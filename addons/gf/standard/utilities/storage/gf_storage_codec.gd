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

## 存储文档压缩使用的 Deflate 模式。
## [br]
## @api private
## [br]
const _COMPRESSION_MODE: int = FileAccess.COMPRESSION_DEFLATE

## 完整性摘要采用的算法标识。
## [br]
## @api private
## [br]
const _INTEGRITY_ALGORITHM: String = "sha256"

## JSON codec 用于标记遍历上限错误的类型名。
## [br]
## @api private
## [br]
const _TRAVERSAL_LIMIT_TYPE_NAME: String = "TraversalLimit"

## 存储文档 metadata 允许出现的字段名集合。
## [br]
## @api private
## [br]
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

## 解混淆、解压后允许交给解析器的最大明文字节数，默认 64 MiB。
## 只能设置正数，无效赋值保留原值；该上限不表示 Variant 堆内存或解析耗时上限。
## [br]
## @api public
## [br]
## @since unreleased
@export var max_decode_bytes: int = 64 * 1024 * 1024:
	set(value):
		if value <= 0:
			push_error("[GFStorageCodec][storage_codec.decode_limit_invalid] max_decode_bytes must be positive.")
			return
		max_decode_bytes = value

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
## @schema options: Dictionary，可包含 format、use_compression、obfuscation_key、use_integrity_checksum、include_metadata 和 version。
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
	if bytes.is_empty():
		return bytes
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
## @schema options: Dictionary，可包含 format、use_compression、obfuscation_key、use_integrity_checksum、strict_integrity、normalize_json_numbers、require_integrity_checksum 和 max_decode_bytes；字节上限必须是正 int，默认 64 MiB，同时约束解压输出和明文解析。已移除的 max_decompressed_bytes 选项被拒绝，不提供别名。JSON 解码还受 GFVariantJsonCodec 默认遍历预算约束，超限不返回部分载荷。无法区分损坏流与输出预算耗尽的解压失败保守返回 LIMIT_EXCEEDED。
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
	var decode_limit: int = _get_positive_decode_limit(options, "max_decode_bytes", max_decode_bytes)
	if decode_limit <= 0 or options.has("max_decompressed_bytes"):
		var reason: String = (
			"max_decompressed_bytes was removed; use max_decode_bytes"
			if options.has("max_decompressed_bytes")
			else "max_decode_bytes must be a positive integer"
		)
		return _make_failure(
			reason, ERR_INVALID_PARAMETER,
			{}, GFStorageReadResult.IntegrityStatus.NOT_CHECKED, 0,
			GFStorageReadResult.FailureKind.INVALID_REQUEST
		)
	var payload_bytes: PackedByteArray = _decode_obfuscation(bytes, key)
	if payload_bytes.is_empty():
		return _make_failure("Payload is empty", ERR_FILE_CORRUPT)

	if should_compress:
		payload_bytes = payload_bytes.decompress_dynamic(
			decode_limit,
			_COMPRESSION_MODE
		)
		if payload_bytes.is_empty() and not bytes.is_empty():
			return _make_limit_failure("Decompression failed or exceeded the decode byte limit")
	if payload_bytes.size() > decode_limit:
		return _make_limit_failure("Decoded plaintext exceeds max_decode_bytes")

	var deserialize_result: Dictionary = _try_deserialize_dictionary(
		payload_bytes,
		active_format,
		should_normalize_json_numbers,
		decode_limit
	)
	if not GFVariantData.get_option_bool(deserialize_result, "ok"):
		if GFVariantData.get_option_bool(deserialize_result, "limit_exceeded"):
			return _make_limit_failure("JSON decode traversal exceeded its budget")
		return _make_failure("Decode failed", ERR_PARSE_ERROR)

	var document: Dictionary = GFVariantData.get_option_dictionary(deserialize_result, "data")
	var declared_schema_version: int = _get_declared_document_schema_version(document)
	if declared_schema_version > DOCUMENT_SCHEMA_VERSION:
		var future_descriptor: Dictionary = GFVariantData.get_option_dictionary(
			document,
			DOCUMENT_KEY
		)
		return _make_failure(
			"Unsupported future storage document schema: %d > %d" % [
				declared_schema_version,
				DOCUMENT_SCHEMA_VERSION,
			],
			ERR_FILE_UNRECOGNIZED,
			GFVariantData.get_option_dictionary(future_descriptor, METADATA_KEY),
			GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
			declared_schema_version,
			GFStorageReadResult.FailureKind.FUTURE_VERSION
		)
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


## 反序列化字典；超过 max_decode_bytes 或 JSON 默认遍历预算时返回空字典。
## [br]
## @api public
## [br]
## @since 3.17.0
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
	if bytes.is_empty():
		return ""
	var hashing: HashingContext = HashingContext.new()
	var _start_error: Error = hashing.start(HashingContext.HASH_SHA256)
	var _update_error: Error = hashing.update(bytes)
	return hashing.finish().hex_encode()


# --- 私有/辅助方法 ---

## 组合 schema 描述、元数据、payload 和可选完整性摘要形成存储文档。
## [br]
## @api private
## [br]
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


## 验证文档外层、descriptor、schema、metadata 与 integrity 字段形状；有效时返回空字符串。
## [br]
## @api private
## [br]
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


## 从 descriptor 读取精确整数 schema_version；结构不符或类型错误时返回 -1。
## [br]
## @api private
## [br]
func _get_declared_document_schema_version(document: Dictionary) -> int:
	var descriptor_value: Variant = GFVariantData.get_option_value(document, DOCUMENT_KEY)
	if not descriptor_value is Dictionary:
		return -1
	var descriptor: Dictionary = descriptor_value
	var schema_version_value: Variant = GFVariantData.get_option_value(
		descriptor,
		SCHEMA_VERSION_KEY
	)
	if not GFVariantData.is_exact_integer(schema_version_value):
		return -1
	return GFVariantData.to_exact_int(schema_version_value, -1)


## 移除摘要字段后按指定格式重算 checksum，并与文档中的摘要比较。
## [br]
## @api private
## [br]
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


## 按目标格式序列化字典；JSON 路径先稳定排序并转换 Godot 值标记。
## [br]
## @api private
## [br]
func _serialize_dictionary(data: Dictionary, p_format: Format) -> PackedByteArray:
	match p_format:
		Format.BINARY:
			return var_to_bytes(data)
		_:
			var sorted_data: Dictionary = GFVariantData.as_dictionary(_sort_value_recursive(data))
			var json_value: Variant = GFVariantJsonCodec.variant_to_json_compatible(sorted_data)
			if _is_json_traversal_limit_marker(json_value):
				return PackedByteArray()
			return JSON.stringify(json_value, "", true).to_utf8_buffer()


## 检查值是否为 GFVariantJsonCodec 的完整 TraversalLimit 标记，以阻止输出该错误值。
## [br]
## @api private
## [br]
func _is_json_traversal_limit_marker(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var document: Dictionary = value
	if document.size() != 1 or not document.has(GFVariantJsonCodec.JSON_MARKER_KEY):
		return false
	var marker_value: Variant = GFVariantData.get_option_value(
		document,
		GFVariantJsonCodec.JSON_MARKER_KEY
	)
	if not (marker_value is Dictionary):
		return false
	var marker: Dictionary = marker_value
	return (
		GFVariantData.get_option_int(marker, GFVariantJsonCodec.JSON_VERSION_KEY, 0)
		== GFVariantJsonCodec.JSON_SCHEMA_VERSION
		and GFVariantData.get_option_string(marker, GFVariantJsonCodec.JSON_CODEC_KEY)
		== GFVariantJsonCodec.JSON_CODEC_ID
		and GFVariantData.get_option_string(marker, GFVariantJsonCodec.JSON_TYPE_KEY)
		== _TRAVERSAL_LIMIT_TYPE_NAME
		and marker.has(GFVariantJsonCodec.JSON_VALUE_KEY)
	)


## 经通用反序列化器读取字典；失败结果被转换为空字典。
## [br]
## @api private
## [br]
func _deserialize_dictionary(bytes: PackedByteArray, p_format: Format) -> Dictionary:
	var result: Dictionary = _try_deserialize_dictionary(bytes, p_format, normalize_json_numbers, max_decode_bytes)
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(result, "data", {}))


## 在 byte_limit 内按格式解析 bytes 并严格恢复 JSON 标记；失败时返回空 data，不交付部分 marker。
## 字节或 JSON 遍历超限带 limit_exceeded，其他格式失败保留普通 decode failure。
## [br]
## @api private
## [br]
func _try_deserialize_dictionary(
	bytes: PackedByteArray,
	p_format: Format,
	should_normalize_json_numbers: bool,
	byte_limit: int
) -> Dictionary:
	if bytes.size() > byte_limit:
		return {"ok": false, "data": {}, "limit_exceeded": true}
	match p_format:
		Format.BINARY:
			var value: Variant = bytes_to_var(bytes)
			if value is Dictionary:
				var data: Dictionary = value
				return { "ok": true, "data": data }
			return { "ok": false, "data": {} }
		_:
			var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
			var decoded: Dictionary = GFVariantJsonCodec.json_compatible_to_variant_result(parsed)
			if not GFVariantData.get_option_bool(decoded, "ok"):
				var reason: String = GFVariantData.get_option_string(decoded, "error")
				return {
					"ok": false, "data": {},
					"limit_exceeded": reason in ["max_depth", "max_nodes", "max_collection_items"],
				}
			var restored: Variant = decoded.get("value")
			if restored is Dictionary:
				var data: Dictionary = restored
				if should_normalize_json_numbers:
					data = _normalize_dictionary_numbers(data)
				return { "ok": true, "data": data }
			return { "ok": false, "data": {} }


## 递归重建字典与数组，并按稳定键标记排序每层字典键。
## [br]
## @api private
## [br]
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


## 优先使用 GFVariantKeyCodec 标记；无标记时以 JSON 兼容表示和类型名构造排序键。
## [br]
## @api private
## [br]
func _make_dictionary_sort_key(key: Variant) -> String:
	var stable_token: String = GFVariantKeyCodec.make_key_token(key)
	if not stable_token.is_empty():
		return stable_token

	var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible(key, {
		"encode_dictionary_keys": true,
		"encode_unsafe_ints": true,
	})
	return "gfv1:%s:%s" % [type_string(typeof(key)), JSON.stringify(encoded, "", true)]


## Binary checksum 输入保持原字典；JSON 输入先归一数字，再经 JSON 序列化往返归一。
## [br]
## @api private
## [br]
func _normalize_checksum_data(data: Dictionary, p_format: Format) -> Dictionary:
	if p_format != Format.JSON:
		return data

	var normalized: Dictionary = _normalize_dictionary_numbers(data)
	var bytes: PackedByteArray = _serialize_dictionary(normalized, p_format)
	if bytes.is_empty():
		return normalized
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if parsed is Dictionary:
		var parsed_dictionary: Dictionary = parsed
		return _normalize_dictionary_numbers(parsed_dictionary)
	return normalized


## 递归处理字典值与数组，把近似整数的 float 转成 int；其他值保持原样。
## [br]
## @api private
## [br]
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


## 返回递归数字归一化后的 Dictionary。
## [br]
## @api private
## [br]
func _normalize_dictionary_numbers(data: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(_normalize_numbers(data))


## key 为零时原样返回 bytes；否则校验 Base64 文本、解码后执行 XOR 还原。
## [br]
## @api private
## [br]
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


## 检查 Base64 文本长度为 4 的倍数、字符集合法且末尾填充不超过两个等号。
## [br]
## @api private
## [br]
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


## 判断码点是否为 Base64 字母、数字、加号或斜杠字符。
## [br]
## @api private
## [br]
func _is_base64_code(code: int) -> bool:
	return (
		(code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)
		or (code >= 48 and code <= 57)
		or code == 43
		or code == 47
	)


## 复制输入字节并逐字节异或 key 的低 8 位。
## [br]
## @api private
## [br]
func _obfuscate_bytes(bytes: PackedByteArray, key: int) -> PackedByteArray:
	var result: PackedByteArray = PackedByteArray(bytes)
	var key_byte: int = key & 0xff
	for index: int in range(result.size()):
		result[index] = result[index] ^ key_byte
	return result


## 将读取失败字段交由 GFStorageReadResult.configure_failure 构造类型化结果。
## [br]
## @api private
## [br]
func _make_failure(
	error_message: String,
	error_code: Error,
	metadata: Dictionary = {},
	integrity_status: GFStorageReadResult.IntegrityStatus = GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
	document_schema_version: int = 0,
	failure_kind: GFStorageReadResult.FailureKind = GFStorageReadResult.FailureKind.CORRUPT
) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_failure(
		error_message,
		error_code,
		metadata,
		integrity_status,
		document_schema_version,
		failure_kind
	)


## 构造不证明文件损坏的预算拒绝；这类结果不能授权 destructive family reset。
## [br]
## @api private
func _make_limit_failure(message: String) -> GFStorageReadResult:
	return _make_failure(
		message, ERR_OUT_OF_MEMORY, {}, GFStorageReadResult.IntegrityStatus.NOT_CHECKED, 0,
		GFStorageReadResult.FailureKind.LIMIT_EXCEEDED
	)


## 读取正整数解码上限；缺省沿用配置，无效 options 返回零供调用方拒绝请求。
## [br]
## @api private
func _get_positive_decode_limit(options: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = options.get(key, fallback)
	if not value is int:
		return 0
	var limit: int = value
	return limit if limit > 0 else 0


## 读取 options.format，并以资源当前格式作为无效值的回退。
## [br]
## @api private
## [br]
func _get_format(options: Dictionary) -> Format:
	return _variant_to_format(GFVariantData.get_option_value(options, "format", format), format)


## 将任意值转成合法 Format；不属于枚举的值返回 fallback。
## [br]
## @api private
## [br]
static func _variant_to_format(value: Variant, fallback: Format) -> Format:
	var format_value: int = GFVariantData.to_int(value, int(fallback))
	if not Format.values().has(format_value):
		return fallback
	return _to_format(format_value, fallback)


## 将已检查的整数格式值映射为枚举成员，未知值使用 fallback。
## [br]
## @api private
## [br]
static func _to_format(value: int, fallback: Format) -> Format:
	match value:
		Format.BINARY:
			return Format.BINARY
		Format.JSON:
			return Format.JSON
		_:
			return fallback


## 将 BINARY 映射为 binary，其余当前格式映射为 json。
## [br]
## @api private
## [br]
func _format_to_string(p_format: Format) -> String:
	match p_format:
		Format.BINARY:
			return "binary"
		_:
			return "json"
