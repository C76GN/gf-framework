"""Observable contracts of the mandatory GDScript readability checker."""

from __future__ import annotations

from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import gf_gdscript_readability as readability


class ReadabilityTests(unittest.TestCase):
	def rules(self, source: str, path: str = "addons/gf/fixture.gd") -> set[str]:
		return {issue["rule"] for issue in readability.audit_source(path, source)}

	def test_comments_and_literal_payloads_are_not_executable_code(self) -> None:
		source = '# if a: return; func(): pass\nvar text: String = "if a: return; func(): pass #"\n'
		self.assertEqual(self.rules(source), set())

	def test_triple_strings_keep_embedded_source_unchecked(self) -> None:
		source = 'var text: String = """\n    if a: return; func(): pass\n"""\n'
		self.assertEqual(self.rules(source), set())

	def test_triple_string_closing_line_code_is_checked_by_structure(self) -> None:
		payload = "a" * 300
		clean = 'var text = """\n' + payload + '""".format([])\n'
		self.assertEqual(self.rules(clean), set())
		bad = 'var text = """\n' + payload + '"""; run()\n'
		self.assertIn("statement_separator", self.rules(bad))
		self.assertEqual(self.rules('var text = """' + payload + '""".format([])\n'), set())
		spaced_payload = 'var text = """\n    payload""".format([])\n'
		self.assertNotIn("text_format", self.rules(spaced_payload))
		condition = 'if """' + payload + '""" == text:\n\tpass\n'
		self.assertNotIn("condition_layout", self.rules(condition))

	def test_token_offsets_preserve_unicode_literals_and_comments(self) -> None:
		source = 'var text: String = &"你好;#" # tail\n'
		view = readability.lex_source("addons/gf/x.gd", source)
		self.assertEqual(view.issues, ())
		for token in (*view.tokens, *view.comments):
			self.assertEqual(source[token.start:token.end], token.value)
		self.assertEqual([token.kind for token in view.tokens].count("string"), 1)
		self.assertEqual(view.comments[0].value, "# tail")

	def test_unicode_line_separator_inside_literal_is_not_a_source_newline(self) -> None:
		source = 'var text = "left\u2028right"\nvar a = { "x": 1 }; var b = 2\n'
		view = readability.lex_source("addons/gf/x.gd", source)
		self.assertEqual(len(view.lines), 2)
		issues = readability.audit_source("addons/gf/x.gd", source)
		self.assertEqual([(issue["rule"], issue["line"]) for issue in issues], [("statement_separator", 2)])

	def test_template_rendered_offsets_map_back_to_original_source(self) -> None:
		path = "addons/gf/tools/config_pipeline/templates/read_config.gd.txt"
		source = "var a = load({DatabasePath})\nif ready: run()\n"
		view = readability.lex_source(path, source)
		for token in view.tokens:
			self.assertEqual(source[token.start:token.end], token.value)
		issues = readability.audit_source(path, source)
		self.assertEqual([(issue["rule"], issue["line"]) for issue in issues], [("inline_body", 2)])

	def test_unclosed_strings_and_delimiters_fail_closed(self) -> None:
		for source in ('var text = "missing\n', 'var text = """missing\n', 'foo(]\n', 'foo(\n'):
			with self.subTest(source=source):
				self.assertIn("lexical_closure", self.rules(source))

	def test_semicolon_sequences_are_rejected(self) -> None:
		self.assertIn("statement_separator", self.rules("var a = 1; var b = 2\n"))

	def test_member_names_remain_adjacent_to_access_dots(self) -> None:
		for source in ('source. contains(value)\n', 'source.\n\tcontains(value)\n'):
			self.assertIn("member_access_spacing", self.rules(source))
		for source in (
			'source.contains(value)\n',
			'var value = (\n\tsource\n\t.contains(data)\n)\n',
			'var number = 1.25\nvar text = "source. contains" # source. contains\n',
		):
			self.assertNotIn("member_access_spacing", self.rules(source))

	def test_inline_function_lambda_accessor_control_and_match_bodies_are_rejected(self) -> None:
		for source in (
			"func _run() -> void: pass\n",
			"signal.changed.connect(func() -> void: run())\n",
			"if enabled: run()\n", "else: return\n", "for item in items: run()\n",
			"var data: int:\n\tget: return 1\n",
			"match value:\n\t1: return\n",
		):
			with self.subTest(source=source):
				self.assertIn("inline_body", self.rules(source))

	def test_expanded_lambda_keeps_body_scope(self) -> None:
		source = "changed.connect(\n\tfunc(value: int) -> void:\n\t\trun(value)\n)\n"
		self.assertEqual(self.rules(source), set())

	def test_two_short_dictionary_fields_are_permitted(self) -> None:
		self.assertEqual(self.rules('var data = { "a": 1, "b": 2 }\n'), set())

	def test_three_fields_or_nonempty_nested_containers_need_expansion(self) -> None:
		for source in ('var data = { "a": 1, "b": 2, "c": 3 }\n',
					   'var data = { "a": [1] }\n', 'var data = [{ "a": 1 }]\n'):
			with self.subTest(source=source):
				self.assertIn("dictionary_layout", self.rules(source))
		self.assertEqual(self.rules('var data = { "a": [] }\n'), set())

	def test_multiline_container_items_closing_and_final_comma(self) -> None:
		self.assertEqual(self.rules('var data = {\n\t"a": 1,\n\t"b": 2,\n\t"c": 3,\n}\n'), set())
		self.assertIn("multiline_items", self.rules('var data = [\n\t1, 2,\n]\n'))
		self.assertIn("multiline_items", self.rules('var data = [1,\n\t2,\n]\n'))
		self.assertIn("closing_delimiter", self.rules('var data = [\n\t1,]\n'))
		self.assertIn("trailing_comma", self.rules('var data = [\n\t1\n]\n'))

	def test_multiline_calls_and_signatures_have_one_argument_per_line(self) -> None:
		self.assertEqual(self.rules('foo(\n\ta,\n\tb,\n\tc\n)\n'), set())
		self.assertIn("multiline_items", self.rules('foo(\n\ta, b\n)\n'))
		self.assertEqual(self.rules('func run(\n\ta: int,\n\tb: int,\n\tc: int\n) -> void:\n\tpass\n'), set())

	def test_nested_close_delimiters_keep_separate_structural_lines(self) -> None:
		source = 'foo(\n\tbar(\n\t\tvalue,\n\t\tother,\n\t\tthird\n\t)\n)\n'
		self.assertEqual(self.rules(source), set())
		self.assertIn("closing_delimiter", self.rules(source.replace("\t)\n)", "\t))")))

	def test_condition_thresholds_include_parenthesized_terms(self) -> None:
		for source in (
			'if a and b and c and d:\n\tpass\n',
			'if (a or b) and c:\n\tpass\n',
		):
			self.assertIn("condition_layout", self.rules(source))
		self.assertNotIn("condition_layout", self.rules('if (\n\ta\n\tand b\n\tand c\n):\n\tpass\n'))

	def test_condition_does_not_count_call_arguments_as_outer_terms(self) -> None:
		source = 'if predicate(\n\ta\n\tand b\n\tand c\n\tand d\n) and ready:\n\tpass\n'
		self.assertNotIn("condition_layout", self.rules(source))

	def test_expanded_condition_preserves_existing_precedence_groups(self) -> None:
		source = 'if (\n\t(\n\t\ta\n\t\tor b\n\t)\n\tand c\n):\n\tpass\n'
		self.assertEqual(self.rules(source), set())
		self.assertIn("condition_layout", self.rules('if (\n\t(a or b)\n\tand c\n):\n\tpass\n'))

	def test_nested_ternary_is_layered_instead_of_flattened(self) -> None:
		self.assertIn("nested_ternary", self.rules('var value = a if p else b if q else c\n'))
		source = 'var value = (\n\ta\n\tif p\n\telse (\n\t\tb\n\t\tif q\n\t\telse c\n\t)\n)\n'
		self.assertNotIn("nested_ternary", self.rules(source))

	def test_independent_ternaries_are_not_nested(self) -> None:
		source = 'var a = left if p else right\nvar b = left if q else right\n'
		self.assertNotIn("nested_ternary", self.rules(source))

	def test_independent_ternaries_in_arguments_arrays_and_dictionary_fields(self) -> None:
		expressions = (
			'call(a if p else b, c if q else d)\n',
			'return [a if p else b, c if q else d]\n',
			'return { "a": a if p else b, "b": c if q else d }\n',
			'return (a if p else b) + (c if q else d)\n',
			'if ready:\n\tvar a = x if p else y\nelif waiting:\n\tvar b = x if q else y\n',
		)
		for source in expressions:
			with self.subTest(source=source):
				self.assertNotIn("nested_ternary", self.rules(source))
		self.assertIn("nested_ternary", self.rules('call(a if p else (b if q else c))\n'))
		self.assertIn("nested_ternary", self.rules('return a if p else (b if q else c)\n'))
		self.assertIn("nested_ternary", self.rules('return a if p else \\\n\t(b if q else c)\n'))

	def test_multiline_call_does_not_hide_unexpanded_boolean_operators(self) -> None:
		source = 'if a and b and predicate(\n\tvalue\n) and d:\n\tpass\n'
		self.assertIn("condition_layout", self.rules(source))

	def test_continuation_indentation_is_checked_per_layer(self) -> None:
		self.assertIn("continuation_indentation", self.rules('foo(\nvalue\n)\n'))
		self.assertIn("continuation_indentation", self.rules('foo(\n\tvalue\n\t)\n'))

	def test_typed_for_header_does_not_confuse_type_and_body_colons(self) -> None:
		for source in (
			'for record: Dictionary in records:\n\tpass\n',
			'for key: Variant in record:\n\tpass\n',
		):
			self.assertNotIn("inline_body", self.rules(source))
		self.assertIn("inline_body", self.rules('for key: Variant in record: run()\n'))

	def test_independent_ternaries_in_different_and_same_lambda_bodies(self) -> None:
		sources = (
			'call(\n\tfunc() -> void:\n\t\tvar a = x if p else y\n'
			'\t\tvar b = x if q else y\n)\n',
			'call(\n\tfunc() -> void:\n\t\tvar a = x if p else y,\n'
			'\tfunc() -> void:\n\t\tvar b = x if q else y\n)\n',
		)
		for source in sources:
			with self.subTest(source=source):
				self.assertNotIn("nested_ternary", self.rules(source))

	def test_typed_setter_and_multiline_callable_headers(self) -> None:
		source = (
			'var value: int:\n\tset(new_value: int):\n\t\tvalue = new_value\n'
			'\tget:\n\t\treturn value\n'
			'func run(\n\tvalue: Variant\n) -> void:\n\tawait changed\n'
		)
		self.assertNotIn("inline_body", self.rules(source))
		self.assertIn("inline_body", self.rules('var a: int:\n\tset(value: int): a = value\n'))

	def test_match_binding_arms_cannot_hide_inline_bodies(self) -> None:
		for arm in ("var item", "var item when item != null"):
			source = "func run(value: Variant) -> void:\n\tmatch value:\n\t\t" + arm + ": use(item)\n"
			self.assertIn("inline_body", self.rules(source))
		clean = (
			"func run(value: Variant) -> void:\n\tvar ordinary: int = 1\n"
			"\tmatch value:\n\t\tvar item:\n\t\t\tvar typed: Variant = item\n"
			"\t\t\tuse(typed)\n\tvar following: int = ordinary\n"
		)
		self.assertEqual(self.rules(clean), set())
		lambda_arm = (
			"call(\n\tfunc(value: Variant) -> void:\n\t\tmatch value:\n"
			"\t\t\tvar item: use(item)\n)\n"
		)
		self.assertIn("inline_body", self.rules(lambda_arm))

	def test_multiline_return_types_do_not_hide_function_or_lambda_bodies(self) -> None:
		for source in (
			"func run() -> Array[\n\tString\n]: return []\n",
			"call(\n\tfunc() -> Array[\n\t\tString\n\t]: return []\n)\n",
		):
			self.assertIn("inline_body", self.rules(source))
		clean = "func run() -> Array[\n\tString\n]:\n\treturn []\n"
		self.assertNotIn("inline_body", self.rules(clean))

	def test_required_condition_groups_keep_their_indentation_and_closers(self) -> None:
		self.assertIn("continuation_indentation", self.rules(
			"if (\na\nand b\nand c\nand d\n):\n\tpass\n",
		))
		self.assertIn("continuation_indentation", self.rules(
			"if (\n\ta\n\tand (\n\tb\n\tor c\n\t)\n):\n\tpass\n",
		))
		for source in (
			"if (\n\ta\n\tand b\n\tand c\n\tand d):\n\tpass\n",
			"if (\n\ta\n\tand (\n\t\tb\n\t\tor c)):\n\tpass\n",
		):
			self.assertIn("closing_delimiter", self.rules(source))
		clean = (
			"if (\n\tready\n\tand predicate(\n\t\tleft if p else right,\n"
			"\t\tfirst if q else second\n\t)\n\tand active\n\tand visible\n):\n\tpass\n"
		)
		self.assertEqual(self.rules(clean), set())
		arithmetic = "var value = (\na + b\n)\n"
		self.assertNotIn("continuation_indentation", self.rules(arithmetic))

	def test_nested_ternary_groups_keep_indentation_and_explicit_layers(self) -> None:
		self.assertIn("continuation_indentation", self.rules(
			"return (\na\nif p\nelse (\nb\nif q\nelse c\n)\n)\n",
		))
		self.assertIn("closing_delimiter", self.rules(
			"return (\n\ta\n\tif p\n\telse (\n\t\tb\n\t\tif q\n\t\telse c))\n",
		))
		self.assertIn("nested_ternary", self.rules(
			"return a \\\n\tif p \\\n\telse (\n\t\tb\n\t\tif q\n\t\telse c\n\t)\n",
		))
		clean = (
			"return (\n\ta\n\tif p\n\telse (\n\t\tb\n\t\tif q\n\t\telse c\n\t)\n).method()\n"
		)
		self.assertEqual(self.rules(clean), set())

	def test_independent_lambda_assignment_ternaries_remain_independent(self) -> None:
		for statements in (
			"\t\tstate.a = x if p else y\n\t\tstate.b = x if q else y\n",
			'\t\tstate["a"] = x if p else y\n\t\tstate["b"] = x if q else y\n',
		):
			source = "call(\n\tfunc() -> void:\n" + statements + ")\n"
			self.assertNotIn("nested_ternary", self.rules(source))

	def test_logical_operator_aliases_do_not_create_mixed_conditions(self) -> None:
		self.assertNotIn("condition_layout", self.rules("if (\n\ta\n\t&& b\n\tand c\n):\n\tpass\n"))
		self.assertIn("condition_layout", self.rules("if a && b or c:\n\tpass\n"))

	def test_triple_literal_end_is_still_a_value_before_a_closer(self) -> None:
		self.assertIn("closing_delimiter", self.rules('call(\n\t"""a\nb""")\n'))
		self.assertEqual(self.rules('call(\n\t"""a\nb"""\n)\n'), set())

	def test_large_operator_and_independent_item_inputs_remain_bounded(self) -> None:
		condition = "if " + " and ".join("a" for _ in range(4_000)) + ":\n\tpass\n"
		self.assertIn("condition_layout", self.rules(condition))
		arguments = "call(" + ", ".join("a if p else b" for _ in range(4_000)) + ")\n"
		self.assertNotIn("nested_ternary", self.rules(arguments))

	def test_literal_length_does_not_require_a_continuation(self) -> None:
		self.assertEqual(self.rules('"' + 'a' * 5_000 + '"\n'), set())

	def test_dictionary_spacing_is_a_distinct_violation(self) -> None:
		self.assertIn("dictionary_spacing", self.rules('var a = {"x": 1}\n'))
		self.assertNotIn("dictionary_spacing", self.rules('var a = {}\n'))

	def test_named_and_anonymous_enums_allow_optional_final_commas(self) -> None:
		for header in ("enum Mode", "enum"):
			for final_comma in ("", ","):
				source = header + " {\n\tREADY = 1,\n\tACTIVE = 2,\n\tDONE = 3" + final_comma + "\n}\n"
				self.assertEqual(self.rules(source), set())
				view = readability.lex_source("addons/gf/enum_fixture.gd", source)
				self.assertEqual([group.kind for group in view.groups], ["enum"])

	def test_enum_members_indentation_and_closers_use_enum_diagnostics(self) -> None:
		for source in (
			"enum Mode {READY, ACTIVE}\n",
			"enum {READY, ACTIVE, DONE}\n",
			"enum Mode {\n\tREADY, ACTIVE,\n}\n",
			"enum Mode {READY,\n\tACTIVE,\n}\n",
			"enum Mode {\nREADY,\n\tACTIVE\n}\n",
			"enum Mode {\n\tREADY,\n\tACTIVE}\n",
			"enum Mode {\n\tREADY,\n\tACTIVE\n\t}\n",
		):
			self.assertEqual(self.rules(source), {"enum_layout"})

	def test_enum_like_call_arguments_and_dictionary_keys_remain_dictionaries(self) -> None:
		source = (
			'call(\n\tEnums.Mode,\n\t{ "enum": 1 }\n)\n'
			'object.enum_method({ "Mode": 1 })\n'
		)
		self.assertEqual(self.rules(source), set())
		view = readability.lex_source("addons/gf/enum_fixture.gd", source)
		self.assertEqual([group.kind for group in view.groups].count("dictionary"), 2)
		self.assertNotIn("enum", {group.kind for group in view.groups})
		self.assertIn("dictionary_layout", self.rules('call({ "enum": 1, "a": 2, "b": 3 })\n'))
		self.assertIn("trailing_comma", self.rules('var data = {\n\t"enum": 1\n}\n'))

	def test_nested_class_enum_uses_its_declaration_indentation(self) -> None:
		source = "class State:\n\tenum Mode {\n\t\tREADY,\n\t\tACTIVE\n\t}\n"
		self.assertEqual(self.rules(source), set())

	def test_nested_multiline_lambda_argument_requires_comma_in_each_delimiter_context(self) -> None:
		for source in (
			"outer(\n\tinner(\n\t\tfunc() -> void:\n\t\t\trecord()\n\t)\n)\n",
			"var result = (\n\tinner(\n\t\tfunc() -> void:\n\t\t\trecord()\n\t)\n)\n",
			"var result = [\n\tinner(\n\t\tfunc() -> void:\n\t\t\trecord()\n\t),\n]\n",
			'var result = {\n\t"callback": inner(\n\t\tfunc() -> void:\n\t\t\trecord()\n\t),\n}\n',
		):
			with self.subTest(source=source):
				self.assertIn("lambda_argument_separator", self.rules(source))
				self.assertNotIn("lambda_argument_separator", self.rules(source.replace("record()\n", "record(),\n")))

	def test_lambda_separator_does_not_require_comma_for_flat_calls_or_assigned_lambdas(self) -> None:
		for source in (
			"inner(\n\tfunc() -> void:\n\t\trecord()\n)\n",
			"var callback: Callable = func() -> void:\n\trecord()\n",
			"var callbacks = [\n\tfunc() -> void:\n\t\trecord(),\n]\n",
			"outer(\n\tinner(\n\t\tfunc() -> void:\n\t\t\trecord(),\n\t\t42\n\t)\n)\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("lambda_argument_separator", self.rules(source))

	def test_lambda_separator_preserves_typed_headers_comments_and_literal_payload(self) -> None:
		bad = "outer(\n\tinner(\n\t\tfunc() -> Array[\n\t\t\tString\n\t\t]:\n\t\t\treturn [] # retained\n\t)\n)\n"
		self.assertIn("lambda_argument_separator", self.rules(bad))
		self.assertNotIn("lambda_argument_separator", self.rules(bad.replace("return [] #", "return [], #")))
		literal = 'var source = """outer(\n\tinner(\n\t\tfunc() -> void:\n\t\t\trecord()\n\t)\n)\n"""\n'
		self.assertNotIn("lambda_argument_separator", self.rules(literal))

	def test_lambda_body_statements_restart_expression_context(self) -> None:
		statement = "outer(\n\tfunc() -> void:\n\t\tinner(\n\t\t\tfunc() -> void:\n\t\t\t\trecord()\n\t\t)\n)\n"
		self.assertNotIn("lambda_argument_separator", self.rules(statement))
		grouped = "outer(\n\tfunc() -> void:\n\t\tvar result = (\n\t\t\tinner(\n\t\t\t\tfunc() -> void:\n\t\t\t\t\trecord()\n\t\t\t)\n\t\t)\n)\n"
		self.assertIn("lambda_argument_separator", self.rules(grouped))
		self.assertNotIn("lambda_argument_separator", self.rules(grouped.replace("record()\n", "record(),\n")))

	def test_dictionary_value_lambda_body_statements_restart_expression_context(self) -> None:
		for key in ('"run"', 'StringName(\n\t\t"run"\n\t)'):
			source = 'var callbacks = {\n\t' + key + ': func() -> void:\n\t\tinner(\n\t\t\tfunc() -> void:\n\t\t\t\trecord()\n\t\t),\n}\n'
			with self.subTest(key=key):
				self.assertNotIn("lambda_argument_separator", self.rules(source))

	def test_dictionary_lambda_body_still_checks_calls_inside_real_expression_groups(self) -> None:
		source = 'var callbacks = {\n\t"run": func() -> void:\n\t\tvar result = (\n\t\t\tinner(\n\t\t\t\tfunc() -> void:\n\t\t\t\t\trecord()\n\t\t\t)\n\t\t),\n}\n'
		self.assertIn("lambda_argument_separator", self.rules(source))
		self.assertNotIn("lambda_argument_separator", self.rules(source.replace("record()\n", "record(),\n")))

	def test_lua_style_dictionary_lambda_body_restarts_expression_context(self) -> None:
		source = 'var callbacks = {\n\trun = func() -> void:\n\t\tinner(\n\t\t\tfunc() -> void:\n\t\t\t\trecord()\n\t\t),\n}\n'
		self.assertNotIn("lambda_argument_separator", self.rules(source))

	def test_lua_style_dictionary_lambda_body_retains_real_expression_groups(self) -> None:
		source = 'var callbacks = {\n\trun = func() -> void:\n\t\tvar result = (\n\t\t\tinner(\n\t\t\t\tfunc() -> void:\n\t\t\t\t\trecord()\n\t\t\t)\n\t\t),\n}\n'
		self.assertIn("lambda_argument_separator", self.rules(source))
		self.assertNotIn("lambda_argument_separator", self.rules(source.replace("record()\n", "record(),\n")))

	def test_dictionary_lambda_body_context_accepts_literal_and_grouped_keys(self) -> None:
		for key, separators in (
			('"run"', (":", "=")),
			('r"run"', (":", "=")),
			('"""run"""', (":", "=")),
			('("run")', (":", "=")),
			('(StringName("run"))', (":",)),
		):
			for separator in separators:
				source = 'var callbacks = {\n\t' + key + ' ' + separator + ' func() -> void:\n\t\tinner(\n\t\t\tfunc() -> void:\n\t\t\t\trecord()\n\t\t),\n}\n'
				with self.subTest(key=key, separator=separator):
					self.assertNotIn("lambda_argument_separator", self.rules(source))

	def test_dictionary_key_groups_preserve_nested_call_separator_requirement(self) -> None:
		for key, separators in (
			('("run")', (":", "=")),
			('(StringName(\n\t\t\t"run"\n\t\t)\n\t)', (":",)),
		):
			for separator in separators:
				source = 'var callbacks = {\n\t' + key + ' ' + separator + ' func() -> void:\n\t\tvar result = (\n\t\t\tinner(\n\t\t\t\tfunc() -> void:\n\t\t\t\t\trecord()\n\t\t\t)\n\t\t),\n}\n'
				with self.subTest(key=key, separator=separator):
					self.assertIn("lambda_argument_separator", self.rules(source))
					self.assertNotIn("lambda_argument_separator", self.rules(source.replace("record()\n", "record(),\n")))

	def test_lambda_value_continuations_restart_statement_context(self) -> None:
		for header in ('run = \\\n\t', '"run": \\\n\t', 'run \\\n\t= '):
			source = 'var callbacks = {\n\t' + header + 'func() -> void:\n\t\tinner(\n\t\t\tfunc() -> void:\n\t\t\t\trecord()\n\t\t),\n}\n'
			with self.subTest(header=header):
				self.assertNotIn("lambda_argument_separator", self.rules(source))
		for source in (
			'outer(\\\n\tfunc() -> void:\n\t\tinner(\n\t\t\tfunc() -> void:\n\t\t\t\trecord()\n\t\t)\n)\n',
			'var callbacks = [\\\n\tfunc() -> void:\n\t\tinner(\n\t\t\tfunc() -> void:\n\t\t\t\trecord()\n\t\t),\n]\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("lambda_argument_separator", self.rules(source))

	def test_multiline_literal_dictionary_key_preserves_lambda_statement_context(self) -> None:
		source = 'var callbacks = {\n\t"""ru\nn""": func() -> void:\n\t\tinner(\n\t\t\tfunc() -> void:\n\t\t\t\trecord()\n\t\t),\n}\n'
		self.assertNotIn("lambda_argument_separator", self.rules(source))
		grouped = source.replace(
			'\t\tinner(\n\t\t\tfunc() -> void:\n\t\t\t\trecord()\n\t\t),',
			'\t\tvar result = (\n\t\t\tinner(\n\t\t\t\tfunc() -> void:\n\t\t\t\t\trecord()\n\t\t\t)\n\t\t),',
		)
		self.assertIn("lambda_argument_separator", self.rules(grouped))
		self.assertNotIn("lambda_argument_separator", self.rules(grouped.replace("record()\n", "record(),\n")))

	def test_nested_final_lambda_continuation_preserves_separator_requirement(self) -> None:
		for marker in ('\\\n\t\t', '\\\n\t\t\\\n\t\t'):
			source = 'outer(\n\tinner(\n\t\t' + marker + 'func() -> void:\n\t\t\trecord()\n\t)\n)\n'
			with self.subTest(marker=marker):
				self.assertIn("lambda_argument_separator", self.rules(source))
				self.assertNotIn("lambda_argument_separator", self.rules(source.replace("record()\n", "record(),\n")))

	def test_same_owner_functions_need_two_blank_lines_including_inner_classes(self) -> None:
		for blanks in ("", "\n", "\n\n\n"):
			for indent, prefix in (("", ""), ("\t", "class Fixture:\n")):
				source = (
					prefix + indent + "func first() -> void:\n" + indent + "\tpass\n"
					+ blanks + indent + "func second() -> void:\n" + indent + "\tpass\n"
				)
				self.assertIn("definition_spacing", self.rules(source))
		clean = "class Fixture:\n\tfunc first() -> void:\n\t\tpass\n\n\n\tfunc second() -> void:\n\t\tpass\n"
		self.assertEqual(self.rules(clean), set())

	def test_adjacent_enum_class_and_function_definitions_use_the_same_boundary(self) -> None:
		clean = "enum Mode {\n\tREADY,\n\tDONE\n}\n\n\nclass Fixture:\n\tpass\n\n\nfunc run() -> void:\n\tpass\n"
		self.assertEqual(self.rules(clean), set())
		self.assertIn("definition_spacing", self.rules(clean.replace("}\n\n\nclass", "}\n\nclass")))
		member_between = "func first() -> void:\n\tpass\nvar value: int = 1\nfunc second() -> void:\n\tpass\n"
		self.assertNotIn("definition_spacing", self.rules(member_between))

	def test_documentation_and_annotations_belong_to_the_following_definition(self) -> None:
		clean = (
			"func first() -> void:\n\tpass\n\n\n## The following function.\n"
			'@warning_ignore("unused_parameter")\n'
			"func second(value: int) -> void:\n\tpass\n"
		)
		self.assertEqual(self.rules(clean), set())
		self.assertIn("definition_spacing", self.rules(clean.replace("pass\n\n\n##", "pass\n\n##")))

	def test_member_section_boundaries_take_priority_over_function_spacing(self) -> None:
		clean = (
			"func first() -> void:\n\tpass\n\n\n# --- Private methods ---\n\n"
			"## The first function in this section.\nfunc second() -> void:\n\tpass\n"
		)
		self.assertEqual(self.rules(clean), set())
		for bad in (clean.replace("pass\n\n\n#", "pass\n\n#"), clean.replace("---\n\n##", "---\n\n\n##")):
			self.assertEqual(self.rules(bad), {"section_spacing"})
		first = "# --- Public methods ---\n\nfunc run() -> void:\n\tpass\n"
		self.assertEqual(self.rules(first), set())

	def test_inner_class_sections_use_two_before_and_one_after(self) -> None:
		clean = "class Fixture:\n\n\n\t# --- Public methods ---\n\n\tfunc run() -> void:\n\t\tpass\n"
		self.assertEqual(self.rules(clean), set())
		self.assertIn("section_spacing", self.rules(clean.replace("Fixture:\n\n\n", "Fixture:\n\n")))
		self.assertEqual(self.rules("# --- Signals ---\n\n\n# --- Methods ---\n"), set())

	def test_section_before_gap_rejects_zero_one_and_three_blank_lines(self) -> None:
		for blanks in ("", "\n", "\n\n\n"):
			source = "extends RefCounted\n" + blanks + "# --- Methods ---\n\nfunc run() -> void:\n\tpass\n"
			self.assertEqual(self.rules(source), {"section_spacing"})
		clean = "extends RefCounted\n\n\n# --- Methods ---\n\nfunc run() -> void:\n\tpass\n"
		self.assertEqual(self.rules(clean), set())

	def test_adjacent_empty_sections_use_two_blank_lines_without_bof_or_eof_padding(self) -> None:
		clean = "# --- Signals ---\n\n\n# --- Methods ---\n"
		self.assertEqual(self.rules(clean), set())
		self.assertEqual(self.rules("# --- Methods ---\n"), set())
		for blanks in ("", "\n", "\n\n\n"):
			self.assertEqual(self.rules("# --- Signals ---\n" + blanks + "# --- Methods ---\n"), {"section_spacing"})

	def test_function_body_and_continuation_comments_are_not_member_sections(self) -> None:
		for source in (
			"func run() -> void:\n\t# --- Body phase ---\n\tpass\n",
			"func run() -> void:\n# --- Body phase ---\n\tpass\n",
			"call(\n\t# --- Argument notes ---\n)\n",
			"class Fixture:\n\tvar value: int:\n\t\tget:\n\t# --- Body phase ---\n\t\t\treturn 1\n",
		):
			self.assertNotIn("section_spacing", self.rules(source))
		body_gaps = "func run() -> void:\n\tpass\n\n\n\n\tpass\n"
		self.assertNotIn("definition_spacing", self.rules(body_gaps))
		class_end = "class Fixture:\n\n\n\t# --- Methods ---\n\n\nfunc run() -> void:\n\tpass\n"
		self.assertEqual(self.rules(class_end), set())

	def test_blank_layout_does_not_treat_literal_payload_as_declarations_or_gaps(self) -> None:
		source = (
			'func first() -> String:\n\treturn """\n\n\n'
			'func fake():\n# --- Fake section ---\n\n\n"""\n\n\n'
			"func second() -> void:\n\tpass\n"
		)
		self.assertEqual(self.rules(source), set())
		boundaries = readability.blank_layout_boundaries("addons/gf/fixture.gd", source)
		self.assertEqual(len(boundaries), 1)
		self.assertEqual(boundaries[0].expected, 2)

	def test_legal_short_backslash_continuation_is_preserved(self) -> None:
		source = 'if a \\\n\tand b:\n\tpass\n'
		self.assertEqual(self.rules(source), set())
		self.assertIn("condition_layout", self.rules('if a and b \\\n\tand c and d:\n\tpass\n'))
		self.assertIn("lexical_closure", self.rules('var x = 1 \\ plus 2\n'))
		self.assertIn("lexical_closure", self.rules('var x = 1 \\\n'))

	def test_unary_not_preserves_expanded_condition_group(self) -> None:
		source = 'if not (\n\ta\n\tand b\n\tand c\n\tand d\n):\n\tpass\n'
		self.assertNotIn("condition_layout", self.rules(source))

	def test_long_literal_call_argument_is_not_outer_condition_width(self) -> None:
		source = 'if predicate(\n\t"' + 'a' * 200 + '"\n):\n\tpass\n'
		self.assertNotIn("condition_layout", self.rules(source))

	def test_inventory_changes_during_reader_callback_fail_closed(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "addons/gf").mkdir(parents=True)
			(root / "tests/gf_core").mkdir(parents=True)
			(root / "addons/gf/x.gd").write_bytes(b"var x = 1\n")
			def mutate(path: Path) -> str:
				(root / "addons/gf/new.gd").write_bytes(b"var y = 2\n")
				return path.read_text(encoding="utf-8")
			report = readability.audit_repository(root, read_text=mutate)
			self.assertFalse(report["complete"])
			self.assertIn("source_identity", {issue["rule"] for issue in report["issues"]})

	def test_names_literals_and_comments_have_no_column_limit(self) -> None:
		self.assertNotIn("line_length", readability.RULES)
		self.assertNotIn("columns", readability.POLICY)
		for length in (120, 121, 1_000, 5_000):
			with self.subTest(length=length):
				self.assertEqual(self.rules("x" * length + "\n"), set())
				self.assertEqual(self.rules("func run() -> void:\n\t" + "x" * length + "\n"), set())
				self.assertEqual(self.rules("x # " + "a" * length + "\n"), set())

	def test_long_literals_need_no_length_exception(self) -> None:
		literal = '"' + "a" * 200 + '"'
		for source in (
			"var value = " + literal + "\n",
			"foo(" + literal + ")\n",
			"var a = [&" + literal + "]\n",
			"foo(" + literal + ' + "b")\n',
		):
			with self.subTest(source=source):
				self.assertEqual(self.rules(source), set())

	def test_condition_layout_depends_on_structure_instead_of_identifier_length(self) -> None:
		for length in (1, 300, 5_000):
			name = "x" * length
			with self.subTest(length=length):
				self.assertNotIn("condition_layout", self.rules("if " + name + ":\n\tpass\n"))
				self.assertNotIn("condition_layout", self.rules("if (\n\t" + name + "\n\tand b\n\tand c\n):\n\tpass\n"))
				self.assertIn("condition_layout", self.rules("if " + name + " and b and c and d:\n\tpass\n"))
				self.assertIn("condition_layout", self.rules("if " + name + " and b or c:\n\tpass\n"))

	def test_simple_call_layout_is_independent_of_name_and_literal_length(self) -> None:
		for length in (1, 120, 121, 5_000):
			name = "method_" + "x" * length
			literal = '"' + "res://" + "x" * length + '.gd"'
			for argument in (literal, name, "self." + name):
				with self.subTest(length=length, argument=argument):
					self.assertEqual(self.rules(name + "(" + argument + ")\n"), set())
					self.assertIn("simple_call_layout", self.rules(name + "(\n\t" + argument + "\n)\n"))

	def test_cast_closing_suffix_keeps_original_four_line_call(self) -> None:
		source = (
			"var error: Error = signal_value.connect(\n"
			"\tcallback,\n\tCONNECT_ONE_SHOT as Object.ConnectFlags\n) as Error\n"
		)
		self.assertEqual(self.rules(source), set())
		self.assertEqual(self.rules("var error = items.resize(LIMIT) as Error\n"), set())

	def test_argument_group_rejects_extra_layer_around_warning_message(self) -> None:
		source = (
			"push_warning(\n"
			"\t(\n"
			'\t\t"[GFPlugin][plugin.contribution.refresh_not_applied] Editor contribution refresh was not applied: kind=%s generation=%d."\n'
			"\t\t% [kind, generation]\n"
			"\t)\n"
			")\n"
		)
		self.assertIn("argument_group_layout", self.rules(source))

	def test_argument_group_warning_uses_call_continuation_without_extra_layer(self) -> None:
		for length in (1, 120, 121, 5_000):
			with self.subTest(length=length):
				source = 'push_warning(\n\t"' + "x" * length + ' kind=%s generation=%d."\n\t% [kind, generation]\n)\n'
				self.assertEqual(self.rules(source), set())

	def test_argument_group_handles_independent_parameters_and_retains_tail_comma(self) -> None:
		source = "submit(\n\t(left + right),\n\t(\n\t\tprefix + suffix\n\t),\n\tcount,\n)\n"
		self.assertIn("argument_group_layout", self.rules(source))
		clean = "submit(\n\t(left + right),\n\tprefix + suffix,\n\tcount,\n)\n"
		self.assertEqual(self.rules(clean), set())

	def test_argument_group_rejects_multiple_complete_wrapper_layers(self) -> None:
		source = "consume(\n\t(\n\t\t(\n\t\t\tleft + right\n\t\t)\n\t)\n)\n"
		self.assertIn("argument_group_layout", self.rules(source))
		self.assertEqual(self.rules("consume(left + right)\n"), set())

	def test_argument_group_keeps_inner_operator_precedence_after_outer_removal(self) -> None:
		source = "consume(\n\t(\n\t\tleft * (middle + right)\n\t)\n)\n"
		self.assertIn("argument_group_layout", self.rules(source))
		self.assertEqual(self.rules("consume(left * (middle + right))\n"), set())

	def test_argument_group_preserves_partial_operands_and_grouped_receivers(self) -> None:
		for source in (
			"consume(\n\t(\n\t\tleft + right\n\t) * scale\n)\n",
			"consume(\n\t(\n\t\tleft + right\n\t).method()\n)\n",
			"consume(\n\t(\n\t\tvalues + defaults\n\t)[index]\n)\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("argument_group_layout", self.rules(source))

	def test_argument_group_preserves_single_line_groups_and_existing_atomic_contract(self) -> None:
		self.assertEqual(self.rules("consume(\n\t(left + right),\n\tother\n)\n"), set())
		self.assertEqual(self.rules("consume((value))\n"), set())
		atomic = "consume(\n\t(\n\t\tvalue\n\t)\n)\n"
		self.assertNotIn("argument_group_layout", self.rules(atomic))
		self.assertIn("atomic_group_layout", self.rules(atomic))

	def test_argument_group_keeps_comments_and_literal_physical_structure(self) -> None:
		for source in (
			'push_warning(\n\t(\n\t\t# identify the request\n\t\t"kind=%s" % kind\n\t)\n)\n',
			'push_warning(\n\t(\n\t\t"kind=%s" # request context\n\t\t% kind\n\t)\n)\n',
			'push_warning(\n\t(\n\t\t"kind=%s" % kind\n\t) # request context\n)\n',
			'push_warning(\n\t(\n\t\t"kind=%s" % kind\n\t), # request context\n\tother\n)\n',
			'push_warning(\n\t(\n\t\t"kind=%s" \\\n\t\t% kind\n\t)\n)\n',
			'push_warning(\n\t(\n\t\t"""first line\nsecond line""" % kind\n\t)\n)\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("argument_group_layout", self.rules(source))

	def test_argument_group_keeps_conditional_cast_and_await_boundaries(self) -> None:
		for source in (
			"consume(\n\t(\n\t\tleft if ready else right\n\t)\n)\n",
			"consume(\n\t(\n\t\tmake(a, b) as RefCounted\n\t)\n)\n",
			"consume(\n\t(\n\t\tawait request.wait_settled()\n\t)\n)\n",
			"consume(\n\t(\n\t\tmake(value as RefCounted, count)\n\t)\n)\n",
			"consume(\n\t(\n\t\tmake(await request.wait_settled(), count)\n\t)\n)\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("argument_group_layout", self.rules(source))

	def test_argument_group_lambda_body_checks_its_independent_call(self) -> None:
		source = (
			"changed.connect(\n\tfunc() -> void:\n\t\tpush_warning(\n"
			'\t\t\t(\n\t\t\t\t"value=%s" % value\n\t\t\t)\n\t\t)\n)\n'
		)
		self.assertIn("argument_group_layout", self.rules(source))
		clean = (
			'changed.connect(\n\tfunc() -> void:\n\t\tpush_warning("value=%s" % value)\n)\n'
		)
		self.assertEqual(self.rules(clean), set())

	def test_argument_group_does_not_remove_lambda_context_or_required_separator(self) -> None:
		source = (
			"consume(\n\t(\n\t\tmake_callback(\n\t\t\tfunc() -> void:\n"
			"\t\t\t\trecord(),\n\t\t)\n\t)\n)\n"
		)
		self.assertEqual(self.rules(source), set())
		missing = source.replace("record(),", "record()")
		self.assertNotIn("argument_group_layout", self.rules(missing))
		self.assertIn("lambda_argument_separator", self.rules(missing))

	def test_argument_group_keeps_nested_conditional_and_lambda_groups(self) -> None:
		for source in (
			"consume(\n\t(\n\t\tmake(left if ready else right, count)\n\t)\n)\n",
			"consume(\n\t(\n\t\tfunc() -> void:\n\t\t\trecord()\n\t)\n)\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("argument_group_layout", self.rules(source))

	def test_argument_group_keeps_assignment_return_and_container_continuation_groups(self) -> None:
		for source, clean in (
			('var message = (\n\t"kind=%s"\n\t% kind\n)\n', 'var message = ("kind=%s" % kind)\n'),
			('return (\n\t"kind=%s"\n\t% kind\n)\n', 'return ("kind=%s" % kind)\n'),
			("var values = [(left + right),]\n", "var values = [(left + right),]\n"),
		):
			with self.subTest(source=source):
				self.assertNotIn("argument_group_layout", self.rules(source))
				if source != clean:
					self.assertEqual(self.rules(source), {"simple_format_layout"})
				self.assertEqual(self.rules(clean), set())

	def test_argument_group_does_not_treat_function_default_as_call_argument(self) -> None:
		source = "func build(value = (\n\tleft + right\n)) -> void:\n\tpass\n"
		self.assertNotIn("argument_group_layout", self.rules(source))

	def test_argument_group_lambda_sibling_does_not_hide_ordinary_parameter(self) -> None:
		for source in (
			"submit(\n\tfunc() -> void:\n\t\trecord(),\n\t(\n\t\tleft + right\n\t)\n)\n",
			"submit(\n\t(\n\t\tleft + right\n\t),\n\tfunc() -> void:\n\t\trecord()\n)\n",
		):
			with self.subTest(source=source):
				self.assertIn("argument_group_layout", self.rules(source))

	def test_argument_group_nested_call_in_lambda_body_has_its_own_parameter_scope(self) -> None:
		source = (
			"changed.connect(\n\tfunc() -> void:\n\t\tconsume(\n\t\t\tmake(\n"
			"\t\t\t\t(\n\t\t\t\t\tleft + right\n\t\t\t\t),\n\t\t\t\tcount\n"
			"\t\t\t)\n\t\t)\n)\n"
		)
		self.assertIn("argument_group_layout", self.rules(source))
		clean = (
			"changed.connect(\n\tfunc() -> void:\n\t\tconsume(\n\t\t\tmake(\n"
			"\t\t\t\tleft + right,\n\t\t\t\tcount\n\t\t\t)\n\t\t)\n)\n"
		)
		self.assertEqual(self.rules(clean), set())

	def test_argument_group_keyword_spelling_inside_single_line_literal_is_ordinary_data(self) -> None:
		source = 'push_warning(\n\t(\n\t\t"if else func as await value=%s" % value\n\t)\n)\n'
		self.assertIn("argument_group_layout", self.rules(source))
		self.assertEqual(self.rules('push_warning("if else func as await value=%s" % value)\n'), set())

	def test_argument_group_container_argument_uses_its_existing_delimiters(self) -> None:
		source = 'consume(\n\t(\n\t\t{\n\t\t\t"left": left,\n\t\t\t"right": right,\n\t\t}\n\t)\n)\n'
		self.assertIn("argument_group_layout", self.rules(source))
		clean = 'consume({ "left": left, "right": right, })\n'
		self.assertEqual(self.rules(clean), set())

	def test_argument_container_condition_warning_keeps_string_sum_precedence(self) -> None:
		source = (
			"push_warning(\n\t(\n\t\t(\n"
			'\t\t\t"[GFPlugin][plugin.invalid_standard_contribution_manifest] Standard editor contribution manifest "\n'
			'\t\t\t+ "state=%s issue_count=%d skipped_record_count=%d issue_kinds=%s."\n'
			"\t\t)\n\t\t% [\n"
			'\t\t\tstate if not state.is_empty() else "invalid",\n'
			'\t\t\t_GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "issue_count", 0),\n'
			'\t\t\t_GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "skipped_record_count", 0),\n'
			"\t\t\tkinds_text,\n\t\t]\n\t)\n)\n"
		)
		self.assertIn("argument_group_layout", self.rules(source))
		self.assertIn("simple_string_layout", self.rules(source))
		spans = readability.argument_group_layout_spans(readability.lex_source("addons/gf/warning.gd", source))
		self.assertEqual(len(spans), 1)
		self.assertEqual(spans[0].start, source.index("\t(") + 1)
		clean = (
			'push_warning(\n\t("[GFPlugin][plugin.invalid_standard_contribution_manifest] Standard editor contribution manifest " '
			'+ "state=%s issue_count=%d skipped_record_count=%d issue_kinds=%s.")\n\t% [\n'
			'\t\tstate if not state.is_empty() else "invalid",\n'
			'\t\t_GF_VARIANT_ACCESS_SCRIPT.get_option_int(\n\t\t\treport,\n\t\t\t"issue_count",\n\t\t\t0\n\t\t),\n'
			'\t\t_GF_VARIANT_ACCESS_SCRIPT.get_option_int(\n\t\t\treport,\n\t\t\t"skipped_record_count",\n\t\t\t0\n\t\t),\n'
			"\t\tkinds_text,\n\t]\n)\n"
		)
		self.assertEqual(self.rules(clean), set())
		self.assertEqual(readability.argument_group_layout_spans(readability.lex_source("addons/gf/warning.gd", clean)), ())

	def test_argument_container_condition_dictionary_keys_and_values_are_independent(self) -> None:
		for value, clean in (
			('{ "key": left if ready else right }', 'consume({ "key": left if ready else right })\n'),
			('{ ("left" if ready else "right"): value }', 'consume({ ("left" if ready else "right"): value })\n'),
			('{\n\t\t"key": make(\n\t\t\tleft if ready else right,\n\t\t\tcount\n\t\t),\n\t}', 'consume(\n\t{\n\t\t"key": make(\n\t\t\tleft if ready else right,\n\t\t\tcount\n\t\t),\n\t}\n)\n'),
			('{ "key": values[left if ready else right] }', 'consume({ "key": values[left if ready else right] })\n'),
		):
			with self.subTest(value=value):
				self.assertIn("argument_group_layout", self.rules("consume(\n\t(\n\t\t" + value + "\n\t)\n)\n"))
				self.assertEqual(self.rules(clean), set())

	def test_argument_container_condition_nested_containers_keep_their_layout(self) -> None:
		source = 'consume(\n\t(\n\t\t[\n\t\t\t{\n\t\t\t\t"key": [\n\t\t\t\t\tleft if ready else right,\n\t\t\t\t],\n\t\t\t},\n\t\t]\n\t)\n)\n'
		self.assertIn("argument_group_layout", self.rules(source))
		clean = 'consume(\n\t[\n\t\t{\n\t\t\t"key": [left if ready else right,],\n\t\t},\n\t]\n)\n'
		self.assertEqual(self.rules(clean), set())

	def test_argument_container_condition_whole_wrapper_chain_has_no_precedence_operands(self) -> None:
		source = "consume(\n\t(\n\t\t(\n\t\t\t[left if ready else right]\n\t\t)\n\t)\n)\n"
		spans = readability.argument_group_layout_spans(readability.lex_source("addons/gf/wrappers.gd", source))
		self.assertEqual(len(spans), 2)
		self.assertEqual(self.rules("consume([left if ready else right])\n"), set())

	def test_argument_container_condition_nested_lambda_body_call_starts_its_own_scope(self) -> None:
		source = (
			"changed.connect(\n\tfunc() -> void:\n\t\tother_changed.connect(\n"
			"\t\t\tfunc() -> void:\n\t\t\t\tconsume(\n\t\t\t\t\t(\n"
			"\t\t\t\t\t\t[left if ready else right]\n\t\t\t\t\t)\n\t\t\t\t)\n\t\t)\n)\n"
		)
		self.assertIn("argument_group_layout", self.rules(source))
		clean = (
			"changed.connect(\n\tfunc() -> void:\n\t\tother_changed.connect(\n"
			"\t\t\tfunc() -> void:\n\t\t\t\tconsume([left if ready else right])\n\t\t)\n)\n"
		)
		self.assertEqual(self.rules(clean), set())

	def test_argument_container_condition_ancestor_container_does_not_hide_own_ternary(self) -> None:
		for source in (
			"var values = [\n\tconsume(\n\t\t(\n\t\t\tleft if ready else right\n\t\t)\n\t),\n]\n",
			'var values = {\n\t"key": consume(\n\t\t(\n\t\t\tleft if ready else right\n\t\t)\n\t),\n}\n',
		):
			with self.subTest(source=source):
				self.assertEqual(readability.argument_group_layout_spans(readability.lex_source("addons/gf/ancestor.gd", source)), ())

	def test_argument_container_condition_direct_calls_indexes_and_outer_ternary_keep_groups(self) -> None:
		for value in (
			"make(left if ready else right, count)",
			"values[left if ready else right]",
			"left if ready else [right]",
			'[left if ready else right] if available else []',
		):
			with self.subTest(value=value):
				self.assertNotIn("argument_group_layout", self.rules("consume(\n\t(\n\t\t" + value + "\n\t)\n)\n"))
		assignment = "var value = (make([left if ready else right], count))\n"
		self.assertNotIn("call_group_layout", self.rules(assignment))

	def test_argument_container_condition_does_not_hide_lambda_cast_or_await(self) -> None:
		for value in (
			"[left as Node if ready else right]",
			"[await request.wait_settled() if ready else right]",
			"[\n\t\t\tfunc() -> void:\n\t\t\t\trecord(),\n\t\t]",
		):
			with self.subTest(value=value):
				self.assertNotIn("argument_group_layout", self.rules("consume(\n\t(\n\t\t" + value + "\n\t)\n)\n"))

	def test_argument_container_condition_preserves_physical_boundaries(self) -> None:
		for source in (
			"consume(\n\t(\n\t\t# selected value\n\t\t[left if ready else right]\n\t)\n)\n",
			"consume(\n\t(\n\t\t[left if ready else right]\n\t) # selected value\n)\n",
			"consume(\n\t(\n\t\t[left if ready else right] \\\n\t\t+ other\n\t)\n)\n",
			'consume(\n\t(\n\t\t"""value=%s\nnext line""" % [left if ready else right]\n\t)\n)\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("argument_group_layout", self.rules(source))

	def test_argument_container_condition_many_siblings_remain_separate_parameters(self) -> None:
		source = "consume(\n" + "\t(\n\t\t[left if ready else right]\n\t),\n" * 300 + ")\n"
		view = readability.lex_source("addons/gf/container_siblings.gd", source)
		spans = readability.argument_group_layout_spans(view)
		self.assertEqual(len(spans), 300)
		self.assertTrue(all(source[span.start:span.end] == "(\n\t\t[left if ready else right]\n\t)" for span in spans))

	def test_simple_string_group_preserves_modulo_operand_and_array_layout(self) -> None:
		source = 'push_warning(\n\t(\n\t\t"Request state=%s "\n\t\t+ "issue_count=%d "\n\t\t+ "kind=%s."\n\t)\n\t% [\n\t\tstate if ready else "invalid",\n\t\tissue_count,\n\t\tkind,\n\t]\n)\n'
		self.assertIn("simple_string_layout", self.rules(source))
		spans = readability.simple_string_layout_spans(readability.lex_source("addons/gf/string_group.gd", source))
		self.assertEqual(len(spans), 1)
		self.assertEqual(spans[0].start, source.index("\t(") + 1)
		self.assertIsNotNone(spans[0].group_open_index)
		clean = 'push_warning(\n\t("Request state=%s " + "issue_count=%d " + "kind=%s.")\n\t% [\n\t\tstate if ready else "invalid",\n\t\tissue_count,\n\t\tkind,\n\t]\n)\n'
		self.assertEqual(self.rules(clean), set())

	def test_simple_string_literal_anchor_and_name_atoms_have_no_width_limit(self) -> None:
		for length in (1, 120, 121, 5_000):
			with self.subTest(length=length):
				literal = '"' + "x" * length + '"'
				self.assertIn("simple_string_layout", self.rules("consume(\n\t" + literal + "\n\t+ name\n\t+ self.suffix\n)\n"))
				self.assertEqual(self.rules("consume(" + literal + " + name + self.suffix)\n"), set())

	def test_simple_string_complete_container_items_preserve_commas(self) -> None:
		for source, clean in (
			('consume(\n\t"left"\n\t+ "right",\n\tother\n)\n', 'consume(\n\t"left" + "right",\n\tother\n)\n'),
			('var values = [\n\t"left"\n\t+ "right",\n]\n', 'var values = ["left" + "right",]\n'),
			('var values = {\n\t"left"\n\t+ "right": value,\n}\n', 'var values = { "left" + "right": value, }\n'),
			('var values = {\n\t"key": "left"\n\t+ "right",\n}\n', 'var values = { "key": "left" + "right", }\n'),
		):
			with self.subTest(source=source):
				self.assertIn("simple_string_layout", self.rules(source))
				self.assertEqual(self.rules(clean), set())

	def test_simple_string_assignment_and_return_groups_retain_required_parentheses(self) -> None:
		for source, clean in (
			('var message: String = (\n\t"left"\n\t+ name\n)\n', 'var message: String = ("left" + name)\n'),
			('func message() -> String:\n\treturn (\n\t\t"left"\n\t\t+ name\n\t)\n', 'func message() -> String:\n\treturn ("left" + name)\n'),
		):
			with self.subTest(source=source):
				self.assertIn("simple_string_layout", self.rules(source))
				self.assertEqual(self.rules(clean), set())

	def test_simple_string_raw_escaped_and_quote_literals_keep_exact_payloads(self) -> None:
		for first in ('r"C:\\folder"', '"quote=\\\"; newline=\\n"', "'left'", '"if else func as await"', '"""left"""', 'r"""left"""'):
			with self.subTest(first=first):
				self.assertIn("simple_string_layout", self.rules("consume(\n\t" + first + '\n\t+ "suffix"\n)\n'))
				self.assertEqual(self.rules("consume(" + first + ' + "suffix")\n'), set())

	def test_simple_string_numbers_and_unknown_variable_types_are_not_concat_anchors(self) -> None:
		for expression in ('1 + 2', 'left + right', '"left" + 1', '"left" + true', '"left" + null', '&"left" + &"right"', '^"left" + ^"right"'):
			with self.subTest(expression=expression):
				self.assertNotIn("simple_string_layout", self.rules("var value = (\n\t" + expression + "\n)\n"))
		for type_name in ("int", "float", "String"):
			self.assertNotIn("simple_string_layout", self.rules("var value: " + type_name + " = (\n\tleft\n\t+ right\n)\n"))

	def test_simple_string_complex_calls_indexes_casts_and_conditions_keep_layout(self) -> None:
		for expression in (
			'"left" + make(left, right)', '"left" + values[index]',
			'"left" + (value as String)', '"left" + await request.wait_settled()',
			'"left" + (first if ready else other)', '"left" + "right" if ready else other',
			'"left" + func() -> void:\n\t\trecord()',
		):
			with self.subTest(expression=expression):
				self.assertNotIn("simple_string_layout", self.rules("var value = (\n\t" + expression + "\n)\n"))

	def test_simple_string_partial_math_and_modulo_are_outside_complete_expression_scope(self) -> None:
		for source in (
			'consume(\n\t"left"\n\t+ "right" % value\n)\n',
			'consume(\n\t"left"\n\t+ "right" * scale\n)\n',
			'consume(\n\t"left"\n\t+ "right" - value\n)\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("simple_string_layout", self.rules(source))

	def test_simple_string_comments_continuations_and_multiline_literal_are_barriers(self) -> None:
		for source in (
			'consume(\n\t"left" # label\n\t+ "right"\n)\n',
			'consume(\n\t"left"\n\t+ "right" # label\n)\n',
			'consume(\n\t"left" \\\n\t+ "right"\n)\n',
			'consume(\n\t"""first\nsecond"""\n\t+ "right"\n)\n',
			'var value = (\n\t"left"\n\t+ "right"\n) # label\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("simple_string_layout", self.rules(source))

	def test_simple_string_lambda_body_call_keeps_its_independent_statement_layout(self) -> None:
		source = 'changed.connect(\n\tfunc() -> void:\n\t\tconsume(\n\t\t\t"left"\n\t\t\t+ name\n\t\t)\n)\n'
		self.assertIn("simple_string_layout", self.rules(source))
		self.assertEqual(self.rules('changed.connect(\n\tfunc() -> void:\n\t\tconsume("left" + name)\n)\n'), set())

	def test_simple_string_default_parameter_rhs_is_complete_and_preserves_prefix(self) -> None:
		source = 'func configure(\n\tvalue: String = "left"\n\t+ "right",\n\tcount: int = 0\n) -> void:\n\tpass\n'
		self.assertIn("simple_string_layout", self.rules(source))
		spans = readability.simple_string_layout_spans(readability.lex_source("addons/gf/default.gd", source))
		self.assertEqual(len(spans), 1)
		self.assertEqual(source[spans[0].start:spans[0].end], '"left"\n\t+ "right"')
		clean = 'func configure(value: String = "left" + "right", count: int = 0) -> void:\n\tpass\n'
		self.assertEqual(self.rules(clean), set())
		partial = 'func configure(\n\tvalue: String = "left"\n\t+ "right" % values\n) -> void:\n\tpass\n'
		self.assertNotIn("simple_string_layout", self.rules(partial))
		self.assertEqual(readability.simple_string_layout_spans(readability.lex_source("addons/gf/default.gd", partial)), ())

	def test_simple_format_real_timeline_warning_joins_the_entire_call(self) -> None:
		literal = '"[GFConfiguredTweenAction][configured_tween_action.invalid_timeline] Cannot play the timeline: %s."'
		source = "push_warning(\n\t" + literal + "\n\t% captured_plan.error\n)\n"
		self.assertIn("simple_format_layout", self.rules(source))
		spans = readability.simple_format_layout_spans(readability.lex_source("addons/gf/timeline.gd", source))
		self.assertTrue(any(span.context == "call" and source[span.start:span.end] == source.rstrip("\n") for span in spans))
		self.assertEqual(self.rules("push_warning(" + literal + " % captured_plan.error)\n"), set())

	def test_simple_format_inline_argument_still_requires_simple_call_to_use_one_line(self) -> None:
		for source in ('push_warning(\n\t"value=%s" % value\n)\n', 'logger.warn(\n\t"value=%s" % value,\n)\n'):
			with self.subTest(source=source):
				self.assertIn("simple_format_layout", self.rules(source))
		self.assertEqual(self.rules('logger.warn("value=%s" % value,)\n'), set())

	def test_simple_format_multi_parameter_call_preserves_its_structure(self) -> None:
		source = 'report(\n\t"value=%s"\n\t% value,\n\tcount\n)\n'
		self.assertIn("simple_format_layout", self.rules(source))
		spans = readability.simple_format_layout_spans(readability.lex_source("addons/gf/report.gd", source))
		self.assertFalse(any(span.context == "call" for span in spans))
		self.assertTrue(any(source[span.start:span.end] == '"value=%s"\n\t% value' for span in spans))
		self.assertEqual(self.rules('report(\n\t"value=%s" % value,\n\tcount\n)\n'), set())

	def test_simple_format_literal_and_scalar_atoms_use_the_same_width_independent_rule(self) -> None:
		for length in (1, 120, 121, 5_000):
			with self.subTest(length=length):
				literal = '"' + "x" * length + '%s"'
				self.assertIn("simple_format_layout", self.rules("emit(\n\t" + literal + "\n\t% value\n)\n"))
				self.assertEqual(self.rules("emit(" + literal + " % value)\n"), set())
		for left in ('"%s"', "'%s'", 'r"%s"', '"""%s"""', '("%s")'):
			for right in ('value', 'self.value', '42', '-42', '~mask', 'true', 'null', '"value"', 'r"value"', '"""value"""', '((value))', '(not ready)'):
				with self.subTest(left=left, right=right):
					self.assertIn("simple_format_layout", self.rules("emit(\n\t" + left + "\n\t% " + right + "\n)\n"))
					self.assertEqual(self.rules("emit(" + left + " % " + right + ")\n"), set())

	def test_simple_format_complete_containers_defaults_assignments_and_returns(self) -> None:
		for source, clean in (
			('var values = [\n\t"value=%s"\n\t% value,\n]\n', 'var values = ["value=%s" % value,]\n'),
			('var values = {\n\t"key=%s"\n\t% key: value,\n}\n', 'var values = { "key=%s" % key: value, }\n'),
			('var values = {\n\t"key": "value=%s"\n\t% value,\n}\n', 'var values = { "key": "value=%s" % value, }\n'),
			('func configure(\n\tvalue: String = "%s"\n\t% name\n) -> void:\n\tpass\n', 'func configure(value: String = "%s" % name) -> void:\n\tpass\n'),
			('var message: String = (\n\t"value=%s"\n\t% value\n)\n', 'var message: String = ("value=%s" % value)\n'),
			('func message() -> String:\n\treturn (\n\t\t"value=%s"\n\t\t% value\n\t)\n', 'func message() -> String:\n\treturn ("value=%s" % value)\n'),
		):
			with self.subTest(source=source):
				self.assertIn("simple_format_layout", self.rules(source))
				self.assertEqual(self.rules(clean), set())

	def test_simple_format_partial_operators_are_not_complete_format_expressions(self) -> None:
		for expression in ('"%s" % value + suffix', '"%s" % value * scale', '"%s" % value % other', '"%s" % value if ready else other', 'prefix + "%s" % value'):
			with self.subTest(expression=expression):
				self.assertNotIn("simple_format_layout", self.rules("consume(\n\t" + expression + "\n)\n"))

	def test_simple_format_complex_scalar_and_nonstring_left_operands_are_preserved(self) -> None:
		for left, right in (
			('"%s"', '[]'), ('"%s"', '{}'), ('"%s"', '[value]'), ('"%s"', 'make(left, right)'),
			('"%s"', 'values[index]'), ('"%s"', 'value as String'), ('"%s"', 'await request.wait_settled()'),
			('"%s"', 'first if ready else other'), ('"%s"', '&"key"'), ('"%s"', '^"node"'), ('"%s"', '$Node'),
			('&"%s"', 'value'), ('^"%s"', 'value'), ('template', 'value'), ('("%s" + suffix)', 'value'),
		):
			with self.subTest(left=left, right=right):
				self.assertNotIn("simple_format_layout", self.rules("consume(\n\t" + left + "\n\t% " + right + "\n)\n"))

	def test_simple_format_independent_group_inside_complex_math_preserves_parentheses(self) -> None:
		source = 'consume(\n\t(\n\t\t"value=%s"\n\t\t% value\n\t)\n\t+ suffix\n)\n'
		self.assertIn("simple_format_layout", self.rules(source))
		spans = readability.simple_format_layout_spans(readability.lex_source("addons/gf/grouped_format.gd", source))
		self.assertFalse(any(span.context == "call" for span in spans))
		self.assertTrue(any(source[span.start:span.end] == '(\n\t\t"value=%s"\n\t\t% value\n\t)' for span in spans))
		self.assertEqual(self.rules('consume(("value=%s" % value) + suffix)\n'), set())

	def test_simple_format_complex_receiver_checks_only_its_independent_argument(self) -> None:
		source = 'factory().warn(\n\t"value=%s"\n\t% value\n)\n'
		self.assertIn("simple_format_layout", self.rules(source))
		spans = readability.simple_format_layout_spans(readability.lex_source("addons/gf/complex_receiver.gd", source))
		self.assertFalse(any(span.context == "call" for span in spans))
		self.assertEqual(self.rules('factory().warn("value=%s" % value)\n'), set())

	def test_simple_format_node_access_and_literal_receivers_keep_their_call_structure(self) -> None:
		for receiver in ('$Node.warn', '%UniqueNode.warn', '$Node/Child.warn', '$"Node Path".warn', 'get_node(node_path).warn', '"receiver".warn'):
			for prefix, suffix, indent in (
				("", "\n", ""),
				("var result = ", "\n", ""),
				("func report() -> Variant:\n\treturn ", "\n", "\t"),
				("changed.connect(\n\tfunc() -> void:\n\t\t", "\n)\n", "\t\t"),
			):
				with self.subTest(receiver=receiver, prefix=prefix):
					clean = prefix + receiver + '(\n' + indent + '\t"value=%s" % value\n' + indent + ')' + suffix
					self.assertNotIn("simple_format_layout", self.rules(clean))
					clean_spans = readability.simple_format_layout_spans(readability.lex_source("addons/gf/node_receiver.gd", clean))
					self.assertFalse(any(span.context == "call" for span in clean_spans))
					expression = '"value=%s"\n' + indent + '\t% value'
					source = prefix + receiver + '(\n' + indent + '\t' + expression + '\n' + indent + ')' + suffix
					self.assertIn("simple_format_layout", self.rules(source))
					spans = readability.simple_format_layout_spans(readability.lex_source("addons/gf/node_receiver.gd", source))
					self.assertFalse(any(span.context == "call" for span in spans))
					self.assertTrue(any(span.context == "expression" and source[span.start:span.end] == expression for span in spans))

	def test_simple_format_ordinary_member_calls_after_binary_operators_still_use_one_line(self) -> None:
		for prefix, receiver in (
			("", "node_ref.warn"),
			('var text = "outer%s" % ', "Node.warn"),
			("var text = template % ", "Node.warn"),
			('var text = "outer%s" \\\n\t% ', "Node.warn"),
			("var quotient = $Node / ", "Other.warn"),
			("var quotient = $Node/ ", "Other.warn"),
			("var quotient = $Node / ", "Other.warn"),
		):
			with self.subTest(prefix=prefix, receiver=receiver):
				call = receiver + '(\n\t"inner%s" % value\n)'
				source = prefix + call + "\n"
				self.assertIn("simple_format_layout", self.rules(source))
				spans = readability.simple_format_layout_spans(readability.lex_source("addons/gf/ordinary_receiver.gd", source))
				self.assertTrue(any(span.context == "call" and source[span.start:span.end] == call for span in spans))
				self.assertEqual(self.rules(prefix + receiver + '("inner%s" % value)\n'), set())

	def test_simple_format_absolute_and_quoted_relative_node_paths_keep_receiver_boundaries(self) -> None:
		for receiver in (
			'$/Root/Child.warn', '%/Root/Child.warn',
			'$ /Root/Child.warn', '$/ Root/Child.warn', '$ / Root/Child.warn',
			'% /Root/Child.warn', '%/ Root/Child.warn', '% / Root/Child.warn',
			'$%/Root/Child.warn', '$% /Root/Child.warn', '$ %/Root/Child.warn',
			'$ % /Root/Child.warn', '$ % / Root/Child.warn',
			'$ Root/Child.warn', '% Root/Child.warn', '$% Root/Child.warn',
			'$ %Root/Child.warn', '$ % Root/Child.warn',
			'$"../Child".warn', '%"../Child".warn',
			'$ "../Child".warn', '% "../Child".warn',
			'$% "../Child".warn', '$ % "../Child".warn',
			'$\\\n\tNode.warn', '$\\\n\t/Root/Child.warn',
			'%\\\n\tUnique.warn', '%\\\n\t/Root/Child.warn',
			'$%\\\n\t/Root/Child.warn', '$\\\n\t%/Root/Child.warn',
			'$Root/\\\n\tChild.warn', '%Root/\\\n\tChild.warn',
			'$Root\\\n\t/Child.warn', '%Root\\\n\t/Child.warn',
			'$Root /\\\n\tChild.warn', '%Root /\\\n\tChild.warn',
			'$Root\\\n\t / Child.warn', '%Root\\\n\t / Child.warn',
		):
			for prefix, suffix, indent in (
				("func report() -> void:\n\t", "\n", "\t"),
				("var result = ", "\n", ""),
				("func report() -> Variant:\n\treturn ", "\n", "\t"),
				("var results = [\n\t", ",\n]\n", "\t"),
				("func connect_handler() -> void:\n\tchanged.connect(\n\t\tfunc() -> void:\n\t\t\t", "\n\t)\n", "\t\t\t"),
			):
				with self.subTest(receiver=receiver, prefix=prefix):
					physical_receiver = receiver.replace("\n", "\n" + indent)
					call_indent = indent + ("\t" if "\n" in receiver else "")
					clean = prefix + physical_receiver + '(\n' + call_indent + '\t"value=%s" % value\n' + call_indent + ')' + suffix
					self.assertNotIn("simple_format_layout", self.rules(clean))
					clean_spans = readability.simple_format_layout_spans(readability.lex_source("addons/gf/absolute_node_receiver.gd", clean))
					self.assertFalse(any(span.context == "call" for span in clean_spans))
					expression = '"value=%s"\n' + call_indent + '\t% value'
					source = prefix + physical_receiver + '(\n' + call_indent + '\t' + expression + '\n' + call_indent + ')' + suffix
					view = readability.lex_source("addons/gf/absolute_node_receiver.gd", source)
					self.assertEqual(view.issues, ())
					self.assertIn("simple_format_layout", self.rules(source))
					spans = readability.simple_format_layout_spans(view)
					self.assertFalse(any(span.context == "call" for span in spans))
					self.assertTrue(any(span.context == "expression" and source[span.start:span.end] == expression for span in spans))
		for receiver in (
			'$Root/\n\tChild.warn', '$Root\n\t/Child.warn',
			'%Root/\n\tChild.warn', '%Root\n\t/Child.warn',
			'$Root/ # path note\n\tChild.warn', '$Root # path note\n\t/Child.warn',
			'%Root/ # path note\n\tChild.warn', '%Root # path note\n\t/Child.warn',
		):
			for prefix, suffix, indent in (
				("func report() -> void:\n\tconsume(\n\t\t", "\n\t)\n", "\t\t"),
				("var result = consume(\n\t", "\n)\n", "\t"),
				("func report() -> Variant:\n\treturn consume(\n\t\t", "\n\t)\n", "\t\t"),
				("var results = [\n\t", ",\n]\n", "\t"),
				("func connect_handler() -> void:\n\tchanged.connect(\n\t\tfunc() -> void:\n\t\t\tconsume(\n\t\t\t\t", "\n\t\t\t)\n\t)\n", "\t\t\t\t"),
				("func report() -> void:\n\tconsume(\n\t\t", ",\n\t\tcount\n\t)\n", "\t\t"),
			):
				with self.subTest(receiver=receiver, prefix=prefix, suffix=suffix):
					physical_receiver = receiver.replace("\n", "\n" + indent)
					call_indent = indent + "\t"
					clean = prefix + physical_receiver + '(\n' + call_indent + '\t"value=%s" % value\n' + call_indent + ')' + suffix
					self.assertNotIn("simple_format_layout", self.rules(clean))
					clean_spans = readability.simple_format_layout_spans(readability.lex_source("addons/gf/implicit_node_receiver.gd", clean))
					self.assertFalse(any(span.context == "call" for span in clean_spans))
					expression = '"value=%s"\n' + call_indent + '\t% value'
					source = prefix + physical_receiver + '(\n' + call_indent + '\t' + expression + '\n' + call_indent + ')' + suffix
					view = readability.lex_source("addons/gf/implicit_node_receiver.gd", source)
					self.assertEqual(view.issues, ())
					self.assertIn("simple_format_layout", self.rules(source))
					spans = readability.simple_format_layout_spans(view)
					self.assertFalse(any(span.context == "call" for span in spans))
					self.assertTrue(any(span.context == "expression" and source[span.start:span.end] == expression for span in spans))

	def test_simple_format_physical_comments_continuations_and_multiline_literals_are_barriers(self) -> None:
		for source in (
			'warn(\n\t"%s" # label\n\t% value\n)\n', 'warn(\n\t"%s"\n\t% value # label\n)\n',
			'warn(\n\t"%s" \\\n\t% value\n)\n', 'warn(\n\t"""first\nsecond %s"""\n\t% value\n)\n',
			'var value = (\n\t"%s"\n\t% name\n) # label\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("simple_format_layout", self.rules(source))
		call_comment = 'warn( # caller label\n\t"%s" % value\n)\n'
		self.assertNotIn("simple_format_layout", self.rules(call_comment))

	def test_simple_format_lambda_body_call_and_template_offsets_preserve_ownership(self) -> None:
		lambda_source = 'changed.connect(\n\tfunc() -> void:\n\t\tpush_warning(\n\t\t\t"value=%s"\n\t\t\t% value\n\t\t)\n)\n'
		self.assertIn("simple_format_layout", self.rules(lambda_source))
		self.assertEqual(self.rules('changed.connect(\n\tfunc() -> void:\n\t\tpush_warning("value=%s" % value)\n)\n'), set())
		path = "addons/gf/tools/config_pipeline/templates/read_config.gd.txt"
		source = 'var database = load({DatabasePath})\nwarn(\n\t"value=%s"\n\t% state.value\n)\n'
		self.assertIn("simple_format_layout", self.rules(source, path))
		spans = readability.simple_format_layout_spans(readability.lex_source(path, source))
		self.assertTrue(any(span.context == "call" and source[span.start:span.end] == 'warn(\n\t"value=%s"\n\t% state.value\n)' for span in spans))

	def test_simple_format_many_sibling_parameters_keep_commas_and_independent_ranges(self) -> None:
		source = "emit(\n" + '\t"value=%s"\n\t% value,\n' * 300 + ")\n"
		self.assertIn("simple_format_layout", self.rules(source))
		spans = readability.simple_format_layout_spans(readability.lex_source("addons/gf/format_siblings.gd", source))
		self.assertEqual(len(spans), 300)
		self.assertTrue(all(span.context == "expression" and source[span.start:span.end] == '"value=%s"\n\t% value' for span in spans))

	def test_call_group_rejects_extra_assignment_layer_around_record_lookup(self) -> None:
		source = (
			"_editor_contribution_records = (_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(\n"
			'\t_builtin_tool_editor_contribution_report,\n\t"records",\n\tstandard_records\n)\n)\n'
		)
		self.assertIn("call_group_layout", self.rules(source))
		clean = (
			"_editor_contribution_records = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(\n"
			'\t_builtin_tool_editor_contribution_report,\n\t"records",\n\tstandard_records\n)\n'
		)
		self.assertEqual(self.rules(clean), set())

	def test_call_group_assignment_uses_call_delimiters_when_outer_opener_is_on_own_line(self) -> None:
		source = "var records: Dictionary = (\n\tstore.get_records(\n\t\tcontext,\n\t\tkey\n\t)\n)\n"
		self.assertIn("call_group_layout", self.rules(source))
		self.assertEqual(self.rules("var records: Dictionary = store.get_records(context, key)\n"), set())

	def test_call_group_return_and_single_line_calls_do_not_need_extra_layers(self) -> None:
		for source in (
			"return (make(left, right))\n",
			"func build() -> Variant:\n\treturn (make(left, right))\n",
			"return (\n\tmake(\n\t\tleft,\n\t\tright\n\t)\n)\n",
			"var value = (make(left, right))\n",
			'const RESOURCE_SCRIPT = (preload("res://addons/gf/example.gd"))\n',
			'var value = (make("if else func as await", count))\n',
		):
			with self.subTest(source=source):
				self.assertIn("call_group_layout", self.rules(source))
		self.assertEqual(self.rules("return make(left, right)\n"), set())

	def test_call_group_removes_whole_wrapper_chain_without_changing_call_arguments(self) -> None:
		for source in (
			"var value = (((make(left, right))))\n",
			"return (\n\t(\n\t\tmake(left, right)\n\t)\n)\n",
		):
			with self.subTest(source=source):
				self.assertIn("call_group_layout", self.rules(source))
		self.assertEqual(self.rules("var value = make(\n\t(left + right) * scale,\n\tcount\n)\n"), set())

	def test_call_group_member_assignments_and_inferred_declarations_are_complete_values(self) -> None:
		for source in (
			"self.records = (store.get_records(context, key))\n",
			"records[key] = (make(left, right))\n",
			"var records := (store.get_records(context, key))\n",
		):
			with self.subTest(source=source):
				self.assertIn("call_group_layout", self.rules(source))

	def test_call_group_preserves_operator_operands_and_receiver_suffixes(self) -> None:
		for source in (
			"var value = (make(left, right)) + offset\n",
			"return (make(left, right)).member\n",
			"return (make(left, right))[index]\n",
			"var value = (make(left, right)) as RefCounted\n",
			"var value = (make(left, right))(next_value)\n",
			"var value = (left + make(right, count))\n",
			"var value = (factory().make(left, right))\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("call_group_layout", self.rules(source))

	def test_call_group_preserves_comments_continuations_and_multiline_literals(self) -> None:
		for source in (
			"var value = (\n\t# lookup context\n\tmake(left, right)\n)\n",
			"var value = (\n\tmake(left, right) # lookup context\n)\n",
			"var value = (\n\tmake(left, right)\n) # lookup context\n",
			"var value = (\n\tmake(\n\t\tleft, \\\n\t\tright\n\t)\n)\n",
			'var value = (\n\tmake("""first line\nsecond line""", right)\n)\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("call_group_layout", self.rules(source))

	def test_call_group_preserves_conditional_cast_await_and_lambda_context(self) -> None:
		for source in (
			"var value = (make(left, right) as RefCounted)\n",
			"var value = (make(left if ready else right, count))\n",
			"var value = (make(left, right) if ready else make(default, count))\n",
			"var value = (await request.wait_settled())\n",
			"var value = (make(left as RefCounted, count))\n",
			"var value = (make(await request.wait_settled(), count))\n",
			"var callback = (\n\tmake_callback(\n\t\tfunc() -> void:\n\t\t\trecord(),\n\t)\n)\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("call_group_layout", self.rules(source))

	def test_call_group_keeps_atomic_and_arithmetic_continuation_groups(self) -> None:
		for source in (
			'const PATH = ("res://addons/gf/example.gd")\n',
			"var value = (left)\n",
			"var total = (left + right)\n",
			"return (make(left, right) + offset)\n",
		):
			with self.subTest(source=source):
				self.assertEqual(self.rules(source), set())

	def test_call_group_does_not_extend_assignment_scope_to_defaults_containers_or_conditions(self) -> None:
		for source in (
			"func build(value = (make(left, right))) -> void:\n\tpass\n",
			"consume((make(left, right)))\n",
			"var values = [(make(left, right))]\n",
			"if value == (make(left, right)):\n\tpass\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("call_group_layout", self.rules(source))

	def test_call_group_lambda_body_independent_assignment_keeps_neighbor_statements(self) -> None:
		source = (
			"changed.connect(\n\tfunc() -> void:\n\t\trecord_start()\n"
			"\t\tvar value = (\n\t\t\tmake(left, right)\n\t\t)\n\t\tconsume(value)\n)\n"
		)
		self.assertIn("call_group_layout", self.rules(source))
		clean = (
			"changed.connect(\n\tfunc() -> void:\n\t\trecord_start()\n"
			"\t\tvar value = make(left, right)\n\t\tconsume(value)\n)\n"
		)
		self.assertEqual(self.rules(clean), set())

	def test_call_group_lambda_body_independent_return_has_its_own_statement_scope(self) -> None:
		source = (
			"changed.connect(\n\tfunc() -> Variant:\n\t\trecord_start()\n"
			"\t\treturn (make(left, right))\n)\n"
		)
		self.assertIn("call_group_layout", self.rules(source))
		clean = source.replace("return (make(left, right))", "return make(left, right)")
		self.assertEqual(self.rules(clean), set())

	def test_call_group_named_lambda_parameters_and_typed_return_keep_statement_scope(self) -> None:
		source = (
			"changed.connect(\n\tfunc debug_name(value: int) -> Array[int]:\n"
			"\t\tvar result = (build_array(value, count))\n\t\treturn (normalize(result, count))\n)\n"
		)
		self.assertIn("call_group_layout", self.rules(source))
		clean = source.replace("(build_array(value, count))", "build_array(value, count)")
		clean = clean.replace("(normalize(result, count))", "normalize(result, count)")
		self.assertEqual(self.rules(clean), set())

	def test_call_group_nested_named_lambda_restores_outer_body_after_inner_close(self) -> None:
		source = (
			"changed.connect(\n\tfunc outer_trace(value: int) -> Array[int]:\n"
			"\t\tvar callback = make_callback(\n\t\t\tfunc inner_trace() -> Array[int]:\n"
			"\t\t\t\treturn (build_array(value, count))\n\t\t)\n"
			"\t\treturn (invoke_callback(callback, value))\n)\n"
		)
		issues = readability.audit_source("addons/gf/named_callbacks.gd", source)
		self.assertEqual([issue["line"] for issue in issues if issue["rule"] == "call_group_layout"], [5, 7])
		clean = source.replace("(build_array(value, count))", "build_array(value, count)")
		clean = clean.replace("(invoke_callback(callback, value))", "invoke_callback(callback, value)")
		self.assertEqual(self.rules(clean), set())

	def test_call_group_named_function_default_is_separate_from_return_value(self) -> None:
		source = (
			"func build_array(value: int = (make(left, right))) -> Array[int]:\n"
			"\treturn (normalize(value, count))\n"
		)
		issues = readability.audit_source("addons/gf/named_method.gd", source)
		self.assertEqual([issue["line"] for issue in issues if issue["rule"] == "call_group_layout"], [2])

	def test_call_group_many_unfinished_lambda_headers_recover_at_next_statement(self) -> None:
		source = "sink(\n\t" + "func() " * 10_000 + "\n)\nvar value = (make(left, right))\n"
		view = readability.lex_source("addons/gf/unfinished_headers.gd", source)
		self.assertEqual(view.issues, ())
		spans = readability.call_group_layout_spans(view)
		self.assertEqual(len(spans), 1)
		self.assertEqual(source[spans[0].start:spans[0].end], "(make(left, right))")
		with patch.object(readability, "MAX_TOKENS", 64):
			limited = readability.lex_source("addons/gf/unfinished_headers.gd", source)
			self.assertIn("source_budget", {issue["rule"] for issue in limited.issues})
			self.assertEqual(readability.call_group_layout_spans(limited), ())

	def test_call_group_keeps_layer_sort_comparison_and_right_operand_group(self) -> None:
		source = (
			"func _sort_layer_state(left: Dictionary, right: Dictionary) -> bool:\n"
			'\tvar left_order: int = GFVariantData.get_option_int(left, "draw_order")\n'
			'\tvar right_order: int = GFVariantData.get_option_int(right, "draw_order")\n'
			"\tif left_order == right_order:\n\t\treturn ("
			'GFVariantData.get_option_int(left, "source_index") '
			"< (GFVariantData.get_option_int("
			'right, "source_index")))\n'
			"\treturn left_order < right_order\n"
		)
		view = readability.lex_source("addons/gf/layer_sort.gd", source)
		self.assertEqual(readability.call_group_layout_spans(view), ())
		self.assertEqual(self.rules(source), set())

	def test_call_group_keeps_arithmetic_index_and_prefix_operator_operand_groups(self) -> None:
		for expression in (
			"make(left, count) + other(right, count)",
			"make(left, count) + (other(right, count))",
			"make(left, count) < (other(right, count))",
			"make(left, count) and (other(right, count))",
			"values[index] + (other(right, count))",
			"-(make(left, right))",
			"+(make(left, right))",
			"not (make(left, right))",
		):
			with self.subTest(expression=expression):
				source = "return (" + expression + ")\n"
				view = readability.lex_source("addons/gf/operator_groups.gd", source)
				self.assertEqual(readability.call_group_layout_spans(view), ())
				self.assertEqual(self.rules(source), set())

	def test_cast_nominal_qualified_and_flat_generic_suffixes_are_bounded(self) -> None:
		for type_name in ("Error", "Object.ConnectFlags", "RefCounted", "Array[Node]",
			"Dictionary[String, Node]", "Array[Namespace.Type]", "Dictionary[String, Namespace.Type]"):
			with self.subTest(type_name=type_name):
				source = "var value = make(\n\tleft,\n\tright,\n\tthird\n) as " + type_name + "\n"
				self.assertEqual(self.rules(source), set())
				view = readability.lex_source("addons/gf/x.gd", source)
				span = readability.cast_layout_spans(view)[0]
				self.assertEqual(source[view.tokens[span.type_start_index].start:view.tokens[span.type_end_index - 1].end], type_name)

	def test_cast_suffix_on_expanded_containers_preserves_their_layout(self) -> None:
		self.assertEqual(self.rules("var items = [\n\t1,\n\t2,\n\t3,\n] as Array[int]\n"), set())
		self.assertEqual(self.rules(
			'var values = {\n\t"one": 1,\n\t"two": 2,\n\t"three": 3,\n} as Dictionary[String, int]\n'
		), set())

	def test_cast_suffix_does_not_allow_call_targets_nested_types_or_extra_statements(self) -> None:
		for suffix in ("RefCounted()", "Error other()", "Array[Array[int]]",
			"Dictionary[String, Array[int]]", "Array[int, int]", "Dictionary[String]",
			"Dictionary[String, int] unrelated = 1", "Type[Node]", "void"):
			with self.subTest(suffix=suffix):
				self.assertIn("closing_delimiter", self.rules("make(\n\ta,\n\tb\n) as " + suffix + "\n"))
		self.assertEqual(self.rules("make(\n\ta,\n\tb,\n\tc\n) as RefCounted\nother()\n"), set())

	def test_detached_cast_suffix_and_excess_whole_value_groups_are_rejected(self) -> None:
		source = "var error = (\n\t(make(\n\t\ta,\n\t\tb\n\t)\n\t)\n\tas Error\n)\n"
		self.assertIn("cast_layout", self.rules(source))
		view = readability.lex_source("addons/gf/x.gd", source)
		span = readability.cast_layout_spans(view)[0]
		self.assertEqual(len(span.redundant_operand_group_open_indexes), 1)
		self.assertEqual(len(span.redundant_cast_group_open_indexes), 1)
		self.assertTrue(span.attachment_allowed)
		self.assertEqual(source[span.start:span.end], source[source.index("("):source.rindex(")") + 1])
		self.assertIn("cast_layout", self.rules("var error = ((items.resize(LIMIT)) as Error)\n"))

	def test_whole_assignment_return_and_argument_cast_groups_share_the_narrow_owner_boundary(self) -> None:
		for source in (
			"var value = ((make(a, b)) as RefCounted)\n",
			"const VALUE = ((make(a, b)) as RefCounted)\n",
			"value = ((make(a, b)) as RefCounted)\n",
			"return ((make(a, b)) as RefCounted)\n",
			"consume(((make(a, b)) as RefCounted), other)\n",
		):
			with self.subTest(source=source):
				self.assertIn("cast_layout", self.rules(source))
				span = readability.cast_layout_spans(readability.lex_source("addons/gf/x.gd", source))[0]
				self.assertEqual(len(span.redundant_cast_group_open_indexes), 1)

	def test_cast_needed_precedence_receiver_and_complex_operand_groups_are_preserved(self) -> None:
		for source in (
			"var value = (make(a, b) as RefCounted) + other\n",
			"return (make(a, b) as RefCounted).member\n",
			"var value = ((left + right) as RefCounted)\n",
			"var value = ((left if ready else right) as RefCounted)\n",
			"var value = (factory().make(a, b) as RefCounted)\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("cast_layout", self.rules(source))
				for span in readability.cast_layout_spans(readability.lex_source("addons/gf/x.gd", source)):
					self.assertEqual(span.redundant_cast_group_open_indexes, ())
					self.assertEqual(span.redundant_operand_group_open_indexes, ())

	def test_cast_comments_continuations_and_multiline_literal_payloads_block_group_removal(self) -> None:
		for source in (
			"var value = (\n\t# retain context\n\tmake(a, b) as RefCounted\n)\n",
			"var value = (\n\tmake(a, b) # retain close context\n\tas RefCounted\n)\n",
			"var value = (\n\tmake(a, b) \\\n\tas RefCounted\n)\n",
			'var value = (\n\tmake("""first\nsecond""", other) as RefCounted\n)\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("cast_layout", self.rules(source))
				spans = readability.cast_layout_spans(readability.lex_source("addons/gf/x.gd", source))
				if " \\\n" in source:
					self.assertEqual(spans, ())
				else:
					self.assertEqual(len(spans), 1)
					self.assertEqual(spans[0].redundant_cast_group_open_indexes, ())
					self.assertEqual(spans[0].redundant_operand_group_open_indexes, ())

	def test_cast_default_parameter_groups_are_outside_complete_value_scope(self) -> None:
		source = 'func f(value = ((preload("x")) as Script)) -> void:\n\tpass\n'
		self.assertNotIn("cast_layout", self.rules(source))
		span = readability.cast_layout_spans(readability.lex_source("addons/gf/x.gd", source))[0]
		self.assertEqual(span.redundant_operand_group_open_indexes, ())
		self.assertEqual(span.redundant_cast_group_open_indexes, ())

	def test_cast_receiver_groups_keep_both_call_and_cast_layers(self) -> None:
		source = "return ((make(a, b)) as RefCounted).member\n"
		self.assertNotIn("cast_layout", self.rules(source))
		span = readability.cast_layout_spans(readability.lex_source("addons/gf/x.gd", source))[0]
		self.assertEqual(span.redundant_operand_group_open_indexes, ())
		self.assertEqual(span.redundant_cast_group_open_indexes, ())

	def test_cast_operator_operand_groups_keep_both_call_and_cast_layers(self) -> None:
		source = "var value = ((make(a, b)) as RefCounted) + other\n"
		self.assertNotIn("cast_layout", self.rules(source))
		span = readability.cast_layout_spans(readability.lex_source("addons/gf/x.gd", source))[0]
		self.assertEqual(span.redundant_operand_group_open_indexes, ())
		self.assertEqual(span.redundant_cast_group_open_indexes, ())

	def test_cast_partial_argument_groups_are_outside_complete_item_scope(self) -> None:
		source = "consume((make(a, b)) as RefCounted + other)\n"
		self.assertNotIn("cast_layout", self.rules(source))
		span = readability.cast_layout_spans(readability.lex_source("addons/gf/x.gd", source))[0]
		self.assertEqual(span.redundant_operand_group_open_indexes, ())
		self.assertEqual(span.redundant_cast_group_open_indexes, ())

	def test_lambda_cast_keeps_group_context_and_required_body_comma(self) -> None:
		source = "var error = (\n\tchanged.connect(\n\t\tfunc() -> void:\n\t\t\trecord(),\n\t) as Error\n)\n"
		self.assertEqual(self.rules(source), set())
		span = readability.cast_layout_spans(readability.lex_source("addons/gf/x.gd", source))[0]
		self.assertEqual(span.redundant_cast_group_open_indexes, ())
		self.assertEqual(span.redundant_operand_group_open_indexes, ())
		self.assertIn("lambda_argument_separator", self.rules(source.replace("record(),", "record()")))

	def test_cast_words_in_comments_literals_and_unrelated_statements_are_not_candidates(self) -> None:
		source = 'var text = "(call()) as RefCounted" # (call()) as RefCounted\nvar ready = true\n'
		self.assertEqual(readability.cast_layout_spans(readability.lex_source("addons/gf/x.gd", source)), ())
		self.assertEqual(self.rules(source), set())

	def test_many_cast_arguments_use_complete_items_without_swallowing_neighbors(self) -> None:
		source = "consume(" + ",".join("(make(a, b) as RefCounted)" for _ in range(400)) + ")\n"
		spans = readability.cast_layout_spans(readability.lex_source("addons/gf/x.gd", source))
		self.assertEqual(len(spans), 400)
		self.assertTrue(all(len(span.redundant_cast_group_open_indexes) == 1 for span in spans))

	def test_atomic_groups_use_one_line_independently_of_literal_length(self) -> None:
		for length in (1, 120, 121, 5_000):
			literal = '"res://' + "x" * length + '.json"'
			with self.subTest(length=length):
				self.assertIn("atomic_group_layout", self.rules("const PATH: String = (\n\t" + literal + "\n)\n"))
				self.assertEqual(self.rules("const PATH: String = (" + literal + ")\n"), set())
				self.assertEqual(self.rules("const PATH: String = " + literal + "\n"), set())

	def test_atomic_groups_share_the_call_atom_contract_in_all_expression_contexts(self) -> None:
		for atom in ('"text"', '&"key"', 'r"path"', 'null', '42', 'root.member',
			'[]', '{}', '-value', '!ready', 'not ready', '((value))'):
			for source in (
				'var value = (\n\t' + atom + '\n)\n',
				'func run() -> Variant:\n\treturn (\n\t\t' + atom + '\n\t)\n',
				'if (\n\t' + atom + '\n):\n\tpass\n',
			):
				with self.subTest(atom=atom, source=source):
					self.assertIn("atomic_group_layout", self.rules(source))

	def test_atomic_groups_preserve_comments_continuations_and_multiline_literals(self) -> None:
		for source in (
			'var value = (\n\t# context\n\t"text"\n)\n',
			'var value = (\n\t"text" # context\n)\n',
			'var value = (\\\n\t"text"\n)\n',
			'var value = (\n\t"""first\nsecond"""\n)\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("atomic_group_layout", self.rules(source))

	def test_single_item_complex_groups_and_parameter_headers_are_not_atoms(self) -> None:
		for expression in ('a + b', 'a and b', 'a and b or c', 'items[index]',
			'child(value)', 'value as Resource', 'a if ready else b', '-not ready',
			'[1]', '{ "a": 1 }', 'value,'):
			with self.subTest(expression=expression):
				self.assertNotIn("atomic_group_layout", self.rules('var value = (\n\t' + expression + '\n)\n'))
		for source in ('func run(\n\tvalue\n) -> void:\n\tpass\n',
			'signal changed(\n\tvalue\n)\n', 'func(\n\tvalue\n):\n\tpass\n'):
			self.assertNotIn("atomic_group_layout", self.rules(source))

	def test_atomic_group_spans_keep_nested_parentheses_and_exact_offsets(self) -> None:
		source = 'var value = (\n\t(\n\t\troot.member\n\t)\n)\n'
		view = readability.lex_source("addons/gf/x.gd", source)
		spans = readability.atomic_group_layout_spans(view)
		self.assertEqual(len(spans), 2)
		self.assertEqual(source[spans[0].start:spans[0].end], source[source.index('('):source.rindex(')') + 1])
		self.assertEqual([token.value for token in view.tokens[spans[0].open_index:spans[0].close_index + 1]],
			['(', '(', 'root', '.', 'member', ')', ')'])
		self.assertIn("simple_call_layout", self.rules('call(\n\t(\n\t\tvalue\n\t)\n)\n'))
		self.assertIn("atomic_group_layout", self.rules('call(\n\t(\n\t\tvalue\n\t)\n)\n'))

	def test_simple_calls_cover_atoms_grouping_unary_and_empty_containers(self) -> None:
		for argument in ('', 'true', 'null', '2.5', '"# ; ()"', '&"key"', 'r"path"',
			'root.member', '[]', '{}', '-value', '~value', 'not ready', '!ready', '(value)', '((not (ready)))'):
			with self.subTest(argument=argument):
				self.assertNotIn("simple_call_layout", self.rules("call(" + argument + ")\n"))
				self.assertIn("simple_call_layout", self.rules("call(\n\t" + argument + "\n)\n"))

	def test_simple_member_callee_continuations_use_the_complete_call_span(self) -> None:
		source = 'var value = (\n\tRoot\n\t.method(\n\t\tmember\n\t)\n)\n'
		self.assertIn("simple_call_layout", self.rules(source))
		view = readability.lex_source("addons/gf/x.gd", source)
		spans = readability.simple_call_layout_spans(view)
		self.assertEqual(len(spans), 1)
		span = spans[0]
		self.assertTrue(source[span.start:span.end].startswith("Root\n"))
		self.assertEqual([token.value for token in view.tokens[span.callee_start_index:span.callee_end_index]],
			["Root", ".", "method"])

	def test_simple_call_layout_preserves_comment_continuation_and_literal_boundaries(self) -> None:
		for source in (
			'call(\n\t# context\n\tvalue\n)\n',
			'call(\n\tvalue # context\n)\n',
			'call(\\\n\tvalue\n)\n',
			'call(\n\t"""first\nsecond"""\n)\n',
			'var value = (\n\tRoot # context\n\t.method(\n\t\tmember\n\t)\n)\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("simple_call_layout", self.rules(source))

	def test_complex_calls_and_receivers_keep_their_structural_layout(self) -> None:
		for source in (
			'call(\n\ta,\n\tb\n)\n',
			'call(\n\ta + b\n)\n',
			'call(\n\titems[index]\n)\n',
			'call(\n\tchild(value)\n)\n',
			'call(\n\ta if ready else b\n)\n',
			'call(\n\tvalue as Resource\n)\n',
			'call(\n\t[1]\n)\n',
			'call(\n\t{ "a": 1 }\n)\n',
			'call(\n\tfunc() -> void:\n\t\trecord()\n)\n',
			'factory().method(\n\tvalue\n)\n',
			'callbacks[index](\n\tvalue\n)\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("simple_call_layout", self.rules(source))

	def test_simple_call_layout_keeps_explicit_argument_commas_and_template_offsets(self) -> None:
		for source in ('call(value,)\n', 'call(\n\tvalue,\n)\n'):
			view = readability.lex_source("addons/gf/x.gd", source)
			self.assertEqual(len(readability.simple_call_layout_spans(view)), 1)
		self.assertEqual(self.rules('var value = load({DatabasePath})\n',
			"addons/gf/tools/config_pipeline/templates/read_config.gd.txt"), set())
		self.assertIn("simple_call_layout", self.rules('var value = load(\n\t{DatabasePath}\n)\n',
			"addons/gf/tools/config_pipeline/templates/read_config.gd.txt"))

	def test_long_literals_still_require_structurally_complex_containers_to_expand(self) -> None:
		literal = '"' + "x" * 5_000 + '"'
		self.assertNotIn("dictionary_layout", self.rules('var value = { "a": ' + literal + ', "b": 2 }\n'))
		self.assertIn("dictionary_layout", self.rules('var value = { "a": ' + literal + ', "b": 2, "c": 3 }\n'))
		self.assertIn("dictionary_layout", self.rules('var value = { "a": [' + literal + '] }\n'))

	def test_bom_crlf_spaces_and_final_newline(self) -> None:
		for source in ("\ufeffvar x = 1\n", "var x = 1\r\n", "  var x = 1\n", "var x = 1"):
			with self.subTest(source=source):
				self.assertIn("text_format", self.rules(source))

	def test_controlled_template_placeholders_keep_line_positions(self) -> None:
		path = "addons/gf/tools/config_pipeline/templates/read_config.gd.txt"
		source = "var value = load({DatabasePath})\nvar table = StringName({TableName})\n"
		self.assertEqual(self.rules(source, path), set())
		native = "class_name {ClassName}\nextends {BaseClass}\n"
		native_path = "addons/gf/standard/state_machine/node/editor/templates/node_state.gdtemplate"
		self.assertEqual(self.rules(native, native_path), set())
		self.assertIn("template_contract", self.rules(native, "addons/gf/x.gdtemplate"))
		self.assertIn("template_contract", self.rules("var x = {UnknownValue}\n", path))

	def test_owned_templates_are_checked_not_skipped(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "addons/gf").mkdir(parents=True)
			(root / "tests/gf_core").mkdir(parents=True)
			(root / "addons/gf/x.gd.txt").write_bytes(b"if ready: run()\n")
			report = readability.audit_repository(root)
			self.assertFalse(report["ok"])
			self.assertTrue(report["complete"])
			self.assertEqual(report["scanned_file_count"], 1)
			self.assertEqual(report["issues"][0]["rule"], "inline_body")

	def test_read_failures_and_limits_are_not_clean(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "addons/gf").mkdir(parents=True)
			(root / "tests/gf_core").mkdir(parents=True)
			(root / "addons/gf/x.gd").write_bytes(b"var x = 1\n")
			def fail(_path: Path) -> str:
				raise OSError("fixture")
			report = readability.audit_repository(root, read_text=fail)
			self.assertFalse(report["complete"])
			self.assertFalse(report["ok"])
			with patch.object(readability, "MAX_SOURCE_BYTES", 3):
				report = readability.audit_repository(root)
			self.assertFalse(report["complete"])

	def test_reader_cannot_hide_actual_crlf(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "addons/gf").mkdir(parents=True)
			(root / "tests/gf_core").mkdir(parents=True)
			(root / "addons/gf/x.gd").write_bytes(b"var x = 1\r\n")
			report = readability.audit_repository(root, read_text=lambda path: path.read_text(encoding="utf-8"))
			self.assertFalse(report["ok"])
			self.assertIn("text_format", {issue["rule"] for issue in report["issues"]})

	def test_boolean_three_terms_expand_in_each_control_header(self) -> None:
		for header in ("if", "elif", "while"):
			leading = "if fallback:\n\tpass\n" if header == "elif" else ""
			for operator in ("and", "or"):
				with self.subTest(header=header, operator=operator):
					bad = leading + f"{header} a {operator} b {operator} c:\n\tpass\n"
					clean = leading + f"{header} (\n\ta\n\t{operator} b\n\t{operator} c\n):\n\tpass\n"
					self.assertIn("condition_layout", self.rules(bad))
					self.assertEqual(self.rules(clean), set())
					self.assertEqual(self.rules(leading + f"{header} a {operator} b:\n\tpass\n"), set())

	def test_boolean_assignment_and_return_share_the_control_header_layout(self) -> None:
		for prefix in (
			"var ready: bool = ", "var ready = ", "var ready := ", "ready = ",
			"state.ready = ", 'state["ready"] = ', "return ",
			"ready += ", "state.ready |= ", 'state["ready"] &= ', "",
		):
			for operator in ("and", "or"):
				with self.subTest(prefix=prefix, operator=operator):
					self.assertIn("condition_layout", self.rules(prefix + f"a {operator} b {operator} c\n"))
					clean = prefix + f"(\n\ta\n\t{operator} b\n\t{operator} c\n)\n"
					self.assertEqual(self.rules(clean), set())
					self.assertEqual(self.rules(prefix + f"a {operator} b\n"), set())

	def test_boolean_existing_groups_cannot_hide_three_terms(self) -> None:
		for prefix, suffix in (("if ", ":\n\tpass\n"), ("var ready = ", "\n"), ("return ", "\n")):
			for expression in ("(a or b or c)", "((a and b and c))", "not (a or b or c)"):
				with self.subTest(prefix=prefix, expression=expression):
					self.assertIn("condition_layout", self.rules(prefix + expression + suffix))
		clean = "return not (\n\ta\n\tor b\n\tor c\n)\n"
		self.assertEqual(self.rules(clean), set())
		self.assertIn("condition_layout", self.rules("consume((a or b or c))\n"))
		clean_argument = "consume(\n\t(\n\t\ta\n\t\tor b\n\t\tor c\n\t)\n)\n"
		self.assertEqual(self.rules(clean_argument), set())
		for ordinary_group in (
			"consume(\n\t(\n\t\ta and b\n\t)\n)\n",
			"consume(\n\t(\n\t\tpredicate(\n\t\t\ta\n\t\t\tand b\n\t\t\tand c\n\t\t)\n\t)\n)\n",
			"consume(\n\t(\n\t\t[\n\t\t\ta\n\t\t\tand b\n\t\t\tand c,\n\t\t]\n\t)\n)\n",
		):
			with self.subTest(ordinary_group=ordinary_group):
				self.assertIn("argument_group_layout", self.rules(ordinary_group))
				self.assertNotIn("condition_layout", self.rules(ordinary_group))

	def test_boolean_required_host_keeps_the_inner_or_layer(self) -> None:
		clean = (
			"if (\n\trequired_host\n\tand (\n"
			"\t\ta\n\t\tor b\n\t\tor c\n\t)\n):\n\tpass\n"
		)
		self.assertEqual(self.rules(clean), set())
		self.assertIn("condition_layout", self.rules(clean.replace("\t\ta\n\t\tor b\n\t\tor c", "\t\ta or b or c")))
		self.assertIn("condition_layout", self.rules("if required_host and (a or b or c):\n\tpass\n"))

	def test_boolean_mixed_operators_keep_native_precedence_and_existing_groups(self) -> None:
		for expression, expanded in (
			("a or b and c", "(\n\ta\n\tor b\n\tand c\n)"),
			("a and b or c", "(\n\ta\n\tand b\n\tor c\n)"),
			("a and (b or c)", "(\n\ta\n\tand (\n\t\tb\n\t\tor c\n\t)\n)"),
			("not a and b and c", "(\n\tnot a\n\tand b\n\tand c\n)"),
		):
			with self.subTest(expression=expression):
				self.assertIn("condition_layout", self.rules("return " + expression + "\n"))
				self.assertEqual(self.rules("return " + expanded + "\n"), set())

	def test_boolean_call_and_container_items_are_independent_complete_domains(self) -> None:
		for source, clean in (
			("consume(a and b and c, other)\n", "consume(\n\ta\n\tand b\n\tand c,\n\tother\n)\n"),
			("var flags = [a or b or c, other]\n", "var flags = [\n\ta\n\tor b\n\tor c,\n\tother,\n]\n"),
			('var flags = { "ready": a and b and c }\n', 'var flags = {\n\t"ready": (\n\t\ta\n\t\tand b\n\t\tand c\n\t),\n}\n'),
			('var flags = { a or b or c: "ready" }\n', 'var flags = {\n\t(\n\t\ta\n\t\tor b\n\t\tor c\n\t): "ready",\n}\n'),
			("func run(ready: bool = a or b or c) -> void:\n\tpass\n", "func run(\n\tready: bool = (\n\t\ta\n\t\tor b\n\t\tor c\n\t)\n) -> void:\n\tpass\n"),
			("var value = items[a and b and c]\n", "var value = items[\n\ta\n\tand b\n\tand c\n]\n"),
		):
			with self.subTest(source=source):
				self.assertIn("condition_layout", self.rules(source))
				self.assertEqual(self.rules(clean), set())

	def test_boolean_calls_and_containers_do_not_add_terms_to_their_parent(self) -> None:
		for source in (
			"if predicate(a and b) and ready:\n\tpass\n",
			"return predicate(a or b) and ready\n",
			"var flags = [a and b, c or d]\n",
			'var flags = { "left": a and b, "right": c or d }\n',
			"consume(\n\ta and b,\n\tc or d\n)\n",
			"func run(left = a and b, right = c or d) -> void:\n\tpass\n",
		):
			with self.subTest(source=source):
				self.assertEqual(self.rules(source), set())

	def test_boolean_ternary_branches_do_not_combine_their_term_counts(self) -> None:
		for prefix in ("return ", "var result = "):
			self.assertEqual(self.rules(prefix + "a and b if c or d else e and f\n"), set())
		for expression in (
			"a and b and c if ready else other",
			"left if a or b or c else right",
			"left if ready else a and b and c",
		):
			with self.subTest(expression=expression):
				self.assertIn("condition_layout", self.rules("return " + expression + "\n"))
		clean = (
			"return (\n\ta\n\tand b\n\tand c\n) if ready else other\n"
		)
		self.assertEqual(self.rules(clean), set())

	def test_boolean_lambda_body_statements_keep_their_own_scopes(self) -> None:
		source = (
			"changed.connect(\n\tfunc check(value: bool = a and b) -> bool:\n"
			"\t\tvar ready = a and b and c\n"
			"\t\tif a or b or c:\n\t\t\trecord()\n"
			"\t\treturn a and b and c\n)\n"
			"var following = a and b\n"
		)
		issues = readability.audit_source("addons/gf/fixture.gd", source)
		self.assertEqual([issue["line"] for issue in issues if issue["rule"] == "condition_layout"], [3, 4, 6])
		clean = (
			"changed.connect(\n\tfunc check(value: bool = a and b) -> bool:\n"
			"\t\tvar ready = (\n\t\t\ta\n\t\t\tand b\n\t\t\tand c\n\t\t)\n"
			"\t\tif (\n\t\t\ta\n\t\t\tor b\n\t\t\tor c\n\t\t):\n\t\t\trecord()\n"
			"\t\treturn (\n\t\t\ta\n\t\t\tand b\n\t\t\tand c\n\t\t)\n)\n"
			"var following = a and b\n"
		)
		self.assertEqual(self.rules(clean), set())

	def test_boolean_literals_and_comments_do_not_supply_terms(self) -> None:
		for source in (
			'var text = "a and b and c or d" # e and f and g\n',
			'var text = """\na and b and c\nor d\n"""\n',
			'if ready and "and or && ||" == text:\n\tpass\n',
			'var ready = a and b # and c or d\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("condition_layout", self.rules(source))
		clean = "return (\n\ta # first condition\n\tand b\n\tand c # last condition\n)\n"
		self.assertEqual(self.rules(clean), set())
		self.assertIn("condition_layout", self.rules("var ready = a and b and c # fourth and fifth\n"))

	def test_boolean_expansion_keeps_continuation_and_closing_gates(self) -> None:
		for prefix, suffix in (("if ", ":\n\tpass\n"), ("var ready = ", "\n"), ("return ", "\n")):
			with self.subTest(prefix=prefix):
				self.assertIn("continuation_indentation", self.rules(prefix + "(\na\nand b\nand c\n)" + suffix))
				self.assertIn("closing_delimiter", self.rules(prefix + "(\n\ta\n\tand b\n\tand c)" + suffix))
		self.assertIn("condition_layout", self.rules("return a and b \\\n\tand c\n"))
		self.assertEqual(self.rules("return a \\\n\tand b\n"), set())
		self.assertIn("closing_delimiter", self.rules("var value = items[\n\ta\n\tand b\n\tand c]\n"))
		self.assertIn("continuation_indentation", self.rules("var value = items[\na\nand b\nand c\n]\n"))
		self.assertIn("continuation_indentation", self.rules("var value = items[\n\ta\n\tand b\n\tand c\n\t]\n"))

	def test_boolean_node_path_and_member_keywords_are_names(self) -> None:
		for expression in (
			"$Node/or/and/Child", "%Unique/or/and", "state.and", "state.or",
			"state.and(ready)", "state.or(ready)",
			"$Node / or / and", "%Unique / or / and",
		):
			for prefix, suffix in (("if ", ":\n\tpass\n"), ("var value = ", "\n"), ("return ", "\n")):
				with self.subTest(expression=expression, prefix=prefix):
					self.assertNotIn("condition_layout", self.rules(prefix + expression + suffix))
					self.assertNotIn("condition_layout", self.rules(prefix + expression + " and ready" + suffix))
		self.assertIn("condition_layout", self.rules("return $Node/or/and/Child and state.or and active\n"))
		for callee in ("state.func", "$Node.func", "%Unique.func"):
			with self.subTest(callee=callee):
				self.assertIn("condition_layout", self.rules(f"return {callee}(a or b or c)\n"))
				self.assertEqual(self.rules(f"return {callee}(\n\ta\n\tor b\n\tor c\n)\n"), set())
				self.assertEqual(self.rules(f"return {callee}(a or b)\n"), set())
		for receiver in ("state.and", "state.or", "state.if", "$and", "%or"):
			with self.subTest(receiver=receiver):
				source = f"return {receiver}[a or b or c]\n"
				self.assertIn("condition_layout", self.rules(source))
				spans = readability.boolean_layout_spans(readability.lex_source("addons/gf/fixture.gd", source))
				self.assertEqual(len(spans), 1)
				self.assertEqual(spans[0].context, "index_item")
				clean = f"return {receiver}[\n\ta\n\tor b\n\tor c\n]\n"
				self.assertEqual(self.rules(clean), set())
				self.assertNotIn("trailing_comma", self.rules(clean))
				self.assertEqual(self.rules(f"return {receiver}[a or b]\n"), set())
		for receiver in ("state.and", "state.or", "state.if", "$and", "%or"):
			with self.subTest(grouped_index_receiver=receiver):
				grouped = f"return {receiver}[\n\t(\n\t\ta\n\t\tor b\n\t\tor c\n\t)\n]\n"
				self.assertEqual(self.rules(grouped), set())
		for actual_array in (
			"return [\n\t(\n\t\ta\n\t\tor b\n\t\tor c\n\t)\n]\n",
			"return [\n\tpredicate(\n\t\ta\n\t\tor b\n\t\tor c\n\t)\n]\n",
		):
			with self.subTest(actual_array=actual_array):
				self.assertIn("trailing_comma", self.rules(actual_array))
				self.assertEqual(self.rules(actual_array.replace("\t)\n]", "\t),\n]")), set())
		for host in ("state.func", "$Node.func", "%Unique.func"):
			for signature in ("func() -> void:", "func inspect(value: bool = a or b) -> void:"):
				for previous in ("", "consume()", "var previous = ready", "var previous = ready()", 'var previous = "ready"'):
					prefix = f"{host}(\n\t{signature}\n" + (f"\t\t{previous}\n" if previous else "")
					for node_path in ("%or/and/Child", "%Unique/or/and/Child"):
						with self.subTest(host=host, signature=signature, previous=previous, node_path=node_path):
							source = prefix + f"\t\t{node_path}.activate()\n)\n"
							self.assertEqual(self.rules(source), set())
							self.assertEqual(readability.boolean_layout_spans(readability.lex_source("addons/gf/fixture.gd", source)), ())
					with self.subTest(host=host, signature=signature, previous=previous, body_index=True):
						source = prefix + "\t\t%or[a or b or c]\n)\n"
						self.assertIn("condition_layout", self.rules(source))
						spans = readability.boolean_layout_spans(readability.lex_source("addons/gf/fixture.gd", source))
						self.assertEqual(len(spans), 1)
						self.assertEqual(spans[0].context, "index_item")
						self.assertEqual(spans[0].term_count, 3)
						clean = prefix + "\t\t%or[\n\t\t\ta\n\t\t\tor b\n\t\t\tor c\n\t\t]\n)\n"
						self.assertEqual(self.rules(clean), set())
			for signature in ("func() -> void:", "func inspect() -> void:"):
				with self.subTest(host=host, signature=signature, nested_body=True):
					source = (
						f"{host}(\n\t{signature}\n"
						"\t\tvar child = func child_debug(value: bool = a or b) -> void:\n"
						"\t\t\tconsume()\n\t\t\t%or/and/Child.activate()\n"
						"\t\t%Unique/or/and/Child.activate()\n)\nvar following = a or b\n"
					)
					self.assertEqual(self.rules(source), set())
					self.assertEqual(readability.boolean_layout_spans(readability.lex_source("addons/gf/fixture.gd", source)), ())
		for receiver in ("map", "state.and", "$and", "%or"):
			for signature in ("func() -> bool:", "func compute(value: bool = a or b) -> bool:"):
				with self.subTest(receiver=receiver, signature=signature, index_lambda=True):
					source = f"var callback = {receiver}[\n\t{signature}\n\t\tvar ready = a and b and c\n\t\treturn a or b or c\n]\n"
					spans = readability.boolean_layout_spans(readability.lex_source("addons/gf/fixture.gd", source))
					self.assertEqual(len(spans), 2)
					self.assertEqual([source[span.start:span.end] for span in spans], ["a and b and c", "a or b or c"])
					self.assertTrue(all(span.needs_outer_group and span.carrier_open_index is None for span in spans))
					clean = (
						f"var callback = {receiver}[\n\t{signature}\n"
						"\t\tvar ready = (\n\t\t\ta\n\t\t\tand b\n\t\t\tand c\n\t\t)\n"
						"\t\treturn (\n\t\t\ta\n\t\t\tor b\n\t\t\tor c\n\t\t)\n]\n"
					)
					self.assertEqual(self.rules(clean), set())
		for formatted in (
			'\t\tvar formatted = ("outer=%s" % Node.func(a or b))\n',
			'\t\tvar formatted = "outer=%s" \\\n\t\t\t% Node.func(a or b)\n',
		):
			with self.subTest(binary_percent=formatted):
				source = "state.func(\n\tfunc() -> void:\n" + formatted + "\t\t%Unique/or/and/Child.activate()\n)\n"
				self.assertEqual(self.rules(source), set())
				self.assertEqual(readability.boolean_layout_spans(readability.lex_source("addons/gf/fixture.gd", source)), ())
		actual_array = "var callbacks = [\n\tfunc() -> bool:\n\t\treturn (\n\t\t\ta\n\t\t\tor b\n\t\t\tor c\n\t\t)\n]\n"
		self.assertIn("trailing_comma", self.rules(actual_array))
		self.assertEqual(self.rules(actual_array.replace("\t\t)\n]", "\t\t),\n]")), set())

	def test_boolean_match_subject_and_when_guard_are_independent_domains(self) -> None:
		self.assertIn("condition_layout", self.rules("match a and b and c:\n\t_:\n\t\tpass\n"))
		self.assertEqual(self.rules("match (\n\ta\n\tand b\n\tand c\n):\n\t_:\n\t\tpass\n"), set())
		self.assertIn("condition_layout", self.rules("match value:\n\tvar item when a or b or c:\n\t\tpass\n"))
		self.assertEqual(self.rules("match value:\n\tvar item when (\n\t\ta\n\t\tor b\n\t\tor c\n\t):\n\t\tpass\n"), set())
		for source in (
			"match a and b:\n\tvar item when c or d:\n\t\tpass\n",
			"match state.or:\n\tvar item when $Node/or/and/Child and ready:\n\t\tpass\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("condition_layout", self.rules(source))

	def test_boolean_aliases_follow_the_same_three_term_boundary(self) -> None:
		for operator in ("&&", "||"):
			for prefix, suffix in (("if ", ":\n\tpass\n"), ("var ready = ", "\n"), ("return ", "\n")):
				with self.subTest(operator=operator, prefix=prefix):
					self.assertIn("condition_layout", self.rules(prefix + f"a {operator} b {operator} c" + suffix))
					self.assertEqual(self.rules(prefix + f"a {operator} b" + suffix), set())

	def test_boolean_layout_does_not_depend_on_leaf_length_or_type(self) -> None:
		long_name = "very_long_condition_" + "x" * 5_000
		for prefix, suffix in (("if ", ":\n\tpass\n"), ("var ready: Variant = ", "\n"), ("return ", "\n")):
			with self.subTest(prefix=prefix):
				self.assertEqual(self.rules(prefix + long_name + suffix), set())
				self.assertEqual(self.rules(prefix + long_name + " and other" + suffix), set())
				self.assertIn("condition_layout", self.rules(prefix + long_name + " and other and third" + suffix))
		self.assertIn("condition_layout", self.rules("return is_ready() and state.ready and values[index]\n"))

	def test_boolean_many_independent_siblings_are_not_one_large_chain(self) -> None:
		items = ",\n".join("\ta and b" for _ in range(600))
		self.assertNotIn("condition_layout", self.rules("consume(\n" + items + "\n)\n"))
		items = ",\n".join("\ta or b or c" for _ in range(200))
		issues = readability.audit_source("addons/gf/fixture.gd", "consume(\n" + items + "\n)\n")
		self.assertEqual(sum(issue["rule"] == "condition_layout" for issue in issues), 200)

	def test_boolean_public_spans_keep_expression_domains_and_source_offsets(self) -> None:
		span_reader = getattr(readability, "boolean_layout_spans", None)
		self.assertTrue(callable(span_reader), "Boolean layout must expose source spans for safe formatting.")
		for path, source, expression in (
			("addons/gf/fixture.gd", "return a and b and c if ready else other\n", "a and b and c"),
			("addons/gf/fixture.gd", "if predicate(a and b and c) and ready:\n\tpass\n", "a and b and c"),
			("addons/gf/fixture.gd", 'var flags = { "ready": a and b and c }\n', "a and b and c"),
			("addons/gf/fixture.gd", "return $Node/or/and/Child and state.or and active\n", "$Node/or/and/Child and state.or and active"),
			("addons/gf/tools/config_pipeline/templates/read_config.gd.txt", "var loaded = load({DatabasePath})\nreturn a and b and c\n", "a and b and c"),
		):
			with self.subTest(path=path, source=source):
				view = readability.lex_source(path, source)
				self.assertEqual(view.issues, ())
				spans = [span for span in span_reader(view) if span.term_count >= 3]
				self.assertEqual(len(spans), 1)
				span = spans[0]
				self.assertEqual(span.term_count, 3)
				self.assertEqual(source[span.start:span.end], expression)
				self.assertEqual([view.tokens[index].value for index in span.operator_indexes], ["and", "and"])

	def test_boolean_public_spans_distinguish_carriers_and_unsafe_physical_layout(self) -> None:
		span_reader = getattr(readability, "boolean_layout_spans", None)
		self.assertTrue(callable(span_reader), "Boolean layout must expose its formatting safety contract.")
		for source, needs_outer_group in (
			("consume(a and b and c)\n", False),
			("var ready = a and b and c\n", True),
			("changed.connect(\n\tfunc() -> bool:\n\t\treturn a and b and c\n)\n", True),
		):
			with self.subTest(source=source):
				view = readability.lex_source("addons/gf/fixture.gd", source)
				spans = span_reader(view)
				self.assertEqual(len(spans), 1)
				self.assertEqual(spans[0].needs_outer_group, needs_outer_group)
				self.assertTrue(spans[0].migration_safe)
				if needs_outer_group:
					self.assertIsNone(spans[0].carrier_open_index)
				else:
					self.assertEqual(view.tokens[spans[0].carrier_open_index].value, "(")
		for source, barrier in (
			("var ready = a and b and c # keep this note\n", "comment"),
			("return a and b \\\n\tand c\n", "explicit_continuation"),
			('return """first\nsecond""" == text and b and c\n', "multiline_literal"),
		):
			with self.subTest(barrier=barrier):
				spans = span_reader(readability.lex_source("addons/gf/fixture.gd", source))
				self.assertEqual(len(spans), 1)
				self.assertFalse(spans[0].migration_safe)
				self.assertIn(barrier, spans[0].barriers)

	def test_cli_json_and_exit_code(self) -> None:
		with tempfile.TemporaryDirectory() as directory:
			root = Path(directory)
			(root / "addons/gf").mkdir(parents=True)
			(root / "tests/gf_core").mkdir(parents=True)
			(root / "addons/gf/x.gd").write_bytes(b"if ready: run()\n")
			stream = io.StringIO()
			with redirect_stdout(stream):
				result = readability.main(["--root", str(root), "--json"])
			self.assertEqual(result, 1)
			report = json.loads(stream.getvalue())
			self.assertIn("policy_version", report)
			self.assertEqual(report["scope"], "owned_repository")

	def test_dictionary_entry_keeps_single_line_key_separator_and_value_start_together(self) -> None:
		for separator in (":", "="):
			for value in ("value", "build(value)", "[value]", '{ "inner": value }', "(a + b)"):
				key = '"key"' if separator == ":" else "key"
				with self.subTest(separator=separator, value=value):
					self.assertNotIn("dictionary_entry_layout", self.rules(f"var data = {{\n\t{key}{separator} {value},\n}}\n"))
					self.assertIn("dictionary_entry_layout", self.rules(f"var data = {{\n\t{key}{separator}\n\t{value},\n}}\n"))
					self.assertIn("dictionary_entry_layout", self.rules(f"var data = {{\n\t{key}\n\t{separator} {value},\n}}\n"))

	def test_dictionary_entry_nested_value_starts_on_key_line(self) -> None:
		for value in (
			"build(\n\t\tvalue,\n\t\tother,\n\t\tthird\n\t)",
			"[\n\t\tvalue,\n\t]",
			'{\n\t\t"inner": value,\n\t}',
			"(\n\t\ta\n\t\tand b\n\t\tand c\n\t)",
			"func() -> void:\n\t\trun()",
		):
			with self.subTest(value=value):
				self.assertNotIn("dictionary_entry_layout", self.rules('var data = {\n\t"key": ' + value + ",\n}\n"))
				self.assertIn("dictionary_entry_layout", self.rules('var data = {\n\t"key":\n\t' + value + ",\n}\n"))

	def test_dictionary_entry_finds_direct_separator_after_complex_keys(self) -> None:
		for key in (
			"choose(left, right)",
			"[left, right]",
			'{ "left": right }',
			"(left if ready else right)",
			'"contains: = , delimiters"',
		):
			with self.subTest(key=key):
				self.assertIn("dictionary_entry_layout", self.rules(f"var data = {{\n\t{key}:\n\tvalue,\n}}\n"))
				self.assertNotIn("dictionary_entry_layout", self.rules(f"var data = {{\n\t{key}: value,\n}}\n"))

	def test_dictionary_entry_does_not_confuse_lambda_body_colons_or_assignments(self) -> None:
		source = (
			'var data = {\n\t"callback": func() -> void:\n'
			"\t\tvar local = {\n\t\t\tchild = value,\n\t\t}\n"
			"\t\tif ready:\n\t\t\trun(local),\n\tother = value,\n}\n"
		)
		self.assertNotIn("dictionary_entry_layout", self.rules(source))
		self.assertIn("dictionary_entry_layout", self.rules(source.replace("child = value", "child =\n\t\t\tvalue")))
		self.assertIn("dictionary_entry_layout", self.rules(source.replace("other = value", "other =\n\tvalue")))

	def test_dictionary_entry_physical_barriers_preserve_key_and_value_boundaries(self) -> None:
		for source in (
			'var data = {\n\t"key": # value explanation\n\tvalue,\n}\n',
			'var data = {\n\t"key" # key explanation\n\t: value,\n}\n',
			'var data = {\n\t"key": \\\n\tvalue,\n}\n',
			'var data = {\n\t"""first\nsecond""":\n\tvalue,\n}\n',
			'var data = {\n\t"key":\n\t"""first\nsecond""",\n}\n',
			'var data = {\n\t(\n\t\ta\n\t\t+ b\n\t):\n\tvalue,\n}\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("dictionary_entry_layout", self.rules(source))
		self.assertIn("dictionary_entry_layout", self.rules('var data = {\n\t"key":\n\tbuild(\n\t\tvalue # argument explanation\n\t),\n}\n'))

	def test_dictionary_entry_layout_is_checked_inside_rendered_templates(self) -> None:
		path = "addons/gf/tools/config_pipeline/templates/read_config.gd.txt"
		source = 'var data = {\n\t"path":\n\tload({DatabasePath}),\n}\n'
		self.assertIn("dictionary_entry_layout", self.rules(source, path))
		self.assertNotIn("dictionary_entry_layout", self.rules(source.replace('"path":\n\tload', '"path": load'), path))

	def test_two_atomic_call_arguments_use_single_line_argument_block(self) -> None:
		for first, second in (
			("left", "right"), ("owner.member", "other.value"),
			('"first"', '&"second"'), ("-1", "not enabled"),
			("[]", "{}"), ("(left)", "((right))"),
		):
			with self.subTest(first=first, second=second):
				self.assertNotIn("multi_argument_call_layout", self.rules(f"use({first}, {second})\n"))
				self.assertIn("multi_argument_call_layout", self.rules(f"use(\n\t{first},\n\t{second}\n)\n"))
				self.assertNotIn("multi_argument_call_layout", self.rules(f"use({first}, {second},)\n"))

	def test_two_argument_calls_expand_when_either_argument_is_nonatomic(self) -> None:
		for complex_argument in (
			"build(value)", "values[index]", "left + right", "left as Object",
			"left if ready else right", "await pending", "[value]", '{ "key": value }',
			"(left + right)", "--value",
		):
			for first, second in ((complex_argument, "other"), ("other", complex_argument)):
				with self.subTest(first=first, second=second):
					self.assertIn("multi_argument_call_layout", self.rules(f"use({first}, {second})\n"))
					self.assertNotIn("multi_argument_call_layout", self.rules(f"use(\n\t{first},\n\t{second}\n)\n"))

	def test_three_or_more_call_arguments_always_expand_by_count(self) -> None:
		for arguments in (("a", "b", "c"), ("a", "b", "c", "d")):
			with self.subTest(arguments=arguments):
				self.assertIn("multi_argument_call_layout", self.rules("use(" + ", ".join(arguments) + ")\n"))
				self.assertNotIn("multi_argument_call_layout", self.rules("use(\n\t" + ",\n\t".join(arguments) + "\n)\n"))

	def test_multi_argument_calls_count_direct_arguments_only(self) -> None:
		self.assertNotIn("multi_argument_call_layout", self.rules("outer(inner(a, b))\n"))
		self.assertIn("multi_argument_call_layout", self.rules("outer(inner(a, b), other)\n"))
		self.assertNotIn("multi_argument_call_layout", self.rules("outer(\n\tinner(a, b),\n\tother\n)\n"))
		self.assertNotIn("multi_argument_call_layout", self.rules('outer(\n\t[one, two],\n\t{ "key": value }\n)\n'))
		self.assertIn("multi_argument_call_layout", self.rules("outer(\n\tinner(a, b, c),\n\tother\n)\n"))

	def test_multi_argument_call_threshold_ignores_callee_and_argument_length(self) -> None:
		long_name = "member_" + "x" * 5_000
		for callee in ("run", "owner.member", f"owner.{long_name}"):
			for value in ("value", long_name, '"' + "x" * 5_000 + '"'):
				with self.subTest(callee=callee, value=value):
					self.assertNotIn("multi_argument_call_layout", self.rules(f"{callee}({value}, other)\n"))
					self.assertIn("multi_argument_call_layout", self.rules(f"{callee}(\n\t{value},\n\tother\n)\n"))
					self.assertIn("multi_argument_call_layout", self.rules(f"{callee}({value}, other, third)\n"))

	def test_multi_argument_call_applies_only_to_argument_block_of_complex_callee(self) -> None:
		for callee in ("factory()", "values[index]", "$Node.run", "%Unique.run", "state.func", "state.or"):
			with self.subTest(callee=callee):
				self.assertIn("multi_argument_call_layout", self.rules(f"{callee}(\n\tleft,\n\tright\n)\n"))
				self.assertNotIn("multi_argument_call_layout", self.rules(f"{callee}(left, right)\n"))
				self.assertIn("multi_argument_call_layout", self.rules(f"{callee}(left, right, third)\n"))
				self.assertNotIn("multi_argument_call_layout", self.rules(f"{callee}(\n\tleft,\n\tright,\n\tthird\n)\n"))
		self.assertNotIn("multi_argument_call_layout", self.rules("(\n\tleft\n\t+ right\n)(first, second)\n"))

	def test_multi_argument_call_preserves_physical_barriers_but_old_structure_gates_remain(self) -> None:
		for source in (
			"run(\n\tleft, # first\n\tright\n)\n",
			"run(left, \\\n\tright)\n",
			'run(\n\t"""first\nsecond""",\n\tright\n)\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("multi_argument_call_layout", self.rules(source))
		self.assertIn("closing_delimiter", self.rules("run(\n\tleft, # first\n\tright)\n"))
		self.assertIn("multiline_items", self.rules("run(\n\tleft, right # together\n)\n"))

	def test_multi_argument_call_does_not_expand_function_annotation_or_signal_parameters(self) -> None:
		for source in (
			"func run(left: int, right: int, third: int) -> void:\n\tpass\n",
			"signal changed(left: int, right: int, third: int)\n",
			'@export_range(0, 10, 1)\nvar amount: int\n',
			"var callback = func(left: int, right: int, third: int) -> void:\n\tpass\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("multi_argument_call_layout", self.rules(source))

	def test_multi_argument_calls_inside_lambda_bodies_use_their_own_scopes(self) -> None:
		for signature in ("func() -> void:", "func inspect(left: int, right: int) -> void:"):
			prefix = "changed.connect(\n\t" + signature + "\n"
			with self.subTest(signature=signature):
				self.assertIn("multi_argument_call_layout", self.rules(prefix + "\t\trun(left, right, third)\n)\n"))
				self.assertIn("multi_argument_call_layout", self.rules(prefix + "\t\trun(\n\t\t\tleft,\n\t\t\tright\n\t\t)\n)\n"))
				self.assertNotIn("multi_argument_call_layout", self.rules(prefix + "\t\trun(left, right)\n)\n"))
				self.assertNotIn("multi_argument_call_layout", self.rules(prefix + "\t\trun(\n\t\t\tleft,\n\t\t\tright,\n\t\t\tthird\n\t\t)\n)\n"))

	def test_multi_argument_call_handles_lambda_argument_without_counting_body_commas(self) -> None:
		source = (
			"run(\n\tcontext,\n\tfunc(left: int, right: int) -> void:\n"
			"\t\tvar values = [left, right]\n\t\tconsume(left, right)\n)\n"
		)
		self.assertNotIn("multi_argument_call_layout", self.rules(source))
		self.assertIn("multi_argument_call_layout", self.rules(source.replace("consume(left, right)", "consume(left, right, third)")))

	def test_multi_argument_call_checks_rendered_template_structure(self) -> None:
		path = "addons/gf/tools/config_pipeline/templates/read_config.gd.txt"
		self.assertIn("multi_argument_call_layout", self.rules("read({DatabasePath}, value, fallback)\n", path))
		self.assertNotIn("multi_argument_call_layout", self.rules("read(\n\t{DatabasePath},\n\tvalue,\n\tfallback\n)\n", path))

	def test_dictionary_entry_public_spans_end_at_value_start_without_flattening_children(self) -> None:
		source = 'var data = {\n\t"资源":\n\tbuild(\n\t\tvalue,\n\t\tother,\n\t\tthird\n\t),\n}\n'
		view = readability.lex_source("addons/gf/fixture.gd", source)
		spans = readability.dictionary_entry_layout_spans(view)
		self.assertEqual(len(spans), 1)
		span = spans[0]
		self.assertEqual(source[span.start:span.end], '"资源":\n\tbuild')
		self.assertEqual(view.tokens[span.separator_index].value, ":")
		self.assertEqual(view.tokens[span.value_start_index].value, "build")
		self.assertTrue(span.migration_safe)
		self.assertEqual(span.barriers, ())
		for replacement, barrier in (('"资源": # keep\n\tbuild', "comment"), ('"资源": \\\n\tbuild', "explicit_continuation")):
			with self.subTest(barrier=barrier):
				blocked = source.replace('"资源":\n\tbuild', replacement)
				span = readability.dictionary_entry_layout_spans(readability.lex_source("addons/gf/fixture.gd", blocked))[0]
				self.assertFalse(span.migration_safe)
				self.assertIn(barrier, span.barriers)

	def test_multi_argument_call_public_spans_preserve_receiver_and_direct_item_offsets(self) -> None:
		for arguments, expected in (("left, right", "inline"), ("left, right, third", "expanded"), ("left, build(right)", "expanded")):
			source = "values[index](" + arguments + ")\n"
			with self.subTest(arguments=arguments):
				view = readability.lex_source("addons/gf/fixture.gd", source)
				spans = readability.multi_argument_call_layout_spans(view)
				self.assertEqual(len(spans), 1)
				span = spans[0]
				self.assertEqual(source[span.start:span.end], "(" + arguments + ")")
				self.assertEqual(span.expected_layout, expected)
				self.assertEqual([source[view.tokens[start].start:view.tokens[end - 1].end] for start, end in span.items], arguments.split(", "))
				self.assertTrue(span.migration_safe)
				self.assertEqual(span.barriers, ())
		blocked = "values[index](\n\tleft, # keep\n\tright\n)\n"
		span = readability.multi_argument_call_layout_spans(readability.lex_source("addons/gf/fixture.gd", blocked))[0]
		self.assertFalse(span.migration_safe)
		self.assertIn("comment", span.barriers)

	def test_dictionary_and_call_layout_use_physical_lines_independently_of_line_endings(self) -> None:
		for newline in ("\n", "\r\n"):
			with self.subTest(newline=newline):
				self.assertIn("dictionary_entry_layout", self.rules('var data = {\n\t"key":\n\tvalue,\n}\n'.replace("\n", newline)))
				self.assertIn("multi_argument_call_layout", self.rules("run(\n\tleft,\n\tright\n)\n".replace("\n", newline)))
				self.assertEqual(self.rules('var data = {\n\t"key": run(\n\t\tleft,\n\t\tright,\n\t\tthird\n\t),\n}\n'.replace("\n", newline)) & {"dictionary_entry_layout", "multi_argument_call_layout"}, set())

	def test_expanded_call_closing_line_accepts_expression_operators_and_ternary_suffixes(self) -> None:
		call = "choose(\n\tleft,\n\tright,\n\tthird\n)"
		for source in (
			"if " + call + " != null:\n\tpass\n",
			"if " + call + " <= current_time:\n\tpass\n",
			"return " + call + " + other\n",
			"return " + call + " * scale\n",
			"return " + call + " and ready\n",
			"return " + call + " in values\n",
			"return " + call + " is Object\n",
			"return " + call + " as Object != null\n",
			"var selected = " + call + " if ready else fallback\n",
			"var selected = first if " + call + " else fallback\n",
			"var selected = first if ready else " + call + "\n",
		):
			with self.subTest(source=source):
				self.assertEqual(self.rules(source), set())

	def test_expanded_call_closing_line_accepts_member_index_and_call_postfixes(self) -> None:
		call = "choose(\n\tleft,\n\tright,\n\tthird\n)"
		for suffix in (".value", "[index]", "(left, right)", ".read(left, right)"):
			with self.subTest(suffix=suffix):
				self.assertEqual(self.rules("return " + call + suffix + "\n"), set())

	def test_expanded_call_expression_suffix_does_not_accept_unrelated_values_or_glued_parent_close(self) -> None:
		call = "choose(\n\tleft,\n\tright,\n\tthird\n)"
		for suffix in (" unrelated", " 42", ' "literal"', " return value"):
			with self.subTest(suffix=suffix):
				self.assertIn("closing_delimiter", self.rules("return " + call + suffix + "\n"))
		self.assertIn("closing_delimiter", self.rules("outer(\n\tchoose(\n\t\tleft,\n\t\tright,\n\t\tthird\n\t))\n"))

	def test_keyword_member_multi_argument_calls_keep_item_indentation_and_closing_gates(self) -> None:
		for callee in ("state.func", "state.or", "state.not"):
			with self.subTest(callee=callee):
				self.assertEqual(self.rules(f"{callee}(\n\tleft,\n\tright,\n\tthird\n)\n"), set())
				self.assertIn("continuation_indentation", self.rules(f"{callee}(\nleft,\nright,\nthird\n)\n"))
				self.assertIn("closing_delimiter", self.rules(f"{callee}(\n\tleft,\n\tright,\n\tthird)\n"))
				self.assertIn("continuation_indentation", self.rules(f"{callee}(\n\tleft,\n\tright,\n\tthird\n\t)\n"))

	def test_dictionary_key_and_value_ternaries_are_independent_domains(self) -> None:
		for source in (
			'var values = { "a" if first else "b": 1 if second else 2 }\n',
			'var values = { ("a" if first else "b"): (1 if second else 2) }\n',
		):
			with self.subTest(source=source):
				self.assertNotIn("nested_ternary", self.rules(source))

	def test_dictionary_key_or_value_actual_nested_ternary_is_still_checked(self) -> None:
		for source in (
			'var values = { "a" if first else "b" if second else "c": 1 }\n',
			'var values = { "a": 1 if first else 2 if second else 3 }\n',
		):
			with self.subTest(source=source):
				self.assertIn("nested_ternary", self.rules(source))

	def test_bitwise_compound_assignments_remain_single_tokens(self) -> None:
		source = 'mask |= bit\nmask &= ~bit\nmask ^= other\n'
		view = readability.lex_source("addons/gf/fixture.gd", source)
		self.assertEqual(view.issues, ())
		self.assertEqual([token.value for token in view.tokens if token.value.endswith("=")], ["|=", "&=", "^="])
		for token in view.tokens:
			self.assertEqual(source[token.start:token.end], token.value)


	def test_expanded_array_dictionary_and_index_values_accept_real_postfixes(self) -> None:
		values = (
			("[\n\tleft,\n\tright,\n\tthird,\n]", (".size()", "[index]", ".find(value)")),
			('{\n\t"left": left,\n\t"right": right,\n\t"third": third,\n}', (".size()", "[key]", ".get(key)")),
			("values[\n\tchoose(\n\t\tleft,\n\t\tright,\n\t\tthird\n\t)\n]", (".size()", "[index]")),
		)
		for value, suffixes in values:
			for suffix in suffixes:
				with self.subTest(value=value, suffix=suffix):
					self.assertEqual(self.rules("return " + value + suffix + "\n"), set())

	def test_expanded_array_find_chain_remains_an_independent_index_operand(self) -> None:
		source = 'return vector[\n\t[\n\t\t&"x",\n\t\t&"y",\n\t\t&"z",\n\t].find(component)\n]\n'
		self.assertEqual(self.rules(source), set())

	def test_expanded_value_postfixes_reject_unrelated_tokens_and_glued_closes(self) -> None:
		for value in ("[\n\tleft,\n\tright,\n\tthird,\n]", '{\n\t"left": left,\n\t"right": right,\n\t"third": third,\n}'):
			for suffix in (" unrelated", " 42", ' "literal"', " return value"):
				with self.subTest(value=value, suffix=suffix):
					self.assertIn("closing_delimiter", self.rules("return " + value + suffix + "\n"))
		for source, closing_line in (
			("outer(\n\t[\n\t\tleft,\n\t\tright,\n\t\tthird,\n\t])\n", 6),
			('outer(\n\t{\n\t\t"left": left,\n\t\t"right": right,\n\t\t"third": third,\n\t})\n', 6),
		):
			with self.subTest(source=source):
				issues = readability.audit_source("addons/gf/fixture.gd", source)
				self.assertIn(("closing_delimiter", closing_line, 2), {(issue["rule"], issue["line"], issue["column"]) for issue in issues})
	def test_conditional_keywords_in_member_and_node_names_are_not_ternaries(self) -> None:
		for source in (
			"return owner.if == other.if\n",
			"return $Parent/if == $Other/if\n",
			"return %Parent/if == %Other/if\n",
			"return owner.if if ready else other.if\n",
			"return $Parent/if if ready else $Other/if\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("nested_ternary", self.rules(source))

	def test_real_nested_ternaries_remain_checked_beside_keyword_names(self) -> None:
		for source in (
			"return owner.if if first else other.if if second else fallback\n",
			"return $Parent/if if first else $Other/if if second else fallback\n",
			"return owner.func.if if first else (other.if if second else fallback)\n",
			"return owner.else if first else other.if if second else fallback\n",
			"return owner.elif if first else other.if if second else fallback\n",
		):
			with self.subTest(source=source):
				self.assertIn("nested_ternary", self.rules(source))

	def test_dictionary_ternary_domains_exclude_keyword_names_without_merging_sides(self) -> None:
		for source in (
			"var values = { owner.if if first else other.if: left.if if second else right.if }\n",
			"var values = { $Parent/if if first else $Other/if: $Left/if if second else $Right/if }\n",
		):
			with self.subTest(source=source):
				self.assertNotIn("nested_ternary", self.rules(source))
		for source in (
			"var values = { owner.if if first else other.if if second else fallback: value }\n",
			"var values = { key: $Left/if if first else $Right/if if second else fallback }\n",
		):
			with self.subTest(source=source):
				self.assertIn("nested_ternary", self.rules(source))

	def test_keyword_names_do_not_split_real_nested_ternary_domains(self) -> None:
		for value in ("owner.func", "$Node/func", "owner.else", "owner.elif", "$Node/else"):
			source = "consume(\n\t" + value + " if first else\n\tother if second else fallback\n)\n"
			with self.subTest(source=source):
				self.assertIn("nested_ternary", self.rules(source))
	def test_shared_name_path_roles_preserve_the_name_wrapper_contract(self) -> None:
		source = "return owner.if == $Parent/and or %Unique/func\n"
		view = readability.lex_source("addons/gf/fixture.gd", source)
		starts = readability._independent_statement_starts(view)[1]
		names, path_tokens = readability._boolean_name_path_roles(view, starts)
		expected = {index for index, token in enumerate(view.tokens) if token.value in {"if", "Parent", "and", "Unique", "func"}}
		self.assertEqual(names, expected)
		self.assertEqual(readability._boolean_name_roles(view, starts), expected)
		self.assertLessEqual({index for index, token in enumerate(view.tokens) if token.value in {"$", "%", "/"}}, path_tokens)

	def test_shared_path_roles_include_quoted_and_absolute_node_markers(self) -> None:
		for shorthand in (
			"$Node", "$Parent/Child", "%Unique", "%Parent/Child", "$Parent/%Child",
			"$/root/Child", "%/root/Child", "$%/root/Child",
			'%"Unique"', '$%"Unique"', '$"Path/Child"', '$"if/func"',
		):
			source = "return " + shorthand + "\n"
			with self.subTest(shorthand=shorthand):
				view = readability.lex_source("addons/gf/fixture.gd", source)
				starts = readability._independent_statement_starts(view)[1]
				names, path_tokens = readability._boolean_name_path_roles(view, starts)
				markers = {index for index, token in enumerate(view.tokens) if token.value in {"$", "%", "/"} or (token.kind == "string" and token.value.startswith("$"))}
				self.assertTrue(markers)
				self.assertLessEqual(markers, path_tokens)
				self.assertEqual(readability._boolean_name_roles(view, starts), names)
				self.assertFalse(any(view.tokens[index].kind == "string" for index in names))

	def test_shared_path_roles_do_not_reclassify_real_modulo(self) -> None:
		for operand in ("value", "12", "values[index]", "owner.if", "$Parent/if", '$"Path"', "%Unique"):
			source = "return " + operand + " % divisor\n"
			with self.subTest(operand=operand):
				view = readability.lex_source("addons/gf/fixture.gd", source)
				starts = readability._independent_statement_starts(view)[1]
				_names, path_tokens = readability._boolean_name_path_roles(view, starts)
				modulo = [index for index, token in enumerate(view.tokens) if token.value == "%"][-1]
				self.assertNotIn(modulo, path_tokens)
		source = 'return "Value=%s" % %"Unique"\n'
		view = readability.lex_source("addons/gf/fixture.gd", source)
		_names, path_tokens = readability._boolean_name_path_roles(view, readability._independent_statement_starts(view)[1])
		percentages = [index for index, token in enumerate(view.tokens) if token.value == "%"]
		self.assertNotIn(percentages[0], path_tokens)
		self.assertIn(percentages[1], path_tokens)

	def test_keyword_member_names_keep_atomic_call_and_scalar_format_layouts(self) -> None:
		for member in ("value", "func", "if", "else", "not", "await", "in", "is", "as", "for", "return"):
			with self.subTest(member=member):
				self.assertEqual(self.rules("consume(owner." + member + ", other)\n"), set())
				self.assertEqual(self.rules('warn("Value=%s" % owner.' + member + ')\n'), set())
				for source in (
					"consume(owner." + member + "(), other)\n",
					"consume(owner." + member + "[index], other)\n",
					"consume(owner." + member + " + value, other)\n",
				):
					self.assertIn("multi_argument_call_layout", self.rules(source))
		for keyword in ("func", "if", "else", "await", "in", "is", "as", "for", "return"):
			with self.subTest(keyword=keyword):
				view = readability.lex_source("addons/gf/fixture.gd", keyword + "\n")
				identifier, atom, _barrier = readability._atomic_layout_matcher(view)
				self.assertFalse(identifier(0))
				self.assertIsNone(atom(0, len(view.tokens)))
	def test_keyword_member_before_expression_group_is_not_a_parameter_header(self) -> None:
		import gf_gdscript_expression_layout as expression
		for receiver in ("owner.func", "owner.signal", "$Parent/func", "$Parent/signal"):
			for source, keyword in (
				('return prefix if ' + receiver + ' else (\n\t"%s"\n\t% [value]\n)\n', "else"),
				("return " + receiver + " and (left or right)\n", "and"),
				("return " + receiver + " in (values)\n", "in"),
			):
				with self.subTest(source=source):
					view = readability.lex_source("addons/gf/fixture.gd", source)
					roles = expression.effective_group_kinds(view)
					group = next(number for number, item in enumerate(view.groups) if view.tokens[item.open_index - 1].value == keyword)
					self.assertEqual(roles[group], "group")
					self.assertNotIn("declaration_parameter_layout", self.rules(source))

	def test_actual_function_signal_and_lambda_parameter_headers_keep_their_roles(self) -> None:
		import gf_gdscript_expression_layout as expression
		for source in (
			"func run(left: int, right: int) -> void:\n\tpass\n",
			"signal changed(left: int, right: int)\n",
			"var callback = func(left: int, right: int) -> void:\n\tpass\n",
			"var callback = func named(left: int, right: int) -> void:\n\tpass\n",
		):
			with self.subTest(source=source):
				view = readability.lex_source("addons/gf/fixture.gd", source)
				self.assertEqual(expression.effective_group_kinds(view)[0], "parameters")
				self.assertEqual(self.rules(source), set())


if __name__ == "__main__":
	unittest.main()
