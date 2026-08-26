#!/usr/bin/env python3
"""Load and validate GF's internal module ownership descriptors.

The filename is retained for internal imports. This module no longer builds archives,
registries, package sources, presets, or offline bundles.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import gf_path_security
from gf_package_paths import normalize_manifest_path as normalize_shared_manifest_path
from gf_package_paths import path_matches_any_manifest_path as shared_path_matches_any_manifest_path
from gf_package_paths import portable_literal_path_identity as shared_portable_literal_path_identity
from gf_package_paths import portable_manifest_path_identity as shared_portable_manifest_path_identity


ROOT = Path(__file__).resolve().parents[1]
PACKAGE_ROOT = ROOT / "packages"
BLOCKED_DIR_NAMES = {".git", ".godot", ".import", ".vs", "__pycache__", "node_modules"}
BLOCKED_FILE_NAMES = {".DS_Store", "Thumbs.db"}
BLOCKED_SUFFIXES = {".import", ".pyc", ".pyo", ".tmp", ".log"}
PACKAGE_SCHEMA_VERSION = 1
PACKAGE_MANIFEST_MAX_BYTES = 1024 * 1024
PACKAGE_MANIFEST_MAX_DEPTH = 32
PACKAGE_MANIFEST_MAX_NODES = 4096
PACKAGE_MANIFEST_ALLOWED_FIELDS = {
	"schema_version",
	"id",
	"kind",
	"dependencies",
	"exclude_paths",
	"paths",
	"gf_extension_id",
}
PACKAGE_KINDS = {"kernel", "standard", "extension", "tool"}


def main() -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(
		description="Validate GF internal module ownership descriptors."
	)
	parser.add_argument("--json", action="store_true", help="Print JSON output.")
	args = parser.parse_args()
	result = load_package_manifests()
	result["ok"] = not result["issues"]
	result["module_count"] = len(result["records"])
	if args.json:
		print(json.dumps(result, ensure_ascii=False, indent=2))
	else:
		print(f"ok={result['ok']} modules={result['module_count']}")
		for issue in result["issues"]:
			print(f"- {issue}")
	return 0 if result["ok"] else 1


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def load_package_manifests() -> dict[str, Any]:
	records: list[dict[str, Any]] = []
	issues: list[str] = []
	seen_ids: dict[str, str] = {}
	for path in sorted(PACKAGE_ROOT.rglob("*.json")):
		relative_path = path.relative_to(ROOT).as_posix()
		data = read_manifest_data(path, relative_path, issues)
		if data is None:
			continue
		issues.extend(audit_manifest_fields(data, relative_path))
		record = manifest_record(data, relative_path)
		module_id = record["id"]
		if module_id:
			previous_path = seen_ids.get(module_id)
			if previous_path:
				issues.append(
					f"{relative_path}: module id {module_id!r} is already declared "
					f"by {previous_path}."
				)
			else:
				seen_ids[module_id] = relative_path
		records.append(record)
	declared_ids = {record["id"] for record in records if record["id"]}
	for record in records:
		for dependency_id in record["dependencies"]:
			if dependency_id not in declared_ids:
				issues.append(
					f"{record['path']}: dependency module is not declared: "
					f"{dependency_id}."
				)
	return {"records": records, "issues": issues}


def read_manifest_data(
	path: Path,
	relative_path: str,
	issues: list[str],
) -> dict[str, Any] | None:
	if gf_path_security.path_has_reparse_component(path):
		issues.append(
			f"{relative_path}: module descriptor crosses a symlink, junction, "
			"or reparse point."
		)
		return None
	try:
		manifest_text = gf_path_security.read_pinned_utf8_regular_file(
			ROOT,
			relative_path,
			max_bytes=PACKAGE_MANIFEST_MAX_BYTES,
		)
	except gf_path_security.PinnedReadError as error:
		issues.append(
			f"{relative_path}: module descriptor is not a stable contained "
			f"UTF-8 regular file: {error.rule_id}."
		)
		return None
	try:
		data = json.loads(
			manifest_text,
			parse_constant=reject_non_finite_json_constant,
			object_pairs_hook=reject_duplicate_json_object_keys,
		)
	except RecursionError:
		issues.append(
			f"{relative_path}: module descriptor nesting exceeds "
			f"{PACKAGE_MANIFEST_MAX_DEPTH}."
		)
		return None
	except (json.JSONDecodeError, ValueError) as error:
		issues.append(f"{relative_path}: invalid module descriptor JSON: {error}")
		return None
	structure_issue = package_manifest_structure_issue(data)
	if structure_issue:
		issues.append(f"{relative_path}: {structure_issue}.")
		return None
	if not isinstance(data, dict):
		issues.append(f"{relative_path}: module descriptor root must be an object.")
		return None
	return data


def audit_manifest_fields(data: dict[str, Any], relative_path: str) -> list[str]:
	issues: list[str] = []
	for field_name in sorted(set(data) - PACKAGE_MANIFEST_ALLOWED_FIELDS):
		issues.append(
			f"{relative_path}: unsupported module descriptor field: {field_name}."
		)
	if (
		type(data.get("schema_version")) is not int
		or data["schema_version"] != PACKAGE_SCHEMA_VERSION
	):
		issues.append(
			f"{relative_path}: schema_version must be the integer "
			f"{PACKAGE_SCHEMA_VERSION}."
		)
	module_id = string_value(data.get("id", ""))
	if not module_id or module_id != data.get("id"):
		issues.append(f"{relative_path}: canonical module id is required.")
	kind = string_value(data.get("kind", ""))
	if kind not in PACKAGE_KINDS:
		issues.append(
			f"{relative_path}: module kind must be one of "
			f"{', '.join(sorted(PACKAGE_KINDS))}."
		)
	issues.extend(string_array_issues(module_id or relative_path, "dependencies", data.get("dependencies")))
	issues.extend(
		portable_manifest_path_list_issues(
			module_id or relative_path,
			"paths",
			data.get("paths"),
		)
	)
	issues.extend(
		portable_manifest_path_list_issues(
			module_id or relative_path,
			"exclude_paths",
			data.get("exclude_paths", []),
		)
	)
	if not string_array(data.get("paths")):
		issues.append(f"{relative_path}: module descriptor must own at least one path.")
	extension_id = string_value(data.get("gf_extension_id", ""))
	if kind == "extension" and not extension_id:
		issues.append(
			f"{relative_path}: extension module must declare gf_extension_id."
		)
	if kind != "extension" and "gf_extension_id" in data:
		issues.append(
			f"{relative_path}: only extension modules may declare gf_extension_id."
		)
	return issues


def manifest_record(data: dict[str, Any], relative_path: str) -> dict[str, Any]:
	return {
		"path": relative_path,
		"id": string_value(data.get("id", "")),
		"kind": string_value(data.get("kind", "")),
		"gf_extension_id": string_value(data.get("gf_extension_id", "")),
		"dependencies": string_array(data.get("dependencies", [])),
		"paths": string_array(data.get("paths", [])),
		"exclude_paths": string_array(data.get("exclude_paths", [])),
	}


def reject_non_finite_json_constant(value: str) -> Any:
	raise ValueError(f"non-finite JSON number is forbidden: {value}")


def reject_duplicate_json_object_keys(
	pairs: list[tuple[str, Any]],
) -> dict[str, Any]:
	result: dict[str, Any] = {}
	for key, value in pairs:
		if key in result:
			raise ValueError(f"duplicate JSON object key is forbidden: {key}")
		result[key] = value
	return result


def package_manifest_structure_issue(value: Any) -> str:
	stack: list[tuple[Any, int]] = [(value, 1)]
	node_count = 0
	while stack:
		current, depth = stack.pop()
		if depth > PACKAGE_MANIFEST_MAX_DEPTH:
			return f"module descriptor nesting exceeds {PACKAGE_MANIFEST_MAX_DEPTH}"
		node_count += 1
		if node_count > PACKAGE_MANIFEST_MAX_NODES:
			return (
				f"module descriptor structure exceeds "
				f"{PACKAGE_MANIFEST_MAX_NODES} JSON values"
			)
		if isinstance(current, dict):
			stack.extend(
				(nested, depth + 1)
				for nested in reversed(list(current.values()))
			)
		elif isinstance(current, list):
			stack.extend((nested, depth + 1) for nested in reversed(current))
	return ""


def collect_package_files(
	record: dict[str, Any],
	issues: list[str] | None = None,
) -> list[Path]:
	result_issues = issues if issues is not None else []
	files: list[Path] = []
	seen_identities: dict[str, Path] = {}
	exclude_patterns = record.get("exclude_paths", [])
	path_issues = portable_manifest_path_list_issues(
		record["id"],
		"paths",
		record.get("paths"),
	)
	path_issues.extend(portable_manifest_path_list_issues(
		record["id"],
		"exclude_paths",
		exclude_patterns,
	))
	if path_issues:
		result_issues.extend(path_issues)
		return files
	for raw_pattern in record["paths"]:
		pattern = normalize_manifest_path(raw_pattern)
		for path in expand_manifest_path(pattern):
			if gf_path_security.path_has_reparse_component(path):
				result_issues.append(
					f"{record['id']}: module source crosses a symlink, junction, "
					f"or reparse point: {relative_display_path(path)}"
				)
				continue
			if not path.is_file() or is_blocked_path(path):
				continue
			try:
				resolved_path = path.resolve(strict=True)
				resolved_path.relative_to(ROOT.resolve(strict=True))
			except (OSError, ValueError):
				result_issues.append(
					f"{record['id']}: module source leaves the repository root: "
					f"{path.as_posix()}"
				)
				continue
			relative_path = path.relative_to(ROOT).as_posix()
			if not is_windows_portable_relative_path(relative_path):
				result_issues.append(
					f"{record['id']}: module source is not portable: {relative_path}"
				)
				continue
			if path_matches_any_manifest_path(relative_path, exclude_patterns):
				continue
			identity = portable_path_identity(relative_path)
			previous = seen_identities.get(identity)
			if previous is not None and previous != path:
				result_issues.append(
					f"{record['id']}: module sources collide under portable path "
					f"rules: {previous.relative_to(ROOT).as_posix()} and "
					f"{relative_path}"
				)
				continue
			seen_identities[identity] = path
			if path not in files:
				files.append(path)
	return sorted(files, key=lambda item: item.relative_to(ROOT).as_posix())


def expand_manifest_path(pattern: str) -> list[Path]:
	normalized = normalize_manifest_path(pattern)
	if not normalized:
		return []
	module_source_root = gf_path_security.absolute_lexical_path(ROOT / "addons/gf")
	if not has_glob(normalized):
		path = gf_path_security.absolute_lexical_path(ROOT / normalized)
		if (
			gf_path_security.path_is_inside_lexical(module_source_root, path)
			and path.exists()
		):
			return [path]
		return []
	static_parts: list[str] = []
	for part in normalized.split("/"):
		if has_glob(part):
			break
		static_parts.append(part)
	search_root = gf_path_security.absolute_lexical_path(ROOT.joinpath(*static_parts))
	if gf_path_security.path_is_inside_lexical(search_root, module_source_root):
		search_root = module_source_root
	if (
		not gf_path_security.path_is_inside_lexical(module_source_root, search_root)
		or gf_path_security.path_has_reparse_component(search_root)
		or not search_root.is_dir()
	):
		return []
	return sorted(
		path
		for path in search_root.rglob("*")
		if path_matches_any_manifest_path(
			path.relative_to(ROOT).as_posix(),
			[normalized],
		)
	)


def normalize_manifest_path(path: str) -> str:
	return normalize_shared_manifest_path(path)


def is_windows_portable_relative_path(path: str) -> bool:
	return bool(shared_portable_literal_path_identity(path))


def portable_path_identity(path: str) -> str:
	return shared_portable_literal_path_identity(path)


def portable_manifest_path_list_issues(
	module_id: str,
	field_name: str,
	value: Any,
) -> list[str]:
	if not isinstance(value, list):
		return [f"{module_id}: module descriptor {field_name} must be an array."]
	issues: list[str] = []
	seen_identities: set[str] = set()
	for raw_path in value:
		if (
			not isinstance(raw_path, str)
			or not raw_path
			or raw_path != raw_path.strip()
		):
			issues.append(
				f"{module_id}: module descriptor {field_name} must contain "
				"canonical non-empty strings."
			)
			continue
		identity = shared_portable_manifest_path_identity(raw_path)
		if not identity:
			issues.append(
				f"{module_id}: module descriptor {field_name} contains an "
				f"unsafe or non-portable path: {raw_path}"
			)
			continue
		if identity in seen_identities:
			issues.append(
				f"{module_id}: module descriptor {field_name} contains a "
				f"duplicate portable path: {raw_path}"
			)
			continue
		seen_identities.add(identity)
	return issues


def string_array_issues(module_id: str, field_name: str, value: Any) -> list[str]:
	if not isinstance(value, list):
		return [f"{module_id}: module descriptor {field_name} must be an array."]
	issues: list[str] = []
	seen: set[str] = set()
	for item in value:
		if not isinstance(item, str) or not item or item != item.strip():
			issues.append(
				f"{module_id}: module descriptor {field_name} must contain "
				"canonical non-empty strings."
			)
			continue
		if item in seen:
			issues.append(
				f"{module_id}: module descriptor {field_name} contains "
				f"duplicate value: {item}."
			)
		seen.add(item)
	return issues


def path_matches_any_manifest_path(path: str, patterns: list[str]) -> bool:
	return shared_path_matches_any_manifest_path(path, patterns)


def is_blocked_path(path: Path) -> bool:
	relative_parts = path.relative_to(ROOT).parts
	if any(part in BLOCKED_DIR_NAMES for part in relative_parts):
		return True
	if path.name in BLOCKED_FILE_NAMES:
		return True
	return path.suffix in BLOCKED_SUFFIXES


def has_glob(path: str) -> bool:
	return any(token in path for token in ("*", "?"))


def relative_display_path(path: Path) -> str:
	try:
		return path.relative_to(ROOT).as_posix()
	except ValueError:
		return path.as_posix()


def string_value(value: Any) -> str:
	return value.strip() if isinstance(value, str) else ""


def string_array(value: Any) -> list[str]:
	if not isinstance(value, list):
		return []
	return [item.strip() for item in value if isinstance(item, str) and item.strip()]


if __name__ == "__main__":
	raise SystemExit(main())
