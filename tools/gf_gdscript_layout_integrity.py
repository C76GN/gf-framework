"""Structural whitespace integrity for the shared GDScript lexical view."""

from __future__ import annotations

from dataclasses import dataclass
from bisect import bisect_left


RULES = ("token_spacing", "suite_indentation", "member_block_spacing", "member_doc_binding", "match_pattern_layout")
_BINARY = frozenset(("=", ":=", "+=", "-=", "*=", "/=", "%=", "**=", "<<=", ">>=", "&=", "|=", "^=", "+", "-", "*", "/", "%", "**", "<<", ">>", "&", "|", "^", "==", "!=", "<", ">", "<=", ">=", "&&", "||", "->"))
_WORDS = frozenset(("and", "or", "as", "is", "in"))
_PREFIX = frozenset(("return", "await", "not", "if", "elif", "while", "match", "when", "else", "for", "and", "or", "in", "is", "as"))
_HEADERS = frozenset(("if", "elif", "else", "for", "while", "match", "class", "get", "set"))
_DATA = frozenset(("var", "const", "signal"))
_DECLARATIONS = _DATA | frozenset(("func", "class", "enum"))


@dataclass(frozen=True)
class LayoutEdit:
	start: int
	end: int
	replacement: str
	rule: str
	line: int = 0
	message: str = ""


class _Collector:
	def __init__(self, view):
		from gf_gdscript_readability import _boolean_scope_view
		self.view = view
		self.scope = _boolean_scope_view(view)
		if self.scope is None:
			raise ValueError("Shared statement-role closure budget exhausted.")
		self.edits = {}
		self.starts = [0]
		self.starts.extend(i + 1 for i, char in enumerate(view.source) if char == "\n")
		self.indents = {line: len(raw) - len(raw.lstrip("\t")) for line, raw in enumerate(view.lines, 1)}

	def put(self, start, end, replacement, rule, line, message):
		if self.view.source[start:end] != replacement:
			self.edits[start, end] = LayoutEdit(start, end, replacement, rule, line, message)
		else:
			# A more-specific delimiter contract can restore the original gap;
			# that must cancel an earlier generic comma/spacing proposal.
			self.edits.pop((start, end), None)

	def gap(self, left, right, replacement, rule="token_spacing"):
		if left.end_line == right.line and not self.view.source[left.end:right.start].strip():
			self.put(left.end, right.start, replacement, rule, left.line, "Use structural token spacing.")

	def prefix(self, line, expected):
		raw = self.view.lines[line - 1]
		length = len(raw) - len(raw.lstrip("\t "))
		self.put(self.starts[line - 1], self.starts[line - 1] + length, "\t" * expected, "suite_indentation", line, "Indent a direct suite statement by exactly one Tab.")

	def blank(self, before, after, expected, rule):
		if after <= before:
			return
		start, end = self.starts[before], self.starts[after - 1]
		if not self.view.source[start:end].strip():
			self.put(start, end, "\n" * expected, rule, after, "Keep the complete declaration and documentation blocks at their required spacing.")


def _operand(tokens, index, node=()):
	if index < 0:
		return False
	value = tokens[index]
	member = index > 0 and tokens[index - 1].value == "."
	return value.value in {")", "]", "}"} or value.kind in {"number", "string"} or (value.kind == "identifier" and (member or index in node or value.value not in _PREFIX | {"var", "const", "func", "signal", "class", "extends", "set", "get"}))


def _spacing(c):
	tokens = c.view.tokens
	statement_starts = c.scope[3]
	by_open = {g.open_index: g for g in c.scope[0].groups}
	by_close = {g.close_index: g for g in c.scope[0].groups}
	node = set()
	for i, token in enumerate(tokens):
		previous = i - 1
		while previous >= 0 and tokens[previous].value == "\\":
			previous -= 1
		if token.value not in {"$", "%"} or token.kind != "symbol" or (token.value == "%" and i not in statement_starts and _operand(tokens, previous, node)):
			continue
		node.add(i)
		cursor = i + 1
		while cursor < len(tokens):
			item = tokens[cursor]
			if item.line != token.line or (cursor > i + 1 and item.start != tokens[cursor - 1].end):
				break
			if item.kind not in {"identifier", "number", "string"} and item.value not in {"/", ":"}:
				break
			node.add(cursor)
			cursor += 1
		if i + 1 in node:
			c.gap(token, tokens[i + 1], "")
	for i, token in enumerate(tokens):
		value = token.value
		member = i > 0 and tokens[i - 1].value == "."
		if i not in node and (value in _BINARY or (value in _WORDS and not member)):
			previous = i - 1
			while previous >= 0 and tokens[previous].value == "\\":
				previous -= 1
			unary = value in {"+", "-"} and not _operand(tokens, previous, node)
			if i and not unary:
				c.gap(tokens[i - 1], token, " ")
			if i + 1 < len(tokens):
				c.gap(token, tokens[i + 1], "" if unary else " ")
		if value in {"!", "~"} and token.kind == "symbol" and i + 1 < len(tokens):
			c.gap(token, tokens[i + 1], "")
		if value in _PREFIX and not member and i not in node and i + 1 < len(tokens) and value not in _WORDS and tokens[i + 1].value not in {":", ",", ")", "]", "}"}:
			c.gap(token, tokens[i + 1], " ")
			if value == "not" and tokens[i + 1].value == "in" and i and _operand(tokens, i - 1, node):
				c.gap(tokens[i - 1], token, " ")
		if value == ":" and token.kind == "symbol" and i not in node:
			if i:
				c.gap(tokens[i - 1], token, "")
			if i + 1 < len(tokens):
				c.gap(token, tokens[i + 1], " ")
		if value == "," and token.kind == "symbol":
			if i:
				c.gap(tokens[i - 1], token, "")
			if i + 1 < len(tokens):
				closing = by_close.get(i + 1)
				inline_dictionary = closing is not None and closing.kind == "dictionary" and closing.items and tokens[closing.open_index].line == tokens[closing.close_index].line
				c.gap(token, tokens[i + 1], "" if tokens[i + 1].value in {")", "]", "}"} and not inline_dictionary else " ")
	for group in c.scope[0].groups:
		opener, closer = tokens[group.open_index], tokens[group.close_index]
		if opener.value == "[" and group.kind == "index" and group.open_index:
			c.gap(tokens[group.open_index - 1], opener, "")
		if opener.value == "(" and group.open_index:
			previous = tokens[group.open_index - 1]
			member = group.open_index > 1 and tokens[group.open_index - 2].value == "."
			if (group.kind in {"call", "parameters"} and previous.value not in _PREFIX) or member:
				c.gap(previous, opener, "")
		if group.open_index + 1 == group.close_index:
			c.gap(opener, closer, "")
			continue
		padding = " " if group.kind == "dictionary" and opener.line == closer.line else ""
		c.gap(opener, tokens[group.open_index + 1], padding)
		c.gap(tokens[group.close_index - 1], closer, padding)


@dataclass
class _Suite:
	start: int
	colon: int
	kind: str
	actual: int
	expected: int


@dataclass
class _Member:
	owner: tuple
	kind: str
	line: int
	start_line: int
	documented: bool
	indent: int


def _declaration(view, start, by_open):
	tokens = view.tokens
	cursor = start
	while cursor < len(tokens) and tokens[cursor].value == "@":
		cursor += 2
		if cursor in by_open:
			cursor = by_open[cursor].close_index + 1
		if cursor >= len(tokens) or tokens[cursor].line != tokens[cursor - 1].end_line:
			return None
	if tokens[cursor].value == "static":
		cursor += 1
	return cursor if cursor < len(tokens) and tokens[cursor].value in _DECLARATIONS else None


def _suite_and_members(c):
	# Lazy import uses the already-created shared view; this is not another lexer.
	from gf_gdscript_readability import _header_colon
	view, tokens = c.view, c.view.tokens
	by_open = {g.open_index: g for g in c.scope[0].groups}
	starts = c.scope[3]
	# The first token on a multiline literal's closing row can still be a
	# postfix/operator of the earlier statement, not an offside statement.
	starts = {index for index in starts if not index or tokens[index - 1].end_line < tokens[index].line}
	headers = {}
	annotations = {}
	group_annotations = set()
	declarations = {}
	for index in sorted(starts):
		token = tokens[index]
		decl = _declaration(view, index, by_open)
		if decl is not None:
			declarations[index] = decl
		if token.value == "@":
			end = index + 1
			if end + 1 in by_open:
				end = by_open[end + 1].close_index
			if end + 1 == len(tokens) or tokens[end + 1].line > tokens[end].end_line:
				annotations[tokens[end].end_line] = token.line
				if tokens[index + 1].value in {"export_group", "export_subgroup"}:
					group_annotations.add(tokens[end].end_line)
		kind = tokens[decl].value if decl is not None else token.value
		if kind in _HEADERS | {"func"}:
			colon = _header_colon(tokens, decl if decl is not None else index, by_open)
			if colon is not None:
				headers[index] = colon, kind
		elif kind == "var":
			cursor = decl
			while cursor < len(tokens):
				if cursor in by_open:
					closing = by_open[cursor].close_index
					cursor = closing + 1
					if cursor >= len(tokens) or tokens[cursor].line > tokens[closing].end_line:
						break
					continue
				item = tokens[cursor]
				if item.value == ":" and cursor + 1 < len(tokens) and tokens[cursor + 1].line > item.line and tokens[cursor + 1].value in {"get", "set"}:
					headers[index] = cursor, "property"
					break
				if cursor + 1 >= len(tokens) or tokens[cursor + 1].line > item.end_line:
					break
				cursor += 1
	declaration_indexes = set(declarations.values())
	for index, token in enumerate(tokens):
		if token.value == "func" and token.kind == "identifier" and (not index or tokens[index - 1].value != "."):
			if index in starts or index in declaration_indexes:
				continue
			colon = _header_colon(tokens, index, by_open)
			if colon is not None:
				headers[index] = colon, "lambda"
	comments = {comment.line: comment for comment in view.comments if view.lines[comment.line - 1].strip() == comment.value.rstrip()}
	stack = []
	expected_lines = {}
	members = []
	patterns = []
	for index in sorted(starts | set(headers)):
		token = tokens[index]
		actual = c.indents[token.line]
		if index in starts:
			while stack and token.line > tokens[stack[-1].colon].line and actual <= stack[-1].actual:
				stack.pop()
			expected = stack[-1].expected + 1 if stack else 0
			expected_lines[token.line] = expected
			c.prefix(token.line, expected)
			if expected != actual:
				line = token.line - 1
				while line in comments and c.indents[line] == actual:
					c.prefix(line, expected)
					line -= 1
			if all(suite.kind == "class" for suite in stack) and index in declarations:
				decl = declarations[index]
				start_line, documented = _member_prefix(c, token.line, comments, annotations, group_annotations)
				members.append(_Member(tuple(s.start for s in stack), tokens[decl].value, token.line, start_line, documented, actual))
			if stack and stack[-1].kind == "match" and index not in headers:
				colon = _header_colon(tokens, index, by_open)
				if colon is not None:
					patterns.append((index, colon, expected))
					stack.append(_Suite(index, colon, "arm", actual, expected))
		if index in headers:
			colon, kind = headers[index]
			if colon + 1 < len(tokens) and tokens[colon + 1].line > tokens[colon].line:
				stack.append(_Suite(index, colon, kind, actual, expected_lines.get(token.line, actual)))
	_member_spacing(c, members, comments)
	_match_patterns(c, patterns, by_open)


def _member_prefix(c, line, comments, annotations, group_annotations):
	start, documented = line, False
	pending = []
	cursor = line - 1
	while cursor > 0:
		comment = comments.get(cursor)
		if comment is not None and c.indents[cursor] == c.indents[line] and not comment.value.startswith("# ---"):
			documented = documented or comment.value.startswith("##")
			start = cursor
			cursor -= 1
		elif cursor in annotations and c.indents[annotations[cursor]] == c.indents[line]:
			start = annotations[cursor]
			cursor = start - 1
		elif not c.view.lines[cursor - 1].strip():
			stop = cursor
			while cursor > 0 and not c.view.lines[cursor - 1].strip():
				cursor -= 1
			upper = comments.get(cursor)
			if (cursor in annotations and cursor not in group_annotations) or (upper is not None and upper.value.startswith("##") and c.indents[cursor] == c.indents[line]):
				pending.append((cursor, stop + 1))
			else:
				break
		else:
			break
	if documented:
		for before, after in pending:
			c.blank(before, after, 0, "member_doc_binding")
	return start, documented


def _member_spacing(c, members, comments):
	by_owner = {}
	line_tokens = c.view.tokens
	token_lines = [token.line for token in line_tokens]
	for member in members:
		previous = by_owner.get(member.owner)
		by_owner[member.owner] = member
		if previous is None or previous.kind not in _DATA or member.kind not in _DATA:
			continue
		last_index = bisect_left(token_lines, member.start_line) - 1
		if last_index < 0:
			continue
		end_line = line_tokens[last_index].end_line
		# A property's trailing body comment remains inside that member's block.
		for line in range(end_line + 1, member.start_line):
			if line in comments and c.indents[line] > previous.indent:
				end_line = line
		if previous.documented:
			c.blank(end_line, member.start_line, 1, "member_block_spacing")
		elif member.kind in _DATA and not member.documented and previous.line == end_line and member.start_line == member.line:
			c.blank(end_line, member.start_line, 0, "member_block_spacing")


def _match_patterns(c, patterns, by_open):
	tokens = c.view.tokens
	for start, colon, indent in patterns:
		if tokens[start].line == tokens[colon].line:
			continue
		cursor = start
		while cursor < colon:
			if cursor in by_open:
				cursor = by_open[cursor].close_index + 1
				continue
			if tokens[cursor].value == "when":
				break
			if tokens[cursor].value == "," and cursor + 1 < colon:
				next_item = cursor + 1
				while next_item < colon and tokens[next_item].value == "\\":
					next_item += 1
				if next_item < colon and tokens[next_item].line > tokens[cursor].line:
					c.prefix(tokens[next_item].line, indent)
			if tokens[cursor].value == "," and cursor + 1 < colon and tokens[cursor + 1].value != "\\" and tokens[cursor + 1].line == tokens[cursor].line:
				left, right = tokens[cursor], tokens[cursor + 1]
				if not c.view.source[left.end:right.start].strip():
					c.put(left.end, right.start, " \\\n" + "\t" * indent, "match_pattern_layout", right.line, "Start each direct pattern of a multiline match arm on its own line.")
			cursor += 1


def layout_edits(view) -> tuple[LayoutEdit, ...]:
	"""Return ordered, disjoint edits containing only proven layout changes.

	Only match-pattern splitting may add syntax: a continuation marker directly
	after that pattern separator and immediately before its new physical LF.
	All token gaps are checked against the shared view's original source offsets.
	"""
	if view.issues:
		return ()
	c = _Collector(view)
	_spacing(c)
	_suite_and_members(c)
	result = tuple(sorted(c.edits.values(), key=lambda edit: (edit.start, edit.end)))
	for left, right in zip(result, result[1:]):
		if left.end > right.start:
			raise ValueError("Structural layout edits overlap.")
	return result


def audit_issues(path: str, view) -> list[dict]:
	return [{"path": path, "rule": edit.rule, "kind": edit.rule, "line": edit.line, "column": 1, "message": edit.message, "suggestion": "Apply the structural layout without changing original tokens or literal and comment payloads."} for edit in layout_edits(view)]
