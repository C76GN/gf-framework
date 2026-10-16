"""Canonical list layout shared by diagnostics and whitespace-only migrations.

Lists are classified from their direct items, independently of name length.
Ordinary expression groups and indexes belong to the expression-layout pass;
the caller combines the passes to a bounded fixed point. No source is written
here, and every replacement is confined to one inter-token whitespace gap.
"""

from __future__ import annotations

from bisect import bisect_right
from dataclasses import dataclass
from typing import TYPE_CHECKING

if TYPE_CHECKING:
	from gf_gdscript_readability import Group, LexedSource, Token


_FIELD_ANNOTATIONS = frozenset({
	"export", "export_range", "export_enum", "export_flags", "export_exp_easing",
	"export_file", "export_dir", "export_global_file", "export_global_dir",
	"export_multiline", "export_placeholder", "export_color_no_alpha",
	"export_node_path", "export_flags_2d_render", "export_flags_3d_render",
	"export_flags_2d_physics", "export_flags_3d_physics",
	"export_flags_2d_navigation", "export_flags_3d_navigation",
	"export_storage", "export_custom", "export_tool_button", "onready",
})


@dataclass(frozen=True)
class LayoutEdit:
	"""One half-open source replacement, sorted and disjoint from other edits."""

	start: int
	end: int
	replacement: str
	rule: str


@dataclass(frozen=True)
class _Plan:
	group: Group
	kind: str
	layout: str
	rule: str
	depth: int


def _validate_threshold(max_inline_items: int) -> None:
	if isinstance(max_inline_items, bool) or not isinstance(max_inline_items, int) or max_inline_items < 0:
		raise ValueError("max_inline_items must be a nonnegative integer")


def _kind(view: LexedSource, group: Group, effective_kind: str) -> str | None:
	tokens = view.tokens
	opening = group.open_index
	if tokens[opening].value == "(":
		if opening >= 2 and tokens[opening - 2].value == "@":
			return "annotation"
		if effective_kind == "call":
			return "call"
		if effective_kind == "parameters":
			return "parameters"
	if effective_kind in {"array", "dictionary"}:
		return effective_kind
	return None


def _rule(kind: str) -> str:
	return {
		"parameters": "declaration_parameter_layout",
		"annotation": "annotation_parameter_layout",
	}.get(kind, "list_layout")


def _indent(view: LexedSource, line: int) -> int:
	raw = view.lines[line - 1]
	return len(raw) - len(raw.lstrip("\t"))


def _plans(view: LexedSource, max_inline_items: int) -> dict[int, _Plan]:
	_validate_threshold(max_inline_items)
	if view.issues:
		return {}
	# Import only at invocation time: readability consumes this module as well.
	import gf_gdscript_readability as readability
	from gf_gdscript_expression_layout import effective_group_kinds

	tokens, groups = view.tokens, view.groups
	by_open = {group.open_index: group for group in groups}
	effective_kinds = effective_group_kinds(view)
	kinds = {group.open_index: kind for number, group in enumerate(groups) if (kind := _kind(view, group, effective_kinds[number])) is not None}
	barriers = readability._entry_call_physical_barriers(view)
	_identifier, atom, _barrier_free = readability._atomic_layout_matcher(view)
	boolean_spans = readability.boolean_layout_spans(view)
	boolean_starts = sorted((span.start_index, span.end_index) for span in boolean_spans)
	start_indexes = [start for start, _end in boolean_starts]
	depths: dict[int, int] = {}
	nonempty_container_ancestors: set[int] = set()
	for number, group in enumerate(groups):
		depths[group.open_index] = 0 if group.parent_index is None else depths[groups[group.parent_index].open_index] + 1
		if effective_kinds[number] in {"array", "dictionary"} and group.items:
			parent = group.parent_index
			while parent is not None:
				nonempty_container_ancestors.add(groups[parent].open_index)
				parent = groups[parent].parent_index

	plans: dict[int, _Plan] = {}

	def item_multiline(start: int, end: int, kind: str) -> bool:
		if atom(start, end) is not None:
			return False
		first_boolean = bisect_right(start_indexes, start - 1)
		if first_boolean < len(boolean_starts):
			boolean_start, boolean_end = boolean_starts[first_boolean]
			if start <= boolean_start < end and boolean_end <= end:
				return True
		# A declaration's type is metadata, not a value/index expression. Its
		# internal generic commas do not become declaration parameters.
		default_start = end
		if kind == "parameters":
			cursor = start
			while cursor < end:
				child = by_open.get(cursor)
				if child is not None:
					cursor = child.close_index + 1
				elif tokens[cursor].value == "=":
					default_start = cursor + 1
					break
				else:
					cursor += 1
		cursor = start
		while cursor < end:
			child = by_open.get(cursor)
			if child is not None and child.close_index < end:
				if cursor in plans:
					if plans[cursor].layout != "inline":
						return True
					next_index = child.close_index + 1
					if next_index < end and tokens[child.close_index].end_line != tokens[next_index].line:
						if not (kind == "parameters" and next_index <= default_start):
							return True
					cursor = next_index
					continue
				if not (kind == "parameters" and cursor < default_start):
					if tokens[cursor].line != tokens[child.close_index].end_line:
						return True
			if cursor + 1 < end and tokens[cursor].end_line != tokens[cursor + 1].line:
				if not (kind == "parameters" and cursor + 1 <= default_start):
					return True
			cursor += 1
		return False

	for group in reversed(groups):
		opening, closing = group.open_index, group.close_index
		kind = kinds.get(opening)
		if kind is None:
			continue
		if barriers(opening, closing + 1):
			layout = "preserve"
		else:
			too_many = kind != "annotation" and len(group.items) > max_inline_items
			two_nonatomic_arguments = kind == "call" and len(group.items) == 2 and any(
				atom(start, end) is None for start, end in group.items
			)
			nested_container = kind in {"array", "dictionary"} and opening in nonempty_container_ancestors
			child_multiline = any(item_multiline(start, end, kind) for start, end in group.items)
			layout = "expanded" if too_many or two_nonatomic_arguments or nested_container or child_multiline else "inline"
		plans[opening] = _Plan(group, kind, layout, _rule(kind), depths[opening])
	return plans


def list_layout_states(view: LexedSource, *, max_inline_items: int = 2) -> dict[int, str]:
	"""Map list opening token indexes to inline, expanded or preserve.

	List descendants use canonical decisions instead of their old wrapping.
	Non-list expression children can remain expanded until the expression pass
	canonicalizes them; running the passes to a bounded fixed point resolves
	that dependency without making historical newlines a permanent policy.
	"""
	return {opening: plan.layout for opening, plan in sorted(_plans(view, max_inline_items).items())}


def _inline_separator(left: Token, right: Token) -> str:
	if right.value in {",", "(", ")", "[", "]", "}", ".", ":"} or left.value in {"(", "[", "{", "."}:
		return ""
	if left.value in {"+", "-", "~", "!", "&", "^"}:
		return ""
	return " "


def _annotation_binding_edits(view: LexedSource, plans: dict[int, _Plan]) -> tuple[LayoutEdit, ...]:
	"""Bind one field annotation; grouping/warning directives remain independent."""
	tokens = view.tokens
	by_open = {group.open_index: group for group in view.groups}
	annotations: dict[int, tuple[int, int, bool]] = {}
	ending: dict[int, tuple[int, int, bool]] = {}
	for index, token in enumerate(tokens[:-1]):
		if token.value != "@" or tokens[index + 1].kind != "identifier":
			continue
		end = index + 2
		if end in by_open:
			end = by_open[end].close_index + 1
		entry = index, end, tokens[index + 1].value in _FIELD_ANNOTATIONS
		annotations[index] = entry
		ending[end] = entry
	edits: list[LayoutEdit] = []
	for start, end, field in annotations.values():
		if not field or end >= len(tokens) or tokens[end].value not in {"var", "const"}:
			continue
		first, last, declaration = tokens[start], tokens[end - 1], tokens[end]
		if view.lines[first.line - 1][:first.column - 1].strip():
			continue
		if _indent(view, first.line) != _indent(view, declaration.line):
			continue
		metadata = plans.get(start + 2)
		if metadata is not None and metadata.layout != "inline":
			continue
		# Comments do not manufacture a new annotation block. If two field
		# annotations apply to one member, preserve their complete physical form.
		cursor = start
		multiple = False
		while cursor in ending:
			previous_start, _previous_end, previous_field = ending[cursor]
			if _indent(view, tokens[previous_start].line) != _indent(view, first.line):
				break
			if not previous_field:
				break
			multiple = True
			cursor = previous_start
		if multiple:
			continue
		gap = view.source[last.end:declaration.start]
		if gap and gap.isspace() and gap != " ":
			edits.append(LayoutEdit(last.end, declaration.start, " ", "annotation_binding_layout"))
	return tuple(edits)


def layout_edits(view: LexedSource, *, max_inline_items: int = 2) -> tuple[LayoutEdit, ...]:
	"""Return disjoint whitespace edits and necessary container final commas.

	Physical barriers protect their owner, not unrelated descendant lists.
	When a newly expanded item moves a lambda header or inner expression, its
	existing continuation/body indentation is rebased by that same displacement.
	Deeper list boundaries take precedence over inherited indentation rebasing.
	"""
	plans = _plans(view, max_inline_items)
	if view.issues:
		return ()
	tokens, source, groups = view.tokens, view.source, view.groups
	import gf_gdscript_readability as readability

	_identifier, atom, _barrier_free = readability._atomic_layout_matcher(view)
	item_starts = {opening: [left for left, _right in plan.group.items] for opening, plan in plans.items()}
	bases: dict[int, int] = {}
	for group in groups:
		opening = group.open_index
		if opening not in plans:
			continue
		base = _indent(view, tokens[opening].line)
		parent = group.parent_index
		while parent is not None and groups[parent].open_index not in plans:
			parent = groups[parent].parent_index
		if parent is not None:
			parent_open = groups[parent].open_index
			parent_plan = plans[parent_open]
			if parent_plan.layout == "expanded":
				item_number = bisect_right(item_starts[parent_open], opening) - 1
				if item_number >= 0:
					start, end = parent_plan.group.items[item_number]
					if opening < end:
						relative = max(0, base - _indent(view, tokens[start].line))
						base = bases[parent_open] + 1 + relative
		bases[opening] = base

	# Every key is exactly one gap between adjacent original tokens. Priority
	# resolves inherited indentation against the more specific child owner.
	gaps: dict[tuple[int, int], tuple[int, LayoutEdit]] = {}

	def put(start: int, end: int, replacement: str, plan: _Plan, priority: int) -> None:
		original = source[start:end]
		if original and not original.isspace():
			return
		key = start, end
		previous = gaps.get(key)
		if previous is None or priority > previous[0]:
			gaps[key] = priority, LayoutEdit(start, end, replacement, plan.rule)

	def rebase_item(start: int, end: int, target: int, plan: _Plan, priority: int) -> None:
		delta = target - _indent(view, tokens[start].line)
		if not delta:
			return
		for index in range(start + 1, end):
			token = tokens[index]
			line = view.lines[token.line - 1]
			if line[:token.column - 1].strip():
				continue
			left = tokens[index - 1]
			gap = source[left.end:token.start]
			if not gap or not gap.isspace() or "\n" not in gap:
				continue
			prefix, _newline, _indentation = gap.rpartition("\n")
			new_indent = max(0, _indent(view, token.line) + delta)
			put(left.end, token.start, prefix + "\n" + "\t" * new_indent, plan, priority)

	def join_atom_or_type(start: int, end: int, plan: _Plan, priority: int) -> None:
		if atom(start, end) is not None:
			join_end = end
		elif plan.kind == "parameters":
			# Join only the declaration prefix, not a default expression owned by
			# the scalar/group pass. A generic type may itself contain commas.
			default = next((i for i in range(start, end) if tokens[i].value == "="), end)
			join_end = min(end, default + 2)
		else:
			return
		for index in range(start, join_end - 1):
			left, right = tokens[index], tokens[index + 1]
			if "\n" in source[left.end:right.start]:
				put(left.end, right.start, _inline_separator(left, right), plan, priority)

	for opening, plan in sorted(plans.items()):
		if plan.layout == "preserve":
			continue
		group = plan.group
		opener, closer = tokens[opening], tokens[group.close_index]
		priority = plan.depth * 10
		expanded = plan.layout == "expanded"
		base = bases[opening]
		if not group.items:
			put(opener.end, closer.start, "", plan, priority + 5)
			continue
		for number, (start, end) in enumerate(group.items):
			if expanded:
				rebase_item(start, end, base + 1, plan, priority + 1)
			join_atom_or_type(start, end, plan, priority + 2)
			previous = opener if number == 0 else tokens[group.items[number - 1][1]]
			prefix = "\n" + "\t" * (base + 1) if expanded else (" " if number or plan.kind == "dictionary" else "")
			put(previous.end, tokens[start].start, prefix, plan, priority + 5)
			if end < group.close_index and tokens[end].value == ",":
				put(tokens[end - 1].end, tokens[end].start, "", plan, priority + 5)
		last = tokens[group.close_index - 1]
		final_comma = expanded and plan.kind in {"array", "dictionary"} and last.value != ","
		suffix = "\n" + "\t" * base if expanded else (" " if plan.kind == "dictionary" else "")
		put(last.end, closer.start, ("," if final_comma else "") + suffix, plan, priority + 5)

	edits = tuple(sorted(
		[edit for _priority, edit in gaps.values() if source[edit.start:edit.end] != edit.replacement]
		+ list(_annotation_binding_edits(view, plans)),
		key=lambda edit: (edit.start, edit.end),
	))
	for previous, current in zip(edits, edits[1:]):
		if previous.end > current.start:
			raise ValueError("List layout produced overlapping whitespace edits")
	return edits
