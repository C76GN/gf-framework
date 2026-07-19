## GFTextFitter: 文本尺寸适配器。
##
## 为常见文本控件提供通用字体大小计算，不接管控件布局、主题或项目文本规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFTextFitter
extends RefCounted


# --- 枚举 ---

## 文本测量模式。
## [br]
## @api public
## [br]
## @since 9.0.0
enum MeasurementMode {
	## 根据控件文本布局属性选择测量路径，保持完整换行与排版语义。
	AUTO,
	## 面向不换行短文本，只在最大字号测量一次并按可用区域推导结果。
	SINGLE_LINE,
	## 强制使用完整多行排版测量。
	MULTILINE,
}


# --- 常量 ---

## 默认最小字体尺寸。
## [br]
## @api public
const DEFAULT_MIN_FONT_SIZE: int = 8

## 默认最大字体尺寸。
## [br]
## @api public
const DEFAULT_MAX_FONT_SIZE: int = 64


# --- 公共方法 ---

## 计算并可选应用常见 Control 的合适字体尺寸。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param control: 目标文本控件，支持 Label、RichTextLabel、Button、LineEdit 与 TextEdit，也可通过 options.text 适配自定义控件。
## [br]
## @param options: 可选设置，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、text、content_insets、use_placeholder、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction。
## [br]
## @return 计算出的字体尺寸；目标无效或无法读取文本时返回 0。
## [br]
## @schema options: Dictionary，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、font、text、content_insets、use_placeholder、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction；measurement_mode 默认为 MeasurementMode.AUTO，SINGLE_LINE 只测量一次最大字号并按比例选择连续或候选字号，MULTILINE 强制完整多行排版；font_size_candidates 为整数候选字号数组。
static func fit_control(control: Control, options: Dictionary = {}) -> int:
	if control == null:
		return 0
	if control is RichTextLabel:
		var rich_label: RichTextLabel = control
		return fit_rich_text_label(rich_label, options)
	if control is Label:
		var label: Label = control
		return fit_label(label, options)

	var text_info: Dictionary = _get_control_text_info(control, options)
	if text_info.is_empty():
		return 0

	var resolved_options: Dictionary = _resolve_options(
		control,
		_merge_control_text_options(options, text_info),
		GFVariantData.get_option_string_name(text_info, "font_name", &"font"),
		GFVariantData.get_option_string_name(text_info, "font_size_name", &"font_size")
	)
	resolved_options["available_size"] = _resolve_content_available_size(control, resolved_options)
	var font_size: int = _find_largest_fitting_font_size(control, GFVariantData.get_option_string(text_info, "text", ""), resolved_options)
	if GFVariantData.get_option_bool(resolved_options, "apply", true):
		control.add_theme_font_size_override(
			GFVariantData.get_option_string_name(resolved_options, "font_size_name", &"font_size"),
			font_size
		)
	return font_size


## 计算并可选应用 Label 的合适字体尺寸。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param label: 目标 Label。
## [br]
## @param options: 可选设置，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、font、text、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction。
## [br]
## @return 计算出的字体尺寸；目标无效时返回 0。
## [br]
## @schema options: Dictionary，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、font、text、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction；measurement_mode 默认为 MeasurementMode.AUTO，SINGLE_LINE 适用于无换行短文本的一次测量路径，MULTILINE 强制完整多行排版；font_size_candidates 为整数候选字号数组。
static func fit_label(label: Label, options: Dictionary = {}) -> int:
	if label == null:
		return 0

	var resolved_options: Dictionary = _resolve_options(
		label,
		_merge_control_text_options(options, _get_label_text_info(label)),
		&"font",
		&"font_size"
	)
	resolved_options["available_size"] = _resolve_content_available_size(label, resolved_options)
	var text: String = GFVariantData.get_option_string(resolved_options, "text", label.text)
	var font_size: int = _find_largest_fitting_font_size(label, text, resolved_options)
	if GFVariantData.get_option_bool(resolved_options, "apply", true):
		label.add_theme_font_size_override(
			GFVariantData.get_option_string_name(resolved_options, "font_size_name", &"font_size"),
			font_size
		)
	return font_size


## 计算并可选应用 RichTextLabel 的合适字体尺寸。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param label: 目标 RichTextLabel。
## [br]
## @param options: 可选设置，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、font、text、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction。
## [br]
## @return 计算出的字体尺寸；目标无效时返回 0。
## [br]
## @schema options: Dictionary，支持 min_font_size、max_font_size、font_size_candidates、available_size、fit_width、fit_height、apply、font_name、font_size_name、font、text、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction；measurement_mode 默认为 MeasurementMode.AUTO，MULTILINE 可用于显式保留完整多行排版；font_size_candidates 为整数候选字号数组。
static func fit_rich_text_label(label: RichTextLabel, options: Dictionary = {}) -> int:
	if label == null:
		return 0

	var resolved_options: Dictionary = _resolve_options(
		label,
		_merge_control_text_options(options, _get_rich_text_label_text_info(label)),
		&"normal_font",
		&"normal_font_size"
	)
	resolved_options["available_size"] = _resolve_content_available_size(label, resolved_options)
	var text: String = GFVariantData.get_option_string(resolved_options, "text", "")
	var font_size: int = _find_largest_fitting_font_size(label, text, resolved_options)
	if GFVariantData.get_option_bool(resolved_options, "apply", true):
		label.add_theme_font_size_override(
			GFVariantData.get_option_string_name(resolved_options, "font_size_name", &"normal_font_size"),
			font_size
		)
	return font_size


## 测量常见 Control 在指定字体尺寸下的文本占用。
## [br]
## @api public
## [br]
## @param control: 目标文本控件。
## [br]
## @param font_size: 字体尺寸。
## [br]
## @param options: fit_control() 使用的设置。
## [br]
## @return 文本尺寸；目标无效或字体缺失时返回 Vector2.ZERO。
## [br]
## @schema options: Dictionary，字段同 fit_control() 的 options。
static func measure_control_text(control: Control, font_size: int, options: Dictionary = {}) -> Vector2:
	if control == null:
		return Vector2.ZERO

	var text_info: Dictionary = _get_control_text_info(control, options)
	if text_info.is_empty():
		return Vector2.ZERO

	var resolved_options: Dictionary = _merge_control_text_options(options, text_info)
	resolved_options["available_size"] = _resolve_content_available_size(control, resolved_options)
	return measure_text(control, GFVariantData.get_option_string(text_info, "text", ""), font_size, resolved_options)


## 测量 Control 在指定字体尺寸下的文本占用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param control: 提供主题字体的控件。
## [br]
## @param text: 待测量文本。
## [br]
## @param font_size: 字体尺寸。
## [br]
## @param options: fit_label() 或 fit_rich_text_label() 使用的设置。
## [br]
## @return 文本尺寸；字体缺失时返回 Vector2.ZERO。
## [br]
## @schema options: Dictionary，支持 available_size、fit_width、font_name、font、measurement_mode、horizontal_alignment、autowrap_mode、line_break_flags、justification_flags、text_direction。
static func measure_text(control: Control, text: String, font_size: int, options: Dictionary = {}) -> Vector2:
	if control == null:
		return Vector2.ZERO

	var font_name: StringName = GFVariantData.get_option_string_name(options, "font_name", &"font")
	var font: Font = _get_dictionary_font(options, "font")
	if font == null:
		font = control.get_theme_font(font_name)
	if font == null:
		return Vector2.ZERO

	var available_size: Vector2 = _resolve_available_size(control, options)
	var fit_width: bool = GFVariantData.get_option_bool(options, "fit_width", true)
	var wrap_width: float = available_size.x if fit_width and available_size.x > 0.0 else -1.0
	if _get_measurement_mode(options) == MeasurementMode.SINGLE_LINE:
		return _measure_single_line_text(font, text, font_size, options)
	if _uses_multiline_text_measurement(options):
		return _measure_multiline_text(font, text, font_size, wrap_width, options)
	return _measure_lines(font, text, font_size, wrap_width)


# --- 私有/辅助方法 ---

static func _get_dictionary_font(source: Dictionary, key: Variant) -> Font:
	var value: Variant = GFVariantData.get_option_value(source, key)
	if value is Font:
		return value
	return null


static func _resolve_options(
	control: Control,
	options: Dictionary,
	default_font_name: StringName,
	default_font_size_name: StringName
) -> Dictionary:
	var resolved: Dictionary = options.duplicate(true)
	resolved["font_name"] = GFVariantData.get_option_string_name(resolved, "font_name", default_font_name)
	resolved["font_size_name"] = GFVariantData.get_option_string_name(resolved, "font_size_name", default_font_size_name)
	resolved["min_font_size"] = maxi(GFVariantData.get_option_int(resolved, "min_font_size", DEFAULT_MIN_FONT_SIZE), 1)

	var max_font_size: int = GFVariantData.get_option_int(resolved, "max_font_size", 0)
	if max_font_size <= 0:
		max_font_size = control.get_theme_font_size(GFVariantData.get_option_string_name(resolved, "font_size_name", default_font_size_name))
	if max_font_size <= 0:
		max_font_size = DEFAULT_MAX_FONT_SIZE

	resolved["max_font_size"] = maxi(max_font_size, GFVariantData.get_option_int(resolved, "min_font_size", DEFAULT_MIN_FONT_SIZE))
	resolved["fit_width"] = GFVariantData.get_option_bool(resolved, "fit_width", true)
	resolved["fit_height"] = GFVariantData.get_option_bool(resolved, "fit_height", true)
	resolved["apply"] = GFVariantData.get_option_bool(resolved, "apply", true)
	resolved["measurement_mode"] = _get_measurement_mode(resolved)
	return resolved


static func _merge_control_text_options(options: Dictionary, text_info: Dictionary) -> Dictionary:
	var merged: Dictionary = options.duplicate(true)
	if not merged.has("font_name"):
		merged["font_name"] = GFVariantData.get_option_string_name(text_info, "font_name", &"font")
	if not merged.has("font_size_name"):
		merged["font_size_name"] = GFVariantData.get_option_string_name(text_info, "font_size_name", &"font_size")
	if not merged.has("content_insets"):
		merged["content_insets"] = GFVariantData.get_option_value(text_info, "content_insets", Vector4.ZERO)
	for key: String in [
		"text",
		"horizontal_alignment",
		"line_break_flags",
		"autowrap_mode",
		"justification_flags",
		"text_direction",
		"orientation",
	]:
		if not merged.has(key) and text_info.has(key):
			merged[key] = text_info[key]
	return merged


static func _get_control_text_info(control: Control, options: Dictionary) -> Dictionary:
	if options.has("text"):
		return {
			"text": GFVariantData.get_option_string(options, "text", ""),
			"font_name": GFVariantData.get_option_string_name(options, "font_name", &"font"),
			"font_size_name": GFVariantData.get_option_string_name(options, "font_size_name", &"font_size"),
			"content_insets": GFVariantData.get_option_value(options, "content_insets", Vector4.ZERO),
		}
	if control is RichTextLabel:
		var rich_label: RichTextLabel = control
		return _get_rich_text_label_text_info(rich_label)
	if control is Label:
		var label: Label = control
		return _get_label_text_info(label)
	if control is Button:
		var button: Button = control
		return _get_button_text_info(button)
	if control is LineEdit:
		var line_edit: LineEdit = control
		return _get_line_edit_text_info(line_edit, options)
	if control is TextEdit:
		var text_edit: TextEdit = control
		var line_break_flags: int = int(TextServer.BREAK_MANDATORY)
		if int(text_edit.wrap_mode) != 0:
			line_break_flags = _autowrap_mode_to_line_break_flags(text_edit.autowrap_mode)
		return {
			"text": text_edit.text,
			"font_name": &"font",
			"font_size_name": &"font_size",
			"content_insets": _get_stylebox_insets(control, &"normal"),
			"line_break_flags": line_break_flags,
			"text_direction": text_edit.text_direction,
		}
	return {}


static func _get_button_text_info(button: Button) -> Dictionary:
	var insets: Vector4 = _get_stylebox_insets(button, &"normal")
	var icon: Texture2D = button.icon
	if icon != null:
		var icon_size: Vector2 = icon.get_size()
		insets.x += icon_size.x + float(button.get_theme_constant(&"h_separation", &"Button"))
	return {
		"text": button.text,
		"font_name": &"font",
		"font_size_name": &"font_size",
		"content_insets": insets,
		"horizontal_alignment": button.alignment,
		"line_break_flags": _autowrap_mode_to_line_break_flags(button.autowrap_mode, button.autowrap_trim_flags),
		"text_direction": button.text_direction,
	}


static func _get_line_edit_text_info(line_edit: LineEdit, options: Dictionary) -> Dictionary:
	var text: String = line_edit.text
	if text.is_empty() and GFVariantData.get_option_bool(options, "use_placeholder", true):
		text = line_edit.placeholder_text
	return {
		"text": text,
		"font_name": &"font",
		"font_size_name": &"font_size",
		"content_insets": _get_stylebox_insets(line_edit, &"normal"),
		"horizontal_alignment": line_edit.alignment,
		"line_break_flags": TextServer.BREAK_MANDATORY,
		"text_direction": line_edit.text_direction,
	}


static func _get_label_text_info(label: Label) -> Dictionary:
	return {
		"text": label.text,
		"font_name": &"font",
		"font_size_name": &"font_size",
		"content_insets": Vector4.ZERO,
		"horizontal_alignment": label.horizontal_alignment,
		"line_break_flags": _autowrap_mode_to_line_break_flags(label.autowrap_mode, label.autowrap_trim_flags),
		"justification_flags": label.justification_flags,
		"text_direction": label.text_direction,
	}


static func _get_rich_text_label_text_info(label: RichTextLabel) -> Dictionary:
	var text: String = label.text
	if label.bbcode_enabled:
		text = _strip_bbcode(text)
	return {
		"text": text,
		"font_name": &"normal_font",
		"font_size_name": &"normal_font_size",
		"content_insets": Vector4.ZERO,
		"horizontal_alignment": label.horizontal_alignment,
		"line_break_flags": _autowrap_mode_to_line_break_flags(label.autowrap_mode, label.autowrap_trim_flags),
		"justification_flags": label.justification_flags,
		"text_direction": label.text_direction,
	}


static func _find_largest_fitting_font_size(control: Control, text: String, options: Dictionary) -> int:
	var min_font_size: int = GFVariantData.get_option_int(options, "min_font_size", DEFAULT_MIN_FONT_SIZE)
	var max_font_size: int = GFVariantData.get_option_int(options, "max_font_size", DEFAULT_MAX_FONT_SIZE)
	var font_size_candidates: Array[int] = _resolve_font_size_candidates(options, min_font_size, max_font_size)
	if _get_measurement_mode(options) == MeasurementMode.SINGLE_LINE:
		var measurement_provider: Callable = func(
			measurement_control: Control,
			measurement_text: String,
			measurement_font_size: int,
			measurement_options: Dictionary
		) -> Vector2:
			return measure_text(
				measurement_control,
				measurement_text,
				measurement_font_size,
				measurement_options
			)
		return _find_single_line_font_size_one_pass(
			control,
			text,
			options,
			font_size_candidates,
			min_font_size,
			max_font_size,
			measurement_provider
		)
	if not font_size_candidates.is_empty():
		return _find_largest_candidate_font_size(control, text, options, font_size_candidates, min_font_size)

	var best_size: int = min_font_size
	var low: int = min_font_size
	var high: int = max_font_size

	while low <= high:
		var candidate: int = (low + high) >> 1
		if _fits(control, text, candidate, options):
			best_size = candidate
			low = candidate + 1
		else:
			high = candidate - 1

	return best_size


static func _find_single_line_font_size_one_pass(
	control: Control,
	text: String,
	options: Dictionary,
	font_size_candidates: Array[int],
	min_font_size: int,
	max_font_size: int,
	measurement_provider: Callable
) -> int:
	if not measurement_provider.is_valid():
		return min_font_size
	var measured_size: Vector2 = Vector2.ZERO
	var measured_value: Variant = measurement_provider.call(control, text, max_font_size, options)
	if measured_value is Vector2:
		var vector_measurement: Vector2 = measured_value
		measured_size = vector_measurement
	var available_size: Vector2 = _resolve_available_size(control, options)
	var scale_factor: float = 1.0
	if GFVariantData.get_option_bool(options, "fit_width", true) and available_size.x > 0.0:
		scale_factor = minf(scale_factor, available_size.x / maxf(measured_size.x, 1.0))
	if GFVariantData.get_option_bool(options, "fit_height", true) and available_size.y > 0.0:
		scale_factor = minf(scale_factor, available_size.y / maxf(measured_size.y, 1.0))

	var estimated_font_size: int = clampi(
		floori(float(max_font_size) * minf(scale_factor, 1.0)),
		min_font_size,
		max_font_size
	)
	if font_size_candidates.is_empty():
		return estimated_font_size
	for candidate: int in font_size_candidates:
		if candidate <= estimated_font_size:
			return candidate
	return min_font_size


static func _find_largest_candidate_font_size(
	control: Control,
	text: String,
	options: Dictionary,
	font_size_candidates: Array[int],
	fallback_font_size: int
) -> int:
	for candidate: int in font_size_candidates:
		if _fits(control, text, candidate, options):
			return candidate
	return fallback_font_size


static func _resolve_font_size_candidates(options: Dictionary, min_font_size: int, max_font_size: int) -> Array[int]:
	var raw_candidates: Array[int] = GFVariantData.get_option_int_array(options, "font_size_candidates", [])
	var result: Array[int] = []
	var seen: Dictionary = {}
	for raw_candidate: int in raw_candidates:
		var candidate: int = maxi(raw_candidate, 0)
		if candidate < min_font_size or candidate > max_font_size:
			continue
		if seen.has(candidate):
			continue
		seen[candidate] = true
		result.append(candidate)
	result.sort()
	result.reverse()
	return result


static func _fits(control: Control, text: String, font_size: int, options: Dictionary) -> bool:
	var available_size: Vector2 = _resolve_available_size(control, options)
	if available_size.x <= 0.0 and available_size.y <= 0.0:
		return true

	var measured_size: Vector2 = measure_text(control, text, font_size, options)
	var fit_width: bool = GFVariantData.get_option_bool(options, "fit_width", true)
	var fit_height: bool = GFVariantData.get_option_bool(options, "fit_height", true)
	if fit_width and available_size.x > 0.0 and measured_size.x > available_size.x:
		return false
	if fit_height and available_size.y > 0.0 and measured_size.y > available_size.y:
		return false
	return true


static func _resolve_available_size(control: Control, options: Dictionary) -> Vector2:
	var available_size: Variant = GFVariantData.get_option_value(options, "available_size", control.size)
	if available_size is Vector2i:
		var vector2i_size: Vector2i = available_size
		return Vector2(vector2i_size)
	if available_size is Vector2:
		var vector_size: Vector2 = available_size
		return vector_size
	return control.size


static func _resolve_content_available_size(control: Control, options: Dictionary) -> Vector2:
	var size: Vector2 = _resolve_available_size(control, options)
	var insets: Vector4 = _resolve_content_insets(GFVariantData.get_option_value(options, "content_insets", Vector4.ZERO))
	return Vector2(
		maxf(size.x - insets.x - insets.z, 0.0),
		maxf(size.y - insets.y - insets.w, 0.0)
	)


static func _resolve_content_insets(value: Variant) -> Vector4:
	if value is Vector4:
		var vector: Vector4 = value
		return vector
	if value is Rect2:
		var rect: Rect2 = value
		return Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	if value is Dictionary:
		var data: Dictionary = value
		return Vector4(
			GFVariantData.get_option_float(data, "left", 0.0),
			GFVariantData.get_option_float(data, "top", 0.0),
			GFVariantData.get_option_float(data, "right", 0.0),
			GFVariantData.get_option_float(data, "bottom", 0.0)
		)
	return Vector4.ZERO


static func _get_stylebox_insets(control: Control, stylebox_name: StringName) -> Vector4:
	var stylebox: StyleBox = control.get_theme_stylebox(stylebox_name)
	if stylebox == null:
		return Vector4.ZERO
	return Vector4(
		stylebox.get_margin(SIDE_LEFT),
		stylebox.get_margin(SIDE_TOP),
		stylebox.get_margin(SIDE_RIGHT),
		stylebox.get_margin(SIDE_BOTTOM)
	)


static func _uses_multiline_text_measurement(options: Dictionary) -> bool:
	var measurement_mode: int = _get_measurement_mode(options)
	if measurement_mode == MeasurementMode.MULTILINE:
		return true
	if measurement_mode == MeasurementMode.SINGLE_LINE:
		return false
	if GFVariantData.get_option_bool(options, "use_multiline_measurement", false):
		return true
	for key: String in [
		"horizontal_alignment",
		"line_break_flags",
		"autowrap_mode",
		"justification_flags",
		"text_direction",
		"orientation",
	]:
		if options.has(key):
			return true
	return false


static func _get_measurement_mode(options: Dictionary) -> int:
	return clampi(
		GFVariantData.get_option_int(options, "measurement_mode", MeasurementMode.AUTO),
		MeasurementMode.AUTO,
		MeasurementMode.MULTILINE
	)


static func _measure_single_line_text(
	font: Font,
	text: String,
	font_size: int,
	options: Dictionary
) -> Vector2:
	var alignment: int = GFVariantData.get_option_int(options, "horizontal_alignment", HORIZONTAL_ALIGNMENT_LEFT)
	var justification_flags: int = GFVariantData.get_option_int(
		options,
		"justification_flags",
		TextServer.JUSTIFICATION_KASHIDA | TextServer.JUSTIFICATION_WORD_BOUND
	)
	var text_direction: int = GFVariantData.get_option_int(options, "text_direction", TextServer.DIRECTION_AUTO)
	var orientation: int = GFVariantData.get_option_int(options, "orientation", TextServer.ORIENTATION_HORIZONTAL)
	var size: Vector2 = font.get_string_size(
		text,
		alignment,
		-1.0,
		font_size,
		justification_flags,
		text_direction,
		orientation
	)
	if text.is_empty():
		size.y = maxf(size.y, float(font_size))
	return size


static func _measure_multiline_text(
	font: Font,
	text: String,
	font_size: int,
	wrap_width: float,
	options: Dictionary
) -> Vector2:
	var alignment: int = GFVariantData.get_option_int(options, "horizontal_alignment", HORIZONTAL_ALIGNMENT_LEFT)
	var line_break_flags: int = GFVariantData.get_option_int(options, "line_break_flags", TextServer.BREAK_MANDATORY)
	if options.has("autowrap_mode") and not options.has("line_break_flags"):
		line_break_flags = _autowrap_mode_to_line_break_flags(GFVariantData.get_option_int(options, "autowrap_mode", TextServer.AUTOWRAP_OFF))
	var justification_flags: int = GFVariantData.get_option_int(
		options,
		"justification_flags",
		TextServer.JUSTIFICATION_KASHIDA | TextServer.JUSTIFICATION_WORD_BOUND
	)
	var text_direction: int = GFVariantData.get_option_int(options, "text_direction", TextServer.DIRECTION_AUTO)
	var orientation: int = GFVariantData.get_option_int(options, "orientation", TextServer.ORIENTATION_HORIZONTAL)
	var size: Vector2 = font.get_multiline_string_size(
		text,
		alignment,
		wrap_width,
		font_size,
		-1,
		line_break_flags,
		justification_flags,
		text_direction,
		orientation
	)
	if text.is_empty():
		size.y = maxf(size.y, float(font_size))
	return size


static func _autowrap_mode_to_line_break_flags(autowrap_mode: int, trim_flags: int = 0) -> int:
	var flags: int = int(TextServer.BREAK_MANDATORY) | trim_flags
	match autowrap_mode:
		TextServer.AUTOWRAP_ARBITRARY:
			flags |= TextServer.BREAK_GRAPHEME_BOUND
		TextServer.AUTOWRAP_WORD:
			flags |= TextServer.BREAK_WORD_BOUND
		TextServer.AUTOWRAP_WORD_SMART:
			flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	return flags


static func _measure_lines(font: Font, text: String, font_size: int, wrap_width: float) -> Vector2:
	var lines: PackedStringArray = text.split("\n")
	var max_width: float = 0.0
	var total_height: float = 0.0
	for line: String in lines:
		var line_size: Vector2 = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
		var line_height: float = maxf(line_size.y, float(font_size))
		if wrap_width > 0.0 and line_size.x > wrap_width:
			var wrapped_size: Vector2 = _measure_wrapped_line(font, line, font_size, wrap_width, line_height)
			max_width = maxf(max_width, wrapped_size.x)
			total_height += wrapped_size.y
		else:
			max_width = maxf(max_width, line_size.x)
			total_height += line_height
	return Vector2(max_width, total_height)


static func _measure_wrapped_line(
	font: Font,
	line: String,
	font_size: int,
	wrap_width: float,
	line_height: float
) -> Vector2:
	if line.is_empty():
		return Vector2(0.0, line_height)

	var max_width: float = 0.0
	var line_count: int = 1
	var current_text: String = ""
	for index: int in range(line.length()):
		var next_text: String = current_text + line.substr(index, 1)
		var next_width: float = font.get_string_size(next_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		if not current_text.is_empty() and next_width > wrap_width:
			var current_width: float = font.get_string_size(current_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
			max_width = maxf(max_width, minf(current_width, wrap_width))
			line_count += 1
			current_text = line.substr(index, 1)
		else:
			current_text = next_text

	if not current_text.is_empty():
		var current_width: float = font.get_string_size(current_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		max_width = maxf(max_width, minf(current_width, wrap_width))
	return Vector2(max_width, line_height * float(line_count))


static func _strip_bbcode(text: String) -> String:
	var regex: RegEx = RegEx.new()
	var error: Error = regex.compile("\\[[^\\]]*\\]")
	if error != OK:
		return text
	return regex.sub(text, "", true)
