#!/usr/bin/env python3
"""POSIX process-tree watchdog for invocation-owned long-lived services.

The watchdog is intentionally a separate session and the direct parent of the
service.  Parent-pipe EOF, an authenticated CANCEL message, or the immutable
monotonic deadline all enter the same kill-group/reap/confirm state machine.
"""

from __future__ import annotations

import argparse
import ctypes
import errno
import json
import os
from pathlib import Path
import re
import selectors
import signal
import sys
import time
from typing import Any


PROTOCOL_VERSION = 1
MAX_CONFIG_BYTES = 1024 * 1024
MAX_CONTROL_BYTES = 4096
MAX_STATUS_BYTES = 64 * 1024
CLEANUP_DEBT_NOTICE_NS = 10_000_000_000
PROC_SCAN_MAX_ENTRIES = 131072
PROC_STAT_MAX_BYTES = 4096
PROC_SUPER_MAGIC = 0x9FA0
_NONCE_PATTERN = re.compile(r"[0-9a-f]{64}\Z")
_TERMINAL_STATES = frozenset(("Z", "X", "x"))
_signal_requested = False


def _request_stop(_signum: int, _frame: Any) -> None:
	global _signal_requested
	_signal_requested = True


def _parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(add_help=False)
	parser.add_argument("--control-fd", required=True, type=int)
	parser.add_argument("--status-fd", required=True, type=int)
	parser.add_argument("--deadline-ns", required=True, type=int)
	parser.add_argument("--nonce", required=True)
	return parser.parse_args()


def _read_initial_config(
	control_fd: int,
	bootstrap_deadline_ns: int,
) -> tuple[dict[str, Any], bytearray]:
	"""Read exactly one bounded CONFIG frame while retaining later control bytes."""
	buffer = bytearray()
	os.set_blocking(control_fd, False)
	while True:
		remaining_ns = bootstrap_deadline_ns - time.monotonic_ns()
		if remaining_ns <= 0:
			raise TimeoutError("watchdog CONFIG publication exceeded its deadline")
		selector = selectors.DefaultSelector()
		try:
			selector.register(control_fd, selectors.EVENT_READ)
			if not selector.select(min(0.05, remaining_ns / 1_000_000_000)):
				continue
		finally:
			selector.close()
		try:
			chunk = os.read(control_fd, 4096)
		except BlockingIOError:
			continue
		if not chunk:
			raise EOFError("watchdog parent closed before CONFIG publication")
		buffer.extend(chunk)
		if len(buffer) > MAX_CONFIG_BYTES:
			raise ValueError("watchdog CONFIG frame exceeded its byte limit")
		line_end = buffer.find(b"\n")
		if line_end >= 0:
			break
	payload = bytes(buffer[:line_end])
	del buffer[:line_end + 1]
	value = json.loads(payload.decode("utf-8"))
	if not isinstance(value, dict):
		raise ValueError("watchdog config must be an object")
	return value, buffer


def _validated_config(
	value: dict[str, Any],
) -> tuple[str, int, str, list[str], dict[str, str]]:
	if set(value) != {
		"version", "nonce", "type", "deadline_ns", "cwd", "command",
		"environment",
	}:
		raise ValueError("watchdog config fields were not exact")
	version = value["version"]
	nonce = value["nonce"]
	message_type = value["type"]
	deadline_ns = value["deadline_ns"]
	cwd_value = value["cwd"]
	command_value = value["command"]
	environment_value = value["environment"]
	if version != PROTOCOL_VERSION or message_type != "CONFIG":
		raise ValueError("watchdog protocol version mismatch")
	if not isinstance(nonce, str) or _NONCE_PATTERN.fullmatch(nonce) is None:
		raise ValueError("watchdog nonce was invalid")
	if isinstance(deadline_ns, bool) or not isinstance(deadline_ns, int) or deadline_ns <= 0:
		raise ValueError("watchdog deadline was invalid")
	if not isinstance(cwd_value, str) or not os.path.isabs(cwd_value):
		raise ValueError("watchdog cwd must be absolute")
	if (
		not isinstance(command_value, list)
		or not command_value
		or any(not isinstance(item, str) or "\x00" in item for item in command_value)
	):
		raise ValueError("watchdog command was invalid")
	if not os.path.isabs(command_value[0]):
		raise ValueError("watchdog executable must be absolute")
	if not isinstance(environment_value, dict) or any(
		not isinstance(key, str)
		or not isinstance(item, str)
		or not key
		or "=" in key
		or "\x00" in key
		or "\x00" in item
		for key, item in environment_value.items()
	):
		raise ValueError("watchdog environment snapshot was invalid")
	return (
		nonce,
		deadline_ns,
		cwd_value,
		list(command_value),
		dict(environment_value),
	)


def _write_status(status_fd: int, payload: dict[str, Any]) -> None:
	encoded = json.dumps(payload, ensure_ascii=True, separators=(",", ":")).encode("ascii") + b"\n"
	if len(encoded) > MAX_STATUS_BYTES:
		raise ValueError("watchdog status exceeded its byte limit")
	view = memoryview(encoded)
	while view:
		written = os.write(status_fd, view)
		if written <= 0:
			raise BrokenPipeError("watchdog status pipe closed")
		view = view[written:]


def _close_fd(fd: int) -> None:
	try:
		os.close(fd)
	except OSError:
		pass


def _spawn_service(
	command: list[str],
	*,
	cwd: str,
	environment: dict[str, str],
	control_fd: int,
	status_fd: int,
	ownership_guard: list[int],
	deadline_ns: int,
) -> int:
	error_read_fd, error_write_fd = os.pipe2(os.O_CLOEXEC | os.O_NONBLOCK)
	guard_read_fd, guard_write_fd = os.pipe2(os.O_CLOEXEC)
	identity_read_fd, identity_write_fd = os.pipe2(os.O_CLOEXEC)
	os.set_blocking(identity_read_fd, False)
	service_pid = 0
	ownership_guard[0] = -1
	try:
		service_pid = os.fork()
	except BaseException:
		# If fork returned in the parent but asynchronous control flow interrupted
		# its STORE_FAST, closing the only guard writer makes the not-yet-execed
		# service child exit instead of becoming an orphan.
		_close_fd(guard_write_fd)
		_close_fd(guard_read_fd)
		_close_fd(error_write_fd)
		_close_fd(error_read_fd)
		_close_fd(identity_write_fd)
		try:
			identity_payload = _read_child_identity(identity_read_fd, deadline_ns)
			recovered_pid = int(identity_payload.decode("ascii").strip())
			if recovered_pid > 0:
				ownership_guard[0] = recovered_pid
		except BaseException:
			pass
		_close_fd(identity_read_fd)
		raise
	if service_pid == 0:
		try:
			_close_fd(identity_read_fd)
			os.write(identity_write_fd, f"{os.getpid()}\n".encode("ascii"))
			_close_fd(identity_write_fd)
			_close_fd(guard_write_fd)
			guard_byte = os.read(guard_read_fd, 1)
			_close_fd(guard_read_fd)
			if guard_byte != b"G":
				raise RuntimeError("watchdog ownership guard was not committed")
			_close_fd(error_read_fd)
			_close_fd(control_fd)
			_close_fd(status_fd)
			os.setsid()
			for signal_name in (
				"SIGPIPE", "SIGXFZ", "SIGXFSZ", "SIGTERM", "SIGINT", "SIGHUP",
				"SIGCHLD",
			):
				requested_signal = getattr(signal, signal_name, None)
				if requested_signal is not None:
					signal.signal(requested_signal, signal.SIG_DFL)
			pthread_sigmask = getattr(signal, "pthread_sigmask", None)
			if callable(pthread_sigmask):
				pthread_sigmask(signal.SIG_SETMASK, [])
			devnull_fd = os.open(os.devnull, os.O_RDWR)
			try:
				for target_fd in (0, 1, 2):
					os.dup2(devnull_fd, target_fd)
			finally:
				if devnull_fd > 2:
					_close_fd(devnull_fd)
			os.chdir(cwd)
			os.execve(command[0], command, environment)
		except BaseException as error:
			try:
				detail = f"{type(error).__name__}:{getattr(error, 'errno', 0)}".encode("ascii", "replace")
				os.write(error_write_fd, detail[:1024])
			except BaseException:
				pass
		finally:
			os._exit(127)
	try:
		_close_fd(identity_write_fd)
		identity_payload = _read_child_identity(identity_read_fd, deadline_ns)
		_close_fd(identity_read_fd)
		if int(identity_payload.decode("ascii").strip()) != service_pid:
			raise RuntimeError("watchdog service identity handshake failed")
		# This publication precedes every other fallible parent-side operation.
		ownership_guard[0] = service_pid
		_close_fd(guard_read_fd)
		_close_fd(error_write_fd)
		os.write(guard_write_fd, b"G")
	except BaseException:
		if service_pid > 0:
			ownership_guard[0] = service_pid
		_close_fd(identity_read_fd)
		_close_fd(identity_write_fd)
		_close_fd(error_write_fd)
		raise
	finally:
		_close_fd(guard_write_fd)
	return error_read_fd


def _read_child_identity(identity_fd: int, deadline_ns: int) -> bytes:
	buffer = bytearray()
	selector = selectors.DefaultSelector()
	try:
		selector.register(identity_fd, selectors.EVENT_READ)
		while True:
			remaining_ns = deadline_ns - time.monotonic_ns()
			if remaining_ns <= 0:
				raise TimeoutError("watchdog child identity exceeded its deadline")
			if not selector.select(min(0.05, remaining_ns / 1_000_000_000)):
				continue
			try:
				chunk = os.read(identity_fd, 32 - len(buffer))
			except BlockingIOError:
				continue
			if not chunk:
				raise EOFError("watchdog child identity closed before publication")
			buffer.extend(chunk)
			if len(buffer) > 31:
				raise ValueError("watchdog child identity exceeded its byte limit")
			if b"\n" in buffer:
				line, separator, trailing = bytes(buffer).partition(b"\n")
				if not separator or trailing:
					raise ValueError("watchdog child identity frame was malformed")
				return line
	finally:
		selector.close()


def _settle_unknown_service_child() -> bool:
	"""Reap the helper's only possible child without ever signalling a raw id."""
	reap_inflight = False
	while True:
		if reap_inflight:
			# waitpid may already have consumed the only identity. Fail closed and
			# retain this helper forever rather than publish a false no-child proof.
			time.sleep(0.05)
			continue
		reap_inflight = True
		try:
			waited_pid, _wait_status = os.waitpid(-1, 0)
		except ChildProcessError:
			return True
		except BaseException:
			continue
		if waited_pid > 0:
			return True


def _read_control_messages(buffer: bytearray, chunk: bytes, nonce: str) -> bool:
	buffer.extend(chunk)
	if len(buffer) > MAX_CONTROL_BYTES:
		raise ValueError("watchdog control message exceeded its byte limit")
	cancelled = False
	while True:
		line_end = buffer.find(b"\n")
		if line_end < 0:
			break
		line = bytes(buffer[:line_end])
		del buffer[:line_end + 1]
		message = json.loads(line.decode("ascii"))
		if (
			not isinstance(message, dict)
			or set(message) != {"version", "nonce", "type"}
			or message["version"] != PROTOCOL_VERSION
			or message["nonce"] != nonce
			or message["type"] != "CANCEL"
		):
			raise ValueError("watchdog control message failed authentication")
		cancelled = True
	return cancelled


def _direct_exit_observed(service_pid: int) -> bool:
	try:
		status = os.waitid(
			os.P_PID,
			service_pid,
			os.WEXITED | os.WNOHANG | os.WNOWAIT,
		)
	except ChildProcessError:
		# ECHILD is not a reap proof. The PID/PGID authority may already have
		# been released, so callers must stop signalling and fail closed.
		raise
	except BaseException:
		# Unknown is live for cleanup purposes. The persistent loop will retry.
		return False
	return status is not None and int(getattr(status, "si_pid", 0)) == service_pid


def _process_group_state(process_group_id: int) -> tuple[bool, bool]:
	"""Return (group_found, live_member_found) without signalling a reused PGID."""
	proc_root = Path("/proc")
	if not proc_root.is_dir():
		try:
			os.killpg(process_group_id, 0)
		except ProcessLookupError:
			return False, False
		except OSError:
			return True, True
		return True, True
	group_found = False
	entry_count = 0
	try:
		with os.scandir(proc_root) as entries:
			for entry in entries:
				if not entry.name.isdecimal():
					continue
				entry_count += 1
				if entry_count > PROC_SCAN_MAX_ENTRIES:
					return True, True
				try:
					with open(Path(entry.path) / "stat", "rb") as stream:
						payload = stream.read(PROC_STAT_MAX_BYTES + 1)
				except FileNotFoundError:
					continue
				except BaseException:
					return True, True
				if len(payload) > PROC_STAT_MAX_BYTES:
					return True, True
				_prefix, separator, suffix = payload.rpartition(b")")
				fields = suffix.split()
				if not separator or len(fields) < 3:
					return True, True
				try:
					state = fields[0].decode("ascii")
					member_group = int(fields[2])
				except (UnicodeDecodeError, ValueError):
					return True, True
				if member_group != process_group_id:
					continue
				group_found = True
				if state not in _TERMINAL_STATES:
					return True, True
	except BaseException:
		return True, True
	return group_found, False


def _preflight_procfs_visibility(deadline_ns: int) -> None:
	"""Require one full, bounded, parseable Linux process-table snapshot."""
	proc_root = Path("/proc")
	if not proc_root.is_dir():
		raise RuntimeError("watchdog requires a mounted Linux /proc")
	statfs_buffer = ctypes.create_string_buffer(256)
	libc = ctypes.CDLL(None, use_errno=True)
	if libc.statfs(os.fsencode(proc_root), ctypes.byref(statfs_buffer)) != 0:
		raise OSError(ctypes.get_errno(), "watchdog procfs statfs failed")
	filesystem_type = ctypes.c_long.from_buffer(statfs_buffer).value
	if filesystem_type != PROC_SUPER_MAGIC:
		raise RuntimeError("watchdog /proc path was not a real procfs mount")
	entry_count = 0
	self_pid = os.getpid()
	self_observed = False
	try:
		with os.scandir(proc_root) as entries:
			for entry in entries:
				if not entry.name.isdecimal():
					continue
				if time.monotonic_ns() >= deadline_ns:
					raise TimeoutError("watchdog procfs preflight exceeded its deadline")
				entry_count += 1
				if int(entry.name) == self_pid:
					self_observed = True
				if entry_count > PROC_SCAN_MAX_ENTRIES:
					raise RuntimeError("watchdog procfs preflight exceeded its entry budget")
				try:
					with open(Path(entry.path) / "stat", "rb") as stream:
						payload = stream.read(PROC_STAT_MAX_BYTES + 1)
				except FileNotFoundError:
					# Concurrent exit is not a visibility failure.
					continue
				if len(payload) > PROC_STAT_MAX_BYTES:
					raise RuntimeError("watchdog procfs stat exceeded its byte budget")
				prefix, separator, suffix = payload.rpartition(b")")
				fields = suffix.split()
				if not separator or len(fields) < 4:
					raise RuntimeError("watchdog procfs stat was malformed")
				try:
					stat_pid = int(prefix.split(b" ", 1)[0])
					state = fields[0].decode("ascii")
					process_group = int(fields[2])
					session_id = int(fields[3])
				except (UnicodeDecodeError, ValueError) as error:
					raise RuntimeError(
						"watchdog procfs stat identity was malformed"
					) from error
				if not state:
					raise RuntimeError("watchdog procfs process state was empty")
				if stat_pid != int(entry.name):
					raise RuntimeError("watchdog procfs pid identity was inconsistent")
				if int(entry.name) == self_pid and (
					process_group != os.getpgrp() or session_id != os.getsid(0)
				):
					raise RuntimeError("watchdog procfs self identity was inconsistent")
	except FileNotFoundError as error:
		raise RuntimeError("watchdog procfs disappeared during preflight") from error
	if not self_observed:
		raise RuntimeError("watchdog procfs snapshot did not include the helper")


def _terminate_and_reap(
	service_pid: int,
	*,
	status_fd: int,
	nonce: str,
	trigger: str,
	terminal_guard: dict[str, Any],
) -> tuple[int, bool, bool]:
	"""Persistently kill, reap, and prove the owned group empty.

	The direct child remains waitable until the group proof is complete.  A
	one-shot signal is not sufficient evidence: a transient signal failure must
	not turn the watchdog into a permanent live-group polling loop.
	"""
	if terminal_guard.get("reaped") is True:
		return (
			int(terminal_guard.get("return_code", 127)),
			True,
			bool(terminal_guard.get("termination_cancelled", False)),
		)
	authority_lost = False
	reap_uncertain = bool(terminal_guard.get("reap_inflight"))
	try:
		direct_running_before_termination = not _direct_exit_observed(service_pid)
	except ChildProcessError:
		direct_running_before_termination = False
		authority_lost = True
	signal_delivered = False

	def safe_now_ns() -> int:
		try:
			return time.monotonic_ns()
		except BaseException:
			return 0

	def safe_pause() -> None:
		try:
			time.sleep(0.01)
		except BaseException:
			pass

	def signal_owned_group() -> None:
		nonlocal signal_delivered
		try:
			os.killpg(service_pid, signal.SIGKILL)
			signal_delivered = True
			return
		except ProcessLookupError:
			pass
		except BaseException:
			pass
		try:
			os.kill(service_pid, signal.SIGKILL)
			signal_delivered = True
		except BaseException:
			pass

	debt_notice_at = safe_now_ns() + CLEANUP_DEBT_NOTICE_NS
	debt_reported = False
	while True:
		now_ns = safe_now_ns()
		if not authority_lost and not reap_uncertain:
			signal_owned_group()
		if reap_uncertain:
			# waitpid may have consumed the kernel identity before Python could
			# publish its return value. Never touch the raw PID/PGID again.
			direct_exited = False
			live_member_found = True
		else:
			try:
				direct_exited = _direct_exit_observed(service_pid)
			except ChildProcessError:
				authority_lost = True
				direct_exited = False
			except BaseException:
				direct_exited = False
			try:
				_group_found, live_member_found = _process_group_state(service_pid)
			except BaseException:
				live_member_found = True
		if direct_exited and not live_member_found and not authority_lost:
			try:
				terminal_guard["reap_inflight"] = True
				wait_result = os.waitpid(service_pid, 0)
				# First post-syscall publication: once this is true no exception
				# path may ever signal or scan the released raw identity again.
				terminal_guard["reaped"] = True
			except ChildProcessError:
				authority_lost = True
			except BaseException:
				# The syscall may have succeeded before CALL returned to STORE_FAST.
				# Retain a fail-closed helper forever, but never signal a reusable id.
				reap_uncertain = True
			else:
				try:
					_reaped_pid, wait_status = wait_result
					return_code = os.waitstatus_to_exitcode(wait_status)
				except BaseException:
					return_code = 127
				try:
					termination_cancelled = (
						direct_running_before_termination and signal_delivered
					)
					terminal_guard["return_code"] = return_code
					terminal_guard["termination_cancelled"] = termination_cancelled
				except BaseException:
					if terminal_guard.get("reaped") is not True:
						reap_uncertain = True
						continue
				return (
					int(terminal_guard.get("return_code", 127)),
					True,
					bool(terminal_guard.get("termination_cancelled", False)),
				)
		if not debt_reported and now_ns >= debt_notice_at:
			try:
				_write_status(status_fd, {
					"version": PROTOCOL_VERSION,
					"nonce": nonce,
					"type": "DEBT",
					"helper_pid": os.getpid(),
					"server_pid": service_pid,
					"process_group_id": service_pid,
					"child_created": True,
					"trigger": trigger,
				})
			except OSError:
				pass
			debt_reported = True
		safe_pause()


def main() -> int:
	args = _parse_args()
	control_fd = args.control_fd
	status_fd = args.status_fd
	service_pid = 0
	service_ownership_guard = [0]
	exec_error_fd = -1
	nonce = args.nonce
	trigger = ""
	ready = False
	return_code = 127
	tree_empty = True
	cancelled = False
	primary_error: BaseException | None = None
	service_terminal_guard: dict[str, Any] = {}
	for requested_signal in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
		signal.signal(requested_signal, _request_stop)
	try:
		if args.deadline_ns <= 0:
			raise ValueError("watchdog bootstrap deadline was invalid")
		if _NONCE_PATTERN.fullmatch(nonce) is None:
			raise ValueError("watchdog bootstrap nonce was invalid")
		config, control_buffer = _read_initial_config(control_fd, args.deadline_ns)
		config_nonce, deadline_ns, cwd, command, environment = _validated_config(config)
		if config_nonce != nonce:
			raise ValueError("watchdog CONFIG nonce did not match bootstrap nonce")
		if deadline_ns != args.deadline_ns:
			raise ValueError("watchdog CONFIG deadline did not match bootstrap deadline")
		if time.monotonic_ns() >= deadline_ns:
			raise TimeoutError("watchdog deadline expired before service spawn")
		_preflight_procfs_visibility(deadline_ns)
		# SIG_IGN/SA_NOCLDWAIT survives exec on POSIX. Restore a waitable child
		# contract before fork so ECHILD can never be mistaken for our reap proof.
		signal.signal(signal.SIGCHLD, signal.SIG_DFL)
		os.set_blocking(control_fd, False)
		exec_error_fd = _spawn_service(
			command,
			cwd=cwd,
			environment=environment,
			control_fd=control_fd,
			status_fd=status_fd,
			ownership_guard=service_ownership_guard,
			deadline_ns=deadline_ns,
		)
		service_pid = service_ownership_guard[0]
		try:
			selector = selectors.DefaultSelector()
			selector.register(control_fd, selectors.EVENT_READ, "control")
			selector.register(exec_error_fd, selectors.EVENT_READ, "exec")
			exec_error = bytearray()
			if control_buffer and _read_control_messages(control_buffer, b"", nonce):
				trigger = "cancel"
			while not trigger:
				if _signal_requested:
					trigger = "signal"
					break
				if time.monotonic_ns() >= deadline_ns:
					trigger = "deadline"
					break
				if _direct_exit_observed(service_pid):
					trigger = "early_exit"
					break
				timeout = min(
					0.05,
					max(
						0.0,
						(deadline_ns - time.monotonic_ns()) / 1_000_000_000,
					),
				)
				for key, _mask in selector.select(timeout):
					if key.data == "control":
						chunk = os.read(control_fd, 4096)
						if not chunk:
							trigger = "parent_eof"
							break
						if _read_control_messages(control_buffer, chunk, nonce):
							trigger = (
								"early_exit"
								if _direct_exit_observed(service_pid)
								else "cancel"
							)
							break
					else:
						chunk = os.read(exec_error_fd, 4096)
						if chunk:
							exec_error.extend(chunk)
							if len(exec_error) > 4096:
								trigger = "exec_failure"
								break
						else:
							selector.unregister(exec_error_fd)
							_close_fd(exec_error_fd)
							exec_error_fd = -1
							if exec_error:
								trigger = "exec_failure"
								break
							ready = True
							try:
								_write_status(status_fd, {
									"version": PROTOCOL_VERSION,
									"nonce": nonce,
									"type": "READY",
									"helper_pid": os.getpid(),
									"server_pid": service_pid,
									"process_group_id": service_pid,
								})
							except BaseException as error:
								# Once READY cannot be observed, keeping the service alive
								# would leave the parent with no authenticated authority
								# evidence. Enter the same persistent cleanup path now;
								# terminal status publication may also fail, but tree cleanup
								# remains independent of the status channel.
								primary_error = error
								trigger = "status_error"
								break
		except BaseException as error:
			primary_error = error
			trigger = "watchdog_error"
	except BaseException as error:
		primary_error = error
		trigger = "startup_error"
	finally:
		if exec_error_fd >= 0:
			_close_fd(exec_error_fd)
		service_pid = service_ownership_guard[0]
		if service_pid < 0:
			if _settle_unknown_service_child():
				service_ownership_guard[0] = 0
				service_pid = 0
		if service_pid > 0:
			while True:
				try:
					return_code, tree_empty, termination_cancelled = _terminate_and_reap(
						service_pid,
						status_fd=status_fd,
						nonce=nonce,
						trigger=trigger or "watchdog_error",
						terminal_guard=service_terminal_guard,
					)
					break
				except BaseException:
					# A hostile checkpoint must not bypass the only cleanup authority.
					continue
			cancelled = trigger == "cancel" and termination_cancelled
			try:
				_write_status(status_fd, {
					"version": PROTOCOL_VERSION,
					"nonce": nonce,
					"type": "QUIET" if tree_empty else "DEBT",
					"helper_pid": os.getpid(),
					"server_pid": service_pid,
					"process_group_id": service_pid,
					"return_code": return_code,
					"trigger": trigger or "watchdog_error",
					"ready": ready,
					"child_created": True,
					"tree_empty": tree_empty,
					"direct_reaped": True,
					"cancelled": cancelled,
					"error_type": (
						type(primary_error).__name__ if primary_error is not None else ""
					),
				})
			except BaseException:
				pass
		elif service_pid == 0 and primary_error is not None:
			try:
				_write_status(status_fd, {
					"version": PROTOCOL_VERSION,
					"nonce": nonce,
					"type": "QUIET",
					"helper_pid": os.getpid(),
					"server_pid": 0,
					"process_group_id": 0,
					"return_code": 127,
					"trigger": trigger or "startup_error",
					"ready": False,
					"child_created": False,
					"tree_empty": True,
					"direct_reaped": False,
					"cancelled": False,
					"error_type": type(primary_error).__name__,
				})
			except BaseException:
				pass
		_close_fd(control_fd)
		_close_fd(status_fd)
	if service_pid > 0:
		return 0 if tree_empty else 3
	return 2


if __name__ == "__main__":
	raise SystemExit(main())
