"""Bounded project-source observations against the declared GF package policy."""

from __future__ import annotations

import os
import re
import stat
from pathlib import Path
from typing import Any

from . import catalog, dependencies
from .paths import (
	canonical_json_bytes,
	is_reserved_framework_resource_path,
	portable_ownership_path_identity,
	read_bounded_bytes,
	sha256_bytes,
)


SOURCE_DOMAINS = ("runtime", "test", "tool", "editor")
MAX_PROJECT_SCRIPTS = 20_000
MAX_SCRIPT_BYTES = 2 * 1024 * 1024
MAX_SOURCE_SCAN_BYTES = 128 * 1024 * 1024
MAX_OBSERVATION_EVIDENCE = 200
MAX_ACTIONABLE_EVIDENCE = 200
MAX_ADVISORY_EVIDENCE = 100
MAX_CATALOG_ISSUES = 20

_SKIPPED_DIRECTORY_NAMES = frozenset({
	".git",
	".gf",
	".godot",
	".import",
	"__pycache__",
	"ai_analysis",
	"build",
	"node_modules",
	"site",
})
_DYNAMIC_GF_SYMBOL_PATTERN = re.compile(r"(?:GF[A-Z][A-Za-z0-9_]*|Gf)")


def analyze_api_package_policy(
	project_root: Path,
	contract_result: dict[str, Any],
	*,
	api_index: dict[str, Any] | None = None,
	max_scripts: int = MAX_PROJECT_SCRIPTS,
	max_script_bytes: int = MAX_SCRIPT_BYTES,
	max_source_bytes: int = MAX_SOURCE_SCAN_BYTES,
) -> dict[str, Any]:
	"""Map bounded exact public API tokens to package-policy observations."""
	catalog_error = ""
	if api_index is None:
		try:
			api_index = catalog.load_api_index()
		except (OSError, UnicodeDecodeError, ValueError) as exc:
			api_index = {}
			catalog_error = str(exc)
	catalog_issues = catalog.api_index_issues(api_index)
	if catalog_error:
		catalog_issues.insert(0, catalog_error)
	catalog_issues = list(dict.fromkeys(catalog_issues))

	contract_valid = bool(contract_result.get("ok"))
	contract_data = contract_result.get("contract", {})
	if not contract_valid or not isinstance(contract_data, dict):
		contract_data = {}
	framework = contract_data.get("framework", {})
	if not isinstance(framework, dict):
		framework = {}
	architecture = contract_data.get("architecture", {})
	if not isinstance(architecture, dict):
		architecture = {}
	required = _string_set(framework.get("required_packages"))
	optional = _string_set(framework.get("optional_packages"))
	forbidden = _string_set(framework.get("forbidden_packages"))
	allowed = set() if catalog_issues else _package_closure(required | optional, api_index)
	owners = {} if catalog_issues else _public_owner_records(api_index)
	excluded_root_identities = _generated_root_identities(contract_result, architecture)
	domain_roots, domain_root_states, domain_root_pins = _source_domain_roots(
		project_root,
		architecture,
		excluded_root_identities,
	)

	scan = _scan_sources(
		project_root,
		owners,
		domain_roots,
		allowed,
		forbidden,
		excluded_root_identities,
		max_scripts=max_scripts,
		max_script_bytes=max_script_bytes,
		max_source_bytes=max_source_bytes,
	)
	_post_roots, post_domain_root_states, post_domain_root_pins = _source_domain_roots(
		project_root,
		architecture,
		excluded_root_identities,
	)
	if domain_root_states != post_domain_root_states or domain_root_pins != post_domain_root_pins:
		post_by_root = {item["root"]: item for item in post_domain_root_states}
		for state in domain_root_states:
			post = post_by_root.get(state["root"])
			if post != state or domain_root_pins.get(state["root"]) != post_domain_root_pins.get(state["root"]):
				state["status"] = "drifted"
	root_incomplete = any(item["status"] != "ready" for item in domain_root_states)
	source_complete = bool(scan["source_scan_complete"]) and not root_incomplete
	if catalog_issues:
		status = "catalog_invalid"
	elif not contract_valid:
		status = "contract_invalid"
	elif not source_complete:
		status = "partial"
	else:
		status = "complete"

	observations = [_without_order(item) for item in scan.pop("all_observations")]
	actionable = [item for item in observations if item["policy"] != "allowed"]
	advisories = [_without_order(item) for item in scan.pop("all_advisories")]
	domain_summaries: list[dict[str, Any]] = []
	for domain in SOURCE_DOMAINS:
		domain_observations = [item for item in observations if item["source_domain"] == domain]
		domain_advisories = [item for item in advisories if item["source_domain"] == domain]
		domain_summaries.append({
			"domain": domain,
			"observation_count": len(domain_observations),
			"allowed_count": sum(item["policy"] == "allowed" for item in domain_observations),
			"outside_policy_count": sum(item["policy"] == "outside_policy" for item in domain_observations),
			"forbidden_count": sum(item["policy"] == "forbidden" for item in domain_observations),
			"actionable_count": sum(item["policy"] != "allowed" for item in domain_observations),
			"advisory_count": len(domain_advisories),
		})

	identity = _catalog_identity(api_index)
	return {
		"status": status,
		"complete": status == "complete",
		"catalog": identity,
		"catalog_issue_count": len(catalog_issues),
		"catalog_issues_truncated": len(catalog_issues) > MAX_CATALOG_ISSUES,
		"catalog_issues": catalog_issues[:MAX_CATALOG_ISSUES],
		"contract_issue_count": int(contract_result.get("error_count", 0)),
		"required_packages": sorted(required),
		"optional_packages": sorted(optional),
		"allowed_packages": sorted(allowed),
		"forbidden_packages": sorted(forbidden),
		"source_domains": domain_root_states,
		"domains": domain_summaries,
		"observation_count": len(observations),
		"observations_truncated": len(observations) > MAX_OBSERVATION_EVIDENCE,
		"observations": observations[:MAX_OBSERVATION_EVIDENCE],
		"actionable_count": len(actionable),
		"actionable_observations_truncated": len(actionable) > MAX_ACTIONABLE_EVIDENCE,
		"actionable_observations": actionable[:MAX_ACTIONABLE_EVIDENCE],
		"advisory_count": len(advisories),
		"advisories_truncated": len(advisories) > MAX_ADVISORY_EVIDENCE,
		"advisories": advisories[:MAX_ADVISORY_EVIDENCE],
		**scan,
	}


def _scan_sources(
	project_root: Path,
	owners: dict[str, dict[str, str]],
	domain_roots: tuple[tuple[str, str, int], ...],
	allowed: set[str],
	forbidden: set[str],
	excluded_root_identities: frozenset[str],
	*,
	max_scripts: int,
	max_script_bytes: int,
	max_source_bytes: int,
) -> dict[str, Any]:
	script_count = 0
	scanned_script_count = 0
	scanned_script_bytes = 0
	test_script_count = 0
	skipped_large_script_count = 0
	unreadable_script_count = 0
	unsafe_script_path_count = 0
	unsafe_directory_count = 0
	invalid_gdignore_count = 0
	ignored_directory_count = 0
	truncated = False
	truncation_reason = ""
	observations: list[dict[str, Any]] = []
	advisories: list[dict[str, Any]] = []
	runtime_classes: set[str] = set()
	test_classes: set[str] = set()
	walk_errors: list[OSError] = []
	walked_directory_pins: dict[Path, tuple[int, int, int, int, int]] = {}
	gdignore_pins: dict[Path, tuple[int, int, int, int, int]] = {}

	for current_root, directory_names, file_names in os.walk(
		project_root,
		topdown=True,
		followlinks=False,
		onerror=walk_errors.append,
	):
		current_path = Path(current_root)
		current_pin = _directory_snapshot(project_root, current_path)
		if current_pin is None:
			unsafe_directory_count += 1
			directory_names[:] = []
			continue
		walked_directory_pins[current_path] = current_pin
		current_resource = _canonical_source_path(project_root, current_path)
		if not current_resource:
			unsafe_directory_count += 1
			directory_names[:] = []
			continue
		marker = current_path / ".gdignore"
		if ".gdignore" in file_names:
			marker_pin = _regular_snapshot(project_root, marker)
			if marker_pin is not None:
				gdignore_pins[marker] = marker_pin
				ignored_directory_count += 1
				directory_names[:] = []
				continue
			invalid_gdignore_count += 1
			directory_names[:] = []
			continue

		safe_directories: list[str] = []
		for name in sorted(directory_names):
			candidate = current_path / name
			resource_path = _canonical_source_path(project_root, candidate)
			identity = portable_ownership_path_identity(resource_path)
			if name.casefold() in _SKIPPED_DIRECTORY_NAMES:
				continue
			if is_reserved_framework_resource_path(resource_path):
				continue
			if identity in excluded_root_identities:
				continue
			if not resource_path or not identity or not _safe_directory_path(project_root, candidate):
				unsafe_directory_count += 1
				continue
			safe_directories.append(name)
		directory_names[:] = safe_directories

		for file_name in sorted(file_names):
			if not file_name.casefold().endswith(".gd"):
				continue
			path = current_path / file_name
			source_path = _canonical_source_path(project_root, path)
			identity = portable_ownership_path_identity(source_path)
			if not source_path or not identity or is_reserved_framework_resource_path(source_path):
				unsafe_script_path_count += 1
				continue
			if identity in excluded_root_identities:
				continue
			if script_count >= max_scripts:
				truncated = True
				truncation_reason = "script_count"
				break
			script_count += 1
			if not _safe_regular_path(project_root, path):
				unsafe_script_path_count += 1
				continue
			try:
				raw = read_bounded_bytes(path, max_script_bytes)
			except ValueError as exc:
				try:
					too_large = path.lstat().st_size > max_script_bytes
				except OSError:
					too_large = False
				if too_large:
					skipped_large_script_count += 1
				elif "linked or reparsed" in str(exc).casefold() or "regular file" in str(exc).casefold():
					unsafe_script_path_count += 1
				else:
					unreadable_script_count += 1
				continue
			if scanned_script_bytes + len(raw) > max_source_bytes:
				truncated = True
				truncation_reason = "byte_budget"
				break
			try:
				text = raw.decode("utf-8", errors="strict")
			except UnicodeDecodeError:
				unreadable_script_count += 1
				continue
			scanned_script_count += 1
			scanned_script_bytes += len(raw)
			domain = _source_domain(identity, domain_roots)
			if domain == "test":
				test_script_count += 1
			for occurrence, token in enumerate(dependencies.lex_gdscript(text)):
				owner = owners.get(token.value)
				if token.kind == "string":
					if owner is None and _DYNAMIC_GF_SYMBOL_PATTERN.fullmatch(token.value) is None:
						continue
					advisories.append({
						"source_path": source_path,
						"line": token.line,
						"source_domain": domain,
						"symbol": token.value,
						"reason": "dynamic_api_reference" if owner is not None else "unknown_dynamic_gf_symbol",
						"_occurrence": occurrence,
					})
					continue
				if token.kind != "identifier" or owner is None:
					continue
				package_id = owner["package_id"]
				if package_id in forbidden:
					policy = "forbidden"
				elif package_id in allowed:
					policy = "allowed"
				else:
					policy = "outside_policy"
				observations.append({
					"source_path": source_path,
					"line": token.line,
					"source_domain": domain,
					"owner_kind": owner["owner_kind"],
					"owner_name": token.value,
					"package_id": package_id,
					"policy": policy,
					"_occurrence": occurrence,
				})
				if owner["owner_kind"] == "class":
					if domain == "runtime":
						runtime_classes.add(token.value)
					elif domain == "test":
						test_classes.add(token.value)
		if truncated:
			break

	observations.sort(key=lambda item: (
		item["source_path"], item["line"], item["_occurrence"], item["owner_kind"], item["owner_name"]
	))
	advisories.sort(key=lambda item: (
		item["source_path"], item["line"], item["_occurrence"], item["symbol"]
	))
	unsafe_directory_count += len(walk_errors)
	directory_identity_drift_count = sum(
		_directory_snapshot(project_root, path) != pin
		for path, pin in walked_directory_pins.items()
	) + sum(
		_regular_snapshot(project_root, path) != pin
		for path, pin in gdignore_pins.items()
	)
	complete = not truncated and not any((
		skipped_large_script_count,
		unreadable_script_count,
		unsafe_script_path_count,
		unsafe_directory_count,
		invalid_gdignore_count,
		directory_identity_drift_count,
	))
	return {
		"script_count": script_count,
		"scanned_script_count": scanned_script_count,
		"scanned_script_bytes": scanned_script_bytes,
		"test_script_count": test_script_count,
		"source_scan_truncated": truncated,
		"source_scan_truncation_reason": truncation_reason,
		"source_scan_complete": complete,
		"skipped_large_script_count": skipped_large_script_count,
		"unreadable_script_count": unreadable_script_count,
		"unsafe_script_path_count": unsafe_script_path_count,
		"unsafe_directory_count": unsafe_directory_count,
		"invalid_gdignore_count": invalid_gdignore_count,
		"ignored_directory_count": ignored_directory_count,
		"directory_identity_drift_count": directory_identity_drift_count,
		"gf_api_usage": sorted(runtime_classes),
		"test_gf_api_usage": sorted(test_classes),
		"all_observations": observations,
		"all_advisories": advisories,
	}


def _source_domain_roots(
	project_root: Path,
	architecture: dict[str, Any],
	excluded_root_identities: frozenset[str] = frozenset(),
) -> tuple[
	tuple[tuple[str, str, int], ...],
	list[dict[str, str]],
	dict[str, tuple[int, int, int, int, int]],
]:
	declarations = architecture.get("source_domains", [])
	if not isinstance(declarations, list):
		declarations = []
	roots: list[tuple[str, str, int]] = []
	states: list[dict[str, str]] = []
	pins: dict[str, tuple[int, int, int, int, int]] = {}
	for declaration in declarations:
		if not isinstance(declaration, dict):
			continue
		root = str(declaration.get("root", ""))
		domain = str(declaration.get("domain", ""))
		identity = portable_ownership_path_identity(root)
		depth = len(root.removeprefix("res://").split("/")) if identity else 0
		roots.append((identity, domain, depth))
		status = _source_root_status(project_root, root, excluded_root_identities)
		states.append({"root": root, "domain": domain, "status": status})
		if status == "ready":
			relative = root.removeprefix("res://")
			pin = _directory_snapshot(project_root, project_root / Path(*relative.split("/")))
			if pin is not None:
				pins[root] = pin
	roots.sort(key=lambda item: (-item[2], item[0], item[1]))
	states.sort(key=lambda item: (portable_ownership_path_identity(item["root"]), item["domain"]))
	return tuple(roots), states, pins


def _source_root_status(
	project_root: Path,
	root: str,
	excluded_root_identities: frozenset[str],
) -> str:
	identity = portable_ownership_path_identity(root)
	if not identity or is_reserved_framework_resource_path(root):
		return "unsafe"
	parts = [part.casefold() for part in root.removeprefix("res://").split("/")]
	if any(part in _SKIPPED_DIRECTORY_NAMES for part in parts):
		return "excluded"
	if any(identity == generated or identity.startswith(generated + "/") for generated in excluded_root_identities):
		return "generated"
	relative = root.removeprefix("res://")
	path = project_root / Path(*relative.split("/"))
	if not path.exists():
		return "missing"
	if not path.is_dir():
		return "not_directory"
	if not _safe_directory_path(project_root, path):
		return "unsafe"
	current = path
	while True:
		marker = current / ".gdignore"
		try:
			marker.lstat()
		except FileNotFoundError:
			pass
		except OSError:
			return "unsafe"
		else:
			return "ignored" if _safe_regular_path(project_root, marker) else "unsafe"
		if current == project_root:
			break
		try:
			current = current.parent
		except OSError:
			return "unsafe"
	return "ready"


def _source_domain(
	source_identity: str,
	domain_roots: tuple[tuple[str, str, int], ...],
) -> str:
	for root_identity, domain, _depth in domain_roots:
		if source_identity == root_identity or source_identity.startswith(root_identity + "/"):
			return domain
	return "runtime"


def _generated_root_identities(
	contract_result: dict[str, Any],
	architecture: dict[str, Any],
) -> frozenset[str]:
	if not contract_result.get("ok"):
		return frozenset()
	result: set[str] = set()
	modules = architecture.get("modules", [])
	if not isinstance(modules, list):
		return frozenset()
	for module in modules:
		if not isinstance(module, dict) or module.get("ownership") != "generated":
			continue
		for root in module.get("roots", []):
			if isinstance(root, str):
				identity = portable_ownership_path_identity(root)
				if identity:
					result.add(identity)
	return frozenset(result)


def _public_owner_records(api_index: dict[str, Any]) -> dict[str, dict[str, str]]:
	result: dict[str, dict[str, str]] = {}
	for owner_kind, field in (("class", "classes"), ("autoload", "autoloads")):
		records = api_index.get(field, {})
		if not isinstance(records, dict):
			continue
		for owner_name, record in records.items():
			if not isinstance(owner_name, str) or not isinstance(record, dict):
				continue
			if record.get("visibility") != "public":
				continue
			package_id = record.get("package_id")
			if isinstance(package_id, str) and package_id:
				result[owner_name] = {
					"owner_kind": owner_kind,
					"package_id": package_id,
				}
	return result


def _package_closure(package_ids: set[str], api_index: dict[str, Any]) -> set[str]:
	package_records = {
		str(item.get("id")): item
		for item in api_index.get("packages", [])
		if isinstance(item, dict) and isinstance(item.get("id"), str)
	}
	closure: set[str] = set()
	pending = sorted(package_ids, reverse=True)
	while pending:
		package_id = pending.pop()
		if package_id in closure:
			continue
		closure.add(package_id)
		record = package_records.get(package_id, {})
		dependencies_value = record.get("dependencies", []) if isinstance(record, dict) else []
		dependencies = sorted(_string_set(dependencies_value), reverse=True)
		pending.extend(dependencies)
	return closure


def _catalog_identity(api_index: dict[str, Any]) -> dict[str, Any]:
	return {
		"schema_version": api_index.get("schema_version", 0),
		"catalog_version": str(api_index.get("catalog_version", "")),
		"source_digest": str(api_index.get("source_digest", "")),
	}


def _canonical_source_path(project_root: Path, path: Path) -> str:
	try:
		relative = path.relative_to(project_root)
	except ValueError:
		return ""
	if not relative.parts:
		return "res://project.godot"
	resource_path = "res://" + "/".join(relative.parts)
	return resource_path if portable_ownership_path_identity(resource_path) else ""


def _safe_directory_path(project_root: Path, path: Path) -> bool:
	return _directory_snapshot(project_root, path) is not None


def _directory_snapshot(
	project_root: Path,
	path: Path,
) -> tuple[int, int, int, int, int] | None:
	try:
		metadata = path.lstat()
		if not stat.S_ISDIR(metadata.st_mode) or _is_link_or_reparse(path, metadata):
			return None
		path.resolve(strict=True).relative_to(project_root.resolve(strict=True))
	except (OSError, ValueError):
		return None
	return _identity_snapshot(metadata)


def _safe_regular_path(project_root: Path, path: Path) -> bool:
	return _regular_snapshot(project_root, path) is not None


def _regular_snapshot(
	project_root: Path,
	path: Path,
) -> tuple[int, int, int, int, int] | None:
	try:
		metadata = path.lstat()
		if not stat.S_ISREG(metadata.st_mode) or _is_link_or_reparse(path, metadata):
			return None
		path.resolve(strict=True).relative_to(project_root.resolve(strict=True))
	except (OSError, ValueError):
		return None
	return _identity_snapshot(metadata)


def _identity_snapshot(metadata: os.stat_result) -> tuple[int, int, int, int, int]:
	return (
		int(metadata.st_dev),
		int(metadata.st_ino),
		int(metadata.st_mode),
		int(metadata.st_size),
		int(metadata.st_mtime_ns),
	)


def _is_link_or_reparse(path: Path, metadata: os.stat_result) -> bool:
	if path.is_symlink():
		return True
	reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
	return bool(reparse_flag and getattr(metadata, "st_file_attributes", 0) & reparse_flag)


def _string_set(value: Any) -> set[str]:
	return {str(item) for item in value if isinstance(item, str) and item} if isinstance(value, list) else set()


def _without_order(item: dict[str, Any]) -> dict[str, Any]:
	return {key: value for key, value in item.items() if key != "_occurrence"}


def canonical_api_index_digest(api_index: dict[str, Any]) -> str:
	"""Return the version-2 source digest; useful to maintain strict fixtures."""
	payload = {key: value for key, value in api_index.items() if key != "source_digest"}
	return sha256_bytes(canonical_json_bytes(payload))
