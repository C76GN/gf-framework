#!/usr/bin/env python3
"""为 Project Layout 的原生 GDScript 检查提供有界传输。

编辑器和维护适配器使用同一套 GDScript 会话校验配置并分析项目。配置编译、选择器、
正则和规则求值均由该会话负责。
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
	"""核验受信的布局检查产物，项目配置本身留给原生规则解释。"""
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
	snapshot_path: str = "",
	native_executor: Callable[[dict[str, Any]], dict[str, Any]],
) -> dict[str, Any]:
	"""从固定身份的文件读取一份 UTF-8 输入，将产品规则判定交给 Godot。"""
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
		if snapshot_path and profile_path:
			raise PinnedReadError("project_layout.snapshot_profile_conflict")
		candidates = (snapshot_path,) if snapshot_path else ((profile_path,) if profile_path else PROJECT_PROFILE_DEFAULT_FILES)
		for candidate in candidates:
			if not profile_path and not snapshot_path and candidate == ".gf/project_profile.json" and not os.path.lexists(source_root / ".gf"):
				# 对可选父目录的缺失也须固定其身份。观察期间如果目录突然出现，应拒绝该输入。
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
				if profile_path or snapshot_path:
					raise PinnedReadError("project_layout.profile_unavailable")
				continue
			base.update({"profile_found": True, "profile_path": str(path)})
			request: dict[str, Any] = {
				"schema_version": 1, "operation": "analyze",
				"profile_text": text, "profile_source_path": path.as_posix(),
				"options": {"source_root": source_root.as_posix()},
			}
			if snapshot_path:
				request = {"schema_version": 1, "operation": "analyze_snapshot", "snapshot_text": text}
				base["snapshot_path"] = str(path)
			report = native_executor(request)
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
		if error.cleanup_errors:
			base["cleanup_errors"] = list(error.cleanup_errors)
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
