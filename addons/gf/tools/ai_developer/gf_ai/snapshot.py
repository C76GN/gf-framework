"""Observed project snapshot and declared-vs-observed drift checks."""

from __future__ import annotations

import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from . import api_policy, catalog, dependencies, documentation
from .constants import DEFAULT_CONTRACT_PATH, DEFAULT_SNAPSHOT_PATH, SCHEMA_ROOT, SNAPSHOT_SCHEMA_VERSION, TOOL_VERSION
from .contract import load_contract
from .paths import atomic_write_json, resolve_project_path
from .schema import validate_schema_file


_MAX_PROJECT_SCRIPTS = 20000
_MAX_SCRIPT_BYTES = 2 * 1024 * 1024
_MAX_SOURCE_SCAN_BYTES = 128 * 1024 * 1024
_MAX_CAPABILITY_RECIPE_PACKAGE_EVIDENCE = 40
_MAX_CAPABILITY_RECIPE_GROUP_EVIDENCE = 40
_MAX_CAPABILITY_CLASS_EVIDENCE = 80


def build_snapshot(
	project_root: Path,
	contract_relative_path: str = DEFAULT_CONTRACT_PATH,
) -> dict[str, Any]:
	contract_result = load_contract(project_root, contract_relative_path)
	contract_data = contract_result.get("contract", {})
	if not isinstance(contract_data, dict):
		contract_data = {}
	project_source = _read_project_source(project_root)
	try:
		package_report = catalog.installed_package_report(project_root)
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		package_report = {
			"packages": [],
			"source": "filesystem",
			"lockfile_present": (project_root / ".gf/packages.lock.json").exists(),
			"valid": False,
			"issues": [f"GF API/package catalog is invalid: {exc}"],
		}
	package_ids = list(package_report["packages"])
	try:
		catalog_report = catalog.catalog_compatibility(project_root)
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		catalog_report = {"ok": False, "issues": [f"GF API/package catalog is invalid: {exc}"]}
	try:
		catalog_framework_version = catalog.catalog_framework_version()
	except (OSError, UnicodeDecodeError, ValueError):
		catalog_framework_version = ""
	api_package_policy_analysis = api_policy.analyze_api_package_policy(
		project_root,
		contract_result,
		max_scripts=_MAX_PROJECT_SCRIPTS,
		max_script_bytes=_MAX_SCRIPT_BYTES,
		max_source_bytes=_MAX_SOURCE_SCAN_BYTES,
	)
	documentation_reference_analysis = documentation.analyze_documentation_references(
		project_root,
		contract_result,
	)
	source_scan = api_package_policy_analysis
	capability_readiness = _build_capability_readiness(
		contract_result,
		contract_data,
		package_ids,
		source_scan,
	)
	declared_roots = _declared_roots(project_root, contract_data)
	module_dependency_analysis = dependencies.analyze_module_dependencies(
		project_root,
		contract_data,
		contract_valid=bool(contract_result.get("ok")),
	)
	try:
		from .adapters import agent_status

		agent_report = agent_status(project_root)
	except (OSError, ValueError):
		agent_report = {"installed": [], "drifted": []}
	drift = _build_drift(
		project_root,
		contract_result,
		contract_data,
		package_ids,
		package_report,
		catalog_report,
		capability_readiness,
		declared_roots,
		module_dependency_analysis,
		api_package_policy_analysis,
		documentation_reference_analysis,
	)
	return {
		"schema_version": SNAPSHOT_SCHEMA_VERSION,
		"generator_version": TOOL_VERSION,
		"generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
		"project_root": ".",
		"contract": {
			"path": contract_relative_path,
			"valid": bool(contract_result.get("ok")),
			"sha256": str(contract_result.get("sha256", "")),
			"issue_count": len(contract_result.get("issues", [])),
			"schema_version": int(contract_result.get("schema_version", 0)),
			"current_schema_version": int(contract_result.get("current_schema_version", 0)),
			"migration_required": bool(contract_result.get("migration_required")),
			"migration_available": bool(contract_result.get("migration_available")),
		},
		"framework": {
			"installed": _framework_plugin_exists(project_root),
			"version": catalog.project_framework_version(project_root),
			"catalog_framework_version": catalog_framework_version,
			"catalog_matches_framework": bool(catalog_report["ok"]),
			"plugin_enabled": _editor_plugin_enabled(project_source, "res://addons/gf/plugin.cfg"),
			"packages": package_ids,
			"package_state": {
				"source": package_report["source"],
				"lockfile_present": package_report["lockfile_present"],
				"valid": package_report["valid"],
				"issues": package_report["issues"],
			},
			"extensions": _enabled_extensions(project_source),
			"capability_readiness": capability_readiness,
		},
		"project": {
			"godot_features": _string_array_setting(project_source, "config/features"),
			"script_count": source_scan["script_count"],
			"scanned_script_count": source_scan["scanned_script_count"],
			"scanned_script_bytes": source_scan["scanned_script_bytes"],
			"test_script_count": source_scan["test_script_count"],
			"source_scan_truncated": source_scan["source_scan_truncated"],
			"source_scan_truncation_reason": source_scan["source_scan_truncation_reason"],
			"source_scan_complete": source_scan["source_scan_complete"],
			"skipped_large_script_count": source_scan["skipped_large_script_count"],
			"unreadable_script_count": source_scan["unreadable_script_count"],
			"unsafe_script_path_count": source_scan["unsafe_script_path_count"],
			"unsafe_directory_count": source_scan["unsafe_directory_count"],
			"gf_api_usage": source_scan["gf_api_usage"],
			"test_gf_api_usage": source_scan["test_gf_api_usage"],
			"api_package_policy_analysis": api_package_policy_analysis,
			"documentation_reference_analysis": documentation_reference_analysis,
			"declared_roots": declared_roots,
			"module_dependency_analysis": module_dependency_analysis,
		},
		"agents": {
			"installed": agent_report.get("installed", []),
			"drifted": agent_report.get("drifted", []),
		},
		"drift": drift,
	}


def write_snapshot(
	project_root: Path,
	contract_relative_path: str = DEFAULT_CONTRACT_PATH,
	output_relative_path: str = DEFAULT_SNAPSHOT_PATH,
) -> dict[str, Any]:
	snapshot = build_snapshot(project_root, contract_relative_path)
	schema_issues = validate_schema_file(snapshot, SCHEMA_ROOT / "project_snapshot.schema.json")
	if schema_issues:
		raise RuntimeError(
			"Generated project snapshot violates its schema: "
			+ "; ".join(f"{item['path']}: {item['message']}" for item in schema_issues[:10])
		)
	output_path = resolve_project_path(project_root, output_relative_path)
	atomic_write_json(output_path, snapshot)
	return {"ok": bool(snapshot["drift"]["ok"]), "path": output_relative_path, "snapshot": snapshot}


def project_context(
	project_root: Path,
	contract_relative_path: str = DEFAULT_CONTRACT_PATH,
) -> dict[str, Any]:
	contract_result = load_contract(project_root, contract_relative_path)
	snapshot = build_snapshot(project_root, contract_relative_path)
	contract_data = contract_result.get("contract", {})
	capability_requirements: list[dict[str, Any]] = []
	if contract_result.get("ok") and isinstance(contract_data, dict):
		framework = contract_data.get("framework", {})
		if isinstance(framework, dict):
			readiness = {
				str(item.get("id", "")): item
				for item in snapshot["framework"]["capability_readiness"]
				if isinstance(item, dict)
			}
			for requirement in framework.get("capability_requirements", []):
				if not isinstance(requirement, dict):
					continue
				capability_id = str(requirement.get("id", ""))
				capability_requirements.append({
					"requirement": requirement,
					"catalog": catalog.capability_by_id(capability_id, project_root),
					"readiness": readiness.get(capability_id, {}),
				})
	return {
		"ok": bool(contract_result.get("ok")) and bool(snapshot["drift"]["ok"]),
		"contract": contract_result,
		"snapshot": snapshot,
		"capability_requirements": capability_requirements,
		"workflow": [
			"Migrate an older project contract before making architecture decisions.",
			"Resolve explicit unknowns that block the requested work.",
			"Query a GF capability and exact API signatures before implementation.",
			"Keep project business rules and platform SDK adapters outside addons/gf.",
			"Implement against declared module/adapter ownership and module dependency rules.",
			"Independently review structured verification argv, run only approved checks, and refresh the observed snapshot.",
			"Draft GF feedback only when evidence survives project/framework boundary triage.",
		],
	}


def _build_drift(
	project_root: Path,
	contract_result: dict[str, Any],
	contract_data: dict[str, Any],
	installed_packages: list[str],
	package_report: dict[str, Any],
	catalog_report: dict[str, Any],
	capability_readiness: list[dict[str, Any]],
	declared_roots: list[dict[str, Any]],
	module_dependency_analysis: dict[str, Any],
	api_package_policy_analysis: dict[str, Any],
	documentation_reference_analysis: dict[str, Any],
) -> dict[str, Any]:
	issues: list[dict[str, str]] = []
	for item in contract_result.get("issues", []):
		if isinstance(item, dict):
			code = str(item.get("code", "contract_issue"))
			issues.append({
				"severity": "error" if code == "capability_requirement_pending_review" else str(item.get("severity", "error")),
				"code": code,
				"path": str(item.get("path", "")),
				"message": str(item.get("message", "")),
			})
	if not package_report.get("valid"):
		for message in package_report.get("issues", []):
			issues.append(_issue("error", "package_state_invalid", ".gf/packages.lock.json", str(message)))
	if not catalog_report.get("ok"):
		for message in catalog_report.get("issues", []):
			issues.append(_issue("error", "catalog_framework_mismatch", "addons/gf/plugin.cfg", str(message)))
	for readiness in capability_readiness:
		status = str(readiness.get("status", ""))
		capability_id = str(readiness.get("id", ""))
		if status == "unavailable":
			issues.append(_issue(
				"error",
				"required_capability_unavailable",
				capability_id,
				f"Required capability has no installed provider package: {capability_id}.",
			))
		elif status == "incomplete":
			missing_parts: list[str] = []
			missing_all = readiness.get("missing_recipe_all_of_packages", [])
			if missing_all:
				missing_parts.append("all_of=" + ", ".join(str(item) for item in missing_all))
			unsatisfied_groups = readiness.get("unsatisfied_recipe_any_of_package_groups", [])
			if unsatisfied_groups:
				missing_parts.append("any_of=" + "; ".join(" | ".join(str(item) for item in group) for group in unsatisfied_groups))
			missing = "; ".join(missing_parts) or "bounded evidence omitted"
			issues.append(_issue(
				"error",
				"capability_recipe_package_missing",
				capability_id,
				f"Capability recipe packages are missing for {capability_id}: {missing}.",
			))
	if contract_result.get("ok"):
		framework = contract_data.get("framework", {})
		if isinstance(framework, dict):
			required = _string_values(framework.get("required_packages", []))
			forbidden = _string_values(framework.get("forbidden_packages", []))
			for package_id in sorted(required - set(installed_packages)):
				issues.append(_issue("error", "required_package_missing", package_id, f"Required package is not installed: {package_id}."))
			for package_id in sorted(forbidden.intersection(installed_packages)):
				issues.append(_issue("error", "forbidden_package_installed", package_id, f"Forbidden package is installed: {package_id}."))
		module_contracts = _module_contract_map(contract_data)
		for root in declared_roots:
			module = module_contracts.get(str(root["module_id"]), {})
			if not root["exists"] and module.get("ownership") != "generated":
				issues.append(_issue("error", "declared_module_root_missing", str(root["path"]), f"Declared module root is missing: {root['path']}."))
		architecture = contract_data.get("architecture", {})
		if isinstance(architecture, dict):
			profile_path = str(architecture.get("project_profile_path", ""))
			if profile_path and not resolve_project_path(project_root, profile_path).is_file():
				issues.append(_issue("error", "project_profile_missing", profile_path, "Declared project layout profile is missing."))
		verification = contract_data.get("verification", {})
		if isinstance(verification, dict):
			for required_path in verification.get("required_paths", []):
				if isinstance(required_path, str) and not resolve_project_path(project_root, required_path).exists():
					issues.append(_issue("error", "verification_path_missing", required_path, f"Required verification path is missing: {required_path}."))
		for unknown in contract_data.get("unknowns", []):
			if isinstance(unknown, dict) and unknown.get("blocking") is True:
				unknown_id = str(unknown.get("id", "unknown"))
				issues.append(_issue("error", "blocking_unknown", unknown_id, f"Project contract still has a blocking unknown: {unknown_id}."))
		issues.extend(_module_dependency_drift_issues(contract_data, module_dependency_analysis))
	issues.extend(_api_package_policy_drift_issues(api_package_policy_analysis))
	issues.extend(_documentation_reference_drift_issues(documentation_reference_analysis))
	error_count = sum(1 for issue in issues if issue["severity"] == "error")
	warning_count = sum(1 for issue in issues if issue["severity"] == "warning")
	return {
		"ok": error_count == 0,
		"error_count": error_count,
		"warning_count": warning_count,
		"issues": issues,
	}


def _api_package_policy_drift_issues(analysis: dict[str, Any]) -> list[dict[str, str]]:
	issues: list[dict[str, str]] = []
	status = str(analysis.get("status", "partial"))
	if status != "complete":
		issues.append(_issue(
			"error",
			"api_package_policy_analysis_incomplete",
			"$.architecture.source_domains",
			(
				"GF public API package-policy analysis is not complete "
				f"(status={status}, catalog_issues={int(analysis.get('catalog_issue_count', 0))}, "
				f"unreadable_scripts={int(analysis.get('unreadable_script_count', 0))}, "
				f"unsafe_paths={int(analysis.get('unsafe_script_path_count', 0))}, "
				f"unsafe_directories={int(analysis.get('unsafe_directory_count', 0))}, "
				f"invalid_gdignore={int(analysis.get('invalid_gdignore_count', 0))}, "
				f"directory_identity_drift={int(analysis.get('directory_identity_drift_count', 0))}, "
				f"truncated={bool(analysis.get('source_scan_truncated'))})."
			),
		))
	actionable_count = int(analysis.get("actionable_count", 0))
	actionable = [
		item for item in analysis.get("actionable_observations", [])
		if isinstance(item, dict)
	]
	for item in actionable:
		policy = str(item.get("policy", "outside_policy"))
		code = "forbidden_gf_api_package_reference" if policy == "forbidden" else "undeclared_gf_api_package_reference"
		source_path = str(item.get("source_path", "$.architecture.source_domains"))
		line = int(item.get("line", 0))
		owner_kind = str(item.get("owner_kind", "owner"))
		owner_name = str(item.get("owner_name", ""))
		package_id = str(item.get("package_id", ""))
		domain = str(item.get("source_domain", "runtime"))
		issues.append(_issue(
			"error",
			code,
			source_path,
			f"{domain} {owner_kind} {owner_name!r} at {source_path}:{line} maps to {policy} package {package_id!r}.",
		))
	if actionable_count > len(actionable):
		issues.append(_issue(
			"error",
			"gf_api_package_reference_evidence_truncated",
			"$.architecture.source_domains",
			f"GF API package policy has {actionable_count - len(actionable)} additional bounded actionable observation(s).",
		))
	if int(analysis.get("advisory_count", 0)) > 0:
		issues.append(_issue(
			"warning",
			"dynamic_gf_api_reference_advisory",
			"$.architecture.source_domains",
			f"Observed {int(analysis.get('advisory_count', 0))} dynamic or uncertain GF API reference(s); no package intent was inferred.",
		))
	return issues


def _documentation_reference_drift_issues(analysis: dict[str, Any]) -> list[dict[str, str]]:
	issues: list[dict[str, str]] = []
	status = str(analysis.get("status", "partial"))
	if status not in ("complete", "not_configured"):
		issues.append(_issue(
			"error",
			"documentation_reference_analysis_incomplete",
			"$.architecture.documentation_roots",
			(
				"GF documentation reference analysis is not complete "
				f"(status={status}, catalog_issues={int(analysis.get('catalog_issue_count', 0))}, "
				f"entries={int(analysis.get('entry_count', 0))}, "
				f"oversized_files={int(analysis.get('skipped_large_file_count', 0))}, "
				f"unreadable_files={int(analysis.get('unreadable_file_count', 0))}, "
				f"unsafe_paths={int(analysis.get('unsafe_file_path_count', 0))}, "
				f"unsafe_directories={int(analysis.get('unsafe_directory_count', 0))}, "
				f"directory_identity_drift={int(analysis.get('directory_identity_drift_count', 0))}, "
				f"truncated={bool(analysis.get('scan_truncated'))}, "
				f"truncation_reason={str(analysis.get('scan_truncation_reason', ''))})."
			),
		))
	root_issue_codes = {
		"missing": "documentation_root_missing",
		"not_directory": "documentation_root_not_directory",
		"unsafe": "documentation_root_unsafe",
		"excluded": "documentation_root_excluded",
		"generated": "documentation_root_generated",
		"drifted": "documentation_root_identity_drift",
	}
	for root_state in analysis.get("documentation_roots", []):
		if not isinstance(root_state, dict):
			continue
		root_status = str(root_state.get("status", "unsafe"))
		code = root_issue_codes.get(root_status)
		if code is None:
			continue
		root = str(root_state.get("root", "$.architecture.documentation_roots"))
		issues.append(_issue(
			"error",
			code,
			root,
			f"Declared documentation root is not safely scannable (status={root_status}): {root}.",
		))
	actionable_count = int(analysis.get("actionable_count", 0))
	actionable = [
		item for item in analysis.get("actionable_references", [])
		if isinstance(item, dict)
	]
	for item in actionable:
		status = str(item.get("status", "unknown_owner"))
		code = "stale_gf_api_member_reference" if status == "unknown_member" else "stale_gf_api_owner_reference"
		source_path = str(item.get("source_path", "$.architecture.documentation_roots"))
		line = int(item.get("line", 0))
		column = int(item.get("column", 0))
		symbol = str(item.get("symbol", ""))
		issues.append(_issue(
			"error",
			code,
			source_path,
			f"GF API reference {symbol!r} is absent from the exact catalog at {source_path}:{line}:{column}.",
		))
	if actionable_count > len(actionable):
		issues.append(_issue(
			"error",
			"documentation_gf_reference_evidence_truncated",
			"$.architecture.documentation_roots",
			f"Documentation analysis has {actionable_count - len(actionable)} additional bounded actionable reference(s).",
		))
	if int(analysis.get("advisory_count", 0)) > 0:
		issues.append(_issue(
			"warning",
			"documentation_gf_reference_advisory",
			"$.architecture.documentation_roots",
			(
				f"Observed {int(analysis.get('advisory_count', 0))} GF-shaped prose reference(s); "
				"prose is advisory and was not treated as executable API evidence."
			),
		))
	return issues


def _build_capability_readiness(
	contract_result: dict[str, Any],
	contract_data: dict[str, Any],
	installed_packages: list[str],
	source_scan: dict[str, Any],
) -> list[dict[str, Any]]:
	if not contract_result.get("ok"):
		return []
	framework = contract_data.get("framework", {})
	if not isinstance(framework, dict):
		return []
	capabilities = catalog.capability_records_by_id()
	recipes = catalog.recipe_records_by_id()
	installed = set(installed_packages)
	observed_usage = set(_string_values(source_scan.get("gf_api_usage", [])))
	scan_complete = bool(source_scan.get("source_scan_complete"))
	result: list[dict[str, Any]] = []
	for requirement in framework.get("capability_requirements", []):
		if not isinstance(requirement, dict):
			continue
		capability_id = str(requirement.get("id", ""))
		capability = capabilities.get(capability_id, {})
		catalog_packages = sorted(_string_values(capability.get("packages", [])))
		installed_catalog_packages = sorted(installed.intersection(catalog_packages))
		selected_recipes = sorted(_string_values(requirement.get("recipes", [])))
		recipe_classes: set[str] = set()
		for recipe_id in selected_recipes:
			recipe_classes.update(_string_values(recipes.get(recipe_id, {}).get("primary_classes", [])))
		package_readiness = catalog.recipe_package_readiness(selected_recipes, installed)
		all_recipe_packages = package_readiness["all_of"]
		all_missing_recipe_packages = package_readiness["missing_all_of"]
		all_recipe_groups = package_readiness["any_of"]
		all_unsatisfied_recipe_groups = package_readiness["unsatisfied_any_of"]
		observation_candidates = set(_string_values(capability.get("primary_classes", []))).union(recipe_classes)
		all_observed_classes = sorted(observed_usage.intersection(observation_candidates))
		if not installed_catalog_packages:
			status = "unavailable"
		elif not package_readiness["satisfied"]:
			status = "incomplete"
		elif all_observed_classes:
			status = "observed"
		elif scan_complete:
			status = "available_unobserved"
		else:
			status = "evidence_incomplete"
		acceptance = requirement.get("acceptance", [])
		recipe_packages = all_recipe_packages[:_MAX_CAPABILITY_RECIPE_PACKAGE_EVIDENCE]
		missing_recipe_packages = all_missing_recipe_packages[:_MAX_CAPABILITY_RECIPE_PACKAGE_EVIDENCE]
		recipe_groups = all_recipe_groups[:_MAX_CAPABILITY_RECIPE_GROUP_EVIDENCE]
		unsatisfied_recipe_groups = all_unsatisfied_recipe_groups[:_MAX_CAPABILITY_RECIPE_GROUP_EVIDENCE]
		observed_classes = all_observed_classes[:_MAX_CAPABILITY_CLASS_EVIDENCE]
		result.append({
			"id": capability_id,
			"decision_state": str(requirement.get("decision_state", "")),
			"owner": str(requirement.get("owner", "")),
			"status": status,
			"catalog_packages": catalog_packages,
			"installed_catalog_packages": installed_catalog_packages,
			"recipe_all_of_packages": recipe_packages,
			"recipe_all_of_package_count": len(all_recipe_packages),
			"recipe_all_of_packages_truncated": len(recipe_packages) < len(all_recipe_packages),
			"missing_recipe_all_of_packages": missing_recipe_packages,
			"missing_recipe_all_of_package_count": len(all_missing_recipe_packages),
			"missing_recipe_all_of_packages_truncated": len(missing_recipe_packages) < len(all_missing_recipe_packages),
			"recipe_any_of_package_groups": recipe_groups,
			"recipe_any_of_package_group_count": len(all_recipe_groups),
			"recipe_any_of_package_groups_truncated": len(recipe_groups) < len(all_recipe_groups),
			"unsatisfied_recipe_any_of_package_groups": unsatisfied_recipe_groups,
			"unsatisfied_recipe_any_of_package_group_count": len(all_unsatisfied_recipe_groups),
			"unsatisfied_recipe_any_of_package_groups_truncated": len(unsatisfied_recipe_groups) < len(all_unsatisfied_recipe_groups),
			"observed_classes": observed_classes,
			"observed_class_count": len(all_observed_classes),
			"observed_classes_truncated": len(observed_classes) < len(all_observed_classes),
			"observation_complete": scan_complete,
			"recipes": selected_recipes,
			"acceptance_count": len(acceptance) if isinstance(acceptance, list) else 0,
		})
	return result


def _declared_roots(project_root: Path, contract_data: dict[str, Any]) -> list[dict[str, Any]]:
	result: list[dict[str, Any]] = []
	architecture = contract_data.get("architecture", {})
	if not isinstance(architecture, dict):
		return result
	modules = architecture.get("modules", [])
	if not isinstance(modules, list):
		return result
	for module in modules:
		if not isinstance(module, dict):
			continue
		module_id = str(module.get("id", ""))
		for raw_path in module.get("roots", []):
			if not isinstance(raw_path, str):
				continue
			relative = raw_path.removeprefix("res://")
			try:
				path = resolve_project_path(project_root, relative)
				exists = path.exists()
			except ValueError:
				exists = False
			result.append({"module_id": module_id, "path": raw_path, "exists": exists})
	return result


def _module_dependency_drift_issues(
	contract_data: dict[str, Any],
	analysis: dict[str, Any],
) -> list[dict[str, str]]:
	issues: list[dict[str, str]] = []
	status = str(analysis.get("status", "partial"))
	if status not in ("complete", "not_configured"):
		issues.append(_issue(
			"error",
			"module_dependency_analysis_incomplete",
			"$.architecture",
			(
				"Observed module/adapter dependency and path-role analysis is incomplete "
				f"(status={status}, truncated={bool(analysis.get('truncated'))}, "
				f"unreadable_files={int(analysis.get('unreadable_file_count', 0))}, "
				f"missing_roots={int(analysis.get('missing_root_count', 0))}, "
				f"unsafe_paths={int(analysis.get('unsafe_path_count', 0))}, "
				f"missing_owned_resources={int(analysis.get('missing_owned_resource_count', 0))}, "
				f"unsafe_owned_resources={int(analysis.get('unsafe_owned_resource_count', 0))}, "
				f"partial_path_roles={int(analysis.get('partial_path_role_count', 0))}, "
				f"ambiguous_classes={int(analysis.get('ambiguous_class_name_count', 0))})."
			),
		))

	scan_root_violation_count = int(analysis.get("path_role_dependency_violation_count", 0))
	scan_root_violations = [
		item
		for item in analysis.get("path_role_dependency_violations", [])
		if isinstance(item, dict)
	]
	for item in scan_root_violations:
		source_path = str(item.get("source_path", "$.architecture.path_roles"))
		source_module = str(item.get("source_module", ""))
		target_path = str(item.get("target_path", ""))
		target_module = str(item.get("target_module", ""))
		line = int(item.get("line", 0))
		issues.append(_issue(
			"error",
			"undeclared_scan_root_dependency",
			source_path,
			f"Module {source_module!r} uses scan root {target_path!r} at "
			f"{source_path}:{line}, but covered module/adapter component {target_module!r} is neither "
			"self-owned nor declared in allowed_dependencies.",
		))
	if scan_root_violation_count > len(scan_root_violations):
		issues.append(_issue(
			"error",
			"undeclared_scan_root_dependency",
			"$.architecture.path_roles",
			f"Scan-root dependency evidence omitted "
			f"{scan_root_violation_count - len(scan_root_violations)} bounded observation(s).",
		))

	for item in analysis.get("ambiguous_class_names", []):
		if not isinstance(item, dict):
			continue
		class_name = str(item.get("class_name", ""))
		paths = [str(path) for path in item.get("paths", []) if isinstance(path, str)]
		issues.append(_issue(
			"error",
			"ambiguous_project_class_name",
			paths[0] if paths else "$.architecture.modules",
			f"Project class_name {class_name!r} has multiple module/adapter owners: {', '.join(paths)}.",
		))

	modules = _module_contract_map(contract_data)
	for edge in analysis.get("edges", []):
		if not isinstance(edge, dict):
			continue
		source_module = str(edge.get("source_module", ""))
		target_module = str(edge.get("target_module", ""))
		source_contract = modules.get(source_module, {})
		allowed = _string_values(source_contract.get("allowed_dependencies", []))
		forbidden = _string_values(source_contract.get("forbidden_dependencies", []))
		evidence_path, evidence_text = _dependency_edge_evidence(edge)
		if target_module in forbidden:
			issues.append(_issue(
				"error",
				"forbidden_module_dependency",
				evidence_path,
				f"Module {source_module!r} depends on forbidden module/adapter target "
				f"{target_module!r}.{evidence_text}",
			))
		elif target_module not in allowed:
			issues.append(_issue(
				"error",
				"undeclared_module_dependency",
				evidence_path,
				f"Module {source_module!r} depends on undeclared module/adapter target "
				f"{target_module!r}.{evidence_text}",
			))

	for component in analysis.get("cycles", []):
		if not isinstance(component, list):
			continue
		module_ids = [str(module_id) for module_id in component]
		issues.append(_issue(
			"error",
			"observed_module_dependency_cycle",
			"$.architecture.modules",
			f"Observed project source contains a module dependency cycle: {' -> '.join(module_ids + module_ids[:1])}.",
		))

	unowned_count = int(analysis.get("unowned_reference_count", 0))
	if unowned_count > 0:
		references = analysis.get("unowned_references", [])
		first = references[0] if isinstance(references, list) and references else {}
		source_path = str(first.get("source_path", "$.architecture.modules")) if isinstance(first, dict) else "$.architecture.modules"
		target_path = str(first.get("target_path", "")) if isinstance(first, dict) else ""
		line = int(first.get("line", 0)) if isinstance(first, dict) else 0
		detail = f" First evidence: {source_path}:{line} -> {target_path}." if target_path else ""
		issues.append(_issue(
			"warning",
			"unowned_project_resource_reference",
			source_path,
			f"Declared modules reference {unowned_count} project resource path(s) outside "
			f"module/adapter ownership.{detail}",
		))
	return issues


def _module_contract_map(contract_data: dict[str, Any]) -> dict[str, dict[str, Any]]:
	architecture = contract_data.get("architecture", {})
	if not isinstance(architecture, dict):
		return {}
	modules = architecture.get("modules", [])
	if not isinstance(modules, list):
		return {}
	return {
		str(module.get("id", "")): module
		for module in modules
		if isinstance(module, dict)
	}


def _dependency_edge_evidence(edge: dict[str, Any]) -> tuple[str, str]:
	evidence = edge.get("evidence", [])
	if not isinstance(evidence, list) or not evidence or not isinstance(evidence[0], dict):
		return "$.architecture.modules", ""
	first = evidence[0]
	source_path = str(first.get("source_path", "$.architecture.modules"))
	line = int(first.get("line", 0))
	kind = str(first.get("kind", "reference"))
	symbol = str(first.get("symbol", ""))
	return source_path, f" Evidence: {source_path}:{line} {kind} {symbol!r}."


def _read_project_source(project_root: Path) -> str:
	try:
		path = resolve_project_path(project_root, "project.godot", must_exist=True)
		with path.open("rb") as stream:
			raw = stream.read(16 * 1024 * 1024 + 1)
		if len(raw) > 16 * 1024 * 1024:
			raise ValueError("project.godot exceeds the 16 MiB snapshot input budget.")
		return raw.decode("utf-8", errors="strict")
	except (OSError, UnicodeDecodeError, ValueError) as exc:
		raise ValueError(f"project.godot is unreadable: {exc}") from exc


def _framework_plugin_exists(project_root: Path) -> bool:
	try:
		return resolve_project_path(project_root, "addons/gf/plugin.cfg", must_exist=True).is_file()
	except ValueError:
		return False


def _string_array_setting(source: str, setting: str) -> list[str]:
	pattern = re.compile(rf"(?m)^\s*{re.escape(setting)}\s*=\s*(?P<value>[^\r\n]+?)\s*$")
	match = pattern.search(source)
	if match is None:
		return []
	value = match.group("value")
	packed_prefix = "PackedStringArray("
	typed_prefix = "Array[String](["
	if value.startswith(packed_prefix) and value.endswith(")"):
		content = value[len(packed_prefix):-1]
	elif value.startswith(typed_prefix) and value.endswith("])"):
		content = value[len(typed_prefix):-2]
	else:
		return []
	return sorted(set(re.findall(r'"((?:[^"\\]|\\.)*)"', content)))


def _project_section(source: str, section_name: str) -> str:
	section = re.search(
		rf"(?ms)^\[{re.escape(section_name)}\]\s*(.*?)(?=^\[[^\]]+\]|\Z)",
		source,
	)
	return section.group(1) if section is not None else ""


def _enabled_extensions(source: str) -> list[str]:
	return _string_array_setting(_project_section(source, "gf"), "extensions/enabled")


def _editor_plugin_enabled(source: str, plugin_path: str) -> bool:
	return plugin_path in _string_array_setting(_project_section(source, "editor_plugins"), "enabled")


def _string_values(value: Any) -> set[str]:
	return {str(item) for item in value if isinstance(item, str)} if isinstance(value, list) else set()


def _issue(severity: str, code: str, path: str, message: str) -> dict[str, str]:
	return {"severity": severity, "code": code, "path": path, "message": message}
