## 测试 GFScriptPatchUtility 的脚本头部注解补丁。
extends GutTest


const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试方法 ---

func test_annotation_patch_inserts_after_tool_before_docs() -> void:
	var source: String = "@tool\n\n## Example\nclass_name Example\nextends Node\n"

	var patch: Dictionary = GFScriptPatchUtility.make_annotation_patch(source, "@icon(\"res://icon.svg\")")
	var patched_source: String = GF_VARIANT_ACCESS.get_option_string(patch, "source_code")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(patch, "ok"), "有效注解应生成补丁。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(patch, "changed"), "插入新注解应报告 changed。")
	assert_true(patched_source.begins_with("@tool\n@icon(\"res://icon.svg\")\n\n## Example"), "注解应插入 @tool 之后、文档注释之前。")


func test_annotation_patch_replaces_existing_prefix() -> void:
	var source: String = "@tool\n@icon(\"res://old.svg\")\n\n## Example\nclass_name Example\nextends Node\n"

	var patch: Dictionary = GFScriptPatchUtility.make_annotation_patch(source, "@icon(\"res://new.svg\")", {
		"replacement_prefix": "@icon",
	})
	var patched_source: String = GF_VARIANT_ACCESS.get_option_string(patch, "source_code")

	assert_eq(GF_VARIANT_ACCESS.get_option_int(patch, "removed_count"), 1, "旧注解应被替换。")
	assert_true(patched_source.contains("@icon(\"res://new.svg\")"), "新注解应写入源码。")
	assert_false(patched_source.contains("@icon(\"res://old.svg\")"), "旧注解不应保留。")


func test_patch_script_path_annotation_returns_artifact_report() -> void:
	var path: String = "user://gf_script_patch_utility_%d.gd" % Time.get_ticks_usec()
	_write_text(path, "## Example\nclass_name Example\nextends Node\n")

	var result: Dictionary = GFScriptPatchUtility.patch_script_path_annotation(path, "@tool", {
		"scan_filesystem": false,
	})
	var artifact_report: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(result, "artifact_report")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "测试应能读取补丁后的脚本。")
	var text: String = ""
	if file != null:
		text = file.get_as_text()
		file.close()
	var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	assert_eq(remove_error, OK, "测试应清理临时脚本。")
	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "文件补丁应成功。")
	assert_eq(GF_VARIANT_ACCESS.get_option_string_name(artifact_report, "status"), GFGeneratedArtifactReport.STATUS_CHANGED, "文件写回应报告 changed。")
	assert_true(text.begins_with("@tool\n## Example"), "@tool 应插入文件头部。")


# --- 私有/辅助方法 ---

func _write_text(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建临时脚本。")
	if file == null:
		return
	var _store_result: Variant = file.store_string(text)
	file.close()
