@tool

# 为 Godot 原生 EditorProperty 提供普通文本悬浮说明。
extends EditorProperty


# --- 常量 ---

## EditorProperty 上保存完整展示说明的 metadata key。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const TOOLTIP_METADATA: StringName = &"_gf_project_setting_tooltip"

## 无法按窗口宽度自动决定时，普通文本悬浮标签采用的最小宽度。
## [br]
## @api private
const _MINIMUM_TOOLTIP_WIDTH: float = 420.0


# --- Godot 回调方法 ---

## 使用当前属性控件的已配置信息构建纯文本提示控件，不使用引擎传入的展示字符串。
## [br]
## @api private
func _make_custom_tooltip(_for_text: String) -> Object:
	return make_tooltip(self)


# --- 框架内部方法 ---

## 根据 EditorProperty metadata 创建普通文本悬浮控件。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param editor_property: 持有 TOOLTIP_METADATA 的属性编辑器。
## [br]
## @return 有说明时返回 Label，否则返回 null。
static func make_tooltip(editor_property: EditorProperty) -> Object:
	if editor_property == null:
		return null
	var tooltip_value: Variant = editor_property.get_meta(TOOLTIP_METADATA, "")
	var tooltip: String = ""
	if tooltip_value is String:
		tooltip = tooltip_value
	elif tooltip_value is StringName:
		var tooltip_name: StringName = tooltip_value
		tooltip = String(tooltip_name)
	if tooltip.is_empty():
		return null

	var tooltip_label: Label = Label.new()
	tooltip_label.text = tooltip
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.custom_minimum_size = Vector2(_MINIMUM_TOOLTIP_WIDTH, 0.0)
	tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tooltip_label
