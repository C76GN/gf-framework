"""Bounded, optional GDScript function structure observations from source text.

This is not a compiler, a quality gate, or a cyclomatic/cognitive complexity
implementation. ``complete`` means this observation algorithm completed; it
does not establish valid GDScript, type correctness, or runtime behavior.

The shared API parser supplies literal/comment masking and function-name
recognition. This module only groups masked statements and observes explicit
indentation blocks. A small closure audit supplements the shared masker's
deliberately permissive handling of unfinished strings. No files, Git state,
source expressions, or external processes are accessed by ``analyze_source``.

Named methods (including static and inner-class methods) receive rows. Lambda
bodies belong to the nearest enclosing named method, inclusively, and do not
receive duplicate rows. Lambdas outside named methods are counted separately;
property accessors and script initializers are not named-method rows. Function
ranges run from ``func`` through their last observed code line, excluding
trailing comments/blank lines and preceding annotations. Effective code lines
count body physical lines containing masked structural code, including literal
assignments and expression continuations, but excluding literal-only lines.

Branches are explicit if/elif/else headers plus match arms (including wildcard,
one per arm regardless of pattern alternatives or guards). Match itself adds
nesting, not a branch. Loops are for/while headers. Nesting counts control
blocks including match/arm, but not class/function/lambda/container indentation.
Conditional-expression ``if`` tokens are separate; boolean operators, early
returns, calls and exception-like semantics add no branches. No call graph,
expression parser, reachability analysis or semantic validation is attempted.

Malformed observed headers, delimiters, indentation and unsupported block
forms produce incomplete observations. Any issue conservatively marks every
row from that source incomplete. Input rejection yields unknown with no rows;
mid-scan limits retain explicitly incomplete, bounded observations. All limits
and the stable lexicographic ranking are reported; there is no scalar score.
Tabs expand to four columns; mixed tab/space prefixes are incomplete. Semicolon
statement sequences and multiline lambdas embedded in control headers are
explicit support limits, rather than silently flattened expressions.
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any

from gdscript_api_parser import parse_function_name, scan_gdscript_line


SCHEMA_VERSION = 1
ALGORITHM_VERSION = 1
MAX_SOURCE_BYTES = 2 * 1024 * 1024
MAX_LINES = 100_000
MAX_LINE_LENGTH = 65_536
MAX_FUNCTIONS = 4_096
MAX_NESTING = 128
MAX_BRACKET_DEPTH = 128
MAX_TOKENS = 300_000
MAX_ISSUES = 128
MAX_PATH_LENGTH = 4_096
MAX_IDENTIFIER_LENGTH = 256
MAX_QUALIFIED_NAME_LENGTH = 2_048
MAX_ID_LENGTH = 8_192
SORT_ORDER = [
	"max_nesting:descending", "branch_count:descending", "loop_count:descending",
	"effective_code_lines:descending", "path:ascending", "start_line:ascending", "id:ascending",
]
METRIC_DEFINITIONS = {
	"branch_count": "Explicit if/elif/else headers plus one per match arm, including wildcard; no boolean-operator or guard bonus.",
	"loop_count": "Explicit for/while headers; comprehensions and call semantics are not inferred.",
	"match_arm_count": "One per match arm, regardless of alternative patterns or guards.",
	"max_nesting": "Maximum enclosing control-block depth including match and arms; excludes function/class/lambda/container scopes.",
	"effective_code_lines": "Distinct body physical lines containing masked structural code; excludes signature, comments, blank and literal-only lines.",
	"lambda_count": "Lambda declarations within the named function, including nested lambda bodies; no separate lambda rows.",
	"conditional_expression_count": "Non-header if tokens, observed separately from statement branches.",
}
_TOKEN = re.compile(r"\w+|->|:=|[^\s]", re.UNICODE)
_OPEN = {"(": ")", "[": "]", "{": "}"}
_CLOSE = frozenset(_OPEN.values())
_CONTROL = frozenset({"if", "elif", "else", "for", "while", "match"})


@dataclass
class _LexState:
	# scan_gdscript_line only requires this state field; API ownership parsing is
	# intentionally not reused as a function-body parser.
	multiline_quote: str = ""


@dataclass(frozen=True)
class _Token:
	value: str
	line: int
	column: int


@dataclass
class _Statement:
	tokens: list[_Token]
	indent: int
	lines: set[int]
	end_line: int
	bracket_depth: int = 0


@dataclass
class _Scope:
	kind: str
	indent: int
	line: int
	name: str = ""
	row: dict[str, Any] | None = None
	body_indent: int | None = None


class _LimitReached(Exception):
	pass


def function_sort_key(row: dict[str, Any]) -> tuple[Any, ...]:
	"""Use the same transparent order within a source and across source reports."""
	metrics = row["metrics"]
	return (
		-metrics["max_nesting"], -metrics["branch_count"], -metrics["loop_count"],
		-metrics["effective_code_lines"], row["path"], row["start_line"], row["id"],
	)


def analyze_source(source: str, path: str) -> dict[str, Any]:
	"""Observe supplied text; ``path`` is an opaque display identity, not an IO path.

	Returned keys: schema_version, algorithm_version, path, status, source_bytes,
	functions, script_lambda_count, issues, omitted_issue_count, limits, sort_order.
	Issues contain code/line/message; source contents are never included in them.
	"""
	report: dict[str, Any] = {
		"schema_version": SCHEMA_VERSION, "algorithm_version": ALGORITHM_VERSION,
		"path": path if isinstance(path, str) and len(path) <= MAX_PATH_LENGTH else "", "status": "complete", "source_bytes": 0,
		"functions": [], "script_lambda_count": 0, "issues": [], "omitted_issue_count": 0,
		"limits": {
			"source_bytes": MAX_SOURCE_BYTES, "lines": MAX_LINES, "line_length": MAX_LINE_LENGTH,
			"functions": MAX_FUNCTIONS, "scopes": MAX_NESTING, "bracket_depth": MAX_BRACKET_DEPTH,
			"tokens": MAX_TOKENS, "issues": MAX_ISSUES,
			"identifier_length": MAX_IDENTIFIER_LENGTH, "qualified_name_length": MAX_QUALIFIED_NAME_LENGTH,
			"id_length": MAX_ID_LENGTH, "path_length": MAX_PATH_LENGTH,
		},
		"sort_order": list(SORT_ORDER),
		"metric_definitions": dict(METRIC_DEFINITIONS),
	}
	if not isinstance(source, str) or not isinstance(path, str) or len(path) > MAX_PATH_LENGTH:
		return _reject(report, "invalid_input", "Expected bounded source and path strings.")
	if len(source) > MAX_SOURCE_BYTES:
		return _reject(report, "source_limit", "Source exceeds the byte budget.")
	try:
		report["source_bytes"] = len(source.encode("utf-8", errors="strict"))
	except UnicodeError:
		return _reject(report, "invalid_unicode", "Source is not encodable as strict UTF-8.")
	if report["source_bytes"] > MAX_SOURCE_BYTES:
		return _reject(report, "source_limit", "Source exceeds the byte budget.")
	if any((ord(char) < 32 and char not in "\t\r\n") or char in "\x85\u2028\u2029" for char in source):
		return _reject(report, "unsupported_control_character", "Source contains unsupported control characters.")
	if source.startswith("\ufeff"):
		source = source[1:]
	lines = source.splitlines()
	if len(lines) > MAX_LINES:
		return _reject(report, "line_limit", "Source exceeds the physical line budget.")
	if any(len(line) > MAX_LINE_LENGTH for line in lines):
		return _reject(report, "line_length_limit", "Source exceeds the per-line character budget.")
	observer = _Observer(report, lines)
	observer.run()
	if report["issues"]:
		report["status"] = "incomplete"
		for row in report["functions"]:
			row["status"] = "incomplete"
	report["functions"].sort(key=function_sort_key)
	return report


def _reject(report: dict[str, Any], code: str, message: str) -> dict[str, Any]:
	report["status"] = "unknown"
	report["issues"] = [{"code": code, "line": 0, "message": message}]
	return report


def _ordinary_quotes_closed(text: str, initial_multiline_quote: str) -> bool:
	"""Audit quote closure only; shared scan_gdscript_line owns structural masking."""
	quote = initial_multiline_quote
	i = 0
	while i < len(text):
		if quote:
			if text.startswith(quote, i):
				i += len(quote)
				quote = ""
			elif text[i] == "\\":
				i += 2
			else:
				i += 1
			continue
		if text[i] == "#":
			return True
		if text.startswith('"""', i) or text.startswith("'''", i):
			quote = text[i:i + 3]
			i += 3
		elif text[i] in "\"'":
			ordinary = text[i]
			i += 1
			while i < len(text):
				if text[i] == "\\":
					i += 2
				elif text[i] == ordinary:
					i += 1
					break
				else:
					i += 1
			else:
				return False
		else:
			i += 1
	return True


def _colon_index(tokens: list[_Token]) -> int | None:
	depth = 0
	for index, token in enumerate(tokens):
		if token.value in _OPEN:
			depth += 1
		elif token.value in _CLOSE:
			depth -= 1
		elif token.value == ":" and depth == 0:
			return index
	return None


def _without_annotations(tokens: list[_Token]) -> list[_Token]:
	index = 0
	while index < len(tokens) and tokens[index].value == "@":
		index += 2
		if index < len(tokens) and tokens[index].value == "(":
			depth = 1
			index += 1
			while index < len(tokens) and depth:
				depth += (tokens[index].value == "(") - (tokens[index].value == ")")
				index += 1
	return tokens[index:]


class _Observer:
	def __init__(self, report: dict[str, Any], lines: list[str]) -> None:
		self.report = report
		self.lines = lines
		self.scopes: list[_Scope] = []
		self.root_name = ""
		self.seen_names: set[str] = set()
		self.function_lines: dict[str, set[int]] = {}

	def issue(self, code: str, line: int, message: str) -> None:
		if len(self.report["issues"]) < MAX_ISSUES:
			self.report["issues"].append({"code": code, "line": line, "message": message})
		else:
			self.report["omitted_issue_count"] += 1

	def limit(self, code: str, line: int, message: str) -> None:
		self.issue(code, line, message)
		raise _LimitReached

	def run(self) -> None:
		state = _LexState()
		brackets: list[_Token] = []
		pending: list[_Token] = []
		pending_lines: set[int] = set()
		base_depth = 0
		callable_base_depth: int | None = None
		token_count = 0
		try:
			for number, raw in enumerate(self.lines, 1):
				if not _ordinary_quotes_closed(raw, state.multiline_quote):
					self.issue("unterminated_string", number, "Ordinary string is not closed on its physical line.")
				masked, _comment, _started_multiline = scan_gdscript_line(raw, state)
				tokens = [_Token(match.group(), number, match.start()) for match in _TOKEN.finditer(masked)]
				if not tokens:
					if pending and not state.multiline_quote and len(brackets) <= base_depth:
						self.observe(_Statement(pending, self.indent(pending[0].line), pending_lines, number, base_depth))
						pending = []
						pending_lines = set()
						callable_base_depth = None
					continue
				token_count += len(tokens)
				if token_count > MAX_TOKENS:
					self.limit("token_limit", number, "Source exceeds the structural token budget.")
				if not pending:
					base_depth = len(brackets)
				pending_lines.add(number)
				lambda_header = False
				for token in tokens:
					if token.value == "func":
						callable_base_depth = len(brackets)
					elif token.value == ":" and callable_base_depth == len(brackets):
						lambda_header = True
					if token.value in _OPEN:
						if len(brackets) >= MAX_BRACKET_DEPTH:
							self.limit("bracket_depth_limit", number, "Delimiter nesting exceeds the budget.")
						brackets.append(token)
					elif token.value in _CLOSE:
						if not brackets or _OPEN[brackets[-1].value] != token.value:
							self.issue("unmatched_delimiter", number, "Closing delimiter does not match its opener.")
						else:
							brackets.pop()
				continued = tokens[-1].value == "\\"
				# The consumed continuation marker joins physical lines; it is not
				# part of the declaration/expression passed to structural observers.
				pending.extend(tokens[:-1] if continued else tokens)
				if (len(brackets) <= base_depth or lambda_header) and not continued and not state.multiline_quote:
					self.observe(_Statement(pending, self.indent(pending[0].line), pending_lines, number, base_depth))
					pending = []
					pending_lines = set()
					callable_base_depth = None
			if pending:
				self.issue("incomplete_statement", pending[0].line, "Continued statement is unfinished.")
				self.observe(_Statement(pending, self.indent(pending[0].line), pending_lines, pending[-1].line, base_depth))
			if state.multiline_quote:
				self.issue("unterminated_multiline_string", len(self.lines), "Multiline string is not closed.")
			if brackets:
				self.issue("unclosed_delimiter", brackets[0].line, "Opening delimiter remains unclosed.")
		except _LimitReached:
			pass
		while self.scopes:
			self.close_scope()
		for row in self.report["functions"]:
			row["metrics"]["effective_code_lines"] = len(self.function_lines[row["id"]])

	def indent(self, line: int) -> int:
		raw = self.lines[line - 1]
		prefix = raw[:len(raw) - len(raw.lstrip(" \t"))]
		if " " in prefix and "\t" in prefix:
			self.issue("mixed_indentation", line, "Indent prefix mixes spaces and tabs.")
		return len(prefix.expandtabs(4))

	def close_scope(self) -> None:
		scope = self.scopes.pop()
		if scope.body_indent is None:
			self.issue("missing_body", scope.line, "Block has no observed body.")

	def push(self, scope: _Scope) -> None:
		if len(self.scopes) >= MAX_NESTING:
			self.limit("nesting_limit", scope.line, "Syntactic scope nesting exceeds the budget.")
		self.scopes.append(scope)

	def current_function(self) -> dict[str, Any] | None:
		return next((scope.row for scope in reversed(self.scopes) if scope.row is not None), None)

	def observe(self, statement: _Statement) -> None:
		tokens = _without_annotations(statement.tokens)
		if not tokens:
			return
		while self.scopes and statement.indent <= self.scopes[-1].indent:
			self.close_scope()
		# After a lambda body, the enclosing call/container still owns following
		# arguments. Their indentation is expression layout, not a new block.
		in_expression = statement.bracket_depth > 0 and not any(scope.kind == "lambda" for scope in self.scopes)
		if self.scopes:
			scope = self.scopes[-1]
			if scope.body_indent is None:
				scope.body_indent = statement.indent
			elif statement.indent != scope.body_indent and not in_expression:
				self.issue("unexpected_indentation", tokens[0].line, "Indentation has no corresponding observed block.")
		elif statement.indent and not in_expression:
			self.issue("unexpected_indentation", tokens[0].line, "Top-level statement is indented.")
		values = [token.value for token in tokens]
		first = values[0]
		if ";" in values:
			self.issue("unsupported_statement_separator", tokens[0].line, "Multiple statements separated by semicolons are outside this observation grammar.")
		owner = self.current_function()
		if first == "class_name" and len(tokens) > 1 and not self.scopes:
			self.check_identifier(tokens[1])
			self.root_name = tokens[1].value
			return
		if first == "class":
			if owner is not None or len(tokens) < 3 or _colon_index(tokens) != len(tokens) - 1:
				self.issue("unsupported_class", tokens[0].line, "Class declaration is not a supported standalone block.")
				return
			self.check_identifier(tokens[1])
			self.push(_Scope("class", statement.indent, tokens[0].line, name=tokens[1].value))
			return
		function_offset = 1 if first == "static" else 0
		is_declaration = (
			function_offset + 2 < len(values) and values[function_offset] == "func"
			and values[function_offset + 1].isidentifier() and values[function_offset + 2] == "("
			and not in_expression
		)
		if is_declaration and owner is None and all(scope.kind == "class" for scope in self.scopes):
			self.function(tokens[function_offset:], statement)
			return
		if is_declaration:
			self.issue("nested_function_declaration", tokens[0].line, "Standalone nested named declaration is unsupported; observations remain with its enclosing function.")
		if owner is not None:
			self.record_lines(owner, statement.lines, statement.end_line)
		self.body(tokens, statement.indent, owner)

	def check_identifier(self, token: _Token) -> None:
		if len(token.value) > MAX_IDENTIFIER_LENGTH:
			self.limit("identifier_limit", token.line, "Declaration identifier exceeds the length budget.")

	def function(self, tokens: list[_Token], statement: _Statement) -> None:
		name = parse_function_name(" ".join(token.value for token in tokens))
		# The API declaration recognizer restricts the first character to ASCII.
		# Observation also accepts an unambiguous Unicode identifier token, without
		# changing the API parser's declaration/visibility rules.
		if not name and len(tokens) >= 3 and tokens[1].value.isidentifier() and tokens[2].value == "(":
			name = tokens[1].value
		if not name:
			self.issue("unsupported_function", tokens[0].line, "Named function declaration could not be recognized.")
			return
		self.check_identifier(tokens[1])
		if len(self.report["functions"]) >= MAX_FUNCTIONS:
			self.limit("function_limit", tokens[0].line, "Named function count exceeds the budget.")
		owners = ([self.root_name] if self.root_name else []) + [scope.name for scope in self.scopes if scope.kind == "class"]
		qualified = ".".join([*owners, name])
		identity = f'{self.report["path"]}::{qualified}@{tokens[0].line}'
		if len(qualified) > MAX_QUALIFIED_NAME_LENGTH or len(identity) > MAX_ID_LENGTH:
			self.limit("identity_limit", tokens[0].line, "Qualified function identity exceeds the length budget.")
		if qualified in self.seen_names:
			self.issue("duplicate_function", tokens[0].line, "Function qualified name is declared more than once.")
		self.seen_names.add(qualified)
		row: dict[str, Any] = {
			"id": identity,
			"path": self.report["path"], "name": name, "qualified_name": qualified,
			"start_line": tokens[0].line, "end_line": statement.end_line, "status": "complete",
			"metrics": {
				"branch_count": 0, "loop_count": 0, "match_arm_count": 0, "max_nesting": 0,
				"effective_code_lines": 0, "lambda_count": 0, "conditional_expression_count": 0,
			},
		}
		self.report["functions"].append(row)
		self.function_lines[row["id"]] = set()
		colon = _colon_index(tokens)
		if colon is None:
			self.issue("incomplete_function_header", tokens[0].line, "Function header has no completed body colon.")
			self.push(_Scope("function", statement.indent, tokens[0].line, row=row))
		elif colon == len(tokens) - 1:
			self.push(_Scope("function", statement.indent, tokens[0].line, row=row))
		else:
			body = tokens[colon + 1:]
			self.record_lines(row, {token.line for token in body}, statement.end_line)
			self.body(body, statement.indent, row, inline=True)

	def record_lines(self, row: dict[str, Any], lines: set[int], end_line: int) -> None:
		self.function_lines[row["id"]].update(lines)
		row["end_line"] = max(row["end_line"], end_line)

	def body(self, tokens: list[_Token], indent: int, owner: dict[str, Any] | None, *, inline: bool = False) -> None:
		values = [token.value for token in tokens]
		first = values[0]
		colon = _colon_index(tokens)
		if first == "for" and "in" in values:
			iterator_end = values.index("in") + 1
			body_colon = _colon_index(tokens[iterator_end:])
			colon = None if body_colon is None else iterator_end + body_colon
		is_arm = bool(self.scopes and self.scopes[-1].kind == "match")
		control = first in _CONTROL or is_arm
		lambda_indices = [index for index, token in enumerate(tokens) if token.value == "func"]
		if owner is not None:
			owner["metrics"]["lambda_count"] += len(lambda_indices)
		else:
			self.report["script_lambda_count"] += len(lambda_indices)
		if owner is not None:
			metrics = owner["metrics"]
			metrics["conditional_expression_count"] += values.count("if") - int(first == "if" and not is_arm)
			if control:
				if first in {"if", "elif", "else"} or is_arm:
					metrics["branch_count"] += 1
				if is_arm:
					metrics["match_arm_count"] += 1
				elif first in {"for", "while"}:
					metrics["loop_count"] += 1
				depth = 1 + sum(scope.kind in _CONTROL or scope.kind == "arm" for scope in self.scopes)
				metrics["max_nesting"] = max(metrics["max_nesting"], depth)
		if control:
			if colon is None:
				if "func" in values:
					self.issue("unsupported_lambda_in_control_header", tokens[0].line, "Multiline lambda embedded in a control header is outside this observation grammar.")
				else:
					self.issue("incomplete_control_header", tokens[0].line, "Control header has no completed body colon.")
			elif inline:
				self.issue("unsupported_inline_control", tokens[0].line, "Nested compound statement inside an inline body is unsupported.")
			elif colon == len(tokens) - 1:
				self.push(_Scope("arm" if is_arm else first, indent, tokens[0].line))
			elif tokens[colon + 1].value in _CONTROL:
				self.issue("unsupported_inline_control", tokens[0].line, "Nested compound statement inside an inline body is unsupported.")
			return
		if lambda_indices:
			last = lambda_indices[-1]
			lambda_colon = _colon_index(tokens[last:])
			if lambda_colon is None:
				self.issue("incomplete_lambda", tokens[last].line, "Lambda header has no completed body colon.")
			elif last + lambda_colon == len(tokens) - 1:
				self.push(_Scope("lambda", self.indent(tokens[last].line), tokens[last].line))
			return
		if tokens[-1].value == ":":
			if owner is None and first in {"var", "get", "set"}:
				self.push(_Scope("accessor", indent, tokens[0].line))
			else:
				self.issue("unsupported_block", tokens[0].line, "Block form is outside the supported observation grammar.")
				self.push(_Scope("unknown", indent, tokens[0].line))
