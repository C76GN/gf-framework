#!/usr/bin/env python3
"""Transactional replacement for generated directory trees."""

from __future__ import annotations

import os
import re
import shutil
import stat
import tempfile
import unicodedata
from pathlib import Path
from pathlib import PureWindowsPath
from typing import Callable


WINDOWS_RESERVED_NAMES = {
	"CON",
	"PRN",
	"AUX",
	"NUL",
	*(f"COM{index}" for index in range(1, 10)),
	*(f"LPT{index}" for index in range(1, 10)),
}
WINDOWS_INVALID_COMPONENT_PATTERN = re.compile(r'[<>:"|?*]|[\x00-\x1f]')


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


GeneratedContent = str | bytes | None


def replace_generated_trees(outputs: list[tuple[Path, dict[str, GeneratedContent]]]) -> None:
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


def compare_generated_tree(
	root: Path,
	desired: dict[str, str],
	normalize_expected: Callable[[str], str] | None = None,
) -> list[str]:
	"""Compare a generated tree without mutating it."""
	_validate_relative_paths(desired)
	mismatches: list[str] = []
	for relative_path in sorted(desired):
		path = root.joinpath(*relative_path.split("/"))
		if not path.exists():
			mismatches.append(f"missing: {relative_path}")
			continue
		if not path.is_file():
			mismatches.append(f"stale: {relative_path}")
			continue
		expected = desired[relative_path]
		if normalize_expected is not None:
			expected = normalize_expected(expected)
		if path.read_text(encoding="utf-8") != expected:
			mismatches.append(f"stale: {relative_path}")

	existing = {
		path.relative_to(root).as_posix()
		for path in root.rglob("*")
		if path.is_file()
	} if root.exists() else set()
	for extra in sorted(existing - set(desired)):
		mismatches.append(f"extra: {extra}")
	return mismatches


def _normalize_outputs(
	outputs: list[tuple[Path, dict[str, GeneratedContent]]],
) -> list[tuple[Path, dict[str, GeneratedContent]]]:
	normalized: list[tuple[Path, dict[str, GeneratedContent]]] = []
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


def validate_generated_entries(files: dict[str, GeneratedContent]) -> None:
	"""Validate portable relative identities before a generated tree is staged."""
	_validate_relative_paths(files)


def path_is_link_or_junction(path: Path) -> bool:
	"""Return whether a path is a symlink, junction, or other reparse point."""
	return _path_is_link_or_junction(path)


def _validate_relative_paths(files: dict[str, GeneratedContent]) -> None:
	portable_identities: dict[str, str] = {}
	portable_components: dict[str, str] = {}
	for relative_path, content in files.items():
		if not isinstance(relative_path, str) or not isinstance(content, (str, bytes, type(None))):
			raise TypeError(
				"Generated output paths must be strings and contents must be strings, bytes, or None"
			)
		windows_path = PureWindowsPath(relative_path)
		if (
			not relative_path
			or "\\" in relative_path
			or relative_path.startswith("/")
			or windows_path.drive
			or windows_path.root
		):
			raise ValueError(
				f"Generated output path must stay relative to its root: {relative_path!r}"
			)

		components = relative_path.split("/")
		if any(component in {"", ".", ".."} for component in components):
			raise ValueError(
				f"Generated output path contains an unsafe component: {relative_path!r}"
			)
		for component in components:
			if (
				WINDOWS_INVALID_COMPONENT_PATTERN.search(component) is not None
				or component.endswith((" ", "."))
			):
				raise ValueError(
					f"Generated output path is not portable: {relative_path!r}"
				)
			reserved_stem = component.split(".", 1)[0].upper()
			if reserved_stem in WINDOWS_RESERVED_NAMES:
				raise ValueError(
					f"Generated output path uses a reserved name: {relative_path!r}"
				)

		try:
			relative_path.encode("utf-8", errors="strict")
		except UnicodeEncodeError as error:
			raise ValueError(
				f"Generated output path is not valid UTF-8 text: {relative_path!r}"
			) from error

		portable_parts: list[str] = []
		for component in components:
			portable_parts.append(unicodedata.normalize("NFC", component).casefold())
			portable_prefix = "/".join(portable_parts)
			literal_prefix = "/".join(components[:len(portable_parts)])
			previous_prefix = portable_components.get(portable_prefix)
			if previous_prefix is not None and previous_prefix != literal_prefix:
				raise ValueError(
					"Generated output portable path collision: "
					f"{previous_prefix!r} and {literal_prefix!r}"
				)
			portable_components[portable_prefix] = literal_prefix

		portable_identity = "/".join(portable_parts)
		previous = portable_identities.get(portable_identity)
		if previous is not None:
			raise ValueError(
				"Generated output portable path collision: "
				f"{previous!r} and {relative_path!r}"
			)
		portable_identities[portable_identity] = relative_path

	content_by_portable_identity = {
		"/".join(
			unicodedata.normalize("NFC", component).casefold()
			for component in relative_path.split("/")
		): content
		for relative_path, content in files.items()
	}
	for relative_path, content in files.items():
		components = relative_path.split("/")
		for index in range(1, len(components)):
			parent_identity = "/".join(
				unicodedata.normalize("NFC", component).casefold()
				for component in components[:index]
			)
			if (
				parent_identity in content_by_portable_identity
				and content_by_portable_identity[parent_identity] is not None
			):
				raise ValueError(
					"Generated output file cannot also be an ancestor directory: "
					f"{'/'.join(components[:index])!r} for {relative_path!r}"
				)
		if content is None:
			continue


def _write_staging_tree(staging_root: Path, files: dict[str, GeneratedContent]) -> None:
	for relative_path, content in sorted(
		files.items(),
		key=lambda item: (item[0].count("/"), item[0]),
	):
		path = staging_root.joinpath(*relative_path.split("/"))
		if content is None:
			path.mkdir(parents=True, exist_ok=True)
			continue
		path.parent.mkdir(parents=True, exist_ok=True)
		if isinstance(content, bytes):
			path.write_bytes(content)
		else:
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
