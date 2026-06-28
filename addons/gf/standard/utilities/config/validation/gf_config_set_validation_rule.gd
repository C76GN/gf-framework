## GFConfigSetValidationRule: 值集合校验规则。
##
## 用于限制字段值必须出现在一个显式白名单中，不解释白名单背后的业务含义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigSetValidationRule
extends GFConfigValidationRule


# --- 导出变量 ---

## 允许出现的值列表。
## [br]
## @api public
## [br]
## @schema allowed_values: Array，包含当前规则允许的 Variant 值。
@export var allowed_values: Array = []

## 字符串比较是否区分大小写。
## [br]
## @api public
@export var case_sensitive: bool = true


# --- 私有变量 ---

var _lookup_cache: Dictionary = {}
var _lookup_signature: String = ""


# --- 公共方法 ---

## 导出规则摘要。
## [br]
## @api public
## [br]
## @return 规则摘要字典。
## [br]
## @schema return: Dictionary，包含基础规则字段、allowed_values 和 case_sensitive。
func describe() -> Dictionary:
	var result: Dictionary = super.describe()
	result["allowed_values"] = GFVariantData.duplicate_variant(allowed_values)
	result["case_sensitive"] = case_sensitive
	return result


# --- 可重写钩子 / 虚方法 ---

## 返回集合规则的默认稳定标识。
## [br]
## @api protected
## [br]
## @return 默认规则标识。
func _get_default_rule_id() -> StringName:
	return &"set"


## 校验单个字段值是否属于允许集合。
## [br]
## @api protected
## [br]
## @param value: 待校验值。
## [br]
## @param context: 校验上下文。
## [br]
## @param report: 当前校验报告。
## [br]
## @schema value: Variant，与 allowed_values 比较的字段值。
## [br]
## @schema context: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
## [br]
## @schema report: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
	var lookup: Dictionary = _build_lookup()
	if not lookup.has(_make_comparison_key(value)):
		_add_issue(report, _make_issue_context(context, value), "set_value_not_allowed", "值不在允许集合中。")


# --- 私有/辅助方法 ---

func _build_lookup() -> Dictionary:
	var signature: String = _make_lookup_signature()
	if signature == _lookup_signature:
		return _lookup_cache

	var lookup: Dictionary = {}
	for value: Variant in allowed_values:
		lookup[_make_comparison_key(value)] = true
	_lookup_cache = lookup
	_lookup_signature = signature
	return lookup


func _make_comparison_key(value: Variant) -> String:
	if not case_sensitive and (typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME):
		return "string:%s" % GFVariantData.to_text(value).to_lower()
	return _make_variant_key(value)


func _make_issue_context(context: Dictionary, value: Variant) -> Dictionary:
	var issue_context: Dictionary = context.duplicate(true)
	issue_context["value"] = GFVariantData.duplicate_variant(value)
	issue_context["actual_value"] = GFVariantData.duplicate_variant(value)
	issue_context["supported_values"] = GFVariantData.duplicate_variant(allowed_values)
	return issue_context


func _make_lookup_signature() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var _case_sensitive_appended: bool = parts.append("case:%s" % str(case_sensitive))
	for value: Variant in allowed_values:
		var _value_appended: bool = parts.append(var_to_str(value))
	return "|".join(parts)
