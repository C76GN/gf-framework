## 测试 GFScreenshotUtility 的路径构建和图片保存行为。
extends GutTest


# --- 私有变量 ---

var _directories: Array[String] = []


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_directories.clear()


func after_each() -> void:
	for index: int in range(_directories.size() - 1, -1, -1):
		_remove_user_directory(_directories[index])
	_directories.clear()


# --- 测试方法 ---

## 验证截图路径只组合通用上下文，不引入 UI 或业务命名约定。
func test_build_screenshot_path_includes_optional_context() -> void:
	var utility: GFScreenshotUtility = GFScreenshotUtility.new()

	var flat_path: String = utility.build_screenshot_path({
		"directory": "user://shots",
		"prefix": "release shot",
		"timestamp": "2026:06:07 12/00",
		"locale": "zh_CN",
		"resolution": Vector2i(1280, 720),
		"format": "webp",
	})
	var nested_path: String = utility.build_screenshot_path({
		"directory": "user://shots",
		"prefix": "qa",
		"timestamp": "t",
		"locale": "en",
		"resolution": Vector2i(800, 600),
		"use_subdirectories": true,
	})

	assert_eq(flat_path, "user://shots/release_shot_2026_06_07_12_00_zh_CN_1280x720.webp", "平铺路径应包含安全化后的上下文。")
	assert_eq(nested_path, "user://shots/qa_t/en/800x600/qa_t.png", "分目录路径应按时间戳、语言和尺寸组织。")


## 验证 Image 可保存为 PNG，并返回结构化记录。
func test_save_image_writes_png_and_emits_record() -> void:
	var utility: GFScreenshotUtility = GFScreenshotUtility.new()
	var directory: String = _make_test_directory()
	var target_path: String = directory.path_join("shot.png")
	var saved_records: Array[Dictionary] = []
	var _screenshot_saved_connected: Error = utility.screenshot_saved.connect(func(record: Dictionary) -> void:
		saved_records.append(record)
	) as Error

	var result: Dictionary = utility.save_image(_make_image(), target_path, {
		"unique": false,
		"locale": "en",
		"resolution": Vector2i(4, 3),
	})

	assert_true(GFVariantData.get_option_bool(result, "ok"), "有效 Image 应保存成功。")
	assert_eq(GFVariantData.get_option_string(result, "path"), target_path, "结果应记录目标路径。")
	assert_eq(GFVariantData.get_option_string(result, "format"), GFScreenshotUtility.FORMAT_PNG, "PNG 扩展名应解析为 png 格式。")
	assert_eq(GFVariantData.get_option_vector2(result, "size"), Vector2(4, 3), "结果应记录图像尺寸。")
	assert_true(FileAccess.file_exists(target_path), "截图文件应写入磁盘。")
	assert_eq(saved_records.size(), 1, "保存成功后应发出 screenshot_saved。")


## 验证 unique 选项会避免覆盖已有截图。
func test_save_image_unique_path_avoids_overwrite() -> void:
	var utility: GFScreenshotUtility = GFScreenshotUtility.new()
	var directory: String = _make_test_directory()
	var target_path: String = directory.path_join("shot.png")
	var first_result: Dictionary = utility.save_image(_make_image(Color.RED), target_path, {
		"unique": false,
	})
	var second_result: Dictionary = utility.save_image(_make_image(Color.BLUE), target_path, {
		"unique": true,
	})
	var second_path: String = GFVariantData.get_option_string(second_result, "path")

	assert_true(GFVariantData.get_option_bool(first_result, "ok"), "第一次保存应成功。")
	assert_true(GFVariantData.get_option_bool(second_result, "ok"), "第二次保存应成功。")
	assert_ne(second_path, target_path, "unique 保存不应覆盖已有文件。")
	assert_true(second_path.ends_with("_1.png"), "unique 保存应追加稳定数字后缀。")
	assert_true(FileAccess.file_exists(second_path), "unique 路径文件应存在。")


## 验证空图像会返回失败记录而不是写入占位文件。
func test_save_image_rejects_null_image() -> void:
	var utility: GFScreenshotUtility = GFScreenshotUtility.new()
	var directory: String = _make_test_directory()
	var target_path: String = directory.path_join("missing.png")

	var result: Dictionary = utility.save_image(null, target_path, {
		"unique": false,
	})

	assert_false(GFVariantData.get_option_bool(result, "ok"), "空 Image 不应保存成功。")
	assert_eq(GFVariantData.get_option_string(result, "reason"), "image_is_null", "失败原因应稳定。")
	assert_false(FileAccess.file_exists(target_path), "空 Image 不应写入文件。")


## 验证批量截图会在组合数量超过预算时提前拒绝。
func test_capture_burst_rejects_capture_count_above_limit() -> void:
	var utility: GFScreenshotUtility = GFScreenshotUtility.new()
	var finished_reports: Array[Dictionary] = []
	var _burst_finished_connected: Error = utility.burst_finished.connect(func(finished_report: Dictionary) -> void:
		finished_reports.append(finished_report)
	) as Error

	var burst_report: Dictionary = await utility.capture_burst({
		"locales": PackedStringArray(["en", "zh_CN"]),
		"resolutions": [Vector2i.ZERO],
		"formats": PackedStringArray([GFScreenshotUtility.FORMAT_PNG]),
		"max_captures": 1,
	})

	assert_false(GFVariantData.get_option_bool(burst_report, "ok"), "超过 max_captures 时批量截图不应成功。")
	assert_eq(GFVariantData.get_option_string(burst_report, "error"), "max_captures_exceeded", "超限原因应稳定。")
	assert_eq(GFVariantData.get_option_int(burst_report, "planned_count"), 2, "报告应记录原始计划截图数量。")
	assert_eq(GFVariantData.get_option_int(burst_report, "max_captures"), 1, "报告应记录生效上限。")
	assert_eq(GFVariantData.as_array(GFVariantData.get_option_value(burst_report, "records")).size(), 0, "超限时不应保存任何截图记录。")
	assert_eq(finished_reports.size(), 1, "提前拒绝也应发出 burst_finished，方便 UI 复位。")


func test_capture_burst_cancellation_restores_global_environment() -> void:
	var utility: GFScreenshotUtility = GFScreenshotUtility.new()
	var original_locale: String = TranslationServer.get_locale()
	var original_size: Vector2i = DisplayServer.window_get_size()
	var tree: SceneTree = get_tree()
	var original_paused: bool = tree.paused
	var alternate_locale: String = "fr" if original_locale != "fr" else "en"
	var requested_size: Vector2i = Vector2i(maxi(original_size.x + 16, 64), maxi(original_size.y + 16, 64))
	var _deferred_cancel: Variant = utility.call_deferred("cancel_burst", "test_cancel")

	var report: Dictionary = await utility.capture_burst({
		"locales": PackedStringArray([alternate_locale]),
		"resolutions": [requested_size],
		"formats": PackedStringArray([GFScreenshotUtility.FORMAT_PNG]),
		"pause_tree": true,
		"frame_delay_seconds": 0.01,
		"directory": _make_test_directory(),
	})

	assert_false(GFVariantData.get_option_bool(report, "ok"), "取消的批量截图不应报告成功。")
	assert_eq(GFVariantData.get_option_string(report, "error"), "capture_burst_cancelled", "取消应返回稳定错误。")
	assert_eq(GFVariantData.get_option_string_name(report, "cancel_reason"), &"test_cancel", "报告应保留取消原因。")
	assert_eq(TranslationServer.get_locale(), original_locale, "取消后应恢复原 locale。")
	assert_eq(DisplayServer.window_get_size(), original_size, "取消后应恢复原窗口尺寸。")
	assert_eq(tree.paused, original_paused, "取消后应恢复原暂停状态。")


# --- 私有/辅助方法 ---

func _make_test_directory() -> String:
	var path: String = "user://gf_screenshot_utility_test_%d" % Time.get_ticks_usec()
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	assert_eq(error, OK, "测试目录应可创建。")
	_directories.append(path)
	return path


func _make_image(color: Color = Color.RED) -> Image:
	var image: Image = Image.create(4, 3, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image


func _remove_user_directory(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute_path):
		return

	_remove_absolute_directory(absolute_path)


func _remove_absolute_directory(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return

	var _list_dir_begin_result: Error = directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var child_path: String = path.path_join(entry)
			if directory.current_is_dir():
				_remove_absolute_directory(child_path)
			else:
				var _remove_file_result: Error = DirAccess.remove_absolute(child_path)
		entry = directory.get_next()
	directory.list_dir_end()

	var _remove_directory_result: Error = DirAccess.remove_absolute(path)
