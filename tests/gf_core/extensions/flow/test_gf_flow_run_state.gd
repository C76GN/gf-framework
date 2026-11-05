## 从项目节点入口验证业务共享、不同运行和子调用之间的调度隔离。
extends GutTest


# --- 辅助类 ---

class Operation extends RefCounted:
	signal finished


class Step extends GFFlowNode:
	var action: Callable

	func _init(id: StringName, callback: Callable) -> void:
		node_id = id
		action = callback


	func execute(context: GFFlowContext, execution: GFFlowNodeExecution) -> Variant:
		return action.call(context, execution)


# --- 测试方法 ---

## 同一 Context 和节点 ID，异步等待与取消只影响所属 Runner。
func test_overlapping_runs_share_business_writes_but_not_wait_cancellation_or_node_progress() -> void:
	var context: GFFlowContext = GFFlowContext.new()
	var first: GFFlowRunner = GFFlowRunner.new()
	var second: GFFlowRunner = GFFlowRunner.new()
	var first_task: Operation = Operation.new()
	var second_task: Operation = Operation.new()
	var first_calls: Array[GFFlowNodeExecution] = []
	var second_calls: Array[GFFlowNodeExecution] = []
	var observed: Array[String] = []
	var a: Step = Step.new(
		&"step",
		func(business: GFFlowContext, execution: GFFlowNodeExecution) -> Signal:
			first_calls.append(execution)
			var _set: GFFlowContext = business.set_value(&"effect", "first")
			var _saved: bool = execution.set_runtime_value(&"count", 1)
			return first_task.finished
	)
	var b: Step = Step.new(
		&"step",
		func(business: GFFlowContext, execution: GFFlowNodeExecution) -> Signal:
			second_calls.append(execution)
			observed.append(GFVariantData.to_text(business.get_value(&"effect")))
			var _set: GFFlowContext = business.set_value(&"effect", "second")
			var _saved: bool = execution.set_runtime_value(&"count", 2)
			return second_task.finished
	)
	first.call_deferred(
		"run",
		_graph([a]),
		context
	)
	await get_tree().process_frame
	second.call_deferred(
		"run",
		_graph([b]),
		context
	)
	await get_tree().process_frame
	assert_true(first.is_running)
	assert_true(second.is_running)
	assert_ne(
		first.get_run_state(),
		second.get_run_state()
	)
	assert_eq(
		observed,
		["first"]
	)
	var old_state: GFFlowRunState = first.get_run_state()
	_assert_value(
		old_state.get_report().get("waiting_node_id"),
		"step"
	)
	_assert_value(
		second.get_run_state().get_report().get("waiting_node_id"),
		"step"
	)
	assert_true(old_state.cancel())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(first.is_running)
	assert_true(second.is_running)
	_assert_value(
		first.get_last_run_report().get("outcome"),
		"cancelled"
	)
	_assert_value(
		context.get_value(&"effect"),
		"second"
	)
	assert_eq(
		old_state.get_report(),
		first.get_last_run_report()
	)
	assert_false(old_state.cancel())
	assert_false(first_calls[0].set_runtime_value(&"count", 80))
	assert_true(second_calls[0].set_runtime_value(&"count", 3))
	first_task.finished.emit()
	assert_true(second.is_running)
	second_task.finished.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_value(
		second.get_last_run_report().get("outcome"),
		"completed"
	)
	assert_eq(
		first.get_run_state().create_data_snapshot(),
		{
			"nodes": {
				&"step": { &"count": 1 },
			},
		}
	)
	assert_eq(
		second.get_run_state().create_data_snapshot(),
		{
			"nodes": {
				&"step": { &"count": 3 },
			},
		}
	)


## 父图已选分支，子图有同名节点并等待，返回后只消费父帧选定的后继。
func test_child_call_waits_in_its_own_frame_and_returns_to_the_saved_parent_branch() -> void:
	var runner: GFFlowRunner = GFFlowRunner.new()
	var context: GFFlowContext = GFFlowContext.new()
	var gate: Operation = Operation.new()
	var visits: Array[String] = []
	var child_node: Step = Step.new(
		&"shared",
		func(business: GFFlowContext, execution: GFFlowNodeExecution) -> Signal:
			visits.append("child")
			_assert_value(
				execution.get_runtime_value(&"position", 0),
				0
			)
			assert_true(execution.set_runtime_value(&"position", 99))
			var _set: GFFlowContext = business.set_value(&"heard", true)
			assert_true(execution.set_next_nodes(PackedStringArray(["child_end"])))
			return gate.finished
	)
	var child_end: Step = Step.new(
		&"child_end",
		func(_ctx: GFFlowContext, _ex: GFFlowNodeExecution) -> Variant:
			visits.append("child_end")
			return null
	)
	var child: GFFlowGraph = _graph([child_node, child_end])
	var parent_node: Step = Step.new(
		&"shared",
		func(_business: GFFlowContext, execution: GFFlowNodeExecution) -> Variant:
			visits.append("parent")
			_assert_value(
				execution.get_runtime_value(&"position", 0),
				4
			)
			assert_true(execution.set_next_nodes(PackedStringArray(["expected"])))
			assert_true(execution.call_subgraph(child))
			assert_false(execution.call_subgraph(child))
			return null
	)
	parent_node.next_node_ids = PackedStringArray(["wrong"])
	var expected: Step = Step.new(
		&"expected",
		func(business: GFFlowContext, _execution: GFFlowNodeExecution) -> Variant:
			visits.append("expected")
			_assert_value(
				business.get_value(&"heard"),
				true
			)
			return null
	)
	runner.call_deferred(
		"run",
		_graph([parent_node, expected]),
		context,
		{
			&"shared": { &"position": 4 },
		}
	)
	await get_tree().process_frame
	assert_eq(
		visits,
		["parent", "child"]
	)
	var state: GFFlowRunState = runner.get_run_state()
	var frames: Array[Dictionary] = state.describe_frames()
	assert_eq(
		frames.size(),
		2
	)
	if frames.size() == 2:
		_assert_distinct_ids(
			frames[0].get("frame_id"),
			frames[1].get("frame_id")
		)
		_assert_value(
			frames[0].get("pending"),
			PackedStringArray(["expected"])
		)
	gate.finished.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(
		visits,
		[
			"parent",
			"child",
			"child_end",
			"expected",
		]
	)
	_assert_value(
		runner.get_last_run_report().get("completed_node_count"),
		4
	)
	_assert_value(
		runner.get_last_run_report().get("outcome"),
		"completed"
	)
	assert_eq(
		state.describe_frames().size(),
		0
	)
	var nodes: Dictionary = GFVariantData.get_option_dictionary(
		state.create_data_snapshot(),
		"nodes"
	)
	_assert_value(
		nodes.get(&"shared"),
		{ &"position": 4 }
	)


## 在同一节点的下一次循环中回放旧回调，身份不同且新状态不受影响。
func test_previous_iteration_handle_cannot_redirect_or_mutate_same_node_on_next_visit() -> void:
	var calls: Array[GFFlowNodeExecution] = []
	var step: Step = Step.new(
		&"loop",
		func(_ctx: GFFlowContext, execution: GFFlowNodeExecution) -> Variant:
			calls.append(execution)
			if calls.size() == 1:
				assert_true(execution.set_runtime_value(&"index", 1))
				assert_true(execution.set_next_nodes(PackedStringArray(["loop"])))
			else:
				assert_false(calls[0].set_next_nodes(PackedStringArray(["wrong"])))
				assert_false(calls[0].set_runtime_value(&"index", 50))
				assert_ne(
					calls[0],
					execution
				)
				_assert_value(
					execution.get_runtime_value(&"index"),
					1
				)
				assert_true(execution.set_runtime_value(&"index", 2))
			return null
	)
	var runner: GFFlowRunner = GFFlowRunner.new()
	var report: Dictionary = await runner.run(_graph([step]))
	_assert_value(
		report.get("outcome"),
		"completed"
	)
	_assert_value(
		report.get("executed_node_count"),
		2
	)
	assert_false(calls[1].is_active())
	assert_eq(
		runner.get_run_state().create_data_snapshot(),
		{
			"nodes": {
				&"loop": { &"index": 2 },
			},
		}
	)


## 终态监听器显式重启同一 Runner 时，旧返回值和旧句柄都保持独立。
func test_terminal_listener_restarts_same_runner_after_old_state_is_closed() -> void:
	var runner: GFFlowRunner = GFFlowRunner.new()
	var calls: Array[GFFlowNodeExecution] = []
	var step: Step = Step.new(
		&"step",
		func(_ctx: GFFlowContext, execution: GFFlowNodeExecution) -> Variant:
			calls.append(execution)
			assert_true(
				execution.set_runtime_value(
					&"version",
					calls.size()
				)
			)
			return null
	)
	var graph: GFFlowGraph = _graph([step])
	var context: GFFlowContext = GFFlowContext.new()
	var second_reports: Array[Dictionary] = []
	var first_states: Array[GFFlowRunState] = []
	var _connection: int = runner.flow_completed.connect(
		func(_report: Dictionary) -> void:
			assert_false(runner.is_running)
			assert_false(calls[0].is_active())
			first_states.append(runner.get_run_state())
			var next: Dictionary = await runner.run(graph, context)
			second_reports.append(next),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	)
	var original: Dictionary = await runner.run(graph, context)
	assert_eq(
		second_reports.size(),
		1
	)
	if second_reports.size() == 1:
		_assert_distinct_ids(
			original.get("run_id"),
			second_reports[0].get("run_id")
		)
		assert_eq(
			runner.get_last_run_report(),
			second_reports[0]
		)
	assert_false(calls[0].set_runtime_value(&"version", 100))
	assert_ne(
		first_states[0],
		runner.get_run_state()
	)
	assert_eq(
		first_states[0].get_report(),
		original
	)
	assert_false(first_states[0].cancel())
	assert_eq(
		runner.get_run_state().get_report(),
		second_reports[0]
	)
	assert_eq(
		first_states[0].create_data_snapshot(),
		{
			"nodes": {
				&"step": { &"version": 1 },
			},
		}
	)
	assert_eq(
		runner.get_run_state().create_data_snapshot(),
		{
			"nodes": {
				&"step": { &"version": 2 },
			},
		}
	)


## 非等待节点完成逻辑调度后仍占用物理资源；旧物理任务完成只释放原租约。
func test_background_completion_releases_only_resource_after_node_execution_has_closed() -> void:
	var context: GFFlowContext = GFFlowContext.new()
	var task: Operation = Operation.new()
	var calls: Array[GFFlowNodeExecution] = []
	var worker: Step = Step.new(
		&"work",
		func(_context: GFFlowContext, execution: GFFlowNodeExecution) -> Signal:
			calls.append(execution)
			assert_true(execution.set_runtime_value(&"count", 1))
			return task.finished
	)
	worker.wait_for_result = false
	var graph: GFFlowGraph = _graph([worker])
	var first: GFFlowRunner = GFFlowRunner.new()
	var report: Dictionary = await first.run(graph, context)
	_assert_value(
		report.get("outcome"),
		"completed"
	)
	assert_true(worker.is_runtime_state_leased())
	assert_false(calls[0].set_next_nodes(PackedStringArray(["late"])))
	assert_false(calls[0].set_runtime_value(&"count", 100))
	var separate: GFFlowRunner = GFFlowRunner.new()
	var busy: Dictionary = await separate.run(
		graph,
		GFFlowContext.new()
	)
	_assert_value(
		busy.get("reason"),
		"node_runtime_state_busy"
	)
	var busy_trace: Array = GFVariantData.get_option_array(busy, "trace")
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.as_dictionary(busy_trace[0]),
			"reason"
		),
		"node_runtime_state_busy"
	)
	assert_push_error("[GFFlowRunner][flow_runner.runtime_lease_active]")
	task.finished.emit()
	assert_false(worker.is_runtime_state_leased())
	var next: Dictionary = await separate.run(graph, context)
	_assert_value(
		next.get("outcome"),
		"completed"
	)
	assert_false(calls[0].is_active())
	assert_eq(
		first.get_run_state().create_data_snapshot(),
		{
			"nodes": {
				&"work": { &"count": 1 },
			},
		}
	)
	task.finished.emit()
	assert_false(worker.is_runtime_state_leased())


## 取消通知里启动新的等待，同一节点资源上旧任务的实际完成不结束新等待。
func test_cancel_listener_restarts_and_old_completion_cannot_end_new_wait() -> void:
	var runner: GFFlowRunner = GFFlowRunner.new()
	var context: GFFlowContext = GFFlowContext.new()
	var operations: Array[Operation] = []
	var calls: Array[GFFlowNodeExecution] = []
	var node: Step = Step.new(
		&"wait",
		func(_ctx: GFFlowContext, execution: GFFlowNodeExecution) -> Signal:
			var operation: Operation = Operation.new()
			operations.append(operation)
			calls.append(execution)
			return operation.finished
	)
	var graph: GFFlowGraph = _graph([node])
	var old_states: Array[GFFlowRunState] = []
	var _connected: int = runner.flow_cancelled.connect(
		func(report: Dictionary) -> void:
			var retired: GFFlowRunState = runner.get_run_state()
			old_states.append(retired)
			assert_eq(
				retired.get_report(),
				report
			)
			assert_false(runner.is_running)
			assert_false(calls[0].is_active())
			var _new_report: Dictionary = await runner.run(graph, context),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	)
	runner.call_deferred(
		"run",
		graph,
		context
	)
	await get_tree().process_frame
	runner.cancel()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(
		operations.size(),
		2
	)
	if operations.size() != 2:
		return
	var current: GFFlowRunState = runner.get_run_state()
	assert_ne(
		current,
		old_states[0]
	)
	assert_false(old_states[0].cancel())
	operations[0].finished.emit()
	await get_tree().process_frame
	assert_true(runner.is_running)
	_assert_value(
		current.get_report().get("waiting_node_id"),
		"wait"
	)
	assert_false(calls[0].set_next_nodes(PackedStringArray(["wrong"])))
	assert_true(calls[1].set_next_nodes(PackedStringArray()))
	operations[1].finished.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_value(
		current.get_report().get("outcome"),
		"completed"
	)
	_assert_value(
		old_states[0].get_report().get("outcome"),
		"cancelled"
	)


## 缺失子节点或子调用耗尽整轮节点预算时，运行终止，父返回点不会被执行。
func test_child_failure_or_total_node_limit_aborts_the_whole_run() -> void:
	for bounded: bool in [false, true]:
		var child: GFFlowGraph = GFFlowGraph.new()
		child.start_node_id = &"absent"
		var visits: Array[String] = []
		var invoke: Step = Step.new(
			&"invoke",
			func(_ctx: GFFlowContext, execution: GFFlowNodeExecution) -> Variant:
				visits.append("parent")
				assert_true(execution.call_subgraph(child))
				assert_true(execution.set_next_nodes(PackedStringArray(["after"])))
				return null
		)
		var after: Step = Step.new(
			&"after",
			func(_ctx: GFFlowContext, _execution: GFFlowNodeExecution) -> Variant:
				visits.append("after")
				return null
		)
		var runner: GFFlowRunner = GFFlowRunner.new()
		runner.max_executed_nodes = 1 if bounded else 4
		var report: Dictionary = await runner.run(_graph([invoke, after]))
		assert_eq(
			visits,
			["parent"]
		)
		_assert_value(
			report.get("outcome"),
			"aborted"
		)
		if bounded:
			_assert_value(
				report.get("reason"),
				"max_executed_nodes"
			)
			assert_push_warning("[GFFlowRunner][flow_runner.node_execution_limit]")
		else:
			_assert_value(
				report.get("reason"),
				"missing_node"
			)
			assert_push_warning("[GFFlowRunner][flow_runner.missing_node]")
		assert_eq(
			runner.get_run_state().get_report(),
			report
		)
		assert_true(runner.get_run_state().describe_frames().is_empty())


## 空的强类型字典是合法的初始进度；运行仍能按需创建节点状态。
func test_empty_typed_seed_can_allocate_and_write_node_progress() -> void:
	var initial_progress: Dictionary[StringName, int] = {}
	var step: Step = Step.new(
		&"step",
		func(_context: GFFlowContext, execution: GFFlowNodeExecution) -> Variant:
			assert_true(execution.set_runtime_value(&"progress", "started"))
			return null
	)
	var runner: GFFlowRunner = GFFlowRunner.new()
	var report: Dictionary = await runner.run(
		_graph([step]),
		GFFlowContext.new(),
		initial_progress
	)
	_assert_value(
		report.get("outcome"),
		"completed"
	)
	assert_eq(
		runner.get_run_state().create_data_snapshot(),
		{
			"nodes": {
				&"step": { &"progress": "started" },
			},
		}
	)
	assert_true(initial_progress.is_empty())


## 框架拥有的节点字段可以写入不同类型；原来的强类型节点字典保持原值。
func test_typed_node_progress_accepts_new_variant_field_types_without_mutating_seed() -> void:
	var typed_fields: Dictionary[StringName, int] = { &"progress": 3 }
	var initial_progress: Dictionary[StringName, Dictionary] = { &"step": typed_fields }
	var step: Step = Step.new(
		&"step",
		func(_context: GFFlowContext, execution: GFFlowNodeExecution) -> Variant:
			_assert_value(
				execution.get_runtime_value(&"progress"),
				3
			)
			var items: Array[int] = [4, 7]
			assert_true(execution.set_runtime_value(&"progress", items))
			items[0] = 100
			var stored: Variant = execution.get_runtime_value(&"progress")
			assert_true(stored is Array[int])
			_assert_value(
				stored,
				[4, 7]
			)
			return null
	)
	var runner: GFFlowRunner = GFFlowRunner.new()
	var report: Dictionary = await runner.run(
		_graph([step]),
		GFFlowContext.new(),
		initial_progress
	)
	_assert_value(
		report.get("outcome"),
		"completed"
	)
	assert_eq(
		runner.get_run_state().create_data_snapshot(),
		{
			"nodes": {
				&"step": {
					&"progress": [4, 7],
				},
			},
		}
	)
	assert_eq(
		typed_fields[&"progress"],
		3
	)


## 节点同步取消且不等待时，报告仍应记录执行身份；后台操作独立释放租约。
func test_synchronous_cancel_records_node_trace_and_preserves_background_lease() -> void:
	for background: bool in [false, true]:
		var runner: GFFlowRunner = GFFlowRunner.new()
		var task: Operation = Operation.new()
		var step: Step = Step.new(
			&"cancel",
			func(_context: GFFlowContext, execution: GFFlowNodeExecution) -> Variant:
				runner.cancel()
				assert_false(execution.is_active())
				if background:
					return task.finished
				return null
		)
		step.wait_for_result = false
		var report: Dictionary = await runner.run(_graph([step]))
		_assert_value(
			report.get("outcome"),
			"cancelled"
		)
		_assert_value(
			report.get("executed_node_count"),
			1
		)
		_assert_value(
			report.get("completed_node_count"),
			0
		)
		_assert_value(
			report.get("trace_entry_count"),
			1
		)
		var trace: Array = GFVariantData.get_option_array(report, "trace")
		if trace.size() == 1:
			var row: Dictionary = GFVariantData.as_dictionary(trace[0])
			_assert_value(
				row.get("node_id"),
				"cancel"
			)
			_assert_value(
				row.get("status"),
				"cancelled"
			)
			_assert_value(
				row.get("reason"),
				"cancel_requested"
			)
			_assert_value(
				row.get("execution_id"),
				1
			)
		assert_eq(
			step.is_runtime_state_leased(),
			background
		)
		task.finished.emit()
		assert_false(step.is_runtime_state_leased())


# --- 私有/辅助方法 ---

## Variant 类型必须正确，避免转换或默认值掩盖字段缺失。
func _assert_value(actual: Variant, expected: Variant) -> void:
	assert_eq(
		typeof(actual),
		typeof(expected)
	)
	if typeof(actual) != typeof(expected):
		return
	var equal: bool = actual == expected
	assert_true(
		equal,
		"期望 %s，得到 %s"
		% [expected, actual]
	)


## 两个标识必须都是整数且属于不同的帧或运行。
func _assert_distinct_ids(first: Variant, second: Variant) -> void:
	assert_true(first is int)
	assert_true(second is int)
	if first is int and second is int:
		var distinct: bool = first != second
		assert_true(distinct)


func _graph(nodes: Array[GFFlowNode]) -> GFFlowGraph:
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = nodes[0].node_id
	graph.nodes = nodes
	return graph
