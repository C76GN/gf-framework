# 测试 Storage worker 诊断到 Save 校验报告的隔离适配。
extends GutTest


const _ADAPTER = preload("res://addons/gf/extensions/save/profile/gf_save_payload_validation_adapter.gd")


func test_adapter_infers_section_and_never_copies_payload_fields() -> void:
	var result: Dictionary = _ADAPTER.adapt_for_framework(
		{
			"ok": false,
			"failure_kind": "unsupported_variant_type",
			"failure_path": "$.PRIVATE_KEY.PRIVATE_VALUE",
			"path_segments": [
				{
					"kind": "dictionary_value",
					"entry_index": 4,
					"key_token_sha256": "PRIVATE_KEY_DIGEST",
					"raw_key": "PRIVATE_KEY",
				},
				{
					"kind": "dictionary_value",
					"entry_index": 0,
					"key_token_sha256": "PRIVATE_SECTION_DIGEST",
					"raw_value": "PRIVATE_VALUE",
				},
				{
					"kind": "array_index",
					"index": 3,
					"raw_value": "PRIVATE_VALUE",
				},
			],
			"variant_type": TYPE_OBJECT,
			"variant_type_name": "PRIVATE_TYPE_NAME",
			"visited_values": 17,
			"visited_bytes": 43,
			"payload": "PRIVATE_VALUE",
		},
		4,
		[&"command_history"]
	)

	assert_eq(
		GFVariantData.get_option_string_name(result, "failed_section_id"),
		&"command_history"
	)
	var report: Dictionary = GFVariantData.get_option_dictionary(
		result,
		"validation_report"
	)
	assert_false(GFVariantData.get_option_bool(report, "ok", true))
	assert_eq(GFVariantData.get_option_int(report, "error_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "issue_count"), 1)
	assert_eq(
		GFVariantData.get_option_int(
			GFVariantData.get_option_dictionary(report, "worker_diagnostics"),
			"visited_bytes"
		),
		43
	)
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(report, "worker_diagnostics"),
			"variant_type_name"
		),
		"Object"
	)
	var serialized: String = JSON.stringify(report)
	assert_false(serialized.contains("PRIVATE_KEY"))
	assert_false(serialized.contains("PRIVATE_VALUE"))
	assert_false(serialized.contains("PRIVATE_TYPE_NAME"))
	assert_false(serialized.contains("PRIVATE_SECTION_DIGEST"))
	var normalized_report: RefCounted = (
		GFValidationReportDictionary.report_from_dict(report)
	)
	assert_not_null(normalized_report)
	var roundtrip_value: Variant = normalized_report.call(&"to_dict")
	assert_true(roundtrip_value is Dictionary)
	if roundtrip_value is Dictionary:
		var roundtrip: Dictionary = roundtrip_value
		assert_false(GFVariantData.get_option_bool(roundtrip, "ok", true))
		assert_eq(GFVariantData.get_option_int(roundtrip, "error_count"), 1)
		assert_eq(GFVariantData.get_option_int(roundtrip, "issue_count"), 1)


func test_adapter_uses_empty_section_for_unmatched_structural_positions() -> void:
	var no_section_ids: Array[StringName] = []
	var result: Dictionary = _ADAPTER.adapt_for_framework(
		{
			"failure_kind": "future_worker_failure",
			"path_segments": [
				{
					"kind": "dictionary_value",
					"entry_index": 1,
				},
				{
					"kind": "dictionary_value",
					"entry_index": 2,
					"key_token_sha256": "PRIVATE_KEY_DIGEST",
					"raw_key": "PRIVATE_KEY",
				},
			],
			"variant_type": TYPE_MAX + 10,
			"visited_values": -2,
		},
		4,
		no_section_ids
	)

	assert_eq(
		GFVariantData.get_option_string_name(result, "failed_section_id"),
		&""
	)
	var report: Dictionary = GFVariantData.get_option_dictionary(
		result,
		"validation_report"
	)
	var diagnostics: Dictionary = GFVariantData.get_option_dictionary(
		report,
		"worker_diagnostics"
	)
	assert_eq(
		GFVariantData.get_option_string_name(diagnostics, "failure_kind"),
		&"payload_invalid"
	)
	assert_eq(GFVariantData.get_option_int(diagnostics, "visited_values"), 0)
	assert_eq(GFVariantData.get_option_string(diagnostics, "variant_type_name"), "")
	assert_false(JSON.stringify(report).contains("PRIVATE_KEY"))


func test_adapter_does_not_infer_section_from_nested_non_section_dictionary() -> void:
	var result: Dictionary = _ADAPTER.adapt_for_framework(
		{
			"failure_kind": "unsupported_variant_type",
			"path_segments": [
				{
					"kind": "dictionary_value",
					"entry_index": 5,
				},
				{
					"kind": "dictionary_value",
					"entry_index": 0,
				},
				{
					"kind": "dictionary_value",
					"entry_index": 0,
				},
			],
			"variant_type": TYPE_OBJECT,
			"visited_values": 8,
		},
		4,
		[&"command_history"]
	)

	assert_eq(
		GFVariantData.get_option_string_name(result, "failed_section_id"),
		&"",
		"只有根 document.sections.<section_id> 前缀允许推断 section。"
	)
