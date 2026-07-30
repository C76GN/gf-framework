#!/usr/bin/env python3
"""Reject CodeQL suppressions and configuration escape hatches in tracked sources."""

from __future__ import annotations

import io
import re
import tokenize
import unicodedata
from pathlib import Path

from gf_path_security import PinnedReadError
from gf_path_security import read_pinned_utf8_regular_file


SCHEMA_VERSION = 1
CODEQL_MARKER_RE = re.compile(r"#\s*codeql\b", re.IGNORECASE)
LGTM_MARKER_RE = re.compile(r"#\s*lgtm\s*\[", re.IGNORECASE)
TRACKED_PATH_CONTROL_CATEGORIES = frozenset(("Cc", "Cf"))
MAX_TRACKED_SOURCE_BYTES = 16 * 1024 * 1024
CODEQL_ACTION_REFERENCE = "github/codeql-action/"
MAX_YAML_LEXER_WORK_UNITS = 8 * 1024 * 1024
YAML_NODE_PROPERTY_PATTERN = (
	r"(?:!<[^>\r\n]+>|![^\s,\[\]{}]+|&[^\s,\[\]{}]+)"
)


def audit_tracked_sources(
	root: Path,
	tracked_paths: list[str],
	git_error: str = "",
) -> dict[str, object]:
	"""Audit only the explicit tracked-file inventory supplied by the maintenance runner."""
	issues: list[dict[str, object]] = []
	if git_error:
		issues.append(_issue(
			"codeql_suppression.git_index_unavailable",
			"git-index",
			0,
			"Git tracked-file inventory is unavailable.",
		))
		return _result(tracked_paths, 0, 0, 0, issues)

	inventory_issues, canonical_paths = _audit_tracked_path_inventory(tracked_paths)
	if inventory_issues:
		return _result(tracked_paths, 0, 0, 0, inventory_issues)

	python_file_count = 0
	config_file_count = 0
	suppression_count = 0
	for normalized_path in canonical_paths:
		if normalized_path.lower().endswith(".py"):
			python_file_count += 1
			try:
				source = read_pinned_utf8_regular_file(
					root,
					normalized_path,
					max_bytes=MAX_TRACKED_SOURCE_BYTES,
				)
			except PinnedReadError:
				issues.append(_issue(
					"codeql_suppression.python_source_unreadable",
					"tracked-python-source",
					0,
					"Tracked Python source failed the pinned UTF-8 read boundary.",
				))
				continue
			source_issues, source_suppressions = audit_python_source(normalized_path, source)
			issues.extend(source_issues)
			suppression_count += source_suppressions
			continue
		if not _is_possible_codeql_config_path(normalized_path):
			continue
		try:
			source = read_pinned_utf8_regular_file(
				root,
				normalized_path,
				max_bytes=MAX_TRACKED_SOURCE_BYTES,
			)
		except PinnedReadError:
			issues.append(_issue(
				"codeql_suppression.config_unreadable",
				"tracked-codeql-config",
				0,
				"Tracked CodeQL configuration failed the pinned UTF-8 read boundary.",
			))
			continue
		if not _is_codeql_config(normalized_path, source):
			continue
		config_file_count += 1
		issues.extend(audit_codeql_config(normalized_path, source))

	return _result(
		tracked_paths,
		python_file_count,
		config_file_count,
		suppression_count,
		issues,
	)


def _audit_tracked_path_inventory(
	tracked_paths: list[str],
) -> tuple[list[dict[str, object]], list[str]]:
	issues: list[dict[str, object]] = []
	canonical_paths: list[str] = []
	paths_by_portable_identity: dict[str, list[str]] = {}
	for relative_path in sorted(set(tracked_paths)):
		if any(
			unicodedata.category(character) in TRACKED_PATH_CONTROL_CATEGORIES
			for character in relative_path
		):
			issues.append(_issue(
				"codeql_suppression.tracked_path_control_character",
				"git-index",
				0,
				"Git tracked-file inventory contains a control or format character.",
			))
			continue
		if (
			"\\" in relative_path
			or relative_path.startswith("/")
			or re.match(r"^[A-Za-z]:", relative_path) is not None
			or any(part in ("", ".", "..") for part in relative_path.split("/"))
			or unicodedata.normalize("NFC", relative_path) != relative_path
		):
			issues.append(_issue(
				"codeql_suppression.tracked_path_noncanonical",
				"git-index",
				0,
				"Git tracked-file inventory contains a non-canonical path.",
			))
			continue
		canonical_paths.append(relative_path)
		portable_identity = unicodedata.normalize(
			"NFC",
			unicodedata.normalize("NFC", relative_path).casefold(),
		)
		paths_by_portable_identity.setdefault(portable_identity, []).append(relative_path)

	if any(
		len(set(identity_paths)) > 1
		for identity_paths in paths_by_portable_identity.values()
	):
		issues.append(_issue(
			"codeql_suppression.tracked_path_collision",
			"git-index",
			0,
			"Git tracked-file inventory contains paths with a colliding portable identity.",
		))
	return issues, canonical_paths


def audit_python_source(path: str, source: str) -> tuple[list[dict[str, object]], int]:
	"""Reject suppression comment tokens while ignoring directive-looking string content."""
	issues: list[dict[str, object]] = []
	try:
		tokens = list(tokenize.generate_tokens(io.StringIO(source).readline))
	except (IndentationError, tokenize.TokenError):
		return [
			_issue(
				"codeql_suppression.python_tokenization_failed",
				path,
				0,
				"Tracked Python source could not be tokenized.",
			)
		], 0

	suppression_count = 0
	for token in tokens:
		if token.type != tokenize.COMMENT:
			continue
		comment = token.string.strip()
		if LGTM_MARKER_RE.search(comment):
			suppression_count += 1
			issues.append(_issue(
				"codeql_suppression.legacy_lgtm_directive",
				path,
				token.start[0],
				"Legacy lgtm suppression directives are forbidden.",
			))
			continue
		if CODEQL_MARKER_RE.search(comment):
			suppression_count += 1
			issues.append(_issue(
				"codeql_suppression.python_directive_forbidden",
				path,
				token.start[0],
				"Python CodeQL suppression directives are forbidden.",
			))

	return issues, suppression_count


def audit_codeql_config(path: str, source: str) -> list[dict[str, object]]:
	"""Conservatively reject broad CodeQL escape hatches from YAML mapping keys."""
	if path.lower().endswith(".qls"):
		return [_issue(
			"codeql_suppression.custom_queries_forbidden",
			path,
			1,
			"Tracked custom CodeQL query suites are forbidden.",
		)]
	if _yaml_lexer_budget_exceeded(source):
		return [_issue(
			"codeql_suppression.yaml_lexer_budget_exceeded",
			path,
			1,
			"CodeQL policy YAML exceeds the bounded lexer work budget.",
		)]
	issues: list[dict[str, object]] = []
	effective_lines, continuation_lines = _normalize_yaml_policy_lines(source)
	mapping_keys, complex_key_lines = _yaml_mapping_key_lines(effective_lines)
	for line_number in continuation_lines:
		issues.append(_issue(
			"codeql_suppression.yaml_line_continuation_forbidden",
			path,
			line_number,
			"CodeQL policy YAML must not use escaped line continuations.",
		))
	for line_number in complex_key_lines:
		issues.append(_issue(
			"codeql_suppression.complex_mapping_key_forbidden",
			path,
			line_number,
			"CodeQL policy YAML must use direct scalar mapping keys.",
		))
	for token, kind, message in (
		(
			"disable-default-queries",
			"codeql_suppression.default_queries_disabled",
			"CodeQL default queries must not be customized.",
		),
		(
			"config-file",
			"codeql_suppression.custom_config_reference_forbidden",
			"CodeQL workflows must not delegate policy to a custom config file.",
		),
		(
			"paths-ignore",
			"codeql_suppression.tests_path_ignored",
			"CodeQL configuration must not ignore source paths.",
		),
		(
			"paths",
			"codeql_suppression.source_paths_filtered",
			"CodeQL configuration must not restrict analyzed source paths.",
		),
		(
			"query-filters",
			"codeql_suppression.security_query_excluded",
			"CodeQL query filters are forbidden.",
		),
		(
			"queries",
			"codeql_suppression.custom_queries_forbidden",
			"Custom CodeQL query suites are forbidden.",
		),
	):
		line_number = next(
			(
				key_line
				for key_line, key in mapping_keys
				if key.casefold() == token
			),
			0,
		)
		if line_number > 0:
			issues.append(_issue(kind, path, line_number, message))
	return issues


def _normalize_yaml_policy_lines(
	source: str,
) -> tuple[list[tuple[int, str]], list[int]]:
	if source.startswith("\ufeff"):
		source = source[1:]
	normalized_lines: list[tuple[int, str]] = []
	continuation_lines: list[int] = []
	block_scalar_base_indent = -1
	block_scalar_content_indent = -1
	pending_line_number = 0
	pending_text = ""
	pending_quote = ""
	pending_join_without_space = False
	pending_quote_start = -1
	pending_escape_lines: list[int] = []
	for line_number, raw_line in enumerate(source.splitlines(), start=1):
		if pending_line_number == 0 and block_scalar_base_indent >= 0:
			if not raw_line.strip():
				continue
			line_indent = _yaml_line_indent(raw_line)
			if block_scalar_content_indent < 0:
				if line_indent > block_scalar_base_indent:
					block_scalar_content_indent = line_indent
					continue
			elif line_indent >= block_scalar_content_indent:
				continue
			block_scalar_base_indent = -1
			block_scalar_content_indent = -1

		line, line_quote, escaped_line_break = _strip_yaml_comment_and_quote(
			raw_line,
			initial_quote=pending_quote,
		)
		if pending_line_number > 0:
			pending_text += (
				"" if pending_join_without_space else " "
			) + line.lstrip()
		else:
			pending_line_number = line_number
			pending_text = line
			pending_quote_start = (
				_unfinished_double_quote_start(pending_text)
				if line_quote == '"'
				else -1
			)
		if escaped_line_break and line_quote == '"':
			pending_escape_lines.append(line_number)
			pending_text = pending_text.rstrip()[:-1]
			pending_quote = line_quote
			pending_join_without_space = True
			continue
		if line_quote:
			pending_quote = line_quote
			pending_join_without_space = False
			continue
		if (
			pending_escape_lines
			and _quoted_scalar_is_mapping_key(
				pending_text,
				pending_quote_start,
			)
		):
			continuation_lines.extend(pending_escape_lines)
		normalized = _decode_yaml_unicode_escapes(pending_text)
		normalized_lines.append((pending_line_number, normalized))
		block_scalar = _block_scalar_header(normalized)
		if block_scalar is not None:
			block_scalar_base_indent, block_scalar_content_indent = block_scalar
		pending_line_number = 0
		pending_text = ""
		pending_quote = ""
		pending_join_without_space = False
		pending_quote_start = -1
		pending_escape_lines = []
	if pending_line_number > 0:
		normalized_lines.append((
			pending_line_number,
			_decode_yaml_unicode_escapes(pending_text),
		))
	return normalized_lines, continuation_lines


def _yaml_mapping_key_lines(
	lines: list[tuple[int, str]],
) -> tuple[list[tuple[int, str]], list[int]]:
	keys: list[tuple[int, str]] = []
	complex_key_lines: set[int] = set()
	for line_number, line in lines:
		if (
			not _yaml_flow_structure_is_balanced(line)
			or _yaml_flow_collection_is_mapping_key(line)
		):
			complex_key_lines.add(line_number)
		explicit_key, explicit_is_complex = _explicit_yaml_mapping_key(line)
		if explicit_key:
			keys.append((line_number, explicit_key))
		if explicit_is_complex:
			complex_key_lines.add(line_number)
		line_keys, line_has_complex_key = _yaml_mapping_keys_on_line(line)
		for key in line_keys:
			keys.append((line_number, key))
		if line_has_complex_key:
			complex_key_lines.add(line_number)
	return keys, sorted(complex_key_lines)


def _yaml_flow_structure_is_balanced(line: str) -> bool:
	flow_stack: list[str] = []
	quote = ""
	escaped = False
	verbatim_tag_end = -1
	for index, character in enumerate(line):
		if escaped:
			escaped = False
			continue
		if quote == '"' and character == "\\":
			escaped = True
			continue
		if quote:
			if character == quote:
				if quote == "'" and index + 1 < len(line) and line[index + 1] == "'":
					escaped = True
				else:
					quote = ""
			continue
		if index <= verbatim_tag_end:
			continue
		if line.startswith("!<", index):
			closing_index = line.find(">", index + 2)
			if closing_index >= 0:
				verbatim_tag_end = closing_index
				continue
		if (
			character in ("'", '"')
			and _yaml_quote_can_start(line, index)
		):
			quote = character
			continue
		if character in ("{", "["):
			flow_stack.append(character)
			continue
		if character not in ("}", "]"):
			continue
		if not flow_stack:
			return False
		expected_opening = "{" if character == "}" else "["
		if flow_stack.pop() != expected_opening:
			return False
	return not flow_stack


def _yaml_flow_collection_is_mapping_key(line: str) -> bool:
	flow_stack: list[str] = []
	quote = ""
	escaped = False
	verbatim_tag_end = -1
	for index, character in enumerate(line):
		if escaped:
			escaped = False
			continue
		if quote == '"' and character == "\\":
			escaped = True
			continue
		if quote:
			if character == quote:
				if quote == "'" and index + 1 < len(line) and line[index + 1] == "'":
					escaped = True
				else:
					quote = ""
			continue
		if index <= verbatim_tag_end:
			continue
		if line.startswith("!<", index):
			closing_index = line.find(">", index + 2)
			if closing_index >= 0:
				verbatim_tag_end = closing_index
				continue
		if (
			character in ("'", '"')
			and _yaml_quote_can_start(line, index)
		):
			quote = character
			continue
		if character in ("{", "["):
			flow_stack.append(character)
			continue
		if character not in ("}", "]") or not flow_stack:
			continue
		expected_opening = "{" if character == "}" else "["
		if flow_stack[-1] != expected_opening:
			continue
		flow_stack.pop()
		next_index = index + 1
		while next_index < len(line) and line[next_index].isspace():
			next_index += 1
		if next_index < len(line) and line[next_index] == ":":
			return True
	return False


def _explicit_yaml_mapping_key(line: str) -> tuple[str, bool]:
	match = re.fullmatch(
		r"\s*(?:-\s+)?\?\s+(?P<key>.+?)\s*",
		line,
	)
	if match is None:
		return "", False
	key = _normalize_yaml_mapping_key(match.group("key"))
	return key, not bool(key)


def _yaml_mapping_keys_on_line(line: str) -> tuple[list[str], bool]:
	keys: list[str] = []
	has_complex_key = False
	flow_stack: list[str] = []
	candidate_start: int | None = 0
	quote = ""
	escaped = False
	verbatim_tag_end = -1
	for index, character in enumerate(line):
		if escaped:
			escaped = False
			continue
		if quote == '"' and character == "\\":
			escaped = True
			continue
		if quote:
			if character == quote:
				if quote == "'" and index + 1 < len(line) and line[index + 1] == "'":
					escaped = True
				else:
					quote = ""
			continue
		if index <= verbatim_tag_end:
			continue
		if line.startswith("!<", index):
			closing_index = line.find(">", index + 2)
			if closing_index >= 0:
				verbatim_tag_end = closing_index
				continue
		if (
			character in ("'", '"')
			and _yaml_quote_can_start(line, index)
		):
			quote = character
			continue
		if character == "{":
			flow_stack.append(character)
			candidate_start = index + 1
			continue
		if character == "[":
			flow_stack.append(character)
			candidate_start = None
			continue
		if character in ("}", "]"):
			if flow_stack:
				flow_stack.pop()
			candidate_start = None
			continue
		if character == ",":
			candidate_start = (
				index + 1
				if flow_stack and flow_stack[-1] == "{"
				else None
			)
			continue
		if character != ":" or candidate_start is None:
			continue
		candidate = line[candidate_start:index]
		if not _yaml_colon_is_mapping_delimiter(line, index, candidate):
			continue
		key = _normalize_yaml_mapping_key(candidate)
		if key:
			keys.append(key)
		elif candidate.strip():
			has_complex_key = True
		candidate_start = None
	return keys, has_complex_key


def _normalize_yaml_mapping_key(candidate: str) -> str:
	key = candidate.strip()
	sequence_match = re.match(r"^-\s+(?P<key>.*)$", key)
	if sequence_match is not None:
		key = sequence_match.group("key").strip()
	explicit_match = re.match(r"^\?\s+(?P<key>.*)$", key)
	if explicit_match is not None:
		key = explicit_match.group("key").strip()
	if re.fullmatch(r"[A-Za-z0-9_-]+", key):
		return key
	if len(key) >= 2 and key[0] == key[-1] == '"':
		content = key[1:-1]
		if re.fullmatch(r"(?:\\.|[^\"\\])*", content) is None:
			return ""
		return _decode_yaml_unicode_escapes(content)
	if len(key) >= 2 and key[0] == key[-1] == "'":
		content = key[1:-1]
		if re.fullmatch(r"(?:''|[^'])*", content) is None:
			return ""
		return content.replace("''", "'")
	if key and key[0] not in "&*![]{}|>":
		return key
	return ""


def _yaml_colon_is_mapping_delimiter(
	line: str,
	index: int,
	candidate: str,
) -> bool:
	key = candidate.strip()
	if key.startswith(('"', "'")):
		return True
	if index + 1 >= len(line):
		return True
	return line[index + 1].isspace() or line[index + 1] in "{[,}]"


def _yaml_quote_can_start(line: str, index: int) -> bool:
	prefix = line[:index]
	property_suffix = rf"(?:{YAML_NODE_PROPERTY_PATTERN}\s+)*"
	return (
		re.search(
			rf"(?:^|[\[\]{{}},?])\s*{property_suffix}$",
			prefix,
		)
		is not None
		or re.search(
			rf":\s+{property_suffix}$",
			prefix,
		)
		is not None
		or re.search(
			r"""(?:"(?:\\.|[^"\\])*"|'(?:''|[^'])*'):\s*$""",
			prefix,
		)
		is not None
		or re.fullmatch(
			rf"\s*-\s+{property_suffix}",
			prefix,
		)
		is not None
	)


def _strip_yaml_comment_and_quote(
	line: str,
	*,
	initial_quote: str = "",
) -> tuple[str, str, bool]:
	quote = initial_quote
	index = 0
	while index < len(line):
		character = line[index]
		if quote == '"' and character == "\\":
			if index + 1 >= len(line):
				return line.rstrip(), quote, True
			index += 2
			continue
		if quote:
			if character == quote:
				if quote == "'" and index + 1 < len(line) and line[index + 1] == "'":
					index += 2
					continue
				quote = ""
			index += 1
			continue
		if (
			character in ("'", '"')
			and _yaml_quote_can_start(line, index)
		):
			quote = character
			index += 1
			continue
		if character == "#" and (
			index == 0 or line[index - 1].isspace()
		):
			return line[:index].rstrip(), "", False
		index += 1
	return line.rstrip(), quote, False


def _unfinished_double_quote_start(line: str) -> int:
	quote = ""
	escaped = False
	opening_index = -1
	for index, character in enumerate(line):
		if escaped:
			escaped = False
			continue
		if quote == '"' and character == "\\":
			escaped = True
			continue
		if quote:
			if character == quote:
				quote = ""
				opening_index = -1
			continue
		if (
			character in ("'", '"')
			and _yaml_quote_can_start(line, index)
		):
			quote = character
			if quote == '"':
				opening_index = index
	return opening_index if quote == '"' else -1


def _quoted_scalar_is_mapping_key(line: str, opening_index: int) -> bool:
	if opening_index < 0 or opening_index >= len(line):
		return False
	escaped = False
	closing_index = -1
	for index in range(opening_index + 1, len(line)):
		character = line[index]
		if escaped:
			escaped = False
			continue
		if character == "\\":
			escaped = True
			continue
		if character == '"':
			closing_index = index
			break
	if closing_index < 0:
		return False
	suffix = line[closing_index + 1:]
	if re.match(r"\s*:", suffix) is not None:
		return True
	if suffix.strip():
		return False
	return re.search(
		r"(?:^|[,{])\s*(?:-\s+)?\?\s*"
		rf"(?:{YAML_NODE_PROPERTY_PATTERN}\s+)*$",
		line[:opening_index],
	) is not None


def _block_scalar_header(line: str) -> tuple[int, int] | None:
	match = re.search(
		r"(?P<marker>[|>])"
		r"(?P<modifiers>(?:[1-9][+-]?|[+-][1-9]?|[+-]?))\s*$",
		line,
	)
	if match is None or _yaml_index_is_quoted(line, match.start("marker")):
		return None
	prefix = line[:match.start("marker")]
	property_suffix = re.search(
		rf"(?:{YAML_NODE_PROPERTY_PATTERN}\s+)+$",
		prefix,
	)
	structural_prefix = (
		prefix[:property_suffix.start()]
		if property_suffix is not None
		else prefix
	)
	if not (
		re.search(r":\s*$", structural_prefix) is not None
		or re.fullmatch(r"\s*-\s*", structural_prefix) is not None
	):
		return None
	base_indent = _yaml_line_indent(line)
	compact_mapping = re.match(
		r"^\s*-\s+(?P<key>.+):\s*$",
		structural_prefix,
	)
	if compact_mapping is not None:
		base_indent = compact_mapping.start("key")
	indicator = next(
		(
			int(character)
			for character in match.group("modifiers")
			if character.isdigit()
		),
		0,
	)
	return base_indent, base_indent + indicator if indicator else -1


def _yaml_index_is_quoted(line: str, target_index: int) -> bool:
	quote = ""
	escaped = False
	index = 0
	while index < target_index:
		character = line[index]
		if escaped:
			escaped = False
			index += 1
			continue
		if quote == '"' and character == "\\":
			escaped = True
			index += 1
			continue
		if quote:
			if character == quote:
				if quote == "'" and index + 1 < target_index and line[index + 1] == "'":
					index += 2
					continue
				quote = ""
			index += 1
			continue
		if (
			character in ("'", '"')
			and _yaml_quote_can_start(line, index)
		):
			quote = character
		index += 1
	return bool(quote)


def _yaml_line_indent(line: str) -> int:
	return len(line) - len(line.lstrip(" "))


def _decode_yaml_unicode_escapes(source: str) -> str:
	def decode(match: re.Match[str]) -> str:
		try:
			value = next(group for group in match.groups() if group is not None)
			return chr(int(value, 16))
		except (ValueError, OverflowError):
			return match.group(0)

	return re.sub(
		r"\\(?:x([0-9A-Fa-f]{2})|u([0-9A-Fa-f]{4})|U([0-9A-Fa-f]{8}))",
		decode,
		source,
	)


def _is_possible_codeql_config_path(path: str) -> bool:
	lower_path = path.lower()
	return (
		lower_path.endswith(".qls")
		or (
			lower_path.startswith(".github/")
			and lower_path.endswith((".yml", ".yaml"))
		)
	)


def _is_codeql_config(path: str, source: str) -> bool:
	lower_path = path.lower()
	if lower_path.endswith(".qls"):
		return True
	file_name = lower_path.rsplit("/", 1)[-1]
	return (
		"codeql" in file_name
		or lower_path.startswith(".github/codeql/")
		or _yaml_lexer_budget_exceeded(source)
		or _yaml_source_has_codeql_action_reference(source)
	)


def _yaml_lexer_budget_exceeded(source: str) -> bool:
	probe_count = (
		source.count('"')
		+ source.count("'")
		+ source.count("!<")
		+ 1
	)
	if probe_count > MAX_YAML_LEXER_WORK_UNITS:
		return True
	return len(source) > MAX_YAML_LEXER_WORK_UNITS // probe_count


def _yaml_source_has_codeql_action_reference(source: str) -> bool:
	comment_free_lines: list[str] = []
	pending_quote = ""
	for raw_line in source.splitlines():
		line, line_quote, _escaped_line_break = _strip_yaml_comment_and_quote(
			raw_line,
			initial_quote=pending_quote,
		)
		comment_free_lines.append(line)
		pending_quote = line_quote
	comment_free_source = _decode_yaml_unicode_escapes(
		"\n".join(comment_free_lines)
	).replace("\\/", "/")
	joined_source = re.sub(
		r"\\\n[ \t]*",
		"",
		comment_free_source,
	)
	return CODEQL_ACTION_REFERENCE in joined_source.casefold()


def _issue(
	kind: str,
	path: str,
	line: int,
	message: str,
) -> dict[str, object]:
	issue: dict[str, object] = {
		"kind": kind,
		"path": path,
		"message": message,
	}
	if line > 0:
		issue["line"] = line
	return issue


def _result(
	tracked_paths: list[str],
	python_file_count: int,
	config_file_count: int,
	suppression_count: int,
	issues: list[dict[str, object]],
) -> dict[str, object]:
	return {
		"schema_version": SCHEMA_VERSION,
		"ok": not issues,
		"tracked_file_count": len(set(tracked_paths)),
		"python_file_count": python_file_count,
		"codeql_config_file_count": config_file_count,
		"suppression_count": suppression_count,
		"issue_count": len(issues),
		"issues": issues,
	}
