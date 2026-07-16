## 测试 GFDirectoryWatchUtility 的快照差异检测。
extends GutTest


# --- 常量 ---

const GF_PATH_ENUMERATION_TOOLS_SCRIPT = preload("res://addons/gf/standard/utilities/io/gf_path_enumeration_tools.gd")


# --- 测试方法 ---

func test_path_enumeration_tools_apply_extension_depth_exclusion_and_limit() -> void:
	var root_path: String = "user://gf_path_enumeration_tools_scan"
	var keep_dir: String = root_path.path_join("keep")
	var deep_dir: String = keep_dir.path_join("deep")
	var skip_dir: String = root_path.path_join("skip")
	var root_file: String = root_path.path_join("root.txt")
	var keep_file: String = keep_dir.path_join("keep.txt")
	var deep_file: String = deep_dir.path_join("deep.txt")
	var skip_file: String = skip_dir.path_join("skip.txt")
	var other_file: String = root_path.path_join("other.json")
	var make_deep_error: Error = DirAccess.make_dir_recursive_absolute(deep_dir)
	var make_skip_error: Error = DirAccess.make_dir_recursive_absolute(skip_dir)
	assert_true(make_deep_error == OK or make_deep_error == ERR_ALREADY_EXISTS, "测试应能创建深层目录。")
	assert_true(make_skip_error == OK or make_skip_error == ERR_ALREADY_EXISTS, "测试应能创建排除目录。")
	_write_text_file(root_file, "root")
	_write_text_file(keep_file, "keep")
	_write_text_file(deep_file, "deep")
	_write_text_file(skip_file, "skip")
	_write_text_file(other_file, "other")

	var report: Dictionary = GF_PATH_ENUMERATION_TOOLS_SCRIPT.scan_files(root_path, {
		"extensions": PackedStringArray(["txt"]),
		"excluded_paths": PackedStringArray([skip_dir]),
		"max_scan_depth": 1,
	})
	var paths: PackedStringArray = GFVariantData.get_option_packed_string_array(report, "paths")
	var limited_report: Dictionary = GF_PATH_ENUMERATION_TOOLS_SCRIPT.scan_files(root_path, {
		"extensions": PackedStringArray(["txt"]),
		"max_file_count": 1,
	})
	var limited_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(limited_report, "paths")

	_remove_user_file(root_file)
	_remove_user_file(keep_file)
	_remove_user_file(deep_file)
	_remove_user_file(skip_file)
	_remove_user_file(other_file)
	_remove_user_dir(deep_dir)
	_remove_user_dir(keep_dir)
	_remove_user_dir(skip_dir)
	_remove_user_dir(root_path)

	assert_true(paths.has(root_file), "根目录匹配扩展名文件应被枚举。")
	assert_true(paths.has(keep_file), "max_scan_depth=1 应允许一层子目录文件。")
	assert_false(paths.has(deep_file), "超过 max_scan_depth 的文件应被跳过。")
	assert_false(paths.has(skip_file), "排除目录内文件应被跳过。")
	assert_false(paths.has(other_file), "扩展名不匹配文件应被跳过。")
	assert_eq(limited_paths.size(), 1, "max_file_count 应限制返回文件数量。")
	assert_true(GFVariantData.get_option_bool(limited_report, "truncated"), "达到数量上限应报告 truncated。")


func test_poll_builds_baseline_then_reports_created_and_deleted_paths() -> void:
	var root_path: String = "user://gf_directory_watch_utility_scan"
	var first_path: String = root_path.path_join("first.txt")
	var second_path: String = root_path.path_join("second.txt")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(root_path)
	assert_true(make_error == OK or make_error == ERR_ALREADY_EXISTS, "测试应能创建 user:// 临时目录。")
	_write_text_file(first_path, "first")

	var watcher: GFDirectoryWatchUtility = GFDirectoryWatchUtility.new()
	var events: Array[GFDirectoryChangeSet] = []
	var _configure_result_17: Variant = watcher.configure({ "extensions": PackedStringArray(["txt"]) })
	watcher.watch_path(root_path)
	var connect_error: int = watcher.changed.connect(func(change_set: GFDirectoryChangeSet) -> void:
		events.append(change_set.duplicate_change_set())
	)
	assert_true(connect_error == OK, "测试应能监听目录变化信号。")

	var baseline: GFDirectoryChangeSet = watcher.poll()
	_write_text_file(second_path, "second")
	var created: GFDirectoryChangeSet = watcher.poll()
	_remove_user_file(first_path)
	var deleted: GFDirectoryChangeSet = watcher.poll()

	_remove_user_file(second_path)
	_remove_user_dir(root_path)

	assert_true(baseline.is_empty(), "默认首次扫描只建立基线，不应报告已存在文件。")
	assert_eq(baseline.snapshot_size, 1, "首次扫描仍应记录快照数量。")
	assert_true(created.created.has(second_path), "新增文件应进入 created 列表。")
	assert_true(deleted.deleted.has(first_path), "删除文件应进入 deleted 列表。")
	assert_eq(events.size(), 2, "只有实际变化应触发 changed 信号。")


func test_poll_can_report_existing_files_on_first_scan() -> void:
	var root_path: String = "user://gf_directory_watch_utility_first_scan"
	var first_path: String = root_path.path_join("first.txt")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(root_path)
	assert_true(make_error == OK or make_error == ERR_ALREADY_EXISTS, "测试应能创建 user:// 临时目录。")
	_write_text_file(first_path, "first")

	var watcher: GFDirectoryWatchUtility = GFDirectoryWatchUtility.new()
	watcher.report_existing_on_first_scan = true
	watcher.watch_path(root_path)

	var change_set: GFDirectoryChangeSet = watcher.poll()

	_remove_user_file(first_path)
	_remove_user_dir(root_path)

	assert_true(change_set.created.has(first_path), "开启 report_existing_on_first_scan 后首次扫描应报告已有文件。")


func test_poll_reports_content_change_without_size_change() -> void:
	var root_path: String = "user://gf_directory_watch_utility_content"
	var file_path: String = root_path.path_join("same_size.txt")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(root_path)
	assert_true(make_error == OK or make_error == ERR_ALREADY_EXISTS, "测试应能创建 user:// 临时目录。")
	_write_text_file(file_path, "aaaa")

	var watcher: GFDirectoryWatchUtility = GFDirectoryWatchUtility.new()
	var _configure_result: Variant = watcher.configure({ "extensions": PackedStringArray(["txt"]) })
	watcher.watch_path(root_path)
	var _baseline: GFDirectoryChangeSet = watcher.poll()
	_write_text_file(file_path, "bbbb")
	var changed: GFDirectoryChangeSet = watcher.poll()

	_remove_user_file(file_path)
	_remove_user_dir(root_path)

	assert_true(changed.modified.has(file_path), "同大小内容变化也应进入 modified 列表。")


func test_path_normalization_and_excluded_paths_match_child_directories() -> void:
	var root_path: String = "user://gf_directory_watch_utility_excluded"
	var keep_dir: String = root_path.path_join("keep")
	var skip_dir: String = root_path.path_join("skip")
	var keep_path: String = keep_dir.path_join("keep.txt")
	var skip_path: String = skip_dir.path_join("skip.txt")
	var make_keep_error: Error = DirAccess.make_dir_recursive_absolute(keep_dir)
	var make_skip_error: Error = DirAccess.make_dir_recursive_absolute(skip_dir)
	assert_true(make_keep_error == OK or make_keep_error == ERR_ALREADY_EXISTS, "测试应能创建保留目录。")
	assert_true(make_skip_error == OK or make_skip_error == ERR_ALREADY_EXISTS, "测试应能创建排除目录。")
	_write_text_file(keep_path, "keep")
	_write_text_file(skip_path, "skip")

	var watcher: GFDirectoryWatchUtility = GFDirectoryWatchUtility.new()
	var _configure_result: GFDirectoryWatchUtility = watcher.configure({
		"extensions": PackedStringArray(["txt"]),
		"excluded_paths": PackedStringArray([root_path + "\\skip/", skip_dir, ""]),
	})
	watcher.report_existing_on_first_scan = true
	watcher.watch_path(root_path + "\\")

	var change_set: GFDirectoryChangeSet = watcher.poll()
	var watch_paths: PackedStringArray = watcher.get_watch_paths()

	_remove_user_file(keep_path)
	_remove_user_file(skip_path)
	_remove_user_dir(keep_dir)
	_remove_user_dir(skip_dir)
	_remove_user_dir(root_path)

	assert_eq(Array(watch_paths), [root_path], "监听路径应统一反斜杠并去掉尾随斜杠。")
	assert_eq(Array(watcher.excluded_paths), [skip_dir], "排除路径应统一反斜杠并去掉尾随斜杠。")
	assert_true(change_set.created.has(keep_path), "未排除目录中的文件应被扫描。")
	assert_false(change_set.created.has(skip_path), "排除目录中的子文件不应被扫描。")


# --- 私有/辅助方法 ---

func _write_text_file(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建 user:// 临时文件。")
	if file != null:
		var _store_string_result_65: Variant = file.store_string(content)
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
