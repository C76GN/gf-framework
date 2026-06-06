## 测试 GFAudioBankTools 的音频集合导入和校验辅助。
extends GutTest


# --- 常量 ---

const GFAudioBankInspectorPluginScript = preload("res://addons/gf/standard/utilities/audio/editor/gf_audio_bank_inspector_plugin.gd")


# --- 私有/辅助方法 ---

func _write_empty_user_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建 user:// 临时文件。")
	if file != null:
		var _store_string_result_16: Variant = file.store_string("")
		file.close()


func _find_property_info(object: Object, property_name: String) -> Dictionary:
	for property_info: Dictionary in object.get_property_list():
		if GFVariantData.get_option_string(property_info, "name") == property_name:
			return property_info
	return {}


# --- 测试 ---

func test_create_bank_from_paths_uses_relative_clip_ids() -> void:
	var paths: PackedStringArray = PackedStringArray([
		"res://audio/ui/click.ogg",
		"res://audio/ui/confirm.wav",
	])

	var bank: GFAudioBank = GFAudioBankTools.create_bank_from_paths(paths, {
		"id_mode": "relative_path",
		"base_path": "res://audio",
		"path_separator": "+",
		"bus_name": "SFX",
	})

	assert_true(bank.has_clip(&"ui+click"), "应按相对路径生成稳定片段 ID。")
	assert_true(bank.has_clip(&"ui+confirm"), "应导入全部支持的音频路径。")
	assert_eq(bank.get_clip(&"ui+click").bus_name, "SFX", "导入时应写入默认 bus。")


func test_create_bank_from_paths_accepts_string_name_options_and_normalizes_extensions() -> void:
	var options: Dictionary = {}
	options[&"id_mode"] = "relative_path"
	options[&"base_path"] = "res://audio"
	options[&"path_separator"] = "+"
	options[&"extensions"] = PackedStringArray([".ogg"])
	options[&"bus_name"] = &"SFX"
	options[&"volume_db"] = "-3.5"
	options[&"pitch_scale"] = "1.25"

	var bank: GFAudioBank = GFAudioBankTools.create_bank_from_paths(PackedStringArray([
		"res://audio/ui/click.OGG",
		"res://audio/ui/skip.wav",
	]), options)
	var clip: GFAudioClip = bank.get_clip(&"ui+click")

	assert_true(bank.has_clip(&"ui+click"), "导入选项应接受 StringName 键并规范化扩展名。")
	assert_false(bank.has_clip(&"ui+skip"), "自定义扩展名白名单应过滤未包含的音频路径。")
	assert_not_null(clip, "导入后的片段应可读取。")
	if clip == null:
		return
	assert_eq(clip.bus_name, "SFX", "StringName bus_name 应按字符串写入片段。")
	assert_almost_eq(clip.volume_db, -3.5, 0.001, "字符串音量选项应稳定转换为 float。")
	assert_almost_eq(clip.pitch_scale, 1.25, 0.001, "字符串 pitch 选项应稳定转换为 float。")


func test_add_paths_to_bank_skips_existing_ids_without_overwrite() -> void:
	var bank: GFAudioBank = GFAudioBank.new()
	var existing_clip: GFAudioClip = GFAudioClip.new()
	existing_clip.path = "res://audio/existing.ogg"
	bank.set_clip(&"click", existing_clip)

	var report: GFValidationReport = GFAudioBankTools.add_paths_to_bank(bank, PackedStringArray([
		"res://audio/click.ogg",
	]))
	var counts: Dictionary = report.get_issue_counts_by_kind()

	assert_eq(GFVariantData.get_option_int(counts, "audio_clip_id_exists"), 1, "重复 ID 且未开启覆盖时应跳过。")
	assert_eq(bank.get_clip(&"click").path, "res://audio/existing.ogg", "原有片段不应被覆盖。")
	assert_eq(GFVariantData.get_option_int(report.metadata, "skipped_count"), 1, "报告应记录跳过数量。")


func test_sync_bank_from_scan_imports_audio_paths() -> void:
	var root_path: String = "user://gf_audio_bank_tools_scan"
	var _make_dir_recursive_absolute_result_91: Variant = DirAccess.make_dir_recursive_absolute(root_path)
	_write_empty_user_file(root_path.path_join("click.ogg"))
	_write_empty_user_file(root_path.path_join("ignore.txt"))
	var bank: GFAudioBank = GFAudioBank.new()

	var report: GFValidationReport = GFAudioBankTools.sync_bank_from_scan(bank, root_path, {
		"id_mode": "relative_path",
		"base_path": root_path,
		"bus_name": "SFX",
	})

	assert_eq(GFVariantData.get_option_int(report.metadata, "scanned_count"), 1, "扫描同步只应收集支持的音频扩展名。")
	assert_eq(GFVariantData.get_option_int(report.metadata, "added_count"), 1, "扫描同步应导入新音频片段。")
	assert_true(bank.has_clip(&"click"), "扫描同步应按相对路径生成片段 ID。")
	assert_eq(bank.get_clip(&"click").bus_name, "SFX", "扫描同步应传递导入选项。")


func test_scan_audio_paths_normalizes_excluded_path_list() -> void:
	var root_path: String = "user://gf_audio_bank_tools_excluded"
	var keep_dir: String = root_path.path_join("keep")
	var skip_dir: String = root_path.path_join("skip")
	var keep_path: String = keep_dir.path_join("keep.ogg")
	var skip_path: String = skip_dir.path_join("skip.ogg")
	var make_keep_error: Error = DirAccess.make_dir_recursive_absolute(keep_dir)
	var make_skip_error: Error = DirAccess.make_dir_recursive_absolute(skip_dir)
	assert_true(make_keep_error == OK or make_keep_error == ERR_ALREADY_EXISTS, "测试应能创建保留目录。")
	assert_true(make_skip_error == OK or make_skip_error == ERR_ALREADY_EXISTS, "测试应能创建排除目录。")
	_write_empty_user_file(keep_path)
	_write_empty_user_file(skip_path)

	var paths: PackedStringArray = GFAudioBankTools.scan_audio_paths(root_path + "\\", {
		"excluded_paths": PackedStringArray([skip_dir + "\\", skip_dir, ""]),
	})

	var _remove_keep_file_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(keep_path))
	var _remove_skip_file_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(skip_path))
	var _remove_keep_dir_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(keep_dir))
	var _remove_skip_dir_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(skip_dir))
	var _remove_root_dir_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(root_path))

	assert_true(paths.has(keep_path), "未排除目录中的音频应被扫描。")
	assert_false(paths.has(skip_path), "排除目录中的音频不应被扫描。")


func test_audio_clip_path_picker_accepts_default_tool_extensions() -> void:
	var clip: GFAudioClip = GFAudioClip.new()
	var path_property: Dictionary = _find_property_info(clip, "path")
	var hint_string: String = GFVariantData.get_option_string(path_property, "hint_string")

	for extension: String in GFAudioBankTools.AUDIO_EXTENSIONS:
		assert_true(
			hint_string.contains("*.%s" % extension),
			"GFAudioClip.path 的文件选择器应包含 GFAudioBankTools 默认音频扩展名。"
		)


func test_scan_audio_paths_respects_audio_path_limit() -> void:
	var root_path: String = "user://gf_audio_bank_tools_limit"
	var first_path: String = root_path.path_join("first.ogg")
	var second_path: String = root_path.path_join("second.ogg")
	var _make_dir_recursive_absolute_result_124: Variant = DirAccess.make_dir_recursive_absolute(root_path)
	_write_empty_user_file(first_path)
	_write_empty_user_file(second_path)

	var paths: PackedStringArray = GFAudioBankTools.scan_audio_paths(root_path, {
		"max_audio_paths": 1,
	})
	assert_push_warning("[GFAudioBankTools] scan_audio_paths 已达到 max_audio_paths=1，后续音频已跳过。")

	var _remove_absolute_result_133: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(first_path))
	var _remove_absolute_result_134: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(second_path))
	var _remove_absolute_result_135: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(root_path))

	assert_eq(paths.size(), 1, "音频扫描应遵守 max_audio_paths 上限。")


func test_validate_bank_playback_reports_bus_and_extension_issues() -> void:
	var bank: GFAudioBank = GFAudioBank.new()
	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = "res://audio/not_audio.txt"
	clip.bus_name = "__missing_gf_test_bus__"
	bank.set_clip(&"bad", clip)

	var report: GFValidationReport = GFAudioBankTools.validate_bank_playback(bank, {
		"check_bus_exists": true,
	})
	var counts: Dictionary = report.get_issue_counts_by_kind()

	assert_eq(GFVariantData.get_option_int(counts, "unsupported_audio_extension"), 1, "不支持的扩展名应产生警告。")
	assert_eq(GFVariantData.get_option_int(counts, "missing_audio_bus"), 1, "不存在的音频总线应产生警告。")


func test_audio_bank_inspector_tooltip_formats_validation_issue_objects() -> void:
	var bank: GFAudioBank = GFAudioBank.new()
	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = "res://audio/not_audio.txt"
	bank.set_clip(&"bad", clip)

	var report: GFValidationReport = GFAudioBankTools.validate_bank_playback(bank)
	var tooltip: String = GFAudioBankInspectorPluginScript.format_report_tooltip(report)

	assert_true(tooltip.contains("unsupported_audio_extension"), "Inspector tooltip 应能读取 GFValidationIssue.kind。")
	assert_true(tooltip.contains("Audio clip path uses an unsupported extension."), "Inspector tooltip 应能读取 GFValidationIssue.message。")
