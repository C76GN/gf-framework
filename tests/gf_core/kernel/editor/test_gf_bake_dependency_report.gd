extends GutTest

const GF_BAKE_DEPENDENCY_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_bake_dependency_report.gd")


func test_bake_dependency_report_marks_stale_outputs_and_dependencies() -> void:
	var report: GF_BAKE_DEPENDENCY_REPORT_SCRIPT = GF_BAKE_DEPENDENCY_REPORT_SCRIPT.new()
	var _configured: GF_BAKE_DEPENDENCY_REPORT_SCRIPT = report.configure(&"mesh-bake", "Mesh Bake", { "tool": "test" })
	var _input: Dictionary = report.add_input("res://source.mesh", { "exists": true })
	var _output: Dictionary = report.add_output("res://generated.mesh", { "exists": false })
	var _dependency: Dictionary = report.add_dependency(&"settings", {
		"status": GF_BAKE_DEPENDENCY_REPORT_SCRIPT.STATUS_STALE,
		"version": "2",
	})
	var _invalidation: Dictionary = report.mark_stale("settings_changed", { "dependency_id": &"settings" })
	report.add_artifact_report(GFGeneratedArtifactReport.make_report(
		"res://generated.mesh",
		GFGeneratedArtifactReport.STATUS_NEW
	))

	var summary: Dictionary = report.summarize({
		"include_outputs": true,
		"include_invalidations": true,
	})

	assert_true(GFVariantData.get_option_bool(summary, "success"), "stale 代表需要重建，不应等同失败。")
	assert_false(GFVariantData.get_option_bool(summary, "current"), "缺失输出和 stale 依赖应让 current 为 false。")
	assert_eq(GFVariantData.get_option_string_name(summary, "status"), GF_BAKE_DEPENDENCY_REPORT_SCRIPT.STATUS_STALE, "摘要状态应为 stale。")
	assert_eq(GFVariantData.get_option_array(summary, "missing_outputs").size(), 1, "缺失输出应进入摘要。")
	assert_eq(GFVariantData.get_option_array(summary, "stale_dependencies").size(), 1, "stale 依赖应进入摘要。")
	assert_eq(GFVariantData.get_option_array(summary, "invalidations").size(), 1, "include_invalidations 应附带失效记录。")


func test_bake_dependency_report_failed_dependency_overrides_stale() -> void:
	var report: GF_BAKE_DEPENDENCY_REPORT_SCRIPT = GF_BAKE_DEPENDENCY_REPORT_SCRIPT.new()
	var _configured: GF_BAKE_DEPENDENCY_REPORT_SCRIPT = report.configure(&"bake")
	var _input: Dictionary = report.add_input("res://source.mesh", { "exists": true })
	var _dependency: Dictionary = report.add_dependency(&"importer", {
		"status": GF_BAKE_DEPENDENCY_REPORT_SCRIPT.STATUS_FAILED,
		"error": "importer_error",
	})

	var summary: Dictionary = report.summarize()

	assert_false(GFVariantData.get_option_bool(summary, "success"), "failed 依赖应让摘要失败。")
	assert_eq(GFVariantData.get_option_string_name(summary, "status"), GF_BAKE_DEPENDENCY_REPORT_SCRIPT.STATUS_FAILED, "failed 依赖优先级最高。")
	assert_eq(GFVariantData.get_option_array(summary, "failed_dependencies").size(), 1, "failed 依赖应进入摘要。")
