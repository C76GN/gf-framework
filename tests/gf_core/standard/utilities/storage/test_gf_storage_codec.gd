## 测试 GFStorageCodec 的稳定序列化、校验、压缩和混淆行为。
extends GutTest


# --- 测试方法 ---

func test_json_encoding_sorts_dictionary_keys() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()

	var left: PackedByteArray = codec.encode({ "b": 2, "a": 1 }, { "obfuscation_key": 0 })
	var right: PackedByteArray = codec.encode({ "a": 1, "b": 2 }, { "obfuscation_key": 0 })

	assert_eq(left, right, "JSON 编码应递归排序字典键，保证输出稳定。")


func test_json_encoding_sorts_non_string_dictionary_keys() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()

	var left: PackedByteArray = codec.encode({ 10: "ten", &"2": "two" }, { "obfuscation_key": 0 })
	var right: PackedByteArray = codec.encode({ &"2": "two", 10: "ten" }, { "obfuscation_key": 0 })

	assert_eq(left, right, "JSON 编码应能稳定排序非字符串键。")
	assert_false(left.is_empty(), "非字符串键不应导致 JSON 编码失败。")


func test_json_encoding_sorts_keys_by_type_aware_tokens() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()

	var left: PackedByteArray = codec.encode({ 1: "int", "1": "string" }, { "obfuscation_key": 0 })
	var right: PackedByteArray = codec.encode({ "1": "string", 1: "int" }, { "obfuscation_key": 0 })
	var result: GFStorageReadResult = codec.decode(left, { "obfuscation_key": 0 })
	var data: Dictionary = result.payload

	assert_eq(left, right, "str(key) 相同但类型不同的键也应有稳定全序。")
	assert_true(result.ok, "类型不同的键应能正常往返。")
	assert_eq(GFVariantData.get_option_string(data, 1), "int", "int key 不应与 string key 混淆。")
	assert_eq(GFVariantData.get_option_string(data, "1"), "string", "string key 不应与 int key 混淆。")


func test_json_encoding_preserves_godot_variants_and_nonfinite_values() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var packed_values: PackedFloat32Array = PackedFloat32Array()
	var _nan_appended: bool = packed_values.append(NAN)
	var _value_appended: bool = packed_values.append(3.5)

	var bytes: PackedByteArray = codec.encode({
		"position": Vector2(1.5, -2.0),
		"tint": Color(0.25, 0.5, 0.75, 1.0),
		"nan_value": NAN,
		"inf_value": INF,
		"packed": packed_values,
	}, {
		"obfuscation_key": 0,
	})
	var json_text: String = bytes.get_string_from_utf8()
	var result: GFStorageReadResult = codec.decode(bytes, {
		"obfuscation_key": 0,
	})
	var data: Dictionary = result.payload
	var position_value: Variant = GFVariantData.get_option_value(data, "position")
	var tint_value: Variant = GFVariantData.get_option_value(data, "tint")
	var nan_value: Variant = GFVariantData.get_option_value(data, "nan_value")
	var inf_value: Variant = GFVariantData.get_option_value(data, "inf_value")
	var packed_value: Variant = GFVariantData.get_option_value(data, "packed")
	var nan_preserved: bool = false
	if nan_value is float:
		var nan_float: float = nan_value
		nan_preserved = is_nan(nan_float)
	var inf_preserved: bool = false
	if inf_value is float:
		var inf_float: float = inf_value
		inf_preserved = is_inf(inf_float) and inf_float > 0.0

	assert_true(result.ok, "包含 Godot 值类型的 JSON 存档应可读取。")
	assert_false(json_text.contains(":null"), "JSON 存储不应把 NaN/Inf 交给 JSON.stringify 替换成 null。")
	assert_true(json_text.contains("\"Vector2\""), "Vector2 应写入类型标记。")
	assert_true(json_text.contains("\"Float\""), "非有限 float 应写入类型标记。")
	assert_true(position_value is Vector2, "Vector2 应恢复为 Godot 值类型。")
	assert_true(tint_value is Color, "Color 应恢复为 Godot 值类型。")
	assert_true(nan_preserved, "NaN 应保持语义。")
	assert_true(inf_preserved, "正无穷应保持语义。")
	assert_true(packed_value is PackedFloat32Array, "PackedFloat32Array 应恢复为 Godot 值类型。")
	if position_value is Vector2:
		var position: Vector2 = position_value
		assert_eq(position, Vector2(1.5, -2.0), "Vector2 值应完整往返。")
	if tint_value is Color:
		var tint: Color = tint_value
		assert_eq(tint, Color(0.25, 0.5, 0.75, 1.0), "Color 值应完整往返。")
	if packed_value is PackedFloat32Array:
		var decoded_packed: PackedFloat32Array = packed_value
		assert_eq(decoded_packed.size(), 2, "PackedFloat32Array 长度应保持。")
		assert_true(is_nan(decoded_packed[0]), "PackedFloat32Array 内的 NaN 应保持语义。")
		assert_eq(decoded_packed[1], 3.5, "PackedFloat32Array 普通 float 应保持。")


func test_json_checksum_accepts_nonfinite_values() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = codec.encode({
		"unstable_value": NAN,
		"position": Vector3(1.0, INF, -INF),
	}, {
		"include_metadata": true,
		"use_integrity_checksum": true,
		"obfuscation_key": 0,
	})

	var result: GFStorageReadResult = codec.decode(bytes, {
		"use_integrity_checksum": true,
		"strict_integrity": true,
		"obfuscation_key": 0,
	})
	var data: Dictionary = result.payload
	var unstable_value: Variant = GFVariantData.get_option_value(data, "unstable_value")
	var position_value: Variant = GFVariantData.get_option_value(data, "position")
	var unstable_preserved: bool = false
	if unstable_value is float:
		var unstable_float: float = unstable_value
		unstable_preserved = is_nan(unstable_float)

	assert_true(result.ok, "checksum 不应把非有限 float 存档误判为损坏。")
	assert_eq(result.integrity_status, GFStorageReadResult.IntegrityStatus.VALID, "非有限 float 经类型标记编码后 checksum 应稳定。")
	assert_true(unstable_preserved, "NaN 应在 checksum 往返后保持。")
	assert_true(position_value is Vector3, "Vector3 应在 checksum 往返后保持。")
	if position_value is Vector3:
		var position: Vector3 = position_value
		assert_true(is_inf(position.y) and position.y > 0.0, "Vector3 中的 INF 应保持。")
		assert_true(is_inf(position.z) and position.z < 0.0, "Vector3 中的 -INF 应保持。")


func test_checksum_rejects_tampered_payload_in_strict_mode() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = codec.encode({
		"coins": 10,
	}, {
		"include_metadata": true,
		"use_integrity_checksum": true,
		"obfuscation_key": 0,
	})
	var tampered: Dictionary = GFVariantData.get_option_dictionary({
		"payload": JSON.parse_string(bytes.get_string_from_utf8()),
	}, "payload")
	var tampered_payload: Dictionary = GFVariantData.get_option_dictionary(tampered, GFStorageCodec.PAYLOAD_KEY)
	tampered_payload["coins"] = 99
	tampered[GFStorageCodec.PAYLOAD_KEY] = tampered_payload

	var result: GFStorageReadResult = codec.decode(JSON.stringify(tampered).to_utf8_buffer(), {
		"use_integrity_checksum": true,
		"strict_integrity": true,
		"obfuscation_key": 0,
	})

	assert_false(result.ok, "严格模式下 checksum 不匹配应拒绝读取。")
	assert_eq(result.integrity_status, GFStorageReadResult.IntegrityStatus.INVALID, "结果应标记完整性失败。")


func test_checksum_accepts_json_roundtrip_large_integers() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = codec.encode({
		"rng_state": 9_223_372_036_854_775_000,
	}, {
		"include_metadata": true,
		"use_integrity_checksum": true,
		"obfuscation_key": 0,
	})

	var result: GFStorageReadResult = codec.decode(bytes, {
		"use_integrity_checksum": true,
		"strict_integrity": true,
		"obfuscation_key": 0,
	})

	assert_true(result.ok, "checksum 应按 JSON 写盘后的语义校验，不能把合法大整数 JSON 往返误判为损坏。")
	assert_eq(result.integrity_status, GFStorageReadResult.IntegrityStatus.VALID, "大整数 JSON 往返后的 checksum 应保持有效。")


func test_checksum_without_extra_metadata_roundtrips() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = codec.encode({ "coins": 10 }, {
		"include_metadata": false,
		"use_integrity_checksum": true,
		"obfuscation_key": 0,
	})

	var result: GFStorageReadResult = codec.decode(bytes, {
		"use_integrity_checksum": true,
		"strict_integrity": true,
		"obfuscation_key": 0,
	})

	assert_true(result.ok, "只启用 checksum 时也应能正常校验并读取。")
	assert_eq(result.integrity_status, GFStorageReadResult.IntegrityStatus.VALID, "checksum 应通过校验。")


func test_user_meta_key_roundtrips_with_storage_metadata() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = codec.encode({
		"_meta": {
			"player_note": "keep",
		},
		"coins": 10,
	}, {
		"include_metadata": true,
		"use_integrity_checksum": true,
		"obfuscation_key": 0,
	})

	var result: GFStorageReadResult = codec.decode(bytes, {
		"use_integrity_checksum": true,
		"strict_integrity": true,
		"obfuscation_key": 0,
	})
	var data: Dictionary = result.payload
	var metadata: Dictionary = result.metadata
	var user_meta: Dictionary = GFVariantData.get_option_dictionary(data, "_meta")

	assert_true(result.ok, "带用户 _meta 的载荷仍应通过存储元数据校验。")
	assert_eq(GFVariantData.get_option_string(user_meta, "player_note"), "keep", "用户 _meta 不应被存储 metadata 覆盖。")
	assert_eq(GFVariantData.get_option_int(metadata, GFStorageCodec.VERSION_KEY), 1, "存储 metadata 应独立包含数据版本。")
	assert_eq(result.integrity_status, GFStorageReadResult.IntegrityStatus.VALID, "存储文档应保留独立完整性状态。")


func test_storage_metadata_never_enters_user_payload() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = codec.encode({ "coins": 10 }, {
		"include_metadata": true,
		"use_integrity_checksum": true,
		"obfuscation_key": 0,
	})

	var result: GFStorageReadResult = codec.decode(bytes, {
		"use_integrity_checksum": true,
		"strict_integrity": true,
		"obfuscation_key": 0,
	})
	var data: Dictionary = result.payload
	var metadata: Dictionary = result.metadata

	assert_true(result.ok, "存储文档应成功读取。")
	assert_false(data.has("_meta"), "框架存储 metadata 不得进入用户 payload。")
	assert_eq(GFVariantData.get_option_int(metadata, GFStorageCodec.VERSION_KEY), 1, "框架存储 metadata 应只通过结果对象暴露。")
	assert_eq(result.integrity_status, GFStorageReadResult.IntegrityStatus.VALID, "完整性信息不得混入 metadata 或 payload。")


func test_checksum_enabled_rejects_missing_checksum_by_default() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = codec.encode({ "coins": 10 }, {
		"obfuscation_key": 0,
	})

	var result: GFStorageReadResult = codec.decode(bytes, {
		"use_integrity_checksum": true,
		"strict_integrity": true,
		"obfuscation_key": 0,
	})

	assert_false(result.ok, "启用 checksum 时，缺少 checksum 的载荷默认应被拒绝。")
	assert_eq(result.integrity_status, GFStorageReadResult.IntegrityStatus.MISSING, "缺少 checksum 应标记完整性失败。")
	assert_eq(result.error, "Integrity checksum missing", "应返回明确的缺失 checksum 错误。")


func test_missing_checksum_can_be_allowed_for_migration() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = codec.encode({ "coins": 10 }, {
		"obfuscation_key": 0,
	})

	var result: GFStorageReadResult = codec.decode(bytes, {
		"use_integrity_checksum": true,
		"strict_integrity": true,
		"require_integrity_checksum": false,
		"obfuscation_key": 0,
	})
	var data: Dictionary = result.payload

	assert_true(result.ok, "可显式允许没有 checksum 的文档。")
	assert_true(result.is_integrity_accepted(), "显式允许缺少 checksum 时应允许使用载荷。")
	assert_eq(GFVariantData.get_option_int(data, "coins"), 10, "旧载荷数据应保持可读。")


func test_empty_dictionary_is_valid_payload() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()

	var result: GFStorageReadResult = codec.decode(codec.encode({}, { "obfuscation_key": 0 }), {
		"obfuscation_key": 0,
	})

	assert_true(result.ok, "空字典是合法载荷，不应被当作解码失败。")
	var data: Dictionary = result.payload
	assert_true(data.is_empty(), "空字典载荷应保持为空字典。")


func test_user_envelope_like_dictionary_roundtrips_without_field_loss() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var user_data: Dictionary = {
		GFStorageCodec.DOCUMENT_KEY: { "business": true },
		GFStorageCodec.PAYLOAD_KEY: { "nested": 1 },
		"sibling": "must-survive",
	}

	var result: GFStorageReadResult = codec.decode(codec.encode(user_data), {})
	var decoded: Dictionary = result.payload

	assert_true(result.ok, "包含保留字段的用户字典应可往返。")
	assert_true(GFVariantData.get_option_bool(GFVariantData.get_option_dictionary(decoded, GFStorageCodec.DOCUMENT_KEY), "business"), "用户 document 字段应保留。")
	assert_eq(
		GFVariantData.get_option_int(GFVariantData.get_option_dictionary(decoded, GFStorageCodec.PAYLOAD_KEY), "nested"),
		1,
		"用户 payload 字段应保留。"
	)
	assert_eq(GFVariantData.get_option_string(decoded, "sibling"), "must-survive", "codec 不得丢弃 envelope-like 字典的兄弟字段。")


func test_empty_bytes_are_invalid_payload() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()

	var result: GFStorageReadResult = codec.decode(PackedByteArray(), {
		"obfuscation_key": 0,
	})

	assert_false(result.ok, "空 bytes 不应被当作合法空字典。")
	assert_eq(result.error, "Payload is empty", "空 bytes 应返回明确诊断。")


func test_json_number_normalization_is_disabled_by_default() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = codec.encode({ "whole": 1.0 }, { "obfuscation_key": 0 })

	var preserved: GFStorageReadResult = codec.decode(bytes, {
		"obfuscation_key": 0,
	})
	var normalized: GFStorageReadResult = codec.decode(bytes, {
		"obfuscation_key": 0,
		"normalize_json_numbers": true,
	})
	var preserved_data: Dictionary = preserved.payload
	var normalized_data: Dictionary = normalized.payload

	assert_eq(typeof(GFVariantData.get_option_value(preserved_data, "whole")), TYPE_FLOAT, "2.0 默认应保留 JSON float 类型。")
	assert_eq(typeof(GFVariantData.get_option_value(normalized_data, "whole")), TYPE_INT, "迁移旧整数语义时可显式开启数字归一化。")


func test_plain_json_without_storage_document_is_rejected() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = "{\"coins\": 10}".to_utf8_buffer()

	var result: GFStorageReadResult = codec.decode(bytes, { "obfuscation_key": 0 })

	assert_false(result.ok, "运行时 codec 不应把任意 JSON 当作 GF 存储文档。")
	assert_eq(result.error, "Storage document envelope missing or malformed", "应报告缺少严格文档 envelope。")


func test_storage_document_rejects_coercive_version_fields() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var canonical: Dictionary = JSON.parse_string(
		codec.encode({ "coins": 10 }, { "obfuscation_key": 0 }).get_string_from_utf8()
	)
	var invalid_versions: Array = [2.5, "2", true]

	for invalid_version: Variant in invalid_versions:
		var invalid_schema: Dictionary = canonical.duplicate(true)
		var descriptor: Dictionary = GFVariantData.get_option_dictionary(
			invalid_schema,
			GFStorageCodec.DOCUMENT_KEY
		)
		descriptor[GFStorageCodec.SCHEMA_VERSION_KEY] = invalid_version
		invalid_schema[GFStorageCodec.DOCUMENT_KEY] = descriptor
		var schema_result: GFStorageReadResult = codec.decode(
			JSON.stringify(invalid_schema).to_utf8_buffer(),
			{ "obfuscation_key": 0 }
		)
		assert_false(schema_result.ok, "schema_version 不得接受隐式类型转换：%s" % [invalid_version])

		var invalid_data_version: Dictionary = canonical.duplicate(true)
		descriptor = GFVariantData.get_option_dictionary(
			invalid_data_version,
			GFStorageCodec.DOCUMENT_KEY
		)
		var metadata: Dictionary = GFVariantData.get_option_dictionary(
			descriptor,
			GFStorageCodec.METADATA_KEY
		)
		metadata[GFStorageCodec.VERSION_KEY] = invalid_version
		descriptor[GFStorageCodec.METADATA_KEY] = metadata
		invalid_data_version[GFStorageCodec.DOCUMENT_KEY] = descriptor
		var data_version_result: GFStorageReadResult = codec.decode(
			JSON.stringify(invalid_data_version).to_utf8_buffer(),
			{ "obfuscation_key": 0 }
		)
		assert_false(data_version_result.ok, "data_version 不得接受隐式类型转换：%s" % [invalid_version])


func test_future_storage_document_schema_has_typed_future_failure() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var future_document: Dictionary = JSON.parse_string(
		codec.encode({"future": true}, {"obfuscation_key": 0}).get_string_from_utf8()
	)
	var descriptor: Dictionary = GFVariantData.get_option_dictionary(
		future_document,
		GFStorageCodec.DOCUMENT_KEY
	)
	descriptor[GFStorageCodec.SCHEMA_VERSION_KEY] = GFStorageCodec.DOCUMENT_SCHEMA_VERSION + 1
	future_document[GFStorageCodec.DOCUMENT_KEY] = descriptor

	var result: GFStorageReadResult = codec.decode(
		JSON.stringify(future_document).to_utf8_buffer(),
		{"obfuscation_key": 0}
	)

	assert_false(result.ok)
	assert_eq(result.failure_kind, GFStorageReadResult.FailureKind.FUTURE_VERSION)
	assert_eq(result.document_schema_version, GFStorageCodec.DOCUMENT_SCHEMA_VERSION + 1)


func test_storage_read_result_deserialization_enforces_success_failure_invariant() -> void:
	var forged_success: GFStorageReadResult = GFStorageReadResult.from_dict({
		"ok": true,
		"failure_kind": GFStorageReadResult.FailureKind.CORRUPT,
	})
	var forged_failure: GFStorageReadResult = GFStorageReadResult.from_dict({
		"ok": false,
		"failure_kind": GFStorageReadResult.FailureKind.NONE,
	})

	assert_eq(forged_success.failure_kind, GFStorageReadResult.FailureKind.NONE)
	assert_eq(forged_failure.failure_kind, GFStorageReadResult.FailureKind.IO_FAILED)


func test_storage_document_rejects_noncanonical_metadata_and_integrity_types() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var canonical: Dictionary = JSON.parse_string(
		codec.encode({ "coins": 10 }, { "obfuscation_key": 0 }).get_string_from_utf8()
	)
	var unknown_metadata: Dictionary = canonical.duplicate(true)
	var descriptor: Dictionary = GFVariantData.get_option_dictionary(
		unknown_metadata,
		GFStorageCodec.DOCUMENT_KEY
	)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(
		descriptor,
		GFStorageCodec.METADATA_KEY
	)
	metadata["future_field"] = true
	descriptor[GFStorageCodec.METADATA_KEY] = metadata
	unknown_metadata[GFStorageCodec.DOCUMENT_KEY] = descriptor

	var metadata_result: GFStorageReadResult = codec.decode(
		JSON.stringify(unknown_metadata).to_utf8_buffer(),
		{ "obfuscation_key": 0 }
	)
	assert_false(metadata_result.ok, "同一存储 schema 不得静默接受未知 metadata 字段。")

	var invalid_integrity: Dictionary = canonical.duplicate(true)
	descriptor = GFVariantData.get_option_dictionary(
		invalid_integrity,
		GFStorageCodec.DOCUMENT_KEY
	)
	descriptor[GFStorageCodec.INTEGRITY_KEY] = {
		GFStorageCodec.ALGORITHM_KEY: 256,
		GFStorageCodec.DIGEST_KEY: "digest",
	}
	invalid_integrity[GFStorageCodec.DOCUMENT_KEY] = descriptor
	var integrity_result: GFStorageReadResult = codec.decode(
		JSON.stringify(invalid_integrity).to_utf8_buffer(),
		{ "obfuscation_key": 0 }
	)
	assert_false(integrity_result.ok, "完整性描述不得把非字符串算法标识强转为字符串。")


func test_removed_legacy_option_cannot_reenable_runtime_fallback() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = "{\"coins\": 10}".to_utf8_buffer()

	var result: GFStorageReadResult = codec.decode(bytes, {
		"allow_legacy_plain_json_fallback": true,
		"obfuscation_key": 0,
	})

	assert_false(result.ok, "已移除的 legacy 选项不得重新开启运行时兼容分支。")


func test_compression_and_obfuscation_roundtrip() -> void:
	var codec: GFStorageCodec = GFStorageCodec.new()
	var data: Dictionary = {
		"player": "demo",
		"stats": {
			"hp": 100,
			"mp": 50,
		},
	}

	var bytes: PackedByteArray = codec.encode(data, {
		"use_compression": true,
		"obfuscation_key": 77,
	})
	var result: GFStorageReadResult = codec.decode(bytes, {
		"use_compression": true,
		"obfuscation_key": 77,
	})

	assert_true(result.ok, "压缩和混淆组合应可正常往返。")
	if not result.ok:
		return

	var loaded: Dictionary = result.payload
	var stats: Dictionary = GFVariantData.get_option_dictionary(loaded, "stats")
	assert_eq(GFVariantData.get_option_int(stats, "hp"), 100, "嵌套字典应正确恢复。")
