"""Evidence-based, redacted, approval-gated feedback workflow for GF issues."""

from __future__ import annotations

import json
import os
import re
import secrets
import shutil
import subprocess
from copy import deepcopy
from pathlib import Path
from typing import Any, Callable

from .constants import DEFAULT_CONTRACT_PATH, DEFAULT_FEEDBACK_ROOT, SCHEMA_ROOT
from .contract import load_contract
from .paths import atomic_write_json, atomic_write_text, canonical_json_bytes, read_json_object, resolve_project_path, sha256_bytes
from .schema import validate_schema_file


_DEFAULT_REDACTIONS: tuple[tuple[re.Pattern[str], str], ...] = (
	(re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", re.DOTALL), "<redacted-private-key>"),
	(re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"), "<redacted-github-token>"),
	(re.compile(r"\bAKIA[0-9A-Z]{16}\b"), "<redacted-access-key>"),
	(re.compile(r"(?i)\b(authorization\s*:\s*bearer|bearer)\s+[A-Za-z0-9._~+/=-]{8,}"), r"\1 <redacted-token>"),
	(re.compile(r"(?i)\b(api[_-]?key|client[_-]?secret|password|token)\s*[:=]\s*[^\s,;]{6,}"), r"\1=<redacted-secret>"),
	(re.compile(r"(?i)\b[A-Z]:\\Users\\[^\\\s]+"), "<redacted-home>"),
	(re.compile(r"/(?:home|Users)/[^/\s]+"), "<redacted-home>"),
)


def analyze_candidate(
	project_root: Path,
	candidate: dict[str, Any],
	contract_relative_path: str = DEFAULT_CONTRACT_PATH,
) -> dict[str, Any]:
	candidate = _enrich_environment(project_root, deepcopy(candidate))
	contract_result = load_contract(project_root, contract_relative_path)
	contract_data = contract_result.get("contract", {})
	feedback_policy = contract_data.get("feedback", {}) if isinstance(contract_data, dict) else {}
	issues = [
		{
			"severity": "error",
			"code": str(item["code"]),
			"path": str(item["path"]),
			"message": str(item["message"]),
		}
		for item in validate_schema_file(candidate, SCHEMA_ROOT / "feedback_candidate.schema.json")
	]
	if not issues:
		issues.extend(_evidence_policy_issues(candidate, feedback_policy))
	if issues:
		return {
			"ok": False,
			"classification": "invalid",
			"eligible_for_official_issue": False,
			"candidate": {},
			"fingerprint": "",
			"reasons": [],
			"issues": issues,
		}
	extra_literals = feedback_policy.get("extra_redaction_literals", []) if isinstance(feedback_policy, dict) else []
	sanitized = _sanitize_value(candidate, project_root, extra_literals)
	classification, confidence, reasons = _classify(sanitized)
	eligible = classification in {
		"framework_bug",
		"framework_feature",
		"documentation_gap",
		"adapter_contract_gap",
	} and _has_minimum_evidence(sanitized, classification)
	if not eligible:
		reasons.append("Candidate is not yet specific enough for the official GF issue tracker.")
	fingerprint_payload = {
		"classification": classification,
		"title": sanitized.get("title", ""),
		"expected": sanitized.get("expected", ""),
		"actual": sanitized.get("actual", ""),
		"requested_change": sanitized.get("requested_change", ""),
		"reproduction_steps": sanitized.get("reproduction_steps", []),
	}
	return {
		"ok": bool(contract_result.get("ok")) and not issues,
		"classification": classification,
		"confidence": confidence,
		"eligible_for_official_issue": eligible,
		"candidate": sanitized,
		"fingerprint": sha256_bytes(canonical_json_bytes(fingerprint_payload)),
		"reasons": reasons,
		"issues": issues + [
			item for item in contract_result.get("issues", [])
			if isinstance(item, dict) and item.get("severity") == "error"
		],
	}


def draft_feedback(
	project_root: Path,
	candidate: dict[str, Any],
	contract_relative_path: str = DEFAULT_CONTRACT_PATH,
	write: bool = True,
) -> dict[str, Any]:
	analysis = analyze_candidate(project_root, candidate, contract_relative_path)
	if not analysis.get("ok") or not analysis.get("eligible_for_official_issue"):
		return {"ok": False, "analysis": analysis, "path": "", "draft": {}, "issues": analysis.get("issues", [])}
	contract_result = load_contract(project_root, contract_relative_path)
	contract_data = contract_result["contract"]
	feedback_policy = contract_data["feedback"]
	sanitized = analysis["candidate"]
	fingerprint = str(analysis["fingerprint"])
	payload = {
		"repository": feedback_policy["repository"],
		"title": _issue_title(str(analysis["classification"]), str(sanitized["title"])),
		"body": _issue_body(sanitized, analysis),
		"labels": [],
	}
	draft = {
		"schema_version": 1,
		"fingerprint": fingerprint,
		"classification": analysis["classification"],
		"eligible_for_official_issue": True,
		"contract_sha256": contract_result["sha256"],
		"payload": payload,
		"submission_sha256": sha256_bytes(canonical_json_bytes(payload)),
	}
	relative_path = f"{DEFAULT_FEEDBACK_ROOT}/{fingerprint}.json"
	if write:
		atomic_write_json(resolve_project_path(project_root, relative_path), draft)
	return {"ok": True, "analysis": analysis, "path": relative_path, "draft": draft, "issues": []}


def load_draft(project_root: Path, relative_path: str) -> dict[str, Any]:
	normalized = relative_path.strip().replace("\\", "/")
	if not normalized.startswith(DEFAULT_FEEDBACK_ROOT + "/"):
		raise ValueError(f"Feedback drafts must stay under {DEFAULT_FEEDBACK_ROOT}.")
	draft = read_json_object(
		resolve_project_path(project_root, normalized, must_exist=True),
		max_bytes=512 * 1024,
	)
	_validate_draft_integrity(draft)
	return draft


def prepare_submission(
	project_root: Path,
	draft: dict[str, Any],
	contract_relative_path: str = DEFAULT_CONTRACT_PATH,
) -> dict[str, Any]:
	try:
		_validate_draft_integrity(draft)
	except ValueError as exc:
		return {"ok": False, "ready": False, "issues": [str(exc)]}
	contract_result = load_contract(project_root, contract_relative_path)
	if not contract_result.get("ok"):
		return {"ok": False, "ready": False, "issues": ["Project contract is invalid."]}
	contract_data = contract_result["contract"]
	policy = contract_data["feedback"]
	issues: list[str] = []
	if policy.get("submission_policy") != "approval_required":
		issues.append("Feedback submission policy must remain approval_required.")
	if policy.get("allow_network_submission") is not True:
		issues.append("Project contract does not opt in to network issue submission.")
	if draft.get("contract_sha256") != contract_result.get("sha256"):
		issues.append("Feedback draft was created against a different project contract.")
	payload = draft.get("payload", {})
	if not isinstance(payload, dict) or payload.get("repository") != policy.get("repository"):
		issues.append("Feedback draft repository does not match the project contract.")
	return {
		"ok": not issues,
		"ready": not issues,
		"repository": payload.get("repository", "") if isinstance(payload, dict) else "",
		"title": payload.get("title", "") if isinstance(payload, dict) else "",
		"body": payload.get("body", "") if isinstance(payload, dict) else "",
		"confirmation_sha256": draft.get("submission_sha256", ""),
		"fingerprint": draft.get("fingerprint", ""),
		"issues": issues,
	}


def check_duplicates(
	project_root: Path,
	draft: dict[str, Any],
	runner: Callable[..., subprocess.CompletedProcess[str]] = subprocess.run,
) -> dict[str, Any]:
	try:
		_validate_draft_integrity(draft)
	except ValueError as exc:
		return {"ok": False, "duplicates": [], "issues": [str(exc)]}
	gh_path = shutil.which("gh")
	if gh_path is None:
		return {"ok": False, "duplicates": [], "issues": ["GitHub CLI (gh) is not available."]}
	payload = draft["payload"]
	fingerprint = str(draft["fingerprint"])
	command = [
		gh_path,
		"issue",
		"list",
		"--repo",
		str(payload["repository"]),
		"--state",
		"all",
		"--search",
		fingerprint,
		"--limit",
		"20",
		"--json",
		"number,title,url,state,body",
	]
	try:
		completed = runner(command, cwd=project_root, capture_output=True, text=True, encoding="utf-8", timeout=30, check=False)
	except (OSError, subprocess.SubprocessError) as exc:
		return {"ok": False, "duplicates": [], "issues": [f"GitHub duplicate check failed: {exc}"]}
	if completed.returncode != 0:
		return {"ok": False, "duplicates": [], "issues": [completed.stderr.strip() or "GitHub duplicate check failed."]}
	try:
		values = json.loads(completed.stdout or "[]")
	except json.JSONDecodeError as exc:
		return {"ok": False, "duplicates": [], "issues": [f"GitHub duplicate result is invalid JSON: {exc}"]}
	duplicates = [
		item for item in values
		if isinstance(item, dict) and fingerprint in str(item.get("body", ""))
	] if isinstance(values, list) else []
	return {"ok": True, "duplicates": duplicates, "issues": []}


def submit_issue(
	project_root: Path,
	draft: dict[str, Any],
	confirmation_sha256: str,
	contract_relative_path: str = DEFAULT_CONTRACT_PATH,
	runner: Callable[..., subprocess.CompletedProcess[str]] = subprocess.run,
	human_approved: bool = False,
) -> dict[str, Any]:
	if not human_approved:
		return {
			"ok": False,
			"url": "",
			"issues": ["Interactive human approval is required before GitHub issue submission."],
		}
	prepared = prepare_submission(project_root, draft, contract_relative_path)
	if not prepared.get("ready"):
		return {"ok": False, "url": "", "issues": prepared.get("issues", [])}
	if not confirmation_sha256 or confirmation_sha256 != prepared.get("confirmation_sha256"):
		return {"ok": False, "url": "", "issues": ["Exact submission confirmation hash is required."]}
	duplicate_report = check_duplicates(project_root, draft, runner)
	if not duplicate_report.get("ok"):
		return {"ok": False, "url": "", "issues": duplicate_report.get("issues", [])}
	if duplicate_report.get("duplicates"):
		return {
			"ok": False,
			"url": "",
			"duplicates": duplicate_report["duplicates"],
			"issues": ["A GF issue with the same evidence fingerprint already exists."],
		}
	gh_path = shutil.which("gh")
	if gh_path is None:
		return {"ok": False, "url": "", "issues": ["GitHub CLI (gh) is not available."]}
	payload = draft["payload"]
	temporary_relative = f"{DEFAULT_FEEDBACK_ROOT}/.submit-{os.getpid()}-{secrets.token_hex(8)}.md"
	temporary = resolve_project_path(project_root, temporary_relative)
	try:
		atomic_write_text(temporary, str(payload["body"]))
		command = [
			gh_path,
			"issue",
			"create",
			"--repo",
			str(payload["repository"]),
			"--title",
			str(payload["title"]),
			"--body-file",
			str(temporary),
		]
		completed = runner(command, cwd=project_root, capture_output=True, text=True, encoding="utf-8", timeout=60, check=False)
	except (OSError, subprocess.SubprocessError, ValueError) as exc:
		return {"ok": False, "url": "", "issues": [f"GitHub issue submission failed: {exc}"]}
	finally:
		if temporary.is_file():
			temporary.unlink()
	if completed.returncode != 0:
		return {"ok": False, "url": "", "issues": [completed.stderr.strip() or "GitHub issue submission failed."]}
	url = completed.stdout.strip().splitlines()[-1] if completed.stdout.strip() else ""
	return {"ok": bool(url), "url": url, "fingerprint": draft["fingerprint"], "issues": [] if url else ["GitHub CLI returned no issue URL."]}


def _classify(candidate: dict[str, Any]) -> tuple[str, str, list[str]]:
	scope = str(candidate.get("suspected_scope", "unknown"))
	reasons: list[str] = []
	if scope == "project":
		return "project_issue", "high", ["Candidate is explicitly scoped to project code or project configuration."]
	if scope == "documentation":
		return "documentation_gap", "high", ["Candidate is explicitly scoped to GF documentation."]
	if scope == "adapter":
		return "adapter_contract_gap", "medium", ["Candidate concerns a provider adapter boundary, not provider-specific business logic."]
	if scope == "framework":
		if candidate.get("expected") and candidate.get("actual") and candidate.get("reproduction_steps"):
			return "framework_bug", "high", ["Framework scope includes expected, actual, and reproduction evidence."]
		if candidate.get("requested_change"):
			return "framework_feature", "medium", ["Framework scope requests a provider-neutral reusable mechanism."]
		return "uncertain", "low", ["Framework scope lacks bug evidence or a concrete reusable change."]
	if candidate.get("expected") and candidate.get("actual") and candidate.get("reproduction_steps"):
		reasons.append("Behavior resembles a bug, but ownership remains unknown.")
	return "uncertain", "low", reasons or ["Candidate ownership remains unknown."]


def _has_minimum_evidence(candidate: dict[str, Any], classification: str) -> bool:
	if not candidate.get("title") or not candidate.get("summary"):
		return False
	if classification == "framework_bug":
		return bool(candidate.get("expected") and candidate.get("actual") and candidate.get("reproduction_steps"))
	if classification in ("framework_feature", "adapter_contract_gap"):
		return bool(candidate.get("requested_change"))
	if classification == "documentation_gap":
		return bool(candidate.get("actual") or candidate.get("requested_change"))
	return False


def _sanitize_value(value: Any, project_root: Path, extra_literals: Any) -> Any:
	if isinstance(value, dict):
		return {str(key): _sanitize_value(item, project_root, extra_literals) for key, item in value.items()}
	if isinstance(value, list):
		return [_sanitize_value(item, project_root, extra_literals) for item in value]
	if not isinstance(value, str):
		return value
	text = value
	path_flags = re.IGNORECASE if os.name == "nt" else 0
	for root_text in sorted({str(project_root), project_root.as_posix()}, key=len, reverse=True):
		text = re.sub(re.escape(root_text), "<project>", text, flags=path_flags)
	for pattern, replacement in _DEFAULT_REDACTIONS:
		text = pattern.sub(replacement, text)
	if isinstance(extra_literals, list):
		for literal in sorted(
			(item for item in extra_literals if isinstance(item, str) and item),
			key=len,
			reverse=True,
		):
			text = text.replace(literal, "<redacted-project-literal>")
	return text


def _evidence_policy_issues(candidate: dict[str, Any], feedback_policy: Any) -> list[dict[str, str]]:
	policy = feedback_policy if isinstance(feedback_policy, dict) else {}
	issues: list[dict[str, str]] = []
	for index, record in enumerate(candidate.get("evidence", [])):
		if not isinstance(record, dict):
			continue
		kind = str(record.get("kind", ""))
		if kind == "source_snippet" and policy.get("allow_source_snippets") is not True:
			issues.append({
				"severity": "error",
				"code": "source_snippet_not_allowed",
				"path": f"$.evidence[{index}]",
				"message": "Project feedback policy does not allow source snippets.",
			})
		if kind == "log_excerpt" and policy.get("allow_log_excerpt") is not True:
			issues.append({
				"severity": "error",
				"code": "log_excerpt_not_allowed",
				"path": f"$.evidence[{index}]",
				"message": "Project feedback policy does not allow log excerpts.",
			})
	return issues


def _enrich_environment(project_root: Path, candidate: dict[str, Any]) -> dict[str, Any]:
	environment = candidate.get("environment")
	if not isinstance(environment, dict):
		return candidate
	try:
		from .snapshot import build_snapshot

		snapshot = build_snapshot(project_root)
	except (OSError, ValueError, RuntimeError):
		return candidate
	framework = snapshot.get("framework", {})
	project = snapshot.get("project", {})
	if isinstance(framework, dict):
		if not environment.get("gf_version"):
			environment["gf_version"] = str(framework.get("version", ""))
		if not environment.get("packages"):
			environment["packages"] = list(framework.get("packages", []))
	if isinstance(project, dict) and not environment.get("godot_version"):
		features = project.get("godot_features", [])
		if isinstance(features, list):
			versions = [str(item) for item in features if re.fullmatch(r"\d+\.\d+(?:\.\d+)?", str(item))]
			if versions:
				environment["godot_version"] = versions[0]
	return candidate


def _issue_title(classification: str, title: str) -> str:
	prefixes = {
		"framework_bug": "[Bug]",
		"framework_feature": "[Feature]",
		"documentation_gap": "[Docs]",
		"adapter_contract_gap": "[Adapter]",
	}
	return f"{prefixes.get(classification, '[Feedback]')} {title}"[:200]


def _issue_body(candidate: dict[str, Any], analysis: dict[str, Any]) -> str:
	environment = candidate.get("environment", {})
	steps = candidate.get("reproduction_steps", [])
	evidence = candidate.get("evidence", [])
	packages = environment.get("packages", []) if isinstance(environment, dict) else []
	lines = [
		"## Summary",
		"",
		str(candidate.get("summary", "")),
		"",
		"## Boundary Triage",
		"",
		f"- Classification: `{analysis.get('classification', '')}`",
		f"- Suspected scope: `{candidate.get('suspected_scope', '')}`",
		"- This report contains no automatic file attachment or private source upload.",
		"",
		"## Expected",
		"",
		str(candidate.get("expected", "")) or "Not applicable.",
		"",
		"## Actual",
		"",
		str(candidate.get("actual", "")) or "Not applicable.",
		"",
		"## Reproduction",
		"",
	]
	lines.extend(f"{index}. {step}" for index, step in enumerate(steps, start=1))
	if not steps:
		lines.append("Not applicable.")
	lines.extend(["", "## Requested Change", "", str(candidate.get("requested_change", "")) or "Not applicable."])
	lines.extend(["", "## Evidence", ""])
	lines.extend(
		f"- `{item.get('kind', 'observation')}`: {item.get('text', '')}"
		for item in evidence
		if isinstance(item, dict)
	)
	if not evidence:
		lines.append("- No additional excerpt supplied.")
	lines.extend([
		"",
		"## Environment",
		"",
		f"- Godot: `{environment.get('godot_version', '')}`",
		f"- GF: `{environment.get('gf_version', '')}`",
		f"- Platform: `{environment.get('platform', '')}`",
		f"- Packages: {', '.join(f'`{item}`' for item in packages) if packages else 'Not supplied.'}",
		f"- Impact: `{candidate.get('impact', '')}`",
		f"- Workaround: {candidate.get('workaround', '') or 'None known.'}",
		"",
		f"<!-- gf-ai-fingerprint: {analysis.get('fingerprint', '')} -->",
	])
	return "\n".join(lines).strip() + "\n"


def _validate_draft_integrity(draft: dict[str, Any]) -> None:
	required = {
		"schema_version",
		"fingerprint",
		"classification",
		"eligible_for_official_issue",
		"contract_sha256",
		"payload",
		"submission_sha256",
	}
	if set(draft) != required or draft.get("schema_version") != 1:
		raise ValueError("Feedback draft structure is invalid.")
	payload = draft.get("payload")
	if not isinstance(payload, dict) or set(payload) != {"repository", "title", "body", "labels"}:
		raise ValueError("Feedback draft payload structure is invalid.")
	expected = sha256_bytes(canonical_json_bytes(payload))
	if draft.get("submission_sha256") != expected:
		raise ValueError("Feedback draft payload hash does not match its content.")
	fingerprint = str(draft.get("fingerprint", ""))
	if re.fullmatch(r"[0-9a-f]{64}", fingerprint) is None:
		raise ValueError("Feedback draft fingerprint is invalid.")
	if f"<!-- gf-ai-fingerprint: {fingerprint} -->" not in str(payload.get("body", "")):
		raise ValueError("Feedback draft body is not bound to its fingerprint.")
