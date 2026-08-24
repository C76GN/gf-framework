#!/usr/bin/env python3
"""Canonical Project Layout profile admission and read-only audit support."""

from __future__ import annotations

import fnmatch
import hashlib
import json
import math
import os
import re
import stat
import time
from pathlib import Path
from typing import Any
from typing import Callable
from typing import Mapping

import gf_process_supervisor
from gf_process_authority import FrozenGitProcess


ROOT = Path(__file__).resolve().parents[1]
PROFILE_MODES = ("strict", "legacy", "shadow")
PROFILE_LEGACY_REMOVAL_VERSION = "12.0.0"

PROJECT_LAYOUT_PROFILE_CONTRACT_RELATIVE_PATH = (
	"addons/gf/tools/project_layout/contracts/project_profile_v1.contract.json"
)
PROJECT_LAYOUT_PROFILE_CONTRACT_PATH = ROOT / PROJECT_LAYOUT_PROFILE_CONTRACT_RELATIVE_PATH
PROJECT_LAYOUT_PROFILE_CONTRACT_MAX_BYTES = 1024 * 1024
PROJECT_LAYOUT_PROFILE_CONTRACT_UNAVAILABLE = "PROJECT_LAYOUT_PROFILE_CONTRACT_UNAVAILABLE"
PROJECT_LAYOUT_PROFILE_CONTRACT_INVALID = "PROJECT_LAYOUT_PROFILE_CONTRACT_INVALID"
PROJECT_PROFILE_STRICT_MAX_BYTES = 1024 * 1024
PROJECT_PROFILE_STRICT_MAX_DEPTH = 64
PROJECT_PROFILE_STRICT_MAX_NODES = 16384
PROJECT_PROFILE_STRICT_DEPTH_ERROR = (
	"Project profile JSON nesting exceeds the strict structural budget."
)
PROJECT_PROFILE_STRICT_NODE_ERROR = (
	"Project profile JSON structure exceeds the strict value-count budget."
)
PROJECT_PROFILE_RESOURCE_LIMIT_REASON_CODE = (
	"PROJECT_LAYOUT_PROFILE_RESOURCE_LIMIT_EXCEEDED"
)
PROJECT_PROFILE_REGEX_UNSAFE_REASON_CODE = "PROJECT_LAYOUT_PROFILE_REGEX_UNSAFE"
PROJECT_PROFILE_GIT_STDOUT_MAX_BYTES = 16 * 1024 * 1024
PROJECT_PROFILE_GIT_STDERR_MAX_BYTES = 64 * 1024
PROJECT_PROFILE_GIT_TIMEOUT_SECONDS = 30.0
PROJECT_PROFILE_INVENTORY_MAX_PATHS = 20_000
PROJECT_PROFILE_INVENTORY_MAX_PATH_BYTES = 16_384
PROJECT_PROFILE_INVENTORY_MAX_UTF8_BYTES = 16 * 1024 * 1024
PROJECT_PROFILE_INVENTORY_MAX_SORT_WORK_UNITS = 400_000
PROJECT_PROFILE_AUDIT_MAX_WORK_UNITS = 12_000_000
PROJECT_PROFILE_MAX_DIAGNOSTICS = 256
PROJECT_PROFILE_REGEX_DIALECT = "portable_safe_v1"
PROJECT_PROFILE_REGEX_MAX_UTF8_BYTES = 1024
PROJECT_PROFILE_REGEX_MAX_ALTERNATIVES = 32
PROJECT_PROFILE_REGEX_MAX_QUANTIFIERS_PER_BRANCH = 1
PROJECT_PROFILE_REGEX_ALLOWED_ESCAPED_LITERALS = r"\.^$*+?()[]{}|/-"
PROJECT_PROFILE_CONTRACT_ID = "gf.project_layout.profile.v1"
PROJECT_PROFILE_CONTRACT_TOP_LEVEL_FIELDS = frozenset({
	"contract_schema_version",
	"contract_id",
	"profile_schema_versions",
	"domains",
	"semantics",
	"profile_fields",
	"zone_fields",
	"rule_common_fields",
	"rule_compatibility_fields",
	"rule_kinds",
	"reason_codes",
})
PROJECT_PROFILE_CONTRACT_DOMAIN_FIELDS = frozenset({"severity", "naming_target"})
PROJECT_PROFILE_CONTRACT_SEMANTICS_FIELDS = frozenset({
	"regex_match_mode",
	"regex_dialect",
	"regex_max_utf8_bytes",
	"regex_max_alternatives",
	"regex_max_quantifiers_per_branch",
	"regex_ascii_only",
	"regex_allow_groups",
	"regex_allowed_escaped_literals",
	"collection_duplicate_policy",
	"feature_contract_combination",
	"relative_path",
	"extension",
	"glob",
})
PROJECT_PROFILE_CONTRACT_RELATIVE_PATH_SEMANTICS_FIELDS = frozenset({
	"allow_dot_segments",
	"allow_empty_segments",
	"allow_wildcards",
})
PROJECT_PROFILE_CONTRACT_EXTENSION_SEMANTICS_FIELDS = frozenset({
	"trim_whitespace",
	"lowercase",
	"add_missing_leading_dot",
})
PROJECT_PROFILE_CONTRACT_GLOB_SEMANTICS_FIELDS = frozenset({
	"match_entire_path",
	"single_star_crosses_separator",
	"double_star_crosses_separator",
	"double_star_slash_matches_zero_segments",
	"allow_dot_segments",
	"allow_empty_segments",
	"allow_trailing_separator",
	"allow_question_mark",
	"allow_character_classes",
	"allow_triple_star",
})
PROJECT_PROFILE_CONTRACT_FIELD_TYPES = frozenset({
	"bool",
	"enum",
	"exact_integer",
	"extension_list",
	"glob_list",
	"non_empty_string",
	"object",
	"object_array",
	"positive_integer",
	"regex",
	"relative_path_list",
	"string",
})
PROJECT_PROFILE_CONTRACT_DESCRIPTOR_FIELDS = frozenset({
	"type",
	"required",
	"allow_empty",
	"default",
	"domain",
	"requires_capability",
	"empty_semantics",
})
PROJECT_PROFILE_CONTRACT_RULE_RECORD_FIELDS = frozenset({"default_severity", "fields"})
PROJECT_PROFILE_CONTRACT_REQUIRED_REASON_KEYS = frozenset({
	"contract_unavailable",
	"contract_invalid",
	"schema_version_unsupported",
	"required_field_missing",
	"field_unsupported",
	"field_type_invalid",
	"field_value_invalid",
	"duplicate_id",
	"relative_path_invalid",
	"regex_invalid",
	"regex_unsafe",
	"resource_limit",
	"field_not_executed",
	"rule_unsupported_by_executor",
	"registry_invalid",
	"collection_value_duplicate",
	"zone_extension_not_allowed",
	"zone_extension_denied",
})
PROJECT_PROFILE_CONTRACT_CORE_DESCRIPTORS = {
	"profile_fields": {
		"schema_version": ("exact_integer", True),
		"id": ("non_empty_string", True),
		"zones": ("object_array", True),
		"rules": ("object_array", True),
	},
	"zone_fields": {
		"id": ("non_empty_string", True),
		"roots": ("relative_path_list", True),
	},
	"rule_common_fields": {
		"id": ("non_empty_string", True),
		"kind": ("non_empty_string", True),
	},
}
PROJECT_PROFILE_CONTRACT_BOOTSTRAP_REASON_CODES = {
	"contract_unavailable": PROJECT_LAYOUT_PROFILE_CONTRACT_UNAVAILABLE,
	"contract_invalid": PROJECT_LAYOUT_PROFILE_CONTRACT_INVALID,
}
PROJECT_PROFILE_DEFAULT_FILES = (
	"gf_project_profile.json",
	".gf/project_profile.json",
	"project_profile.json",
)
# Legacy mode intentionally keeps its original permissive field/kind tables. Strict-v1
# compiles only from the canonical JSON contract and the executable handler registry.
PROJECT_PROFILE_ALLOWED_FIELDS = {
	"schema_version",
	"id",
	"display_name",
	"description",
	"zones",
	"rules",
	"metadata",
}
PROJECT_PROFILE_ZONE_ALLOWED_FIELDS = {
	"id",
	"description",
	"roots",
	"required",
	"allow_extensions",
	"deny_extensions",
	"exclude",
	"severity",
	"metadata",
}
PROJECT_PROFILE_RULE_ALLOWED_FIELDS = {
	"id",
	"description",
	"kind",
	"paths",
	"any",
	"roots",
	"include",
	"exclude",
	"extensions",
	"pattern",
	"target",
	"allowed_files",
	"feature_id_pattern",
	"required_subdirs",
	"allowed_subdirs",
	"allow_root_files",
	"max_files",
	"severity",
	"metadata",
}
PROJECT_PROFILE_RULE_KINDS = {
	"path_exists",
	"files_under_roots",
	"extension_allowlist",
	"extension_denylist",
	"naming_convention",
	"forbid_root_files",
	"feature_module_contract",
	"generated_boundary",
	"bucket_size",
}
PROJECT_PROFILE_SEVERITIES = {"error", "warning", "info"}
PROJECT_PROFILE_SCAN_EXCLUDED_PREFIXES = (
	".git/",
	".godot/",
	".import/",
	"addons/gut/",
	"ai_analysis/",
	"build/",
)


def trim_text(text: str, max_chars: int) -> str:
	if len(text) <= max_chars:
		return text
	return text[-max_chars:]


def make_boundary_issue(
	kind: str,
	path: str,
	message: str,
	**extra: Any,
) -> dict[str, Any]:
	issue = {
		"kind": kind,
		"path": path,
		"message": message,
	}
	issue.update({key: value for key, value in extra.items() if value not in ("", None)})
	return issue


def count_issue_field(issues: list[dict[str, Any]], field_name: str) -> list[dict[str, Any]]:
	counter: dict[str, int] = {}
	for issue in issues:
		key = str(issue.get(field_name) or "<empty>")
		counter[key] = counter.get(key, 0) + 1
	return [
		{"key": key, "count": count}
		for key, count in sorted(counter.items())
	]


def reject_duplicate_json_object_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
	payload: dict[str, Any] = {}
	for key, value in pairs:
		if key in payload:
			raise ValueError(f"Duplicate JSON object key is not allowed: {key}")
		payload[key] = value
	return payload


def exact_integral_number(value: Any) -> int | None:
	if isinstance(value, bool) or not isinstance(value, (int, float)):
		return None
	if isinstance(value, float) and (not math.isfinite(value) or not value.is_integer()):
		return None
	return int(value)


class ProjectProfileResourceLimitError(RuntimeError):
	"""Internal control flow for a terminal Project Layout resource boundary."""


class ProjectProfileIssueList(list[dict[str, Any]]):
	"""Issue collector that reserves one slot for a terminal limit diagnostic."""

	def __init__(self, values: Any = ()) -> None:
		super().__init__()
		self.extend(values)

	def append(self, value: dict[str, Any]) -> None:
		if len(self) >= PROJECT_PROFILE_MAX_DIAGNOSTICS - 1:
			raise ProjectProfileResourceLimitError("diagnostics")
		super().append(value)

	def extend(self, values: Any) -> None:
		for value in values:
			self.append(value)


def make_project_profile_resource_limit_issue(
	resource: str,
	path: str = "",
) -> dict[str, Any]:
	return make_project_profile_issue(
		"project_profile_resource_limit_exceeded",
		path,
		"Project profile evaluation exceeded a non-configurable resource limit.",
		reason_code=PROJECT_PROFILE_RESOURCE_LIMIT_REASON_CODE,
		resource=resource,
	)


def project_profile_terminal_resource_issues(
	resource: str,
	path: str = "",
) -> list[dict[str, Any]]:
	return [make_project_profile_resource_limit_issue(resource, path)]


def project_profile_terminal_resource_issue(
	issues: list[dict[str, Any]],
) -> dict[str, Any] | None:
	return next(
		(
			issue
			for issue in issues
			if issue.get("reason_code") == PROJECT_PROFILE_RESOURCE_LIMIT_REASON_CODE
		),
		None,
	)


def capture_subprocess_bytes_bounded(
	command: list[str],
	*,
	cwd: Path,
	environment: Mapping[str, str],
	max_stdout_bytes: int,
	max_stderr_bytes: int,
) -> dict[str, Any]:
	deadline = time.perf_counter() + PROJECT_PROFILE_GIT_TIMEOUT_SECONDS
	try:
		process_result = gf_process_supervisor.run_supervised_process_bytes(
			command,
			cwd=cwd,
			timeout_seconds=PROJECT_PROFILE_GIT_TIMEOUT_SECONDS,
			deadline=deadline,
			environment=dict(environment),
			max_stdout_bytes=max_stdout_bytes,
			max_stderr_bytes=max_stderr_bytes,
		)
		process_result = (
			gf_process_supervisor.require_supervised_binary_quiet_boundary(
				process_result,
				deadline=deadline,
			)
		)
	except gf_process_supervisor.SupervisedProcessCleanupError:
		raise
	except TimeoutError:
		return {
			"returncode": -1,
			"stdout": b"",
			"stderr": b"",
			"error_kind": "timeout",
		}
	except OSError:
		return {
			"returncode": -1,
			"stdout": b"",
			"stderr": b"",
			"error_kind": "os_error",
		}
	if process_result.stdout_truncated or process_result.stderr_truncated:
		return {
			"returncode": process_result.return_code,
			"stdout": b"",
			"stderr": b"",
			"error_kind": "resource_limit",
		}
	if process_result.timed_out:
		error_kind = "timeout"
	elif process_result.output_drain_failed:
		error_kind = "process_tree"
	else:
		error_kind = ""
	return {
		"returncode": process_result.return_code,
		"stdout": b"" if error_kind else process_result.stdout,
		"stderr": b"" if error_kind else process_result.stderr,
		"error_kind": error_kind,
	}


def read_git_paths(
	command: list[str],
	*,
	git_process: FrozenGitProcess,
	strict_utf8: bool = False,
) -> dict[str, Any]:
	capture = capture_git_paths(command, git_process=git_process)
	return project_profile_git_paths_from_capture(
		capture,
		strict_utf8=strict_utf8,
	)


def capture_git_paths(
	command: list[str],
	*,
	git_process: FrozenGitProcess,
) -> dict[str, Any]:
	result = capture_subprocess_bytes_bounded(
		list(git_process.command(command).effective),
		cwd=ROOT,
		environment=git_process.environment.values(),
		max_stdout_bytes=PROJECT_PROFILE_GIT_STDOUT_MAX_BYTES,
		max_stderr_bytes=PROJECT_PROFILE_GIT_STDERR_MAX_BYTES,
	)
	error_kind = str(result.get("error_kind", ""))
	if error_kind == "resource_limit":
		return {
			"stdout": b"",
			"error": "Git path inventory exceeded the bounded capture budget.",
			"error_kind": "resource_limit",
		}
	if error_kind:
		return {
			"stdout": b"",
			"error": "git path scan failed.",
			"error_kind": error_kind,
		}
	if int(result["returncode"]) != 0:
		return {
			"stdout": b"",
			"error": "git path scan failed.",
			"error_kind": "command_failed",
		}
	return {"stdout": result["stdout"], "error": "", "error_kind": ""}


def project_profile_git_paths_from_capture(
	capture: dict[str, Any],
	*,
	strict_utf8: bool,
) -> dict[str, Any]:
	if capture["error"]:
		return {
			"paths": [],
			"path_count": 0,
			"utf8_bytes": 0,
			"error": capture["error"],
			"error_kind": capture.get("error_kind", "scan_failed"),
		}
	stdout_bytes = capture["stdout"]
	if len(stdout_bytes) > PROJECT_PROFILE_GIT_STDOUT_MAX_BYTES:
		return {
			"paths": [],
			"path_count": 0,
			"utf8_bytes": 0,
			"error": "Git path inventory exceeded the bounded capture budget.",
			"error_kind": "resource_limit",
		}
	try:
		decoded_stdout = stdout_bytes.decode(
			"utf-8",
			errors="strict" if strict_utf8 else "replace",
		)
	except UnicodeDecodeError:
		return {
			"paths": [],
			"path_count": 0,
			"utf8_bytes": 0,
			"error": "Git path inventory is not valid UTF-8.",
			"error_kind": "invalid_utf8",
		}
	raw_paths: list[str] = []
	path_count = 0
	utf8_bytes = 0
	start_index = 0
	while start_index <= len(decoded_stdout):
		end_index = decoded_stdout.find("\0", start_index)
		if end_index < 0:
			end_index = len(decoded_stdout)
		path = decoded_stdout[start_index:end_index]
		if path:
			path_count += 1
			path_size = len(path.encode("utf-8"))
			if (
				path_count > PROJECT_PROFILE_INVENTORY_MAX_PATHS
				or path_size > PROJECT_PROFILE_INVENTORY_MAX_PATH_BYTES
				or utf8_bytes > PROJECT_PROFILE_INVENTORY_MAX_UTF8_BYTES - path_size
				or project_profile_sort_work_units(path_count)
				> PROJECT_PROFILE_INVENTORY_MAX_SORT_WORK_UNITS
			):
				return {
					"paths": [],
					"path_count": path_count,
					"utf8_bytes": utf8_bytes,
					"error": "Git path inventory exceeded the bounded inventory envelope.",
					"error_kind": "resource_limit",
				}
			utf8_bytes += path_size
			raw_paths.append(path)
		if end_index == len(decoded_stdout):
			break
		start_index = end_index + 1
	if strict_utf8 and any(project_profile_inventory_path_is_invalid(path) for path in raw_paths):
		return {
			"paths": [],
			"path_count": path_count,
			"utf8_bytes": utf8_bytes,
			"error": "Git path inventory contains a non-canonical path.",
			"error_kind": "invalid_path",
		}
	paths = sorted({
		path if strict_utf8 else path.replace("\\", "/")
		for path in raw_paths
	})
	return {
		"paths": paths,
		"path_count": path_count,
		"utf8_bytes": utf8_bytes,
		"error": "",
		"error_kind": "",
	}


def project_profile_sort_work_units(item_count: int) -> int:
	if item_count <= 1:
		return item_count
	return item_count * (item_count - 1).bit_length()


def project_profile_boundary(
	profile_path: str = "",
	fail_on_warnings: bool = False,
	profile_mode: str = "strict",
	*,
	git_process: FrozenGitProcess,
) -> dict[str, Any]:
	if profile_mode not in PROFILE_MODES:
		raise ValueError(f"Unsupported project profile mode: {profile_mode}")
	if profile_mode == "strict":
		payload = _project_profile_boundary_phase1(
			profile_path=profile_path,
			fail_on_warnings=fail_on_warnings,
			strict_v1=True,
			git_process=git_process,
		)
	elif profile_mode == "legacy":
		payload = _project_profile_boundary_phase1(
			profile_path=profile_path,
			fail_on_warnings=fail_on_warnings,
			git_process=git_process,
		)
	else:
		shared_profile_payload = load_project_profile(profile_path)
		inventory_views = (
			collect_project_profile_path_views(git_process=git_process)
			if shared_profile_payload["found"]
			else None
		)
		payload = _project_profile_boundary_phase1(
			profile_path=profile_path,
			fail_on_warnings=fail_on_warnings,
			profile_payload=shared_profile_payload,
			paths_payload=(
				inventory_views["legacy"]
				if inventory_views is not None
				else None
			),
			git_process=git_process,
		)
		shadow_container = _project_profile_boundary_phase1(
			profile_path=profile_path,
			fail_on_warnings=fail_on_warnings,
			strict_v1_shadow=True,
			profile_payload=shared_profile_payload,
			paths_payload=(
				inventory_views["strict"]
				if inventory_views is not None
				else None
			),
			git_process=git_process,
		)
		payload["strict_v1_shadow"] = shadow_container.get("strict_v1_shadow")
	return normalize_project_profile_boundary_payload(payload, profile_mode)


def normalize_project_profile_boundary_payload(
	payload: dict[str, Any],
	profile_mode: str,
) -> dict[str, Any]:
	result = dict(payload)
	legacy_shadow = result.pop("strict_v1_shadow", None)
	deprecated = profile_mode in {"legacy", "shadow"}
	result.update({
		"profile_mode": profile_mode,
		"contract_mode": profile_mode,
		"contract_version": 1,
		"authoritative_profile_mode": (
			"legacy" if profile_mode in {"legacy", "shadow"} else "strict"
		),
		"deprecated": deprecated,
		"removal_version": PROFILE_LEGACY_REMOVAL_VERSION if deprecated else None,
	})
	capabilities = dict(result.get("executor_capabilities", {}))
	if capabilities:
		capabilities.update({
			"mode": result["authoritative_profile_mode"],
			"invocation_mode": profile_mode,
			"deprecated": deprecated,
			"removal_version": (
				PROFILE_LEGACY_REMOVAL_VERSION if deprecated else None
			),
		})
	result["executor_capabilities"] = capabilities
	result["shadow"] = (
		normalize_project_profile_shadow_payload(legacy_shadow)
		if profile_mode == "shadow" and isinstance(legacy_shadow, dict)
		else None
	)
	return result


def normalize_project_profile_shadow_payload(
	payload: dict[str, Any],
) -> dict[str, Any]:
	result = dict(payload)
	result.update({
		"profile_mode": "strict",
		"authoritative": False,
		"migration_only": True,
	})
	capabilities = dict(result.get("executor_capabilities", {}))
	if capabilities:
		capabilities.update({
			"mode": "strict",
			"invocation_mode": "shadow",
			"deprecated": True,
			"removal_version": PROFILE_LEGACY_REMOVAL_VERSION,
		})
	result["executor_capabilities"] = capabilities
	return result


def project_profile_capabilities(
	*,
	profile_mode: str = "strict",
	operation: str = "audit",
) -> dict[str, Any]:
	if profile_mode not in PROFILE_MODES:
		raise ValueError(f"Unsupported project profile mode: {profile_mode}")
	internal_mode = {
		"strict": "strict-v1",
		"legacy": "legacy",
		"shadow": "strict-v1-shadow",
	}[profile_mode]
	capabilities = dict(project_profile_python_capabilities(
		mode=internal_mode,
		operation=operation,
	))
	deprecated = profile_mode in {"legacy", "shadow"}
	capabilities.update({
		"mode": profile_mode,
		"deprecated": deprecated,
		"removal_version": PROFILE_LEGACY_REMOVAL_VERSION if deprecated else None,
	})
	return capabilities


def _project_profile_boundary_phase1(
	profile_path: str = "",
	fail_on_warnings: bool = False,
	strict_v1: bool = False,
	strict_v1_shadow: bool = False,
	profile_payload: dict[str, Any] | None = None,
	paths_payload: dict[str, Any] | None = None,
	*,
	git_process: FrozenGitProcess,
) -> dict[str, Any]:
	if strict_v1 and strict_v1_shadow:
		raise ValueError("strict_v1 and strict_v1_shadow are mutually exclusive")
	if profile_payload is None:
		profile_payload = load_project_profile(profile_path, strict_json=strict_v1)
	issues: list[dict[str, Any]] = list(profile_payload["issues"])
	if not profile_payload["found"]:
		if not strict_v1 and not strict_v1_shadow:
			return make_project_profile_boundary_payload(
				profile_payload,
				[],
				issues,
				fail_on_warnings,
			)
		contract_payload = load_project_profile_contract()
		contract_issues = list(contract_payload.get("issues", []))
		contract_digest = str(contract_payload.get("digest", ""))
		if strict_v1:
			strict_payload = make_project_profile_boundary_payload(
				profile_payload,
				[],
				[*issues, *contract_issues],
				fail_on_warnings,
				strict_v1=True,
				contract_digest=contract_digest,
			)
			strict_payload.update({
				"evaluation_complete": False,
				"evaluation_status": "not_applicable",
				"skip_reason": "profile_not_found",
			})
			return strict_payload
		shadow_payload = make_project_profile_shadow_payload(
			contract_issues,
			contract_digest=contract_digest,
			inventory_available=False,
			profile_found=False,
			evaluation_status="not_applicable",
			skip_reason="profile_not_found",
		)
		return make_project_profile_boundary_payload(
			profile_payload,
			[],
			issues,
			fail_on_warnings,
			strict_v1_shadow=shadow_payload,
		)
	strict_profile_payload = (
		make_strict_project_profile_view(profile_payload)
		if strict_v1_shadow
		else profile_payload
	)
	strict_compilation: dict[str, Any] | None = None
	strict_contract_evaluated = False
	strict_schema_issues: list[dict[str, Any]] = list(strict_profile_payload["issues"])
	contract_digest = ""
	if strict_v1 or strict_v1_shadow:
		if strict_schema_issues:
			contract_payload = load_project_profile_contract()
			contract_digest = str(contract_payload.get("digest", ""))
			strict_schema_issues.extend(contract_payload.get("issues", []))
		else:
			strict_compilation = compile_project_profile_v1(
				strict_profile_payload["data"],
				strict_profile_payload["path"],
			)
			strict_contract_evaluated = bool(
				strict_compilation.get("contract_evaluated", False)
			)
			strict_schema_issues = list(strict_compilation["issues"])
			contract_digest = str(strict_compilation.get("contract_digest", ""))
	strict_schema_has_errors = any(
		issue.get("severity") == "error"
		for issue in strict_schema_issues
	)
	if strict_v1 and strict_schema_has_errors:
		strict_payload = make_project_profile_boundary_payload(
			profile_payload,
			[],
			strict_schema_issues,
			fail_on_warnings,
			strict_v1=True,
			contract_digest=contract_digest,
		)
		strict_payload.update({
			"evaluation_complete": False,
			"evaluation_status": "incomplete",
			"skip_reason": project_profile_evaluation_skip_reason(
				strict_schema_issues,
				contract_evaluated=strict_contract_evaluated,
			),
		})
		return strict_payload
	if strict_v1_shadow and strict_schema_has_errors:
		shadow_payload = make_project_profile_shadow_payload(
			strict_schema_issues,
			contract_digest=contract_digest,
			profile_source_digest=str(strict_profile_payload.get("source_digest", "")),
			inventory_available=False,
			contract_evaluated=strict_contract_evaluated,
		)
		return make_project_profile_boundary_payload(
			profile_payload,
			[],
			issues,
			fail_on_warnings,
			strict_v1_shadow=shadow_payload,
		)
	strict_inventory = strict_v1 or (strict_v1_shadow and not strict_schema_has_errors)
	if paths_payload is None:
		paths_payload = (
			collect_project_profile_paths(
				strict_v1=True,
				git_process=git_process,
			)
			if strict_inventory
			else collect_project_profile_paths(git_process=git_process)
		)
	strict_inventory_issues = list(paths_payload.get("errors", []))
	legacy_inventory_issues = list(
		paths_payload.get("legacy_errors", strict_inventory_issues)
	)
	blocking_inventory_issues = (
		strict_inventory_issues
		if strict_v1 or strict_v1_shadow
		else legacy_inventory_issues
	)
	if blocking_inventory_issues:
		if strict_v1:
			issues = list(strict_schema_issues)
			issues.extend(blocking_inventory_issues)
		elif not strict_v1_shadow:
			issues.extend(blocking_inventory_issues)
		shadow_payload = (
			make_project_profile_shadow_payload(
				strict_schema_issues,
				contract_digest=contract_digest,
				profile_source_digest=str(strict_profile_payload.get("source_digest", "")),
				inventory_available=False,
				inventory_issues=strict_inventory_issues,
				contract_evaluated=strict_contract_evaluated,
			)
			if strict_v1_shadow
			else None
		)
		boundary_payload = make_project_profile_boundary_payload(
			profile_payload,
			[],
			issues,
			fail_on_warnings,
			strict_v1=strict_v1,
			strict_v1_shadow=shadow_payload,
			contract_digest=contract_digest,
		)
		if strict_v1:
			boundary_payload.update({
				"evaluation_complete": False,
				"evaluation_status": "incomplete",
				"skip_reason": "inventory_unavailable",
			})
		return boundary_payload

	repo_paths: list[str] = paths_payload["paths"]
	profile_data: dict[str, Any] = profile_payload["data"]
	if strict_v1:
		issues = audit_compiled_project_profile_data(
			strict_compilation or compile_project_profile_v1(
				strict_profile_payload["data"],
				strict_profile_payload["path"],
			),
			profile_payload["path"],
			repo_paths,
		)
	elif not strict_v1_shadow:
		issues.extend(audit_project_profile_data(
			profile_data,
			profile_payload["path"],
			repo_paths,
		))
	shadow_payload: dict[str, Any] | None = None
	if strict_v1_shadow:
		shadow_runtime_issues: list[dict[str, Any]] | None = None
		if not strict_schema_has_errors and not strict_inventory_issues:
			shadow_runtime_issues = audit_compiled_project_profile_runtime(
				strict_compilation or compile_project_profile_v1(
					strict_profile_payload["data"],
					strict_profile_payload["path"],
				),
				strict_profile_payload["path"],
				repo_paths,
			)
		shadow_payload = make_project_profile_shadow_payload(
			strict_schema_issues,
			shadow_runtime_issues,
			contract_digest=contract_digest,
			profile_source_digest=str(strict_profile_payload.get("source_digest", "")),
			inventory_available=strict_inventory and not strict_inventory_issues,
			inventory_issues=strict_inventory_issues,
			contract_evaluated=strict_contract_evaluated,
		)
	return make_project_profile_boundary_payload(
		profile_payload,
		repo_paths,
		issues,
		fail_on_warnings,
		strict_v1=strict_v1,
		strict_v1_shadow=shadow_payload,
		contract_digest=contract_digest,
	)


def project_profile_evaluation_skip_reason(
	issues: list[dict[str, Any]],
	*,
	contract_evaluated: bool,
) -> str:
	if contract_evaluated:
		return "profile_contract_invalid"
	issue_kinds = {
		str(issue.get("kind", ""))
		for issue in issues
		if isinstance(issue, dict)
	}
	if "project_profile_contract_unavailable" in issue_kinds:
		return "contract_unavailable"
	if "project_profile_contract_invalid" in issue_kinds:
		return "contract_invalid"
	if "project_profile_registry_invalid" in issue_kinds:
		return "executor_registry_invalid"
	return "strict_input_admission_failed"


def make_project_profile_shadow_payload(
	schema_issues: list[dict[str, Any]],
	runtime_issues: list[dict[str, Any]] | None = None,
	*,
	contract_digest: str = "",
	profile_source_digest: str = "",
	inventory_available: bool = False,
	inventory_issues: list[dict[str, Any]] | None = None,
	profile_found: bool = True,
	contract_evaluated: bool = True,
	evaluation_status: str = "",
	skip_reason: str = "",
) -> dict[str, Any]:
	contract_valid: bool | None = (
		not any(issue.get("severity") == "error" for issue in schema_issues)
		if profile_found and contract_evaluated
		else None
	)
	evaluation_complete = (
		contract_valid is True
		and inventory_available
		and runtime_issues is not None
	)
	resolved_evaluation_status = evaluation_status or (
		"complete" if evaluation_complete else "incomplete"
	)
	resolved_skip_reason = skip_reason
	if not resolved_skip_reason and profile_found:
		if contract_valid is not True:
			resolved_skip_reason = project_profile_evaluation_skip_reason(
				schema_issues,
				contract_evaluated=contract_evaluated,
			)
		elif not inventory_available:
			resolved_skip_reason = "inventory_unavailable"
	runtime_ok: bool | None = None
	if evaluation_complete:
		runtime_ok = not any(
			issue.get("severity") == "error"
			for issue in runtime_issues or []
		)
	try:
		bounded_issues = ProjectProfileIssueList(schema_issues)
		bounded_issues.extend(inventory_issues or [])
		if runtime_issues is not None:
			bounded_issues.extend(runtime_issues)
		issues: list[dict[str, Any]] = list(bounded_issues)
	except ProjectProfileResourceLimitError:
		issues = project_profile_terminal_resource_issues("diagnostics")
	terminal_resource_issue = project_profile_terminal_resource_issue(issues)
	if terminal_resource_issue is not None:
		issues = [terminal_resource_issue]
		evaluation_complete = False
		resolved_evaluation_status = "incomplete"
		resolved_skip_reason = "resource_limit"
		runtime_ok = None
		runtime_issues = None
	error_count = sum(1 for issue in issues if issue.get("severity") == "error")
	warning_count = sum(1 for issue in issues if issue.get("severity") == "warning")
	return {
		"ok": contract_valid is True and evaluation_complete and runtime_ok is True,
		"authoritative": False,
		"contract_digest": contract_digest,
		"profile_source_digest": profile_source_digest,
		"contract_valid": contract_valid,
		"inventory_available": inventory_available,
		"evaluation_complete": evaluation_complete,
		"evaluation_status": resolved_evaluation_status,
		"skip_reason": resolved_skip_reason,
		"runtime_ok": runtime_ok,
		"schema_issue_count": len(schema_issues),
		"runtime_issue_count": len(runtime_issues) if runtime_issues is not None else None,
		"executor_capabilities": project_profile_python_capabilities(
			mode="strict-v1-shadow",
			operation="audit",
		),
		"issue_count": len(issues),
		"error_count": error_count,
		"warning_count": warning_count,
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"reason_code_counts": count_project_profile_reason_codes(issues),
		"issues": issues,
	}


def make_project_profile_boundary_payload(
	profile_payload: dict[str, Any],
	repo_paths: list[str],
	issues: list[dict[str, Any]],
	fail_on_warnings: bool,
	strict_v1: bool = False,
	strict_v1_shadow: dict[str, Any] | None = None,
	contract_digest: str = "",
) -> dict[str, Any]:
	terminal_resource_issue = project_profile_terminal_resource_issue(issues)
	if len(issues) >= PROJECT_PROFILE_MAX_DIAGNOSTICS:
		issues = project_profile_terminal_resource_issues(
			"diagnostics",
			str(profile_payload.get("path", "")),
		)
		terminal_resource_issue = issues[0]
	elif terminal_resource_issue is not None:
		issues = [terminal_resource_issue]
	error_count = sum(1 for issue in issues if issue.get("severity") == "error")
	warning_count = sum(1 for issue in issues if issue.get("severity") == "warning")
	info_count = sum(1 for issue in issues if issue.get("severity") == "info")
	payload = {
		"ok": error_count == 0 and (not fail_on_warnings or warning_count == 0),
		"root": str(ROOT),
		"profile_found": profile_payload["found"],
		"profile_path": profile_payload["path"],
		"profile_id": profile_payload["id"],
		"profile_source_digest": str(profile_payload.get("source_digest", "")),
		"file_count": len(repo_paths),
		"issue_count": len(issues),
		"error_count": error_count,
		"warning_count": warning_count,
		"info_count": info_count,
		"issue_kind_counts": count_issue_field(issues, "kind"),
		"reason_code_counts": count_project_profile_reason_codes(issues),
		"severity_counts": count_issue_field(issues, "severity"),
		"contract_mode": "strict-v1" if strict_v1 else "legacy",
		"contract_digest": contract_digest if strict_v1 else "",
		"executor_capabilities": project_profile_python_capabilities(
			mode="strict-v1" if strict_v1 else "legacy",
			operation="audit",
		),
		"strict_v1_shadow": strict_v1_shadow,
		"issues": issues,
	}
	if strict_v1:
		payload.update({
			"evaluation_complete": terminal_resource_issue is None,
			"evaluation_status": (
				"complete" if terminal_resource_issue is None else "incomplete"
			),
			"skip_reason": "" if terminal_resource_issue is None else "resource_limit",
		})
	return payload


def count_project_profile_reason_codes(issues: list[dict[str, Any]]) -> list[dict[str, Any]]:
	return count_issue_field(
		[issue for issue in issues if issue.get("reason_code")],
		"reason_code",
	)

class ProjectProfileBoundedFileTooLargeError(OSError):
	pass


def project_profile_file_stat_token(metadata: os.stat_result) -> tuple[int, int, int, int]:
	return (
		int(getattr(metadata, "st_dev", 0)),
		int(getattr(metadata, "st_ino", 0)),
		int(getattr(metadata, "st_size", 0)),
		int(getattr(metadata, "st_mtime_ns", 0)),
	)


def read_project_profile_bounded_regular_file(
	path: Path,
	max_bytes: int,
) -> bytes:
	metadata = path.lstat()
	if (
		not stat.S_ISREG(metadata.st_mode)
		or stat.S_ISLNK(metadata.st_mode)
		or bool(int(getattr(metadata, "st_file_attributes", 0)) & 0x0400)
	):
		raise OSError("path must be a regular non-linked file")
	if metadata.st_size > max_bytes:
		raise ProjectProfileBoundedFileTooLargeError(
			f"file exceeds the {max_bytes}-byte input budget"
		)
	with path.open("rb") as payload_file:
		opened_metadata = os.fstat(payload_file.fileno())
		if (
			not stat.S_ISREG(opened_metadata.st_mode)
			or bool(int(getattr(opened_metadata, "st_file_attributes", 0)) & 0x0400)
		):
			raise OSError("opened path must be a regular non-linked file")
		if project_profile_file_stat_token(metadata) != project_profile_file_stat_token(
			opened_metadata
		):
			raise OSError("file identity changed before bounded read")
		payload_bytes = payload_file.read(max_bytes + 1)
		if len(payload_bytes) > max_bytes:
			raise ProjectProfileBoundedFileTooLargeError(
				f"file exceeds the {max_bytes}-byte input budget"
			)
		final_metadata = os.fstat(payload_file.fileno())
		if (
			project_profile_file_stat_token(opened_metadata)
			!= project_profile_file_stat_token(final_metadata)
			or final_metadata.st_size != len(payload_bytes)
		):
			raise OSError("file changed during bounded read")
	return payload_bytes


def load_project_profile_contract() -> dict[str, Any]:
	issues: list[dict[str, Any]] = []
	payload_bytes = b""
	digest = ""
	try:
		payload_bytes = read_project_profile_bounded_regular_file(
			PROJECT_LAYOUT_PROFILE_CONTRACT_PATH,
			PROJECT_LAYOUT_PROFILE_CONTRACT_MAX_BYTES,
		)
		digest = hashlib.sha256(payload_bytes).hexdigest()
	except OSError as error:
		issues.append(make_project_profile_issue(
			"project_profile_contract_unavailable",
			PROJECT_LAYOUT_PROFILE_CONTRACT_RELATIVE_PATH,
			"The canonical project profile contract is unavailable.",
			reason_code=PROJECT_LAYOUT_PROFILE_CONTRACT_UNAVAILABLE,
			error=trim_text(str(error), 300),
		))
		return {"ok": False, "data": {}, "digest": digest, "issues": issues}

	try:
		payload_text = payload_bytes.decode("utf-8", errors="strict")
		data = parse_project_profile_strict_json(payload_text)
	except (UnicodeDecodeError, ValueError, RecursionError, OverflowError) as error:
		issues.append(make_project_profile_issue(
			"project_profile_contract_invalid",
			PROJECT_LAYOUT_PROFILE_CONTRACT_RELATIVE_PATH,
			"The canonical project profile contract is not strict JSON.",
			reason_code=PROJECT_LAYOUT_PROFILE_CONTRACT_INVALID,
			error=trim_text(str(error), 300),
		))
		return {"ok": False, "data": {}, "digest": digest, "issues": issues}
	if not project_profile_contract_shape_is_valid(data):
		issues.append(make_project_profile_issue(
			"project_profile_contract_invalid",
			PROJECT_LAYOUT_PROFILE_CONTRACT_RELATIVE_PATH,
			"The canonical project profile contract has an invalid closed shape.",
			reason_code=PROJECT_LAYOUT_PROFILE_CONTRACT_INVALID,
		))
		return {"ok": False, "data": {}, "digest": digest, "issues": issues}
	return {
		"ok": True,
		"data": data,
		"digest": digest,
		"issues": [],
	}


def reject_project_profile_json_constant(value: str) -> Any:
	raise ValueError(f"Non-finite JSON constant is not allowed: {value}")


def parse_project_profile_json_float(value: str) -> float:
	parsed_value = float(value)
	if not math.isfinite(parsed_value):
		raise ValueError("Non-finite JSON number is not allowed.")
	return parsed_value


class ProjectProfileStrictStructureBudgetError(ValueError):
	pass


def parse_project_profile_strict_json(payload_text: str) -> Any:
	project_profile_strict_json_lexical_budget_error(payload_text)
	data = json.loads(
		payload_text,
		object_pairs_hook=reject_duplicate_json_object_keys,
		parse_constant=reject_project_profile_json_constant,
		parse_float=parse_project_profile_json_float,
	)
	model_error = project_profile_strict_json_model_error(data)
	if model_error:
		if model_error in {
			PROJECT_PROFILE_STRICT_DEPTH_ERROR,
			PROJECT_PROFILE_STRICT_NODE_ERROR,
		}:
			raise ProjectProfileStrictStructureBudgetError(model_error)
		raise ValueError(model_error)
	return data


def project_profile_strict_json_lexical_budget_error(payload_text: str) -> None:
	depth = 0
	structure_units = 0
	in_string = False
	escaped = False
	for character in payload_text:
		if in_string:
			if escaped:
				escaped = False
			elif character == "\\":
				escaped = True
			elif character == '"':
				in_string = False
			continue
		if character == '"':
			in_string = True
			continue
		if character in "[{":
			depth += 1
			structure_units += 1
			if depth > PROJECT_PROFILE_STRICT_MAX_DEPTH:
				raise ProjectProfileStrictStructureBudgetError(
					PROJECT_PROFILE_STRICT_DEPTH_ERROR
				)
		elif character in "]}":
			depth = max(depth - 1, 0)
		elif character == ",":
			structure_units += 1
		if structure_units > PROJECT_PROFILE_STRICT_MAX_NODES:
			raise ProjectProfileStrictStructureBudgetError(
				PROJECT_PROFILE_STRICT_NODE_ERROR
			)


def project_profile_strict_json_model_error(value: Any) -> str:
	stack: list[tuple[Any, int]] = [(value, 1)]
	node_count = 0
	while stack:
		current, depth = stack.pop()
		if depth > PROJECT_PROFILE_STRICT_MAX_DEPTH:
			return PROJECT_PROFILE_STRICT_DEPTH_ERROR
		node_count += 1
		if node_count > PROJECT_PROFILE_STRICT_MAX_NODES:
			return PROJECT_PROFILE_STRICT_NODE_ERROR
		if type(current) is float and not math.isfinite(current):
			return "Non-finite JSON number is not allowed."
		if isinstance(current, dict):
			if any(not isinstance(key, str) for key in current):
				return "Project profile JSON object keys must be strings."
			stack.extend((nested, depth + 1) for nested in reversed(list(current.values())))
		elif isinstance(current, list):
			stack.extend((nested, depth + 1) for nested in reversed(current))
	return ""


def project_profile_string_has_unsafe_text_controls(value: str) -> bool:
	return any(
		ord(character) < 0x20
		or 0x7F <= ord(character) <= 0x9F
		or character in {"\u2028", "\u2029"}
		for character in value
	)


def project_profile_contract_shape_is_valid(data: Any) -> bool:
	if not isinstance(data, dict) or set(data) != PROJECT_PROFILE_CONTRACT_TOP_LEVEL_FIELDS:
		return False
	if project_profile_strict_json_model_error(data):
		return False
	if exact_integral_number(data.get("contract_schema_version")) != 1:
		return False
	if data.get("contract_id") != PROJECT_PROFILE_CONTRACT_ID:
		return False
	profile_schema_versions = data.get("profile_schema_versions")
	if (
		not isinstance(profile_schema_versions, list)
		or [exact_integral_number(value) for value in profile_schema_versions] != [1]
	):
		return False
	domains = data.get("domains")
	if not isinstance(domains, dict) or set(domains) != PROJECT_PROFILE_CONTRACT_DOMAIN_FIELDS:
		return False
	if domains.get("severity") != ["error", "warning", "info"]:
		return False
	if domains.get("naming_target") != ["path", "name", "stem"]:
		return False
	semantics = data.get("semantics")
	if not project_profile_contract_semantics_are_valid(semantics):
		return False
	field_maps: list[dict[str, Any]] = []
	for field_name in (
		"profile_fields",
		"zone_fields",
		"rule_common_fields",
		"rule_compatibility_fields",
	):
		field_map = data.get(field_name)
		if not project_profile_contract_field_map_is_valid(field_map, data):
			return False
		field_maps.append(field_map)
	for map_name, required_descriptors in PROJECT_PROFILE_CONTRACT_CORE_DESCRIPTORS.items():
		field_map = data[map_name]
		for field_name, (field_type, required) in required_descriptors.items():
			descriptor = field_map.get(field_name)
			if (
				not isinstance(descriptor, dict)
				or descriptor.get("type") != field_type
				or descriptor.get("required", False) is not required
			):
				return False
	rule_kinds = data.get("rule_kinds")
	if not isinstance(rule_kinds, dict) or not rule_kinds:
		return False
	for rule_kind, rule_record in rule_kinds.items():
		if not isinstance(rule_kind, str) or not rule_kind.strip():
			return False
		if not isinstance(rule_record, dict) or set(rule_record) != PROJECT_PROFILE_CONTRACT_RULE_RECORD_FIELDS:
			return False
		if rule_record.get("default_severity") not in domains["severity"]:
			return False
		if not project_profile_contract_field_map_is_valid(rule_record.get("fields"), data):
			return False
	reason_code_map = data.get("reason_codes")
	if (
		not isinstance(reason_code_map, dict)
		or set(reason_code_map) != PROJECT_PROFILE_CONTRACT_REQUIRED_REASON_KEYS
	):
		return False
	reason_codes = list(reason_code_map.values())
	if (
		any(not isinstance(reason_code, str) or not reason_code.strip() for reason_code in reason_codes)
		or len(reason_codes) != len(set(reason_codes))
	):
		return False
	if any(
		reason_code_map.get(reason_key) != expected_value
		for reason_key, expected_value in PROJECT_PROFILE_CONTRACT_BOOTSTRAP_REASON_CODES.items()
	):
		return False
	if reason_code_map.get("regex_unsafe") != PROJECT_PROFILE_REGEX_UNSAFE_REASON_CODE:
		return False
	if (
		reason_code_map.get("resource_limit")
		!= PROJECT_PROFILE_RESOURCE_LIMIT_REASON_CODE
	):
		return False
	return True


def project_profile_contract_semantics_are_valid(semantics: Any) -> bool:
	if not isinstance(semantics, dict) or set(semantics) != PROJECT_PROFILE_CONTRACT_SEMANTICS_FIELDS:
		return False
	if semantics.get("regex_match_mode") != "search":
		return False
	if semantics.get("regex_dialect") != PROJECT_PROFILE_REGEX_DIALECT:
		return False
	if exact_integral_number(semantics.get("regex_max_utf8_bytes")) != PROJECT_PROFILE_REGEX_MAX_UTF8_BYTES:
		return False
	if exact_integral_number(semantics.get("regex_max_alternatives")) != PROJECT_PROFILE_REGEX_MAX_ALTERNATIVES:
		return False
	if (
		exact_integral_number(semantics.get("regex_max_quantifiers_per_branch"))
		!= PROJECT_PROFILE_REGEX_MAX_QUANTIFIERS_PER_BRANCH
	):
		return False
	if semantics.get("regex_ascii_only") is not True:
		return False
	if semantics.get("regex_allow_groups") is not False:
		return False
	if (
		semantics.get("regex_allowed_escaped_literals")
		!= PROJECT_PROFILE_REGEX_ALLOWED_ESCAPED_LITERALS
	):
		return False
	if semantics.get("collection_duplicate_policy") != "preserve_first_warn":
		return False
	if semantics.get("feature_contract_combination") != "all_match_union_paths":
		return False
	relative_path = semantics.get("relative_path")
	if (
		not isinstance(relative_path, dict)
		or set(relative_path) != PROJECT_PROFILE_CONTRACT_RELATIVE_PATH_SEMANTICS_FIELDS
		or any(type(relative_path.get(field)) is not bool for field in relative_path)
		or any(relative_path.values())
	):
		return False
	extension = semantics.get("extension")
	if (
		not isinstance(extension, dict)
		or set(extension) != PROJECT_PROFILE_CONTRACT_EXTENSION_SEMANTICS_FIELDS
		or any(type(extension.get(field)) is not bool for field in extension)
		or not all(extension.values())
	):
		return False
	glob = semantics.get("glob")
	if not isinstance(glob, dict) or set(glob) != PROJECT_PROFILE_CONTRACT_GLOB_SEMANTICS_FIELDS:
		return False
	return (
		type(glob.get("match_entire_path")) is bool
		and glob["match_entire_path"] is True
		and type(glob.get("single_star_crosses_separator")) is bool
		and glob["single_star_crosses_separator"] is False
		and type(glob.get("double_star_crosses_separator")) is bool
		and glob["double_star_crosses_separator"] is True
		and type(glob.get("double_star_slash_matches_zero_segments")) is bool
		and glob["double_star_slash_matches_zero_segments"] is True
		and type(glob.get("allow_dot_segments")) is bool
		and glob["allow_dot_segments"] is False
		and type(glob.get("allow_empty_segments")) is bool
		and glob["allow_empty_segments"] is False
		and type(glob.get("allow_trailing_separator")) is bool
		and glob["allow_trailing_separator"] is False
		and type(glob.get("allow_question_mark")) is bool
		and glob["allow_question_mark"] is False
		and type(glob.get("allow_character_classes")) is bool
		and glob["allow_character_classes"] is False
		and type(glob.get("allow_triple_star")) is bool
		and glob["allow_triple_star"] is False
	)


def project_profile_portable_regex_error(
	pattern: str,
	contract: dict[str, Any] | None = None,
) -> str:
	semantics = (
		contract.get("semantics", {})
		if isinstance(contract, dict)
		else {}
	)
	max_bytes = exact_integral_number(semantics.get("regex_max_utf8_bytes"))
	max_alternatives = exact_integral_number(semantics.get("regex_max_alternatives"))
	max_quantifiers = exact_integral_number(
		semantics.get("regex_max_quantifiers_per_branch")
	)
	allowed_escapes = semantics.get("regex_allowed_escaped_literals")
	if max_bytes is None:
		max_bytes = PROJECT_PROFILE_REGEX_MAX_UTF8_BYTES
	if max_alternatives is None:
		max_alternatives = PROJECT_PROFILE_REGEX_MAX_ALTERNATIVES
	if max_quantifiers is None:
		max_quantifiers = PROJECT_PROFILE_REGEX_MAX_QUANTIFIERS_PER_BRANCH
	if not isinstance(allowed_escapes, str):
		allowed_escapes = PROJECT_PROFILE_REGEX_ALLOWED_ESCAPED_LITERALS
	if len(pattern.encode("utf-8")) > max_bytes:
		return "pattern_bytes"
	if any(ord(character) < 0x20 or ord(character) > 0x7E for character in pattern):
		return "ascii_only"
	if not pattern:
		return "empty_branch"

	branch_count = 1
	branch_has_syntax = False
	branch_at_start = True
	branch_is_start_anchored = False
	can_quantify = False
	quantifier_count = 0
	index = 0
	while index < len(pattern):
		character = pattern[index]
		if character == "\\":
			if index + 1 >= len(pattern) or pattern[index + 1] not in allowed_escapes:
				return "escape"
			branch_has_syntax = True
			branch_at_start = False
			can_quantify = True
			index += 2
			continue
		if character in "()":
			return "group"
		if character == "[":
			class_end, class_error = project_profile_portable_regex_class_end(
				pattern,
				index,
				allowed_escapes,
			)
			if class_error:
				return class_error
			branch_has_syntax = True
			branch_at_start = False
			can_quantify = True
			index = class_end
			continue
		if character == "]":
			return "character_class"
		if character == "|":
			if not branch_has_syntax:
				return "empty_branch"
			branch_count += 1
			if branch_count > max_alternatives:
				return "alternatives"
			branch_has_syntax = False
			branch_at_start = True
			branch_is_start_anchored = False
			can_quantify = False
			quantifier_count = 0
			index += 1
			continue
		if character in "*+?":
			if not can_quantify:
				return "quantifier"
			if not branch_is_start_anchored:
				return "unanchored_quantifier"
			quantifier_count += 1
			if quantifier_count > max_quantifiers:
				return "quantifiers"
			can_quantify = False
			branch_at_start = False
			index += 1
			continue
		if character in "{}":
			return "quantifier"
		if character == "^":
			if not branch_at_start:
				return "anchor"
			branch_is_start_anchored = True
			branch_has_syntax = True
			branch_at_start = False
			can_quantify = False
			index += 1
			continue
		if character == "$":
			if index + 1 < len(pattern) and pattern[index + 1] != "|":
				return "anchor"
			branch_has_syntax = True
			branch_at_start = False
			can_quantify = False
			index += 1
			continue
		branch_has_syntax = True
		branch_at_start = False
		can_quantify = True
		index += 1
	if not branch_has_syntax:
		return "empty_branch"
	return ""


def project_profile_portable_regex_class_end(
	pattern: str,
	start_index: int,
	allowed_escapes: str,
) -> tuple[int, str]:
	tokens: list[str] = []
	index = start_index + 1
	if index < len(pattern) and pattern[index] == "^":
		index += 1
	while index < len(pattern):
		character = pattern[index]
		if character == "]":
			if not tokens:
				return index + 1, "character_class"
			for operator in ("&&", "--", "~~", "||"):
				if operator in "".join(tokens):
					return index + 1, "character_class"
			for token_index, token in enumerate(tokens):
				if token != "-" or token_index in {0, len(tokens) - 1}:
					continue
				left = tokens[token_index - 1]
				right = tokens[token_index + 1]
				if not (
					len(left) == 1
					and len(right) == 1
					and (
						left.isdigit() and right.isdigit()
						or left.islower() and right.islower()
						or left.isupper() and right.isupper()
					)
					and ord(left) <= ord(right)
				):
					return index + 1, "character_class"
			return index + 1, ""
		if character == "[":
			return index + 1, "character_class"
		if character == "\\":
			if index + 1 >= len(pattern) or pattern[index + 1] not in allowed_escapes:
				return index + 1, "escape"
			tokens.append(pattern[index + 1])
			index += 2
			continue
		tokens.append(character)
		index += 1
	return index, "syntax"


def project_profile_contract_field_map_is_valid(field_map: Any, contract: dict[str, Any]) -> bool:
	if not isinstance(field_map, dict):
		return False
	for field_name, descriptor in field_map.items():
		if not isinstance(field_name, str) or not field_name.strip():
			return False
		if not project_profile_contract_descriptor_is_valid(descriptor, contract):
			return False
	return True


def project_profile_contract_descriptor_is_valid(descriptor: Any, contract: dict[str, Any]) -> bool:
	if not isinstance(descriptor, dict) or not set(descriptor).issubset(
		PROJECT_PROFILE_CONTRACT_DESCRIPTOR_FIELDS
	):
		return False
	field_type = descriptor.get("type")
	if field_type not in PROJECT_PROFILE_CONTRACT_FIELD_TYPES:
		return False
	for bool_field in ("required", "allow_empty", "requires_capability"):
		if bool_field in descriptor and type(descriptor[bool_field]) is not bool:
			return False
	if "allow_empty" in descriptor and not str(field_type).endswith("_list"):
		return False
	domain_name = descriptor.get("domain")
	if field_type == "enum":
		if not isinstance(domain_name, str) or domain_name not in contract["domains"]:
			return False
	elif "domain" in descriptor:
		return False
	if "empty_semantics" in descriptor:
		if not str(field_type).endswith("_list") or descriptor["empty_semantics"] != "deny_all":
			return False
	if "default" in descriptor and not project_profile_contract_default_is_valid(
		descriptor["default"],
		descriptor,
		contract,
	):
		return False
	return True


def project_profile_contract_default_is_valid(
	value: Any,
	descriptor: dict[str, Any],
	contract: dict[str, Any],
) -> bool:
	field_type = descriptor["type"]
	if field_type == "string":
		return isinstance(value, str)
	if field_type == "non_empty_string":
		return isinstance(value, str) and bool(value.strip())
	if field_type == "bool":
		return type(value) is bool
	if field_type == "exact_integer":
		return exact_integral_number(value) is not None
	if field_type == "positive_integer":
		integer_value = exact_integral_number(value)
		return integer_value is not None and integer_value > 0
	if field_type == "enum":
		return isinstance(value, str) and value in contract["domains"][descriptor["domain"]]
	if field_type == "object":
		return isinstance(value, dict)
	if field_type == "object_array":
		return isinstance(value, list)
	if field_type == "regex":
		if (
			not isinstance(value, str)
			or not value.strip()
			or project_profile_portable_regex_error(value, contract)
		):
			return False
		try:
			re.compile(value)
		except (re.error, OverflowError):
			return False
		return True
	if field_type in {"relative_path_list", "glob_list", "extension_list"}:
		if (
			not isinstance(value, list)
			or (not value and not descriptor.get("allow_empty", False))
			or any(not isinstance(item, str) or not item.strip() for item in value)
		):
			return False
		canonical_values = [
			normalize_project_profile_contract_extension(item, contract)
			if field_type == "extension_list"
			else item
			for item in value
		]
		if len(canonical_values) != len(set(canonical_values)):
			return False
		if field_type == "relative_path_list":
			return not any(
				project_profile_contract_relative_path_is_invalid(item)
				for item in canonical_values
			)
		if field_type == "glob_list":
			return not any(
				project_profile_contract_glob_is_invalid(item)
				for item in canonical_values
			)
		return True
	return False


def project_profile_contract_reason_code(contract: dict[str, Any], key: str) -> str:
	reason_codes = contract.get("reason_codes", {})
	value = reason_codes.get(key, "") if isinstance(reason_codes, dict) else ""
	return value if isinstance(value, str) else ""


def compile_project_profile_v1(data: dict[str, Any], profile_path: str) -> dict[str, Any]:
	try:
		return _compile_project_profile_v1(data, profile_path)
	except ProjectProfileResourceLimitError as error:
		return {
			"ok": False,
			"data": {},
			"contract": {},
			"contract_evaluated": False,
			"contract_digest": "",
			"issues": project_profile_terminal_resource_issues(
				str(error) or "diagnostics",
				profile_path,
			),
		}


def _compile_project_profile_v1(data: dict[str, Any], profile_path: str) -> dict[str, Any]:
	contract_payload = load_project_profile_contract()
	issues: ProjectProfileIssueList = ProjectProfileIssueList(contract_payload["issues"])
	if issues:
		return {
			"ok": False,
			"data": {},
			"contract": {},
			"contract_evaluated": False,
			"contract_digest": str(contract_payload.get("digest", "")),
			"issues": issues,
		}
	contract: dict[str, Any] = contract_payload["data"]
	model_error = project_profile_strict_json_model_error(data)
	if model_error:
		issue_kind = (
			"project_profile_strict_structure_budget_exceeded"
			if model_error in {
				PROJECT_PROFILE_STRICT_DEPTH_ERROR,
				PROJECT_PROFILE_STRICT_NODE_ERROR,
			}
			else "project_profile_strict_admission_failed"
		)
		issues.append(make_project_profile_issue(
			issue_kind,
			profile_path,
			"Project profile data exceeds the Python strict input envelope.",
			error=model_error,
		))
		return {
			"ok": False,
			"data": {},
			"contract": contract,
			"contract_evaluated": False,
			"contract_digest": contract_payload["digest"],
			"issues": issues,
		}
	audit_operation = project_profile_operation_registry(mode="strict-v1")["audit"]
	registry = audit_operation["rules"]
	contract_rule_kinds = set(contract["rule_kinds"])
	registry_valid = set(registry) == contract_rule_kinds
	if registry_valid:
		for rule_kind, entry in registry.items():
			allowed_fields = set(contract["rule_common_fields"])
			allowed_fields.update(contract["rule_compatibility_fields"])
			allowed_fields.update(contract["rule_kinds"][rule_kind]["fields"])
			if not set(entry.get("executed_fields", ())).issubset(allowed_fields):
				registry_valid = False
				break
	if not set(audit_operation["zone"]["executed_fields"]).issubset(
		set(contract["zone_fields"])
	):
		registry_valid = False
	if not registry_valid:
		issues.append(make_project_profile_issue(
			"project_profile_registry_invalid",
			profile_path,
			"The Python project profile handler registry does not match the canonical contract.",
			reason_code=project_profile_contract_reason_code(contract, "registry_invalid"),
			expected_value=", ".join(sorted(contract_rule_kinds)),
			actual_value=", ".join(sorted(registry)),
		))
		return {
			"ok": False,
			"data": {},
			"contract": contract,
			"contract_evaluated": False,
			"contract_digest": contract_payload["digest"],
			"issues": issues,
		}

	normalized_profile = validate_project_profile_contract_scope(
		data,
		contract["profile_fields"],
		profile_path,
		"profile",
		contract,
		issues,
	)
	schema_version = exact_integral_number(data.get("schema_version"))
	supported_versions = {
		exact_integral_number(value)
		for value in contract["profile_schema_versions"]
	}
	if schema_version is not None and schema_version not in supported_versions:
		issues.append(make_project_profile_issue(
			"invalid_project_profile_schema_version",
			profile_path,
			"Project profile schema_version is not supported by the canonical v1 contract.",
			field="schema_version",
			reason_code=project_profile_contract_reason_code(contract, "schema_version_unsupported"),
			actual_value=schema_version,
			expected_value=", ".join(str(value) for value in sorted(supported_versions) if value is not None),
		))

	normalized_zones: list[dict[str, Any]] = []
	seen_zone_ids: set[str] = set()
	zone_values = data.get("zones", [])
	if isinstance(zone_values, list):
		for index, zone_value in enumerate(zone_values):
			if not isinstance(zone_value, dict):
				issues.append(project_profile_contract_field_issue(
					profile_path,
					"zones",
					"zone",
					contract,
					"field_type_invalid",
					row_index=index,
				))
				continue
			normalized_zone = validate_project_profile_contract_scope(
				zone_value,
				contract["zone_fields"],
				profile_path,
				"zone",
				contract,
				issues,
				row_index=index,
			)
			zone_id = normalized_zone.get("id", "")
			if isinstance(zone_id, str) and zone_id:
				if zone_id in seen_zone_ids:
					issues.append(make_project_profile_issue(
						"duplicate_project_profile_id",
						profile_path,
						"Project profile zone ids must be unique.",
						field="id",
						zone_id=zone_id,
						row_index=index,
						reason_code=project_profile_contract_reason_code(contract, "duplicate_id"),
					))
				seen_zone_ids.add(zone_id)
			normalized_zones.append(normalized_zone)
	normalized_profile["zones"] = normalized_zones

	normalized_rules: list[dict[str, Any]] = []
	seen_rule_ids: set[str] = set()
	rule_values = data.get("rules", [])
	if isinstance(rule_values, list):
		for index, rule_value in enumerate(rule_values):
			if not isinstance(rule_value, dict):
				issues.append(project_profile_contract_field_issue(
					profile_path,
					"rules",
					"rule",
					contract,
					"field_type_invalid",
					row_index=index,
				))
				continue
			rule_kind_value = rule_value.get("kind")
			rule_kind = rule_kind_value if isinstance(rule_kind_value, str) else ""
			kind_record = contract["rule_kinds"].get(rule_kind)
			field_definitions = dict(contract["rule_common_fields"])
			field_definitions.update(contract["rule_compatibility_fields"])
			if isinstance(kind_record, dict):
				field_definitions.update(kind_record["fields"])
			normalized_rule = validate_project_profile_contract_scope(
				rule_value,
				field_definitions,
				profile_path,
				"rule",
				contract,
				issues,
				row_index=index,
			)
			rule_id = normalized_rule.get("id", "")
			if isinstance(rule_id, str) and rule_id:
				if rule_id in seen_rule_ids:
					issues.append(make_project_profile_issue(
						"duplicate_project_profile_id",
						profile_path,
						"Project profile rule ids must be unique.",
						field="id",
						rule_id=rule_id,
						row_index=index,
						reason_code=project_profile_contract_reason_code(contract, "duplicate_id"),
					))
				seen_rule_ids.add(rule_id)
			if not isinstance(kind_record, dict):
				issues.append(make_project_profile_issue(
					"unsupported_project_profile_rule_kind",
					profile_path,
					"Project profile rule kind is not defined by the canonical contract.",
					field="kind",
					rule_id=rule_id,
					row_index=index,
					reason_code=project_profile_contract_reason_code(contract, "field_value_invalid"),
					actual_value=rule_kind,
				))
				normalized_rules.append(normalized_rule)
				continue
			if "severity" not in normalized_rule:
				normalized_rule["severity"] = kind_record["default_severity"]
			executed_fields = registry[rule_kind]["executed_fields"]
			for field_name, descriptor in contract["rule_compatibility_fields"].items():
				if field_name not in rule_value or not descriptor.get("requires_capability", False):
					continue
				if field_name in executed_fields:
					continue
				issues.append(make_project_profile_issue(
					"project_profile_field_not_executed",
					profile_path,
					"The schema-v1 compatibility field is accepted but not executed by this Python rule handler.",
					severity="warning",
					field=field_name,
					rule_id=rule_id,
					row_index=index,
					reason_code=project_profile_contract_reason_code(contract, "field_not_executed"),
				))
				normalized_rule.pop(field_name, None)
			normalized_rules.append(normalized_rule)
	normalized_profile["rules"] = normalized_rules
	error_count = sum(1 for issue in issues if issue.get("severity") == "error")
	return {
		"ok": error_count == 0,
		"data": normalized_profile,
		"contract": contract,
		"contract_evaluated": True,
		"contract_digest": contract_payload["digest"],
		"issues": issues,
	}


def validate_project_profile_contract_scope(
	data: dict[str, Any],
	field_definitions: dict[str, Any],
	profile_path: str,
	scope: str,
	contract: dict[str, Any],
	issues: list[dict[str, Any]],
	row_index: int = -1,
) -> dict[str, Any]:
	normalized: dict[str, Any] = {}
	for field_name in sorted(data):
		if field_name in field_definitions:
			continue
		kind = {
			"profile": "unsupported_project_profile_field",
			"zone": "unsupported_project_profile_zone_field",
			"rule": "unsupported_project_profile_rule_field",
		}.get(scope, "unsupported_project_profile_field")
		issues.append(make_project_profile_issue(
			kind,
			profile_path,
			"Project profile fields are scoped by the canonical v1 contract.",
			field=field_name,
			row_index=row_index,
			reason_code=project_profile_contract_reason_code(contract, "field_unsupported"),
		))
	for field_name, descriptor in field_definitions.items():
		if field_name not in data:
			if descriptor.get("required", False):
				issues.append(project_profile_contract_field_issue(
					profile_path,
					field_name,
					scope,
					contract,
					"required_field_missing",
					row_index=row_index,
				))
			elif "default" in descriptor:
				normalized[field_name] = descriptor["default"]
			continue
		valid, normalized_value, field_issues = validate_project_profile_contract_value(
			data[field_name],
			descriptor,
			profile_path,
			field_name,
			scope,
			contract,
			row_index,
		)
		issues.extend(field_issues)
		if valid:
			normalized[field_name] = normalized_value
	return normalized


def validate_project_profile_contract_value(
	value: Any,
	descriptor: dict[str, Any],
	profile_path: str,
	field_name: str,
	scope: str,
	contract: dict[str, Any],
	row_index: int,
) -> tuple[bool, Any, list[dict[str, Any]]]:
	field_type = descriptor["type"]
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	invalid_reason = "field_type_invalid"
	if field_type == "string":
		valid = isinstance(value, str)
		normalized_value = value if valid else ""
	elif field_type == "non_empty_string":
		is_string = isinstance(value, str)
		valid = is_string and bool(value.strip())
		if is_string and not valid:
			invalid_reason = "field_value_invalid"
		normalized_value = value if valid else ""
	elif field_type == "bool":
		valid = type(value) is bool
		normalized_value = value if valid else False
	elif field_type in {"exact_integer", "positive_integer"}:
		integer_value = exact_integral_number(value)
		valid = integer_value is not None
		if valid and field_type == "positive_integer" and integer_value <= 0:
			valid = False
			invalid_reason = "field_value_invalid"
		normalized_value = integer_value if valid else 0
	elif field_type == "object":
		valid = isinstance(value, dict)
		normalized_value = dict(value) if valid else {}
	elif field_type == "object_array":
		valid = isinstance(value, list)
		normalized_value = list(value) if valid else []
	elif field_type == "enum":
		domain_values = contract["domains"][descriptor["domain"]]
		is_string = isinstance(value, str)
		valid = is_string and value in domain_values
		if is_string and not valid:
			invalid_reason = "field_value_invalid"
		normalized_value = value if valid else ""
	elif field_type in {"relative_path_list", "glob_list", "extension_list"}:
		valid, normalized_value, list_issues = validate_project_profile_contract_string_list(
			value,
			descriptor,
			profile_path,
			field_name,
			scope,
			contract,
			row_index,
		)
		issues.extend(list_issues)
		return valid, normalized_value, issues
	elif field_type == "regex":
		is_string = isinstance(value, str)
		valid = is_string and bool(value.strip())
		if is_string and not valid:
			invalid_reason = "field_value_invalid"
		normalized_value = value if valid else ""
		if valid:
			portable_error = project_profile_portable_regex_error(value, contract)
			if portable_error and portable_error != "syntax":
				issues.append(make_project_profile_issue(
					"project_profile_regex_unsafe",
					profile_path,
					"Project profile regex is outside the portable safe subset.",
					field=field_name,
					row_index=row_index,
					reason_code=project_profile_contract_reason_code(
						contract,
						"regex_unsafe",
					),
					portable_reason=portable_error,
				))
				return False, "", issues
			try:
				re.compile(value)
			except (re.error, OverflowError) as error:
				issues.append(make_project_profile_issue(
					"project_profile_regex_invalid",
					profile_path,
					"Project profile regex pattern is invalid.",
					field=field_name,
					row_index=row_index,
					reason_code=project_profile_contract_reason_code(contract, "regex_invalid"),
					actual_value=value,
					error_type=type(error).__name__,
					error=str(error),
				))
				return False, "", issues
	else:
		valid = False
		normalized_value = None
	if not valid:
		issues.append(project_profile_contract_field_issue(
			profile_path,
			field_name,
			scope,
			contract,
			invalid_reason,
			row_index=row_index,
		))
	return valid, normalized_value, issues


def normalize_project_profile_contract_extension(
	value: str,
	contract: dict[str, Any],
) -> str:
	extension_semantics = contract["semantics"]["extension"]
	normalized_value = value
	if extension_semantics["trim_whitespace"]:
		normalized_value = normalized_value.strip()
	if extension_semantics["lowercase"]:
		normalized_value = normalized_value.lower()
	if (
		extension_semantics["add_missing_leading_dot"]
		and not normalized_value.startswith(".")
	):
		normalized_value = "." + normalized_value
	return normalized_value


def validate_project_profile_contract_string_list(
	value: Any,
	descriptor: dict[str, Any],
	profile_path: str,
	field_name: str,
	scope: str,
	contract: dict[str, Any],
	row_index: int,
) -> tuple[bool, list[str], list[dict[str, Any]]]:
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	if not isinstance(value, list):
		return False, [], [project_profile_contract_field_issue(
			profile_path,
			field_name,
			scope,
			contract,
			"field_type_invalid",
			row_index=row_index,
		)]
	if not descriptor.get("allow_empty", False) and not value:
		return False, [], [project_profile_contract_field_issue(
			profile_path,
			field_name,
			scope,
			contract,
			"field_value_invalid",
			row_index=row_index,
		)]
	normalized: list[str] = []
	seen: set[str] = set()
	for item in value:
		if not isinstance(item, str):
			issues.append(project_profile_contract_field_issue(
				profile_path,
				field_name,
				scope,
				contract,
				"field_type_invalid",
				row_index=row_index,
			))
			continue
		if not item.strip():
			issues.append(project_profile_contract_field_issue(
				profile_path,
				field_name,
				scope,
				contract,
				"field_value_invalid",
				row_index=row_index,
			))
			continue
		field_type = descriptor["type"]
		normalized_item = item
		if field_type == "relative_path_list" and project_profile_contract_relative_path_is_invalid(item):
			issues.append(project_profile_contract_field_issue(
				profile_path,
				field_name,
				scope,
				contract,
				"relative_path_invalid",
				row_index=row_index,
				actual_value=item,
			))
			continue
		if field_type == "glob_list" and project_profile_contract_glob_is_invalid(item):
			issues.append(project_profile_contract_field_issue(
				profile_path,
				field_name,
				scope,
				contract,
				"relative_path_invalid",
				row_index=row_index,
				actual_value=item,
			))
			continue
		if field_type == "extension_list":
			normalized_item = normalize_project_profile_contract_extension(item, contract)
		if normalized_item in seen:
			issues.append(make_project_profile_issue(
				"duplicate_project_profile_collection_value",
				profile_path,
				"Project profile collection values use preserve-first normalization.",
				severity="warning",
				field=field_name,
				scope=scope,
				row_index=row_index,
				reason_code=project_profile_contract_reason_code(
					contract,
					"collection_value_duplicate",
				),
				actual_value=item,
			))
			continue
		seen.add(normalized_item)
		normalized.append(normalized_item)
	return not any(issue.get("severity") == "error" for issue in issues), normalized, issues


def project_profile_contract_relative_path_is_invalid(path: str) -> bool:
	if (
		not path
		or path != path.strip()
		or "\\" in path
		or path.endswith("/")
		or path == "."
		or path.startswith("./")
		or "//" in path
		or any(character in path for character in "*?[]")
	):
		return True
	if path.startswith("/") or "://" in path or ":" in path:
		return True
	return any(part in {"", ".", ".."} for part in path.split("/"))


def project_profile_contract_glob_is_invalid(pattern: str) -> bool:
	if (
		not pattern
		or pattern != pattern.strip()
		or "\\" in pattern
		or pattern.endswith("/")
		or pattern == "."
		or pattern.startswith("./")
		or "//" in pattern
		or any(character in pattern for character in "?[]")
		or "***" in pattern
	):
		return True
	if pattern.startswith("/") or "://" in pattern or ":" in pattern:
		return True
	return any(part in {"", ".", ".."} for part in pattern.split("/"))


def project_profile_contract_field_issue(
	profile_path: str,
	field_name: str,
	scope: str,
	contract: dict[str, Any],
	reason_key: str,
	row_index: int = -1,
	actual_value: Any = None,
) -> dict[str, Any]:
	kind_by_reason = {
		"required_field_missing": "invalid_project_profile_required_field",
		"field_type_invalid": "invalid_project_profile_field_type",
		"field_value_invalid": "invalid_project_profile_field_value",
		"relative_path_invalid": "invalid_project_profile_relative_path",
	}
	extra: dict[str, Any] = {
		"field": field_name,
		"scope": scope,
		"reason_code": project_profile_contract_reason_code(contract, reason_key),
	}
	if row_index >= 0:
		extra["row_index"] = row_index
	if actual_value is not None:
		extra["actual_value"] = actual_value
	return make_project_profile_issue(
		kind_by_reason.get(reason_key, "invalid_project_profile_field_value"),
		profile_path,
		"Project profile field does not satisfy the canonical v1 contract.",
		**extra,
	)


def load_project_profile(
	profile_path: str = "",
	strict_json: bool = False,
) -> dict[str, Any]:
	source = read_project_profile_source(
		profile_path,
		max_bytes=PROJECT_PROFILE_STRICT_MAX_BYTES,
	)
	return parse_project_profile_source(
		source,
		strict_json=strict_json,
	)


def read_project_profile_source(
	profile_path: str = "",
	*,
	max_bytes: int | None = None,
) -> dict[str, Any]:
	resolved_path = resolve_project_profile_path(profile_path)
	issues: list[dict[str, Any]] = []
	source: dict[str, Any] = {
		"found": resolved_path != "",
		"path": resolved_path,
		"source_digest": "",
		"source_size": 0,
		"_source_text": "",
		"issues": issues,
	}
	if not resolved_path:
		return source

	profile_file = ROOT / resolved_path
	try:
		source_bytes = (
			read_project_profile_bounded_regular_file(profile_file, max_bytes)
			if max_bytes is not None
			else profile_file.read_bytes()
		)
		profile_text = source_bytes.decode("utf-8")
	except ProjectProfileBoundedFileTooLargeError:
		issues.append(make_project_profile_issue(
			"invalid_project_profile_json",
			resolved_path,
			"Project profile exceeds the bounded input budget.",
			expected_value=f"at most {max_bytes} bytes",
		))
		return source
	except (OSError, UnicodeDecodeError) as error:
		issues.append(make_project_profile_issue(
			"invalid_project_profile_json",
			resolved_path,
			"Project profile must be a readable UTF-8 JSON object.",
			error=trim_text(str(error), 300),
		))
		return source
	source["source_digest"] = hashlib.sha256(source_bytes).hexdigest()
	source["source_size"] = len(source_bytes)
	source["_source_text"] = profile_text
	return source


def parse_project_profile_source(
	source: dict[str, Any],
	*,
	strict_json: bool,
) -> dict[str, Any]:
	issues: list[dict[str, Any]] = list(source.get("issues", []))
	payload: dict[str, Any] = {
		"found": bool(source.get("found", False)),
		"path": str(source.get("path", "")),
		"id": "",
		"data": {},
		"source_digest": str(source.get("source_digest", "")),
		"source_size": int(source.get("source_size", 0)),
		"_source_text": str(source.get("_source_text", "")),
		"issues": issues,
	}
	if not payload["found"] or issues:
		return payload
	if strict_json and payload["source_size"] > PROJECT_PROFILE_STRICT_MAX_BYTES:
		issues.append(make_project_profile_issue(
			"invalid_project_profile_json",
			payload["path"],
			"Project profile exceeds the bounded input budget.",
			expected_value=f"at most {PROJECT_PROFILE_STRICT_MAX_BYTES} bytes",
			actual_value=payload["source_size"],
		))
		return payload
	try:
		if strict_json:
			data = parse_project_profile_strict_json(payload["_source_text"])
		else:
			data = json.loads(payload["_source_text"])
	except (ValueError, RecursionError, OverflowError) as error:
		error_text = trim_text(str(error), 300)
		issue_kind = (
			"project_profile_strict_structure_budget_exceeded"
			if strict_json
			and isinstance(error, ProjectProfileStrictStructureBudgetError)
			else "invalid_project_profile_json"
		)
		issues.append(make_project_profile_issue(
			issue_kind,
			payload["path"],
			"Project profile must be a readable UTF-8 JSON object.",
			error=error_text,
		))
		return payload
	if not isinstance(data, dict):
		issues.append(make_project_profile_issue(
			"invalid_project_profile",
			payload["path"],
			"Project profile root must be a JSON object.",
			expected_value="object",
			actual_value=type(data).__name__,
		))
		return payload

	payload["data"] = data
	payload["id"] = (
		project_profile_raw_string(data, "id")
		if strict_json
		else project_profile_string(data, "id")
	)
	return payload


def make_strict_project_profile_view(profile_payload: dict[str, Any]) -> dict[str, Any]:
	if "_source_text" not in profile_payload:
		return {
			"found": bool(profile_payload.get("found", False)),
			"path": str(profile_payload.get("path", "")),
			"id": str(profile_payload.get("id", "")),
			"data": profile_payload.get("data", {}),
			"source_digest": str(profile_payload.get("source_digest", "")),
			"issues": list(profile_payload.get("issues", [])),
		}
	return parse_project_profile_source(profile_payload, strict_json=True)


def resolve_project_profile_path(profile_path: str = "") -> str:
	if profile_path.strip():
		return normalize_project_profile_path(profile_path)
	for candidate in PROJECT_PROFILE_DEFAULT_FILES:
		path = ROOT / candidate
		if path.is_file():
			return candidate
	return ""


def normalize_project_profile_path(path: str) -> str:
	normalized_path = path.strip().replace("\\", "/")
	if normalized_path.startswith("res://"):
		normalized_path = normalized_path.removeprefix("res://")
	if os.path.isabs(normalized_path):
		try:
			return Path(normalized_path).resolve().relative_to(ROOT).as_posix()
		except ValueError:
			return normalized_path
	normalized_path = normalized_path.removeprefix("./")
	return normalized_path


def collect_project_profile_paths(
	strict_v1: bool = False,
	*,
	git_process: FrozenGitProcess,
) -> dict[str, Any]:
	views = collect_project_profile_path_views(git_process=git_process)
	return views["strict" if strict_v1 else "legacy"]


def collect_project_profile_path_views(
	*,
	git_process: FrozenGitProcess,
) -> dict[str, dict[str, Any]]:
	tracked_capture = capture_git_paths(
		["ls-files", "-z", "--cached"],
		git_process=git_process,
	)
	untracked_capture = capture_git_paths(
		["ls-files", "-z", "--others", "--exclude-standard"],
		git_process=git_process,
	)
	legacy_payload = make_project_profile_paths_payload(
		project_profile_git_paths_from_capture(
			tracked_capture,
			strict_utf8=False,
		),
		project_profile_git_paths_from_capture(
			untracked_capture,
			strict_utf8=False,
		),
	)
	strict_payload = make_project_profile_paths_payload(
		project_profile_git_paths_from_capture(
			tracked_capture,
			strict_utf8=True,
		),
		project_profile_git_paths_from_capture(
			untracked_capture,
			strict_utf8=True,
		),
	)
	legacy_paths = list(legacy_payload["paths"])
	legacy_errors = list(legacy_payload["errors"])
	legacy_payload.update({
		"legacy_paths": legacy_paths,
		"legacy_errors": legacy_errors,
	})
	strict_payload.update({
		"legacy_paths": legacy_paths,
		"legacy_errors": legacy_errors,
	})
	return {
		"legacy": legacy_payload,
		"strict": strict_payload,
	}


def make_project_profile_paths_payload(
	tracked_paths_result: dict[str, Any],
	untracked_paths_result: dict[str, Any],
) -> dict[str, Any]:
	results = (tracked_paths_result, untracked_paths_result)
	if any(result.get("error_kind") == "resource_limit" for result in results):
		return {
			"paths": [],
			"errors": project_profile_terminal_resource_issues("inventory_capture"),
		}
	errors: ProjectProfileIssueList = ProjectProfileIssueList()
	if tracked_paths_result.get("error"):
		errors.append(make_project_profile_issue(
			"project_profile_tracked_scan_failed",
			"",
			trim_text(str(tracked_paths_result["error"]), 1000),
		))
	if untracked_paths_result.get("error"):
		errors.append(make_project_profile_issue(
			"project_profile_untracked_scan_failed",
			"",
			trim_text(str(untracked_paths_result["error"]), 1000),
		))
	if errors:
		return {"paths": [], "errors": list(errors)}

	path_count = sum(
		int(result.get("path_count", len(result.get("paths", []))))
		for result in results
	)
	utf8_bytes = sum(
		int(result.get(
			"utf8_bytes",
			sum(
				len(str(path).encode("utf-8"))
				for path in result.get("paths", [])
			),
		))
		for result in results
	)
	if (
		path_count > PROJECT_PROFILE_INVENTORY_MAX_PATHS
		or utf8_bytes > PROJECT_PROFILE_INVENTORY_MAX_UTF8_BYTES
	):
		return {
			"paths": [],
			"errors": project_profile_terminal_resource_issues("inventory_envelope"),
		}
	combined_paths: set[str] = set()
	actual_count = 0
	actual_utf8_bytes = 0
	for result in results:
		for path_value in result.get("paths", []):
			if not isinstance(path_value, str):
				return {
					"paths": [],
					"errors": project_profile_terminal_resource_issues("inventory_path_type"),
				}
			actual_count += 1
			path_size = len(path_value.encode("utf-8"))
			if (
				actual_count > PROJECT_PROFILE_INVENTORY_MAX_PATHS
				or path_size > PROJECT_PROFILE_INVENTORY_MAX_PATH_BYTES
				or actual_utf8_bytes
				> PROJECT_PROFILE_INVENTORY_MAX_UTF8_BYTES - path_size
			):
				return {
					"paths": [],
					"errors": project_profile_terminal_resource_issues("inventory_envelope"),
				}
			actual_utf8_bytes += path_size
			combined_paths.add(path_value)
	if (
		project_profile_sort_work_units(len(combined_paths))
		> PROJECT_PROFILE_INVENTORY_MAX_SORT_WORK_UNITS
	):
		return {
			"paths": [],
			"errors": project_profile_terminal_resource_issues("inventory_sort_work"),
		}

	paths = sorted({
		path
		for path in combined_paths
		if should_scan_project_profile_path(path)
	})
	return {
		"paths": paths,
		"errors": [],
	}


def should_scan_project_profile_path(path: str) -> bool:
	normalized_path = path.replace("\\", "/")
	if any(normalized_path.startswith(prefix) for prefix in PROJECT_PROFILE_SCAN_EXCLUDED_PREFIXES):
		return False
	return True


def project_profile_inventory_path_is_invalid(path: str) -> bool:
	return (
		not path
		or path != path.strip()
		or "\\" in path
		or path.startswith("/")
		or re.match(r"^[A-Za-z]:", path) is not None
		or any(part in ("", ".", "..") for part in path.split("/"))
		or project_profile_string_has_unsafe_text_controls(path)
	)


def project_profile_audit_resource_name(
	data: dict[str, Any],
	repo_paths: list[str],
) -> str:
	if project_profile_strict_json_model_error(data):
		return "audit_structure"
	if len(repo_paths) > PROJECT_PROFILE_INVENTORY_MAX_PATHS:
		return "inventory_path_count"
	path_bytes = 0
	path_work_units = 0
	for path in repo_paths:
		if not isinstance(path, str):
			return "inventory_path_type"
		encoded_size = len(path.encode("utf-8"))
		if encoded_size > PROJECT_PROFILE_INVENTORY_MAX_PATH_BYTES:
			return "inventory_path_bytes"
		if path_bytes > PROJECT_PROFILE_INVENTORY_MAX_UTF8_BYTES - encoded_size:
			return "inventory_total_bytes"
		path_bytes += encoded_size
		path_work_units += 1 + (encoded_size + 63) // 64
	if (
		project_profile_sort_work_units(len(repo_paths))
		> PROJECT_PROFILE_INVENTORY_MAX_SORT_WORK_UNITS
	):
		return "inventory_sort_work"

	profile_weight = 0
	stack: list[Any] = [data]
	while stack:
		value = stack.pop()
		profile_weight += 1
		if isinstance(value, str):
			profile_weight += (len(value.encode("utf-8")) + 63) // 64
		elif isinstance(value, dict):
			stack.extend(value.keys())
			stack.extend(value.values())
		elif isinstance(value, list):
			stack.extend(value)
		if profile_weight > PROJECT_PROFILE_AUDIT_MAX_WORK_UNITS:
			return "audit_work"
	audit_work = (
		(profile_weight + 1) * (path_work_units + 1)
		+ project_profile_sort_work_units(len(repo_paths))
	)
	if audit_work > PROJECT_PROFILE_AUDIT_MAX_WORK_UNITS:
		return "audit_work"
	return ""


def audit_project_profile_data(
	data: dict[str, Any],
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
) -> list[dict[str, Any]]:
	if strict_v1:
		compilation = compile_project_profile_v1(data, profile_path)
		return audit_compiled_project_profile_data(compilation, profile_path, repo_paths)
	resource_name = project_profile_audit_resource_name(data, repo_paths)
	if resource_name:
		return project_profile_terminal_resource_issues(resource_name, profile_path)
	try:
		issues: ProjectProfileIssueList = ProjectProfileIssueList()
		issues.extend(audit_project_profile_schema(data, profile_path))
		if issues:
			return list(issues)
		audit_operation = project_profile_operation_registry(mode="legacy")["audit"]
		zone_handler = audit_operation["zone"]["handler"]
		for zone_index, zone in enumerate(project_profile_dict_list(data, "zones")):
			issues.extend(zone_handler(zone, zone_index, profile_path, repo_paths))
		for rule_index, rule in enumerate(project_profile_dict_list(data, "rules")):
			issues.extend(audit_project_profile_rule(rule, rule_index, profile_path, repo_paths))
		return list(issues)
	except ProjectProfileResourceLimitError:
		return project_profile_terminal_resource_issues("diagnostics", profile_path)


def audit_compiled_project_profile_data(
	compilation: dict[str, Any],
	profile_path: str,
	repo_paths: list[str],
) -> list[dict[str, Any]]:
	try:
		issues: ProjectProfileIssueList = ProjectProfileIssueList(compilation["issues"])
		if any(issue.get("severity") == "error" for issue in issues):
			return list(issues)
		issues.extend(audit_compiled_project_profile_runtime(
			compilation,
			profile_path,
			repo_paths,
		))
		return list(issues)
	except ProjectProfileResourceLimitError:
		return project_profile_terminal_resource_issues("diagnostics", profile_path)


def audit_compiled_project_profile_runtime(
	compilation: dict[str, Any],
	profile_path: str,
	repo_paths: list[str],
) -> list[dict[str, Any]]:
	if any(issue.get("severity") == "error" for issue in compilation["issues"]):
		return []
	compiled_data: dict[str, Any] = compilation["data"]
	resource_name = project_profile_audit_resource_name(compiled_data, repo_paths)
	if resource_name:
		return project_profile_terminal_resource_issues(resource_name, profile_path)
	try:
		issues: ProjectProfileIssueList = ProjectProfileIssueList()
		compiled_rules = project_profile_dict_list(compiled_data, "rules")
		feature_allowed_subdirs_by_root = (
			project_profile_feature_allowed_subdirs_by_root(compiled_rules)
		)
		audit_operation = project_profile_operation_registry(mode="strict-v1")["audit"]
		zone_handler = audit_operation["zone"]["handler"]
		for zone_index, zone in enumerate(project_profile_dict_list(compiled_data, "zones")):
			issues.extend(zone_handler(
				zone,
				zone_index,
				profile_path,
				repo_paths,
				strict_v1=True,
				contract=compilation["contract"],
			))
		for rule_index, rule in enumerate(compiled_rules):
			issues.extend(audit_project_profile_rule(
				rule,
				rule_index,
				profile_path,
				repo_paths,
				strict_v1=True,
				feature_allowed_subdirs_by_root=feature_allowed_subdirs_by_root,
			))
		return list(issues)
	except ProjectProfileResourceLimitError:
		return project_profile_terminal_resource_issues("diagnostics", profile_path)


def project_profile_feature_allowed_subdirs_by_root(
	rules: list[dict[str, Any]],
) -> dict[str, tuple[str, ...]]:
	allowed_by_root: dict[str, list[str]] = {}
	for rule in rules:
		if project_profile_raw_string(rule, "kind") != "feature_module_contract":
			continue
		allowed_subdirs = normalize_project_profile_paths(
			project_profile_string_array(rule, "allowed_subdirs")
		)
		for root in normalize_project_profile_paths(
			project_profile_string_array(rule, "roots")
		):
			root_allowed = allowed_by_root.setdefault(root, [])
			for subdir in allowed_subdirs:
				if subdir not in root_allowed:
					root_allowed.append(subdir)
	return {
		root: tuple(allowed_subdirs)
		for root, allowed_subdirs in allowed_by_root.items()
	}


def audit_project_profile_schema(
	data: dict[str, Any],
	profile_path: str,
	strict_v1: bool = False,
) -> list[dict[str, Any]]:
	if strict_v1:
		return compile_project_profile_v1(data, profile_path)["issues"]
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	for field_name in sorted(data.keys()):
		if field_name not in PROJECT_PROFILE_ALLOWED_FIELDS:
			issues.append(make_project_profile_issue(
				"unsupported_project_profile_field",
				profile_path,
				"Project profile fields are whitelisted; project-specific data belongs in metadata.",
				field=field_name,
			))
	if "schema_version" in data and not isinstance(data["schema_version"], int):
		issues.append(make_project_profile_issue(
			"invalid_project_profile_schema_version",
			profile_path,
			"schema_version must be an integer when present.",
			field="schema_version",
			expected_value="integer",
		))
	if "metadata" in data and not isinstance(data["metadata"], dict):
		issues.append(make_project_profile_issue(
			"invalid_project_profile_metadata",
			profile_path,
			"metadata must be an object when present.",
			field="metadata",
			expected_value="object",
		))
	for field_name in ("zones", "rules"):
		if field_name in data and not isinstance(data[field_name], list):
			issues.append(make_project_profile_issue(
				f"invalid_project_profile_{field_name}",
				profile_path,
				f"{field_name} must be an array when present.",
				field=field_name,
				expected_value="array",
			))
	for index, zone in enumerate(project_profile_raw_list(data, "zones")):
		if not isinstance(zone, dict):
			issues.append(make_project_profile_issue(
				"invalid_project_profile_zone",
				profile_path,
				"zones entries must be objects.",
				field="zones",
				row_index=index,
				expected_value="object",
			))
			continue
		for field_name in sorted(zone.keys()):
			if field_name not in PROJECT_PROFILE_ZONE_ALLOWED_FIELDS:
				issues.append(make_project_profile_issue(
					"unsupported_project_profile_zone_field",
					profile_path,
					"Zone fields are whitelisted; project-specific data belongs in metadata.",
					field=field_name,
					row_index=index,
				))
		issues.extend(validate_project_profile_severity(zone, profile_path, "zones", index))
	for index, rule in enumerate(project_profile_raw_list(data, "rules")):
		if not isinstance(rule, dict):
			issues.append(make_project_profile_issue(
				"invalid_project_profile_rule",
				profile_path,
				"rules entries must be objects.",
				field="rules",
				row_index=index,
				expected_value="object",
			))
			continue
		for field_name in sorted(rule.keys()):
			if field_name not in PROJECT_PROFILE_RULE_ALLOWED_FIELDS:
				issues.append(make_project_profile_issue(
					"unsupported_project_profile_rule_field",
					profile_path,
					"Rule fields are whitelisted; project-specific data belongs in metadata.",
					field=field_name,
					row_index=index,
				))
		rule_kind = project_profile_string(rule, "kind")
		if rule_kind not in PROJECT_PROFILE_RULE_KINDS:
			issues.append(make_project_profile_issue(
				"unsupported_project_profile_rule_kind",
				profile_path,
				"Project profile rule kind is not supported.",
				field="kind",
				row_index=index,
				actual_value=rule_kind,
			))
		issues.extend(validate_project_profile_severity(rule, profile_path, "rules", index))
	return issues


def validate_project_profile_severity(
	data: dict[str, Any],
	profile_path: str,
	field_name: str,
	row_index: int,
) -> list[dict[str, Any]]:
	severity = project_profile_string(data, "severity", "error")
	if severity in PROJECT_PROFILE_SEVERITIES:
		return []
	return [make_project_profile_issue(
		"invalid_project_profile_severity",
		profile_path,
		"severity must be one of error, warning, or info.",
		field=field_name,
		row_index=row_index,
		actual_value=severity,
	)]


def audit_project_profile_zone(
	zone: dict[str, Any],
	zone_index: int,
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
	contract: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	zone_id = project_profile_runtime_string(
		zone,
		"id",
		f"zone_{zone_index}",
		strict_v1=strict_v1,
	)
	severity = project_profile_severity(zone, strict_v1=strict_v1)
	roots = normalize_project_profile_paths(project_profile_string_array(zone, "roots"))
	exclude = normalize_project_profile_patterns(project_profile_string_array(zone, "exclude"))
	allow_extensions = normalize_project_profile_extensions(project_profile_string_array(zone, "allow_extensions"))
	deny_extensions = normalize_project_profile_extensions(project_profile_string_array(zone, "deny_extensions"))
	if not roots:
		issues.append(make_project_profile_issue(
			"project_profile_zone_missing_roots",
			profile_path,
			"Project profile zone must declare at least one root.",
			severity=severity,
			field="roots",
			zone_id=zone_id,
			row_index=zone_index,
		))
		return issues
	if project_profile_bool(zone, "required", False):
		for root_path in roots:
			if project_profile_root_exists(root_path, repo_paths):
				continue
			issues.append(make_project_profile_issue(
				"project_profile_required_root_missing",
				profile_path,
				"Required project profile root is missing.",
				severity=severity,
				field="roots",
				zone_id=zone_id,
				row_index=zone_index,
				actual_value=root_path,
			))
	for file_path in repo_paths_under_roots(repo_paths, roots):
		if project_profile_path_matches_any(file_path, exclude, strict_v1=strict_v1):
			continue
		extension = Path(file_path).suffix.lower()
		if allow_extensions and extension not in allow_extensions:
			issues.append(make_project_profile_issue(
				"project_profile_zone_extension_not_allowed",
				file_path,
				"File extension is not allowed in this project profile zone.",
				severity=severity,
				profile_path=profile_path,
				zone_id=zone_id,
				field="allow_extensions",
				actual_value=extension or "<none>",
				expected_value=", ".join(sorted(allow_extensions)),
				**({
					"reason_code": project_profile_contract_reason_code(contract, "zone_extension_not_allowed")
				} if strict_v1 and isinstance(contract, dict) else {}),
			))
		if deny_extensions and extension in deny_extensions:
			issues.append(make_project_profile_issue(
				"project_profile_zone_extension_denied",
				file_path,
				"File extension is denied in this project profile zone.",
				severity=severity,
				profile_path=profile_path,
				zone_id=zone_id,
				field="deny_extensions",
				actual_value=extension or "<none>",
				**({
					"reason_code": project_profile_contract_reason_code(contract, "zone_extension_denied")
				} if strict_v1 and isinstance(contract, dict) else {}),
			))
	return issues


def audit_project_profile_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
	feature_allowed_subdirs_by_root: dict[str, tuple[str, ...]] | None = None,
) -> list[dict[str, Any]]:
	rule_kind = project_profile_runtime_string(rule, "kind", strict_v1=strict_v1)
	mode = "strict-v1" if strict_v1 else "legacy"
	registry = project_profile_operation_registry(mode=mode)["audit"]["rules"]
	entry = registry.get(rule_kind)
	if entry is not None:
		handler = entry["handler"]
		if strict_v1 and rule_kind == "feature_module_contract":
			return handler(
				rule,
				rule_index,
				profile_path,
				repo_paths,
				strict_v1,
				feature_allowed_subdirs_by_root,
			)
		return handler(rule, rule_index, profile_path, repo_paths, strict_v1)
	return []


def project_profile_rule_handler_registry(
	mode: str = "strict-v1",
) -> dict[str, dict[str, Any]]:
	strict_contract_mode = mode in {"strict-v1", "strict-v1-shadow"}
	legacy_selector_fields = frozenset() if strict_contract_mode else frozenset({
		"include",
		"exclude",
		"extensions",
	})
	return {
		"path_exists": {
			"handler": audit_project_profile_path_exists_rule,
			"executed_fields": frozenset({"paths", "any", "severity"}),
		},
		"files_under_roots": {
			"handler": audit_project_profile_files_under_roots_rule,
			"executed_fields": frozenset({"roots", "include", "exclude", "extensions", "severity"}),
		},
		"extension_allowlist": {
			"handler": audit_project_profile_extension_allowlist_rule,
			"executed_fields": frozenset({"roots", "include", "exclude", "extensions", "severity"}),
		},
		"extension_denylist": {
			"handler": audit_project_profile_extension_denylist_rule,
			"executed_fields": frozenset({"roots", "include", "exclude", "extensions", "severity"}),
		},
		"naming_convention": {
			"handler": audit_project_profile_naming_convention_rule,
			"executed_fields": (
				frozenset({"roots", "exclude", "pattern", "target", "severity"})
				| (legacy_selector_fields - {"exclude"})
			),
		},
		"forbid_root_files": {
			"handler": audit_project_profile_forbid_root_files_rule,
			"executed_fields": frozenset({"allowed_files", "severity"}) | legacy_selector_fields,
		},
		"feature_module_contract": {
			"handler": audit_project_profile_feature_module_contract_rule,
			"executed_fields": frozenset({
				"roots",
				"feature_id_pattern",
				"required_subdirs",
				"allowed_subdirs",
				"allow_root_files",
				"severity",
			}) | legacy_selector_fields,
		},
		"generated_boundary": {
			"handler": audit_project_profile_generated_boundary_rule,
			"executed_fields": (
				frozenset({"include", "roots", "severity"})
				| (legacy_selector_fields - {"include"})
			),
		},
		"bucket_size": {
			"handler": audit_project_profile_bucket_size_rule,
			"executed_fields": frozenset({"roots", "max_files", "severity"}) | legacy_selector_fields,
		},
	}


def project_profile_operation_registry(
	mode: str = "strict-v1",
) -> dict[str, dict[str, Any]]:
	return {
		"audit": {
			"zone": {
				"handler": audit_project_profile_zone,
				"executed_fields": frozenset({
					"roots",
					"required",
					"allow_extensions",
					"deny_extensions",
					"exclude",
					"severity",
				}),
			},
			"rules": project_profile_rule_handler_registry(mode=mode),
		},
	}


def project_profile_zone_executed_fields(
	mode: str = "strict-v1",
) -> frozenset[str]:
	return project_profile_operation_registry(mode=mode)["audit"]["zone"]["executed_fields"]


def project_profile_python_capabilities(
	*,
	mode: str = "legacy",
	operation: str = "audit",
) -> dict[str, Any]:
	operation_registry = project_profile_operation_registry(mode=mode)
	operation_entry = operation_registry.get(operation)
	operation_supported = operation_entry is not None
	active_registry = operation_entry["rules"] if operation_entry is not None else {}
	zone_fields = (
		operation_entry["zone"]["executed_fields"]
		if operation_entry is not None
		else frozenset()
	)
	contract_enforced = mode in {"strict-v1", "strict-v1-shadow"}
	semantic_equivalence = (
		"not_guaranteed"
		if operation_supported and contract_enforced
		else "not_applicable"
	)
	limitation_codes = (
		[
			"empty_directories_unobservable",
			"godot_file_parser_duplicate_key_semantics_unverified",
			"inventory_envelope_differs_from_live_filesystem",
			"json_parser_numeric_and_unicode_semantics_executor_specific",
			"python_strict_structure_budget",
		]
		if semantic_equivalence == "not_guaranteed"
		else []
	)
	return {
		"executor": "python",
		"mode": mode,
		"operation": operation,
		"operation_supported": operation_supported,
		"contract_enforced": contract_enforced,
		"authoritative": mode != "strict-v1-shadow",
		"semantic_equivalence": semantic_equivalence,
		"limitation_codes": limitation_codes,
		"regex_dialect": PROJECT_PROFILE_REGEX_DIALECT,
		"limits": {
			"profile_bytes": PROJECT_PROFILE_STRICT_MAX_BYTES,
			"profile_depth": PROJECT_PROFILE_STRICT_MAX_DEPTH,
			"profile_values": PROJECT_PROFILE_STRICT_MAX_NODES,
			"git_stdout_bytes_per_command": PROJECT_PROFILE_GIT_STDOUT_MAX_BYTES,
			"git_stderr_bytes_per_command": PROJECT_PROFILE_GIT_STDERR_MAX_BYTES,
			"inventory_paths": PROJECT_PROFILE_INVENTORY_MAX_PATHS,
			"inventory_path_bytes": PROJECT_PROFILE_INVENTORY_MAX_PATH_BYTES,
			"inventory_total_utf8_bytes": PROJECT_PROFILE_INVENTORY_MAX_UTF8_BYTES,
			"inventory_sort_work_units": PROJECT_PROFILE_INVENTORY_MAX_SORT_WORK_UNITS,
			"audit_work_units": PROJECT_PROFILE_AUDIT_MAX_WORK_UNITS,
			"diagnostics": PROJECT_PROFILE_MAX_DIAGNOSTICS,
			"regex_utf8_bytes": PROJECT_PROFILE_REGEX_MAX_UTF8_BYTES,
			"regex_alternatives": PROJECT_PROFILE_REGEX_MAX_ALTERNATIVES,
			"regex_quantifiers_per_branch": (
				PROJECT_PROFILE_REGEX_MAX_QUANTIFIERS_PER_BRANCH
			),
		},
		"rule_kinds": sorted(active_registry),
		"rule_fields": {
			kind: sorted(entry["executed_fields"])
			for kind, entry in sorted(active_registry.items())
		},
		"zone_fields": sorted(zone_fields),
	}


def audit_project_profile_path_exists_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
) -> list[dict[str, Any]]:
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	rule_id = project_profile_runtime_string(
		rule, "id", f"rule_{rule_index}", strict_v1=strict_v1
	)
	severity = project_profile_severity(rule, strict_v1=strict_v1)
	paths = normalize_project_profile_paths(project_profile_string_array(rule, "paths"))
	if not paths:
		return [make_project_profile_issue(
			"project_profile_rule_missing_paths",
			profile_path,
			"path_exists rule must declare paths.",
			severity=severity,
			field="paths",
			rule_id=rule_id,
			row_index=rule_index,
		)]
	if project_profile_bool(rule, "any", False):
		if any(project_profile_path_exists(path, repo_paths) for path in paths):
			return []
		issues.append(make_project_profile_issue(
			"project_profile_any_path_missing",
			profile_path,
			"At least one declared project profile path must exist.",
			severity=severity,
			field="paths",
			rule_id=rule_id,
			row_index=rule_index,
			expected_value=", ".join(paths),
		))
		return issues
	for path in paths:
		if project_profile_path_exists(path, repo_paths):
			continue
		issues.append(make_project_profile_issue(
			"project_profile_path_missing",
			profile_path,
			"Declared project profile path is missing.",
			severity=severity,
			field="paths",
			rule_id=rule_id,
			row_index=rule_index,
			actual_value=path,
		))
	return issues


def audit_project_profile_files_under_roots_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
) -> list[dict[str, Any]]:
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	rule_id = project_profile_runtime_string(
		rule, "id", f"rule_{rule_index}", strict_v1=strict_v1
	)
	severity = project_profile_severity(rule, strict_v1=strict_v1)
	roots = normalize_project_profile_paths(project_profile_string_array(rule, "roots"))
	include = normalize_project_profile_patterns(project_profile_string_array(rule, "include"))
	exclude = normalize_project_profile_patterns(project_profile_string_array(rule, "exclude"))
	extensions = normalize_project_profile_extensions(project_profile_string_array(rule, "extensions"))
	for file_path in repo_paths:
		if not project_profile_file_selected(
			file_path,
			include,
			exclude,
			extensions,
			strict_v1=strict_v1,
		):
			continue
		if project_profile_path_under_any_root(file_path, roots):
			continue
		issues.append(make_project_profile_issue(
			"project_profile_file_outside_roots",
			file_path,
			"Selected file must live under one of the declared roots.",
			severity=severity,
			profile_path=profile_path,
			rule_id=rule_id,
			field="roots",
			expected_value=", ".join(roots),
		))
	return issues


def audit_project_profile_extension_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	allowlist: bool,
	strict_v1: bool = False,
) -> list[dict[str, Any]]:
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	rule_id = project_profile_runtime_string(
		rule, "id", f"rule_{rule_index}", strict_v1=strict_v1
	)
	severity = project_profile_severity(rule, strict_v1=strict_v1)
	roots = normalize_project_profile_paths(project_profile_string_array(rule, "roots"))
	include = normalize_project_profile_patterns(project_profile_string_array(rule, "include"))
	exclude = normalize_project_profile_patterns(project_profile_string_array(rule, "exclude"))
	extensions = normalize_project_profile_extensions(project_profile_string_array(rule, "extensions"))
	for file_path in repo_paths_under_roots(repo_paths, roots):
		if not project_profile_file_selected(
			file_path,
			include,
			exclude,
			set(),
			strict_v1=strict_v1,
		):
			continue
		extension = Path(file_path).suffix.lower()
		if allowlist and extension in extensions:
			continue
		if not allowlist and extension not in extensions:
			continue
		issues.append(make_project_profile_issue(
			"project_profile_extension_not_allowed" if allowlist else "project_profile_extension_denied",
			file_path,
			"File extension violates the project profile rule.",
			severity=severity,
			profile_path=profile_path,
			rule_id=rule_id,
			field="extensions",
			actual_value=extension or "<none>",
			expected_value=", ".join(sorted(extensions)),
		))
	return issues


def audit_project_profile_extension_allowlist_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
) -> list[dict[str, Any]]:
	return audit_project_profile_extension_rule(
		rule,
		rule_index,
		profile_path,
		repo_paths,
		True,
		strict_v1,
	)


def audit_project_profile_extension_denylist_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
) -> list[dict[str, Any]]:
	return audit_project_profile_extension_rule(
		rule,
		rule_index,
		profile_path,
		repo_paths,
		False,
		strict_v1,
	)


def audit_project_profile_naming_convention_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
) -> list[dict[str, Any]]:
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	rule_id = project_profile_runtime_string(
		rule, "id", f"rule_{rule_index}", strict_v1=strict_v1
	)
	severity = project_profile_severity(rule, strict_v1=strict_v1)
	pattern_text = project_profile_runtime_string(
		rule, "pattern", strict_v1=strict_v1
	)
	pattern, pattern_issues = compile_project_profile_regex(
		pattern_text,
		profile_path,
		rule_id,
		rule_index,
		"pattern",
		severity,
	)
	if pattern_issues:
		return pattern_issues
	target = project_profile_runtime_string(
		rule, "target", "path", strict_v1=strict_v1
	) or "path"
	if target not in {"path", "name", "stem"}:
		return [make_project_profile_issue(
			"project_profile_naming_target_invalid",
			profile_path,
			"naming_convention target must be one of path, name, or stem.",
			severity=severity,
			field="target",
			rule_id=rule_id,
			row_index=rule_index,
			actual_value=target,
		)]
	for file_path in project_profile_select_paths(rule, repo_paths, strict_v1=strict_v1):
		target_value = project_profile_path_target(file_path, target)
		if pattern is not None and (
			pattern.search(target_value) if strict_v1 else pattern.fullmatch(target_value)
		):
			continue
		issues.append(make_project_profile_issue(
			"project_profile_naming_convention_violation",
			file_path,
			"Selected path does not match the project profile naming convention.",
			severity=severity,
			profile_path=profile_path,
			rule_id=rule_id,
			field="pattern",
			target=target,
			actual_value=target_value,
			expected_value=pattern_text,
		))
	return issues


def audit_project_profile_forbid_root_files_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
) -> list[dict[str, Any]]:
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	rule_id = project_profile_runtime_string(
		rule, "id", f"rule_{rule_index}", strict_v1=strict_v1
	)
	severity = project_profile_severity(rule, strict_v1=strict_v1)
	allowed_files = set(normalize_project_profile_paths(project_profile_string_array(rule, "allowed_files")))
	for file_path in project_profile_select_paths(
		rule,
		repo_paths,
		use_roots=False,
		strict_v1=strict_v1,
	):
		if "/" in file_path:
			continue
		if file_path in allowed_files:
			continue
		issues.append(make_project_profile_issue(
			"project_profile_forbidden_root_file",
			file_path,
			"Root-level files must be explicitly listed in the project profile.",
			severity=severity,
			profile_path=profile_path,
			rule_id=rule_id,
			field="allowed_files",
			actual_value=file_path,
			expected_value=", ".join(sorted(allowed_files)),
		))
	return issues


def audit_project_profile_feature_module_contract_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
	allowed_subdirs_by_root: dict[str, tuple[str, ...]] | None = None,
) -> list[dict[str, Any]]:
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	rule_id = project_profile_runtime_string(
		rule, "id", f"rule_{rule_index}", strict_v1=strict_v1
	)
	severity = project_profile_severity(rule, strict_v1=strict_v1)
	roots = normalize_project_profile_paths(project_profile_string_array(rule, "roots"))
	if not roots:
		return [make_project_profile_issue(
			"project_profile_rule_missing_roots",
			profile_path,
			"feature_module_contract rule must declare roots.",
			severity=severity,
			field="roots",
			rule_id=rule_id,
			row_index=rule_index,
		)]
	feature_pattern_text = project_profile_runtime_string(
		rule,
		"feature_id_pattern",
		r"^[a-z][a-z0-9_]*$",
		strict_v1=strict_v1,
	)
	feature_pattern, pattern_issues = compile_project_profile_regex(
		feature_pattern_text,
		profile_path,
		rule_id,
		rule_index,
		"feature_id_pattern",
		severity,
	)
	if pattern_issues:
		return pattern_issues
	required_subdirs = normalize_project_profile_paths(project_profile_string_array(rule, "required_subdirs"))
	allowed_subdirs = set(normalize_project_profile_paths(project_profile_string_array(rule, "allowed_subdirs")))
	allow_root_files = project_profile_bool(rule, "allow_root_files", False)
	features_by_root: dict[str, dict[str, set[str]]] = {root: {} for root in roots}
	invalid_feature_ids: set[tuple[str, str]] = set()
	invalid_subdirs: set[tuple[str, str, str]] = set()
	for root in roots:
		root_allowed_subdirs = (
			allowed_subdirs_by_root.get(root, tuple(allowed_subdirs))
			if strict_v1 and allowed_subdirs_by_root is not None
			else tuple(allowed_subdirs)
		)
		root_prefix = root.rstrip("/") + "/"
		for file_path in project_profile_select_paths(
			rule,
			repo_paths,
			use_roots=False,
			strict_v1=strict_v1,
		):
			if not file_path.startswith(root_prefix):
				continue
			relative_path = file_path.removeprefix(root_prefix)
			parts = [part for part in relative_path.split("/") if part]
			if not parts:
				continue
			feature_id = parts[0]
			feature_subdirs = features_by_root[root].setdefault(feature_id, set())
			if feature_pattern is not None and not (
				feature_pattern.search(feature_id)
				if strict_v1
				else feature_pattern.fullmatch(feature_id)
			):
				invalid_feature_ids.add((root, feature_id))
			if len(parts) <= 2:
				if not allow_root_files:
					issues.append(make_project_profile_issue(
						"project_profile_feature_root_file",
						file_path,
						"Feature modules should place files in declared cohesive subdirectories.",
						severity=severity,
						profile_path=profile_path,
						rule_id=rule_id,
						field="allow_root_files",
						actual_value=file_path,
					))
				continue
			subdir = parts[1]
			feature_subdirs.add(subdir)
			if (strict_v1 or root_allowed_subdirs) and subdir not in root_allowed_subdirs:
				invalid_subdirs.add((root, feature_id, subdir))
	for root, feature_id in sorted(invalid_feature_ids):
		issues.append(make_project_profile_issue(
			"project_profile_feature_id_invalid",
			f"{root}/{feature_id}",
			"Feature module id does not match the project profile convention.",
			severity=severity,
			profile_path=profile_path,
			rule_id=rule_id,
			field="feature_id_pattern",
			actual_value=feature_id,
			expected_value=feature_pattern_text,
		))
	for root, feature_id, subdir in sorted(invalid_subdirs):
		root_allowed_subdirs = (
			allowed_subdirs_by_root.get(root, tuple(allowed_subdirs))
			if strict_v1 and allowed_subdirs_by_root is not None
			else tuple(allowed_subdirs)
		)
		issues.append(make_project_profile_issue(
			"project_profile_feature_subdir_not_allowed",
			f"{root}/{feature_id}/{subdir}",
			"Feature module subdirectory is not allowed by the project profile.",
			severity=severity,
			profile_path=profile_path,
			rule_id=rule_id,
			field="allowed_subdirs",
			actual_value=subdir,
			expected_value=", ".join(sorted(root_allowed_subdirs)),
		))
	for root, features in sorted(features_by_root.items()):
		for feature_id, present_subdirs in sorted(features.items()):
			for required_subdir in required_subdirs:
				if required_subdir in present_subdirs:
					continue
				issues.append(make_project_profile_issue(
					"project_profile_feature_required_subdir_missing",
					f"{root}/{feature_id}/{required_subdir}",
					"Feature module is missing a required cohesive subdirectory.",
					severity=severity,
					profile_path=profile_path,
					rule_id=rule_id,
					field="required_subdirs",
					actual_value=required_subdir,
				))
	return issues


def audit_project_profile_generated_boundary_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
) -> list[dict[str, Any]]:
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	rule_id = project_profile_runtime_string(
		rule, "id", f"rule_{rule_index}", strict_v1=strict_v1
	)
	severity = project_profile_severity(rule, strict_v1=strict_v1)
	roots = normalize_project_profile_paths(project_profile_string_array(rule, "roots"))
	include = normalize_project_profile_patterns(project_profile_string_array(rule, "include"))
	extensions = normalize_project_profile_extensions(project_profile_string_array(rule, "extensions"))
	if not roots:
		return [make_project_profile_issue(
			"project_profile_rule_missing_roots",
			profile_path,
			"generated_boundary rule must declare generated roots.",
			severity=severity,
			field="roots",
			rule_id=rule_id,
			row_index=rule_index,
		)]
	if not include and not extensions:
		return [make_project_profile_issue(
			"project_profile_generated_boundary_missing_selector",
			profile_path,
			"generated_boundary rule must declare include patterns or extensions.",
			severity=severity,
			field="include",
			rule_id=rule_id,
			row_index=rule_index,
		)]
	for file_path in project_profile_select_paths(
		rule,
		repo_paths,
		use_roots=False,
		strict_v1=strict_v1,
	):
		if project_profile_path_under_any_root(file_path, roots):
			continue
		issues.append(make_project_profile_issue(
			"project_profile_generated_file_outside_roots",
			file_path,
			"Generated files must stay under declared generated roots.",
			severity=severity,
			profile_path=profile_path,
			rule_id=rule_id,
			field="roots",
			expected_value=", ".join(roots),
		))
	return issues


def audit_project_profile_bucket_size_rule(
	rule: dict[str, Any],
	rule_index: int,
	profile_path: str,
	repo_paths: list[str],
	strict_v1: bool = False,
) -> list[dict[str, Any]]:
	issues: ProjectProfileIssueList = ProjectProfileIssueList()
	rule_id = project_profile_runtime_string(
		rule, "id", f"rule_{rule_index}", strict_v1=strict_v1
	)
	severity = project_profile_severity(rule, strict_v1=strict_v1)
	roots = normalize_project_profile_paths(project_profile_string_array(rule, "roots"))
	max_files = project_profile_int(rule, "max_files", 0)
	if not roots:
		return [make_project_profile_issue(
			"project_profile_rule_missing_roots",
			profile_path,
			"bucket_size rule must declare roots.",
			severity=severity,
			field="roots",
			rule_id=rule_id,
			row_index=rule_index,
		)]
	if max_files <= 0:
		return [make_project_profile_issue(
			"project_profile_bucket_size_invalid",
			profile_path,
			"bucket_size rule must declare a positive max_files value.",
			severity=severity,
			field="max_files",
			rule_id=rule_id,
			row_index=rule_index,
			actual_value=str(max_files),
		)]
	for root in roots:
		selected_paths = [
			file_path
			for file_path in project_profile_select_paths(
				rule,
				repo_paths,
				use_roots=False,
				strict_v1=strict_v1,
			)
			if project_profile_path_under_root(file_path, root)
		]
		if len(selected_paths) <= max_files:
			continue
		issues.append(make_project_profile_issue(
			"project_profile_bucket_too_large",
			root,
			"Project profile bucket contains more files than allowed.",
			severity=severity,
			profile_path=profile_path,
			rule_id=rule_id,
			field="max_files",
			actual_value=str(len(selected_paths)),
			expected_value=str(max_files),
		))
	return issues


def compile_project_profile_regex(
	pattern_text: str,
	profile_path: str,
	rule_id: str,
	rule_index: int,
	field: str,
	severity: str,
) -> tuple[re.Pattern[str] | None, list[dict[str, Any]]]:
	if not pattern_text:
		return None, [make_project_profile_issue(
			"project_profile_regex_missing",
			profile_path,
			"Project profile regex rule must declare a pattern.",
			severity=severity,
			field=field,
			rule_id=rule_id,
			row_index=rule_index,
		)]
	portable_error = project_profile_portable_regex_error(pattern_text)
	if portable_error and portable_error != "syntax":
		return None, [make_project_profile_issue(
			"project_profile_regex_unsafe",
			profile_path,
			"Project profile regex is outside the portable safe subset.",
			severity=severity,
			field=field,
			rule_id=rule_id,
			row_index=rule_index,
			reason_code=PROJECT_PROFILE_REGEX_UNSAFE_REASON_CODE,
			portable_reason=portable_error,
		)]
	try:
		return re.compile(pattern_text), []
	except (re.error, OverflowError) as error:
		return None, [make_project_profile_issue(
			"project_profile_regex_invalid",
			profile_path,
			"Project profile regex pattern is invalid.",
			severity=severity,
			field=field,
			rule_id=rule_id,
			row_index=rule_index,
			actual_value=pattern_text,
			error_type=type(error).__name__,
			error=str(error),
		)]


def project_profile_select_paths(
	rule: dict[str, Any],
	repo_paths: list[str],
	use_roots: bool = True,
	strict_v1: bool = False,
) -> list[str]:
	roots = normalize_project_profile_paths(project_profile_string_array(rule, "roots"))
	include = normalize_project_profile_patterns(project_profile_string_array(rule, "include"))
	exclude = normalize_project_profile_patterns(project_profile_string_array(rule, "exclude"))
	extensions = normalize_project_profile_extensions(project_profile_string_array(rule, "extensions"))
	candidate_paths = repo_paths_under_roots(repo_paths, roots) if use_roots else repo_paths
	return [
		file_path
		for file_path in candidate_paths
		if project_profile_file_selected(
			file_path,
			include,
			exclude,
			extensions,
			strict_v1=strict_v1,
		)
	]


def project_profile_path_target(file_path: str, target: str) -> str:
	name = file_path.rsplit("/", 1)[-1]
	if target == "name":
		return name
	if target == "stem":
		return Path(name).stem
	return file_path


def project_profile_file_selected(
	file_path: str,
	include: list[str],
	exclude: list[str],
	extensions: set[str],
	strict_v1: bool = False,
) -> bool:
	if include and not project_profile_path_matches_any(file_path, include, strict_v1=strict_v1):
		return False
	if exclude and project_profile_path_matches_any(file_path, exclude, strict_v1=strict_v1):
		return False
	if extensions and Path(file_path).suffix.lower() not in extensions:
		return False
	return True


def project_profile_path_matches_any(
	path: str,
	patterns: list[str],
	strict_v1: bool = False,
) -> bool:
	if not strict_v1:
		return any(fnmatch.fnmatch(path, pattern) for pattern in patterns)
	return any(project_profile_path_matches_canonical_glob(path, pattern) for pattern in patterns)


def project_profile_path_matches_canonical_glob(path: str, pattern: str) -> bool:
	expression = ""
	index = 0
	while index < len(pattern):
		character = pattern[index]
		if character == "*":
			if index + 1 < len(pattern) and pattern[index + 1] == "*":
				if index + 2 < len(pattern) and pattern[index + 2] == "/":
					expression += "(?:.*/)?"
					index += 3
				else:
					expression += ".*"
					index += 2
			else:
				expression += "[^/]*"
				index += 1
			continue
		if character == "?":
			expression += "[^/]"
			index += 1
			continue
		expression += re.escape(character)
		index += 1
	return re.fullmatch(expression, path) is not None


def repo_paths_under_roots(repo_paths: list[str], roots: list[str]) -> list[str]:
	if not roots:
		return list(repo_paths)
	return [
		path
		for path in repo_paths
		if project_profile_path_under_any_root(path, roots)
	]


def project_profile_path_under_any_root(path: str, roots: list[str]) -> bool:
	return any(project_profile_path_under_root(path, root) for root in roots)


def project_profile_path_under_root(path: str, root: str) -> bool:
	normalized_path = path.strip().replace("\\", "/")
	normalized_root = root.strip().replace("\\", "/").rstrip("/")
	if not normalized_root:
		return True
	return normalized_path == normalized_root or normalized_path.startswith(normalized_root + "/")


def project_profile_root_exists(root_path: str, repo_paths: list[str]) -> bool:
	return project_profile_path_exists(root_path, repo_paths) or any(
		project_profile_path_under_root(path, root_path)
		for path in repo_paths
	)


def project_profile_path_exists(path: str, repo_paths: list[str]) -> bool:
	normalized_path = path.strip().replace("\\", "/").rstrip("/")
	if not normalized_path:
		return True
	if normalized_path in repo_paths:
		return True
	return (ROOT / normalized_path).exists()


def project_profile_raw_list(data: dict[str, Any], key: str) -> list[Any]:
	value = data.get(key, [])
	return value if isinstance(value, list) else []


def project_profile_dict_list(data: dict[str, Any], key: str) -> list[dict[str, Any]]:
	result: list[dict[str, Any]] = []
	for item in project_profile_raw_list(data, key):
		if isinstance(item, dict):
			result.append(item)
	return result


def project_profile_string(data: dict[str, Any], key: str, fallback: str = "") -> str:
	value = data.get(key, fallback)
	if isinstance(value, str):
		return value.strip()
	return fallback


def project_profile_raw_string(data: dict[str, Any], key: str, fallback: str = "") -> str:
	value = data.get(key, fallback)
	return value if isinstance(value, str) else fallback


def project_profile_runtime_string(
	data: dict[str, Any],
	key: str,
	fallback: str = "",
	*,
	strict_v1: bool = False,
) -> str:
	if strict_v1:
		return project_profile_raw_string(data, key, fallback)
	return project_profile_string(data, key, fallback)


def project_profile_bool(data: dict[str, Any], key: str, fallback: bool = False) -> bool:
	value = data.get(key, fallback)
	if isinstance(value, bool):
		return value
	return fallback


def project_profile_int(data: dict[str, Any], key: str, fallback: int = 0) -> int:
	value = data.get(key, fallback)
	if isinstance(value, bool):
		return fallback
	if isinstance(value, int):
		return value
	return fallback


def project_profile_string_array(data: dict[str, Any], key: str) -> list[str]:
	value = data.get(key, [])
	if isinstance(value, str):
		return [value]
	if not isinstance(value, list):
		return []
	result: list[str] = []
	for item in value:
		if isinstance(item, str) and item.strip():
			result.append(item.strip())
	return result


def normalize_project_profile_paths(paths: list[str]) -> list[str]:
	result: list[str] = []
	for path in paths:
		normalized_path = normalize_project_profile_relative_path(path)
		if normalized_path and normalized_path not in result:
			result.append(normalized_path)
	return result


def normalize_project_profile_patterns(patterns: list[str]) -> list[str]:
	result: list[str] = []
	for pattern in patterns:
		normalized_pattern = normalize_project_profile_relative_path(pattern, allow_glob=True)
		if normalized_pattern and normalized_pattern not in result:
			result.append(normalized_pattern)
	return result


def normalize_project_profile_relative_path(path: str, allow_glob: bool = False) -> str:
	normalized_path = path.strip().replace("\\", "/")
	if normalized_path.startswith("res://"):
		normalized_path = normalized_path.removeprefix("res://")
	if normalized_path.startswith("./"):
		normalized_path = normalized_path[2:]
	normalized_path = normalized_path.strip("/")
	if not normalized_path:
		return ""
	if normalized_path.startswith("/") or "://" in normalized_path or ":" in normalized_path:
		return ""
	parts = [part for part in normalized_path.split("/") if part not in ("", ".")]
	if any(part == ".." for part in parts):
		return ""
	if not allow_glob and any(any(character in part for character in "*?[") for part in parts):
		return ""
	return "/".join(parts)


def normalize_project_profile_extensions(extensions: list[str]) -> set[str]:
	result: set[str] = set()
	for extension in extensions:
		normalized_extension = extension.strip().lower()
		if not normalized_extension:
			continue
		if not normalized_extension.startswith("."):
			normalized_extension = "." + normalized_extension
		result.add(normalized_extension)
	return result


def project_profile_severity(data: dict[str, Any], strict_v1: bool = False) -> str:
	severity = project_profile_runtime_string(
		data,
		"severity",
		"error",
		strict_v1=strict_v1,
	)
	if strict_v1:
		return severity
	return severity if severity in PROJECT_PROFILE_SEVERITIES else "error"


def make_project_profile_issue(
	kind: str,
	path: str,
	message: str,
	severity: str = "error",
	**extra: Any,
) -> dict[str, Any]:
	return make_boundary_issue(kind, path, message, severity=severity, **extra)
