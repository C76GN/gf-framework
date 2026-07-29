#!/usr/bin/env python3
"""Reject CodeQL suppressions and configuration escape hatches in tracked sources."""

from __future__ import annotations

import io
import re
import tokenize
import unicodedata
from pathlib import Path
from typing import Callable


SCHEMA_VERSION = 1
CODEQL_MARKER_RE = re.compile(r"#\s*codeql\b", re.IGNORECASE)
LGTM_MARKER_RE = re.compile(r"#\s*lgtm\b", re.IGNORECASE)
TRACKED_PATH_CONTROL_CATEGORIES = frozenset(("Cc", "Cf"))


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

	inventory_issues, canonical_paths = _audit_tracked_path_inventory(tracked_paths)
	if inventory_issues:
		return _result(tracked_paths, 0, 0, 0, inventory_issues)

	python_file_count = 0
	config_file_count = 0
	suppression_count = 0
	for normalized_path in canonical_paths:
		path = root / Path(normalized_path)
		if normalized_path.lower().endswith(".py"):
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
