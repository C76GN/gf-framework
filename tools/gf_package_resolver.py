#!/usr/bin/env python3
"""Plan GF package installs/uninstalls against a registry and lockfile."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

import gf_path_security
from gf_package_paths import normalize_manifest_path as normalize_shared_manifest_path
from gf_package_paths import path_matches_any_manifest_path as shared_path_matches_any_manifest_path
from gf_semver import parse_semver, reaches_exclusive_compatibility_bound


def find_workspace_root(start: Path, fallback: Path) -> Path:
	current = start.resolve()
	while True:
		if (current / "addons/gf/plugin.cfg").is_file():
			return current
		if current == current.parent:
			return fallback.resolve()
		current = current.parent


SCRIPT_PATH = Path(__file__).resolve()
ROOT = find_workspace_root(SCRIPT_PATH.parent, SCRIPT_PATH.parents[1])
LOCKFILE_SCHEMA_VERSION = 1
REGISTRY_SCHEMA_VERSION = 2
VALID_REASONS = {"manual", "dependency", "preset", "bundled", "dev"}
PROTECTED_REASONS = {"manual", "preset", "bundled", "dev"}
PROJECT_TEXT_SCAN_EXTENSIONS = {".cfg", ".gd", ".godot", ".json", ".tres", ".tscn"}
PROJECT_BINARY_RESOURCE_EXTENSIONS = {".res", ".scn"}
PROJECT_SCAN_EXTENSIONS = PROJECT_TEXT_SCAN_EXTENSIONS | PROJECT_BINARY_RESOURCE_EXTENSIONS
MAX_BINARY_RESOURCE_SCAN_BYTES = 64 * 1024 * 1024
PROJECT_SCAN_EXCLUDED_PREFIXES = (
	".git/",
	".gf/",
	".godot/",
	".import/",
	"addons/gf/",
	"addons/gut/",
	"ai_analysis/",
	"build/",
)
PACKAGE_TREE_IGNORED_DIR_NAMES = {".git", ".godot", ".import", "__pycache__"}
PACKAGE_TREE_IGNORED_FILE_NAMES = {".DS_Store", "Thumbs.db"}
PACKAGE_TREE_IGNORED_SUFFIXES = {".import", ".pyc", ".pyo", ".tmp", ".log"}
UNSUPPORTED_REGISTRY_PACKAGE_SIGNATURE_FIELDS = {
	"public_key",
	"public_keys",
	"registry_signature",
	"registry_signature_algorithm",
	"registry_signature_sha256",
	"registry_signature_size_bytes",
	"registry_signature_url",
	"registry_signing_key_id",
	"signature",
	"signature_algorithm",
	"signature_public_key",
	"signature_sha256",
	"signature_url",
	"signing_key",
	"signing_key_id",
	"signing_keys",
}
PACKAGE_ID_PART_RE = re.compile(r"^[a-z0-9_-]+$")


def main() -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(description="Plan GF package installs and uninstalls.")
	subparsers = parser.add_subparsers(dest="command", required=True)

	install_parser = subparsers.add_parser("install-plan", help="Resolve package dependencies without mutating installed state.")
	install_parser.add_argument("packages", nargs="*", help="Package ids to install.")
	add_common_args(install_parser)
	install_parser.add_argument("--reason", choices=sorted(VALID_REASONS - {"dependency"}), default="manual")
	install_parser.add_argument("--all-concrete", action="store_true", help="Install every non-preset package selected by the registry.")
	install_parser.add_argument("--kind", action="append", default=[], help="Install packages matching one or more comma-separated package kinds.")
	install_parser.add_argument("--exclude-kind", action="append", default=[], help="Exclude packages matching one or more comma-separated package kinds.")

	update_parser = subparsers.add_parser("update-plan", help="Plan updates for packages already present in the lockfile.")
	update_parser.add_argument("packages", nargs="*", help="Installed package ids to update.")
	add_common_args(update_parser)
	update_parser.add_argument("--all-installed", action="store_true", help="Update every installed package that is present in the registry.")

	uninstall_parser = subparsers.add_parser("uninstall-plan", help="Plan safe package removal from a lockfile.")
	uninstall_parser.add_argument("packages", nargs="+", help="Package ids to uninstall.")
	add_common_args(uninstall_parser)
	uninstall_parser.add_argument("--project-root", default=".", help="Project root to scan for references before removal.")
	uninstall_parser.add_argument("--force", action="store_true", help="Ignore required_by/protected reason/reference blockers.")

	verify_parser = subparsers.add_parser("verify-lock", help="Validate lockfile consistency with a registry.")
	add_common_args(verify_parser)
	verify_parser.add_argument(
		"--project-root",
		default="",
		help="Project root used to verify installed file content. Canonical .gf lockfiles infer it automatically.",
	)

	args = parser.parse_args()
	if args.command == "install-plan":
		result = install_plan(
			registry_path=args.registry,
			lockfile_path=args.lockfile,
			package_ids=args.packages,
			reason=args.reason,
			all_concrete=args.all_concrete,
			include_kinds=split_selector_values(args.kind),
			exclude_kinds=split_selector_values(args.exclude_kind),
			current_framework_version=args.current_framework_version,
		)
	elif args.command == "update-plan":
		result = update_plan(
			registry_path=args.registry,
			lockfile_path=args.lockfile,
			package_ids=args.packages,
			all_installed=args.all_installed,
			current_framework_version=args.current_framework_version,
		)
	elif args.command == "uninstall-plan":
		result = uninstall_plan(
			registry_path=args.registry,
			lockfile_path=args.lockfile,
			package_ids=args.packages,
			project_root=args.project_root,
			force=args.force,
		)
	else:
		result = verify_lock(
			registry_path=args.registry,
			lockfile_path=args.lockfile,
			project_root=args.project_root,
		)
	print_result(result, args.json)
	return 0 if result["ok"] else 1


def add_common_args(parser: argparse.ArgumentParser) -> None:
	parser.add_argument("--registry", required=True, help="Registry index JSON path.")
	parser.add_argument("--lockfile", default=".gf/packages.lock.json", help="Project package lockfile path.")
	parser.add_argument("--current-framework-version", default="", help="Current target project GF version. Empty allows bootstrap installs.")
	parser.add_argument("--json", action="store_true", help="Print JSON instead of text.")


def configure_stdio() -> None:
	for stream in (sys.stdin, sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="replace")


def split_selector_values(values: list[str]) -> list[str]:
	result: list[str] = []
	for value in values:
		for item in value.split(","):
			trimmed_item = item.strip()
			if trimmed_item:
				append_unique(result, trimmed_item)
	return result


def install_plan(
	registry_path: str,
	lockfile_path: str,
	package_ids: list[str],
	reason: str,
	all_concrete: bool = False,
	include_kinds: list[str] | None = None,
	exclude_kinds: list[str] | None = None,
	current_framework_version: str = "",
) -> dict[str, Any]:
	registry = load_registry(resolve_path(registry_path))
	lockfile = load_lockfile(resolve_path(lockfile_path))
	issues = [*registry["issues"], *lockfile["issues"]]
	if reason not in VALID_REASONS or reason == "dependency":
		issues.append(f"Invalid install reason: {reason}")
	target_package_ids = collect_install_targets(
		package_ids,
		registry["packages"],
		all_concrete,
		include_kinds or [],
		exclude_kinds or [],
		issues,
	)
	if issues:
		result = make_plan_result(False, "install", [], [], [], [], issues, lockfile["data"], lockfile_path)
		result["requested_packages"] = target_package_ids
		return result

	closure = resolve_dependency_closure(registry["packages"], target_package_ids)
	if closure["issues"]:
		result = make_plan_result(False, "install", [], [], [], [], closure["issues"], lockfile["data"], lockfile_path)
		result["requested_packages"] = target_package_ids
		return result
	compatibility_issues = framework_compatibility_issues(
		registry,
		registry["packages"],
		closure["order"],
		current_framework_version,
	)
	if compatibility_issues:
		result = make_plan_result(False, "install", [], [], [], [], compatibility_issues, lockfile["data"], lockfile_path)
		result["requested_packages"] = target_package_ids
		return result

	original_installed = copy.deepcopy(lockfile["data"]["installed"])
	installed = copy.deepcopy(original_installed)
	requested_package_ids = set(target_package_ids)
	for package_id in closure["order"]:
		registry_entry = registry["packages"][package_id]
		entry = make_lock_entry(registry_entry, package_id)
		existing = installed.get(package_id, {})
		reasons = set(string_array(existing.get("reason", [])))
		if isinstance(existing, dict) and string_array(existing.get("files", [])):
			entry["files"] = string_array(existing.get("files", []))
		if isinstance(existing, dict) and isinstance(existing.get("file_metadata"), dict) and existing["file_metadata"]:
			entry["file_metadata"] = copy.deepcopy(existing["file_metadata"])
		if package_id in requested_package_ids:
			reasons.add(reason)
		elif package_id == "gf.kernel":
			reasons.add("bundled")
		else:
			reasons.add("dependency")
		entry["reason"] = sorted(reasons)
		installed[package_id] = entry
	recompute_required_by(installed, registry["packages"])
	planned_lock = make_lockfile(lockfile["data"], installed, registry["framework_version"], {"source": registry_path})
	to_install = [package_id for package_id in closure["order"] if package_id not in original_installed]
	to_update = [
		package_id
		for package_id in closure["order"]
		if package_id in original_installed
		and lock_entry_payload_changed(original_installed[package_id], installed[package_id])
	]
	result = make_plan_result(
		True,
		"install",
		closure["order"],
		to_install,
		to_update,
		[],
		[],
		planned_lock,
		lockfile_path,
	)
	result["requested_packages"] = target_package_ids
	return result


def update_plan(
	registry_path: str,
	lockfile_path: str,
	package_ids: list[str],
	all_installed: bool,
	current_framework_version: str = "",
) -> dict[str, Any]:
	registry = load_registry(resolve_path(registry_path))
	lockfile = load_lockfile(resolve_path(lockfile_path))
	issues = [*registry["issues"], *lockfile["issues"]]
	if issues:
		return make_plan_result(False, "update", [], [], [], [], issues, lockfile["data"], lockfile_path)

	registry_packages = registry["packages"]
	installed = lockfile["data"]["installed"]
	target_ids = collect_update_targets(package_ids, all_installed, installed, registry_packages, issues)
	if issues:
		return make_plan_result(False, "update", [], [], [], [], issues, lockfile["data"], lockfile_path)
	if not target_ids:
		planned_lock = make_lockfile(lockfile["data"], installed, registry["framework_version"], {"source": registry_path})
		return make_plan_result(True, "update", [], [], [], [], [], planned_lock, lockfile_path)

	closure = resolve_dependency_closure(registry_packages, target_ids)
	if closure["issues"]:
		return make_plan_result(False, "update", [], [], [], [], closure["issues"], lockfile["data"], lockfile_path)
	compatibility_issues = framework_compatibility_issues(
		registry,
		registry_packages,
		closure["order"],
		current_framework_version,
	)
	if compatibility_issues:
		return make_plan_result(False, "update", [], [], [], [], compatibility_issues, lockfile["data"], lockfile_path)

	original_installed = copy.deepcopy(installed)
	updated_installed = copy.deepcopy(original_installed)
	for package_id in closure["order"]:
		registry_entry = registry_packages[package_id]
		entry = make_lock_entry(registry_entry, package_id)
		existing = updated_installed.get(package_id, {})
		reasons = set(string_array(existing.get("reason", []))) if isinstance(existing, dict) else set()
		if isinstance(existing, dict) and string_array(existing.get("files", [])):
			entry["files"] = string_array(existing.get("files", []))
		if isinstance(existing, dict) and isinstance(existing.get("file_metadata"), dict) and existing["file_metadata"]:
			entry["file_metadata"] = copy.deepcopy(existing["file_metadata"])
		if not reasons:
			reasons.add("bundled" if package_id == "gf.kernel" else "dependency")
		entry["reason"] = sorted(reasons)
		updated_installed[package_id] = entry
	recompute_required_by(updated_installed, registry_packages)
	planned_lock = make_lockfile(lockfile["data"], updated_installed, registry["framework_version"], {"source": registry_path})
	to_install = [package_id for package_id in closure["order"] if package_id not in original_installed]
	to_update = [
		package_id
		for package_id in closure["order"]
		if package_id in original_installed
		and lock_entry_payload_changed(original_installed[package_id], updated_installed[package_id])
	]
	return make_plan_result(
		True,
		"update",
		closure["order"],
		to_install,
		to_update,
		[],
		[],
		planned_lock,
		lockfile_path,
	)


def uninstall_plan(
	registry_path: str,
	lockfile_path: str,
	package_ids: list[str],
	project_root: str,
	force: bool,
) -> dict[str, Any]:
	resolved_project_root = gf_path_security.absolute_lexical_path(resolve_path(project_root))
	registry = load_registry(resolve_path(registry_path))
	lockfile = load_lockfile(resolve_path(lockfile_path))
	issues = [*registry["issues"], *lockfile["issues"]]
	if not resolved_project_root.is_dir() or gf_path_security.path_has_reparse_component(resolved_project_root):
		issues.append(f"Project root is missing or crosses a filesystem link: {normalize_display_path(resolved_project_root)}")
	if issues:
		return make_plan_result(False, "uninstall", [], [], [], [], issues, lockfile["data"], lockfile_path)

	installed = copy.deepcopy(lockfile["data"]["installed"])
	blocked: list[dict[str, Any]] = []
	to_remove: list[str] = []
	for package_id in package_ids:
		entry = installed.get(package_id)
		if not isinstance(entry, dict):
			blocked.append({"id": package_id, "reason": "not_installed"})
			continue
		reasons = set(string_array(entry.get("reason", [])))
		required_by = string_array(entry.get("required_by", []))
		protected = sorted((reasons & (PROTECTED_REASONS - {"manual"})))
		references = scan_project_references(resolved_project_root, registry["packages"], package_id)
		if required_by and not force:
			blocked.append({"id": package_id, "reason": "required_by", "required_by": required_by})
			continue
		if protected and not force:
			blocked.append({"id": package_id, "reason": "protected_reason", "protected_reasons": protected})
			continue
		if references and not force:
			blocked.append({"id": package_id, "reason": "project_references", "references": references[:20]})
			continue
		append_unique(to_remove, package_id)
	if blocked:
		return make_plan_result(False, "uninstall", [], [], [], [], ["Uninstall blocked."], lockfile["data"], lockfile_path, blocked=blocked)

	for package_id in to_remove:
		installed.pop(package_id, None)
	recompute_required_by(installed, registry["packages"])
	prune_blocked = collect_dependency_prune_blockers(
		installed,
		registry["packages"],
		resolved_project_root,
		force=force,
	)
	if prune_blocked:
		return make_plan_result(
			False,
			"uninstall",
			[],
			[],
			[],
			[],
			["Uninstall blocked."],
			lockfile["data"],
			lockfile_path,
			blocked=prune_blocked,
		)
	pruned = prune_dependency_only_packages(installed, registry["packages"], force=force)
	planned_lock = make_lockfile(lockfile["data"], installed, registry["framework_version"])
	return make_plan_result(
		True,
		"uninstall",
		[],
		[],
		[],
		[to_remove_item for to_remove_item in [*to_remove, *pruned]],
		[],
		planned_lock,
		lockfile_path,
		blocked=[],
	)


def verify_lock(registry_path: str, lockfile_path: str, project_root: str = "") -> dict[str, Any]:
	resolved_lockfile_path = resolve_path(lockfile_path)
	registry = load_registry(resolve_path(registry_path))
	lockfile = load_lockfile(resolved_lockfile_path)
	issues = [*registry["issues"], *lockfile["issues"], *lockfile_schema_issues(lockfile["data"])]
	installed = lockfile["data"]["installed"]
	lockfile_framework_version = str(lockfile["data"].get("framework_version", "")).strip()
	registry_framework_version = str(registry.get("framework_version", "")).strip()
	if lockfile_framework_version and registry_framework_version and lockfile_framework_version != registry_framework_version:
		issues.append(
			"Lockfile framework_version differs from registry framework_version: "
			f"{lockfile_framework_version} != {registry_framework_version}"
		)
	expected = copy.deepcopy(installed)
	recompute_required_by(expected, registry["packages"])
	for package_id, entry in installed.items():
		registry_entry = registry["packages"].get(package_id)
		if registry_entry is None:
			issues.append(f"Installed package is missing from registry: {package_id}")
			continue
		if entry.get("sha256", "") != registry_entry.get("sha256", ""):
			issues.append(f"Installed package sha256 differs from registry: {package_id}")
		if sorted(string_array(entry.get("required_by", []))) != sorted(string_array(expected.get(package_id, {}).get("required_by", []))):
			issues.append(f"Installed package required_by is stale: {package_id}")
	resolved_project_root = resolve_verify_project_root(project_root, resolved_lockfile_path, issues)
	issues.extend(installed_state_issues(installed, registry["packages"], resolved_project_root))
	return make_plan_result(len(issues) == 0, "verify", [], [], [], [], issues, lockfile["data"], lockfile_path)


def resolve_verify_project_root(project_root: str, lockfile_path: Path, issues: list[str]) -> Path | None:
	if project_root.strip():
		resolved = gf_path_security.absolute_lexical_path(resolve_path(project_root))
		if not resolved.is_dir() or gf_path_security.path_has_reparse_component(resolved):
			issues.append(f"Project root is missing or crosses a filesystem link: {normalize_display_path(resolved)}")
			return None
		return resolved
	if lockfile_path.name != "packages.lock.json" or lockfile_path.parent.name != ".gf":
		return None
	inferred_root = gf_path_security.absolute_lexical_path(lockfile_path.parent.parent)
	if gf_path_security.path_has_reparse_component(inferred_root):
		issues.append(f"Inferred project root crosses a filesystem link: {normalize_display_path(inferred_root)}")
		return None
	if not (inferred_root / "project.godot").is_file():
		return None
	return inferred_root


def installed_state_issues(
	installed: dict[str, Any],
	registry_packages: dict[str, dict[str, Any]],
	project_root: Path | None = None,
) -> list[str]:
	issues: list[str] = []
	valid_entries: dict[str, dict[str, Any]] = {}
	owners_by_file: dict[str, list[str]] = {}
	for package_id in sorted(installed.keys()):
		lock_entry = installed.get(package_id)
		registry_entry = registry_packages.get(package_id)
		if not isinstance(lock_entry, dict) or not isinstance(registry_entry, dict):
			continue
		identity_issues = lock_entry_identity_issues(package_id, lock_entry, registry_entry)
		issues.extend(identity_issues)
		if str(registry_entry.get("kind", "")) == "preset":
			continue
		entry_issues, files, metadata = validate_installed_entry(package_id, lock_entry, registry_entry)
		issues.extend(entry_issues)
		for relative_path in files:
			owners_by_file.setdefault(relative_path, []).append(package_id)
		if not entry_issues and not identity_issues:
			valid_entries[package_id] = {
				"files": files,
				"file_metadata": metadata,
				"owned_tree_scan_allowed": lock_entry_matches_registry_identity(lock_entry, registry_entry),
			}

	for relative_path in sorted(owners_by_file.keys()):
		owners = sorted(set(owners_by_file[relative_path]))
		if len(owners) > 1:
			issues.append(
				f"Installed file is owned by multiple packages: {relative_path}: {', '.join(owners)}"
			)

	if project_root is None:
		return issues
	issues.extend(installed_file_integrity_issues(valid_entries, project_root))
	issues.extend(extra_owned_tree_file_issues(valid_entries, registry_packages, project_root))
	return issues


def lockfile_schema_issues(lockfile: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	allowed_fields = {"schema_version", "framework_version", "installed", "registry_source"}
	required_fields = {"schema_version", "framework_version", "installed"}
	for field_name in sorted(required_fields - set(lockfile)):
		issues.append(f"Lockfile is missing required field: {field_name}")
	for field_name in sorted(set(lockfile) - allowed_fields):
		issues.append(f"Lockfile contains unsupported field: {field_name}")
	if type(lockfile.get("schema_version")) is not int or lockfile.get("schema_version") != LOCKFILE_SCHEMA_VERSION:
		issues.append(f"Lockfile schema_version must be the integer {LOCKFILE_SCHEMA_VERSION}.")
	if not isinstance(lockfile.get("framework_version"), str):
		issues.append("Lockfile framework_version must be a string.")
	if not isinstance(lockfile.get("installed"), dict):
		issues.append("Lockfile installed must be an object.")
	if "registry_source" in lockfile and not isinstance(lockfile.get("registry_source"), dict):
		issues.append("Lockfile registry_source must be an object when present.")
	elif isinstance(lockfile.get("registry_source"), dict):
		issues.extend(lockfile_registry_source_schema_issues(lockfile["registry_source"]))
	return issues


def lockfile_registry_source_schema_issues(source: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	allowed_fields = {
		"source",
		"source_manifest",
		"channel",
		"offline_bundle",
		"registry_sha256",
		"remote",
		"mirror_index",
		"registry_size_bytes",
	}
	for field_name in sorted(set(source) - allowed_fields):
		issues.append(f"Lockfile registry_source contains unsupported field: {field_name}")
	for field_name in ("source", "source_manifest", "channel", "offline_bundle", "registry_sha256"):
		if field_name in source and not isinstance(source[field_name], str):
			issues.append(f"Lockfile registry_source {field_name} must be a string.")
	if "registry_sha256" in source and not is_sha256_hex(str(source.get("registry_sha256", ""))):
		issues.append("Lockfile registry_source registry_sha256 must be a full SHA-256.")
	if "remote" in source and type(source["remote"]) is not bool:
		issues.append("Lockfile registry_source remote must be boolean.")
	if "mirror_index" in source and (
		type(source["mirror_index"]) is not int or int(source["mirror_index"]) < -1
	):
		issues.append("Lockfile registry_source mirror_index must be an integer greater than or equal to -1.")
	if "registry_size_bytes" in source and (
		type(source["registry_size_bytes"]) is not int or int(source["registry_size_bytes"]) < 0
	):
		issues.append("Lockfile registry_source registry_size_bytes must be a non-negative integer.")
	return issues


def lock_entry_identity_issues(
	package_id: str,
	lock_entry: dict[str, Any],
	registry_entry: dict[str, Any],
) -> list[str]:
	issues: list[str] = []
	common_fields = {"version", "kind", "reason", "required_by", "paths", "archive", "sha256"}
	optional_fields = {"gf_extension_id"}
	if str(registry_entry.get("kind", "")) == "preset":
		required_fields = common_fields | {"packages"}
		allowed_fields = required_fields | optional_fields
	else:
		required_fields = common_fields | {"files", "file_metadata"}
		allowed_fields = required_fields | optional_fields
	for field_name in sorted(required_fields - set(lock_entry)):
		issues.append(f"Installed package lockfile entry is missing required field: {package_id}.{field_name}")
	for field_name in sorted(set(lock_entry) - allowed_fields):
		issues.append(f"Installed package lockfile entry contains unsupported field: {package_id}.{field_name}")

	for field_name in ("version", "kind", "archive", "sha256"):
		if not isinstance(lock_entry.get(field_name), str):
			issues.append(f"Installed package lockfile entry {field_name} must be a string: {package_id}")
	for field_name in ("reason", "required_by", "paths"):
		value = lock_entry.get(field_name)
		if not valid_string_array(value):
			issues.append(f"Installed package lockfile entry {field_name} must be an array of unique non-empty strings: {package_id}")
	reasons = string_array(lock_entry.get("reason", []))
	for reason in reasons:
		if reason not in VALID_REASONS:
			issues.append(f"Installed package lockfile entry contains invalid reason: {package_id}: {reason}")
	for required_by_id in string_array(lock_entry.get("required_by", [])):
		if not package_id_is_valid(required_by_id):
			issues.append(f"Installed package lockfile entry contains invalid required_by id: {package_id}: {required_by_id}")

	identity_fields = ("version", "kind", "archive", "sha256")
	for field_name in identity_fields:
		if lock_entry.get(field_name) != registry_entry.get(field_name, ""):
			issues.append(f"Installed package {field_name} differs from registry: {package_id}")
	lock_paths = string_array(lock_entry.get("paths", []))
	registry_paths = string_array(registry_entry.get("paths", []))
	if lock_paths != registry_paths:
		issues.append(f"Installed package paths differ from registry: {package_id}")
	for path in lock_paths:
		if normalize_manifest_path(path) != path or not portable_manifest_path_identity(path):
			issues.append(f"Installed package path identity is unsafe: {package_id}: {path}")

	registry_extension_id = str(registry_entry.get("gf_extension_id", ""))
	lock_extension_id = lock_entry.get("gf_extension_id", "")
	if not isinstance(lock_extension_id, str) or lock_extension_id != registry_extension_id:
		issues.append(f"Installed package gf_extension_id differs from registry: {package_id}")
	if str(registry_entry.get("kind", "")) == "preset":
		if not valid_string_array(lock_entry.get("packages")):
			issues.append(f"Installed preset packages must be an array of unique non-empty strings: {package_id}")
		elif string_array(lock_entry.get("packages")) != string_array(registry_entry.get("packages", [])):
			issues.append(f"Installed preset packages differ from registry: {package_id}")
	return issues


def valid_string_array(value: Any) -> bool:
	return (
		isinstance(value, list)
		and all(isinstance(item, str) and bool(item) and item == item.strip() for item in value)
		and len(value) == len(set(value))
	)


def validate_installed_entry(
	package_id: str,
	lock_entry: dict[str, Any],
	registry_entry: dict[str, Any],
) -> tuple[list[str], list[str], dict[str, Any]]:
	issues: list[str] = []
	raw_files = lock_entry.get("files")
	if raw_files is None or raw_files == []:
		issues.append(f"Installed package lockfile entry is missing files list: {package_id}")
		return issues, [], {}
	if not isinstance(raw_files, list) or any(not isinstance(item, str) or not item.strip() for item in raw_files):
		issues.append(f"Installed package lockfile entry files must be an array of non-empty strings: {package_id}")
		return issues, [], {}
	files = [item for item in raw_files]
	file_identities = [portable_package_path_identity(path) for path in files]
	if any(not identity for identity in file_identities) or len(file_identities) != len(set(file_identities)):
		issues.append(f"Installed package lockfile entry files must not contain duplicates: {package_id}")

	metadata = lock_entry.get("file_metadata")
	if not isinstance(metadata, dict):
		issues.append(f"Installed package lockfile entry file_metadata must be an object: {package_id}")
		return issues, files, {}
	file_set = set(files)
	metadata_set = set(metadata.keys())
	metadata_identities = [portable_package_path_identity(str(path)) for path in metadata_set]
	if any(not identity for identity in metadata_identities) or len(metadata_identities) != len(set(metadata_identities)):
		issues.append(f"Installed package file_metadata contains unsafe or aliased paths: {package_id}")
	for relative_path in sorted(file_set - metadata_set):
		issues.append(f"Installed package file_metadata is missing file: {package_id}: {relative_path}")
	for relative_path in sorted(metadata_set - file_set):
		issues.append(f"Installed package file_metadata contains an unlisted file: {package_id}: {relative_path}")

	manifest_paths = string_array(registry_entry.get("paths", []))
	for relative_path in sorted(file_set):
		if normalize_package_file_path(relative_path) != relative_path or not relative_path.startswith("addons/gf/"):
			issues.append(f"Installed package files entry is unsafe: {package_id}: {relative_path}")
			continue
		if not path_matches_any_manifest_path(relative_path, manifest_paths):
			issues.append(f"Installed package file is not covered by registry paths: {package_id}: {relative_path}")
		file_state = metadata.get(relative_path)
		if not valid_file_metadata(file_state):
			issues.append(f"Installed package file_metadata entry is invalid: {package_id}: {relative_path}")
	return issues, files, metadata


def installed_file_integrity_issues(valid_entries: dict[str, dict[str, Any]], project_root: Path) -> list[str]:
	issues: list[str] = []
	for package_id in sorted(valid_entries.keys()):
		entry = valid_entries[package_id]
		metadata = entry["file_metadata"]
		for relative_path in entry["files"]:
			target_path = resolve_project_target(project_root, relative_path)
			if target_path is None:
				issues.append(f"Installed package file resolves outside project root: {package_id}: {relative_path}")
				continue
			if not target_path.is_file():
				issues.append(f"Installed package file is missing: {package_id}: {relative_path}")
				continue
			file_state = metadata[relative_path]
			try:
				actual_size = target_path.stat().st_size
			except OSError as error:
				issues.append(f"Could not read installed package file: {package_id}: {relative_path}: {error}")
				continue
			if actual_size != file_state["size_bytes"]:
				issues.append(
					f"Installed package file size does not match lockfile metadata: {package_id}: {relative_path}"
				)
				continue
			try:
				actual_sha256 = sha256_file(target_path)
			except OSError as error:
				issues.append(f"Could not hash installed package file: {package_id}: {relative_path}: {error}")
				continue
			if actual_sha256 != str(file_state["sha256"]).lower():
				issues.append(
					f"Installed package file sha256 does not match lockfile metadata: {package_id}: {relative_path}"
				)
	return issues


def extra_owned_tree_file_issues(
	valid_entries: dict[str, dict[str, Any]],
	registry_packages: dict[str, dict[str, Any]],
	project_root: Path,
) -> list[str]:
	issues: list[str] = []
	listed_files = {
		relative_path
		for entry in valid_entries.values()
		for relative_path in entry["files"]
	}
	reported_files: set[str] = set()
	for package_id in sorted(valid_entries.keys()):
		if not valid_entries[package_id]["owned_tree_scan_allowed"]:
			continue
		for tree_root in exclusive_package_tree_roots(package_id, registry_packages):
			root_path = resolve_project_target(project_root, tree_root)
			if root_path is None or not root_path.is_dir() or root_path.is_symlink():
				continue
			for path in collect_package_tree_files(root_path):
				relative_path = path.relative_to(project_root).as_posix()
				if relative_path in listed_files or relative_path in reported_files:
					continue
				reported_files.add(relative_path)
				issues.append(
					f"Installed package unlisted file remains in package-owned tree: {package_id}: {relative_path}"
				)
	return issues


def lock_entry_matches_registry_identity(lock_entry: dict[str, Any], registry_entry: dict[str, Any]) -> bool:
	lock_sha256 = str(lock_entry.get("sha256", "")).strip().lower()
	registry_sha256 = str(registry_entry.get("sha256", "")).strip().lower()
	lock_paths = sorted(normalize_manifest_path(path) for path in string_array(lock_entry.get("paths", [])))
	registry_paths = sorted(normalize_manifest_path(path) for path in string_array(registry_entry.get("paths", [])))
	return (
		is_sha256_hex(lock_sha256)
		and lock_sha256 == registry_sha256
		and str(lock_entry.get("version", "")) == str(registry_entry.get("version", ""))
		and str(lock_entry.get("kind", "")) == str(registry_entry.get("kind", ""))
		and lock_paths == registry_paths
	)


def exclusive_package_tree_roots(
	package_id: str,
	registry_packages: dict[str, dict[str, Any]],
) -> list[str]:
	registry_entry = registry_packages.get(package_id, {})
	if not isinstance(registry_entry, dict):
		return []
	roots: list[str] = []
	for raw_pattern in string_array(registry_entry.get("paths", [])):
		pattern = normalize_manifest_path(raw_pattern)
		if not pattern.endswith("/**"):
			continue
		tree_root = pattern[:-3].rstrip("/")
		if (
			not tree_root.startswith("addons/gf/")
			or normalize_package_file_path(tree_root) != tree_root
			or contains_glob(tree_root)
			or not package_tree_root_is_exclusive(tree_root, package_id, registry_packages)
		):
			continue
		if any(tree_root == existing or tree_root.startswith(existing + "/") for existing in roots):
			continue
		roots = [existing for existing in roots if not existing.startswith(tree_root + "/")]
		roots.append(tree_root)
	return sorted(roots)


def package_tree_root_is_exclusive(
	tree_root: str,
	package_id: str,
	registry_packages: dict[str, dict[str, Any]],
) -> bool:
	for other_package_id, other_entry in registry_packages.items():
		if str(other_package_id) == package_id or not isinstance(other_entry, dict):
			continue
		for raw_pattern in string_array(other_entry.get("paths", [])):
			if manifest_pattern_may_overlap_tree(raw_pattern, tree_root):
				return False
	return True


def manifest_pattern_may_overlap_tree(raw_pattern: str, tree_root: str) -> bool:
	pattern = normalize_manifest_path(raw_pattern)
	if not pattern:
		return True
	if pattern.endswith("/**") and not contains_glob(pattern[:-3]):
		other_root = pattern[:-3].rstrip("/")
		return paths_overlap_as_trees(tree_root, other_root)
	if not contains_glob(pattern):
		return pattern == tree_root or pattern.startswith(tree_root + "/")
	static_prefix = re.split(r"[?*\[]", pattern, maxsplit=1)[0].rstrip("/")
	if not static_prefix:
		return True
	return (
		paths_overlap_as_trees(tree_root, static_prefix)
		or tree_root.startswith(static_prefix)
		or static_prefix.startswith(tree_root + "/")
	)


def paths_overlap_as_trees(left: str, right: str) -> bool:
	return left == right or left.startswith(right + "/") or right.startswith(left + "/")


def collect_package_tree_files(tree_root: Path) -> list[Path]:
	result: list[Path] = []
	try:
		resolved_tree_root = tree_root.resolve()
	except OSError:
		return result
	stack = [tree_root]
	while stack:
		current = stack.pop()
		try:
			children = sorted(current.iterdir(), key=lambda path: path.name)
		except OSError:
			continue
		for child in children:
			if child.is_symlink():
				continue
			if child.is_dir():
				if child.name in PACKAGE_TREE_IGNORED_DIR_NAMES:
					continue
				try:
					resolved_child = child.resolve()
				except OSError:
					continue
				if not path_is_within(resolved_child, resolved_tree_root):
					continue
				stack.append(child)
			elif child.is_file() and not package_tree_file_is_ignored(child):
				result.append(child)
	return sorted(result)


def package_tree_file_is_ignored(path: Path) -> bool:
	return path.name in PACKAGE_TREE_IGNORED_FILE_NAMES or any(
		path.name.endswith(suffix) for suffix in PACKAGE_TREE_IGNORED_SUFFIXES
	)


def resolve_project_target(project_root: Path, relative_path: str) -> Path | None:
	normalized = normalize_package_file_path(relative_path)
	if not normalized:
		return None
	project_root = gf_path_security.absolute_lexical_path(project_root)
	target_path = project_root / Path(*normalized.split("/"))
	if not gf_path_security.path_is_inside_lexical(project_root, target_path):
		return None
	if gf_path_security.path_has_reparse_component(project_root) or gf_path_security.path_has_reparse_component(target_path):
		return None
	return target_path


def path_is_within(path: Path, root: Path) -> bool:
	try:
		path.relative_to(root)
		return True
	except ValueError:
		return False


def normalize_package_file_path(path: str) -> str:
	if path != path.strip():
		return ""
	normalized = path.replace("\\", "/")
	if not normalized or normalized.startswith("/") or ":" in normalized:
		return ""
	parts = normalized.split("/")
	if any(part in {"", ".", ".."} or part != part.rstrip(" .") or any(ord(character) < 32 for character in part) for part in parts):
		return ""
	return "/".join(parts)


def portable_package_path_identity(path: str) -> str:
	normalized = normalize_package_file_path(path)
	return normalized.lower() if normalized else ""


def portable_manifest_path_identity(path: str) -> str:
	normalized = normalize_manifest_path(path)
	if not normalized or normalized != path:
		return ""
	parts = normalized.split("/")
	if any(part in {"", ".", ".."} or part != part.rstrip(" .") for part in parts):
		return ""
	return normalized.lower()


def path_matches_any_manifest_path(path: str, patterns: list[str]) -> bool:
	return shared_path_matches_any_manifest_path(path, patterns)


def contains_glob(value: str) -> bool:
	return any(character in value for character in "*?[")


def valid_file_metadata(value: Any) -> bool:
	if not isinstance(value, dict):
		return False
	if set(value) != {"sha256", "size_bytes"}:
		return False
	sha256 = value.get("sha256")
	size_bytes = value.get("size_bytes")
	return (
		isinstance(sha256, str)
		and is_sha256_hex(sha256)
		and type(size_bytes) is int
		and size_bytes >= 0
	)


def is_sha256_hex(value: str) -> bool:
	return len(value) == 64 and all(character in "0123456789abcdefABCDEF" for character in value)


def sha256_file(path: Path) -> str:
	digest = hashlib.sha256()
	with path.open("rb") as handle:
		for chunk in iter(lambda: handle.read(1024 * 1024), b""):
			digest.update(chunk)
	return digest.hexdigest()


def resolve_dependency_closure(packages: dict[str, dict[str, Any]], roots: list[str]) -> dict[str, Any]:
	order: list[str] = []
	issues: list[str] = []
	visiting: list[str] = []
	visited: set[str] = set()

	def visit(package_id: str) -> None:
		if package_id in visited:
			return
		if package_id in visiting:
			cycle = [*visiting[visiting.index(package_id):], package_id]
			issues.append("Package dependency cycle: " + " -> ".join(cycle))
			return
		if package_id not in packages:
			issues.append(f"Missing package: {package_id}")
			return
		visiting.append(package_id)
		for dependency_id in package_dependency_ids(packages[package_id]):
			visit(dependency_id)
		visiting.pop()
		visited.add(package_id)
		append_unique(order, package_id)

	for root_package_id in roots:
		visit(root_package_id)
	return {"order": order, "issues": issues}


def recompute_required_by(installed: dict[str, Any], packages: dict[str, dict[str, Any]]) -> None:
	for entry in installed.values():
		if isinstance(entry, dict):
			entry["required_by"] = []
	for package_id in sorted(installed.keys()):
		registry_entry = packages.get(package_id, {})
		for dependency_id in package_dependency_ids(registry_entry):
			if dependency_id in installed:
				append_unique(installed[dependency_id]["required_by"], package_id)
	for entry in installed.values():
		if isinstance(entry, dict):
			entry["required_by"] = sorted(string_array(entry.get("required_by", [])))


def prune_dependency_only_packages(installed: dict[str, Any], packages: dict[str, dict[str, Any]], force: bool) -> list[str]:
	pruned: list[str] = []
	changed = True
	while changed:
		changed = False
		recompute_required_by(installed, packages)
		for package_id in sorted(list(installed.keys())):
			entry = installed[package_id]
			reasons = set(string_array(entry.get("reason", [])))
			required_by = string_array(entry.get("required_by", []))
			if reasons <= {"dependency"} and not required_by:
				if package_id == "gf.kernel" and not force:
					continue
				installed.pop(package_id, None)
				append_unique(pruned, package_id)
				changed = True
	return pruned


def collect_dependency_prune_blockers(
	installed_after_requested_removal: dict[str, Any],
	packages: dict[str, dict[str, Any]],
	project_root: Path,
	force: bool,
) -> list[dict[str, Any]]:
	if force:
		return []

	installed = copy.deepcopy(installed_after_requested_removal)
	blockers: list[dict[str, Any]] = []
	changed = True
	while changed:
		changed = False
		recompute_required_by(installed, packages)
		for package_id in sorted(list(installed.keys())):
			entry = installed[package_id]
			reasons = set(string_array(entry.get("reason", [])))
			required_by = string_array(entry.get("required_by", []))
			if not (reasons <= {"dependency"} and not required_by):
				continue
			if package_id == "gf.kernel":
				continue

			references = scan_project_references(project_root, packages, package_id)
			if references:
				if not any(blocker.get("id") == package_id for blocker in blockers):
					blockers.append(
						{
							"id": package_id,
							"reason": "project_references",
							"references": references[:20],
						}
					)
				continue

			installed.pop(package_id, None)
			changed = True
	return blockers


def scan_project_references(project_root: Path, packages: dict[str, dict[str, Any]], package_id: str) -> list[dict[str, Any]]:
	package = packages.get(package_id)
	if package is None:
		return []
	path_tokens = package_path_tokens(string_array(package.get("paths", [])))
	symbols = collect_package_class_names(package, project_root)
	package_tokens = [package_id, *path_tokens, *symbols]
	if not package_tokens:
		return []
	references: list[dict[str, Any]] = []
	for path in collect_project_scan_files(project_root):
		relative_path = path.relative_to(project_root).as_posix()
		if path.suffix.lower() in PROJECT_BINARY_RESOURCE_EXTENSIONS:
			binary_symbol = binary_resource_reference_symbol(path, [package_id, *path_tokens])
			if binary_symbol:
				references.append({"path": relative_path, "symbol": binary_symbol})
			continue
		text = read_text(path)
		if not text:
			continue
		for token in package_tokens:
			if token.startswith("GF"):
				if source_contains_identifier(text, token):
					references.append({"path": relative_path, "symbol": token})
					break
			elif token in text:
				references.append({"path": relative_path, "symbol": token})
				break
	return references


def binary_resource_reference_symbol(path: Path, tokens: list[str]) -> str:
	try:
		if path.stat().st_size > MAX_BINARY_RESOURCE_SCAN_BYTES:
			return "<binary_resource_audit_limit_exceeded>"
		payload = path.read_bytes()
	except OSError:
		return "<binary_resource_audit_unavailable>"
	for token in tokens:
		if token and token.encode("utf-8") in payload:
			return token
	return ""


def collect_project_scan_files(project_root: Path) -> list[Path]:
	if not project_root.is_dir():
		return []
	files: list[Path] = []
	for path in sorted(project_root.rglob("*")):
		if gf_path_security.path_has_reparse_component(path) or not path.is_file():
			continue
		relative_path = path.relative_to(project_root).as_posix()
		if any(relative_path.startswith(prefix) for prefix in PROJECT_SCAN_EXCLUDED_PREFIXES):
			continue
		if path.suffix.lower() in PROJECT_SCAN_EXTENSIONS or path.name == "project.godot":
			files.append(path)
	return files


def collect_package_class_names(package: dict[str, Any], project_root: Path) -> list[str]:
	result: list[str] = []
	for pattern in string_array(package.get("paths", [])):
		for path in expand_source_pattern(pattern, project_root):
			if path.suffix.lower() != ".gd":
				continue
			text = read_text(path)
			for match in re.finditer(r"(?m)^\s*class_name\s+([A-Za-z_]\w*)", text):
				append_unique(result, match.group(1))
	return result


def expand_source_pattern(pattern: str, project_root: Path) -> list[Path]:
	normalized = normalize_manifest_path(pattern)
	if not normalized:
		return []
	project_root = gf_path_security.absolute_lexical_path(project_root)
	if gf_path_security.path_has_reparse_component(project_root):
		return []
	if normalized.endswith("/**") and not any(token in normalized[:-3] for token in ("*", "?", "[")):
		directory = project_root / normalized[:-3].rstrip("/")
		if not directory.is_dir():
			return []
		return sorted(
			path
			for path in directory.rglob("*")
			if path.is_file() and not gf_path_security.path_has_reparse_component(path)
		)
	if any(token in normalized for token in ("*", "?", "[")):
		return sorted(
			path
			for path in project_root.glob(normalized)
			if path.is_file() and not gf_path_security.path_has_reparse_component(path)
		)
	path = project_root / normalized
	return [path] if path.is_file() and not gf_path_security.path_has_reparse_component(path) else []


def package_path_tokens(paths: list[str]) -> list[str]:
	tokens: list[str] = []
	for path in paths:
		normalized = normalize_manifest_path(path)
		if not normalized:
			continue
		if normalized.endswith("/**"):
			normalized = normalized[:-3].rstrip("/")
		append_unique(tokens, normalized)
		append_unique(tokens, "res://" + normalized)
	return tokens


def collect_install_targets(
	package_ids: list[str],
	registry_packages: dict[str, dict[str, Any]],
	all_concrete: bool,
	include_kinds: list[str],
	exclude_kinds: list[str],
	issues: list[str],
) -> list[str]:
	result: list[str] = []
	for package_id in package_ids:
		trimmed_id = package_id.strip()
		if trimmed_id:
			append_unique(result, trimmed_id)
	for package_id in select_registry_package_ids(registry_packages, all_concrete, include_kinds, exclude_kinds):
		append_unique(result, package_id)
	if not result:
		issues.append("Missing package id or matching package selector.")
		return result
	for package_id in result:
		if package_id not in registry_packages:
			issues.append(f"Missing package: {package_id}")
	return result


def select_registry_package_ids(
	registry_packages: dict[str, dict[str, Any]],
	all_concrete: bool,
	include_kinds: list[str],
	exclude_kinds: list[str],
) -> list[str]:
	include = {item.strip() for item in include_kinds if item.strip()}
	exclude = {item.strip() for item in exclude_kinds if item.strip()}
	if not all_concrete and not include and not exclude:
		return []
	result: list[str] = []
	for package_id in sorted(registry_packages.keys()):
		entry = registry_packages.get(package_id, {})
		package_kind = str(entry.get("kind", "")) if isinstance(entry, dict) else ""
		if all_concrete and package_kind == "preset":
			continue
		if include and package_kind not in include:
			continue
		if package_kind in exclude:
			continue
		result.append(package_id)
	return result


def collect_update_targets(
	package_ids: list[str],
	all_installed: bool,
	installed: dict[str, Any],
	registry_packages: dict[str, dict[str, Any]],
	issues: list[str],
) -> list[str]:
	requested_ids = list(package_ids)
	if all_installed:
		requested_ids.extend(sorted(str(package_id) for package_id in installed.keys()))
	if not requested_ids:
		issues.append("Missing package id. Use --all-installed to update every installed package.")
		return []

	result: list[str] = []
	for package_id in requested_ids:
		package_id = package_id.strip()
		if not package_id:
			continue
		if package_id in result:
			continue
		if package_id not in installed:
			issues.append(f"Package is not installed: {package_id}. Use install to add it.")
			continue
		if package_id not in registry_packages:
			issues.append(f"Installed package is missing from registry: {package_id}")
			continue
		result.append(package_id)
	return result


def make_lock_entry(registry_entry: dict[str, Any], package_id: str) -> dict[str, Any]:
	entry = {
		"version": str(registry_entry.get("version", "")),
		"kind": str(registry_entry.get("kind", "")),
		"reason": [],
		"required_by": [],
		"paths": string_array(registry_entry.get("paths", [])),
		"archive": str(registry_entry.get("archive", "")),
		"sha256": str(registry_entry.get("sha256", "")),
	}
	if entry["kind"] == "preset":
		entry["packages"] = string_array(registry_entry.get("packages", []))
	if registry_entry.get("gf_extension_id"):
		entry["gf_extension_id"] = str(registry_entry["gf_extension_id"])
	return entry


def package_dependency_ids(registry_entry: dict[str, Any]) -> list[str]:
	if str(registry_entry.get("kind", "")) == "preset":
		return string_array(registry_entry.get("packages", []))
	return string_array(registry_entry.get("dependencies", []))


def make_lockfile(
	base_lockfile: dict[str, Any],
	installed: dict[str, Any],
	framework_version: str,
	registry_source: dict[str, Any] | None = None,
) -> dict[str, Any]:
	lockfile = {
		"schema_version": LOCKFILE_SCHEMA_VERSION,
		"framework_version": framework_version or str(base_lockfile.get("framework_version", "")),
		"installed": {package_id: installed[package_id] for package_id in sorted(installed.keys())},
	}
	source_info = make_lockfile_registry_source(base_lockfile, registry_source or {})
	if source_info:
		lockfile["registry_source"] = source_info
	return lockfile


def make_lockfile_registry_source(base_lockfile: dict[str, Any], registry_source: dict[str, Any]) -> dict[str, Any]:
	if not registry_source:
		existing = base_lockfile.get("registry_source", {})
		return dict(existing) if isinstance(existing, dict) else {}
	result: dict[str, Any] = {}
	for source_key, target_key in (
		("source", "source"),
		("registry_source_manifest", "source_manifest"),
		("channel", "channel"),
		("offline_bundle", "offline_bundle"),
		("registry_sha256", "registry_sha256"),
	):
		value = str(registry_source.get(source_key, "")).strip()
		if value:
			result[target_key] = value
	for key in ("remote",):
		if key in registry_source:
			result[key] = bool(registry_source[key])
	for key in ("mirror_index", "registry_size_bytes"):
		if key in registry_source:
			result[key] = int(registry_source[key])
	return result


def framework_compatibility_issues(
	registry: dict[str, Any],
	registry_packages: dict[str, dict[str, Any]],
	package_ids: list[str],
	current_framework_version: str,
) -> list[str]:
	current_version = current_framework_version.strip()
	if not current_version:
		return []
	issues = compatibility_range_issues(
		"registry",
		current_version,
		str(registry.get("minimum_framework_version", "")),
		str(registry.get("maximum_framework_version_exclusive", "")),
	)
	for package_id in package_ids:
		entry = registry_packages.get(package_id, {})
		issues.extend(compatibility_range_issues(
			f"package {package_id}",
			current_version,
			str(entry.get("minimum_framework_version", "")),
			str(entry.get("maximum_framework_version_exclusive", "")),
		))
	return issues


def compatibility_range_issues(label: str, current_version: str, minimum_version: str, maximum_exclusive: str) -> list[str]:
	issues: list[str] = []
	if not current_version.strip():
		return issues
	current = parse_semver(current_version)
	minimum = parse_semver(minimum_version)
	maximum = parse_semver(maximum_exclusive)
	if current is None:
		return [f"{label}: target GF framework version is not SemVer: {current_version}"]
	if minimum_version.strip() and minimum is None:
		issues.append(f"{label}: minimum_framework_version is not SemVer: {minimum_version}")
	elif minimum is not None and current < minimum:
		issues.append(
			f"{label}: target GF framework version {current_version} is lower than "
			f"minimum_framework_version {minimum_version}"
		)
	if maximum_exclusive.strip() and maximum is None:
		issues.append(f"{label}: maximum_framework_version_exclusive is not SemVer: {maximum_exclusive}")
	elif maximum is not None and reaches_exclusive_compatibility_bound(current, maximum):
		issues.append(
			f"{label}: target GF framework version {current_version} must be lower than "
			f"maximum_framework_version_exclusive {maximum_exclusive}"
		)
	return issues


def make_plan_result(
	ok: bool,
	operation: str,
	install_order: list[str],
	to_install: list[str],
	to_update: list[str],
	to_remove: list[str],
	issues: list[str],
	lockfile: dict[str, Any],
	lockfile_path: str,
	blocked: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
	return {
		"ok": ok,
		"operation": operation,
		"install_order": install_order,
		"to_install": to_install,
		"to_update": to_update,
		"to_remove": sorted(to_remove),
		"blocked": blocked or [],
		"lockfile_written": False,
		"lockfile": normalize_display_path(resolve_path(lockfile_path)),
		"installed_count": len(lockfile.get("installed", {})),
		"issues": issues,
		"planned_lockfile": lockfile,
	}


def load_registry(path: Path) -> dict[str, Any]:
	issues: list[str] = []
	if gf_path_security.path_has_reparse_component(path):
		return {"packages": {}, "framework_version": "", "issues": [f"Registry path crosses a filesystem link: {normalize_display_path(path)}"]}
	try:
		data = json.loads(path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		return {"packages": {}, "framework_version": "", "issues": [f"Could not read registry: {error}"]}
	if not isinstance(data, dict):
		return {"packages": {}, "framework_version": "", "issues": ["Registry root must be an object."]}
	if data.get("schema_version") != REGISTRY_SCHEMA_VERSION:
		issues.append(f"Registry schema_version must be {REGISTRY_SCHEMA_VERSION}.")
	for field_name in ["minimum_framework_version", "maximum_framework_version_exclusive"]:
		if field_name not in data:
			issues.append(f"Registry {field_name} field is required.")
	packages = data.get("packages", {})
	if not isinstance(packages, dict):
		issues.append("Registry packages must be an object.")
		packages = {}
	clean_packages: dict[str, dict[str, Any]] = {}
	for package_id, package_entry in sorted(packages.items()):
		package_id_text = str(package_id)
		if not package_id_is_valid(package_id_text):
			issues.append(f"Registry package id is invalid: {package_id_text}")
			continue
		if not isinstance(package_entry, dict):
			continue
		has_unsupported_signature = False
		for field_name in sorted(UNSUPPORTED_REGISTRY_PACKAGE_SIGNATURE_FIELDS.intersection(package_entry)):
			has_unsupported_signature = True
			issues.append(
				"Registry package signature field is not supported until native verification is implemented: "
				f"{package_id}.{field_name}"
			)
		for field_name in ["minimum_framework_version", "maximum_framework_version_exclusive"]:
			if field_name not in package_entry:
				issues.append(f"Registry package {package_id} is missing {field_name}.")
		if has_unsupported_signature:
			continue
		clean_packages[package_id_text] = package_entry
	return {
		"packages": clean_packages,
		"framework_version": str(data.get("framework_version", "")),
		"minimum_framework_version": str(data.get("minimum_framework_version", "")),
		"maximum_framework_version_exclusive": str(data.get("maximum_framework_version_exclusive", "")),
		"issues": issues,
	}


def package_id_is_valid(package_id: str) -> bool:
	text = str(package_id)
	if text.strip() != text or not text:
		return False
	if not text.startswith("gf."):
		return False
	if "/" in text or "\\" in text or ":" in text:
		return False
	if ".." in text:
		return False
	parts = text.split(".")
	if len(parts) < 2:
		return False
	return all(part and PACKAGE_ID_PART_RE.match(part) for part in parts)


def load_lockfile(path: Path) -> dict[str, Any]:
	if gf_path_security.path_has_reparse_component(path):
		return {
			"data": {"schema_version": LOCKFILE_SCHEMA_VERSION, "framework_version": "", "installed": {}},
			"issues": [f"Lockfile path crosses a filesystem link: {normalize_display_path(path)}"],
		}
	if not path.exists():
		return {"data": {"schema_version": LOCKFILE_SCHEMA_VERSION, "framework_version": "", "installed": {}}, "issues": []}
	issues: list[str] = []
	try:
		data = json.loads(path.read_text(encoding="utf-8"))
	except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
		return {"data": {"schema_version": LOCKFILE_SCHEMA_VERSION, "framework_version": "", "installed": {}}, "issues": [f"Could not read lockfile: {error}"]}
	if not isinstance(data, dict):
		return {"data": {"schema_version": LOCKFILE_SCHEMA_VERSION, "framework_version": "", "installed": {}}, "issues": ["Lockfile root must be an object."]}
	if data.get("schema_version") != LOCKFILE_SCHEMA_VERSION:
		issues.append(f"Lockfile schema_version must be {LOCKFILE_SCHEMA_VERSION}.")
	installed = data.get("installed", {})
	if not isinstance(installed, dict):
		issues.append("Lockfile installed must be an object.")
		installed = {}
	data["installed"] = {str(package_id): entry for package_id, entry in installed.items() if isinstance(entry, dict)}
	return {"data": data, "issues": issues}


def lock_entry_payload_changed(left: dict[str, Any], right: dict[str, Any]) -> bool:
	return (
		left.get("version") != right.get("version")
		or left.get("sha256") != right.get("sha256")
	)


def resolve_path(path: str) -> Path:
	resolved = Path(path)
	if not resolved.is_absolute():
		resolved = ROOT / resolved
	return resolved


def normalize_display_path(path: Path) -> str:
	try:
		return path.relative_to(ROOT).as_posix()
	except ValueError:
		return path.as_posix()


def normalize_manifest_path(path: str) -> str:
	return normalize_shared_manifest_path(path)


def string_array(value: Any) -> list[str]:
	if isinstance(value, str):
		return [value.strip()] if value.strip() else []
	if not isinstance(value, list):
		return []
	return [item.strip() for item in value if isinstance(item, str) and item.strip()]


def append_unique(items: list[str], item: str) -> None:
	if item and item not in items:
		items.append(item)


def source_contains_identifier(source: str, identifier: str) -> bool:
	return re.search(rf"(?<![A-Za-z0-9_]){re.escape(identifier)}(?![A-Za-z0-9_])", source) is not None


def read_text(path: Path) -> str:
	try:
		return path.read_text(encoding="utf-8")
	except (OSError, UnicodeError):
		return ""


def print_result(result: dict[str, Any], as_json: bool) -> None:
	if as_json:
		print(json.dumps(result, ensure_ascii=False, indent=2))
		return
	print(f"{result['operation']}: ok={result['ok']} installed={result['installed_count']} lockfile={result['lockfile']}")
	if result["to_install"]:
		print("to_install: " + ", ".join(result["to_install"]))
	if result["to_update"]:
		print("to_update: " + ", ".join(result["to_update"]))
	if result["to_remove"]:
		print("to_remove: " + ", ".join(result["to_remove"]))
	if result["blocked"]:
		print("blocked:")
		for item in result["blocked"]:
			print(f"- {item}")
	if result["issues"]:
		print("issues:")
		for issue in result["issues"]:
			print(f"- {issue}")


if __name__ == "__main__":
	raise SystemExit(main())
