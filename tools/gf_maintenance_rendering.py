#!/usr/bin/env python3
"""Human-readable output rendering for the GF maintenance CLI."""

from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path
from typing import Any


_JSON_OUTPUT_PATH: Path | None = None


def set_json_output_path(path: Path | None) -> None:
	"""Route JSON output to an explicit UTF-8 file instead of shell stdout."""
	global _JSON_OUTPUT_PATH
	_JSON_OUTPUT_PATH = path


def print_output(data: dict[str, Any], as_json: bool, renderer: Any) -> None:
	if as_json:
		payload = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
		if _JSON_OUTPUT_PATH is not None:
			write_utf8_json_output(_JSON_OUTPUT_PATH, payload)
		else:
			print(payload, end="")
	else:
		print(renderer(data))


def write_utf8_json_output(path: Path, payload: str) -> None:
	"""Atomically write UTF-8 JSON without a byte-order mark."""
	path.parent.mkdir(parents=True, exist_ok=True)
	temporary_path: Path | None = None
	try:
		with tempfile.NamedTemporaryFile(
			mode="w",
			encoding="utf-8",
			newline="\n",
			dir=path.parent,
			prefix=f".{path.name}.",
			suffix=".tmp",
			delete=False,
		) as temporary_file:
			temporary_path = Path(temporary_file.name)
			temporary_file.write(payload)
			temporary_file.flush()
			os.fsync(temporary_file.fileno())
		os.replace(temporary_path, path)
		temporary_path = None
	finally:
		if temporary_path is not None:
			temporary_path.unlink(missing_ok=True)


def render_summary_text(data: dict[str, Any]) -> str:
	release = data["release"]
	catalog = data["api_catalog"]
	release_ok = release.get("ok")
	release_state = "not-run" if release_ok == None else str(release_ok)
	lines = [
		f"root: {data['root']}",
		f"git: {data['git']['branch']} {data['git']['head']} dirty={data['git']['dirty_file_count']}",
		f"version: {release['version']} release_ok={release_state}",
		f"api: classes={catalog.get('class_count', 0)} methods={catalog.get('method_count', 0)} schema={catalog.get('schema_version', '')}",
		"checks: python tools/gf_maintenance.py check --suite full",
		"mcp: python tools/gf_mcp_server.py",
	]
	if release_ok == None:
		lines.append("release: skipped; use `python tools/gf_maintenance.py summary --release` for release diagnostics")
	elif release["issues"]:
		lines.append("release issues:")
		lines.extend(f"- {issue}" for issue in release["issues"])
	return "\n".join(lines)


def render_api_search_text(data: dict[str, Any]) -> str:
	lines = [f"query: {data['query']} matches={data['count']}"]
	for item in data["results"]:
		lines.append(f"- {item['class_name']} | {item['module']} | {item['path']}")
		for match in item["member_matches"][:3]:
			lines.append(f"  - {match['kind']} {match['signature']}")
	return "\n".join(lines)


def render_api_class_text(data: dict[str, Any]) -> str:
	if not data.get("found"):
		return data["message"]
	lines = [
		f"{data['class_name']} extends {data['extends']}",
		f"path: {data['path']}",
		f"module: {data['module']}",
	]
	for line in data.get("summary", [])[:5]:
		lines.append(f"summary: {line}")
	for group in ("signals", "enums", "constants", "variables", "methods"):
		items = data.get(group, [])
		if not items:
			continue
		lines.append(f"{group}:")
		for item in items:
			lines.append(f"- {item['signature']}")
	return "\n".join(lines)


def render_api_module_text(data: dict[str, Any]) -> str:
	if not data.get("found"):
		lines = [data["message"]]
		available = data.get("available_modules", [])
		if available:
			lines.append("available modules:")
			lines.extend(f"- {module}" for module in available)
		return "\n".join(lines)
	lines = [
		f"query: {data['query']}",
		f"classes: {data['returned_class_count']}/{data['class_count']} truncated={data['truncated']}",
		"modules:",
	]
	for module, stats in sorted(data["matched_modules"].items()):
		lines.append(f"- {module}: classes={stats['classes']} methods={stats['methods']}")
	lines.append("classes:")
	for item in data["classes"]:
		lines.append(f"- {item['class_name']} extends {item['extends']} | {item['path']}")
		counts = item["member_counts"]
		lines.append(
			"  members: "
			f"signals={counts['signals']} enums={counts['enums']} constants={counts['constants']} "
			f"variables={counts['variables']} methods={counts['methods']}"
		)
	return "\n".join(lines)


def render_workspace_status_text(data: dict[str, Any]) -> str:
	lines = [
		f"root: {data['root']}",
		f"git: {data['branch']} {data['head']} dirty={data['dirty_file_count']}",
		f"scope: {data.get('scope', 'worktree')}",
		f"ai_analysis_ignored: {data['ai_analysis_ignored']}",
	]
	if data.get("selected_paths"):
		lines.append("selected paths:")
		lines.extend(f"- {path}" for path in data["selected_paths"])
	for category, files in data["categories"].items():
		if not files:
			continue
		lines.append(f"{category}: {len(files)}")
		lines.extend(f"- {item['status']} {item['path']}" for item in files[:20])
		if len(files) > 20:
			lines.append(f"- ... {len(files) - 20} more")
	if data["recommended_checks"]:
		lines.append("recommended checks:")
		lines.extend(f"- {command}" for command in data["recommended_checks"])
	return "\n".join(lines)


def render_project_settings_drift_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"project_settings_drift: ok={data['ok']} "
			f"unstaged={data['unstaged_changed']} staged={data['staged_changed']}"
		),
	]
	for issue in data["issues"]:
		lines.append(f"- {issue}")
	if data["unstaged_diff"]:
		lines.append(indent_text(trim_text(data["unstaged_diff"], 4000), "  unstaged_diff: "))
	if data["staged_diff"]:
		lines.append(indent_text(trim_text(data["staged_diff"], 4000), "  staged_diff: "))
	return "\n".join(lines)


def render_path_hygiene_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"path_hygiene: ok={data['ok']} "
			f"tracked={data['tracked_file_count']} "
			f"untracked={data.get('untracked_file_count', 0)} "
			f"scanned={data.get('scanned_file_count', data['tracked_file_count'])} "
			f"issues={data['issue_count']}"
		),
	]
	for issue in data["issues"]:
		lines.append(f"- {issue['kind']}: {issue.get('path', '')} {issue.get('message', '')}".rstrip())
		if issue.get("paths"):
			for path in issue["paths"]:
				lines.append(f"  path: {path}")
	return "\n".join(lines)


def render_api_since_touched_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"api_since_touched: ok={data['ok']} "
			f"changed_gdscript={data['changed_gdscript_file_count']} "
			f"scanned={data['scanned_file_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		declaration = issue.get("declaration", "")
		suffix = f" {declaration}" if declaration else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_dependency_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"dependency_boundary: ok={data['ok']} "
			f"manifests={data['manifest_count']} "
			f"extension_ids={data['extension_id_count']} "
			f"standard_classes={data['standard_class_count']} "
			f"extension_classes={data['extension_class_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for issue in data["issues"]:
		details = []
		for key in ("extension_id", "field", "symbol"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {issue.get('path', '')}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_changelog_policy_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"changelog_policy: ok={data['ok']} "
			f"version={data['framework_version']} "
			f"mode={data['mode']} "
			f"release_target={data.get('release_target_version', '')} "
			f"sections={data['section_count']} "
			f"issues={data['issue_count']}"
		),
	]
	api_baseline = data.get("api_baseline", {})
	if api_baseline:
		summary = api_baseline.get("summary", {})
		lines.append(
			"- api_baseline: "
			f"ok={api_baseline.get('ok', False)} "
			f"base={api_baseline.get('base_tag', '')} "
			f"breaking={summary.get('breaking_change_count', 0)} "
			f"compatible={summary.get('compatible_change_count', 0)}"
		)
	if data.get("extension_count") is not None:
		lines.append(
			"- extensions: "
			f"count={data.get('extension_count', 0)} "
			f"mismatches={len(data.get('extension_mismatches', []))}"
		)
	for section in data["sections"]:
		lines.append(
			f"- section: line={section['line']} version={section['version']} heading={section['heading']}"
		)
	for issue in data["issues"]:
		lines.append(f"- {issue}")
	return "\n".join(lines)


def render_public_docs_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"public_docs_boundary: ok={data['ok']} "
			f"files={data['file_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		symbol = issue.get("symbol", "")
		suffix = f" ({symbol})" if symbol else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_public_api_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"public_api_boundary: ok={data['ok']} "
			f"files={data['file_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		symbol = issue.get("symbol", "")
		suffix = f" ({symbol})" if symbol else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def format_counter_summary(items: list[dict[str, Any]], limit: int = 8) -> str:
	parts: list[str] = []
	for item in items[:limit]:
		parts.append(f"{item.get('key', '')}={item.get('count', 0)}")
	if len(items) > limit:
		parts.append(f"...+{len(items) - limit}")
	return ", ".join(parts)


def render_resource_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"resource_boundary: ok={data['ok']} "
			f"report_only={data.get('report_only', True)} "
			f"files={data['file_count']} "
			f"issues={data['issue_count']} "
			f"warnings={data.get('warning_count', 0)} "
			f"info={data.get('info_count', 0)} "
			f"observations={data.get('observation_count', 0)}"
		),
	]
	kind_summary = format_counter_summary(data.get("issue_kind_counts", []))
	extension_summary = format_counter_summary(data.get("target_extension_counts", []))
	source_kind_summary = format_counter_summary(data.get("source_kind_counts", []))
	source_package_summary = format_counter_summary(data.get("source_package_counts", []))
	target_package_summary = format_counter_summary(data.get("target_package_counts", []))
	source_target_package_summary = format_counter_summary(data.get("source_target_package_counts", []))
	observation_kind_summary = format_counter_summary(data.get("observation_kind_counts", []))
	observation_extension_summary = format_counter_summary(data.get("observation_target_extension_counts", []))
	observation_source_kind_summary = format_counter_summary(data.get("observation_source_kind_counts", []))
	observation_source_package_summary = format_counter_summary(data.get("observation_source_package_counts", []))
	observation_target_package_summary = format_counter_summary(data.get("observation_target_package_counts", []))
	observation_source_target_package_summary = format_counter_summary(data.get("observation_source_target_package_counts", []))
	if kind_summary:
		lines.append(f"kinds: {kind_summary}")
	if extension_summary:
		lines.append(f"target_extensions: {extension_summary}")
	if source_kind_summary:
		lines.append(f"source_kinds: {source_kind_summary}")
	if source_package_summary:
		lines.append(f"source_packages: {source_package_summary}")
	if target_package_summary:
		lines.append(f"target_packages: {target_package_summary}")
	if source_target_package_summary:
		lines.append(f"source_target_packages: {source_target_package_summary}")
	if observation_kind_summary:
		lines.append(f"observation_kinds: {observation_kind_summary}")
	if observation_extension_summary:
		lines.append(f"observation_target_extensions: {observation_extension_summary}")
	if observation_source_kind_summary:
		lines.append(f"observation_source_kinds: {observation_source_kind_summary}")
	if observation_source_package_summary:
		lines.append(f"observation_source_packages: {observation_source_package_summary}")
	if observation_target_package_summary:
		lines.append(f"observation_target_packages: {observation_target_package_summary}")
	if observation_source_target_package_summary:
		lines.append(f"observation_source_target_packages: {observation_source_target_package_summary}")
	warning_issues = [issue for issue in data["issues"] if issue.get("severity") == "warning"]
	info_issues = [issue for issue in data["issues"] if issue.get("severity") != "warning"]
	display_limit = 12
	display_issues = [*warning_issues[:display_limit]]
	if len(display_issues) < display_limit:
		display_issues.extend(info_issues[:display_limit - len(display_issues)])
	for issue in display_issues:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		target = issue.get("target", "")
		callee = issue.get("callee", "")
		severity = issue.get("severity", "")
		source_kind = issue.get("source_kind", "")
		source_package = issue.get("source_package", "")
		target_package = issue.get("target_package", "")
		details = []
		if severity:
			details.append(f"severity={severity}")
		if callee:
			details.append(f"callee={callee}")
		if source_kind:
			details.append(f"source_kind={source_kind}")
		if source_package:
			details.append(f"source_package={source_package}")
		if target_package:
			details.append(f"target_package={target_package}")
		if target:
			details.append(f"target={target}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	if len(data["issues"]) > len(display_issues):
		lines.append(f"... {len(data['issues']) - len(display_issues)} more issue(s) omitted from text output; use --json for the full report.")
	if data.get("observation_count", 0) > 0:
		lines.append("Observations are summarized separately; pass --include-observations --json for full records.")
	return "\n".join(lines)


def render_content_package_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"content_package_boundary: ok={data['ok']} "
			f"manifests={data['manifest_count']} "
			f"packages={data['package_count']} "
			f"resources={data['resource_count']} "
			f"issues={data['issue_count']}"
		),
	]
	kind_summary = format_counter_summary(data.get("issue_kind_counts", []))
	if kind_summary:
		lines.append(f"kinds: {kind_summary}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("field", "row_index", "row_key", "actual_value"):
			if key in issue:
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_asset_lifecycle_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"asset_lifecycle_boundary: ok={data['ok']} "
			f"report_only={data.get('report_only', True)} "
			f"files={data['file_count']} "
			f"issues={data['issue_count']} "
			f"warnings={data.get('warning_count', 0)} "
			f"info={data.get('info_count', 0)}"
		),
	]
	kind_summary = format_counter_summary(data.get("issue_kind_counts", []))
	if kind_summary:
		lines.append(f"kinds: {kind_summary}")
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		details = []
		for key in ("severity", "callee", "target"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_project_profile_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"project_profile_boundary: ok={data['ok']} "
			f"profile_found={data.get('profile_found', False)} "
			f"profile={data.get('profile_path', '')} "
			f"files={data.get('file_count', 0)} "
			f"issues={data['issue_count']} "
			f"errors={data.get('error_count', 0)} "
			f"warnings={data.get('warning_count', 0)} "
			f"info={data.get('info_count', 0)}"
		),
	]
	kind_summary = format_counter_summary(data.get("issue_kind_counts", []))
	if kind_summary:
		lines.append(f"kinds: {kind_summary}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("severity", "rule_id", "zone_id", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_boundary: ok={data['ok']} "
			f"manifests={data['manifest_count']} "
			f"packages={data['package_count']} "
			f"paths={data['path_count']} "
			f"issues={data['issue_count']}"
		),
	]
	kind_counts = format_counter_summary(data.get("kind_counts", []))
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if kind_counts:
		lines.append(f"package_kinds: {kind_counts}")
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("field", "row_index", "row_key", "actual_value", "expected_value"):
			if key in issue:
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_closure_audit_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_closure_audit: ok={data['ok']} "
			f"packages={data['package_count']} "
			f"closures={data['closure_count']} "
			f"errors={data['error_count']} "
			f"warnings={data['warning_count']} "
			f"info={data['info_count']}"
		),
	]
	kind_counts = format_counter_summary(data.get("kind_counts", []))
	severity_counts = format_counter_summary(data.get("severity_counts", []))
	if kind_counts:
		lines.append(f"package_kinds: {kind_counts}")
	if severity_counts:
		lines.append(f"severity: {severity_counts}")
	large_closures = [
		row
		for row in data.get("closures", [])
		if (
			(
				row.get("kind") == "extension"
				and int(row.get("closure_count", 0)) > data.get("extension_total_warning_threshold", 8)
			)
			or (
				row.get("kind") == "preset"
				and int(row.get("closure_count", 0)) > data.get("preset_total_info_threshold", 12)
			)
		)
	]
	for row in large_closures[:8]:
		lines.append(
			f"- closure: {row.get('package_id')} "
			f"kind={row.get('kind')} "
			f"total={row.get('closure_count')} "
			f"standard={row.get('standard_count')} "
			f"extension={row.get('extension_count')}"
		)
	for fan_in in data.get("standard_fan_in", [])[:8]:
		lines.append(
			f"- fan_in: {fan_in.get('package_id')} "
			f"dependents={fan_in.get('dependent_count')}"
		)
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("severity", "row_key", "actual_value", "expected_value"):
			if key in issue:
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_source_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_source_boundary: ok={data['ok']} "
			f"packages={data['package_count']} "
			f"source_files={data['source_file_count']} "
			f"distribution_files={data.get('distribution_file_count', 0)} "
			f"issues={data['issue_count']}"
		),
	]
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		details = []
		for key in ("row_key", "symbol", "target", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_build_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_build_boundary: ok={data['ok']} "
			f"packages={data['package_count']} "
			f"archives={data['archive_count']} "
			f"registry_packages={data['registry_package_count']} "
			f"issues={data['issue_count']}"
		),
	]
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_user_dependency_boundary_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_user_dependency_boundary: ok={data['ok']} "
			f"source_files={data['source_file_count']} "
			f"issues={data['issue_count']}"
		),
	]
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		details = []
		for key in ("actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_external_command_audit_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_external_command_audit: ok={data['ok']} "
			f"report_only={data.get('report_only', True)} "
			f"packages={data.get('package_count', 0)} "
			f"source_files={data['source_file_count']} "
			f"issues={data['issue_count']} "
			f"errors={data.get('error_count', 0)} "
			f"warnings={data.get('warning_count', 0)} "
			f"info={data.get('info_count', 0)}"
		),
	]
	kind_summary = format_counter_summary(data.get("issue_kind_counts", []))
	api_summary = format_counter_summary(data.get("api_counts", []))
	command_summary = format_counter_summary(data.get("command_counts", []))
	if kind_summary:
		lines.append(f"kinds: {kind_summary}")
	if api_summary:
		lines.append(f"apis: {api_summary}")
	if command_summary:
		lines.append(f"commands: {command_summary}")
	display_limit = 16
	for issue in data["issues"][:display_limit]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		details = []
		for key in ("severity", "row_key", "api", "command"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	if len(data["issues"]) > display_limit:
		lines.append(f"... {len(data['issues']) - display_limit} more issue(s) omitted from text output; use --json for the full report.")
	return "\n".join(lines)


def render_core_only_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"core_only_smoke: ok={data['ok']} "
			f"files={data['file_count']} "
			f"standard_classes={data['standard_class_count']} "
			f"issues={data['issue_count']}"
		),
	]
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = f"{issue.get('path', '')}:{issue.get('line', '')}".rstrip(":")
		details = []
		for key in ("symbol", "field", "actual_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_core_plugin_bootstrap_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"core_plugin_bootstrap_smoke: ok={data['ok']} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		lines.append(
			f"- {scenario.get('name', '')}: "
			f"ok={scenario.get('ok', False)} "
			f"return_code={scenario.get('return_code', -1)}"
		)
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "actual_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_editor_wizard_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_editor_wizard_smoke: ok={data['ok']} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		details = []
		for key in ("test_path", "exit_code", "log_path"):
			if key in scenario:
				details.append(f"{key}={scenario[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}{suffix}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "actual_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
		if issue.get("error"):
			lines.append(indent_text(str(issue["error"]), "  error_tail: "))
	return "\n".join(lines)


def render_package_focused_gut_mapping_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_focused_gut_mapping: ok={data['ok']} "
			f"packages={data.get('package_count', 0)} "
			f"mapped={data.get('mapped_package_count', 0)} "
			f"tests={data.get('test_count', 0)} "
			f"issues={data['issue_count']}"
		),
		f"mapping: {data.get('mapping_path', '')}",
	]
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "row_index", "field", "actual_value", "expected_value"):
			if issue.get(key) != None and issue.get(key) != "":
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_godot_cli_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_godot_cli_smoke: ok={data['ok']} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		details = []
		for key in ("package_count", "installed_file_count", "removed_file_count", "dry_run", "cache_file_count", "registry_mirror_index"):
			if key in scenario:
				details.append(f"{key}={scenario[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}{suffix}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_package_godot_smoke_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"package_godot_smoke: ok={data['ok']} "
			f"mode={data.get('mode', 'representative')} "
			f"packages={data.get('package_count', 0)} "
			f"jobs={data.get('jobs', 1)} "
			f"scenarios={data['scenario_count']} "
			f"issues={data['issue_count']}"
		),
	]
	for scenario in data["scenarios"]:
		details = []
		for key in ("package_id", "package_kind", "installed_file_count", "expected_file_count", "preload_count", "exit_leak_warning_count"):
			if key in scenario:
				details.append(f"{key}={scenario[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {scenario.get('name', '')}: ok={scenario.get('ok', False)}{suffix}")
	issue_counts = format_counter_summary(data.get("issue_kind_counts", []))
	if issue_counts:
		lines.append(f"issue_kinds: {issue_counts}")
	for issue in data["issues"]:
		location = issue.get("path", "")
		details = []
		for key in ("row_key", "field", "actual_value", "expected_value"):
			if issue.get(key):
				details.append(f"{key}={issue[key]}")
		suffix = f" ({', '.join(details)})" if details else ""
		lines.append(f"- {issue['kind']}: {location}{suffix} {issue.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_maintenance_self_test_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"maintenance_self_test: ok={data['ok']} "
			f"tests={data['test_count']} "
			f"failures={data['failure_count']}"
		),
	]
	for failure in data["failures"]:
		lines.append(f"- {failure['name']}: {failure.get('message', '')}".rstrip())
	return "\n".join(lines)


def render_maintenance_log_hygiene_text(data: dict[str, Any]) -> str:
	lines = [
		(
			f"maintenance_log_hygiene: ok={data['ok']} dry_run={data['dry_run']} "
			f"all={data['remove_all']}"
		),
		(
			f"files: before={data['before_file_count']} candidates={data['candidate_file_count']} "
			f"removed={data['removed_file_count']} retained={data['retained_file_count']}"
		),
		(
			f"bytes: before={data['before_bytes']} candidates={data['candidate_bytes']} "
			f"removed={data['removed_bytes']} retained={data['retained_bytes']}"
		),
	]
	if data["reason_counts"]:
		lines.append(
			"reasons: "
			+ ", ".join(
				f"{reason}={count}" for reason, count in sorted(data["reason_counts"].items())
			)
		)
	for error in data["errors"]:
		lines.append(f"- error: {error}")
	return "\n".join(lines)


def render_godot_exit_leak_report_text(data: dict[str, Any]) -> str:
	lines = [
		f"godot_exit_leak_report: ok={data['ok']} has_leaks={data['has_leaks']} logs={len(data['logs'])}",
		(
			"summary: "
			f"objectdb={data['objectdb_warning_count']} "
			f"resource_summaries={data['resource_summary_count']} "
			f"resource_total={data['resource_summary_total']} "
			f"resource_paths={data['resource_still_in_use_count']} "
			f"rid_total={data['rid_allocation_total']} "
			f"leaked_instances={data['leaked_instance_total']}"
		),
	]
	if data["missing_logs"]:
		lines.append("missing logs:")
		lines.extend(f"- {path}" for path in data["missing_logs"])
	if data["rid_allocations"]:
		lines.append("rid allocations:")
		lines.extend(f"- {item['key']}: {item['count']}" for item in data["rid_allocations"][:12])
	if data["leaked_instance_types"]:
		lines.append("leaked instance types:")
		lines.extend(f"- {item['key']}: {item['count']}" for item in data["leaked_instance_types"][:12])
	if data["resource_type_counts"]:
		lines.append("resource types:")
		lines.extend(f"- {item['key']}: {item['count']}" for item in data["resource_type_counts"][:12])
	if data["resource_path_prefix_counts"]:
		lines.append("resource path prefixes:")
		lines.extend(f"- {item['key']}: {item['count']}" for item in data["resource_path_prefix_counts"][:12])
	if data["warning_lines"]:
		lines.append("warning lines:")
		lines.extend(f"- {line}" for line in data["warning_lines"][:12])
	return "\n".join(lines)


def print_check_progress(event: str, name: str, duration_seconds: float | None) -> None:
	if event == "started":
		print(f"[gf-maintenance] starting {name}", file=sys.stderr, flush=True)
		return
	duration_text = f" in {duration_seconds:.2f}s" if duration_seconds is not None else ""
	print(f"[gf-maintenance] finished {name}{duration_text}", file=sys.stderr, flush=True)


def print_check_output(name: str, stream: str, text: str) -> None:
	if stream == "heartbeat":
		print(f"[gf-maintenance] {name}: {text}", file=sys.stderr, flush=True)
		return
	for line in text.rstrip("\r\n").splitlines():
		print(f"[gf-maintenance][{name}][{stream}] {line}", file=sys.stderr, flush=True)


def render_checks_text(data: dict[str, Any]) -> str:
	lines = [
		f"suite: {data['suite']} ok={data['ok']} duration={data.get('duration_seconds', 0.0):.2f}s"
	]
	for result in data["results"]:
		lines.append(
			f"- {result['name']}: exit={result['exit_code']} "
			f"timeout={result.get('timed_out', False)} "
			f"duration={result.get('duration_seconds', 0.0):.2f}s "
			f"execution={result.get('execution', 'subprocess')}"
		)
		stdout = result.get("stdout", "").strip()
		stderr = result.get("stderr", "").strip()
		if stdout and (not result.get("streamed_output") or result.get("exit_code", 1) != 0):
			lines.append(indent_text(trim_text(stdout, 1200), "  stdout: "))
		if stderr and (not result.get("streamed_output") or result.get("exit_code", 1) != 0):
			lines.append(indent_text(trim_text(stderr, 1200), "  stderr: "))
		release = result.get("release_status")
		if release and release["issues"]:
			lines.extend(f"  issue: {issue}" for issue in release["issues"])
	return "\n".join(lines)


def render_failed_checks_text(data: dict[str, Any]) -> str:
	failed_results = failed_check_results(data)
	lines = [
		(
			f"suite: {data['suite']} ok={data['ok']} "
			f"checks={len(data['results'])} failed={len(failed_results)} "
			f"duration={data.get('duration_seconds', 0.0):.2f}s"
		)
	]
	if not failed_results:
		lines.append("all checks passed")
		return "\n".join(lines)
	lines.append("failed checks:")
	for result in failed_results:
		lines.append(
			f"- {result['name']}: exit={result.get('exit_code')} "
			f"timeout={result.get('timed_out', False)} "
			f"duration={result.get('duration_seconds', 0.0):.2f}s "
			f"execution={result.get('execution', 'subprocess')}"
		)
		command = result.get("command")
		if command:
			lines.append(f"  command: {' '.join(str(part) for part in command)}")
		for note in result.get("notes", []) or []:
			lines.append(f"  note: {note}")
		release = result.get("release_status")
		if release and release.get("issues"):
			lines.extend(f"  issue: {issue}" for issue in release["issues"])
		stdout = result.get("stdout", "").strip()
		stderr = result.get("stderr", "").strip()
		if stdout:
			lines.append(indent_text(trim_text(stdout, 4000), "  stdout_tail: "))
		if stderr:
			lines.append(indent_text(trim_text(stderr, 4000), "  stderr_tail: "))
	return "\n".join(lines)


def failed_check_results(data: dict[str, Any]) -> list[dict[str, Any]]:
	return [
		result
		for result in data["results"]
		if result.get("exit_code", 1) != 0 or result.get("timed_out", False)
	]


def print_github_check_annotations(data: dict[str, Any]) -> None:
	for result in failed_check_results(data):
		name = str(result.get("name", "unknown"))
		title = github_workflow_command_escape_property(f"GF check failed: {name}")
		message = github_workflow_command_escape_data(render_failed_check_annotation(result))
		print(f"::error title={title}::{message}")


def render_failed_check_annotation(result: dict[str, Any]) -> str:
	lines = [
		(
			f"{result.get('name', 'unknown')} failed "
			f"exit={result.get('exit_code')} timeout={result.get('timed_out', False)}"
		)
	]
	command = result.get("command")
	if command:
		lines.append(f"command: {' '.join(str(part) for part in command)}")
	for note in result.get("notes", []) or []:
		lines.append(f"note: {note}")
	release = result.get("release_status")
	if release and release.get("issues"):
		lines.extend(f"issue: {issue}" for issue in release["issues"])
	stdout = result.get("stdout", "").strip()
	stderr = result.get("stderr", "").strip()
	if stdout:
		lines.append("stdout_tail:")
		lines.append(trim_text(stdout, 3000))
	if stderr:
		lines.append("stderr_tail:")
		lines.append(trim_text(stderr, 3000))
	return "\n".join(lines)


def github_workflow_command_escape_data(value: str) -> str:
	return value.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def github_workflow_command_escape_property(value: str) -> str:
	return github_workflow_command_escape_data(value).replace(":", "%3A").replace(",", "%2C")


def render_release_status_text(data: dict[str, Any]) -> str:
	lines = [f"version: {data['version']} ok={data['ok']}"]
	lines.append(f"plugin: {data['plugin_version']}")
	lines.append(
		"worktree: "
		f"dirty={data.get('worktree_dirty', False)} "
		f"changed={data.get('dirty_file_count', 0)} "
		f"allow_dirty={data.get('allow_dirty', False)}"
	)
	lines.append(
		"compatibility: "
		f"allow_breaking_api={data.get('allow_breaking_api', False)}"
	)
	lines.append(
		"since: "
		f"unresolved={data.get('unresolved_since_count', 0)} "
		f"future={data.get('future_since_count', 0)}"
	)
	api_diff = data.get("api_baseline_diff", {})
	api_diff_summary = api_diff.get("summary", {})
	if api_diff_summary:
		lines.append(
			"api_baseline: "
			f"base={api_diff.get('base_tag', '')} "
			f"breaking={api_diff_summary.get('breaking_change_count', 0)} "
			f"compatible={api_diff_summary.get('compatible_change_count', 0)} "
			f"added_classes={api_diff_summary.get('added_classes', 0)} "
			f"signature_changes={api_diff_summary.get('signature_changes', 0)} "
			f"breaking_signatures={api_diff_summary.get('breaking_signature_changes', 0)} "
			f"compatible_signatures={api_diff_summary.get('compatible_signature_changes', 0)} "
			f"schema_changes={api_diff_summary.get('schema_changes', 0)} "
			f"breaking_schemas={api_diff_summary.get('breaking_schema_changes', 0)} "
			f"compatible_schemas={api_diff_summary.get('compatible_schema_changes', 0)} "
			f"removed_members={api_diff_summary.get('removed_members', 0)} "
			f"breaking_allowed={api_diff_summary.get('breaking_allowed', False)} "
			f"compatible_allowed={api_diff_summary.get('compatible_allowed', False)}"
		)
	asset_library = data.get("asset_library", {})
	lines.append(
		"asset_library: "
		f"version={asset_library.get('Asset Version', '')} "
		f"download={asset_library.get('Download Commit/URL', '')} "
		f"preview_todos={len(data.get('asset_library_preview_todos', []))}"
	)
	asset_store = data.get("asset_store", {})
	asset_store_fields = asset_store.get("fields", {})
	lines.append(
		"asset_store: "
		f"version={asset_store_fields.get('Current release version', '')} "
		f"tag={asset_store_fields.get('Release tag', '')} "
		f"tags={len(asset_store.get('tags', []))}"
	)
	lines.append(f"extensions: {data['extension_count']} mismatches={len(data['extension_mismatches'])}")
	package_archive = data.get("package_archive", {})
	lines.append(
		"archive: "
		f"skipped={package_archive.get('skipped', False)} "
		f"missing_rules={len(package_archive.get('missing_export_ignore_rules', []))} "
		f"blocked_dirs={len(package_archive.get('blocked_package_dirs', []))} "
		f"asset_store_package_issues={len(package_archive.get('asset_store_package', {}).get('issues', []))}"
	)
	modular_registry = package_archive.get("modular_package_registry", {})
	lines.append(
		"package_registry: "
		f"skipped={modular_registry.get('skipped', False)} "
		f"packages={modular_registry.get('package_count', 0)} "
		f"archives={modular_registry.get('archive_count', 0)} "
		f"presets={modular_registry.get('preset_count', 0)} "
		f"source={bool(modular_registry.get('registry_source', ''))} "
		f"offline_bundle={bool(modular_registry.get('offline_bundle', ''))} "
		f"issues={len(modular_registry.get('issues', []))}"
	)
	lines.append(f"tag: exists={data['tag_exists']} points_at_head={data['tag_points_at_head']}")
	if data["issues"]:
		lines.append("issues:")
		lines.extend(f"- {issue}" for issue in data["issues"])
	return "\n".join(lines)


def render_api_baseline_diff_text(data: dict[str, Any]) -> str:
	summary = data.get("summary", {})
	lines = [
		(
			f"api_baseline_diff: ok={data['ok']} "
			f"base={data.get('base_tag', '')} "
			f"version={data.get('version', '')} "
			f"enforce={data.get('enforce_version', False)}"
		),
		(
			"summary: "
			f"added_classes={summary.get('added_classes', 0)} "
			f"removed_classes={summary.get('removed_classes', 0)} "
			f"added_members={summary.get('added_members', 0)} "
			f"removed_members={summary.get('removed_members', 0)} "
			f"signature_changes={summary.get('signature_changes', 0)} "
			f"breaking_signatures={summary.get('breaking_signature_changes', 0)} "
			f"compatible_signatures={summary.get('compatible_signature_changes', 0)} "
			f"schema_changes={summary.get('schema_changes', 0)} "
			f"breaking_schemas={summary.get('breaking_schema_changes', 0)} "
			f"compatible_schemas={summary.get('compatible_schema_changes', 0)} "
			f"extends_changes={summary.get('extends_changes', 0)} "
			f"breaking={summary.get('breaking_change_count', 0)} "
			f"compatible={summary.get('compatible_change_count', 0)} "
			f"breaking_allowed={summary.get('breaking_allowed', False)} "
			f"compatible_allowed={summary.get('compatible_allowed', False)}"
		),
	]
	for issue in data.get("issues", []):
		lines.append(f"- issue: {issue}")
	diff = data.get("diff", {})
	for group in (
		"added_classes",
		"removed_classes",
		"removed_members",
		"breaking_signature_changes",
		"compatible_signature_changes",
		"breaking_schema_changes",
		"compatible_schema_changes",
		"extends_changes",
	):
		items = diff.get(group, [])
		if not items:
			continue
		lines.append(f"{group}:")
		for item in items[:20]:
			lines.append(f"- {format_api_diff_item(group, item)}")
		if len(items) > 20:
			lines.append(f"- ... {len(items) - 20} more")
	return "\n".join(lines)


def format_api_diff_item(group: str, item: dict[str, Any]) -> str:
	if group in {"added_classes", "removed_classes"}:
		return f"{item.get('name', '')} | {item.get('module', '')} | {item.get('source_path', '')}"
	if group in {"signature_changes", "breaking_signature_changes", "compatible_signature_changes"}:
		compatibility = item.get("compatibility", "")
		suffix = f" [{compatibility}]" if compatibility else ""
		return (
			f"{item.get('class', '')}.{item.get('name', '')}: "
			f"{item.get('old_signature', '')} -> {item.get('new_signature', '')}"
			f"{suffix}"
		)
	if group in {"schema_changes", "breaking_schema_changes", "compatible_schema_changes"}:
		compatibility = item.get("compatibility", "")
		suffix = f" [{compatibility}]" if compatibility else ""
		return (
			f"{item.get('class', '')}.{item.get('name', '')}: "
			f"{item.get('old_schema', [])} -> {item.get('new_schema', [])}"
			f"{suffix}"
		)
	if group == "extends_changes":
		return (
			f"{item.get('class', '')}: "
			f"{item.get('old_extends', '')} -> {item.get('new_extends', '')}"
		)
	return f"{item.get('class', '')}.{item.get('name', '')} | {item.get('signature', '')}"


def render_api_index_text(data: dict[str, Any]) -> str:
	lines = [
		f"source: {data['source_root']}",
		f"files: {data['file_count']}",
		f"classes: {data['class_count']}",
		f"public methods: {data['public_method_count']}",
		"modules:",
	]
	for module, stats in sorted(data["modules"].items()):
		lines.append(f"- {module}: classes={stats['classes']} methods={stats['methods']}")
	return "\n".join(lines)


def trim_text(text: str, max_chars: int) -> str:
	if len(text) <= max_chars:
		return text
	return text[-max_chars:]


def indent_text(text: str, prefix: str) -> str:
	lines = text.splitlines()
	if not lines:
		return prefix
	return prefix + ("\n" + " " * len(prefix)).join(lines)
