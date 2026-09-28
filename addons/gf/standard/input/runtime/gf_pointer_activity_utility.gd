## GFPointerActivityUtility: 通用指针活动状态工具。
##
## 由项目在 _input(event) 中显式转发事件，工具只维护按下、移动、拖拽和空闲状态，
## 不消费输入，也不绑定任何具体交互或业务对象。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFPointerActivityUtility
extends GFUtility


# --- 信号 ---

## 指针按下时发出。
## [br]
## @api public
## [br]
## @param pointer_id: 指针 ID；鼠标为 0，触摸为触点 index。
## [br]
## @param position: 指针位置。
## [br]
## @param event: 原始输入事件。
signal pointer_pressed(pointer_id: int, position: Vector2, event: InputEvent)

## 指针释放时发出。
## [br]
## @api public
## [br]
## @param pointer_id: 指针 ID；鼠标为 0，触摸为触点 index。
## [br]
## @param position: 指针位置。
## [br]
## @param event: 原始输入事件。
signal pointer_released(pointer_id: int, position: Vector2, event: InputEvent)

## 指针移动时发出。
## [br]
## @api public
## [br]
## @param pointer_id: 指针 ID；鼠标为 0，触摸为触点 index。
## [br]
## @param position: 指针位置。
## [br]
## @param previous_position: 上一次指针位置。
## [br]
## @param event: 原始输入事件。
signal pointer_moved(pointer_id: int, position: Vector2, previous_position: Vector2, event: InputEvent)

## 指针从按下状态进入拖拽时发出。
## [br]
## @api public
## [br]
## @param pointer_id: 指针 ID；鼠标为 0，触摸为触点 index。
## [br]
## @param start_position: 指针按下位置。
## [br]
## @param position: 当前指针位置。
## [br]
## @param event: 原始输入事件。
signal pointer_drag_started(pointer_id: int, start_position: Vector2, position: Vector2, event: InputEvent)

## 指针拖拽中发出。
## [br]
## @api public
## [br]
## @param pointer_id: 指针 ID；鼠标为 0，触摸为触点 index。
## [br]
## @param position: 当前指针位置。
## [br]
## @param delta: 本次拖拽位移。
## [br]
## @param event: 原始输入事件。
signal pointer_dragged(pointer_id: int, position: Vector2, delta: Vector2, event: InputEvent)

## 指针拖拽结束时发出。
## [br]
## @api public
## [br]
## @param pointer_id: 指针 ID；鼠标为 0，触摸为触点 index。
## [br]
## @param position: 指针释放位置。
## [br]
## @param event: 原始输入事件。
signal pointer_drag_ended(pointer_id: int, position: Vector2, event: InputEvent)

## 指针活动超过阈值后进入空闲时发出。
## [br]
## @api public
## [br]
## @param pointer_id: 指针 ID；鼠标为 0，触摸为触点 index。
## [br]
## @param position: 最近活动位置。
signal pointer_idle_started(pointer_id: int, position: Vector2)

## 指针从空闲恢复活动时发出。
## [br]
## @api public
## [br]
## @param pointer_id: 指针 ID；鼠标为 0，触摸为触点 index。
## [br]
## @param position: 恢复活动位置。
signal pointer_idle_ended(pointer_id: int, position: Vector2)


# --- 常量 ---

## 用于按具体事件类型提取鼠标和触摸输入。
## [br]
## @api private
## [br]
const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")


# --- 公共变量 ---

## 是否追踪鼠标事件。
## [br]
## @api public
var track_mouse: bool = true

## 是否追踪触摸事件。
## [br]
## @api public
var track_touch: bool = true

## 鼠标模式下作为主指针的按钮。
## [br]
## @api public
var mouse_button_index: MouseButton = MOUSE_BUTTON_LEFT

## 从按下位置移动超过该距离后进入拖拽状态。
## [br]
## @api public
var drag_threshold_pixels: float = 8.0

## 无活动超过该秒数后进入空闲状态。
## [br]
## @api public
var idle_threshold_seconds: float = 0.5

## 当前是否有指针按下。
## [br]
## @api public
var is_pointer_pressed: bool = false

## 当前是否处于拖拽状态。
## [br]
## @api public
var is_pointer_dragging: bool = false

## 最近一帧是否收到指针活动。
## [br]
## @api public
var is_pointer_moving: bool = false

## 当前是否处于空闲状态。
## [br]
## @api public
var is_pointer_idle: bool = true

## 当前活动指针 ID；鼠标为 0，触摸为 InputEventScreenTouch.index。
## [br]
## @api public
var active_pointer_id: int = -1

## 最近发生活动的指针 ID。
## [br]
## @api public
var last_pointer_id: int = -1

## 最近按下位置。
## [br]
## @api public
var press_position: Vector2 = Vector2.ZERO

## 最近指针位置。
## [br]
## @api public
var last_position: Vector2 = Vector2.ZERO


# --- 私有变量 ---

## 自最近一次指针活动以来累计的秒数。
## [br]
## @api private
## [br]
var _idle_elapsed_seconds: float = 0.0


# --- 公共方法 ---

## 处理一个输入事件。
## [br]
## @api public
## [br]
## @param event: 输入事件。
## [br]
## @return 识别为受追踪指针事件时返回 true。
func handle_input_event(event: InputEvent) -> bool:
	if event == null:
		return false
	var mouse_button: InputEventMouseButton = _INPUT_EVENT_TOOLS.get_mouse_button_event(event)
	if track_mouse and mouse_button != null:
		return _handle_mouse_button(mouse_button)
	var mouse_motion: InputEventMouseMotion = _INPUT_EVENT_TOOLS.get_mouse_motion_event(event)
	if track_mouse and mouse_motion != null:
		return _handle_mouse_motion(mouse_motion)
	var screen_touch: InputEventScreenTouch = _INPUT_EVENT_TOOLS.get_screen_touch_event(event)
	if track_touch and screen_touch != null:
		return _handle_screen_touch(screen_touch)
	var screen_drag: InputEventScreenDrag = _INPUT_EVENT_TOOLS.get_screen_drag_event(event)
	if track_touch and screen_drag != null:
		return _handle_screen_drag(screen_drag)
	return false


## 推进空闲计时。通常在 tick(delta) 或 _process(delta) 中调用。
## [br]
## @api public
## [br]
## @param delta: 秒。
func tick(delta: float) -> void:
	var safe_delta: float = maxf(delta, 0.0)
	if is_pointer_moving:
		is_pointer_moving = false
		_idle_elapsed_seconds = 0.0
		return

	_idle_elapsed_seconds += safe_delta
	if not is_pointer_idle and _idle_elapsed_seconds >= maxf(idle_threshold_seconds, 0.0):
		is_pointer_idle = true
		pointer_idle_started.emit(last_pointer_id, last_position)


## 清理所有指针活动状态。
## [br]
## @api public
func reset_activity() -> void:
	is_pointer_pressed = false
	is_pointer_dragging = false
	is_pointer_moving = false
	is_pointer_idle = true
	active_pointer_id = -1
	last_pointer_id = -1
	press_position = Vector2.ZERO
	last_position = Vector2.ZERO
	_idle_elapsed_seconds = 0.0


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 当前指针状态。
## [br]
## @schema return: Dictionary，包含 pointer id、pressed/dragging/moving/idle 标记、位置、idle 计时器和阈值配置。
func get_debug_snapshot() -> Dictionary:
	return {
		"active_pointer_id": active_pointer_id,
		"last_pointer_id": last_pointer_id,
		"is_pointer_pressed": is_pointer_pressed,
		"is_pointer_dragging": is_pointer_dragging,
		"is_pointer_moving": is_pointer_moving,
		"is_pointer_idle": is_pointer_idle,
		"press_position": press_position,
		"last_position": last_position,
		"idle_elapsed_seconds": _idle_elapsed_seconds,
		"drag_threshold_pixels": drag_threshold_pixels,
		"idle_threshold_seconds": idle_threshold_seconds,
	}


# --- 私有/辅助方法 ---

## 只处理配置的主鼠标按钮；按下或释放时更新指针状态并返回 true。
## [br]
## @api private
## [br]
func _handle_mouse_button(event: InputEventMouseButton) -> bool:
	if event.button_index != mouse_button_index:
		return false
	if event.pressed:
		_press_pointer(0, event.position, event)
	else:
		_release_pointer(0, event.position, event)
	return true


## 将鼠标移动事件转发为指针 ID 0 的移动。
## [br]
## @api private
## [br]
func _handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	_move_pointer(0, event.position, event)
	return true


## 只接受当前唯一活动触点的按下/释放；其他触点在活动指针冲突时返回 false。
## [br]
## @api private
## [br]
func _handle_screen_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		if active_pointer_id != -1 and active_pointer_id != event.index:
			return false
		_press_pointer(event.index, event.position, event)
	else:
		if active_pointer_id != event.index:
			return false
		_release_pointer(event.index, event.position, event)
	return true


## 活动指针未锁定或索引与当前活动触点一致时，将拖动事件转发为移动。
## [br]
## @api private
## [br]
func _handle_screen_drag(event: InputEventScreenDrag) -> bool:
	if active_pointer_id != -1 and active_pointer_id != event.index:
		return false
	_move_pointer(event.index, event.position, event)
	return true


## 初始化按下指针的状态与位置，标记活动并发出 pointer_pressed。
## [br]
## @api private
## [br]
func _press_pointer(pointer_id: int, position: Vector2, event: InputEvent) -> void:
	active_pointer_id = pointer_id
	is_pointer_pressed = true
	is_pointer_dragging = false
	press_position = position
	last_position = position
	_mark_pointer_activity(pointer_id, position)
	pointer_pressed.emit(pointer_id, position, event)


## 忽略与当前活动指针不一致的释放；匹配时先记录活动，必要时发出拖拽结束，再清状态并发出释放信号。
## [br]
## @api private
## [br]
func _release_pointer(pointer_id: int, position: Vector2, event: InputEvent) -> void:
	if active_pointer_id != -1 and active_pointer_id != pointer_id:
		return

	_mark_pointer_activity(pointer_id, position)
	last_position = position
	if is_pointer_dragging:
		pointer_drag_ended.emit(pointer_id, position, event)
	is_pointer_pressed = false
	is_pointer_dragging = false
	active_pointer_id = -1
	pointer_released.emit(pointer_id, position, event)


## 忽略与当前活动指针冲突的移动；更新位置并发出移动信号，按距离阈值进入拖拽并报告位移。
## [br]
## @api private
## [br]
func _move_pointer(pointer_id: int, position: Vector2, event: InputEvent) -> void:
	if active_pointer_id != -1 and active_pointer_id != pointer_id:
		return

	var previous_position: Vector2 = last_position
	last_position = position
	_mark_pointer_activity(pointer_id, position)
	pointer_moved.emit(pointer_id, position, previous_position, event)

	if not is_pointer_pressed:
		return

	var drag_distance: float = press_position.distance_to(position)
	if not is_pointer_dragging and drag_distance >= maxf(drag_threshold_pixels, 0.0):
		is_pointer_dragging = true
		pointer_drag_started.emit(pointer_id, press_position, position, event)
	if is_pointer_dragging:
		pointer_dragged.emit(pointer_id, position, position - previous_position, event)


## 记录最近活动指针及位置，重置空闲计时；从空闲转为活动时发出 pointer_idle_ended。
## [br]
## @api private
## [br]
func _mark_pointer_activity(pointer_id: int, position: Vector2) -> void:
	var was_idle: bool = is_pointer_idle
	last_pointer_id = pointer_id
	is_pointer_moving = true
	is_pointer_idle = false
	_idle_elapsed_seconds = 0.0
	if was_idle:
		pointer_idle_ended.emit(pointer_id, position)
