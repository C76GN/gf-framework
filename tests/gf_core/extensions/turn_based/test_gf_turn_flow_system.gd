## 测试通用回合流程系统的阶段推进与行动排序。
extends GutTest


# --- 辅助类 ---

class RecordingPhase extends GFTurnPhase:
	var order: Array[String] = []

	func _init(p_phase_id: StringName, p_order: Array[String]) -> void:
		phase_id = p_phase_id
		order = p_order

	func _enter(_context: GFTurnContext) -> void:
		order.append("enter:%s" % phase_id)

	func _execute(_context: GFTurnContext) -> Variant:
		order.append("execute:%s" % phase_id)
		return null

	func _exit(_context: GFTurnContext) -> void:
		order.append("exit:%s" % phase_id)


class ManualPhase extends GFTurnPhase:
	signal completed

	var order: Array[String] = []

	func _init(p_order: Array[String]) -> void:
		order = p_order
		auto_finish = false

	func _enter(_context: GFTurnContext) -> void:
		order.append("enter")

	func _execute(_context: GFTurnContext) -> Variant:
		order.append("execute")
		return completed

	func _exit(_context: GFTurnContext) -> void:
		order.append("exit")


class RecordingAction extends GFTurnAction:
	var order: Array[String] = []

	func _init(p_label: String, p_priority: int, p_sort_value: float, p_order: Array[String]) -> void:
		action_id = StringName(p_label)
		priority = p_priority
		sort_value = p_sort_value
		order = p_order

	func _resolve(_context: GFTurnContext) -> Variant:
		order.append(String(action_id))
		return null


class ManualAction extends GFTurnAction:
	signal completed

	var order: Array[String] = []

	func _init(p_order: Array[String]) -> void:
		action_id = &"manual"
		order = p_order

	func _resolve(_context: GFTurnContext) -> Variant:
		order.append("resolve")
		return completed


class StopAction extends GFTurnAction:
	var system: GFTurnFlowSystem = null
	var clear_actions: bool = true
	var order: Array[String] = []

	func _init(p_system: GFTurnFlowSystem, p_clear_actions: bool, p_order: Array[String]) -> void:
		action_id = &"stop_action"
		system = p_system
		clear_actions = p_clear_actions
		order = p_order

	func _resolve(_context: GFTurnContext) -> Variant:
		order.append("stop")
		if system != null:
			system.stop(clear_actions)
		return null


class ValueActor extends Object:
	var speed: float = 7.0


# --- 测试方法 ---

## 验证阶段推进会调用 enter/execute/exit 生命周期。
func test_advance_phase_runs_phase_lifecycle() -> void:
	var order: Array[String] = []
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.set_phases([
		RecordingPhase.new(&"prepare", order),
	])

	system.start()
	await system.advance_phase()

	assert_eq(order, [
		"enter:prepare",
		"execute:prepare",
		"exit:prepare",
	], "阶段推进应按生命周期顺序调用。")
	assert_eq(system.context.round_index, 1, "首次进入第 0 阶段应推进轮次。")


## 验证行动默认按 priority 与 sort_value 降序解析。
func test_resolve_actions_sorts_by_priority_and_sort_value() -> void:
	var order: Array[String] = []
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()

	system.enqueue_action(RecordingAction.new("low", 0, 100.0, order))
	system.enqueue_action(RecordingAction.new("fast", 1, 20.0, order))
	system.enqueue_action(RecordingAction.new("slow", 1, 10.0, order))
	await system.resolve_actions()

	assert_eq(order, ["fast", "slow", "low"], "行动应优先按 priority 再按 sort_value 降序解析。")
	assert_true(system.context.actions.is_empty(), "解析后待处理行动应被清空。")
	assert_null(system.context.current_actor, "解析完成后 current_actor 应复位。")


func test_stop_prevents_awaited_phase_from_resuming() -> void:
	var order: Array[String] = []
	var phase: ManualPhase = ManualPhase.new(order)
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.set_phases([phase])

	system.start()
	@warning_ignore("missing_await")
	system.advance_phase()
	await get_tree().process_frame

	system.stop()
	phase.completed.emit()
	await get_tree().process_frame

	assert_eq(order, ["enter", "execute"], "stop 后等待中的阶段不应继续 finish/exit。")


func test_phase_signal_timeout_aborts_without_exit() -> void:
	var order: Array[String] = []
	var phase: ManualPhase = ManualPhase.new(order)
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.signal_timeout_seconds = 0.001
	system.set_phases([phase])

	system.start()
	@warning_ignore("missing_await")
	system.advance_phase()
	await get_tree().create_timer(0.05).timeout
	await get_tree().process_frame

	assert_push_warning("[GFTurnFlowSystem] 等待阶段 Signal 超时，阶段推进已中止。")
	assert_eq(order, ["enter", "execute"], "阶段 Signal 超时后不应继续 finish/exit。")


func test_advance_phase_reentry_is_rejected_while_waiting() -> void:
	var order: Array[String] = []
	var phase: ManualPhase = ManualPhase.new(order)
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.set_phases([phase])

	system.start()
	@warning_ignore("missing_await")
	system.advance_phase()
	await get_tree().process_frame
	@warning_ignore("missing_await")
	system.advance_phase()

	assert_push_warning("[GFTurnFlowSystem] advance_phase 失败：阶段正在推进中。")
	assert_eq(order, ["enter", "execute"], "阶段等待中再次推进不应重复进入同一阶段。")

	system.stop()
	await get_tree().process_frame


func test_phase_changed_stop_prevents_phase_enter() -> void:
	var order: Array[String] = []
	var phase: RecordingPhase = RecordingPhase.new(&"prepare", order)
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.set_phases([phase])
	var _connect_result: Error = system.phase_changed.connect(func(_phase: GFTurnPhase, _index: int) -> void:
		system.stop()
	) as Error

	system.start()
	await system.advance_phase()

	assert_eq(order, [], "phase_changed 中 stop 后不应继续调用新阶段 enter。")


func test_advance_phase_skips_null_phase_entries_safely() -> void:
	var order: Array[String] = []
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.phases = [null, RecordingPhase.new(&"play", order)]

	system.start()
	await system.advance_phase()

	assert_eq(order, [
		"enter:play",
		"execute:play",
		"exit:play",
	], "空阶段条目应被跳过并进入下一个有效阶段。")
	assert_eq(system.context.round_index, 1, "跳过空阶段后首次进入有效阶段仍应推进轮次。")


func test_stop_prevents_awaited_action_from_resuming() -> void:
	var order: Array[String] = []
	var action: ManualAction = ManualAction.new(order)
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.enqueue_action(action)

	@warning_ignore("missing_await")
	system.resolve_actions()
	await get_tree().process_frame

	system.stop()
	action.completed.emit()
	await get_tree().process_frame

	assert_eq(order, ["resolve"], "stop 后等待中的行动不应继续发出 resolved。")
	assert_null(system.context.current_actor, "stop 打断行动解析后 current_actor 应复位。")


func test_sync_action_stop_prevents_resolved_signal() -> void:
	var order: Array[String] = []
	var resolved_count: Array[int] = [0]
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var _connect_result: Error = system.action_resolved.connect(func(_action: GFTurnAction) -> void:
		resolved_count[0] = resolved_count[0] + 1
	) as Error
	system.enqueue_action(StopAction.new(system, true, order))

	await system.resolve_actions()

	assert_eq(order, ["stop"], "同步 stop action 应已执行 resolve。")
	assert_eq(resolved_count[0], 0, "stop 打断后不应再发出 action_resolved。")


func test_stop_without_clearing_restores_unresolved_pending_actions() -> void:
	var order: Array[String] = []
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.enqueue_action(StopAction.new(system, false, order))
	system.enqueue_action(RecordingAction.new("next", 0, 0.0, order))

	await system.resolve_actions()

	assert_eq(order, ["stop"], "stop(false) 后本轮不应继续解析剩余行动。")
	assert_eq(system.context.actions.size(), 1, "stop(false) 应保留尚未解析的行动。")
	assert_eq(String(system.context.actions[0].action_id), "next", "保留的行动应是未解析部分。")


func test_resolve_actions_reentry_is_rejected_while_waiting() -> void:
	var order: Array[String] = []
	var action: ManualAction = ManualAction.new(order)
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.enqueue_action(action)

	@warning_ignore("missing_await")
	system.resolve_actions()
	await get_tree().process_frame
	@warning_ignore("missing_await")
	system.resolve_actions()

	assert_push_warning("[GFTurnFlowSystem] resolve_actions 失败：行动正在解析中。")
	assert_eq(order, ["resolve"], "解析等待中再次调用 resolve_actions 不应重复执行同一批行动。")

	system.stop()
	await get_tree().process_frame


func test_equal_priority_actions_resolve_in_enqueue_order() -> void:
	var order: Array[String] = []
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.enqueue_action(RecordingAction.new("first", 0, 0.0, order))
	system.enqueue_action(RecordingAction.new("second", 0, 0.0, order))
	system.enqueue_action(RecordingAction.new("third", 0, 0.0, order))

	await system.resolve_actions()

	assert_eq(order, ["first", "second", "third"], "priority 与 sort_value 相同时应按入队顺序解析。")


func test_action_constructor_filters_invalid_and_duplicate_targets() -> void:
	var target: Node = Node.new()
	var stale_target: Node = Node.new()
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var action: GFTurnAction = GFTurnAction.new(null, [target, target, null])
	action.targets.append(stale_target)
	stale_target.free()
	system.enqueue_action(action)

	await system.resolve_actions()

	assert_eq(action.targets.size(), 1, "行动目标应过滤 null、重复和已释放对象。")
	assert_eq(action.targets[0], target, "有效目标应保留。")
	target.free()


## 验证上下文可安全读取参与者排序值。
func test_turn_context_reads_actor_value() -> void:
	var actor: ValueActor = ValueActor.new()

	var context: GFTurnContext = GFTurnContext.new()
	context.add_actor(actor)

	assert_eq(GFVariantData.to_float(context.get_actor_value(actor, &"speed")), 7.0, "应能从对象属性读取值。")
	assert_eq(GFVariantData.to_float(context.get_actor_value(null, &"speed", 0.0)), 0.0, "空对象应返回 fallback。")

	actor.free()
