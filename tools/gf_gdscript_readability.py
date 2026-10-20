"""Deterministic, bounded formatting checks for GF-owned GDScript.

This module checks source layout, not runtime semantics. Tokens retain exact
source offsets so migration tools can consume this lexer without recognizing
the language independently. Comments and literal payloads never become code.
"""

from __future__ import annotations

import argparse
from collections import Counter
from collections.abc import Callable, Iterable
from dataclasses import dataclass, field, replace
from bisect import bisect_right
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
from typing import Any

from gdscript_api_parser import scan_gdscript_structure


SCHEMA_VERSION = 1
POLICY_VERSION = "1.1.0"
MAX_INLINE_LIST_ITEMS = 2
MAX_INLINE_DICTIONARY_FIELDS = MAX_INLINE_LIST_ITEMS
MAX_INLINE_CONDITION_TERMS = 2
MAX_INLINE_MIXED_CONDITION_TERMS = MAX_INLINE_CONDITION_TERMS
MAX_SOURCE_BYTES = 8 * 1024 * 1024
MAX_TOTAL_BYTES = 256 * 1024 * 1024
MAX_FILES = 20_000
MAX_ENTRIES = 100_000
MAX_TOKENS = 500_000
MAX_LINES = 100_000
MAX_GROUP_DEPTH = 128
MAX_ISSUES = 20_000
OWNED_ROOTS = ("addons/gf", "tests/gf_core")
SUFFIXES = (".gd", ".gd.txt", ".gdtemplate")
RULES = (
	"source_encoding", "source_budget", "source_unreadable", "source_identity",
	"template_contract", "lexical_closure", "text_format",
	"statement_separator", "inline_body", "dictionary_layout",
	"enum_layout",
	"condition_layout", "multiline_items", "closing_delimiter",
	"trailing_comma", "nested_ternary", "dictionary_spacing",
	"continuation_indentation", "member_access_spacing", "issue_budget",
	"section_spacing", "definition_spacing", "lambda_argument_separator",
	"simple_call_layout",
	"atomic_group_layout",
	"cast_layout",
	"argument_group_layout",
	"call_group_layout",
	"simple_string_layout",
	"simple_format_layout",
	"dictionary_entry_layout",
	"multi_argument_call_layout",
	"list_layout", "declaration_parameter_layout", "annotation_parameter_layout",
	"annotation_binding_layout", "expression_layout", "expression_group_layout",
	"index_layout", "chain_layout", "format_layout", "format_carrier",
	"token_spacing", "suite_indentation", "member_block_spacing",
	"member_doc_binding", "match_pattern_layout",
)
POLICY = {
	"version": POLICY_VERSION,
	"layout_basis": "syntax_structure",
	"max_inline_list_items": MAX_INLINE_LIST_ITEMS,
	"canonical_child_layout": "bottom_up_structure_not_existing_physical_newlines",
	"declaration_parameter_layout": "up_to_two_inline_unless_child_requires_expansion_three_or_more_direct_parameters_expanded",
	"annotation_parameter_layout": "flat_metadata_inline_distinct_from_call_parameters",
	"annotation_binding_layout": "one_field_annotation_attached_to_its_declaration_without_crossing_comments",
	"expression_layout": "single_complete_formula_or_ternary_inline_when_children_inline",
	"expression_group_layout": "remaining_multiline_groups_have_their_own_indent_and_close",
	"index_layout": "subscript_child_layout_without_container_comma",
	"chain_layout": "suffix_attached_to_its_receiver_close",
	"complex_format_layout": "template_inline_percent_next_line_array_uses_its_own_layout",
	"complex_format_scalar_scope": "scalar_expression_inline_when_children_inline",
	"complex_format_unknown_template_type": "ordinary_expression_without_type_guessing",
	"nested_ternary_keyword_names": "shared_member_and_node_path_roles",
	"suite_indentation": "one_tab_per_direct_body_owner",
	"member_block_spacing": "documented_data_members_one_blank_undocumented_single_line_members_none_definitions_and_sections_take_priority",
	"token_spacing": "syntactic_roles_preserve_unary_node_paths_types_patterns_and_literals",
	"match_pattern_layout": "existing_multiline_arm_one_direct_pattern_per_line_with_necessary_markers",
	"max_inline_dictionary_fields": MAX_INLINE_DICTIONARY_FIELDS,
	"max_inline_condition_terms": MAX_INLINE_CONDITION_TERMS,
	"max_inline_mixed_condition_terms": MAX_INLINE_MIXED_CONDITION_TERMS,
	"condition_layout_scope": "complete_boolean_expression_domains_including_headers_values_items_defaults_and_ternary_slots",
	"condition_layout_headers": ("if", "elif", "while", "match_subject", "match_when", "for_iterable"),
	"condition_layout_expression_boundaries": ("complete_group", "call_argument", "annotation_argument", "array_item", "index_item", "dictionary_key", "dictionary_value", "parameter_default", "assignment", "compound_assignment", "return", "expression_statement", "ternary_slot"),
	"condition_layout_preserve_precedence_groups_and_operator_order": True,
	"condition_layout_new_groups": "only_complete_domain_without_a_continuation_carrier",
	"condition_layout_all_existing_boolean_layers_expanded": True,
	"condition_layout_keyword_member_delimiters": "actual_call_or_index_in_boolean_scope_only",
	"condition_layout_statement_role_closure_rounds": 2,
	"condition_layout_index_lambda_body_proof": True,
	"condition_layout_migration_barriers": ("comment", "explicit_continuation", "multiline_literal", "lambda", "cast", "await", "unproven_domain"),
	"nested_nonempty_containers_expanded": True,
	"inline_bodies_allowed": False,
	"multiple_statements_allowed": False,
	"multiline_items_per_line": 1,
	"multiline_closing_layers_per_line": 1,
	"multiline_container_final_comma": True,
	"enum_members_expanded": True,
	"enum_final_comma_required": False,
	"member_section_blank_lines_before": 2,
	"member_section_blank_lines_after": 1,
	"adjacent_definition_blank_lines": 2,
	"nested_call_multiline_lambda_final_comma": True,
	"lambda_body_restarts_expression_context": True,
	"dictionary_value_lambda_body_context": True,
	"dictionary_lua_style_value_lambda_body_context": True,
	"lambda_header_continuation_markers": True,
	"member_name_adjacent_to_dot": True,
	"required_expression_group_layers_indented": True,
	"simple_call_layout": "single_line_for_zero_or_one_atomic_argument",
	"simple_call_callee": "identifier_or_member_chain",
	"simple_call_atomic_argument": "literal_identifier_member_chain_empty_container_or_one_unary_with_redundant_groups",
	"simple_call_layout_barriers": ("comment", "explicit_continuation", "multiline_literal", "complex_receiver"),
	"dictionary_entry_layout": "single_line_key_separator_and_value_start_preserving_value_structure",
	"dictionary_entry_separators": (":", "="),
	"dictionary_entry_keys": "any_complete_single_physical_line_expression",
	"dictionary_entry_layout_barriers": ("multiline_key", "comment_between_key_and_value_start", "explicit_continuation_between_key_and_value_start", "multiline_value_start_literal"),
	"multi_argument_call_layout": "single_line_for_exactly_two_atomic_arguments_otherwise_expanded",
	"multi_argument_call_scope": "direct_argument_region_of_nonannotation_call_groups_or_proven_member_calls_with_at_least_two_arguments",
	"multi_argument_call_atomic_argument": "shared_simple_call_atomic_definition",
	"multi_argument_call_layout_barriers": ("comment", "explicit_continuation", "multiline_literal"),
	"multi_argument_call_preserve_complex_receiver": True,
	"multi_argument_call_proven_member_groups_use_existing_call_layout_checks": True,
	"layout_barriers_preserve_existing_item_and_closing_checks": True,
	"multiline_call_closing_suffix": "finite_expression_operator_or_ternary_or_postfix_with_operand_start_proof_and_bounded_cast_prefix",
	"multiline_call_closing_suffix_keeps_other_expanded_closings_separate": True,
	"atomic_group_layout": "single_line_for_one_atomic_expression",
	"atomic_group_layout_barriers": ("comment", "explicit_continuation", "multiline_literal"),
	"cast_layout": "as_type_attached_to_operand_close",
	"cast_types": "nominal_qualified_or_flat_typed_array_dictionary",
	"cast_redundant_groups": "direct_call_operand_and_complete_statement_value_or_call_argument",
	"cast_group_removal_barriers": ("comment", "explicit_continuation", "multiline_literal", "lambda", "complex_receiver", "operator_operand", "receiver_suffix"),
	"argument_group_layout": "remove_whole_multiline_non_atomic_call_argument_groups",
	"argument_group_scope": "complete_direct_call_argument_and_complete_group_wrapper_chain",
	"argument_group_layout_barriers": ("comment", "explicit_continuation", "multiline_literal", "lambda", "conditional_expression", "cast", "await"),
	"argument_group_condition_scope": "current_expression_outside_complete_inner_array_dictionary",
	"argument_group_condition_sealing_groups": ("array", "dictionary"),
	"argument_group_preserve_inner_precedence": True,
	"argument_group_preserve_complete_boolean_carriers_min_terms": MAX_INLINE_CONDITION_TERMS + 1,
	"call_group_layout": "remove_whole_assignment_or_return_groups_around_plain_calls",
	"call_group_callee": "identifier_or_member_chain",
	"call_group_scope": "complete_assignment_or_return_statement_including_proven_lambda_body",
	"call_group_layout_barriers": ("comment_on_wrapper_boundary_or_inside", "explicit_continuation", "multiline_literal", "lambda", "conditional_expression", "cast", "await", "complex_receiver", "operator_operand", "receiver_suffix"),
	"simple_string_layout": "single_line_for_complete_flat_string_addition_chain",
	"simple_string_min_operands": 2,
	"simple_string_anchor": "at_least_one_single_physical_line_ordinary_or_raw_string_literal",
	"simple_string_operands": "string_literal_identifier_member_chain_or_groups_around_one_atom",
	"simple_string_expression_boundaries": ("complete_group", "call_argument", "array_item", "dictionary_key", "dictionary_value", "assignment", "return", "parameter_default"),
	"simple_string_layout_barriers": ("comment_on_boundary_line_or_inside", "explicit_continuation", "multiline_literal", "call", "index", "cast", "await", "lambda", "conditional_expression", "numeric_or_nonstring_literal"),
	"simple_string_preserve_tokens_and_grouping": True,
	"simple_format_layout": "single_line_for_complete_string_format_with_one_scalar_operand",
	"simple_format_left_operand": "single_physical_line_ordinary_or_raw_string_literal_with_atomic_groups",
	"simple_format_right_operand": "ordinary_string_number_boolean_null_identifier_member_chain_or_one_unary_with_atomic_groups",
	"simple_format_expression_boundaries": ("complete_group", "call_argument", "array_item", "dictionary_key", "dictionary_value", "assignment", "return", "parameter_default"),
	"simple_format_single_argument_call": "join_complete_identifier_or_member_chain_call",
	"simple_format_call_callee": "identifier_or_member_chain_excluding_node_reference_shorthand",
	"simple_format_layout_barriers": ("comment_on_boundary_line_or_inside", "explicit_continuation", "multiline_literal", "nonstring_literal_prefix", "container", "call_or_index_operand", "cast", "await", "lambda", "conditional_expression", "other_operator", "complex_receiver_for_whole_call"),
	"simple_format_preserve_tokens_and_grouping": True,
	"owned_roots": OWNED_ROOTS,
	"suffixes": SUFFIXES,
	"rules": RULES,
}
POLICY_SHA256 = hashlib.sha256(
	json.dumps(POLICY, sort_keys=True, separators=(",", ":")).encode("utf-8")
).hexdigest()
_OPEN = {"(": ")", "[": "]", "{": "}"}
_CLOSE = {value: key for key, value in _OPEN.items()}
_OPERATORS = ("**=", "<<=", ">>=", "->", ":=", "==", "!=", "<=", ">=",
			  "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "**", "<<", ">>", "&&", "||")
_OPERATORS_BY_INITIAL = {
	initial: tuple(value for value in _OPERATORS if value[0] == initial)
	for initial in {value[0] for value in _OPERATORS}
}
_CONTROL = {"if", "elif", "else", "for", "while", "match"}
_NUMBER = re.compile(r"(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|[0-9_]+(?:\.[0-9_]+)?(?:[eE][+-]?[0-9_]+)?)")
_FATAL = {"source_encoding", "source_budget", "source_unreadable", "source_identity",
		  "template_contract", "lexical_closure", "issue_budget"}


@dataclass(frozen=True)
class Token:
	"""One exact token; offsets are zero-based, line and column are one-based."""

	kind: str
	value: str
	start: int
	end: int
	line: int
	column: int
	end_line: int
	end_column: int


@dataclass(frozen=True)
class Group:
	"""Balanced delimiter and its direct comma-delimited token spans."""

	open_index: int
	close_index: int
	kind: str
	parent_index: int | None
	items: tuple[tuple[int, int], ...]


@dataclass(frozen=True)
class LexedSource:
	"""Immutable lexical view, shared by checks and mechanical migrations."""

	source: str
	lines: tuple[str, ...]
	tokens: tuple[Token, ...]
	comments: tuple[Token, ...]
	groups: tuple[Group, ...]
	issues: tuple[dict[str, Any], ...]
	_analysis: _SourceAnalysis | None = field(default=None, repr=False, compare=False, kw_only=True)


class _SourceAnalysis:
	"""Own derived views only for one audit; close even when a rule raises."""

	def __init__(self) -> None:
		self._views: dict[int, tuple[LexedSource, dict[tuple[str, tuple[int, ...]], Any]]] = {}
		self._closed = False

	def resolve(self, view: LexedSource, key: tuple[str, tuple[int, ...]], build: Callable[[], Any]) -> Any:
		if self._closed:
			return build()
		identity = id(view)
		entry = self._views.get(identity)
		if entry is None:
			# Retain the identity owner until close, so an id cannot be reused.
			entry = view, {}
			self._views[identity] = entry
		values = entry[1]
		if key not in values:
			# None is a completed, fail-closed result; exceptions publish nothing.
			values[key] = build()
		return values[key]

	def close(self) -> None:
		self._closed = True
		# Views and matcher inputs may refer back to this invocation owner.
		self._views.clear()


def _analysis_result(view: LexedSource, name: str, build: Callable[[], Any]) -> Any:
	analysis = view._analysis
	if analysis is None:
		return build()
	policy = (
		MAX_INLINE_LIST_ITEMS, MAX_INLINE_DICTIONARY_FIELDS,
		MAX_INLINE_CONDITION_TERMS, MAX_INLINE_MIXED_CONDITION_TERMS, MAX_GROUP_DEPTH,
	)
	return analysis.resolve(view, (name, policy), build)


@dataclass(frozen=True)
class SimpleCallLayoutSpan:
	"""One structurally simple call; token and source ranges are half-open.

	The callee range ends before its opening parenthesis. The complete source
	range includes any callee continuation and the closing parenthesis. Existing
	grouping parentheses and an optional argument comma remain part of the span.
	"""

	callee_start_index: int
	callee_end_index: int
	open_index: int
	close_index: int
	argument_start_index: int | None
	argument_end_index: int | None
	start: int
	end: int
	line: int
	end_line: int


@dataclass(frozen=True)
class DictionaryEntryLayoutSpan:
	"""A dictionary field's key, separator and first value token.

	Token and source ranges are half-open. The source range stops after the
	first value token, so joining this header cannot flatten a call, container
	or another expression within the value. Physical barriers remain observable
	but must not be migrated or exempt the value's independent layout checks.
	"""

	dictionary_open_index: int
	key_start_index: int
	key_end_index: int
	separator_index: int
	value_start_index: int
	value_end_index: int
	start: int
	end: int
	line: int
	end_line: int
	migration_safe: bool
	barriers: tuple[str, ...]


@dataclass(frozen=True)
class MultiArgumentCallLayoutSpan:
	"""One call's argument region, independent of its receiver expression.

	The source range includes only the call parentheses and their contents;
	Argument token ranges are half-open and exclude their separator commas;
	optional commas remain within the complete source range.
	Exactly two atomic arguments use inline layout; other multiple-argument
	calls use expanded layout. Barriers preserve physical structure, while existing
	item, indentation and closing-delimiter checks still apply independently.
	"""

	open_index: int
	close_index: int
	items: tuple[tuple[int, int], ...]
	expected_layout: str
	start: int
	end: int
	line: int
	end_line: int
	migration_safe: bool
	barriers: tuple[str, ...]


@dataclass(frozen=True)
class AtomicGroupLayoutSpan:
	"""A parenthesized atom, retaining every token in a half-open source range."""

	open_index: int
	close_index: int
	start: int
	end: int
	line: int
	end_line: int


@dataclass(frozen=True)
class SimpleStringLayoutSpan:
	"""A complete literal-anchored string addition chain, retaining every token.

	Source and token ranges are half-open. A complete grouped expression includes
	all its parentheses; group_open_index names its outermost group, if present.
	Consumers join only whitespace and preserve literal spelling and grouping.
	"""

	start_index: int
	end_index: int
	start: int
	end: int
	line: int
	end_line: int
	group_open_index: int | None = None


@dataclass(frozen=True)
class SimpleFormatLayoutSpan:
	"""One complete simple format expression, or its single-argument plain call.

	Token and source ranges are half-open. Context distinguishes an expression
	from a whole call, including its callee and any existing argument comma.
	Nested spans may overlap; joining whitespace never changes their tokens.
	"""

	start_index: int
	end_index: int
	start: int
	end: int
	line: int
	end_line: int
	context: str


@dataclass(frozen=True)
class BooleanLayoutSpan:
	"""A complete Boolean domain requiring expansion, including canonical source.

	Ranges are half-open and retain all original tokens. Operators belong only to
	this domain; calls, containers and ternary slots have independent domains.
	The carrier is an existing delimiter. A proven statement cannot borrow its
	enclosing lambda's call delimiter. Unsafe spans remain observable diagnostics.
	"""

	start_index: int
	end_index: int
	start: int
	end: int
	line: int
	end_line: int
	context: str
	term_count: int
	operator_indexes: tuple[int, ...]
	layer_group_open_indexes: tuple[int, ...]
	carrier_open_index: int | None
	needs_outer_group: bool
	migration_safe: bool
	barriers: tuple[str, ...]


@dataclass(frozen=True)
class ArgumentGroupLayoutSpan:
	"""One redundant whole-argument group within an existing call.

	Source ranges are half-open and include this layer's two parentheses. The
	call index names the original parameter owner, including for inner layers
	of a complete wrapper chain. Consumers may remove only these delimiters;
	partial operand groups and every token inside them remain unchanged.
	"""

	call_open_index: int
	open_index: int
	close_index: int
	start: int
	end: int
	line: int
	end_line: int


@dataclass(frozen=True)
class CallGroupLayoutSpan:
	"""A complete assignment/return wrapper around one ordinary call.

	Source ranges are half-open and include this layer's parentheses. The call
	and callee indexes identify retained tokens; removing a wrapper never removes
	call delimiters or changes the left-hand side of the assignment.
	"""

	context: str
	call_open_index: int
	callee_start_index: int
	open_index: int
	close_index: int
	start: int
	end: int
	line: int
	end_line: int


@dataclass(frozen=True)
class CastLayoutSpan:
	"""A bounded cast suffix and the exact direct-call groups proven redundant.

	Source/token ranges are half-open. Group open indexes name existing balanced
	par_expr layers, never call delimiters. Attachment preserves every token;
	group removal also requires semantic proof from the migration consumer.
	"""

	start_index: int
	end_index: int
	start: int
	end: int
	operand_close_index: int
	cast_index: int
	type_start_index: int
	type_end_index: int
	attachment_allowed: bool
	call_open_index: int | None
	callee_start_index: int | None
	redundant_operand_group_open_indexes: tuple[int, ...]
	redundant_cast_group_open_indexes: tuple[int, ...]


def _issue(path: str, rule: str, line: int, column: int, message: str,
		   suggestion: str = "") -> dict[str, Any]:
	return {
		"rule": rule,
		"kind": rule,
		"path": path,
		"line": line,
		"column": column,
		"message": message,
		"suggestion": suggestion,
	}


def _template_view(path: str, source: str) -> tuple[str, list[int] | None]:
	"""Instantiate the existing controlled template contract with an offset map.

    The existing comment-contract helper uses these literal substitutions and
    an enclosing function for the integration snippet. Layout does not require
    that synthetic function; leaving the snippet unwrapped preserves positions.
    No template content is removed or exempted from any formatting rule.
    """
	replacements: dict[str, str] = {}
	if path == "addons/gf/tools/config_pipeline/templates/read_config.gd.txt":
		replacements = {
			"{DatabasePath}": '"res://comment_contract_fixture.tres"',
			"{TableName}": '"comment_contract_fixture"',
		}
	native_templates = {
		(
			"addons/gf/standard/state_machine/node/editor/templates/"
			"node_state.gdtemplate"
		): "GFNodeState",
		(
			"addons/gf/standard/state_machine/node/editor/templates/"
			"node_state_machine.gdtemplate"
		): "GFNodeStateMachine",
	}
	if path in native_templates:
		replacements = {
			"{ClassName}": "GFTemplateFixture",
			"{BaseClass}": native_templates[path],
		}
	if path.endswith(".gd.txt"):
		replacements["__ROOT__"] = "res://comment_contract_fixture"
	if not any(placeholder in source for placeholder in replacements):
		return source, None
	pattern = re.compile("|".join(re.escape(placeholder) for placeholder in replacements))
	parts: list[str] = []
	mapping: list[int] = []
	start = 0
	for match in pattern.finditer(source):
		parts.append(source[start:match.start()])
		mapping.extend(range(start, match.start()))
		replacement = replacements[match.group()]
		parts.append(replacement)
		mapping.extend([match.start()] * len(replacement))
		start = match.end()
	parts.append(source[start:])
	mapping.extend(range(start, len(source)))
	mapping.append(len(source))
	return "".join(parts), mapping


def render_template(path: str, source: str) -> str:
	"""Return the controlled lexical instance, preserving every original line."""
	return _template_view(path, source)[0]


def lex_source(path: str, text: str) -> LexedSource:
	"""Tokenize without executing source, preserving literals and comments."""
	issues: list[dict[str, Any]] = []
	try:
		encoded = text.encode("utf-8", errors="strict")
	except UnicodeEncodeError:
		return LexedSource(text, (), (), (), (), (
			_issue(path, "source_encoding", 1, 1, "Source is not strict UTF-8."),
		))
	if len(encoded) > MAX_SOURCE_BYTES:
		return LexedSource(text, (), (), (), (), (
			_issue(path, "source_budget", 1, 1, "Source exceeds the byte budget."),
		))
	if text.count("\n") > MAX_LINES:
		return LexedSource(text, (), (), (), (), (
			_issue(path, "source_budget", 1, 1, "Source line budget exhausted."),
		))
	source, offset_map = _template_view(path, text)
	lines = tuple(source.removesuffix("\n").split("\n")) if source else ()
	tokens: list[Token] = []
	comments: list[Token] = []
	position = 0
	line = 1
	column = 1
	original_line_starts = [0]
	original_line_starts.extend(index + 1 for index, value in enumerate(text) if value == "\n")

	def advance(end: int) -> None:
		nonlocal position, line, column
		part = source[position:end]
		count = part.count("\n")
		if count:
			line += count
			column = len(part.rsplit("\n", 1)[1]) + 1
		else:
			column += len(part)
		position = end

	def emit(kind: str, end: int) -> None:
		start, start_line, start_column = position, line, column
		original_start = offset_map[start] if offset_map is not None else start
		original_end = offset_map[end] if offset_map is not None else end
		value = text[original_start:original_end]
		advance(end)
		if offset_map is not None:
			start_line = bisect_right(original_line_starts, original_start)
			start_column = original_start - original_line_starts[start_line - 1] + 1
			end_line = bisect_right(original_line_starts, original_end)
			end_column = original_end - original_line_starts[end_line - 1] + 1
		else:
			end_line, end_column = line, column
		token = Token(kind, value, original_start, original_end, start_line, start_column, end_line, end_column)
		(comments if kind == "comment" else tokens).append(token)

	while position < len(source):
		character = source[position]
		if character.isspace():
			advance(position + 1)
			continue
		if character == "#":
			end = source.find("\n", position)
			emit("comment", len(source) if end < 0 else end)
			continue
		quote_start = position
		if character in "r&^$" and position + 1 < len(source) and source[position + 1] in "\"'":
			quote_start += 1
		if source[quote_start] in "\"'":
			quote = source[quote_start]
			delimiter = quote * 3 if source.startswith(quote * 3, quote_start) else quote
			end = quote_start + len(delimiter)
			closed = False
			while end < len(source):
				if source[end] == "\\":
					end += 2
					continue
				if source.startswith(delimiter, end):
					end += len(delimiter)
					closed = True
					break
				if len(delimiter) == 1 and source[end] in "\r\n":
					break
				end += 1
			if not closed:
				issues.append(_issue(path, "lexical_closure", line, column,
									 "String literal is not closed."))
				break
			emit("string", end)
		elif character.isalpha() or character == "_":
			end = position + 1
			while end < len(source) and ("_" + source[end]).isidentifier():
				end += 1
			emit("identifier", end)
		elif character.isdigit():
			match = _NUMBER.match(source, position)
			emit("number", position + len(match.group()) if match else position + 1)
		else:
			operator = next(
				(value for value in _OPERATORS_BY_INITIAL.get(character, ())
				 if source.startswith(value, position)),
				character,
			)
			emit("symbol", position + len(operator))
		if len(tokens) > MAX_TOKENS:
			issues.append(_issue(path, "source_budget", line, column, "Token budget exhausted."))
			break
	groups: list[Group] = []
	stack: list[tuple[int, int | None, int]] = []
	staged: list[Group | None] = []
	for index, token in enumerate(tokens):
		if token.value == "\\" and token.kind == "symbol":
			if index + 1 >= len(tokens) or tokens[index + 1].line != token.line + 1:
				issues.append(_issue(path, "lexical_closure", token.line, token.column,
								 "A continuation backslash must end a continued physical line."))
		if token.value in _OPEN and token.kind == "symbol":
			if len(stack) >= MAX_GROUP_DEPTH:
				issues.append(_issue(path, "source_budget", token.line, token.column,
									 "Delimiter depth budget exhausted."))
				break
			group_index = len(staged)
			staged.append(None)
			parent = stack[-1][2] if stack else None
			stack.append((index, parent, group_index))
		elif token.value in _CLOSE and token.kind == "symbol":
			if not stack or tokens[stack[-1][0]].value != _CLOSE[token.value]:
				issues.append(_issue(path, "lexical_closure", token.line, token.column,
									 "Closing delimiter does not match its opener."))
				break
			opening, parent, group_index = stack.pop()
			kind = _group_kind(tokens, opening)
			depth = 0
			starts = opening + 1
			items: list[tuple[int, int]] = []
			for cursor in range(opening + 1, index):
				value = tokens[cursor].value if tokens[cursor].kind == "symbol" else ""
				if value in _OPEN:
					depth += 1
				elif value in _CLOSE:
					depth -= 1
				elif value == "," and depth == 0:
					if starts < cursor:
						items.append((starts, cursor))
					starts = cursor + 1
			if starts < index:
				items.append((starts, index))
			staged[group_index] = Group(opening, index, kind, parent, tuple(items))
	if stack:
		token = tokens[stack[0][0]]
		issues.append(_issue(path, "lexical_closure", token.line, token.column,
							 "Opening delimiter remains unclosed."))
	if not issues:
		groups = [group for group in staged if group is not None]
	if path.endswith((".gd.txt", ".gdtemplate")):
		for index in range(len(tokens) - 2):
			if tokens[index].value == "{" and tokens[index + 1].kind == "identifier" and tokens[index + 2].value == "}":
				issues.append(_issue(path, "template_contract", tokens[index].line,
									 tokens[index].column, "Unknown template placeholder."))
	original_lines = tuple(text.removesuffix("\n").split("\n")) if text else ()
	return LexedSource(text, original_lines, tuple(tokens), tuple(comments),
					   tuple(groups), tuple(issues))


def _group_kind(tokens: list[Token] | tuple[Token, ...], opening: int, *, names: set[int] | None = None) -> str:
	value = tokens[opening].value
	previous = tokens[opening - 1] if opening else None
	if value == "{":
		keyword = opening - 1
		if previous is not None and previous.kind == "identifier" and previous.value != "enum":
			keyword -= 1
		if (
			keyword >= 0
			and tokens[keyword].kind == "identifier"
			and tokens[keyword].value == "enum"
			and (keyword == 0 or tokens[keyword - 1].end_line < tokens[keyword].line)
		):
			return "enum"
		return "dictionary"
	if value == "[":
		if previous and ((previous.kind in {"identifier", "string", "number"}
						  and previous.value not in {"return", "in", "not", "and", "or", "else", "if", "elif", "while"})
						 or previous.value in _CLOSE):
			return "index"
		return "array"
	if previous and previous.kind == "identifier":
		if (
			previous.value == "func" and (names is None or opening - 1 not in names)
			or (
				opening >= 2 and tokens[opening - 2].value in {"func", "signal"}
				and (names is None or opening - 2 not in names)
			)
		):
			return "parameters"
		grouping_keywords = {
			"if", "elif", "else", "while", "match", "return", "await",
			"assert", "not", "and", "or", "in",
		}
		if previous.value not in grouping_keywords:
			return "call"
		if previous.value == "assert":
			return "call"
	if previous and previous.value in _CLOSE:
		return "call"
	return "group"


def _atomic_layout_inputs(view: LexedSource) -> tuple[dict[int, Group], tuple[int, ...], tuple[int, ...]]:
	group_by_open = {group.open_index: group for group in view.groups}
	comment_starts = tuple(comment.start for comment in view.comments)
	barrier_prefix = [0]
	for token in view.tokens:
		barrier_prefix.append(barrier_prefix[-1] + int(
			token.value == "\\"
			or (token.kind == "string" and token.line != token.end_line)
		))
	return group_by_open, comment_starts, tuple(barrier_prefix)


def _atomic_layout_matcher(view: LexedSource) -> tuple[
	Callable[[int], bool], Callable[[int, int], int | None], Callable[[int, int], bool],
]:
	"""Share bounded atom and physical-boundary matching across layout rules.

	Atoms are single-line literals, identifiers, member chains, empty containers,
	or one unary operator over an atom. Parentheses may wrap the atom without
	adding complexity. Calls, indexing and other expressions are not atoms.
	Comments, explicit continuation markers and multiline literals preserve
	physical structure. No column or name length participates in this decision.
	"""
	tokens = view.tokens
	group_by_open, comment_starts, barrier_prefix = _analysis_result(
		view, "atomic_inputs", lambda: _atomic_layout_inputs(view),
	)
	reserved = {
		"func", "if", "elif", "else", "for", "while", "match", "return",
		"var", "const", "signal", "enum", "class", "class_name", "extends",
		"static", "await", "and", "or", "in", "is", "as", "not", "pass",
		"break", "continue", "breakpoint", "yield",
	}
	unary = {"+", "-", "~", "not", "!"}
	atom_cache: dict[tuple[int, int], int | None] = {}

	def identifier(index: int) -> bool:
		return tokens[index].kind == "identifier" and (
			tokens[index].value not in reserved
			or (index > 0 and tokens[index - 1].kind == "symbol" and tokens[index - 1].value == ".")
		)

	def atom_unary_count(start: int, end: int, depth: int = 0) -> int | None:
		key = (start, end)
		if key in atom_cache:
			return atom_cache[key]
		if start >= end or depth > MAX_GROUP_DEPTH:
			return None
		result: int | None = None
		first = tokens[start]
		if first.value in unary:
			child_count = atom_unary_count(start + 1, end, depth + 1)
			if child_count == 0:
				result = 1
		elif end == start + 1:
			if first.kind in {"number", "string"} or identifier(start):
				result = 0
		else:
			group = group_by_open.get(start)
			if group is not None and group.close_index == end - 1:
				if group.kind in {"array", "dictionary"} and group.open_index + 1 == group.close_index:
					result = 0
				elif (
					group.kind == "group" and len(group.items) == 1
					and tokens[group.close_index - 1].value != ","
				):
					result = atom_unary_count(*group.items[0], depth + 1)
			elif identifier(start):
				cursor = start + 1
				while cursor < end and cursor + 1 < end and tokens[cursor].value == "." and identifier(cursor + 1):
					cursor += 2
				if cursor == end:
					result = 0
		atom_cache[key] = result
		return result

	def barrier_free(start: int, end: int) -> bool:
		if barrier_prefix[end] != barrier_prefix[start]:
			return False
		comment_index = bisect_right(comment_starts, tokens[start].start - 1)
		return (
			comment_index == len(comment_starts)
			or comment_starts[comment_index] >= tokens[end - 1].end
		)

	return identifier, atom_unary_count, barrier_free


def atomic_group_layout_spans(view: LexedSource) -> tuple[AtomicGroupLayoutSpan, ...]:
	"""Find groups containing one atom, preserving complex surrounding structure."""
	if view.issues:
		return ()
	_identifier, atom_unary_count, barrier_free = _atomic_layout_matcher(view)
	spans: list[AtomicGroupLayoutSpan] = []
	for group in view.groups:
		if group.kind != "group":
			continue
		if atom_unary_count(group.open_index, group.close_index + 1) is None:
			continue
		if not barrier_free(group.open_index, group.close_index + 1):
			continue
		opener, closer = view.tokens[group.open_index], view.tokens[group.close_index]
		spans.append(AtomicGroupLayoutSpan(
			group.open_index, group.close_index, opener.start, closer.end,
			opener.line, closer.end_line,
		))
	return tuple(spans)


def simple_call_layout_spans(view: LexedSource) -> tuple[SimpleCallLayoutSpan, ...]:
	"""Find zero/one-atom calls, retaining complex receivers and physical barriers."""
	if view.issues:
		return ()
	tokens = view.tokens
	identifier, atom_unary_count, barrier_free = _atomic_layout_matcher(view)
	callee_cache: dict[int, int | None] = {}

	def callee_start(opening: int) -> int | None:
		if opening in callee_cache:
			return callee_cache[opening]
		cursor = opening - 1
		result: int | None = None
		if cursor >= 0 and identifier(cursor):
			while cursor >= 2 and tokens[cursor - 1].value == "." and identifier(cursor - 2):
				cursor -= 2
			if cursor == 0 or tokens[cursor - 1].value != ".":
				result = cursor
		callee_cache[opening] = result
		return result

	spans: list[SimpleCallLayoutSpan] = []
	for group in view.groups:
		if group.kind != "call" or len(group.items) > 1:
			continue
		start = callee_start(group.open_index)
		if start is None:
			continue
		if not barrier_free(start, group.close_index + 1):
			continue
		opener, closer = tokens[group.open_index], tokens[group.close_index]
		argument_start: int | None = None
		argument_end: int | None = None
		if group.items:
			argument_start, argument_end = group.items[0]
			if argument_start != group.open_index + 1 or atom_unary_count(argument_start, argument_end) is None:
				continue
		elif group.open_index + 1 != group.close_index:
			continue
		spans.append(SimpleCallLayoutSpan(
			start, group.open_index, group.open_index, group.close_index,
			argument_start, argument_end, tokens[start].start, closer.end,
			tokens[start].line, closer.end_line,
		))
	return tuple(spans)


def _entry_call_physical_barriers(view: LexedSource) -> Callable[[int, int], tuple[str, ...]]:
	"""Index physical boundaries for the two structural entry/call rules only."""
	tokens = view.tokens
	comment_starts = tuple(comment.start for comment in view.comments)
	continuations = [0]
	multiline_literals = [0]
	for token in tokens:
		continuations.append(continuations[-1] + int(token.value == "\\"))
		multiline_literals.append(multiline_literals[-1] + int(
			token.kind == "string" and token.line != token.end_line
		))

	def barriers(start: int, end: int) -> tuple[str, ...]:
		result: list[str] = []
		comment_index = bisect_right(comment_starts, tokens[start].start - 1)
		if comment_index < len(comment_starts) and comment_starts[comment_index] < tokens[end - 1].end:
			result.append("comment")
		if continuations[end] != continuations[start]:
			result.append("explicit_continuation")
		if multiline_literals[end] != multiline_literals[start]:
			result.append("multiline_literal")
		return tuple(result)

	return barriers


def dictionary_entry_layout_spans(view: LexedSource) -> tuple[DictionaryEntryLayoutSpan, ...]:
	"""Find dictionary headers without flattening any value's child structure.

	Only a direct colon/equal sign separates the key and value. A complete
	single-line dynamic key is eligible just like a literal key; nested groups
	are skipped while finding that separator. A multiline key or a physical
	barrier in the local header preserves its original layout.
	"""
	if view.issues:
		return ()
	tokens = view.tokens
	group_by_open = {group.open_index: group for group in view.groups}
	physical_barriers = _entry_call_physical_barriers(view)
	spans: list[DictionaryEntryLayoutSpan] = []
	for group in view.groups:
		if group.kind != "dictionary":
			continue
		for start, end in group.items:
			cursor = start
			separator: int | None = None
			while cursor < end:
				child = group_by_open.get(cursor)
				if child is not None:
					cursor = child.close_index + 1
				elif tokens[cursor].kind == "symbol" and tokens[cursor].value in {":", "="}:
					separator = cursor
					break
				else:
					cursor += 1
			if separator is None or separator == start or separator + 1 >= end:
				continue
			value_start = separator + 1
			barriers = physical_barriers(start, value_start + 1)
			if tokens[start].line != tokens[separator - 1].end_line:
				barriers = ("multiline_key",) + barriers
			spans.append(DictionaryEntryLayoutSpan(
				group.open_index, start, separator, separator, value_start, end,
				tokens[start].start, tokens[value_start].end,
				tokens[start].line, tokens[value_start].end_line,
				not barriers, barriers,
			))
	return tuple(spans)


def multi_argument_call_layout_spans(view: LexedSource) -> tuple[MultiArgumentCallLayoutSpan, ...]:
	"""Classify only a call's two-or-more direct arguments by structure.

	The receiver is outside this rule's source range, so complex receivers are
	retained. An adjacent dot and member name prove a member call even where the
	shared lexer treats a keyword-shaped member as parameters or grouping.
	Annotation and declaration parameter groups do not enter the call policy.
	"""
	if view.issues:
		return ()
	tokens = view.tokens
	_identifier, atom_unary_count, _barrier_free = _atomic_layout_matcher(view)
	physical_barriers = _entry_call_physical_barriers(view)
	spans: list[MultiArgumentCallLayoutSpan] = []
	for group in view.groups:
		opening = group.open_index
		if len(group.items) < 2:
			continue
		if opening >= 2 and tokens[opening - 2].value == "@":
			continue
		member_call = (
			opening >= 2 and tokens[opening - 1].kind == "identifier"
			and tokens[opening - 2].value == "."
		)
		if group.kind != "call" and not member_call:
			continue
		opener, closer = tokens[opening], tokens[group.close_index]
		inline = len(group.items) <= MAX_INLINE_LIST_ITEMS and all(
			atom_unary_count(start, end) is not None for start, end in group.items
		)
		barriers = physical_barriers(opening, group.close_index + 1)
		spans.append(MultiArgumentCallLayoutSpan(
			opening, group.close_index, group.items,
			"inline" if inline else "expanded", opener.start, closer.end,
			opener.line, closer.end_line, not barriers, barriers,
		))
	return tuple(spans)


def argument_group_layout_spans(view: LexedSource) -> tuple[ArgumentGroupLayoutSpan, ...]:
	"""Find only complete multiline argument wrappers with no scope barriers.

	A call already supplies continuation delimiters for its arguments. Removing
	an entire argument wrapper does not change its internal operator precedence.
	Direct item boundaries are essential: a lambda body's independent statements
	must never be mistaken for the enclosing call's complete argument. All layers
	inherit barriers from the original full parameter, so a nested wrapper cannot
	bypass a comment, lambda, cast or await elsewhere in that value. A complete
	inner array or dictionary seals its own conditions; conditions in the current
	expression, including inside a call or index, still preserve the wrapper.
	An existing whole three-or-more-term Boolean argument group remains a valid
	logic layer; a complex Boolean expression inside a child call/container does
	not make its ordinary outer wrapper a Boolean continuation carrier.

	Prefix counts, one delimiter-stack pass and indexed group lookup avoid
	rescanning candidate contents. A container blocks propagation only to its
	parent, retaining each child's own condition flag for independent checks.
	The wrapper walk is bounded by the lexer's existing delimiter depth limit.
	"""
	if view.issues:
		return ()
	tokens, groups = view.tokens, view.groups
	by_open = {group.open_index: group for group in groups}
	_identifier, atom_unary_count, barrier_free = _atomic_layout_matcher(view)
	comment_lines = {comment.line for comment in view.comments}
	boolean_carriers = {
		(span.start_index, span.end_index) for span in boolean_layout_spans(view)
	}
	scope_prefix = [0]
	exposed_conditions: set[int] = set()
	condition_stack: list[Group] = []
	for index, token in enumerate(tokens):
		scope_prefix.append(scope_prefix[-1] + int(
			token.kind == "identifier" and token.value in {"func", "as", "await"}
		))
		opening = by_open.get(index)
		if opening is not None:
			condition_stack.append(opening)
		elif token.kind == "identifier" and token.value in {"if", "else"}:
			if condition_stack:
				exposed_conditions.add(condition_stack[-1].open_index)
		elif token.kind == "symbol" and token.value in _CLOSE:
			closed = condition_stack.pop()
			if (
				condition_stack and closed.kind not in {"array", "dictionary"}
				and closed.open_index in exposed_conditions
			):
				exposed_conditions.add(condition_stack[-1].open_index)
	spans: list[ArgumentGroupLayoutSpan] = []
	for call_index, call in enumerate(groups):
		if call.kind != "call":
			continue
		for start, end in call.items:
			group = by_open.get(start)
			if (
				group is None or group.kind != "group"
				or group.parent_index != call_index or group.close_index != end - 1
				or group.items != ((group.open_index + 1, group.close_index),)
				or tokens[group.open_index].line == tokens[group.close_index].end_line
				or tokens[group.open_index].line in comment_lines
				or tokens[group.close_index].end_line in comment_lines
				or group.open_index in exposed_conditions
				or scope_prefix[start] != scope_prefix[end]
				or not barrier_free(start, end)
				or atom_unary_count(start, end) is not None
				or (start, end) in boolean_carriers
			):
				continue
			while group is not None:
				opener, closer = tokens[group.open_index], tokens[group.close_index]
				if opener.line != closer.end_line:
					spans.append(ArgumentGroupLayoutSpan(
						call.open_index, group.open_index, group.close_index,
						opener.start, closer.end, opener.line, closer.end_line,
					))
				inner = by_open.get(group.open_index + 1)
				if (
					inner is None or inner.kind != "group"
					or inner.close_index != group.close_index - 1
					or inner.items != ((inner.open_index + 1, inner.close_index),)
				):
					break
				group = inner
	return tuple(spans)


def _independent_statement_starts(view: LexedSource) -> tuple[dict[int, int], set[int]]:
	"""Reuse this exact view's statement proof without exposing mutable cache data."""
	if view._analysis is None:
		return _build_independent_statement_starts(view)
	first_by_line, starts = _analysis_result(
		view, "statement_starts", lambda: _build_independent_statement_starts(view),
	)
	return dict(first_by_line), set(starts)


def _build_independent_statement_starts(view: LexedSource) -> tuple[dict[int, int], set[int]]:
	"""Prove physical statement starts outside delimiters or in a lambda body.

	An anonymous function's parameter owner and header colon establish its body
	domain. Direct comma items keep sibling parameters separate; an indentation
	stack restores the outer body after a nested lambda ends. A declaration's
	parameter list or a container without such a body cannot create statements.
	Each token and lambda stack entry is visited a bounded number of times.
	"""
	tokens, groups = view.tokens, view.groups
	by_open = {group.open_index: group for group in groups}
	group_numbers = {group.open_index: number for number, group in enumerate(groups)}
	parents: list[int | None] = []
	delimiters: list[int] = []
	first_by_line: dict[int, int] = {}
	for index, token in enumerate(tokens):
		parents.append(delimiters[-1] if delimiters else None)
		first_by_line.setdefault(token.line, index)
		if index in group_numbers:
			delimiters.append(group_numbers[index])
		elif token.kind == "symbol" and token.value in _CLOSE:
			delimiters.pop()
	item_starts: dict[int, tuple[int, ...]] = {}

	def item_key(owner: int | None, index: int) -> tuple[int, int] | None:
		if owner is None or groups[owner].kind not in {"call", "group", "array", "dictionary"}:
			return None
		if owner not in item_starts:
			item_starts[owner] = tuple(left for left, _right in groups[owner].items)
		item = bisect_right(item_starts[owner], index) - 1
		if item < 0 or index >= groups[owner].items[item][1]:
			return None
		return owner, item

	def indentation(line: int) -> int:
		raw = view.lines[line - 1]
		return len(raw) - len(raw.lstrip("\t"))

	identifier, _atom, _barrier = _atomic_layout_matcher(view)
	type_cache: dict[tuple[int, int], int | None] = {}

	def type_end(start: int, limit: int, depth: int = 0) -> int | None:
		key = start, limit
		if key in type_cache:
			return type_cache[key]
		if start >= limit or depth > MAX_GROUP_DEPTH or not (identifier(start) or tokens[start].value == "void"):
			return None
		cursor = start + 1
		while cursor + 1 < limit and tokens[cursor].value == "." and identifier(cursor + 1):
			cursor += 2
		if cursor < limit and tokens[cursor].value == "[":
			collection = by_open.get(cursor)
			arity = {"Array": 1, "Dictionary": 2}.get(tokens[start].value)
			if (
				cursor != start + 1 or collection is None or collection.close_index >= limit
				or arity is None or len(collection.items) != arity
				or tokens[collection.close_index - 1].value == ","
				or any(type_end(left, right, depth + 1) != right for left, right in collection.items)
			):
				cursor = None
			else:
				cursor = collection.close_index + 1
		type_cache[key] = cursor
		return cursor

	def header_cursor(start: int, previous_line: int) -> int | None:
		while start < len(tokens):
			token = tokens[start]
			if token.line > previous_line:
				return None
			if token.kind != "symbol" or token.value != "\\":
				return start
			previous_line = token.end_line + 1
			start += 1
		return None

	def lambda_colon(parameters: Group) -> int | None:
		# Read only this header's suffix. A missing colon must not scan another
		# func header or a lambda body elsewhere on the same physical line.
		cursor = header_cursor(parameters.close_index + 1, tokens[parameters.close_index].end_line)
		if cursor is None:
			return None
		if tokens[cursor].value == "->":
			start = header_cursor(cursor + 1, tokens[cursor].end_line)
			end = type_end(start, len(tokens)) if start is not None else None
			if end is None:
				return None
			cursor = header_cursor(end, tokens[end - 1].end_line)
		return cursor if cursor is not None and tokens[cursor].value == ":" else None

	headers: dict[int, tuple[tuple[int, int], int]] = {}
	for index, token in enumerate(tokens):
		if token.kind != "identifier" or token.value != "func":
			continue
		opening = index + 1
		if opening < len(tokens) and identifier(opening):
			opening += 1
		parameters = by_open.get(opening)
		if parameters is None or parameters.kind != "parameters":
			continue
		key = item_key(parameters.parent_index, index)
		if key is None:
			continue
		colon = lambda_colon(parameters)
		if key is not None and colon is not None:
			headers[colon] = key, indentation(token.line)
	active: dict[tuple[int, int], list[tuple[int, int]]] = {}
	starts: set[int] = set()
	for index, token in enumerate(tokens):
		if first_by_line[token.line] == index:
			previous = tokens[index - 1] if index else None
			if previous is None or previous.value != "\\":
				if parents[index] is None:
					starts.add(index)
				else:
					key = item_key(parents[index], index)
					stack = active.get(key, []) if key is not None else []
					indent = indentation(token.line)
					while stack and stack[-1][0] >= indent:
						stack.pop()
					if stack and token.line > tokens[stack[-1][1]].end_line:
						starts.add(index)
		if index in headers:
			key, indent = headers[index]
			active.setdefault(key, []).append((indent, index))
	return first_by_line, starts


def call_group_layout_spans(view: LexedSource) -> tuple[CallGroupLayoutSpan, ...]:
	"""Find whole statement-value groups around an unchanged ordinary call.

	Only complete assignment and return values qualify. Calls or operators after
	the group, complex callees and all scope/physical barriers retain their groups.
	Lambda bodies use proven independent statement starts, never a line prefix
	inside a call, container or function parameter declaration by itself.
	"""
	if view.issues:
		return ()
	tokens, groups = view.tokens, view.groups
	by_open = {group.open_index: group for group in groups}
	by_close = {group.close_index: group for group in groups}
	first_by_line, statement_starts = _independent_statement_starts(view)
	identifier, _atom, barrier_free = _atomic_layout_matcher(view)
	comment_lines = {comment.line for comment in view.comments}
	scope_prefix = [0]
	for token in tokens:
		scope_prefix.append(scope_prefix[-1] + int(
			token.kind == "identifier" and token.value in {"func", "if", "else", "as", "await"}
		))
	callee_cache: dict[int, int | None] = {}
	item_end_cache: dict[int, set[int]] = {}

	def callee_start(call: Group) -> int | None:
		if call.open_index in callee_cache:
			return callee_cache[call.open_index]
		cursor = call.open_index - 1
		result = None
		if cursor >= 0 and identifier(cursor):
			while cursor >= 2 and tokens[cursor - 1].value == "." and identifier(cursor - 2):
				cursor -= 2
			if cursor == 0 or tokens[cursor - 1].value != ".":
				result = cursor
		callee_cache[call.open_index] = result
		return result

	def context(group: Group) -> str | None:
		first = first_by_line[tokens[group.open_index].line]
		if first not in statement_starts or first >= group.open_index:
			return None
		previous = tokens[group.open_index - 1]
		if previous.value == "return" and first == group.open_index - 1:
			return "return"
		if previous.kind != "symbol" or previous.value not in {"=", ":="}:
			return None
		end, cursor = group.open_index - 1, first
		while cursor + 1 < end and tokens[cursor].value == "@" and identifier(cursor + 1):
			cursor += 2
			annotation = by_open.get(cursor)
			if annotation is not None and annotation.close_index < end:
				cursor = annotation.close_index + 1
		if cursor < end and tokens[cursor].value == "static":
			cursor += 1
		declaration = cursor < end and tokens[cursor].value in {"var", "const"}
		if declaration:
			cursor += 1
		if cursor >= end or not identifier(cursor):
			return None
		cursor += 1
		if declaration:
			if cursor == end:
				return "assignment"
			if tokens[cursor].value != ":" or cursor + 1 == end:
				return None
			return "assignment" if all(
				identifier(position) or tokens[position].value in {".", "[", "]", ","}
				for position in range(cursor + 1, end)
			) else None
		while cursor < end:
			if cursor + 1 < end and tokens[cursor].value == "." and identifier(cursor + 1):
				cursor += 2
				continue
			index_group = by_open.get(cursor)
			if index_group is not None and index_group.kind == "index" and index_group.close_index < end:
				cursor = index_group.close_index + 1
				continue
			return None
		return "assignment"

	def complete_value(group: Group) -> bool:
		end = group.close_index + 1
		if end == len(tokens):
			return True
		next_token = tokens[end]
		if next_token.value in {".", "[", "(", "+", "-", "*", "/", "%", "**", "<<", ">>", "&", "|", "^", "==", "!=", "<", ">", "<=", ">=", "and", "or", "is", "in", "as", "if", "else", "\\"}:
			# A following block header is a new statement, not a conditional suffix.
			if not (
				next_token.value in {"if", "else"}
				and next_token.line > tokens[group.close_index].end_line
				and first_by_line[next_token.line] == end
				and _header_colon(tokens, end, by_open) is not None
			):
				return False
		if group.parent_index is not None:
			owner = groups[group.parent_index]
			if next_token.value == ",":
				if owner.open_index not in item_end_cache:
					item_end_cache[owner.open_index] = {right for _left, right in owner.items}
				return end in item_end_cache[owner.open_index]
			if end == owner.close_index:
				return True
		return next_token.line > tokens[group.close_index].end_line

	spans: list[CallGroupLayoutSpan] = []
	for group in groups:
		if group.kind != "group":
			continue
		value_context = context(group)
		if value_context is None or not complete_value(group):
			continue
		start, end = group.open_index, group.close_index + 1
		if (
			scope_prefix[start] != scope_prefix[end] or not barrier_free(start, end)
			or tokens[start].line in comment_lines or tokens[end - 1].end_line in comment_lines
		):
			continue
		wrappers: list[Group] = []
		inner = group
		while inner.kind == "group":
			if inner.items != ((inner.open_index + 1, inner.close_index),):
				break
			wrappers.append(inner)
			child = by_open.get(inner.open_index + 1)
			if child is None:
				child = by_close.get(inner.close_index - 1)
			if child is None or child.close_index != inner.close_index - 1:
				break
			if (
				(child.kind == "group" and child.open_index != inner.open_index + 1)
				or (child.kind == "call" and callee_start(child) != inner.open_index + 1)
				or child.kind not in {"group", "call"}
			):
				break
			inner = child
		if inner.kind != "call":
			continue
		callee = callee_start(inner)
		if not wrappers or callee != wrappers[-1].open_index + 1:
			continue
		for wrapper in wrappers:
			opener, closer = tokens[wrapper.open_index], tokens[wrapper.close_index]
			spans.append(CallGroupLayoutSpan(
				value_context, inner.open_index, callee, wrapper.open_index,
				wrapper.close_index, opener.start, closer.end, opener.line, closer.end_line,
			))
	return tuple(spans)


def _expression_layout_candidates(view: LexedSource, identifier: Callable[[int], bool]) -> tuple[
	dict[int, Group], list[int | None], dict[str, dict[int | None, list[int]]], set[tuple[int, int]],
]:
	"""Index direct operators and complete expression domains in bounded passes.

	Only complete delimiter items, groups, defaults and proven statement values
	qualify. Balanced-group jumps keep statement scanning outside nested values;
	operator ownership prevents a child expression from supplying its parent's
	operator. Matching rules still decide which complete domains are simple.
	"""
	tokens, groups = view.tokens, view.groups
	by_open = {group.open_index: group for group in groups}
	group_numbers = {group.open_index: number for number, group in enumerate(groups)}
	parents: list[int | None] = []
	stack: list[int] = []
	operators: dict[str, dict[int | None, list[int]]] = {"+": {}, "%": {}}
	assignments: dict[int | None, list[int]] = {}
	dictionary_separators: dict[int, list[int]] = {}
	parameter_defaults: dict[int, list[int]] = {}
	for index, token in enumerate(tokens):
		parent = stack[-1] if stack else None
		parents.append(parent)
		if token.kind == "symbol":
			if token.value in operators:
				operators[token.value].setdefault(parent, []).append(index)
			if token.value in {"=", ":="}:
				assignments.setdefault(parent, []).append(index)
			if parent is not None and groups[parent].kind == "dictionary" and token.value in {":", "="}:
				dictionary_separators.setdefault(parent, []).append(index)
			if parent is not None and groups[parent].kind == "parameters" and token.value == "=":
				parameter_defaults.setdefault(parent, []).append(index)
		if index in group_numbers:
			stack.append(group_numbers[index])
		elif token.kind == "symbol" and token.value in _CLOSE:
			stack.pop()

	def direct_indexes(indexes: list[int], start: int, end: int) -> tuple[int, int]:
		return bisect_right(indexes, start - 1), bisect_right(indexes, end - 1)

	candidates: set[tuple[int, int]] = set()
	for number, group in enumerate(groups):
		if group.kind == "group":
			candidates.add((group.open_index, group.close_index + 1))
		elif group.kind in {"call", "array"}:
			candidates.update(group.items)
		elif group.kind in {"dictionary", "parameters"}:
			indexes = dictionary_separators.get(number, []) if group.kind == "dictionary" else parameter_defaults.get(number, [])
			for start, end in group.items:
				left, right = direct_indexes(indexes, start, end)
				if right - left == 1:
					separator = indexes[left]
					if group.kind == "dictionary":
						candidates.add((start, separator))
					candidates.add((separator + 1, end))
	_first_by_line, statement_starts = _independent_statement_starts(view)
	for start in statement_starts:
		first = tokens[start]
		if first.value not in {"return", "var", "const", "static", "@"} and not (
			identifier(start) and first.value not in {"true", "false", "null"}
		):
			continue
		owner = parents[start]
		cursor = start
		while cursor < len(tokens):
			token = tokens[cursor]
			if cursor > start and token.line > tokens[cursor - 1].end_line and tokens[cursor - 1].value != "\\":
				break
			if parents[cursor] != owner or (token.kind == "symbol" and token.value in {",", ")", "]", "}"}):
				break
			group = by_open.get(cursor)
			cursor = group.close_index + 1 if group is not None else cursor + 1
		end = cursor
		if first.value == "return":
			candidates.add((start + 1, end))
		else:
			indexes = assignments.get(owner, [])
			left, right = direct_indexes(indexes, start, end)
			if right - left == 1:
				candidates.add((indexes[left] + 1, end))
	return by_open, parents, operators, candidates


def _boolean_name_path_roles(view: LexedSource, statement_starts: set[int]) -> tuple[set[int], set[int]]:
	"""Prove member/node names and node-reference markers independently of operators.

	Path names may themselves be language keywords. Whitespace does not turn a
	/NAME path component into a Boolean operator. This indexes syntactic roles;
	it never promotes a receiver to an ordinary callee or changes other rules.
	Each indexed path is consumed once.
	"""
	tokens = view.tokens
	names = {
		index for index, token in enumerate(tokens)
		if token.kind == "identifier" and index > 0 and tokens[index - 1].value == "."
	}
	after: dict[int, int] = {}
	before: dict[int, int] = {}
	cursor = 0
	while cursor < len(tokens):
		if tokens[cursor].value != "\\":
			cursor += 1
			continue
		start = cursor
		while cursor < len(tokens) and tokens[cursor].value == "\\":
			cursor += 1
		for index in range(start, cursor):
			after[index], before[index] = cursor, start - 1
	path_tokens: set[int] = set()
	non_operands = _CONTROL | {
		"return", "when", "in", "not", "and", "or", "await", "as", "is",
		"var", "const", "static", "func", "else", "elif",
	}
	for index, token in enumerate(tokens):
		if token.kind == "string" and token.value.startswith(('$"', "$'")):
			# The lexer folds the $ header into its opaque quoted path token.
			path_tokens.add(index)
			continue
		if token.kind != "symbol" or token.value not in {"$", "%"} or index in path_tokens:
			continue
		previous = before.get(index - 1, index - 1)
		if token.value == "%" and previous >= 0 and index not in statement_starts:
			left = tokens[previous]
			if left.kind in {"number", "string"} or left.value in _CLOSE or (
				left.kind == "identifier" and (left.value not in non_operands or previous in names)
			):
				continue
		cursor = after.get(index + 1, index + 1)
		unique_marker = None
		if token.value == "$" and cursor < len(tokens) and tokens[cursor].value == "%":
			unique_marker = cursor
			cursor = after.get(cursor + 1, cursor + 1)
		leading_slash = None
		if cursor < len(tokens) and tokens[cursor].value == "/":
			leading_slash = cursor
			cursor = after.get(cursor + 1, cursor + 1)
		if cursor < len(tokens) and leading_slash is None:
			payload = tokens[cursor]
			quoted = payload.kind == "string" and payload.value.startswith(('"', "'"))
			regular = quoted and not payload.value.startswith(('"""', "'''"))
			if quoted and ((token.value == "$" and unique_marker is None) or regular):
				path_tokens.update((index, cursor))
				if unique_marker is not None:
					path_tokens.add(unique_marker)
				continue
		if cursor >= len(tokens) or tokens[cursor].kind != "identifier":
			continue
		names.add(cursor)
		path_tokens.add(index)
		if unique_marker is not None:
			path_tokens.add(unique_marker)
		if leading_slash is not None:
			path_tokens.add(leading_slash)
		while cursor + 1 < len(tokens):
			slash = after.get(cursor + 1, cursor + 1)
			if slash >= len(tokens) or tokens[slash].value != "/":
				break
			child = after.get(slash + 1, slash + 1)
			marker = child
			if child < len(tokens) and tokens[child].value == "%":
				child = after.get(child + 1, child + 1)
			if child >= len(tokens) or tokens[child].kind != "identifier":
				break
			path_tokens.update((slash, marker))
			cursor = child
			names.add(cursor)
	return names, path_tokens


def _boolean_name_roles(view: LexedSource, statement_starts: set[int]) -> set[int]:
	"""Keep the established name-role API for Boolean scope consumers."""
	return _boolean_name_path_roles(view, statement_starts)[0]


def _boolean_group_kinds(view: LexedSource, names: set[int]) -> tuple[str, ...]:
	"""Restore group owners using proven keyword-name roles in the scope view."""
	kinds: list[str] = []
	for group in view.groups:
		kind = group.kind
		if kind == "parameters":
			kind = _group_kind(view.tokens, group.open_index, names=names)
		if group.open_index > 0 and group.open_index - 1 in names:
			if view.tokens[group.open_index].value == "(":
				kind = "call"
			elif view.tokens[group.open_index].value == "[":
				kind = "index"
		kinds.append(kind)
	return tuple(kinds)


def _boolean_scope_view(view: LexedSource) -> tuple[
	LexedSource, LexedSource, dict[int, int], set[int], set[int], tuple[str, ...],
] | None:
	"""Reuse the scope closure, keeping each consumer's mutable collections private."""
	if view._analysis is None:
		return _build_boolean_scope_view(view)
	scope = _analysis_result(view, "boolean_scope", lambda: _build_boolean_scope_view(view))
	if scope is None:
		return None
	scoped, proof, first_by_line, starts, names, kinds = scope
	return scoped, proof, dict(first_by_line), set(starts), set(names), kinds


def _build_boolean_scope_view(view: LexedSource) -> tuple[
	LexedSource, LexedSource, dict[int, int], set[int], set[int], tuple[str, ...],
] | None:
	"""Close keyword roles over proven statements in at most two bounded passes.

	A lambda value has the same header/item/indentation proof in an index as in
	an array. Only the statement-proof lens presents indices as eligible arrays;
	logical domains retain their actual index kind and never borrow its carrier
	for body statements. This keeps body proof stable while names restore an
	old array classification to an index. Raw groups and tokens remain untouched.
	"""
	def lens(kinds: tuple[str, ...], statement_proof: bool = False) -> LexedSource:
		groups = tuple(Group(
			group.open_index, group.close_index,
			"array" if statement_proof and kinds[number] == "index" else kinds[number],
			group.parent_index, group.items,
		) for number, group in enumerate(view.groups))
		return LexedSource(
			view.source, view.lines, view.tokens, view.comments, groups, view.issues,
			_analysis=view._analysis,
		)

	_first_by_line, starts = _independent_statement_starts(view)
	names = _boolean_name_roles(view, starts)
	for _round in range(2):
		kinds = _boolean_group_kinds(view, names)
		proof_view = lens(kinds, statement_proof=True)
		first_by_line, starts = _independent_statement_starts(proof_view)
		names = _boolean_name_roles(view, starts)
		closed_kinds = _boolean_group_kinds(view, names)
		if closed_kinds == kinds:
			return lens(closed_kinds), proof_view, first_by_line, starts, names, closed_kinds
	return None


def boolean_layout_spans(view: LexedSource) -> tuple[BooleanLayoutSpan, ...]:
	"""Return immutable Boolean spans, shared only inside the owning audit."""
	return _analysis_result(view, "boolean_spans", lambda: _build_boolean_layout_spans(view))


def _build_boolean_layout_spans(view: LexedSource) -> tuple[BooleanLayoutSpan, ...]:
	"""Index complete three-or-more-term Boolean domains without flattening syntax.

	Ordinary groups are transparent for term counting; calls, containers and
	ternary slots are independent. Direct-owner indexes, delimiter jumps and the
	existing depth budget bound the work. Physical barriers affect migration
	safety, never whether a required layout remains visible to the checker.
	"""
	if view.issues or not view.tokens:
		return ()
	tokens = view.tokens
	identifier, _atom, _barrier = _atomic_layout_matcher(view)
	scope = _boolean_scope_view(view)
	if scope is None:
		return ()
	scoped_view, proof_view, first_by_line, statement_starts, names, actual_kinds = scope
	groups, kinds = scoped_view.groups, list(actual_kinds)
	by_open, parents, _operators, candidates = _expression_layout_candidates(proof_view, identifier)
	group_numbers = {group.open_index: number for number, group in enumerate(groups)}
	domains: dict[tuple[int, int], tuple[str, int | None]] = {}
	for number, group in enumerate(groups):
		if kinds[number] == "group":
			domains[group.open_index, group.close_index + 1] = "group", group.open_index
		elif kinds[number] in {"call", "array", "index"}:
			for item in group.items:
				domains[item] = kinds[number] + "_item", group.open_index
	for start, end in candidates:
		if (start, end) in domains:
			continue
		parent = parents[start] if start < end else None
		kind = kinds[parent] if parent is not None else None
		context = {"dictionary": "dictionary_slot", "parameters": "parameter_default"}.get(kind)
		if context is not None:
			domains[start, end] = context, groups[parent].open_index
		else:
			context = "return" if start > 0 and tokens[start - 1].value == "return" else "assignment"
			domains[start, end] = context, None
	# The shared simple-expression index intentionally recognizes only =/:=.
	# Boolean domains also include complete compound RHSs and value statements;
	# keep that extension local so String/format candidate sets remain unchanged.
	compound = {"+=", "-=", "*=", "/=", "%=", "**=", "<<=", ">>=", "&=", "|=", "^="}
	non_values = _CONTROL | {
		"func", "signal", "class", "class_name", "enum", "extends", "get", "set",
		"return", "var", "const", "static", "@", "pass", "break", "continue",
	}
	for start in statement_starts:
		if tokens[start].value in non_values:
			continue
		owner, cursor, separator = parents[start], start, None
		has_assignment = False
		while cursor < len(tokens):
			token = tokens[cursor]
			if cursor > start and token.line > tokens[cursor - 1].end_line and tokens[cursor - 1].value != "\\":
				break
			if parents[cursor] != owner or token.value in {",", ")", "]", "}"}:
				break
			child = by_open.get(cursor)
			if child is not None:
				cursor = child.close_index + 1
				continue
			if token.kind == "symbol" and token.value in compound:
				separator = cursor
			if token.kind == "symbol" and token.value in {"=", ":="}:
				has_assignment = True
			cursor += 1
		if separator is not None:
			domains[separator + 1, cursor] = "compound_assignment", None
		elif (start, cursor) not in domains and not has_assignment:
			domains[start, cursor] = "expression_statement", None

	def indentation(line: int) -> int:
		raw = view.lines[line - 1]
		return len(raw) - len(raw.lstrip("\t"))

	header_starts: set[int] = set()
	match_scopes: list[tuple[int, int, int | None]] = []
	for line, start in first_by_line.items():
		first, owner, indent = tokens[start], parents[start], indentation(line)
		while match_scopes and line > match_scopes[-1][1] and owner == match_scopes[-1][2] and indent <= match_scopes[-1][0]:
			match_scopes.pop()
		if start not in statement_starts:
			continue
		arm = bool(match_scopes and owner == match_scopes[-1][2] and line > match_scopes[-1][1] and indent == match_scopes[-1][0] + 1)
		if first.value not in _CONTROL and not arm:
			continue
		colon = _header_colon(tokens, start, by_open)
		if colon is None:
			continue
		header_starts.add(start)
		if first.value in {"if", "elif", "while", "match"}:
			domains[start + 1, colon] = first.value, None
		if first.value == "match":
			match_scopes.append((indent, tokens[colon].line, owner))
		cursor = start + 1
		while cursor < colon:
			child = by_open.get(cursor)
			if child is not None:
				cursor = child.close_index + 1
				continue
			if cursor not in names and tokens[cursor].kind == "identifier":
				if first.value == "for" and tokens[cursor].value == "in":
					domains[cursor + 1, colon] = "for_iterable", None
					break
				if arm and tokens[cursor].value == "when":
					domains[cursor + 1, colon] = "match_when", None
					group = by_open.get(cursor + 1)
					if group is not None and group.close_index == colon - 1:
						kinds[group_numbers[group.open_index]] = "group"
					break
			cursor += 1

	direct: dict[int | None, list[int]] = {}
	conditionals: dict[int | None, list[int]] = {}
	functions: dict[int | None, list[int]] = {}
	else_for_if: dict[int, int] = {}
	pending: dict[int | None, list[int]] = {}
	for index, token in enumerate(tokens):
		if index in names:
			continue
		owner = parents[index]
		if token.value in {"and", "or", "&&", "||"} and token.kind in {"identifier", "symbol"}:
			direct.setdefault(owner, []).append(index)
		if token.kind != "identifier":
			continue
		if token.value == "func":
			functions.setdefault(owner, []).append(index)
		elif token.value == "if" and index not in header_starts:
			conditionals.setdefault(owner, []).append(index)
			pending.setdefault(owner, []).append(index)
		elif token.value == "else" and index not in statement_starts:
			stack = pending.get(owner, [])
			if stack:
				else_for_if[stack.pop()] = index
	sealed = {number for number in conditionals if number is not None and kinds[number] == "group"}
	group_scopes: list[int | None] = []
	for number, group in enumerate(groups):
		parent_scope = group_scopes[group.parent_index] if group.parent_index is not None else None
		group_scopes.append(number if kinds[number] != "group" or number in sealed else parent_scope)
	logical: dict[int | None, list[int]] = {}
	for owner, indexes in direct.items():
		scope = group_scopes[owner] if owner is not None else None
		logical.setdefault(scope, []).extend(indexes)
	for indexes in logical.values():
		indexes.sort()
	layers: dict[int | None, list[int]] = {}
	for number, group in enumerate(groups):
		if kinds[number] != "group":
			continue
		scope = group_scopes[number]
		indexes = logical.get(scope, [])
		if bisect_right(indexes, group.close_index - 1) > bisect_right(indexes, group.open_index):
			layers.setdefault(scope, []).append(group.open_index)
	comment_lines = sorted({comment.line for comment in view.comments})
	barrier_prefixes = {name: [0] for name in ("explicit_continuation", "multiline_literal", "lambda", "cast", "await")}
	for index, token in enumerate(tokens):
		flags = {
			"explicit_continuation": token.kind == "symbol" and token.value == "\\",
			"multiline_literal": token.kind == "string" and token.line != token.end_line,
			"lambda": token.kind == "identifier" and token.value == "func" and index not in names,
			"cast": token.kind == "identifier" and token.value == "as" and index not in names,
			"await": token.kind == "identifier" and token.value == "await" and index not in names,
		}
		for name, prefix in barrier_prefixes.items():
			prefix.append(prefix[-1] + int(flags[name]))

	def within(indexes: list[int], start: int, end: int) -> list[int]:
		return indexes[bisect_right(indexes, start - 1):bisect_right(indexes, end - 1)]

	observed: list[tuple[int | None, BooleanLayoutSpan]] = []
	visited: set[tuple[int, int, int | None]] = set()

	def domain(start: int, end: int, context: str, carrier: int | None, depth: int = 0) -> None:
		if start >= end or depth > MAX_GROUP_DEPTH or (start, end, carrier) in visited:
			return
		visited.add((start, end, carrier))
		inner_start, inner_end = start, end
		while inner_start < inner_end and tokens[inner_start].value == "\\":
			inner_start += 1
		wrappers: list[int] = []
		while inner_start < inner_end:
			cursor = inner_start
			while cursor < inner_end and tokens[cursor].value in {"not", "!"}:
				cursor += 1
			group = by_open.get(cursor)
			if group is None or kinds[group_numbers[cursor]] != "group" or group.close_index != inner_end - 1:
				break
			wrappers.append(cursor)
			inner_start, inner_end = cursor + 1, inner_end - 1
		if inner_start >= inner_end:
			return
		owner = parents[inner_start]
		function_indexes = within(functions.get(owner, []), inner_start, inner_end)
		if function_indexes and function_indexes[0] == inner_start:
			# A lambda is an operand, not a Boolean expression made of its body.
			# Proven body statements and parameter defaults are separate candidates.
			return
		carrier = wrappers[0] if wrappers else carrier
		ifs = within(conditionals.get(owner, []), inner_start, inner_end)
		unproven = bool(function_indexes)
		if ifs:
			first_if = ifs[0]
			otherwise = else_for_if.get(first_if)
			if otherwise is not None and first_if < otherwise < inner_end:
				for left, right, slot in (
					(inner_start, first_if, "then"), (first_if + 1, otherwise, "condition"),
					(otherwise + 1, inner_end, "else"),
				):
					domain(left, right, context + ":ternary_" + slot, carrier, depth + 1)
				return
			unproven = True
		logical_end = function_indexes[0] if function_indexes else inner_end
		if not within(direct.get(owner, []), inner_start, logical_end):
			return
		scope = group_scopes[owner] if owner is not None else None
		indexes = tuple(within(logical.get(scope, []), inner_start, logical_end))
		if len(indexes) + 1 <= MAX_INLINE_CONDITION_TERMS:
			return
		first, last = tokens[start], tokens[end - 1]
		barriers = [name for name, prefix in barrier_prefixes.items() if prefix[end] != prefix[start]]
		if bisect_right(comment_lines, last.end_line) > bisect_right(comment_lines, first.line - 1):
			barriers.insert(0, "comment")
		if unproven:
			barriers.append("unproven_domain")
		participating = tuple(
			opening for opening in within(layers.get(scope, []), start, end)
			if by_open[opening].close_index < end
		)
		observed.append((scope, BooleanLayoutSpan(
			start, end, first.start, last.end, first.line, last.end_line, context,
			len(indexes) + 1, indexes, participating, carrier, carrier is None,
			not barriers, tuple(barriers),
		)))
	for (start, end), (context, carrier) in sorted(domains.items(), key=lambda item: (item[0][0], -item[0][1])):
		domain(start, end, context, carrier)
	# Transparent nested groups are one Boolean domain, not duplicate issues.
	# Opaque child scopes remain independently observable even inside a host span.
	covered: dict[int | None, int] = {}
	spans: list[BooleanLayoutSpan] = []
	for scope, span in sorted(observed, key=lambda item: (item[1].start_index, -item[1].end_index)):
		if span.end_index <= covered.get(scope, -1):
			continue
		covered[scope] = span.end_index
		spans.append(span)
	return tuple(spans)


def simple_string_layout_spans(view: LexedSource) -> tuple[SimpleStringLayoutSpan, ...]:
	"""Find complete flat + chains with a real String literal as a syntax anchor.

	Unknown variable types are not inferred, and numeric/non-String literals do
	not qualify. Complete groups may be joined inside a more complex expression,
	but ungrouped prefixes or suffixes of that expression never become candidates.
	Delimiter-owner indexes, span caches and balanced-group jumps bound the work;
	no candidate rescans the whole source or walks its ancestor chain.
	"""
	if view.issues:
		return ()
	tokens = view.tokens
	identifier, _atom, barrier_free = _atomic_layout_matcher(view)
	by_open, parents, operators, candidates = _expression_layout_candidates(view, identifier)
	pluses = operators["+"]
	atom_cache: dict[tuple[int, int], bool | None] = {}
	chain_cache: dict[tuple[int, int], bool] = {}

	def string_literal(index: int) -> bool:
		token = tokens[index]
		return (
			token.kind == "string" and token.line == token.end_line
			and (token.value.startswith(("\"", "'")) or token.value.startswith(('r"', "r'")))
		)

	def name(index: int) -> bool:
		return identifier(index) and tokens[index].value not in {"true", "false", "null"}

	def atom(start: int, end: int, depth: int = 0) -> bool | None:
		key = start, end
		if key in atom_cache:
			return atom_cache[key]
		if start >= end or depth > MAX_GROUP_DEPTH:
			return None
		result: bool | None = None
		group = by_open.get(start)
		if (
			group is not None and group.kind == "group" and group.close_index == end - 1
			and group.items == ((start + 1, end - 1),)
		):
			result = atom(start + 1, end - 1, depth + 1)
		elif end == start + 1 and string_literal(start):
			result = True
		elif name(start):
			cursor = start + 1
			while cursor + 1 < end and tokens[cursor].value == "." and name(cursor + 1):
				cursor += 2
			if cursor == end and (end > start + 1 or tokens[start].value not in {"self", "super"}):
				result = False
		atom_cache[key] = result
		return result

	def chain(start: int, end: int, depth: int = 0) -> bool:
		key = start, end
		if key in chain_cache:
			return chain_cache[key]
		if start >= end or depth > MAX_GROUP_DEPTH:
			return False
		group = by_open.get(start)
		if (
			group is not None and group.kind == "group" and group.close_index == end - 1
			and group.items == ((start + 1, end - 1),)
		):
			result = chain(start + 1, end - 1, depth + 1)
		else:
			operators = pluses.get(parents[start], [])
			left, right = bisect_right(operators, start - 1), bisect_right(operators, end - 1)
			result = False
			if left < right:
				result, anchored = True, False
				cursor = start
				for position in range(left, right + 1):
					stop = operators[position] if position < right else end
					literal = atom(cursor, stop)
					if literal is None:
						result = False
						break
					anchored = anchored or literal
					cursor = stop + 1
				result = result and anchored
		chain_cache[key] = result
		return result

	comment_lines = {comment.line for comment in view.comments}
	spans: list[SimpleStringLayoutSpan] = []
	for start, end in sorted(candidates):
		if start >= end or not chain(start, end):
			continue
		first, last = tokens[start], tokens[end - 1]
		if first.line in comment_lines or last.end_line in comment_lines or not barrier_free(start, end):
			continue
		group = by_open.get(start)
		spans.append(SimpleStringLayoutSpan(
			start, end, first.start, last.end, first.line, last.end_line,
			group.open_index if group is not None and group.kind == "group" and group.close_index == end - 1 else None,
		))
	return tuple(spans)


def simple_format_layout_spans(view: LexedSource) -> tuple[SimpleFormatLayoutSpan, ...]:
	"""Find complete String % scalar expressions and their plain one-argument calls.

	The String anchor is an ordinary/raw literal on one physical line. Scalar
	operands may retain atomic groups and one unary operator; containers, calls,
	indexing and compound operators are not scalar atoms. Complete groups inside
	complex expressions remain independent candidates. No ungrouped prefix or
	suffix can become a candidate, and no name length determines the layout.

	Direct-owner operator indexes and memoized group matching bound the work.
	Whole-call spans may overlap expression spans so consumers can retain the
	expression when a comment or complex receiver protects the surrounding call.
	"""
	if view.issues:
		return ()
	tokens, groups = view.tokens, view.groups
	identifier, _atom, barrier_free = _atomic_layout_matcher(view)
	by_open, parents, operators, candidates = _expression_layout_candidates(view, identifier)
	percents = operators["%"]
	comment_lines = {comment.line for comment in view.comments}
	literal_cache: dict[tuple[int, int], bool] = {}
	scalar_cache: dict[tuple[int, int], int | None] = {}
	format_cache: dict[tuple[int, int], bool] = {}
	unary = {"+", "-", "~", "not", "!"}

	def string_literal(index: int) -> bool:
		token = tokens[index]
		return (
			token.kind == "string" and token.line == token.end_line
			and (token.value.startswith(("\"", "'")) or token.value.startswith(('r"', "r'")))
		)

	def name(index: int) -> bool:
		return identifier(index) and tokens[index].value not in {"true", "false", "null"}

	# Lexical closure has already validated each explicit continuation. Index
	# runs once so path headers, segments and binary-% context skip them in O(1).
	before_continuation: dict[int, int] = {}
	after_continuation: dict[int, int] = {}
	previous_real = -1
	for index, token in enumerate(tokens):
		if token.value == "\\":
			before_continuation[index] = previous_real
		else:
			previous_real = index
	next_real = len(tokens)
	for index in range(len(tokens) - 1, -1, -1):
		if tokens[index].value == "\\":
			after_continuation[index] = next_real
		else:
			next_real = index

	# $Node and primary %UniqueNode are get_node receivers, not plain name
	# callees. Index their raw path bases once; a binary % after a complete
	# operand still permits the independent ordinary call on its right.
	_first_by_line, statement_starts = _independent_statement_starts(view)
	node_receiver_starts: set[int] = set()
	for index, token in enumerate(tokens):
		if token.kind != "symbol" or token.value not in {"$", "%"}:
			continue
		if token.value == "%" and index > 0 and index not in statement_starts:
			previous_index = before_continuation.get(index - 1, index - 1)
			if previous_index >= 0:
				previous = tokens[previous_index]
				if previous.kind in {"number", "string"} or identifier(previous_index) or (
					previous.kind == "symbol" and previous.value in _CLOSE
				):
					continue
		cursor = after_continuation.get(index + 1, index + 1)
		# A primary shorthand header may contain whitespace around its leading
		# slash. There is no left operand here; later segments retain raw spelling
		# or their comments and line continuations, keeping plain division outside.
		if cursor < len(tokens) and tokens[cursor].value == "/":
			cursor = after_continuation.get(cursor + 1, cursor + 1)
		if cursor >= len(tokens) or not name(cursor):
			continue
		node_receiver_starts.add(cursor)
		while cursor + 1 < len(tokens):
			slash = after_continuation.get(cursor + 1, cursor + 1)
			if slash >= len(tokens) or tokens[slash].value != "/":
				break
			child = after_continuation.get(slash + 1, slash + 1)
			if child >= len(tokens) or not name(child):
				break
			# Continuations and cross-line gaps (including line comments) protect
			# this physical path segment. Plain same-line spacing stays division.
			if not (
				slash > cursor + 1 or child > slash + 1
				or tokens[cursor].end_line < tokens[slash].line
				or tokens[slash].end_line < tokens[child].line
				or (tokens[cursor].end == tokens[slash].start and tokens[slash].end == tokens[child].start)
			):
				break
			cursor = child
			node_receiver_starts.add(cursor)

	def complete_group(start: int, end: int) -> bool:
		group = by_open.get(start)
		return (
			group is not None and group.kind == "group" and group.close_index == end - 1
			and group.items == ((start + 1, end - 1),)
		)

	def literal(start: int, end: int, depth: int = 0) -> bool:
		key = start, end
		if key in literal_cache:
			return literal_cache[key]
		if start >= end or depth > MAX_GROUP_DEPTH:
			return False
		if complete_group(start, end):
			result = literal(start + 1, end - 1, depth + 1)
		else:
			result = end == start + 1 and string_literal(start)
		literal_cache[key] = result
		return result

	def scalar(start: int, end: int, depth: int = 0) -> int | None:
		key = start, end
		if key in scalar_cache:
			return scalar_cache[key]
		if start >= end or depth > MAX_GROUP_DEPTH:
			return None
		result: int | None = None
		first = tokens[start]
		if complete_group(start, end):
			result = scalar(start + 1, end - 1, depth + 1)
		elif first.value in unary:
			if scalar(start + 1, end, depth + 1) == 0:
				result = 1
		elif end == start + 1:
			if string_literal(start) or first.kind == "number" or name(start) or first.value in {"true", "false", "null"}:
				result = 0
		elif name(start):
			cursor = start + 1
			while cursor + 1 < end and tokens[cursor].value == "." and name(cursor + 1):
				cursor += 2
			if cursor == end:
				result = 0
		scalar_cache[key] = result
		return result

	def formatted(start: int, end: int, depth: int = 0) -> bool:
		key = start, end
		if key in format_cache:
			return format_cache[key]
		if start >= end or depth > MAX_GROUP_DEPTH:
			return False
		if complete_group(start, end):
			result = formatted(start + 1, end - 1, depth + 1)
		else:
			indexes = percents.get(parents[start], [])
			left, right = bisect_right(indexes, start - 1), bisect_right(indexes, end - 1)
			result = False
			if right - left == 1:
				separator = indexes[left]
				result = literal(start, separator) and scalar(separator + 1, end) is not None
		format_cache[key] = result
		return result

	def physical_structure_free(start: int, end: int) -> bool:
		return (
			tokens[start].line not in comment_lines and tokens[end - 1].end_line not in comment_lines
			and barrier_free(start, end)
		)

	spans: list[SimpleFormatLayoutSpan] = []
	matched: set[tuple[int, int]] = set()
	for start, end in sorted(candidates):
		if start >= end or not formatted(start, end) or not physical_structure_free(start, end):
			continue
		first, last = tokens[start], tokens[end - 1]
		matched.add((start, end))
		spans.append(SimpleFormatLayoutSpan(
			start, end, first.start, last.end, first.line, last.end_line, "expression",
		))
	for call in groups:
		if call.kind != "call" or len(call.items) != 1 or call.items[0] not in matched:
			continue
		if call.items[0][0] != call.open_index + 1:
			continue
		start = call.open_index - 1
		if start < 0 or not name(start):
			continue
		while start >= 2 and tokens[start - 1].value == "." and name(start - 2):
			start -= 2
		if start in node_receiver_starts or (start > 0 and tokens[start - 1].value == "."):
			continue
		end = call.close_index + 1
		if not physical_structure_free(start, end):
			continue
		first, last = tokens[start], tokens[end - 1]
		spans.append(SimpleFormatLayoutSpan(
			start, end, first.start, last.end, first.line, last.end_line, "call",
		))
	return tuple(sorted(spans, key=lambda span: (span.start_index, -span.end_index)))


def _cast_type_reader(view: LexedSource) -> Callable[[int], int | None]:
	"""Read only a nominal type or one native-supported typed collection layer."""
	tokens = view.tokens
	groups = {group.open_index: group for group in view.groups}
	cache: dict[int, int | None] = {}
	reserved = {
		"as", "is", "in", "and", "or", "not", "if", "elif", "else", "while",
		"for", "match", "return", "await", "func", "signal", "class", "var",
		"const", "static", "enum", "extends", "class_name", "pass", "break",
		"continue", "true", "false", "null", "self", "super", "void",
	}

	def nominal(start: int, limit: int) -> int | None:
		if start >= limit or tokens[start].kind != "identifier" or tokens[start].value in reserved:
			return None
		cursor = start + 1
		while cursor + 1 < limit and tokens[cursor].value == ".":
			member = tokens[cursor + 1]
			if member.kind != "identifier" or member.value in reserved:
				return None
			cursor += 2
		return cursor

	def read(start: int) -> int | None:
		if start in cache:
			return cache[start]
		end = nominal(start, len(tokens))
		if end is not None and end < len(tokens) and tokens[end].value == "[":
			group = groups.get(end)
			arity = {"Array": 1, "Dictionary": 2}.get(tokens[start].value)
			if (
				end != start + 1 or group is None or arity is None
				or len(group.items) != arity
				or tokens[group.close_index - 1].value == ","
				or any(nominal(left, right) != right for left, right in group.items)
			):
				end = None
			else:
				end = group.close_index + 1
		cache[start] = end
		return end

	return read


def cast_layout_spans(view: LexedSource) -> tuple[CastLayoutSpan, ...]:
	"""Find closed-operand casts without widening expression or lambda scope."""
	if view.issues:
		return ()
	tokens, groups = view.tokens, view.groups
	by_open = {group.open_index: group for group in groups}
	by_close = {group.close_index: group for group in groups}
	read_type = _cast_type_reader(view)
	identifier, _atom, barrier_free = _atomic_layout_matcher(view)
	lambda_prefix = [0]
	for token in tokens:
		lambda_prefix.append(lambda_prefix[-1] + int(token.kind == "identifier" and token.value == "func"))
	callee_cache: dict[int, int | None] = {}
	item_start_cache: dict[int, tuple[int, ...]] = {}

	def callee_start(group: Group) -> int | None:
		if group.open_index in callee_cache:
			return callee_cache[group.open_index]
		cursor = group.open_index - 1
		result = None
		if cursor >= 0 and identifier(cursor):
			while cursor >= 2 and tokens[cursor - 1].value == "." and identifier(cursor - 2):
				cursor -= 2
			if cursor == 0 or tokens[cursor - 1].value != ".":
				result = cursor
		callee_cache[group.open_index] = result
		return result

	def complete_value(start: int, end: int, parent_index: int | None) -> bool:
		if end < len(tokens) and tokens[end].value in {".", "[", "("}:
			return False
		if parent_index is not None:
			parent = groups[parent_index]
			if parent.kind != "call":
				return False
			if parent.open_index not in item_start_cache:
				item_start_cache[parent.open_index] = tuple(left for left, _right in parent.items)
			starts = item_start_cache[parent.open_index]
			item = bisect_right(starts, start) - 1
			return item >= 0 and parent.items[item] == (start, end)
		if end < len(tokens) and tokens[end].line == tokens[end - 1].end_line:
			return False
		if start == 0 or tokens[start - 1].value not in {"=", ":=", "return"}:
			return False
		first = tokens[start]
		prefix = view.lines[first.line - 1][:first.column - 1].strip()
		if tokens[start - 1].value == "return":
			return prefix == "return"
		return prefix.endswith(("=", ":=")) and not prefix.startswith(("if ", "while ", "for ", "func "))

	spans: list[CastLayoutSpan] = []
	for cast_index, token in enumerate(tokens):
		if token.kind != "identifier" or token.value != "as" or cast_index == 0:
			continue
		operand = by_close.get(cast_index - 1)
		if operand is None or operand.kind not in {"call", "group", "array", "dictionary", "index"}:
			continue
		type_end = read_type(cast_index + 1)
		if type_end is None:
			continue
		call = operand
		operand_layers: list[Group] = []
		while call.kind == "group":
			inner = by_open.get(call.open_index + 1)
			if inner is None:
				inner = by_close.get(call.close_index - 1)
				if inner is not None and (inner.kind != "call" or callee_start(inner) != call.open_index + 1):
					inner = None
			if inner is None or inner.close_index != call.close_index - 1:
				break
			operand_layers.append(call)
			call = inner
		callee = callee_start(call) if call.kind == "call" else None
		start = operand.open_index if operand_layers or callee is None else callee
		end = type_end
		cast_layers: list[Group] = []
		while start > 0:
			wrapper = by_open.get(start - 1)
			if wrapper is None or wrapper.kind != "group" or wrapper.close_index != end:
				break
			cast_layers.append(wrapper)
			start, end = wrapper.open_index, wrapper.close_index + 1
		parent_index = cast_layers[-1].parent_index if cast_layers else operand.parent_index
		removable_operand: tuple[int, ...] = ()
		removable_cast: tuple[int, ...] = ()
		if (
			callee is not None and barrier_free(start, end)
			and lambda_prefix[end] == lambda_prefix[start]
			and complete_value(start, end, parent_index)
		):
			removable_operand = tuple(group.open_index for group in operand_layers)
			removable_cast = tuple(group.open_index for group in cast_layers)
		spans.append(CastLayoutSpan(
			start, end, tokens[start].start, tokens[end - 1].end,
			operand.close_index, cast_index, cast_index + 1, type_end,
			barrier_free(operand.close_index, type_end),
			call.open_index if callee is not None else None, callee,
			removable_operand, removable_cast,
		))
	return tuple(spans)


def _call_closing_suffix_allowed(
	view: LexedSource, group: Group, read_cast_type: Callable[[int], int | None],
	group_by_close: dict[int, Group], group_by_open: dict[int, Group],
) -> bool:
	"""Recognize a finite expression suffix after an expanded value's close.

	This is a layout boundary proof, not a replacement language parser. Operator
	suffixes need a possible expression operand, postfix delimiters need their
	matched group, and a cast prefix retains the existing bounded type reader.
	Another expanded layer's close on this physical line is always rejected.
	"""
	tokens = view.tokens
	opening = group.open_index
	member_call = (
		opening >= 2 and tokens[opening - 1].kind == "identifier"
		and tokens[opening - 2].value == "."
	)
	if (
		(group.kind not in {"call", "array", "dictionary", "index"} and not member_call)
		or (opening >= 2 and tokens[opening - 2].value == "@")
	):
		return False
	start = group.close_index + 1
	if start >= len(tokens):
		return False
	closing_line = tokens[group.close_index].line
	line_end = start
	while line_end < len(tokens) and tokens[line_end].line == closing_line:
		other = group_by_close.get(line_end)
		if other is not None and tokens[other.open_index].line != closing_line:
			return False
		line_end += 1
	if start == line_end:
		return False
	cast_prefix = tokens[start].value == "as"
	if cast_prefix:
		type_end = read_cast_type(start + 1)
		if type_end is None or tokens[type_end - 1].end_line != closing_line:
			return False
		start = type_end
		if start >= line_end:
			return True

	def operand_start(index: int) -> bool:
		if index >= len(tokens):
			return False
		token = tokens[index]
		if token.kind in {"number", "string"}:
			return True
		if token.kind == "identifier":
			return token.value not in {
				"if", "elif", "else", "for", "while", "match", "return", "var",
				"const", "signal", "enum", "class", "class_name", "extends",
				"static", "and", "or", "in", "is", "as", "pass", "break",
				"continue", "breakpoint",
			}
		return token.kind == "symbol" and token.value in {
			"+", "-", "~", "!", "(", "[", "{", "$", "%", "^", "&",
		}

	first = tokens[start]
	if first.kind == "symbol" and first.value == ".":
		return not cast_prefix and start + 1 < len(tokens) and tokens[start + 1].kind == "identifier"
	if first.kind == "symbol" and first.value in {"(", "["}:
		postfix = group_by_open.get(start)
		return not cast_prefix and postfix is not None and postfix.kind == {"(": "call", "[": "index"}[first.value]
	if first.kind == "symbol" and first.value in {
		"**", "*", "/", "%", "+", "-", "<<", ">>", "&", "^", "|",
		"==", "!=", "<", ">", "<=", ">=", "&&", "||",
	}:
		return operand_start(start + 1)
	if first.kind == "identifier" and first.value in {"and", "or", "in", "is", "if", "else"}:
		return operand_start(start + 1)
	if first.kind == "identifier" and first.value == "not":
		return (
			start + 1 < len(tokens) and tokens[start + 1].value == "in"
			and operand_start(start + 2)
		)
	return False


def audit_source(path: str, text: str) -> list[dict[str, Any]]:
	"""Return every observed violation, or a hard failure for incomplete input."""
	view = lex_source(path, text)
	if view.issues:
		return list(view.issues)
	analysis = _SourceAnalysis()
	try:
		return _audit_source_view(path, text, replace(view, _analysis=analysis))
	finally:
		analysis.close()


def _audit_source_view(path: str, text: str, view: LexedSource) -> list[dict[str, Any]]:
	"""Audit a complete lexical view using its invocation-owned derived inputs."""
	issues: list[dict[str, Any]] = []
	tokens, groups = view.tokens, view.groups
	from gf_gdscript_expression_layout import effective_group_kinds
	effective_kinds = effective_group_kinds(view)
	by_line: dict[int, list[int]] = {}
	for index, token in enumerate(tokens):
		by_line.setdefault(token.line, []).append(index)
	structural, multiline = scan_gdscript_structure(list(view.lines))
	if text.startswith("\ufeff"):
		issues.append(_issue(path, "text_format", 1, 1, "UTF-8 BOM is not allowed."))
	if "\r" in text:
		issues.append(_issue(path, "text_format", 1, 1, "Use LF line endings."))
	if text and not text.endswith("\n"):
		issues.append(_issue(path, "text_format", len(view.lines), 1, "End source with LF."))
	group_by_open = {group.open_index: group for group in groups}
	group_by_close = {group.close_index: group for group in groups}
	parents: dict[int, int] = {}
	nonempty_descendants: set[int] = set()
	for number, group in enumerate(groups):
		for index in range(group.open_index + 1, group.close_index):
			parents[index] = number
		if effective_kinds[number] in {"array", "dictionary"} and group.items:
			ancestor = group.parent_index
			while ancestor is not None:
				nonempty_descendants.add(ancestor)
				ancestor = groups[ancestor].parent_index

	def add(rule: str, token: Token, message: str, suggestion: str) -> None:
		issues.append(_issue(path, rule, token.line, token.column, message, suggestion))

	for span in simple_call_layout_spans(view):
		if span.line != span.end_line:
			add(
				"simple_call_layout", tokens[span.callee_start_index],
				"A simple call with zero or one atomic argument must use one line.",
				"Join the call without changing its tokens, literal payload or comments.",
			)

	for span in dictionary_entry_layout_spans(view):
		if span.migration_safe and (
			tokens[span.key_start_index].line != tokens[span.separator_index].line
			or tokens[span.separator_index].line != tokens[span.value_start_index].line
		):
			add(
				"dictionary_entry_layout", tokens[span.separator_index],
				"Keep a single-line dictionary key, its separator and its value's first token on one line.",
				"Join only this field header; preserve the value's independent child layout.",
			)

	multi_call_spans = multi_argument_call_layout_spans(view)
	multi_call_open_indexes = {span.open_index for span in multi_call_spans}
	for span in multi_call_spans:
		if not span.migration_safe:
			continue
		if span.expected_layout == "inline":
			if span.line != span.end_line:
				add(
					"multi_argument_call_layout", tokens[span.open_index],
					"A call with exactly two atomic arguments must keep its argument region on one line.",
					"Join only the argument region; preserve the receiver, tokens and optional comma.",
				)
			continue
		previous_end = tokens[span.open_index].end_line
		separate = True
		for start, end in span.items:
			if tokens[start].line <= previous_end:
				separate = False
			previous_end = tokens[end - 1].end_line
		if tokens[span.close_index].line <= previous_end:
			separate = False
		if not separate:
			add(
				"multi_argument_call_layout", tokens[span.open_index],
				"A call with three or more arguments, or two including a non-atomic argument, must use expanded layout.",
				"Start each direct argument below the opener and close below the final argument; preserve each argument's child structure.",
			)

	for span in atomic_group_layout_spans(view):
		if span.line != span.end_line:
			add(
				"atomic_group_layout", tokens[span.open_index],
				"A group containing one atomic expression must use one line.",
				"Join the group while preserving its parentheses, tokens and literal payload.",
			)

	for span in simple_string_layout_spans(view):
		if span.line != span.end_line:
			add(
				"simple_string_layout", tokens[span.start_index],
				"A complete flat string addition chain must use one line.",
				"Join only whitespace; preserve literal spelling, operators and all grouping parentheses.",
			)

	format_covered_end = -1
	for span in simple_format_layout_spans(view):
		if span.line == span.end_line or span.end_index <= format_covered_end:
			continue
		format_covered_end = span.end_index
		add(
			"simple_format_layout", tokens[span.start_index],
			"A complete simple String format expression or its plain single-argument call must use one line.",
			"Join only whitespace; preserve literal spelling, operators, commas and all grouping parentheses.",
		)

	for span in argument_group_layout_spans(view):
		add(
			"argument_group_layout", tokens[span.open_index],
			"A complete multiline call argument has redundant expression grouping.",
			"Remove only whole-argument group layers; preserve inner groups, tokens and evaluation order.",
		)

	for span in call_group_layout_spans(view):
		add(
			"call_group_layout", tokens[span.open_index],
			"A complete assignment or return value has redundant grouping around a plain call.",
			"Remove only whole-value group layers; preserve the callee, call arguments and evaluation order.",
		)

	for span in cast_layout_spans(view):
		if span.attachment_allowed and (
			tokens[span.operand_close_index].end_line != tokens[span.cast_index].line
			or tokens[span.operand_close_index].end_line != tokens[span.type_end_index - 1].end_line
		):
			add("cast_layout", tokens[span.cast_index],
				"Keep as Type on the same line as its operand's closing delimiter.",
				"Attach only the unchanged cast suffix; preserve the operand's structure.")
		redundant = span.redundant_operand_group_open_indexes + span.redundant_cast_group_open_indexes
		if redundant:
			add("cast_layout", tokens[min(redundant)],
				"This direct-call cast has redundant expression grouping.",
				"Remove only these whole-call or whole-value group layers; preserve arguments, cast and precedence.")

	line_indents: dict[int, int] = {}
	for number, raw in enumerate(view.lines, 1):
		prefix = re.match(r"[\t ]*", raw).group()
		line_indents[number] = len(prefix) - len(prefix.lstrip("\t"))
		line_tokens = [tokens[index] for index in by_line.get(number, [])]
		if not multiline[number - 1] and " " in prefix and (structural[number - 1].strip() or line_tokens):
			issues.append(_issue(path, "text_format", number, 1, "Use Tab indentation."))
	function_colons: dict[int, int] = {}
	for index, token in enumerate(tokens):
		if token.kind == "symbol" and token.value == "." and index + 1 < len(tokens):
			member = tokens[index + 1]
			if member.kind == "identifier" and member.start != token.end:
				add(
					"member_access_spacing", member,
					"A member name must immediately follow its access dot.",
					"Keep .member together; a leading .member continuation may remain.",
				)
		if token.kind == "symbol" and token.value == ";":
			add("statement_separator", token, "Multiple statements on one line are prohibited.",
				"Put each statement on its own line.")
		if token.value == "func" and token.kind == "identifier":
			opening = index + 1
			if opening < len(tokens) and tokens[opening].kind == "identifier":
				opening += 1
			group = group_by_open.get(opening)
			if group:
				colon = _header_colon(tokens, index, group_by_open)
				if colon is not None:
					function_colons[index] = colon
					_check_inline(path, tokens, colon, issues)
	match_scopes: list[tuple[int, int, int | None]] = []
	layer_groups: set[int] = set()
	boolean_spans = boolean_layout_spans(view)
	boolean_scope = _boolean_scope_view(view)
	if boolean_scope is None:
		issues.append(_issue(path, "source_budget", 1, 1,
			"Boolean statement-role closure budget exhausted."))
		return sorted(issues, key=lambda item: (item["line"], item["column"], item["rule"]))
	boolean_kinds = boolean_scope[-1]
	required_boolean_operators = sorted({
		index for span in boolean_spans for index in span.operator_indexes
	})
	boolean_index_carriers: set[int] = set()
	for number, group in enumerate(groups):
		if boolean_kinds[number] == "index" and group.kind == "array" and (
			bisect_right(required_boolean_operators, group.close_index - 1)
			> bisect_right(required_boolean_operators, group.open_index)
		):
			# Only a real index containing this rule's required work escapes its
			# false array classification. Actual arrays retain every array rule;
			# child-domain operators never enter the index's own term count.
			boolean_index_carriers.add(group.open_index)
	for number, indexes in by_line.items():
		first = tokens[indexes[0]]
		ambient_parent = parents.get(indexes[0])
		indent = line_indents[number]
		while (
			match_scopes
			and number > match_scopes[-1][1]
			and ambient_parent == match_scopes[-1][2]
			and indent <= match_scopes[-1][0]
		):
			match_scopes.pop()
		match_arm = bool(
			match_scopes
			and number > match_scopes[-1][1]
			and ambient_parent == match_scopes[-1][2]
			and indent == match_scopes[-1][0] + 1
		)
		if first.value in _CONTROL or first.value in {"get", "set"}:
			colon = _header_colon(tokens, indexes[0], group_by_open)
			if colon is not None:
				_check_inline(path, tokens, colon, issues)
				if first.value == "match":
					match_scopes.append((indent, tokens[colon].line, ambient_parent))
		# match arms are indented and end in a colon. Type annotations and
		# dictionary fields are already enclosed by their literal groups.
		elif match_arm or (first.column > 1 and first.value not in {
			"var", "const", "@", "func", "static", "signal", "class", "extends", "enum",
		}):
			colon = _header_colon(tokens, indexes[0], group_by_open)
			if colon is not None and (match_arm or indexes[0] not in parents):
				_check_inline(path, tokens, colon, issues)
	item_starts = {group.open_index: tuple(start for start, _end in group.items) for group in groups}
	parent_lambda_colons: dict[tuple[int, int], int | None] = {}
	read_cast_type = _cast_type_reader(view)
	for group_number, group in enumerate(groups):
		if group.open_index in boolean_index_carriers:
			# This is a proven Boolean index, not an array literal requiring a comma.
			# Its own carrier/layer checks below retain closure and indentation.
			continue
		layout_kind = "call" if group.open_index in multi_call_open_indexes else effective_kinds[group_number]
		opener, closer = tokens[group.open_index], tokens[group.close_index]
		expression_parent = group.parent_index is not None
		if group.parent_index is not None:
			parent = groups[group.parent_index]
			parent_item = bisect_right(item_starts[parent.open_index], group.open_index) - 1
			if parent_item >= 0:
				parent_key = (parent.open_index, parent_item)
				if parent_key not in parent_lambda_colons:
					parent_start = parent.items[parent_item][0]
					if parent.kind == "dictionary":
						cursor = parent_start
						while cursor < parent.items[parent_item][1]:
							key_group = group_by_open.get(cursor)
							if key_group is not None:
								cursor = key_group.close_index + 1
							elif tokens[cursor].value in {":", "="}:
								parent_start = cursor + 1
								break
							else:
								cursor += 1
					while (
						parent_start < parent.items[parent_item][1]
						and tokens[parent_start].value == "\\"
					):
						parent_start += 1
					parent_lambda_colons[parent_key] = function_colons.get(parent_start)
				outer_colon = parent_lambda_colons[parent_key]
				if outer_colon is not None and outer_colon < group.open_index:
					# An enclosing lambda's body contains independent statements.
					expression_parent = False
		if layout_kind == "call" and expression_parent and group.items:
			start, _end = group.items[-1]
			while start < _end and tokens[start].value == "\\":
				start += 1
			if start + 1 < _end and tokens[start].value == "func" and tokens[start + 1].value == "(":
				colon = _header_colon(tokens, start, group_by_open)
				if (
					colon is not None and colon + 1 < group.close_index
					and tokens[colon + 1].line > tokens[colon].line
					and tokens[group.close_index - 1].value != ","
				):
					add("lambda_argument_separator", tokens[group.close_index - 1],
						"A nested call's final multiline lambda argument needs a terminating comma.",
						"Add the comma after the lambda's last body token, before any comment.")
		nonempty_nested = group_number in nonempty_descendants
		enum_group = layout_kind == "enum"
		if enum_group and group.items and opener.line == closer.line:
			add("enum_layout", opener, "Each enum member needs its own expanded declaration line.",
				"Put each enum member below the opener, indented by one Tab.")
		if layout_kind in {"array", "dictionary"}:
			expanded = nonempty_nested or (
				layout_kind == "dictionary" and len(group.items) > MAX_INLINE_DICTIONARY_FIELDS
			)
			if expanded and opener.line == closer.line:
				add("dictionary_layout", opener, "This container must use expanded layout.",
					"Put items and nested nonempty containers on separate lines.")
			if layout_kind == "dictionary" and group.items and opener.line == closer.line:
				if text[opener.end:opener.end + 1] != " " or text[closer.start - 1:closer.start] != " ":
					add("dictionary_spacing", opener, "Put a space inside each side of a nonempty inline dictionary.",
						'Use { "key": value } for a permitted short inline dictionary.')
		if opener.line == closer.line or layout_kind not in {"call", "parameters", "array", "dictionary", "enum"}:
			continue
		item_rule = "enum_layout" if enum_group else "multiline_items"
		indent_rule = "enum_layout" if enum_group else "continuation_indentation"
		closing_rule = "enum_layout" if enum_group else "closing_delimiter"
		previous_end = opener.line
		opening_indent = line_indents[opener.line]
		for start, end in group.items:
			item_first, item_last = tokens[start], tokens[end - 1]
			if item_first.line <= previous_end:
				add(item_rule, item_first, "Multiline arguments/items must each start on a separate line.",
					"Move this argument/item to its own line.")
			previous_end = item_last.end_line
			item_indent = line_indents[item_first.line]
			if item_first.line != opener.line and item_indent != opening_indent + 1:
				add(indent_rule, item_first, "Indent each direct multiline argument/item by one Tab.",
					"Use one continuation level relative to this opener.")
		closing_indexes = by_line.get(closer.line, [])
		preceding = [tokens[index] for index in closing_indexes if index < group.close_index]
		following = [tokens[index] for index in closing_indexes if index > group.close_index]
		allowed_suffix = not following or following[0].value in {",", ":"} or (
			layout_kind == "parameters" and following[0].value == "->"
		)
		if following and following[0].value == "as" and layout_kind in {"call", "array", "dictionary"}:
			type_end = read_cast_type(group.close_index + 2)
			if type_end is not None and tokens[type_end - 1].end_line == closer.line:
				tail = [tokens[index] for index in closing_indexes if index >= type_end]
				allowed_suffix = not tail or tail[0].value in {",", ":"}
		if following and not allowed_suffix:
			allowed_suffix = _call_closing_suffix_allowed(
				view, group, read_cast_type, group_by_close, group_by_open,
			)
		value_ends_on_close = (
			group.close_index > group.open_index + 1
			and tokens[group.close_index - 1].end_line == closer.line
		)
		if preceding or value_ends_on_close or not allowed_suffix:
			add(closing_rule, closer, "Close a multiline call/container/enum on a separate line.",
				"Move the closing delimiter below the final item.")
		closing_indent = line_indents[closer.line]
		if closing_indent != opening_indent:
			add(indent_rule, closer,
				"Align a multiline closing delimiter with its opener's indentation.",
				"Close this layer at its own base indentation.")
		if layout_kind in {"array", "dictionary"} and group.items and tokens[group.close_index - 1].value != ",":
			add("trailing_comma", closer, "A multiline container needs a final comma.",
				"Add a comma after the final array item or dictionary field.")
	_check_boolean_layout(path, view, parents, by_line, line_indents, layer_groups, issues,
		boolean_spans, boolean_kinds)
	_check_ternaries(path, view, parents, issues, layer_groups)
	_check_expression_layers(path, view, parents, by_line, line_indents, layer_groups, issues)
	try:
		blank_boundaries = _blank_layout_boundaries(view, parents, by_line, line_indents)
	except ValueError:
		blank_boundaries = []
		issues.append(_issue(path, "source_budget", 1, 1, "Declaration depth budget exhausted."))
	for boundary in blank_boundaries:
		if boundary.stop_line - boundary.start_line != boundary.expected:
			issues.append(_issue(
				path, boundary.rule, boundary.stop_line, 1,
				f"Use exactly {boundary.expected} blank line(s) at this declaration boundary.",
				"Adjust only blank code lines; preserve the comment and declaration blocks.",
			))
	_check_canonical_layout(path, view, issues)
	if len(issues) > MAX_ISSUES:
		issues = issues[:MAX_ISSUES - 1] + [_issue(path, "issue_budget", 1, 1,
												"Diagnostic budget exhausted.")]
	return sorted(issues, key=lambda item: (item["line"], item["column"], item["rule"]))


def _check_canonical_layout(path: str, view: LexedSource, issues: list[dict[str, Any]]) -> None:
	"""Consume the same bounded layout decisions used by source migrations."""
	from gf_gdscript_list_layout import layout_edits as list_edits
	from gf_gdscript_expression_layout import layout_edits as expression_edits
	from gf_gdscript_layout_integrity import audit_issues as integrity_issues
	starts = [0]
	starts.extend(index + 1 for index, value in enumerate(view.source) if value == "\n")
	observed: set[tuple[str, int]] = set()
	for planner in (list_edits, expression_edits):
		for edit in planner(view, max_inline_items=MAX_INLINE_LIST_ITEMS):
			if not 0 <= edit.start <= edit.end <= len(view.source) or edit.rule not in RULES:
				raise ValueError("Invalid canonical layout decision.")
			line = bisect_right(starts, edit.start)
			key = (edit.rule, line)
			if key in observed:
				continue
			observed.add(key)
			issues.append(_issue(path, edit.rule, line, edit.start - starts[line - 1] + 1,
				"This syntax structure does not use its canonical layout.",
				"Apply the structure's item count, child layout and continuation hierarchy; preserve comments and literal payloads."))
	issues.extend(integrity_issues(path, view))


def _header_colon(tokens: tuple[Token, ...], start: int,
				  group_by_open: dict[int, Group]) -> int | None:
	cursor = start
	header_line = tokens[start].line
	awaiting_in = tokens[start].value == "for"
	while cursor < len(tokens):
		token = tokens[cursor]
		continued = cursor > start and tokens[cursor - 1].value == "\\"
		if cursor > start and token.line > header_line and not continued:
			# A parenthesized header is skipped below as a complete group.
			return None
		if cursor in group_by_open:
			closing = group_by_open[cursor].close_index
			header_line = tokens[closing].line
			cursor = closing + 1
			continue
		if token.value == "in" and awaiting_in:
			awaiting_in = False
		header_line = token.line
		if token.value == ":" and not awaiting_in:
			return cursor
		cursor += 1
	return None


def _check_inline(path: str, tokens: tuple[Token, ...], colon: int,
				  issues: list[dict[str, Any]]) -> None:
	if (
		colon + 1 < len(tokens)
		and tokens[colon + 1].line == tokens[colon].line
		and tokens[colon + 1].value not in {",", ")", "]", "}"}
	):
		token = tokens[colon + 1]
		issues.append(_issue(path, "inline_body", token.line, token.column,
							 "A block body must start on the next line.",
							 "Expand this body while preserving its indentation scope."))


def _check_boolean_layout(
	path: str, view: LexedSource, parents: dict[int, int],
	by_line: dict[int, list[int]], line_indents: dict[int, int],
	layer_groups: set[int], issues: list[dict[str, Any]],
	spans: tuple[BooleanLayoutSpan, ...], kinds: tuple[str, ...],
) -> None:
	"""Apply the same complete-domain contract used by mechanical migrations."""
	by_open = {group.open_index: group for group in view.groups}
	group_numbers = {group.open_index: number for number, group in enumerate(view.groups)}
	first_non_open = {
		line: next((index for index in indexes if view.tokens[index].value != "("), None)
		for line, indexes in by_line.items()
	}
	for span in spans:
		first = view.tokens[span.start_index]
		bad = span.line == span.end_line or span.needs_outer_group or "unproven_domain" in span.barriers
		for opening in span.layer_group_open_indexes:
			group = by_open[opening]
			layer_groups.add(group_numbers[opening])
			if view.tokens[opening].line == view.tokens[opening + 1].line:
				bad = True
		if span.carrier_open_index is not None:
			carrier = by_open[span.carrier_open_index]
			carrier_kind = kinds[group_numbers[carrier.open_index]]
			if carrier_kind == "group" or span.context == "match_when":
				layer_groups.add(group_numbers[carrier.open_index])
			elif carrier_kind == "index":
				# The general multiline-item rule deliberately excludes index syntax.
				# Only an index acting as this proven Boolean carrier needs these closes.
				opener, closer = view.tokens[carrier.open_index], view.tokens[carrier.close_index]
				if opener.line == first.line:
					bad = True
				elif line_indents[first.line] != line_indents[opener.line] + 1:
					issues.append(_issue(
						path, "continuation_indentation", first.line, first.column,
						"Indent the first Boolean index operand relative to its opener.",
						"Use one Tab inside this Boolean continuation bracket.",
					))
				if by_line[closer.line][0] != carrier.close_index:
					issues.append(_issue(
						path, "closing_delimiter", closer.line, closer.column,
						"Close a Boolean continuation index on its own structural line.",
						"Separate the closing bracket from the final operand.",
					))
				if line_indents[closer.line] != line_indents[opener.line]:
					issues.append(_issue(
						path, "continuation_indentation", closer.line, closer.column,
						"Align this Boolean continuation index with its opener's indentation.",
						"Close the bracket at its own base indentation.",
					))
		for index in span.operator_indexes:
			token = view.tokens[index]
			earlier = first_non_open[token.line]
			if earlier is not None and earlier < index:
				bad = True
			owner = parents.get(index)
			if owner is not None and span.carrier_open_index is not None:
				opener = view.tokens[view.groups[owner].open_index]
				if token.line != opener.line and line_indents[token.line] != line_indents[opener.line] + 1:
					issues.append(_issue(
						path, "continuation_indentation", token.line, token.column,
						"Indent each Boolean operand relative to its own continuation carrier.",
						"Use one Tab inside the existing delimiter or required expression group.",
					))
		if bad:
			issues.append(_issue(
				path, "condition_layout", first.line, first.column,
				"Three or more Boolean terms require hierarchical multiline layout.",
				"Keep every existing group and operator in order; expand each and/or operand at its own layer.",
			))


def _check_ternaries(path: str, view: LexedSource, parents: dict[int, int],
					 issues: list[dict[str, Any]], layer_groups: set[int]) -> None:
	# Conditional and lambda keywords are operators only outside proven names.
	scope = _boolean_scope_view(view)
	if scope is None:
		_first, statement_starts = _independent_statement_starts(view)
		names = _boolean_name_roles(view, statement_starts)
	else:
		names = scope[4]
	candidates: dict[tuple[int, int, int, int], list[int]] = {}
	lambda_domains: dict[tuple[int, int], dict[int, int]] = {}
	dictionary_separators: dict[tuple[int, int], int | None] = {}
	group_by_open = {group.open_index: group for group in view.groups}
	statement_lines: dict[int, int] = {}
	depth = 0
	previous: Token | None = None
	statement_line = 1
	for number, value in enumerate(view.tokens):
		if previous is None or (value.line > previous.end_line and depth == 0 and previous.value != "\\"):
			statement_line = value.line
		statement_lines[number] = statement_line
		if value.kind == "symbol" and value.value in _OPEN:
			depth += 1
		elif value.kind == "symbol" and value.value in _CLOSE:
			depth -= 1
		previous = value
	by_line: dict[int, list[Token]] = {}
	for token in view.tokens:
		by_line.setdefault(token.line, []).append(token)
	first_non_open = {
		line: next((token for token in values if token.value != "("), None)
		for line, values in by_line.items()
	}
	item_starts = {
		index: [span[0] for span in group.items]
		for index, group in enumerate(view.groups)
	}
	for index, token in enumerate(view.tokens):
		if index in names or token.value != "if" or token.kind != "identifier":
			continue
		preceding = view.tokens[index - 1] if index and view.tokens[index - 1].line == token.line else None
		if preceding is None and _header_colon(view.tokens, index, group_by_open) is not None:
			continue
		if preceding is not None and preceding.value in {"else", "elif"} and index - 1 not in names:
			continue
		parent = parents.get(index)
		root = parent
		while root is not None and view.groups[root].kind == "group" and view.groups[root].parent_index is not None:
			root = view.groups[root].parent_index
		if root is None:
			key = (-statement_lines[index], 0, 0, 0)
		else:
			domain = view.groups[root]
			if domain.kind == "group" and domain.parent_index is None:
				key = (-statement_lines[domain.open_index], 0, 0, 0)
			else:
				item = bisect_right(item_starts[root], index) - 1
				if item >= 0 and index >= domain.items[item][1]:
					item = -1
				anchor = 0
				side = 0
				if item >= 0:
					domain_key = (root, item)
					if domain.kind == "dictionary":
						if domain_key not in dictionary_separators:
							cursor, stop = domain.items[item]
							separator = None
							while cursor < stop:
								child = group_by_open.get(cursor)
								if child is not None:
									cursor = child.close_index + 1
								elif view.tokens[cursor].kind == "symbol" and view.tokens[cursor].value in {":", "="}:
									separator = cursor
									break
								else:
									cursor += 1
							dictionary_separators[domain_key] = separator
						separator = dictionary_separators[domain_key]
						# A field contains two independent expression domains. Its
						# key and value conditionals do not nest in one another.
						side = int(separator is not None and index > separator)
					if domain_key not in lambda_domains:
						span_start, span_end = domain.items[item]
						lambda_seen = False
						lambda_parent: int | None = None
						current_anchor = 0
						anchors: dict[int, int] = {}
						for position in range(span_start, span_end):
							value = view.tokens[position]
							if value.value == "func" and position not in names:
								lambda_seen = True
								lambda_parent = parents.get(position)
							previous_token = view.tokens[position - 1] if position else None
							if (
								lambda_seen
								and by_line[value.line][0] is value
								and parents.get(position) == lambda_parent
								and previous_token is not None
								and previous_token.end_line < value.line
								and previous_token.value != "\\"
							):
								current_anchor = value.line
							if value.value == "if" and position not in names:
								anchors[position] = current_anchor
						lambda_domains[domain_key] = anchors
					anchor = lambda_domains[domain_key].get(index, 0)
				key = (root, item, side, anchor)
		candidates.setdefault(key, []).append(index)
	for indexes in candidates.values():
		if len(indexes) < 2:
			continue
		parent_counts = Counter(parents.get(index) for index in indexes)
		nested = any(count > 1 for count in parent_counts.values())
		for parent in parent_counts:
			ancestor = view.groups[parent].parent_index if parent is not None else None
			while parent is not None:
				if ancestor in parent_counts:
					nested = True
					break
				if ancestor is None:
					break
				ancestor = view.groups[ancestor].parent_index
		if not nested:
			continue
		inline_layer = any(
			first_non_open[view.tokens[index].line] is not None
			and first_non_open[view.tokens[index].line].start < view.tokens[index].start
			for index in indexes
		)
		missing_layer = any(
			parents.get(index) is None or view.groups[parents[index]].kind != "group"
			for index in indexes
		)
		for index in indexes:
			parent = parents.get(index)
			while parent is not None and view.groups[parent].kind == "group":
				layer_groups.add(parent)
				parent = view.groups[parent].parent_index
		if (len({view.tokens[index].line for index in indexes}) != len(indexes)
				or len({parents.get(index) for index in indexes}) != len(indexes)
				or inline_layer or missing_layer):
			token = view.tokens[indexes[1]]
			issues.append(_issue(path, "nested_ternary", token.line, token.column,
								 "Nested conditional expressions require separate precedence layers.",
								 "Parenthesize each nested conditional and expand each layer across lines."))


def _check_expression_layers(
	path: str, view: LexedSource, parents: dict[int, int],
	by_line: dict[int, list[int]], line_indents: dict[int, int],
	layer_groups: set[int], issues: list[dict[str, Any]],
) -> None:
	"""Validate proven complex condition/ternary layers, not arbitrary parentheses.

	A call/container remains the nearest owner of its parameters and lambda body.
	Grouping closers can retain expression suffixes, but not another layer's close.
	"""
	closing_groups = {
		view.groups[number].close_index: number
		for number in layer_groups
		if view.tokens[view.groups[number].open_index].line
		!= view.tokens[view.groups[number].close_index].line
	}
	literal_end_lines = {
		token.end_line for token in view.tokens
		if token.kind == "string" and token.line != token.end_line
	}
	for line, indexes in by_line.items():
		first_index = indexes[0]
		first = view.tokens[first_index]
		parent = parents.get(first_index)
		if first_index in closing_groups:
			parent = closing_groups[first_index]
		elif parent not in layer_groups or line in literal_end_lines:
			continue
		if parent is None:
			continue
		group = view.groups[parent]
		opener = view.tokens[group.open_index]
		if first_index == group.close_index:
			expected = line_indents[opener.line]
		elif first.line == opener.line:
			continue
		else:
			expected = line_indents[opener.line] + 1
		if line_indents[line] != expected:
			issues.append(_issue(
				path, "continuation_indentation", first.line, first.column,
				"Indent this required expression layer relative to its own opener.",
				"Use one Tab inside each participating group and align its closer.",
			))
	for closing_index in closing_groups:
		closer = view.tokens[closing_index]
		value_ends_on_close = (
			closing_index > 0
			and view.tokens[closing_index - 1].end_line == closer.line
		)
		if by_line[closer.line][0] != closing_index or value_ends_on_close:
			issues.append(_issue(
				path, "closing_delimiter", closer.line, closer.column,
				"Close each required expression layer on its own structural line.",
				"Separate this close from the final value and other layer closers.",
			))


def _is_link(info: os.stat_result) -> bool:
	return stat.S_ISLNK(info.st_mode) or bool(getattr(info, "st_file_attributes", 0) & 0x400)


@dataclass(frozen=True)
class BlankBoundary:
	"""One-based half-open range of blank physical lines, outside literal payloads."""

	rule: str
	start_line: int
	stop_line: int
	expected: int


@dataclass
class _DefinitionLayout:
	kind: str
	indent: int
	start_line: int
	header_end: int
	end_line: int
	owner: int | None
	index: int


_SECTION_LINE = re.compile(r"# --- .+ ---\s*$")


def _blank_layout_boundaries(
	view: LexedSource, parents: dict[int, int], by_line: dict[int, list[int]],
	line_indents: dict[int, int],
) -> list[BlankBoundary]:
	"""Index only member sections and adjacent definitions using the existing lexer.

	Offside layout locates declaration ends; delimiter parents keep continuations,
	decorators and literal payloads out of member-boundary classification. This
	does not infer logical paragraphs or change ordinary member-group spacing.
	"""
	tokens = view.tokens
	group_by_open = {group.open_index: group for group in view.groups}
	group_by_close = {group.close_index: group for group in view.groups}
	group_numbers = {group.open_index: number for number, group in enumerate(view.groups)}
	starts = [token.start for token in tokens]
	comments: dict[int, Token] = {}
	comment_parents: dict[int, int | None] = {}
	for comment in view.comments:
		if view.lines[comment.line - 1].strip() != comment.value.rstrip():
			continue
		comments[comment.line] = comment
		before = bisect_right(starts, comment.start) - 1
		parent = parents.get(before)
		if before in group_by_open:
			parent = group_numbers[before]
		elif before in group_by_close:
			parent = group_by_close[before].parent_index
		comment_parents[comment.line] = parent
	blank_prefix = [0]
	previous_nonblank: dict[int, int | None] = {}
	next_nonblank: dict[int, int | None] = {}
	previous = None
	for line, raw in enumerate(view.lines, 1):
		previous_nonblank[line] = previous
		blank_prefix.append(blank_prefix[-1] + bool(raw.strip()))
		if raw.strip():
			previous = line
	following = None
	for line in range(len(view.lines), 0, -1):
		next_nonblank[line] = following
		if view.lines[line - 1].strip():
			following = line
	annotations: dict[int, tuple[int, int]] = {}
	statement_lines: set[int] = set()
	for line, indexes in by_line.items():
		first_index = indexes[0]
		first = tokens[first_index]
		previous_token = tokens[first_index - 1] if first_index else None
		if (
			parents.get(first_index) is None and first.value not in _CLOSE
			and (previous_token is None or (previous_token.end_line < line and previous_token.value != "\\"))
		):
			statement_lines.add(line)
		if first.value == "@" and parents.get(first_index) is None:
			end_index = first_index + 1
			if end_index + 1 in group_by_open:
				end_index = group_by_open[end_index + 1].close_index
			end_line = tokens[end_index].end_line
			if end_index + 1 == len(tokens) or tokens[end_index + 1].line > end_line:
				annotations[end_line] = (line, line_indents[line])
	next_statement: dict[int, int | None] = {}
	following = None
	for line in range(len(view.lines), 0, -1):
		next_statement[line] = following
		if line in statement_lines:
			following = line

	def declaration_start(line: int, indent: int) -> int:
		while line > 1:
			comment = comments.get(line - 1)
			annotation = annotations.get(line - 1)
			if comment is not None and line_indents[line - 1] == indent and not _SECTION_LINE.fullmatch(comment.value):
				line -= 1
			elif annotation is not None and annotation[1] == indent:
				line = annotation[0]
			else:
				break
		return line

	boundaries: list[BlankBoundary] = []
	active: list[_DefinitionLayout] = []
	last_definition: dict[int | None, _DefinitionLayout | None] = {}
	tail_comments: list[Token] = []
	previous_code_end = 0

	def close_definitions(line: int, indent: int) -> None:
		while active and indent <= active[-1].indent and line > active[-1].header_end:
			definition = active.pop()
			definition.end_line = max(
				previous_code_end,
				max((value.line for value in tail_comments
					 if line_indents[value.line] > definition.indent), default=0),
			)

	def append_gap(rule: str, before: int | None, after: int | None, expected: int) -> None:
		if before is None or after is None or after <= before:
			return
		if blank_prefix[after - 1] != blank_prefix[before]:
			return
		boundaries.append(BlankBoundary(rule, before + 1, after, expected))

	for line in sorted(set(by_line) | set(comments)):
		comment = comments.get(line)
		if comment is not None:
			indent = line_indents[line]
			is_section = _SECTION_LINE.fullmatch(comment.value) is not None and comment_parents[line] is None
			following = next_statement[line]
			if is_section and (following is None or line_indents[following] <= indent):
				close_definitions(line, indent)
			owner = next((definition for definition in reversed(active) if definition.kind == "class"), None)
			member_indent = owner.indent + 1 if owner is not None else 0
			at_member_section = (
				is_section and indent == member_indent
				and not any(definition.kind == "func" for definition in active)
				and (following is None or line_indents[following] <= member_indent)
			)
			if at_member_section:
				append_gap("section_spacing", previous_nonblank[line], line, 2)
				after = next_nonblank[line]
				after_comment = comments.get(after) if after is not None else None
				after_is_section = (
					after_comment is not None
					and _SECTION_LINE.fullmatch(after_comment.value) is not None
					and comment_parents[after] is None
					and line_indents[after] == member_indent
				)
				if after is not None and line_indents[after] >= member_indent and not after_is_section:
					append_gap("section_spacing", line, after, 1)
				last_definition[owner.index if owner is not None else None] = None
			tail_comments.append(comment)
			continue
		indexes = by_line[line]
		first_index = indexes[0]
		first = tokens[first_index]
		indent = line_indents[line]
		if line in statement_lines:
			close_definitions(line, indent)
		owner = next((definition for definition in reversed(active) if definition.kind == "class"), None)
		owner_index = owner.index if owner is not None else None
		member_indent = owner.indent + 1 if owner is not None else 0
		at_member_level = (
			line in statement_lines and indent == member_indent
			and not any(definition.kind == "func" for definition in active)
		)
		if at_member_level:
			keyword_index = first_index
			if first.value == "@":
				keyword_index = next((index for index in indexes
					if parents.get(index) is None and tokens[index].value in {"func", "static", "class", "enum", "var", "const", "signal"}), -1)
			if keyword_index >= 0 and tokens[keyword_index].value == "static":
				keyword_index += 1
			kind = tokens[keyword_index].value if keyword_index >= 0 else ""
			header_end = None
			end_line = None
			if kind in {"func", "class"} and keyword_index + 1 < len(tokens) and tokens[keyword_index + 1].kind == "identifier":
				colon = _header_colon(tokens, keyword_index, group_by_open)
				if colon is not None:
					header_end = tokens[colon].line
			elif kind == "enum":
				opening = keyword_index + 1
				if opening < len(tokens) and tokens[opening].kind == "identifier":
					opening += 1
				group = group_by_open.get(opening)
				if group is not None and group.kind == "enum":
					header_end = tokens[group.open_index].line
					end_line = tokens[group.close_index].line
			if header_end is not None:
				definition = _DefinitionLayout(
					kind, indent, declaration_start(line, indent), header_end,
					end_line if end_line is not None else header_end, owner_index, keyword_index,
				)
				previous_definition = last_definition.get(owner_index)
				if previous_definition is not None:
					append_gap("definition_spacing", previous_definition.end_line, definition.start_line, 2)
				last_definition[owner_index] = definition
				if kind in {"func", "class"}:
					if len(active) >= MAX_GROUP_DEPTH:
						raise ValueError("Declaration depth budget exhausted.")
					active.append(definition)
			elif keyword_index >= 0:
				last_definition[owner_index] = None
		previous_code_end = max(previous_code_end, *(tokens[index].end_line for index in indexes))
		tail_comments.clear()
	return sorted(set(boundaries), key=lambda value: (value.start_line, value.stop_line, value.rule))


def blank_layout_boundaries(path: str, source: str) -> list[BlankBoundary]:
	"""Expose the same safe blank-line ranges for a private mechanical migration."""
	view = lex_source(path, source)
	return blank_layout_boundaries_from_view(view)


def blank_layout_boundaries_from_view(view: LexedSource) -> list[BlankBoundary]:
	"""Reuse an immutable lexical view without scanning the same source twice."""
	if view.issues:
		raise ValueError("Blank layout requires complete lexical input.")
	parents: dict[int, int] = {}
	for number, group in enumerate(view.groups):
		for index in range(group.open_index + 1, group.close_index):
			parents[index] = number
	by_line: dict[int, list[int]] = {}
	for index, token in enumerate(view.tokens):
		by_line.setdefault(token.line, []).append(index)
	line_indents = {
		line: len(raw) - len(raw.lstrip("\t"))
		for line, raw in enumerate(view.lines, 1)
	}
	return _blank_layout_boundaries(view, parents, by_line, line_indents)


def _identity(info: os.stat_result) -> tuple[int, int, int, int]:
	return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns


def audit_repository(root: Path, paths: Iterable[str] | None = None, *,
					 read_text: Callable[[Path], str] | None = None) -> dict[str, Any]:
	"""Check complete owned inventory, or a clearly labeled diagnostic subset."""
	root = Path(root).absolute()
	issues: list[dict[str, Any]] = []
	selected: list[str] = []
	entries = 0
	inventory_identities: dict[Path, tuple[int, int, int, int]] = {}
	source_identities: dict[Path, tuple[int, int, int, int]] = {}
	try:
		if any(_is_link(value.lstat()) for value in (*reversed(root.parents), root)) or not root.is_dir():
			raise ValueError("Unsafe source root")
		if paths is None:
			for owned in OWNED_ROOTS:
				directory = root / owned
				if not directory.is_dir() or _is_link(directory.lstat()):
					raise ValueError("Missing or unsafe owned root")
				pending = [directory]
				while pending:
					current = pending.pop()
					inventory_identities[current] = _identity(current.lstat())
					children = []
					with os.scandir(current) as iterator:
						for entry in iterator:
							entries += 1
							if entries > MAX_ENTRIES:
								raise ValueError("Inventory budget exhausted")
							children.append(entry)
					for entry in sorted(children, key=lambda value: value.name):
						path = Path(entry.path)
						info = path.lstat()
						relative = path.relative_to(root).as_posix()
						if _is_link(info):
							issues.append(_issue(relative, "source_identity", 1, 1,
												 "Linked/reparse source entries are not allowed."))
						elif stat.S_ISDIR(info.st_mode):
							pending.append(path)
						elif relative.endswith(SUFFIXES):
							selected.append(relative)
							if len(selected) > MAX_FILES:
								raise ValueError("File budget exhausted")
		else:
			for path in paths:
				if (
					not isinstance(path, str)
					or "\\" in path
					or Path(path).is_absolute()
					or any(part in {"", ".", ".."} for part in path.split("/"))
				):
					raise ValueError("Invalid diagnostic source path")
				if not any(path.startswith(owned + "/") for owned in OWNED_ROOTS) or not path.endswith(SUFFIXES):
					raise ValueError("Source is outside the owned scope")
				selected.append(path)
				if len(selected) > MAX_FILES:
					raise ValueError("File budget exhausted")
	except (OSError, ValueError) as error:
		issues.append(_issue(".", "source_budget" if "budget" in str(error) else "source_identity", 1, 1,
							 "Owned inventory could not be completed."))
	total = 0
	scanned = 0
	for relative in sorted(set(selected)):
		path = root / relative
		try:
			chain = [root]
			for part in relative.split("/")[:-1]:
				chain.append(chain[-1] / part)
			before_chain = [_identity(value.lstat()) for value in chain]
			if any(_is_link(value.lstat()) for value in chain):
				raise ValueError("Linked parent")
			before = path.lstat()
			if _is_link(before) or not stat.S_ISREG(before.st_mode):
				raise ValueError("Unsafe source")
			total += before.st_size
			if before.st_size > MAX_SOURCE_BYTES or total > MAX_TOTAL_BYTES:
				issues.append(_issue(relative, "source_budget", 1, 1, "Source byte budget exhausted."))
				continue
			with path.open("rb") as stream:
				if _identity(os.fstat(stream.fileno())) != _identity(before):
					raise ValueError("Source changed before reading")
				data = stream.read(MAX_SOURCE_BYTES + 1)
				if _identity(os.fstat(stream.fileno())) != _identity(before):
					raise ValueError("Source changed while reading")
			source = data.decode("utf-8", errors="strict")
			if read_text is not None:
				try:
					cached_source = read_text(path)
				except Exception:
					issues.append(_issue(relative, "source_unreadable", 1, 1, "Snapshot reader failed."))
					continue
				normalized = source.replace("\r\n", "\n").replace("\r", "\n")
				if not isinstance(cached_source, str) or cached_source not in {source, normalized}:
					raise ValueError("Reader returned inconsistent source")
			if len(data) != before.st_size:
				raise ValueError("Reader returned inconsistent source")
			after_chain = [_identity(value.lstat()) for value in chain]
			if _identity(path.lstat()) != _identity(before) or after_chain != before_chain:
				raise ValueError("Source identity changed")
			scanned += 1
			source_identities[path] = _identity(before)
			issues.extend(audit_source(relative, source))
			if len(issues) > MAX_ISSUES:
				issues = issues[:MAX_ISSUES - 1] + [_issue(".", "issue_budget", 1, 1, "Diagnostic budget exhausted.")]
				break
		except UnicodeError:
			issues.append(_issue(relative, "source_encoding", 1, 1, "Source is not strict UTF-8."))
		except OSError:
			issues.append(_issue(relative, "source_unreadable", 1, 1, "Source could not be read."))
		except ValueError:
			issues.append(_issue(relative, "source_identity", 1, 1, "Source identity could not be verified."))
	for path, identity in {**inventory_identities, **source_identities}.items():
		try:
			current = path.lstat()
			stable = not _is_link(current) and _identity(current) == identity
		except OSError:
			stable = False
		if not stable:
			issues.append(_issue(path.relative_to(root).as_posix(), "source_identity", 1, 1,
								 "Source inventory changed during validation."))
	if len(issues) > MAX_ISSUES:
		issues = issues[:MAX_ISSUES - 1] + [
			_issue(".", "issue_budget", 1, 1, "Diagnostic budget exhausted."),
		]
	issues.sort(key=lambda item: (item["path"], item["line"], item["column"], item["rule"]))
	complete = not any(item["rule"] in _FATAL for item in issues)
	status = "clean" if not issues else "violations" if complete else "incomplete"
	counts = Counter(item["rule"] for item in issues)
	return {
		"schema_version": SCHEMA_VERSION,
		"policy_version": POLICY_VERSION,
		"policy_sha256": POLICY_SHA256,
		"ok": not issues,
		"complete": complete,
		"status": status,
		"scope": "owned_repository" if paths is None else "diagnostic_subset",
		"owned_roots": list(OWNED_ROOTS),
		"rules": list(RULES),
		"scanned_file_count": scanned,
		"source_bytes": total,
		"issue_count": len(issues),
		"rule_counts": dict(sorted(counts.items())),
		"issues": issues,
	}


def main(argv: list[str] | None = None) -> int:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
	parser.add_argument("--json", action="store_true")
	parser.add_argument("--path", action="append", help="Diagnostic subset; full gates must omit this option.")
	args = parser.parse_args(argv)
	report = audit_repository(args.root, args.path)
	if args.json:
		print(json.dumps(report, ensure_ascii=False, allow_nan=False))
	else:
		print(
			f"GDScript readability: {report['status']}; "
			f"{report['scanned_file_count']} files; {report['issue_count']} issues"
		)
		for issue in report["issues"]:
			print(
				f"{issue['path']}:{issue['line']}:{issue['column']}: "
				f"{issue['rule']}: {issue['message']} {issue['suggestion']}"
			)
	return 0 if report["ok"] else 1


if __name__ == "__main__":
	sys.exit(main())
