## GFVisualAction: 视觉表现动作的抽象基类。
##
## 继承自 RefCounted，代表一个具体的、可 await 的表现动作单元，
## 如移动动画、卡牌翻面、粒子爆炸等。
## 通过将每个视觉动作封装为独立对象，GFActionQueueSystem 可以严格按序
## 或并行地消费它们，从而彻底隔离底层逻辑时序与 UI 表现时序。
##
## 子类必须重写 execute() 以实现具体的视觉逻辑：
##   - 若动作是瞬时的（无需等待），直接执行并返回 null。
##   - 若动作需要等待（如 Tween/动画），返回一个 Signal，
##     外部可 await 此 Signal 以知悉动作结束。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFVisualAction
extends RefCounted


# --- 信号 ---

# 内置可等待视觉动作的完成信号。
signal _action_completed


# --- 枚举 ---

## 队列如何处理 execute() 的返回值。
## [br]
## @api public
enum CompletionMode {
	## 自动模式：返回 Signal 时等待，否则视为立即完成。
	AUTO,
	## 显式等待：语义上声明本动作需要等待返回的 Signal。
	WAIT_FOR_SIGNAL,
	## 发出即走：即使 execute() 返回 Signal，队列也不会等待。
	FIRE_AND_FORGET,
}


# --- 常量 ---

const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")
const _ACTION_TIME_POLICY = preload("res://addons/gf/extensions/action_queue/core/gf_action_time_policy.gd")


# --- 公共变量 ---

## 动作完成模式。默认自动等待 Signal，返回 null 则继续。
## [br]
## @api public
var completion_mode: CompletionMode = CompletionMode.AUTO

## 等待 Signal 的超时时间（秒）。小于等于 0 时表示不启用超时。
## [br]
## @api public
## [br]
## @since 3.17.0
var signal_timeout_seconds: float:
	get:
		return _signal_timeout_seconds
	set(value):
		_signal_timeout_seconds = _ACTION_TIME_POLICY.sanitize_non_negative_seconds(
			value,
			_signal_timeout_seconds
		)

## Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。
## [br]
## @api public
var signal_timeout_respects_time_scale: bool = true


# --- 私有变量 ---

var _architecture_ref: WeakRef = null
var _completion_emitted: bool = false
var _signal_timeout_seconds: float = 30.0


# --- 公共方法 ---

## 执行此视觉动作。子类必须重写此方法。
## [br]
## @api public
## [br]
## @return 瞬时动作返回 null；需要等待的动作返回一个 Signal 供 await。
## [br]
## @schema return: Variant，瞬时动作返回 null；需要等待的动作返回 Signal。
func execute() -> Variant:
	return null


## 判断动作在入队消费时是否仍然有效。
## 子类可根据目标节点、战斗目标或运行时状态决定是否跳过。
## [br]
## @api public
## [br]
## @return 有效返回 true。
func is_valid() -> bool:
	return true


## 判断动作是否可以执行。默认委托 is_valid()，便于子类覆盖更明确的语义。
## [br]
## @api public
## [br]
## @return 可以执行返回 true。
func can_execute() -> bool:
	return is_valid()


## 注入当前动作执行所在的架构实例。
## [br]
## @api framework_internal
## [br]
## @param architecture: 当前架构。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null


## 将动作标记为显式 fire-and-forget，并返回自身以便链式调用。
## [br]
## @api public
## [br]
## @return 当前动作实例。
func as_fire_and_forget() -> GFVisualAction:
	completion_mode = CompletionMode.FIRE_AND_FORGET
	return self


## 将动作标记为显式等待 Signal，并返回自身以便链式调用。
## [br]
## @api public
## [br]
## @return 当前动作实例。
func as_wait_for_signal() -> GFVisualAction:
	completion_mode = CompletionMode.WAIT_FOR_SIGNAL
	return self


## 请求取消动作。基础实现不做处理；持有 Tween、Timer、信号连接或外部任务的自定义动作应重写。
## [br]
## @api public
func cancel() -> void:
	pass


## 请求暂停动作。基础实现不做处理；可暂停动作应重写。
## [br]
## @api public
func pause() -> void:
	pass


## 请求恢复动作。基础实现不做处理；可暂停动作应重写。
## [br]
## @api public
func resume() -> void:
	pass


## 请求立即完成动作。基础实现委托 cancel()；需要区分取消和完成的动作应重写。
## [br]
## @api public
func finish() -> void:
	cancel()


## 返回用于保护 Signal 等待生命周期的节点。
## Tween 等非 Node 信号可通过该节点的 tree_exited 提前结束等待。
## [br]
## @api public
## [br]
## @return 等待保护节点；没有时返回 null。
func get_wait_guard_node() -> Node:
	return null


## 设置等待 Signal 的超时时间，并返回自身以便链式调用。
## [br]
## @api public
## [br]
## @param seconds: 超时时间；小于等于 0 时表示不启用超时。
## [br]
## @param respect_time_scale: 是否跟随 GFTimeUtility 的暂停与 time_scale。
## [br]
## @return 当前动作实例。
func with_signal_timeout(seconds: float, respect_time_scale: bool = true) -> GFVisualAction:
	signal_timeout_seconds = seconds
	signal_timeout_respects_time_scale = respect_time_scale
	return self


## 根据当前完成模式判断队列是否应该等待 execute() 的返回值。
## [br]
## @api public
## [br]
## @param result: execute() 返回值。
## [br]
## @return 应等待返回 true。
## [br]
## @schema result: Variant，由 execute() 返回，通常为 Signal 或 null。
func should_wait_for_result(result: Variant) -> bool:
	if completion_mode == CompletionMode.FIRE_AND_FORGET:
		return false
	return result is Signal


## 安全等待 execute() 返回的 Signal。
## 当发射源失效或 Node 提前退出树时，会自动结束等待，避免队列永久卡死。
## [br]
## @api public
## [br]
## @param result: execute() 返回值。
## [br]
## @param should_continue: 可选取消检查回调；返回 false 时立即停止等待。
## [br]
## @schema result: Variant，由 execute() 返回，等待时必须是 Signal。
func await_result_safely(result: Variant, should_continue: Callable = Callable()) -> void:
	if not should_wait_for_result(result):
		return

	var signal_result: Signal = result
	await _GF_ASYNC_WAIT_SUPPORT.await_signal_safely(
		signal_result,
		should_continue,
		_get_time_utility(),
		signal_timeout_seconds,
		signal_timeout_respects_time_scale,
		"[GFVisualAction] 等待 Signal 超时，队列将继续执行后续动作。",
		get_wait_guard_node()
	)


# --- 私有/辅助方法 ---

func _reset_completion_state() -> void:
	_completion_emitted = false


func _emit_completed_once() -> void:
	if _completion_emitted:
		return
	_completion_emitted = true
	_action_completed.emit()


func _get_time_utility() -> GFTimeUtility:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return _get_time_utility_value(architecture.get_utility(GFTimeUtility))


func _get_architecture_or_null() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture: GFArchitecture = _get_architecture_value(_architecture_ref.get_ref())
		if architecture != null:
			return architecture
	return GFAutoload.get_architecture_or_null()


func _get_time_utility_value(value: Variant) -> GFTimeUtility:
	if value is GFTimeUtility:
		var utility: GFTimeUtility = value
		return utility
	return null


func _get_architecture_value(value: Variant) -> GFArchitecture:
	if value is GFArchitecture:
		var architecture: GFArchitecture = value
		return architecture
	return null
