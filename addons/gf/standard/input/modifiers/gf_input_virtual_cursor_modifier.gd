## GFInputVirtualCursorModifier: 虚拟光标输入修饰器。
##
## 将二维输入视为速度并积分为一个位置值。它只维护抽象坐标，不访问 Viewport、
## Control 或具体 UI 节点。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputVirtualCursorModifier
extends GFInputModifier


# --- 导出变量 ---

## 初始位置。
## [br]
## @api public
@export var initial_position: Vector2 = Vector2(0.5, 0.5)

## 每秒移动速度倍率。
## [br]
## @api public
@export var speed: Vector2 = Vector2.ONE

## 是否按真实经过时间缩放输入。
## [br]
## @api public
@export var apply_delta_time: bool = true

## 是否使用 manual_delta_seconds 替代系统时钟。
## [br]
## @api public
## [br]
## @since 7.0.0
@export var use_manual_delta_time: bool = false

## 手动驱动的每步 delta 秒数，用于确定性输入回放。
## [br]
## @api public
## [br]
## @since 7.0.0
@export_range(0.0, 10.0, 0.0001) var manual_delta_seconds: float = 0.0

## 是否将位置限制在 clamp_rect 内。
## [br]
## @api public
@export var clamp_to_rect: bool = true

## 可用位置范围。
## [br]
## @api public
@export var clamp_rect: Rect2 = Rect2(Vector2.ZERO, Vector2.ONE)

## 输入低于该长度时视为空闲。
## [br]
## @api public
@export_range(0.0, 1.0, 0.001) var idle_threshold: float = 0.0

## 空闲时是否回到 initial_position。
## [br]
## @api public
@export var reset_when_idle: bool = false


# --- 公共变量 ---

## 当前虚拟光标位置。
## [br]
## @api public
var position: Vector2 = Vector2(0.5, 0.5)


# --- 私有变量 ---

var _initialized: bool = false
var _last_ticks_msec: int = 0


# --- 公共方法 ---

## 修改二维输入值。
## [br]
## @api public
## [br]
## @param value: 要写入或修改的值。
## [br]
## @param _event: 原始输入事件，默认实现不直接使用。
## [br]
## @param _action: 当前输入动作配置，默认实现不直接使用。
## [br]
## @return 更新后的虚拟光标位置。
func modify(value: Vector2, _event: InputEvent = null, _action: GFInputAction = null) -> Vector2:
	_ensure_initialized()
	var input_value: Vector2 = value if _is_finite_vector2(value) else Vector2.ZERO
	var safe_idle_threshold: float = _normalize_non_negative_scalar(idle_threshold)
	if input_value.length() <= safe_idle_threshold:
		if reset_when_idle:
			var _reset_position_result_85: Variant = reset_position()
		position = _normalize_position(position)
		_update_ticks()
		return position

	var safe_speed: Vector2 = speed if _is_finite_vector2(speed) else Vector2.ZERO
	position = _normalize_position(position + input_value * safe_speed * _get_step_delta())
	return position


## 修改三维输入值。
## [br]
## @api public
## [br]
## @param value: 要写入或修改的值。
## [br]
## @param event: 原始输入事件，默认实现不直接使用。
## [br]
## @param action: 当前输入动作配置，默认实现不直接使用。
## [br]
## @return 包含虚拟光标 X/Y 和原 Z 分量的三维值。
func modify_3d(value: Vector3, event: InputEvent = null, action: GFInputAction = null) -> Vector3:
	var cursor_position: Vector2 = modify(Vector2(value.x, value.y), event, action)
	return Vector3(cursor_position.x, cursor_position.y, value.z)


## 重置虚拟光标位置。
## [br]
## @api public
## [br]
## @return 当前修饰器。
func reset_position() -> GFInputVirtualCursorModifier:
	position = _normalize_position(initial_position)
	_initialized = true
	_update_ticks()
	return self


## 设置下一步和后续步骤使用的手动 delta 秒数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param delta_seconds: 手动 delta 秒数；小于 0 时按 0 处理。
## [br]
## @return 当前修饰器。
func set_manual_delta_seconds(delta_seconds: float) -> GFInputVirtualCursorModifier:
	manual_delta_seconds = _normalize_non_negative_scalar(delta_seconds)
	use_manual_delta_time = true
	_last_ticks_msec = 0
	return self


## 获取运行时状态快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前运行时状态。
## [br]
## @schema return: Dictionary，包含 position 与 initialized。
func get_runtime_state() -> Dictionary:
	return {
		"position": position,
		"initialized": _initialized,
	}


## 从运行时状态快照恢复虚拟光标。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param state: get_runtime_state() 生成的状态。
## [br]
## @return 当前修饰器。
## [br]
## @schema state: Dictionary，可包含 position: Vector2 与 initialized: bool。
func restore_runtime_state(state: Dictionary) -> GFInputVirtualCursorModifier:
	position = _normalize_position(GFVariantData.get_option_vector2(state, "position", initial_position))
	_initialized = GFVariantData.get_option_bool(state, "initialized", false)
	_last_ticks_msec = 0
	return self


## 当前修饰器是否维护运行时状态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 始终返回 true。
func supports_runtime_state() -> bool:
	return true


## 获取运行时状态快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前运行时状态。
## [br]
## @schema return: Dictionary，包含 position 与 initialized。
func get_modifier_runtime_state() -> Dictionary:
	return get_runtime_state()


## 从运行时状态快照恢复虚拟光标。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param state: get_modifier_runtime_state() 生成的状态。
## [br]
## @schema state: Dictionary，可包含 position: Vector2 与 initialized: bool。
## [br]
## @return 当前修饰器。
func restore_modifier_runtime_state(state: Dictionary) -> GFInputModifier:
	return restore_runtime_state(state)


## 重置运行时状态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前修饰器。
func reset_modifier_runtime_state() -> GFInputModifier:
	return reset_position()


## 设置下一步和后续步骤使用的运行时 delta 秒数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param delta_seconds: 运行时 delta 秒数；小于 0 时按 0 处理。
## [br]
## @return 当前修饰器。
func set_runtime_delta_seconds(delta_seconds: float) -> GFInputModifier:
	return set_manual_delta_seconds(delta_seconds)


## 清除手动运行时 delta，恢复系统时间源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前修饰器。
func clear_runtime_delta_seconds() -> GFInputModifier:
	use_manual_delta_time = false
	_last_ticks_msec = 0
	return self


## 创建运行时副本。
## [br]
## @api public
## [br]
## @return 修饰器副本。
func duplicate_modifier() -> GFInputModifier:
	var modifier: GFInputVirtualCursorModifier = _duplicate_virtual_cursor_modifier()
	if modifier == null:
		return null
	modifier.position = modifier.initial_position
	modifier._initialized = false
	modifier._last_ticks_msec = 0
	return modifier


# --- 私有/辅助方法 ---

func _ensure_initialized() -> void:
	if _initialized:
		return
	position = _normalize_position(initial_position)
	_initialized = true
	_update_ticks()


func _get_step_delta() -> float:
	if not apply_delta_time:
		_update_ticks()
		return 1.0
	if use_manual_delta_time:
		_last_ticks_msec = 0
		return _normalize_non_negative_scalar(manual_delta_seconds)

	var now: int = Time.get_ticks_msec()
	var delta: float = 0.0
	if _last_ticks_msec > 0:
		delta = float(now - _last_ticks_msec) / 1000.0
	_last_ticks_msec = now
	return maxf(delta, 0.0)


func _update_ticks() -> void:
	if use_manual_delta_time:
		_last_ticks_msec = 0
		return
	_last_ticks_msec = Time.get_ticks_msec()


func _clamp_position(value: Vector2) -> Vector2:
	var rect: Rect2 = clamp_rect.abs()
	return Vector2(
		clampf(value.x, rect.position.x, rect.end.x),
		clampf(value.y, rect.position.y, rect.end.y)
	)


func _normalize_position(value: Vector2) -> Vector2:
	var fallback: Vector2 = initial_position if _is_finite_vector2(initial_position) else Vector2.ZERO
	var result: Vector2 = value if _is_finite_vector2(value) else fallback
	if clamp_to_rect and _is_finite_rect(clamp_rect):
		result = _clamp_position(result)
	return result


func _is_finite_rect(rect: Rect2) -> bool:
	return (
		_is_finite_vector2(rect.position)
		and _is_finite_vector2(rect.size)
		and _is_finite_vector2(rect.position + rect.size)
	)


func _is_finite_vector2(value: Vector2) -> bool:
	return not is_nan(value.x) and not is_inf(value.x) and not is_nan(value.y) and not is_inf(value.y)


func _normalize_non_negative_scalar(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return maxf(value, 0.0)


func _duplicate_virtual_cursor_modifier() -> GFInputVirtualCursorModifier:
	var modifier: Resource = duplicate(true)
	if modifier is GFInputVirtualCursorModifier:
		var cursor_modifier: GFInputVirtualCursorModifier = modifier
		return cursor_modifier
	return null
