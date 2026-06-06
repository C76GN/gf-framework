## GFConfigRangeValidationRule: 数值范围校验规则。
##
## 用于声明字段数值上下限。上下限可以单独启用，比较方式可选择是否包含边界。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigRangeValidationRule
extends GFConfigValidationRule


# --- 导出变量 ---

## 是否检查最小值。
## [br]
## @api public
@export var has_minimum: bool = false

## 最小值。
## [br]
## @api public
@export var minimum: float = 0.0

## 最小值是否包含边界。
## [br]
## @api public
@export var inclusive_minimum: bool = true

## 是否检查最大值。
## [br]
## @api public
@export var has_maximum: bool = false

## 最大值。
## [br]
## @api public
@export var maximum: float = 0.0

## 最大值是否包含边界。
## [br]
## @api public
@export var inclusive_maximum: bool = true


# --- 公共方法 ---

## 导出规则摘要。
## [br]
## @api public
## [br]
## @return 规则摘要字典。
## [br]
## @schema return: Dictionary，包含基础规则字段和数值范围设置。
func describe() -> Dictionary:
	var result: Dictionary = super.describe()
	result["has_minimum"] = has_minimum
	result["minimum"] = minimum
	result["inclusive_minimum"] = inclusive_minimum
	result["has_maximum"] = has_maximum
	result["maximum"] = maximum
	result["inclusive_maximum"] = inclusive_maximum
	return result


# --- 可重写钩子 / 虚方法 ---

## 返回数值范围规则的默认稳定标识。
## [br]
## @api protected
## [br]
## @return 默认规则标识。
func _get_default_rule_id() -> StringName:
	return &"range"


## 校验单个数值是否落在允许范围内。
## [br]
## @api protected
## [br]
## @param value: 待校验值。
## [br]
## @param context: 校验上下文。
## [br]
## @param report: 当前校验报告。
## [br]
## @schema value: Variant，期望为 int 或 float。
## [br]
## @schema context: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
## [br]
## @schema report: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		_add_issue(report, _make_issue_context(context, value, "int or float"), "range_invalid_type", "范围校验只支持 int 或 float。")
		return

	var number: float = GFVariantData.to_float(value)
	if is_nan(number) or is_inf(number):
		_add_issue(report, _make_issue_context(context, value, "finite_number"), "range_invalid_number", "数值必须是有限数字。")
		return
	if has_minimum and not _passes_minimum(number):
		_add_issue(report, _make_issue_context(context, value, _describe_range()), "range_below_minimum", "数值小于允许范围。")
	if has_maximum and not _passes_maximum(number):
		_add_issue(report, _make_issue_context(context, value, _describe_range()), "range_above_maximum", "数值大于允许范围。")


# --- 私有/辅助方法 ---

func _passes_minimum(value: float) -> bool:
	return value >= minimum if inclusive_minimum else value > minimum


func _passes_maximum(value: float) -> bool:
	return value <= maximum if inclusive_maximum else value < maximum


func _make_issue_context(context: Dictionary, value: Variant, expected_value: Variant) -> Dictionary:
	var issue_context: Dictionary = context.duplicate(true)
	issue_context["value"] = GFVariantData.duplicate_variant(value)
	issue_context["actual_value"] = GFVariantData.duplicate_variant(value)
	issue_context["expected_value"] = GFVariantData.duplicate_variant(expected_value)
	return issue_context


func _describe_range() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if has_minimum:
		var minimum_prefix: String = ">=" if inclusive_minimum else ">"
		var _minimum_appended: bool = parts.append("%s %s" % [minimum_prefix, str(minimum)])
	if has_maximum:
		var maximum_prefix: String = "<=" if inclusive_maximum else "<"
		var _maximum_appended: bool = parts.append("%s %s" % [maximum_prefix, str(maximum)])
	return " and ".join(parts) if not parts.is_empty() else "number"
