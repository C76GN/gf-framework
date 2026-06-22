## 测试 GFBuildInfo 与 GFBuildInfoUtility 的构建信息快照。
extends GutTest


# --- 测试方法 ---

func test_build_info_roundtrip_deep_copies_metadata() -> void:
	var info: GFBuildInfo = GFBuildInfo.new()
	info.project_name = "GF Test"
	info.project_version = "1.0.0"
	info.framework_version = "1.27.1"
	info.commit_hash = "abc123"
	info.branch = "main"
	info.tag = "v1.0.0"
	info.commit_count = 12
	info.is_dirty = true
	info.metadata = {
		"channel": "test",
		"nested": {
			"value": 1,
		},
	}

	var copy: GFBuildInfo = GFBuildInfo.from_dict(info.to_dict())
	var copy_nested: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(copy.metadata, "nested")
	)
	copy_nested["value"] = 2
	var source_nested: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(info.metadata, "nested")
	)

	assert_eq(copy.project_name, "GF Test", "构建信息应可从字典恢复。")
	assert_eq(copy.tag, "v1.0.0", "构建标签应参与序列化。")
	assert_eq(copy.commit_count, 12, "提交数量应参与序列化。")
	assert_true(copy.is_dirty, "工作区 dirty 标记应参与序列化。")
	assert_eq(GFVariantData.get_option_int(source_nested, "value"), 1, "metadata 应深拷贝，避免外部修改原始对象。")


func test_build_info_collect_reads_framework_and_engine_version() -> void:
	var info: GFBuildInfo = GFBuildInfo.collect()

	assert_false(info.framework_version.is_empty(), "应能从 plugin.cfg 读取 GF 版本。")
	assert_false(info.engine_version.is_empty(), "应能读取 Godot 引擎版本。")
	assert_false(info.platform_name.is_empty(), "应能读取运行平台。")


func test_build_info_writes_external_metadata_to_project_settings() -> void:
	var setting_paths: Array[String] = [
		GFBuildInfo.BUILD_ID_SETTING,
		GFBuildInfo.COMMIT_HASH_SETTING,
		GFBuildInfo.BRANCH_SETTING,
		GFBuildInfo.TAG_SETTING,
		GFBuildInfo.COMMIT_COUNT_SETTING,
		GFBuildInfo.IS_DIRTY_SETTING,
		GFBuildInfo.TIME_UTC_SETTING,
		GFBuildInfo.METADATA_SETTING,
	]
	var previous_values: Dictionary = _capture_project_settings(setting_paths)
	var build_data: Dictionary = {
		"build_id": "build-42",
		"commit_hash": "abc123def456",
		"branch": "main",
		"tag": "5.2.0",
		"commit_count": 77,
		"is_dirty": true,
		"build_time_utc": "2026-06-18T01:02:03",
		"metadata": {
			"channel": "nightly",
			"nested": {
				"a": 1,
			},
		},
	}
	var extra_metadata: Dictionary = {
		"channel": "stable",
		"nested": {
			"b": 2,
		},
	}

	var written: Dictionary = GFBuildInfo.write_metadata_to_project_settings(build_data, extra_metadata, false)
	var collected: GFBuildInfo = GFBuildInfo.collect()
	_restore_project_settings(previous_values)

	var collected_nested: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(collected.metadata, "nested")
	)

	assert_eq(collected.build_id, "build-42", "构建 ID 应写入 ProjectSettings。")
	assert_eq(collected.commit_hash, "abc123def456", "提交哈希应由外部元数据写入。")
	assert_eq(collected.branch, "main", "分支名应由外部元数据写入。")
	assert_eq(collected.tag, "5.2.0", "标签应由外部元数据写入。")
	assert_eq(collected.commit_count, 77, "提交数量应由外部元数据写入。")
	assert_true(collected.is_dirty, "dirty 标记应由外部元数据写入。")
	assert_eq(collected.build_time_utc, "2026-06-18T01:02:03", "显式构建时间不应被覆盖。")
	assert_eq(GFVariantData.get_option_string(collected.metadata, "channel"), "stable", "附加 metadata 应覆盖同名字段。")
	assert_eq(GFVariantData.get_option_int(collected_nested, "a"), 1, "原始嵌套 metadata 应保留。")
	assert_eq(GFVariantData.get_option_int(collected_nested, "b"), 2, "附加嵌套 metadata 应递归合并。")
	assert_eq(GFVariantData.get_option_string(written, "commit_hash"), "abc123def456", "返回值应包含已写入字段。")


func test_build_info_utility_returns_copy_and_debug_snapshot() -> void:
	var info: GFBuildInfo = GFBuildInfo.new()
	info.project_name = "GF Test"
	info.project_version = "1.0.0"
	info.framework_version = "1.27.1"
	info.build_id = "42"
	var utility: GFBuildInfoUtility = GFBuildInfoUtility.new()

	utility.set_build_info(info)
	var copy: GFBuildInfo = utility.get_build_info()
	copy.project_name = "Changed"
	var snapshot: Dictionary = utility.get_debug_snapshot()

	assert_eq(utility.get_build_info(false).project_name, "GF Test", "默认返回副本，不应允许调用方改内部状态。")
	assert_true(GFVariantData.get_option_bool(snapshot, "available"), "调试快照应报告构建信息可用。")
	assert_true(GFVariantData.get_option_string(snapshot, "summary").contains("GF Test"), "摘要应包含项目名。")


func test_build_info_export_plugin_reports_stable_name() -> void:
	var export_script: Script = _script_resource(
		load("res://addons/gf/standard/utilities/debug/editor/gf_build_info_export_plugin.gd")
	)
	var has_get_name: bool = false
	for method: Dictionary in export_script.get_script_method_list():
		if GFVariantData.get_option_string(method, "name") == "_get_name":
			has_get_name = true
			break

	assert_true(has_get_name, "EditorExportPlugin 必须提供 _get_name()，避免导出流程报错。")


func test_build_info_export_plugin_writes_and_restores_metadata() -> void:
	var setting_paths: Array[String] = _build_info_export_setting_paths()
	var previous_values: Dictionary = _capture_project_settings(setting_paths)
	ProjectSettings.set_setting(GFBuildInfo.BUILD_ID_SETTING, "previous-build")
	ProjectSettings.set_setting(GFBuildInfo.COMMIT_HASH_SETTING, "previous-commit")
	ProjectSettings.set_setting(GFBuildInfo.METADATA_SETTING, {
		"previous": true,
	})
	ProjectSettings.set_setting(GFBuildInfoExportPlugin.ENABLED_SETTING, true)
	ProjectSettings.set_setting(GFBuildInfoExportPlugin.RESTORE_PREVIOUS_SETTING, true)
	ProjectSettings.set_setting(GFBuildInfoExportPlugin.SAVE_PROJECT_SETTINGS_SETTING, false)
	ProjectSettings.set_setting(GFBuildInfoExportPlugin.BUILD_METADATA_SETTING, {
		"build_id": "export-build",
		"commit_hash": "export-commit",
		"branch": "main",
		"metadata": {
			"channel": "nightly",
			"nested": {
				"a": 1,
			},
		},
	})
	ProjectSettings.set_setting(GFBuildInfoExportPlugin.EXTRA_METADATA_SETTING, {
		"channel": "release",
		"nested": {
			"b": 2,
		},
	})
	var export_snapshot: Dictionary = GFBuildInfoExportPlugin._write_export_metadata_from_project_settings()
	var written_info: GFBuildInfo = GFBuildInfo.collect()
	var written_nested: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(written_info.metadata, "nested")
	)
	GFBuildInfoExportPlugin._restore_export_metadata(export_snapshot)
	var restored_build_id: String = GFVariantData.to_text(ProjectSettings.get_setting(GFBuildInfo.BUILD_ID_SETTING, ""))
	var restored_commit_hash: String = GFVariantData.to_text(ProjectSettings.get_setting(GFBuildInfo.COMMIT_HASH_SETTING, ""))
	var restored_metadata: Dictionary = GFVariantData.as_dictionary(ProjectSettings.get_setting(GFBuildInfo.METADATA_SETTING, {}))
	_restore_project_settings(previous_values)

	assert_eq(written_info.build_id, "export-build", "导出开始应写入外部构建 ID。")
	assert_eq(written_info.commit_hash, "export-commit", "导出开始应写入外部提交哈希。")
	assert_eq(written_info.branch, "main", "导出开始应写入外部分支。")
	assert_eq(GFVariantData.get_option_string(written_info.metadata, "channel"), "release", "extra metadata 应覆盖同名字段。")
	assert_eq(GFVariantData.get_option_int(written_nested, "a"), 1, "原始嵌套 metadata 应保留。")
	assert_eq(GFVariantData.get_option_int(written_nested, "b"), 2, "extra metadata 应递归合并。")
	assert_eq(restored_build_id, "previous-build", "导出结束应恢复旧 build_id。")
	assert_eq(restored_commit_hash, "previous-commit", "导出结束应恢复旧 commit_hash。")
	assert_true(GFVariantData.get_option_bool(restored_metadata, "previous"), "导出结束应恢复旧 metadata。")


func test_build_info_export_plugin_clears_missing_previous_settings_after_export() -> void:
	var setting_paths: Array[String] = _build_info_export_setting_paths()
	var previous_values: Dictionary = _capture_project_settings(setting_paths)
	for setting_path: String in setting_paths:
		_clear_project_setting_if_exists(setting_path)
	ProjectSettings.set_setting(GFBuildInfoExportPlugin.ENABLED_SETTING, true)
	ProjectSettings.set_setting(GFBuildInfoExportPlugin.RESTORE_PREVIOUS_SETTING, true)
	ProjectSettings.set_setting(GFBuildInfoExportPlugin.SAVE_PROJECT_SETTINGS_SETTING, false)
	ProjectSettings.set_setting(GFBuildInfoExportPlugin.BUILD_METADATA_SETTING, {
		"build_id": "temporary-build",
		"commit_hash": "temporary-commit",
	})

	var export_snapshot: Dictionary = GFBuildInfoExportPlugin._write_export_metadata_from_project_settings()
	GFBuildInfoExportPlugin._restore_export_metadata(export_snapshot)
	var has_build_id: bool = ProjectSettings.has_setting(GFBuildInfo.BUILD_ID_SETTING)
	var has_commit_hash: bool = ProjectSettings.has_setting(GFBuildInfo.COMMIT_HASH_SETTING)
	var has_time_utc: bool = ProjectSettings.has_setting(GFBuildInfo.TIME_UTC_SETTING)
	var has_metadata: bool = ProjectSettings.has_setting(GFBuildInfo.METADATA_SETTING)
	_restore_project_settings(previous_values)

	assert_false(has_build_id, "导出前不存在 build_id 时，导出结束应清理临时值。")
	assert_false(has_commit_hash, "导出前不存在 commit_hash 时，导出结束应清理临时值。")
	assert_false(has_time_utc, "导出前不存在 time_utc 时，导出结束应清理自动补齐值。")
	assert_false(has_metadata, "导出前不存在 metadata 时，导出结束应清理临时 metadata。")


# --- 私有/辅助方法 ---

func _script_resource(value: Resource) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


func _build_info_export_setting_paths() -> Array[String]:
	return [
		GFBuildInfoExportPlugin.ENABLED_SETTING,
		GFBuildInfoExportPlugin.RESTORE_PREVIOUS_SETTING,
		GFBuildInfoExportPlugin.SAVE_PROJECT_SETTINGS_SETTING,
		GFBuildInfoExportPlugin.BUILD_METADATA_SETTING,
		GFBuildInfoExportPlugin.EXTRA_METADATA_SETTING,
		GFBuildInfo.BUILD_ID_SETTING,
		GFBuildInfo.COMMIT_HASH_SETTING,
		GFBuildInfo.BRANCH_SETTING,
		GFBuildInfo.TAG_SETTING,
		GFBuildInfo.COMMIT_COUNT_SETTING,
		GFBuildInfo.IS_DIRTY_SETTING,
		GFBuildInfo.TIME_UTC_SETTING,
		GFBuildInfo.METADATA_SETTING,
	]


func _capture_project_settings(setting_paths: Array[String]) -> Dictionary:
	var snapshot: Dictionary = {}
	for setting_path: String in setting_paths:
		snapshot[setting_path] = {
			"had": ProjectSettings.has_setting(setting_path),
			"value": ProjectSettings.get_setting(setting_path) if ProjectSettings.has_setting(setting_path) else null,
		}
	return snapshot


func _restore_project_settings(snapshot: Dictionary) -> void:
	for setting_path: Variant in snapshot.keys():
		var entry: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(snapshot, setting_path))
		if GFVariantData.get_option_bool(entry, "had", false):
			ProjectSettings.set_setting(GFVariantData.to_text(setting_path), GFVariantData.get_option_value(entry, "value"))
		else:
			_clear_project_setting_if_exists(GFVariantData.to_text(setting_path))


func _clear_project_setting_if_exists(setting_path: String) -> void:
	if ProjectSettings.has_setting(setting_path):
		ProjectSettings.clear(setting_path)
