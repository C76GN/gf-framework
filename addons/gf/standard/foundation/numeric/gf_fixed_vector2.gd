## GFFixedVector2: 基于统一整数缩放的二维定点向量值对象。
##
## 它适合锁步、回放、黄金测试和需要稳定序列化的二维坐标或方向值。
## 该类型不替代 Vector2i 格子坐标，也不替代 Godot Vector2 在渲染和物理中的浮点表达。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 5.0.0
class_name GFFixedVector2
extends RefCounted


# --- 常量 ---

const _BYTE_FORMAT_SIZE: int = 24
const _BYTE_MAGIC_0: int = 71
const _BYTE_MAGIC_1: int = 70
const _BYTE_MAGIC_2: int = 70
const _BYTE_MAGIC_3: int = 50
const _BYTE_X_MAGNITUDE_OFFSET: int = 7
const _BYTE_Y_SIGN_OFFSET: int = 15
const _BYTE_Y_MAGNITUDE_OFFSET: int = 16
const _SERIALIZATION_SUPPORT: Script = preload("res://addons/gf/standard/foundation/numeric/gf_fixed_numeric_serialization_support.gd")
const _SERIALIZATION_TYPE: String = "gf.fixed_vector2"
const _SERIALIZATION_VERSION: int = 1
const _INVALID_SIGNED_MAGNITUDE: int = -9_223_372_036_854_775_807 - 1


# --- 公共变量 ---

## X 分量的整数缩放值。
## [br]
## @api public
## [br]
## @since 5.0.0
var raw_x: int = 0

## Y 分量的整数缩放值。
## [br]
## @api public
## [br]
## @since 5.0.0
var raw_y: int = 0

## 两个分量共享的小数位数。
## [br]
## @api public
## [br]
## @since 5.0.0
var decimal_places: int = 2


# --- Godot 生命周期方法 ---

func _init(p_raw_x: int = 0, p_raw_y: int = 0, p_decimal_places: int = 2) -> void:
	raw_x = _normalize_raw_value(p_raw_x, "init")
	raw_y = _normalize_raw_value(p_raw_y, "init")
	decimal_places = _normalize_decimal_places(p_decimal_places)


# --- 公共方法 ---

## 从 raw 分量创建定点二维向量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param p_raw_x: X 分量整数缩放值。
## [br]
## @param p_raw_y: Y 分量整数缩放值。
## [br]
## @param p_decimal_places: 两个分量共享的小数位。
## [br]
## @return 定点二维向量实例。
static func from_raw(p_raw_x: int, p_raw_y: int, p_decimal_places: int = 2) -> GFFixedVector2:
	return GFFixedVector2.new(p_raw_x, p_raw_y, p_decimal_places)


## 从普通十进制字符串创建定点二维向量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param x_text: X 分量十进制字符串。
## [br]
## @param y_text: Y 分量十进制字符串。
## [br]
## @param p_decimal_places: 目标小数位。
## [br]
## @param rounding_mode: 舍入策略。
## [br]
## @return 定点二维向量实例。
static func from_decimal_strings(
	x_text: String,
	y_text: String,
	p_decimal_places: int = 2,
	rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP
) -> GFFixedVector2:
	var x_decimal: GFFixedDecimal = GFFixedDecimal.from_string(x_text, p_decimal_places, rounding_mode)
	var y_decimal: GFFixedDecimal = GFFixedDecimal.from_string(y_text, p_decimal_places, rounding_mode)
	return GFFixedVector2.new(x_decimal.raw_value, y_decimal.raw_value, x_decimal.decimal_places)


## 从 Godot Vector2 创建定点二维向量。
## 这是显式浮点适配入口，不应用作 deterministic 真值来源。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param value: Godot 浮点二维向量。
## [br]
## @param p_decimal_places: 目标小数位。
## [br]
## @param rounding_mode: 舍入策略。
## [br]
## @return 定点二维向量实例。
static func from_vector2(
	value: Vector2,
	p_decimal_places: int = 2,
	rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP
) -> GFFixedVector2:
	var x_decimal: GFFixedDecimal = GFFixedDecimal.from_float(value.x, p_decimal_places, rounding_mode)
	var y_decimal: GFFixedDecimal = GFFixedDecimal.from_float(value.y, p_decimal_places, rounding_mode)
	return GFFixedVector2.new(x_decimal.raw_value, y_decimal.raw_value, x_decimal.decimal_places)


## 从状态字典恢复定点二维向量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: `to_dict()` 输出的状态字典。
## [br]
## @schema data: Dictionary with `type`, `version`, `raw_x`, `raw_y`, and `decimal_places` fields.
## [br]
## @return 定点二维向量实例。
static func from_dict(data: Dictionary) -> GFFixedVector2:
	var value: GFFixedVector2 = GFFixedVector2.new()
	var _applied: bool = value.apply_dict(data)
	return value


## 从固定字节序列恢复定点二维向量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: `to_bytes()` 输出的字节序列。
## [br]
## @return 定点二维向量实例。
static func from_bytes(data: PackedByteArray) -> GFFixedVector2:
	var value: GFFixedVector2 = GFFixedVector2.new()
	var _applied: bool = value.apply_bytes(data)
	return value


## 克隆当前向量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 内容相同的新实例。
func clone() -> GFFixedVector2:
	return GFFixedVector2.new(raw_x, raw_y, decimal_places)


## 当前向量是否为零向量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 两个 raw 分量都为 0 时返回 true。
func is_zero() -> bool:
	return raw_x == 0 and raw_y == 0


## X 分量转为 GFFixedDecimal。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return X 分量定点数。
func get_x_decimal() -> GFFixedDecimal:
	return GFFixedDecimal.new(raw_x, decimal_places)


## Y 分量转为 GFFixedDecimal。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return Y 分量定点数。
func get_y_decimal() -> GFFixedDecimal:
	return GFFixedDecimal.new(raw_y, decimal_places)


## 转为 Godot Vector2。
## 该转换会回到 float，仅用于渲染、调试或 Godot API 适配。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return Godot 浮点二维向量。
func to_vector2() -> Vector2:
	return Vector2(get_x_decimal().to_float(), get_y_decimal().to_float())


## 重设小数位数。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param target_decimal_places: 目标小数位。
## [br]
## @param rounding_mode: 降位时的舍入策略。
## [br]
## @return 重设后的定点二维向量。
func rescaled(
	target_decimal_places: int,
	rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP
) -> GFFixedVector2:
	var x_decimal: GFFixedDecimal = get_x_decimal().rescaled(target_decimal_places, rounding_mode)
	var y_decimal: GFFixedDecimal = get_y_decimal().rescaled(target_decimal_places, rounding_mode)
	return GFFixedVector2.new(x_decimal.raw_value, y_decimal.raw_value, x_decimal.decimal_places)


## 获取相反向量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 新的定点二维向量。
func negated() -> GFFixedVector2:
	return GFFixedVector2.new(
		get_x_decimal().negated().raw_value,
		get_y_decimal().negated().raw_value,
		decimal_places
	)


## 与另一个定点二维向量相加。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param other: 另一个定点二维向量。
## [br]
## @return 相加结果。
func add(other: GFFixedVector2) -> GFFixedVector2:
	if other == null:
		return clone()

	var x_decimal: GFFixedDecimal = get_x_decimal().add(other.get_x_decimal())
	var y_decimal: GFFixedDecimal = get_y_decimal().add(other.get_y_decimal())
	return GFFixedVector2.new(x_decimal.raw_value, y_decimal.raw_value, x_decimal.decimal_places)


## 与另一个定点二维向量相减。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param other: 另一个定点二维向量。
## [br]
## @return 相减结果。
func subtract(other: GFFixedVector2) -> GFFixedVector2:
	if other == null:
		return clone()
	return add(other.negated())


## 乘以定点标量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param scalar: 定点标量。
## [br]
## @param target_decimal_places: 结果小数位；传 -1 时沿用较高小数位。
## [br]
## @param rounding_mode: 结果降位时的舍入策略。
## [br]
## @return 乘法结果。
func multiply_scalar(
	scalar: GFFixedDecimal,
	target_decimal_places: int = -1,
	rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP
) -> GFFixedVector2:
	if scalar == null:
		return clone()

	var x_decimal: GFFixedDecimal = get_x_decimal().multiply(scalar, target_decimal_places, rounding_mode)
	var y_decimal: GFFixedDecimal = get_y_decimal().multiply(scalar, target_decimal_places, rounding_mode)
	return GFFixedVector2.new(x_decimal.raw_value, y_decimal.raw_value, x_decimal.decimal_places)


## 计算点积。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param other: 另一个定点二维向量。
## [br]
## @param target_decimal_places: 结果小数位；传 -1 时沿用较高小数位。
## [br]
## @param rounding_mode: 结果降位时的舍入策略。
## [br]
## @return 点积定点数。
func dot(
	other: GFFixedVector2,
	target_decimal_places: int = -1,
	rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP
) -> GFFixedDecimal:
	if other == null:
		return GFFixedDecimal.new(0, decimal_places)

	var x_product: GFFixedDecimal = get_x_decimal().multiply(other.get_x_decimal(), target_decimal_places, rounding_mode)
	var y_product: GFFixedDecimal = get_y_decimal().multiply(other.get_y_decimal(), target_decimal_places, rounding_mode)
	return x_product.add(y_product)


## 计算长度平方。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param target_decimal_places: 结果小数位；传 -1 时沿用当前小数位。
## [br]
## @param rounding_mode: 结果降位时的舍入策略。
## [br]
## @return 长度平方定点数。
func length_squared(
	target_decimal_places: int = -1,
	rounding_mode: int = GFFixedDecimal.RoundingMode.HALF_UP
) -> GFFixedDecimal:
	return dot(self, target_decimal_places, rounding_mode)


## 判断 raw 分量和小数位是否完全一致。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param other: 另一个定点二维向量。
## [br]
## @return raw 分量和小数位完全一致时返回 true。
func equals_exact(other: GFFixedVector2) -> bool:
	return (
		other != null
		and raw_x == other.raw_x
		and raw_y == other.raw_y
		and decimal_places == other.decimal_places
	)


## 导出 JSON 安全状态字典。
## raw 分量固定写为十进制字符串，避免 JSON 64 位整数精度丢失。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 可稳定恢复定点二维向量的状态字典。
## [br]
## @schema return: Dictionary with `type: String`, `version: int`, `raw_x: String`, `raw_y: String`, and `decimal_places: int`.
func to_dict() -> Dictionary:
	var serialized_raw_x: int = _normalize_raw_value(raw_x, "to_dict")
	var serialized_raw_y: int = _normalize_raw_value(raw_y, "to_dict")
	var serialized_places: int = _normalize_decimal_places(decimal_places)
	return {
		"type": _SERIALIZATION_TYPE,
		"version": _SERIALIZATION_VERSION,
		"raw_x": str(serialized_raw_x),
		"raw_y": str(serialized_raw_y),
		"decimal_places": serialized_places,
	}


## 应用 JSON 安全状态字典。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: `to_dict()` 输出的状态字典。
## [br]
## @schema data: Dictionary with `type`, `version`, `raw_x`, `raw_y`, and `decimal_places` fields.
## [br]
## @return 状态有效并已应用时返回 true。
func apply_dict(data: Dictionary) -> bool:
	var type_name: String = GFVariantData.get_option_string(data, "type")
	var version: int = GFVariantData.get_option_int(data, "version")
	var raw_x_data: Variant = GFVariantData.get_option_value(data, "raw_x")
	var raw_y_data: Variant = GFVariantData.get_option_value(data, "raw_y")
	var places: int = GFVariantData.get_option_int(data, "decimal_places", -1)
	if (
		type_name != _SERIALIZATION_TYPE
		or version != _SERIALIZATION_VERSION
		or not _state_value_is_int(raw_x_data)
		or not _state_value_is_int(raw_y_data)
		or not _decimal_places_are_in_serialized_range(places)
	):
		push_error("[GFFixedVector2] 不支持的状态字典格式。")
		_reset_serialized_zero()
		return false

	raw_x = _state_value_to_int(raw_x_data)
	raw_y = _state_value_to_int(raw_y_data)
	decimal_places = places
	return true


## 导出固定二进制序列。
## 格式为 `GFF2` magic、版本、小数位，以及每个分量的符号位和 8 字节大端绝对 raw 值。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 可稳定恢复定点二维向量的字节序列。
func to_bytes() -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray()
	var _magic_0: bool = result.append(_BYTE_MAGIC_0)
	var _magic_1: bool = result.append(_BYTE_MAGIC_1)
	var _magic_2: bool = result.append(_BYTE_MAGIC_2)
	var _magic_3: bool = result.append(_BYTE_MAGIC_3)
	var _version_appended: bool = result.append(_SERIALIZATION_VERSION)
	var _places_appended: bool = result.append(_normalize_decimal_places(decimal_places))
	result = _append_signed_magnitude(result, raw_x, "GFFixedVector2", "to_bytes")
	result = _append_signed_magnitude(result, raw_y, "GFFixedVector2", "to_bytes")
	return result


## 应用固定二进制序列。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: `to_bytes()` 输出的字节序列。
## [br]
## @return 字节序列有效并已应用时返回 true。
func apply_bytes(data: PackedByteArray) -> bool:
	if not _bytes_have_supported_header(data):
		push_error("[GFFixedVector2] 不支持的字节序列格式。")
		_reset_serialized_zero()
		return false

	var x_value: int = _read_signed_magnitude(data, 6, _BYTE_X_MAGNITUDE_OFFSET)
	var y_value: int = _read_signed_magnitude(data, _BYTE_Y_SIGN_OFFSET, _BYTE_Y_MAGNITUDE_OFFSET)
	if (
		_signed_magnitude_is_invalid(x_value)
		or _signed_magnitude_is_invalid(y_value)
	):
		push_error("[GFFixedVector2] 不支持的字节序列格式。")
		_reset_serialized_zero()
		return false

	raw_x = x_value
	raw_y = y_value
	decimal_places = data[5]
	return true


# --- 私有/辅助方法 ---

static func _call_serialization_support(method_name: StringName, arguments: Array) -> Variant:
	return _SERIALIZATION_SUPPORT.callv(method_name, arguments)


static func _call_serialization_support_bool(method_name: StringName, arguments: Array) -> bool:
	var raw_result: Variant = _call_serialization_support(method_name, arguments)
	if raw_result is bool:
		var bool_result: bool = raw_result
		return bool_result
	return false


static func _call_serialization_support_int(
	method_name: StringName,
	arguments: Array,
	fallback: int = 0
) -> int:
	var raw_result: Variant = _call_serialization_support(method_name, arguments)
	if raw_result is int:
		var int_result: int = raw_result
		return int_result
	return fallback


static func _append_signed_magnitude(
	target: PackedByteArray,
	value: int,
	owner_name: String,
	context: String
) -> PackedByteArray:
	var result: PackedByteArray = target
	var _ignored: Variant = _call_serialization_support(
		&"append_signed_magnitude",
		[result, value, owner_name, context]
	)
	return result


static func _normalize_raw_value(value: int, context: String) -> int:
	return _call_serialization_support_int(
		&"normalize_raw_value",
		[value, "GFFixedVector2", context],
		value
	)


static func _normalize_decimal_places(value: int) -> int:
	return _call_serialization_support_int(&"normalize_decimal_places", [value, "GFFixedVector2"], value)


static func _decimal_places_are_in_serialized_range(value: int) -> bool:
	return _call_serialization_support_bool(&"decimal_places_are_in_serialized_range", [value])


static func _bytes_have_supported_header(data: PackedByteArray) -> bool:
	return (
		data.size() == _BYTE_FORMAT_SIZE
		and data[0] == _BYTE_MAGIC_0
		and data[1] == _BYTE_MAGIC_1
		and data[2] == _BYTE_MAGIC_2
		and data[3] == _BYTE_MAGIC_3
		and data[4] == _SERIALIZATION_VERSION
		and _decimal_places_are_in_serialized_range(data[5])
	)


static func _read_signed_magnitude(data: PackedByteArray, sign_offset: int, magnitude_offset: int) -> int:
	return _call_serialization_support_int(
		&"read_signed_magnitude",
		[data, sign_offset, magnitude_offset],
		_INVALID_SIGNED_MAGNITUDE
	)


static func _signed_magnitude_is_invalid(value: int) -> bool:
	return _call_serialization_support_bool(&"signed_magnitude_is_invalid", [value])


static func _state_value_is_int(value: Variant) -> bool:
	return _call_serialization_support_bool(&"state_value_is_int", [value])


static func _state_value_to_int(value: Variant) -> int:
	return _call_serialization_support_int(&"state_value_to_int", [value])


func _reset_serialized_zero() -> void:
	raw_x = 0
	raw_y = 0
	decimal_places = 2
