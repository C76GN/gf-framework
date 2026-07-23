#!/usr/bin/env python3
"""Cross-platform subprocess supervision for GF maintenance commands."""

from __future__ import annotations

import os
import signal
import subprocess
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from typing import Callable


OUTPUT_DRAIN_GRACE_SECONDS = 1.0
OUTPUT_CLEANUP_GRACE_SECONDS = 2.0


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


class _ProcessTreeOwner:
	"""Kernel-backed ownership for every process launched by one command."""

	def __init__(self) -> None:
		self.cleanup_failed = False
		self._started_process: subprocess.Popen[str] | None = None
		self._closed = False
		self._termination_succeeded = False
		self._cleanup_confirmation_succeeded = False

	def start(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str] | None,
	) -> subprocess.Popen[str]:
		raise NotImplementedError

	def wait_for_direct_exit(
		self,
		process: subprocess.Popen[str],
		timeout_seconds: float,
	) -> bool:
		raise NotImplementedError

	def terminate(self, process: subprocess.Popen[str]) -> list[str]:
		raise NotImplementedError

	def confirm_cleanup_after_reap(self) -> list[str]:
		self._cleanup_confirmation_succeeded = True
		return []

	def close(self) -> list[str]:
		self._started_process = None
		self._closed = True
		return []

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
		process: subprocess.Popen[str] | None = None
		try:
			process = subprocess.Popen(
				command,
				cwd=cwd,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE,
				text=True,
				encoding="utf-8",
				errors="replace",
				env=environment,
				start_new_session=True,
			)
			self._started_process = process
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
		while True:
			try:
				# Signal zero only probes existence and permissions; it does not deliver a signal.
				os.killpg(process_group_id, 0)
			except ProcessLookupError:
				self._cleanup_probe_group_id = 0
				self._cleanup_confirmation_succeeded = True
				return []
			except PermissionError:
				pass
			except OSError as error:
				self.cleanup_failed = True
				return [f"Could not confirm POSIX process group {process_group_id} cleanup: {error}"]
			if time.perf_counter() >= cleanup_deadline:
				self.cleanup_failed = True
				return [
					f"Owned POSIX process group {process_group_id} still existed after forced cleanup."
				]
			time.sleep(0.01)


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
					pending_traceback = error.__traceback__


	def _close_windows_handle_worker(owner: Any, operation: _WindowsHandleCloseOperation) -> None:
		# Retrying a close whose Thread.start() was interrupted may create another
		# contender. Exactly one worker can claim the numeric handle.
		with operation.claim_lock:
			if operation.claimed:
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
			close_traceback = error.__traceback__
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
						# risking a close against a reused handle.
						owner.handle = 0
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
						pending_traceback = error.__traceback__
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
						pending_traceback = error.__traceback__
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
			process: subprocess.Popen[str] | None = None
			assigned_to_job = False
			try:
				process = subprocess.Popen(
					command,
					cwd=cwd,
					stdout=subprocess.PIPE,
					stderr=subprocess.PIPE,
					text=True,
					encoding="utf-8",
					errors="replace",
					env=environment,
					creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | _CREATE_SUSPENDED,
				)
				self._started_process = process
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

		def close(self) -> list[str]:
			with self._handle_state_lock:
				already_closed = self.handle == 0 and self._close_operation is None
			if already_closed:
				self._started_process = None
				self._closed = True
				return []
			outcome = _close_windows_handle_in_worker(self)
			if outcome.called and outcome.result is False:
				self.cleanup_failed = True
			if outcome.error is not None:
				raise outcome.error.with_traceback(outcome.error_traceback)
			if outcome.result is False:
				return [f"Could not close the owned Windows Job Object: {ctypes.WinError(outcome.last_error)}"]
			return []

		def close_terminates_tree(self) -> bool:
			return True


def _new_process_tree_owner() -> _ProcessTreeOwner:
	if os.name == "nt":
		return _WindowsJobOwner()
	return _PosixProcessGroupOwner()


@dataclass(frozen=True)
class SupervisedProcessResult:
	return_code: int
	stdout: str
	stderr: str
	timed_out: bool
	duration_seconds: float
	pid: int
	notes: tuple[str, ...] = ()
	cancelled: bool = False


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
) -> SupervisedProcessResult:
	started = time.perf_counter()
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
		)
	owner: _ProcessTreeOwner | None = None
	process: subprocess.Popen[str] | None = None
	stdout_parts: list[str] = []
	stderr_parts: list[str] = []
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

	def owned_process() -> subprocess.Popen[str] | None:
		# owner.start() retains the child before it returns. This fallback closes the
		# bytecode-sized gap between that return and assignment to the local variable.
		nonlocal process
		if process is None and owner is not None:
			process = owner._started_process
		return process

	def record_cleanup_error(action: str, error: BaseException) -> None:
		nonlocal pending_error, pending_traceback
		if owner is not None:
			owner.cleanup_failed = True
		notes.append(f"{action} failed during process cleanup: {type(error).__name__}: {error}")
		if pending_error is None:
			pending_error = error
			pending_traceback = error.__traceback__

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
								owner = _new_process_tree_owner()
								process = owner.start(command, cwd=cwd, environment=environment)
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
							except BaseException as error:
								command_failed = True
								pending_error = error
								pending_traceback = error.__traceback__
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
	if pending_error is not None:
		raise pending_error.with_traceback(pending_traceback)
	if owner is None or process is None:
		raise RuntimeError("Process supervision completed without a started process.")
	if owner.cleanup_failed and not cancelled:
		timed_out = True
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
) -> threading.Thread:
	def pump() -> None:
		if pipe is None:
			return
		try:
			for line in iter(pipe.readline, ""):
				parts.append(line)
				with activity_lock:
					last_output_at[0] = time.perf_counter()
				if callback is not None:
					try:
						callback(line)
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
	result = run_supervised_process(
		command,
		cwd=cwd,
		timeout_seconds=timeout_seconds,
		environment=environment,
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
