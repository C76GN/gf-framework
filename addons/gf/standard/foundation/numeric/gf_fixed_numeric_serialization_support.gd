# 定点数值对象的序列化共享实现。
#
# 该脚本只供 standard/foundation/numeric 内部复用，不作为用户继承入口。
extends RefCounted


# --- 常量 ---

const _MAX_SIGNED_MAGNITUDE: int = 9_223_372_036_854_775_807
const _INVALID_SIGNED_MAGNITUDE: int = -9_223_372_036_854_775_807 - 1
const _MAX_DECIMAL_PLACES: int = 18
const _MAX_INT_DIGITS: String = "9223372036854775807"
const _U64_INITIAL_DIVISOR: int = 72_057_594_037_927_936


# --- 层内方法 ---

## 归一化定点数小数位。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param value: 输入小数位。
## [br]
## @param owner_name: 报错时使用的类型名。
## [br]
## @return 钳制到安全范围内的小数位。
static func normalize_decimal_places(value: int, owner_name: String) -> int:
	if value < 0:
		return 0
	if value > _MAX_DECIMAL_PLACES:
		push_error("[%s] decimal_places 超出上限 %d，已自动钳制。" % [
			owner_name,
			_MAX_DECIMAL_PLACES,
		])
		return _MAX_DECIMAL_PLACES
	return value


## 判断序列化状态中的小数位是否在受支持范围内。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param value: 待检查的小数位。
## [br]
## @return 小数位可被定点数值对象恢复时返回 true。
static func decimal_places_are_in_serialized_range(value: int) -> bool:
	return value >= 0 and value <= _MAX_DECIMAL_PLACES


## 判断 raw 值是否处于 GF 定点数安全对称 int64 范围内。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param value: 待检查 raw 值。
## [br]
## @return raw 值可安全取绝对值和序列化时返回 true。
static func raw_value_is_supported(value: int) -> bool:
	return value >= -_MAX_SIGNED_MAGNITUDE and value <= _MAX_SIGNED_MAGNITUDE


## 将 raw 值钳制到 GF 定点数安全对称 int64 范围内。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param value: 输入 raw 值。
## [br]
## @param owner_name: 报错时使用的类型名。
## [br]
## @param context: 报错时使用的调用上下文。
## [br]
## @return 钳制后的 raw 值。
static func normalize_raw_value(value: int, owner_name: String, context: String) -> int:
	if value < -_MAX_SIGNED_MAGNITUDE:
		push_error("[%s] %s 超出可表示范围，已钳制。" % [owner_name, context])
		return -_MAX_SIGNED_MAGNITUDE
	if value > _MAX_SIGNED_MAGNITUDE:
		push_error("[%s] %s 超出可表示范围，已钳制。" % [owner_name, context])
		return _MAX_SIGNED_MAGNITUDE
	return value


## 返回安全对称 raw 范围内的绝对值。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param value: 输入 raw 值。
## [br]
## @return 输入值的非负绝对值。
static func abs_symmetric(value: int) -> int:
	var normalized: int = normalize_raw_value(value, "GFFixedDecimal", "abs")
	return -normalized if normalized < 0 else normalized


## 判断状态字段是否为受支持的整数 raw 值。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param value: 状态字段值。
## [br]
## @schema value: Variant expected to be an int, String, or StringName representing a supported signed raw value.
## [br]
## @return 字段可转换为安全 raw 整数时返回 true。
static func state_value_is_int(value: Variant) -> bool:
	if value is int:
		var int_value: int = value
		return raw_value_is_supported(int_value)
	if value is String or value is StringName:
		return signed_int_text_is_valid(str(value))
	return false


## 将已校验的状态字段转为整数。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param value: 已通过 state_value_is_int() 校验的状态字段。
## [br]
## @schema value: Variant previously validated by state_value_is_int().
## [br]
## @return 状态字段对应的整数。
static func state_value_to_int(value: Variant) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	return str(value).strip_edges().to_int()


## 判断文本是否为受支持的十进制整数 raw 值。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param text: 待检查文本。
## [br]
## @return 文本可安全转为 raw 整数时返回 true。
static func signed_int_text_is_valid(text: String) -> bool:
	var trimmed: String = text.strip_edges()
	if trimmed.is_empty():
		return false

	var digits: String = trimmed
	if digits.begins_with("-") or digits.begins_with("+"):
		digits = digits.substr(1)
	if digits.is_empty():
		return false

	for i: int in range(digits.length()):
		var character: String = digits.substr(i, 1)
		if character < "0" or character > "9":
			return false

	var significant_digits: String = digits
	while significant_digits.length() > 1 and significant_digits.begins_with("0"):
		significant_digits = significant_digits.substr(1)
	if significant_digits.length() > 19:
		return false
	if significant_digits.length() == 19 and significant_digits > _MAX_INT_DIGITS:
		return false
	return true


## 写入符号位和 8 字节大端绝对 raw 值。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param target: 目标字节数组。
## [br]
## @param value: 要写入的 signed raw 值。
## [br]
## @param owner_name: 报错时使用的类型名。
## [br]
## @param context: 报错时使用的调用上下文。
static func append_signed_magnitude(target: PackedByteArray, value: int, owner_name: String, context: String) -> void:
	var normalized: int = normalize_raw_value(value, owner_name, context)
	var _sign_appended: bool = target.append(1 if normalized < 0 else 0)
	append_u64_magnitude_bytes(target, abs_symmetric(normalized))


## 写入 8 字节大端无符号 magnitude。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param target: 目标字节数组。
## [br]
## @param magnitude: 非负 magnitude。
static func append_u64_magnitude_bytes(target: PackedByteArray, magnitude: int) -> void:
	var divisor: int = _U64_INITIAL_DIVISOR
	var remaining: int = magnitude
	while divisor > 0:
		var byte_value: int = divide_truncated(remaining, divisor)
		var _byte_appended: bool = target.append(byte_value)
		remaining -= byte_value * divisor
		divisor = divide_truncated(divisor, 256)


## 读取符号位和 8 字节大端绝对 raw 值。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param data: 来源字节数组。
## [br]
## @param sign_offset: 符号位偏移。
## [br]
## @param magnitude_offset: magnitude 起始偏移。
## [br]
## @return signed raw 值；格式非法时返回内部无效哨兵。
static func read_signed_magnitude(data: PackedByteArray, sign_offset: int, magnitude_offset: int) -> int:
	var sign_value: int = data[sign_offset]
	if sign_value != 0 and sign_value != 1:
		return _INVALID_SIGNED_MAGNITUDE

	var magnitude: int = read_u64_magnitude_bytes(data, magnitude_offset)
	if magnitude < 0:
		return _INVALID_SIGNED_MAGNITUDE
	if sign_value == 1 and magnitude == 0:
		return _INVALID_SIGNED_MAGNITUDE
	return -magnitude if sign_value == 1 else magnitude


## 判断 read_signed_magnitude() 的返回值是否为无效哨兵。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param value: read_signed_magnitude() 的返回值。
## [br]
## @return 值为无效哨兵时返回 true。
static func signed_magnitude_is_invalid(value: int) -> bool:
	return value == _INVALID_SIGNED_MAGNITUDE


## 读取 8 字节大端无符号 magnitude。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param data: 来源字节数组。
## [br]
## @param offset: magnitude 起始偏移。
## [br]
## @return magnitude；超过安全 raw 范围时返回 -1。
static func read_u64_magnitude_bytes(data: PackedByteArray, offset: int) -> int:
	var magnitude: int = 0
	for i: int in range(8):
		var byte_value: int = data[offset + i]
		if magnitude > divide_truncated(_MAX_SIGNED_MAGNITUDE - byte_value, 256):
			return -1
		magnitude = magnitude * 256 + byte_value
	return magnitude


## 执行整数截断除法。
## [br]
## @api layer_internal
## [br]
## @layer standard/foundation/numeric
## [br]
## @param numerator: 被除数。
## [br]
## @param denominator: 除数。
## [br]
## @return 截断后的整数商。
static func divide_truncated(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	return numerator / denominator
