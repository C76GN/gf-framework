#!/usr/bin/env python3
"""Shared strict Markdown parsing for the current GF changelog."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
import html
import re
from typing import Any


CHANGELOG_TITLE = "# 更新日志 (Changelog)"
CHANGELOG_CATEGORY_RE = re.compile(r"^### (?P<category>.+)$")
CHANGELOG_OVERVIEW_RE = re.compile(r"^\*\*版本概述\*\*：(?P<body>.*)$")
CHANGELOG_CATEGORY_HEADINGS: tuple[str, ...] = (
	"🚀 新增特性 (Added)",
	"🔄 机制更改 (Changed)",
	"🐛 Bug 修复 (Fixed)",
	"⚠️ 废弃与移除 (Deprecated/Removed)",
	"🔧 API 变动说明 (API Changes)",
	"📘 升级指南 (Migration Guide)",
)
INTERNAL_PATH_ONLY_LIST_ITEM_RE = re.compile(
	r"^- `(?:\.github|addons/gf|ai_analysis|docs/maintainers|packages|tests|tools)"
	r"(?:/[^`]+)?/?`[。.]?$"
)
FORMAL_HEADING_RE = re.compile(
	r"^## \[(?P<version>(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*))\] "
	r"- (?P<date>\d{4}-\d{2}-\d{2})$"
)

CHANGELOG_VERSION_TEXT_RE = re.compile(
	r"^\[(?P<version>[^\]]+)\](?:[ \t].*)?$"
)
FENCE_RE = re.compile(r"^ {0,3}(?P<fence>`{3,}|~{3,})(?P<suffix>.*)$")
ATX_HEADING_RE = re.compile(
	r"^(?P<indent> {0,3})(?P<marker>#{1,6})(?:[ \t]+(?P<text>.*)|[ \t]*)$"
)
SETEXT_UNDERLINE_RE = re.compile(
	r"^ {0,3}(?P<marker>=+|-+)[ \t]*$"
)
HTML_TOKEN_RE = re.compile(r"<(?:/?[A-Za-z]|[!?])")
REFERENCE_DEFINITION_RE = re.compile(
	r"^ {0,3}\[(?P<label>[^\]\r\n]+)\]:[ \t]*(?P<destination>.*)$"
)
BLOCKQUOTE_PREFIX_RE = re.compile(r"^ {0,3}>[ \t]?")
LIST_PREFIX_RE = re.compile(
	r"^ {0,3}(?:[-+*]|[0-9]{1,9}[.)])(?:[ \t]+|$)"
)


@dataclass(frozen=True)
class VisibleMarkdownLine:
	"""One source line outside fenced/indented code and HTML comments."""

	offset: int
	line_number: int
	raw: str
	visible: str


@dataclass(frozen=True)
class MarkdownHeading:
	"""One visible ATX or Setext heading with its source position."""

	level: int
	text: str
	offset: int
	line_number: int
	raw: str
	style: str


def visible_markdown_lines(text: str) -> list[VisibleMarkdownLine]:
	"""Return source-preserving lines that can contribute visible Markdown.

	Block syntax is recognized only from the original source line. HTML comment
	removal never splices tokens into a new fence or heading.
	"""

	result: list[VisibleMarkdownLine] = []
	fence_character = ""
	fence_length = 0
	in_html_comment = False
	for offset, raw_line in enumerate(text.splitlines()):
		if fence_character:
			fence_match = FENCE_RE.fullmatch(raw_line)
			if fence_match is not None:
				marker = fence_match.group("fence")
				if (
					marker[0] == fence_character
					and len(marker) >= fence_length
					and not fence_match.group("suffix").strip()
				):
					fence_character = ""
					fence_length = 0
			continue

		if in_html_comment:
			if "-->" in raw_line:
				in_html_comment = False
			continue
		comment_start = raw_line.find("<!--")
		if comment_start >= 0:
			if raw_line.find("-->", comment_start + 4) < 0:
				in_html_comment = True
			continue

		fence_match = FENCE_RE.fullmatch(raw_line)
		if fence_match is not None and is_valid_opening_fence(fence_match):
			marker = fence_match.group("fence")
			fence_character = marker[0]
			fence_length = len(marker)
			continue
		if is_indented_code(raw_line):
			continue
		result.append(
			VisibleMarkdownLine(
				offset=offset,
				line_number=offset + 1,
				raw=raw_line,
				visible=raw_line,
			)
		)
	return result


def markdown_syntax_issues(text: str) -> list[str]:
	"""Reject ambiguous syntax that the strict changelog grammar does not use."""

	issues: list[str] = []
	fence_character = ""
	fence_length = 0
	in_html_comment = False
	for line_number, raw_line in enumerate(text.splitlines(), start=1):
		if fence_character:
			fence_match = FENCE_RE.fullmatch(raw_line)
			if fence_match is not None:
				marker = fence_match.group("fence")
				if (
					marker[0] == fence_character
					and len(marker) >= fence_length
					and not fence_match.group("suffix").strip()
				):
					fence_character = ""
					fence_length = 0
			continue

		if in_html_comment:
			comment_end = raw_line.find("-->")
			if comment_end >= 0:
				if raw_line[comment_end + 3:].strip():
					issues.append(
						f"line {line_number} mixes an HTML comment with visible content."
					)
				in_html_comment = False
			continue

		comment_start = raw_line.find("<!--")
		if comment_start >= 0:
			comment_end = raw_line.find("-->", comment_start + 4)
			prefix = raw_line[:comment_start]
			suffix = raw_line[comment_end + 3:] if comment_end >= 0 else ""
			if prefix.strip() or suffix.strip():
				issues.append(
					f"line {line_number} mixes an HTML comment with visible content."
				)
			if comment_end < 0:
				in_html_comment = True
			continue

		fence_match = FENCE_RE.fullmatch(raw_line)
		if fence_match is not None and is_valid_opening_fence(fence_match):
			marker = fence_match.group("fence")
			fence_character = marker[0]
			fence_length = len(marker)
			continue
		if is_indented_code(raw_line):
			continue
		container_content, has_container = strip_markdown_container_prefix(raw_line)
		if has_container and (
			ATX_HEADING_RE.fullmatch(container_content) is not None
			or SETEXT_UNDERLINE_RE.fullmatch(container_content) is not None
		):
			issues.append(
				f"line {line_number} contains a heading inside a list or blockquote container."
			)
		if is_reference_definition(container_content):
			issues.append(
				f"line {line_number} contains a Markdown reference definition; "
				"changelog policy and entry text must remain visibly rendered."
			)
		if HTML_TOKEN_RE.search(raw_line):
			issues.append(
				f"line {line_number} contains raw HTML; changelog structure must use plain Markdown."
			)

	if in_html_comment:
		issues.append("HTML comment is not closed.")
	if fence_character:
		issues.append("fenced code block is not closed.")
	return issues


def parse_markdown_headings(text: str) -> list[MarkdownHeading]:
	"""Parse visible ATX and Setext headings without container coercion."""

	visible_lines = visible_markdown_lines(text)
	by_offset = {line.offset: line for line in visible_lines}
	headings: list[MarkdownHeading] = []
	atx_offsets: set[int] = set()
	for line in visible_lines:
		match = ATX_HEADING_RE.fullmatch(line.visible)
		if match is None:
			continue
		marker = match.group("marker")
		heading_text = re.sub(
			r"[ \t]+#+[ \t]*$",
			"",
			match.group("text") or "",
		).strip(" \t")
		headings.append(
			MarkdownHeading(
				level=len(marker),
				text=heading_text,
				offset=line.offset,
				line_number=line.line_number,
				raw=line.raw,
				style="atx",
			)
		)
		atx_offsets.add(line.offset)

	for line in visible_lines:
		match = SETEXT_UNDERLINE_RE.fullmatch(line.visible)
		if match is None:
			continue
		previous = by_offset.get(line.offset - 1)
		if (
			previous is None
			or not previous.visible.strip()
			or previous.offset in atx_offsets
			or is_thematic_break(previous.visible)
		):
			continue
		headings.append(
			MarkdownHeading(
				level=1 if match.group("marker")[0] == "=" else 2,
				text=previous.visible.strip(),
				offset=previous.offset,
				line_number=previous.line_number,
				raw=f"{previous.raw}\n{line.raw}",
				style="setext",
			)
		)

	return sorted(headings, key=lambda heading: (heading.offset, heading.level))


def parse_changelog_sections(text: str) -> list[dict[str, object]]:
	"""Parse visible ``## [version]`` sections while preserving exact bodies."""

	source_lines = text.splitlines()
	all_headings = parse_markdown_headings(text)
	version_headings: list[dict[str, object]] = []
	for heading in all_headings:
		if heading.level != 2:
			continue
		match = CHANGELOG_VERSION_TEXT_RE.fullmatch(heading.text)
		if match is None:
			continue
		version_headings.append({
			"version": match.group("version").strip(),
			"line": heading.line_number,
			"heading": heading.raw,
			"offset": heading.offset,
		})

	sections: list[dict[str, object]] = []
	for heading in version_headings:
		start_offset = int(heading["offset"])
		later_top_level_offsets = [
			candidate.offset
			for candidate in all_headings
			if candidate.level <= 2 and candidate.offset > start_offset
		]
		end_offset = min(later_top_level_offsets) if later_top_level_offsets else len(source_lines)
		sections.append({
			"version": heading["version"],
			"line": heading["line"],
			"heading": heading["heading"],
			"body": "\n".join(source_lines[start_offset + 1:end_offset]),
		})
	return sections


def strict_document_heading_issues(
	text: str,
	candidate_heading: str,
) -> list[str]:
	"""Require the one supported top-level changelog document layout."""

	issues: list[str] = []
	first_visible_line = first_visible_nonempty_source_line(text)
	if first_visible_line is None or first_visible_line.raw != CHANGELOG_TITLE:
		found = first_visible_line.raw if first_visible_line is not None else ""
		issues.append(
			f"the first visible non-empty line must be exactly {CHANGELOG_TITLE!r}; "
			f"found {found!r}."
		)
	actual = [
		heading.raw
		for heading in parse_markdown_headings(text)
		if heading.level <= 2
	]
	expected = [
		CHANGELOG_TITLE,
		candidate_heading,
	]
	if actual != expected:
		issues.append(
			"top-level headings must be exactly, in order: "
			+ " -> ".join(expected)
			+ f"; found {actual}."
		)
	return issues


def first_visible_nonempty_source_line(text: str) -> VisibleMarkdownLine | None:
	"""Return the first non-comment source line that renders block content."""

	in_html_comment = False
	for offset, raw_line in enumerate(text.splitlines()):
		if not raw_line.strip():
			continue
		if in_html_comment:
			comment_end = raw_line.find("-->")
			if comment_end < 0:
				continue
			in_html_comment = False
			if not raw_line[comment_end + 3:].strip():
				continue
		comment_start = raw_line.find("<!--")
		if comment_start >= 0:
			comment_end = raw_line.find("-->", comment_start + 4)
			prefix = raw_line[:comment_start]
			suffix = raw_line[comment_end + 3:] if comment_end >= 0 else ""
			if not prefix.strip() and not suffix.strip():
				if comment_end < 0:
					in_html_comment = True
				continue
		return VisibleMarkdownLine(
			offset=offset,
			line_number=offset + 1,
			raw=raw_line,
			visible=raw_line,
		)
	return None


def is_valid_opening_fence(match: re.Match[str]) -> bool:
	"""Return whether a fence opener follows the CommonMark info-string rule."""

	marker = match.group("fence")
	return marker[0] == "~" or "`" not in match.group("suffix")


def is_indented_code(line: str) -> bool:
	"""Return whether leading spaces/tabs reach a four-column Markdown indent."""

	column = 0
	for character in line:
		if character == " ":
			column += 1
		elif character == "\t":
			column += 4 - (column % 4)
		else:
			break
		if column >= 4:
			return True
	return False


def strip_markdown_container_prefix(line: str) -> tuple[str, bool]:
	"""Strip list/blockquote container markers without coercing their content."""

	remainder = line
	has_container = False
	while True:
		blockquote_match = BLOCKQUOTE_PREFIX_RE.match(remainder)
		if blockquote_match is not None:
			remainder = remainder[blockquote_match.end():]
			has_container = True
			continue
		list_match = LIST_PREFIX_RE.match(remainder)
		if list_match is not None:
			remainder = remainder[list_match.end():]
			has_container = True
			continue
		return remainder, has_container


def is_reference_definition(line: str) -> bool:
	"""Return whether a source line is a non-rendered Markdown link definition."""

	return REFERENCE_DEFINITION_RE.fullmatch(line) is not None


def is_thematic_break(line: str) -> bool:
	"""Return whether one visible line is a CommonMark thematic break."""

	trimmed = line.lstrip(" ")
	if len(line) - len(trimmed) > 3:
		return False
	compact = trimmed.replace(" ", "").replace("\t", "")
	return (
		len(compact) >= 3
		and compact[0] in {"*", "-", "_"}
		and all(character == compact[0] for character in compact)
	)


def has_readable_text(value: str) -> bool:
	"""Require at least one rendered Unicode letter or number."""

	return any(character.isalnum() for character in markdown_plain_text(value))


def markdown_plain_text(value: str) -> str:
	"""Return conservative reader-visible text for supported inline Markdown."""

	plain_lines: list[str] = []
	for raw_line in value.splitlines() or [value]:
		if REFERENCE_DEFINITION_RE.match(raw_line):
			plain_lines.append("")
			continue
		plain_lines.append(_inline_markdown_plain_text(html.unescape(raw_line)))
	return "\n".join(plain_lines)


def _inline_markdown_plain_text(value: str) -> str:
	result: list[str] = []
	index = 0
	while index < len(value):
		character = value[index]
		if character == "\\" and index + 1 < len(value):
			result.append(value[index + 1])
			index += 2
			continue
		if character == "`":
			run_end = index + 1
			while run_end < len(value) and value[run_end] == "`":
				run_end += 1
			marker = value[index:run_end]
			close_index = value.find(marker, run_end)
			if close_index >= 0:
				result.append(value[run_end:close_index])
				index = close_index + len(marker)
			else:
				index = run_end
			continue

		is_image = character == "!" and index + 1 < len(value) and value[index + 1] == "["
		label_open = index + 1 if is_image else index
		label_start = label_open + 1
		if character == "[" or is_image:
			close_label = _find_balanced_square_bracket(value, label_open)
			if close_label >= 0:
				label = value[label_start:close_label]
				next_index = close_label + 1
				if next_index < len(value) and value[next_index] == "(":
					close_destination = _find_balanced_parenthesis(value, next_index)
					if close_destination >= 0:
						result.append(_inline_markdown_plain_text(label))
						index = close_destination + 1
						continue
				if next_index < len(value) and value[next_index] == "[":
					close_reference = _find_unescaped(value, "]", next_index + 1)
					if close_reference >= 0:
						result.append(_inline_markdown_plain_text(label))
						index = close_reference + 1
						continue
				result.append(_inline_markdown_plain_text(label))
				index = next_index
				continue

		if character not in {"*", "_", "~", "#", ">"}:
			result.append(character)
		index += 1
	return "".join(result)


def _find_unescaped(value: str, target: str, start: int) -> int:
	index = start
	while index < len(value):
		if value[index] == "\\":
			index += 2
			continue
		if value[index] == target:
			return index
		index += 1
	return -1


def _find_balanced_square_bracket(value: str, start: int) -> int:
	depth = 0
	index = start
	while index < len(value):
		if value[index] == "\\":
			index += 2
			continue
		if value[index] == "[":
			depth += 1
		elif value[index] == "]":
			depth -= 1
			if depth == 0:
				return index
		index += 1
	return -1


def _find_balanced_parenthesis(value: str, start: int) -> int:
	depth = 0
	index = start
	while index < len(value):
		if value[index] == "\\":
			index += 2
			continue
		if value[index] == "(":
			depth += 1
		elif value[index] == ")":
			depth -= 1
			if depth == 0:
				return index
		index += 1
	return -1


def validate_document_layout(
	text: str,
	candidate_heading: str,
	path_label: str,
) -> list[str]:
	"""Validate a reader-only changelog document and its exact top-level shape."""

	issues = [
		f"{path_label} {issue}"
		for issue in markdown_syntax_issues(text)
	]
	issues.extend(
		f"{path_label} {issue}"
		for issue in strict_document_heading_issues(text, candidate_heading)
	)

	return issues


def validate_formal_section(
	section: dict[str, Any],
	path_label: str,
) -> list[str]:
	"""Validate one stable release candidate section."""

	issues: list[str] = []
	if not str(section["body"]).strip():
		issues.append(f"{path_label} section [{section['version']}] must not be empty.")
	heading = str(section["heading"])
	date_match = FORMAL_HEADING_RE.fullmatch(heading)
	if date_match is None or date_match.group("version") != str(section["version"]):
		issues.append(
			f"{path_label} line {section['line']} formal heading must use "
			"'## [x.y.z] - YYYY-MM-DD'."
		)
		return issues
	try:
		date.fromisoformat(date_match.group("date"))
	except ValueError:
		issues.append(f"{path_label} line {section['line']} contains an invalid calendar date.")
	issues.extend(validate_entry_structure(section, path_label))
	return issues


def validate_unreleased_section(
	section: dict[str, Any],
	path_label: str,
) -> list[str]:
	"""Validate one development release candidate section."""

	issues: list[str] = []
	if str(section["heading"]) != "## [未发布]":
		issues.append(
			f"{path_label} line {section['line']} development heading must use exactly "
			"'## [未发布]'."
		)
	if not str(section["body"]).strip():
		issues.append(f"{path_label} section [未发布] must not be empty.")
	issues.extend(validate_entry_structure(section, path_label))
	return issues


def validate_entry_structure(
	section: dict[str, Any],
	path_label: str,
) -> list[str]:
	"""Validate the reader-visible overview and ordered category bodies."""

	body_text = str(section["body"])
	body_lines = body_text.splitlines()
	issues: list[str] = []
	visible_lines = visible_markdown_lines(body_text)
	for line in visible_lines:
		if INTERNAL_PATH_ONLY_LIST_ITEM_RE.fullmatch(line.visible.strip()):
			issues.append(
				f"{path_label} line {int(section['line']) + line.line_number} "
				"must describe a consumer-visible change instead of listing only an "
				"internal repository path."
			)
	overview_lines = [
		line
		for line in visible_lines
		if line.visible.lstrip(" \t").startswith("**版本概述**")
	]
	if len(overview_lines) != 1:
		issues.append(
			f"{path_label} section [{section['version']}] must contain exactly one "
			"'**版本概述**：...' line."
		)
	else:
		overview_line = overview_lines[0]
		overview_match = CHANGELOG_OVERVIEW_RE.fullmatch(overview_line.visible)
		if overview_match is None or not has_readable_text(overview_match.group("body")):
			issues.append(
				f"{path_label} line {int(section['line']) + overview_line.line_number} "
				"must use a top-level, non-empty '**版本概述**：...' entry."
			)

	first_visible_line = first_visible_nonempty_source_line(body_text)
	if (
		len(overview_lines) == 1
		and first_visible_line is not None
		and first_visible_line.offset != overview_lines[0].offset
	):
		issues.append(
			f"{path_label} line {int(section['line']) + overview_lines[0].line_number} "
			"version overview must be the first visible entry after the version heading."
		)

	body_headings = parse_markdown_headings(body_text)
	category_entries: list[dict[str, Any]] = []
	for heading in body_headings:
		line_number = int(section["line"]) + heading.line_number
		if heading.level != 3:
			issues.append(
				f"{path_label} line {line_number} uses unsupported H{heading.level} "
				"inside a changelog candidate; only top-level H3 categories are allowed."
			)
			continue
		category_match = CHANGELOG_CATEGORY_RE.fullmatch(heading.raw)
		if category_match is None:
			issues.append(
				f"{path_label} line {line_number} category headings must start at column 1 "
				"and use exactly '### <standard category>'."
			)
			category_entries.append({
				"name": heading.text,
				"offset": heading.offset,
				"line": line_number,
				"supported": False,
			})
			continue
		category = category_match.group("category")
		category_entries.append({
			"name": category,
			"offset": heading.offset,
			"line": line_number,
			"supported": category in CHANGELOG_CATEGORY_HEADINGS,
		})

	supported_entries = [entry for entry in category_entries if entry["supported"]]
	if not supported_entries:
		issues.append(
			f"{path_label} section [{section['version']}] must contain at least one "
			"standard change category."
		)

	overview_offsets = {line.offset for line in overview_lines}
	heading_offsets = {heading.offset for heading in body_headings}
	seen_categories: set[str] = set()
	last_category_index = -1
	for entry_index, entry in enumerate(category_entries):
		category = str(entry["name"])
		line_number = int(entry["line"])
		if not entry["supported"]:
			issues.append(
				f"{path_label} line {line_number} uses unsupported changelog category "
				f"'### {category}'."
			)
			continue
		if category in seen_categories:
			issues.append(
				f"{path_label} line {line_number} duplicates changelog category "
				f"'### {category}'."
			)
		seen_categories.add(category)
		category_index = CHANGELOG_CATEGORY_HEADINGS.index(category)
		if category_index < last_category_index:
			issues.append(
				f"{path_label} line {line_number} places '### {category}' outside the "
				"standard category order."
			)
		last_category_index = max(last_category_index, category_index)

		next_offset = (
			int(category_entries[entry_index + 1]["offset"])
			if entry_index + 1 < len(category_entries)
			else len(body_lines)
		)
		content_lines = [
			line.visible
			for line in visible_lines
			if int(entry["offset"]) < line.offset < next_offset
			and line.visible.strip()
			and not line.visible.startswith((" ", "\t"))
			and not is_thematic_break(line.visible)
			and line.offset not in overview_offsets
			and line.offset not in heading_offsets
			and has_readable_text(line.visible)
		]
		if not content_lines:
			issues.append(
				f"{path_label} line {line_number} category '### {category}' must not be empty."
			)
	return issues
