## 测试通用导入计划、预检和 source trace。
extends GutTest


func test_import_plan_reports_source_trace_and_repair_actions() -> void:
	var plan: GFImportPlan = GFImportPlan.new()
	var _updated_plan: GFImportPlan = plan.add_entry(
		"res://source/items.csv",
		"res://imported/items.tres",
		GFImportPlan.OPERATION_CONVERT,
		{
			"source_format": "csv",
			"target_format": "tres",
			"source_trace": {
				"sheet": "items",
			},
			"repair_actions": [
				{
					"kind": "create_parent_directory",
				},
			],
		}
	)

	var traces: Array[Dictionary] = plan.get_source_traces()
	var repair_report: Dictionary = plan.get_repair_report()
	var actions: Array = GFVariantData.get_option_array(repair_report, "actions")
	var first_trace: Dictionary = traces[0]
	var first_action: Dictionary = GFVariantData.as_dictionary(actions[0])

	assert_eq(GFVariantData.get_option_string(first_trace, "source_path"), "res://source/items.csv", "trace 应保留来源路径。")
	assert_eq(GFVariantData.get_option_string(first_trace, "target_format"), "tres", "trace 应保留目标格式。")
	assert_eq(GFVariantData.get_option_string(first_trace, "sheet"), "items", "trace 应合并调用方来源信息。")
	assert_eq(GFVariantData.get_option_int(repair_report, "action_count"), 1, "修复报告应统计动作数量。")
	assert_eq(GFVariantData.get_option_string(first_action, "source_path"), "res://source/items.csv", "修复动作应补充来源路径。")


func test_import_plan_preflight_reports_invalid_entries() -> void:
	var plan: GFImportPlan = GFImportPlan.new()
	var _updated_plan: GFImportPlan = plan.add_entry(
		"",
		"res://outside/generated.tres",
		&"unknown"
	)

	var report: Dictionary = plan.get_validation_report({
		"target_root": "res://generated",
	})

	assert_false(GFVariantData.get_option_bool(report, "ok"), "无效导入条目应让预检失败。")
	assert_true(_has_issue_kind(report, "missing_source_path"), "预检应报告缺少 source_path。")
	assert_true(_has_issue_kind(report, "unsupported_operation"), "预检应报告未知操作。")
	assert_true(_has_issue_kind(report, "target_outside_root"), "预检应报告目标越界。")


func test_import_plan_summary_counts_and_duplicate_targets() -> void:
	var plan: GFImportPlan = GFImportPlan.new()
	var _first_entry_plan: GFImportPlan = plan.add_entry("res://source/a.csv", "res://generated/items.tres", GFImportPlan.OPERATION_COPY, {
		"source_format": "csv",
		"target_format": "tres",
	})
	var _second_entry_plan: GFImportPlan = plan.add_entry("res://source/b.csv", "res://generated/items.tres", GFImportPlan.OPERATION_CONVERT, {
		"source_format": "csv",
		"target_format": "tres",
	})
	var _third_entry_plan: GFImportPlan = plan.add_entry("res://source/c.csv", "", GFImportPlan.OPERATION_SKIP)

	var summary: Dictionary = plan.get_operation_summary()
	var validation_report: Dictionary = plan.get_validation_report()
	var counts_by_operation: Dictionary = GFVariantData.get_option_dictionary(summary, "counts_by_operation")
	var duplicate_targets: Array = GFVariantData.get_option_array(summary, "duplicate_targets")
	var first_duplicate: Dictionary = GFVariantData.as_dictionary(duplicate_targets[0])

	assert_eq(GFVariantData.get_option_int(summary, "entry_count"), 3, "摘要应统计总条目。")
	assert_eq(GFVariantData.get_option_int(summary, "actionable_entry_count"), 2, "摘要应统计非 skip 条目。")
	assert_eq(GFVariantData.get_option_int(summary, "skipped_entry_count"), 1, "摘要应统计 skip 条目。")
	assert_eq(GFVariantData.get_option_int(counts_by_operation, "copy"), 1, "摘要应按操作统计 copy。")
	assert_eq(GFVariantData.get_option_int(counts_by_operation, "convert"), 1, "摘要应按操作统计 convert。")
	assert_eq(duplicate_targets.size(), 1, "摘要应报告重复目标路径。")
	assert_eq(GFVariantData.get_option_string(first_duplicate, "target_path"), "res://generated/items.tres", "重复目标应保留目标路径。")
	assert_false(GFVariantData.get_option_bool(validation_report, "ok"), "重复目标默认应让预检失败。")
	assert_true(_has_issue_kind(validation_report, "duplicate_target_path"), "预检应报告重复目标路径。")


func test_import_plan_round_trips_dictionary_data() -> void:
	var plan: GFImportPlan = GFImportPlan.new()
	plan.metadata["profile"] = "default"
	var _updated_plan: GFImportPlan = plan.add_entry("res://a.csv", "res://a.tres")

	var copied: GFImportPlan = GFImportPlan.from_dict(plan.to_dict())
	var entries: Array[Dictionary] = copied.get_entries()

	assert_eq(GFVariantData.get_option_string(copied.metadata, "profile"), "default", "metadata 应可序列化往返。")
	assert_eq(GFVariantData.get_option_string(entries[0], "source_path"), "res://a.csv", "entries 应可序列化往返。")


func _has_issue_kind(report: Dictionary, kind: String) -> bool:
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false
