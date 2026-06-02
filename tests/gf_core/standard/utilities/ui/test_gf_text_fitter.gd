## 测试 GFTextFitter 的字体尺寸适配。
extends GutTest


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
	auto_fit.deferred_refresh = false
	button.add_child(auto_fit)
	add_child_autofree(button)

	var font_size: int = auto_fit.refresh()

	assert_eq(auto_fit.get_target(), button, "target_path 为空时应绑定父 Control。")
	assert_eq(font_size, 22, "自动适配应返回计算出的字体大小。")
	assert_eq(button.get_theme_font_size(&"font_size"), 22, "自动适配应写入控件主题覆盖。")
