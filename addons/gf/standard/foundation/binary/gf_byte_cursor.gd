## GFByteCursor: PackedByteArray 读写游标。
##
## 提供边界检查、显式字节序和 varuint 编码，适合网络包、存档片段、
## 二进制配置或工具导入器复用。它只处理字节游标，不规定协议字段或消息语义。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 7.0.0
class_name GFByteCursor
extends RefCounted


# --- 常量 ---

const _DEFAULT_MAX_READ_BYTE_COUNT: int = 16 * 1024 * 1024
const _MAX_VAR_UINT_VALUE: int = 9223372036854775807


# --- 公共变量 ---

## 是否使用小端读写多字节整数。false 表示大端。
## [br]
## @api public
## [br]
## @since 7.0.0
var little_endian: bool = false

## 单次读取允许的最大字节数。小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_read_byte_count: int = _DEFAULT_MAX_READ_BYTE_COUNT


# --- 私有变量 ---

var _bytes: PackedByteArray = PackedByteArray()
var _position: int = 0
var _last_error: Error = OK


# --- Godot 生命周期方法 ---

## 构造字节游标。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param source_bytes: 初始字节。
## [br]
## @param p_little_endian: 是否使用小端。
func _init(source_bytes: PackedByteArray = PackedByteArray(), p_little_endian: bool = false) -> void:
	_bytes = PackedByteArray(source_bytes)
	little_endian = p_little_endian


# --- 公共方法 ---

## 从字节创建游标。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param source_bytes: 初始字节。
## [br]
## @param offset: 初始位置。
## [br]
## @param p_little_endian: 是否使用小端。
## [br]
## @return 新游标。
static func from_bytes(source_bytes: PackedByteArray, offset: int = 0, p_little_endian: bool = false) -> GFByteCursor:
	var cursor: GFByteCursor = GFByteCursor.new(source_bytes, p_little_endian)
	if not cursor.set_position(offset):
		cursor._position = cursor.size()
		cursor._last_error = ERR_INVALID_PARAMETER
	return cursor


## 替换内部字节并重置位置。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param source_bytes: 新字节。
func reset(source_bytes: PackedByteArray = PackedByteArray()) -> void:
	_bytes = PackedByteArray(source_bytes)
	_position = 0
	_last_error = OK


## 获取字节副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前字节副本。
func get_bytes() -> PackedByteArray:
	return PackedByteArray(_bytes)


## 获取当前位置。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前位置。
func get_position() -> int:
	return _position


## 设置当前位置。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param offset: 新位置。
## [br]
## @return 设置成功返回 true。
func set_position(offset: int) -> bool:
	if offset < 0 or offset > _bytes.size():
		_last_error = ERR_INVALID_PARAMETER
		return false
	_position = offset
	_last_error = OK
	return true


## 获取总字节数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 总长度。
func size() -> int:
	return _bytes.size()


## 获取剩余可读字节数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 剩余长度。
func remaining() -> int:
	return maxi(_bytes.size() - _position, 0)


## 是否已经到达末尾。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 到达末尾返回 true。
func is_eof() -> bool:
	return _position >= _bytes.size()


## 检查是否还能读取指定长度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param byte_count: 字节数。
## [br]
## @return 可读取返回 true。
func has_bytes(byte_count: int) -> bool:
	return byte_count >= 0 and byte_count <= remaining()


## 读取一个无符号 8 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取到的值；越界时返回 0。
func read_u8() -> int:
	if not _require(1):
		return 0
	var value: int = _bytes[_position]
	_position += 1
	_last_error = OK
	return value


## 读取一个有符号 8 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取到的值；越界时返回 0。
func read_i8() -> int:
	var value: int = read_u8()
	return value - 256 if value >= 128 else value


## 尝试读取一个无符号 8 位整数，并返回结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.
func try_read_u8() -> Dictionary:
	return _try_read_uint(1)


## 尝试读取一个有符号 8 位整数，并返回结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.
func try_read_i8() -> Dictionary:
	var report: Dictionary = try_read_u8()
	if not _read_report_is_ok(report):
		return report
	var raw_value: Variant = report.get("value", 0)
	var value: int = raw_value if raw_value is int else 0
	report["value"] = value - 256 if value >= 128 else value
	return report


## 读取一个无符号 16 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取到的值；越界时返回 0。
func read_u16() -> int:
	return _read_uint(2)


## 读取一个有符号 16 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取到的值；越界时返回 0。
func read_i16() -> int:
	var value: int = read_u16()
	return value - 65536 if value >= 32768 else value


## 尝试读取一个无符号 16 位整数，并返回结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.
func try_read_u16() -> Dictionary:
	return _try_read_uint(2)


## 尝试读取一个有符号 16 位整数，并返回结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.
func try_read_i16() -> Dictionary:
	var report: Dictionary = try_read_u16()
	if not _read_report_is_ok(report):
		return report
	var raw_value: Variant = report.get("value", 0)
	var value: int = raw_value if raw_value is int else 0
	report["value"] = value - 65536 if value >= 32768 else value
	return report


## 读取一个无符号 32 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取到的值；越界时返回 0。
func read_u32() -> int:
	return _read_uint(4)


## 读取一个有符号 32 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取到的值；越界时返回 0。
func read_i32() -> int:
	var value: int = read_u32()
	return value - 4294967296 if value >= 2147483648 else value


## 尝试读取一个无符号 32 位整数，并返回结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.
func try_read_u32() -> Dictionary:
	return _try_read_uint(4)


## 尝试读取一个有符号 32 位整数，并返回结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.
func try_read_i32() -> Dictionary:
	var report: Dictionary = try_read_u32()
	if not _read_report_is_ok(report):
		return report
	var raw_value: Variant = report.get("value", 0)
	var value: int = raw_value if raw_value is int else 0
	report["value"] = value - 4294967296 if value >= 2147483648 else value
	return report


## 读取 Godot int 可表达范围内的 varuint，使用 7-bit continuation 编码。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取到的值；损坏或越界时返回 0。
func read_var_uint() -> int:
	var shift: int = 0
	var result: int = 0
	var read_position: int = _position
	for index: int in range(10):
		if read_position >= _bytes.size():
			_last_error = ERR_FILE_EOF
			return 0
		var byte_value: int = _bytes[read_position]
		read_position += 1
		if index == 9:
			if (byte_value & 0x80) != 0 or (byte_value & 0x7f) != 0:
				_last_error = ERR_PARSE_ERROR
				return 0
		result = result | ((byte_value & 0x7f) << shift)
		if (byte_value & 0x80) == 0:
			_position = read_position
			_last_error = OK
			return result
		shift += 7
	_last_error = ERR_PARSE_ERROR
	return 0


## 尝试读取 Godot int 可表达范围内的 varuint，并返回结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `value: int`, `error: int`, `position: int`, `next_position: int`.
func try_read_var_uint() -> Dictionary:
	var start_position: int = _position
	var value: int = read_var_uint()
	if _last_error != OK:
		_position = start_position
		return _make_read_report(false, 0, _last_error, start_position, start_position)
	return _make_read_report(true, value, OK, start_position, _position)


## 读取指定长度的字节。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param byte_count: 字节数。
## [br]
## @return 字节副本；越界时返回空数组。
func read_bytes(byte_count: int) -> PackedByteArray:
	if byte_count < 0:
		_last_error = ERR_INVALID_PARAMETER
		return PackedByteArray()
	if not _within_read_limit(byte_count):
		_last_error = ERR_INVALID_PARAMETER
		return PackedByteArray()
	if not _require(byte_count):
		return PackedByteArray()
	var result: PackedByteArray = _bytes.slice(_position, _position + byte_count)
	_position += byte_count
	_last_error = OK
	return result


## 尝试读取指定长度的字节，并返回结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param byte_count: 字节数。
## [br]
## @return 读取报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `value: PackedByteArray`, `error: int`, `position: int`, `next_position: int`.
func try_read_bytes(byte_count: int) -> Dictionary:
	var start_position: int = _position
	var value: PackedByteArray = read_bytes(byte_count)
	if _last_error != OK:
		_position = start_position
		return _make_read_report(false, PackedByteArray(), _last_error, start_position, start_position)
	return _make_read_report(true, value, OK, start_position, _position)


## 读取 UTF-8 字符串。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param byte_count: 字节数。
## [br]
## @return 解码后的字符串。
func read_utf8(byte_count: int) -> String:
	if byte_count < 0:
		_last_error = ERR_INVALID_PARAMETER
		return ""
	if not _within_read_limit(byte_count):
		_last_error = ERR_INVALID_PARAMETER
		return ""
	if not _require(byte_count):
		return ""
	var slice: PackedByteArray = _bytes.slice(_position, _position + byte_count)
	if not _is_valid_utf8(slice):
		_last_error = ERR_PARSE_ERROR
		return ""
	_position += byte_count
	_last_error = OK
	return slice.get_string_from_utf8()


## 尝试读取 UTF-8 字符串，并返回结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param byte_count: 字节数。
## [br]
## @return 读取报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `value: String`, `error: int`, `position: int`, `next_position: int`.
func try_read_utf8(byte_count: int) -> Dictionary:
	var start_position: int = _position
	var value: String = read_utf8(byte_count)
	if _last_error != OK:
		_position = start_position
		return _make_read_report(false, "", _last_error, start_position, start_position)
	return _make_read_report(true, value, OK, start_position, _position)


## 读取 varuint 长度前缀的 UTF-8 字符串。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 解码后的字符串；长度或 UTF-8 校验失败时返回空字符串。
func read_var_utf8() -> String:
	var report: Dictionary = try_read_var_utf8()
	var raw_value: Variant = report.get("value", "")
	return raw_value if raw_value is String else ""


## 尝试读取 varuint 长度前缀的 UTF-8 字符串，并返回结构化报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 读取报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `value: String`, `error: int`, `position: int`, `next_position: int`.
func try_read_var_utf8() -> Dictionary:
	var start_position: int = _position
	var length_report: Dictionary = try_read_var_uint()
	if not _read_report_is_ok(length_report):
		_position = start_position
		var raw_length_error: Variant = length_report.get("error", ERR_PARSE_ERROR)
		var length_error: Error = ERR_PARSE_ERROR
		if raw_length_error is int:
			length_error = raw_length_error
		_last_error = length_error
		return _make_read_report(false, "", length_error, start_position, start_position)

	var raw_length: Variant = length_report.get("value", 0)
	var byte_count: int = raw_length if raw_length is int else 0
	var value_report: Dictionary = try_read_utf8(byte_count)
	if not _read_report_is_ok(value_report):
		_position = start_position
		var raw_value_error: Variant = value_report.get("error", ERR_PARSE_ERROR)
		var value_error: Error = ERR_PARSE_ERROR
		if raw_value_error is int:
			value_error = raw_value_error
		_last_error = value_error
		return _make_read_report(false, "", value_error, start_position, start_position)

	var raw_value: Variant = value_report.get("value", "")
	var value: String = raw_value if raw_value is String else ""
	return _make_read_report(true, value, OK, start_position, _position)


## 写入一个无符号 8 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要写入的值。
func write_u8(value: int) -> void:
	_write_checked_uint(value, 1)


## 写入一个有符号 8 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要写入的值。
func write_i8(value: int) -> void:
	_write_checked_int(value, 1)


## 写入一个无符号 16 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要写入的值。
func write_u16(value: int) -> void:
	_write_checked_uint(value, 2)


## 写入一个有符号 16 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要写入的值。
func write_i16(value: int) -> void:
	_write_checked_int(value, 2)


## 写入一个无符号 32 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要写入的值。
func write_u32(value: int) -> void:
	_write_checked_uint(value, 4)


## 写入一个有符号 32 位整数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要写入的值。
func write_i32(value: int) -> void:
	_write_checked_int(value, 4)


## 写入 Godot int 可表达范围内的 varuint，使用 7-bit continuation 编码。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 非负整数。
## [br]
## @return 写入成功返回 true。
func write_var_uint(value: int) -> bool:
	if value < 0 or value > _MAX_VAR_UINT_VALUE:
		_last_error = ERR_INVALID_PARAMETER
		return false
	var remaining_value: int = value
	while remaining_value >= 0x80:
		if not _write_byte((remaining_value & 0x7f) | 0x80):
			return false
		remaining_value = remaining_value >> 7
	if not _write_byte(remaining_value):
		return false
	_last_error = OK
	return true


## 写入字节数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要追加的字节。
func write_bytes(value: PackedByteArray) -> void:
	var next_size: int = _position + value.size()
	if not _ensure_size(next_size):
		return
	for index: int in range(value.size()):
		_bytes[_position + index] = value[index]
	_position = next_size
	_last_error = OK


## 写入 UTF-8 字符串。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要写入的字符串。
func write_utf8(value: String) -> void:
	write_bytes(value.to_utf8_buffer())


## 写入 varuint 长度前缀的 UTF-8 字符串。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 要写入的字符串。
## [br]
## @return 写入成功返回 true。
func write_var_utf8(value: String) -> bool:
	var bytes: PackedByteArray = value.to_utf8_buffer()
	if not write_var_uint(bytes.size()):
		return false
	write_bytes(bytes)
	return _last_error == OK


## 获取最近错误码。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 最近错误码。
func get_last_error() -> Error:
	return _last_error


## 清除最近错误码。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear_error() -> void:
	_last_error = OK


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 size、position、remaining、little_endian 和 last_error。
func get_debug_snapshot() -> Dictionary:
	return {
		"size": _bytes.size(),
		"position": _position,
		"remaining": remaining(),
		"little_endian": little_endian,
		"last_error": _last_error,
	}


# --- 私有/辅助方法 ---

func _require(byte_count: int) -> bool:
	if has_bytes(byte_count):
		return true
	_last_error = ERR_FILE_EOF
	return false


func _read_uint(byte_count: int) -> int:
	if not _require(byte_count):
		return 0
	var result: int = 0
	for index: int in range(byte_count):
		var byte_index: int = index if little_endian else byte_count - index - 1
		result = result | (_bytes[_position + index] << (byte_index * 8))
	_position += byte_count
	_last_error = OK
	return result


func _try_read_uint(byte_count: int) -> Dictionary:
	var start_position: int = _position
	var value: int = _read_uint(byte_count)
	if _last_error != OK:
		_position = start_position
		return _make_read_report(false, 0, _last_error, start_position, start_position)
	return _make_read_report(true, value, OK, start_position, _position)


func _make_read_report(ok: bool, value: Variant, error: Error, start_position: int, next_position: int) -> Dictionary:
	_last_error = error
	return {
		"ok": ok,
		"value": value,
		"error": error,
		"position": start_position,
		"next_position": next_position,
	}


func _read_report_is_ok(report: Dictionary) -> bool:
	var raw_ok: Variant = report.get("ok", false)
	return raw_ok is bool and raw_ok


func _write_uint(value: int, byte_count: int) -> void:
	for index: int in range(byte_count):
		var byte_index: int = index if little_endian else byte_count - index - 1
		if not _write_byte((value >> (byte_index * 8)) & 0xff):
			return
	_last_error = OK


func _write_checked_uint(value: int, byte_count: int) -> void:
	if value < 0 or value > _max_unsigned_value(byte_count):
		_last_error = ERR_INVALID_PARAMETER
		return
	_write_uint(value, byte_count)


func _write_checked_int(value: int, byte_count: int) -> void:
	var bits: int = byte_count * 8
	var minimum: int = -(1 << (bits - 1))
	var maximum: int = (1 << (bits - 1)) - 1
	if value < minimum or value > maximum:
		_last_error = ERR_INVALID_PARAMETER
		return
	var unsigned_value: int = value if value >= 0 else (1 << bits) + value
	_write_uint(unsigned_value, byte_count)


func _write_byte(value: int) -> bool:
	if not _ensure_size(_position + 1):
		return false
	_bytes[_position] = value & 0xff
	_position += 1
	_last_error = OK
	return true


func _ensure_size(size_bytes: int) -> bool:
	if size_bytes <= _bytes.size():
		return true
	var resize_result: Error = _bytes.resize(size_bytes) as Error
	if resize_result != OK:
		_last_error = resize_result
		return false
	return true


func _within_read_limit(byte_count: int) -> bool:
	return max_read_byte_count <= 0 or byte_count <= max_read_byte_count


static func _max_unsigned_value(byte_count: int) -> int:
	return (1 << (byte_count * 8)) - 1


static func _is_valid_utf8(bytes: PackedByteArray) -> bool:
	var index: int = 0
	while index < bytes.size():
		var byte_value: int = bytes[index]
		if byte_value <= 0x7f:
			index += 1
		elif byte_value >= 0xc2 and byte_value <= 0xdf:
			if not _has_continuation_bytes(bytes, index, 1):
				return false
			index += 2
		elif byte_value == 0xe0:
			if index + 2 >= bytes.size() or bytes[index + 1] < 0xa0 or bytes[index + 1] > 0xbf or not _is_continuation_byte(bytes[index + 2]):
				return false
			index += 3
		elif byte_value >= 0xe1 and byte_value <= 0xec:
			if not _has_continuation_bytes(bytes, index, 2):
				return false
			index += 3
		elif byte_value == 0xed:
			if index + 2 >= bytes.size() or bytes[index + 1] < 0x80 or bytes[index + 1] > 0x9f or not _is_continuation_byte(bytes[index + 2]):
				return false
			index += 3
		elif byte_value >= 0xee and byte_value <= 0xef:
			if not _has_continuation_bytes(bytes, index, 2):
				return false
			index += 3
		elif byte_value == 0xf0:
			if index + 3 >= bytes.size() or bytes[index + 1] < 0x90 or bytes[index + 1] > 0xbf or not _is_continuation_byte(bytes[index + 2]) or not _is_continuation_byte(bytes[index + 3]):
				return false
			index += 4
		elif byte_value >= 0xf1 and byte_value <= 0xf3:
			if not _has_continuation_bytes(bytes, index, 3):
				return false
			index += 4
		elif byte_value == 0xf4:
			if index + 3 >= bytes.size() or bytes[index + 1] < 0x80 or bytes[index + 1] > 0x8f or not _is_continuation_byte(bytes[index + 2]) or not _is_continuation_byte(bytes[index + 3]):
				return false
			index += 4
		else:
			return false
	return true


static func _has_continuation_bytes(bytes: PackedByteArray, start_index: int, count: int) -> bool:
	if start_index + count >= bytes.size():
		return false
	for offset: int in range(1, count + 1):
		if not _is_continuation_byte(bytes[start_index + offset]):
			return false
	return true


static func _is_continuation_byte(value: int) -> bool:
	return value >= 0x80 and value <= 0xbf
