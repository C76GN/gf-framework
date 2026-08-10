#!/usr/bin/env python3
"""Collect Godot GDScript diagnostics through the editor Language Server.

This complements headless editor reload-log checks. Godot can surface some
GDScript warnings through the editor diagnostics pipeline without reliably
printing them in GUT or short --editor --quit runs.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import re
import socket
import subprocess
import sys
import tempfile
import time
import urllib.parse
from dataclasses import dataclass
from typing import Any

from gf_godot_process import resolve_godot_executable
from gf_maintenance_rendering import encode_strict_json
from gf_maintenance_rendering import write_json_object_atomic


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


class LspProtocolError(RuntimeError):
	"""The peer sent an invalid, truncated, or deadline-exhausted LSP frame."""


@dataclass(frozen=True)
class JsonRpcMessage:
	payload: dict[str, Any]


class LspClient:
	def __init__(self, host: str, port: int) -> None:
		self._socket = socket.create_connection((host, port), timeout=5.0)
		self._next_id = 1
		self._receive_buffer = bytearray()

	def close(self) -> None:
		try:
			self._socket.close()
		except OSError:
			pass

	def request(self, method: str, params: dict[str, Any]) -> int:
		request_id = self._next_id
		self._next_id += 1
		self.send({
			"jsonrpc": "2.0",
			"id": request_id,
			"method": method,
			"params": params,
		})
		return request_id

	def notify(self, method: str, params: dict[str, Any]) -> None:
		self.send({
			"jsonrpc": "2.0",
			"method": method,
			"params": params,
		})

	def send(self, payload: dict[str, Any]) -> None:
		data = encode_strict_json(payload).encode("utf-8")
		header = f"Content-Length: {len(data)}\r\n\r\n".encode("ascii")
		self._socket.settimeout(None)
		self._socket.sendall(header + data)

	def receive(self, timeout: float) -> JsonRpcMessage | None:
		deadline = time.monotonic() + max(timeout, 0.0)
		header_end = self._receive_buffer.find(b"\r\n\r\n")
		while header_end < 0:
			if len(self._receive_buffer) >= MAX_LSP_HEADER_BYTES:
				raise LspProtocolError("LSP header exceeds the configured byte limit.")
			if not self._receive_until(deadline, MAX_LSP_HEADER_BYTES):
				return None
			header_end = self._receive_buffer.find(b"\r\n\r\n")
		header_size = header_end + 4
		if header_size > MAX_LSP_HEADER_BYTES:
			raise LspProtocolError("LSP header exceeds the configured byte limit.")
		length = _parse_content_length(bytes(self._receive_buffer[:header_size]))
		frame_size = header_size + length
		while len(self._receive_buffer) < frame_size:
			self._receive_until(deadline, frame_size)
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
		return JsonRpcMessage(payload)

	def _receive_until(self, deadline: float, maximum_buffer_size: int) -> bool:
		remaining = deadline - time.monotonic()
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
		return True


def main() -> int:
	args = _parse_args()
	project_root = pathlib.Path(args.project_root).resolve()
	files = _collect_files(project_root, args)
	if not files:
		return _print_tool_error("No GDScript files matched the scan inputs.", None)

	temp_log_path: pathlib.Path | None = None
	process: subprocess.Popen[str] | None = None
	port = args.port
	configured_port = args.port
	spawned = False
	connection_fallback_reason = ""
	workspace_definition_uri = ""
	started_at = time.monotonic()

	try:
		client: LspClient | None = None
		should_spawn_lsp = args.spawn_lsp
		if args.connect_or_spawn:
			should_spawn_lsp = True
			if port > 0 and _wait_for_port("127.0.0.1", port, min(args.startup_timeout, 1.0)):
				try:
					client = LspClient("127.0.0.1", port)
					_initialize_lsp(client, project_root, args.request_timeout)
					workspace_definition_uri = _verify_lsp_workspace(
						client,
						project_root,
						args.request_timeout,
					)
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
			process = _start_godot_lsp(args.godot, project_root, port, temp_log_path)
			spawned = True
			if not _wait_for_port("127.0.0.1", port, args.startup_timeout):
				return _print_tool_error("Godot LSP port did not open before timeout.", temp_log_path)
		elif client is None and not _wait_for_port("127.0.0.1", port, min(args.startup_timeout, 3.0)):
			return _print_tool_error(
				"Godot LSP port %d is not open. Open the editor or pass --connect-or-spawn." % port,
				None,
			)

		if client is None:
			client = LspClient("127.0.0.1", port)
			try:
				_initialize_lsp(client, project_root, args.request_timeout)
				workspace_definition_uri = _verify_lsp_workspace(
					client,
					project_root,
					args.request_timeout,
				)
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
		report["transport"]["configured_port"] = configured_port
		report["transport"]["workspace_definition_uri"] = workspace_definition_uri
		if connection_fallback_reason:
			report["transport"]["fallback_reason"] = connection_fallback_reason
		if not spawned and args.log_file:
			_write_connection_audit_log(pathlib.Path(args.log_file), report)
		if args.output_json:
			_write_json(pathlib.Path(args.output_json), report)
		if args.format == "json":
			print(encode_strict_json(report, indent=2))
		else:
			_print_text_report(report, args.limit)

		if report["summary"]["timeout_count"] > 0:
			return 2
		if not args.allow_diagnostics and report["summary"]["failing_diagnostic_count"] > 0:
			return 1
		return 0
	except Exception as error:
		audit_path: pathlib.Path | None = None
		if not spawned and args.log_file:
			audit_path = pathlib.Path(args.log_file)
			_write_connection_audit_log(audit_path, {
				"tool": "gdscript_lsp_diagnostics",
				"transport": {
					"host": "127.0.0.1",
					"port": port,
					"mode": "connected",
					"spawned_godot_lsp": False,
				},
				"summary": {"ok": False},
				"error": str(error),
			})
		return _print_tool_error(str(error), audit_path)
	finally:
		if process is not None:
			_stop_process(process)
		if temp_log_path is not None and not args.keep_log:
			_remove_file(temp_log_path)


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


def _start_godot_lsp(
	godot: str,
	project_root: pathlib.Path,
	port: int,
	temp_log_path: pathlib.Path,
) -> subprocess.Popen[str]:
	resolved_godot = resolve_godot_executable(godot)
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
	startupinfo = None
	creationflags = 0
	if os.name == "nt":
		startupinfo = subprocess.STARTUPINFO()
		startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
		creationflags = subprocess.CREATE_NO_WINDOW
	return subprocess.Popen(
		command,
		cwd=str(project_root),
		stdout=subprocess.DEVNULL,
		stderr=subprocess.DEVNULL,
		text=True,
		startupinfo=startupinfo,
		creationflags=creationflags,
	)


def _wait_for_port(host: str, port: int, timeout: float) -> bool:
	deadline = time.monotonic() + timeout
	while time.monotonic() < deadline:
		try:
			with socket.create_connection((host, port), timeout=0.5):
				return True
		except OSError:
			time.sleep(0.2)
	return False


def _initialize_lsp(client: LspClient, project_root: pathlib.Path, timeout: float) -> None:
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
	})
	deadline = time.monotonic() + timeout
	while time.monotonic() < deadline:
		message = client.receive(min(0.5, max(deadline - time.monotonic(), 0.0)))
		if message is None:
			continue
		if message.payload.get("id") == request_id:
			if "error" in message.payload:
				raise RuntimeError("Godot LSP initialize failed: %s" % message.payload["error"])
			client.notify("initialized", {})
			return
	raise RuntimeError("Godot LSP initialize timed out")


def _verify_lsp_workspace(
	client: LspClient,
	project_root: pathlib.Path,
	timeout: float,
) -> str:
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
	})
	try:
		request_id = client.request("textDocument/definition", {
			"textDocument": {"uri": probe_uri},
			"position": {
				"line": 1,
				"character": probe_line.index(WORKSPACE_PROBE_CLASS) + 1,
			},
		})
		response = _wait_for_lsp_response(client, request_id, timeout)
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
		client.notify("textDocument/didClose", {
			"textDocument": {"uri": probe_uri},
		})


def _wait_for_lsp_response(client: LspClient, request_id: int, timeout: float) -> dict[str, Any]:
	deadline = time.monotonic() + timeout
	while time.monotonic() < deadline:
		message = client.receive(min(0.5, max(deadline - time.monotonic(), 0.0)))
		if message is not None and message.payload.get("id") == request_id:
			return message.payload
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
) -> tuple[list[dict[str, Any]], list[str]]:
	diagnostics: list[dict[str, Any]] = []
	remaining_files = list(files)
	timed_out_paths: list[pathlib.Path] = []
	next_version = 1
	retry_count = max(timeout_retries, 0)
	for attempt_index in range(retry_count + 1):
		attempt_diagnostics, timed_out_paths, next_version = _scan_file_pass(
			client,
			project_root,
			remaining_files,
			per_file_timeout,
			max_file_timeout,
			attempt_index,
			next_version,
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
) -> tuple[list[dict[str, Any]], list[pathlib.Path], int]:
	diagnostics: list[dict[str, Any]] = []
	timed_out_paths: list[pathlib.Path] = []
	for path in files:
		uri = path.as_uri()
		version = next_version
		next_version += 1
		client.notify("textDocument/didOpen", {
			"textDocument": {
				"uri": uri,
				"languageId": "gdscript",
				"version": version,
				"text": _read_text(path),
			},
		})
		try:
			file_timeout = _get_file_timeout(path, per_file_timeout, max_file_timeout, attempt_index)
			file_diagnostics = _wait_for_file_diagnostics(client, path, version, file_timeout)
			if file_diagnostics is None:
				timed_out_paths.append(path)
			else:
				for diagnostic in file_diagnostics:
					diagnostics.append(_normalize_diagnostic(project_root, path, diagnostic))
		finally:
			client.notify("textDocument/didClose", {
				"textDocument": {
					"uri": uri,
				},
			})
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
	timeout: float,
) -> list[dict[str, Any]] | None:
	expected = _normalized_path_key(path)
	deadline = time.monotonic() + timeout
	while time.monotonic() < deadline:
		message = client.receive(min(0.25, max(deadline - time.monotonic(), 0.0)))
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


def _stop_process(process: subprocess.Popen[str]) -> None:
	if process.poll() is not None:
		return
	process.terminate()
	try:
		process.wait(timeout=5.0)
	except subprocess.TimeoutExpired:
		process.kill()
		process.wait(timeout=5.0)


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
