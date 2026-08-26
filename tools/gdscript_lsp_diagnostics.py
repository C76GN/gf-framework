#!/usr/bin/env python3
"""Collect Godot GDScript diagnostics through the editor Language Server.

This complements headless editor reload-log checks. Godot can surface some
GDScript warnings through the editor diagnostics pipeline without reliably
printing them in GUT or short --editor --quit runs.
"""

from __future__ import annotations

import argparse
import json
import math
import os
import pathlib
import re
import socket
import sys
import tempfile
import threading
import time
import urllib.parse
from dataclasses import dataclass
from typing import Any
from typing import Callable

from gf_godot_process import resolve_godot_executable
from gf_maintenance_rendering import encode_strict_json
from gf_maintenance_rendering import write_json_object_atomic
import gf_process_supervisor


DEFAULT_SCAN_ROOTS = ("addons/gf", "tests/gf_core")
DEFAULT_EXCLUDED_PARTS = {
	".git",
	".godot",
	".gf",
	".import",
	"__pycache__",
	"ai_analysis",
	"build",
	"site",
}
DEFAULT_EXCLUDED_PREFIXES = ("addons/gut",)
DEFAULT_FAIL_SEVERITIES = ("error", "warning")
SEVERITY_NAMES = {
	1: "error",
	2: "warning",
	3: "information",
	4: "hint",
}
WARNING_CODE_PATTERN = re.compile(r"^\(([^)]+)\):\s*(.*)$")
WORKSPACE_PROBE_CLASS = "GFVariantData"
MAX_LSP_HEADER_BYTES = 16 * 1024
MAX_LSP_BODY_BYTES = 16 * 1024 * 1024
LSP_RECEIVE_CHUNK_BYTES = 4096
LINUX_TCP_OWNER_TABLE_MAX_BYTES = 8 * 1024 * 1024
LINUX_TCP_OWNER_MAX_PID_ENTRIES = 131072
LINUX_TCP_OWNER_MAX_FD_ENTRIES = 1048576
WINDOWS_TCP_OWNER_TABLE_MAX_BYTES = 8 * 1024 * 1024
WINDOWS_TCP_OWNER_MAX_ENTRIES = 131072
WINDOWS_TCP_OWNER_QUERY_RETRIES = 3
WINDOWS_TCP_OWNER_WAIT_SLICE_SECONDS = 0.01
WINDOWS_TCP_OWNER_ROW_CHECKPOINT_INTERVAL = 256


class LspProtocolError(RuntimeError):
	"""The peer sent an invalid, truncated, or deadline-exhausted LSP frame."""


class TcpOwnerLookupError(RuntimeError):
	"""The kernel TCP snapshot did not yet expose one unambiguous owner."""


class LspOperationCleanupError(RuntimeError):
	"""Preserve both the scan failure and an owned-process cleanup failure."""

	def __init__(self, operation_error: BaseException, cleanup_error: BaseException) -> None:
		gf_process_supervisor.add_exception_note(
			operation_error,
			"Invocation-owned Godot LSP cleanup also failed: "
			f"{gf_process_supervisor.safe_exception_detail(cleanup_error)}",
		)
		super().__init__(
			"Godot LSP operation failed before cleanup, and process cleanup also failed: "
			f"operation={type(operation_error).__name__}: "
			f"{gf_process_supervisor.safe_exception_detail(operation_error)}; "
			f"cleanup={type(cleanup_error).__name__}: "
			f"{gf_process_supervisor.safe_exception_detail(cleanup_error)}"
		)
		self.operation_error = operation_error
		self.cleanup_error = cleanup_error
		self.cleanup_debt = (
			gf_process_supervisor.exception_has_cleanup_debt(operation_error)
			or gf_process_supervisor.exception_has_cleanup_debt(cleanup_error)
		)
		self.process_boundary_quiescent = not self.cleanup_debt


@dataclass(frozen=True)
class JsonRpcMessage:
	payload: dict[str, Any]


class _OwnedLspProcess:
	"""Run one invocation-owned Godot LSP tree behind the TCP client."""

	def __init__(
		self,
		command: list[str],
		*,
		cwd: pathlib.Path,
		environment: dict[str, str],
		timeout_seconds: float,
	) -> None:
		self.command = tuple(command)
		self.cwd = cwd
		self.environment = dict(environment)
		self.timeout_seconds = timeout_seconds
		self._lease_slot = (
			gf_process_supervisor.SupervisedProcessLeasePublicationSlot()
		)
		self._start_lock = threading.Lock()
		self._start_state = "new"

	def start(self) -> None:
		with self._start_lock:
			if self._start_state != "new":
				raise RuntimeError("Godot LSP process supervision was started more than once.")
			self._start_state = "starting"
		deadline = time.perf_counter() + self.timeout_seconds
		try:
			gf_process_supervisor.start_supervised_process_lease(
				list(self.command),
				cwd=self.cwd,
				deadline=deadline,
				environment=dict(self.environment),
				publication_slot=self._lease_slot,
			)
			gf_process_supervisor._process_supervision_checkpoint(
				"lsp_owned_process_after_lease_api_return"
			)
		except BaseException:
			with self._start_lock:
				self._start_state = "published" if self._lease_slot.has_lease else "failed"
			raise
		with self._start_lock:
			self._start_state = "published"

	@property
	def has_lease(self) -> bool:
		return self._lease_slot.has_lease

	@property
	def operation_deadline(self) -> float:
		return self._lease_or_raise().operation_deadline

	def is_finished(self) -> bool:
		lease = self._lease_or_raise()
		try:
			lease.poll_operation_health()
		except RuntimeError:
			return True
		except TimeoutError:
			return True
		return False

	def wait_started_pid(self, timeout_seconds: float) -> int:
		_ = timeout_seconds
		lease = self._lease_or_raise()
		lease.poll_operation_health()
		started_pid = lease.pid
		if started_pid <= 0:
			raise RuntimeError("Invocation-owned Godot LSP published an invalid PID.")
		return started_pid

	def raise_if_finished(self) -> None:
		try:
			self._lease_or_raise().poll_operation_health()
		except TimeoutError:
			raise
		except Exception as error:
			raise RuntimeError(
				"Invocation-owned Godot LSP became unavailable before the diagnostics "
				"session completed."
			) from error

	def stop(self) -> gf_process_supervisor.SupervisedProcessResult:
		lease = self._lease_or_raise()
		result = lease.cancel_and_close(deadline=lease.deadline)
		issues: list[str] = []
		if not result.cancelled:
			issues.append("the owned server did not acknowledge local cancellation")
		if result.timed_out:
			issues.append("the owned server reached its lifetime deadline")
		if not result.process_boundary_quiescent:
			issues.append("the owned server process tree was not proven quiescent")
		if result.stdout_truncated or result.stderr_truncated:
			issues.append("the owned server process output was truncated")
		if issues:
			error = RuntimeError(
				"Godot LSP supervision failed closed: " + "; ".join(issues) + "."
			)
			error.cleanup_debt = False  # type: ignore[attr-defined]
			error.process_boundary_quiescent = True  # type: ignore[attr-defined]
			raise error
		return result

	def _lease_or_raise(self) -> gf_process_supervisor.SupervisedProcessLease:
		return self._lease_slot.get()


class _LspOperationBoundary:
	"""Clamp every protocol wait to one owned lease operation deadline."""

	def __init__(self, owned_process: _OwnedLspProcess | None = None) -> None:
		self._owned_process = owned_process

	@property
	def deadline(self) -> float | None:
		if self._owned_process is None:
			return None
		return self._owned_process.operation_deadline

	def checkpoint(self) -> None:
		if self._owned_process is not None:
			self._owned_process.raise_if_finished()
		deadline = self.deadline
		if deadline is not None and time.perf_counter() >= deadline:
			raise TimeoutError(
				"Godot LSP operation deadline was exhausted; the remaining lease "
				"lifetime is reserved for process cleanup."
			)

	def clamp_deadline(self, deadline: float) -> float:
		self.checkpoint()
		operation_deadline = self.deadline
		if operation_deadline is None:
			return deadline
		return min(deadline, operation_deadline)

	def deadline_after(self, timeout_seconds: float) -> float:
		return self.clamp_deadline(
			time.perf_counter() + max(0.0, timeout_seconds)
		)

	def remaining(self, deadline: float, maximum_seconds: float | None = None) -> float:
		self.checkpoint()
		remaining = max(0.0, self.clamp_deadline(deadline) - time.perf_counter())
		if maximum_seconds is not None:
			remaining = min(remaining, max(0.0, maximum_seconds))
		return remaining


class LspClient:
	def __init__(self, host: str, port: int) -> None:
		self._initialize_connection(socket.create_connection((host, port), timeout=5.0))

	@classmethod
	def from_connected_socket(cls, connection: socket.socket) -> LspClient:
		client = cls.__new__(cls)
		client._initialize_connection(connection)
		return client

	def _initialize_connection(self, connection: socket.socket) -> None:
		self._socket = connection
		self._next_id = 1
		self._receive_buffer = bytearray()

	def close(self) -> None:
		try:
			self._socket.close()
		except OSError:
			pass

	def request(
		self,
		method: str,
		params: dict[str, Any],
		*,
		deadline: float,
		boundary: _LspOperationBoundary,
	) -> int:
		request_id = self._next_id
		self._next_id += 1
		self.send({
			"jsonrpc": "2.0",
			"id": request_id,
			"method": method,
			"params": params,
		}, deadline=deadline, boundary=boundary)
		return request_id

	def notify(
		self,
		method: str,
		params: dict[str, Any],
		*,
		deadline: float,
		boundary: _LspOperationBoundary,
	) -> None:
		self.send({
			"jsonrpc": "2.0",
			"method": method,
			"params": params,
		}, deadline=deadline, boundary=boundary)

	def send(
		self,
		payload: dict[str, Any],
		*,
		deadline: float,
		boundary: _LspOperationBoundary,
	) -> None:
		boundary.checkpoint()
		deadline = boundary.clamp_deadline(deadline)
		data = encode_strict_json(payload).encode("utf-8")
		header = f"Content-Length: {len(data)}\r\n\r\n".encode("ascii")
		boundary.checkpoint()
		remaining = deadline - time.perf_counter()
		if remaining <= 0.0:
			raise TimeoutError("LSP send deadline was exhausted before socket write.")
		self._socket.settimeout(remaining)
		try:
			self._socket.sendall(header + data)
		except socket.timeout as error:
			raise TimeoutError("LSP socket write exceeded its absolute deadline.") from error
		boundary.checkpoint()
		if time.perf_counter() > deadline:
			raise TimeoutError("LSP socket write exceeded its absolute deadline.")

	def receive(
		self,
		timeout: float,
		*,
		boundary: _LspOperationBoundary | None = None,
	) -> JsonRpcMessage | None:
		if boundary is None:
			boundary = _LspOperationBoundary()
		deadline = boundary.deadline_after(timeout)
		header_end = self._receive_buffer.find(b"\r\n\r\n")
		while header_end < 0:
			if len(self._receive_buffer) >= MAX_LSP_HEADER_BYTES:
				raise LspProtocolError("LSP header exceeds the configured byte limit.")
			if not self._receive_until(deadline, MAX_LSP_HEADER_BYTES, boundary):
				return None
			header_end = self._receive_buffer.find(b"\r\n\r\n")
		header_size = header_end + 4
		if header_size > MAX_LSP_HEADER_BYTES:
			raise LspProtocolError("LSP header exceeds the configured byte limit.")
		length = _parse_content_length(bytes(self._receive_buffer[:header_size]))
		frame_size = header_size + length
		while len(self._receive_buffer) < frame_size:
			self._receive_until(deadline, frame_size, boundary)
		body = bytes(self._receive_buffer[header_size:frame_size])
		del self._receive_buffer[:frame_size]
		try:
			text = body.decode("utf-8", errors="strict")
			payload = json.loads(
				text,
				object_pairs_hook=_reject_duplicate_json_object_keys,
				parse_constant=_reject_json_constant,
			)
		except (UnicodeDecodeError, json.JSONDecodeError, RecursionError, ValueError) as error:
			raise LspProtocolError(f"Invalid LSP JSON body: {error}") from error
		if not isinstance(payload, dict):
			raise LspProtocolError("LSP JSON-RPC body must be an object.")
		boundary.checkpoint()
		return JsonRpcMessage(payload)

	def _receive_until(
		self,
		deadline: float,
		maximum_buffer_size: int,
		boundary: _LspOperationBoundary,
	) -> bool:
		remaining = boundary.remaining(deadline)
		if remaining <= 0.0:
			if self._receive_buffer:
				raise LspProtocolError("LSP frame deadline exhausted after partial input.")
			return False
		self._socket.settimeout(remaining)
		try:
			chunk = self._socket.recv(
				min(LSP_RECEIVE_CHUNK_BYTES, maximum_buffer_size - len(self._receive_buffer))
			)
		except socket.timeout as error:
			if self._receive_buffer:
				raise LspProtocolError("LSP frame deadline exhausted after partial input.") from error
			return False
		except OSError as error:
			if self._receive_buffer:
				raise LspProtocolError("LSP connection failed after partial input.") from error
			return False
		if not chunk:
			if self._receive_buffer:
				raise LspProtocolError("LSP connection closed after partial input.")
			return False
		self._receive_buffer.extend(chunk)
		boundary.checkpoint()
		return True


def _iter_exception_cleanup_chain(
	errors: tuple[BaseException, ...],
) -> list[BaseException]:
	# Treat the caller tuple as an event sequence.  A LIFO traversal may still be
	# used for each exception chain, but seed it in reverse so the first top-level
	# error (and then its cause/context/original chain) is observed first.
	pending = list(reversed(errors))
	ordered: list[BaseException] = []
	seen: set[int] = set()
	while pending:
		error = pending.pop()
		if id(error) in seen:
			continue
		seen.add(id(error))
		ordered.append(error)
		try:
			attributes = BaseException.__getattribute__(error, "__dict__")
		except BaseException:
			attributes = {}
		try:
			cause = BaseException.__getattribute__(error, "__cause__")
			context = BaseException.__getattribute__(error, "__context__")
		except BaseException:
			cause = None
			context = None
		nested_errors = (
			cause,
			context,
			attributes.get("original_error") if isinstance(attributes, dict) else None,
		)
		for nested in reversed(nested_errors):
			if isinstance(nested, BaseException):
				pending.append(nested)
	return ordered


def _settle_deferred_cleanups_before_propagation(
	errors: tuple[BaseException, ...],
) -> None:
	"""Observe each distinct retained authority without swallowing control flow."""
	seen_handles: set[int] = set()
	pending_error: BaseException | None = None
	pending_traceback: Any = None
	pending_debt: BaseException | None = None
	for error in _iter_exception_cleanup_chain(errors):
		try:
			attributes = BaseException.__getattribute__(error, "__dict__")
			handle = (
				attributes.get("deferred_cleanup")
				if isinstance(attributes, dict)
				else None
			)
		except BaseException as inspection_error:
			gf_process_supervisor.add_exception_note(
				error,
				"Deferred cleanup authority could not be inspected before propagation: "
				f"{type(inspection_error).__name__}.",
			)
			continue
		if handle is None or id(handle) in seen_handles:
			continue
		seen_handles.add(id(handle))
		try:
			wait = getattr(handle, "wait")
			if not callable(wait):
				raise TypeError("deferred cleanup handle wait is not callable")
			completed = bool(
				wait(gf_process_supervisor.BINARY_PROCESS_DEFERRED_CLEANUP_SECONDS)
			)
		except BaseException as wait_error:
			gf_process_supervisor.add_exception_note(
				error,
				"Deferred cleanup observation before propagation failed: "
				f"{type(wait_error).__name__}: "
				f"{gf_process_supervisor.safe_exception_detail(wait_error)}.",
			)
			if not isinstance(wait_error, Exception):
				control_error = wait_error
				try:
					status = handle.snapshot()
				except BaseException as snapshot_error:
					status = gf_process_supervisor.SupervisedBinaryCleanupStatus(
						complete=False,
						cleanup_complete=False,
						owner_closed=False,
						process_tree_empty=False,
						pid=0,
						notes=(
							"Deferred cleanup status inspection failed after control flow: "
							f"{type(snapshot_error).__name__}.",
						),
					)
				status_is_quiet = gf_process_supervisor._binary_cleanup_status_is_quiet(
					status
				)
				selected, selected_traceback = (
					gf_process_supervisor._select_preferred_cleanup_error(
						pending_error,
						pending_traceback,
						control_error,
						context="LSP deferred cleanup observation",
					)
				)
				pending_error = selected
				pending_traceback = selected_traceback
				if not status_is_quiet:
					control_debt = gf_process_supervisor.SupervisedProcessCleanupError(
						"Deferred LSP cleanup retained debt after control flow.",
						notes=status.notes,
						original_error=control_error,
						pid=status.pid,
						owner_closed=status.owner_closed,
						process_tree_empty=status.process_tree_empty,
						cleanup_status=status,
						deferred_cleanup=handle,
					)
					if selected is control_error:
						pending_debt = control_debt
					elif pending_debt is None:
						pending_debt = control_debt
			elif gf_process_supervisor.exception_has_cleanup_debt(wait_error):
				selected, selected_traceback = (
					gf_process_supervisor._select_preferred_cleanup_error(
						pending_error,
						pending_traceback,
						wait_error,
						context="LSP deferred cleanup observation",
					)
				)
				if selected is wait_error:
					pending_error = selected
					pending_traceback = selected_traceback
				if pending_debt is None:
					pending_debt = wait_error
			continue
		if completed:
			gf_process_supervisor.add_exception_note(
				error,
				"Deferred process cleanup reached a terminal observation before the LSP "
				"tool propagated its original cleanup debt.",
			)
		else:
			gf_process_supervisor.add_exception_note(
				error,
				"Deferred process cleanup remained active under retained non-daemon "
				"authority after the bounded observation.",
			)
	if pending_debt is not None:
		if pending_error is not None and not isinstance(pending_error, Exception):
			if isinstance(
				pending_debt,
				gf_process_supervisor.SupervisedProcessCleanupError,
			):
				pending_debt.original_error = pending_error
			raise pending_debt from pending_error
		original = getattr(pending_debt, "original_error", None)
		if isinstance(original, BaseException):
			raise pending_debt from original
		raise pending_debt
	if pending_error is not None:
		raise pending_error.with_traceback(pending_traceback)


def main() -> int:
	args = _parse_args()
	if not math.isfinite(args.lsp_process_timeout) or args.lsp_process_timeout <= 0.0:
		return _print_tool_error("--lsp-process-timeout must be finite and positive.", None)
	if args.spawn_lsp and args.lsp_process_timeout <= args.startup_timeout:
		return _print_tool_error(
			"--lsp-process-timeout must exceed --startup-timeout for owned startup cleanup.",
			None,
		)
	if args.spawn_lsp and args.port != 0:
		return _print_tool_error(
			"--spawn-lsp requires --port 0 so the owned server always uses a dynamic port.",
			None,
		)
	project_root = pathlib.Path(args.project_root).resolve()
	process_environment = dict(os.environ)
	files = _collect_files(project_root, args)
	if not files:
		return _print_tool_error("No GDScript files matched the scan inputs.", None)

	temp_log_path: pathlib.Path | None = None
	process: _OwnedLspProcess | None = None
	process_result: gf_process_supervisor.SupervisedProcessResult | None = None
	started_pid = 0
	listener_pid = 0
	port = args.port
	configured_port = args.port
	spawned = False
	connection_fallback_reason = ""
	workspace_definition_uri = ""
	started_at = time.monotonic()
	report: dict[str, Any] | None = None
	operation_error: BaseException | None = None
	operation_traceback: Any = None
	operation_boundary = _LspOperationBoundary()

	try:
		client: LspClient | None = None
		client_initialized = False
		should_spawn_lsp = args.spawn_lsp
		if args.connect_or_spawn:
			should_spawn_lsp = True
			if port > 0 and _wait_for_port("127.0.0.1", port, min(args.startup_timeout, 1.0)):
				try:
					client = LspClient("127.0.0.1", port)
					_initialize_lsp(
						client,
						project_root,
						args.request_timeout,
						boundary=operation_boundary,
					)
					workspace_definition_uri = _verify_lsp_workspace(
						client,
						project_root,
						args.request_timeout,
						boundary=operation_boundary,
					)
					client_initialized = True
					should_spawn_lsp = False
				except Exception as error:
					connection_fallback_reason = str(error)
					if client is not None:
						client.close()
					client = None
		if should_spawn_lsp:
			if args.connect_or_spawn or port <= 0:
				port = _reserve_local_port()
			temp_log_path = _make_temp_log_path(args.log_file)
			process = _create_owned_godot_lsp(
				args.godot,
				project_root,
				port,
				temp_log_path,
				environment=process_environment,
				timeout_seconds=args.lsp_process_timeout,
			)
			process.start()
			operation_boundary = _LspOperationBoundary(process)
			spawned = True
			client, started_pid, listener_pid = _connect_verified_owned_lsp_client(
				process,
				"127.0.0.1",
				port,
				args.startup_timeout,
			)
		elif client is None and not _wait_for_port("127.0.0.1", port, min(args.startup_timeout, 3.0)):
			raise RuntimeError(
				"Godot LSP port %d is not open. Open the editor or pass --connect-or-spawn."
				% port
			)

		if client is None:
			client = LspClient("127.0.0.1", port)
		if not client_initialized:
			try:
				_initialize_lsp(
					client,
					project_root,
					args.request_timeout,
					boundary=operation_boundary,
				)
				workspace_definition_uri = _verify_lsp_workspace(
					client,
					project_root,
					args.request_timeout,
					boundary=operation_boundary,
				)
				client_initialized = True
			except Exception:
				client.close()
				raise
		try:
			diagnostics, timed_out_files = _scan_files(
				client,
				project_root,
				files,
				args.per_file_timeout,
				args.max_file_timeout,
				args.timeout_retries,
				boundary=operation_boundary,
			)
		finally:
			client.close()

		fail_severities = _parse_csv(args.fail_severity)
		report = _make_report(
			project_root,
			files,
			diagnostics,
			timed_out_files,
			port,
			spawned,
			fail_severities,
			time.monotonic() - started_at,
		)
	except BaseException as error:
		operation_error = error
		operation_traceback = gf_process_supervisor.safe_exception_traceback(error)
	finally:
		if process is not None and process.has_lease:
			try:
				process_result = process.stop()
			except BaseException as cleanup_error:
				if operation_error is not None:
					selected_error, selected_traceback = (
						gf_process_supervisor._select_preferred_cleanup_error(
							operation_error,
							operation_traceback,
							cleanup_error,
							context="LSP operation and owned-process cleanup",
						)
					)
					assert selected_error is not None
					any_cleanup_debt = (
						gf_process_supervisor.exception_has_cleanup_debt(operation_error)
						or gf_process_supervisor.exception_has_cleanup_debt(cleanup_error)
					)
					if any_cleanup_debt:
						combined_error = LspOperationCleanupError(
							operation_error,
							cleanup_error,
						)
						combined_error.original_error = selected_error
						if (
							isinstance(
								cleanup_error,
								gf_process_supervisor.SupervisedProcessCleanupError,
							)
							and cleanup_error.original_error is None
						):
							cleanup_error.original_error = selected_error
						_settle_deferred_cleanups_before_propagation(
							(operation_error, cleanup_error)
						)
						raise combined_error from selected_error
					if not isinstance(selected_error, Exception):
						gf_process_supervisor.add_exception_note(
							selected_error,
							"The other LSP operation/cleanup phase also failed: "
							f"{type(cleanup_error if selected_error is operation_error else operation_error).__name__}.",
						)
						if selected_error is cleanup_error:
							raise selected_error.with_traceback(
								selected_traceback
							) from operation_error
						raise selected_error.with_traceback(selected_traceback)
					gf_process_supervisor.add_exception_note(
						operation_error,
						"Invocation-owned Godot LSP cleanup finished quietly but also "
						"reported: "
						f"{gf_process_supervisor.safe_exception_detail(cleanup_error)}",
					)
					raise operation_error.with_traceback(operation_traceback)
				_settle_deferred_cleanups_before_propagation((cleanup_error,))
				raise

	if operation_error is not None and gf_process_supervisor.exception_has_cleanup_debt(
		operation_error
	):
		_settle_deferred_cleanups_before_propagation((operation_error,))
		raise operation_error.with_traceback(operation_traceback)
	if operation_error is not None and not isinstance(operation_error, Exception):
		raise operation_error.with_traceback(operation_traceback)

	if operation_error is None and spawned:
		if process_result is None:
			operation_error = RuntimeError(
				"Invocation-owned Godot LSP completed without supervisor evidence."
			)
		else:
			try:
				_verify_owned_connection_identity(
					listener_pid,
					started_pid,
					process_result,
				)
			except RuntimeError as error:
				operation_error = error

	if operation_error is not None:
		audit_path: pathlib.Path | None = None
		if not spawned and args.log_file:
			retained_owned_lease = process is not None and process.has_lease
			audit_path = pathlib.Path(args.log_file)
			_write_connection_audit_log(audit_path, {
				"tool": "gdscript_lsp_diagnostics",
				"transport": {
					"host": "127.0.0.1",
					"port": port,
					"mode": (
						"spawned" if retained_owned_lease else "connected_non_authoritative"
					),
					"authority": (
						"invocation_owned"
						if retained_owned_lease
						else "non_authoritative"
					),
					"spawned_godot_lsp": retained_owned_lease,
				},
				"summary": {"ok": False},
				"error": str(operation_error),
			})
		result_code = _print_tool_error(str(operation_error), audit_path or temp_log_path)
		if temp_log_path is not None and not args.keep_log:
			_remove_file(temp_log_path)
		return result_code

	if report is None:
		raise RuntimeError("GDScript LSP diagnostics completed without a report.")
	transport = report["transport"]
	transport["configured_port"] = configured_port
	transport["workspace_definition_uri"] = workspace_definition_uri
	invocation_owned = bool(
		spawned
		and process is not None
		and process.has_lease
		and process_result is not None
		and process_result.process_boundary_quiescent
		and listener_pid == started_pid == process_result.pid
	)
	transport["authority"] = (
		"invocation_owned" if invocation_owned else "non_authoritative"
	)
	transport["dynamic_port"] = bool(
		spawned and (configured_port <= 0 or args.connect_or_spawn)
	)
	transport["ambient_connect_allowed"] = not args.spawn_lsp
	if connection_fallback_reason:
		transport["fallback_reason"] = connection_fallback_reason
	if process is not None:
		transport["resolved_godot_executable"] = process.command[0]
	if process_result is not None:
		transport.update({
			"server_pid": process_result.pid,
			"listener_pid": listener_pid,
			"listener_identity_verified": (
				listener_pid == started_pid == process_result.pid
			),
			"listener_identity_kind": "established_server_connection_owner_pid",
			"supervisor_cancelled": process_result.cancelled,
			"process_boundary_quiescent": process_result.process_boundary_quiescent,
		})
	try:
		if not spawned and args.log_file:
			_write_connection_audit_log(pathlib.Path(args.log_file), report)
		if args.output_json:
			_write_json(pathlib.Path(args.output_json), report)
		if args.format == "json":
			print(encode_strict_json(report, indent=2))
		else:
			_print_text_report(report, args.limit)
	except Exception as error:
		return _print_tool_error(str(error), temp_log_path)
	finally:
		if temp_log_path is not None and not args.keep_log:
			_remove_file(temp_log_path)

	if report["summary"]["timeout_count"] > 0:
		return 2
	if not args.allow_diagnostics and report["summary"]["failing_diagnostic_count"] > 0:
		return 1
	return 0


def _parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(
		description="Scan GDScript diagnostics from Godot editor LSP.",
	)
	parser.add_argument("--project-root", default=".", help="Godot project root. Defaults to cwd.")
	parser.add_argument("--godot", default="godot", help="Godot executable used when spawning LSP.")
	parser.add_argument("--port", type=int, default=6005, help="Existing Godot LSP port. Use 0 with --spawn-lsp for a free port.")
	lsp_mode = parser.add_mutually_exclusive_group()
	lsp_mode.add_argument("--spawn-lsp", action="store_true", help="Always spawn a hidden headless Godot editor LSP process.")
	lsp_mode.add_argument(
		"--connect-or-spawn",
		action="store_true",
		help="Reuse the configured LSP port when available; otherwise spawn a hidden headless process.",
	)
	parser.add_argument("--startup-timeout", type=float, default=120.0, help="Seconds to wait for spawned LSP startup.")
	parser.add_argument(
		"--lsp-process-timeout",
		type=float,
		default=600.0,
		help="Maximum lifetime in seconds for an invocation-owned Godot LSP process.",
	)
	parser.add_argument("--request-timeout", type=float, default=60.0, help="Seconds to wait for initialize response.")
	parser.add_argument("--per-file-timeout", type=float, default=3.0, help="Base seconds to wait for each file diagnostics.")
	parser.add_argument("--max-file-timeout", type=float, default=12.0, help="Maximum size-scaled diagnostics wait per file before retry scaling.")
	parser.add_argument("--timeout-retries", type=int, default=2, help="Retry count for files that do not publish diagnostics in time.")
	parser.add_argument("--include", action="append", default=[], help="File or directory to scan. Repeatable.")
	parser.add_argument("--file", action="append", default=[], help="Specific .gd file to scan. Repeatable.")
	parser.add_argument("--exclude-prefix", action="append", default=[], help="Project-relative path prefix to skip. Repeatable.")
	parser.add_argument(
		"--fail-severity",
		default=",".join(DEFAULT_FAIL_SEVERITIES),
		help="Comma-separated severities that fail the command. Defaults to error,warning.",
	)
	parser.add_argument("--log-file", default="", help="Godot log file path used for spawned LSP.")
	parser.add_argument("--keep-log", action="store_true", help="Keep the temporary Godot log file.")
	parser.add_argument("--output-json", default="", help="Optional JSON report path.")
	parser.add_argument("--format", choices=("text", "json"), default="text")
	parser.add_argument("--limit", type=int, default=100, help="Max diagnostics printed in text mode.")
	parser.add_argument("--allow-diagnostics", action="store_true", help="Return exit 0 even when failing diagnostics exist.")
	return parser.parse_args()


def _collect_files(project_root: pathlib.Path, args: argparse.Namespace) -> list[pathlib.Path]:
	raw_inputs = [*args.include, *args.file] or list(DEFAULT_SCAN_ROOTS)
	excluded_prefixes = tuple(DEFAULT_EXCLUDED_PREFIXES + tuple(_normalize_prefix(prefix) for prefix in args.exclude_prefix))
	result: list[pathlib.Path] = []
	seen: set[str] = set()
	for raw_input in raw_inputs:
		path = _resolve_project_path(project_root, raw_input)
		if path.is_dir():
			candidates = sorted(path.rglob("*.gd"))
		elif path.is_file() and path.suffix == ".gd":
			candidates = [path]
		else:
			continue

		for candidate in candidates:
			if _is_excluded(project_root, candidate, excluded_prefixes):
				continue
			normalized = os.path.normcase(str(candidate.resolve()))
			if normalized in seen:
				continue
			seen.add(normalized)
			result.append(candidate.resolve())
	result.sort(key=lambda value: _relative_path(project_root, value))
	return result


def _resolve_project_path(project_root: pathlib.Path, raw_path: str) -> pathlib.Path:
	if raw_path.startswith("res://"):
		return (project_root / raw_path.removeprefix("res://")).resolve()
	path = pathlib.Path(raw_path)
	if path.is_absolute():
		return path.resolve()
	return (project_root / path).resolve()


def _is_excluded(project_root: pathlib.Path, path: pathlib.Path, excluded_prefixes: tuple[str, ...]) -> bool:
	if set(path.parts).intersection(DEFAULT_EXCLUDED_PARTS):
		return True
	rel = _relative_path(project_root, path).replace("\\", "/")
	return any(rel.startswith(prefix + "/") or rel == prefix for prefix in excluded_prefixes if prefix)


def _normalize_prefix(prefix: str) -> str:
	if prefix.startswith("res://"):
		prefix = prefix.removeprefix("res://")
	return prefix.strip().strip("/").replace("\\", "/")


def _make_temp_log_path(log_file: str) -> pathlib.Path:
	if log_file:
		path = pathlib.Path(log_file)
		if not path.is_absolute():
			path = pathlib.Path.cwd() / path
		path.parent.mkdir(parents=True, exist_ok=True)
		return path
	return pathlib.Path(tempfile.gettempdir()) / ("gf_gdscript_lsp_diagnostics_%d.log" % os.getpid())


def _create_owned_godot_lsp(
	godot: str,
	project_root: pathlib.Path,
	port: int,
	temp_log_path: pathlib.Path,
	*,
	environment: dict[str, str],
	timeout_seconds: float,
) -> _OwnedLspProcess:
	resolved_godot = resolve_godot_executable(
		godot,
		environment=environment,
		cwd=project_root,
	)
	command = [
		resolved_godot,
		"--headless",
		"--editor",
		"--path",
		str(project_root),
		"--lsp-port",
		str(port),
		"--log-file",
		str(temp_log_path),
	]
	return _OwnedLspProcess(
		command,
		cwd=project_root,
		environment=environment,
		timeout_seconds=timeout_seconds,
	)


def _wait_for_port(
	host: str,
	port: int,
	timeout: float,
	*,
	owned_process: _OwnedLspProcess | None = None,
) -> bool:
	boundary = _LspOperationBoundary(owned_process)
	deadline = boundary.deadline_after(timeout)
	while time.perf_counter() < deadline:
		if owned_process is not None:
			owned_process.raise_if_finished()
		remaining = boundary.remaining(deadline, 0.5)
		if remaining <= 0.0:
			break
		try:
			with socket.create_connection((host, port), timeout=remaining):
				return True
		except OSError:
			time.sleep(boundary.remaining(deadline, 0.2))
	if owned_process is not None:
		owned_process.raise_if_finished()
	return False


def _connect_verified_owned_lsp_client(
	owned_process: _OwnedLspProcess,
	host: str,
	port: int,
	timeout_seconds: float,
) -> tuple[LspClient, int, int]:
	boundary = _LspOperationBoundary(owned_process)
	deadline = boundary.deadline_after(timeout_seconds)
	started_pid = owned_process.wait_started_pid(timeout_seconds)
	while True:
		owned_process.raise_if_finished()
		remaining = boundary.remaining(deadline)
		if remaining <= 0.0:
			raise RuntimeError("Godot LSP port did not open before timeout.")
		try:
			connection = socket.create_connection(
				(host, port),
				timeout=min(0.5, remaining),
			)
		except OSError:
			time.sleep(boundary.remaining(deadline, 0.2))
			continue

		try:
			while True:
				try:
					server_pid = _tcp_connection_server_pid(
						connection,
						deadline=deadline,
						health_check=owned_process.raise_if_finished,
					)
				except TcpOwnerLookupError:
					owned_process.raise_if_finished()
					remaining = boundary.remaining(deadline)
					if remaining <= 0.0:
						raise RuntimeError(
							"Kernel TCP evidence did not publish the connected LSP server owner "
							"before timeout."
						)
					time.sleep(min(0.05, remaining))
					continue
				owned_process.raise_if_finished()
				_verify_live_owned_connection_identity(server_pid, started_pid)
				return LspClient.from_connected_socket(connection), started_pid, server_pid
		except BaseException:
			connection.close()
			raise


def _initialize_lsp(
	client: LspClient,
	project_root: pathlib.Path,
	timeout: float,
	*,
	boundary: _LspOperationBoundary,
) -> None:
	deadline = boundary.deadline_after(timeout)
	request_id = client.request("initialize", {
		"processId": None,
		"rootUri": project_root.as_uri(),
		"capabilities": {
			"textDocument": {
				"publishDiagnostics": {
					"relatedInformation": True,
					"versionSupport": True,
				},
			},
			"workspace": {
				"workspaceFolders": True,
			},
		},
		"workspaceFolders": [
			{
				"uri": project_root.as_uri(),
				"name": project_root.name,
			},
		],
	}, deadline=deadline, boundary=boundary)
	while time.perf_counter() < deadline:
		message = client.receive(
			boundary.remaining(deadline, 0.5),
			boundary=boundary,
		)
		if message is None:
			continue
		if message.payload.get("id") == request_id:
			if "error" in message.payload:
				raise RuntimeError("Godot LSP initialize failed: %s" % message.payload["error"])
			client.notify(
				"initialized",
				{},
				deadline=deadline,
				boundary=boundary,
			)
			return
	boundary.checkpoint()
	raise RuntimeError("Godot LSP initialize timed out")


def _verify_lsp_workspace(
	client: LspClient,
	project_root: pathlib.Path,
	timeout: float,
	*,
	boundary: _LspOperationBoundary,
) -> str:
	deadline = boundary.deadline_after(timeout)
	probe_path = project_root / ".godot/gf_lsp_workspace_probe.gd"
	probe_uri = probe_path.as_uri()
	probe_line = "var _gf_lsp_workspace_probe: %s" % WORKSPACE_PROBE_CLASS
	probe_text = "extends RefCounted\n%s\n" % probe_line
	client.notify("textDocument/didOpen", {
		"textDocument": {
			"uri": probe_uri,
			"languageId": "gdscript",
			"version": 1,
			"text": probe_text,
		},
	}, deadline=deadline, boundary=boundary)
	try:
		request_id = client.request("textDocument/definition", {
			"textDocument": {"uri": probe_uri},
			"position": {
				"line": 1,
				"character": probe_line.index(WORKSPACE_PROBE_CLASS) + 1,
			},
		}, deadline=deadline, boundary=boundary)
		response = _wait_for_lsp_response(
			client,
			request_id,
			deadline,
			boundary=boundary,
		)
		if "error" in response:
			raise RuntimeError("Godot LSP workspace probe failed: %s" % response["error"])
		definition_uris = _definition_result_uris(response.get("result"))
		for definition_uri in definition_uris:
			if _uri_is_within_project(definition_uri, project_root):
				return definition_uri
		resolved = ", ".join(definition_uris) if definition_uris else "no definition"
		raise RuntimeError(
			"Connected Godot LSP workspace mismatch: expected %s, %s resolved to %s"
			% (project_root, WORKSPACE_PROBE_CLASS, resolved)
		)
	finally:
		close_deadline = boundary.deadline or deadline
		if time.perf_counter() < close_deadline:
			client.notify("textDocument/didClose", {
				"textDocument": {"uri": probe_uri},
			}, deadline=close_deadline, boundary=boundary)


def _wait_for_lsp_response(
	client: LspClient,
	request_id: int,
	deadline: float,
	*,
	boundary: _LspOperationBoundary,
) -> dict[str, Any]:
	deadline = boundary.clamp_deadline(deadline)
	while time.perf_counter() < deadline:
		message = client.receive(
			boundary.remaining(deadline, 0.5),
			boundary=boundary,
		)
		if message is not None and message.payload.get("id") == request_id:
			return message.payload
	boundary.checkpoint()
	raise RuntimeError("Godot LSP workspace probe timed out")


def _definition_result_uris(result: Any) -> list[str]:
	locations = result if isinstance(result, list) else [result]
	result_uris: list[str] = []
	for location in locations:
		if not isinstance(location, dict):
			continue
		uri = str(location.get("uri", location.get("targetUri", "")))
		if uri and uri not in result_uris:
			result_uris.append(uri)
	return result_uris


def _uri_is_within_project(uri: str, project_root: pathlib.Path) -> bool:
	path = _path_from_uri(uri)
	if path is None:
		return False
	try:
		path.resolve().relative_to(project_root.resolve())
		return True
	except ValueError:
		return False


def _scan_files(
	client: LspClient,
	project_root: pathlib.Path,
	files: list[pathlib.Path],
	per_file_timeout: float,
	max_file_timeout: float,
	timeout_retries: int,
	*,
	boundary: _LspOperationBoundary,
) -> tuple[list[dict[str, Any]], list[str]]:
	diagnostics: list[dict[str, Any]] = []
	remaining_files = list(files)
	timed_out_paths: list[pathlib.Path] = []
	next_version = 1
	retry_count = max(timeout_retries, 0)
	for attempt_index in range(retry_count + 1):
		boundary.checkpoint()
		attempt_diagnostics, timed_out_paths, next_version = _scan_file_pass(
			client,
			project_root,
			remaining_files,
			per_file_timeout,
			max_file_timeout,
			attempt_index,
			next_version,
			boundary=boundary,
		)
		diagnostics.extend(attempt_diagnostics)
		if not timed_out_paths:
			return diagnostics, []
		remaining_files = timed_out_paths
	return diagnostics, [_relative_path(project_root, path) for path in timed_out_paths]


def _scan_file_pass(
	client: LspClient,
	project_root: pathlib.Path,
	files: list[pathlib.Path],
	per_file_timeout: float,
	max_file_timeout: float,
	attempt_index: int,
	next_version: int,
	*,
	boundary: _LspOperationBoundary,
) -> tuple[list[dict[str, Any]], list[pathlib.Path], int]:
	diagnostics: list[dict[str, Any]] = []
	timed_out_paths: list[pathlib.Path] = []
	for path in files:
		boundary.checkpoint()
		uri = path.as_uri()
		version = next_version
		next_version += 1
		file_timeout = _get_file_timeout(path, per_file_timeout, max_file_timeout, attempt_index)
		file_deadline = boundary.deadline_after(file_timeout)
		file_text = _read_text(path)
		boundary.checkpoint()
		client.notify("textDocument/didOpen", {
			"textDocument": {
				"uri": uri,
				"languageId": "gdscript",
				"version": version,
				"text": file_text,
			},
		}, deadline=file_deadline, boundary=boundary)
		try:
			file_diagnostics = _wait_for_file_diagnostics(
				client,
				path,
				version,
				file_deadline,
				boundary=boundary,
			)
			if file_diagnostics is None:
				timed_out_paths.append(path)
			else:
				for diagnostic in file_diagnostics:
					diagnostics.append(_normalize_diagnostic(project_root, path, diagnostic))
		finally:
			close_deadline = boundary.deadline or (
				time.perf_counter() + max(0.1, file_timeout)
			)
			if time.perf_counter() < close_deadline:
				client.notify("textDocument/didClose", {
					"textDocument": {
						"uri": uri,
					},
				}, deadline=close_deadline, boundary=boundary)
	return diagnostics, timed_out_paths, next_version


def _get_file_timeout(
	path: pathlib.Path,
	base_timeout: float,
	max_timeout: float,
	attempt_index: int,
) -> float:
	file_size = 0
	try:
		file_size = path.stat().st_size
	except OSError:
		pass
	safe_base_timeout = max(base_timeout, 0.1)
	safe_max_timeout = max(max_timeout, safe_base_timeout)
	attempt_multiplier = float(attempt_index + 1)
	scaled_base_timeout = safe_base_timeout * attempt_multiplier
	scaled_max_timeout = max(safe_max_timeout * attempt_multiplier, scaled_base_timeout)
	size_scaled_timeout = scaled_base_timeout + (float(file_size) / 35000.0)
	return min(max(size_scaled_timeout, scaled_base_timeout), scaled_max_timeout)


def _wait_for_file_diagnostics(
	client: LspClient,
	path: pathlib.Path,
	version: int,
	deadline: float,
	*,
	boundary: _LspOperationBoundary,
) -> list[dict[str, Any]] | None:
	expected = _normalized_path_key(path)
	deadline = boundary.clamp_deadline(deadline)
	while time.perf_counter() < deadline:
		message = client.receive(
			boundary.remaining(deadline, 0.25),
			boundary=boundary,
		)
		if message is None:
			continue
		if message.payload.get("method") != "textDocument/publishDiagnostics":
			continue
		params = message.payload.get("params", {})
		received_uri = str(params.get("uri", ""))
		if _normalized_uri_path_key(received_uri) != expected:
			continue
		received_version = params.get("version")
		if isinstance(received_version, int) and received_version != version:
			continue
		return list(params.get("diagnostics", []))
	boundary.checkpoint()
	return None


def _normalize_diagnostic(
	project_root: pathlib.Path,
	path: pathlib.Path,
	diagnostic: dict[str, Any],
) -> dict[str, Any]:
	start = diagnostic.get("range", {}).get("start", {})
	severity_number = int(diagnostic.get("severity", 0) or 0)
	raw_message = str(diagnostic.get("message", ""))
	warning_code = str(diagnostic.get("code", ""))
	message = raw_message
	match = WARNING_CODE_PATTERN.match(raw_message)
	if match:
		warning_code = match.group(1)
		message = match.group(2)
	return {
		"path": _relative_path(project_root, path),
		"line": int(start.get("line", -1)) + 1,
		"column": int(start.get("character", -1)) + 1,
		"severity": SEVERITY_NAMES.get(severity_number, "unknown"),
		"severity_number": severity_number,
		"code": warning_code,
		"raw_code": diagnostic.get("code", ""),
		"source": diagnostic.get("source", "gdscript"),
		"message": message,
		"raw_message": raw_message,
	}


def _make_report(
	project_root: pathlib.Path,
	files: list[pathlib.Path],
	diagnostics: list[dict[str, Any]],
	timed_out_files: list[str],
	port: int,
	spawned: bool,
	fail_severities: set[str],
	elapsed_seconds: float,
) -> dict[str, Any]:
	counts_by_severity: dict[str, int] = {}
	counts_by_code: dict[str, int] = {}
	failing_diagnostics: list[dict[str, Any]] = []
	for diagnostic in diagnostics:
		severity = str(diagnostic["severity"])
		code = str(diagnostic["code"])
		counts_by_severity[severity] = counts_by_severity.get(severity, 0) + 1
		counts_by_code[code] = counts_by_code.get(code, 0) + 1
		if severity in fail_severities:
			failing_diagnostics.append(diagnostic)
	summary = {
		"ok": not failing_diagnostics and not timed_out_files,
		"files_scanned": len(files),
		"diagnostic_count": len(diagnostics),
		"failing_diagnostic_count": len(failing_diagnostics),
		"timeout_count": len(timed_out_files),
		"counts_by_severity": counts_by_severity,
		"counts_by_code": counts_by_code,
		"fail_severities": sorted(fail_severities),
		"elapsed_seconds": round(elapsed_seconds, 3),
	}
	return {
		"tool": "gdscript_lsp_diagnostics",
		"project_root": str(project_root),
		"transport": {
			"host": "127.0.0.1",
			"port": port,
			"mode": "spawned" if spawned else "connected",
			"spawned_godot_lsp": spawned,
		},
		"summary": summary,
		"timed_out_files": timed_out_files,
		"diagnostics": diagnostics,
	}


def _print_text_report(report: dict[str, Any], limit: int) -> None:
	summary = report["summary"]
	transport = report["transport"]
	print("GDScript LSP diagnostics")
	print("transport=%s host=%s port=%d" % (
		transport["mode"],
		transport["host"],
		transport["port"],
	))
	print("files_scanned=%d diagnostics=%d failing=%d timeouts=%d elapsed_seconds=%.3f" % (
		summary["files_scanned"],
		summary["diagnostic_count"],
		summary["failing_diagnostic_count"],
		summary["timeout_count"],
		summary["elapsed_seconds"],
	))
	if summary["counts_by_severity"]:
		print("by_severity=%s" % json.dumps(summary["counts_by_severity"], ensure_ascii=False, sort_keys=True))
	if summary["counts_by_code"]:
		print("by_code=%s" % json.dumps(summary["counts_by_code"], ensure_ascii=False, sort_keys=True))
	for path in report["timed_out_files"]:
		print("%s:0:0: timeout: did not receive diagnostics before timeout" % path)
	for diagnostic in report["diagnostics"][:max(limit, 0)]:
		print("%s:%d:%d: %s: %s: %s" % (
			diagnostic["path"],
			diagnostic["line"],
			diagnostic["column"],
			diagnostic["severity"],
			diagnostic["code"],
			diagnostic["message"],
		))
	remaining = len(report["diagnostics"]) - max(limit, 0)
	if remaining > 0:
		print("... %d more diagnostics omitted by --limit" % remaining)


def _print_tool_error(message: str, log_path: pathlib.Path | None) -> int:
	print("gdscript_lsp_diagnostics: %s" % message, file=sys.stderr)
	if log_path is not None and log_path.exists():
		print("Godot log: %s" % log_path, file=sys.stderr)
	return 2


def _write_json(path: pathlib.Path, report: dict[str, Any]) -> None:
	if not path.is_absolute():
		path = pathlib.Path.cwd() / path
	write_json_object_atomic(path, report)


def _write_connection_audit_log(path: pathlib.Path, report: dict[str, Any]) -> None:
	if not path.is_absolute():
		path = pathlib.Path.cwd() / path
	write_json_object_atomic(path, report)


def _read_text(path: pathlib.Path) -> str:
	try:
		return path.read_text(encoding="utf-8")
	except UnicodeDecodeError:
		return path.read_text(encoding="utf-8-sig")


def _parse_content_length(header: bytes) -> int:
	if len(header) > MAX_LSP_HEADER_BYTES:
		raise LspProtocolError("LSP header exceeds the configured byte limit.")
	try:
		text = header.decode("ascii", errors="strict")
	except UnicodeDecodeError as error:
		raise LspProtocolError("LSP header must be ASCII.") from error
	if not text.endswith("\r\n\r\n"):
		raise LspProtocolError("LSP header terminator is missing.")
	content_lengths: list[str] = []
	for line in text[:-4].split("\r\n"):
		if not line:
			continue
		if ":" not in line:
			raise LspProtocolError("Malformed LSP header field.")
		name, value = line.split(":", 1)
		if name.strip().lower() == "content-length":
			content_lengths.append(value.strip())
	if len(content_lengths) != 1:
		raise LspProtocolError("LSP frame must contain exactly one Content-Length field.")
	raw_length = content_lengths[0]
	if not raw_length or not raw_length.isascii() or not raw_length.isdecimal():
		raise LspProtocolError("LSP Content-Length must be an unsigned decimal integer.")
	length = int(raw_length)
	if length <= 0 or length > MAX_LSP_BODY_BYTES:
		raise LspProtocolError("LSP Content-Length is outside the configured byte range.")
	return length


def _reject_duplicate_json_object_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
	result: dict[str, Any] = {}
	for key, value in pairs:
		if key in result:
			raise ValueError(f"duplicate JSON object key: {key}")
		result[key] = value
	return result


def _reject_json_constant(value: str) -> Any:
	raise ValueError(f"non-finite JSON number: {value}")


def _parse_csv(text: str) -> set[str]:
	return {item.strip().lower() for item in text.split(",") if item.strip()}


def _tcp_listener_pid(host: str, port: int) -> int:
	if host != "127.0.0.1" or not 0 < port <= 65535:
		raise RuntimeError("Listener identity requires one valid IPv4 loopback port.")
	if os.name == "nt":
		return _windows_tcp_listener_pid(host, port)
	if sys.platform.startswith("linux"):
		return _linux_tcp_listener_pid(host, port)
	raise RuntimeError(
		"Authoritative Godot LSP listener identity is unsupported on this platform."
	)


def _tcp_connection_server_pid(
	connection: socket.socket,
	*,
	deadline: float | None = None,
	health_check: Callable[[], None] | None = None,
) -> int:
	_tcp_owner_lookup_checkpoint(deadline, health_check)
	try:
		client_endpoint = connection.getsockname()
		server_endpoint = connection.getpeername()
	except OSError as error:
		raise RuntimeError("Connected LSP socket endpoints could not be read.") from error
	if (
		len(client_endpoint) < 2
		or len(server_endpoint) < 2
		or not isinstance(client_endpoint[0], str)
		or not isinstance(server_endpoint[0], str)
	):
		raise RuntimeError("Connected LSP socket did not expose IPv4 endpoints.")
	client_host, client_port = client_endpoint[0], int(client_endpoint[1])
	server_host, server_port = server_endpoint[0], int(server_endpoint[1])
	for host, port in (
		(client_host, client_port),
		(server_host, server_port),
	):
		if host != "127.0.0.1" or not 0 < port <= 65535:
			raise RuntimeError(
				"Connected LSP ownership requires IPv4 loopback endpoints."
			)
	if os.name == "nt":
		owner_pid = _windows_tcp_connection_server_pid(
			server_host,
			server_port,
			client_host,
			client_port,
			deadline=deadline,
			health_check=health_check,
		)
	elif sys.platform.startswith("linux"):
		owner_pid = _linux_tcp_connection_server_pid(
			server_host,
			server_port,
			client_host,
			client_port,
			deadline=deadline,
			health_check=health_check,
		)
	else:
		raise RuntimeError(
			"Authoritative Godot LSP connection identity is unsupported on this platform."
		)
	_tcp_owner_lookup_checkpoint(deadline, health_check)
	return owner_pid


def _tcp_owner_lookup_checkpoint(
	deadline: float | None,
	health_check: Callable[[], None] | None,
) -> None:
	if health_check is not None:
		health_check()
	if deadline is not None and time.perf_counter() >= deadline:
		raise TcpOwnerLookupError(
			"TCP owner lookup exceeded the owned LSP operation deadline."
		)


def _windows_tcp_listener_pid(host: str, port: int) -> int:
	return _windows_tcp_owner_pid(
		host,
		port,
		remote_host=None,
		remote_port=None,
		state=2,
		table_class=3,
	)


def _windows_tcp_connection_server_pid(
	server_host: str,
	server_port: int,
	client_host: str,
	client_port: int,
	*,
	deadline: float | None = None,
	health_check: Callable[[], None] | None = None,
) -> int:
	return _windows_tcp_owner_pid(
		server_host,
		server_port,
		remote_host=client_host,
		remote_port=client_port,
		state=5,
		table_class=5,
		deadline=deadline,
		health_check=health_check,
	)


def _windows_tcp_owner_pid(
	local_host: str,
	local_port: int,
	*,
	remote_host: str | None,
	remote_port: int | None,
	state: int,
	table_class: int,
	deadline: float | None = None,
	health_check: Callable[[], None] | None = None,
) -> int:
	import ctypes
	from ctypes import wintypes

	class MibTcpRowOwnerPid(ctypes.Structure):
		_fields_ = (
			("state", wintypes.DWORD),
			("local_address", wintypes.DWORD),
			("local_port", wintypes.DWORD),
			("remote_address", wintypes.DWORD),
			("remote_port", wintypes.DWORD),
			("owning_pid", wintypes.DWORD),
		)

	get_extended_tcp_table = ctypes.WinDLL("iphlpapi").GetExtendedTcpTable
	get_extended_tcp_table.argtypes = (
		wintypes.LPVOID,
		ctypes.POINTER(wintypes.DWORD),
		wintypes.BOOL,
		wintypes.ULONG,
		wintypes.INT,
		wintypes.ULONG,
	)
	get_extended_tcp_table.restype = wintypes.DWORD
	table_buffer, table_size = _query_windows_tcp_table(
		get_extended_tcp_table,
		table_class,
		deadline=deadline,
		health_check=health_check,
	)
	row_size = ctypes.sizeof(MibTcpRowOwnerPid)
	entry_count = _windows_tcp_table_entry_count(
		table_buffer,
		table_size,
		row_size,
	)
	_tcp_owner_lookup_checkpoint(deadline, health_check)
	expected_local_address = int.from_bytes(
		socket.inet_aton(local_host),
		byteorder="little",
	)
	expected_remote_address = (
		None
		if remote_host is None
		else int.from_bytes(socket.inet_aton(remote_host), byteorder="little")
	)
	owner_pids: set[int] = set()
	for index in range(entry_count):
		if index % WINDOWS_TCP_OWNER_ROW_CHECKPOINT_INTERVAL == 0:
			_tcp_owner_lookup_checkpoint(deadline, health_check)
		row = MibTcpRowOwnerPid.from_buffer_copy(table_buffer, 4 + index * row_size)
		if row.state != state:
			continue
		if int(row.local_address) != expected_local_address:
			continue
		if socket.ntohs(int(row.local_port) & 0xFFFF) != local_port:
			continue
		if expected_remote_address is not None and (
			int(row.remote_address) != expected_remote_address
			or remote_port is None
			or socket.ntohs(int(row.remote_port) & 0xFFFF) != remote_port
		):
			continue
		owner_pids.add(int(row.owning_pid))
	_tcp_owner_lookup_checkpoint(deadline, health_check)
	return _one_tcp_owner_pid(owner_pids, local_host, local_port)


def _windows_tcp_table_entry_count(
	table_buffer: Any,
	table_size: int,
	row_size: int,
) -> int:
	if table_size < 4 or row_size <= 0:
		raise RuntimeError("Windows TCP owner table returned an invalid layout.")
	entry_count = int.from_bytes(table_buffer.raw[:4], byteorder="little")
	if entry_count > WINDOWS_TCP_OWNER_MAX_ENTRIES:
		raise TcpOwnerLookupError(
			"Windows TCP owner table exceeded the configured entry budget."
		)
	if 4 + entry_count * row_size > table_size:
		raise RuntimeError("Windows TCP owner table was truncated.")
	return entry_count


def _call_windows_tcp_native_query(
	query: Callable[[], int],
	*,
	deadline: float | None,
	health_check: Callable[[], None] | None,
) -> int:
	"""Run a read-only native TCP snapshot call without owning process authority."""

	_tcp_owner_lookup_checkpoint(deadline, health_check)
	if deadline is None and health_check is None:
		return int(query())

	finished = threading.Event()
	outcome: list[tuple[int | None, BaseException | None]] = []

	def invoke() -> None:
		try:
			outcome.append((int(query()), None))
		except BaseException as error:
			outcome.append((None, error))
		finally:
			finished.set()

	# The worker owns only the native call and its closure-retained read buffers.
	# It is deliberately daemonized so an uninterruptible OS snapshot cannot hold
	# the CLI alive after the supervised process deadline has already been reached.
	worker = threading.Thread(
		target=invoke,
		name="gf-windows-tcp-owner-query",
		daemon=True,
	)
	worker.start()
	while not finished.is_set():
		_tcp_owner_lookup_checkpoint(deadline, health_check)
		wait_seconds = WINDOWS_TCP_OWNER_WAIT_SLICE_SECONDS
		if deadline is not None:
			wait_seconds = min(wait_seconds, max(0.0, deadline - time.perf_counter()))
		finished.wait(wait_seconds)
	_tcp_owner_lookup_checkpoint(deadline, health_check)
	if len(outcome) != 1:
		raise RuntimeError("Windows TCP owner query completed without one result.")
	result, error = outcome[0]
	if error is not None:
		raise error.with_traceback(gf_process_supervisor.safe_exception_traceback(error))
	assert result is not None
	return result


def _query_windows_tcp_table(
	get_extended_tcp_table: Any,
	table_class: int,
	*,
	deadline: float | None = None,
	health_check: Callable[[], None] | None = None,
) -> tuple[Any, int]:
	import ctypes
	from ctypes import wintypes

	error_insufficient_buffer = 122
	table_size = wintypes.DWORD(0)
	result = _call_windows_tcp_native_query(
		lambda: get_extended_tcp_table(
			None,
			ctypes.byref(table_size),
			False,
			socket.AF_INET,
			table_class,
			0,
		),
		deadline=deadline,
		health_check=health_check,
	)
	if result not in (0, error_insufficient_buffer) or table_size.value < 4:
		raise RuntimeError(
			"Windows TCP owner table size query failed "
			f"(win32_error={result}, size={table_size.value})."
		)
	requested_size = int(table_size.value)
	if requested_size > WINDOWS_TCP_OWNER_TABLE_MAX_BYTES:
		raise TcpOwnerLookupError(
			"Windows TCP owner table exceeded the configured byte budget."
		)
	for _attempt in range(WINDOWS_TCP_OWNER_QUERY_RETRIES):
		_tcp_owner_lookup_checkpoint(deadline, health_check)
		table_buffer = ctypes.create_string_buffer(requested_size)
		table_size = wintypes.DWORD(requested_size)
		result = _call_windows_tcp_native_query(
			lambda: get_extended_tcp_table(
				table_buffer,
				ctypes.byref(table_size),
				False,
				socket.AF_INET,
				table_class,
				0,
			),
			deadline=deadline,
			health_check=health_check,
		)
		if result == 0:
			used_size = int(table_size.value)
			if used_size < 4 or used_size > requested_size:
				raise RuntimeError(
					"Windows TCP owner table returned an invalid byte size."
				)
			return table_buffer, used_size
		if result != error_insufficient_buffer or table_size.value <= requested_size:
			raise RuntimeError(
				f"Windows TCP owner table query failed (win32_error={result})."
			)
		requested_size = int(table_size.value)
		if requested_size > WINDOWS_TCP_OWNER_TABLE_MAX_BYTES:
			raise TcpOwnerLookupError(
				"Windows TCP owner table exceeded the configured byte budget."
			)
	raise RuntimeError("Windows TCP owner table kept growing during bounded retries.")


def _linux_tcp_listener_pid(host: str, port: int) -> int:
	return _linux_tcp_owner_pid(
		host,
		port,
		remote_host=None,
		remote_port=None,
		state="0A",
	)


def _linux_tcp_connection_server_pid(
	server_host: str,
	server_port: int,
	client_host: str,
	client_port: int,
	*,
	deadline: float | None = None,
	health_check: Callable[[], None] | None = None,
) -> int:
	return _linux_tcp_owner_pid(
		server_host,
		server_port,
		remote_host=client_host,
		remote_port=client_port,
		state="01",
		deadline=deadline,
		health_check=health_check,
	)


def _linux_tcp_owner_pid(
	local_host: str,
	local_port: int,
	*,
	remote_host: str | None,
	remote_port: int | None,
	state: str,
	deadline: float | None = None,
	health_check: Callable[[], None] | None = None,
) -> int:
	_tcp_owner_lookup_checkpoint(deadline, health_check)
	try:
		with pathlib.Path("/proc/net/tcp").open("rb") as tcp_table:
			table_payload = tcp_table.read(LINUX_TCP_OWNER_TABLE_MAX_BYTES + 1)
	except OSError as error:
		raise RuntimeError("Linux TCP owner table could not be read.") from error
	_tcp_owner_lookup_checkpoint(deadline, health_check)
	if len(table_payload) > LINUX_TCP_OWNER_TABLE_MAX_BYTES:
		raise TcpOwnerLookupError("Linux TCP owner table exceeded its byte budget.")
	try:
		lines = table_payload.decode("ascii", errors="strict").splitlines()[1:]
	except UnicodeDecodeError as error:
		raise RuntimeError("Linux TCP owner table was not ASCII.") from error
	owner_inodes = _linux_tcp_owner_inodes(
		lines,
		local_host,
		local_port,
		remote_host=remote_host,
		remote_port=remote_port,
		state=state,
	)

	owner_pids: set[int] = set()
	pid_entry_count = 0
	fd_entry_count = 0
	for process_directory in pathlib.Path("/proc").iterdir():
		if not process_directory.name.isdecimal():
			continue
		pid_entry_count += 1
		if pid_entry_count > LINUX_TCP_OWNER_MAX_PID_ENTRIES:
			raise TcpOwnerLookupError("Linux TCP owner lookup exceeded its PID budget.")
		_tcp_owner_lookup_checkpoint(deadline, health_check)
		fd_directory = process_directory / "fd"
		try:
			file_descriptors = fd_directory.iterdir()
		except OSError:
			continue
		try:
			for file_descriptor in file_descriptors:
				fd_entry_count += 1
				if fd_entry_count > LINUX_TCP_OWNER_MAX_FD_ENTRIES:
					raise TcpOwnerLookupError(
						"Linux TCP owner lookup exceeded its file-descriptor budget."
					)
				_tcp_owner_lookup_checkpoint(deadline, health_check)
				try:
					target = os.readlink(file_descriptor)
				except OSError:
					continue
				if target.startswith("socket:[") and target.endswith("]"):
					inode = target[8:-1]
					if inode in owner_inodes:
						owner_pids.add(int(process_directory.name))
						break
		except OSError:
			continue
	_tcp_owner_lookup_checkpoint(deadline, health_check)
	return _one_tcp_owner_pid(owner_pids, local_host, local_port)


def _linux_tcp_owner_inodes(
	lines: list[str],
	local_host: str,
	local_port: int,
	*,
	remote_host: str | None,
	remote_port: int | None,
	state: str,
) -> set[str]:
	expected_local = _linux_proc_tcp_endpoint(local_host, local_port)
	expected_remote = (
		None
		if remote_host is None or remote_port is None
		else _linux_proc_tcp_endpoint(remote_host, remote_port)
	)
	owner_inodes: set[str] = set()
	for line in lines:
		fields = line.split()
		if len(fields) < 10 or fields[3].upper() != state:
			continue
		if fields[1].upper() != expected_local:
			continue
		if expected_remote is not None and fields[2].upper() != expected_remote:
			continue
		owner_inodes.add(fields[9])
	if not owner_inodes:
		raise TcpOwnerLookupError(
			f"No Linux TCP owner inode matched {local_host}:{local_port}."
		)
	return owner_inodes


def _linux_proc_tcp_endpoint(host: str, port: int) -> str:
	packed_address = socket.inet_aton(host)
	if sys.byteorder == "little":
		packed_address = packed_address[::-1]
	return f"{packed_address.hex().upper()}:{port:04X}"


def _one_tcp_owner_pid(owner_pids: set[int], host: str, port: int) -> int:
	if len(owner_pids) != 1:
		raise TcpOwnerLookupError(
			f"Expected exactly one TCP owner for {host}:{port}; "
			f"observed {len(owner_pids)}."
		)
	owner_pid = next(iter(owner_pids))
	if owner_pid <= 0:
		raise RuntimeError(f"TCP listener owner for {host}:{port} had no valid PID.")
	return owner_pid


def _verify_live_owned_connection_identity(connection_pid: int, started_pid: int) -> None:
	if connection_pid <= 0 or connection_pid != started_pid:
		raise RuntimeError(
			"Godot LSP established connection ownership mismatch before protocol use: "
			f"connection_pid={connection_pid}, supervised_pid={started_pid}."
		)


def _verify_owned_connection_identity(
	connection_pid: int,
	started_pid: int,
	process_result: gf_process_supervisor.SupervisedProcessResult,
) -> None:
	if (
		connection_pid <= 0
		or started_pid <= 0
		or connection_pid != started_pid
		or started_pid != process_result.pid
	):
		raise RuntimeError(
			"Godot LSP established connection ownership mismatch: "
			f"connection_pid={connection_pid}, started_pid={started_pid}, "
			f"supervised_pid={process_result.pid}."
		)


def _reserve_local_port() -> int:
	with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
		listener.bind(("127.0.0.1", 0))
		return int(listener.getsockname()[1])


def _relative_path(project_root: pathlib.Path, path: pathlib.Path) -> str:
	try:
		return str(path.resolve().relative_to(project_root)).replace("\\", "/")
	except ValueError:
		return str(path)


def _normalized_path_key(path: pathlib.Path) -> str:
	return os.path.normcase(str(path.resolve()))


def _normalized_uri_path_key(uri: str) -> str:
	path = _path_from_uri(uri)
	return os.path.normcase(str(path.resolve())) if path is not None else ""


def _path_from_uri(uri: str) -> pathlib.Path | None:
	parsed = urllib.parse.urlparse(uri)
	if parsed.scheme != "file":
		return None
	path_text = urllib.parse.unquote(parsed.path)
	if os.name == "nt" and re.match(r"^/[A-Za-z]:", path_text):
		path_text = path_text[1:]
	return pathlib.Path(path_text)


def _remove_file(path: pathlib.Path) -> None:
	try:
		path.unlink(missing_ok=True)
	except OSError:
		pass


if __name__ == "__main__":
	try:
		raise SystemExit(main())
	except RuntimeError as error:
		print("gdscript_lsp_diagnostics: %s" % error, file=sys.stderr)
		raise SystemExit(2)
