extends GutTest

const GF_EDITOR_OPERATION_PLAN_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_operation_plan.gd")
const GF_GENERATED_ARTIFACT_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")


func test_editor_operation_plan_summarizes_steps_and_artifacts() -> void:
	var plan: GF_EDITOR_OPERATION_PLAN_SCRIPT = GF_EDITOR_OPERATION_PLAN_SCRIPT.new()
	var _configured: RefCounted = plan.configure(&"resource_import", "Resource Import", true, {
		"scope": "unit",
	})

	var _planned_step: Dictionary = plan.add_step(&"scan", "Scan", {
		"target": "res://items",
		"kind": &"scan",
	})
	var _write_step: Dictionary = plan.add_step(&"write", "Write")
	assert_true(plan.mark_step(&"scan", GF_EDITOR_OPERATION_PLAN_SCRIPT.STATUS_PREVIEWED), "应能更新步骤状态。")
	assert_true(plan.mark_step(&"write", GF_EDITOR_OPERATION_PLAN_SCRIPT.STATUS_SKIPPED, OK, "", {
		"reason": "dry_run",
	}), "应能标记步骤跳过。")

	plan.add_artifact_report(GF_GENERATED_ARTIFACT_REPORT_SCRIPT.make_report(
		"res://generated/items.gd",
		GF_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_CHANGED,
		OK,
		"",
		{ "dry_run": true }
	))

	var summary: Dictionary = plan.summarize({
		"include_steps": true,
	})
	var status_counts: Dictionary = GFVariantData.get_option_dictionary(summary, "status_counts")
	var artifact_summary: Dictionary = GFVariantData.get_option_dictionary(summary, "artifact_summary")

	assert_true(GFVariantData.get_option_bool(summary, "success"), "无失败步骤和产物时操作应成功。")
	assert_true(GFVariantData.get_option_bool(summary, "dry_run"), "摘要应保留 dry_run 标记。")
	assert_eq(GFVariantData.get_option_int(status_counts, String(GF_EDITOR_OPERATION_PLAN_SCRIPT.STATUS_PREVIEWED)), 1, "摘要应统计 previewed 步骤。")
	assert_eq(GFVariantData.get_option_int(status_counts, String(GF_EDITOR_OPERATION_PLAN_SCRIPT.STATUS_SKIPPED)), 1, "摘要应统计 skipped 步骤。")
	assert_eq(GFVariantData.get_option_int(artifact_summary, "dry_run_count"), 1, "产物摘要应统计 dry-run。")
	assert_eq(GFVariantData.get_option_array(summary, "steps").size(), 2, "include_steps 时应包含步骤副本。")
