@tool

## GFStorageCodec: 通用存档字典编码与解码策略。
##
## 负责严格存储文档的字典序列化、可选压缩、完整性校验和轻量混淆。
## JSON 格式会通过 GFVariantJsonCodec 保留 Godot 值类型和非有限浮点数。
## 业务载荷始终位于独立 payload 字段中，框架元数据不会进入业务字典。
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

## 存储文档描述字段名。
## [br]
## @api public
## [br]
## @since 9.0.0
const DOCUMENT_KEY: String = "__gf_storage_document"

## 存储文档业务载荷字段名。
## [br]
## @api public
## [br]
## @since 9.0.0
const PAYLOAD_KEY: String = "payload"

## 文档 schema 版本字段名。
## [br]
## @api public
## [br]
## @since 9.0.0
const SCHEMA_VERSION_KEY: String = "schema_version"

## 存储元信息字段名。
## [br]
## @api public
## [br]
## @since 9.0.0
const METADATA_KEY: String = "metadata"

## 存储完整性描述字段名。
## [br]
## @api public
## [br]
## @since 9.0.0
const INTEGRITY_KEY: String = "integrity"

## 完整性算法字段名。
## [br]
## @api public
## [br]
## @since 9.0.0
const ALGORITHM_KEY: String = "algorithm"

## 完整性摘要字段名。
## [br]
## @api public
## [br]
## @since 9.0.0
const DIGEST_KEY: String = "digest"

## 存储版本字段名。
## [br]
## @api public
## [br]
## @since 9.0.0
const VERSION_KEY: String = "data_version"

## 存储时间戳字段名。
## [br]
## @api public
## [br]
## @since 9.0.0
const TIMESTAMP_KEY: String = "timestamp"

## 存储编码格式字段名。
## [br]
## @api public
## [br]
## @since 9.0.0
const FORMAT_KEY: String = "format"

## 存储压缩方式字段名。
## [br]
## @api public
## [br]
## @since 9.0.0
const COMPRESSION_KEY: String = "compression"

## 当前存储文档 schema 版本。
## [br]
## @api public
## [br]
## @since 9.0.0
const DOCUMENT_SCHEMA_VERSION: int = 2

const _COMPRESSION_MODE: int = FileAccess.COMPRESSION_DEFLATE
const _INTEGRITY_ALGORITHM: String = "sha256"
const _METADATA_FIELDS: Array = [
	VERSION_KEY,
	TIMESTAMP_KEY,
	FORMAT_KEY,
	COMPRESSION_KEY,
]


# --- 导出变量 ---

## 默认序列化格式。
## [br]
## @api public
@export var format: Format = Format.JSON

## 是否压缩载荷。
## [br]
## @api public
@export var use_compression: bool = false

## 是否在文档完整性描述中写入 SHA-256 摘要。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var use_integrity_checksum: bool = false

## 校验失败时是否拒绝读取。
## [br]
## @api public
@export var strict_integrity: bool = true

## 启用完整性校验时，是否要求文档必须包含 SHA-256 摘要。
## [br]
## @api public
## [br]
## @since 9.0.0
@export var require_integrity_checksum: bool = true

## 是否写入时间戳、编码格式和压缩方式等诊断元数据。
## 数据版本始终写入，不受该选项影响。
## [br]
## @api public
## [br]
## @since 9.0.0
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

## JSON 解码时是否把接近整数的 float 归一为 int。Binary 格式不受影响。
## [br]
## @api public
@export var normalize_json_numbers: bool = false


# --- 公共方法 ---

## 将字典编码为可写入文件的 bytes。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param data: 要编码的数据。
## [br]
## @param options: 临时覆盖当前 codec 设置的选项字典。
## [br]
## @schema data: Dictionary，要序列化的业务载荷；所有键都会原样保存在独立 payload 中。
## [br]
## @schema options: Dictionary，可包含 format、use_compression、obfuscation_key、use_integrity_checksum、include_metadata、version 和 max_decompressed_bytes。
## [br]
## @return 编码后的 bytes。
func encode(data: Dictionary, options: Dictionary = {}) -> PackedByteArray:
	var active_format: Format = _get_format(options)
	var should_compress: bool = GFVariantData.get_option_bool(options, "use_compression", use_compression)
	var key: int = GFVariantData.get_option_int(options, "obfuscation_key", obfuscation_key)
	var should_write_checksum: bool = GFVariantData.get_option_bool(options, "use_integrity_checksum", use_integrity_checksum)
	var document: Dictionary = _make_storage_document(
		data,
		active_format,
		should_compress,
		should_write_checksum,
		options
	)
	var bytes: PackedByteArray = _serialize_dictionary(document, active_format)
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
## @since 9.0.0
## [br]
## @param bytes: 文件读取到的 bytes。
## [br]
## @param options: 临时覆盖当前 codec 设置的选项字典。
## [br]
## @return 强类型读取结果；业务载荷与框架元数据保持隔离。
## [br]
## @schema options: Dictionary，可包含 format、use_compression、obfuscation_key、use_integrity_checksum、strict_integrity、normalize_json_numbers、require_integrity_checksum 和 max_decompressed_bytes。
func decode(bytes: PackedByteArray, options: Dictionary = {}) -> GFStorageReadResult:
	var active_format: Format = _get_format(options)
	var should_compress: bool = GFVariantData.get_option_bool(options, "use_compression", use_compression)
	var key: int = GFVariantData.get_option_int(options, "obfuscation_key", obfuscation_key)
	var should_verify_checksum: bool = GFVariantData.get_option_bool(options, "use_integrity_checksum", use_integrity_checksum)
	var should_reject_bad_checksum: bool = GFVariantData.get_option_bool(options, "strict_integrity", strict_integrity)
	var should_normalize_json_numbers: bool = GFVariantData.get_option_bool(options, "normalize_json_numbers", normalize_json_numbers)
	var should_require_checksum: bool = GFVariantData.get_option_bool(
		options,
		"require_integrity_checksum",
		require_integrity_checksum
	)
	var payload_bytes: PackedByteArray = _decode_obfuscation(bytes, key)
	if payload_bytes.is_empty():
		return _make_failure("Payload is empty", ERR_FILE_CORRUPT)

	if should_compress:
		payload_bytes = payload_bytes.decompress_dynamic(
			GFVariantData.get_option_int(options, "max_decompressed_bytes", max_decompressed_bytes),
			_COMPRESSION_MODE
		)
		if payload_bytes.is_empty() and not bytes.is_empty():
			return _make_failure("Decompression failed", ERR_FILE_CORRUPT)

	var deserialize_result: Dictionary = _try_deserialize_dictionary(
		payload_bytes,
		active_format,
		should_normalize_json_numbers
	)
	if not GFVariantData.get_option_bool(deserialize_result, "ok"):
		return _make_failure("Decode failed", ERR_PARSE_ERROR)

	var document: Dictionary = GFVariantData.get_option_dictionary(deserialize_result, "data")
	var validation_error: String = _validate_storage_document(document)
	if not validation_error.is_empty():
		return _make_failure(validation_error, ERR_FILE_UNRECOGNIZED)

	var descriptor: Dictionary = GFVariantData.get_option_dictionary(document, DOCUMENT_KEY)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(descriptor, METADATA_KEY)
	var payload: Dictionary = GFVariantData.get_option_dictionary(document, PAYLOAD_KEY)
	var integrity: Dictionary = GFVariantData.get_option_dictionary(descriptor, INTEGRITY_KEY)
	var document_schema_version: int = GFVariantData.to_exact_int(
		GFVariantData.get_option_value(descriptor, SCHEMA_VERSION_KEY)
	)
	var has_digest: bool = integrity.has(DIGEST_KEY)
	var integrity_status: GFStorageReadResult.IntegrityStatus = GFStorageReadResult.IntegrityStatus.NOT_CHECKED

	if has_digest:
		if GFVariantData.get_option_string(integrity, ALGORITHM_KEY) != _INTEGRITY_ALGORITHM:
			return _make_failure(
				"Unsupported integrity algorithm",
				ERR_FILE_UNRECOGNIZED,
				metadata,
				GFStorageReadResult.IntegrityStatus.INVALID,
				document_schema_version
			)
		if _verify_document_integrity(document, active_format):
			integrity_status = GFStorageReadResult.IntegrityStatus.VALID
		else:
			integrity_status = GFStorageReadResult.IntegrityStatus.INVALID
			if should_reject_bad_checksum:
				return _make_failure(
					"Integrity checksum mismatch",
					ERR_FILE_CORRUPT,
					metadata,
					integrity_status,
					document_schema_version
				)
	elif should_verify_checksum and should_require_checksum:
		return _make_failure(
			"Integrity checksum missing",
			ERR_FILE_CORRUPT,
			metadata,
			GFStorageReadResult.IntegrityStatus.MISSING,
			document_schema_version
		)

	return GFStorageReadResult.new().configure_success(
		payload,
		metadata,
		integrity_status,
		document_schema_version
	)


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


# --- 私有/辅助方法 ---

func _make_storage_document(
	payload: Dictionary,
	active_format: Format,
	should_compress: bool,
	should_write_checksum: bool,
	options: Dictionary
) -> Dictionary:
	var metadata: Dictionary = {
		VERSION_KEY: maxi(GFVariantData.get_option_int(options, "version", version), 1),
	}
	var should_include_metadata: bool = GFVariantData.get_option_bool(options, "include_metadata", include_metadata)
	if should_include_metadata:
		metadata[TIMESTAMP_KEY] = Time.get_datetime_string_from_system(true, true)
		metadata[FORMAT_KEY] = _format_to_string(active_format)
		if should_compress:
			metadata[COMPRESSION_KEY] = "deflate"

	var integrity: Dictionary = {}
	var descriptor: Dictionary = {
		SCHEMA_VERSION_KEY: DOCUMENT_SCHEMA_VERSION,
		METADATA_KEY: metadata,
		INTEGRITY_KEY: integrity,
	}
	var document: Dictionary = {
		DOCUMENT_KEY: descriptor,
		PAYLOAD_KEY: payload.duplicate(true),
	}
	if should_write_checksum:
		integrity[ALGORITHM_KEY] = _INTEGRITY_ALGORITHM
		integrity[DIGEST_KEY] = calculate_checksum(document, active_format)
		descriptor[INTEGRITY_KEY] = integrity
		document[DOCUMENT_KEY] = descriptor
	return document


func _validate_storage_document(document: Dictionary) -> String:
	if document.size() != 2 or not document.has(DOCUMENT_KEY) or not document.has(PAYLOAD_KEY):
		return "Storage document envelope missing or malformed"
	if not GFVariantData.get_option_value(document, DOCUMENT_KEY) is Dictionary:
		return "Storage document descriptor is not a Dictionary"
	if not GFVariantData.get_option_value(document, PAYLOAD_KEY) is Dictionary:
		return "Storage document payload is not a Dictionary"

	var descriptor: Dictionary = GFVariantData.get_option_dictionary(document, DOCUMENT_KEY)
	if descriptor.size() != 3:
		return "Storage document descriptor contains unsupported fields"
	if (
		not descriptor.has(SCHEMA_VERSION_KEY)
		or not descriptor.has(METADATA_KEY)
		or not descriptor.has(INTEGRITY_KEY)
	):
		return "Storage document descriptor is incomplete"
	var schema_version_value: Variant = GFVariantData.get_option_value(descriptor, SCHEMA_VERSION_KEY)
	if not GFVariantData.is_exact_integer(schema_version_value):
		return "Storage document schema_version must be an integer"
	var schema_version: int = GFVariantData.to_exact_int(schema_version_value, -1)
	if schema_version != DOCUMENT_SCHEMA_VERSION:
		return "Unsupported storage document schema: %d" % schema_version
	if not GFVariantData.get_option_value(descriptor, METADATA_KEY) is Dictionary:
		return "Storage document metadata is not a Dictionary"
	if not GFVariantData.get_option_value(descriptor, INTEGRITY_KEY) is Dictionary:
		return "Storage document integrity descriptor is not a Dictionary"

	var metadata: Dictionary = GFVariantData.get_option_dictionary(descriptor, METADATA_KEY)
	for metadata_key: Variant in metadata.keys():
		if typeof(metadata_key) != TYPE_STRING or not _METADATA_FIELDS.has(metadata_key):
			return "Storage document metadata contains unsupported fields"
	var data_version_value: Variant = GFVariantData.get_option_value(metadata, VERSION_KEY)
	if (
		not GFVariantData.is_exact_integer(data_version_value)
		or GFVariantData.to_exact_int(data_version_value) <= 0
	):
		return "Storage document data_version is missing or invalid"
	if metadata.has(TIMESTAMP_KEY):
		var timestamp_value: Variant = GFVariantData.get_option_value(metadata, TIMESTAMP_KEY)
		if typeof(timestamp_value) != TYPE_STRING or GFVariantData.to_text(timestamp_value).is_empty():
			return "Storage document timestamp is invalid"
	if metadata.has(FORMAT_KEY):
		var format_value: Variant = GFVariantData.get_option_value(metadata, FORMAT_KEY)
		if (
			typeof(format_value) != TYPE_STRING
			or not ["json", "binary"].has(GFVariantData.to_text(format_value))
		):
			return "Storage document format metadata is invalid"
	if metadata.has(COMPRESSION_KEY):
		var compression_value: Variant = GFVariantData.get_option_value(metadata, COMPRESSION_KEY)
		if typeof(compression_value) != TYPE_STRING or GFVariantData.to_text(compression_value) != "deflate":
			return "Storage document compression metadata is invalid"
	var integrity: Dictionary = GFVariantData.get_option_dictionary(descriptor, INTEGRITY_KEY)
	if integrity.is_empty():
		return ""
	if integrity.size() != 2 or not integrity.has(ALGORITHM_KEY) or not integrity.has(DIGEST_KEY):
		return "Storage document integrity descriptor is incomplete"
	var algorithm_value: Variant = GFVariantData.get_option_value(integrity, ALGORITHM_KEY)
	if typeof(algorithm_value) != TYPE_STRING or GFVariantData.to_text(algorithm_value).is_empty():
		return "Storage document integrity algorithm is empty"
	var digest_value: Variant = GFVariantData.get_option_value(integrity, DIGEST_KEY)
	if typeof(digest_value) != TYPE_STRING or GFVariantData.to_text(digest_value).is_empty():
		return "Storage document integrity digest is empty"
	return ""


func _verify_document_integrity(document: Dictionary, active_format: Format) -> bool:
	var descriptor: Dictionary = GFVariantData.get_option_dictionary(document, DOCUMENT_KEY)
	var integrity: Dictionary = GFVariantData.get_option_dictionary(descriptor, INTEGRITY_KEY)
	var expected: String = GFVariantData.get_option_string(integrity, DIGEST_KEY)
	if expected.is_empty():
		return false

	var checksum_document: Dictionary = document.duplicate(true)
	var checksum_descriptor: Dictionary = GFVariantData.get_option_dictionary(checksum_document, DOCUMENT_KEY)
	var checksum_integrity: Dictionary = GFVariantData.get_option_dictionary(checksum_descriptor, INTEGRITY_KEY)
	var _digest_erased: bool = checksum_integrity.erase(DIGEST_KEY)
	checksum_descriptor[INTEGRITY_KEY] = checksum_integrity
	checksum_document[DOCUMENT_KEY] = checksum_descriptor
	return calculate_checksum(checksum_document, active_format) == expected


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
	key: int
) -> PackedByteArray:
	if key == 0:
		return bytes

	var encoded_text: String = bytes.get_string_from_utf8().strip_edges()
	if not _looks_like_base64_text(encoded_text):
		return PackedByteArray()

	var raw: PackedByteArray = Marshalls.base64_to_raw(encoded_text)
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


func _make_failure(
	error_message: String,
	error_code: Error,
	metadata: Dictionary = {},
	integrity_status: GFStorageReadResult.IntegrityStatus = GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
	document_schema_version: int = 0
) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_failure(
		error_message,
		error_code,
		metadata,
		integrity_status,
		document_schema_version
	)


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
