## GFTurnPhase: 通用回合阶段基类。
##
## 阶段只提供 _enter/_execute/_exit 生命周期和完成信号，
## 不绑定任何具体游戏流程。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFTurnPhase
extends Resource


# --- 信号 ---

## 阶段完成时发出。
## [br]
## @api public
signal finished


# --- 导出变量 ---

## 阶段标识。
## [br]
## @api public
@export var phase_id: StringName = &""

## `_execute()` 返回后是否自动完成阶段。
## [br]
## @api public
@export var auto_finish: bool = true


# --- 私有变量 ---

var _runtime_by_context_id: Dictionary = {}


# --- 公共方法 ---

## 标记指定上下文的阶段运行完成。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param context: 活动 Flow 的上下文；只有一个运行态时可省略。
func finish(context: GFTurnContext = null) -> void:
	var runtime: RuntimeState = _resolve_runtime(context)
	if runtime != null:
		runtime.finish()


## 查询指定上下文的阶段是否完成。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param context: 活动 Flow 的上下文。
## [br]
## @return: 对应运行态存在且已经完成时返回 true。
func is_finished_for(context: GFTurnContext) -> bool:
	var runtime: RuntimeState = _get_runtime(context)
	return runtime != null and runtime.is_finished


# --- 可重写钩子 / 虚方法 ---

## 进入阶段时由 GFTurnFlowSystem 调用。
## [br]
## @api protected
## [br]
## @param _context: 回合上下文。
func _enter(_context: GFTurnContext) -> void:
	pass


## 执行阶段逻辑时由 GFTurnFlowSystem 调用。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _context: 回合上下文。
## [br]
## @return: 可等待结果。
## [br]
## @schema return: Variant that is null or a Signal awaited before phase completion.
func _execute(_context: GFTurnContext) -> Variant:
	return null


## 退出阶段时由 GFTurnFlowSystem 调用。
## [br]
## @api protected
## [br]
## @param _context: 回合上下文。
func _exit(_context: GFTurnContext) -> void:
	pass


# --- 框架内部方法 ---

## 为一次 Flow 推进创建独立运行态。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param context: 本次推进持有的回合上下文。
## [br]
## @return: 创建成功时返回独立运行态；上下文无效或已在运行时返回 null。
func begin_runtime(context: GFTurnContext) -> RuntimeState:
	if context == null:
		return null
	var context_id: int = context.get_instance_id()
	if _runtime_by_context_id.has(context_id):
		push_error("[GFTurnPhase] 同一 context 已存在活动运行态。")
		return null
	var runtime: RuntimeState = RuntimeState.new()
	_runtime_by_context_id[context_id] = runtime
	var _finished_connected: Error = runtime.finished.connect(
		_on_runtime_finished.bind(context_id, runtime)
	) as Error
	return runtime


## 释放一次 Flow 推进的运行态。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param context: 本次推进持有的回合上下文。
## [br]
## @param runtime: begin_runtime() 返回的运行态。
func end_runtime(context: GFTurnContext, runtime: RuntimeState) -> void:
	if context == null or runtime == null:
		return
	var context_id: int = context.get_instance_id()
	if _get_runtime_value(GFVariantData.get_option_value(_runtime_by_context_id, context_id)) != runtime:
		return
	var _runtime_erased: bool = _runtime_by_context_id.erase(context_id)


# --- 私有/辅助方法 ---

func _resolve_runtime(context: GFTurnContext) -> RuntimeState:
	if context != null:
		return _get_runtime(context)
	if _runtime_by_context_id.is_empty():
		return null
	if _runtime_by_context_id.size() > 1:
		push_error("[GFTurnPhase] finish 失败：存在多个活动运行态，必须提供 context。")
		return null
	return _get_runtime_value(_runtime_by_context_id.values()[0])


func _get_runtime(context: GFTurnContext) -> RuntimeState:
	if context == null:
		return null
	return _get_runtime_value(GFVariantData.get_option_value(_runtime_by_context_id, context.get_instance_id()))


func _get_runtime_value(value: Variant) -> RuntimeState:
	if value is RuntimeState:
		var runtime: RuntimeState = value
		return runtime
	return null


# --- 信号处理函数 ---

func _on_runtime_finished(context_id: int, runtime: RuntimeState) -> void:
	if _get_runtime_value(GFVariantData.get_option_value(_runtime_by_context_id, context_id)) != runtime:
		return
	finished.emit()


# --- 内部类 ---

## 单次阶段推进的上下文隔离运行态。
## [br]
## @api framework_internal
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
class RuntimeState extends RefCounted:
	## 当前运行态完成时发出。
	## [br]
	## @api framework_internal
	## [br]
	## @since 8.0.0
	signal finished

	## 当前运行态是否已经完成。
	## [br]
	## @api framework_internal
	## [br]
	## @since 8.0.0
	var is_finished: bool = false

	## 幂等地标记当前运行态完成。
	## [br]
	## @api framework_internal
	## [br]
	## @since 8.0.0
	func finish() -> void:
		if is_finished:
			return
		is_finished = true
		finished.emit()
