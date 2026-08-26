#!/usr/bin/env python3
"""Linux real-process coverage for the public POSIX watchdog lease contract."""

from __future__ import annotations

import ctypes
from dataclasses import dataclass
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import textwrap
import time
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_process_supervisor


_PROC_SUPER_MAGIC = 0x9FA0
_TERMINAL_PROCESS_STATES = frozenset(("Z", "X", "x"))
_SERVICE_ENVIRONMENT = {
	"LANG": "C",
	"LC_ALL": "C",
	"PYTHONCOERCECLOCALE": "0",
	"PYTHONDONTWRITEBYTECODE": "1",
	"PYTHONNOUSERSITE": "1",
	"PYTHONUTF8": "1",
}


def _has_full_linux_procfs() -> bool:
	if sys.platform != "linux" or os.name != "posix":
		return False
	if not all(
		hasattr(os, name)
		for name in ("fork", "killpg", "pidfd_open", "waitid")
	):
		return False
	for required_path in (
		Path("/proc/self/stat"),
		Path("/proc/self/fd"),
		Path(f"/proc/{os.getpid()}/task/{os.getpid()}/children"),
	):
		if not required_path.exists():
			return False
	try:
		statfs_buffer = ctypes.create_string_buffer(256)
		libc = ctypes.CDLL(None, use_errno=True)
		if libc.statfs(os.fsencode("/proc"), ctypes.byref(statfs_buffer)) != 0:
			return False
		if ctypes.c_long.from_buffer(statfs_buffer).value != _PROC_SUPER_MAGIC:
			return False
		pidfd = os.pidfd_open(os.getpid(), 0)
		os.close(pidfd)
		_read_proc_stat(os.getpid())
	except (OSError, RuntimeError, ValueError):
		return False
	return True


@dataclass(frozen=True)
class _ProcStat:
	pid: int
	state: str
	parent_pid: int
	process_group_id: int
	session_id: int
	start_time_ticks: int


@dataclass(frozen=True)
class _ProcIdentity:
	pid: int
	start_time_ticks: int


def _read_proc_stat(pid: int) -> _ProcStat:
	try:
		payload = Path(f"/proc/{pid}/stat").read_bytes()
	except FileNotFoundError:
		raise
	prefix, separator, suffix = payload.rpartition(b")")
	fields = suffix.split()
	pid_token, opening, _command = prefix.partition(b" (")
	if not separator or not opening or len(fields) < 20:
		raise RuntimeError(f"Malformed proc stat for pid {pid}.")
	try:
		parsed_pid = int(pid_token)
		state = fields[0].decode("ascii")
		parent_pid = int(fields[1])
		process_group_id = int(fields[2])
		session_id = int(fields[3])
		start_time_ticks = int(fields[19])
	except (UnicodeDecodeError, ValueError) as error:
		raise RuntimeError(f"Invalid proc identity for pid {pid}.") from error
	if parsed_pid != pid or not state:
		raise RuntimeError(f"Inconsistent proc identity for pid {pid}.")
	return _ProcStat(
		pid=parsed_pid,
		state=state,
		parent_pid=parent_pid,
		process_group_id=process_group_id,
		session_id=session_id,
		start_time_ticks=start_time_ticks,
	)


def _capture_identity(pid: int) -> _ProcIdentity:
	stat = _read_proc_stat(pid)
	return _ProcIdentity(pid=pid, start_time_ticks=stat.start_time_ticks)


def _matching_live_stat(identity: _ProcIdentity) -> _ProcStat | None:
	try:
		stat = _read_proc_stat(identity.pid)
	except FileNotFoundError:
		return None
	if stat.start_time_ticks != identity.start_time_ticks:
		return None
	if stat.state in _TERMINAL_PROCESS_STATES:
		return None
	return stat


def _wait_until_identity_is_not_live(
	identity: _ProcIdentity,
	*,
	timeout_seconds: float,
) -> bool:
	deadline = time.perf_counter() + timeout_seconds
	while time.perf_counter() < deadline:
		if _matching_live_stat(identity) is None:
			return True
		time.sleep(0.02)
	return _matching_live_stat(identity) is None


def _wait_until_identities_are_not_live(
	identities: tuple[_ProcIdentity, ...],
	*,
	timeout_seconds: float,
) -> bool:
	deadline = time.perf_counter() + timeout_seconds
	while time.perf_counter() < deadline:
		if all(_matching_live_stat(identity) is None for identity in identities):
			return True
		time.sleep(0.02)
	return all(_matching_live_stat(identity) is None for identity in identities)


def _write_script(path: Path, source: str) -> None:
	path.write_text(
		textwrap.dedent(source).lstrip(),
		encoding="utf-8",
		newline="\n",
	)


def _read_json(path: Path) -> dict[str, object]:
	payload = path.read_bytes()
	if len(payload) > 64 * 1024:
		raise ValueError(f"Fixture JSON exceeded its byte limit: {path.name}")
	value = json.loads(payload.decode("utf-8"))
	if not isinstance(value, dict):
		raise ValueError(f"Fixture JSON was not an object: {path.name}")
	return value


def _wait_for_json(
	path: Path,
	*,
	timeout_seconds: float,
) -> dict[str, object]:
	deadline = time.perf_counter() + timeout_seconds
	last_error: BaseException | None = None
	while time.perf_counter() < deadline:
		try:
			return _read_json(path)
		except (FileNotFoundError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
			last_error = error
		time.sleep(0.02)
	raise AssertionError(f"Timed out waiting for {path.name}: {last_error}")


def _wait_for_json_while_running(
	path: Path,
	process: subprocess.Popen[str],
	*,
	timeout_seconds: float,
) -> dict[str, object]:
	deadline = time.perf_counter() + timeout_seconds
	last_error: BaseException | None = None
	while time.perf_counter() < deadline:
		if process.poll() is not None:
			stdout, stderr = process.communicate()
			raise AssertionError(
				"Fixture driver exited before publication: "
				f"code={process.returncode}, stdout={stdout!r}, stderr={stderr!r}"
			)
		try:
			return _read_json(path)
		except (FileNotFoundError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
			last_error = error
		time.sleep(0.02)
	raise AssertionError(f"Timed out waiting for driver publication: {last_error}")


def _fd_snapshot() -> dict[int, str]:
	result: dict[int, str] = {}
	for name in os.listdir("/proc/self/fd"):
		if not name.isdecimal():
			continue
		try:
			result[int(name)] = os.readlink(f"/proc/self/fd/{name}")
		except FileNotFoundError:
			# The descriptor used by os.listdir may already have closed.
			continue
	return result


def _direct_children() -> frozenset[int]:
	path = Path(f"/proc/{os.getpid()}/task/{os.getpid()}/children")
	return frozenset(int(value) for value in path.read_text(encoding="ascii").split())


def _identity_safe_emergency_cleanup(
	service: _ProcIdentity | None,
	helper: _ProcIdentity | None,
) -> None:
	if service is not None:
		stat = _matching_live_stat(service)
		if stat is not None and stat.process_group_id == service.pid:
			try:
				os.killpg(service.pid, signal.SIGKILL)
			except ProcessLookupError:
				pass
			_wait_until_identity_is_not_live(service, timeout_seconds=2.0)
	if helper is not None:
		stat = _matching_live_stat(helper)
		if stat is not None:
			try:
				os.kill(helper.pid, signal.SIGKILL)
			except ProcessLookupError:
				pass
			_wait_until_identity_is_not_live(helper, timeout_seconds=2.0)


def _best_effort_reap_driver(
	process: subprocess.Popen[str],
	*,
	kill_process_group: bool,
) -> None:
	if process.poll() is None:
		try:
			if kill_process_group:
				os.killpg(process.pid, signal.SIGKILL)
			else:
				process.kill()
		except ProcessLookupError:
			pass
	try:
		process.communicate(timeout=3.0)
	except subprocess.TimeoutExpired:
		if process.poll() is None:
			try:
				process.kill()
			except ProcessLookupError:
				pass
		try:
			process.communicate(timeout=1.0)
		except subprocess.TimeoutExpired:
			pass
	finally:
		for stream in (process.stdin, process.stdout, process.stderr):
			if stream is not None:
				try:
					stream.close()
				except OSError:
					pass


_SIMPLE_SERVICE = """
	import json
	import os
	from pathlib import Path
	import sys
	import time

	state_path = Path(sys.argv[1])
	payload = {
		"pid": os.getpid(),
		"parent_pid": os.getppid(),
		"process_group_id": os.getpgrp(),
		"session_id": os.getsid(0),
	}
	temporary_path = state_path.with_suffix(".tmp")
	temporary_path.write_text(json.dumps(payload), encoding="utf-8")
	os.replace(temporary_path, state_path)
	while True:
		time.sleep(60)
"""


_DESCENDANT = """
	import json
	import os
	from pathlib import Path
	import sys
	import time

	ready_path = Path(sys.argv[1])
	payload = {
		"pid": os.getpid(),
		"parent_pid": os.getppid(),
		"process_group_id": os.getpgrp(),
		"session_id": os.getsid(0),
	}
	temporary_path = ready_path.with_suffix(".tmp")
	temporary_path.write_text(json.dumps(payload), encoding="utf-8")
	os.replace(temporary_path, ready_path)
	while True:
		time.sleep(60)
"""


_SERVICE_WITH_DESCENDANT = """
	import json
	import os
	from pathlib import Path
	import subprocess
	import sys
	import time

	state_path = Path(sys.argv[1])
	descendant_script = Path(sys.argv[2])
	descendant_ready = Path(sys.argv[3])
	child = subprocess.Popen(
		[sys.executable, str(descendant_script), str(descendant_ready)],
		stdin=subprocess.DEVNULL,
		stdout=subprocess.DEVNULL,
		stderr=subprocess.DEVNULL,
		close_fds=True,
		env=dict(os.environ),
	)
	ready_deadline = time.monotonic() + 5.0
	while time.monotonic() < ready_deadline and not descendant_ready.is_file():
		if child.poll() is not None:
			raise RuntimeError("descendant exited before its ready publication")
		time.sleep(0.01)
	if not descendant_ready.is_file():
		raise TimeoutError("descendant did not publish ready evidence")
	payload = {
		"pid": os.getpid(),
		"parent_pid": os.getppid(),
		"process_group_id": os.getpgrp(),
		"session_id": os.getsid(0),
		"descendant_pid": child.pid,
	}
	temporary_path = state_path.with_suffix(".tmp")
	temporary_path.write_text(json.dumps(payload), encoding="utf-8")
	os.replace(temporary_path, state_path)
	while True:
		time.sleep(60)
"""


_ENVIRONMENT_SERVICE = """
	import json
	import os
	from pathlib import Path
	import sys
	import time

	state_path = Path(sys.argv[1])
	payload = {
		"pid": os.getpid(),
		"parent_pid": os.getppid(),
		"environment": dict(os.environ),
	}
	temporary_path = state_path.with_suffix(".tmp")
	temporary_path.write_text(json.dumps(payload, sort_keys=True), encoding="utf-8")
	os.replace(temporary_path, state_path)
	while True:
		time.sleep(60)
"""


_POLL_HEALTH_DRIVER = """
	import json
	import os
	from pathlib import Path
	import sys
	import time

	tools_root = Path(sys.argv[1])
	sys.path.insert(0, str(tools_root))
	import gf_process_supervisor

	service_script = Path(sys.argv[2])
	service_state = Path(sys.argv[3])
	descendant_script = Path(sys.argv[4])
	descendant_ready = Path(sys.argv[5])
	driver_ready = Path(sys.argv[6])
	begin_path = Path(sys.argv[7])
	result_path = Path(sys.argv[8])
	cwd = Path(sys.argv[9])
	environment = {
		"LANG": "C",
		"LC_ALL": "C",
		"PYTHONCOERCECLOCALE": "0",
		"PYTHONDONTWRITEBYTECODE": "1",
		"PYTHONNOUSERSITE": "1",
		"PYTHONUTF8": "1",
	}
	lease = None
	close_attempted = False
	payload = {}
	exit_code = 1
	try:
		deadline = time.perf_counter() + 15.0
		slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		lease = gf_process_supervisor.start_supervised_process_lease(
			[
				str(Path(sys.executable).resolve()),
				str(service_script),
				str(service_state),
				str(descendant_script),
				str(descendant_ready),
			],
			cwd=cwd,
			deadline=deadline,
			environment=environment,
			publication_slot=slot,
		)
		publication_deadline = time.perf_counter() + 5.0
		while time.perf_counter() < publication_deadline and not service_state.is_file():
			time.sleep(0.01)
		if not service_state.is_file():
			raise TimeoutError("service tree did not publish ready evidence")
		service_payload = json.loads(service_state.read_text(encoding="utf-8"))
		ready_payload = {
			"driver_pid": os.getpid(),
			"server_pid": lease.pid,
			"helper_pid": service_payload["parent_pid"],
			"descendant_pid": service_payload["descendant_pid"],
		}
		ready_temporary = driver_ready.with_suffix(".tmp")
		ready_temporary.write_text(json.dumps(ready_payload), encoding="utf-8")
		os.replace(ready_temporary, driver_ready)
		begin_deadline = time.perf_counter() + 5.0
		while time.perf_counter() < begin_deadline and not begin_path.is_file():
			time.sleep(0.01)
		if not begin_path.is_file():
			raise TimeoutError("parent did not release the poll fixture")
		for _index in range(2):
			lease.poll_health()
			lease.poll_operation_health()
		close_attempted = True
		result = lease.cancel_and_close(deadline=lease.deadline)
		payload = {
			"ok": True,
			"poll_health_count": 2,
			"poll_operation_health_count": 2,
			"cancelled": result.cancelled,
			"process_boundary_quiescent": result.process_boundary_quiescent,
		}
		exit_code = 0
	except BaseException as error:
		payload = {
			"ok": False,
			"error_type": type(error).__name__,
			"cleanup_debt": gf_process_supervisor.exception_has_cleanup_debt(error),
		}
	finally:
		if lease is not None and not close_attempted:
			try:
				lease.cancel_and_close(deadline=lease.deadline)
			except BaseException as cleanup_error:
				payload["cleanup_error_type"] = type(cleanup_error).__name__
				payload["cleanup_debt"] = (
					gf_process_supervisor.exception_has_cleanup_debt(cleanup_error)
				)
		result_temporary = result_path.with_suffix(".tmp")
		result_temporary.write_text(json.dumps(payload), encoding="utf-8")
		os.replace(result_temporary, result_path)
	raise SystemExit(exit_code)
"""


_EARLY_EXIT_DRIVER = """
	import json
	import os
	from pathlib import Path
	import sys
	import time

	tools_root = Path(sys.argv[1])
	sys.path.insert(0, str(tools_root))
	import gf_process_supervisor

	result_path = Path(sys.argv[2])
	driver_state = Path(sys.argv[3])
	cwd = Path(sys.argv[4])
	environment = {
		"LANG": "C",
		"LC_ALL": "C",
		"PYTHONCOERCECLOCALE": "0",
		"PYTHONDONTWRITEBYTECODE": "1",
		"PYTHONNOUSERSITE": "1",
		"PYTHONUTF8": "1",
	}
	children_path = Path(f"/proc/{os.getpid()}/task/{os.getpid()}/children")
	children_before = tuple(sorted(int(value) for value in children_path.read_text(
		encoding="ascii"
	).split()))
	original_wait_ready = (
		gf_process_supervisor._PosixWatchdogTransport.wait_ready_before_deadline
	)
	observed = {}

	def delayed_wait_ready(transport, deadline):
		observed["transport"] = transport
		state_temporary = driver_state.with_suffix(".tmp")
		state_temporary.write_text(json.dumps({
			"driver_pid": os.getpid(),
			"helper_pid": transport.helper.pid,
		}), encoding="utf-8")
		os.replace(state_temporary, driver_state)
		time.sleep(0.4)
		try:
			return original_wait_ready(transport, deadline)
		finally:
			observed["quiet"] = transport.quiet_payload()

	gf_process_supervisor._PosixWatchdogTransport.wait_ready_before_deadline = (
		delayed_wait_ready
	)
	slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
	payload = {}
	exit_code = 1
	lease = None
	try:
		try:
			lease = gf_process_supervisor.start_supervised_process_lease(
				["/bin/true"],
				cwd=cwd,
				deadline=time.perf_counter() + 5.0,
				environment=environment,
				publication_slot=slot,
			)
		except BaseException as error:
			children_deadline = time.perf_counter() + 2.0
			children_after = ()
			while time.perf_counter() < children_deadline:
				children_after = tuple(sorted(
					int(value)
					for value in children_path.read_text(encoding="ascii").split()
				))
				if children_after == children_before:
					break
				time.sleep(0.01)
			quiet = observed.get("quiet")
			payload = {
				"ok": isinstance(error, OSError),
				"error_type": type(error).__name__,
				"cleanup_debt": (
					gf_process_supervisor.exception_has_cleanup_debt(error)
				),
				"slot_has_lease": slot.has_lease,
				"children_before": children_before,
				"children_after": children_after,
				"quiet": quiet,
			}
			if (
				payload["ok"]
				and not payload["cleanup_debt"]
				and not payload["slot_has_lease"]
				and children_after == children_before
				and isinstance(quiet, dict)
				and quiet.get("trigger") == "early_exit"
				and quiet.get("child_created") is True
				and quiet.get("tree_empty") is True
				and quiet.get("direct_reaped") is True
			):
				exit_code = 0
		else:
			payload = {
				"ok": False,
				"error_type": "UnexpectedLeasePublication",
				"cleanup_debt": False,
				"slot_has_lease": slot.has_lease,
				"children_before": children_before,
				"children_after": tuple(sorted(
					int(value)
					for value in children_path.read_text(encoding="ascii").split()
				)),
				"quiet": observed.get("quiet"),
			}
	finally:
		gf_process_supervisor._PosixWatchdogTransport.wait_ready_before_deadline = (
			original_wait_ready
		)
		if lease is not None:
			try:
				lease.cancel_and_close(deadline=lease.deadline)
			except BaseException as cleanup_error:
				payload["cleanup_error_type"] = type(cleanup_error).__name__
				payload["cleanup_debt"] = (
					gf_process_supervisor.exception_has_cleanup_debt(cleanup_error)
				)
		result_temporary = result_path.with_suffix(".tmp")
		result_temporary.write_text(json.dumps(payload), encoding="utf-8")
		os.replace(result_temporary, result_path)
	raise SystemExit(exit_code)
"""


_DEADLINE_DRIVER = """
	import json
	import os
	from pathlib import Path
	import sys
	import time

	tools_root = Path(sys.argv[1])
	sys.path.insert(0, str(tools_root))
	import gf_process_supervisor

	service_script = Path(sys.argv[2])
	service_state = Path(sys.argv[3])
	descendant_script = Path(sys.argv[4])
	descendant_ready = Path(sys.argv[5])
	driver_ready = Path(sys.argv[6])
	close_path = Path(sys.argv[7])
	result_path = Path(sys.argv[8])
	cwd = Path(sys.argv[9])
	environment = {
		"LANG": "C",
		"LC_ALL": "C",
		"PYTHONCOERCECLOCALE": "0",
		"PYTHONDONTWRITEBYTECODE": "1",
		"PYTHONNOUSERSITE": "1",
		"PYTHONUTF8": "1",
	}
	lease = None
	close_attempted = False
	payload = {}
	exit_code = 1
	try:
		deadline = time.perf_counter() + 2.5
		slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		lease = gf_process_supervisor.start_supervised_process_lease(
			[
				str(Path(sys.executable).resolve()),
				str(service_script),
				str(service_state),
				str(descendant_script),
				str(descendant_ready),
			],
			cwd=cwd,
			deadline=deadline,
			environment=environment,
			publication_slot=slot,
		)
		publication_deadline = min(deadline, time.perf_counter() + 2.0)
		while time.perf_counter() < publication_deadline and not service_state.is_file():
			time.sleep(0.01)
		if not service_state.is_file():
			raise TimeoutError("service tree did not publish before its deadline")
		service_payload = json.loads(service_state.read_text(encoding="utf-8"))
		ready_payload = {
			"driver_pid": os.getpid(),
			"server_pid": lease.pid,
			"helper_pid": service_payload["parent_pid"],
			"descendant_pid": service_payload["descendant_pid"],
			"deadline": lease.deadline,
		}
		ready_temporary = driver_ready.with_suffix(".tmp")
		ready_temporary.write_text(json.dumps(ready_payload), encoding="utf-8")
		os.replace(ready_temporary, driver_ready)
		close_publication_deadline = deadline + 5.0
		while (
			time.perf_counter() < close_publication_deadline
			and not close_path.is_file()
		):
			time.sleep(0.01)
		if not close_path.is_file():
			raise TimeoutError("parent did not release the deadline fixture")
		close_attempted = True
		result = lease.cancel_and_close(deadline=lease.deadline)
		payload = {
			"ok": True,
			"timed_out": result.timed_out,
			"cancelled": result.cancelled,
			"process_boundary_quiescent": result.process_boundary_quiescent,
			"stdout": result.stdout,
			"stderr": result.stderr,
		}
		exit_code = 0
	except BaseException as error:
		payload = {
			"ok": False,
			"error_type": type(error).__name__,
			"cleanup_debt": gf_process_supervisor.exception_has_cleanup_debt(error),
		}
	finally:
		if lease is not None and not close_attempted:
			try:
				lease.cancel_and_close(deadline=lease.deadline)
			except BaseException as cleanup_error:
				payload["cleanup_error_type"] = type(cleanup_error).__name__
				payload["cleanup_debt"] = (
					gf_process_supervisor.exception_has_cleanup_debt(cleanup_error)
				)
		result_temporary = result_path.with_suffix(".tmp")
		result_temporary.write_text(json.dumps(payload), encoding="utf-8")
		os.replace(result_temporary, result_path)
	raise SystemExit(exit_code)
"""


_STATUS_CHANNEL_FAILURE_DRIVER = """
	import json
	import os
	from pathlib import Path
	import sys
	import time

	tools_root = Path(sys.argv[1])
	sys.path.insert(0, str(tools_root))
	import gf_process_supervisor

	service_script = Path(sys.argv[2])
	service_state = Path(sys.argv[3])
	descendant_script = Path(sys.argv[4])
	descendant_ready = Path(sys.argv[5])
	driver_ready = Path(sys.argv[6])
	begin_path = Path(sys.argv[7])
	phase_path = Path(sys.argv[8])
	result_path = Path(sys.argv[9])
	cwd = Path(sys.argv[10])
	environment = {
		"LANG": "C",
		"LC_ALL": "C",
		"PYTHONCOERCECLOCALE": "0",
		"PYTHONDONTWRITEBYTECODE": "1",
		"PYTHONNOUSERSITE": "1",
		"PYTHONUTF8": "1",
	}
	lease = None
	close_attempted = False
	payload = {}
	exit_code = 1

	def publish_phase(phase):
		phase_temporary = phase_path.with_suffix(".tmp")
		phase_temporary.write_text(phase, encoding="utf-8")
		os.replace(phase_temporary, phase_path)

	try:
		deadline = time.perf_counter() + 15.0
		slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		lease = gf_process_supervisor.start_supervised_process_lease(
			[
				str(Path(sys.executable).resolve()),
				str(service_script),
				str(service_state),
				str(descendant_script),
				str(descendant_ready),
			],
			cwd=cwd,
			deadline=deadline,
			environment=environment,
			publication_slot=slot,
		)
		publication_deadline = time.perf_counter() + 5.0
		while time.perf_counter() < publication_deadline and not service_state.is_file():
			time.sleep(0.01)
		if not service_state.is_file():
			raise TimeoutError("service tree did not publish ready evidence")
		service_payload = json.loads(service_state.read_text(encoding="utf-8"))
		ready_payload = {
			"driver_pid": os.getpid(),
			"server_pid": lease.pid,
			"helper_pid": service_payload["parent_pid"],
			"descendant_pid": service_payload["descendant_pid"],
		}
		ready_temporary = driver_ready.with_suffix(".tmp")
		ready_temporary.write_text(json.dumps(ready_payload), encoding="utf-8")
		os.replace(ready_temporary, driver_ready)
		begin_deadline = time.perf_counter() + 5.0
		while time.perf_counter() < begin_deadline and not begin_path.is_file():
			time.sleep(0.01)
		if not begin_path.is_file():
			raise TimeoutError("parent did not release the status failure fixture")
		backend = object.__getattribute__(
			lease,
			"_SupervisedProcessLease__backend",
		)
		transport = backend._transport
		control_open_before_poll = not transport._control_closed
		transport._status.close()
		publish_phase("status_closed")
		poll_started = time.perf_counter()
		poll_error = None
		try:
			lease.poll_health()
		except BaseException as error:
			poll_error = error
		poll_elapsed = time.perf_counter() - poll_started
		publish_phase("poll_returned")
		control_closed_after_poll = transport._control_closed
		close_attempted = True
		close_error = None
		publish_phase("close_entered")
		try:
			lease.cancel_and_close(deadline=lease.deadline)
		except BaseException as error:
			close_error = error
		publish_phase("close_returned")
		cleanup_status = (
			None if close_error is None else getattr(close_error, "cleanup_status", None)
		)
		payload = {
			"ok": (
				type(poll_error) is gf_process_supervisor._PosixWatchdogProtocolError
				and poll_elapsed < 2.0
				and control_open_before_poll
				and control_closed_after_poll
				and isinstance(
					close_error,
					gf_process_supervisor.SupervisedProcessCleanupError,
				)
				and close_error.cleanup_debt is True
				and close_error.process_boundary_quiescent is False
				and cleanup_status is not None
				and cleanup_status.owner_closed is True
				and cleanup_status.cleanup_complete is False
				and close_error.deferred_cleanup is not None
			),
			"poll_error_type": (
				"" if poll_error is None else type(poll_error).__name__
			),
			"poll_elapsed": poll_elapsed,
			"control_open_before_poll": control_open_before_poll,
			"control_closed_after_poll": control_closed_after_poll,
			"close_error_type": (
				"" if close_error is None else type(close_error).__name__
			),
			"cleanup_debt": (
				False if close_error is None else close_error.cleanup_debt
			),
			"process_boundary_quiescent": (
				True
				if close_error is None
				else close_error.process_boundary_quiescent
			),
			"owner_closed": (
				False if cleanup_status is None else cleanup_status.owner_closed
			),
			"cleanup_complete": (
				False if cleanup_status is None else cleanup_status.cleanup_complete
			),
			"deferred_cleanup": (
				False
				if close_error is None
				else close_error.deferred_cleanup is not None
			),
		}
		if payload["ok"]:
			exit_code = 0
	except BaseException as error:
		payload = {
			"ok": False,
			"error_type": type(error).__name__,
			"cleanup_debt": gf_process_supervisor.exception_has_cleanup_debt(error),
		}
	finally:
		if lease is not None and not close_attempted:
			try:
				lease.cancel_and_close(deadline=lease.deadline)
			except BaseException as cleanup_error:
				payload["cleanup_error_type"] = type(cleanup_error).__name__
		result_temporary = result_path.with_suffix(".tmp")
		result_temporary.write_text(json.dumps(payload), encoding="utf-8")
		os.replace(result_temporary, result_path)
	raise SystemExit(exit_code)
"""


_PARTIAL_TRANSPORT_DRIVER = """
	import json
	import os
	from pathlib import Path
	import sys
	import time

	tools_root = Path(sys.argv[1])
	sys.path.insert(0, str(tools_root))
	import gf_process_supervisor

	service_script = Path(sys.argv[2])
	driver_state = Path(sys.argv[3])
	result_path = Path(sys.argv[4])
	failure_index = int(sys.argv[5])
	cwd = Path(sys.argv[6])
	environment = {
		"LANG": "C",
		"LC_ALL": "C",
		"PYTHONCOERCECLOCALE": "0",
		"PYTHONDONTWRITEBYTECODE": "1",
		"PYTHONNOUSERSITE": "1",
		"PYTHONUTF8": "1",
	}

	def fd_snapshot():
		result = {}
		for name in os.listdir("/proc/self/fd"):
			if not name.isdecimal():
				continue
			try:
				result[int(name)] = os.readlink(f"/proc/self/fd/{name}")
			except FileNotFoundError:
				continue
		return result

	def direct_children():
		children_path = Path(
			f"/proc/{os.getpid()}/task/{os.getpid()}/children"
		)
		return tuple(sorted(
			int(value)
			for value in children_path.read_text(encoding="ascii").split()
		))

	class InjectedTransportInitError(RuntimeError):
		pass

	original_init = gf_process_supervisor._PosixWatchdogTransport.__init__
	injected_error = InjectedTransportInitError(
		f"injected set_blocking failure {failure_index}"
	)
	observed = {}

	def faulting_init(transport, helper, *args, **kwargs):
		observed["helper"] = helper
		observed["stdin"] = helper.stdin
		observed["status"] = helper.stdout
		original_set_blocking = gf_process_supervisor.os.set_blocking
		call_count = 0

		def faulting_set_blocking(fd, blocking):
			nonlocal call_count
			call_count += 1
			if call_count == failure_index:
				helper_stat = Path(f"/proc/{helper.pid}/stat").read_bytes()
				_fields = helper_stat.rpartition(b")")[2].split()
				state_temporary = driver_state.with_suffix(".tmp")
				state_temporary.write_text(json.dumps({
					"driver_pid": os.getpid(),
					"helper_pid": helper.pid,
					"helper_start_time_ticks": int(_fields[19]),
				}), encoding="utf-8")
				os.replace(state_temporary, driver_state)
				raise injected_error
			return original_set_blocking(fd, blocking)

		gf_process_supervisor.os.set_blocking = faulting_set_blocking
		try:
			return original_init(transport, helper, *args, **kwargs)
		finally:
			observed["set_blocking_count"] = call_count
			gf_process_supervisor.os.set_blocking = original_set_blocking

	gf_process_supervisor._PosixWatchdogTransport.__init__ = faulting_init
	children_before = direct_children()
	fds_before = fd_snapshot()
	slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
	lease = None
	payload = {}
	exit_code = 1
	try:
		try:
			lease = gf_process_supervisor.start_supervised_process_lease(
				[
					str(Path(sys.executable).resolve()),
					str(service_script),
					str(cwd / "unused-service-state.json"),
				],
				cwd=cwd,
				deadline=time.perf_counter() + 5.0,
				environment=environment,
				publication_slot=slot,
			)
		except BaseException as error:
			helper = observed.get("helper")
			settle_deadline = time.perf_counter() + 2.0
			children_after = direct_children()
			while time.perf_counter() < settle_deadline:
				if helper is not None:
					helper.poll()
				children_after = direct_children()
				if children_after == children_before:
					break
				time.sleep(0.01)
			fds_after = fd_snapshot()
			stdin_stream = observed.get("stdin")
			status_stream = observed.get("status")
			payload = {
				"ok": (
					error is injected_error
					and not gf_process_supervisor.exception_has_cleanup_debt(error)
					and not slot.has_lease
					and observed.get("set_blocking_count") == failure_index
					and stdin_stream is not None
					and stdin_stream.closed
					and status_stream is not None
					and status_stream.closed
					and helper is not None
					and helper.pidfd_closed()
					and helper.poll() is not None
					and children_after == children_before
					and fds_after == fds_before
				),
				"same_error": error is injected_error,
				"error_type": type(error).__name__,
				"cleanup_debt": (
					gf_process_supervisor.exception_has_cleanup_debt(error)
				),
				"slot_has_lease": slot.has_lease,
				"set_blocking_count": observed.get("set_blocking_count", 0),
				"stdin_closed": (
					False if stdin_stream is None else stdin_stream.closed
				),
				"status_closed": (
					False if status_stream is None else status_stream.closed
				),
				"pidfd_closed": (
					False if helper is None else helper.pidfd_closed()
				),
				"helper_reaped": (
					False if helper is None else helper.poll() is not None
				),
				"children_restored": children_after == children_before,
				"fds_restored": fds_after == fds_before,
			}
			if payload["ok"]:
				exit_code = 0
		else:
			payload = {
				"ok": False,
				"error_type": "UnexpectedLeasePublication",
				"slot_has_lease": slot.has_lease,
			}
	finally:
		gf_process_supervisor._PosixWatchdogTransport.__init__ = original_init
		if lease is not None:
			try:
				lease.cancel_and_close(deadline=lease.deadline)
			except BaseException as cleanup_error:
				payload["cleanup_error_type"] = type(cleanup_error).__name__
		result_temporary = result_path.with_suffix(".tmp")
		result_temporary.write_text(json.dumps(payload), encoding="utf-8")
		os.replace(result_temporary, result_path)
	raise SystemExit(exit_code)
"""


_OUTER_KILL_DRIVER = """
	import json
	import os
	from pathlib import Path
	import sys
	import time

	tools_root = Path(sys.argv[1])
	sys.path.insert(0, str(tools_root))
	import gf_process_supervisor

	service_script = Path(sys.argv[2])
	service_state = Path(sys.argv[3])
	descendant_script = Path(sys.argv[4])
	descendant_ready = Path(sys.argv[5])
	driver_ready = Path(sys.argv[6])
	cwd = Path(sys.argv[7])
	environment = {
		"LANG": "C",
		"LC_ALL": "C",
		"PYTHONCOERCECLOCALE": "0",
		"PYTHONDONTWRITEBYTECODE": "1",
		"PYTHONNOUSERSITE": "1",
		"PYTHONUTF8": "1",
	}
	deadline = time.perf_counter() + 20.0
	slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
	lease = gf_process_supervisor.start_supervised_process_lease(
		[
			str(Path(sys.executable).resolve()),
			str(service_script),
			str(service_state),
			str(descendant_script),
			str(descendant_ready),
		],
		cwd=cwd,
		deadline=deadline,
		environment=environment,
		publication_slot=slot,
	)
	publication_deadline = time.perf_counter() + 5.0
	while time.perf_counter() < publication_deadline and not service_state.is_file():
		time.sleep(0.01)
	if not service_state.is_file():
		raise TimeoutError("service tree did not publish ready evidence")
	service_payload = json.loads(service_state.read_text(encoding="utf-8"))
	payload = {
		"driver_pid": os.getpid(),
		"server_pid": lease.pid,
		"helper_pid": service_payload["parent_pid"],
		"descendant_pid": service_payload["descendant_pid"],
	}
	temporary_path = driver_ready.with_suffix(".tmp")
	temporary_path.write_text(json.dumps(payload), encoding="utf-8")
	os.replace(temporary_path, driver_ready)
	while True:
		time.sleep(60)
"""


_SIGCHLD_IGNORED_DRIVER = """
	import json
	import os
	from pathlib import Path
	import signal
	import sys
	import time

	tools_root = Path(sys.argv[1])
	sys.path.insert(0, str(tools_root))
	import gf_process_supervisor

	service_script = Path(sys.argv[2])
	service_state = Path(sys.argv[3])
	result_path = Path(sys.argv[4])
	cwd = Path(sys.argv[5])
	signal.signal(signal.SIGCHLD, signal.SIG_IGN)
	environment = {
		"LANG": "C",
		"LC_ALL": "C",
		"PYTHONCOERCECLOCALE": "0",
		"PYTHONDONTWRITEBYTECODE": "1",
		"PYTHONNOUSERSITE": "1",
		"PYTHONUTF8": "1",
	}
	payload = {}
	exit_code = 1
	lease = None
	try:
		deadline = time.perf_counter() + 10.0
		slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		lease = gf_process_supervisor.start_supervised_process_lease(
			[str(Path(sys.executable).resolve()), str(service_script), str(service_state)],
			cwd=cwd,
			deadline=deadline,
			environment=environment,
			publication_slot=slot,
		)
		publication_deadline = time.perf_counter() + 3.0
		while time.perf_counter() < publication_deadline and not service_state.is_file():
			time.sleep(0.01)
		if not service_state.is_file():
			raise TimeoutError("service did not publish ready evidence")
		service_payload = json.loads(service_state.read_text(encoding="utf-8"))
		result = lease.cancel_and_close(deadline=lease.deadline)
		payload = {
			"ok": True,
			"server_pid": lease.pid,
			"helper_pid": service_payload["parent_pid"],
			"cancelled": result.cancelled,
			"process_boundary_quiescent": result.process_boundary_quiescent,
			"stdout": result.stdout,
			"stderr": result.stderr,
		}
		exit_code = 0
	except BaseException as error:
		payload = {
			"ok": False,
			"error_type": type(error).__name__,
			"cleanup_debt": gf_process_supervisor.exception_has_cleanup_debt(error),
			"server_pid": 0 if lease is None else lease.pid,
		}
	finally:
		temporary_path = result_path.with_suffix(".tmp")
		temporary_path.write_text(json.dumps(payload), encoding="utf-8")
		os.replace(temporary_path, result_path)
	raise SystemExit(exit_code)
"""


@unittest.skipUnless(
	_has_full_linux_procfs(),
	"POSIX watchdog integration tests require Linux with a complete real procfs.",
)
class PosixProcessWatchdogIntegrationTests(unittest.TestCase):
	def _start_service(
		self,
		command: list[str],
		*,
		cwd: Path,
		environment: dict[str, str] | None = None,
		lifetime_seconds: float = 12.0,
	) -> tuple[
		gf_process_supervisor.SupervisedProcessLeasePublicationSlot,
		object,
	]:
		slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		lease = gf_process_supervisor.start_supervised_process_lease(
			command,
			cwd=cwd,
			deadline=time.perf_counter() + lifetime_seconds,
			environment=(
				dict(_SERVICE_ENVIRONMENT)
				if environment is None
				else dict(environment)
			),
			publication_slot=slot,
		)
		self.assertIs(slot.get(), lease)
		self.assertEqual(lease.pid, slot.get().pid)
		return slot, lease

	def _best_effort_close(self, lease: object | None) -> None:
		if lease is None:
			return
		try:
			lease.cancel_and_close(deadline=lease.deadline)
		except BaseException:
			pass

	def _assert_quiet_identities(self, *identities: _ProcIdentity) -> None:
		for identity in identities:
			self.assertTrue(
				_wait_until_identity_is_not_live(identity, timeout_seconds=5.0),
				f"Process identity remained live after watchdog cleanup: {identity}",
			)

	def test_normal_start_cancel_publishes_quiet_result(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-normal-") as temporary:
			root = Path(temporary)
			service_script = root / "service.py"
			state_path = root / "service-state.json"
			_write_script(service_script, _SIMPLE_SERVICE)
			lease = None
			close_attempted = False
			try:
				_slot, lease = self._start_service(
					[str(Path(sys.executable).resolve()), str(service_script), str(state_path)],
					cwd=root,
				)
				state = _wait_for_json(
					state_path,
					timeout_seconds=3.0,
				)
				self.assertEqual(state["pid"], lease.pid)
				self.assertEqual(state["process_group_id"], lease.pid)
				close_attempted = True
				result = lease.cancel_and_close(deadline=lease.deadline)
				self.assertTrue(result.cancelled)
				self.assertTrue(result.process_boundary_quiescent)
				self.assertEqual(result.pid, lease.pid)
				self.assertEqual(result.stdout, "")
				self.assertEqual(result.stderr, "")
				self.assertFalse(result.stdout_truncated)
				self.assertFalse(result.stderr_truncated)
			finally:
				if not close_attempted:
					self._best_effort_close(lease)

	def test_public_lease_uses_exact_supervised_process_lease_facade(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-facade-") as temporary:
			root = Path(temporary)
			service_script = root / "service.py"
			state_path = root / "service-state.json"
			_write_script(service_script, _SIMPLE_SERVICE)
			lease = None
			close_attempted = False
			try:
				_slot, lease = self._start_service(
					[str(Path(sys.executable).resolve()), str(service_script), str(state_path)],
					cwd=root,
				)
				_wait_for_json(state_path, timeout_seconds=3.0)
				self.assertIs(
					type(lease),
					gf_process_supervisor.SupervisedProcessLease,
				)
				close_attempted = True
				result = lease.cancel_and_close(deadline=lease.deadline)
				self.assertTrue(result.process_boundary_quiescent)
			finally:
				if not close_attempted:
					self._best_effort_close(lease)

	def test_cancel_kills_real_descendant_group(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-tree-") as temporary:
			root = Path(temporary)
			service_script = root / "service.py"
			descendant_script = root / "descendant.py"
			state_path = root / "service-state.json"
			descendant_ready = root / "descendant-state.json"
			_write_script(service_script, _SERVICE_WITH_DESCENDANT)
			_write_script(descendant_script, _DESCENDANT)
			lease = None
			close_attempted = False
			try:
				_slot, lease = self._start_service(
					[
						str(Path(sys.executable).resolve()),
						str(service_script),
						str(state_path),
						str(descendant_script),
						str(descendant_ready),
					],
					cwd=root,
				)
				state = _wait_for_json(
					state_path,
					timeout_seconds=4.0,
				)
				server_identity = _capture_identity(lease.pid)
				descendant_pid = int(state["descendant_pid"])
				descendant_identity = _capture_identity(descendant_pid)
				self.assertEqual(_read_proc_stat(descendant_pid).process_group_id, lease.pid)
				close_attempted = True
				result = lease.cancel_and_close(deadline=lease.deadline)
				self.assertTrue(result.process_boundary_quiescent)
				self.assertTrue(result.cancelled)
				self._assert_quiet_identities(server_identity, descendant_identity)
			finally:
				if not close_attempted:
					self._best_effort_close(lease)

	def test_public_health_polls_are_bounded_and_preserve_quiet_cleanup(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-poll-") as temporary:
			root = Path(temporary)
			driver_script = root / "driver.py"
			service_script = root / "service.py"
			descendant_script = root / "descendant.py"
			service_state = root / "service-state.json"
			descendant_ready = root / "descendant-state.json"
			driver_ready = root / "driver-ready.json"
			begin_path = root / "begin"
			result_path = root / "driver-result.json"
			_write_script(driver_script, _POLL_HEALTH_DRIVER)
			_write_script(service_script, _SERVICE_WITH_DESCENDANT)
			_write_script(descendant_script, _DESCENDANT)
			driver = subprocess.Popen(
				[
					str(Path(sys.executable).resolve()),
					str(driver_script),
					str(TOOLS_ROOT),
					str(service_script),
					str(service_state),
					str(descendant_script),
					str(descendant_ready),
					str(driver_ready),
					str(begin_path),
					str(result_path),
					str(root),
				],
				cwd=root,
				env=dict(_SERVICE_ENVIRONMENT),
				stdin=subprocess.DEVNULL,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE,
				text=True,
				encoding="utf-8",
				start_new_session=True,
				close_fds=True,
			)
			server_identity = None
			helper_identity = None
			descendant_identity = None
			timed_out = False
			stdout = ""
			stderr = ""
			quiet_after_driver = True
			try:
				publication = _wait_for_json_while_running(
					driver_ready,
					driver,
					timeout_seconds=7.0,
				)
				self.assertEqual(publication["driver_pid"], driver.pid)
				server_identity = _capture_identity(int(publication["server_pid"]))
				helper_identity = _capture_identity(int(publication["helper_pid"]))
				descendant_identity = _capture_identity(
					int(publication["descendant_pid"])
				)
				begin_path.write_text("begin\n", encoding="utf-8", newline="\n")
				try:
					stdout, stderr = driver.communicate(timeout=5.0)
				except subprocess.TimeoutExpired as error:
					timed_out = True
					stdout = str(error.stdout or "")
					stderr = str(error.stderr or "")
			finally:
				_best_effort_reap_driver(driver, kill_process_group=True)
				for identity in (
					server_identity,
					descendant_identity,
					helper_identity,
				):
					if identity is not None and not _wait_until_identity_is_not_live(
						identity,
						timeout_seconds=5.0,
					):
						quiet_after_driver = False
				if not quiet_after_driver:
					_identity_safe_emergency_cleanup(server_identity, helper_identity)
			self.assertTrue(
				quiet_after_driver,
				"Watchdog did not clean the poll driver's service tree after parent exit.",
			)
			if timed_out:
				self.fail(
					"Public process lease health polling exceeded its bounded driver timeout; "
					f"stdout={stdout!r}, stderr={stderr!r}"
				)
			payload = _read_json(result_path)
			self.assertEqual(
				driver.returncode,
				0,
				f"payload={payload!r}, stdout={stdout!r}, stderr={stderr!r}",
			)
			self.assertIs(payload["ok"], True)
			self.assertEqual(payload["poll_health_count"], 2)
			self.assertEqual(payload["poll_operation_health_count"], 2)
			self.assertIs(payload["cancelled"], True)
			self.assertIs(payload["process_boundary_quiescent"], True)

	def test_outer_driver_sigkill_control_eof_cleans_service_tree(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-eof-") as temporary:
			root = Path(temporary)
			driver_script = root / "driver.py"
			service_script = root / "service.py"
			descendant_script = root / "descendant.py"
			service_state = root / "service-state.json"
			descendant_ready = root / "descendant-state.json"
			driver_ready = root / "driver-ready.json"
			_write_script(driver_script, _OUTER_KILL_DRIVER)
			_write_script(service_script, _SERVICE_WITH_DESCENDANT)
			_write_script(descendant_script, _DESCENDANT)
			driver = subprocess.Popen(
				[
					str(Path(sys.executable).resolve()),
					str(driver_script),
					str(TOOLS_ROOT),
					str(service_script),
					str(service_state),
					str(descendant_script),
					str(descendant_ready),
					str(driver_ready),
					str(root),
				],
				cwd=root,
				env=dict(_SERVICE_ENVIRONMENT),
				stdin=subprocess.DEVNULL,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE,
				text=True,
				encoding="utf-8",
				start_new_session=True,
				close_fds=True,
			)
			server_identity = None
			helper_identity = None
			try:
				publication = _wait_for_json_while_running(
					driver_ready,
					driver,
					timeout_seconds=7.0,
				)
				self.assertEqual(publication["driver_pid"], driver.pid)
				server_identity = _capture_identity(int(publication["server_pid"]))
				helper_identity = _capture_identity(int(publication["helper_pid"]))
				descendant_identity = _capture_identity(
					int(publication["descendant_pid"])
				)
				os.killpg(driver.pid, signal.SIGKILL)
				stdout, stderr = driver.communicate(timeout=5.0)
				self.assertEqual(
					driver.returncode,
					-signal.SIGKILL,
					f"stdout={stdout!r}, stderr={stderr!r}",
				)
				self._assert_quiet_identities(
					server_identity,
					descendant_identity,
					helper_identity,
				)
			finally:
				_best_effort_reap_driver(driver, kill_process_group=True)
				_identity_safe_emergency_cleanup(server_identity, helper_identity)

	def test_ready_status_epipe_cleans_tree_while_control_stays_open(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-status-epipe-") as temporary:
			root = Path(temporary)
			service_script = root / "service.py"
			descendant_script = root / "descendant.py"
			service_state = root / "service-state.json"
			descendant_ready = root / "descendant-state.json"
			_write_script(service_script, _SERVICE_WITH_DESCENDANT)
			_write_script(descendant_script, _DESCENDANT)
			control_read, control_write = os.pipe2(os.O_CLOEXEC)
			status_read, status_write = os.pipe2(os.O_CLOEXEC)
			helper = None
			helper_identity = None
			server_identity = None
			descendant_identity = None
			stdout = ""
			stderr = ""
			control_open_at_helper_exit = False
			quiet_after_helper = True
			try:
				os.set_blocking(status_write, False)
				filled_bytes = 0
				while True:
					try:
						filled_bytes += os.write(status_write, b"x" * 4096)
					except BlockingIOError:
						break
				os.set_blocking(status_write, True)
				self.assertGreaterEqual(filled_bytes, 4096)
				nonce = "a" * 64
				deadline_ns = time.monotonic_ns() + 10_000_000_000
				helper = subprocess.Popen(
					[
						str(Path(sys.executable).resolve()),
						"-I",
						"-S",
						str((TOOLS_ROOT / "gf_posix_process_watchdog.py").resolve()),
						"--control-fd",
						str(control_read),
						"--status-fd",
						str(status_write),
						"--deadline-ns",
						str(deadline_ns),
						"--nonce",
						nonce,
					],
					cwd=root,
					env=dict(_SERVICE_ENVIRONMENT),
					stdin=subprocess.DEVNULL,
					stdout=subprocess.PIPE,
					stderr=subprocess.PIPE,
					text=True,
					encoding="utf-8",
					start_new_session=True,
					close_fds=True,
					pass_fds=(control_read, status_write),
				)
				helper_identity = _capture_identity(helper.pid)
				os.close(control_read)
				control_read = -1
				os.close(status_write)
				status_write = -1
				config = {
					"version": 1,
					"nonce": nonce,
					"type": "CONFIG",
					"deadline_ns": deadline_ns,
					"cwd": str(root.resolve()),
					"command": [
						str(Path(sys.executable).resolve()),
						str(service_script.resolve()),
						str(service_state.resolve()),
						str(descendant_script.resolve()),
						str(descendant_ready.resolve()),
					],
					"environment": dict(_SERVICE_ENVIRONMENT),
				}
				config_frame = (
					json.dumps(
						config,
						ensure_ascii=True,
						separators=(",", ":"),
					).encode("ascii")
					+ b"\n"
				)
				config_view = memoryview(config_frame)
				while config_view:
					written = os.write(control_write, config_view)
					self.assertGreater(written, 0)
					config_view = config_view[written:]
				state = _wait_for_json_while_running(
					service_state,
					helper,
					timeout_seconds=4.0,
				)
				self.assertEqual(state["parent_pid"], helper.pid)
				server_identity = _capture_identity(int(state["pid"]))
				descendant_identity = _capture_identity(int(state["descendant_pid"]))
				self.assertEqual(
					_read_proc_stat(descendant_identity.pid).process_group_id,
					server_identity.pid,
				)
				os.close(status_read)
				status_read = -1
				try:
					stdout, stderr = helper.communicate(timeout=5.0)
				except subprocess.TimeoutExpired:
					self.fail(
						"Watchdog ignored READY status EPIPE while control remained open."
					)
				os.fstat(control_write)
				control_open_at_helper_exit = True
				self.assertEqual(
					helper.returncode,
					0,
					f"stdout={stdout!r}, stderr={stderr!r}",
				)
			finally:
				for descriptor in (
					status_read,
					status_write,
					control_write,
					control_read,
				):
					if descriptor >= 0:
						try:
							os.close(descriptor)
						except OSError:
							pass
				if helper is not None:
					_best_effort_reap_driver(helper, kill_process_group=True)
				for identity in (
					server_identity,
					descendant_identity,
					helper_identity,
				):
					if identity is not None and not _wait_until_identity_is_not_live(
						identity,
						timeout_seconds=5.0,
					):
						quiet_after_helper = False
				if not quiet_after_helper:
					_identity_safe_emergency_cleanup(server_identity, helper_identity)
			self.assertTrue(
				control_open_at_helper_exit,
				"Control writer closed before status-channel failure cleanup completed.",
			)
			self.assertTrue(
				quiet_after_helper,
				"READY status EPIPE left a real helper, service, or descendant live.",
			)

	def test_parent_status_failure_fails_poll_and_closes_control_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-status-read-") as temporary:
			root = Path(temporary)
			driver_script = root / "driver.py"
			service_script = root / "service.py"
			descendant_script = root / "descendant.py"
			service_state = root / "service-state.json"
			descendant_ready = root / "descendant-state.json"
			driver_ready = root / "driver-ready.json"
			begin_path = root / "begin"
			phase_path = root / "phase"
			result_path = root / "driver-result.json"
			_write_script(driver_script, _STATUS_CHANNEL_FAILURE_DRIVER)
			_write_script(service_script, _SERVICE_WITH_DESCENDANT)
			_write_script(descendant_script, _DESCENDANT)
			driver = subprocess.Popen(
				[
					str(Path(sys.executable).resolve()),
					str(driver_script),
					str(TOOLS_ROOT),
					str(service_script),
					str(service_state),
					str(descendant_script),
					str(descendant_ready),
					str(driver_ready),
					str(begin_path),
					str(phase_path),
					str(result_path),
					str(root),
				],
				cwd=root,
				env=dict(_SERVICE_ENVIRONMENT),
				stdin=subprocess.DEVNULL,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE,
				text=True,
				encoding="utf-8",
				start_new_session=True,
				close_fds=True,
			)
			server_identity = None
			helper_identity = None
			descendant_identity = None
			driver_timed_out = False
			quiet_after_driver = True
			stdout = ""
			stderr = ""
			try:
				publication = _wait_for_json_while_running(
					driver_ready,
					driver,
					timeout_seconds=7.0,
				)
				self.assertEqual(publication["driver_pid"], driver.pid)
				server_identity = _capture_identity(int(publication["server_pid"]))
				helper_identity = _capture_identity(int(publication["helper_pid"]))
				descendant_identity = _capture_identity(
					int(publication["descendant_pid"])
				)
				begin_path.write_text("begin\n", encoding="utf-8", newline="\n")
				try:
					stdout, stderr = driver.communicate(timeout=7.0)
				except subprocess.TimeoutExpired as error:
					driver_timed_out = True
					stdout = str(error.stdout or "")
					stderr = str(error.stderr or "")
			finally:
				_best_effort_reap_driver(driver, kill_process_group=True)
				for identity in (
					server_identity,
					descendant_identity,
					helper_identity,
				):
					if identity is not None and not _wait_until_identity_is_not_live(
						identity,
						timeout_seconds=5.0,
					):
						quiet_after_driver = False
				if not quiet_after_driver:
					_identity_safe_emergency_cleanup(server_identity, helper_identity)
			self.assertTrue(
				quiet_after_driver,
				"Parent status failure left a helper, service, or descendant live.",
			)
			if driver_timed_out:
				phase = (
					phase_path.read_text(encoding="utf-8")
					if phase_path.is_file()
					else "not-published"
				)
				self.fail(
					"Public poll/close status-failure path exceeded its driver timeout; "
					f"phase={phase!r}, stdout={stdout!r}, stderr={stderr!r}"
				)
			payload = _read_json(result_path)
			self.assertEqual(
				driver.returncode,
				0,
				f"payload={payload!r}, stdout={stdout!r}, stderr={stderr!r}",
			)
			self.assertIs(payload["ok"], True)
			self.assertEqual(payload["poll_error_type"], "_PosixWatchdogProtocolError")
			self.assertLess(float(payload["poll_elapsed"]), 2.0)
			self.assertIs(payload["control_open_before_poll"], True)
			self.assertIs(payload["control_closed_after_poll"], True)
			self.assertEqual(
				payload["close_error_type"],
				"SupervisedProcessCleanupError",
			)
			self.assertIs(payload["cleanup_debt"], True)
			self.assertIs(payload["process_boundary_quiescent"], False)
			self.assertIs(payload["owner_closed"], True)
			self.assertIs(payload["cleanup_complete"], False)
			self.assertIs(payload["deferred_cleanup"], True)

	def test_partial_transport_init_failure_closes_raw_resources_and_reaps_helper(
		self,
	) -> None:
		for failure_index in (1, 2):
			with self.subTest(set_blocking_call=failure_index):
				with tempfile.TemporaryDirectory(
					prefix=f"gf-posix-watchdog-partial-{failure_index}-"
				) as temporary:
					root = Path(temporary)
					driver_script = root / "driver.py"
					service_script = root / "service.py"
					driver_state = root / "driver-state.json"
					result_path = root / "driver-result.json"
					_write_script(driver_script, _PARTIAL_TRANSPORT_DRIVER)
					_write_script(service_script, _SIMPLE_SERVICE)
					driver = subprocess.Popen(
						[
							str(Path(sys.executable).resolve()),
							str(driver_script),
							str(TOOLS_ROOT),
							str(service_script),
							str(driver_state),
							str(result_path),
							str(failure_index),
							str(root),
						],
						cwd=root,
						env=dict(_SERVICE_ENVIRONMENT),
						stdin=subprocess.DEVNULL,
						stdout=subprocess.PIPE,
						stderr=subprocess.PIPE,
						text=True,
						encoding="utf-8",
						start_new_session=True,
						close_fds=True,
					)
					helper_identity = None
					driver_timed_out = False
					quiet_after_driver = True
					stdout = ""
					stderr = ""
					try:
						publication = _wait_for_json(
							driver_state,
							timeout_seconds=4.0,
						)
						self.assertEqual(publication["driver_pid"], driver.pid)
						helper_identity = _ProcIdentity(
							pid=int(publication["helper_pid"]),
							start_time_ticks=int(
								publication["helper_start_time_ticks"]
							),
						)
						try:
							stdout, stderr = driver.communicate(timeout=7.0)
						except subprocess.TimeoutExpired as error:
							driver_timed_out = True
							stdout = str(error.stdout or "")
							stderr = str(error.stderr or "")
					finally:
						_best_effort_reap_driver(driver, kill_process_group=True)
						if helper_identity is not None and not (
							_wait_until_identity_is_not_live(
								helper_identity,
								timeout_seconds=5.0,
							)
						):
							quiet_after_driver = False
							_identity_safe_emergency_cleanup(None, helper_identity)
					self.assertTrue(
						quiet_after_driver,
						"Partial transport init left its exact helper identity live.",
					)
					if driver_timed_out:
						self.fail(
							"Partial transport cleanup exceeded its driver timeout; "
							f"call={failure_index}, stdout={stdout!r}, stderr={stderr!r}"
						)
					payload = _read_json(result_path)
					self.assertEqual(
						driver.returncode,
						0,
						f"call={failure_index}, payload={payload!r}, "
						f"stdout={stdout!r}, stderr={stderr!r}",
					)
					self.assertIs(payload["ok"], True)
					self.assertIs(payload["same_error"], True)
					self.assertEqual(
						payload["error_type"],
						"InjectedTransportInitError",
					)
					self.assertIs(payload["cleanup_debt"], False)
					self.assertIs(payload["slot_has_lease"], False)
					self.assertEqual(payload["set_blocking_count"], failure_index)
					self.assertIs(payload["stdin_closed"], True)
					self.assertIs(payload["status_closed"], True)
					self.assertIs(payload["pidfd_closed"], True)
					self.assertIs(payload["helper_reaped"], True)
					self.assertIs(payload["children_restored"], True)
					self.assertIs(payload["fds_restored"], True)

	def test_absolute_deadline_cleans_tree_before_caller_closes_lease(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-deadline-") as temporary:
			root = Path(temporary)
			driver_script = root / "driver.py"
			service_script = root / "service.py"
			descendant_script = root / "descendant.py"
			service_state = root / "service-state.json"
			descendant_ready = root / "descendant-state.json"
			driver_ready = root / "driver-ready.json"
			close_path = root / "close"
			result_path = root / "driver-result.json"
			_write_script(driver_script, _DEADLINE_DRIVER)
			_write_script(service_script, _SERVICE_WITH_DESCENDANT)
			_write_script(descendant_script, _DESCENDANT)
			driver = subprocess.Popen(
				[
					str(Path(sys.executable).resolve()),
					str(driver_script),
					str(TOOLS_ROOT),
					str(service_script),
					str(service_state),
					str(descendant_script),
					str(descendant_ready),
					str(driver_ready),
					str(close_path),
					str(result_path),
					str(root),
				],
				cwd=root,
				env=dict(_SERVICE_ENVIRONMENT),
				stdin=subprocess.DEVNULL,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE,
				text=True,
				encoding="utf-8",
				start_new_session=True,
				close_fds=True,
			)
			server_identity = None
			helper_identity = None
			descendant_identity = None
			deadline_tree_quiet = False
			driver_alive_at_quiet = False
			driver_timed_out = False
			stdout = ""
			stderr = ""
			quiet_after_driver = True
			try:
				publication = _wait_for_json_while_running(
					driver_ready,
					driver,
					timeout_seconds=5.0,
				)
				self.assertEqual(publication["driver_pid"], driver.pid)
				server_identity = _capture_identity(int(publication["server_pid"]))
				helper_identity = _capture_identity(int(publication["helper_pid"]))
				descendant_identity = _capture_identity(
					int(publication["descendant_pid"])
				)
				remaining = max(
					0.0,
					float(publication["deadline"]) - time.perf_counter(),
				)
				deadline_tree_quiet = _wait_until_identities_are_not_live(
					(server_identity, descendant_identity, helper_identity),
					timeout_seconds=min(5.0, remaining + 3.0),
				)
				driver_alive_at_quiet = driver.poll() is None
				close_path.write_text("close\n", encoding="utf-8", newline="\n")
				try:
					stdout, stderr = driver.communicate(timeout=5.0)
				except subprocess.TimeoutExpired as error:
					driver_timed_out = True
					stdout = str(error.stdout or "")
					stderr = str(error.stderr or "")
			finally:
				if not close_path.exists():
					close_path.write_text("close\n", encoding="utf-8", newline="\n")
				_best_effort_reap_driver(driver, kill_process_group=True)
				for identity in (
					server_identity,
					descendant_identity,
					helper_identity,
				):
					if identity is not None and not _wait_until_identity_is_not_live(
						identity,
						timeout_seconds=5.0,
					):
						quiet_after_driver = False
				if not quiet_after_driver:
					_identity_safe_emergency_cleanup(server_identity, helper_identity)
			self.assertTrue(
				deadline_tree_quiet,
				"Absolute lease deadline did not clean the service tree autonomously.",
			)
			self.assertTrue(
				driver_alive_at_quiet,
				"Fixture driver exited instead of retaining its open lease control pipe.",
			)
			self.assertTrue(
				quiet_after_driver,
				"Deadline fixture left a live process identity after driver cleanup.",
			)
			if driver_timed_out:
				self.fail(
					"Deadline fixture close exceeded its bounded driver timeout; "
					f"stdout={stdout!r}, stderr={stderr!r}"
				)
			payload = _read_json(result_path)
			self.assertEqual(
				driver.returncode,
				0,
				f"payload={payload!r}, stdout={stdout!r}, stderr={stderr!r}",
			)
			self.assertIs(payload["ok"], True)
			self.assertIs(payload["timed_out"], True)
			self.assertIs(payload["cancelled"], False)
			self.assertIs(payload["process_boundary_quiescent"], True)
			self.assertEqual(payload["stdout"], "")
			self.assertEqual(payload["stderr"], "")

	def test_service_environment_is_exact_and_helper_is_python_isolated(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-env-") as temporary:
			root = Path(temporary)
			canary_root = root / "canary"
			canary_root.mkdir()
			service_script = root / "service.py"
			state_path = root / "service-state.json"
			_write_script(service_script, _ENVIRONMENT_SERVICE)
			_write_script(
				canary_root / "sitecustomize.py",
				"""
					import json
					import os
					from pathlib import Path
					import sys

					root = Path(os.environ["GF_SITECUSTOMIZE_CANARY_ROOT"])
					payload = {
						"pid": os.getpid(),
						"parent_pid": os.getppid(),
						"argv0": sys.argv[0],
					}
					(root / f"{os.getpid()}.json").write_text(
						json.dumps(payload), encoding="utf-8"
					)
				""",
			)
			exact_environment = dict(_SERVICE_ENVIRONMENT)
			exact_environment.update(
				{
					"GF_EXACT_SERVICE_MARKER": "service-only",
					"GF_SITECUSTOMIZE_CANARY_ROOT": str(canary_root),
					"PYTHONPATH": str(canary_root),
				}
			)
			ambient_canary = {
				"GF_AMBIENT_ONLY_MARKER": "must-not-reach-service",
				"GF_SITECUSTOMIZE_CANARY_ROOT": str(canary_root),
				"PYTHONPATH": str(canary_root),
			}
			lease = None
			close_attempted = False
			try:
				with mock.patch.dict(os.environ, ambient_canary, clear=False):
					_slot, lease = self._start_service(
						[
							str(Path(sys.executable).resolve()),
							str(service_script),
							str(state_path),
						],
						cwd=root,
						environment=exact_environment,
					)
					state = _wait_for_json(
						state_path,
						timeout_seconds=3.0,
					)
					close_attempted = True
					result = lease.cancel_and_close(deadline=lease.deadline)
				self.assertTrue(result.process_boundary_quiescent)
				self.assertEqual(state["pid"], lease.pid)
				self.assertEqual(state["environment"], exact_environment)
				canary_payloads = [_read_json(path) for path in canary_root.glob("*.json")]
				self.assertEqual(len(canary_payloads), 1)
				self.assertEqual(canary_payloads[0]["pid"], lease.pid)
			finally:
				if not close_attempted:
					self._best_effort_close(lease)

	def test_inherited_sigchld_ignore_still_produces_reaped_quiet_result(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-sigchld-") as temporary:
			root = Path(temporary)
			driver_script = root / "driver.py"
			service_script = root / "service.py"
			service_state = root / "service-state.json"
			result_path = root / "driver-result.json"
			_write_script(driver_script, _SIGCHLD_IGNORED_DRIVER)
			_write_script(service_script, _SIMPLE_SERVICE)
			driver = subprocess.Popen(
				[
					str(Path(sys.executable).resolve()),
					str(driver_script),
					str(TOOLS_ROOT),
					str(service_script),
					str(service_state),
					str(result_path),
					str(root),
				],
				cwd=root,
				env=dict(_SERVICE_ENVIRONMENT),
				stdin=subprocess.DEVNULL,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE,
				text=True,
				encoding="utf-8",
				close_fds=True,
			)
			try:
				try:
					stdout, stderr = driver.communicate(timeout=14.0)
				except subprocess.TimeoutExpired:
					driver.kill()
					stdout, stderr = driver.communicate(timeout=3.0)
					self.fail(
						"SIGCHLD fixture timed out: "
						f"stdout={stdout!r}, stderr={stderr!r}"
					)
				payload = _read_json(result_path)
				self.assertEqual(
					driver.returncode,
					0,
					f"payload={payload!r}, stdout={stdout!r}, stderr={stderr!r}",
				)
				self.assertIs(payload["ok"], True)
				self.assertIs(payload["cancelled"], True)
				self.assertIs(payload["process_boundary_quiescent"], True)
				self.assertEqual(payload["stdout"], "")
				self.assertEqual(payload["stderr"], "")
			finally:
				_best_effort_reap_driver(driver, kill_process_group=False)

	def test_exec_failure_is_quiet_without_cleanup_debt(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-exec-") as temporary:
			root = Path(temporary)
			missing_executable = root / "missing-executable"
			slot = gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
			children_before = _direct_children()
			with self.assertRaises(OSError) as raised:
				gf_process_supervisor.start_supervised_process_lease(
					[str(missing_executable), "fixture"],
					cwd=root,
					deadline=time.perf_counter() + 8.0,
					environment=dict(_SERVICE_ENVIRONMENT),
					publication_slot=slot,
				)
			self.assertFalse(
				gf_process_supervisor.exception_has_cleanup_debt(raised.exception)
			)
			self.assertFalse(slot.has_lease)
			self.assertEqual(_direct_children(), children_before)

	def test_instant_exit_fails_start_after_real_child_quiet_evidence(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-early-exit-") as temporary:
			root = Path(temporary)
			driver_script = root / "driver.py"
			driver_state = root / "driver-state.json"
			result_path = root / "driver-result.json"
			_write_script(driver_script, _EARLY_EXIT_DRIVER)
			driver = subprocess.Popen(
				[
					str(Path(sys.executable).resolve()),
					str(driver_script),
					str(TOOLS_ROOT),
					str(result_path),
					str(driver_state),
					str(root),
				],
				cwd=root,
				env=dict(_SERVICE_ENVIRONMENT),
				stdin=subprocess.DEVNULL,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE,
				text=True,
				encoding="utf-8",
				start_new_session=True,
				close_fds=True,
			)
			helper_identity = None
			service_identity = None
			driver_timed_out = False
			stdout = ""
			stderr = ""
			quiet_after_driver = True
			try:
				publication = _wait_for_json_while_running(
					driver_state,
					driver,
					timeout_seconds=3.0,
				)
				self.assertEqual(publication["driver_pid"], driver.pid)
				helper_identity = _capture_identity(int(publication["helper_pid"]))
				try:
					stdout, stderr = driver.communicate(timeout=5.0)
				except subprocess.TimeoutExpired as error:
					driver_timed_out = True
					stdout = str(error.stdout or "")
					stderr = str(error.stderr or "")
					helper_stat = _matching_live_stat(helper_identity)
					if helper_stat is not None:
						children_path = Path(
							f"/proc/{helper_identity.pid}/task/"
							f"{helper_identity.pid}/children"
						)
						try:
							children = children_path.read_text(
								encoding="ascii"
							).split()
						except FileNotFoundError:
							children = []
						if children:
							try:
								service_identity = _capture_identity(int(children[0]))
							except FileNotFoundError:
								pass
			finally:
				_best_effort_reap_driver(driver, kill_process_group=True)
				for identity in (service_identity, helper_identity):
					if identity is not None and not _wait_until_identity_is_not_live(
						identity,
						timeout_seconds=5.0,
					):
						quiet_after_driver = False
				if not quiet_after_driver:
					_identity_safe_emergency_cleanup(service_identity, helper_identity)
			self.assertTrue(
				quiet_after_driver,
				"Instant-exit fixture left a real helper or service identity live.",
			)
			if driver_timed_out:
				self.fail(
					"Instant-exit public start exceeded its bounded driver timeout; "
					f"stdout={stdout!r}, stderr={stderr!r}"
				)
			payload = _read_json(result_path)
			self.assertEqual(
				driver.returncode,
				0,
				f"payload={payload!r}, stdout={stdout!r}, stderr={stderr!r}",
			)
			self.assertIs(payload["ok"], True)
			self.assertEqual(payload["error_type"], "OSError")
			self.assertIs(payload["cleanup_debt"], False)
			self.assertIs(payload["slot_has_lease"], False)
			self.assertEqual(payload["children_after"], payload["children_before"])
			quiet = payload["quiet"]
			self.assertIsInstance(quiet, dict)
			self.assertEqual(quiet["trigger"], "early_exit")
			self.assertIs(quiet["ready"], True)
			self.assertIs(quiet["child_created"], True)
			self.assertIs(quiet["tree_empty"], True)
			self.assertIs(quiet["direct_reaped"], True)
			self.assertIs(quiet["cancelled"], False)

	def test_repeated_leases_do_not_leak_parent_file_descriptors(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-posix-watchdog-fds-") as temporary:
			root = Path(temporary)
			service_script = root / "service.py"
			_write_script(service_script, _SIMPLE_SERVICE)
			fds_before = _fd_snapshot()
			retained_leases: list[object] = []
			retained_slots: list[object] = []
			for index in range(8):
				state_path = root / f"service-state-{index}.json"
				lease = None
				close_attempted = False
				try:
					slot, lease = self._start_service(
						[
							str(Path(sys.executable).resolve()),
							str(service_script),
							str(state_path),
						],
						cwd=root,
						lifetime_seconds=8.0,
					)
					_wait_for_json(
						state_path,
						timeout_seconds=2.0,
					)
					close_attempted = True
					result = lease.cancel_and_close(deadline=lease.deadline)
					self.assertTrue(result.process_boundary_quiescent)
					retained_slots.append(slot)
					retained_leases.append(lease)
				finally:
					if not close_attempted:
						self._best_effort_close(lease)
			fds_after = _fd_snapshot()
			self.assertEqual(fds_after, fds_before)
			self.assertEqual(len(retained_slots), 8)
			self.assertEqual(len(retained_leases), 8)


if __name__ == "__main__":
	unittest.main()
