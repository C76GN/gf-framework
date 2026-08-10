#!/usr/bin/env python3
"""Safely check, plan, or apply the GF addon snapshot in a reference project."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from generated_output_transaction import lexical_absolute_path
from generated_output_transaction import path_is_link_or_junction
from generated_output_transaction import replace_generated_trees
from generated_output_transaction import validate_controlled_path
from generated_output_transaction import validate_generated_entries


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path("addons/gf")
DEFAULT_PROJECT_ROOT = Path("../gf-reference-project")
PROJECT_PATH_ENV_VAR = "GF_REFERENCE_PROJECT_PATH"
SCHEMA_VERSION = 2
READ_CHUNK_BYTES = 1024 * 1024
BLOCKED_DIR_NAMES = {
	".git",
	".godot",
	".import",
	".mypy_cache",
	".pytest_cache",
	".vs",
	"__pycache__",
	"node_modules",
}
BLOCKED_FILE_NAMES = {
	".DS_Store",
	"Thumbs.db",
}
BLOCKED_SUFFIXES = {
	".import",
	".log",
	".pyc",
	".pyo",
	".tmp",
}


@dataclass(frozen=True)
class SyncLimits:
	max_entries: int = 8192
	max_file_bytes: int = 64 * 1024 * 1024
	max_total_bytes: int = 256 * 1024 * 1024
	max_mismatches: int = 80
	deadline_seconds: float = 120.0


DEFAULT_LIMITS = SyncLimits()


class ReferenceSyncError(RuntimeError):
	"""A stable, path-redacted reference synchronization failure."""

	def __init__(self, rule_id: str, message: str) -> None:
		self.rule_id = rule_id
		self.message = message
		super().__init__(f"{rule_id}: {message}")


@dataclass(frozen=True)
class TreeEntry:
	relative_path: str
	kind: str
	path: Path
	identity: tuple[int, int, int, int, int]


@dataclass(frozen=True)
class PayloadEntry:
	relative_path: str
	kind: str
	size: int
	sha256: str
	content: bytes


@dataclass(frozen=True)
class ReferencePayloadManifest:
	entries: tuple[PayloadEntry, ...]
	payload_sha256: str
	file_count: int
	directory_count: int
	total_bytes: int
	skipped_count: int

	def generated_entries(self) -> dict[str, str | bytes | None]:
		return {
			entry.relative_path: entry.content if entry.kind == "file" else None
			for entry in self.entries
		}


@dataclass
class SyncStats:
	operation: str
	mode: str
	manifest: ReferencePayloadManifest
	planned_actions: list[str]
	applied_actions: list[str]

	def to_dict(self) -> dict[str, Any]:
		return {
			"schema_version": SCHEMA_VERSION,
			"ok": True,
			"operation": self.operation,
			"mode": self.mode,
			"source": "addons/gf",
			"target": "<reference-project>/addons/gf",
			"payload_sha256": self.manifest.payload_sha256,
			"file_count": self.manifest.file_count,
			"directory_count": self.manifest.directory_count,
			"total_bytes": self.manifest.total_bytes,
			"skipped_count": self.manifest.skipped_count,
			"planned_actions": list(self.planned_actions),
			"applied_actions": list(self.applied_actions),
		}


@dataclass
class CheckStats:
	manifest: ReferencePayloadManifest
	target_mode: str
	mismatch_count: int
	mismatches: list[str]

	def to_dict(self) -> dict[str, Any]:
		return {
			"schema_version": SCHEMA_VERSION,
			"ok": self.mismatch_count == 0,
			"operation": "check",
			"target_mode": self.target_mode,
			"source": "addons/gf",
			"target": "<reference-project>/addons/gf",
			"input_complete": True,
			"payload_sha256": self.manifest.payload_sha256,
			"file_count": self.manifest.file_count,
			"directory_count": self.manifest.directory_count,
			"total_bytes": self.manifest.total_bytes,
			"mismatch_count": self.mismatch_count,
			"mismatches_truncated": self.mismatch_count > len(self.mismatches),
			"mismatches": list(self.mismatches),
		}


class MismatchCollector:
	def __init__(self, limit: int) -> None:
		self.limit = limit
		self.count = 0
		self.samples: list[str] = []

	def add(self, message: str) -> None:
		self.count += 1
		if len(self.samples) < self.limit:
			self.samples.append(message)


def parse_arguments(argv: list[str] | None = None) -> argparse.Namespace:
	parser = argparse.ArgumentParser(
		description="Check, plan, or explicitly apply addons/gf in the reference project.",
	)
	parser.add_argument(
		"--project-root",
		default=None,
		help=(
			"Reference project root. Defaults to GF_REFERENCE_PROJECT_PATH "
			"or ../gf-reference-project."
		),
	)
	operation = parser.add_mutually_exclusive_group()
	operation.add_argument("--check", action="store_true", help="Verify current content without writing.")
	operation.add_argument("--plan", action="store_true", help="Describe an exact write plan without applying it.")
	operation.add_argument("--apply", action="store_true", help="Explicitly apply the planned synchronization.")
	parser.add_argument("--mode", choices=["copy", "link"], default="copy", help="Apply/plan mode.")
	parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")
	return parser.parse_args(argv)


def selected_operation(args: argparse.Namespace) -> str:
	if args.apply:
		return "apply"
	if args.plan:
		return "plan"
	return "check"


def main(argv: list[str] | None = None) -> int:
	configure_stdio()
	args = parse_arguments(argv)

	project_root = (
		args.project_root
		or os.environ.get(PROJECT_PATH_ENV_VAR, "")
		or str(DEFAULT_PROJECT_ROOT)
	)
	source = lexical_absolute_path(ROOT / DEFAULT_SOURCE)
	project = resolve_workspace_path(project_root)
	target = project / "addons" / "gf"
	operation_name = selected_operation(args)
	deadline = time.monotonic() + DEFAULT_LIMITS.deadline_seconds

	try:
		assert_source_root(source)
		assert_reference_project(project)
		assert_generated_target(project, target)
		assert_sync_boundaries(source, project, target)
		manifest = capture_payload_manifest(source, DEFAULT_LIMITS, deadline)
		if operation_name == "check":
			result: SyncStats | CheckStats = check_addon(
				manifest,
				source,
				target,
				DEFAULT_LIMITS,
				deadline,
			)
		else:
			result = sync_addon(
				manifest,
				source,
				target,
				args.mode,
				apply=operation_name == "apply",
			)
	except ReferenceSyncError as error:
		print_failure(error, args.json)
		return 1
	except (OSError, ValueError) as error:
		print_failure(
			ReferenceSyncError("reference_sync.unexpected_failure", type(error).__name__),
			args.json,
		)
		return 1

	data = result.to_dict()
	if args.json:
		print(json.dumps(data, ensure_ascii=False, indent=2))
	else:
		print(render_result(data))
	return 0 if bool(data["ok"]) else 1


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def resolve_workspace_path(value: str) -> Path:
	path = Path(value)
	if not path.is_absolute():
		path = ROOT / path
	return lexical_absolute_path(path)


def assert_source_root(source: Path, *, repository_root: Path = ROOT) -> None:
	expected_source = lexical_absolute_path(repository_root / DEFAULT_SOURCE)
	if lexical_absolute_path(source) != expected_source:
		raise ReferenceSyncError(
			"reference_sync.source_identity",
			"Source must be the repository-owned addons/gf root.",
		)
	if not source.is_dir():
		raise ReferenceSyncError("reference_sync.source_unavailable", "GF addon source is unavailable.")
	_validate_controlled(source, repository_root, "reference_sync.source_boundary")
	plugin_marker = source / "plugin.cfg"
	_validate_controlled(plugin_marker, source, "reference_sync.source_identity")
	try:
		marker_stat = plugin_marker.lstat()
	except OSError as error:
		raise ReferenceSyncError(
			"reference_sync.source_identity",
			"GF addon marker is unavailable.",
		) from error
	if not stat.S_ISREG(marker_stat.st_mode):
		raise ReferenceSyncError(
			"reference_sync.source_identity",
			"GF addon marker must be a regular file.",
		)


def assert_reference_project(project: Path) -> None:
	if not project.is_dir():
		raise ReferenceSyncError(
			"reference_sync.project_unavailable",
			"Reference project is unavailable.",
		)
	_validate_controlled(project, project.parent, "reference_sync.project_boundary")
	project_file = project / "project.godot"
	_validate_controlled(project_file, project, "reference_sync.project_identity")
	try:
		project_stat = project_file.lstat()
	except OSError as error:
		raise ReferenceSyncError(
			"reference_sync.project_identity",
			"Reference project marker is unavailable.",
		) from error
	if not stat.S_ISREG(project_stat.st_mode):
		raise ReferenceSyncError(
			"reference_sync.project_identity",
			"Reference project marker must be a regular file.",
		)


def assert_generated_target(project: Path, target: Path) -> None:
	expected_parent = lexical_absolute_path(project / "addons")
	if lexical_absolute_path(target.parent) != expected_parent or target.name != "gf":
		raise ReferenceSyncError(
			"reference_sync.target_identity",
			"Target must be the direct addons/gf child of the reference project.",
		)
	_validate_controlled(target.parent, project, "reference_sync.target_boundary")
	if not target.is_symlink():
		_validate_controlled(target, project, "reference_sync.target_boundary")


def assert_sync_boundaries(
	source: Path,
	project: Path,
	target: Path,
	*,
	repository_root: Path = ROOT,
) -> None:
	if paths_overlap(project, repository_root):
		raise ReferenceSyncError(
			"reference_sync.project_overlaps_repository",
			"Reference project must be external to the GF repository.",
		)
	if paths_overlap(source, target, include_filesystem_identity=not target.is_symlink()):
		raise ReferenceSyncError(
			"reference_sync.source_target_overlap",
			"Source and target must not be identical, ancestors, or descendants.",
		)


def paths_overlap(
	first: Path,
	second: Path,
	*,
	include_filesystem_identity: bool = True,
) -> bool:
	first_path = lexical_absolute_path(first)
	second_path = lexical_absolute_path(second)
	if _is_relative_to(first_path, second_path) or _is_relative_to(second_path, first_path):
		return True
	if not include_filesystem_identity:
		return False
	try:
		first_real = first_path.resolve(strict=False)
		second_real = second_path.resolve(strict=False)
		if _is_relative_to(first_real, second_real) or _is_relative_to(second_real, first_real):
			return True
		return _existing_path_is_ancestor(first_path, second_path) or _existing_path_is_ancestor(
			second_path,
			first_path,
		)
	except OSError as error:
		raise ReferenceSyncError(
			"reference_sync.identity_unavailable",
			"Filesystem identity could not be established safely.",
		) from error


def _existing_path_is_ancestor(candidate: Path, descendant: Path) -> bool:
	if not candidate.exists():
		return False
	current = descendant
	while not current.exists():
		if current == current.parent:
			return False
		current = current.parent
	while True:
		if candidate.samefile(current):
			return True
		if current == current.parent:
			return False
		current = current.parent


def capture_payload_manifest(
	source: Path,
	limits: SyncLimits = DEFAULT_LIMITS,
	deadline: float | None = None,
) -> ReferencePayloadManifest:
	effective_deadline = time.monotonic() + limits.deadline_seconds if deadline is None else deadline
	first = _capture_payload_manifest(source, limits, effective_deadline, keep_content=True)
	second = _capture_payload_manifest(source, limits, effective_deadline, keep_content=False)
	if (
		first.payload_sha256 != second.payload_sha256
		or first.file_count != second.file_count
		or first.directory_count != second.directory_count
		or first.total_bytes != second.total_bytes
		or first.skipped_count != second.skipped_count
	):
		raise ReferenceSyncError(
			"reference_sync.source_changed",
			"Source changed while the payload manifest was being captured.",
		)
	return first


def _capture_payload_manifest(
	source: Path,
	limits: SyncLimits,
	deadline: float,
	*,
	keep_content: bool,
) -> ReferencePayloadManifest:
	scan_entries, skipped_count = scan_tree(source, limits, deadline)
	validation_entries: dict[str, str | bytes | None] = {}
	for entry in scan_entries:
		if entry.kind == "link":
			raise ReferenceSyncError(
				"reference_sync.source_link",
				f"Source contains an unsupported linked entry: {entry.relative_path}",
			)
		if entry.kind == "special":
			raise ReferenceSyncError(
				"reference_sync.source_special_entry",
				f"Source contains an unsupported special entry: {entry.relative_path}",
			)
		validation_entries[entry.relative_path] = None if entry.kind == "directory" else b""
	try:
		validate_generated_entries(validation_entries)
	except (TypeError, ValueError, UnicodeError) as error:
		raise ReferenceSyncError(
			"reference_sync.payload_path",
			"Source contains a non-portable or colliding payload path.",
		) from error

	total_bytes = 0
	payload_entries: list[PayloadEntry] = []
	for entry in scan_entries:
		_check_deadline(deadline)
		if entry.kind == "directory":
			payload_entries.append(PayloadEntry(entry.relative_path, "directory", 0, "", b""))
			continue
		content, digest, size = read_regular_file(
			entry.path,
			entry.relative_path,
			entry.identity,
			limits,
			deadline,
			keep_content=keep_content,
		)
		total_bytes += size
		if total_bytes > limits.max_total_bytes:
			raise ReferenceSyncError(
				"reference_sync.total_bytes_limit",
				"Payload exceeds the total byte budget.",
			)
		payload_entries.append(PayloadEntry(entry.relative_path, "file", size, digest, content))

	payload_entries.sort(key=lambda item: item.relative_path)
	payload_digest = payload_manifest_digest(payload_entries)
	return ReferencePayloadManifest(
		entries=tuple(payload_entries),
		payload_sha256=payload_digest,
		file_count=sum(entry.kind == "file" for entry in payload_entries),
		directory_count=sum(entry.kind == "directory" for entry in payload_entries),
		total_bytes=total_bytes,
		skipped_count=skipped_count,
	)


def scan_tree(
	root: Path,
	limits: SyncLimits,
	deadline: float,
) -> tuple[list[TreeEntry], int]:
	_validate_controlled(root, root, "reference_sync.tree_boundary")
	if path_is_link_or_junction(root):
		raise ReferenceSyncError("reference_sync.tree_boundary", "Tree root must not be linked.")
	try:
		root_stat = root.lstat()
	except OSError as error:
		raise ReferenceSyncError(
			"reference_sync.tree_unreadable",
			"Tree root could not be inspected safely.",
		) from error
	if not stat.S_ISDIR(root_stat.st_mode):
		raise ReferenceSyncError("reference_sync.tree_boundary", "Tree root must be a directory.")
	root_identity = stat_identity(root_stat)
	entries: list[TreeEntry] = []
	stack: list[tuple[Path, str, tuple[int, int, int, int, int]]] = [
		(root, "", root_identity),
	]
	observed_count = 0
	skipped_count = 0
	while stack:
		_check_deadline(deadline)
		directory, directory_relative, expected_directory_identity = stack.pop()
		try:
			directory_stat = directory.lstat()
		except OSError as error:
			raise ReferenceSyncError(
				"reference_sync.tree_changed",
				"Tree directory changed while it was being enumerated.",
			) from error
		if (
			stat_identity(directory_stat) != expected_directory_identity
			or not stat.S_ISDIR(directory_stat.st_mode)
			or stat_is_link_or_reparse(directory_stat)
		):
			raise ReferenceSyncError(
				"reference_sync.tree_changed",
				"Tree directory changed while it was being enumerated.",
			)
		try:
			with os.scandir(directory) as iterator:
				directory_entries: list[tuple[str, Path]] = []
				for raw_entry in iterator:
					observed_count += 1
					if observed_count > limits.max_entries:
						raise ReferenceSyncError(
							"reference_sync.entry_limit",
							"Tree exceeds the entry budget.",
						)
					directory_entries.append((raw_entry.name, Path(raw_entry.path)))
		except ReferenceSyncError:
			raise
		except OSError as error:
			raise ReferenceSyncError(
				"reference_sync.tree_unreadable",
				"Tree could not be enumerated safely.",
			) from error

		for entry_name, path in sorted(directory_entries, key=lambda item: item[0], reverse=True):
			_check_deadline(deadline)
			relative_path = (
				f"{directory_relative}/{entry_name}"
				if directory_relative
				else entry_name
			)
			if should_skip(Path(relative_path)):
				skipped_count += 1
				continue
			try:
				entry_stat = path.lstat()
			except OSError as error:
				raise ReferenceSyncError(
					"reference_sync.entry_unreadable",
					f"Tree entry became unavailable: {relative_path}",
				) from error
			entry_identity = stat_identity(entry_stat)
			if stat_is_link_or_reparse(entry_stat):
				entries.append(TreeEntry(relative_path, "link", path, entry_identity))
			elif stat.S_ISDIR(entry_stat.st_mode):
				entries.append(TreeEntry(relative_path, "directory", path, entry_identity))
				stack.append((path, relative_path, entry_identity))
			elif stat.S_ISREG(entry_stat.st_mode):
				entries.append(TreeEntry(relative_path, "file", path, entry_identity))
			else:
				entries.append(TreeEntry(relative_path, "special", path, entry_identity))
	try:
		final_root_stat = root.lstat()
	except OSError as error:
		raise ReferenceSyncError(
			"reference_sync.tree_changed",
			"Tree root changed while it was being enumerated.",
		) from error
	if (
		stat_identity(final_root_stat) != root_identity
		or stat_is_link_or_reparse(final_root_stat)
	):
		raise ReferenceSyncError(
			"reference_sync.tree_changed",
			"Tree root changed while it was being enumerated.",
		)
	entries.sort(key=lambda item: item.relative_path)
	return entries, skipped_count


def read_regular_file(
	path: Path,
	relative_path: str,
	expected_identity: tuple[int, int, int, int, int],
	limits: SyncLimits,
	deadline: float,
	*,
	keep_content: bool,
) -> tuple[bytes, str, int]:
	_check_deadline(deadline)
	try:
		before_stat = path.lstat()
	except OSError as error:
		raise ReferenceSyncError(
			"reference_sync.file_unreadable",
			f"Payload file became unavailable: {relative_path}",
		) from error
	if (
		stat_identity(before_stat) != expected_identity
		or not stat.S_ISREG(before_stat.st_mode)
		or stat_is_link_or_reparse(before_stat)
	):
		raise ReferenceSyncError(
			"reference_sync.file_changed",
			f"Payload file changed before it was opened: {relative_path}",
		)
	if before_stat.st_size > limits.max_file_bytes:
		raise ReferenceSyncError(
			"reference_sync.file_bytes_limit",
			f"Payload file exceeds the per-file byte budget: {relative_path}",
		)

	digest = hashlib.sha256()
	content_parts: list[bytes] = []
	read_bytes = 0
	try:
		with path.open("rb", buffering=0) as stream:
			handle_stat = os.fstat(stream.fileno())
			if stat_identity(before_stat) != stat_identity(handle_stat):
				raise ReferenceSyncError(
					"reference_sync.file_changed",
					f"Payload file changed before it was opened: {relative_path}",
				)
			while True:
				_check_deadline(deadline)
				chunk = stream.read(READ_CHUNK_BYTES)
				if not chunk:
					break
				read_bytes += len(chunk)
				if read_bytes > limits.max_file_bytes:
					raise ReferenceSyncError(
						"reference_sync.file_bytes_limit",
						f"Payload file exceeds the per-file byte budget: {relative_path}",
					)
				digest.update(chunk)
				if keep_content:
					content_parts.append(chunk)
			after_handle_stat = os.fstat(stream.fileno())
	except ReferenceSyncError:
		raise
	except OSError as error:
		raise ReferenceSyncError(
			"reference_sync.file_unreadable",
			f"Payload file could not be read: {relative_path}",
		) from error
	try:
		after_stat = path.lstat()
	except OSError as error:
		raise ReferenceSyncError(
			"reference_sync.file_changed",
			f"Payload file disappeared after it was read: {relative_path}",
		) from error
	if (
		stat_identity(before_stat) != stat_identity(after_handle_stat)
		or stat_identity(before_stat) != stat_identity(after_stat)
		or read_bytes != before_stat.st_size
	):
		raise ReferenceSyncError(
			"reference_sync.file_changed",
			f"Payload file changed while it was read: {relative_path}",
		)
	return b"".join(content_parts), digest.hexdigest(), read_bytes


def stat_identity(value: os.stat_result) -> tuple[int, int, int, int, int]:
	return (
		value.st_dev,
		value.st_ino,
		value.st_mode,
		value.st_size,
		value.st_mtime_ns,
	)


def stat_is_link_or_reparse(value: os.stat_result) -> bool:
	if stat.S_ISLNK(value.st_mode):
		return True
	attributes = getattr(value, "st_file_attributes", 0)
	return bool(attributes & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0))


def payload_manifest_digest(entries: list[PayloadEntry]) -> str:
	digest = hashlib.sha256()
	digest.update(b"gf-reference-payload-v1\0")
	for entry in entries:
		path_bytes = entry.relative_path.encode("utf-8", errors="strict")
		digest.update(len(path_bytes).to_bytes(4, "big"))
		digest.update(path_bytes)
		digest.update(b"D" if entry.kind == "directory" else b"F")
		digest.update(entry.size.to_bytes(8, "big"))
		if entry.kind == "file":
			digest.update(bytes.fromhex(entry.sha256))
	return digest.hexdigest()


def check_addon(
	manifest: ReferencePayloadManifest,
	source: Path,
	target: Path,
	limits: SyncLimits = DEFAULT_LIMITS,
	deadline: float | None = None,
) -> CheckStats:
	effective_deadline = time.monotonic() + limits.deadline_seconds if deadline is None else deadline
	mismatches = MismatchCollector(limits.max_mismatches)
	if not path_exists(target):
		mismatches.add("missing target")
		return CheckStats(manifest, "missing", mismatches.count, mismatches.samples)
	if target.is_symlink():
		try:
			link_matches = target.resolve(strict=True) == source.resolve(strict=True)
		except OSError:
			link_matches = False
		if not link_matches:
			mismatches.add("stale top-level link")
		return CheckStats(manifest, "link", mismatches.count, mismatches.samples)
	if path_is_link_or_junction(target):
		mismatches.add("unsupported top-level reparse target")
		return CheckStats(manifest, "unsupported", mismatches.count, mismatches.samples)
	if not target.is_dir():
		mismatches.add("target is not a directory")
		return CheckStats(manifest, "unsupported", mismatches.count, mismatches.samples)

	target_entries, _skipped = scan_tree(target, limits, effective_deadline)
	target_by_path = {entry.relative_path: entry for entry in target_entries}
	expected_paths = {entry.relative_path for entry in manifest.entries}
	total_read_bytes = 0
	for expected in manifest.entries:
		_check_deadline(effective_deadline)
		actual = target_by_path.get(expected.relative_path)
		if actual is None:
			mismatches.add(f"missing {expected.kind}: {expected.relative_path}")
			continue
		if actual.kind != expected.kind:
			mismatches.add(f"entry kind mismatch: {expected.relative_path}")
			continue
		if expected.kind == "directory":
			continue
		_content, actual_digest, actual_size = read_regular_file(
			actual.path,
			actual.relative_path,
			actual.identity,
			limits,
			effective_deadline,
			keep_content=False,
		)
		total_read_bytes += actual_size
		if total_read_bytes > limits.max_total_bytes:
			raise ReferenceSyncError(
				"reference_sync.target_total_bytes_limit",
				"Target comparison exceeds the total byte budget.",
			)
		if actual_size != expected.size or actual_digest != expected.sha256:
			mismatches.add(f"stale file: {expected.relative_path}")
	for extra_path in sorted(set(target_by_path) - expected_paths):
		mismatches.add(f"extra entry: {extra_path}")
	return CheckStats(manifest, "copy", mismatches.count, mismatches.samples)


def sync_addon(
	manifest: ReferencePayloadManifest,
	source: Path,
	target: Path,
	mode: str,
	*,
	apply: bool,
) -> SyncStats:
	operation = "apply" if apply else "plan"
	planned_actions: list[str] = []
	applied_actions: list[str] = []
	if mode == "link":
		if target.is_symlink():
			try:
				link_matches = target.resolve(strict=True) == source.resolve(strict=True)
			except OSError:
				link_matches = False
			if not link_matches:
				raise ReferenceSyncError(
					"reference_sync.link_target_conflict",
					"Existing top-level link does not point to the GF source.",
				)
			planned_actions.append("retain_top_level_link")
			return SyncStats(operation, mode, manifest, planned_actions, applied_actions)
		if path_exists(target):
			raise ReferenceSyncError(
				"reference_sync.link_target_conflict",
				"Link mode refuses to replace an existing target without an ownership protocol.",
			)
		planned_actions.append("create_top_level_link")
		if apply:
			target.parent.mkdir(parents=True, exist_ok=True)
			try:
				os.symlink(source, target, target_is_directory=True)
			except OSError as error:
				raise ReferenceSyncError(
					"reference_sync.link_create_failed",
					"Top-level link could not be created.",
				) from error
			applied_actions.append("create_top_level_link")
		return SyncStats(operation, mode, manifest, planned_actions, applied_actions)

	if path_is_link_or_junction(target):
		raise ReferenceSyncError(
			"reference_sync.copy_target_link",
			"Copy mode refuses to replace a linked or reparse target.",
		)
	if target.exists() and not target.is_dir():
		raise ReferenceSyncError(
			"reference_sync.copy_target_conflict",
			"Copy mode requires the target to be absent or a directory.",
		)
	planned_action = "replace_copy_tree" if target.exists() else "create_copy_tree"
	planned_actions.append(planned_action)
	if apply:
		try:
			replace_generated_trees([(target, manifest.generated_entries())])
		except (OSError, RuntimeError, TypeError, ValueError) as error:
			raise ReferenceSyncError(
				"reference_sync.copy_commit_failed",
				"Copy transaction failed before a complete result could be committed.",
			) from error
		applied_actions.append(planned_action)
	return SyncStats(operation, mode, manifest, planned_actions, applied_actions)


def path_exists(path: Path) -> bool:
	return path.exists() or path.is_symlink()


def should_skip(relative_path: Path) -> bool:
	if relative_path.is_absolute():
		raise ValueError("Skip policy accepts only payload-relative paths.")
	if any(part in BLOCKED_DIR_NAMES for part in relative_path.parts):
		return True
	if relative_path.name in BLOCKED_FILE_NAMES:
		return True
	if relative_path.suffix in BLOCKED_SUFFIXES:
		return True
	return False


def render_result(data: dict[str, Any]) -> str:
	lines = [
		f"operation: {data['operation']}",
		f"ok: {data['ok']}",
		f"source: {data['source']}",
		f"target: {data['target']}",
		f"payload_sha256: {data['payload_sha256']}",
		f"files: {data['file_count']}",
		f"directories: {data['directory_count']}",
		f"bytes: {data['total_bytes']}",
	]
	if data["operation"] == "check":
		lines.append(f"target_mode: {data['target_mode']}")
		lines.append(f"mismatch_count: {data['mismatch_count']}")
		for mismatch in data["mismatches"]:
			lines.append(f"- {mismatch}")
	elif data["planned_actions"]:
		lines.append(f"planned_actions: {', '.join(data['planned_actions'])}")
		lines.append(
			"applied_actions: "
			+ (", ".join(data["applied_actions"]) if data["applied_actions"] else "<none>")
		)
	return "\n".join(lines)


def print_failure(error: ReferenceSyncError, as_json: bool) -> None:
	data = {
		"schema_version": SCHEMA_VERSION,
		"ok": False,
		"rule_id": error.rule_id,
		"message": error.message,
	}
	if as_json:
		print(json.dumps(data, ensure_ascii=False, indent=2))
	else:
		print(f"{error.rule_id}: {error.message}", file=sys.stderr)


def _validate_controlled(path: Path, root: Path, rule_id: str) -> None:
	try:
		validate_controlled_path(path, root)
	except ValueError as error:
		raise ReferenceSyncError(rule_id, "Path crosses a linked, reparse, or containment boundary.") from error


def _check_deadline(deadline: float) -> None:
	if time.monotonic() > deadline:
		raise ReferenceSyncError(
			"reference_sync.deadline",
			"Reference synchronization exceeded its wall-clock budget.",
		)


def _is_relative_to(path: Path, root: Path) -> bool:
	try:
		path.relative_to(root)
	except ValueError:
		return False
	return True


if __name__ == "__main__":
	raise SystemExit(main())
