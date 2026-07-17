#!/usr/bin/env python3
"""Internal GF package cache policy and filesystem artifact store."""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import shutil
from pathlib import Path
from typing import Any

import gf_path_security


SCRIPT_PATH = Path(__file__).resolve()
ROOT = SCRIPT_PATH.parents[1]
SCHEMA_PATH = ROOT / "addons/gf/kernel/package/gf_package_cache_schema.json"
SCHEMA = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
SCHEMA_VERSION = int(SCHEMA["schema_version"])
LAYOUT_VERSION = int(SCHEMA["layout_version"])
MARKER_FILE = str(SCHEMA["marker_file"])
MARKER_KIND = str(SCHEMA["marker_kind"])
DEFAULT_MODE = str(SCHEMA["default_mode"])
CACHE_MODES = tuple(str(value) for value in SCHEMA["modes"])
MODE_PROJECT_LOCAL = "project_local"
MODE_EXTERNAL_READ_ONLY = "external_read_only"
MODE_EXTERNAL_SHARED_RW = "external_shared_rw"
CREATED_BY = "gf_package_manager"
LOCAL_CACHE_RELATIVE_PATH = Path(".gf/package_cache")
WORKSPACE_RELATIVE_PATH = Path(".gf/package_workspace")


def resolve_context(project_root: Path, cache_dir: str, cache_mode: str, issues: list[str]) -> dict[str, Any]:
	project_root = gf_path_security.absolute_lexical_path(project_root)
	local_root = gf_path_security.absolute_lexical_path(project_root / LOCAL_CACHE_RELATIVE_PATH)
	workspace_root = gf_path_security.absolute_lexical_path(project_root / WORKSPACE_RELATIVE_PATH)
	mode = cache_mode.strip() or DEFAULT_MODE
	context = make_context(mode, local_root, workspace_root, project_root)
	if gf_path_security.path_has_reparse_component(project_root):
		issues.append(f"Package cache project root crosses a filesystem link: {project_root.as_posix()}")
		return context
	if project_root.exists() and not project_root.is_dir():
		issues.append(f"Package cache project root is not a directory: {project_root.as_posix()}")
		return context
	for label, owned_root in (("cache", local_root), ("workspace", workspace_root)):
		if not context_path_is_safe(project_root, owned_root):
			issues.append(f"Project package {label} root crosses a filesystem link or leaves project_root: {owned_root.as_posix()}")
	if issues:
		return context
	if mode not in CACHE_MODES:
		issues.append(f"Unsupported package cache mode: {mode}")
		return context
	requested = cache_dir.strip()
	if mode == MODE_PROJECT_LOCAL:
		if requested:
			requested_root = resolve_cache_path(project_root, requested)
			if requested_root != local_root:
				issues.append(f"project_local cache mode only permits the project-owned cache directory: {local_root.as_posix()}")
				return context
		configure_project_local_context(context, local_root)
		validate_existing_local_marker(local_root, context, issues)
		return context
	if not requested:
		issues.append("External package cache mode requires cache_dir.")
		return context
	requested_path = Path(requested)
	if not requested_path.is_absolute():
		issues.append(f"External package cache directory must be an absolute path: {requested}")
		return context
	external_root = gf_path_security.absolute_lexical_path(requested_path)
	if gf_path_security.path_is_inside_lexical(project_root, external_root):
		issues.append("External package cache directory must be outside project_root; use project_local mode for project-owned cache.")
		return context
	if gf_path_security.path_has_reparse_component(external_root):
		issues.append(f"External package cache directory crosses a filesystem link: {external_root.as_posix()}")
		return context
	context["external"] = True
	context["external_root"] = external_root
	context["marker_path"] = external_root / MARKER_FILE
	if not validate_marker(external_root, issues):
		return context
	context["marker_valid"] = True
	if mode == MODE_EXTERNAL_READ_ONLY:
		context["read_only"] = True
		context["artifact_read_roots"] = [external_root, local_root]
		context["artifact_write_root"] = local_root
		validate_existing_local_marker(local_root, context, issues)
	else:
		context["artifact_read_roots"] = [external_root]
		context["artifact_write_root"] = external_root
	return context


def initialize_external_cache(cache_dir: str) -> dict[str, Any]:
	issues: list[str] = []
	created = False
	normalized_root: Path | None = None
	requested = cache_dir.strip()
	if not requested:
		issues.append("External package cache directory is required.")
	else:
		candidate = Path(requested)
		if not candidate.is_absolute():
			issues.append(f"External package cache directory must be an absolute path: {requested}")
		else:
			normalized_root = gf_path_security.absolute_lexical_path(candidate)
			if not cache_root_is_safe(normalized_root):
				issues.append(f"Refusing to initialize unsafe package cache root: {normalized_root.as_posix()}")
			elif gf_path_security.path_has_reparse_component(normalized_root):
				issues.append(f"Package cache root crosses a filesystem link: {normalized_root.as_posix()}")
			elif normalized_root.is_file():
				issues.append(f"Package cache root is a file: {normalized_root.as_posix()}")
			elif normalized_root.is_dir():
				marker_path = normalized_root / MARKER_FILE
				if marker_path.is_file():
					validate_marker(normalized_root, issues)
				elif any(normalized_root.iterdir()):
					issues.append(
						f"Refusing to claim a non-empty directory without a GF package cache marker: {normalized_root.as_posix()}"
					)
				else:
					created = write_marker(normalized_root, issues)
			else:
				try:
					normalized_root.mkdir(parents=True)
				except OSError as error:
					issues.append(f"Could not create package cache directory: {error}")
				else:
					created = write_marker(normalized_root, issues)
	marker_path_text = (normalized_root / MARKER_FILE).as_posix() if normalized_root else ""
	return {
		"schema_version": SCHEMA_VERSION,
		"ok": not issues,
		"operation": "cache_init",
		"cache_dir": normalized_root.as_posix() if normalized_root else "",
		"marker_path": marker_path_text,
		"created": created,
		"issue_count": len(issues),
		"issues": issues,
	}


def make_context(mode: str, local_root: Path, workspace_root: Path, project_root: Path | None = None) -> dict[str, Any]:
	return {
		"schema_version": SCHEMA_VERSION,
		"mode": mode,
		"external": False,
		"read_only": False,
		"external_root": None,
		"artifact_read_roots": [],
		"artifact_write_root": None,
		"workspace_root": workspace_root,
		"marker_path": local_root / MARKER_FILE,
		"marker_valid": False,
		"project_root": project_root,
		"local_root": local_root,
	}


def configure_project_local_context(context: dict[str, Any], local_root: Path) -> None:
	context["artifact_read_roots"] = [local_root]
	context["artifact_write_root"] = local_root
	context["marker_path"] = local_root / MARKER_FILE


def make_report(context: dict[str, Any]) -> dict[str, Any]:
	return {
		"schema_version": SCHEMA_VERSION,
		"mode": str(context.get("mode", DEFAULT_MODE)),
		"external": bool(context.get("external", False)),
		"read_only": bool(context.get("read_only", False)),
		"artifact_read_roots": [Path(root).as_posix() for root in context.get("artifact_read_roots", [])],
		"artifact_write_root": path_text(context.get("artifact_write_root")),
		"workspace_root": path_text(context.get("workspace_root")),
		"marker_path": path_text(context.get("marker_path")),
		"marker_valid": bool(context.get("marker_valid", False)),
	}


def find_artifact(context: dict[str, Any], expected_sha: str, expected_size: int, suffix: str) -> Path | None:
	normalized_sha = expected_sha.strip().lower()
	if not is_sha256(normalized_sha) or expected_size <= 0 or not is_safe_suffix(suffix):
		return None
	for read_root in context.get("artifact_read_roots", []):
		root_path = Path(read_root)
		candidate = artifact_path(root_path, normalized_sha, suffix)
		if not context_path_is_safe(root_path, candidate):
			continue
		if artifact_matches(candidate, normalized_sha, expected_size):
			return candidate
	return None


def commit_artifact(
	context: dict[str, Any],
	source_path: Path,
	expected_sha: str,
	expected_size: int,
	suffix: str,
	issues: list[str],
) -> Path | None:
	normalized_sha = expected_sha.strip().lower()
	if not is_sha256(normalized_sha) or expected_size <= 0:
		issues.append("Package cache artifact requires a full sha256 and positive size.")
		return None
	if not is_safe_suffix(suffix):
		issues.append(f"Package cache artifact suffix is unsafe: {suffix}")
		return None
	if not artifact_matches(source_path, normalized_sha, expected_size):
		issues.append(f"Package cache artifact source does not match expected sha256 and size: {source_path.as_posix()}")
		return None
	write_root = context.get("artifact_write_root")
	if not isinstance(write_root, Path):
		issues.append("Package cache context does not permit artifact writes.")
		return None
	if not ensure_write_root(context, issues):
		return None
	target_path = artifact_path(write_root, normalized_sha, suffix)
	if not context_path_is_safe(write_root, target_path):
		issues.append(f"Package cache artifact target crosses a filesystem link: {target_path.as_posix()}")
		return None
	if artifact_matches(target_path, normalized_sha, expected_size):
		return target_path
	target_path.parent.mkdir(parents=True, exist_ok=True)
	if not context_path_is_safe(write_root, target_path):
		issues.append(f"Package cache artifact target became unsafe before write: {target_path.as_posix()}")
		return None
	temp_path = target_path.with_name(f"{target_path.name}.tmp-{os.getpid()}-{secrets.token_hex(8)}")
	try:
		shutil.copyfile(source_path, temp_path)
		if not artifact_matches(temp_path, normalized_sha, expected_size):
			raise OSError("copied artifact failed integrity verification")
		os.replace(temp_path, target_path)
	except OSError as error:
		try_unlink(temp_path)
		if artifact_matches(target_path, normalized_sha, expected_size):
			return target_path
		issues.append(f"Could not finalize package cache artifact: {error}")
		return None
	return target_path


def artifact_path(cache_root: Path, expected_sha: str, suffix: str) -> Path:
	normalized_sha = expected_sha.strip().lower()
	return cache_root / "objects" / "sha256" / normalized_sha[:2] / f"{normalized_sha}{suffix}"


def make_workspace_temp_path(context: dict[str, Any], category: str, suffix: str) -> Path:
	workspace_root = Path(context["workspace_root"])
	safe_suffix = suffix if is_safe_suffix(suffix) else ""
	target_path = workspace_root / safe_segment(category) / f"{os.getpid()}-{secrets.token_hex(12)}{safe_suffix}"
	if not context_path_is_safe(workspace_root, target_path):
		raise ValueError(f"Package workspace path crosses a filesystem link: {target_path.as_posix()}")
	return target_path


def workspace_path(context: dict[str, Any], category: str, key: str, suffix: str) -> Path:
	workspace_root = Path(context["workspace_root"])
	safe_suffix = suffix if is_safe_suffix(suffix) else ""
	target_path = workspace_root / safe_segment(category) / f"{safe_segment(key)}{safe_suffix}"
	if not context_path_is_safe(workspace_root, target_path):
		raise ValueError(f"Package workspace path crosses a filesystem link: {target_path.as_posix()}")
	return target_path


def validate_existing_local_marker(
	local_root: Path,
	context: dict[str, Any],
	issues: list[str],
) -> None:
	marker_path = local_root / MARKER_FILE
	if not marker_path.is_file():
		return
	if validate_marker(local_root, issues):
		context["marker_valid"] = True


def ensure_write_root(context: dict[str, Any], issues: list[str]) -> bool:
	write_root = context.get("artifact_write_root")
	if not isinstance(write_root, Path):
		issues.append("Package cache context does not permit artifact writes.")
		return False
	if not context_path_is_safe(write_root, write_root):
		issues.append(f"Package cache write root crosses a filesystem link: {write_root.as_posix()}")
		return False
	project_root = context.get("project_root")
	local_root = context.get("local_root")
	if isinstance(project_root, Path) and isinstance(local_root, Path) and write_root == local_root:
		if not context_path_is_safe(project_root, write_root):
			issues.append(f"Project-local package cache root leaves project_root: {write_root.as_posix()}")
			return False
	mode = str(context.get("mode", DEFAULT_MODE))
	if mode == MODE_EXTERNAL_SHARED_RW:
		return validate_marker(write_root, issues)
	marker_path = write_root / MARKER_FILE
	valid = validate_marker(write_root, issues) if marker_path.is_file() else write_marker(write_root, issues)
	if valid and mode == MODE_PROJECT_LOCAL:
		context["marker_valid"] = True
	return valid


def validate_marker(cache_root: Path, issues: list[str]) -> bool:
	marker_path = cache_root / MARKER_FILE
	if not context_path_is_safe(cache_root, marker_path):
		issues.append(f"Package cache marker crosses a filesystem link: {marker_path.as_posix()}")
		return False
	if not marker_path.is_file():
		issues.append(f"External package cache is missing its GF marker; initialize it explicitly: {cache_root.as_posix()}")
		return False
	try:
		marker = json.loads(marker_path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		issues.append(f"Package cache marker is invalid: {marker_path.as_posix()}: {error}")
		return False
	if not isinstance(marker, dict):
		issues.append(f"Package cache marker is not a JSON object: {marker_path.as_posix()}")
		return False
	valid = True
	checks = (
		(marker.get("schema_version") == SCHEMA_VERSION, "schema_version"),
		(marker.get("kind") == MARKER_KIND, "kind"),
		(marker.get("layout_version") == LAYOUT_VERSION, "layout_version"),
		(isinstance(marker.get("cache_id"), str) and bool(marker["cache_id"].strip()), "cache_id"),
		(marker.get("created_by") == CREATED_BY, "created_by"),
	)
	for accepted, field_name in checks:
		if not accepted:
			issues.append(f"Package cache marker {field_name} is invalid: {marker_path.as_posix()}")
			valid = False
	return valid


def write_marker(cache_root: Path, issues: list[str]) -> bool:
	if gf_path_security.path_has_reparse_component(cache_root):
		issues.append(f"Package cache root crosses a filesystem link: {cache_root.as_posix()}")
		return False
	try:
		cache_root.mkdir(parents=True, exist_ok=True)
		marker_path = cache_root / MARKER_FILE
		if not context_path_is_safe(cache_root, marker_path):
			issues.append(f"Package cache marker target crosses a filesystem link: {marker_path.as_posix()}")
			return False
		temp_path = marker_path.with_name(f"{marker_path.name}.tmp-{os.getpid()}-{secrets.token_hex(8)}")
		marker = {
			"schema_version": SCHEMA_VERSION,
			"kind": MARKER_KIND,
			"layout_version": LAYOUT_VERSION,
			"cache_id": secrets.token_hex(32),
			"created_by": CREATED_BY,
		}
		with temp_path.open("w", encoding="utf-8", newline="\n") as handle:
			json.dump(marker, handle, ensure_ascii=False, indent=2)
			handle.write("\n")
			handle.flush()
			os.fsync(handle.fileno())
		os.replace(temp_path, marker_path)
	except OSError as error:
		if "temp_path" in locals():
			try_unlink(temp_path)
		issues.append(f"Could not write package cache marker: {error}")
		return False
	return True


def artifact_matches(path: Path, expected_sha: str, expected_size: int) -> bool:
	try:
		return (
			not gf_path_security.path_has_reparse_component(path)
			and path.is_file()
			and path.stat().st_size == expected_size
			and sha256_file(path) == expected_sha
		)
	except OSError:
		return False


def sha256_file(path: Path) -> str:
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def resolve_cache_path(project_root: Path, value: str) -> Path:
	path = Path(value)
	if not path.is_absolute():
		path = project_root / path
	return gf_path_security.absolute_lexical_path(path)


def is_sha256(value: str) -> bool:
	return len(value) == 64 and all(character in "0123456789abcdef" for character in value)


def is_safe_suffix(value: str) -> bool:
	return not value or (value.startswith(".") and len(value) <= 16 and not any(token in value for token in ("/", "\\", ":")))


def safe_segment(value: str) -> str:
	result = "".join(character if character.isascii() and (character.isalnum() or character in {"-", "_"}) else "-" for character in value)
	return result.strip("-") or "item"


def cache_root_is_safe(path: Path) -> bool:
	text = path.as_posix()
	return bool(text) and path != path.parent and len(text) >= 4


def context_path_is_safe(root: Path, target: Path) -> bool:
	root_path = gf_path_security.absolute_lexical_path(root)
	target_path = gf_path_security.absolute_lexical_path(target)
	return (
		gf_path_security.path_is_inside_lexical(root_path, target_path)
		and not gf_path_security.path_has_reparse_component(root_path)
		and not gf_path_security.path_has_reparse_component(target_path)
	)


def path_text(value: Any) -> str:
	return value.as_posix() if isinstance(value, Path) else ""


def try_unlink(path: Path) -> None:
	try:
		path.unlink()
	except OSError:
		pass
