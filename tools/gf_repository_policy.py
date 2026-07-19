#!/usr/bin/env python3
"""Validate and optionally apply GF repository workflow policy."""

from __future__ import annotations

import argparse
import configparser
import json
import os
import re
import sys
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
POLICY_FIELDS = {
	"schema_version",
	"repository",
	"default_branch",
	"internal_branch_pattern",
	"bot_branch_patterns",
	"development_version_pattern",
	"required_status_check",
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
REQUIRED_CI_SUITES = (
	"framework",
	"package-contract",
	"package-editor",
	"package-cli-local",
	"package-cli-network",
	"package-godot-ci",
)


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
	if policy.get("schema_version") != 1:
		issues.append("Repository policy schema_version must be the integer 1.")
	repository = policy.get("repository")
	if not isinstance(repository, str) or REPOSITORY_RE.fullmatch(repository) is None:
		issues.append("Repository policy repository must use owner/name syntax.")
	for field_name in ("default_branch", "internal_branch_pattern", "development_version_pattern", "required_status_check"):
		if not isinstance(policy.get(field_name), str) or not str(policy.get(field_name, "")).strip():
			issues.append(f"Repository policy {field_name} must be a non-empty string.")
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
	)
	for path in required_paths:
		if not path.is_file():
			issues.append(f"Required workflow file is missing: {relative_path(path, root)}")
	if issues:
		return issues

	ci_source = (root / ".github/workflows/ci.yml").read_text(encoding="utf-8")
	required_status_check = str(policy["required_status_check"])
	required_ci_fragments = (
		f"name: {required_status_check}",
		"python tools/gf_repository_policy.py validate",
		"python tools/gf_repository_policy.py validate-pr",
		"      - edited",
		"github.event.pull_request.draft == true",
		"github.event.pull_request.draft == false",
		"--suite quick",
		"--suite framework",
		"--suite ${{ matrix.suite }}",
	)
	for fragment in required_ci_fragments:
		if fragment not in ci_source:
			issues.append(f"CI workflow is missing repository policy fragment: {fragment}")
	for suite_name in REQUIRED_CI_SUITES[1:]:
		if f"suite: {suite_name}" not in ci_source:
			issues.append(f"CI workflow is missing full-suite shard: {suite_name}")

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
	if stable_source and (not internal_pull_request or not head_ref.startswith(("release/", "hotfix/"))):
		issues.append("Stable source versions are allowed only on internal release/ or hotfix/ pull requests.")
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
		("stable_normal_branch", ["Stable source"], audit_pull_request(policy, base_ref=default_branch, head_ref="fix/example", repository=repository, head_repository=repository, source_version="8.2.0")),
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
	repository_fixture = dict(policy["repository_settings"])
	protection = policy["branch_protection"]
	protection_fixture = {
		"required_status_checks": {
			"strict": protection["strict_status_checks"],
			"contexts": [policy["required_status_check"]],
			"checks": [],
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
	branch_fixture = {"commit": {"sha": "0123456789abcdef"}}
	check_runs_fixture = {
		"check_runs": [{
			"name": policy["required_status_check"],
			"status": "completed",
			"conclusion": "success",
		}],
	}
	if audit_required_merge_gate(policy, branch_fixture, check_runs_fixture):
		issues.append("Repository policy self-test rejected a successful required merge gate.")
	if not audit_required_merge_gate(policy, branch_fixture, {"check_runs": []}):
		issues.append("Repository policy self-test did not reject a missing required merge gate.")
	failed_check_runs_fixture = json.loads(json.dumps(check_runs_fixture))
	failed_check_runs_fixture["check_runs"][0]["conclusion"] = "failure"
	if not audit_required_merge_gate(policy, branch_fixture, failed_check_runs_fixture):
		issues.append("Repository policy self-test did not reject a failing required merge gate.")
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
	return issues


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
			encoded_check_name = urllib.parse.quote(str(policy["required_status_check"]), safe="")
			check_runs_data = github_request(
				"GET",
				f"/repos/{repository}/commits/{head_sha}/check-runs?check_name={encoded_check_name}&filter=latest&per_page=100",
				token,
			) if head_sha else {"check_runs": []}
			preflight_issues = audit_required_merge_gate(policy, branch_data, check_runs_data)
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
			"contexts": [policy["required_status_check"]],
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
	contexts = set(string_array(status_checks.get("contexts")))
	for check in object_array(status_checks.get("checks")):
		context = check.get("context")
		if isinstance(context, str):
			contexts.add(context)
	expected_contexts = {str(policy["required_status_check"])}
	if contexts != expected_contexts:
		issues.append(f"GitHub required status checks are {sorted(contexts)}, expected {sorted(expected_contexts)}.")
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


def audit_required_merge_gate(
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
	required_name = str(policy["required_status_check"])
	matching_runs = [
		run
		for run in check_runs
		if isinstance(run, dict) and run.get("name") == required_name
	]
	if not matching_runs:
		return [f"Cannot apply protection before {required_name!r} appears on the current default-branch commit."]
	if not any(run.get("status") == "completed" and run.get("conclusion") == "success" for run in matching_runs):
		issues.append(f"Cannot apply protection until {required_name!r} succeeds on the current default-branch commit.")
	return issues


def github_request(
	method: str,
	path: str,
	token: str,
	payload: dict[str, Any] | None = None,
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
		with urllib.request.urlopen(request, timeout=30) as response:
			body = response.read()
	except urllib.error.HTTPError as error:
		body = error.read().decode("utf-8", errors="replace")
		raise GitHubApiError(error.code, body[:2000]) from error
	except urllib.error.URLError as error:
		raise GitHubApiError(0, str(error.reason)) from error
	if not body:
		return {}
	parsed = json.loads(body.decode("utf-8"))
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
