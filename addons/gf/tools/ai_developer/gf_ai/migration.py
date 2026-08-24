"""Hash-bound, single-step migrations for the GF project intent contract."""

from __future__ import annotations

import copy
import json
import re
from pathlib import Path
from typing import Any

from .constants import CONTRACT_SCHEMA_VERSION, DEFAULT_CONTRACT_PATH, TOOL_VERSION
from .contract import contract_path, validate_contract_data
from .paths import CompareExchangeError, atomic_compare_exchange_json, read_json_object, sha256_json


_SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
_MAX_CONTRACT_BYTES = 1024 * 1024


def plan_contract_migration(
	project_root: Path,
	relative_path: str = DEFAULT_CONTRACT_PATH,
) -> dict[str, Any]:
	try:
		path = contract_path(project_root, relative_path)
	except ValueError as exc:
		return _blocked(relative_path, 0, "", "unsafe_contract_path", str(exc))
	if not path.is_file():
		return _blocked(relative_path, 0, "", "missing_contract", "Project contract is missing.")
	try:
		source = read_json_object(path, max_bytes=_MAX_CONTRACT_BYTES)
	except ValueError as exc:
		return _blocked(relative_path, 0, "", "invalid_contract_json", str(exc))
	source_sha256 = sha256_json(source)
	raw_version = source.get("schema_version")
	source_version = raw_version if isinstance(raw_version, int) and not isinstance(raw_version, bool) else 0
	base = {
		"tool_version": TOOL_VERSION,
		"migration_id": "",
		"contract_path": relative_path,
		"source": {"schema_version": source_version, "sha256": source_sha256},
		"target": {"schema_version": CONTRACT_SCHEMA_VERSION, "sha256": source_sha256},
		"changes": [],
		"candidate": {},
		"plan_sha256": "",
		"issues": [],
	}
	if source_version == CONTRACT_SCHEMA_VERSION:
		validation_issues = validate_contract_data(source, project_root)
		if any(issue.get("severity") == "error" for issue in validation_issues):
			return {"ok": False, "status": "blocked", **base, "issues": validation_issues}
		return {"ok": True, "status": "up_to_date", **base, "issues": validation_issues}
	if source_version not in (1, 2, 3, 4) or CONTRACT_SCHEMA_VERSION != 5:
		return {
			"ok": False,
			"status": "blocked",
			**base,
			"issues": [_issue(
				"unsupported_contract_migration",
				"$.schema_version",
				f"No migration exists from contract schema v{source_version} to v{CONTRACT_SCHEMA_VERSION}.",
			)],
		}
	candidate = copy.deepcopy(source)
	conversion_issues: list[dict[str, str]] = []
	changes: list[dict[str, str]] = []
	if source_version == 1:
		candidate, conversion_issues = _migrate_v1_to_v2(candidate)
		changes.append({
			"code": "capability_requirements_structured",
			"path": "$.framework.capability_requirements",
			"message": "Converted required capability ids into owner-bound capability requirement records.",
		})
	if source_version <= 2 and not conversion_issues:
		candidate, conversion_issues = _migrate_v2_to_v3(candidate)
		changes.append({
			"code": "path_roles_initialized",
			"path": "$.architecture.path_roles",
			"message": "Initialized the closed project path-role declaration list.",
		})
	if source_version <= 3 and not conversion_issues:
		candidate, conversion_issues = _migrate_v3_to_v4(candidate)
		changes.extend((
			{
				"code": "source_domains_initialized",
				"path": "$.architecture.source_domains",
				"message": "Initialized the closed project source-domain declaration list.",
			},
			{
				"code": "declare_source_domain_roots",
				"path": "$.architecture.source_domains",
				"message": (
					"Review and declare test, tool, and editor roots: unmatched scripts now "
					"default fail-safe to runtime, and the legacy test-path heuristic is not authoritative."
				),
			},
		))
	if not conversion_issues:
		candidate, conversion_issues = _migrate_v4_to_v5(candidate)
		changes.extend((
			{
				"code": "documentation_roots_initialized",
				"path": "$.architecture.documentation_roots",
				"message": "Initialized the closed project documentation-root declaration list.",
			},
			{
				"code": "declare_documentation_roots",
				"path": "$.architecture.documentation_roots",
				"message": (
					"Declare only the project documentation roots that should be checked against "
					"the exact installed GF API catalog; an empty list keeps the opt-in check disabled."
				),
			},
		))
	if conversion_issues:
		return {"ok": False, "status": "blocked", **base, "candidate": candidate, "issues": conversion_issues}
	validation_issues = validate_contract_data(candidate, project_root)
	if len((json.dumps(candidate, ensure_ascii=False, indent=2, allow_nan=False) + "\n").encode("utf-8")) > _MAX_CONTRACT_BYTES:
		validation_issues.append(_issue(
			"migrated_contract_budget_exceeded",
			"$",
			"Migrated project contract exceeds the one-megabyte runtime input budget.",
		))
	target_sha256 = sha256_json(candidate)
	migration_id = f"project-contract-v{source_version}-to-v{CONTRACT_SCHEMA_VERSION}"
	if any(issue.get("severity") == "error" for issue in validation_issues):
		return _with_plan_hash({
			"ok": False,
			"status": "blocked",
			**base,
			"migration_id": migration_id,
			"target": {"schema_version": CONTRACT_SCHEMA_VERSION, "sha256": target_sha256},
			"changes": changes,
			"candidate": candidate,
			"issues": validation_issues,
		})
	return _with_plan_hash({
		"ok": True,
		"status": "ready",
		**base,
		"migration_id": migration_id,
		"target": {"schema_version": CONTRACT_SCHEMA_VERSION, "sha256": target_sha256},
		"changes": changes,
		"candidate": candidate,
		"issues": validation_issues,
	})


def apply_contract_migration(
	project_root: Path,
	expected_plan_sha256: str,
	relative_path: str = DEFAULT_CONTRACT_PATH,
	*,
	human_approved: bool = False,
) -> dict[str, Any]:
	if not isinstance(expected_plan_sha256, str) or _SHA256_PATTERN.fullmatch(expected_plan_sha256) is None:
		return _apply_blocked(relative_path, "invalid_expected_plan_sha256", "Expected plan hash must be exactly 64 lowercase hexadecimal characters.")
	plan = plan_contract_migration(project_root, relative_path)
	if plan.get("status") == "up_to_date":
		return {**plan, "ok": False, "status": "blocked", "issues": [_issue(
			"no_pending_contract_migration",
			"$.schema_version",
			"Project contract already uses the current schema; no reviewed migration is pending.",
		)]}
	if not plan.get("ok"):
		return plan
	if expected_plan_sha256 != plan["plan_sha256"]:
		return {**plan, "ok": False, "status": "blocked", "issues": [_issue(
			"migration_plan_changed",
			"expected_plan_sha256",
			"Migration source, target, tool, or path changed after the plan was reviewed.",
		)]}
	if not human_approved:
		return {**plan, "ok": False, "status": "blocked", "issues": [_issue(
			"human_approval_required",
			"expected_plan_sha256",
			"Contract migration requires explicit approval in an interactive human terminal.",
		)]}
	path = contract_path(project_root, relative_path)
	try:
		target_sha256 = atomic_compare_exchange_json(path, plan["source"]["sha256"], plan["candidate"])
	except (CompareExchangeError, OSError, ValueError) as exc:
		message = str(exc)
		if "changed" in message:
			code = "contract_source_changed"
		elif "lock already exists" in message:
			code = "contract_migration_locked"
		elif "linked or reparsed" in message:
			code = "unsafe_contract_path"
		else:
			code = "contract_migration_write_failed"
		return {**plan, "ok": False, "status": "blocked", "issues": [_issue(code, relative_path, message)]}
	if target_sha256 != plan["target"]["sha256"]:
		return {**plan, "ok": False, "status": "blocked", "issues": [_issue(
			"contract_target_hash_mismatch",
			relative_path,
			"Applied project contract does not match the reviewed migration target.",
		)]}
	return {**plan, "status": "applied"}


def _migrate_v1_to_v2(source: dict[str, Any]) -> tuple[dict[str, Any], list[dict[str, str]]]:
	candidate = copy.deepcopy(source)
	framework = candidate.get("framework")
	if not isinstance(framework, dict):
		return candidate, [_issue("invalid_legacy_framework", "$.framework", "Legacy framework field must be an object.")]
	legacy_capabilities = framework.get("required_capabilities")
	if not isinstance(legacy_capabilities, list):
		return candidate, [_issue(
			"invalid_legacy_capabilities",
			"$.framework.required_capabilities",
			"Legacy required_capabilities must be an array.",
		)]
	if len(legacy_capabilities) > 100:
		return candidate, [_issue(
			"invalid_legacy_capabilities",
			"$.framework.required_capabilities",
			"Legacy required_capabilities exceeds the 100-item migration budget.",
		)]
	seen: set[str] = set()
	for index, capability_id in enumerate(legacy_capabilities):
		if not isinstance(capability_id, str) or re.fullmatch(r"[a-z][a-z0-9_-]*", capability_id) is None:
			return candidate, [_issue(
				"invalid_legacy_capability",
				f"$.framework.required_capabilities[{index}]",
				"Legacy capability id is invalid.",
			)]
		if capability_id in seen:
			return candidate, [_issue(
				"duplicate_legacy_capability",
				f"$.framework.required_capabilities[{index}]",
				f"Legacy capability id is duplicated: {capability_id}.",
			)]
		seen.add(capability_id)
	framework.pop("required_capabilities", None)
	framework["capability_requirements"] = [
		{"id": capability_id, "decision_state": "pending_review", "owner": "project", "recipes": [], "acceptance": [], "notes": ""}
		for capability_id in legacy_capabilities
	]
	candidate["schema_version"] = 2
	return candidate, []


def _migrate_v2_to_v3(source: dict[str, Any]) -> tuple[dict[str, Any], list[dict[str, str]]]:
	candidate = copy.deepcopy(source)
	architecture = candidate.get("architecture")
	if not isinstance(architecture, dict):
		return candidate, [_issue("invalid_legacy_architecture", "$.architecture", "Legacy architecture field must be an object.")]
	legacy_owned_resources = architecture.get("owned_resources")
	if legacy_owned_resources is not None and not isinstance(legacy_owned_resources, list):
		return candidate, [_issue(
			"invalid_legacy_owned_resources",
			"$.architecture.owned_resources",
			"Legacy owned_resources must be an array when present.",
		)]
	if "path_roles" in architecture:
		return candidate, [_issue(
			"invalid_legacy_path_roles",
			"$.architecture.path_roles",
			"Legacy contract schemas must not predeclare schema v3 path_roles.",
		)]
	architecture["path_roles"] = []
	candidate["schema_version"] = 3
	return candidate, []


def _migrate_v3_to_v4(source: dict[str, Any]) -> tuple[dict[str, Any], list[dict[str, str]]]:
	candidate = copy.deepcopy(source)
	architecture = candidate.get("architecture")
	if not isinstance(architecture, dict):
		return candidate, [_issue("invalid_legacy_architecture", "$.architecture", "Legacy architecture field must be an object.")]
	if "source_domains" in architecture:
		return candidate, [_issue(
			"invalid_legacy_source_domains",
			"$.architecture.source_domains",
			"Legacy contract schemas must not predeclare schema v4 source_domains.",
		)]
	architecture["source_domains"] = []
	candidate["schema_version"] = 4
	return candidate, []


def _migrate_v4_to_v5(source: dict[str, Any]) -> tuple[dict[str, Any], list[dict[str, str]]]:
	candidate = copy.deepcopy(source)
	architecture = candidate.get("architecture")
	if not isinstance(architecture, dict):
		return candidate, [_issue("invalid_legacy_architecture", "$.architecture", "Legacy architecture field must be an object.")]
	if "documentation_roots" in architecture:
		return candidate, [_issue(
			"invalid_legacy_documentation_roots",
			"$.architecture.documentation_roots",
			"Legacy contract schemas must not predeclare schema v5 documentation_roots.",
		)]
	architecture["documentation_roots"] = []
	candidate["schema_version"] = CONTRACT_SCHEMA_VERSION
	return candidate, []


def _blocked(relative_path: str, source_version: int, source_sha256: str, code: str, message: str) -> dict[str, Any]:
	return {
		"ok": False,
		"status": "blocked",
		"tool_version": TOOL_VERSION,
		"migration_id": "",
		"contract_path": relative_path,
		"source": {"schema_version": source_version, "sha256": source_sha256},
		"target": {"schema_version": CONTRACT_SCHEMA_VERSION, "sha256": ""},
		"changes": [],
		"candidate": {},
		"plan_sha256": "",
		"issues": [_issue(code, relative_path, message)],
	}


def _with_plan_hash(plan: dict[str, Any]) -> dict[str, Any]:
	plan["plan_sha256"] = sha256_json({
		"tool_version": plan["tool_version"],
		"migration_id": plan["migration_id"],
		"contract_path": plan["contract_path"],
		"source": plan["source"],
		"target": plan["target"],
	})
	return plan


def _apply_blocked(relative_path: str, code: str, message: str) -> dict[str, Any]:
	return {
		"ok": False,
		"status": "blocked",
		"tool_version": TOOL_VERSION,
		"migration_id": "",
		"contract_path": relative_path,
		"source": {"schema_version": 0, "sha256": ""},
		"target": {"schema_version": CONTRACT_SCHEMA_VERSION, "sha256": ""},
		"changes": [],
		"candidate": {},
		"plan_sha256": "",
		"issues": [_issue(code, "expected_plan_sha256", message)],
	}


def _issue(code: str, path: str, message: str) -> dict[str, str]:
	return {"severity": "error", "code": code, "path": path, "message": message}
