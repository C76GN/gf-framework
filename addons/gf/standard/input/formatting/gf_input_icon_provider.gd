## GFInputIconProvider: 输入图标格式化扩展点。
##
## 项目可继承此资源，把输入事件映射为 Texture2D 或 RichTextLabel BBCode。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFInputIconProvider
extends Resource


# --- 导出变量 ---

## 优先级。数值越大越先尝试。
## [br]
## @api public
@export var priority: int = 0

## BBCode 图标默认尺寸。小于等于 0 时不写尺寸。
## [br]
## @api public
@export var icon_size: int = 24


# --- 公共方法 ---

## 获取优先级。
## [br]
## @api public
## [br]
## @return 优先级。
func get_priority() -> int:
	return priority


## 判断是否支持指定输入事件。
## [br]
## @api public
## [br]
## @param _input_event: 输入事件。
## [br]
## @param _options: 调用选项。
## [br]
## @schema _options: Dictionary，由 GFInputFormatter 传入，包含 provider 特定图标字段。
## [br]
## @return 支持返回 true。
func supports_event(_input_event: InputEvent, _options: Dictionary = {}) -> bool:
	return false


## 获取输入事件图标。
## [br]
## @api public
## [br]
## @param _input_event: 输入事件。
## [br]
## @param _options: 调用选项。
## [br]
## @schema _options: Dictionary，由 GFInputFormatter 传入，包含 provider 特定图标字段。
## [br]
## @return 图标资源；返回 null 会回退到后续 provider。
func get_event_icon(_input_event: InputEvent, _options: Dictionary = {}) -> Texture2D:
	return null


## 获取输入事件 RichTextLabel BBCode。
## [br]
## @api public
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 调用选项。
## [br]
## @schema options: Dictionary，可包含 icon_size 和 provider 特定富文本字段。
## [br]
## @return BBCode；返回空字符串会回退到文本格式化。
func get_event_rich_text(input_event: InputEvent, options: Dictionary = {}) -> String:
	var icon: Texture2D = get_event_icon(input_event, options)
	if icon == null or icon.resource_path.is_empty():
		return ""

	var size: int = GFVariantData.get_option_int(options, "icon_size", icon_size)
	var escaped_path: String = _escape_bbcode(icon.resource_path)
	if size > 0:
		return "[img=%d]%s[/img]" % [size, escaped_path]
	return "[img]%s[/img]" % escaped_path


# --- 私有/辅助方法 ---

func _escape_bbcode(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")
