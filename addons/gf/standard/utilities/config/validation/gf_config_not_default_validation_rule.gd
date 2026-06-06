## GFConfigNotDefaultValidationRule: 非默认值校验规则。
##
## 用于要求字段显式填写有效值。默认值可以按类型推导，也可以由项目指定。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigNotDefaultValidationRule
extends GFConfigValidationRule


# --- 导出变量 ---

## 是否按输入值类型推导默认值。
## [br]
## @api public
@export var use_type_default: bool = true

## use_type_default 为 false 时使用的默认值。
## [br]
## @api public
## [br]
## @schema default_value: Variant，use_type_default 为 false 时被当前规则拒绝的显式默认值。
@export var default_value: Variant = null


# --- Godot 生命周期方法 ---

func _init() -> void:
	allow_null = false


# --- 公共方法 ---

## 导出规则摘要。
## [br]
## @api public
## [br]
## @return 规则摘要字典。
## [br]
## @schema return: Dictionary，包含基础规则字段、use_type_default 和 default_value。
func describe() -> Dictionary:
	var result: Dictionary = super.describe()
	result["use_type_default"] = use_type_default
	result["default_value"] = GFVariantData.duplicate_variant(default_value)
	return result


# --- 可重写钩子 / 虚方法 ---

## 返回非默认值规则的默认稳定标识。
## [br]
## @api protected
## [br]
## @return 默认规则标识。
func _get_default_rule_id() -> StringName:
	return &"not_default"


## 校验单个字段值是否不同于推导或显式默认值。
## [br]
## @api protected
## [br]
## @param value: 待校验值。
## [br]
## @param context: 校验上下文。
## [br]
## @param report: 当前校验报告。
## [br]
## @schema value: Variant，与推导默认值或显式默认值比较的字段值。
## [br]
## @schema context: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
## [br]
## @schema report: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
	var compared_default: Variant = _get_type_default(value) if use_type_default else default_value
	if _make_variant_key(value) == _make_variant_key(compared_default):
		_add_issue(report, _make_issue_context(context, value, compared_default), "default_value_not_allowed", "值不能等于默认值。")


# --- 私有/辅助方法 ---

func _get_type_default(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL:
			return false
		TYPE_INT:
			return 0
		TYPE_FLOAT:
			return 0.0
		TYPE_STRING:
			return ""
		TYPE_STRING_NAME:
			return &""
		TYPE_ARRAY:
			return []
		TYPE_DICTIONARY:
			return {}
		TYPE_VECTOR2:
			return Vector2.ZERO
		TYPE_VECTOR2I:
			return Vector2i.ZERO
		TYPE_VECTOR3:
			return Vector3.ZERO
		TYPE_VECTOR3I:
			return Vector3i.ZERO
		TYPE_COLOR:
			return Color()
		_:
			return null


func _make_issue_context(context: Dictionary, value: Variant, compared_default: Variant) -> Dictionary:
	var issue_context: Dictionary = context.duplicate(true)
	issue_context["value"] = GFVariantData.duplicate_variant(value)
	issue_context["actual_value"] = GFVariantData.duplicate_variant(value)
	issue_context["expected_value"] = "not %s" % var_to_str(compared_default)
	return issue_context
