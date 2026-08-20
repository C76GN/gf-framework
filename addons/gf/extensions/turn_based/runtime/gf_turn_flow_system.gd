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


# --- 常量 ---

const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")

enum _LifecycleState {
	STOPPED,
	STARTING,
	RUNNING,
	STOPPING,
}


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

var _flow_serial: int = 0
var _is_advancing_phase: bool = false
var _is_resolving_actions: bool = false
var _context: GFTurnContext = GFTurnContext.new()
var _phases: Array[GFTurnPhase] = []
var _current_phase_index: int = -1
var _is_running: bool = false
var _actions: Array[GFTurnAction] = []
var _next_action_order: int = 0
var _action_order_by_instance_id: Dictionary = {}
var _restore_pending_actions_on_cancel: bool = false
var _lifecycle_state: int = _LifecycleState.STOPPED
var _active_operation_stop_requested: bool = false
var _active_context_operation_leases: Array[GFTurnContext.FlowOperationLease] = []
var _is_notifying_flow_started: bool = false
var _has_pending_start_request: bool = false
var _pending_start_reset_indices: bool = true
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
		push_warning("[GFTurnFlowSystem] set_context 失败：存在活动 Context operation。")
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
		push_warning("[GFTurnFlowSystem] set_phases 失败：阶段正在推进中。")
		return
	_phases.clear()
	for phase: GFTurnPhase in p_phases:
		if phase == null:
			push_warning("[GFTurnFlowSystem] set_phases 跳过空阶段。")
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
		push_warning("[GFTurnFlowSystem] start 失败：流程正在推进或解析中。")
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
		push_warning("[GFTurnFlowSystem] start 失败：context 正由另一个 flow generation 持有。")
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
## @since unreleased
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
		push_warning("[GFTurnFlowSystem] advance_phase 失败：阶段正在推进中。")
		return
	if _phases.is_empty():
		return
	if not _is_running:
		start(false)
	if not _is_running:
		return
	var flow_serial: int = _flow_serial
	var active_context: GFTurnContext = _context
	var phase_lease: GFTurnContext.FlowOperationLease = _acquire_context_operation_lease(
		active_context,
		flow_serial
	)
	if phase_lease == null:
		push_warning("[GFTurnFlowSystem] advance_phase 失败：context 正由另一个 flow generation 持有。")
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
			"[GFTurnFlowSystem] 等待阶段 Signal 超时，阶段推进已中止。"
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
			"[GFTurnFlowSystem] 等待阶段完成超时，阶段推进已中止。"
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
		push_warning("[GFTurnFlowSystem] clear_actions 失败：行动正在解析中；请调用 stop(true)。")
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
		push_warning("[GFTurnFlowSystem] enqueue_action 失败：action 实例只能入队一次。")
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
## @param order_resolver: 可选排序回调，签名为 func(a, b) -> bool；调用方必须提供无副作用、确定且满足严格弱序的比较器。自定义比较器不继承默认 non-finite 与入队顺序规则。
func resolve_actions(order_resolver: Callable = Callable()) -> void:
	if _is_disposed:
		return
	if _is_resolving_actions:
		push_warning("[GFTurnFlowSystem] resolve_actions 失败：行动正在解析中。")
		return

	var flow_serial: int = _flow_serial
	var active_context: GFTurnContext = _context
	var action_lease: GFTurnContext.FlowOperationLease = _acquire_context_operation_lease(
		active_context,
		flow_serial
	)
	if action_lease == null:
		push_warning("[GFTurnFlowSystem] resolve_actions 失败：context 正由另一个 flow generation 持有。")
		return
	var pending_actions: Array[GFTurnAction] = _actions.duplicate()
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
			pending_actions.sort_custom(order_resolver)
		else:
			pending_actions.sort_custom(_sort_action_desc)
	if not _is_context_operation_lease_current(action_lease, flow_serial, active_context):
		_restore_unresolved_actions(pending_actions, 0)
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
				"[GFTurnFlowSystem] 等待行动 Signal 超时，当前行动已跳过。"
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

func _sort_action_desc(a: GFTurnAction, b: GFTurnAction) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	var a_sort_value: float = _normalized_action_sort_value(a)
	var b_sort_value: float = _normalized_action_sort_value(b)
	if a_sort_value != b_sort_value:
		return a_sort_value > b_sort_value
	return _get_action_order(a) < _get_action_order(b)


func _next_valid_phase() -> Dictionary:
	var next_index: int = _current_phase_index
	var wrapped: bool = false
	for _step: int in range(_phases.size()):
		next_index = (next_index + 1) % _phases.size()
		if next_index == 0:
			wrapped = true
		var phase: GFTurnPhase = _phases[next_index]
		if phase == null:
			push_warning("[GFTurnFlowSystem] advance_phase 跳过空阶段。")
			continue
		return {
			"index": next_index,
			"wrapped": wrapped,
		}
	return {}


func _ensure_action_order(action: GFTurnAction) -> void:
	if action == null:
		return
	var instance_key: int = action.get_instance_id()
	if _action_order_by_instance_id.has(instance_key):
		return
	_action_order_by_instance_id[instance_key] = _next_action_order
	_next_action_order += 1


func _get_action_order(action: GFTurnAction) -> int:
	if action == null:
		return 0
	return GFVariantData.get_option_int(_action_order_by_instance_id, action.get_instance_id(), 0)


func _forget_action_order(action: GFTurnAction) -> void:
	if action == null:
		return
	var _erased_order: bool = _action_order_by_instance_id.erase(action.get_instance_id())


func _clear_action_order_cache() -> void:
	_action_order_by_instance_id.clear()
	_next_action_order = 0


func _clear_actions_internal() -> void:
	for action: GFTurnAction in _actions:
		_consume_action(action)
	_actions.clear()
	_clear_action_order_cache()


func _consume_action(action: GFTurnAction) -> void:
	_forget_action_order(action)
	if action != null:
		action.seal_after_queue()


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


func _action_has_invalid_actor(action: GFTurnAction) -> bool:
	if action == null:
		return true
	var actor_value: Variant = action.actor
	if typeof(actor_value) != TYPE_OBJECT:
		return false
	return not is_instance_valid(actor_value)


func _variant_to_valid_object(value: Variant) -> Object:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	var object_value: Object = value
	return object_value


func _inject_action(action: GFTurnAction) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return
	action.inject_dependencies_from_flow(architecture)


func _normalized_action_sort_value(action: GFTurnAction) -> float:
	if action == null:
		return -INF
	var value: float = action.sort_value
	if is_nan(value) or is_inf(value):
		return -INF
	return value


func _await_signal_safely(result_signal: Signal, should_continue: Callable, timeout_warning: String) -> bool:
	return await _GF_ASYNC_WAIT_SUPPORT.await_signal_safely(
		result_signal,
		should_continue,
		_get_time_utility(),
		signal_timeout_seconds,
		signal_timeout_respects_time_scale,
		timeout_warning
	)


func _get_time_utility() -> GFTimeUtility:
	var utility_value: Variant = get_utility(GFTimeUtility)
	if utility_value is GFTimeUtility:
		var utility: GFTimeUtility = utility_value
		return utility
	return null


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


func _cancel_active_context_operation_leases() -> void:
	for lease: GFTurnContext.FlowOperationLease in _active_context_operation_leases.duplicate():
		if lease == null:
			continue
		var _cancelled: bool = _context.cancel_flow_operation_lease(lease, self)


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


func _clear_pending_start_request() -> void:
	_has_pending_start_request = false
	_pending_start_reset_indices = true


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
