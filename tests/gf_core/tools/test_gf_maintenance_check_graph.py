#!/usr/bin/env python3
"""Focused tests for maintenance check-graph workspace fingerprinting."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
TOOLS_ROOT = ROOT / "tools"
if str(TOOLS_ROOT) not in sys.path:
	sys.path.insert(0, str(TOOLS_ROOT))

import gf_maintenance_check_graph as check_graph  # noqa: E402
import gf_process_supervisor as process_supervisor  # noqa: E402


class WorkspaceFingerprintGitTests(unittest.TestCase):
	def test_run_git_bytes_round_trips_binary_stdin_and_stdout(self) -> None:
		payload = b"binary\x00payload\xff\r\nsecond-line\n"
		with tempfile.TemporaryDirectory() as temporary_directory:
			repository = Path(temporary_directory) / "repository"
			repository.mkdir()
			self._git(repository, "init", "--quiet")

			object_id = check_graph.run_git_bytes(
				repository,
				["hash-object", "-w", "--stdin"],
				input_bytes=payload,
			).decode("ascii", errors="strict").strip()
			actual = check_graph.run_git_bytes(
				repository,
				["cat-file", "blob", object_id],
			)

		self.assertRegex(object_id, r"^[0-9a-f]{40}(?:[0-9a-f]{24})?$")
		self.assertEqual(actual, payload)

	def test_run_git_bytes_rejects_unproved_process_boundary(self) -> None:
		payload = b"input\x00\xff\r\n"
		result = process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout=b"output\x00\xfe\r\n".decode(
				"utf-8",
				errors="surrogateescape",
			),
			stderr="",
			timed_out=False,
			duration_seconds=0.01,
			pid=123,
			process_boundary_quiescent=False,
		)
		with mock.patch.object(
			check_graph,
			"run_supervised_process",
			return_value=result,
		) as supervised:
			with self.assertRaises(
				check_graph.WorkspaceFingerprintProcessBoundaryError,
			) as raised:
				check_graph.run_git_bytes(
					ROOT,
					["hash-object", "--stdin"],
					input_bytes=payload,
				)

		self.assertIsInstance(
			raised.exception,
			check_graph.WorkspaceFingerprintError,
		)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)
		call = supervised.call_args
		self.assertEqual(call.args[0], ["git", "hash-object", "--stdin"])
		self.assertEqual(call.kwargs["stdin_bytes"], payload)
		self.assertEqual(call.kwargs["text_errors"], "surrogateescape")
		self.assertTrue(call.kwargs["binary_output"])

	def test_run_git_bytes_preserves_process_control_exceptions(self) -> None:
		for error in (
			KeyboardInterrupt("fixture interrupt"),
			SystemExit(7),
			GeneratorExit("fixture generator exit"),
		):
			with self.subTest(error=type(error).__name__), mock.patch.object(
				check_graph,
				"run_supervised_process",
				side_effect=error,
			):
				with self.assertRaises(type(error)) as raised:
					check_graph.run_git_bytes(ROOT, ["status", "--porcelain=v1"])
			self.assertIs(raised.exception, error)

	def test_run_git_bytes_wraps_ordinary_supervision_failure(self) -> None:
		with mock.patch.object(
			check_graph,
			"run_supervised_process",
			side_effect=RuntimeError("fixture supervision failure"),
		):
			with self.assertRaises(
				check_graph.WorkspaceFingerprintProcessBoundaryError,
			) as raised:
				check_graph.run_git_bytes(ROOT, ["status", "--porcelain=v1"])
		self.assertIsInstance(raised.exception.__cause__, RuntimeError)

	def test_run_git_bytes_classifies_proven_no_child_start_failure_as_setup(self) -> None:
		original = FileNotFoundError("fixture git missing")
		with mock.patch.object(
			check_graph,
			"run_supervised_process",
			side_effect=process_supervisor.SupervisedProcessStartError(original),
		):
			with self.assertRaises(
				check_graph.WorkspaceFingerprintSetupError,
			) as raised:
				check_graph.run_git_bytes(ROOT, ["status", "--porcelain=v1"])
		self.assertIs(raised.exception.__cause__.original_error, original)

	@staticmethod
	def _git(root: Path, *arguments: str) -> None:
		completed = subprocess.run(
			["git", *arguments],
			cwd=root,
			stdout=subprocess.PIPE,
			stderr=subprocess.PIPE,
			check=False,
		)
		if completed.returncode != 0:
			raise AssertionError(
				completed.stderr.decode("utf-8", errors="replace")
			)


if __name__ == "__main__":
	unittest.main()
