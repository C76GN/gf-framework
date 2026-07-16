## GFNetworkFieldSerializer: 网络状态字段编码器。
##
## 将常见 Godot 值归一化为可序列化 Variant。它只处理字段值的形态转换，
## 不规定同步方向、可靠性、预测、回滚或冲突解决策略。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNetworkFieldSerializer
extends Resource


# --- 枚举 ---

## 字段值类型。
## [br]
## @api public
enum ValueType {
	## 保持原始 Variant。
	VARIANT,
	## 布尔值。
	BOOL,
	## 整数。
	INT,
	## 浮点数。
	FLOAT,
	## 字符串。
	STRING,
	## StringName，编码时使用 String。
	STRING_NAME,
	## Vector2，编码为两个数值。
	VECTOR2,
	## Vector3，编码为三个数值。
	VECTOR3,
	## Vector2i，编码为两个整数。
	VECTOR2I,
	## Vector3i，编码为三个整数。
	VECTOR3I,
	## Color，编码为四个数值。
	COLOR,
}


# --- 导出变量 ---

## 字段值类型。
## [br]
## @api public
@export var value_type: ValueType = ValueType.VARIANT

## 浮点量化小数位；小于 0 表示不量化。
## [br]
## @api public
@export_range(-1, 8, 1) var quantize_decimals: int = -1

## 是否夹取数值。
## [br]
## @api public
@export var clamp_enabled: bool = false

## 数值夹取下限。
## [br]
## @api public
@export var min_value: float = 0.0

## 数值夹取上限。
## [br]
## @api public
@export var max_value: float = 1.0


# --- 公共方法 ---

## 编码字段值。
## [br]
## @api public
## [br]
## @param value: 原始值。
## [br]
## @return 可序列化值。
## [br]
## @schema value: Variant，原始字段值。
## [br]
## @schema return: Variant，可序列化字段值；向量和颜色会编码为 Array。
func serialize_value(value: Variant) -> Variant:
	match value_type:
		ValueType.BOOL:
			return _coerce_bool(value)
		ValueType.INT:
			return roundi(_apply_number_policy(_coerce_float(value)))
		ValueType.FLOAT:
			return _apply_number_policy(_coerce_float(value))
		ValueType.STRING:
			return str(value)
		ValueType.STRING_NAME:
			return _coerce_text(value)
		ValueType.VECTOR2:
			return _serialize_vector2(value)
		ValueType.VECTOR3:
			return _serialize_vector3(value)
		ValueType.VECTOR2I:
			return _serialize_vector2i(value)
		ValueType.VECTOR3I:
			return _serialize_vector3i(value)
		ValueType.COLOR:
			return _serialize_color(value)
		_:
			return GFVariantData.duplicate_variant(value)


## 解码字段值。
## [br]
## @api public
## [br]
## @param value: 编码值。
## [br]
## @return 解码后的值。
## [br]
## @schema value: Variant，serialize_value() 产生的编码值或兼容输入。
## [br]
## @schema return: Variant，按 value_type 解码后的字段值。
func deserialize_value(value: Variant) -> Variant:
	match value_type:
		ValueType.BOOL:
			return _coerce_bool(value)
		ValueType.INT:
			return _coerce_int(value)
		ValueType.FLOAT:
			return _coerce_float(value)
		ValueType.STRING:
			return str(value)
		ValueType.STRING_NAME:
			return StringName(str(value))
		ValueType.VECTOR2:
			return _deserialize_vector2(value)
		ValueType.VECTOR3:
			return _deserialize_vector3(value)
		ValueType.VECTOR2I:
			return _deserialize_vector2i(value)
		ValueType.VECTOR3I:
			return _deserialize_vector3i(value)
		ValueType.COLOR:
			return _deserialize_color(value)
		_:
			return GFVariantData.duplicate_variant(value)


## 复制编码器配置。
## [br]
## @api public
## [br]
## @return 新编码器。
func duplicate_serializer() -> GFNetworkFieldSerializer:
	var serializer: GFNetworkFieldSerializer = GFNetworkFieldSerializer.new()
	serializer.value_type = value_type
	serializer.quantize_decimals = quantize_decimals
	serializer.clamp_enabled = clamp_enabled
	serializer.min_value = min_value
	serializer.max_value = max_value
	return serializer


# --- 私有/辅助方法 ---

func _apply_number_policy(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	var result: float = value
	if clamp_enabled:
		result = clampf(result, minf(min_value, max_value), maxf(min_value, max_value))
	if quantize_decimals >= 0:
		var scale: float = pow(10.0, float(quantize_decimals))
		result = roundf(result * scale) / scale
	return result


func _serialize_vector2(value: Variant) -> Array:
	var vector: Vector2 = Vector2.ZERO
	if value is Vector2:
		vector = value
	return [
		_apply_number_policy(vector.x),
		_apply_number_policy(vector.y),
	]


func _serialize_vector3(value: Variant) -> Array:
	var vector: Vector3 = Vector3.ZERO
	if value is Vector3:
		vector = value
	return [
		_apply_number_policy(vector.x),
		_apply_number_policy(vector.y),
		_apply_number_policy(vector.z),
	]


func _serialize_vector2i(value: Variant) -> Array:
	var vector: Vector2i = Vector2i.ZERO
	if value is Vector2i:
		vector = value
	return [
		vector.x,
		vector.y,
	]


func _serialize_vector3i(value: Variant) -> Array:
	var vector: Vector3i = Vector3i.ZERO
	if value is Vector3i:
		vector = value
	return [
		vector.x,
		vector.y,
		vector.z,
	]


func _serialize_color(value: Variant) -> Array:
	var color: Color = Color.WHITE
	if value is Color:
		color = value
	return [
		_apply_number_policy(color.r),
		_apply_number_policy(color.g),
		_apply_number_policy(color.b),
		_apply_number_policy(color.a),
	]


func _deserialize_vector2(value: Variant) -> Vector2:
	var values: Array = _read_array(value)
	return Vector2(
		_get_array_float(values, 0),
		_get_array_float(values, 1)
	)


func _deserialize_vector3(value: Variant) -> Vector3:
	var values: Array = _read_array(value)
	return Vector3(
		_get_array_float(values, 0),
		_get_array_float(values, 1),
		_get_array_float(values, 2)
	)


func _deserialize_vector2i(value: Variant) -> Vector2i:
	var values: Array = _read_array(value)
	return Vector2i(
		_get_array_int(values, 0),
		_get_array_int(values, 1)
	)


func _deserialize_vector3i(value: Variant) -> Vector3i:
	var values: Array = _read_array(value)
	return Vector3i(
		_get_array_int(values, 0),
		_get_array_int(values, 1),
		_get_array_int(values, 2)
	)


func _deserialize_color(value: Variant) -> Color:
	var values: Array = _read_array(value)
	return Color(
		_get_array_float(values, 0, 1.0),
		_get_array_float(values, 1, 1.0),
		_get_array_float(values, 2, 1.0),
		_get_array_float(values, 3, 1.0)
	)


func _read_array(value: Variant) -> Array:
	if value is Array:
		var array_value: Array = value
		return array_value
	if value is PackedFloat32Array:
		var float32_values: PackedFloat32Array = value
		return Array(float32_values)
	if value is PackedFloat64Array:
		var float64_values: PackedFloat64Array = value
		return Array(float64_values)
	if value is PackedInt32Array:
		var int32_values: PackedInt32Array = value
		return Array(int32_values)
	if value is PackedInt64Array:
		var int64_values: PackedInt64Array = value
		return Array(int64_values)
	return []


func _get_array_float(values: Array, index: int, default_value: float = 0.0) -> float:
	if index < 0 or index >= values.size():
		return default_value
	return _coerce_float(values[index], default_value)


func _get_array_int(values: Array, index: int, default_value: int = 0) -> int:
	if index < 0 or index >= values.size():
		return default_value
	return _coerce_int(values[index], default_value)


func _coerce_bool(value: Variant, default_value: bool = false) -> bool:
	if value is bool:
		var bool_value: bool = value
		return bool_value
	if value is int:
		var int_value: int = value
		return int_value != 0
	if value is float:
		var float_value: float = value
		return not is_zero_approx(float_value)
	if value is String or value is StringName:
		var text: String = _coerce_text(value).strip_edges().to_lower()
		if text in ["true", "1", "yes", "on"]:
			return true
		if text in ["false", "0", "no", "off", ""]:
			return false
	return default_value


func _coerce_int(value: Variant, default_value: int = 0) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	if value is bool:
		var bool_value: bool = value
		return int(bool_value)
	if value is String or value is StringName:
		var text: String = _coerce_text(value).strip_edges()
		if text.is_valid_int():
			return text.to_int()
		if text.is_valid_float():
			return int(text.to_float())
	return default_value


func _coerce_float(value: Variant, default_value: float = 0.0) -> float:
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	if value is bool:
		var bool_value: bool = value
		return 1.0 if bool_value else 0.0
	if value is String or value is StringName:
		var text: String = _coerce_text(value).strip_edges()
		if text.is_valid_float():
			return text.to_float()
	return default_value


func _coerce_text(value: Variant, default_value: String = "") -> String:
	if value is String:
		var text_value: String = value
		return text_value
	if value is StringName:
		var name_value: StringName = value
		return String(name_value)
	if value is NodePath:
		var path_value: NodePath = value
		return String(path_value)
	if value == null:
		return default_value
	return str(value)
