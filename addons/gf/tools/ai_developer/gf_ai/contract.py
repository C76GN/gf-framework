"""Loading, initialization, and semantic validation for project intent contracts."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from . import catalog
from .constants import DEFAULT_CONTRACT_PATH, DEFAULT_OFFICIAL_REPOSITORY, SCHEMA_ROOT, TEMPLATE_ROOT
from .paths import atomic_write_json, read_json_object, resolve_project_path, sha256_json
from .schema import validate_schema_file


def contract_path(project_root: Path, relative_path: str = DEFAULT_CONTRACT_PATH) -> Path:
	return resolve_project_path(project_root, relative_path)


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
	path = contract_path(project_root, relative_path)
	if not path.is_file():
		return {
			"ok": False,
			"path": relative_path,
			"contract": {},
			"sha256": "",
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
			"error_count": 1,
			"warning_count": 0,
			"issues": [_issue("error", "invalid_contract_json", relative_path, str(exc))],
		}
	issues = [
		_issue("error", str(item["code"]), str(item["path"]), str(item["message"]))
		for item in validate_schema_file(data, SCHEMA_ROOT / "project_contract.schema.json")
	]
	if not issues:
		issues.extend(_semantic_issues(data, project_root))
	error_count = sum(1 for issue in issues if issue["severity"] == "error")
	warning_count = sum(1 for issue in issues if issue["severity"] == "warning")
	return {
		"ok": error_count == 0,
		"path": relative_path,
		"contract": data,
		"sha256": sha256_json(data),
		"error_count": error_count,
		"warning_count": warning_count,
		"issues": issues,
	}


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
	known_capabilities = catalog.known_capability_ids()
	for capability_id in sorted(_string_set(framework, "required_capabilities") - known_capabilities):
		issues.append(_issue(
			"error",
			"unknown_capability",
			"$.framework.required_capabilities",
			f"GF capability is not present in this installed kit: {capability_id}.",
		))

	architecture = _object(data, "architecture")
	modules = _object_list(architecture, "modules")
	module_ids = _unique_ids(modules, "$.architecture.modules", issues)
	adapters = _object_list(framework, "adapter_boundaries")
	adapter_ids = _unique_ids(adapters, "$.framework.adapter_boundaries", issues)
	for component_id in sorted(module_ids.intersection(adapter_ids)):
		issues.append(_issue(
			"error",
			"ambiguous_component_id",
			"$.framework.adapter_boundaries",
			f"Module and adapter ids share one dependency namespace and must be distinct: {component_id}.",
		))
	known_dependencies = module_ids.union(adapter_ids).union({"gf", "godot"})
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
				_validate_contract_path(
					project_root,
					raw_path.removeprefix("res://"),
					f"$.architecture.modules[{index}].roots[{root_index}]",
					issues,
				)
	issues.extend(_module_dependency_cycle_issues(modules, module_ids))
	for index, adapter in enumerate(adapters):
		raw_path = adapter.get("project_root")
		if isinstance(raw_path, str):
			_validate_contract_path(
				project_root,
				raw_path.removeprefix("res://"),
				f"$.framework.adapter_boundaries[{index}].project_root",
				issues,
			)
	issues.extend(_ownership_root_overlap_issues(modules, adapters))
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
