## GFInputEventIdentity: 输入事件的稳定语义身份。
##
## 将 Godot InputEvent 归一为框架可复用的显示键、冲突键与图标候选键。
## 它不读取 InputMap，不规定项目 action 命名，也不绑定具体图标资源。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 8.0.0
## [br]
## @layer standard/input
class_name GFInputEventIdentity
extends RefCounted


# --- 常量 ---

## 未识别或空输入事件。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_NONE: StringName = &""

## Godot InputEventAction。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_ACTION: StringName = &"action"

## 键盘按键事件。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_KEY: StringName = &"key"

## 鼠标按钮事件。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_MOUSE_BUTTON: StringName = &"mouse_button"

## 手柄按钮事件。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_JOY_BUTTON: StringName = &"joy_button"

## 手柄轴事件。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_JOY_AXIS: StringName = &"joy_axis"

## 触屏按下事件。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_TOUCH: StringName = &"touch"

## 触屏拖动事件。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_SCREEN_DRAG: StringName = &"screen_drag"

## 未专门建模的其他 InputEvent。
## [br]
## @api public
## [br]
## @since 8.0.0
const KIND_UNKNOWN: StringName = &"unknown"

const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")


# --- 公共变量 ---

## 输入事件类别。
## [br]
## @api public
## [br]
## @since 8.0.0
var kind: StringName = KIND_NONE

## 主身份键。用于日志、报告和调试展示中的稳定归类。
## [br]
## @api public
## [br]
## @since 8.0.0
var primary_key: String = ""

## 显示键。用于 UI 或文档层决定如何进一步本地化。
## [br]
## @api public
## [br]
## @since 8.0.0
var display_key: String = ""

## 冲突键。默认不包含设备 ID，设备匹配应使用 get_signature()。
## [br]
## @api public
## [br]
## @since 8.0.0
var conflict_key: String = ""

## 首选图标键。没有稳定图标语义时为空。
## [br]
## @api public
## [br]
## @since 8.0.0
var icon_key: StringName = &""

## 输入事件携带的 Godot device ID。
## [br]
## @api public
## [br]
## @since 8.0.0
var device_id: int = -1

## 轴方向。正向为 1，负向为 -1，未知或不适用为 0。
## [br]
## @api public
## [br]
## @since 8.0.0
var axis_sign: int = 0

## 附加元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema metadata: Dictionary，包含事件类型相关的纯数据字段。
var metadata: Dictionary = {}


# --- 公共方法 ---

## 从输入事件构建稳定身份。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 归一化选项。
## [br]
## @schema options: Dictionary，可包含 include_key_modifiers、include_key_modifier_combo、match_touch_index 和 joy_axis_sign。
## [br]
## @return 输入事件身份；空事件返回 kind 为空的身份。
static func from_event(input_event: InputEvent, options: Dictionary = {}) -> GFInputEventIdentity:
	var identity: GFInputEventIdentity = GFInputEventIdentity.new()
	if input_event == null:
		return identity

	identity.device_id = input_event.device
	var action_event: InputEventAction = _INPUT_EVENT_TOOLS.get_action_event(input_event)
	if action_event != null:
		_apply_action_event(identity, action_event)
		return identity

	var key_event: InputEventKey = _INPUT_EVENT_TOOLS.get_key_event(input_event)
	if key_event != null:
		_apply_key_event(identity, key_event, options)
		return identity

	var mouse_button_event: InputEventMouseButton = _INPUT_EVENT_TOOLS.get_mouse_button_event(input_event)
	if mouse_button_event != null:
		_apply_mouse_button_event(identity, mouse_button_event)
		return identity

	var joypad_button_event: InputEventJoypadButton = _INPUT_EVENT_TOOLS.get_joypad_button_event(input_event)
	if joypad_button_event != null:
		_apply_joy_button_event(identity, joypad_button_event)
		return identity

	var joypad_motion_event: InputEventJoypadMotion = _INPUT_EVENT_TOOLS.get_joypad_motion_event(input_event)
	if joypad_motion_event != null:
		_apply_joy_axis_event(identity, joypad_motion_event, options)
		return identity

	var touch_event: InputEventScreenTouch = _INPUT_EVENT_TOOLS.get_screen_touch_event(input_event)
	if touch_event != null:
		_apply_touch_event(identity, touch_event, options)
		return identity

	var drag_event: InputEventScreenDrag = _INPUT_EVENT_TOOLS.get_screen_drag_event(input_event)
	if drag_event != null:
		_apply_screen_drag_event(identity, drag_event, options)
		return identity

	_apply_unknown_event(identity, input_event)
	return identity


## 获取输入事件可能使用的图标键。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param input_event: 输入事件。
## [br]
## @param options: 归一化选项。
## [br]
## @schema options: Dictionary，可包含 include_key_modifier_combo、match_touch_index 和 joy_axis_sign。
## [br]
## @return 图标键列表，按优先级排序。
static func get_icon_candidates(input_event: InputEvent, options: Dictionary = {}) -> PackedStringArray:
	var candidates: PackedStringArray = PackedStringArray()
	if input_event == null:
		return candidates

	var action_event: InputEventAction = _INPUT_EVENT_TOOLS.get_action_event(input_event)
	if action_event != null:
		_append_unique_candidate(candidates, "action:%s" % _sanitize_icon_name(String(action_event.action)))
		return candidates

	var key_event: InputEventKey = _INPUT_EVENT_TOOLS.get_key_event(input_event)
	if key_event != null:
		_append_key_icon_candidates(candidates, key_event, options)
		return candidates

	var mouse_button_event: InputEventMouseButton = _INPUT_EVENT_TOOLS.get_mouse_button_event(input_event)
	if mouse_button_event != null:
		_append_mouse_button_icon_candidates(candidates, mouse_button_event.button_index)
		return candidates

	var joypad_button_event: InputEventJoypadButton = _INPUT_EVENT_TOOLS.get_joypad_button_event(input_event)
	if joypad_button_event != null:
		_append_joy_button_icon_candidates(candidates, joypad_button_event.button_index)
		return candidates

	var joypad_motion_event: InputEventJoypadMotion = _INPUT_EVENT_TOOLS.get_joypad_motion_event(input_event)
	if joypad_motion_event != null:
		_append_joy_axis_icon_candidates(candidates, joypad_motion_event, options)
		return candidates

	if input_event is InputEventScreenTouch:
		_append_unique_candidate(candidates, "touch")
	return candidates


## 判断身份是否为空。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 空身份返回 true。
func is_empty() -> bool:
	return kind == KIND_NONE or conflict_key.is_empty()


## 获取冲突签名。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param include_device: 是否把 device_id 纳入签名。
## [br]
## @return 稳定冲突签名；空身份返回空字符串。
func get_signature(include_device: bool = false) -> String:
	if is_empty():
		return ""
	return "%s@%s" % [conflict_key, str(device_id) if include_device else "*"]


## 转换为字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param json_compatible: 是否把 metadata 转换为 JSON 兼容值。
## [br]
## @return 身份字典。
## [br]
## @schema return: Dictionary with kind, primary_key, display_key, conflict_key, icon_key, device_id, axis_sign, and metadata fields.
func to_dictionary(json_compatible: bool = true) -> Dictionary:
	var metadata_value: Variant = GFVariantJsonCodec.variant_to_json_compatible(metadata) if json_compatible else metadata.duplicate(true)
	return {
		&"kind": String(kind),
		&"primary_key": primary_key,
		&"display_key": display_key,
		&"conflict_key": conflict_key,
		&"icon_key": String(icon_key),
		&"device_id": device_id,
		&"axis_sign": axis_sign,
		&"metadata": metadata_value,
	}


## 从字典恢复输入事件身份。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 身份字典。
## [br]
## @schema data: Dictionary produced by to_dictionary(), or a compatible dictionary with the same fields.
## [br]
## @return 输入事件身份。
static func from_dictionary(data: Dictionary) -> GFInputEventIdentity:
	var identity: GFInputEventIdentity = GFInputEventIdentity.new()
	identity.kind = GFVariantData.get_option_string_name(data, &"kind", KIND_NONE)
	identity.primary_key = GFVariantData.get_option_string(data, &"primary_key")
	identity.display_key = GFVariantData.get_option_string(data, &"display_key")
	identity.conflict_key = GFVariantData.get_option_string(data, &"conflict_key")
	identity.icon_key = GFVariantData.get_option_string_name(data, &"icon_key")
	identity.device_id = GFVariantData.get_option_int(data, &"device_id", -1)
	identity.axis_sign = clampi(GFVariantData.get_option_int(data, &"axis_sign"), -1, 1)
	var metadata_value: Variant = GFVariantData.get_option_value(data, &"metadata", {})
	identity.metadata = GFVariantData.as_dictionary(GFVariantJsonCodec.json_compatible_to_variant(metadata_value))
	return identity


# --- 私有/辅助方法 ---

static func _apply_action_event(identity: GFInputEventIdentity, event: InputEventAction) -> void:
	var action_text: String = String(event.action)
	identity.kind = KIND_ACTION
	identity.primary_key = "action:%s" % action_text
	identity.display_key = action_text
	identity.conflict_key = identity.primary_key
	identity.icon_key = StringName("action:%s" % _sanitize_icon_name(action_text))
	identity.axis_sign = 0
	identity.metadata = {
		&"action": action_text,
	}


static func _apply_key_event(identity: GFInputEventIdentity, event: InputEventKey, options: Dictionary) -> void:
	var keycode: int = int(event.physical_keycode)
	if keycode == int(KEY_NONE):
		keycode = int(event.keycode)

	var include_modifiers: bool = GFVariantData.get_option_bool(options, &"include_key_modifiers", true)
	identity.kind = KIND_KEY
	identity.primary_key = "key:%d" % keycode
	identity.display_key = _get_key_display_text(keycode)
	if include_modifiers:
		identity.conflict_key = "key:%d:%d:%d:%d:%d" % [
			keycode,
			1 if event.ctrl_pressed else 0,
			1 if event.alt_pressed else 0,
			1 if event.shift_pressed else 0,
			1 if event.meta_pressed else 0,
		]
	else:
		identity.conflict_key = identity.primary_key

	var candidates: PackedStringArray = PackedStringArray()
	_append_key_icon_candidates(candidates, event, options)
	identity.icon_key = StringName(candidates[0]) if not candidates.is_empty() else &""
	identity.axis_sign = 0
	identity.metadata = {
		&"keycode": keycode,
		&"physical_keycode": int(event.physical_keycode),
		&"logical_keycode": int(event.keycode),
		&"ctrl": event.ctrl_pressed,
		&"alt": event.alt_pressed,
		&"shift": event.shift_pressed,
		&"meta": event.meta_pressed,
	}


static func _apply_mouse_button_event(identity: GFInputEventIdentity, event: InputEventMouseButton) -> void:
	identity.kind = KIND_MOUSE_BUTTON
	identity.primary_key = "mouse_button:%d" % int(event.button_index)
	identity.display_key = identity.primary_key
	identity.conflict_key = identity.primary_key
	var candidates: PackedStringArray = PackedStringArray()
	_append_mouse_button_icon_candidates(candidates, event.button_index)
	identity.icon_key = StringName(candidates[0]) if not candidates.is_empty() else &""
	identity.axis_sign = 0
	identity.metadata = {
		&"button_index": int(event.button_index),
	}


static func _apply_joy_button_event(identity: GFInputEventIdentity, event: InputEventJoypadButton) -> void:
	identity.kind = KIND_JOY_BUTTON
	identity.primary_key = "joy_button:%d" % int(event.button_index)
	identity.display_key = identity.primary_key
	identity.conflict_key = identity.primary_key
	var candidates: PackedStringArray = PackedStringArray()
	_append_joy_button_icon_candidates(candidates, event.button_index)
	identity.icon_key = StringName(candidates[0]) if not candidates.is_empty() else &""
	identity.axis_sign = 0
	identity.metadata = {
		&"button_index": int(event.button_index),
	}


static func _apply_joy_axis_event(identity: GFInputEventIdentity, event: InputEventJoypadMotion, options: Dictionary) -> void:
	var sign_override: int = clampi(GFVariantData.get_option_int(options, &"joy_axis_sign"), -1, 1)
	var sign_value: int = sign_override if sign_override != 0 else _get_axis_sign(event.axis_value)
	var direction: String = _axis_sign_to_conflict_direction(sign_value)
	identity.kind = KIND_JOY_AXIS
	identity.primary_key = "joy_axis:%d:%s" % [int(event.axis), direction]
	identity.display_key = identity.primary_key
	identity.conflict_key = identity.primary_key
	var candidates: PackedStringArray = PackedStringArray()
	_append_joy_axis_icon_candidates(candidates, event, options)
	identity.icon_key = StringName(candidates[0]) if not candidates.is_empty() else &""
	identity.axis_sign = sign_value
	identity.metadata = {
		&"axis": int(event.axis),
		&"axis_sign": sign_value,
	}


static func _apply_touch_event(identity: GFInputEventIdentity, event: InputEventScreenTouch, options: Dictionary) -> void:
	var match_touch_index: bool = GFVariantData.get_option_bool(options, &"match_touch_index", false)
	identity.kind = KIND_TOUCH
	identity.primary_key = "screen_touch:%d" % event.index if match_touch_index else "screen_touch"
	identity.display_key = identity.primary_key
	identity.conflict_key = identity.primary_key
	identity.icon_key = &"touch"
	identity.axis_sign = 0
	identity.metadata = {
		&"index": event.index,
	}


static func _apply_screen_drag_event(identity: GFInputEventIdentity, event: InputEventScreenDrag, options: Dictionary) -> void:
	var match_touch_index: bool = GFVariantData.get_option_bool(options, &"match_touch_index", false)
	identity.kind = KIND_SCREEN_DRAG
	identity.primary_key = "screen_drag:%d" % event.index if match_touch_index else "screen_drag"
	identity.display_key = identity.primary_key
	identity.conflict_key = identity.primary_key
	identity.icon_key = &""
	identity.axis_sign = 0
	identity.metadata = {
		&"index": event.index,
	}


static func _apply_unknown_event(identity: GFInputEventIdentity, event: InputEvent) -> void:
	var event_text: String = event.as_text()
	identity.kind = KIND_UNKNOWN
	identity.primary_key = "event:%s" % event_text
	identity.display_key = event_text
	identity.conflict_key = identity.primary_key
	identity.icon_key = &""
	identity.axis_sign = 0
	identity.metadata = {
		&"event_class": event.get_class(),
	}


static func _append_key_icon_candidates(candidates: PackedStringArray, event: InputEventKey, options: Dictionary) -> void:
	var keycode: int = int(event.physical_keycode)
	if keycode == int(KEY_NONE):
		keycode = int(event.keycode)

	var key_name: String = _sanitize_icon_name(OS.get_keycode_string(keycode))
	var modifiers: PackedStringArray = _get_key_modifier_names(event)
	if GFVariantData.get_option_bool(options, &"include_key_modifier_combo", true) and not modifiers.is_empty():
		var combo_parts: PackedStringArray = modifiers.duplicate()
		_append_unique_candidate(combo_parts, key_name)
		_append_unique_candidate(candidates, "key:%s" % "+".join(combo_parts))
	if not key_name.is_empty():
		_append_unique_candidate(candidates, "key:%s" % key_name)
	_append_unique_candidate(candidates, "key:%d" % keycode)


static func _append_mouse_button_icon_candidates(candidates: PackedStringArray, button: MouseButton) -> void:
	match button:
		MOUSE_BUTTON_LEFT:
			_append_unique_candidate(candidates, "mouse:left")
		MOUSE_BUTTON_RIGHT:
			_append_unique_candidate(candidates, "mouse:right")
		MOUSE_BUTTON_MIDDLE:
			_append_unique_candidate(candidates, "mouse:middle")
		MOUSE_BUTTON_WHEEL_UP:
			_append_unique_candidate(candidates, "mouse:wheel_up")
		MOUSE_BUTTON_WHEEL_DOWN:
			_append_unique_candidate(candidates, "mouse:wheel_down")
	_append_unique_candidate(candidates, "mouse:%d" % int(button))


static func _append_joy_button_icon_candidates(candidates: PackedStringArray, button: JoyButton) -> void:
	match button:
		JOY_BUTTON_A:
			_append_unique_candidate(candidates, "joy_button:south")
		JOY_BUTTON_B:
			_append_unique_candidate(candidates, "joy_button:east")
		JOY_BUTTON_X:
			_append_unique_candidate(candidates, "joy_button:west")
		JOY_BUTTON_Y:
			_append_unique_candidate(candidates, "joy_button:north")
		JOY_BUTTON_LEFT_SHOULDER:
			_append_unique_candidate(candidates, "joy_button:left_shoulder")
		JOY_BUTTON_RIGHT_SHOULDER:
			_append_unique_candidate(candidates, "joy_button:right_shoulder")
		JOY_BUTTON_LEFT_STICK:
			_append_unique_candidate(candidates, "joy_button:left_stick")
		JOY_BUTTON_RIGHT_STICK:
			_append_unique_candidate(candidates, "joy_button:right_stick")
		JOY_BUTTON_BACK:
			_append_unique_candidate(candidates, "joy_button:back")
		JOY_BUTTON_START:
			_append_unique_candidate(candidates, "joy_button:start")
		JOY_BUTTON_DPAD_UP:
			_append_unique_candidate(candidates, "joy_button:dpad_up")
		JOY_BUTTON_DPAD_DOWN:
			_append_unique_candidate(candidates, "joy_button:dpad_down")
		JOY_BUTTON_DPAD_LEFT:
			_append_unique_candidate(candidates, "joy_button:dpad_left")
		JOY_BUTTON_DPAD_RIGHT:
			_append_unique_candidate(candidates, "joy_button:dpad_right")
	_append_unique_candidate(candidates, "joy_button:%d" % int(button))


static func _append_joy_axis_icon_candidates(candidates: PackedStringArray, event: InputEventJoypadMotion, options: Dictionary) -> void:
	var sign_override: int = clampi(GFVariantData.get_option_int(options, &"joy_axis_sign"), -1, 1)
	var sign_value: int = sign_override if sign_override != 0 else _get_axis_sign(event.axis_value)
	var suffix: String = "negative" if sign_value < 0 else "positive"
	match event.axis:
		JOY_AXIS_LEFT_X:
			_append_unique_candidate(candidates, "joy_axis:left_x_%s" % suffix)
		JOY_AXIS_LEFT_Y:
			_append_unique_candidate(candidates, "joy_axis:left_y_%s" % suffix)
		JOY_AXIS_RIGHT_X:
			_append_unique_candidate(candidates, "joy_axis:right_x_%s" % suffix)
		JOY_AXIS_RIGHT_Y:
			_append_unique_candidate(candidates, "joy_axis:right_y_%s" % suffix)
		JOY_AXIS_TRIGGER_LEFT:
			_append_unique_candidate(candidates, "joy_axis:left_trigger")
		JOY_AXIS_TRIGGER_RIGHT:
			_append_unique_candidate(candidates, "joy_axis:right_trigger")
	_append_unique_candidate(candidates, "joy_axis:%d:%s" % [int(event.axis), suffix])


static func _append_unique_candidate(target: PackedStringArray, value: String) -> void:
	if value.is_empty() or target.has(value):
		return
	var _append_result: bool = target.append(value)


static func _get_key_modifier_names(event: InputEventKey) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if event.ctrl_pressed:
		_append_unique_candidate(result, "ctrl")
	if event.alt_pressed:
		_append_unique_candidate(result, "alt")
	if event.shift_pressed:
		_append_unique_candidate(result, "shift")
	if event.meta_pressed:
		_append_unique_candidate(result, "meta")
	return result


static func _get_key_display_text(keycode: int) -> String:
	var key_text: String = OS.get_keycode_string(keycode)
	return key_text if not key_text.is_empty() else "key:%d" % keycode


static func _get_axis_sign(axis_value: float) -> int:
	if axis_value > 0.0:
		return 1
	if axis_value < 0.0:
		return -1
	return 0


static func _axis_sign_to_conflict_direction(sign_value: int) -> String:
	if sign_value > 0:
		return "+"
	if sign_value < 0:
		return "-"
	return "*"


static func _sanitize_icon_name(value: String) -> String:
	var result: String = value.strip_edges().to_lower()
	result = result.replace(" ", "_")
	result = result.replace("/", "_")
	result = result.replace("\\", "_")
	result = result.replace(".", "_")
	return result
