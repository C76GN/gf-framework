#!/usr/bin/env python3
"""Focused tests for supervised Git workspace materialization."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
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
		for payload in (b"", b"binary\x00patch\xff\nline\r\n"):
			with self.subTest(payload=payload):
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

	def test_supervisor_refuses_launch_after_stdin_staging_timeout(self) -> None:
		clock = [0.0]

		class SlowStdin:
			closed = False

			def write(self, payload: object) -> int:
				clock[0] = 2.0
				return len(payload)  # type: ignore[arg-type]

			def seek(self, _offset: int) -> int:
				return 0

			def close(self) -> None:
				self.closed = True

		stream = SlowStdin()
		with mock.patch.object(
			process_supervisor.tempfile,
			"TemporaryFile",
			return_value=stream,
		), mock.patch.object(
			process_supervisor.time,
			"perf_counter",
			side_effect=lambda: clock[0],
		), mock.patch.object(
			process_supervisor,
			"_new_process_tree_owner",
		) as owner_factory:
			result = process_supervisor.run_supervised_process(
				[sys.executable, "-c", "raise SystemExit(0)"],
				cwd=ROOT,
				timeout_seconds=1.0,
				stdin_bytes=b"payload",
			)

		self.assertTrue(stream.closed)
		owner_factory.assert_not_called()
		self.assertEqual(result.return_code, 124)
		self.assertTrue(result.timed_out)
		self.assertFalse(result.cancelled)
		self.assertEqual(result.pid, 0)
		self.assertTrue(result.process_boundary_quiescent)

	def test_supervisor_refuses_launch_when_deadline_expires_during_stdin_seek(self) -> None:
		clock = [0.0]

		class SlowSeekStdin:
			closed = False

			def write(self, payload: object) -> int:
				return len(payload)  # type: ignore[arg-type]

			def seek(self, _offset: int) -> int:
				clock[0] = 2.0
				return 0

			def close(self) -> None:
				self.closed = True

		stream = SlowSeekStdin()
		with mock.patch.object(
			process_supervisor.tempfile,
			"TemporaryFile",
			return_value=stream,
		), mock.patch.object(
			process_supervisor.time,
			"perf_counter",
			side_effect=lambda: clock[0],
		), mock.patch.object(
			process_supervisor,
			"_new_process_tree_owner",
		) as owner_factory:
			result = process_supervisor.run_supervised_process(
				[sys.executable, "-c", "raise SystemExit(0)"],
				cwd=ROOT,
				timeout_seconds=1.0,
				stdin_bytes=b"payload",
			)

		self.assertTrue(stream.closed)
		owner_factory.assert_not_called()
		self.assertEqual(result.return_code, 124)
		self.assertTrue(result.timed_out)
		self.assertEqual(result.pid, 0)
		self.assertTrue(result.process_boundary_quiescent)

	def test_supervisor_refuses_launch_after_stdin_staging_cancellation(self) -> None:
		cancellation = threading.Event()

		class CancellingStdin:
			closed = False

			def write(self, payload: object) -> int:
				cancellation.set()
				return len(payload)  # type: ignore[arg-type]

			def seek(self, _offset: int) -> int:
				return 0

			def close(self) -> None:
				self.closed = True

		stream = CancellingStdin()
		with mock.patch.object(
			process_supervisor.tempfile,
			"TemporaryFile",
			return_value=stream,
		), mock.patch.object(
			process_supervisor,
			"_new_process_tree_owner",
		) as owner_factory:
			result = process_supervisor.run_supervised_process(
				[sys.executable, "-c", "raise SystemExit(0)"],
				cwd=ROOT,
				timeout_seconds=10.0,
				stdin_bytes=b"payload",
				cancellation_event=cancellation,
			)

		self.assertTrue(stream.closed)
		owner_factory.assert_not_called()
		self.assertEqual(result.return_code, 130)
		self.assertFalse(result.timed_out)
		self.assertTrue(result.cancelled)
		self.assertEqual(result.pid, 0)
		self.assertTrue(result.process_boundary_quiescent)

	def test_supervisor_stops_between_bounded_stdin_chunks(self) -> None:
		cancellation = threading.Event()

		class CancellingAfterFirstChunk:
			closed = False
			write_sizes: list[int] = []

			def write(self, payload: object) -> int:
				size = len(payload)  # type: ignore[arg-type]
				self.write_sizes.append(size)
				cancellation.set()
				return size

			def close(self) -> None:
				self.closed = True

		stream = CancellingAfterFirstChunk()
		payload = b"x" * (process_supervisor.STDIN_STAGE_CHUNK_BYTES + 1)
		with mock.patch.object(
			process_supervisor.tempfile,
			"TemporaryFile",
			return_value=stream,
		), mock.patch.object(
			process_supervisor,
			"_new_process_tree_owner",
		) as owner_factory:
			result = process_supervisor.run_supervised_process(
				[sys.executable, "-c", "raise SystemExit(0)"],
				cwd=ROOT,
				timeout_seconds=10.0,
				stdin_bytes=payload,
				cancellation_event=cancellation,
			)

		self.assertEqual(stream.write_sizes, [process_supervisor.STDIN_STAGE_CHUNK_BYTES])
		self.assertTrue(stream.closed)
		owner_factory.assert_not_called()
		self.assertTrue(result.cancelled)
		self.assertEqual(result.pid, 0)
		self.assertTrue(result.process_boundary_quiescent)

	def test_stdin_close_failure_does_not_mask_staging_control_exception(self) -> None:
		class FailingStdin:
			def __init__(self, error: BaseException) -> None:
				self.error = error

			def write(self, _payload: object) -> int:
				raise self.error

			def close(self) -> None:
				raise OSError("fixture close failure")

		for error in (
			KeyboardInterrupt("fixture interrupt"),
			SystemExit(9),
			GeneratorExit("fixture generator exit"),
		):
			with self.subTest(error=type(error).__name__), mock.patch.object(
				process_supervisor.tempfile,
				"TemporaryFile",
				return_value=FailingStdin(error),
			), mock.patch.object(
				process_supervisor,
				"_new_process_tree_owner",
			) as owner_factory:
				with self.assertRaises(type(error)) as raised:
					process_supervisor.run_supervised_process(
						[sys.executable, "-c", "raise SystemExit(0)"],
						cwd=ROOT,
						timeout_seconds=10.0,
						stdin_bytes=b"payload",
					)

			self.assertIs(raised.exception, error)
			self.assertTrue(any("stdin cleanup also failed" in note for note in error.__notes__))
			owner_factory.assert_not_called()

	def test_stdin_close_failure_does_not_mask_prelaunch_stop_result(self) -> None:
		for stop_kind in ("timeout", "cancel"):
			clock = [0.0]
			cancellation = threading.Event()

			class StoppingStdin:
				close_count = 0

				def write(self, payload: object) -> int:
					if stop_kind == "timeout":
						clock[0] = 2.0
					else:
						cancellation.set()
					return len(payload)  # type: ignore[arg-type]

				def close(self) -> None:
					self.close_count += 1
					if self.close_count == 1:
						raise OSError("fixture close failure")

			stdin_stream = StoppingStdin()
			with self.subTest(stop_kind=stop_kind), mock.patch.object(
				process_supervisor.tempfile,
				"TemporaryFile",
				return_value=stdin_stream,
			), mock.patch.object(
				process_supervisor.time,
				"perf_counter",
				side_effect=lambda: clock[0],
			), mock.patch.object(
				process_supervisor,
				"_new_process_tree_owner",
			) as owner_factory:
				result = process_supervisor.run_supervised_process(
					[sys.executable, "-c", "raise SystemExit(0)"],
					cwd=ROOT,
					timeout_seconds=1.0,
					stdin_bytes=b"payload",
					cancellation_event=cancellation,
				)

			owner_factory.assert_not_called()
			self.assertEqual(result.return_code, 124 if stop_kind == "timeout" else 130)
			self.assertEqual(result.timed_out, stop_kind == "timeout")
			self.assertEqual(result.cancelled, stop_kind == "cancel")
			self.assertEqual(result.pid, 0)
			self.assertTrue(result.process_boundary_quiescent)
			self.assertEqual(stdin_stream.close_count, 2)
			self.assertTrue(any("cleanup succeeded on retry" in note for note in result.notes))

	def test_repeated_stdin_close_failure_surfaces_prelaunch_cleanup_debt(self) -> None:
		cancellation = threading.Event()

		class UnclosableStdin:
			close_count = 0

			def write(self, payload: object) -> int:
				cancellation.set()
				return len(payload)  # type: ignore[arg-type]

			def close(self) -> None:
				self.close_count += 1
				raise OSError("fixture repeated close failure")

		stdin_stream = UnclosableStdin()
		with mock.patch.object(
			process_supervisor.tempfile,
			"TemporaryFile",
			return_value=stdin_stream,
		), mock.patch.object(
			process_supervisor,
			"_new_process_tree_owner",
		) as owner_factory:
			with self.assertRaises(
				process_supervisor.SupervisedProcessCleanupError,
			) as raised:
				process_supervisor.run_supervised_process(
					[sys.executable, "-c", "raise SystemExit(0)"],
					cwd=ROOT,
					timeout_seconds=10.0,
					stdin_bytes=b"payload",
					cancellation_event=cancellation,
				)

		owner_factory.assert_not_called()
		self.assertGreaterEqual(stdin_stream.close_count, 3)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)

	def test_prelaunch_stop_does_not_mask_cleanup_control_exception(self) -> None:
		cancellation = threading.Event()
		injected = KeyboardInterrupt("fixture cleanup interrupt")

		class EmptyOwner:
			_started_process = None
			_process_was_created = False
			cleanup_failed = False
			closed = False

			def termination_succeeded(self) -> bool:
				return True

			def confirm_cleanup_after_reap(self) -> list[str]:
				return []

			def cleanup_confirmation_succeeded(self) -> bool:
				return True

			def close(self) -> list[str]:
				self.closed = True
				return []

			def is_closed(self) -> bool:
				return self.closed

			def close_terminates_tree(self) -> bool:
				return False

		owner = EmptyOwner()

		def make_owner() -> EmptyOwner:
			cancellation.set()
			return owner

		def checkpoint(name: str) -> None:
			if name == "before_owner_close":
				raise injected

		with mock.patch.object(
			process_supervisor,
			"_new_process_tree_owner",
			side_effect=make_owner,
		), mock.patch.object(
			process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=checkpoint,
		):
			with self.assertRaises(KeyboardInterrupt) as raised:
				process_supervisor.run_supervised_process(
					[sys.executable, "-c", "raise SystemExit(0)"],
					cwd=ROOT,
					timeout_seconds=10.0,
					cancellation_event=cancellation,
				)

		self.assertIs(raised.exception, injected)
		self.assertTrue(owner.closed)

	def test_cleanup_error_formatting_does_not_replace_first_control_exception(self) -> None:
		class HostileCleanupError(BaseException):
			def __str__(self) -> str:
				raise self

		primary = KeyboardInterrupt("fixture process-owner interrupt")
		cleanup_failure = HostileCleanupError()

		def checkpoint(name: str) -> None:
			if name == "process_owner_started":
				raise primary
			if name == "before_initial_termination":
				raise cleanup_failure

		with mock.patch.object(
			process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=checkpoint,
		):
			with self.assertRaises(KeyboardInterrupt) as raised:
				process_supervisor.run_supervised_process(
					[sys.executable, "-c", "import time; time.sleep(60)"],
					cwd=ROOT,
					timeout_seconds=10.0,
				)

		self.assertIs(raised.exception, primary)

	def test_primary_traceback_restoration_bypasses_hostile_override(self) -> None:
		replacement = SystemExit("fixture traceback replacement")

		class HostilePrimary(KeyboardInterrupt):
			def with_traceback(self, traceback: object) -> BaseException:
				raise replacement

		primary = HostilePrimary("fixture process-owner interrupt")

		def checkpoint(name: str) -> None:
			if name == "process_owner_started":
				raise primary

		with mock.patch.object(
			process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=checkpoint,
		):
			observed: BaseException | None = None
			try:
				process_supervisor.run_supervised_process(
					[sys.executable, "-c", "import time; time.sleep(60)"],
					cwd=ROOT,
					timeout_seconds=10.0,
				)
			except BaseException as error:
				observed = error

		self.assertIs(observed, primary)

	def test_prelaunch_stop_rejects_unclosed_process_tree_owner(self) -> None:
		cancellation = threading.Event()

		class UnclosableOwner:
			_started_process = None
			_process_was_created = False
			cleanup_failed = False
			close_count = 0

			def termination_succeeded(self) -> bool:
				return True

			def confirm_cleanup_after_reap(self) -> list[str]:
				return []

			def cleanup_confirmation_succeeded(self) -> bool:
				return True

			def close(self) -> list[str]:
				self.close_count += 1
				self.cleanup_failed = True
				return [f"fixture owner close failure {self.close_count}"]

			def is_closed(self) -> bool:
				return False

			def close_terminates_tree(self) -> bool:
				return False

		owner = UnclosableOwner()

		def make_owner() -> UnclosableOwner:
			cancellation.set()
			return owner

		with mock.patch.object(
			process_supervisor,
			"_new_process_tree_owner",
			side_effect=make_owner,
		):
			with self.assertRaises(
				process_supervisor.SupervisedProcessCleanupError
			) as raised:
				process_supervisor.run_supervised_process(
					[sys.executable, "-c", "raise SystemExit(0)"],
					cwd=ROOT,
					timeout_seconds=10.0,
					cancellation_event=cancellation,
				)

		self.assertEqual(owner.close_count, 2)
		self.assertTrue(raised.exception.cleanup_debt)
		self.assertFalse(raised.exception.process_boundary_quiescent)
		self.assertTrue(
			any("fixture owner close failure" in note for note in raised.exception.notes)
		)

	def test_completed_process_wrapper_rejects_unproved_boundary(self) -> None:
		unproved = process_supervisor.SupervisedProcessResult(
			return_code=0,
			stdout="",
			stderr="",
			timed_out=False,
			duration_seconds=0.1,
			pid=123,
			notes=("fixture cleanup debt",),
			process_boundary_quiescent=False,
		)
		with mock.patch.object(
			process_supervisor,
			"run_supervised_process",
			return_value=unproved,
		):
			with self.assertRaises(
				process_supervisor.SupervisedProcessCleanupError
			) as raised:
				process_supervisor.run_supervised_completed_process(
					["fixture"],
					cwd=ROOT,
					timeout_seconds=10.0,
				)
		self.assertEqual(raised.exception.notes, unproved.notes)

	def test_completed_process_wrapper_preserves_start_error_compatibility(
		self,
	) -> None:
		original = FileNotFoundError("fixture command is unavailable")
		start_error = process_supervisor.SupervisedProcessStartError(original)
		with mock.patch.object(
			process_supervisor,
			"run_supervised_process",
			side_effect=start_error,
		):
			with self.assertRaises(FileNotFoundError) as raised:
				process_supervisor.run_supervised_completed_process(
					["fixture"],
					cwd=ROOT,
					timeout_seconds=10.0,
				)
		self.assertIs(raised.exception, original)

	def test_staged_stdin_is_closed_when_interrupted_before_owner_creation(self) -> None:
		class StagedStdin:
			closed = False

			def write(self, payload: object) -> int:
				return len(payload)  # type: ignore[arg-type]

			def seek(self, _offset: int) -> int:
				return 0

			def close(self) -> None:
				self.closed = True

		stream = StagedStdin()
		injected = KeyboardInterrupt("fixture post-staging interrupt")

		def checkpoint(name: str) -> None:
			if name == "stdin_staged":
				raise injected

		with mock.patch.object(
			process_supervisor.tempfile,
			"TemporaryFile",
			return_value=stream,
		), mock.patch.object(
			process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=checkpoint,
		), mock.patch.object(
			process_supervisor,
			"_new_process_tree_owner",
		) as owner_factory:
			with self.assertRaises(KeyboardInterrupt) as raised:
				process_supervisor.run_supervised_process(
					[sys.executable, "-c", "raise SystemExit(0)"],
					cwd=ROOT,
					timeout_seconds=10.0,
					stdin_bytes=b"payload",
				)

		self.assertIs(raised.exception, injected)
		self.assertTrue(stream.closed)
		owner_factory.assert_not_called()

	def test_staged_stdin_close_interruption_retries_owned_stream(self) -> None:
		real_stream = tempfile.TemporaryFile(mode="w+b", buffering=0)

		class TrackingStdin:
			close_count = 0

			def fileno(self) -> int:
				return real_stream.fileno()

			def write(self, payload: object) -> int:
				return real_stream.write(payload)  # type: ignore[arg-type]

			def seek(self, offset: int) -> int:
				return real_stream.seek(offset)

			def close(self) -> None:
				self.close_count += 1
				real_stream.close()

		stream = TrackingStdin()
		injected = KeyboardInterrupt("fixture close interrupt")
		injected_once = False

		def checkpoint(name: str) -> None:
			nonlocal injected_once
			if name == "stdin_stream_closed" and not injected_once:
				injected_once = True
				raise injected

		with mock.patch.object(
			process_supervisor.tempfile,
			"TemporaryFile",
			return_value=stream,
		), mock.patch.object(
			process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=checkpoint,
		):
			with self.assertRaises(KeyboardInterrupt) as raised:
				process_supervisor.run_supervised_process(
					[sys.executable, "-c", "import sys; sys.stdin.buffer.read()"],
					cwd=ROOT,
					timeout_seconds=10.0,
					stdin_bytes=b"payload",
				)

		self.assertIs(raised.exception, injected)
		self.assertEqual(stream.close_count, 2)

	def test_supervisor_stages_partial_stdin_writes_without_truncation(self) -> None:
		real_stream = tempfile.TemporaryFile(mode="w+b", buffering=0)

		class PartialStdin:
			def fileno(self) -> int:
				return real_stream.fileno()

			def write(self, payload: object) -> int:
				return real_stream.write(payload[:2])  # type: ignore[index]

			def seek(self, offset: int) -> int:
				return real_stream.seek(offset)

			def close(self) -> None:
				real_stream.close()

		payload = b"partial-write-payload"
		with mock.patch.object(
			process_supervisor.tempfile,
			"TemporaryFile",
			return_value=PartialStdin(),
		):
			result = process_supervisor.run_supervised_process(
				[
					sys.executable,
					"-c",
					"import sys; sys.stdout.buffer.write(sys.stdin.buffer.read())",
				],
				cwd=ROOT,
				timeout_seconds=10.0,
				stdin_bytes=payload,
				text_errors="surrogateescape",
				binary_output=True,
			)

		self.assertEqual(result.return_code, 0)
		self.assertTrue(result.process_boundary_quiescent)
		self.assertEqual(
			result.stdout.encode("utf-8", errors="surrogateescape"),
			payload,
		)

	def test_supervisor_rejects_invalid_stdin_staging_progress(self) -> None:
		class StalledStdin:
			closed = False
			result: object = 0

			def write(self, _payload: object) -> object:
				return self.result

			def close(self) -> None:
				self.closed = True

		for invalid in (None, 0, True, 8):
			stream = StalledStdin()
			stream.result = invalid
			with self.subTest(invalid=invalid), mock.patch.object(
				process_supervisor.tempfile,
				"TemporaryFile",
				return_value=stream,
			), mock.patch.object(
				process_supervisor,
				"_new_process_tree_owner",
			) as owner_factory, self.assertRaisesRegex(OSError, "make progress"):
				process_supervisor.run_supervised_process(
					[sys.executable, "-c", "raise SystemExit(0)"],
					cwd=ROOT,
					timeout_seconds=10.0,
					stdin_bytes=b"payload",
				)

			self.assertTrue(stream.closed)
			owner_factory.assert_not_called()

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

	def test_run_git_preserves_process_control_exceptions(self) -> None:
		for error in (
			KeyboardInterrupt("fixture interrupt"),
			SystemExit(7),
			GeneratorExit("fixture generator exit"),
		):
			with self.subTest(error=type(error).__name__), mock.patch.object(
				parallel_validation,
				"run_supervised_process",
				side_effect=error,
			):
				with self.assertRaises(type(error)) as raised:
					parallel_validation._run_git(  # noqa: SLF001
						ROOT,
						["status", "--porcelain=v1"],
					)
			self.assertIs(raised.exception, error)

	def test_missing_shard_executable_has_positive_no_child_boundary(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			missing_executable = Path(temporary_directory) / "missing-command"
			shard = parallel_validation.ParallelShard(
				name="missing-command",
				command=(str(missing_executable),),
				workspace=ROOT,
				timeout_seconds=10.0,
			)
			result = parallel_validation.run_parallel_shards([shard], max_workers=1)[0]

		self.assertEqual(result.exit_code, 127)
		self.assertIsNone(result.process_exit_code)
		self.assertEqual(result.pid, 0)
		self.assertFalse(result.started)
		self.assertFalse(result.ok)
		self.assertTrue(result.process_boundary_quiescent)

	def test_pre_creation_start_errors_publish_positive_no_child_proof(self) -> None:
		for original, expected_return_code in (
			(FileNotFoundError("fixture missing"), 127),
			(PermissionError("fixture denied"), 126),
		):
			with self.subTest(error=type(original).__name__), mock.patch.object(
				process_supervisor.subprocess,
				"Popen",
				side_effect=original,
			):
				with self.assertRaises(
					process_supervisor.SupervisedProcessStartError,
				) as raised:
					process_supervisor.run_supervised_process(
						["fixture-command"],
						cwd=ROOT,
						timeout_seconds=10.0,
					)

			self.assertIs(raised.exception.original_error, original)
			self.assertEqual(raised.exception.return_code, expected_return_code)
			self.assertFalse(raised.exception.started)
			self.assertEqual(raised.exception.pid, 0)
			self.assertTrue(raised.exception.process_boundary_quiescent)

	def test_pre_creation_start_error_ignores_hostile_args_getter(self) -> None:
		replacement = SystemExit("fixture hostile args getter")

		class HostileMissing(FileNotFoundError):
			def __getattribute__(self, name: str) -> object:
				if name == "args":
					raise replacement
				return super().__getattribute__(name)

		original = HostileMissing("fixture missing")
		with mock.patch.object(
			process_supervisor.subprocess,
			"Popen",
			side_effect=original,
		):
			with self.assertRaises(
				process_supervisor.SupervisedProcessStartError,
			) as raised:
				process_supervisor.run_supervised_process(
					["fixture-command"],
					cwd=ROOT,
					timeout_seconds=10.0,
				)

		self.assertIs(raised.exception.original_error, original)
		self.assertEqual(raised.exception.return_code, 127)
		self.assertTrue(raised.exception.process_boundary_quiescent)

	def test_structured_start_diagnostics_ignore_hostile_string(self) -> None:
		class HostileMissing(FileNotFoundError):
			def __str__(self) -> str:
				raise SystemExit("fixture hostile start-error text")

		original = HostileMissing("fixture missing")
		shard = parallel_validation.ParallelShard(
			name="hostile-start-error",
			command=("fixture",),
			workspace=ROOT,
			timeout_seconds=10.0,
		)
		with mock.patch.object(
			parallel_validation,
			"run_supervised_process",
			side_effect=process_supervisor.SupervisedProcessStartError(original),
		):
			result = parallel_validation._run_parallel_shard(  # noqa: SLF001
				shard,
				parallel_validation._CancellationState(),  # noqa: SLF001
				None,
				None,
			)

		self.assertEqual(result.exit_code, 127)
		self.assertFalse(result.started)
		self.assertTrue(result.process_boundary_quiescent)
		self.assertIn("detail unavailable", result.stderr)

	def test_post_creation_permission_error_is_not_misclassified_as_no_child(self) -> None:
		original = PermissionError("fixture after process creation")
		started_checkpoint = (
			"windows_process_started"
			if process_supervisor.os.name == "nt"
			else "posix_process_started"
		)

		def fail_after_creation(name: str) -> None:
			if name == started_checkpoint:
				raise original

		with mock.patch.object(
			process_supervisor,
			"_process_supervision_checkpoint",
			side_effect=fail_after_creation,
		):
			with self.assertRaises(PermissionError) as raised:
				process_supervisor.run_supervised_process(
					[sys.executable, "-c", "raise SystemExit(0)"],
					cwd=ROOT,
					timeout_seconds=10.0,
				)

		self.assertIs(raised.exception, original)
		self.assertNotIsInstance(
			raised.exception,
			process_supervisor.SupervisedProcessStartError,
		)

	def test_generic_shard_start_error_retains_unproved_boundary(self) -> None:
		shard = parallel_validation.ParallelShard(
			name="generic-start-error",
			command=("fixture",),
			workspace=ROOT,
			timeout_seconds=10.0,
		)
		with mock.patch.object(
			parallel_validation,
			"run_supervised_process",
			side_effect=OSError("synthetic post-start failure"),
		):
			result = parallel_validation._run_parallel_shard(  # noqa: SLF001
				shard,
				parallel_validation._CancellationState(),  # noqa: SLF001
				None,
				None,
			)

		self.assertEqual(result.exit_code, 127)
		self.assertFalse(result.started)
		self.assertFalse(result.process_boundary_quiescent)

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

	def test_materializer_retains_staging_for_process_control_exceptions(self) -> None:
		for error in (
			KeyboardInterrupt("fixture interrupt"),
			SystemExit(7),
			GeneratorExit("fixture generator exit"),
		):
			with self.subTest(error=type(error).__name__), tempfile.TemporaryDirectory() as temporary_directory:
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

				def interrupt_clone(
					_root: Path,
					arguments: list[str],
					**_kwargs: object,
				) -> bytes:
					Path(arguments[-1]).mkdir()
					raise error

				with (
					mock.patch.object(
						parallel_validation,
						"_validate_repository_root",
						return_value=source,
					),
					mock.patch.object(
						parallel_validation,
						"_run_git",
						side_effect=interrupt_clone,
					),
				):
					with self.assertRaises(type(error)) as raised:
						parallel_validation.materialize_workspace(
							snapshot,
							target,
							verify_source=False,
						)

				staging_root = root / ".target.m"
				self.assertIs(raised.exception, error)
				self.assertTrue(staging_root.is_dir())
				self.assertFalse(target.exists())
				self.assertIn(
					str(staging_root),
					"\n".join(getattr(error, "__notes__", ())),
				)

	def test_materializer_retains_staging_for_arbitrary_base_exception(self) -> None:
		class HostileBaseException(BaseException):
			pass

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
			injected = HostileBaseException("fixture base exception")

			def interrupt_clone(
				_root: Path,
				arguments: list[str],
				**_kwargs: object,
			) -> bytes:
				Path(arguments[-1]).mkdir()
				raise injected

			with mock.patch.object(
				parallel_validation,
				"_validate_repository_root",
				return_value=source,
			), mock.patch.object(
				parallel_validation,
				"_run_git",
				side_effect=interrupt_clone,
			):
				with self.assertRaises(HostileBaseException) as raised:
					parallel_validation.materialize_workspace(
						snapshot,
						target,
						verify_source=False,
					)

			self.assertIs(raised.exception, injected)
			self.assertTrue((root / ".target.m").is_dir())

	def test_materializer_diagnostics_do_not_replace_control_exception(self) -> None:
		class HostileInterrupt(KeyboardInterrupt):
			def add_note(self, _note: str) -> None:
				raise SystemExit("fixture hostile add_note")

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
			injected = HostileInterrupt("fixture interrupt")

			def interrupt_clone(
				_root: Path,
				arguments: list[str],
				**_kwargs: object,
			) -> bytes:
				Path(arguments[-1]).mkdir()
				raise injected

			with mock.patch.object(
				parallel_validation,
				"_validate_repository_root",
				return_value=source,
			), mock.patch.object(
				parallel_validation,
				"_run_git",
				side_effect=interrupt_clone,
			):
				with self.assertRaises(HostileInterrupt) as raised:
					parallel_validation.materialize_workspace(
						snapshot,
						target,
						verify_source=False,
					)

			self.assertIs(raised.exception, injected)
			self.assertTrue((root / ".target.m").is_dir())

	def test_materializer_retention_diagnostics_do_not_replace_boundary_error(self) -> None:
		class HostileBoundaryError(parallel_validation.WorkspaceProcessBoundaryError):
			def preserve_owned_paths(self, _paths: object) -> None:
				raise SystemExit("fixture hostile preserve_owned_paths")

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
			injected = HostileBoundaryError("fixture unproved boundary")

			def fail_clone(
				_root: Path,
				arguments: list[str],
				**_kwargs: object,
			) -> bytes:
				Path(arguments[-1]).mkdir()
				raise injected

			with mock.patch.object(
				parallel_validation,
				"_validate_repository_root",
				return_value=source,
			), mock.patch.object(
				parallel_validation,
				"_run_git",
				side_effect=fail_clone,
			):
				with self.assertRaises(HostileBoundaryError) as raised:
					parallel_validation.materialize_workspace(
						snapshot,
						target,
						verify_source=False,
					)

			self.assertIs(raised.exception, injected)
			self.assertTrue((root / ".target.m").is_dir())

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

	def test_published_target_cleanup_failure_preserves_primary_and_owned_roots(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source = root / "source"
			source.mkdir()
			target = root / "target"
			staging_root = root / ".target.m"
			snapshot = parallel_validation.CapturedWorkspace(
				source_root=source,
				head="1" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="2" * 64,
			)
			primary = parallel_validation.WorkspaceSnapshotError("late validation failed")
			cleanup_failure = parallel_validation.WorkspaceSnapshotError(
				"exact target cleanup was refused"
			)
			cleanup_calls: list[Path] = []

			def clone_then_checkout(
				_root: Path,
				arguments: list[str],
				**_kwargs: object,
			) -> bytes:
				if arguments[0] == "clone":
					(Path(arguments[-1]) / ".git").mkdir(parents=True)
				return b""

			def refuse_cleanup(path: Path, **_kwargs: object) -> None:
				cleanup_calls.append(path)
				raise cleanup_failure

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
					side_effect=(snapshot, primary),
				),
				mock.patch.object(
					parallel_validation,
					"_remove_owned_tree",
					side_effect=refuse_cleanup,
				),
			):
				with self.assertRaises(parallel_validation.WorkspaceSnapshotError) as raised:
					parallel_validation.materialize_workspace(
						snapshot,
						target,
						verify_source=False,
					)

			self.assertIs(raised.exception, primary)
			self.assertIs(raised.exception.__cause__, cleanup_failure)
			self.assertIs(raised.exception.cleanup_error, cleanup_failure)
			self.assertTrue(raised.exception.cleanup_debt)
			self.assertFalse(raised.exception.process_boundary_quiescent)
			self.assertEqual(raised.exception.preserved_paths, (target, staging_root))
			self.assertEqual(cleanup_calls, [target])
			self.assertTrue(target.is_dir())
			self.assertTrue(staging_root.is_dir())

	def test_missing_published_target_is_cleanup_debt(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source = root / "source"
			source.mkdir()
			target = root / "target"
			staging_root = root / ".target.m"
			staging_workspace = staging_root / "w"
			moved_target = root / "moved-target"
			snapshot = parallel_validation.CapturedWorkspace(
				source_root=source,
				head="1" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="2" * 64,
			)
			primary = parallel_validation.WorkspaceSnapshotError(
				"late published validation failed"
			)

			def clone_then_checkout(
				_root: Path,
				arguments: list[str],
				**_kwargs: object,
			) -> bytes:
				if arguments[0] == "clone":
					(Path(arguments[-1]) / ".git").mkdir(parents=True)
				return b""

			def capture_then_move(materialized_root: Path, **_kwargs: object) -> object:
				if materialized_root == staging_workspace:
					return snapshot
				target.rename(moved_target)
				raise primary

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
					side_effect=capture_then_move,
				),
			):
				with self.assertRaises(parallel_validation.WorkspaceSnapshotError) as raised:
					parallel_validation.materialize_workspace(
						snapshot,
						target,
						verify_source=False,
					)

			self.assertIs(raised.exception, primary)
			self.assertTrue(raised.exception.cleanup_debt)
			self.assertFalse(raised.exception.process_boundary_quiescent)
			self.assertTrue(moved_target.is_dir())
			self.assertTrue(staging_root.is_dir())

	def test_publication_move_then_control_retains_both_owned_roots(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source = root / "source"
			source.mkdir()
			target = root / "target"
			staging_root = root / ".target.m"
			snapshot = parallel_validation.CapturedWorkspace(
				source_root=source,
				head="1" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="2" * 64,
			)
			primary = KeyboardInterrupt("fixture publication interruption")
			real_replace = os.replace

			def clone_then_checkout(
				_root: Path,
				arguments: list[str],
				**_kwargs: object,
			) -> bytes:
				if arguments[0] == "clone":
					(Path(arguments[-1]) / ".git").mkdir(parents=True)
				return b""

			def move_then_interrupt(source_path: object, target_path: object) -> None:
				real_replace(source_path, target_path)
				raise primary

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
					return_value=snapshot,
				),
				mock.patch.object(
					parallel_validation.os,
					"replace",
					side_effect=move_then_interrupt,
				),
			):
				observed: BaseException | None = None
				try:
					parallel_validation.materialize_workspace(
						snapshot,
						target,
						verify_source=False,
					)
				except BaseException as error:
					observed = error

			self.assertIs(observed, primary)
			self.assertTrue(primary.cleanup_debt)
			self.assertFalse(primary.process_boundary_quiescent)
			self.assertEqual(primary.preserved_paths, (target, staging_root))
			self.assertTrue(target.is_dir())
			self.assertTrue(staging_root.is_dir())

	def test_missing_staging_root_blocks_successful_materialization_return(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source = root / "source"
			source.mkdir()
			target = root / "target"
			staging_root = root / ".target.m"
			moved_staging = root / "moved-staging"
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

			def move_staging(_identity: tuple[int, int, int]) -> None:
				staging_root.rename(moved_staging)

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
					return_value=snapshot,
				),
			):
				with self.assertRaises(
					parallel_validation.WorkspaceProcessBoundaryError
				) as raised:
					parallel_validation.materialize_workspace(
						snapshot,
						target,
						verify_source=False,
						identity_callback=move_staging,
					)

			self.assertTrue(raised.exception.cleanup_debt)
			self.assertFalse(raised.exception.process_boundary_quiescent)
			self.assertTrue(target.is_dir())
			self.assertTrue(moved_staging.is_dir())

	def test_staging_cleanup_failure_revokes_outer_cleanup_after_publication(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source = root / "source"
			source.mkdir()
			target = root / "target"
			staging_root = root / ".target.m"
			snapshot = parallel_validation.CapturedWorkspace(
				source_root=source,
				head="1" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="2" * 64,
			)
			cleanup_failure = parallel_validation.WorkspaceSnapshotError(
				"exact staging cleanup was refused"
			)

			def clone_then_checkout(
				_root: Path,
				arguments: list[str],
				**_kwargs: object,
			) -> bytes:
				if arguments[0] == "clone":
					(Path(arguments[-1]) / ".git").mkdir(parents=True)
				return b""

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
					side_effect=(snapshot, snapshot),
				),
				mock.patch.object(
					parallel_validation,
					"_remove_owned_tree",
					side_effect=cleanup_failure,
				) as remove_owned_tree,
			):
				with self.assertRaises(
					parallel_validation.WorkspaceProcessBoundaryError,
				) as raised:
					parallel_validation.materialize_workspace(
						snapshot,
						target,
						verify_source=False,
					)

			self.assertIs(raised.exception.__cause__, cleanup_failure)
			self.assertIs(raised.exception.cleanup_error, cleanup_failure)
			self.assertTrue(raised.exception.cleanup_debt)
			self.assertFalse(raised.exception.process_boundary_quiescent)
			self.assertEqual(raised.exception.preserved_paths, (target, staging_root))
			remove_owned_tree.assert_called_once_with(
				staging_root,
				expected_identity=mock.ANY,
			)
			self.assertTrue(target.is_dir())
			self.assertTrue(staging_root.is_dir())

	def test_staging_cleanup_debt_excludes_a_successfully_removed_target(self) -> None:
		with tempfile.TemporaryDirectory() as temporary_directory:
			root = Path(temporary_directory)
			source = root / "source"
			source.mkdir()
			target = root / "target"
			staging_root = root / ".target.m"
			snapshot = parallel_validation.CapturedWorkspace(
				source_root=source,
				head="1" * 40,
				binary_diff=b"",
				untracked_files=(),
				workspace_fingerprint="2" * 64,
			)
			primary = parallel_validation.WorkspaceSnapshotError("late validation failed")
			cleanup_failure = parallel_validation.WorkspaceSnapshotError(
				"exact staging cleanup was refused"
			)
			cleanup_calls: list[Path] = []
			real_remove_owned_tree = parallel_validation._remove_owned_tree

			def clone_then_checkout(
				_root: Path,
				arguments: list[str],
				**_kwargs: object,
			) -> bytes:
				if arguments[0] == "clone":
					(Path(arguments[-1]) / ".git").mkdir(parents=True)
				return b""

			def remove_target_then_refuse_staging(
				path: Path,
				*,
				expected_identity: os.stat_result | None,
			) -> None:
				cleanup_calls.append(path)
				if path == target:
					real_remove_owned_tree(path, expected_identity=expected_identity)
					return
				raise cleanup_failure

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
					side_effect=(snapshot, primary),
				),
				mock.patch.object(
					parallel_validation,
					"_remove_owned_tree",
					side_effect=remove_target_then_refuse_staging,
				),
			):
				with self.assertRaises(parallel_validation.WorkspaceSnapshotError) as raised:
					parallel_validation.materialize_workspace(
						snapshot,
						target,
						verify_source=False,
					)

			self.assertIs(raised.exception, primary)
			self.assertIs(raised.exception.__cause__, cleanup_failure)
			self.assertEqual(raised.exception.preserved_paths, (staging_root,))
			self.assertEqual(cleanup_calls, [target, staging_root])
			self.assertFalse(target.exists())
			self.assertTrue(staging_root.is_dir())

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
