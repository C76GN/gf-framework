## GFConfigRegexValidationRule: 字符串正则校验规则。
##
## 用于检查字符串字段是否匹配给定表达式，可选择部分匹配或完整匹配。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigRegexValidationRule
extends GFConfigValidationRule


# --- 导出变量 ---

## 正则表达式。
## [br]
## @api public
@export var pattern: String = ""

## 是否要求整个字符串都匹配。
## [br]
## @api public
@export var require_full_match: bool = false

## 空字符串是否直接视为通过。
## [br]
## @api public
@export var allow_empty: bool = true


# --- 私有变量 ---

var _compiled_pattern: String = ""
var _compiled_regex: RegEx = null
var _compile_error: Error = OK
var _has_compiled_pattern: bool = false


# --- 公共方法 ---

## 导出规则摘要。
## [br]
## @api public
## [br]
## @return 规则摘要字典。
## [br]
## @schema return: Dictionary，包含基础规则字段、pattern、require_full_match 和 allow_empty。
func describe() -> Dictionary:
	var result: Dictionary = super.describe()
	result["pattern"] = pattern
	result["require_full_match"] = require_full_match
	result["allow_empty"] = allow_empty
	return result


# --- 可重写钩子 / 虚方法 ---

## 返回正则规则的默认稳定标识。
## [br]
## @api protected
## [br]
## @return 默认规则标识。
func _get_default_rule_id() -> StringName:
	return &"regex"


## 校验单个字符串值是否匹配正则表达式。
## [br]
## @api protected
## [br]
## @param value: 待校验值。
## [br]
## @param context: 校验上下文。
## [br]
## @param report: 当前校验报告。
## [br]
## @schema value: Variant，期望为 String 或 StringName。
## [br]
## @schema context: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
## [br]
## @schema report: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		_add_issue(report, _make_issue_context(context, value, "String or StringName"), "regex_invalid_type", "正则校验只支持 String 或 StringName。")
		return

	var text: String = GFVariantData.to_text(value)
	if text.is_empty() and allow_empty:
		return
	if pattern.is_empty():
		_add_issue(report, _make_issue_context(context, value, "non_empty_pattern"), "regex_empty_pattern", "正则表达式为空。")
		return

	var regex: RegEx = _get_compiled_regex()
	if regex == null:
		_add_issue(report, _make_issue_context(context, value, pattern), "regex_compile_failed", "正则表达式无法编译：%s。" % error_string(_compile_error))
		return

	var matched: RegExMatch = regex.search(text)
	if matched == null:
		_add_issue(report, _make_issue_context(context, value, pattern), "regex_mismatch", "字符串不符合正则表达式。")
		return
	if require_full_match and (matched.get_start() != 0 or matched.get_end() != text.length()):
		_add_issue(report, _make_issue_context(context, value, pattern), "regex_mismatch", "字符串不完整匹配正则表达式。")


# --- 私有/辅助方法 ---

func _get_compiled_regex() -> RegEx:
	if _has_compiled_pattern and _compiled_pattern == pattern:
		return _compiled_regex

	_has_compiled_pattern = true
	_compiled_pattern = pattern
	_compiled_regex = RegEx.new()
	_compile_error = _compiled_regex.compile(pattern)
	if _compile_error != OK:
		_compiled_regex = null
	return _compiled_regex


func _make_issue_context(context: Dictionary, value: Variant, expected_value: Variant) -> Dictionary:
	var issue_context: Dictionary = context.duplicate(true)
	issue_context["value"] = GFVariantData.duplicate_variant(value)
	issue_context["actual_value"] = GFVariantData.duplicate_variant(value)
	issue_context["expected_value"] = GFVariantData.duplicate_variant(expected_value)
	if not pattern.is_empty():
		issue_context["supported_formats"] = [pattern]
	return issue_context
