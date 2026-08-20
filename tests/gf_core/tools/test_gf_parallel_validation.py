#!/usr/bin/env python3
"""Focused tests for supervised Git workspace materialization."""

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

import gf_parallel_validation as parallel_validation  # noqa: E402
import gf_process_supervisor as process_supervisor  # noqa: E402


class SupervisedGitTests(unittest.TestCase):
	def test_materializer_reproduces_binary_git_diff_through_supervisor(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source = root / "source"
			source.mkdir()
			self._git(source, "init", "--quiet")
			self._git(source, "config", "user.email", "tests@example.invalid")
			self._git(source, "config", "user.name", "GF Tests")
			payload_path = source / "payload.bin"
			payload_path.write_bytes(b"before\x00\r\n")
			self._git(source, "add", "payload.bin")
			self._git(source, "commit", "--quiet", "-m", "fixture")
			expected = b"after\x00\xff\r\n"
			payload_path.write_bytes(expected)

			snapshot = parallel_validation.capture_workspace(source)
			target = root / "target"
			parallel_validation.materialize_workspace(snapshot, target)

			self.assertTrue(snapshot.binary_diff)
			self.assertEqual((target / "payload.bin").read_bytes(), expected)
			self.assertEqual(
				parallel_validation.capture_workspace(target).workspace_fingerprint,
				snapshot.workspace_fingerprint,
			)

	def test_supervisor_round_trips_binary_stdin_and_stdout(self) -> None:
		payload = b"binary\x00patch\xff\nline\r\n"

		result = process_supervisor.run_supervised_process(
			[
				sys.executable,
				"-c",
				(
					"import sys; data = sys.stdin.buffer.read(); "
					"sys.stdout.buffer.write(data)"
				),
			],
			cwd=ROOT,
			timeout_seconds=10.0,
			stdin_bytes=payload,
			text_errors="surrogateescape",
			binary_output=True,
		)

		self.assertEqual(result.return_code, 0)
		self.assertFalse(result.timed_out)
		self.assertTrue(result.process_boundary_quiescent)
		self.assertEqual(
			result.stdout.encode("utf-8", errors="surrogateescape"),
			payload,
		)

	def test_run_git_requires_positive_process_boundary_proof(self) -> None:
		result = process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="ok\n",
			stderr="",
			timed_out=False,
			duration_seconds=0.01,
			pid=123,
			process_boundary_quiescent=False,
		)
		with mock.patch.object(
			parallel_validation,
			"run_supervised_process",
			return_value=result,
		) as supervised:
			with self.assertRaises(
				parallel_validation.WorkspaceProcessBoundaryError,
			) as raised:
				parallel_validation._run_git(ROOT, ["status", "--porcelain=v1"])  # noqa: SLF001

		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)
		supervised.assert_called_once()

	def test_run_git_preserves_binary_payload_through_supervisor(self) -> None:
		payload = b"diff --git a/x b/x\n\xff\x00"
		stdout = b"result\x00\xfe".decode("utf-8", errors="surrogateescape")
		result = process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout=stdout,
			stderr="",
			timed_out=False,
			duration_seconds=0.01,
			pid=123,
			process_boundary_quiescent=True,
		)
		with mock.patch.object(
			parallel_validation,
			"run_supervised_process",
			return_value=result,
		) as supervised:
			captured = parallel_validation._run_git(  # noqa: SLF001
				ROOT,
				["apply", "--binary", "--index"],
				input_bytes=payload,
			)

		self.assertEqual(captured, b"result\x00\xfe")
		call = supervised.call_args
		self.assertEqual(call.args[0], ["git", "apply", "--binary", "--index"])
		self.assertEqual(call.kwargs["stdin_bytes"], payload)
		self.assertEqual(call.kwargs["text_errors"], "surrogateescape")
		self.assertTrue(call.kwargs["binary_output"])

	def test_materializer_preserves_owner_root_when_git_boundary_is_unproved(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source = root / "source"
			source.mkdir()
			target = root / "target"
			snapshot = parallel_validation.CapturedWorkspace(
				source_root=source,
				head="1" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="2" * 64,
			)

			def fail_clone(
				_root: Path,
				arguments: list[str],
				**_kwargs: object,
			) -> bytes:
				Path(arguments[-1]).mkdir()
				raise parallel_validation.WorkspaceProcessBoundaryError(
					"Git process boundary was not proven quiet."
				)

			with (
				mock.patch.object(
					parallel_validation,
					"_validate_repository_root",
					return_value=source,
				),
				mock.patch.object(parallel_validation, "_run_git", side_effect=fail_clone),
			):
				with self.assertRaises(
					parallel_validation.WorkspaceProcessBoundaryError,
				) as raised:
					parallel_validation.materialize_workspace(
						snapshot,
						target,
						verify_source=False,
					)

			staging_root = root / ".target.m"
			self.assertTrue(staging_root.is_dir())
			self.assertEqual(raised.exception.preserved_paths, (staging_root,))
			self.assertTrue(raised.exception.cleanup_debt)

	def test_materializer_preserves_published_target_after_late_boundary_failure(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source = root / "source"
			source.mkdir()
			target = root / "target"
			snapshot = parallel_validation.CapturedWorkspace(
				source_root=source,
				head="1" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="2" * 64,
			)

			def clone_then_checkout(
				_root: Path,
				arguments: list[str],
				**_kwargs: object,
			) -> bytes:
				if arguments[0] == "clone":
					(Path(arguments[-1]) / ".git").mkdir(parents=True)
				return b""

			late_boundary = parallel_validation.WorkspaceProcessBoundaryError(
				"Late Git process boundary was not proven quiet."
			)
			with (
				mock.patch.object(
					parallel_validation,
					"_validate_repository_root",
					return_value=source,
				),
				mock.patch.object(parallel_validation, "_run_git", side_effect=clone_then_checkout),
				mock.patch.object(parallel_validation, "_validate_workspace_tree_safety"),
				mock.patch.object(parallel_validation, "_assert_source_matches_snapshot"),
				mock.patch.object(
					parallel_validation,
					"_capture_workspace_once",
					side_effect=(snapshot, late_boundary),
				),
			):
				with self.assertRaises(
					parallel_validation.WorkspaceProcessBoundaryError,
				) as raised:
					parallel_validation.materialize_workspace(
						snapshot,
						target,
						verify_source=False,
					)

			staging_root = root / ".target.m"
			self.assertTrue(target.is_dir())
			self.assertTrue(staging_root.is_dir())
			self.assertEqual(
				raised.exception.preserved_paths,
				(target, staging_root),
			)

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
			raise AssertionError(completed.stderr.decode("utf-8", errors="replace"))


if __name__ == "__main__":
	unittest.main()
