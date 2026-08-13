#!/usr/bin/env python3
"""Focused behavioral tests for GF maintenance execution/protocol boundaries."""

from __future__ import annotations

import io
import json
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

	def test_observation_timeout_has_an_independent_twelve_minute_floor(self) -> None:
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
		self.assertNotIn("gut", gf_maintenance.CHECK_TIMEOUT_SECONDS)

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
