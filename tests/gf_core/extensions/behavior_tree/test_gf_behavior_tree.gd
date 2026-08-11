extends GutTest


func test_condition_node() -> void:
	var is_true: GFBehaviorTree.Condition = GFBehaviorTree.Condition.new(func(_bb: Dictionary) -> bool: return true)
	var is_false: GFBehaviorTree.Condition = GFBehaviorTree.Condition.new(func(_bb: Dictionary) -> bool: return false)
	
	assert_eq(is_true.tick({}), GFBehaviorTree.Status.SUCCESS)
	assert_eq(is_false.tick({}), GFBehaviorTree.Status.FAILURE)


func test_condition_node_rejects_non_bool_result() -> void:
	var invalid_condition: GFBehaviorTree.Condition = GFBehaviorTree.Condition.new(func(_bb: Dictionary) -> String: return "yes")

	assert_eq(invalid_condition.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(invalid_condition.last_reason, &"invalid_condition_result", "非 bool 条件结果应被标记为非法结果。")


func test_condition_node_distinguishes_invalid_callable_from_false() -> void:
	var invalid_condition: GFBehaviorTree.Condition = GFBehaviorTree.Condition.new(Callable())

	assert_eq(invalid_condition.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(
		invalid_condition.last_reason,
		&"invalid_condition",
		"无效 Callable 是生命周期/配置错误，不应伪装成合法 condition_false。"
	)


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


func test_action_node_rejects_invalid_non_integer_status() -> void:
	var act: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> String: return "success")

	assert_eq(act.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(act.last_reason, &"invalid_status", "非 int 状态应归一为 FAILURE 并记录非法状态原因。")


func test_action_node_rejects_fresh_as_tick_result() -> void:
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.FRESH
	)

	assert_eq(action.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(action.last_reason, &"invalid_status", "FRESH 只表示未执行状态，不能作为 tick 结果。")


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


func test_decorator_resets_previous_running_child_before_replacement() -> void:
	var previous_child: ResetCountingNode = ResetCountingNode.new()
	var replacement: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	var inverter: GFBehaviorTree.Inverter = GFBehaviorTree.Inverter.new(previous_child)

	assert_eq(inverter.tick({}), GFBehaviorTree.Status.RUNNING)
	var _set_result: GFBehaviorTree.Decorator = inverter.set_child(replacement)

	assert_eq(previous_child.reset_count, 1, "拓扑替换前必须结束旧 child 的运行态。")
	assert_eq(inverter.tick({}), GFBehaviorTree.Status.FAILURE, "替换完成后只能推进新 child。")


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


func test_until_decorators_reset_child_before_retrying_terminal_mismatch() -> void:
	var success_child: StatusSequenceNode = StatusSequenceNode.new([
		GFBehaviorTree.Status.FAILURE,
		GFBehaviorTree.Status.SUCCESS,
	])
	var until_success: GFBehaviorTree.UntilSuccess = GFBehaviorTree.UntilSuccess.new(success_child)

	assert_eq(until_success.tick({}), GFBehaviorTree.Status.RUNNING)
	assert_eq(success_child.reset_count, 1, "UntilSuccess 子节点失败后重试前应 reset。")
	assert_eq(until_success.tick({}), GFBehaviorTree.Status.SUCCESS)

	var fail_child: StatusSequenceNode = StatusSequenceNode.new([
		GFBehaviorTree.Status.SUCCESS,
		GFBehaviorTree.Status.FAILURE,
	])
	var until_fail: GFBehaviorTree.UntilFail = GFBehaviorTree.UntilFail.new(fail_child)

	assert_eq(until_fail.tick({}), GFBehaviorTree.Status.RUNNING)
	assert_eq(fail_child.reset_count, 1, "UntilFail 子节点成功后重试前应 reset。")
	assert_eq(until_fail.tick({}), GFBehaviorTree.Status.SUCCESS)


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


func test_blackboard_scope_rejects_parent_cycles() -> void:
	var parent: GFBehaviorTree.BlackboardScope = GFBehaviorTree.BlackboardScope.new({ &"mode": "base" })
	var child: GFBehaviorTree.BlackboardScope = GFBehaviorTree.BlackboardScope.new({ &"speed": 5 }, parent)

	parent.parent = child

	assert_eq(parent.parent, null, "会形成二节点循环的 parent 应被拒绝。")
	assert_eq(GFVariantData.to_text(child.get_value(&"mode")), "base", "拒绝循环后原有父链应保持可读。")
	assert_push_error("[GFBehaviorTree] 拒绝设置会形成循环的 BlackboardScope parent。")

	child.parent = child

	assert_eq(child.parent, parent, "自环 parent 应被拒绝并保留原 parent。")
	assert_push_error("[GFBehaviorTree] 拒绝设置会形成循环的 BlackboardScope parent。")


func test_probability_cooldown_and_time_limit_decorators() -> void:
	var clock_state: Dictionary = { "msec": 1000 }
	var clock: Callable = _make_test_clock(clock_state)
	var rng: RandomNumberGenerator = _make_rng(1)
	var action_count: Dictionary = { "value": 0 }
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(bb: Dictionary) -> int:
		bb["value"] = GFVariantData.get_option_int(bb, "value") + 1
		return GFBehaviorTree.Status.SUCCESS
	)
	var probability: GFBehaviorTree.Probability = GFBehaviorTree.Probability.new(action, 1.0, rng)
	var cooldown: GFBehaviorTree.Cooldown = GFBehaviorTree.Cooldown.new(probability, 1.0, clock)

	assert_eq(cooldown.tick({ "value": GFVariantData.get_option_int(action_count, "value") }), GFBehaviorTree.Status.SUCCESS)
	clock_state["msec"] = 1200
	assert_eq(cooldown.tick({ "value": GFVariantData.get_option_int(action_count, "value") }), GFBehaviorTree.Status.FAILURE)

	var running: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.RUNNING
	)
	var limited_clock_state: Dictionary = { "msec": 1000 }
	var limited: GFBehaviorTree.TimeLimit = GFBehaviorTree.TimeLimit.new(
		running,
		0.5,
		_make_test_clock(limited_clock_state)
	)

	assert_eq(limited.tick({}), GFBehaviorTree.Status.RUNNING)
	limited_clock_state["msec"] = 1601
	assert_eq(limited.tick({}), GFBehaviorTree.Status.FAILURE)


func test_time_limit_zero_fails_before_ticking_child() -> void:
	var child: StatusSequenceNode = StatusSequenceNode.new([GFBehaviorTree.Status.SUCCESS])
	var limited: GFBehaviorTree.TimeLimit = GFBehaviorTree.TimeLimit.new(
		child,
		0.0,
		_make_test_clock({ "msec": 1000 })
	)

	assert_eq(limited.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(child.tick_count_value, 0, "TimeLimit(0) 不应先执行一次子节点。")
	assert_eq(child.reset_count, 1, "TimeLimit(0) 应重置子节点运行态。")


func test_cooldown_starts_after_condition_false_terminal_result() -> void:
	var clock_state: Dictionary = { "msec": 1000 }
	var condition_count: Dictionary = { "value": 0 }
	var condition: GFBehaviorTree.Condition = GFBehaviorTree.Condition.new(func(_bb: Dictionary) -> bool:
		condition_count["value"] = GFVariantData.get_option_int(condition_count, "value") + 1
		return false
	)
	var cooldown: GFBehaviorTree.Cooldown = GFBehaviorTree.Cooldown.new(
		condition,
		1.0,
		_make_test_clock(clock_state)
	)

	assert_eq(cooldown.tick({}), GFBehaviorTree.Status.FAILURE)
	clock_state["msec"] = 1200
	assert_eq(cooldown.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(cooldown.last_reason, &"cooldown_active", "普通失败终态后应进入冷却期。")
	assert_eq(GFVariantData.get_option_int(condition_count, "value"), 1, "冷却期内不应重复 tick 子条件。")


func test_cooldown_starts_after_child_tick_finishes() -> void:
	var clock_state: Dictionary = { "msec": 1000 }
	var action_count: Dictionary = { "value": 0 }
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		action_count["value"] = GFVariantData.get_option_int(action_count, "value") + 1
		clock_state["msec"] = 5000
		return GFBehaviorTree.Status.SUCCESS
	)
	var cooldown: GFBehaviorTree.Cooldown = GFBehaviorTree.Cooldown.new(
		action,
		1.0,
		_make_test_clock(clock_state)
	)

	assert_eq(cooldown.tick({}), GFBehaviorTree.Status.SUCCESS)
	assert_eq(cooldown.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(cooldown.last_reason, &"cooldown_active")
	clock_state["msec"] = 5999
	assert_eq(cooldown.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(GFVariantData.get_option_int(action_count, "value"), 1, "子节点耗时不得抵扣完成后的冷却窗口。")
	clock_state["msec"] = 6000
	assert_eq(cooldown.tick({}), GFBehaviorTree.Status.SUCCESS)
	assert_eq(GFVariantData.get_option_int(action_count, "value"), 2)


func test_cooldown_survives_parent_runtime_reset() -> void:
	var clock_state: Dictionary = { "msec": 1000 }
	var action_count: Dictionary = { "value": 0 }
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		action_count["value"] = GFVariantData.get_option_int(action_count, "value") + 1
		return GFBehaviorTree.Status.SUCCESS
	)
	var cooldown: GFBehaviorTree.Cooldown = GFBehaviorTree.Cooldown.new(
		action,
		1.0,
		_make_test_clock(clock_state)
	)
	var sequence: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([cooldown]))

	assert_eq(sequence.tick({}), GFBehaviorTree.Status.SUCCESS)
	clock_state["msec"] = 1200
	assert_eq(sequence.tick({}), GFBehaviorTree.Status.FAILURE)
	assert_eq(GFVariantData.get_option_int(action_count, "value"), 1, "父节点完成后的 reset 不应清空 Cooldown。")

	cooldown.clear_cooldown()

	assert_eq(sequence.tick({}), GFBehaviorTree.Status.SUCCESS, "显式清空冷却后应允许下一轮执行。")


func test_cooldown_resets_terminal_child_before_next_attempt() -> void:
	var clock_state: Dictionary = { "msec": 1000 }
	var child: ResettableAttemptNode = ResettableAttemptNode.new()
	var cooldown: GFBehaviorTree.Cooldown = GFBehaviorTree.Cooldown.new(
		child,
		1.0,
		_make_test_clock(clock_state)
	)

	assert_eq(cooldown.tick({}), GFBehaviorTree.Status.RUNNING)
	clock_state["msec"] = 1001
	assert_eq(cooldown.tick({}), GFBehaviorTree.Status.SUCCESS)
	assert_eq(child.reset_count, 1, "子节点终态后必须结束本轮运行态。")
	clock_state["msec"] = 2001
	assert_eq(cooldown.tick({}), GFBehaviorTree.Status.RUNNING, "冷却后的下一次执行必须从新尝试开始。")


func test_time_limit_clamps_injected_clock_rollback() -> void:
	var clock_state: Dictionary = { "msec": 1000 }
	var child: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.RUNNING
	)
	var limited: GFBehaviorTree.TimeLimit = GFBehaviorTree.TimeLimit.new(
		child,
		0.5,
		_make_test_clock(clock_state)
	)

	assert_eq(limited.tick({}), GFBehaviorTree.Status.RUNNING)
	clock_state["msec"] = 900
	assert_eq(limited.tick({}), GFBehaviorTree.Status.RUNNING, "时钟回拨不能倒退已观察时间。")
	clock_state["msec"] = 1499
	assert_eq(limited.tick({}), GFBehaviorTree.Status.RUNNING)
	clock_state["msec"] = 1500
	assert_eq(limited.tick({}), GFBehaviorTree.Status.FAILURE)


func test_time_decorators_reject_non_finite_durations() -> void:
	var child: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	var cooldown: GFBehaviorTree.Cooldown = GFBehaviorTree.Cooldown.new(child, NAN)
	var limited: GFBehaviorTree.TimeLimit = GFBehaviorTree.TimeLimit.new(child, INF)

	assert_eq(cooldown.cooldown_seconds, 0.0)
	assert_eq(limited.limit_seconds, 1.0)
	cooldown.cooldown_seconds = INF
	limited.limit_seconds = NAN
	assert_eq(cooldown.cooldown_seconds, 0.0, "非法赋值应保留最后一个有效冷却时长。")
	assert_eq(limited.limit_seconds, 1.0, "非法赋值应保留最后一个有效时间限制。")


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


func test_runner_normalizes_invalid_root_tick_results() -> void:
	var invalid_root: RawStatusNode = RawStatusNode.new(999)
	var fresh_root: RawStatusNode = RawStatusNode.new(GFBehaviorTree.Status.FRESH)

	assert_eq(GFBehaviorTree.Runner.new(invalid_root, false).tick(), GFBehaviorTree.Status.FAILURE)
	assert_eq(invalid_root.last_reason, &"invalid_status")
	assert_eq(GFBehaviorTree.Runner.new(fresh_root, false).tick(), GFBehaviorTree.Status.FAILURE)
	assert_eq(fresh_root.last_reason, &"invalid_status")


func test_runner_rejects_custom_node_without_duplicate_override() -> void:
	var custom_node: CustomCountingNode = CustomCountingNode.new()
	var sequence: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([custom_node]))
	var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(sequence)

	assert_eq(runner.tick(), GFBehaviorTree.Status.FAILURE, "未重写 duplicate_runtime() 的自定义节点不应在默认复制模式下静默共享运行态。")
	assert_eq(custom_node.tick_count_value, 0, "无法复制的自定义节点不应污染原始定义节点。")
	assert_push_error("[GFBehaviorTree] BTNode 子类必须重写 duplicate_runtime() 才能被 Runner 默认复制；请返回独立运行副本，或显式创建 Runner(root, false) 共享运行树。")


func test_runner_rejects_concrete_node_subclass_without_duplicate_override() -> void:
	var custom_sequence: CustomSequenceWithoutDuplicate = CustomSequenceWithoutDuplicate.new()
	var definition: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([custom_sequence]))
	var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(definition)

	assert_eq(
		runner.tick(),
		GFBehaviorTree.Status.FAILURE,
		"继承具体内置节点时也不得被 duplicate_runtime() 静默切片为基类。"
	)
	var root_snapshot: Dictionary = GFVariantData.get_option_dictionary(
		runner.get_debug_snapshot(),
		"root"
	)
	assert_eq(
		GFVariantData.get_option_string_name(root_snapshot, "reason"),
		&"runtime_duplicate_missing_override"
	)
	assert_eq(custom_sequence.custom_tick_count, 0, "失败关闭不得执行原始定义节点。")
	assert_push_error(
		"[GFBehaviorTree] duplicate_runtime() 必须返回保持动态脚本类型的独立节点；具体内置节点的自定义子类也必须显式重写。"
	)


func test_runner_accepts_every_builtin_runtime_duplicate_type() -> void:
	var success_action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	var definitions: Array[GFBehaviorTree.BTNode] = _nodes([
		GFBehaviorTree.Sequence.new([]),
		GFBehaviorTree.Selector.new([]),
		GFBehaviorTree.Parallel.new([]),
		GFBehaviorTree.RandomSelector.new([]),
		GFBehaviorTree.RandomSequence.new([]),
		success_action,
		GFBehaviorTree.Condition.new(func(_bb: Dictionary) -> bool: return true),
		GFBehaviorTree.Decorator.new(null),
		GFBehaviorTree.Inverter.new(success_action),
		GFBehaviorTree.AlwaysSucceed.new(success_action),
		GFBehaviorTree.AlwaysFail.new(success_action),
		GFBehaviorTree.Probability.new(success_action),
		GFBehaviorTree.Cooldown.new(success_action),
		GFBehaviorTree.TimeLimit.new(success_action),
		GFBehaviorTree.Limit.new(success_action),
		GFBehaviorTree.Repeat.new(success_action),
		GFBehaviorTree.UntilSuccess.new(success_action),
		GFBehaviorTree.UntilFail.new(success_action),
	])

	for definition: GFBehaviorTree.BTNode in definitions:
		var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(definition)
		var root: Dictionary = GFVariantData.get_option_dictionary(
			runner.get_debug_snapshot(),
			"root"
		)
		assert_ne(
			GFVariantData.get_option_string_name(root, "reason"),
			&"runtime_duplicate_missing_override",
			"内置节点 duplicate_runtime() 必须保持自己的动态脚本类型：%s" % definition.name
		)


func test_runner_rejects_synchronous_reentrant_tick() -> void:
	var node: ReentrantRunnerNode = ReentrantRunnerNode.new()
	var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(node, false)
	node.runner = runner

	var status: int = runner.tick()
	node.runner = null

	assert_eq(status, GFBehaviorTree.Status.ABORTED)
	assert_eq(node.tick_call_count, 1, "同步重入必须在第二次推进根节点前失败关闭。")
	assert_push_error("[GFBehaviorTree] Runner.tick() 不允许同步重入。")


func test_runner_isolates_custom_node_when_duplicate_runtime_is_implemented() -> void:
	var custom_node: DuplicatingCountingNode = DuplicatingCountingNode.new()
	var sequence: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([custom_node]))
	var first_runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(sequence)
	var second_runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(sequence)

	assert_eq(first_runner.tick(), GFBehaviorTree.Status.RUNNING)
	assert_eq(second_runner.tick(), GFBehaviorTree.Status.RUNNING)
	assert_eq(custom_node.tick_count_value, 0, "Runner 副本不应 tick 原始自定义定义节点。")
	assert_eq(first_runner.tick(), GFBehaviorTree.Status.SUCCESS)
	assert_eq(second_runner.tick(), GFBehaviorTree.Status.SUCCESS)


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


func test_debug_snapshot_sanitizes_metadata_and_marks_debug_cycles() -> void:
	var node: SelfDebugNode = SelfDebugNode.new()
	var circular_metadata: Dictionary = {}
	circular_metadata["self"] = circular_metadata
	node.metadata = {
		"position": Vector2(1.0, 2.0),
		"bad_number": NAN,
		"loop": circular_metadata,
	}

	var snapshot: Dictionary = node.get_debug_snapshot()
	var metadata: Dictionary = GFVariantData.get_option_dictionary(snapshot, "metadata")
	var encoded_position: Dictionary = GFVariantData.get_option_dictionary(metadata, "position")
	var encoded_bad_number: Dictionary = GFVariantData.get_option_dictionary(metadata, "bad_number")
	var encoded_loop: Dictionary = GFVariantData.get_option_dictionary(metadata, "loop")
	var loop_reference: Dictionary = GFVariantData.get_option_dictionary(encoded_loop, "self")
	var loop_marker: Dictionary = GFVariantData.get_option_dictionary(loop_reference, "__gf_report_value__")
	var children: Array = GFVariantData.get_option_array(snapshot, "children")
	var cycle_child: Dictionary = GFVariantData.as_dictionary(children[0])

	assert_true(encoded_position.has(GFVariantJsonCodec.JSON_MARKER_KEY), "Vector2 metadata 应输出 JSON-safe typed marker。")
	assert_true(encoded_bad_number.has(GFVariantJsonCodec.JSON_MARKER_KEY), "NaN metadata 应输出 JSON-safe typed marker。")
	assert_eq(GFVariantData.get_option_string(loop_marker, "type"), "CircularReference", "循环 metadata 应输出报告 marker。")
	assert_true(GFVariantData.get_option_bool(cycle_child, "cycle"), "debug child 自环应被标记而不是递归展开。")
	assert_ne(JSON.stringify(snapshot), "", "调试快照应可直接进入 JSON.stringify。")


func test_debug_snapshot_distinguishes_shared_reference_from_cycle() -> void:
	var shared: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	shared.node_id = &"shared"
	var sequence: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([shared, shared]))
	var snapshot: Dictionary = sequence.get_debug_snapshot()
	var children: Array = GFVariantData.get_option_array(snapshot, "children")
	var first_child: Dictionary = GFVariantData.as_dictionary(children[0])
	var second_child: Dictionary = GFVariantData.as_dictionary(children[1])

	assert_false(GFVariantData.get_option_bool(first_child, "cycle"))
	assert_false(GFVariantData.get_option_bool(second_child, "cycle"), "第二条合法引用不是递归回边。")
	assert_true(
		GFVariantData.get_option_bool(second_child, "shared_reference"),
		"共享 identity 应与真实 cycle 分开表达。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(second_child, "reason"),
		&"debug_shared_reference"
	)


func test_debug_snapshot_bounds_children_during_tree_traversal() -> void:
	var sequence: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([
		GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS),
		GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS),
		GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS),
		GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS),
	]))

	var snapshot: Dictionary = GFBehaviorTree.build_debug_snapshot(sequence, {
		"max_nodes": 8,
		"max_depth": 4,
		"max_children": 1,
	})
	var children: Array = GFVariantData.get_option_array(snapshot, "children")
	var debug_budget: Dictionary = GFVariantData.get_option_dictionary(snapshot, "debug_budget")

	assert_eq(GFVariantData.get_option_int(snapshot, "child_count"), 4)
	assert_eq(GFVariantData.get_option_int(snapshot, "captured_child_count"), 1)
	assert_eq(GFVariantData.get_option_int(snapshot, "omitted_child_count"), 3)
	assert_eq(children.size(), 1, "子节点预算必须在递归前生效。")
	assert_true(GFVariantData.get_option_bool(snapshot, "truncated"))
	assert_eq(GFVariantData.get_option_string_name(snapshot, "truncation_reason"), &"max_children")
	assert_true(GFVariantData.get_option_bool(debug_budget, "truncated"))


func test_debug_snapshot_reports_null_child_as_structural_truncation() -> void:
	var sequence: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([null]))

	var snapshot: Dictionary = GFBehaviorTree.build_debug_snapshot(sequence)
	var debug_budget: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		"debug_budget"
	)
	var truncation_reasons: Array = GFVariantData.get_option_array(
		debug_budget,
		"truncation_reasons"
	)

	assert_eq(GFVariantData.get_option_int(snapshot, "child_count"), 1)
	assert_eq(GFVariantData.get_option_int(snapshot, "captured_child_count"), 0)
	assert_eq(GFVariantData.get_option_int(snapshot, "omitted_child_count"), 1)
	assert_true(GFVariantData.get_option_bool(snapshot, "truncated"))
	assert_eq(
		GFVariantData.get_option_string_name(snapshot, "truncation_reason"),
		&"null_child"
	)
	assert_true(GFVariantData.get_option_bool(debug_budget, "truncated"))
	assert_has(truncation_reasons, "null_child")


func test_debug_snapshot_stops_when_global_node_budget_is_exhausted() -> void:
	var sequence: GFBehaviorTree.Sequence = GFBehaviorTree.Sequence.new(_nodes([
		GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS),
		GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS),
		GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS),
	]))

	var snapshot: Dictionary = GFBehaviorTree.build_debug_snapshot(sequence, {
		"max_nodes": 2,
		"max_children": 8,
	})
	var children: Array = GFVariantData.get_option_array(snapshot, "children")
	var debug_budget: Dictionary = GFVariantData.get_option_dictionary(snapshot, "debug_budget")

	assert_eq(children.size(), 1, "根节点占用一个 node budget，只能再捕获一个子节点。")
	assert_eq(GFVariantData.get_option_int(snapshot, "omitted_child_count"), 2)
	assert_eq(GFVariantData.get_option_string_name(snapshot, "truncation_reason"), &"max_nodes")
	assert_eq(GFVariantData.get_option_int(debug_budget, "node_count"), 2)
	assert_true(GFVariantData.get_option_bool(debug_budget, "truncated"))


func test_debug_snapshot_stops_before_descending_past_depth_budget() -> void:
	var root: GFBehaviorTree.Inverter = GFBehaviorTree.Inverter.new(
		GFBehaviorTree.Inverter.new(
			GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int: return GFBehaviorTree.Status.SUCCESS)
		)
	)

	var snapshot: Dictionary = GFBehaviorTree.build_debug_snapshot(root, {
		"max_nodes": 8,
		"max_depth": 1,
		"max_children": 8,
	})
	var children: Array = GFVariantData.get_option_array(snapshot, "children")
	var child: Dictionary = GFVariantData.as_dictionary(children[0])
	var debug_budget: Dictionary = GFVariantData.get_option_dictionary(snapshot, "debug_budget")

	assert_true(GFVariantData.get_option_array(child, "children").is_empty())
	assert_eq(GFVariantData.get_option_int(child, "omitted_child_count"), 1)
	assert_eq(GFVariantData.get_option_string_name(child, "truncation_reason"), &"max_depth")
	assert_eq(GFVariantData.get_option_int(debug_budget, "node_count"), 2)
	assert_true(GFVariantData.get_option_bool(debug_budget, "truncated"))


func test_runner_debug_snapshot_bounds_metadata_and_never_exports_blackboard_values() -> void:
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	action.metadata = {
		"resource": Resource.new(),
		"callable": func() -> void: pass,
		"long_text": "x".repeat(4096),
	}
	var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(action, false)
	runner.blackboard = {
		"alpha": Resource.new(),
		"beta": "sensitive_blackboard_value",
		"gamma": Callable(),
	}

	var snapshot: Dictionary = GFBehaviorTree.build_debug_snapshot(runner, {
		"max_total_bytes": 8192,
		"max_text_length": 64,
		"max_blackboard_keys": 1,
	})
	var root: Dictionary = GFVariantData.get_option_dictionary(snapshot, "root")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(root, "metadata")
	var blackboard_keys: Array = GFVariantData.get_option_array(snapshot, "blackboard_keys")

	assert_eq(blackboard_keys.size(), 1)
	assert_eq(GFVariantData.get_option_int(snapshot, "blackboard_key_count"), 3)
	assert_true(GFVariantData.get_option_bool(snapshot, "blackboard_keys_truncated"))
	assert_true(
		GFVariantData.get_option_string(metadata, "long_text").ends_with("..."),
		"统一报告编码器必须按文本预算投影 metadata。"
	)
	assert_true(JSON.stringify(snapshot).to_utf8_buffer().size() <= 8192)
	assert_false(_contains_live_debug_value(snapshot), "快照不得保留 Object 或 Callable live reference。")
	assert_false(
		JSON.stringify(snapshot).contains("sensitive_blackboard_value"),
		"Runner 快照只能输出受限黑板键，不能输出黑板值。"
	)


func test_runner_debug_snapshot_bounds_wide_metadata_with_collection_marker() -> void:
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	for index: int in range(2048):
		action.metadata["key_%04d" % index] = index
	var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(action, false)

	var snapshot: Dictionary = GFBehaviorTree.build_debug_snapshot(runner, {
		"max_total_bytes": 65_536,
	})
	var root: Dictionary = GFVariantData.get_option_dictionary(snapshot, "root")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(root, "metadata")
	var marker: Dictionary = GFVariantData.get_option_dictionary(
		metadata,
		"__gf_report_value__"
	)

	assert_eq(GFVariantData.get_option_string(marker, "type"), "CollectionBudget")
	assert_eq(GFVariantData.get_option_int(marker, "count"), 2048)
	assert_eq(GFVariantData.get_option_int(marker, "omitted_count"), 1024)
	assert_false(_contains_live_debug_value(snapshot))


func test_runner_debug_snapshot_bounds_blackboard_keys_before_materialization() -> void:
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(action, false)
	for index: int in range(2048):
		runner.blackboard["key_%04d" % index] = "secret_%04d" % index

	var snapshot: Dictionary = GFBehaviorTree.build_debug_snapshot(runner, {
		"max_blackboard_keys": 3,
		"max_total_bytes": 8192,
	})
	var blackboard_keys: Array = GFVariantData.get_option_array(snapshot, "blackboard_keys")

	assert_eq(blackboard_keys.size(), 3, "黑板键必须在完整物化前按请求预算停止。")
	assert_eq(GFVariantData.get_option_int(snapshot, "blackboard_key_count"), 2048)
	assert_true(GFVariantData.get_option_bool(snapshot, "blackboard_keys_truncated"))
	assert_true(JSON.stringify(snapshot).to_utf8_buffer().size() <= 8192)
	assert_false(JSON.stringify(snapshot).contains("secret_"), "调试快照不得读取或导出黑板值。")


func test_runtime_copy_and_blackboard_scope_handle_cyclic_dictionaries() -> void:
	var circular: Dictionary = {}
	circular["self"] = circular
	var action: GFBehaviorTree.Action = GFBehaviorTree.Action.new(func(_bb: Dictionary) -> int:
		return GFBehaviorTree.Status.SUCCESS
	)
	action.metadata = { "loop": circular }
	var runner: GFBehaviorTree.Runner = GFBehaviorTree.Runner.new(action)
	var scope: GFBehaviorTree.BlackboardScope = GFBehaviorTree.BlackboardScope.new({ &"loop": circular })

	assert_eq(runner.tick(), GFBehaviorTree.Status.SUCCESS)
	var root: Dictionary = GFVariantData.get_option_dictionary(runner.get_debug_snapshot(), "root")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(root, "metadata")
	var encoded_loop: Dictionary = GFVariantData.get_option_dictionary(metadata, "loop")
	var loop_reference: Dictionary = GFVariantData.get_option_dictionary(encoded_loop, "self")
	var loop_marker: Dictionary = GFVariantData.get_option_dictionary(
		loop_reference,
		"__gf_report_value__"
	)
	assert_eq(GFVariantData.get_option_string(loop_marker, "type"), "CircularReference")
	var scope_loop: Dictionary = GFVariantData.as_dictionary(scope.get_value(&"loop"))
	assert_true(is_same(scope_loop, scope_loop.get("self")), "BlackboardScope 的循环快照必须保持自引用且不崩溃。")


func test_build_debug_snapshot_sanitizes_arbitrary_snapshot_owner() -> void:
	var snapshot_source: UnsafeDebugOwner = UnsafeDebugOwner.new()
	var snapshot: Dictionary = GFBehaviorTree.build_debug_snapshot(snapshot_source)
	var resource_value: Dictionary = GFVariantData.get_option_dictionary(snapshot, "resource")
	var resource_marker: Dictionary = GFVariantData.get_option_dictionary(
		resource_value,
		"__gf_report_value__"
	)
	var loop_value: Dictionary = GFVariantData.get_option_dictionary(snapshot, "loop")
	var loop_reference: Dictionary = GFVariantData.get_option_dictionary(loop_value, "self")
	var loop_marker: Dictionary = GFVariantData.get_option_dictionary(loop_reference, "__gf_report_value__")

	assert_eq(GFVariantData.get_option_string(resource_marker, "type"), "Object")
	assert_eq(GFVariantData.get_option_string(loop_marker, "type"), "CircularReference")
	assert_false(JSON.stringify(snapshot).contains(":null"), "NaN 不应在调试报告中退化为 null。")


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


func _make_test_clock(state: Dictionary) -> Callable:
	return func() -> int:
		return GFVariantData.get_option_int(state, "msec")


func _count_unique(values: Array) -> int:
	var lookup: Dictionary = {}
	for value: Variant in values:
		lookup[value] = true
	return lookup.size()


func _nodes(nodes: Array[GFBehaviorTree.BTNode]) -> Array[GFBehaviorTree.BTNode]:
	return nodes


func _contains_live_debug_value(value: Variant) -> bool:
	if value is Object or value is Callable:
		return true
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		for key: Variant in dictionary_value.keys():
			if _contains_live_debug_value(key) or _contains_live_debug_value(dictionary_value[key]):
				return true
	elif value is Array:
		var array_value: Array = value
		for item: Variant in array_value:
			if _contains_live_debug_value(item):
				return true
	return false


class CustomCountingNode extends GFBehaviorTree.BTNode:
	var tick_count_value: int = 0

	func tick(_blackboard: Dictionary) -> int:
		tick_count_value += 1
		return _record_tick(GFBehaviorTree.Status.SUCCESS)


class DuplicatingCountingNode extends GFBehaviorTree.BTNode:
	var tick_count_value: int = 0

	func tick(_blackboard: Dictionary) -> int:
		tick_count_value += 1
		return _record_tick(GFBehaviorTree.Status.RUNNING if tick_count_value == 1 else GFBehaviorTree.Status.SUCCESS)

	func duplicate_runtime() -> GFBehaviorTree.BTNode:
		var copy: DuplicatingCountingNode = DuplicatingCountingNode.new()
		_copy_base_fields_to(copy)
		return copy


class CustomSequenceWithoutDuplicate extends GFBehaviorTree.Sequence:
	var custom_tick_count: int = 0

	func _init() -> void:
		super([])

	func tick(_blackboard: Dictionary) -> int:
		custom_tick_count += 1
		return _record_tick(GFBehaviorTree.Status.ABORTED, &"custom_sequence_tick")


class ReentrantRunnerNode extends GFBehaviorTree.BTNode:
	var runner: GFBehaviorTree.Runner = null
	var tick_call_count: int = 0

	func tick(_blackboard: Dictionary) -> int:
		tick_call_count += 1
		if tick_call_count == 1 and runner != null:
			return _record_tick(runner.tick())
		return _record_tick(GFBehaviorTree.Status.SUCCESS)


class SelfDebugNode extends GFBehaviorTree.BTNode:
	func _get_debug_children() -> Array[GFBehaviorTree.BTNode]:
		return [self]

	func duplicate_runtime() -> GFBehaviorTree.BTNode:
		var copy: SelfDebugNode = SelfDebugNode.new()
		_copy_base_fields_to(copy)
		return copy


class ResetCountingNode extends GFBehaviorTree.BTNode:
	var reset_count: int = 0

	func tick(_blackboard: Dictionary) -> int:
		return _record_tick(GFBehaviorTree.Status.RUNNING)

	func reset() -> void:
		reset_count += 1
		super.reset()


class StatusSequenceNode extends GFBehaviorTree.BTNode:
	var statuses: Array[int] = []
	var tick_count_value: int = 0
	var reset_count: int = 0

	func _init(p_statuses: Array[int]) -> void:
		statuses = p_statuses.duplicate()

	func tick(_blackboard: Dictionary) -> int:
		var status_index: int = mini(tick_count_value, statuses.size() - 1)
		tick_count_value += 1
		return _record_tick(statuses[status_index])

	func reset() -> void:
		reset_count += 1
		super.reset()


class ResettableAttemptNode extends GFBehaviorTree.BTNode:
	var phase: int = 0
	var reset_count: int = 0

	func tick(_blackboard: Dictionary) -> int:
		phase += 1
		return _record_tick(
			GFBehaviorTree.Status.RUNNING if phase == 1 else GFBehaviorTree.Status.SUCCESS
		)

	func reset() -> void:
		phase = 0
		reset_count += 1


class RawStatusNode extends GFBehaviorTree.BTNode:
	var raw_status: int = GFBehaviorTree.Status.FAILURE

	func _init(p_raw_status: int) -> void:
		raw_status = p_raw_status

	func tick(_blackboard: Dictionary) -> int:
		return raw_status


class UnsafeDebugOwner extends RefCounted:
	func get_debug_snapshot() -> Dictionary:
		var loop: Dictionary = {}
		loop["self"] = loop
		return {
			"bad_number": NAN,
			"resource": Resource.new(),
			"loop": loop,
		}
