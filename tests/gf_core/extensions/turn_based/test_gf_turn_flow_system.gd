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

	func _execute(
		_context: GFTurnContext,
		_completion: GFTurnPhaseCompletionHandle
	) -> Variant:
		order.append("execute:%s" % phase_id)
		return null

	func _exit(_context: GFTurnContext) -> void:
		order.append("exit:%s" % phase_id)


class ManualPhase extends GFTurnPhase:
	signal completed

	var order: Array[String] = []
	var completion_handle: GFTurnPhaseCompletionHandle = null

	func _init(p_order: Array[String]) -> void:
		order = p_order
		auto_finish = false

	func _enter(_context: GFTurnContext) -> void:
		order.append("enter")

	func _execute(
		_context: GFTurnContext,
		completion: GFTurnPhaseCompletionHandle
	) -> Variant:
		completion_handle = completion
		order.append("execute")
		return completed

	func _exit(_context: GFTurnContext) -> void:
		order.append("exit")


class StoppingPhase extends GFTurnPhase:
	var system: GFTurnFlowSystem = null
	var order: Array[String] = []

	func _init(p_system: GFTurnFlowSystem, p_order: Array[String]) -> void:
		system = p_system
		order = p_order

	func _execute(
		_context: GFTurnContext,
		_completion: GFTurnPhaseCompletionHandle
	) -> Variant:
		order.append("execute")
		if system != null:
			system.stop()
		return null


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


class StartAction extends GFTurnAction:
	var system: GFTurnFlowSystem = null
	var order: Array[String] = []

	func _init(p_system: GFTurnFlowSystem, p_order: Array[String]) -> void:
		action_id = &"start_action"
		system = p_system
		order = p_order

	func _resolve(_context: GFTurnContext) -> Variant:
		order.append("start")
		if system != null:
			system.start(false)
		return null


class ValueActor extends Object:
	var speed: float = 7.0


class ActorCountPhase extends GFTurnPhase:
	var actor_counts: Array[int] = []

	func _enter(context: GFTurnContext) -> void:
		actor_counts.append(context.get_actors().size())


class SharedManualFinishPhase extends GFTurnPhase:
	var exited_contexts: Array[GFTurnContext] = []
	var completions_by_context_id: Dictionary = {}

	func _init() -> void:
		auto_finish = false

	func _execute(
		context: GFTurnContext,
		completion: GFTurnPhaseCompletionHandle
	) -> Variant:
		completions_by_context_id[context.get_instance_id()] = completion
		return null

	func _exit(context: GFTurnContext) -> void:
		exited_contexts.append(context)

	func get_completion(context: GFTurnContext) -> GFTurnPhaseCompletionHandle:
		if context == null:
			return null
		var completion_value: Variant = GFVariantData.get_option_value(
			completions_by_context_id,
			context.get_instance_id()
		)
		if completion_value is GFTurnPhaseCompletionHandle:
			var completion: GFTurnPhaseCompletionHandle = completion_value
			return completion
		return null


class CapturingManualPhase extends GFTurnPhase:
	var completions: Array[GFTurnPhaseCompletionHandle] = []
	var exited_contexts: Array[GFTurnContext] = []

	func _init() -> void:
		auto_finish = false

	func _execute(
		_context: GFTurnContext,
		completion: GFTurnPhaseCompletionHandle
	) -> Variant:
		completions.append(completion)
		return null

	func _exit(context: GFTurnContext) -> void:
		exited_contexts.append(context)


class ConcurrentResolutionPhase extends GFTurnPhase:
	signal completed

	var system: GFTurnFlowSystem = null

	func _init(p_system: GFTurnFlowSystem) -> void:
		system = p_system

	func _execute(
		_context: GFTurnContext,
		_completion: GFTurnPhaseCompletionHandle
	) -> Variant:
		@warning_ignore("missing_await")
		system.resolve_actions()
		return completed


class InjectionCollisionAction extends GFTurnAction:
	var collision_inject_called: bool = false
	var resolved: bool = false

	func inject(_value: Variant) -> void:
		collision_inject_called = true

	func _resolve(_context: GFTurnContext) -> Variant:
		resolved = true
		return null


class ExplicitInjectionAction extends GFTurnAction:
	var injected_architecture: GFArchitecture = null
	var resolved: bool = false

	func _inject_dependencies(architecture: GFArchitecture) -> void:
		injected_architecture = architecture

	func _resolve(_context: GFTurnContext) -> Variant:
		resolved = true
		return null


class StopDuringInjectionAction extends GFTurnAction:
	var system: GFTurnFlowSystem = null
	var resolved: bool = false

	func _init(p_system: GFTurnFlowSystem) -> void:
		system = p_system

	func _inject_dependencies(_architecture: GFArchitecture) -> void:
		if system != null:
			system.stop(false)

	func _resolve(_context: GFTurnContext) -> Variant:
		resolved = true
		return null


class CompatibleTurnValueActor extends Object:
	func get_turn_value(key: StringName, fallback: Variant) -> Variant:
		return 9 if key == &"initiative" else fallback


class WrongArityTurnValueActor extends Object:
	func get_turn_value(_key: StringName) -> Variant:
		return 99


# --- 测试方法 ---

func test_unconfigured_phase_completion_handle_is_inert() -> void:
	var completion: GFTurnPhaseCompletionHandle = GFTurnPhaseCompletionHandle.new()

	assert_false(completion.try_complete(), "项目手工构造的未配置 handle 不得拥有完成权限。")


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
	assert_true(system.get_actions().is_empty(), "解析后待处理行动应被清空。")
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
	assert_not_null(phase.completion_handle)
	if phase.completion_handle != null:
		assert_false(
			phase.completion_handle.try_complete(),
			"stop 返回时必须立即撤销等待中 phase 的 completion authority。"
		)
	phase.completed.emit()
	await get_tree().process_frame

	assert_eq(order, ["enter", "execute"], "stop 后等待中的阶段不应继续 finish/exit。")


func test_turn_flow_start_and_stop_are_idempotent_under_signal_reentry() -> void:
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var started_count: Array[int] = [0]
	var stopped_count: Array[int] = [0]
	var started_callback: Callable = (
		func(_context: GFTurnContext) -> void:
			started_count[0] += 1
			system.start()
	)
	var _started_connection: Error = system.flow_started.connect(
		started_callback
	) as Error
	var stopped_callback: Callable = (
		func(_context: GFTurnContext) -> void:
			stopped_count[0] += 1
			system.stop()
	)
	var _stopped_connection: Error = system.flow_stopped.connect(
		stopped_callback
	) as Error

	system.start()
	system.start(false)
	system.stop()
	system.stop(false)
	system.flow_started.disconnect(started_callback)
	system.flow_stopped.disconnect(stopped_callback)

	assert_eq(started_count[0], 1, "start 及 flow_started 重入不得重复发出生命周期信号。")
	assert_eq(stopped_count[0], 1, "stop 及 flow_stopped 重入不得重复发出生命周期信号。")
	assert_false(system.is_running, "幂等 stop 后状态必须稳定为 stopped。")


func test_flow_started_holds_context_authority_until_observers_finish() -> void:
	var context: GFTurnContext = GFTurnContext.new()
	var replacement_context: GFTurnContext = GFTurnContext.new()
	var owner_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var foreign_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	owner_system.set_context(context)
	foreign_system.set_context(context)
	var started_callback: Callable = func(_context: GFTurnContext) -> void:
		foreign_system.start()
		owner_system.set_context(replacement_context)
	var _started_connection: Error = owner_system.flow_started.connect(started_callback) as Error

	owner_system.start()
	owner_system.flow_started.disconnect(started_callback)

	assert_push_warning("[GFTurnFlowSystem] start 失败：context 正由另一个 flow generation 持有。")
	assert_push_warning("[GFTurnFlowSystem] set_context 失败：存在活动 Context operation。")
	assert_same(owner_system.context, context, "start 通知期间不得替换仍被事务持有的 Context。")
	assert_false(foreign_system.is_running, "flow_started 观察者不得穿插 foreign Context mutation。")
	foreign_system.start()
	assert_true(foreign_system.is_running, "start 事务结束后空闲 Context 仍允许另一 system 顺序使用。")
	owner_system.stop()
	foreign_system.stop()


func test_turn_flow_can_restart_from_completed_stop_notification() -> void:
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var restarted: Array[bool] = [false]
	var stopped_callback: Callable = (
		func(_context: GFTurnContext) -> void:
			if restarted[0]:
				return
			restarted[0] = true
			system.start(false)
	)
	var _stopped_connection: Error = system.flow_stopped.connect(
		stopped_callback
	) as Error

	system.start()
	system.stop()
	system.flow_stopped.disconnect(stopped_callback)

	assert_true(restarted[0], "flow_stopped 应观察到已完成的 stopped 状态并可启动新周期。")
	assert_true(system.is_running, "旧 stop 调用链不得在通知返回后覆盖重入启动的新周期。")


func test_turn_flow_honors_restart_requested_from_nested_start_stop_notifications() -> void:
	var context: GFTurnContext = GFTurnContext.new()
	var owner_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var foreign_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	owner_system.set_context(context)
	foreign_system.set_context(context)
	var seed_order: Array[String] = []
	owner_system.set_phases([RecordingPhase.new(&"seed", seed_order)])
	owner_system.start()
	await owner_system.advance_phase()
	owner_system.stop()
	var preserved_phase_index: int = owner_system.current_phase_index
	var preserved_round_index: int = context.round_index
	assert_eq(preserved_phase_index, 0, "回归夹具必须先建立可观察的非默认 phase index。")
	assert_eq(preserved_round_index, 1, "回归夹具必须先建立可观察的非默认轮次。")
	var events: Array[String] = []
	var started_count: Array[int] = [0]
	var stopped_count: Array[int] = [0]
	var started_callback: Callable = func(_context: GFTurnContext) -> void:
		started_count[0] += 1
		events.append("owner_started:%d" % started_count[0])
		if started_count[0] == 1:
			owner_system.stop()
	var stopped_callback: Callable = func(_context: GFTurnContext) -> void:
		stopped_count[0] += 1
		events.append("owner_stopped:%d" % stopped_count[0])
		if stopped_count[0] == 1:
			events.append("restart_requested")
			owner_system.start(false)
			events.append("foreign_attempted")
			foreign_system.start(false)
	var _started_connection: Error = owner_system.flow_started.connect(started_callback) as Error
	var _stopped_connection: Error = owner_system.flow_stopped.connect(stopped_callback) as Error

	owner_system.start(false)
	owner_system.flow_started.disconnect(started_callback)
	owner_system.flow_stopped.disconnect(stopped_callback)

	assert_push_warning("[GFTurnFlowSystem] start 失败：context 正由另一个 flow generation 持有。")
	assert_eq(
		events,
		[
			"owner_started:1",
			"owner_stopped:1",
			"restart_requested",
			"foreign_attempted",
			"owner_started:2",
		],
		"新 generation 必须等外层 start 通知展开完成后再同步启动。"
	)
	assert_eq(started_count[0], 2, "完成嵌套 stop 通知后应启动一次新 generation。")
	assert_eq(stopped_count[0], 1, "嵌套重启不得重复发出 stop 通知。")
	assert_true(owner_system.is_running, "flow_stopped 中请求的重启应在外层 start 事务释放后生效。")
	assert_false(foreign_system.is_running, "外层 start 通知仍在展开时不得穿插 foreign Context mutation。")
	assert_eq(
		owner_system.current_phase_index,
		preserved_phase_index,
		"start(false) 的嵌套重启不得丢失 reset_indices 载荷。"
	)
	assert_eq(
		context.round_index,
		preserved_round_index,
		"start(false) 的嵌套重启不得重置 Context 轮次。"
	)

	owner_system.stop()
	foreign_system.start(false)
	assert_true(foreign_system.is_running, "重启事务收敛后不得泄漏 Context claim。")
	foreign_system.stop()


func test_later_stop_cancels_restart_queued_during_start_notification() -> void:
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var started_count: Array[int] = [0]
	var started_callback: Callable = func(_context: GFTurnContext) -> void:
		started_count[0] += 1
		if started_count[0] == 1:
			system.stop()
	var restart_callback: Callable = func(_context: GFTurnContext) -> void:
		system.start(false)
	var final_stop_callback: Callable = func(_context: GFTurnContext) -> void:
		system.stop()
	var _started_connection: Error = system.flow_started.connect(started_callback) as Error
	var _restart_connection: Error = system.flow_stopped.connect(restart_callback) as Error
	var _final_stop_connection: Error = system.flow_stopped.connect(final_stop_callback) as Error

	system.start()
	system.flow_started.disconnect(started_callback)
	system.flow_stopped.disconnect(restart_callback)
	system.flow_stopped.disconnect(final_stop_callback)

	assert_eq(started_count[0], 1, "后续 stop 应取消尚未执行的嵌套重启请求。")
	assert_false(system.is_running, "延迟重启不得反转后续 stop 的最终状态。")


func test_stop_true_clears_actions_even_when_already_stopped() -> void:
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var action: GFTurnAction = GFTurnAction.new()
	system.enqueue_action(action)

	system.stop(true)

	assert_eq(system.get_action_count(), 0, "stopped 状态的 clear policy 仍必须收敛队列。")
	assert_true(action.is_sealed(), "被 stopped cleanup 丢弃的 action 必须永久封存。")


func test_disposed_flow_rejects_new_action_without_claiming_it() -> void:
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var fresh_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var action: GFTurnAction = GFTurnAction.new()
	system.dispose()

	system.enqueue_action(action)

	assert_eq(system.get_action_count(), 0, "disposed system 不得接纳新 action。")
	assert_false(action.is_sealed(), "未被接纳的 action 不得被 claim 或封存。")
	fresh_system.enqueue_action(action)
	assert_eq(fresh_system.get_action_count(), 1, "disposed guard 必须位于 one-shot claim 之前。")
	fresh_system.stop(true)


func test_stop_true_upgrades_completed_stop_false_restore() -> void:
	var order: Array[String] = []
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var pending_action: RecordingAction = RecordingAction.new("pending", 0, 0.0, order)
	system.enqueue_action(StopAction.new(system, false, order))
	system.enqueue_action(pending_action)
	await system.resolve_actions()
	assert_eq(system.get_action_count(), 1)

	system.stop(true)

	assert_eq(system.get_action_count(), 0, "stop(false) 恢复后必须允许升级为 clear。")
	assert_true(pending_action.is_sealed(), "升级清理必须封存已恢复的一次性 action。")


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
	assert_not_null(phase.completion_handle)
	if phase.completion_handle != null:
		assert_false(phase.completion_handle.try_complete(), "Signal timeout 后 handle 必须失效。")


func test_phase_completion_wait_timeout_invalidates_handle_without_exit() -> void:
	var phase: CapturingManualPhase = CapturingManualPhase.new()
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var foreign_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.signal_timeout_seconds = 0.001
	system.set_phases([phase])
	foreign_system.set_context(system.context)

	system.start()
	@warning_ignore("missing_await")
	system.advance_phase()
	await get_tree().create_timer(0.05).timeout
	await get_tree().process_frame

	assert_push_warning("[GFTurnFlowSystem] 等待阶段完成超时，阶段推进已中止。")
	assert_eq(phase.completions.size(), 1)
	assert_true(phase.exited_contexts.is_empty(), "completion timeout 不得调用 phase exit。")
	if not phase.completions.is_empty():
		assert_false(phase.completions[0].try_complete(), "completion timeout 后 handle 必须失效。")
	foreign_system.start()
	assert_true(foreign_system.is_running, "completion timeout 清理后必须释放 Context claim。")
	foreign_system.stop()


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
	var phase_changed_callback: Callable = func(_phase: GFTurnPhase, _index: int) -> void:
		system.stop()
	var _connect_result: Error = system.phase_changed.connect(phase_changed_callback) as Error

	system.start()
	await system.advance_phase()
	system.phase_changed.disconnect(phase_changed_callback)

	assert_eq(order, [], "phase_changed 中 stop 后不应继续调用新阶段 enter。")


func test_sync_phase_stop_prevents_auto_finish() -> void:
	var order: Array[String] = []
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var phase: StoppingPhase = StoppingPhase.new(system, order)
	var finished_count: Array[int] = [0]
	var _connect_result: Error = phase.finished.connect(func() -> void:
		finished_count[0] = finished_count[0] + 1
	) as Error
	system.set_phases([phase])

	system.start()
	await system.advance_phase()
	phase.system = null

	assert_eq(order, ["execute"], "同步 stop 后不应继续阶段完成流程。")
	assert_eq(finished_count[0], 0, "同步 stop 后不应发出 finished。")
	assert_false(phase.is_finished_for(system.context), "同步 stop 后 phase 不应保留已完成运行态。")


func test_advance_phase_skips_null_phase_entries_safely() -> void:
	var order: Array[String] = []
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.phases = [null, RecordingPhase.new(&"play", order)]
	assert_push_warning("[GFTurnFlowSystem] set_phases 跳过空阶段。")

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


func test_context_replacement_is_rejected_during_awaited_action() -> void:
	var order: Array[String] = []
	var actor: Node = Node.new()
	var action: ManualAction = ManualAction.new(order)
	action.actor = actor
	var old_context: GFTurnContext = GFTurnContext.new()
	var replacement_context: GFTurnContext = GFTurnContext.new()
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.set_context(old_context)
	system.enqueue_action(action)
	system.enqueue_action(RecordingAction.new("next", 0, 0.0, order))

	@warning_ignore("missing_await")
	system.resolve_actions()
	await get_tree().process_frame
	system.context = replacement_context
	system.stop(false)
	action.completed.emit()
	await get_tree().process_frame

	assert_same(system.context, old_context, "in-flight 解析必须持有启动时 context lease。")
	assert_null(old_context.current_actor, "解析结束必须清理启动时 context 的 current_actor。")
	assert_eq(_get_queued_actions(system).size(), 2, "stop(false) 应把未解析行动恢复到原 flow 队列。")
	assert_push_warning("[GFTurnFlowSystem] set_context 失败：存在活动 Context operation。")
	system.stop(true)
	actor.free()


func test_awaited_action_cancel_prevents_resolved_signal() -> void:
	var order: Array[String] = []
	var action: ManualAction = ManualAction.new(order)
	var resolved_count: Array[int] = [0]
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var _connect_result: Error = system.action_resolved.connect(func(_action: GFTurnAction) -> void:
		resolved_count[0] = resolved_count[0] + 1
	) as Error
	system.enqueue_action(action)

	@warning_ignore("missing_await")
	system.resolve_actions()
	await get_tree().process_frame

	action.cancel()
	action.completed.emit()
	await get_tree().process_frame

	assert_eq(order, ["resolve"], "取消 awaited action 后不应重新解析。")
	assert_eq(resolved_count[0], 0, "取消 awaited action 后不应发出 resolved。")
	assert_null(system.context.current_actor, "取消 awaited action 后 current_actor 应复位。")


func test_awaited_action_actor_freed_prevents_resolved_signal() -> void:
	var order: Array[String] = []
	var actor: Node = Node.new()
	var action: ManualAction = ManualAction.new(order)
	action.actor = actor
	var resolved_count: Array[int] = [0]
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var _connect_result: Error = system.action_resolved.connect(func(_action: GFTurnAction) -> void:
		resolved_count[0] = resolved_count[0] + 1
	) as Error
	system.enqueue_action(action)

	@warning_ignore("missing_await")
	system.resolve_actions()
	await get_tree().process_frame

	actor.free()
	action.completed.emit()
	await get_tree().process_frame

	assert_eq(resolved_count[0], 0, "actor 失效后的 awaited action 不应发出 resolved。")
	assert_null(system.context.current_actor, "actor 失效后 current_actor 应复位。")


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
	assert_eq(system.get_actions().size(), 1, "stop(false) 应保留尚未解析的行动。")
	assert_eq(String(system.get_actions()[0].action_id), "next", "保留的行动应是未解析部分。")


func test_stop_without_clearing_restores_awaited_current_action() -> void:
	var order: Array[String] = []
	var manual: ManualAction = ManualAction.new(order)
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.enqueue_action(manual)
	system.enqueue_action(RecordingAction.new("next", 0, 0.0, order))

	@warning_ignore("missing_await")
	system.resolve_actions()
	await get_tree().process_frame

	system.stop(false)
	manual.completed.emit()
	await get_tree().process_frame

	assert_eq(system.get_actions().size(), 2, "await 期间 stop(false) 应恢复 current 和后续未解析行动。")
	assert_eq(String(system.get_actions()[0].action_id), "manual", "current action 应按原顺序恢复。")
	assert_eq(String(system.get_actions()[1].action_id), "next", "后续 action 应按原顺序恢复。")


func test_cross_channel_stop_policy_converges_when_phase_finishes_first() -> void:
	await _assert_cross_channel_stop_policy_converges(true)


func test_cross_channel_stop_policy_converges_when_action_finishes_first() -> void:
	await _assert_cross_channel_stop_policy_converges(false)


func test_start_reentry_during_action_is_rejected_without_dropping_pending_actions() -> void:
	var order: Array[String] = []
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.enqueue_action(StartAction.new(system, order))
	system.enqueue_action(RecordingAction.new("next", 0, 0.0, order))

	await system.resolve_actions()

	assert_push_warning("[GFTurnFlowSystem] start 失败：流程正在推进或解析中。")
	assert_eq(order, ["start", "next"], "解析中 start 重入应被拒绝且不丢弃后续行动。")


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


func test_comparator_stop_restores_snapshot_without_resolving() -> void:
	var order: Array[String] = []
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var stopped: Array[bool] = [false]
	system.enqueue_action(RecordingAction.new("first", 0, 0.0, order))
	system.enqueue_action(RecordingAction.new("second", 0, 0.0, order))
	var comparator: Callable = func(_a: GFTurnAction, _b: GFTurnAction) -> bool:
		if not stopped[0]:
			stopped[0] = true
			system.stop(false)
		return false

	await system.resolve_actions(comparator)

	assert_eq(order, [], "比较器使 transaction 失效后不得开始解析行动。")
	assert_eq(_get_queued_actions(system).size(), 2, "比较器 stop(false) 后应完整恢复排序快照。")
	system.stop(true)


func test_non_finite_sort_values_are_stable_and_last() -> void:
	var order: Array[String] = []
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.enqueue_action(RecordingAction.new("nan", 0, NAN, order))
	system.enqueue_action(RecordingAction.new("finite", 0, 1.0, order))
	system.enqueue_action(RecordingAction.new("inf", 0, INF, order))

	await system.resolve_actions()

	assert_eq(order, ["finite", "nan", "inf"], "非有限 sort_value 应按入队顺序稳定排在有限值之后。")


func test_action_constructor_filters_invalid_and_duplicate_targets() -> void:
	var target: Node = Node.new()
	var stale_target: Node = Node.new()
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var action: GFTurnAction = GFTurnAction.new(null, [target, target, stale_target, null])
	system.enqueue_action(action)
	stale_target.free()

	await system.resolve_actions()

	assert_eq(action.targets.size(), 1, "行动目标应过滤 null、重复和已释放对象。")
	assert_eq(action.targets[0], target, "有效目标应保留。")
	target.free()


func test_phase_cleans_invalid_actors_before_enter() -> void:
	var actor: Node = Node.new()
	var phase: ActorCountPhase = ActorCountPhase.new()
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.context.add_actor(actor)
	actor.free()
	system.set_phases([phase])

	system.start()
	await system.advance_phase()

	assert_eq(phase.actor_counts, [0], "phase enter 前必须清理 context 中已失效的 actor。")


func test_shared_phase_completion_is_scoped_to_one_context() -> void:
	var phase: SharedManualFinishPhase = SharedManualFinishPhase.new()
	var system_a: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var system_b: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system_a.set_phases([phase])
	system_b.set_phases([phase])
	system_a.start()
	system_b.start()

	@warning_ignore("missing_await")
	system_a.advance_phase()
	@warning_ignore("missing_await")
	system_b.advance_phase()
	await get_tree().process_frame
	var completion_a: GFTurnPhaseCompletionHandle = phase.get_completion(system_a.context)
	var completion_b: GFTurnPhaseCompletionHandle = phase.get_completion(system_b.context)

	assert_not_null(completion_a, "每个 phase runtime 必须收到自己的 completion handle。")
	assert_not_null(completion_b, "共享 phase 的不同 Context 必须收到不同 completion handle。")
	if completion_a == null or completion_b == null:
		system_a.stop()
		system_b.stop()
		return
	assert_ne(completion_a, completion_b, "共享 phase 的 completion handle 不得跨 Context 复用。")
	assert_true(completion_b.try_complete(), "精确 handle 应完成自己的 runtime。")
	assert_false(completion_b.try_complete(), "completion handle 必须一次性提交。")
	await get_tree().process_frame

	assert_eq(phase.exited_contexts, [system_b.context], "完成 Context B 不得结算 Context A。")
	system_a.stop()
	system_b.stop()
	await get_tree().process_frame
	assert_false(
		completion_a.try_complete(),
		"stop 后未完成 handle 必须失效。"
	)


func test_stale_phase_completion_cannot_settle_restarted_generation() -> void:
	var phase: CapturingManualPhase = CapturingManualPhase.new()
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.set_phases([phase])
	system.start()
	@warning_ignore("missing_await")
	system.advance_phase()
	await get_tree().process_frame

	assert_eq(phase.completions.size(), 1, "首个 generation 必须收到 completion handle。")
	if phase.completions.is_empty() or phase.completions[0] == null:
		system.stop()
		return
	var stale_completion: GFTurnPhaseCompletionHandle = phase.completions[0]
	system.stop()
	assert_false(
		stale_completion.try_complete(),
		"stop 必须立即撤销旧 generation 的 settlement authority。"
	)
	await get_tree().process_frame

	system.start(false)
	@warning_ignore("missing_await")
	system.advance_phase()
	await get_tree().process_frame
	assert_eq(phase.completions.size(), 2, "重启后必须创建新的 completion handle。")
	if phase.completions.size() < 2 or phase.completions[1] == null:
		system.stop()
		return
	var current_completion: GFTurnPhaseCompletionHandle = phase.completions[1]

	assert_false(
		stale_completion.try_complete(),
		"旧 callback 不得结算同一 Context 的新 generation。"
	)
	assert_true(
		current_completion.try_complete(),
		"当前 generation 的精确 handle 应可完成。"
	)
	assert_false(
		current_completion.try_complete(),
		"当前 handle 完成后必须拒绝重复提交。"
	)
	await get_tree().process_frame
	assert_eq(phase.exited_contexts, [system.context], "只有重启后的 generation 应正常 exit。")


func test_dispose_invalidates_completion_and_releases_context_after_unwind() -> void:
	var context: GFTurnContext = GFTurnContext.new()
	var phase: CapturingManualPhase = CapturingManualPhase.new()
	var owner_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var foreign_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	owner_system.set_context(context)
	foreign_system.set_context(context)
	owner_system.set_phases([phase])
	owner_system.start()
	@warning_ignore("missing_await")
	owner_system.advance_phase()
	await get_tree().process_frame

	assert_eq(phase.completions.size(), 1)
	if phase.completions.is_empty():
		owner_system.dispose()
		return
	var completion: GFTurnPhaseCompletionHandle = phase.completions[0]
	owner_system.dispose()
	assert_false(completion.try_complete(), "dispose 返回时必须立即撤销 phase completion。")
	owner_system.dispose()
	owner_system.start()
	assert_false(owner_system.is_running, "disposed Flow System 不得重新启动。")

	foreign_system.start()
	assert_push_warning("[GFTurnFlowSystem] start 失败：context 正由另一个 flow generation 持有。")
	assert_false(foreign_system.is_running, "旧 continuation 清理前不得提前转交 Context。")
	await get_tree().process_frame
	foreign_system.start()
	assert_true(foreign_system.is_running, "旧 continuation 收敛后必须允许另一 system 顺序接管。")
	foreign_system.stop()


func test_context_claims_release_only_after_last_exact_lease() -> void:
	var context: GFTurnContext = GFTurnContext.new()
	var owner_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var foreign_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var third_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var first_lease: GFTurnContext.FlowOperationLease = (
		context.try_acquire_flow_operation_lease(owner_system, 1)
	)
	var second_lease: GFTurnContext.FlowOperationLease = (
		context.try_acquire_flow_operation_lease(owner_system, 1)
	)

	assert_not_null(first_lease)
	assert_not_null(second_lease)
	assert_true(context.release_flow_operation_lease(first_lease, owner_system))
	assert_null(
		context.try_acquire_flow_operation_lease(foreign_system, 1),
		"同 owner 的第二张 exact claim 未释放前不得转交 Context。"
	)
	assert_true(context.cancel_flow_operation_lease(second_lease, owner_system))
	assert_null(
		context.try_acquire_flow_operation_lease(foreign_system, 1),
		"取消只撤销写权限，不得提前释放旧 continuation 的 claim。"
	)
	assert_true(context.release_flow_operation_lease(second_lease, owner_system))
	var foreign_lease: GFTurnContext.FlowOperationLease = (
		context.try_acquire_flow_operation_lease(foreign_system, 1)
	)
	assert_not_null(foreign_lease)
	assert_false(
		context.release_flow_operation_lease(second_lease, owner_system),
		"旧 lease 的重复释放不得清除新 owner。"
	)
	assert_null(
		context.try_acquire_flow_operation_lease(third_system, 1),
		"stale release 后新 owner 的 claim 必须继续有效。"
	)
	assert_true(context.release_flow_operation_lease(foreign_lease, foreign_system))


func test_shared_context_rejects_foreign_flow_before_phase_mutation() -> void:
	var context: GFTurnContext = GFTurnContext.new()
	var owner_phase: CapturingManualPhase = CapturingManualPhase.new()
	var foreign_order: Array[String] = []
	var owner_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var foreign_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var foreign_start_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	owner_system.set_context(context)
	foreign_system.set_context(context)
	foreign_start_system.set_context(context)
	owner_system.set_phases([owner_phase])
	foreign_system.set_phases([RecordingPhase.new(&"foreign", foreign_order)])
	owner_system.start()
	foreign_system.start()
	@warning_ignore("missing_await")
	owner_system.advance_phase()
	await get_tree().process_frame
	var owned_round: int = context.round_index

	foreign_start_system.start()
	assert_push_warning("[GFTurnFlowSystem] start 失败：context 正由另一个 flow generation 持有。")
	assert_false(foreign_start_system.is_running, "foreign start 失败后不得提交 lifecycle 状态。")
	assert_eq(context.round_index, owned_round, "foreign start 不得提前重置 Context 轮次。")
	@warning_ignore("missing_await")
	foreign_system.advance_phase()
	assert_push_warning("[GFTurnFlowSystem] advance_phase 失败：context 正由另一个 flow generation 持有。")
	assert_eq(foreign_system.current_phase_index, -1, "foreign advance 不得提前切换 phase index。")
	assert_eq(context.round_index, owned_round, "foreign advance 不得提前推进 Context 轮次。")
	assert_true(foreign_order.is_empty(), "foreign phase 不得 enter/execute/exit。")

	owner_system.stop()
	await get_tree().process_frame
	await foreign_system.advance_phase()
	assert_eq(foreign_order, ["enter:foreign", "execute:foreign", "exit:foreign"])
	foreign_system.stop()


func test_shared_context_rejects_foreign_action_before_queue_mutation() -> void:
	var context: GFTurnContext = GFTurnContext.new()
	var owner_phase: CapturingManualPhase = CapturingManualPhase.new()
	var owner_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var foreign_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var foreign_order: Array[String] = []
	var foreign_action: RecordingAction = RecordingAction.new("foreign", 0, 0.0, foreign_order)
	owner_system.set_context(context)
	foreign_system.set_context(context)
	owner_system.set_phases([owner_phase])
	owner_system.start()
	@warning_ignore("missing_await")
	owner_system.advance_phase()
	await get_tree().process_frame
	foreign_system.enqueue_action(foreign_action)

	await foreign_system.resolve_actions()
	assert_push_warning("[GFTurnFlowSystem] resolve_actions 失败：context 正由另一个 flow generation 持有。")
	assert_eq(foreign_order, [], "foreign action 不得开始 resolve。")
	assert_eq(foreign_system.get_action_count(), 1, "foreign rejection 不得清空或封存队列。")
	assert_false(foreign_action.is_sealed(), "未接纳的 foreign action 必须保持待处理状态。")
	assert_null(context.current_actor, "foreign rejection 不得写入 current_actor。")

	owner_system.stop()
	await get_tree().process_frame
	await foreign_system.resolve_actions()
	assert_eq(foreign_order, ["foreign"], "owner release 后另一 system 应可解析自己的队列。")
	assert_true(foreign_action.is_sealed())


func test_same_owner_phase_and_action_claims_block_foreign_until_both_finish() -> void:
	var context: GFTurnContext = GFTurnContext.new()
	var actor: Node = Node.new()
	var action_order: Array[String] = []
	var owner_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var foreign_system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var phase: ConcurrentResolutionPhase = ConcurrentResolutionPhase.new(owner_system)
	var action: ManualAction = ManualAction.new(action_order)
	action.actor = actor
	owner_system.set_context(context)
	foreign_system.set_context(context)
	owner_system.set_phases([phase])
	owner_system.enqueue_action(action)
	owner_system.start()
	@warning_ignore("missing_await")
	owner_system.advance_phase()
	await get_tree().process_frame

	assert_eq(action_order, ["resolve"], "phase 内启动的同 owner action 必须真实进入 resolve。")
	assert_same(context.current_actor, actor)
	foreign_system.start()
	assert_push_warning("[GFTurnFlowSystem] start 失败：context 正由另一个 flow generation 持有。")

	phase.completed.emit()
	await get_tree().process_frame
	assert_same(context.current_actor, actor, "phase claim 释放后 action claim 仍应独占 Context。")
	foreign_system.start()
	assert_push_warning("[GFTurnFlowSystem] start 失败：context 正由另一个 flow generation 持有。")
	assert_false(foreign_system.is_running)

	action.completed.emit()
	await get_tree().process_frame
	assert_null(context.current_actor)
	foreign_system.start()
	assert_true(foreign_system.is_running, "phase/action 两张 claim 都释放后必须允许顺序接管。")
	foreign_system.stop()
	owner_system.stop()
	phase.system = null
	actor.free()


func test_action_injection_uses_framework_internal_dispatch_to_explicit_protected_hook() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var collision_action: InjectionCollisionAction = InjectionCollisionAction.new()
	var explicit_action: ExplicitInjectionAction = ExplicitInjectionAction.new()
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	system.inject_dependencies(architecture)
	system.enqueue_action(collision_action)
	system.enqueue_action(explicit_action)

	await system.resolve_actions()

	assert_false(collision_action.collision_inject_called, "项目自有 inject 方法不得被隐藏协议调用。")
	assert_same(explicit_action.injected_architecture, architecture, "framework_internal 边界应调度显式 protected 注入 hook。")
	assert_true(collision_action.resolved)
	assert_true(explicit_action.resolved)
	system.release_dependencies()
	architecture.dispose()


func test_action_injection_stop_is_rechecked_before_context_write_or_resolve() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var stopping_action: StopDuringInjectionAction = StopDuringInjectionAction.new(system)
	var next_action: GFTurnAction = GFTurnAction.new()
	system.inject_dependencies(architecture)
	system.enqueue_action(stopping_action)
	system.enqueue_action(next_action)

	await system.resolve_actions()

	assert_false(stopping_action.resolved, "injection hook stop 后不得继续调用 action resolve。")
	assert_eq(system.get_action_count(), 2, "stop(false) 应保留 current 与后续 action。")
	assert_null(system.context.current_actor, "injection stop 后不得写入 current_actor。")
	system.stop(true)
	stopping_action.system = null
	system.release_dependencies()
	architecture.dispose()


func test_action_queue_is_system_owned_and_snapshot_only() -> void:
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var action: GFTurnAction = GFTurnAction.new()
	system.enqueue_action(action)

	assert_true(system.has_method("get_actions"), "flow system 必须提供只读行动快照入口。")
	if not system.has_method("get_actions"):
		return
	var snapshot: Array = GFVariantData.as_array(system.call("get_actions"))
	snapshot.clear()

	assert_eq(_get_queued_actions(system).size(), 1, "修改返回快照不得绕过 system 队列所有权。")
	assert_false(_has_property(system.context, &"actions"), "context 不应再暴露第二套可变 action 队列。")
	system.stop(true)


func test_action_instance_is_one_shot_and_configuration_seals_on_enqueue() -> void:
	var system_a: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var system_b: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var action: GFTurnAction = GFTurnAction.new()
	action.priority = 3

	system_a.enqueue_action(action)
	system_a.enqueue_action(action)
	system_b.enqueue_action(action)
	action.priority = 99

	assert_eq(_get_queued_actions(system_a).size(), 1, "同一 action 实例不得重复入队。")
	assert_eq(_get_queued_actions(system_b).size(), 0, "同一 action 实例不得跨 flow 复用。")
	assert_eq(action.priority, 3, "action 入队后配置必须冻结。")
	for _index: int in range(2):
		assert_push_warning("[GFTurnFlowSystem] enqueue_action 失败：action 实例只能入队一次。")
	assert_push_error("[GFTurnAction] 行动已入队，不能修改配置：priority。")
	system_a.stop(true)


## 验证上下文可安全读取参与者排序值。
func test_turn_context_reads_actor_value() -> void:
	var actor: ValueActor = ValueActor.new()

	var context: GFTurnContext = GFTurnContext.new()
	context.add_actor(actor)

	assert_eq(GFVariantData.to_float(context.get_actor_value(actor, &"speed")), 7.0, "应能从对象属性读取值。")
	assert_eq(GFVariantData.to_float(context.get_actor_value(null, &"speed", 0.0)), 0.0, "空对象应返回 fallback。")

	actor.free()


func test_turn_context_preflights_get_turn_value_signature() -> void:
	var compatible: CompatibleTurnValueActor = CompatibleTurnValueActor.new()
	var incompatible: WrongArityTurnValueActor = WrongArityTurnValueActor.new()
	var context: GFTurnContext = GFTurnContext.new()

	assert_eq(GFVariantData.to_int(context.get_actor_value(compatible, &"initiative", 3), -1), 9)
	assert_eq(
		GFVariantData.to_int(context.get_actor_value(incompatible, &"initiative", 3), -1),
		3,
		"同名但不接受两个参数的方法必须稳定返回 fallback，不能直接错误调用。"
	)
	compatible.free()
	incompatible.free()


func test_turn_context_cleanup_invalid_actors() -> void:
	var actor: Node = Node.new()
	var context: GFTurnContext = GFTurnContext.new()
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var lease: GFTurnContext.FlowOperationLease = context.try_acquire_flow_operation_lease(system, 1)
	context.add_actor(actor)
	context.set_current_actor_from_flow(actor, lease, system, 1)

	actor.free()
	var removed_count: int = context.cleanup_invalid_actors()

	assert_eq(removed_count, 1, "cleanup_invalid_actors 应移除失效 actor。")
	assert_true(context.get_actors().is_empty(), "失效 actor 不应留在 actors 中。")
	assert_null(context.current_actor, "失效 current_actor 应被复位。")
	assert_true(context.release_flow_operation_lease(lease, system))


# --- 辅助方法 ---

func _get_queued_actions(system: GFTurnFlowSystem) -> Array:
	return GFVariantData.as_array(system.call("get_actions"))


func _has_property(object: Object, property_name: StringName) -> bool:
	for property_info: Dictionary in object.get_property_list():
		if StringName(GFVariantData.get_option_string(property_info, "name")) == property_name:
			return true
	return false


func _assert_cross_channel_stop_policy_converges(phase_finishes_first: bool) -> void:
	var actor: Node = Node.new()
	var system: GFTurnFlowSystem = GFTurnFlowSystem.new()
	var phase: ConcurrentResolutionPhase = ConcurrentResolutionPhase.new(system)
	var action: ManualAction = ManualAction.new([])
	action.actor = actor
	system.set_phases([phase])
	system.enqueue_action(action)
	var stopped_count: Array[int] = [0]
	var _stopped_connection: Error = system.flow_stopped.connect(
		func(_context: GFTurnContext) -> void:
			stopped_count[0] += 1
	) as Error
	system.start()
	@warning_ignore("missing_await")
	system.advance_phase()
	await get_tree().process_frame

	system.stop(false)
	system.stop(true)
	if phase_finishes_first:
		phase.completed.emit()
		await get_tree().process_frame
		action.completed.emit()
	else:
		action.completed.emit()
		await get_tree().process_frame
		phase.completed.emit()
	await get_tree().process_frame

	assert_eq(stopped_count[0], 1, "cross-channel 重复 stop 不得重复通知。")
	assert_eq(system.get_action_count(), 0, "更强 clear policy 必须覆盖仍在途的 restore policy。")
	assert_true(action.is_sealed(), "最终 clear policy 必须封存 in-flight action。")
	assert_null(system.context.current_actor)
	phase.system = null
	actor.free()
