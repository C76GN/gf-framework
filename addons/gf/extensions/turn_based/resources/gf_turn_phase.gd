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
## @param _completion: 仅能完成本次阶段运行的一次性句柄；异步回调必须捕获该句柄，而不是稍后按 Context 查找运行态。
## [br]
## @return: 可等待结果。
## [br]
## @schema return: Variant that is null or a Signal awaited before phase completion.
func _execute(
	_context: GFTurnContext,
	_completion: GFTurnPhaseCompletionHandle
) -> Variant:
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
## @param lease: 本次推进持有的精确 Context 操作租约。
## [br]
## @param owner: 持有租约的 Flow System。
## [br]
## @param flow_serial: 持有租约的 Flow generation。
## [br]
## @return: 创建成功时返回独立运行态；上下文无效或已在运行时返回 null。
func begin_runtime(
	context: GFTurnContext,
	lease: GFTurnContext.FlowOperationLease,
	owner: GFTurnFlowSystem,
	flow_serial: int
) -> RuntimeState:
	if (
		context == null
		or owner == null
		or not context.is_flow_operation_lease_active(lease, owner, flow_serial)
	):
		return null
	var context_id: int = context.get_instance_id()
	if _runtime_by_context_id.has(context_id):
		push_error("[GFTurnPhase] 同一 context 已存在活动运行态。")
		return null
	var runtime: RuntimeState = RuntimeState.new()
	if not runtime.configure_from_flow(context, lease, owner, flow_serial):
		return null
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
	runtime.invalidate_from_flow()
	var _runtime_erased: bool = _runtime_by_context_id.erase(context_id)


# --- 私有/辅助方法 ---

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

	var _active: bool = false
	var _completion_handle: GFTurnPhaseCompletionHandle = null
	var _context_ref: WeakRef = null
	var _lease: GFTurnContext.FlowOperationLease = null
	var _owner_ref: WeakRef = null
	var _flow_serial: int = -1

	## 绑定本次运行的精确 Context claim，并创建公开 completion handle。
	## [br]
	## @api framework_internal
	## [br]
	## @since unreleased
	## [br]
	## @param context: 本次运行的 Context。
	## [br]
	## @param lease: 本次阶段 operation 的精确 claim。
	## [br]
	## @param owner: claim 的 Flow System owner。
	## [br]
	## @param flow_serial: claim 所属 Flow generation。
	## [br]
	## @return: 绑定成功时返回 true。
	func configure_from_flow(
		context: GFTurnContext,
		lease: GFTurnContext.FlowOperationLease,
		owner: GFTurnFlowSystem,
		flow_serial: int
	) -> bool:
		if (
			_active
			or context == null
			or owner == null
			or not context.is_flow_operation_lease_active(lease, owner, flow_serial)
		):
			return false
		_context_ref = weakref(context)
		_lease = lease
		_owner_ref = weakref(owner)
		_flow_serial = flow_serial
		_completion_handle = GFTurnPhaseCompletionHandle.new()
		if not _completion_handle.configure_from_turn_based(self):
			_completion_handle = null
			_context_ref = null
			_lease = null
			_owner_ref = null
			_flow_serial = -1
			return false
		_active = true
		return true

	## 获取传给项目 `_execute()` 的精确 completion handle。
	## [br]
	## @api framework_internal
	## [br]
	## @since unreleased
	## [br]
	## @return: 传给项目 `_execute()` 的精确 completion handle。
	func get_completion_handle() -> GFTurnPhaseCompletionHandle:
		return _completion_handle

	## 由 Flow 的 auto_finish 路径完成本次精确运行。
	## [br]
	## @api framework_internal
	## [br]
	## @since unreleased
	## [br]
	## @return: 本次运行仍有效且首次完成时返回 true。
	func try_complete_from_flow() -> bool:
		return try_complete_from_turn_based(_completion_handle)

	## 仅供 GFTurnPhaseCompletionHandle 提交本次精确完成权限。
	## [br]
	## @api layer_internal
	## [br]
	## @layer extensions/turn_based
	## [br]
	## @since unreleased
	## [br]
	## @param handle: 请求完成本次运行的精确 handle。
	## [br]
	## @return: 本次运行仍有效且首次完成时返回 true。
	func try_complete_from_turn_based(handle: GFTurnPhaseCompletionHandle) -> bool:
		return _try_complete(handle)

	## 使 completion authority 立即失效；不会释放由 Flow 持有的 Context claim。
	## [br]
	## @api framework_internal
	## [br]
	## @since unreleased
	func invalidate_from_flow() -> void:
		if _completion_handle != null:
			var _invalidated: bool = _completion_handle.invalidate_from_turn_based(self)
		_active = false
		_context_ref = null
		_lease = null
		_owner_ref = null
		_flow_serial = -1

	func _try_complete(handle: GFTurnPhaseCompletionHandle) -> bool:
		if (
			not _active
			or is_finished
			or handle == null
			or handle != _completion_handle
			or _context_ref == null
			or _owner_ref == null
		):
			return false
		var context_value: Variant = _context_ref.get_ref()
		var owner_value: Variant = _owner_ref.get_ref()
		if not (context_value is GFTurnContext) or not (owner_value is GFTurnFlowSystem):
			return false
		var context: GFTurnContext = context_value
		var owner: GFTurnFlowSystem = owner_value
		if not context.is_flow_operation_lease_active(_lease, owner, _flow_serial):
			return false
		is_finished = true
		_active = false
		var _invalidated: bool = handle.invalidate_from_turn_based(self)
		finished.emit()
		return true
