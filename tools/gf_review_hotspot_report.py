#!/usr/bin/env python3
"""Capture bounded current-source observations for an optional review report."""

from __future__ import annotations

import hashlib
import time
from pathlib import Path
from pathlib import PurePosixPath
from typing import Any

import gf_path_security
import gf_review_hotspots


MAX_INVENTORY_BYTES = 2 * 1024 * 1024
MAX_INVENTORY_PATHS = 20_000
MAX_FILES = 4096
MAX_FILE_BYTES = 1024 * 1024
MAX_TOTAL_BYTES = 64 * 1024 * 1024
MAX_FUNCTIONS = 100_000
MAX_SCAN_SECONDS = 30.0
MAX_RESULT_LIMIT = 500
MAX_SCOPES = 64
MAX_FILE_ISSUES = 16


def normalize_scope(value: str) -> str:
	"""Accept a literal repository-relative file or directory, never a pathspec."""
	if not isinstance(value, str):
		raise ValueError("review_hotspots.invalid_scope")
	value = value.replace("\\", "/")
	path = PurePosixPath(value)
	if (
		not value
		or not path.parts
		or len(value.encode("utf-8")) > 1024
		or path.is_absolute()
		or path.as_posix() != value
		or any(part in {".", ".."} or ":" in part for part in path.parts)
		or any(ord(character) < 32 or ord(character) == 127 for character in value)
	):
		raise ValueError("review_hotspots.invalid_scope")
	return value


def parse_inventory(payload: bytes) -> list[str]:
	"""Parse one bounded NUL-delimited Git inventory without lossy decoding."""
	if len(payload) > MAX_INVENTORY_BYTES:
		raise ValueError("review_hotspots.inventory_limit")
	if payload and not payload.endswith(b"\0"):
		raise ValueError("review_hotspots.incomplete_inventory")
	try:
		paths = payload.decode("utf-8", errors="strict").split("\0")[:-1]
	except UnicodeDecodeError:
		raise ValueError("review_hotspots.invalid_inventory_utf8") from None
	if len(paths) > MAX_INVENTORY_PATHS:
		raise ValueError("review_hotspots.inventory_limit")
	files: set[str] = set()
	for path in paths:
		# Git reports untracked nested repositories as directory markers, without
		# inventorying their contents. Validate their literal spelling, then leave
		# that separate repository outside this report's source inventory.
		is_directory = path.endswith("/")
		literal = path[:-1] if is_directory else path
		try:
			if "\\" in literal or normalize_scope(literal) != literal:
				raise ValueError("review_hotspots.invalid_inventory_path")
		except ValueError:
			raise ValueError("review_hotspots.invalid_inventory_path") from None
		if not is_directory:
			files.add(literal)
	return sorted(files)


def empty_report(scopes: list[str], limit: int) -> dict[str, Any]:
	return {
		"schema_version": 1,
		"algorithm_version": gf_review_hotspots.ALGORITHM_VERSION,
		"metric_definitions": dict(gf_review_hotspots.METRIC_DEFINITIONS),
		"observation_only": True,
		"ok": False,
		"status": "incomplete",
		"scopes": scopes,
		"limit": limit,
		"selected_file_count": 0,
		"scanned_file_count": 0,
		"function_count": 0,
		"omitted_function_count": 0,
		"files": [],
		"functions": [],
		"issues": [],
		"ranking": list(gf_review_hotspots.SORT_ORDER),
		"source_consistency": "per_file_pinned_read_with_sha256",
		"limits": {
			"max_files": MAX_FILES,
			"max_file_bytes": MAX_FILE_BYTES,
			"max_total_bytes": MAX_TOTAL_BYTES,
			"max_functions": MAX_FUNCTIONS,
			"max_scan_seconds": MAX_SCAN_SECONDS,
		},
	}


def build_report(
	root: Path,
	inventory: list[str],
	*,
	scopes: list[str] | None = None,
	limit: int = 30,
) -> dict[str, Any]:
	"""Read matching tracked/unignored files; keep partial coverage explicit."""
	if scopes is not None and len(scopes) > MAX_SCOPES:
		raise ValueError("review_hotspots.scope_limit")
	selected_scopes = sorted({normalize_scope(value) for value in (scopes or ["addons/gf"])})
	if type(limit) is not int or not 1 <= limit <= MAX_RESULT_LIMIT:
		raise ValueError("review_hotspots.invalid_limit")
	report = empty_report(selected_scopes, limit)
	if len(inventory) > MAX_INVENTORY_PATHS:
		report["issues"].append({"code": "review_hotspots.inventory_limit"})
		return report
	selected: set[str] = set()
	for scope in selected_scopes:
		matches = {
			path for path in inventory
			if path.endswith(".gd") and (path == scope or path.startswith(scope + "/"))
		}
		if not matches:
			report["issues"].append({"code": "review_hotspots.no_matching_scripts", "path": scope})
		selected.update(matches)
	report["selected_file_count"] = len(selected)
	if len(selected) > MAX_FILES:
		report["issues"].append({"code": "review_hotspots.file_limit"})
		return report
	deadline = time.monotonic() + MAX_SCAN_SECONDS
	total_bytes = 0
	functions: list[dict[str, Any]] = []
	for path in sorted(selected):
		if time.monotonic() >= deadline:
			report["issues"].append({"code": "review_hotspots.deadline"})
			break
		remaining_bytes = MAX_TOTAL_BYTES - total_bytes
		if remaining_bytes <= 0:
			report["issues"].append({"code": "review_hotspots.total_bytes_limit", "path": path})
			break
		try:
			payload = gf_path_security.read_pinned_regular_file(
				root, path, max_bytes=min(MAX_FILE_BYTES, remaining_bytes),
			)
			total_bytes += len(payload)
			source = payload.decode("utf-8", errors="strict")
		except (gf_path_security.PinnedReadError, UnicodeDecodeError) as error:
			if getattr(error, "rule_id", "") == "path_security.file_too_large" and remaining_bytes < MAX_FILE_BYTES:
				report["issues"].append({"code": "review_hotspots.total_bytes_limit", "path": path})
				break
			report["issues"].append({
				"code": getattr(error, "rule_id", "review_hotspots.invalid_utf8"),
				"path": path,
			})
			continue
		analysis = gf_review_hotspots.analyze_source(source, path)
		report["scanned_file_count"] += 1
		report["files"].append({
			"path": path,
			"sha256": hashlib.sha256(payload).hexdigest(),
			"status": analysis["status"],
			"function_count": len(analysis["functions"]),
			"issues": analysis["issues"][:MAX_FILE_ISSUES],
			"omitted_issue_count": analysis["omitted_issue_count"] + max(0, len(analysis["issues"]) - MAX_FILE_ISSUES),
		})
		if len(functions) + len(analysis["functions"]) > MAX_FUNCTIONS:
			report["issues"].append({"code": "review_hotspots.function_limit", "path": path})
			break
		functions.extend(analysis["functions"])
		if time.monotonic() >= deadline:
			report["issues"].append({"code": "review_hotspots.deadline"})
			break
	functions.sort(key=gf_review_hotspots.function_sort_key)
	report["function_count"] = len(functions)
	report["functions"] = functions[:limit]
	report["omitted_function_count"] = max(0, len(functions) - limit)
	report["ok"] = not report["issues"] and all(
		item["status"] == "complete" for item in report["files"]
	)
	report["status"] = "complete" if report["ok"] else "incomplete"
	return report


def render_text(report: dict[str, Any]) -> str:
	"""Render locations and individual observations without a quality score."""
	lines = [
		f"Review hotspots (observation only): {report['status']}",
		f"Scopes: {', '.join(report['scopes'])}",
		f"Files: {report['scanned_file_count']}/{report['selected_file_count']}; "
		f"functions: {report['function_count']}; omitted by limit: {report['omitted_function_count']}",
		"Order: nesting, branches, loops, code lines (descending); no pass/fail threshold.",
	]
	for function in report["functions"]:
		metrics = function["metrics"]
		lines.append(
			f"{function['path']}:{function['start_line']} "
			f"{function['qualified_name']} [{function['status']}] "
			f"nesting={metrics['max_nesting']} branches={metrics['branch_count']} "
			f"loops={metrics['loop_count']} lines={metrics['effective_code_lines']}"
		)
	for issue in report["issues"]:
		lines.append(f"Issue: {issue.get('path', '')} {issue['code']}")
	for file in report["files"]:
		if file["status"] != "complete":
			lines.append(f"Incomplete source: {file['path']}: {file['issues']}")
	return "\n".join(lines)
