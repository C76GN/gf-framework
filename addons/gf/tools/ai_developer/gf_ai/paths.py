"""Path validation and atomic UTF-8 persistence helpers."""

from __future__ import annotations

import json
import os
import secrets
from pathlib import Path
from typing import Any


DEFAULT_MAX_JSON_BYTES = 16 * 1024 * 1024


class PathBoundaryError(ValueError):
	"""Raised when a project-side operation would escape its owned boundary."""


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
	target = (project_root / Path(*parts)).resolve(strict=False)
	try:
		target.relative_to(project_root)
	except ValueError as exc:
		raise PathBoundaryError(f"Project path escapes the project root: {relative_path!r}") from exc
	if must_exist and not target.exists():
		raise PathBoundaryError(f"Project path does not exist: {relative_path!r}")
	return target


def read_json_object(path: Path, max_bytes: int = DEFAULT_MAX_JSON_BYTES) -> dict[str, Any]:
	if max_bytes <= 0:
		raise ValueError("JSON byte budget must be positive.")
	try:
		with path.open("rb") as stream:
			raw = stream.read(max_bytes + 1)
		if len(raw) > max_bytes:
			raise ValueError(f"JSON file exceeds the {max_bytes}-byte budget: {path}")
		value = strict_json_loads(raw.decode("utf-8", errors="strict"))
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		raise ValueError(f"JSON file is unreadable: {path}: {exc}") from exc
	if not isinstance(value, dict):
		raise ValueError(f"JSON root must be an object: {path}")
	return value


def strict_json_loads(source: str) -> Any:
	return json.loads(
		source,
		parse_constant=_reject_json_constant,
		object_pairs_hook=_strict_json_object,
	)


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
		os.replace(temporary, path)
	finally:
		if temporary.exists():
			temporary.unlink()


def atomic_write_json(path: Path, value: Any) -> None:
	text = json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n"
	atomic_write_text(path, text)


def sha256_bytes(value: bytes) -> str:
	import hashlib

	return hashlib.sha256(value).hexdigest()


def sha256_json(value: Any) -> str:
	return sha256_bytes(canonical_json_bytes(value))


def _reject_linked_write_path(path: Path) -> None:
	current = path.parent
	while True:
		if current.exists() and current.is_symlink():
			raise PathBoundaryError(f"Refusing to write through a linked directory: {current}")
		if current.parent == current:
			break
		current = current.parent
	if path.exists() and path.is_symlink():
		raise PathBoundaryError(f"Refusing to replace a linked file: {path}")


def _reject_json_constant(value: str) -> Any:
	raise ValueError(f"Non-finite JSON number is not allowed: {value}.")


def _strict_json_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
	result: dict[str, Any] = {}
	for key, value in pairs:
		if key in result:
			raise ValueError(f"Duplicate JSON object key is not allowed: {key!r}.")
		result[key] = value
	return result
