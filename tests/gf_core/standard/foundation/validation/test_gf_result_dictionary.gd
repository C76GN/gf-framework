## 测试通用结果字典常量与轻量工厂。
extends GutTest


func test_make_adds_ok_and_preserves_fields() -> void:
	var data: Dictionary = { "coins": 10 }
	var result: Dictionary = GFResultDictionary.make(
		true,
		{
			GFResultDictionary.KEY_DATA: data,
			GFResultDictionary.KEY_METADATA: { "version": 2 },
		}
	)
	var metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(result, GFResultDictionary.KEY_METADATA))

	assert_true(
		GFVariantData.get_option_bool(result, GFResultDictionary.KEY_OK),
		"make() 应写入 ok 字段。"
	)
	assert_eq(
		GFVariantData.as_dictionary(GFVariantData.get_option_value(result, GFResultDictionary.KEY_DATA)),
		data,
		"data 字段应保持调用方传入的值。"
	)
	assert_eq(
		GFVariantData.get_option_int(metadata, "version"),
		2,
		"附加字段应保留。"
	)


func test_make_deep_copies_field_collections() -> void:
	var fields: Dictionary = {
		GFResultDictionary.KEY_METADATA: {
			"nested": { "value": 1, },
		},
	}

	var result: Dictionary = GFResultDictionary.make(true, fields)
	var result_metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(result, GFResultDictionary.KEY_METADATA))
	var result_nested: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(result_metadata, "nested"))
	result_nested["value"] = 2

	var source_metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(fields, GFResultDictionary.KEY_METADATA))
	var source_nested: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(source_metadata, "nested"))
	assert_eq(
		GFVariantData.get_option_int(source_nested, "value"),
		1,
		"结果字段应深拷贝，避免调用方共享集合。"
	)


func test_make_success_uses_common_key_constants() -> void:
	var result: Dictionary = GFResultDictionary.make_success({ GFResultDictionary.KEY_INTEGRITY_VALID: true, })

	assert_true(
		GFVariantData.get_option_bool(result, GFResultDictionary.KEY_OK),
		"成功结果 ok 应为 true。"
	)
	assert_true(
		GFVariantData.get_option_bool(result, GFResultDictionary.KEY_INTEGRITY_VALID),
		"完整性字段常量应可直接用于结果。"
	)


func test_make_failure_writes_error_without_discarding_fields() -> void:
	var result: Dictionary = GFResultDictionary.make_failure(
		"File not found",
		{ GFResultDictionary.KEY_DATA: {}, }
	)
	var data: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(result, GFResultDictionary.KEY_DATA))

	assert_false(
		GFVariantData.get_option_bool(result, GFResultDictionary.KEY_OK),
		"失败结果 ok 应为 false。"
	)
	assert_eq(
		GFVariantData.get_option_string(result, GFResultDictionary.KEY_ERROR),
		"File not found",
		"失败结果应写入 error。"
	)
	assert_eq(
		GFVariantData.get_option_string(result, GFResultDictionary.KEY_REASON),
		"File not found",
		"失败结果应写入 reason。"
	)
	assert_eq(
		GFVariantData.get_option_string(result, GFResultDictionary.KEY_MESSAGE),
		"File not found",
		"失败结果应写入 message。"
	)
	assert_true(
		data.is_empty(),
		"失败结果应保留调用方提供的 data。"
	)


func test_make_rejected_uses_reason_message_and_error_fallback() -> void:
	var result: Dictionary = GFResultDictionary.make_rejected(
		&"invalid_state",
		"State is invalid.",
		{
			GFResultDictionary.KEY_METADATA: { "state": "boot", },
		}
	)
	var metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(result, GFResultDictionary.KEY_METADATA))

	assert_false(
		GFResultDictionary.is_ok(result),
		"拒绝结果应失败。"
	)
	assert_eq(
		GFVariantData.get_option_string(result, GFResultDictionary.KEY_REASON),
		"invalid_state",
		"拒绝结果应写入稳定原因。"
	)
	assert_eq(
		GFVariantData.get_option_string(result, GFResultDictionary.KEY_MESSAGE),
		"State is invalid.",
		"拒绝结果应写入说明。"
	)
	assert_eq(
		GFVariantData.get_option_string(result, GFResultDictionary.KEY_ERROR),
		"State is invalid.",
		"未显式 error 时应使用 message。"
	)
	assert_eq(
		GFVariantData.get_option_string(metadata, "state"),
		"boot",
		"元数据应保留。"
	)


func test_make_with_issues_adds_count_and_health() -> void:
	var result: Dictionary = GFResultDictionary.make_with_issues(
		false,
		[
			{ "kind": "bad_value" },
		]
	)

	assert_false(
		GFVariantData.get_option_bool(result, GFResultDictionary.KEY_OK),
		"带错误的问题结果应失败。"
	)
	assert_eq(
		GFVariantData.get_option_int(result, GFResultDictionary.KEY_ISSUE_COUNT),
		1,
		"问题总数应稳定输出。"
	)
	assert_false(
		GFVariantData.get_option_bool(result, GFResultDictionary.KEY_HEALTHY),
		"包含问题时不应健康。"
	)


func test_normalize_copies_metadata_and_derives_standard_fields() -> void:
	var source: Dictionary = {
		GFResultDictionary.KEY_ERROR: "Missing config",
		GFResultDictionary.KEY_METADATA: {
			"nested": { "value": 1, },
		},
		GFResultDictionary.KEY_ISSUES: [
			{ "kind": "missing_config" },
		],
	}

	var normalized: Dictionary = GFResultDictionary.normalize(
		source,
		false,
		{ "include_healthy": true, }
	)
	var normalized_metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(normalized, GFResultDictionary.KEY_METADATA))
	var normalized_nested: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(normalized_metadata, "nested"))
	normalized_nested["value"] = 2

	var source_metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(source, GFResultDictionary.KEY_METADATA))
	var source_nested: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(source_metadata, "nested"))

	assert_false(
		GFVariantData.get_option_bool(normalized, GFResultDictionary.KEY_OK),
		"缺少 ok 时应使用 default_ok。"
	)
	assert_eq(
		GFVariantData.get_option_string(normalized, GFResultDictionary.KEY_REASON),
		"Missing config",
		"缺少 reason 时应从 error 派生。"
	)
	assert_eq(
		GFVariantData.get_option_string(normalized, GFResultDictionary.KEY_MESSAGE),
		"Missing config",
		"缺少 message 时应从 error 派生。"
	)
	assert_eq(
		GFVariantData.get_option_int(normalized, GFResultDictionary.KEY_ISSUE_COUNT),
		1,
		"归一化应统计 issues。"
	)
	assert_false(
		GFVariantData.get_option_bool(normalized, GFResultDictionary.KEY_HEALTHY),
		"有问题时 healthy 应为 false。"
	)
	assert_eq(
		GFVariantData.get_option_int(source_nested, "value"),
		1,
		"归一化不应共享源 metadata。"
	)


func test_merge_metadata_uses_deep_merge() -> void:
	var result: Dictionary = GFResultDictionary.make_success(
		{
			GFResultDictionary.KEY_METADATA: {
				"nested": { "a": 1, },
			},
		}
	)

	var _merged: Dictionary = GFResultDictionary.merge_metadata(
		result,
		{
			"nested": { "b": 2, },
		}
	)

	var metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(result, GFResultDictionary.KEY_METADATA))
	var nested: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(metadata, "nested"))
	assert_eq(
		GFVariantData.get_option_int(nested, "a"),
		1,
		"已有嵌套元数据应保留。"
	)
	assert_eq(
		GFVariantData.get_option_int(nested, "b"),
		2,
		"新嵌套元数据应合并。"
	)
