"""No-engine checks for benchmark ownership and measurement boundaries."""

from __future__ import annotations

import contextlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import gf_reactive_benchmark as benchmark


class ReactiveBenchmarkBoundaryTests(unittest.TestCase):
	def test_cleanup_requires_exact_created_directory_and_receipt(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-reactive-boundary-") as directory:
			parent = Path(directory).resolve()
			stage = parent / "owned"
			stage.mkdir()
			receipt = b"a" * 32
			(stage / "owner.receipt").write_bytes(receipt)
			metadata = stage.stat()
			identity = (metadata.st_dev, metadata.st_ino)
			self.assertTrue(benchmark._cleanup_allowed(stage, parent, receipt, identity))
			self.assertFalse(benchmark._cleanup_allowed(stage, parent.parent, receipt, identity))
			(stage / "owner.receipt").write_bytes(b"b" * 32)
			self.assertFalse(benchmark._cleanup_allowed(stage, parent, receipt, identity))
			(stage / "owner.receipt").unlink()
			self.assertFalse(benchmark._cleanup_allowed(stage, parent, receipt, identity))
			stage.rename(parent / "previous")
			stage.mkdir()
			(stage / "owner.receipt").write_bytes(receipt)
			self.assertFalse(benchmark._cleanup_allowed(stage, parent, receipt, identity))

	def test_output_refuses_other_artifacts_and_reparse_components(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-reactive-output-") as directory:
			root = Path(directory).resolve()
			output = root / "report.json"
			with mock.patch.object(benchmark, "ROOT", root):
				output.write_text('{"kind":"game_save"}', encoding="utf-8")
				with self.assertRaisesRegex(ValueError, "different artifact"):
					benchmark._validate_output(output)
				output.write_text(json.dumps({"kind": benchmark.REPORT_KIND, "schema_version": 1}), encoding="utf-8")
				self.assertEqual(benchmark._validate_output(output), output)
				with mock.patch.object(benchmark, "_is_linked", side_effect=lambda path: path == root):
					with self.assertRaisesRegex(ValueError, "linked or reparsed"):
						benchmark._validate_output(output)
				with self.assertRaisesRegex(ValueError, "inside this repository"):
					benchmark._validate_output(root.parent / "outside.json")

	def test_write_rechecks_output_ownership_instead_of_overwriting_new_data(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-reactive-rewrite-") as directory:
			root = Path(directory).resolve()
			output = root / "report.json"
			with mock.patch.object(benchmark, "ROOT", root):
				benchmark._write_report(output, {"kind": benchmark.REPORT_KIND, "schema_version": 1})
				output.write_text('{"business":true}', encoding="utf-8")
				with self.assertRaisesRegex(ValueError, "different artifact"):
					benchmark._write_report(output, {"kind": benchmark.REPORT_KIND, "schema_version": 1})
				self.assertEqual(output.read_text(encoding="utf-8"), '{"business":true}')

	def test_missing_direct_process_cpu_is_unavailable_not_elapsed_or_zero(self) -> None:
		with mock.patch.object(benchmark.os, "name", "posix"):
			accounting = benchmark._ProcessCPU()
			accounting.start(123)
			result = accounting.finish()
		self.assertFalse(result["available"])
		self.assertIsNone(result["seconds"])
		self.assertIn("unavailable", result["unavailable_reason"])

	def test_invalid_global_deadline_starts_no_process(self) -> None:
		for value in ("nan", "inf", "0", "601"):
			with (
				self.subTest(value=value),
				mock.patch.object(sys, "argv", ["benchmark", "--godot", "unused", "--deadline-seconds", value]),
				mock.patch.object(benchmark, "run_benchmark") as run,
				contextlib.redirect_stderr(io.StringIO()),
			):
				with self.assertRaises(SystemExit) as raised:
					benchmark.main()
				self.assertEqual(raised.exception.code, 2)
				run.assert_not_called()

	def test_workload_checksum_mismatch_is_not_a_valid_performance_comparison(self) -> None:
		runs = []
		for workload in benchmark.WORKLOADS:
			for mode in benchmark.MODES:
				runs.append({"workload": workload, "mode": mode, "samples": [{"checksum": 1}]})
		runs[1]["samples"][0]["checksum"] = 2
		with self.assertRaisesRegex(ValueError, "not equivalent"):
			benchmark._summarize(runs)


if __name__ == "__main__":
	unittest.main(verbosity=2)
