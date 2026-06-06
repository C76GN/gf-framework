## GFConfigSizeValidationRule: 长度或数量校验规则。
##
## 用于校验 String、Array、Dictionary、PackedArray 字段，或整表记录数量。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigSizeValidationRule
extends GFConfigValidationRule


# --- 导出变量 ---

## 是否检查最小数量。
## [br]
## @api public
@export var has_minimum_size: bool = false

## 最小数量。
## [br]
## @api public
@export var minimum_size: int = 0

## 是否检查最大数量。
## [br]
## @api public
@export var has_maximum_size: bool = false

## 最大数量。
## [br]
## @api public
@export var maximum_size: int = 0


# --- 公共方法 ---

## 导出规则摘要。
## [br]
## @api public
## [br]
## @return 规则摘要字典。
## [br]
## @schema return: Dictionary，包含基础规则字段和数量边界设置。
func describe() -> Dictionary:
	var result: Dictionary = super.describe()
	result["has_minimum_size"] = has_minimum_size
	result["minimum_size"] = minimum_size
	result["has_maximum_size"] = has_maximum_size
	result["maximum_size"] = maximum_size
	return result


# --- 可重写钩子 / 虚方法 ---

## 返回数量规则的默认稳定标识。
## [br]
## @api protected
## [br]
## @return 默认规则标识。
func _get_default_rule_id() -> StringName:
	return &"size"


## 校验单个字段值长度或数量。
## [br]
## @api protected
## [br]
## @param value: 待校验值。
## [br]
## @param context: 校验上下文。
## [br]
## @param report: 当前校验报告。
## [br]
## @schema value: Variant，期望为 String、StringName、Array、Dictionary 或 PackedArray。
## [br]
## @schema context: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
## [br]
## @schema report: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
	var size: int = _get_value_size(value)
	if size < 0:
		_add_issue(
			report,
			_make_issue_context(context, value, "String, Array, Dictionary, or PackedArray", -1),
			"size_invalid_type",
			"数量校验只支持 String、Array、Dictionary 或 PackedArray。"
		)
		return
	_validate_size(size, context, report, "size_out_of_range", value)


## 校验整张表的行数。
## [br]
## @api protected
## [br]
## @param rows: 规范化行列表。
## [br]
## @param context: 校验上下文。
## [br]
## @param report: 当前校验报告。
## [br]
## @schema rows: Array[Dictionary]，元素通常包含 row_key、record 和 row_index。
## [br]
## @schema context: Dictionary，可包含 table_name 和 source 字段。
## [br]
## @schema report: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
func _validate_table(rows: Array[Dictionary], context: Dictionary, report: Dictionary) -> void:
	_validate_size(rows.size(), context, report, "table_size_out_of_range", rows)


# --- 私有/辅助方法 ---

func _validate_size(
	size: int,
	context: Dictionary,
	report: Dictionary,
	kind: String,
	value: Variant
) -> void:
	if has_minimum_size and size < minimum_size:
		_add_issue(report, _make_issue_context(context, value, _describe_size_range(), size), kind, "数量小于允许范围。")
	if has_maximum_size and size > maximum_size:
		_add_issue(report, _make_issue_context(context, value, _describe_size_range(), size), kind, "数量大于允许范围。")


func _get_value_size(value: Variant) -> int:
	if value is String or value is StringName:
		return GFVariantData.to_text(value).length()
	if value is Array:
		var array: Array = value
		return array.size()
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.size()
	if value is PackedByteArray:
		var packed_bytes: PackedByteArray = value
		return packed_bytes.size()
	if value is PackedInt32Array:
		var packed_int32: PackedInt32Array = value
		return packed_int32.size()
	if value is PackedInt64Array:
		var packed_int64: PackedInt64Array = value
		return packed_int64.size()
	if value is PackedFloat32Array:
		var packed_float32: PackedFloat32Array = value
		return packed_float32.size()
	if value is PackedFloat64Array:
		var packed_float64: PackedFloat64Array = value
		return packed_float64.size()
	if value is PackedStringArray:
		var packed_strings: PackedStringArray = value
		return packed_strings.size()
	if value is PackedVector2Array:
		var packed_vector2: PackedVector2Array = value
		return packed_vector2.size()
	if value is PackedVector3Array:
		var packed_vector3: PackedVector3Array = value
		return packed_vector3.size()
	if value is PackedColorArray:
		var packed_colors: PackedColorArray = value
		return packed_colors.size()
	return -1


func _make_issue_context(
	context: Dictionary,
	value: Variant,
	expected_value: Variant,
	actual_value: Variant
) -> Dictionary:
	var issue_context: Dictionary = context.duplicate(true)
	issue_context["value"] = GFVariantData.duplicate_variant(value)
	issue_context["expected_value"] = GFVariantData.duplicate_variant(expected_value)
	issue_context["actual_value"] = GFVariantData.duplicate_variant(actual_value)
	return issue_context


func _describe_size_range() -> String:
	var parts: PackedStringArray = PackedStringArray()
	if has_minimum_size:
		var _minimum_appended: bool = parts.append(">= %d" % minimum_size)
	if has_maximum_size:
		var _maximum_appended: bool = parts.append("<= %d" % maximum_size)
	return " and ".join(parts) if not parts.is_empty() else "any_size"
