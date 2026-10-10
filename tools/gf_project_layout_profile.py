#!/usr/bin/env python3
"""Bounded transport to the single native Project Layout authority.

Python deliberately has no profile compiler, selectors, regular expressions or
rule evaluator. The same GDScript session owns admission and analysis in both
the editor and this maintenance adapter.
"""

from __future__ import annotations

from pathlib import Path
import hashlib
import os
import re
from typing import Any, Callable
from gf_project_layout_native import NativeExecutionError

from gf_path_security import (
	PinnedReadError,
	absolute_lexical_path,
	path_has_reparse_component,
	path_is_inside_lexical,
	read_optional_pinned_utf8_regular_file,
)


ROOT = Path(__file__).resolve().parents[1]
PROJECT_PROFILE_DEFAULT_FILES = (
	"gf_project_profile.json", ".gf/project_profile.json", "project_profile.json",
)
PROJECT_PROFILE_MAX_BYTES = 1024 * 1024


def project_profile_artifacts(*, root: Path = ROOT) -> dict[str, Any]:
	"""Check trusted artifacts without interpreting a project's profile."""
	paths = (
		"addons/gf/tools/project_layout/gf_project_layout_session.gd",
		"addons/gf/tools/project_layout/gf_project_layout_profile_compiler.gd",
		"addons/gf/tools/project_layout/cli/gf_project_layout_cli.gd",
		"addons/gf/tools/project_layout/contracts/project_profile_v2.contract.json",
		"docs/adr/0002-project-layout-authority.md",
	)
	issues = []
	artifacts = {}
	for path in paths:
		try:
			text = read_optional_pinned_utf8_regular_file(root, path, max_bytes=PROJECT_PROFILE_MAX_BYTES)
			if text is None or not text.strip():
				raise PinnedReadError("project_layout.artifact_unavailable")
			artifacts[path] = text
		except PinnedReadError as error:
			issues.append({"kind": error.rule_id, "severity": "error", "path": path})
	if not issues:
		compiler_path = paths[1]
		contract_path = paths[3]
		declared = re.findall(r'^const _CANONICAL_CONTRACT_SHA256: String = "([a-f0-9]{64})"$',
			artifacts[compiler_path], re.MULTILINE)
		actual = hashlib.sha256(artifacts[contract_path].encode("utf-8")).hexdigest()
		if declared != [actual]:
			issues.append({"kind": "project_layout.contract_artifact_stale", "severity": "error", "path": contract_path})
	return {"ok": not issues, "issue_count": len(issues), "issues": issues,
		"executor": "static_artifacts", "artifact_count": len(paths)}


def project_profile_boundary(
	profile_path: str = "",
	fail_on_warnings: bool = False,
	*,
	root: Path = ROOT,
	native_executor: Callable[[dict[str, Any]], dict[str, Any]],
) -> dict[str, Any]:
	"""Read one pinned UTF-8 input and delegate every product decision to Godot."""
	source_root = absolute_lexical_path(root)
	base: dict[str, Any] = {
		"root": str(source_root), "profile_found": False, "profile_path": "",
		"executor": "godot_gdscript", "contract_version": 2,
		"evaluation_complete": False, "evaluation_status": "not_applicable",
		"file_count": 0, "issues": [], "process_boundary_quiet": True,
	}
	try:
		if path_has_reparse_component(source_root) or not source_root.is_dir():
			raise PinnedReadError("project_layout.source_root_unavailable")
		candidates = (profile_path,) if profile_path else PROJECT_PROFILE_DEFAULT_FILES
		for candidate in candidates:
			if not profile_path and candidate == ".gf/project_profile.json" and not os.path.lexists(source_root / ".gf"):
				# Prove the absent optional parent as a pinned leaf. A directory that
				# appears during this observation fails closed instead of being skipped.
				if read_optional_pinned_utf8_regular_file(source_root, ".gf", max_bytes=0) is None:
					continue
			path = absolute_lexical_path(source_root / candidate)
			if not path_is_inside_lexical(source_root, path) or path == source_root:
				raise PinnedReadError("project_layout.profile_outside_source_root")
			relative = path.relative_to(source_root).as_posix()
			text = read_optional_pinned_utf8_regular_file(
				source_root, relative, max_bytes=PROJECT_PROFILE_MAX_BYTES,
			)
			if text is None:
				if profile_path:
					raise PinnedReadError("project_layout.profile_unavailable")
				continue
			base.update({"profile_found": True, "profile_path": str(path)})
			report = native_executor({
				"schema_version": 1, "operation": "analyze",
				"profile_text": text, "profile_source_path": path.as_posix(),
				"options": {"source_root": source_root.as_posix(), "root_path": source_root.as_posix()},
			})
			base["analysis"] = report
			base["issues"] = report.get("issues", [])
			base["evaluation_complete"] = report.get("evaluation_complete", False)
			base["evaluation_status"] = report.get("evaluation_status", "unavailable")
			base["file_count"] = report.get("file_count", 0)
			base["coverage"] = report.get("graph", {}).get("scope", {})
			break
	except NativeExecutionError as error:
		base["evaluation_status"] = "unavailable"
		base["process_boundary_quiet"] = error.process_boundary_quiet
		base["issues"] = [{
			"kind": error.reason, "severity": "error", "path": "",
			"message": "The trusted native Project Layout executor did not complete.",
		}]
	except PinnedReadError as error:
		base["evaluation_status"] = "unavailable"
		base["issues"] = [{
			"kind": error.rule_id, "severity": "error", "path": "",
			"message": "Project Layout input could not be read within its boundary.",
		}]
	return _finish(base, fail_on_warnings)


def _finish(payload: dict[str, Any], fail_on_warnings: bool) -> dict[str, Any]:
	issues = payload["issues"]
	for severity in ("error", "warning", "info"):
		payload[f"{severity}_count"] = sum(
			1 for issue in issues if issue.get("severity") == severity
		)
	payload["issue_count"] = len(issues)
	payload["ok"] = (
		payload["error_count"] == 0
		and (not fail_on_warnings or payload["warning_count"] == 0)
		and (not payload["profile_found"] or payload["evaluation_complete"] is True)
	)
	return payload
