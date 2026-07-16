## 测试模板生成清单与产物报告衔接。
@tool

extends GutTest


const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT = preload("res://addons/gf/kernel/editor/gf_template_generation_manifest.gd")


# --- 测试 ---

func test_template_manifest_parses_json_and_builds_artifact_options() -> void:
	var text: String = JSON.stringify({
		"template_id": "panel",
		"template_path": "res://templates/panel.gd.tpl",
		"output_path": "user://generated_panel.gd",
		"variables": {
			"class_name": "GeneratedPanel",
		},
		"requirements": {
			"packages": ["gf.kernel"],
		},
	})

	var manifest: Dictionary = GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT.from_json_text(text, {
		"generator_id": "gf.test.generator",
		"artifact_owner": "generated",
	})
	var options: Dictionary = GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT.make_artifact_options(manifest, {
		"dry_run": true,
	})
	var metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(options, "metadata")
	var variables: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(metadata, "variables")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(manifest, "valid"), "有效 JSON 清单应通过校验。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(manifest, "template_id"), &"panel", "清单应保留模板 ID。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(options, "generator_id"), "gf.test.generator", "产物选项应携带生成器 ID。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(options, "dry_run"), "额外保存选项应能覆盖到产物选项。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(variables, "class_name"), "GeneratedPanel", "变量应进入产物 metadata。")


func test_template_manifest_reports_invalid_fields_and_dry_run_save() -> void:
	var invalid_manifest: Dictionary = GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT.from_dictionary({
		"template_id": "broken",
	})
	var invalid_report: Dictionary = GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT.save_text_from_manifest(invalid_manifest, "extends Node", {
		"dry_run": true,
	})
	var valid_manifest: Dictionary = GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT.make_manifest(
		&"valid",
		"res://templates/valid.gd.tpl",
		"user://gf_template_generation_manifest_valid.gd"
	)
	var dry_run_report: Dictionary = GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT.save_text_from_manifest(valid_manifest, "extends Node\n", {
		"dry_run": true,
		"scan_filesystem": false,
	})
	var summary: Dictionary = GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT.summarize_manifests([invalid_manifest, valid_manifest])

	assert_false(GF_VARIANT_ACCESS.get_option_bool(invalid_manifest, "valid"), "缺少必要字段的清单应无效。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(invalid_report, "status"), GFGeneratedArtifactReport.STATUS_FAILED, "无效清单保存应返回 failed 报告。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(dry_run_report, "dry_run"), "有效清单应能 dry-run 保存。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(dry_run_report, "status"), GFGeneratedArtifactReport.STATUS_NEW, "不存在文件 dry-run 应报告 new。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(summary, "invalid_count"), 1, "摘要应统计无效清单数量。")


func test_template_manifest_summary_returns_json_safe_report_boundary() -> void:
	var manifest: Dictionary = GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT.make_manifest(&"safe", "res://templates/safe_panel.gd.tpl", "user://generated/safe_panel.gd", {
		"variables": {
			"owner": self,
			"weight": INF,
		},
		"requirements": {
			"template_path": "res://secret/internal.tpl",
		},
		"metadata": {
			"owner": self,
		},
	})
	var summary: Dictionary = GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT.summarize_manifests([manifest], {
		"include_manifests": true,
		"metadata": {
			"owner": self,
		},
	})
	var summary_metadata: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary, "metadata")
	var summary_owner_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary_metadata, "owner")
	var summary_owner_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(summary_owner_payload, "__gf_report_value__")
	var summary_manifests: Array = GF_VARIANT_ACCESS.get_option_array(summary, "manifests")
	var included_manifest: Dictionary = {}
	if not summary_manifests.is_empty() and summary_manifests[0] is Dictionary:
		included_manifest = summary_manifests[0]
	var variables: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(included_manifest, "variables")
	var variable_owner_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(variables, "owner")
	var variable_owner_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(variable_owner_payload, "__gf_report_value__")
	var weight_payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(variables, "weight")
	var weight_marker: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(weight_payload, "__gf_variant__")
	var requirements: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(included_manifest, "requirements")

	assert_eq(GF_VARIANT_ACCESS.get_option_string(summary_owner_marker, "type"), "Object", "摘要 metadata 应通过报告边界编码。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(variable_owner_marker, "type"), "Object", "include_manifests 中的 variables 应通过报告边界编码。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(weight_marker, "type"), "Float", "include_manifests 中的 INF 应使用 typed marker。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string(requirements, "template_path"), "internal.tpl", "include_manifests 中的动态路径应按报告策略收束为文件名。")
	assert_eq(GF_VARIANT_ACCESS.get_option_array(summary, "template_ids"), ["safe"], "摘要 template_ids 应是 JSON 原生数组。")
	assert_false(JSON.stringify(summary).contains(":null"), "模板清单摘要应可直接 JSON.stringify()。")


func test_template_manifest_rejects_unsafe_paths() -> void:
	var parent_escape_manifest: Dictionary = GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT.from_dictionary({
		"template_id": "escape",
		"template_path": "res://templates/../secret.gd.tpl",
		"output_path": "user://generated/../escape.gd",
	})
	var local_path_manifest: Dictionary = GF_TEMPLATE_GENERATION_MANIFEST_SCRIPT.from_dictionary({
		"template_id": "local",
		"template_path": "C:/templates/panel.gd.tpl",
		"output_path": "generated_panel.gd",
	})
	var parent_errors: Array = GF_VARIANT_ACCESS.get_option_array(parent_escape_manifest, "errors")
	var local_errors: Array = GF_VARIANT_ACCESS.get_option_array(local_path_manifest, "errors")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(parent_escape_manifest, "valid"), "包含 .. 的模板清单应无效。")
	assert_true(parent_errors.has("template_path 不能包含 .. 路径段。"), "template_path 应拒绝父级越界。")
	assert_true(parent_errors.has("output_path 不能包含 .. 路径段。"), "output_path 应拒绝父级越界。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(local_path_manifest, "valid"), "本地绝对路径或相对路径应无效。")
	assert_true(local_errors.has("template_path 必须使用 res:// 或 user:// 路径。"), "template_path 应要求资源协议。")
	assert_true(local_errors.has("output_path 必须使用 res:// 或 user:// 路径。"), "output_path 应要求资源协议。")
