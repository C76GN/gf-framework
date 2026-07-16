## GFBlackboardEntry: 通用黑板字段声明。
##
## 只描述字段键、类型、必填性、空值策略和默认值，不绑定行为树、AI 或具体玩法。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFBlackboardEntry
extends Resource


# --- 枚举 ---

## 黑板字段值类型。
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
	## Vector3。
	VECTOR3,
	## Vector3i。
	VECTOR3I,
	## Color。
	COLOR,
	## Dictionary。
	DICTIONARY,
	## Array。
	ARRAY,
	## Object。
	OBJECT,
}


# --- 导出变量 ---

## 字段键。
## [br]
## @api public
@export var key: StringName = &""

## 字段值类型。
## [br]
## @api public
@export var value_type: ValueType = ValueType.ANY

## 是否必须出现在黑板数据中。
## [br]
## @api public
@export var required: bool = false

## 是否允许 null 值。
## [br]
## @api public
@export var allow_null: bool = true

## 默认值。`GFBlackboardSchema.apply_defaults()` 会在缺字段时使用。
## [br]
## @api public
## [br]
## @schema default_value: Variant default blackboard value.
@export var default_value: Variant = null

## 可选元数据，供编辑器、调试器或项目工具使用。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary metadata for editor, debugger, or project tooling.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取稳定字段键。
## [br]
## @api public
## [br]
## @return 字段键。
func get_key() -> StringName:
	return key


## 检查输入值是否符合字段声明。
## [br]
## @api public
## [br]
## @param value: 待检查值。
## [br]
## @return 符合声明时返回 true。
## [br]
## @schema value: Variant value to validate.
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
		ValueType.VECTOR3:
			return value is Vector3
		ValueType.VECTOR3I:
			return value is Vector3i
		ValueType.COLOR:
			return value is Color
		ValueType.DICTIONARY:
			return value is Dictionary
		ValueType.ARRAY:
			return value is Array
		ValueType.OBJECT:
			return value is Object
		_:
			return true


## 将输入值转换为字段要求的类型；转换失败时返回输入值副本。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param value: 输入值。
## [br]
## @return 转换后的值；失败时为输入值副本。
## [br]
## @schema value: Variant value to coerce.
## [br]
## @schema return: Variant coerced value.
func coerce_value(value: Variant) -> Variant:
	var result: Dictionary = try_coerce_value(value)
	if GFVariantData.get_option_bool(result, "ok", false):
		return GFVariantData.get_option_value(result, "value")
	return GFVariantData.duplicate_variant(value)


## 尝试转换输入值并返回转换报告。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @return 包含 ok、value、message 的转换报告。
## [br]
## @schema value: Variant value to coerce.
## [br]
## @schema return: Dictionary with ok, value, and message.
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
		ValueType.VECTOR3:
			return _try_coerce_vector3(value)
		ValueType.VECTOR3I:
			return _try_coerce_vector3i(value)
		ValueType.COLOR:
			return _try_coerce_color(value)
		ValueType.DICTIONARY:
			if value is Dictionary:
				return _make_coerce_result(true, GFVariantData.to_dictionary(value))
			return _make_coerce_result(false, {}, "值无法转换为 Dictionary。")
		ValueType.ARRAY:
			if value is Array:
				return _make_coerce_result(true, GFVariantData.to_array(value))
			return _make_coerce_result(false, [], "值无法转换为 Array。")
		ValueType.OBJECT:
			if value is Object:
				return _make_coerce_result(true, value)
			return _make_coerce_result(false, null, "值无法转换为 Object。")
		_:
			return _make_coerce_result(true, value)


## 创建同内容拷贝，避免运行时修改污染共享 Resource。
## [br]
## @api public
## [br]
## @return 新字段声明。
func duplicate_entry() -> GFBlackboardEntry:
	var entry: GFBlackboardEntry = GFBlackboardEntry.new()
	entry.key = key
	entry.value_type = value_type
	entry.required = required
	entry.allow_null = allow_null
	entry.default_value = GFVariantData.duplicate_variant(default_value)
	entry.metadata = metadata.duplicate(true)
	return entry


## 导出字段声明摘要。
## [br]
## @api public
## [br]
## @return 字段声明字典。
## [br]
## @schema return: Dictionary entry description.
func describe() -> Dictionary:
	return {
		"key": key,
		"value_type": value_type,
		"value_type_name": value_type_to_name(value_type),
		"required": required,
		"allow_null": allow_null,
		"default_value": GFVariantData.duplicate_variant(default_value),
		"metadata": metadata.duplicate(true),
	}


## 将字段类型转换为可读名称。
## [br]
## @api public
## [br]
## @param type_id: 字段类型。
## [br]
## @return 类型名称。
static func value_type_to_name(type_id: ValueType) -> String:
	match type_id:
		ValueType.BOOL:
			return "bool"
		ValueType.INT:
			return "int"
		ValueType.FLOAT:
			return "float"
		ValueType.STRING:
			return "string"
		ValueType.STRING_NAME:
			return "string_name"
		ValueType.VECTOR2:
			return "vector2"
		ValueType.VECTOR2I:
			return "vector2i"
		ValueType.VECTOR3:
			return "vector3"
		ValueType.VECTOR3I:
			return "vector3i"
		ValueType.COLOR:
			return "color"
		ValueType.DICTIONARY:
			return "dictionary"
		ValueType.ARRAY:
			return "array"
		ValueType.OBJECT:
			return "object"
		_:
			return "any"


# --- 私有/辅助方法 ---

func _make_coerce_result(ok: bool, coerced_value: Variant, message: String = "") -> Dictionary:
	return {
		"ok": ok,
		"value": coerced_value,
		"message": message,
	}


func _try_coerce_bool(value: Variant) -> Dictionary:
	if value is bool:
		var bool_value: bool = value
		return _make_coerce_result(true, bool_value)
	if value is int or value is float:
		var numeric_value: float = GFVariantData.to_float(value, 0.0)
		if not is_finite(numeric_value):
			return _make_coerce_result(false, false, "Value cannot be coerced to bool from a non-finite number.")
		return _make_coerce_result(true, numeric_value != 0.0)
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value, "").strip_edges().to_lower()
		if text in ["true", "1", "yes", "on"]:
			return _make_coerce_result(true, true)
		if text in ["false", "0", "no", "off"]:
			return _make_coerce_result(true, false)
	return _make_coerce_result(false, false, "值无法转换为 bool。")


func _try_coerce_int(value: Variant) -> Dictionary:
	if value is int or value is bool:
		return _make_coerce_result(true, GFVariantData.to_int(value, 0))
	if value is float:
		var float_value: float = GFVariantData.to_float(value, 0.0)
		if is_nan(float_value) or is_inf(float_value):
			return _make_coerce_result(false, 0, "值无法转换为 int。")
		return _make_coerce_result(true, int(float_value))
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value, "").strip_edges()
		if text.is_valid_int():
			return _make_coerce_result(true, text.to_int())
	return _make_coerce_result(false, 0, "值无法转换为 int。")


func _try_coerce_float(value: Variant) -> Dictionary:
	if value is float or value is int or value is bool:
		var float_value: float = GFVariantData.to_float(value, 0.0)
		if is_nan(float_value) or is_inf(float_value):
			return _make_coerce_result(false, 0.0, "值无法转换为 float。")
		return _make_coerce_result(true, float_value)
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value, "").strip_edges()
		if text.is_valid_float():
			return _make_coerce_result(true, text.to_float())
	return _make_coerce_result(false, 0.0, "值无法转换为 float。")


func _try_coerce_vector2(value: Variant) -> Dictionary:
	if value is Vector2:
		return _make_coerce_result(true, value)
	if value is Vector2i:
		var vector2i: Vector2i = value
		return _make_coerce_result(true, Vector2(vector2i.x, vector2i.y))
	return _coerce_vector_from_collection(value, 2, false)


func _try_coerce_vector2i(value: Variant) -> Dictionary:
	if value is Vector2i:
		return _make_coerce_result(true, value)
	if value is Vector2:
		var vector2: Vector2 = value
		return _make_coerce_result(true, Vector2i(roundi(vector2.x), roundi(vector2.y)))

	var result: Dictionary = _coerce_vector_from_collection(value, 2, true)
	if GFVariantData.get_option_bool(result, "ok", false):
		var vector: Vector2 = _get_dictionary_vector2(result, "value", Vector2.ZERO)
		result["value"] = Vector2i(roundi(vector.x), roundi(vector.y))
	return result


func _try_coerce_vector3(value: Variant) -> Dictionary:
	if value is Vector3:
		return _make_coerce_result(true, value)
	if value is Vector3i:
		var vector3i: Vector3i = value
		return _make_coerce_result(true, Vector3(vector3i.x, vector3i.y, vector3i.z))
	return _coerce_vector_from_collection(value, 3, false)


func _try_coerce_vector3i(value: Variant) -> Dictionary:
	if value is Vector3i:
		return _make_coerce_result(true, value)
	if value is Vector3:
		var vector3: Vector3 = value
		return _make_coerce_result(true, Vector3i(roundi(vector3.x), roundi(vector3.y), roundi(vector3.z)))

	var result: Dictionary = _coerce_vector_from_collection(value, 3, true)
	if GFVariantData.get_option_bool(result, "ok", false):
		var vector: Vector3 = _get_dictionary_vector3(result, "value", Vector3.ZERO)
		result["value"] = Vector3i(roundi(vector.x), roundi(vector.y), roundi(vector.z))
	return result


func _try_coerce_color(value: Variant) -> Dictionary:
	if value is Color:
		return _make_coerce_result(true, value)
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value, "").strip_edges()
		if not text.is_empty():
			if text.begins_with("#") and Color.html_is_valid(text):
				return _make_coerce_result(true, Color.html(text))
			return _make_coerce_result(false, Color.WHITE, "无效颜色字符串：%s" % text)

	var channels: Dictionary = _read_numeric_fields(value, ["r", "g", "b", "a"], 3, 1.0)
	if not GFVariantData.get_option_bool(channels, "ok", false):
		return _make_coerce_result(false, Color.WHITE, "值无法转换为 Color。")

	var values: Array = GFVariantData.get_option_array(channels, "values")
	return _make_coerce_result(
		true,
		Color(
			GFVariantData.to_float(values[0], 0.0),
			GFVariantData.to_float(values[1], 0.0),
			GFVariantData.to_float(values[2], 0.0),
			GFVariantData.to_float(values[3], 1.0)
		)
	)


func _coerce_vector_from_collection(value: Variant, size: int, _integer: bool) -> Dictionary:
	var names: Array[String] = ["x", "y", "z"]
	var fields: Array[String] = names.slice(0, size)
	var channels: Dictionary = _read_numeric_fields(value, fields, size, 0.0)
	if not GFVariantData.get_option_bool(channels, "ok", false):
		var fallback_value: Variant = Vector2.ZERO
		if size == 3:
			fallback_value = Vector3.ZERO
		return _make_coerce_result(false, fallback_value, "值无法转换为 Vector。")

	var values: Array = GFVariantData.get_option_array(channels, "values")
	if size == 3:
		return _make_coerce_result(
			true,
			Vector3(
				GFVariantData.to_float(values[0], 0.0),
				GFVariantData.to_float(values[1], 0.0),
				GFVariantData.to_float(values[2], 0.0)
			)
		)
	return _make_coerce_result(
		true,
		Vector2(
			GFVariantData.to_float(values[0], 0.0),
			GFVariantData.to_float(values[1], 0.0)
		)
	)


func _read_numeric_fields(value: Variant, field_names: Array, required_size: int, default_last: float) -> Dictionary:
	var values: Array[float] = []
	if value is Dictionary:
		var data: Dictionary = value
		for index: int in range(field_names.size()):
			var field_name: String = GFVariantData.to_text(field_names[index], "")
			var fallback_value: Variant = null
			if index >= required_size:
				fallback_value = default_last
			var raw_value: Variant = GFVariantData.get_option_value(data, field_name, fallback_value)
			var coerced: Dictionary = _try_coerce_float(raw_value)
			if not GFVariantData.get_option_bool(coerced, "ok", false):
				return { "ok": false, "values": [] }
			values.append(GFVariantData.get_option_float(coerced, "value", 0.0))
		return { "ok": true, "values": values }
	if value is Array:
		var array: Array = value
		if array.size() < required_size:
			return { "ok": false, "values": [] }
		for index: int in range(field_names.size()):
			var raw_value: Variant = null
			if index < array.size():
				raw_value = array[index]
			else:
				raw_value = default_last
			var coerced: Dictionary = _try_coerce_float(raw_value)
			if not GFVariantData.get_option_bool(coerced, "ok", false):
				return { "ok": false, "values": [] }
			values.append(GFVariantData.get_option_float(coerced, "value", 0.0))
		return { "ok": true, "values": values }
	return { "ok": false, "values": [] }


func _get_dictionary_vector2(source: Dictionary, dictionary_key: Variant, fallback: Vector2) -> Vector2:
	return _variant_to_vector2(GFVariantData.get_option_value(source, dictionary_key, fallback), fallback)


func _get_dictionary_vector3(source: Dictionary, dictionary_key: Variant, fallback: Vector3) -> Vector3:
	return _variant_to_vector3(GFVariantData.get_option_value(source, dictionary_key, fallback), fallback)


func _variant_to_vector2(value: Variant, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		var vector_value: Vector2 = value
		return vector_value
	return fallback


func _variant_to_vector3(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Vector3:
		var vector_value: Vector3 = value
		return vector_value
	return fallback
