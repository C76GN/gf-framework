"""Bounded stale-reference analysis for explicitly declared project Markdown."""

from __future__ import annotations

import os
import re
import stat
from array import array
from bisect import bisect_right
from pathlib import Path
from typing import Any, Iterator

from . import catalog
from .paths import (
	is_reserved_framework_resource_path,
	portable_ownership_path_identity,
	project_path_has_link_component,
	read_bounded_bytes,
)


MAX_DOCUMENT_FILES = 10_000
MAX_DOCUMENT_ENTRIES = 100_000
MAX_DOCUMENT_BYTES = 2 * 1024 * 1024
MAX_DOCUMENT_SCAN_BYTES = 64 * 1024 * 1024
MAX_REFERENCE_EVIDENCE = 200
MAX_ACTIONABLE_EVIDENCE = 200
MAX_ADVISORY_EVIDENCE = 100
MAX_CATALOG_ISSUES = 20
MAX_SOURCE_PATH_LENGTH = 1024

_SCANNER_EXCLUDED_SEGMENTS = frozenset({
	".git",
	".gf",
	".godot",
	".import",
	"__pycache__",
	"ai_analysis",
	"build",
	"node_modules",
	"site",
})
_GF_REFERENCE_PATTERN = re.compile(
	r"(?<!\w)"
	r"(?P<owner>Gf|GF[A-Z][A-Za-z0-9_]{0,157})"
	r"(?:\.(?P<member>[A-Za-z_][A-Za-z0-9_]{0,159}))?"
	r"(?!\w)"
)
_GF_OWNER_PATTERN = re.compile(r"^(?:Gf|GF[A-Z][A-Za-z0-9_]{0,157})$")
_MEMBER_PATTERN = re.compile(r"^[A-Za-z_][A-Za-z0-9_]{0,159}$")
_PACKAGE_ID_PATTERN = re.compile(r"^gf\.[a-z0-9_.-]{1,157}$")
_FENCE_OPEN_PATTERN = re.compile(r"^ {0,3}(?P<fence>`{3,}|~{3,})(?P<info>[^\r\n]*)$")
_LIST_MARKER_PATTERN = re.compile(r"(?:[*+-]|[0-9]{1,9}[.)])")

_PROSE = 0
_FENCED_CODE = 1
_IGNORED_MARKER = 2
_INLINE_CODE = 3


def analyze_documentation_references(
	project_root: Path,
	contract_result: dict[str, Any],
	*,
	api_index: dict[str, Any] | None = None,
	max_entries: int = MAX_DOCUMENT_ENTRIES,
	max_files: int = MAX_DOCUMENT_FILES,
	max_file_bytes: int = MAX_DOCUMENT_BYTES,
	max_total_bytes: int = MAX_DOCUMENT_SCAN_BYTES,
) -> dict[str, Any]:
	"""Validate GF-qualified references only inside declared Markdown roots."""
	max_entries = _clamped_limit(max_entries, MAX_DOCUMENT_ENTRIES)
	max_files = _clamped_limit(max_files, MAX_DOCUMENT_FILES)
	max_file_bytes = _clamped_limit(max_file_bytes, MAX_DOCUMENT_BYTES)
	max_total_bytes = _clamped_limit(max_total_bytes, MAX_DOCUMENT_SCAN_BYTES)
	contract_valid = bool(contract_result.get("ok"))
	contract_data = contract_result.get("contract", {})
	if not contract_valid or not isinstance(contract_data, dict):
		contract_data = {}
	architecture = contract_data.get("architecture", {})
	if not isinstance(architecture, dict):
		architecture = {}
	configured_roots = _string_items(architecture.get("documentation_roots"))

	loaded_index: dict[str, Any] = {}
	catalog_error = ""
	if api_index is None:
		try:
			loaded_index = catalog.load_api_index()
		except (OSError, UnicodeDecodeError, ValueError) as exc:
			catalog_error = str(exc)
	else:
		loaded_index = api_index

	identity = _catalog_identity(project_root, loaded_index)
	base = _empty_analysis(
		identity,
		contract_issue_count=int(contract_result.get("error_count", 0)),
	)
	if not contract_valid:
		base["status"] = "contract_invalid"
		return base
	if not configured_roots:
		base["status"] = "not_configured"
		return base

	catalog_issues = [
		*catalog.api_index_issues(loaded_index),
		*_documentation_catalog_issues(loaded_index),
	]
	if catalog_error:
		catalog_issues.insert(0, catalog_error)
	project_version = identity["project_framework_version"]
	catalog_version = identity["framework_version"]
	if not project_version:
		catalog_issues.append("GF Framework is not installed or addons/gf/plugin.cfg has no version.")
	elif catalog_version and project_version != catalog_version:
		catalog_issues.append(
			"GF AI catalog version does not match the installed framework: "
			f"{catalog_version} != {project_version}."
		)
	catalog_issues = list(dict.fromkeys(_bounded_message(item) for item in catalog_issues))
	base["catalog_issue_count"] = len(catalog_issues)
	base["catalog_issues_truncated"] = len(catalog_issues) > MAX_CATALOG_ISSUES
	base["catalog_issues"] = catalog_issues[:MAX_CATALOG_ISSUES]

	excluded_roots = _generated_root_identities(architecture)
	ready_roots, root_states, root_pins = _documentation_roots(
		project_root,
		architecture,
		excluded_roots,
	)
	base["documentation_roots"] = root_states
	if catalog_issues:
		base["status"] = "catalog_invalid"
		return base

	owners = _public_owner_records(loaded_index)
	scan = _scan_documentation(
		project_root,
		ready_roots,
		owners,
		max_entries=max_entries,
		max_files=max_files,
		max_file_bytes=max_file_bytes,
		max_total_bytes=max_total_bytes,
	)
	_post_roots, post_states, post_pins = _documentation_roots(
		project_root,
		architecture,
		excluded_roots,
	)
	if root_states != post_states or root_pins != post_pins:
		post_by_root = {item["root"]: item for item in post_states}
		for state in root_states:
			post = post_by_root.get(state["root"])
			if post != state or root_pins.get(state["root"]) != post_pins.get(state["root"]):
				state["status"] = "drifted"
	root_incomplete = any(item["status"] != "ready" for item in root_states)
	complete = bool(scan["scan_complete"]) and not root_incomplete
	return {
		**base,
		"status": "complete" if complete else "partial",
		"complete": complete,
		"documentation_roots": root_states,
		**scan,
	}


def _empty_analysis(
	catalog_identity: dict[str, Any],
	*,
	contract_issue_count: int,
) -> dict[str, Any]:
	return {
		"status": "partial",
		"complete": False,
		"catalog": catalog_identity,
		"catalog_issue_count": 0,
		"catalog_issues_truncated": False,
		"catalog_issues": [],
		"contract_issue_count": contract_issue_count,
		"documentation_roots": [],
		"reference_count": 0,
		"references_truncated": False,
		"references": [],
		"actionable_count": 0,
		"actionable_references_truncated": False,
		"actionable_references": [],
		"advisory_count": 0,
		"advisories_truncated": False,
		"advisories": [],
		"entry_count": 0,
		"file_count": 0,
		"scanned_file_count": 0,
		"scanned_file_bytes": 0,
		"scan_truncated": False,
		"scan_truncation_reason": "",
		"scan_complete": False,
		"skipped_large_file_count": 0,
		"unreadable_file_count": 0,
		"unsafe_file_path_count": 0,
		"unsafe_directory_count": 0,
		"directory_identity_drift_count": 0,
	}


def _scan_documentation(
	project_root: Path,
	ready_roots: tuple[tuple[str, Path], ...],
	owners: dict[str, dict[str, Any]],
	*,
	max_files: int,
	max_file_bytes: int,
	max_total_bytes: int,
	max_entries: int = MAX_DOCUMENT_ENTRIES,
) -> dict[str, Any]:
	entry_count = 0
	file_count = 0
	scanned_file_count = 0
	scanned_file_bytes = 0
	skipped_large_file_count = 0
	unreadable_file_count = 0
	unsafe_file_path_count = 0
	unsafe_directory_count = 0
	directory_identity_drift_count = 0
	truncated = False
	truncation_reason = ""
	reference_count = 0
	actionable_count = 0
	advisory_count = 0
	references: list[dict[str, Any]] = []
	actionable_references: list[dict[str, Any]] = []
	advisories: list[dict[str, Any]] = []
	walked_directory_pins: dict[Path, tuple[int, int, int, int, int]] = {}
	discovered_directory_pins: dict[Path, tuple[int, int, int, int, int]] = {}
	seen_directory_identities: set[str] = set()
	seen_file_identities: set[str] = set()

	for _root_name, root_path in ready_roots:
		root_resource_path = _canonical_resource_path(project_root, root_path)
		root_identity = portable_ownership_path_identity(root_resource_path)
		if not root_identity or root_identity in seen_directory_identities:
			unsafe_directory_count += 1
			continue
		root_discovery_pin = _directory_snapshot(project_root, root_path)
		if root_discovery_pin is None:
			unsafe_directory_count += 1
			continue
		seen_directory_identities.add(root_identity)
		discovered_directory_pins[root_path] = root_discovery_pin
		pending_directories = [root_path]
		while pending_directories:
			current_path = pending_directories.pop()
			current_pin = _directory_snapshot(project_root, current_path)
			if current_pin is None:
				unsafe_directory_count += 1
				continue
			discovery_pin = discovered_directory_pins.pop(current_path, None)
			if discovery_pin is None or discovery_pin != current_pin:
				directory_identity_drift_count += 1
				continue
			walked_directory_pins[current_path] = current_pin
			entry_names, entry_truncated, entry_error = _bounded_directory_entry_names(
				current_path,
				max_entries - entry_count,
			)
			entry_count += len(entry_names)
			if entry_error:
				unsafe_directory_count += 1
				continue
			if entry_truncated:
				truncated = True
				truncation_reason = "entry_count"
				break
			if _directory_snapshot(project_root, current_path) != current_pin:
				directory_identity_drift_count += 1
				walked_directory_pins.pop(current_path, None)
				continue

			directory_names: list[str] = []
			file_names: list[str] = []
			for name in entry_names:
				candidate = current_path / name
				try:
					metadata = candidate.lstat()
				except OSError:
					unsafe_directory_count += 1
					continue
				if _is_link_or_reparse(candidate, metadata):
					if name.casefold().endswith(".md"):
						# Markdown-shaped unsafe entries share the regular-file
						# budget, so unsafe_file_path_count cannot escape it.
						file_names.append(name)
					else:
						unsafe_directory_count += 1
					continue
				if stat.S_ISDIR(metadata.st_mode):
					directory_names.append(name)
				else:
					file_names.append(name)

			safe_directories: list[Path] = []
			for name in directory_names:
				candidate = current_path / name
				resource_path = _canonical_resource_path(project_root, candidate)
				if is_reserved_framework_resource_path(resource_path):
					continue
				if name.casefold() in _SCANNER_EXCLUDED_SEGMENTS:
					unsafe_directory_count += 1
					continue
				candidate_identity = portable_ownership_path_identity(resource_path)
				candidate_pin = _directory_snapshot(project_root, candidate)
				if (
					not candidate_identity
					or candidate_identity in seen_directory_identities
					or candidate_pin is None
				):
					unsafe_directory_count += 1
					continue
				seen_directory_identities.add(candidate_identity)
				discovered_directory_pins[candidate] = candidate_pin
				safe_directories.append(candidate)
			pending_directories.extend(reversed(safe_directories))

			for file_name in file_names:
				if not file_name.casefold().endswith(".md"):
					continue
				if file_count >= max_files:
					truncated = True
					truncation_reason = "file_count"
					break
				file_count += 1
				path = current_path / file_name
				source_path = _canonical_resource_path(project_root, path)
				source_identity = portable_ownership_path_identity(source_path)
				if (
					not source_identity
					or source_identity in seen_file_identities
					or is_reserved_framework_resource_path(source_path)
				):
					unsafe_file_path_count += 1
					continue
				seen_file_identities.add(source_identity)
				file_pin = _regular_snapshot(project_root, path)
				if file_pin is None:
					unsafe_file_path_count += 1
					continue
				file_size = file_pin[3]
				if file_size > max_file_bytes:
					skipped_large_file_count += 1
					continue
				if scanned_file_bytes + file_size > max_total_bytes:
					truncated = True
					truncation_reason = "byte_budget"
					break
				remaining_bytes = max_total_bytes - scanned_file_bytes
				read_limit = min(max_file_bytes, remaining_bytes)
				try:
					raw = read_bounded_bytes(path, read_limit)
				except ValueError:
					scanned_file_bytes += read_limit
					unreadable_file_count += 1
					continue
				scanned_file_bytes += len(raw)
				if _regular_snapshot(project_root, path) != file_pin:
					unreadable_file_count += 1
					continue
				try:
					text = raw.decode("utf-8", errors="strict")
				except UnicodeDecodeError:
					unreadable_file_count += 1
					continue
				scanned_file_count += 1
				for item in _markdown_reference_items(text, source_path, owners):
					if item["kind"] == "advisory":
						advisory_count += 1
						if len(advisories) < MAX_ADVISORY_EVIDENCE:
							advisories.append(item["evidence"])
						continue
					reference = item["evidence"]
					reference_count += 1
					if len(references) < MAX_REFERENCE_EVIDENCE:
						references.append(reference)
					if reference["status"] != "current":
						actionable_count += 1
						if len(actionable_references) < MAX_ACTIONABLE_EVIDENCE:
							actionable_references.append(reference)
			if truncated:
				break
		if truncated:
			break

	if not truncated:
		directory_identity_drift_count += len(discovered_directory_pins)
	directory_identity_drift_count += sum(
		_directory_snapshot(project_root, path) != pin
		for path, pin in walked_directory_pins.items()
	)
	complete = not truncated and not any((
		skipped_large_file_count,
		unreadable_file_count,
		unsafe_file_path_count,
		unsafe_directory_count,
		directory_identity_drift_count,
	))
	return {
		"reference_count": reference_count,
		"references_truncated": reference_count > len(references),
		"references": references,
		"actionable_count": actionable_count,
		"actionable_references_truncated": actionable_count > len(actionable_references),
		"actionable_references": actionable_references,
		"advisory_count": advisory_count,
		"advisories_truncated": advisory_count > len(advisories),
		"advisories": advisories,
		"entry_count": entry_count,
		"file_count": file_count,
		"scanned_file_count": scanned_file_count,
		"scanned_file_bytes": scanned_file_bytes,
		"scan_truncated": truncated,
		"scan_truncation_reason": truncation_reason,
		"scan_complete": complete,
		"skipped_large_file_count": skipped_large_file_count,
		"unreadable_file_count": unreadable_file_count,
		"unsafe_file_path_count": unsafe_file_path_count,
		"unsafe_directory_count": unsafe_directory_count,
		"directory_identity_drift_count": directory_identity_drift_count,
	}


def _bounded_directory_entry_names(
	path: Path,
	remaining_entries: int,
) -> tuple[tuple[str, ...], bool, bool]:
	"""Keep at most the entry budget plus one enumeration-only truncation sentinel."""
	names: list[str] = []
	try:
		with os.scandir(path) as entries:
			for entry in entries:
				if len(names) >= remaining_entries:
					# The single extra DirEntry proves truncation. Its name is
					# never retained/sorted, and its path is never stat'ed or read.
					return tuple(sorted(names)), True, False
				names.append(entry.name)
	except OSError:
		return tuple(sorted(names)), False, True
	return tuple(sorted(names)), False, False


def _markdown_reference_items(
	text: str,
	source_path: str,
	owners: dict[str, dict[str, Any]],
) -> Iterator[dict[str, Any]]:
	contexts = _markdown_contexts(text)
	line = 1
	line_start = 0
	line_cursor = 0
	for match in _GF_REFERENCE_PATTERN.finditer(text):
		while line_cursor < match.start():
			line_feed = text.find("\n", line_cursor, match.start())
			carriage_return = text.find("\r", line_cursor, match.start())
			if line_feed < 0:
				newline = carriage_return
			elif carriage_return < 0:
				newline = line_feed
			else:
				newline = min(line_feed, carriage_return)
			if newline < 0:
				break
			line += 1
			line_cursor = newline + 1
			if text[newline] == "\r" and line_cursor < len(text) and text[line_cursor] == "\n":
				line_cursor += 1
			line_start = line_cursor
		line_cursor = match.start()
		context_values = contexts[match.start():match.end()]
		if not context_values or len(set(context_values)) != 1:
			continue
		context_value = context_values[0]
		if context_value == _IGNORED_MARKER:
			continue
		column = match.start() - line_start + 1
		symbol = match.group(0)
		end_column = column + len(symbol)
		if context_value == _PROSE:
			yield {
				"kind": "advisory",
				"evidence": {
					"source_path": source_path,
					"line": line,
					"column": column,
					"end_column": end_column,
					"symbol": symbol,
					"reason": "prose_api_reference",
				},
			}
			continue
		if context_value not in (_FENCED_CODE, _INLINE_CODE):
			continue
		owner_name = match.group("owner")
		member_name = match.group("member") or ""
		owner = owners.get(owner_name)
		if owner is None:
			owner_kind = ""
			package_id = ""
			status = "unknown_owner"
		elif member_name and member_name not in owner["members"]:
			owner_kind = str(owner["owner_kind"])
			package_id = str(owner["package_id"])
			status = "unknown_member"
		else:
			owner_kind = str(owner["owner_kind"])
			package_id = str(owner["package_id"])
			status = "current"
		yield {
			"kind": "reference",
			"evidence": {
				"source_path": source_path,
				"line": line,
				"column": column,
				"end_column": end_column,
				"context": "fenced_code" if context_value == _FENCED_CODE else "inline_code",
				"symbol": symbol,
				"reference_kind": "member" if member_name else "owner",
				"owner_kind": owner_kind,
				"owner_name": owner_name,
				"member_name": member_name,
				"package_id": package_id,
				"status": status,
			},
		}


def _markdown_contexts(text: str) -> bytearray:
	contexts = bytearray([_PROSE]) * len(text)
	fence_character = ""
	fence_length = 0
	fence_containers: tuple[tuple[str, int], ...] = ()
	html_comment_open = False
	for offset, content_end in _markdown_line_bounds(text):
		content = text[offset:content_end]
		if fence_character:
			container_content = _strip_container_content(content, fence_containers)
			if container_content is None:
				# CommonMark closes an unclosed fence at the end of its quote/list
				# container. Reprocess this physical line outside that container.
				fence_character = ""
				fence_length = 0
				fence_containers = ()
			elif _is_fence_close(container_content, fence_character, fence_length):
				contexts[offset:content_end] = bytes([_IGNORED_MARKER]) * len(content)
				fence_character = ""
				fence_length = 0
				fence_containers = ()
			else:
				contexts[offset:content_end] = bytes([_FENCED_CODE]) * len(content)
			if fence_character or container_content is not None:
				continue
		if html_comment_open:
			html_comment_open = _mark_inline_code_and_html_comments(
				text,
				contexts,
				offset,
				content_end,
				html_comment_open=True,
			)
			continue
		opening, containers = _fence_opening(content)
		if opening is not None:
			fence = opening.group("fence")
			info = opening.group("info")
			if fence[0] == "~" or "`" not in info:
				contexts[offset:content_end] = bytes([_IGNORED_MARKER]) * len(content)
				fence_character = fence[0]
				fence_length = len(fence)
				fence_containers = containers
				continue
		html_comment_open = _mark_inline_code_and_html_comments(
			text,
			contexts,
			offset,
			content_end,
			html_comment_open=False,
		)
	return contexts


def _markdown_line_bounds(text: str) -> Iterator[tuple[int, int]]:
	line_start = 0
	while line_start < len(text):
		line_feed = text.find("\n", line_start)
		carriage_return = text.find("\r", line_start)
		if line_feed < 0:
			line_end = carriage_return
		elif carriage_return < 0:
			line_end = line_feed
		else:
			line_end = min(line_feed, carriage_return)
		if line_end < 0:
			yield line_start, len(text)
			return
		yield line_start, line_end
		line_start = line_end + 1
		if text[line_end] == "\r" and line_start < len(text) and text[line_start] == "\n":
			line_start += 1


def _mark_inline_code_and_html_comments(
	text: str,
	contexts: bytearray,
	line_start: int,
	line_end: int,
	*,
	html_comment_open: bool,
) -> bool:
	# Closed code spans bind before raw inline HTML. Marking them first lets a
	# literal ``<!--`` inside code remain code, while a real comment can then
	# overwrite every code-looking delimiter inside its disabled range.
	_mark_inline_code_segment(text, contexts, line_start, line_end)
	cursor = line_start
	if html_comment_open:
		closing = text.find("-->", cursor, line_end)
		if closing < 0:
			contexts[line_start:line_end] = bytes([_IGNORED_MARKER]) * (line_end - line_start)
			return True
		closing_end = closing + 3
		contexts[line_start:closing_end] = bytes([_IGNORED_MARKER]) * (closing_end - line_start)
		cursor = closing_end

	while cursor < line_end:
		opening = text.find("<!--", cursor, line_end)
		if opening < 0:
			break
		if (
			_is_escaped(text, opening)
			or any(contexts[index] != _PROSE for index in range(opening, opening + 4))
		):
			cursor = opening + 4
			continue
		closing_end = _same_line_html_comment_closing_end(text, opening, line_end)
		if closing_end is None:
			contexts[opening:line_end] = bytes([_IGNORED_MARKER]) * (line_end - opening)
			return True
		contexts[opening:closing_end] = bytes([_IGNORED_MARKER]) * (closing_end - opening)
		cursor = closing_end
	return False


def _same_line_html_comment_closing_end(text: str, opening: int, line_end: int) -> int | None:
	# CommonMark also accepts the two empty comment forms ``<!-->`` and
	# ``<!--->``. They must not leave the rest of the document disabled.
	if text.startswith("<!-->", opening, line_end):
		return opening + 5
	if text.startswith("<!--->", opening, line_end):
		return opening + 6
	closing = text.find("-->", opening + 4, line_end)
	return closing + 3 if closing >= 0 else None


def _mark_inline_code_segment(
	text: str,
	contexts: bytearray,
	segment_start: int,
	segment_end: int,
) -> None:
	positions_by_length: dict[int, array] = {}
	index = segment_start
	while index < segment_end:
		opening_start = text.find("`", index, segment_end)
		if opening_start < 0:
			break
		if _is_escaped(text, opening_start):
			index = opening_start + 1
			continue
		run_end = opening_start
		while run_end < segment_end and text[run_end] == "`":
			run_end += 1
		run_length = run_end - opening_start
		positions_by_length.setdefault(run_length, array("I")).append(opening_start)
		index = run_end

	index = segment_start
	while index < segment_end:
		opening_start = text.find("`", index, segment_end)
		if opening_start < 0:
			break
		if _is_escaped(text, opening_start):
			index = opening_start + 1
			continue
		run_end = opening_start
		while run_end < segment_end and text[run_end] == "`":
			run_end += 1
		run_length = run_end - opening_start
		positions = positions_by_length[run_length]
		closing_position = bisect_right(positions, opening_start)
		if closing_position >= len(positions):
			index = run_end
			continue
		closing_start = positions[closing_position]
		closing_end = closing_start + run_length
		contexts[opening_start:run_end] = bytes([_IGNORED_MARKER]) * run_length
		contexts[run_end:closing_start] = bytes([_INLINE_CODE]) * (closing_start - run_end)
		contexts[closing_start:closing_end] = bytes([_IGNORED_MARKER]) * run_length
		index = closing_end


def _is_fence_close(content: str, fence_character: str, minimum_length: int) -> bool:
	pattern = rf"^ {{0,3}}{re.escape(fence_character)}{{{minimum_length},}}[ \t]*$"
	return re.fullmatch(pattern, content) is not None


def _fence_opening(
	content: str,
) -> tuple[re.Match[str] | None, tuple[tuple[str, int], ...]]:
	container_content, containers = _strip_container_opening(content)
	return _FENCE_OPEN_PATTERN.fullmatch(container_content), containers


def _strip_container_opening(content: str) -> tuple[str, tuple[tuple[str, int], ...]]:
	containers: list[tuple[str, int]] = []
	cursor = 0
	while cursor < len(content):
		level_start = cursor
		indent_end, indent_columns = _consume_prefix_indentation(content, level_start, 3)
		if indent_end < len(content) and content[indent_end] == ">":
			cursor = indent_end + 1
			if cursor < len(content) and content[cursor] in " \t":
				cursor += 1
			containers.append(("quote", 0))
			continue

		marker = _LIST_MARKER_PATTERN.match(content, indent_end)
		if marker is None:
			break
		spacing_start = marker.end()
		spacing_end = spacing_start
		while spacing_end < len(content) and content[spacing_end] in " \t":
			spacing_end += 1
		if spacing_end == spacing_start or spacing_end >= len(content):
			break
		marker_columns = indent_columns + len(marker.group(0))
		content_columns = _advance_indentation_column(
			content[spacing_start:spacing_end],
			marker_columns,
		)
		spacing_columns = content_columns - marker_columns
		if spacing_columns < 1 or spacing_columns > 4:
			break
		containers.append(("list", content_columns))
		cursor = spacing_end
	return content[cursor:], tuple(containers)


def _strip_container_content(
	content: str,
	containers: tuple[tuple[str, int], ...],
) -> str | None:
	cursor = 0
	for index, (container_kind, required_columns) in enumerate(containers):
		if container_kind == "quote":
			indent_end, _indent_columns = _consume_prefix_indentation(content, cursor, 3)
			if indent_end >= len(content) or content[indent_end] != ">":
				return None
			cursor = indent_end + 1
			if cursor < len(content) and content[cursor] in " \t":
				cursor += 1
			continue
		if not content[cursor:].strip(" \t"):
			return "" if all(kind == "list" for kind, _width in containers[index:]) else None
		indent_end = _consume_required_indentation(content, cursor, required_columns)
		if indent_end is None:
			return None
		cursor = indent_end
	return content[cursor:]


def _consume_prefix_indentation(content: str, start: int, maximum_columns: int) -> tuple[int, int]:
	cursor = start
	columns = 0
	while cursor < len(content) and content[cursor] in " \t":
		next_columns = _advance_indentation_column(content[cursor], columns)
		if next_columns > maximum_columns:
			break
		columns = next_columns
		cursor += 1
	return cursor, columns


def _consume_required_indentation(content: str, start: int, required_columns: int) -> int | None:
	cursor = start
	columns = 0
	while cursor < len(content) and content[cursor] in " \t" and columns < required_columns:
		next_columns = _advance_indentation_column(content[cursor], columns)
		if next_columns > required_columns:
			return None
		columns = next_columns
		cursor += 1
	return cursor if columns == required_columns else None


def _advance_indentation_column(value: str, initial_column: int) -> int:
	column = initial_column
	for character in value:
		column = column + 1 if character == " " else (column // 4 + 1) * 4
	return column


def _is_escaped(text: str, index: int) -> bool:
	backslashes = 0
	cursor = index - 1
	while cursor >= 0 and text[cursor] == "\\":
		backslashes += 1
		cursor -= 1
	return backslashes % 2 == 1


def _documentation_roots(
	project_root: Path,
	architecture: dict[str, Any],
	excluded_root_identities: frozenset[str] = frozenset(),
) -> tuple[
	tuple[tuple[str, Path], ...],
	list[dict[str, str]],
	dict[str, tuple[int, int, int, int, int]],
]:
	declarations = _string_items(architecture.get("documentation_roots"))
	ready: list[tuple[str, Path]] = []
	states: list[dict[str, str]] = []
	pins: dict[str, tuple[int, int, int, int, int]] = {}
	for root in declarations:
		status = _documentation_root_status(project_root, root, excluded_root_identities)
		states.append({"root": root, "status": status})
		if status != "ready":
			continue
		relative = root.removeprefix("res://")
		path = project_root / Path(*relative.split("/"))
		pin = _directory_snapshot(project_root, path)
		if pin is None:
			states[-1]["status"] = "unsafe"
			continue
		ready.append((root, path))
		pins[root] = pin
	ready.sort(key=lambda item: portable_ownership_path_identity(item[0]))
	states.sort(key=lambda item: portable_ownership_path_identity(item["root"]))
	return tuple(ready), states, pins


def _documentation_root_status(
	project_root: Path,
	root: str,
	excluded_root_identities: frozenset[str],
) -> str:
	identity = portable_ownership_path_identity(root)
	if not identity or is_reserved_framework_resource_path(root):
		return "unsafe"
	parts = [part.casefold() for part in root.removeprefix("res://").split("/")]
	if any(part in _SCANNER_EXCLUDED_SEGMENTS for part in parts):
		return "excluded"
	if any(
		identity == generated
		or identity.startswith(generated + "/")
		or generated.startswith(identity + "/")
		for generated in excluded_root_identities
	):
		return "generated"
	path = project_root / Path(*root.removeprefix("res://").split("/"))
	try:
		metadata = path.lstat()
	except FileNotFoundError:
		return "missing"
	except OSError:
		return "unsafe"
	if _is_link_or_reparse(path, metadata):
		return "unsafe"
	if not stat.S_ISDIR(metadata.st_mode):
		return "not_directory"
	return "ready" if _directory_snapshot(project_root, path) is not None else "unsafe"


def _generated_root_identities(architecture: dict[str, Any]) -> frozenset[str]:
	result: set[str] = set()
	modules = architecture.get("modules", [])
	if not isinstance(modules, list):
		return frozenset()
	for module in modules:
		if not isinstance(module, dict) or module.get("ownership") != "generated":
			continue
		for root in module.get("roots", []):
			if isinstance(root, str):
				identity = portable_ownership_path_identity(root)
				if identity:
					result.add(identity)
	return frozenset(result)


def _public_owner_records(api_index: dict[str, Any]) -> dict[str, dict[str, Any]]:
	classes_value = api_index.get("classes", {})
	classes = classes_value if isinstance(classes_value, dict) else {}
	class_member_cache: dict[str, frozenset[str]] = {}

	def class_members(owner_name: str) -> frozenset[str]:
		cached = class_member_cache.get(owner_name)
		if cached is not None:
			return cached
		chain: list[str] = []
		seen: set[str] = set()
		cursor = owner_name
		while cursor in classes and cursor not in class_member_cache and cursor not in seen:
			seen.add(cursor)
			chain.append(cursor)
			record = classes.get(cursor)
			parent_name = record.get("extends") if isinstance(record, dict) else ""
			cursor = parent_name if isinstance(parent_name, str) else ""
		inherited = class_member_cache.get(cursor, frozenset())
		for class_name in reversed(chain):
			record = classes.get(class_name)
			direct = _visible_member_names(record) if isinstance(record, dict) else frozenset()
			inherited = inherited.union(direct)
			class_member_cache[class_name] = inherited
		return class_member_cache.get(owner_name, frozenset())

	result: dict[str, dict[str, Any]] = {}
	for owner_kind, field in (("class", "classes"), ("autoload", "autoloads")):
		records = api_index.get(field, {})
		if not isinstance(records, dict):
			continue
		for owner_name, record in records.items():
			if not isinstance(owner_name, str) or not isinstance(record, dict):
				continue
			if record.get("visibility") != "public":
				continue
			members = set(_visible_member_names(record))
			if owner_kind == "class":
				members.update(class_members(owner_name))
			else:
				parent_name = record.get("extends")
				if isinstance(parent_name, str) and parent_name in classes:
					members.update(class_members(parent_name))
			result[owner_name] = {
				"owner_kind": owner_kind,
				"package_id": str(record.get("package_id", "")),
				"members": frozenset(members),
			}
	return result


def _visible_member_names(record: dict[str, Any]) -> frozenset[str]:
	return frozenset(
		str(member.get("name"))
		for member in record.get("members", [])
		if isinstance(member, dict)
		and member.get("visibility") in ("public", "protected")
		and isinstance(member.get("name"), str)
		and member.get("name")
	)


def _documentation_catalog_issues(api_index: dict[str, Any]) -> list[str]:
	issues: list[str] = []
	classes_value = api_index.get("classes")
	classes = classes_value if isinstance(classes_value, dict) else {}
	for owner_kind, field in (("class", "classes"), ("autoload", "autoloads")):
		records = api_index.get(field)
		if not isinstance(records, dict):
			continue
		for owner_name, record in records.items():
			if not isinstance(owner_name, str) or not isinstance(record, dict):
				continue
			if _GF_OWNER_PATTERN.fullmatch(owner_name) is None:
				issues.append(f"API index {owner_kind} name is not a bounded GF owner identifier: {owner_name!r}.")
			if record.get("visibility") != "public":
				issues.append(f"API index {owner_kind} visibility is not public: {owner_name}.")
			package_id = record.get("package_id")
			if not isinstance(package_id, str) or _PACKAGE_ID_PATTERN.fullmatch(package_id) is None:
				issues.append(f"API index {owner_kind} package_id is not bounded and canonical: {owner_name}.")
			parent_name = record.get("extends")
			if not isinstance(parent_name, str):
				issues.append(f"API index {owner_kind} extends is not a string: {owner_name}.")
			elif _GF_OWNER_PATTERN.fullmatch(parent_name) is not None and parent_name not in classes:
				issues.append(f"API index {owner_kind} has an unknown GF parent class: {owner_name} -> {parent_name}.")
			members = record.get("members")
			if not isinstance(members, list):
				continue
			seen_members: set[str] = set()
			for member in members:
				if not isinstance(member, dict):
					continue
				member_name = member.get("name")
				if not isinstance(member_name, str) or _MEMBER_PATTERN.fullmatch(member_name) is None:
					issues.append(f"API index {owner_kind} has an invalid bounded member name: {owner_name}.")
					continue
				if member_name in seen_members:
					issues.append(f"API index {owner_kind} member is duplicated: {owner_name}.{member_name}.")
				seen_members.add(member_name)
				if member.get("visibility") not in ("public", "protected"):
					issues.append(f"API index {owner_kind} member visibility is invalid: {owner_name}.{member_name}.")
	issues.extend(_class_inheritance_cycle_issues(classes))
	return issues


def _class_inheritance_cycle_issues(classes: dict[str, Any]) -> list[str]:
	graph = {
		owner_name: str(record.get("extends"))
		for owner_name, record in classes.items()
		if isinstance(owner_name, str)
		and isinstance(record, dict)
		and isinstance(record.get("extends"), str)
		and record.get("extends") in classes
	}
	visited: set[str] = set()
	issues: list[str] = []

	for start_owner in sorted(graph):
		if start_owner in visited:
			continue
		path: list[str] = []
		positions: dict[str, int] = {}
		owner_name = start_owner
		while owner_name in graph and owner_name not in visited and owner_name not in positions:
			positions[owner_name] = len(path)
			path.append(owner_name)
			owner_name = graph[owner_name]
		if owner_name in positions:
			cycle = path[positions[owner_name]:] + [owner_name]
			issues.append("API index class inheritance contains a cycle: " + " -> ".join(cycle) + ".")
		visited.update(path)
	return issues


def _catalog_identity(project_root: Path, api_index: dict[str, Any]) -> dict[str, Any]:
	project_version = catalog.project_framework_version(project_root)
	framework_version = str(api_index.get("framework_version", ""))
	raw_schema_version = api_index.get("schema_version")
	schema_version = (
		raw_schema_version
		if isinstance(raw_schema_version, int) and not isinstance(raw_schema_version, bool) and raw_schema_version >= 0
		else 0
	)
	return {
		"schema_version": schema_version,
		"catalog_version": str(api_index.get("catalog_version", "")),
		"framework_version": framework_version,
		"project_framework_version": project_version,
		"source_digest": str(api_index.get("source_digest", "")),
		"matches_project": bool(project_version) and project_version == framework_version,
	}


def _canonical_resource_path(project_root: Path, path: Path) -> str:
	try:
		relative = path.relative_to(project_root)
	except ValueError:
		return ""
	if not relative.parts:
		return ""
	resource_path = "res://" + "/".join(relative.parts)
	if len(resource_path) > MAX_SOURCE_PATH_LENGTH:
		return ""
	try:
		resource_path.encode("utf-8", errors="strict")
	except UnicodeEncodeError:
		return ""
	return resource_path if portable_ownership_path_identity(resource_path) else ""


def _directory_snapshot(
	project_root: Path,
	path: Path,
) -> tuple[int, int, int, int, int] | None:
	try:
		relative = path.relative_to(project_root)
		if not relative.parts or project_path_has_link_component(project_root, "/".join(relative.parts)):
			return None
		metadata = path.lstat()
		if not stat.S_ISDIR(metadata.st_mode) or _is_link_or_reparse(path, metadata):
			return None
		path.resolve(strict=True).relative_to(project_root.resolve(strict=True))
	except (OSError, ValueError):
		return None
	return _identity_snapshot(metadata)


def _regular_snapshot(
	project_root: Path,
	path: Path,
) -> tuple[int, int, int, int, int] | None:
	try:
		relative = path.relative_to(project_root)
		if not relative.parts or project_path_has_link_component(project_root, "/".join(relative.parts)):
			return None
		metadata = path.lstat()
		if not stat.S_ISREG(metadata.st_mode) or _is_link_or_reparse(path, metadata):
			return None
		path.resolve(strict=True).relative_to(project_root.resolve(strict=True))
	except (OSError, ValueError):
		return None
	return _identity_snapshot(metadata)


def _identity_snapshot(metadata: os.stat_result) -> tuple[int, int, int, int, int]:
	return (
		int(metadata.st_dev),
		int(metadata.st_ino),
		int(metadata.st_mode),
		int(metadata.st_size),
		int(metadata.st_mtime_ns),
	)


def _is_link_or_reparse(path: Path, metadata: os.stat_result) -> bool:
	if path.is_symlink():
		return True
	reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
	return bool(reparse_flag and getattr(metadata, "st_file_attributes", 0) & reparse_flag)


def _string_items(value: Any) -> list[str]:
	return [str(item) for item in value if isinstance(item, str) and item] if isinstance(value, list) else []


def _clamped_limit(value: Any, hard_limit: int) -> int:
	if not isinstance(value, int) or isinstance(value, bool):
		return 0
	return max(0, min(value, hard_limit))


def _bounded_message(value: Any, limit: int = 500) -> str:
	message = str(value)
	return message if len(message) <= limit else message[:limit - 1] + "…"
