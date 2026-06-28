## GFScreenshotUtility: 通用 Viewport 截图捕获与保存工具。
##
## 提供无 UI 的截图捕获、文件保存和批量尺寸/语言截图流程。它不绑定调试面板、
## 上传服务、文件浏览器或项目业务命名规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFScreenshotUtility
extends GFUtility


# --- 信号 ---

## 截图文件保存成功后发出。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param record: 保存结果记录。
## [br]
## @schema record: Dictionary，包含 ok、path、format、size、locale、resolution、error 与 reason 字段。
signal screenshot_saved(record: Dictionary)

## 批量截图开始前发出。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param options: 批量截图选项副本。
## [br]
## @schema options: Dictionary，capture_burst() 接收的选项副本。
signal burst_started(options: Dictionary)

## 批量截图完成后发出。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param report: 批量截图报告。
## [br]
## @schema report: Dictionary，包含 ok、records、saved_count、error_count、locale_count、resolution_count 与 format_count 字段。
signal burst_finished(report: Dictionary)


# --- 常量 ---

## PNG 截图格式。
## [br]
## @api public
## [br]
## @since 5.0.0
const FORMAT_PNG: String = "png"

## JPEG 截图格式。
## [br]
## @api public
## [br]
## @since 5.0.0
const FORMAT_JPG: String = "jpg"

## WebP 截图格式。
## [br]
## @api public
## [br]
## @since 5.0.0
const FORMAT_WEBP: String = "webp"

## 默认截图目录。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_SAVE_DIR: String = "user://screenshots"

## 默认截图文件名前缀。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_PREFIX: String = "screenshot"

## 默认批量截图数量上限。传入 0 表示不限制。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_MAX_BURST_CAPTURES: int = 128


# --- 公共变量 ---

## 默认截图保存目录。
## [br]
## @api public
## [br]
## @since 5.0.0
var default_save_dir: String = DEFAULT_SAVE_DIR

## 默认截图文件名前缀。
## [br]
## @api public
## [br]
## @since 5.0.0
var default_prefix: String = DEFAULT_PREFIX

## 默认截图格式。
## [br]
## @api public
## [br]
## @since 5.0.0
var default_format: String = FORMAT_PNG:
	set(value):
		default_format = _normalize_format(value)

## 默认是否为已存在文件追加数字后缀。
## [br]
## @api public
## [br]
## @since 5.0.0
var default_unique_paths: bool = true

## JPEG/WebP 有损保存质量，范围 0.0 到 1.0。
## [br]
## @api public
## [br]
## @since 5.0.0
var default_quality: float = 0.9:
	set(value):
		default_quality = clampf(value, 0.0, 1.0)


# --- 私有变量 ---

var _burst_capture_active: bool = false


# --- 公共方法 ---

## 捕获 Viewport 图像。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param viewport: 目标 Viewport；为 null 时使用当前 SceneTree root。
## [br]
## @return 捕获的 Image；无可用 Viewport 时返回 null。
func capture_viewport_image(viewport: Viewport = null) -> Image:
	var target_viewport: Viewport = _resolve_viewport(viewport)
	if target_viewport == null:
		return null

	var texture: ViewportTexture = target_viewport.get_texture()
	if texture == null:
		return null
	return texture.get_image()


## 捕获 Viewport PNG 字节。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param viewport: 目标 Viewport；为 null 时使用当前 SceneTree root。
## [br]
## @return PNG 编码字节；捕获失败时为空数组。
func capture_viewport_png_buffer(viewport: Viewport = null) -> PackedByteArray:
	var image: Image = capture_viewport_image(viewport)
	if image == null:
		return PackedByteArray()
	return image.save_png_to_buffer()


## 捕获并保存 Viewport 截图。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param file_path: 目标路径；为空时使用 build_screenshot_path(options)。
## [br]
## @param options: 保存选项，支持 viewport、directory、prefix、format、quality、unique、timestamp、locale、resolution 与 use_subdirectories。
## [br]
## @return 保存结果记录。
## [br]
## @schema options: Dictionary，支持 viewport、directory、prefix、format、quality、unique、timestamp、locale、resolution 与 use_subdirectories。
## [br]
## @schema return: Dictionary，包含 ok、path、format、size、locale、resolution、error 与 reason 字段。
func save_viewport_screenshot(file_path: String = "", options: Dictionary = {}) -> Dictionary:
	var target_viewport: Viewport = _get_viewport_option(options)
	var image: Image = capture_viewport_image(target_viewport)
	return save_image(image, file_path, options)


## 保存已有 Image 为截图文件。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param image: 要保存的图像。
## [br]
## @param file_path: 目标路径；为空时使用 build_screenshot_path(options)。
## [br]
## @param options: 保存选项，支持 directory、prefix、format、quality、unique、timestamp、locale、resolution 与 use_subdirectories。
## [br]
## @return 保存结果记录。
## [br]
## @schema options: Dictionary，支持 directory、prefix、format、quality、unique、timestamp、locale、resolution 与 use_subdirectories。
## [br]
## @schema return: Dictionary，包含 ok、path、format、size、locale、resolution、error 与 reason 字段。
func save_image(image: Image, file_path: String = "", options: Dictionary = {}) -> Dictionary:
	var format: String = _resolve_format(file_path, options)
	var path: String = _resolve_file_path(file_path, options, format)
	var resolution: Vector2i = _get_vector2i_option(options, "resolution", Vector2i.ZERO)
	var locale: String = GFVariantData.get_option_string(options, "locale", TranslationServer.get_locale())
	var record: Dictionary = _make_save_record(false, path, format, Vector2i.ZERO, locale, resolution, ERR_INVALID_PARAMETER)
	if image == null:
		record["reason"] = "image_is_null"
		return record
	if path.is_empty():
		record["reason"] = "path_is_empty"
		return record

	record["size"] = image.get_size()
	if resolution == Vector2i.ZERO:
		record["resolution"] = image.get_size()

	var directory_error: Error = _ensure_directory_for_path(path)
	if directory_error != OK:
		record["error"] = int(directory_error)
		record["reason"] = "directory_unavailable"
		return record

	var save_error: Error = _save_image_with_format(image, path, format, options)
	record["ok"] = save_error == OK
	record["error"] = int(save_error)
	record["reason"] = _get_error_reason(save_error)
	if save_error == OK:
		screenshot_saved.emit(record)
	return record


## 构建截图保存路径。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param options: 路径选项，支持 directory、prefix、format、timestamp、locale、resolution 与 use_subdirectories。
## [br]
## @return 截图路径。
## [br]
## @schema options: Dictionary，支持 directory、prefix、format、timestamp、locale、resolution 与 use_subdirectories。
func build_screenshot_path(options: Dictionary = {}) -> String:
	var directory: String = GFVariantData.get_option_string(options, "directory", default_save_dir)
	if directory.is_empty():
		directory = DEFAULT_SAVE_DIR

	var prefix: String = _sanitize_path_segment(GFVariantData.get_option_string(options, "prefix", default_prefix))
	if prefix.is_empty():
		prefix = DEFAULT_PREFIX

	var format: String = _normalize_format(GFVariantData.get_option_string(options, "format", default_format))
	var timestamp: String = _sanitize_path_segment(GFVariantData.get_option_string(options, "timestamp", _make_timestamp()))
	var base_name: String = "%s_%s" % [prefix, timestamp]
	var locale: String = _sanitize_path_segment(GFVariantData.get_option_string(options, "locale", ""))
	var resolution: Vector2i = _get_vector2i_option(options, "resolution", Vector2i.ZERO)
	var resolution_label: String = _get_resolution_label(resolution)
	var use_subdirectories: bool = GFVariantData.get_option_bool(options, "use_subdirectories", false)

	if use_subdirectories:
		var target_directory: String = directory.path_join(base_name)
		if not locale.is_empty():
			target_directory = target_directory.path_join(locale)
		if not resolution_label.is_empty():
			target_directory = target_directory.path_join(resolution_label)
		return target_directory.path_join("%s.%s" % [base_name, format])

	var file_name: String = base_name
	if not locale.is_empty():
		file_name += "_%s" % locale
	if not resolution_label.is_empty():
		file_name += "_%s" % resolution_label
	return directory.path_join("%s.%s" % [file_name, format])


## 按尺寸、语言和格式批量保存 Viewport 截图。
## [br]
## 该方法只负责临时切换窗口尺寸和 TranslationServer 语言，然后恢复原值；项目层仍应决定
## 何时调用、是否隐藏 UI、是否上传或纳入发布流程。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param options: 批量截图选项，支持 viewport、locales、resolutions、formats、max_captures、pause_tree、frame_delay_seconds、directory、prefix、quality、unique 与 use_subdirectories。
## [br]
## @return 批量截图报告。
## [br]
## @schema options: Dictionary，支持 viewport、locales、resolutions、formats、max_captures、pause_tree、frame_delay_seconds、directory、prefix、quality、unique 与 use_subdirectories。
## [br]
## @schema return: Dictionary，包含 ok、records、saved_count、error_count、locale_count、resolution_count、format_count、planned_count、max_captures 与 error 字段。
func capture_burst(options: Dictionary = {}) -> Dictionary:
	var target_viewport: Viewport = _get_viewport_option(options)
	target_viewport = _resolve_viewport(target_viewport)
	var locales: PackedStringArray = _get_locale_values(options)
	var resolutions: Array[Vector2i] = _get_resolution_values(options)
	var formats: PackedStringArray = _get_format_values(options)
	var records: Array[Dictionary] = []
	var planned_count: int = _get_burst_capture_count(locales, resolutions, formats)
	var max_captures: int = maxi(GFVariantData.get_option_int(options, "max_captures", DEFAULT_MAX_BURST_CAPTURES), 0)
	var report: Dictionary = _make_burst_report(
		records,
		locales.size(),
		resolutions.size(),
		formats.size(),
		planned_count,
		max_captures
	)
	if max_captures > 0 and planned_count > max_captures:
		report["error"] = "max_captures_exceeded"
		burst_finished.emit(report)
		return report
	if target_viewport == null:
		report["error"] = "Viewport is unavailable."
		burst_finished.emit(report)
		return report
	if _burst_capture_active:
		report["error"] = "capture_burst_already_running"
		burst_finished.emit(report)
		return report

	var tree: SceneTree = _get_scene_tree()
	var previous_paused: bool = false
	var should_pause_tree: bool = GFVariantData.get_option_bool(options, "pause_tree", false)
	if tree != null:
		previous_paused = tree.paused
		if should_pause_tree:
			tree.paused = true

	var previous_locale: String = TranslationServer.get_locale()
	var previous_size: Vector2i = DisplayServer.window_get_size()
	var resized_window: bool = false
	_burst_capture_active = true
	burst_started.emit(options.duplicate(true))

	for locale: String in locales:
		if not locale.is_empty():
			TranslationServer.set_locale(locale)
		for resolution: Vector2i in resolutions:
			if _is_valid_resolution(resolution):
				DisplayServer.window_set_size(resolution)
				resized_window = true
			await _wait_for_capture_frame(GFVariantData.get_option_float(options, "frame_delay_seconds", 0.0))

			for format: String in formats:
				var capture_options: Dictionary = options.duplicate(true)
				capture_options["viewport"] = target_viewport
				capture_options["format"] = format
				capture_options["locale"] = TranslationServer.get_locale()
				capture_options["resolution"] = DisplayServer.window_get_size() if resolution == Vector2i.ZERO else resolution
				records.append(save_viewport_screenshot("", capture_options))

	TranslationServer.set_locale(previous_locale)
	if resized_window:
		DisplayServer.window_set_size(previous_size)
	if tree != null and should_pause_tree:
		tree.paused = previous_paused

	_burst_capture_active = false
	_update_burst_report_counts(report, records)
	burst_finished.emit(report)
	return report


# --- 私有/辅助方法 ---

func _resolve_viewport(viewport: Viewport) -> Viewport:
	if is_instance_valid(viewport):
		return viewport

	var tree: SceneTree = _get_scene_tree()
	if tree != null:
		return tree.root
	return null


func _get_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		return tree
	return null


func _get_viewport_option(options: Dictionary) -> Viewport:
	var value: Variant = GFVariantData.get_option_value(options, "viewport")
	if value is Viewport:
		var viewport: Viewport = value
		return viewport
	return null


func _resolve_format(file_path: String, options: Dictionary) -> String:
	var option_format: String = GFVariantData.get_option_string(options, "format", "")
	if not option_format.is_empty():
		return _normalize_format(option_format)

	var extension: String = file_path.get_extension().to_lower()
	if not extension.is_empty():
		return _normalize_format(extension)
	return _normalize_format(default_format)


func _resolve_file_path(file_path: String, options: Dictionary, format: String) -> String:
	var path: String = file_path
	if path.is_empty():
		var path_options: Dictionary = options.duplicate(true)
		path_options["format"] = format
		path = build_screenshot_path(path_options)
	else:
		path = _ensure_extension(path, format)

	if GFVariantData.get_option_bool(options, "unique", default_unique_paths):
		return _make_unique_path(path)
	return path


func _ensure_extension(path: String, format: String) -> String:
	var extension: String = path.get_extension().to_lower()
	if extension.is_empty():
		return "%s.%s" % [path, format]
	return path


func _normalize_format(value: String) -> String:
	var format: String = value.strip_edges().trim_prefix(".").to_lower()
	match format:
		FORMAT_PNG:
			return FORMAT_PNG
		"jpeg", FORMAT_JPG:
			return FORMAT_JPG
		FORMAT_WEBP:
			return FORMAT_WEBP
	return FORMAT_PNG


func _save_image_with_format(image: Image, path: String, format: String, options: Dictionary) -> Error:
	var quality: float = clampf(GFVariantData.get_option_float(options, "quality", default_quality), 0.0, 1.0)
	match format:
		FORMAT_JPG:
			return image.save_jpg(path, quality)
		FORMAT_WEBP:
			var lossy: bool = GFVariantData.get_option_bool(options, "lossy", false)
			return image.save_webp(path, lossy, quality)
	return image.save_png(path)


func _ensure_directory_for_path(path: String) -> Error:
	var directory: String = path.get_base_dir()
	if directory.is_empty():
		return OK
	if DirAccess.dir_exists_absolute(directory):
		return OK
	return DirAccess.make_dir_recursive_absolute(directory)


func _make_unique_path(path: String) -> String:
	if path.is_empty() or not FileAccess.file_exists(path):
		return path

	var base_path: String = path.get_basename()
	var extension: String = path.get_extension()
	for index: int in range(1, 10000):
		var candidate: String = "%s_%d.%s" % [base_path, index, extension]
		if not FileAccess.file_exists(candidate):
			return candidate
	return path


func _make_save_record(
	ok: bool,
	path: String,
	format: String,
	size: Vector2i,
	locale: String,
	resolution: Vector2i,
	error: Error
) -> Dictionary:
	return {
		"ok": ok,
		"path": path,
		"format": format,
		"size": size,
		"locale": locale,
		"resolution": resolution,
		"error": int(error),
		"reason": _get_error_reason(error),
	}


func _get_error_reason(error: Error) -> String:
	if error == OK:
		return ""
	return "error_%d" % int(error)


func _make_timestamp() -> String:
	var datetime: Dictionary = Time.get_datetime_dict_from_system()
	return "%04d%02d%02d_%02d%02d%02d_%03d" % [
		GFVariantData.get_option_int(datetime, "year"),
		GFVariantData.get_option_int(datetime, "month"),
		GFVariantData.get_option_int(datetime, "day"),
		GFVariantData.get_option_int(datetime, "hour"),
		GFVariantData.get_option_int(datetime, "minute"),
		GFVariantData.get_option_int(datetime, "second"),
		Time.get_ticks_msec() % 1000,
	]


func _sanitize_path_segment(value: String) -> String:
	var result: String = value.strip_edges()
	for invalid_character: String in ["\\", "/", ":", "*", "?", "\"", "<", ">", "|"]:
		result = result.replace(invalid_character, "_")
	return result.replace(" ", "_")


func _get_vector2i_option(options: Dictionary, key: Variant, default_value: Vector2i) -> Vector2i:
	return _to_vector2i(GFVariantData.get_option_value(options, key), default_value)


func _to_vector2i(value: Variant, default_value: Vector2i) -> Vector2i:
	if value is Vector2i:
		var vector2i: Vector2i = value
		return vector2i
	if value is Vector2:
		var vector2: Vector2 = value
		return Vector2i(roundi(vector2.x), roundi(vector2.y))
	if value is Dictionary:
		var dictionary: Dictionary = GFVariantData.as_dictionary(value)
		return Vector2i(
			GFVariantData.get_option_int(dictionary, "x", default_value.x),
			GFVariantData.get_option_int(dictionary, "y", default_value.y)
		)
	if value is Array:
		var array: Array = GFVariantData.as_array(value)
		if array.size() >= 2:
			return Vector2i(GFVariantData.to_int(array[0], default_value.x), GFVariantData.to_int(array[1], default_value.y))
	return default_value


func _get_resolution_label(resolution: Vector2i) -> String:
	if not _is_valid_resolution(resolution):
		return ""
	return "%dx%d" % [resolution.x, resolution.y]


func _is_valid_resolution(resolution: Vector2i) -> bool:
	return resolution.x > 0 and resolution.y > 0


func _get_locale_values(options: Dictionary) -> PackedStringArray:
	var locales: PackedStringArray = PackedStringArray()
	var raw_locales: Variant = GFVariantData.get_option_value(options, "locales")
	if raw_locales is PackedStringArray:
		locales = raw_locales
	elif raw_locales is Array:
		var locale_array: Array = GFVariantData.as_array(raw_locales)
		for locale_value: Variant in locale_array:
			_append_packed_string(locales, GFVariantData.to_text(locale_value))
	else:
		var locale: String = GFVariantData.get_option_string(options, "locale", "")
		if not locale.is_empty():
			_append_packed_string(locales, locale)

	if locales.is_empty():
		_append_packed_string(locales, "")
	return locales


func _get_resolution_values(options: Dictionary) -> Array[Vector2i]:
	var resolutions: Array[Vector2i] = []
	var raw_resolutions: Variant = GFVariantData.get_option_value(
		options,
		"resolutions",
		GFVariantData.get_option_value(options, "sizes")
	)
	if raw_resolutions is PackedVector2Array:
		var packed_resolutions: PackedVector2Array = raw_resolutions
		for resolution_vector: Vector2 in packed_resolutions:
			resolutions.append(Vector2i(roundi(resolution_vector.x), roundi(resolution_vector.y)))
	elif raw_resolutions is Array:
		var resolution_array: Array = GFVariantData.as_array(raw_resolutions)
		for resolution_value: Variant in resolution_array:
			resolutions.append(_to_vector2i(resolution_value, Vector2i.ZERO))
	else:
		var single_resolution: Vector2i = _get_vector2i_option(options, "resolution", Vector2i.ZERO)
		if single_resolution == Vector2i.ZERO:
			single_resolution = _get_vector2i_option(options, "window_size", Vector2i.ZERO)
		if single_resolution != Vector2i.ZERO:
			resolutions.append(single_resolution)

	if resolutions.is_empty():
		resolutions.append(Vector2i.ZERO)
	return resolutions


func _get_format_values(options: Dictionary) -> PackedStringArray:
	var formats: PackedStringArray = PackedStringArray()
	var raw_formats: Variant = GFVariantData.get_option_value(options, "formats")
	if raw_formats is PackedStringArray:
		var packed_formats: PackedStringArray = raw_formats
		for format: String in packed_formats:
			_append_packed_string(formats, _normalize_format(format))
	elif raw_formats is Array:
		var format_array: Array = GFVariantData.as_array(raw_formats)
		for format_value: Variant in format_array:
			_append_packed_string(formats, _normalize_format(GFVariantData.to_text(format_value)))
	else:
		_append_packed_string(formats, _normalize_format(GFVariantData.get_option_string(options, "format", default_format)))

	if formats.is_empty():
		_append_packed_string(formats, _normalize_format(default_format))
	return formats


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _make_burst_report(
	records: Array[Dictionary],
	locale_count: int,
	resolution_count: int,
	format_count: int,
	planned_count: int,
	max_captures: int
) -> Dictionary:
	return {
		"ok": false,
		"records": records,
		"saved_count": 0,
		"error_count": 0,
		"locale_count": locale_count,
		"resolution_count": resolution_count,
		"format_count": format_count,
		"planned_count": planned_count,
		"max_captures": max_captures,
		"error": "",
	}


func _get_burst_capture_count(locales: PackedStringArray, resolutions: Array[Vector2i], formats: PackedStringArray) -> int:
	return locales.size() * resolutions.size() * formats.size()


func _update_burst_report_counts(report: Dictionary, records: Array[Dictionary]) -> void:
	var saved_count: int = 0
	var error_count: int = 0
	for record: Dictionary in records:
		if GFVariantData.get_option_bool(record, "ok"):
			saved_count += 1
		else:
			error_count += 1

	report["ok"] = error_count == 0
	report["saved_count"] = saved_count
	report["error_count"] = error_count


func _wait_for_capture_frame(delay_seconds: float) -> void:
	var tree: SceneTree = _get_scene_tree()
	if tree == null:
		return

	await tree.process_frame
	await tree.process_frame
	if delay_seconds > 0.0:
		await tree.create_timer(delay_seconds, true, false, true).timeout
