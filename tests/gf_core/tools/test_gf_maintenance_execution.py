#!/usr/bin/env python3
"""Focused behavioral tests for GF maintenance execution/protocol boundaries."""

from __future__ import annotations

import contextlib
import concurrent.futures
import copy
import inspect
import io
import json
import math
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gdscript_lsp_diagnostics
import gf_gut_lifecycle_smoke
import gf_maintenance
import gf_maintenance_rendering
import gf_mcp_server
import gf_workspace_snapshot


def _remove_directory_link_fixture(path: Path) -> None:
	if not os.path.lexists(path):
		return
	if os.name == "nt":
		os.rmdir(path)
	else:
		path.unlink()


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


class GutLifecycleSmokeBoundaryTests(unittest.TestCase):
	def test_structured_no_child_start_remains_an_ordinary_scenario_failure(self) -> None:
		original = FileNotFoundError("fixture missing Godot")
		start_error = gf_maintenance.gf_process_supervisor.SupervisedProcessStartError(
			original
		)
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_gut_lifecycle_smoke,
			"LOG_ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"run_supervised_process",
			side_effect=start_error,
		):
			result = gf_gut_lifecycle_smoke.run_scenario(
				"fixture-godot",
				gf_gut_lifecycle_smoke.SCENARIOS[0],
			)
		self.assertFalse(result.ok)
		self.assertIn("before a child was created", result.issues[0])

	def test_structured_start_diagnostics_ignore_hostile_string(self) -> None:
		class HostileMissing(FileNotFoundError):
			def __str__(self) -> str:
				raise SystemExit("fixture hostile start-error text")

		original = HostileMissing("fixture missing Godot")
		start_error = gf_maintenance.gf_process_supervisor.SupervisedProcessStartError(
			original
		)
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_gut_lifecycle_smoke,
			"LOG_ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"run_supervised_process",
			side_effect=start_error,
		):
			result = gf_gut_lifecycle_smoke.run_scenario(
				"fixture-godot",
				gf_gut_lifecycle_smoke.SCENARIOS[0],
			)
		self.assertFalse(result.ok)
		self.assertIn("detail unavailable", result.issues[0])

	def test_unclassified_supervisor_failure_escapes_with_boundary_debt(self) -> None:
		original = RuntimeError("fixture supervisor failure")
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_gut_lifecycle_smoke,
			"LOG_ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"run_supervised_process",
			side_effect=original,
		):
			with self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
			) as raised:
				gf_gut_lifecycle_smoke.run_scenario(
					"fixture-godot",
					gf_gut_lifecycle_smoke.SCENARIOS[0],
				)
		self.assertIs(raised.exception.__cause__, original)

	def test_returned_unproved_scenario_boundary_is_rejected(self) -> None:
		unproved = gf_maintenance.gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=123,
			process_boundary_quiescent=False,
		)
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_gut_lifecycle_smoke,
			"LOG_ROOT",
			Path(temporary_directory),
		), mock.patch.object(
			gf_gut_lifecycle_smoke,
			"run_supervised_process",
			return_value=unproved,
		):
			with self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
			):
				gf_gut_lifecycle_smoke.run_scenario(
					"fixture-godot",
					gf_gut_lifecycle_smoke.SCENARIOS[0],
				)


class CorePluginBootstrapSmokeTests(unittest.TestCase):
	def test_translation_preview_smoke_uses_a_real_display_on_linux(self) -> None:
		with mock.patch.object(
			gf_maintenance.sys,
			"platform",
			"linux",
		), mock.patch.object(
			gf_maintenance,
			"resolve_godot_executable",
			return_value="/opt/godot",
		), mock.patch.object(
			gf_maintenance.shutil,
			"which",
			return_value="/usr/bin/xvfb-run",
		):
			command = gf_maintenance.make_core_plugin_bootstrap_smoke_command(
				Path("/tmp/project"),
				Path("/tmp/godot.log"),
				"resource_preview_translation",
			)

		self.assertEqual(command[0], "/usr/bin/xvfb-run")
		self.assertIn("/opt/godot", command)
		self.assertIn("--display-driver", command)
		self.assertIn("x11", command)
		self.assertNotIn("--headless", command)

	def test_translation_preview_smoke_uses_resolved_godot_on_desktop_platforms(self) -> None:
		for platform_name in ("darwin", "win32"):
			with self.subTest(platform=platform_name), mock.patch.object(
				gf_maintenance.sys,
				"platform",
				platform_name,
			), mock.patch.object(
				gf_maintenance,
				"resolve_godot_executable",
				return_value="/opt/godot",
			), mock.patch.object(
				gf_maintenance.shutil,
				"which",
			) as which_mock:
				command = gf_maintenance.make_core_plugin_bootstrap_smoke_command(
					Path("/tmp/project"),
					Path("/tmp/godot.log"),
					"resource_preview_translation",
				)

			self.assertEqual(command[0], "/opt/godot")
			self.assertIn("--editor", command)
			self.assertNotIn("--headless", command)
			which_mock.assert_not_called()

	def test_translation_preview_smoke_fails_closed_without_xvfb(self) -> None:
		with mock.patch.object(
			gf_maintenance.sys,
			"platform",
			"linux",
		), mock.patch.object(
			gf_maintenance,
			"resolve_godot_executable",
			return_value="/opt/godot",
		), mock.patch.object(
			gf_maintenance.shutil,
			"which",
			return_value=None,
		):
			with self.assertRaises(
				gf_maintenance.CorePluginBootstrapDisplayDependencyError
			):
				gf_maintenance.make_core_plugin_bootstrap_smoke_command(
					Path("/tmp/project"),
					Path("/tmp/godot.log"),
					"resource_preview_translation",
				)

	def test_translation_preview_smoke_reports_missing_display_dependency(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_maintenance,
			"prepare_core_plugin_bootstrap_smoke_project",
		), mock.patch.object(
			gf_maintenance,
			"make_core_plugin_bootstrap_smoke_command",
			side_effect=gf_maintenance.CorePluginBootstrapDisplayDependencyError(
				"xvfb-run missing"
			),
		):
			issues: list[dict[str, object]] = []
			result = gf_maintenance.run_core_plugin_bootstrap_smoke_scenario(
				Path(temporary_directory),
				"resource_preview_translation",
				issues,
			)

		self.assertFalse(result["ok"])
		self.assertEqual(
			[item["kind"] for item in issues],
			["core_plugin_bootstrap_smoke_display_dependency_missing"],
		)
		self.assertIn("display dependency", str(issues[0]["message"]))

	def test_translation_preview_smoke_isolates_platform_user_directories(self) -> None:
		platform_cases = [
			("nt", "win32", ("APPDATA", "LOCALAPPDATA", "TMPDIR", "TEMP", "TMP")),
			("posix", "darwin", ("HOME", "TMPDIR", "TEMP", "TMP")),
			(
				"posix",
				"linux",
				(
					"HOME",
					"XDG_DATA_HOME",
					"XDG_CONFIG_HOME",
					"XDG_CACHE_HOME",
					"TMPDIR",
					"TEMP",
					"TMP",
				),
			),
		]
		with tempfile.TemporaryDirectory() as temporary_directory:
			temp_root = Path(temporary_directory)
			for os_name, platform_name, isolated_fields in platform_cases:
				original_environment = dict(gf_maintenance.os.environ)
				with self.subTest(platform=platform_name), mock.patch.object(
					gf_maintenance.os,
					"name",
					os_name,
				), mock.patch.object(
					gf_maintenance.sys,
					"platform",
					platform_name,
				), mock.patch.dict(
					gf_maintenance.os.environ,
					{"GODOT_USER_HOME": "unsafe", "HOME": "host-home"},
				):
					host_environment = dict(gf_maintenance.os.environ)
					environment = gf_maintenance.make_core_plugin_bootstrap_smoke_environment(
						temp_root,
						"resource_preview_translation",
					)
					self.assertEqual(dict(gf_maintenance.os.environ), host_environment)

				self.assertIsNotNone(environment)
				assert environment is not None
				self.assertNotIn("GODOT_USER_HOME", environment)
				self.assertEqual(dict(gf_maintenance.os.environ), original_environment)
				isolation_root = temp_root / "resource_preview_translation" / "user"
				prefix = f"{isolation_root}{os.sep}"
				for field_name in isolated_fields:
					self.assertTrue(
						environment[field_name].startswith(prefix),
						f"{platform_name} {field_name} should stay inside the smoke root",
					)

	def test_translation_preview_smoke_rejects_source_load_errors(self) -> None:
		clean_issues: list[dict[str, object]] = []
		gf_maintenance.validate_resource_preview_translation_smoke_output(
			"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
			"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
			"resource_preview_translation",
			clean_issues,
		)
		self.assertEqual(clean_issues, [])

		failed_issues: list[dict[str, object]] = []
		gf_maintenance.validate_resource_preview_translation_smoke_output(
			(
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK\n"
				"ERROR: Failed loading resource: res://preview_translation.csv"
			),
			"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
			"resource_preview_translation",
			failed_issues,
		)
		self.assertEqual(
			[item["kind"] for item in failed_issues],
			["core_plugin_bootstrap_smoke_resource_preview_source_loaded"],
		)

		callback_cases = [
			("", "", "missing success marker"),
			(
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK\n"
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK\n"
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
				"duplicate success marker",
			),
			(
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_FAILED: injected",
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
				"failure marker",
			),
		]
		for combined_output, log_text, case_name in callback_cases:
			with self.subTest(case=case_name):
				callback_issues: list[dict[str, object]] = []
				gf_maintenance.validate_resource_preview_translation_smoke_output(
					combined_output,
					log_text,
					"resource_preview_translation",
					callback_issues,
				)
				self.assertIn(
					"core_plugin_bootstrap_smoke_resource_preview_callback_failed",
					[item["kind"] for item in callback_issues],
				)

		null_translation_issues: list[dict[str, object]] = []
		gf_maintenance.validate_resource_preview_translation_smoke_output(
			(
				"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK\n"
				'ERROR: Parameter "p_translation" is null.'
			),
			"GF_RESOURCE_PREVIEW_TRANSLATION_EDITOR_SMOKE_OK",
			"resource_preview_translation",
			null_translation_issues,
		)
		self.assertEqual(
			[item["kind"] for item in null_translation_issues],
			["core_plugin_bootstrap_smoke_resource_preview_source_loaded"],
		)


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


class GutShardPlanIntegrationTests(unittest.TestCase):
	OBSERVATION_NONCE = "a" * 64
	INVENTORY = (
		"res://tests/gf_core/maintenance/test_alpha.gd",
		"res://tests/gf_core/kernel/test_beta.gd",
	)
	MANIFEST = {
		"schema_version": 1,
		"inventory_root": "res://tests/gf_core",
		"balancing_basis": "bootstrap_unweighted",
		"shards": [
			{
				"name": "gut-contracts",
				"role": "contracts",
				"scripts": [INVENTORY[0]],
			},
			{
				"name": "gut-lane-a",
				"role": "lane",
				"scripts": [INVENTORY[1]],
			},
		],
	}

	def _prepared_output(self) -> mock.Mock:
		invocation_directory = (
			ROOT / "build/gut-sharding" / self.OBSERVATION_NONCE
		)
		return mock.Mock(
			path=invocation_directory / "gut-authoritative.xml",
			provenance_path=(
				invocation_directory / "gut-authoritative-provenance.json"
			),
			nonce=self.OBSERVATION_NONCE,
			invocation_directory=invocation_directory,
		)

	def _manifest_patches(self) -> tuple[mock._patch, mock._patch, mock._patch]:
		return (
			mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"discover_gut_test_scripts",
				return_value=self.INVENTORY,
			),
			mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"load_and_validate_manifest",
				return_value=self.MANIFEST,
			),
			mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"canonical_digest",
				return_value="a" * 64,
			),
		)

	def _observation_report(self) -> dict[str, object]:
		return {
			"schema_version": 1,
			"observation_only": True,
			"execution_changed": False,
			"skip_count": 0,
			"reuse_count": 0,
			"shards": [
				{
					"name": "gut-contracts",
					"role": "contracts",
					"script_count": 1,
					"test_count": 2,
					"duration_seconds": 1.0,
				},
				{
					"name": "gut-lane-a",
					"role": "lane",
					"script_count": 1,
					"test_count": 2,
					"duration_seconds": 2.0,
				},
			],
		}

	def test_manifest_only_mode_never_runs_or_mutates_authoritative_gut(self) -> None:
		canonical_gut = list(gf_maintenance.CHECK_DEFINITIONS["gut"])
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"run_command",
		) as run_command:
			report = gf_maintenance.gut_shard_plan()
		self.assertTrue(report["ok"])
		self.assertEqual(report["mode"], "manifest_only")
		self.assertFalse(report["execution"]["performed"])
		self.assertEqual(report["execution"]["gut_run_count"], 0)
		self.assertEqual(
			[
				report["observation_policy"]["skip_count"],
				report["observation_policy"]["cache_read_count"],
				report["observation_policy"]["cache_write_count"],
				report["observation_policy"]["reuse_count"],
			],
			[0, 0, 0, 0],
		)
		self.assertEqual(gf_maintenance.CHECK_DEFINITIONS["gut"], canonical_gut)
		run_command.assert_not_called()

	def test_existing_junit_is_diagnostic_only_and_rejected_as_observation(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		junit_report = {
			"input_complete": False,
			"script_count": 2,
			"test_count": 4,
			"scripts": [],
		}
		observed_identity: tuple[int, int, int, int, int, int] | None = None
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			junit_path = fixture_root / "build/gut-sharding/existing.xml"
			junit_path.parent.mkdir(parents=True)
			junit_path.write_text("fixture", encoding="utf-8")
			observed_identity = (
				gf_maintenance.gf_gut_sharding.stable_file_identity(junit_path.lstat())
			)
			with discover_patch, manifest_patch, digest_patch, mock.patch.object(
				gf_maintenance,
				"ROOT",
				fixture_root,
			), mock.patch.object(
				gf_maintenance,
				"validate_gut_shard_junit_input_path",
				return_value=junit_path,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"parse_gut_junit_xml",
				return_value=junit_report,
			) as parse_junit, mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"build_observation_report",
			) as build_observation, mock.patch.object(
				gf_maintenance,
				"run_command",
			) as run_command:
				report = gf_maintenance.gut_shard_plan(
					junit_path="build/gut-sharding/existing.xml"
				)
		self.assertFalse(report["ok"])
		self.assertEqual(report["junit"], junit_report)
		self.assertNotIn("observation", report)
		self.assertEqual(
			[item["kind"] for item in report["issues"]],
			["gut_shard_observation_junit_rejected"],
		)
		self.assertEqual(parse_junit.call_args.args, (junit_path,))
		self.assertEqual(parse_junit.call_args.kwargs["expected_scripts"], self.INVENTORY)
		self.assertEqual(
			parse_junit.call_args.kwargs["expected_file_identity"],
			observed_identity,
		)
		self.assertNotIn("trusted_unfiltered_run", parse_junit.call_args.kwargs)
		self.assertNotIn("provenance_path", parse_junit.call_args.kwargs)
		build_observation.assert_not_called()
		run_command.assert_not_called()

	def test_explicit_run_executes_import_and_authoritative_gut_once(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		canonical_gut = list(gf_maintenance.CHECK_DEFINITIONS["gut"])
		prepared_output = self._prepared_output()
		junit_output = prepared_output.path
		import_result = gf_maintenance.CommandResult(
			name="godot_import",
			command=list(gf_maintenance.CHECK_DEFINITIONS["godot_import"]),
			exit_code=0,
			stdout="",
			stderr="",
		)
		gut_result = gf_maintenance.CommandResult(
			name="gut",
			command=canonical_gut,
			exit_code=0,
			stdout="",
			stderr="",
			gut_lifecycle_report={"ok": True},
		)
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=prepared_output,
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=[import_result, gut_result],
		) as run_command, mock.patch.object(
			gf_maintenance,
			"parse_published_gut_shard_junit",
			return_value={"input_complete": True, "script_count": 2, "scripts": []},
		) as parse_junit, mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"build_observation_report",
			return_value=self._observation_report(),
		) as build_observation:
			report = gf_maintenance.gut_shard_plan(run_gut=True)
		self.assertTrue(report["ok"])
		self.assertEqual(report["execution"]["gut_run_count"], 1)
		self.assertTrue(report["execution"]["result_accepted"])
		self.assertEqual(run_command.call_count, 2)
		self.assertEqual(run_command.call_args_list[0].args[0], "godot_import")
		self.assertNotIn("environment", run_command.call_args_list[0].kwargs)
		gut_call = run_command.call_args_list[1]
		self.assertEqual(gut_call.args[0], "gut")
		self.assertEqual(
			gut_call.kwargs["environment"][
				gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT
			],
			self.OBSERVATION_NONCE,
		)
		self.assertEqual(
			gut_call.kwargs["environment"][
				gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT
			],
			(
				"res://build/gut-sharding/"
				f"{self.OBSERVATION_NONCE}/gut-authoritative-provenance.json"
			),
		)
		self.assertEqual(
			gut_call.args[1][:-1],
			gf_maintenance.gut_shard_observation_command(
				canonical_gut,
				self.OBSERVATION_NONCE,
				"gut",
			),
		)
		self.assertEqual(
			gut_call.args[1][-1:],
			[
				f"-gjunit_xml_file={junit_output.as_posix()}",
			],
		)
		self.assertEqual(
			run_command.call_args_list[1].args[2],
			gf_maintenance.GUT_SHARD_OBSERVATION_TIMEOUT_SECONDS,
		)
		self.assertEqual(gf_maintenance.CHECK_DEFINITIONS["gut"], canonical_gut)
		parse_junit.assert_called_once_with(
			prepared_output,
			self.INVENTORY,
		)
		build_observation.assert_called_once()
		self.assertTrue(report["observation_policy"]["writes_ignored_state"])
		self.assertEqual(
			report["execution"]["junit_path"],
			f"build/gut-sharding/{self.OBSERVATION_NONCE}/gut-authoritative.xml",
		)
		self.assertEqual(
			report["execution"]["provenance_path"],
			(
				f"build/gut-sharding/{self.OBSERVATION_NONCE}/"
				"gut-authoritative-provenance.json"
			),
		)

	def test_authoritative_gut_command_rejects_filtered_missing_or_duplicate_flags(self) -> None:
		canonical_gut = list(gf_maintenance.CHECK_DEFINITIONS["gut"])
		invalid_commands = {
			"filtered_script": [
				*canonical_gut,
				"-gtest=res://tests/gf_core/kernel/test_beta.gd",
			],
			"filtered_testcase": [*canonical_gut, "-gunit_test_name=test_selected"],
			"filtered_inner_class": [*canonical_gut, "-ginner_class=TestSelected"],
			"filtered_name": [*canonical_gut, "-gselect=selected"],
			"filtered_config": [
				(
					"-gconfig=res://build/gut-sharding/filtered.json"
					if argument == gf_maintenance.GUT_SHARD_CONFIG_DISABLED_ARGUMENT
					else argument
				)
				for argument in canonical_gut
			],
			"missing_recursive_flag": [
				argument
				for argument in canonical_gut
				if argument != "-ginclude_subdirs"
			],
			"missing_directory_flag": [
				argument
				for argument in canonical_gut
				if argument != gf_maintenance.GUT_SHARD_FULL_DIRECTORY_ARGUMENT
			],
			"duplicate_recursive_flag": [*canonical_gut, "-ginclude_subdirs"],
			"duplicate_directory_flag": [
				*canonical_gut,
				gf_maintenance.GUT_SHARD_FULL_DIRECTORY_ARGUMENT,
			],
			"duplicate_managed_log": [
				*canonical_gut,
				"--log-file",
				gf_maintenance.godot_log_path("duplicate"),
			],
			"preexisting_junit_flag": [
				*canonical_gut,
				"-gjunit_xml_file=build/gut-sharding/unowned.xml",
			],
		}
		for case_name, invalid_command in invalid_commands.items():
			with self.subTest(case=case_name), mock.patch.dict(
				gf_maintenance.CHECK_DEFINITIONS,
				{"gut": invalid_command},
			), self.assertRaises(ValueError):
				gf_maintenance.authoritative_gut_shard_observation_command(
					ROOT / "build/gut-sharding" / self.OBSERVATION_NONCE / "gut-authoritative.xml",
					self.OBSERVATION_NONCE,
				)

	def test_run_command_forwards_explicit_observation_environment(self) -> None:
		environment = {
			gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT: (
				self.OBSERVATION_NONCE
			),
			gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT: (
				"res://build/gut-sharding/owned/provenance.json"
			),
		}
		process_result = mock.Mock(
			timed_out=False,
			process_boundary_quiescent=True,
			return_code=0,
			stdout="",
			stderr="",
			duration_seconds=0.1,
			pid=123,
			notes=(),
		)
		expected_result = gf_maintenance.CommandResult(
			name="gut",
			command=["resolved-godot"],
			exit_code=0,
			stdout="",
			stderr="",
		)
		with mock.patch.object(
			gf_maintenance,
			"resolve_godot_command",
			return_value=["resolved-godot"],
		) as resolve_command, mock.patch.object(
			gf_maintenance,
			"prepare_command_log_paths",
			return_value=[],
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=process_result,
		) as run_process, mock.patch.object(
			gf_maintenance,
			"completed_command_result",
			return_value=expected_result,
		):
			result = gf_maintenance.run_command(
				"gut",
				["godot"],
				1200.0,
				environment=environment,
			)

		self.assertIs(result, expected_result)
		resolve_command.assert_called_once_with(
			["godot"],
			environment=environment,
		)
		self.assertIs(run_process.call_args.kwargs["environment"], environment)

	def test_run_command_scrubs_ambient_observation_environment_by_default(self) -> None:
		process_result = mock.Mock(
			timed_out=False,
			process_boundary_quiescent=True,
			return_code=0,
			stdout="",
			stderr="",
			duration_seconds=0.1,
			pid=123,
			notes=(),
		)
		with mock.patch.dict(
			os.environ,
			{
				gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT: (
					self.OBSERVATION_NONCE
				),
				gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT: (
					"res://build/gut-sharding/stale/provenance.json"
				),
			},
		), mock.patch.object(
			gf_maintenance,
			"resolve_godot_command",
			return_value=["resolved-godot"],
		) as resolve_command, mock.patch.object(
			gf_maintenance,
			"prepare_command_log_paths",
			return_value=[],
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=process_result,
		) as run_process:
			gf_maintenance.run_command("gut", ["godot"], 1200.0)

		resolved_environment = resolve_command.call_args.kwargs["environment"]
		process_environment = run_process.call_args.kwargs["environment"]
		for environment in (resolved_environment, process_environment):
			self.assertNotIn(
				gf_maintenance.GUT_SHARD_OBSERVATION_NONCE_ENVIRONMENT,
				environment,
			)
			self.assertNotIn(
				gf_maintenance.GUT_SHARD_OBSERVATION_PATH_ENVIRONMENT,
				environment,
			)

	def test_run_command_maps_proven_start_failures_without_tracebacks(self) -> None:
		cases = (
			(FileNotFoundError("fixture missing"), 127, "command not found"),
			(PermissionError("fixture denied"), 126, "failed to run command"),
		)
		for original, expected_exit, expected_message in cases:
			with self.subTest(error=type(original).__name__), mock.patch.object(
				gf_maintenance,
				"resolve_godot_command",
				return_value=["fixture-command"],
			), mock.patch.object(
				gf_maintenance,
				"prepare_command_log_paths",
				return_value=[],
			), mock.patch.object(
				gf_maintenance,
				"run_supervised_process",
				side_effect=(
					gf_maintenance.gf_process_supervisor.SupervisedProcessStartError(
						original
					)
				),
			):
				result = gf_maintenance.run_command(
					"fixture",
					["fixture-command"],
					10.0,
				)

			self.assertEqual(result.exit_code, expected_exit)
			self.assertFalse(result.timed_out)
			self.assertFalse(result.cancelled)
			self.assertIn(expected_message, result.stderr)
			self.assertNotIn("Traceback", result.stderr)

	def test_run_command_start_diagnostics_ignore_hostile_string(self) -> None:
		class HostileMissing(FileNotFoundError):
			def __str__(self) -> str:
				raise SystemExit("fixture hostile start-error text")

		original = HostileMissing("fixture missing")
		with mock.patch.object(
			gf_maintenance,
			"resolve_godot_command",
			return_value=["fixture-command"],
		), mock.patch.object(
			gf_maintenance,
			"prepare_command_log_paths",
			return_value=[],
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			side_effect=(
				gf_maintenance.gf_process_supervisor.SupervisedProcessStartError(
					original
				)
			),
		):
			result = gf_maintenance.run_command(
				"fixture",
				["fixture-command"],
				10.0,
			)

		self.assertEqual(result.exit_code, 127)
		self.assertIn("detail unavailable", result.stderr)

	def test_run_command_rejects_raw_supervisor_os_errors_without_boundary_proof(self) -> None:
		for original_error in (
			FileNotFoundError("fixture unclassified missing executable"),
			PermissionError("fixture unclassified process failure"),
			RuntimeError("fixture unclassified runtime failure"),
		):
			with self.subTest(error=type(original_error).__name__), mock.patch.object(
				gf_maintenance,
				"resolve_godot_command",
				return_value=["fixture-command"],
			), mock.patch.object(
				gf_maintenance,
				"prepare_command_log_paths",
				return_value=[],
			), mock.patch.object(
				gf_maintenance,
				"run_supervised_process",
				side_effect=original_error,
			):
				with self.assertRaises(
					gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
				) as raised:
					gf_maintenance.run_command(
						"fixture",
						["fixture-command"],
						10.0,
					)
			self.assertIs(raised.exception.__cause__, original_error)
			self.assertTrue(raised.exception.cleanup_debt)

	def test_run_command_rejects_returned_unproved_process_boundary(self) -> None:
		process_result = gf_maintenance.gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=123,
			process_boundary_quiescent=False,
		)
		with mock.patch.object(
			gf_maintenance,
			"resolve_godot_command",
			return_value=["fixture-command"],
		), mock.patch.object(
			gf_maintenance,
			"prepare_command_log_paths",
			return_value=[],
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=process_result,
		):
			with self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
			) as raised:
				gf_maintenance.run_command("fixture", ["fixture-command"], 10.0)
		self.assertTrue(raised.exception.cleanup_debt)

	def test_run_command_gut_timeout_publishes_failed_lifecycle_evidence(self) -> None:
		process_result = mock.Mock(
			timed_out=True,
			process_boundary_quiescent=True,
			return_code=-1,
			stdout="partial GUT output without a lifecycle marker",
			stderr="",
			duration_seconds=600.0,
			pid=123,
			notes=("terminated supervised process tree",),
		)
		with mock.patch.object(
			gf_maintenance,
			"resolve_godot_command",
			return_value=["resolved-godot"],
		), mock.patch.object(
			gf_maintenance,
			"prepare_command_log_paths",
			return_value=[],
		), mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=process_result,
		):
			result = gf_maintenance.run_command("gut", ["godot"], 600.0)

		self.assertEqual(result.exit_code, 124)
		self.assertTrue(result.timed_out)
		self.assertEqual(result.process_exit_code, -1)
		self.assertIsNotNone(result.gut_lifecycle_report)
		assert result.gut_lifecycle_report is not None
		self.assertFalse(result.gut_lifecycle_report["ok"])
		self.assertEqual(result.gut_lifecycle_report["marker_count"], 0)
		self.assertEqual(
			gf_maintenance.validate_gut_lifecycle_report(
				result.gut_lifecycle_report
			),
			"",
		)
		payload = result.to_dict()
		self.assertEqual(payload["exit_code"], 124)
		self.assertTrue(payload["timed_out"])
		self.assertEqual(payload["process_exit_code"], -1)
		self.assertEqual(
			payload["gut_lifecycle_report"],
			result.gut_lifecycle_report,
		)

	def test_import_failure_stops_before_gut_and_junit_parse(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		import_failure = gf_maintenance.CommandResult(
			name="godot_import",
			command=[],
			exit_code=1,
			stdout="",
			stderr="import failed",
		)
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=self._prepared_output(),
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			return_value=import_failure,
		) as run_command, mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"parse_gut_junit_xml",
		) as parse_junit:
			report = gf_maintenance.gut_shard_plan(run_gut=True)
		self.assertFalse(report["ok"])
		self.assertEqual(run_command.call_count, 1)
		self.assertEqual(report["execution"]["gut_run_count"], 0)
		parse_junit.assert_not_called()

	def test_process_boundary_failure_remains_a_closed_observation_report(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=self._prepared_output(),
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=gf_maintenance.WorkspaceSnapshotError(
				"fixture process-boundary cleanup was not proven"
			),
		):
			report = gf_maintenance.gut_shard_plan(run_gut=True)
		self.assertFalse(report["ok"])
		self.assertEqual(
			[item["kind"] for item in report["issues"]],
			["gut_shard_observation_failed"],
		)
		self.assertIn("process-boundary", report["issues"][0]["message"])

	def test_process_boundary_debt_escapes_observation_report(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		boundary_error = (
			gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError(
				"fixture unproved process boundary"
			)
		)
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=self._prepared_output(),
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=boundary_error,
		):
			with self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
			) as raised:
				gf_maintenance.gut_shard_plan(run_gut=True)
		self.assertIs(raised.exception, boundary_error)

	def test_gut_timeout_without_published_junit_remains_a_failed_observation(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		import_result = gf_maintenance.CommandResult(
			name="godot_import",
			command=[],
			exit_code=0,
			stdout="",
			stderr="",
		)
		gut_timeout = gf_maintenance.CommandResult(
			name="gut",
			command=[],
			exit_code=124,
			stdout="",
			stderr="timed out",
			timed_out=True,
			process_exit_code=1,
			notes=["Command timed out after 600s; terminating its process tree."],
			duration_seconds=600.0,
		)
		prepared_output = self._prepared_output()
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=prepared_output,
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			side_effect=[import_result, gut_timeout],
		), mock.patch.object(
			gf_maintenance,
			"parse_published_gut_shard_junit",
			side_effect=gf_maintenance.gf_gut_sharding.GutShardingError(
				"junit_file_unreadable",
				"JUnit input cannot be inspected.",
			),
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"build_observation_report",
		) as build_observation:
			report = gf_maintenance.gut_shard_plan(run_gut=True)

		self.assertFalse(report["ok"])
		self.assertEqual(report["execution"]["gut_run_count"], 1)
		self.assertFalse(report["execution"]["result_accepted"])
		self.assertTrue(report["execution"]["gut"]["timed_out"])
		self.assertEqual(
			[item["kind"] for item in report["issues"]],
			["gut_shard_observation_gut_failed", "junit_file_unreadable"],
		)
		build_observation.assert_not_called()

	def test_gut_success_with_rejected_junit_is_not_accepted(self) -> None:
		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		command_result = gf_maintenance.CommandResult(
			name="command",
			command=[],
			exit_code=0,
			stdout="",
			stderr="",
		)
		prepared_output = self._prepared_output()
		with discover_patch, manifest_patch, digest_patch, mock.patch.object(
			gf_maintenance,
			"prepare_gut_shard_junit_output",
			return_value=prepared_output,
		), mock.patch.object(
			gf_maintenance,
			"run_command",
			return_value=command_result,
		), mock.patch.object(
			gf_maintenance,
			"parse_published_gut_shard_junit",
			return_value={"input_complete": False},
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"build_observation_report",
		) as build_observation:
			report = gf_maintenance.gut_shard_plan(run_gut=True)

		self.assertFalse(report["ok"])
		self.assertEqual(report["execution"]["gut_run_count"], 1)
		self.assertFalse(report["execution"]["result_accepted"])
		self.assertEqual(
			[item["kind"] for item in report["issues"]],
			["gut_shard_observation_junit_rejected"],
		)
		build_observation.assert_not_called()

	def test_invalid_manifest_and_rejected_junit_fail_closed(self) -> None:
		with mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"discover_gut_test_scripts",
			return_value=self.INVENTORY,
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"load_and_validate_manifest",
			side_effect=gf_maintenance.gf_gut_sharding.GutShardingError(
				"manifest_inventory_mismatch",
				"manifest inventory mismatch",
			),
		), mock.patch.object(gf_maintenance, "run_command") as run_command:
			manifest_report = gf_maintenance.gut_shard_plan()
		self.assertFalse(manifest_report["ok"])
		self.assertEqual(manifest_report["issues"][0]["kind"], "manifest_inventory_mismatch")
		run_command.assert_not_called()

		discover_patch, manifest_patch, digest_patch = self._manifest_patches()
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			junit_path = fixture_root / "build/gut-sharding/rejected.xml"
			junit_path.parent.mkdir(parents=True)
			junit_path.write_text("fixture", encoding="utf-8")
			with discover_patch, manifest_patch, digest_patch, mock.patch.object(
				gf_maintenance,
				"ROOT",
				fixture_root,
			), mock.patch.object(
				gf_maintenance,
				"validate_gut_shard_junit_input_path",
				return_value=junit_path,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"parse_gut_junit_xml",
				return_value={"input_complete": False},
			), mock.patch.object(gf_maintenance, "run_command") as run_command:
				junit_report = gf_maintenance.gut_shard_plan(
					junit_path="build/gut-sharding/rejected.xml"
				)
		self.assertFalse(junit_report["ok"])
		self.assertEqual(
			junit_report["issues"][0]["kind"],
			"gut_shard_observation_junit_rejected",
		)
		run_command.assert_not_called()

	def test_junit_read_paths_are_confined_to_ignored_build_tree(self) -> None:
		with self.assertRaises(ValueError):
			gf_maintenance.validate_gut_shard_junit_input_path(
				str(ROOT.parent / "outside.xml"),
			)

	def test_run_output_uses_fresh_invocation_owned_directory_without_unlink(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			observation_root = Path(temporary_directory) / "gut-sharding"
			observation_root.mkdir()
			sentinel = observation_root / "prior-observation.xml"
			sentinel.write_text("must survive", encoding="utf-8")
			with mock.patch.object(
				gf_maintenance,
				"GUT_SHARD_OBSERVATION_ROOT",
				observation_root,
			):
				first = gf_maintenance.prepare_gut_shard_junit_output()
				second = gf_maintenance.prepare_gut_shard_junit_output()

			self.assertNotEqual(first.invocation_directory, second.invocation_directory)
			self.assertRegex(first.nonce, r"[0-9a-f]{64}\Z")
			self.assertRegex(second.nonce, r"[0-9a-f]{64}\Z")
			self.assertEqual(first.path.name, "gut-authoritative.xml")
			self.assertEqual(second.path.name, "gut-authoritative.xml")
			self.assertEqual(
				first.provenance_path.name,
				"gut-authoritative-provenance.json",
			)
			self.assertEqual(
				second.provenance_path.name,
				"gut-authoritative-provenance.json",
			)
			self.assertTrue(first.invocation_directory.is_dir())
			self.assertTrue(second.invocation_directory.is_dir())
			self.assertFalse(first.path.exists())
			self.assertFalse(second.path.exists())
			self.assertFalse(first.provenance_path.exists())
			self.assertFalse(second.provenance_path.exists())
			self.assertEqual(first.invocation_directory.parent, observation_root)
			self.assertEqual(second.invocation_directory.parent, observation_root)
			self.assertEqual(sentinel.read_text(encoding="utf-8"), "must survive")
			self.assertFalse(
				hasattr(gf_maintenance, "remove_stale_gut_shard_junit_output")
			)

	def test_run_output_creation_refuses_existing_invocation_identity(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			observation_root = Path(temporary_directory) / "gut-sharding"
			observation_root.mkdir()
			reused_nonce = "0" * 64
			(observation_root / reused_nonce).mkdir()
			with mock.patch.object(
				gf_maintenance,
				"GUT_SHARD_OBSERVATION_ROOT",
				observation_root,
			), mock.patch.object(
				gf_maintenance.secrets,
				"token_hex",
				return_value=reused_nonce,
			), self.assertRaises(FileExistsError):
				gf_maintenance.prepare_gut_shard_junit_output()

	def test_run_output_creation_rejects_observation_root_identity_change(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			observation_root = Path(temporary_directory) / "gut-sharding"
			with mock.patch.object(
				gf_maintenance,
				"GUT_SHARD_OBSERVATION_ROOT",
				observation_root,
			), mock.patch.object(
				gf_maintenance,
				"same_owned_directory_identity",
				return_value=False,
			), self.assertRaisesRegex(ValueError, "changed while preparing"):
				gf_maintenance.prepare_gut_shard_junit_output()

	def test_published_junit_revalidates_file_identity_after_parse(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			observation_root = Path(temporary_directory) / "gut-sharding"
			with mock.patch.object(
				gf_maintenance,
				"GUT_SHARD_OBSERVATION_ROOT",
				observation_root,
			):
				output = gf_maintenance.prepare_gut_shard_junit_output()
			output.path.write_text("before", encoding="utf-8")
			output.provenance_path.write_text("provenance", encoding="utf-8")

			def replace_during_parse(*_args: object, **_kwargs: object) -> dict[str, object]:
				replacement = output.path.with_name("replacement.xml")
				replacement.write_text("after payload", encoding="utf-8")
				os.replace(replacement, output.path)
				return {"input_complete": True}

			with mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"parse_gut_junit_xml",
				side_effect=replace_during_parse,
			) as parse_junit, self.assertRaisesRegex(ValueError, "changed while parsing"):
				gf_maintenance.parse_published_gut_shard_junit(output, self.INVENTORY)
			self.assertTrue(parse_junit.call_args.kwargs["trusted_unfiltered_run"])
			self.assertEqual(
				parse_junit.call_args.kwargs["provenance_path"],
				output.provenance_path,
			)
			self.assertEqual(
				parse_junit.call_args.kwargs["expected_provenance_nonce"],
				output.nonce,
			)

	def test_published_junit_revalidates_provenance_identity_after_parse(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			observation_root = Path(temporary_directory) / "gut-sharding"
			with mock.patch.object(
				gf_maintenance,
				"GUT_SHARD_OBSERVATION_ROOT",
				observation_root,
			):
				output = gf_maintenance.prepare_gut_shard_junit_output()
			output.path.write_text("junit", encoding="utf-8")
			output.provenance_path.write_text("before", encoding="utf-8")

			def replace_during_parse(*_args: object, **_kwargs: object) -> dict[str, object]:
				replacement = output.provenance_path.with_name("replacement.json")
				replacement.write_text("after payload", encoding="utf-8")
				os.replace(replacement, output.provenance_path)
				return {"input_complete": True}

			with mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"parse_gut_junit_xml",
				side_effect=replace_during_parse,
			), self.assertRaisesRegex(ValueError, "changed while parsing"):
				gf_maintenance.parse_published_gut_shard_junit(output, self.INVENTORY)

	def test_published_junit_rejects_real_root_and_invocation_replacement(self) -> None:
		for replacement_kind in ("root", "invocation"):
			with self.subTest(replacement=replacement_kind), tempfile.TemporaryDirectory() as temporary_directory:
				fixture_root = Path(temporary_directory)
				observation_root = fixture_root / "gut-sharding"
				with mock.patch.object(
					gf_maintenance,
					"GUT_SHARD_OBSERVATION_ROOT",
					observation_root,
				):
					output = gf_maintenance.prepare_gut_shard_junit_output()
				output.path.write_text("before", encoding="utf-8")
				output.provenance_path.write_text("provenance", encoding="utf-8")
				original = (
					output.root.with_name("gut-sharding-original")
					if replacement_kind == "root"
					else output.invocation_directory.with_name(
						f"{output.invocation_directory.name}-original"
					)
				)
				link = output.root if replacement_kind == "root" else output.invocation_directory
				target = fixture_root / f"replacement-{replacement_kind}"

				def replace_directory_during_parse(
					*_args: object,
					**_kwargs: object,
				) -> dict[str, object]:
					link.rename(original)
					if replacement_kind == "root":
						replacement_invocation = target / output.invocation_directory.name
						replacement_invocation.mkdir(parents=True)
						(replacement_invocation / output.path.name).write_text(
							"replacement",
							encoding="utf-8",
						)
					else:
						target.mkdir()
						(target / output.path.name).write_text(
							"replacement",
							encoding="utf-8",
						)
					gf_maintenance.create_directory_link_fixture(target, link)
					return {"input_complete": True}

				try:
					with mock.patch.object(
						gf_maintenance.gf_gut_sharding,
						"parse_gut_junit_xml",
						side_effect=replace_directory_during_parse,
					), self.assertRaises(ValueError):
						gf_maintenance.parse_published_gut_shard_junit(
							output,
							self.INVENTORY,
						)
				finally:
					_remove_directory_link_fixture(link)
					original.rename(link)

	def test_published_junit_rejects_ordinary_root_and_invocation_replacement(self) -> None:
		for replacement_kind in ("root", "invocation"):
			with self.subTest(replacement=replacement_kind), tempfile.TemporaryDirectory() as temporary_directory:
				fixture_root = Path(temporary_directory)
				observation_root = fixture_root / "gut-sharding"
				with mock.patch.object(
					gf_maintenance,
					"GUT_SHARD_OBSERVATION_ROOT",
					observation_root,
				):
					output = gf_maintenance.prepare_gut_shard_junit_output()
				output.path.write_text("before", encoding="utf-8")
				output.provenance_path.write_text("provenance", encoding="utf-8")
				replaced_path = (
					output.root
					if replacement_kind == "root"
					else output.invocation_directory
				)
				original = replaced_path.with_name(f"{replaced_path.name}-original")
				replacement = fixture_root / f"replacement-{replacement_kind}"

				def replace_directory_during_parse(
					*_args: object,
					**_kwargs: object,
				) -> dict[str, object]:
					replaced_path.rename(original)
					if replacement_kind == "root":
						replacement_output = (
							replacement / output.invocation_directory.name / output.path.name
						)
					else:
						replacement_output = replacement / output.path.name
					replacement_output.parent.mkdir(parents=True)
					replacement_output.write_text("replacement", encoding="utf-8")
					replacement.rename(replaced_path)
					return {"input_complete": True}

				with mock.patch.object(
					gf_maintenance.gf_gut_sharding,
					"parse_gut_junit_xml",
					side_effect=replace_directory_during_parse,
				), self.assertRaises(ValueError):
					gf_maintenance.parse_published_gut_shard_junit(
						output,
						self.INVENTORY,
					)

	def test_existing_junit_revalidates_file_identity_after_parse(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			path = fixture_root / "build/gut-sharding/existing.xml"
			path.parent.mkdir(parents=True)
			path.write_text("before", encoding="utf-8")

			def replace_during_parse(*_args: object, **_kwargs: object) -> dict[str, object]:
				replacement = path.with_name("replacement.xml")
				replacement.write_text("after payload", encoding="utf-8")
				os.replace(replacement, path)
				return {"input_complete": True}

			with mock.patch.object(
				gf_maintenance,
				"ROOT",
				fixture_root,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"parse_gut_junit_xml",
				side_effect=replace_during_parse,
			), self.assertRaisesRegex(ValueError, "changed while parsing"):
				gf_maintenance.parse_existing_gut_shard_junit(path, self.INVENTORY)

	def test_existing_junit_rejects_real_parent_directory_replacement(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			parent = fixture_root / "build/gut-sharding"
			path = parent / "existing.xml"
			parent.mkdir(parents=True)
			path.write_text("before", encoding="utf-8")
			original = parent.with_name("gut-sharding-original")
			target = fixture_root / "replacement-parent"

			def replace_parent_during_parse(
				*_args: object,
				**_kwargs: object,
			) -> dict[str, object]:
				parent.rename(original)
				target.mkdir()
				(target / path.name).write_text("replacement", encoding="utf-8")
				gf_maintenance.create_directory_link_fixture(target, parent)
				return {"input_complete": True}

			try:
				with mock.patch.object(
					gf_maintenance,
					"ROOT",
					fixture_root,
				), mock.patch.object(
					gf_maintenance.gf_gut_sharding,
					"parse_gut_junit_xml",
					side_effect=replace_parent_during_parse,
				), self.assertRaises(ValueError):
					gf_maintenance.parse_existing_gut_shard_junit(path, self.INVENTORY)
			finally:
				_remove_directory_link_fixture(parent)
				original.rename(parent)

	def test_existing_junit_rejects_ordinary_build_and_parent_replacement(self) -> None:
		for replacement_kind in ("build", "parent"):
			with self.subTest(replacement=replacement_kind), tempfile.TemporaryDirectory() as temporary_directory:
				fixture_root = Path(temporary_directory)
				build = fixture_root / "build"
				parent = build / "gut-sharding"
				path = parent / "existing.xml"
				parent.mkdir(parents=True)
				path.write_text("before", encoding="utf-8")
				replaced_path = build if replacement_kind == "build" else parent
				original = replaced_path.with_name(f"{replaced_path.name}-original")
				replacement = fixture_root / f"replacement-{replacement_kind}"

				def replace_directory_during_parse(
					*_args: object,
					**_kwargs: object,
				) -> dict[str, object]:
					replaced_path.rename(original)
					replacement_output = (
						replacement / "gut-sharding" / path.name
						if replacement_kind == "build"
						else replacement / path.name
					)
					replacement_output.parent.mkdir(parents=True)
					replacement_output.write_text("replacement", encoding="utf-8")
					replacement.rename(replaced_path)
					return {"input_complete": True}

				with mock.patch.object(
					gf_maintenance,
					"ROOT",
					fixture_root,
				), mock.patch.object(
					gf_maintenance.gf_gut_sharding,
					"parse_gut_junit_xml",
					side_effect=replace_directory_during_parse,
				), self.assertRaises(ValueError):
					gf_maintenance.parse_existing_gut_shard_junit(
						path,
						self.INVENTORY,
					)

	def test_authoritative_gut_timeouts_have_a_twenty_minute_floor(self) -> None:
		self.assertEqual(
			gf_maintenance.resolve_gut_shard_observation_timeout_seconds(None),
			1200,
		)
		self.assertEqual(
			gf_maintenance.resolve_gut_shard_observation_timeout_seconds(30),
			1200,
		)
		self.assertEqual(
			gf_maintenance.resolve_gut_shard_observation_timeout_seconds(1500),
			1500,
		)
		self.assertEqual(gf_maintenance.CHECK_TIMEOUT_SECONDS["gut"], 1200)
		self.assertEqual(
			gf_maintenance.resolve_check_timeout_seconds("gut", None),
			1200,
		)
		self.assertEqual(
			gf_maintenance.resolve_check_timeout_seconds("gut", 600),
			1200,
		)
		self.assertEqual(
			gf_maintenance.resolve_check_timeout_seconds("gut", 1500),
			1500,
		)
		framework_gut = next(
			shard
			for shard in gf_maintenance.parallel_full_shard_plan()
			if shard.name == "framework-gut"
		)
		self.assertEqual(
			gf_maintenance.parallel_shard_timeout_seconds(framework_gut, None),
			2820,
		)

	def test_renderer_exposes_diagnostic_completeness_and_duration_scope(self) -> None:
		text = gf_maintenance_rendering.render_gut_shard_plan_text({
			"ok": True,
			"mode": "existing_junit",
			"inventory_count": 1,
			"shard_count": 1,
			"manifest_path": "tests/gf_core/gut_shard_manifest.json",
			"manifest_digest": "a" * 64,
			"shards": [],
			"observation_policy": {
				"skip_count": 0,
				"cache_read_count": 0,
				"cache_write_count": 0,
				"reuse_count": 0,
			},
			"execution": {"performed": False, "result_accepted": False},
			"junit": {
				"input_complete": False,
				"completeness_basis": "script_names_only",
				"duration_scope": "testcase_only_excludes_script_lifecycle",
				"assertion_counts_complete": False,
				"assertion_count_unknown_reason": (
					"script_lifecycle_assertions_not_exported"
				),
				"script_count": 1,
				"test_count": 5,
				"assertion_count": 7,
				"lifecycle_assertion_count": 0,
				"duration_seconds": 0.5,
				"testcase_duration_seconds": 0.5,
				"status_counts": {
					"passed": 1,
					"failed": 1,
					"pending": 1,
					"no_asserts": 1,
					"skipped": 1,
				},
			},
			"issues": [],
		})

		self.assertIn(
			"statuses=passed=1, failed=1, pending=1, no_asserts=1, skipped=1",
			text,
		)
		self.assertIn(
			"policy: skips=0 cache_reads=0 cache_writes=0 reuse=0",
			text,
		)
		self.assertIn(
			"execution: performed=False result_accepted=False",
			text,
		)
		self.assertIn("input_complete=False", text)
		self.assertIn("completeness_basis=script_names_only", text)
		self.assertIn(
			"duration_scope=testcase_only_excludes_script_lifecycle",
			text,
		)
		self.assertIn("assertion_counts_complete=False", text)
		self.assertIn("lifecycle_assertion_count=0", text)
		self.assertIn(
			"assertion_count_unknown_reason=script_lifecycle_assertions_not_exported",
			text,
		)

	def test_full_synthetic_existing_junit_remains_diagnostic_only(self) -> None:
		inventory = gf_maintenance.gf_gut_sharding.discover_gut_test_scripts(ROOT)
		expected_count = len(inventory)
		root_element = ET.Element(
			"testsuites",
			{"name": "GutTests", "failures": "0", "tests": str(len(inventory))},
		)
		for script in inventory:
			junit_script = script.removeprefix("res://")
			suite = ET.SubElement(
				root_element,
				"testsuite",
				{
					"name": junit_script,
					"tests": "1",
					"failures": "0",
					"skipped": "0",
					"time": "0.001",
				},
			)
			ET.SubElement(
				suite,
				"testcase",
				{
					"name": "test_synthetic_observation",
					"assertions": "1",
					"status": "pass",
					"classname": junit_script,
					"time": "0.001",
				},
			)

		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			junit_path = fixture_root / "build/gut-sharding/full.xml"
			junit_path.parent.mkdir(parents=True)
			junit_path.write_bytes(
				b'<?xml version="1.0" encoding="UTF-8"?>\n'
				+ ET.tostring(root_element, encoding="utf-8"),
			)
			with mock.patch.object(gf_maintenance, "ROOT", fixture_root), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"discover_gut_test_scripts",
				return_value=inventory,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"load_and_validate_manifest",
				return_value=gf_maintenance.gf_gut_sharding.load_and_validate_manifest(
					ROOT / gf_maintenance.gf_gut_sharding.MANIFEST_RELATIVE_PATH,
					root=ROOT,
					expected_inventory=inventory,
				),
			):
				report = gf_maintenance.gut_shard_plan(junit_path=str(junit_path))

		self.assertFalse(report["ok"])
		self.assertEqual(report["mode"], "existing_junit")
		self.assertEqual(report["inventory_count"], expected_count)
		self.assertFalse(report["junit"]["input_complete"])
		self.assertEqual(report["junit"]["script_count"], expected_count)
		self.assertEqual(report["junit"]["test_count"], expected_count)
		self.assertNotIn("observation", report)
		self.assertEqual(
			[item["kind"] for item in report["issues"]],
			["gut_shard_observation_junit_rejected"],
		)


class GutShardRuntimeSourceBindingTests(unittest.TestCase):
	def test_loaded_runtime_binding_matches_current_source(self) -> None:
		digest = gf_maintenance.validate_gut_shard_runtime_source_binding(
			ROOT,
			gf_maintenance.GUT_SHARD_LOADED_RUNTIME_SOURCE_BINDING,
			deadline=time.perf_counter() + 10.0,
		)
		self.assertEqual(
			digest,
			gf_maintenance.GUT_SHARD_LOADED_RUNTIME_SOURCE_DIGEST,
		)
		self.assertEqual(
			tuple(path for path, _digest in gf_maintenance.GUT_SHARD_LOADED_RUNTIME_SOURCE_BINDING),
			tuple(path for path, _module in gf_maintenance.GUT_SHARD_RUNTIME_SOURCE_MODULES),
		)

	def test_top_report_and_worker_request_bind_runtime_digest(self) -> None:
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
		self.assertEqual(
			report["runtime_source_digest"],
			gf_maintenance.GUT_SHARD_LOADED_RUNTIME_SOURCE_DIGEST,
		)
		with tempfile.TemporaryDirectory() as temporary_directory:
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				Path(temporary_directory),
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				runtime_source_digest="4" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
		self.assertEqual(request["runtime_source_digest"], "4" * 64)
		self.assertEqual(
			set(request),
			gf_maintenance.gf_gut_shard_worker.REQUEST_KEYS,
		)

	def test_imported_a_rejects_captured_b_before_probe_or_worker(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			for relative_path, _module_name in gf_maintenance.GUT_SHARD_RUNTIME_SOURCE_MODULES:
				source_path = ROOT / relative_path
				target_path = fixture_root / relative_path
				target_path.parent.mkdir(parents=True, exist_ok=True)
				target_path.write_bytes(source_path.read_bytes())
			mutated_path = fixture_root / "tools/gf_gut_sharding.py"
			original = mutated_path.read_bytes()
			mutated = original.replace(b"SCHEMA_VERSION = 1", b"SCHEMA_VERSION = 2", 1)
			self.assertNotEqual(mutated, original)
			mutated_path.write_bytes(mutated)
			captured = mock.Mock(workspace_fingerprint="1" * 64)
			with mock.patch.object(
				gf_maintenance,
				"ROOT",
				fixture_root,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"capture_workspace",
				return_value=captured,
			) as capture, mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
			) as isolation_probe, mock.patch.object(
				gf_maintenance,
				"execute_gut_shard_candidate_reports",
			) as candidates:
				report = gf_maintenance.gut_shard_run()
		capture.assert_called_once()
		isolation_probe.assert_not_called()
		candidates.assert_not_called()
		self.assertFalse(report["ok"])
		self.assertEqual(report["executed_shard_count"], 0)
		self.assertIn(
			"gut_shard_runtime_source_mismatch",
			{issue["kind"] for issue in report["issues"]},
		)


class GutShardRunIntegrationTests(unittest.TestCase):
	TOP_LEVEL_FIELDS = {
		"schema_version",
		"ok",
		"mode",
		"authoritative",
		"merge_evidence",
		"workspace_fingerprint",
		"runtime_source_digest",
		"manifest_path",
		"manifest_digest",
		"inventory_digest",
		"inventory_count",
		"jobs",
		"import_timeout_seconds",
		"candidate_gut_timeout_seconds",
		"control_gut_timeout_seconds",
		"total_timeout_seconds",
		"qualify_requested",
		"candidate_eligible",
		"qualified",
		"qualification_status",
		"shard_count",
		"executed_shard_count",
		"completed_shard_count",
		"successful_shard_count",
		"failed_shard_count",
		"unreported_shard_count",
		"not_scheduled_shard_count",
		"duration_seconds",
		"isolation_probe",
		"shards",
		"aggregate",
		"control",
		"equivalence",
		"observation_policy",
		"issues",
	}
	INVENTORY = (
		gf_maintenance.gf_gut_sharding.LIFECYCLE_CONTRACT_SCRIPT,
		*tuple(
			f"res://tests/gf_core/synthetic/test_{index}.gd"
			for index in range(8)
		),
	)
	INVENTORY = tuple(sorted(INVENTORY))
	MANIFEST = gf_maintenance.gf_gut_sharding._bootstrap_manifest_for_inventory(  # noqa: SLF001
		INVENTORY
	)

	@staticmethod
	def _junit(scripts: list[str], *, duration: float = 0.1) -> dict[str, object]:
		script_reports = []
		for script_path in scripts:
			script_reports.append({
				"script": script_path,
				"duration_seconds": duration,
				"testcase_duration_seconds": duration,
				"testcase_duration_sum_seconds": duration,
				"testcase_duration_serialization_tolerance_seconds": 0.000002,
				"duration_scope": (
					gf_maintenance.gf_gut_sharding.JUNIT_LIFECYCLE_DURATION_SCOPE
				),
				"test_count": 1,
				"status_counts": {
					"passed": 1,
					"failed": 0,
					"pending": 0,
					"no_asserts": 0,
					"skipped": 0,
				},
				"failure_assertion_count": 0,
				"pending_assertion_count": 0,
				"failure_test_count_lower_bound": 0,
				"failure_test_count_upper_bound": 0,
				"assertion_count": 1,
				"lifecycle_assertion_count": 0,
				"assertion_counts_complete": True,
				"assertion_count_unknown_reason": None,
				"tests": [{
					"name": "test_fixture",
					"duration_seconds": duration,
					"status": "passed",
					"assertion_count": 1,
				}],
			})
		total_duration = gf_maintenance.gf_gut_sharding._finite_sum(  # noqa: SLF001
			(
				float(script["duration_seconds"])
				for script in script_reports
			),
			"fixture_duration_invalid",
			"Fixture duration must remain finite.",
		)
		return {
			"schema_version": 1,
			"ok": True,
			"source_format": "gut_junit_xml",
			"junit_sha256": "a" * 64,
			"provenance_sha256": "b" * 64,
			"input_complete": True,
			"completeness_basis": (
				gf_maintenance.gf_gut_sharding.JUNIT_COMPLETENESS_CONTROLLED_RUN
			),
			"script_count": len(scripts),
			"covered_script_count": len(scripts),
			"test_count": len(scripts),
			"duration_seconds": total_duration,
			"testcase_duration_seconds": total_duration,
			"duration_scope": (
				gf_maintenance.gf_gut_sharding.JUNIT_LIFECYCLE_DURATION_SCOPE
			),
			"status_counts": {
				"passed": len(scripts),
				"failed": 0,
				"pending": 0,
				"no_asserts": 0,
				"skipped": 0,
			},
			"failure_test_count": 0,
			"failure_assertion_count": 0,
			"pending_assertion_count": 0,
			"assertion_count": len(scripts),
			"lifecycle_assertion_count": 0,
			"assertion_counts_complete": True,
			"assertion_count_unknown_reason": None,
			"scripts": script_reports,
		}

	@staticmethod
	def _successful_worker_report(
		request: dict[str, object],
		junit: dict[str, object],
	) -> dict[str, object]:
		report = gf_maintenance.gf_gut_shard_worker._empty_report(request)
		report.update({
			"ok": True,
			"import_run_count": 1,
			"gut_run_count": 1,
			"import_result": {
				"ok": True,
				"exit_code": 0,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.0,
			},
			"gut_result": {
				"ok": True,
				"exit_code": 0,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.0,
			},
			"junit": junit,
			"junit_digest": gf_maintenance.gf_gut_shard_worker.canonical_digest(junit),
			"lifecycle_ok": True,
			"process_boundary_quiescent": True,
			"worker_cleanup_complete": True,
			"workspace_cleanup_permitted": True,
			"continuation_safe": True,
			"duration_seconds": 0.0,
		})
		return report

	@staticmethod
	def _failed_worker_report(
		request: dict[str, object],
		*,
		kind: str = "worker_import_failed",
	) -> dict[str, object]:
		report = gf_maintenance.gf_gut_shard_worker._empty_report(request)
		report["workspace_cleanup_permitted"] = True
		if kind == "worker_import_failed":
			report["import_run_count"] = 1
			report["import_result"] = {
				"ok": False,
				"exit_code": 1,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.01,
			}
			report["duration_seconds"] = 0.01
			report["continuation_safe"] = True
		report["issues"].append({
			"kind": kind,
			"message": "fixture",
			"phase": "import" if kind == "worker_import_failed" else "worker",
		})
		return report

	def _candidate_worker_reports(
		self,
		workspace: Path,
		*,
		gut_timeout: int | None = None,
	) -> list[dict[str, object]]:
		manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(self.MANIFEST)
		inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
			list(self.INVENTORY)
		)
		import_timeout = gf_maintenance.resolve_check_timeout_seconds(
			"godot_import", None
		)
		resolved_gut_timeout = gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(
			gut_timeout
		)
		reports: list[dict[str, object]] = []
		for index, shard in enumerate(self.MANIFEST["shards"]):
			candidate_workspace = workspace / f"candidate-{index}"
			candidate_workspace.mkdir(exist_ok=True)
			reports.append(self._successful_worker_report(
				gf_maintenance.make_gut_shard_worker_request(
					shard,
					candidate_workspace,
					workspace_fingerprint_value="1" * 64,
					manifest_digest=manifest_digest,
					inventory_digest=inventory_digest,
					remaining_seconds=float(
						gf_maintenance.gut_shard_worker_total_timeout_seconds(
							import_timeout,
							resolved_gut_timeout,
						)
					),
					import_timeout_seconds=import_timeout,
					gut_timeout_seconds=resolved_gut_timeout,
				),
				self._junit(shard["scripts"]),
			))
		return reports

	def _control_worker_report(self, workspace: Path) -> dict[str, object]:
		control_workspace = workspace / "control"
		control_workspace.mkdir(exist_ok=True)
		import_timeout = gf_maintenance.resolve_check_timeout_seconds(
			"godot_import", None
		)
		gut_timeout = gf_maintenance.resolve_gut_shard_observation_timeout_seconds(None)
		request = gf_maintenance.make_gut_shard_worker_request(
			{
				"name": gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME,
				"role": gf_maintenance.gf_gut_shard_worker.CONTROL_ROLE,
				"scripts": list(self.INVENTORY),
			},
			control_workspace,
			workspace_fingerprint_value="1" * 64,
			manifest_digest=gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			),
			inventory_digest=gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			),
			remaining_seconds=float(
				gf_maintenance.gut_shard_worker_total_timeout_seconds(
					import_timeout,
					gut_timeout,
				)
			),
			import_timeout_seconds=import_timeout,
			gut_timeout_seconds=gut_timeout,
			mode=gf_maintenance.gf_gut_shard_worker.CONTROL_MODE,
		)
		return self._successful_worker_report(
			request,
			self._junit(list(self.INVENTORY)),
		)

	def test_report_envelope_is_non_authoritative_and_has_zero_reuse(self) -> None:
		self.assertEqual(
			gf_maintenance.WINDOWS_PARALLEL_VALIDATION_ROOT_MAX_CHARACTERS,
			19,
		)
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
		self.assertEqual(set(report), self.TOP_LEVEL_FIELDS)
		self.assertEqual(report["mode"], "sharded_observation")
		self.assertFalse(report["authoritative"])
		self.assertFalse(report["merge_evidence"])
		self.assertFalse(report["qualified"])
		self.assertEqual(report["qualification_status"], "not_requested")
		self.assertEqual(report["isolation_probe"]["probe_count"], 0)
		self.assertEqual(
			report["observation_policy"],
			{
				"affects_check_graph": False,
				"affects_suite_membership": False,
				"authoritative_result_replaced": False,
				"skip_count": 0,
				"cache_read_count": 0,
				"cache_write_count": 0,
				"reuse_count": 0,
			},
		)

	def test_timeout_override_only_raises_candidate_floor_and_parent_is_bounded(self) -> None:
		self.assertEqual(gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(None), 600)
		self.assertEqual(gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(30), 600)
		self.assertEqual(gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(900), 900)
		self.assertEqual(
			gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=True,
			)["control_gut_timeout_seconds"],
			1200,
		)
		self.assertEqual(
			gf_maintenance.GUT_SHARD_RUN_WORKER_PREFLIGHT_ALLOWANCE_SECONDS,
			math.ceil(
				2 * gf_maintenance.gf_gut_sharding.INVENTORY_DEADLINE_SECONDS
			)
			+ gf_maintenance.GUT_SHARD_RUN_WORKER_NON_INVENTORY_PREFLIGHT_ALLOWANCE_SECONDS,
		)
		self.assertEqual(
			gf_maintenance.gut_shard_worker_total_timeout_seconds(600, 600),
			1320,
		)
		self.assertEqual(
			gf_maintenance.gut_shard_worker_total_timeout_seconds(600, 1200),
			1920,
		)
		self.assertEqual(
			gf_maintenance.gut_shard_run_total_timeout_seconds(
				9,
				2,
				gut_timeout_seconds=600,
				qualify=False,
			),
			6900,
		)
		self.assertEqual(
			gf_maintenance.gut_shard_run_total_timeout_seconds(
				9,
				2,
				gut_timeout_seconds=600,
				qualify=True,
			),
			8820,
		)
		overridden_report = gf_maintenance.make_gut_shard_run_report(
			jobs=2,
			qualify=True,
			gut_timeout_seconds=1500,
		)
		self.assertEqual(overridden_report["candidate_gut_timeout_seconds"], 1500)
		self.assertEqual(overridden_report["control_gut_timeout_seconds"], 1200)
		self.assertEqual(overridden_report["total_timeout_seconds"], 13320)
		self.assertEqual(
			overridden_report["total_timeout_seconds"]
			- gf_maintenance.gut_shard_run_total_timeout_seconds(
				9,
				2,
				gut_timeout_seconds=1500,
				qualify=False,
			),
			gf_maintenance.gut_shard_worker_total_timeout_seconds(600, 1200),
		)
		with self.assertRaisesRegex(ValueError, "phase timeout ceiling"):
			gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(
				gf_maintenance.gf_gut_shard_worker.MAX_PHASE_TIMEOUT_SECONDS + 1
			)
		for invalid in (-1, 0):
			with self.subTest(invalid=invalid), self.assertRaisesRegex(
				ValueError,
				"positive seconds",
			):
				gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(invalid)
			with self.assertRaisesRegex(ValueError, "positive seconds"):
				gf_maintenance.gut_shard_run(timeout_seconds=invalid)
		for invalid in (True, 1.5):
			with self.subTest(invalid=invalid), self.assertRaisesRegex(
				TypeError,
				"must be integers",
			):
				gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(invalid)
			with self.assertRaisesRegex(TypeError, "must be integers"):
				gf_maintenance.gut_shard_run(timeout_seconds=invalid)

	def test_cli_defaults_to_two_workers_and_forwards_qualification(self) -> None:
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
		with mock.patch.object(
			sys,
			"argv",
			["gf_maintenance.py", "gut-shard-run", "--qualify", "--json"],
		), mock.patch.object(
			gf_maintenance,
			"gut_shard_run",
			return_value=report,
		) as runner, mock.patch.object(
			gf_maintenance.maintenance_rendering,
			"print_output",
		) as print_output:
			exit_code = gf_maintenance.main()
		self.assertEqual(exit_code, 1)
		runner.assert_called_once_with(jobs=2, timeout_seconds=None, qualify=True)
		print_output.assert_called_once()

	def test_cli_rejects_out_of_range_shard_timeouts_before_execution(self) -> None:
		for invalid in ("0", "7201", "not-an-integer"):
			stdout = io.StringIO()
			stderr = io.StringIO()
			with self.subTest(invalid=invalid), mock.patch.object(
				sys,
				"argv",
				["gf_maintenance.py", "gut-shard-run", "--timeout", invalid, "--json"],
			), mock.patch.object(
				gf_maintenance,
				"gut_shard_run",
			) as runner, contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(
				stderr,
			), self.assertRaises(
				SystemExit,
			) as raised:
				gf_maintenance.main()
			self.assertEqual(raised.exception.code, 2)
			runner.assert_not_called()
			self.assertEqual(stdout.getvalue(), "")
			self.assertIn("between 1 and 7200 seconds", stderr.getvalue())
			self.assertNotIn("Traceback", stderr.getvalue())

	def test_cli_shard_timeout_parser_accepts_worker_phase_bounds(self) -> None:
		for valid in ("1", "600", "7200"):
			with self.subTest(valid=valid):
				self.assertEqual(
					gf_maintenance.parse_gut_shard_run_timeout_seconds(valid),
					int(valid),
				)
		for invalid in ("0", "7201", "1.5"):
			with self.subTest(invalid=invalid), self.assertRaises(
				gf_maintenance.argparse.ArgumentTypeError,
			):
				gf_maintenance.parse_gut_shard_run_timeout_seconds(invalid)

	def test_top_level_run_captures_once_and_accepts_all_candidate_reports(self) -> None:
		captured = mock.Mock(
			workspace_fingerprint="1" * 64,
		)
		with tempfile.TemporaryDirectory() as temporary_directory:
			worker_reports = self._candidate_worker_reports(Path(temporary_directory))
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			with mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"capture_workspace",
				return_value=captured,
			) as capture, mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"discover_gut_test_scripts",
				return_value=self.INVENTORY,
			) as discover_inventory, mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"load_and_validate_manifest",
				return_value=self.MANIFEST,
			), mock.patch.object(
				gf_maintenance,
				"validate_gut_shard_runtime_source_binding",
				wraps=gf_maintenance.validate_gut_shard_runtime_source_binding,
			) as runtime_binding, mock.patch.object(
				gf_maintenance,
				"managed_validation_directory",
				return_value=contextlib.nullcontext(Path(temporary_directory)),
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path",
						"user_dir",
						"data_dir",
						"config_dir",
						"cache_dir",
					],
					"private_roots": {"a": "random-a", "b": "random-b"},
				},
			) as isolation_probe, mock.patch.object(
				gf_maintenance,
				"execute_gut_shard_candidate_reports",
				return_value=(worker_reports, 9, []),
			) as candidates, mock.patch.object(
				gf_maintenance,
				"aggregate_gut_shard_candidate_reports",
				return_value=aggregate,
			):
				call_order = mock.Mock()
				call_order.attach_mock(isolation_probe, "isolation_probe")
				call_order.attach_mock(candidates, "candidates")
				report = gf_maintenance.gut_shard_run()
		self.assertTrue(report["ok"], report["issues"])
		self.assertTrue(report["candidate_eligible"])
		self.assertFalse(report["authoritative"])
		self.assertFalse(report["merge_evidence"])
		self.assertEqual(report["executed_shard_count"], 9)
		self.assertEqual(report["completed_shard_count"], 9)
		self.assertEqual(report["successful_shard_count"], 9)
		self.assertEqual(report["failed_shard_count"], 0)
		self.assertEqual(report["unreported_shard_count"], 0)
		self.assertEqual(report["not_scheduled_shard_count"], 0)
		self.assertEqual(
			report["isolation_probe"],
			{
				"ok": True,
				"probe_count": 2,
				"fields": [
					"marker_path",
					"user_dir",
					"data_dir",
					"config_dir",
					"cache_dir",
				],
			},
		)
		capture.assert_called_once()
		discover_inventory.assert_called_once_with(
			gf_maintenance.ROOT,
			deadline=capture.call_args.kwargs["deadline"],
		)
		self.assertEqual(runtime_binding.call_count, 2)
		isolation_probe.assert_called_once()
		self.assertEqual(
			[call[0] for call in call_order.mock_calls[:2]],
			["isolation_probe", "candidates"],
		)
		self.assertEqual(candidates.call_args.kwargs["jobs"], 2)
		self.assertEqual(
			candidates.call_args.kwargs["runtime_source_digest"],
			report["runtime_source_digest"],
		)
		self.assertEqual(candidates.call_args.kwargs["gut_timeout_seconds"], 600)
		self.assertIsInstance(
			candidates.call_args.kwargs["cancellation_event"],
			threading.Event,
		)
		self.assertFalse(candidates.call_args.kwargs["cancellation_event"].is_set())

	def test_isolation_probe_failure_starts_zero_candidate_workers(self) -> None:
		captured = mock.Mock(workspace_fingerprint="1" * 64)
		with tempfile.TemporaryDirectory() as temporary_directory, mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"capture_workspace",
			return_value=captured,
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"assert_source_matches_snapshot",
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"discover_gut_test_scripts",
			return_value=self.INVENTORY,
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"load_and_validate_manifest",
			return_value=self.MANIFEST,
		), mock.patch.object(
			gf_maintenance,
			"managed_validation_directory",
			return_value=contextlib.nullcontext(Path(temporary_directory)),
		), mock.patch.object(
			gf_maintenance,
			"run_parallel_godot_isolation_probe",
			side_effect=gf_maintenance.WorkspaceSnapshotError("probe failed closed"),
		), mock.patch.object(
			gf_maintenance,
			"execute_gut_shard_candidate_reports",
		) as candidates:
			report = gf_maintenance.gut_shard_run()
		self.assertFalse(report["ok"])
		self.assertEqual(report["executed_shard_count"], 0)
		self.assertEqual(
			report["isolation_probe"],
			{
				"ok": False,
				"probe_count": 0,
				"fields": [
					"marker_path",
					"user_dir",
					"data_dir",
					"config_dir",
					"cache_dir",
				],
			},
		)
		candidates.assert_not_called()

	def test_isolation_probe_unproven_boundary_forbids_validation_root_cleanup(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			cleanup_state = {"permitted": True}
			results = [
				gf_maintenance.ParallelShardResult(
					name=label,
					command=("godot",),
					workspace=parallel_root / "p" / label,
					exit_code=0,
					process_exit_code=0,
					stdout="",
					stderr="",
					timed_out=False,
					cancelled=False,
					duration_seconds=0.1,
					pid=index + 1,
					started=True,
					process_boundary_quiescent=(label == "a"),
				)
				for index, label in enumerate(("a", "b"))
			]
			with mock.patch.object(
				gf_maintenance,
				"resolve_godot_executable",
				return_value="godot",
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				return_value=results,
			):
				with self.assertRaisesRegex(
					gf_maintenance.WorkspaceSnapshotError,
					"process-boundary cleanup",
				):
					gf_maintenance.run_parallel_godot_isolation_probe(
						parallel_root,
						deadline=time.perf_counter() + 10.0,
						output_callback=None,
						cleanup_state=cleanup_state,
					)
			self.assertFalse(cleanup_state["permitted"])

	def test_isolation_probe_no_child_start_failure_permits_root_cleanup(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			cleanup_state = {"permitted": True}
			missing_executable = Path(temporary_directory) / "missing-godot"
			with mock.patch.object(
				gf_maintenance,
				"resolve_godot_executable",
				return_value=str(missing_executable),
			):
				with self.assertRaisesRegex(
					gf_maintenance.WorkspaceSnapshotError,
					"failed",
				):
					gf_maintenance.run_parallel_godot_isolation_probe(
						Path(temporary_directory),
						deadline=time.perf_counter() + 10.0,
						output_callback=None,
						cleanup_state=cleanup_state,
					)
			self.assertTrue(cleanup_state["permitted"])

	def test_isolation_probe_base_exception_keeps_cleanup_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			cleanup_state = {"permitted": True}
			with mock.patch.object(
				gf_maintenance,
				"resolve_godot_executable",
				return_value="godot",
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=KeyboardInterrupt("fixture probe interruption"),
			):
				with self.assertRaisesRegex(KeyboardInterrupt, "probe interruption"):
					gf_maintenance.run_parallel_godot_isolation_probe(
						Path(temporary_directory),
						deadline=time.perf_counter() + 10.0,
						output_callback=None,
						cleanup_state=cleanup_state,
					)
			self.assertFalse(cleanup_state["permitted"])

	def test_qualification_runs_one_original_timeout_control_after_candidates(self) -> None:
		captured = mock.Mock(workspace_fingerprint="1" * 64)
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(
				workspace,
				gut_timeout=900,
			)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST, self.INVENTORY, worker_reports,
			)
			control = self._control_worker_report(workspace)
			equivalence = gf_maintenance.compare_gut_shard_qualification(
				aggregate,
				control,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				candidate_reports=worker_reports,
			)
			with mock.patch.object(
				gf_maintenance.gf_parallel_validation,
			"capture_workspace",
			return_value=captured,
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"assert_source_matches_snapshot",
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"discover_gut_test_scripts",
			return_value=self.INVENTORY,
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"load_and_validate_manifest",
			return_value=self.MANIFEST,
		), mock.patch.object(
			gf_maintenance,
			"managed_validation_directory",
			return_value=contextlib.nullcontext(Path(temporary_directory)),
		), mock.patch.object(
			gf_maintenance,
			"run_parallel_godot_isolation_probe",
			return_value={
				"ok": True,
				"probe_count": 2,
				"fields": [
					"marker_path",
					"user_dir",
					"data_dir",
					"config_dir",
					"cache_dir",
				],
			},
		), mock.patch.object(
			gf_maintenance,
			"execute_gut_shard_candidate_reports",
			return_value=(worker_reports, 9, []),
		), mock.patch.object(
			gf_maintenance,
			"aggregate_gut_shard_candidate_reports",
			return_value=aggregate,
		), mock.patch.object(
			gf_maintenance,
			"execute_gut_shard_control_report",
			return_value=(control, 1, []),
		) as control_runner, mock.patch.object(
			gf_maintenance,
			"compare_gut_shard_qualification",
			return_value=equivalence,
		) as compare:
				report = gf_maintenance.gut_shard_run(
				timeout_seconds=900,
				qualify=True,
			)
		self.assertTrue(report["ok"], report["issues"])
		self.assertTrue(report["qualified"])
		self.assertEqual(report["qualification_status"], "qualified")
		control_runner.assert_called_once()
		self.assertEqual(control_runner.call_args.kwargs["gut_timeout_seconds"], 1200)
		self.assertEqual(compare.call_count, 2)
		for call in compare.call_args_list:
			self.assertEqual(call.args, (report["aggregate"], control))
			self.assertEqual(call.kwargs, {
				"manifest": self.MANIFEST,
				"inventory": self.INVENTORY,
				"candidate_reports": worker_reports,
			})

	def test_comparison_exception_returns_closed_infrastructure_report(self) -> None:
		captured = mock.Mock(workspace_fingerprint="1" * 64)
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			control = self._control_worker_report(workspace)
			with mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"capture_workspace",
				return_value=captured,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"discover_gut_test_scripts",
				return_value=self.INVENTORY,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"load_and_validate_manifest",
				return_value=self.MANIFEST,
			), mock.patch.object(
				gf_maintenance,
				"managed_validation_directory",
				return_value=contextlib.nullcontext(workspace),
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
			), mock.patch.object(
				gf_maintenance,
				"execute_gut_shard_candidate_reports",
				return_value=(worker_reports, len(worker_reports), []),
			), mock.patch.object(
				gf_maintenance,
				"aggregate_gut_shard_candidate_reports",
				return_value=aggregate,
			), mock.patch.object(
				gf_maintenance,
				"execute_gut_shard_control_report",
				return_value=(control, 1, []),
			), mock.patch.object(
				gf_maintenance,
				"compare_gut_shard_qualification",
				side_effect=RuntimeError("synthetic comparison failure"),
			) as compare:
				report = gf_maintenance.gut_shard_run(qualify=True)
		self.assertFalse(report["ok"])
		self.assertFalse(report["candidate_eligible"])
		self.assertFalse(report["qualified"])
		self.assertEqual(report["qualification_status"], "infrastructure_failed")
		self.assertIsNone(report["equivalence"])
		self.assertEqual(compare.call_count, 1)
		self.assertIn(
			"gut_shard_comparison_failed",
			{issue["kind"] for issue in report["issues"]},
		)

	def test_final_source_drift_revokes_candidate_and_qualification(self) -> None:
		captured = mock.Mock(workspace_fingerprint="1" * 64)
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)

			@contextlib.contextmanager
			def retained_validation_root(**kwargs: object) -> object:
				try:
					yield workspace
				finally:
					cleanup_permitted = kwargs["cleanup_permitted"]
					if not cleanup_permitted():
						kwargs["cleanup_errors"].append(
							"Retained validation root after final source drift."
						)

			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST, self.INVENTORY, worker_reports,
			)
			control = self._control_worker_report(workspace)
			equivalence = gf_maintenance.compare_gut_shard_qualification(
				aggregate,
				control,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				candidate_reports=worker_reports,
			)
			with mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"capture_workspace",
				return_value=captured,
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"assert_source_matches_snapshot",
			side_effect=[
				None,
				gf_maintenance.gf_parallel_validation.WorkspaceDriftError(
					"final source drift"
				),
			],
		) as source_check, mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"discover_gut_test_scripts",
			return_value=self.INVENTORY,
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"load_and_validate_manifest",
			return_value=self.MANIFEST,
		), mock.patch.object(
			gf_maintenance,
			"managed_validation_directory",
			side_effect=retained_validation_root,
		), mock.patch.object(
			gf_maintenance,
			"run_parallel_godot_isolation_probe",
			return_value={
				"ok": True,
				"probe_count": 2,
				"fields": [
					"marker_path",
					"user_dir",
					"data_dir",
					"config_dir",
					"cache_dir",
				],
			},
		), mock.patch.object(
			gf_maintenance,
			"execute_gut_shard_candidate_reports",
			return_value=(worker_reports, 9, []),
		), mock.patch.object(
			gf_maintenance,
			"aggregate_gut_shard_candidate_reports",
			return_value=aggregate,
		), mock.patch.object(
			gf_maintenance,
			"execute_gut_shard_control_report",
			return_value=(control, 1, []),
		), mock.patch.object(
			gf_maintenance,
			"compare_gut_shard_qualification",
			return_value=equivalence,
		):
				report = gf_maintenance.gut_shard_run(qualify=True)
		self.assertEqual(source_check.call_count, 2)
		self.assertFalse(report["ok"])
		self.assertFalse(report["candidate_eligible"])
		self.assertFalse(report["qualified"])
		self.assertEqual(report["qualification_status"], "cleanup_failed")
		self.assertIn("final source drift", "\n".join(
			issue["message"] for issue in report["issues"]
		))

	def test_command_is_outside_checks_suites_dependencies_and_workflows(self) -> None:
		self.assertNotIn("gut_shard_run", gf_maintenance.CHECK_DEFINITIONS)
		self.assertTrue(all(
			"gut_shard_run" not in checks
			for checks in gf_maintenance.CHECK_SUITES.values()
		))
		self.assertTrue(all(
			"gut_shard_run" not in dependencies
			for dependencies in gf_maintenance.CHECK_DEPENDENCIES.values()
		))
		for relative_path in (
			".github/workflows/ci.yml",
			".github/workflows/ci-manual.yml",
			".github/workflows/release.yml",
		):
			self.assertNotIn("gut-shard-run", (ROOT / relative_path).read_text(encoding="utf-8"))

	def test_worker_request_binds_exact_workspace_selection_and_remaining_duration(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=123.5,
				import_timeout_seconds=600,
				gut_timeout_seconds=900,
			)
		self.assertEqual(set(request), gf_maintenance.gf_gut_shard_worker.REQUEST_KEYS)
		self.assertEqual(request["workspace_path"], str(workspace.resolve()))
		self.assertEqual(request["mode"], gf_maintenance.gf_gut_shard_worker.CANDIDATE_MODE)
		self.assertEqual(request["remaining_seconds"], 123.5)
		self.assertNotIn("deadline", request)

	def test_direct_worker_failed_report_is_accepted_only_when_request_matches(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory) / "workspace"
			workspace.mkdir()
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
			report = gf_maintenance.gf_gut_shard_worker._empty_report(request)
			report["issues"].append({
				"kind": "fixture_failure",
				"message": "fixture",
				"phase": "gut",
			})
			with mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "1" * 64},
			):
				loaded = gf_maintenance.validate_direct_gut_shard_worker_report(
					report,
					request,
					workspace,
					expected_workspace_fingerprint="1" * 64,
					deadline=time.perf_counter() + 10.0,
				)
				self.assertEqual(loaded, report)
				with self.assertRaisesRegex(ValueError, "parent request"):
					gf_maintenance.validate_direct_gut_shard_worker_report(
						report,
						{**request, "nonce": "fe" * 32},
						workspace,
						expected_workspace_fingerprint="1" * 64,
						deadline=time.perf_counter() + 10.0,
					)

	def test_direct_worker_wave_is_parallel_ordered_and_never_nests_parallel_shards(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		with contextlib.nullcontext(temporary_owner.name) as temporary_directory:
			root = Path(temporary_directory)
			workspaces = {}
			requests = []
			for index, name in enumerate(("gut-lane-a", "gut-lane-b")):
				workspace = root / f"s{index}"
				workspace.mkdir()
				workspaces[name] = workspace
				requests.append(gf_maintenance.make_gut_shard_worker_request(
					{
						"name": name,
						"role": "lane",
						"scripts": [f"res://tests/gf_core/{name}/test_fixture.gd"],
					},
					workspace,
					workspace_fingerprint_value="1" * 64,
					manifest_digest="2" * 64,
					inventory_digest="3" * 64,
					remaining_seconds=120.0,
					import_timeout_seconds=60,
					gut_timeout_seconds=60,
				))
		barrier = threading.Barrier(2)
		second_finished = threading.Event()
		active = 0
		maximum_active = 0
		active_lock = threading.Lock()

		def run_worker(request: dict[str, object], *, cancellation_event: threading.Event) -> dict[str, object]:
			nonlocal active, maximum_active
			with active_lock:
				active += 1
				maximum_active = max(maximum_active, active)
			try:
				barrier.wait(timeout=2.0)
				if request["shard_name"] == "gut-lane-b":
					second_finished.set()
				else:
					self.assertTrue(second_finished.wait(timeout=2.0))
				return self._successful_worker_report(
					request,
					self._junit(request["scripts"]),
				)
			finally:
				with active_lock:
					active -= 1

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value={"fingerprint": "1" * 64},
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"run_parallel_shards",
			side_effect=AssertionError("nested worker supervisor forbidden"),
		) as nested_runner:
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				requests,
				workspaces,
				expected_workspace_fingerprint="1" * 64,
				deadline=time.perf_counter() + 10.0,
				cancellation_event=threading.Event(),
			)
		self.assertEqual(issues, [])
		self.assertEqual(executed, 2)
		self.assertEqual(maximum_active, 2)
		self.assertEqual(
			[report["request"]["shard_name"] for report in reports],
			["gut-lane-a", "gut-lane-b"],
		)
		nested_runner.assert_not_called()

	def test_direct_worker_wave_deadline_sets_shared_cancellation(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		with contextlib.nullcontext(temporary_owner.name) as temporary_directory:
			workspace = Path(temporary_directory)
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
		cancellation_event = threading.Event()

		def wait_for_cancellation(
			worker_request: dict[str, object],
			*,
			cancellation_event: threading.Event,
		) -> dict[str, object]:
			self.assertTrue(cancellation_event.wait(timeout=2.0))
			return self._failed_worker_report(worker_request, kind="worker_cancelled")

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=wait_for_cancellation,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=TimeoutError("synthetic expired fingerprint deadline"),
		):
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				[request],
				{"gut-lane-a": workspace},
				expected_workspace_fingerprint="1" * 64,
				deadline=time.perf_counter() + 0.02,
				cancellation_event=cancellation_event,
			)
		self.assertTrue(cancellation_event.is_set())
		self.assertEqual(executed, 1)
		self.assertEqual(reports, [])
		self.assertEqual(
			[issue["kind"] for issue in issues],
			["gut_shard_worker_wave_deadline_exhausted"],
		)

	def test_direct_worker_boundary_can_precede_peer_wave_deadline(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		root = Path(temporary_owner.name)
		workspaces: dict[str, Path] = {}
		requests: list[dict[str, object]] = []
		for index, name in enumerate(("gut-lane-a", "gut-lane-b")):
			workspace = root / f"s{index}"
			workspace.mkdir()
			workspaces[name] = workspace
			requests.append(gf_maintenance.make_gut_shard_worker_request(
				{
					"name": name,
					"role": "lane",
					"scripts": [f"res://tests/gf_core/{name}/test_fixture.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			))
		barrier = threading.Barrier(2)
		cancellation_event = threading.Event()
		cleanup_state = {"permitted": True}
		worker_deadline = time.perf_counter() + 1.0

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
		) -> dict[str, object]:
			barrier.wait(timeout=2.0)
			if request["shard_name"] == "gut-lane-b":
				self.assertTrue(cancellation_event.wait(timeout=2.0))
				while time.perf_counter() <= worker_deadline + 0.03:
					time.sleep(0.005)
			return self._successful_worker_report(
				request,
				self._junit(request["scripts"]),
			)

		def fingerprint(
			workspace: Path,
			*,
			deadline: float | None = None,
		) -> dict[str, str]:
			if workspace == workspaces["gut-lane-a"]:
				boundary_error = (
					gf_maintenance.gf_maintenance_check_graph
					.WorkspaceFingerprintProcessBoundaryError
				)
				raise boundary_error("synthetic early fingerprint boundary debt")
			raise TimeoutError("synthetic peer report validation deadline")

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=fingerprint,
		):
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				requests,
				workspaces,
				expected_workspace_fingerprint="1" * 64,
				deadline=worker_deadline,
				cancellation_event=cancellation_event,
				cleanup_state=cleanup_state,
			)
		self.assertEqual(reports, [])
		self.assertEqual(executed, 2)
		self.assertTrue(cancellation_event.is_set())
		self.assertFalse(cleanup_state["permitted"])
		self.assertEqual(
			[issue["kind"] for issue in issues],
			[
				"gut_shard_workspace_fingerprint_boundary_unproven",
				"gut_shard_worker_wave_deadline_exhausted",
			],
		)

	def test_direct_worker_boundary_can_precede_retained_peer_deadline_debt(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		root = Path(temporary_owner.name)
		workspaces: dict[str, Path] = {}
		requests: list[dict[str, object]] = []
		for index, name in enumerate(("gut-lane-a", "gut-lane-b")):
			workspace = root / f"s{index}"
			workspace.mkdir()
			workspaces[name] = workspace
			requests.append(gf_maintenance.make_gut_shard_worker_request(
				{
					"name": name,
					"role": "lane",
					"scripts": [f"res://tests/gf_core/{name}/test_fixture.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			))
		barrier = threading.Barrier(2)
		cancellation_event = threading.Event()
		cleanup_state = {"permitted": True}
		worker_deadline = time.perf_counter() + 1.0

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
		) -> dict[str, object]:
			barrier.wait(timeout=2.0)
			if request["shard_name"] == "gut-lane-a":
				return self._successful_worker_report(
					request,
					self._junit(request["scripts"]),
				)
			self.assertTrue(cancellation_event.wait(timeout=2.0))
			while time.perf_counter() <= worker_deadline + 0.03:
				time.sleep(0.005)
			retained = self._failed_worker_report(
				request,
				kind="worker_cancelled",
			)
			retained["workspace_cleanup_permitted"] = False
			retained["continuation_safe"] = False
			return retained

		def fingerprint(
			workspace: Path,
			*,
			deadline: float | None = None,
		) -> dict[str, str]:
			self.assertEqual(workspace, workspaces["gut-lane-a"])
			boundary_error = (
				gf_maintenance.gf_maintenance_check_graph
				.WorkspaceFingerprintProcessBoundaryError
			)
			raise boundary_error("synthetic early fingerprint boundary debt")

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			side_effect=fingerprint,
		):
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				requests,
				workspaces,
				expected_workspace_fingerprint="1" * 64,
				deadline=worker_deadline,
				cancellation_event=cancellation_event,
				cleanup_state=cleanup_state,
			)
		self.assertEqual(executed, 2)
		self.assertEqual(
			[report["request"]["shard_name"] for report in reports],
			["gut-lane-b"],
		)
		self.assertFalse(cleanup_state["permitted"])
		self.assertEqual(
			[issue["kind"] for issue in issues],
			[
				"gut_shard_workspace_fingerprint_boundary_unproven",
				"gut_shard_worker_wave_deadline_exhausted",
				"gut_shard_worker_infrastructure_failed",
				"gut_shard_workspace_ownership_unproven",
			],
		)

	def test_direct_worker_exception_cancels_and_drains_its_peer(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		with contextlib.nullcontext(temporary_owner.name) as temporary_directory:
			root = Path(temporary_directory)
			workspaces = {}
			requests = []
			for index, name in enumerate(("gut-lane-a", "gut-lane-b")):
				workspace = root / f"s{index}"
				workspace.mkdir()
				workspaces[name] = workspace
				requests.append(gf_maintenance.make_gut_shard_worker_request(
					{
						"name": name,
						"role": "lane",
						"scripts": [f"res://tests/gf_core/{name}/test_fixture.gd"],
					},
					workspace,
					workspace_fingerprint_value="1" * 64,
					manifest_digest="2" * 64,
					inventory_digest="3" * 64,
					remaining_seconds=120.0,
					import_timeout_seconds=60,
					gut_timeout_seconds=60,
				))
		barrier = threading.Barrier(2)
		peer_drained = threading.Event()
		cancellation_event = threading.Event()

		def run_worker(request: dict[str, object], *, cancellation_event: threading.Event) -> dict[str, object]:
			barrier.wait(timeout=2.0)
			if request["shard_name"] == "gut-lane-a":
				raise RuntimeError("fixture worker crash")
			self.assertTrue(cancellation_event.wait(timeout=2.0))
			peer_drained.set()
			return self._failed_worker_report(request, kind="worker_cancelled")

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value={"fingerprint": "1" * 64},
		):
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				requests,
				workspaces,
				expected_workspace_fingerprint="1" * 64,
				deadline=time.perf_counter() + 10.0,
				cancellation_event=cancellation_event,
			)
		self.assertTrue(cancellation_event.is_set())
		self.assertTrue(peer_drained.is_set())
		self.assertEqual(executed, 2)
		self.assertEqual(len(reports), 1)
		self.assertIn("gut_shard_worker_exception", {issue["kind"] for issue in issues})

	def test_direct_worker_submit_failure_retains_exact_launched_progress(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		root = Path(temporary_owner.name)
		workspaces = {}
		requests = []
		for index, name in enumerate(("gut-lane-a", "gut-lane-b")):
			workspace = root / f"s{index}"
			workspace.mkdir()
			workspaces[name] = workspace
			requests.append(gf_maintenance.make_gut_shard_worker_request(
				{
					"name": name,
					"role": "lane",
					"scripts": [f"res://tests/gf_core/{name}/test_fixture.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			))
		original_submit = concurrent.futures.ThreadPoolExecutor.submit
		submit_count = 0

		def fail_second_submit(
			executor: concurrent.futures.ThreadPoolExecutor,
			function: object,
			*args: object,
			**kwargs: object,
		) -> concurrent.futures.Future[object]:
			nonlocal submit_count
			submit_count += 1
			if submit_count == 2:
				raise RuntimeError("fixture submit failure")
			return original_submit(executor, function, *args, **kwargs)

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
		) -> dict[str, object]:
			del cancellation_event
			return self._successful_worker_report(
				request,
				self._junit(request["scripts"]),
			)

		cancellation_event = threading.Event()
		cleanup_state = {"permitted": True}
		with mock.patch.object(
			concurrent.futures.ThreadPoolExecutor,
			"submit",
			new=fail_second_submit,
		), mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value={"fingerprint": "1" * 64},
		):
			reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
				requests,
				workspaces,
				expected_workspace_fingerprint="1" * 64,
				deadline=time.perf_counter() + 10.0,
				cancellation_event=cancellation_event,
				cleanup_state=cleanup_state,
			)
		self.assertTrue(cancellation_event.is_set())
		self.assertFalse(cleanup_state["permitted"])
		self.assertEqual(executed, 1)
		self.assertEqual(len(reports), 1)
		self.assertEqual(
			{issue["kind"] for issue in issues},
			{"gut_shard_worker_schedule_failed"},
		)

	def test_base_exception_sets_cancellation_before_executor_drains_workers(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		workspace = Path(temporary_owner.name)
		request = gf_maintenance.make_gut_shard_worker_request(
			{
				"name": "gut-lane-a",
				"role": "lane",
				"scripts": ["res://tests/gf_core/a/test_a.gd"],
			},
			workspace,
			workspace_fingerprint_value="1" * 64,
			manifest_digest="2" * 64,
			inventory_digest="3" * 64,
			remaining_seconds=120.0,
			import_timeout_seconds=60,
			gut_timeout_seconds=60,
		)
		worker_started = threading.Event()
		worker_drained = threading.Event()
		cancellation_event = threading.Event()

		def run_worker(
			worker_request: dict[str, object],
			*,
			cancellation_event: threading.Event,
		) -> dict[str, object]:
			worker_started.set()
			self.assertTrue(cancellation_event.wait(timeout=2.0))
			worker_drained.set()
			return self._failed_worker_report(worker_request, kind="worker_cancelled")

		def interrupted_wait(*_args: object, **_kwargs: object) -> object:
			self.assertTrue(worker_started.wait(timeout=2.0))
			raise KeyboardInterrupt("fixture interrupt")

		with mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance.concurrent.futures,
			"wait",
			side_effect=interrupted_wait,
		):
			with self.assertRaises(KeyboardInterrupt):
				gf_maintenance.execute_gut_shard_worker_wave(
					[request],
					{"gut-lane-a": workspace},
					expected_workspace_fingerprint="1" * 64,
					deadline=time.perf_counter() + 10.0,
					cancellation_event=cancellation_event,
				)
		self.assertTrue(cancellation_event.is_set())
		self.assertTrue(worker_drained.is_set())

	def test_closed_worker_failures_continue_through_every_candidate_wave(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		parallel_root = Path(temporary_owner.name)
		captured = mock.Mock(workspace_fingerprint="1" * 64)
		cancellation_event = threading.Event()
		seen_names = []

		def materialize(
			_captured: object,
			batch_root: Path,
			shards: list[dict[str, object]],
			*,
			deadline: float,
		) -> tuple[dict[str, Path], dict[str, tuple[int, int, int]]]:
			del deadline
			result = {}
			identities = {}
			for index, shard in enumerate(shards):
				workspace = batch_root / f"fixture-{index}"
				workspace.mkdir()
				result[shard["name"]] = workspace
				identities[shard["name"]] = (
					gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
						workspace.lstat()
					)
				)
			return result, identities

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
			expected_workspace_identity: tuple[int, int, int],
		) -> dict[str, object]:
			self.assertIsInstance(expected_workspace_identity, tuple)
			self.assertLessEqual(
				request["remaining_seconds"],
				gf_maintenance.gut_shard_worker_total_timeout_seconds(60, 60),
			)
			seen_names.append(request["shard_name"])
			return self._failed_worker_report(request)

		with mock.patch.object(
			gf_maintenance,
			"materialize_gut_shard_workspaces",
			side_effect=materialize,
		), mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value={"fingerprint": "1" * 64},
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"assert_source_matches_snapshot",
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"run_parallel_shards",
			side_effect=AssertionError("nested worker supervisor forbidden"),
		) as nested_runner:
			reports, executed, issues = gf_maintenance.execute_gut_shard_candidate_reports(
				captured,
				self.MANIFEST,
				parallel_root,
				jobs=2,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
				deadline=time.perf_counter() + 300.0,
				cancellation_event=cancellation_event,
			)
		self.assertFalse(cancellation_event.is_set())
		self.assertEqual(issues, [])
		self.assertEqual(executed, 9)
		self.assertEqual(len(reports), 9)
		self.assertCountEqual(
			seen_names,
			[shard["name"] for shard in self.MANIFEST["shards"]],
		)
		self.assertEqual(
			[report["request"]["shard_name"] for report in reports],
			[shard["name"] for shard in self.MANIFEST["shards"]],
		)
		nested_runner.assert_not_called()

	def test_worker_local_deadline_or_phase_timeout_cancels_later_waves(self) -> None:
		for failure_mode in ("deadline", "timed_out"):
			with self.subTest(failure_mode=failure_mode), tempfile.TemporaryDirectory() as temporary_directory:
				parallel_root = Path(temporary_directory)
				captured = mock.Mock(workspace_fingerprint="1" * 64)
				cancellation_event = threading.Event()
				seen_names: list[str] = []

				def materialize(
					_captured: object,
					batch_root: Path,
					shards: list[dict[str, object]],
					*,
					deadline: float,
				) -> tuple[dict[str, Path], dict[str, tuple[int, int, int]]]:
					del deadline
					result = {}
					identities = {}
					for index, shard in enumerate(shards):
						workspace = batch_root / f"fixture-{index}"
						workspace.mkdir()
						result[shard["name"]] = workspace
						identities[shard["name"]] = (
							gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
								workspace.lstat()
							)
						)
					return result, identities

				def run_worker(
					request: dict[str, object],
					*,
					cancellation_event: threading.Event,
					expected_workspace_identity: tuple[int, int, int],
				) -> dict[str, object]:
					self.assertIsInstance(expected_workspace_identity, tuple)
					seen_names.append(request["shard_name"])
					if failure_mode == "deadline":
						return self._failed_worker_report(
							request,
							kind="worker_deadline_exhausted",
						)
					report = self._failed_worker_report(
						request,
						kind="worker_import_failed",
					)
					report["issues"][0]["phase"] = "import"
					report["import_run_count"] = 1
					report["import_result"] = {
						"ok": False,
						"exit_code": 124,
						"timed_out": True,
						"cancelled": False,
						"duration_seconds": 0.1,
					}
					report["continuation_safe"] = False
					report["duration_seconds"] = 0.1
					return report

				with mock.patch.object(
					gf_maintenance,
					"materialize_gut_shard_workspaces",
					side_effect=materialize,
				), mock.patch.object(
					gf_maintenance.gf_gut_shard_worker,
					"run_worker",
					side_effect=run_worker,
				), mock.patch.object(
					gf_maintenance,
					"workspace_fingerprint",
					return_value={"fingerprint": "1" * 64},
				), mock.patch.object(
					gf_maintenance.gf_parallel_validation,
					"assert_source_matches_snapshot",
					side_effect=AssertionError("later wave checkpoint must not run"),
				) as source_check:
					reports, executed, issues = gf_maintenance.execute_gut_shard_candidate_reports(
						captured,
						self.MANIFEST,
						parallel_root,
						jobs=2,
						manifest_digest="2" * 64,
						inventory_digest="3" * 64,
						import_timeout_seconds=60,
						gut_timeout_seconds=60,
						deadline=time.perf_counter() + 300.0,
						cancellation_event=cancellation_event,
					)
				self.assertTrue(cancellation_event.is_set())
				self.assertEqual(executed, 2)
				self.assertEqual(len(reports), 2)
				self.assertCountEqual(
					seen_names,
					[shard["name"] for shard in self.MANIFEST["shards"][:2]],
				)
				self.assertIn(
					"gut_shard_worker_deadline_exhausted",
					{issue["kind"] for issue in issues},
				)
				source_check.assert_not_called()

	def test_candidate_source_drift_preserves_completed_wave_progress(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			captured = mock.Mock(workspace_fingerprint="1" * 64)
			cancellation_event = threading.Event()
			cleanup_state = {"permitted": True}

			def materialize(
				_captured: object,
				batch_root: Path,
				shards: list[dict[str, object]],
				*,
				deadline: float,
			) -> tuple[dict[str, Path], dict[str, tuple[int, int, int]]]:
				del deadline
				workspaces: dict[str, Path] = {}
				identities: dict[str, tuple[int, int, int]] = {}
				for index, shard in enumerate(shards):
					workspace = batch_root / f"s{index}"
					workspace.mkdir()
					workspaces[shard["name"]] = workspace
					identities[shard["name"]] = (
						gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
							workspace.lstat()
						)
					)
				return workspaces, identities

			def completed_wave(
				requests: list[dict[str, object]],
				_workspace_by_name: dict[str, Path],
				**_kwargs: object,
			) -> tuple[list[dict[str, object]], int, list[dict[str, str]]]:
				return (
					[self._failed_worker_report(request) for request in requests],
					len(requests),
					[],
				)

			with mock.patch.object(
				gf_maintenance,
				"materialize_gut_shard_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"execute_gut_shard_worker_wave",
				side_effect=completed_wave,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
				side_effect=gf_maintenance.gf_parallel_validation.WorkspaceDriftError(
					"synthetic source drift"
				),
			):
				reports, executed, issues = (
					gf_maintenance.execute_gut_shard_candidate_reports(
						captured,
						self.MANIFEST,
						parallel_root,
						jobs=2,
						manifest_digest="2" * 64,
						inventory_digest="3" * 64,
						import_timeout_seconds=60,
						gut_timeout_seconds=60,
						deadline=time.perf_counter() + 300.0,
						cancellation_event=cancellation_event,
						cleanup_state=cleanup_state,
					)
				)
			self.assertEqual(executed, 2)
			self.assertEqual(len(reports), 2)
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])
			self.assertIn(
				"gut_shard_candidate_source_verification_failed",
				{issue["kind"] for issue in issues},
			)

	def test_candidate_batch_cleanup_failure_cancels_and_forbids_outer_cleanup(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			captured = mock.Mock(workspace_fingerprint="1" * 64)
			cancellation_event = threading.Event()
			cleanup_state = {"permitted": True}

			def materialize(
				_captured: object,
				batch_root: Path,
				shards: list[dict[str, object]],
				*,
				deadline: float,
			) -> tuple[dict[str, Path], dict[str, tuple[int, int, int]]]:
				del deadline
				result = {}
				identities = {}
				for index, shard in enumerate(shards):
					workspace = batch_root / f"fixture-{index}"
					workspace.mkdir()
					result[shard["name"]] = workspace
					identities[shard["name"]] = (
						gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
							workspace.lstat()
						)
					)
				return result, identities

			def run_worker(
				request: dict[str, object],
				*,
				cancellation_event: threading.Event,
				expected_workspace_identity: tuple[int, int, int],
			) -> dict[str, object]:
				self.assertIsInstance(expected_workspace_identity, tuple)
				return self._failed_worker_report(request)

			with mock.patch.object(
				gf_maintenance,
				"materialize_gut_shard_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance.gf_gut_shard_worker,
				"run_worker",
				side_effect=run_worker,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "1" * 64},
			), mock.patch.object(
				gf_maintenance,
				"remove_owned_gut_shard_workspace_batch",
				return_value="synthetic batch cleanup failure",
			):
				reports, executed, issues = gf_maintenance.execute_gut_shard_candidate_reports(
					captured,
					self.MANIFEST,
					parallel_root,
					jobs=2,
					manifest_digest="2" * 64,
					inventory_digest="3" * 64,
					import_timeout_seconds=60,
					gut_timeout_seconds=60,
					deadline=time.perf_counter() + 300.0,
					cancellation_event=cancellation_event,
					cleanup_state=cleanup_state,
				)
			self.assertEqual(executed, 2)
			self.assertEqual(len(reports), 2)
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])
			self.assertIn(
				"gut_shard_workspace_cleanup_failed",
				{issue["kind"] for issue in issues},
			)

	def test_candidate_materialization_and_nested_cleanup_failure_forbid_outer_cleanup(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			cleanup_state = {"permitted": True}
			with mock.patch.object(
				gf_maintenance,
				"materialize_gut_shard_workspaces",
				side_effect=OSError("synthetic materialization failure"),
			), mock.patch.object(
				gf_maintenance,
				"remove_managed_temporary_tree",
				return_value="synthetic nested cleanup failure",
			):
				reports, executed, issues = (
					gf_maintenance.execute_gut_shard_candidate_reports(
						mock.Mock(workspace_fingerprint="1" * 64),
						self.MANIFEST,
						Path(temporary_directory),
						jobs=2,
						manifest_digest="2" * 64,
						inventory_digest="3" * 64,
						import_timeout_seconds=60,
						gut_timeout_seconds=60,
						deadline=time.perf_counter() + 30.0,
						cancellation_event=threading.Event(),
						cleanup_state=cleanup_state,
					)
				)
			self.assertEqual(reports, [])
			self.assertEqual(executed, 0)
			self.assertIn(
				"gut_shard_candidate_batch_failed",
				{issue["kind"] for issue in issues},
			)
			self.assertIn(
				"gut_shard_workspace_cleanup_failed",
				{issue["kind"] for issue in issues},
			)
			self.assertFalse(cleanup_state["permitted"])

	def test_candidate_retains_batch_when_materializer_refuses_replaced_child(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			cleanup_state = {"permitted": True}
			cancellation_event = threading.Event()

			def reject_replaced_child(
				_captured: object,
				batch_root: Path,
				_shards: list[dict[str, object]],
				*,
				deadline: float,
			) -> dict[str, Path]:
				del deadline
				target = batch_root / "s0"
				target.mkdir()
				expected_identity = target.lstat()
				target.rename(batch_root / "original-s0")
				target.mkdir()
				(target / "replacement-marker.txt").write_text(
					"replacement",
					encoding="utf-8",
				)
				gf_maintenance.gf_parallel_validation._remove_owned_tree(  # noqa: SLF001
					target,
					expected_identity=expected_identity,
				)
				raise AssertionError("replaced child cleanup must fail closed")

			with mock.patch.object(
				gf_maintenance,
				"materialize_gut_shard_workspaces",
				side_effect=reject_replaced_child,
			):
				reports, executed, issues = (
					gf_maintenance.execute_gut_shard_candidate_reports(
						mock.Mock(workspace_fingerprint="1" * 64),
						self.MANIFEST,
						parallel_root,
						jobs=2,
						manifest_digest="2" * 64,
						inventory_digest="3" * 64,
						import_timeout_seconds=60,
						gut_timeout_seconds=60,
						deadline=time.perf_counter() + 30.0,
						cancellation_event=cancellation_event,
						cleanup_state=cleanup_state,
					)
				)
			batch_root = parallel_root / "0"
			self.assertEqual(reports, [])
			self.assertEqual(executed, 0)
			self.assertIn(
				"gut_shard_candidate_batch_failed",
				{issue["kind"] for issue in issues},
			)
			self.assertTrue((batch_root / "s0" / "replacement-marker.txt").is_file())
			self.assertTrue((batch_root / "original-s0").is_dir())
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])

	def test_candidate_distinguishes_pre_yield_workspace_acquisition_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			foreign_batch = parallel_root / "0"
			foreign_batch.mkdir()
			marker = foreign_batch / "foreign-marker.txt"
			marker.write_text("retain", encoding="utf-8")
			cleanup_state = {"permitted": True}
			cancellation_event = threading.Event()
			reports, executed, issues = gf_maintenance.execute_gut_shard_candidate_reports(
				mock.Mock(workspace_fingerprint="1" * 64),
				self.MANIFEST,
				parallel_root,
				jobs=2,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
				deadline=time.perf_counter() + 30.0,
				cancellation_event=cancellation_event,
				cleanup_state=cleanup_state,
			)
			kinds = {issue["kind"] for issue in issues}
			self.assertEqual(reports, [])
			self.assertEqual(executed, 0)
			self.assertIn("gut_shard_candidate_workspace_acquisition_failed", kinds)
			self.assertNotIn("gut_shard_workspace_cleanup_failed", kinds)
			self.assertTrue(marker.is_file())
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])

	def test_unproven_process_boundary_cancels_and_retains_owned_workspace(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			workspace = root / "workspace"
			workspace.mkdir()
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
			report = self._failed_worker_report(request)
			report["process_boundary_quiescent"] = False
			report["workspace_cleanup_permitted"] = False
			report["continuation_safe"] = False
			cancellation_event = threading.Event()
			cleanup_state = {"permitted": True}
			with mock.patch.object(
				gf_maintenance.gf_gut_shard_worker,
				"run_worker",
				return_value=report,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				side_effect=AssertionError(
					"unproven worker boundary must forbid post-validation reads"
				),
			) as fingerprint:
				reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
					[request],
					{"gut-lane-a": workspace},
					expected_workspace_fingerprint="1" * 64,
					deadline=time.perf_counter() + 10.0,
					cancellation_event=cancellation_event,
					cleanup_state=cleanup_state,
				)
			self.assertEqual(executed, 1)
			self.assertEqual(len(reports), 1)
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])
			fingerprint.assert_not_called()
			self.assertIn(
				"gut_shard_workspace_ownership_unproven",
				{issue["kind"] for issue in issues},
			)

	def test_post_validation_git_boundary_debt_is_not_protocol_rejection(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory) / "workspace"
			workspace.mkdir()
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
			report = self._failed_worker_report(request)
			cancellation_event = threading.Event()
			cleanup_state = {"permitted": True}
			with mock.patch.object(
				gf_maintenance.gf_gut_shard_worker,
				"run_worker",
				return_value=report,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				side_effect=(
					gf_maintenance.gf_maintenance_check_graph.
					WorkspaceFingerprintProcessBoundaryError("synthetic Git boundary debt")
				),
			):
				reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
					[request],
					{"gut-lane-a": workspace},
					expected_workspace_fingerprint="1" * 64,
					deadline=time.perf_counter() + 10.0,
					cancellation_event=cancellation_event,
					cleanup_state=cleanup_state,
				)
			kinds = {issue["kind"] for issue in issues}
			self.assertEqual(executed, 1)
			self.assertEqual(reports, [])
			self.assertIn("gut_shard_workspace_fingerprint_boundary_unproven", kinds)
			self.assertNotIn("gut_shard_worker_report_rejected", kinds)
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])

	def test_worker_cleanup_debt_cancels_and_retains_owned_workspace(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			workspace = root / "workspace"
			workspace.mkdir()
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": "gut-lane-a",
					"role": "lane",
					"scripts": ["res://tests/gf_core/a/test_a.gd"],
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
			)
			report = self._failed_worker_report(
				request,
				kind="worker_private_environment_cleanup_failed",
			)
			report["issues"][0]["phase"] = "cleanup"
			report["worker_cleanup_complete"] = False
			cancellation_event = threading.Event()
			cleanup_state = {"permitted": True}
			with mock.patch.object(
				gf_maintenance.gf_gut_shard_worker,
				"run_worker",
				return_value=report,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "1" * 64},
			):
				reports, executed, issues = gf_maintenance.execute_gut_shard_worker_wave(
					[request],
					{"gut-lane-a": workspace},
					expected_workspace_fingerprint="1" * 64,
					deadline=time.perf_counter() + 10.0,
					cancellation_event=cancellation_event,
					cleanup_state=cleanup_state,
				)
			self.assertEqual(executed, 1)
			self.assertEqual(len(reports), 1)
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])
			self.assertIn(
				"gut_shard_worker_cleanup_debt",
				{issue["kind"] for issue in issues},
			)

	def test_managed_owned_directory_retains_when_cleanup_is_not_proven(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			owned = Path(temporary_directory) / "owned"
			errors: list[str] = []
			with gf_maintenance.managed_owned_directory(
				owned,
				cleanup_errors=errors,
				cleanup_permitted=lambda: False,
			):
				(owned / "evidence.txt").write_text("retain", encoding="utf-8")
			self.assertTrue((owned / "evidence.txt").is_file())
			self.assertTrue(any("Retained managed directory" in error for error in errors))

	def test_managed_owned_directory_marks_only_real_cleanup_failures(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			cleanup_state = {"permitted": True}
			cleanup_failed = mock.Mock(
				side_effect=lambda: cleanup_state.__setitem__("permitted", False)
			)
			errors: list[str] = []
			success = root / "success"
			with gf_maintenance.managed_owned_directory(
				success,
				cleanup_errors=errors,
				cleanup_permitted=lambda: cleanup_state["permitted"],
				cleanup_failed=cleanup_failed,
			):
				(success / "fixture.txt").write_text("fixture", encoding="utf-8")
			self.assertFalse(success.exists())
			self.assertEqual(errors, [])
			self.assertTrue(cleanup_state["permitted"])
			cleanup_failed.assert_not_called()

			failure = root / "failure"
			with mock.patch.object(
				gf_maintenance,
				"remove_managed_temporary_tree",
				return_value="synthetic cleanup failure",
			):
				with gf_maintenance.managed_owned_directory(
					failure,
					cleanup_errors=errors,
					cleanup_permitted=lambda: cleanup_state["permitted"],
					cleanup_failed=cleanup_failed,
				):
					(failure / "fixture.txt").write_text("fixture", encoding="utf-8")
			self.assertEqual(errors, ["synthetic cleanup failure"])
			self.assertFalse(cleanup_state["permitted"])
			cleanup_failed.assert_called_once_with()

	def test_cleanup_base_exception_revokes_every_wider_owner(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			cleanup_state = {"permitted": True}
			owned = root / "owned"
			with mock.patch.object(
				gf_maintenance,
				"remove_managed_temporary_tree",
				side_effect=KeyboardInterrupt("synthetic cleanup interrupt"),
			), self.assertRaisesRegex(KeyboardInterrupt, "cleanup interrupt"):
				with gf_maintenance.managed_owned_directory(
					owned,
					cleanup_errors=[],
					cleanup_permitted=lambda: cleanup_state["permitted"],
					cleanup_started=lambda: cleanup_state.__setitem__("permitted", False),
					cleanup_succeeded=lambda: cleanup_state.__setitem__("permitted", True),
					cleanup_failed=lambda: cleanup_state.__setitem__("permitted", False),
				):
					(owned / "evidence.txt").write_text("retain", encoding="utf-8")
			self.assertFalse(cleanup_state["permitted"])
			self.assertTrue((owned / "evidence.txt").is_file())

			batch_state = {"permitted": True}
			cancellation_event = threading.Event()
			batch = root / "batch"
			with mock.patch.object(
				gf_maintenance,
				"remove_owned_gut_shard_workspace_batch",
				side_effect=SystemExit("synthetic batch cleanup interrupt"),
			), self.assertRaisesRegex(SystemExit, "batch cleanup interrupt"):
				with gf_maintenance.managed_gut_shard_workspace_batch(
					batch,
					cleanup_errors=[],
					workspace_ownership={},
					cancellation_event=cancellation_event,
					cleanup_state=batch_state,
				):
					pass
			self.assertFalse(batch_state["permitted"])
			self.assertTrue(cancellation_event.is_set())
			self.assertTrue(batch.is_dir())

	def test_exact_workspace_batch_cleanup_preflights_every_child(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			batch = Path(temporary_directory) / "batch"
			batch.mkdir()
			first = batch / "s0"
			second = batch / "s1"
			first.mkdir()
			second.mkdir()
			(first / "first.txt").write_text("first", encoding="utf-8")
			(second / "second.txt").write_text("second", encoding="utf-8")
			batch_identity = batch.lstat()
			ownership = {
				first: gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
					first.lstat()
				),
				second: gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
					second.lstat()
				),
			}
			second.rename(batch / "original-s1")
			second.mkdir()
			(second / "replacement.txt").write_text("replacement", encoding="utf-8")
			error = gf_maintenance.remove_owned_gut_shard_workspace_batch(
				batch,
				batch_identity,
				ownership,
			)
			self.assertIn("membership differs", error)
			self.assertTrue((first / "first.txt").is_file())
			self.assertTrue((second / "replacement.txt").is_file())
			self.assertTrue((batch / "original-s1" / "second.txt").is_file())

	def test_exact_workspace_batch_cleanup_rejects_unowned_entry_and_deletes_normal_batch(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			batch = Path(temporary_directory) / "batch"
			batch.mkdir()
			workspace = batch / "s0"
			workspace.mkdir()
			(workspace / "source.txt").write_text("source", encoding="utf-8")
			ownership = {
				workspace: gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
					workspace.lstat()
				),
			}
			unexpected = batch / ".gf-gut-leftover"
			unexpected.mkdir()
			error = gf_maintenance.remove_owned_gut_shard_workspace_batch(
				batch,
				batch.lstat(),
				ownership,
			)
			self.assertIn("membership differs", error)
			self.assertTrue((workspace / "source.txt").is_file())
			self.assertTrue(unexpected.is_dir())
			unexpected.rmdir()
			self.assertEqual(
				gf_maintenance.remove_owned_gut_shard_workspace_batch(
					batch,
					batch.lstat(),
					ownership,
				),
				"",
			)
			self.assertFalse(batch.exists())

	def test_timeout_above_worker_ceiling_fails_before_capture_or_probe(self) -> None:
		with mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"capture_workspace",
		) as capture, mock.patch.object(
			gf_maintenance,
			"run_parallel_godot_isolation_probe",
		) as isolation_probe:
			with self.assertRaisesRegex(ValueError, "phase timeout ceiling"):
				gf_maintenance.gut_shard_run(
					timeout_seconds=(
						gf_maintenance.gf_gut_shard_worker.MAX_PHASE_TIMEOUT_SECONDS + 1
					),
				)
		capture.assert_not_called()
		isolation_probe.assert_not_called()

	def test_control_uses_direct_worker_without_parallel_shard_supervisor(self) -> None:
		temporary_owner = tempfile.TemporaryDirectory()
		self.addCleanup(temporary_owner.cleanup)
		parallel_root = Path(temporary_owner.name)
		captured = mock.Mock(workspace_fingerprint="1" * 64)

		def materialize(
			_captured: object,
			destination: Path,
			*,
			deadline: float,
			verify_source: bool,
			identity_callback: object,
		) -> Path:
			del deadline
			self.assertFalse(verify_source)
			destination.mkdir()
			identity_callback(
				gf_maintenance.gf_parallel_validation._owned_directory_identity(  # noqa: SLF001
					destination.lstat()
				)
			)
			return destination

		def run_worker(
			request: dict[str, object],
			*,
			cancellation_event: threading.Event,
			expected_workspace_identity: tuple[int, int, int] | None = None,
		) -> dict[str, object]:
			self.assertFalse(cancellation_event.is_set())
			self.assertIsNotNone(expected_workspace_identity)
			self.assertEqual(request["mode"], gf_maintenance.gf_gut_shard_worker.CONTROL_MODE)
			return self._successful_worker_report(request, self._junit(request["scripts"]))

		with mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"materialize_workspace",
			side_effect=materialize,
		), mock.patch.object(
			gf_maintenance.gf_gut_shard_worker,
			"run_worker",
			side_effect=run_worker,
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value={"fingerprint": "1" * 64},
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"assert_source_matches_snapshot",
		), mock.patch.object(
			gf_maintenance.gf_parallel_validation,
			"run_parallel_shards",
			side_effect=AssertionError("nested worker supervisor forbidden"),
		) as nested_runner:
			report, executed, issues = gf_maintenance.execute_gut_shard_control_report(
				captured,
				parallel_root,
				inventory=self.INVENTORY,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
				deadline=time.perf_counter() + 300.0,
				cancellation_event=threading.Event(),
			)
		self.assertEqual(issues, [])
		self.assertEqual(executed, 1)
		self.assertIsNotNone(report)
		self.assertEqual(report["request"]["mode"], gf_maintenance.gf_gut_shard_worker.CONTROL_MODE)
		nested_runner.assert_not_called()

	def test_control_retains_root_when_materializer_refuses_replaced_child(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			cleanup_state = {"permitted": True}
			cancellation_event = threading.Event()

			def reject_replaced_child(
				_captured: object,
				target: Path,
				*,
				deadline: float,
				verify_source: bool,
				identity_callback: object,
			) -> Path:
				del deadline, identity_callback
				self.assertFalse(verify_source)
				target.mkdir()
				expected_identity = target.lstat()
				target.rename(target.parent / "original-s0")
				target.mkdir()
				(target / "replacement-marker.txt").write_text(
					"replacement",
					encoding="utf-8",
				)
				gf_maintenance.gf_parallel_validation._remove_owned_tree(  # noqa: SLF001
					target,
					expected_identity=expected_identity,
				)
				raise AssertionError("replaced child cleanup must fail closed")

			with mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"materialize_workspace",
				side_effect=reject_replaced_child,
			):
				control, executed, issues = (
					gf_maintenance.execute_gut_shard_control_report(
						mock.Mock(workspace_fingerprint="1" * 64),
						parallel_root,
						inventory=self.INVENTORY,
						manifest_digest="2" * 64,
						inventory_digest="3" * 64,
						import_timeout_seconds=60,
						gut_timeout_seconds=60,
						deadline=time.perf_counter() + 30.0,
						cancellation_event=cancellation_event,
						cleanup_state=cleanup_state,
					)
				)
			control_root = parallel_root / "c"
			self.assertIsNone(control)
			self.assertEqual(executed, 0)
			self.assertIn(
				"gut_shard_control_report_rejected",
				{issue["kind"] for issue in issues},
			)
			self.assertIn(
				"gut_shard_control_cleanup_failed",
				{issue["kind"] for issue in issues},
			)
			self.assertTrue(
				(control_root / "s0" / "replacement-marker.txt").is_file()
			)
			self.assertTrue((control_root / "original-s0").is_dir())
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])

	def test_control_distinguishes_pre_yield_workspace_acquisition_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parallel_root = Path(temporary_directory)
			foreign_control = parallel_root / "c"
			foreign_control.mkdir()
			marker = foreign_control / "foreign-marker.txt"
			marker.write_text("retain", encoding="utf-8")
			cleanup_state = {"permitted": True}
			cancellation_event = threading.Event()
			control, executed, issues = gf_maintenance.execute_gut_shard_control_report(
				mock.Mock(workspace_fingerprint="1" * 64),
				parallel_root,
				inventory=self.INVENTORY,
				manifest_digest="2" * 64,
				inventory_digest="3" * 64,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
				deadline=time.perf_counter() + 30.0,
				cancellation_event=cancellation_event,
				cleanup_state=cleanup_state,
			)
			kinds = {issue["kind"] for issue in issues}
			self.assertIsNone(control)
			self.assertEqual(executed, 0)
			self.assertIn("gut_shard_control_workspace_acquisition_failed", kinds)
			self.assertNotIn("gut_shard_control_cleanup_failed", kinds)
			self.assertTrue(marker.is_file())
			self.assertTrue(cancellation_event.is_set())
			self.assertFalse(cleanup_state["permitted"])

	def test_candidate_aggregate_requires_all_exact_shards_and_combines_junit(self) -> None:
		inventory = tuple(
			f"res://tests/gf_core/synthetic/test_{index}.gd"
			for index in range(9)
		)
		manifest = {
			"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(list(inventory)),
			"shards": [
				{
					"name": name,
					"role": "contracts" if index == 0 else "lane",
					"scripts": [inventory[index]],
				}
				for index, name in enumerate(gf_maintenance.gf_gut_sharding.SHARD_NAMES)
			],
		}
		manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(manifest)
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			reports = []
			for shard in manifest["shards"]:
				request = gf_maintenance.make_gut_shard_worker_request(
					shard,
					workspace,
					workspace_fingerprint_value="1" * 64,
					manifest_digest=manifest_digest,
					inventory_digest=manifest["inventory_digest"],
					remaining_seconds=120.0,
					import_timeout_seconds=60,
					gut_timeout_seconds=60,
				)
				reports.append(self._successful_worker_report(
					request,
					self._junit(shard["scripts"]),
				))
			with mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"validate_manifest",
				return_value=manifest,
			), mock.patch.object(
				gf_maintenance.gf_gut_sharding,
				"build_observation_report_from_script_records",
				return_value={"observation_only": True},
			):
				aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
					manifest,
					inventory,
					reports,
				)
			workspace_marker = str(workspace)
		with mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"validate_manifest",
			return_value=manifest,
		), mock.patch.object(
			gf_maintenance.gf_gut_sharding,
			"build_observation_report_from_script_records",
			return_value={"observation_only": True},
		):
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				manifest,
				inventory,
				reports,
			)
			missing = gf_maintenance.aggregate_gut_shard_candidate_reports(
				manifest,
				inventory,
				reports[:-1],
			)
		self.assertFalse(Path(workspace_marker).exists())
		self.assertTrue(aggregate["eligible"], aggregate["issues"])
		self.assertEqual(aggregate["shard_count"], 9)
		self.assertEqual(aggregate["script_count"], 9)
		self.assertEqual(aggregate["test_count"], 9)
		self.assertEqual(aggregate["assertion_count"], 9)
		self.assertFalse(missing["eligible"])

	def test_failed_worker_diagnostic_junit_never_becomes_candidate_evidence(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			reports = self._candidate_worker_reports(Path(temporary_directory))
			failed = reports[0]
			failed["ok"] = False
			failed["gut_result"] = {
				"ok": False,
				"exit_code": 1,
				"timed_out": False,
				"cancelled": False,
				"duration_seconds": 0.0,
			}
			failed["issues"] = [{
				"kind": "worker_gut_failed",
				"message": "fixture test failure",
				"phase": "gut",
			}]
			failed["continuation_safe"] = True
			validated = gf_maintenance.gf_gut_shard_worker.validate_report(failed)
			self.assertIsNotNone(validated["junit"])
			self.assertFalse(
				gf_maintenance.gut_shard_worker_report_eligible(validated)
			)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				reports,
			)
		self.assertFalse(aggregate["eligible"])
		self.assertEqual(aggregate["members"], [])
		self.assertIsNone(aggregate["semantic_result"])

	def test_qualification_ignores_duration_but_rejects_test_semantic_drift(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			candidate_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				candidate_reports,
			)
			request = gf_maintenance.make_gut_shard_worker_request(
				{
					"name": gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME,
					"role": gf_maintenance.gf_gut_shard_worker.CONTROL_ROLE,
					"scripts": list(self.INVENTORY),
				},
				workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest=aggregate["manifest_digest"],
				inventory_digest=aggregate["inventory_digest"],
				remaining_seconds=120.0,
				import_timeout_seconds=60,
				gut_timeout_seconds=60,
				mode=gf_maintenance.gf_gut_shard_worker.CONTROL_MODE,
			)
			control = self._successful_worker_report(
				request,
				self._junit(list(self.INVENTORY), duration=0.9),
			)
			equivalent = gf_maintenance.compare_gut_shard_qualification(
				aggregate,
				control,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				candidate_reports=candidate_reports,
			)
			forged = copy.deepcopy(control)
			forged["junit"]["scripts"][0]["tests"][0]["status"] = "failed"
			forged["junit"]["scripts"][0]["status_counts"] = {
				"passed": 0,
				"failed": 1,
				"pending": 0,
				"no_asserts": 0,
				"skipped": 0,
			}
			forged["junit"]["status_counts"] = {
				"passed": len(self.INVENTORY) - 1,
				"failed": 1,
				"pending": 0,
				"no_asserts": 0,
				"skipped": 0,
			}
			forged["junit"]["failure_test_count"] = 1
			forged["junit"]["failure_assertion_count"] = 1
			forged["junit"]["scripts"][0]["failure_test_count_lower_bound"] = 1
			forged["junit"]["scripts"][0]["failure_test_count_upper_bound"] = 1
			forged["junit"]["scripts"][0]["failure_assertion_count"] = 1
			forged["junit_digest"] = gf_maintenance.gf_gut_shard_worker.canonical_digest(
				forged["junit"]
			)
			workspace_marker = str(workspace)
		equivalent = gf_maintenance.compare_gut_shard_qualification(
			aggregate,
			control,
			manifest=self.MANIFEST,
			inventory=self.INVENTORY,
			candidate_reports=candidate_reports,
		)
		different = gf_maintenance.compare_gut_shard_qualification(
			aggregate,
			forged,
			manifest=self.MANIFEST,
			inventory=self.INVENTORY,
			candidate_reports=candidate_reports,
		)
		self.assertFalse(Path(workspace_marker).exists())
		self.assertTrue(equivalent["equivalent"], equivalent["issues"])
		self.assertTrue(equivalent["semantic_match"])
		self.assertFalse(different["equivalent"])
		self.assertFalse(different["semantic_match"])

	def test_qualification_rejects_partial_or_forged_candidate_aggregate(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			candidate_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				candidate_reports,
			)
			control = self._control_worker_report(workspace)

			partial = copy.deepcopy(aggregate)
			partial.pop("members")
			forged_semantic = copy.deepcopy(aggregate)
			forged_semantic["semantic_result"]["assertion_count"] += 1
			forged_count = copy.deepcopy(aggregate)
			forged_count["assertion_count"] += 1
			forged_status = copy.deepcopy(aggregate)
			forged_status["status_counts"] = {
				"passed": len(self.INVENTORY) - 1,
				"failed": 1,
				"pending": 0,
				"no_asserts": 0,
				"skipped": 0,
			}
			forged_member = copy.deepcopy(aggregate)
			forged_member["members"][0]["junit_report_digest"] = "c" * 64
			forged_member["member_evidence_digest"] = (
				gf_maintenance.gf_gut_shard_worker.canonical_digest(
					forged_member["members"]
				)
			)
			for candidate in (
				partial,
				forged_semantic,
				forged_count,
				forged_status,
				forged_member,
			):
				with self.subTest(fields=set(candidate)):
					result = gf_maintenance.compare_gut_shard_qualification(
						candidate,
						control,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						candidate_reports=candidate_reports,
					)
					self.assertFalse(result["equivalent"])
					self.assertFalse(result["candidate_eligible"])

			forged_failure = copy.deepcopy(aggregate)
			forged_script = forged_failure["scripts"][0]
			forged_script["tests"][0]["status"] = "failed"
			forged_script["status_counts"] = {
				"passed": 0,
				"failed": 1,
				"pending": 0,
				"no_asserts": 0,
				"skipped": 0,
			}
			forged_script["failure_test_count_lower_bound"] = 1
			forged_script["failure_test_count_upper_bound"] = 1
			forged_script["failure_assertion_count"] = 1
			forged_failure["status_counts"]["passed"] -= 1
			forged_failure["status_counts"]["failed"] = 1
			forged_failure["failure_test_count"] = 1
			forged_failure["failure_assertion_count"] = 1
			forged_failure["observation"] = (
				gf_maintenance.gf_gut_sharding.build_observation_report_from_script_records(
					self.MANIFEST,
					forged_failure["scripts"],
					failure_test_count=1,
				)
			)
			forged_failure["semantic_result"] = (
				gf_maintenance.gut_shard_semantic_result_from_evidence(
					forged_failure
				)
			)
			with self.assertRaisesRegex(ValueError, "only passing"):
				gf_maintenance.validate_gut_shard_candidate_aggregate(
					forged_failure,
					self.MANIFEST,
					self.INVENTORY,
					worker_reports=candidate_reports,
				)

	def test_equivalence_validator_rejects_forged_decision_booleans(self) -> None:
		valid_failure = {
			"schema_version": 1,
			"equivalent": False,
			"candidate_eligible": True,
			"control_eligible": True,
			"same_workspace": True,
			"same_manifest": True,
			"same_inventory": True,
			"semantic_match": False,
			"issues": [{
				"kind": "gut_shard_qualification_not_equivalent",
				"message": "fixture mismatch",
			}],
		}
		gf_maintenance.validate_gut_shard_equivalence_report(valid_failure)
		for mutation in (
			{**valid_failure, "equivalent": True},
			{**valid_failure, "semantic_match": "true"},
			{**valid_failure, "unexpected": False},
		):
			with self.assertRaises(ValueError):
				gf_maintenance.validate_gut_shard_equivalence_report(mutation)

	def test_top_report_validator_rejects_linked_positive_claim_mutations(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
			report.update({
				"ok": True,
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"candidate_eligible": True,
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports),
				"duration_seconds": 1.0,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
			})
			normalized = gf_maintenance.validate_gut_shard_run_report(
				report,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			self.assertTrue(normalized["ok"])
			other_reports = self._candidate_worker_reports(workspace)
			for worker_report in other_reports:
				worker_report["junit"] = self._junit(
					worker_report["request"]["scripts"],
					duration=0.9,
				)
				worker_report["junit_digest"] = (
					gf_maintenance.gf_gut_shard_worker.canonical_digest(
						worker_report["junit"]
					)
				)
			forged_independent = copy.deepcopy(report)
			forged_independent["shards"] = other_reports
			with self.assertRaisesRegex(ValueError, "not exactly derived"):
				gf_maintenance.validate_gut_shard_run_report(
					forged_independent,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			for mutate in (
				lambda value: value.__setitem__("candidate_eligible", False),
				lambda value: value.__setitem__("successful_shard_count", 8),
				lambda value: value["aggregate"].__setitem__("test_count", 100),
				lambda value: value["shards"].__setitem__(1, value["shards"][0]),
			):
				forged = copy.deepcopy(report)
				mutate(forged)
				with self.assertRaises((
					ValueError,
					gf_maintenance.gf_gut_shard_worker.GutShardWorkerError,
				)):
					gf_maintenance.validate_gut_shard_run_report(
						forged,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

	def test_top_report_validator_binds_private_workspace_and_timeout_policy(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
			report.update({
				"ok": True,
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"candidate_eligible": True,
				"shard_count": len(worker_reports),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports),
				"duration_seconds": 1.0,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
			})
			with self.assertRaisesRegex(ValueError, "bound private context"):
				gf_maintenance.validate_gut_shard_run_report(
					report,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
				)

			duplicate_nonce = copy.deepcopy(report)
			duplicate_nonce["shards"][1]["request"]["nonce"] = (
				duplicate_nonce["shards"][0]["request"]["nonce"]
			)
			duplicate_nonce["shards"][1]["request_digest"] = (
				gf_maintenance.gf_gut_shard_worker.canonical_digest(
					duplicate_nonce["shards"][1]["request"]
				)
			)
			with self.assertRaisesRegex(ValueError, "nonces must be exact and unique"):
				gf_maintenance.validate_gut_shard_run_report(
					duplicate_nonce,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			duplicate_workspace = copy.deepcopy(report)
			duplicate_workspace["shards"][1]["request"]["workspace_path"] = (
				duplicate_workspace["shards"][0]["request"]["workspace_path"]
			)
			duplicate_workspace["shards"][1]["request_digest"] = (
				gf_maintenance.gf_gut_shard_worker.canonical_digest(
					duplicate_workspace["shards"][1]["request"]
				)
			)
			with self.assertRaisesRegex(ValueError, "non-overlapping workspaces"):
				gf_maintenance.validate_gut_shard_run_report(
					duplicate_workspace,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			forged_timeout = copy.deepcopy(report)
			forged_timeout["candidate_gut_timeout_seconds"] += 1
			with self.assertRaisesRegex(ValueError, "timeout policy"):
				gf_maintenance.validate_gut_shard_run_report(
					forged_timeout,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			forged_duration = copy.deepcopy(report)
			forged_duration["shards"][0]["duration_seconds"] = 2.0
			with self.assertRaisesRegex(ValueError, "duration cannot be shorter"):
				gf_maintenance.validate_gut_shard_run_report(
					forged_duration,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			forged_wave_duration = copy.deepcopy(report)
			for shard in forged_wave_duration["shards"]:
				shard["duration_seconds"] = 100.0
			forged_wave_duration["duration_seconds"] = 100.0
			with self.assertRaisesRegex(ValueError, "duration cannot be shorter"):
				gf_maintenance.validate_gut_shard_run_report(
					forged_wave_duration,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			for issue_kind, error_pattern in (
				("totally_fabricated", "unknown producer kind"),
				("gut_shard_run_setup_failed", "cannot follow published candidate aggregate"),
			):
				forged_failure = copy.deepcopy(report)
				forged_failure.update({
					"ok": False,
					"candidate_eligible": False,
					"issues": [{
						"kind": issue_kind,
						"message": "synthetic unrelated failure",
					}],
				})
				with self.subTest(issue_kind=issue_kind), self.assertRaisesRegex(
					ValueError,
					error_pattern,
				):
					gf_maintenance.validate_gut_shard_run_report(
						forged_failure,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			duplicate_deadline = copy.deepcopy(report)
			duplicate_deadline.update({
				"ok": False,
				"candidate_eligible": False,
				"issues": [
					{
						"kind": "gut_shard_candidate_scheduling_deadline_exhausted",
						"message": "synthetic first parent deadline",
					},
					{
						"kind": "gut_shard_candidate_scheduling_deadline_exhausted",
						"message": "synthetic second parent deadline",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "duplicates singleton producer"):
				gf_maintenance.validate_gut_shard_run_report(
					duplicate_deadline,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			for control_issues in (
				[
					{
						"kind": "gut_shard_control_report_missing",
						"message": "synthetic unrequested control report",
					},
				],
				[
					{
						"kind": "gut_shard_control_deadline_exhausted",
						"message": "synthetic unrequested control deadline",
					},
					{
						"kind": "gut_shard_control_cleanup_failed",
						"message": "synthetic retained control root",
					},
				],
			):
				unrequested_control = copy.deepcopy(report)
				unrequested_control.update({
					"ok": False,
					"candidate_eligible": False,
					"issues": [
						*control_issues,
						{
							"kind": "gut_shard_validation_cleanup_failed",
							"message": "synthetic retained validation root",
						},
					],
				})
				with self.subTest(control_issues=control_issues), self.assertRaisesRegex(
					ValueError,
					"Unrequested GUT shard observation retained control-stage",
				):
					gf_maintenance.validate_gut_shard_run_report(
						unrequested_control,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			for wave_kind in (
				"gut_shard_worker_wave_deadline_exhausted",
				"gut_shard_worker_wave_failed",
			):
				complete_wave_failure = copy.deepcopy(report)
				complete_wave_failure.update({
					"ok": False,
					"candidate_eligible": False,
					"issues": [
						{
							"kind": wave_kind,
							"message": "synthetic impossible complete wave failure",
						},
						{
							"kind": "gut_shard_workspace_cleanup_failed",
							"message": "synthetic retained candidate batch",
						},
						{
							"kind": "gut_shard_validation_cleanup_failed",
							"message": "synthetic retained validation root",
						},
					],
				})
				with self.subTest(wave_kind=wave_kind), self.assertRaisesRegex(
					ValueError,
					(
						"deadline lacks pending result"
						if wave_kind == "gut_shard_worker_wave_deadline_exhausted"
						else "complete.*result set"
					),
				):
					gf_maintenance.validate_gut_shard_run_report(
						complete_wave_failure,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

	def test_top_report_validator_rejects_qualified_label_without_positive_claim(self) -> None:
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
		report.update({
			"qualification_status": "qualified",
			"duration_seconds": 0.1,
		})
		with self.assertRaisesRegex(ValueError, "qualified status"):
			gf_maintenance.validate_gut_shard_run_report(report)

	def test_top_report_validator_binds_probe_and_candidate_stop_to_aggregate_stage(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			)
			inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			)
			base = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
			base.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]),
				"qualification_status": "infrastructure_failed",
				"duration_seconds": 0.1,
				"issues": [{
					"kind": "gut_shard_run_setup_failed",
					"message": "synthetic setup failure after probe publication",
				}],
			})
			probe_without_aggregate = copy.deepcopy(base)
			probe_without_aggregate["isolation_probe"] = {
				"ok": True,
				"probe_count": 2,
				"fields": [
					"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
				],
			}
			with self.assertRaisesRegex(ValueError, "isolation must publish"):
				gf_maintenance.validate_gut_shard_run_report(
					probe_without_aggregate,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			stop_before_probe = copy.deepcopy(base)
			stop_before_probe["qualification_status"] = "cleanup_failed"
			stop_before_probe["issues"] = [
				{
					"kind": "gut_shard_candidate_scheduling_deadline_exhausted",
					"message": "synthetic candidate-phase deadline before isolation",
				},
				{
					"kind": "gut_shard_validation_cleanup_failed",
					"message": "synthetic retained validation root",
				},
			]
			with self.assertRaisesRegex(ValueError, "candidate-phase stop lacks"):
				gf_maintenance.validate_gut_shard_run_report(
					stop_before_probe,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			cleanup_without_setup = copy.deepcopy(base)
			cleanup_without_setup["qualification_status"] = "cleanup_failed"
			cleanup_without_setup["issues"] = [{
				"kind": "gut_shard_validation_cleanup_failed",
				"message": "synthetic retained root without setup cause",
			}]
			with self.assertRaisesRegex(ValueError, "exact setup-stage cause"):
				gf_maintenance.validate_gut_shard_run_report(
					cleanup_without_setup,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			bound_early_runtime_mismatch = copy.deepcopy(base)
			bound_early_runtime_mismatch["issues"] = [{
				"kind": "gut_shard_runtime_source_mismatch",
				"message": "synthetic early loaded-source mismatch with bound context",
			}]
			with self.assertRaisesRegex(ValueError, "retained bound execution context"):
				gf_maintenance.validate_gut_shard_run_report(
					bound_early_runtime_mismatch,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_top_report_validator_revokes_unrequested_candidate_when_issues_exist(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
			report.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"candidate_eligible": True,
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports),
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
				"issues": [{
					"kind": "gut_shard_final_source_drift",
					"message": "fixture final drift",
				}],
			})
			with self.assertRaisesRegex(ValueError, "candidate eligibility is not derived"):
				gf_maintenance.validate_gut_shard_run_report(
					report,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_top_report_validator_binds_workspace_acquisition_to_exact_phase(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			)
			inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			)
			empty_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				[],
			)
			candidate_acquisition = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=False,
			)
			candidate_acquisition.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]),
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"aggregate": empty_aggregate,
				"issues": [
					{
						"kind": "gut_shard_candidate_workspace_acquisition_failed",
						"message": "synthetic foreign candidate batch",
					},
					*copy.deepcopy(empty_aggregate["issues"]),
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				candidate_acquisition,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			for case, mutate in (
				(
					"missing_outer_cleanup",
					lambda value: value["issues"].pop(),
				),
				(
					"forged_inner_cleanup",
					lambda value: value["issues"].insert(1, {
						"kind": "gut_shard_workspace_cleanup_failed",
						"message": "synthetic impossible inner cleanup",
					}),
				),
				(
					"redundant_stop",
					lambda value: value["issues"].insert(1, {
						"kind": "gut_shard_candidate_scheduling_deadline_exhausted",
						"message": "synthetic redundant deadline",
					}),
				),
				(
					"impossible_final_source_phase",
					lambda value: value["issues"].insert(1, {
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic unreachable final source drift",
					}),
				),
				(
					"unreported_worker",
					lambda value: value.update({
						"executed_shard_count": 1,
						"unreported_shard_count": 1,
						"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 1,
					}),
				),
			):
				forged = copy.deepcopy(candidate_acquisition)
				mutate(forged)
				with self.subTest(case=case), self.assertRaises(ValueError):
					gf_maintenance.validate_gut_shard_run_report(
						forged,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			candidate_reports = self._candidate_worker_reports(workspace)
			eligible_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				candidate_reports,
			)
			control_acquisition = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=True,
			)
			control_acquisition.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(candidate_reports),
				"executed_shard_count": len(candidate_reports),
				"completed_shard_count": len(candidate_reports),
				"successful_shard_count": len(candidate_reports),
				"duration_seconds": 1.0,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": candidate_reports,
				"aggregate": eligible_aggregate,
				"qualification_status": "cleanup_failed",
				"issues": [
					{
						"kind": "gut_shard_control_workspace_acquisition_failed",
						"message": "synthetic foreign control root",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				control_acquisition,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			for case, extra_issue in (
				(
					"forged_inner_cleanup",
					{
						"kind": "gut_shard_control_cleanup_failed",
						"message": "synthetic impossible control cleanup",
					},
				),
				(
					"redundant_control_stop",
					{
						"kind": "gut_shard_control_report_missing",
						"message": "synthetic redundant missing report",
					},
				),
				(
					"impossible_final_source_phase",
					{
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic unreachable final source drift",
					},
				),
			):
				forged = copy.deepcopy(control_acquisition)
				forged["issues"].insert(1, extra_issue)
				with self.subTest(case=case), self.assertRaises(ValueError):
					gf_maintenance.validate_gut_shard_run_report(
						forged,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

	def test_top_report_validator_enforces_terminal_status_evidence(self) -> None:
		for status, error_pattern in (
			("candidate_ineligible", "failed aggregate evidence"),
			("control_ineligible", "failed control evidence"),
			("not_equivalent", "complete mismatch evidence"),
			("cleanup_failed", "terminal priority"),
		):
			with self.subTest(status=status):
				report = gf_maintenance.make_gut_shard_run_report(
					jobs=2,
					qualify=True,
				)
				report.update({
					"qualification_status": status,
					"duration_seconds": 0.1,
				})
				with self.assertRaisesRegex(ValueError, error_pattern):
					gf_maintenance.validate_gut_shard_run_report(report)

		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			control_ineligible = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=True,
			)
			control_ineligible.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"candidate_eligible": True,
				"qualification_status": "control_ineligible",
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports),
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
				"issues": [{
					"kind": "gut_shard_control_report_missing",
					"message": "control failed before publishing a report",
				}],
			})
			normalized = gf_maintenance.validate_gut_shard_run_report(
				control_ineligible,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
		self.assertEqual(normalized["qualification_status"], "control_ineligible")
		self.assertIsNone(normalized["control"])

	def test_terminal_candidate_state_requires_every_manifest_shard_report(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)[:-1]
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			control = self._control_worker_report(workspace)
			report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
			report.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"qualification_status": "candidate_ineligible",
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports),
				"not_scheduled_shard_count": 1,
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
				"control": control,
				"issues": copy.deepcopy(aggregate["issues"]),
			})
			with self.assertRaisesRegex(ValueError, "incomplete candidate partition"):
				gf_maintenance.validate_gut_shard_run_report(
					report,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_terminal_candidate_state_rejects_infrastructure_worker_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			worker_reports = self._candidate_worker_reports(workspace)
			failed_worker = self._failed_worker_report(
				worker_reports[0]["request"],
				kind="worker_deadline_exhausted",
			)
			worker_reports[0] = failed_worker
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				worker_reports,
			)
			worker_issue = failed_worker["issues"][0]
			report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
			report.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					self.MANIFEST
				),
				"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
					list(self.INVENTORY)
				),
				"inventory_count": len(self.INVENTORY),
				"qualification_status": "candidate_ineligible",
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(worker_reports),
				"completed_shard_count": len(worker_reports),
				"successful_shard_count": len(worker_reports) - 1,
				"failed_shard_count": 1,
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": worker_reports,
				"aggregate": aggregate,
				"control": self._control_worker_report(workspace),
				"issues": [
					{
						"kind": worker_issue["kind"],
						"message": (
							f"{failed_worker['request']['shard_name']}: "
							f"{worker_issue['message']}"
						),
					},
					*copy.deepcopy(aggregate["issues"]),
				],
			})
			with self.assertRaisesRegex(ValueError, "derived worker orchestration debt"):
				gf_maintenance.validate_gut_shard_run_report(
					report,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_top_report_validator_binds_reports_to_scheduled_wave_prefix(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			all_reports = self._candidate_worker_reports(workspace)
			manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			)
			inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			)

			for case, reports, executed, extra_issue in (
				(
					"all_unreported",
					[],
					len(self.MANIFEST["shards"]),
					{
						"kind": "gut_shard_worker_exception",
						"message": "synthetic fault wave",
					},
				),
				(
					"last_shard_first",
					[all_reports[-1]],
					1,
					None,
				),
				(
					"partial_second_wave_without_schedule_failure",
					all_reports[:2],
					3,
					{
						"kind": "gut_shard_worker_exception",
						"message": "synthetic result fault",
					},
				),
				(
					"final_drift_cannot_explain_an_incomplete_candidate_schedule",
					all_reports[:2],
					2,
					{
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic post-candidate source drift",
					},
				),
			):
				with self.subTest(case=case):
					aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
						self.MANIFEST,
						self.INVENTORY,
						reports,
					)
					top_issues = (
						[extra_issue] if extra_issue is not None else []
					) + copy.deepcopy(aggregate["issues"])
					if case == "final_drift_cannot_explain_an_incomplete_candidate_schedule":
						top_issues = [
							*copy.deepcopy(aggregate["issues"]),
							extra_issue,
							{
								"kind": "gut_shard_validation_cleanup_failed",
								"message": "synthetic retained validation root",
							},
						]
					report = gf_maintenance.make_gut_shard_run_report(
						jobs=2,
						qualify=False,
					)
					report.update({
						"workspace_fingerprint": "1" * 64,
						"manifest_digest": manifest_digest,
						"inventory_digest": inventory_digest,
						"inventory_count": len(self.INVENTORY),
						"shard_count": len(self.MANIFEST["shards"]),
						"executed_shard_count": executed,
						"completed_shard_count": len(reports),
						"successful_shard_count": len(reports),
						"unreported_shard_count": executed - len(reports),
						"not_scheduled_shard_count": (
							len(self.MANIFEST["shards"]) - executed
						),
						"duration_seconds": 1.0,
						"isolation_probe": {
							"ok": True,
							"probe_count": 2,
							"fields": [
								"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
							],
						},
						"shards": reports,
						"aggregate": aggregate,
						"issues": top_issues,
					})
				with self.assertRaisesRegex(
					ValueError,
					"planned worker wave|scheduled wave|scheduled prefix|incomplete candidate partition|candidate infrastructure stop",
				):
					gf_maintenance.validate_gut_shard_run_report(
						report,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			empty_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				[],
			)
			too_many_worker_exceptions = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=False,
			)
			too_many_worker_exceptions.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": 2,
				"unreported_shard_count": 2,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 2,
				"duration_seconds": 1.0,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"aggregate": empty_aggregate,
				"issues": [
					*[
						{
							"kind": "gut_shard_worker_exception",
							"message": f"synthetic worker exception {index}",
						}
						for index in range(3)
					],
					{
						"kind": "gut_shard_workspace_cleanup_failed",
						"message": "synthetic retained candidate batch",
					},
					*copy.deepcopy(empty_aggregate["issues"]),
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			with self.assertRaisesRegex(
				ValueError,
				"worker-result failure|exceeds unreported execution",
			):
				gf_maintenance.validate_gut_shard_run_report(
					too_many_worker_exceptions,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			reachable_boundary_then_deadline = copy.deepcopy(
				too_many_worker_exceptions
			)
			reachable_boundary_then_deadline["issues"] = [
				{
					"kind": "gut_shard_workspace_fingerprint_boundary_unproven",
					"message": (
						f"{self.MANIFEST['shards'][0]['name']}: "
						"synthetic early boundary failure"
					),
				},
				{
					"kind": "gut_shard_worker_wave_deadline_exhausted",
					"message": "synthetic peer deadline",
				},
				{
					"kind": "gut_shard_workspace_cleanup_failed",
					"message": "synthetic retained candidate batch",
				},
				*copy.deepcopy(empty_aggregate["issues"]),
				{
					"kind": "gut_shard_validation_cleanup_failed",
					"message": "synthetic retained validation root",
				},
			]
			gf_maintenance.validate_gut_shard_run_report(
				reachable_boundary_then_deadline,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			wave_deadline_with_fingerprint_boundary = copy.deepcopy(
				reachable_boundary_then_deadline
			)
			wave_deadline_with_fingerprint_boundary["issues"][:2] = list(reversed(
				wave_deadline_with_fingerprint_boundary["issues"][:2]
			))
			with self.assertRaisesRegex(
				ValueError,
				"boundary and worker-wave deadline ordering is unreachable",
			):
				gf_maintenance.validate_gut_shard_run_report(
					wave_deadline_with_fingerprint_boundary,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			boundary_deadline_then_wave_failure = copy.deepcopy(
				reachable_boundary_then_deadline
			)
			boundary_deadline_then_wave_failure["issues"].insert(2, {
				"kind": "gut_shard_worker_wave_failed",
				"message": "synthetic failure while the peer remained unresolved",
			})
			gf_maintenance.validate_gut_shard_run_report(
				boundary_deadline_then_wave_failure,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			for label, executed, cause_issues in (
				(
					"deadline-before-schedule",
					1,
					[
						{
							"kind": "gut_shard_worker_wave_deadline_exhausted",
							"message": "synthetic impossible early deadline",
						},
						{
							"kind": "gut_shard_worker_schedule_failed",
							"message": (
								f"{self.MANIFEST['shards'][1]['name']}: "
								"synthetic late submit failure"
							),
						},
					],
				),
				(
					"wave-failed-before-deadline",
					2,
					[
						{
							"kind": "gut_shard_worker_wave_failed",
							"message": "synthetic impossible early outer failure",
						},
						{
							"kind": "gut_shard_worker_wave_deadline_exhausted",
							"message": "synthetic late deadline",
						},
					],
				),
				(
					"fingerprint-before-schedule",
					1,
					[
						{
							"kind": "gut_shard_workspace_fingerprint_boundary_unproven",
							"message": (
								f"{self.MANIFEST['shards'][0]['name']}: "
								"synthetic impossible pre-schedule result"
							),
						},
						{
							"kind": "gut_shard_worker_schedule_failed",
							"message": (
								f"{self.MANIFEST['shards'][1]['name']}: "
								"synthetic late submit failure"
							),
						},
					],
				),
				(
					"exception-before-schedule",
					1,
					[
						{
							"kind": "gut_shard_worker_exception",
							"message": (
								f"{self.MANIFEST['shards'][0]['name']}: "
								"synthetic impossible pre-schedule result"
							),
						},
						{
							"kind": "gut_shard_worker_schedule_failed",
							"message": (
								f"{self.MANIFEST['shards'][1]['name']}: "
								"synthetic late submit failure"
							),
						},
					],
				),
			):
				unreachable_wave_order = copy.deepcopy(too_many_worker_exceptions)
				unreachable_wave_order.update({
					"executed_shard_count": executed,
					"unreported_shard_count": executed,
					"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - executed,
					"issues": [
						*copy.deepcopy(cause_issues),
						{
							"kind": "gut_shard_workspace_cleanup_failed",
							"message": "synthetic retained candidate batch",
						},
						*copy.deepcopy(empty_aggregate["issues"]),
						{
							"kind": "gut_shard_validation_cleanup_failed",
							"message": "synthetic retained validation root",
						},
					],
				})
				with self.subTest(label=label), self.assertRaisesRegex(
					ValueError,
					"did not precede|did not follow",
				):
					gf_maintenance.validate_gut_shard_run_report(
						unreachable_wave_order,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			candidate_deadline_issue = {
				"kind": "gut_shard_worker_wave_deadline_exhausted",
				"message": "synthetic single-worker parent deadline",
			}
			candidate_exception_issue = {
				"kind": "gut_shard_worker_exception",
				"message": (
					f"{self.MANIFEST['shards'][0]['name']}: "
					"synthetic late worker exception"
				),
			}
			candidate_cleanup_issue = {
				"kind": "gut_shard_workspace_cleanup_failed",
				"message": "synthetic retained candidate batch",
			}
			outer_cleanup_issue = {
				"kind": "gut_shard_validation_cleanup_failed",
				"message": "synthetic retained validation root",
			}
			single_worker_deadline = gf_maintenance.make_gut_shard_run_report(
				jobs=1,
				qualify=False,
			)
			single_worker_deadline.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": 1,
				"unreported_shard_count": 1,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 1,
				"duration_seconds": 1.0,
				"isolation_probe": copy.deepcopy(
					too_many_worker_exceptions["isolation_probe"]
				),
				"aggregate": copy.deepcopy(empty_aggregate),
				"issues": [
					candidate_deadline_issue,
					candidate_exception_issue,
					candidate_cleanup_issue,
					*copy.deepcopy(empty_aggregate["issues"]),
					outer_cleanup_issue,
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				single_worker_deadline,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			single_worker_reverse = copy.deepcopy(single_worker_deadline)
			single_worker_reverse["issues"][:2] = list(reversed(
				single_worker_reverse["issues"][:2]
			))
			with self.assertRaisesRegex(ValueError, "single-worker result failure preceded"):
				gf_maintenance.validate_gut_shard_run_report(
					single_worker_reverse,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			partial_schedule_deadline = copy.deepcopy(too_many_worker_exceptions)
			partial_schedule_deadline.update({
				"executed_shard_count": 1,
				"unreported_shard_count": 1,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 1,
				"issues": [
					{
						"kind": "gut_shard_worker_schedule_failed",
						"message": (
							f"{self.MANIFEST['shards'][1]['name']}: "
							"synthetic second submit failure"
						),
					},
					candidate_deadline_issue,
					candidate_exception_issue,
					candidate_cleanup_issue,
					*copy.deepcopy(empty_aggregate["issues"]),
					outer_cleanup_issue,
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				partial_schedule_deadline,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			partial_schedule_reverse = copy.deepcopy(partial_schedule_deadline)
			partial_schedule_reverse["issues"][1:3] = list(reversed(
				partial_schedule_reverse["issues"][1:3]
			))
			with self.assertRaisesRegex(ValueError, "single-worker result failure preceded"):
				gf_maintenance.validate_gut_shard_run_report(
					partial_schedule_reverse,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			candidate_cleanup_before_causes = copy.deepcopy(partial_schedule_deadline)
			candidate_cleanup_before_causes["issues"] = [
				candidate_cleanup_before_causes["issues"][3],
				*candidate_cleanup_before_causes["issues"][:3],
				*candidate_cleanup_before_causes["issues"][4:],
			]
			with self.assertRaisesRegex(ValueError, "workspace cleanup preceded"):
				gf_maintenance.validate_gut_shard_run_report(
					candidate_cleanup_before_causes,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			aggregate_before_candidate_cleanup = copy.deepcopy(partial_schedule_deadline)
			aggregate_before_candidate_cleanup["issues"] = [
				*aggregate_before_candidate_cleanup["issues"][:3],
				*copy.deepcopy(empty_aggregate["issues"]),
				candidate_cleanup_issue,
				outer_cleanup_issue,
			]
			with self.assertRaisesRegex(ValueError, "followed its derived"):
				gf_maintenance.validate_gut_shard_run_report(
					aggregate_before_candidate_cleanup,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			outer_cleanup_before_candidate = copy.deepcopy(partial_schedule_deadline)
			outer_cleanup_before_candidate["issues"] = [
				outer_cleanup_before_candidate["issues"][-1],
				*outer_cleanup_before_candidate["issues"][:-1],
			]
			with self.assertRaisesRegex(ValueError, "validation cleanup evidence did not follow"):
				gf_maintenance.validate_gut_shard_run_report(
					outer_cleanup_before_candidate,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			outer_cleanup_before_aggregate = copy.deepcopy(partial_schedule_deadline)
			outer_cleanup_before_aggregate["issues"] = [
				*outer_cleanup_before_aggregate["issues"][:4],
				outer_cleanup_issue,
				*copy.deepcopy(empty_aggregate["issues"]),
			]
			with self.assertRaisesRegex(ValueError, "validation cleanup evidence did not follow"):
				gf_maintenance.validate_gut_shard_run_report(
					outer_cleanup_before_aggregate,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			deadline_worker = self._failed_worker_report(
				all_reports[0]["request"],
				kind="worker_deadline_exhausted",
			)
			deadline_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				[deadline_worker],
			)
			deadline_nested_issue = {
				"kind": deadline_worker["issues"][0]["kind"],
				"message": (
					f"{deadline_worker['request']['shard_name']}: "
					f"{deadline_worker['issues'][0]['message']}"
				),
			}
			derived_deadline_issue = {
				"kind": "gut_shard_worker_deadline_exhausted",
				"message": (
					f"{deadline_worker['request']['shard_name']}: worker-local deadline "
					"or phase timeout stopped the remaining shard schedule."
				),
			}
			wave_failure_issue = {
				"kind": "gut_shard_worker_wave_failed",
				"message": "synthetic failure while draining the worker wave",
			}
			schedule_failure_issue = {
				"kind": "gut_shard_worker_schedule_failed",
				"message": (
					f"{self.MANIFEST['shards'][1]['name']}: "
					"synthetic second submit failure"
				),
			}

			def derived_worker_failure_report(
				*,
				jobs: int,
				executed: int,
				worker: dict[str, object],
				aggregate: dict[str, object],
				causes: list[dict[str, str]],
				nested_issue: dict[str, str],
			) -> dict[str, object]:
				result = gf_maintenance.make_gut_shard_run_report(
					jobs=jobs,
					qualify=False,
				)
				result.update({
					"workspace_fingerprint": "1" * 64,
					"manifest_digest": manifest_digest,
					"inventory_digest": inventory_digest,
					"inventory_count": len(self.INVENTORY),
					"shard_count": len(self.MANIFEST["shards"]),
					"executed_shard_count": executed,
					"completed_shard_count": 1,
					"failed_shard_count": 1,
					"unreported_shard_count": executed - 1,
					"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - executed,
					"duration_seconds": 1.0,
					"isolation_probe": copy.deepcopy(
						too_many_worker_exceptions["isolation_probe"]
					),
					"shards": [worker],
					"aggregate": aggregate,
					"issues": [
						*copy.deepcopy(causes),
						candidate_cleanup_issue,
						copy.deepcopy(nested_issue),
						*copy.deepcopy(aggregate["issues"]),
						outer_cleanup_issue,
					],
				})
				return result

			for label, executed, causes in (
				(
					"schedule-before-derived-result",
					1,
					[schedule_failure_issue, derived_deadline_issue],
				),
				(
					"derived-result-before-wave-failure",
					2,
					[derived_deadline_issue, wave_failure_issue],
				),
			):
				derived_order = derived_worker_failure_report(
					jobs=2,
					executed=executed,
					worker=deadline_worker,
					aggregate=deadline_aggregate,
					causes=causes,
					nested_issue=deadline_nested_issue,
				)
				with self.subTest(label=label):
					gf_maintenance.validate_gut_shard_run_report(
						derived_order,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)
					reversed_derived_order = copy.deepcopy(derived_order)
					reversed_derived_order["issues"][:2] = list(reversed(
						reversed_derived_order["issues"][:2]
					))
					with self.assertRaisesRegex(ValueError, "did not precede|did not follow"):
						gf_maintenance.validate_gut_shard_run_report(
							reversed_derived_order,
							manifest=self.MANIFEST,
							inventory=self.INVENTORY,
							expected_workspace_fingerprint="1" * 64,
							expected_validation_root=workspace,
						)

			unowned_deadline_worker = copy.deepcopy(deadline_worker)
			unowned_deadline_worker.update({
				"process_boundary_quiescent": False,
				"workspace_cleanup_permitted": False,
				"continuation_safe": False,
			})
			unowned_deadline_aggregate = (
				gf_maintenance.aggregate_gut_shard_candidate_reports(
					self.MANIFEST,
					self.INVENTORY,
					[unowned_deadline_worker],
				)
			)
			ownership_issue = {
				"kind": "gut_shard_workspace_ownership_unproven",
				"message": (
					f"{unowned_deadline_worker['request']['shard_name']}: "
					"process-boundary, workspace ownership, or worker-owned cleanup "
					"was not proven; the validation workspace must be retained."
				),
			}
			parent_deadline_issue = {
				"kind": "gut_shard_worker_wave_deadline_exhausted",
				"message": "synthetic parent deadline before retained worker evidence",
			}
			single_worker_owned_debt = derived_worker_failure_report(
				jobs=1,
				executed=1,
				worker=unowned_deadline_worker,
				aggregate=unowned_deadline_aggregate,
				causes=[
					parent_deadline_issue,
					derived_deadline_issue,
					ownership_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			gf_maintenance.validate_gut_shard_run_report(
				single_worker_owned_debt,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			for label, order in (
				("result-before-parent-deadline", [1, 0, 2]),
				("ownership-before-result", [0, 2, 1]),
			):
				forged_order = copy.deepcopy(single_worker_owned_debt)
				forged_order["issues"][:3] = [
					forged_order["issues"][index] for index in order
				]
				with self.subTest(label=label), self.assertRaisesRegex(
					ValueError,
					(
						"single-worker result failure preceded|ownership debt preceded|"
						"are not adjacent"
					),
				):
					gf_maintenance.validate_gut_shard_run_report(
						forged_order,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
							expected_validation_root=workspace,
						)

			fingerprint_issue = {
				"kind": "gut_shard_workspace_fingerprint_boundary_unproven",
				"message": (
					f"{self.MANIFEST['shards'][1]['name']}: "
					"synthetic early fingerprint boundary debt"
				),
			}
			fingerprint_then_retained_peer = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=unowned_deadline_worker,
				aggregate=unowned_deadline_aggregate,
				causes=[
					fingerprint_issue,
					parent_deadline_issue,
					derived_deadline_issue,
					ownership_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			gf_maintenance.validate_gut_shard_run_report(
				fingerprint_then_retained_peer,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			surplus_wave_failure = copy.deepcopy(fingerprint_then_retained_peer)
			surplus_wave_failure["issues"].insert(4, wave_failure_issue)
			with self.assertRaisesRegex(ValueError, "does not explain unresolved"):
				gf_maintenance.validate_gut_shard_run_report(
					surplus_wave_failure,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			fingerprint_without_peer_debt = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=deadline_worker,
				aggregate=deadline_aggregate,
				causes=[
					fingerprint_issue,
					parent_deadline_issue,
					derived_deadline_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			with self.assertRaisesRegex(ValueError, "lacks retained ownership debt"):
				gf_maintenance.validate_gut_shard_run_report(
					fingerprint_without_peer_debt,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			early_exception_issue = {
				"kind": "gut_shard_worker_exception",
				"message": (
					f"{self.MANIFEST['shards'][1]['name']}: "
					"synthetic early worker exception"
				),
			}
			for label, causes in (
				(
					"owned-result-before-peer-exception",
					[derived_deadline_issue, ownership_issue, early_exception_issue],
				),
				(
					"peer-exception-before-owned-result",
					[early_exception_issue, derived_deadline_issue, ownership_issue],
				),
			):
				adjacent_owned_result = derived_worker_failure_report(
					jobs=2,
					executed=2,
					worker=unowned_deadline_worker,
					aggregate=unowned_deadline_aggregate,
					causes=causes,
					nested_issue=deadline_nested_issue,
				)
				with self.subTest(label=label):
					gf_maintenance.validate_gut_shard_run_report(
						adjacent_owned_result,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)
			interleaved_owned_result = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=unowned_deadline_worker,
				aggregate=unowned_deadline_aggregate,
				causes=[
					derived_deadline_issue,
					early_exception_issue,
					ownership_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			with self.assertRaisesRegex(ValueError, "are not adjacent"):
				gf_maintenance.validate_gut_shard_run_report(
					interleaved_owned_result,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			safe_partial_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				[all_reports[0]],
			)
			early_exception_with_safe_peer = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=False,
			)
			early_exception_with_safe_peer.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": 2,
				"completed_shard_count": 1,
				"successful_shard_count": 1,
				"unreported_shard_count": 1,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 2,
				"duration_seconds": 1.0,
				"isolation_probe": copy.deepcopy(
					too_many_worker_exceptions["isolation_probe"]
				),
				"shards": [all_reports[0]],
				"aggregate": safe_partial_aggregate,
				"issues": [
					early_exception_issue,
					parent_deadline_issue,
					candidate_cleanup_issue,
					*copy.deepcopy(safe_partial_aggregate["issues"]),
					outer_cleanup_issue,
				],
			})
			with self.assertRaisesRegex(ValueError, "retained an unowned peer report"):
				gf_maintenance.validate_gut_shard_run_report(
					early_exception_with_safe_peer,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			deadline_then_late_exception = copy.deepcopy(early_exception_with_safe_peer)
			deadline_then_late_exception["issues"][:2] = list(reversed(
				deadline_then_late_exception["issues"][:2]
			))
			gf_maintenance.validate_gut_shard_run_report(
				deadline_then_late_exception,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			early_exception_with_missing_peer = copy.deepcopy(
				reachable_boundary_then_deadline
			)
			early_exception_with_missing_peer["issues"][0] = early_exception_issue
			gf_maintenance.validate_gut_shard_run_report(
				early_exception_with_missing_peer,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			early_exception_with_owned_peer = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=unowned_deadline_worker,
				aggregate=unowned_deadline_aggregate,
				causes=[
					early_exception_issue,
					parent_deadline_issue,
					derived_deadline_issue,
					ownership_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			gf_maintenance.validate_gut_shard_run_report(
				early_exception_with_owned_peer,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			first_exception_issue = {
				"kind": "gut_shard_worker_exception",
				"message": (
					f"{self.MANIFEST['shards'][0]['name']}: "
					"synthetic first worker exception"
				),
			}
			all_scoped_before_deadline = copy.deepcopy(
				early_exception_with_missing_peer
			)
			all_scoped_before_deadline["issues"] = [
				first_exception_issue,
				early_exception_issue,
				parent_deadline_issue,
				candidate_cleanup_issue,
				*copy.deepcopy(empty_aggregate["issues"]),
				outer_cleanup_issue,
			]
			with self.assertRaisesRegex(ValueError, "deadline lacks pending result"):
				gf_maintenance.validate_gut_shard_run_report(
					all_scoped_before_deadline,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			for label, prefix in (
				(
					"deadline-before-both-scoped-results",
					[parent_deadline_issue, first_exception_issue, early_exception_issue],
				),
				(
					"deadline-between-scoped-results",
					[first_exception_issue, parent_deadline_issue, early_exception_issue],
				),
			):
				reachable_scoped_deadline = copy.deepcopy(
					all_scoped_before_deadline
				)
				reachable_scoped_deadline["issues"][:3] = prefix
				with self.subTest(label=label):
					gf_maintenance.validate_gut_shard_run_report(
						reachable_scoped_deadline,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			post_deadline_result_without_debt = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=deadline_worker,
				aggregate=deadline_aggregate,
				causes=[parent_deadline_issue, derived_deadline_issue],
				nested_issue=deadline_nested_issue,
			)
			with self.assertRaisesRegex(ValueError, "result lacks ownership debt"):
				gf_maintenance.validate_gut_shard_run_report(
					post_deadline_result_without_debt,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			pre_deadline_result_without_debt = copy.deepcopy(
				post_deadline_result_without_debt
			)
			pre_deadline_result_without_debt["issues"][:2] = list(reversed(
				pre_deadline_result_without_debt["issues"][:2]
			))
			gf_maintenance.validate_gut_shard_run_report(
				pre_deadline_result_without_debt,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			straddled_result_ownership = derived_worker_failure_report(
				jobs=2,
				executed=2,
				worker=unowned_deadline_worker,
				aggregate=unowned_deadline_aggregate,
				causes=[
					derived_deadline_issue,
					parent_deadline_issue,
					ownership_issue,
				],
				nested_issue=deadline_nested_issue,
			)
			with self.assertRaisesRegex(
				ValueError,
				"straddle its wave deadline|are not adjacent",
			):
				gf_maintenance.validate_gut_shard_run_report(
					straddled_result_ownership,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			for label, prefix in (
				(
					"result-and-ownership-before-deadline",
					[derived_deadline_issue, ownership_issue, parent_deadline_issue],
				),
				(
					"result-and-ownership-after-deadline",
					[parent_deadline_issue, derived_deadline_issue, ownership_issue],
				),
			):
				reachable_owned_deadline = copy.deepcopy(straddled_result_ownership)
				reachable_owned_deadline["issues"][:3] = prefix
				with self.subTest(label=label):
					gf_maintenance.validate_gut_shard_run_report(
						reachable_owned_deadline,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
							expected_validation_root=workspace,
					)

			two_report_owned_aggregate = (
				gf_maintenance.aggregate_gut_shard_candidate_reports(
					self.MANIFEST,
					self.INVENTORY,
					[unowned_deadline_worker, all_reports[1]],
				)
			)
			completed_owned_wave = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=False,
			)
			completed_owned_wave.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": 2,
				"completed_shard_count": 2,
				"successful_shard_count": 1,
				"failed_shard_count": 1,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 2,
				"duration_seconds": 1.0,
				"isolation_probe": copy.deepcopy(
					too_many_worker_exceptions["isolation_probe"]
				),
				"shards": [unowned_deadline_worker, all_reports[1]],
				"aggregate": two_report_owned_aggregate,
				"issues": [
					derived_deadline_issue,
					ownership_issue,
					parent_deadline_issue,
					candidate_cleanup_issue,
					deadline_nested_issue,
					*copy.deepcopy(two_report_owned_aggregate["issues"]),
					outer_cleanup_issue,
				],
			})
			with self.assertRaisesRegex(ValueError, "deadline lacks pending result"):
				gf_maintenance.validate_gut_shard_run_report(
					completed_owned_wave,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			deadline_then_completed_owned_wave = copy.deepcopy(completed_owned_wave)
			deadline_then_completed_owned_wave["issues"][:3] = [
				parent_deadline_issue,
				derived_deadline_issue,
				ownership_issue,
			]
			gf_maintenance.validate_gut_shard_run_report(
				deadline_then_completed_owned_wave,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

	def test_top_report_validator_binds_control_and_equivalence_to_completed_candidates(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			all_reports = self._candidate_worker_reports(workspace)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				all_reports,
			)
			control = self._control_worker_report(workspace)
			equivalence = gf_maintenance.compare_gut_shard_qualification(
				aggregate,
				control,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				candidate_reports=all_reports,
			)
			manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			)
			inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			)
			qualified = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=True)
			qualified.update({
				"ok": True,
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"candidate_eligible": True,
				"qualified": True,
				"qualification_status": "qualified",
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": len(all_reports),
				"completed_shard_count": len(all_reports),
				"successful_shard_count": len(all_reports),
				"duration_seconds": 1.0,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": all_reports,
				"aggregate": aggregate,
				"control": control,
				"equivalence": equivalence,
			})
			gf_maintenance.validate_gut_shard_run_report(
				qualified,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			failed_control = self._failed_worker_report(control["request"])
			for primary_kind, cleanup_scope in (
				("gut_shard_control_workspace_acquisition_failed", "outer"),
				("gut_shard_control_deadline_exhausted", "inner"),
				("gut_shard_control_report_rejected", "inner"),
				("gut_shard_control_report_missing", "none"),
			):
				retained_control = copy.deepcopy(qualified)
				cleanup_issues = []
				if cleanup_scope == "inner":
					cleanup_issues.append(
						{
							"kind": "gut_shard_control_cleanup_failed",
							"message": "synthetic retained control root",
						}
					)
				if cleanup_scope != "none":
					cleanup_issues.append(
						{
							"kind": "gut_shard_validation_cleanup_failed",
							"message": "synthetic retained validation root",
						}
					)
				retained_control.update({
					"ok": False,
					"candidate_eligible": cleanup_scope == "none",
					"qualified": False,
					"qualification_status": (
						"cleanup_failed" if cleanup_scope != "none" else "control_ineligible"
					),
					"control": copy.deepcopy(failed_control),
					"equivalence": None,
					"issues": [
						*[
							{
								"kind": issue["kind"],
								"message": issue["message"],
							}
							for issue in failed_control["issues"]
						],
						{
							"kind": primary_kind,
							"message": "synthetic primary control failure",
						},
						*cleanup_issues,
					],
				})
				with self.subTest(primary_kind=primary_kind), self.assertRaisesRegex(
					ValueError,
					"control primary failure retained a control report",
				):
					gf_maintenance.validate_gut_shard_run_report(
						retained_control,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			deadline_control = self._failed_worker_report(
				control["request"],
				kind="worker_deadline_exhausted",
			)
			derived_control_deadline_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_deadline_exhausted: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"worker-local deadline or phase timeout stopped the remaining "
					"shard schedule."
				),
			}
			nested_control_deadline_issue = {
				"kind": deadline_control["issues"][0]["kind"],
				"message": deadline_control["issues"][0]["message"],
			}
			retained_deadline_control = copy.deepcopy(qualified)
			retained_deadline_control.update({
				"ok": False,
				"candidate_eligible": True,
				"qualified": False,
				"qualification_status": "control_ineligible",
				"control": deadline_control,
				"equivalence": None,
				"issues": [
					derived_control_deadline_issue,
					nested_control_deadline_issue,
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				retained_deadline_control,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			reversed_deadline_control = copy.deepcopy(retained_deadline_control)
			reversed_deadline_control["issues"].reverse()
			with self.assertRaisesRegex(ValueError, "followed its nested control evidence"):
				gf_maintenance.validate_gut_shard_run_report(
					reversed_deadline_control,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			ineligible_candidate_reports = copy.deepcopy(all_reports)
			ineligible_candidate_reports[0] = self._failed_worker_report(
				all_reports[0]["request"]
			)
			ineligible_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				ineligible_candidate_reports,
			)
			candidate_worker_issue = ineligible_candidate_reports[0]["issues"][0]
			candidate_nested_issue = {
				"kind": candidate_worker_issue["kind"],
				"message": (
					f"{self.MANIFEST['shards'][0]['name']}: "
					f"{candidate_worker_issue['message']}"
				),
			}
			control_missing_issue = {
				"kind": "gut_shard_control_report_missing",
				"message": "synthetic missing control report",
			}
			candidate_ineligible_control_missing = copy.deepcopy(qualified)
			candidate_ineligible_control_missing.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "control_ineligible",
				"successful_shard_count": len(all_reports) - 1,
				"failed_shard_count": 1,
				"shards": ineligible_candidate_reports,
				"aggregate": ineligible_aggregate,
				"control": None,
				"equivalence": None,
				"issues": [
					candidate_nested_issue,
					*copy.deepcopy(ineligible_aggregate["issues"]),
					control_missing_issue,
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				candidate_ineligible_control_missing,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			control_before_candidate_nested = copy.deepcopy(
				candidate_ineligible_control_missing
			)
			control_before_candidate_nested["issues"] = [
				control_missing_issue,
				candidate_nested_issue,
				*copy.deepcopy(ineligible_aggregate["issues"]),
			]
			with self.assertRaisesRegex(ValueError, "preceded candidate nested evidence"):
				gf_maintenance.validate_gut_shard_run_report(
					control_before_candidate_nested,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			failed_control_nested_issue = {
				"kind": failed_control["issues"][0]["kind"],
				"message": failed_control["issues"][0]["message"],
			}
			final_drift_issue = {
				"kind": "gut_shard_final_source_drift",
				"message": "synthetic final source drift",
			}
			final_cleanup_issue = {
				"kind": "gut_shard_validation_cleanup_failed",
				"message": "synthetic retained validation root",
			}
			control_failure_then_final_drift = copy.deepcopy(qualified)
			control_failure_then_final_drift.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"control": failed_control,
				"equivalence": None,
				"issues": [
					failed_control_nested_issue,
					final_drift_issue,
					final_cleanup_issue,
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				control_failure_then_final_drift,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			final_before_control_nested = copy.deepcopy(control_failure_then_final_drift)
			final_before_control_nested["issues"][:2] = list(reversed(
				final_before_control_nested["issues"][:2]
			))
			with self.assertRaisesRegex(ValueError, "final-proof evidence preceded"):
				gf_maintenance.validate_gut_shard_run_report(
					final_before_control_nested,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			legacy_control_budget = copy.deepcopy(qualified)
			legacy_control_budget["control_gut_timeout_seconds"] = 600
			legacy_control_budget["total_timeout_seconds"] = 8220
			legacy_control_request = legacy_control_budget["control"]["request"]
			legacy_control_request["gut_timeout_seconds"] = 600
			legacy_control_request["remaining_seconds"] = 1320.0
			legacy_control_budget["control"]["request_digest"] = (
				gf_maintenance.gf_gut_shard_worker.canonical_digest(
					legacy_control_request
				)
			)
			with self.assertRaisesRegex(ValueError, "timeout policy"):
				gf_maintenance.validate_gut_shard_run_report(
					legacy_control_budget,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			missing_control_stage = copy.deepcopy(qualified)
			missing_control_stage.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"control": None,
				"equivalence": None,
				"issues": [
					{
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic final drift without control stage",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "omitted its reached control stage"):
				gf_maintenance.validate_gut_shard_run_report(
					missing_control_stage,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			missing_equivalence = copy.deepcopy(qualified)
			missing_equivalence.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"equivalence": None,
				"issues": [
					{
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic final drift",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "equivalence presence"):
				gf_maintenance.validate_gut_shard_run_report(
					missing_equivalence,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			final_runtime_mismatch = copy.deepcopy(qualified)
			final_runtime_mismatch.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "infrastructure_failed",
				"issues": [{
					"kind": "gut_shard_runtime_source_mismatch",
					"message": "synthetic final loaded-source mismatch",
				}],
			})
			with self.assertRaisesRegex(ValueError, "final source-proof failure"):
				gf_maintenance.validate_gut_shard_run_report(
					final_runtime_mismatch,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			multiple_final_causes = copy.deepcopy(qualified)
			multiple_final_causes.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"issues": [
					{
						"kind": "gut_shard_final_infrastructure_failed",
						"message": "synthetic final infrastructure root cause",
					},
					{
						"kind": "gut_shard_final_source_drift",
						"message": "synthetic impossible second final root cause",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "mutually exclusive root causes"):
				gf_maintenance.validate_gut_shard_run_report(
					multiple_final_causes,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			multiple_control_causes = copy.deepcopy(qualified)
			multiple_control_causes.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"control": None,
				"equivalence": None,
				"issues": [
					{
						"kind": "gut_shard_control_deadline_exhausted",
						"message": "synthetic control deadline",
					},
					{
						"kind": "gut_shard_control_report_rejected",
						"message": "synthetic impossible second control cause",
					},
					{
						"kind": "gut_shard_control_cleanup_failed",
						"message": "synthetic retained control root",
					},
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "mutually exclusive primary failures"):
				gf_maintenance.validate_gut_shard_run_report(
					multiple_control_causes,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			control_primary_with_worker = copy.deepcopy(multiple_control_causes)
			control_primary_with_worker["issues"][1] = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_exception: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"synthetic worker failure"
				),
			}
			with self.assertRaisesRegex(ValueError, "cannot follow worker-wave"):
				gf_maintenance.validate_gut_shard_run_report(
					control_primary_with_worker,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			for worker_prefixes in (
				(
					"gut_shard_worker_schedule_failed",
					"gut_shard_worker_exception",
				),
				(
					"gut_shard_worker_wave_failed",
					"gut_shard_worker_exception",
				),
				(
					"gut_shard_worker_schedule_failed",
					"gut_shard_worker_wave_deadline_exhausted",
				),
				(
					"gut_shard_worker_wave_deadline_exhausted",
					"gut_shard_worker_infrastructure_failed",
				),
				(
					"gut_shard_worker_wave_deadline_exhausted",
					"gut_shard_workspace_fingerprint_boundary_unproven",
				),
			):
				impossible_control_wave = copy.deepcopy(qualified)
				worker_issues = []
				for prefix in worker_prefixes:
					detail = "synthetic single-worker failure"
					if prefix not in {
						"gut_shard_worker_wave_failed",
						"gut_shard_worker_wave_deadline_exhausted",
					}:
						detail = (
							f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
							f"{detail}"
						)
					worker_issues.append({
						"kind": "gut_shard_control_worker_failed",
						"message": f"{prefix}: {detail}",
					})
				impossible_control_wave.update({
					"ok": False,
					"candidate_eligible": False,
					"qualified": False,
					"qualification_status": "cleanup_failed",
					"control": None,
					"equivalence": None,
					"issues": [
						*worker_issues,
						{
							"kind": "gut_shard_control_cleanup_failed",
							"message": "synthetic retained control root",
						},
						{
							"kind": "gut_shard_validation_cleanup_failed",
							"message": "synthetic retained validation root",
						},
					],
				})
				with self.subTest(worker_prefixes=worker_prefixes), self.assertRaisesRegex(
					ValueError,
					"mutually exclusive single-worker causes",
				):
					gf_maintenance.validate_gut_shard_run_report(
						impossible_control_wave,
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			reachable_deadline_ownership = copy.deepcopy(impossible_control_wave)
			reachable_deadline_ownership["issues"] = [
				{
					"kind": "gut_shard_control_worker_failed",
					"message": (
						"gut_shard_worker_wave_deadline_exhausted: "
						"synthetic parent deadline"
					),
				},
				{
					"kind": "gut_shard_control_worker_failed",
					"message": (
						"gut_shard_worker_infrastructure_failed: "
						f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
						"synthetic unsafe report"
					),
				},
				{
					"kind": "gut_shard_control_worker_failed",
					"message": (
						"gut_shard_workspace_ownership_unproven: "
						f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
						"synthetic retained workspace"
					),
				},
				{
					"kind": "gut_shard_control_cleanup_failed",
					"message": "synthetic retained control root",
				},
				{
					"kind": "gut_shard_validation_cleanup_failed",
					"message": "synthetic retained validation root",
				},
			]
			validated_deadline_ownership = gf_maintenance.validate_gut_shard_run_report(
				reachable_deadline_ownership,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			self.assertEqual(
				validated_deadline_ownership["qualification_status"],
				"cleanup_failed",
			)

			def control_failure_report(
				issues: list[dict[str, str]],
			) -> dict[str, object]:
				result = copy.deepcopy(qualified)
				result.update({
					"ok": False,
					"candidate_eligible": False,
					"qualified": False,
					"qualification_status": "cleanup_failed",
					"control": None,
					"equivalence": None,
					"issues": copy.deepcopy(issues),
				})
				return result

			control_cleanup_issues = [
				{
					"kind": "gut_shard_control_cleanup_failed",
					"message": "synthetic retained control root",
				},
				{
					"kind": "gut_shard_validation_cleanup_failed",
					"message": "synthetic retained validation root",
				},
			]
			control_deadline_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_wave_deadline_exhausted: "
					"synthetic parent deadline"
				),
			}
			control_wave_failure_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": "gut_shard_worker_wave_failed: synthetic outer wave failure",
			}
			reachable_deadline_then_wave_failure = control_failure_report([
				control_deadline_issue,
				control_wave_failure_issue,
				*control_cleanup_issues,
			])
			gf_maintenance.validate_gut_shard_run_report(
				reachable_deadline_then_wave_failure,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)

			control_exception_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_exception: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"synthetic worker exception"
				),
			}
			control_rejected_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_report_rejected: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"synthetic rejected report"
				),
			}
			control_infrastructure_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_worker_infrastructure_failed: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"synthetic unsafe report"
				),
			}
			control_ownership_issue = {
				"kind": "gut_shard_control_worker_failed",
				"message": (
					"gut_shard_workspace_ownership_unproven: "
					f"{gf_maintenance.gf_gut_shard_worker.CONTROL_SHARD_NAME}: "
					"synthetic retained workspace"
				),
			}
			for label, issues, expected_message in (
				(
					"wave-failure-before-deadline",
					[
						control_wave_failure_issue,
						control_deadline_issue,
						*control_cleanup_issues,
					],
					"deadline did not precede|failure did not follow",
				),
				(
					"exception-before-deadline",
					[
						control_exception_issue,
						control_deadline_issue,
						*control_cleanup_issues,
					],
					"deadline did not precede",
				),
				(
					"rejection-before-deadline",
					[
						control_rejected_issue,
						control_deadline_issue,
						*control_cleanup_issues,
					],
					"deadline did not precede",
				),
				(
					"ownership-before-result",
					[
						control_ownership_issue,
						control_infrastructure_issue,
						*control_cleanup_issues,
					],
					"ownership debt preceded",
				),
				(
					"control-cleanup-before-worker",
					[
						control_cleanup_issues[0],
						control_exception_issue,
						control_cleanup_issues[1],
					],
					"control cleanup evidence preceded",
				),
				(
					"outer-cleanup-before-worker",
					[
						control_cleanup_issues[1],
						control_exception_issue,
						control_cleanup_issues[0],
					],
					"validation cleanup evidence did not follow",
				),
				(
					"primary-after-control-cleanup",
					[
						control_cleanup_issues[0],
						{
							"kind": "gut_shard_control_report_rejected",
							"message": "synthetic rejected control",
						},
						control_cleanup_issues[1],
					],
					"control cleanup evidence preceded",
				),
				(
					"outer-cleanup-before-primary-cleanup",
					[
						{
							"kind": "gut_shard_control_report_rejected",
							"message": "synthetic rejected control",
						},
						control_cleanup_issues[1],
						control_cleanup_issues[0],
					],
					"validation cleanup evidence did not follow",
				),
			):
				with self.subTest(label=label), self.assertRaisesRegex(
					ValueError,
					expected_message,
				):
					gf_maintenance.validate_gut_shard_run_report(
						control_failure_report(issues),
						manifest=self.MANIFEST,
						inventory=self.INVENTORY,
						expected_workspace_fingerprint="1" * 64,
						expected_validation_root=workspace,
					)

			final_infrastructure_failure = copy.deepcopy(qualified)
			final_infrastructure_failure.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "infrastructure_failed",
				"issues": [{
					"kind": "gut_shard_final_infrastructure_failed",
					"message": "synthetic final proof infrastructure failure",
				}],
			})
			with self.assertRaisesRegex(ValueError, "final source-proof failure"):
				gf_maintenance.validate_gut_shard_run_report(
					final_infrastructure_failure,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			partial_reports = all_reports[:2]
			partial_aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				partial_reports,
			)
			partial_with_control = copy.deepcopy(qualified)
			partial_with_control.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"executed_shard_count": 2,
				"completed_shard_count": 2,
				"successful_shard_count": 2,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 2,
				"shards": partial_reports,
				"aggregate": partial_aggregate,
				"equivalence": None,
				"issues": [
					{
						"kind": "gut_shard_candidate_scheduling_deadline_exhausted",
						"message": "synthetic candidate deadline",
					},
					*copy.deepcopy(partial_aggregate["issues"]),
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained candidate root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "candidate-phase stop retained control"):
				gf_maintenance.validate_gut_shard_run_report(
					partial_with_control,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			unowned_control = self._failed_worker_report(control["request"])
			unowned_control.update({
				"process_boundary_quiescent": False,
				"workspace_cleanup_permitted": False,
				"continuation_safe": False,
			})
			forged_unowned_control = copy.deepcopy(qualified)
			forged_unowned_control.update({
				"ok": False,
				"qualified": False,
				"qualification_status": "control_ineligible",
				"control": unowned_control,
				"equivalence": None,
				"issues": [{
					"kind": issue["kind"],
					"message": issue["message"],
				} for issue in unowned_control["issues"]],
			})
			with self.assertRaisesRegex(ValueError, "control evidence retained unproven"):
				gf_maintenance.validate_gut_shard_run_report(
					forged_unowned_control,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

			failed_control = self._failed_worker_report(control["request"])
			control_retained_after_cleanup = copy.deepcopy(qualified)
			control_retained_after_cleanup.update({
				"ok": False,
				"candidate_eligible": False,
				"qualified": False,
				"qualification_status": "cleanup_failed",
				"control": failed_control,
				"equivalence": None,
				"issues": [
					{
						"kind": "gut_shard_control_cleanup_failed",
						"message": "synthetic retained control root",
					},
					*[{
						"kind": issue["kind"],
						"message": issue["message"],
					} for issue in failed_control["issues"]],
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			with self.assertRaisesRegex(ValueError, "retained a control report"):
				gf_maintenance.validate_gut_shard_run_report(
					control_retained_after_cleanup,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_top_report_validator_requires_nested_failure_issue_subsequence(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			candidate_workspace = workspace / "candidate-0"
			candidate_workspace.mkdir()
			manifest_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			)
			inventory_digest = gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			)
			request = gf_maintenance.make_gut_shard_worker_request(
				self.MANIFEST["shards"][0],
				candidate_workspace,
				workspace_fingerprint_value="1" * 64,
				manifest_digest=manifest_digest,
				inventory_digest=inventory_digest,
				remaining_seconds=float(
					gf_maintenance.gut_shard_worker_total_timeout_seconds(
						gf_maintenance.resolve_check_timeout_seconds("godot_import", None),
						gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(None),
					)
				),
				import_timeout_seconds=gf_maintenance.resolve_check_timeout_seconds(
					"godot_import", None
				),
				gut_timeout_seconds=(
					gf_maintenance.resolve_gut_shard_run_gut_timeout_seconds(None)
				),
			)
			failed_worker = self._failed_worker_report(request)
			aggregate = gf_maintenance.aggregate_gut_shard_candidate_reports(
				self.MANIFEST,
				self.INVENTORY,
				[failed_worker],
			)
			worker_issue = failed_worker["issues"][0]
			derived_issue = {
				"kind": worker_issue["kind"],
				"message": (
					f"{request['shard_name']}: {worker_issue['message']}".rstrip()
				),
			}
			report = gf_maintenance.make_gut_shard_run_report(
				jobs=2,
				qualify=False,
			)
			report.update({
				"workspace_fingerprint": "1" * 64,
				"manifest_digest": manifest_digest,
				"inventory_digest": inventory_digest,
				"inventory_count": len(self.INVENTORY),
				"shard_count": len(self.MANIFEST["shards"]),
				"executed_shard_count": 2,
				"completed_shard_count": 1,
				"failed_shard_count": 1,
				"unreported_shard_count": 1,
				"not_scheduled_shard_count": len(self.MANIFEST["shards"]) - 2,
				"duration_seconds": 0.1,
				"isolation_probe": {
					"ok": True,
					"probe_count": 2,
					"fields": [
						"marker_path", "user_dir", "data_dir", "config_dir", "cache_dir",
					],
				},
				"shards": [failed_worker],
				"aggregate": aggregate,
				"issues": [
					{
						"kind": "gut_shard_worker_exception",
						"message": (
							f"{self.MANIFEST['shards'][1]['name']}: "
							"synthetic peer worker failure"
						),
					},
					{
						"kind": "gut_shard_workspace_cleanup_failed",
						"message": "synthetic retained candidate batch",
					},
					derived_issue,
					*copy.deepcopy(aggregate["issues"]),
					{
						"kind": "gut_shard_validation_cleanup_failed",
						"message": "synthetic retained validation root",
					},
				],
			})
			gf_maintenance.validate_gut_shard_run_report(
				report,
				manifest=self.MANIFEST,
				inventory=self.INVENTORY,
				expected_workspace_fingerprint="1" * 64,
				expected_validation_root=workspace,
			)
			early_nested_issue = copy.deepcopy(report)
			early_nested_issue["issues"][1:3] = list(reversed(
				early_nested_issue["issues"][1:3]
			))
			with self.assertRaisesRegex(ValueError, "followed its derived candidate"):
				gf_maintenance.validate_gut_shard_run_report(
					early_nested_issue,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)
			forged = copy.deepcopy(report)
			forged["issues"] = [{
				"kind": "gut_shard_unrelated_failure",
				"message": "unrelated orchestrator issue",
			}]
			with self.assertRaisesRegex(ValueError, "omit derived nested evidence"):
				gf_maintenance.validate_gut_shard_run_report(
					forged,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
					expected_validation_root=workspace,
				)

	def test_top_report_validator_binds_context_even_for_failure_reports(self) -> None:
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
		report.update({
			"workspace_fingerprint": "1" * 64,
			"manifest_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
				self.MANIFEST
			),
			"inventory_digest": gf_maintenance.gf_gut_sharding.canonical_digest(
				list(self.INVENTORY)
			),
			"inventory_count": len(self.INVENTORY),
			"shard_count": len(self.MANIFEST["shards"]),
			"not_scheduled_shard_count": len(self.MANIFEST["shards"]),
			"duration_seconds": 0.1,
			"issues": [{
				"kind": "gut_shard_run_setup_failed",
				"message": "fixture",
			}],
		})
		gf_maintenance.validate_gut_shard_run_report(
			report,
			manifest=self.MANIFEST,
			inventory=self.INVENTORY,
			expected_workspace_fingerprint="1" * 64,
		)
		with self.assertRaisesRegex(ValueError, "requires manifest and inventory"):
			gf_maintenance.validate_gut_shard_run_report(
				report,
				expected_workspace_fingerprint="1" * 64,
			)
		for field, value in (
			("workspace_fingerprint", "2" * 64),
			("manifest_digest", "2" * 64),
			("inventory_digest", "3" * 64),
			("inventory_count", 999),
			("shard_count", 1),
			("runtime_source_digest", "4" * 64),
		):
			forged = copy.deepcopy(report)
			forged[field] = value
			if field == "shard_count":
				forged["not_scheduled_shard_count"] = value
			with self.subTest(field=field), self.assertRaises(ValueError):
				gf_maintenance.validate_gut_shard_run_report(
					forged,
					manifest=self.MANIFEST,
					inventory=self.INVENTORY,
					expected_workspace_fingerprint="1" * 64,
				)

	def test_renderer_keeps_candidate_and_evidence_status_distinct(self) -> None:
		report = gf_maintenance.make_gut_shard_run_report(jobs=2, qualify=False)
		report.update({
			"manifest_digest": "a" * 64,
			"inventory_digest": "b" * 64,
			"inventory_count": 2,
			"shard_count": 2,
		})
		text = gf_maintenance_rendering.render_gut_shard_run_text(report)
		self.assertIn("candidate_eligible=False qualified=False", text)
		self.assertIn("authoritative=False merge_evidence=False", text)
		self.assertIn(f"runtime_source={report['runtime_source_digest']}", text)
		self.assertIn("skips=0 cache_reads=0 cache_writes=0 reuse=0", text)


class WorkspaceExecutionBoundaryTests(unittest.TestCase):
	def test_parallel_full_schedule_separates_heavy_shards(self) -> None:
		plan = gf_maintenance.parallel_full_shard_plan()
		plan_names = tuple(shard.name for shard in plan)
		self.assertEqual(
			plan_names,
			(
				"package-editor",
				"framework-static",
				"package-godot-ci",
				"package-cli-local",
				"package-cli-network",
				"package-contract",
				"framework-gut",
				"framework-lsp",
			),
		)
		self.assertEqual(
			tuple(
				tuple(shard.name for shard in batch)
				for batch in gf_maintenance.parallel_full_shard_batches(plan, 2)
			),
			(
				("package-editor", "framework-static"),
				("package-godot-ci", "package-cli-local"),
				("package-cli-network", "package-contract"),
				("framework-gut",),
				("framework-lsp",),
			),
		)
		self.assertEqual(
			tuple(
				tuple(shard.name for shard in batch)
				for batch in gf_maintenance.parallel_full_shard_batches(plan, 3)
			),
			(
				("package-editor", "framework-static", "package-godot-ci"),
				("package-cli-local", "package-cli-network", "package-contract"),
				("framework-gut",),
				("framework-lsp",),
			),
		)
		for jobs in range(1, gf_maintenance.MAX_PARALLEL_FULL_JOBS + 1):
			batches = gf_maintenance.parallel_full_shard_batches(plan, jobs)
			batch_names = tuple(
				tuple(shard.name for shard in batch)
				for batch in batches
			)
			flattened_names = tuple(
				name for batch in batch_names for name in batch
			)
			with self.subTest(jobs=jobs):
				self.assertEqual(flattened_names, plan_names)
				self.assertTrue(all(1 <= len(batch) <= jobs for batch in batches))
				self.assertEqual(
					[batch for batch in batch_names if "framework-gut" in batch],
					[("framework-gut",)],
				)
		with self.assertRaisesRegex(ValueError, "must be positive"):
			gf_maintenance.parallel_full_shard_batches(plan, 0)

	def test_parallel_full_fail_fast_marks_only_future_resource_batches(self) -> None:
		plan = [
			gf_maintenance.ParallelCheckShardPlan("first", ("docs",)),
			gf_maintenance.ParallelCheckShardPlan(
				"framework-gut",
				("api_reference",),
			),
			gf_maintenance.ParallelCheckShardPlan("last", ("ai_api",)),
		]

		class ExpectedStop(RuntimeError):
			pass

		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			parallel_root = root / "parallel"
			parallel_root.mkdir()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="b" * 64,
			)

			def materialize(
				_captured: object,
				batch_root: Path,
				batch_plan: list[object],
				**_kwargs: object,
			) -> dict[str, Path]:
				workspaces: dict[str, Path] = {}
				for shard_plan in batch_plan:
					workspace = batch_root / str(shard_plan.name)
					workspace.mkdir()
					workspaces[str(shard_plan.name)] = workspace
				return workspaces

			def make_shard(
				shard_plan: object,
				workspace: Path,
				**_kwargs: object,
			) -> tuple[object, Path]:
				return (
					gf_maintenance.ParallelShard(
						name=str(shard_plan.name),
						command=("python", "-V"),
						workspace=workspace,
						timeout_seconds=1.0,
					),
					workspace / "report.json",
				)

			def run_shards(
				shards: list[object],
				**_kwargs: object,
			) -> list[object]:
				shard = shards[0]
				exit_code = 1 if shard.name == "framework-gut" else 0
				return [gf_maintenance.ParallelShardResult(
					name=str(shard.name),
					command=tuple(shard.command),
					workspace=shard.workspace,
					exit_code=exit_code,
					process_exit_code=exit_code,
					stdout="",
					stderr="",
					timed_out=False,
					cancelled=False,
					duration_seconds=0.1,
					pid=1,
					started=True,
					process_boundary_quiescent=True,
				)]

			def load_report(
				shard_result: object,
				_report_path: Path,
				expected_checks: list[str],
				*_args: object,
				**_kwargs: object,
			) -> tuple[dict[str, object], str]:
				return ({
					"ok": shard_result.exit_code == 0,
					"results": [{
						"name": expected_checks[0],
						"exit_code": shard_result.exit_code,
						"timed_out": False,
						"cancelled": False,
						"duration_seconds": 0.1,
					}],
				}, "")

			with mock.patch.object(
				gf_maintenance,
				"parallel_full_shard_plan",
				return_value=plan,
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				side_effect=lambda _suite, checks, **_kwargs: list(checks or []),
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={"ok": True},
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance,
				"materialize_parallel_full_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"make_parallel_full_shard",
				side_effect=make_shard,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=run_shards,
			) as run_parallel, mock.patch.object(
				gf_maintenance,
				"load_parallel_shard_report",
				side_effect=load_report,
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "b" * 64},
			), mock.patch.object(
				gf_maintenance,
				"collect_parallel_failure_logs",
				return_value=[],
			), mock.patch.object(
				gf_maintenance,
				"append_unstarted_parallel_shards",
				side_effect=ExpectedStop("captured future batches"),
			) as append_unstarted:
				with self.assertRaises(ExpectedStop):
					gf_maintenance.run_parallel_full_checks(
						captured,
						parallel_root,
						jobs=2,
						timeout_seconds=None,
						suite_timeout_seconds=None,
						fail_fast=True,
						package_artifact_manifest="manifest.json",
						package_artifact_manifest_sha256="d" * 64,
						package_artifact_count=1,
						progress_callback=None,
						output_callback=None,
						overall_started=time.perf_counter(),
						suite_deadline=time.perf_counter() + 10.0,
					)

		self.assertEqual(run_parallel.call_count, 2)
		self.assertEqual(
			[shard.name for shard in append_unstarted.call_args.args[0]],
			["last"],
		)

	def test_parallel_full_plan_owns_full_check_set_exactly_once(self) -> None:
		plan = gf_maintenance.parallel_full_shard_plan()
		owned_checks = [check for shard in plan for check in shard.checks]
		self.assertEqual(set(owned_checks), set(gf_maintenance.FULL_CHECKS))
		self.assertEqual(len(owned_checks), len(set(owned_checks)))
		for shard in plan:
			with self.subTest(shard=shard.name):
				self.assertTrue(set(shard.checks).issubset(
					gf_maintenance.CHECK_SUITES[shard.name]
				))
		self.assertEqual(
			next(
				shard.name
				for shard in plan
				if "gdscript_lsp_diagnostics" in shard.checks
			),
			"framework-lsp",
		)

	def test_windows_path_budget_counts_utf16_code_units(self) -> None:
		path = r"D:\😀😀😀\gfs-xxxxxxxx"
		self.assertEqual(len(path), 19)
		self.assertEqual(gf_maintenance.windows_utf16_path_code_units(path), 22)

	def test_open_file_identity_rejects_missing_device_and_inode(self) -> None:
		missing_identity = os.stat_result(
			(0o100600, 0, 0, 1, 0, 0, 7, 0, 0, 0)
		)
		self.assertFalse(
			gf_maintenance.same_open_file_identity(
				missing_identity,
				missing_identity,
			)
		)

	@unittest.skipUnless(os.name == "nt", "Windows extended-path behavior")
	def test_parallel_failure_log_copy_supports_long_destination_leaf(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			workspace_root = fixture_root / "workspace"
			source_root = workspace_root / "ai_analysis" / "godot_logs"
			destination_containment_root = fixture_root / "destination"
			destination_root = (
				destination_containment_root
				/ ("session-" + "x" * 96)
				/ "package-editor"
			)
			source_root.mkdir(parents=True)
			destination_root.mkdir(parents=True)
			entry_name = (
				"package_editor_wizard_smoke_minimal_kernel_project_editor_"
				"offline_bundle_preset_install_uninstall.log"
			)
			payload = b"retained failure evidence"
			(source_root / entry_name).write_bytes(payload)
			destination_path = destination_root / entry_name
			self.assertGreaterEqual(
				gf_maintenance.windows_utf16_path_code_units(destination_path),
				260,
			)
			extended_destination = "\\\\?\\" + str(destination_path)
			try:
				gf_maintenance.copy_parallel_log_tree(
					source_root,
					destination_root,
					containment_root=workspace_root,
					destination_containment_root=destination_containment_root,
					expected_destination_identity=destination_root.lstat(),
					expected_destination_containment_identity=(
						destination_containment_root.lstat()
					),
				)

				file_descriptor = os.open(extended_destination, os.O_RDONLY)
				try:
					self.assertEqual(os.read(file_descriptor, len(payload) + 1), payload)
				finally:
					os.close(file_descriptor)
			finally:
				if os.path.lexists(extended_destination):
					os.unlink(extended_destination)

	@unittest.skipUnless(os.name == "nt", "Windows extended-path behavior")
	def test_parallel_failure_log_copy_supports_long_source_leaf(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			fixture_root = Path(temporary_directory)
			workspace_root = fixture_root / "workspace"
			source_root = workspace_root / ("source-" + "x" * 104)
			destination_containment_root = fixture_root / "destination"
			destination_root = destination_containment_root / "package-editor"
			source_root.mkdir(parents=True)
			destination_root.mkdir(parents=True)
			entry_name = (
				"package_editor_wizard_smoke_minimal_kernel_project_editor_"
				"offline_bundle_preset_install_uninstall.log"
			)
			payload = b"retained failure evidence"
			source_path = source_root / entry_name
			self.assertGreaterEqual(
				gf_maintenance.windows_utf16_path_code_units(source_path),
				260,
			)
			extended_source = "\\\\?\\" + str(source_path)
			file_descriptor = os.open(
				extended_source,
				os.O_CREAT | os.O_EXCL | os.O_WRONLY | getattr(os, "O_BINARY", 0),
				0o600,
			)
			with os.fdopen(file_descriptor, "wb") as source_file:
				source_file.write(payload)
			try:
				gf_maintenance.copy_parallel_log_tree(
					source_root,
					destination_root,
					containment_root=workspace_root,
					destination_containment_root=destination_containment_root,
					expected_destination_identity=destination_root.lstat(),
					expected_destination_containment_identity=(
						destination_containment_root.lstat()
					),
				)

				self.assertEqual((destination_root / entry_name).read_bytes(), payload)
			finally:
				if os.path.lexists(extended_source):
					os.unlink(extended_source)

	def test_standalone_process_smokes_use_guarded_temporary_roots(self) -> None:
		for function in (
			gf_maintenance.core_plugin_bootstrap_smoke,
			gf_maintenance.package_build_boundary,
			gf_maintenance.package_editor_wizard_smoke,
			gf_maintenance.package_godot_cli_smoke,
			gf_maintenance.package_godot_smoke,
		):
			with self.subTest(function=function.__name__):
				source = inspect.getsource(function)
				self.assertIn("strict_process_boundary_temporary_directory", source)
				self.assertNotIn("with strict_managed_temporary_directory", source)

	def test_process_boundary_temp_retains_root_until_body_proves_quiescence(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			retained: Path | None = None
			with self.assertRaises(
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError,
			) as raised:
				with gf_maintenance.strict_process_boundary_temporary_directory(
					prefix="gf-process-boundary-fixture-",
					directory=parent,
				) as owned_root:
					retained = owned_root
					(owned_root / "must-retain.txt").write_text("retained", encoding="utf-8")
					raise gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError(
						"synthetic unproved process boundary",
						preserved_paths=(owned_root,),
					)
			self.assertIsNotNone(retained)
			assert retained is not None
			self.assertTrue(gf_maintenance.exception_has_cleanup_debt(raised.exception))
			self.assertIn(
				"Retained temporary root because process-boundary cleanup ownership was not proven",
				"\n".join(getattr(raised.exception, "__notes__", ())),
			)
			self.assertEqual(
				(retained / "must-retain.txt").read_text(encoding="utf-8"),
				"retained",
			)

	def test_retention_diagnostics_do_not_replace_hostile_primary_error(self) -> None:
		class HostileBoundaryError(
			gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError
		):
			def add_note(self, _note: str) -> None:
				raise SystemExit("fixture hostile add_note")

		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			owned_root.mkdir()
			primary = HostileBoundaryError(
				"synthetic unproved process boundary",
				preserved_paths=(owned_root,),
			)
			with mock.patch.object(
				gf_maintenance.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			):
				with self.assertRaises(HostileBoundaryError) as raised:
					with gf_maintenance.strict_process_boundary_temporary_directory(
						prefix="gf-process-boundary-fixture-",
					) as retained:
						(retained / "must-retain.txt").write_text(
							"retained",
							encoding="utf-8",
						)
						raise primary

			self.assertIs(raised.exception, primary)
			self.assertEqual(
				(owned_root / "must-retain.txt").read_text(encoding="utf-8"),
				"retained",
			)

	def test_cleanup_debt_classifier_bypasses_lying_exception_getters(self) -> None:
		class HostileDebtError(gf_maintenance.PackageArtifactSetError):
			def __init__(self, message: str) -> None:
				super().__init__(message)
				attributes = BaseException.__getattribute__(self, "__dict__")
				attributes["cleanup_debt"] = True
				attributes["process_boundary_quiescent"] = False

			def __getattribute__(self, name: str) -> object:
				if name == "cleanup_debt":
					return False
				if name == "process_boundary_quiescent":
					return True
				return super().__getattribute__(name)

		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			owned_root.mkdir()
			marker = owned_root / "must-retain.txt"
			marker.write_text("retained", encoding="utf-8")
			primary = HostileDebtError("synthetic uninspectable cleanup boundary")

			with mock.patch.object(
				gf_maintenance.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			), mock.patch.object(
				gf_maintenance,
				"load_or_build_private_package_artifact_set",
				side_effect=primary,
			):
				with self.assertRaises(HostileDebtError) as raised:
					gf_maintenance.package_build_boundary()

			self.assertIs(raised.exception, primary)
			self.assertEqual(marker.read_text(encoding="utf-8"), "retained")

	def test_cleanup_debt_classifier_rejects_hidden_context_descriptor(self) -> None:
		class HostileWrapper(gf_maintenance.PackageArtifactSetError):
			@property
			def __context__(self) -> None:
				return None

		debt = gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError(
			"fixture hidden cleanup debt"
		)
		try:
			raise debt
		except gf_maintenance.WorkspaceSnapshotError:
			try:
				raise HostileWrapper("fixture wrapper") from None
			except HostileWrapper as wrapper:
				primary = wrapper

		self.assertTrue(gf_maintenance.exception_has_cleanup_debt(primary))

	def test_package_capture_wrapper_does_not_format_hostile_cleanup_debt(self) -> None:
		class HostileSnapshotError(gf_maintenance.WorkspaceSnapshotError):
			cleanup_debt = True
			process_boundary_quiescent = False

			def __str__(self) -> str:
				raise SystemExit("fixture hostile snapshot __str__")

		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			owned_root.mkdir()
			marker = owned_root / "must-retain.txt"
			marker.write_text("retained", encoding="utf-8")
			primary = HostileSnapshotError("synthetic capture cleanup debt")
			workspace_state = {"fingerprint": "a" * 64}

			with (
				mock.patch.object(
					gf_maintenance.tempfile,
					"mkdtemp",
					return_value=str(owned_root),
				),
				mock.patch.object(
					gf_maintenance,
					"workspace_fingerprint",
					return_value=workspace_state,
				),
				mock.patch.object(
					gf_maintenance.gf_parallel_validation,
					"capture_workspace",
					side_effect=primary,
				),
			):
				with self.assertRaises(gf_maintenance.PackageArtifactSetError) as raised:
					gf_maintenance.package_build_boundary()

			self.assertIs(raised.exception.__cause__, primary)
			self.assertTrue(gf_maintenance.exception_has_cleanup_debt(raised.exception))
			self.assertEqual(marker.read_text(encoding="utf-8"), "retained")

	def test_package_build_diagnostic_does_not_format_hostile_ordinary_error(self) -> None:
		class HostilePackageError(gf_maintenance.PackageArtifactSetError):
			def __str__(self) -> str:
				raise SystemExit("fixture hostile package error text")

		with mock.patch.object(
			gf_maintenance,
			"load_or_build_private_package_artifact_set",
			side_effect=HostilePackageError("fixture invalid artifact set"),
		):
			report = gf_maintenance.package_build_boundary()

		self.assertFalse(report["ok"])
		self.assertEqual(report["issues"][0]["kind"], "package_artifact_set_invalid")
		self.assertIn("detail unavailable", report["issues"][0]["error"])

	def test_package_build_boundary_preserves_wrapped_materializer_debt(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			owned_root.mkdir()

			def fail_with_boundary(
				temp_root: Path,
				_consumer_root: Path,
				*_args: object,
				**_kwargs: object,
			) -> object:
				marker = temp_root / "artifact-source" / "must-retain.txt"
				marker.parent.mkdir(parents=True)
				marker.write_text("retained", encoding="utf-8")
				try:
					raise gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError(
						"synthetic materializer boundary debt",
						preserved_paths=(marker.parent,),
					)
				except gf_maintenance.WorkspaceSnapshotError as error:
					raise gf_maintenance.PackageArtifactSetError(
						"wrapped materializer failure"
					) from error

			with mock.patch.object(
				gf_maintenance.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			), mock.patch.object(
				gf_maintenance,
				"load_or_build_private_package_artifact_set",
				side_effect=fail_with_boundary,
			):
				with self.assertRaises(
					gf_maintenance.PackageArtifactSetError,
				) as raised:
					gf_maintenance.package_build_boundary()
			self.assertTrue(gf_maintenance.exception_has_cleanup_debt(raised.exception))
			self.assertIsInstance(
				raised.exception.__cause__,
				gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError,
			)
			self.assertIn(
				"Retained temporary root",
				"\n".join(getattr(raised.exception, "__notes__", ())),
			)
			self.assertTrue((owned_root / "artifact-source" / "must-retain.txt").is_file())

	def test_private_artifact_cleanup_failure_carries_debt_and_retained_path(self) -> None:
		artifact_module = gf_maintenance.gf_package_artifact_set
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source_root = root / "source"
			source_root.mkdir()
			manifest_path = source_root / artifact_module.MANIFEST_FILENAME
			manifest_path.write_text("{}\n", encoding="utf-8")
			source = artifact_module.PackageArtifactSet(
				root=source_root,
				manifest_path=manifest_path,
				manifest_sha256="a" * 64,
				workspace_state={},
				artifacts=(),
				builder_result={},
			)
			target = root / "consumer"
			staging = root / ".consumer.a-deadbeef"
			primary = artifact_module.PackageArtifactSetError("private copy validation failed")

			with (
				mock.patch.object(
					artifact_module,
					"revalidate_package_artifact_set",
					return_value=source,
				),
				mock.patch.object(
					artifact_module,
					"load_package_artifact_set",
					side_effect=primary,
				),
				mock.patch.object(artifact_module.secrets, "token_hex", return_value="deadbeef"),
				mock.patch.object(
					artifact_module,
					"_safe_remove_private_tree",
					return_value="exact private staging cleanup was refused",
				),
			):
				with self.assertRaises(artifact_module.PackageArtifactSetError) as raised:
					artifact_module.materialize_package_artifact_set(source, target)

			self.assertIs(raised.exception, primary)
			self.assertTrue(raised.exception.cleanup_debt)
			self.assertFalse(raised.exception.process_boundary_quiescent)
			self.assertEqual(raised.exception.preserved_paths, (staging,))
			self.assertIsInstance(
				raised.exception.cleanup_error,
				artifact_module.PackageArtifactSetError,
			)
			self.assertIn(
				"exact private staging cleanup was refused",
				str(raised.exception.cleanup_error),
			)
			self.assertTrue(staging.is_dir())

	def test_missing_private_artifact_staging_is_cleanup_debt(self) -> None:
		artifact_module = gf_maintenance.gf_package_artifact_set
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source_root = root / "source"
			source_root.mkdir()
			manifest_path = source_root / artifact_module.MANIFEST_FILENAME
			manifest_path.write_text("{}\n", encoding="utf-8")
			source = artifact_module.PackageArtifactSet(
				root=source_root,
				manifest_path=manifest_path,
				manifest_sha256="a" * 64,
				workspace_state={},
				artifacts=(),
				builder_result={},
			)
			target = root / "consumer"
			staging = root / ".consumer.a-deadbeef"
			moved_staging = root / "moved-private-staging"
			primary = artifact_module.PackageArtifactSetError(
				"private copy validation failed"
			)

			def move_staging_then_fail(*_args: object, **_kwargs: object) -> object:
				staging.rename(moved_staging)
				raise primary

			with (
				mock.patch.object(
					artifact_module,
					"revalidate_package_artifact_set",
					return_value=source,
				),
				mock.patch.object(
					artifact_module,
					"load_package_artifact_set",
					side_effect=move_staging_then_fail,
				),
				mock.patch.object(artifact_module.secrets, "token_hex", return_value="deadbeef"),
			):
				with self.assertRaises(artifact_module.PackageArtifactSetError) as raised:
					artifact_module.materialize_package_artifact_set(source, target)

			self.assertIs(raised.exception, primary)
			self.assertTrue(raised.exception.cleanup_debt)
			self.assertFalse(raised.exception.process_boundary_quiescent)
			self.assertEqual(raised.exception.preserved_paths, (staging,))
			self.assertTrue(moved_staging.is_dir())

	def test_private_artifact_publication_move_then_control_retains_target(self) -> None:
		artifact_module = gf_maintenance.gf_package_artifact_set
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source_root = root / "source"
			source_root.mkdir()
			manifest_path = source_root / artifact_module.MANIFEST_FILENAME
			manifest_path.write_text("{}\n", encoding="utf-8")
			source = artifact_module.PackageArtifactSet(
				root=source_root,
				manifest_path=manifest_path,
				manifest_sha256="a" * 64,
				workspace_state={},
				artifacts=(),
				builder_result={},
			)
			target = root / "consumer"
			staging = root / ".consumer.a-deadbeef"
			primary = KeyboardInterrupt("fixture publication interruption")
			real_replace = os.replace

			def move_then_interrupt(source_path: object, target_path: object) -> None:
				real_replace(source_path, target_path)
				raise primary

			with (
				mock.patch.object(
					artifact_module,
					"revalidate_package_artifact_set",
					return_value=source,
				),
				mock.patch.object(
					artifact_module,
					"load_package_artifact_set",
					return_value=source,
				),
				mock.patch.object(artifact_module.secrets, "token_hex", return_value="deadbeef"),
				mock.patch.object(
					artifact_module.os,
					"replace",
					side_effect=move_then_interrupt,
				),
			):
				observed: BaseException | None = None
				try:
					artifact_module.materialize_package_artifact_set(source, target)
				except BaseException as error:
					observed = error

			self.assertIs(observed, primary)
			self.assertTrue(primary.cleanup_debt)
			self.assertFalse(primary.process_boundary_quiescent)
			self.assertEqual(primary.preserved_paths, (target,))
			self.assertTrue(target.is_dir())
			self.assertFalse(staging.exists())

	def test_package_build_boundary_preserves_private_artifact_cleanup_debt(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			staging = owned_root / ".artifact-consumer.a-deadbeef"
			staging.mkdir(parents=True)
			debt = gf_maintenance.PackageArtifactSetError(
				"private artifact cleanup could not be proven"
			)
			debt.cleanup_debt = True
			debt.process_boundary_quiescent = False
			debt.preserved_paths = (staging,)

			with mock.patch.object(
				gf_maintenance.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			), mock.patch.object(
				gf_maintenance,
				"load_or_build_private_package_artifact_set",
				side_effect=debt,
			):
				with self.assertRaises(gf_maintenance.PackageArtifactSetError) as raised:
					gf_maintenance.package_build_boundary()

			self.assertIs(raised.exception, debt)
			self.assertTrue(gf_maintenance.exception_has_cleanup_debt(raised.exception))
			self.assertTrue(staging.is_dir())

	def test_package_build_boundary_retains_replaced_published_artifact_root(self) -> None:
		artifact_module = gf_maintenance.gf_package_artifact_set
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source_root = root / "source"
			source_root.mkdir()
			manifest_path = source_root / artifact_module.MANIFEST_FILENAME
			manifest_path.write_text("{}\n", encoding="utf-8")
			source = artifact_module.PackageArtifactSet(
				root=source_root,
				manifest_path=manifest_path,
				manifest_sha256="a" * 64,
				workspace_state={},
				artifacts=(),
				builder_result={},
			)
			owned_root = root / "owned"
			owned_root.mkdir()
			target = owned_root / "artifact-consumer"
			replacement_marker = target / "replacement.txt"
			primary = artifact_module.PackageArtifactSetError(
				"published private artifact validation failed"
			)
			load_count = 0

			def replace_before_final_validation(*_args: object, **_kwargs: object) -> object:
				nonlocal load_count
				load_count += 1
				if load_count == 1:
					return source
				(target / artifact_module.MANIFEST_FILENAME).unlink()
				target.rmdir()
				target.mkdir()
				replacement_marker.write_text("retained", encoding="utf-8")
				raise primary

			def materialize_private_set(
				_temp_root: Path,
				consumer_root: Path,
				*_args: object,
				**_kwargs: object,
			) -> object:
				return artifact_module.materialize_package_artifact_set(source, consumer_root)

			with (
				mock.patch.object(
					artifact_module,
					"revalidate_package_artifact_set",
					return_value=source,
				),
				mock.patch.object(
					artifact_module,
					"load_package_artifact_set",
					side_effect=replace_before_final_validation,
				),
				mock.patch.object(artifact_module.secrets, "token_hex", return_value="deadbeef"),
				mock.patch.object(
					gf_maintenance.tempfile,
					"mkdtemp",
					return_value=str(owned_root),
				),
				mock.patch.object(
					gf_maintenance,
					"load_or_build_private_package_artifact_set",
					side_effect=materialize_private_set,
				),
			):
				with self.assertRaises(artifact_module.PackageArtifactSetError) as raised:
					gf_maintenance.package_build_boundary()

			self.assertIs(raised.exception, primary)
			self.assertTrue(gf_maintenance.exception_has_cleanup_debt(raised.exception))
			self.assertEqual(raised.exception.preserved_paths, (target,))
			self.assertTrue(owned_root.is_dir())
			self.assertEqual(replacement_marker.read_text(encoding="utf-8"), "retained")

	def test_process_boundary_temp_cleans_handled_non_debt_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			owned_root = Path(temporary_directory) / "owned"
			owned_root.mkdir()
			with mock.patch.object(
				gf_maintenance.tempfile,
				"mkdtemp",
				return_value=str(owned_root),
			), mock.patch.object(
				gf_maintenance,
				"load_or_build_private_package_artifact_set",
				side_effect=gf_maintenance.PackageArtifactSetError(
					"ordinary closed artifact failure"
				),
			):
				report = gf_maintenance.package_build_boundary()
			self.assertFalse(report["ok"])
			self.assertFalse(owned_root.exists())

	def test_maintenance_subprocess_requires_positive_process_boundary_proof(self) -> None:
		unproved = gf_maintenance.gf_process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=101,
			process_boundary_quiescent=False,
		)
		with mock.patch.object(
			gf_maintenance,
			"run_supervised_process",
			return_value=unproved,
		):
			with self.assertRaisesRegex(
				gf_maintenance.WorkspaceSnapshotError,
				"process-boundary cleanup was not proven",
			):
				gf_maintenance.run_maintenance_subprocess(
					[sys.executable, "-c", "pass"],
					timeout_seconds=1.0,
				)

	def test_maintenance_subprocess_restores_proven_no_child_start_errors(self) -> None:
		for original_error in (
			FileNotFoundError("fixture missing executable"),
			PermissionError("fixture executable denied"),
		):
			with self.subTest(error=type(original_error).__name__), mock.patch.object(
				gf_maintenance,
				"run_supervised_process",
				side_effect=(
					gf_maintenance.gf_process_supervisor.SupervisedProcessStartError(
						original_error
					)
				),
			):
				with self.assertRaises(type(original_error)) as raised:
					gf_maintenance.run_maintenance_subprocess(
						[sys.executable, "-c", "pass"],
						timeout_seconds=1.0,
					)
			self.assertIs(raised.exception, original_error)

	def test_maintenance_subprocess_rejects_unproved_raw_os_errors(self) -> None:
		for original_error in (
			FileNotFoundError("fixture unproved missing executable"),
			PermissionError("fixture unproved executable denial"),
			OSError("fixture partial-start cleanup debt"),
			RuntimeError("fixture runtime cleanup debt"),
		):
			with self.subTest(error=type(original_error).__name__), mock.patch.object(
				gf_maintenance,
				"run_supervised_process",
				side_effect=original_error,
			):
				with self.assertRaises(
					gf_maintenance.gf_parallel_validation.WorkspaceProcessBoundaryError,
				) as raised:
					gf_maintenance.run_maintenance_subprocess(
						[sys.executable, "-c", "pass"],
						timeout_seconds=1.0,
					)
			self.assertIs(raised.exception.__cause__, original_error)

	def test_parallel_full_boundary_debt_retains_artifact_and_validation_roots(self) -> None:
		workspace_state = {
			"schema_version": 1,
			"head": "a" * 40,
			"dirty": False,
			"untracked_file_count": 0,
			"fingerprint": "b" * 64,
		}
		captured = gf_maintenance.CapturedWorkspace(
			source_root=gf_maintenance.ROOT,
			head="a" * 40,
			binary_diff=b"",
			untracked_files=(),
			workspace_fingerprint="b" * 64,
		)
		retained_roots: dict[str, Path] = {}
		with tempfile.TemporaryDirectory() as temporary_directory:
			temp_root = Path(temporary_directory)

			def materialize(
				_captured: object,
				target: Path,
				**_kwargs: object,
			) -> Path:
				target.mkdir()
				retained_roots["artifact"] = target.parent
				return target

			def build_artifact(artifact_root: Path, *_args: object, **_kwargs: object) -> object:
				artifact_root.mkdir()
				artifact = mock.Mock()
				artifact.manifest_path = artifact_root / "manifest.json"
				artifact.manifest_sha256 = "c" * 64
				artifact.artifacts = (mock.Mock(),)
				return artifact

			def fail_parallel(
				_captured: object,
				parallel_root: Path,
				**kwargs: object,
			) -> object:
				retained_roots["validation"] = parallel_root
				kwargs["cleanup_state"]["permitted"] = False
				raise gf_maintenance.WorkspaceSnapshotError(
					"synthetic unproved Full consumer process boundary"
				)

			with mock.patch.dict(
				os.environ,
				{
					gf_maintenance.MAINTENANCE_VALIDATION_TEMP_ROOT_ENV_VAR: str(temp_root),
				},
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value=workspace_state,
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				return_value=["package_build_boundary"],
			), mock.patch.object(
				gf_maintenance,
				"resolve_check_jobs",
				return_value=2,
			), mock.patch.object(
				gf_maintenance,
				"WINDOWS_PARALLEL_VALIDATION_ROOT_MAX_CHARACTERS",
				260,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"capture_workspace",
				return_value=captured,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"materialize_workspace",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"build_package_smoke_artifact_set",
				side_effect=build_artifact,
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_full_checks",
				side_effect=fail_parallel,
			), mock.patch.object(
				gf_maintenance,
				"package_artifact_details",
				return_value={"retained_fixture": True},
			):
				result = gf_maintenance.run_checks(
					checks=["package_build_boundary"],
					jobs=2,
				)
			self.assertFalse(result["ok"])
			self.assertTrue(retained_roots["artifact"].exists())
			self.assertIn("validation", retained_roots, result)
			self.assertTrue(retained_roots["validation"].exists())
			self.assertIn(
				"temporary_workspace_cleanup",
				{item["name"] for item in result["results"]},
			)

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
			"discovery_contract_version": 2,
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

	def test_advisory_deadline_translates_and_caps_the_suite_clock(self) -> None:
		with mock.patch.object(
			gf_maintenance.time,
			"monotonic",
			return_value=1_000.0,
		), mock.patch.object(
			gf_maintenance.time,
			"perf_counter",
			return_value=100.0,
		):
			self.assertEqual(
				gf_maintenance.advisory_collection_deadline(15.0, 104.0),
				1_004.0,
			)
			self.assertEqual(
				gf_maintenance.advisory_collection_deadline(15.0, None),
				1_015.0,
			)

	def test_shadow_attachment_uses_the_suite_capped_deadline(self) -> None:
		data = {"checks": ["docs"]}
		workspace_state = self._workspace_state()
		with mock.patch.object(
			gf_maintenance,
			"advisory_collection_deadline",
			return_value=123.0,
		) as deadline, mock.patch.object(
			gf_maintenance,
			"make_validation_shadow_report",
			return_value={"report_ok": True},
		) as make_report:
			gf_maintenance.attach_validation_shadow_report(
				data,
				workspace_state,
				suite_deadline=50.0,
			)
		deadline.assert_called_once_with(
			gf_maintenance.VALIDATION_SHADOW_COLLECTION_TIMEOUT_SECONDS,
			50.0,
		)
		self.assertEqual(make_report.call_args.kwargs["shadow_deadline_seconds"], 123.0)

	def test_exhausted_suite_budget_makes_shadow_fail_closed_immediately(self) -> None:
		data = {"checks": ["docs"]}
		with mock.patch.object(
			gf_maintenance,
			"advisory_collection_deadline",
			return_value=10.0,
		), mock.patch.object(
			gf_maintenance.time,
			"monotonic",
			return_value=10.0,
		), mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
		) as inventory:
			gf_maintenance.attach_validation_shadow_report(
				data,
				self._workspace_state(),
				suite_deadline=1.0,
			)
		self.assertEqual(data["validation_shadow"]["errors"], ["shadow_deadline_exceeded"])
		inventory.assert_not_called()

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

	def test_package_artifact_action_key_uses_digest_not_ephemeral_path(self) -> None:
		workspace_state = self._workspace_state()

		def report(manifest_path: str, digest: str) -> dict[str, object]:
			data = {
				"ok": True,
				"suite": "package-contract",
				"checks": ["package_build_boundary"],
				"package_artifact_set": {
					"reused": False,
					"manifest_sha256": digest,
					"artifact_count": 1,
					"workspace_fingerprint": "a" * 64,
				},
				"results": [{
					"name": "package_build_boundary",
					"command": [
						"python",
						"tools/gf_maintenance.py",
						"package-build-boundary",
						"--package-artifact-manifest",
						manifest_path,
						"--package-artifact-manifest-sha256",
						digest,
					],
					"execution": "in_process",
					"exit_code": 0,
					"timed_out": False,
					"cancelled": False,
					"duration_seconds": 0.1,
					"result_fingerprint": "e" * 64,
				}],
			}
			with mock.patch.object(
				gf_maintenance.gf_validation_test_inventory,
				"collect_test_inventory",
				return_value=self._inventory(),
			):
				return gf_maintenance.make_validation_shadow_report(data, workspace_state)

		first = report("C:/temp/gfa-one/manifest.json", "1" * 64)
		second = report("C:/temp/gfa-two/manifest.json", "1" * 64)
		changed = report("C:/temp/gfa-two/manifest.json", "2" * 64)
		first_evidence = first["actions"][0]["shadow_evidence"]
		second_evidence = second["actions"][0]["shadow_evidence"]
		changed_evidence = changed["actions"][0]["shadow_evidence"]
		self.assertEqual(first_evidence["action_key"], second_evidence["action_key"])
		self.assertNotEqual(first_evidence["action_key"], changed_evidence["action_key"])
		material = first_evidence["action_key_material"]
		self.assertIn(
			gf_maintenance.PACKAGE_ARTIFACT_MANIFEST_ACTION_SENTINEL,
			material["command"],
		)
		self.assertNotIn("C:/temp/gfa-one/manifest.json", material["command"])
		self.assertEqual(
			material["dependency_artifacts"],
			{gf_maintenance.PACKAGE_ARTIFACT_MANIFEST_DEPENDENCY_LABEL: "1" * 64},
		)
		with self.assertRaisesRegex(ValueError, "differs from the parent"):
			gf_maintenance.validation_shadow_action_inputs(
				{"package_artifact_set": {
					"reused": False,
					"manifest_sha256": "1" * 64,
					"artifact_count": 1,
					"workspace_fingerprint": "a" * 64,
				}},
				"package_build_boundary",
				[
					"python",
					"--package-artifact-manifest",
					"C:/temp/gfa/manifest.json",
					"--package-artifact-manifest-sha256",
					"2" * 64,
				],
				workspace_digest="a" * 64,
				allow_planned_command=False,
			)
		malformed_commands = (
			[
				"python",
				"--package-artifact-manifest",
				"--package-artifact-manifest-sha256",
				"1" * 64,
			],
			[
				"python",
				"--package-artifact-manifest-sha256",
				"1" * 64,
				"--package-artifact-manifest",
				"manifest.json",
			],
			[
				"python",
				"--package-artifact-manifest",
				"one.json",
				"--package-artifact-manifest",
				"two.json",
				"--package-artifact-manifest-sha256",
				"1" * 64,
			],
		)
		artifact_data = {
			"package_artifact_set": {
				"reused": False,
				"manifest_sha256": "1" * 64,
				"artifact_count": 1,
				"workspace_fingerprint": "a" * 64,
			},
		}
		for command in malformed_commands:
			with self.subTest(command=command):
				with self.assertRaises(ValueError):
					gf_maintenance.validation_shadow_action_inputs(
						artifact_data,
						"package_build_boundary",
						command,
						workspace_digest="a" * 64,
						allow_planned_command=False,
					)

	def test_unstarted_package_action_uses_a_stable_planned_command(self) -> None:
		workspace_state = self._workspace_state()
		data = {
			"ok": False,
			"suite": "full",
			"checks": ["package_build_boundary"],
			"package_artifact_set": {
				"reused": False,
				"manifest_sha256": "1" * 64,
				"artifact_count": 1,
				"workspace_fingerprint": "a" * 64,
			},
			"results": [{
				"name": "package_build_boundary",
				"command": ["python", "tools/gf_maintenance.py", "package-build-boundary"],
				"execution": "not_started",
				"exit_code": 124,
				"timed_out": True,
				"cancelled": False,
				"duration_seconds": 0.0,
			}],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			report = gf_maintenance.make_validation_shadow_report(data, workspace_state)
		action = report["actions"][0]
		self.assertFalse(action["execution_observed"])
		material = action["shadow_evidence"]["action_key_material"]
		self.assertIn(
			gf_maintenance.PACKAGE_ARTIFACT_MANIFEST_ACTION_SENTINEL,
			material["command"],
		)
		self.assertEqual(
			material["dependency_artifacts"],
			{gf_maintenance.PACKAGE_ARTIFACT_MANIFEST_DEPENDENCY_LABEL: "1" * 64},
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

	def test_initial_workspace_process_control_exception_propagates(self) -> None:
		for error in (
			KeyboardInterrupt("fixture interrupt"),
			SystemExit(7),
			GeneratorExit("fixture generator exit"),
		):
			with self.subTest(error=type(error).__name__), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				side_effect=error,
			):
				with self.assertRaises(type(error)) as raised:
					gf_maintenance.run_checks(
						checks=["docs"],
						jobs=1,
						validation_shadow=True,
					)
			self.assertIs(raised.exception, error)

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

	def test_parallel_deadline_preserves_completed_shadow_occurrences(self) -> None:
		workspace_state = self._workspace_state()
		observations: dict[str, list[dict[str, object]]] = {}
		plans = [
			gf_maintenance.ParallelCheckShardPlan("first", ("docs",)),
			gf_maintenance.ParallelCheckShardPlan("second", ("api_reference",)),
		]

		def expanded_names(
			suite: str,
			checks: list[str] | None,
			**_kwargs: object,
		) -> list[str]:
			if suite == "full":
				return ["docs", "api_reference"]
			return list(checks or [])

		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			(root / "parallel").mkdir()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint=str(workspace_state["fingerprint"]),
			)

			def materialize(
				_captured: object,
				_batch_root: Path,
				batch_plan: list[object],
				**_kwargs: object,
			) -> dict[str, Path]:
				return {
					str(plan.name): root / str(plan.name)
					for plan in batch_plan
				}

			def make_shard(
				plan: object,
				workspace: Path,
				**_kwargs: object,
			) -> tuple[object, Path]:
				shard = gf_maintenance.ParallelShard(
					name=str(plan.name),
					command=("python", "-V"),
					workspace=workspace,
					timeout_seconds=1.0,
				)
				return shard, root / f"{plan.name}.json"

			def run_shards(shards: list[object], **_kwargs: object) -> list[object]:
				shard = shards[0]
				return [gf_maintenance.ParallelShardResult(
					name=str(shard.name),
					command=tuple(shard.command),
					workspace=shard.workspace,
					exit_code=0,
					process_exit_code=0,
					stdout="",
					stderr="",
					timed_out=False,
					cancelled=False,
					duration_seconds=1.0,
					pid=1,
					started=True,
					process_boundary_quiescent=True,
				)]

			report = {
				"ok": True,
				"results": [{
					"name": "docs",
					"execution": "subprocess",
					"exit_code": 0,
					"timed_out": False,
					"cancelled": False,
					"duration_seconds": 1.0,
					"input_fingerprint": "b" * 64,
					"result_fingerprint": "c" * 64,
				}],
			}
			with mock.patch.object(
				gf_maintenance,
				"parallel_full_shard_plan",
				return_value=plans,
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				side_effect=expanded_names,
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={"ok": True},
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
				side_effect=[
					None,
					gf_maintenance.WorkspaceDeadlineError("injected deadline"),
				],
			), mock.patch.object(
				gf_maintenance,
				"materialize_parallel_full_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"make_parallel_full_shard",
				side_effect=make_shard,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=run_shards,
			), mock.patch.object(
				gf_maintenance,
				"load_parallel_shard_report",
				return_value=(report, ""),
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value=workspace_state,
			):
				with self.assertRaises(gf_maintenance.WorkspaceDeadlineError):
					gf_maintenance.run_parallel_full_checks(
						captured,
						root / "parallel",
						jobs=1,
						timeout_seconds=None,
						suite_timeout_seconds=None,
						fail_fast=False,
						package_artifact_manifest="manifest.json",
						package_artifact_manifest_sha256="d" * 64,
						package_artifact_count=1,
						progress_callback=None,
						output_callback=None,
						overall_started=0.0,
						suite_deadline=None,
						validation_occurrences_out=observations,
					)

		self.assertEqual(len(observations["docs"]), 1)
		self.assertEqual(observations["docs"][0]["execution"], "subprocess")
		data = {
			"ok": False,
			"suite": "full",
			"checks": ["docs", "api_reference"],
			"results": [],
		}
		with mock.patch.object(
			gf_maintenance.gf_validation_test_inventory,
			"collect_test_inventory",
			return_value=self._inventory(),
		):
			shadow = gf_maintenance.make_validation_shadow_report(
				data,
				workspace_state,
				parallel_occurrences=observations,
			)
		self.assertEqual(shadow["execution_observation_count"], 1)

	def test_parallel_full_unproven_boundary_keeps_cleanup_fail_closed(self) -> None:
		plan = [gf_maintenance.ParallelCheckShardPlan("first", ("docs",))]
		cleanup_state = {"permitted": True}
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			parallel_root = root / "parallel"
			parallel_root.mkdir()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="b" * 64,
			)

			def materialize(
				_captured: object,
				batch_root: Path,
				_batch_plan: list[object],
				**_kwargs: object,
			) -> dict[str, Path]:
				workspace = batch_root / "first"
				workspace.mkdir()
				return {"first": workspace}

			def make_shard(
				_plan: object,
				workspace: Path,
				**_kwargs: object,
			) -> tuple[object, Path]:
				return (
					gf_maintenance.ParallelShard(
						name="first",
						command=("python", "-V"),
						workspace=workspace,
						timeout_seconds=1.0,
					),
					workspace / "report.json",
				)

			def run_shards(shards: list[object], **_kwargs: object) -> list[object]:
				shard = shards[0]
				return [gf_maintenance.ParallelShardResult(
					name=str(shard.name),
					command=tuple(shard.command),
					workspace=shard.workspace,
					exit_code=0,
					process_exit_code=0,
					stdout="",
					stderr="",
					timed_out=False,
					cancelled=False,
					duration_seconds=0.1,
					pid=1,
					started=True,
					process_boundary_quiescent=False,
				)]

			with mock.patch.object(
				gf_maintenance,
				"parallel_full_shard_plan",
				return_value=plan,
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				return_value=["docs"],
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={"ok": True},
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance,
				"materialize_parallel_full_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"make_parallel_full_shard",
				side_effect=make_shard,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=run_shards,
			), mock.patch.object(
				gf_maintenance,
				"load_parallel_shard_report",
			) as report_loader:
				with self.assertRaisesRegex(
					gf_maintenance.WorkspaceSnapshotError,
					"process-boundary cleanup",
				):
					gf_maintenance.run_parallel_full_checks(
						captured,
						parallel_root,
						jobs=1,
						timeout_seconds=None,
						suite_timeout_seconds=None,
						fail_fast=False,
						package_artifact_manifest="manifest.json",
						package_artifact_manifest_sha256="d" * 64,
						package_artifact_count=1,
						progress_callback=None,
						output_callback=None,
						overall_started=time.perf_counter(),
						suite_deadline=time.perf_counter() + 10.0,
						cleanup_state=cleanup_state,
					)
			self.assertFalse(cleanup_state["permitted"])
			report_loader.assert_not_called()

	def test_parallel_full_log_copy_failure_retains_source_batch(self) -> None:
		plan = [gf_maintenance.ParallelCheckShardPlan("first", ("docs",))]
		cleanup_state = {"permitted": True}
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			parallel_root = root / "parallel"
			parallel_root.mkdir()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="b" * 64,
			)
			retained_marker: Path | None = None

			def materialize(
				_captured: object,
				batch_root: Path,
				_batch_plan: list[object],
				**_kwargs: object,
			) -> dict[str, Path]:
				nonlocal retained_marker
				workspace = batch_root / "first"
				workspace.mkdir()
				retained_marker = workspace / "must-retain.log"
				retained_marker.write_text("source evidence", encoding="utf-8")
				return {"first": workspace}

			def make_shard(
				_plan: object,
				workspace: Path,
				**_kwargs: object,
			) -> tuple[object, Path]:
				return (
					gf_maintenance.ParallelShard(
						name="first",
						command=("python", "-V"),
						workspace=workspace,
						timeout_seconds=1.0,
					),
					workspace / "report.json",
				)

			def run_shards(shards: list[object], **_kwargs: object) -> list[object]:
				shard = shards[0]
				return [gf_maintenance.ParallelShardResult(
					name=str(shard.name),
					command=tuple(shard.command),
					workspace=shard.workspace,
					exit_code=1,
					process_exit_code=1,
					stdout="",
					stderr="synthetic failure",
					timed_out=False,
					cancelled=False,
					duration_seconds=0.1,
					pid=1,
					started=True,
					process_boundary_quiescent=True,
				)]

			report = {
				"ok": False,
				"results": [{
					"name": "docs",
					"exit_code": 1,
					"timed_out": False,
					"cancelled": False,
					"duration_seconds": 0.1,
				}],
			}
			with mock.patch.object(
				gf_maintenance,
				"parallel_full_shard_plan",
				return_value=plan,
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				return_value=["docs"],
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={"ok": True},
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance,
				"materialize_parallel_full_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"make_parallel_full_shard",
				side_effect=make_shard,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				side_effect=run_shards,
			), mock.patch.object(
				gf_maintenance,
				"load_parallel_shard_report",
				return_value=(report, ""),
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "b" * 64},
			), mock.patch.object(
				gf_maintenance,
				"collect_parallel_failure_logs",
				return_value=["first: synthetic copy failure"],
			):
				with self.assertRaises(
					gf_maintenance.WorkspaceSnapshotError,
				) as raised:
					gf_maintenance.run_parallel_full_checks(
						captured,
						parallel_root,
						jobs=1,
						timeout_seconds=None,
						suite_timeout_seconds=None,
						fail_fast=False,
						package_artifact_manifest="manifest.json",
						package_artifact_manifest_sha256="d" * 64,
						package_artifact_count=1,
						progress_callback=None,
						output_callback=None,
						overall_started=time.perf_counter(),
						suite_deadline=time.perf_counter() + 10.0,
						cleanup_state=cleanup_state,
					)
			self.assertIn("batch cleanup failed", str(raised.exception))
			self.assertIn("first: synthetic copy failure", str(raised.exception))
			self.assertFalse(cleanup_state["permitted"])
			self.assertIsNotNone(retained_marker)
			assert retained_marker is not None
			self.assertEqual(
				retained_marker.read_text(encoding="utf-8"),
				"source evidence",
			)

	def test_parallel_full_passing_batch_cleanup_failure_keeps_its_reason(self) -> None:
		plan = [gf_maintenance.ParallelCheckShardPlan("first", ("docs",))]
		cleanup_state = {"permitted": True}
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			parallel_root = root / "parallel"
			parallel_root.mkdir()
			captured = gf_maintenance.CapturedWorkspace(
				source_root=root,
				head="a" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="b" * 64,
			)
			retained_marker: Path | None = None

			@contextlib.contextmanager
			def retained_batch(
				path: Path,
				**kwargs: object,
			) -> object:
				path.mkdir()
				try:
					yield path
				finally:
					cleanup_errors = kwargs["cleanup_errors"]
					assert isinstance(cleanup_errors, list)
					cleanup_errors.append("synthetic passing-batch cleanup failure")
					cleanup_failed = kwargs["cleanup_failed"]
					assert callable(cleanup_failed)
					cleanup_failed()

			def materialize(
				_captured: object,
				batch_root: Path,
				_batch_plan: list[object],
				**_kwargs: object,
			) -> dict[str, Path]:
				nonlocal retained_marker
				workspace = batch_root / "first"
				workspace.mkdir()
				retained_marker = workspace / "must-retain.log"
				retained_marker.write_text("source evidence", encoding="utf-8")
				return {"first": workspace}

			def make_shard(
				_plan: object,
				workspace: Path,
				**_kwargs: object,
			) -> tuple[object, Path]:
				return (
					gf_maintenance.ParallelShard(
						name="first",
						command=("python", "-V"),
						workspace=workspace,
						timeout_seconds=1.0,
					),
					workspace / "report.json",
				)

			report = {
				"ok": True,
				"results": [{
					"name": "docs",
					"exit_code": 0,
					"timed_out": False,
					"cancelled": False,
					"duration_seconds": 0.1,
				}],
			}
			shard_result = gf_maintenance.ParallelShardResult(
				name="first",
				command=("python", "-V"),
				workspace=parallel_root / "b0" / "first",
				exit_code=0,
				process_exit_code=0,
				stdout="",
				stderr="",
				timed_out=False,
				cancelled=False,
				duration_seconds=0.1,
				pid=1,
				started=True,
				process_boundary_quiescent=True,
			)
			with mock.patch.object(
				gf_maintenance,
				"parallel_full_shard_plan",
				return_value=plan,
			), mock.patch.object(
				gf_maintenance,
				"expanded_check_names",
				return_value=["docs"],
			), mock.patch.object(
				gf_maintenance,
				"run_parallel_godot_isolation_probe",
				return_value={"ok": True},
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"assert_source_matches_snapshot",
			), mock.patch.object(
				gf_maintenance,
				"managed_owned_directory",
				side_effect=retained_batch,
			), mock.patch.object(
				gf_maintenance,
				"materialize_parallel_full_workspaces",
				side_effect=materialize,
			), mock.patch.object(
				gf_maintenance,
				"make_parallel_full_shard",
				side_effect=make_shard,
			), mock.patch.object(
				gf_maintenance.gf_parallel_validation,
				"run_parallel_shards",
				return_value=[shard_result],
			), mock.patch.object(
				gf_maintenance,
				"load_parallel_shard_report",
				return_value=(report, ""),
			), mock.patch.object(
				gf_maintenance,
				"workspace_fingerprint",
				return_value={"fingerprint": "b" * 64},
			), mock.patch.object(
				gf_maintenance,
				"collect_parallel_failure_logs",
			) as collect_logs:
				with self.assertRaises(
					gf_maintenance.WorkspaceSnapshotError,
				) as raised:
					gf_maintenance.run_parallel_full_checks(
						captured,
						parallel_root,
						jobs=1,
						timeout_seconds=None,
						suite_timeout_seconds=None,
						fail_fast=False,
						package_artifact_manifest="manifest.json",
						package_artifact_manifest_sha256="d" * 64,
						package_artifact_count=1,
						progress_callback=None,
						output_callback=None,
						overall_started=time.perf_counter(),
						suite_deadline=time.perf_counter() + 10.0,
						cleanup_state=cleanup_state,
					)
			collect_logs.assert_not_called()
			self.assertIn("synthetic passing-batch cleanup failure", str(raised.exception))
			self.assertFalse(cleanup_state["permitted"])
			self.assertIsNotNone(retained_marker)
			assert retained_marker is not None
			self.assertEqual(
				retained_marker.read_text(encoding="utf-8"),
				"source evidence",
			)

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

	def test_affected_attachment_uses_the_suite_capped_deadline(self) -> None:
		data = {"checks": ["docs"]}
		with mock.patch.object(
			gf_maintenance,
			"advisory_collection_deadline",
			return_value=321.0,
		) as deadline, mock.patch.object(
			gf_maintenance.gf_validation_inputs,
			"analyze_affected_checks",
			return_value=self._analysis(),
		) as analyze:
			gf_maintenance.attach_affected_analysis_report(
				data,
				base_revision="HEAD",
				explain=True,
				suite_deadline=75.0,
			)
		deadline.assert_called_once_with(
			gf_maintenance.AFFECTED_ANALYSIS_COLLECTION_TIMEOUT_SECONDS,
			75.0,
		)
		self.assertEqual(analyze.call_args.kwargs["deadline_seconds"], 321.0)

	def test_exhausted_suite_budget_makes_affected_analysis_fail_closed(self) -> None:
		data = {"checks": ["docs"]}
		with mock.patch.object(
			gf_maintenance,
			"advisory_collection_deadline",
			return_value=10.0,
		), mock.patch.object(
			gf_maintenance.time,
			"monotonic",
			return_value=10.0,
		):
			gf_maintenance.attach_affected_analysis_report(
				data,
				base_revision="HEAD",
				explain=False,
				suite_deadline=1.0,
			)
		self.assertEqual(
			data["affected_analysis"]["errors"],
			["affected_deadline_exceeded"],
		)

	def test_reported_duration_includes_both_advisory_attachments(self) -> None:
		workspace_state = self._workspace_state()
		clock = [10.0]
		shadow_deadlines: list[object] = []
		affected_deadlines: list[object] = []

		def attach_shadow(data: dict[str, object], *_args: object, **kwargs: object) -> None:
			shadow_deadlines.append(kwargs.get("suite_deadline"))
			clock[0] = 12.0
			data["validation_shadow"] = {"report_ok": True}

		def attach_affected(data: dict[str, object], **kwargs: object) -> None:
			affected_deadlines.append(kwargs.get("suite_deadline"))
			clock[0] = 15.0
			data["affected_analysis"] = self._analysis()

		with mock.patch.object(
			gf_maintenance.time,
			"perf_counter",
			side_effect=lambda: clock[0],
		), mock.patch.object(
			gf_maintenance,
			"workspace_fingerprint",
			return_value=workspace_state,
		), mock.patch.object(
			gf_maintenance,
			"maintenance_in_process_check_runners",
			return_value={"docs": lambda: {"ok": True}},
		), mock.patch.object(
			gf_maintenance,
			"attach_validation_shadow_report",
			side_effect=attach_shadow,
		), mock.patch.object(
			gf_maintenance,
			"attach_affected_analysis_report",
			side_effect=attach_affected,
		):
			result = gf_maintenance.run_checks(
				checks=["docs"],
				jobs=1,
				validation_shadow=True,
				affected=True,
				suite_timeout_seconds=10,
			)
		self.assertEqual(result["duration_seconds"], 5.0)
		self.assertEqual(shadow_deadlines, [20.0])
		self.assertEqual(affected_deadlines, [20.0])

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
