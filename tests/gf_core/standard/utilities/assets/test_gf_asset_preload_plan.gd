## 测试 GFAssetPreloadPlan 的条目归一、校验与 GFAssetUtility 委托预热行为。
extends GutTest


var _utility: GFAssetUtility


func before_each() -> void:
	_utility = GFAssetUtility.new()
	_utility.init()


func after_each() -> void:
	if _utility != null:
		_utility.dispose()
	_utility = null
	await get_tree().process_frame


func test_preload_plan_normalizes_entries_validation_and_options() -> void:
	var asset_plan: GFAssetPreloadPlan = GFAssetPreloadPlan.new()
	var _configured: GFAssetPreloadPlan = asset_plan.configure(
		&"battle_ui",
		[
			{ "path": " res://ui/battle_hud.tscn ", "type_hint": " PackedScene ", "metadata": { "role": "hud" } },
			{ "path": "res://ui/battle_hud.tscn", "type_hint": "PackedScene" },
			{ "path": "res://ui/disabled.tres", "enabled": false },
			{ "path": "" },
		],
		{
			"plan_id": &"boot.battle_ui",
			"pin_cache": false,
			"lane_id": &"ui",
			"max_concurrent_loads": 2,
			"metadata": { "source": "test" },
		}
	)

	var entries: Array[Dictionary] = asset_plan.get_entries()
	var first_entry: Dictionary = entries[0]
	var validation: Dictionary = asset_plan.validate()
	var duplicate_paths: Array = GFVariantData.get_option_array(validation, "duplicate_paths")
	var preload_options: Dictionary = asset_plan.to_preload_options()

	assert_eq(entries.size(), 2, "只应输出启用且路径有效的条目。")
	assert_eq(GFVariantData.get_option_string(first_entry, "path"), "res://ui/battle_hud.tscn", "路径应裁剪空白。")
	assert_eq(GFVariantData.get_option_string(first_entry, "type_hint"), "PackedScene", "type_hint 应裁剪空白。")
	assert_false(GFVariantData.get_option_bool(validation, "ok"), "空路径启用条目应让校验失败。")
	assert_eq(GFVariantData.get_option_int(validation, "enabled_count"), 2, "启用有效条目数量应稳定。")
	assert_eq(GFVariantData.get_option_int(validation, "disabled_count"), 1, "禁用条目应单独统计。")
	assert_eq(GFVariantData.get_option_int(validation, "invalid_count"), 1, "启用空路径应计为无效。")
	assert_eq(duplicate_paths.size(), 1, "重复启用路径应进入重复路径报告。")
	assert_false(GFVariantData.get_option_bool(preload_options, "pin_cache", true), "计划默认 pin_cache 应写入选项。")
	assert_eq(GFVariantData.get_option_string_name(preload_options, "lane_id"), &"ui", "计划 lane_id 应写入选项。")
	assert_eq(GFVariantData.get_option_int(preload_options, "max_concurrent_loads"), 2, "计划并发限制应写入选项。")


func test_preload_plan_async_delegates_to_group_preload_and_merges_metadata() -> void:
	var completing: CompletingAssetUtility = CompletingAssetUtility.new()
	_replace_utility(completing)
	completing.complete = true

	var asset_plan: GFAssetPreloadPlan = GFAssetPreloadPlan.new()
	var _configured: GFAssetPreloadPlan = asset_plan.configure(
		&"boot_ui",
		[{ "path": "res://ui/boot_panel.tres", "type_hint": "Resource" }],
		{
			"plan_id": &"boot.ui",
			"metadata": { "scope": "boot" },
		}
	)
	var reports: Array[Dictionary] = []

	_utility.preload_plan_async(asset_plan, func(preload_report: Dictionary) -> void:
		reports.append(preload_report)
	, { "pin_cache": true })
	_utility.tick()

	var report: Dictionary = reports[0]
	var report_metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")
	var validation: Dictionary = GFVariantData.get_option_dictionary(report_metadata, "preload_plan")
	var plan_metadata: Dictionary = GFVariantData.get_option_dictionary(report_metadata, "plan_metadata")

	assert_eq(completing.requested_paths, ["res://ui/boot_panel.tres"], "计划应委托 GFAssetUtility 发起分组加载。")
	assert_eq(completing.requested_type_hints, ["Resource"], "计划条目 type_hint 应传给加载器。")
	assert_eq(reports.size(), 1, "预热完成后应回调一次。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效计划预热成功时报告应为 ok。")
	assert_true(_utility.get_group_paths(&"boot_ui").has("res://ui/boot_panel.tres"), "成功路径应注册到计划 group。")
	assert_true(_utility.is_cache_pinned("res://ui/boot_panel.tres"), "pin_cache 覆盖选项应生效。")
	assert_eq(GFVariantData.get_option_string_name(report_metadata, "plan_id"), &"boot.ui", "报告 metadata 应包含计划 ID。")
	assert_true(GFVariantData.get_option_bool(validation, "ok"), "报告 metadata 应包含计划校验结果。")
	assert_eq(GFVariantData.get_option_string(plan_metadata, "scope"), "boot", "报告 metadata 应包含计划自定义 metadata。")


func test_preload_plan_async_reports_empty_group_without_hanging() -> void:
	var asset_plan: GFAssetPreloadPlan = GFAssetPreloadPlan.new()
	var _configured: GFAssetPreloadPlan = asset_plan.configure(
		&"",
		[{ "path": "res://ui/boot_panel.tres", "type_hint": "Resource" }],
		{ "plan_id": &"broken.ui" }
	)
	var reports: Array[Dictionary] = []

	_utility.preload_plan_async(asset_plan, func(report: Dictionary) -> void:
		reports.append(report)
	)

	assert_push_error("[GFAssetUtility] preload_plan_async 失败：group_id 为空。")
	assert_eq(reports.size(), 1, "无效 group 也应立即回调失败报告。")
	assert_false(GFVariantData.get_option_bool(reports[0], "ok"), "失败报告应标记 ok=false。")

	var metadata: Dictionary = GFVariantData.get_option_dictionary(reports[0], "metadata")
	var validation: Dictionary = GFVariantData.get_option_dictionary(metadata, "preload_plan")
	var issues: Array = GFVariantData.get_option_array(validation, "issues")
	assert_false(GFVariantData.get_option_bool(validation, "ok"), "失败报告应包含无效计划校验结果。")
	assert_gt(issues.size(), 0, "校验结果应包含具体问题。")


# --- 私有/辅助方法 ---

func _replace_utility(utility: GFAssetUtility) -> void:
	if _utility != null:
		_utility.dispose()
	_utility = utility
	_utility.init()


# --- 内部类 ---

class CompletingAssetUtility extends GFAssetUtility:
	var requested_paths: Array[String] = []
	var requested_type_hints: Array[String] = []
	var complete: bool = false
	var loaded_resource: Resource = Resource.new()

	func _request_threaded(path: String, type_hint: String) -> Error:
		requested_paths.append(path)
		requested_type_hints.append(type_hint)
		return OK

	func _get_threaded_status_with_progress(_path: String, _progress: Array) -> ResourceLoader.ThreadLoadStatus:
		return ResourceLoader.THREAD_LOAD_LOADED if complete else ResourceLoader.THREAD_LOAD_IN_PROGRESS

	func _take_threaded_resource(_path: String) -> Resource:
		return loaded_resource
