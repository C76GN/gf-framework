"""Path validation and atomic UTF-8 persistence helpers."""

from __future__ import annotations

import json
import os
import posixpath
import secrets
import stat
import unicodedata
from pathlib import Path
from typing import Any


DEFAULT_MAX_JSON_BYTES = 16 * 1024 * 1024
_RESOURCE_PATH_FORBIDDEN_CHARACTERS = frozenset('<>:"|?*[]')
_WINDOWS_RESERVED_PATH_STEMS = frozenset({
	"aux",
	"con",
	"nul",
	"prn",
	*(f"com{index}" for index in range(1, 10)),
	*(f"lpt{index}" for index in range(1, 10)),
})


class PathBoundaryError(ValueError):
	"""Raised when a project-side operation would escape its owned boundary."""


class CompareExchangeError(ValueError):
	"""Raised when a guarded JSON replacement cannot prove its source or target."""


def normalize_resource_path(raw_path: str) -> str:
	"""Normalize one exact non-root res:// path without applying platform policy."""
	normalized = raw_path.strip().replace("\\", "/")
	if not normalized.startswith("res://"):
		return ""
	relative = normalized.removeprefix("res://")
	if not relative:
		return ""
	parts = relative.split("/")
	if any(part in ("", ".", "..") for part in parts):
		return ""
	return "res://" + posixpath.normpath(relative)


def normalize_portable_ownership_path(raw_path: str) -> str:
	"""Return a canonical cross-platform ownership path, or an empty string."""
	if any(ord(character) < 32 or ord(character) == 127 for character in raw_path):
		return ""
	normalized = normalize_resource_path(raw_path)
	if not normalized or normalized != raw_path:
		return ""
	parts = normalized.removeprefix("res://").split("/")
	for part in parts:
		if part != part.rstrip(" ."):
			return ""
		if any(character in _RESOURCE_PATH_FORBIDDEN_CHARACTERS for character in part):
			return ""
		if part.split(".", 1)[0].casefold() in _WINDOWS_RESERVED_PATH_STEMS:
			return ""
	return normalized


def portable_ownership_path_identity(raw_path: str) -> str:
	"""Return the Unicode-normalized case-folded identity of a portable ownership path."""
	normalized = normalize_portable_ownership_path(raw_path)
	if not normalized:
		return ""
	return unicodedata.normalize("NFC", normalized).casefold()


def is_reserved_framework_resource_path(raw_path: str) -> bool:
	"""Return whether a resource path addresses the reserved addons/gf boundary."""
	normalized = normalize_resource_path(raw_path)
	if not normalized:
		return False
	parts = tuple(part.casefold() for part in normalized.removeprefix("res://").split("/"))
	return parts[0:2] == ("addons", "gf")


def project_path_has_link_component(project_root: Path, relative_path: str) -> bool:
	"""Fail closed when an existing project-relative path component is linked or reparsed."""
	normalized = relative_path.strip().replace("\\", "/")
	root = Path(os.path.abspath(os.fspath(project_root)))
	target = Path(os.path.abspath(os.fspath(root / normalized)))
	try:
		relative = target.relative_to(root)
	except ValueError:
		return True
	reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
	current = root
	for part in relative.parts:
		current /= part
		try:
			metadata = current.lstat()
		except FileNotFoundError:
			break
		except OSError:
			return True
		if current.is_symlink():
			return True
		if reparse_flag and getattr(metadata, "st_file_attributes", 0) & reparse_flag:
			return True
	return False


def resolve_project_root(raw_root: str | Path) -> Path:
	root = Path(raw_root or ".").expanduser().resolve()
	if not root.is_dir():
		raise PathBoundaryError(f"Project root is not a directory: {root}")
	try:
		project_file = resolve_project_path(root, "project.godot", must_exist=True)
	except PathBoundaryError as exc:
		raise PathBoundaryError(f"Project root has an unsafe project.godot: {root}: {exc}") from exc
	if not project_file.is_file():
		raise PathBoundaryError(f"Project root does not contain project.godot: {root}")
	return root


def resolve_project_path(
	project_root: Path,
	relative_path: str,
	*,
	must_exist: bool = False,
) -> Path:
	normalized = relative_path.strip().replace("\\", "/")
	if not normalized or normalized.startswith(('/', '\\')):
		raise PathBoundaryError(f"Project path must be non-empty and relative: {relative_path!r}")
	if len(normalized) >= 2 and normalized[1] == ":":
		raise PathBoundaryError(f"Project path must not contain a drive prefix: {relative_path!r}")
	parts = Path(normalized).parts
	if any(part in ("", ".", "..") for part in parts):
		raise PathBoundaryError(f"Project path contains an unsafe segment: {relative_path!r}")
	root = Path(os.path.abspath(os.fspath(project_root)))
	target = Path(os.path.abspath(os.fspath(root / Path(*parts))))
	try:
		target.relative_to(root)
	except ValueError as exc:
		raise PathBoundaryError(f"Project path escapes the project root: {relative_path!r}") from exc
	if project_path_has_link_component(root, normalized):
		raise PathBoundaryError(f"Project path crosses a filesystem link: {relative_path!r}")
	if must_exist and not target.exists():
		raise PathBoundaryError(f"Project path does not exist: {relative_path!r}")
	return target


def read_bounded_bytes(path: Path, max_bytes: int) -> bytes:
	"""Read one regular file within a hard byte budget and reject identity drift."""
	if max_bytes <= 0:
		raise ValueError("File byte budget must be positive.")
	_reject_linked_write_path(path)
	try:
		before = path.lstat()
	except OSError as exc:
		raise ValueError(f"File is unreadable: {path}: {exc}") from exc
	if not stat.S_ISREG(before.st_mode):
		raise ValueError(f"Path is not a regular file: {path}")
	if before.st_size > max_bytes:
		raise ValueError(f"File exceeds the {max_bytes}-byte budget: {path}")
	try:
		with path.open("rb") as stream:
			opened_before = os.fstat(stream.fileno())
			raw = stream.read(max_bytes + 1)
			opened_after = os.fstat(stream.fileno())
		after = path.lstat()
	except OSError as exc:
		raise ValueError(f"File is unreadable: {path}: {exc}") from exc
	if len(raw) > max_bytes:
		raise ValueError(f"File exceeds the {max_bytes}-byte budget: {path}")
	if not (
		_same_file_snapshot(before, opened_before)
		and _same_file_snapshot(opened_before, opened_after)
		and _same_file_snapshot(opened_after, after)
	):
		raise ValueError(f"File identity changed while it was read: {path}")
	if len(raw) != opened_before.st_size:
		raise ValueError(f"File length changed while it was read: {path}")
	return raw


def read_bounded_text(path: Path, max_bytes: int) -> str:
	"""Read strict UTF-8 text without universal-newline normalization."""
	try:
		return read_bounded_bytes(path, max_bytes).decode("utf-8", errors="strict")
	except UnicodeDecodeError as exc:
		raise ValueError(f"File is not valid UTF-8: {path}: {exc}") from exc


def read_json_object(path: Path, max_bytes: int = DEFAULT_MAX_JSON_BYTES) -> dict[str, Any]:
	if max_bytes <= 0:
		raise ValueError("JSON byte budget must be positive.")
	try:
		raw = read_bounded_bytes(path, max_bytes)
		value = strict_json_loads(raw.decode("utf-8", errors="strict"))
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		raise ValueError(f"JSON file is unreadable: {path}: {exc}") from exc
	if not isinstance(value, dict):
		raise ValueError(f"JSON root must be an object: {path}")
	return value


def strict_json_loads(source: str) -> Any:
	try:
		return json.loads(
			source,
			parse_constant=_reject_json_constant,
			object_pairs_hook=_strict_json_object,
		)
	except RecursionError as exc:
		raise ValueError("JSON nesting exceeds the parser limit.") from exc


def canonical_json_bytes(value: Any) -> bytes:
	return json.dumps(
		value,
		ensure_ascii=False,
		sort_keys=True,
		separators=(",", ":"),
		allow_nan=False,
	).encode("utf-8")


def atomic_write_text(path: Path, text: str) -> None:
	atomic_write_bytes(path, text.encode("utf-8"))


def atomic_write_bytes(path: Path, data: bytes) -> None:
	_reject_linked_write_path(path)
	path.parent.mkdir(parents=True, exist_ok=True)
	_reject_linked_write_path(path)
	temporary = path.parent / f".{path.name}.gf-ai-{os.getpid()}-{secrets.token_hex(8)}.tmp"
	try:
		with temporary.open("xb") as stream:
			stream.write(data)
			stream.flush()
			os.fsync(stream.fileno())
		_reject_linked_write_path(path)
		os.replace(temporary, path)
		_fsync_parent_directory(path)
	finally:
		if temporary.exists():
			temporary.unlink()


def atomic_write_json(path: Path, value: Any) -> None:
	text = json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
	atomic_write_text(path, text)


def atomic_compare_exchange_json(path: Path, expected_sha256: str, value: Any) -> str:
	"""Atomically replace JSON after cooperative locking and two source comparisons."""
	if not isinstance(expected_sha256, str) or len(expected_sha256) != 64 or any(
		character not in "0123456789abcdef" for character in expected_sha256
	):
		raise CompareExchangeError("Expected JSON SHA-256 must be 64 lowercase hexadecimal characters.")
	target_sha256 = sha256_json(value)
	data = (json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")
	lock_path = path.with_name(f".{path.name}.gf-ai-migration.lock")
	temporary = path.parent / f".{path.name}.gf-ai-{os.getpid()}-{secrets.token_hex(8)}.tmp"
	lock_stream = None
	lock_owned = False
	_reject_linked_write_path(path)
	path.parent.mkdir(parents=True, exist_ok=True)
	_reject_linked_write_path(path)
	try:
		_reject_linked_write_path(lock_path)
		try:
			lock_stream = lock_path.open("xb")
		except FileExistsError as exc:
			raise CompareExchangeError(f"Project contract migration lock already exists: {lock_path}") from exc
		lock_owned = True
		lock_stream.write(f"pid={os.getpid()}\n".encode("ascii"))
		lock_stream.flush()
		os.fsync(lock_stream.fileno())
		if _json_sha256_at_path(path) != expected_sha256:
			raise CompareExchangeError("Project contract changed before compare-exchange started.")
		with temporary.open("xb") as stream:
			stream.write(data)
			stream.flush()
			os.fsync(stream.fileno())
		_reject_linked_write_path(path)
		if _json_sha256_at_path(path) != expected_sha256:
			raise CompareExchangeError("Project contract changed during compare-exchange.")
		os.replace(temporary, path)
		_fsync_parent_directory(path)
		if _json_sha256_at_path(path) != target_sha256:
			raise CompareExchangeError("Migrated project contract target hash verification failed.")
		return target_sha256
	finally:
		if lock_stream is not None:
			lock_stream.close()
		if temporary.exists():
			temporary.unlink()
		if lock_owned and lock_path.exists():
			lock_path.unlink()


def sha256_bytes(value: bytes) -> str:
	import hashlib

	return hashlib.sha256(value).hexdigest()


def sha256_json(value: Any) -> str:
	return sha256_bytes(canonical_json_bytes(value))


def _reject_linked_write_path(path: Path) -> None:
	current = path
	while True:
		if _path_is_link_or_reparse(current):
			raise PathBoundaryError(f"Refusing to write through a linked or reparsed path: {current}")
		if current.parent == current:
			break
		current = current.parent


def _path_is_link_or_reparse(path: Path) -> bool:
	try:
		metadata = path.lstat()
	except FileNotFoundError:
		return False
	except OSError:
		return True
	if path.is_symlink():
		return True
	reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
	return bool(reparse_flag and getattr(metadata, "st_file_attributes", 0) & reparse_flag)


def _same_file_snapshot(left: os.stat_result, right: os.stat_result) -> bool:
	return (
		stat.S_IFMT(left.st_mode),
		left.st_dev,
		left.st_ino,
		left.st_size,
		getattr(left, "st_mtime_ns", None),
	) == (
		stat.S_IFMT(right.st_mode),
		right.st_dev,
		right.st_ino,
		right.st_size,
		getattr(right, "st_mtime_ns", None),
	)


def _json_sha256_at_path(path: Path) -> str:
	return sha256_json(read_json_object(path, max_bytes=1024 * 1024))


def _fsync_parent_directory(path: Path) -> None:
	if os.name == "nt":
		return
	flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0)
	descriptor = os.open(path.parent, flags)
	try:
		os.fsync(descriptor)
	finally:
		os.close(descriptor)


def _reject_json_constant(value: str) -> Any:
	raise ValueError(f"Non-finite JSON number is not allowed: {value}.")


def _strict_json_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
	result: dict[str, Any] = {}
	for key, value in pairs:
		if key in result:
			raise ValueError(f"Duplicate JSON object key is not allowed: {key!r}.")
		result[key] = value
	return result
