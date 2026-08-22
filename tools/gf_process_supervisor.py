#!/usr/bin/env python3
"""Cross-platform subprocess supervision for GF maintenance commands."""

from __future__ import annotations

import math
import os
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

	def __init__(self, message: str, *, notes: tuple[str, ...] = ()) -> None:
		super().__init__(message)
		self.cleanup_debt = True
		self.process_boundary_quiescent = False
		self.notes = notes


def safe_exception_detail(error: BaseException) -> str:
	"""Format diagnostics without letting hostile exception text replace control flow."""
	try:
		return str(error)
	except BaseException:
		return "exception detail unavailable"


def safe_exception_traceback(error: BaseException) -> TracebackType | None:
	"""Capture only a real traceback without dispatching through hostile accessors."""
	try:
		traceback = BaseException.__getattribute__(error, "__traceback__")
	except BaseException:
		return None
	return traceback if traceback is None or isinstance(traceback, TracebackType) else None


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
		self._started_process: subprocess.Popen[str] | None = None
		self._process_was_created = False
		self._closed = False
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
		environment: dict[str, str] | None,
	) -> subprocess.Popen[str]:
		raise NotImplementedError

	def start_bytes(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str] | None,
	) -> subprocess.Popen[bytes]:
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
		return []

	def close_before_deadline(self, deadline: float) -> list[str]:
		notes = self.close()
		if time.perf_counter() > deadline:
			self.cleanup_failed = True
			notes.append("Process-tree owner close exceeded its absolute deadline.")
		return notes

	def wait_for_close_completion(self, timeout_seconds: float | None) -> bool:
		_ = timeout_seconds
		return self.is_closed()

	def is_closed(self) -> bool:
		return self._closed

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
		environment: dict[str, str] | None,
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
		environment: dict[str, str] | None,
	) -> subprocess.Popen[bytes]:
		return self._start_process(
			command,
			cwd=cwd,
			environment=environment,
			binary=True,
		)

	def _start_process(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str] | None,
		binary: bool,
	) -> Any:
		process: subprocess.Popen[Any] | None = None
		try:
			popen_options: dict[str, Any] = {
				"cwd": cwd,
				"stdin": subprocess.DEVNULL if binary else self._stdin_stream,
				"stdout": subprocess.PIPE,
				"stderr": subprocess.PIPE,
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
		self._termination_succeeded = time.perf_counter() <= deadline
		if not self._termination_succeeded:
			self.cleanup_failed = True
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
	from ctypes import wintypes

	_CREATE_SUSPENDED = 0x00000004
	_JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 0x00002000
	_JOB_OBJECT_BASIC_ACCOUNTING_INFORMATION_CLASS = 1
	_JOB_OBJECT_EXTENDED_LIMIT_INFORMATION_CLASS = 9
	_WAIT_OBJECT_0 = 0x00000000
	_WAIT_TIMEOUT = 0x00000102
	_WAIT_FAILED = 0xFFFFFFFF


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
				if pending_error is None:
					pending_error = error
					pending_traceback = safe_exception_traceback(error)


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
					else:
						# An exception after entering CloseHandle makes the kernel
						# result unknowable. Consume the numeric value rather than
						# risking a close against a reused handle. Keep an unreaped
						# direct child published even after the Job is gone so an
						# already-installed outer cleanup guard can retry it.
						owner.handle = 0
						if (
							owner._started_process is not None
							and owner._started_process.returncode is not None
						):
							owner._started_process = None
						owner._closed = True
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
					if pending_error is None:
						pending_error = error
						pending_traceback = safe_exception_traceback(error)
			if not worker_launched:
				try:
					_thread.start_new_thread(
						_close_windows_handle_worker,
						(owner, operation),
					)
					worker_launched = True
				except BaseException as error:
					if pending_error is None:
						pending_error = error
						pending_traceback = safe_exception_traceback(error)
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
	) -> tuple[list[str], bool]:
		"""Launch one persistent non-daemon close worker without losing the handle."""
		notes: list[str] = []
		worker_launched = False
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
			operation.finished.set()
			return notes, False
		return notes, True


	class _WindowsJobOwner(_ProcessTreeOwner):
		"""Assign a suspended child to a kill-on-close Job before any code runs."""

		def __init__(self) -> None:
			super().__init__()
			self._handle_state_lock = threading.Lock()
			self._close_operation: _WindowsHandleCloseOperation | None = None
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
			except BaseException:
				# The Job is still empty. Route every configuration-failure close
				# through the same interruption-safe state machine, retrying explicit
				# False while preserving the original configuration exception.
				for _attempt in range(2):
					try:
						self.close()
					except BaseException:
						pass
					if self.is_closed():
						break
				raise

		def start(
			self,
			command: list[str],
			*,
			cwd: Path,
			environment: dict[str, str] | None,
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
			environment: dict[str, str] | None,
		) -> subprocess.Popen[bytes]:
			return self._start_process(
				command,
				cwd=cwd,
				environment=environment,
				binary=True,
			)

		def _start_process(
			self,
			command: list[str],
			*,
			cwd: Path,
			environment: dict[str, str] | None,
			binary: bool,
		) -> Any:
			process: subprocess.Popen[Any] | None = None
			assigned_to_job = False
			try:
				popen_options: dict[str, Any] = {
					"cwd": cwd,
					"stdin": subprocess.DEVNULL if binary else self._stdin_stream,
					"stdout": subprocess.PIPE,
					"stderr": subprocess.PIPE,
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
				setattr(process, "_gf_process_tree_owner", self)
				_process_supervision_checkpoint("windows_process_started")
				process_handle = wintypes.HANDLE(int(process._handle))
				if not _ASSIGN_PROCESS_TO_JOB(wintypes.HANDLE(self.handle), process_handle):
					raise ctypes.WinError(ctypes.get_last_error())
				assigned_to_job = True
				_process_supervision_checkpoint("windows_process_assigned")
				resume_status = int(_NT_RESUME_PROCESS(process_handle))
				if resume_status != 0:
					raise OSError(
						f"NtResumeProcess failed with NTSTATUS 0x{resume_status & 0xFFFFFFFF:08x}."
					)
				return process
			except BaseException:
				if process is None:
					try:
						self.close()
					except BaseException:
						pass
					raise
				try:
					try:
						try:
							if assigned_to_job:
								_TERMINATE_JOB(wintypes.HANDLE(self.handle), 1)
							else:
								# The process is still suspended and cannot have created descendants.
								process.kill()
						finally:
							try:
								self.close()
							finally:
								try:
									reap_direct_process(process, [])
								finally:
									_close_process_pipes(process)
					except BaseException:
						# Startup must preserve its first exception after exhausting cleanup.
						pass
				finally:
					# Closing an empty/unassigned Job cannot stop this suspended
					# child. Publish it until wait() has positively observed direct
					# exit so the outer cleanup chain can retry local kill/reap
					# failures instead of losing the only process handle.
					with self._handle_state_lock:
						if process.returncode is None:
							self._started_process = process
							self.cleanup_failed = True
						elif self._started_process is process:
							self._started_process = None
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

		def terminate(self, _process: subprocess.Popen[str]) -> list[str]:
			self._termination_succeeded = False
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
			_process: subprocess.Popen[Any],
			deadline: float,
		) -> list[str]:
			self._termination_succeeded = False
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
					self.cleanup_failed = True
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
				self._cleanup_confirmation_succeeded = self._closed
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
					self.cleanup_failed = True
					return [
						"Windows Job Object cleanup could not be confirmed before "
						"its absolute deadline."
					]
				time.sleep(min(0.01, max(0.0, deadline - now)))

		def close(self) -> list[str]:
			with self._handle_state_lock:
				already_closed = self.handle == 0 and self._close_operation is None
				if already_closed:
					if (
						self._started_process is not None
						and self._started_process.returncode is not None
					):
						self._started_process = None
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
						self._started_process = None
						self._closed = True
						return []
					operation = _WindowsHandleCloseOperation(self.handle)
					self._close_operation = operation
					self.handle = 0
					self._closed = False

			notes, worker_active = _launch_windows_handle_close_before_deadline(
				self,
				operation,
			)
			if not worker_active:
				self.cleanup_failed = True
				notes.append("Windows Job Object close worker could not be retained.")
				return notes
			while not operation.finished.is_set():
				remaining = deadline - time.perf_counter()
				if remaining <= 0.0:
					self.cleanup_failed = True
					notes.append(
						"Windows Job Object close could not be confirmed before "
						"its absolute deadline."
					)
					return notes
				operation.finished.wait(min(0.01, remaining))
			outcome = _windows_handle_close_outcome(operation, None, None)
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
				self.cleanup_failed = True
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


def _drain_binary_pipe_nonblocking(
	state: _BoundedBinaryPipeState,
	stream_name: str,
	notes: list[str],
) -> None:
	while not state.eof and not state.truncated and not state.read_failed:
		remaining = state.max_bytes - state.byte_count
		try:
			chunk = os.read(
				state.pipe.fileno(),
				min(64 * 1024, remaining + 1),
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
		environment: dict[str, str] | None,
		max_stdout_bytes: int,
		max_stderr_bytes: int,
	) -> None:
		self._command = list(command)
		self._cwd = cwd
		self._environment = environment
		self._max_stdout_bytes = max_stdout_bytes
		self._max_stderr_bytes = max_stderr_bytes
		self._worker_claim_lock = threading.Lock()
		self._worker_claimed = False
		self._launch_aborted = False
		self._state_lock = threading.Lock()
		self._spawn_ready = threading.Event()
		self._caller_decision = threading.Event()
		self._finished = threading.Event()
		self._caller_claimed = False
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
				daemon=False,
			)
			try:
				worker.start()
				if first_error is not None and not isinstance(first_error, Exception):
					self.abandon()
					raise first_error.with_traceback(first_traceback)
				return
			except BaseException as error:
				if first_error is None:
					first_error = error
					first_traceback = error.__traceback__

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
			self._spawn_ready.set()
			self._finished.set()
		if first_error is not None:
			raise first_error.with_traceback(first_traceback)
		raise RuntimeError("Binary spawn worker could not be retained.")

	def claim_before_deadline(self, deadline: float) -> _BinarySpawnHandoff | None:
		remaining = deadline - time.perf_counter()
		if remaining <= 0.0 or not self._spawn_ready.wait(remaining):
			self.abandon()
			return None
		with self._state_lock:
			if time.perf_counter() > deadline:
				self._caller_abandoned = True
				self._caller_decision.set()
				return None
			error = self._error
			error_traceback = self._error_traceback
			owner = self._owner
			process = self._process
			if error is None and owner is not None and process is not None:
				self._caller_claimed = True
				self._caller_decision.set()
				handoff = _BinarySpawnHandoff(owner=owner, process=process)
			else:
				handoff = None
		if error is not None:
			raise error.with_traceback(error_traceback)
		if handoff is None:
			raise RuntimeError("Binary spawn completed without an owned process.")
		remaining = max(0.0, deadline - time.perf_counter())
		self._finished.wait(remaining)
		return handoff

	def abandon(self) -> None:
		with self._state_lock:
			if self._caller_claimed:
				return
			self._caller_abandoned = True
			self._caller_decision.set()

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
			process = owner.start_bytes(
				self._command,
				cwd=self._cwd,
				environment=self._environment,
			)
			if getattr(process, "_gf_process_tree_owner", None) is not owner:
				raise RuntimeError(
					"Started binary process lost its process-tree owner binding."
				)
			if process.stdout is None or process.stderr is None:
				raise OSError("Supervised binary process did not expose both output pipes.")
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
			cleanup_status = self._cleanup_owned_spawn(
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
		with self._state_lock:
			caller_claimed = self._caller_claimed
		if caller_claimed:
			with self._state_lock:
				self._notes = ("Binary spawn ownership transferred to the caller.",)
			self._finished.set()
			return
		cleanup_status = self._cleanup_owned_spawn(owner, process)
		self._publish_cleanup_status(cleanup_status)
		self._finished.set()

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
			if process.stdout is not None and process.stderr is not None:
				try:
					for pipe in (process.stdout, process.stderr):
						os.set_blocking(pipe.fileno(), False)
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
				except OSError as error:
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
				except OSError:
					pass
		process_tree_empty = (
			process is None
			or (
				owner.termination_succeeded()
				and owner.cleanup_confirmation_succeeded()
			)
		)
		owner_closed = owner.is_closed()
		cleanup_complete = (
			process_tree_empty
			and direct_reaped
			and owner_closed
			and not owner.cleanup_failed
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


class _BinaryOwnerCloseObservation:
	"""Observe a retained close worker after the caller's deadline elapsed."""

	def __init__(
		self,
		owner: _ProcessTreeOwner,
		*,
		pid: int,
		process_tree_empty: bool,
		direct_reaped: bool,
		notes: tuple[str, ...],
	) -> None:
		self._owner = owner
		self._pid = pid
		self._process_tree_empty = process_tree_empty
		self._direct_reaped = direct_reaped
		self._notes = notes

	def wait(self, timeout_seconds: float | None) -> bool:
		return self._owner.wait_for_close_completion(timeout_seconds)

	def snapshot(self) -> SupervisedBinaryCleanupStatus:
		owner_closed = self._owner.is_closed()
		return SupervisedBinaryCleanupStatus(
			complete=owner_closed,
			cleanup_complete=(
				owner_closed
				and self._process_tree_empty
				and self._direct_reaped
				and not self._owner.cleanup_failed
			),
			owner_closed=owner_closed,
			process_tree_empty=self._process_tree_empty,
			pid=self._pid,
			notes=self._notes,
		)


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


def run_supervised_process_bytes(
	command: list[str],
	*,
	cwd: Path,
	timeout_seconds: float,
	max_stdout_bytes: int,
	max_stderr_bytes: int,
	environment: dict[str, str] | None = None,
) -> SupervisedBinaryProcessResult:
	"""Run one owned process tree with raw, byte-bounded output capture."""
	started = time.perf_counter()
	if (
		isinstance(timeout_seconds, bool)
		or not isinstance(timeout_seconds, (int, float))
		or not math.isfinite(float(timeout_seconds))
		or float(timeout_seconds) <= 0.0
	):
		raise ValueError("Binary process timeout must be a finite positive number.")
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

	deadline = started + float(timeout_seconds)
	cleanup_reserve = min(
		BINARY_PROCESS_CLEANUP_RESERVE_SECONDS,
		float(timeout_seconds) * 0.5,
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
		spawn_operation.abandon()
		raise
	if handoff is None:
		duration_seconds = time.perf_counter() - started
		return SupervisedBinaryProcessResult(
			return_code=124,
			stdout=b"",
			stderr=b"",
			timed_out=True,
			duration_seconds=duration_seconds,
			pid=spawn_operation.current_pid(),
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
	pending_error: BaseException | None = None
	pending_traceback: Any = None

	try:
		# Spawn admission validated owner binding and both pipes before handoff.
		stdout_pipe = process.stdout
		stderr_pipe = process.stderr
		if stdout_pipe is None or stderr_pipe is None:
			raise RuntimeError("Binary spawn handoff lost its captured output pipes.")
		for pipe in (stdout_pipe, stderr_pipe):
			os.set_blocking(pipe.fileno(), False)
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
		pending_error = error
		pending_traceback = error.__traceback__
	finally:
		if owner is not None and process is not None:
			try:
				notes.extend(owner.terminate_before_deadline(process, deadline))
			except BaseException as error:
				owner.cleanup_failed = True
				notes.append(
					f"Binary process-tree termination failed: {type(error).__name__}."
				)
				if pending_error is None:
					pending_error = error
					pending_traceback = error.__traceback__

			pipe_drain_deadline = min(
				deadline,
				time.perf_counter() + BINARY_PROCESS_POST_TERMINATION_DRAIN_SECONDS,
			)
			while stdout_state is not None and stderr_state is not None:
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
				if pending_error is None:
					pending_error = error
					pending_traceback = error.__traceback__

			try:
				notes.extend(owner.confirm_cleanup_after_reap_before_deadline(deadline))
			except BaseException as error:
				owner.cleanup_failed = True
				notes.append(
					f"Binary process-tree confirmation failed: {type(error).__name__}."
				)
				if pending_error is None:
					pending_error = error
					pending_traceback = error.__traceback__

		if owner is not None:
			try:
				notes.extend(owner.close_before_deadline(deadline))
			except BaseException as error:
				owner.cleanup_failed = True
				notes.append(f"Binary process-tree owner close failed: {type(error).__name__}.")
				if pending_error is None:
					pending_error = error
					pending_traceback = error.__traceback__

		if process is not None:
			for pipe in (process.stdout, process.stderr):
				if pipe is None:
					continue
				try:
					pipe.close()
				except OSError:
					pass

	if pending_error is not None:
		raise pending_error.with_traceback(pending_traceback)
	if owner is None or process is None or stdout_state is None or stderr_state is None:
		raise RuntimeError("Binary process supervision completed without a process result.")
	duration_seconds = time.perf_counter() - started
	deadline_respected = duration_seconds <= float(timeout_seconds)
	if not deadline_respected:
		timed_out = True
		notes.append("Binary process supervision exceeded its absolute deadline.")
	process_tree_empty = (
		owner.termination_succeeded()
		and owner.cleanup_confirmation_succeeded()
	)
	cleanup_complete = (
		process_tree_empty
		and direct_reaped
		and owner.is_closed()
		and not owner.cleanup_failed
		and deadline_respected
	)
	deferred_cleanup: SupervisedBinaryCleanupHandle | None = None
	if not owner.is_closed():
		deferred_cleanup = SupervisedBinaryCleanupHandle(
			_BinaryOwnerCloseObservation(
				owner,
				pid=process.pid,
				process_tree_empty=process_tree_empty,
				direct_reaped=direct_reaped,
				notes=tuple(notes),
			)
		)
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
	environment: dict[str, str] | None = None,
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
		"""Close staged input without replacing an in-flight control exception."""
		try:
			close_staged_stdin()
		except BaseException as cleanup_error:
			# Startup/staging still owns no live process here. Preserve the first
			# exception exactly, while retaining the close failure as diagnostics.
			try:
				BaseException.add_note(
					primary_error,
					"Staged subprocess stdin cleanup also failed: "
					f"{type(cleanup_error).__name__}: "
					f"{safe_exception_detail(cleanup_error)}"
				)
			except BaseException:
				pass

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
		try:
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
		except BaseException as error:
			close_staged_stdin_preserving(error)
			raise
		return None

	def owned_process() -> subprocess.Popen[str] | None:
		# owner.start() retains the child before it returns. This fallback closes the
		# bytecode-sized gap between that return and assignment to the local variable.
		nonlocal process
		if process is None and owner is not None:
			process = owner._started_process
		return process

	def record_cleanup_error(action: str, error: BaseException) -> None:
		nonlocal pending_error, pending_traceback
		if pending_error is None:
			pending_error = error
			try:
				pending_traceback = safe_exception_traceback(error)
			except BaseException:
				pending_traceback = None
		try:
			if owner is not None:
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
				record_cleanup_error(f"{action_name} checkpoint", error)
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
				):
					reap_direct_process(target_process, notes)
					direct_reap_completed = target_process.returncode is not None
					if not direct_reap_completed:
						owner.cleanup_failed = True
					else:
						_close_process_pipes(target_process)

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
	if (
		pending_error is not None
		and isinstance(pending_error, (FileNotFoundError, PermissionError))
		and process is None
		and owner is not None
		and not owner._process_was_created
		and not owner.cleanup_failed
		and owner.is_closed()
		and tree_termination_completed
		and direct_reap_completed
		and cleanup_confirmation_completed
	):
		raise SupervisedProcessStartError(pending_error) from pending_error
	if pending_error is not None:
		raise BaseException.with_traceback(pending_error, pending_traceback)
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
	environment: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
	"""Compatibility wrapper for call sites that consume CompletedProcess."""
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
