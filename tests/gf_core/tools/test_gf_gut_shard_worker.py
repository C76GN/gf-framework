#!/usr/bin/env python3
"""Focused pure-Python tests for the single-shard GUT worker."""

from __future__ import annotations

from dataclasses import replace
import hashlib
import json
import os
from pathlib import Path, PureWindowsPath
import secrets
import sys
import tempfile
import threading
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_gut_shard_worker as worker  # noqa: E402
from gf_process_supervisor import SupervisedProcessResult  # noqa: E402


class GutShardWorkerTests(unittest.TestCase):
	def test_inventory_discovery_delegates_fresh_scans_under_worker_deadline(self) -> None:
		workspace = Path("private-workspace")
		with mock.patch.object(
			worker.gf_gut_sharding,
			"discover_gut_test_scripts",
			return_value=(self.SCRIPT_A, self.SCRIPT_B),
		) as discover:
			actual = worker._discover_inventory_with_deadline(  # noqa: SLF001
				workspace,
				123.0,
			)
		self.assertEqual(actual, (self.SCRIPT_A, self.SCRIPT_B))
		discover.assert_called_once_with(workspace, deadline=123.0)

	def test_inventory_deadline_has_a_distinct_preflight_issue(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory)
			with (
				mock.patch.object(
					worker,
					"_discover_inventory_with_deadline",
					side_effect=worker.gf_gut_sharding.GutShardingError(
						"inventory_deadline_exceeded",
						"synthetic deadline",
					),
				),
				self.assertRaisesRegex(
					worker.GutShardWorkerError,
					"worker_inventory_deadline_exhausted",
				),
			):
				worker._validate_shard_binding(  # noqa: SLF001
					workspace,
					{},
					self._identity(workspace),
					deadline=float("inf"),
				)

	def test_builder_uses_exact_repeated_gtest_selection(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			junit = (Path(temporary_directory) / "result.xml").resolve()
			argv = worker.build_gut_shard_argv(
				("godot", "--headless", "-s", "res://tests/gf_core/support/gf_gut_cli.gd"),
				config_path="res://.gutconfig.json",
				pre_run_script="res://tests/gf_core/support/gf_gut_pre_run_hook.gd",
				post_run_script="res://tests/gf_core/support/gf_gut_post_run_hook.gd",
				scripts=(self.SCRIPT_A, self.SCRIPT_B),
				junit_xml_path=str(junit),
			)
		self.assertNotIn("-ginclude_subdirs", argv)
		self.assertFalse(any(argument.startswith("-gdir") for argument in argv))
		self.assertEqual(
			[(argv[index], argv[index + 1]) for index, value in enumerate(argv[:-1]) if value == "-gtest"],
			[("-gtest", self.SCRIPT_A), ("-gtest", self.SCRIPT_B)],
		)
		self.assertEqual(argv[-1], "-gexit")
		self.assertNotIn("-gdisable_colors", argv)

	def test_builder_rejects_owned_base_options_and_ambiguous_paths(self) -> None:
		with self.assertRaisesRegex(worker.GutShardWorkerError, "base_selection_forbidden"):
			self._build_argv(("godot", "-gdir=res://tests"), (self.SCRIPT_A,))
		for scripts in (("res://tests/gf_core/a/test_a,test_b.gd",), ("res://tests/gf_core/../test_a.gd",)):
			with self.subTest(scripts=scripts), self.assertRaisesRegex(worker.GutShardWorkerError, "scripts_invalid"):
				self._build_argv(("godot",), scripts)

	def test_builder_rejects_script_identity_and_argv_budget_violations(self) -> None:
		for scripts in ((), (self.SCRIPT_B, self.SCRIPT_A), (self.SCRIPT_A, self.SCRIPT_A)):
			with self.subTest(scripts=scripts), self.assertRaisesRegex(worker.GutShardWorkerError, "scripts_invalid"):
				self._build_argv(("godot",), scripts)
		with self.assertRaisesRegex(worker.GutShardWorkerError, "argv_budget_exceeded"):
			self._build_argv(tuple("x" for _ in range(worker.MAX_GUT_SHARD_ARGV_ITEMS + 1)), (self.SCRIPT_A,))

	def test_request_schema_is_closed_and_normalized(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			request = self._request(Path(temporary_directory))
			normalized = worker.validate_request(request)
			self.assertEqual(set(normalized), worker.REQUEST_KEYS)
			self.assertIsInstance(normalized["remaining_seconds"], float)
			with self.assertRaisesRegex(worker.GutShardWorkerError, "worker_request_schema_invalid"):
				worker.validate_request({**request, "unexpected": True})
			with self.assertRaisesRegex(worker.GutShardWorkerError, "schema_unsupported"):
				worker.validate_request({**request, "schema_version": True})
			for invalid_digest in ("A" * 64, "0" * 63, True):
				with self.subTest(runtime_source_digest=invalid_digest), self.assertRaisesRegex(
					worker.GutShardWorkerError,
					"worker_request_digest_invalid",
				):
					worker.validate_request({
						**request,
						"runtime_source_digest": invalid_digest,
					})
			with self.assertRaisesRegex(
				worker.GutShardWorkerError,
				"worker_request_nonce_invalid",
			):
				worker.validate_request({**request, "nonce": secrets.token_hex(16)})

	def test_request_rejects_relative_workspace_and_absolute_deadline_shape(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			request = self._request(Path(temporary_directory))
			request["workspace_path"] = "relative/workspace"
			with self.assertRaisesRegex(worker.GutShardWorkerError, "workspace_path"):
				worker.validate_request(request)
			request = self._request(Path(temporary_directory))
			request["deadline_monotonic_ns"] = 1
			with self.assertRaisesRegex(worker.GutShardWorkerError, "schema_invalid"):
				worker.validate_request(request)

	def test_request_rejects_unsorted_duplicate_or_noncanonical_scripts(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			for scripts in (
				[self.SCRIPT_B, self.SCRIPT_A],
				[self.SCRIPT_A, self.SCRIPT_A],
				["tests/gf_core/a/test_a.gd"],
			):
				request = self._request(root)
				request["scripts"] = scripts
				with self.assertRaisesRegex(worker.GutShardWorkerError, "worker_request_scripts_invalid"):
					worker.validate_request(request)

	def test_empty_report_is_closed_observational_and_has_zero_reuse_counts(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			request = worker.validate_request(self._request(Path(temporary_directory)))
			report = worker._empty_report(request)  # noqa: SLF001
			self.assertEqual(set(report), worker.REPORT_KEYS)
			self.assertEqual(set(report["import_result"]), worker.PHASE_RESULT_KEYS)
			self.assertEqual(set(report["observation_policy"]), worker.POLICY_KEYS)
			self.assertTrue(report["observation_policy"]["observation_only"])
			self.assertFalse(report["workspace_cleanup_permitted"])
			for key in ("skip_count", "cache_read_count", "cache_write_count", "reuse_count", "persistence_count"):
				self.assertEqual(report["observation_policy"][key], 0)
			report["issues"].append({"kind": "fixture", "message": "fixture", "phase": "fixture"})
			worker.validate_report_shape(report)

	def test_import_failure_never_starts_gut(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			calls: list[list[str]] = []
			def process_runner(command: list[str], **_kwargs: object) -> SupervisedProcessResult:
				calls.append(command)
				return self._process_result(return_code=1)
			with (
				mock.patch.object(
					worker,
					"_validate_workspace_binding",
					return_value=root.lstat(),
				),
				mock.patch.object(worker, "_validate_shard_binding"),
			):
				report = worker.run_worker(
					request,
					process_runner=process_runner,
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
			self.assertFalse(report["ok"])
			self.assertEqual(report["import_run_count"], 1)
			self.assertEqual(report["gut_run_count"], 0)
			self.assertEqual(len(calls), 1)
			self.assertEqual(report["issues"][0]["phase"], "import")

	def test_worker_requires_materializer_publication_identity(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			process_runner = mock.Mock(side_effect=AssertionError("runner must not start"))
			report = worker.run_worker(
				self._request(root),
				process_runner=process_runner,
				result_adapter=self._authority_adapter,
			)
			self.assertFalse(report["workspace_cleanup_permitted"])
			self.assertFalse(report["continuation_safe"])
			self.assertEqual(
				report["issues"][0]["kind"],
				"worker_workspace_publication_identity_mismatch",
			)
			process_runner.assert_not_called()
			worker.validate_report(report)

	def test_worker_uses_remaining_budget_and_exact_selected_argv(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			calls: list[tuple[list[str], float]] = []
			def process_runner(command: list[str], **kwargs: object) -> SupervisedProcessResult:
				calls.append((command, float(kwargs["timeout_seconds"])))
				if len(calls) == 2:
					self._publish_observation_pair(
						root,
						command,
						self._environment(kwargs),
						request["scripts"],
						str(request["nonce"]),
					)
				return self._process_result()
			real_parser = worker.gf_gut_sharding.parse_gut_junit_xml
			with (
				mock.patch.object(
					worker,
					"_validate_workspace_binding",
					return_value=root.lstat(),
				),
				mock.patch.object(worker, "_validate_shard_binding"),
				mock.patch.object(worker, "_parse_lifecycle_for_test", return_value={"ok": True}),
				mock.patch.object(
					worker.gf_gut_sharding,
					"parse_gut_junit_xml",
					wraps=real_parser,
				) as parse_junit,
			):
				report = worker.run_worker(
					request,
					process_runner=process_runner,
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
			self.assertTrue(report["ok"])
			self.assertEqual(report["import_run_count"], 1)
			self.assertEqual(report["gut_run_count"], 1)
			self.assertLessEqual(calls[0][1], request["import_timeout_seconds"])
			self.assertLessEqual(calls[1][1], request["gut_timeout_seconds"])
			gut_command = calls[1][0]
			self.assertNotIn("-ginclude_subdirs", gut_command)
			self.assertFalse(any(part.startswith("-gdir") for part in gut_command))
			self.assertEqual(
				[
					(gut_command[index], gut_command[index + 1])
					for index, argument in enumerate(gut_command[:-1])
					if argument == "-gtest"
				],
				[
					("-gtest", self.SCRIPT_A),
					("-gtest", self.SCRIPT_B),
				],
			)

			invocation_root = (
				root / "build" / "gut-sharding" / str(request["nonce"])
			)
			junit_path = invocation_root / "gut-authoritative.xml"
			provenance_path = (
				invocation_root / "gut-authoritative-provenance.json"
			)
			self.assertEqual(
				Path(
					next(
						part.split("=", 1)[1]
						for part in gut_command
						if part.startswith("-gjunit_xml_file=")
					)
				),
				junit_path,
			)
			parse_junit.assert_called_once()
			self.assertEqual(parse_junit.call_args.args, (junit_path,))
			self.assertEqual(
				parse_junit.call_args.kwargs,
				{
					"expected_scripts": tuple(request["scripts"]),
					"expected_file_identity": (
						worker.gf_gut_sharding.stable_file_identity(
							junit_path.lstat()
						)
					),
					"trusted_unfiltered_run": True,
					"provenance_path": provenance_path,
					"expected_provenance_identity": (
						worker.gf_gut_sharding.stable_file_identity(
							provenance_path.lstat()
						)
					),
					"expected_provenance_nonce": request["nonce"],
				},
			)
			self.assertTrue(report["junit"]["input_complete"])

	def test_preflight_time_does_not_reduce_import_or_gut_phase_floors(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			clock = [0.0]
			phase_timeouts: list[float] = []
			def consume_preflight(*_args: object, **_kwargs: object) -> None:
				clock[0] += float(worker.WORKER_PREFLIGHT_ALLOWANCE_SECONDS)
			def process_runner(command: list[str], **kwargs: object) -> SupervisedProcessResult:
				timeout = float(kwargs["timeout_seconds"])
				phase_timeouts.append(timeout)
				clock[0] += timeout
				if len(phase_timeouts) == 2:
					self._publish_observation_pair(
						root,
						command,
						self._environment(kwargs),
						request["scripts"],
						str(request["nonce"]),
					)
				return self._process_result()
			with (
				mock.patch.object(worker.time, "monotonic", side_effect=lambda: clock[0]),
				mock.patch.object(worker, "_validate_workspace_binding", return_value=root.lstat()),
				mock.patch.object(worker, "_validate_shard_binding", side_effect=consume_preflight),
				mock.patch.object(worker, "_parse_lifecycle_for_test", return_value={"ok": True}),
			):
				report = worker.run_worker(
					request,
					process_runner=process_runner,
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
		self.assertTrue(report["ok"])
		self.assertEqual(
			phase_timeouts,
			[request["import_timeout_seconds"], request["gut_timeout_seconds"]],
		)

	def test_preflight_overrun_refuses_import_before_process_launch(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			clock = [0.0]
			process_runner = mock.Mock(side_effect=AssertionError("runner must not start"))
			def overrun_preflight(*_args: object, **_kwargs: object) -> None:
				clock[0] += float(worker.WORKER_PREFLIGHT_ALLOWANCE_SECONDS) + 0.001
			with (
				mock.patch.object(worker.time, "monotonic", side_effect=lambda: clock[0]),
				mock.patch.object(worker, "_validate_workspace_binding", return_value=root.lstat()),
				mock.patch.object(worker, "_validate_shard_binding", side_effect=overrun_preflight),
			):
				report = worker.run_worker(
					request,
					process_runner=process_runner,
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
		process_runner.assert_not_called()
		self.assertEqual(report["import_run_count"], 0)
		self.assertEqual(
			[(issue["kind"], issue["phase"]) for issue in report["issues"]],
			[("worker_deadline_exhausted", "import")],
		)
		self.assertTrue(report["worker_cleanup_complete"])
		self.assertTrue(report["workspace_cleanup_permitted"])
		self.assertFalse(report["continuation_safe"])
		worker.validate_report(report)

	def test_failed_gut_attaches_strict_junit_without_becoming_successful(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			calls = 0
			def process_runner(command: list[str], **kwargs: object) -> SupervisedProcessResult:
				nonlocal calls
				calls += 1
				if calls == 2:
					self._publish_observation_pair(
						root,
						command,
						self._environment(kwargs),
						request["scripts"],
						str(request["nonce"]),
						first_status="fail",
					)
				return self._process_result(return_code=int(calls == 2))
			with (
				mock.patch.object(worker, "_validate_workspace_binding", return_value=root.lstat()),
				mock.patch.object(worker, "_validate_shard_binding"),
				mock.patch.object(worker, "_parse_lifecycle_for_test", return_value={"ok": True}),
			):
				report = worker.run_worker(
					request,
					process_runner=process_runner,
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
		self.assertFalse(report["ok"])
		self.assertEqual(
			[issue["kind"] for issue in report["issues"]],
			["worker_gut_failed"],
		)
		self.assertEqual(report["junit"]["failure_test_count"], 1)
		self.assertEqual(report["junit"]["failure_assertion_count"], 1)
		self.assertEqual(report["junit_digest"], worker.canonical_digest(report["junit"]))
		self.assertTrue(report["continuation_safe"])
		worker.validate_report(report)

	def test_failed_gut_missing_junit_keeps_primary_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			calls = 0
			def process_runner(_command: list[str], **_kwargs: object) -> SupervisedProcessResult:
				nonlocal calls
				calls += 1
				return self._process_result(return_code=int(calls == 2))
			with (
				mock.patch.object(worker, "_validate_workspace_binding", return_value=root.lstat()),
				mock.patch.object(worker, "_validate_shard_binding"),
				mock.patch.object(worker, "_parse_lifecycle_for_test", return_value={"ok": True}),
			):
				report = worker.run_worker(
					request,
					process_runner=process_runner,
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
		self.assertFalse(report["ok"])
		self.assertEqual(
			[issue["kind"] for issue in report["issues"]],
			["worker_gut_failed"],
		)
		self.assertIsNone(report["junit"])
		self.assertIsNone(report["junit_digest"])
		self.assertTrue(report["continuation_safe"])
		worker.validate_report(report)

	def test_failed_gut_incomplete_junit_is_not_attached(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			calls = 0
			def process_runner(_command: list[str], **_kwargs: object) -> SupervisedProcessResult:
				nonlocal calls
				calls += 1
				return self._process_result(return_code=int(calls == 2))
			with (
				mock.patch.object(worker, "_validate_workspace_binding", return_value=root.lstat()),
				mock.patch.object(worker, "_validate_shard_binding"),
				mock.patch.object(worker, "_parse_lifecycle_for_test", return_value={"ok": True}),
				mock.patch.object(
					worker,
					"_parse_published_junit_observation",
					return_value={"ok": False, "input_complete": False},
				),
			):
				report = worker.run_worker(
					request,
					process_runner=process_runner,
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
		self.assertEqual(
			[issue["kind"] for issue in report["issues"]],
			["worker_gut_failed"],
		)
		self.assertIsNone(report["junit"])
		self.assertIsNone(report["junit_digest"])
		self.assertTrue(report["continuation_safe"])
		worker.validate_report(report)

	def test_failed_gut_invalid_junit_keeps_primary_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			calls = 0
			def process_runner(_command: list[str], **_kwargs: object) -> SupervisedProcessResult:
				nonlocal calls
				calls += 1
				return self._process_result(return_code=int(calls == 2))
			with (
				mock.patch.object(worker, "_validate_workspace_binding", return_value=root.lstat()),
				mock.patch.object(worker, "_validate_shard_binding"),
				mock.patch.object(worker, "_parse_lifecycle_for_test", return_value={"ok": True}),
				mock.patch.object(
					worker,
					"_parse_published_junit_observation",
					side_effect=worker.GutShardWorkerError(
						"worker_junit_rejected",
						"synthetic invalid pair",
						"junit",
					),
				),
			):
				report = worker.run_worker(
					request,
					process_runner=process_runner,
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
		self.assertEqual(
			[issue["kind"] for issue in report["issues"]],
			["worker_gut_failed"],
		)
		self.assertIsNone(report["junit"])
		self.assertIsNone(report["junit_digest"])
		self.assertTrue(report["continuation_safe"])
		worker.validate_report(report)

	def test_control_mode_preserves_authoritative_directory_selection(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			request.update({
				"mode": worker.CONTROL_MODE,
				"shard_name": worker.CONTROL_SHARD_NAME,
				"role": worker.CONTROL_ROLE,
			})
			calls: list[list[str]] = []
			def process_runner(command: list[str], **_kwargs: object) -> SupervisedProcessResult:
				calls.append(command)
				if len(calls) == 2:
					self._publish_observation_pair(
						root,
						command,
						self._environment(_kwargs),
						request["scripts"],
						str(request["nonce"]),
					)
				return self._process_result()
			with (
				mock.patch.object(worker, "_validate_workspace_binding", return_value=root.lstat()),
				mock.patch.object(worker, "_validate_shard_binding"),
				mock.patch.object(worker, "_parse_lifecycle_for_test", return_value={"ok": True}),
			):
				report = worker.run_worker(
					request,
					process_runner=process_runner,
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
			self.assertTrue(report["ok"])
			self.assertIn("-ginclude_subdirs", calls[1])
			self.assertIn("-gdir=res://tests/gf_core", calls[1])
			self.assertFalse(any(part.startswith("-gtest=") for part in calls[1]))
			log_index = calls[1].index("--log-file") + 1
			self.assertEqual(
				Path(calls[1][log_index]).parent,
				root / "ai_analysis/godot_logs",
			)

	def test_missing_pair_rejection_covers_phase_sum_with_coarse_wall_timer(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			with (
				mock.patch.object(
					worker.time,
					"perf_counter",
					side_effect=(100.0, 100.019999),
				),
				mock.patch.object(
					worker,
					"_validate_workspace_binding",
					return_value=root.lstat(),
				),
				mock.patch.object(worker, "_validate_shard_binding"),
				mock.patch.object(
					worker,
					"_parse_lifecycle_for_test",
					return_value={"ok": True},
				),
			):
				report = worker.run_worker(
					request,
					process_runner=lambda *_args, **_kwargs: self._process_result(),
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
		self.assertFalse(report["ok"])
		self.assertTrue(report["process_boundary_quiescent"])
		self.assertEqual(report["issues"][0]["kind"], "worker_junit_rejected")
		self.assertEqual(report["issues"][0]["phase"], "junit")
		self.assertEqual(report["duration_seconds"], 0.02)
		worker.validate_report(report)

	def test_observation_file_identity_drift_after_parse_is_rejected(self) -> None:
		for drift_target in ("junit", "provenance"):
			with self.subTest(drift_target=drift_target), tempfile.TemporaryDirectory() as temporary_directory:
				root = Path(temporary_directory)
				request = self._request(root)
				calls = 0
				def process_runner(command: list[str], **kwargs: object) -> SupervisedProcessResult:
					nonlocal calls
					calls += 1
					if calls == 2:
						self._publish_observation_pair(
							root,
							command,
							self._environment(kwargs),
							request["scripts"],
							str(request["nonce"]),
						)
					return self._process_result()
				real_parser = worker.gf_gut_sharding.parse_gut_junit_xml
				def parse_then_replace(path: Path, **kwargs: object) -> dict[str, object]:
					result = real_parser(path, **kwargs)
					target = (
						path
						if drift_target == "junit"
						else Path(str(kwargs["provenance_path"]))
					)
					replacement = target.with_name(f"replacement-{target.name}")
					replacement.write_bytes(target.read_bytes())
					os.replace(replacement, target)
					return result
				with (
					mock.patch.object(
						worker,
						"_validate_workspace_binding",
						return_value=root.lstat(),
					),
					mock.patch.object(worker, "_validate_shard_binding"),
					mock.patch.object(
						worker,
						"_parse_lifecycle_for_test",
						return_value={"ok": True},
					),
					mock.patch.object(
						worker.gf_gut_sharding,
						"parse_gut_junit_xml",
						side_effect=parse_then_replace,
					),
				):
					report = worker.run_worker(
						request,
						process_runner=process_runner,
						result_adapter=self._authority_adapter,
						expected_workspace_identity=self._identity(root),
					)
				self.assertFalse(report["ok"])
				self.assertEqual(
					report["issues"][0]["kind"],
					"worker_junit_rejected",
				)
				worker.validate_report(report)

	def test_private_platform_roots_are_outside_project_and_cleaned(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			workspace = parent / "workspace"
			workspace.mkdir()
			private_root = parent / "private-root"
			environment = worker._private_environment(  # noqa: SLF001
				workspace,
				private_root,
				observation_nonce="a" * 64,
			)
			self.assertFalse(worker._paths_overlap(workspace, private_root))  # noqa: SLF001
			self.assertTrue(all(Path(environment[key]).is_relative_to(private_root) for key in ("TEMP", "TMP", "TMPDIR")))
			identity = private_root.lstat()
			self.assertEqual(worker._remove_private_environment_root(private_root, identity), "")  # noqa: SLF001
			self.assertFalse(private_root.exists())

	def test_private_environment_production_layout_preserves_windows_path_budget(self) -> None:
		validation_root = PureWindowsPath("D:/") / ("gfs-" + "x" * 12)
		self.assertEqual(len(str(validation_root)), 19)
		workspace_s0 = validation_root / "0" / "s0"
		workspace_s1 = validation_root / "0" / "s1"
		private_s0 = worker._private_environment_root_path(workspace_s0, "a" * 64)  # noqa: SLF001
		private_s1 = worker._private_environment_root_path(workspace_s1, "b" * 64)  # noqa: SLF001
		private_last = worker._private_environment_root_path(  # noqa: SLF001
			validation_root / "8" / "s0",
			"c" * 64,
		)
		private_control = worker._private_environment_root_path(  # noqa: SLF001
			validation_root / "c" / "s0",
			"d" * 64,
		)
		self.assertEqual(private_s0, validation_root / "0" / "0")
		self.assertEqual(private_s1, validation_root / "0" / "1")
		self.assertEqual(private_last, validation_root / "8" / "0")
		self.assertEqual(private_control, validation_root / "c" / "0")
		self.assertNotEqual(private_s0, private_s1)
		jobs_one_roots = {
			worker._private_environment_root_path(  # noqa: SLF001
				validation_root / str(index) / "s0",
				f"{index:x}" * 64,
			)
			for index in range(9)
		}
		jobs_two_roots = {
			worker._private_environment_root_path(  # noqa: SLF001
				validation_root / str(index // 2) / f"s{index % 2}",
				f"{index:x}" * 64,
			)
			for index in range(9)
		}
		self.assertEqual(
			jobs_one_roots,
			{validation_root / str(index) / "0" for index in range(9)},
		)
		self.assertEqual(
			jobs_two_roots,
			{
				validation_root / str(index // 2) / str(index % 2)
				for index in range(9)
			},
		)
		self.assertEqual(
			worker.WINDOWS_GUT_USER_PATH_RESERVE_CHARACTERS,
			worker.WINDOWS_GUT_KNOWN_DEEPEST_RELATIVE_PATH_CHARACTERS
			+ worker.WINDOWS_GUT_PATH_GROWTH_MARGIN_CHARACTERS,
		)
		for private_root in (private_s0, private_s1, private_last, private_control):
			with self.subTest(private_root=private_root):
				godot_user_root = private_root / "Godot" / "app_userdata" / "GF"
				self.assertLessEqual(
					len(str(godot_user_root))
					+ worker.WINDOWS_GUT_USER_PATH_RESERVE_CHARACTERS,
					worker.WINDOWS_LEGACY_MAX_PATH_CHARACTERS,
				)
		legacy_private_root = (
			workspace_s0.parent / (".gf-gut-shard-" + "a" * 64)
		)
		legacy_godot_user_root = (
			legacy_private_root / "appdata" / "Godot" / "app_userdata" / "GF"
		)
		self.assertGreater(
			len(str(legacy_godot_user_root))
			+ worker.WINDOWS_GUT_USER_PATH_RESERVE_CHARACTERS,
			worker.WINDOWS_LEGACY_MAX_PATH_CHARACTERS,
		)

	def test_private_environment_fallback_collision_retains_unowned_sentinel(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			workspace = parent / "workspace"
			workspace.mkdir()
			first_nonce = "a" * 64
			second_nonce = "a" * 16 + "b" * 48
			first_root = worker._private_environment_root_path(workspace, first_nonce)  # noqa: SLF001
			second_root = worker._private_environment_root_path(workspace, second_nonce)  # noqa: SLF001
			self.assertEqual(first_root, second_root)
			first_root.mkdir()
			marker = first_root / "unowned.txt"
			marker.write_text("retain", encoding="utf-8")
			with self.assertRaises(FileExistsError):
				worker._private_environment(  # noqa: SLF001
					workspace,
					second_root,
					observation_nonce=second_nonce,
				)
			self.assertEqual(marker.read_text(encoding="utf-8"), "retain")

	def test_private_environment_replaces_ambient_observation_binding(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			workspace = parent / "workspace"
			workspace.mkdir()
			private_root = parent / "private-root"
			nonce = "b" * 64
			with mock.patch.dict(
				os.environ,
				{
					worker.OBSERVATION_NONCE_ENVIRONMENT: "ambient-nonce",
					worker.OBSERVATION_PATH_ENVIRONMENT: "res://ambient.json",
				},
				clear=False,
			):
				environment = worker._private_environment(  # noqa: SLF001
					workspace,
					private_root,
					observation_nonce=nonce,
				)
			self.assertEqual(
				environment[worker.OBSERVATION_NONCE_ENVIRONMENT],
				nonce,
			)
			self.assertEqual(
				environment[worker.OBSERVATION_PATH_ENVIRONMENT],
				(
					"res://build/gut-sharding/"
					f"{nonce}/gut-authoritative-provenance.json"
				),
			)
			self.assertEqual(
				worker._remove_private_environment_root(  # noqa: SLF001
					private_root,
					private_root.lstat(),
				),
				"",
			)

	def test_private_environment_partial_construction_rolls_back(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			workspace = parent / "workspace"
			workspace.mkdir()
			private_root = parent / "partial-private-root"
			original_validator = worker._validate_real_directory  # noqa: SLF001
			def reject_child(path: Path, label: str) -> Path:
				if label == "platform isolation directory":
					raise OSError("synthetic partial construction failure")
				return original_validator(path, label)
			with (
				mock.patch.object(worker, "_validate_real_directory", side_effect=reject_child),
				self.assertRaisesRegex(OSError, "partial construction"),
			):
				worker._private_environment(  # noqa: SLF001
					workspace,
					private_root,
					observation_nonce="a" * 64,
				)
			self.assertFalse(private_root.exists())

	def test_private_environment_root_validation_failure_rolls_back(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			workspace = parent / "workspace"
			workspace.mkdir()
			private_root = parent / "invalid-private-root"
			original_validator = worker._validate_real_directory  # noqa: SLF001
			def reject_root(path: Path, label: str) -> Path:
				if label == "platform isolation root":
					raise OSError("synthetic root validation failure")
				return original_validator(path, label)
			with (
				mock.patch.object(worker, "_validate_real_directory", side_effect=reject_root),
				self.assertRaisesRegex(OSError, "root validation"),
			):
				worker._private_environment(  # noqa: SLF001
					workspace,
					private_root,
					observation_nonce="a" * 64,
				)
			self.assertFalse(private_root.exists())

	def test_preset_cancellation_returns_closed_report_without_process(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			request = self._request(Path(temporary_directory))
			cancellation_event = threading.Event()
			cancellation_event.set()
			process_runner = mock.Mock(side_effect=AssertionError("runner must not start"))
			report = worker.run_worker(
				request,
				process_runner=process_runner,
				result_adapter=self._authority_adapter,
				cancellation_event=cancellation_event,
				expected_workspace_identity=self._identity(Path(temporary_directory)),
			)
			self.assertFalse(report["ok"])
			self.assertEqual(report["import_run_count"], 0)
			self.assertEqual(report["gut_run_count"], 0)
			self.assertTrue(report["process_boundary_quiescent"])
			self.assertEqual([issue["kind"] for issue in report["issues"]], ["worker_cancelled"])
			process_runner.assert_not_called()
			worker.validate_report(report)

	def test_inflight_cancellation_is_forwarded_and_stops_after_clean_reap(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			cancellation_event = threading.Event()
			calls = 0
			def process_runner(_command: list[str], **kwargs: object) -> SupervisedProcessResult:
				nonlocal calls
				calls += 1
				self.assertIs(kwargs["cancellation_event"], cancellation_event)
				cancellation_event.set()
				return self._process_result(return_code=130, cancelled=True)
			with (
				mock.patch.object(worker, "_validate_workspace_binding", return_value=root.lstat()),
				mock.patch.object(worker, "_validate_shard_binding"),
			):
				report = worker.run_worker(
					request,
					process_runner=process_runner,
					result_adapter=self._authority_adapter,
					cancellation_event=cancellation_event,
					expected_workspace_identity=self._identity(root),
				)
			self.assertEqual(calls, 1)
			self.assertEqual(report["import_run_count"], 1)
			self.assertEqual(report["gut_run_count"], 0)
			self.assertTrue(report["import_result"]["cancelled"])
			self.assertTrue(report["process_boundary_quiescent"])
			self.assertEqual([issue["kind"] for issue in report["issues"]], ["worker_cancelled"])
			worker.validate_report(report)

	def test_runner_exception_records_attempt_and_unknown_cleanup_state(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			private_root = worker._private_environment_root_path(root, request["nonce"])  # noqa: SLF001
			with (
				mock.patch.object(worker, "_validate_workspace_binding", return_value=root.lstat()),
				mock.patch.object(worker, "_validate_shard_binding"),
			):
				report = worker.run_worker(
					request,
					process_runner=mock.Mock(side_effect=LookupError("synthetic runner failure")),
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
			self.assertEqual(report["import_run_count"], 1)
			self.assertEqual(report["gut_run_count"], 0)
			self.assertFalse(report["process_boundary_quiescent"])
			self.assertFalse(report["worker_cleanup_complete"])
			self.assertTrue(any(issue["phase"] == "cleanup" for issue in report["issues"]))
			self.assertEqual(report["issues"][0]["kind"], "worker_execution_failed")
			worker.validate_report(report)
			self.assertEqual(
				worker._remove_private_environment_root(private_root, private_root.lstat()),  # noqa: SLF001
				"",
			)

	def test_unproven_process_boundary_retains_private_environment(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			private_root = worker._private_environment_root_path(root, request["nonce"])  # noqa: SLF001
			with (
				mock.patch.object(worker, "_validate_workspace_binding", return_value=root.lstat()),
				mock.patch.object(worker, "_validate_shard_binding"),
			):
				report = worker.run_worker(
					request,
					process_runner=lambda *_args, **_kwargs: self._process_result(
						return_code=1,
						process_boundary_quiescent=False,
					),
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
			self.assertFalse(report["process_boundary_quiescent"])
			self.assertFalse(report["worker_cleanup_complete"])
			self.assertTrue(private_root.is_dir())
			self.assertIn(
				"worker_private_environment_retained",
				{issue["kind"] for issue in report["issues"]},
			)
			worker.validate_report(report)
			self.assertEqual(
				worker._remove_private_environment_root(private_root, private_root.lstat()),  # noqa: SLF001
				"",
			)

	def test_private_environment_cleanup_failure_is_structured_and_ineligible(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			private_root = worker._private_environment_root_path(root, request["nonce"])  # noqa: SLF001
			original_cleanup = worker._remove_private_environment_root  # noqa: SLF001
			with (
				mock.patch.object(worker, "_validate_workspace_binding", return_value=root.lstat()),
				mock.patch.object(worker, "_validate_shard_binding"),
				mock.patch.object(
					worker,
					"_remove_private_environment_root",
					return_value="synthetic identity drift",
				),
			):
				report = worker.run_worker(
					request,
					process_runner=lambda *_args, **_kwargs: self._process_result(return_code=1),
					result_adapter=self._authority_adapter,
					expected_workspace_identity=self._identity(root),
				)
			self.assertTrue(report["process_boundary_quiescent"])
			self.assertFalse(report["worker_cleanup_complete"])
			self.assertTrue(private_root.is_dir())
			self.assertIn(
				"worker_private_environment_cleanup_failed",
				{issue["kind"] for issue in report["issues"]},
			)
			worker.validate_report(report)
			self.assertEqual(original_cleanup(private_root, private_root.lstat()), "")

	def test_workspace_publication_identity_is_not_reacquired_after_fingerprint_replacement(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			parent = Path(temporary_directory)
			workspace = parent / "workspace"
			workspace.mkdir()
			(workspace / "same.txt").write_text("same", encoding="utf-8")
			published_identity = self._identity(workspace)
			replaced = parent / "replaced-workspace"
			def replace_during_fingerprint(
				_path: Path,
				*,
				deadline: float,
			) -> dict[str, str]:
				self.assertGreater(deadline, 0.0)
				workspace.rename(replaced)
				workspace.mkdir()
				(workspace / "same.txt").write_text("same", encoding="utf-8")
				return {"fingerprint": "1" * 64}
			with (
				mock.patch(
					"gf_maintenance_check_graph.workspace_fingerprint",
					side_effect=replace_during_fingerprint,
				),
				self.assertRaisesRegex(
					worker.GutShardWorkerError,
					"worker_workspace_replaced",
				),
			):
				worker._validate_workspace_binding(  # noqa: SLF001
					workspace,
					"1" * 64,
					published_identity,
					deadline=10**12,
				)
			self.assertNotEqual(self._identity(workspace), published_identity)

	def test_log_root_replacement_is_structured_as_ownership_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			request = self._request(root)
			private_root = worker._private_environment_root_path(root, request["nonce"])  # noqa: SLF001
			def replace_log_root(
				command: list[str],
				**_kwargs: object,
			) -> SupervisedProcessResult:
				log_path = Path(command[command.index("--log-file") + 1])
				log_root = log_path.parent
				log_root.rename(log_root.with_name("replaced-godot-logs"))
				log_root.mkdir()
				return self._process_result()
			with (
				mock.patch.object(worker, "_validate_workspace_binding"),
				mock.patch.object(worker, "_validate_shard_binding"),
			):
				report = worker.run_worker(
					request,
					process_runner=replace_log_root,
					result_adapter=None,
					expected_workspace_identity=self._identity(root),
				)
			self.assertFalse(report["workspace_cleanup_permitted"])
			self.assertFalse(report["continuation_safe"])
			self.assertIn(
				"worker_log_root_replaced",
				{issue["kind"] for issue in report["issues"]},
			)
			worker.validate_report(report)
			self.assertEqual(
				worker._remove_private_environment_root(  # noqa: SLF001
					private_root,
					private_root.lstat(),
				),
				"",
			)

	def test_authority_evaluator_reads_required_log_and_fails_closed(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			log_path = root / "phase.log"
			command = ("godot", "--log-file", str(log_path))
			def process_runner(_command: list[str], **_kwargs: object) -> SupervisedProcessResult:
				log_path.write_text("SCRIPT ERROR: fixture\n", encoding="utf-8")
				return self._process_result()
			_result, phase, _lifecycle = worker._run_authoritative_phase(  # noqa: SLF001
				"godot_import",
				command,
				workspace=ROOT,
				timeout_seconds=10.0,
				environment={},
				process_runner=process_runner,
				result_adapter=None,
				owned_log_root=root,
				expected_workspace_identity=self._identity(ROOT),
				expected_log_chain=((root, self._identity(root)),),
				expected_log_root_identity=self._identity(root),
			)
			self.assertFalse(phase["ok"])
			self.assertEqual(phase["exit_code"], 1)

	def test_authority_evaluator_missing_log_is_structured_infrastructure_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			with self.assertRaisesRegex(
				worker.GutShardWorkerError,
				"worker_phase_evidence_invalid",
			):
				worker._run_authoritative_phase(  # noqa: SLF001
					"godot_import",
					("godot", "--log-file", str(root / "missing.log")),
					workspace=ROOT,
					timeout_seconds=10.0,
					environment={},
					process_runner=lambda *_args, **_kwargs: self._process_result(),
					result_adapter=None,
					owned_log_root=root,
					expected_workspace_identity=self._identity(ROOT),
					expected_log_chain=((root, self._identity(root)),),
					expected_log_root_identity=self._identity(root),
				)

	def test_authority_evaluator_rejects_import_exit_cleanup_debt(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			log_path = root / "phase.log"
			command = ("godot", "--log-file", str(log_path))
			def process_runner(_command: list[str], **_kwargs: object) -> SupervisedProcessResult:
				log_path.write_text(
					"WARNING: ObjectDB instances leaked at exit (run with --verbose for details).\n",
					encoding="utf-8",
				)
				return self._process_result()
			_result, phase, _lifecycle = worker._run_authoritative_phase(  # noqa: SLF001
				"godot_import",
				command,
				workspace=ROOT,
				timeout_seconds=10.0,
				environment={},
				process_runner=process_runner,
				result_adapter=None,
				owned_log_root=root,
				expected_workspace_identity=self._identity(ROOT),
				expected_log_chain=((root, self._identity(root)),),
				expected_log_root_identity=self._identity(root),
			)
			self.assertFalse(phase["ok"])

	def test_unproven_process_boundary_reads_no_log_or_lifecycle_evidence(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			adapter = mock.Mock(side_effect=AssertionError("authority adapter must not inspect evidence"))
			with mock.patch.object(
				worker,
				"_read_stable_regular_file",
				side_effect=AssertionError("log evidence must not be read"),
			) as log_reader, mock.patch.object(
				worker,
				"_parse_lifecycle_for_test",
				side_effect=AssertionError("lifecycle evidence must not be read"),
			) as lifecycle_reader:
				_result, phase, lifecycle = worker._run_authoritative_phase(  # noqa: SLF001
					"gut",
					("godot", "--log-file", str(root / "phase.log")),
					workspace=ROOT,
					timeout_seconds=10.0,
					environment={},
					process_runner=lambda *_args, **_kwargs: self._process_result(
						process_boundary_quiescent=False,
					),
					result_adapter=adapter,
					owned_log_root=root,
					expected_workspace_identity=self._identity(ROOT),
					expected_log_chain=((root, self._identity(root)),),
					expected_log_root_identity=self._identity(root),
				)
		self.assertFalse(phase["ok"])
		self.assertEqual(phase["exit_code"], 1)
		self.assertIsNone(lifecycle)
		adapter.assert_not_called()
		log_reader.assert_not_called()
		lifecycle_reader.assert_not_called()

	def test_success_report_rejects_every_nonpassing_strict_junit_status(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			request = worker.validate_request(self._request(Path(temporary_directory)))
			for status in ("failed", "pending", "no_asserts", "skipped"):
				with self.subTest(status=status):
					junit = self._strict_junit(status)
					worker.gf_gut_sharding._validate_observation_junit_report(junit)  # noqa: SLF001
					report = worker._empty_report(request)  # noqa: SLF001
					report.update({
						"ok": True,
						"import_run_count": 1,
						"gut_run_count": 1,
						"import_result": self._successful_phase(),
						"gut_result": self._successful_phase(),
						"junit": junit,
						"junit_digest": worker.canonical_digest(junit),
						"lifecycle_ok": True,
						"duration_seconds": 0.02,
					})
					with self.assertRaisesRegex(
						worker.GutShardWorkerError,
						"worker_report_junit_failed",
					):
						worker.validate_report(report)

	def test_report_validator_rejects_forged_counts_policy_and_digest(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			request = worker.validate_request(
				self._request(Path(temporary_directory))
			)
			for mutate in (
				lambda report: report.update(selection_count=3),
				lambda report: report["observation_policy"].update(reuse_count=True),
				lambda report: report.update(junit_digest="0" * 64),
			):
				report = worker._empty_report(request)  # noqa: SLF001
				report["issues"].append({
					"kind": "fixture",
					"message": "fixture",
					"phase": "fixture",
				})
				mutate(report)
				with self.assertRaises(worker.GutShardWorkerError):
					worker.validate_report_shape(report)

	def test_report_validator_recomputes_continuation_safe_from_closed_evidence(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			request = worker.validate_request(self._request(Path(temporary_directory)))
			valid = worker._empty_report(request)  # noqa: SLF001
			valid.update({
				"import_run_count": 1,
				"import_result": worker._failed_attempt_phase(),  # noqa: SLF001
				"workspace_cleanup_permitted": True,
				"continuation_safe": True,
				"duration_seconds": 0.01,
			})
			valid["issues"].append({
				"kind": "worker_import_failed",
				"message": "fixture",
				"phase": "import",
			})
			worker.validate_report(valid)
			for mutate in (
				lambda report: report["issues"][0].update(kind="worker_execution_failed"),
				lambda report: report["issues"][0].update(phase="worker"),
				lambda report: report.update(workspace_cleanup_permitted=False),
				lambda report: report.update(process_boundary_quiescent=False),
				lambda report: report.update(worker_cleanup_complete=False),
				lambda report: report["import_result"].update(timed_out=True),
			):
				forged = worker.validate_report(valid)
				mutate(forged)
				if forged["worker_cleanup_complete"] is False:
					forged["issues"].append({
						"kind": "worker_private_environment_cleanup_failed",
						"message": "fixture",
						"phase": "cleanup",
					})
				with self.assertRaises(worker.GutShardWorkerError):
					worker.validate_report(forged)

			forged_import_junit = worker.validate_report(valid)
			forged_import_junit["junit"] = self._strict_junit("passed")
			forged_import_junit["junit_digest"] = worker.canonical_digest(
				forged_import_junit["junit"]
			)
			with self.assertRaisesRegex(
				worker.GutShardWorkerError,
				"completed, quiescent GUT execution",
			):
				worker.validate_report(forged_import_junit)

			lifecycle_only_failure = worker._empty_report(request)  # noqa: SLF001
			lifecycle_only_failure.update({
				"import_run_count": 1,
				"gut_run_count": 1,
				"import_result": self._successful_phase(),
				"gut_result": self._successful_phase(),
				"workspace_cleanup_permitted": True,
				"duration_seconds": 0.02,
			})
			lifecycle_only_failure["issues"].append({
				"kind": "worker_gut_failed",
				"message": "fixture",
				"phase": "gut",
			})
			worker.validate_report(lifecycle_only_failure)
			lifecycle_only_failure["continuation_safe"] = True
			with self.assertRaisesRegex(
				worker.GutShardWorkerError,
				"worker_report_status_invalid",
			):
				worker.validate_report(lifecycle_only_failure)

	def test_validate_report_returns_deeply_detached_normalized_mapping(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			request = worker.validate_request(self._request(Path(temporary_directory)))
			report = worker._empty_report(request)  # noqa: SLF001
			report["issues"].append({"kind": "fixture", "message": "fixture", "phase": "fixture"})
			detached = worker.validate_report(report)
			self.assertEqual(detached, report)
			self.assertIsNot(detached, report)
			self.assertIsNot(detached["request"], report["request"])
			self.assertIsNot(detached["issues"], report["issues"])
			detached["request"]["scripts"].append(self.SCRIPT_B)
			detached["issues"][0]["kind"] = "mutated"
			self.assertEqual(report["request"]["scripts"], [self.SCRIPT_A, self.SCRIPT_B])
			self.assertEqual(report["issues"][0]["kind"], "fixture")

	def test_report_validation_is_pure_after_private_workspace_cleanup(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory) / "workspace"
			workspace.mkdir()
			request = worker.validate_request(self._request(workspace))
			report = worker._empty_report(request)  # noqa: SLF001
			report["issues"].append({"kind": "fixture", "message": "fixture", "phase": "fixture"})
			workspace.rmdir()
			detached = worker.validate_report(report)
			self.assertEqual(detached, report)

	def test_run_worker_requires_live_workspace_after_protocol_validation(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			workspace = Path(temporary_directory) / "workspace"
			workspace.mkdir()
			request = worker.validate_request(self._request(workspace))
			workspace_identity = self._identity(workspace)
			workspace.rmdir()
			report = worker.run_worker(
				request,
				process_runner=mock.Mock(side_effect=AssertionError("runner must not start")),
				result_adapter=self._authority_adapter,
				expected_workspace_identity=workspace_identity,
			)
		self.assertFalse(report["ok"])
		self.assertEqual(report["import_run_count"], 0)
		self.assertEqual(report["gut_run_count"], 0)
		self.assertEqual(report["issues"][0]["kind"], "worker_path_invalid")

	def test_report_validator_rejects_nonexact_schema_embedded_request_and_size(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			request = worker.validate_request(self._request(Path(temporary_directory)))
			report = worker._empty_report(request)  # noqa: SLF001
			report["issues"].append({"kind": "fixture", "message": "fixture", "phase": "fixture"})
			with self.assertRaisesRegex(worker.GutShardWorkerError, "schema_invalid"):
				worker.validate_report({**report, "schema_version": True})
			forged = {**report, "request": {**request, "schema_version": True}}
			with self.assertRaisesRegex(worker.GutShardWorkerError, "schema_invalid"):
				worker.validate_report(forged)
			with (
				mock.patch.object(worker, "MAX_REPORT_BYTES", 1),
				self.assertRaisesRegex(worker.GutShardWorkerError, "report_too_large"),
			):
				worker.validate_report(report)

	def test_process_cleanup_uses_explicit_supervisor_evidence_only(self) -> None:
		clean = self._process_result()
		self.assertTrue(worker._process_boundary_quiescent(clean))  # noqa: SLF001
		self.assertFalse(worker._process_boundary_quiescent(replace(clean, process_boundary_quiescent=False)))  # noqa: SLF001
		self.assertTrue(worker._process_boundary_quiescent(replace(clean, notes=("arbitrary observation",))))  # noqa: SLF001
		self.assertTrue(worker._process_boundary_quiescent(replace(clean, stdout_truncated=True)))  # noqa: SLF001

	SCRIPT_A = "res://tests/gf_core/a/test_a.gd"
	SCRIPT_B = "res://tests/gf_core/b/test_b.gd"

	@staticmethod
	def _environment(kwargs: dict[str, object]) -> dict[str, str]:
		environment = kwargs.get("environment")
		if type(environment) is not dict or any(
			type(key) is not str or type(value) is not str
			for key, value in environment.items()
		):
			raise AssertionError("worker did not pass one string environment mapping")
		return environment

	@classmethod
	def _publish_observation_pair(
		cls,
		workspace: Path,
		command: list[str],
		environment: dict[str, str],
		scripts_value: object,
		nonce: str,
		*,
		first_status: str = "pass",
	) -> None:
		if first_status not in {"pass", "fail"}:
			raise AssertionError("fixture status is invalid")
		if type(scripts_value) is not list or any(
			type(script) is not str for script in scripts_value
		):
			raise AssertionError("fixture scripts are invalid")
		scripts = tuple(scripts_value)
		junit_arguments = [
			argument.split("=", 1)[1]
			for argument in command
			if argument.startswith("-gjunit_xml_file=")
		]
		if len(junit_arguments) != 1:
			raise AssertionError("worker did not own exactly one JUnit output")
		invocation_root = workspace / "build" / "gut-sharding" / nonce
		junit_path = Path(junit_arguments[0])
		if junit_path != invocation_root / "gut-authoritative.xml":
			raise AssertionError("worker JUnit path is outside the producer contract")
		expected_resource_path = (
			"res://build/gut-sharding/"
			f"{nonce}/gut-authoritative-provenance.json"
		)
		if (
			environment.get(worker.OBSERVATION_NONCE_ENVIRONMENT) != nonce
			or environment.get(worker.OBSERVATION_PATH_ENVIRONMENT)
			!= expected_resource_path
		):
			raise AssertionError("worker environment is outside the producer contract")
		provenance_path = workspace / expected_resource_path.removeprefix("res://")
		if provenance_path != invocation_root / "gut-authoritative-provenance.json":
			raise AssertionError("worker provenance path is outside the producer contract")

		suites: list[str] = []
		provenance_scripts: list[dict[str, object]] = []
		for index, script in enumerate(scripts):
			short_path = script.removeprefix("res://")
			test_name = f"test_worker_fixture_{index}"
			status = first_status if index == 0 else "pass"
			failure_count = int(status == "fail")
			failure_element = (
				'<failure message="failed"><![CDATA[fixture failure]]></failure>'
				if failure_count
				else ""
			)
			suites.append(
				f'<testsuite name="{short_path}" tests="1" failures="{failure_count}" '
				'skipped="0" time="0.01">\n'
				f'<testcase name="{test_name}" assertions="1" status="{status}" '
				f'classname="{short_path}" time="0.01">{failure_element}</testcase>\n'
				"</testsuite>"
			)
			provenance_scripts.append({
				"script": script,
				"inner_class": "",
				"was_run": True,
				"was_skipped": False,
				"duration_seconds": 0.02,
				"assertion_count": 2,
				"lifecycle_assertion_count": 1,
				"tests": [{
					"name": test_name,
					"was_run": True,
					"status": status,
					"assertion_count": 1,
					"duration_seconds": 0.01,
				}],
			})
		xml = (
			'<?xml version="1.0" encoding="UTF-8"?>\n'
			f'<testsuites name="GutTests" failures="{int(first_status == "fail")}" '
			f'tests="{len(scripts)}">\n'
			+ "\n".join(suites)
			+ "\n</testsuites>"
		)
		xml_bytes = xml.encode("utf-8")
		junit_path.write_bytes(xml_bytes)
		provenance = {
			"schema_version": 1,
			"nonce": nonce,
			"junit_sha256": hashlib.sha256(xml_bytes).hexdigest(),
			"unfiltered": True,
			"script_count": len(scripts),
			"scripts": provenance_scripts,
		}
		provenance_path.write_bytes(
			(
				json.dumps(
					provenance,
					ensure_ascii=False,
					allow_nan=False,
					separators=(",", ":"),
					sort_keys=True,
				)
				+ "\n"
			).encode("utf-8")
		)

	@classmethod
	def _strict_junit(cls, first_status: str) -> dict[str, object]:
		script_reports = []
		for script_path, status in zip(
			(cls.SCRIPT_A, cls.SCRIPT_B),
			(first_status, "passed"),
			strict=True,
		):
			assertion_count = 0 if status in {"no_asserts", "skipped"} else 1
			status_counts = {
				value: int(value == status)
				for value in ("passed", "failed", "pending", "no_asserts", "skipped")
			}
			script_reports.append({
				"script": script_path,
				"duration_seconds": 0.1,
				"testcase_duration_seconds": 0.1,
				"testcase_duration_sum_seconds": 0.1,
				"testcase_duration_serialization_tolerance_seconds": 0.000002,
				"duration_scope": worker.gf_gut_sharding.JUNIT_LIFECYCLE_DURATION_SCOPE,
				"test_count": 1,
				"status_counts": status_counts,
				"failure_assertion_count": int(status == "failed"),
				"pending_assertion_count": int(status == "pending"),
				"failure_test_count_lower_bound": int(status == "failed"),
				"failure_test_count_upper_bound": int(status == "failed"),
				"assertion_count": assertion_count,
				"lifecycle_assertion_count": 0,
				"assertion_counts_complete": True,
				"assertion_count_unknown_reason": None,
				"tests": [{
					"name": "test_fixture",
					"duration_seconds": 0.1,
					"status": status,
					"assertion_count": assertion_count,
				}],
			})
		status_counts = {
			status: sum(report["status_counts"][status] for report in script_reports)
			for status in ("passed", "failed", "pending", "no_asserts", "skipped")
		}
		return {
			"schema_version": 1,
			"ok": True,
			"source_format": "gut_junit_xml",
			"junit_sha256": "a" * 64,
			"provenance_sha256": "b" * 64,
			"input_complete": True,
			"completeness_basis": worker.gf_gut_sharding.JUNIT_COMPLETENESS_CONTROLLED_RUN,
			"script_count": 2,
			"covered_script_count": 2,
			"test_count": 2,
			"duration_seconds": 0.2,
			"testcase_duration_seconds": 0.2,
			"duration_scope": worker.gf_gut_sharding.JUNIT_LIFECYCLE_DURATION_SCOPE,
			"status_counts": status_counts,
			"failure_test_count": int(first_status == "failed"),
			"failure_assertion_count": int(first_status == "failed"),
			"pending_assertion_count": int(first_status == "pending"),
			"assertion_count": sum(report["assertion_count"] for report in script_reports),
			"lifecycle_assertion_count": 0,
			"assertion_counts_complete": True,
			"assertion_count_unknown_reason": None,
			"scripts": script_reports,
		}

	@staticmethod
	def _successful_phase() -> dict[str, object]:
		return {
			"ok": True,
			"exit_code": 0,
			"timed_out": False,
			"cancelled": False,
			"duration_seconds": 0.01,
		}

	@classmethod
	def _build_argv(
		cls,
		base_command: tuple[str, ...],
		scripts: tuple[str, ...],
	) -> tuple[str, ...]:
		return worker.build_gut_shard_argv(
			base_command,
			config_path="res://.gutconfig.json",
			pre_run_script="res://tests/gf_core/support/gf_gut_pre_run_hook.gd",
			post_run_script="res://tests/gf_core/support/gf_gut_post_run_hook.gd",
			scripts=scripts,
		)

	@classmethod
	def _request(cls, workspace: Path) -> dict[str, object]:
		return {
			"schema_version": 1,
			"nonce": secrets.token_hex(32),
			"mode": worker.MODE,
			"shard_name": "gut-lane-a",
			"role": "lane",
			"scripts": [cls.SCRIPT_A, cls.SCRIPT_B],
			"workspace_path": str(workspace.resolve()),
			"workspace_fingerprint": "1" * 64,
			"runtime_source_digest": "4" * 64,
			"manifest_digest": "2" * 64,
			"inventory_digest": "3" * 64,
			"remaining_seconds": 240,
			"import_timeout_seconds": 30,
			"gut_timeout_seconds": 90,
		}

	@staticmethod
	def _process_result(
		return_code: int = 0,
		*,
		timed_out: bool = False,
		cancelled: bool = False,
		process_boundary_quiescent: bool = True,
	) -> SupervisedProcessResult:
		return SupervisedProcessResult(
			return_code=return_code,
			stdout="",
			stderr="",
			timed_out=timed_out,
			duration_seconds=0.01,
			pid=123,
			cancelled=cancelled,
			process_boundary_quiescent=process_boundary_quiescent,
		)

	@staticmethod
	def _identity(path: Path) -> tuple[int, int, int]:
		return worker._directory_identity(path.lstat())  # noqa: SLF001

	@staticmethod
	def _authority_adapter(
		_phase: str,
		result: SupervisedProcessResult,
	) -> dict[str, object]:
		return {
			"ok": result.return_code == 0 and not result.timed_out and not result.cancelled,
			"exit_code": result.return_code,
			"timed_out": result.timed_out,
			"cancelled": result.cancelled,
			"duration_seconds": result.duration_seconds,
		}


if __name__ == "__main__":
	unittest.main()
