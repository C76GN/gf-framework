from __future__ import annotations

import hashlib
import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from dataclasses import replace
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
if str(ROOT / "tools") not in sys.path:
	sys.path.insert(0, str(ROOT / "tools"))

import gf_maintenance
import gf_review_hotspot_report as reports
from gf_path_security import PinnedReadError


def binary_result(**changes: object) -> gf_maintenance.gf_process_supervisor.SupervisedBinaryProcessResult:
	return replace(
		gf_maintenance.gf_process_supervisor.SupervisedBinaryProcessResult(
			return_code=0, stdout=b"a.gd\0", stderr=b"", timed_out=False,
			duration_seconds=0.01, pid=8123, cleanup_complete=True,
		),
		**changes,
	)


class DeferredCleanupFixture:
	def __init__(self, *, completed: bool = True, pid: int = 8123) -> None:
		self.completed = completed
		self.pid = pid
		self.waited: list[float | None] = []

	def wait(self, timeout_seconds: float | None) -> bool:
		self.waited.append(timeout_seconds)
		return self.completed

	def snapshot_before_deadline(self, _deadline: float) -> object:
		return gf_maintenance.gf_process_supervisor.SupervisedBinaryCleanupStatus(
			complete=self.completed, cleanup_complete=self.completed,
			owner_closed=self.completed, process_tree_empty=self.completed, pid=self.pid,
		)


class ReviewHotspotReportTests(unittest.TestCase):
	def test_literal_scope_deduplication_ranking_and_source_digest(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "addons/gf").mkdir(parents=True)
			first = "func small():\n\tpass\n"
			second = "func larger():\n\tif true:\n\t\tfor item in []:\n\t\t\tprint(item)\n"
			(root / "addons/gf/a.gd").write_text(first, encoding="utf-8", newline="\n")
			(root / "addons/gf/b.gd").write_text(second, encoding="utf-8", newline="\n")
			result = reports.build_report(
				root, ["addons/gf/a.gd", "addons/gf/b.gd", "addons/gf2/outside.gd"],
				scopes=["addons\\gf", "addons/gf/a.gd"], limit=1,
			)
			self.assertTrue(result["ok"], result)
			self.assertTrue(result["observation_only"])
			self.assertEqual(result["selected_file_count"], 2)
			self.assertEqual(result["function_count"], 2)
			self.assertEqual(result["omitted_function_count"], 1)
			self.assertEqual(result["functions"][0]["name"], "larger")
			self.assertEqual(result["files"][0]["sha256"], hashlib.sha256(first.encode()).hexdigest())
			self.assertIn("addons/gf/b.gd:1", reports.render_text(result))
			self.assertEqual((root / "addons/gf/a.gd").read_text(), first)
			self.assertEqual(sorted(path.name for path in (root / "addons/gf").iterdir()), ["a.gd", "b.gd"])

	def test_top_limit_never_turns_high_observations_into_a_failure(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "guard.gd").write_text(
				"func guarded():\n" + "\tif true:\n\t\treturn\n" * 200,
				encoding="utf-8",
			)
			result = reports.build_report(root, ["guard.gd"], scopes=["guard.gd"])
			self.assertTrue(result["ok"], result)
			self.assertGreaterEqual(result["functions"][0]["metrics"]["branch_count"], 200)

	def test_missing_invalid_and_incomplete_source_are_not_clean_observations(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "invalid.gd").write_bytes(b"\xff")
			(root / "incomplete.gd").write_text("func broken(\n", encoding="utf-8")
			result = reports.build_report(
				root, ["missing.gd", "invalid.gd", "incomplete.gd"],
				scopes=["missing.gd", "invalid.gd", "incomplete.gd", "unmatched"],
			)
			self.assertFalse(result["ok"])
			self.assertEqual(result["status"], "incomplete")
			self.assertEqual(result["selected_file_count"], 3)
			self.assertEqual(result["scanned_file_count"], 1)
			self.assertNotEqual(result["files"][0]["status"], "complete")
			self.assertEqual(len(result["issues"]), 3)

	def test_pinned_read_drift_failure_is_preserved(self) -> None:
		with mock.patch.object(
			reports.gf_path_security, "read_pinned_regular_file",
			side_effect=PinnedReadError("path_security.file_changed"),
		):
			result = reports.build_report(Path.cwd(), ["a.gd"], scopes=["a.gd"])
		self.assertFalse(result["ok"])
		self.assertEqual(result["issues"][0]["code"], "path_security.file_changed")
		self.assertEqual(result["scanned_file_count"], 0)

	def test_report_limits_refuse_silent_partial_success(self) -> None:
		with (
			mock.patch.object(reports, "MAX_FILES", 1),
			mock.patch.object(reports.gf_path_security, "read_pinned_regular_file") as read,
		):
			result = reports.build_report(Path.cwd(), ["a/a.gd", "a/b.gd"], scopes=["a"])
		self.assertFalse(result["ok"])
		read.assert_not_called()
		with (
			mock.patch.object(reports.time, "monotonic", side_effect=[0.0, 31.0]),
			mock.patch.object(reports.gf_path_security, "read_pinned_regular_file") as read,
		):
			result = reports.build_report(Path.cwd(), ["a.gd"], scopes=["a.gd"])
		self.assertEqual(result["issues"][0]["code"], "review_hotspots.deadline")
		read.assert_not_called()

	def test_source_budget_is_enforced_before_parse(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "a.gd").write_bytes(b"x" * 65)
			with mock.patch.object(reports, "MAX_FILE_BYTES", 64):
				result = reports.build_report(root, ["a.gd"], scopes=["a.gd"])
			self.assertFalse(result["ok"])
			self.assertEqual(result["scanned_file_count"], 0)

	def test_scopes_cannot_escape_repository_or_become_git_pathspecs(self) -> None:
		for value in (".", "../outside", "/absolute", "C:\\outside", "a/../b", "a//b", "a/", ":(glob)*", "a\n"):
			with self.subTest(value=value), self.assertRaises(ValueError):
				reports.normalize_scope(value)
		self.assertEqual(reports.normalize_scope("a[b]"), "a[b]")
		self.assertEqual(reports.normalize_scope("space dir/a.gd"), "space dir/a.gd")

	def test_inventory_is_strict_and_bounded(self) -> None:
		self.assertEqual(reports.parse_inventory(b"a.gd\0b.gd\0a.gd\0"), ["a.gd", "b.gd"])
		self.assertEqual(reports.parse_inventory(b""), [])
		for payload in (b"a.gd", b"\xff\0", b"../outside\0", b"a\\b\0", b"a\0\0"):
			with self.subTest(payload=payload), self.assertRaises(ValueError):
				reports.parse_inventory(payload)
		with mock.patch.object(reports, "MAX_INVENTORY_BYTES", 3), self.assertRaises(ValueError):
			reports.parse_inventory(b"a.gd\0")

	def test_cli_inventory_rejects_truncation_stderr_and_nonzero_exit(self) -> None:
		for changes in ({"stdout_truncated": True}, {"stderr_truncated": True}, {"stderr": b"warning"}, {"return_code": 1}, {"timed_out": True}, {"output_drain_failed": True}):
			with (
				mock.patch.object(gf_maintenance.gf_process_supervisor, "run_supervised_process_bytes", return_value=binary_result(**changes)),
				mock.patch.object(reports, "build_report") as build,
			):
				report = gf_maintenance.review_hotspots.__wrapped__(paths=["a.gd"])
			self.assertFalse(report["ok"])
			build.assert_not_called()

	def test_cli_does_not_delegate_user_paths_to_git(self) -> None:
		process = binary_result(stdout=b"literal[1]/a.gd\0")
		with (
			mock.patch.object(gf_maintenance.gf_process_supervisor, "run_supervised_process_bytes", return_value=process) as git,
			mock.patch.object(reports, "build_report", return_value={"ok": True}) as build,
		):
			result = gf_maintenance.review_hotspots.__wrapped__(paths=["literal[1]"], limit=2)
		self.assertTrue(result["ok"])
		self.assertNotIn("literal[1]", git.call_args.args[0])
		self.assertEqual(git.call_args.kwargs["max_stdout_bytes"], reports.MAX_INVENTORY_BYTES)
		self.assertEqual(build.call_args.kwargs["scopes"], ["literal[1]"])

	def test_report_command_remains_outside_all_quality_check_plans(self) -> None:
		self.assertNotIn("review_hotspots", gf_maintenance.CHECK_DEFINITIONS)
		for checks in gf_maintenance.CHECK_SUITES.values():
			self.assertNotIn("review_hotspots", checks)
		self.assertIn(
			"tests/gf_core/tools/test_gf_review_hotspot_report.py",
			gf_maintenance.CHECK_DEFINITIONS["maintenance_generator_tests"],
		)

	def test_cli_json_round_trip_and_coverage_exit_status(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "selected.gd").write_text("func selected():\n\tpass\n", encoding="utf-8")
			process = binary_result(stdout=b"selected.gd\0")
			for scope, expected_code in (("selected.gd", 0), ("missing.gd", 1)):
				output = io.StringIO()
				with (
					mock.patch.object(gf_maintenance, "ROOT", root),
					mock.patch.object(gf_maintenance.gf_process_supervisor, "run_supervised_process_bytes", return_value=process),
					mock.patch.object(sys, "argv", ["gf_maintenance.py", "review-hotspots", "--path", scope, "--limit", "1", "--json"]),
					contextlib.redirect_stdout(output),
				):
					self.assertEqual(gf_maintenance.main(), expected_code)
				data = json.loads(output.getvalue())
				self.assertEqual(data["ok"], expected_code == 0)
				self.assertEqual(data["scopes"], [scope])
				self.assertIn("metric_definitions", data)

	def test_cli_observes_deferred_cleanup_under_the_original_deadline(self) -> None:
		supervisor = gf_maintenance.gf_process_supervisor
		operation = DeferredCleanupFixture()
		handle = supervisor.SupervisedBinaryCleanupHandle(operation)
		process = binary_result(cleanup_complete=False, deferred_cleanup=handle)
		with (
			mock.patch.object(supervisor, "run_supervised_process_bytes", return_value=process) as run,
			mock.patch.object(supervisor, "require_supervised_binary_quiet_boundary", wraps=supervisor.require_supervised_binary_quiet_boundary) as quiet,
			mock.patch.object(reports, "build_report", return_value={"ok": True}),
		):
			self.assertTrue(gf_maintenance.review_hotspots.__wrapped__(paths=["a.gd"])["ok"])
		self.assertEqual(run.call_args.kwargs["deadline"], quiet.call_args.kwargs["deadline"])
		self.assertEqual(len(operation.waited), 1)
		self.assertGreaterEqual(operation.waited[0], 0.0)
		self.assertLessEqual(operation.waited[0], 30.0)

	def test_cli_preserves_cleanup_debt_and_rejects_pid_mismatch(self) -> None:
		supervisor = gf_maintenance.gf_process_supervisor
		for operation in (DeferredCleanupFixture(completed=False), DeferredCleanupFixture(pid=9999)):
			handle = supervisor.SupervisedBinaryCleanupHandle(operation)
			with (
				mock.patch.object(supervisor, "run_supervised_process_bytes", return_value=binary_result(cleanup_complete=False, deferred_cleanup=handle)),
				mock.patch.object(reports, "build_report") as build,
				self.assertRaises(supervisor.SupervisedProcessCleanupError) as raised,
			):
				gf_maintenance.review_hotspots.__wrapped__(paths=["a.gd"])
			self.assertIs(raised.exception.deferred_cleanup, handle)
			self.assertTrue(supervisor.exception_has_cleanup_debt(raised.exception))
			build.assert_not_called()

	def test_cli_does_not_swallow_cleanup_exception_from_spawn(self) -> None:
		supervisor = gf_maintenance.gf_process_supervisor
		error = supervisor.SupervisedProcessCleanupError("owned process cleanup failed")
		with (
			mock.patch.object(supervisor, "run_supervised_process_bytes", side_effect=error),
			self.assertRaises(supervisor.SupervisedProcessCleanupError) as raised,
		):
			gf_maintenance.review_hotspots.__wrapped__(paths=["a.gd"])
		self.assertIs(raised.exception, error)


if __name__ == "__main__":
	unittest.main()
