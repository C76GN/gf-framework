"""Structural list choices are independent of historical physical wrapping."""

from __future__ import annotations

from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))

import gf_gdscript_readability as readability
import gf_gdscript_list_layout as lists


def format_source(source: str, *, max_inline_items: int = 2) -> str:
	view = readability.lex_source("addons/gf/example.gd", source)
	if view.issues:
		raise AssertionError(view.issues)
	edits = lists.layout_edits(view, max_inline_items=max_inline_items)
	previous_end = -1
	for edit in edits:
		if edit.start < previous_end:
			raise AssertionError("Overlapping edits")
		previous_end = edit.end
	for edit in reversed(edits):
		source = source[:edit.start] + edit.replacement + source[edit.end:]
	return source


class GDScriptListLayoutTests(unittest.TestCase):
	def assert_canonical(self, source: str, expected: str, *, threshold: int = 2) -> None:
		actual = format_source(source, max_inline_items=threshold)
		self.assertEqual(actual, expected)
		self.assertEqual(format_source(actual, max_inline_items=threshold), actual)

	def test_two_atomic_call_arguments_join_and_three_arguments_expand(self) -> None:
		self.assert_canonical("consume(\n\tleft,\n\tright\n)\n", "consume(left, right)\n")
		self.assert_canonical("consume(left, right, third)\n", "consume(\n\tleft,\n\tright,\n\tthird\n)\n")
		self.assert_canonical("consume(\n\tvalue\n)\n", "consume(value)\n")

	def test_two_nonatomic_call_arguments_expand_even_when_each_child_is_inline(self) -> None:
		for expression in ("build(value)", "values[index]", "left + right", "left if p else right", "first and second", '"value=%s" % value'):
			for first, second in ((expression, "other"), ("other", expression)):
				with self.subTest(first=first, second=second):
					self.assert_canonical(f"consume({first}, {second})\n", f"consume(\n\t{first},\n\t{second}\n)\n")
		for source in ("predicate(\n\tleft if p else right,\n\tfirst if q else second\n)\n", "consume(\n\ta and b,\n\tc or d\n)\n"):
			self.assert_canonical(source, source)

	def test_container_count_uses_the_same_threshold_and_keeps_final_comma(self) -> None:
		self.assert_canonical("var values = [\n\tleft,\n\tright,\n]\n", "var values = [left, right,]\n")
		self.assert_canonical("var values = [left, right, third]\n", "var values = [\n\tleft,\n\tright,\n\tthird,\n]\n")
		self.assert_canonical('var value = {\n\t"key": value,\n}\n', 'var value = { "key": value, }\n')

	def test_two_item_containers_use_child_layout_instead_of_call_atomicity(self) -> None:
		self.assert_canonical("var values = [\n\tbuild(value),\n\titems[index],\n]\n", "var values = [build(value), items[index],]\n")
		self.assert_canonical('var values = {\n\t"a": build(value),\n\t"b": items[index],\n}\n', 'var values = { "a": build(value), "b": items[index], }\n')

	def test_typed_declaration_is_not_a_complex_call_argument(self) -> None:
		self.assert_canonical("func update(\n\tvalue: Array[Dictionary]\n) -> void:\n\tpass\n", "func update(value: Array[Dictionary]) -> void:\n\tpass\n")
		self.assert_canonical("signal changed(\n\tleft: int,\n\tright: int\n)\n", "signal changed(left: int, right: int)\n")
		self.assert_canonical("signal changed(left: int, right: int, third: int)\n", "signal changed(\n\tleft: int,\n\tright: int,\n\tthird: int\n)\n")
		self.assert_canonical("func update(\n\tvalue: Array[Dictionary],\n\tother: int = build(source)\n) -> void:\n\tpass\n", "func update(value: Array[Dictionary], other: int = build(source)) -> void:\n\tpass\n")

	def test_threshold_can_be_selected_without_a_column_limit(self) -> None:
		self.assert_canonical("consume(left, right)\n", "consume(\n\tleft,\n\tright\n)\n", threshold=1)
		argument = '"' + "path/" * 300 + 'asset.tres"'
		self.assert_canonical("preload(\n\t" + argument + "\n)\n", "preload(" + argument + ")\n")
		for invalid in (-1, True, 1.5, "1"):
			with self.subTest(invalid=invalid), self.assertRaises(ValueError):
				lists.layout_edits(readability.lex_source("x.gd", "run()\n"), max_inline_items=invalid)

	def test_nested_single_calls_join_without_waiting_for_old_newlines(self) -> None:
		self.assert_canonical("outer(\n\tinner(\n\t\tvalue\n\t)\n)\n", "outer(inner(value))\n")

	def test_inline_child_does_not_hide_its_following_expression_continuation(self) -> None:
		for template in ("factory()", "$Parent/func.get_template()", "%Unique.get_template()"):
			with self.subTest(template=template):
				source = "warn(\n\t" + template + "\n\t% [value]\n)\n"
				self.assert_canonical(source, source)
		source = "warn(\n\tfactory(\n\t\tvalue\n\t)\n\t% [value]\n)\n"
		expected = "warn(\n\tfactory(value)\n\t% [value]\n)\n"
		self.assert_canonical(source, expected)

	def test_expanding_a_child_rebases_its_ancestor_and_nested_arguments(self) -> None:
		self.assert_canonical("outer(inner(left, right, third))\n", "outer(\n\tinner(\n\t\tleft,\n\t\tright,\n\t\tthird\n\t)\n)\n")
		self.assert_canonical("outer(middle(inner(left, right, third)))\n", "outer(\n\tmiddle(\n\t\tinner(\n\t\t\tleft,\n\t\t\tright,\n\t\t\tthird\n\t\t)\n\t)\n)\n")

	def test_one_flat_container_argument_joins_but_nested_containers_keep_layers(self) -> None:
		self.assert_canonical("consume(\n\t[value]\n)\n", "consume([value])\n")
		self.assert_canonical("var values = [[value]]\n", "var values = [\n\t[value],\n]\n")
		self.assert_canonical("var values = [\n\t[],\n]\n", "var values = [[],]\n")

	def test_dictionary_values_keep_their_call_structure_and_key_header(self) -> None:
		self.assert_canonical('var values = { "key": read(left, right, third) }\n', 'var values = {\n\t"key": read(\n\t\tleft,\n\t\tright,\n\t\tthird\n\t),\n}\n')
		self.assert_canonical('var values = { "a": left, "b": right }\n', 'var values = { "a": left, "b": right }\n')
		self.assert_canonical('var values = { "a": left, "b": right, "c": third }\n', 'var values = {\n\t"a": left,\n\t"b": right,\n\t"c": third,\n}\n')

	def test_complex_receiver_uses_the_same_argument_region_rule(self) -> None:
		self.assert_canonical("factory().copy(\n\ttrue\n)\n", "factory().copy(true)\n")
		self.assert_canonical("factory().configure(\n\tleft,\n\tright\n)\n", "factory().configure(left, right)\n")
		self.assert_canonical("factory().configure(left, right, third)\n", "factory().configure(\n\tleft,\n\tright,\n\tthird\n)\n")
		self.assert_canonical("factory().copy(\n)\n", "factory().copy()\n")

	def test_flat_annotation_metadata_stays_inline_independently_of_count(self) -> None:
		self.assert_canonical('@export_enum(\n\t"A",\n\t"B",\n\t"C"\n) var value: String\n', '@export_enum("A", "B", "C") var value: String\n')
		self.assert_canonical('@export_range(0, 100, 1)\nvar value: int\n', '@export_range(0, 100, 1) var value: int\n')

	def test_comments_protect_their_list_but_not_an_independent_child_call(self) -> None:
		self.assert_canonical("run(\n\tleft, # keep this binding\n\tinner(first, second, third)\n)\n", "run(\n\tleft, # keep this binding\n\tinner(\n\t\tfirst,\n\t\tsecond,\n\t\tthird\n\t)\n)\n")

	def test_explicit_continuations_and_real_multiline_literals_are_opaque(self) -> None:
		for source in ('run(\\\n\tvalue)\n', 'run("""first\nsecond""")\n', 'run(\n\t# reason\n\tvalue\n)\n'):
			with self.subTest(source=source):
				self.assert_canonical(source, source)

	def test_atomic_wrappers_keep_tokens_and_lose_only_whitespace(self) -> None:
		self.assert_canonical("run(\n\t(\n\t\tvalue\n\t)\n)\n", "run((value))\n")
		self.assert_canonical("run(\n\tnot ready\n)\n", "run(not ready)\n")

	def test_generic_type_commas_do_not_count_as_declaration_parameters(self) -> None:
		self.assert_canonical("func update(\n\tvalue: Dictionary[StringName, int]\n) -> void:\n\tpass\n", "func update(value: Dictionary[StringName, int]) -> void:\n\tpass\n")
		self.assert_canonical("func update(\n\tvalue:\n\t\tArray[\n\t\t\tNode\n\t\t]\n) -> void:\n\tpass\n", "func update(value: Array[Node]) -> void:\n\tpass\n")
		self.assert_canonical("func update(\n\tvalue: Dictionary\n\t\t[\n\t\t\tStringName,\n\t\t\tint\n\t\t]\n) -> void:\n\tpass\n", "func update(value: Dictionary[StringName, int]) -> void:\n\tpass\n")

	def test_default_calls_expand_only_when_their_child_list_requires_it(self) -> None:
		self.assert_canonical("func update(\n\tvalue: int = build(source)\n) -> void:\n\tpass\n", "func update(value: int = build(source)) -> void:\n\tpass\n")
		self.assert_canonical("func update(value: int = build(left, right, third)) -> void:\n\tpass\n", "func update(\n\tvalue: int = build(\n\t\tleft,\n\t\tright,\n\t\tthird\n\t)\n) -> void:\n\tpass\n")
		self.assert_canonical("func update(\n\tvalue: int\n\t\t= build(source)\n) -> void:\n\tpass\n", "func update(value: int = build(source)) -> void:\n\tpass\n")

	def test_lambda_body_rebases_when_the_single_argument_gets_its_own_line(self) -> None:
		self.assert_canonical("run(func(value: int) -> int:\n\treturn value\n)\n", "run(\n\tfunc(value: int) -> int:\n\t\treturn value\n)\n")
		self.assert_canonical("run(func(left: int, right: int) -> int:\n\treturn left + right\n)\n", "run(\n\tfunc(left: int, right: int) -> int:\n\t\treturn left + right\n)\n")
		self.assert_canonical("run(func(left: int, right: int, third: int) -> int:\n\treturn left + right + third\n)\n", "run(\n\tfunc(\n\t\tleft: int,\n\t\tright: int,\n\t\tthird: int\n\t) -> int:\n\t\treturn left + right + third\n)\n")

	def test_required_boolean_expression_is_not_flattened_into_a_single_argument(self) -> None:
		source = "run(\n\tfirst\n\tand second\n\tand third\n)\n"
		self.assert_canonical(source, source)

	def test_call_suffixes_and_existing_final_commas_are_preserved(self) -> None:
		self.assert_canonical("var value = run(left, right, third) as Node\n", "var value = run(\n\tleft,\n\tright,\n\tthird\n) as Node\n")
		self.assert_canonical("run(\n\tvalue,\n)\n", "run(value,)\n")
		self.assert_canonical("var value = [\n\tvalue,\n]\n", "var value = [value,]\n")

	def test_enum_and_ordinary_index_owners_belong_to_their_existing_passes(self) -> None:
		for source in ("enum Mode { FIRST, SECOND }\n", "var value = items[\n\tindex\n]\n"):
			self.assert_canonical(source, source)

	def test_independent_parenthesized_statement_is_not_a_previous_call_suffix(self) -> None:
		source = "var value = acquire()\n(\n\tfactory().configure(\n\t\tleft,\n\t\tright\n\t)\n)\n"
		states = lists.list_layout_states(readability.lex_source("x.gd", source))
		view = readability.lex_source("x.gd", source)
		standalone = next(i for i, token in enumerate(view.tokens) if token.value == "(" and token.line == 2)
		self.assertNotIn(standalone, states)

	def test_edit_rules_are_owned_and_lexical_failure_is_not_repaired(self) -> None:
		source = "run(left, right, third)\nsignal changed(left: int, right: int, third: int)\n@export_range(\n\t0,\n\t10,\n\t1\n) var amount: int\n"
		rules = {edit.rule for edit in lists.layout_edits(readability.lex_source("x.gd", source))}
		self.assertEqual(rules, {"list_layout", "declaration_parameter_layout", "annotation_parameter_layout"})
		self.assertEqual(lists.layout_edits(readability.lex_source("x.gd", "run(\n")), ())

	def test_nonwhitespace_tokens_and_comment_literal_payloads_survive(self) -> None:
		source = 'var value = { "key": run(first, second, "a ; # b") }\n'
		actual = format_source(source)
		self.assertNotEqual(actual, source)
		before = [(token.kind, token.value) for token in readability.lex_source("x.gd", source).tokens]
		after = [(token.kind, token.value) for token in readability.lex_source("x.gd", actual).tokens]
		cursor = 0
		for token in after:
			if cursor < len(before) and token == before[cursor]:
				cursor += 1
			else:
				self.assertEqual(token, ("symbol", ","))
		self.assertEqual(cursor, len(before))

	def test_single_field_annotation_binds_to_its_declaration(self) -> None:
		self.assert_canonical('@export_enum("public", "support", "debug")\nvar profile: String = "debug"\n', '@export_enum("public", "support", "debug") var profile: String = "debug"\n')
		self.assert_canonical('@export\nvar amount: int\n', '@export var amount: int\n')
		self.assert_canonical('@onready\nvar child: Node = get_child(0)\n', '@onready var child: Node = get_child(0)\n')

	def test_field_annotation_metadata_can_normalize_and_bind_in_one_pass(self) -> None:
		self.assert_canonical('@export_enum(\n\t"A",\n\t"B"\n)\nvar mode: String\n', '@export_enum("A", "B") var mode: String\n')
		value = '"' + "long metadata " * 100 + '"'
		self.assert_canonical('@export_placeholder(' + value + ')\nvar text: String\n', '@export_placeholder(' + value + ') var text: String\n')

	def test_multiple_field_annotations_and_physical_binding_barriers_remain(self) -> None:
		for source in ('@export\n@onready\nvar amount: int\n', '@export\n# keep binding\nvar amount: int\n', '@export_enum(\n\t"A", # meaning\n\t"B"\n)\nvar mode: String\n', '@export\n# first field marker\n@onready\nvar amount: int\n'):
			with self.subTest(source=source):
				self.assert_canonical(source, source)

	def test_independent_annotation_directives_do_not_bind_to_members(self) -> None:
		for source in ('@tool\nvar value: int\n', '@icon("res://icon.svg")\nvar value: int\n', '@export_group("Group")\nvar value: int\n', '@export_subgroup("Subgroup")\nvar value: int\n', '@export_category("Category")\nvar value: int\n', '@warning_ignore("unused_private_class_variable")\nvar value: int\n'):
			with self.subTest(source=source):
				self.assert_canonical(source, source)
		self.assert_canonical('@export_group("Group")\n@export\nvar value: int\n', '@export_group("Group")\n@export var value: int\n')

	def test_field_annotation_binding_preserves_class_owner_and_rule(self) -> None:
		source = 'class Entry:\n\t@export_storage\n\tvar count: int\n'
		expected = 'class Entry:\n\t@export_storage var count: int\n'
		self.assert_canonical(source, expected)
		edits = lists.layout_edits(readability.lex_source("x.gd", source))
		self.assertEqual({edit.rule for edit in edits}, {"annotation_binding_layout"})


if __name__ == "__main__":
	unittest.main()
