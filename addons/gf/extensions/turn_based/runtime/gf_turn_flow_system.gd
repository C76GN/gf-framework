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


# --- 公共方法 ---

## 设置上下文。
## [br]
## @api public
## [br]
## @param p_context: 新上下文。
func set_context(p_context: GFTurnContext) -> void:
	if _is_advancing_phase or _is_resolving_actions:
		push_warning("[GFTurnFlowSystem] set_context 失败：流程正在推进或解析中。")
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
## [br]
## @api public
## [br]
## @param reset_indices: 是否重置阶段索引和轮次数据。
func start(reset_indices: bool = true) -> void:
	if _lifecycle_state == _LifecycleState.STARTING or _lifecycle_state == _LifecycleState.RUNNING:
		return
	if _lifecycle_state == _LifecycleState.STOPPING:
		return
	if _is_advancing_phase or _is_resolving_actions:
		push_warning("[GFTurnFlowSystem] start 失败：流程正在推进或解析中。")
		return
	_lifecycle_state = _LifecycleState.STARTING
	if reset_indices:
		_current_phase_index = -1
		_context.reset_round_from_flow()
	_flow_serial += 1
	_restore_pending_actions_on_cancel = false
	_active_operation_stop_requested = false
	_is_running = true
	_lifecycle_state = _LifecycleState.RUNNING
	flow_started.emit(_context)


## 停止流程。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param should_clear_actions: 是否清空待处理行动。
func stop(should_clear_actions: bool = true) -> void:
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
	if should_clear_actions:
		_clear_actions_internal()
	_is_running = false
	var stopped_context: GFTurnContext = _context
	_lifecycle_state = _LifecycleState.STOPPED
	flow_stopped.emit(stopped_context)


## 推进到下一个阶段。
## [br]
## @api public
func advance_phase() -> void:
	if _is_advancing_phase:
		push_warning("[GFTurnFlowSystem] advance_phase 失败：阶段正在推进中。")
		return
	if _phases.is_empty():
		return
	if not _is_running:
		start(false)
	if not _is_running:
		return
	_is_advancing_phase = true
	_active_operation_stop_requested = false
	var flow_serial: int = _flow_serial
	var active_context: GFTurnContext = _context
	var _cleanup_before_phase: int = active_context.cleanup_invalid_actors()

	var next_phase: Dictionary = _next_valid_phase()
	if next_phase.is_empty():
		_is_advancing_phase = false
		return
	_current_phase_index = GFVariantData.get_option_int(next_phase, "index")
	if GFVariantData.get_option_bool(next_phase, "wrapped"):
		active_context.advance_round_from_flow()

	var phase: GFTurnPhase = _phases[_current_phase_index]
	if phase == null:
		_is_advancing_phase = false
		return
	var phase_runtime: GFTurnPhase.RuntimeState = phase.begin_runtime(active_context)
	if phase_runtime == null:
		_is_advancing_phase = false
		return

	phase_changed.emit(phase, _current_phase_index)
	if not _is_active_context_lease(flow_serial, active_context):
		_end_phase_advance(phase, active_context, phase_runtime)
		return
	var _cleanup_after_phase_signal: int = active_context.cleanup_invalid_actors()
	phase._enter(active_context)
	if not _is_active_context_lease(flow_serial, active_context):
		_end_phase_advance(phase, active_context, phase_runtime)
		return

	var result: Variant = phase._execute(active_context)
	if not _is_active_context_lease(flow_serial, active_context):
		_end_phase_advance(phase, active_context, phase_runtime)
		return
	if result is Signal:
		var result_signal: Signal = result
		var completed: bool = await _await_signal_safely(
			result_signal,
			Callable(self, "_is_active_context_lease").bind(flow_serial, active_context),
			"[GFTurnFlowSystem] 等待阶段 Signal 超时，阶段推进已中止。"
		)
		if not completed or not _is_active_context_lease(flow_serial, active_context):
			_end_phase_advance(phase, active_context, phase_runtime)
			return
	if phase.auto_finish:
		phase_runtime.finish()
	if not _is_active_context_lease(flow_serial, active_context):
		_end_phase_advance(phase, active_context, phase_runtime)
		return
	if not phase_runtime.is_finished:
		var completed: bool = await _await_signal_safely(
			phase_runtime.finished,
			Callable(self, "_is_active_context_lease").bind(flow_serial, active_context),
			"[GFTurnFlowSystem] 等待阶段完成超时，阶段推进已中止。"
		)
		if not completed or not _is_active_context_lease(flow_serial, active_context):
			_end_phase_advance(phase, active_context, phase_runtime)
			return
	phase._exit(active_context)
	_end_phase_advance(phase, active_context, phase_runtime)


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
	if action == null:
		return
	if not action.claim_for_queue():
		push_warning("[GFTurnFlowSystem] enqueue_action 失败：action 实例只能入队一次。")
		return
	_ensure_action_order(action)
	_actions.append(action)
	action_enqueued.emit(action)


## 解析当前上下文中的所有行动。
## [br]
## @api public
## [br]
## @param order_resolver: 可选排序回调，签名为 func(a, b) -> bool。
func resolve_actions(order_resolver: Callable = Callable()) -> void:
	if _is_resolving_actions:
		push_warning("[GFTurnFlowSystem] resolve_actions 失败：行动正在解析中。")
		return

	var flow_serial: int = _flow_serial
	var active_context: GFTurnContext = _context
	var pending_actions: Array[GFTurnAction] = _actions.duplicate()
	_actions.clear()
	_is_resolving_actions = true
	_active_operation_stop_requested = false
	var _cleanup_invalid_actors_result: int = active_context.cleanup_invalid_actors()
	for action: GFTurnAction in pending_actions:
		_ensure_action_order(action)

	if sort_actions_before_resolve:
		if order_resolver.is_valid():
			pending_actions.sort_custom(order_resolver)
		else:
			pending_actions.sort_custom(_sort_action_desc)
	if not _is_context_lease_current(flow_serial, active_context):
		_restore_unresolved_actions(pending_actions, 0)
		_finish_action_resolution(active_context)
		return

	var action_index: int = 0
	while action_index < pending_actions.size():
		var action: GFTurnAction = pending_actions[action_index]
		if not _is_context_lease_current(flow_serial, active_context):
			_restore_unresolved_actions(pending_actions, action_index)
			break
		if action == null or action.is_cancelled or _action_has_invalid_actor(action):
			_consume_action(action)
			action_index += 1
			continue
		_inject_action(action)
		_sanitize_action_targets(action)
		active_context.set_current_actor_from_flow(_variant_to_valid_object(action.actor))
		var result: Variant = action._resolve(active_context)
		if result is Signal:
			var result_signal: Signal = result
			var completed: bool = await _await_signal_safely(
				result_signal,
				Callable(self, "_is_context_lease_current").bind(flow_serial, active_context),
				"[GFTurnFlowSystem] 等待行动 Signal 超时，当前行动已跳过。"
			)
			if not _is_context_lease_current(flow_serial, active_context):
				_restore_unresolved_actions(pending_actions, action_index)
				break
			if not completed:
				_consume_action(action)
				action_index += 1
				continue
		if not _is_context_lease_current(flow_serial, active_context):
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

	_finish_action_resolution(active_context)


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


func _sanitize_action_targets(action: GFTurnAction) -> void:
	if action == null:
		return
	var valid_targets: Array[Object] = []
	for target_value: Variant in action.targets:
		var target: Object = _variant_to_valid_object(target_value)
		if target == null:
			continue
		if not valid_targets.has(target):
			valid_targets.append(target)
	action.replace_runtime_targets(valid_targets)


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
	phase_runtime: GFTurnPhase.RuntimeState
) -> void:
	if phase != null:
		phase.end_runtime(active_context, phase_runtime)
	_is_advancing_phase = false
	_active_operation_stop_requested = false


func _finish_action_resolution(active_context: GFTurnContext) -> void:
	if active_context != null:
		active_context.set_current_actor_from_flow(null)
	_is_resolving_actions = false
	_restore_pending_actions_on_cancel = false
	_active_operation_stop_requested = false


func _is_context_lease_current(serial: int, active_context: GFTurnContext) -> bool:
	return serial == _flow_serial and active_context == _context


func _is_active_context_lease(serial: int, active_context: GFTurnContext) -> bool:
	return _is_running and _is_context_lease_current(serial, active_context)
