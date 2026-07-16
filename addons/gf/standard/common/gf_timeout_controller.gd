## GFTimeoutController: 可复用的超时取消控制器。
##
## 将“超时”建模为取消 token 的一种原因，并提供 start / reset / stop 的可复用生命周期。
## 它只负责产生超时信号和 token，不执行重试、回滚或业务流程。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFTimeoutController
extends RefCounted


# --- 信号 ---

## 当前超时计划触发时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 超时取消原因。
## [br]
## @param metadata: 超时上下文。
## [br]
## @schema metadata: Dictionary，包含调用方传入的超时上下文。
signal timed_out(reason: StringName, metadata: Dictionary)


# --- 常量 ---

## 默认超时原因。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_TIMEOUT_REASON: StringName = &"timeout"


# --- 公共变量 ---

## 是否在暂停时继续计时。
## [br]
## @api public
## [br]
## @since 7.0.0
var process_always: bool = true

## 是否在物理帧中处理超时计时器。
## [br]
## @api public
## [br]
## @since 7.0.0
var process_in_physics: bool = false

## 是否忽略 Engine.time_scale。
## [br]
## @api public
## [br]
## @since 7.0.0
var ignore_time_scale: bool = false


# --- 私有变量 ---

var _source: GFCancellationSource = null
var _source_callback: Callable = Callable()
var _active: bool = false
var _timed_out: bool = false
var _manual_cancel_pending: bool = false
var _timeout_seconds: float = 0.0
var _started_msec: int = 0
var _last_reason: StringName = &""
var _last_metadata: Dictionary = {}


# --- Godot 生命周期方法 ---

## 创建超时控制器。
## [br]
## @api public
## [br]
## @since 7.0.0
func _init() -> void:
	_replace_source()


# --- 公共方法 ---

## 获取当前取消 token。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前超时控制器持有的 token。
func get_token() -> GFCancellationToken:
	return _source.get_token()


## 启动一个新的超时计划。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param seconds: 超时时间；小于等于 0 时立即超时。
## [br]
## @param tree: 可选 SceneTree；为空时使用当前主循环。
## [br]
## @param reason: 超时取消原因；为空时使用 timeout。
## [br]
## @param metadata: 超时上下文。
## [br]
## @return 当前计划使用的 token。
## [br]
## @schema metadata: Dictionary，包含调用方定义的超时上下文。
func start_seconds(
	seconds: float,
	tree: SceneTree = null,
	reason: StringName = DEFAULT_TIMEOUT_REASON,
	metadata: Dictionary = {}
) -> GFCancellationToken:
	if _source == null or _source.is_cancel_requested():
		_replace_source()
	else:
		_source.dispose()

	_active = true
	_timed_out = false
	_timeout_seconds = maxf(seconds, 0.0)
	_started_msec = Time.get_ticks_msec()
	_last_reason = reason if reason != &"" else DEFAULT_TIMEOUT_REASON
	_last_metadata = metadata.duplicate(true)

	var scheduled: bool = _source.cancel_after_seconds(
		_timeout_seconds,
		tree,
		_last_reason,
		_last_metadata,
		process_always,
		process_in_physics,
		ignore_time_scale
	)
	if not scheduled and not _source.is_cancel_requested():
		_active = false
	return _source.get_token()


## 停止当前超时计划，不取消 token。
## [br]
## @api public
## [br]
## @since 7.0.0
func stop() -> void:
	if _source != null:
		_source.dispose()
	_active = false


## 重置为一个未取消 token，并清除超时状态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 重置后的 token。
func reset() -> GFCancellationToken:
	if _source == null or _source.is_cancel_requested():
		_replace_source()
	else:
		_source.dispose()
	_clear_timeout_state()
	return _source.get_token()


## 主动取消当前 token。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 取消原因。
## [br]
## @param metadata: 取消上下文。
## [br]
## @return 首次取消时返回 true。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:
	if _source == null:
		return false
	_manual_cancel_pending = true
	var cancelled_now: bool = _source.cancel(reason, metadata)
	_manual_cancel_pending = false
	return cancelled_now


## 判断当前 token 是否已取消。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 已取消时返回 true。
func is_cancelled() -> bool:
	return _source != null and _source.is_cancel_requested()


## 判断当前是否存在待触发的超时计划。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 存在活动超时计划时返回 true。
func is_active() -> bool:
	return _active


## 判断最近一次取消是否来自超时计划。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 最近一次取消由超时触发时返回 true。
func is_timeout() -> bool:
	return _timed_out


## 获取当前超时计划已运行毫秒数。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 从 start_seconds 开始经过的毫秒数；未启动时为 0。
func get_elapsed_msec() -> int:
	if _started_msec <= 0:
		return 0
	return maxi(Time.get_ticks_msec() - _started_msec, 0)


## 释放当前计划和连接。
## [br]
## @api public
## [br]
## @since 7.0.0
func dispose() -> void:
	if _source != null:
		_source.dispose()
	_disconnect_source()
	_clear_timeout_state()


## 获取超时控制器调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 active、timed_out、timeout_seconds、elapsed_msec、reason、metadata 和 token。
func get_debug_snapshot() -> Dictionary:
	return {
		"active": _active,
		"timed_out": _timed_out,
		"timeout_seconds": _timeout_seconds,
		"elapsed_msec": get_elapsed_msec(),
		"reason": _last_reason,
		"metadata": _last_metadata.duplicate(true),
		"token": _source.get_debug_snapshot() if _source != null else {},
	}


# --- 私有/辅助方法 ---

func _replace_source() -> void:
	_disconnect_source()
	_source = GFCancellationSource.new()
	_source_callback = Callable(self, "_on_token_cancelled")
	var _connect_error: Error = _source.get_token().cancel_requested.connect(
		_source_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if _connect_error != OK:
		_source_callback = Callable()
		push_warning("[GFTimeoutController] 无法连接取消 token，超时状态将不会自动更新。")


func _disconnect_source() -> void:
	if _source == null or not _source_callback.is_valid():
		return
	var token: GFCancellationToken = _source.get_token()
	if token.cancel_requested.is_connected(_source_callback):
		token.cancel_requested.disconnect(_source_callback)
	_source_callback = Callable()


func _clear_timeout_state() -> void:
	_active = false
	_timed_out = false
	_manual_cancel_pending = false
	_timeout_seconds = 0.0
	_started_msec = 0
	_last_reason = &""
	_last_metadata.clear()


func _on_token_cancelled(reason: StringName) -> void:
	var metadata: Dictionary = _source.get_token().get_cancel_metadata() if _source != null else {}
	var cancelled_by_timeout: bool = _active and not _manual_cancel_pending and reason == _last_reason
	_active = false
	if not cancelled_by_timeout:
		return
	_timed_out = true
	timed_out.emit(reason, metadata.duplicate(true))
