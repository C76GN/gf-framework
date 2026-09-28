## GFInputDeviceTextProvider: 通用手柄输入文本 provider。
##
## 以抽象方位和轴名称描述 Joypad 输入，项目可通过字典覆盖为任意设备、平台或本地化文本。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputDeviceTextProvider
extends GFInputTextProvider


# --- 常量 ---

## 把 JoyButton 枚举映射到通用方位或按钮英文标签的默认表。
## [br]
## @api private
## [br]
const _DEFAULT_BUTTON_LABELS: Dictionary = {
	JOY_BUTTON_A: "Button South",
	JOY_BUTTON_B: "Button East",
	JOY_BUTTON_X: "Button West",
	JOY_BUTTON_Y: "Button North",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "Left Stick",
	JOY_BUTTON_RIGHT_STICK: "Right Stick",
	JOY_BUTTON_LEFT_SHOULDER: "Left Shoulder",
	JOY_BUTTON_RIGHT_SHOULDER: "Right Shoulder",
	JOY_BUTTON_DPAD_UP: "D-Pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
	JOY_BUTTON_MISC1: "Misc",
	JOY_BUTTON_PADDLE1: "Paddle 1",
	JOY_BUTTON_PADDLE2: "Paddle 2",
	JOY_BUTTON_PADDLE3: "Paddle 3",
	JOY_BUTTON_PADDLE4: "Paddle 4",
	JOY_BUTTON_TOUCHPAD: "Touchpad",
}

## 把 JoyAxis 枚举映射到通用摇杆或扳机英文标签的默认表。
## [br]
## @api private
## [br]
const _DEFAULT_AXIS_LABELS: Dictionary = {
	JOY_AXIS_LEFT_X: "Left Stick X",
	JOY_AXIS_LEFT_Y: "Left Stick Y",
	JOY_AXIS_RIGHT_X: "Right Stick X",
	JOY_AXIS_RIGHT_Y: "Right Stick Y",
	JOY_AXIS_TRIGGER_LEFT: "Left Trigger",
	JOY_AXIS_TRIGGER_RIGHT: "Right Trigger",
}

## 预载输入事件工具脚本，用于将 Variant 收窄为 Joypad 事件类型。
## [br]
## @api private
## [br]
const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")


# --- 导出变量 ---

## Joypad 按钮标签表，Key 为 JoyButton int。
## [br]
## @api public
## [br]
## @schema button_labels: Dictionary，以 JoyButton int 或枚举值为键，值为 String 显示标签。
@export var button_labels: Dictionary = _DEFAULT_BUTTON_LABELS

## Joypad 轴标签表，Key 为 JoyAxis int。
## [br]
## @api public
## [br]
## @schema axis_labels: Dictionary，以 JoyAxis int 或枚举值为键，值为 String 显示标签。
@export var axis_labels: Dictionary = _DEFAULT_AXIS_LABELS

## 正向轴后缀。
## [br]
## @api public
@export var axis_positive_suffix: String = "+"

## 负向轴后缀。
## [br]
## @api public
@export var axis_negative_suffix: String = "-"

## 轴方向判断死区。
## [br]
## @api public
@export_range(0.0, 1.0, 0.001) var axis_direction_deadzone: float = 0.1


# --- 公共方法 ---

## 创建标准手柄文本 provider。
## [br]
## @api public
## [br]
## @param provider_priority: provider 优先级。
## [br]
## @return 文本 provider。
static func create_standard(provider_priority: int = 0) -> GFInputDeviceTextProvider:
	var provider: GFInputDeviceTextProvider = GFInputDeviceTextProvider.new()
	provider.priority = provider_priority
	return provider


## 使用标准标签格式化 Joypad 输入事件。
## [br]
## @api public
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 可选格式化参数。
## [br]
## @schema options: Dictionary，可包含 joypad_button_labels、joypad_axis_labels、joypad_axis_deadzone、joypad_axis_positive_suffix 和 joypad_axis_negative_suffix。
## [br]
## @return 文本；非 Joypad 事件返回空字符串。
static func format_joypad_event(input_event: InputEvent, options: Dictionary = {}) -> String:
	var provider: GFInputDeviceTextProvider = create_standard()
	return provider.get_event_text(input_event, options)


## 判断是否支持指定输入事件。
## [br]
## @api public
## [br]
## @param input_event: 输入事件。
## [br]
## @param _options: 调用选项。
## [br]
## @schema _options: Dictionary，为 provider 接口兼容性接收的选项。
## [br]
## @return 支持返回 true。
func supports_event(input_event: InputEvent, _options: Dictionary = {}) -> bool:
	return input_event is InputEventJoypadButton or input_event is InputEventJoypadMotion


## 获取输入事件文本。
## [br]
## @api public
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 调用选项。
## [br]
## @schema options: Dictionary，可包含 joypad_button_labels、joypad_axis_labels、joypad_axis_deadzone、joypad_axis_positive_suffix 和 joypad_axis_negative_suffix。
## [br]
## @return 文本；不支持时返回空字符串。
func get_event_text(input_event: InputEvent, options: Dictionary = {}) -> String:
	var button_event: InputEventJoypadButton = _INPUT_EVENT_TOOLS.get_joypad_button_event(input_event)
	if button_event != null:
		return _button_as_text(button_event.button_index, options)

	var motion: InputEventJoypadMotion = _INPUT_EVENT_TOOLS.get_joypad_motion_event(input_event)
	if motion != null:
		return _axis_as_text(motion.axis, motion.axis_value, options)
	return ""


# --- 私有/辅助方法 ---

## 优先读取 options 覆盖标签或 provider 标签表，未命中时返回带编号的按钮文本。
## [br]
## @api private
## [br]
func _button_as_text(button: JoyButton, options: Dictionary) -> String:
	var labels: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(options, "joypad_button_labels", button_labels))
	if labels != null and labels.has(int(button)):
		return GFVariantData.to_text(labels[int(button)])
	return "Joy Button %d" % int(button)


## 读取轴标签并按配置死区抑制方向后缀，死区外追加正向或负向后缀。
## [br]
## @api private
## [br]
func _axis_as_text(axis: JoyAxis, axis_value: float, options: Dictionary) -> String:
	var labels: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(options, "joypad_axis_labels", axis_labels))
	var base_text: String = ""
	if labels != null and labels.has(int(axis)):
		base_text = GFVariantData.to_text(labels[int(axis)])
	else:
		base_text = "Joy Axis %d" % int(axis)

	var deadzone: float = GFVariantData.get_option_float(options, "joypad_axis_deadzone", axis_direction_deadzone)
	if absf(axis_value) <= deadzone:
		return base_text
	if axis_value > 0.0:
		return "%s %s" % [base_text, GFVariantData.get_option_string(options, "joypad_axis_positive_suffix", axis_positive_suffix)]
	return "%s %s" % [base_text, GFVariantData.get_option_string(options, "joypad_axis_negative_suffix", axis_negative_suffix)]
