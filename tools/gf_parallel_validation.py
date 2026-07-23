#!/usr/bin/env python3
"""Immutable workspace snapshots and bounded parallel validation helpers."""

from __future__ import annotations

import concurrent.futures
import hashlib
import math
import os
import re
import shutil
import stat
import subprocess
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from pathlib import PurePosixPath
from types import MappingProxyType
from typing import Callable
from typing import Iterable
from typing import Mapping

from gf_process_supervisor import run_supervised_process


FILE_ATTRIBUTE_REPARSE_POINT = 0x0400
GIT_TIMEOUT_SECONDS = 120
PARALLEL_POLL_SECONDS = 0.05
UNTRACKED_CAPTURE_CHUNK_BYTES = 1024 * 1024
MAX_CAPTURED_UNTRACKED_FILE_BYTES = 64 * 1024 * 1024
MAX_CAPTURED_UNTRACKED_TOTAL_BYTES = 256 * 1024 * 1024
WORKSPACE_FINGERPRINT_PREFIX = b"gf-maintenance-workspace-v1\0"
GIT_OBJECT_ID_PATTERN = re.compile(r"^[0-9a-f]{40}(?:[0-9a-f]{24})?$")


class WorkspaceSnapshotError(RuntimeError):
	"""Base error for fail-closed workspace snapshot operations."""


class UnsafeWorkspacePathError(WorkspaceSnapshotError):
	"""Raised when a workspace path can escape through a link or invalid name."""


class WorkspaceDriftError(WorkspaceSnapshotError):
	"""Raised when the source workspace no longer matches its captured state."""


class WorkspaceDeadlineError(WorkspaceSnapshotError):
	"""Raised when snapshot setup exhausts its owning suite deadline."""


@dataclass(frozen=True)
class CapturedWorkspaceFile:
	"""One untracked, non-ignored regular file captured as immutable bytes."""

	relative_path: str
	mode: int
	data: bytes

	@property
	def size_bytes(self) -> int:
		return len(self.data)


@dataclass(frozen=True)
class CapturedWorkspace:
	"""An immutable HEAD + binary diff + untracked workspace snapshot."""

	source_root: Path
	head: str
	binary_diff: bytes
	untracked_files: tuple[CapturedWorkspaceFile, ...]
	workspace_fingerprint: str

	@property
	def fingerprint(self) -> str:
		return self.workspace_fingerprint

	@property
	def dirty(self) -> bool:
		return bool(self.binary_diff or self.untracked_files)

	@property
	def untracked_file_count(self) -> int:
		return len(self.untracked_files)

	def workspace_state(self) -> dict[str, object]:
		return {
			"schema_version": 1,
			"head": self.head,
			"dirty": self.dirty,
			"untracked_file_count": self.untracked_file_count,
			"fingerprint": self.workspace_fingerprint,
		}


@dataclass(frozen=True)
class ParallelShard:
	"""One command whose working directory is private to that shard."""

	name: str
	command: tuple[str, ...]
	workspace: Path
	timeout_seconds: float
	environment: Mapping[str, str] | None = None

	def __post_init__(self) -> None:
		name = str(self.name).strip()
		if not name:
			raise ValueError("Parallel shard names must not be empty.")
		command = tuple(str(part) for part in self.command)
		if not command or any(not part or "\0" in part for part in command):
			raise ValueError(f"Parallel shard {name!r} has an invalid command.")
		timeout_seconds = float(self.timeout_seconds)
		if not math.isfinite(timeout_seconds) or timeout_seconds <= 0.0:
			raise ValueError(f"Parallel shard {name!r} must have a positive finite timeout.")
		environment = None
		if self.environment is not None:
			environment_copy = {str(key): str(value) for key, value in self.environment.items()}
			if any(not key or "\0" in key or "=" in key or "\0" in value for key, value in environment_copy.items()):
				raise ValueError(f"Parallel shard {name!r} has an invalid environment entry.")
			environment = MappingProxyType(environment_copy)
		object.__setattr__(self, "name", name)
		object.__setattr__(self, "command", command)
		object.__setattr__(self, "workspace", _absolute_lexical_path(Path(self.workspace)))
		object.__setattr__(self, "timeout_seconds", timeout_seconds)
		object.__setattr__(self, "environment", environment)

	@property
	def cwd(self) -> Path:
		return self.workspace


@dataclass(frozen=True)
class ParallelShardResult:
	"""Structured outcome for a parallel shard, including stable cancellation codes."""

	name: str
	command: tuple[str, ...]
	workspace: Path
	exit_code: int
	process_exit_code: int | None
	stdout: str
	stderr: str
	timed_out: bool
	cancelled: bool
	duration_seconds: float
	pid: int
	started: bool
	notes: tuple[str, ...] = ()

	@property
	def ok(self) -> bool:
		return self.started and self.exit_code == 0 and not self.timed_out and not self.cancelled

	@property
	def return_code(self) -> int:
		"""Stable aggregate code: 124 for timeout and 130 for cancellation."""
		return self.exit_code

	@property
	def status(self) -> str:
		if self.cancelled:
			return "cancelled"
		if self.timed_out:
			return "timed_out"
		if not self.started:
			return "not_started"
		return "passed" if self.exit_code == 0 else "failed"

	def to_dict(self) -> dict[str, object]:
		return {
			"name": self.name,
			"command": list(self.command),
			"workspace": str(self.workspace),
			"exit_code": self.exit_code,
			"process_exit_code": self.process_exit_code,
			"stdout": self.stdout,
			"stderr": self.stderr,
			"timed_out": self.timed_out,
			"cancelled": self.cancelled,
			"duration_seconds": self.duration_seconds,
			"pid": self.pid,
			"started": self.started,
			"status": self.status,
			"notes": list(self.notes),
		}


class _CancellationState:
	def __init__(self) -> None:
		self.event = threading.Event()
		self._reason = ""
		self._lock = threading.Lock()

	def cancel(self, reason: str) -> None:
		with self._lock:
			if not self._reason:
				self._reason = reason
			self.event.set()

	def reason(self) -> str:
		with self._lock:
			return self._reason


def capture_workspace(root: Path, *, deadline: float | None = None) -> CapturedWorkspace:
	"""Capture a stable Git workspace or fail when it changes during capture."""
	_check_deadline(deadline, "workspace capture")
	repository_root = _validate_repository_root(Path(root), deadline=deadline)
	first = _capture_workspace_once(repository_root, deadline=deadline)
	second = _capture_workspace_once(repository_root, deadline=deadline)
	if not _snapshots_have_identical_payload(first, second):
		raise WorkspaceDriftError("Git workspace changed while its immutable snapshot was being captured.")
	_check_deadline(deadline, "workspace capture")
	return second


def materialize_workspace(
	snapshot: CapturedWorkspace,
	target: Path,
	*,
	deadline: float | None = None,
	verify_source: bool = True,
) -> Path:
	"""Materialize a verified local shared clone of ``snapshot`` at ``target``."""
	_check_deadline(deadline, "workspace materialization")
	if not isinstance(snapshot, CapturedWorkspace):
		raise TypeError("snapshot must be a CapturedWorkspace instance.")
	source_root = _validate_repository_root(snapshot.source_root, deadline=deadline)
	target_path = _absolute_lexical_path(Path(target))
	if os.path.lexists(target_path):
		raise WorkspaceSnapshotError(f"Materialization target already exists: {target_path}")
	target_parent = target_path.parent
	if not target_parent.is_dir():
		raise WorkspaceSnapshotError(f"Materialization target parent does not exist: {target_parent}")
	_assert_path_has_no_link_components(target_parent)
	if _paths_overlap(source_root, target_path):
		raise UnsafeWorkspacePathError("Materialization target must not contain or be contained by the source workspace.")
	if verify_source:
		_assert_source_matches_snapshot(snapshot, deadline=deadline)

	staging_root = target_parent / f".{target_path.name}.m"
	try:
		staging_root.mkdir(exist_ok=False)
	except FileExistsError as error:
		raise WorkspaceSnapshotError(
			f"Materialization staging path already exists: {staging_root}"
		) from error
	staging_root_identity = staging_root.lstat()
	staging_workspace = staging_root / "w"
	published_workspace_identity: os.stat_result | None = None
	published = False
	try:
		_run_git(
			target_parent,
			[
				"clone",
				"--quiet",
				"--shared",
				"--no-checkout",
				"--",
				str(source_root),
				str(staging_workspace),
			],
			deadline=deadline,
		)
		_assert_path_has_no_link_components(staging_workspace)
		published_workspace_identity = staging_workspace.lstat()
		empty_hooks = staging_workspace / ".git" / "gf-empty-hooks"
		empty_hooks.mkdir()
		_run_git(
			staging_workspace,
			[
				"-c",
				f"core.hooksPath={empty_hooks}",
				"checkout",
				"--quiet",
				"--detach",
				"--force",
				snapshot.head,
				"--",
			],
			deadline=deadline,
		)
		_validate_workspace_tree_safety(staging_workspace, snapshot.head, deadline=deadline)
		if snapshot.binary_diff:
			_run_git(
				staging_workspace,
				["apply", "--binary", "--whitespace=nowarn"],
				input_bytes=snapshot.binary_diff,
				deadline=deadline,
			)
		_materialize_untracked_files(staging_workspace, snapshot.untracked_files)
		_check_deadline(deadline, "workspace materialization")
		_validate_workspace_tree_safety(staging_workspace, snapshot.head, deadline=deadline)
		materialized = _capture_workspace_once(staging_workspace, deadline=deadline)
		if not _snapshots_have_identical_payload(snapshot, materialized):
			raise WorkspaceSnapshotError(
				"Materialized workspace does not reproduce the captured workspace fingerprint."
			)
		if verify_source:
			_assert_source_matches_snapshot(snapshot, deadline=deadline)
		if not _same_owned_directory_identity(
			published_workspace_identity,
			staging_workspace.lstat(),
		):
			raise WorkspaceSnapshotError("Materialized workspace identity changed before publication.")
		os.replace(staging_workspace, target_path)
		published = True
		_assert_path_has_no_link_components(target_path)
		if not _same_owned_directory_identity(
			published_workspace_identity,
			target_path.lstat(),
		):
			raise WorkspaceSnapshotError("Published workspace identity differs from its staging directory.")
		if verify_source:
			_assert_source_matches_snapshot(snapshot, deadline=deadline)
		published_snapshot = _capture_workspace_once(target_path, deadline=deadline)
		if not _snapshots_have_identical_payload(snapshot, published_snapshot):
			raise WorkspaceSnapshotError("Published workspace drifted during materialization.")
		_check_deadline(deadline, "workspace materialization")
		return target_path
	except BaseException:
		if published and os.path.lexists(target_path):
			_remove_owned_tree(target_path, expected_identity=published_workspace_identity)
		raise
	finally:
		if os.path.lexists(staging_root):
			_remove_owned_tree(staging_root, expected_identity=staging_root_identity)


def assert_source_matches_snapshot(
	snapshot: CapturedWorkspace,
	*,
	deadline: float | None = None,
) -> None:
	"""Verify one captured source at an orchestration boundary."""
	if not isinstance(snapshot, CapturedWorkspace):
		raise TypeError("snapshot must be a CapturedWorkspace instance.")
	_assert_source_matches_snapshot(snapshot, deadline=deadline)


def run_parallel_shards(
	shards: Iterable[ParallelShard],
	*,
	max_workers: int = 4,
	deadline_seconds: float | None = None,
	fail_fast: bool = False,
	cancellation_event: threading.Event | None = None,
	output_callback: Callable[[str, str, str], None] | None = None,
) -> list[ParallelShardResult]:
	"""Run isolated shard commands with bounded workers and cooperative cancellation."""
	shard_list = list(shards)
	if not shard_list:
		return []
	if isinstance(max_workers, bool) or not isinstance(max_workers, int) or max_workers <= 0:
		raise ValueError("max_workers must be a positive integer.")
	if deadline_seconds is not None:
		deadline_seconds = float(deadline_seconds)
		if not math.isfinite(deadline_seconds) or deadline_seconds < 0.0:
			raise ValueError("deadline_seconds must be a non-negative finite duration.")
	_validate_parallel_shards(shard_list)

	started = time.perf_counter()
	deadline = started + deadline_seconds if deadline_seconds is not None else None
	cancellation = _CancellationState()
	results: list[ParallelShardResult | None] = [None] * len(shard_list)
	next_index = 0
	in_flight: dict[concurrent.futures.Future[ParallelShardResult], int] = {}
	executor = concurrent.futures.ThreadPoolExecutor(
		max_workers=min(max_workers, len(shard_list)),
		thread_name_prefix="gf-validation-shard",
	)

	def observe_cancellation() -> None:
		if cancellation.event.is_set():
			return
		if cancellation_event is not None and cancellation_event.is_set():
			cancellation.cancel("external cancellation was requested")
			return
		if deadline is not None and time.perf_counter() >= deadline:
			cancellation.cancel("the parallel deadline was exhausted")

	def submit_available() -> None:
		nonlocal next_index
		observe_cancellation()
		while (
			next_index < len(shard_list)
			and len(in_flight) < max_workers
			and not cancellation.event.is_set()
		):
			index = next_index
			next_index += 1
			future = executor.submit(
				_run_parallel_shard,
				shard_list[index],
				cancellation,
				deadline,
				output_callback,
			)
			in_flight[future] = index

	try:
		submit_available()
		while in_flight:
			observe_cancellation()
			if cancellation.event.is_set():
				for future in in_flight:
					future.cancel()
			done, _pending = concurrent.futures.wait(
				tuple(in_flight),
				timeout=PARALLEL_POLL_SECONDS,
				return_when=concurrent.futures.FIRST_COMPLETED,
			)
			for future in done:
				index = in_flight.pop(future)
				if future.cancelled():
					result = _not_started_result(shard_list[index], cancellation.reason())
				else:
					result = future.result()
				results[index] = result
				if fail_fast and not result.ok and not cancellation.event.is_set():
					cancellation.cancel(f"fail-fast followed shard {result.name!r}")
			submit_available()
	except BaseException:
		cancellation.cancel("the parallel runner was interrupted")
		for future in in_flight:
			future.cancel()
		executor.shutdown(wait=True, cancel_futures=True)
		raise
	else:
		executor.shutdown(wait=True, cancel_futures=True)

	reason = cancellation.reason()
	for index, result in enumerate(results):
		if result is None:
			results[index] = _not_started_result(shard_list[index], reason)
	return [result for result in results if result is not None]


def _capture_workspace_once(root: Path, *, deadline: float | None = None) -> CapturedWorkspace:
	_check_deadline(deadline, "workspace capture")
	head = _read_head(root, deadline=deadline)
	_validate_workspace_tree_safety(root, head, deadline=deadline)
	binary_diff = _run_git(
		root,
		["diff", "--binary", "--no-ext-diff", "HEAD", "--"],
		deadline=deadline,
	)
	untracked_paths = _read_untracked_paths(root, deadline=deadline)
	_validate_relative_path_set(untracked_paths)
	captured_untracked_files: list[CapturedWorkspaceFile] = []
	captured_untracked_bytes = 0
	for relative_path in untracked_paths:
		captured_file = _capture_untracked_file(root, relative_path, deadline=deadline)
		captured_untracked_bytes += captured_file.size_bytes
		if captured_untracked_bytes > MAX_CAPTURED_UNTRACKED_TOTAL_BYTES:
			raise WorkspaceSnapshotError(
				"Untracked workspace files exceed the "
				f"{MAX_CAPTURED_UNTRACKED_TOTAL_BYTES}-byte total capture limit."
			)
		captured_untracked_files.append(captured_file)
	untracked_files = tuple(captured_untracked_files)
	if _read_head(root, deadline=deadline) != head:
		raise WorkspaceDriftError("Git HEAD changed while the workspace was being captured.")
	fingerprint = _fingerprint_captured_payload(head, binary_diff, untracked_files)
	return CapturedWorkspace(
		source_root=root,
		head=head,
		binary_diff=binary_diff,
		untracked_files=untracked_files,
		workspace_fingerprint=fingerprint,
	)


def _read_head(root: Path, *, deadline: float | None = None) -> str:
	head = _run_git(
		root,
		["rev-parse", "--verify", "HEAD^{commit}"],
		deadline=deadline,
	).decode("ascii", errors="strict").strip()
	if not GIT_OBJECT_ID_PATTERN.fullmatch(head):
		raise WorkspaceSnapshotError(f"Git returned an invalid HEAD object id: {head!r}")
	return head


def _read_untracked_paths(root: Path, *, deadline: float | None = None) -> list[str]:
	payload = _run_git(
		root,
		["ls-files", "--others", "--exclude-standard", "-z"],
		deadline=deadline,
	)
	paths = _decode_nul_paths(payload, "untracked file list")
	return sorted(paths)


def _capture_untracked_file(
	root: Path,
	relative_path: str,
	*,
	deadline: float | None = None,
) -> CapturedWorkspaceFile:
	_check_deadline(deadline, "untracked workspace capture")
	path = _workspace_path(root, relative_path)
	_assert_path_has_no_link_components(path)
	chain_before = _snapshot_real_directory_chain(path.parent, deadline=deadline)
	try:
		before = path.lstat()
	except OSError as exc:
		raise WorkspaceDriftError(f"Could not inspect untracked file {relative_path!r}: {exc}") from exc
	if not stat.S_ISREG(before.st_mode) or _stat_is_reparse(before):
		raise UnsafeWorkspacePathError(f"Untracked workspace entry is not a regular file: {relative_path}")
	if before.st_size > MAX_CAPTURED_UNTRACKED_FILE_BYTES:
		raise WorkspaceSnapshotError(
			f"Untracked workspace file exceeds the {MAX_CAPTURED_UNTRACKED_FILE_BYTES}-byte "
			f"capture limit: {relative_path}"
		)
	flags = (
		os.O_RDONLY
		| getattr(os, "O_BINARY", 0)
		| getattr(os, "O_CLOEXEC", 0)
		| getattr(os, "O_NOFOLLOW", 0)
	)
	try:
		file_descriptor = os.open(path, flags)
	except OSError as exc:
		raise WorkspaceDriftError(f"Could not open untracked file {relative_path!r}: {exc}") from exc
	payload = bytearray()
	try:
		try:
			opened_before = os.fstat(file_descriptor)
			if (
				not stat.S_ISREG(opened_before.st_mode)
				or _stat_is_reparse(opened_before)
				or not _same_open_file_identity(before, opened_before)
			):
				raise WorkspaceDriftError(
					f"Untracked file changed while it was being opened: {relative_path}"
				)
			chain_opened = _snapshot_real_directory_chain(path.parent, deadline=deadline)
			if not _same_directory_chain_identity(chain_before, chain_opened):
				raise WorkspaceDriftError(
					f"Untracked file parent directory chain changed while opening: {relative_path}"
				)
			while len(payload) <= MAX_CAPTURED_UNTRACKED_FILE_BYTES:
				_check_deadline(deadline, "untracked workspace file reading")
				chunk = os.read(
					file_descriptor,
					min(
						UNTRACKED_CAPTURE_CHUNK_BYTES,
						MAX_CAPTURED_UNTRACKED_FILE_BYTES + 1 - len(payload),
					),
				)
				_check_deadline(deadline, "untracked workspace file reading")
				if not chunk:
					break
				payload.extend(chunk)
			opened_after = os.fstat(file_descriptor)
		except OSError as exc:
			raise WorkspaceDriftError(
				f"Could not capture untracked file {relative_path!r}: {exc}"
			) from exc
	finally:
		os.close(file_descriptor)
	if len(payload) > MAX_CAPTURED_UNTRACKED_FILE_BYTES:
		raise WorkspaceSnapshotError(
			f"Untracked workspace file exceeds the {MAX_CAPTURED_UNTRACKED_FILE_BYTES}-byte "
			f"capture limit: {relative_path}"
		)
	try:
		after = path.lstat()
	except OSError as exc:
		raise WorkspaceDriftError(
			f"Could not re-inspect untracked file {relative_path!r}: {exc}"
		) from exc
	chain_after = _snapshot_real_directory_chain(path.parent, deadline=deadline)
	if (
		not _same_directory_chain_identity(chain_before, chain_after)
		or not _same_file_snapshot(before, after)
		or not _same_file_snapshot(opened_before, opened_after)
		or not _same_open_file_identity(opened_after, after)
		or len(payload) != before.st_size
		or len(payload) != opened_after.st_size
		or not stat.S_ISREG(after.st_mode)
		or _stat_is_reparse(after)
	):
		raise WorkspaceDriftError(f"Untracked file changed while being captured: {relative_path}")
	_check_deadline(deadline, "untracked workspace capture")
	return CapturedWorkspaceFile(relative_path=relative_path, mode=before.st_mode, data=bytes(payload))


def _fingerprint_captured_payload(
	head: str,
	binary_diff: bytes,
	untracked_files: tuple[CapturedWorkspaceFile, ...],
) -> str:
	digest = hashlib.sha256()
	digest.update(WORKSPACE_FINGERPRINT_PREFIX)
	digest.update(head.encode("utf-8"))
	digest.update(b"\0diff\0")
	digest.update(binary_diff)
	for captured_file in untracked_files:
		digest.update(b"\0untracked\0")
		digest.update(captured_file.relative_path.encode("utf-8", errors="surrogateescape"))
		digest.update(
			f"\0mode={captured_file.mode:o}\0size={captured_file.size_bytes}\0".encode("ascii")
		)
		digest.update(captured_file.data)
	return digest.hexdigest()


def _snapshots_have_identical_payload(left: CapturedWorkspace, right: CapturedWorkspace) -> bool:
	return (
		left.head == right.head
		and left.binary_diff == right.binary_diff
		and left.untracked_files == right.untracked_files
		and left.workspace_fingerprint == right.workspace_fingerprint
	)


def _assert_source_matches_snapshot(
	snapshot: CapturedWorkspace,
	*,
	deadline: float | None = None,
) -> None:
	current = _capture_workspace_once(snapshot.source_root, deadline=deadline)
	if not _snapshots_have_identical_payload(snapshot, current):
		raise WorkspaceDriftError(
			"Source Git workspace drifted after capture; refusing to materialize a mixed revision."
		)


def _materialize_untracked_files(
	root: Path,
	untracked_files: tuple[CapturedWorkspaceFile, ...],
) -> None:
	for captured_file in untracked_files:
		path = _workspace_path(root, captured_file.relative_path)
		_create_safe_parent_directories(root, path.parent)
		_assert_path_has_no_link_components(path.parent)
		flags = os.O_CREAT | os.O_EXCL | os.O_WRONLY | getattr(os, "O_BINARY", 0)
		if hasattr(os, "O_NOFOLLOW"):
			flags |= os.O_NOFOLLOW
		try:
			file_descriptor = os.open(path, flags, stat.S_IMODE(captured_file.mode))
		except OSError as exc:
			raise WorkspaceSnapshotError(
				f"Could not create captured untracked file {captured_file.relative_path!r}: {exc}"
			) from exc
		try:
			with os.fdopen(file_descriptor, "wb") as output_file:
				output_file.write(captured_file.data)
		except BaseException:
			try:
				os.close(file_descriptor)
			except OSError:
				pass
			raise
		try:
			os.chmod(path, stat.S_IMODE(captured_file.mode), follow_symlinks=False)
		except (NotImplementedError, OSError) as exc:
			raise WorkspaceSnapshotError(
				f"Could not restore mode for untracked file {captured_file.relative_path!r}: {exc}"
			) from exc
		_assert_path_has_no_link_components(path)


def _create_safe_parent_directories(root: Path, parent: Path) -> None:
	try:
		relative = parent.relative_to(root)
	except ValueError as exc:
		raise UnsafeWorkspacePathError(f"Workspace path escapes its root: {parent}") from exc
	current = root
	for part in relative.parts:
		current /= part
		try:
			metadata = current.lstat()
		except FileNotFoundError:
			current.mkdir()
			metadata = current.lstat()
		except OSError as exc:
			raise WorkspaceSnapshotError(f"Could not inspect workspace directory {current}: {exc}") from exc
		if not stat.S_ISDIR(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode) or _stat_is_reparse(metadata):
			raise UnsafeWorkspacePathError(f"Unsafe workspace directory component: {current}")


def _validate_repository_root(root: Path, *, deadline: float | None = None) -> Path:
	_check_deadline(deadline, "repository validation")
	root_path = _absolute_lexical_path(root)
	if not root_path.is_dir():
		raise WorkspaceSnapshotError(f"Git workspace root does not exist: {root_path}")
	_assert_path_has_no_link_components(root_path)
	reported_root = _run_git(
		root_path,
		["rev-parse", "--show-toplevel"],
		deadline=deadline,
	).decode(
		"utf-8",
		errors="surrogateescape",
	).strip()
	reported_path = _absolute_lexical_path(Path(reported_root))
	if os.path.normcase(str(reported_path)) != os.path.normcase(str(root_path)):
		raise WorkspaceSnapshotError(
			f"Expected repository root {root_path}, but Git reported {reported_path}."
		)
	return root_path


def _validate_workspace_tree_safety(
	root: Path,
	head: str,
	*,
	deadline: float | None = None,
) -> None:
	_check_deadline(deadline, "workspace safety validation")
	tracked_paths: list[str] = []
	head_entries = _run_git(
		root,
		["ls-tree", "-r", "-z", "--full-tree", head],
		deadline=deadline,
	)
	for entry in _split_nul_records(head_entries, "HEAD tree"):
		try:
			header, path_bytes = entry.split(b"\t", 1)
			mode, object_type, _object_id = header.split(b" ", 2)
		except ValueError as exc:
			raise WorkspaceSnapshotError("Git returned a malformed HEAD tree entry.") from exc
		relative_path = path_bytes.decode("utf-8", errors="surrogateescape")
		_validate_relative_path(relative_path)
		if mode not in {b"100644", b"100755"} or object_type != b"blob":
			raise UnsafeWorkspacePathError(
				f"Workspace snapshots reject links, gitlinks, and special tracked entries: {relative_path}"
			)
		tracked_paths.append(relative_path)

	index_entries = _run_git(root, ["ls-files", "--stage", "-z"], deadline=deadline)
	for entry in _split_nul_records(index_entries, "Git index"):
		try:
			header, path_bytes = entry.split(b"\t", 1)
			mode, _object_id, stage = header.split(b" ", 2)
		except ValueError as exc:
			raise WorkspaceSnapshotError("Git returned a malformed index entry.") from exc
		relative_path = path_bytes.decode("utf-8", errors="surrogateescape")
		_validate_relative_path(relative_path)
		if stage != b"0":
			raise WorkspaceSnapshotError(f"Workspace snapshots reject unmerged index entries: {relative_path}")
		if mode not in {b"100644", b"100755"}:
			raise UnsafeWorkspacePathError(
				f"Workspace snapshots reject links, gitlinks, and special index entries: {relative_path}"
			)
		tracked_paths.append(relative_path)

	_validate_relative_path_set(tracked_paths)
	_validate_tracked_path_components(root, set(tracked_paths))
	_check_deadline(deadline, "workspace safety validation")


def _validate_tracked_path_components(root: Path, relative_paths: set[str]) -> None:
	"""Inspect each existing worktree component once, including reparse metadata."""
	_assert_path_has_no_link_components(root)
	inspected: set[str] = set()
	for relative_path in relative_paths:
		current = root
		for part in relative_path.split("/"):
			current /= part
			key = os.path.normcase(str(current))
			if key in inspected:
				continue
			inspected.add(key)
			try:
				metadata = current.lstat()
			except FileNotFoundError:
				break
			except OSError as exc:
				raise UnsafeWorkspacePathError(f"Could not inspect path component {current}: {exc}") from exc
			if stat.S_ISLNK(metadata.st_mode) or _stat_is_reparse(metadata):
				raise UnsafeWorkspacePathError(f"Path contains a link or reparse point: {current}")


def _validate_relative_path_set(paths: Iterable[str]) -> None:
	seen: dict[str, str] = {}
	for relative_path in paths:
		_validate_relative_path(relative_path)
		key = os.path.normcase(str(Path(*relative_path.split("/"))))
		previous = seen.get(key)
		if previous is not None and previous != relative_path:
			raise UnsafeWorkspacePathError(
				f"Workspace paths collide on this filesystem: {previous!r} and {relative_path!r}"
			)
		seen[key] = relative_path


def _validate_relative_path(relative_path: str) -> None:
	if not relative_path or "\0" in relative_path or "\\" in relative_path:
		raise UnsafeWorkspacePathError(f"Invalid workspace-relative path: {relative_path!r}")
	parts = relative_path.split("/")
	path = PurePosixPath(relative_path)
	if (
		path.is_absolute()
		or any(part in {"", ".", ".."} for part in parts)
		or any(part.casefold() == ".git" for part in parts)
		or re.match(r"^[A-Za-z]:", parts[0]) is not None
	):
		raise UnsafeWorkspacePathError(f"Unsafe workspace-relative path: {relative_path!r}")


def _workspace_path(root: Path, relative_path: str) -> Path:
	_validate_relative_path(relative_path)
	path = _absolute_lexical_path(root.joinpath(*relative_path.split("/")))
	try:
		common = os.path.commonpath((str(root), str(path)))
	except ValueError as exc:
		raise UnsafeWorkspacePathError(f"Workspace path escapes its root: {relative_path!r}") from exc
	if os.path.normcase(common) != os.path.normcase(str(root)) or path == root:
		raise UnsafeWorkspacePathError(f"Workspace path escapes its root: {relative_path!r}")
	return path


def _assert_path_has_no_link_components(path: Path) -> None:
	current = _absolute_lexical_path(path)
	while True:
		try:
			metadata = current.lstat()
		except FileNotFoundError:
			pass
		except OSError as exc:
			raise UnsafeWorkspacePathError(f"Could not inspect path component {current}: {exc}") from exc
		else:
			if stat.S_ISLNK(metadata.st_mode) or _stat_is_reparse(metadata):
				raise UnsafeWorkspacePathError(f"Path contains a link or reparse point: {current}")
		if current == current.parent:
			return
		current = current.parent


def _snapshot_real_directory_chain(
	directory: Path,
	*,
	deadline: float | None = None,
) -> tuple[tuple[Path, os.stat_result], ...]:
	"""Pin every real parent directory identity from the filesystem root."""
	current = _absolute_lexical_path(directory)
	reversed_snapshot: list[tuple[Path, os.stat_result]] = []
	while True:
		_check_deadline(deadline, "untracked workspace parent directory inspection")
		try:
			metadata = current.lstat()
		except OSError as exc:
			raise WorkspaceDriftError(
				f"Could not inspect untracked workspace parent directory {current}: {exc}"
			) from exc
		if (
			not stat.S_ISDIR(metadata.st_mode)
			or stat.S_ISLNK(metadata.st_mode)
			or _stat_is_reparse(metadata)
			or not _same_owned_directory_identity(metadata, metadata)
		):
			raise UnsafeWorkspacePathError(
				f"Untracked workspace path crosses an unsafe or identity-less directory: {current}"
			)
		reversed_snapshot.append((current, metadata))
		if current == current.parent:
			break
		current = current.parent
	reversed_snapshot.reverse()
	return tuple(reversed_snapshot)


def _same_directory_chain_identity(
	left: tuple[tuple[Path, os.stat_result], ...],
	right: tuple[tuple[Path, os.stat_result], ...],
) -> bool:
	return (
		len(left) == len(right)
		and all(
			left_path == right_path
			and _same_owned_directory_identity(left_metadata, right_metadata)
			for (left_path, left_metadata), (right_path, right_metadata) in zip(left, right)
		)
	)


def _same_file_snapshot(left: os.stat_result, right: os.stat_result) -> bool:
	return (
		left.st_mode == right.st_mode
		and left.st_size == right.st_size
		and left.st_mtime_ns == right.st_mtime_ns
		and left.st_ctime_ns == right.st_ctime_ns
		and int(getattr(left, "st_dev", 0)) == int(getattr(right, "st_dev", 0))
		and int(getattr(left, "st_ino", 0)) == int(getattr(right, "st_ino", 0))
		and int(getattr(left, "st_file_attributes", 0))
		== int(getattr(right, "st_file_attributes", 0))
	)


def _same_open_file_identity(left: os.stat_result, right: os.stat_result) -> bool:
	left_device = int(getattr(left, "st_dev", 0))
	left_inode = int(getattr(left, "st_ino", 0))
	return (
		stat.S_ISREG(left.st_mode)
		and stat.S_ISREG(right.st_mode)
		and left.st_mode == right.st_mode
		and left.st_size == right.st_size
		and (left_device != 0 or left_inode != 0)
		and left_device == int(getattr(right, "st_dev", 0))
		and left_inode == int(getattr(right, "st_ino", 0))
	)


def _stat_is_reparse(metadata: os.stat_result) -> bool:
	return bool(int(getattr(metadata, "st_file_attributes", 0)) & FILE_ATTRIBUTE_REPARSE_POINT)


def _absolute_lexical_path(path: Path) -> Path:
	return Path(os.path.abspath(os.fspath(path.expanduser())))


def _paths_overlap(left: Path, right: Path) -> bool:
	try:
		common = os.path.commonpath((str(left), str(right)))
	except ValueError:
		return False
	normalized_common = os.path.normcase(common)
	return normalized_common in {os.path.normcase(str(left)), os.path.normcase(str(right))}


def _decode_nul_paths(payload: bytes, description: str) -> list[str]:
	return [record.decode("utf-8", errors="surrogateescape") for record in _split_nul_records(payload, description)]


def _split_nul_records(payload: bytes, description: str) -> list[bytes]:
	if not payload:
		return []
	if not payload.endswith(b"\0"):
		raise WorkspaceSnapshotError(f"Git returned a malformed {description}.")
	records = payload[:-1].split(b"\0")
	if any(not record for record in records):
		raise WorkspaceSnapshotError(f"Git returned an empty record in its {description}.")
	return records


def _run_git(
	root: Path,
	arguments: list[str],
	*,
	input_bytes: bytes | None = None,
	deadline: float | None = None,
) -> bytes:
	timeout_seconds = _remaining_timeout(deadline, "git workspace operation")
	environment = os.environ.copy()
	environment["GIT_OPTIONAL_LOCKS"] = "0"
	try:
		completed = subprocess.run(
			["git", *arguments],
			cwd=root,
			input=input_bytes,
			stdout=subprocess.PIPE,
			stderr=subprocess.PIPE,
			check=False,
			timeout=min(GIT_TIMEOUT_SECONDS, timeout_seconds),
			env=environment,
		)
	except subprocess.TimeoutExpired as exc:
		if deadline is not None and time.perf_counter() >= deadline:
			raise WorkspaceDeadlineError(
				f"Suite deadline exhausted while running git {' '.join(arguments)}."
			) from exc
		raise WorkspaceSnapshotError(f"Could not run git {' '.join(arguments)}: {exc}") from exc
	except OSError as exc:
		raise WorkspaceSnapshotError(f"Could not run git {' '.join(arguments)}: {exc}") from exc
	if completed.returncode != 0:
		message = completed.stderr.decode("utf-8", errors="replace").strip()
		raise WorkspaceSnapshotError(
			f"git {' '.join(arguments)} failed with exit code {completed.returncode}: {message}"
		)
	return completed.stdout


def _remaining_timeout(deadline: float | None, operation: str) -> float:
	if deadline is None:
		return float(GIT_TIMEOUT_SECONDS)
	remaining = deadline - time.perf_counter()
	if remaining <= 0.0:
		raise WorkspaceDeadlineError(f"Suite deadline exhausted during {operation}.")
	return max(0.001, remaining)


def _check_deadline(deadline: float | None, operation: str) -> None:
	if deadline is not None and time.perf_counter() >= deadline:
		raise WorkspaceDeadlineError(f"Suite deadline exhausted during {operation}.")


def _remove_owned_tree(
	path: Path,
	*,
	expected_identity: os.stat_result | None,
) -> None:
	_assert_path_has_no_link_components(path.parent)
	metadata = path.lstat()
	if (
		not stat.S_ISDIR(metadata.st_mode)
		or stat.S_ISLNK(metadata.st_mode)
		or _stat_is_reparse(metadata)
	):
		raise UnsafeWorkspacePathError(f"Refusing to clean an unsafe materialization path: {path}")
	if expected_identity is None or not _same_owned_directory_identity(expected_identity, metadata):
		raise UnsafeWorkspacePathError(f"Refusing to clean a replaced materialization path: {path}")
	cleanup_path: Path | str = path
	if os.name == "nt" and not str(path).startswith("\\\\?\\"):
		cleanup_path = "\\\\?\\" + str(path)
	last_error: OSError | None = None
	for attempt in range(8):
		try:
			shutil.rmtree(cleanup_path, onexc=_make_remove_writable)
			return
		except FileNotFoundError:
			return
		except OSError as error:
			last_error = error
		time.sleep(min(0.1 * (2 ** attempt), 1.0))
	raise WorkspaceSnapshotError(
		f"Could not clean owned materialization path after bounded retries: {path}: {last_error}"
	)


def _same_owned_directory_identity(left: os.stat_result, right: os.stat_result) -> bool:
	left_device = int(getattr(left, "st_dev", 0))
	left_inode = int(getattr(left, "st_ino", 0))
	return (
		stat.S_ISDIR(left.st_mode)
		and stat.S_ISDIR(right.st_mode)
		and left.st_mode == right.st_mode
		and (left_device != 0 or left_inode != 0)
		and left_device == int(getattr(right, "st_dev", 0))
		and left_inode == int(getattr(right, "st_ino", 0))
	)


def _make_remove_writable(function: Callable[[str], object], path: str, error: BaseException) -> None:
	try:
		os.chmod(path, stat.S_IWRITE)
		function(path)
	except OSError:
		raise error


def _validate_parallel_shards(shards: list[ParallelShard]) -> None:
	seen_names: set[str] = set()
	for shard in shards:
		if not isinstance(shard, ParallelShard):
			raise TypeError("run_parallel_shards accepts only ParallelShard instances.")
		if shard.name in seen_names:
			raise ValueError(f"Parallel shard names must be unique: {shard.name!r}")
		seen_names.add(shard.name)
		if not shard.workspace.is_dir():
			raise ValueError(f"Parallel shard workspace does not exist: {shard.workspace}")
		_assert_path_has_no_link_components(shard.workspace)
	for index, left in enumerate(shards):
		for right in shards[index + 1:]:
			if _paths_overlap(left.workspace, right.workspace):
				raise ValueError(
					f"Parallel shard workspaces must be isolated: {left.workspace} and {right.workspace}"
				)


def _run_parallel_shard(
	shard: ParallelShard,
	cancellation: _CancellationState,
	deadline: float | None,
	output_callback: Callable[[str, str, str], None] | None,
) -> ParallelShardResult:
	started = time.perf_counter()
	if cancellation.event.is_set():
		return _not_started_result(shard, cancellation.reason())
	remaining = deadline - started if deadline is not None else None
	if remaining is not None and remaining <= 0.0:
		return _not_started_result(shard, "the parallel deadline was exhausted")
	effective_timeout = min(shard.timeout_seconds, remaining) if remaining is not None else shard.timeout_seconds
	try:
		process_result = run_supervised_process(
			list(shard.command),
			cwd=shard.workspace,
			timeout_seconds=effective_timeout,
			environment=dict(shard.environment) if shard.environment is not None else None,
			stdout_callback=(
				(lambda line: output_callback(shard.name, "stdout", line))
				if output_callback is not None
				else None
			),
			stderr_callback=(
				(lambda line: output_callback(shard.name, "stderr", line))
				if output_callback is not None
				else None
			),
			heartbeat_callback=(
				(lambda elapsed, pid: output_callback(
					shard.name,
					"heartbeat",
					f"still running elapsed={elapsed:.1f}s pid={pid}",
				))
				if output_callback is not None
				else None
			),
			cancellation_event=cancellation.event,
		)
	except OSError as exc:
		return ParallelShardResult(
			name=shard.name,
			command=shard.command,
			workspace=shard.workspace,
			exit_code=127,
			process_exit_code=None,
			stdout="",
			stderr=str(exc),
			timed_out=False,
			cancelled=False,
			duration_seconds=time.perf_counter() - started,
			pid=0,
			started=False,
			notes=(f"Could not start shard command: {exc}",),
		)

	reason = cancellation.reason()
	deadline_cancelled = process_result.cancelled and reason == "the parallel deadline was exhausted"
	cancelled = process_result.cancelled and not deadline_cancelled
	timed_out = process_result.timed_out or deadline_cancelled
	exit_code = 130 if cancelled else (124 if timed_out else process_result.return_code)
	notes = list(process_result.notes)
	if process_result.cancelled and reason:
		notes.append(f"Parallel runner cancellation reason: {reason}.")
	return ParallelShardResult(
		name=shard.name,
		command=shard.command,
		workspace=shard.workspace,
		exit_code=exit_code,
		process_exit_code=process_result.return_code,
		stdout=process_result.stdout,
		stderr=process_result.stderr,
		timed_out=timed_out,
		cancelled=cancelled,
		duration_seconds=process_result.duration_seconds,
		pid=process_result.pid,
		started=process_result.pid > 0,
		notes=tuple(notes),
	)


def _not_started_result(shard: ParallelShard, reason: str) -> ParallelShardResult:
	deadline_exhausted = reason == "the parallel deadline was exhausted"
	cancelled = not deadline_exhausted
	effective_reason = reason or "the shard was not scheduled"
	return ParallelShardResult(
		name=shard.name,
		command=shard.command,
		workspace=shard.workspace,
		exit_code=124 if deadline_exhausted else 130,
		process_exit_code=None,
		stdout="",
		stderr="",
		timed_out=deadline_exhausted,
		cancelled=cancelled,
		duration_seconds=0.0,
		pid=0,
		started=False,
		notes=(f"Shard did not start because {effective_reason}.",),
	)
