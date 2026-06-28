extends GutTest


# --- 测试用例 ---

func test_compare_ids_reports_missing_and_extra_items() -> void:
	var report: Dictionary = GFDriftReport.compare_ids(
		PackedStringArray(["item_a", "item_b"]),
		PackedStringArray(["item_b", "item_c"]),
		{
			"subject": "Registry drift",
			"expected_label": "registry",
			"actual_label": "project",
		}
	)
	var issue_counts: Dictionary = GFVariantData.get_option_dictionary(report, "issue_counts_by_kind")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失项默认是错误。")
	assert_eq(GFVariantData.get_option_int(report, "matched_count"), 1, "共同 ID 应进入 matched。")
	assert_eq(GFVariantData.get_option_int(report, "missing_count"), 1, "期望存在但实际缺失应进入 missing。")
	assert_eq(GFVariantData.get_option_int(report, "extra_count"), 1, "实际多出的 ID 应进入 extra。")
	assert_eq(GFVariantData.get_option_array(report, "matched"), ["item_b"], "matched 应保留排序后的 ID。")
	assert_eq(GFVariantData.get_option_array(report, "missing"), ["item_a"], "missing 应保留排序后的 ID。")
	assert_eq(GFVariantData.get_option_array(report, "extra"), ["item_c"], "extra 应保留排序后的 ID。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "drift_missing"), 1, "issue kind 应稳定报告缺失。")
	assert_eq(GFVariantData.get_option_int(issue_counts, "drift_extra"), 1, "issue kind 应稳定报告多余。")


func test_compare_entries_reports_stale_values_without_project_semantics() -> void:
	var report: Dictionary = GFDriftReport.compare_entries(
		{
			"enemy": { "version": 1, "path": "res://enemy.tres" },
			"item": { "version": 1 },
		},
		{
			"enemy": { "version": 2, "path": "res://enemy.tres" },
			"item": { "version": 1 },
		},
		{
			"subject": "Catalog drift",
			"include_values": true,
		}
	)
	var stale: Array = GFVariantData.get_option_array(report, "stale")
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var stale_issue: Dictionary = _find_issue(issues, "drift_stale")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(stale_issue, "metadata")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "stale 默认是 warning，不应让 ok 失败。")
	assert_false(GFVariantData.get_option_bool(report, "healthy"), "存在 warning 时不应 healthy。")
	assert_eq(stale, ["enemy"], "值不同的共同 key 应进入 stale。")
	assert_eq(GFVariantData.get_option_int(report, "stale_count"), 1, "stale 数量应进入报告字段。")
	assert_true(metadata.has("expected"), "include_values 应保留期望值用于工具审查。")
	assert_true(metadata.has("actual"), "include_values 应保留实际值用于工具审查。")


func test_compare_entries_can_ignore_values_for_key_only_drift() -> void:
	var report: Dictionary = GFDriftReport.compare_entries(
		{ "entry": { "version": 1 } },
		{ "entry": { "version": 2 } },
		{
			"compare_values": false,
		}
	)

	assert_true(GFVariantData.get_option_bool(report, "healthy"), "只比较 key 时值差异不应产生漂移。")
	assert_eq(GFVariantData.get_option_array(report, "matched"), ["entry"], "共同 key 应进入 matched。")
	assert_true(GFVariantData.get_option_array(report, "stale").is_empty(), "关闭值比较后不应报告 stale。")


func test_compare_entries_uses_standard_variant_value_options() -> void:
	var report: Dictionary = GFDriftReport.compare_entries(
		{ "speed": 1.0 },
		{ "speed": 1.0001 },
		{
			"numeric_epsilon": 0.001,
		}
	)

	assert_true(GFVariantData.get_option_bool(report, "healthy"), "漂移比较应复用 GFVariantData 的数值容差。")
	assert_eq(GFVariantData.get_option_array(report, "matched"), ["speed"], "容差内的值应视为 matched。")
	assert_true(GFVariantData.get_option_array(report, "stale").is_empty(), "容差内的值不应报告 stale。")


func test_compare_entries_accepts_custom_severity_for_strict_tools() -> void:
	var report: Dictionary = GFDriftReport.compare_entries(
		{ "entry": 1 },
		{ "entry": 2 },
		{
			"stale_severity": "error",
		}
	)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "调用方可把 stale 提升为 error。")
	assert_eq(GFVariantData.get_option_int(report, "error_count"), 1, "自定义 severity 应进入标准报告统计。")


# --- 私有/辅助方法 ---

func _find_issue(issues: Array, kind: String) -> Dictionary:
	for issue_variant: Variant in issues:
		if issue_variant is Dictionary:
			var issue: Dictionary = issue_variant
			if GFVariantData.get_option_string(issue, "kind") == kind:
				return issue
	return {}
