extends GutTest


# --- 常量 ---

## 分析源码文本，不加载夹具脚本。
## [br]
## @api private
const _SOURCE_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_source.gd")

## 只读布局检查入口。
## [br]
## @api private
const _LAYOUT_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_layout.gd")


# --- 公共方法 ---

func test_source_keeps_unicode_coordinates_literal_payloads_and_comments() -> void:
	var source: String = "var 名称 = r\"# and ( )\" # only comment\n"
	var view: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", source)
	assert_true(_boolean_field(view, "complete"))
	var tokens: Array[Dictionary] = view["tokens"]
	var comments: Array[Dictionary] = view["comments"]
	var groups: Array[Dictionary] = view["groups"]
	assert_eq(
		_text_field(
			tokens[1],
			"text"
		),
		"名称"
	)
	assert_eq(
		_integer_field(
			tokens[1],
			"column"
		),
		5
	)
	assert_eq(
		_integer_field(
			tokens[1],
			"end_column"
		),
		7
	)
	assert_eq(
		_text_field(
			tokens[3],
			"kind"
		),
		"string"
	)
	assert_eq(
		_text_field(
			tokens[3],
			"text"
		),
		"r\"# and ( )\""
	)
	assert_eq(
		comments.size(),
		1
	)
	assert_eq(
		_text_field(
			comments[0],
			"text"
		),
		"# only comment"
	)
	assert_eq(
		groups.size(),
		0
	)
	assert_eq(
		_text_field(view, "source"),
		source
	)


func test_source_rejects_unclosed_literals_mismatched_groups_and_bad_continuations() -> void:
	for source: String in [
		"consume(\n",
		"var text = \"open\n",
		"consume([)]\n",
		"var x = 1 \\\n",
	]:
		var view: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", source)
		var diagnostics: Array = view["diagnostics"]
		assert_false(
			_boolean_field(view, "complete"),
			source
		)
		assert_gt(
			diagnostics.size(),
			0
		)
		assert_true(_rules(source).has("lexical_closure"))


func test_source_counts_only_direct_items_and_complete_function_signatures() -> void:
	var source: String = "func run(\n\tfirst: Dictionary[String, int],\n\tsecond: int = build(left, right)\n) -> void:\n\tpass\n"
	var view: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", source)
	assert_true(_boolean_field(view, "complete"))
	var groups: Array[Dictionary] = view["groups"]
	var items: Array = groups[0]["items"]
	assert_eq(
		_text_field(
			groups[0],
			"kind"
		),
		"parameters"
	)
	assert_eq(
		items.size(),
		2
	)
	assert_eq(
		_text_field(
			groups[1],
			"kind"
		),
		"type_arguments"
	)
	var statements: Array[Dictionary] = view["statements"]
	assert_eq(
		statements.size(),
		2
	)
	assert_eq(
		_text_field(
			statements[0],
			"kind"
		),
		"func"
	)
	assert_eq(
		_integer_field(
			statements[1],
			"owner_index"
		),
		0
	)
	var tokens: Array[Dictionary] = view["tokens"]
	assert_eq(
		_text_field(
			tokens[
				_integer_field(
					statements[0],
					"header_end_index"
				) - 1
			],
			"text"
		),
		":"
	)


func test_two_atomic_items_inline_and_three_expand_without_a_column_limit() -> void:
	assert_false(_rules("consume(left, right)\n").has("list_layout"))
	assert_true(_rules("consume(left, right, third)\n").has("list_layout"))
	assert_false(_rules("consume(\n\tleft,\n\tright,\n\tthird\n)\n").has("list_layout"))
	assert_true(_rules("consume(\n\tleft,\n\tright\n)\n").has("list_layout"))
	var path: String = "path/".repeat(300) + "resource.tres"
	assert_eq(
		_rules("preload(\"" + path + "\")\n"),
		[]
	)
	assert_true(
		_rules(
			"consume(left, right)\n",
			{ "max_inline_items": 1 }
		).has("list_layout")
	)


func test_two_complex_call_arguments_expand_but_two_container_items_can_stay_inline() -> void:
	for expression: String in [
		"build(value)",
		"items[index]",
		"left + right",
		"left if ready else right",
		"first and second",
	]:
		assert_true(
			_rules("consume(" + expression + ", other)\n").has("list_layout"),
			expression
		)
		assert_false(
			_rules("consume(\n\t" + expression + ",\n\tother\n)\n").has("list_layout"),
			expression
		)
	assert_false(_rules("var values = [build(value), items[index]]\n").has("list_layout"))
	assert_false(_rules("var values = [left, right]\n").has("list_layout"))
	assert_true(_rules("var values = [left, right, third]\n").has("list_layout"))


func test_nested_child_structure_expands_its_parent_without_counting_grandchildren() -> void:
	assert_true(_rules("outer(inner(left, right, third))\n").has("list_layout"))
	assert_false(_rules("outer(inner(left, right))\n").has("list_layout"))
	assert_true(_rules("var values = [[value]]\n").has("list_layout"))
	assert_false(_rules("var values = [[],]\n").has("list_layout"))


func test_dictionary_header_stays_with_value_start_and_multiline_tail_keeps_comma() -> void:
	var broken: String = "var values = {\n\t\"key\":\n\tbuild(\n\t\tleft,\n\t\tright,\n\t\tthird\n\t),\n}\n"
	assert_true(_rules(broken).has("dictionary_entry_layout"))
	var valid: String = "var values = {\n\t\"key\": build(\n\t\tleft,\n\t\tright,\n\t\tthird\n\t),\n}\n"
	assert_false(_rules(valid).has("dictionary_entry_layout"))
	assert_false(_rules(valid).has("list_layout"))
	assert_true(_rules("var values = [\n\tleft,\n\tright,\n\tthird\n]\n").has("trailing_comma"))


func test_three_boolean_terms_expand_in_headers_assignments_and_call_arguments() -> void:
	assert_true(_rules("if first and second or third:\n\tpass\n").has("condition_layout"))
	assert_true(_rules("var ready = first and second and third\n").has("condition_layout"))
	assert_true(_rules("consume(first and second and third)\n").has("condition_layout"))
	assert_false(_rules("if (\n\tfirst\n\tand second\n\tor third\n):\n\tpass\n").has("condition_layout"))
	assert_false(_rules("if first and second:\n\tpass\n").has("condition_layout"))


func test_keyword_members_and_node_paths_do_not_create_boolean_operators() -> void:
	for source: String in [
		"consume(state.and, state.or)\n",
		"consume($Parent/and, %or)\n",
		"var value = $Parent/func/return\n",
		"var value = %Parent/if/else\n",
	]:
		assert_false(
			_rules(source).has("condition_layout"),
			source
		)
		assert_false(
			_rules(source).has("nested_ternary"),
			source
		)
		assert_false(
			_rules(source).has("token_spacing"),
			source
		)


func test_flat_string_addition_and_scalar_format_have_one_complete_line() -> void:
	assert_true(_rules("consume(\n\t\"first\"\n\t+ value\n)\n").has("simple_string_layout"))
	assert_false(_rules("consume(\"first\" + value)\n").has("simple_string_layout"))
	assert_true(_rules("consume(\n\t\"value=%s\"\n\t% value\n)\n").has("simple_format_layout"))
	assert_false(_rules("consume(\"value=%s\" % value)\n").has("simple_format_layout"))
	assert_true(_rules("consume(\"value=%s\" % [value])\n").has("format_layout"))


func test_comments_and_multiline_string_payloads_are_not_layout_code() -> void:
	var source: String = "func run() -> void:\n\tvar text = \"\"\"if one and two and three: run(a,b,c)\n  \"key\":\nvalue\n\"\"\"\n\tconsume(\n\t\t# Keep this argument binding.\n\t\tvalue\n\t)\n"
	var rules: Array[String] = _rules(source)
	assert_false(rules.has("condition_layout"))
	assert_false(rules.has("statement_separator"))
	assert_false(rules.has("dictionary_entry_layout"))
	assert_false(rules.has("text_format"))
	assert_false(rules.has("list_layout"))


func test_multiline_strings_keep_payload_whitespace_but_check_structural_suffixes() -> void:
	for delimiter: String in ["\"\"\"", "'''"]:
		var source: String = "var text = " + delimiter + "first\n  middle \t\n  last" + delimiter
		assert_false(_rules(source + "\n").has("text_format"))
		assert_false(_rules(source.replace("first\n", "first \t\n") + "\n").has("text_format"))
		assert_true(_rules(source + " \t\n").has("text_format"))
		assert_true(_rules(source + " + suffix \t\n").has("text_format"))
		assert_false(_rules(source + " + " + delimiter + "next \t\nlast" + delimiter + "\n").has("text_format"))
		assert_true(_rules("  " + source + "\n").has("text_format"))
	var view: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", "var text = \"\"\"first\n  last\"\"\" \t\n")
	var diagnostics: Array[Dictionary] = _LAYOUT_SCRIPT.analyze(view)
	assert_eq(
		diagnostics.size(),
		1
	)
	if diagnostics.size() != 1:
		return
	assert_eq(
		_text_field(
			diagnostics[0],
			"rule"
		),
		"text_format"
	)
	assert_eq(
		_integer_field(
			diagnostics[0],
			"line"
		),
		2
	)
	assert_eq(
		_integer_field(
			diagnostics[0],
			"column"
		),
		11
	)


func test_redundant_multiline_argument_wrapper_and_detached_cast_are_reported() -> void:
	assert_true(_rules("consume(\n\t(\n\t\tbuild(left, right, third)\n\t)\n)\n").has("argument_group_layout"))
	assert_true(_rules("var value = (\n\tbuild(value)\n)\nas Result\n").has("cast_layout"))
	assert_false(_rules("var value = build(\n\tfirst,\n\tsecond,\n\tthird\n) as Result\n").has("cast_layout"))


func test_suite_indentation_and_inline_bodies_are_checked_from_block_ownership() -> void:
	assert_true(_rules("func run() -> void:\n\t\tconsume(value)\n").has("suite_indentation"))
	assert_false(_rules("func run() -> void:\n\tif ready:\n\t\tconsume(value)\n").has("suite_indentation"))
	assert_true(_rules("func run() -> void: consume(value)\n").has("inline_body"))
	assert_true(_rules("first(); second()\n").has("statement_separator"))


func test_sections_and_adjacent_definitions_require_two_blank_lines() -> void:
	assert_true(_rules("extends RefCounted\n\n# --- 常量 ---\n\nconst VALUE = 1\n").has("section_spacing"))
	assert_false(_rules("extends RefCounted\n\n\n# --- 常量 ---\n\nconst VALUE = 1\n").has("section_spacing"))
	assert_true(_rules("func first() -> void:\n\tpass\n\nfunc second() -> void:\n\tpass\n").has("definition_spacing"))
	assert_false(_rules("func first() -> void:\n\tpass\n\n\nfunc second() -> void:\n\tpass\n").has("definition_spacing"))


func test_readonly_analysis_keeps_input_view_unchanged_and_is_deterministic() -> void:
	var view: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", "consume(first, second, third)\n")
	var before: Dictionary = view.duplicate(true)
	var first: Array[Dictionary] = _LAYOUT_SCRIPT.analyze(view)
	var second: Array[Dictionary] = _LAYOUT_SCRIPT.analyze(view)
	assert_eq(first, second)
	assert_eq(view, before)
	assert_gt(
		first.size(),
		0
	)


func test_keyword_node_receivers_keep_index_and_member_call_roles() -> void:
	for source: String in [
		"return $and[\n\ta\n\tor b\n\tor c\n]\n",
		"if $Node / or / and and ready:\n\tpass\n",
		"return $Parent/%Child\n",
		"return $%\"Unique\"\n",
		"return prefix if owner.func else (\n\t\"%s\"\n\t% [value]\n)\n",
	]:
		assert_eq(
			_rules(source),
			[],
			source
		)


func test_boolean_groups_and_conditional_slots_keep_their_independent_layers() -> void:
	assert_eq(
		_rules("return (\n\ta\n\tand (\n\t\tb\n\t\tor c\n\t)\n)\n"),
		[]
	)
	assert_eq(
		_rules("var values = { $Parent/if if first else $Other/if: $Left/if if second else $Right/if }\n"),
		[]
	)
	assert_eq(
		_rules("return (\n\ta\n\tif first\n\telse (\n\t\tb\n\t\tif second\n\t\telse c\n\t)\n)\n"),
		[]
	)
	assert_true(_rules("return a if first else (b if second else c)\n").has("nested_ternary"))


func test_named_lambda_bodies_reset_expression_ownership_after_nested_calls() -> void:
	var clean: String = "changed.connect(\n\tfunc outer_trace(value: int) -> Array[int]:\n\t\tvar callback = make_callback(\n\t\t\tfunc inner_trace() -> Array[int]:\n\t\t\t\treturn build_array(value, count)\n\t\t)\n\t\treturn invoke_callback(callback, value)\n)\n"
	assert_eq(
		_rules(clean),
		[]
	)
	var wrapped: String = clean.replace("return invoke_callback(callback, value)", "return (invoke_callback(callback, value))")
	assert_true(_rules(wrapped).has("call_group_layout"))
	assert_eq(
		_rules("outer(\n\tinner(\n\t\tfunc() -> void:\n\t\t\trecord(),\n\t\t42\n\t)\n)\n"),
		[]
	)


func test_grouped_lambda_owns_body_statements_at_its_physical_indentation() -> void:
	var source: String = "func run() -> void:\n\tvar callback = (\n\t\tfunc(\n\t\t\tfirst: int,\n\t\t\tsecond: int,\n\t\t\tthird: int\n\t\t) -> void:\n\t\tif replaced[0]:\n\t\t\treturn\n\t\treplaced[0] = true\n\t)\n\tafter()\n"
	var view: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", source)
	assert_true(_boolean_field(view, "complete"))
	var tokens: Array[Dictionary] = view["tokens"]
	var statements: Array[Dictionary] = view["statements"]
	var by_first: Dictionary = {}
	for index: int in statements.size():
		var opening: int = _integer_field(
			statements[index],
			"start_index"
		)
		var text: String = _text_field(
			tokens[opening],
			"text"
		)
		by_first[text] = index
	for required: String in [
		"if",
		"return",
		"replaced",
		"after",
	]:
		assert_true(
			by_first.has(required),
			required
		)
		if not by_first.has(required):
			return
	var conditional: Dictionary = statements[_integer_field(by_first, "if")]
	var lambda_index: int = _integer_field(conditional, "owner_index")
	assert_gte(lambda_index, 0)
	if lambda_index < 0:
		return
	assert_eq(
		_text_field(
			statements[lambda_index],
			"kind"
		),
		"lambda"
	)
	assert_eq(
		_integer_field(
			statements[lambda_index],
			"indent"
		),
		1
	)
	assert_eq(
		_integer_field(
			statements[_integer_field(by_first, "return")],
			"owner_index"
		),
		_integer_field(by_first, "if")
	)
	assert_eq(
		_integer_field(
			statements[_integer_field(by_first, "replaced")],
			"owner_index"
		),
		lambda_index
	)
	assert_eq(
		_integer_field(
			statements[_integer_field(by_first, "after")],
			"owner_index"
		),
		0
	)
	assert_false(_rules(source).has("expression_layout"))


func test_sibling_lambda_bodies_end_at_their_own_direct_container_items() -> void:
	var source: String = "var callbacks: Array[Callable] = [\n\tfunc() -> int:\n\t\treturn 1,\n\tCallable(),\n\tfunc() -> int:\n\t\treturn 2,\n]\n"
	var view: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", source)
	assert_true(_boolean_field(view, "complete"))
	var tokens: Array[Dictionary] = view["tokens"]
	var statements: Array[Dictionary] = view["statements"]
	var returns: Array[Dictionary] = []
	for statement: Dictionary in statements:
		var start: int = _integer_field(statement, "start_index")
		if _text_field(
			tokens[start],
			"text"
		) == "return":
			returns.append(statement)
	assert_eq(
		returns.size(),
		2
	)
	for index: int in returns.size():
		var statement: Dictionary = returns[index]
		var ending: int = _integer_field(statement, "end_index")
		assert_eq(
			_text_field(
				tokens[ending],
				"text"
			),
			","
		)
		assert_eq(
			_text_field(
				tokens[ending - 1],
				"text"
			),
			str(index + 1)
		)
		var owner_index: int = _integer_field(statement, "owner_index")
		assert_eq(
			_text_field(
				statements[owner_index],
				"kind"
			),
			"lambda"
		)


func test_nested_lambda_argument_terminator_is_required_only_with_a_live_outer_expression() -> void:
	var nested: String = "outer(\n\tinner(\n\t\tfunc() -> void:\n\t\t\trecord()\n\t)\n)\n"
	assert_true(_rules(nested).has("lambda_argument_separator"))
	assert_eq(
		_rules(nested.replace("record()", "record(),")),
		[]
	)
	assert_eq(
		_rules("outer(\n\tfunc() -> void:\n\t\tinner(\n\t\t\tfunc() -> void:\n\t\t\t\trecord()\n\t\t)\n)\n"),
		[]
	)


func test_all_complete_call_values_reject_redundant_wrappers_including_keyword_members() -> void:
	for source: String in [
		"self.records = (store.get_records(context, key))\n",
		"records[key] = (make(left, right))\n",
		"return ((make(left, right)) as Result)\n",
		"var value = (owner.or(value))\n",
	]:
		var rules: Array[String] = _rules(source)
		assert_true(
			rules.has("call_group_layout") or rules.has("cast_layout"),
			source
		)
	assert_eq(
		_rules("return (make(left, right) < (other(left, right)))\n"),
		[]
	)


func test_array_formatting_accepts_call_templates_and_checks_operator_indentation() -> void:
	for template: String in [
		"factory()",
		"$Parent/Child.get_template()",
		"$\"Parent/Child\".get_template()",
		"%Unique.get_template()",
	]:
		assert_eq(
			_rules("warn(\n\t" + template + "\n\t% [value]\n)\n"),
			[],
			template
		)
		assert_true(
			_rules("warn(" + template + " % [value])\n").has("format_layout"),
			template
		)
		assert_true(
			_rules("warn(\n\t" + template + "\n\t\t% [value]\n)\n").has("format_layout"),
			template
		)
	assert_eq(
		_rules("var result = a + template % [value]\n"),
		[]
	)


func test_typed_loop_headers_match_guards_and_inline_lambda_bodies_have_real_colon_owners() -> void:
	assert_eq(
		_rules("for record: Dictionary in records:\n\tpass\n"),
		[]
	)
	assert_true(_rules("match value:\n\tvar item when first or second or third:\n\t\tpass\n").has("condition_layout"))
	assert_true(_rules("match value:\n\tvar item: use(item)\n").has("inline_body"))
	assert_true(_rules("call(\n\tfunc() -> Array[\n\t\tString\n\t]: return []\n)\n").has("inline_body"))


func test_only_member_sections_and_complete_decorated_definitions_get_blank_line_rules() -> void:
	assert_eq(
		_rules("func run() -> void:\n\t# --- Body phase ---\n\tpass\n"),
		[]
	)
	assert_eq(
		_rules("call(\n\t# --- Argument notes ---\n)\n"),
		[]
	)
	assert_eq(
		_rules("func first() -> void:\n\tpass\n\n\n## Second.\n@warning_ignore(\"unused_parameter\")\nfunc second(value: int) -> void:\n\tpass\n"),
		[]
	)
	assert_true(_rules("class Fixture:\n\tfunc first() -> void:\n\t\tpass\n\tfunc second() -> void:\n\t\tpass\n").has("definition_spacing"))


func test_comment_and_continuation_barriers_preserve_spelling_while_structural_errors_still_fail() -> void:
	assert_eq(
		_rules("var value = (\n\tmake(a, b) # Context belongs to the operand.\n\tas RefCounted\n)\n"),
		[]
	)
	assert_eq(
		_rules("return first \\\n\t+ second\n"),
		[]
	)
	assert_true(_rules("return first and second \\\n\tand third\n").has("condition_layout"))
	assert_true(_rules("run(\n\tleft, # First argument.\n\tright)\n").has("closing_delimiter"))
	assert_eq(
		_rules("consume({ \"left\": left, \"right\": right, })\n"),
		[]
	)


func test_unicode_combining_identifiers_and_bounded_group_depth_are_explicit() -> void:
	var view: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", "var 名称́ = 1\n")
	var tokens: Array[Dictionary] = view["tokens"]
	assert_eq(
		_text_field(
			tokens[1],
			"kind"
		),
		"name"
	)
	assert_eq(
		_text_field(
			tokens[1],
			"text"
		),
		"名称́"
	)
	var nested: String = "(".repeat(129) + "value" + ")".repeat(129) + "\n"
	var limited: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", nested)
	assert_false(_boolean_field(limited, "complete"))
	assert_true(_rules(nested).has("source_budget"))


# --- 私有/辅助方法 ---

## 通过只读入口收集规则 ID，断言真实排版结果而非实现函数文本。
## [br]
## @api private
func _rules(source: String, options: Dictionary = {}) -> Array[String]:
	var view: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", source)
	var result: Array[String] = []
	for diagnostic: Dictionary in _LAYOUT_SCRIPT.analyze(view, options):
		var rule: String = diagnostic["rule"]
		if not result.has(rule):
			result.append(rule)
	return result


## 断言文本字段的实际类型，避免把错误类型转换后当作正确产物。
## [br]
## @api private
func _text_field(record: Dictionary, key: String) -> String:
	var value: Variant = record.get(key)
	if value is String:
		var text: String = value
		return text
	fail_test("Expected a String field: " + key)
	return ""


## 索引与位置必须保持整数类型，测试读取不接受隐式数值转换。
## [br]
## @api private
func _integer_field(record: Dictionary, key: String) -> int:
	var value: Variant = record.get(key)
	if value is int:
		var integer: int = value
		return integer
	fail_test("Expected an int field: " + key)
	return 0


## 完整性标志必须是布尔值，缺失或错型也记录一次明确失败。
## [br]
## @api private
func _boolean_field(record: Dictionary, key: String) -> bool:
	var value: Variant = record.get(key)
	if value is bool:
		var boolean: bool = value
		return boolean
	fail_test("Expected a bool field: " + key)
	return false
