extends GutTest


# --- 常量 ---

const _SOURCE_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_source.gd")
const _DOCS_SCRIPT = preload("res://addons/gf/tools/code_quality/internal/gf_code_quality_docs.gd")


# --- 测试用例 ---

func test_plain_game_documentation_does_not_require_gf_metadata() -> void:
	var source: String = """## Coordinates a moving actor.
class_name Actor
extends Node

## Moves toward the requested point.
## @param target: Destination in local coordinates.
## @param options: Optional movement settings.
## @return Whether the actor reached the point.
func move_to(
	target: Vector2,
	options: Dictionary = { "points": [1, 2], "label": "x,y" }
) -> bool:
	var local_value: int = 1
	return target == Vector2.ZERO and not options.is_empty() and local_value > 0
"""
	assert_eq(
		_analyze(source),
		[]
	)


func test_public_members_and_class_need_their_own_summaries() -> void:
	var source: String = """class_name Undocumented
extends RefCounted
const LIMIT: int = 4
var speed: float = 1.0
signal changed
enum State {
	IDLE,
	RUNNING,
}
func start() -> void:
	pass
"""
	assert_eq(
		_count(
			_analyze(source),
			"doc_public_summary"
		),
		8
	)


func test_private_members_and_callbacks_need_summary_but_not_local_variables() -> void:
	var source: String = """extends Node
var _cached: int = 0
func _ready() -> void:
	var local_value: int = 1
	_cached = local_value
"""
	var findings: Array[Dictionary] = _analyze(source)
	assert_eq(
		_count(findings, "doc_private_summary"),
		2
	)
	assert_eq(
		_count(findings, "doc_public_summary"),
		0
	)


func test_private_parameters_allow_an_ordered_subset_and_optional_return() -> void:
	var source: String = """extends RefCounted
## Calculates a bounded total.
## @param second: Additional amount.
func _total(first: int, second: int) -> int:
	return first + second
"""
	assert_eq(
		_analyze(source),
		[]
	)


func test_present_private_parameter_tags_must_be_real_ordered_unique_and_described() -> void:
	for documentation: String in [
		"## @param second: Additional amount.\n## @param first: Initial amount.",
		"## @param absent: Unknown argument.",
		"## @param first: Initial amount.\n## @param first: Repeated.",
		"## @param first:",
	]:
		var source: String = "extends RefCounted\n## Calculates a total.\n%s\nfunc _total(first: int, second: int) -> int:\n\treturn first + second\n" % documentation
		assert_gt(
			_count(
				_analyze(source),
				"doc_parameters"
			),
			0
		)


func test_public_signature_requires_all_parameter_descriptions() -> void:
	var source: String = """extends RefCounted
## Combines two amounts.
## @param first: Initial amount.
func combine(first: int, second: int) -> void:
	pass
"""
	assert_eq(
		_count(
			_analyze(source),
			"doc_parameters"
		),
		1
	)


func test_typed_and_inferred_public_value_returns_need_description() -> void:
	for signature: String in ["func value() -> int:", "func value():"]:
		var source: String = "extends RefCounted\n## Produces the current value.\n%s\n\treturn 7\n" % signature
		assert_eq(
			_count(
				_analyze(source),
				"doc_return"
			),
			1
		)


func test_inline_inferred_value_return_needs_description() -> void:
	var source: String = "extends RefCounted\n## Produces the current value.\nfunc value(): return 7\n"
	assert_eq(
		_count(
			_analyze(source),
			"doc_return"
		),
		1
	)


func test_method_returning_a_lambda_still_needs_a_return_description() -> void:
	for body: String in [" return func(): return 3\n", "\n\treturn func(): return 3\n"]:
		var source: String = "extends RefCounted\n## Produces a deferred value.\nfunc callback():" + body
		assert_eq(
			_count(
				_analyze(source),
				"doc_return"
			),
			1
		)


func test_inline_bare_return_does_not_inherit_the_next_statement_as_a_value() -> void:
	for ending: String in ["\n", "; var local = 1\n"]:
		var source: String = "extends RefCounted\n## Stops processing.\nfunc stop(): return" + ending
		assert_eq(
			_analyze(source),
			[]
		)


func test_void_and_duplicate_return_tags_are_rejected() -> void:
	var void_source: String = """extends RefCounted
## Clears current state.
## @return Nothing.
func clear() -> void:
	pass
"""
	assert_eq(
		_count(
			_analyze(void_source),
			"doc_return"
		),
		1
	)
	var duplicate_source: String = """extends RefCounted
## Produces a count.
## @return Count.
## @return Another count.
func count() -> int:
	return 1
"""
	assert_eq(
		_count(
			_analyze(duplicate_source),
			"doc_return"
		),
		1
	)


func test_native_callback_describes_responsibility_without_repeating_native_parameters() -> void:
	var source: String = """extends Node
## Advances the displayed position each frame.
## @api public
func _process(delta: float) -> void:
	position_for_test(delta)

## Supplies optional dynamic properties.
func _get(property: StringName) -> Variant:
	return null

## Consumes the elapsed amount internally.
func position_for_test(_delta: float) -> void:
	pass
"""
	# The ordinary public helper still needs its parameter; native callbacks do not.
	assert_eq(
		_count(
			_analyze(source),
			"doc_parameters"
		),
		1
	)
	assert_eq(
		_count(
			_analyze(source),
			"doc_return"
		),
		0
	)
	assert_eq(
		_count(
			_analyze(source),
			"doc_private_summary"
		),
		0
	)


func test_documentation_remains_bound_across_multiline_annotations() -> void:
	var source: String = """extends Node
## Maximum allowed travel speed.
@export_range(
	0.0,
	20.0
)
var speed: float = 1.0

## Initial travel offset.
@export var offset: float = 0.0

## Restarts the actor state.
@rpc(
	"any_peer",
	"call_local"
)
func restart() -> void:
	pass
"""
	assert_eq(
		_analyze(source),
		[]
	)


func test_file_and_inspector_metadata_do_not_hide_a_members_own_documentation() -> void:
	var source: String = """@tool

## Coordinates an editor actor.
class_name EditorActor
extends Node

@export_group("Movement")

## Initial travel speed.
@export var speed: float = 1.0

@export_subgroup("Bounds")
## Maximum allowed travel speed.
@export_range(
	0.0,
	20.0
)
var maximum: float = 20.0
"""
	assert_eq(
		_analyze(source),
		[]
	)


func test_metadata_and_detached_annotations_cannot_donate_documentation_to_a_member() -> void:
	for prefix: String in [
		"## Configures this editor script.\n@tool\n",
		"## Groups inspector fields.\n@export_group(\"Movement\")\n",
		"## Describes a detached annotation.\n@export_range(0.0, 20.0)\n\n",
	]:
		var source: String = prefix + "var speed: float = 1.0\n"
		assert_eq(
			_count(
				_analyze(source),
				"doc_public_summary"
			),
			1
		)


func test_classless_plain_file_comment_is_not_a_phantom_class_declaration() -> void:
	var source: String = """# Keeps local state without exposing a global type.
extends RefCounted
## Stores the current state.
var _state: int = 0
"""
	assert_eq(
		_analyze(source),
		[]
	)


func test_strings_and_comment_examples_cannot_manufacture_members_or_documentation() -> void:
	var source: String = "extends RefCounted\n## Stores an example payload.\nconst SAMPLE: String = \"\"\"\n## Fake summary.\nfunc fake(argument):\n\treturn 1\n\"\"\"\n# ## Not declaration documentation.\nfunc real() -> void:\n\tpass\n"
	var findings: Array[Dictionary] = _analyze(source)
	assert_eq(
		_count(findings, "doc_public_summary"),
		1
	)
	assert_eq(
		_count(findings, "doc_parameters"),
		0
	)


func test_blank_line_prevents_a_stale_doc_block_from_binding() -> void:
	var source: String = "extends RefCounted\n## Detached description.\n\nvar value: int = 0\n"
	assert_eq(
		_count(
			_analyze(source),
			"doc_public_summary"
		),
		1
	)


func test_inner_class_members_are_checked_while_method_locals_are_ignored() -> void:
	var source: String = """extends RefCounted
## Holds one independent counter.
class Counter:
	## Stores the counter value.
	var _value: int = 0
	## Advances the counter.
	func advance() -> void:
		var increment: int = 1
		_value += increment
"""
	assert_eq(
		_analyze(source),
		[]
	)


func test_enum_item_documentation_does_not_inherit_the_enum_summary() -> void:
	var source: String = """extends RefCounted
## Available execution states.
enum State {
	## Waits for a new request.
	IDLE,
	RUNNING,
}
"""
	assert_eq(
		_count(
			_analyze(source),
			"doc_public_summary"
		),
		1
	)


func test_sections_are_optional_and_do_not_require_gf_lifecycle_sections() -> void:
	var source: String = """extends RefCounted
## Starts the local request.
func start() -> void:
	pass
## Clears the retained state.
func _clear() -> void:
	pass
"""
	assert_eq(
		_count(
			_analyze(source),
			"section_order"
		),
		0
	)


func test_present_sections_reject_regression_and_private_helper_in_public_methods() -> void:
	var source: String = """extends RefCounted
# --- 公共方法 ---
## Releases retained state.
func _clear() -> void:
	pass
# --- 常量 ---
## Maximum pending requests.
const LIMIT: int = 1
"""
	assert_eq(
		_count(
			_analyze(source),
			"section_order"
		),
		2
	)


func test_signal_handlers_follow_helpers_without_becoming_signal_declarations() -> void:
	for heading: String in ["信号处理函数", "信号回调函数"]:
		var source: String = """extends RefCounted
# --- 信号 ---
## Reports a state change.
signal changed
# --- 私有/辅助方法 ---
## Releases retained state.
func _clear() -> void:
	pass
# --- %s ---
## Responds to a state change.
func _on_changed() -> void:
	pass
"""
		source = source % heading
		assert_eq(
			_analyze(source),
			[]
		)


func test_a_trailing_empty_heading_is_optional_but_still_obeys_present_section_order() -> void:
	var source: String = "extends RefCounted\n# --- 私有/辅助方法 ---\n## Releases temporary state.\nfunc _clear() -> void:\n\tpass\n# --- 常量 ---\n"
	assert_eq(
		_count(
			_analyze(source),
			"section_order"
		),
		1
	)


func test_existing_metadata_is_checked_but_missing_metadata_is_allowed() -> void:
	var source: String = """extends RefCounted
## Retains the current request.
## @api private
## @api public
## @since
var _request: Dictionary = {}
"""
	assert_eq(
		_count(
			_analyze(source),
			"doc_tags"
		),
		2
	)
	assert_eq(
		_count(
			_analyze("extends RefCounted\n## Stores a value.\nvar value: int = 1\n"),
			"doc_tags"
		),
		0
	)


func test_multiline_parameter_and_return_descriptions_bind_to_their_tags() -> void:
	var source: String = """extends RefCounted
## Produces a bounded total.
## @param first:
## Initial amount before the adjustment.
## [br]
## @param second:
## Additional amount to include.
## @return
## Combined total after applying both amounts.
func total(first: int, second: int) -> int:
	return first + second
"""
	assert_eq(
		_analyze(source),
		[]
	)


func test_metadata_before_summary_and_unknown_tags_do_not_impose_new_requirements() -> void:
	var source: String = """extends RefCounted
## @api public
## @since next-release
## Stores the current count.
## @author Example team
## @custom
## Additional project-specific information.
var count: int = 0
"""
	assert_eq(
		_analyze(source),
		[]
	)


func test_example_code_does_not_satisfy_empty_parameter_or_return_descriptions() -> void:
	var source: String = """extends RefCounted
## Produces a bounded amount.
## @param amount:
## [codeblock]
## amount = 4
## [/codeblock]
## @return
## ```gdscript
## return 4
## ```
func total(amount: int) -> int:
	return amount
"""
	var findings: Array[Dictionary] = _analyze(source)
	assert_eq(
		_count(findings, "doc_parameters"),
		1
	)
	assert_eq(
		_count(findings, "doc_return"),
		1
	)


func test_lambda_value_return_does_not_become_the_enclosing_method_return() -> void:
	var source: String = """extends RefCounted
## Builds a local callback without returning it.
func prepare() -> void:
	var callback: Callable = func() -> int:
		return 3
	callback.call()
"""
	assert_eq(
		_count(
			_analyze(source),
			"doc_return"
		),
		0
	)
	assert_eq(
		_count(
			_analyze(source),
			"doc_public_summary"
		),
		0
	)


func test_untyped_method_does_not_inherit_inline_or_nested_lambda_returns() -> void:
	for body: String in [
		"\tvar callback = func(): return 3\n\tcallback.call()\n",
		"\tvar callback = func():\n\t\treturn 3\n\tcallback.call()\n",
		"\t[1].map(func(value): return value + 1)\n",
		"\t[1].map(func(value):\n\t\treturn value + 1\n\t)\n",
		"\tvar callback = func():\n\t\tvar nested = func(): return 3\n\t\treturn nested.call()\n",
	]:
		var source: String = "extends RefCounted\n## Prepares local callbacks.\nfunc prepare():\n" + body
		assert_eq(
			_analyze(source),
			[],
			body
		)


func test_inline_lambda_in_an_inline_method_does_not_require_an_outer_return_tag() -> void:
	for body: String in ["var callback = func(): return 3", "[1].map(func(value): return value + 1)"]:
		var source: String = "extends RefCounted\n## Prepares a local callback.\nfunc prepare(): " + body + "\n"
		assert_eq(
			_analyze(source),
			[]
		)


func test_untyped_method_return_after_a_lambda_still_requires_documentation() -> void:
	for body: String in [
		"\tvar callback = func(): return 3\n\treturn callback.call()\n",
		"\tif true:\n\t\treturn 3\n",
		"\tvar initial = 1; return initial\n",
	]:
		var source: String = "extends RefCounted\n## Produces the requested value.\nfunc value():\n" + body
		assert_eq(
			_count(
				_analyze(source),
				"doc_return"
			),
			1,
			body
		)


func test_semicolon_separated_members_are_checked_with_only_documentation_rules() -> void:
	for source: String in ["extends RefCounted\n## Stores the initial amount.\nvar initial = 1; var missing = 2; const LIMIT = 3\n", "extends RefCounted\n## Owns local state.\nclass State:\n\t## Stores the initial amount.\n\tvar initial = 1; var missing = 2; const LIMIT = 3\n"]:
		assert_eq(
			_count(
				_analyze(source),
				"doc_public_summary"
			),
			2
		)


func test_semicolon_separated_locals_are_not_treated_as_members() -> void:
	for body: String in ["\n\tvar initial = 1; var following = 2\n", " var initial = 1; var following = 2\n"]:
		var source: String = "extends RefCounted\n## Prepares local amounts.\nfunc prepare():" + body
		assert_eq(
			_analyze(source),
			[]
		)


func test_space_indented_locals_keep_their_real_function_and_class_scope() -> void:
	for width: int in range(1, 5):
		var prefix: String = " ".repeat(width)
		var source: String = (
			"extends RefCounted\n## Prepares a local value.\nfunc prepare():\n%svar first = 1\n%svar value = first\n"
			% [prefix, prefix]
		)
		assert_eq(
			_analyze(source),
			[],
			"function indentation: %d" % width
		)
		source = (
			"extends RefCounted\n## Owns one counter.\nclass Counter:\n%s## Keeps the current count.\n%svar count = 0\n%s## Prepares local values.\n%sfunc prepare():\n%svar value = 2\n"
			% [
				prefix,
				prefix,
				prefix,
				prefix,
				prefix.repeat(2),
			]
		)
		assert_eq(
			_analyze(source),
			[],
			"inner-class indentation: %d" % width
		)


func test_one_declarations_parameter_findings_respect_rule_selection_and_a_fixed_budget() -> void:
	var source: String = "extends RefCounted\n## Consumes the requested amount.\n"
	for _index: int in range(10_010):
		source += "## @param amount: Requested amount.\n"
	source += "func _consume(amount: int) -> void:\n\tpass\n"
	var view: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", source)
	var complete: bool = view["complete"]
	assert_true(complete)
	for level: String in ["warning", "error"]:
		var findings: Array[Dictionary] = _DOCS_SCRIPT.analyze(
			view,
			{
				"rule_levels": { "doc_parameters": level, "analysis_budget": "off" },
			}
		)
		assert_eq(
			findings.size(),
			10_000
		)
		assert_eq(
			_count(findings, "analysis_budget"),
			1
		)
	assert_eq(
		_DOCS_SCRIPT.analyze(
			view,
			{
				"rule_levels": { "doc_parameters": "off" },
			}
		),
		[]
	)


func test_incomplete_source_view_does_not_produce_speculative_documentation_findings() -> void:
	assert_eq(
		_DOCS_SCRIPT.analyze(
			{ "complete": false },
			{}
		),
		[]
	)
	assert_eq(
		_DOCS_SCRIPT.get_rule_ids().size(),
		6
	)


# --- 私有/辅助方法 ---

func _analyze(source: String) -> Array[Dictionary]:
	var view: Dictionary = _SOURCE_SCRIPT.lex_source("fixture.gd", source)
	var complete: bool = view["complete"]
	assert_true(complete, "文档夹具必须有完整词法模型。")
	return _DOCS_SCRIPT.analyze(view, {})


func _count(findings: Array[Dictionary], rule: String) -> int:
	var count: int = 0
	for finding: Dictionary in findings:
		if finding.get("rule", "") == rule:
			count += 1
	return count
