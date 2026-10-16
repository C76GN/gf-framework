"""Complete-expression formatting contracts shared by diagnostics and migration."""

from __future__ import annotations

from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools"))
import gf_gdscript_expression_layout as expression
import gf_gdscript_readability as readability


class ExpressionLayoutTests(unittest.TestCase):
	def canonical(self, source: str, path: str = "addons/gf/fixture.gd") -> str:
		for _round in range(12):
			view = readability.lex_source(path, source)
			self.assertEqual(view.issues, ())
			edits = expression.layout_edits(view)
			self.assertEqual(list(edits), sorted(edits, key=lambda edit: (edit.start, edit.end)))
			for previous, current in zip(edits, edits[1:]):
				self.assertLessEqual(previous.end, current.start)
			if not edits:
				return source
			for edit in reversed(edits):
				source = source[:edit.start] + edit.replacement + source[edit.end:]
		self.fail("Expression layout did not converge.")

	def test_arithmetic_single_expression_uses_one_line(self) -> None:
		source = 'var total = (\n\tleft\n\t+ right\n)\n'
		self.assertEqual(self.canonical(source), 'var total = (left + right)\n')

	def test_one_ternary_choice_is_one_line(self) -> None:
		source = 'return (\n\tregistry\n\tif registry != null\n\telse Registry.shared()\n)\n'
		self.assertEqual(self.canonical(source), 'return (registry if registry != null else Registry.shared())\n')

	def test_index_with_inline_child_is_inline(self) -> None:
		source = 'values[\n\treader.get_value(key)\n] = value\n'
		self.assertEqual(self.canonical(source), 'values[reader.get_value(key)] = value\n')

	def test_chain_joins_receiver_and_suffix_after_multiline_stage(self) -> None:
		source = 'var value = (\n\tmake(\n\t\ta,\n\t\tb\n\t)\n\t.next()\n)\n'
		self.assertEqual(self.canonical(source), 'var value = (\n\tmake(\n\t\ta,\n\t\tb\n\t).next()\n)\n')

	def test_multiline_ordinary_group_checks_missing_indent_and_close(self) -> None:
		source = 'var value = (\nmake(\n\ta,\n\tb\n) + other)\n'
		self.assertEqual(self.canonical(source), 'var value = (\n\tmake(\n\t\ta,\n\t\tb\n\t) + other\n)\n')

	def test_complete_ungrouped_items_join_inside_call_array_and_dictionary(self) -> None:
		cases = (
			('consume(\n\tleft\n\t+ right\n)\n', 'consume(\n\tleft + right\n)\n'),
			('var items = [\n\tleft\n\t+ right,\n]\n', 'var items = [\n\tleft + right,\n]\n'),
			('var data = {\n\t"value": yes\n\tif ready\n\telse no,\n}\n', 'var data = {\n\t"value": yes if ready else no,\n}\n'),
		)
		for source, expected in cases:
			with self.subTest(source=source):
				self.assertEqual(self.canonical(source), expected)

	def test_complete_default_ternary_and_arithmetic_have_their_own_domain(self) -> None:
		source = 'func f(\n\tvalue = left\n\t+ right\n) -> void:\n\tpass\n'
		self.assertEqual(self.canonical(source), 'func f(\n\tvalue = left + right\n) -> void:\n\tpass\n')

	def test_formula_count_and_leaf_length_do_not_add_groups(self) -> None:
		source = 'var value = (\n\ta * b\n\t+ c / d\n\t- e\n)\n'
		self.assertEqual(self.canonical(source), 'var value = (a * b + c / d - e)\n')
		long_name = 'variable_' + 'x' * 2000
		self.assertEqual(self.canonical(source.replace('a * b', long_name + ' * b')), 'var value = (' + long_name + ' * b + c / d - e)\n')

	def test_precedence_parentheses_and_one_unary_are_preserved(self) -> None:
		source = 'return (\n\t-(left + right)\n\t* mask\n\t>> count\n)\n'
		self.assertEqual(self.canonical(source), 'return (-(left + right) * mask >> count)\n')

	def test_existing_required_boolean_layers_never_collapse(self) -> None:
		source = 'if (\n\ta\n\tand b\n\tand c\n):\n\tpass\n'
		self.assertEqual(self.canonical(source), source)

	def test_required_nested_ternary_layers_never_collapse(self) -> None:
		source = 'return (\n\ta\n\tif first\n\telse (\n\t\tb\n\t\tif second\n\t\telse c\n\t)\n)\n'
		self.assertEqual(self.canonical(source), source)

	def test_independent_dictionary_key_and_value_choices_are_not_nested(self) -> None:
		source = 'var data = {\n\t("a" if first else "b"): (\n\t\t1\n\t\tif second\n\t\telse 2\n\t),\n}\n'
		expected = 'var data = {\n\t("a" if first else "b"): (1 if second else 2),\n}\n'
		self.assertEqual(self.canonical(source), expected)

	def test_multiline_index_preserves_child_call_and_has_no_array_comma(self) -> None:
		source = 'var value = items[\nread(\n\ta,\n\tb\n)]\n'
		expected = 'var value = items[\n\tread(\n\t\ta,\n\t\tb\n\t)\n]\n'
		self.assertEqual(self.canonical(source), expected)

	def test_generic_type_brackets_are_not_index_owners(self) -> None:
		source = 'var values: Dictionary[\n\tString,\n\tint\n] = {}\n'
		self.assertEqual(self.canonical(source), source)

	def test_independent_group_after_previous_call_is_not_a_call(self) -> None:
		source = 'owner["key"] = read()\n(\n\towner\n\t.next()\n)\n'
		view = readability.lex_source('addons/gf/fixture.gd', source)
		roles = expression.effective_group_kinds(view)
		self.assertEqual(roles[-2], 'group')
		self.assertEqual(self.canonical(source), 'owner["key"] = read()\n(owner.next())\n')

	def test_independent_array_after_previous_call_is_not_an_index(self) -> None:
		source = 'run()\n[1].duplicate()\n'
		view = readability.lex_source('addons/gf/fixture.gd', source)
		roles = expression.effective_group_kinds(view)
		self.assertEqual(roles[1], 'array')

	def test_await_group_keeps_hierarchy_without_changing_await(self) -> None:
		source = 'var value = (await run(\n\ta,\n\tb\n))\n'
		expected = 'var value = (\n\tawait run(\n\t\ta,\n\t\tb\n\t)\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_lambda_group_reindents_header_and_body_as_one_owned_subtree(self) -> None:
		source = 'var callback = (func() -> void:\n\trun()\n)\n'
		expected = 'var callback = (\n\tfunc() -> void:\n\t\trun()\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_lambda_body_independent_expression_has_its_own_level(self) -> None:
		source = 'var callback = (\n\tfunc() -> void:\n\t\tvar value = (\n\t\t\tleft\n\t\t\t+ right\n\t\t)\n\t\tconsume(value)\n)\n'
		expected = 'var callback = (\n\tfunc() -> void:\n\t\tvar value = (left + right)\n\t\tconsume(value)\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_comments_preserve_owner_but_not_independent_descendants(self) -> None:
		source = 'var value = (\n\t# Preserve this comment and its line.\n\t(\n\t\tleft\n\t\t+ right\n\t)\n)\n'
		expected = 'var value = (\n\t# Preserve this comment and its line.\n\t(left + right)\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_explicit_continuation_barrier_is_local_to_its_owner(self) -> None:
		source = 'var value = (\n\tleft \\\n\t+ (\n\t\tright\n\t\t* factor\n\t)\n)\n'
		expected = 'var value = (\n\tleft \\\n\t+ (right * factor)\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_actual_multiline_literal_payload_is_never_reindented(self) -> None:
		source = 'var value = (\n\t"""\npayload\n  exact text\n"""\n\t+ suffix\n)\n'
		result = self.canonical(source)
		before = [token.value for token in readability.lex_source('addons/gf/f.gd', source).tokens if token.kind == 'string']
		after = [token.value for token in readability.lex_source('addons/gf/f.gd', result).tokens if token.kind == 'string']
		self.assertEqual(after, before)

	def test_chain_comment_and_explicit_continuation_are_real_local_barriers(self) -> None:
		source = 'var value = (\n\towner # Preserve receiver explanation.\n\t.next()\n)\n'
		self.assertEqual(self.canonical(source), source)

	def test_scalar_format_is_not_rewritten_as_array_format(self) -> None:
		source = 'push_warning("Unknown: %s." % kind)\n'
		self.assertEqual(self.canonical(source), source)

	def test_array_format_inside_call_borrows_existing_carrier(self) -> None:
		source = 'warn(\n\t"State=%s" % [state]\n)\n'
		expected = 'warn(\n\t"State=%s"\n\t% [state]\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_array_format_assignment_adds_only_necessary_continuation_carrier(self) -> None:
		source = 'var message = "State=%s" % [state]\n'
		expected = 'var message = (\n\t"State=%s"\n\t% [state]\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_array_format_return_inside_lambda_cannot_borrow_ambient_call(self) -> None:
		source = 'consume(\n\tfunc() -> String:\n\t\treturn "State=%s" % [state]\n)\n'
		expected = 'consume(\n\tfunc() -> String:\n\t\treturn (\n\t\t\t"State=%s"\n\t\t\t% [state]\n\t\t)\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_array_format_keeps_concatenation_precedence_group(self) -> None:
		source = 'warn(\n\t("State=%s " + "count=%d.") % [state, count]\n)\n'
		expected = 'warn(\n\t("State=%s " + "count=%d.")\n\t% [state, count]\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_array_format_does_not_rewrite_partial_operator_or_comment_domains(self) -> None:
		for source in ('var result = a + template % [value]\n', 'warn(\n\t"%s" # Template explanation.\n\t% [value]\n)\n'):
			with self.subTest(source=source):
				self.assertEqual(self.canonical(source), source)

	def test_array_format_does_not_add_a_group_inside_dictionary_value(self) -> None:
		source = 'var value = {\n\t"message": "%s" % [name],\n}\n'
		expected = 'var value = {\n\t"message": "%s"\n\t% [name],\n}\n'
		self.assertEqual(self.canonical(source), expected)

	def test_template_offsets_remain_original_and_all_noncarrier_tokens_are_exact(self) -> None:
		source = 'class_name {ClassName}\nextends {BaseClass}\n\nfunc sample():\n\treturn (\n\t\tleft\n\t\t+ right\n\t)\n'
		expected = source.replace('(\n\t\tleft\n\t\t+ right\n\t)', '(left + right)')
		self.assertEqual(self.canonical(source, 'addons/gf/standard/state_machine/node/editor/templates/node_state.gdtemplate'), expected)

	def test_edits_preserve_original_literals_comments_and_token_order(self) -> None:
		source = 'var callback = (func():\n\tvar value = (\n\t\t"exact \\\" text"\n\t\t+ suffix\n\t)\n\tconsume(value) # Keep this exact text.\n)\n'
		result = self.canonical(source)
		before = readability.lex_source('addons/gf/f.gd', source)
		after = readability.lex_source('addons/gf/f.gd', result)
		self.assertEqual([(token.kind, token.value) for token in after.tokens], [(token.kind, token.value) for token in before.tokens])
		self.assertEqual([token.value for token in after.comments], [token.value for token in before.comments])

	def test_lambda_subtree_translation_retains_comment_binding(self) -> None:
		source = 'var callback = (func():\n\t# Explain this body statement.\n\trun()\n)\n'
		expected = 'var callback = (\n\tfunc():\n\t\t# Explain this body statement.\n\t\trun()\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_keyword_member_call_parentheses_are_joined_using_proven_role(self) -> None:
		source = 'var value = (\n\towner.or\n\t(value)\n)\n'
		self.assertEqual(self.canonical(source), 'var value = (owner.or(value))\n')

	def test_specialized_scalar_and_string_rules_remain_the_only_collapse_owner(self) -> None:
		for source in ('var value = (\n\t"left"\n\t+ "right"\n)\n', 'var value = (\n\t"%s"\n\t% name\n)\n'):
			with self.subTest(source=source):
				self.assertEqual(expression.layout_edits(readability.lex_source('addons/gf/f.gd', source)), ())

	def test_comment_barrier_preserves_lines_but_not_wrong_owner_indentation(self) -> None:
		source = 'var value = (\n\t# Explain the value.\nleft\n\t# Explain the closing layer.\n\t\t)\n'
		expected = 'var value = (\n\t# Explain the value.\n\tleft\n\t# Explain the closing layer.\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_numeric_modulo_in_complete_borrowed_carrier_operand_joins(self) -> None:
		source = 'consume(\n\tvalue\n\t% divisor\n)\n'
		self.assertEqual(self.canonical(source), 'consume(\n\tvalue % divisor\n)\n')

	def test_two_boolean_terms_in_complete_borrowed_domain_follow_dynamic_policy(self) -> None:
		source = 'consume(\n\tready\n\tand active\n)\n'
		if readability.MAX_INLINE_CONDITION_TERMS >= 2:
			self.assertEqual(self.canonical(source), 'consume(\n\tready and active\n)\n')
		else:
			self.assertEqual(self.canonical(source), source)

	def test_format_in_single_ternary_branch_gets_only_necessary_local_carrier(self) -> None:
		source = 'metadata["path"] = prefix if empty else "%s.%s" % [prefix, nested]\n'
		expected = 'metadata["path"] = prefix if empty else (\n\t"%s.%s"\n\t% [prefix, nested]\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_format_in_ternary_branch_borrows_real_call_carrier(self) -> None:
		source = 'consume(\n\tprefix if empty else "%s.%s" % [prefix, nested]\n)\n'
		expected = 'consume(\n\tprefix if empty else "%s.%s"\n\t% [prefix, nested]\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_array_format_keyword_named_template_member_is_not_a_lambda(self) -> None:
		source = 'var text = owner.func() % [value]\n'
		expected = 'var text = (\n\towner.func()\n\t% [value]\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_ternary_format_in_lambda_statement_cannot_borrow_ambient_call(self) -> None:
		source = 'consume(\n\tfunc() -> String:\n\t\treturn prefix if empty else "%s" % [value]\n)\n'
		expected = 'consume(\n\tfunc() -> String:\n\t\treturn prefix if empty else (\n\t\t\t"%s"\n\t\t\t% [value]\n\t\t)\n)\n'
		self.assertEqual(self.canonical(source), expected)

	def test_keyword_member_lambda_unique_node_statement_is_not_previous_rhs_modulo(self) -> None:
		for host in ('state.func', '$Node.func', '%Unique.func'):
			for previous in ('ready', 'ready()', '"ready"'):
				with self.subTest(host=host, previous=previous):
					source = host + '(\n\tfunc() -> void:\n\t\tvar previous = ' + previous + '\n\t\t%or/and/Child.activate()\n)\n'
					self.assertEqual(self.canonical(source), source)

	def test_scalar_formats_with_inline_children_join_without_extra_carriers(self) -> None:
		for operand in ('build(value)', 'values[index]', '(left + right)', '(value as String)', '(await reader.read())', '(left if ready else right)', '{}'):
			with self.subTest(operand=operand):
				source = 'warn(\n\t"Value=%s"\n\t% ' + operand + '\n)\n'
				expected = 'warn("Value=%s" % ' + operand + ')\n'
				self.assertEqual(self.composed(source), expected)
				self.assertTrue(readability.audit_source('addons/gf/f.gd', source))
				self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])

	def test_scalar_assignment_and_return_do_not_add_continuation_carriers(self) -> None:
		for prefix in ('var message = ', 'return '):
			for operand in ('build(value)', 'values[index]', '(left if ready else right)'):
				with self.subTest(prefix=prefix, operand=operand):
					source = prefix + '"Value=%s" % ' + operand + '\n'
					self.assertEqual(self.canonical(source), source)
					self.assertEqual(readability.audit_source('addons/gf/f.gd', source), [])

	def test_scalar_formats_keep_existing_group_and_concat_precedence(self) -> None:
		for template in ('"Value=%s"', '("Value=" + "%s")', 'r"Value=%s"'):
			with self.subTest(template=template):
				source = 'var message = (\n\t' + template + ' % build(value)\n)\n'
				expected = 'var message = (' + template + ' % build(value))\n'
				self.assertEqual(self.canonical(source), expected)

	def test_scalar_formats_inside_container_values_use_inline_child_layout(self) -> None:
		for source, expected in (
			('var messages = [\n\t"Value=%s" % values[index],\n]\n', 'var messages = ["Value=%s" % values[index],]\n'),
			('var messages = {\n\t"message": "Value=%s" % build(value),\n}\n', 'var messages = { "message": "Value=%s" % build(value), }\n'),
		):
			with self.subTest(source=source):
				self.assertEqual(self.composed(source), expected)
				self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])

	def test_scalar_format_in_ternary_branch_needs_no_new_carrier(self) -> None:
		for source, expected in (
			('return prefix if empty else "%s" % build(value)\n', 'return prefix if empty else "%s" % build(value)\n'),
			('consume(\n\tprefix if empty else "%s" % values[index]\n)\n', 'consume(prefix if empty else "%s" % values[index])\n'),
			('consume(\n\tfunc() -> String:\n\t\treturn prefix if empty else "%s" % build(value)\n)\n', 'consume(\n\tfunc() -> String:\n\t\treturn prefix if empty else "%s" % build(value)\n)\n'),
		):
			with self.subTest(source=source):
				self.assertEqual(self.composed(source), expected)

	def test_scalar_format_keeps_required_child_boolean_layers(self) -> None:
		source = 'warn(\n\t"Value=%s" % (\n\t\tfirst\n\t\tand second\n\t\tand third\n\t)\n)\n'
		expected = source
		self.assertEqual(self.canonical(source), expected)
		self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])

	def test_simple_scalar_formats_with_boundary_comments_do_not_become_complex(self) -> None:
		for operand in ('value', 'owner.value', '-count', 'not ready', 'true', 'null', '(value)', '(+value)'):
			with self.subTest(operand=operand):
				source = 'warn("Value=%s" % ' + operand + ') # Preserve this binding.\n'
				self.assertEqual(self.canonical(source), source)

	def test_unknown_or_numeric_modulo_is_not_guessed_to_be_string_formatting(self) -> None:
		for left in ('value', '12', '12.5', 'values[index]', 'owner.read()', '&"name"', '^"path"'):
			with self.subTest(left=left):
				source = 'consume(\n\t' + left + '\n\t% divisor()\n)\n'
				expected = 'consume(\n\t' + left + ' % divisor()\n)\n'
				self.assertEqual(self.canonical(source), expected)
				self.assertFalse(any(edit.rule in {'format_layout', 'format_carrier'} for edit in expression.layout_edits(readability.lex_source('addons/gf/f.gd', source))))

	def test_scalar_formats_compose_with_two_nonatomic_call_arguments(self) -> None:
		source = 'report("Value=%s" % build(value), "Other=%s" % values[index])\n'
		expected = 'report(\n\t"Value=%s" % build(value),\n\t"Other=%s" % values[index]\n)\n'
		self.assertEqual(self.composed(source), expected)
		self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])

	def test_membership_and_type_comparisons_join_complete_inline_operands(self) -> None:
		for operator in ('in', 'not in', 'is'):
			with self.subTest(operator=operator):
				source = 'consume(\n\tvalue\n\t' + operator + ' other\n)\n'
				self.assertEqual(self.canonical(source), 'consume(\n\tvalue ' + operator + ' other\n)\n')

	def test_membership_composes_with_canonical_inline_and_expanded_list_children(self) -> None:
		for source in ('assert_true(result.get_status()\n\tin [FIRST, SECOND,])\n', 'assert_true(\n\tresult.get_status()\n\tin [\n\t\tFIRST,\n\t\tSECOND,\n\t]\n)\n'):
			with self.subTest(source=source):
				expected = 'assert_true(result.get_status() in [FIRST, SECOND,])\n'
				self.assertEqual(self.composed(source), expected)
				self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])
		source = 'assert_true(result.get_status() in [FIRST, SECOND, THIRD])\n'
		expected = 'assert_true(\n\tresult.get_status() in [\n\t\tFIRST,\n\t\tSECOND,\n\t\tTHIRD,\n\t]\n)\n'
		self.assertEqual(self.composed(source), expected)
		self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])

	def composed(self, source: str) -> str:
		import gf_gdscript_list_layout as lists
		import gf_gdscript_layout_integrity as integrity
		for _round in range(12):
			before = source
			for module in (lists, expression, integrity):
				view = readability.lex_source('addons/gf/f.gd', source)
				self.assertEqual(view.issues, ())
				for edit in reversed(module.layout_edits(view)):
					source = source[:edit.start] + edit.replacement + source[edit.end:]
			if source == before:
				return source
		self.fail('Composed layout did not converge.')

	def test_node_reference_scalar_format_uses_inline_expression_layout(self) -> None:
		for operand in ('$Node', '$Parent/Child', '%Unique', '%Parent/Child', '$Parent/%Child', '$/Root/Child', '%/Root/Child', '$"Parent/Child"', '%"Unique"', '$%"Unique"'):
			with self.subTest(operand=operand):
				source = 'warn(\n\t"Value=%s"\n\t% ' + operand + '\n)\n'
				expected = 'warn("Value=%s" % ' + operand + ')\n'
				self.assertEqual(self.composed(source), expected)
				self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])

	def test_reserved_keyword_path_names_do_not_hide_ternary_format_slots(self) -> None:
		for keyword in ('and', 'as', 'await', 'class', 'const', 'elif', 'else', 'extends', 'for', 'func', 'get', 'if', 'in', 'is', 'match', 'not', 'or', 'return', 'set', 'signal', 'var', 'when', 'while'):
			for value in ('$Parent/' + keyword, '%Parent/' + keyword, '%' + keyword, 'owner.' + keyword):
				for source, expected in (
					('return ' + value + ' if ready else "%s" % [value]\n', 'return ' + value + ' if ready else (\n\t"%s"\n\t% [value]\n)\n'),
					('return prefix if ' + value + ' else "%s" % [value]\n', 'return prefix if ' + value + ' else (\n\t"%s"\n\t% [value]\n)\n'),
				):
					with self.subTest(keyword=keyword, value=value, source=source):
						self.assertEqual(self.canonical(source), expected)
						self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])

	def test_reserved_keyword_node_templates_preserve_array_format_layout(self) -> None:
		for keyword in ('and', 'as', 'await', 'else', 'func', 'if', 'not', 'or', 'return'):
			for operand in ('$Parent/' + keyword, '%Parent/' + keyword, '%' + keyword, '$Parent/%' + keyword):
				with self.subTest(operand=operand):
					source = 'warn(\n\t' + operand + '.get_template()\n\t% [value]\n)\n'
					self.assertEqual(self.composed(source), source)
					self.assertEqual(readability.audit_source('addons/gf/f.gd', source), [])

	def test_keyword_member_chains_share_ordinary_simple_scalar_shape(self) -> None:
		for keyword in ('and', 'as', 'await', 'class', 'const', 'elif', 'else', 'extends', 'for', 'func', 'get', 'if', 'in', 'is', 'match', 'not', 'or', 'return', 'set', 'signal', 'var', 'when', 'while'):
			for operand in ('owner.' + keyword, '(owner.' + keyword + ')', '-owner.' + keyword):
				with self.subTest(operand=operand):
					source = 'warn(\n\t"Value=%s"\n\t% ' + operand + '\n)\n'
					expected = 'warn("Value=%s" % ' + operand + ')\n'
					view = readability.lex_source('addons/gf/f.gd', source)
					self.assertTrue(any(span.context == 'call' and span.start == 0 and span.end == len(source) - 1 for span in readability.simple_format_layout_spans(view)))
					self.assertIn('simple_format_layout', {issue['rule'] for issue in readability.audit_source('addons/gf/f.gd', source)})
					self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])

	def test_keyword_paths_do_not_borrow_lambda_carriers_or_change_numeric_modulo(self) -> None:
		for value in ('$Parent/func', '%func', 'owner.func'):
			with self.subTest(value=value):
				source = 'consume(\n\tfunc() -> String:\n\t\treturn ' + value + ' if ready else "%s" % [value]\n)\n'
				expected = 'consume(\n\tfunc() -> String:\n\t\treturn ' + value + ' if ready else (\n\t\t\t"%s"\n\t\t\t% [value]\n\t\t)\n)\n'
				self.assertEqual(self.canonical(source), expected)
				source = 'consume(\n\t' + value + '\n\t% divisor()\n)\n'
				self.assertEqual(self.canonical(source), 'consume(\n\t' + value + ' % divisor()\n)\n')

	def test_format_operand_boundaries_follow_comparison_and_multiplicative_precedence(self) -> None:
		for source, expected in (
			('warn(\n\t"%s"\n\t% value in values\n)\n', 'warn("%s" % value in values)\n'),
			('warn(\n\t"%s"\n\t% value not in values\n)\n', 'warn("%s" % value not in values)\n'),
			('var accepted = "%s" % build(value) in values\n', 'var accepted = "%s" % build(value) in values\n'),
			('var accepted = left == "%s" % build(value)\n', 'var accepted = left == "%s" % build(value)\n'),
			('var accepted = "%s" % build(value) == right\n', 'var accepted = "%s" % build(value) == right\n'),
			('var text = "%s" % build(value) as String\n', 'var text = "%s" % build(value) as String\n'),
			('warn("%s" % value is String)\n', 'warn("%s" % value is String)\n'),
			('warn("%s" % value ** exponent)\n', 'warn("%s" % value ** exponent)\n'),
			('warn("%s" % value * scale)\n', 'warn("%s" % value * scale)\n'),
			('var text = "%s" % build(value) * scale\n', 'var text = "%s" % build(value) * scale\n'),
			('var text = scale * "%s" % build(value)\n', 'var text = scale * "%s" % build(value)\n'),
			('var text = "%s" % build(value) % divisor\n', 'var text = "%s" % build(value) % divisor\n'),
			('var text = "%s" % build(value) + "%s" % other(value)\n', 'var text = "%s" % build(value) + "%s" % other(value)\n'),
			('var text = "%s" % await reader.read()\n', 'var text = "%s" % await reader.read()\n'),
			('var text = value % build(value) in values\n', 'var text = value % build(value) in values\n'),
		):
			with self.subTest(source=source):
				self.assertEqual(self.composed(source), expected)
				self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])

	def test_scalar_format_expands_only_when_its_child_list_requires_it(self) -> None:
		for source, expected in (
			('warn("%s" % build(first, second, third))\n', 'warn(\n\t"%s" % build(\n\t\tfirst,\n\t\tsecond,\n\t\tthird\n\t)\n)\n'),
			('var text = "%s" % build(first, second, third)\n', 'var text = "%s" % build(\n\tfirst,\n\tsecond,\n\tthird\n)\n'),
		):
			with self.subTest(source=source):
				self.assertEqual(self.composed(source), expected)
				self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])
				self.assertFalse(any(edit.rule == 'format_carrier' for edit in expression.layout_edits(readability.lex_source('addons/gf/f.gd', source))))

	def test_array_format_node_templates_share_quoted_and_absolute_path_proof(self) -> None:
		for template in ('$Node', '$Parent/Child', '%Unique', '%Parent/Child', '$Parent/%Child', '$/Root/Child', '%/Root/Child', '$"Parent/Child"', '%"Unique"', '$%"Unique"'):
			with self.subTest(template=template):
				source = 'warn(' + template + '.get_template() % [value])\n'
				expected = 'warn(\n\t' + template + '.get_template()\n\t% [value]\n)\n'
				self.assertEqual(self.composed(source), expected)
				self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])

	def test_two_array_format_ternary_branches_keep_independent_carriers(self) -> None:
		source = 'return "%s" % [left] if ready else "%s" % [right]\n'
		expected = 'return (\n\t"%s"\n\t% [left]\n) if ready else (\n\t"%s"\n\t% [right]\n)\n'
		self.assertEqual(self.canonical(source), expected)
		self.assertEqual(readability.audit_source('addons/gf/f.gd', expected), [])


if __name__ == "__main__":
	unittest.main()
