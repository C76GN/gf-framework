#!/usr/bin/env python3
"""Focused behavioral tests for GF maintenance execution/protocol boundaries."""

from __future__ import annotations

import io
import json
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gdscript_lsp_diagnostics
import gf_maintenance
import gf_maintenance_rendering
import gf_mcp_server
import gf_workspace_snapshot


class StrictJsonBoundaryTests(unittest.TestCase):
	def test_strict_encoder_rejects_non_finite_numbers(self) -> None:
		with self.assertRaises(ValueError):
			gf_maintenance_rendering.encode_strict_json({"value": float("nan")})

	def test_atomic_json_writer_preserves_old_target_when_replace_fails(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			target = Path(temporary_directory) / "report.json"
			target.write_text('{"old":true}\n', encoding="utf-8")
			with mock.patch.object(
				gf_maintenance_rendering.os,
				"replace",
				side_effect=OSError("injected replace failure"),
			):
				with self.assertRaises(OSError):
					gf_maintenance_rendering.write_json_object_atomic(target, {"new": True})
			self.assertEqual(target.read_text(encoding="utf-8"), '{"old":true}\n')
			self.assertEqual(list(target.parent.glob(f".{target.name}.*.tmp")), [])

	def test_lsp_json_writers_are_strict_and_atomic(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			target = Path(temporary_directory) / "lsp.json"
			target.write_text('{"old":true}\n', encoding="utf-8")
			with self.assertRaises(ValueError):
				gdscript_lsp_diagnostics._write_json(target, {"value": float("inf")})
			self.assertEqual(target.read_text(encoding="utf-8"), '{"old":true}\n')
			gdscript_lsp_diagnostics._write_connection_audit_log(target, {"ok": True})
			self.assertEqual(json.loads(target.read_text(encoding="utf-8")), {"ok": True})


class LspFramingBoundaryTests(unittest.TestCase):
	def _make_client(self, connection: socket.socket) -> gdscript_lsp_diagnostics.LspClient:
		client = gdscript_lsp_diagnostics.LspClient.__new__(
			gdscript_lsp_diagnostics.LspClient
		)
		client._socket = connection
		client._next_id = 1
		client._receive_buffer = bytearray()
		return client

	def test_fragmented_frame_round_trips(self) -> None:
		client_socket, peer_socket = socket.socketpair()
		self.addCleanup(client_socket.close)
		self.addCleanup(peer_socket.close)
		client = self._make_client(client_socket)
		payload = b'{"jsonrpc":"2.0","id":1,"result":{}}'
		frame = b"Content-Length: %d\r\n\r\n" % len(payload) + payload
		for offset in range(0, len(frame), 3):
			peer_socket.sendall(frame[offset:offset + 3])
		message = client.receive(0.5)
		self.assertIsNotNone(message)
		self.assertEqual(message.payload["id"], 1)

	def test_duplicate_and_oversized_content_length_fail_closed(self) -> None:
		with self.assertRaises(gdscript_lsp_diagnostics.LspProtocolError):
			gdscript_lsp_diagnostics._parse_content_length(
				b"Content-Length: 2\r\nContent-Length: 2\r\n\r\n"
			)
		with self.assertRaises(gdscript_lsp_diagnostics.LspProtocolError):
			gdscript_lsp_diagnostics._parse_content_length(
				(
					"Content-Length: %d\r\n\r\n"
					% (gdscript_lsp_diagnostics.MAX_LSP_BODY_BYTES + 1)
				).encode("ascii")
			)

	def test_trickle_header_cannot_refresh_the_absolute_deadline(self) -> None:
		client_socket, peer_socket = socket.socketpair()
		self.addCleanup(client_socket.close)
		self.addCleanup(peer_socket.close)
		client = self._make_client(client_socket)

		def trickle() -> None:
			for byte in b"Content-Length: 2":
				try:
					peer_socket.sendall(bytes([byte]))
				except OSError:
					return
				time.sleep(0.02)

		thread = threading.Thread(target=trickle, daemon=True)
		thread.start()
		started = time.monotonic()
		with self.assertRaises(gdscript_lsp_diagnostics.LspProtocolError):
			client.receive(0.06)
		self.assertLess(time.monotonic() - started, 0.25)

	def test_non_object_json_rpc_body_is_rejected(self) -> None:
		client_socket, peer_socket = socket.socketpair()
		self.addCleanup(client_socket.close)
		self.addCleanup(peer_socket.close)
		client = self._make_client(client_socket)
		payload = b"[]"
		peer_socket.sendall(b"Content-Length: 2\r\n\r\n" + payload)
		with self.assertRaises(gdscript_lsp_diagnostics.LspProtocolError):
			client.receive(0.5)


class McpBoundaryTests(unittest.TestCase):
	def _tool_request(self, request_id: int, name: str, arguments: dict[str, object]) -> dict[str, object]:
		return {
			"jsonrpc": "2.0",
			"id": request_id,
			"method": "tools/call",
			"params": {"name": name, "arguments": arguments},
		}

	def test_tool_arguments_enforce_advertised_schema(self) -> None:
		too_large = gf_mcp_server.handle_message(
			self._tool_request(1, "gf_api_search", {"query": "x", "limit": 81})
		)
		self.assertEqual(too_large["error"]["code"], -32602)
		extra = gf_mcp_server.handle_message(
			self._tool_request(2, "gf_api_search", {"query": "x", "unexpected": True})
		)
		self.assertEqual(extra["error"]["code"], -32602)
		empty_checks = gf_mcp_server.handle_message(
			self._tool_request(3, "gf_run_checks", {"checks": []})
		)
		self.assertEqual(empty_checks["error"]["code"], -32602)

	def test_request_decoder_is_bounded_strict_and_object_only(self) -> None:
		with self.assertRaises(gf_mcp_server.McpRequestError):
			gf_mcp_server.decode_request_bytes(b"[]\n")
		with self.assertRaises(gf_mcp_server.McpRequestError):
			gf_mcp_server.decode_request_bytes(b'{"jsonrpc":"2.0","x":NaN}\n')
		deep_value: object = None
		for _index in range(gf_mcp_server.MAX_MCP_JSON_DEPTH + 1):
			deep_value = [deep_value]
		with self.assertRaises(gf_mcp_server.McpRequestError):
			gf_mcp_server.decode_request_bytes(
				json.dumps({"jsonrpc": "2.0", "method": "ping", "params": {"value": deep_value}}).encode("utf-8")
			)
		with self.assertRaises(gf_mcp_server.McpRequestError):
			gf_mcp_server.decode_request_bytes(
				json.dumps({
					"jsonrpc": "2.0",
					"method": "ping",
					"params": {"value": "x" * (gf_mcp_server.MAX_MCP_STRING_BYTES + 1)},
				}).encode("utf-8")
			)
		oversized = io.BytesIO(b"x" * (gf_mcp_server.MAX_MCP_REQUEST_BYTES + 1))
		with self.assertRaises(gf_mcp_server.McpRequestError):
			gf_mcp_server.read_request_bytes(oversized)

	def test_each_mcp_request_starts_with_a_fresh_api_cache(self) -> None:
		gf_maintenance._API_CACHE = None
		with mock.patch.object(gf_maintenance, "collect_api_scripts", return_value=[]) as collect:
			gf_mcp_server.handle_message(
				self._tool_request(1, "gf_api_search", {"query": "first"})
			)
			gf_mcp_server.handle_message(
				self._tool_request(2, "gf_api_search", {"query": "second"})
			)
		self.assertEqual(collect.call_count, 2)

	def test_mcp_text_serializer_rejects_non_finite_results(self) -> None:
		with self.assertRaises(ValueError):
			gf_mcp_server.tool_result({"value": float("nan")})

	def test_stdio_server_applies_validation_and_emits_strict_json(self) -> None:
		requests = b"\n".join([
			b'{"jsonrpc":"2.0","id":1,"method":"ping"}',
			b'{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"gf_api_search","arguments":{"query":"x","limit":81}}}',
		]) + b"\n"
		completed = subprocess.run(
			[sys.executable, str(TOOLS_ROOT / "gf_mcp_server.py")],
			input=requests,
			cwd=ROOT,
			capture_output=True,
			check=False,
			timeout=10.0,
		)
		self.assertEqual(completed.returncode, 0, completed.stderr.decode("utf-8"))
		responses = [json.loads(line) for line in completed.stdout.decode("utf-8").splitlines()]
		self.assertEqual(responses[0]["id"], 1)
		self.assertEqual(responses[0]["result"], {})
		self.assertEqual(responses[1]["id"], 2)
		self.assertEqual(responses[1]["error"]["code"], -32602)
		self.assertEqual(completed.stderr, b"")


class WorkspaceExecutionBoundaryTests(unittest.TestCase):
	def test_workspace_snapshot_keeps_only_the_current_live_identity(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			path = Path(temporary_directory) / "value.txt"
			path.write_text("a", encoding="utf-8")
			snapshot = gf_workspace_snapshot.WorkspaceSnapshot(Path(temporary_directory))
			self.assertEqual(snapshot.read_utf8_text_strict(path), "a")
			path.write_text("longer", encoding="utf-8")
			self.assertEqual(snapshot.read_utf8_text_strict(path), "longer")
			self.assertEqual(snapshot.stats()["text_entry_count"], 1)

	def test_read_only_suite_rejects_ending_workspace_drift(self) -> None:
		initial = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "a" * 64,
		}
		ending = {**initial, "dirty": True, "fingerprint": "b" * 64}
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=[initial, ending],
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_check_runners",
			return_value={"docs": lambda: {"ok": True}},
		):
			result = gf_maintenance.run_checks(checks=["docs"], jobs=1)
		self.assertFalse(result["ok"])
		self.assertIn(
			"workspace_snapshot_integrity",
			[item["name"] for item in result["results"]],
		)

	def test_plugin_cfg_uses_the_shared_containment_policy(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			addon_root = root / "addons/gf"
			addon_root.mkdir(parents=True)
			(addon_root / "plugin.cfg").write_text(
				'[plugin]\nname="GF"\nscript="plugin.gd"\n',
				encoding="utf-8",
			)
			(addon_root / "plugin.gd").write_text("@tool\nextends EditorPlugin\n", encoding="utf-8")
			with mock.patch.object(gf_maintenance, "ROOT", root), mock.patch.object(
				gf_maintenance.gf_path_security,
				"path_is_inside",
				return_value=False,
			) as containment:
				report = gf_maintenance.audit_plugin_cfg()
			self.assertFalse(report["script_inside_addon"])
			containment.assert_called_once_with(addon_root, addon_root / "plugin.gd")


if __name__ == "__main__":
	unittest.main()
