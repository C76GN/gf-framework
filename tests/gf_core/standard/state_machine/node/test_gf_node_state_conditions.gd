## 测试节点状态条件组合、活跃状态条件和状态机快照恢复入口。
extends GutTest


# --- 辅助子类 ---

class FixedCondition:
	extends GFNodeStateCondition

	var accepted: bool = true

	func _init(p_accepted: bool = true) -> void:
		accepted = p_accepted

	func _evaluate(
		_state: GFNodeState,
		_phase: StringName,
		_peer_state: StringName = &"",
		_args: Dictionary = {}
	) -> bool:
		return accepted


class TrackingNodeState:
	extends GFNodeState

	var enter_count: int = 0
	var exit_count: int = 0

	func _enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> void:
		enter_count += 1

	func _exit(_next_state: StringName = &"", _args: Dictionary = {}) -> void:
		exit_count += 1


# --- 测试 ---

func test_condition_group_combines_child_conditions() -> void:
	var state: GFNodeState = GFNodeState.new()
	autofree(state)
	var passing: FixedCondition = FixedCondition.new(true)
	var failing: FixedCondition = FixedCondition.new(false)
	var group: GFNodeStateConditionGroup = GFNodeStateConditionGroup.new()
	group.conditions = [passing, failing]

	group.mode = GFNodeStateConditionGroup.MatchMode.ALL
	assert_false(group.evaluate(state, &"enter"), "ALL 模式应在任一条件失败时失败。")

	group.mode = GFNodeStateConditionGroup.MatchMode.ANY
	assert_true(group.evaluate(state, &"enter"), "ANY 模式应在任一条件通过时通过。")

	group.mode = GFNodeStateConditionGroup.MatchMode.NONE
	assert_false(group.evaluate(state, &"enter"), "NONE 模式应在任一条件通过时失败。")


func test_active_condition_reads_current_and_stacked_states() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var menu: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	menu.name = "Menu"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(menu)
	await get_tree().process_frame
	machine.push_state(&"Menu")

	var condition: GFNodeStateActiveCondition = GFNodeStateActiveCondition.new()
	condition.state_paths = PackedStringArray(["Idle", "Menu"])
	condition.mode = GFNodeStateActiveCondition.MatchMode.ALL

	assert_true(condition.evaluate(menu, &"enter"), "活跃状态条件应识别当前状态和暂停栈状态。")

	condition.mode = GFNodeStateActiveCondition.MatchMode.NONE
	assert_false(condition.evaluate(menu, &"enter"), "NONE 模式应在任一目标状态处于活动状态时失败。")


func test_node_state_machine_public_restore_snapshot_restores_stack() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var menu: TrackingNodeState = TrackingNodeState.new()
	var run: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	menu.name = "Menu"
	run.name = "Run"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(menu)
	machine.add_child(run)
	await get_tree().process_frame

	machine.push_state(&"Menu")
	var snapshot: Dictionary = machine.get_state_snapshot()
	machine.transition_to(&"Run")

	var report: Dictionary = machine.restore_state_snapshot(snapshot)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "公共快照恢复入口应返回成功报告。")
	assert_eq(machine.get_current_state(), menu, "恢复后当前状态应来自快照。")
	assert_eq(machine.get_stack_depth(), 1, "恢复后暂停栈应来自快照。")
	assert_true(machine.is_in_state(&"Idle"), "恢复后暂停栈状态应仍被视为活动。")
