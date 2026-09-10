#!/usr/bin/env python3
"""Behavior tests for optional GDScript structure observations."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[3]
if str(ROOT / "tools") not in sys.path:
	sys.path.insert(0, str(ROOT / "tools"))

import gf_review_hotspots as hotspots


class ReviewHotspotsTests(unittest.TestCase):
	def analyze(self, source: str) -> dict:
		return hotspots.analyze_source(source, "addons/gf/sample.gd")

	def test_explicit_control_observations_are_not_boolean_path_scores(self) -> None:
		report = self.analyze(
			"func choose(value):\n"
			"\tif value and ready:\n"
			"\t\tfor entry in values:\n"
			"\t\t\twhile entry.active:\n"
			"\t\t\t\tbreak\n"
			"\telif alternate or fallback:\n"
			"\t\treturn 2\n"
			"\telse:\n"
			"\t\treturn 3 if ready else 4\n"
		)
		self.assertEqual(report["status"], "complete")
		row = report["functions"][0]
		self.assertEqual((row["start_line"], row["end_line"]), (1, 9))
		self.assertEqual(row["metrics"], {
			"branch_count": 3, "loop_count": 2, "match_arm_count": 0,
			"max_nesting": 3, "effective_code_lines": 8, "lambda_count": 0,
			"conditional_expression_count": 1,
		})
		self.assertNotIn("score", row)

	def test_comments_strings_and_multiline_literal_decoys_are_not_declarations(self) -> None:
		report = self.analyze(
			'# func fake():\n'
			'var text = """\nfunc fake2():\n\tif invented:\n"""\n'
			'func real():\n'
			'\tvar label = "for if # func fake3():" # while\n'
			'\tvar escaped = "quote \\\" elif"\n'
			'\t# if decoy:\n'
			'\treturn label\n'
		)
		self.assertEqual(report["status"], "complete")
		self.assertEqual([row["name"] for row in report["functions"]], ["real"])
		self.assertEqual(report["functions"][0]["metrics"]["branch_count"], 0)
		self.assertEqual(report["functions"][0]["metrics"]["effective_code_lines"], 3)

	def test_multiline_static_signature_annotations_and_nested_classes_have_unique_ids(self) -> None:
		report = self.analyze(
			'class_name Example\n'
			'class First:\n'
			'\t@warning_ignore("unused_parameter")\n'
			'\tstatic func same(\n'
			'\t\tvalue: Dictionary = {"func": ":"},\n'
			'\t) -> Array[String]:\n'
			'\t\treturn []\n'
			'\tclass Nested:\n'
			'\t\tfunc same():\n'
			'\t\t\tpass\n'
			'class Second:\n'
			'\tfunc same(): pass\n'
		)
		self.assertEqual(report["status"], "complete", report["issues"])
		rows = {row["qualified_name"]: row for row in report["functions"]}
		self.assertEqual(set(rows), {"Example.First.same", "Example.First.Nested.same", "Example.Second.same"})
		self.assertEqual(rows["Example.First.same"]["start_line"], 4)
		self.assertEqual(rows["Example.First.same"]["metrics"]["effective_code_lines"], 1)
		self.assertEqual(len({row["id"] for row in rows.values()}), 3)
		self.assertTrue(all(row["id"].startswith("addons/gf/sample.gd::") for row in rows.values()))

	def test_match_patterns_guards_and_wildcard_are_one_arm_each(self) -> None:
		report = self.analyze(
			'func inspect(value):\n'
			'\tmatch value:\n'
			'\t\t1, 2:\n'
			'\t\t\treturn 1\n'
			'\t\t{"name": var name} when name != "":\n'
			'\t\t\tif name.length() > 1:\n'
			'\t\t\t\treturn 2\n'
			'\t\t"a:b", "#": return 3\n'
			'\t\t_: return 0\n'
		)
		self.assertEqual(report["status"], "complete", report["issues"])
		metrics = report["functions"][0]["metrics"]
		self.assertEqual(metrics["match_arm_count"], 4)
		self.assertEqual(metrics["branch_count"], 5)
		self.assertEqual(metrics["max_nesting"], 3)

	def test_multiline_expressions_and_backslash_continuation_do_not_inflate_nesting(self) -> None:
		report = self.analyze(
			'func inspect():\n'
			'\tvar table = {\n'
			'\t\t"x": [1, 2],\n'
			'\t}\n'
			'\tif (\n'
			'\t\tready\n'
			'\t\tand active\n'
			'\t):\n'
			'\t\treturn 1 + \\\n'
			'\t\t\t2\n'
		)
		self.assertEqual(report["status"], "complete", report["issues"])
		metrics = report["functions"][0]["metrics"]
		self.assertEqual((metrics["branch_count"], metrics["max_nesting"]), (1, 1))
		self.assertEqual(metrics["effective_code_lines"], 9)

	def test_lambda_bodies_belong_to_nearest_named_function_without_duplicate_rows(self) -> None:
		report = self.analyze(
			'var at_script = func(): return 0\n'
			'func outer():\n'
			'\tvar callback = func named(value):\n'
			'\t\tif value:\n'
			'\t\t\treturn value\n'
			'\tinvoke(\n'
			'\t\tfunc():\n'
			'\t\t\tfor value in values:\n'
			'\t\t\t\tpass\n'
			'\t)\n'
			'\treturn callback\n'
			'func next(): pass\n'
		)
		self.assertEqual(report["status"], "complete", report["issues"])
		rows = {row["name"]: row for row in report["functions"]}
		self.assertEqual(set(rows), {"outer", "next"})
		self.assertEqual(rows["outer"]["metrics"]["lambda_count"], 2)
		self.assertEqual(rows["outer"]["metrics"]["branch_count"], 1)
		self.assertEqual(rows["outer"]["metrics"]["loop_count"], 1)
		self.assertEqual(rows["next"]["metrics"]["lambda_count"], 0)
		self.assertEqual(report["script_lambda_count"], 1)

	def test_property_accessors_are_not_misreported_as_named_functions(self) -> None:
		report = self.analyze('var enabled: bool:\n\tget:\n\t\treturn true\n\tset(value):\n\t\tpass\nfunc method(): pass\n')
		self.assertEqual(report["status"], "complete", report["issues"])
		self.assertEqual([row["name"] for row in report["functions"]], ["method"])

	def test_sort_is_explicit_stable_and_independent_of_declaration_order_ties(self) -> None:
		source = 'func plain(): pass\nfunc branch():\n\tif ready:\n\t\tpass\nfunc later(): pass\n'
		first = self.analyze(source)
		self.assertEqual(first, self.analyze(source))
		self.assertEqual([row["name"] for row in first["functions"]], ["branch", "plain", "later"])
		json.dumps(first, allow_nan=False)

	def test_duplicate_names_remain_unique_and_are_marked_incomplete(self) -> None:
		report = self.analyze('func same(): pass\nfunc same(): pass\n')
		self.assertEqual(report["status"], "incomplete")
		self.assertEqual(len({row["id"] for row in report["functions"]}), 2)
		self.assertIn("duplicate_function", {issue["code"] for issue in report["issues"]})

	def test_empty_source_is_complete_without_hotspots(self) -> None:
		report = self.analyze('# no function\n\n')
		self.assertEqual(report["status"], "complete")
		self.assertEqual(report["functions"], [])

	def test_unterminated_strings_and_delimiters_are_never_complete(self) -> None:
		for source in [
			'func x():\n\tvar bad = "unterminated\n',
			"func x():\n\tvar bad = '''unterminated\n",
			'func x(\n\tvalue: int\n',
			'func x():\n\treturn ([)]\n',
		]:
			with self.subTest(source=source):
				report = self.analyze(source)
				self.assertEqual(report["status"], "incomplete")
				self.assertTrue(report["issues"])
				self.assertTrue(all(row["status"] == "incomplete" for row in report["functions"]))

	def test_missing_body_and_unknown_block_are_explicit(self) -> None:
		for source in ['func x():\n# nothing\n', 'func x():\n\twith unknown:\n\t\tpass\n', 'func x()\n\tpass\n']:
			with self.subTest(source=source):
				self.assertEqual(self.analyze(source)["status"], "incomplete")

	def test_mixed_indent_is_not_silently_interpreted(self) -> None:
		report = self.analyze('func x():\n\t if yes:\n\t  pass\n')
		self.assertEqual(report["status"], "incomplete")
		self.assertIn("mixed_indentation", {issue["code"] for issue in report["issues"]})

	def test_size_line_and_function_budgets_are_explicit(self) -> None:
		with mock.patch.object(hotspots, "MAX_SOURCE_BYTES", 16):
			report = self.analyze('é' * 9)
		self.assertEqual(report["status"], "unknown")
		self.assertEqual(report["functions"], [])
		with mock.patch.object(hotspots, "MAX_LINES", 2):
			self.assertEqual(self.analyze('\n\n\n')["status"], "unknown")
		with mock.patch.object(hotspots, "MAX_FUNCTIONS", 1):
			report = self.analyze('func one(): pass\nfunc two(): pass\n')
		self.assertEqual(report["status"], "incomplete")
		self.assertLessEqual(len(report["functions"]), 1)
		self.assertIn("function_limit", {issue["code"] for issue in report["issues"]})

	def test_nested_bracket_and_block_budgets_do_not_recurse(self) -> None:
		with mock.patch.object(hotspots, "MAX_BRACKET_DEPTH", 3):
			report = self.analyze('func x():\n\treturn [[[[0]]]]\n')
		self.assertEqual(report["status"], "incomplete")
		with mock.patch.object(hotspots, "MAX_NESTING", 3):
			report = self.analyze('func x():\n\tif a:\n\t\tif b:\n\t\t\tif c:\n\t\t\t\tif d:\n\t\t\t\t\tpass\n')
		self.assertEqual(report["status"], "incomplete")
		self.assertIn("nesting_limit", {issue["code"] for issue in report["issues"]})

	def test_invalid_unicode_and_control_input_fail_without_echoing_source(self) -> None:
		for source in ['\ud800', '\x00secret', '\x1bsecret', '\x85secret']:
			with self.subTest(source=repr(source)):
				report = self.analyze(source)
				self.assertEqual(report["status"], "unknown")
				self.assertNotIn('secret', json.dumps(report))

	def test_crlf_and_unicode_identifiers_have_consistent_line_locations(self) -> None:
		report = self.analyze('\ufeffclass Inner:\r\n\tfunc 检查():\r\n\t\treturn true\r\n')
		self.assertEqual(report["status"], "complete", report["issues"])
		self.assertEqual(report["functions"][0]["qualified_name"], "Inner.检查")
		self.assertEqual(report["functions"][0]["end_line"], 3)

	def test_literal_path_is_only_identity_and_source_is_never_executed(self) -> None:
		report = hotspots.analyze_source('func x(): OS.execute("never", [])\n', '../../literal;$(path).gd')
		self.assertEqual(report["path"], '../../literal;$(path).gd')
		self.assertEqual(report["status"], 'complete')

	def test_semicolon_separated_bodies_are_explicitly_incomplete(self) -> None:
		for source in ['func x(): first(); second()\n', 'func x():\n\tfirst(); if ready: pass\n']:
			with self.subTest(source=source):
				report = self.analyze(source)
				self.assertEqual(report["status"], "incomplete")
				self.assertIn("unsupported_statement_separator", {issue["code"] for issue in report["issues"]})

	def test_large_multiline_container_is_bounded_and_does_not_create_scope_nesting(self) -> None:
		report = self.analyze('func x():\n\tvar items = [\n' + '\t\t1,\n' * 20_000 + '\t]\n\treturn items\n')
		self.assertEqual(report["status"], "complete", report["issues"])
		self.assertEqual(len(report["functions"]), 1)
		self.assertEqual(report["functions"][0]["metrics"]["max_nesting"], 0)
		self.assertEqual(report["functions"][0]["metrics"]["effective_code_lines"], 20_003)

	def test_issue_and_token_limits_are_reported_without_unbounded_diagnostics(self) -> None:
		with mock.patch.object(hotspots, "MAX_ISSUES", 2):
			report = self.analyze('func x():\n' + '\t with unsupported:\n' * 20)
		self.assertEqual(report["status"], "incomplete")
		self.assertEqual(len(report["issues"]), 2)
		self.assertGreater(report["omitted_issue_count"], 0)
		with mock.patch.object(hotspots, "MAX_TOKENS", 8):
			report = self.analyze('func x():\n\treturn [1,2,3,4,5]\n')
		self.assertEqual(report["status"], "incomplete")
		self.assertIn("token_limit", {issue["code"] for issue in report["issues"]})

	def test_algorithm_contract_is_in_report_and_sort_key_is_reusable(self) -> None:
		report = self.analyze('func x(): pass\n')
		self.assertEqual(report["algorithm_version"], hotspots.ALGORITHM_VERSION)
		self.assertEqual(report["metric_definitions"], hotspots.METRIC_DEFINITIONS)
		self.assertEqual(report["sort_order"], hotspots.SORT_ORDER)
		self.assertEqual(sorted(report["functions"], key=hotspots.function_sort_key), report["functions"])

	def test_typed_for_iterator_colon_is_not_the_loop_body_colon(self) -> None:
		report = self.analyze('func x():\n\tfor item: Dictionary[String, Variant] in items:\n\t\tif item.ready:\n\t\t\treturn item\n\treturn null\n')
		self.assertEqual(report["status"], "complete", report["issues"])
		self.assertEqual(report["functions"][0]["metrics"]["loop_count"], 1)
		self.assertEqual(report["functions"][0]["metrics"]["max_nesting"], 2)

	def test_sibling_lambdas_and_following_call_arguments_keep_enclosing_ownership(self) -> None:
		report = self.analyze(
			'func x():\n'
			'\treturn invoke(\n'
			'\t\tfunc(value):\n'
			'\t\t\tif value:\n'
			'\t\t\t\treturn value,\n'
			'\t\tfunc named(value):\n'
			'\t\t\treturn value,\n'
			'\t\towner,\n'
			'\t\t{"next": func():\n'
			'\t\t\treturn null,\n'
			'\t\t"limit": 10}\n'
			'\t)\n'
		)
		self.assertEqual(report["status"], "complete", report["issues"])
		self.assertEqual(len(report["functions"]), 1)
		self.assertEqual(report["functions"][0]["metrics"]["lambda_count"], 3)
		self.assertEqual(report["functions"][0]["metrics"]["branch_count"], 1)
		self.assertEqual(report["functions"][0]["end_line"], 12)

	def test_multiline_lambda_in_control_header_has_explicit_support_limit(self) -> None:
		report = self.analyze('func x():\n\tif values.any(func(item):\n\t\treturn item == null\n\t):\n\t\treturn true\n')
		self.assertEqual(report["status"], "incomplete")
		self.assertIn("unsupported_lambda_in_control_header", {issue["code"] for issue in report["issues"]})

	def test_declaration_names_and_identity_have_independent_length_budgets(self) -> None:
		for source in ['class_name ' + 'A' * 257, 'class ' + 'A' * 257 + ':\n\tpass\n', 'func ' + 'a' * 257 + '(): pass\n']:
			with self.subTest(source_length=len(source)):
				report = self.analyze(source)
				self.assertEqual(report["status"], "incomplete")
				self.assertIn("identifier_limit", {issue["code"] for issue in report["issues"]})
		with mock.patch.object(hotspots, "MAX_QUALIFIED_NAME_LENGTH", 8):
			report = self.analyze('class Owner:\n\tfunc method(): pass\n')
		self.assertEqual(report["status"], "incomplete")
		self.assertEqual(report["functions"], [])
		with mock.patch.object(hotspots, "MAX_ID_LENGTH", 8):
			self.assertEqual(self.analyze('func x(): pass\n')["status"], "incomplete")
		report = hotspots.analyze_source('func x(): pass\n', 'p' * 4097)
		self.assertEqual(report["status"], "unknown")
		self.assertEqual(report["path"], "")

	def test_inline_control_bodies_and_conditions_count_their_lambdas(self) -> None:
		report = self.analyze(
			'func inspect(values):\n'
			'\tif enabled: values.map(func(x): return x)\n'
			'\telif values.any(func(x): return bool(x)): return 1\n'
			'\telse: values.filter(func(x): return true)\n'
			'\twhile values.any(func(x): return bool(x)): break\n'
			'\tfor item in values.map(func(x): return x): pass\n'
			'\tmatch code:\n'
			'\t\t_: values.map(func(x): return x)\n'
		)
		self.assertEqual(report["status"], "complete", report["issues"])
		metrics = report["functions"][0]["metrics"]
		self.assertEqual(metrics["lambda_count"], 6)
		self.assertEqual(metrics["branch_count"], 4)
		self.assertEqual(metrics["loop_count"], 2)
		self.assertEqual(metrics["match_arm_count"], 1)
		self.assertEqual(metrics["max_nesting"], 2)
		self.assertEqual(report["script_lambda_count"], 0)

	def test_explicit_continuation_keeps_named_static_function_identity(self) -> None:
		report = self.analyze(
			'func split \\\n'
			'():\n'
			'\tpass\n'
			'class Inner:\n'
			'\tstatic func same \\\n'
			'\t(value):\n'
			'\t\tif value:\n'
			'\t\t\treturn value\n'
		)
		self.assertEqual(report["status"], "complete", report["issues"])
		rows = {row["qualified_name"]: row for row in report["functions"]}
		self.assertEqual(set(rows), {"split", "Inner.same"})
		self.assertEqual((rows["split"]["start_line"], rows["split"]["end_line"]), (1, 3))
		self.assertEqual((rows["Inner.same"]["start_line"], rows["Inner.same"]["end_line"]), (5, 8))
		self.assertEqual(rows["split"]["metrics"]["effective_code_lines"], 1)
		self.assertEqual(rows["Inner.same"]["metrics"]["effective_code_lines"], 2)
		self.assertEqual(report["script_lambda_count"], 0)


if __name__ == "__main__":
	unittest.main()
