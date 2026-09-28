## GFUuid: 通用 UUID 生成与校验工具。
##
## 只处理 RFC 4122 形态的字符串标识，不绑定存档、分析、网络请求或编辑器资源语义。
## v4 适合匿名随机标识，v7 适合需要大致按生成时间排序的标识；同一进程、同一毫秒内的 v7
## 会写入递增序列以保证 canonical 字符串严格递增。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.19.0
class_name GFUuid
extends RefCounted


# --- 常量 ---

## UUID 字节长度。
## [br]
## @api public
const BYTE_COUNT: int = 16

## UUID 规范字符串长度。
## [br]
## @api public
const CANONICAL_LENGTH: int = 36

## UUID 十六进制字符表；用于字符校验和 nibble 转换。
## [br]
## @api private
const _HEX_CHARS: String = "0123456789abcdef"

## UUID v7 时间戳可写入的最大 48 位 Unix 毫秒值。
## [br]
## @api private
const _MAX_UNIX_TIME_MSEC: int = 281474976710655

## UUID v7 时间字段之后可用的 12 位单调序列上限。
## [br]
## @api private
const _MAX_V7_SEQUENCE: int = 4095

## UUID v7 在时间戳和 12 位序列达到边界后使用的 62 位尾部序列上限。
## [br]
## @api private
const _MAX_V7_TAIL_SEQUENCE: int = 4611686018427387903


# --- 私有变量 ---

## 最近一次保留的 UUID v7 48 位 Unix 毫秒时间戳；状态由互斥锁保护。
## [br]
## @api private
static var _last_v7_timestamp_msec: int = -1

## 最近一次保留的 UUID v7 12 位单调序列；状态由互斥锁保护。
## [br]
## @api private
static var _last_v7_sequence: int = -1

## 时间戳与 12 位序列到达最大值时使用的最近尾部序列；状态由互斥锁保护。
## [br]
## @api private
static var _last_v7_tail_sequence: int = -1

## 串行保护 UUID v7 单调状态的互斥锁。
## [br]
## @api private
static var _v7_state_mutex: Mutex = Mutex.new()


# --- 公共方法 ---

## 生成随机 UUID v4。
## [br]
## @api public
## [br]
## @return 小写 canonical UUID 字符串。
static func generate_v4() -> String:
	var bytes: PackedByteArray = _generate_random_bytes()
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	return _format_uuid_bytes(bytes)


## 生成时间有序 UUID v7。
## [br]
## @api public
## [br]
## @param unix_time_msec: Unix epoch 毫秒；小于 0 时使用系统当前时间。
## [br]
## @return 小写 canonical UUID 字符串。
static func generate_v7(unix_time_msec: int = -1) -> String:
	var v7_state: Dictionary = _reserve_v7_monotonic_state(_resolve_unix_time_msec(unix_time_msec))
	var timestamp_msec: int = GFVariantData.get_option_int(v7_state, "timestamp_msec", 0)
	var sequence: int = GFVariantData.get_option_int(v7_state, "sequence", 0)
	var bytes: PackedByteArray = _generate_random_bytes()
	bytes[0] = (timestamp_msec >> 40) & 0xff
	bytes[1] = (timestamp_msec >> 32) & 0xff
	bytes[2] = (timestamp_msec >> 24) & 0xff
	bytes[3] = (timestamp_msec >> 16) & 0xff
	bytes[4] = (timestamp_msec >> 8) & 0xff
	bytes[5] = timestamp_msec & 0xff
	bytes[6] = ((sequence >> 8) & 0x0f) | 0x70
	bytes[7] = sequence & 0xff
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var tail_sequence: int = GFVariantData.get_option_int(v7_state, "tail_sequence", -1)
	if tail_sequence >= 0:
		_write_v7_tail_sequence(bytes, tail_sequence)
	return _format_uuid_bytes(bytes)


## 判断字符串是否为 canonical UUID。
## [br]
## @api public
## [br]
## @param value: 待校验字符串。
## [br]
## @param version: 可选版本过滤；0 表示接受任意版本。
## [br]
## @return 字符串符合 canonical UUID 形态且版本匹配时返回 true。
static func is_valid(value: String, version: int = 0) -> bool:
	if value.length() != CANONICAL_LENGTH:
		return false
	if version < 0 or version > 15:
		return false
	if value.substr(8, 1) != "-":
		return false
	if value.substr(13, 1) != "-":
		return false
	if value.substr(18, 1) != "-":
		return false
	if value.substr(23, 1) != "-":
		return false

	for index: int in range(CANONICAL_LENGTH):
		if [8, 13, 18, 23].has(index):
			continue
		if not _is_hex_char(value.substr(index, 1)):
			return false

	if version > 0 and value.substr(14, 1) != _hex_nibble(version):
		return false

	var variant: String = value.substr(19, 1)
	return ["8", "9", "a", "b"].has(variant)


# --- 私有/辅助方法 ---

## 生成一个 UUID 字节长度的随机字节数组。
## [br]
## @api private
static func _generate_random_bytes() -> PackedByteArray:
	var crypto: Crypto = Crypto.new()
	return crypto.generate_random_bytes(BYTE_COUNT)


## 将请求时间解析为 UUID v7 可表示范围内的 Unix 毫秒时间戳。
## [br]
## @api private
static func _resolve_unix_time_msec(unix_time_msec: int) -> int:
	if unix_time_msec < 0:
		return GFVariantData.to_int(floor(Time.get_unix_time_from_system() * 1000.0))
	if unix_time_msec > _MAX_UNIX_TIME_MSEC:
		return _MAX_UNIX_TIME_MSEC
	return unix_time_msec


## 在互斥锁内预留时间戳与序号，时钟回退时沿用上次时间；序号用尽先推进时间，再使用尾部序号。
## 时间戳、主序号及尾序号全部耗尽后保持饱和值，不承诺越过表示范围后仍严格递增。
## [br]
## @api private
static func _reserve_v7_monotonic_state(timestamp_msec: int) -> Dictionary:
	_v7_state_mutex.lock()
	var effective_timestamp: int = timestamp_msec
	var sequence: int = 0
	var tail_sequence: int = -1
	if effective_timestamp <= _last_v7_timestamp_msec:
		effective_timestamp = _last_v7_timestamp_msec
		sequence = _last_v7_sequence + 1
		if sequence > _MAX_V7_SEQUENCE:
			if _last_v7_timestamp_msec < _MAX_UNIX_TIME_MSEC:
				effective_timestamp = _last_v7_timestamp_msec + 1
				sequence = 0
				tail_sequence = -1
			else:
				sequence = _MAX_V7_SEQUENCE
				tail_sequence = mini(_last_v7_tail_sequence + 1, _MAX_V7_TAIL_SEQUENCE)
		elif effective_timestamp == _MAX_UNIX_TIME_MSEC and sequence == _MAX_V7_SEQUENCE:
			tail_sequence = 0

	_last_v7_timestamp_msec = effective_timestamp
	_last_v7_sequence = sequence
	_last_v7_tail_sequence = tail_sequence
	var result: Dictionary = {
		"timestamp_msec": effective_timestamp,
		"sequence": sequence,
		"tail_sequence": tail_sequence,
	}
	_v7_state_mutex.unlock()
	return result


## 将 62 位尾部序列写入 UUID v7 的变体位和末尾 7 个字节。
## [br]
## @api private
static func _write_v7_tail_sequence(bytes: PackedByteArray, tail_sequence: int) -> void:
	var clamped_sequence: int = mini(maxi(tail_sequence, 0), _MAX_V7_TAIL_SEQUENCE)
	bytes[8] = 0x80 | ((clamped_sequence >> 56) & 0x3f)
	for index: int in range(7):
		bytes[9 + index] = (clamped_sequence >> ((6 - index) * 8)) & 0xff


## 将 UUID 字节编码为带连字符的小写 canonical 字符串。
## [br]
## @api private
static func _format_uuid_bytes(bytes: PackedByteArray) -> String:
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]


## 判断单字符字符串是否属于小写十六进制字符表。
## [br]
## @api private
static func _is_hex_char(character: String) -> bool:
	return _HEX_CHARS.find(character) >= 0


## 将整数的低 4 位映射为小写十六进制字符。
## [br]
## @api private
static func _hex_nibble(value: int) -> String:
	return _HEX_CHARS.substr(value & 0x0f, 1)
