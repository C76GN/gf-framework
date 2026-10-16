"""Observable formatting contracts for structural whitespace integrity."""

from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import gf_gdscript_readability as readability
import gf_gdscript_layout_integrity as integrity


class LayoutIntegrityTests(unittest.TestCase):
	KEYWORD_NAMES = ("and", "as", "await", "class", "const", "elif", "else", "extends", "for", "func", "get", "if", "in", "is", "match", "not", "or", "return", "set", "signal", "var", "when", "while")

	def edits(self, source):
		return integrity.layout_edits(readability.lex_source("addons/gf/fixture.gd", source))

	def formatted(self, source):
		edits = self.edits(source)
		for left, right in zip(edits, edits[1:]):
			self.assertLessEqual(left.end, right.start)
		for edit in reversed(edits):
			source = source[:edit.start] + edit.replacement + source[edit.end:]
		return source

	def test_binary_compound_and_unary_operator_roles(self):
		self.assertEqual(self.formatted("var total:int=left+ -right*2\nmask&=bits\n"), "var total: int = left + -right * 2\nmask &= bits\n")

	def test_delimiter_padding_commas_and_call_opening(self):
		self.assertEqual(self.formatted('foo (  a ,b )\nvar x=[ 1 ,2 ]\nvar y={"a":1,"b":2}\n'), 'foo(a, b)\nvar x = [1, 2]\nvar y = { "a": 1, "b": 2 }\n')

	def test_literals_comments_node_paths_and_typed_collections_are_preserved(self):
		source = 'var x: Dictionary[String, Array[int]] = { "a": [1, 2] }\nvar n = $Root/Child\nvar u = %Unique\nvar text = "a+b, c:d" # x+y\n'
		self.assertEqual(self.formatted(source), source)

	def test_keyword_operators_and_group_prefix_spacing(self):
		self.assertEqual(self.formatted('if(a  and  not(b)):\n\tpass\nvar x=(a)as int\n'), 'if (a and not (b)):\n\tpass\nvar x = (a) as int\n')

	def test_named_and_control_suites_normalize_direct_statement_depth(self):
		source = 'func run() -> void:\n\t\tif enabled:\n\t\t\t\twork()\n\t\tdone()\n'
		expected = 'func run() -> void:\n\tif enabled:\n\t\twork()\n\tdone()\n'
		self.assertEqual(self.formatted(source), expected)

	def test_class_property_and_accessor_suites_have_separate_owners(self):
		source = 'class Nested:\n\t\tvar value: int:\n\t\t\t\tget:\n\t\t\t\t\t\treturn 1\n'
		self.assertEqual(self.formatted(source), 'class Nested:\n\tvar value: int:\n\t\tget:\n\t\t\treturn 1\n')

	def test_lambda_body_restarts_suite_inside_dictionary(self):
		source = 'var callbacks = {\n\t"run": func() -> void:\n\t\t\tif active:\n\t\t\t\t\tuse(a, b),\n}\n'
		expected = 'var callbacks = {\n\t"run": func() -> void:\n\t\tif active:\n\t\t\tuse(a, b),\n}\n'
		self.assertEqual(self.formatted(source), expected)

	def test_multiline_signature_and_initializer_keep_continuation_owners(self):
		source = 'func run(\n\tvalue: int\n) -> void:\n\tawait changed\nvar color: Color = Color(\n\t1,\n\t2,\n\t3\n):\n\tset(value):\n\t\tcolor = value\n'
		self.assertEqual(self.formatted(source), source)

	def test_match_arm_body_depth_is_not_pattern_continuation_depth(self):
		source = 'match value:\n\t\tA, \\\n\t\tB:\n\t\t\t\twork()\n'
		self.assertEqual(self.formatted(source), 'match value:\n\tA, \\\n\tB:\n\t\twork()\n')

	def test_documented_members_are_separate_units(self):
		source = '## First.\nvar first: int = 1\n## Second.\nvar second: int = 2\n'
		self.assertEqual(self.formatted(source), '## First.\nvar first: int = 1\n\n## Second.\nvar second: int = 2\n')

	def test_documentation_stays_bound_through_annotations(self):
		source = '## Radius.\n\n@export\n\nvar radius: float = 1.0\n'
		self.assertEqual(self.formatted(source), '## Radius.\n@export\nvar radius: float = 1.0\n')

	def test_group_directives_are_not_data_members_and_property_is_complete(self):
		source = '@export_group("Shape")\n## Radius.\n@export var radius: float = 1.0:\n\tset(value):\n\t\tradius = value\n\n## Color.\n@export var color: Color = Color.WHITE\n'
		self.assertEqual(self.formatted(source), source)

	def test_undocumented_single_line_members_do_not_have_empty_gaps(self):
		self.assertEqual(self.formatted('var first: int = 1\n\nvar second: int = 2\n'), 'var first: int = 1\nvar second: int = 2\n')

	def test_sections_definitions_and_enum_documentation_keep_existing_spacing(self):
		source = '## First.\nvar first: int = 1\n\n\n# --- 公共方法 ---\n\nfunc a() -> void:\n\tpass\n\n\nfunc b() -> void:\n\tpass\n\n\nenum State {\n\t## Ready.\n\tREADY,\n\t## Done.\n\tDONE,\n}\n'
		self.assertEqual(self.formatted(source), source)

	def test_comments_and_multiline_literal_payload_are_never_whitespace_code(self):
		source = 'func run() -> void:\n\tvar text = """a+b\n   c:d\n"""\n\t# x+y\n\tuse(text)\n'
		self.assertEqual(self.formatted(source), source)

	def test_packed_multiline_match_patterns_add_only_required_continuations(self):
		source = 'match value:\n\tA, B, \\\n\tC:\n\t\tpass\n'
		view = readability.lex_source('addons/gf/fixture.gd', source)
		self.assertIn('match_pattern_layout', {x['rule'] for x in integrity.audit_issues('addons/gf/fixture.gd', view)})
		self.assertEqual(self.formatted(source), 'match value:\n\tA, \\\n\tB, \\\n\tC:\n\t\tpass\n')
		edit = next(x for x in self.edits(source) if x.rule == 'match_pattern_layout')
		self.assertTrue(edit.replacement.startswith(' \\\n'))

	def test_match_nested_pattern_commas_and_guard_are_not_direct_pattern_splits(self):
		source = 'match value:\n\t[A, B], { "key": var item }, \\\n\tC when ready:\n\t\tuse(item)\n'
		expected = 'match value:\n\t[A, B], \\\n\t{ "key": var item }, \\\n\tC when ready:\n\t\tuse(item)\n'
		self.assertEqual(self.formatted(source), expected)

	def test_nested_classes_documented_data_and_property_body_form_complete_units(self):
		source = 'class Nested:\n\t## First.\n\tvar first: int:\n\t\tget:\n\t\t\treturn 1\n\t## Second.\n\tvar second: int = 2\n'
		expected = 'class Nested:\n\t## First.\n\tvar first: int:\n\t\tget:\n\t\t\treturn 1\n\n\t## Second.\n\tvar second: int = 2\n'
		self.assertEqual(self.formatted(source), expected)

	def test_keyword_named_members_are_calls_instead_of_control_headers(self):
		source = 'func run() -> void:\n\tobject.if(ready)\n\tobject.not(ready)\n\tobject.func(a, b)\n'
		self.assertEqual(self.formatted(source), source)

	def test_keyword_named_member_operands_keep_binary_operator_spacing(self):
		for member in self.KEYWORD_NAMES:
			for operator in ("+", "-", "%"):
				with self.subTest(member=member, operator=operator):
					source = f'var total = state.{member} {operator} value\n'
					self.assertEqual(self.formatted(source), source)
					self.assertEqual(readability.audit_source('addons/gf/fixture.gd', source), [])
					self.assertEqual(self.formatted(f'var total = state.{member}{operator}value\n'), source)


	def test_keyword_node_path_segments_preserve_slash_and_dot_boundaries(self):
		for prefix in ("$", "%"):
			for segment in self.KEYWORD_NAMES:
				for suffix in ("/Child", ".text"):
					with self.subTest(prefix=prefix, segment=segment, suffix=suffix):
						source = f'func run() -> Variant:\n\treturn {prefix}Parent/{segment}{suffix}\n'
						self.assertEqual(self.formatted(source), source)
						self.assertEqual(readability.audit_source('addons/gf/fixture.gd', source), [])


	def test_node_path_final_keyword_is_a_binary_left_operand(self):
		for prefix in ("$", "%"):
			for segment in ("not", "await", "get", "if"):
				for operator in ("+", "-", "%"):
					with self.subTest(prefix=prefix, segment=segment, operator=operator):
						source = f'var total = {prefix}Parent/{segment} {operator} value\n'
						self.assertEqual(self.formatted(source), source)


	def test_keyword_member_binary_after_continuation_and_real_unary_roles(self):
		source = 'var total = state.not \\\n\t+ value\nvar result = state.get - -offset\nvar inverted = not active\nvar negative = -value\nvar positive = +value\n'
		self.assertEqual(self.formatted(source), source)
		self.assertEqual(self.formatted('var result=state.get- - offset\nvar inverted=not  active\nvar negative= - value\n'), 'var result = state.get - -offset\nvar inverted = not active\nvar negative = -value\n')

	def test_prefix_literals_indices_modulo_and_binary_bits_keep_roles(self):
		source = 'var x = [&"name", ^"path", $"Node/Child", -1, ~mask]\nvar y = values[index] % 2 | mask ^ bits & other\nvar z = $Root/Child.position\n'
		self.assertEqual(self.formatted(source), source)

	def test_annotation_arguments_are_not_inline_bodies_or_members(self):
		source = '@export_range(0, 100, 1) var count: int = 1\n@warning_ignore("unused_parameter")\nfunc run(value: int) -> void:\n\tpass\n'
		self.assertEqual(self.formatted(source), source)

	def test_assigned_named_lambda_and_nested_callback_keep_body_owners(self):
		source = 'func run() -> void:\n\tvar callback = func named(value: int) -> int:\n\t\t\treturn value\n\tuse(callback)\n'
		expected = 'func run() -> void:\n\tvar callback = func named(value: int) -> int:\n\t\treturn value\n\tuse(callback)\n'
		self.assertEqual(self.formatted(source), expected)

	def test_initializer_cannot_borrow_a_following_property_body_colon(self):
		source = 'var first: Array[int] = []\n\n## Second.\nvar second: int = 1:\n\tget:\n\t\treturn 1\n'
		self.assertEqual(self.formatted(source), source)

	def test_export_group_blank_before_first_docs_is_a_group_boundary(self):
		source = '@export_group("Shape")\n\n## Radius.\n@export var radius: float = 1.0\n'
		self.assertEqual(self.formatted(source), source)

	def test_data_to_function_keeps_definition_boundary_priority(self):
		source = '## Field.\nvar value: int = 1\n\n\nfunc run() -> void:\n\tpass\n'
		self.assertEqual(self.formatted(source), source)

	def test_index_and_type_collection_brackets_have_no_outer_padding(self):
		self.assertEqual(self.formatted('var values: Array [int] = []\nvar first = values [ 0 ]\n'), 'var values: Array[int] = []\nvar first = values[0]\n')

	def test_multiline_literal_closing_row_postfix_does_not_end_its_function_suite(self):
		source = 'func run() -> void:\n\tvar text = """first\n  literal payload\n""".strip_edges()\n\tuse(text)\n'
		self.assertEqual(self.formatted(source), source)

	def test_multiple_annotations_on_declaration_line_keep_the_member_owner(self):
		source = 'class Nested:\n\t@export @onready var value: int = 1\n'
		self.assertEqual(self.formatted(source), source)

	def test_not_in_binary_word_spacing_is_separate_from_unary_not(self):
		self.assertEqual(self.formatted('var x = item  not  in  values\n'), 'var x = item not in values\n')

	def test_inline_dictionary_tail_comma_keeps_the_inner_space(self):
		source = 'var options = { "encode_dictionary_keys": true, }\n'
		self.assertEqual(self.formatted(source), source)

	def test_inline_dictionary_tail_comma_missing_padding_is_restored(self):
		self.assertEqual(self.formatted('var options={"key":true,}\n'), 'var options = { "key": true, }\n')

	def test_inline_dictionary_tail_comma_has_a_shared_list_integrity_fixed_point(self):
		import gf_gdscript_list_layout as lists
		source = 'var options = { "encode_dictionary_keys": true, }\n'
		for _ in range(4):
			before = source
			for module in (integrity, lists):
				view = readability.lex_source('addons/gf/fixture.gd', source)
				for edit in reversed(module.layout_edits(view)):
					source = source[:edit.start] + edit.replacement + source[edit.end:]
			if source == before:
				break
		view = readability.lex_source('addons/gf/fixture.gd', source)
		self.assertEqual(integrity.layout_edits(view), ())
		self.assertEqual(lists.layout_edits(view), ())
		self.assertEqual(source, 'var options = { "encode_dictionary_keys": true, }\n')

	def test_unique_node_new_statement_is_not_modulo_after_previous_call(self):
		source = 'func run() -> void:\n\tconsume()\n\t%or/and/Child.activate()\n'
		self.assertEqual(self.formatted(source), source)

	def test_binary_operator_after_continuation_is_not_unary(self):
		source = 'return first \\\n\t+ second\n'
		self.assertEqual(self.formatted(source), source)

	def test_when_guard_parentheses_are_not_call_parentheses(self):
		source = 'match value:\n\tvar item when (\n\t\ta\n\t\tor b\n\t):\n\t\tpass\n'
		self.assertEqual(self.formatted(source), source)

	def test_keyword_member_callback_uses_proven_body_statement_roles(self):
		source = 'state.func(\n\tfunc() -> void:\n\t\tconsume()\n\t\t%Unique/or/and/Child.activate()\n)\n'
		self.assertEqual(self.formatted(source), source)

	def test_modulo_after_explicit_continuation_does_not_become_node_access(self):
		source = 'var text = "outer%s" \\\n\t% Node.warn("inner%s" % value)\n'
		self.assertEqual(self.formatted(source), source)

	def test_every_edit_preserves_code_literal_comment_sequence_and_is_idempotent(self):
		source = '## One.\nvar one:int=1\n## Two.\nvar two:int= -2\n'
		formatted = self.formatted(source)
		before = readability.lex_source('addons/gf/fixture.gd', source)
		after = readability.lex_source('addons/gf/fixture.gd', formatted)
		self.assertEqual([(x.kind, x.value) for x in before.tokens], [(x.kind, x.value) for x in after.tokens])
		self.assertEqual([x.value for x in before.comments], [x.value for x in after.comments])
		self.assertEqual(self.edits(formatted), ())


if __name__ == '__main__':
	unittest.main()
