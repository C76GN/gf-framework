## 测试 GFPathEnumerationTools 的只读路径枚举报告。
extends GutTest


func test_scan_files_reports_depth_limit_without_stopping_sibling_scan() -> void:
	var root_path: String = "user://gf_path_enumeration_depth"
	var deep_dir: String = root_path.path_join("a").path_join("deeper")
	var shallow_path: String = root_path.path_join("z_keep.tres")
	var deep_path: String = deep_dir.path_join("skipped.tres")
	var make_root_error: Error = DirAccess.make_dir_recursive_absolute(root_path)
	var make_deep_error: Error = DirAccess.make_dir_recursive_absolute(deep_dir)
	assert_true(make_root_error == OK or make_root_error == ERR_ALREADY_EXISTS, "测试应能创建扫描根目录。")
	assert_true(make_deep_error == OK or make_deep_error == ERR_ALREADY_EXISTS, "测试应能创建深层目录。")
	_write_empty_user_file(shallow_path)
	_write_empty_user_file(deep_path)

	var report: Dictionary = GFPathEnumerationTools.scan_files(root_path, {
		"extensions": PackedStringArray(["tres"]),
		"max_scan_depth": 1,
	})
	var paths: PackedStringArray = GFVariantData.get_option_packed_string_array(report, "paths")

	_remove_user_file(shallow_path)
	_remove_user_file(deep_path)
	_remove_user_dir(deep_dir)
	_remove_user_dir(root_path.path_join("a"))
	_remove_user_dir(root_path)

	assert_true(GFVariantData.get_option_bool(report, "truncated"), "命中深度上限时报告应标记 truncated。")
	assert_eq(GFVariantData.get_option_string(report, "limit_kind"), "depth", "深度上限应有稳定 limit_kind。")
	assert_eq(GFVariantData.get_option_int(report, "limit_value"), 1, "深度上限应进入报告。")
	assert_true(paths.has(shallow_path), "深度上限只应跳过过深分支，不应停止同层后续文件扫描。")
	assert_false(paths.has(deep_path), "过深分支中的文件不应被枚举。")


func test_scan_files_reports_count_limit() -> void:
	var root_path: String = "user://gf_path_enumeration_count"
	var first_path: String = root_path.path_join("first.tres")
	var second_path: String = root_path.path_join("second.tres")
	var make_root_error: Error = DirAccess.make_dir_recursive_absolute(root_path)
	assert_true(make_root_error == OK or make_root_error == ERR_ALREADY_EXISTS, "测试应能创建扫描根目录。")
	_write_empty_user_file(first_path)
	_write_empty_user_file(second_path)

	var report: Dictionary = GFPathEnumerationTools.scan_files(root_path, {
		"extensions": PackedStringArray(["tres"]),
		"max_file_count": 1,
	})
	var paths: PackedStringArray = GFVariantData.get_option_packed_string_array(report, "paths")

	_remove_user_file(first_path)
	_remove_user_file(second_path)
	_remove_user_dir(root_path)

	assert_true(GFVariantData.get_option_bool(report, "truncated"), "命中数量上限时报告应标记 truncated。")
	assert_eq(GFVariantData.get_option_string(report, "limit_kind"), "count", "数量上限应有稳定 limit_kind。")
	assert_eq(GFVariantData.get_option_int(report, "limit_value"), 1, "数量上限应进入报告。")
	assert_eq(paths.size(), 1, "数量上限应停止后续文件枚举。")
	assert_eq(GFVariantData.get_option_int(report, "scanned_count"), 1, "报告应记录已纳入文件数量。")


func test_scan_files_applies_filter_before_count_budget() -> void:
	var root_path: String = "user://gf_path_enumeration_filter_budget"
	var rejected_path: String = root_path.path_join("a_rejected.tres")
	var accepted_path: String = root_path.path_join("z_accepted.tres")
	var make_root_error: Error = DirAccess.make_dir_recursive_absolute(root_path)
	assert_true(make_root_error == OK or make_root_error == ERR_ALREADY_EXISTS, "测试应能创建扫描根目录。")
	_write_empty_user_file(rejected_path)
	_write_empty_user_file(accepted_path)

	var report: Dictionary = GFPathEnumerationTools.scan_files(root_path, {
		"extensions": PackedStringArray(["tres"]),
		"file_filter": func(path: String) -> bool:
			return path == accepted_path,
		"max_file_count": 1,
	})
	var paths: PackedStringArray = GFVariantData.get_option_packed_string_array(report, "paths")

	_remove_user_file(rejected_path)
	_remove_user_file(accepted_path)
	_remove_user_dir(root_path)

	assert_eq(paths, PackedStringArray([accepted_path]), "数量预算只能消耗已通过过滤的文件。")
	assert_eq(GFVariantData.get_option_int(report, "scanned_count"), 1, "scanned_count 应表示已纳入文件数。")


func test_scan_files_bounds_visited_entries_before_extension_filtering() -> void:
	var root_path: String = "user://gf_path_enumeration_entry_budget"
	var first_path: String = root_path.path_join("first.txt")
	var second_path: String = root_path.path_join("second.txt")
	var make_root_error: Error = DirAccess.make_dir_recursive_absolute(root_path)
	assert_true(make_root_error == OK or make_root_error == ERR_ALREADY_EXISTS, "测试应能创建扫描根目录。")
	_write_empty_user_file(first_path)
	_write_empty_user_file(second_path)

	var report: Dictionary = GFPathEnumerationTools.scan_files(root_path, {
		"extensions": PackedStringArray(["tres"]),
		"max_file_count": 1,
		"max_entry_count": 1,
	})

	_remove_user_file(first_path)
	_remove_user_file(second_path)
	_remove_user_dir(root_path)

	assert_true(GFVariantData.get_option_bool(report, "truncated"), "不匹配扩展名的目录项也必须消耗遍历预算。")
	assert_eq(GFVariantData.get_option_string(report, "limit_kind"), "entry_count", "遍历预算应与输出数量预算分开报告。")
	assert_eq(GFVariantData.get_option_int(report, "visited_entry_count"), 1, "实际访问的目录项不得超过预算。")
	assert_eq(GFVariantData.get_option_int(report, "scanned_count"), 0, "未匹配文件不得计入输出数量。")


# --- 私有/辅助方法 ---

func _write_empty_user_file(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建 user:// 临时文件。")
	if file != null:
		var _store_string_result: Variant = file.store_string("")
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
