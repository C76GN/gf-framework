"""No-engine checks for benchmark ownership and measurement boundaries."""

from __future__ import annotations

import argparse
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
from gf_process_supervisor import (
	SupervisedProcessCleanupError,
	SupervisedProcessResult,
	SupervisedProcessStartError,
	run_supervised_process,
)


class ReactiveBenchmarkBoundaryTests(unittest.TestCase):
	@contextlib.contextmanager
	def _private_run(self):
		"""Use real private staging files and a fake executable fixture, without Godot."""
		with tempfile.TemporaryDirectory(prefix="gf-reactive-failure-") as directory:
			root = Path(directory).resolve() / "workspace"
			fixture = root / "tests/gf_core/benchmarks/reactive"
			fixture.mkdir(parents=True)
			(fixture / "project.godot.fixture").write_text("synthetic project", encoding="utf-8")
			(fixture / "reactive_pull_benchmark.gd").write_text("synthetic fixture", encoding="utf-8")
			kernel = root / "addons/gf/kernel/core"
			kernel.mkdir(parents=True)
			for name in benchmark.KERNEL_FILES:
				(kernel / name).write_text("synthetic kernel", encoding="utf-8")
			runner = root / "tools/gf_reactive_benchmark.py"
			runner.parent.mkdir()
			runner.write_text("synthetic runner identity", encoding="utf-8")
			parent = Path(directory).resolve() / "sandboxes"
			parent.mkdir()
			neighbor = parent / "unrelated"
			neighbor.mkdir()
			(neighbor / "sentinel").write_bytes(b"keep unrelated data")
			args = argparse.Namespace(
				godot=Path(sys.executable), output=root / "build/report.json",
				temp_parent=parent, deadline_seconds=10.0, correctness_only=True,
				keep_sandbox=False,
			)
			stages = []
			create_stage = tempfile.mkdtemp

			def capture_stage(*arguments, **keywords):
				stage = Path(create_stage(*arguments, **keywords)).resolve()
				stages.append(stage)
				return str(stage)

			cpu = mock.Mock()
			cpu.finish.return_value = {"available": False, "seconds": None, "method": "unavailable", "unavailable_reason": "synthetic accounting"}
			with (
				mock.patch.object(benchmark, "ROOT", root),
				mock.patch.object(benchmark, "FIXTURE", fixture),
				mock.patch.object(benchmark, "__file__", str(runner)),
				mock.patch.object(benchmark.tempfile, "mkdtemp", side_effect=capture_stage),
				mock.patch.object(benchmark, "_ProcessCPU", return_value=cpu),
				contextlib.redirect_stdout(io.StringIO()),
			):
				yield args, stages, neighbor, cpu

	def _quiet_result(self, command, **_keywords):
		project = Path(command[command.index("--path") + 1])
		stdout = ""
		if "--script" in command:
			stdout = "GF_REACTIVE_RESULT=" + json.dumps({"ok": True, "user_data_dir": str(project.parent / "profile")})
		return SupervisedProcessResult(
			return_code=0, stdout=stdout, stderr="", timed_out=False,
			duration_seconds=0.01, pid=123, process_boundary_quiescent=True,
		)

	def test_setup_failures_clean_owned_stage_and_preserve_original_error(self) -> None:
		for phase in ("closure_mkdir", "kernel_write", "project_copy", "fixture_copy", "environment_mkdir", "log_mkdir"):
			with self.subTest(phase=phase), self._private_run() as (args, stages, neighbor, _cpu):
				primary = OSError(f"synthetic {phase} failure")
				original_mkdir = Path.mkdir
				original_write = Path.write_bytes
				original_copy = benchmark.shutil.copyfile
				observed_receipts = []

				def fail_with_receipt():
					owner = stages[0] / "owner.receipt"
					observed_receipts.append(owner.read_bytes() if owner.exists() else None)
					raise primary

				def mkdir(path, *arguments, **keywords):
					if ((phase == "closure_mkdir" and path.name == "core")
						or (phase == "environment_mkdir" and path.name == "profile")
						or (phase == "log_mkdir" and path.parent.name == "reactive_benchmark")):
						fail_with_receipt()
					return original_mkdir(path, *arguments, **keywords)

				def write(path, data):
					if phase == "kernel_write" and path.parent.name == "core":
						fail_with_receipt()
					return original_write(path, data)

				def copy(source, destination, *arguments, **keywords):
					if ((phase == "project_copy" and Path(destination).name == "project.godot")
						or (phase == "fixture_copy" and Path(destination).name == "benchmark.gd")):
						fail_with_receipt()
					return original_copy(source, destination, *arguments, **keywords)

				with (
					mock.patch.object(Path, "mkdir", mkdir),
					mock.patch.object(Path, "write_bytes", write),
					mock.patch.object(benchmark.shutil, "copyfile", side_effect=copy),
					mock.patch.object(benchmark, "run_supervised_process") as process,
				):
					with self.assertRaises(OSError) as raised:
						benchmark.run_benchmark(args)
				self.assertIs(raised.exception, primary)
				process.assert_not_called()
				self.assertEqual(len(stages), 1)
				self.assertFalse(stages[0].exists())
				self.assertEqual([len(value) if value is not None else None for value in observed_receipts], [32])
				self.assertEqual((neighbor / "sentinel").read_bytes(), b"keep unrelated data")
				report = json.loads(args.output.read_text(encoding="utf-8"))
				self.assertFalse(report["valid"])
				self.assertEqual(report["error"], str(primary))

	def test_unproven_supervisor_error_preserves_identity_and_retains_sandbox(self) -> None:
		with self._private_run() as (args, stages, neighbor, cpu):
			primary = OSError("synthetic unproven supervision error")
			with mock.patch.object(benchmark, "run_supervised_process", side_effect=primary):
				with self.assertRaises(OSError) as raised:
					benchmark.run_benchmark(args)
			self.assertIs(raised.exception, primary)
			cpu.finish.assert_called_once()
			self.assertTrue(stages[0].exists())
			self.assertEqual((neighbor / "sentinel").read_bytes(), b"keep unrelated data")
			self.assertIn("retained", json.loads(args.output.read_text(encoding="utf-8"))["sandbox_cleanup"])

	def test_proven_no_child_start_error_cleans_owned_sandbox(self) -> None:
		with self._private_run() as (args, stages, neighbor, _cpu):
			primary = SupervisedProcessStartError(FileNotFoundError("synthetic executable disappeared"))
			with mock.patch.object(benchmark, "run_supervised_process", side_effect=primary):
				with self.assertRaises(SupervisedProcessStartError) as raised:
					benchmark.run_benchmark(args)
			self.assertIs(raised.exception, primary)
			self.assertFalse(stages[0].exists())
			self.assertEqual((neighbor / "sentinel").read_bytes(), b"keep unrelated data")

	def test_start_error_without_positive_boundary_proof_retains_sandbox(self) -> None:
		with self._private_run() as (args, stages, _neighbor, _cpu):
			primary = SupervisedProcessStartError(FileNotFoundError("synthetic unproven start failure"))
			primary.process_boundary_quiescent = None
			with mock.patch.object(benchmark, "run_supervised_process", side_effect=primary):
				with self.assertRaises(SupervisedProcessStartError) as raised:
					benchmark.run_benchmark(args)
			self.assertIs(raised.exception, primary)
			self.assertTrue(stages[0].exists())

	def test_real_supervisor_quiet_start_callback_failure_cleans_sandbox(self) -> None:
		with self._private_run() as (args, stages, _neighbor, cpu):
			primary = RuntimeError("synthetic process CPU start failure")
			cpu.start.side_effect = primary

			def run_python(_command, **keywords):
				return run_supervised_process([sys.executable, "-c", "pass"], **keywords)

			with mock.patch.object(benchmark, "run_supervised_process", side_effect=run_python):
				with self.assertRaises(RuntimeError) as raised:
					benchmark.run_benchmark(args)
			self.assertIs(raised.exception, primary)
			cpu.start.assert_called_once()
			cpu.finish.assert_called_once()
			self.assertFalse(stages[0].exists())

	def test_callback_cleanup_debt_retains_sandbox_and_original_cause(self) -> None:
		with self._private_run() as (args, stages, _neighbor, cpu):
			primary = RuntimeError("synthetic callback failure")
			cpu.start.side_effect = primary
			debt = SupervisedProcessCleanupError("synthetic cleanup debt", original_error=primary, pid=123)

			def fail_with_debt(_command, **keywords):
				try:
					keywords["process_started_callback"](123)
				except RuntimeError:
					raise debt from primary

			with mock.patch.object(benchmark, "run_supervised_process", side_effect=fail_with_debt):
				with self.assertRaises(SupervisedProcessCleanupError) as raised:
					benchmark.run_benchmark(args)
			self.assertIs(raised.exception, debt)
			self.assertIs(raised.exception.original_error, primary)
			self.assertIs(raised.exception.__cause__, primary)
			self.assertTrue(stages[0].exists())

	def test_cpu_finish_error_does_not_replace_start_error(self) -> None:
		with self._private_run() as (args, stages, _neighbor, cpu):
			primary = SupervisedProcessStartError(FileNotFoundError("synthetic start failure"))
			cpu.finish.side_effect = OSError("synthetic accounting close failure")
			with mock.patch.object(benchmark, "run_supervised_process", side_effect=primary):
				with self.assertRaises(SupervisedProcessStartError) as raised:
					benchmark.run_benchmark(args)
			self.assertIs(raised.exception, primary)
			self.assertFalse(stages[0].exists())
			self.assertTrue(any("accounting close failure" in note for note in primary.__notes__))

	def test_cleanup_failure_preserves_setup_error_and_records_retention(self) -> None:
		with self._private_run() as (args, stages, neighbor, _cpu):
			primary = OSError("synthetic fixture copy failure")
			with (
				mock.patch.object(benchmark.shutil, "copyfile", side_effect=primary),
				mock.patch.object(benchmark.shutil, "rmtree", side_effect=OSError("synthetic cleanup failure")) as cleanup,
			):
				with self.assertRaises(OSError) as raised:
					benchmark.run_benchmark(args)
			self.assertIs(raised.exception, primary)
			cleanup.assert_called_once_with(stages[0])
			self.assertTrue(stages[0].exists())
			self.assertEqual((neighbor / "sentinel").read_bytes(), b"keep unrelated data")
			self.assertTrue(any("cleanup failure" in note for note in primary.__notes__))
			report = json.loads(args.output.read_text(encoding="utf-8"))
			self.assertFalse(report["valid"])
			self.assertEqual(report["error"], str(primary))
			self.assertIn("cleanup failure", report["cleanup_error"])

	def test_report_write_error_does_not_replace_setup_or_start_error(self) -> None:
		for phase in ("setup", "start"):
			with self.subTest(phase=phase), self._private_run() as (args, stages, _neighbor, _cpu):
				primary = OSError("synthetic setup failure") if phase == "setup" else SupervisedProcessStartError(FileNotFoundError("synthetic start failure"))
				with contextlib.ExitStack() as stack:
					stack.enter_context(mock.patch.object(benchmark, "_write_report", side_effect=OSError("synthetic report write failure")))
					if phase == "setup":
						stack.enter_context(mock.patch.object(benchmark.shutil, "copyfile", side_effect=primary))
					else:
						stack.enter_context(mock.patch.object(benchmark, "run_supervised_process", side_effect=primary))
					with self.assertRaises(type(primary)) as raised:
						benchmark.run_benchmark(args)
				self.assertIs(raised.exception, primary)
				self.assertFalse(stages[0].exists())
				self.assertTrue(any("report write failure" in note for note in primary.__notes__))

	def test_partial_owner_receipt_write_retains_unproven_stage(self) -> None:
		with self._private_run() as (args, stages, neighbor, _cpu):
			primary = OSError("synthetic receipt write failure")
			original_write = Path.write_bytes

			def fail_owner_write(path, data):
				if path.name == "owner.receipt":
					original_write(path, data[:3])
					raise primary
				return original_write(path, data)

			with (
				mock.patch.object(Path, "write_bytes", fail_owner_write),
				mock.patch.object(benchmark, "run_supervised_process") as process,
			):
				with self.assertRaises(OSError) as raised:
					benchmark.run_benchmark(args)
			self.assertIs(raised.exception, primary)
			process.assert_not_called()
			self.assertTrue(stages[0].exists())
			self.assertEqual((stages[0] / "owner.receipt").stat().st_size, 3)
			self.assertEqual((neighbor / "sentinel").read_bytes(), b"keep unrelated data")
			report = json.loads(args.output.read_text(encoding="utf-8"))
			self.assertFalse(report["valid"])
			self.assertIn("retained", report["sandbox_cleanup"])

	def test_keep_sandbox_retains_owned_stage_after_setup_failure(self) -> None:
		with self._private_run() as (args, stages, _neighbor, _cpu):
			args.keep_sandbox = True
			primary = OSError("synthetic fixture copy failure")
			with mock.patch.object(benchmark.shutil, "copyfile", side_effect=primary):
				with self.assertRaises(OSError) as raised:
					benchmark.run_benchmark(args)
			self.assertIs(raised.exception, primary)
			self.assertTrue(stages[0].exists())
			self.assertEqual((stages[0] / "owner.receipt").stat().st_size, 32)
			self.assertIn("retained", json.loads(args.output.read_text(encoding="utf-8"))["sandbox_cleanup"])

	def test_changed_owner_receipt_refuses_cleanup_even_after_quiet_start_error(self) -> None:
		with self._private_run() as (args, stages, _neighbor, _cpu):
			primary = SupervisedProcessStartError(FileNotFoundError("synthetic start failure"))

			def replace_receipt_and_fail(*_arguments, **_keywords):
				(stages[0] / "owner.receipt").write_bytes(b"foreign replacement")
				raise primary

			with mock.patch.object(benchmark, "run_supervised_process", side_effect=replace_receipt_and_fail):
				with self.assertRaises(SupervisedProcessStartError) as raised:
					benchmark.run_benchmark(args)
			self.assertIs(raised.exception, primary)
			self.assertTrue(stages[0].exists())
			self.assertEqual((stages[0] / "owner.receipt").read_bytes(), b"foreign replacement")

	def test_quiet_success_cleans_only_owned_stage(self) -> None:
		with self._private_run() as (args, stages, neighbor, _cpu):
			with mock.patch.object(benchmark, "run_supervised_process", side_effect=self._quiet_result) as process:
				report = benchmark.run_benchmark(args)
			self.assertTrue(report["valid"])
			self.assertEqual(process.call_count, 2)
			self.assertFalse(stages[0].exists())
			self.assertEqual((neighbor / "sentinel").read_bytes(), b"keep unrelated data")
			self.assertEqual(json.loads(args.output.read_text(encoding="utf-8")), report)

	def test_cleanup_failure_after_quiet_success_is_a_reported_failure(self) -> None:
		with self._private_run() as (args, stages, _neighbor, _cpu):
			primary = OSError("synthetic cleanup failure")
			with (
				mock.patch.object(benchmark, "run_supervised_process", side_effect=self._quiet_result),
				mock.patch.object(benchmark.shutil, "rmtree", side_effect=primary),
			):
				with self.assertRaises(OSError) as raised:
					benchmark.run_benchmark(args)
			self.assertIs(raised.exception, primary)
			self.assertTrue(stages[0].exists())
			report = json.loads(args.output.read_text(encoding="utf-8"))
			self.assertFalse(report["valid"])
			self.assertIn("cleanup failure", report["cleanup_error"])

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

	def test_failed_report_encode_write_or_replace_leaves_old_output_and_no_pending(self) -> None:
		for phase in ("encode", "write", "replace"):
			with self.subTest(phase=phase), tempfile.TemporaryDirectory(prefix="gf-reactive-pending-") as directory:
				root = Path(directory).resolve()
				output = root / "report.json"
				original = json.dumps({"kind": benchmark.REPORT_KIND, "schema_version": 1, "sentinel": "old result"}).encode("utf-8")
				output.write_bytes(original)
				primary = OSError(f"synthetic report {phase} failure")
				create_pending = tempfile.NamedTemporaryFile

				@contextlib.contextmanager
				def failing_pending(*arguments, **keywords):
					with create_pending(*arguments, **keywords) as stream:
						proxy = mock.Mock(wraps=stream)
						proxy.name = stream.name
						proxy.write.side_effect = primary
						yield proxy

				payload = {"kind": benchmark.REPORT_KIND, "schema_version": 1}
				with contextlib.ExitStack() as stack:
					stack.enter_context(mock.patch.object(benchmark, "ROOT", root))
					if phase == "encode":
						payload["invalid"] = object()
					elif phase == "write":
						stack.enter_context(mock.patch.object(benchmark.tempfile, "NamedTemporaryFile", side_effect=failing_pending))
					else:
						stack.enter_context(mock.patch.object(Path, "replace", side_effect=primary))
					with self.assertRaises(TypeError if phase == "encode" else OSError) as raised:
						benchmark._write_report(output, payload)
					if phase != "encode":
						self.assertIs(raised.exception, primary)
				self.assertEqual(output.read_bytes(), original)
				self.assertEqual(list(root.glob("*.pending")), [])

	def test_pending_cleanup_failure_preserves_report_replace_error(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-reactive-pending-close-") as directory:
			root = Path(directory).resolve()
			primary = OSError("synthetic report replace failure")
			with (
				mock.patch.object(benchmark, "ROOT", root),
				mock.patch.object(Path, "replace", side_effect=primary),
				mock.patch.object(Path, "unlink", side_effect=OSError("synthetic pending cleanup failure")),
			):
				with self.assertRaises(OSError) as raised:
					benchmark._write_report(root / "report.json", {"kind": benchmark.REPORT_KIND, "schema_version": 1})
			self.assertIs(raised.exception, primary)
			self.assertEqual(len(list(root.glob("*.pending"))), 1)
			self.assertTrue(any("pending cleanup failure" in note for note in primary.__notes__))

	def test_pending_replacement_refuses_deleting_foreign_file(self) -> None:
		with tempfile.TemporaryDirectory(prefix="gf-reactive-pending-identity-") as directory:
			root = Path(directory).resolve()
			output = root / "report.json"
			original = json.dumps({"kind": benchmark.REPORT_KIND, "schema_version": 1, "sentinel": "old result"}).encode("utf-8")
			output.write_bytes(original)
			primary = OSError("synthetic concurrent pending replacement")
			original_replace = Path.replace
			replacements = []

			def replace_with_foreign(path, _destination):
				original_replace(path, root / "displaced-original")
				path.write_bytes(b"foreign replacement")
				replacements.append(path)
				raise primary

			with (
				mock.patch.object(benchmark, "ROOT", root),
				mock.patch.object(Path, "replace", replace_with_foreign),
			):
				with self.assertRaises(OSError) as raised:
					benchmark._write_report(output, {"kind": benchmark.REPORT_KIND, "schema_version": 1})
			self.assertIs(raised.exception, primary)
			self.assertEqual(output.read_bytes(), original)
			self.assertEqual(replacements[0].read_bytes(), b"foreign replacement")

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
