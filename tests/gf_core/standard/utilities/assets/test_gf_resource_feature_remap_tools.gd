## 测试 GFResourceFeatureRemapTools 的资源 feature 重映射计划。
extends GutTest


func test_normalize_remaps_accepts_array_dictionary_and_feature_lists() -> void:
	var report: Dictionary = GFResourceFeatureRemapTools.normalize_remaps({
		"res://ui/panel.tres": [
			PackedStringArray(["mobile", "res://ui/panel_mobile.tres"]),
			{
				"feature": "web",
				"target_path": "res://ui/panel_web.tres",
				"metadata": {
					"quality": "compact",
				},
			},
			{
				"features": PackedStringArray(["demo", "debug"]),
				"path": "res://ui/panel_debug.tres",
			},
		],
	})
	var remaps: Dictionary = GFVariantData.get_option_dictionary(report, "remaps")
	var entries: Array = GFVariantData.get_option_array(remaps, "res://ui/panel.tres")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效 remap 声明应归一化成功。")
	assert_eq(GFVariantData.get_option_int(report, "source_count"), 1, "应记录 source 数量。")
	assert_eq(GFVariantData.get_option_int(report, "entry_count"), 4, "features 列表应展开为多个 entry。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(entries[0]), "feature"), "mobile", "PackedStringArray entry 应被读取。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(entries[1]), "feature"), "web", "Dictionary feature 应被读取。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(entries[2]), "feature"), "demo", "features 中的第一个 feature 应保留顺序。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(entries[3]), "feature"), "debug", "features 中的第二个 feature 应保留顺序。")


func test_select_remap_for_path_uses_first_matching_entry_order() -> void:
	var report: Dictionary = GFResourceFeatureRemapTools.select_remap_for_path(
		"res://ui/panel.tres",
		{
			"res://ui/panel.tres": [
				["mobile", "res://ui/panel_mobile.tres"],
				["web", "res://ui/panel_web.tres"],
			],
		},
		PackedStringArray(["web", "mobile"])
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "选择报告不应失败。")
	assert_true(GFVariantData.get_option_bool(report, "selected"), "active feature 应命中 remap entry。")
	assert_eq(GFVariantData.get_option_string(report, "feature"), "mobile", "entry 声明顺序应优先于 active feature 顺序。")
	assert_eq(GFVariantData.get_option_string(report, "resolved_path"), "res://ui/panel_mobile.tres", "resolved_path 应指向选中 target。")


func test_normalize_remaps_accepts_single_array_entry_shorthand() -> void:
	var report: Dictionary = GFResourceFeatureRemapTools.normalize_remaps({
		"res://ui/icon.png": ["mobile", "res://ui/icon_mobile.png"],
	})
	var remaps: Dictionary = GFVariantData.get_option_dictionary(report, "remaps")
	var entries: Array = GFVariantData.get_option_array(remaps, "res://ui/icon.png")
	var entry: Dictionary = GFVariantData.as_dictionary(entries[0])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "source 直接指向 [feature, target] 简写时应归一化成功。")
	assert_eq(entries.size(), 1, "单条简写不应被拆成两个无效 entry。")
	assert_eq(GFVariantData.get_option_string(entry, "feature"), "mobile")
	assert_eq(GFVariantData.get_option_string(entry, "target_path"), "res://ui/icon_mobile.png")


func test_select_remap_keeps_feature_tokens_distinct_from_paths() -> void:
	var report: Dictionary = GFResourceFeatureRemapTools.select_remap_for_path(
		"res://ui/icon.png",
		{
			"res://ui/icon.png": [
				["tier\\one", "res://ui/icon_tier_one.png"],
			],
		},
		PackedStringArray(["tier\\one"])
	)

	assert_true(GFVariantData.get_option_bool(report, "selected"), "feature token 不应被路径归一化改写。")
	assert_eq(GFVariantData.get_option_string(report, "resolved_path"), "res://ui/icon_tier_one.png")


func test_build_remap_plan_reports_resolved_unmatched_and_unused_targets() -> void:
	var plan: Dictionary = GFResourceFeatureRemapTools.build_remap_plan(
		{
			"res://ui/panel.tres": [
				["mobile", "res://ui/panel_mobile.tres"],
				["web", "res://ui/panel_web.tres"],
			],
			"res://audio/theme.ogg": [
				["desktop", "res://audio/theme_hi.ogg"],
			],
		},
		PackedStringArray(["mobile"]),
		{
			"exported_paths": PackedStringArray([
				"res://ui/panel.tres",
				"res://ui/panel_mobile.tres",
				"res://ui/panel_web.tres",
				"res://audio/theme.ogg",
				"res://audio/theme_hi.ogg",
			]),
		}
	)
	var resolved: Array = GFVariantData.get_option_array(plan, "resolved")
	var unmatched: Array = GFVariantData.get_option_array(plan, "unmatched")
	var selected_targets: Dictionary = GFVariantData.get_option_dictionary(plan, "selected_targets")
	var skip_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(plan, "skip_paths")

	assert_true(GFVariantData.get_option_bool(plan, "ok"), "计划生成不应失败。")
	assert_eq(resolved.size(), 1, "应只选择 active feature 命中的 source。")
	assert_eq(unmatched.size(), 1, "未命中 active feature 的 source 应保留诊断。")
	assert_eq(GFVariantData.get_option_string(selected_targets, "res://ui/panel.tres"), "res://ui/panel_mobile.tres", "selected_targets 应保留 source 到 target 的映射。")
	assert_true(skip_paths.has("res://ui/panel_web.tres"), "未选中的同源 target 应可被外层导出工具跳过。")
	assert_true(skip_paths.has("res://audio/theme_hi.ogg"), "无 active feature 命中的 target 应可被跳过。")
	assert_false(skip_paths.has("res://ui/panel_mobile.tres"), "已选中的 target 不应被 skip。")
	assert_false(skip_paths.has("res://audio/theme.ogg"), "原始 source 路径默认不应被 skip。")


func test_build_remap_plan_protects_target_selected_by_another_source() -> void:
	var plan: Dictionary = GFResourceFeatureRemapTools.build_remap_plan(
		{
			"res://ui/a.tres": [
				["mobile", "res://ui/shared_mobile.tres"],
			],
			"res://ui/b.tres": [
				["web", "res://ui/shared_mobile.tres"],
			],
		},
		PackedStringArray(["mobile"])
	)
	var skip_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(plan, "skip_paths")

	assert_false(skip_paths.has("res://ui/shared_mobile.tres"), "被任一 source 选中的 target 不应因另一条未命中 entry 被 skip。")


func test_normalize_remaps_reports_invalid_entries_without_dropping_valid_ones() -> void:
	var report: Dictionary = GFResourceFeatureRemapTools.normalize_remaps({
		"res://ui/panel.tres": [
			["mobile", "res://ui/panel_mobile.tres"],
			["", "res://ui/panel_empty_feature.tres"],
			["web", ""],
			42,
		],
		"": [
			["desktop", "res://ui/panel_desktop.tres"],
		],
	})
	var remaps: Dictionary = GFVariantData.get_option_dictionary(report, "remaps")
	var entries: Array = GFVariantData.get_option_array(remaps, "res://ui/panel.tres")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "无效 entry 应让报告失败。")
	assert_eq(GFVariantData.get_option_int(report, "entry_count"), 1, "默认只应保留有效 entry。")
	assert_eq(entries.size(), 1, "有效 entry 不应被无效 entry 影响。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "empty_feature"), "应报告空 feature。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "empty_target_path"), "应报告空 target。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "invalid_entry_payload"), "应报告非法 entry 类型。")
	assert_true(_has_issue_kind(GFVariantData.get_option_array(report, "issues"), "empty_source_path"), "应报告空 source。")


func _has_issue_kind(issues: Array, kind: String) -> bool:
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false
