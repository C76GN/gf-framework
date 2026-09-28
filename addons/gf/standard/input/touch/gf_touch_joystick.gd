@tool

## GFTouchJoystick: 通用触屏虚拟摇杆节点。
##
## 可直接发出摇杆向量信号，也可选择映射到 Godot InputMap 动作。
## 每次 gesture 会冻结 begin-time 定位模式、action 与虚拟 joypad lane；
## 运行时配置修改从下一次 gesture 生效。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFTouchJoystick
extends GFTouchControl2D


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

## 输入事件提取辅助脚本。
## [br]
## @api private
## [br]
const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")

## 虚拟输入动作和手柄轴桥接脚本。
## [br]
## @api private
## [br]
const _VIRTUAL_INPUT_BRIDGE = preload("res://addons/gf/standard/input/common/gf_virtual_input_bridge.gd")

## active_region 为空时拒绝触控起点的稳定警告文本。
## [br]
## @api private
## [br]
const _WARNING_EMPTY_ACTIVE_REGION: String = "[GFTouchJoystick][touch_joystick.active_region_missing] use_active_region is enabled but active_region is empty; touch starts and dragging will be rejected."


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

## 当前摇杆手柄相对控件中心的局部偏移。
## [br]
## @api private
## [br]
var _knob_position: Vector2 = Vector2.ZERO

## 当前对外输出的摇杆向量。
## [br]
## @api private
## [br]
var _direction: Vector2 = Vector2.ZERO

## 相对/跟随模式开始手势前控件的全局位置，释放后用于恢复。
## [br]
## @api private
## [br]
var _rest_global_position: Vector2 = Vector2.ZERO

## 是否已为当前空 active_region 发出缺失警告。
## [br]
## @api private
## [br]
var _empty_active_region_warning_emitted: bool = false

## 当前手势是否已冻结开始时的定位及输出配置。
## [br]
## @api private
## [br]
var _gesture_binding_active: bool = false

## 手势代际；开始与释放时递增，用于识别信号重入导致的过期流程。
## [br]
## @api private
## [br]
var _gesture_generation: int = 0

## 当前是否正在执行 release，防止重入释放。
## [br]
## @api private
## [br]
var _release_in_progress: bool = false

## 当前手势开始时冻结的定位模式。
## [br]
## @api private
## [br]
var _active_position_mode: PositionMode = PositionMode.FIXED

## 当前手势开始时冻结的左方向动作名。
## [br]
## @api private
## [br]
var _active_action_left: StringName = &""

## 当前手势开始时冻结的右方向动作名。
## [br]
## @api private
## [br]
var _active_action_right: StringName = &""

## 当前手势开始时冻结的上方向动作名。
## [br]
## @api private
## [br]
var _active_action_up: StringName = &""

## 当前手势开始时冻结的下方向动作名。
## [br]
## @api private
## [br]
var _active_action_down: StringName = &""

## 当前手势开始时冻结的手柄轴事件开关。
## [br]
## @api private
## [br]
var _active_emit_joypad_motion: bool = false

## 当前手势开始时冻结的虚拟手柄设备 ID。
## [br]
## @api private
## [br]
var _active_joypad_device_id: int = -2

## 当前手势开始时冻结的 X 轴映射。
## [br]
## @api private
## [br]
var _active_joy_axis_x: JoyAxis = JOY_AXIS_LEFT_X

## 当前手势开始时冻结的 Y 轴映射。
## [br]
## @api private
## [br]
var _active_joy_axis_y: JoyAxis = JOY_AXIS_LEFT_Y


# --- Godot 生命周期方法 ---

func _ready() -> void:
	_rest_global_position = global_position


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
	if _release_in_progress:
		return
	var was_active: bool = (
		is_touch_active()
		or _direction != Vector2.ZERO
		or _knob_position != Vector2.ZERO
	)
	if not was_active:
		return
	_release_in_progress = true
	_gesture_generation += 1
	var _released_touch: bool = _release_touch_capture()
	_set_direction(Vector2.ZERO, Vector2.ZERO)
	if _gesture_binding_active and _position_mode_uses_touch_origin(_active_position_mode):
		global_position = _rest_global_position
	_clear_gesture_binding()
	_release_in_progress = false
	joystick_released.emit()


# --- 私有/辅助方法 ---

## 把触屏事件换算为画布与局部坐标；按下命中时开始手势，匹配触点抬起时释放。
## [br]
## @api private
## [br]
func _handle_touch(event: InputEventScreenTouch) -> void:
	var global_pos: Vector2 = _screen_to_global_position(event.position)
	var local_pos: Vector2 = to_local(global_pos)
	if event.pressed:
		if not is_touch_active() and _can_begin_at(local_pos, event.position):
			_begin_touch(event.index, global_pos, local_pos)
			_mark_input_as_handled()
	elif _touch_matches(event.index):
		release()
		_mark_input_as_handled()


## 只处理当前捕获触点；越出配置的 active_region 时释放，否则按拖动位置更新方向。
## [br]
## @api private
## [br]
func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _touch_matches(event.index):
		return
	if release_outside_active_region and use_active_region and not _is_screen_position_in_active_region(event.position):
		release()
		_mark_input_as_handled()
		return
	_update_from_local_position(to_local(_screen_to_global_position(event.position)))
	_mark_input_as_handled()


## 捕获触点并冻结手势配置；相对/跟随模式把控件中心移到起点，发出按下信号后检查重入并初始化方向。
## [br]
## @api private
## [br]
func _begin_touch(touch_index: int, global_pos: Vector2, local_pos: Vector2) -> void:
	if _release_in_progress or not _try_capture_touch_index(touch_index):
		return
	_gesture_generation += 1
	var generation: int = _gesture_generation
	_capture_gesture_binding()
	if _position_mode_uses_touch_origin(_active_position_mode):
		_rest_global_position = global_position
		global_position = global_pos
		local_pos = Vector2.ZERO
	_knob_position = Vector2.ZERO
	joystick_pressed.emit()
	if generation != _gesture_generation or not _touch_matches(touch_index):
		return
	_update_from_local_position(local_pos)


## 检查可选屏幕 active_region 以及定位模式对应的起点半径。
## [br]
## @api private
## [br]
func _can_begin_at(local_pos: Vector2, screen_position: Vector2 = Vector2.ZERO) -> bool:
	if use_active_region and not _is_screen_position_in_active_region(screen_position):
		return false
	if _uses_touch_origin():
		return local_pos.length() <= interaction_radius
	return local_pos.length() <= radius


## 按手势定位模式调整中心，限制手柄位移到半径内，计算原始与最终输出方向并更新状态。
## [br]
## @api private
## [br]
func _update_from_local_position(local_pos: Vector2) -> void:
	local_pos = _apply_follow_origin(local_pos)
	var knob_pos: Vector2 = local_pos.limit_length(radius)
	var raw_direction: Vector2 = knob_pos / radius
	var next_direction: Vector2 = _calculate_output_direction(raw_direction)
	_set_direction(next_direction, knob_pos)


## 仅在方向或手柄位置变化时更新状态；方向变化时先应用动作再发出向量信号，最后重绘。
## [br]
## @api private
## [br]
func _set_direction(next_direction: Vector2, knob_position: Vector2) -> void:
	var direction_changed_value: bool = _direction != next_direction
	var knob_changed: bool = _knob_position != knob_position
	if not direction_changed_value and not knob_changed:
		return
	_direction = next_direction
	_knob_position = knob_position
	if direction_changed_value:
		_apply_input_actions(next_direction)
		direction_changed.emit(next_direction)
	queue_redraw()


## 选取手势冻结或当前配置的四个方向动作，按两个轴更新动作贡献并发送手柄轴事件。
## [br]
## @api private
## [br]
func _apply_input_actions(direction: Vector2) -> void:
	var left_action: StringName = _active_action_left if _gesture_binding_active else action_left
	var right_action: StringName = _active_action_right if _gesture_binding_active else action_right
	var up_action: StringName = _active_action_up if _gesture_binding_active else action_up
	var down_action: StringName = _active_action_down if _gesture_binding_active else action_down
	_apply_axis_actions(direction.x, left_action, right_action)
	_apply_axis_actions(direction.y, up_action, down_action)
	_emit_joypad_motion(direction)


## 根据轴值的符号按下对应方向、释放相反方向；值为零时释放两侧动作。
## [br]
## @api private
## [br]
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


## 忽略空动作名，否则通过虚拟输入桥接按下动作并传递模拟强度。
## [br]
## @api private
## [br]
func _press_action(action: StringName, strength: float) -> void:
	if action == &"":
		return
	var _pressed_action: bool = _VIRTUAL_INPUT_BRIDGE.press_action(action, self, action, strength)


## 忽略空动作名，否则通过虚拟输入桥接释放本控件对动作的贡献。
## [br]
## @api private
## [br]
func _release_action(action: StringName) -> void:
	if action == &"":
		return
	var _released_action: bool = _VIRTUAL_INPUT_BRIDGE.release_action(action, self, action)


## 按当前手势冻结或实时配置决定是否发送手柄轴事件，并分别选择轴映射。
## [br]
## @api private
## [br]
func _emit_joypad_motion(direction: Vector2) -> void:
	var should_emit: bool = (
		_active_emit_joypad_motion
		if _gesture_binding_active
		else emit_joypad_motion
	)
	if not should_emit:
		return

	var axis_x: JoyAxis = _active_joy_axis_x if _gesture_binding_active else joy_axis_x
	var axis_y: JoyAxis = _active_joy_axis_y if _gesture_binding_active else joy_axis_y
	_emit_joypad_axis(axis_x, direction.x)
	_emit_joypad_axis(axis_y, direction.y)


## 用当前手势冻结或实时配置的设备 ID 发出指定手柄轴值。
## [br]
## @api private
## [br]
func _emit_joypad_axis(axis: JoyAxis, value: float) -> void:
	var device_id: int = _active_joypad_device_id if _gesture_binding_active else joypad_device_id
	_VIRTUAL_INPUT_BRIDGE.emit_joypad_axis(device_id, axis, value)


## 对原始向量应用径向死区。
## [br]
## @api private
## [br]
func _apply_deadzone(raw_direction: Vector2) -> Vector2:
	return GFInputDirectionTools.apply_radial_deadzone(raw_direction, deadzone)


## 按 ANALOG、DPAD_4 或 DPAD_8 模式计算输出方向；模拟模式使用径向死区，数字模式执行方向吸附。
## [br]
## @api private
## [br]
func _calculate_output_direction(raw_direction: Vector2) -> Vector2:
	if output_mode == OutputMode.ANALOG:
		return _apply_deadzone(raw_direction)
	if output_mode == OutputMode.DPAD_4:
		return GFInputDirectionTools.snap_vector(
			raw_direction,
			GFInputDirectionTools.SnapMode.CARDINAL_4,
			deadzone
		)
	return GFInputDirectionTools.snap_vector(
		raw_direction,
		GFInputDirectionTools.SnapMode.EIGHT_WAY,
		deadzone
	)


## 仅在 FOLLOW 模式且指针超出摇杆半径时移动控件中心追随指针，并返回半径内的手柄偏移。
## [br]
## @api private
## [br]
func _apply_follow_origin(local_pos: Vector2) -> Vector2:
	var effective_position_mode: PositionMode = (
		_active_position_mode
		if _gesture_binding_active
		else position_mode
	)
	if effective_position_mode != PositionMode.FOLLOW or local_pos.length() <= radius:
		return local_pos
	var knob_pos: Vector2 = local_pos.limit_length(radius)
	var global_delta: Vector2 = to_global(local_pos) - to_global(knob_pos)
	global_position += global_delta
	return knob_pos


## 读取冻结或当前定位模式，判断是否以触点作为手势中心。
## [br]
## @api private
## [br]
func _uses_touch_origin() -> bool:
	var effective_position_mode: PositionMode = (
		_active_position_mode
		if _gesture_binding_active
		else position_mode
	)
	return _position_mode_uses_touch_origin(effective_position_mode)


## RELATIVE 和 FOLLOW 模式使用触点作为手势中心。
## [br]
## @api private
## [br]
func _position_mode_uses_touch_origin(mode: PositionMode) -> bool:
	return mode == PositionMode.RELATIVE or mode == PositionMode.FOLLOW


## 在手势开始时冻结定位模式、方向动作和手柄轴输出设置。
## [br]
## @api private
## [br]
func _capture_gesture_binding() -> void:
	_gesture_binding_active = true
	_active_position_mode = position_mode
	_active_action_left = action_left
	_active_action_right = action_right
	_active_action_up = action_up
	_active_action_down = action_down
	_active_emit_joypad_motion = emit_joypad_motion
	_active_joypad_device_id = joypad_device_id
	_active_joy_axis_x = joy_axis_x
	_active_joy_axis_y = joy_axis_y


## 结束冻结并把手势设置恢复为默认值。
## [br]
## @api private
## [br]
func _clear_gesture_binding() -> void:
	_gesture_binding_active = false
	_active_position_mode = PositionMode.FIXED
	_active_action_left = &""
	_active_action_right = &""
	_active_action_up = &""
	_active_action_down = &""
	_active_emit_joypad_motion = false
	_active_joypad_device_id = -2
	_active_joy_axis_x = JOY_AXIS_LEFT_X
	_active_joy_axis_y = JOY_AXIS_LEFT_Y


## 将 active_region 规范化为非负尺寸；空区域只警告一次并拒绝，非空区域按屏幕坐标判断包含关系。
## [br]
## @api private
## [br]
func _is_screen_position_in_active_region(screen_position: Vector2) -> bool:
	var normalized_region: Rect2 = active_region.abs()
	if normalized_region.size.x <= 0.0 or normalized_region.size.y <= 0.0:
		if not _empty_active_region_warning_emitted:
			push_warning(_WARNING_EMPTY_ACTIVE_REGION)
			_empty_active_region_warning_emitted = true
		return false
	_empty_active_region_warning_emitted = false
	return normalized_region.has_point(screen_position)
