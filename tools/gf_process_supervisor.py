#!/usr/bin/env python3
"""Cross-platform subprocess supervision for GF maintenance commands."""

from __future__ import annotations

import json
import math
import os
import secrets
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from dataclasses import dataclass
from dataclasses import replace
from pathlib import Path
from types import TracebackType
from typing import Any
from typing import BinaryIO
from typing import Callable


OUTPUT_DRAIN_GRACE_SECONDS = 1.0
OUTPUT_CLEANUP_GRACE_SECONDS = 2.0
STDIN_STAGE_CHUNK_BYTES = 1024 * 1024
BINARY_PROCESS_CLEANUP_RESERVE_SECONDS = 4.0
BINARY_PROCESS_POLL_SECONDS = 0.01
BINARY_PROCESS_POST_TERMINATION_DRAIN_SECONDS = 1.0
BINARY_PROCESS_DEFERRED_CLEANUP_SECONDS = 10.0
PROCESS_LEASE_CLEANUP_RESERVE_SECONDS = 30.0
POSIX_WATCHDOG_PROTOCOL_VERSION = 1
POSIX_WATCHDOG_MAX_STATUS_BYTES = 64 * 1024
POSIX_WATCHDOG_MAX_CONFIG_BYTES = 1024 * 1024
POSIX_WATCHDOG_HELPER_NAME = "gf_posix_process_watchdog.py"
LINUX_PROC_STAT_MAX_BYTES = 4096
LINUX_PROC_SCAN_MAX_ENTRIES = 131072
LINUX_PROC_SCAN_TIMEOUT_SECONDS = 0.25
_LINUX_PROCESS_GROUP_ABSENT = "absent"
_LINUX_PROCESS_GROUP_TERMINATED = "terminated"
_LINUX_PROCESS_GROUP_LIVE = "live"
_LINUX_TERMINATED_PROCESS_STATES = frozenset(("Z", "X", "x"))


class SupervisedProcessStartError(OSError):
	"""A command-start failure with a positive no-child boundary proof."""

	def __init__(self, error: OSError) -> None:
		try:
			arguments = BaseException.__getattribute__(error, "args")
		except BaseException:
			arguments = ("Subprocess start failed before child creation.",)
		if not isinstance(arguments, tuple):
			arguments = ("Subprocess start failed before child creation.",)
		super().__init__(*arguments)
		self.original_error = error
		self.return_code = 127 if isinstance(error, FileNotFoundError) else 126
		self.started = False
		self.pid = 0
		self.process_boundary_quiescent = True


class SupervisedProcessCleanupError(OSError):
	"""A supervision failure whose owner/resource cleanup was not proven complete."""

	def __init__(
		self,
		message: str,
		*,
		notes: tuple[str, ...] = (),
		original_error: BaseException | None = None,
		pid: int = 0,
		owner_closed: bool = False,
		process_tree_empty: bool = False,
		direct_reaped: bool = False,
		cleanup_confirmation_complete: bool = False,
		cleanup_status: Any = None,
		deferred_cleanup: Any = None,
	) -> None:
		super().__init__(message)
		self.cleanup_debt = True
		self.process_boundary_quiescent = False
		self.cleanup_complete = False
		self.notes = notes
		self.original_error = original_error
		self.pid = pid
		self.owner_closed = owner_closed
		self.process_tree_empty = process_tree_empty
		self.direct_reaped = direct_reaped
		self.cleanup_confirmation_complete = cleanup_confirmation_complete
		self.cleanup_status = cleanup_status
		self.deferred_cleanup = deferred_cleanup


def exception_has_cleanup_debt(error: BaseException) -> bool:
	"""Return whether an exception chain carries an unproven cleanup boundary.

	The inspection is deliberately fail-closed: custom exception attribute access,
	descriptors, or an unreadable cause/context chain cannot grant cleanup authority.
	"""
	uninspectable = object()

	def raw_attribute(current: BaseException, name: str, default: object) -> object:
		try:
			attributes = BaseException.__getattribute__(current, "__dict__")
			if isinstance(attributes, dict) and name in attributes:
				return attributes[name]
			return BaseException.__getattribute__(current, name)
		except AttributeError:
			return default
		except BaseException:
			return uninspectable

	pending: list[BaseException] = [error]
	seen: set[int] = set()
	while pending:
		current = pending.pop()
		current_id = id(current)
		if current_id in seen:
			continue
		seen.add(current_id)
		try:
			error_type = type(current)
			if error_type.__getattribute__ is not BaseException.__getattribute__:
				return True
			for owner_type in error_type.__mro__:
				if owner_type is BaseException:
					break
				owner_attributes = vars(owner_type)
				if "__dict__" in owner_attributes or any(
					name in owner_attributes
					for name in (
						"cleanup_debt",
						"process_boundary_quiescent",
						"__cause__",
						"__context__",
						"__suppress_context__",
					)
				):
					return True
		except BaseException:
			return True
		cleanup_debt = raw_attribute(current, "cleanup_debt", False)
		process_boundary_quiescent = raw_attribute(
			current,
			"process_boundary_quiescent",
			None,
		)
		cause = raw_attribute(current, "__cause__", None)
		context = raw_attribute(current, "__context__", None)
		if any(
			value is uninspectable
			for value in (cleanup_debt, process_boundary_quiescent, cause, context)
		):
			return True
		if cleanup_debt is True or process_boundary_quiescent is False:
			return True
		for nested in (cause, context):
			if isinstance(nested, BaseException):
				pending.append(nested)
	return False


def safe_exception_detail(error: BaseException) -> str:
	"""Format diagnostics without letting hostile exception text replace control flow."""
	try:
		return str(error)
	except BaseException:
		return "exception detail unavailable"


def add_exception_note(error: BaseException, note: str) -> bool:
	"""Attach one diagnostic note on every supported Python without raising."""
	if not isinstance(note, str):
		return False
	native_add_note = getattr(BaseException, "add_note", None)
	if callable(native_add_note):
		try:
			native_add_note(error, note)
		except BaseException:
			return False
		return True
	try:
		attributes = BaseException.__getattribute__(error, "__dict__")
		if type(attributes) is not dict:
			return False
		notes = attributes.get("__notes__")
		if notes is None:
			notes = []
			attributes["__notes__"] = notes
		if type(notes) is not list:
			return False
		notes.append(note)
		verified = BaseException.__getattribute__(error, "__dict__")
		return (
			verified is attributes
			and verified.get("__notes__") is notes
			and bool(notes)
			and notes[-1] == note
		)
	except BaseException:
		return False


def rmtree_with_exception_callback(
	path: Path | str,
	callback: Callable[[Callable[..., object], str, BaseException], None],
) -> None:
	"""Use the Python 3.12 ``onexc`` contract while supporting Python 3.10/3.11."""
	if sys.version_info >= (3, 12):
		shutil.rmtree(path, onexc=callback)
		return

	def legacy_onerror(
		function: Callable[..., object],
		failed_path: str,
		exception_info: tuple[type[BaseException], BaseException, TracebackType],
	) -> None:
		error = exception_info[1]
		if not isinstance(error, BaseException):
			raise RuntimeError("shutil.rmtree did not provide a cleanup exception")
		callback(function, failed_path, error)

	shutil.rmtree(path, onerror=legacy_onerror)


def safe_exception_traceback(error: BaseException) -> TracebackType | None:
	"""Capture only a real traceback without dispatching through hostile accessors."""
	try:
		traceback = BaseException.__getattribute__(error, "__traceback__")
	except BaseException:
		return None
	return traceback if traceback is None or isinstance(traceback, TracebackType) else None


def _select_preferred_cleanup_error(
	current: BaseException | None,
	current_traceback: TracebackType | None,
	candidate: BaseException,
	*,
	context: str,
) -> tuple[BaseException, TracebackType | None]:
	"""Prefer the first control-flow interruption, otherwise the first error.

	Cleanup must continue after every failure, but ``KeyboardInterrupt``/
	``SystemExit``/other direct ``BaseException`` subclasses cannot be hidden by an
	earlier ordinary ``Exception``.  The non-selected failure remains attached as a
	diagnostic note without invoking hostile exception string conversion.
	"""
	candidate_traceback = safe_exception_traceback(candidate)
	if current is None:
		return candidate, candidate_traceback
	current_is_control = not isinstance(current, Exception)
	candidate_is_control = not isinstance(candidate, Exception)
	if candidate_is_control and not current_is_control:
		add_exception_note(
			candidate,
			f"Earlier {context} failure was {type(current).__name__}.",
		)
		return candidate, candidate_traceback
	add_exception_note(
		current,
		f"Later {context} failure was {type(candidate).__name__}.",
	)
	return current, current_traceback


def _process_supervision_checkpoint(_name: str) -> None:
	"""Private no-op seam for deterministic maintenance fault injection."""


def _close_process_pipes(process: subprocess.Popen[str]) -> None:
	"""Close both captured streams even when closing the first stream fails."""
	try:
		if process.stdout is not None:
			process.stdout.close()
	finally:
		if process.stderr is not None:
			process.stderr.close()


def _linux_process_group_cleanup_state(
	process_group_id: int,
	*,
	proc_root: Path | None = None,
	scan_deadline: float | None = None,
) -> str | None:
	"""Classify one Linux process group without treating terminal zombies as live."""
	if process_group_id <= 0:
		return None
	if proc_root is None:
		if not sys.platform.startswith("linux"):
			return None
		proc_root = Path("/proc")
	if scan_deadline is None:
		scan_deadline = time.perf_counter() + LINUX_PROC_SCAN_TIMEOUT_SECONDS
	group_found = False
	entry_count = 0
	try:
		process_entries = os.scandir(proc_root)
	except OSError:
		return None
	with process_entries:
		for process_entry in process_entries:
			if not process_entry.name.isdecimal():
				continue
			entry_count += 1
			if (
				entry_count > LINUX_PROC_SCAN_MAX_ENTRIES
				or time.perf_counter() >= scan_deadline
			):
				return None
			stat_path = Path(process_entry.path) / "stat"
			try:
				with stat_path.open("rb") as stat_file:
					stat_payload = stat_file.read(LINUX_PROC_STAT_MAX_BYTES + 1)
			except FileNotFoundError:
				continue
			except OSError:
				return None
			if len(stat_payload) > LINUX_PROC_STAT_MAX_BYTES:
				return None
			_prefix, separator, stat_suffix = stat_payload.rpartition(b")")
			stat_fields = stat_suffix.split()
			if not separator or len(stat_fields) < 18 or len(stat_fields[0]) != 1:
				return None
			try:
				member_group_id = int(stat_fields[2])
				member_state = stat_fields[0].decode("ascii")
				member_thread_count = int(stat_fields[17])
			except (UnicodeDecodeError, ValueError):
				return None
			if member_group_id < 0 or member_thread_count < 0:
				return None
			if member_group_id != process_group_id:
				continue
			group_found = True
			if (
				member_state not in _LINUX_TERMINATED_PROCESS_STATES
				or member_thread_count > 1
			):
				return _LINUX_PROCESS_GROUP_LIVE
	return (
		_LINUX_PROCESS_GROUP_TERMINATED
		if group_found
		else _LINUX_PROCESS_GROUP_ABSENT
	)


class _ProcessTreeOwner:
	"""Kernel-backed ownership for every process launched by one command."""

	def __init__(self) -> None:
		self.cleanup_failed = False
		self.deadline_late = False
		self._started_process: subprocess.Popen[str] | None = None
		self._process_was_created = False
		self._closed = False
		self._close_succeeded = False
		self._termination_succeeded = False
		self._cleanup_confirmation_succeeded = False
		self._stdin_stream: BinaryIO | None = None
		self._text_errors = "replace"
		self._binary_output = False

	def start(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str],
	) -> subprocess.Popen[str]:
		raise NotImplementedError

	def start_bytes(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str],
	) -> subprocess.Popen[bytes]:
		raise NotImplementedError

	def start_lease(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str],
	) -> subprocess.Popen[bytes]:
		"""Start a long-lived child with zero-byte DEVNULL output capture."""
		raise NotImplementedError

	def wait_for_direct_exit(
		self,
		process: subprocess.Popen[str],
		timeout_seconds: float,
	) -> bool:
		raise NotImplementedError

	def terminate(self, process: subprocess.Popen[str]) -> list[str]:
		raise NotImplementedError

	def terminate_before_deadline(
		self,
		process: subprocess.Popen[Any],
		deadline: float,
	) -> list[str]:
		_ = deadline
		return self.terminate(process)

	def confirm_cleanup_after_reap(self) -> list[str]:
		self._cleanup_confirmation_succeeded = True
		return []

	def confirm_cleanup_after_reap_before_deadline(
		self,
		deadline: float,
	) -> list[str]:
		_ = deadline
		return self.confirm_cleanup_after_reap()

	def close(self) -> list[str]:
		self._started_process = None
		self._closed = True
		self._close_succeeded = True
		return []

	def close_before_deadline(self, deadline: float) -> list[str]:
		notes = self.close()
		if time.perf_counter() > deadline:
			self.deadline_late = True
			notes.append("Process-tree owner close exceeded its absolute deadline.")
		return notes

	def wait_for_close_completion(self, timeout_seconds: float | None) -> bool:
		_ = timeout_seconds
		return self.is_closed()

	def is_closed(self) -> bool:
		return self._closed

	def close_succeeded(self) -> bool:
		return self._close_succeeded

	def termination_succeeded(self) -> bool:
		return self._termination_succeeded

	def cleanup_confirmation_succeeded(self) -> bool:
		return self._cleanup_confirmation_succeeded

	def close_terminates_tree(self) -> bool:
		return False

class _PosixProcessGroupOwner(_ProcessTreeOwner):
	"""Keep the group leader unreaped until its independently owned group is empty."""

	def __init__(self) -> None:
		super().__init__()
		if not all(hasattr(os, name) for name in ("waitid", "P_PID", "WEXITED", "WNOHANG", "WNOWAIT")):
			raise OSError("POSIX process supervision requires waitid(..., WNOWAIT) support.")
		self.process_group_id = 0
		self._cleanup_probe_group_id = 0

	def start(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str],
	) -> subprocess.Popen[str]:
		return self._start_process(
			command,
			cwd=cwd,
			environment=environment,
			binary=False,
		)

	def start_bytes(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str],
	) -> subprocess.Popen[bytes]:
		return self._start_process(
			command,
			cwd=cwd,
			environment=environment,
			binary=True,
		)

	def start_lease(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str],
	) -> subprocess.Popen[bytes]:
		return self._start_process(
			command,
			cwd=cwd,
			environment=environment,
			binary=True,
			capture_output=False,
		)

	def _start_process(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str],
		binary: bool,
		capture_output: bool = True,
	) -> Any:
		process: subprocess.Popen[Any] | None = None
		try:
			popen_options: dict[str, Any] = {
				"cwd": cwd,
				"stdin": subprocess.DEVNULL if binary else self._stdin_stream,
				"stdout": subprocess.PIPE if capture_output else subprocess.DEVNULL,
				"stderr": subprocess.PIPE if capture_output else subprocess.DEVNULL,
				"env": environment,
				"start_new_session": True,
			}
			if binary:
				popen_options["bufsize"] = 0
			if binary or self._binary_output:
				popen_options["text"] = False
			else:
				popen_options.update({
					"text": True,
					"encoding": "utf-8",
					"errors": self._text_errors,
				})
			process = subprocess.Popen(command, **popen_options)
			self._started_process = process
			self._process_was_created = True
			self.process_group_id = process.pid
			setattr(process, "_gf_process_tree_owner", self)
			_process_supervision_checkpoint("posix_process_started")
			return process
		except BaseException:
			if process is not None:
				# Popen completed start_new_session before returning. Publish the
				# process and PGID to the already-installed outer cleanup guard; do
				# not reap locally if group termination has not succeeded.
				self._started_process = process
				self.process_group_id = process.pid
				try:
					setattr(process, "_gf_process_tree_owner", self)
				except BaseException:
					# Preserve the first startup error. The outer guard will fail
					# closed if this otherwise ordinary Popen attribute cannot bind.
					pass
			raise

	def wait_for_direct_exit(
		self,
		process: subprocess.Popen[str],
		timeout_seconds: float,
	) -> bool:
		status = os.waitid(
			os.P_PID,
			process.pid,
			os.WEXITED | os.WNOHANG | os.WNOWAIT,
		)
		if status is not None and int(getattr(status, "si_pid", 0)) == process.pid:
			return True
		if timeout_seconds > 0.0:
			time.sleep(min(timeout_seconds, 0.05))
		status = os.waitid(
			os.P_PID,
			process.pid,
			os.WEXITED | os.WNOHANG | os.WNOWAIT,
		)
		return status is not None and int(getattr(status, "si_pid", 0)) == process.pid

	def terminate(self, process: subprocess.Popen[str]) -> list[str]:
		self._termination_succeeded = False
		if self._cleanup_probe_group_id > 0:
			self.cleanup_failed = True
			return [
				"POSIX process-group termination was requested after the leader was reaped; "
				"refusing to signal a potentially reused PGID."
			]
		if self.process_group_id <= 0:
			if self._started_process is process:
				self.process_group_id = process.pid
			else:
				self.cleanup_failed = True
				return ["Owned POSIX process group identity was unavailable during cleanup."]
		notes: list[str] = []
		try:
			direct_exited = self.wait_for_direct_exit(process, 0.0)
		except ChildProcessError as error:
			self.cleanup_failed = True
			return [
				"Direct child was already reaped before POSIX process-group cleanup; "
				f"refusing to signal a potentially reused PGID: {error}"
			]
		except OSError as error:
			direct_exited = False
			notes.append(
				f"Could not inspect the direct child before POSIX process-group cleanup; "
				f"continuing with forced cleanup: {error}"
			)
		termination_notes = terminate_posix_process_group_id(
			self.process_group_id,
			grace_seconds=0.0 if direct_exited else 0.1,
		)
		notes.extend(termination_notes)
		if termination_notes:
			self.cleanup_failed = True
		else:
			self._termination_succeeded = True
		return notes

	def terminate_before_deadline(
		self,
		process: subprocess.Popen[Any],
		deadline: float,
	) -> list[str]:
		self._termination_succeeded = False
		if self._cleanup_probe_group_id > 0:
			self.cleanup_failed = True
			return [
				"POSIX process-group termination was requested after the leader was reaped; "
				"refusing to signal a potentially reused PGID."
			]
		if self.process_group_id <= 0:
			if self._started_process is process:
				self.process_group_id = process.pid
			else:
				self.cleanup_failed = True
				return ["Owned POSIX process group identity was unavailable during cleanup."]
		try:
			os.killpg(self.process_group_id, signal.SIGKILL)
		except ProcessLookupError:
			self._termination_succeeded = True
			return []
		except OSError as error:
			self.cleanup_failed = True
			return [f"Could not kill owned POSIX process group before its deadline: {error}"]
		self._termination_succeeded = True
		if time.perf_counter() > deadline:
			self.deadline_late = True
			return ["Owned POSIX process-group termination exceeded its absolute deadline."]
		return []

	def confirm_cleanup_after_reap(self) -> list[str]:
		self._cleanup_confirmation_succeeded = False
		if self._cleanup_probe_group_id <= 0 and self.process_group_id > 0:
			self._cleanup_probe_group_id = self.process_group_id
		# Reaping releases the leader PID. From this point onward, retain only a
		# probe-only identity that is never used for a nonzero signal.
		self.process_group_id = 0
		if self._cleanup_probe_group_id <= 0:
			self._cleanup_confirmation_succeeded = True
			return []
		process_group_id = self._cleanup_probe_group_id
		cleanup_deadline = time.perf_counter() + OUTPUT_CLEANUP_GRACE_SECONDS
		linux_cleanup_state: str | None = None
		linux_scan_attempted = False
		probe_permission_denied = False
		while True:
			try:
				# Signal zero only probes existence and permissions; it does not deliver a signal.
				os.killpg(process_group_id, 0)
			except ProcessLookupError:
				self._cleanup_probe_group_id = 0
				self._cleanup_confirmation_succeeded = True
				return []
			except PermissionError:
				probe_permission_denied = True
			except OSError as error:
				self.cleanup_failed = True
				return [f"Could not confirm POSIX process group {process_group_id} cleanup: {error}"]
			now = time.perf_counter()
			if (
				not probe_permission_denied
				and (not linux_scan_attempted or now >= cleanup_deadline)
			):
				linux_cleanup_state = _linux_process_group_cleanup_state(process_group_id)
				linux_scan_attempted = True
				if linux_cleanup_state in (
					_LINUX_PROCESS_GROUP_ABSENT,
					_LINUX_PROCESS_GROUP_TERMINATED,
				):
					self._cleanup_probe_group_id = 0
					self._cleanup_confirmation_succeeded = True
					if linux_cleanup_state == _LINUX_PROCESS_GROUP_TERMINATED:
						return [
							f"Owned POSIX process group {process_group_id} retained only "
							"terminated (zombie/dead) members after forced cleanup."
						]
					return []
			if now >= cleanup_deadline:
				self.cleanup_failed = True
				if linux_cleanup_state == _LINUX_PROCESS_GROUP_LIVE:
					return [
						f"Owned POSIX process group {process_group_id} still had "
						"non-terminal members after forced cleanup."
					]
				return [
					f"Owned POSIX process group {process_group_id} still existed after forced cleanup."
				]
			time.sleep(0.01)

	def confirm_cleanup_after_reap_before_deadline(
		self,
		deadline: float,
	) -> list[str]:
		self._cleanup_confirmation_succeeded = False
		if self._cleanup_probe_group_id <= 0 and self.process_group_id > 0:
			self._cleanup_probe_group_id = self.process_group_id
		self.process_group_id = 0
		if self._cleanup_probe_group_id <= 0:
			self._cleanup_confirmation_succeeded = True
			return []
		process_group_id = self._cleanup_probe_group_id
		while True:
			try:
				os.killpg(process_group_id, 0)
			except ProcessLookupError:
				self._cleanup_probe_group_id = 0
				self._cleanup_confirmation_succeeded = True
				return []
			except PermissionError:
				pass
			except OSError as error:
				self.cleanup_failed = True
				return [
					f"Could not confirm POSIX process group {process_group_id} cleanup: {error}"
				]
			now = time.perf_counter()
			linux_cleanup_state = _linux_process_group_cleanup_state(
				process_group_id,
				scan_deadline=deadline,
			)
			if linux_cleanup_state in (
				_LINUX_PROCESS_GROUP_ABSENT,
				_LINUX_PROCESS_GROUP_TERMINATED,
			):
				self._cleanup_probe_group_id = 0
				self._cleanup_confirmation_succeeded = True
				if linux_cleanup_state == _LINUX_PROCESS_GROUP_TERMINATED:
					return [
						f"Owned POSIX process group {process_group_id} retained only "
						"terminated (zombie/dead) members after forced cleanup."
					]
				return []
			if now >= deadline:
				self.cleanup_failed = True
				return [
					f"Owned POSIX process group {process_group_id} cleanup "
					"could not be confirmed before its absolute deadline."
				]
			time.sleep(min(0.01, max(0.0, deadline - now)))


if os.name == "nt":
	import _thread
	import ctypes
	import msvcrt
	from ctypes import wintypes

	_CREATE_SUSPENDED = 0x00000004
	_JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000
	_JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS = 1
	_JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS = 9
	_WAIT_OBJECT_0 = 0x00000000
	_WAIT_TIMEOUT = 0x00000102
	_WAIT_FAILED = 0xFFFFFFFF
	_ERROR_BROKEN_PIPE = 109
	_ERROR_NO_DATA = 232


	class _JobObjectBasicLimitInformation(ctypes.Structure):
		_fields_ = [
			("PerProcessUserTimeLimit", ctypes.c_longlong),
			("PerJobUserTimeLimit", ctypes.c_longlong),
			("LimitFlags", wintypes.DWORD),
			("MinimumWorkingSetSize", ctypes.c_size_t),
			("MaximumWorkingSetSize", ctypes.c_size_t),
			("ActiveProcessLimit", wintypes.DWORD),
			("Affinity", ctypes.c_size_t),
			("PriorityClass", wintypes.DWORD),
			("SchedulingClass", wintypes.DWORD),
		]


	class _IoCounters(ctypes.Structure):
		_fields_ = [
			("ReadOperationCount", ctypes.c_ulonglong),
			("WriteOperationCount", ctypes.c_ulonglong),
			("OtherOperationCount", ctypes.c_ulonglong),
			("ReadTransferCount", ctypes.c_ulonglong),
			("WriteTransferCount", ctypes.c_ulonglong),
			("OtherTransferCount", ctypes.c_ulonglong),
		]


	class _JobObjectExtendedLimitInformation(ctypes.Structure):
		_fields_ = [
			("BasicLimitInformation", _JobObjectBasicLimitInformation),
			("IoInfo", _IoCounters),
			("ProcessMemoryLimit", ctypes.c_size_t),
			("JobMemoryLimit", ctypes.c_size_t),
			("PeakProcessMemoryUsed", ctypes.c_size_t),
			("PeakJobMemoryUsed", ctypes.c_size_t),
		]


	class _JobObjectBasicAccountingInformation(ctypes.Structure):
		_fields_ = [
			("TotalUserTime", ctypes.c_longlong),
			("TotalKernelTime", ctypes.c_longlong),
			("ThisPeriodTotalUserTime", ctypes.c_longlong),
			("ThisPeriodTotalKernelTime", ctypes.c_longlong),
			("TotalPageFaultCount", wintypes.DWORD),
			("TotalProcesses", wintypes.DWORD),
			("ActiveProcesses", wintypes.DWORD),
			("TotalTerminatedProcesses", wintypes.DWORD),
		]


	_KERNEL32 = ctypes.WinDLL("kernel32", use_last_error=True)
	_NTDLL = ctypes.WinDLL("ntdll", use_last_error=True)
	_CREATE_JOB_OBJECT = _KERNEL32.CreateJobObjectW
	_CREATE_JOB_OBJECT.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
	_CREATE_JOB_OBJECT.restype = wintypes.HANDLE
	_SET_JOB_INFORMATION = _KERNEL32.SetInformationJobObject
	_SET_JOB_INFORMATION.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
	_SET_JOB_INFORMATION.restype = wintypes.BOOL
	_ASSIGN_PROCESS_TO_JOB = _KERNEL32.AssignProcessToJobObject
	_ASSIGN_PROCESS_TO_JOB.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
	_ASSIGN_PROCESS_TO_JOB.restype = wintypes.BOOL
	_QUERY_JOB_INFORMATION = _KERNEL32.QueryInformationJobObject
	_QUERY_JOB_INFORMATION.argtypes = [
		wintypes.HANDLE,
		ctypes.c_int,
		ctypes.c_void_p,
		wintypes.DWORD,
		ctypes.POINTER(wintypes.DWORD),
	]
	_QUERY_JOB_INFORMATION.restype = wintypes.BOOL
	_TERMINATE_JOB = _KERNEL32.TerminateJobObject
	_TERMINATE_JOB.argtypes = [wintypes.HANDLE, wintypes.UINT]
	_TERMINATE_JOB.restype = wintypes.BOOL
	_WAIT_FOR_SINGLE_OBJECT = _KERNEL32.WaitForSingleObject
	_WAIT_FOR_SINGLE_OBJECT.argtypes = [wintypes.HANDLE, wintypes.DWORD]
	_WAIT_FOR_SINGLE_OBJECT.restype = wintypes.DWORD
	_PEEK_NAMED_PIPE = _KERNEL32.PeekNamedPipe
	_PEEK_NAMED_PIPE.argtypes = [
		wintypes.HANDLE,
		ctypes.c_void_p,
		wintypes.DWORD,
		ctypes.POINTER(wintypes.DWORD),
		ctypes.POINTER(wintypes.DWORD),
		ctypes.POINTER(wintypes.DWORD),
	]
	_PEEK_NAMED_PIPE.restype = wintypes.BOOL
	_CLOSE_HANDLE = _KERNEL32.CloseHandle
	_CLOSE_HANDLE.argtypes = [wintypes.HANDLE]
	_CLOSE_HANDLE.restype = wintypes.BOOL
	_NT_RESUME_PROCESS = _NTDLL.NtResumeProcess
	_NT_RESUME_PROCESS.argtypes = [wintypes.HANDLE]
	_NT_RESUME_PROCESS.restype = ctypes.c_long


	@dataclass(frozen=True)
	class _WindowsHandleCloseOutcome:
		called: bool
		result: bool | None
		last_error: int
		error: BaseException | None
		error_traceback: Any


	class _WindowsHandleCloseOperation:
		"""One persistent, single-consumer CloseHandle attempt."""

		def __init__(self, handle: int) -> None:
			self.handle = handle
			self.claim_lock = threading.Lock()
			self.claimed = False
			self.aborted_before_claim = False
			self.finished = threading.Event()
			self.state_lock = threading.Lock()
			self.called = False
			self.result: bool | None = None
			self.last_error = 0
			self.error: BaseException | None = None
			self.error_traceback: Any = None


	def _wait_for_windows_close_event(
		event: threading.Event,
		pending_error: BaseException | None,
		pending_traceback: Any,
	) -> tuple[BaseException | None, Any]:
		while True:
			try:
				if event.wait(0.05):
					return pending_error, pending_traceback
			except BaseException as error:
				pending_error, pending_traceback = _select_preferred_cleanup_error(
					pending_error,
					pending_traceback,
					error,
					context="Windows handle-close wait",
				)


	def _close_windows_handle_worker(owner: Any, operation: _WindowsHandleCloseOperation) -> None:
		# Retrying a close whose Thread.start() was interrupted may create another
		# contender. Exactly one worker can claim the numeric handle.
		with operation.claim_lock:
			if operation.claimed or operation.aborted_before_claim:
				return
			operation.claimed = True
		close_result: bool | None = None
		close_error: BaseException | None = None
		close_traceback: Any = None
		last_error = 0
		try:
			close_result = bool(_CLOSE_HANDLE(wintypes.HANDLE(operation.handle)))
			if not close_result:
				last_error = ctypes.get_last_error()
		except BaseException as error:
			close_error = error
			close_traceback = safe_exception_traceback(error)
		finally:
			with operation.state_lock:
				operation.called = True
				operation.result = close_result
				operation.last_error = last_error
				operation.error = close_error
				operation.error_traceback = close_traceback
			with owner._handle_state_lock:
				if owner._close_operation is operation:
					if close_result is False:
						# False is the only result that proves the numeric handle
						# remains valid and may safely be retried.
						owner.handle = operation.handle
						owner._closed = False
						owner._close_succeeded = False
					else:
						# An exception after entering CloseHandle makes the kernel
						# result unknowable. Consume the numeric value rather than
						# risking a close against a reused handle.  A created child
						# remains published until the outer cleanup chain has proved
						# termination, direct reap, and tree confirmation; returncode
						# alone is not an ownership-release proof.
						owner.handle = 0
						owner._closed = True
						owner._close_succeeded = close_result is True
					owner._close_operation = None
			operation.finished.set()


	def _windows_handle_close_outcome(
		operation: _WindowsHandleCloseOperation,
		pending_error: BaseException | None,
		pending_traceback: Any,
	) -> _WindowsHandleCloseOutcome:
		with operation.state_lock:
			return _WindowsHandleCloseOutcome(
				called=operation.called,
				result=operation.result,
				last_error=operation.last_error,
				error=pending_error if pending_error is not None else operation.error,
				error_traceback=(
					pending_traceback
					if pending_error is not None
					else operation.error_traceback
				),
			)


	def _close_windows_handle_in_worker(owner: Any) -> _WindowsHandleCloseOutcome:
		"""Close one handle off-main while retaining an interruption-safe operation."""
		with owner._handle_state_lock:
			operation = owner._close_operation
			if operation is None:
				if owner.handle == 0:
					return _WindowsHandleCloseOutcome(
						called=False,
						result=True,
						last_error=0,
						error=None,
						error_traceback=None,
					)
				operation = _WindowsHandleCloseOperation(owner.handle)
				# Publish the operation before hiding the raw numeric handle. Any
				# interrupted retry will join this operation instead of closing twice.
				owner._close_operation = operation
				owner.handle = 0
				owner._closed = False

		pending_error: BaseException | None = None
		pending_traceback: Any = None
		worker_launched = False
		with operation.claim_lock:
			already_claimed = operation.claimed
		if not already_claimed and not operation.finished.is_set():
			# Thread.start() can be interrupted after creating its native thread.
			# Multiple contenders are safe because the operation has one claim lock.
			for _attempt in range(2):
				worker = threading.Thread(
					target=_close_windows_handle_worker,
					args=(owner, operation),
					name="gf-windows-handle-close",
					daemon=True,
				)
				try:
					worker.start()
					worker_launched = True
					break
				except BaseException as error:
					pending_error, pending_traceback = _select_preferred_cleanup_error(
						pending_error,
						pending_traceback,
						error,
						context="Windows handle-close worker launch",
					)
			if not worker_launched:
				try:
					_thread.start_new_thread(
						_close_windows_handle_worker,
						(owner, operation),
					)
					worker_launched = True
				except BaseException as error:
					pending_error, pending_traceback = _select_preferred_cleanup_error(
						pending_error,
						pending_traceback,
						error,
						context="Windows low-level handle-close worker launch",
					)
		if not worker_launched:
			# An earlier ambiguous Thread.start() may still have created a contender.
			# Wait only after it claims; otherwise retain the operation for a later
			# close retry without ever exposing its numeric handle.
			with operation.claim_lock:
				claimed = operation.claimed
			if not claimed and not operation.finished.is_set():
				return _windows_handle_close_outcome(
					operation,
					pending_error,
					pending_traceback,
				)
		pending_error, pending_traceback = _wait_for_windows_close_event(
			operation.finished,
			pending_error,
			pending_traceback,
		)
		return _windows_handle_close_outcome(
			operation,
			pending_error,
			pending_traceback,
		)


	def _launch_windows_handle_close_before_deadline(
		owner: Any,
		operation: _WindowsHandleCloseOperation,
	) -> tuple[list[str], bool, BaseException | None, Any]:
		"""Launch one persistent non-daemon close worker without losing the handle."""
		notes: list[str] = []
		worker_launched = False
		pending_error: BaseException | None = None
		pending_traceback: Any = None
		for _attempt in range(2):
			worker = threading.Thread(
				target=_close_windows_handle_worker,
				args=(owner, operation),
				name="gf-windows-handle-close-deadline",
				daemon=False,
			)
			try:
				worker.start()
				worker_launched = True
				break
			except BaseException as error:
				pending_error, pending_traceback = _select_preferred_cleanup_error(
					pending_error,
					pending_traceback,
					error,
					context="deadline-bounded Windows handle-close worker launch",
				)
				notes.append(
					"Windows Job Object close worker launch failed: "
					f"{type(error).__name__}."
				)

		with operation.claim_lock:
			worker_claimed = operation.claimed
			abort_launch = not worker_launched and not worker_claimed
			if abort_launch:
				# A Thread.start() exception can be ambiguous. Claim cancellation while
				# holding the same lock used by every target so a late native thread
				# cannot consume a handle that has been restored to the owner.
				operation.aborted_before_claim = True
		if abort_launch:
			with owner._handle_state_lock:
				if owner._close_operation is operation:
					owner.handle = operation.handle
					owner._close_operation = None
					owner._closed = False
					owner._close_succeeded = False
			operation.finished.set()
			return notes, False, pending_error, pending_traceback
		return notes, True, pending_error, pending_traceback


	class _WindowsJobOwner(_ProcessTreeOwner):
		"""Assign a suspended child to a kill-on-close Job before any code runs."""

		def __init__(self) -> None:
			super().__init__()
			self._handle_state_lock = threading.Lock()
			self._close_operation: _WindowsHandleCloseOperation | None = None
			self._started_process_assigned_to_job = False
			handle = _CREATE_JOB_OBJECT(None, None)
			if not handle:
				raise ctypes.WinError(ctypes.get_last_error())
			self.handle = int(handle)
			information = _JobObjectExtendedLimitInformation()
			information.BasicLimitInformation.LimitFlags = _JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
			try:
				if not _SET_JOB_INFORMATION(
					wintypes.HANDLE(self.handle),
					_JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS,
					ctypes.byref(information),
					ctypes.sizeof(information),
				):
					raise ctypes.WinError(ctypes.get_last_error())
			except BaseException as configuration_error:
				# The Job is still empty. Route every configuration-failure close
				# through the same interruption-safe state machine, retrying explicit
				# False.  A repeated close failure is resource cleanup debt, not a
				# reason to silently restore the configuration exception.
				close_notes: list[str] = []
				for _attempt in range(2):
					try:
						close_notes.extend(self.close())
					except BaseException as close_error:
						close_notes.append(
							"Windows Job Object configuration cleanup failed: "
							f"{type(close_error).__name__}."
						)
					if self.is_closed():
						break
				if not self.is_closed():
					raise SupervisedProcessCleanupError(
						"Windows Job Object configuration failed without a proven "
						"owner-close boundary.",
						notes=tuple(close_notes),
						original_error=configuration_error,
						owner_closed=False,
						process_tree_empty=True,
						direct_reaped=True,
						cleanup_confirmation_complete=True,
					) from configuration_error
				for close_note in close_notes:
					add_exception_note(configuration_error, close_note)
				raise

		def start(
			self,
			command: list[str],
			*,
			cwd: Path,
			environment: dict[str, str],
		) -> subprocess.Popen[str]:
			return self._start_process(
				command,
				cwd=cwd,
				environment=environment,
				binary=False,
			)

		def start_bytes(
			self,
			command: list[str],
			*,
			cwd: Path,
			environment: dict[str, str],
		) -> subprocess.Popen[bytes]:
			return self._start_process(
				command,
				cwd=cwd,
				environment=environment,
				binary=True,
			)

		def start_lease(
			self,
			command: list[str],
			*,
			cwd: Path,
			environment: dict[str, str],
		) -> subprocess.Popen[bytes]:
			return self._start_process(
				command,
				cwd=cwd,
				environment=environment,
				binary=True,
				capture_output=False,
			)

		def _start_process(
			self,
			command: list[str],
			*,
			cwd: Path,
			environment: dict[str, str],
			binary: bool,
			capture_output: bool = True,
		) -> Any:
			process: subprocess.Popen[Any] | None = None
			assigned_to_job = False
			try:
				popen_options: dict[str, Any] = {
					"cwd": cwd,
					"stdin": subprocess.DEVNULL if binary else self._stdin_stream,
					"stdout": subprocess.PIPE if capture_output else subprocess.DEVNULL,
					"stderr": subprocess.PIPE if capture_output else subprocess.DEVNULL,
					"env": environment,
					"creationflags": (
						subprocess.CREATE_NEW_PROCESS_GROUP | _CREATE_SUSPENDED
					),
				}
				if binary:
					popen_options["bufsize"] = 0
				if binary or self._binary_output:
					popen_options["text"] = False
				else:
					popen_options.update({
						"text": True,
						"encoding": "utf-8",
						"errors": self._text_errors,
					})
				process = subprocess.Popen(command, **popen_options)
				self._started_process = process
				self._process_was_created = True
				self._started_process_assigned_to_job = False
				setattr(process, "_gf_process_tree_owner", self)
				_process_supervision_checkpoint("windows_process_started")
				process_handle = wintypes.HANDLE(int(process._handle))
				if not _ASSIGN_PROCESS_TO_JOB(wintypes.HANDLE(self.handle), process_handle):
					raise ctypes.WinError(ctypes.get_last_error())
				assigned_to_job = True
				self._started_process_assigned_to_job = True
				_process_supervision_checkpoint("windows_process_assigned")
				resume_status = int(_NT_RESUME_PROCESS(process_handle))
				if resume_status != 0:
					raise OSError(
						f"NtResumeProcess failed with NTSTATUS 0x{resume_status & 0xFFFFFFFF:08x}."
					)
				return process
			except BaseException:
				# The caller installs the complete terminate -> reap -> confirm ->
				# close chain before calling start().  Retain every created child and
				# its assignment state for that chain; performing a second private
				# cleanup here previously swallowed every cleanup-stage exception.
				if process is not None:
					self._started_process = process
					self._started_process_assigned_to_job = assigned_to_job
				raise

		def wait_for_direct_exit(
			self,
			process: subprocess.Popen[str],
			timeout_seconds: float,
		) -> bool:
			milliseconds = min(0xFFFFFFFE, max(0, int(timeout_seconds * 1000.0 + 0.999)))
			wait_result = int(
				_WAIT_FOR_SINGLE_OBJECT(
					wintypes.HANDLE(int(process._handle)),
					milliseconds,
				)
			)
			if wait_result == _WAIT_OBJECT_0:
				return True
			if wait_result == _WAIT_TIMEOUT:
				return False
			if wait_result == _WAIT_FAILED:
				raise ctypes.WinError(ctypes.get_last_error())
			raise OSError(f"WaitForSingleObject returned unexpected status 0x{wait_result:08x}.")

		def _active_process_count(self, handle: int) -> int:
			information = _JobObjectBasicAccountingInformation()
			if not _QUERY_JOB_INFORMATION(
				wintypes.HANDLE(handle),
				_JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS,
				ctypes.byref(information),
				ctypes.sizeof(information),
				None,
			):
				raise ctypes.WinError(ctypes.get_last_error())
			return int(information.ActiveProcesses)

		def _terminate_unassigned_started_process_before_deadline(
			self,
			process: subprocess.Popen[Any],
			deadline: float,
		) -> list[str] | None:
			"""Stop a child whose suspended launch failed before Job assignment."""
			if (
				self._started_process is not process
				or self._started_process_assigned_to_job
			):
				return None
			notes: list[str] = []
			pending_error: BaseException | None = None
			pending_traceback: Any = None

			def record(error: BaseException, context: str) -> None:
				nonlocal pending_error, pending_traceback
				pending_error, pending_traceback = _select_preferred_cleanup_error(
					pending_error,
					pending_traceback,
					error,
					context=context,
				)

			try:
				direct_exited = self.wait_for_direct_exit(process, 0.0)
			except BaseException as error:
				record(error, "unassigned Windows child inspection")
				direct_exited = False
				notes.append(
					"Could not inspect the unassigned suspended Windows child before "
					f"termination: {type(error).__name__}."
				)
			if not direct_exited:
				try:
					# Before assignment the process is still suspended and therefore
					# cannot have created descendants.  Keep its Popen identity retained
					# until the outer chain separately reaps it.
					process.kill()
				except BaseException as error:
					record(error, "unassigned Windows child termination")
					notes.append(
						"Could not terminate the unassigned suspended Windows child: "
						f"{type(error).__name__}."
					)
				remaining = max(0.0, deadline - time.perf_counter())
				try:
					direct_exited = self.wait_for_direct_exit(process, remaining)
				except BaseException as error:
					record(error, "unassigned Windows child termination confirmation")
					direct_exited = False
					notes.append(
						"Could not confirm unassigned suspended Windows child termination: "
						f"{type(error).__name__}."
					)
			self._termination_succeeded = direct_exited
			if direct_exited:
				notes.append("Terminated the unassigned suspended Windows child.")
				if pending_error is not None:
					raise pending_error.with_traceback(pending_traceback)
				return notes
			self.cleanup_failed = True
			notes.append(
				"Unassigned suspended Windows child termination was not proven "
				"before its absolute deadline."
			)
			if pending_error is not None:
				raise pending_error.with_traceback(pending_traceback)
			return notes

		def terminate(self, process: subprocess.Popen[str]) -> list[str]:
			self._termination_succeeded = False
			unassigned_notes = self._terminate_unassigned_started_process_before_deadline(
				process,
				time.perf_counter() + OUTPUT_CLEANUP_GRACE_SECONDS,
			)
			if unassigned_notes is not None:
				return unassigned_notes
			with self._handle_state_lock:
				close_in_progress = self._close_operation is not None
				handle = self.handle
			if close_in_progress:
				self.deadline_late = True
				return [
					"Owned Windows Job Object close was already in progress; "
					"deferring tree termination to kill-on-close."
				]
			if handle == 0:
				self._termination_succeeded = self.close_succeeded()
				return []
			notes: list[str] = []
			try:
				active_before = self._active_process_count(handle)
			except OSError as error:
				self.cleanup_failed = True
				return [f"Could not query the owned Windows Job Object: {error}"]
			if active_before == 0:
				self._termination_succeeded = True
				return notes
			if not _TERMINATE_JOB(wintypes.HANDLE(handle), 1):
				self.cleanup_failed = True
				return [f"Could not terminate the owned Windows Job Object: {ctypes.WinError(ctypes.get_last_error())}"]
			cleanup_deadline = time.perf_counter() + OUTPUT_CLEANUP_GRACE_SECONDS
			while time.perf_counter() < cleanup_deadline:
				try:
					if self._active_process_count(handle) == 0:
						self._termination_succeeded = True
						notes.append(f"Terminated {active_before} process(es) from the owned Windows Job Object.")
						return notes
				except OSError as error:
					self.cleanup_failed = True
					return [f"Could not confirm Windows Job Object cleanup: {error}"]
				time.sleep(0.01)
			notes.append("Owned Windows Job Object still reported active processes after forced termination.")
			self.cleanup_failed = True
			return notes

		def terminate_before_deadline(
			self,
			process: subprocess.Popen[Any],
			deadline: float,
		) -> list[str]:
			self._termination_succeeded = False
			unassigned_notes = self._terminate_unassigned_started_process_before_deadline(
				process,
				deadline,
			)
			if unassigned_notes is not None:
				return unassigned_notes
			with self._handle_state_lock:
				close_in_progress = self._close_operation is not None
				handle = self.handle
			if close_in_progress:
				self.cleanup_failed = True
				return [
					"Owned Windows Job Object close was already in progress; "
					"deferring tree termination to kill-on-close."
				]
			if handle == 0:
				self._termination_succeeded = self._closed
				return []
			try:
				active_before = self._active_process_count(handle)
			except OSError as error:
				self.cleanup_failed = True
				return [f"Could not query the owned Windows Job Object: {error}"]
			if active_before == 0:
				self._termination_succeeded = True
				return []
			if not _TERMINATE_JOB(wintypes.HANDLE(handle), 1):
				self.cleanup_failed = True
				return [
					f"Could not terminate the owned Windows Job Object: "
					f"{ctypes.WinError(ctypes.get_last_error())}"
				]
			while True:
				try:
					if self._active_process_count(handle) == 0:
						self._termination_succeeded = True
						return [
							f"Terminated {active_before} process(es) from the "
							"owned Windows Job Object."
						]
				except OSError as error:
					self.cleanup_failed = True
					return [f"Could not confirm Windows Job Object cleanup: {error}"]
				now = time.perf_counter()
				if now >= deadline:
					self.deadline_late = True
					return [
						"Owned Windows Job Object cleanup could not be confirmed "
						"before its absolute deadline."
					]
				time.sleep(min(0.01, max(0.0, deadline - now)))

		def confirm_cleanup_after_reap_before_deadline(
			self,
			deadline: float,
		) -> list[str]:
			self._cleanup_confirmation_succeeded = False
			with self._handle_state_lock:
				handle = self.handle
			if handle == 0:
				self._cleanup_confirmation_succeeded = self.close_succeeded()
				return []
			while True:
				try:
					if self._active_process_count(handle) == 0:
						self._cleanup_confirmation_succeeded = True
						return []
				except OSError as error:
					self.cleanup_failed = True
					return [f"Could not confirm Windows Job Object cleanup: {error}"]
				now = time.perf_counter()
				if now >= deadline:
					self.deadline_late = True
					return [
						"Windows Job Object cleanup could not be confirmed before "
						"its absolute deadline."
					]
				time.sleep(min(0.01, max(0.0, deadline - now)))

		def close(self) -> list[str]:
			with self._handle_state_lock:
				already_closed = self.handle == 0 and self._close_operation is None
			if already_closed:
				self._closed = True
			if already_closed:
				return []
			outcome = _close_windows_handle_in_worker(self)
			if outcome.called and outcome.result is False:
				self.cleanup_failed = True
			if outcome.error is not None:
				raise BaseException.with_traceback(
					outcome.error,
					outcome.error_traceback,
				)
			if outcome.result is False:
				return [f"Could not close the owned Windows Job Object: {ctypes.WinError(outcome.last_error)}"]
			return []

		def close_before_deadline(self, deadline: float) -> list[str]:
			with self._handle_state_lock:
				operation = self._close_operation
				if operation is None:
					if self.handle == 0:
						self._closed = True
						return []
					operation = _WindowsHandleCloseOperation(self.handle)
					self._close_operation = operation
					self.handle = 0
					self._closed = False
					self._close_succeeded = False

			(
				notes,
				worker_active,
				pending_error,
				pending_traceback,
			) = _launch_windows_handle_close_before_deadline(
				self,
				operation,
			)
			if not worker_active:
				self.cleanup_failed = True
				notes.append("Windows Job Object close worker could not be retained.")
				if pending_error is not None:
					raise pending_error.with_traceback(pending_traceback)
				return notes
			while not operation.finished.is_set():
				remaining = deadline - time.perf_counter()
				if remaining <= 0.0:
					self.deadline_late = True
					notes.append(
						"Windows Job Object close could not be confirmed before "
						"its absolute deadline."
					)
					if pending_error is not None:
						raise pending_error.with_traceback(pending_traceback)
					return notes
				operation.finished.wait(min(0.01, remaining))
			outcome = _windows_handle_close_outcome(
				operation,
				pending_error,
				pending_traceback,
			)
			if outcome.called and outcome.result is False:
				self.cleanup_failed = True
			if outcome.error is not None:
				raise outcome.error.with_traceback(outcome.error_traceback)
			if outcome.result is False:
				notes.append(
					f"Could not close the owned Windows Job Object: "
					f"{ctypes.WinError(outcome.last_error)}"
				)
				return notes
			if time.perf_counter() > deadline:
				self.deadline_late = True
				notes.append("Windows Job Object close exceeded its absolute deadline.")
			return notes

		def wait_for_close_completion(self, timeout_seconds: float | None) -> bool:
			with self._handle_state_lock:
				operation = self._close_operation
			if operation is None:
				return self.is_closed()
			if timeout_seconds is None:
				operation.finished.wait()
			else:
				operation.finished.wait(max(0.0, timeout_seconds))
			return operation.finished.is_set() and self.is_closed()

		def close_terminates_tree(self) -> bool:
			return True

def _new_process_tree_owner() -> _ProcessTreeOwner:
	if os.name == "nt":
		return _WindowsJobOwner()
	return _PosixProcessGroupOwner()


@dataclass(frozen=True)
class SupervisedProcessResult:
	"""One command result with an explicit platform-boundary cleanup proof.

	``process_boundary_quiescent`` is true only when the Windows Job Object was
	observed empty, or the POSIX process group was absent/contained no executable
	members, before its owner was released (or no process was ever started). On
	POSIX this does not claim
	containment against a descendant that deliberately leaves the owned group.
	The field is independent of command success, timeout/cancellation, and output
	completeness.
	"""

	return_code: int
	stdout: str
	stderr: str
	timed_out: bool
	duration_seconds: float
	pid: int
	notes: tuple[str, ...] = ()
	cancelled: bool = False
	stdout_truncated: bool = False
	stderr_truncated: bool = False
	process_boundary_quiescent: bool = False


class _LocalSupervisedProcessLeaseBackend:
	"""Caller-owned long-lived process tree with one immutable lifetime deadline.

	Lease stdout and stderr are routed directly to ``DEVNULL``.  This is a
	zero-byte, intrinsically bounded output policy intended for services that own
	their durable diagnostics separately (for example Godot's explicit log file).
	No supervisor or output-helper thread exists behind this object.
	"""

	def __init__(
		self,
		owner: _ProcessTreeOwner,
		process: subprocess.Popen[bytes],
		*,
		command: tuple[str, ...],
		cwd: Path,
		started_at: float,
		deadline: float,
	) -> None:
		self._owner = owner
		self._process = process
		self.command = command
		self.cwd = cwd
		self.started_at = started_at
		self.deadline = deadline
		available_seconds = max(0.0, deadline - started_at)
		self.cleanup_reserve_seconds = min(
			PROCESS_LEASE_CLEANUP_RESERVE_SECONDS,
			available_seconds * 0.5,
		)
		self.operation_deadline = deadline - self.cleanup_reserve_seconds
		self._result: SupervisedProcessResult | None = None
		self._closing = False
		self._close_claim_lock = threading.Lock()
		self._close_finished = threading.Event()
		self._close_owner_thread_id: int | None = None
		self._close_terminal_error: BaseException | None = None
		self._close_terminal_traceback: Any = None
		self._deferred_cleanup_handle: SupervisedBinaryCleanupHandle | None = None

	@property
	def pid(self) -> int:
		return self._process.pid

	def poll_health(self) -> None:
		"""Fail when the service exited or exhausted its immutable lifetime."""
		if self._result is not None:
			raise RuntimeError("Supervised process lease is already closed.")
		if time.perf_counter() >= self.deadline:
			raise TimeoutError(
				"Supervised process lease reached its absolute lifetime deadline."
			)
		try:
			direct_exited = self._owner.wait_for_direct_exit(self._process, 0.0)
		except Exception as error:
			raise RuntimeError(
				"Could not inspect the supervised process lease direct child."
			) from error
		if direct_exited:
			raise RuntimeError(
				"Supervised process lease direct child exited before cancellation."
			)

	def poll_operation_health(self) -> None:
		"""Fail when the child exits or the operation portion of its lease ends."""
		self.poll_health()
		if time.perf_counter() >= self.operation_deadline:
			raise TimeoutError(
				"Supervised process lease reached its operation deadline; its remaining "
				"lifetime is reserved for cleanup."
			)

	def cancel_and_close(self, *, deadline: float) -> SupervisedProcessResult:
		"""Cancel and close while retaining the first asynchronous interruption."""
		if (
			isinstance(deadline, bool)
			or not isinstance(deadline, (int, float))
			or not math.isfinite(float(deadline))
		):
			raise ValueError("Process lease close deadline must be finite.")
		deadline = float(deadline)
		if deadline != self.deadline:
			raise ValueError(
				"Process lease close must reuse its original absolute lifetime deadline."
			)
		claim_error: BaseException | None = None
		claim_traceback: Any = None
		try:
			owns_close = self._claim_close_before_deadline(deadline)
		except BaseException as error:
			claim_error = error
			claim_traceback = safe_exception_traceback(error)
			owns_close = self._claim_close_before_deadline(deadline)
		if not owns_close:
			try:
				shared_result = self._wait_for_close_owner_before_deadline(deadline)
			except BaseException as close_error:
				if claim_error is None:
					raise
				if isinstance(close_error, SupervisedProcessCleanupError):
					if close_error.original_error is None:
						close_error.original_error = claim_error
					raise close_error from claim_error
				add_exception_note(
					claim_error,
					"Concurrent process lease close also raised "
					f"{type(close_error).__name__} after reaching its terminal boundary.",
				)
				raise claim_error.with_traceback(claim_traceback) from close_error
			if claim_error is not None:
				raise claim_error.with_traceback(claim_traceback)
			return shared_result
		try:
			try:
				result = self._cancel_and_close_impl(
					deadline=deadline,
					initial_error=claim_error,
					initial_traceback=claim_traceback,
				)
			except BaseException as initial_error:
				initial_traceback = safe_exception_traceback(initial_error)
				if exception_has_cleanup_debt(initial_error):
					raise
				if self._result is not None:
					raise initial_error.with_traceback(initial_traceback)
				try:
					result = self._cancel_and_close_impl(
						deadline=deadline,
						initial_error=initial_error,
						initial_traceback=initial_traceback,
					)
				except SupervisedProcessCleanupError as cleanup_error:
					if cleanup_error.original_error is None:
						cleanup_error.original_error = initial_error
					raise cleanup_error from initial_error
		except BaseException as terminal_error:
			self._publish_close_terminal_error(terminal_error)
			raise
		self._publish_close_terminal_error(None)
		return result

	def _claim_close_before_deadline(self, deadline: float) -> bool:
		if self._close_finished.is_set():
			return False
		remaining = max(0.0, deadline - time.perf_counter())
		acquired = (
			self._close_claim_lock.acquire(blocking=False)
			if remaining <= 0.0
			else self._close_claim_lock.acquire(timeout=remaining)
		)
		if not acquired:
			raise TimeoutError("Process lease close claim exceeded its absolute deadline.")
		try:
			owner_thread_id = self._close_owner_thread_id
			current_thread_id = threading.get_ident()
			if self._close_finished.is_set():
				return False
			if owner_thread_id is None:
				self._close_owner_thread_id = current_thread_id
				self._closing = True
				return True
			return owner_thread_id == current_thread_id
		finally:
			self._close_claim_lock.release()

	def _wait_for_close_owner_before_deadline(self, deadline: float) -> SupervisedProcessResult:
		if not self._close_finished.is_set():
			remaining = max(0.0, deadline - time.perf_counter())
			if remaining <= 0.0 or not self._close_finished.wait(remaining):
				raise SupervisedProcessCleanupError(
					"Concurrent process lease close did not publish terminal evidence before "
					"the shared absolute deadline.",
					pid=self.pid,
				)
		# Event publication is the terminal memory barrier.  Consume an already
		# published result/error without reacquiring a lock after the deadline.
		terminal_error = self._close_terminal_error
		terminal_traceback = self._close_terminal_traceback
		result = self._result
		if terminal_error is not None:
			raise terminal_error.with_traceback(terminal_traceback)
		if result is None:
			raise SupervisedProcessCleanupError(
				"Concurrent process lease close finished without terminal evidence.",
				pid=self.pid,
			)
		return result

	def _publish_close_terminal_error(self, error: BaseException | None) -> None:
		with self._close_claim_lock:
			self._close_terminal_error = error
			self._close_terminal_traceback = (
				safe_exception_traceback(error) if error is not None else None
			)
			self._close_finished.set()

	def _cancel_and_close_impl(
		self,
		*,
		deadline: float,
		initial_error: BaseException | None = None,
		initial_traceback: Any = None,
	) -> SupervisedProcessResult:
		_process_supervision_checkpoint("process_lease_close_impl_entered")
		if self._result is not None:
			return self._result
		notes = [
			"Long-lived process stdout and stderr used the zero-byte DEVNULL policy."
		]
		pending_error = initial_error
		pending_traceback = initial_traceback
		if initial_error is not None:
			notes.append(
				"Long-lived close entry was interrupted before cleanup choreography: "
				f"{type(initial_error).__name__}."
			)

		def record_error(action: str, error: BaseException) -> None:
			nonlocal pending_error, pending_traceback
			pending_error, pending_traceback = _select_preferred_cleanup_error(
				pending_error,
				pending_traceback,
				error,
				context=f"long-lived {action}",
			)
			notes.append(
				f"Long-lived {action} failed: {type(error).__name__}."
			)

		def checkpoint(name: str) -> None:
			try:
				_process_supervision_checkpoint(name)
			except BaseException as error:
				record_error(f"{name} checkpoint", error)

		direct_running_before_cancel: bool | None = None
		try:
			direct_running_before_cancel = not self._owner.wait_for_direct_exit(
				self._process,
				0.0,
			)
		except BaseException as error:
			record_error("pre-cancellation direct-child observation", error)
		direct_reaped = False
		cleanup_confirmation_complete = False
		checkpoint("process_lease_before_terminate")
		try:
			notes.extend(self._owner.terminate_before_deadline(self._process, deadline))
		except BaseException as error:
			record_error("process-tree termination", error)

		# DEVNULL has no caller-owned pipe and is therefore already drained.
		termination_succeeded = False
		try:
			termination_succeeded = self._owner.termination_succeeded()
		except BaseException as error:
			record_error("process-tree termination proof", error)
		if termination_succeeded:
			checkpoint("process_lease_before_reap")
			try:
				direct_reaped = _reap_direct_process_before_deadline(
					self._process,
					deadline,
					notes,
				)
			except BaseException as error:
				record_error("direct-child reap", error)
		if direct_reaped:
			checkpoint("process_lease_before_confirm")
			try:
				notes.extend(
					self._owner.confirm_cleanup_after_reap_before_deadline(deadline)
				)
				cleanup_confirmation_complete = (
					self._owner.cleanup_confirmation_succeeded()
				)
			except BaseException as error:
				record_error("process-tree confirmation", error)

		checkpoint("process_lease_before_close")
		try:
			notes.extend(self._owner.close_before_deadline(deadline))
		except BaseException as error:
			record_error("process-tree owner close", error)

		# Windows kill-on-close is the final kernel boundary if explicit Job
		# termination could not be confirmed. Reap only after close published its
		# atomic outcome; POSIX never signals or reaps by this fallback.
		owner_closed = False
		close_succeeded = False
		close_terminates_tree = False
		for action_name, action in (
			("owner-close completion proof", self._owner.is_closed),
			("owner-close success proof", self._owner.close_succeeded),
			("owner-close tree policy", self._owner.close_terminates_tree),
		):
			try:
				value = bool(action())
			except BaseException as error:
				record_error(action_name, error)
				value = False
			if action_name == "owner-close completion proof":
				owner_closed = value
			elif action_name == "owner-close success proof":
				close_succeeded = value
			else:
				close_terminates_tree = value
		closed_tree_boundary = (
			close_terminates_tree and owner_closed and close_succeeded
		)
		if closed_tree_boundary and not direct_reaped:
			try:
				direct_reaped = _reap_direct_process_before_deadline(
					self._process,
					deadline,
					notes,
				)
			except BaseException as error:
				record_error("direct-child reap after owner close", error)
		process_tree_empty = (
			(
				termination_succeeded
				and cleanup_confirmation_complete
			)
			or closed_tree_boundary
		)
		boundary_quiescent = (
			owner_closed
			and direct_reaped
			and process_tree_empty
			and (closed_tree_boundary or not self._owner.cleanup_failed)
		)
		deadline_respected = (
			time.perf_counter() <= deadline and not self._owner.deadline_late
		)
		if not deadline_respected:
			notes.append(
				"Long-lived process cleanup exceeded its original absolute lifetime deadline."
			)
		if not boundary_quiescent:
			status = SupervisedBinaryCleanupStatus(
				complete=True,
				cleanup_complete=False,
				owner_closed=owner_closed,
				process_tree_empty=process_tree_empty,
				pid=self._process.pid,
				notes=tuple(notes),
			)
			deferred_cleanup = self._deferred_cleanup_handle
			if deferred_cleanup is None:
				deferred_operation = _LeaseDeferredCleanupOperation(
					self._owner,
					self._process,
					owner_closed=owner_closed,
					process_tree_empty=process_tree_empty,
					direct_reaped=direct_reaped,
					cleanup_confirmation_complete=cleanup_confirmation_complete,
					notes=tuple(notes),
				)
				deferred_cleanup = SupervisedBinaryCleanupHandle(deferred_operation)
				# Publish retained authority on the lease before starting any worker.
				self._deferred_cleanup_handle = deferred_cleanup
			else:
				deferred_operation = deferred_cleanup._operation
			try:
				deferred_operation.launch()
			except BaseException as error:
				record_error("deferred cleanup launch", error)
			cleanup_error = SupervisedProcessCleanupError(
				"Long-lived process lease closed without a proven quiet boundary.",
				notes=tuple(notes),
				pid=self._process.pid,
				owner_closed=owner_closed,
				process_tree_empty=process_tree_empty,
				direct_reaped=direct_reaped,
				cleanup_confirmation_complete=cleanup_confirmation_complete,
				cleanup_status=status,
				deferred_cleanup=deferred_cleanup,
			)
			if pending_error is not None:
				cleanup_error.original_error = pending_error
				raise cleanup_error from pending_error
			raise cleanup_error

		result = SupervisedProcessResult(
			return_code=(
				self._process.returncode
				if self._process.returncode is not None
				else 124
			),
			stdout="",
			stderr="",
			timed_out=not deadline_respected,
			duration_seconds=time.perf_counter() - self.started_at,
			pid=self._process.pid,
			notes=tuple(notes),
			cancelled=direct_running_before_cancel is True,
			stdout_truncated=False,
			stderr_truncated=False,
			process_boundary_quiescent=True,
		)
		self._result = result
		if pending_error is not None:
			raise pending_error.with_traceback(pending_traceback)
		return result


class SupervisedProcessLeasePublicationSlot:
	"""Caller-owned lease reference published before spawn authority transfers.

	The slot uses a deadline-bounded compare-and-set lock. The reference assignment
	is the publication commit point: asynchronous control flow can interrupt the
	surrounding call, but competing starters cannot overwrite an existing lease.
	Callers must retain the slot before asking the supervisor to create a child.
	"""

	def __init__(self) -> None:
		self._lease: Any = None
		self._publication_lock = threading.Lock()

	@property
	def has_lease(self) -> bool:
		return self._lease is not None

	def publish(self, lease: Any, *, deadline: float) -> None:
		if type(lease) is not SupervisedProcessLease:
			raise TypeError(
				"Process lease publication accepts only the public lease facade."
			)
		remaining = max(0.0, deadline - time.perf_counter())
		if remaining <= 0.0 or not self._publication_lock.acquire(timeout=remaining):
			raise TimeoutError("Process lease publication exceeded its absolute deadline.")
		try:
			current = self._lease
			if current is not None and current is not lease:
				raise RuntimeError("Process lease publication slot was already occupied.")
			self._lease = lease
		finally:
			self._publication_lock.release()

	def contains(self, lease: Any) -> bool:
		return self._lease is lease

	def get(self) -> Any:
		lease = self._lease
		if lease is None:
			raise RuntimeError("Process lease publication slot is empty.")
		return lease


def start_supervised_process_lease(
	command: list[str],
	*,
	cwd: Path,
	deadline: float,
	environment: dict[str, str],
	publication_slot: SupervisedProcessLeasePublicationSlot,
) -> SupervisedProcessLease:
	"""Start a caller-owned long-lived process with a fixed monotonic deadline."""
	if environment is None:
		raise TypeError("Supervised process lease requires an explicit environment.")
	if type(publication_slot) is not SupervisedProcessLeasePublicationSlot:
		raise TypeError(
			"Supervised process lease requires its concrete caller-owned publication slot."
		)
	if (
		isinstance(deadline, bool)
		or not isinstance(deadline, (int, float))
		or not math.isfinite(float(deadline))
	):
		raise ValueError("Process lease deadline must be a finite monotonic timestamp.")
	deadline = float(deadline)
	started_at = time.perf_counter()
	if deadline <= started_at:
		raise TimeoutError("Process lease deadline expired before process creation.")
	if os.name != "nt":
		if sys.platform != "linux":
			raise NotImplementedError(
				"Long-lived supervised POSIX leases require Linux /proc evidence; "
				"this platform is rejected before helper or service creation."
			)
		return _start_posix_watchdog_process_lease(
			command,
			cwd=cwd,
			deadline=deadline,
			environment=environment,
			publication_slot=publication_slot,
			started_at=started_at,
		)
	return _start_local_supervised_process_lease(
		command,
		cwd=cwd,
		deadline=deadline,
		environment=environment,
		publication_slot=publication_slot,
		started_at=started_at,
	)


def _start_local_supervised_process_lease(
	command: list[str],
	*,
	cwd: Path,
	deadline: float,
	environment: dict[str, str],
	publication_slot: SupervisedProcessLeasePublicationSlot,
	started_at: float,
) -> SupervisedProcessLease:
	spawn_operation = _BinarySpawnOperation(
		command,
		cwd=cwd,
		environment=environment,
		max_stdout_bytes=1,
		max_stderr_bytes=1,
		capture_output=False,
		worker_daemon=False,
		deferred_claim_ack=True,
	)
	try:
		spawn_operation.launch()
		handoff = spawn_operation.claim_before_deadline(deadline)
	except BaseException as start_error:
		preferred_error = start_error
		preferred_traceback = safe_exception_traceback(start_error)
		spawn_operation.abandon(deadline=deadline)
		try:
			spawn_operation.wait(max(0.0, deadline - time.perf_counter()))
		except BaseException as cleanup_wait_error:
			preferred_error, preferred_traceback = _select_preferred_cleanup_error(
				preferred_error,
				preferred_traceback,
				cleanup_wait_error,
				context="process lease spawn cleanup wait",
			)
		if exception_has_cleanup_debt(start_error):
			if preferred_error is not start_error:
				if isinstance(start_error, SupervisedProcessCleanupError):
					start_error.original_error = preferred_error
				raise start_error from preferred_error
			raise start_error.with_traceback(preferred_traceback)
		status = spawn_operation.snapshot_before_deadline(deadline)
		_raise_binary_original_or_cleanup_debt(
			preferred_error,
			preferred_traceback,
			message="Process lease start failed without a proven quiet boundary.",
			status=status,
			deferred_cleanup=(
				None
				if status.complete
				else SupervisedBinaryCleanupHandle(spawn_operation)
			),
		)
	if handoff is None:
		start_error = TimeoutError(
			"Process lease creation did not complete before its absolute lifetime deadline."
		)
		status = spawn_operation.snapshot_before_deadline(deadline)
		_raise_binary_original_or_cleanup_debt(
			start_error,
			safe_exception_traceback(start_error),
			message="Process lease spawn remained active beyond its lifetime deadline.",
			status=status,
			deferred_cleanup=SupervisedBinaryCleanupHandle(spawn_operation),
		)
	owner = handoff.owner
	process = handoff.process
	backend = _LocalSupervisedProcessLeaseBackend(
		owner,
		process,
		command=tuple(command),
		cwd=cwd,
		started_at=started_at,
		deadline=deadline,
	)
	lease = SupervisedProcessLease._from_backend(backend)
	claim_acknowledged = False
	try:
		if getattr(process, "_gf_process_tree_owner", None) is not owner:
			raise RuntimeError(
				"Started process lease lost its process-tree owner binding."
			)
		if process.stdout is not None or process.stderr is not None:
			raise RuntimeError(
				"Process lease violated its zero-byte DEVNULL output policy."
			)
		if time.perf_counter() > deadline:
			raise TimeoutError(
				"Process lease creation exceeded its absolute lifetime deadline."
			)
		_process_supervision_checkpoint("process_lease_before_claim_ack")
		claim_acknowledged = spawn_operation.acknowledge_claim(
			handoff,
			lease=lease,
			publication_slot=publication_slot,
			deadline=deadline,
		)
		if not claim_acknowledged:
			raise TimeoutError(
				"Process lease handoff was not acknowledged before its lifetime deadline."
			)
		return lease
	except BaseException as start_error:
		preferred_error = start_error
		preferred_traceback = safe_exception_traceback(start_error)
		if not claim_acknowledged:
			claim_acknowledged = spawn_operation.claim_acknowledged_before_deadline(
				deadline
			)
		if not claim_acknowledged:
			spawn_operation.abandon(deadline=deadline)
			try:
				spawn_operation.wait(max(0.0, deadline - time.perf_counter()))
			except BaseException as cleanup_wait_error:
				preferred_error, preferred_traceback = (
					_select_preferred_cleanup_error(
						preferred_error,
						preferred_traceback,
						cleanup_wait_error,
						context="process lease handoff cleanup wait",
					)
				)
			if exception_has_cleanup_debt(start_error):
				if preferred_error is not start_error:
					if isinstance(start_error, SupervisedProcessCleanupError):
						start_error.original_error = preferred_error
					raise start_error from preferred_error
				raise start_error.with_traceback(preferred_traceback)
			status = spawn_operation.snapshot_before_deadline(deadline)
			_raise_binary_original_or_cleanup_debt(
				preferred_error,
				preferred_traceback,
				message="Process lease handoff failed without a proven quiet boundary.",
				status=status,
				deferred_cleanup=SupervisedBinaryCleanupHandle(spawn_operation),
			)
		try:
			lease.cancel_and_close(deadline=deadline)
		except BaseException as cleanup_error:
			preferred_error, preferred_traceback = _select_preferred_cleanup_error(
				start_error,
				safe_exception_traceback(start_error),
				cleanup_error,
				context="acknowledged process lease start cleanup",
			)
			if isinstance(cleanup_error, SupervisedProcessCleanupError):
				cleanup_error.original_error = preferred_error
				raise cleanup_error from preferred_error
			raise preferred_error.with_traceback(preferred_traceback)
		raise


@dataclass(frozen=True)
class SupervisedBinaryCleanupStatus:
	complete: bool
	cleanup_complete: bool
	owner_closed: bool
	process_tree_empty: bool
	pid: int
	notes: tuple[str, ...] = ()
	error_type: str = ""


@dataclass(frozen=True)
class SupervisedBinaryProcessResult:
	return_code: int
	stdout: bytes
	stderr: bytes
	timed_out: bool
	duration_seconds: float
	pid: int
	notes: tuple[str, ...] = ()
	stdout_truncated: bool = False
	stderr_truncated: bool = False
	output_drain_failed: bool = False
	cleanup_complete: bool = False
	deferred_cleanup: SupervisedBinaryCleanupHandle | None = None


@dataclass
class _BoundedBinaryPipeState:
	pipe: Any
	max_bytes: int
	chunks: list[bytes]
	byte_count: int = 0
	eof: bool = False
	truncated: bool = False
	read_failed: bool = False


class _PosixWatchdogProtocolError(RuntimeError):
	"""The independent POSIX watchdog violated its strict status protocol."""


def _close_pipe_fd(fd: int) -> None:
	try:
		os.close(fd)
	except OSError:
		pass


class _PosixWatchdogHelperProcess:
	"""Wait-safe facade for the isolated watchdog helper process."""

	def __init__(
		self,
		process: subprocess.Popen[bytes],
		pidfd_stream: BinaryIO,
	) -> None:
		if process.stdin is None or process.stdout is None:
			raise RuntimeError(
				"POSIX watchdog did not expose control and status pipes."
			)
		self._process = process
		self.pid = process.pid
		self.stdin = process.stdin
		self.stdout = process.stdout
		self.returncode = process.returncode
		self._pidfd_stream: BinaryIO | None = pidfd_stream
		self._wait_lock = threading.Lock()

	def poll(self) -> int | None:
		with self._wait_lock:
			if self.returncode is not None:
				return self.returncode
			pidfd_stream = self._pidfd_stream
			if pidfd_stream is None or pidfd_stream.closed:
				return None
			try:
				pidfd = pidfd_stream.fileno()
			except (OSError, ValueError):
				return None
			try:
				readable, _writable, _errors = select.select(
					[pidfd], [], [], 0.0
				)
			except (OSError, ValueError):
				return None
			if not readable:
				return None
			try:
				return_code = self._process.poll()
			except ChildProcessError:
				# pidfd readability proves this exact helper exited. ECHILD means
				# SIGCHLD=SIG_IGN/SA_NOCLDWAIT auto-reaped it, or an interrupted
				# prior waitpid already consumed it; both are terminal ownership proof.
				return_code = 0
				self._process.returncode = return_code
			except Exception:
				return None
			if return_code is None:
				return None
			self.returncode = int(return_code)
			return self.returncode

	def close_pidfd(self) -> None:
		pending_error: BaseException | None = None
		pending_traceback: Any = None
		with self._wait_lock:
			pidfd_stream = self._pidfd_stream
			if pidfd_stream is None:
				return
			try:
				pidfd_stream.close()
			except BaseException as error:
				pending_error = error
				pending_traceback = safe_exception_traceback(error)
			if pidfd_stream.closed:
				self._pidfd_stream = None
		if pending_error is not None:
			raise pending_error.with_traceback(pending_traceback)

	def pidfd_closed(self) -> bool:
		with self._wait_lock:
			stream = self._pidfd_stream
			return stream is None or stream.closed

	def wait(self, timeout: float | None = None) -> int:
		deadline = None if timeout is None else time.perf_counter() + max(0.0, timeout)
		while True:
			return_code = self.poll()
			if return_code is not None:
				return return_code
			if deadline is not None and time.perf_counter() >= deadline:
				raise subprocess.TimeoutExpired(
					("gf-posix-process-watchdog",), timeout
				)
			time.sleep(
				BINARY_PROCESS_POLL_SECONDS
				if deadline is None
				else min(
					BINARY_PROCESS_POLL_SECONDS,
					max(0.0, deadline - time.perf_counter()),
				)
			)


def _spawn_posix_watchdog_helper(
	*,
	helper_path: Path,
	deadline_ns: int,
	nonce: str,
	publication: Callable[[_PosixWatchdogHelperProcess], None],
) -> _PosixWatchdogHelperProcess:
	"""Start the isolated helper and retain it across every later failure."""
	helper_process: subprocess.Popen[bytes] | None = None
	helper_pidfd = -1
	helper_pidfd_stream: BinaryIO | None = None
	helper: _PosixWatchdogHelperProcess | None = None
	try:
		helper_environment = {"LC_ALL": "C", "LANG": "C"}
		executable = str(Path(sys.executable).resolve())
		arguments = [
			executable,
			"-I",
			"-S",
			"-X",
			"utf8",
			str(helper_path),
			"--control-fd", "0",
			"--status-fd", "1",
			"--deadline-ns", str(deadline_ns),
			"--nonce", nonce,
		]
		helper_process = subprocess.Popen(
			arguments,
			stdin=subprocess.PIPE,
			stdout=subprocess.PIPE,
			stderr=subprocess.DEVNULL,
			cwd=str(helper_path.parent),
			env=helper_environment,
			start_new_session=True,
			close_fds=True,
			bufsize=0,
		)
		pidfd_open = getattr(os, "pidfd_open", None)
		if not callable(pidfd_open):
			raise NotImplementedError("POSIX watchdog helper requires Linux pidfd_open.")
		helper_pidfd = int(pidfd_open(helper_process.pid, 0))
		helper_pidfd_stream = os.fdopen(helper_pidfd, "rb", buffering=0)
		helper_pidfd = -1
		helper = _PosixWatchdogHelperProcess(
			helper_process,
			helper_pidfd_stream,
		)
		helper_pidfd_stream = None
		publication(helper)
		return helper
	except BaseException:
		if helper is not None:
			try:
				helper.stdin.close()
			except BaseException:
				pass
			try:
				helper.stdout.close()
			except BaseException:
				pass
			while helper.poll() is None:
				try:
					time.sleep(BINARY_PROCESS_POLL_SECONDS)
				except BaseException:
					continue
			helper.close_pidfd()
		elif helper_process is not None:
			for stream in (helper_process.stdin, helper_process.stdout):
				if stream is not None:
					try:
						stream.close()
					except BaseException:
						pass
			while helper_process.poll() is None:
				try:
					time.sleep(BINARY_PROCESS_POLL_SECONDS)
				except BaseException:
					continue
		if helper_pidfd >= 0:
			pidfd = helper_pidfd
			helper_pidfd = -1
			_close_pipe_fd(pidfd)
		if helper_pidfd_stream is not None:
			try:
				helper_pidfd_stream.close()
			except BaseException:
				pass
		raise


class _PosixWatchdogTransport:
	"""Authenticated parent-side transport to one independent watchdog helper."""

	def __init__(
		self,
		helper: _PosixWatchdogHelperProcess,
		*,
		nonce: str,
		deadline: float,
		deadline_ns: int,
	) -> None:
		if helper.stdin is None or helper.stdout is None:
			raise RuntimeError("POSIX watchdog did not expose control and status pipes.")
		self.helper = helper
		self.nonce = nonce
		self.deadline = deadline
		self.deadline_ns = deadline_ns
		self._control = helper.stdin
		self._status = helper.stdout
		self._control_io_lock = threading.Lock()
		self._status_io_lock = threading.Lock()
		self._state_lock = threading.Lock()
		# The production transport is Linux-only, but its authenticated protocol is
		# exercised on every supported Python. Windows Python before 3.12 cannot
		# make anonymous pipes non-blocking, so cross-host parsing uses the same
		# PeekNamedPipe boundary as binary capture instead of risking a blocking read.
		self._uses_windows_status_peek = os.name == "nt"
		if not self._uses_windows_status_peek:
			os.set_blocking(self._control.fileno(), False)
			os.set_blocking(self._status.fileno(), False)
		self._status_buffer = bytearray()
		self._status_eof = False
		self._ready = False
		self._server_pid = 0
		self._quiet: dict[str, Any] | None = None
		self._helper_return_code: int | None = None
		self._protocol_error: BaseException | None = None
		self._protocol_traceback: Any = None
		self._control_closed = False
		self._finalized = False
		self._notes: list[str] = []

	@property
	def server_pid(self) -> int:
		with self._state_lock:
			return self._server_pid

	@property
	def ready(self) -> bool:
		with self._state_lock:
			return self._ready

	def publish_config_frame(self, frame: bytes, *, deadline: float) -> None:
		self._write_control_frame(frame, deadline=deadline)

	def request_cancel(self, *, deadline: float) -> None:
		with self._state_lock:
			already_closed = self._control_closed
		if already_closed:
			return
		self._write_control_message(
			{
				"version": POSIX_WATCHDOG_PROTOCOL_VERSION,
				"nonce": self.nonce,
				"type": "CANCEL",
			},
			deadline=deadline,
		)

	def close_control(self) -> None:
		pending_error: BaseException | None = None
		pending_traceback: Any = None
		with self._control_io_lock:
			with self._state_lock:
				if self._control_closed:
					return
			try:
				self._control.close()
			except BaseException as error:
				pending_error = error
				pending_traceback = safe_exception_traceback(error)
			with self._state_lock:
				self._control_closed = self._control.closed
		if pending_error is not None:
			raise pending_error.with_traceback(pending_traceback)

	def wait_ready_before_deadline(self, deadline: float) -> int:
		while True:
			self._pump_status_once(deadline=deadline, wait=True)
			with self._state_lock:
				quiet = self._quiet
				ready = self._ready
				server_pid = self._server_pid
				eof = self._status_eof
				helper_return_code = self._helper_return_code
			if quiet is not None:
				raise OSError(
					"POSIX watchdog reached a quiet boundary before service startup "
					f"(trigger={quiet['trigger']}, return_code={quiet['return_code']})."
				)
			if eof:
				raise _PosixWatchdogProtocolError(
					"POSIX watchdog status closed without READY or terminal quiet evidence."
				)
			if ready:
				return server_pid
			if time.perf_counter() >= deadline:
				raise TimeoutError(
					"POSIX watchdog did not publish READY before the lease deadline."
				)

	def poll(self) -> None:
		with self._state_lock:
			finalized = self._finalized
		if finalized:
			return
		self._pump_status_once(deadline=None, wait=False)

	def wait_quiet_and_reaped(self, deadline: float | None) -> bool:
		pending_error: BaseException | None = None
		pending_traceback: Any = None
		while True:
			try:
				self._pump_status_once(deadline=deadline, wait=True)
			except BaseException as error:
				pending_error, pending_traceback = _select_preferred_cleanup_error(
					pending_error,
					pending_traceback,
					error,
					context="POSIX watchdog terminal observation",
				)
			with self._state_lock:
				quiet = self._quiet
				helper_return_code = self._helper_return_code
			if helper_return_code is not None:
				try:
					finalized = self.finalize()
				except BaseException as error:
					pending_error, pending_traceback = _select_preferred_cleanup_error(
						pending_error,
						pending_traceback,
						error,
						context="POSIX watchdog terminal finalization",
					)
					finalized = False
				if finalized:
					status = self.cleanup_status()
					if pending_error is not None:
						raise pending_error.with_traceback(pending_traceback)
					return status.cleanup_complete
			if deadline is not None and time.perf_counter() >= deadline:
				if pending_error is not None:
					raise pending_error.with_traceback(pending_traceback)
				return False
			if pending_error is not None:
				try:
					time.sleep(BINARY_PROCESS_POLL_SECONDS)
				except BaseException as error:
					pending_error, pending_traceback = _select_preferred_cleanup_error(
						pending_error,
						pending_traceback,
						error,
						context="POSIX watchdog terminal retry pause",
					)

	def quiet_payload(self) -> dict[str, Any] | None:
		with self._state_lock:
			return None if self._quiet is None else dict(self._quiet)

	def cleanup_status(self) -> SupervisedBinaryCleanupStatus:
		with self._state_lock:
			quiet = self._quiet
			helper_reaped = self._helper_return_code is not None
			server_pid = self._server_pid
			notes = tuple(self._notes)
			finalized = self._finalized
			protocol_error = self._protocol_error
		cleanup_complete = bool(
			quiet is not None
			and protocol_error is None
			and helper_reaped
			and finalized
			and quiet["tree_empty"] is True
			and (
				quiet["child_created"] is False
				or quiet["direct_reaped"] is True
			)
		)
		terminal = cleanup_complete or bool(helper_reaped and finalized)
		return SupervisedBinaryCleanupStatus(
			complete=terminal,
			cleanup_complete=cleanup_complete,
			owner_closed=helper_reaped and finalized,
			process_tree_empty=bool(quiet is not None and quiet["tree_empty"] is True),
			pid=server_pid,
			notes=notes,
			error_type=(
				type(protocol_error).__name__
				if protocol_error is not None
				else str(quiet["error_type"])
				if quiet is not None
				else ""
			),
		)

	def finalize(self) -> bool:
		pending_error: BaseException | None = None
		pending_traceback: Any = None

		def record(error: BaseException) -> None:
			nonlocal pending_error, pending_traceback
			pending_error, pending_traceback = _select_preferred_cleanup_error(
				pending_error,
				pending_traceback,
				error,
				context="POSIX watchdog transport finalization",
			)

		with self._state_lock:
			if self._finalized:
				return True
			if self._helper_return_code is None:
				return False
		with self._control_io_lock:
			try:
				self._control.close()
			except BaseException as error:
				record(error)
			with self._state_lock:
				self._control_closed = self._control.closed
		with self._status_io_lock:
			try:
				self._status.close()
			except BaseException as error:
				record(error)
		try:
			self.helper.close_pidfd()
		except BaseException as error:
			record(error)
		resources_closed = bool(
			self._control.closed
			and self._status.closed
			and self.helper.pidfd_closed()
		)
		with self._state_lock:
			self._finalized = resources_closed
		if pending_error is not None:
			raise pending_error.with_traceback(pending_traceback)
		return resources_closed

	def _write_control_message(
		self,
		payload: dict[str, Any],
		*,
		deadline: float,
	) -> None:
		self._write_control_frame(
			(
			json.dumps(payload, ensure_ascii=True, separators=(",", ":")).encode("ascii")
			+ b"\n"
			),
			deadline=deadline,
		)

	def _write_control_frame(self, encoded: bytes, *, deadline: float) -> None:
		if len(encoded) > POSIX_WATCHDOG_MAX_CONFIG_BYTES:
			raise ValueError("POSIX watchdog control frame exceeded its byte limit.")
		with self._control_io_lock:
			with self._state_lock:
				if self._control_closed:
					raise BrokenPipeError("POSIX watchdog control pipe closed.")
			view = memoryview(encoded)
			fd = self._control.fileno()
			while view:
				remaining = deadline - time.perf_counter()
				if remaining <= 0.0:
					raise TimeoutError(
						"POSIX watchdog control publication exceeded its deadline."
					)
				try:
					written = os.write(fd, view)
				except BlockingIOError:
					select.select([], [fd], [], min(0.05, remaining))
					continue
				if written <= 0:
					raise BrokenPipeError("POSIX watchdog control pipe closed.")
				view = view[written:]

	def _pump_status_once(self, *, deadline: float | None, wait: bool) -> None:
		pending_error: BaseException | None = None
		pending_traceback: Any = None
		with self._status_io_lock:
			with self._state_lock:
				if self._finalized:
					return
				if self._protocol_error is not None:
					pending_error = self._protocol_error
					pending_traceback = self._protocol_traceback
				fd: int | None = None
				if pending_error is None:
					try:
						fd = self._status.fileno()
					except (OSError, ValueError) as error:
						self._status_eof = True
						self._notes.append(
							"POSIX watchdog status descriptor became unavailable: "
							f"{type(error).__name__}."
						)
						pending_error = _PosixWatchdogProtocolError(
							"POSIX watchdog status descriptor became unavailable before "
							"a closed protocol boundary."
						)
						pending_traceback = safe_exception_traceback(pending_error)
						self._protocol_error = pending_error
						self._protocol_traceback = pending_traceback
			if wait and pending_error is None and fd is not None:
				timeout: float | None
				if deadline is None:
					timeout = 0.05
				else:
					remaining = max(0.0, deadline - time.perf_counter())
					timeout = min(0.05, remaining) if remaining > 0.0 else 0.0
				try:
					if self._uses_windows_status_peek:
						available, writer_closed = _windows_binary_pipe_available(
							self._status
						)
						if available <= 0 and not writer_closed and timeout > 0.0:
							time.sleep(timeout)
					else:
						select.select([fd], [], [], timeout)
				except (OSError, ValueError):
					pass
			with self._state_lock:
				while fd is not None and not self._status_eof:
					if self._protocol_error is not None:
						pending_error = self._protocol_error
						pending_traceback = self._protocol_traceback
						break
					try:
						if self._uses_windows_status_peek:
							available, writer_closed = _windows_binary_pipe_available(
								self._status
							)
							if writer_closed:
								chunk = b""
							elif available <= 0:
								break
							else:
								chunk = os.read(fd, min(4096, available))
						else:
							chunk = os.read(fd, 4096)
					except BlockingIOError:
						break
					except OSError as error:
						self._status_eof = True
						self._notes.append(
							"POSIX watchdog status read failed: "
							f"{type(error).__name__}."
						)
						pending_error = _PosixWatchdogProtocolError(
							"POSIX watchdog status read failed before a closed protocol boundary."
						)
						pending_traceback = safe_exception_traceback(pending_error)
						self._protocol_error = pending_error
						self._protocol_traceback = pending_traceback
						break
					if not chunk:
						self._status_eof = True
						if self._status_buffer or self._quiet is None:
							pending_error = _PosixWatchdogProtocolError(
								"POSIX watchdog status closed without an exact terminal QUIET frame."
							)
							pending_traceback = safe_exception_traceback(pending_error)
							self._protocol_error = pending_error
							self._protocol_traceback = pending_traceback
						break
					self._status_buffer.extend(chunk)
					if len(self._status_buffer) > POSIX_WATCHDOG_MAX_STATUS_BYTES:
						raise _PosixWatchdogProtocolError(
							"POSIX watchdog status exceeded its byte limit."
						)
					try:
						self._parse_status_lines_locked()
					except BaseException as error:
						pending_error = error
						pending_traceback = safe_exception_traceback(error)
						if isinstance(error, _PosixWatchdogProtocolError):
							self._protocol_error = error
							self._protocol_traceback = pending_traceback
						break
					if self._quiet is not None and self._status_buffer:
						pending_error = _PosixWatchdogProtocolError(
							"POSIX watchdog emitted trailing bytes after terminal QUIET."
						)
						pending_traceback = safe_exception_traceback(pending_error)
						self._protocol_error = pending_error
						self._protocol_traceback = pending_traceback
						break
		self._try_reap_helper()
		if isinstance(pending_error, _PosixWatchdogProtocolError):
			try:
				# Once the authenticated status channel is broken the service is no
				# longer observable.  Revoke its liveness authority immediately; do
				# not depend on an outer caller reaching a finally block.
				self.close_control()
			except BaseException as close_error:
				pending_error, pending_traceback = _select_preferred_cleanup_error(
					pending_error,
					pending_traceback,
					close_error,
					context="POSIX watchdog protocol-failure control close",
				)
		if pending_error is not None:
			raise pending_error.with_traceback(pending_traceback)

	def _try_reap_helper(self) -> None:
		with self._state_lock:
			if self._helper_return_code is not None:
				return
		try:
			return_code = self.helper.poll()
		except OSError:
			return
		if return_code is not None:
			with self._state_lock:
				self._helper_return_code = int(return_code)

	def _parse_status_lines_locked(self) -> None:
		while True:
			line_end = self._status_buffer.find(b"\n")
			if line_end < 0:
				return
			line = bytes(self._status_buffer[:line_end])
			del self._status_buffer[:line_end + 1]
			try:
				message = json.loads(line.decode("ascii"))
			except (UnicodeDecodeError, json.JSONDecodeError) as error:
				raise _PosixWatchdogProtocolError(
					"POSIX watchdog emitted malformed status JSON."
				) from error
			if not isinstance(message, dict):
				raise _PosixWatchdogProtocolError(
					"POSIX watchdog status was not an object."
				)
			self._accept_status_locked(message)

	def _accept_status_locked(self, message: dict[str, Any]) -> None:
		if (
			message.get("version") != POSIX_WATCHDOG_PROTOCOL_VERSION
			or message.get("nonce") != self.nonce
			or not isinstance(message.get("type"), str)
		):
			raise _PosixWatchdogProtocolError(
				"POSIX watchdog status authentication failed."
			)
		message_type = message["type"]
		if message_type == "READY":
			expected = {
				"version", "nonce", "type", "helper_pid", "server_pid",
				"process_group_id",
			}
			if set(message) != expected or self._ready or self._quiet is not None:
				raise _PosixWatchdogProtocolError(
					"POSIX watchdog READY transition was invalid."
				)
			helper_pid = message["helper_pid"]
			server_pid = message["server_pid"]
			if (
				type(helper_pid) is not int
				or helper_pid != self.helper.pid
				or type(server_pid) is not int
				or server_pid <= 0
				or message["process_group_id"] != server_pid
				or self._server_pid not in (0, server_pid)
			):
				raise _PosixWatchdogProtocolError(
					"POSIX watchdog READY process identity was invalid."
				)
			self._server_pid = server_pid
			self._ready = True
			return
		if message_type == "DEBT":
			expected = {
				"version", "nonce", "type", "helper_pid", "server_pid",
				"process_group_id", "child_created", "trigger",
			}
			server_pid = message.get("server_pid")
			if (
				set(message) != expected
				or message.get("helper_pid") != self.helper.pid
				or type(server_pid) is not int
				or server_pid <= 0
				or message.get("process_group_id") != server_pid
				or message.get("child_created") is not True
				or not isinstance(message.get("trigger"), str)
				or self._server_pid not in (0, server_pid)
				or self._quiet is not None
			):
				raise _PosixWatchdogProtocolError(
					"POSIX watchdog DEBT notice was invalid."
				)
			self._server_pid = server_pid
			self._notes.append(
				"POSIX watchdog cleanup remained active after its debt notice."
			)
			return
		if message_type == "QUIET":
			expected = {
				"version", "nonce", "type", "helper_pid", "server_pid",
				"process_group_id", "return_code", "trigger", "ready",
				"child_created", "tree_empty", "direct_reaped", "cancelled",
				"error_type",
			}
			if set(message) != expected or self._quiet is not None:
				raise _PosixWatchdogProtocolError(
					"POSIX watchdog QUIET transition was invalid."
				)
			server_pid = message["server_pid"]
			if (
				type(message["helper_pid"]) is not int
				or message["helper_pid"] != self.helper.pid
				or type(server_pid) is not int
				or server_pid < 0
				or message["process_group_id"] != server_pid
				or (self._server_pid not in (0, server_pid))
				or type(message["return_code"]) is not int
				or not isinstance(message["trigger"], str)
				or type(message["ready"]) is not bool
				or type(message["child_created"]) is not bool
				or type(message["tree_empty"]) is not bool
				or type(message["direct_reaped"]) is not bool
				or type(message["cancelled"]) is not bool
				or not isinstance(message["error_type"], str)
				or message["ready"] is not self._ready
				or (message["ready"] is True and message["child_created"] is not True)
				or (message["child_created"] is True and server_pid <= 0)
				or (message["child_created"] is False and server_pid != 0)
				or (
					message["child_created"] is False
					and (
						message["process_group_id"] != 0
						or message["ready"] is not False
						or message["tree_empty"] is not True
						or message["direct_reaped"] is not False
						or message["cancelled"] is not False
					)
				)
				or (
					message["child_created"] is True
					and (
						message["tree_empty"] is not True
						or message["direct_reaped"] is not True
					)
				)
			):
				raise _PosixWatchdogProtocolError(
					"POSIX watchdog QUIET evidence was invalid."
				)
			self._server_pid = server_pid
			self._quiet = dict(message)
			return
		raise _PosixWatchdogProtocolError(
			f"POSIX watchdog emitted unknown status type {message_type!r}."
		)


@dataclass(frozen=True)
class _PosixWatchdogSpawnHandoff:
	transport: _PosixWatchdogTransport


class _PosixWatchdogSpawnOperation:
	"""Retained non-daemon authority across helper Popen and lease publication."""

	def __init__(
		self,
		*,
		deadline: float,
		deadline_ns: int,
		nonce: str,
	) -> None:
		self._deadline = deadline
		self._deadline_ns = deadline_ns
		self._nonce = nonce
		self._state_lock = threading.Lock()
		self._worker_claim_lock = threading.Lock()
		self._worker_claimed = False
		self._launch_aborted = False
		self._ready = threading.Event()
		self._decision = threading.Event()
		self._acknowledged = threading.Event()
		self._finished = threading.Event()
		self._abandoned = False
		self._raw_helper: _PosixWatchdogHelperProcess | None = None
		self._transport: _PosixWatchdogTransport | None = None
		self._error: BaseException | None = None
		self._error_traceback: Any = None
		self._status = SupervisedBinaryCleanupStatus(
			complete=False,
			cleanup_complete=False,
			owner_closed=False,
			process_tree_empty=False,
			pid=0,
		)

	def launch(self) -> None:
		first_error: BaseException | None = None
		first_traceback: Any = None
		for _attempt in range(2):
			try:
				worker = threading.Thread(
					target=self._worker_main,
					name="gf-posix-watchdog-spawn",
					daemon=False,
				)
				worker.start()
			except BaseException as error:
				first_error, first_traceback = _select_preferred_cleanup_error(
					first_error,
					first_traceback,
					error,
					context="POSIX watchdog worker launch",
				)
				continue
			if first_error is not None and not isinstance(first_error, Exception):
				raise first_error.with_traceback(first_traceback)
			return
		with self._worker_claim_lock:
			claimed = self._worker_claimed
			if not claimed:
				self._launch_aborted = True
		if claimed:
			self.abandon()
			raise _binary_cleanup_error(
				"POSIX watchdog worker launch lost a positive cleanup boundary.",
				original_error=first_error,
				status=self.snapshot(),
				deferred_cleanup=SupervisedBinaryCleanupHandle(self),
			) from first_error
		self._status = SupervisedBinaryCleanupStatus(
			complete=True,
			cleanup_complete=True,
			owner_closed=True,
			process_tree_empty=True,
			pid=0,
			error_type=type(first_error).__name__ if first_error is not None else "",
		)
		self._ready.set()
		self._finished.set()
		if first_error is not None:
			raise first_error.with_traceback(first_traceback)
		raise RuntimeError("POSIX watchdog worker could not be retained.")

	def claim_before_deadline(self, deadline: float) -> _PosixWatchdogSpawnHandoff | None:
		remaining = deadline - time.perf_counter()
		if remaining <= 0.0 or not self._ready.wait(remaining):
			self.abandon(deadline=deadline)
			return None
		remaining = deadline - time.perf_counter()
		if remaining <= 0.0 or not self._state_lock.acquire(timeout=remaining):
			self.abandon(deadline=deadline)
			return None
		try:
			error = self._error
			error_traceback = self._error_traceback
			transport = self._transport
		finally:
			self._state_lock.release()
		if error is not None:
			raise error.with_traceback(error_traceback)
		if transport is None:
			raise RuntimeError("POSIX watchdog spawn published no transport.")
		return _PosixWatchdogSpawnHandoff(transport=transport)

	def acknowledge_claim(
		self,
		handoff: _PosixWatchdogSpawnHandoff,
		*,
		lease: Any,
		publication_slot: SupervisedProcessLeasePublicationSlot,
		deadline: float,
	) -> bool:
		remaining = deadline - time.perf_counter()
		if remaining <= 0.0 or not self._state_lock.acquire(timeout=remaining):
			self._decision.set()
			return False
		publication_error: BaseException | None = None
		publication_traceback: Any = None
		try:
			if self._abandoned or self._transport is not handoff.transport:
				return False
			try:
				publication_slot.publish(lease, deadline=deadline)
				_process_supervision_checkpoint("process_lease_publication_committed")
			except BaseException as error:
				publication_error, publication_traceback = (
					_select_preferred_cleanup_error(
						publication_error,
						publication_traceback,
						error,
						context="POSIX watchdog lease publication",
					)
				)
				try:
					published = publication_slot.contains(lease)
				except BaseException as contains_error:
					publication_error, publication_traceback = (
						_select_preferred_cleanup_error(
							publication_error,
							publication_traceback,
							contains_error,
							context="POSIX watchdog lease publication proof",
						)
					)
					published = False
				if not published:
					self._abandoned = True
					raise publication_error.with_traceback(publication_traceback)
			self._acknowledged.set()
			try:
				_process_supervision_checkpoint("process_lease_claim_ack_committed")
			except BaseException as error:
				publication_error, publication_traceback = (
					_select_preferred_cleanup_error(
						publication_error,
						publication_traceback,
						error,
						context="POSIX watchdog lease claim acknowledgement",
					)
				)
			if publication_error is not None:
				raise publication_error.with_traceback(publication_traceback)
			return True
		finally:
			self._decision.set()
			self._state_lock.release()

	def claim_acknowledged(self) -> bool:
		return self._acknowledged.is_set()

	def abandon(self, *, deadline: float | None = None) -> None:
		# Decision publication is the worker's cleanup authority transfer.  It must
		# never wait behind the very state lock whose deadline-bounded claim failed.
		self._decision.set()
		acquired = (
			self._state_lock.acquire(blocking=False)
			if deadline is None
			else self._state_lock.acquire(
				timeout=max(0.0, deadline - time.perf_counter())
			)
		)
		if not acquired:
			return
		try:
			if not self._acknowledged.is_set():
				self._abandoned = True
		finally:
			self._state_lock.release()

	def wait(self, timeout_seconds: float | None) -> bool:
		if not self._finished.wait(timeout_seconds):
			return False
		with self._state_lock:
			error = self._error
			error_traceback = self._error_traceback
			status = replace(self._status, complete=True)
		if error is not None:
			_raise_binary_original_or_cleanup_debt(
				error,
				error_traceback,
				message="POSIX watchdog spawn cleanup did not reach a quiet boundary.",
				status=status,
				deferred_cleanup=(
					None
					if status.cleanup_complete
					else SupervisedBinaryCleanupHandle(self)
				),
			)
		return True

	def snapshot(self) -> SupervisedBinaryCleanupStatus:
		with self._state_lock:
			return replace(self._status, complete=self._finished.is_set())

	def snapshot_before_deadline(self, deadline: float) -> SupervisedBinaryCleanupStatus:
		remaining = deadline - time.perf_counter()
		terminal_published = self._finished.is_set()
		acquired = (
			self._state_lock.acquire(blocking=False)
			if terminal_published or remaining <= 0.0
			else self._state_lock.acquire(timeout=remaining)
		)
		if not acquired:
			return SupervisedBinaryCleanupStatus(
				complete=False,
				cleanup_complete=False,
				owner_closed=False,
				process_tree_empty=False,
				pid=0,
				notes=("POSIX watchdog spawn state exceeded its read deadline.",),
				error_type="TimeoutError",
			)
		try:
			return replace(self._status, complete=self._finished.is_set())
		finally:
			self._state_lock.release()

	def _worker_main(self) -> None:
		with self._worker_claim_lock:
			if self._worker_claimed or self._launch_aborted:
				return
			self._worker_claimed = True
		helper: _PosixWatchdogHelperProcess | None = None
		transport: _PosixWatchdogTransport | None = None
		try:
			helper_path = Path(__file__).resolve().with_name(POSIX_WATCHDOG_HELPER_NAME)

			def publish_raw_helper(
				created_helper: _PosixWatchdogHelperProcess,
			) -> None:
				with self._state_lock:
					self._raw_helper = created_helper

			helper = _spawn_posix_watchdog_helper(
				helper_path=helper_path,
				deadline_ns=self._deadline_ns,
				nonce=self._nonce,
				publication=publish_raw_helper,
			)
			transport = _PosixWatchdogTransport.__new__(_PosixWatchdogTransport)
			with self._state_lock:
				self._transport = transport
			_PosixWatchdogTransport.__init__(
				transport,
				helper,
				nonce=self._nonce,
				deadline=self._deadline,
				deadline_ns=self._deadline_ns,
			)
			_process_supervision_checkpoint("process_lease_spawn_published")
		except BaseException as error:
			with self._state_lock:
				self._error = error
				self._error_traceback = safe_exception_traceback(error)
			self._ready.set()
			cleanup_status, preferred_error, preferred_traceback = (
				self._cleanup_failed_helper_construction(
				helper,
				transport,
				error,
				)
			)
			with self._state_lock:
				self._error = preferred_error
				self._error_traceback = preferred_traceback
				self._status = cleanup_status
			self._finished.set()
			return
		with self._state_lock:
			self._transport = transport
		self._ready.set()
		self._decision.wait()
		if self._acknowledged.is_set():
			with self._state_lock:
				self._status = SupervisedBinaryCleanupStatus(
					complete=True,
					cleanup_complete=False,
					owner_closed=False,
					process_tree_empty=False,
					pid=transport.server_pid,
					notes=("POSIX watchdog authority transferred to the lease.",),
				)
			self._finished.set()
			return
		cleanup_status, cleanup_error, cleanup_traceback = (
			self._finish_abandoned_transport(transport)
		)
		with self._state_lock:
			self._error = cleanup_error
			self._error_traceback = cleanup_traceback
			self._status = cleanup_status
		self._finished.set()

	def _finish_abandoned_transport(
		self,
		transport: _PosixWatchdogTransport,
	) -> tuple[SupervisedBinaryCleanupStatus, BaseException | None, Any]:
		notes: list[str] = []
		protocol_broken = False
		pending_error: BaseException | None = None
		pending_traceback: Any = None

		def record(action: str, error: BaseException) -> None:
			nonlocal pending_error, pending_traceback, protocol_broken
			pending_error, pending_traceback = _select_preferred_cleanup_error(
				pending_error,
				pending_traceback,
				error,
				context=f"abandoned POSIX watchdog {action}",
			)
			if isinstance(error, _PosixWatchdogProtocolError):
				protocol_broken = True
			note = (
				f"Abandoned watchdog {action} failed: {type(error).__name__}."
			)
			if note not in notes:
				notes.append(note)

		try:
			transport.request_cancel(
				deadline=max(self._deadline, time.perf_counter() + 0.1)
			)
		except BaseException as error:
			record("CANCEL publication", error)
		while True:
			try:
				transport.close_control()
			except BaseException as error:
				record("control close", error)
			try:
				transport._pump_status_once(
					deadline=time.perf_counter() + 0.1,
					wait=True,
				)
			except BaseException as error:
				record("status protocol", error)
			try:
				transport._try_reap_helper()
			except BaseException as error:
				record("helper reap", error)
			with transport._state_lock:
				helper_reaped = transport._helper_return_code is not None
			if helper_reaped:
				try:
					if transport.finalize():
						break
				except BaseException as error:
					record("resource finalization", error)
			try:
				time.sleep(BINARY_PROCESS_POLL_SECONDS)
			except BaseException as error:
				record("reap pause", error)
		status = transport.cleanup_status()
		if protocol_broken:
			status = replace(
				status,
				complete=True,
				cleanup_complete=False,
				process_tree_empty=False,
				notes=(*status.notes, *notes),
				error_type="_PosixWatchdogProtocolError",
			)
		else:
			status = replace(status, notes=(*status.notes, *notes))
		return status, pending_error, pending_traceback

	def _cleanup_failed_helper_construction(
		self,
		helper: _PosixWatchdogHelperProcess | None,
		transport: _PosixWatchdogTransport | None,
		error: BaseException,
	) -> tuple[SupervisedBinaryCleanupStatus, BaseException, Any]:
		notes = [
			"POSIX watchdog helper construction failed: "
			f"{type(error).__name__}."
		]
		pending_error: BaseException = error
		pending_traceback: Any = safe_exception_traceback(error)

		def record(action: str, cleanup_error: BaseException) -> None:
			nonlocal pending_error, pending_traceback
			pending_error, pending_traceback = _select_preferred_cleanup_error(
				pending_error,
				pending_traceback,
				cleanup_error,
				context=f"partial POSIX watchdog {action}",
			)
			note = (
				f"Partial watchdog {action} failed: "
				f"{type(cleanup_error).__name__}."
			)
			if note not in notes:
				notes.append(note)

		if helper is None:
			with self._state_lock:
				helper = self._raw_helper
		if helper is None:
			return SupervisedBinaryCleanupStatus(
				complete=True,
				cleanup_complete=True,
				owner_closed=True,
				process_tree_empty=True,
				pid=0,
				notes=tuple(notes),
				error_type=type(pending_error).__name__,
			), pending_error, pending_traceback
		# CONFIG cannot have been published before the spawn-ready event. Closing
		# stdin therefore proves the helper cannot create a service. Reap the raw
		# helper under this retained non-daemon worker before publishing completion.
		reaped = False
		resources_closed = False
		while not (reaped and resources_closed):
			control = getattr(helper, "stdin", None)
			if control is not None and not getattr(control, "closed", False):
				try:
					control.close()
				except BaseException as cleanup_error:
					record("raw control close retry", cleanup_error)
			if not reaped:
				try:
					reaped = helper.poll() is not None
				except BaseException as cleanup_error:
					record("raw helper reap retry", cleanup_error)
			if reaped:
				status_stream = getattr(helper, "stdout", None)
				if status_stream is not None and not getattr(status_stream, "closed", False):
					try:
						status_stream.close()
					except BaseException as cleanup_error:
						record("raw status close retry", cleanup_error)
				try:
					helper.close_pidfd()
				except BaseException as cleanup_error:
					record("raw pidfd close retry", cleanup_error)
				resources_closed = bool(
					(control is None or getattr(control, "closed", False))
					and (
						status_stream is None
						or getattr(status_stream, "closed", False)
					)
					and helper.pidfd_closed()
				)
			if not (reaped and resources_closed):
				try:
					time.sleep(BINARY_PROCESS_POLL_SECONDS)
				except BaseException as pause_error:
					record("raw helper retry pause", pause_error)
		return SupervisedBinaryCleanupStatus(
			complete=True,
			cleanup_complete=True,
			owner_closed=True,
			process_tree_empty=True,
			pid=0,
			notes=tuple(notes),
			error_type=type(pending_error).__name__,
		), pending_error, pending_traceback


class _PosixWatchdogDeferredCleanupOperation:
	"""Bounded observer for external helper authority that survives this CLI."""

	def __init__(self, transport: _PosixWatchdogTransport) -> None:
		self._transport = transport

	def wait(self, timeout_seconds: float | None) -> bool:
		deadline = (
			None
			if timeout_seconds is None
			else time.perf_counter() + max(0.0, timeout_seconds)
		)
		pending_error: BaseException | None = None
		pending_traceback: Any = None
		try:
			self._transport.close_control()
		except BaseException as error:
			pending_error, pending_traceback = _select_preferred_cleanup_error(
				pending_error,
				pending_traceback,
				error,
				context="deferred POSIX watchdog control close",
			)
		quiet = False
		try:
			quiet = self._transport.wait_quiet_and_reaped(deadline)
		except BaseException as error:
			pending_error, pending_traceback = _select_preferred_cleanup_error(
				pending_error,
				pending_traceback,
				error,
				context="deferred POSIX watchdog terminal wait",
			)
		status = self._transport.cleanup_status()
		if not status.cleanup_complete:
			if pending_error is None:
				return False
			cleanup_error = _binary_cleanup_error(
				"Deferred POSIX watchdog cleanup remained unproved.",
				original_error=pending_error,
				status=status,
				deferred_cleanup=SupervisedBinaryCleanupHandle(self),
			)
			raise cleanup_error from pending_error
		if pending_error is not None:
			raise pending_error.with_traceback(pending_traceback)
		return quiet

	def snapshot(self) -> SupervisedBinaryCleanupStatus:
		self._transport.poll()
		return self._transport.cleanup_status()

	def snapshot_before_deadline(self, deadline: float) -> SupervisedBinaryCleanupStatus:
		# A zero-wait pump may consume QUIET and a readable pidfd that were already
		# published before the deadline; observing that proof late does not invalidate it.
		self._transport.poll()
		return self._transport.cleanup_status()


class _PosixWatchdogProcessLease:
	"""Long-lived service lease whose process-tree authority is external."""

	def __init__(
		self,
		transport: _PosixWatchdogTransport,
		*,
		command: tuple[str, ...],
		cwd: Path,
		started_at: float,
		deadline: float,
	) -> None:
		self._transport = transport
		self.command = command
		self.cwd = cwd
		self.started_at = started_at
		self.deadline = deadline
		available_seconds = max(0.0, deadline - started_at)
		self.cleanup_reserve_seconds = min(
			PROCESS_LEASE_CLEANUP_RESERVE_SECONDS,
			available_seconds * 0.5,
		)
		self.operation_deadline = deadline - self.cleanup_reserve_seconds
		self._result: SupervisedProcessResult | None = None
		self._close_lock = threading.Lock()
		self._close_finished = threading.Event()
		self._close_owner: int | None = None
		self._close_error: BaseException | None = None
		self._close_traceback: Any = None

	@property
	def pid(self) -> int:
		return self._transport.server_pid

	def poll_health(self) -> None:
		if self._result is not None:
			raise RuntimeError("Supervised process lease is already closed.")
		if time.perf_counter() >= self.deadline:
			raise TimeoutError(
				"Supervised process lease reached its absolute lifetime deadline."
			)
		self._transport.poll()
		quiet = self._transport.quiet_payload()
		if quiet is not None and quiet["trigger"] == "early_exit":
			raise RuntimeError(
				"Supervised process lease direct child exited before cancellation."
			)
		status = self._transport.cleanup_status()
		if status.cleanup_complete:
			raise RuntimeError(
				"Supervised process lease direct child exited before cancellation."
			)
		if status.complete and not status.cleanup_complete:
			raise _binary_cleanup_error(
				"POSIX watchdog exited without a proven quiet boundary.",
				original_error=None,
				status=status,
				deferred_cleanup=SupervisedBinaryCleanupHandle(
					_PosixWatchdogDeferredCleanupOperation(self._transport)
				),
			)

	def poll_operation_health(self) -> None:
		self.poll_health()
		if time.perf_counter() >= self.operation_deadline:
			raise TimeoutError(
				"Supervised process lease reached its operation deadline; its remaining "
				"lifetime is reserved for cleanup."
			)

	def cancel_and_close(self, *, deadline: float) -> SupervisedProcessResult:
		if (
			isinstance(deadline, bool)
			or not isinstance(deadline, (int, float))
			or not math.isfinite(float(deadline))
			or float(deadline) != self.deadline
		):
			raise ValueError(
				"Process lease close must reuse its original absolute lifetime deadline."
			)
		deadline = float(deadline)
		remaining = deadline - time.perf_counter()
		acquired = (
			self._close_lock.acquire(blocking=False)
			if remaining <= 0.0
			else self._close_lock.acquire(timeout=remaining)
		)
		if not acquired:
			raise SupervisedProcessCleanupError(
				"POSIX watchdog lease close could not claim its shared deadline.",
				pid=self.pid,
				deferred_cleanup=SupervisedBinaryCleanupHandle(
					_PosixWatchdogDeferredCleanupOperation(self._transport)
				),
			)
		try:
			if self._close_finished.is_set():
				owns_close = False
			elif self._close_owner is None:
				self._close_owner = threading.get_ident()
				owns_close = True
			else:
				owns_close = self._close_owner == threading.get_ident()
		finally:
			self._close_lock.release()
		if not owns_close:
			remaining = max(0.0, deadline - time.perf_counter())
			if not self._close_finished.wait(remaining):
				raise SupervisedProcessCleanupError(
					"Concurrent POSIX watchdog close exceeded its shared deadline.",
					pid=self.pid,
					deferred_cleanup=SupervisedBinaryCleanupHandle(
						_PosixWatchdogDeferredCleanupOperation(self._transport)
					),
				)
			if self._close_error is not None:
				raise self._close_error.with_traceback(self._close_traceback)
			if self._result is None:
				raise SupervisedProcessCleanupError(
					"POSIX watchdog close published no terminal result.", pid=self.pid
				)
			return self._result

		pending_error: BaseException | None = None
		pending_traceback: Any = None

		def record(error: BaseException, context: str) -> None:
			nonlocal pending_error, pending_traceback
			pending_error, pending_traceback = _select_preferred_cleanup_error(
				pending_error,
				pending_traceback,
				error,
				context=context,
			)

		try:
			try:
				_process_supervision_checkpoint("process_lease_close_impl_entered")
			except BaseException as error:
				record(error, "POSIX watchdog close entry")
			deadline_expired = time.perf_counter() >= deadline
			quiet = False
			terminal_quiet_observed = self._transport.quiet_payload() is not None
			if terminal_quiet_observed or deadline_expired:
				try:
					# Consume an already-authenticated QUIET frame plus the helper pidfd
					# without publishing a redundant CANCEL into a closed control pipe.
					# A completed proof remains valid when observed just after the timestamp.
					quiet = self._transport.wait_quiet_and_reaped(deadline)
				except BaseException as error:
					record(error, "existing POSIX watchdog terminal observation")
			if not quiet and not terminal_quiet_observed:
				try:
					self._transport.request_cancel(deadline=deadline)
				except TimeoutError as error:
					if not deadline_expired:
						record(error, "POSIX watchdog cancellation publication")
				except BaseException as error:
					record(error, "POSIX watchdog cancellation publication")
				finally:
					try:
						self._transport.close_control()
					except BaseException as error:
						record(error, "POSIX watchdog control close")
				try:
					quiet = self._transport.wait_quiet_and_reaped(deadline)
				except BaseException as error:
					record(error, "POSIX watchdog terminal observation")
			status = self._transport.cleanup_status()
			quiet = quiet or status.cleanup_complete
			if not quiet or not status.cleanup_complete:
				cleanup_error = _binary_cleanup_error(
					"POSIX watchdog lease closed without terminal QUIET evidence.",
					original_error=pending_error,
					status=status,
					deferred_cleanup=SupervisedBinaryCleanupHandle(
						_PosixWatchdogDeferredCleanupOperation(self._transport)
					),
				)
				if pending_error is not None:
					raise cleanup_error from pending_error
				raise cleanup_error
			payload = self._transport.quiet_payload()
			if payload is None:
				raise RuntimeError("POSIX watchdog quiet payload disappeared.")
			result = SupervisedProcessResult(
				return_code=int(payload["return_code"]),
				stdout="",
				stderr="",
				timed_out=(
					time.perf_counter() > deadline or payload["trigger"] == "deadline"
				),
				duration_seconds=time.perf_counter() - self.started_at,
				pid=self.pid,
				notes=status.notes,
				cancelled=bool(payload["cancelled"]),
				process_boundary_quiescent=True,
			)
			self._result = result
			if pending_error is not None:
				raise pending_error.with_traceback(pending_traceback)
		except BaseException as error:
			self._close_error = error
			self._close_traceback = safe_exception_traceback(error)
			self._close_finished.set()
			raise
		self._close_finished.set()
		return result


_SUPERVISED_PROCESS_LEASE_FACADE_TOKEN = object()


class SupervisedProcessLease:
	"""Uniform public lease façade over one platform-specific process authority."""

	def __init__(self, backend: Any, *, _token: object) -> None:
		if _token is not _SUPERVISED_PROCESS_LEASE_FACADE_TOKEN:
			raise TypeError("Supervised process lease facades are supervisor-created.")
		self.__backend = backend
		self._close_claim_lock = threading.Lock()
		self._close_finished = threading.Event()
		self._close_owner_thread_id: int | None = None
		self._close_result: SupervisedProcessResult | None = None
		self._close_terminal_error: BaseException | None = None
		self._close_terminal_traceback: Any = None

	@classmethod
	def _from_backend(cls, backend: Any) -> SupervisedProcessLease:
		return cls(backend, _token=_SUPERVISED_PROCESS_LEASE_FACADE_TOKEN)

	@property
	def command(self) -> tuple[str, ...]:
		return self.__backend.command

	@property
	def cwd(self) -> Path:
		return self.__backend.cwd

	@property
	def started_at(self) -> float:
		return float(self.__backend.started_at)

	@property
	def deadline(self) -> float:
		return float(self.__backend.deadline)

	@property
	def cleanup_reserve_seconds(self) -> float:
		return float(self.__backend.cleanup_reserve_seconds)

	@property
	def operation_deadline(self) -> float:
		return float(self.__backend.operation_deadline)

	@property
	def pid(self) -> int:
		return int(self.__backend.pid)

	def poll_health(self) -> None:
		self.__backend.poll_health()

	def poll_operation_health(self) -> None:
		self.__backend.poll_operation_health()

	def cancel_and_close(self, *, deadline: float) -> SupervisedProcessResult:
		if (
			isinstance(deadline, bool)
			or not isinstance(deadline, (int, float))
			or not math.isfinite(float(deadline))
			or float(deadline) != self.deadline
		):
			raise ValueError(
				"Process lease close must reuse its original absolute lifetime deadline."
			)
		deadline = float(deadline)
		pending_error: BaseException | None = None
		pending_traceback: Any = None
		while True:
			try:
				return self._cancel_and_close_once(
					deadline=deadline,
					initial_error=pending_error,
					initial_traceback=pending_traceback,
				)
			except BaseException as error:
				if self._close_finished.is_set():
					terminal_control = error if not isinstance(error, Exception) else None
					return self._wait_for_close_owner_before_deadline(
						deadline,
						initial_error=terminal_control,
						initial_traceback=(
							safe_exception_traceback(terminal_control)
							if terminal_control is not None
							else None
						),
					)
				pending_error, pending_traceback = _select_preferred_cleanup_error(
					pending_error,
					pending_traceback,
					error,
					context="public process lease close entry",
				)
				if self._close_finished.is_set():
					terminal_control = (
						pending_error
						if pending_error is not None
						and not isinstance(pending_error, Exception)
						else None
					)
					return self._wait_for_close_owner_before_deadline(
						deadline,
						initial_error=terminal_control,
						initial_traceback=(
							pending_traceback if terminal_control is not None else None
						),
					)
				if isinstance(error, SupervisedProcessCleanupError):
					if error.original_error is None:
						error.original_error = pending_error
					if pending_error is error:
						raise error.with_traceback(pending_traceback)
					raise error from pending_error
				if time.perf_counter() >= deadline:
					if self._close_finished.wait(0.0):
						terminal_control = (
							pending_error
							if pending_error is not None
							and not isinstance(pending_error, Exception)
							else None
						)
						return self._wait_for_close_owner_before_deadline(
							deadline,
							initial_error=terminal_control,
							initial_traceback=(
								pending_traceback if terminal_control is not None else None
							),
						)
					cleanup_error = SupervisedProcessCleanupError(
						"Public process lease close could not claim or observe terminal "
						"evidence before its shared absolute deadline.",
						pid=self.pid,
						original_error=pending_error,
					)
					if pending_error is not None:
						raise cleanup_error from pending_error
					raise cleanup_error

	def _cancel_and_close_once(
		self,
		*,
		deadline: float,
		initial_error: BaseException | None,
		initial_traceback: Any,
	) -> SupervisedProcessResult:
		owns_close = self._claim_close_before_deadline(deadline)
		if not owns_close:
			return self._wait_for_close_owner_before_deadline(
				deadline,
				initial_error=initial_error,
				initial_traceback=initial_traceback,
			)

		pending_error = initial_error
		pending_traceback = initial_traceback
		try:
			_process_supervision_checkpoint("process_lease_close_claimed")
		except BaseException as checkpoint_error:
			pending_error, pending_traceback = _select_preferred_cleanup_error(
				pending_error,
				pending_traceback,
				checkpoint_error,
				context="public process lease close-claim publication",
			)

		try:
			result = self.__backend.cancel_and_close(deadline=deadline)
		except BaseException as backend_error:
			preferred_error, preferred_traceback = _select_preferred_cleanup_error(
				pending_error,
				pending_traceback,
				backend_error,
				context="public process lease backend close",
			)
			assert preferred_error is not None
			if isinstance(backend_error, SupervisedProcessCleanupError):
				if backend_error.original_error is None or preferred_error is not backend_error:
					backend_error.original_error = preferred_error
				self._publish_close_terminal(result=None, error=backend_error)
				if preferred_error is backend_error:
					raise backend_error.with_traceback(preferred_traceback)
				raise backend_error from preferred_error
			self._publish_close_terminal(result=None, error=preferred_error)
			raise preferred_error.with_traceback(preferred_traceback)

		if pending_error is not None:
			self._publish_close_terminal(result=result, error=pending_error)
			raise pending_error.with_traceback(pending_traceback)
		self._publish_close_terminal(result=result, error=None)
		return result

	def _claim_close_before_deadline(self, deadline: float) -> bool:
		if self._close_finished.is_set():
			return False
		remaining = max(0.0, deadline - time.perf_counter())
		acquired = (
			self._close_claim_lock.acquire(blocking=False)
			if remaining <= 0.0
			else self._close_claim_lock.acquire(timeout=remaining)
		)
		if not acquired:
			raise TimeoutError("Public process lease close claim exceeded its deadline.")
		try:
			if self._close_finished.is_set():
				return False
			current_thread_id = threading.get_ident()
			if self._close_owner_thread_id is None:
				self._close_owner_thread_id = current_thread_id
				return True
			return self._close_owner_thread_id == current_thread_id
		finally:
			self._close_claim_lock.release()

	def _wait_for_close_owner_before_deadline(
		self,
		deadline: float,
		*,
		initial_error: BaseException | None,
		initial_traceback: Any,
	) -> SupervisedProcessResult:
		if not self._close_finished.is_set():
			remaining = max(0.0, deadline - time.perf_counter())
			if remaining <= 0.0 or not self._close_finished.wait(remaining):
				if not self._close_finished.wait(0.0):
					cleanup_error = SupervisedProcessCleanupError(
						"Public process lease close did not publish terminal evidence before "
						"its shared absolute deadline.",
						pid=self.pid,
						original_error=initial_error,
					)
					if initial_error is not None:
						raise cleanup_error from initial_error
					raise cleanup_error
		terminal_error = self._close_terminal_error
		terminal_traceback = self._close_terminal_traceback
		result = self._close_result
		if terminal_error is not None:
			if terminal_error is initial_error:
				raise terminal_error.with_traceback(terminal_traceback)
			preferred_error, preferred_traceback = _select_preferred_cleanup_error(
				initial_error,
				initial_traceback,
				terminal_error,
				context="shared public process lease close",
			)
			assert preferred_error is not None
			if isinstance(terminal_error, SupervisedProcessCleanupError):
				if terminal_error.original_error is None:
					terminal_error.original_error = preferred_error
				if preferred_error is terminal_error:
					raise terminal_error.with_traceback(terminal_traceback)
				raise terminal_error from preferred_error
			raise preferred_error.with_traceback(preferred_traceback)
		if result is None:
			raise SupervisedProcessCleanupError(
				"Public process lease close finished without terminal evidence.",
				pid=self.pid,
				original_error=initial_error,
			)
		if initial_error is not None:
			raise initial_error.with_traceback(initial_traceback)
		return result

	def _publish_close_terminal(
		self,
		*,
		result: SupervisedProcessResult | None,
		error: BaseException | None,
	) -> None:
		with self._close_claim_lock:
			self._close_result = result
			self._close_terminal_error = error
			self._close_terminal_traceback = (
				safe_exception_traceback(error) if error is not None else None
			)
			self._close_finished.set()


def _encode_posix_watchdog_config(
	command: list[str],
	*,
	cwd: Path,
	environment: dict[str, str],
	nonce: str,
	deadline_ns: int,
) -> bytes:
	if (
		not command
		or any(not isinstance(item, str) or "\x00" in item for item in command)
		or not Path(command[0]).is_absolute()
	):
		raise ValueError(
			"POSIX watchdog leases require an absolute, NUL-free service command."
		)
	if any(
		not isinstance(key, str)
		or not isinstance(item, str)
		or not key
		or "=" in key
		or "\x00" in key
		or "\x00" in item
		for key, item in environment.items()
	):
		raise ValueError("POSIX watchdog environment snapshot was invalid.")
	resolved_cwd = cwd.resolve()
	if not resolved_cwd.is_absolute():
		raise ValueError("POSIX watchdog cwd must resolve to an absolute path.")
	frame = (
		json.dumps(
			{
				"version": POSIX_WATCHDOG_PROTOCOL_VERSION,
				"nonce": nonce,
				"type": "CONFIG",
				"deadline_ns": deadline_ns,
				"cwd": str(resolved_cwd),
				"command": list(command),
				"environment": dict(environment),
			},
			ensure_ascii=True,
			separators=(",", ":"),
		).encode("ascii")
		+ b"\n"
	)
	if len(frame) > POSIX_WATCHDOG_MAX_CONFIG_BYTES:
		raise ValueError("POSIX watchdog CONFIG frame exceeded its byte limit.")
	return frame


def _start_posix_watchdog_process_lease(
	command: list[str],
	*,
	cwd: Path,
	deadline: float,
	environment: dict[str, str],
	publication_slot: SupervisedProcessLeasePublicationSlot,
	started_at: float,
) -> SupervisedProcessLease:
	if not Path("/proc").is_dir():
		raise NotImplementedError(
			"POSIX watchdog leases require Linux /proc before helper creation."
		)
	if not callable(getattr(os, "pidfd_open", None)):
		raise NotImplementedError(
			"POSIX watchdog leases require Linux pidfd_open before helper creation."
		)
	remaining = max(0.0, deadline - time.perf_counter())
	deadline_ns = time.monotonic_ns() + int(remaining * 1_000_000_000)
	nonce = secrets.token_hex(32)
	config_frame = _encode_posix_watchdog_config(
		command,
		cwd=cwd,
		environment=environment,
		nonce=nonce,
		deadline_ns=deadline_ns,
	)
	operation = _PosixWatchdogSpawnOperation(
		deadline=deadline,
		deadline_ns=deadline_ns,
		nonce=nonce,
	)
	handoff: _PosixWatchdogSpawnHandoff | None = None
	lease: SupervisedProcessLease | None = None
	acknowledged = False
	try:
		operation.launch()
		handoff = operation.claim_before_deadline(deadline)
		if handoff is None:
			raise TimeoutError(
				"POSIX watchdog helper spawn exceeded the lease deadline."
			)
		handoff.transport.publish_config_frame(config_frame, deadline=deadline)
		handoff.transport.wait_ready_before_deadline(deadline)
		backend = _PosixWatchdogProcessLease(
			handoff.transport,
			command=tuple(command),
			cwd=cwd,
			started_at=started_at,
			deadline=deadline,
		)
		lease = SupervisedProcessLease._from_backend(backend)
		_process_supervision_checkpoint("process_lease_before_claim_ack")
		acknowledged = operation.acknowledge_claim(
			handoff,
			lease=lease,
			publication_slot=publication_slot,
			deadline=deadline,
		)
		if not acknowledged:
			raise TimeoutError(
				"POSIX watchdog lease handoff exceeded its lifetime deadline."
			)
		return lease
	except BaseException as start_error:
		preferred_error = start_error
		preferred_traceback = safe_exception_traceback(start_error)
		if not acknowledged:
			acknowledged = operation.claim_acknowledged()
		if not acknowledged:
			try:
				operation.abandon(deadline=deadline)
			except BaseException as abandon_error:
				preferred_error, preferred_traceback = (
					_select_preferred_cleanup_error(
						preferred_error,
						preferred_traceback,
						abandon_error,
						context="POSIX watchdog spawn abandonment",
					)
				)
			try:
				operation.wait(max(0.0, deadline - time.perf_counter()))
			except BaseException as wait_error:
				preferred_error, preferred_traceback = (
					_select_preferred_cleanup_error(
						preferred_error,
						preferred_traceback,
						wait_error,
						context="POSIX watchdog spawn cleanup wait",
					)
				)
			status = operation.snapshot_before_deadline(deadline)
			_raise_binary_original_or_cleanup_debt(
				preferred_error,
				preferred_traceback,
				message="POSIX watchdog lease start failed without a quiet boundary.",
				status=status,
				deferred_cleanup=(
					None
					if status.complete
					else SupervisedBinaryCleanupHandle(operation)
				),
			)
		if lease is None:
			lease = publication_slot.get()
		try:
			lease.cancel_and_close(deadline=deadline)
		except BaseException as cleanup_error:
			preferred_error, preferred_traceback = _select_preferred_cleanup_error(
				preferred_error,
				preferred_traceback,
				cleanup_error,
				context="acknowledged POSIX watchdog lease start cleanup",
			)
			if isinstance(cleanup_error, SupervisedProcessCleanupError):
				cleanup_error.original_error = preferred_error
				raise cleanup_error from preferred_error
			raise preferred_error.with_traceback(preferred_traceback)
		raise


def _prepare_binary_pipe_for_polling(pipe: Any) -> None:
	"""Prepare one captured pipe without requiring Windows 3.12 APIs.

	``os.set_blocking`` did not support Windows pipes until Python 3.12.  On
	Windows the drain path uses ``PeekNamedPipe`` before every read instead, so
	the descriptor remains in its native blocking mode while each read is proven
	to have at least one available byte.  POSIX keeps the native non-blocking
	descriptor path.
	"""
	if os.name != "nt":
		os.set_blocking(pipe.fileno(), False)


def _windows_binary_pipe_available(pipe: Any) -> tuple[int, bool]:
	"""Return available Windows pipe bytes and whether the writer is gone."""
	if os.name != "nt":
		raise RuntimeError("Windows pipe availability was requested on a non-Windows host.")
	available = wintypes.DWORD(0)
	handle = wintypes.HANDLE(msvcrt.get_osfhandle(pipe.fileno()))
	if _PEEK_NAMED_PIPE(
		handle,
		None,
		0,
		None,
		ctypes.byref(available),
		None,
	):
		return int(available.value), False
	error_code = ctypes.get_last_error()
	if error_code in (_ERROR_BROKEN_PIPE, _ERROR_NO_DATA):
		return 0, True
	raise ctypes.WinError(error_code)


def _drain_binary_pipe_nonblocking(
	state: _BoundedBinaryPipeState,
	stream_name: str,
	notes: list[str],
) -> None:
	while not state.eof and not state.truncated and not state.read_failed:
		remaining = state.max_bytes - state.byte_count
		try:
			read_size = min(64 * 1024, remaining + 1)
			if os.name == "nt":
				available, writer_closed = _windows_binary_pipe_available(state.pipe)
				if writer_closed:
					state.eof = True
					return
				if available <= 0:
					return
				read_size = min(read_size, available)
			chunk = os.read(
				state.pipe.fileno(),
				read_size,
			)
		except BlockingIOError:
			return
		except OSError as error:
			state.read_failed = True
			notes.append(
				f"Could not read supervised binary {stream_name}: "
				f"{type(error).__name__}."
			)
			return
		if not chunk:
			state.eof = True
			return
		if len(chunk) > remaining:
			if remaining > 0:
				state.chunks.append(chunk[:remaining])
				state.byte_count += remaining
			state.truncated = True
			return
		state.chunks.append(chunk)
		state.byte_count += len(chunk)


def _reap_direct_process_before_deadline(
	process: subprocess.Popen[Any],
	deadline: float,
	notes: list[str],
) -> bool:
	remaining = max(0.0, deadline - time.perf_counter())
	try:
		process.wait(timeout=remaining)
		return process.returncode is not None
	except subprocess.TimeoutExpired:
		try:
			process.kill()
		except OSError as error:
			notes.append(
				f"Direct child could not be killed before its absolute deadline: {error}"
			)
		remaining = max(0.0, deadline - time.perf_counter())
		if remaining <= 0.0:
			notes.append("Direct child could not be reaped before its absolute deadline.")
			return False
		try:
			process.wait(timeout=remaining)
		except (OSError, subprocess.TimeoutExpired) as error:
			notes.append(
				f"Direct child could not be reaped before its absolute deadline: {error}"
			)
		return process.returncode is not None


@dataclass(frozen=True)
class _BinarySpawnHandoff:
	owner: _ProcessTreeOwner
	process: subprocess.Popen[bytes]


class _BinarySpawnOperation:
	"""Persistent owner for a spawn that may finish after the caller deadline."""

	def __init__(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str],
		max_stdout_bytes: int,
		max_stderr_bytes: int,
		capture_output: bool = True,
		worker_daemon: bool = False,
		deferred_claim_ack: bool = False,
	) -> None:
		self._command = list(command)
		self._cwd = cwd
		self._environment = environment
		self._max_stdout_bytes = max_stdout_bytes
		self._max_stderr_bytes = max_stderr_bytes
		self._capture_output = capture_output
		self._worker_daemon = worker_daemon
		self._deferred_claim_ack = deferred_claim_ack
		self._worker_claim_lock = threading.Lock()
		self._worker_claimed = False
		self._launch_aborted = False
		self._state_lock = threading.Lock()
		self._spawn_ready = threading.Event()
		self._caller_decision = threading.Event()
		self._finished = threading.Event()
		self._caller_claim_prepared = False
		self._claim_acknowledged_event = threading.Event()
		self._caller_abandoned = False
		self._owner: _ProcessTreeOwner | None = None
		self._process: subprocess.Popen[bytes] | None = None
		self._error: BaseException | None = None
		self._error_traceback: Any = None
		self._cleanup_complete = False
		self._owner_closed = False
		self._process_tree_empty = False
		self._notes: tuple[str, ...] = ()
		self._error_type = ""

	def launch(self) -> None:
		first_error: BaseException | None = None
		first_traceback: Any = None
		for _attempt in range(2):
			worker = threading.Thread(
				target=self._worker_main,
				name="gf-binary-process-spawn",
				daemon=self._worker_daemon,
			)
			try:
				worker.start()
				if first_error is not None and not isinstance(first_error, Exception):
					self.abandon()
					status = self.snapshot()
					_raise_binary_original_or_cleanup_debt(
						first_error,
						first_traceback,
						message=(
							"Binary spawn worker launch was interrupted after another "
							"worker may have claimed process authority."
						),
						status=status,
						deferred_cleanup=(
							None
							if status.complete
							else SupervisedBinaryCleanupHandle(self)
						),
					)
				return
			except BaseException as error:
				first_error, first_traceback = _select_preferred_cleanup_error(
					first_error,
					first_traceback,
					error,
					context="binary spawn worker launch",
				)

		with self._worker_claim_lock:
			worker_claimed = self._worker_claimed
			if not worker_claimed:
				self._launch_aborted = True
		if worker_claimed:
			self.abandon()
		else:
			with self._state_lock:
				self._error = first_error
				self._error_traceback = first_traceback
				self._error_type = type(first_error).__name__ if first_error is not None else ""
				self._notes = ("Binary spawn worker could not be retained.",)
				self._cleanup_complete = True
				self._owner_closed = True
				self._process_tree_empty = True
			self._spawn_ready.set()
			self._finished.set()
		if first_error is not None:
			if worker_claimed:
				status = self.snapshot()
				_raise_binary_original_or_cleanup_debt(
					first_error,
					first_traceback,
					message=(
						"Binary spawn worker could not be retained after it may have "
						"claimed process ownership."
					),
					status=status,
					deferred_cleanup=(
						None
						if status.complete
						else SupervisedBinaryCleanupHandle(self)
					),
				)
			raise first_error.with_traceback(first_traceback)
		raise RuntimeError("Binary spawn worker could not be retained.")

	def claim_before_deadline(self, deadline: float) -> _BinarySpawnHandoff | None:
		remaining = deadline - time.perf_counter()
		if remaining <= 0.0 or not self._spawn_ready.wait(remaining):
			self.abandon(deadline=deadline)
			return None
		remaining = max(0.0, deadline - time.perf_counter())
		if remaining <= 0.0 or not self._state_lock.acquire(timeout=remaining):
			self._caller_decision.set()
			return None
		try:
			if time.perf_counter() > deadline:
				self._caller_abandoned = True
				self._caller_decision.set()
				return None
			error = self._error
			error_traceback = self._error_traceback
			owner = self._owner
			process = self._process
			if error is None and owner is not None and process is not None:
				if self._deferred_claim_ack:
					self._caller_claim_prepared = True
				else:
					self._claim_acknowledged_event.set()
					self._caller_decision.set()
				handoff = _BinarySpawnHandoff(owner=owner, process=process)
			else:
				handoff = None
		finally:
			self._state_lock.release()
		if error is not None:
			status = self.snapshot_before_deadline(deadline)
			_raise_binary_original_or_cleanup_debt(
				error,
				error_traceback,
				message="Binary process spawn failed without a proven quiet boundary.",
				status=status,
				deferred_cleanup=(
					None
					if status.complete
					else SupervisedBinaryCleanupHandle(self)
				),
			)
		if handoff is None:
			raise RuntimeError("Binary spawn completed without an owned process.")
		if not self._deferred_claim_ack:
			remaining = max(0.0, deadline - time.perf_counter())
			self._finished.wait(remaining)
		return handoff

	def acknowledge_claim(
		self,
		handoff: _BinarySpawnHandoff,
		*,
		lease: SupervisedProcessLease,
		publication_slot: SupervisedProcessLeasePublicationSlot,
		deadline: float,
	) -> bool:
		"""Publish the lease, then atomically commit worker authority transfer."""
		if not self._deferred_claim_ack:
			return True
		remaining = max(0.0, deadline - time.perf_counter())
		if remaining <= 0.0 or not self._state_lock.acquire(timeout=remaining):
			self._caller_decision.set()
			return False
		publication_error: BaseException | None = None
		publication_traceback: Any = None
		try:
			if (
				time.perf_counter() > deadline
				or self._caller_abandoned
				or not self._caller_claim_prepared
				or self._owner is not handoff.owner
				or self._process is not handoff.process
			):
				self._caller_abandoned = True
				return False
			try:
				publication_slot.publish(lease, deadline=deadline)
				_process_supervision_checkpoint("process_lease_publication_committed")
			except BaseException as error:
				if not publication_slot.contains(lease):
					self._caller_abandoned = True
					raise
				publication_error = error
				publication_traceback = safe_exception_traceback(error)
			# This event is the sole ownership-transfer commit. Both caller and
			# worker inspect the same atomic state, eliminating a bool/event gap.
			self._claim_acknowledged_event.set()
			try:
				_process_supervision_checkpoint("process_lease_claim_ack_committed")
			except BaseException as ack_error:
				if publication_error is None:
					raise
				add_exception_note(
					publication_error,
					"Process lease claim acknowledgement was also interrupted by "
					f"{type(ack_error).__name__}.",
				)
			if publication_error is not None:
				raise publication_error.with_traceback(publication_traceback)
			return True
		finally:
			self._caller_decision.set()
			self._state_lock.release()

	def claim_acknowledged_before_deadline(self, deadline: float) -> bool:
		_ = deadline
		return self._claim_acknowledged_event.is_set()

	def abandon(self, *, deadline: float | None = None) -> None:
		self._caller_decision.set()
		if deadline is None:
			acquired = self._state_lock.acquire()
		else:
			acquired = self._state_lock.acquire(
				timeout=max(0.0, deadline - time.perf_counter())
			)
		if not acquired:
			return
		try:
			if self._claim_acknowledged_event.is_set():
				return
			self._caller_abandoned = True
			self._caller_decision.set()
		finally:
			self._state_lock.release()

	def wait(self, timeout_seconds: float | None) -> bool:
		return self._finished.wait(timeout_seconds)

	def snapshot(self) -> SupervisedBinaryCleanupStatus:
		with self._state_lock:
			pid = self._process.pid if self._process is not None else 0
			return SupervisedBinaryCleanupStatus(
				complete=self._finished.is_set(),
				cleanup_complete=self._cleanup_complete,
				owner_closed=self._owner_closed,
				process_tree_empty=self._process_tree_empty,
				pid=pid,
				notes=self._notes,
				error_type=self._error_type,
			)

	def snapshot_before_deadline(self, deadline: float) -> SupervisedBinaryCleanupStatus:
		remaining = max(0.0, deadline - time.perf_counter())
		terminal_published = self._finished.is_set()
		acquired = (
			self._state_lock.acquire(blocking=False)
			if terminal_published or remaining <= 0.0
			else self._state_lock.acquire(timeout=remaining)
		)
		if not acquired:
			return SupervisedBinaryCleanupStatus(
				complete=False,
				cleanup_complete=False,
				owner_closed=False,
				process_tree_empty=False,
				pid=0,
				notes=("Spawn cleanup state could not be read before its deadline.",),
				error_type="TimeoutError",
			)
		try:
			if time.perf_counter() > deadline and not terminal_published:
				return SupervisedBinaryCleanupStatus(
					complete=False,
					cleanup_complete=False,
					owner_closed=False,
					process_tree_empty=False,
					pid=self._process.pid if self._process is not None else 0,
					notes=("Spawn cleanup state became available after its deadline.",),
					error_type="TimeoutError",
				)
			pid = self._process.pid if self._process is not None else 0
			return SupervisedBinaryCleanupStatus(
				complete=self._finished.is_set(),
				cleanup_complete=self._cleanup_complete,
				owner_closed=self._owner_closed,
				process_tree_empty=self._process_tree_empty,
				pid=pid,
				notes=self._notes,
				error_type=self._error_type,
			)
		finally:
			self._state_lock.release()

	def current_pid(self) -> int:
		with self._state_lock:
			return self._process.pid if self._process is not None else 0

	def _worker_main(self) -> None:
		with self._worker_claim_lock:
			if self._worker_claimed or self._launch_aborted:
				return
			self._worker_claimed = True

		owner: _ProcessTreeOwner | None = None
		process: subprocess.Popen[bytes] | None = None
		try:
			owner = _new_process_tree_owner()
			if self._capture_output:
				process = owner.start_bytes(
					self._command,
					cwd=self._cwd,
					environment=self._environment,
				)
			else:
				process = owner.start_lease(
					self._command,
					cwd=self._cwd,
					environment=self._environment,
				)
			if getattr(process, "_gf_process_tree_owner", None) is not owner:
				raise RuntimeError(
					"Started binary process lost its process-tree owner binding."
				)
			if self._capture_output and (
				process.stdout is None or process.stderr is None
			):
				raise OSError("Supervised binary process did not expose both output pipes.")
			if not self._capture_output and (
				process.stdout is not None or process.stderr is not None
			):
				raise OSError("Process lease violated its zero-byte DEVNULL output policy.")
			if not self._capture_output:
				_process_supervision_checkpoint("process_lease_spawn_published")
		except BaseException as error:
			if process is None and owner is not None:
				started_process = owner._started_process
				if started_process is not None:
					process = started_process
			with self._state_lock:
				self._owner = owner
				self._process = process
				self._error = error
				self._error_traceback = error.__traceback__
				self._error_type = type(error).__name__
			cleanup_status = self._cleanup_owned_spawn_until_quiet(
				owner,
				process,
				initial_notes=(f"Binary spawn failed: {type(error).__name__}.",),
			)
			self._publish_cleanup_status(cleanup_status)
			self._finished.set()
			self._spawn_ready.set()
			return

		with self._state_lock:
			self._owner = owner
			self._process = process
		self._spawn_ready.set()
		self._caller_decision.wait()
		caller_claimed = self._claim_acknowledged_event.is_set()
		if caller_claimed:
			with self._state_lock:
				self._notes = ("Binary spawn ownership transferred to the caller.",)
			self._finished.set()
			return
		cleanup_status = self._cleanup_owned_spawn_until_quiet(owner, process)
		self._publish_cleanup_status(cleanup_status)
		self._finished.set()

	def _cleanup_owned_spawn_until_quiet(
		self,
		owner: _ProcessTreeOwner | None,
		process: subprocess.Popen[bytes] | None,
		*,
		initial_notes: tuple[str, ...] = (),
	) -> SupervisedBinaryCleanupStatus:
		notes = initial_notes
		while True:
			status = self._cleanup_owned_spawn(
				owner,
				process,
				initial_notes=notes,
			)
			self._publish_cleanup_status(status)
			if status.cleanup_complete:
				return status
			notes = status.notes
			try:
				time.sleep(BINARY_PROCESS_POLL_SECONDS)
			except BaseException as error:
				notes = (
					*notes,
					"Deferred binary cleanup retry pause failed: "
					f"{type(error).__name__}.",
				)

	def _cleanup_owned_spawn(
		self,
		owner: _ProcessTreeOwner | None,
		process: subprocess.Popen[bytes] | None,
		*,
		initial_notes: tuple[str, ...] = (),
	) -> SupervisedBinaryCleanupStatus:
		notes = list(initial_notes)
		if owner is None:
			return SupervisedBinaryCleanupStatus(
				complete=True,
				cleanup_complete=process is None,
				owner_closed=process is None,
				process_tree_empty=process is None,
				pid=process.pid if process is not None else 0,
				notes=tuple(notes),
				error_type=self._error_type,
			)

		cleanup_deadline = (
			time.perf_counter() + BINARY_PROCESS_DEFERRED_CLEANUP_SECONDS
		)
		direct_reaped = process is None
		pipes_closed = True
		if process is not None:
			try:
				notes.extend(owner.terminate_before_deadline(process, cleanup_deadline))
			except BaseException as error:
				owner.cleanup_failed = True
				notes.append(
					"Deferred binary process-tree termination failed: "
					f"{type(error).__name__}."
				)
			stdout_state: _BoundedBinaryPipeState | None = None
			stderr_state: _BoundedBinaryPipeState | None = None
			if (
				process.stdout is not None
				and process.stderr is not None
				and not process.stdout.closed
				and not process.stderr.closed
			):
				try:
					for pipe in (process.stdout, process.stderr):
						_prepare_binary_pipe_for_polling(pipe)
					stdout_state = _BoundedBinaryPipeState(
						pipe=process.stdout,
						max_bytes=self._max_stdout_bytes,
						chunks=[],
					)
					stderr_state = _BoundedBinaryPipeState(
						pipe=process.stderr,
						max_bytes=self._max_stderr_bytes,
						chunks=[],
					)
				except BaseException as error:
					notes.append(
						"Deferred binary pipe setup failed: "
						f"{type(error).__name__}."
					)
			if stdout_state is not None and stderr_state is not None:
				drain_deadline = min(
					cleanup_deadline,
					time.perf_counter()
					+ BINARY_PROCESS_POST_TERMINATION_DRAIN_SECONDS,
				)
				while True:
					_drain_binary_pipe_nonblocking(stdout_state, "stdout", notes)
					_drain_binary_pipe_nonblocking(stderr_state, "stderr", notes)
					if (
						(stdout_state.eof or stdout_state.truncated or stdout_state.read_failed)
						and (
							stderr_state.eof
							or stderr_state.truncated
							or stderr_state.read_failed
						)
					):
						break
					now = time.perf_counter()
					if now >= drain_deadline:
						notes.append(
							"Deferred binary output drain reached its cleanup deadline."
						)
						break
					time.sleep(min(BINARY_PROCESS_POLL_SECONDS, drain_deadline - now))
			try:
				direct_reaped = _reap_direct_process_before_deadline(
					process,
					cleanup_deadline,
					notes,
				)
			except BaseException as error:
				notes.append(
					f"Deferred binary direct-child reap failed: {type(error).__name__}."
				)
			try:
				notes.extend(
					owner.confirm_cleanup_after_reap_before_deadline(cleanup_deadline)
				)
			except BaseException as error:
				owner.cleanup_failed = True
				notes.append(
					"Deferred binary process-tree confirmation failed: "
					f"{type(error).__name__}."
				)

		try:
			notes.extend(owner.close_before_deadline(cleanup_deadline))
		except BaseException as error:
			owner.cleanup_failed = True
			notes.append(
				f"Deferred binary process-tree owner close failed: {type(error).__name__}."
			)
		while not owner.is_closed():
			# The caller deadline has already been honored. Keep this non-daemon
			# operation alive until an already-started kernel-handle close reports
			# its final state, rather than losing ownership in a daemon-only thread.
			if owner.wait_for_close_completion(None):
				break
			retry_deadline = (
				time.perf_counter() + BINARY_PROCESS_DEFERRED_CLEANUP_SECONDS
			)
			try:
				notes.extend(owner.close_before_deadline(retry_deadline))
			except BaseException as error:
				owner.cleanup_failed = True
				notes.append(
					"Deferred binary process-tree owner close retry failed: "
					f"{type(error).__name__}."
				)
			if not owner.is_closed():
				time.sleep(BINARY_PROCESS_POLL_SECONDS)
		if process is not None:
			for pipe in (process.stdout, process.stderr):
				if pipe is None:
					continue
				try:
					pipe.close()
				except BaseException as error:
					pipes_closed = False
					notes.append(
						"Deferred binary output-pipe close failed: "
						f"{type(error).__name__}."
					)
		owner_closed = owner.is_closed()
		closed_tree_boundary = (
			owner_closed
			and owner.close_succeeded()
			and owner.close_terminates_tree()
		)
		if process is not None and closed_tree_boundary and not direct_reaped:
			final_reap_deadline = (
				time.perf_counter() + BINARY_PROCESS_DEFERRED_CLEANUP_SECONDS
			)
			try:
				direct_reaped = _reap_direct_process_before_deadline(
					process,
					final_reap_deadline,
					notes,
				)
			except BaseException as error:
				notes.append(
					"Deferred binary direct-child reap after owner close failed: "
					f"{type(error).__name__}."
				)
		process_tree_empty = (
			process is None
			or closed_tree_boundary
			or (
				owner.termination_succeeded()
				and owner.cleanup_confirmation_succeeded()
			)
		)
		cleanup_complete = (
			process_tree_empty
			and direct_reaped
			and owner_closed
			and pipes_closed
			and (
				process is None
				or closed_tree_boundary
				or (
					owner.termination_succeeded()
					and owner.cleanup_confirmation_succeeded()
				)
			)
		)
		return SupervisedBinaryCleanupStatus(
			complete=True,
			cleanup_complete=cleanup_complete,
			owner_closed=owner_closed,
			process_tree_empty=process_tree_empty,
			pid=process.pid if process is not None else 0,
			notes=tuple(notes),
			error_type=self._error_type,
		)

	def _publish_cleanup_status(
		self,
		status: SupervisedBinaryCleanupStatus,
	) -> None:
		with self._state_lock:
			self._cleanup_complete = status.cleanup_complete
			self._owner_closed = status.owner_closed
			self._process_tree_empty = status.process_tree_empty
			self._notes = status.notes
			self._error_type = status.error_type


class _LeaseDeferredCleanupOperation:
	"""Retain and finish lease cleanup after the caller's deadline has elapsed."""

	def __init__(
		self,
		owner: _ProcessTreeOwner,
		process: subprocess.Popen[Any],
		*,
		owner_closed: bool,
		process_tree_empty: bool,
		direct_reaped: bool,
		cleanup_confirmation_complete: bool,
		notes: tuple[str, ...],
		pipes_closed: bool = True,
	) -> None:
		self._owner = owner
		self._process = process
		self._state_lock = threading.Lock()
		self._claim_lock = threading.Lock()
		self._claimed = False
		self._claim_owner_thread_id: int | None = None
		self._claim_published = threading.Event()
		self._worker_launch_failed = False
		self._finished = threading.Event()
		self._cleanup_complete = False
		# The synchronous caller already captured this proof behind a hostile-safe
		# boundary. Calling an owner accessor while this object is still being
		# constructed could discard the only cleanup authority before a handle can
		# retain it.
		self._owner_closed = bool(owner_closed)
		self._process_tree_empty = process_tree_empty
		self._direct_reaped = direct_reaped
		self._cleanup_confirmation_complete = cleanup_confirmation_complete
		self._pipes_closed = pipes_closed
		self._notes = notes
		self._error_type = ""
		self._pending_error: BaseException | None = None
		self._pending_traceback: Any = None
		self._launch_lock = threading.Lock()
		self._launched = False

	def launch(self) -> None:
		try:
			with self._launch_lock:
				if self._launched:
					return
				self._launched = True
				_process_supervision_checkpoint("deferred_lease_launch_committed")
			self._launch_worker()
		except BaseException as error:
			self._record_pending_error("worker launch entry", error)
			with self._launch_lock:
				self._launched = True
			with self._state_lock:
				self._worker_launch_failed = True

	def _launch_worker(self) -> bool:
		launch_errors: list[BaseException] = []
		worker_launched = False
		for _attempt in range(2):
			try:
				worker = threading.Thread(
					target=self._worker_main,
					name="gf-process-lease-deferred-cleanup",
					daemon=False,
				)
				worker.start()
				worker_launched = True
				break
			except BaseException as error:
				launch_errors.append(error)
				self._record_pending_error("worker launch", error)
		if not worker_launched:
			# Thread.start() may raise after the native worker became runnable. Keep
			# the claim gate authoritative and let handle.wait() synchronously claim
			# cleanup only if no worker actually did.
			with self._state_lock:
				self._worker_launch_failed = True
				self._notes = (
					*self._notes,
					*(
						"Deferred lease cleanup worker launch failed: "
						f"{type(error).__name__}."
						for error in launch_errors
					),
				)
				self._error_type = (
					type(launch_errors[0]).__name__ if launch_errors else "RuntimeError"
				)
		with self._claim_lock:
			worker_claimed = (
				self._claimed
				and self._claim_owner_thread_id != threading.get_ident()
			)
		return worker_launched or worker_claimed

	def _worker_main(self) -> None:
		if not self._claim_cleanup_authority():
			return
		while not self._finished.is_set():
			if self._run_cleanup_attempt(
				time.perf_counter() + BINARY_PROCESS_DEFERRED_CLEANUP_SECONDS
			):
				self._finished.set()
				return
			try:
				time.sleep(BINARY_PROCESS_POLL_SECONDS)
			except BaseException as error:
				self._record_pending_error("retry pause", error)

	def _claim_cleanup_authority(self) -> bool:
		with self._claim_lock:
			if self._claimed:
				return False
			self._claimed = True
			self._claim_owner_thread_id = threading.get_ident()
			self._claim_published.set()
			return True

	def _caller_owns_cleanup_authority(self) -> bool:
		with self._claim_lock:
			return bool(
				self._claimed
				and self._claim_owner_thread_id == threading.get_ident()
			)

	def _reclaim_cleanup_authority(self) -> bool:
		with self._claim_lock:
			current_thread_id = threading.get_ident()
			if self._claimed:
				return self._claim_owner_thread_id == current_thread_id
			self._claimed = True
			self._claim_owner_thread_id = current_thread_id
			self._claim_published.set()
			return True

	def _handoff_sync_authority_to_worker(self) -> bool:
		with self._claim_lock:
			if not (
				self._claimed
				and self._claim_owner_thread_id == threading.get_ident()
			):
				return True
			self._claimed = False
			self._claim_owner_thread_id = None
			self._claim_published.clear()
		_process_supervision_checkpoint("deferred_lease_sync_authority_released")
		worker_available = self._launch_worker()
		_process_supervision_checkpoint("deferred_lease_sync_worker_launched")
		if worker_available:
			while not self._claim_published.is_set():
				try:
					self._claim_published.wait(BINARY_PROCESS_POLL_SECONDS)
				except BaseException as error:
					self._record_pending_error("authority handoff wait", error)
		with self._claim_lock:
			if self._claimed:
				return self._claim_owner_thread_id != threading.get_ident()
			self._claimed = True
			self._claim_owner_thread_id = threading.get_ident()
			self._claim_published.set()
			return False

	def _wait_for_other_cleanup_owner(self) -> bool:
		while not self._finished.is_set():
			try:
				self._finished.wait(BINARY_PROCESS_POLL_SECONDS)
			except BaseException as error:
				self._record_pending_error("shared cleanup wait", error)
		self._raise_recorded_cleanup_error()
		return True

	def _record_pending_error(self, action: str, error: BaseException) -> None:
		with self._state_lock:
			self._pending_error, self._pending_traceback = (
				_select_preferred_cleanup_error(
					self._pending_error,
					self._pending_traceback,
					error,
					context=f"deferred lease {action}",
				)
			)
			if not self._error_type:
				self._error_type = type(error).__name__
			self._notes = (
				*self._notes,
				f"Deferred lease {action} failed: {type(error).__name__}.",
			)

	def _run_cleanup_attempt(self, deadline: float) -> bool:
		with self._state_lock:
			notes = list(self._notes)
			process_tree_empty = self._process_tree_empty
			direct_reaped = self._direct_reaped
			cleanup_confirmation_complete = self._cleanup_confirmation_complete
			pipes_closed = True
			error_type = self._error_type
			pending_error = self._pending_error
			pending_traceback = self._pending_traceback

		def record(action: str, error: BaseException) -> None:
			nonlocal error_type, pending_error, pending_traceback
			if not error_type:
				error_type = type(error).__name__
			pending_error, pending_traceback = _select_preferred_cleanup_error(
				pending_error,
				pending_traceback,
				error,
				context=f"deferred lease {action}",
			)
			notes.append(f"Deferred lease {action} failed: {type(error).__name__}.")

		termination_succeeded = False
		if not process_tree_empty:
			try:
				notes.extend(
					self._owner.terminate_before_deadline(self._process, deadline)
				)
			except BaseException as error:
				record("process-tree termination retry", error)
			try:
				termination_succeeded = self._owner.termination_succeeded()
			except BaseException as error:
				record("termination proof", error)

		remaining = max(0.0, deadline - time.perf_counter())
		close_observed = False
		try:
			close_observed = self._owner.wait_for_close_completion(remaining)
		except BaseException as error:
			record("owner-close observation", error)
		if not close_observed:
			try:
				notes.extend(self._owner.close_before_deadline(deadline))
			except BaseException as error:
				record("process-tree owner close retry", error)

		try:
			owner_closed = self._owner.is_closed()
		except BaseException as error:
			record("owner-close completion proof", error)
			owner_closed = False
		try:
			close_succeeded = self._owner.close_succeeded()
		except BaseException as error:
			record("owner-close success proof", error)
			close_succeeded = False
		try:
			close_terminates_tree = self._owner.close_terminates_tree()
		except BaseException as error:
			record("owner-close tree policy", error)
			close_terminates_tree = False
		closed_tree_boundary = (
			owner_closed and close_succeeded and close_terminates_tree
		)
		if closed_tree_boundary:
			process_tree_empty = True

		if (process_tree_empty or termination_succeeded) and not direct_reaped:
			try:
				direct_reaped = _reap_direct_process_before_deadline(
					self._process,
					deadline,
					notes,
				)
			except BaseException as error:
				record("direct-child reap", error)

		if direct_reaped and not process_tree_empty:
			if termination_succeeded:
				try:
					notes.extend(
						self._owner.confirm_cleanup_after_reap_before_deadline(deadline)
					)
					cleanup_confirmation_complete = (
						self._owner.cleanup_confirmation_succeeded()
					)
				except BaseException as error:
					record("process-tree confirmation", error)
				process_tree_empty = (
					termination_succeeded and cleanup_confirmation_complete
				)

		for pipe in (self._process.stdout, self._process.stderr):
			if pipe is None or getattr(pipe, "closed", False):
				continue
			try:
				pipe.close()
			except BaseException as error:
				pipes_closed = False
				record("output-pipe close retry", error)

		cleanup_complete = (
			owner_closed
			and direct_reaped
			and process_tree_empty
			and pipes_closed
		)
		with self._state_lock:
			if self._pending_error is not None and self._pending_error is not pending_error:
				pending_error, pending_traceback = _select_preferred_cleanup_error(
					pending_error,
					pending_traceback,
					self._pending_error,
					context="concurrent deferred lease cleanup",
				)
			notes = list(dict.fromkeys((*notes, *self._notes)))
			self._cleanup_complete = cleanup_complete
			self._owner_closed = owner_closed
			self._process_tree_empty = process_tree_empty
			self._direct_reaped = direct_reaped
			self._cleanup_confirmation_complete = cleanup_confirmation_complete
			self._pipes_closed = pipes_closed
			self._notes = tuple(notes)
			self._error_type = error_type
			self._pending_error = pending_error
			self._pending_traceback = pending_traceback
		return cleanup_complete

	def wait(self, timeout_seconds: float | None) -> bool:
		if self._finished.is_set():
			self._raise_recorded_cleanup_error()
			return True
		with self._state_lock:
			worker_launch_failed = self._worker_launch_failed
		owns_sync_cleanup = False
		try:
			if worker_launch_failed:
				owns_sync_cleanup = self._claim_cleanup_authority()
		except BaseException as error:
			with self._claim_lock:
				owns_sync_cleanup = (
					self._claimed
					and self._claim_owner_thread_id == threading.get_ident()
				)
			if not owns_sync_cleanup:
				raise
			self._record_pending_error("synchronous claim publication", error)
		if owns_sync_cleanup:
			try:
				_process_supervision_checkpoint(
					"deferred_lease_sync_cleanup_claimed"
				)
				if timeout_seconds is not None and timeout_seconds <= 0.0:
					if self._handoff_sync_authority_to_worker():
						return False
					return self._run_synchronous_cleanup(None)
				return self._run_synchronous_cleanup(timeout_seconds)
			except BaseException as error:
				# Claim publication transfers the only cleanup authority to this
				# caller.  An asynchronous interruption in the CALL/entry gap must
				# therefore be retained while this same caller continues cleanup.
				if self._finished.is_set():
					raise
				self._record_pending_error("synchronous cleanup entry", error)
				if self._reclaim_cleanup_authority():
					return self._run_synchronous_cleanup(None)
				return self._wait_for_other_cleanup_owner()
		wait_deadline = (
			None
			if timeout_seconds is None
			else time.perf_counter() + max(0.0, timeout_seconds)
		)
		while not self._finished.is_set():
			if wait_deadline is not None:
				remaining = wait_deadline - time.perf_counter()
				if remaining <= 0.0:
					return False
			else:
				remaining = BINARY_PROCESS_POLL_SECONDS
			try:
				self._finished.wait(min(BINARY_PROCESS_POLL_SECONDS, remaining))
			except BaseException as error:
				self._record_pending_error("worker completion wait", error)
		self._raise_recorded_cleanup_error()
		return True

	def _run_synchronous_cleanup(self, timeout_seconds: float | None) -> bool:
		wait_deadline: float | None = None
		while wait_deadline is None:
			try:
				wait_deadline = (
					math.inf
					if timeout_seconds is None
					else time.perf_counter() + max(0.0, timeout_seconds)
				)
			except BaseException as error:
				self._record_pending_error("synchronous deadline preparation", error)
		while not self._finished.is_set():
			try:
				cleanup_deadline = min(
					time.perf_counter() + BINARY_PROCESS_DEFERRED_CLEANUP_SECONDS,
					wait_deadline,
				)
				if self._run_cleanup_attempt(cleanup_deadline):
					self._finished.set()
					break
				if time.perf_counter() >= wait_deadline:
					if self._handoff_sync_authority_to_worker():
						return False
					wait_deadline = math.inf
			except BaseException as error:
				self._record_pending_error("synchronous cleanup choreography", error)
				if not self._reclaim_cleanup_authority():
					return self._wait_for_other_cleanup_owner()
		self._raise_recorded_cleanup_error()
		return True

	def _raise_recorded_cleanup_error(self) -> None:
		with self._state_lock:
			pending_error = self._pending_error
			pending_traceback = self._pending_traceback
			status = SupervisedBinaryCleanupStatus(
				complete=self._finished.is_set(),
				cleanup_complete=self._cleanup_complete,
				owner_closed=self._owner_closed,
				process_tree_empty=self._process_tree_empty,
				pid=self._process.pid,
				notes=self._notes,
				error_type=self._error_type,
			)
		if pending_error is None:
			return
		if _binary_cleanup_status_is_quiet(status):
			raise pending_error.with_traceback(pending_traceback)
		cleanup_error = _binary_cleanup_error(
			"Deferred lease cleanup failed without a proven quiet boundary.",
			original_error=pending_error,
			status=status,
			deferred_cleanup=SupervisedBinaryCleanupHandle(self),
		)
		raise cleanup_error from pending_error

	def snapshot(self) -> SupervisedBinaryCleanupStatus:
		with self._state_lock:
			return SupervisedBinaryCleanupStatus(
				complete=self._finished.is_set(),
				cleanup_complete=self._cleanup_complete,
				owner_closed=self._owner_closed,
				process_tree_empty=self._process_tree_empty,
				pid=self._process.pid,
				notes=self._notes,
				error_type=self._error_type,
			)

	def snapshot_before_deadline(self, deadline: float) -> SupervisedBinaryCleanupStatus:
		remaining = max(0.0, deadline - time.perf_counter())
		terminal_published = self._finished.is_set()
		acquired = (
			self._state_lock.acquire(blocking=False)
			if terminal_published or remaining <= 0.0
			else self._state_lock.acquire(timeout=remaining)
		)
		if not acquired:
			return SupervisedBinaryCleanupStatus(
				complete=False,
				cleanup_complete=False,
				owner_closed=False,
				process_tree_empty=False,
				pid=self._process.pid,
				notes=("Deferred lease cleanup state was unavailable before its deadline.",),
				error_type="TimeoutError",
			)
		try:
			if time.perf_counter() > deadline and not terminal_published:
				return SupervisedBinaryCleanupStatus(
					complete=False,
					cleanup_complete=False,
					owner_closed=False,
					process_tree_empty=False,
					pid=self._process.pid,
					notes=(
						"Deferred lease cleanup state became available after its deadline.",
					),
					error_type="TimeoutError",
				)
			return SupervisedBinaryCleanupStatus(
				complete=self._finished.is_set(),
				cleanup_complete=self._cleanup_complete,
				owner_closed=self._owner_closed,
				process_tree_empty=self._process_tree_empty,
				pid=self._process.pid,
				notes=self._notes,
				error_type=self._error_type,
			)
		finally:
			self._state_lock.release()


class SupervisedBinaryCleanupHandle:
	"""Observable final state for a spawn cleaned after the caller deadline."""

	def __init__(self, operation: Any) -> None:
		self._operation = operation

	def wait(self, timeout_seconds: float | None = None) -> bool:
		if timeout_seconds is not None and (
			isinstance(timeout_seconds, bool)
			or not isinstance(timeout_seconds, (int, float))
			or not math.isfinite(float(timeout_seconds))
			or float(timeout_seconds) < 0.0
		):
			raise ValueError("Deferred cleanup timeout must be finite and non-negative.")
		return self._operation.wait(
			None if timeout_seconds is None else float(timeout_seconds)
		)

	def snapshot(self) -> SupervisedBinaryCleanupStatus:
		return self._operation.snapshot()

	def snapshot_before_deadline(self, deadline: float) -> SupervisedBinaryCleanupStatus:
		bounded_snapshot = getattr(self._operation, "snapshot_before_deadline", None)
		if not callable(bounded_snapshot):
			raise TypeError(
				"Deferred cleanup operation does not expose a deadline-bounded snapshot."
			)
		return bounded_snapshot(deadline)


def _binary_cleanup_status_is_quiet(status: SupervisedBinaryCleanupStatus) -> bool:
	return (
		status.complete is True
		and status.cleanup_complete is True
		and status.owner_closed is True
		and status.process_tree_empty is True
	)


def _binary_cleanup_error(
	message: str,
	*,
	original_error: BaseException | None,
	status: SupervisedBinaryCleanupStatus,
	deferred_cleanup: SupervisedBinaryCleanupHandle | None,
) -> SupervisedProcessCleanupError:
	return SupervisedProcessCleanupError(
		message,
		notes=status.notes,
		original_error=original_error,
		pid=status.pid,
		owner_closed=status.owner_closed is True,
		process_tree_empty=status.process_tree_empty is True,
		cleanup_status=status,
		deferred_cleanup=deferred_cleanup,
	)


def _raise_binary_original_or_cleanup_debt(
	error: BaseException,
	traceback: Any,
	*,
	message: str,
	status: SupervisedBinaryCleanupStatus,
	deferred_cleanup: SupervisedBinaryCleanupHandle | None,
) -> None:
	if _binary_cleanup_status_is_quiet(status):
		raise error.with_traceback(traceback)
	raise _binary_cleanup_error(
		message,
		original_error=error,
		status=status,
		deferred_cleanup=deferred_cleanup,
	) from error


def require_supervised_binary_quiet_boundary(
	result: SupervisedBinaryProcessResult,
	*,
	deadline: float,
) -> SupervisedBinaryProcessResult:
	"""Accept a binary result only within the caller's original monotonic deadline."""
	if (
		isinstance(deadline, bool)
		or not isinstance(deadline, (int, float))
		or not math.isfinite(float(deadline))
	):
		raise ValueError("Binary quiet-boundary deadline must be finite.")
	deadline = float(deadline)
	if result.cleanup_complete is True and result.deferred_cleanup is None:
		if time.perf_counter() > deadline:
			raise TimeoutError(
				"Binary process result was not accepted before the caller's original "
				"absolute deadline."
			)
		return result

	handle = result.deferred_cleanup
	if handle is None:
		status = SupervisedBinaryCleanupStatus(
			complete=True,
			cleanup_complete=False,
			owner_closed=False,
			process_tree_empty=False,
			pid=result.pid,
			notes=result.notes,
		)
		raise _binary_cleanup_error(
			"Binary process result has no proven quiet boundary or deferred owner.",
			original_error=None,
			status=status,
			deferred_cleanup=None,
		)

	try:
		finished = handle.wait(max(0.0, deadline - time.perf_counter()))
		if not finished or time.perf_counter() > deadline:
			status = SupervisedBinaryCleanupStatus(
				complete=False,
				cleanup_complete=False,
				owner_closed=False,
				process_tree_empty=False,
				pid=result.pid,
				notes=(
					*result.notes,
					"Deferred cleanup did not publish final state before the caller's "
					"original absolute deadline.",
				),
				error_type="TimeoutError",
			)
		else:
			status = handle.snapshot_before_deadline(deadline)
	except BaseException as error:
		fallback_status = SupervisedBinaryCleanupStatus(
			complete=False,
			cleanup_complete=False,
			owner_closed=False,
			process_tree_empty=False,
			pid=result.pid,
			notes=result.notes,
			error_type=type(error).__name__,
		)
		raise _binary_cleanup_error(
			"Deferred binary cleanup observation failed.",
			original_error=error,
			status=fallback_status,
			deferred_cleanup=handle,
		) from error

	if type(status) is not SupervisedBinaryCleanupStatus:
		fallback_status = SupervisedBinaryCleanupStatus(
			complete=False,
			cleanup_complete=False,
			owner_closed=False,
			process_tree_empty=False,
			pid=result.pid,
			notes=(*result.notes, "Deferred cleanup returned an invalid status object."),
		)
		raise _binary_cleanup_error(
			"Deferred binary cleanup did not return an authoritative status.",
			original_error=None,
			status=fallback_status,
			deferred_cleanup=handle,
		)
	observed_before_deadline = time.perf_counter() <= deadline
	pid_matches = result.pid <= 0 or (
		status.pid > 0 and result.pid == status.pid
	)
	if (
		not _binary_cleanup_status_is_quiet(status)
		or not pid_matches
		or not observed_before_deadline
	):
		if not observed_before_deadline:
			status = replace(
				status,
				notes=(
					*status.notes,
					"Deferred binary cleanup was not observed before the caller's "
					"original absolute deadline.",
				),
			)
		raise _binary_cleanup_error(
			"Deferred binary cleanup did not prove a quiet process boundary.",
			original_error=None,
			status=status,
			deferred_cleanup=handle,
		)
	merged_notes = tuple(dict.fromkeys((*result.notes, *status.notes)))
	return replace(
		result,
		notes=merged_notes,
		cleanup_complete=True,
		deferred_cleanup=None,
	)


def run_supervised_process_bytes(
	command: list[str],
	*,
	cwd: Path,
	timeout_seconds: float,
	deadline: float | None = None,
	max_stdout_bytes: int,
	max_stderr_bytes: int,
	environment: dict[str, str],
) -> SupervisedBinaryProcessResult:
	"""Run one owned process tree with raw, byte-bounded output capture."""
	if environment is None:
		raise TypeError("Supervised process bytes requires an explicit environment.")
	started = time.perf_counter()
	if (
		isinstance(timeout_seconds, bool)
		or not isinstance(timeout_seconds, (int, float))
		or not math.isfinite(float(timeout_seconds))
		or float(timeout_seconds) <= 0.0
	):
		raise ValueError("Binary process timeout must be a finite positive number.")
	if deadline is not None and (
		isinstance(deadline, bool)
		or not isinstance(deadline, (int, float))
		or not math.isfinite(float(deadline))
	):
		raise ValueError("Binary process deadline must be a finite monotonic timestamp.")
	for stream_name, capture_limit in (
		("stdout", max_stdout_bytes),
		("stderr", max_stderr_bytes),
	):
		if (
			isinstance(capture_limit, bool)
			or not isinstance(capture_limit, int)
			or capture_limit < 1
		):
			raise ValueError(
				f"{stream_name} byte capture limit must be a positive integer."
			)

	relative_deadline = started + float(timeout_seconds)
	deadline = (
		relative_deadline
		if deadline is None
		else min(relative_deadline, float(deadline))
	)
	if deadline <= started:
		return SupervisedBinaryProcessResult(
			return_code=124,
			stdout=b"",
			stderr=b"",
			timed_out=True,
			duration_seconds=time.perf_counter() - started,
			pid=0,
			notes=(
				"Binary process deadline expired before its process started.",
			),
			cleanup_complete=True,
		)
	available_seconds = deadline - started
	cleanup_reserve = min(
		BINARY_PROCESS_CLEANUP_RESERVE_SECONDS,
		available_seconds * 0.5,
	)
	execution_deadline = deadline - cleanup_reserve
	spawn_operation = _BinarySpawnOperation(
		command,
		cwd=cwd,
		environment=environment,
		max_stdout_bytes=max_stdout_bytes,
		max_stderr_bytes=max_stderr_bytes,
	)
	try:
		spawn_operation.launch()
		handoff = spawn_operation.claim_before_deadline(deadline)
	except BaseException:
		spawn_operation.abandon(deadline=deadline)
		raise
	if handoff is None:
		duration_seconds = time.perf_counter() - started
		spawn_status = spawn_operation.snapshot_before_deadline(deadline)
		return SupervisedBinaryProcessResult(
			return_code=124,
			stdout=b"",
			stderr=b"",
			timed_out=True,
			duration_seconds=duration_seconds,
			pid=spawn_status.pid,
			notes=(
				"Binary process spawn did not complete before its absolute deadline; "
				"deferred cleanup retained ownership.",
			),
			cleanup_complete=False,
			deferred_cleanup=SupervisedBinaryCleanupHandle(spawn_operation),
		)

	owner: _ProcessTreeOwner = handoff.owner
	process: subprocess.Popen[bytes] = handoff.process
	stdout_state: _BoundedBinaryPipeState | None = None
	stderr_state: _BoundedBinaryPipeState | None = None
	notes: list[str] = []
	timed_out = False
	output_drain_failed = False
	direct_reaped = False
	pipes_closed = True
	pending_error: BaseException | None = None
	pending_traceback: Any = None

	def record_pending(error: BaseException, context: str) -> None:
		nonlocal pending_error, pending_traceback
		pending_error, pending_traceback = _select_preferred_cleanup_error(
			pending_error,
			pending_traceback,
			error,
			context=context,
		)

	try:
		# Spawn admission validated owner binding and both pipes before handoff.
		stdout_pipe = process.stdout
		stderr_pipe = process.stderr
		if stdout_pipe is None or stderr_pipe is None:
			raise RuntimeError("Binary spawn handoff lost its captured output pipes.")
		for pipe in (stdout_pipe, stderr_pipe):
			_prepare_binary_pipe_for_polling(pipe)
		stdout_state = _BoundedBinaryPipeState(
			pipe=stdout_pipe,
			max_bytes=max_stdout_bytes,
			chunks=[],
		)
		stderr_state = _BoundedBinaryPipeState(
			pipe=stderr_pipe,
			max_bytes=max_stderr_bytes,
			chunks=[],
		)
		direct_exit_at: float | None = None
		while True:
			_drain_binary_pipe_nonblocking(stdout_state, "stdout", notes)
			_drain_binary_pipe_nonblocking(stderr_state, "stderr", notes)
			if stdout_state.truncated or stderr_state.truncated:
				break
			if stdout_state.read_failed or stderr_state.read_failed:
				output_drain_failed = True
				break
			direct_exited = owner.wait_for_direct_exit(process, 0.0)
			now = time.perf_counter()
			if direct_exited and stdout_state.eof and stderr_state.eof:
				break
			if direct_exited:
				if direct_exit_at is None:
					direct_exit_at = now
				if now >= min(
					execution_deadline,
					direct_exit_at + OUTPUT_DRAIN_GRACE_SECONDS,
				):
					output_drain_failed = True
					notes.append(
						"Output pipes remained open after the direct child exited; "
						"terminating the owned process tree."
					)
					break
			if now >= execution_deadline:
				timed_out = True
				notes.append(
					"Binary command reached its execution deadline; terminating "
					"the owned process tree."
				)
				break
			time.sleep(min(BINARY_PROCESS_POLL_SECONDS, execution_deadline - now))
	except BaseException as error:
		record_pending(error, "binary process monitoring")
	finally:
		if owner is not None and process is not None:
			try:
				notes.extend(owner.terminate_before_deadline(process, deadline))
			except BaseException as error:
				owner.cleanup_failed = True
				notes.append(
					f"Binary process-tree termination failed: {type(error).__name__}."
				)
				record_pending(error, "binary process-tree termination")

			pipe_drain_deadline = min(
				deadline,
				time.perf_counter() + BINARY_PROCESS_POST_TERMINATION_DRAIN_SECONDS,
			)
			while stdout_state is not None and stderr_state is not None:
				try:
					_drain_binary_pipe_nonblocking(stdout_state, "stdout", notes)
					_drain_binary_pipe_nonblocking(stderr_state, "stderr", notes)
				except BaseException as error:
					output_drain_failed = True
					notes.append(
						"Binary post-termination output drain failed: "
						f"{type(error).__name__}."
					)
					record_pending(error, "binary post-termination output drain")
					break
				if (
					(stdout_state.eof or stdout_state.truncated or stdout_state.read_failed)
					and (
						stderr_state.eof
						or stderr_state.truncated
						or stderr_state.read_failed
					)
				):
					break
				now = time.perf_counter()
				if now >= pipe_drain_deadline:
					output_drain_failed = True
					break
				time.sleep(min(BINARY_PROCESS_POLL_SECONDS, pipe_drain_deadline - now))

			try:
				direct_reaped = _reap_direct_process_before_deadline(
					process,
					deadline,
					notes,
				)
			except BaseException as error:
				notes.append(f"Binary direct-child reap failed: {type(error).__name__}.")
				record_pending(error, "binary direct-child reap")

			try:
				notes.extend(owner.confirm_cleanup_after_reap_before_deadline(deadline))
			except BaseException as error:
				owner.cleanup_failed = True
				notes.append(
					f"Binary process-tree confirmation failed: {type(error).__name__}."
				)
				record_pending(error, "binary process-tree confirmation")

		if owner is not None:
			try:
				notes.extend(owner.close_before_deadline(deadline))
			except BaseException as error:
				owner.cleanup_failed = True
				notes.append(f"Binary process-tree owner close failed: {type(error).__name__}.")
				record_pending(error, "binary process-tree owner close")

		if process is not None:
			for pipe in (process.stdout, process.stderr):
				if pipe is None:
					continue
				try:
					pipe.close()
				except BaseException as error:
					pipes_closed = False
					notes.append(
						f"Binary output-pipe close failed: {type(error).__name__}."
					)
					record_pending(error, "binary output-pipe close")

	duration_seconds = time.perf_counter() - started
	deadline_respected = time.perf_counter() <= deadline
	if not deadline_respected:
		timed_out = True
		notes.append("Binary process supervision exceeded its absolute deadline.")
	owner_closed = owner.is_closed()
	closed_tree_boundary = (
		owner_closed
		and owner.close_succeeded()
		and owner.close_terminates_tree()
	)
	process_tree_empty = (
		closed_tree_boundary
		or (
			owner.termination_succeeded()
			and owner.cleanup_confirmation_succeeded()
		)
	)
	cleanup_complete = (
		process_tree_empty
		and direct_reaped
		and owner_closed
		and pipes_closed
	)
	deferred_cleanup: SupervisedBinaryCleanupHandle | None = None
	if not cleanup_complete:
		deferred_operation = _LeaseDeferredCleanupOperation(
				owner,
				process,
				owner_closed=owner_closed,
				process_tree_empty=process_tree_empty,
				direct_reaped=direct_reaped,
				cleanup_confirmation_complete=(
					owner.cleanup_confirmation_succeeded()
				),
				notes=tuple(notes),
				pipes_closed=pipes_closed,
			)
		deferred_cleanup = SupervisedBinaryCleanupHandle(deferred_operation)
		deferred_operation.launch()
	cleanup_status = SupervisedBinaryCleanupStatus(
		complete=True,
		cleanup_complete=cleanup_complete,
		owner_closed=owner_closed,
		process_tree_empty=process_tree_empty,
		pid=process.pid,
		notes=tuple(notes),
		error_type=type(pending_error).__name__ if pending_error is not None else "",
	)
	if pending_error is not None:
		_raise_binary_original_or_cleanup_debt(
			pending_error,
			pending_traceback,
			message="Binary process supervision failed without a proven quiet boundary.",
			status=cleanup_status,
			deferred_cleanup=deferred_cleanup,
		)
	if stdout_state is None or stderr_state is None:
		raise RuntimeError("Binary process supervision completed without a process result.")
	return SupervisedBinaryProcessResult(
		return_code=process.returncode if process.returncode is not None else 124,
		stdout=b"".join(stdout_state.chunks),
		stderr=b"".join(stderr_state.chunks),
		timed_out=timed_out,
		duration_seconds=duration_seconds,
		pid=process.pid,
		notes=tuple(notes),
		stdout_truncated=stdout_state.truncated,
		stderr_truncated=stderr_state.truncated,
		output_drain_failed=output_drain_failed,
		cleanup_complete=cleanup_complete,
		deferred_cleanup=deferred_cleanup,
	)


def run_supervised_process(
	command: list[str],
	*,
	cwd: Path,
	timeout_seconds: float,
	environment: dict[str, str],
	process_started_callback: Callable[[int], None] | None = None,
	stdout_callback: Callable[[str], None] | None = None,
	stderr_callback: Callable[[str], None] | None = None,
	heartbeat_callback: Callable[[float, int], None] | None = None,
	heartbeat_interval_seconds: float = 15.0,
	cancellation_event: threading.Event | None = None,
	max_stdout_characters: int | None = None,
	max_stderr_characters: int | None = None,
	stdin_bytes: bytes | None = None,
	text_errors: str = "replace",
	binary_output: bool = False,
) -> SupervisedProcessResult:
	if environment is None:
		raise TypeError("Supervised process requires an explicit environment.")
	started = time.perf_counter()
	if stdin_bytes is not None and not isinstance(stdin_bytes, bytes):
		raise TypeError("stdin_bytes must be bytes or None.")
	if text_errors not in {"replace", "surrogateescape"}:
		raise ValueError("text_errors must be 'replace' or 'surrogateescape'.")
	if not isinstance(binary_output, bool):
		raise TypeError("binary_output must be a bool.")
	for stream_name, capture_limit in (
		("stdout", max_stdout_characters),
		("stderr", max_stderr_characters),
	):
		if capture_limit is not None and capture_limit < 1:
			raise ValueError(
				f"{stream_name} capture limit must be a positive integer."
			)
	if cancellation_event is not None and cancellation_event.is_set():
		return SupervisedProcessResult(
			return_code=130,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=time.perf_counter() - started,
			pid=0,
			notes=("Command was cancelled before its process started.",),
			cancelled=True,
			process_boundary_quiescent=True,
		)
	owner: _ProcessTreeOwner | None = None
	process: subprocess.Popen[str] | None = None
	stdout_parts: list[str] = []
	stderr_parts: list[str] = []
	stdout_truncated = [False]
	stderr_truncated = [False]
	callback_errors: list[str] = []
	callback_error_lock = threading.Lock()
	activity_lock = threading.Lock()
	last_output_at = [started]
	deadline = started + max(0.001, timeout_seconds)
	next_heartbeat = started + max(0.1, heartbeat_interval_seconds)
	timed_out = False
	cancelled = False
	notes: list[str] = []
	output_threads: list[threading.Thread] = []
	pending_error: BaseException | None = None
	pending_traceback: Any = None
	command_failed = False
	tree_termination_completed = False
	direct_reap_completed = False
	cleanup_confirmation_completed = False
	stdin_stream: BinaryIO | None = None
	prelaunch_result: SupervisedProcessResult | None = None

	class PrelaunchStopped(Exception):
		def __init__(self, result: SupervisedProcessResult) -> None:
			super().__init__("Process launch stopped before a child was created.")
			self.result = result

	def close_staged_stdin() -> None:
		nonlocal stdin_stream
		stream = stdin_stream
		if stream is not None:
			stream.close()
			_process_supervision_checkpoint("stdin_stream_closed")
			# Clear the shared reference only after close returns. If an asynchronous
			# exception lands inside close, the preserving cleanup path can retry the
			# still-owned stream instead of losing its only handle.
			if stdin_stream is stream:
				stdin_stream = None

	def close_staged_stdin_preserving(primary_error: BaseException) -> None:
		"""Preserve the primary error only after staged-input close is proven."""
		cleanup_errors: list[BaseException] = []
		for _attempt in range(2):
			try:
				close_staged_stdin()
			except BaseException as cleanup_error:
				cleanup_errors.append(cleanup_error)
				continue
			if cleanup_errors:
				add_exception_note(
					primary_error,
					"Staged subprocess stdin cleanup succeeded on retry after: "
					f"{type(cleanup_errors[0]).__name__}: "
					f"{safe_exception_detail(cleanup_errors[0])}",
				)
			return
		cleanup_notes = tuple(
			"Staged subprocess stdin cleanup failed: "
			f"{type(cleanup_error).__name__}: "
			f"{safe_exception_detail(cleanup_error)}"
			for cleanup_error in cleanup_errors
		)
		if isinstance(primary_error, SupervisedProcessCleanupError):
			for cleanup_note in cleanup_notes:
				add_exception_note(primary_error, cleanup_note)
			raise primary_error
		raise SupervisedProcessCleanupError(
			"Staged subprocess stdin cleanup failed repeatedly before ownership "
			"could be released.",
			notes=cleanup_notes,
			original_error=primary_error,
		) from primary_error

	def close_staged_stdin_for_stop(
		result: SupervisedProcessResult,
	) -> SupervisedProcessResult:
		"""Retry one ordinary close failure before publishing a prelaunch stop."""
		first_cleanup_error: Exception | None = None
		for _attempt in range(2):
			try:
				close_staged_stdin()
			except Exception as cleanup_error:
				if first_cleanup_error is None:
					first_cleanup_error = cleanup_error
					continue
				raise SupervisedProcessCleanupError(
					"Staged subprocess stdin cleanup was not proven complete before launch.",
					notes=(
						*result.notes,
						"Staged subprocess stdin cleanup failed twice before launch: "
						f"{type(cleanup_error).__name__}: "
						f"{safe_exception_detail(cleanup_error)}",
					),
				) from first_cleanup_error
			if first_cleanup_error is None:
				return result
			return replace(
				result,
				notes=(
					*result.notes,
					"Staged subprocess stdin cleanup succeeded on retry after: "
					f"{type(first_cleanup_error).__name__}: "
					f"{safe_exception_detail(first_cleanup_error)}",
				),
			)
		raise AssertionError("unreachable staged stdin cleanup retry state")

	def prelaunch_stop_result() -> SupervisedProcessResult | None:
		now = time.perf_counter()
		if now >= deadline:
			return SupervisedProcessResult(
				return_code=124,
				stdout="",
				stderr="",
				timed_out=True,
				duration_seconds=now - started,
				pid=0,
				notes=("Command timed out while staging stdin before its process started.",),
				process_boundary_quiescent=True,
			)
		if cancellation_event is not None and cancellation_event.is_set():
			return SupervisedProcessResult(
				return_code=130,
				stdout="",
				stderr="",
				timed_out=False,
				duration_seconds=now - started,
				pid=0,
				notes=("Command was cancelled while staging stdin before its process started.",),
				cancelled=True,
				process_boundary_quiescent=True,
			)
		return None

	def stage_stdin_before_launch() -> SupervisedProcessResult | None:
		nonlocal stdin_stream
		if stdin_bytes is None:
			return None
		stdin_stream = tempfile.TemporaryFile(mode="w+b", buffering=0)
		stopped = prelaunch_stop_result()
		if stopped is not None:
			return close_staged_stdin_for_stop(stopped)
		payload = memoryview(stdin_bytes)
		offset = 0
		while offset < len(payload):
			stopped = prelaunch_stop_result()
			if stopped is not None:
				return close_staged_stdin_for_stop(stopped)
			chunk = payload[offset:offset + STDIN_STAGE_CHUNK_BYTES]
			written = stdin_stream.write(chunk)
			if (
				isinstance(written, bool)
				or not isinstance(written, int)
				or written <= 0
				or written > len(chunk)
			):
				raise OSError("Could not make progress while staging subprocess stdin.")
			offset += written
			stopped = prelaunch_stop_result()
			if stopped is not None:
				return close_staged_stdin_for_stop(stopped)
		stdin_stream.seek(0)
		stopped = prelaunch_stop_result()
		if stopped is not None:
			return close_staged_stdin_for_stop(stopped)
		return None

	def owned_process() -> subprocess.Popen[str] | None:
		# owner.start() retains the child before it returns. This fallback closes the
		# bytecode-sized gap between that return and assignment to the local variable.
		nonlocal process
		if process is None and owner is not None:
			process = owner._started_process
		return process

	def record_cleanup_error(
		action: str,
		error: BaseException,
		*,
		marks_cleanup_failed: bool = True,
	) -> None:
		nonlocal pending_error, pending_traceback
		if pending_error is None:
			pending_error = error
			try:
				pending_traceback = safe_exception_traceback(error)
			except BaseException:
				pending_traceback = None
		try:
			if owner is not None and marks_cleanup_failed:
				owner.cleanup_failed = True
		except BaseException:
			pass
		try:
			notes.append(
				f"{action} failed during process cleanup: {type(error).__name__}: {error}"
			)
		except BaseException:
			try:
				notes.append(
					f"{action} failed during process cleanup: "
					f"{type(error).__name__}: detail unavailable"
				)
			except BaseException:
				pass

	def run_cleanup_action(
		checkpoint_name: str,
		action_name: str,
		action: Callable[[], None],
	) -> None:
		# The real action lives in finally so a deterministic or asynchronous
		# checkpoint exception cannot skip that stage.
		try:
			try:
				_process_supervision_checkpoint(checkpoint_name)
			except BaseException as error:
				record_cleanup_error(
					f"{action_name} checkpoint",
					error,
					marks_cleanup_failed=False,
				)
		finally:
			try:
				action()
			except BaseException as error:
				record_cleanup_error(action_name, error)

	def attempt_tree_termination() -> bool:
		target_process = owned_process()
		if target_process is None:
			return True
		if owner is None or getattr(target_process, "_gf_process_tree_owner", None) is not owner:
			if owner is not None:
				owner.cleanup_failed = True
			notes.append("Started process lost its kernel process-tree owner binding during cleanup.")
			return False
		notes.extend(terminate_process_tree(target_process))
		return owner.termination_succeeded()

	def ensure_tree_termination() -> None:
		nonlocal tree_termination_completed
		if tree_termination_completed:
			return
		tree_termination_completed = attempt_tree_termination()

	def initial_termination() -> None:
		# Preserve the independent final attempt on exceptional paths. A successful
		# initial stop does not suppress the final pre-reap verification/attempt.
		attempt_tree_termination()

	def output_drain() -> None:
		nonlocal timed_out
		target_process = owned_process()
		if target_process is None:
			return
		output_drained = True
		if output_threads:
			output_drained = drain_output_pumps(target_process, tuple(output_threads), notes)
		if not output_drained and not cancelled:
			timed_out = True

	def final_termination() -> None:
		ensure_tree_termination()

	def direct_reap() -> None:
		nonlocal direct_reap_completed
		target_process = owned_process()
		try:
			if direct_reap_completed:
				return
			# If interruption skipped the preceding call boundary, terminate here
			# before releasing the POSIX leader PID/PGID.
			ensure_tree_termination()
			if not tree_termination_completed:
				return
			if target_process is not None:
				reap_direct_process(target_process, notes)
				direct_reap_completed = target_process.returncode is not None
				if not direct_reap_completed and owner is not None:
					owner.cleanup_failed = True
			else:
				direct_reap_completed = True
		finally:
			# Pumps close their own streams, but startup and partial-pump failures can
			# leave one or both pipes unowned. Never contend with a live pump's
			# TextIOWrapper lock unless the owned tree has definitely terminated.
			if (
				target_process is not None
				and tree_termination_completed
				and direct_reap_completed
			):
				_close_process_pipes(target_process)

	def cleanup_confirmation() -> None:
		nonlocal cleanup_confirmation_completed
		if cleanup_confirmation_completed:
			return
		# The same staged fallback covers interruption immediately before the direct
		# reap call while preserving the no-signal-after-reap invariant.
		direct_reap()
		if not direct_reap_completed:
			return
		if owner is not None:
			notes.extend(owner.confirm_cleanup_after_reap())
			cleanup_confirmation_completed = owner.cleanup_confirmation_succeeded()
		else:
			cleanup_confirmation_completed = True

	def owner_close() -> None:
		nonlocal direct_reap_completed
		if owner is None:
			return
		target_process = owned_process()
		# Always release the kernel owner, even if a retried earlier cleanup step
		# fails. On Windows, kill-on-close remains the last-resort tree boundary.
		try:
			cleanup_confirmation()
		finally:
			try:
				notes.extend(owner.close())
			finally:
				# A successful Windows Job close terminates every member even when
				# TerminateJobObject could not be confirmed. Reap only after that
				# atomic owner state is published, then pipes are safe to close.
				if (
					target_process is not None
					and owner.close_terminates_tree()
					and owner.is_closed()
					and owner.close_succeeded()
				):
					reap_direct_process(target_process, notes)
					direct_reap_completed = target_process.returncode is not None
					if not direct_reap_completed:
						owner.cleanup_failed = True
					else:
						_close_process_pipes(target_process)
				if (
					target_process is not None
					and direct_reap_completed
					and owner.is_closed()
					and owner._started_process is target_process
				):
					# The direct PID has been reaped and the kernel owner has reached a
					# terminal close state.  Retaining the Popen no longer carries tree
					# authority and makes later diagnostics falsely report an owned child.
					owner._started_process = None

	# Install the complete cleanup chain before constructing the owner or starting a
	# child. Nested finally blocks ensure any single BaseException at a stage boundary
	# still runs every later stage. The first captured error is re-raised only after
	# owner close.
	try:
		try:
			try:
				try:
					try:
						try:
							try:
								try:
									stopped = stage_stdin_before_launch()
									if stopped is not None:
										raise PrelaunchStopped(stopped)
									if stdin_stream is not None:
										_process_supervision_checkpoint("stdin_staged")
									owner = _new_process_tree_owner()
									stopped = prelaunch_stop_result()
									if stopped is not None:
										raise PrelaunchStopped(close_staged_stdin_for_stop(stopped))
									owner._stdin_stream = stdin_stream
									owner._text_errors = text_errors
									owner._binary_output = binary_output
									process = owner.start(
										command,
										cwd=cwd,
										environment=environment,
									)
								except PrelaunchStopped:
									raise
								except BaseException as error:
									close_staged_stdin_preserving(error)
									raise
								else:
									try:
										close_staged_stdin()
									except BaseException as error:
										close_staged_stdin_preserving(error)
										raise
								finally:
									if owner is not None:
										owner._stdin_stream = None
								_process_supervision_checkpoint("process_owner_started")
								setattr(process, "_gf_process_tree_owner", owner)
								if process_started_callback is not None:
									process_started_callback(process.pid)
								output_threads.append(start_output_pump(
									process.stdout,
									stdout_parts,
									stdout_callback,
									"stdout",
									callback_errors,
									callback_error_lock,
									last_output_at,
									activity_lock,
									max_stdout_characters,
									stdout_truncated,
									text_errors,
								))
								output_threads.append(start_output_pump(
									process.stderr,
									stderr_parts,
									stderr_callback,
									"stderr",
									callback_errors,
									callback_error_lock,
									last_output_at,
									activity_lock,
									max_stderr_characters,
									stderr_truncated,
									text_errors,
								))
								while not owner.wait_for_direct_exit(process, 0.0):
									now = time.perf_counter()
									remaining = deadline - now
									if remaining <= 0.0:
										timed_out = True
										notes.append(
											f"Command timed out after {timeout_seconds:g}s; "
											"terminating its process tree."
										)
										notes.extend(terminate_process_tree(process))
										break
									if cancellation_event is not None and cancellation_event.is_set():
										cancelled = True
										notes.append(
											"Command cancellation was requested; terminating its process tree."
										)
										notes.extend(terminate_process_tree(process))
										break
									if heartbeat_callback is not None and now >= next_heartbeat:
										with activity_lock:
											last_activity = last_output_at[0]
										if now - last_activity >= heartbeat_interval_seconds:
											try:
												heartbeat_callback(now - started, process.pid)
											except Exception as exc:  # pragma: no cover - defensive callback boundary
												with callback_error_lock:
													callback_errors.append(f"heartbeat callback failed: {exc}")
											next_heartbeat = now + max(0.1, heartbeat_interval_seconds)
										else:
											next_heartbeat = last_activity + max(0.1, heartbeat_interval_seconds)
									owner.wait_for_direct_exit(process, min(0.25, remaining))
							except PrelaunchStopped:
								raise
							except BaseException as error:
								command_failed = True
								pending_error = error
								pending_traceback = safe_exception_traceback(error)
							finally:
								if command_failed:
									run_cleanup_action(
										"before_initial_termination",
										"Initial process-tree termination",
										initial_termination,
									)
						finally:
							run_cleanup_action(
								"before_output_drain",
								"Output draining",
								output_drain,
							)
					finally:
						run_cleanup_action(
							"before_final_termination",
							"Final process-tree termination",
							final_termination,
						)
				finally:
					# No POSIX signal may be sent after this point: reaping releases
					# the leader PID and permits its numeric PGID to be reused.
					run_cleanup_action(
						"before_direct_reap",
						"Direct-child reap",
						direct_reap,
					)
			finally:
				run_cleanup_action(
					"before_cleanup_confirmation",
					"Owned process-tree confirmation",
					cleanup_confirmation,
				)
		finally:
			run_cleanup_action(
				"before_owner_close",
				"Process-tree owner close",
				owner_close,
			)
	except PrelaunchStopped as stopped:
		prelaunch_result = stopped.result
	except BaseException as error:
		# A boundary exception not raised by a cleanup action still arrives only
		# after all lexically outer cleanup stages have run.
		record_cleanup_error("Process cleanup sequencing", error)
	finally:
		# One final idempotent attempt covers interruption immediately before or
		# during the normal close call. It is dormant on the successful path.
		if owner is not None and not owner.is_closed():
			try:
				owner_close()
			except BaseException as error:
				record_cleanup_error("Emergency process-tree owner close", error)
	no_child_owner_quiet = (
		owner is not None
		and process is None
		and owner._started_process is None
		and owner._process_was_created is False
		and owner.cleanup_failed is False
		and owner.is_closed()
	)
	if (
		pending_error is not None
		and isinstance(pending_error, (FileNotFoundError, PermissionError))
		and no_child_owner_quiet
	):
		raise SupervisedProcessStartError(pending_error) from pending_error
	if pending_error is not None:
		if owner is None or no_child_owner_quiet:
			raise BaseException.with_traceback(pending_error, pending_traceback)
		owner_closed = owner is not None and owner.is_closed()
		process_tree_empty = (
			tree_termination_completed and cleanup_confirmation_completed
		)
		cleanup_complete = (
			owner is not None
			and owner.cleanup_failed is False
			and owner_closed
			and process_tree_empty
			and direct_reap_completed
		)
		if cleanup_complete:
			raise BaseException.with_traceback(pending_error, pending_traceback)
		owned_pid = 0
		owned_target = process
		if owned_target is None and owner is not None:
			owned_target = owner._started_process
		if owned_target is not None:
			owned_pid = owned_target.pid
		raise SupervisedProcessCleanupError(
			"Process supervision failed without a proven quiet process boundary.",
			notes=tuple(notes),
			original_error=pending_error,
			pid=owned_pid,
			owner_closed=owner_closed,
			process_tree_empty=process_tree_empty,
			direct_reaped=direct_reap_completed,
			cleanup_confirmation_complete=cleanup_confirmation_completed,
		) from pending_error
	if prelaunch_result is not None:
		prelaunch_notes = (*prelaunch_result.notes, *notes)
		if owner is not None and (
			owner.cleanup_failed
			or not owner.is_closed()
			or not tree_termination_completed
			or not direct_reap_completed
			or not cleanup_confirmation_completed
		):
			raise SupervisedProcessCleanupError(
				"Process launch stopped before child creation, but process-tree owner "
				"cleanup was not proven complete.",
				notes=prelaunch_notes,
			)
		return replace(prelaunch_result, notes=prelaunch_notes)
	if owner is None or process is None:
		raise RuntimeError("Process supervision completed without a started process.")
	if owner.cleanup_failed and not cancelled:
		timed_out = True
	if stdout_truncated[0]:
		notes.append("Captured stdout exceeded its configured character limit.")
	if stderr_truncated[0]:
		notes.append("Captured stderr exceeded its configured character limit.")
	notes.extend(callback_errors)
	return SupervisedProcessResult(
		return_code=process.returncode if process.returncode is not None else 124,
		stdout="".join(stdout_parts),
		stderr="".join(stderr_parts),
		timed_out=timed_out,
		duration_seconds=time.perf_counter() - started,
		pid=process.pid,
		notes=tuple(notes),
		cancelled=cancelled,
		stdout_truncated=stdout_truncated[0],
		stderr_truncated=stderr_truncated[0],
		process_boundary_quiescent=(
			owner.is_closed()
			and tree_termination_completed
			and direct_reap_completed
			and cleanup_confirmation_completed
		),
	)


def start_output_pump(
	pipe: Any,
	parts: list[str],
	callback: Callable[[str], None] | None,
	stream_name: str,
	callback_errors: list[str],
	callback_error_lock: threading.Lock,
	last_output_at: list[float],
	activity_lock: threading.Lock,
	max_capture_characters: int | None = None,
	capture_truncated: list[bool] | None = None,
	decode_errors: str = "replace",
) -> threading.Thread:
	def pump() -> None:
		if pipe is None:
			return
		try:
			read_next = (
				(lambda: pipe.readline())
				if max_capture_characters is None
				else (lambda: pipe.read(4096))
			)
			captured_characters = 0
			while True:
				output_chunk = read_next()
				if not output_chunk:
					break
				if isinstance(output_chunk, bytes):
					output_chunk = output_chunk.decode("utf-8", errors=decode_errors)
				if max_capture_characters is None:
					parts.append(output_chunk)
				else:
					remaining = max_capture_characters - captured_characters
					if remaining > 0:
						captured = output_chunk[:remaining]
						parts.append(captured)
						captured_characters += len(captured)
					if len(output_chunk) > max(remaining, 0):
						if capture_truncated is not None:
							capture_truncated[0] = True
				with activity_lock:
					last_output_at[0] = time.perf_counter()
				if callback is not None:
					try:
						callback(output_chunk)
					except Exception as exc:  # pragma: no cover - defensive callback boundary
						with callback_error_lock:
							callback_errors.append(f"{stream_name} callback failed: {exc}")
		finally:
			pipe.close()

	thread = threading.Thread(target=pump, name=f"gf-{stream_name}-pump", daemon=True)
	thread.start()
	return thread


def drain_output_pumps(
	process: subprocess.Popen[str],
	threads: tuple[threading.Thread, ...],
	notes: list[str],
) -> bool:
	if wait_for_output_pumps(threads, OUTPUT_DRAIN_GRACE_SECONDS):
		return True
	notes.append(
		"Output pipes remained open after the direct child exited; "
		"terminating the owned process tree instead of truncating output silently."
	)
	notes.extend(terminate_process_tree(process))
	if not wait_for_output_pumps(threads, OUTPUT_CLEANUP_GRACE_SECONDS):
		notes.append("Output pumps did not reach EOF after descendant cleanup.")
	return False


def wait_for_output_pumps(threads: tuple[threading.Thread, ...], timeout_seconds: float) -> bool:
	deadline = time.perf_counter() + max(0.0, timeout_seconds)
	while True:
		alive_threads = [thread for thread in threads if thread.is_alive()]
		if not alive_threads:
			return True
		remaining = deadline - time.perf_counter()
		if remaining <= 0.0:
			return False
		for thread in alive_threads:
			thread.join(timeout=min(0.05, remaining))


def terminate_remaining_descendants(root_pid: int) -> list[str]:
	if os.name == "nt":
		return [
			"Windows descendant cleanup requires the Job Object handle retained by run_supervised_process; "
			f"refusing an unsafe PID-tree snapshot for root PID {root_pid}."
		]
	return terminate_posix_process_group_id(root_pid)


def terminate_posix_process_group_id(
	process_group_id: int,
	*,
	grace_seconds: float = 0.1,
) -> list[str]:
	notes: list[str] = []
	try:
		os.killpg(process_group_id, signal.SIGTERM)
	except ProcessLookupError:
		return notes
	except OSError as exc:
		return [f"Could not terminate remaining process group {process_group_id}: {exc}"]
	if grace_seconds > 0.0:
		time.sleep(grace_seconds)
	try:
		os.killpg(process_group_id, signal.SIGKILL)
	except ProcessLookupError:
		pass
	except OSError as exc:
		notes.append(f"Could not kill remaining process group {process_group_id}: {exc}")
	return notes


def run_supervised_completed_process(
	command: list[str],
	*,
	cwd: Path,
	timeout_seconds: float,
	environment: dict[str, str],
) -> subprocess.CompletedProcess[str]:
	"""Compatibility wrapper for call sites that consume CompletedProcess."""
	if environment is None:
		raise TypeError(
			"Supervised completed process requires an explicit environment."
		)
	try:
		result = run_supervised_process(
			command,
			cwd=cwd,
			timeout_seconds=timeout_seconds,
			environment=environment,
		)
	except SupervisedProcessStartError as error:
		raise error.original_error from error
	if result.process_boundary_quiescent is not True:
		raise SupervisedProcessCleanupError(
			"CompletedProcess compatibility result lacked a quiet process-boundary proof.",
			notes=result.notes,
		)
	if result.timed_out:
		raise subprocess.TimeoutExpired(
			command,
			timeout_seconds,
			output=result.stdout,
			stderr=result.stderr,
		)
	return subprocess.CompletedProcess(
		command,
		result.return_code,
		stdout=result.stdout,
		stderr=result.stderr,
	)


def process_group_options() -> dict[str, Any]:
	if os.name == "nt":
		return {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
	return {"start_new_session": True}


def terminate_process_tree(process: subprocess.Popen[str]) -> list[str]:
	owner = getattr(process, "_gf_process_tree_owner", None)
	if isinstance(owner, _ProcessTreeOwner):
		return owner.terminate(process)
	if os.name == "nt":
		return terminate_windows_process_tree(process)
	return terminate_posix_process_tree(process)


def terminate_windows_process_tree(process: subprocess.Popen[str]) -> list[str]:
	notes = ["Process was not launched with an owned Windows Job Object; only the direct child can be stopped safely."]
	if process.poll() is not None:
		return notes
	try:
		process.kill()
		process.wait(timeout=1.0)
	except (OSError, subprocess.TimeoutExpired) as error:
		notes.append(f"Could not stop the unowned direct child process: {error}")
	return notes


def terminate_posix_process_tree(process: subprocess.Popen[str]) -> list[str]:
	try:
		process_group_id = os.getpgid(process.pid)
	except ProcessLookupError:
		return []
	# Complete every group signal while the leader PID/PGID is still retained.
	# Reaping first would allow the numeric PGID to be reused by an unrelated group.
	notes = terminate_posix_process_group_id(process_group_id)
	if not notes:
		reap_direct_process(process, notes)
	return notes


def reap_direct_process(process: subprocess.Popen[str], notes: list[str]) -> None:
	"""Reap the direct child only after its owned tree has been force-cleared."""
	try:
		process.wait(timeout=1.0)
	except subprocess.TimeoutExpired:
		try:
			process.kill()
			process.wait(timeout=1.0)
		except (OSError, subprocess.TimeoutExpired) as error:
			notes.append(f"Direct child could not be reaped after owned process-tree cleanup: {error}")
