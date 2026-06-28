## GFPointerGestureUtility: 通用指针手势摘要工具。
##
## 把鼠标、触摸和系统手势事件归一为平移、缩放和旋转摘要。
## 工具只输出数据，不控制 Camera、Control、Node2D 或项目业务对象。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFPointerGestureUtility
extends GFUtility


# --- 信号 ---

## 手势摘要更新时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param snapshot: 手势摘要字典。
## [br]
## @param event: 原始输入事件。
## [br]
## @schema snapshot: Dictionary with active, source, pointer_count, pointer_ids, center, previous_center, pan_delta, scale, rotation_delta, distance, previous_distance, and primary_pointer_id.
signal gesture_updated(snapshot: Dictionary, event: InputEvent)

## 最后一个活动指针释放或 reset_gesture() 清理活动手势时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param snapshot: 结束后的手势摘要。
## [br]
## @schema snapshot: Dictionary with active=false and the last known center fields.
signal gesture_ended(snapshot: Dictionary)


# --- 常量 ---

const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")
const _MOUSE_POINTER_ID: int = 0
const _DEFAULT_MINIMUM_PINCH_DISTANCE: float = 0.001


# --- 公共变量 ---

## 是否追踪鼠标拖拽事件。
## [br]
## @api public
## [br]
## @since 7.0.0
var track_mouse: bool = true

## 是否把鼠标滚轮归一为缩放手势。
## [br]
## @api public
## [br]
## @since 7.0.0
var track_mouse_wheel: bool = true

## 是否追踪触摸事件。
## [br]
## @api public
## [br]
## @since 7.0.0
var track_touch: bool = true

## 是否追踪 Godot 提供的 pan / magnify 系统手势事件。
## [br]
## @api public
## [br]
## @since 7.0.0
var track_gesture_events: bool = true

## 鼠标模式下作为拖拽指针的按钮。
## [br]
## @api public
## [br]
## @since 7.0.0
var mouse_button_index: MouseButton = MOUSE_BUTTON_LEFT

## 鼠标滚轮单步缩放因子。向下滚动会使用该值的倒数。
## [br]
## @api public
## [br]
## @since 7.0.0
var mouse_wheel_zoom_factor: float = 1.1

## 双指距离低于该阈值时不产生缩放因子。
## [br]
## @api public
## [br]
## @since 7.0.0
var minimum_pinch_distance: float = _DEFAULT_MINIMUM_PINCH_DISTANCE


# --- 私有变量 ---

var _active_pointers: Dictionary = {}
var _last_snapshot: Dictionary = _make_empty_snapshot(&"none")


# --- 公共方法 ---

## 处理一个输入事件。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param event: 输入事件。
## [br]
## @return 识别为受追踪手势事件时返回 true。
func handle_input_event(event: InputEvent) -> bool:
	if event == null:
		return false

	var magnify_gesture: InputEventMagnifyGesture = _INPUT_EVENT_TOOLS.get_magnify_gesture_event(event)
	if track_gesture_events and magnify_gesture != null:
		return _handle_magnify_gesture(magnify_gesture)

	var pan_gesture: InputEventPanGesture = _INPUT_EVENT_TOOLS.get_pan_gesture_event(event)
	if track_gesture_events and pan_gesture != null:
		return _handle_pan_gesture(pan_gesture)

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


## 清理当前手势状态。
## [br]
## @api public
## [br]
## @since 7.0.0
func reset_gesture() -> void:
	var had_active_gesture: bool = not _active_pointers.is_empty()
	_active_pointers.clear()
	_last_snapshot = _make_empty_snapshot(&"reset")
	if had_active_gesture:
		gesture_ended.emit(_last_snapshot.duplicate(true))


## 获取活动指针数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前活动指针数量。
func get_active_pointer_count() -> int:
	return _active_pointers.size()


## 获取最近一次手势摘要。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 手势摘要副本。
## [br]
## @schema return: Dictionary with active, source, pointer_count, pointer_ids, center, previous_center, pan_delta, scale, rotation_delta, distance, previous_distance, and primary_pointer_id.
func get_gesture_snapshot() -> Dictionary:
	return _last_snapshot.duplicate(true)


## 根据上一组和当前组指针位置计算手势摘要。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param previous_points: 上一组指针位置，键为 pointer id，值为 Vector2。
## [br]
## @param current_points: 当前指针位置，键为 pointer id，值为 Vector2。
## [br]
## @param source: 摘要来源标识。
## [br]
## @param minimum_distance: 缩放计算的最小安全距离。
## [br]
## @return 手势摘要字典。
## [br]
## @schema previous_points: Dictionary[int, Vector2] previous pointer positions.
## [br]
## @schema current_points: Dictionary[int, Vector2] current pointer positions.
## [br]
## @schema return: Dictionary with active, source, pointer_count, pointer_ids, center, previous_center, pan_delta, scale, rotation_delta, distance, previous_distance, and primary_pointer_id.
static func calculate_gesture(
	previous_points: Dictionary,
	current_points: Dictionary,
	source: StringName = &"pointer",
	minimum_distance: float = _DEFAULT_MINIMUM_PINCH_DISTANCE
) -> Dictionary:
	var pointer_ids: Array[int] = _get_sorted_pointer_ids(current_points)
	if pointer_ids.is_empty():
		return _make_empty_snapshot(source)

	var aligned_previous_points: Dictionary = _align_previous_points(previous_points, current_points, pointer_ids)
	var center: Vector2 = _average_points(current_points, pointer_ids)
	var previous_center: Vector2 = _average_points(aligned_previous_points, pointer_ids)
	var distance: float = 0.0
	var previous_distance: float = 0.0
	var scale: float = 1.0
	var rotation_delta: float = 0.0
	if pointer_ids.size() >= 2:
		var first_pointer_id: int = pointer_ids[0]
		var second_pointer_id: int = pointer_ids[1]
		var first_point: Vector2 = _read_point(current_points, first_pointer_id)
		var second_point: Vector2 = _read_point(current_points, second_pointer_id)
		var previous_first_point: Vector2 = _read_point(aligned_previous_points, first_pointer_id)
		var previous_second_point: Vector2 = _read_point(aligned_previous_points, second_pointer_id)
		var current_vector: Vector2 = second_point - first_point
		var previous_vector: Vector2 = previous_second_point - previous_first_point
		distance = current_vector.length()
		previous_distance = previous_vector.length()
		var safe_minimum_distance: float = maxf(minimum_distance, _DEFAULT_MINIMUM_PINCH_DISTANCE)
		if previous_distance >= safe_minimum_distance and distance >= safe_minimum_distance:
			scale = distance / previous_distance
			rotation_delta = wrapf(current_vector.angle() - previous_vector.angle(), -PI, PI)

	return {
		"active": true,
		"source": source,
		"pointer_count": pointer_ids.size(),
		"pointer_ids": pointer_ids,
		"center": center,
		"previous_center": previous_center,
		"pan_delta": center - previous_center,
		"scale": scale,
		"rotation_delta": rotation_delta,
		"distance": distance,
		"previous_distance": previous_distance,
		"primary_pointer_id": pointer_ids[0],
	}


# --- 私有/辅助方法 ---

func _handle_mouse_button(event: InputEventMouseButton) -> bool:
	if track_mouse_wheel and _is_mouse_wheel_button(event.button_index):
		return _handle_mouse_wheel(event)
	if event.button_index != mouse_button_index:
		return false
	if event.pressed:
		_start_pointer(_MOUSE_POINTER_ID, event.position, event, &"mouse_press")
	else:
		_release_pointer(_MOUSE_POINTER_ID, event.position, event, &"mouse_release")
	return true


func _handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	if not _active_pointers.has(_MOUSE_POINTER_ID):
		return false
	_move_pointer(_MOUSE_POINTER_ID, event.position, event, &"mouse_motion")
	return true


func _handle_screen_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		_start_pointer(event.index, event.position, event, &"touch_press")
	else:
		_release_pointer(event.index, event.position, event, &"touch_release")
	return true


func _handle_screen_drag(event: InputEventScreenDrag) -> bool:
	if not _active_pointers.has(event.index):
		return false
	_move_pointer(event.index, event.position, event, &"touch_drag")
	return true


func _handle_mouse_wheel(event: InputEventMouseButton) -> bool:
	if not event.pressed:
		return false
	var safe_factor: float = maxf(mouse_wheel_zoom_factor, _DEFAULT_MINIMUM_PINCH_DISTANCE)
	var scale: float = safe_factor
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scale = 1.0 / safe_factor
	var snapshot: Dictionary = _make_external_gesture_snapshot(&"mouse_wheel", event.position, Vector2.ZERO, scale)
	_store_and_emit_snapshot(snapshot, event)
	return true


func _handle_magnify_gesture(event: InputEventMagnifyGesture) -> bool:
	var safe_factor: float = maxf(event.factor, _DEFAULT_MINIMUM_PINCH_DISTANCE)
	var snapshot: Dictionary = _make_external_gesture_snapshot(&"magnify_gesture", event.position, Vector2.ZERO, safe_factor)
	_store_and_emit_snapshot(snapshot, event)
	return true


func _handle_pan_gesture(event: InputEventPanGesture) -> bool:
	var snapshot: Dictionary = _make_external_gesture_snapshot(&"pan_gesture", event.position, event.delta, 1.0)
	_store_and_emit_snapshot(snapshot, event)
	return true


func _start_pointer(pointer_id: int, position: Vector2, event: InputEvent, source: StringName) -> void:
	var previous_points: Dictionary = _copy_points(_active_pointers)
	_active_pointers[pointer_id] = position
	_update_pointer_snapshot(previous_points, event, source)


func _move_pointer(pointer_id: int, position: Vector2, event: InputEvent, source: StringName) -> void:
	var previous_points: Dictionary = _copy_points(_active_pointers)
	_active_pointers[pointer_id] = position
	_update_pointer_snapshot(previous_points, event, source)


func _release_pointer(pointer_id: int, position: Vector2, event: InputEvent, source: StringName) -> void:
	if not _active_pointers.has(pointer_id):
		return
	var previous_points: Dictionary = _copy_points(_active_pointers)
	_active_pointers[pointer_id] = position
	var _erased_pointer: bool = _active_pointers.erase(pointer_id)
	if _active_pointers.is_empty():
		_last_snapshot = _make_inactive_snapshot(source, position)
		gesture_ended.emit(_last_snapshot.duplicate(true))
		return
	_update_pointer_snapshot(previous_points, event, source)


func _update_pointer_snapshot(previous_points: Dictionary, event: InputEvent, source: StringName) -> void:
	var snapshot: Dictionary = calculate_gesture(previous_points, _active_pointers, source, minimum_pinch_distance)
	_store_and_emit_snapshot(snapshot, event)


func _store_and_emit_snapshot(snapshot: Dictionary, event: InputEvent) -> void:
	_last_snapshot = snapshot.duplicate(true)
	gesture_updated.emit(_last_snapshot.duplicate(true), event)


func _make_external_gesture_snapshot(
	source: StringName,
	center: Vector2,
	pan_delta: Vector2,
	scale: float
) -> Dictionary:
	return {
		"active": true,
		"source": source,
		"pointer_count": 0,
		"pointer_ids": [],
		"center": center,
		"previous_center": center - pan_delta,
		"pan_delta": pan_delta,
		"scale": scale,
		"rotation_delta": 0.0,
		"distance": 0.0,
		"previous_distance": 0.0,
		"primary_pointer_id": -1,
	}


static func _make_empty_snapshot(source: StringName) -> Dictionary:
	return _make_inactive_snapshot(source, Vector2.ZERO)


static func _make_inactive_snapshot(source: StringName, center: Vector2) -> Dictionary:
	return {
		"active": false,
		"source": source,
		"pointer_count": 0,
		"pointer_ids": [],
		"center": center,
		"previous_center": center,
		"pan_delta": Vector2.ZERO,
		"scale": 1.0,
		"rotation_delta": 0.0,
		"distance": 0.0,
		"previous_distance": 0.0,
		"primary_pointer_id": -1,
	}


static func _copy_points(points: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for pointer_key: Variant in points.keys():
		if not (pointer_key is int):
			continue
		var pointer_id: int = pointer_key
		result[pointer_id] = _read_point(points, pointer_id)
	return result


static func _align_previous_points(
	previous_points: Dictionary,
	current_points: Dictionary,
	pointer_ids: Array[int]
) -> Dictionary:
	var result: Dictionary = {}
	for pointer_id: int in pointer_ids:
		result[pointer_id] = _read_point(previous_points, pointer_id, _read_point(current_points, pointer_id))
	return result


static func _get_sorted_pointer_ids(points: Dictionary) -> Array[int]:
	var pointer_ids: Array[int] = []
	for pointer_key: Variant in points.keys():
		if pointer_key is int:
			var pointer_id: int = pointer_key
			pointer_ids.append(pointer_id)
	pointer_ids.sort()
	return pointer_ids


static func _average_points(points: Dictionary, pointer_ids: Array[int]) -> Vector2:
	if pointer_ids.is_empty():
		return Vector2.ZERO
	var total: Vector2 = Vector2.ZERO
	for pointer_id: int in pointer_ids:
		total += _read_point(points, pointer_id)
	return total / float(pointer_ids.size())


static func _read_point(points: Dictionary, pointer_id: int, default_value: Vector2 = Vector2.ZERO) -> Vector2:
	if not points.has(pointer_id):
		return default_value
	var value: Variant = points[pointer_id]
	if value is Vector2:
		var point: Vector2 = value
		return point
	return default_value


static func _is_mouse_wheel_button(button_index: MouseButton) -> bool:
	return button_index == MOUSE_BUTTON_WHEEL_UP or button_index == MOUSE_BUTTON_WHEEL_DOWN
