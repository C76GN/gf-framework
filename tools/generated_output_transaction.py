#!/usr/bin/env python3
"""Transactional replacement for generated directory trees."""

from __future__ import annotations

import os
import shutil
import stat
import tempfile
from pathlib import Path


class GeneratedOutputTransactionError(RuntimeError):
	"""Report a replacement failure whose rollback also failed."""

	def __init__(
		self,
		original_error: BaseException,
		rollback_errors: list[tuple[Path, BaseException]],
		backup_paths: list[Path],
	) -> None:
		self.original_error = original_error
		self.rollback_errors = rollback_errors
		self.backup_paths = backup_paths
		rollback_summary = "; ".join(
			f"{path}: {error}"
			for path, error in rollback_errors
		)
		backup_summary = ", ".join(str(path) for path in backup_paths) or "<none>"
		super().__init__(
			"Generated output replacement failed and rollback was incomplete. "
			f"Original failure: {original_error}. Rollback failures: {rollback_summary}. "
			f"Retained backups: {backup_summary}"
		)


def lexical_absolute_path(path: Path) -> Path:
	"""Return an absolute normalized path without following filesystem links."""
	return Path(os.path.abspath(os.fspath(path)))


def validate_controlled_path(path: Path, containment_root: Path) -> Path:
	"""Validate lexical and real containment without traversing reparse targets."""
	controlled_path = lexical_absolute_path(path)
	controlled_root = lexical_absolute_path(containment_root)
	if not _is_relative_to(controlled_path, controlled_root):
		raise ValueError(
			f"Controlled path escapes its lexical root: {controlled_path} (root: {controlled_root})"
		)

	root_ancestor = _nearest_existing_ancestor(controlled_root)
	path_ancestor = _nearest_existing_ancestor(controlled_path)
	for existing_ancestor in (root_ancestor, path_ancestor):
		if _path_is_link_or_junction(existing_ancestor):
			raise ValueError(
				f"Controlled path must not traverse a symlink or junction: {existing_ancestor}"
			)
	if not _is_relative_to(path_ancestor.resolve(strict=True), root_ancestor.resolve(strict=True)):
		raise ValueError(
			"Controlled path escapes its root through an existing filesystem ancestor: "
			f"{controlled_path} (root: {controlled_root})"
		)

	current = controlled_path
	while True:
		if _path_is_link_or_junction(current):
			raise ValueError(f"Controlled path must not traverse a symlink or junction: {current}")
		if current == current.parent:
			break
		current = current.parent
	return controlled_path


def replace_generated_trees(outputs: list[tuple[Path, dict[str, str]]]) -> None:
	"""Stage every output tree, then replace all roots with rollback on failure."""
	normalized_outputs = _normalize_outputs(outputs)
	staging_roots: dict[Path, Path] = {}
	backup_parents: dict[Path, Path] = {}
	replaced_roots: list[Path] = []
	committed = False
	rollback_failed = False

	try:
		for root, files in normalized_outputs:
			root.parent.mkdir(parents=True, exist_ok=True)
			staging_root = Path(tempfile.mkdtemp(
				prefix=f".{root.name}.staging-",
				dir=root.parent,
			))
			staging_roots[root] = staging_root
			_write_staging_tree(staging_root, files)

		for root, _files in normalized_outputs:
			staging_root = staging_roots[root]
			if root.exists():
				if not root.is_dir():
					raise RuntimeError(f"Generated output root is not a directory: {root}")
				backup_parent = Path(tempfile.mkdtemp(
					prefix=f".{root.name}.backup-",
					dir=root.parent,
				))
				backup_parents[root] = backup_parent
				os.replace(root, backup_parent / "previous")
			os.replace(staging_root, root)
			replaced_roots.append(root)
		committed = True
	except Exception as original_error:
		if not committed:
			rollback_errors: list[tuple[Path, BaseException]] = []
			for root, _files in reversed(normalized_outputs):
				backup_parent = backup_parents.get(root)
				previous = backup_parent / "previous" if backup_parent is not None else None
				try:
					if root in replaced_roots and root.exists():
						if not root.is_dir() or _path_is_link_or_junction(root):
							raise RuntimeError(f"Refusing to remove an uncontrolled rollback target: {root}")
						shutil.rmtree(root)
					if previous is not None and previous.exists():
						if root.exists():
							raise RuntimeError(f"Rollback destination still exists: {root}")
						os.replace(previous, root)
				except Exception as rollback_error:
					rollback_errors.append((root, rollback_error))
			if rollback_errors:
				rollback_failed = True
				backup_paths = [
					backup_parent / "previous"
					for backup_parent in backup_parents.values()
					if (backup_parent / "previous").exists()
				]
				raise GeneratedOutputTransactionError(
					original_error,
					rollback_errors,
					backup_paths,
				) from original_error
		raise
	finally:
		for staging_root in staging_roots.values():
			if staging_root.exists():
				shutil.rmtree(staging_root, ignore_errors=True)
		for backup_parent in backup_parents.values():
			if rollback_failed and (backup_parent / "previous").exists():
				continue
			if backup_parent.exists():
				shutil.rmtree(backup_parent, ignore_errors=True)


def _normalize_outputs(outputs: list[tuple[Path, dict[str, str]]]) -> list[tuple[Path, dict[str, str]]]:
	normalized: list[tuple[Path, dict[str, str]]] = []
	seen_roots: set[Path] = set()
	for raw_root, files in outputs:
		root = lexical_absolute_path(raw_root)
		if root == root.parent:
			raise ValueError(f"Generated output root must not be a filesystem anchor: {root}")
		validate_controlled_path(root, root.parent)
		if root in seen_roots:
			raise ValueError(f"Duplicate generated output root: {root}")
		seen_roots.add(root)
		_validate_relative_paths(files)
		normalized.append((root, files))
	return normalized


def _validate_relative_paths(files: dict[str, str]) -> None:
	for relative_path in files:
		path = Path(relative_path)
		if not relative_path or path.is_absolute() or ".." in path.parts:
			raise ValueError(f"Generated output path must stay relative to its root: {relative_path!r}")


def _write_staging_tree(staging_root: Path, files: dict[str, str]) -> None:
	for relative_path, content in files.items():
		path = staging_root / relative_path
		path.parent.mkdir(parents=True, exist_ok=True)
		path.write_text(content, encoding="utf-8", newline="\n")


def _nearest_existing_ancestor(path: Path) -> Path:
	current = path
	while True:
		if _path_is_link_or_junction(current) or current.exists():
			return current
		if current == current.parent:
			raise ValueError(f"No existing filesystem ancestor for controlled path: {path}")
		current = current.parent


def _path_is_link_or_junction(path: Path) -> bool:
	if path.is_symlink():
		return True
	is_junction = getattr(path, "is_junction", None)
	if callable(is_junction) and is_junction():
		return True
	try:
		attributes = path.lstat().st_file_attributes
	except (AttributeError, FileNotFoundError, OSError):
		return False
	return bool(attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT)


def _is_relative_to(path: Path, root: Path) -> bool:
	try:
		path.relative_to(root)
	except ValueError:
		return False
	return True
