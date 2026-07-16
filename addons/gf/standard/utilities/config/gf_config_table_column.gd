## GFConfigTableColumn: 导表字段声明。
##
## 只描述字段名、值类型、必填性、空值策略和默认值，不绑定任何具体业务表。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigTableColumn
extends Resource


# --- 枚举 ---

## 导表字段值类型，用于导入与运行时校验。
## [br]
## @api public
enum ValueType {
	## 不做类型约束。
	ANY,
	## 布尔值。
	BOOL,
	## 整数。
	INT,
	## 浮点数。
	FLOAT,
	## 字符串。
	STRING,
	## StringName。
	STRING_NAME,
	## Vector2。
	VECTOR2,
	## Vector2i。
	VECTOR2I,
	## Color。
	COLOR,
	## Dictionary。
	DICTIONARY,
	## Array。
	ARRAY,
}


# --- 导出变量 ---

## 字段名。建议和导表列名保持一致。
## [br]
## @api public
@export var field_name: StringName = &""

## 字段值类型。
## [br]
## @api public
@export var value_type: ValueType = ValueType.ANY

## 是否必须出现在记录中。
## [br]
## @api public
@export var required: bool = false

## 是否允许 null 值。
## [br]
## @api public
@export var allow_null: bool = true

## 字段缺省值。`GFConfigTableSchema.coerce_record()` 会在缺字段时使用。
## [br]
## @api public
## [br]
## @schema default_value: Variant，字段缺失时复制到记录中的默认值。
@export var default_value: Variant = null

## 字段级校验规则。只作用于当前字段值，不绑定具体业务枚举。
## [br]
## @api public
## [br]
## @schema validation_rules: Array，包含作用于当前字段的 GFConfigValidationRule 资源。
@export var validation_rules: Array[GFConfigValidationRule] = []

## 可选元数据，供编辑器、导入器或项目层扩展使用。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存编辑器、导入器或项目层附加到当前字段的元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取稳定字段键。
## [br]
## @api public
## [br]
## @return 字段名。
func get_field_key() -> StringName:
	return field_name


## 将输入值转换为当前列要求的类型。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @return 转换后的值。
## [br]
## @schema value: Variant，按 value_type 转换的输入字段值。
## [br]
## @schema return: Variant，按当前 value_type 转换后的值。
func coerce_value(value: Variant) -> Variant:
	return _coerce_report_value(try_coerce_value(value))


## 尝试将输入值转换为当前列要求的类型，并返回转换报告。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @return 包含 ok、value 与 message 的转换报告。
## [br]
## @schema value: Variant，按 value_type 尝试转换的输入字段值。
## [br]
## @schema return: Dictionary，包含 ok、value 和 message 字段。
func try_coerce_value(value: Variant) -> Dictionary:
	if value == null:
		return _make_coerce_result(true, null)

	match value_type:
		ValueType.BOOL:
			return _try_coerce_bool(value)
		ValueType.INT:
			return _try_coerce_int(value)
		ValueType.FLOAT:
			return _try_coerce_float(value)
		ValueType.STRING:
			return _make_coerce_result(true, str(value))
		ValueType.STRING_NAME:
			return _make_coerce_result(true, StringName(str(value)))
		ValueType.VECTOR2:
			return _try_coerce_vector2(value)
		ValueType.VECTOR2I:
			return _try_coerce_vector2i(value)
		ValueType.COLOR:
			return _try_coerce_color(value)
		ValueType.DICTIONARY:
			if value is Dictionary:
				return _make_coerce_result(true, GFVariantData.duplicate_variant(value))
			return _make_coerce_result(false, {}, "值无法转换为 Dictionary。")
		ValueType.ARRAY:
			if value is Array:
				return _make_coerce_result(true, GFVariantData.duplicate_variant(value))
			return _make_coerce_result(false, [], "值无法转换为 Array。")
		_:
			return _make_coerce_result(true, value)


## 检查输入值是否符合当前列声明。
## [br]
## @api public
## [br]
## @param value: 待检查值。
## [br]
## @return 符合声明时返回 true。
## [br]
## @schema value: Variant，按 value_type 与 allow_null 检查的字段值。
func is_value_valid(value: Variant) -> bool:
	if value == null:
		return allow_null

	match value_type:
		ValueType.ANY:
			return true
		ValueType.BOOL:
			return typeof(value) == TYPE_BOOL
		ValueType.INT:
			return typeof(value) == TYPE_INT
		ValueType.FLOAT:
			return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
		ValueType.STRING:
			return typeof(value) == TYPE_STRING
		ValueType.STRING_NAME:
			return typeof(value) == TYPE_STRING_NAME
		ValueType.VECTOR2:
			return value is Vector2
		ValueType.VECTOR2I:
			return value is Vector2i
		ValueType.COLOR:
			return value is Color
		ValueType.DICTIONARY:
			return value is Dictionary
		ValueType.ARRAY:
			return value is Array
		_:
			return true


## 创建同内容拷贝，避免运行时修改污染共享 Resource。
## [br]
## @api public
## [br]
## @return 新字段声明。
func duplicate_column() -> GFConfigTableColumn:
	var column: GFConfigTableColumn = GFConfigTableColumn.new()
	column.field_name = field_name
	column.value_type = value_type
	column.required = required
	column.allow_null = allow_null
	column.default_value = GFVariantData.duplicate_collection(default_value)
	for rule: GFConfigValidationRule in validation_rules:
		column.validation_rules.append(rule.duplicate_rule() if rule != null else null)
	column.metadata = metadata.duplicate(true)
	return column


## 导出字段声明摘要。
## [br]
## @api public
## [br]
## @return 字段声明字典。
## [br]
## @schema return: Dictionary，包含 field_name、value_type、required、allow_null、default_value、validation_rules 和 metadata。
func describe() -> Dictionary:
	return {
		"field_name": field_name,
		"value_type": value_type,
		"required": required,
		"allow_null": allow_null,
		"default_value": GFVariantData.duplicate_collection(default_value),
		"validation_rules": _describe_validation_rules(),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _coerce_report_ok(report: Dictionary) -> bool:
	return GFVariantData.get_option_bool(report, "ok", false)


func _coerce_report_value(report: Dictionary) -> Variant:
	return GFVariantData.get_option_value(report, "value")


func _coerce_report_float(report: Dictionary) -> float:
	return GFVariantData.get_option_float(report, "value", 0.0)


func _describe_validation_rules() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rule: GFConfigValidationRule in validation_rules:
		if rule != null:
			result.append(rule.describe())
	return result


func _make_coerce_result(ok: bool, coerced_value: Variant, message: String = "") -> Dictionary:
	return {
		"ok": ok,
		"value": coerced_value,
		"message": message,
	}


func _try_coerce_bool(value: Variant) -> Dictionary:
	if value is bool:
		return _make_coerce_result(true, GFVariantData.to_bool(value))
	if value is int or value is float:
		return _make_coerce_result(true, GFVariantData.to_float(value) != 0.0)
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value).strip_edges().to_lower()
		if text in ["true", "1", "yes", "on"]:
			return _make_coerce_result(true, true)
		if text in ["false", "0", "no", "off"]:
			return _make_coerce_result(true, false)
		return _make_coerce_result(false, false, "值无法转换为 bool。")
	return _make_coerce_result(false, GFVariantData.to_bool(value), "值无法转换为 bool。")


func _try_coerce_int(value: Variant) -> Dictionary:
	if value is int or value is bool:
		return _make_coerce_result(true, GFVariantData.to_int(value))
	if value is float:
		var float_value: float = GFVariantData.to_float(value)
		if is_nan(float_value) or is_inf(float_value):
			return _make_coerce_result(false, 0, "值无法转换为 int。")
		return _make_coerce_result(true, int(float_value))
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value).strip_edges()
		if text.is_valid_int():
			return _make_coerce_result(true, text.to_int())
		return _make_coerce_result(false, 0, "值无法转换为 int。")
	return _make_coerce_result(false, GFVariantData.to_int(value), "值无法转换为 int。")


func _try_coerce_float(value: Variant) -> Dictionary:
	if value is float or value is int or value is bool:
		var float_value: float = GFVariantData.to_float(value)
		if is_nan(float_value) or is_inf(float_value):
			return _make_coerce_result(false, 0.0, "值无法转换为 float。")
		return _make_coerce_result(true, float_value)
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value).strip_edges()
		if text.is_valid_float():
			return _make_coerce_result(true, text.to_float())
		return _make_coerce_result(false, 0.0, "值无法转换为 float。")
	return _make_coerce_result(false, GFVariantData.to_float(value), "值无法转换为 float。")


func _try_coerce_vector2(value: Variant) -> Dictionary:
	if value is Vector2 or value is Vector2i:
		return _make_coerce_result(true, _coerce_vector2(value))
	if value is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(value)
		var x: Dictionary = _try_coerce_float(GFVariantData.get_option_value(data, "x"))
		var y: Dictionary = _try_coerce_float(GFVariantData.get_option_value(data, "y"))
		if _coerce_report_ok(x) and _coerce_report_ok(y):
			return _make_coerce_result(true, Vector2(_coerce_report_float(x), _coerce_report_float(y)))
		return _make_coerce_result(false, Vector2.ZERO, "值无法转换为 Vector2。")
	if value is Array:
		var values: Array = GFVariantData.as_array(value)
		if values.size() >= 2:
			var x: Dictionary = _try_coerce_float(values[0])
			var y: Dictionary = _try_coerce_float(values[1])
			if _coerce_report_ok(x) and _coerce_report_ok(y):
				return _make_coerce_result(true, Vector2(_coerce_report_float(x), _coerce_report_float(y)))
	return _make_coerce_result(false, Vector2.ZERO, "值无法转换为 Vector2。")


func _try_coerce_vector2i(value: Variant) -> Dictionary:
	if value is Vector2i or value is Vector2:
		return _make_coerce_result(true, _coerce_vector2i(value))
	if value is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(value)
		var x: Dictionary = _try_coerce_float(GFVariantData.get_option_value(data, "x"))
		var y: Dictionary = _try_coerce_float(GFVariantData.get_option_value(data, "y"))
		if _coerce_report_ok(x) and _coerce_report_ok(y):
			return _make_coerce_result(true, Vector2i(roundi(_coerce_report_float(x)), roundi(_coerce_report_float(y))))
		return _make_coerce_result(false, Vector2i.ZERO, "值无法转换为 Vector2i。")
	if value is Array:
		var values: Array = GFVariantData.as_array(value)
		if values.size() >= 2:
			var x: Dictionary = _try_coerce_float(values[0])
			var y: Dictionary = _try_coerce_float(values[1])
			if _coerce_report_ok(x) and _coerce_report_ok(y):
				return _make_coerce_result(true, Vector2i(roundi(_coerce_report_float(x)), roundi(_coerce_report_float(y))))
	return _make_coerce_result(false, Vector2i.ZERO, "值无法转换为 Vector2i。")


func _try_coerce_color(value: Variant) -> Dictionary:
	if value is Color:
		return _make_coerce_result(true, value)
	if value is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(value)
		var r: Dictionary = _try_coerce_float(GFVariantData.get_option_value(data, "r"))
		var g: Dictionary = _try_coerce_float(GFVariantData.get_option_value(data, "g"))
		var b: Dictionary = _try_coerce_float(GFVariantData.get_option_value(data, "b"))
		var a: Dictionary = _try_coerce_float(GFVariantData.get_option_value(data, "a", 1.0))
		if (
			_coerce_report_ok(r)
			and _coerce_report_ok(g)
			and _coerce_report_ok(b)
			and _coerce_report_ok(a)
		):
			return _make_coerce_result(true, Color(
				_coerce_report_float(r),
				_coerce_report_float(g),
				_coerce_report_float(b),
				_coerce_report_float(a)
			))
		return _make_coerce_result(false, Color.WHITE, "值无法转换为 Color。")
	if value is Array:
		var values: Array = GFVariantData.as_array(value)
		if values.size() >= 3:
			var r: Dictionary = _try_coerce_float(values[0])
			var g: Dictionary = _try_coerce_float(values[1])
			var b: Dictionary = _try_coerce_float(values[2])
			var a: Dictionary = _try_coerce_float(values[3] if values.size() >= 4 else 1.0)
			if (
				_coerce_report_ok(r)
				and _coerce_report_ok(g)
				and _coerce_report_ok(b)
				and _coerce_report_ok(a)
			):
				return _make_coerce_result(true, Color(
					_coerce_report_float(r),
					_coerce_report_float(g),
					_coerce_report_float(b),
					_coerce_report_float(a)
				))
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value).strip_edges()
		if _is_valid_color_text(text):
			return _make_coerce_result(true, Color.html(text))
	return _make_coerce_result(false, Color.WHITE, "值无法转换为 Color。")


func _coerce_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		var vector: Vector2 = value
		return vector
	if value is Vector2i:
		var vector2i: Vector2i = value
		return Vector2(vector2i.x, vector2i.y)
	if value is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(value)
		return Vector2(
			GFVariantData.get_option_float(data, "x", 0.0),
			GFVariantData.get_option_float(data, "y", 0.0)
		)
	if value is Array:
		var values: Array = GFVariantData.as_array(value)
		if values.size() >= 2:
			return Vector2(GFVariantData.to_float(values[0]), GFVariantData.to_float(values[1]))
	return Vector2.ZERO


func _coerce_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		var vector2i: Vector2i = value
		return vector2i
	if value is Vector2:
		var vector2: Vector2 = value
		return Vector2i(roundi(vector2.x), roundi(vector2.y))
	if value is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(value)
		return Vector2i(
			GFVariantData.get_option_int(data, "x", 0),
			GFVariantData.get_option_int(data, "y", 0)
		)
	if value is Array:
		var values: Array = GFVariantData.as_array(value)
		if values.size() >= 2:
			return Vector2i(GFVariantData.to_int(values[0]), GFVariantData.to_int(values[1]))
	return Vector2i.ZERO


func _coerce_color(value: Variant) -> Color:
	if value is Color:
		var color: Color = value
		return color
	if value is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(value)
		return Color(
			GFVariantData.get_option_float(data, "r", 1.0),
			GFVariantData.get_option_float(data, "g", 1.0),
			GFVariantData.get_option_float(data, "b", 1.0),
			GFVariantData.get_option_float(data, "a", 1.0)
		)
	if value is Array:
		var values: Array = GFVariantData.as_array(value)
		if values.size() >= 3:
			return Color(
				GFVariantData.to_float(values[0], 1.0),
				GFVariantData.to_float(values[1], 1.0),
				GFVariantData.to_float(values[2], 1.0),
				GFVariantData.to_float(values[3], 1.0) if values.size() >= 4 else 1.0
			)
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value).strip_edges()
		if _is_valid_color_text(text):
			return Color.html(text)
	return Color.WHITE


func _is_valid_color_text(value: String) -> bool:
	if value.is_empty():
		return false
	return Color.html_is_valid(value)
