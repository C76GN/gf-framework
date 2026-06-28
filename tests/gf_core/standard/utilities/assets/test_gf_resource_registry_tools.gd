## 测试 GFResourceRegistryTools 的扫描和注册表生成能力。
extends GutTest


func test_create_registry_from_paths_generates_ids_hints_and_path_fields() -> void:
	var registry: GFResourceRegistry = GFResourceRegistryTools.create_registry_from_paths(PackedStringArray([
		"res://assets/ui/menu.tscn",
		"res://assets/audio/click.ogg",
	]), {
		"id_mode": "relative_path",
		"base_path": "res://assets",
		"path_separator": ".",
		"fields_by_id": {
			"ui.menu": {
				&"purpose": "screen",
			},
		},
	})
	var menu_fields: Dictionary = registry.get_entry_fields(&"ui.menu")
	var menu_tags: PackedStringArray = GFVariantData.get_option_packed_string_array(menu_fields, &"tags")

	assert_true(registry.has_entry(&"ui.menu"), "应按相对路径生成稳定资源 ID。")
	assert_true(registry.has_entry(&"audio.click"), "应导入全部支持的路径。")
	assert_eq(registry.get_entry_type_hint(&"ui.menu"), "PackedScene", "场景路径应推导 PackedScene type_hint。")
	assert_eq(registry.get_entry_type_hint(&"audio.click"), "AudioStream", "音频路径应推导 AudioStream type_hint。")
	assert_eq(GFVariantData.get_option_string(menu_fields, &"category"), "ui", "默认 category 应来自相对目录首段。")
	assert_true(menu_tags.has("ui"), "默认 tags 应包含相对目录段。")
	assert_eq(GFVariantData.get_option_string(menu_fields, &"purpose"), "screen", "调用方字段覆盖应合并到条目字段。")
	assert_eq(registry.query(&"category", "ui"), PackedStringArray(["ui.menu"]), "生成字段应可直接用于注册表查询。")


func test_add_paths_to_registry_skips_existing_ids_without_overwrite() -> void:
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	var _initial_report: GFValidationReport = GFResourceRegistryTools.add_paths_to_registry(registry, PackedStringArray([
		"res://assets/ui/click.png",
	]), {
		"id_mode": "basename",
	})

	var report: GFValidationReport = GFResourceRegistryTools.add_paths_to_registry(registry, PackedStringArray([
		"res://assets/icons/click.png",
	]), {
		"id_mode": "basename",
	})
	var counts: Dictionary = report.get_issue_counts_by_kind()

	assert_eq(GFVariantData.get_option_int(counts, "resource_entry_id_exists"), 1, "重复 ID 且未开启覆盖时应跳过。")
	assert_eq(registry.get_entry_path(&"click"), "res://assets/ui/click.png", "原有条目不应被覆盖。")
	assert_eq(GFVariantData.get_option_int(report.metadata, "skipped_count"), 1, "报告应记录跳过数量。")


func test_scan_resource_paths_respects_extension_and_count_limits() -> void:
	var root_path: String = "user://gf_resource_registry_tools_scan"
	var nested_path: String = root_path.path_join("ui")
	var first_path: String = nested_path.path_join("first.tscn")
	var second_path: String = nested_path.path_join("second.png")
	var ignored_path: String = nested_path.path_join("ignored.txt")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(nested_path)
	assert_true(make_error == OK or make_error == ERR_ALREADY_EXISTS, "测试应能创建 user:// 临时目录。")
	_write_empty_user_file(first_path)
	_write_empty_user_file(second_path)
	_write_empty_user_file(ignored_path)

	var paths: PackedStringArray = GFResourceRegistryTools.scan_resource_paths(root_path, {
		"extensions": PackedStringArray(["tscn", "png"]),
		"max_resource_paths": 1,
	})

	_remove_user_file(first_path)
	_remove_user_file(second_path)
	_remove_user_file(ignored_path)
	_remove_user_dir(nested_path)
	_remove_user_dir(root_path)

	assert_push_warning("[GFResourceRegistryTools] scan_resource_paths 已达到 max_resource_paths=1，后续资源已跳过。")
	assert_eq(paths.size(), 1, "资源扫描应遵守 max_resource_paths 上限。")


func test_scan_resource_paths_normalizes_excluded_path_list() -> void:
	var root_path: String = "user://gf_resource_registry_tools_excluded"
	var keep_dir: String = root_path.path_join("keep")
	var skip_dir: String = root_path.path_join("skip")
	var keep_path: String = keep_dir.path_join("keep.tscn")
	var skip_path: String = skip_dir.path_join("skip.tscn")
	var make_keep_error: Error = DirAccess.make_dir_recursive_absolute(keep_dir)
	var make_skip_error: Error = DirAccess.make_dir_recursive_absolute(skip_dir)
	assert_true(make_keep_error == OK or make_keep_error == ERR_ALREADY_EXISTS, "测试应能创建保留目录。")
	assert_true(make_skip_error == OK or make_skip_error == ERR_ALREADY_EXISTS, "测试应能创建排除目录。")
	_write_empty_user_file(keep_path)
	_write_empty_user_file(skip_path)

	var paths: PackedStringArray = GFResourceRegistryTools.scan_resource_paths(root_path + "\\", {
		"extensions": PackedStringArray(["tscn"]),
		"excluded_paths": PackedStringArray([skip_dir + "\\", skip_dir, ""]),
	})

	_remove_user_file(keep_path)
	_remove_user_file(skip_path)
	_remove_user_dir(keep_dir)
	_remove_user_dir(skip_dir)
	_remove_user_dir(root_path)

	assert_true(paths.has(keep_path), "未排除目录中的资源应被扫描。")
	assert_false(paths.has(skip_path), "排除目录中的资源不应被扫描。")


func test_scan_resource_paths_filters_include_and_exclude_patterns() -> void:
	var root_path: String = "user://gf_resource_registry_tools_patterns"
	var ui_dir: String = root_path.path_join("ui")
	var icon_dir: String = ui_dir.path_join("icons")
	var temp_dir: String = root_path.path_join("temp")
	var audio_dir: String = root_path.path_join("audio")
	var menu_path: String = ui_dir.path_join("menu.tscn")
	var draft_path: String = ui_dir.path_join("draft_menu.tscn")
	var icon_path: String = icon_dir.path_join("icon.png")
	var temp_path: String = temp_dir.path_join("menu.tscn")
	var audio_path: String = audio_dir.path_join("click.ogg")
	var make_icon_error: Error = DirAccess.make_dir_recursive_absolute(icon_dir)
	var make_temp_error: Error = DirAccess.make_dir_recursive_absolute(temp_dir)
	var make_audio_error: Error = DirAccess.make_dir_recursive_absolute(audio_dir)
	assert_true(make_icon_error == OK or make_icon_error == ERR_ALREADY_EXISTS, "测试应能创建图标目录。")
	assert_true(make_temp_error == OK or make_temp_error == ERR_ALREADY_EXISTS, "测试应能创建临时目录。")
	assert_true(make_audio_error == OK or make_audio_error == ERR_ALREADY_EXISTS, "测试应能创建音频目录。")
	_write_empty_user_file(menu_path)
	_write_empty_user_file(draft_path)
	_write_empty_user_file(icon_path)
	_write_empty_user_file(temp_path)
	_write_empty_user_file(audio_path)

	var paths: PackedStringArray = GFResourceRegistryTools.scan_resource_paths(root_path, {
		"extensions": PackedStringArray(["tscn", "png", "ogg"]),
		"include_patterns": PackedStringArray(["**/*.tscn", "*.png"]),
		"exclude_patterns": PackedStringArray(["temp/**", "**/draft_*"]),
	})

	_remove_user_file(menu_path)
	_remove_user_file(draft_path)
	_remove_user_file(icon_path)
	_remove_user_file(temp_path)
	_remove_user_file(audio_path)
	_remove_user_dir(icon_dir)
	_remove_user_dir(ui_dir)
	_remove_user_dir(temp_dir)
	_remove_user_dir(audio_dir)
	_remove_user_dir(root_path)

	assert_true(paths.has(menu_path), "include_patterns 应匹配相对路径中的场景资源。")
	assert_true(paths.has(icon_path), "无路径分隔符的模式应可匹配文件名。")
	assert_false(paths.has(draft_path), "exclude_patterns 应能排除命中的资源路径。")
	assert_false(paths.has(temp_path), "exclude_patterns 应能按相对目录排除资源。")
	assert_false(paths.has(audio_path), "未命中 include_patterns 的资源不应被收集。")


func test_collect_dependency_paths_reads_direct_external_resource_dependencies() -> void:
	var dependency_path: String = "user://gf_resource_registry_tools_dependency_entry.tres"
	var root_path: String = "user://gf_resource_registry_tools_dependency_registry.tres"
	var entry: GFResourceRegistryEntry = GFResourceRegistryEntry.new()
	var _configured_entry: Resource = entry.configure(&"menu", "res://assets/ui/menu.tscn", "PackedScene")
	assert_eq(ResourceSaver.save(entry, dependency_path), OK, "测试应能保存依赖资源。")

	var dependency: GFResourceRegistryEntry = _load_registry_entry(dependency_path)
	assert_not_null(dependency, "测试应能加载依赖资源。")
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	registry.entries.append(dependency)
	assert_eq(ResourceSaver.save(registry, root_path), OK, "测试应能保存引用依赖的根资源。")

	var paths: PackedStringArray = GFResourceRegistryTools.collect_dependency_paths(root_path, {
		"recursive": false,
		"include_root": true,
		"extensions": PackedStringArray(["tres"]),
	})

	_remove_user_file(root_path)
	_remove_user_file(dependency_path)

	assert_true(paths.has(root_path), "include_root 应包含入口资源。")
	assert_true(paths.has(dependency_path), "依赖收集应包含外部 Resource 引用。")


func test_collect_dependency_paths_respects_limit() -> void:
	var dependency_path: String = "user://gf_resource_registry_tools_limited_dependency.tres"
	var root_path: String = "user://gf_resource_registry_tools_limited_registry.tres"
	var entry: GFResourceRegistryEntry = GFResourceRegistryEntry.new()
	var _configured_entry: Resource = entry.configure(&"menu", "res://assets/ui/menu.tscn", "PackedScene")
	assert_eq(ResourceSaver.save(entry, dependency_path), OK, "测试应能保存依赖资源。")
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	registry.entries.append(_load_registry_entry(dependency_path))
	assert_eq(ResourceSaver.save(registry, root_path), OK, "测试应能保存引用依赖的根资源。")

	var paths: PackedStringArray = GFResourceRegistryTools.collect_dependency_paths(root_path, {
		"include_root": true,
		"max_dependency_paths": 1,
		"extensions": PackedStringArray(["tres"]),
	})

	_remove_user_file(root_path)
	_remove_user_file(dependency_path)

	assert_push_warning("[GFResourceRegistryTools] collect_dependency_paths 已达到 max_dependency_paths=1，后续依赖已跳过。")
	assert_eq(paths.size(), 1, "依赖收集应遵守 max_dependency_paths 上限。")


func test_build_dependency_report_records_resources_and_direct_dependencies() -> void:
	var dependency_path: String = "user://gf_resource_registry_tools_report_dependency.tres"
	var root_path: String = "user://gf_resource_registry_tools_report_registry.tres"
	var entry: GFResourceRegistryEntry = GFResourceRegistryEntry.new()
	var _configured_entry: Resource = entry.configure(&"menu", "res://assets/ui/menu.tscn", "PackedScene")
	assert_eq(ResourceSaver.save(entry, dependency_path), OK, "测试应能保存依赖资源。")
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	registry.entries.append(_load_registry_entry(dependency_path))
	assert_eq(ResourceSaver.save(registry, root_path), OK, "测试应能保存引用依赖的根资源。")

	var report: Dictionary = GFResourceRegistryTools.build_dependency_report(root_path, {
		"recursive": false,
		"include_root": true,
		"extensions": PackedStringArray(["tres"]),
	})

	_remove_user_file(root_path)
	_remove_user_file(dependency_path)

	var paths: Array = GFVariantData.get_option_array(report, "paths")
	var resources: Array = GFVariantData.get_option_array(report, "resources")
	var root_record: Dictionary = _find_report_record(resources, root_path)
	var direct_dependencies: Array = GFVariantData.get_option_array(root_record, "direct_dependencies")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "健康依赖图不应产生 error。")
	assert_true(GFVariantData.get_option_bool(report, "healthy"), "仅被过滤的非目标扩展不应让报告不健康。")
	assert_true(paths.has(root_path), "报告路径闭包应包含入口资源。")
	assert_true(paths.has(dependency_path), "报告路径闭包应包含支持扩展的直接依赖。")
	assert_true(direct_dependencies.has(dependency_path), "资源记录应保留 Godot 暴露的直接依赖。")
	assert_true(GFVariantData.get_option_int(root_record, "direct_dependency_count") >= 1, "资源记录应记录直接依赖数量。")


func test_build_dependency_report_reports_missing_root_as_error() -> void:
	var report: Dictionary = GFResourceRegistryTools.build_dependency_report("user://gf_resource_registry_tools_missing_root.tres", {
		"extensions": PackedStringArray(["tres"]),
	})
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失入口资源应让报告失败。")
	assert_eq(GFVariantData.get_option_int(report, "missing_count"), 1, "报告应记录缺失资源数量。")
	assert_eq(GFVariantData.get_option_int(report, "error_count"), 1, "缺失入口资源应计为 error。")
	assert_true(_report_has_issue_kind(issues, "missing_resource"), "报告应包含稳定 issue kind。")


func test_build_dependency_report_records_limit_without_push_warning() -> void:
	var dependency_path: String = "user://gf_resource_registry_tools_report_limit_dependency.tres"
	var root_path: String = "user://gf_resource_registry_tools_report_limit_registry.tres"
	var entry: GFResourceRegistryEntry = GFResourceRegistryEntry.new()
	var _configured_entry: Resource = entry.configure(&"menu", "res://assets/ui/menu.tscn", "PackedScene")
	assert_eq(ResourceSaver.save(entry, dependency_path), OK, "测试应能保存依赖资源。")
	var registry: GFResourceRegistry = GFResourceRegistry.new()
	registry.entries.append(_load_registry_entry(dependency_path))
	assert_eq(ResourceSaver.save(registry, root_path), OK, "测试应能保存引用依赖的根资源。")

	var report: Dictionary = GFResourceRegistryTools.build_dependency_report(root_path, {
		"include_root": true,
		"max_dependency_paths": 1,
		"extensions": PackedStringArray(["tres"]),
	})

	_remove_user_file(root_path)
	_remove_user_file(dependency_path)

	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_true(GFVariantData.get_option_bool(report, "limit_reached"), "报告应记录依赖路径数量上限命中。")
	assert_eq(GFVariantData.get_option_int(report, "resource_count"), 1, "路径上限应限制纳入的资源闭包。")
	assert_eq(GFVariantData.get_option_int(report, "warning_count"), 1, "路径上限应通过报告 warning 暴露。")
	assert_true(_report_has_issue_kind(issues, "dependency_count_limit"), "报告应包含稳定的上限 issue kind。")


# --- 私有/辅助方法 ---

func _find_report_record(records: Array, path: String) -> Dictionary:
	for record_value: Variant in records:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		if GFVariantData.get_option_string(record, "path") == path:
			return record
	return {}


func _report_has_issue_kind(issues: Array, kind: String) -> bool:
	for issue_value: Variant in issues:
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false


func _load_registry_entry(path: String) -> GFResourceRegistryEntry:
	var resource: Resource = ResourceLoader.load(path)
	if resource is GFResourceRegistryEntry:
		var entry: GFResourceRegistryEntry = resource
		return entry
	return null


func _write_empty_user_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建 user:// 临时文件。")
	if file != null:
		var _store_string_result_85: Variant = file.store_string("")
		file.close()


func _remove_user_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var remove_error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		assert_eq(remove_error, OK, "测试应能删除 user:// 临时文件。")


func _remove_user_dir(path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(path)
	if DirAccess.dir_exists_absolute(global_path):
		var remove_error: Error = DirAccess.remove_absolute(global_path)
		assert_eq(remove_error, OK, "测试应能删除 user:// 临时目录。")
