## 测试 GFNodeState 的 Resource 条件与行为钩子。
extends GutTest


class TrackingNodeState:
	extends GFNodeState

	var enter_count: int = 0
	var exit_count: int = 0

	func _enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:
		enter_count += 1

	func _exit(_next_state: StringName = &"", _args: Dictionary = {}) -> void:
		exit_count += 1


class ToggleCondition:
	extends GFNodeStateCondition

	var allowed: bool = true
	var phases: Array[StringName] = []
	var peers: Array[StringName] = []

	func _evaluate(_state: GFNodeState, phase: StringName, peer_state: StringName = &"", _args: Dictionary = {}) -> bool:
		phases.append(phase)
		peers.append(peer_state)
		return allowed


class RecordingBehavior:
	extends GFNodeStateBehavior

	var calls: Array[String] = []
	var handled_event_id: StringName = &""

	func _initialize(state: GFNodeState) -> void:
		calls.append("initialize:%s" % state.get_state_name())

	func _enter(state: GFNodeState, previous_state: StringName = &"", _args: Dictionary = {}) -> void:
		calls.append("enter:%s:%s" % [state.get_state_name(), previous_state])

	func _exit(state: GFNodeState, next_state: StringName = &"", _args: Dictionary = {}) -> void:
		calls.append("exit:%s:%s" % [state.get_state_name(), next_state])

	func _pause(state: GFNodeState, next_state: StringName = &"", _args: Dictionary = {}) -> void:
		calls.append("pause:%s:%s" % [state.get_state_name(), next_state])

	func _resume(state: GFNodeState, previous_state: StringName = &"", _args: Dictionary = {}) -> void:
		calls.append("resume:%s:%s" % [state.get_state_name(), previous_state])

	func _handle_state_event(state: GFNodeState, event_id: StringName, _payload: Variant = null) -> bool:
		calls.append("event:%s:%s" % [state.get_state_name(), event_id])
		return event_id == handled_event_id


func test_enter_condition_blocks_transition_until_allowed() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var run: TrackingNodeState = TrackingNodeState.new()
	var condition: ToggleCondition = ToggleCondition.new()
	idle.name = "Idle"
	run.name = "Run"
	condition.allowed = false
	run.enter_conditions.append(condition)
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(run)
	await get_tree().process_frame

	machine.transition_to(&"Run")

	assert_eq(machine.get_current_state(), idle, "条件拒绝时不应进入目标状态。")
	assert_eq(run.enter_count, 0, "条件拒绝时目标 enter 不应执行。")
	assert_eq(condition.phases, [&"enter"], "进入条件应以 enter 阶段评估。")
	assert_eq(condition.peers, [&"Idle"], "进入条件应收到来源状态名。")

	condition.allowed = true
	machine.transition_to(&"Run")

	assert_eq(machine.get_current_state(), run, "条件允许后应完成切换。")
	assert_eq(run.enter_count, 1, "条件允许后目标 enter 应执行。")


func test_exit_condition_blocks_leaving_current_state() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var run: TrackingNodeState = TrackingNodeState.new()
	var condition: ToggleCondition = ToggleCondition.new()
	idle.name = "Idle"
	run.name = "Run"
	condition.allowed = false
	idle.exit_conditions.append(condition)
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(run)
	await get_tree().process_frame

	machine.transition_to(&"Run")

	assert_eq(machine.get_current_state(), idle, "退出条件拒绝时应保持当前状态。")
	assert_eq(idle.exit_count, 0, "退出条件拒绝时当前 exit 不应执行。")
	assert_eq(condition.phases, [&"exit"], "退出条件应以 exit 阶段评估。")
	assert_eq(condition.peers, [&"Run"], "退出条件应收到目标状态名。")


func test_behavior_receives_lifecycle_and_can_handle_events() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var run: TrackingNodeState = TrackingNodeState.new()
	var behavior: RecordingBehavior = RecordingBehavior.new()
	idle.name = "Idle"
	run.name = "Run"
	behavior.handled_event_id = &"ping"
	idle.behaviors.append(behavior)
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(run)
	await get_tree().process_frame

	var group: GFNodeStateGroup = machine.get_state_group(GFNodeStateMachine.INTERNAL_GROUP_NAME)
	var handled: bool = group.dispatch_state_event(&"ping", { "value": 1 })
	machine.transition_to(&"Run")

	assert_true(handled, "状态自身未处理时，行为资源应能处理状态事件。")
	assert_has(behavior.calls, "initialize:Idle", "行为应收到初始化回调。")
	assert_has(behavior.calls, "enter:Idle:", "行为应收到进入回调。")
	assert_has(behavior.calls, "event:Idle:ping", "行为应收到事件回调。")
	assert_has(behavior.calls, "exit:Idle:Run", "行为应收到退出回调。")


func test_behavior_receives_pause_and_resume_callbacks() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var menu: TrackingNodeState = TrackingNodeState.new()
	var behavior: RecordingBehavior = RecordingBehavior.new()
	idle.name = "Idle"
	menu.name = "Menu"
	idle.behaviors.append(behavior)
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(menu)
	await get_tree().process_frame

	machine.push_state(&"Menu")
	var _pop_state_result_150: Variant = machine.pop_state()

	assert_has(behavior.calls, "pause:Idle:Menu", "push_state 应触发行为资源的 pause。")
	assert_has(behavior.calls, "resume:Idle:Menu", "pop_state 应触发行为资源的 resume。")


func test_group_remove_stacked_state_exits_removed_state() -> void:
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var menu: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	menu.name = "Menu"
	add_child_autofree(group)
	group.add_child(idle)
	group.add_child(menu)
	group.add_state(idle)
	group.add_state(menu)
	group.transition_to(&"Idle")
	group.push_state(&"Menu")

	assert_true(group.remove_state(idle), "移除暂停栈中的状态应成功。")

	assert_eq(idle.exit_count, 1, "暂停栈中的状态被移除时也应执行 exit。")
	assert_eq(group.get_stack_depth(), 0, "移除暂停栈状态后栈中不应残留该状态。")
