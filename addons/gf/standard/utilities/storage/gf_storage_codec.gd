@tool

## GFStorageCodec: 通用存档字典编码与解码策略。
##
## 负责字典序列化、可选压缩、完整性校验和轻量混淆。
## JSON 格式会通过 GFVariantJsonCodec 保留 Godot 值类型和非有限浮点数。
## 它不负责路径、槽位、事务提交或云同步。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFStorageCodec
extends Resource


# --- 枚举 ---

## 存档载荷序列化格式。
## [br]
## @api public
enum Format {
	## 稳定排序后的 JSON 文本。
	JSON,
	## Godot Variant 二进制格式。
	BINARY,
}


# --- 常量 ---

## 存储元信息字段名。
## [br]
## @api public
const META_KEY: String = "_meta"

## 存储版本字段名。
## [br]
## @api public
const VERSION_KEY: String = "version"

## 存储时间戳字段名。
## [br]
## @api public
const TIMESTAMP_KEY: String = "timestamp"

## 存储完整性校验字段名。
## [br]
## @api public
const CHECKSUM_KEY: String = "checksum"

## 存储编码格式字段名。
## [br]
## @api public
const FORMAT_KEY: String = "format"

## 存储压缩方式字段名。
## [br]
## @api public
const COMPRESSION_KEY: String = "compression"

## 当用户数据自身包含 `_meta` 时，外层包裹使用的标记字段名。
## [br]
## @api public
const ENVELOPE_KEY: String = "__gf_storage_envelope"

## 存储 envelope schema 版本字段名。
## [br]
## @api public
## [br]
## @since 8.0.0
const ENVELOPE_VERSION_KEY: String = "__gf_storage_envelope_version"

## 存储 envelope 内原始用户数据的字段名。
## [br]
## @api public
const ENVELOPE_DATA_KEY: String = "data"

## 当前存储 envelope schema 版本。
## [br]
## @api public
## [br]
## @since 8.0.0
const ENVELOPE_VERSION: int = 1

const _COMPRESSION_MODE: int = FileAccess.COMPRESSION_DEFLATE


# --- 导出变量 ---

## 默认序列化格式。
## [br]
## @api public
@export var format: Format = Format.JSON

## 是否压缩载荷。
## [br]
## @api public
@export var use_compression: bool = false

## 是否在 `_meta.checksum` 中写入 SHA-256 完整性校验。
## [br]
## @api public
@export var use_integrity_checksum: bool = false

## 校验失败时是否拒绝读取。
## [br]
## @api public
@export var strict_integrity: bool = true

## 启用完整性校验时，是否要求载荷必须包含 `_meta.checksum`。
## [br]
## @api public
@export var require_integrity_checksum: bool = true

## 是否写入 `_meta.version` 和 `_meta.timestamp`。
## [br]
## @api public
@export var include_metadata: bool = false

## 当前数据版本。
## [br]
## @api public
@export var version: int = 1:
	set(value):
		version = maxi(value, 1)

## 轻量 XOR 混淆密钥；为 0 时写入原始 bytes。该字段不提供安全加密能力。
## [br]
## @api public
@export var obfuscation_key: int = 0

## 解压时允许的最大输出字节数。
## [br]
## @api public
@export var max_decompressed_bytes: int = 64 * 1024 * 1024

## 解码失败时是否尝试按旧版未压缩、未混淆 JSON 读取原始 bytes。
## [br]
## @api public
@export var allow_legacy_plain_json_fallback: bool = false

## JSON 解码时是否把接近整数的 float 归一为 int。Binary 格式不受影响。
## [br]
## @api public
@export var normalize_json_numbers: bool = false


# --- 公共方法 ---

## 将字典编码为可写入文件的 bytes。
## [br]
## @api public
## [br]
## @param data: 要编码的数据。
## [br]
## @param options: 临时覆盖当前 codec 设置的选项字典。
## [br]
## @schema data: Dictionary，要序列化的数据载荷；启用存储元数据时，用户 `_meta` 键会通过信封结构保留。
## [br]
## @schema options: Dictionary，可包含 format、use_compression、obfuscation_key、use_integrity_checksum、include_metadata、version 和 max_decompressed_bytes。
## [br]
## @return 编码后的 bytes。
func encode(data: Dictionary, options: Dictionary = {}) -> PackedByteArray:
	var active_format: Format = _get_format(options)
	var should_compress: bool = GFVariantData.get_option_bool(options, "use_compression", use_compression)
	var key: int = GFVariantData.get_option_int(options, "obfuscation_key", obfuscation_key)
	var should_write_checksum: bool = GFVariantData.get_option_bool(options, "use_integrity_checksum", use_integrity_checksum)
	var should_write_metadata: bool = GFVariantData.get_option_bool(options, "include_metadata", include_metadata) or should_write_checksum
	var payload: Dictionary = _make_storage_payload(data, should_write_metadata)

	if should_write_metadata:
		_prepare_metadata(payload, active_format, should_compress, should_write_checksum, options)

	var bytes: PackedByteArray = _serialize_dictionary(payload, active_format)
	if should_compress:
		bytes = bytes.compress(_COMPRESSION_MODE)
	if key != 0:
		bytes = _obfuscate_bytes(bytes, key)
		return Marshalls.raw_to_base64(bytes).to_utf8_buffer()
	return bytes


## 从 bytes 解码字典。
## [br]
## @api public
## [br]
## @param bytes: 文件读取到的 bytes。
## [br]
## @param options: 临时覆盖当前 codec 设置的选项字典。
## [br]
## @return 结果字典，包含 ok、data、metadata、integrity_valid、error。
## [br]
## @schema options: Dictionary，可包含 format、use_compression、obfuscation_key、allow_legacy_plain_json_fallback、use_integrity_checksum、strict_integrity、normalize_json_numbers、require_integrity_checksum 和 max_decompressed_bytes。
## [br]
## @schema return: Dictionary，包含 ok: bool、data: Dictionary、metadata: Dictionary、integrity_valid: bool 和 error: String。
func decode(bytes: PackedByteArray, options: Dictionary = {}) -> Dictionary:
	var active_format: Format = _get_format(options)
	var should_compress: bool = GFVariantData.get_option_bool(options, "use_compression", use_compression)
	var key: int = GFVariantData.get_option_int(options, "obfuscation_key", obfuscation_key)
	var should_allow_legacy_plain_json: bool = GFVariantData.get_option_bool(
		options,
		"allow_legacy_plain_json_fallback",
		allow_legacy_plain_json_fallback
	)
	var should_verify_checksum: bool = GFVariantData.get_option_bool(options, "use_integrity_checksum", use_integrity_checksum)
	var should_reject_bad_checksum: bool = GFVariantData.get_option_bool(options, "strict_integrity", strict_integrity)
	var should_normalize_json_numbers: bool = GFVariantData.get_option_bool(options, "normalize_json_numbers", normalize_json_numbers)
	var should_require_checksum: bool = GFVariantData.get_option_bool(
		options,
		"require_integrity_checksum",
		require_integrity_checksum
	)
	var payload_bytes: PackedByteArray = _decode_obfuscation(bytes, key, should_allow_legacy_plain_json)
	if payload_bytes.is_empty():
		return _make_result(false, {}, "Payload is empty", true)

	var deserialize_result: Dictionary = {}
	if should_compress:
		if should_allow_legacy_plain_json:
			deserialize_result = _try_legacy_plain_json(bytes, should_normalize_json_numbers)
		if GFVariantData.get_option_bool(deserialize_result, "ok"):
			payload_bytes = bytes
		else:
			deserialize_result.clear()
			payload_bytes = payload_bytes.decompress_dynamic(
				GFVariantData.get_option_int(options, "max_decompressed_bytes", max_decompressed_bytes),
				_COMPRESSION_MODE
			)
			if payload_bytes.is_empty() and not bytes.is_empty():
				return _make_result(false, {}, "Decompression failed", true)

	if deserialize_result.is_empty():
		deserialize_result = _try_deserialize_dictionary(
			payload_bytes,
			active_format,
			should_normalize_json_numbers
		)
	var data: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(deserialize_result, "data", {}))
	if (
		should_allow_legacy_plain_json
		and not GFVariantData.get_option_bool(deserialize_result, "ok")
		and not payload_bytes.is_empty()
	):
		var fallback_result: Dictionary = _try_legacy_plain_json(bytes, should_normalize_json_numbers)
		if GFVariantData.get_option_bool(fallback_result, "ok"):
			data = GFVariantData.as_dictionary(GFVariantData.get_option_value(fallback_result, "data", {}))
			deserialize_result = fallback_result

	if not GFVariantData.get_option_bool(deserialize_result, "ok") and not payload_bytes.is_empty():
		return _make_result(false, {}, "Decode failed", true)

	var integrity_valid: bool = true
	if should_verify_checksum:
		var has_checksum: bool = has_integrity_checksum(data)
		integrity_valid = has_checksum and verify_integrity(data, active_format)
		if not has_checksum and not should_require_checksum:
			integrity_valid = true
		elif not has_checksum and should_reject_bad_checksum:
			return _make_result(false, _get_user_payload(data), "Integrity checksum missing", false, get_metadata(data))
		if not integrity_valid and should_reject_bad_checksum:
			return _make_result(false, _get_user_payload(data), "Integrity checksum mismatch", false, get_metadata(data))

	return _make_result(true, _get_user_payload(data), "", integrity_valid, get_metadata(data))


## 序列化字典。JSON 格式会递归排序字典键，并把 Godot 值类型转为 JSON 安全标记。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param data: 要序列化的数据。
## [br]
## @param p_format: 目标格式。
## [br]
## @schema data: Dictionary，要序列化的数据载荷。
## [br]
## @return 字节数组。
func serialize_dictionary(data: Dictionary, p_format: Format = Format.JSON) -> PackedByteArray:
	return _serialize_dictionary(data, p_format)


## 反序列化字典。
## [br]
## @api public
## [br]
## @param bytes: 源 bytes。
## [br]
## @param p_format: 源格式。
## [br]
## @return 字典；失败时返回空字典。
## [br]
## @schema return: Dictionary，从字节解析出的数据；解析失败时为空字典。
func deserialize_dictionary(bytes: PackedByteArray, p_format: Format = Format.JSON) -> Dictionary:
	return _deserialize_dictionary(bytes, p_format)


## 计算当前数据按指定格式序列化后的 SHA-256。
## JSON 格式会在 checksum 输入中规范化整数字面量，避免不同 Godot 版本解析 JSON 数字类型导致误判损坏。
## [br]
## @api public
## [br]
## @param data: 输入数据。
## [br]
## @param p_format: 序列化格式。
## [br]
## @schema data: Dictionary，用作校验和输入的数据载荷。
## [br]
## @return checksum hex 字符串。
func calculate_checksum(data: Dictionary, p_format: Format = Format.JSON) -> String:
	var checksum_data: Dictionary = _normalize_checksum_data(data, p_format)
	var bytes: PackedByteArray = _serialize_dictionary(checksum_data, p_format)
	var hashing: HashingContext = HashingContext.new()
	var _start_error: Error = hashing.start(HashingContext.HASH_SHA256)
	var _update_error: Error = hashing.update(bytes)
	return hashing.finish().hex_encode()


## 校验 `_meta.checksum`。
## [br]
## @api public
## [br]
## @param data: 包含可选 `_meta.checksum` 的字典。
## [br]
## @param p_format: checksum 计算使用的格式。
## [br]
## @schema data: Dictionary，包含可选 `_meta.checksum` 的数据载荷。
## [br]
## @return 缺少 checksum 或校验通过时返回 true。
func verify_integrity(data: Dictionary, p_format: Format = Format.JSON) -> bool:
	var metadata: Dictionary = get_metadata(data)
	if not metadata.has(CHECKSUM_KEY):
		return true

	var expected: String = GFVariantData.get_option_string(metadata, CHECKSUM_KEY)
	var copy: Dictionary = data.duplicate(true)
	var copy_metadata: Dictionary = get_metadata(copy)
	var _checksum_erased: bool = copy_metadata.erase(CHECKSUM_KEY)
	if copy_metadata.is_empty():
		var _metadata_erased: bool = copy.erase(META_KEY)
	else:
		copy[META_KEY] = copy_metadata

	return calculate_checksum(copy, p_format) == expected


## 获取存档元信息副本。
## [br]
## @api public
## [br]
## @param data: 存档数据。
## [br]
## @return `_meta` 字典副本；不存在时为空字典。
## [br]
## @schema data: Dictionary，可能包含 `_meta` 的数据载荷。
## [br]
## @schema return: Dictionary，从 `_meta` 复制出的元数据；不存在元数据时为空字典。
func get_metadata(data: Dictionary) -> Dictionary:
	var metadata_variant: Variant = GFVariantData.get_option_value(data, META_KEY, {})
	if metadata_variant is Dictionary:
		var metadata: Dictionary = metadata_variant
		return metadata.duplicate(true)
	return {}


## 判断字典是否包含完整性 checksum。
## [br]
## @api public
## [br]
## @param data: 存档数据。
## [br]
## @schema data: Dictionary，可能包含 `_meta.checksum` 的数据载荷。
## [br]
## @return 包含 `_meta.checksum` 时返回 true。
func has_integrity_checksum(data: Dictionary) -> bool:
	return get_metadata(data).has(CHECKSUM_KEY)


# --- 私有/辅助方法 ---

func _prepare_metadata(
	payload: Dictionary,
	active_format: Format,
	should_compress: bool,
	should_write_checksum: bool,
	options: Dictionary
) -> void:
	var metadata: Dictionary = get_metadata(payload)
	var should_include_metadata: bool = GFVariantData.get_option_bool(options, "include_metadata", include_metadata)
	if should_include_metadata:
		metadata[VERSION_KEY] = GFVariantData.get_option_int(options, "version", version)
		metadata[TIMESTAMP_KEY] = Time.get_datetime_string_from_system(true, true)
		metadata[FORMAT_KEY] = _format_to_string(active_format)
		if should_compress:
			metadata[COMPRESSION_KEY] = "deflate"

	if metadata.is_empty():
		var _metadata_erased: bool = payload.erase(META_KEY)
	else:
		payload[META_KEY] = metadata

	if should_write_checksum:
		var _checksum_erased: bool = metadata.erase(CHECKSUM_KEY)
		if metadata.is_empty():
			var _checksum_metadata_erased: bool = payload.erase(META_KEY)
		else:
			payload[META_KEY] = metadata
		metadata[CHECKSUM_KEY] = calculate_checksum(payload, active_format)
		payload[META_KEY] = metadata


func _make_storage_payload(data: Dictionary, should_write_metadata: bool) -> Dictionary:
	var payload: Dictionary = data.duplicate(true)
	if (
		(should_write_metadata and payload.has(META_KEY))
		or payload.has(ENVELOPE_KEY)
		or payload.has(ENVELOPE_VERSION_KEY)
	):
		return {
			ENVELOPE_KEY: true,
			ENVELOPE_VERSION_KEY: ENVELOPE_VERSION,
			ENVELOPE_DATA_KEY: payload,
		}
	return payload


func _get_user_payload(data: Dictionary) -> Dictionary:
	if _is_storage_envelope(data):
		return GFVariantData.to_dictionary(GFVariantData.get_option_value(data, ENVELOPE_DATA_KEY, {}))
	return data


func _is_storage_envelope(data: Dictionary) -> bool:
	if not data.has(ENVELOPE_KEY) or not data[ENVELOPE_KEY] is bool or not data[ENVELOPE_KEY]:
		return false
	if GFVariantData.get_option_int(data, ENVELOPE_VERSION_KEY, -1) != ENVELOPE_VERSION:
		return false
	if not GFVariantData.get_option_value(data, ENVELOPE_DATA_KEY) is Dictionary:
		return false
	for key: Variant in data.keys():
		if key != ENVELOPE_KEY and key != ENVELOPE_VERSION_KEY and key != ENVELOPE_DATA_KEY and key != META_KEY:
			return false
	return true


func _serialize_dictionary(data: Dictionary, p_format: Format) -> PackedByteArray:
	match p_format:
		Format.BINARY:
			return var_to_bytes(data)
		_:
			var sorted_data: Dictionary = GFVariantData.as_dictionary(_sort_value_recursive(data))
			return GFVariantJsonCodec.stringify_json_compatible(sorted_data, "", true).to_utf8_buffer()


func _deserialize_dictionary(bytes: PackedByteArray, p_format: Format) -> Dictionary:
	var result: Dictionary = _try_deserialize_dictionary(bytes, p_format, normalize_json_numbers)
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(result, "data", {}))


func _try_deserialize_dictionary(
	bytes: PackedByteArray,
	p_format: Format,
	should_normalize_json_numbers: bool
) -> Dictionary:
	match p_format:
		Format.BINARY:
			var value: Variant = bytes_to_var(bytes)
			if value is Dictionary:
				var data: Dictionary = value
				return { "ok": true, "data": data }
			return { "ok": false, "data": {} }
		_:
			var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			var restored: Variant = GFVariantJsonCodec.json_compatible_to_variant(parsed)
			if restored is Dictionary:
				var data: Dictionary = restored
				if should_normalize_json_numbers:
					data = _normalize_dictionary_numbers(data)
				return { "ok": true, "data": data }
			return { "ok": false, "data": {} }


func _sort_value_recursive(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var dictionary: Dictionary = value
		var keys: Array = dictionary.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool:
			return _make_dictionary_sort_key(left) < _make_dictionary_sort_key(right)
		)
		for key: Variant in keys:
			result[key] = _sort_value_recursive(dictionary[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_sort_value_recursive(item))
		return result
	return value


func _make_dictionary_sort_key(key: Variant) -> String:
	var stable_token: String = GFVariantKeyCodec.make_key_token(key)
	if not stable_token.is_empty():
		return stable_token

	var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible(key, {
		"encode_dictionary_keys": true,
		"encode_unsafe_ints": true,
	})
	return "gfv1:%s:%s" % [type_string(typeof(key)), JSON.stringify(encoded, "", true)]


func _normalize_checksum_data(data: Dictionary, p_format: Format) -> Dictionary:
	if p_format != Format.JSON:
		return data

	var normalized: Dictionary = _normalize_dictionary_numbers(data)
	var bytes: PackedByteArray = _serialize_dictionary(normalized, p_format)
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if parsed is Dictionary:
		var parsed_dictionary: Dictionary = parsed
		return _normalize_dictionary_numbers(parsed_dictionary)
	return normalized


func _normalize_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		var dictionary: Dictionary = value
		for key: Variant in dictionary.keys():
			result[key] = _normalize_numbers(dictionary[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_normalize_numbers(item))
		return result
	if value is float:
		var float_value: float = value
		if is_equal_approx(float_value, floorf(float_value)):
			return int(float_value)
	return value


func _normalize_dictionary_numbers(data: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(_normalize_numbers(data))


func _decode_obfuscation(
	bytes: PackedByteArray,
	key: int,
	should_allow_legacy_plain_json: bool
) -> PackedByteArray:
	if key == 0:
		return bytes

	var encoded_text: String = bytes.get_string_from_utf8().strip_edges()
	if not _looks_like_base64_text(encoded_text):
		return bytes if should_allow_legacy_plain_json else PackedByteArray()

	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded_text)
	if raw.is_empty() and not bytes.is_empty() and should_allow_legacy_plain_json:
		return bytes
	return _obfuscate_bytes(raw, key)


func _looks_like_base64_text(text: String) -> bool:
	if text.is_empty() or text.length() % 4 != 0:
		return false

	var padding_count: int = 0
	var padding_started: bool = false
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		if code == 61:
			padding_started = true
			padding_count += 1
			if padding_count > 2:
				return false
			continue
		if padding_started:
			return false
		if not _is_base64_code(code):
			return false
	return true


func _is_base64_code(code: int) -> bool:
	return (
		(code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)
		or (code >= 48 and code <= 57)
		or code == 43
		or code == 47
	)


func _obfuscate_bytes(bytes: PackedByteArray, key: int) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray(bytes)
	var key_byte: int = key & 0xff
	for index: int in range(result.size()):
		result[index] = result[index] ^ key_byte
	return result


func _try_legacy_plain_json(bytes: PackedByteArray, should_normalize_json_numbers: bool) -> Dictionary:
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	var restored: Variant = GFVariantJsonCodec.json_compatible_to_variant(parsed)
	if restored is Dictionary:
		var data: Dictionary = restored
		if should_normalize_json_numbers:
			data = _normalize_dictionary_numbers(data)
		return GFResultDictionary.make_success({
			GFResultDictionary.KEY_DATA: data,
		})
	return GFResultDictionary.make_failure("", {
		GFResultDictionary.KEY_DATA: {},
	})


func _make_result(
	ok: bool,
	data: Dictionary,
	error: String,
	integrity_valid: bool,
	metadata: Dictionary = {}
) -> Dictionary:
	var result_metadata: Dictionary = metadata if not metadata.is_empty() else get_metadata(data)
	return GFResultDictionary.make(ok, {
		GFResultDictionary.KEY_DATA: data,
		GFResultDictionary.KEY_METADATA: result_metadata,
		GFResultDictionary.KEY_INTEGRITY_VALID: integrity_valid,
		GFResultDictionary.KEY_ERROR: error,
	})


func _get_format(options: Dictionary) -> Format:
	return _variant_to_format(GFVariantData.get_option_value(options, "format", format), format)


static func _variant_to_format(value: Variant, fallback: Format) -> Format:
	var format_value: int = GFVariantData.to_int(value, int(fallback))
	if not Format.values().has(format_value):
		return fallback
	return _to_format(format_value, fallback)


static func _to_format(value: int, fallback: Format) -> Format:
	match value:
		Format.BINARY:
			return Format.BINARY
		Format.JSON:
			return Format.JSON
		_:
			return fallback


func _format_to_string(p_format: Format) -> String:
	match p_format:
		Format.BINARY:
			return "binary"
		_:
			return "json"
