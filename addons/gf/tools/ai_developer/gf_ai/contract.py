"""Loading, initialization, and semantic validation for project intent contracts."""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any

from . import catalog
from .constants import (
	CONTRACT_SCHEMA_VERSION,
	DEFAULT_CONTRACT_PATH,
	DEFAULT_OFFICIAL_REPOSITORY,
	RESERVED_DEPENDENCY_IDS,
	SCHEMA_ROOT,
	TEMPLATE_ROOT,
)
from .paths import (
	atomic_write_json,
	is_reserved_framework_resource_path,
	normalize_portable_ownership_path,
	portable_ownership_path_identity,
	project_path_has_link_component,
	read_json_object,
	resolve_project_path,
	sha256_json,
)
from .schema import validate_schema_file


_SOURCE_DOMAIN_EXCLUDED_ROOTS = frozenset({
	".git", ".gf", ".godot", ".import", "__pycache__", "ai_analysis", "build", "node_modules", "site",
})
_MAX_DOCUMENTATION_ROOTS = 100


def contract_path(project_root: Path, relative_path: str = DEFAULT_CONTRACT_PATH) -> Path:
	resolve_project_path(project_root, relative_path)
	if project_path_has_link_component(project_root, relative_path):
		raise ValueError("Project contract path crosses a symbolic link, junction, or reparse point.")
	normalized = relative_path.strip().replace("\\", "/")
	return Path(os.path.abspath(os.fspath(project_root / Path(normalized))))


def initialize_contract(
	project_root: Path,
	relative_path: str = DEFAULT_CONTRACT_PATH,
) -> dict[str, Any]:
	path = contract_path(project_root, relative_path)
	if path.exists():
		result = load_contract(project_root, relative_path)
		result["created"] = False
		return result
	template = read_json_object(TEMPLATE_ROOT / "gf_project_contract.json")
	project = template.get("project", {})
	if isinstance(project, dict):
		project_id = re.sub(r"[^a-z0-9_-]+", "_", project_root.name.casefold()).strip("_")
		if not project_id or not project_id[0].isalpha():
			project_id = f"project_{project_id}" if project_id else "gf_project"
		project["id"] = project_id[:80]
		project["summary"] = f"GF project {project_root.name}."
	atomic_write_json(path, template)
	result = load_contract(project_root, relative_path)
	result["created"] = True
	return result


def load_contract(
	project_root: Path,
	relative_path: str = DEFAULT_CONTRACT_PATH,
) -> dict[str, Any]:
	try:
		path = contract_path(project_root, relative_path)
	except ValueError as exc:
		return {
			"ok": False,
			"path": relative_path,
			"contract": {},
			"sha256": "",
			"schema_version": 0,
			"current_schema_version": CONTRACT_SCHEMA_VERSION,
			"migration_required": False,
			"migration_available": False,
			"error_count": 1,
			"warning_count": 0,
			"issues": [_issue("error", "unsafe_contract_path", relative_path, str(exc))],
		}
	if not path.is_file():
		return {
			"ok": False,
			"path": relative_path,
			"contract": {},
			"sha256": "",
			"schema_version": 0,
			"current_schema_version": CONTRACT_SCHEMA_VERSION,
			"migration_required": False,
			"migration_available": False,
			"error_count": 1,
			"warning_count": 0,
			"issues": [_issue("error", "missing_contract", relative_path, "Project contract is missing.")],
		}
	try:
		data = read_json_object(path, max_bytes=1024 * 1024)
	except ValueError as exc:
		return {
			"ok": False,
			"path": relative_path,
			"contract": {},
			"sha256": "",
			"schema_version": 0,
			"current_schema_version": CONTRACT_SCHEMA_VERSION,
			"migration_required": False,
			"migration_available": False,
			"error_count": 1,
			"warning_count": 0,
			"issues": [_issue("error", "invalid_contract_json", relative_path, str(exc))],
		}
	raw_schema_version = data.get("schema_version")
	schema_version = raw_schema_version if isinstance(raw_schema_version, int) and not isinstance(raw_schema_version, bool) else 0
	migration_required = schema_version > 0 and schema_version != CONTRACT_SCHEMA_VERSION
	migration_available = schema_version in (1, 2, 3, 4) and CONTRACT_SCHEMA_VERSION == 5
	if migration_required and migration_available:
		issues = [_issue(
			"error",
			"contract_migration_required",
			"$.schema_version",
			f"Project contract schema v{schema_version} must be migrated to v{CONTRACT_SCHEMA_VERSION}.",
		)]
	elif migration_required and schema_version > 0:
		issues = [_issue(
			"error",
			"unsupported_contract_schema",
			"$.schema_version",
			f"Project contract schema v{schema_version} is not supported by this kit (expected v{CONTRACT_SCHEMA_VERSION}).",
		)]
	else:
		issues = validate_contract_data(data, project_root)
	error_count = sum(1 for issue in issues if issue["severity"] == "error")
	warning_count = sum(1 for issue in issues if issue["severity"] == "warning")
	return {
		"ok": error_count == 0,
		"path": relative_path,
		"contract": data,
		"sha256": sha256_json(data),
		"schema_version": schema_version,
		"current_schema_version": CONTRACT_SCHEMA_VERSION,
		"migration_required": migration_required,
		"migration_available": migration_available,
		"error_count": error_count,
		"warning_count": warning_count,
		"issues": issues,
	}


def validate_contract_data(data: dict[str, Any], project_root: Path) -> list[dict[str, str]]:
	issues = [
		_issue("error", str(item["code"]), str(item["path"]), str(item["message"]))
		for item in validate_schema_file(data, SCHEMA_ROOT / "project_contract.schema.json")
	]
	if not issues:
		try:
			issues.extend(_semantic_issues(data, project_root))
		except (OSError, UnicodeDecodeError, ValueError) as exc:
			issues.append(_issue(
				"error",
				"catalog_invalid",
				"$.framework",
				f"GF API/package catalog is invalid: {exc}",
			))
	return issues


def _semantic_issues(data: dict[str, Any], project_root: Path) -> list[dict[str, str]]:
	issues: list[dict[str, str]] = []
	framework = _object(data, "framework")
	required = _string_set(framework, "required_packages")
	optional = _string_set(framework, "optional_packages")
	forbidden = _string_set(framework, "forbidden_packages")
	if "gf.kernel" not in required:
		issues.append(_issue("error", "kernel_not_required", "$.framework.required_packages", "GF projects must explicitly require gf.kernel."))
	for left_name, left, right_name, right in (
		("required_packages", required, "optional_packages", optional),
		("required_packages", required, "forbidden_packages", forbidden),
		("optional_packages", optional, "forbidden_packages", forbidden),
	):
		for package_id in sorted(left.intersection(right)):
			issues.append(_issue(
				"error",
				"package_policy_overlap",
				f"$.framework.{left_name}",
				f"Package {package_id} also appears in {right_name}.",
			))
	known_packages = catalog.known_package_ids()
	for field, package_ids in (
		("required_packages", required),
		("optional_packages", optional),
		("forbidden_packages", forbidden),
	):
		for package_id in sorted(package_ids - known_packages):
			issues.append(_issue(
				"error",
				"unknown_package",
				f"$.framework.{field}",
				f"GF package is not present in this installed kit: {package_id}.",
			))
	capability_requirements = _object_list(framework, "capability_requirements")
	capability_ids = _unique_ids(capability_requirements, "$.framework.capability_requirements", issues)
	capability_records = catalog.capability_records_by_id()
	for capability_id in sorted(capability_ids - set(capability_records)):
		issues.append(_issue(
			"error",
			"unknown_capability",
			"$.framework.capability_requirements",
			f"GF capability is not present in this installed kit: {capability_id}.",
		))

	architecture = _object(data, "architecture")
	modules = _object_list(architecture, "modules")
	owned_resources = [
		raw_path
		for raw_path in architecture.get("owned_resources", [])
		if isinstance(raw_path, str)
	]
	path_roles = _object_list(architecture, "path_roles")
	source_domains = _object_list(architecture, "source_domains")
	documentation_roots_value = architecture.get("documentation_roots", [])
	documentation_roots = documentation_roots_value if isinstance(documentation_roots_value, list) else []
	module_ids = _unique_ids(modules, "$.architecture.modules", issues)
	adapters = _object_list(framework, "adapter_boundaries")
	adapter_ids = _unique_ids(adapters, "$.framework.adapter_boundaries", issues)
	for components, component_path in (
		(modules, "$.architecture.modules"),
		(adapters, "$.framework.adapter_boundaries"),
	):
		for index, component in enumerate(components):
			component_id = str(component.get("id", ""))
			if component_id in RESERVED_DEPENDENCY_IDS:
				issues.append(_issue(
					"error",
					"reserved_dependency_id",
					f"{component_path}[{index}].id",
					(
						"Module and adapter ids share one dependency namespace and cannot "
						f"claim the reserved dependency target {component_id!r}."
					),
				))
	for component_id in sorted(module_ids.intersection(adapter_ids)):
		issues.append(_issue(
			"error",
			"ambiguous_component_id",
			"$.framework.adapter_boundaries",
			f"Module and adapter ids share one dependency namespace and must be distinct: {component_id}.",
		))
	known_dependencies = module_ids.union(adapter_ids).union({"gf", "godot"})
	capability_owners = module_ids.union(adapter_ids).union({"project"})
	known_recipes = catalog.known_recipe_ids()
	for index, requirement in enumerate(capability_requirements):
		capability_id = str(requirement.get("id", ""))
		decision_state = str(requirement.get("decision_state", ""))
		owner = str(requirement.get("owner", ""))
		if decision_state == "pending_review":
			issues.append(_issue(
				"warning",
				"capability_requirement_pending_review",
				f"$.framework.capability_requirements[{index}].decision_state",
				f"Capability requirement still needs explicit project review: {capability_id}.",
			))
		elif decision_state == "confirmed":
			if not _string_set(requirement, "recipes"):
				issues.append(_issue(
					"error",
					"confirmed_capability_recipe_required",
					f"$.framework.capability_requirements[{index}].recipes",
					f"Confirmed capability requirement must select at least one advertised Recipe: {capability_id}.",
				))
			if not _string_set(requirement, "acceptance"):
				issues.append(_issue(
					"error",
					"confirmed_capability_acceptance_required",
					f"$.framework.capability_requirements[{index}].acceptance",
					f"Confirmed capability requirement must declare at least one project-owned acceptance condition: {capability_id}.",
				))
		if owner not in capability_owners:
			issues.append(_issue(
				"error",
				"unknown_capability_owner",
				f"$.framework.capability_requirements[{index}].owner",
				f"Capability owner is not project, a declared module, or a declared adapter: {owner}.",
			))
		capability = capability_records.get(capability_id, {})
		capability_packages = _string_set(capability, "packages")
		if capability and not required.intersection(capability_packages):
			issues.append(_issue(
				"error",
				"capability_package_not_required",
				f"$.framework.capability_requirements[{index}].id",
				f"Required capability {capability_id} has no provider package in required_packages.",
			))
		advertised_recipes = _string_set(capability, "recipes")
		selected_recipes = _string_set(requirement, "recipes")
		for recipe_id in sorted(selected_recipes):
			if recipe_id not in known_recipes:
				issues.append(_issue(
					"error",
					"unknown_capability_recipe",
					f"$.framework.capability_requirements[{index}].recipes",
					f"GF recipe is not present in this installed kit: {recipe_id}.",
				))
			elif capability and recipe_id not in advertised_recipes:
				issues.append(_issue(
					"error",
					"capability_recipe_mismatch",
					f"$.framework.capability_requirements[{index}].recipes",
					f"Recipe {recipe_id} is not advertised for capability {capability_id}.",
				))
		recipe_readiness = catalog.recipe_package_readiness(selected_recipes, required)
		for package_id in recipe_readiness["missing_all_of"]:
			issues.append(_issue(
				"error",
				"capability_recipe_package_not_required",
				f"$.framework.capability_requirements[{index}].recipes",
				f"Selected Recipe for {capability_id} requires package {package_id} in the required package dependency closure.",
			))
		for group in recipe_readiness["unsatisfied_any_of"]:
			issues.append(_issue(
				"error",
				"capability_recipe_package_alternative_not_required",
				f"$.framework.capability_requirements[{index}].recipes",
				f"Selected Recipe for {capability_id} requires one package from: {', '.join(group)}.",
			))
	for index, module in enumerate(modules):
		allowed = _string_set(module, "allowed_dependencies")
		blocked = _string_set(module, "forbidden_dependencies")
		for dependency_id in sorted(allowed.intersection(blocked)):
			issues.append(_issue(
				"error",
				"dependency_policy_overlap",
				f"$.architecture.modules[{index}]",
				f"Dependency {dependency_id} is both allowed and forbidden.",
			))
		for dependency_id in sorted(allowed.union(blocked) - known_dependencies):
			issues.append(_issue(
				"error",
				"unknown_module_dependency",
				f"$.architecture.modules[{index}]",
				f"Dependency target is not a declared module, adapter, gf, or godot: {dependency_id}.",
			))
		for root_index, raw_path in enumerate(module.get("roots", [])):
			if isinstance(raw_path, str):
				_validate_ownership_root_path(
					project_root,
					raw_path,
					f"$.architecture.modules[{index}].roots[{root_index}]",
					issues,
				)
	for index, raw_path in enumerate(owned_resources):
		_validate_owned_resource_path(
			project_root,
			raw_path,
			f"$.architecture.owned_resources[{index}]",
			issues,
		)
	for index, path_role in enumerate(path_roles):
		raw_path = path_role.get("path")
		if isinstance(raw_path, str):
			_validate_path_role_path(
				project_root,
				raw_path,
				f"$.architecture.path_roles[{index}].path",
				issues,
			)
	issues.extend(_path_role_overlap_issues(path_roles))
	issues.extend(_source_domain_issues(project_root, source_domains, modules))
	issues.extend(_documentation_root_issues(documentation_roots, modules))
	issues.extend(_module_dependency_cycle_issues(modules, module_ids))
	for index, adapter in enumerate(adapters):
		raw_path = adapter.get("project_root")
		if isinstance(raw_path, str):
			_validate_ownership_root_path(
				project_root,
				raw_path,
				f"$.framework.adapter_boundaries[{index}].project_root",
				issues,
			)
	issues.extend(_ownership_root_overlap_issues(modules, adapters))
	issues.extend(_ownership_resource_overlap_issues(modules, adapters, owned_resources))
	profile_path = architecture.get("project_profile_path")
	if isinstance(profile_path, str) and profile_path:
		_validate_contract_path(project_root, profile_path, "$.architecture.project_profile_path", issues)

	_unique_ids(_object_list(data, "decisions"), "$.decisions", issues)
	_unique_ids(_object_list(data, "unknowns"), "$.unknowns", issues)
	verification = _object(data, "verification")
	_unique_ids(_object_list(verification, "checks"), "$.verification.checks", issues)
	for index, raw_path in enumerate(verification.get("required_paths", [])):
		if isinstance(raw_path, str):
			_validate_contract_path(project_root, raw_path, f"$.verification.required_paths[{index}]", issues)
	feedback = _object(data, "feedback")
	if feedback.get("repository") != DEFAULT_OFFICIAL_REPOSITORY:
		issues.append(_issue(
			"error",
			"unsupported_feedback_repository",
			"$.feedback.repository",
			f"Automated feedback is pinned to the official repository {DEFAULT_OFFICIAL_REPOSITORY}.",
		))
	constraints = _object(data, "constraints")
	for field in ("determinism", "persistence", "networking"):
		value = _object(constraints, field)
		if value.get("mode") == "unknown":
			issues.append(_issue(
				"warning",
				"undeclared_constraint",
				f"$.constraints.{field}.mode",
				f"The {field} constraint remains explicitly unknown.",
			))
	return issues


def _validate_contract_path(
	project_root: Path,
	relative_path: str,
	path: str,
	issues: list[dict[str, str]],
) -> None:
	try:
		resolve_project_path(project_root, relative_path)
	except ValueError as exc:
		issues.append(_issue("error", "unsafe_project_path", path, str(exc)))
		return
	if project_path_has_link_component(project_root, relative_path):
		issues.append(_issue(
			"error",
			"unsafe_project_path",
			path,
			"Project path crosses a symbolic link, junction, or reparse point.",
		))


def _validate_owned_resource_path(
	project_root: Path,
	raw_path: str,
	path: str,
	issues: list[dict[str, str]],
) -> None:
	normalized_path = normalize_portable_ownership_path(raw_path)
	if not normalized_path:
		issues.append(_issue(
			"error",
			"non_canonical_owned_resource_path",
			path,
			"Project-owned resource paths must use one canonical non-root res:// path.",
		))
		return
	if is_reserved_framework_resource_path(normalized_path):
		issues.append(_issue(
			"error",
			"framework_owned_resource",
			path,
			"Project-owned resources must stay outside the reserved res://addons/gf boundary.",
		))
		return
	_validate_contract_path(project_root, normalized_path.removeprefix("res://"), path, issues)


def _validate_path_role_path(
	project_root: Path,
	raw_path: str,
	path: str,
	issues: list[dict[str, str]],
) -> None:
	normalized_path = normalize_portable_ownership_path(raw_path)
	if not normalized_path:
		issues.append(_issue(
			"error",
			"non_canonical_path_role_path",
			path,
			"Path roles must use one canonical cross-platform non-root res:// path.",
		))
		return
	if is_reserved_framework_resource_path(normalized_path):
		issues.append(_issue(
			"error",
			"framework_path_role",
			path,
			"Project path roles must stay outside the reserved res://addons/gf boundary.",
		))
		return
	_validate_contract_path(project_root, normalized_path.removeprefix("res://"), path, issues)


def _validate_ownership_root_path(
	project_root: Path,
	raw_path: str,
	path: str,
	issues: list[dict[str, str]],
) -> None:
	normalized_path = normalize_portable_ownership_path(raw_path)
	if not normalized_path:
		issues.append(_issue(
			"error",
			"non_canonical_ownership_root",
			path,
			"Ownership roots must use one canonical cross-platform non-root res:// path.",
		))
		return
	if is_reserved_framework_resource_path(normalized_path):
		issues.append(_issue(
			"error",
			"framework_ownership_root",
			path,
			"Project ownership roots must stay outside the reserved res://addons/gf boundary.",
		))
		return
	_validate_contract_path(project_root, normalized_path.removeprefix("res://"), path, issues)


def _source_domain_issues(
	project_root: Path,
	source_domains: list[dict[str, Any]],
	modules: list[dict[str, Any]],
) -> list[dict[str, str]]:
	issues: list[dict[str, str]] = []
	seen: dict[str, int] = {}
	generated_root_identities = {
		identity
		for module in modules
		if module.get("ownership") == "generated"
		for raw_root in module.get("roots", [])
		if isinstance(raw_root, str)
		for identity in (portable_ownership_path_identity(raw_root),)
		if identity
	}
	for index, declaration in enumerate(source_domains):
		raw_root = declaration.get("root")
		if not isinstance(raw_root, str):
			continue
		path = f"$.architecture.source_domains[{index}].root"
		normalized = normalize_portable_ownership_path(raw_root)
		if not normalized:
			issues.append(_issue(
				"error",
				"non_canonical_source_domain_root",
				path,
				"Source-domain roots must use one canonical cross-platform non-root res:// path.",
			))
			continue
		identity = portable_ownership_path_identity(normalized)
		if identity in seen:
			issues.append(_issue(
				"error",
				"duplicate_source_domain_root",
				path,
				f"Source-domain root duplicates declaration {seen[identity]} under portable path identity: {raw_root}.",
			))
		else:
			seen[identity] = index
		if is_reserved_framework_resource_path(normalized):
			issues.append(_issue(
				"error",
				"reserved_source_domain_root",
				path,
				"Source-domain roots must stay outside the reserved res://addons/gf boundary.",
			))
			continue
		parts = [part.casefold() for part in normalized.removeprefix("res://").split("/")]
		if any(part in _SOURCE_DOMAIN_EXCLUDED_ROOTS for part in parts):
			issues.append(_issue(
				"error",
				"excluded_source_domain_root",
				path,
				f"Source-domain root is inside a scanner-excluded project directory: {raw_root}.",
			))
			continue
		if any(
			identity == generated_identity or identity.startswith(generated_identity + "/")
			for generated_identity in generated_root_identities
		):
			issues.append(_issue(
				"error",
				"generated_source_domain_root",
				path,
				f"Source-domain root is owned by a target-only generated module: {raw_root}.",
			))
	return issues


def _documentation_root_issues(
	documentation_roots: list[Any],
	modules: list[dict[str, Any]],
) -> list[dict[str, str]]:
	issues: list[dict[str, str]] = []
	seen: dict[str, int] = {}
	identities: list[tuple[str, tuple[str, ...]]] = []
	generated_root_identities = {
		identity
		for module in modules
		if module.get("ownership") == "generated"
		for raw_root in module.get("roots", [])
		if isinstance(raw_root, str)
		for identity in (portable_ownership_path_identity(raw_root),)
		if identity
	}
	for index, raw_root in enumerate(documentation_roots[:_MAX_DOCUMENTATION_ROOTS]):
		if not isinstance(raw_root, str):
			continue
		path = f"$.architecture.documentation_roots[{index}]"
		normalized = normalize_portable_ownership_path(raw_root)
		if not normalized:
			issues.append(_issue(
				"error",
				"non_canonical_documentation_root",
				path,
				"Documentation roots must use one canonical cross-platform non-root res:// path.",
			))
			continue
		identity = portable_ownership_path_identity(normalized)
		if identity in seen:
			issues.append(_issue(
				"error",
				"duplicate_documentation_root",
				path,
				f"Documentation root duplicates declaration {seen[identity]} under portable path identity: {raw_root}.",
			))
			continue
		seen[identity] = index
		if is_reserved_framework_resource_path(normalized):
			issues.append(_issue(
				"error",
				"reserved_documentation_root",
				path,
				"Documentation roots must stay outside the reserved res://addons/gf boundary.",
			))
			continue
		parts = tuple(identity.removeprefix("res://").split("/"))
		if any(part in _SOURCE_DOMAIN_EXCLUDED_ROOTS for part in parts):
			issues.append(_issue(
				"error",
				"excluded_documentation_root",
				path,
				f"Documentation root is inside a scanner-excluded project directory: {raw_root}.",
			))
			continue
		if any(
			identity == generated_identity
			or identity.startswith(generated_identity + "/")
			or generated_identity.startswith(identity + "/")
			for generated_identity in generated_root_identities
		):
			issues.append(_issue(
				"error",
				"generated_documentation_root",
				path,
				f"Documentation root overlaps a target-only generated module: {raw_root}.",
			))
			continue
		identities.append((raw_root, parts))
	for left_index, (left_root, left_parts) in enumerate(identities):
		for right_root, right_parts in identities[left_index + 1:]:
			if not _parts_overlap(left_parts, right_parts):
				continue
			issues.append(_issue(
				"error",
				"documentation_root_overlap",
				"$.architecture.documentation_roots",
				f"Documentation roots must not share an exact or ancestor identity: {left_root} and {right_root}.",
			))
	return issues


def _unique_ids(
	records: list[dict[str, Any]],
	path: str,
	issues: list[dict[str, str]],
) -> set[str]:
	seen: set[str] = set()
	for index, record in enumerate(records):
		record_id = str(record.get("id", ""))
		if record_id in seen:
			issues.append(_issue("error", "duplicate_id", f"{path}[{index}].id", f"Duplicate id: {record_id}."))
		seen.add(record_id)
	return seen


def _module_dependency_cycle_issues(
	modules: list[dict[str, Any]],
	module_ids: set[str],
) -> list[dict[str, str]]:
	graph = {
		str(module.get("id", "")): sorted(_string_set(module, "allowed_dependencies").intersection(module_ids))
		for module in modules
		if str(module.get("id", ""))
	}
	state: dict[str, int] = {}
	stack: list[str] = []
	issues: list[dict[str, str]] = []
	reported: set[tuple[str, ...]] = set()

	def visit(module_id: str) -> None:
		state[module_id] = 1
		stack.append(module_id)
		for dependency_id in graph.get(module_id, []):
			if state.get(dependency_id, 0) == 0:
				visit(dependency_id)
			elif state.get(dependency_id) == 1:
				cycle_start = stack.index(dependency_id)
				cycle = tuple([*stack[cycle_start:], dependency_id])
				canonical = _canonical_cycle(cycle)
				if canonical not in reported:
					reported.add(canonical)
					issues.append(_issue(
						"error",
						"module_dependency_cycle",
						"$.architecture.modules",
						"Project module dependency cycle: " + " -> ".join(cycle) + ".",
					))
		stack.pop()
		state[module_id] = 2

	for module_id in sorted(graph):
		if state.get(module_id, 0) == 0:
			visit(module_id)
	return issues


def _ownership_root_overlap_issues(
	modules: list[dict[str, Any]],
	adapters: list[dict[str, Any]],
) -> list[dict[str, str]]:
	roots = _ownership_roots(modules, adapters)
	issues: list[dict[str, str]] = []
	for left_index, (left_owner, left_path, left_parts) in enumerate(roots):
		for right_owner, right_path, right_parts in roots[left_index + 1:]:
			if not _parts_overlap(left_parts, right_parts):
				continue
			issues.append(_issue(
				"error",
				"ownership_root_overlap",
				"$.architecture.modules",
				f"Ownership roots overlap between {left_owner} ({left_path}) and {right_owner} ({right_path}).",
			))
	return issues


def _path_role_overlap_issues(
	path_roles: list[dict[str, Any]],
) -> list[dict[str, str]]:
	identities: list[tuple[str, tuple[str, ...]]] = []
	for path_role in path_roles:
		raw_path = path_role.get("path")
		if not isinstance(raw_path, str):
			continue
		identity = portable_ownership_path_identity(raw_path)
		if not identity:
			continue
		identities.append((raw_path, tuple(identity.removeprefix("res://").split("/"))))
	issues: list[dict[str, str]] = []
	for left_index, (left_path, left_parts) in enumerate(identities):
		for right_path, right_parts in identities[left_index + 1:]:
			if not _parts_overlap(left_parts, right_parts):
				continue
			issues.append(_issue(
				"error",
				"path_role_overlap",
				"$.architecture.path_roles",
				f"Path roles must not share an exact or ancestor identity: {left_path} and {right_path}.",
			))
	return issues


def _ownership_resource_overlap_issues(
	modules: list[dict[str, Any]],
	adapters: list[dict[str, Any]],
	owned_resources: list[str],
) -> list[dict[str, str]]:
	roots = _ownership_roots(modules, adapters)

	issues: list[dict[str, str]] = []
	for index, resource_path in enumerate(owned_resources):
		resource_parts = _root_parts(resource_path)
		for owner, root_path, root_parts in roots:
			if not _parts_overlap(resource_parts, root_parts):
				continue
			issues.append(_issue(
				"error",
				"ownership_resource_overlap",
				f"$.architecture.owned_resources[{index}]",
				f"Project-owned resource {resource_path} overlaps {owner} ownership root {root_path}.",
			))
	return issues


def _ownership_roots(
	modules: list[dict[str, Any]],
	adapters: list[dict[str, Any]],
) -> list[tuple[str, str, tuple[str, ...]]]:
	roots: list[tuple[str, str, tuple[str, ...]]] = []
	for module in modules:
		owner = f"module {module.get('id', '')}"
		for raw_path in module.get("roots", []):
			if isinstance(raw_path, str):
				roots.append((owner, raw_path, _root_parts(raw_path)))
	for adapter in adapters:
		raw_path = adapter.get("project_root")
		if isinstance(raw_path, str):
			roots.append((f"adapter {adapter.get('id', '')}", raw_path, _root_parts(raw_path)))
	return roots


def _root_parts(raw_path: str) -> tuple[str, ...]:
	return tuple(part.casefold() for part in raw_path.removeprefix("res://").split("/") if part)


def _parts_overlap(left: tuple[str, ...], right: tuple[str, ...]) -> bool:
	shorter = min(len(left), len(right))
	return shorter > 0 and left[:shorter] == right[:shorter]


def _canonical_cycle(cycle: tuple[str, ...]) -> tuple[str, ...]:
	nodes = cycle[:-1]
	if not nodes:
		return cycle
	rotations = [nodes[index:] + nodes[:index] for index in range(len(nodes))]
	return min(rotations)


def _object(data: dict[str, Any], field: str) -> dict[str, Any]:
	value = data.get(field, {})
	return value if isinstance(value, dict) else {}


def _object_list(data: dict[str, Any], field: str) -> list[dict[str, Any]]:
	value = data.get(field, [])
	if not isinstance(value, list):
		return []
	return [item for item in value if isinstance(item, dict)]


def _string_set(data: dict[str, Any], field: str) -> set[str]:
	value = data.get(field, [])
	if not isinstance(value, list):
		return set()
	return {str(item) for item in value if isinstance(item, str) and item}


def _issue(severity: str, code: str, path: str, message: str) -> dict[str, str]:
	return {"severity": severity, "code": code, "path": path, "message": message}
