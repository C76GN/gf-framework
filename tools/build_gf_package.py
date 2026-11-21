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

import gf_module_descriptors as descriptors
import gf_path_security
from gf_package_paths import normalize_manifest_path as normalize_shared_manifest_path
from gf_package_paths import path_matches_any_manifest_path as shared_path_matches_any_manifest_path
from gf_package_paths import portable_literal_path_identity as shared_portable_literal_path_identity


ROOT = Path(__file__).resolve().parents[1]
PACKAGE_ROOT = ROOT / "packages"
BLOCKED_DIR_NAMES = {".git", ".godot", ".import", ".vs", "__pycache__", "node_modules"}
BLOCKED_FILE_NAMES = {".DS_Store", "Thumbs.db"}
BLOCKED_SUFFIXES = {".import", ".pyc", ".pyo", ".tmp", ".log"}
PACKAGE_MANIFEST_ALLOWED_FIELDS = descriptors.ALLOWED_FIELDS


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


def load_package_manifests(root: Path | None = None) -> dict[str, Any]:
	package_root = PACKAGE_ROOT if root is None else root / "packages"
	root = ROOT if root is None else root
	records: list[dict[str, Any]] = []
	issues: list[str] = []
	seen_ids: dict[str, str] = {}
	for path in sorted(path for path in package_root.rglob("*") if path.suffix.lower() == ".json" and not path.is_dir()):
		relative_path = path.relative_to(root).as_posix()
		record, problems = descriptors.read_descriptor(root, relative_path)
		issues.extend(f"{relative_path}: {problem['message']}" for problem in problems)
		if not record["id"]:
			continue
		module_id = record["id"]
		previous_path = seen_ids.get(module_id)
		if previous_path:
			issues.append(f"{relative_path}: module id {module_id!r} is already declared by {previous_path}.")
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


def audit_manifest_fields(data: dict[str, Any], relative_path: str) -> list[str]:
	_, issues = descriptors.descriptor_fields(data, relative_path)
	return [f"{relative_path}: {problem['message']}" for problem in issues]


def collect_file_owners(records: list[dict[str, Any]], root: Path) -> dict[str, str]:
	"""Expand the filesystem candidates once and apply the same ownership rules as maintenance."""
	index = descriptors.PackageOwnershipIndex(descriptors.collect_package_source_owner_entries(records))
	owners: dict[str, str] = {}
	portable_paths: dict[str, str] = {}
	for record in records:
		issues: list[str] = []
		files = collect_package_files(record, issues, root=root)
		if issues:
			raise ValueError(f"Package {record['id']} is invalid: " + "; ".join(issues[:10]))
		for path in files:
			relative = path.relative_to(root).as_posix()
			previous = portable_paths.setdefault(portable_path_identity(relative), relative)
			if previous != relative:
				raise ValueError(f"Module sources collide under portable path rules: {previous} and {relative}")
			matches = index.find_owners(relative)
			if len(matches) != 1:
				ids = [match["package_id"] for match in matches]
				raise ValueError(f"Source must belong to exactly one package: {relative} -> {ids}")
			owners[relative] = matches[0]["package_id"]
	return owners


def collect_package_files(
	record: dict[str, Any],
	issues: list[str] | None = None,
	*, root: Path | None = None,
) -> list[Path]:
	root = ROOT if root is None else root
	resolved_root = root.resolve(strict=True)
	result_issues = issues if issues is not None else []
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
		return []
	for raw_pattern in record["paths"]:
		pattern = normalize_manifest_path(raw_pattern)
		for path in expand_manifest_path(pattern, root):
			relative_path = path.relative_to(root).as_posix()
			if gf_path_security.path_has_reparse_component(path):
				result_issues.append(
					f"{record['id']}: module source crosses a symlink, junction, "
					f"or reparse point: {relative_path}"
				)
				continue
			if not path.is_file() or is_blocked_path(path, root):
				continue
			try:
				resolved_path = path.resolve(strict=True)
				resolved_path.relative_to(resolved_root)
			except (OSError, ValueError):
				result_issues.append(
					f"{record['id']}: module source leaves the repository root: "
					f"{path.as_posix()}"
				)
				continue
			if not is_windows_portable_relative_path(relative_path):
				result_issues.append(
					f"{record['id']}: module source is not portable: {relative_path}"
				)
				continue
			if path_matches_any_manifest_path(relative_path, exclude_patterns):
				continue
			identity = portable_path_identity(relative_path)
			previous = seen_identities.get(identity)
			if previous is not None and previous.as_posix() != path.as_posix():
				result_issues.append(
					f"{record['id']}: module sources collide under portable path "
					f"rules: {previous.relative_to(root).as_posix()} and "
					f"{relative_path}"
				)
				continue
			seen_identities[identity] = path
	return sorted(seen_identities.values(), key=lambda item: item.relative_to(root).as_posix())


def expand_manifest_path(pattern: str, root: Path) -> list[Path]:
	normalized = normalize_manifest_path(pattern)
	if not normalized:
		return []
	module_source_root = gf_path_security.absolute_lexical_path(root / "addons/gf")
	if not has_glob(normalized):
		path = descriptors.exact_source_path(root, normalized)
		if (
			path is not None and gf_path_security.path_is_inside_lexical(module_source_root, path)
		):
			return [path]
		return []
	static_parts: list[str] = []
	for part in normalized.split("/"):
		if has_glob(part):
			break
		static_parts.append(part)
	search_root = descriptors.exact_source_path(root, "/".join(static_parts))
	if search_root is None:
		return []
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
			path.relative_to(root).as_posix(),
			[normalized],
		)
	)


def normalize_manifest_path(path: str) -> str:
	return normalize_shared_manifest_path(path)


def is_windows_portable_relative_path(path: str) -> bool:
	return bool(shared_portable_literal_path_identity(path))


def portable_path_identity(path: str) -> str:
	return shared_portable_literal_path_identity(path)


def portable_manifest_path_list_issues(module_id: str, field_name: str, value: Any) -> list[str]:
	_, issues = descriptors.array_field(value, module_id, field_name)
	return [f"{module_id}: {problem['message']}" for problem in issues]


def path_matches_any_manifest_path(path: str, patterns: list[str]) -> bool:
	return shared_path_matches_any_manifest_path(path, patterns)


def is_blocked_path(path: Path, root: Path) -> bool:
	relative_parts = path.relative_to(root).parts
	if any(part in BLOCKED_DIR_NAMES for part in relative_parts):
		return True
	if path.name in BLOCKED_FILE_NAMES:
		return True
	return path.suffix in BLOCKED_SUFFIXES


def has_glob(path: str) -> bool:
	return any(token in path for token in ("*", "?"))


if __name__ == "__main__":
	raise SystemExit(main())
