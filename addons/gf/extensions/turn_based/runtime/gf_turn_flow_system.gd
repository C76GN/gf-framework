## GFTurnFlowSystem: 通用回合流程系统。
##
## 提供阶段推进、行动排队和按优先级解析能力。
## 它不关心战斗、卡牌、棋盘等具体业务，只调度抽象行动。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFTurnFlowSystem
extends GFSystem


# --- 信号 ---

## 流程开始时发出。
## [br]
## @api public
## [br]
## @param context: 当前回合上下文。
signal flow_started(context: GFTurnContext)

## 流程停止时发出。
## [br]
## @api public
## [br]
## @param context: 当前回合上下文。
signal flow_stopped(context: GFTurnContext)

## 阶段切换时发出。
## [br]
## @api public
## [br]
## @param phase: 当前阶段。
## [br]
## @param index: 当前阶段索引。
signal phase_changed(phase: GFTurnPhase, index: int)

## 行动入队时发出。
## [br]
## @api public
## [br]
## @param action: 入队行动。
signal action_enqueued(action: GFTurnAction)

## 行动解析完成时发出。
## [br]
## @api public
## [br]
## @param action: 已解析行动。
signal action_resolved(action: GFTurnAction)


# --- 枚举 ---

## 流程启动、运行与停止的内部状态，控制回调期间是否允许重放启动请求。
## [br]
## @api private
enum _LifecycleState {
	STOPPED,
	STARTING,
	RUNNING,
	STOPPING,
}


# --- 常量 ---

## Signal 安全等待实现，用于阶段和行动回调的有限/受控等待。
## [br]
## @api private
## [br]
const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")




# --- 公共变量 ---

## 当前回合上下文。
## [br]
## @api public
## [br]
## @since 3.17.0
var context: GFTurnContext:
	get:
		return _context
	set(value):
		set_context(value)

## 阶段列表。
## [br]
## @api public
## [br]
## @since 3.17.0
var phases: Array[GFTurnPhase]:
	get:
		return _phases.duplicate()
	set(value):
		set_phases(value)

## 当前阶段索引。
## [br]
## @api public
## [br]
## @since 3.17.0
var current_phase_index: int:
	get:
		return _current_phase_index

## 当前是否正在运行。
## [br]
## @api public
## [br]
## @since 3.17.0
var is_running: bool:
	get:
		return _is_running

## 解析行动前是否按优先级排序。
## [br]
## @api public
var sort_actions_before_resolve: bool = true

## Signal 等待超时时间。小于等于 0 表示不启用超时。
## [br]
## @api public
var signal_timeout_seconds: float = 30.0

## Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。
## [br]
## @api public
var signal_timeout_respects_time_scale: bool = true


# --- 私有变量 ---

## 当前 Flow generation 序号。
## [br]
## @api private
## [br]
var _flow_serial: int = 0

## 阶段推进协程是否正在进行。
## [br]
## @api private
## [br]
var _is_advancing_phase: bool = false

## 行动解析协程是否正在进行。
## [br]
## @api private
## [br]
var _is_resolving_actions: bool = false

## 当前使用的上下文对象。
## [br]
## @api private
## [br]
var _context: GFTurnContext = GFTurnContext.new()

## Flow 使用的阶段序列。
## [br]
## @api private
## [br]
var _phases: Array[GFTurnPhase] = []

## 当前阶段索引；尚未进入阶段时为 -1。
## [br]
## @api private
## [br]
var _current_phase_index: int = -1

## 对外运行状态属性的后备值。
## [br]
## @api private
## [br]
var _is_running: bool = false

## 等待解析或消费的行动队列。
## [br]
## @api private
## [br]
var _actions: Array[GFTurnAction] = []

## 分配给新入队行动的顺序号。
## [br]
## @api private
## [br]
var _next_action_order: int = 0

## 以行动实例 ID 记录入队顺序，供默认比较器稳定排序。
## [br]
## @api private
## [br]
var _action_order_by_instance_id: Dictionary = {}

## 取消正在解析的行动时，是否保留尚未处理的有效行动。
## [br]
## @api private
## [br]
var _restore_pending_actions_on_cancel: bool = false

## _LifecycleState 当前取值。
## [br]
## @api private
## [br]
var _lifecycle_state: int = _LifecycleState.STOPPED

## 请求停止后等待活动 operation 收尾的标志。
## [br]
## @api private
## [br]
var _active_operation_stop_requested: bool = false

## 此 Flow System 当前持有、尚待释放的 Context 操作租约。
## [br]
## @api private
## [br]
var _active_context_operation_leases: Array[GFTurnContext.FlowOperationLease] = []

## flow_started 信号通知期间的重入保护标志。
## [br]
## @api private
## [br]
var _is_notifying_flow_started: bool = false

## 是否有等待生命周期安全点重放的 start 请求。
## [br]
## @api private
## [br]
var _has_pending_start_request: bool = false

## 待重放 start 请求是否重置索引。
## [br]
## @api private
## [br]
var _pending_start_reset_indices: bool = true

## 系统是否已经 dispose。
## [br]
## @api private
## [br]
var _is_disposed: bool = false


# --- 公共方法 ---

## 设置上下文。
## 存在活动 Context operation claim 时会拒绝修改；operation 安全收尾并释放最后一张 claim 后可顺序重试。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param p_context: 新上下文。
func set_context(p_context: GFTurnContext) -> void:
	if (
		_is_advancing_phase
		or _is_resolving_actions
		or not _active_context_operation_leases.is_empty()
	):
		push_warning("[GFTurnFlowSystem][turn_flow_system.context_operation_active] set_context failed: a Context operation is active.")
		return
	var next_context: GFTurnContext = p_context if p_context != null else GFTurnContext.new()
	if _context == next_context:
		return
	_flow_serial += 1
	_clear_actions_internal()
	_context = next_context
	_current_phase_index = -1


## 设置阶段列表。
## [br]
## @api public
## [br]
## @param p_phases: 新阶段列表。
func set_phases(p_phases: Array[GFTurnPhase]) -> void:
	if _is_advancing_phase:
		push_warning("[GFTurnFlowSystem][turn_flow_system.set_phases_during_advance] set_phases failed: a phase is being advanced.")
		return
	_phases.clear()
	for phase: GFTurnPhase in p_phases:
		if phase == null:
			push_warning("[GFTurnFlowSystem][turn_flow_system.empty_set_phase] set_phases skipped a null phase.")
			continue
		_phases.append(phase)
	_current_phase_index = -1


## 开始流程。
## 若同一 Context 正由其他 Flow generation 持有，本次调用会在重置索引、轮次或发出信号前失败关闭；最后一张 operation claim 释放后可顺序重试。
## 若本 system 在自身 [signal flow_started] 通知中完成 [method stop]，并在由此发出的 [signal flow_stopped] 回调中再次调用本方法，首个重启请求会等旧 claim 释放后同步重放；重放前的后续 [method stop] 或 [method dispose] 会取消该请求。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param reset_indices: 是否重置阶段索引和轮次数据。
func start(reset_indices: bool = true) -> void:
	if _is_disposed:
		return
	if _lifecycle_state == _LifecycleState.STARTING or _lifecycle_state == _LifecycleState.RUNNING:
		return
	if _lifecycle_state == _LifecycleState.STOPPING:
		return
	if _is_advancing_phase or _is_resolving_actions:
		push_warning("[GFTurnFlowSystem][turn_flow_system.start_during_processing] start failed: the flow is advancing or resolving.")
		return
	if (
		_lifecycle_state == _LifecycleState.STOPPED
		and _is_notifying_flow_started
		and not _active_context_operation_leases.is_empty()
	):
		if not _has_pending_start_request:
			_has_pending_start_request = true
			_pending_start_reset_indices = reset_indices
		return
	var active_context: GFTurnContext = _context
	var next_flow_serial: int = _flow_serial + 1
	var start_lease: GFTurnContext.FlowOperationLease = _acquire_context_operation_lease(
		active_context,
		next_flow_serial
	)
	if start_lease == null:
		push_warning("[GFTurnFlowSystem][turn_flow_system.start_context_held] start failed: context is held by another flow generation.")
		return
	_lifecycle_state = _LifecycleState.STARTING
	_flow_serial = next_flow_serial
	if reset_indices:
		_current_phase_index = -1
		active_context.reset_round_from_flow(start_lease, self, _flow_serial)
	_restore_pending_actions_on_cancel = false
	_active_operation_stop_requested = false
	_is_running = true
	_lifecycle_state = _LifecycleState.RUNNING
	_is_notifying_flow_started = true
	flow_started.emit(active_context)
	_is_notifying_flow_started = false
	_release_context_operation_lease(active_context, start_lease)


## 停止流程。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param should_clear_actions: 是否清空待处理行动。即使流程已经 stopped，true 仍会幂等清理并封存队列；此前的保留策略也会升级为清理。
func stop(should_clear_actions: bool = true) -> void:
	_clear_pending_start_request()
	_cancel_active_context_operation_leases()
	if should_clear_actions:
		_restore_pending_actions_on_cancel = false
		_clear_actions_internal()
	if _lifecycle_state == _LifecycleState.STOPPING:
		return
	if (
		_lifecycle_state == _LifecycleState.STOPPED
		and (
			not (_is_advancing_phase or _is_resolving_actions)
			or _active_operation_stop_requested
		)
	):
		return
	_lifecycle_state = _LifecycleState.STOPPING
	_active_operation_stop_requested = true
	_flow_serial += 1
	_restore_pending_actions_on_cancel = not should_clear_actions
	_is_running = false
	var stopped_context: GFTurnContext = _context
	_lifecycle_state = _LifecycleState.STOPPED
	flow_stopped.emit(stopped_context)


## 销毁系统，撤销所有在途 operation，并拒绝后续启动、阶段推进、行动入队与行动解析。
## 在途 continuation 会先完成精确清理，再释放 Context claim。
## [br]
## @api public
## [br]
## @since 11.0.0
func dispose() -> void:
	if _is_disposed:
		return
	_is_disposed = true
	stop(true)
	super.dispose()


## 推进到下一个阶段。
## 若同一 Context 正由其他 Flow generation 持有，本次调用会在清理 actor、修改阶段/轮次或发出阶段信号前失败关闭；最后一张 operation claim 释放后可顺序重试。
## [br]
## @api public
## [br]
## @since 3.17.0
func advance_phase() -> void:
	if _is_disposed:
		return
	if _is_advancing_phase:
		push_warning("[GFTurnFlowSystem][turn_flow_system.advance_during_advance] advance_phase failed: a phase is being advanced.")
		return
	if _phases.is_empty():
		return
	if not _is_running:
		start(false)
	if not _is_running or _is_advancing_phase:
		return
	var flow_serial: int = _flow_serial
	var active_context: GFTurnContext = _context
	var phase_lease: GFTurnContext.FlowOperationLease = _acquire_context_operation_lease(
		active_context,
		flow_serial
	)
	if phase_lease == null:
		push_warning("[GFTurnFlowSystem][turn_flow_system.advance_context_held] advance_phase failed: context is held by another flow generation.")
		return
	_is_advancing_phase = true
	_active_operation_stop_requested = false

	var next_phase: Dictionary = _next_valid_phase()
	if next_phase.is_empty():
		_end_phase_advance(null, active_context, null, phase_lease)
		return
	var next_phase_index: int = GFVariantData.get_option_int(next_phase, "index")
	var phase: GFTurnPhase = _phases[next_phase_index]
	if phase == null:
		_end_phase_advance(null, active_context, null, phase_lease)
		return
	var phase_runtime: GFTurnPhase.RuntimeState = phase.begin_runtime(
		active_context,
		phase_lease,
		self,
		flow_serial
	)
	if phase_runtime == null:
		_end_phase_advance(null, active_context, null, phase_lease)
		return
	var _cleanup_before_phase: int = active_context.cleanup_invalid_actors_from_flow(
		phase_lease,
		self,
		flow_serial
	)
	_current_phase_index = next_phase_index
	if GFVariantData.get_option_bool(next_phase, "wrapped"):
		active_context.advance_round_from_flow(phase_lease, self, flow_serial)

	phase_changed.emit(phase, _current_phase_index)
	if not _is_active_context_operation_lease(phase_lease, flow_serial, active_context):
		_end_phase_advance(phase, active_context, phase_runtime, phase_lease)
		return
	var _cleanup_after_phase_signal: int = active_context.cleanup_invalid_actors_from_flow(
		phase_lease,
		self,
		flow_serial
	)
	phase._enter(active_context)
	if not _is_active_context_operation_lease(phase_lease, flow_serial, active_context):
		_end_phase_advance(phase, active_context, phase_runtime, phase_lease)
		return

	var result: Variant = phase._execute(
		active_context,
		phase_runtime.get_completion_handle()
	)
	if not _is_active_context_operation_lease(phase_lease, flow_serial, active_context):
		_end_phase_advance(phase, active_context, phase_runtime, phase_lease)
		return
	if result is Signal:
		var result_signal: Signal = result
		var completed: bool = await _await_signal_safely(
			result_signal,
			Callable(self, "_is_active_context_operation_lease").bind(
				phase_lease,
				flow_serial,
				active_context
			),
			"[GFTurnFlowSystem][turn_flow_system.phase_signal_timeout] Waiting for the phase Signal timed out; phase advancement was aborted."
		)
		if (
			not completed
			or not _is_active_context_operation_lease(phase_lease, flow_serial, active_context)
		):
			_end_phase_advance(phase, active_context, phase_runtime, phase_lease)
			return
	if phase.auto_finish:
		var _auto_completed: bool = phase_runtime.try_complete_from_flow()
	if not _is_active_context_operation_lease(phase_lease, flow_serial, active_context):
		_end_phase_advance(phase, active_context, phase_runtime, phase_lease)
		return
	if not phase_runtime.is_finished:
		var completed: bool = await _await_signal_safely(
			phase_runtime.finished,
			Callable(self, "_is_active_context_operation_lease").bind(
				phase_lease,
				flow_serial,
				active_context
			),
			"[GFTurnFlowSystem][turn_flow_system.phase_completion_timeout] Waiting for phase completion timed out; phase advancement was aborted."
		)
		if (
			not completed
			or not _is_active_context_operation_lease(phase_lease, flow_serial, active_context)
		):
			_end_phase_advance(phase, active_context, phase_runtime, phase_lease)
			return
	phase._exit(active_context)
	_end_phase_advance(phase, active_context, phase_runtime, phase_lease)


## 获取待处理行动的只读快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return: 当前待处理行动数组副本。
func get_actions() -> Array[GFTurnAction]:
	return _actions.duplicate()


## 获取待处理行动数量。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return: 当前待处理行动数量。
func get_action_count() -> int:
	return _actions.size()


## 清空待处理行动并封存这些一次性实例。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear_actions() -> void:
	if _is_resolving_actions:
		push_warning("[GFTurnFlowSystem][turn_flow_system.clear_during_resolution] clear_actions failed: actions are being resolved; call stop(true).")
		return
	_clear_actions_internal()


## 加入一个行动。
## [br]
## @api public
## [br]
## @param action: 行动实例。
func enqueue_action(action: GFTurnAction) -> void:
	if _is_disposed:
		return
	if action == null:
		return
	if not action.claim_for_queue():
		push_warning("[GFTurnFlowSystem][turn_flow_system.action_already_enqueued] enqueue_action failed: an action instance can be enqueued only once.")
		return
	_ensure_action_order(action)
	_actions.append(action)
	action_enqueued.emit(action)


## 解析当前上下文中的所有行动。
## 若同一 Context 正由其他 Flow generation 持有，本次调用会在清理 actor、取走队列、写入 current_actor 或调用 action 前失败关闭；最后一张 operation claim 释放后可顺序重试。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param order_resolver: 可选排序回调，签名为 func(a, b) -> bool；调用方必须提供无副作用、确定且满足严格弱序的比较器。自定义比较器不继承默认 non-finite 与入队顺序规则；若回调使当前 operation 失效，框架会停止后续调用，并按排序前快照恢复或封存队列。
func resolve_actions(order_resolver: Callable = Callable()) -> void:
	if _is_disposed:
		return
	if _is_resolving_actions:
		push_warning("[GFTurnFlowSystem][turn_flow_system.resolution_active] resolve_actions failed: actions are being resolved.")
		return

	var flow_serial: int = _flow_serial
	var active_context: GFTurnContext = _context
	var action_lease: GFTurnContext.FlowOperationLease = _acquire_context_operation_lease(
		active_context,
		flow_serial
	)
	if action_lease == null:
		push_warning("[GFTurnFlowSystem][turn_flow_system.resolve_context_held] resolve_actions failed: context is held by another flow generation.")
		return
	var pending_actions: Array[GFTurnAction] = _actions.duplicate()
	var original_pending_actions: Array[GFTurnAction] = pending_actions.duplicate()
	_actions.clear()
	_is_resolving_actions = true
	_active_operation_stop_requested = false
	var _cleanup_invalid_actors_result: int = active_context.cleanup_invalid_actors_from_flow(
		action_lease,
		self,
		flow_serial
	)
	for action: GFTurnAction in pending_actions:
		_ensure_action_order(action)

	if sort_actions_before_resolve:
		if order_resolver.is_valid():
			var comparator_state: Dictionary = {"is_active": true}
			pending_actions.sort_custom(
				Callable(self, "_sort_action_with_operation_guard").bind(
					order_resolver,
					comparator_state,
					action_lease,
					flow_serial,
					active_context
				)
			)
		else:
			pending_actions.sort_custom(_sort_action_desc)
	if not _is_context_operation_lease_current(action_lease, flow_serial, active_context):
		_restore_unresolved_actions(original_pending_actions, 0)
		_finish_action_resolution(active_context, action_lease)
		return

	var action_index: int = 0
	while action_index < pending_actions.size():
		var action: GFTurnAction = pending_actions[action_index]
		if not _is_context_operation_lease_current(action_lease, flow_serial, active_context):
			_restore_unresolved_actions(pending_actions, action_index)
			break
		if action == null or action.is_cancelled or _action_has_invalid_actor(action):
			_consume_action(action)
			action_index += 1
			continue
		_inject_action(action)
		if not _is_context_operation_lease_current(action_lease, flow_serial, active_context):
			_restore_unresolved_actions(pending_actions, action_index)
			break
		if action == null or action.is_cancelled or _action_has_invalid_actor(action):
			_consume_action(action)
			action_index += 1
			continue
		action.replace_runtime_targets(action.targets)
		if not _is_context_operation_lease_current(action_lease, flow_serial, active_context):
			_restore_unresolved_actions(pending_actions, action_index)
			break
		active_context.set_current_actor_from_flow(
			_variant_to_valid_object(action.actor),
			action_lease,
			self,
			flow_serial
		)
		if not _is_context_operation_lease_current(action_lease, flow_serial, active_context):
			_restore_unresolved_actions(pending_actions, action_index)
			break
		var result: Variant = action._resolve(active_context)
		if result is Signal:
			var result_signal: Signal = result
			var completed: bool = await _await_signal_safely(
				result_signal,
				Callable(self, "_is_context_operation_lease_current").bind(
					action_lease,
					flow_serial,
					active_context
				),
				"[GFTurnFlowSystem][turn_flow_system.action_signal_timeout] Waiting for the action Signal timed out; the current action was skipped."
			)
			if not _is_context_operation_lease_current(action_lease, flow_serial, active_context):
				_restore_unresolved_actions(pending_actions, action_index)
				break
			if not completed:
				_consume_action(action)
				action_index += 1
				continue
		if not _is_context_operation_lease_current(action_lease, flow_serial, active_context):
			_consume_action(action)
			_restore_unresolved_actions(pending_actions, action_index + 1)
			break
		if action == null or action.is_cancelled or _action_has_invalid_actor(action):
			_consume_action(action)
			action_index += 1
			continue
		_consume_action(action)
		action_resolved.emit(action)
		action_index += 1

	_finish_action_resolution(active_context, action_lease)


# --- 私有/辅助方法 ---

## 按优先级、规范化次排序值及首次入队顺序作降序比较。
## [br]
## @api private
## [br]
func _sort_action_desc(a: GFTurnAction, b: GFTurnAction) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	var a_sort_value: float = _normalized_action_sort_value(a)
	var b_sort_value: float = _normalized_action_sort_value(b)
	if a_sort_value != b_sort_value:
		return a_sort_value > b_sort_value
	return _get_action_order(a) < _get_action_order(b)


## 只在 operation lease 有效前后调用自定义比较器，并停用失效的比较状态。
## [br]
## @api private
## [br]
func _sort_action_with_operation_guard(
	a: GFTurnAction,
	b: GFTurnAction,
	order_resolver: Callable,
	comparator_state: Dictionary,
	lease: GFTurnContext.FlowOperationLease,
	flow_serial: int,
	active_context: GFTurnContext
) -> bool:
	if (
		not GFVariantData.get_option_bool(comparator_state, "is_active")
		or not _is_context_operation_lease_current(lease, flow_serial, active_context)
	):
		comparator_state["is_active"] = false
		return false
	var result: Variant = order_resolver.call(a, b)
	if not _is_context_operation_lease_current(lease, flow_serial, active_context):
		comparator_state["is_active"] = false
		return false
	return result is bool and result


## 从当前索引向前环绕查找下一项非 null 阶段，并返回索引与是否已环绕。
## [br]
## @api private
## [br]
func _next_valid_phase() -> Dictionary:
	var next_index: int = _current_phase_index
	var wrapped: bool = false
	for _step: int in range(_phases.size()):
		next_index = (next_index + 1) % _phases.size()
		if next_index == 0:
			wrapped = true
		var phase: GFTurnPhase = _phases[next_index]
		if phase == null:
			push_warning("[GFTurnFlowSystem][turn_flow_system.empty_advance_phase] advance_phase skipped a null phase.")
			continue
		return {
			"index": next_index,
			"wrapped": wrapped,
		}
	return {}


## 为尚无缓存顺序的行动分配下一个入队顺序号。
## [br]
## @api private
## [br]
func _ensure_action_order(action: GFTurnAction) -> void:
	if action == null:
		return
	var instance_key: int = action.get_instance_id()
	if _action_order_by_instance_id.has(instance_key):
		return
	_action_order_by_instance_id[instance_key] = _next_action_order
	_next_action_order += 1


## 查询行动缓存的入队顺序；空行动或未登记时返回 0。
## [br]
## @api private
## [br]
func _get_action_order(action: GFTurnAction) -> int:
	if action == null:
		return 0
	return GFVariantData.get_option_int(_action_order_by_instance_id, action.get_instance_id(), 0)


## 从入队顺序缓存移除行动实例。
## [br]
## @api private
## [br]
func _forget_action_order(action: GFTurnAction) -> void:
	if action == null:
		return
	var _erased_order: bool = _action_order_by_instance_id.erase(action.get_instance_id())


## 清空所有行动顺序记录并重置下一个顺序号。
## [br]
## @api private
## [br]
func _clear_action_order_cache() -> void:
	_action_order_by_instance_id.clear()
	_next_action_order = 0


## 封存队列中的行动，清空队列和顺序缓存。
## [br]
## @api private
## [br]
func _clear_actions_internal() -> void:
	for action: GFTurnAction in _actions:
		_consume_action(action)
	_actions.clear()
	_clear_action_order_cache()


## 移除行动的顺序缓存项，并在行动非空时将其封存。
## [br]
## @api private
## [br]
func _consume_action(action: GFTurnAction) -> void:
	_forget_action_order(action)
	if action != null:
		action.seal_after_queue()


## 按取消恢复开关处理 pending_actions 从 start_index 起的未解析后缀。
## [br]
## @api private
## [br]
func _restore_unresolved_actions(pending_actions: Array[GFTurnAction], start_index: int) -> void:
	if not _restore_pending_actions_on_cancel:
		for index: int in range(start_index, pending_actions.size()):
			_consume_action(pending_actions[index])
		return
	var restored: Array[GFTurnAction] = []
	for index: int in range(start_index, pending_actions.size()):
		var action: GFTurnAction = pending_actions[index]
		if action == null or action.is_cancelled or _action_has_invalid_actor(action):
			_consume_action(action)
			continue
		if _actions.has(action):
			continue
		restored.append(action)
	for index: int in range(restored.size() - 1, -1, -1):
		_actions.push_front(restored[index])


## 行动为空或其 actor 是已释放对象时返回 true；非 Object actor 不视为失效。
## [br]
## @api private
## [br]
func _action_has_invalid_actor(action: GFTurnAction) -> bool:
	if action == null:
		return true
	var actor_value: Variant = action.actor
	if typeof(actor_value) != TYPE_OBJECT:
		return false
	return not is_instance_valid(actor_value)


## 仅将当前仍有效的 Object Variant 转为 Object，其余输入返回 null。
## [br]
## @api private
## [br]
func _variant_to_valid_object(value: Variant) -> Object:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	var object_value: Object = value
	return object_value


## 从系统取得架构，并在架构可用时向行动注入依赖。
## [br]
## @api private
## [br]
func _inject_action(action: GFTurnAction) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return
	action.inject_dependencies_from_flow(architecture)


## 空行动或非有限 sort_value 统一映射为 -INF。
## [br]
## @api private
## [br]
func _normalized_action_sort_value(action: GFTurnAction) -> float:
	if action == null:
		return -INF
	var value: float = action.sort_value
	if is_nan(value) or is_inf(value):
		return -INF
	return value


## 使用配置的 TimeUtility 和超时参数委托给安全 Signal 等待器。
## [br]
## @api private
## [br]
func _await_signal_safely(result_signal: Signal, should_continue: Callable, timeout_warning: String) -> bool:
	return await _GF_ASYNC_WAIT_SUPPORT.await_signal_safely(
		result_signal,
		should_continue,
		_get_time_utility(),
		signal_timeout_seconds,
		signal_timeout_respects_time_scale,
		timeout_warning
	)


## 从系统取得 GFTimeUtility；依赖缺失或类型不符时返回 null。
## [br]
## @api private
## [br]
func _get_time_utility() -> GFTimeUtility:
	var utility_value: Variant = get_utility(GFTimeUtility)
	if utility_value is GFTimeUtility:
		var utility: GFTimeUtility = utility_value
		return utility
	return null


## 结束阶段运行态，更新推进/停止标志并释放阶段操作租约。
## [br]
## @api private
## [br]
func _end_phase_advance(
	phase: GFTurnPhase,
	active_context: GFTurnContext,
	phase_runtime: GFTurnPhase.RuntimeState,
	phase_lease: GFTurnContext.FlowOperationLease
) -> void:
	if phase != null:
		phase.end_runtime(active_context, phase_runtime)
	_is_advancing_phase = false
	if not _is_resolving_actions:
		_active_operation_stop_requested = false
	_release_context_operation_lease(active_context, phase_lease)


## 清除当前 actor，重置行动解析状态并释放行动操作租约。
## [br]
## @api private
## [br]
func _finish_action_resolution(
	active_context: GFTurnContext,
	action_lease: GFTurnContext.FlowOperationLease
) -> void:
	if active_context != null:
		active_context.clear_current_actor_from_flow(action_lease, self)
	_is_resolving_actions = false
	_restore_pending_actions_on_cancel = false
	if not _is_advancing_phase:
		_active_operation_stop_requested = false
	_release_context_operation_lease(active_context, action_lease)


## 向 Context 申请操作租约，并在成功后登记到本系统的活动租约列表。
## [br]
## @api private
## [br]
func _acquire_context_operation_lease(
	active_context: GFTurnContext,
	flow_serial: int
) -> GFTurnContext.FlowOperationLease:
	if active_context == null:
		return null
	var lease: GFTurnContext.FlowOperationLease = (
		active_context.try_acquire_flow_operation_lease(self, flow_serial)
	)
	if lease != null:
		_active_context_operation_leases.append(lease)
	return lease


## 逐一请求 Context 撤销当前登记租约的正常写入权限。
## [br]
## @api private
## [br]
func _cancel_active_context_operation_leases() -> void:
	for lease: GFTurnContext.FlowOperationLease in _active_context_operation_leases.duplicate():
		if lease == null:
			continue
		var _cancelled: bool = _context.cancel_flow_operation_lease(lease, self)


## 向 Context 释放租约、移除本地登记，并尝试重放等待中的 start 请求。
## [br]
## @api private
## [br]
func _release_context_operation_lease(
	active_context: GFTurnContext,
	lease: GFTurnContext.FlowOperationLease
) -> void:
	if lease == null:
		return
	if active_context != null:
		var _released: bool = active_context.release_flow_operation_lease(lease, self)
	_active_context_operation_leases.erase(lease)
	_try_replay_pending_start_request()


## 清除待重放 start 请求，并恢复 reset_indices 的默认值。
## [br]
## @api private
## [br]
func _clear_pending_start_request() -> void:
	_has_pending_start_request = false
	_pending_start_reset_indices = true


## 仅在流程完全停止、没有回调推进或未结算操作租约时重放待启动请求；调用 start 前先清除请求。
## [br]
## @api private
func _try_replay_pending_start_request() -> void:
	if (
		not _has_pending_start_request
		or _is_disposed
		or _is_notifying_flow_started
		or _lifecycle_state != _LifecycleState.STOPPED
		or _is_advancing_phase
		or _is_resolving_actions
		or not _active_context_operation_leases.is_empty()
	):
		return
	var reset_indices: bool = _pending_start_reset_indices
	_clear_pending_start_request()
	start(reset_indices)


## 校验 generation、Context 身份及 Context 对该租约的活动状态。
## [br]
## @api private
## [br]
func _is_context_operation_lease_current(
	lease: GFTurnContext.FlowOperationLease,
	serial: int,
	active_context: GFTurnContext
) -> bool:
	return (
		serial == _flow_serial
		and active_context == _context
		and active_context != null
		and active_context.is_flow_operation_lease_active(lease, self, serial)
	)


## 仅在系统未 dispose、仍运行且租约仍当前时返回 true。
## [br]
## @api private
## [br]
func _is_active_context_operation_lease(
	lease: GFTurnContext.FlowOperationLease,
	serial: int,
	active_context: GFTurnContext
) -> bool:
	return (
		not _is_disposed
		and _is_running
		and _is_context_operation_lease_current(lease, serial, active_context)
	)
