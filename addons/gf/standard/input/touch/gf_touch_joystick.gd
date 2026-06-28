@tool

## GFTouchJoystick: 通用触屏虚拟摇杆节点。
##
## 可直接发出摇杆向量信号，也可选择映射到 Godot InputMap 动作。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFTouchJoystick
extends Node2D


# --- 信号 ---

## 摇杆向量变化时发出。向量已应用死区并保留模拟强度。
## [br]
## @api public
## [br]
## @param direction: 已应用死区并保留模拟强度的摇杆向量。
signal direction_changed(direction: Vector2)

## 摇杆按下时发出。
## [br]
## @api public
signal joystick_pressed

## 摇杆释放时发出。
## [br]
## @api public
signal joystick_released


# --- 枚举 ---

## 摇杆定位模式。
## [br]
## @api public
enum PositionMode {
	## 摇杆中心保持在场景中摆放的位置。
	FIXED,
	## 初次触摸时摇杆中心移动到触点，释放后回到原位置。
	RELATIVE,
	## 初次触摸时摇杆中心移动到触点，拖动超过半径时中心跟随触点。
	FOLLOW,
}

## 摇杆输出模式。
## [br]
## @api public
## [br]
## @since 7.0.0
enum OutputMode {
	## 输出连续模拟向量。
	ANALOG,
	## 输出四方向离散向量。
	DPAD_4,
	## 输出八方向离散向量。
	DPAD_8,
}


# --- 常量 ---

const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")
const _DPAD_DIAGONAL_THRESHOLD: float = 0.38268343
const _WARNING_EMPTY_ACTIVE_REGION: String = "[GFTouchJoystick] use_active_region 已启用，但 active_region 为空；触摸起点和拖动将被拒绝。"


# --- 导出变量 ---

@export_group("Shape")
## 摇杆半径。
## [br]
## @api public
@export var radius: float = 64.0:
	set(value):
		radius = maxf(value, 1.0)
		queue_redraw()

## 摇杆手柄半径比例。
## [br]
## @api public
@export_range(2.0, 8.0, 0.1) var knob_radius_ratio: float = 3.0:
	set(value):
		knob_radius_ratio = maxf(value, 1.0)
		queue_redraw()

## 摇杆颜色。
## [br]
## @api public
@export var color: Color = Color(1.0, 1.0, 1.0, 0.35):
	set(value):
		color = value
		queue_redraw()

## 是否绘制相对摇杆交互范围。
## [br]
## @api public
@export var draw_interaction_zone: bool = false:
	set(value):
		draw_interaction_zone = value
		queue_redraw()

@export_group("Input")
## 输入死区，范围 0 到 1。
## [br]
## @api public
@export_range(0.0, 0.95, 0.01) var deadzone: float = 0.1

## 输出模式。ANALOG 保留模拟强度，DPAD_4 / DPAD_8 输出离散方向。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var output_mode: OutputMode = OutputMode.ANALOG

## 摇杆定位模式。
## [br]
## @api public
@export var position_mode: PositionMode = PositionMode.FIXED:
	set(value):
		position_mode = value
		queue_redraw()

## 相对模式下允许开始触控的交互半径。
## [br]
## @api public
@export var interaction_radius: float = 160.0:
	set(value):
		interaction_radius = maxf(value, radius)
		queue_redraw()

## 是否限制触摸起点必须位于 active_region 内。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var use_active_region: bool = false

## 允许开始触控的屏幕区域，使用 viewport 像素坐标。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var active_region: Rect2 = Rect2()

## 拖动离开 active_region 时是否自动释放。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var release_outside_active_region: bool = true

## 左方向动作名。为空则不映射。
## [br]
## @api public
@export var action_left: StringName = &""

## 右方向动作名。为空则不映射。
## [br]
## @api public
@export var action_right: StringName = &""

## 上方向动作名。为空则不映射。
## [br]
## @api public
@export var action_up: StringName = &""

## 下方向动作名。为空则不映射。
## [br]
## @api public
@export var action_down: StringName = &""

@export_group("Joypad Event")
## 是否额外发送虚拟手柄轴事件。
## [br]
## @api public
@export var emit_joypad_motion: bool = false

## 虚拟手柄设备 ID。建议使用负数以避开真实手柄。
## [br]
## @api public
@export var joypad_device_id: int = -2

## X 轴对应的手柄轴。
## [br]
## @api public
@export var joy_axis_x: JoyAxis = JOY_AXIS_LEFT_X

## Y 轴对应的手柄轴。
## [br]
## @api public
@export var joy_axis_y: JoyAxis = JOY_AXIS_LEFT_Y


# --- 私有变量 ---

var _active_touch_index: int = -1
var _knob_position: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.ZERO
var _rest_global_position: Vector2 = Vector2.ZERO
var _empty_active_region_warning_emitted: bool = false


# --- Godot 生命周期方法 ---

func _ready() -> void:
	_rest_global_position = global_position


func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return
	if what == CanvasItem.NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	release()


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


func _draw() -> void:
	if draw_interaction_zone and _uses_touch_origin():
		draw_circle(Vector2.ZERO, interaction_radius, Color(color, color.a * 0.35), false, 1.0, true)
	draw_circle(Vector2.ZERO, radius, color, false, 2.0, true)
	draw_circle(Vector2.ZERO, radius, Color(color, color.a * 0.35), true, -1.0, true)
	draw_circle(_knob_position, radius / knob_radius_ratio, color, true, -1.0, true)


# --- 公共方法 ---

## 获取当前摇杆向量。
## [br]
## @api public
## [br]
## @return 已应用死区并保留模拟强度的摇杆向量。
func get_direction() -> Vector2:
	return _direction


## 手动释放摇杆并清理动作状态。
## [br]
## @api public
func release() -> void:
	var was_active: bool = (
		_active_touch_index != -1
		or _direction != Vector2.ZERO
		or _knob_position != Vector2.ZERO
	)
	if not was_active:
		return
	_active_touch_index = -1
	_set_direction(Vector2.ZERO, Vector2.ZERO)
	if _uses_touch_origin():
		global_position = _rest_global_position
	joystick_released.emit()


# --- 私有/辅助方法 ---

func _handle_touch(event: InputEventScreenTouch) -> void:
	var global_pos: Vector2 = _screen_to_global_position(event.position)
	var local_pos: Vector2 = to_local(global_pos)
	if event.pressed:
		if _active_touch_index == -1 and _can_begin_at(local_pos, event.position):
			_begin_touch(event.index, global_pos, local_pos)
	elif event.index == _active_touch_index:
		release()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != _active_touch_index:
		return
	if release_outside_active_region and use_active_region and not _is_screen_position_in_active_region(event.position):
		release()
		return
	_update_from_local_position(to_local(_screen_to_global_position(event.position)))


func _begin_touch(touch_index: int, global_pos: Vector2, local_pos: Vector2) -> void:
	_active_touch_index = touch_index
	if _uses_touch_origin():
		_rest_global_position = global_position
		global_position = global_pos
		local_pos = Vector2.ZERO
	_knob_position = Vector2.ZERO
	joystick_pressed.emit()
	_update_from_local_position(local_pos)


func _can_begin_at(local_pos: Vector2, screen_position: Vector2 = Vector2.ZERO) -> bool:
	if use_active_region and not _is_screen_position_in_active_region(screen_position):
		return false
	if _uses_touch_origin():
		return local_pos.length() <= interaction_radius
	return local_pos.length() <= radius


func _update_from_local_position(local_pos: Vector2) -> void:
	local_pos = _apply_follow_origin(local_pos)
	var knob_pos: Vector2 = local_pos.limit_length(radius)
	var raw_direction: Vector2 = knob_pos / radius
	var next_direction: Vector2 = _calculate_output_direction(raw_direction)
	_set_direction(next_direction, knob_pos)


func _set_direction(next_direction: Vector2, knob_position: Vector2) -> void:
	if _direction == next_direction and _knob_position == knob_position:
		return
	_direction = next_direction
	_knob_position = knob_position
	_apply_input_actions(next_direction)
	direction_changed.emit(next_direction)
	queue_redraw()


func _apply_input_actions(direction: Vector2) -> void:
	_apply_axis_actions(direction.x, action_left, action_right)
	_apply_axis_actions(direction.y, action_up, action_down)
	_emit_joypad_motion(direction)


func _apply_axis_actions(value: float, negative_action: StringName, positive_action: StringName) -> void:
	if value < 0.0:
		_press_action(negative_action, absf(value))
		_release_action(positive_action)
	elif value > 0.0:
		_press_action(positive_action, absf(value))
		_release_action(negative_action)
	else:
		_release_action(negative_action)
		_release_action(positive_action)


func _press_action(action: StringName, strength: float) -> void:
	if action == &"":
		return
	Input.action_press(action, strength)


func _release_action(action: StringName) -> void:
	if action == &"":
		return
	Input.action_release(action)


func _emit_joypad_motion(direction: Vector2) -> void:
	if not emit_joypad_motion:
		return

	_emit_joypad_axis(joy_axis_x, direction.x)
	_emit_joypad_axis(joy_axis_y, direction.y)


func _emit_joypad_axis(axis: JoyAxis, value: float) -> void:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.device = joypad_device_id
	event.axis = axis
	event.axis_value = clampf(value, -1.0, 1.0)
	Input.parse_input_event(event)


func _apply_deadzone(raw_direction: Vector2) -> Vector2:
	var magnitude: float = raw_direction.length()
	var threshold: float = clampf(deadzone, 0.0, 0.99)
	if magnitude <= threshold:
		return Vector2.ZERO
	var remapped_magnitude: float = (magnitude - threshold) / (1.0 - threshold)
	return raw_direction.normalized() * clampf(remapped_magnitude, 0.0, 1.0)


func _calculate_output_direction(raw_direction: Vector2) -> Vector2:
	if output_mode == OutputMode.ANALOG:
		return _apply_deadzone(raw_direction)

	var magnitude: float = raw_direction.length()
	if magnitude <= clampf(deadzone, 0.0, 0.99):
		return Vector2.ZERO

	var direction: Vector2 = raw_direction / magnitude
	if output_mode == OutputMode.DPAD_4:
		if absf(direction.x) >= absf(direction.y):
			return Vector2(signf(direction.x), 0.0)
		return Vector2(0.0, signf(direction.y))

	var result: Vector2 = Vector2.ZERO
	if direction.x > _DPAD_DIAGONAL_THRESHOLD:
		result.x = 1.0
	elif direction.x < -_DPAD_DIAGONAL_THRESHOLD:
		result.x = -1.0
	if direction.y > _DPAD_DIAGONAL_THRESHOLD:
		result.y = 1.0
	elif direction.y < -_DPAD_DIAGONAL_THRESHOLD:
		result.y = -1.0
	if result == Vector2.ZERO:
		if absf(direction.x) >= absf(direction.y):
			result.x = signf(direction.x)
		else:
			result.y = signf(direction.y)
	return result


func _apply_follow_origin(local_pos: Vector2) -> Vector2:
	if position_mode != PositionMode.FOLLOW or local_pos.length() <= radius:
		return local_pos
	var knob_pos: Vector2 = local_pos.limit_length(radius)
	var global_delta: Vector2 = to_global(local_pos) - to_global(knob_pos)
	global_position += global_delta
	return knob_pos


func _uses_touch_origin() -> bool:
	return position_mode == PositionMode.RELATIVE or position_mode == PositionMode.FOLLOW


func _screen_to_global_position(screen_position: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return screen_position
	return viewport.get_canvas_transform().affine_inverse() * screen_position


func _is_screen_position_in_active_region(screen_position: Vector2) -> bool:
	var normalized_region: Rect2 = active_region.abs()
	if normalized_region.size.x <= 0.0 or normalized_region.size.y <= 0.0:
		if not _empty_active_region_warning_emitted:
			push_warning(_WARNING_EMPTY_ACTIVE_REGION)
			_empty_active_region_warning_emitted = true
		return false
	_empty_active_region_warning_emitted = false
	return normalized_region.has_point(screen_position)
