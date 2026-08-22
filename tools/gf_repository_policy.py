#!/usr/bin/env python3
"""Validate and optionally apply GF repository workflow policy."""

from __future__ import annotations

import argparse
import configparser
import datetime as dt
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
POLICY_PATH = ROOT / ".github/repository-policy.json"
GITHUB_API_URL = "https://api.github.com"
STABLE_SEMVER_RE = re.compile(r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
REPOSITORY_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
COMMIT_SHA_RE = re.compile(r"^[0-9a-f]{40}$")
POLICY_FIELDS = {
	"schema_version",
	"repository",
	"default_branch",
	"internal_branch_pattern",
	"bot_branch_patterns",
	"development_version_pattern",
	"required_status_checks",
	"repository_settings",
	"branch_protection",
}
REPOSITORY_SETTING_FIELDS = {
	"allow_auto_merge",
	"allow_merge_commit",
	"allow_rebase_merge",
	"allow_squash_merge",
	"delete_branch_on_merge",
}
BRANCH_PROTECTION_FIELDS = {
	"allow_deletions",
	"allow_force_pushes",
	"dismiss_stale_reviews",
	"enforce_admins",
	"require_code_owner_reviews",
	"require_last_push_approval",
	"required_approving_review_count",
	"required_conversation_resolution",
	"required_linear_history",
	"strict_status_checks",
}
REQUIRED_STATUS_CHECKS = (
	"GF repository policy",
	"GF merge gate",
)
FRAMEWORK_CI_SUITES = (
	"framework-gut",
	"framework-lsp",
	"framework-static",
)
FRAMEWORK_GUT_CI_TIMEOUT_MINUTES = 60
REPOSITORY_POLICY_COMMAND = "python tools/gf_repository_policy.py validate --json"
PULL_REQUEST_POLICY_COMMAND = "python tools/gf_repository_policy.py validate-pr --json"
QUICK_CI_COMMAND = (
	"python tools/gf_maintenance.py check --suite quick "
	"--failed-only --github-annotations"
)
FRAMEWORK_CI_COMMAND = (
	"python tools/gf_maintenance.py check --suite ${{ matrix.suite }} "
	"--failed-only --github-annotations"
)
PACKAGE_CI_COMMAND = FRAMEWORK_CI_COMMAND
RELEASE_FRAMEWORK_TIMEOUT_MINUTES = 90
RELEASE_FRAMEWORK_SUITE_TIMEOUT_SECONDS = 4800
RELEASE_FRAMEWORK_COMMAND = (
	"python tools/gf_maintenance.py check --suite framework "
	f"--suite-timeout {RELEASE_FRAMEWORK_SUITE_TIMEOUT_SECONDS} "
	"--failed-only --github-annotations"
)
RELEASE_VERIFY_ARTIFACT_COMMAND = (
	'python tools/build_gf_release_artifacts.py --version "${GITHUB_REF_NAME}" '
	'--manifest "build/release/gf-release-artifacts-${GITHUB_REF_NAME}.json" '
	"--validate-only"
)
RELEASE_EXTRACT_NOTES_COMMAND = (
	'python tools/extract_release_notes.py --tag "${GITHUB_REF_NAME}" '
	'--output "${RUNNER_TEMP}/release-notes.md"'
)
RELEASE_CREATE_COMMAND = (
	'gh release create "${GITHUB_REF_NAME}" \\ '
	'"build/release/gf-framework-${GITHUB_REF_NAME}.zip" \\ '
	'"build/release/gf-ai-developer-kit-${GITHUB_REF_NAME}.zip" \\ '
	'"build/release/gf-registry-${GITHUB_REF_NAME}.json" \\ '
	'"build/release/gf-registry-source.json" \\ '
	'"build/release/gf-package-offline-bundle-${GITHUB_REF_NAME}.zip" \\ '
	'"build/release/gf-release-artifacts-${GITHUB_REF_NAME}.json" \\ '
	'build/release/packages/*.zip \\ --verify-tag \\ '
	'--title "${GITHUB_REF_NAME}" \\ '
	'--notes-file "${RUNNER_TEMP}/release-notes.md"'
)
MANUAL_FULL_TIMEOUT_MINUTES = 90
MANUAL_FULL_COMMAND = (
	"python tools/gf_maintenance.py check --suite full "
	"--failed-only --github-annotations"
)
WINDOWS_PROCESS_SELF_TEST_COMMAND = (
	"python tools/gf_maintenance.py maintenance-self-test --json"
)
WINDOWS_STAGING_TEST_COMMAND = (
	"python -B -m unittest "
	"tests.gf_core.tools.test_gf_parallel_validation "
	"tests.gf_core.tools.test_gf_maintenance_check_graph"
)
PACKAGE_CI_SUITES = (
	"package-contract",
	"package-editor",
	"package-cli-local",
	"package-cli-network",
	"package-godot-ci",
)
RELEASE_PACKAGE_SUITES = (
	"package-contract",
	"package-editor",
	"package-cli-local",
	"package-cli-network",
	"package-godot-release",
)
REQUIRED_CI_SUITES = (*FRAMEWORK_CI_SUITES, *PACKAGE_CI_SUITES)
DRAFT_GATE_NAME = "${{ github.event_name == 'pull_request' && github.event.pull_request.draft == true && (github.event.action != 'edited' || github.event.changes.base.ref.from != '') && 'GF draft gate' || 'GF draft gate (not applicable)' }}"
REPOSITORY_POLICY_NAME = "GF repository policy"
FULL_VALIDATION_EVENT = "github.event_name == 'push' || (github.event_name == 'pull_request' && github.event.pull_request.draft == false && (github.event.action != 'edited' || github.event.changes.base.ref.from != ''))"
REQUIRED_GATE_EVENT = "github.event_name == 'push' || (github.event_name == 'pull_request' && github.event.pull_request.draft == false)"
METADATA_READY_EVENT = "github.event_name == 'pull_request' && github.event.pull_request.draft == false && github.event.action == 'edited' && github.event.changes.base.ref.from == ''"
METADATA_RELAY_STEP_IF = "success() && " + METADATA_READY_EVENT
CURRENT_FULL_STEP_IF = (
	"success() && (github.event_name == 'push' || "
	"(github.event_name == 'pull_request' && "
	"(github.event.action != 'edited' || github.event.changes.base.ref.from != '')))"
)
METADATA_RELAY_COMMAND = (
	"python tools/gf_repository_policy.py validate-pr-gate "
	"--wait-seconds 1800 --poll-seconds 10 --json"
)
CI_RUN_NAME = "GF CI|mode=${{ github.event_name == 'pull_request' && github.event.action == 'edited' && github.event.changes.base.ref.from == '' && 'metadata' || (github.event_name == 'pull_request' && github.event.pull_request.draft == true && 'draft' || 'full') }}|pr=${{ github.event.pull_request.number || 0 }}|head=${{ github.event.pull_request.head.sha || github.sha }}|base=${{ github.event.pull_request.base.sha || github.sha }}"
FULL_VALIDATION_GATE_NAME = "GF full validation (${{ github.event.pull_request.base.sha || github.sha }})"
MERGE_GATE_NAME = "${{ (" + REQUIRED_GATE_EVENT + ") && 'GF merge gate' || 'GF merge gate (not applicable)' }}"
METADATA_CONCURRENCY_GROUP = "ci-${{ github.event.pull_request.number || github.ref }}-${{ github.event_name == 'pull_request' && github.event.action == 'edited' && github.event.changes.base.ref.from == '' && 'policy' || 'validation' }}"
GITHUB_ACTIONS_APP_ID = 15368
FULL_VALIDATION_MAX_AGE = dt.timedelta(days=7)
FULL_VALIDATION_RELAY_MAX_WAIT_SECONDS = 1800
FULL_VALIDATION_RELAY_MAX_POLL_SECONDS = 60
FULL_VALIDATION_RELAY_MAX_PAGES = 10
GITHUB_REQUEST_TIMEOUT_SECONDS = 30.0
MANUAL_CI_RUN_NAME = "GF manual diagnostics|ref=${{ github.ref }}|sha=${{ github.sha }}"
MAINTENANCE_SKILL_PATHS = (
	".codex/skills/gf-framework-maintenance/SKILL.md",
	".codex/skills/gf-framework-maintenance/references/checks.md",
	".codex/skills/gf-reference-boundary/SKILL.md",
	".codex/skills/gf-reference-boundary/references/reference-project.md",
	".codex/skills/gf-change-audit/SKILL.md",
	".codex/skills/gf-release-flow/SKILL.md",
	".codex/skills/gf-release-flow/references/release-checks.md",
)
MANUAL_MAIN_EVENT = "github.ref == 'refs/heads/main'"


class DuplicateJsonKeyError(ValueError):
	pass


class GitHubApiError(RuntimeError):
	def __init__(self, status: int, message: str) -> None:
		super().__init__(message)
		self.status = status


def main(argv: list[str] | None = None) -> int:
	configure_stdio()
	parser = argparse.ArgumentParser(description=__doc__)
	subparsers = parser.add_subparsers(dest="command", required=True)

	validate_parser = subparsers.add_parser("validate", help="Validate local repository policy and governed files.")
	validate_parser.add_argument("--json", action="store_true", help="Print JSON output.")

	pr_parser = subparsers.add_parser("validate-pr", help="Validate one pull request against the local policy.")
	pr_parser.add_argument("--base-ref", default=os.environ.get("GITHUB_BASE_REF", ""))
	pr_parser.add_argument("--head-ref", default=os.environ.get("GITHUB_HEAD_REF", ""))
	pr_parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
	pr_parser.add_argument("--head-repository", default=os.environ.get("GF_HEAD_REPOSITORY", ""))
	pr_parser.add_argument("--json", action="store_true", help="Print JSON output.")

	gate_parser = subparsers.add_parser(
		"validate-pr-gate",
		help="Fail closed unless the latest matching Full validation epoch is reusable.",
	)
	gate_parser.add_argument("--repository", default=os.environ.get("GITHUB_REPOSITORY", ""))
	gate_parser.add_argument("--pull-number", default=os.environ.get("GF_PR_NUMBER", ""))
	gate_parser.add_argument("--head-sha", default=os.environ.get("GF_PR_HEAD_SHA", ""))
	gate_parser.add_argument("--base-sha", default=os.environ.get("GF_PR_BASE_SHA", ""))
	gate_parser.add_argument("--wait-seconds", type=int, default=FULL_VALIDATION_RELAY_MAX_WAIT_SECONDS)
	gate_parser.add_argument("--poll-seconds", type=int, default=10)
	gate_parser.add_argument("--json", action="store_true", help="Print JSON output.")

	protection_parser = subparsers.add_parser(
		"protection",
		help="Check or explicitly apply GitHub repository settings and main protection.",
	)
	protection_parser.add_argument("--repository", default="", help="GitHub owner/name. Defaults to policy repository.")
	protection_parser.add_argument("--apply", action="store_true", help="Apply drift before re-checking it.")
	protection_parser.add_argument("--json", action="store_true", help="Print JSON output.")

	args = parser.parse_args(argv)
	policy, load_issues = load_repository_policy()
	if args.command == "validate":
		issues = [*load_issues]
		if not issues:
			issues.extend(audit_repository_files(policy))
			issues.extend(run_policy_self_tests(policy))
		result = make_result("validate", issues)
		print_result(result, args.json)
		return 0 if result["ok"] else 1
	if args.command == "validate-pr":
		issues = [*load_issues]
		if not issues:
			source_version = read_plugin_version()
			issues.extend(audit_pull_request(
				policy,
				base_ref=args.base_ref,
				head_ref=args.head_ref,
				repository=args.repository,
				head_repository=args.head_repository,
				source_version=source_version,
			))
		result = make_result("validate-pr", issues, {
			"base_ref": args.base_ref,
			"head_ref": args.head_ref,
			"repository": args.repository,
			"head_repository": args.head_repository,
		})
		print_result(result, args.json)
		return 0 if result["ok"] else 1
	if args.command == "validate-pr-gate":
		issues = [*load_issues]
		if issues:
			result = make_result("validate-pr-gate", issues)
		else:
			result = validate_pr_gate_relay(
				policy,
				repository=args.repository,
				pull_number=args.pull_number,
				head_sha=args.head_sha,
				base_sha=args.base_sha,
				wait_seconds=args.wait_seconds,
				poll_seconds=args.poll_seconds,
			)
		print_result(result, args.json)
		return 0 if result["ok"] else 1
	if args.command == "protection":
		issues = [*load_issues]
		repository = args.repository.strip() or str(policy.get("repository", ""))
		result: dict[str, Any]
		if issues:
			result = make_result("protection", issues, make_protection_result_context(repository, args.apply))
		else:
			result = check_or_apply_remote_policy(policy, repository, args.apply)
		print_result(result, args.json)
		return 0 if result["ok"] else 1
	return 2


def configure_stdio() -> None:
	for stream in (sys.stdout, sys.stderr):
		if hasattr(stream, "reconfigure"):
			stream.reconfigure(encoding="utf-8", errors="strict")


def load_repository_policy(path: Path = POLICY_PATH) -> tuple[dict[str, Any], list[str]]:
	try:
		data = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicate_json_keys)
	except (OSError, UnicodeDecodeError, json.JSONDecodeError, DuplicateJsonKeyError) as error:
		return {}, [f"Repository policy is not strict UTF-8 JSON: {error}"]
	if not isinstance(data, dict):
		return {}, ["Repository policy root must be an object."]
	return data, audit_policy_data(data)


def reject_duplicate_json_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
	result: dict[str, Any] = {}
	for key, value in pairs:
		if key in result:
			raise DuplicateJsonKeyError(f"Duplicate JSON key: {key}")
		result[key] = value
	return result


def audit_policy_data(policy: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	audit_exact_fields(policy, POLICY_FIELDS, "policy", issues)
	if policy.get("schema_version") != 2:
		issues.append("Repository policy schema_version must be the integer 2.")
	repository = policy.get("repository")
	if not isinstance(repository, str) or REPOSITORY_RE.fullmatch(repository) is None:
		issues.append("Repository policy repository must use owner/name syntax.")
	for field_name in ("default_branch", "internal_branch_pattern", "development_version_pattern"):
		if not isinstance(policy.get(field_name), str) or not str(policy.get(field_name, "")).strip():
			issues.append(f"Repository policy {field_name} must be a non-empty string.")
	required_status_checks = policy.get("required_status_checks")
	if (
		not isinstance(required_status_checks, list)
		or not required_status_checks
		or any(not isinstance(item, str) or not item.strip() for item in required_status_checks)
	):
		issues.append("Repository policy required_status_checks must be a non-empty string array.")
	elif len(set(required_status_checks)) != len(required_status_checks):
		issues.append("Repository policy required_status_checks must not contain duplicates.")
	elif required_status_checks != list(REQUIRED_STATUS_CHECKS):
		issues.append(
			"Repository policy required_status_checks must be exactly "
			f"{list(REQUIRED_STATUS_CHECKS)!r}."
		)
	for field_name in ("internal_branch_pattern", "development_version_pattern"):
		audit_regex(policy.get(field_name), field_name, issues)
	bot_patterns = policy.get("bot_branch_patterns")
	if not isinstance(bot_patterns, list) or not bot_patterns or any(not isinstance(item, str) for item in bot_patterns):
		issues.append("Repository policy bot_branch_patterns must be a non-empty string array.")
	else:
		for index, pattern in enumerate(bot_patterns):
			audit_regex(pattern, f"bot_branch_patterns[{index}]", issues)

	repository_settings = policy.get("repository_settings")
	if not isinstance(repository_settings, dict):
		issues.append("Repository policy repository_settings must be an object.")
	else:
		audit_exact_fields(repository_settings, REPOSITORY_SETTING_FIELDS, "repository_settings", issues)
		for field_name in REPOSITORY_SETTING_FIELDS:
			if not isinstance(repository_settings.get(field_name), bool):
				issues.append(f"repository_settings.{field_name} must be boolean.")

	protection = policy.get("branch_protection")
	if not isinstance(protection, dict):
		issues.append("Repository policy branch_protection must be an object.")
	else:
		audit_exact_fields(protection, BRANCH_PROTECTION_FIELDS, "branch_protection", issues)
		for field_name in BRANCH_PROTECTION_FIELDS - {"required_approving_review_count"}:
			if not isinstance(protection.get(field_name), bool):
				issues.append(f"branch_protection.{field_name} must be boolean.")
		approval_count = protection.get("required_approving_review_count")
		if type(approval_count) is not int or approval_count < 0 or approval_count > 6:
			issues.append("branch_protection.required_approving_review_count must be an integer from 0 to 6.")
	return issues


def audit_exact_fields(data: dict[str, Any], expected: set[str], label: str, issues: list[str]) -> None:
	missing = sorted(expected - set(data))
	unknown = sorted(set(data) - expected)
	if missing:
		issues.append(f"{label} is missing fields: {', '.join(missing)}")
	if unknown:
		issues.append(f"{label} has unsupported fields: {', '.join(unknown)}")


def audit_regex(value: Any, label: str, issues: list[str]) -> None:
	if not isinstance(value, str):
		return
	try:
		re.compile(value)
	except re.error as error:
		issues.append(f"Repository policy {label} is not a valid regex: {error}")


def audit_repository_files(policy: dict[str, Any], root: Path = ROOT) -> list[str]:
	issues: list[str] = []
	required_paths = (
		root / "CONTRIBUTING.md",
		root / ".github/CODEOWNERS",
		root / ".github/PULL_REQUEST_TEMPLATE.md",
		root / ".github/workflows/ci.yml",
		root / ".github/workflows/ci-manual.yml",
		root / ".github/workflows/release.yml",
		*(root / path for path in MAINTENANCE_SKILL_PATHS),
	)
	for path in required_paths:
		if not path.is_file():
			issues.append(f"Required workflow file is missing: {relative_path(path, root)}")
	if issues:
		return issues

	ci_source = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
	issues.extend(audit_ci_workflow(policy, ci_source))
	manual_ci_source = (root / ".github/workflows/ci-manual.yml").read_text(encoding="utf-8")
	issues.extend(audit_manual_ci_workflow(manual_ci_source))
	release_source = (root / ".github/workflows/release.yml").read_text(encoding="utf-8")
	issues.extend(audit_release_workflow(release_source))
	skill_sources = {
		path: (root / path).read_text(encoding="utf-8")
		for path in MAINTENANCE_SKILL_PATHS
	}
	issues.extend(audit_maintenance_skill_contracts(skill_sources))

	owner = str(policy["repository"]).split("/", 1)[0]
	codeowners_source = (root / ".github/CODEOWNERS").read_text(encoding="utf-8")
	if f"@{owner}" not in codeowners_source:
		issues.append(f"CODEOWNERS does not reference repository owner @{owner}.")
	contributing_source = (root / "CONTRIBUTING.md").read_text(encoding="utf-8")
	for marker in ("Draft", "Ready for review", "Development Version", "GF merge gate"):
		if marker not in contributing_source:
			issues.append(f"CONTRIBUTING.md is missing workflow marker: {marker}")

	source_version = read_plugin_version(root)
	development_pattern = re.compile(str(policy["development_version_pattern"]))
	if STABLE_SEMVER_RE.fullmatch(source_version) is None and development_pattern.fullmatch(source_version) is None:
		issues.append(f"plugin.cfg version must be stable SemVer or the governed development form: {source_version!r}")
	for manifest_path in sorted((root / "addons/gf/extensions").rglob("gf_extension.json")):
		try:
			manifest = json.loads(manifest_path.read_text(encoding="utf-8"), object_pairs_hook=reject_duplicate_json_keys)
		except (OSError, UnicodeDecodeError, json.JSONDecodeError, DuplicateJsonKeyError) as error:
			issues.append(f"Extension manifest is not strict JSON: {relative_path(manifest_path, root)}: {error}")
			continue
		if not isinstance(manifest, dict) or manifest.get("version") != source_version:
			issues.append(f"Extension manifest version must match plugin.cfg: {relative_path(manifest_path, root)}")
	return issues


def audit_maintenance_skill_contracts(sources: dict[str, str]) -> list[str]:
	issues: list[str] = []

	def require(path: str, marker: str, label: str) -> None:
		if marker not in sources.get(path, ""):
			issues.append(f"Maintenance skill contract is missing {label}: {path}")

	def forbid(path: str, marker: str, label: str) -> None:
		if marker in sources.get(path, ""):
			issues.append(f"Maintenance skill contract still contains {label}: {path}")

	release_skill = ".codex/skills/gf-release-flow/SKILL.md"
	release_checks = ".codex/skills/gf-release-flow/references/release-checks.md"
	reference_skill = ".codex/skills/gf-reference-boundary/SKILL.md"
	reference_notes = ".codex/skills/gf-reference-boundary/references/reference-project.md"
	change_audit = ".codex/skills/gf-change-audit/SKILL.md"
	framework_skill = ".codex/skills/gf-framework-maintenance/SKILL.md"
	framework_checks = ".codex/skills/gf-framework-maintenance/references/checks.md"

	require(release_skill, "already reviewed short-lived internal branch", "ordinary release branch rule")
	require(release_skill, "real stabilization freeze", "release freeze rule")
	require(release_skill, "affected immutable stable tag", "hotfix tag-origin rule")
	require(
		release_checks,
		"check --suite release --artifact-manifest",
		"pre-tag release-suite artifact validation",
	)
	forbid(release_checks, "check --suite full --json", "obsolete pre-tag full-suite command")

	for path in (reference_skill, reference_notes):
		require(path, "sync_reference_project.py --check", "path-configurable reference sync check")
		require(path, "sync_reference_project.py --apply", "explicit reference sync apply command")
		forbid(path, "--project-root ..\\gf-reference-project", "hard-coded reference project command")
		forbid(path, "driftbound_", "product-specific reference scene command")
	require(release_checks, "sync_reference_project.py --apply", "explicit release reference sync apply command")

	for marker, label in (
		("Freeze an audit input manifest", "immutable audit input preparation"),
		("SHA-256", "audit digest binding"),
		("recompute the audit input manifest", "end-of-audit drift check"),
		("stale", "stale-result rejection"),
	):
		require(change_audit, marker, label)

	require(
		framework_skill,
		"remove only logs created or rewritten by that invocation",
		"session-owned automatic log cleanup",
	)
	require(framework_skill, "log-hygiene --dry-run --json", "log deletion preview")
	require(framework_skill, "explicitly authorizes workspace-wide cleanup", "workspace-wide cleanup authority")
	forbid(
		framework_skill,
		"Successful maintenance commands remove their session-owned logs and legacy top-level",
		"automatic legacy-log deletion",
	)
	require(
		framework_checks,
		"Historical retention and legacy top-level `.gf/*.log` cleanup occur only through an explicit",
		"explicit historical log cleanup",
	)
	require(
		framework_checks,
		"Ready/main `framework-gut` uses exactly 60 minutes",
		"Ready/main workflow deadline contract",
	)
	require(
		framework_checks,
		"tag-release `release-framework-checks` uses exactly 90 minutes around a 4,800-second",
		"release workflow deadline contract",
	)
	require(
		framework_checks,
		"manual `main` Full remains exactly 90 minutes",
		"manual workflow deadline contract",
	)
	return issues


def audit_manual_ci_workflow(source: str) -> list[str]:
	issues: list[str] = []
	actual_top_level_fields = extract_yaml_direct_mapping_keys(source, 0)
	expected_top_level_fields = ["name", "run-name", "on", "permissions", "concurrency", "jobs"]
	if actual_top_level_fields != expected_top_level_fields:
		issues.append(
			"Manual CI top-level fields are "
			f"{actual_top_level_fields!r}, expected {expected_top_level_fields!r}."
		)
	if extract_yaml_top_level_block(source, "on").rstrip("\r\n") != "on:\n  workflow_dispatch:":
		issues.append("Manual CI triggers must contain only workflow_dispatch.")
	manual_permission_keys = extract_yaml_mapping_keys(source, "permissions", 0)
	if manual_permission_keys != ["contents"]:
		issues.append("Manual CI top-level permissions must contain only contents: read.")
	expected_manual_concurrency = (
		"concurrency:\n"
		"  group: ci-manual-${{ github.ref }}\n"
		"  cancel-in-progress: true"
	)
	if extract_yaml_top_level_block(source, "concurrency").rstrip("\r\n") != expected_manual_concurrency:
		issues.append("Manual CI concurrency must remain ref-scoped and cancelling.")
	jobs, duplicate_jobs = extract_ci_job_blocks(source)
	reject_failure_tolerant_jobs_and_steps(jobs, "Manual CI", issues)
	if duplicate_jobs:
		issues.append(f"Manual CI workflow has duplicate job ids: {', '.join(sorted(duplicate_jobs))}.")
	required_job_ids = {
		"manual-repository-policy",
		"manual-full-validation",
		"manual-windows-process-supervision",
		"manual-diagnostics-gate",
	}
	missing_job_ids = sorted(required_job_ids - set(jobs))
	if missing_job_ids:
		issues.append(f"Manual CI workflow is missing governed jobs: {', '.join(missing_job_ids)}.")
	extra_job_ids = sorted(set(jobs) - required_job_ids)
	if extra_job_ids:
		issues.append(f"Manual CI workflow has unsupported jobs: {', '.join(extra_job_ids)}.")
	expected_job_fields = {
		"manual-repository-policy": ("name", "runs-on", "timeout-minutes", "steps"),
		"manual-full-validation": ("name", "if", "needs", "runs-on", "timeout-minutes", "steps"),
		"manual-windows-process-supervision": (
			"name", "if", "needs", "runs-on", "timeout-minutes", "steps",
		),
		"manual-diagnostics-gate": ("name", "if", "needs", "runs-on", "timeout-minutes", "steps"),
	}
	for job_id, expected_fields in expected_job_fields.items():
		if job_id in jobs:
			require_exact_job_fields(jobs[job_id], job_id, expected_fields, issues)
	manual_step_names = {
		"manual-repository-policy": ("Checkout", "Set up Python", "Validate repository policy"),
		"manual-full-validation": (
			"Checkout", "Set up Python", "Install documentation dependencies",
			"Set up Godot", "Run full maintenance diagnostics",
		),
		"manual-windows-process-supervision": (
			"Checkout", "Set up Python", "Verify owned process-tree cleanup",
		),
		"manual-diagnostics-gate": ("Evaluate manual diagnostics",),
	}
	for job_id, expected_names in manual_step_names.items():
		if job_id in jobs:
			require_exact_step_names(jobs[job_id], job_id, expected_names, issues)
	if not extract_yaml_mapping_block(source, "on", 0, "workflow_dispatch", 2):
		issues.append("Manual CI workflow_dispatch trigger is missing.")
	for forbidden_event in ("pull_request", "push"):
		if extract_yaml_mapping_block(source, "on", 0, forbidden_event, 2):
			issues.append(f"Manual CI must not run automatically on {forbidden_event}.")
	if extract_yaml_scalar(source, "run-name", 0) != MANUAL_CI_RUN_NAME:
		issues.append("Manual CI run-name must remain isolated from required CI epochs.")
	if "GF merge gate" in source:
		issues.append("Manual CI must never emit or reference the protected GF merge gate context.")
	permissions_source = extract_yaml_top_level_block(source, "permissions")
	if extract_yaml_scalar(permissions_source, "contents", 2) != "read":
		issues.append("Manual CI top-level permission contents must be read.")
	for permission_name in ("actions", "checks", "pull-requests"):
		if extract_yaml_scalar(permissions_source, permission_name, 2):
			issues.append(f"Manual CI top-level permission {permission_name} must remain unset.")

	repository_job = jobs.get("manual-repository-policy", "")
	if repository_job:
		require_exact_job_scalar(
			repository_job,
			"manual-repository-policy",
			"name",
			"GF manual repository policy",
			issues,
		)
		require_exact_run_step(
			repository_job,
			"manual-repository-policy",
			"Validate repository policy",
			REPOSITORY_POLICY_COMMAND,
			issues,
		)
	full_job = jobs.get("manual-full-validation", "")
	if full_job:
		require_exact_job_fields(
			full_job,
			"manual-full-validation",
			("name", "if", "needs", "runs-on", "timeout-minutes", "steps"),
			issues,
		)
		require_exact_job_scalar(full_job, "manual-full-validation", "name", "GF manual Full validation", issues)
		require_exact_job_scalar(
			full_job,
			"manual-full-validation",
			"timeout-minutes",
			str(MANUAL_FULL_TIMEOUT_MINUTES),
			issues,
		)
		require_exact_job_scalar(full_job, "manual-full-validation", "if", MANUAL_MAIN_EVENT, issues)
		require_exact_job_needs(
			full_job,
			"manual-full-validation",
			("manual-repository-policy",),
			issues,
		)
		require_exact_run_step(
			full_job,
			"manual-full-validation",
			"Run full maintenance diagnostics",
			MANUAL_FULL_COMMAND,
			issues,
		)
	windows_job = jobs.get("manual-windows-process-supervision", "")
	if windows_job:
		require_exact_job_fields(
			windows_job,
			"manual-windows-process-supervision",
			("name", "if", "needs", "runs-on", "timeout-minutes", "steps"),
			issues,
		)
		require_exact_job_scalar(
			windows_job,
			"manual-windows-process-supervision",
			"name",
			"GF manual process supervision (Windows)",
			issues,
		)
		require_exact_job_scalar(
			windows_job,
			"manual-windows-process-supervision",
			"if",
			MANUAL_MAIN_EVENT,
			issues,
		)
		require_exact_job_needs(
			windows_job,
			"manual-windows-process-supervision",
			("manual-repository-policy",),
			issues,
		)
		require_exact_job_scalar(
			windows_job,
			"manual-windows-process-supervision",
			"runs-on",
			"windows-latest",
			issues,
		)
		require_exact_run_step(
			windows_job,
			"manual-windows-process-supervision",
			"Verify owned process-tree cleanup",
			WINDOWS_PROCESS_SELF_TEST_COMMAND,
			issues,
		)
	gate_job = jobs.get("manual-diagnostics-gate", "")
	if gate_job:
		require_exact_job_scalar(
			gate_job,
			"manual-diagnostics-gate",
			"name",
			"GF manual diagnostics gate",
			issues,
		)
		require_exact_job_scalar(
			gate_job,
			"manual-diagnostics-gate",
			"if",
			"!cancelled() && " + MANUAL_MAIN_EVENT,
			issues,
		)
		require_exact_job_needs(
			gate_job,
			"manual-diagnostics-gate",
			(
				"manual-repository-policy",
				"manual-full-validation",
				"manual-windows-process-supervision",
			),
			issues,
		)
	return issues


def audit_release_workflow(source: str) -> list[str]:
	issues: list[str] = []
	actual_top_level_fields = extract_yaml_direct_mapping_keys(source, 0)
	expected_top_level_fields = ["name", "on", "permissions", "concurrency", "jobs"]
	if actual_top_level_fields != expected_top_level_fields:
		issues.append(
			"Release top-level fields are "
			f"{actual_top_level_fields!r}, expected {expected_top_level_fields!r}."
		)
	expected_release_trigger = (
		"on:\n"
		"  push:\n"
		"    tags:\n"
		'      - "[0-9]*.[0-9]*.[0-9]*"'
	)
	if extract_yaml_top_level_block(source, "on").rstrip("\r\n") != expected_release_trigger:
		issues.append("Release trigger must remain the exact governed stable-tag push filter.")
	expected_release_concurrency = (
		"concurrency:\n"
		"  group: release-${{ github.ref_name }}\n"
		"  cancel-in-progress: false"
	)
	if extract_yaml_top_level_block(source, "concurrency").rstrip("\r\n") != expected_release_concurrency:
		issues.append("Release concurrency must remain tag-scoped and non-cancelling.")
	permissions_source = extract_yaml_top_level_block(source, "permissions")
	top_level_permission_keys = extract_yaml_mapping_keys(source, "permissions", 0)
	if top_level_permission_keys != ["contents"]:
		issues.append("Release top-level permissions must contain only contents: read.")
	if extract_yaml_scalar(permissions_source, "contents", 2) != "read":
		issues.append("Release top-level permission contents must be read.")
	jobs, duplicate_jobs = extract_ci_job_blocks(source)
	reject_failure_tolerant_jobs_and_steps(jobs, "Release", issues)
	if duplicate_jobs:
		issues.append(f"Release workflow has duplicate job ids: {', '.join(sorted(duplicate_jobs))}.")
	required_job_ids = {
		"build-release-artifacts",
		"release-framework-checks",
		"release-package-checks",
		"create-release",
	}
	missing_job_ids = sorted(required_job_ids - set(jobs))
	if missing_job_ids:
		issues.append(f"Release workflow is missing governed jobs: {', '.join(missing_job_ids)}.")
	extra_job_ids = sorted(set(jobs) - required_job_ids)
	if extra_job_ids:
		issues.append(f"Release workflow has unsupported jobs: {', '.join(extra_job_ids)}.")
	expected_job_fields = {
		"build-release-artifacts": ("name", "runs-on", "timeout-minutes", "steps"),
		"release-framework-checks": ("name", "runs-on", "timeout-minutes", "steps"),
		"release-package-checks": ("name", "runs-on", "timeout-minutes", "strategy", "steps"),
		"create-release": ("name", "permissions", "needs", "runs-on", "timeout-minutes", "steps"),
	}
	for job_id, expected_fields in expected_job_fields.items():
		if job_id in jobs:
			require_exact_job_fields(jobs[job_id], job_id, expected_fields, issues)
	release_step_names = {
		"build-release-artifacts": (
			"Checkout tag", "Set up Python", "Build release artifact set",
			"Verify release metadata against built artifacts",
			"Upload immutable release artifact set",
		),
		"release-framework-checks": (
			"Checkout tag", "Set up Python", "Install documentation dependencies",
			"Set up Godot", "Run release framework shard",
		),
		"release-package-checks": (
			"Checkout tag", "Set up Python", "Set up Godot", "Run release package shard",
		),
		"create-release": (
			"Checkout tag", "Set up Python", "Download verified release artifact set",
			"Verify downloaded release artifact set", "Extract release notes", "Create release",
		),
	}
	for job_id, expected_names in release_step_names.items():
		if job_id in jobs:
			require_exact_step_names(jobs[job_id], job_id, expected_names, issues)
	for job_id, job_source in jobs.items():
		permission_keys = extract_yaml_mapping_keys(job_source, "permissions", 4)
		contents_permission = extract_yaml_scalar(job_source, "contents", 6)
		if job_id == "create-release":
			if permission_keys != ["contents"] or contents_permission != "write":
				issues.append("Release job create-release permission contents must be the only job permission and must be write.")
			continue
		if contents_permission == "write":
			issues.append(f"Release job {job_id} permission contents must not be write.")
		if permission_keys and (permission_keys != ["contents"] or contents_permission != "read"):
			issues.append(f"Release job {job_id} may only narrow its permissions to contents: read.")
	if "create-release" not in jobs:
		issues.append("Release workflow is missing create-release job.")
	framework_job = jobs.get("release-framework-checks", "")
	if not framework_job:
		issues.append("Release workflow is missing release-framework-checks job.")
	else:
		actual_framework_job_fields = extract_ci_job_field_keys(framework_job)
		expected_framework_job_fields = ["name", "runs-on", "timeout-minutes", "steps"]
		if actual_framework_job_fields != expected_framework_job_fields:
			issues.append(
				"Release job release-framework-checks fields are "
				f"{actual_framework_job_fields!r}, expected {expected_framework_job_fields!r}."
			)
		require_exact_job_scalar(
			framework_job,
			"release-framework-checks",
			"timeout-minutes",
			str(RELEASE_FRAMEWORK_TIMEOUT_MINUTES),
			issues,
		)
		release_framework_step = extract_ci_step_block(
			framework_job,
			"Run release framework shard",
		)
		actual_release_step_fields = extract_ci_step_field_keys(release_framework_step)
		if actual_release_step_fields != ["run"]:
			issues.append(
				"Release job release-framework-checks Run release framework shard fields "
				f"are {actual_release_step_fields!r}, expected ['run']."
			)
		actual_release_command = extract_yaml_scalar(release_framework_step, "run", 8)
		if actual_release_command != RELEASE_FRAMEWORK_COMMAND:
			issues.append(
				"Release job release-framework-checks Run release framework shard command "
				f"is {actual_release_command!r}, expected {RELEASE_FRAMEWORK_COMMAND!r}."
			)
	package_job = jobs.get("release-package-checks", "")
	if package_job:
		require_exact_matrix_suites(
			package_job,
			"release-package-checks",
			RELEASE_PACKAGE_SUITES,
			issues,
		)
		require_exact_run_step(
			package_job,
			"release-package-checks",
			"Run release package shard",
			PACKAGE_CI_COMMAND,
			issues,
		)
	create_release_job = jobs.get("create-release", "")
	if create_release_job:
		require_exact_job_needs(
			create_release_job,
			"create-release",
			("build-release-artifacts", "release-framework-checks", "release-package-checks"),
			issues,
		)
		require_exact_run_step(
			create_release_job,
			"create-release",
			"Verify downloaded release artifact set",
			RELEASE_VERIFY_ARTIFACT_COMMAND,
			issues,
		)
		require_exact_run_step(
			create_release_job,
			"create-release",
			"Extract release notes",
			RELEASE_EXTRACT_NOTES_COMMAND,
			issues,
		)
		create_step = extract_ci_step_block(create_release_job, "Create release")
		create_step_fields = extract_ci_step_field_keys(create_step)
		if create_step_fields != ["env", "run"]:
			issues.append(
				"CI job create-release Create release fields are "
				f"{create_step_fields!r}, expected ['env', 'run']."
			)
		create_env_keys = extract_yaml_mapping_keys(create_step, "env", 8)
		create_token = extract_yaml_scalar(create_step, "GITHUB_TOKEN", 10)
		if create_env_keys != ["GITHUB_TOKEN"] or create_token != "${{ secrets.GITHUB_TOKEN }}":
			issues.append(
				"CI job create-release Create release environment must contain only the governed GITHUB_TOKEN."
			)
		create_command = extract_yaml_scalar(create_step, "run", 8)
		if create_command != RELEASE_CREATE_COMMAND:
			issues.append(
				"CI job create-release Create release command is "
				f"{create_command!r}, expected {RELEASE_CREATE_COMMAND!r}."
			)
	return issues


def audit_ci_workflow(policy: dict[str, Any], source: str) -> list[str]:
	issues: list[str] = []
	actual_top_level_fields = extract_yaml_direct_mapping_keys(source, 0)
	expected_top_level_fields = ["name", "run-name", "on", "permissions", "concurrency", "jobs"]
	if actual_top_level_fields != expected_top_level_fields:
		issues.append(
			"CI top-level fields are "
			f"{actual_top_level_fields!r}, expected {expected_top_level_fields!r}."
		)
	jobs, duplicate_jobs = extract_ci_job_blocks(source)
	reject_failure_tolerant_jobs_and_steps(jobs, "CI", issues)
	if duplicate_jobs:
		issues.append(f"CI workflow has duplicate job ids: {', '.join(sorted(duplicate_jobs))}.")
	required_job_ids = {
		"repository-policy",
		"quick-checks",
		"framework-checks",
		"package-checks",
		"windows-process-supervision",
		"draft-gate",
		"full-validation-gate",
		"merge-gate",
	}
	missing_job_ids = sorted(required_job_ids - set(jobs))
	if missing_job_ids:
		issues.append(f"CI workflow is missing governed jobs: {', '.join(missing_job_ids)}.")
	extra_job_ids = sorted(set(jobs) - required_job_ids)
	if extra_job_ids:
		issues.append(f"CI workflow has unsupported jobs: {', '.join(extra_job_ids)}.")
	expected_job_fields = {
		"repository-policy": ("name", "runs-on", "timeout-minutes", "steps"),
		"quick-checks": ("name", "if", "needs", "runs-on", "timeout-minutes", "steps"),
		"framework-checks": (
			"name", "if", "needs", "runs-on", "timeout-minutes", "strategy", "steps",
		),
		"package-checks": (
			"name", "if", "needs", "runs-on", "timeout-minutes", "strategy", "steps",
		),
		"windows-process-supervision": (
			"name", "if", "needs", "runs-on", "timeout-minutes", "steps",
		),
		"draft-gate": ("name", "if", "needs", "runs-on", "timeout-minutes", "steps"),
		"full-validation-gate": (
			"name", "if", "needs", "runs-on", "timeout-minutes", "steps",
		),
		"merge-gate": (
			"name", "if", "permissions", "needs", "runs-on", "timeout-minutes", "steps",
		),
	}
	for job_id, expected_fields in expected_job_fields.items():
		if job_id in jobs:
			require_exact_job_fields(jobs[job_id], job_id, expected_fields, issues)
	ci_step_names = {
		"repository-policy": (
			"Checkout", "Set up Python", "Validate repository policy",
			"Validate pull request contract",
		),
		"quick-checks": ("Checkout", "Set up Python", "Run quick maintenance suite"),
		"framework-checks": (
			"Checkout", "Set up Python", "Install documentation dependencies",
			"Set up Godot", "Run framework maintenance shard",
		),
		"package-checks": ("Checkout", "Set up Python", "Set up Godot", "Run package maintenance shard"),
		"windows-process-supervision": (
			"Checkout", "Set up Python", "Verify owned process-tree cleanup",
			"Verify Windows staging and startup boundaries",
		),
		"draft-gate": ("Evaluate Draft checks",),
		"full-validation-gate": ("Evaluate Full validation",),
		"merge-gate": (
			"Evaluate repository policy", "Evaluate current Full validation",
			"Checkout relay policy", "Set up Python for relay",
			"Reuse the latest matching Full validation epoch",
		),
	}
	for job_id, expected_names in ci_step_names.items():
		if job_id in jobs:
			require_exact_step_names(jobs[job_id], job_id, expected_names, issues)

	pull_request_source = extract_yaml_mapping_block(source, "on", 0, "pull_request", 2)
	if extract_yaml_mapping_keys(pull_request_source, "pull_request", 2) != ["types"]:
		issues.append("CI pull_request trigger must contain only types.")
	pull_request_types = extract_yaml_list(pull_request_source, "types", 4)
	expected_pull_request_types = [
		"opened",
		"synchronize",
		"reopened",
		"edited",
		"ready_for_review",
		"converted_to_draft",
	]
	if pull_request_types != expected_pull_request_types:
		issues.append(
			"CI pull_request.types is "
			f"{pull_request_types!r}, expected {expected_pull_request_types!r}."
		)
	push_source = extract_yaml_mapping_block(source, "on", 0, "push", 2)
	if extract_yaml_mapping_keys(push_source, "push", 2) != ["branches"]:
		issues.append("CI push trigger must contain only branches.")
	push_branches = extract_yaml_list(push_source, "branches", 4)
	expected_push_branches = [str(policy["default_branch"])]
	if push_branches != expected_push_branches:
		issues.append(
			f"CI push.branches is {push_branches!r}, expected {expected_push_branches!r}."
		)
	workflow_dispatch_source = extract_yaml_mapping_block(source, "on", 0, "workflow_dispatch", 2)
	if workflow_dispatch_source:
		issues.append("Required CI must not expose workflow_dispatch; manual diagnostics belong to ci-manual.yml.")
	if extract_yaml_mapping_keys(source, "on", 0) != ["pull_request", "push"]:
		issues.append("Required CI triggers must contain only pull_request and push.")
	if extract_yaml_scalar(source, "run-name", 0) != CI_RUN_NAME:
		issues.append("CI run-name must freeze the governed mode, pull request, head SHA, and base SHA epoch.")
	permissions_source = extract_yaml_top_level_block(source, "permissions")
	if extract_yaml_mapping_keys(source, "permissions", 0) != ["contents"]:
		issues.append("CI top-level permissions must contain only contents: read.")
	if extract_yaml_scalar(permissions_source, "contents", 2) != "read":
		issues.append("CI top-level permission contents must be read.")
	for permission_name in ("actions", "checks", "pull-requests"):
		if extract_yaml_scalar(permissions_source, permission_name, 2):
			issues.append(
				f"CI top-level permission {permission_name} must remain unset; "
				"metadata relay access belongs only to merge-gate."
			)
	concurrency_source = extract_yaml_top_level_block(source, "concurrency")
	if extract_yaml_mapping_keys(source, "concurrency", 0) != ["group", "cancel-in-progress"]:
		issues.append("CI concurrency must contain only group and cancel-in-progress.")
	concurrency_group = extract_yaml_scalar(concurrency_source, "group", 2)
	if concurrency_group != METADATA_CONCURRENCY_GROUP:
		issues.append("CI concurrency.group must isolate metadata-only policy runs from source validation runs.")
	if extract_yaml_scalar(concurrency_source, "cancel-in-progress", 2) != "true":
		issues.append("CI concurrency.cancel-in-progress must remain true.")

	repository_job = jobs.get("repository-policy", "")
	if repository_job:
		require_exact_job_scalar(repository_job, "repository-policy", "name", REPOSITORY_POLICY_NAME, issues)
		require_exact_run_step(
			repository_job,
			"repository-policy",
			"Validate repository policy",
			REPOSITORY_POLICY_COMMAND,
			issues,
		)
		pull_request_step = extract_ci_step_block(repository_job, "Validate pull request contract")
		pull_request_fields = extract_ci_step_field_keys(pull_request_step)
		if pull_request_fields != ["if", "env", "run"]:
			issues.append(
				"CI job repository-policy Validate pull request contract fields are "
				f"{pull_request_fields!r}, expected ['if', 'env', 'run']."
			)
		if extract_yaml_scalar(pull_request_step, "if", 8) != "github.event_name == 'pull_request'":
			issues.append("CI job repository-policy Validate pull request contract condition is not governed.")
		pull_request_env_keys = extract_yaml_mapping_keys(pull_request_step, "env", 8)
		pull_request_head_repository = extract_yaml_scalar(
			pull_request_step,
			"GF_HEAD_REPOSITORY",
			10,
		)
		if (
			pull_request_env_keys != ["GF_HEAD_REPOSITORY"]
			or pull_request_head_repository != "${{ github.event.pull_request.head.repo.full_name }}"
		):
			issues.append(
				"CI job repository-policy Validate pull request contract environment is not governed."
			)
		if extract_yaml_scalar(pull_request_step, "run", 8) != PULL_REQUEST_POLICY_COMMAND:
			issues.append("CI job repository-policy Validate pull request contract command is not governed.")

	quick_job = jobs.get("quick-checks", "")
	if quick_job:
		require_exact_job_scalar(quick_job, "quick-checks", "name", "GF draft quick checks", issues)
		require_exact_job_scalar(
			quick_job,
			"quick-checks",
			"if",
			"github.event_name == 'pull_request' && github.event.pull_request.draft == true && "
			"(github.event.action != 'edited' || github.event.changes.base.ref.from != '')",
			issues,
		)
		require_exact_job_needs(quick_job, "quick-checks", ("repository-policy",), issues)
		require_exact_run_step(
			quick_job,
			"quick-checks",
			"Run quick maintenance suite",
			QUICK_CI_COMMAND,
			issues,
		)

	ready_job_if = FULL_VALIDATION_EVENT
	framework_job = jobs.get("framework-checks", "")
	if framework_job:
		require_exact_job_fields(
			framework_job,
			"framework-checks",
			("name", "if", "needs", "runs-on", "timeout-minutes", "strategy", "steps"),
			issues,
		)
		require_exact_job_scalar(framework_job, "framework-checks", "if", ready_job_if, issues)
		require_exact_job_needs(framework_job, "framework-checks", ("repository-policy",), issues)
		require_exact_job_scalar(
			framework_job,
			"framework-checks",
			"timeout-minutes",
			"${{ matrix.timeout_minutes }}",
			issues,
		)
		require_exact_matrix_suites(framework_job, "framework-checks", FRAMEWORK_CI_SUITES, issues)
		require_exact_matrix_suite_scalar(
			framework_job,
			"framework-checks",
			"framework-gut",
			"timeout_minutes",
			str(FRAMEWORK_GUT_CI_TIMEOUT_MINUTES),
			issues,
		)
		require_exact_run_step(
			framework_job,
			"framework-checks",
			"Run framework maintenance shard",
			FRAMEWORK_CI_COMMAND,
			issues,
		)

	package_job = jobs.get("package-checks", "")
	if package_job:
		require_exact_job_scalar(package_job, "package-checks", "if", ready_job_if, issues)
		require_exact_job_needs(package_job, "package-checks", ("repository-policy",), issues)
		require_exact_matrix_suites(package_job, "package-checks", PACKAGE_CI_SUITES, issues)
		require_exact_run_step(
			package_job,
			"package-checks",
			"Run package maintenance shard",
			PACKAGE_CI_COMMAND,
			issues,
		)

	windows_process_job = jobs.get("windows-process-supervision", "")
	if windows_process_job:
		require_exact_job_fields(
			windows_process_job,
			"windows-process-supervision",
			("name", "if", "needs", "runs-on", "timeout-minutes", "steps"),
			issues,
		)
		require_exact_job_scalar(
			windows_process_job,
			"windows-process-supervision",
			"name",
			"GF process supervision (Windows)",
			issues,
		)
		require_exact_job_scalar(
			windows_process_job,
			"windows-process-supervision",
			"if",
			ready_job_if,
			issues,
		)
		require_exact_job_needs(
			windows_process_job,
			"windows-process-supervision",
			("repository-policy",),
			issues,
		)
		require_exact_job_scalar(
			windows_process_job,
			"windows-process-supervision",
			"runs-on",
			"windows-latest",
			issues,
		)
		require_exact_run_step(
			windows_process_job,
			"windows-process-supervision",
			"Verify owned process-tree cleanup",
			WINDOWS_PROCESS_SELF_TEST_COMMAND,
			issues,
		)
		windows_staging_step = extract_ci_step_block(
			windows_process_job,
			"Verify Windows staging and startup boundaries",
		)
		actual_windows_staging_fields = extract_ci_step_field_keys(windows_staging_step)
		if actual_windows_staging_fields != ["run"]:
			issues.append(
				"CI job windows-process-supervision Windows staging/startup step fields "
				f"are {actual_windows_staging_fields!r}, expected ['run']."
			)
		expected_windows_staging_command = WINDOWS_STAGING_TEST_COMMAND
		actual_windows_staging_command = extract_yaml_scalar(windows_staging_step, "run", 8)
		if actual_windows_staging_command != expected_windows_staging_command:
			issues.append(
				"CI job windows-process-supervision Windows staging/startup command "
				f"is {actual_windows_staging_command!r}, expected "
				f"{expected_windows_staging_command!r}."
			)
		require_job_code(
			windows_process_job,
			"windows-process-supervision",
			"tests.gf_core.tools.test_gf_parallel_validation",
			issues,
		)
		require_job_code(
			windows_process_job,
			"windows-process-supervision",
			"tests.gf_core.tools.test_gf_maintenance_check_graph",
			issues,
		)

	draft_gate = jobs.get("draft-gate", "")
	if draft_gate:
		require_exact_job_scalar(draft_gate, "draft-gate", "name", DRAFT_GATE_NAME, issues)
		require_exact_job_scalar(
			draft_gate,
			"draft-gate",
			"if",
			"!cancelled() && github.event_name == 'pull_request' && "
			"github.event.pull_request.draft == true && "
			"(github.event.action != 'edited' || github.event.changes.base.ref.from != '')",
			issues,
		)
		require_exact_job_needs(draft_gate, "draft-gate", ("repository-policy", "quick-checks"), issues)
		require_exact_gate_evaluator(
			draft_gate,
			"draft-gate",
			"Evaluate Draft checks",
			(
				("POLICY_RESULT", "${{ needs.repository-policy.result }}", "Repository policy failed"),
				("QUICK_RESULT", "${{ needs.quick-checks.result }}", "Draft quick checks failed"),
			),
			issues,
		)

	full_validation_gate = jobs.get("full-validation-gate", "")
	if full_validation_gate:
		require_exact_job_scalar(
			full_validation_gate,
			"full-validation-gate",
			"name",
			FULL_VALIDATION_GATE_NAME,
			issues,
		)
		require_exact_job_scalar(
			full_validation_gate,
			"full-validation-gate",
			"if",
			"!cancelled() && (" + FULL_VALIDATION_EVENT + ")",
			issues,
		)
		require_exact_job_needs(
			full_validation_gate,
			"full-validation-gate",
			(
				"repository-policy",
				"framework-checks",
				"package-checks",
				"windows-process-supervision",
			),
			issues,
		)
		require_exact_gate_evaluator(
			full_validation_gate,
			"full-validation-gate",
			"Evaluate Full validation",
			(
				("POLICY_RESULT", "${{ needs.repository-policy.result }}", "Repository policy failed"),
				("FRAMEWORK_RESULT", "${{ needs.framework-checks.result }}", "Framework checks failed"),
				("PACKAGE_RESULT", "${{ needs.package-checks.result }}", "Package checks failed"),
				(
					"WINDOWS_PROCESS_RESULT",
					"${{ needs.windows-process-supervision.result }}",
					"Windows process supervision failed",
				),
			),
			issues,
		)

	merge_gate = jobs.get("merge-gate", "")
	if merge_gate:
		require_exact_job_scalar(merge_gate, "merge-gate", "name", MERGE_GATE_NAME, issues)
		require_exact_job_scalar(
			merge_gate,
			"merge-gate",
			"if",
			"always() && (" + REQUIRED_GATE_EVENT + ")",
			issues,
		)
		require_exact_job_needs(
			merge_gate,
			"merge-gate",
			(
				"repository-policy",
				"full-validation-gate",
			),
			issues,
		)
		if extract_yaml_mapping_keys(merge_gate, "permissions", 4) != [
			"actions",
			"checks",
			"contents",
			"pull-requests",
		]:
			issues.append("CI job merge-gate permissions must contain only the governed read scopes.")
		for permission_name in ("actions", "checks", "contents", "pull-requests"):
			if extract_yaml_scalar(merge_gate, permission_name, 6) != "read":
				issues.append(f"CI job merge-gate permission {permission_name} must be read.")
		require_exact_gate_evaluator(
			merge_gate,
			"merge-gate",
			"Evaluate repository policy",
			(("POLICY_RESULT", "${{ needs.repository-policy.result }}", "Repository policy failed"),),
			issues,
		)
		current_full_step = extract_ci_step_block(merge_gate, "Evaluate current Full validation")
		if extract_ci_step_field_keys(current_full_step) != ["if", "env", "run"]:
			issues.append("CI job merge-gate current Full evaluator fields are not governed.")
		if extract_yaml_scalar(current_full_step, "if", 8) != CURRENT_FULL_STEP_IF:
			issues.append("CI job merge-gate current Full evaluator condition is not governed.")
		if extract_yaml_mapping_keys(current_full_step, "env", 8) != ["FULL_VALIDATION_RESULT"]:
			issues.append("CI job merge-gate current Full evaluator environment is not governed.")
		if extract_yaml_scalar(current_full_step, "FULL_VALIDATION_RESULT", 10) != "${{ needs.full-validation-gate.result }}":
			issues.append("CI job merge-gate current Full evaluator result binding is not governed.")
		expected_full_evaluator = (
			'if [ "${FULL_VALIDATION_RESULT}" != "success" ]; then '
			'echo "Full validation failed: ${FULL_VALIDATION_RESULT}" exit 1 fi'
		)
		if extract_yaml_scalar(current_full_step, "run", 8) != expected_full_evaluator:
			issues.append("CI job merge-gate current Full evaluator command is not governed.")
		expected_current_full_lines = [
			"      - name: Evaluate current Full validation",
			"        if: >-",
			"          success() &&",
			"          (github.event_name == 'push' ||",
			"          (github.event_name == 'pull_request' &&",
			"          (github.event.action != 'edited' || github.event.changes.base.ref.from != '')))",
			"        env:",
			"          FULL_VALIDATION_RESULT: ${{ needs.full-validation-gate.result }}",
			"        run: |",
			'          if [ "${FULL_VALIDATION_RESULT}" != "success" ]; then',
			'            echo "Full validation failed: ${FULL_VALIDATION_RESULT}"',
			"            exit 1",
			"          fi",
		]
		if current_full_step.rstrip("\r\n").splitlines() != expected_current_full_lines:
			issues.append(
				"CI job merge-gate current Full evaluator must match the canonical literal script."
			)
		checkout_step = extract_ci_step_block(merge_gate, "Checkout relay policy")
		if extract_ci_step_field_keys(checkout_step) != ["if", "uses"]:
			issues.append("CI job merge-gate relay checkout fields are not governed.")
		if extract_yaml_scalar(checkout_step, "if", 8) != METADATA_RELAY_STEP_IF:
			issues.append("CI job merge-gate relay checkout condition is not governed.")
		if extract_yaml_scalar(checkout_step, "uses", 8) != "actions/checkout@v7":
			issues.append("CI job merge-gate relay checkout action is not governed.")
		setup_step = extract_ci_step_block(merge_gate, "Set up Python for relay")
		if extract_ci_step_field_keys(setup_step) != ["if", "uses", "with"]:
			issues.append("CI job merge-gate relay Python setup fields are not governed.")
		if extract_yaml_scalar(setup_step, "if", 8) != METADATA_RELAY_STEP_IF:
			issues.append("CI job merge-gate relay Python setup condition is not governed.")
		if extract_yaml_scalar(setup_step, "uses", 8) != "actions/setup-python@v7":
			issues.append("CI job merge-gate relay Python setup action is not governed.")
		if extract_yaml_mapping_keys(setup_step, "with", 8) != ["python-version"]:
			issues.append("CI job merge-gate relay Python setup inputs are not governed.")
		if extract_yaml_scalar(setup_step, "python-version", 10) != '"3.12"':
			issues.append("CI job merge-gate relay Python version is not governed.")
		relay_step = extract_ci_step_block(
			merge_gate,
			"Reuse the latest matching Full validation epoch",
		)
		if extract_ci_step_field_keys(relay_step) != ["if", "env", "run"]:
			issues.append("CI job merge-gate relay fields are not governed.")
		if extract_yaml_scalar(relay_step, "if", 8) != METADATA_RELAY_STEP_IF:
			issues.append("CI job merge-gate relay condition is not governed.")
		expected_relay_env = ["GH_TOKEN", "GF_PR_NUMBER", "GF_PR_HEAD_SHA", "GF_PR_BASE_SHA"]
		if extract_yaml_mapping_keys(relay_step, "env", 8) != expected_relay_env:
			issues.append("CI job merge-gate relay environment fields are not governed.")
		for field_name, expected_value in (
			("GH_TOKEN", "${{ github.token }}"),
			("GF_PR_NUMBER", "${{ github.event.pull_request.number }}"),
			("GF_PR_HEAD_SHA", "${{ github.event.pull_request.head.sha }}"),
			("GF_PR_BASE_SHA", "${{ github.event.pull_request.base.sha }}"),
		):
			if extract_yaml_scalar(relay_step, field_name, 10) != expected_value:
				issues.append(f"CI job merge-gate relay {field_name} binding is not governed.")
		if extract_yaml_scalar(relay_step, "run", 8) != METADATA_RELAY_COMMAND:
			issues.append("CI job merge-gate relay command is not governed.")

	configured_checks = policy.get("required_status_checks")
	if isinstance(configured_checks, list):
		workflow_check_names = {
			"GF repository policy" if extract_yaml_scalar(repository_job, "name", 4) == REPOSITORY_POLICY_NAME else "",
			"GF merge gate" if extract_yaml_scalar(merge_gate, "name", 4) == MERGE_GATE_NAME else "",
		}
		for check_name in configured_checks:
			if isinstance(check_name, str) and check_name not in workflow_check_names:
				issues.append(f"CI workflow does not emit required status check {check_name!r} from its governed job.")
	return issues


def extract_ci_job_blocks(source: str) -> tuple[dict[str, str], set[str]]:
	jobs_source = extract_yaml_top_level_block(source, "jobs")
	if not jobs_source:
		return {}, set()
	lines = jobs_source.splitlines()
	blocks: dict[str, list[str]] = {}
	duplicates: set[str] = set()
	current_job = ""
	for index, line in enumerate(lines[1:], start=1):
		code = strip_yaml_comment(line)
		indent = len(code) - len(code.lstrip(" ")) if code else -1
		match = re.fullmatch(r"  ([A-Za-z0-9_-]+):\s*", code)
		if match is not None:
			current_job = match.group(1)
			if current_job in blocks:
				duplicates.add(current_job)
			else:
				blocks[current_job] = [line]
			continue
		if code and indent == 2:
			# Governed workflow job ids intentionally use one canonical unquoted
			# spelling. Treat quoted, explicit-key, flow, and otherwise unsupported
			# direct mappings as real extra jobs instead of dropping their blocks.
			current_job = f"<unparsed-job-{index}>"
			blocks[current_job] = [line]
			continue
		if current_job:
			blocks[current_job].append(line)
	return {job_id: "\n".join(lines) for job_id, lines in blocks.items()}, duplicates


def extract_ci_step_block(job_source: str, step_name: str) -> str:
	lines = job_source.splitlines()
	steps_indices = [
		index for index, line in enumerate(lines)
		if re.fullmatch(r"    steps:\s*", strip_yaml_comment(line)) is not None
	]
	if len(steps_indices) != 1:
		return ""
	steps_start = steps_indices[0]
	steps_end = len(lines)
	for index in range(steps_start + 1, len(lines)):
		code = strip_yaml_comment(lines[index])
		if code and len(code) - len(code.lstrip(" ")) <= 4:
			steps_end = index
			break
	start = -1
	prefix = "      - name: "
	for index in range(steps_start + 1, steps_end):
		line = lines[index]
		if strip_yaml_comment(line) == prefix + step_name:
			if start >= 0:
				return ""
			start = index
	if start < 0:
		return ""
	end = steps_end
	for index in range(start + 1, steps_end):
		if re.match(r"^      -\s+", strip_yaml_comment(lines[index])) is not None:
			end = index
			break
	return "\n".join(lines[start:end])


def extract_ci_step_names(job_source: str) -> list[str]:
	"""Return the canonical ordered direct step names for one governed job."""
	lines = job_source.splitlines()
	steps_indices = [
		index for index, line in enumerate(lines)
		if re.fullmatch(r"    steps:\s*", strip_yaml_comment(line)) is not None
	]
	if len(steps_indices) != 1:
		return []
	result: list[str] = []
	for line in lines[steps_indices[0] + 1:]:
		code = strip_yaml_comment(line)
		indent = len(code) - len(code.lstrip(" ")) if code else -1
		if code and indent <= 4:
			break
		if code and indent == 6:
			match = re.fullmatch(r"      - name:\s+(\S(?:.*\S)?)", code)
			if match is None:
				return ["<unparsed>"]
			result.append(match.group(1))
	return result


def require_exact_step_names(
	job_source: str,
	job_id: str,
	expected: tuple[str, ...],
	issues: list[str],
) -> None:
	actual = extract_ci_step_names(job_source)
	if actual != list(expected):
		issues.append(
			f"CI job {job_id} step names are {actual!r}, expected {list(expected)!r}."
		)


def extract_yaml_direct_mapping_keys(source: str, indent: int) -> list[str]:
	"""Return direct YAML mapping keys, failing closed on unsupported spellings."""
	keys: list[str] = []
	prefix = " " * indent
	for line in source.splitlines():
		code = strip_yaml_comment(line)
		if not code or len(code) - len(code.lstrip(" ")) != indent:
			continue
		match = re.fullmatch(
			rf'''{re.escape(prefix)}(?:([A-Za-z0-9_-]+)|'([A-Za-z0-9_-]+)'|"([A-Za-z0-9_-]+)"):(?:\s*.*?)?''',
			code,
		)
		keys.append(
			next((group for group in match.groups() if group is not None), "<unparsed>")
			if match is not None
			else "<unparsed>"
		)
	return keys


def extract_ci_step_field_keys(step_source: str) -> list[str]:
	"""Return exact top-level fields on one named CI step, excluding its name."""
	return extract_yaml_direct_mapping_keys("\n".join(step_source.splitlines()[1:]), 8)


def extract_ci_job_field_keys(job_source: str) -> list[str]:
	"""Return direct mapping fields on one CI job, excluding its job id."""
	return extract_yaml_direct_mapping_keys("\n".join(job_source.splitlines()[1:]), 4)


def extract_yaml_top_level_block(source: str, key: str) -> str:
	lines = source.splitlines()
	start = -1
	for index, line in enumerate(lines):
		if re.fullmatch(rf"{re.escape(key)}:\s*", strip_yaml_comment(line)) is not None:
			start = index
			break
	if start < 0:
		return ""
	end = len(lines)
	for index in range(start + 1, len(lines)):
		line = strip_yaml_comment(lines[index])
		if line and not line.startswith((" ", "\t")):
			end = index
			break
	return "\n".join(lines[start:end])


def extract_yaml_mapping_block(
	source: str,
	parent_key: str,
	parent_indent: int,
	child_key: str,
	child_indent: int,
) -> str:
	parent_source = (
		extract_yaml_top_level_block(source, parent_key)
		if parent_indent == 0
		else source
	)
	if not parent_source:
		return ""
	lines = parent_source.splitlines()
	prefix = " " * child_indent
	start = -1
	for index, line in enumerate(lines):
		if re.fullmatch(rf"{re.escape(prefix + child_key)}:\s*", strip_yaml_comment(line)) is not None:
			start = index
			break
	if start < 0:
		return ""
	end = len(lines)
	for index in range(start + 1, len(lines)):
		code = strip_yaml_comment(lines[index])
		if code and len(code) - len(code.lstrip(" ")) <= child_indent:
			end = index
			break
	return "\n".join(lines[start:end])


def extract_yaml_mapping_keys(source: str, key: str, indent: int) -> list[str]:
	lines = source.splitlines()
	prefix = " " * indent
	start = -1
	for index, line in enumerate(lines):
		if re.fullmatch(rf"{re.escape(prefix + key)}:\s*", strip_yaml_comment(line)) is not None:
			if start >= 0:
				return []
			start = index
	if start < 0:
		return []
	keys: list[str] = []
	child_prefix = " " * (indent + 2)
	for line in lines[start + 1:]:
		code = strip_yaml_comment(line)
		code_indent = len(code) - len(code.lstrip(" ")) if code else -1
		if code and code_indent <= indent:
			break
		match = re.fullmatch(rf"{re.escape(child_prefix)}([A-Za-z0-9_-]+):(?:\s*.*?)?", code)
		if match is not None:
			keys.append(match.group(1))
		elif code and code_indent == indent + 2:
			keys.append("<unparsed>")
	return keys


def extract_yaml_scalar(source: str, key: str, indent: int) -> str:
	values: list[str] = []
	lines = source.splitlines()
	prefix = " " * indent
	for index, line in enumerate(lines):
		code = strip_yaml_comment(line)
		match = re.fullmatch(rf"{re.escape(prefix + key)}:\s*(.*?)\s*", code)
		if match is None:
			continue
		value = match.group(1)
		if value in {">", ">-", "|", "|-"}:
			parts: list[str] = []
			for continuation in lines[index + 1:]:
				# A '#' inside a YAML block scalar is shell/script data, not a YAML
				# comment. Preserve it so an exact command audit cannot be spoofed by
				# commenting out the governed continuation lines at runtime.
				continuation_code = continuation.rstrip()
				if continuation_code and len(continuation_code) - len(continuation_code.lstrip(" ")) <= indent:
					break
				if continuation_code.strip():
					parts.append(continuation_code.strip())
			value = " ".join(parts)
		values.append(" ".join(value.split()))
	return values[0] if len(values) == 1 else ""


def extract_yaml_list(source: str, key: str, indent: int) -> list[str]:
	lines = source.splitlines()
	prefix = " " * indent
	for index, line in enumerate(lines):
		if re.fullmatch(rf"{re.escape(prefix + key)}:\s*", strip_yaml_comment(line)) is None:
			continue
		values: list[str] = []
		for continuation in lines[index + 1:]:
			code = strip_yaml_comment(continuation)
			code_indent = len(code) - len(code.lstrip(" ")) if code else -1
			if code and code_indent <= indent:
				break
			match = re.fullmatch(rf"\s{{{indent + 2}}}-\s+([A-Za-z0-9_-]+)\s*", code)
			if match is not None:
				values.append(match.group(1))
			elif code and code_indent == indent + 2:
				values.append("<unparsed>")
		return values
	return []


def extract_matrix_suites(job_source: str) -> list[str]:
	items = extract_matrix_include_items(job_source)
	if not items:
		return []
	suites = [extract_yaml_scalar(item, "suite", 12) for item in items]
	if any(re.fullmatch(r"[a-z0-9][a-z0-9-]*", suite) is None for suite in suites):
		return []
	return suites


def extract_matrix_include_items(job_source: str) -> list[str]:
	"""Extract one strategy.matrix.include sequence without trusting block scalars."""
	lines = job_source.splitlines()
	strategy_indices = [
		index for index, line in enumerate(lines)
		if re.fullmatch(r"    strategy:\s*", strip_yaml_comment(line)) is not None
	]
	if len(strategy_indices) != 1:
		return []
	strategy_start = strategy_indices[0]
	strategy_end = len(lines)
	for index in range(strategy_start + 1, len(lines)):
		code = strip_yaml_comment(lines[index])
		if code and len(code) - len(code.lstrip(" ")) <= 4:
			strategy_end = index
			break
	matrix_indices = [
		index for index in range(strategy_start + 1, strategy_end)
		if re.fullmatch(r"      matrix:\s*", strip_yaml_comment(lines[index])) is not None
	]
	if len(matrix_indices) != 1:
		return []
	matrix_start = matrix_indices[0]
	matrix_end = strategy_end
	for index in range(matrix_start + 1, strategy_end):
		code = strip_yaml_comment(lines[index])
		if code and len(code) - len(code.lstrip(" ")) <= 6:
			matrix_end = index
			break
	include_indices = [
		index for index in range(matrix_start + 1, matrix_end)
		if re.fullmatch(r"        include:\s*", strip_yaml_comment(lines[index])) is not None
	]
	if len(include_indices) != 1:
		return []
	include_start = include_indices[0]
	include_end = matrix_end
	for index in range(include_start + 1, matrix_end):
		code = strip_yaml_comment(lines[index])
		if code and len(code) - len(code.lstrip(" ")) <= 8:
			include_end = index
			break
	items: list[str] = []
	current_item: list[str] = []
	for line in lines[include_start + 1:include_end]:
		code = strip_yaml_comment(line)
		item_match = re.fullmatch(r"          -(?:\s+(.*))?", code)
		if item_match is not None:
			if current_item:
				items.append("\n".join(current_item))
			first_field = item_match.group(1) or ""
			current_item = ["            " + first_field]
		elif current_item:
			current_item.append(line)
	if current_item:
		items.append("\n".join(current_item))
	return items


def extract_matrix_suite_scalar(
	job_source: str,
	suite_name: str,
	field_name: str,
) -> str:
	items = extract_matrix_include_items(job_source)
	values = [
		extract_yaml_scalar(item, field_name, 12)
		for item in items
		if extract_yaml_scalar(item, "suite", 12) == suite_name
	]
	return values[0] if len(values) == 1 else ""


def strip_yaml_comment(line: str) -> str:
	in_single_quote = False
	in_double_quote = False
	escaped = False
	for index, character in enumerate(line):
		if character == "\\" and in_double_quote and not escaped:
			escaped = True
			continue
		if character == "'" and not in_double_quote:
			in_single_quote = not in_single_quote
		elif character == '"' and not in_single_quote and not escaped:
			in_double_quote = not in_double_quote
		elif (
			character == "#"
			and not in_single_quote
			and not in_double_quote
			and (index == 0 or line[index - 1] in {" ", "\t"})
		):
			# YAML begins a plain-scalar comment only after separation whitespace.
			# A token such as ``--json#`` remains command text and must reach the
			# exact-command audit instead of being normalized into a governed value.
			return line[:index].rstrip(" \t")
		escaped = False
	return line.rstrip(" \t")


def require_exact_job_scalar(
	job_source: str,
	job_id: str,
	field_name: str,
	expected: str,
	issues: list[str],
) -> None:
	actual = extract_yaml_scalar(job_source, field_name, 4)
	if actual != expected:
		issues.append(f"CI job {job_id} {field_name} is {actual!r}, expected {expected!r}.")


def require_exact_job_fields(
	job_source: str,
	job_id: str,
	expected: tuple[str, ...],
	issues: list[str],
) -> None:
	actual = extract_ci_job_field_keys(job_source)
	if actual != list(expected):
		issues.append(f"CI job {job_id} fields are {actual!r}, expected {list(expected)!r}.")


def reject_failure_tolerant_jobs_and_steps(
	jobs: dict[str, str],
	workflow_label: str,
	issues: list[str],
) -> None:
	"""Reject GitHub's success-masking switch at every governed job/step."""
	for job_id, job_source in jobs.items():
		job_fields = extract_ci_job_field_keys(job_source)
		step_fields = extract_yaml_direct_mapping_keys(job_source, 8)
		lines = job_source.splitlines()
		steps_indices = [
			index for index, line in enumerate(lines)
			if re.fullmatch(r"    steps:\s*", strip_yaml_comment(line)) is not None
		]
		unsupported_step_item = len(steps_indices) != 1
		if len(steps_indices) == 1:
			for line in lines[steps_indices[0] + 1:]:
				code = strip_yaml_comment(line)
				if code and len(code) - len(code.lstrip(" ")) <= 4:
					break
				if code and len(code) - len(code.lstrip(" ")) == 6:
					if re.fullmatch(r"      - name:\s+\S(?:.*\S)?", code) is None:
						unsupported_step_item = True
		if "<unparsed>" in job_fields:
			issues.append(
				f"{workflow_label} job {job_id} has an unsupported direct field spelling."
			)
		if "<unparsed>" in step_fields:
			issues.append(
				f"{workflow_label} job {job_id} steps have an unsupported direct field spelling."
			)
		if unsupported_step_item:
			issues.append(
				f"{workflow_label} job {job_id} has an unsupported step item spelling."
			)
		if "continue-on-error" in job_fields:
			issues.append(
				f"{workflow_label} job {job_id} must not set continue-on-error."
			)
		if "continue-on-error" in step_fields:
			issues.append(
				f"{workflow_label} job {job_id} steps must not set continue-on-error."
			)


def require_exact_run_step(
	job_source: str,
	job_id: str,
	step_name: str,
	expected_command: str,
	issues: list[str],
) -> None:
	step_source = extract_ci_step_block(job_source, step_name)
	actual_fields = extract_ci_step_field_keys(step_source)
	if actual_fields != ["run"]:
		issues.append(
			f"CI job {job_id} {step_name} fields are {actual_fields!r}, expected ['run']."
		)
	actual_command = extract_yaml_scalar(step_source, "run", 8)
	if actual_command != expected_command:
		issues.append(
			f"CI job {job_id} {step_name} command is {actual_command!r}, "
			f"expected {expected_command!r}."
		)


def require_exact_job_needs(
	job_source: str,
	job_id: str,
	expected: tuple[str, ...],
	issues: list[str],
) -> None:
	actual = extract_yaml_list(job_source, "needs", 4)
	if actual != list(expected):
		issues.append(f"CI job {job_id} needs is {actual!r}, expected {list(expected)!r}.")


def require_exact_matrix_suite_scalar(
	job_source: str,
	job_id: str,
	suite_name: str,
	field_name: str,
	expected: str,
	issues: list[str],
) -> None:
	actual = extract_matrix_suite_scalar(job_source, suite_name, field_name)
	if actual != expected:
		issues.append(
			f"CI job {job_id} matrix suite {suite_name} {field_name} is {actual!r}, expected {expected!r}."
		)


def require_exact_matrix_suites(
	job_source: str,
	job_id: str,
	expected: tuple[str, ...],
	issues: list[str],
) -> None:
	actual = extract_matrix_suites(job_source)
	if actual != list(expected):
		issues.append(f"CI job {job_id} matrix suites are {actual!r}, expected {list(expected)!r}.")


def require_exact_gate_evaluator(
	job_source: str,
	job_id: str,
	step_name: str,
	results: tuple[tuple[str, str, str], ...],
	issues: list[str],
) -> None:
	step_source = extract_ci_step_block(job_source, step_name)
	if not step_source:
		issues.append(f"CI job {job_id} evaluator step is missing or duplicated.")
		return
	expected_lines = [
		f"      - name: {step_name}",
		"        env:",
		*(f"          {environment_name}: {expression}" for environment_name, expression, _message in results),
		"        run: |",
	]
	for environment_name, _expression, message in results:
		expected_lines.extend((
			f'          if [ "${{{environment_name}}}" != "success" ]; then',
			f'            echo "{message}: ${{{environment_name}}}"',
			"            exit 1",
			"          fi",
		))
	actual_lines = step_source.rstrip("\r\n").splitlines()
	if actual_lines != expected_lines:
		issues.append(f"CI job {job_id} evaluator must match the canonical fail-closed result mapping.")


def require_job_code(job_source: str, job_id: str, fragment: str, issues: list[str]) -> None:
	code_source = "\n".join(strip_yaml_comment(line) for line in job_source.splitlines())
	if fragment not in code_source:
		issues.append(f"CI job {job_id} is missing governed command fragment: {fragment}.")


def audit_pull_request(
	policy: dict[str, Any],
	*,
	base_ref: str,
	head_ref: str,
	repository: str,
	head_repository: str,
	source_version: str,
) -> list[str]:
	issues: list[str] = []
	expected_repository = str(policy["repository"])
	default_branch = str(policy["default_branch"])
	if repository != expected_repository:
		issues.append(f"Workflow repository must be {expected_repository}, got {repository or '<empty>'}.")
	if base_ref != default_branch:
		issues.append(f"Pull requests must target {default_branch}, got {base_ref or '<empty>'}.")
	if not head_ref:
		issues.append("Pull request head branch is empty.")
	internal_pull_request = head_repository == expected_repository
	stable_source = STABLE_SEMVER_RE.fullmatch(source_version) is not None
	development_pattern = re.compile(str(policy["development_version_pattern"]))
	if not stable_source and development_pattern.fullmatch(source_version) is None:
		issues.append(f"Pull request source version is not governed stable or development SemVer: {source_version!r}.")
	if internal_pull_request and head_ref:
		if head_ref == default_branch:
			issues.append(f"Pull request head branch cannot be {default_branch}.")
		if not branch_name_is_allowed(policy, head_ref):
			issues.append(f"Internal branch name does not match repository policy: {head_ref}")
	if stable_source and not internal_pull_request:
		issues.append("Stable source versions are allowed only on internal pull requests.")
	return issues


def branch_name_is_allowed(policy: dict[str, Any], branch_name: str) -> bool:
	patterns = [str(policy["internal_branch_pattern"]), *[str(item) for item in policy["bot_branch_patterns"]]]
	return any(re.fullmatch(pattern, branch_name) is not None for pattern in patterns)


def run_policy_self_tests(policy: dict[str, Any]) -> list[str]:
	dev_version = "9.0.0-dev.0"
	repository = str(policy["repository"])
	default_branch = str(policy["default_branch"])
	cases = (
		("valid_internal", [], audit_pull_request(policy, base_ref=default_branch, head_ref="codex/workflow-governance", repository=repository, head_repository=repository, source_version=dev_version)),
		("invalid_internal_name", ["branch"], audit_pull_request(policy, base_ref=default_branch, head_ref="workflow", repository=repository, head_repository=repository, source_version=dev_version)),
		("fork_name_exempt", [], audit_pull_request(policy, base_ref=default_branch, head_ref="My Branch", repository=repository, head_repository="contributor/fork", source_version=dev_version)),
		("fork_stable_source", ["Stable source"], audit_pull_request(policy, base_ref=default_branch, head_ref="release/8.2.0", repository=repository, head_repository="contributor/fork", source_version="8.2.0")),
		("wrong_base", ["target"], audit_pull_request(policy, base_ref="legacy", head_ref="fix/example", repository=repository, head_repository=repository, source_version=dev_version)),
		("stable_normal_branch", [], audit_pull_request(policy, base_ref=default_branch, head_ref="fix/example", repository=repository, head_repository=repository, source_version="8.2.0")),
		("stable_release_branch", [], audit_pull_request(policy, base_ref=default_branch, head_ref="release/8.2.0", repository=repository, head_repository=repository, source_version="8.2.0")),
		("malformed_source_version", ["source version"], audit_pull_request(policy, base_ref=default_branch, head_ref="fix/example", repository=repository, head_repository=repository, source_version="broken")),
	)
	issues: list[str] = []
	for name, expected_fragments, actual_issues in cases:
		if not expected_fragments and actual_issues:
			issues.append(f"Repository policy self-test {name} unexpectedly failed: {actual_issues}")
		for fragment in expected_fragments:
			if not any(fragment in issue for issue in actual_issues):
				issues.append(f"Repository policy self-test {name} did not report {fragment!r}: {actual_issues}")
	duplicate_checks_policy = json.loads(json.dumps(policy))
	duplicate_checks_policy["required_status_checks"].append(policy["required_status_checks"][0])
	if not any("duplicates" in issue for issue in audit_policy_data(duplicate_checks_policy)):
		issues.append("Repository policy self-test did not reject duplicate required status checks.")
	legacy_check_policy = json.loads(json.dumps(policy))
	legacy_check_policy["required_status_check"] = legacy_check_policy.pop("required_status_checks")[0]
	legacy_policy_issues = audit_policy_data(legacy_check_policy)
	if not any("missing fields: required_status_checks" in issue for issue in legacy_policy_issues):
		issues.append("Repository policy self-test did not reject the legacy required_status_check field.")
	repository_fixture = dict(policy["repository_settings"])
	protection = policy["branch_protection"]
	protection_fixture = {
		"required_status_checks": {
			"strict": protection["strict_status_checks"],
			"contexts": list(policy["required_status_checks"]),
			"checks": [
				{"context": required_name, "app_id": GITHUB_ACTIONS_APP_ID}
				for required_name in policy["required_status_checks"]
			],
		},
		"enforce_admins": {"enabled": protection["enforce_admins"]},
		"required_pull_request_reviews": {
			"dismiss_stale_reviews": protection["dismiss_stale_reviews"],
			"require_code_owner_reviews": protection["require_code_owner_reviews"],
			"require_last_push_approval": protection["require_last_push_approval"],
			"required_approving_review_count": protection["required_approving_review_count"],
		},
	}
	for field_name in (
		"required_linear_history",
		"required_conversation_resolution",
		"allow_force_pushes",
		"allow_deletions",
	):
		protection_fixture[field_name] = {"enabled": protection[field_name]}
	remote_issues = audit_remote_policy(policy, repository_fixture, protection_fixture)
	if remote_issues:
		issues.append(f"Repository policy self-test valid_remote unexpectedly drifted: {remote_issues}")
	drifted_fixture = json.loads(json.dumps(protection_fixture))
	drifted_fixture["allow_force_pushes"]["enabled"] = not protection["allow_force_pushes"]
	if not any("allow_force_pushes" in issue for issue in audit_remote_policy(policy, repository_fixture, drifted_fixture)):
		issues.append("Repository policy self-test did not detect force-push protection drift.")
	missing_context_fixture = json.loads(json.dumps(protection_fixture))
	missing_context_fixture["required_status_checks"]["checks"] = (
		missing_context_fixture["required_status_checks"]["checks"][1:]
	)
	if not any("required status checks" in issue for issue in audit_remote_policy(policy, repository_fixture, missing_context_fixture)):
		issues.append("Repository policy self-test did not detect a missing protected status check.")
	wrong_app_fixture = json.loads(json.dumps(protection_fixture))
	wrong_app_fixture["required_status_checks"]["checks"][0]["app_id"] = 1
	if not any("required status checks" in issue for issue in audit_remote_policy(policy, repository_fixture, wrong_app_fixture)):
		issues.append("Repository policy self-test did not detect a required status check bound to the wrong app.")
	branch_fixture = {"commit": {"sha": "0123456789abcdef"}}
	check_runs_fixture = {
		"check_runs": [
			{
				"name": required_name,
				"status": "completed",
				"conclusion": "success",
				"app": {"id": GITHUB_ACTIONS_APP_ID, "slug": "github-actions"},
			}
			for required_name in policy["required_status_checks"]
		],
	}
	if audit_required_status_checks(policy, branch_fixture, check_runs_fixture):
		issues.append("Repository policy self-test rejected successful required status checks.")
	missing_check_runs_fixture = {"check_runs": check_runs_fixture["check_runs"][1:]}
	if not audit_required_status_checks(policy, branch_fixture, missing_check_runs_fixture):
		issues.append("Repository policy self-test did not reject a missing required status check.")
	failed_check_runs_fixture = json.loads(json.dumps(check_runs_fixture))
	failed_check_runs_fixture["check_runs"][0]["conclusion"] = "failure"
	if not audit_required_status_checks(policy, branch_fixture, failed_check_runs_fixture):
		issues.append("Repository policy self-test did not reject a failing required status check.")
	not_started_context = make_protection_result_context(repository, True)
	if not_started_context["applied"] or not_started_context["completed_mutations"]:
		issues.append("Repository policy self-test reported an unstarted apply as completed.")
	partial_context = make_protection_result_context(repository, True, ["branch_protection"])
	if partial_context["applied"]:
		issues.append("Repository policy self-test reported a partial apply as completed.")
	completed_context = make_protection_result_context(
		repository,
		True,
		["branch_protection", "repository_settings"],
		verification_completed=True,
	)
	if not completed_context["applied"] or not completed_context["verification_completed"]:
		issues.append("Repository policy self-test did not report a completed and verified apply.")
	protection_payload = make_branch_protection_payload(policy)
	if protection_payload["lock_branch"] or protection_payload["allow_fork_syncing"]:
		issues.append("Repository policy self-test allowed fork syncing on an unlocked default branch.")
	expected_protected_checks = [
		{"context": required_name, "app_id": GITHUB_ACTIONS_APP_ID}
		for required_name in policy["required_status_checks"]
	]
	if (
		protection_payload["required_status_checks"]["contexts"] != []
		or protection_payload["required_status_checks"]["checks"] != expected_protected_checks
	):
		issues.append(
			"Repository policy self-test did not app-bind every governed status check in protection payload."
		)
	issues.extend(run_ci_workflow_mutation_self_tests(policy))
	issues.extend(run_manual_ci_workflow_mutation_self_tests())
	issues.extend(run_release_workflow_mutation_self_tests())
	issues.extend(run_maintenance_skill_contract_mutation_self_tests())
	issues.extend(run_full_validation_relay_self_tests(policy))
	return issues


def run_maintenance_skill_contract_mutation_self_tests() -> list[str]:
	try:
		sources = {
			path: (ROOT / path).read_text(encoding="utf-8")
			for path in MAINTENANCE_SKILL_PATHS
		}
	except (OSError, UnicodeDecodeError) as error:
		return [f"Repository policy self-test could not read maintenance skills: {error}"]
	if audit_maintenance_skill_contracts(sources):
		return []
	mutations = (
		(
			".codex/skills/gf-release-flow/references/release-checks.md",
			"check --suite release --artifact-manifest",
			"check --suite full --artifact-manifest",
			"pre-tag release-suite artifact validation",
		),
		(
			".codex/skills/gf-reference-boundary/references/reference-project.md",
			"sync_reference_project.py --check",
			"sync_reference_project.py --project-root ..\\gf-reference-project --check",
			"hard-coded reference project command",
		),
		(
			".codex/skills/gf-reference-boundary/references/reference-project.md",
			"sync_reference_project.py --apply",
			"sync_reference_project.py",
			"explicit reference sync apply command",
		),
		(
			".codex/skills/gf-change-audit/SKILL.md",
			"recompute the audit input manifest",
			"reuse the audit input manifest",
			"end-of-audit drift check",
		),
		(
			".codex/skills/gf-framework-maintenance/SKILL.md",
			"remove only logs created or rewritten by that invocation",
			"remove all managed logs after every invocation",
			"session-owned automatic log cleanup",
		),
		(
			".codex/skills/gf-framework-maintenance/references/checks.md",
			"Ready/main `framework-gut` uses exactly 60 minutes",
			"Ready/main `framework-gut` uses exactly 59 minutes",
			"Ready/main workflow deadline contract",
		),
		(
			".codex/skills/gf-framework-maintenance/references/checks.md",
			"tag-release `release-framework-checks` uses exactly 90 minutes around a 4,800-second",
			"tag-release `release-framework-checks` uses exactly 80 minutes around a 4,700-second",
			"release workflow deadline contract",
		),
		(
			".codex/skills/gf-framework-maintenance/references/checks.md",
			"manual `main` Full remains exactly 90 minutes",
			"manual `main` Full remains exactly 80 minutes",
			"manual workflow deadline contract",
		),
	)
	issues: list[str] = []
	for path, marker, replacement, expected_fragment in mutations:
		if marker not in sources[path]:
			issues.append(
				f"Repository policy self-test fixture marker is missing from maintenance skill: {path}: {marker}"
			)
			continue
		mutated_sources = dict(sources)
		mutated_sources[path] = sources[path].replace(marker, replacement, 1)
		actual_issues = audit_maintenance_skill_contracts(mutated_sources)
		if not any(expected_fragment in issue for issue in actual_issues):
			issues.append(
				"Repository policy self-test did not detect maintenance skill drift "
				f"for {path}: {actual_issues}"
			)
	return issues


def run_ci_workflow_mutation_self_tests(policy: dict[str, Any]) -> list[str]:
	try:
		source = (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8")
	except (OSError, UnicodeDecodeError) as error:
		return [f"Repository policy self-test could not read CI workflow: {error}"]
	if audit_ci_workflow(policy, source):
		return []
	jobs, duplicate_jobs = extract_ci_job_blocks(source)
	repository_job = jobs.get("repository-policy", "")
	framework_job = jobs.get("framework-checks", "")
	package_job = jobs.get("package-checks", "")
	windows_job = jobs.get("windows-process-supervision", "")
	if (
		duplicate_jobs
		or not repository_job
		or not framework_job
		or not package_job
		or not windows_job
	):
		return ["Repository policy self-test could not isolate governed Ready CI jobs."]

	def mutate_ci_job(job_source: str, marker: str, replacement: str) -> str:
		if job_source.count(marker) != 1 or source.count(job_source) != 1:
			return source
		return source.replace(job_source, job_source.replace(marker, replacement, 1), 1)

	def make_windows_step_block_scalar_decoy() -> str:
		step = extract_ci_step_block(
			windows_job,
			"Verify Windows staging and startup boundaries",
		)
		if (
			not step
			or windows_job.count(step) != 1
			or windows_job.count("    steps:\n") != 1
			or source.count(windows_job) != 1
		):
			return source
		weakened_step = step.replace(
			"      - name: Verify Windows staging and startup boundaries",
			"      - name: Weakened Windows staging boundary",
			1,
		).replace(
			"          tests.gf_core.tools.test_gf_parallel_validation",
			"          tests.gf_core.tools.test_gf_gut_sharding",
			1,
		)
		mutated_job = windows_job.replace(step, weakened_step, 1).replace(
			"    steps:\n",
			"    concurrency: |2\n"
			"      - name: Verify Windows staging and startup boundaries\n"
			"        run: >\n"
			"          python -B -m unittest\n"
			"          tests.gf_core.tools.test_gf_parallel_validation\n"
			"          tests.gf_core.tools.test_gf_maintenance_check_graph\n"
			"    steps:\n",
			1,
		)
		return source.replace(windows_job, mutated_job, 1)
	mutations = (
		(
			"global_shell_override",
			source.replace(
				"\njobs:\n",
				"\ndefaults:\n  run:\n    shell: 'echo {0}'\n\njobs:\n",
				1,
			),
			"CI top-level fields",
		),
		(
			"quoted_extra_job",
			source.replace(
				"\njobs:\n",
				"\njobs:\n"
				'  "evil":\n'
				"    name: GF merge gate\n"
				"    runs-on: ubuntu-latest\n"
				"    steps:\n"
				"      - name: Fake success\n"
				"        run: echo pass\n\n",
				1,
			),
			"unsupported jobs",
		),
		(
			"extra_top_level_oidc_permission",
			source.replace(
				"permissions:\n  contents: read",
				"permissions:\n  id-token: write\n  contents: read",
				1,
			),
			"top-level permissions",
		),
		(
			"quoted_extra_pull_request_type",
			source.replace(
				"      - converted_to_draft",
				'      - converted_to_draft\n      - "labeled"',
				1,
			),
			"pull_request.types",
		),
		(
			"pull_request_paths_ignore",
			source.replace(
				"    types:\n",
				"    paths-ignore: ['**']\n    types:\n",
				1,
			),
			"pull_request trigger must contain only types",
		),
		(
			"push_paths_ignore",
			source.replace(
				"    branches:\n      - main",
				"    branches:\n      - main\n    paths-ignore: ['**']",
				1,
			),
			"push trigger must contain only branches",
		),
		(
			"wrong_push_branch",
			source.replace("      - main", "      - release", 1),
			"CI push.branches",
		),
		(
			"failure_tolerant_repository_policy_job",
			mutate_ci_job(
				repository_job,
				"    timeout-minutes: 5",
				"    continue-on-error: true\n    timeout-minutes: 5",
			),
			"must not set continue-on-error",
		),
		(
			"skipped_repository_policy_step",
			mutate_ci_job(
				repository_job,
				"      - name: Validate repository policy\n",
				"      - name: Validate repository policy\n        if: false\n",
			),
			"Validate repository policy fields",
		),
		(
			"extra_repository_policy_step",
			mutate_ci_job(
				repository_job,
				"      - name: Validate repository policy\n",
				"      - name: Unexpected preparation\n"
				"        run: echo unexpected\n\n"
				"      - name: Validate repository policy\n",
			),
			"repository-policy step names",
		),
		(
			"inline_hash_spoofed_repository_policy_command",
			mutate_ci_job(
				repository_job,
				f"        run: {REPOSITORY_POLICY_COMMAND}",
				f"        run: {REPOSITORY_POLICY_COMMAND}# || true",
			),
			"Validate repository policy command",
		),
		(
			"inline_hash_spoofed_pull_request_policy_command",
			mutate_ci_job(
				repository_job,
				f"        run: {PULL_REQUEST_POLICY_COMMAND}",
				f"        run: {PULL_REQUEST_POLICY_COMMAND}# || true",
			),
			"Validate pull request contract command",
		),
		(
			"failure_tolerant_package_step",
			mutate_ci_job(
				package_job,
				"      - name: Run package maintenance shard\n",
				"      - name: Run package maintenance shard\n"
				"        continue-on-error: true\n",
			),
			"must not set continue-on-error",
		),
		(
			"skipped_package_step",
			mutate_ci_job(
				package_job,
				"      - name: Run package maintenance shard\n",
				"      - name: Run package maintenance shard\n        if: false\n",
			),
			"Run package maintenance shard fields",
		),
		(
			"first_field_failure_tolerant_package_step",
			mutate_ci_job(
				package_job,
				"      - name: Run package maintenance shard\n",
				"      - continue-on-error: true\n        name: Run package maintenance shard\n",
			),
			"unsupported step item spelling",
		),
		(
			"flow_failure_tolerant_package_step",
			mutate_ci_job(
				package_job,
				"      - name: Set up Godot\n        uses: ./.github/actions/setup-godot",
				'      - {name: Set up Godot, continue-on-error: true, uses: "./.github/actions/setup-godot"}',
			),
			"unsupported step item spelling",
		),
		(
			"escaped_failure_tolerant_package_job",
			mutate_ci_job(
				package_job,
				"    timeout-minutes: ${{ matrix.timeout_minutes }}",
				'    "continue\\u002don\\u002derror": true\n'
				"    timeout-minutes: ${{ matrix.timeout_minutes }}",
			),
			"unsupported direct field spelling",
		),
		(
			"escaped_failure_tolerant_package_step",
			mutate_ci_job(
				package_job,
				"      - name: Run package maintenance shard\n",
				"      - name: Run package maintenance shard\n"
				'        "continue\\u002don\\u002derror": true\n',
			),
			"unsupported direct field spelling",
		),
		(
			"unguarded_full_validation",
			source.replace(
				"github.event_name == 'push' ||\n      (github.event_name == 'pull_request' &&",
				"github.event_name != 'pull_request' ||",
				1,
			),
			"framework-checks if",
		),
		(
			"missing_epoch_run_name",
			source.replace("GF CI|mode=", "GF CI|type=", 1),
			"CI run-name",
		),
		(
			"manual_dispatch_in_required_ci",
			source.replace("\npermissions:\n", "\n  workflow_dispatch:\n\npermissions:\n", 1),
			"must not expose workflow_dispatch",
		),
		(
			"broad_top_level_actions_permission",
			source.replace(
				"permissions:\n  contents: read",
				"permissions:\n  actions: read\n  contents: read",
				1,
			),
			"top-level permission actions",
		),
		(
			"missing_merge_gate_checks_permission",
			source.replace("      checks: read", "      checks: none", 1),
			"merge-gate permission checks",
		),
		(
			"comment_spoofed_cancellation",
			source.replace("      !cancelled() &&", "      always() && # !cancelled() &&", 1),
			"draft-gate if",
		),
		(
			"comment_spoofed_framework_suite",
			source.replace("            suite: framework-lsp", "            # suite: framework-lsp", 1),
			"framework-checks matrix suites",
		),
		(
			"short_framework_gut_timeout",
			source.replace(
				f"            timeout_minutes: {FRAMEWORK_GUT_CI_TIMEOUT_MINUTES}",
				f"            timeout_minutes: {FRAMEWORK_GUT_CI_TIMEOUT_MINUTES - 1}",
				1,
			),
			"framework-checks matrix suite framework-gut timeout_minutes",
		),
		(
			"block_scalar_spoofed_framework_gut_timeout",
			source.replace(
				f"            timeout_minutes: {FRAMEWORK_GUT_CI_TIMEOUT_MINUTES}",
				f"            timeout_minutes: {FRAMEWORK_GUT_CI_TIMEOUT_MINUTES - 1}",
				1,
			).replace(
				"    strategy:\n",
				"    env:\n"
				"      GF_MATRIX_POLICY_FIXTURE: |\n"
				"        include:\n"
				"          - suite: framework-gut\n"
				f"            timeout_minutes: {FRAMEWORK_GUT_CI_TIMEOUT_MINUTES}\n"
				"    strategy:\n",
				1,
			),
			"framework-checks matrix suite framework-gut timeout_minutes",
		),
		(
			"unbound_framework_timeout",
			source.replace(
				"    timeout-minutes: ${{ matrix.timeout_minutes }}",
				f"    timeout-minutes: {FRAMEWORK_GUT_CI_TIMEOUT_MINUTES}",
				1,
			),
			"framework-checks timeout-minutes",
		),
		(
			"failure_tolerant_framework_step",
			mutate_ci_job(
				framework_job,
				"      - name: Run framework maintenance shard\n",
				"      - name: Run framework maintenance shard\n"
				"        continue-on-error: true\n",
			),
			"Run framework maintenance shard fields",
		),
		(
			"failure_tolerant_framework_job",
			mutate_ci_job(
				framework_job,
				"    timeout-minutes: ${{ matrix.timeout_minutes }}",
				"    continue-on-error: true\n"
				"    timeout-minutes: ${{ matrix.timeout_minutes }}",
			),
			"framework-checks fields",
		),
		(
			"comment_spoofed_merge_dependency",
			source.replace("      - package-checks", "      # - package-checks", 1),
			"full-validation-gate needs",
		),
		(
			"wrong_windows_process_runner",
			source.replace("    runs-on: windows-latest", "    runs-on: ubuntu-latest", 1),
			"windows-process-supervision runs-on",
		),
		(
			"missing_windows_process_test",
			source.replace(
				"python tools/gf_maintenance.py maintenance-self-test --json",
				"python tools/gf_maintenance.py summary --json",
				1,
			),
			"Verify owned process-tree cleanup command",
		),
		(
			"failure_tolerant_windows_process_job",
			mutate_ci_job(
				windows_job,
				"    timeout-minutes: 5",
				"    continue-on-error: true\n    timeout-minutes: 5",
			),
			"windows-process-supervision fields",
		),
		(
			"failure_tolerant_windows_process_self_test",
			mutate_ci_job(
				windows_job,
				"      - name: Verify owned process-tree cleanup\n",
				"      - name: Verify owned process-tree cleanup\n"
				"        continue-on-error: true\n",
			),
			"Verify owned process-tree cleanup fields",
		),
		(
			"inline_hash_spoofed_windows_process_self_test",
			mutate_ci_job(
				windows_job,
				f"        run: {WINDOWS_PROCESS_SELF_TEST_COMMAND}",
				f"        run: {WINDOWS_PROCESS_SELF_TEST_COMMAND}#; exit 0",
			),
			"Verify owned process-tree cleanup command",
		),
		(
			"missing_windows_staging_tests",
			source.replace(
				"tests.gf_core.tools.test_gf_parallel_validation",
				"tests.gf_core.tools.test_gf_gut_sharding",
				1,
			),
			"windows-process-supervision is missing governed command",
		),
		(
			"shell_commented_windows_staging_tests",
			source.replace(
				"          python -B -m unittest",
				"          python -B -m unittest # governed modules are shell-commented",
				1,
			),
			"Windows staging/startup command",
		),
		(
			"block_scalar_spoofed_windows_staging_step",
			make_windows_step_block_scalar_decoy(),
			"Windows staging/startup step fields",
		),
		(
			"missing_windows_process_merge_dependency",
			source.replace(
				"      - windows-process-supervision",
				"      # - windows-process-supervision",
				1,
			),
			"full-validation-gate needs",
		),
		(
			"static_required_merge_name",
			source.replace(MERGE_GATE_NAME, "GF merge gate", 1),
			"merge-gate name",
		),
		(
			"mutable_full_marker_name",
			source.replace(
				FULL_VALIDATION_GATE_NAME,
				"GF full validation (${{ github.event.pull_request.head.sha || github.sha }})",
				1,
			),
			"full-validation-gate name",
		),
		(
			"missing_full_validation_merge_dependency",
			source.replace("      - full-validation-gate", "      # - full-validation-gate", 1),
			"merge-gate needs",
		),
		(
			"extra_merge_gate_oidc_permission",
			mutate_ci_job(
				jobs.get("merge-gate", ""),
				"      actions: read",
				'      "id-token": write\n      actions: read',
			),
			"merge-gate permissions",
		),
		(
			"skippable_required_merge_gate",
			source.replace("      always() &&", "      !cancelled() &&", 1),
			"merge-gate if",
		),
		(
			"missing_metadata_relay",
			source.replace(
				"python tools/gf_repository_policy.py validate-pr-gate",
				"python tools/gf_repository_policy.py validate-pr",
				1,
			),
			"merge-gate relay command is not governed",
		),
		(
			"decoy_metadata_relay",
			source.replace(
				"python tools/gf_repository_policy.py validate-pr-gate",
				"python tools/gf_repository_policy.py validate-pr",
				1,
			).replace(
				"          GH_TOKEN: ${{ github.token }}",
				"          GH_TOKEN: ${{ github.token }}\n"
				"          GF_RELAY_COMMAND_DECOY: python tools/gf_repository_policy.py validate-pr-gate --wait-seconds 1800 --poll-seconds 10",
				1,
			),
			"merge-gate relay environment fields",
		),
		(
			"bypassed_current_full_evaluator",
			source.replace(
				'          if [ "${FULL_VALIDATION_RESULT}" != "success" ]; then\n'
				'            echo "Full validation failed: ${FULL_VALIDATION_RESULT}"\n'
				"            exit 1\n"
				"          fi",
				"          echo bypass-current-full-result",
				1,
			),
			"current Full evaluator command",
		),
		(
			"folded_current_full_evaluator_changes_shell_lines",
			source.replace(
				'        run: |\n'
				'          if [ "${FULL_VALIDATION_RESULT}" != "success" ]; then\n'
				'            echo "Full validation failed: ${FULL_VALIDATION_RESULT}"\n'
				"            exit 1\n"
				"          fi",
				'        run: >\n'
				'          if [ "${FULL_VALIDATION_RESULT}" != "success" ]; then\n'
				"\n"
				'          echo "Full validation failed: ${FULL_VALIDATION_RESULT}"\n'
				"          exit 1\n"
				"\n"
				"          fi",
				1,
			),
			"current Full evaluator must match the canonical literal script",
		),
		(
			"wrong_metadata_relay_step_condition",
			source.replace(
				"      - name: Checkout relay policy\n        if: >-\n          success() &&",
				"      - name: Checkout relay policy\n        if: >-\n          always() &&",
				1,
			),
			"relay checkout condition is not governed",
		),
		(
			"missing_metadata_relay_token",
			source.replace("          GH_TOKEN: ${{ github.token }}", "          GF_TOKEN: ${{ github.token }}", 1),
			"relay environment fields are not governed",
		),
		(
			"wrong_job_quick_command",
			source.replace("          --suite quick", "          --suite policy-only", 1).replace(
				"python tools/gf_repository_policy.py validate --json",
				"python tools/gf_repository_policy.py validate --json\n          # --suite quick",
				1,
			),
			"Run quick maintenance suite command",
		),
		(
			"draft_gate_non_failing_branch",
			source.replace("            exit 1", "            exit 0", 1),
			"draft-gate evaluator",
		),
		(
			"draft_gate_wrong_result_mapping",
			source.replace(
				"          QUICK_RESULT: ${{ needs.quick-checks.result }}",
				"          QUICK_RESULT: ${{ needs.repository-policy.result }}",
				1,
			),
			"draft-gate evaluator",
		),
		(
			"full_gate_wrong_result_mapping",
			source.replace(
				"          PACKAGE_RESULT: ${{ needs.package-checks.result }}",
				"          PACKAGE_RESULT: ${{ needs.framework-checks.result }}",
				1,
			),
			"full-validation-gate evaluator",
		),
	)
	issues: list[str] = []
	for name, mutated_source, expected_fragment in mutations:
		mutation_issues = audit_ci_workflow(policy, mutated_source)
		if not any(expected_fragment in issue for issue in mutation_issues):
			issues.append(
				f"Repository policy self-test {name} did not detect its structural CI mutation: "
				f"{mutation_issues}"
			)
	return issues


def run_manual_ci_workflow_mutation_self_tests() -> list[str]:
	try:
		source = (ROOT / ".github/workflows/ci-manual.yml").read_text(encoding="utf-8")
	except (OSError, UnicodeDecodeError) as error:
		return [f"Repository policy self-test could not read manual CI workflow: {error}"]
	if audit_manual_ci_workflow(source):
		return []
	jobs, duplicate_jobs = extract_ci_job_blocks(source)
	repository_job = jobs.get("manual-repository-policy", "")
	full_job = jobs.get("manual-full-validation", "")
	windows_job = jobs.get("manual-windows-process-supervision", "")
	if duplicate_jobs or not repository_job or not full_job or not windows_job:
		return ["Repository policy self-test could not isolate governed manual CI jobs."]

	def mutate_manual_job(job_source: str, marker: str, replacement: str) -> str:
		if job_source.count(marker) != 1 or source.count(job_source) != 1:
			return source
		return source.replace(job_source, job_source.replace(marker, replacement, 1), 1)
	mutations = (
		(
			"manual_global_shell_override",
			source.replace(
				"\njobs:\n",
				"\ndefaults:\n  run:\n    shell: 'echo {0}'\n\njobs:\n",
				1,
			),
			"Manual CI top-level fields",
		),
		(
			"manual_quoted_extra_job",
			source.replace(
				"\njobs:\n",
				"\njobs:\n"
				'  "evil":\n'
				"    name: GF manual diagnostics gate\n"
				"    runs-on: ubuntu-latest\n"
				"    steps:\n"
				"      - name: Fake success\n"
				"        run: echo pass\n\n",
				1,
			),
			"unsupported jobs",
		),
		(
			"manual_scheduled_trigger",
			source.replace(
				"  workflow_dispatch:\n",
				'  workflow_dispatch:\n  schedule:\n    - cron: "0 * * * *"\n',
				1,
			),
			"triggers must contain only workflow_dispatch",
		),
		(
			"manual_extra_oidc_permission",
			source.replace(
				"permissions:\n  contents: read",
				"permissions:\n  id-token: write\n  contents: read",
				1,
			),
			"top-level permissions",
		),
		(
			"automatic_manual_ci",
			source.replace("  workflow_dispatch:\n", "  workflow_dispatch:\n  pull_request:\n", 1),
			"must not run automatically on pull_request",
		),
		(
			"manual_failure_tolerant_repository_policy_job",
			mutate_manual_job(
				repository_job,
				"    timeout-minutes: 5",
				"    continue-on-error: true\n    timeout-minutes: 5",
			),
			"must not set continue-on-error",
		),
		(
			"manual_skipped_repository_policy_step",
			mutate_manual_job(
				repository_job,
				"      - name: Validate repository policy\n",
				"      - name: Validate repository policy\n        if: false\n",
			),
			"Validate repository policy fields",
		),
		(
			"manual_extra_repository_policy_step",
			mutate_manual_job(
				repository_job,
				"      - name: Validate repository policy\n",
				"      - name: Unexpected preparation\n"
				"        run: echo unexpected\n\n"
				"      - name: Validate repository policy\n",
			),
			"manual-repository-policy step names",
		),
		(
			"manual_inline_hash_spoofed_repository_policy_command",
			mutate_manual_job(
				repository_job,
				f"        run: {REPOSITORY_POLICY_COMMAND}",
				f"        run: {REPOSITORY_POLICY_COMMAND}# || true",
			),
			"Validate repository policy command",
		),
		(
			"manual_protected_context",
			source.replace("GF manual diagnostics gate", "GF merge gate", 1),
			"must never emit or reference",
		),
		(
			"manual_extra_job",
			source.replace(
				"\njobs:\n",
				"\njobs:\n  ungoverned:\n    name: Ungoverned\n    runs-on: ubuntu-latest\n\n",
				1,
			),
			"unsupported jobs",
		),
		(
			"manual_broad_permission",
			source.replace(
				"permissions:\n  contents: read",
				"permissions:\n  checks: read\n  contents: read",
				1,
			),
			"permission checks",
		),
		(
			"manual_full_on_nonmain",
			source.replace("    if: github.ref == 'refs/heads/main'", "    if: always()", 1),
			"manual-full-validation if",
		),
		(
			"manual_missing_full_suite",
			source.replace("          --suite full", "          --suite quick", 1),
			"Run full maintenance diagnostics command",
		),
		(
			"manual_failure_tolerant_full_step",
			mutate_manual_job(
				full_job,
				"      - name: Run full maintenance diagnostics\n",
				"      - name: Run full maintenance diagnostics\n"
				"        continue-on-error: true\n",
			),
			"Run full maintenance diagnostics fields",
		),
		(
			"manual_failure_tolerant_full_job",
			mutate_manual_job(
				full_job,
				f"    timeout-minutes: {MANUAL_FULL_TIMEOUT_MINUTES}",
				"    continue-on-error: true\n"
				f"    timeout-minutes: {MANUAL_FULL_TIMEOUT_MINUTES}",
			),
			"manual-full-validation fields",
		),
		(
			"short_manual_full_timeout",
			source.replace(
				f"    timeout-minutes: {MANUAL_FULL_TIMEOUT_MINUTES}",
				f"    timeout-minutes: {MANUAL_FULL_TIMEOUT_MINUTES - 1}",
				1,
			),
			"manual-full-validation timeout-minutes",
		),
		(
			"manual_failure_tolerant_windows_job",
			mutate_manual_job(
				windows_job,
				"    timeout-minutes: 5",
				"    continue-on-error: true\n    timeout-minutes: 5",
			),
			"manual-windows-process-supervision fields",
		),
		(
			"manual_failure_tolerant_windows_self_test",
			mutate_manual_job(
				windows_job,
				"      - name: Verify owned process-tree cleanup\n",
				"      - name: Verify owned process-tree cleanup\n"
				"        continue-on-error: true\n",
			),
			"Verify owned process-tree cleanup fields",
		),
		(
			"manual_inline_hash_spoofed_windows_self_test",
			mutate_manual_job(
				windows_job,
				f"        run: {WINDOWS_PROCESS_SELF_TEST_COMMAND}",
				f"        run: {WINDOWS_PROCESS_SELF_TEST_COMMAND}#; exit 0",
			),
			"Verify owned process-tree cleanup command",
		),
		(
			"manual_missing_windows_gate_dependency",
			source.replace(
				"      - manual-windows-process-supervision",
				"      # - manual-windows-process-supervision",
				1,
			),
			"manual-diagnostics-gate needs",
		),
	)
	issues: list[str] = []
	for name, mutated_source, expected_fragment in mutations:
		mutation_issues = audit_manual_ci_workflow(mutated_source)
		if not any(expected_fragment in issue for issue in mutation_issues):
			issues.append(
				f"Repository policy self-test {name} did not detect its manual CI mutation: "
				f"{mutation_issues}"
			)
	return issues


def run_release_workflow_mutation_self_tests() -> list[str]:
	try:
		source = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
	except (OSError, UnicodeDecodeError) as error:
		return [f"Repository policy self-test could not read release workflow: {error}"]
	if audit_release_workflow(source):
		return []
	jobs, duplicate_jobs = extract_ci_job_blocks(source)
	framework_job = jobs.get("release-framework-checks", "")
	package_job = jobs.get("release-package-checks", "")
	create_release_job = jobs.get("create-release", "")
	if duplicate_jobs or not framework_job or not package_job or not create_release_job:
		return ["Repository policy self-test could not isolate release-framework-checks."]

	def mutate_release_job(job_source: str, marker: str, replacement: str) -> str:
		if job_source.count(marker) != 1 or source.count(job_source) != 1:
			return source
		return source.replace(job_source, job_source.replace(marker, replacement, 1), 1)

	def mutate_framework_job(marker: str, replacement: str) -> str:
		return mutate_release_job(framework_job, marker, replacement)

	def make_release_timeout_decoy() -> str:
		timeout_marker = f"          --suite-timeout {RELEASE_FRAMEWORK_SUITE_TIMEOUT_SECONDS}"
		if (
			framework_job.count(timeout_marker) != 1
			or framework_job.count("    steps:\n") != 1
			or source.count(framework_job) != 1
		):
			return source
		mutated_job = framework_job.replace(
			timeout_marker,
			f"          --suite-timeout {RELEASE_FRAMEWORK_SUITE_TIMEOUT_SECONDS - 100}",
			1,
		).replace(
			"    steps:\n",
			"    env:\n"
			f"      GF_TIMEOUT_DECOY: \"--suite-timeout {RELEASE_FRAMEWORK_SUITE_TIMEOUT_SECONDS}\"\n"
			"    steps:\n",
			1,
		)
		return source.replace(framework_job, mutated_job, 1)

	def make_release_step_block_scalar_decoy() -> str:
		step = extract_ci_step_block(framework_job, "Run release framework shard")
		if (
			not step
			or framework_job.count(step) != 1
			or framework_job.count("    steps:\n") != 1
			or source.count(framework_job) != 1
		):
			return source
		weakened_step = step.replace(
			"      - name: Run release framework shard",
			"      - name: Run weakened release framework shard",
			1,
		).replace(
			f"          --suite-timeout {RELEASE_FRAMEWORK_SUITE_TIMEOUT_SECONDS}",
			f"          --suite-timeout {RELEASE_FRAMEWORK_SUITE_TIMEOUT_SECONDS - 100}",
			1,
		)
		mutated_job = framework_job.replace(step, weakened_step, 1).replace(
			"    steps:\n",
			"    concurrency: |2\n"
			"      - name: Run release framework shard\n"
			"        run: >\n"
			"          python tools/gf_maintenance.py check\n"
			"          --suite framework\n"
			f"          --suite-timeout {RELEASE_FRAMEWORK_SUITE_TIMEOUT_SECONDS}\n"
			"          --failed-only\n"
			"          --github-annotations\n"
			"    steps:\n",
			1,
		)
		return source.replace(framework_job, mutated_job, 1)

	mutations = (
		(
			"release_global_shell_override",
			source.replace(
				"\njobs:\n",
				"\ndefaults:\n  run:\n    shell: 'echo {0}'\n\njobs:\n",
				1,
			),
			"Release top-level fields",
		),
		(
			"release_quoted_extra_job",
			source.replace(
				"\njobs:\n",
				"\njobs:\n"
				'  "evil":\n'
				"    name: Fake release success\n"
				"    runs-on: ubuntu-latest\n"
				"    steps:\n"
				"      - name: Fake success\n"
				"        run: echo pass\n\n",
				1,
			),
			"unsupported jobs",
		),
		(
			"release_broad_tag_trigger",
			source.replace(
				'      - "[0-9]*.[0-9]*.[0-9]*"',
				'      - "*"',
				1,
			),
			"exact governed stable-tag push filter",
		),
		(
			"release_manual_trigger",
			source.replace(
				"permissions:\n",
				"  workflow_dispatch:\n\npermissions:\n",
				1,
			),
			"exact governed stable-tag push filter",
		),
		(
			"release_global_concurrency_group",
			source.replace(
				"  group: release-${{ github.ref_name }}",
				"  group: release-global",
				1,
			),
			"tag-scoped and non-cancelling",
		),
		(
			"release_cancelling_concurrency",
			source.replace(
				"  cancel-in-progress: false",
				"  cancel-in-progress: true",
				1,
			),
			"tag-scoped and non-cancelling",
		),
		(
			"release_extra_oidc_permission",
			source.replace(
				"permissions:\n  contents: read",
				'permissions:\n  "id-token": write\n  contents: read',
				1,
			),
			"top-level permissions",
		),
		(
			"broad_release_top_level_permission",
			source.replace("permissions:\n  contents: read", "permissions:\n  contents: write", 1),
			"top-level permission contents",
		),
		(
			"missing_release_package_job",
			source.replace(
				package_job,
				"  # release-package-checks removed by hostile mutation\n",
				1,
			).replace(
				"      - release-package-checks",
				"      # - release-package-checks",
				1,
			),
			"missing governed jobs: release-package-checks",
		),
		(
			"missing_release_package_dependency",
			mutate_release_job(
				create_release_job,
				"      - release-package-checks",
				"      # - release-package-checks",
			),
			"create-release needs",
		),
		(
			"comment_spoofed_release_package_suite",
			mutate_release_job(
				package_job,
				"            suite: package-godot-release",
				"            suite: package-contract\n"
				"            # suite: package-godot-release",
			),
			"release-package-checks matrix suites",
		),
		(
			"failure_tolerant_create_release_job",
			mutate_release_job(
				create_release_job,
				"    timeout-minutes: 20",
				"    continue-on-error: true\n    timeout-minutes: 20",
			),
			"must not set continue-on-error",
		),
		(
			"skipped_create_release_job",
			mutate_release_job(
				create_release_job,
				"    name: Create GitHub Release\n",
				"    name: Create GitHub Release\n    if: false\n",
			),
			"create-release fields",
		),
		(
			"skipped_release_package_step",
			mutate_release_job(
				package_job,
				"      - name: Run release package shard\n",
				"      - name: Run release package shard\n        if: false\n",
			),
			"Run release package shard fields",
		),
		(
			"flow_failure_tolerant_release_package_step",
			mutate_release_job(
				package_job,
				"      - name: Set up Godot\n        uses: ./.github/actions/setup-godot",
				'      - {name: Set up Godot, continue-on-error: true, uses: "./.github/actions/setup-godot"}',
			),
			"unsupported step item spelling",
		),
		(
			"skipped_create_release_step",
			mutate_release_job(
				create_release_job,
				"      - name: Create release\n",
				"      - name: Create release\n        if: false\n",
			),
			"Create release fields",
		),
		(
			"missing_release_publish_permission",
			source.replace(
				"    permissions:\n      contents: write",
				"    permissions:\n      contents: read",
				1,
			),
			"create-release permission contents",
		),
		(
			"release_build_job_write_permission",
			source.replace(
				"  build-release-artifacts:\n",
				"  build-release-artifacts:\n    permissions:\n      contents: write\n",
				1,
			),
			"build-release-artifacts permission contents must not be write",
		),
		(
			"short_release_framework_timeout",
			mutate_framework_job(
				f"    timeout-minutes: {RELEASE_FRAMEWORK_TIMEOUT_MINUTES}",
				f"    timeout-minutes: {RELEASE_FRAMEWORK_TIMEOUT_MINUTES - 1}",
			),
			"release-framework-checks timeout-minutes",
		),
		(
			"missing_release_framework_suite_timeout",
			mutate_framework_job(
				f"          --suite-timeout {RELEASE_FRAMEWORK_SUITE_TIMEOUT_SECONDS}",
				"          # governed suite timeout removed",
			),
			"Run release framework shard command",
		),
		(
			"decoy_release_framework_suite_timeout",
			make_release_timeout_decoy(),
			"Run release framework shard command",
		),
		(
			"shell_commented_release_framework_arguments",
			mutate_framework_job(
				"          python tools/gf_maintenance.py check",
				"          python tools/gf_maintenance.py check # governed arguments are shell-commented",
			),
			"Run release framework shard command",
		),
		(
			"skipped_release_framework_step",
			mutate_framework_job(
				"      - name: Run release framework shard\n",
				"      - name: Run release framework shard\n        if: ${{ false }}\n",
			),
			"Run release framework shard fields",
		),
		(
			"failure_tolerant_release_framework_step",
			mutate_framework_job(
				"      - name: Run release framework shard\n",
				"      - name: Run release framework shard\n        continue-on-error: true\n",
			),
			"Run release framework shard fields",
		),
		(
			"quoted_failure_tolerant_release_framework_step",
			mutate_framework_job(
				"      - name: Run release framework shard\n",
				"      - name: Run release framework shard\n"
				'        "continue-on-error": true\n',
			),
			"Run release framework shard fields",
		),
		(
			"quoted_skipped_release_framework_step",
			mutate_framework_job(
				"      - name: Run release framework shard\n",
				"      - name: Run release framework shard\n"
				'        "if": false\n',
			),
			"Run release framework shard fields",
		),
		(
			"failure_tolerant_release_framework_job",
			mutate_framework_job(
				f"    timeout-minutes: {RELEASE_FRAMEWORK_TIMEOUT_MINUTES}",
				"    continue-on-error: true\n"
				f"    timeout-minutes: {RELEASE_FRAMEWORK_TIMEOUT_MINUTES}",
			),
			"release-framework-checks fields",
		),
		(
			"quoted_failure_tolerant_release_framework_job",
			mutate_framework_job(
				f"    timeout-minutes: {RELEASE_FRAMEWORK_TIMEOUT_MINUTES}",
				'    "continue-on-error": true\n'
				f"    timeout-minutes: {RELEASE_FRAMEWORK_TIMEOUT_MINUTES}",
			),
			"release-framework-checks fields",
		),
		(
			"block_scalar_spoofed_release_framework_step",
			make_release_step_block_scalar_decoy(),
			"Run release framework shard fields",
		),
	)
	issues: list[str] = []
	for name, mutated_source, expected_fragment in mutations:
		mutation_issues = audit_release_workflow(mutated_source)
		if not any(expected_fragment in issue for issue in mutation_issues):
			issues.append(
				f"Repository policy self-test {name} did not detect its release workflow mutation: "
				f"{mutation_issues}"
			)
	return issues


def run_full_validation_relay_self_tests(policy: dict[str, Any]) -> list[str]:
	repository = str(policy["repository"])
	pull_number = 28
	head_sha = "a" * 40
	base_sha = "b" * 40
	now = dt.datetime(2026, 1, 8, 12, 0, tzinfo=dt.timezone.utc)
	run_id = 101
	run_attempt = 2
	check_suite_id = 202
	job_id = 303
	check_run_id = 404
	started_at = "2026-01-08T10:59:00Z"
	completed_at = "2026-01-08T11:00:00Z"
	valid_run = {
		"id": run_id,
		"run_attempt": run_attempt,
		"check_suite_id": check_suite_id,
		"run_started_at": "2026-01-08T10:00:00Z",
		"display_title": make_full_validation_run_name(pull_number, head_sha, base_sha),
		"name": make_full_validation_run_name(pull_number, head_sha, base_sha),
		"event": "pull_request",
		"head_sha": head_sha,
		"repository": {"full_name": repository},
		"path": ".github/workflows/ci.yml@refs/pull/28/merge",
		"status": "completed",
		"conclusion": "success",
		"pull_requests": [],
	}
	valid_job = {
		"id": job_id,
		"name": make_full_validation_marker_name(base_sha),
		"status": "completed",
		"conclusion": "success",
		"run_id": run_id,
		"run_attempt": run_attempt,
		"head_sha": head_sha,
		"html_url": f"https://github.com/{repository}/actions/runs/{run_id}/job/{job_id}",
		"check_run_url": f"https://api.github.com/repos/{repository}/check-runs/{check_run_id}",
		"started_at": started_at,
		"completed_at": completed_at,
	}
	valid_check_run = {
		"id": check_run_id,
		"name": make_full_validation_marker_name(base_sha),
		"status": "completed",
		"conclusion": "success",
		"head_sha": head_sha,
		"app": {"id": GITHUB_ACTIONS_APP_ID, "slug": "github-actions"},
		"check_suite": {"id": check_suite_id},
		"details_url": valid_job["html_url"],
		"started_at": started_at,
		"completed_at": completed_at,
		"pull_requests": [],
	}
	issues: list[str] = []

	def record(condition: bool, name: str) -> None:
		if not condition:
			issues.append(f"Repository policy relay self-test failed: {name}.")

	selection = select_latest_full_validation_epoch(
		{"workflow_runs": [valid_run]},
		repository=repository,
		head_repository=repository,
		pull_number=pull_number,
		head_sha=head_sha,
		base_sha=base_sha,
		now=now,
	)
	record(selection.get("state") == "success" and object_value(selection.get("epoch")).get("run_id") == run_id, "valid epoch")

	stale_old_run = json.loads(json.dumps(valid_run))
	stale_old_run["id"] = 99
	stale_old_run["run_attempt"] = 1
	stale_old_run["check_suite_id"] = 199
	stale_old_run["run_started_at"] = "2025-12-01T10:00:00Z"
	stale_old_run["path"] = "malformed historical path"
	selection_with_old_history = select_latest_full_validation_epoch(
		{"workflow_runs": [stale_old_run, valid_run]},
		repository=repository,
		head_repository=repository,
		pull_number=pull_number,
		head_sha=head_sha,
		base_sha=base_sha,
		now=now,
	)
	record(
		selection_with_old_history.get("state") == "success"
		and object_value(selection_with_old_history.get("epoch")).get("run_id") == run_id,
		"historical non-sort fields do not block a newer exact epoch",
	)

	newer_running = json.loads(json.dumps(valid_run))
	newer_running["id"] = 102
	newer_running["run_attempt"] = 1
	newer_running["check_suite_id"] = 203
	newer_running["run_started_at"] = "2026-01-08T11:30:00Z"
	newer_running["status"] = "in_progress"
	newer_running["conclusion"] = None
	latest_running_selection = select_latest_full_validation_epoch(
		{"workflow_runs": [valid_run, newer_running]},
		repository=repository,
		head_repository=repository,
		pull_number=pull_number,
		head_sha=head_sha,
		base_sha=base_sha,
		now=now,
	)
	record(
		latest_running_selection.get("state") == "success"
		and object_value(latest_running_selection.get("epoch")).get("run_id") == 102,
		"newer Full intent supersedes an older success before its marker exists",
	)

	stale_only_selection = select_latest_full_validation_epoch(
		{"workflow_runs": [stale_old_run]},
		repository=repository,
		head_repository=repository,
		pull_number=pull_number,
		head_sha=head_sha,
		base_sha=base_sha,
		now=now,
	)
	record(stale_only_selection.get("state") == "failure", "stale latest epoch fails closed")

	job_state, job_issues = audit_full_validation_marker_job(
		valid_job,
		repository=repository,
		run_id=run_id,
		run_attempt=run_attempt,
		head_sha=head_sha,
		run_started_at=valid_run["run_started_at"],
		now=now,
	)
	record(job_state == "success" and not job_issues, "valid marker job")
	pending_job = json.loads(json.dumps(valid_job))
	pending_job["status"] = "in_progress"
	pending_job["conclusion"] = None
	record(
		audit_full_validation_marker_job(
			pending_job,
			repository=repository,
			run_id=run_id,
			run_attempt=run_attempt,
			head_sha=head_sha,
			run_started_at=valid_run["run_started_at"],
			now=now,
		)[0] == "pending",
		"running marker waits",
	)
	skipped_job = json.loads(json.dumps(valid_job))
	skipped_job["conclusion"] = "skipped"
	record(
		audit_full_validation_marker_job(
			skipped_job,
			repository=repository,
			run_id=run_id,
			run_attempt=run_attempt,
			head_sha=head_sha,
			run_started_at=valid_run["run_started_at"],
			now=now,
		)[0] == "failure",
		"skipped marker cannot be reused",
	)

	record(
		not audit_full_validation_check_run(
			valid_check_run,
			valid_job,
			repository=repository,
			head_repository=repository,
			run_id=run_id,
			run_attempt=run_attempt,
			check_suite_id=check_suite_id,
			check_run_id=check_run_id,
			head_sha=head_sha,
			base_sha=base_sha,
			pull_number=pull_number,
			now=now,
		),
		"valid GitHub Actions check run with empty fork associations",
	)
	wrong_app_check = json.loads(json.dumps(valid_check_run))
	wrong_app_check["app"] = {"id": 1, "slug": "third-party"}
	record(
		bool(audit_full_validation_check_run(
			wrong_app_check,
			valid_job,
			repository=repository,
			head_repository=repository,
			run_id=run_id,
			run_attempt=run_attempt,
			check_suite_id=check_suite_id,
			check_run_id=check_run_id,
			head_sha=head_sha,
			base_sha=base_sha,
			pull_number=pull_number,
			now=now,
		)),
		"third-party check run fails closed",
	)
	wrong_suite_check = json.loads(json.dumps(valid_check_run))
	wrong_suite_check["check_suite"]["id"] = 999
	record(
		bool(audit_full_validation_check_run(
			wrong_suite_check,
			valid_job,
			repository=repository,
			head_repository=repository,
			run_id=run_id,
			run_attempt=run_attempt,
			check_suite_id=check_suite_id,
			check_run_id=check_run_id,
			head_sha=head_sha,
			base_sha=base_sha,
			pull_number=pull_number,
			now=now,
		)),
		"cross-epoch check suite fails closed",
	)
	contradictory_association = json.loads(json.dumps(valid_check_run))
	contradictory_association["pull_requests"] = [{
		"number": pull_number,
		"url": f"https://api.github.com/repos/{repository}/pulls/{pull_number}",
		"head": {
			"sha": "c" * 40,
			"repo": {"url": f"https://api.github.com/repos/{repository}"},
		},
		"base": {
			"sha": base_sha,
			"repo": {"url": f"https://api.github.com/repos/{repository}"},
		},
	}]
	record(
		bool(audit_full_validation_check_run(
			contradictory_association,
			valid_job,
			repository=repository,
			head_repository=repository,
			run_id=run_id,
			run_attempt=run_attempt,
			check_suite_id=check_suite_id,
			check_run_id=check_run_id,
			head_sha=head_sha,
			base_sha=base_sha,
			pull_number=pull_number,
			now=now,
		)),
		"contradictory nonempty pull association fails closed",
	)
	mixed_associations = json.loads(json.dumps(valid_check_run))
	mixed_associations["pull_requests"] = [
		{
			"number": pull_number,
			"url": f"https://api.github.com/repos/{repository}/pulls/{pull_number}",
			"head": {
				"sha": head_sha,
				"repo": {"url": f"https://api.github.com/repos/{repository}"},
			},
			"base": {
				"sha": base_sha,
				"repo": {"url": f"https://api.github.com/repos/{repository}"},
			},
		},
		{
			"number": pull_number + 1,
			"url": f"https://api.github.com/repos/{repository}/pulls/{pull_number + 1}",
			"head": {
				"sha": head_sha,
				"repo": {"url": f"https://api.github.com/repos/{repository}"},
			},
			"base": {
				"sha": base_sha,
				"repo": {"url": f"https://api.github.com/repos/{repository}"},
			},
		},
	]
	record(
		bool(audit_full_validation_check_run(
			mixed_associations,
			valid_job,
			repository=repository,
			head_repository=repository,
			run_id=run_id,
			run_attempt=run_attempt,
			check_suite_id=check_suite_id,
			check_run_id=check_run_id,
			head_sha=head_sha,
			base_sha=base_sha,
			pull_number=pull_number,
			now=now,
		)),
		"mixed exact and contradictory pull associations fail closed",
	)
	record(
		check_run_id_from_api_url(valid_job["check_run_url"], repository) == check_run_id
		and check_run_id_from_api_url(valid_job["check_run_url"], "other/repository") == 0,
		"check-run URL repository binding",
	)
	first_fingerprint, first_stable = advance_relay_stability(
		"",
		{"state": "success", "fingerprint": "epoch-a"},
	)
	second_fingerprint, second_stable = advance_relay_stability(
		first_fingerprint,
		{"state": "success", "fingerprint": "epoch-a"},
	)
	reset_fingerprint, reset_stable = advance_relay_stability(
		second_fingerprint,
		{"state": "pending", "fingerprint": "epoch-a"},
	)
	record(
		not first_stable
		and second_stable
		and second_fingerprint == "epoch-a"
		and reset_fingerprint == ""
		and not reset_stable,
		"two consecutive identical successes are required and pending resets stability",
	)
	issues.extend(run_full_validation_relay_transport_self_tests(
		repository=repository,
		pull_number=pull_number,
		head_sha=head_sha,
		base_sha=base_sha,
		valid_run=valid_run,
		valid_job=valid_job,
		valid_check_run=valid_check_run,
	))
	return issues


def run_full_validation_relay_transport_self_tests(
	*,
	repository: str,
	pull_number: int,
	head_sha: str,
	base_sha: str,
	valid_run: dict[str, Any],
	valid_job: dict[str, Any],
	valid_check_run: dict[str, Any],
) -> list[str]:
	fixture_now = dt.datetime.now(dt.timezone.utc)
	started_at = (fixture_now - dt.timedelta(minutes=2)).strftime("%Y-%m-%dT%H:%M:%SZ")
	job_started_at = (fixture_now - dt.timedelta(seconds=90)).strftime("%Y-%m-%dT%H:%M:%SZ")
	completed_at = (fixture_now - dt.timedelta(minutes=1)).strftime("%Y-%m-%dT%H:%M:%SZ")
	transport_run = json.loads(json.dumps(valid_run))
	transport_job = json.loads(json.dumps(valid_job))
	transport_check_run = json.loads(json.dumps(valid_check_run))
	transport_run["run_started_at"] = started_at
	transport_job["started_at"] = job_started_at
	transport_job["completed_at"] = completed_at
	transport_check_run["started_at"] = job_started_at
	transport_check_run["completed_at"] = completed_at
	run_query = urllib.parse.urlencode({
		"event": "pull_request",
		"head_sha": head_sha,
		"per_page": 100,
	})
	run_path = f"/repos/{repository}/actions/workflows/ci.yml/runs?{run_query}&page=1"
	job_path = (
		f"/repos/{repository}/actions/runs/{transport_run['id']}/attempts/"
		f"{transport_run['run_attempt']}/jobs?per_page=100&page=1"
	)
	check_path = f"/repos/{repository}/check-runs/{transport_check_run['id']}"
	pull_path = f"/repos/{repository}/pulls/{pull_number}"
	responses = {
		pull_path: {
			"number": pull_number,
			"state": "open",
			"draft": False,
			"head": {
				"sha": head_sha,
				"repo": {
					"full_name": repository,
					"url": f"https://api.github.com/repos/{repository}",
				},
			},
			"base": {
				"sha": base_sha,
				"repo": {
					"full_name": repository,
					"url": f"https://api.github.com/repos/{repository}",
				},
			},
		},
		run_path: {"total_count": 1, "workflow_runs": [transport_run]},
		job_path: {"total_count": 1, "jobs": [transport_job]},
		check_path: transport_check_run,
	}
	requested_paths: list[str] = []
	original_request = github_request

	def fixture_request(
		method: str,
		path: str,
		token: str,
		payload: dict[str, Any] | None = None,
		*,
		timeout_seconds: float = GITHUB_REQUEST_TIMEOUT_SECONDS,
	) -> dict[str, Any]:
		del payload, timeout_seconds
		if method != "GET" or token != "fixture-token" or path not in responses:
			raise GitHubApiError(0, f"Unexpected relay fixture request: {method} {path}")
		requested_paths.append(path)
		return json.loads(json.dumps(responses[path]))

	issues: list[str] = []
	globals()["github_request"] = fixture_request
	try:
		observation = inspect_full_validation_relay_epoch(
			repository=repository,
			pull_number=pull_number,
			head_sha=head_sha,
			base_sha=base_sha,
			token="fixture-token",
			deadline=time.monotonic() + 5.0,
		)
	except (GitHubApiError, KeyError, TypeError, ValueError) as error:
		issues.append(f"Repository policy relay transport self-test raised unexpectedly: {error}")
	else:
		if observation.get("state") != "success" or not observation.get("fingerprint"):
			issues.append(
				f"Repository policy relay transport self-test rejected its valid fixture: {observation}"
			)
		expected_paths = [pull_path, run_path, job_path, check_path, pull_path, run_path]
		if requested_paths != expected_paths:
			issues.append(
				"Repository policy relay transport self-test used unexpected endpoint order: "
				f"{requested_paths!r}."
			)
	finally:
		globals()["github_request"] = original_request

	first_page_path = "/fixture/runs?per_page=100&page=1"
	second_page_path = "/fixture/runs?per_page=100&page=2"
	page_responses = {
		first_page_path: {
			"total_count": 101,
			"workflow_runs": [{"id": index} for index in range(1, 101)],
		},
		second_page_path: {
			"total_count": 102,
			"workflow_runs": [{"id": 101}],
		},
	}

	def drifting_page_request(
		method: str,
		path: str,
		token: str,
		payload: dict[str, Any] | None = None,
		*,
		timeout_seconds: float = GITHUB_REQUEST_TIMEOUT_SECONDS,
	) -> dict[str, Any]:
		del payload, timeout_seconds
		if method != "GET" or token != "fixture-token" or path not in page_responses:
			raise GitHubApiError(0, f"Unexpected pagination fixture request: {method} {path}")
		return json.loads(json.dumps(page_responses[path]))

	globals()["github_request"] = drifting_page_request
	try:
		try:
			fetch_paginated_github_collection(
				"/fixture/runs?per_page=100",
				"workflow_runs",
				"fixture-token",
				time.monotonic() + 5.0,
			)
		except GitHubApiError as error:
			if "total_count changed" not in str(error):
				issues.append(
					f"Repository policy relay pagination self-test reported the wrong failure: {error}"
				)
		else:
			issues.append("Repository policy relay pagination self-test accepted a drifting total_count.")
	finally:
		globals()["github_request"] = original_request
	return issues


def make_full_validation_run_name(pull_number: int, head_sha: str, base_sha: str) -> str:
	return f"GF CI|mode=full|pr={pull_number}|head={head_sha}|base={base_sha}"


def make_full_validation_marker_name(base_sha: str) -> str:
	return f"GF full validation ({base_sha})"


def validate_pr_gate_relay(
	policy: dict[str, Any],
	*,
	repository: str,
	pull_number: Any,
	head_sha: str,
	base_sha: str,
	wait_seconds: int,
	poll_seconds: int,
) -> dict[str, Any]:
	repository = str(repository).strip()
	head_sha = str(head_sha).strip().lower()
	base_sha = str(base_sha).strip().lower()
	input_issues: list[str] = []
	try:
		parsed_pull_number = int(str(pull_number).strip())
	except ValueError:
		parsed_pull_number = 0
	if repository != policy.get("repository"):
		input_issues.append(
			f"Relay repository must match policy repository {policy.get('repository')!r}, got {repository!r}."
		)
	if parsed_pull_number <= 0:
		input_issues.append("Relay pull request number must be a positive integer.")
	if COMMIT_SHA_RE.fullmatch(head_sha) is None:
		input_issues.append("Relay head SHA must be a lowercase 40-character hexadecimal commit SHA.")
	if COMMIT_SHA_RE.fullmatch(base_sha) is None:
		input_issues.append("Relay base SHA must be a lowercase 40-character hexadecimal commit SHA.")
	if wait_seconds < 0 or wait_seconds > FULL_VALIDATION_RELAY_MAX_WAIT_SECONDS:
		input_issues.append(
			f"Relay wait-seconds must be between 0 and {FULL_VALIDATION_RELAY_MAX_WAIT_SECONDS}."
		)
	if poll_seconds < 1 or poll_seconds > FULL_VALIDATION_RELAY_MAX_POLL_SECONDS:
		input_issues.append(
			f"Relay poll-seconds must be between 1 and {FULL_VALIDATION_RELAY_MAX_POLL_SECONDS}."
		)
	token = os.environ.get("GH_TOKEN", "").strip() or os.environ.get("GITHUB_TOKEN", "").strip()
	if not token:
		input_issues.append("GH_TOKEN or GITHUB_TOKEN with Actions, Checks, and pull-request read access is required.")
	context: dict[str, Any] = {
		"repository": repository,
		"pull_number": parsed_pull_number,
		"head_sha": head_sha,
		"base_sha": base_sha,
		"marker_name": make_full_validation_marker_name(base_sha),
		"wait_seconds": wait_seconds,
		"poll_seconds": poll_seconds,
	}
	if input_issues:
		return make_result("validate-pr-gate", input_issues, context)

	poll_deadline = time.monotonic() + wait_seconds
	request_deadline = poll_deadline + GITHUB_REQUEST_TIMEOUT_SECONDS
	stable_fingerprint = ""
	attempts = 0
	last_issues = ["No matching Full validation epoch has been observed."]
	while True:
		attempts += 1
		try:
			observation = inspect_full_validation_relay_epoch(
				repository=repository,
				pull_number=parsed_pull_number,
				head_sha=head_sha,
				base_sha=base_sha,
				token=token,
				deadline=request_deadline,
			)
		except GitHubApiError as error:
			observation = {
				"state": "pending",
				"issues": [f"GitHub API request failed closed ({error.status}): {error}"],
			}
		state = observation["state"]
		last_issues = list(observation.get("issues", []))
		if state == "failure":
			context["attempts"] = attempts
			context.update(object_value(observation.get("epoch")))
			return make_result("validate-pr-gate", last_issues, context)
		if state == "success":
			stable_fingerprint, stable = advance_relay_stability(stable_fingerprint, observation)
			if stable:
				if time.monotonic() > request_deadline:
					context["attempts"] = attempts
					context["stable_observations"] = 1
					context.update(object_value(observation.get("epoch")))
					return make_result(
						"validate-pr-gate",
						["Metadata relay GitHub API deadline expired before stable success could be committed."],
						context,
					)
				context["attempts"] = attempts
				context["stable_observations"] = 2
				context.update(object_value(observation.get("epoch")))
				return make_result("validate-pr-gate", [], context)
			last_issues = ["Full validation succeeded once; waiting for a second stable epoch observation."]
		else:
			stable_fingerprint = ""

		remaining = poll_deadline - time.monotonic()
		if remaining <= 0:
			context["attempts"] = attempts
			context["stable_observations"] = 1 if stable_fingerprint else 0
			context.update(object_value(observation.get("epoch")))
			return make_result(
				"validate-pr-gate",
				[
					"Timed out without two consecutive stable observations of the latest Full validation epoch.",
					*last_issues,
				],
				context,
			)
		time.sleep(min(float(poll_seconds), remaining))


def advance_relay_stability(previous_fingerprint: str, observation: dict[str, Any]) -> tuple[str, bool]:
	if observation.get("state") != "success":
		return "", False
	fingerprint = str(observation.get("fingerprint", ""))
	if not fingerprint:
		return "", False
	return fingerprint, fingerprint == previous_fingerprint


def inspect_full_validation_relay_epoch(
	*,
	repository: str,
	pull_number: int,
	head_sha: str,
	base_sha: str,
	token: str,
	deadline: float,
) -> dict[str, Any]:
	pull_data = relay_github_request(
		"GET",
		f"/repos/{repository}/pulls/{pull_number}",
		token,
		deadline,
	)
	pull_issues = audit_relay_pull_snapshot(
		pull_data,
		repository=repository,
		pull_number=pull_number,
		head_sha=head_sha,
		base_sha=base_sha,
	)
	if pull_issues:
		return {"state": "failure", "issues": pull_issues}
	head_repository = str(
		object_value(object_value(pull_data.get("head")).get("repo")).get("full_name")
	)

	run_query = urllib.parse.urlencode({
		"event": "pull_request",
		"head_sha": head_sha,
		"per_page": 100,
	})
	runs_data = fetch_paginated_github_collection(
		f"/repos/{repository}/actions/workflows/ci.yml/runs?{run_query}",
		"workflow_runs",
		token,
		deadline,
	)
	selection = select_latest_full_validation_epoch(
		runs_data,
		repository=repository,
		head_repository=head_repository,
		pull_number=pull_number,
		head_sha=head_sha,
		base_sha=base_sha,
		now=dt.datetime.now(dt.timezone.utc),
	)
	if selection["state"] != "success":
		return selection
	epoch = object_value(selection.get("epoch"))
	if epoch.get("status") != "completed" or epoch.get("conclusion") != "success":
		return {
			"state": "pending",
			"issues": ["Latest Full validation epoch has not completed successfully yet."],
			"epoch": epoch,
		}
	run_id = int(epoch["run_id"])
	run_attempt = int(epoch["run_attempt"])
	jobs_data = fetch_paginated_github_collection(
		f"/repos/{repository}/actions/runs/{run_id}/attempts/{run_attempt}/jobs?per_page=100",
		"jobs",
		token,
		deadline,
	)
	marker_name = make_full_validation_marker_name(base_sha)
	marker_jobs = [
		job
		for job in object_array(jobs_data.get("jobs"))
		if job.get("name") == marker_name
	]
	if len(marker_jobs) > 1:
		return {
			"state": "failure",
			"issues": [f"Latest Full validation epoch contains duplicate marker jobs named {marker_name!r}."],
			"epoch": epoch,
		}
	if not marker_jobs:
		if epoch.get("status") == "completed":
			return {
				"state": "failure",
				"issues": ["Latest Full validation epoch completed without its governed marker job."],
				"epoch": epoch,
			}
		return {
			"state": "pending",
			"issues": ["Latest Full validation epoch exists, but its marker job has not been created yet."],
			"epoch": epoch,
		}
	job = marker_jobs[0]
	job_state, job_issues = audit_full_validation_marker_job(
		job,
		repository=repository,
		run_id=run_id,
		run_attempt=run_attempt,
		head_sha=head_sha,
		run_started_at=str(epoch["run_started_at"]),
		now=dt.datetime.now(dt.timezone.utc),
	)
	if job_state != "success":
		return {"state": job_state, "issues": job_issues, "epoch": epoch}

	check_run_id = check_run_id_from_api_url(str(job["check_run_url"]), repository)
	if check_run_id <= 0:
		return {
			"state": "failure",
			"issues": ["Full validation marker job has an invalid or cross-repository check_run_url."],
			"epoch": epoch,
		}
	check_run = relay_github_request(
		"GET",
		f"/repos/{repository}/check-runs/{check_run_id}",
		token,
		deadline,
	)
	check_issues = audit_full_validation_check_run(
		check_run,
		job,
		repository=repository,
		head_repository=head_repository,
		run_id=run_id,
		run_attempt=run_attempt,
		check_suite_id=int(epoch["check_suite_id"]),
		check_run_id=check_run_id,
		head_sha=head_sha,
		base_sha=base_sha,
		pull_number=pull_number,
		now=dt.datetime.now(dt.timezone.utc),
	)
	if check_issues:
		return {"state": "failure", "issues": check_issues, "epoch": epoch}

	final_pull_data = relay_github_request(
		"GET",
		f"/repos/{repository}/pulls/{pull_number}",
		token,
		deadline,
	)
	final_pull_issues = audit_relay_pull_snapshot(
		final_pull_data,
		repository=repository,
		pull_number=pull_number,
		head_sha=head_sha,
		base_sha=base_sha,
	)
	if final_pull_issues:
		return {"state": "failure", "issues": final_pull_issues}
	final_runs_data = fetch_paginated_github_collection(
		f"/repos/{repository}/actions/workflows/ci.yml/runs?{run_query}",
		"workflow_runs",
		token,
		deadline,
	)
	final_selection = select_latest_full_validation_epoch(
		final_runs_data,
		repository=repository,
		head_repository=head_repository,
		pull_number=pull_number,
		head_sha=head_sha,
		base_sha=base_sha,
		now=dt.datetime.now(dt.timezone.utc),
	)
	if final_selection["state"] != "success":
		return final_selection
	final_epoch = object_value(final_selection.get("epoch"))
	epoch_identity_fields = (
		"run_id",
		"run_attempt",
		"run_started_at",
		"check_suite_id",
		"status",
		"conclusion",
	)
	if any(final_epoch.get(field) != epoch.get(field) for field in epoch_identity_fields):
		return {
			"state": "pending",
			"issues": ["Latest Full validation epoch changed during relay verification."],
			"epoch": final_epoch,
		}
	fingerprint = json.dumps(
		{
			"run_id": run_id,
			"run_attempt": run_attempt,
			"run_started_at": epoch["run_started_at"],
			"check_suite_id": epoch["check_suite_id"],
			"job_id": job["id"],
			"check_run_id": check_run_id,
			"completed_at": check_run["completed_at"],
		},
		sort_keys=True,
		separators=(",", ":"),
	)
	return {
		"state": "success",
		"issues": [],
		"fingerprint": fingerprint,
		"epoch": epoch,
	}


def fetch_paginated_github_collection(
	base_path: str,
	collection_key: str,
	token: str,
	deadline: float,
) -> dict[str, Any]:
	separator = "&" if "?" in base_path else "?"
	first_response = relay_github_request("GET", f"{base_path}{separator}page=1", token, deadline)
	total_count = first_response.get("total_count")
	first_items = first_response.get(collection_key)
	if type(total_count) is not int or total_count < 0 or not isinstance(first_items, list):
		raise GitHubApiError(0, f"GitHub {collection_key} response was malformed.")
	page_count = max(1, (total_count + 99) // 100)
	if page_count > FULL_VALIDATION_RELAY_MAX_PAGES:
		raise GitHubApiError(
			0,
			f"GitHub {collection_key} response requires {page_count} pages; refusing an unbounded relay scan.",
		)
	items = list(first_items)
	for page in range(2, page_count + 1):
		response = relay_github_request("GET", f"{base_path}{separator}page={page}", token, deadline)
		if response.get("total_count") != total_count:
			raise GitHubApiError(0, f"GitHub {collection_key} pagination total_count changed during relay inspection.")
		page_items = response.get(collection_key)
		if not isinstance(page_items, list):
			raise GitHubApiError(0, f"GitHub {collection_key} page {page} was malformed.")
		items.extend(page_items)
	identifiers = [
		item.get("id")
		for item in items
		if isinstance(item, dict) and type(item.get("id")) is int
	]
	if len(items) != total_count or len(set(identifiers)) != len(items):
		raise GitHubApiError(0, f"GitHub {collection_key} pagination changed or contained duplicate identities.")
	return {"total_count": total_count, collection_key: items}


def relay_github_request(
	method: str,
	path: str,
	token: str,
	deadline: float,
) -> dict[str, Any]:
	remaining = deadline - time.monotonic()
	if remaining <= 0:
		raise GitHubApiError(0, "Metadata relay GitHub API deadline expired.")
	return github_request(
		method,
		path,
		token,
		timeout_seconds=min(GITHUB_REQUEST_TIMEOUT_SECONDS, remaining),
	)


def audit_relay_pull_snapshot(
	pull_data: dict[str, Any],
	*,
	repository: str,
	pull_number: int,
	head_sha: str,
	base_sha: str,
) -> list[str]:
	issues: list[str] = []
	if pull_data.get("number") != pull_number:
		issues.append("GitHub pull-request snapshot has the wrong pull request number.")
	if pull_data.get("state") != "open" or pull_data.get("draft") is not False:
		issues.append("Metadata relay is allowed only for an open Ready pull request.")
	head = object_value(pull_data.get("head"))
	base = object_value(pull_data.get("base"))
	if str(head.get("sha", "")).lower() != head_sha:
		issues.append("GitHub pull-request snapshot head SHA no longer matches the metadata event.")
	if str(base.get("sha", "")).lower() != base_sha:
		issues.append("GitHub pull-request snapshot base SHA no longer matches the metadata event.")
	head_repository = object_value(head.get("repo")).get("full_name")
	if not isinstance(head_repository, str) or REPOSITORY_RE.fullmatch(head_repository) is None:
		issues.append("GitHub pull-request snapshot has an invalid head repository identity.")
	base_repository = object_value(base.get("repo")).get("full_name")
	if base_repository != repository:
		issues.append("GitHub pull-request snapshot belongs to a different base repository.")
	if object_value(base.get("repo")).get("url") != f"https://api.github.com/repos/{repository}":
		issues.append("GitHub pull-request snapshot has the wrong base repository API URL.")
	if (
		isinstance(head_repository, str)
		and object_value(head.get("repo")).get("url") != f"https://api.github.com/repos/{head_repository}"
	):
		issues.append("GitHub pull-request snapshot has the wrong head repository API URL.")
	return issues


def select_latest_full_validation_epoch(
	runs_data: dict[str, Any],
	*,
	repository: str,
	head_repository: str,
	pull_number: int,
	head_sha: str,
	base_sha: str,
	now: dt.datetime,
) -> dict[str, Any]:
	runs = runs_data.get("workflow_runs")
	if not isinstance(runs, list):
		return {"state": "failure", "issues": ["GitHub workflow-runs response was malformed."]}
	expected_title = make_full_validation_run_name(pull_number, head_sha, base_sha)
	candidates: list[tuple[dt.datetime, int, int, dict[str, Any]]] = []
	for run in runs:
		if not isinstance(run, dict) or run.get("display_title") != expected_title:
			continue
		run_id = run.get("id")
		run_attempt = run.get("run_attempt")
		started_at = parse_github_datetime(run.get("run_started_at"))
		sort_issues: list[str] = []
		if type(run_id) is not int or run_id <= 0:
			sort_issues.append("Full validation epoch has an invalid run id.")
		if type(run_attempt) is not int or run_attempt <= 0:
			sort_issues.append("Full validation epoch has an invalid run attempt.")
		if started_at is None:
			sort_issues.append("Full validation epoch has an invalid run_started_at timestamp.")
		if sort_issues:
			return {"state": "failure", "issues": sort_issues}
		assert started_at is not None
		candidates.append((started_at, run_id, run_attempt, run))
	if not candidates:
		return {
			"state": "pending",
			"issues": ["No exact Full validation intent exists for this repository, pull request, head SHA, and base SHA."],
		}
	latest_started_at, run_id, run_attempt, latest = max(
		candidates,
		key=lambda item: (item[0], item[1], item[2]),
	)
	latest_issues: list[str] = []
	check_suite_id = latest.get("check_suite_id")
	if type(check_suite_id) is not int or check_suite_id <= 0:
		latest_issues.append("Latest Full validation epoch has an invalid check suite id.")
	if latest.get("name") != expected_title or latest.get("event") != "pull_request":
		latest_issues.append("Latest Full validation epoch has the wrong workflow identity or event.")
	if str(latest.get("head_sha", "")).lower() != head_sha:
		latest_issues.append("Latest Full validation epoch has the wrong head SHA.")
	if object_value(latest.get("repository")).get("full_name") != repository:
		latest_issues.append("Latest Full validation epoch belongs to a different repository.")
	if str(latest.get("path", "")).split("@", 1)[0] != ".github/workflows/ci.yml":
		latest_issues.append("Latest Full validation epoch belongs to a different workflow path.")
	status = latest.get("status")
	if status not in {"queued", "in_progress", "completed", "requested", "waiting", "pending"}:
		latest_issues.append("Latest Full validation epoch has an unsupported status.")
	conclusion = latest.get("conclusion")
	if status == "completed" and conclusion != "success":
		latest_issues.append("Latest completed Full validation epoch did not conclude success.")
	if status != "completed" and conclusion is not None:
		latest_issues.append("Incomplete Full validation epoch has an unexpected conclusion.")
	latest_issues.extend(audit_optional_pull_associations(
		latest.get("pull_requests"),
		repository=repository,
		head_repository=head_repository,
		pull_number=pull_number,
		head_sha=head_sha,
		base_sha=base_sha,
	))
	if latest_issues:
		return {"state": "failure", "issues": latest_issues}
	if latest_started_at > now or now - latest_started_at > FULL_VALIDATION_MAX_AGE:
		return {
			"state": "failure",
			"issues": ["Latest matching Full validation intent is outside the seven-day reuse window."],
		}
	return {
		"state": "success",
		"issues": [],
		"epoch": {
			"run_id": run_id,
			"run_attempt": run_attempt,
			"run_started_at": latest["run_started_at"],
			"check_suite_id": check_suite_id,
			"status": status,
			"conclusion": conclusion,
		},
	}


def audit_full_validation_marker_job(
	job: dict[str, Any],
	*,
	repository: str,
	run_id: int,
	run_attempt: int,
	head_sha: str,
	run_started_at: str,
	now: dt.datetime,
) -> tuple[str, list[str]]:
	status = job.get("status")
	if status in {"queued", "in_progress", "requested", "waiting", "pending"}:
		return "pending", ["Latest Full validation marker job is not completed."]
	if status != "completed":
		return "failure", ["Latest Full validation marker job has an unsupported status."]
	issues: list[str] = []
	if job.get("conclusion") != "success":
		issues.append(f"Latest Full validation marker concluded {job.get('conclusion')!r}, not success.")
	if job.get("run_id") != run_id or job.get("run_attempt") != run_attempt:
		issues.append("Full validation marker job is not bound to the selected run attempt.")
	if str(job.get("head_sha", "")).lower() != head_sha:
		issues.append("Full validation marker job has the wrong head SHA.")
	job_id = job.get("id")
	if type(job_id) is not int or job_id <= 0:
		issues.append("Full validation marker job has an invalid id.")
	expected_html_url = f"https://github.com/{repository}/actions/runs/{run_id}/job/{job_id}"
	if job.get("html_url") != expected_html_url:
		issues.append("Full validation marker job details URL is not bound to the selected run and job.")
	run_started = parse_github_datetime(run_started_at)
	job_started = parse_github_datetime(job.get("started_at"))
	completed_at = parse_github_datetime(job.get("completed_at"))
	if (
		run_started is None
		or job_started is None
		or completed_at is None
		or not run_started <= job_started <= completed_at <= now
		or now - completed_at > FULL_VALIDATION_MAX_AGE
	):
		issues.append(
			"Full validation marker job timestamps are malformed, out of order, or outside the seven-day reuse window."
		)
	if not isinstance(job.get("check_run_url"), str):
		issues.append("Full validation marker job is missing its check-run URL.")
	return ("failure", issues) if issues else ("success", [])


def audit_full_validation_check_run(
	check_run: dict[str, Any],
	job: dict[str, Any],
	*,
	repository: str,
	head_repository: str,
	run_id: int,
	run_attempt: int,
	check_suite_id: int,
	check_run_id: int,
	head_sha: str,
	base_sha: str,
	pull_number: int,
	now: dt.datetime,
) -> list[str]:
	issues: list[str] = []
	if check_run.get("id") != check_run_id:
		issues.append("Full validation check-run response has the wrong id.")
	if check_run.get("name") != make_full_validation_marker_name(base_sha):
		issues.append("Full validation check run has the wrong frozen marker name.")
	if check_run.get("status") != "completed" or check_run.get("conclusion") != "success":
		issues.append("Full validation check run is not completed with success.")
	if str(check_run.get("head_sha", "")).lower() != head_sha:
		issues.append("Full validation check run has the wrong head SHA.")
	app = object_value(check_run.get("app"))
	if app.get("id") != GITHUB_ACTIONS_APP_ID or app.get("slug") != "github-actions":
		issues.append("Full validation check run was not created by the governed GitHub Actions app.")
	if object_value(check_run.get("check_suite")).get("id") != check_suite_id:
		issues.append("Full validation check run is not bound to the selected epoch check suite.")
	if check_run.get("details_url") != job.get("html_url"):
		issues.append("Full validation check run details URL is not bound to the selected run and job.")
	job_started = parse_github_datetime(job.get("started_at"))
	job_completed = parse_github_datetime(job.get("completed_at"))
	check_started = parse_github_datetime(check_run.get("started_at"))
	completed_at = parse_github_datetime(check_run.get("completed_at"))
	if (
		job_started is None
		or job_completed is None
		or check_started is None
		or completed_at is None
		or check_started != job_started
		or completed_at != job_completed
		or not check_started <= completed_at <= now
		or now - completed_at > FULL_VALIDATION_MAX_AGE
	):
		issues.append(
			"Full validation check-run timestamps do not exactly match the marker job or the reuse window."
		)
	issues.extend(audit_optional_pull_associations(
		check_run.get("pull_requests"),
		repository=repository,
		head_repository=head_repository,
		pull_number=pull_number,
		head_sha=head_sha,
		base_sha=base_sha,
	))
	if job.get("run_id") != run_id or job.get("run_attempt") != run_attempt:
		issues.append("Full validation check run job binding changed during validation.")
	return issues


def audit_optional_pull_associations(
	value: Any,
	*,
	repository: str,
	head_repository: str,
	pull_number: int,
	head_sha: str,
	base_sha: str,
) -> list[str]:
	if value == []:
		return []
	if not isinstance(value, list) or not all(isinstance(item, dict) for item in value):
		return ["GitHub pull-request associations are malformed."]
	for association in value:
		head = object_value(association.get("head"))
		base = object_value(association.get("base"))
		if (
			association.get("number") != pull_number
			or association.get("url") != f"https://api.github.com/repos/{repository}/pulls/{pull_number}"
			or str(head.get("sha", "")).lower() != head_sha
			or object_value(head.get("repo")).get("url")
			!= f"https://api.github.com/repos/{head_repository}"
			or str(base.get("sha", "")).lower() != base_sha
			or object_value(base.get("repo")).get("url") != f"https://api.github.com/repos/{repository}"
		):
			return ["GitHub pull-request associations contradict the selected pull request, head SHA, or base SHA."]
	return []


def check_run_id_from_api_url(value: str, repository: str) -> int:
	parsed = urllib.parse.urlparse(value)
	expected_prefix = f"/repos/{repository}/check-runs/"
	if parsed.scheme != "https" or parsed.netloc != "api.github.com" or not parsed.path.startswith(expected_prefix):
		return 0
	suffix = parsed.path[len(expected_prefix):]
	return int(suffix) if suffix.isdigit() and int(suffix) > 0 else 0


def parse_github_datetime(value: Any) -> dt.datetime | None:
	if not isinstance(value, str) or not value.endswith("Z"):
		return None
	try:
		parsed = dt.datetime.fromisoformat(value[:-1] + "+00:00")
	except ValueError:
		return None
	return parsed if parsed.tzinfo is not None else None


def read_plugin_version(root: Path = ROOT) -> str:
	config = configparser.ConfigParser()
	config.read(root / "addons/gf/plugin.cfg", encoding="utf-8")
	return config.get("plugin", "version", fallback="").strip().strip('"')


def check_or_apply_remote_policy(policy: dict[str, Any], repository: str, apply: bool) -> dict[str, Any]:
	completed_mutations: list[str] = []
	if REPOSITORY_RE.fullmatch(repository) is None:
		return make_result(
			"protection",
			["Repository must use owner/name syntax."],
			make_protection_result_context(repository, apply, completed_mutations),
		)
	if repository != policy["repository"]:
		return make_result(
			"protection",
			[f"Refusing repository mismatch: policy owns {policy['repository']}, requested {repository}."],
			make_protection_result_context(repository, apply, completed_mutations),
		)
	token = os.environ.get("GH_TOKEN", "").strip() or os.environ.get("GITHUB_TOKEN", "").strip()
	if not token:
		return make_result(
			"protection",
			["GH_TOKEN or GITHUB_TOKEN with repository administration permission is required."],
			make_protection_result_context(repository, apply, completed_mutations),
		)
	head_sha = ""
	try:
		if apply:
			branch = urllib.parse.quote(str(policy["default_branch"]), safe="")
			branch_data = github_request("GET", f"/repos/{repository}/branches/{branch}", token)
			head_sha = str(object_value(branch_data.get("commit")).get("sha", "")).strip()
			check_runs_data = fetch_required_check_runs(policy, repository, head_sha, token)
			preflight_issues = audit_required_status_checks(policy, branch_data, check_runs_data)
			if preflight_issues:
				return make_result(
					"protection",
					preflight_issues,
					make_protection_result_context(repository, apply, completed_mutations, head_sha=head_sha),
				)
			apply_remote_policy(policy, repository, token, completed_mutations)
		repository_data = github_request("GET", f"/repos/{repository}", token)
		branch = urllib.parse.quote(str(policy["default_branch"]), safe="")
		protection_data = github_request("GET", f"/repos/{repository}/branches/{branch}/protection", token)
	except GitHubApiError as error:
		return make_result(
			"protection",
			[f"GitHub API request failed ({error.status}): {error}"],
			make_protection_result_context(repository, apply, completed_mutations, head_sha=head_sha),
		)
	issues = audit_remote_policy(policy, repository_data, protection_data)
	return make_result(
		"protection",
		issues,
		make_protection_result_context(
			repository,
			apply,
			completed_mutations,
			verification_completed=True,
			head_sha=head_sha,
		),
	)


def apply_remote_policy(
	policy: dict[str, Any],
	repository: str,
	token: str,
	completed_mutations: list[str] | None = None,
) -> None:
	mutation_log = completed_mutations if completed_mutations is not None else []
	branch = urllib.parse.quote(str(policy["default_branch"]), safe="")
	github_request(
		"PUT",
		f"/repos/{repository}/branches/{branch}/protection",
		token,
		make_branch_protection_payload(policy),
	)
	mutation_log.append("branch_protection")
	github_request("PATCH", f"/repos/{repository}", token, policy["repository_settings"])
	mutation_log.append("repository_settings")


def fetch_required_check_runs(
	policy: dict[str, Any],
	repository: str,
	head_sha: str,
	token: str,
) -> dict[str, Any]:
	if not head_sha:
		return {"check_runs": []}
	check_runs: list[dict[str, Any]] = []
	for required_name in policy["required_status_checks"]:
		encoded_check_name = urllib.parse.quote(str(required_name), safe="")
		response = github_request(
			"GET",
			f"/repos/{repository}/commits/{head_sha}/check-runs?check_name={encoded_check_name}&filter=latest&per_page=100",
			token,
		)
		response_runs = response.get("check_runs")
		if not isinstance(response_runs, list):
			raise GitHubApiError(0, f"GitHub check-runs response for {required_name!r} was malformed.")
		check_runs.extend(run for run in response_runs if isinstance(run, dict))
	return {"check_runs": check_runs}


def make_protection_result_context(
	repository: str,
	apply_requested: bool,
	completed_mutations: list[str] | None = None,
	*,
	verification_completed: bool = False,
	head_sha: str = "",
) -> dict[str, Any]:
	mutations = list(completed_mutations or [])
	context: dict[str, Any] = {
		"repository": repository,
		"apply_requested": apply_requested,
		"applied": apply_requested and mutations == ["branch_protection", "repository_settings"],
		"completed_mutations": mutations,
		"verification_completed": verification_completed,
	}
	if head_sha:
		context["head_sha"] = head_sha
	return context


def make_branch_protection_payload(policy: dict[str, Any]) -> dict[str, Any]:
	protection = policy["branch_protection"]
	return {
		"required_status_checks": {
			"strict": protection["strict_status_checks"],
			"contexts": [],
			"checks": [
				{"context": required_name, "app_id": GITHUB_ACTIONS_APP_ID}
				for required_name in policy["required_status_checks"]
			],
		},
		"enforce_admins": protection["enforce_admins"],
		"required_pull_request_reviews": {
			"dismiss_stale_reviews": protection["dismiss_stale_reviews"],
			"require_code_owner_reviews": protection["require_code_owner_reviews"],
			"require_last_push_approval": protection["require_last_push_approval"],
			"required_approving_review_count": protection["required_approving_review_count"],
		},
		"restrictions": None,
		"required_linear_history": protection["required_linear_history"],
		"allow_force_pushes": protection["allow_force_pushes"],
		"allow_deletions": protection["allow_deletions"],
		"block_creations": False,
		"required_conversation_resolution": protection["required_conversation_resolution"],
		"lock_branch": False,
		"allow_fork_syncing": False,
	}


def audit_remote_policy(
	policy: dict[str, Any],
	repository_data: dict[str, Any],
	protection_data: dict[str, Any],
) -> list[str]:
	issues: list[str] = []
	for field_name, expected in policy["repository_settings"].items():
		actual = repository_data.get(field_name)
		if actual != expected:
			issues.append(f"GitHub repository setting {field_name} is {actual!r}, expected {expected!r}.")

	protection = policy["branch_protection"]
	status_checks = object_value(protection_data.get("required_status_checks"))
	if status_checks.get("strict") != protection["strict_status_checks"]:
		issues.append("GitHub strict status-check mode differs from repository policy.")
	raw_contexts = status_checks.get("contexts")
	contexts = string_array(raw_contexts)
	checks = object_array(status_checks.get("checks"))
	actual_checks = sorted(
		(check.get("context"), check.get("app_id"))
		for check in checks
		if isinstance(check.get("context"), str) and type(check.get("app_id")) is int
	)
	expected_checks = sorted(
		(str(name), GITHUB_ACTIONS_APP_ID)
		for name in policy["required_status_checks"]
	)
	expected_contexts = sorted(str(name) for name in policy["required_status_checks"])
	if (
		not isinstance(raw_contexts, list)
		or sorted(contexts) != expected_contexts
		or len(checks) != len(actual_checks)
		or actual_checks != expected_checks
	):
		issues.append(
			"GitHub app-bound required status checks are "
			f"{actual_checks!r} with mirrored contexts {sorted(contexts)!r}, "
			f"expected {expected_checks!r} with contexts {expected_contexts!r}."
		)
	if enabled_value(protection_data.get("enforce_admins")) != protection["enforce_admins"]:
		issues.append("GitHub admin enforcement differs from repository policy.")

	reviews = object_value(protection_data.get("required_pull_request_reviews"))
	for field_name in (
		"dismiss_stale_reviews",
		"require_code_owner_reviews",
		"require_last_push_approval",
		"required_approving_review_count",
	):
		if reviews.get(field_name) != protection[field_name]:
			issues.append(f"GitHub pull-request review setting {field_name} differs from repository policy.")
	for field_name in (
		"required_linear_history",
		"required_conversation_resolution",
		"allow_force_pushes",
		"allow_deletions",
	):
		if enabled_value(protection_data.get(field_name)) != protection[field_name]:
			issues.append(f"GitHub branch protection {field_name} differs from repository policy.")
	return issues


def audit_required_status_checks(
	policy: dict[str, Any],
	branch_data: dict[str, Any],
	check_runs_data: dict[str, Any],
) -> list[str]:
	issues: list[str] = []
	head_sha = object_value(branch_data.get("commit")).get("sha")
	if not isinstance(head_sha, str) or not head_sha.strip():
		return ["Cannot apply protection before resolving the default branch head commit."]
	check_runs = check_runs_data.get("check_runs")
	if not isinstance(check_runs, list):
		return ["Cannot apply protection because GitHub check-runs data is malformed."]
	for required_name_value in policy["required_status_checks"]:
		required_name = str(required_name_value)
		matching_runs = [
			run
			for run in check_runs
			if (
				isinstance(run, dict)
				and run.get("name") == required_name
				and object_value(run.get("app")).get("id") == GITHUB_ACTIONS_APP_ID
				and object_value(run.get("app")).get("slug") == "github-actions"
			)
		]
		if not matching_runs:
			issues.append(
				f"Cannot apply protection before {required_name!r} appears on the current default-branch commit."
			)
			continue
		if not any(run.get("status") == "completed" and run.get("conclusion") == "success" for run in matching_runs):
			issues.append(
				f"Cannot apply protection until {required_name!r} succeeds on the current default-branch commit."
			)
	return issues


def github_request(
	method: str,
	path: str,
	token: str,
	payload: dict[str, Any] | None = None,
	*,
	timeout_seconds: float = GITHUB_REQUEST_TIMEOUT_SECONDS,
) -> dict[str, Any]:
	data = None if payload is None else json.dumps(payload, separators=(",", ":")).encode("utf-8")
	request = urllib.request.Request(
		f"{GITHUB_API_URL}{path}",
		data=data,
		method=method,
		headers={
			"Accept": "application/vnd.github+json",
			"Authorization": f"Bearer {token}",
			"Content-Type": "application/json",
			"User-Agent": "gf-repository-policy",
			"X-GitHub-Api-Version": "2022-11-28",
		},
	)
	try:
		with urllib.request.urlopen(request, timeout=max(0.1, timeout_seconds)) as response:
			body = response.read()
	except urllib.error.HTTPError as error:
		body = error.read().decode("utf-8", errors="replace")
		raise GitHubApiError(error.code, body[:2000]) from error
	except urllib.error.URLError as error:
		raise GitHubApiError(0, str(error.reason)) from error
	except (OSError, TimeoutError) as error:
		raise GitHubApiError(0, str(error)) from error
	if not body:
		return {}
	try:
		parsed = json.loads(body.decode("utf-8"))
	except (UnicodeDecodeError, json.JSONDecodeError) as error:
		raise GitHubApiError(0, f"GitHub API response was not strict UTF-8 JSON: {error}") from error
	if not isinstance(parsed, dict):
		raise GitHubApiError(0, "GitHub API response root was not an object.")
	return parsed


def enabled_value(value: Any) -> bool:
	if isinstance(value, dict):
		return value.get("enabled") is True
	return value is True


def object_value(value: Any) -> dict[str, Any]:
	return value if isinstance(value, dict) else {}


def object_array(value: Any) -> list[dict[str, Any]]:
	if not isinstance(value, list):
		return []
	return [item for item in value if isinstance(item, dict)]


def string_array(value: Any) -> list[str]:
	if not isinstance(value, list):
		return []
	return [item for item in value if isinstance(item, str)]


def relative_path(path: Path, root: Path = ROOT) -> str:
	try:
		return path.relative_to(root).as_posix()
	except ValueError:
		return path.as_posix()


def make_result(
	command: str,
	issues: list[str],
	extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
	result: dict[str, Any] = {
		"ok": not issues,
		"command": command,
		"issues": issues,
	}
	if extra:
		result.update(extra)
	return result


def print_result(result: dict[str, Any], as_json: bool) -> None:
	if as_json:
		print(json.dumps(result, ensure_ascii=False, indent=2))
		return
	print(f"GF repository policy: {'OK' if result['ok'] else 'FAILED'}")
	for issue in result["issues"]:
		print(f"- {issue}")


if __name__ == "__main__":
	raise SystemExit(main())
