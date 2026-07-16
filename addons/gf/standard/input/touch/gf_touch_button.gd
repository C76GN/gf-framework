@tool

## GFTouchButton: 通用触屏虚拟按钮节点。
##
## 可直接发送按下/释放信号，也可映射到 Godot InputMap 动作或虚拟手柄按钮事件。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFTouchButton
extends GFTouchControl2D


# --- 信号 ---

## 按钮按下时发出。
## [br]
## @api public
signal button_pressed

## 按钮释放时发出。
## [br]
## @api public
signal button_released


# --- 常量 ---

const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")
const _VIRTUAL_INPUT_BRIDGE = preload("res://addons/gf/standard/input/common/gf_virtual_input_bridge.gd")


# --- 导出变量 ---

@export_group("Shape")
## 按钮半径。
## [br]
## @api public
@export var radius: float = 48.0:
	set(value):
		radius = maxf(value, 1.0)
		queue_redraw()

## 按钮常态颜色。
## [br]
## @api public
@export var color: Color = Color(1.0, 1.0, 1.0, 0.3):
	set(value):
		color = value
		queue_redraw()

## 按钮按下颜色。
## [br]
## @api public
@export var pressed_color: Color = Color(1.0, 1.0, 1.0, 0.65):
	set(value):
		pressed_color = value
		queue_redraw()

@export_group("Input")
## 是否允许鼠标左键模拟触屏。默认关闭，避免触屏控件在桌面端隐式接管鼠标输入。
## [br]
## @api public
@export var accept_mouse_input: bool = false

## 映射到 Godot InputMap 的动作名。为空则不映射。
## [br]
## @api public
@export var action_name: StringName = &""

@export_group("Joypad Event")
## 是否额外发送虚拟手柄按钮事件。
## [br]
## @api public
@export var emit_joypad_button: bool = false

## 虚拟手柄设备 ID。建议使用负数以避开真实手柄。
## [br]
## @api public
@export var joypad_device_id: int = -2

## 对应的手柄按钮。
## [br]
## @api public
@export var joy_button: JoyButton = JOY_BUTTON_A


# --- 私有变量 ---

var _mouse_pressed_inside: bool = false
var _pressed: bool = false


# --- Godot 生命周期方法 ---

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not is_visible_in_tree():
		release()
		return

	var screen_touch: InputEventScreenTouch = _INPUT_EVENT_TOOLS.get_screen_touch_event(event)
	if screen_touch != null:
		_handle_touch(screen_touch)
		return

	var screen_drag: InputEventScreenDrag = _INPUT_EVENT_TOOLS.get_screen_drag_event(event)
	if screen_drag != null:
		_handle_drag(screen_drag)
		return

	var mouse_button: InputEventMouseButton = _INPUT_EVENT_TOOLS.get_mouse_button_event(event)
	if accept_mouse_input and mouse_button != null:
		_handle_mouse_button(mouse_button)
		return

	var mouse_motion: InputEventMouseMotion = _INPUT_EVENT_TOOLS.get_mouse_motion_event(event)
	if accept_mouse_input and mouse_motion != null:
		_handle_mouse_motion(mouse_motion)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, pressed_color if _pressed else color, true, -1.0, true)
	draw_circle(Vector2.ZERO, radius, Color(color, minf(color.a + 0.25, 1.0)), false, 2.0, true)


# --- 公共方法 ---

## 检查按钮是否处于按下状态。
## [br]
## @api public
## [br]
## @return 是否按下。
func is_pressed() -> bool:
	return _pressed


## 手动释放按钮。
## [br]
## @api public
func release() -> void:
	var _released_touch: bool = _release_touch_capture()
	_mouse_pressed_inside = false
	_set_pressed(false)


# --- 私有/辅助方法 ---

func _handle_touch(event: InputEventScreenTouch) -> void:
	var local_pos: Vector2 = to_local(_screen_to_global_position(event.position))
	if event.pressed:
		if not is_touch_active() and local_pos.length() <= radius:
			var _captured: bool = _try_capture_touch_index(event.index)
			_set_pressed(true)
			_mark_input_as_handled()
	elif _touch_matches(event.index):
		release()
		_mark_input_as_handled()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touch_matches(event.index):
		return

	var local_pos: Vector2 = to_local(_screen_to_global_position(event.position))
	if local_pos.length() > radius:
		release()
	_mark_input_as_handled()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var local_pos: Vector2 = to_local(_screen_to_global_position(event.position))
	if event.pressed:
		_mouse_pressed_inside = local_pos.length() <= radius
		if _mouse_pressed_inside:
			_set_pressed(true)
			_mark_input_as_handled()
	else:
		if _mouse_pressed_inside:
			release()
			_mark_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _mouse_pressed_inside:
		return

	var local_pos: Vector2 = to_local(_screen_to_global_position(event.position))
	if local_pos.length() > radius:
		release()
	_mark_input_as_handled()


func _set_pressed(next_pressed: bool) -> void:
	if _pressed == next_pressed:
		return

	_pressed = next_pressed
	_apply_input_action(next_pressed)
	_emit_joypad_button(next_pressed)
	if next_pressed:
		button_pressed.emit()
	else:
		button_released.emit()
	queue_redraw()


func _apply_input_action(pressed: bool) -> void:
	if action_name == &"":
		return
	if pressed:
		var _pressed_action: bool = _VIRTUAL_INPUT_BRIDGE.press_action(action_name, self, action_name)
	else:
		var _released_action: bool = _VIRTUAL_INPUT_BRIDGE.release_action(action_name, self, action_name)


func _emit_joypad_button(pressed: bool) -> void:
	if not emit_joypad_button:
		return

	_VIRTUAL_INPUT_BRIDGE.emit_joypad_button(joypad_device_id, joy_button, pressed)
