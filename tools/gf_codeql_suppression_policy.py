#!/usr/bin/env python3
"""Audit narrowly approved CodeQL suppressions in Git-tracked GF sources."""

from __future__ import annotations

import ast
import io
import re
import tokenize
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


SCHEMA_VERSION = 1
CODEQL_QUERY_ID_RE = re.compile(
	r"^[a-z][a-z0-9-]*/[a-z][a-z0-9-]*(?:[a-z0-9.-]*[a-z0-9])?$"
)
CODEQL_DIRECTIVE_RE = re.compile(r"^#\s*codeql\[(?P<query_id>[^\]]*)\]\s*$")
CODEQL_PREFIX_RE = re.compile(r"^#\s*codeql\b", re.IGNORECASE)
LGTM_PREFIX_RE = re.compile(r"^#\s*lgtm\b", re.IGNORECASE)
REASON_RE = re.compile(
	r"^#\s*gf-codeql-reason:\s*test-only:(?P<reason>[a-z0-9][a-z0-9-]{2,63})\s*$"
)
REASON_PREFIX_RE = re.compile(r"^#\s*gf-codeql-reason\b", re.IGNORECASE)
TARGET_QUERY_ID = "py/clear-text-storage-sensitive-data"
MAX_SUPPRESSIONS = 32


@dataclass(frozen=True)
class SuppressionAllowance:
	path: str
	query_id: str
	reason: str
	container: str
	sink_pattern: str


ALLOWED_SUPPRESSIONS: tuple[SuppressionAllowance, ...] = (
	SuppressionAllowance(
		path="tests/gf_core/tools/test_gf_credential_gate.py",
		query_id=TARGET_QUERY_ID,
		reason="linked-tracked-source-fixture",
		container="test_tracked_scan_rejects_real_linked_directory_without_disclosure",
		sink_pattern=(
			r'\s*\(outside_root / "settings\.txt"\)\.write_text'
			r'\(secret \+ "\\n", encoding="utf-8"\)\s*'
		),
	),
	SuppressionAllowance(
		path="tests/gf_core/tools/test_gf_credential_gate.py",
		query_id=TARGET_QUERY_ID,
		reason="linked-release-artifact-fixture",
		container="test_release_scan_rejects_real_linked_directory_without_disclosure",
		sink_pattern=(
			r'\s*\(outside_root / "release\.txt"\)\.write_text'
			r'\(secret \+ "\\n", encoding="utf-8"\)\s*'
		),
	),
	SuppressionAllowance(
		path="tests/gf_core/tools/test_gf_credential_gate.py",
		query_id=TARGET_QUERY_ID,
		reason="credential-shaped-manifest-fixture",
		container="_write_secret_shaped_path_manifest_fixture",
		sink_pattern=(
			r'\s*manifest_path\.write_text'
			r'\(json\.dumps\(data\), encoding="utf-8"\)\s*'
		),
	),
)


def audit_tracked_sources(
	root: Path,
	tracked_paths: list[str],
	read_text: Callable[[Path], str],
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

	python_file_count = 0
	config_file_count = 0
	suppression_count = 0
	for relative_path in sorted(set(tracked_paths)):
		if (
			"\\" in relative_path
			or relative_path.startswith("/")
			or re.match(r"^[A-Za-z]:", relative_path) is not None
			or any(part in ("", ".", "..") for part in relative_path.split("/"))
			or any(
				ord(character) < 0x20 or ord(character) == 0x7F
				for character in relative_path
			)
		):
			issues.append(_issue(
				"codeql_suppression.tracked_path_noncanonical",
				"git-index",
				0,
				"Git tracked-file inventory contains a non-canonical path.",
			))
			continue
		normalized_path = relative_path
		path = root / Path(normalized_path)
		if normalized_path.endswith(".py"):
			python_file_count += 1
			if path.is_symlink() or not path.exists() or not path.is_file():
				issues.append(_issue(
					"codeql_suppression.python_source_not_regular",
					normalized_path,
					0,
					"Tracked Python source must be a regular non-linked file.",
				))
				continue
			try:
				source = read_text(path)
			except (OSError, UnicodeError):
				issues.append(_issue(
					"codeql_suppression.python_source_unreadable",
					normalized_path,
					0,
					"Tracked Python source could not be read as UTF-8.",
				))
				continue
			source_issues, source_suppressions = audit_python_source(normalized_path, source)
			issues.extend(source_issues)
			suppression_count += source_suppressions
			if suppression_count > MAX_SUPPRESSIONS:
				issues.append(_issue(
					"codeql_suppression.count_exceeded",
					normalized_path,
					0,
					f"Tracked Python sources exceed the {MAX_SUPPRESSIONS}-suppression policy budget.",
				))
				break
			continue
		if not _is_possible_codeql_config_path(normalized_path):
			continue
		if path.is_symlink() or not path.exists() or not path.is_file():
			issues.append(_issue(
				"codeql_suppression.config_not_regular",
				normalized_path,
				0,
				"Tracked CodeQL configuration must be a regular non-linked file.",
			))
			continue
		try:
			source = read_text(path)
		except (OSError, UnicodeError):
			issues.append(_issue(
				"codeql_suppression.config_unreadable",
				normalized_path,
				0,
				"Tracked CodeQL configuration could not be read as UTF-8.",
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


def audit_python_source(path: str, source: str) -> tuple[list[dict[str, object]], int]:
	"""Audit Python comment tokens so directive-looking text inside strings is ignored."""
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
	try:
		syntax_tree = ast.parse(source)
	except SyntaxError:
		return [
			_issue(
				"codeql_suppression.python_parse_failed",
				path,
				0,
				"Tracked Python source could not be parsed.",
			)
		], 0

	lines = source.splitlines()
	comments_by_line: dict[int, list[tokenize.TokenInfo]] = {}
	for token in tokens:
		if token.type == tokenize.COMMENT:
			comments_by_line.setdefault(token.start[0], []).append(token)

	directive_lines: set[int] = set()
	reason_lines: set[int] = set()
	used_allowances: set[tuple[str, str, str]] = set()
	suppression_count = 0
	for line_number in sorted(comments_by_line):
		for token in comments_by_line[line_number]:
			comment = token.string.strip()
			if LGTM_PREFIX_RE.match(comment):
				issues.append(_issue(
					"codeql_suppression.legacy_lgtm_directive",
					path,
					line_number,
					"Legacy lgtm suppression directives are forbidden.",
				))
				continue
			if not CODEQL_PREFIX_RE.match(comment):
				if REASON_PREFIX_RE.match(comment):
					reason_lines.add(line_number)
					if REASON_RE.fullmatch(comment) is None:
						issues.append(_issue(
							"codeql_suppression.reason_malformed",
							path,
							line_number,
							"CodeQL suppression reasons must use the structured test-only reason format.",
						))
				continue

			directive_lines.add(line_number)
			suppression_count += 1
			if not _is_standalone_comment(token, lines):
				issues.append(_issue(
					"codeql_suppression.directive_not_standalone",
					path,
					line_number,
					"CodeQL suppression directives must be standalone comments.",
				))
				continue
			match = CODEQL_DIRECTIVE_RE.fullmatch(comment)
			if match is None:
				issues.append(_issue(
					"codeql_suppression.directive_malformed",
					path,
					line_number,
					"CodeQL suppressions must name one exact query id.",
				))
				continue
			query_id = match.group("query_id")
			if "*" in query_id:
				issues.append(_issue(
					"codeql_suppression.query_wildcard_forbidden",
					path,
					line_number,
					"Wildcard CodeQL query suppression is forbidden.",
				))
				continue
			if CODEQL_QUERY_ID_RE.fullmatch(query_id) is None:
				issues.append(_issue(
					"codeql_suppression.query_id_not_exact",
					path,
					line_number,
					"CodeQL suppressions must name one syntactically exact query id.",
				))
				continue

			reason_tokens = comments_by_line.get(line_number - 1, [])
			reason_token = reason_tokens[0] if len(reason_tokens) == 1 else None
			reason_match = (
				REASON_RE.fullmatch(reason_token.string.strip())
				if reason_token is not None
				and _is_standalone_comment(reason_token, lines)
				and reason_token.start[1] == token.start[1]
				else None
			)
			if reason_match is None:
				issues.append(_issue(
					"codeql_suppression.reason_required",
					path,
					line_number,
					"An adjacent, equally indented structured test-only reason is required.",
				))
				continue
			reason_lines.add(line_number - 1)
			reason = reason_match.group("reason")
			allowance = _find_allowance(path, query_id, reason)
			if allowance is None:
				issues.append(_issue(
					"codeql_suppression.allowance_missing",
					path,
					line_number,
					"Suppression path, query id, and reason are not in the narrow allow policy.",
				))
				continue
			allowance_key = (allowance.path, allowance.query_id, allowance.reason)
			if allowance_key in used_allowances:
				issues.append(_issue(
					"codeql_suppression.allowance_reused",
					path,
					line_number,
					"One suppression allowance may be used at only one sink.",
				))
				continue
			sink_line_number = line_number + 1
			sink_container = _enclosing_function_name(syntax_tree, sink_line_number)
			if sink_container != allowance.container:
				issues.append(_issue(
					"codeql_suppression.container_mismatch",
					path,
					line_number,
					"Suppression is outside its allowlisted test or fixture helper.",
				))
				continue
			if (
				sink_line_number > len(lines)
				or not lines[sink_line_number - 1].strip()
				or lines[sink_line_number - 1].lstrip().startswith("#")
				or _leading_whitespace_count(lines[sink_line_number - 1]) != token.start[1]
				or re.fullmatch(allowance.sink_pattern, lines[sink_line_number - 1]) is None
			):
				issues.append(_issue(
					"codeql_suppression.sink_not_adjacent",
					path,
					line_number,
					"Suppression must immediately precede its allowlisted sink at the same indentation.",
				))
				continue
			used_allowances.add(allowance_key)

	for reason_line in sorted(reason_lines):
		if reason_line + 1 not in directive_lines:
			issues.append(_issue(
				"codeql_suppression.reason_orphaned",
				path,
				reason_line,
				"Structured CodeQL suppression reason is not followed by a suppression directive.",
			))

	return issues, suppression_count


def audit_codeql_config(path: str, source: str) -> list[dict[str, object]]:
	"""Conservatively reject broad CodeQL escape hatches without partially parsing YAML."""
	if path.lower().endswith(".qls"):
		return [_issue(
			"codeql_suppression.custom_queries_forbidden",
			path,
			1,
			"Tracked custom CodeQL query suites are forbidden.",
		)]
	issues: list[dict[str, object]] = []
	effective_lines, continuation_lines = _normalize_yaml_policy_lines(source)
	for line_number in continuation_lines:
		issues.append(_issue(
			"codeql_suppression.yaml_line_continuation_forbidden",
			path,
			line_number,
			"CodeQL policy YAML must not use escaped line continuations.",
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
		line_number = _first_policy_token_line(effective_lines, token)
		if line_number > 0:
			issues.append(_issue(kind, path, line_number, message))
	return issues


def _normalize_yaml_policy_lines(
	source: str,
) -> tuple[list[tuple[int, str]], list[int]]:
	normalized_lines: list[tuple[int, str]] = []
	continuation_lines: list[int] = []
	pending_line_number = 0
	pending_text = ""
	for line_number, raw_line in enumerate(source.splitlines(), start=1):
		line = _decode_yaml_unicode_escapes(_strip_yaml_comment(raw_line))
		if pending_line_number > 0:
			pending_text += line.lstrip()
		else:
			pending_line_number = line_number
			pending_text = line
		if pending_text.rstrip().endswith("\\"):
			continuation_lines.append(line_number)
			pending_text = pending_text.rstrip()[:-1]
			continue
		normalized_lines.append((pending_line_number, pending_text))
		pending_line_number = 0
		pending_text = ""
	if pending_line_number > 0:
		normalized_lines.append((pending_line_number, pending_text))
	return normalized_lines, continuation_lines


def _first_policy_token_line(
	lines: list[tuple[int, str]],
	token: str,
) -> int:
	token_pattern = re.compile(
		rf"(?<![A-Za-z0-9_-]){re.escape(token)}(?![A-Za-z0-9_-])",
		re.IGNORECASE,
	)
	for line_number, line in lines:
		if token_pattern.search(line) is not None:
			return line_number
	return 0


def _strip_yaml_comment(line: str) -> str:
	quote = ""
	escaped = False
	for index, character in enumerate(line):
		if escaped:
			escaped = False
			continue
		if quote == '"' and character == "\\":
			escaped = True
			continue
		if character in ("'", '"'):
			if not quote:
				quote = character
			elif quote == character:
				quote = ""
			continue
		if character == "#" and not quote:
			return line[:index].rstrip()
	return line.rstrip()


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
	effective_lines, _continuation_lines = _normalize_yaml_policy_lines(source)
	effective_source = "\n".join(
		line
		for _line_number, line in effective_lines
	).lower()
	return (
		"codeql" in file_name
		or lower_path.startswith(".github/codeql/")
		or "codeql" in effective_source
	)


def _find_allowance(
	path: str,
	query_id: str,
	reason: str,
) -> SuppressionAllowance | None:
	for allowance in ALLOWED_SUPPRESSIONS:
		if (
			allowance.path == path
			and allowance.query_id == query_id
			and allowance.reason == reason
		):
			return allowance
	return None


def _enclosing_function_name(syntax_tree: ast.AST, line_number: int) -> str:
	candidates = [
		node
		for node in ast.walk(syntax_tree)
		if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef))
		and node.lineno <= line_number <= (node.end_lineno or node.lineno)
	]
	if not candidates:
		return ""
	candidates.sort(key=lambda node: (
		(node.end_lineno or node.lineno) - node.lineno,
		-node.lineno,
	))
	return candidates[0].name


def _is_standalone_comment(token: tokenize.TokenInfo, lines: list[str]) -> bool:
	line_number = token.start[0]
	if line_number <= 0 or line_number > len(lines):
		return False
	return not lines[line_number - 1][:token.start[1]].strip()


def _leading_whitespace_count(line: str) -> int:
	return len(line) - len(line.lstrip(" \t"))


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
