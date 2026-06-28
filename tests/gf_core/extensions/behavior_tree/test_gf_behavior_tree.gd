extends GutTest


func test_condition_node() -> void:
	var is_true: GFBehaviorTree.Condition = GFBehaviorTree.Condition.new(func(_bb: Dictionary) -> bool: return true)
	var is_false: GFBehaviorTree.Condition = GFBehaviorTree.Condition.new(func(_bb: Dictionary) -> bool: return false)
	
	assert_eq(is_true.tick({}), GFBehaviorTree.Status.SUCCESS)
	assert_eq(is_false.tick({}), GFBehaviorTree.Status.FAILURE)


func test_action_node() -> void:
	var bb_test: Dictionary = {"val": 0}
	var act: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["val"] = 42
		return GFBehaviorTree.Status.SUCCESS
	)
	
	assert_eq(act.tick(bb_test), GFBehaviorTree.Status.SUCCESS)
	assert_eq(GFVariantData.get_option_int(bb_test, "val"), 42)


func test_action_node_rejects_invalid_integer_status() -> void:
	var act: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return 999
	)

	assert_eq(act.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(act.last_reason, &"invalid_status", "非法 int 状态应归一为 FAILURE 并记录原因。")


func test_sequence_success() -> void:
	var act1: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS)
	var act2: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS)
	
	var seq: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([act1, act2]))
	assert_eq(seq.tick({}), GFBehaviorTree.Status.SUCCESS)


func test_sequence_failure() -> void:
	var act1: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS)
	var act2: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.FAILURE)
	
	var seq: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([act1, act2]))
	assert_eq(seq.tick({}), GFBehaviorTree.Status.FAILURE)


func test_run_selector() -> void:
	var bb_test: Dictionary = {"run_count": 0}
	var act1: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.FAILURE)
	var act2: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["run_count"] = GFVariantData.get_option_int(bb, "run_count") + 1
		return GFBehaviorTree.Status.SUCCESS
	)
	var act3: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["run_count"] = GFVariantData.get_option_int(bb, "run_count") + 10 # 这一行不应该到达
		return GFBehaviorTree.Status.SUCCESS
	)
	
	var sel: GFBehaviorTree.Selector = GFBehaviorTree.Selector.new(_nodes([act1, act2, act3]))
	assert_eq(sel.tick(bb_test), GFBehaviorTree.Status.SUCCESS)
	assert_eq(GFVariantData.get_option_int(bb_test, "run_count"), 1)


func test_inverter() -> void:
	var act_succ: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS)
	var act_fail: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.FAILURE)
	
	var inv1: GFBehaviorTree.Inverter = GFBehaviorTree.Inverter.new(act_succ)
	var inv2: GFBehaviorTree.Inverter = GFBehaviorTree.Inverter.new(act_fail)
	
	assert_eq(inv1.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(inv2.tick({}), GFBehaviorTree.Status.SUCCESS)


func test_sequence_running_state() -> void:
	var bb_test: Dictionary = {"state": "start"}
	var act1: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["state"] = "running"
		return GFBehaviorTree.Status.RUNNING
	)
	
	var seq: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([act1]))
	var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(seq)
	runner.blackboard = bb_test
	
	# 初次 tick 返回 RUNNING
	assert_eq(runner.tick(), GFBehaviorTree.Status.RUNNING)
	assert_eq(GFVariantData.get_option_string(bb_test, "state"), "running")
	
	# 第二次 tick 应该继续从处于 running 的节点开始（在本实现中直接重新 tick sequence 继续分配即可）
	assert_eq(runner.tick(), GFBehaviorTree.Status.RUNNING)


func test_parallel_require_all_waits_for_running_children() -> void:
	var state: Dictionary = { "first": GFBehaviorTree.Status.RUNNING }
	var running: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFVariantData.get_option_int(state, "first")
	)
	var success: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	var parallel: GFBehaviorTree.Parallel = GFBehaviorTree.Parallel.new(
		_nodes([running, success]),
		GFBehaviorTree.ParallelPolicy.REQUIRE_ALL
	)

	assert_eq(parallel.tick({}), GFBehaviorTree.Status.RUNNING)
	state["first"] = GFBehaviorTree.Status.SUCCESS
	assert_eq(parallel.tick({}), GFBehaviorTree.Status.SUCCESS)


func test_parallel_require_all_does_not_retick_completed_children_while_running() -> void:
	var state: Dictionary = {
		"running_status": GFBehaviorTree.Status.RUNNING,
		"success_ticks": 0,
	}
	var running: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFVariantData.get_option_int(state, "running_status")
	)
	var success: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["success_ticks"] = GFVariantData.get_option_int(bb, "success_ticks") + 1
		return GFBehaviorTree.Status.SUCCESS
	)
	var parallel: GFBehaviorTree.Parallel = GFBehaviorTree.Parallel.new(
		_nodes([running, success]),
		GFBehaviorTree.ParallelPolicy.REQUIRE_ALL
	)

	assert_eq(parallel.tick(state), GFBehaviorTree.Status.RUNNING)
	assert_eq(parallel.tick(state), GFBehaviorTree.Status.RUNNING)
	state["running_status"] = GFBehaviorTree.Status.SUCCESS
	assert_eq(parallel.tick(state), GFBehaviorTree.Status.SUCCESS)
	assert_eq(GFVariantData.get_option_int(state, "success_ticks"), 1, "已成功的并行子节点不应在同一轮运行中重复 tick。")


func test_parallel_require_all_propagates_aborted_status() -> void:
	var aborted: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.ABORTED
	)
	var success: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	var parallel: GFBehaviorTree.Parallel = GFBehaviorTree.Parallel.new(
		_nodes([aborted, success]),
		GFBehaviorTree.ParallelPolicy.REQUIRE_ALL
	)

	assert_eq(parallel.tick({}), GFBehaviorTree.Status.ABORTED, "ABORTED 不应被 REQUIRE_ALL 误判为 SUCCESS。")
	assert_eq(parallel.last_reason, &"aborted")


func test_parallel_require_one_succeeds_when_any_child_succeeds() -> void:
	var fail: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.FAILURE
	)
	var success: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	var parallel: GFBehaviorTree.Parallel = GFBehaviorTree.Parallel.new(
		_nodes([fail, success]),
		GFBehaviorTree.ParallelPolicy.REQUIRE_ONE
	)

	assert_eq(parallel.tick({}), GFBehaviorTree.Status.SUCCESS)


func test_parallel_require_one_does_not_retick_failed_children_while_running() -> void:
	var state: Dictionary = {
		"running_status": GFBehaviorTree.Status.RUNNING,
		"failure_ticks": 0,
	}
	var fail: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["failure_ticks"] = GFVariantData.get_option_int(bb, "failure_ticks") + 1
		return GFBehaviorTree.Status.FAILURE
	)
	var running: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFVariantData.get_option_int(state, "running_status")
	)
	var parallel: GFBehaviorTree.Parallel = GFBehaviorTree.Parallel.new(
		_nodes([fail, running]),
		GFBehaviorTree.ParallelPolicy.REQUIRE_ONE
	)

	assert_eq(parallel.tick(state), GFBehaviorTree.Status.RUNNING)
	assert_eq(parallel.tick(state), GFBehaviorTree.Status.RUNNING)
	state["running_status"] = GFBehaviorTree.Status.FAILURE
	assert_eq(parallel.tick(state), GFBehaviorTree.Status.FAILURE)
	assert_eq(GFVariantData.get_option_int(state, "failure_ticks"), 1, "已失败的并行子节点不应在同一轮运行中重复 tick。")

	state["running_status"] = GFBehaviorTree.Status.SUCCESS
	assert_eq(parallel.tick(state), GFBehaviorTree.Status.SUCCESS, "终止失败后下一轮应重新评估子节点。")
	assert_eq(GFVariantData.get_option_int(state, "failure_ticks"), 2)


func test_random_sequence_uses_sequence_semantics() -> void:
	var state: Dictionary = { "count": 0 }
	var first: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["count"] = GFVariantData.get_option_int(bb, "count") + 1
		return GFBehaviorTree.Status.SUCCESS
	)
	var second: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["count"] = GFVariantData.get_option_int(bb, "count") + 1
		return GFBehaviorTree.Status.SUCCESS
	)
	var random_sequence: GFBehaviorTree.RandomSequence = GFBehaviorTree.RandomSequence.new(
		_nodes([first, second])
	)

	assert_eq(random_sequence.tick(state), GFBehaviorTree.Status.SUCCESS)
	assert_eq(GFVariantData.get_option_int(state, "count"), 2)


func test_random_sequence_can_use_seeded_rng_for_reproducible_order() -> void:
	var first_order: Array = _run_random_sequence_with_seed(1234)
	var second_order: Array = _run_random_sequence_with_seed(1234)

	assert_eq(first_order, second_order, "相同随机种子应产生一致的随机顺序。")
	assert_eq(_count_unique(first_order), 3)


func test_random_selector_can_use_blackboard_rng() -> void:
	var first_state: Dictionary = {
		"rng": _make_rng(77),
		"order": [],
	}
	var second_state: Dictionary = {
		"rng": _make_rng(77),
		"order": [],
	}
	var first_selector: GFBehaviorTree.RandomSelector = GFBehaviorTree.RandomSelector.new(_nodes([
		_make_recording_action("A", GFBehaviorTree.Status.FAILURE),
		_make_recording_action("B", GFBehaviorTree.Status.FAILURE),
		_make_recording_action("C", GFBehaviorTree.Status.SUCCESS),
	]))
	var second_selector: GFBehaviorTree.RandomSelector = GFBehaviorTree.RandomSelector.new(_nodes([
		_make_recording_action("A", GFBehaviorTree.Status.FAILURE),
		_make_recording_action("B", GFBehaviorTree.Status.FAILURE),
		_make_recording_action("C", GFBehaviorTree.Status.SUCCESS),
	]))

	assert_eq(first_selector.tick(first_state), GFBehaviorTree.Status.SUCCESS)
	assert_eq(second_selector.tick(second_state), GFBehaviorTree.Status.SUCCESS)
	assert_eq(GFVariantData.get_option_array(first_state, "order"), GFVariantData.get_option_array(second_state, "order"))


func test_random_selector_uses_selector_semantics() -> void:
	var fail: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.FAILURE
	)
	var success: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	var random_selector: GFBehaviorTree.RandomSelector = GFBehaviorTree.RandomSelector.new(
		_nodes([fail, success])
	)

	assert_eq(random_selector.tick({}), GFBehaviorTree.Status.SUCCESS)


func test_always_succeed_and_always_fail_preserve_running() -> void:
	var running: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.RUNNING
	)
	var fail: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.FAILURE
	)
	var success: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)

	assert_eq(GFBehaviorTree.AlwaysSucceed.new(fail).tick({}), GFBehaviorTree.Status.SUCCESS)
	assert_eq(GFBehaviorTree.AlwaysFail.new(success).tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(GFBehaviorTree.AlwaysSucceed.new(running).tick({}), GFBehaviorTree.Status.RUNNING)
	assert_eq(GFBehaviorTree.AlwaysFail.new(running).tick({}), GFBehaviorTree.Status.RUNNING)


func test_decorators_propagate_aborted_status() -> void:
	var aborted: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.ABORTED
	)

	assert_eq(GFBehaviorTree.Inverter.new(aborted).tick({}), GFBehaviorTree.Status.ABORTED)
	assert_eq(GFBehaviorTree.AlwaysSucceed.new(aborted).tick({}), GFBehaviorTree.Status.ABORTED)
	assert_eq(GFBehaviorTree.AlwaysFail.new(aborted).tick({}), GFBehaviorTree.Status.ABORTED)
	assert_eq(GFBehaviorTree.Repeat.new(aborted, 2).tick({}), GFBehaviorTree.Status.ABORTED)
	assert_eq(GFBehaviorTree.UntilSuccess.new(aborted).tick({}), GFBehaviorTree.Status.ABORTED)
	assert_eq(GFBehaviorTree.UntilFail.new(aborted).tick({}), GFBehaviorTree.Status.ABORTED)


func test_composite_nodes_own_child_array_snapshot() -> void:
	var success: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	var children: Array[GFBehaviorTree.BTNode] = _nodes([success])
	var sequence: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(children)
	children.clear()

	assert_eq(sequence.tick({}), GFBehaviorTree.Status.SUCCESS, "构造后外部数组突变不应改变已构造树拓扑。")


func test_decorator_rejects_self_cycle() -> void:
	var inverter: GFBehaviorTree.Inverter = GFBehaviorTree.Inverter.new(null)
	var _set_result: GFBehaviorTree.Decorator = inverter.set_child(inverter)

	assert_eq(inverter.tick({}), GFBehaviorTree.Status.FAILURE, "set_child(self) 应被拒绝并保留 missing_child 行为。")
	assert_eq(inverter.last_reason, &"missing_child")
	assert_push_error("[GFBehaviorTree] 拒绝设置会形成循环的 decorator 子节点。")


func test_limit_blocks_after_max_ticks() -> void:
	var state: Dictionary = { "count": 0 }
	var child: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["count"] = GFVariantData.get_option_int(bb, "count") + 1
		return GFBehaviorTree.Status.SUCCESS
	)
	var limit: GFBehaviorTree.Limit = GFBehaviorTree.Limit.new(child, 2)

	assert_eq(limit.tick(state), GFBehaviorTree.Status.SUCCESS)
	assert_eq(limit.tick(state), GFBehaviorTree.Status.SUCCESS)
	assert_eq(limit.tick(state), GFBehaviorTree.Status.FAILURE)
	assert_eq(GFVariantData.get_option_int(state, "count"), 2)


func test_limit_resets_running_child_when_limit_is_exceeded() -> void:
	var child: ResetCountingNode = ResetCountingNode.new()
	var limit: GFBehaviorTree.Limit = GFBehaviorTree.Limit.new(child, 1)

	assert_eq(limit.tick({}), GFBehaviorTree.Status.RUNNING)
	assert_eq(limit.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(child.reset_count, 1, "Limit 终止 RUNNING 子节点时应 reset 子节点运行态。")


func test_repeat_returns_success_after_count() -> void:
	var state: Dictionary = { "count": 0 }
	var child: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["count"] = GFVariantData.get_option_int(bb, "count") + 1
		return GFBehaviorTree.Status.SUCCESS
	)
	var repeat: GFBehaviorTree.Repeat = GFBehaviorTree.Repeat.new(child, 3)

	assert_eq(repeat.tick(state), GFBehaviorTree.Status.RUNNING)
	assert_eq(repeat.tick(state), GFBehaviorTree.Status.RUNNING)
	assert_eq(repeat.tick(state), GFBehaviorTree.Status.SUCCESS)
	assert_eq(GFVariantData.get_option_int(state, "count"), 3)


func test_until_success_and_until_fail() -> void:
	var success_state: Dictionary = { "count": 0 }
	var eventually_success: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["count"] = GFVariantData.get_option_int(bb, "count") + 1
		return GFBehaviorTree.Status.SUCCESS if GFVariantData.get_option_int(bb, "count") >= 2 else GFBehaviorTree.Status.FAILURE
	)
	var until_success: GFBehaviorTree.UntilSuccess = GFBehaviorTree.UntilSuccess.new(eventually_success)

	assert_eq(until_success.tick(success_state), GFBehaviorTree.Status.RUNNING)
	assert_eq(until_success.tick(success_state), GFBehaviorTree.Status.SUCCESS)

	var fail_state: Dictionary = { "count": 0 }
	var eventually_fail: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["count"] = GFVariantData.get_option_int(bb, "count") + 1
		return GFBehaviorTree.Status.FAILURE if GFVariantData.get_option_int(bb, "count") >= 2 else GFBehaviorTree.Status.SUCCESS
	)
	var until_fail: GFBehaviorTree.UntilFail = GFBehaviorTree.UntilFail.new(eventually_fail)

	assert_eq(until_fail.tick(fail_state), GFBehaviorTree.Status.RUNNING)
	assert_eq(until_fail.tick(fail_state), GFBehaviorTree.Status.SUCCESS)


func test_runner_debug_snapshot_records_status_and_blackboard_keys() -> void:
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	action.node_id = &"root_action"
	var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(action)
	runner.blackboard["target"] = "value"

	assert_eq(runner.tick(), GFBehaviorTree.Status.SUCCESS)
	var snapshot: Dictionary = runner.get_debug_snapshot()
	var root: Dictionary = GFVariantData.get_option_dictionary(snapshot, "root")

	assert_eq(GFVariantData.get_option_string_name(root, "node_id"), &"root_action", "调试快照应包含节点标识。")
	assert_eq(GFVariantData.get_option_string_name(root, "status_text"), &"success", "调试快照应记录最近状态。")
	assert_eq(GFVariantData.get_option_packed_string_array(snapshot, "blackboard_keys"), PackedStringArray(["target"]), "运行器快照应列出黑板键。")


func test_blackboard_scope_overlays_parent_values() -> void:
	var parent: GFBehaviorTree.BlackboardScope = GFBehaviorTree.BlackboardScope.new({ &"speed": 3, &"mode": "base" })
	var child: GFBehaviorTree.BlackboardScope = GFBehaviorTree.BlackboardScope.new({ &"speed": 5 }, parent)
	var data: Dictionary = child.to_dictionary()

	assert_eq(GFVariantData.to_int(child.get_value(&"speed")), 5, "子作用域应覆盖父级值。")
	assert_eq(GFVariantData.to_text(child.get_value(&"mode")), "base", "缺失值应回退到父作用域。")
	assert_eq(GFVariantData.get_option_int(data, &"speed"), 5, "合并字典应保留覆盖后的值。")


func test_blackboard_scope_returns_deep_snapshots_for_nested_values() -> void:
	var parent: GFBehaviorTree.BlackboardScope = GFBehaviorTree.BlackboardScope.new({
		&"target": {
			"hp": 10,
		},
	})
	var child: GFBehaviorTree.BlackboardScope = GFBehaviorTree.BlackboardScope.new({}, parent)
	var data: Dictionary = child.to_dictionary()
	var target_data: Dictionary = GFVariantData.get_option_dictionary(data, &"target")
	target_data["hp"] = 0
	var stored_target: Dictionary = GFVariantData.as_dictionary(child.get_value(&"target"))

	assert_eq(GFVariantData.get_option_int(stored_target, "hp"), 10, "修改合并字典的嵌套值不应污染 scope。")


func test_probability_cooldown_and_time_limit_decorators() -> void:
	var rng: RandomNumberGenerator = _make_rng(1)
	var action_count: Dictionary = { "value": 0 }
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["value"] = GFVariantData.get_option_int(bb, "value") + 1
		return GFBehaviorTree.Status.SUCCESS
	)
	var probability: GFBehaviorTree.Probability = GFBehaviorTree.Probability.new(action, 1.0, rng)
	var cooldown: GFBehaviorTree.Cooldown = GFBehaviorTree.Cooldown.new(probability, 1.0)

	assert_eq(cooldown.tick({ "value": GFVariantData.get_option_int(action_count, "value"), "time_msec": 1000 }), GFBehaviorTree.Status.SUCCESS)
	assert_eq(cooldown.tick({ "value": GFVariantData.get_option_int(action_count, "value"), "time_msec": 1200 }), GFBehaviorTree.Status.FAILURE)

	var running: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.RUNNING
	)
	var limited: GFBehaviorTree.TimeLimit = GFBehaviorTree.TimeLimit.new(running, 0.5)

	assert_eq(limited.tick({ "time_msec": 1000 }), GFBehaviorTree.Status.RUNNING)
	assert_eq(limited.tick({ "time_msec": 1601 }), GFBehaviorTree.Status.FAILURE)


func test_cooldown_survives_parent_runtime_reset() -> void:
	var action_count: Dictionary = { "value": 0 }
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		action_count["value"] = GFVariantData.get_option_int(action_count, "value") + 1
		return GFBehaviorTree.Status.SUCCESS
	)
	var cooldown: GFBehaviorTree.Cooldown = GFBehaviorTree.Cooldown.new(action, 1.0)
	var sequence: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([cooldown]))

	assert_eq(sequence.tick({ "time_msec": 1000 }), GFBehaviorTree.Status.SUCCESS)
	assert_eq(sequence.tick({ "time_msec": 1200 }), GFBehaviorTree.Status.FAILURE)
	assert_eq(GFVariantData.get_option_int(action_count, "value"), 1, "父节点完成后的 reset 不应清空 Cooldown。")

	cooldown.clear_cooldown()

	assert_eq(sequence.tick({ "time_msec": 1200 }), GFBehaviorTree.Status.SUCCESS, "显式清空冷却后应允许下一轮执行。")


func test_runner_duplicates_runtime_tree_by_default() -> void:
	var action_count: Dictionary = { "value": 0 }
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		action_count["value"] = GFVariantData.get_option_int(action_count, "value") + 1
		return GFBehaviorTree.Status.SUCCESS
	)
	var limited: GFBehaviorTree.Limit = GFBehaviorTree.Limit.new(action, 1)
	var first_runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(limited)
	var second_runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(limited)

	assert_eq(first_runner.tick(), GFBehaviorTree.Status.SUCCESS, "第一个 Runner 应能执行一次。")
	assert_eq(second_runner.tick(), GFBehaviorTree.Status.SUCCESS, "第二个 Runner 应使用独立运行副本。")
	assert_eq(limited.tick({}), GFBehaviorTree.Status.SUCCESS, "原始树不应被 Runner 消耗内部运行态。")
	assert_eq(GFVariantData.get_option_int(action_count, "value"), 3, "两个 Runner 和原始树应各自执行一次叶子动作。")


func test_runner_preserves_custom_node_behavior_without_duplicate_override() -> void:
	var custom_node: CustomCountingNode = CustomCountingNode.new()
	var sequence: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([custom_node]))
	var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(sequence)

	assert_eq(runner.tick(), GFBehaviorTree.Status.SUCCESS, "Runner 默认复制运行树时仍应执行自定义节点逻辑。")
	assert_eq(custom_node.tick_count_value, 1, "未重写 duplicate_runtime() 的自定义节点不应被降级为基础 BTNode。")


func test_probability_keeps_decision_while_child_is_running() -> void:
	var action_count: Dictionary = { "value": 0 }
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		action_count["value"] = GFVariantData.get_option_int(action_count, "value") + 1
		return GFBehaviorTree.Status.RUNNING if GFVariantData.get_option_int(action_count, "value") == 1 else GFBehaviorTree.Status.SUCCESS
	)
	var probability: GFBehaviorTree.Probability = GFBehaviorTree.Probability.new(action, 1.0)

	assert_eq(probability.tick({}), GFBehaviorTree.Status.RUNNING)
	probability.probability = 0.0

	assert_eq(probability.tick({}), GFBehaviorTree.Status.SUCCESS, "RUNNING 子节点应沿用本轮已命中的概率判定。")
	assert_eq(probability.tick({}), GFBehaviorTree.Status.FAILURE, "终态后下一轮应重新抽取概率。")


func test_debug_snapshot_counts_each_tick_once_and_preserves_terminal_status() -> void:
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(action)

	assert_eq(runner.tick(), GFBehaviorTree.Status.SUCCESS)
	var snapshot: Dictionary = runner.get_debug_snapshot()
	var root: Dictionary = GFVariantData.get_option_dictionary(snapshot, "root")

	assert_eq(GFVariantData.get_option_int(root, "tick_count"), 1, "Runner 不应对根节点重复记录 tick。")
	assert_eq(GFVariantData.get_option_string_name(root, "status_text"), &"success", "终态 reset 不应清空最近调试状态。")

	runner.clear_debug_state()
	root = GFVariantData.get_option_dictionary(runner.get_debug_snapshot(), "root")

	assert_eq(GFVariantData.get_option_int(root, "tick_count"), 0, "显式清空调试状态应重置 tick 计数。")
	assert_eq(GFVariantData.get_option_string_name(root, "status_text"), &"fresh", "显式清空调试状态应恢复 FRESH。")


func _run_random_sequence_with_seed(seed_value: int) -> Array:
	var state: Dictionary = { "order": [] }
	var random_sequence: GFBehaviorTree.RandomSequence = GFBehaviorTree.RandomSequence.new(_nodes([
		_make_recording_action("A"),
		_make_recording_action("B"),
		_make_recording_action("C"),
	]), _make_rng(seed_value))

	assert_eq(random_sequence.tick(state), GFBehaviorTree.Status.SUCCESS)
	return GFVariantData.get_option_array(state, "order")


func _make_recording_action(
	label: String,
	status: int = GFBehaviorTree.Status.SUCCESS
) -> GFBehaviorTree.Action:
	return GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		var order: Array = GFVariantData.get_option_array(bb, "order")
		order.append(label)
		bb["order"] = order
		return status
	)


func _make_rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _count_unique(values: Array) -> int:
	var lookup: Dictionary = {}
	for value: Variant in values:
		lookup[value] = true
	return lookup.size()


func _nodes(nodes: Array[GFBehaviorTree.BTNode]) -> Array[GFBehaviorTree.BTNode]:
	return nodes


class CustomCountingNode extends GFBehaviorTree.BTNode:
	var tick_count_value: int = 0

	func tick(_blackboard: Dictionary) -> int:
		tick_count_value += 1
		return _record_tick(GFBehaviorTree.Status.SUCCESS)


class ResetCountingNode extends GFBehaviorTree.BTNode:
	var reset_count: int = 0

	func tick(_blackboard: Dictionary) -> int:
		return _record_tick(GFBehaviorTree.Status.RUNNING)

	func reset() -> void:
		reset_count += 1
		super.reset()
