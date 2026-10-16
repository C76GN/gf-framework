"""Canonical whitespace and necessary carriers for complete GDScript expressions."""

from __future__ import annotations

from bisect import bisect_left, bisect_right
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class LayoutEdit:
	start: int
	end: int
	replacement: str
	rule: str


def effective_group_kinds(view: Any) -> tuple[str, ...]:
	"""Restore proven member roles and independent physical statement starts.

	The shared lexer intentionally keeps local delimiter roles simple. A complete
	previous statement must not turn the next parenthesized expression into a call,
	or a new array literal into an index. Returned roles never mutate the view and
	this helper does not depend on either layout engine.
	"""
	import gf_gdscript_readability as readability

	scope = readability._boolean_scope_view(view)
	if scope is None:
		return tuple(group.kind for group in view.groups)
	kinds = list(scope[-1])
	starts = scope[3]
	for number, group in enumerate(view.groups):
		index = group.open_index
		if index not in starts or index == 0:
			continue
		previous, opener = view.tokens[index - 1], view.tokens[index]
		if previous.end_line >= opener.line or previous.value == "\\":
			continue
		if opener.value == "(":
			kinds[number] = "group"
		elif opener.value == "[":
			kinds[number] = "array"
	return tuple(kinds)


def layout_edits(view: Any, *, max_inline_items: int = 2) -> tuple[LayoutEdit, ...]:
	"""Return disjoint edits, retaining original tokens except required carriers.

	Calls, declarations and container item counts have independent owners. Their
	physical child layout is consumed here; the shared bounded fixed point closes
	those decisions without guessing types or using text width. Boolean and nested
	conditional layers always take precedence over optional expression collapse.
	"""
	if type(max_inline_items) is not int or max_inline_items < 1:
		raise ValueError("The inline item policy must be a positive integer.")
	if view.issues or not view.tokens:
		return ()
	# Read the calling checker's current Boolean policy, never a copied threshold.
	import gf_gdscript_readability as readability

	tokens, groups = view.tokens, view.groups
	by_open = {group.open_index: group for group in groups}
	by_close = {group.close_index: group for group in groups}
	group_numbers = {group.open_index: number for number, group in enumerate(groups)}
	parents: list[int | None] = []
	stack: list[int] = []
	first_by_line: dict[int, int] = {}
	indexes_by_line: dict[int, list[int]] = {}
	for index, token in enumerate(tokens):
		parents.append(stack[-1] if stack else None)
		first_by_line.setdefault(token.line, index)
		indexes_by_line.setdefault(token.line, []).append(index)
		if index in group_numbers:
			stack.append(group_numbers[index])
		elif index in by_close:
			stack.pop()
	scope = readability._boolean_scope_view(view)
	if scope is None:
		return ()
	names, path_symbols = readability._boolean_name_path_roles(view, scope[3])
	kinds = effective_group_kinds(view)
	roles = {group.open_index: kinds[number] for number, group in enumerate(groups)}
	plan = _Plan(view, first_by_line, indexes_by_line)
	protected: set[int] = set()
	for span in readability.boolean_layout_spans(view):
		protected.update(span.layer_group_open_indexes)
		if span.carrier_open_index is not None:
			protected.add(span.carrier_open_index)
	ternary_layers: set[int] = set()
	readability._check_ternaries(
		"addons/gf/expression.gd", view,
		{index: parent for index, parent in enumerate(parents) if parent is not None},
		[], ternary_layers,
	)
	protected.update(groups[number].open_index for number in ternary_layers)
	_identifier, _atom, barrier_free = readability._atomic_layout_matcher(view)
	# The proven scope restores keyword-named call hosts and lambda body owners.
	# Reading raw parameter roles here would mistake a body's assignment for a
	# parameter default and merge its next independent %UniqueNode statement.
	_by_open, _parents, _operators, candidates = readability._expression_layout_candidates(scope[1], _identifier)
	_first, statement_starts = readability._independent_statement_starts(scope[1] if scope else view)
	statement_values = _statement_values(view, parents, by_open, statement_starts)
	candidates.update(statement_values)
	specialized = {
		(span.start_index, span.end_index)
		for span in (*readability.simple_string_layout_spans(view), *readability.simple_format_layout_spans(view))
	}
	def format_percent(start: int, end: int) -> int | None:
		return _direct_percent(view, start, end, by_open, roles, names, path_symbols)
	candidates.update((group.open_index, group.close_index + 1) for number, group in enumerate(groups) if kinds[number] == "group")
	slots = _ternary_slots(view, candidates, by_open, parents, statement_values, roles, readability.MAX_GROUP_DEPTH, names)
	candidates.update(slots)
	formats = _format_domains(view, candidates, by_open, parents, statement_values, roles, slots, format_percent)
	for _start, _end, carrier, wrappers in formats:
		protected.update(wrappers)
		if carrier is not None:
			protected.add(carrier)
	# A forced child cannot be hidden by joining a currently inline ancestor.
	for opening in tuple(protected):
		parent = groups[group_numbers[opening]].parent_index
		while parent is not None:
			protected.add(groups[parent].open_index)
			parent = groups[parent].parent_index
	# Container/call carriers already allow a complete operand to continue. Once
	# its children are inline, normalize the operand itself instead of leaving an
	# old physical break to lock the surrounding list into expanded layout.
	for start, end in sorted(candidates):
		if (start, end) in specialized:
			continue
		if start >= end or (start in by_open and by_open[start].close_index == end - 1):
			continue
		if not barrier_free(start, end):
			continue
		cursor = start
		operators = []
		child_multiline = False
		while cursor < end:
			child = by_open.get(cursor)
			if child is not None:
				if child.open_index in protected or tokens[child.open_index].line != tokens[child.close_index].end_line:
					child_multiline = True
				cursor = child.close_index + 1
				continue
			operators.append(tokens[cursor].value if cursor not in scope[4] else "<name>")
			cursor += 1
		if child_multiline or "func" in operators:
			continue
		if sum(value in {"and", "or", "&&", "||"} for value in operators) + 1 > readability.MAX_INLINE_CONDITION_TERMS:
			# Optional domains follow the same dynamic threshold as required groups.
			continue
		if any(left == start and right == end for left, right, _carrier, _wrappers in formats):
			continue
		if not any(value in {"+", "-", "*", "/", "%", "**", "&", "|", "^", "<<", ">>", "==", "!=", "<", ">", "<=", ">=", "in", "is", "and", "or", "&&", "||", "if", "await"} for value in operators):
			continue
		if "if" in operators and operators.count("if") != 1:
			continue
		for index in range(start + 1, end):
			if "\n" in plan.gap(index):
				plan.put_gap(index, _inline_separator(view, index, roles), "expression_layout")
	children: dict[int, list[Any]] = {}
	for group in groups:
		if group.parent_index is not None:
			children.setdefault(group.parent_index, []).append(group)
	lambda_colons: dict[int, list[int]] = {}
	for index, token in enumerate(tokens):
		if token.kind != "identifier" or token.value != "func" or (index and tokens[index - 1].value == "."):
			continue
		opening = index + 1
		if opening < len(tokens) and tokens[opening].kind == "identifier":
			opening += 1
		parameters = by_open.get(opening)
		if parameters is None or kinds[group_numbers[opening]] != "parameters":
			continue
		colon = readability._header_colon(tokens, index, by_open)
		if colon is not None and parents[index] is not None:
			lambda_colons.setdefault(parents[index], []).append(colon)
	all_lambda_colons = sorted(colon for colons in lambda_colons.values() for colon in colons)
	direct_lines: dict[int, list[int]] = {}
	for index in first_by_line.values():
		if parents[index] is not None:
			direct_lines.setdefault(parents[index], []).append(index)
	for number, group in enumerate(groups):
		kind = kinds[number]
		if kind not in {"group", "index"} or not group.items:
			continue
		if kind == "index" and tokens[group.open_index - 1].value in {"Array", "Dictionary"}:
			# Builtin generic type brackets belong to declarations/casts, not indexing.
			continue
		if len(group.items) != 1 or tokens[group.close_index - 1].value == ",":
			continue
		start, end = group.open_index, group.close_index
		if any(token.value == "\\" for token in tokens[start + 1:end]):
			# This carrier retains its physical continuation; children are still visited.
			continue
		contains_lambda = bisect_right(all_lambda_colons, start) < bisect_left(all_lambda_colons, end)
		inline_children = all(
			tokens[child.open_index].line == tokens[child.close_index].end_line
			for child in children.get(number, ())
		)
		inline = (
			start not in protected and inline_children and not contains_lambda
			and barrier_free(start, end + 1)
		)
		rule = "index_layout" if kind == "index" else "expression_group_layout"
		if inline:
			if (start, end + 1) in specialized:
				continue
			for index in range(start + 1, end + 1):
				if "\n" in plan.gap(index):
					plan.put_gap(index, _inline_separator(view, index, roles), rule)
			continue
		base = plan.indentation(start)
		first = start + 1
		plan.newline(first, base + 1, rule)
		plan.move_line(first, base + 1, end, lambda_colons.get(number, ()), rule)
		body_colons = lambda_colons.get(number, ())
		for index in direct_lines.get(number, ()):
			if index <= first or index >= end or parents[index] != number:
				continue
			if any(colon < index for colon in body_colons):
				# The lexical parent remains open during a lambda's independent body.
				continue
			plan.move_line(index, base + 1, end, body_colons, rule)
		plan.newline(end, base, rule)
	for start, end, carrier, wrappers in formats:
		core_start, core_end = start, end
		while core_start in by_open and by_open[core_start].close_index == core_end - 1 and roles[core_start] == "group":
			core_end -= 1
			core_start += 1
		percent = format_percent(core_start, core_end)
		if percent is None:
			continue
		if carrier is None:
			base = plan.indentation(core_start)
			plan.insert(tokens[core_start].start, "(\n" + "\t" * (base + 1), "format_carrier")
			plan.insert(tokens[core_end - 1].end, "\n" + "\t" * base + ")", "format_carrier")
			plan.translate(core_start, core_end - 1, 1, "format_layout")
			level = base + 1
		else:
			level = plan.indentation(carrier) + 1
		plan.newline(percent, level, "format_layout")
	# A suffix belongs to its receiver's last physical line, including a multiline
	# call/index result. A comment or explicit continuation between them is a real
	# local barrier, not an exemption for every descendant in the carrier.
	for index in range(1, len(tokens) - 1):
		if tokens[index].value != "." or tokens[index].kind != "symbol" or tokens[index + 1].kind != "identifier":
			continue
		previous = tokens[index - 1]
		if previous.kind not in {"identifier", "number", "string"} and previous.value not in {")", "]", "}"}:
			continue
		if "\n" in plan.gap(index):
			separator = " " if previous.kind == "number" else ""
			plan.put_gap(index, separator, "chain_layout")
		if "\n" in plan.gap(index + 1):
			plan.put_gap(index + 1, "", "chain_layout")
	return plan.edits()


def _inline_separator(view: Any, index: int, roles: dict[int, str]) -> str:
	previous, current = view.tokens[index - 1], view.tokens[index]
	if previous.value in {"(", "[", "."} or current.value in {")", "]", "}", ",", ".", ":"}:
		return ""
	if current.value == "[" and roles[index] == "index":
		return ""
	if current.value == "(" and roles[index] == "call":
		return ""
	if current.value == "(" and previous.value not in {"if", "else", "not", "and", "or", "in", "return", "await", "is", "as"} and (previous.kind == "identifier" or previous.value in {")", "]"}):
		return ""
	if previous.value in {"-", "+", "~", "!"} and index > 1 and view.tokens[index - 2].value in {"(", "[", "=", ":=", "+", "-", "*", "/", "and", "or"}:
		return ""
	return " "


def _statement_values(view: Any, parents: list[int | None], by_open: dict[int, Any], starts: set[int]) -> set[tuple[int, int]]:
	values: set[tuple[int, int]] = set()
	assignments = {"=", ":=", "+=", "-=", "*=", "/=", "%=", "**=", "<<=", ">>=", "&=", "|=", "^="}
	for start in starts:
		cursor = start
		operators = []
		while cursor < len(view.tokens):
			token = view.tokens[cursor]
			if cursor > start and token.line > view.tokens[cursor - 1].end_line and view.tokens[cursor - 1].value != "\\":
				break
			if parents[cursor] != parents[start] or token.value in {",", ")", "]", "}"}:
				break
			if token.value in assignments:
				operators.append(cursor)
			group = by_open.get(cursor)
			cursor = group.close_index + 1 if group is not None else cursor + 1
		if view.tokens[start].value == "return" and start + 1 < cursor:
			values.add((start + 1, cursor))
		elif len(operators) == 1 and operators[0] + 1 < cursor:
			values.add((operators[0] + 1, cursor))
	return values


def _direct_percent(view: Any, start: int, end: int, by_open: dict[int, Any], roles: dict[int, str], names: set[int], path_symbols: set[int]) -> int | None:
	percent = None
	cursor = start
	forbidden = {"+", "-", "*", "/", "**", "&", "|", "^", "<<", ">>", "==", "!=", "<", ">", "<=", ">=", "and", "or", "&&", "||", "if", "else", "as", "await", "func"}
	while cursor < end:
		group = by_open.get(cursor)
		if group is not None:
			cursor = group.close_index + 1
			continue
		value = view.tokens[cursor].value
		if cursor in names or cursor in path_symbols:
			cursor += 1
			continue
		if value == "%":
			if percent is not None:
				return None
			percent = cursor
		elif value in forbidden:
			return None
		cursor += 1
	if percent is None or percent <= start or percent + 1 >= end:
		return None
	array = by_open.get(percent + 1)
	if array is None or roles[array.open_index] != "array" or array.close_index != end - 1:
		return None
	return percent


def _ternary_slots(view: Any, candidates: set[tuple[int, int]], by_open: dict[int, Any], parents: list[int | None], statements: set[tuple[int, int]], roles: dict[int, str], max_depth: int, names: set[int]) -> dict[tuple[int, int], int | None]:
	"""Expose complete branch/condition domains without borrowing lambda carriers."""
	result: dict[tuple[int, int], int | None] = {}
	queue = []
	for start, end in sorted(candidates):
		if start >= end:
			continue
		carrier = None if (start, end) in statements or parents[start] is None else view.groups[parents[start]].open_index
		queue.append((start, end, carrier, 0))
	visited: set[tuple[int, int, int | None]] = set()
	while queue:
		start, end, carrier, depth = queue.pop()
		if depth > max_depth:
			# Such an ungrouped nested conditional already fails nested_ternary;
			# do not let malformed optional-domain discovery exceed its budget.
			continue
		if (start, end, carrier) in visited:
			continue
		visited.add((start, end, carrier))
		while start in by_open and roles[start] == "group" and by_open[start].close_index == end - 1:
			carrier = start
			start += 1
			end -= 1
		cursor = start
		pending = []
		matching = {}
		while cursor < end:
			child = by_open.get(cursor)
			if child is not None:
				cursor = child.close_index + 1
				continue
			token = view.tokens[cursor]
			if token.kind == "identifier" and cursor not in names:
				if token.value == "func":
					break
				if token.value == "if":
					pending.append(cursor)
				elif token.value == "else" and pending:
					matching[pending.pop()] = cursor
			cursor += 1
		if not matching:
			continue
		first = min(matching)
		otherwise = matching[first]
		for left, right in ((start, first), (first + 1, otherwise), (otherwise + 1, end)):
			if left < right:
				result.setdefault((left, right), carrier)
				queue.append((left, right, carrier, depth + 1))
	return result


def _format_domains(view: Any, candidates: set[tuple[int, int]], by_open: dict[int, Any], parents: list[int | None], statements: set[tuple[int, int]], roles: dict[int, str], slots: dict[tuple[int, int], int | None], format_percent: Any) -> list[tuple[int, int, int | None, tuple[int, ...]]]:
	result = {}
	comment_starts = tuple(comment.start for comment in view.comments)
	for start, end in sorted(candidates):
		left, right = start, end
		wrappers = []
		while left in by_open and roles[left] == "group" and by_open[left].close_index == right - 1:
			wrappers.append(left)
			left += 1
			right -= 1
		if format_percent(left, right) is None:
			continue
		if any(token.value == "\\" or (token.kind == "string" and token.line != token.end_line) for token in view.tokens[left:right]):
			continue
		comment = bisect_left(comment_starts, view.tokens[left].start)
		if comment < len(comment_starts) and comment_starts[comment] < view.tokens[right - 1].end:
			continue
		if wrappers:
			carrier = wrappers[-1]
		elif (start, end) in slots:
			carrier = slots[start, end]
		elif (start, end) in statements:
			carrier = None
		elif parents[start] is not None:
			carrier = view.groups[parents[start]].open_index
		else:
			continue
		key = left, right
		previous = result.get(key)
		if previous is None or len(wrappers) > len(previous[3]):
			result[key] = start, end, carrier, tuple(wrappers)
	return list(result.values())


class _Plan:
	"""Accumulate whitespace gaps, subtree translations and necessary insertions."""

	def __init__(self, view: Any, first_by_line: dict[int, int], indexes_by_line: dict[int, list[int]]) -> None:
		self.view = view
		self.first = first_by_line
		self.line_indexes = indexes_by_line
		self.code_lines = sorted(first_by_line)
		self.levels = {line: len(raw) - len(raw.lstrip("\t")) for line, raw in enumerate(view.lines, 1)}
		self.token_levels: dict[int, int] = {}
		self.changed: dict[int, tuple[str, str]] = {}
		self.insertions: dict[int, tuple[str, str]] = {}
		self.prefix_rules: dict[int, str] = {}
		self.groups_on_line: dict[int, list[Any]] = {}
		for group in view.groups:
			self.groups_on_line.setdefault(view.tokens[group.open_index].line, []).append(group)
		self.comment_starts = tuple(comment.start for comment in view.comments)
		self.line_starts = [0]
		self.line_starts.extend(index + 1 for index, value in enumerate(view.source) if value == "\n")
		self.comment_lines = {
			comment.line: comment for comment in view.comments
			if not view.source[self.line_starts[comment.line - 1]:comment.start].strip()
		}
		self.comment_targets: dict[int, int] = {}

	def gap(self, index: int) -> str:
		if index in self.changed:
			return self.changed[index][0]
		start = self.view.tokens[index - 1].end if index else 0
		return self.view.source[start:self.view.tokens[index].start]

	def indentation(self, index: int) -> int:
		return self.token_levels.get(index, self.levels[self.view.tokens[index].line])

	def put_gap(self, index: int, replacement: str, rule: str) -> None:
		start = self.view.tokens[index - 1].end if index else 0
		end = self.view.tokens[index].start
		original = self.view.source[start:end]
		comment = bisect_left(self.comment_starts, start)
		if comment < len(self.comment_starts) and self.comment_starts[comment] < end:
			return
		if original.strip():
			return
		self.changed[index] = replacement, rule

	def newline(self, index: int, level: int, rule: str) -> None:
		gap = self.gap(index)
		if gap.strip() and "\n" in gap:
			cut = gap.rfind("\n") + 1
			if not gap[cut:].strip():
				# A comment keeps its exact physical row and binding. Only the
				# following code line's indentation belongs to this owner.
				self.changed[index] = gap[:cut] + "\t" * level, rule
			return
		self.put_gap(index, "\n" + "\t" * level, rule)

	def insert(self, offset: int, text: str, rule: str) -> None:
		if offset in self.insertions and self.insertions[offset] != (text, rule):
			raise ValueError("Conflicting expression continuation carriers.")
		self.insertions[offset] = text, rule

	def translate(self, start: int, end: int, delta: int, rule: str) -> None:
		first_line, end_line = self.view.tokens[start].line, self.view.tokens[end].end_line
		for index in self.line_indexes[first_line]:
			if start <= index <= end:
				self.token_levels[index] = self.indentation(index) + delta
		for line in self.code_lines[bisect_right(self.code_lines, first_line):bisect_right(self.code_lines, end_line)]:
			index = self.first[line]
			if index > end:
				continue
			self.levels[line] = max(0, self.levels[line] + delta)
			self.prefix_rules[line] = rule
		for line, comment in self.comment_lines.items():
			if first_line < line <= end_line and comment.end <= self.view.tokens[end].end:
				self.levels[line] = max(0, self.levels[line] + delta)
				self.comment_targets[line] = self.levels[line]

	def move_line(self, index: int, target: int, owner_end: int, lambda_colons: Any, rule: str) -> None:
		line = self.view.tokens[index].line
		delta = target - self.indentation(index)
		if delta == 0:
			return
		end = index
		for group in self.groups_on_line.get(line, ()):
			if index <= group.open_index < owner_end:
				end = max(end, group.close_index)
		if any(index <= colon and self.view.tokens[colon].line == line for colon in lambda_colons):
			end = owner_end - 1
		self.translate(index, end, delta, rule)
		if self.first[line] == index:
			self.levels[line] = target
			self.prefix_rules[line] = rule

	def edits(self) -> tuple[LayoutEdit, ...]:
		for line, rule in self.prefix_rules.items():
			index = self.first[line]
			gap = self.gap(index)
			if "\n" in gap:
				prefix = gap[:gap.rfind("\n") + 1]
				start = self.view.tokens[index - 1].end if index else 0
				original = self.view.source[start:self.view.tokens[index].start]
				if original.strip():
					# Change only the indentation after comments, never comment bytes.
					cut = original.rfind("\n") + 1
					if not original[cut:].strip():
						self.changed[index] = original[:cut] + "\t" * self.levels[line], rule
				else:
					self.put_gap(index, prefix + "\t" * self.levels[line], rule)
		comment_changes: dict[int, list[tuple[int, int, str]]] = {}
		token_starts = tuple(token.start for token in self.view.tokens)
		for line, target in self.comment_targets.items():
			comment = self.comment_lines[line]
			index = bisect_right(token_starts, comment.end)
			if index >= len(self.view.tokens):
				continue
			start = self.view.tokens[index - 1].end if index else 0
			left, right = self.line_starts[line - 1] - start, comment.start - start
			if left >= 0:
				comment_changes.setdefault(index, []).append((left, right, "\t" * target))
		for index, changes in comment_changes.items():
			gap = self.gap(index)
			for left, right, replacement in sorted(changes, reverse=True):
				gap = gap[:left] + replacement + gap[right:]
			self.changed[index] = gap, "expression_group_layout"
		result = []
		for index, (replacement, rule) in self.changed.items():
			start = self.view.tokens[index - 1].end if index else 0
			end = self.view.tokens[index].start
			if self.view.source[start:end] != replacement:
				result.append(LayoutEdit(start, end, replacement, rule))
		for offset, (replacement, rule) in self.insertions.items():
			result.append(LayoutEdit(offset, offset, replacement, rule))
		result.sort(key=lambda edit: (edit.start, edit.end))
		if any(previous.end > current.start for previous, current in zip(result, result[1:])):
			raise ValueError("Expression layout generated overlapping edits.")
		return tuple(result)
