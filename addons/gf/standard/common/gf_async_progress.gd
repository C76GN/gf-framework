## GFAsyncProgress: 可节流的通用异步进度句柄。
##
## 用于把下载、预热、导入、后台任务或项目流程的进度更新统一为 0 到 1 的值、
## 可选消息和元数据。它不决定 UI 样式，也不绑定具体任务类型。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFAsyncProgress
extends RefCounted


# --- 信号 ---

## 进度通过节流条件并对外发布时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 当前进度，范围 0 到 1。
## [br]
## @param message: 当前进度消息。
## [br]
## @param metadata: 当前进度元数据。
## [br]
## @schema metadata: Dictionary，调用方定义的进度上下文。
signal progressed(value: float, message: String, metadata: Dictionary)


# --- 公共变量 ---

## 触发进度信号的最小数值变化。设为 0 时任意数值变化都会触发。
## [br]
## @api public
## [br]
## @since 7.0.0
var min_delta: float = 0.0:
	set(value):
		min_delta = maxf(value, 0.0)

## 触发进度信号的最小时间间隔，单位毫秒。设为 0 时不按时间节流。
## [br]
## @api public
## [br]
## @since 7.0.0
var min_interval_msec: int = 0:
	set(value):
		min_interval_msec = maxi(value, 0)

## 消息变化时是否允许触发信号，即使数值变化小于 min_delta。
## [br]
## @api public
## [br]
## @since 7.0.0
var emit_on_message_change: bool = true


# --- 私有变量 ---

var _value: float = 0.0
var _message: String = ""
var _metadata: Dictionary = {}
var _last_emitted_value: float = 0.0
var _last_emitted_message: String = ""
var _last_emitted_msec: int = 0
var _has_emitted: bool = false


# --- Godot 生命周期方法 ---

## 创建进度句柄。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param initial_value: 初始进度，范围会被夹到 0 到 1。
## [br]
## @param initial_message: 初始消息。
## [br]
## @param initial_metadata: 初始元数据。
## [br]
## @schema initial_metadata: Dictionary，调用方定义的进度上下文。
func _init(initial_value: float = 0.0, initial_message: String = "", initial_metadata: Dictionary = {}) -> void:
	_value = clampf(initial_value, 0.0, 1.0)
	_message = initial_message
	_metadata = initial_metadata.duplicate(true)


# --- 公共方法 ---

## 更新进度，并在满足节流条件时发出 progressed。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 新进度值，范围会被夹到 0 到 1。
## [br]
## @param message: 进度消息。
## [br]
## @param metadata: 进度元数据。
## [br]
## @return 本次更新是否发出了 progressed。
## [br]
## @schema metadata: Dictionary，调用方定义的进度上下文。
func update(value: float, message: String = "", metadata: Dictionary = {}) -> bool:
	_value = clampf(value, 0.0, 1.0)
	_message = message
	_metadata = metadata.duplicate(true)
	if not _should_emit(false):
		return false
	_emit_progress()
	return true


## 强制发布当前进度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 是否成功发出 progressed。
func force_emit() -> bool:
	_emit_progress()
	return true


## 将进度更新为 1.0 并强制发布。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param message: 完成消息。
## [br]
## @param metadata: 完成元数据。
## [br]
## @return 是否成功发出 progressed。
## [br]
## @schema metadata: Dictionary，调用方定义的进度上下文。
func complete(message: String = "", metadata: Dictionary = {}) -> bool:
	_value = 1.0
	_message = message
	_metadata = metadata.duplicate(true)
	_emit_progress()
	return true


## 重置进度状态，不发出信号。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param value: 新进度值。
## [br]
## @param message: 新消息。
## [br]
## @param metadata: 新元数据。
## [br]
## @schema metadata: Dictionary，调用方定义的进度上下文。
func reset(value: float = 0.0, message: String = "", metadata: Dictionary = {}) -> void:
	_value = clampf(value, 0.0, 1.0)
	_message = message
	_metadata = metadata.duplicate(true)
	_last_emitted_value = _value
	_last_emitted_message = _message
	_last_emitted_msec = 0
	_has_emitted = false


## 获取当前进度值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前进度值。
func get_value() -> float:
	return _value


## 获取当前消息。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前消息。
func get_message() -> String:
	return _message


## 获取当前元数据副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前元数据副本。
## [br]
## @schema return: Dictionary，调用方定义的进度上下文。
func get_metadata() -> Dictionary:
	return _metadata.duplicate(true)


## 获取进度状态快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 进度状态快照。
## [br]
## @schema return: Dictionary，包含 value、message、metadata、min_delta、min_interval_msec、has_emitted 和 last_emitted_value。
func get_debug_snapshot() -> Dictionary:
	return {
		"value": _value,
		"message": _message,
		"metadata": _metadata.duplicate(true),
		"min_delta": min_delta,
		"min_interval_msec": min_interval_msec,
		"emit_on_message_change": emit_on_message_change,
		"has_emitted": _has_emitted,
		"last_emitted_value": _last_emitted_value,
		"last_emitted_message": _last_emitted_message,
		"last_emitted_msec": _last_emitted_msec,
	}


# --- 私有/辅助方法 ---

func _should_emit(force: bool) -> bool:
	if force or not _has_emitted:
		return true

	var now_msec: int = Time.get_ticks_msec()
	if min_interval_msec > 0 and now_msec - _last_emitted_msec < min_interval_msec:
		return false
	if absf(_value - _last_emitted_value) >= min_delta and not is_equal_approx(_value, _last_emitted_value):
		return true
	if emit_on_message_change and _message != _last_emitted_message:
		return true
	return false


func _emit_progress() -> void:
	_last_emitted_value = _value
	_last_emitted_message = _message
	_last_emitted_msec = Time.get_ticks_msec()
	_has_emitted = true
	progressed.emit(_value, _message, _metadata.duplicate(true))
