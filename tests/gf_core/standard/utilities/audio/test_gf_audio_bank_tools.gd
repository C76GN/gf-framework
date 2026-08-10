## 测试 GFAudioBankTools 的音频集合导入和校验辅助。
extends GutTest


# --- 常量 ---

const GFAudioBankInspectorPluginScript = preload("res://addons/gf/standard/utilities/audio/editor/gf_audio_bank_inspector_plugin.gd")
const GFAudioLibraryToolsScript = preload("res://addons/gf/standard/utilities/audio/gf_audio_library_tools.gd")


# --- 私有/辅助方法 ---

func _write_user_file(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建 user:// 临时文件。")
	if file != null:
		var _store_string_result: Variant = file.store_string(content)
		file.close()


func _write_user_buffer(path: String, content: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建 user:// 临时二进制文件。")
	if file != null:
		var _store_buffer_result: Variant = file.store_buffer(content)
		file.close()


func _read_user_buffer(path: String) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file, "测试应能读取 user:// 临时二进制文件。")
	if file == null:
		return PackedByteArray()
	var content: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return content


func _write_empty_user_file(path: String) -> void:
	_write_user_file(path, "")


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var _remove_file_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _remove_user_dir(path: String) -> void:
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		var _remove_dir_result: Variant = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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


func test_create_bank_from_paths_merges_clip_metadata_options() -> void:
	var bank: GFAudioBank = GFAudioBankTools.create_bank_from_paths(PackedStringArray([
		"res://audio/ui/click.ogg",
		"res://audio/ui/confirm.ogg",
	]), {
		"id_mode": "relative_path",
		"base_path": "res://audio",
		"metadata": {
			"category": "ui",
			"tags": ["shared"],
		},
		"metadata_by_path": {
			"res://audio/ui/click.ogg": {
				"bpm": 120,
				"tags": ["click"],
			},
		},
	})
	var click: GFAudioClip = bank.get_clip(&"ui/click")
	var confirm: GFAudioClip = bank.get_clip(&"ui/confirm")

	assert_not_null(click, "路径级 metadata 的片段应可读取。")
	assert_not_null(confirm, "公共 metadata 的片段应可读取。")
	if click == null or confirm == null:
		return

	assert_eq(GFVariantData.get_option_string(click.metadata, "category"), "ui", "路径级 metadata 应保留公共字段。")
	assert_eq(GFVariantData.get_option_int(click.metadata, "bpm"), 120, "路径级 metadata 应合并到指定片段。")
	assert_eq(GFVariantData.as_array(click.metadata["tags"]), ["click"], "路径级 metadata 应能覆盖公共嵌套字段。")
	assert_eq(GFVariantData.get_option_string(confirm.metadata, "category"), "ui", "未指定路径 metadata 的片段应保留公共字段。")
	assert_eq(GFVariantData.as_array(confirm.metadata["tags"]), ["shared"], "公共 metadata 应复制到每个导入片段。")


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


func test_scan_audio_paths_caps_total_directory_entries() -> void:
	var root_path: String = "user://gf_audio_bank_tools_entry_limit"
	var audio_paths: PackedStringArray = PackedStringArray([
		root_path.path_join("first.ogg"),
		root_path.path_join("second.ogg"),
		root_path.path_join("third.ogg"),
		root_path.path_join("fourth.ogg"),
	])
	var make_root_error: Error = DirAccess.make_dir_recursive_absolute(root_path)
	assert_true(
		make_root_error == OK or make_root_error == ERR_ALREADY_EXISTS,
		"测试应能创建扫描预算目录。"
	)
	for audio_path: String in audio_paths:
		_write_empty_user_file(audio_path)

	var paths: PackedStringArray = GFAudioBankTools.scan_audio_paths(root_path, {
		"max_audio_paths": 0,
		"max_scan_depth": 0,
		"max_scanned_entries": 2,
	})
	assert_push_warning(
		"[GFAudioBankTools] scan_audio_paths 已达到 max_scanned_entries=2，后续目录项已跳过。"
	)

	for audio_path: String in audio_paths:
		_remove_user_file(audio_path)
	_remove_user_dir(root_path)

	assert_eq(paths.size(), 2, "扫描总目录项预算必须独立于匹配到的音频数量。")
	assert_true(
		GFAudioBankTools.ABSOLUTE_MAX_SCAN_DEPTH >= GFAudioBankTools.DEFAULT_MAX_SCAN_DEPTH
	)
	assert_true(
		GFAudioBankTools.ABSOLUTE_MAX_AUDIO_PATHS >= GFAudioBankTools.DEFAULT_MAX_AUDIO_PATHS
	)
	assert_true(
		GFAudioBankTools.ABSOLUTE_MAX_SCANNED_ENTRIES
		>= GFAudioBankTools.DEFAULT_MAX_SCANNED_ENTRIES
	)


func test_audio_library_scan_builds_searchable_entries() -> void:
	var root_path: String = "user://gf_audio_library_scan"
	var ui_dir: String = root_path.path_join("ui")
	var voice_dir: String = root_path.path_join("voice")
	var click_path: String = ui_dir.path_join("click.ogg")
	var confirm_path: String = voice_dir.path_join("confirm.wav")
	var ignored_path: String = root_path.path_join("ignore.txt")
	var make_ui_error: Error = DirAccess.make_dir_recursive_absolute(ui_dir)
	var make_voice_error: Error = DirAccess.make_dir_recursive_absolute(voice_dir)
	assert_true(make_ui_error == OK or make_ui_error == ERR_ALREADY_EXISTS, "测试应能创建 UI 音频目录。")
	assert_true(make_voice_error == OK or make_voice_error == ERR_ALREADY_EXISTS, "测试应能创建 voice 音频目录。")
	_write_user_file(click_path, "click")
	_write_user_file(confirm_path, "confirm")
	_write_user_file(ignored_path, "ignore")

	var entries: Array[Dictionary] = GFAudioLibraryToolsScript.scan_library(root_path, {
		"extensions": PackedStringArray([".ogg", ".wav"]),
		"path_separator": "+",
	})
	var filtered: Array[Dictionary] = GFAudioLibraryToolsScript.filter_entries(entries, "ui click")
	var entry: Dictionary = filtered[0] if not filtered.is_empty() else {}

	_remove_user_file(click_path)
	_remove_user_file(confirm_path)
	_remove_user_file(ignored_path)
	_remove_user_dir(ui_dir)
	_remove_user_dir(voice_dir)
	_remove_user_dir(root_path)

	assert_eq(entries.size(), 2, "素材库扫描只应收集支持的音频文件。")
	assert_eq(filtered.size(), 1, "搜索应按多个关键字过滤候选条目。")
	assert_eq(GFVariantData.get_option_string(entry, "relative_path"), "ui/click.ogg", "候选条目应保留相对路径。")
	assert_eq(String(GFVariantData.get_option_string_name(entry, "clip_id")), "ui+click", "候选条目应生成可直接用于 Bank 的片段 ID。")


func test_audio_library_filter_entries_reuses_text_search_options() -> void:
	var entries: Array[Dictionary] = [
		{
			"clip_id": &"UI_Click",
			"relative_path": "UI/Click.ogg",
			"file_name": "Click.ogg",
			"source_path": "res://Audio/UI/Click.ogg",
		},
		{
			"clip_id": &"voice_confirm",
			"relative_path": "voice/confirm.wav",
			"file_name": "confirm.wav",
			"source_path": "res://Audio/voice/confirm.wav",
		},
	]

	var insensitive: Array[Dictionary] = GFAudioLibraryToolsScript.filter_entries(entries, "ui click")
	var sensitive: Array[Dictionary] = GFAudioLibraryToolsScript.filter_entries(entries, "ui click", {
		"case_sensitive": true,
	})
	var partial: Array[Dictionary] = GFAudioLibraryToolsScript.filter_entries(entries, "click missing", {
		"match_all": false,
	})

	assert_eq(insensitive.size(), 1, "默认过滤应使用大小写不敏感的通用文本评分。")
	assert_eq(sensitive.size(), 0, "case_sensitive 应传递给通用文本评分器。")
	assert_eq(partial.size(), 1, "match_all=false 应允许部分 token 命中。")


func test_audio_library_import_plan_skips_existing_and_duplicate_targets() -> void:
	var root_path: String = "user://gf_audio_library_plan_source"
	var target_root: String = "user://gf_audio_library_plan_target"
	var first_dir: String = root_path.path_join("a")
	var second_dir: String = root_path.path_join("b")
	var target_dir: String = target_root.path_join("a")
	var first_path: String = first_dir.path_join("click.ogg")
	var second_path: String = second_dir.path_join("click.ogg")
	var existing_target_path: String = target_dir.path_join("click.ogg")
	var _make_first_dir_result: Variant = DirAccess.make_dir_recursive_absolute(first_dir)
	var _make_second_dir_result: Variant = DirAccess.make_dir_recursive_absolute(second_dir)
	var _make_target_dir_result: Variant = DirAccess.make_dir_recursive_absolute(target_dir)
	_write_user_file(first_path, "first")
	_write_user_file(second_path, "second")
	_write_user_file(existing_target_path, "existing")

	var entries: Array[Dictionary] = GFAudioLibraryToolsScript.scan_library(root_path)
	var preserve_plan: Array[Dictionary] = GFAudioLibraryToolsScript.make_import_plan(entries, target_root)
	var flat_plan: Array[Dictionary] = GFAudioLibraryToolsScript.make_import_plan(entries, target_root, {
		"preserve_structure": false,
	})

	_remove_user_file(first_path)
	_remove_user_file(second_path)
	_remove_user_file(existing_target_path)
	_remove_user_dir(first_dir)
	_remove_user_dir(second_dir)
	_remove_user_dir(target_dir)
	_remove_user_dir(root_path)
	_remove_user_dir(target_root)

	assert_eq(GFVariantData.get_option_string(preserve_plan[0], "reason"), "target_exists", "导入计划应标记已存在目标。")
	assert_eq(GFVariantData.get_option_string(flat_plan[1], "reason"), "duplicate_target", "扁平导入时重复目标应被跳过。")


func test_audio_library_import_plan_falls_back_from_parent_relative_path() -> void:
	var root_path: String = "user://gf_audio_library_parent_source"
	var target_root: String = "user://gf_audio_library_parent_target"
	var source_dir: String = root_path.path_join("ui")
	var source_path: String = source_dir.path_join("escape.ogg")
	var expected_target_path: String = target_root.path_join("escape.ogg")
	var _make_source_dir_result: Variant = DirAccess.make_dir_recursive_absolute(source_dir)
	_write_user_file(source_path, "audio")
	var entries: Array[Dictionary] = [
		{
			"source_path": source_path,
			"relative_path": "nested/..",
			"file_name": "escape.ogg",
			"clip_id": &"escape",
		},
	]

	var plan: Array[Dictionary] = GFAudioLibraryToolsScript.make_import_plan(entries, target_root)
	var plan_entry: Dictionary = plan[0] if not plan.is_empty() else {}

	_remove_user_file(source_path)
	_remove_user_dir(source_dir)
	_remove_user_dir(root_path)
	_remove_user_dir(target_root)

	assert_eq(GFVariantData.get_option_string(plan_entry, "target_path"), expected_target_path, "父目录片段不应把导入目标折叠到目标根。")
	assert_true(GFVariantData.get_option_bool(plan_entry, "will_copy"), "安全降级到文件名后导入计划仍应可执行。")


func test_audio_library_copy_import_plan_feeds_audio_bank_tools() -> void:
	var root_path: String = "user://gf_audio_library_copy_source"
	var target_root: String = "user://gf_audio_library_copy_target"
	var source_dir: String = root_path.path_join("ui")
	var target_dir: String = target_root.path_join("ui")
	var source_path: String = source_dir.path_join("click.ogg")
	var target_path: String = target_dir.path_join("click.ogg")
	var _make_source_dir_result: Variant = DirAccess.make_dir_recursive_absolute(source_dir)
	_write_user_file(source_path, "audio")

	var entries: Array[Dictionary] = GFAudioLibraryToolsScript.scan_library(root_path)
	var plan: Array[Dictionary] = GFAudioLibraryToolsScript.make_import_plan(entries, target_root)
	var report: GFValidationReport = GFAudioLibraryToolsScript.copy_import_plan(plan)
	var copied_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(report.metadata, "copied_paths")
	var bank: GFAudioBank = GFAudioBankTools.create_bank_from_paths(copied_paths, {
		"id_mode": "relative_path",
		"base_path": target_root,
	})

	_remove_user_file(source_path)
	_remove_user_file(target_path)
	_remove_user_dir(source_dir)
	_remove_user_dir(target_dir)
	_remove_user_dir(root_path)
	_remove_user_dir(target_root)

	assert_eq(GFVariantData.get_option_int(report.metadata, "copied_count"), 1, "导入计划复制应报告复制数量。")
	assert_true(copied_paths.has(target_path), "复制报告应返回可继续导入 Bank 的目标路径。")
	assert_true(bank.has_clip(&"ui/click"), "复制后的路径应能复用现有 GFAudioBankTools 生成 Bank。")


func test_audio_library_copy_import_plan_rejects_parent_segments() -> void:
	var root_path: String = "user://gf_audio_library_copy_parent_source"
	var target_root: String = "user://gf_audio_library_copy_parent_target"
	var source_dir: String = root_path.path_join("ui")
	var source_path: String = source_dir.path_join("click.ogg")
	var escaped_target_path: String = target_root.path_join("../gf_audio_library_copy_parent_escape.ogg")
	var escaped_canonical_path: String = "user://gf_audio_library_copy_parent_escape.ogg"
	var _make_source_dir_result: Variant = DirAccess.make_dir_recursive_absolute(source_dir)
	_write_user_file(source_path, "audio")
	var plan: Array[Dictionary] = [
		{
			"source_path": source_path,
			"target_path": escaped_target_path,
			"will_copy": true,
			"reason": "",
		},
	]

	var report: GFValidationReport = GFAudioLibraryToolsScript.copy_import_plan(plan)
	var counts: Dictionary = report.get_issue_counts_by_kind()
	var escaped_target_exists: bool = FileAccess.file_exists(escaped_canonical_path)

	_remove_user_file(source_path)
	_remove_user_file(escaped_canonical_path)
	_remove_user_dir(source_dir)
	_remove_user_dir(root_path)
	_remove_user_dir(target_root)

	assert_false(report.is_ok(), "含父目录片段的导入计划不应执行复制。")
	assert_eq(GFVariantData.get_option_int(counts, "unsafe_import_path"), 1, "报告应标记不安全导入路径。")
	assert_false(escaped_target_exists, "不安全导入计划不应写出根外目标。")


func test_audio_library_copy_import_plan_handles_large_binary_files() -> void:
	var root_path: String = "user://gf_audio_library_copy_large_source"
	var target_root: String = "user://gf_audio_library_copy_large_target"
	var source_dir: String = root_path.path_join("ui")
	var target_dir: String = target_root.path_join("ui")
	var source_path: String = source_dir.path_join("large.ogg")
	var target_path: String = target_dir.path_join("large.ogg")
	var _make_source_dir_result: Variant = DirAccess.make_dir_recursive_absolute(source_dir)
	var source_bytes: PackedByteArray = PackedByteArray()
	var _resize_result: Variant = source_bytes.resize(1_048_576 + 257)
	for index: int in range(source_bytes.size()):
		source_bytes[index] = index % 251
	_write_user_buffer(source_path, source_bytes)

	var plan: Array[Dictionary] = [
		{
			"source_path": source_path,
			"target_path": target_path,
			"will_copy": true,
			"reason": "",
		},
	]
	var report: GFValidationReport = GFAudioLibraryToolsScript.copy_import_plan(plan)
	var copied_bytes: PackedByteArray = _read_user_buffer(target_path)

	_remove_user_file(source_path)
	_remove_user_file(target_path)
	_remove_user_dir(source_dir)
	_remove_user_dir(target_dir)
	_remove_user_dir(root_path)
	_remove_user_dir(target_root)

	assert_eq(GFVariantData.get_option_int(report.metadata, "copied_count"), 1, "大文件复制应仍报告成功。")
	assert_eq(
		GFVariantData.get_option_int(report.metadata, "consumed_copy_bytes"),
		source_bytes.size(),
		"执行期预算应记录实际读取字节数。"
	)
	assert_eq(
		GFVariantData.get_option_int(report.metadata, "committed_copy_bytes"),
		source_bytes.size(),
		"成功提交的字节数应与源文件一致。"
	)
	assert_eq(copied_bytes.size(), source_bytes.size(), "分块复制不应截断音频文件。")
	assert_eq(copied_bytes[0], source_bytes[0], "复制结果应保留文件开头字节。")
	assert_eq(copied_bytes[copied_bytes.size() - 1], source_bytes[source_bytes.size() - 1], "复制结果应保留文件末尾字节。")


func test_audio_library_copy_import_plan_overwrites_existing_target_atomically() -> void:
	var root_path: String = "user://gf_audio_library_overwrite_source"
	var target_root: String = "user://gf_audio_library_overwrite_target"
	var source_dir: String = root_path.path_join("ui")
	var target_dir: String = target_root.path_join("ui")
	var source_path: String = source_dir.path_join("replace.ogg")
	var target_path: String = target_dir.path_join("replace.ogg")
	var _make_source_dir_result: Variant = DirAccess.make_dir_recursive_absolute(source_dir)
	var _make_target_dir_result: Variant = DirAccess.make_dir_recursive_absolute(target_dir)
	_write_user_file(source_path, "new-audio")
	_write_user_file(target_path, "old-audio")
	var plan: Array[Dictionary] = [
		{
			"source_path": source_path,
			"target_path": target_path,
			"will_copy": false,
			"reason": "target_exists",
		},
	]

	var report: GFValidationReport = GFAudioLibraryToolsScript.copy_import_plan(plan, { "overwrite": true })
	var target_content: String = FileAccess.get_file_as_string(target_path)

	_remove_user_file(source_path)
	_remove_user_file(target_path)
	_remove_user_dir(source_dir)
	_remove_user_dir(target_dir)
	_remove_user_dir(root_path)
	_remove_user_dir(target_root)

	assert_true(report.is_ok(), "overwrite=true 时应允许替换已存在目标。")
	assert_eq(GFVariantData.get_option_int(report.metadata, "copied_count"), 1, "替换成功应计为复制。")
	assert_eq(target_content, "new-audio", "目标文件应被完整替换为新内容。")


func test_audio_library_copy_import_plan_rejects_file_count_above_limit() -> void:
	var root_path: String = "user://gf_audio_library_copy_count_source"
	var target_root: String = "user://gf_audio_library_copy_count_target"
	var source_dir: String = root_path.path_join("ui")
	var target_dir: String = target_root.path_join("ui")
	var first_source_path: String = source_dir.path_join("first.ogg")
	var second_source_path: String = source_dir.path_join("second.ogg")
	var first_target_path: String = target_dir.path_join("first.ogg")
	var second_target_path: String = target_dir.path_join("second.ogg")
	var _make_source_dir_result: Variant = DirAccess.make_dir_recursive_absolute(source_dir)
	_write_user_file(first_source_path, "one")
	_write_user_file(second_source_path, "two")
	var plan: Array[Dictionary] = [
		{
			"source_path": first_source_path,
			"target_path": first_target_path,
			"will_copy": true,
			"reason": "",
		},
		{
			"source_path": second_source_path,
			"target_path": second_target_path,
			"will_copy": true,
			"reason": "",
		},
	]

	var report: GFValidationReport = GFAudioLibraryToolsScript.copy_import_plan(plan, {
		"max_copy_files": 1,
	})
	var counts: Dictionary = report.get_issue_counts_by_kind()
	var first_target_exists: bool = FileAccess.file_exists(first_target_path)
	var second_target_exists: bool = FileAccess.file_exists(second_target_path)

	_remove_user_file(first_source_path)
	_remove_user_file(second_source_path)
	_remove_user_file(first_target_path)
	_remove_user_file(second_target_path)
	_remove_user_dir(source_dir)
	_remove_user_dir(target_dir)
	_remove_user_dir(root_path)
	_remove_user_dir(target_root)

	assert_false(report.is_ok(), "超过复制文件数量上限时报告应失败。")
	assert_eq(GFVariantData.get_option_int(counts, "copy_file_count_limit_exceeded"), 1, "报告应记录文件数超限。")
	assert_eq(GFVariantData.get_option_int(report.metadata, "planned_copy_count"), 2, "预算元数据应记录计划复制文件数。")
	assert_eq(GFVariantData.get_option_int(report.metadata, "copied_count"), 0, "超限时不应执行部分复制。")
	assert_false(first_target_exists, "超限时不应写入第一个目标文件。")
	assert_false(second_target_exists, "超限时不应写入第二个目标文件。")


func test_audio_library_copy_import_plan_rejects_total_bytes_above_limit() -> void:
	var root_path: String = "user://gf_audio_library_copy_bytes_source"
	var target_root: String = "user://gf_audio_library_copy_bytes_target"
	var source_dir: String = root_path.path_join("ui")
	var target_dir: String = target_root.path_join("ui")
	var source_path: String = source_dir.path_join("large.ogg")
	var target_path: String = target_dir.path_join("large.ogg")
	var _make_source_dir_result: Variant = DirAccess.make_dir_recursive_absolute(source_dir)
	_write_user_file(source_path, "abcdef")
	var plan: Array[Dictionary] = [
		{
			"source_path": source_path,
			"target_path": target_path,
			"will_copy": true,
			"reason": "",
		},
	]

	var report: GFValidationReport = GFAudioLibraryToolsScript.copy_import_plan(plan, {
		"max_copy_bytes": 5,
	})
	var counts: Dictionary = report.get_issue_counts_by_kind()
	var target_exists: bool = FileAccess.file_exists(target_path)

	_remove_user_file(source_path)
	_remove_user_file(target_path)
	_remove_user_dir(source_dir)
	_remove_user_dir(target_dir)
	_remove_user_dir(root_path)
	_remove_user_dir(target_root)

	assert_false(report.is_ok(), "超过复制总字节上限时报告应失败。")
	assert_eq(GFVariantData.get_option_int(counts, "copy_byte_limit_exceeded"), 1, "报告应记录总字节超限。")
	assert_eq(GFVariantData.get_option_int(report.metadata, "planned_copy_bytes"), 6, "预算元数据应记录计划复制字节数。")
	assert_eq(GFVariantData.get_option_int(report.metadata, "copied_count"), 0, "超限时不应执行部分复制。")
	assert_eq(GFVariantData.get_option_int(report.metadata, "consumed_copy_bytes"), 0, "预检超限不得开始读取。")
	assert_eq(GFVariantData.get_option_int(report.metadata, "committed_copy_bytes"), 0, "预检超限不得提交字节。")
	assert_false(target_exists, "超限时不应写入目标文件。")


func test_audio_library_copy_rejects_source_size_change_after_preflight() -> void:
	var root_path: String = "user://gf_audio_library_copy_changed_source"
	var source_path: String = root_path.path_join("changed.ogg")
	var temp_path: String = root_path.path_join("changed.tmp")
	var _make_root_result: Variant = DirAccess.make_dir_recursive_absolute(root_path)
	_write_user_file(source_path, "1234")
	var expected_source_size: int = GFAudioLibraryToolsScript._get_file_size(source_path)
	_write_user_file(source_path, "12345678")
	var copy_state: Dictionary = {
		"max_bytes": 4,
		"consumed_bytes": 0,
		"committed_bytes": 0,
	}

	var copy_result: Dictionary = GFAudioLibraryToolsScript._copy_file_to_path(
		source_path,
		temp_path,
		expected_source_size,
		copy_state
	)
	var temp_exists: bool = FileAccess.file_exists(temp_path)

	_remove_user_file(source_path)
	_remove_user_file(temp_path)
	_remove_user_dir(root_path)

	assert_eq(GFVariantData.get_option_int(copy_result, "error"), ERR_FILE_CORRUPT)
	assert_eq(GFVariantData.get_option_string_name(copy_result, "reason"), &"source_changed")
	assert_eq(GFVariantData.get_option_int(copy_result, "expected_source_size"), 4)
	assert_eq(GFVariantData.get_option_int(copy_result, "observed_source_size"), 8)
	assert_eq(GFVariantData.get_option_int(copy_state, "consumed_bytes"), 0)
	assert_false(temp_exists, "source identity/长度在正式复制前变化时不得创建临时目标。")


func test_audio_library_copy_recovers_deterministic_interrupted_sidecars() -> void:
	var source_root: String = "user://gf_audio_library_recovery_source"
	var target_root: String = "user://gf_audio_library_recovery_target"
	var source_path: String = source_root.path_join("recover.ogg")
	var target_path: String = target_root.path_join("recover.ogg")
	var temp_path: String = target_path + ".gf-copy.tmp"
	var backup_path: String = target_path + ".gf-copy.backup"
	var _make_source_result: Variant = DirAccess.make_dir_recursive_absolute(source_root)
	var _make_target_result: Variant = DirAccess.make_dir_recursive_absolute(target_root)
	_write_user_file(source_path, "new-audio")
	_write_user_file(temp_path, "partial-new")
	_write_user_file(backup_path, "old-audio")
	var plan: Array[Dictionary] = [{
		"source_path": source_path,
		"target_path": target_path,
		"will_copy": true,
		"reason": "",
	}]

	var report: GFValidationReport = GFAudioLibraryToolsScript.copy_import_plan(
		plan,
		{"overwrite": true}
	)
	var counts: Dictionary = report.get_issue_counts_by_kind()
	var target_content: String = FileAccess.get_file_as_string(target_path)
	var temp_exists: bool = FileAccess.file_exists(temp_path)
	var backup_exists: bool = FileAccess.file_exists(backup_path)

	_remove_user_file(source_path)
	_remove_user_file(target_path)
	_remove_user_file(temp_path)
	_remove_user_file(backup_path)
	_remove_user_dir(source_root)
	_remove_user_dir(target_root)

	assert_true(report.is_ok(), "可恢复的中断 sidecar 不应阻止本次导入。")
	assert_eq(
		GFVariantData.get_option_int(counts, "copy_transaction_recovered"),
		1,
		"恢复动作必须进入可观察报告。"
	)
	assert_eq(target_content, "new-audio", "恢复旧目标后应完成新的原子替换。")
	assert_false(temp_exists, "成功后不得遗留中断 temp。")
	assert_false(backup_exists, "成功后不得遗留旧 backup。")


func test_audio_library_copy_reports_unrecoverable_backup_state() -> void:
	var source_root: String = "user://gf_audio_library_recovery_fail_source"
	var target_root: String = "user://gf_audio_library_recovery_fail_target"
	var source_path: String = source_root.path_join("recover.ogg")
	var target_path: String = target_root.path_join("blocked.ogg")
	var backup_path: String = target_path + ".gf-copy.backup"
	var _make_source_result: Variant = DirAccess.make_dir_recursive_absolute(source_root)
	var _make_target_result: Variant = DirAccess.make_dir_recursive_absolute(target_path)
	_write_user_file(source_path, "new-audio")
	_write_user_file(backup_path, "old-audio")
	var plan: Array[Dictionary] = [{
		"source_path": source_path,
		"target_path": target_path,
		"will_copy": true,
		"reason": "",
	}]

	var report: GFValidationReport = GFAudioLibraryToolsScript.copy_import_plan(
		plan,
		{"overwrite": true}
	)
	var counts: Dictionary = report.get_issue_counts_by_kind()
	var backup_exists: bool = FileAccess.file_exists(backup_path)

	_remove_user_file(source_path)
	_remove_user_file(backup_path)
	_remove_user_dir(target_path)
	_remove_user_dir(source_root)
	_remove_user_dir(target_root)

	assert_false(report.is_ok(), "旧目标无法恢复时复制必须失败关闭。")
	assert_eq(
		GFVariantData.get_option_int(counts, "copy_recovery_failed"),
		1,
		"恢复错误必须有稳定 issue kind。"
	)
	assert_true(backup_exists, "恢复失败时最后已知良好备份必须保留。")


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
