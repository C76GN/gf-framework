@tool

# GF 编辑器工作区通用 UI 辅助。
#
# 提供页面根节点、工具栏、状态文本、空状态和详情区的统一构建函数。
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 默认详情区最小高度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DEFAULT_DETAILS_MIN_HEIGHT: float = 112.0

## 默认工具栏间距。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const TOOLBAR_SEPARATION: int = 6

## 空状态文本颜色。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const EMPTY_TEXT_COLOR: Color = Color(0.72, 0.72, 0.72)

## 信息文本颜色。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const INFO_TEXT_COLOR: Color = Color(0.72, 0.72, 0.72)

## 成功状态文本颜色。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const OK_TEXT_COLOR: Color = Color(0.45, 0.9, 0.55)

## 警告状态文本颜色。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const WARNING_TEXT_COLOR: Color = Color(1.0, 0.78, 0.35)

## 错误状态文本颜色。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ERROR_TEXT_COLOR: Color = Color(1.0, 0.45, 0.35)


# --- 公共方法 ---

## 应用工作区页面根控件的通用尺寸设置。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param control: 页面根控件。
static func apply_page_root(control: Control) -> void:
	if control == null:
		return
	control.clip_contents = true
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control.custom_minimum_size = Vector2.ZERO


## 创建通用工具栏容器。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 工具栏容器。
static func make_toolbar() -> HBoxContainer:
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_theme_constant_override("separation", TOOLBAR_SEPARATION)
	return toolbar


## 创建通用按钮。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param text: 按钮文本。
## [br]
## @param tooltip: 提示文本。
## [br]
## @param pressed: 按下回调。
## [br]
## @return 按钮。
static func make_button(text: String, tooltip: String = "", pressed: Callable = Callable()) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tooltip
	if pressed.is_valid():
		var _connect_result_113: Variant = button.pressed.connect(pressed)
	return button


## 创建通用摘要 Label。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param text: 初始文本。
## [br]
## @return 摘要 Label。
static func make_summary_label(text: String = "") -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.modulate = INFO_TEXT_COLOR
	return label


## 创建通用空状态 Label。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param text: 初始文本。
## [br]
## @return 空状态 Label。
static func make_empty_label(text: String = "") -> Label:
	var label: Label = make_summary_label(text)
	label.modulate = EMPTY_TEXT_COLOR
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return label


## 创建通用详情输出框。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param min_height: 最小高度。
## [br]
## @return 详情输出框。
static func make_details_output(min_height: float = DEFAULT_DETAILS_MIN_HEIGHT) -> TextEdit:
	var details: TextEdit = TextEdit.new()
	details.editable = false
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	details.custom_minimum_size = Vector2(0.0, min_height)
	return details


## 获取校验报告对应的状态颜色。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param report: GF 字典式报告。
## [br]
## @schema report: Dictionary with optional error_count and warning_count fields.
## [br]
## @return 状态颜色。
static func get_report_color(report: Dictionary) -> Color:
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "error_count", 0) > 0:
		return ERROR_TEXT_COLOR
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_int(report, "warning_count", 0) > 0:
		return WARNING_TEXT_COLOR
	return OK_TEXT_COLOR


## 把状态文本写入 Label。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param label: 目标 Label。
## [br]
## @param text: 状态文本。
## [br]
## @param color: 文本颜色。
static func set_status(label: Label, text: String, color: Color = INFO_TEXT_COLOR) -> void:
	if label == null:
		return
	label.text = text
	label.modulate = color
