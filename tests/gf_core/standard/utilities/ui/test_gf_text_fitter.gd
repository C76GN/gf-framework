## 测试 GFTextFitter 的字体尺寸适配。
extends GutTest


# --- 测试状态 ---

var _measurement_call_count: int = 0


# --- 测试方法 ---

## 验证 Label 可按尺寸约束应用字体大小。
func test_fit_label_applies_font_size_override() -> void:
	var label: Label = Label.new()
	label.text = "Fit"
	label.size = Vector2(200.0, 60.0)
	add_child_autofree(label)

	var font_size: int = GFTextFitter.fit_label(label, {
		"min_font_size": 8,
		"max_font_size": 28,
		"available_size": Vector2(200.0, 60.0),
	})

	assert_eq(font_size, 28, "空间足够时应使用最大字体。")
	assert_eq(label.get_theme_font_size(&"font_size"), 28, "默认应写入控件主题覆盖。")


## 验证 Label 可在宽度不足时收缩字体。
func test_fit_label_shrinks_to_available_width() -> void:
	var label: Label = Label.new()
	label.text = "Very Wide Text"
	label.size = Vector2(90.0, 40.0)
	add_child_autofree(label)

	var font_size: int = GFTextFitter.fit_label(label, {
		"min_font_size": 6,
		"max_font_size": 40,
		"available_size": Vector2(90.0, 40.0),
	})
	var measured_size: Vector2 = GFTextFitter.measure_text(label, label.text, font_size, {
		"available_size": Vector2(90.0, 40.0),
	})

	assert_lte(font_size, 40, "字体尺寸不应超过配置上限。")
	assert_lte(measured_size.x, 90.0, "计算后的文本宽度应落在可用范围内。")


## 验证 Label 可限制在项目指定的候选字号内。
func test_fit_label_uses_font_size_candidates() -> void:
	var label: Label = Label.new()
	label.text = "Fit"
	label.size = Vector2(200.0, 60.0)
	add_child_autofree(label)

	var font_size: int = GFTextFitter.fit_label(label, {
		"min_font_size": 8,
		"max_font_size": 32,
		"font_size_candidates": [12, 20],
		"available_size": Vector2(200.0, 60.0),
	})

	assert_eq(font_size, 20, "候选字号非空时应返回最大适配候选。")
	assert_eq(label.get_theme_font_size(&"font_size"), 20, "候选字号结果应写入主题覆盖。")


## 验证候选字号会去重并过滤配置范围外的值。
func test_fit_label_filters_font_size_candidates() -> void:
	var label: Label = Label.new()
	label.text = "Fit"
	label.size = Vector2(200.0, 60.0)
	add_child_autofree(label)

	var font_size: int = GFTextFitter.fit_label(label, {
		"min_font_size": 8,
		"max_font_size": 30,
		"font_size_candidates": PackedInt32Array([40, 16, 24, 16, 4]),
		"available_size": Vector2(200.0, 60.0),
	})

	assert_eq(font_size, 24, "候选字号应忽略重复值和 min/max 范围外的值。")


## 验证单行模式只按最大字号的一次测量结果推导连续字号。
func test_fit_control_label_single_line_mode_uses_one_pass_scale() -> void:
	var label: Label = Label.new()
	label.text = "2048 4096 8192"
	label.size = Vector2(100.0, 100.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
	add_child_autofree(label)
	var options: Dictionary = {
		"min_font_size": 12,
		"max_font_size": 48,
		"available_size": Vector2(100.0, 100.0),
		"measurement_mode": GFTextFitter.MeasurementMode.SINGLE_LINE,
		"apply": false,
	}
	var maximum_size: Vector2 = GFTextFitter.measure_text(label, label.text, 48, options)
	var scale_factor: float = minf(
		100.0 / maxf(maximum_size.x, 1.0),
		100.0 / maxf(maximum_size.y, 1.0)
	)
	var expected_size: int = clampi(floori(48.0 * minf(scale_factor, 1.0)), 12, 48)

	var font_size: int = GFTextFitter.fit_control(label, options)

	assert_eq(font_size, expected_size, "单行模式应按一次最大字号测量的比例结果选择字号。")
	assert_lt(font_size, 48, "超出可用宽度的单行文本应收缩。")


## 验证单行字号推导只消费一次测量结果，避免候选或二分搜索重复创建排版对象。
func test_single_line_size_estimate_invokes_measurement_provider_once() -> void:
	var label: Label = Label.new()
	label.size = Vector2(100.0, 100.0)
	add_child_autofree(label)
	_measurement_call_count = 0
	var font_size_candidates: Array[int] = []

	var font_size: int = GFTextFitter._find_single_line_font_size_one_pass(
		label,
		"2048 4096 8192",
		{"available_size": Vector2(100.0, 100.0)},
		font_size_candidates,
		12,
		48,
		Callable(self, "_count_single_line_measurement")
	)

	assert_eq(_measurement_call_count, 1, "单行字号推导必须且只能执行一次文本测量。")
	assert_eq(font_size, 20, "一次测量结果应按可用空间比例推导字号。")


## 验证 Label 分派不会丢弃调用方显式提供的测量文本。
func test_fit_control_label_respects_explicit_single_line_text_override() -> void:
	var label: Label = Label.new()
	label.text = "8"
	label.size = Vector2(100.0, 100.0)
	add_child_autofree(label)
	var common_options: Dictionary = {
		"min_font_size": 12,
		"max_font_size": 48,
		"available_size": Vector2(100.0, 100.0),
		"measurement_mode": GFTextFitter.MeasurementMode.SINGLE_LINE,
		"apply": false,
	}

	var label_text_size: int = GFTextFitter.fit_control(label, common_options)
	var override_options: Dictionary = common_options.duplicate(true)
	override_options["text"] = "888888888888"
	var override_text_size: int = GFTextFitter.fit_control(label, override_options)

	assert_eq(label_text_size, 48, "短 Label 文本在空间足够时应使用最大字号。")
	assert_lt(override_text_size, label_text_size, "显式测量文本应穿过 Label 分派并影响字号结果。")


## 验证单行一次测量模式仍会遵守项目字阶候选集。
func test_fit_label_single_line_mode_selects_candidate_from_estimate() -> void:
	var label: Label = Label.new()
	label.text = "2048 4096 8192"
	label.size = Vector2(100.0, 100.0)
	add_child_autofree(label)
	var continuous_size: int = GFTextFitter.fit_label(label, {
		"min_font_size": 12,
		"max_font_size": 48,
		"available_size": Vector2(100.0, 100.0),
		"measurement_mode": GFTextFitter.MeasurementMode.SINGLE_LINE,
		"apply": false,
	})

	var candidate_size: int = GFTextFitter.fit_label(label, {
		"min_font_size": 12,
		"max_font_size": 48,
		"font_size_candidates": [12, 20, 28, 36, 48],
		"available_size": Vector2(100.0, 100.0),
		"measurement_mode": GFTextFitter.MeasurementMode.SINGLE_LINE,
		"apply": false,
	})
	var expected_candidate_size: int = 12
	for candidate: int in [12, 20, 28, 36, 48]:
		if candidate <= continuous_size:
			expected_candidate_size = maxi(expected_candidate_size, candidate)

	assert_eq(candidate_size, expected_candidate_size, "单行模式应选择不超过连续推导值的最大合法候选字号。")


## 验证 Label 测量会遵循控件自身换行规则。
func test_measure_control_text_uses_label_autowrap() -> void:
	var label: Label = Label.new()
	label.text = "Alpha Beta Gamma Delta"
	label.size = Vector2(72.0, 160.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
	add_child_autofree(label)

	var wrapped_size: Vector2 = GFTextFitter.measure_control_text(label, 20, {
		"available_size": Vector2(72.0, 160.0),
	})
	var single_line_size: Vector2 = GFTextFitter.measure_text(label, label.text, 20, {
		"available_size": Vector2(72.0, 160.0),
		"fit_width": false,
		"autowrap_mode": TextServer.AUTOWRAP_OFF,
	})

	assert_gt(wrapped_size.y, single_line_size.y, "开启自动换行时测量高度应反映多行文本。")
	assert_lt(wrapped_size.x, single_line_size.x, "开启自动换行时测量宽度应小于单行文本。")


## 验证显式多行模式会保留完整换行排版，不会误入单行比例路径。
func test_measure_text_multiline_mode_preserves_wrapping() -> void:
	var label: Label = Label.new()
	label.text = "Alpha Beta Gamma Delta"
	label.size = Vector2(72.0, 160.0)
	add_child_autofree(label)
	var common_options: Dictionary = {
		"available_size": Vector2(72.0, 160.0),
		"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART,
	}
	var multiline_options: Dictionary = common_options.duplicate(true)
	multiline_options["measurement_mode"] = GFTextFitter.MeasurementMode.MULTILINE
	var single_line_options: Dictionary = common_options.duplicate(true)
	single_line_options["measurement_mode"] = GFTextFitter.MeasurementMode.SINGLE_LINE

	var multiline_size: Vector2 = GFTextFitter.measure_text(label, label.text, 20, multiline_options)
	var single_line_size: Vector2 = GFTextFitter.measure_text(label, label.text, 20, single_line_options)

	assert_gt(multiline_size.y, single_line_size.y, "显式 MULTILINE 应按可用宽度产生多行高度。")
	assert_lt(multiline_size.x, single_line_size.x, "显式 MULTILINE 的换行宽度应小于单行宽度。")


## 验证 Label 适配会按换行后的高度寻找字号。
func test_fit_label_uses_label_autowrap_for_height() -> void:
	var label: Label = Label.new()
	label.text = "Alpha Beta Gamma Delta"
	label.size = Vector2(72.0, 120.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
	add_child_autofree(label)

	var font_size: int = GFTextFitter.fit_label(label, {
		"min_font_size": 8,
		"max_font_size": 32,
		"available_size": Vector2(72.0, 120.0),
	})
	var measured_size: Vector2 = GFTextFitter.measure_control_text(label, font_size, {
		"available_size": Vector2(72.0, 120.0),
	})

	assert_lte(measured_size.y, 120.0, "适配后的换行文本高度不应超过可用区域。")


## 验证 RichTextLabel 可忽略 BBCode 标记进行尺寸适配。
func test_fit_rich_text_label_uses_plain_text_measurement() -> void:
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.text = "[b]Fit[/b]"
	label.size = Vector2(200.0, 60.0)
	add_child_autofree(label)

	var font_size: int = GFTextFitter.fit_rich_text_label(label, {
		"min_font_size": 8,
		"max_font_size": 26,
		"available_size": Vector2(200.0, 60.0),
	})

	assert_eq(font_size, 26, "空间足够时 RichTextLabel 应使用最大字体。")
	assert_eq(label.get_theme_font_size(&"normal_font_size"), 26, "应写入 RichTextLabel 的默认字体尺寸覆盖。")


## 验证通用 Control 适配支持 Button。
func test_fit_control_supports_button_text_and_insets() -> void:
	var button: Button = Button.new()
	button.text = "Apply"
	button.size = Vector2(240.0, 80.0)
	add_child_autofree(button)

	var font_size: int = GFTextFitter.fit_control(button, {
		"min_font_size": 8,
		"max_font_size": 30,
	})

	assert_eq(font_size, 30, "Button 空间足够时应使用最大字体。")
	assert_eq(button.get_theme_font_size(&"font_size"), 30, "Button 应写入默认字体尺寸覆盖。")


## 验证通用 Control 适配支持 LineEdit placeholder。
func test_measure_control_text_uses_line_edit_placeholder() -> void:
	var line_edit: LineEdit = LineEdit.new()
	line_edit.placeholder_text = "Search"
	line_edit.size = Vector2(120.0, 32.0)
	add_child_autofree(line_edit)

	var measured_size: Vector2 = GFTextFitter.measure_control_text(line_edit, 16)

	assert_gt(measured_size.x, 0.0, "LineEdit 为空时应能测量 placeholder 文本。")


## 验证自动适配节点会绑定父控件并应用字体大小。
func test_text_auto_fit_refreshes_parent_control() -> void:
	var button: Button = Button.new()
	button.text = "Auto"
	button.size = Vector2(120.0, 40.0)
	var auto_fit: GFTextAutoFit = GFTextAutoFit.new()
	auto_fit.min_font_size = 8
	auto_fit.max_font_size = 22
	auto_fit.options = {
		"font_size_candidates": [12, 18],
	}
	auto_fit.deferred_refresh = false
	button.add_child(auto_fit)
	add_child_autofree(button)

	var font_size: int = auto_fit.refresh()

	assert_eq(auto_fit.get_target(), button, "target_path 为空时应绑定父 Control。")
	assert_eq(font_size, 18, "自动适配应透传候选字号选项。")
	assert_eq(button.get_theme_font_size(&"font_size"), 18, "自动适配应写入控件主题覆盖。")


# --- 私有/辅助方法 ---

func _count_single_line_measurement(
	_control: Control,
	_text: String,
	_font_size: int,
	_options: Dictionary
) -> Vector2:
	_measurement_call_count += 1
	return Vector2(240.0, 48.0)
