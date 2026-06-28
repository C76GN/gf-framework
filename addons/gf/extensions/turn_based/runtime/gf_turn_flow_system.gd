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


# --- 公共变量 ---

## 当前回合上下文。
## [br]
## @api public
var context: GFTurnContext = GFTurnContext.new()

## 阶段列表。
## [br]
## @api public
var phases: Array[GFTurnPhase] = []

## 当前阶段索引。
## [br]
## @api public
var current_phase_index: int = -1

## 当前是否正在运行。
## [br]
## @api public
var is_running: bool = false

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
var _next_action_order: int = 0
var _action_order_by_instance_id: Dictionary = {}
var _restore_pending_actions_on_cancel: bool = false


# --- 公共方法 ---

## 设置上下文。
## [br]
## @api public
## [br]
## @param p_context: 新上下文。
func set_context(p_context: GFTurnContext) -> void:
	context = p_context if p_context != null else GFTurnContext.new()


## 设置阶段列表。
## [br]
## @api public
## [br]
## @param p_phases: 新阶段列表。
func set_phases(p_phases: Array[GFTurnPhase]) -> void:
	phases.clear()
	for phase: GFTurnPhase in p_phases:
		if phase == null:
			push_warning("[GFTurnFlowSystem] set_phases 跳过空阶段。")
			continue
		phases.append(phase)


## 开始流程。
## [br]
## @api public
## [br]
## @param reset_indices: 是否重置阶段索引和轮次数据。
func start(reset_indices: bool = true) -> void:
	if reset_indices:
		current_phase_index = -1
		context.round_index = 0
	_flow_serial += 1
	_restore_pending_actions_on_cancel = false
	is_running = true
	flow_started.emit(context)


## 停止流程。
## [br]
## @api public
## [br]
## @param clear_actions: 是否清空待处理行动。
func stop(clear_actions: bool = true) -> void:
	_flow_serial += 1
	_restore_pending_actions_on_cancel = not clear_actions
	if clear_actions:
		context.clear_actions()
	is_running = false
	flow_stopped.emit(context)


## 推进到下一个阶段。
## [br]
## @api public
func advance_phase() -> void:
	if _is_advancing_phase:
		push_warning("[GFTurnFlowSystem] advance_phase 失败：阶段正在推进中。")
		return
	if not is_running:
		start(false)
	if phases.is_empty():
		return
	_is_advancing_phase = true
	var flow_serial: int = _flow_serial

	var next_phase: Dictionary = _next_valid_phase()
	if next_phase.is_empty():
		_is_advancing_phase = false
		return
	current_phase_index = GFVariantData.get_option_int(next_phase, "index")
	if GFVariantData.get_option_bool(next_phase, "wrapped"):
		context.round_index += 1

	var phase: GFTurnPhase = phases[current_phase_index]
	if phase == null:
		_is_advancing_phase = false
		return

	phase.reset()
	phase_changed.emit(phase, current_phase_index)
	if not _is_active_flow_serial(flow_serial):
		_is_advancing_phase = false
		return
	phase._enter(context)
	if not _is_active_flow_serial(flow_serial):
		_is_advancing_phase = false
		return

	var result: Variant = phase._execute(context)
	if result is Signal:
		var result_signal: Signal = result
		var completed: bool = await _await_signal_safely(
			result_signal,
			Callable(self, "_is_active_flow_serial").bind(flow_serial),
			"[GFTurnFlowSystem] 等待阶段 Signal 超时，阶段推进已中止。"
		)
		if not completed or not _is_active_flow_serial(flow_serial):
			_is_advancing_phase = false
			return
	if phase.auto_finish:
		phase.finish()
	if not _is_active_flow_serial(flow_serial):
		_is_advancing_phase = false
		return
	if not phase.is_finished:
		var completed: bool = await _await_signal_safely(
			phase.finished,
			Callable(self, "_is_active_flow_serial").bind(flow_serial),
			"[GFTurnFlowSystem] 等待阶段完成超时，阶段推进已中止。"
		)
		if not completed or not _is_active_flow_serial(flow_serial):
			_is_advancing_phase = false
			return
	phase._exit(context)
	_is_advancing_phase = false


## 加入一个行动。
## [br]
## @api public
## [br]
## @param action: 行动实例。
func enqueue_action(action: GFTurnAction) -> void:
	if action == null:
		return
	_ensure_action_order(action)
	context.actions.append(action)
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
	var pending_actions: Array[GFTurnAction] = context.actions.duplicate()
	context.actions.clear()
	_is_resolving_actions = true
	for action: GFTurnAction in pending_actions:
		_ensure_action_order(action)

	if sort_actions_before_resolve:
		if order_resolver.is_valid():
			pending_actions.sort_custom(order_resolver)
		else:
			pending_actions.sort_custom(_sort_action_desc)

	var action_index: int = 0
	while action_index < pending_actions.size():
		var action: GFTurnAction = pending_actions[action_index]
		if not _is_flow_serial_current(flow_serial):
			_restore_unresolved_actions(pending_actions, action_index)
			break
		if action == null or action.is_cancelled or _action_has_invalid_actor(action):
			_forget_action_order(action)
			action_index += 1
			continue
		_inject_action(action)
		_sanitize_action_targets(action)
		context.current_actor = _variant_to_valid_object(action.actor)
		var result: Variant = action._resolve(context)
		if result is Signal:
			var result_signal: Signal = result
			var completed: bool = await _await_signal_safely(
				result_signal,
				Callable(self, "_is_flow_serial_current").bind(flow_serial),
				"[GFTurnFlowSystem] 等待行动 Signal 超时，当前行动已跳过。"
			)
			if not _is_flow_serial_current(flow_serial):
				_restore_unresolved_actions(pending_actions, action_index + 1)
				break
			if not completed:
				_forget_action_order(action)
				action_index += 1
				continue
		if not _is_flow_serial_current(flow_serial):
			_restore_unresolved_actions(pending_actions, action_index + 1)
			break
		action_resolved.emit(action)
		_forget_action_order(action)
		action_index += 1

	context.current_actor = null
	_is_resolving_actions = false
	_restore_pending_actions_on_cancel = false


# --- 私有/辅助方法 ---

func _sort_action_desc(a: GFTurnAction, b: GFTurnAction) -> bool:
	if a.priority != b.priority:
		return a.priority > b.priority
	if a.sort_value != b.sort_value:
		return a.sort_value > b.sort_value
	return _get_action_order(a) < _get_action_order(b)


func _next_valid_phase() -> Dictionary:
	var next_index: int = current_phase_index
	var wrapped: bool = false
	for _step: int in range(phases.size()):
		next_index = (next_index + 1) % phases.size()
		if next_index == 0:
			wrapped = true
		var phase: GFTurnPhase = phases[next_index]
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


func _restore_unresolved_actions(pending_actions: Array[GFTurnAction], start_index: int) -> void:
	if not _restore_pending_actions_on_cancel:
		return
	var restored: Array[GFTurnAction] = []
	for index: int in range(start_index, pending_actions.size()):
		var action: GFTurnAction = pending_actions[index]
		if action == null or action.is_cancelled:
			_forget_action_order(action)
			continue
		if context.actions.has(action):
			continue
		restored.append(action)
	for index: int in range(restored.size() - 1, -1, -1):
		context.actions.push_front(restored[index])


func _action_has_invalid_actor(action: GFTurnAction) -> bool:
	if action == null:
		return true
	return action.actor != null and not is_instance_valid(action.actor)


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
	action.targets = valid_targets


func _variant_to_valid_object(value: Variant) -> Object:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	var object_value: Object = value
	return object_value


func _inject_action(action: GFTurnAction) -> void:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return
	if action.has_method("inject_dependencies"):
		action.call("inject_dependencies", architecture)
	if action.has_method("inject"):
		action.call("inject", architecture)


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


func _is_flow_serial_current(serial: int) -> bool:
	return serial == _flow_serial


func _is_active_flow_serial(serial: int) -> bool:
	return is_running and serial == _flow_serial
