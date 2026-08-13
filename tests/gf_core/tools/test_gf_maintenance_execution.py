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


class ValidationShadowIntegrationTests(unittest.TestCase):
	def _workspace_state(self) -> dict[str, object]:
		return {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "a" * 64,
		}

	def _inventory(self) -> dict[str, object]:
		return {
			"schema_version": 1,
			"discovery_contract_version": 1,
			"root": "tests/gf_core",
			"capture_complete": True,
			"entry_count": 4,
			"file_count": 2,
			"method_count": 3,
			"source_bytes": 128,
			"source_manifest_sha256": "b" * 64,
			"test_list_sha256": "c" * 64,
			"inventory_sha256": "d" * 64,
			"files": [],
		}

	def test_default_check_execution_does_not_collect_shadow_inventory(self) -> None:
		workspace_state = self._workspace_state()
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_check_runners",
			return_value={"docs": lambda: {"ok": True}},
		), mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
		) as inventory:
			result = gf_maintenance.run_checks(checks=["docs"], jobs=1)
		self.assertTrue(result["ok"])
		self.assertNotIn("validation_shadow", result)
		inventory.assert_not_called()

	def test_shadow_observes_one_real_execution_but_never_reuses_it(self) -> None:
		workspace_state = self._workspace_state()
		runner = mock.Mock(return_value={"ok": True})
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_check_runners",
			return_value={"docs": runner},
		), mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				validation_shadow=True,
			)
		self.assertTrue(result["ok"])
		runner.assert_called_once_with()
		shadow = result["validation_shadow"]
		self.assertTrue(shadow["report_ok"])
		self.assertFalse(shadow["authoritative"])
		self.assertFalse(shadow["scheduling_effect"])
		self.assertFalse(shadow["reuse_permitted"])
		self.assertEqual(shadow["executed_action_count"], 1)
		self.assertEqual(shadow["execution_observation_count"], 1)
		self.assertEqual(shadow["reused_count"], 0)
		action = shadow["actions"][0]
		self.assertFalse(action["policy"]["declared"])
		material = action["shadow_evidence"]["action_key_material"]
		self.assertFalse(material["input_complete"])
		self.assertIn(
			"inventory_not_bound_to_immutable_snapshot",
			material["unknown_reasons"],
		)
		decision = action["shadow_evidence"]["acceptance_decision"]
		self.assertEqual(decision["decision"], "execute")
		self.assertEqual(decision["acceptance"], "shadow_only")
		self.assertFalse(decision["structurally_reusable_candidate"])

	def test_shadow_inventory_failure_does_not_change_suite_result(self) -> None:
		workspace_state = self._workspace_state()
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_check_runners",
			return_value={"docs": lambda: {"ok": True}},
		), mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			side_effect=RuntimeError("injected inventory failure"),
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				validation_shadow=True,
			)
		self.assertTrue(result["ok"])
		self.assertEqual(len(result["results"]), 1)
		shadow = result["validation_shadow"]
		self.assertFalse(shadow["report_ok"])
		self.assertEqual(
			frozenset(shadow),
			gf_maintenance.VALIDATION_SHADOW_REPORT_FIELDS,
		)
		self.assertEqual(shadow["fallback_decision"], "execute")
		self.assertEqual(shadow["reused_count"], 0)
		self.assertEqual(shadow["errors"], ["shadow_internal_error"])
		self.assertIsNone(shadow["test_inventory"])
		self.assertEqual(len(shadow["report_fingerprint"]), 64)

	def test_shadow_success_and_failure_use_the_same_exact_envelope(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": True,
			"suite": "quick",
			"checks": ["docs"],
			"results": [],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			gf_maintenance.attach_validation_shadow_report(data, workspace_state)
		success = data["validation_shadow"]
		failure = gf_maintenance.make_validation_shadow_failure_report(
			data,
			"inventory_capture_failed",
		)
		self.assertEqual(frozenset(success), frozenset(failure))
		self.assertEqual(
			frozenset(success),
			gf_maintenance.VALIDATION_SHADOW_REPORT_FIELDS,
		)

	def test_shadow_private_deadline_covers_post_inventory_report_work(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": True,
			"suite": "quick",
			"checks": ["docs"],
			"results": [],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		), mock.patch.object(
			gf_maintenance.time,
			"monotonic",
			side_effect=[0.0, 2.0],
		):
			with self.assertRaisesRegex(
				gf_maintenance.ValidationShadowDeadlineError,
				"deadline",
			):
				gf_maintenance.make_validation_shadow_report(
					data,
					workspace_state,
					shadow_deadline_seconds=1.0,
				)

	def test_ordinary_dependency_pass_does_not_change_shadow_action_key(self) -> None:
		workspace_state = self._workspace_state()

		def report(dependency_fingerprint: str) -> dict[str, object]:
			data = {
				"ok": True,
				"suite": "quick",
				"checks": ["docs"],
				"results": [{
					"name": "docs",
					"command": ["python", "check.py"],
					"execution": "in_process",
					"exit_code": 0,
					"timed_out": False,
					"cancelled": False,
					"duration_seconds": 0.1,
					"dependency_fingerprints": {"api": dependency_fingerprint},
					"result_fingerprint": "e" * 64,
				}],
			}
			with mock.patch.object(
				gf_maintenance.gf_validation_test_inventory,
				"collect_test_inventory",
				return_value=self._inventory(),
			):
				return gf_maintenance.make_validation_shadow_report(
					data,
					workspace_state,
				)

		first = report("1" * 64)
		second = report("2" * 64)
		first_evidence = first["actions"][0]["shadow_evidence"]
		second_evidence = second["actions"][0]["shadow_evidence"]
		self.assertEqual(first_evidence["action_key"], second_evidence["action_key"])
		self.assertEqual(
			first_evidence["action_key_material"]["dependency_artifacts"],
			{},
		)

	def test_shadow_failure_never_stringifies_untrusted_exception(self) -> None:
		class HostileError(RuntimeError):
			def __str__(self) -> str:
				raise AssertionError("exception text must not be observed")

		workspace_state = self._workspace_state()
		data = {"suite": "quick", "checks": ["docs"], "results": []}
		with mock.patch.object(
			gf_maintenance,
			"make_validation_shadow_report",
			side_effect=HostileError(),
		):
			gf_maintenance.attach_validation_shadow_report(data, workspace_state)
		shadow = data["validation_shadow"]
		self.assertEqual(shadow["errors"], ["shadow_internal_error"])
		json.dumps(shadow, allow_nan=False)

	def test_initial_workspace_failure_gets_exact_zero_io_shadow_envelope(self) -> None:
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=gf_maintenance.gf_maintenance_check_graph.WorkspaceFingerprintSetupError(
				"fixture failure"
			),
		), mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
		) as inventory:
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				validation_shadow=True,
			)
		self.assertFalse(result["ok"])
		shadow = result["validation_shadow"]
		self.assertEqual(shadow["errors"], ["workspace_fingerprint_setup_failed"])
		self.assertEqual(shadow["execution_observation_count"], 0)
		self.assertIsNone(shadow["test_inventory"])
		inventory.assert_not_called()

	def test_shadow_attaches_only_after_workspace_revalidation_and_result_freeze(self) -> None:
		workspace_state = self._workspace_state()
		events: list[str] = []

		def fingerprint(*_args: object, **_kwargs: object) -> dict[str, object]:
			events.append("workspace_fingerprint")
			return workspace_state

		def attach(
			data: dict[str, object],
			state: dict[str, object],
			**_kwargs: object,
		) -> None:
			events.append("validation_shadow")
			self.assertIs(state, workspace_state)
			self.assertEqual(data["workspace"], workspace_state)
			self.assertIn("workspace_snapshot", data)
			self.assertIn("duration_seconds", data)
			data["validation_shadow"] = {"report_ok": True}

		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=fingerprint,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_check_runners",
			return_value={"docs": lambda: {"ok": True}},
		), mock.patch.object(
			gf_maintenance,
			"attach_validation_shadow_report",
			side_effect=attach,
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				validation_shadow=True,
			)

		self.assertTrue(result["ok"])
		self.assertEqual(
			events,
			[
				"workspace_fingerprint",
				"workspace_fingerprint",
				"validation_shadow",
			],
		)

	def test_shadow_does_not_invent_evidence_for_blocked_action(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": False,
			"suite": "quick",
			"checks": ["gut"],
			"results": [{
				"name": "gut",
				"command": ["godot"],
				"execution": "blocked",
				"exit_code": 125,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.0,
				"dependency_fingerprints": {},
			}],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			gf_maintenance.attach_validation_shadow_report(data, workspace_state)
		shadow = data["validation_shadow"]
		self.assertEqual(shadow["executed_action_count"], 0)
		self.assertEqual(shadow["non_execution_action_count"], 1)
		self.assertEqual(
			shadow["actions"][0]["shadow_evidence"]["evidence"],
			[],
		)
		decision = shadow["actions"][0]["shadow_evidence"]["acceptance_decision"]
		self.assertEqual(decision["decision"], "execute")
		self.assertEqual(decision["reason_code"], "no_evidence")

	def test_parallel_occurrences_are_all_observed_and_unproved_equivalence_conflicts(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": True,
			"suite": "full",
			"checks": ["godot_import"],
			"results": [{
				"name": "godot_import",
				"command": ["godot", "--editor", "--quit"],
				"parallel_occurrences": [
					{
						"shard": "gut",
						"execution": "subprocess",
						"exit_code": 0,
						"timed_out": False,
						"cancelled": False,
						"duration_seconds": 1.0,
						"result_fingerprint": "e" * 64,
					},
					{
						"shard": "lsp",
						"execution": "subprocess",
						"exit_code": 0,
						"timed_out": False,
						"cancelled": False,
						"duration_seconds": 2.0,
						"result_fingerprint": "f" * 64,
					},
				],
			}],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			gf_maintenance.attach_validation_shadow_report(data, workspace_state)
		shadow = data["validation_shadow"]
		self.assertEqual(shadow["executed_action_count"], 1)
		self.assertEqual(shadow["execution_observation_count"], 2)
		evidence_report = shadow["actions"][0]["shadow_evidence"]
		self.assertEqual(evidence_report["execution_summary"]["executed"], 2)
		self.assertTrue(evidence_report["conflict"]["detected"])
		self.assertFalse(evidence_report["conflict"]["comparison_complete"])

	def test_parallel_public_occurrences_do_not_leak_shadow_execution_field(self) -> None:
		occurrences = [("gut", {
			"execution": "subprocess",
			"exit_code": 0,
			"timed_out": False,
			"cancelled": False,
			"duration_seconds": 1.0,
			"input_fingerprint": "e" * 64,
			"result_fingerprint": "f" * 64,
		})]
		public = gf_maintenance.serialize_parallel_occurrences(
			occurrences,
			include_execution=False,
		)
		shadow = gf_maintenance.serialize_parallel_occurrences(
			occurrences,
			include_execution=True,
		)
		self.assertNotIn("execution", public[0])
		self.assertEqual(shadow[0]["execution"], "subprocess")
		self.assertEqual(set(shadow[0]) - {"execution"}, set(public[0]))

	def test_shadow_timeout_is_failed_evidence_and_never_a_reusable_candidate(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": False,
			"suite": "quick",
			"checks": ["docs"],
			"results": [{
				"name": "docs",
				"command": ["python", "check.py"],
				"execution": "subprocess",
				"exit_code": 124,
				"timed_out": True,
				"cancelled": False,
				"duration_seconds": 1.0,
				"dependency_fingerprints": {},
				"result_fingerprint": "e" * 64,
			}],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			gf_maintenance.attach_validation_shadow_report(data, workspace_state)
		action = data["validation_shadow"]["actions"][0]["shadow_evidence"]
		evidence_record = action["evidence"][0]
		self.assertEqual(evidence_record["outcome"], "failed")
		self.assertTrue(evidence_record["timed_out"])
		self.assertFalse(evidence_record["structurally_reusable_candidate"])
		self.assertEqual(evidence_record["evidence_authority"], "self_asserted")
		self.assertIsNone(evidence_record["warning_count"])
		self.assertEqual(action["acceptance_decision"]["decision"], "execute")

	def test_shadow_rendering_adds_only_a_compact_summary(self) -> None:
		base = {
			"suite": "quick",
			"ok": True,
			"duration_seconds": 0.1,
			"results": [],
		}
		self.assertNotIn(
			"validation_shadow:",
			gf_maintenance_rendering.render_checks_text(base),
		)
		with_shadow = {
			**base,
			"validation_shadow": {
				"report_ok": True,
				"authoritative": False,
				"expected_action_count": 1,
				"executed_action_count": 1,
				"execution_observation_count": 1,
				"reused_count": 0,
				"collection_duration_seconds": 0.01,
				"test_inventory": {"file_count": 2, "method_count": 3},
			},
		}
		rendered = gf_maintenance_rendering.render_checks_text(with_shadow)
		self.assertIn("validation_shadow: report_ok=True", rendered)
		self.assertIn("executed=1 observations=1 reused=0", rendered)
		self.assertNotIn("action_key", rendered)

	def test_parallel_child_command_never_inherits_validation_shadow(self) -> None:
		plan = gf_maintenance.ParallelCheckShardPlan("framework-static", ("docs",))
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_maintenance,
			"parallel_shard_environment",
			return_value=({}, Path(temporary_directory) / "user"),
		):
			shard, _report_path = gf_maintenance.make_parallel_full_shard(
				plan,
				Path(temporary_directory),
				private_environment_root=Path(temporary_directory) / "private",
				timeout_seconds=None,
				suite_deadline=None,
				fail_fast=False,
				package_artifact_manifest="",
				package_artifact_manifest_sha256="",
			)
		self.assertNotIn("--validation-shadow", shard.command)


class AffectedAnalysisIntegrationTests(unittest.TestCase):
	def _workspace_state(self) -> dict[str, object]:
		return {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "a" * 64,
		}

	def _analysis(self, base_revision: str = "HEAD") -> dict[str, object]:
		return gf_maintenance.gf_validation_inputs.make_affected_analysis_failure(
			("docs",),
			base_revision=base_revision,
			error_code="affected_internal_error",
			explain=True,
		)

	def test_default_check_execution_does_not_run_affected_analysis(self) -> None:
		workspace_state = self._workspace_state()
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_check_runners",
			return_value={"docs": lambda: {"ok": True}},
		), mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
		) as analyze:
			result = gf_maintenance.run_checks(checks=["docs"], jobs=1)
		self.assertTrue(result["ok"])
		self.assertNotIn("affected_analysis", result)
		analyze.assert_not_called()

	def test_affected_analysis_attaches_after_execution_and_workspace_freeze(self) -> None:
		workspace_state = self._workspace_state()
		events: list[str] = []

		def fingerprint(*_args: object, **_kwargs: object) -> dict[str, object]:
			events.append("workspace_fingerprint")
			return workspace_state

		def runner() -> dict[str, object]:
			events.append("execute")
			return {"ok": True}

		def analyze(*args: object, **kwargs: object) -> dict[str, object]:
			events.append("affected_analysis")
			self.assertEqual(args[:2], (gf_maintenance.ROOT, ("docs",)))
			self.assertEqual(kwargs["base_revision"], "fixture-base")
			self.assertTrue(kwargs["explain"])
			self.assertIs(
				kwargs["input_specs"],
				gf_maintenance.gf_validation_inputs.DEFAULT_AFFECTED_INPUT_SPECS,
			)
			self.assertGreater(float(kwargs["deadline_seconds"]), time.monotonic())
			return self._analysis("fixture-base")

		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=fingerprint,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_check_runners",
			return_value={"docs": runner},
		), mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
			side_effect=analyze,
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				affected=True,
				affected_base="fixture-base",
				affected_explain=True,
			)

		self.assertTrue(result["ok"])
		self.assertEqual(
			events,
			[
				"workspace_fingerprint",
				"execute",
				"workspace_fingerprint",
				"affected_analysis",
			],
		)
		analysis = result["affected_analysis"]
		self.assertFalse(analysis["authoritative"])
		self.assertFalse(analysis["scheduling_effect"])
		self.assertEqual(analysis["affected_skip_count"], 0)
		self.assertEqual(analysis["cache_read_count"], 0)
		self.assertEqual(analysis["cache_write_count"], 0)
		self.assertEqual(analysis["reused_count"], 0)

	def test_first_affected_specs_cover_the_exact_maintenance_inputs(self) -> None:
		specs = {
			spec.check_name: spec
			for spec in gf_maintenance.gf_validation_inputs.DEFAULT_AFFECTED_INPUT_SPECS
		}
		self.assertEqual(
			set(specs),
			{
				"package_user_dependency_boundary",
				"public_api_boundary",
				"public_docs_boundary",
			},
		)
		self.assertTrue(specs["public_docs_boundary"].matches_source_path("README.md"))
		self.assertTrue(
			specs["public_docs_boundary"].matches_source_path("docs/zh/guide.md")
		)
		self.assertFalse(
			specs["public_docs_boundary"].matches_source_path(
				"docs/zh/reference/api/classes/GF.md"
			)
		)
		self.assertTrue(
			specs["public_api_boundary"].matches_source_path("addons/gf/value.gd")
		)
		self.assertTrue(
			specs["package_user_dependency_boundary"].matches_source_path(
				"addons/gf/kernel/package/installer.gd"
			)
		)
		self.assertFalse(
			specs["package_user_dependency_boundary"].matches_source_path(
				"addons/gf/kernel/unrelated.gd"
			)
		)

	def test_affected_failure_is_unknown_execute_and_cannot_change_success(self) -> None:
		workspace_state = self._workspace_state()
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_check_runners",
			return_value={"docs": lambda: {"ok": True}},
		), mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
			side_effect=RuntimeError("untrusted analyzer failure"),
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				affected=True,
			)
		self.assertTrue(result["ok"])
		analysis = result["affected_analysis"]
		self.assertFalse(analysis["report_ok"])
		self.assertEqual(analysis["unknown_count"], 1)
		self.assertEqual(analysis["fallback_decision"], "execute")
		self.assertEqual(analysis["errors"], ["affected_internal_error"])

	def test_affected_failure_never_stringifies_analyzer_exception(self) -> None:
		class HostileError(RuntimeError):
			def __str__(self) -> str:
				raise AssertionError("exception text must not be observed")

		data = {"checks": ["docs"]}
		with mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
			side_effect=HostileError(),
		):
			gf_maintenance.attach_affected_analysis_report(
				data,
				base_revision="HEAD",
				explain=False,
			)
		self.assertEqual(
			data["affected_analysis"]["errors"],
			["affected_internal_error"],
		)
		json.dumps(data["affected_analysis"], allow_nan=False)

	def test_malformed_affected_report_is_replaced_by_exact_fallback(self) -> None:
		data = {"checks": ["docs"]}
		with mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
			return_value={"report_ok": True, "scheduling_effect": True},
		):
			gf_maintenance.attach_affected_analysis_report(
				data,
				base_revision="HEAD",
				explain=False,
			)
		analysis = data["affected_analysis"]
		self.assertEqual(
			frozenset(analysis),
			gf_maintenance.gf_validation_inputs.AFFECTED_ANALYSIS_REPORT_FIELDS,
		)
		self.assertFalse(analysis["report_ok"])
		self.assertFalse(analysis["scheduling_effect"])
		self.assertEqual(analysis["errors"], ["affected_internal_error"])

	def test_initial_workspace_failure_uses_zero_io_affected_fallback(self) -> None:
		with mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=gf_maintenance.gf_maintenance_check_graph.WorkspaceFingerprintSetupError(
				"fixture failure"
			),
		), mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
		) as analyze:
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				affected=True,
			)
		self.assertFalse(result["ok"])
		analysis = result["affected_analysis"]
		self.assertFalse(analysis["report_ok"])
		self.assertEqual(analysis["unknown_count"], 1)
		self.assertEqual(analysis["execute_count"], 1)
		self.assertEqual(analysis["errors"], ["affected_internal_error"])
		analyze.assert_not_called()

	def test_explain_requires_affected_before_any_check_runs(self) -> None:
		completed = subprocess.run(
			[
				sys.executable,
				str(TOOLS_ROOT / "gf_maintenance.py"),
				"check",
				"--check",
				"docs",
				"--explain",
				"--json",
			],
			cwd=ROOT,
			capture_output=True,
			check=False,
			timeout=10.0,
		)
		self.assertEqual(completed.returncode, 2)
		self.assertIn(b"--explain requires --affected", completed.stderr)

	def test_affected_rendering_is_compact_and_does_not_emit_reasons(self) -> None:
		data = {
			"suite": "quick",
			"ok": True,
			"duration_seconds": 0.1,
			"results": [],
			"affected_analysis": {
				"report_ok": True,
				"authoritative": False,
				"check_count": 3,
				"affected_count": 1,
				"unaffected_count": 1,
				"unknown_count": 1,
				"execute_count": 3,
				"affected_skip_count": 0,
				"reused_count": 0,
				"checks": [{"reasons": ["secret detail"]}],
			},
		}
		rendered = gf_maintenance_rendering.render_checks_text(data)
		self.assertIn("affected_analysis: report_ok=True", rendered)
		self.assertIn("affected=1 unaffected=1 unknown=1", rendered)
		self.assertIn("execute=3 skipped=0 reused=0", rendered)
		self.assertNotIn("secret detail", rendered)

	def test_parallel_child_command_never_inherits_affected_flags(self) -> None:
		plan = gf_maintenance.ParallelCheckShardPlan("framework-static", ("docs",))
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_maintenance,
			"parallel_shard_environment",
			return_value=({}, Path(temporary_directory) / "user"),
		):
			shard, _report_path = gf_maintenance.make_parallel_full_shard(
				plan,
				Path(temporary_directory),
				private_environment_root=Path(temporary_directory) / "private",
				timeout_seconds=None,
				suite_deadline=None,
				fail_fast=False,
				package_artifact_manifest="",
				package_artifact_manifest_sha256="",
			)
		self.assertNotIn("--affected", shard.command)
		self.assertNotIn("--explain", shard.command)
		self.assertNotIn("--affected-base", shard.command)


if __name__ == "__main__":
	unittest.main()
