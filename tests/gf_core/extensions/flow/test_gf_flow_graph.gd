## 测试 GFFlowGraph 的通用节点执行与动态分支。
extends GutTest


# --- 常量 ---

const GFAsyncWaitSupportBase = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")


# --- 辅助类 ---

class RecordingFlowNode extends GFFlowNode:
	var order: Array[String] = []

	func _init(p_node_id: StringName, p_order: Array[String], p_next: PackedStringArray = PackedStringArray()) -> void:
		node_id = p_node_id
		order = p_order
		next_node_ids = p_next

	func execute(_context: GFFlowContext) -> Variant:
		order.append(String(node_id))
		return null


class BranchFlowNode extends GFFlowNode:
	func _init() -> void:
		node_id = &"branch"

	func execute(context: GFFlowContext) -> Variant:
		context.set_next_nodes(PackedStringArray(["right"]))
		return null


class StopFlowNode extends GFFlowNode:
	func _init() -> void:
		node_id = &"stop"

	func execute(context: GFFlowContext) -> Variant:
		context.set_next_nodes(PackedStringArray())
		return null


class ManualWaitFlowNode extends GFFlowNode:
	signal completed

	var order: Array[String] = []

	func _init(p_node_id: StringName, p_order: Array[String], p_next: PackedStringArray = PackedStringArray()) -> void:
		node_id = p_node_id
		order = p_order
		next_node_ids = p_next
		wait_for_result = true

	func execute(_context: GFFlowContext) -> Variant:
		order.append(String(node_id))
		return completed

	func complete() -> void:
		completed.emit()


class RuntimeStateFlowNode extends GFFlowNode:
	func _init() -> void:
		node_id = &"runtime"

	func execute(_context: GFFlowContext) -> Variant:
		set_runtime_value(&"count", GFVariantData.to_int(get_runtime_value(&"count", 0)) + 1)
		return null


class RuntimeStateWaitFlowNode extends GFFlowNode:
	signal completed

	func _init() -> void:
		node_id = &"runtime_wait"
		wait_for_result = true

	func execute(_context: GFFlowContext) -> Variant:
		set_runtime_value(&"count", GFVariantData.to_int(get_runtime_value(&"count", 0)) + 1)
		return completed

	func complete() -> void:
		completed.emit()


class AsyncRuntimeMutationFlowNode extends GFFlowNode:
	signal completed

	func _init() -> void:
		node_id = &"async_runtime"
		wait_for_result = true

	func execute(_context: GFFlowContext) -> Variant:
		set_runtime_value(&"count", GFVariantData.to_int(get_runtime_value(&"count", 0)) + 1)
		return completed

	func mutate_and_complete() -> void:
		set_runtime_value(&"count", 99)
		completed.emit()


class NonWaitingSignalFlowNode extends GFFlowNode:
	signal completed

	func _init() -> void:
		node_id = &"non_waiting_signal"
		wait_for_result = false

	func execute(_context: GFFlowContext) -> Variant:
		return completed

	func complete() -> void:
		completed.emit()


class MethodTrapFlowPort extends GFFlowPort:
	var get_port_id_called: bool = false
	var get_display_name_called: bool = false
	var describe_called: bool = false
	var get_compatibility_report_called: bool = false
	var is_compatible_with_called: bool = false

	func get_port_id() -> StringName:
		get_port_id_called = true
		return &"method_port"

	func get_display_name() -> String:
		get_display_name_called = true
		return "Method Port"

	func describe() -> Dictionary:
		describe_called = true
		return { "port_id": &"method_port" }

	func get_compatibility_report(_target_port: GFFlowPort) -> Dictionary:
		get_compatibility_report_called = true
		return { "ok": false, "message": "method compatibility should not run" }

	func is_compatible_with(_target_port: GFFlowPort) -> bool:
		is_compatible_with_called = true
		return false

	func any_method_called() -> bool:
		return (
			get_port_id_called
			or get_display_name_called
			or describe_called
			or get_compatibility_report_called
			or is_compatible_with_called
		)


class MethodTrapFlowNode extends GFFlowNode:
	var get_display_name_called: bool = false
	var get_input_ports_called: bool = false
	var get_output_ports_called: bool = false
	var get_input_port_called: bool = false
	var get_output_port_called: bool = false
	var describe_ports_called: bool = false
	var describe_editor_called: bool = false
	var describe_node_called: bool = false

	func get_display_name() -> String:
		get_display_name_called = true
		return "Method Node"

	func get_input_ports() -> Array[GFFlowPort]:
		get_input_ports_called = true
		return []

	func get_output_ports() -> Array[GFFlowPort]:
		get_output_ports_called = true
		return []

	func get_input_port(_port_id: StringName) -> GFFlowPort:
		get_input_port_called = true
		return null

	func get_output_port(_port_id: StringName) -> GFFlowPort:
		get_output_port_called = true
		return null

	func describe_ports() -> Dictionary:
		describe_ports_called = true
		return {}

	func describe_editor() -> Dictionary:
		describe_editor_called = true
		return {}

	func describe_node() -> Dictionary:
		describe_node_called = true
		return {}

	func any_method_called() -> bool:
		return (
			get_display_name_called
			or get_input_ports_called
			or get_output_ports_called
			or get_input_port_called
			or get_output_port_called
			or describe_ports_called
			or describe_editor_called
			or describe_node_called
		)


# --- 测试方法 ---

## 验证流程节点会按后继关系执行。
func test_flow_runner_executes_node_links() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"start"
	graph.nodes = [
		RecordingFlowNode.new(&"start", order, PackedStringArray(["end"])),
		RecordingFlowNode.new(&"end", order),
	]
	var runner: GFFlowRunner = GFFlowRunner.new()

	await runner.run(graph, GFFlowContext.new())

	assert_eq(order, ["start", "end"], "流程应按节点后继顺序执行。")
	assert_false(runner.is_running, "同步流程完成后不应保持 running。")


func test_flow_runner_returns_bounded_structured_run_report() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"start"
	graph.nodes = [
		RecordingFlowNode.new(&"start", order, PackedStringArray(["middle"])),
		RecordingFlowNode.new(&"middle", order, PackedStringArray(["end"])),
		RecordingFlowNode.new(&"end", order),
	]
	var runner: GFFlowRunner = GFFlowRunner.new()
	runner.max_report_trace_entries = 2

	var report: Dictionary = await runner.run(graph, GFFlowContext.new())
	var trace: Array = GFVariantData.get_option_array(report, "trace")
	trace.clear()
	var retained_copy: Dictionary = runner.get_last_run_report()

	assert_eq(GFVariantData.get_option_string(report, "outcome"), "completed", "正常流程应报告 completed。")
	assert_eq(GFVariantData.get_option_int(report, "executed_node_count"), 3, "报告应统计已执行节点。")
	assert_eq(GFVariantData.get_option_int(report, "completed_node_count"), 3, "报告应统计已完成节点。")
	assert_eq(GFVariantData.get_option_int(report, "signal_wait_count"), 0, "同步流程不应记录 Signal 等待。")
	assert_eq(GFVariantData.get_option_int(report, "trace_entry_count"), 3, "总 trace 数不应受保留上限影响。")
	assert_eq(GFVariantData.get_option_int(report, "retained_trace_entry_count"), 2, "保留 trace 应受上限约束。")
	assert_eq(GFVariantData.get_option_int(report, "dropped_trace_entry_count"), 1, "报告应显式说明丢弃数量。")
	assert_true(GFVariantData.get_option_bool(report, "trace_truncated"), "超过上限时应标记 trace 截断。")
	assert_eq(GFVariantData.get_option_array(retained_copy, "trace").size(), 2, "last report 必须返回隔离副本。")
	assert_false(JSON.stringify(retained_copy).is_empty(), "运行报告应可直接编码为 JSON。")


## 验证节点可通过上下文覆盖后继节点。
func test_flow_node_can_override_next_nodes() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"branch"
	graph.nodes = [
		BranchFlowNode.new(),
		RecordingFlowNode.new(&"left", order),
		RecordingFlowNode.new(&"right", order),
	]
	var runner: GFFlowRunner = GFFlowRunner.new()

	await runner.run(graph, GFFlowContext.new())

	assert_eq(order, ["right"], "上下文覆盖的分支应决定后继节点。")


## 验证流程节点端口描述可用于图结构描述。
func test_flow_node_describes_ports() -> void:
	var output_port: GFFlowPort = GFFlowPort.new()
	output_port.port_id = &"success"
	output_port.direction = GFFlowPort.Direction.OUTPUT
	output_port.value_type = GFFlowPort.ValueType.BOOL
	output_port.editor_color = Color.GREEN
	output_port.type_hint = &"result"
	output_port.semantic_tags = PackedStringArray(["logic"])
	var node: GFFlowNode = GFFlowNode.new()
	node.node_id = &"check"
	node.output_ports = [output_port]

	var description: Dictionary = node.describe_node()
	var ports: Dictionary = GFVariantData.get_option_dictionary(description, "ports")
	var outputs: Array = GFVariantData.get_option_array(ports, "outputs")
	var first_output: Dictionary = GFVariantData.as_dictionary(outputs[0])

	assert_eq(outputs.size(), 1, "节点描述应包含输出端口。")
	assert_eq(GFVariantData.get_option_string_name(first_output, "port_id"), &"success", "端口标识应保留。")
	assert_eq(_color_value(first_output, "editor_color"), Color.GREEN, "端口描述应包含编辑器颜色。")
	assert_eq(GFVariantData.get_option_string_name(first_output, "type_hint"), &"result", "端口描述应包含类型提示。")
	assert_true(GFVariantData.get_option_packed_string_array(first_output, "semantic_tags").has("logic"), "端口描述应包含语义标签。")


## 验证流程图连接可驱动无 next_node_ids 的节点推进。
func test_flow_runner_executes_graph_connections() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"start"
	graph.nodes = [
		RecordingFlowNode.new(&"start", order),
		RecordingFlowNode.new(&"end", order),
	]
	var _add_connection_result_233: Variant = graph.add_connection(&"start", &"", &"end", &"")
	var runner: GFFlowRunner = GFFlowRunner.new()

	await runner.run(graph, GFFlowContext.new())

	assert_eq(order, ["start", "end"], "流程应能通过图连接推进后继节点。")


func test_flow_data_port_connection_is_not_an_execution_edge() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: RecordingFlowNode = RecordingFlowNode.new(&"start", order)
	start.output_ports = [_make_typed_port(&"value", GFFlowPort.Direction.OUTPUT, GFFlowPort.ValueType.NUMBER)]
	var end: RecordingFlowNode = RecordingFlowNode.new(&"end", order)
	end.input_ports = [_make_typed_port(&"value", GFFlowPort.Direction.INPUT, GFFlowPort.ValueType.NUMBER)]
	graph.start_node_id = &"start"
	graph.nodes = [start, end]
	assert_true(graph.add_connection(&"start", &"value", &"end", &"value"), "测试前应成功创建数据端口连接。")
	var runner: GFFlowRunner = GFFlowRunner.new()

	await runner.run(graph, GFFlowContext.new())
	var runtime_report: Dictionary = graph.validate_graph()
	var editor_report: Dictionary = GFVariantData.get_option_dictionary(
		GFFlowGraphEditorModel.new().build_editor_report(graph),
		"validation"
	)

	assert_eq(order, ["start"], "数据端口连接不得隐式执行目标节点。")
	assert_true(_has_issue(runtime_report, "unreachable_node"), "runtime 拓扑应把 data-only 目标视为执行不可达。")
	assert_true(_has_issue(editor_report, "unreachable_node"), "editor 拓扑应与 runtime 使用相同的执行边语义。")


func test_flow_runner_executes_node_links_and_graph_connections_together() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"start"
	graph.nodes = [
		RecordingFlowNode.new(&"start", order, PackedStringArray(["left"])),
		RecordingFlowNode.new(&"left", order),
		RecordingFlowNode.new(&"right", order),
	]
	var _add_connection_result_244: Variant = graph.add_connection(&"start", &"", &"right", &"")
	var runner: GFFlowRunner = GFFlowRunner.new()

	await runner.run(graph, GFFlowContext.new())
	var report: Dictionary = graph.validate_graph()

	assert_eq(order, ["start", "left", "right"], "节点后继与图连接应使用同一执行拓扑。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "校验拓扑应与运行拓扑一致。")
	assert_false(_has_issue(report, "unreachable_node"), "连接后继不应被运行时跳过。")


## 验证上下文显式空后继会阻止连接回退。
func test_flow_context_empty_override_stops_connection_fallback() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"stop"
	graph.nodes = [
		StopFlowNode.new(),
		RecordingFlowNode.new(&"end", order),
	]
	var _add_connection_result_250: Variant = graph.add_connection(&"stop", &"", &"end", &"")
	var runner: GFFlowRunner = GFFlowRunner.new()

	await runner.run(graph, GFFlowContext.new())

	assert_eq(order, [], "显式空后继应表示停止，而不是回退到图连接。")


func test_flow_runner_cancel_during_signal_wait_stops_after_await() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	var waiting_node: ManualWaitFlowNode = ManualWaitFlowNode.new(&"wait", order, PackedStringArray(["after"]))
	graph.start_node_id = &"wait"
	graph.nodes = [
		waiting_node,
		RecordingFlowNode.new(&"after", order),
	]
	var runner: GFFlowRunner = GFFlowRunner.new()
	var cancelled_reports: Array[Dictionary] = []
	var _report_connected: Error = runner.flow_cancelled.connect(func(cancelled_report: Dictionary) -> void:
		cancelled_reports.append(cancelled_report)
	) as Error
	watch_signals(runner)
	@warning_ignore("missing_await")
	@warning_ignore("return_value_discarded")
	runner.run(graph, GFFlowContext.new())

	await get_tree().process_frame
	runner.cancel()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order, ["wait"], "取消后不应继续推进后继节点。")
	assert_signal_not_emitted(runner, "node_completed", "取消等待后不应再报告当前节点完成。")
	assert_signal_emitted(runner, "flow_cancelled", "取消等待后应发出流程取消信号。")
	assert_eq(cancelled_reports.size(), 1, "取消等待应产生一份终态报告。")
	var report: Dictionary = cancelled_reports[0]
	var trace: Array = GFVariantData.get_option_array(report, "trace")
	assert_eq(GFVariantData.get_option_string(report, "outcome"), "cancelled", "显式取消应报告 cancelled。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "cancel_requested", "取消报告应提供稳定原因。")
	assert_eq(GFVariantData.get_option_int(report, "signal_wait_count"), 1, "报告应统计一次 Signal 等待。")
	assert_eq(GFVariantData.get_option_int(report, "cancelled_signal_wait_count"), 1, "报告应统计被取消的 Signal 等待。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(trace[0]), "wait_status"), "cancelled", "节点 trace 应记录等待取消。")
	assert_false(waiting_node.is_runtime_state_leased(), "取消等待后必须释放节点运行态租约。")
	var verification_lease: int = waiting_node.acquire_runtime_state_lease()
	assert_gt(verification_lease, 0, "取消后节点应可再次获得运行态租约。")
	assert_true(waiting_node.release_runtime_state_lease(verification_lease), "验证租约应可正常释放。")


func test_flow_runner_cancel_from_node_started_skips_execution() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"start"
	graph.nodes = [RecordingFlowNode.new(&"start", order)]
	var runner: GFFlowRunner = GFFlowRunner.new()
	var _connected: Variant = runner.node_started.connect(func(_node_id: StringName, _node: GFFlowNode) -> void:
		runner.cancel()
	)
	watch_signals(runner)

	var report: Dictionary = await runner.run(graph, GFFlowContext.new())

	assert_eq(order, [], "node_started 中取消后不应继续执行当前节点。")
	assert_eq(GFVariantData.get_option_string(report, "outcome"), "cancelled", "node_started 中取消应报告 cancelled。")
	assert_eq(GFVariantData.get_option_int(report, "executed_node_count"), 0, "未进入 execute 的节点不得计为已执行。")
	assert_eq(GFVariantData.get_option_int(report, "completed_node_count"), 0, "未进入 execute 的节点不得计为已完成。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(GFVariantData.get_option_array(report, "trace")[0]), "status"), "cancelled", "trace 应明确节点在执行前取消。")
	assert_signal_not_emitted(runner, "node_completed", "取消后不应报告节点完成。")
	assert_signal_emitted(runner, "flow_cancelled", "取消后应发出 flow_cancelled。")


func test_flow_runner_reports_real_signal_timeout_and_releases_runtime_lease() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var node: RuntimeStateWaitFlowNode = RuntimeStateWaitFlowNode.new()
	graph.start_node_id = node.node_id
	graph.nodes = [node]
	var runner: GFFlowRunner = GFFlowRunner.new()
	var _configured_runner: GFFlowRunner = runner.with_signal_timeout(0.01, false)

	var report: Dictionary = await runner.run(graph, GFFlowContext.new())
	var trace: Array = GFVariantData.get_option_array(report, "trace")

	assert_push_warning("[GFFlowRunner] 等待 Signal 超时，流程将继续执行后续节点。")
	assert_eq(GFVariantData.get_option_string(report, "outcome"), "completed", "Signal 超时按既有策略继续流程时应完成运行。")
	assert_eq(GFVariantData.get_option_int(report, "signal_wait_count"), 1, "报告应统计一次 Signal 等待。")
	assert_eq(GFVariantData.get_option_int(report, "timed_out_signal_wait_count"), 1, "报告应统计真实超时。")
	assert_eq(GFVariantData.get_option_string(GFVariantData.as_dictionary(trace[0]), "wait_status"), "timeout", "节点 trace 应记录 timeout。")
	assert_false(node.is_runtime_state_leased(), "超时继续后必须释放节点运行态租约。")


func test_flow_runner_rejected_reentry_has_independent_report_and_does_not_replace_active_state() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	var node: ManualWaitFlowNode = ManualWaitFlowNode.new(&"wait", order)
	graph.start_node_id = node.node_id
	graph.nodes = [node]
	var runner: GFFlowRunner = GFFlowRunner.new()
	var completed_reports: Array[Dictionary] = []
	var _completed_connected: Error = runner.flow_completed.connect(func(report: Dictionary) -> void:
		completed_reports.append(report)
	) as Error
	@warning_ignore("missing_await")
	@warning_ignore("return_value_discarded")
	runner.run(graph, GFFlowContext.new())
	await get_tree().process_frame

	var rejected: Dictionary = await runner.run(graph, GFFlowContext.new())
	var rejected_copy: Dictionary = runner.get_last_run_report()

	assert_push_warning("[GFFlowRunner] 流程正在执行，忽略重复 run()。")
	assert_eq(GFVariantData.get_option_string(rejected, "outcome"), "rejected", "并发重入应返回 rejected。")
	assert_eq(GFVariantData.get_option_string(rejected, "reason"), "run_in_progress", "并发重入应给出稳定原因。")
	assert_eq(rejected_copy, rejected, "被拒绝的调用也应成为当时可查询的最近报告。")

	node.complete()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(completed_reports.size(), 1, "原运行应继续完成且只发出一份完成报告。")
	assert_eq(GFVariantData.get_option_string(completed_reports[0], "outcome"), "completed", "被拒绝的重入不得污染原运行终态。")
	assert_ne(GFVariantData.get_option_int(completed_reports[0], "run_id"), GFVariantData.get_option_int(rejected, "run_id"), "每次调用报告应有独立 run_id。")
	assert_eq(runner.get_last_run_report(), completed_reports[0], "原运行结束后最近报告应更新为其终态。")


func test_flow_runner_holds_non_waiting_signal_lease_until_signal_emits() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var node: NonWaitingSignalFlowNode = NonWaitingSignalFlowNode.new()
	graph.start_node_id = node.node_id
	graph.nodes = [node]
	var runner: GFFlowRunner = GFFlowRunner.new()

	var report: Dictionary = await runner.run(graph, GFFlowContext.new())

	assert_eq(GFVariantData.get_option_string(report, "outcome"), "completed", "非等待 Signal 不应阻塞流程完成。")
	assert_true(node.is_runtime_state_leased(), "异步工作发出完成 Signal 前仍应保护共享节点运行态。")
	node.set_runtime_value(&"late", true)
	assert_push_error("[GFFlowNode] set_runtime_value 失败：节点运行态已由隔离执行租约保护，必须通过当前 GFFlowContext 写入运行态。")

	node.complete()
	await get_tree().process_frame
	assert_false(node.is_runtime_state_leased(), "非等待 Signal 发出后应释放运行态租约。")
	var verification_lease: int = node.acquire_runtime_state_lease()
	assert_gt(verification_lease, 0, "Signal 发出后节点应可再次获得运行态租约。")
	assert_true(node.release_runtime_state_lease(verification_lease), "验证租约应可正常释放。")


func test_flow_runner_restores_graph_runtime_state_during_signal_wait() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var node: RuntimeStateWaitFlowNode = RuntimeStateWaitFlowNode.new()
	node.set_runtime_value(&"count", 7)
	graph.start_node_id = &"runtime_wait"
	graph.nodes = [node]
	var context: GFFlowContext = GFFlowContext.new()
	context.set_node_runtime_value(&"runtime_wait", &"count", 2)
	var runner: GFFlowRunner = GFFlowRunner.new()
	@warning_ignore("missing_await")
	@warning_ignore("return_value_discarded")
	runner.run(graph, context)

	await get_tree().process_frame
	var graph_state_during_wait: int = GFVariantData.to_int(node.get_runtime_value(&"count", 0))
	node.complete()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(graph_state_during_wait, 7, "等待 Signal 期间共享图资源不应暴露本次运行态。")
	assert_eq(GFVariantData.to_int(node.get_runtime_value(&"count", 0)), 7, "运行结束后共享图资源应恢复原始运行态。")
	assert_eq(GFVariantData.to_int(context.get_node_runtime_value(&"runtime_wait", &"count", 0)), 3, "本次运行态应写回 FlowContext。")


func test_flow_runner_acquires_shared_node_lease_before_node_started_signal() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var node: RuntimeStateWaitFlowNode = RuntimeStateWaitFlowNode.new()
	graph.start_node_id = node.node_id
	graph.nodes = [node]
	var first_runner: GFFlowRunner = GFFlowRunner.new()
	var second_runner: GFFlowRunner = GFFlowRunner.new()
	watch_signals(second_runner)
	var attempted_reentry: Array[bool] = [false]
	var _connected: Error = first_runner.node_started.connect(
		func(_node_id: StringName, _node: GFFlowNode) -> void:
			if attempted_reentry[0]:
				return
			attempted_reentry[0] = true
			@warning_ignore("missing_await")
			@warning_ignore("return_value_discarded")
			second_runner.run(graph, GFFlowContext.new())
	) as Error

	@warning_ignore("missing_await")
	@warning_ignore("return_value_discarded")
	first_runner.run(graph, GFFlowContext.new())
	await get_tree().process_frame
	node.complete()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(attempted_reentry[0], "node_started 监听器应实际尝试第二次执行。")
	assert_signal_emitted(second_runner, "flow_cancelled", "共享节点的第二个 Runner 应在 execute 前失败关闭。")
	assert_push_error("[GFFlowRunner] 节点运行态已被其他执行租约占用：runtime_wait")


func test_flow_node_runtime_value_does_not_leak_mutable_aliases() -> void:
	var node: GFFlowNode = GFFlowNode.new()
	var source: Dictionary = {
		"nested": {
			"value": 1,
		},
	}
	node.set_runtime_value(&"payload", source)
	GFVariantData.get_option_dictionary(source, "nested")["value"] = 2
	var first_read: Dictionary = GFVariantData.as_dictionary(node.get_runtime_value(&"payload"))
	GFVariantData.get_option_dictionary(first_read, "nested")["value"] = 3
	var second_read: Dictionary = GFVariantData.as_dictionary(node.get_runtime_value(&"payload"))

	assert_eq(
		GFVariantData.get_option_int(GFVariantData.get_option_dictionary(second_read, "nested"), "value"),
		1,
		"setter 输入与 getter 返回值都不得保留可变 Dictionary 别名。"
	)


func test_flow_runner_rejects_async_node_state_mutation_after_signal_return() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var node: AsyncRuntimeMutationFlowNode = AsyncRuntimeMutationFlowNode.new()
	node.set_runtime_value(&"count", 7)
	graph.start_node_id = node.node_id
	graph.nodes = [node]
	var context: GFFlowContext = GFFlowContext.new()
	context.set_node_runtime_value(node.node_id, &"count", 2)
	var runner: GFFlowRunner = GFFlowRunner.new()
	@warning_ignore("missing_await")
	@warning_ignore("return_value_discarded")
	runner.run(graph, context)

	await get_tree().process_frame
	node.mutate_and_complete()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_push_error("[GFFlowNode] set_runtime_value 失败：节点运行态已由隔离执行租约保护，必须通过当前 GFFlowContext 写入运行态。")
	assert_eq(GFVariantData.to_int(node.get_runtime_value(&"count", 0)), 7, "异步回调不得污染共享 graph Resource。")
	assert_eq(GFVariantData.to_int(context.get_node_runtime_value(node.node_id, &"count", 0)), 3, "Signal 返回前的同步运行态仍应写回 context。")


func test_flow_runner_loop_guard_cancels_instead_of_completing() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"start"
	graph.nodes = [
		RecordingFlowNode.new(&"start", order, PackedStringArray(["start"])),
	]
	var runner: GFFlowRunner = GFFlowRunner.new()
	runner.max_executed_nodes = 2
	watch_signals(runner)

	var report: Dictionary = await runner.run(graph, GFFlowContext.new())
	assert_push_warning("[GFFlowRunner] 达到最大节点执行数量，流程停止。")

	assert_eq(order, ["start", "start"], "loop guard 应在达到上限后停止。")
	assert_eq(GFVariantData.get_option_string(report, "outcome"), "aborted", "loop guard 应报告 aborted。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "max_executed_nodes", "报告应给出稳定保护原因。")
	assert_eq(GFVariantData.get_option_int(report, "pending_node_count"), 1, "报告应保留中止时尚未执行的节点数量。")
	assert_signal_not_emitted(runner, "flow_completed", "loop guard 截断不应被报告为普通完成。")
	assert_signal_emitted(runner, "flow_cancelled", "loop guard 截断应走非完成终态。")


## 验证流程图会校验连接端点与端口。
func test_flow_graph_validate_reports_connection_port_issues() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	start.output_ports = [_make_port(&"done", GFFlowPort.Direction.OUTPUT)]
	var end: GFFlowNode = GFFlowNode.new()
	end.node_id = &"end"
	end.input_ports = [_make_port(&"enter", GFFlowPort.Direction.INPUT)]
	graph.nodes = [start, end]
	graph.connections = [
		{
			"from_node_id": &"start",
			"from_port_id": &"missing",
			"to_node_id": &"end",
			"to_port_id": &"enter",
			"metadata": {},
		},
	]

	var report: Dictionary = graph.validate_graph()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失连接端口应使校验失败。")
	assert_true(_has_issue(report, "missing_connection_output_port"), "校验报告应包含 missing_connection_output_port。")


func test_flow_port_resource_path_is_not_used_as_identity() -> void:
	var port: GFFlowPort = GFFlowPort.new()
	port.resource_path = "res://temporary/generated_port.tres"

	assert_eq(port.get_port_id(), &"", "端口身份必须来自显式 port_id，不能回退到 resource_path。")
	assert_eq(GFVariantData.get_option_string_name(port.describe(), "port_id"), &"", "端口描述也不应把 resource_path 写成身份。")


## 验证流程图默认端口兼容性校验会报告类型不匹配。
func test_flow_graph_validate_reports_incompatible_ports_by_default() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	start.output_ports = [_make_typed_port(&"value", GFFlowPort.Direction.OUTPUT, GFFlowPort.ValueType.NUMBER)]
	var end: GFFlowNode = GFFlowNode.new()
	end.node_id = &"end"
	end.input_ports = [_make_typed_port(&"value", GFFlowPort.Direction.INPUT, GFFlowPort.ValueType.STRING)]
	graph.nodes = [start, end]
	graph.connections = [
		{
			"from_node_id": &"start",
			"from_port_id": &"value",
			"to_node_id": &"end",
			"to_port_id": &"value",
			"metadata": {},
		},
	]

	var report: Dictionary = graph.validate_graph()
	var compatibility: Dictionary = graph.check_connection_compatibility(&"start", &"value", &"end", &"value")

	assert_true(graph.validate_port_compatibility, "2.0 默认应启用端口兼容性校验。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "默认严格校验下类型不匹配应失败。")
	assert_true(_has_issue(report, "incompatible_connection_ports"), "校验报告应包含 incompatible_connection_ports。")
	assert_false(GFVariantData.get_option_bool(compatibility, "ok"), "兼容性检查应返回失败。")


func test_flow_graph_rejects_mixed_node_and_port_connections() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	start.output_ports = [_make_typed_port(&"done", GFFlowPort.Direction.OUTPUT, GFFlowPort.ValueType.ANY)]
	var end: GFFlowNode = GFFlowNode.new()
	end.node_id = &"end"
	graph.nodes = [start, end]

	var added: bool = graph.add_connection(&"start", &"done", &"end", &"")
	graph.connections = [
		{
			"from_node_id": &"start",
			"from_port_id": &"done",
			"to_node_id": &"end",
			"to_port_id": &"",
			"metadata": {},
		},
	]
	var report: Dictionary = graph.validate_graph()
	var compatibility: Dictionary = graph.check_connection_compatibility(&"start", &"done", &"end", &"")

	assert_false(added, "数据端口不能连接到节点级执行入口。")
	assert_false(GFVariantData.get_option_bool(compatibility, "ok"), "半端口兼容性检查应失败。")
	assert_true(_has_issue(report, "invalid_mixed_connection_ports"), "校验报告应标记半端口连接。")


## 验证流程图默认拒绝新增不兼容端口连接。
func test_flow_graph_add_connection_rejects_incompatible_ports_by_default() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	start.output_ports = [_make_typed_port(&"value", GFFlowPort.Direction.OUTPUT, GFFlowPort.ValueType.NUMBER)]
	var end: GFFlowNode = GFFlowNode.new()
	end.node_id = &"end"
	end.input_ports = [_make_typed_port(&"value", GFFlowPort.Direction.INPUT, GFFlowPort.ValueType.STRING)]
	graph.nodes = [start, end]

	assert_false(graph.add_connection(&"start", &"value", &"end", &"value"), "2.0 默认不应追加不兼容端口连接。")

	graph.validate_port_compatibility = false
	assert_true(graph.add_connection(&"start", &"value", &"end", &"value"), "项目可显式关闭端口兼容性校验以迁移旧资源。")


## 验证流程图连接描述可供编辑器或可视化工具消费。
func test_flow_graph_describes_connections() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var order: Array[String] = []
	graph.nodes = [
		RecordingFlowNode.new(&"start", order),
		RecordingFlowNode.new(&"end", order),
	]
	assert_true(graph.add_connection(&"start", &"", &"end", &"", { "label": "ok" }), "节点级连接应添加成功。")

	var description: Dictionary = graph.describe_graph()
	var connections: Array = GFVariantData.get_option_array(description, "connections")
	var first_connection: Dictionary = GFVariantData.as_dictionary(connections[0])
	var connection_metadata: Dictionary = GFVariantData.get_option_dictionary(first_connection, "metadata")

	assert_eq(GFVariantData.get_option_int(description, "connection_count"), 1, "图描述应包含连接数量。")
	assert_eq(GFVariantData.get_option_string_name(first_connection, "to_node_id"), &"end", "图描述应包含目标节点。")
	assert_eq(GFVariantData.get_option_string(connection_metadata, "label"), "ok", "连接元数据应保留。")


## 验证流程图提供编辑器目录和布局元数据。
func test_flow_graph_editor_catalog_describes_nodes() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var node: GFFlowNode = GFFlowNode.new()
	node.node_id = &"start"
	node.display_name = "Start"
	node.category = &"Core"
	graph.nodes = [node]

	assert_true(graph.set_node_editor_layout(&"start", Vector2(12.0, 24.0), Vector2(160.0, 80.0), true), "应能设置节点编辑器布局。")
	var report: Dictionary = graph.build_editor_report()
	var catalog: Dictionary = GFVariantData.get_option_dictionary(report, "catalog")
	var nodes: Array = GFVariantData.get_option_array(catalog, "nodes")
	var first_node: Dictionary = GFVariantData.as_dictionary(nodes[0])
	var editor: Dictionary = GFVariantData.get_option_dictionary(first_node, "editor")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效流程图编辑器报告应通过。")
	assert_eq(GFVariantData.get_option_string(first_node, "display_name"), "Start", "目录应包含显示名。")
	assert_eq(GFVariantData.get_option_string(first_node, "category"), "Core", "目录应包含分类。")
	assert_eq(GFVariantData.get_option_vector2(editor, "position"), Vector2(12.0, 24.0), "目录应包含编辑器位置。")
	assert_true(GFVariantData.get_option_bool(editor, "collapsed"), "目录应包含折叠状态。")


## 验证 FlowGraph 编辑器视图模型包含端口索引、布局和连接信息。
func test_flow_graph_editor_model_builds_graph_edit_ready_data() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	start.display_name = "Start"
	start.output_ports = [_make_port(&"done", GFFlowPort.Direction.OUTPUT)]
	start.editor_position = Vector2(10.0, 20.0)
	var end: GFFlowNode = GFFlowNode.new()
	end.node_id = &"end"
	end.input_ports = [_make_port(&"enter", GFFlowPort.Direction.INPUT)]
	graph.nodes = [start, end]
	var _add_connection_result_410: Variant = graph.add_connection(&"start", &"done", &"end", &"enter")
	var editor_model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()

	var view_model: Dictionary = editor_model.build_view_model(graph)
	var nodes: Array = GFVariantData.get_option_array(view_model, "nodes")
	var connections: Array = GFVariantData.get_option_array(view_model, "connections")
	var first_node: Dictionary = GFVariantData.as_dictionary(nodes[0])
	var first_connection: Dictionary = GFVariantData.as_dictionary(connections[0])
	var output_port_indices: Dictionary = GFVariantData.get_option_dictionary(first_node, "output_port_indices")
	var output_ports: Array = GFVariantData.get_option_array(first_node, "output_ports")
	var first_output_port: Dictionary = GFVariantData.as_dictionary(output_ports[0])

	assert_true(GFVariantData.get_option_bool(view_model, "ok"), "有效流程图应生成 ok 视图模型。")
	assert_eq(GFVariantData.get_option_vector2(first_node, "position"), Vector2(10.0, 20.0), "节点布局应进入视图模型。")
	assert_eq(GFVariantData.get_option_int(output_port_indices, &"done"), 0, "输出端口应有稳定索引。")
	assert_eq(GFVariantData.get_option_int(first_connection, "from_port_index"), 0, "连接应包含 GraphEdit 可用的输出端口索引。")
	assert_eq(GFVariantData.get_option_int(first_connection, "to_port_index"), 0, "连接应包含 GraphEdit 可用的输入端口索引。")
	assert_eq(GFVariantData.get_option_int(first_node, "execution_slot_index"), 0, "GraphEdit 视图模型应保留执行连接 slot。")
	assert_eq(GFVariantData.get_option_int(first_output_port, "graph_slot_index"), 1, "数据端口应避开执行连接 slot。")
	assert_eq(GFVariantData.get_option_int(first_connection, "from_graph_slot_index"), 1, "连接应包含 GraphEdit 输出 slot。")
	assert_eq(GFVariantData.get_option_int(first_connection, "to_graph_slot_index"), 1, "连接应包含 GraphEdit 输入 slot。")


## 验证 FlowGraph 编辑器视图模型只读取导出属性，不调用项目节点或端口方法。
func test_flow_graph_editor_model_reads_exports_without_calling_node_or_port_methods() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: MethodTrapFlowNode = MethodTrapFlowNode.new()
	start.node_id = &"start"
	start.display_name = "Start Export"
	var output_port: MethodTrapFlowPort = MethodTrapFlowPort.new()
	output_port.port_id = &"done"
	output_port.display_name = "Done Export"
	output_port.direction = GFFlowPort.Direction.OUTPUT
	output_port.value_type = GFFlowPort.ValueType.BOOL
	start.output_ports = [output_port]
	var end: MethodTrapFlowNode = MethodTrapFlowNode.new()
	end.node_id = &"end"
	end.display_name = "End Export"
	var input_port: MethodTrapFlowPort = MethodTrapFlowPort.new()
	input_port.port_id = &"enter"
	input_port.display_name = "Enter Export"
	input_port.direction = GFFlowPort.Direction.INPUT
	input_port.value_type = GFFlowPort.ValueType.BOOL
	end.input_ports = [input_port]
	graph.nodes = [start, end]

	assert_true(graph.add_connection(&"start", &"done", &"end", &"enter"), "结构化属性应足以添加有效端口连接。")
	var editor_model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	var view_model: Dictionary = editor_model.build_view_model(graph)
	var nodes: Array = GFVariantData.get_option_array(view_model, "nodes")
	var connections: Array = GFVariantData.get_option_array(view_model, "connections")
	var first_node: Dictionary = GFVariantData.as_dictionary(nodes[0])
	var output_ports: Array = GFVariantData.get_option_array(first_node, "output_ports")
	var first_output_port: Dictionary = GFVariantData.as_dictionary(output_ports[0])
	var first_connection: Dictionary = GFVariantData.as_dictionary(connections[0])

	assert_true(GFVariantData.get_option_bool(view_model, "ok"), "导出属性完整时编辑器视图模型应通过校验。")
	assert_eq(GFVariantData.get_option_string(first_node, "display_name"), "Start Export", "节点显示名应来自导出属性。")
	assert_eq(GFVariantData.get_option_string(first_output_port, "display_name"), "Done Export", "端口显示名应来自导出属性。")
	assert_eq(GFVariantData.get_option_int(first_connection, "from_port_index"), 0, "连接应能通过导出端口定位。")
	assert_false(start.any_method_called(), "编辑器模型不应调用自定义节点方法。")
	assert_false(end.any_method_called(), "编辑器模型不应调用自定义节点方法。")
	assert_false(output_port.any_method_called(), "编辑器模型不应调用自定义端口方法。")
	assert_false(input_port.any_method_called(), "编辑器模型不应调用自定义端口方法。")


## 验证 FlowGraph 结构报告也只读取导出属性。
func test_flow_graph_structural_reports_read_exports_without_calling_methods() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: MethodTrapFlowNode = MethodTrapFlowNode.new()
	start.node_id = &"start"
	start.display_name = "Start Export"
	var output_port: MethodTrapFlowPort = MethodTrapFlowPort.new()
	output_port.port_id = &"done"
	output_port.direction = GFFlowPort.Direction.OUTPUT
	output_port.value_type = GFFlowPort.ValueType.STRING
	start.output_ports = [output_port]
	var end: MethodTrapFlowNode = MethodTrapFlowNode.new()
	end.node_id = &"end"
	var input_port: MethodTrapFlowPort = MethodTrapFlowPort.new()
	input_port.port_id = &"enter"
	input_port.direction = GFFlowPort.Direction.INPUT
	input_port.value_type = GFFlowPort.ValueType.STRING
	end.input_ports = [input_port]
	graph.nodes = [start, end]
	graph.connections = [
		{
			"from_node_id": &"start",
			"from_port_id": &"done",
			"to_node_id": &"end",
			"to_port_id": &"enter",
			"metadata": {},
		},
	]

	var report: Dictionary = graph.build_editor_report()
	var description: Dictionary = graph.describe_graph()
	var compatibility: Dictionary = graph.check_connection_compatibility(&"start", &"done", &"end", &"enter")
	var catalog: Dictionary = GFVariantData.get_option_dictionary(report, "catalog")
	var catalog_nodes: Array = GFVariantData.get_option_array(catalog, "nodes")
	var report_node: Dictionary = GFVariantData.as_dictionary(catalog_nodes[0])
	var description_nodes: Array = GFVariantData.get_option_array(description, "nodes")
	var description_node: Dictionary = GFVariantData.as_dictionary(description_nodes[0])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "结构报告应通过导出属性完成校验。")
	assert_eq(GFVariantData.get_option_string(report_node, "display_name"), "Start Export", "目录应读取导出显示名。")
	assert_eq(GFVariantData.get_option_string(description_node, "display_name"), "Start Export", "图描述应读取导出显示名。")
	assert_true(GFVariantData.get_option_bool(compatibility, "ok"), "兼容性检查应读取导出端口属性。")
	assert_false(start.any_method_called(), "结构报告不应调用自定义节点方法。")
	assert_false(end.any_method_called(), "结构报告不应调用自定义节点方法。")
	assert_false(output_port.any_method_called(), "结构报告不应调用自定义端口方法。")
	assert_false(input_port.any_method_called(), "结构报告不应调用自定义端口方法。")


## 验证 FlowGraph 编辑器模型可应用通用自动布局。
func test_flow_graph_editor_model_applies_auto_layout() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	var end: GFFlowNode = GFFlowNode.new()
	end.node_id = &"end"
	graph.nodes = [start, end]
	var _add_connection_result_532: Variant = graph.add_connection(&"start", &"", &"end", &"")
	var editor_model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()

	var report: Dictionary = editor_model.auto_layout(graph, { "x_spacing": 120.0 })

	assert_true(GFVariantData.get_option_bool(report, "ok"), "自动布局应返回成功报告。")
	assert_eq(start.editor_position, Vector2.ZERO, "起点应在第一层。")
	assert_eq(end.editor_position, Vector2(120.0, 0.0), "目标节点应进入下一层。")
	assert_eq(GFVariantData.get_option_int(report, "changed_count"), 2, "两个节点都应被写入布局。")


func test_flow_graph_editor_model_auto_layout_uses_next_node_ids() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	start.next_node_ids = PackedStringArray(["end"])
	var end: GFFlowNode = GFFlowNode.new()
	end.node_id = &"end"
	graph.nodes = [start, end]
	var editor_model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()

	var report: Dictionary = editor_model.auto_layout(graph, { "x_spacing": 120.0 })

	assert_true(GFVariantData.get_option_bool(report, "ok"), "自动布局应完成。")
	assert_almost_eq(end.editor_position.x, 120.0, 0.001, "next_node_ids 执行边应参与分层布局。")


## 验证 Flow 工具面板复用编辑器模型展示结构报告。
func test_flow_graph_dock_builds_view_model_for_loaded_graph() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	graph.nodes = [start]
	var dock: GFFlowGraphDock = GFFlowGraphDock.new()

	dock.set_graph(graph)
	var view_model: Dictionary = dock.get_last_view_model()

	assert_eq(GFVariantData.get_option_int(view_model, "node_count"), 1, "Flow 工具面板应构建节点视图模型。")
	assert_true(GFVariantData.get_option_array(view_model, "nodes").size() == 1, "Flow 工具面板应保留节点条目。")
	dock.free()


func test_flow_graph_dock_rejects_non_project_resource_paths_and_clears_view() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var node: GFFlowNode = GFFlowNode.new()
	node.node_id = &"start"
	graph.nodes = [node]
	var dock: GFFlowGraphDock = GFFlowGraphDock.new()
	dock.set_graph(graph)

	dock.set_graph_path("user://flow_graph.tres")

	assert_null(dock._graph, "非 res:// 路径必须清除当前 graph，不能保留旧视图。")
	assert_eq(dock._graph_path, "", "非项目资源路径不得保留为 dock 的可加载路径。")
	assert_eq(dock.get_last_view_model(), {}, "拒绝路径后不得保留旧 graph 的 view model。")
	dock.free()
	await get_tree().process_frame


func test_flow_graph_dock_starts_with_compact_empty_state() -> void:
	var dock: GFFlowGraphDock = GFFlowGraphDock.new()

	assert_false(dock._content_split.visible, "未加载 FlowGraph 时不应显示空画布和侧栏。")
	assert_true(dock._empty_label.visible, "未加载 FlowGraph 时应显示明确空状态。")

	dock.free()


func test_flow_graph_dock_renders_graph_edit_nodes() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	var end: GFFlowNode = GFFlowNode.new()
	end.node_id = &"end"
	graph.nodes = [start, end]
	var dock: GFFlowGraphDock = GFFlowGraphDock.new()

	dock.set_graph(graph)

	assert_eq(dock._node_controls_by_id.size(), 2, "Flow 工具面板应为每个节点创建 GraphEdit 节点。")
	assert_true(dock._node_controls_by_id.has(&"start"), "GraphEdit 节点映射应保留源 node_id。")
	assert_true(dock._graph_edit.visible, "加载 FlowGraph 后应显示图编辑区域。")
	assert_true(dock._content_split.visible, "加载 FlowGraph 后应显示图编辑内容区。")
	dock.free()


func test_flow_graph_dock_connection_request_updates_graph() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	var end: GFFlowNode = GFFlowNode.new()
	end.node_id = &"end"
	graph.nodes = [start, end]
	var dock: GFFlowGraphDock = GFFlowGraphDock.new()
	dock.set_graph(graph)
	var start_control: GraphNode = _graph_node_control(dock, &"start")
	var end_control: GraphNode = _graph_node_control(dock, &"end")

	dock._on_connection_request(StringName(start_control.name), 0, StringName(end_control.name), 0)

	assert_true(graph.has_connection(&"start", &"", &"end", &""), "GraphEdit 连线请求应写入 FlowGraph。")
	dock.free()
	await get_tree().process_frame


func test_flow_graph_dock_canvas_move_updates_node_position() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	graph.nodes = [start]
	var dock: GFFlowGraphDock = GFFlowGraphDock.new()
	dock.set_graph(graph)
	var start_control: GraphNode = _graph_node_control(dock, &"start")
	start_control.position_offset = Vector2(42.0, 64.0)

	dock._on_end_node_move()

	assert_eq(start.editor_position, Vector2(42.0, 64.0), "GraphEdit 节点移动应写回 editor_position。")
	dock.free()
	await get_tree().process_frame


## 验证流程上下文可注册通用条件查询处理器。
func test_flow_context_queries_condition_handlers() -> void:
	var context: GFFlowContext = GFFlowContext.new()
	assert_true(context.register_condition_handler(&"ready", func(condition_id: StringName, payload: Variant, flow_context: GFFlowContext) -> Dictionary:
		return {
			"ok": true,
			"value": GFVariantData.to_text(payload) == "go" and flow_context == context,
			"metadata": { "condition_id": condition_id },
		}
	), "有效条件处理器应注册成功。")

	var result: Dictionary = context.query_condition(&"ready", "go")
	var missing: Dictionary = context.query_condition(&"missing")
	var result_metadata: Dictionary = GFVariantData.get_option_dictionary(result, "metadata")

	assert_true(GFVariantData.get_option_bool(result, "ok"), "有效条件查询应成功。")
	assert_true(GFVariantData.get_option_bool(result, "value"), "条件处理器应返回归一化 value。")
	assert_eq(GFVariantData.get_option_string_name(result_metadata, "condition_id"), &"ready", "条件查询应保留元数据。")
	assert_false(GFVariantData.get_option_bool(missing, "ok"), "缺失处理器应返回失败结果。")
	assert_eq(GFVariantData.get_option_string(missing, "reason"), "missing_condition_handler", "缺失处理器应有稳定 reason。")


func test_flow_context_null_condition_result_uses_default_value() -> void:
	var context: GFFlowContext = GFFlowContext.new()
	var _register_result_643: Variant = context.register_condition_handler(&"ready", func(_condition_id: StringName, _payload: Variant, _flow_context: GFFlowContext) -> Variant:
		return null
	)

	var result: Dictionary = context.query_condition(&"ready", null, false)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "null 结果仍应归一为有效条件报告。")
	assert_false(GFVariantData.get_option_bool(result, "value", true), "handler 未返回值时应使用 default_value。")


## 验证流程图可保存、恢复和清空节点运行态。
func test_flow_graph_serializes_runtime_state() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var node: GFFlowNode = GFFlowNode.new()
	node.node_id = &"node"
	node.set_runtime_value(&"cursor", 3)
	graph.nodes = [node]

	var snapshot: Dictionary = graph.serialize_runtime_state()
	graph.clear_runtime_state()
	assert_eq(GFVariantData.to_int(node.get_runtime_value(&"cursor", 0)), 0, "清空运行态后应回到默认值。")

	graph.deserialize_runtime_state(snapshot)
	assert_eq(GFVariantData.to_int(node.get_runtime_value(&"cursor", 0)), 3, "反序列化应恢复节点运行态。")

	var runtime_graph: GFFlowGraph = graph.instantiate_graph()
	var runtime_node: GFFlowNode = runtime_graph.get_node(&"node")
	assert_eq(GFVariantData.to_int(runtime_node.get_runtime_value(&"cursor", 0)), 0, "实例化运行副本默认应清理运行态。")


func test_flow_graph_runtime_state_restore_is_exact_for_missing_nodes() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var retained_node: GFFlowNode = GFFlowNode.new()
	retained_node.node_id = &"retained"
	retained_node.set_runtime_value(&"cursor", 9)
	var omitted_node: GFFlowNode = GFFlowNode.new()
	omitted_node.node_id = &"omitted"
	omitted_node.set_runtime_value(&"cursor", 7)
	graph.nodes = [retained_node, omitted_node]

	graph.deserialize_runtime_state({
		"nodes": {
			&"retained": {"cursor": 2},
		},
	})

	assert_eq(GFVariantData.to_int(retained_node.get_runtime_value(&"cursor", 0)), 2, "快照中存在的节点应恢复指定状态。")
	assert_eq(GFVariantData.to_int(omitted_node.get_runtime_value(&"cursor", 0)), 0, "快照中缺失的节点必须清空旧状态。")


func test_flow_runtime_snapshot_can_be_json_safe() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var node: GFFlowNode = GFFlowNode.new()
	node.node_id = &"runtime"
	node.set_runtime_value(&"owner", self)
	graph.nodes = [node]
	var context: GFFlowContext = GFFlowContext.new()
	var _set_owner_value_result: GFFlowContext = context.set_value(&"owner", self)
	context.set_node_runtime_value(&"runtime", &"owner", self)

	var graph_snapshot: Dictionary = graph.serialize_runtime_state(true)
	var context_snapshot: Dictionary = context.create_runtime_snapshot({ "json_compatible": true })
	var graph_json: String = JSON.stringify(graph_snapshot)
	var context_json: String = JSON.stringify(context_snapshot)
	var graph_owner: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(
			GFVariantData.get_option_dictionary(graph_snapshot, "nodes"),
			"runtime"
		),
		"owner"
	)
	var context_owner: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(context_snapshot, "values"),
		"owner"
	)

	assert_false(graph_json.is_empty(), "FlowGraph JSON-safe 运行态应可直接 JSON.stringify。")
	assert_false(context_json.is_empty(), "FlowContext JSON-safe 快照应可直接 JSON.stringify。")
	assert_true(graph_owner.has("__gf_report_value__"), "图运行态中的 Object 应转换为报告 marker。")
	assert_true(context_owner.has("__gf_report_value__"), "上下文 values 中的 Object 应转换为报告 marker。")


func test_flow_runner_isolates_node_runtime_state_into_context() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var node: RuntimeStateFlowNode = RuntimeStateFlowNode.new()
	node.set_runtime_value(&"count", 7)
	graph.start_node_id = &"runtime"
	graph.nodes = [node]
	var context: GFFlowContext = GFFlowContext.new()
	var runner: GFFlowRunner = GFFlowRunner.new()

	await runner.run(graph, context)

	assert_eq(GFVariantData.to_int(node.get_runtime_value(&"count", 0)), 7, "Runner 默认不应把本次运行态写回共享图资源。")
	assert_eq(GFVariantData.to_int(context.get_node_runtime_value(&"runtime", &"count", 0)), 1, "本次运行态应沉淀到 FlowContext。")


func test_flow_context_runtime_snapshot_restores_values_and_node_state() -> void:
	var context: GFFlowContext = GFFlowContext.new()
	var configured_context: GFFlowContext = context.set_value(&"chapter", 2)
	assert_eq(configured_context, context, "set_value 应返回当前上下文以支持链式构造。")
	context.set_next_nodes(PackedStringArray(["branch_a"]))
	context.set_node_runtime_value(&"node", &"cursor", 4)
	var _registered: bool = context.register_condition_handler(&"ready", func(_condition_id: StringName, _payload: Variant, _flow_context: GFFlowContext) -> bool:
		return true
	)

	var snapshot: Dictionary = context.create_runtime_snapshot({
		"metadata": {
			"save_slot": "slot_1",
		},
	})
	var updated_context: GFFlowContext = context.set_value(&"chapter", 9)
	assert_eq(updated_context, context, "set_value 覆盖值时仍应返回当前上下文。")
	context.clear_next_nodes()
	context.clear_node_runtime_state()

	assert_true(context.restore_runtime_snapshot(snapshot), "有效 FlowContext 快照应可恢复。")
	assert_eq(GFVariantData.to_int(context.get_value(&"chapter", 0)), 2, "恢复后 values 应回到快照值。")
	assert_true(context.has_next_nodes_override(), "恢复后应保留下一个节点覆盖状态。")
	assert_eq(context.next_node_ids, PackedStringArray(["branch_a"]), "恢复后应保留下一个节点列表。")
	assert_eq(GFVariantData.to_int(context.get_node_runtime_value(&"node", &"cursor", 0)), 4, "恢复后应保留节点运行态。")
	assert_true(context.has_condition_handler(&"ready"), "恢复运行数据不应清空已有条件处理器。")
	assert_eq(GFVariantData.get_option_packed_string_array(snapshot, "condition_handler_ids"), PackedStringArray(["ready"]), "快照可记录条件处理器 ID 供诊断展示。")


## 验证流程图可用轻量 Schema 校验编辑器元数据。
func test_flow_graph_validates_metadata_schema() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.editor_metadata = {
		"label": "Intro",
	}
	graph.metadata_schema = {
		"label": {
			"type": TYPE_STRING,
			"required": true,
		},
		"mode": {
			"type": TYPE_STRING,
			"required": true,
		},
	}

	var report: Dictionary = graph.validate_graph_metadata()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失必填元数据时应校验失败。")
	assert_true(_has_issue(report, "metadata_missing_required"), "元数据校验应报告缺失必填字段。")


func test_flow_metadata_empty_rule_is_rejected_consistently() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var schema: Dictionary = {
		"label": {},
	}
	var runtime_report: Dictionary = graph.validate_metadata({}, schema)
	var editor_report: Dictionary = GFFlowGraphEditorModel.new().validate_metadata_for_editor({}, schema)

	assert_true(_has_issue(runtime_report, "metadata_invalid_rule"), "runtime 必须拒绝没有约束语义的空 schema rule。")
	assert_true(_has_issue(editor_report, "metadata_invalid_rule"), "editor 必须与 runtime 使用相同的空 rule 语义。")
	assert_eq(
		GFVariantData.get_option_int(runtime_report, "warning_count"),
		GFVariantData.get_option_int(editor_report, "warning_count"),
		"runtime/editor 对相同 schema 的诊断数量应一致。"
	)


func test_flow_metadata_class_rule_supports_gdscript_global_classes() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var target_metadata: Dictionary = {
		"node": GFFlowNode.new(),
	}
	var schema: Dictionary = {
		"node": {
			"class_name": "GFFlowNode",
		},
	}
	var runtime_report: Dictionary = graph.validate_metadata(target_metadata, schema)
	var editor_report: Dictionary = GFFlowGraphEditorModel.new().validate_metadata_for_editor(target_metadata, schema)

	assert_false(_has_issue(runtime_report, "metadata_class_mismatch"), "runtime class rule 应识别 GDScript global class。")
	assert_false(_has_issue(editor_report, "metadata_class_mismatch"), "editor class rule 应识别 GDScript global class。")


func test_flow_metadata_class_rule_rejects_freed_objects_without_dereference() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var freed_node: Node = Node.new()
	var target_metadata: Dictionary = {
		"owner": freed_node,
	}
	freed_node.free()
	var schema: Dictionary = {
		"owner": {
			"class_name": "Node",
		},
	}

	var runtime_report: Dictionary = graph.validate_metadata(target_metadata, schema)
	var editor_report: Dictionary = GFFlowGraphEditorModel.new().validate_metadata_for_editor(
		target_metadata,
		schema
	)

	assert_true(_has_issue(runtime_report, "metadata_invalid_object"), "runtime schema 必须对已释放对象失败关闭。")
	assert_true(_has_issue(editor_report, "metadata_invalid_object"), "editor schema 必须对已释放对象失败关闭。")


## 验证编辑器模型可构建选择包并粘贴为新节点。
func test_flow_graph_editor_model_builds_and_pastes_selection_package() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	start.next_node_ids = PackedStringArray(["end"])
	start.editor_position = Vector2(4.0, 8.0)
	var end: GFFlowNode = GFFlowNode.new()
	end.node_id = &"end"
	graph.nodes = [start, end]
	var _add_connection_result_710: Variant = graph.add_connection(&"start", &"", &"end", &"")
	var editor_model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()

	var selection: Dictionary = editor_model.build_selection_package(graph, PackedStringArray(["start", "end"]))
	var paste_report: Dictionary = editor_model.paste_selection_package(graph, selection, Vector2(10.0, 0.0))
	var pasted_start: GFFlowNode = graph.get_node(&"start_2")
	var pasted_end: GFFlowNode = graph.get_node(&"end_2")

	assert_true(GFVariantData.get_option_bool(selection, "ok"), "选择包应构建成功。")
	assert_eq(GFVariantData.get_option_int(selection, "connection_count"), 1, "选择包应包含内部连接。")
	assert_true(GFVariantData.get_option_bool(paste_report, "ok"), "选择包应能粘贴。")
	assert_not_null(pasted_start, "粘贴应生成唯一节点 ID。")
	assert_not_null(pasted_end, "粘贴应生成目标节点。")
	assert_eq(pasted_start.editor_position, Vector2(14.0, 8.0), "粘贴应应用位置偏移。")
	assert_true(pasted_start.next_node_ids.has("end_2"), "粘贴应重映射内部后继节点。")
	assert_true(graph.has_connection(&"start_2", &"", &"end_2", &""), "粘贴应重映射内部连接。")

	var remove_report: Dictionary = editor_model.remove_nodes(graph, PackedStringArray(["start_2", "end_2"]))
	assert_eq(GFVariantData.get_option_int(remove_report, "removed_node_count"), 2, "批量删除应移除粘贴节点。")
	assert_false(graph.has_connection(&"start_2", &"", &"end_2", &""), "批量删除应移除相关连接。")


func test_flow_graph_editor_paste_rejects_invalid_node_ids_atomically() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var existing: GFFlowNode = GFFlowNode.new()
	existing.node_id = &"existing"
	graph.nodes = [existing]
	var valid_source: GFFlowNode = GFFlowNode.new()
	valid_source.node_id = &"valid"
	var invalid_source: GFFlowNode = GFFlowNode.new()
	invalid_source.node_id = &""
	var editor_model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()

	var report: Dictionary = editor_model.paste_selection_package(graph, {
		"nodes": [valid_source, invalid_source],
		"connections": [],
	})

	assert_false(GFVariantData.get_option_bool(report, "ok"), "包含空 node_id 的选择包必须整体拒绝。")
	assert_eq(GFVariantData.get_option_string(report, "error"), "invalid_selection_node_id", "失败报告应提供稳定原因。")
	assert_eq(graph.nodes.size(), 1, "失败粘贴必须保持 graph 原子不变。")
	assert_false(graph.has_node(&"valid"), "合法前缀节点也不得在整体失败时被部分写入。")


func test_flow_graph_remove_node_cleans_stale_next_node_ids() -> void:
	var graph: GFFlowGraph = GFFlowGraph.new()
	var start: GFFlowNode = GFFlowNode.new()
	start.node_id = &"start"
	start.next_node_ids = PackedStringArray(["end"])
	var end: GFFlowNode = GFFlowNode.new()
	end.node_id = &"end"
	graph.start_node_id = &"start"
	graph.nodes = [start, end]

	graph.remove_node(&"end")
	var report: Dictionary = graph.validate_graph()

	assert_false(start.next_node_ids.has("end"), "删除节点应同步清理其他节点的 stale next_node_ids。")
	assert_false(_has_issue(report, "missing_next_node"), "删除后的图不应留下缺失后继错误。")


## 验证流程图校验会报告缺失后继节点。
func test_flow_graph_validate_reports_missing_next_node() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"start"
	graph.nodes = [
		RecordingFlowNode.new(&"start", order, PackedStringArray(["missing"])),
	]

	var report: Dictionary = graph.validate_graph()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失后继节点应使校验失败。")
	assert_gt(GFVariantData.get_option_int(report, "error_count"), 0, "校验报告应统计错误数量。")
	assert_false(GFVariantData.get_option_string(report, "next_action").is_empty(), "校验报告应包含下一步建议。")
	assert_true(_has_issue(report, "missing_next_node"), "校验报告应包含 missing_next_node。")


## 验证流程图校验会提示不可达节点。
func test_flow_graph_validate_warns_unreachable_nodes() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"start"
	graph.nodes = [
		RecordingFlowNode.new(&"start", order, PackedStringArray(["middle"])),
		RecordingFlowNode.new(&"middle", order),
		RecordingFlowNode.new(&"orphan", order),
	]

	var report: Dictionary = graph.validate_graph()

	assert_true(GFVariantData.get_option_bool(report, "ok"), "不可达节点只应作为结构警告，不应阻止图通过基础校验。")
	assert_false(GFVariantData.get_option_bool(report, "healthy"), "存在警告时 healthy 应为 false。")
	assert_true(_has_issue(report, "unreachable_node"), "校验报告应包含 unreachable_node。")


## 验证流程图校验会提示循环结构。
func test_flow_graph_validate_warns_cycles() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"start"
	graph.nodes = [
		RecordingFlowNode.new(&"start", order, PackedStringArray(["middle"])),
		RecordingFlowNode.new(&"middle", order, PackedStringArray(["start"])),
	]

	var report: Dictionary = graph.validate_graph()

	assert_true(GFVariantData.get_option_bool(report, "ok"), "循环只应作为结构警告，运行时仍由 loop guard 保护。")
	assert_true(_has_issue(report, "cycle_detected"), "校验报告应包含 cycle_detected。")


func test_flow_graph_validate_cycles_uses_iterative_traversal_for_long_chains() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"node_0"
	var chain_length: int = 2048
	var cycle_target_index: int = 1024
	for index: int in range(chain_length):
		var node_id: StringName = StringName("node_%d" % index)
		var next_ids: PackedStringArray = PackedStringArray()
		if index < chain_length - 1:
			var _append_next_result: bool = next_ids.append("node_%d" % (index + 1))
		else:
			var _append_cycle_result: bool = next_ids.append("node_%d" % cycle_target_index)
		graph.nodes.append(RecordingFlowNode.new(node_id, order, next_ids))

	var report: Dictionary = graph.validate_graph()

	assert_true(GFVariantData.get_option_bool(report, "ok"), "长链尾部循环仍只应作为结构警告。")
	assert_true(_has_issue(report, "cycle_detected"), "长链尾部循环应被迭代检测报告。")


## 验证项目可显式开启终端节点提示。
func test_flow_graph_validate_can_warn_terminal_nodes() -> void:
	var order: Array[String] = []
	var graph: GFFlowGraph = GFFlowGraph.new()
	graph.start_node_id = &"start"
	graph.warn_terminal_nodes = true
	graph.nodes = [
		RecordingFlowNode.new(&"start", order),
	]

	var report: Dictionary = graph.validate_graph()

	assert_true(GFVariantData.get_option_bool(report, "ok"), "终端节点提示不应阻止基础校验通过。")
	assert_true(_has_issue(report, "terminal_node"), "校验报告应包含 terminal_node。")


## 验证 Flow Signal 超时可以跟随 GFTimeUtility 的暂停与 time_scale。
func test_flow_runner_signal_timeout_respects_time_utility() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var time_utility: GFTimeUtility = GFTimeUtility.new()
	await arch.register_utility_instance(time_utility)
	await arch.init()
	var runner: GFFlowRunner = GFFlowRunner.new()
	runner.inject_dependencies(arch)

	time_utility.time_scale = 0.5
	assert_almost_eq(
		GFAsyncWaitSupportBase.get_timeout_elapsed_msec(
			1000,
			2000,
			time_utility,
			runner.signal_timeout_respects_time_scale
		),
		500.0,
		0.001,
		"默认应按 GFTimeUtility.time_scale 推进超时。"
	)

	time_utility.is_paused = true
	assert_almost_eq(
		GFAsyncWaitSupportBase.get_timeout_elapsed_msec(
			2000,
			3000,
			time_utility,
			runner.signal_timeout_respects_time_scale
		),
		0.0,
		0.001,
		"GFTimeUtility 暂停时超时不应推进。"
	)

	var _with_signal_timeout_result_834: Variant = runner.with_signal_timeout(1.0, false)
	assert_almost_eq(
		GFAsyncWaitSupportBase.get_timeout_elapsed_msec(
			3000,
			4000,
			time_utility,
			runner.signal_timeout_respects_time_scale
		),
		1000.0,
		0.001,
		"关闭 time scale 后应使用真实时间。"
	)

	arch.dispose()


# --- 私有/辅助方法 ---

func _has_issue(report: Dictionary, kind: String) -> bool:
	for issue_variant: Variant in GFVariantData.get_option_array(report, "issues"):
		if not issue_variant is Dictionary:
			continue
		var issue: Dictionary = issue_variant
		if GFVariantData.get_option_string(issue, "kind") == kind:
			return true
	return false


func _color_value(source: Dictionary, key: Variant) -> Color:
	var value: Variant = GFVariantData.get_option_value(source, key)
	if value is Color:
		var color: Color = value
		return color
	return Color.TRANSPARENT


func _graph_node_control(dock: GFFlowGraphDock, node_id: StringName) -> GraphNode:
	var control_value: Variant = GFVariantData.get_option_value(dock._node_controls_by_id, node_id)
	if control_value is GraphNode:
		return control_value
	return null


func _make_port(port_id: StringName, direction: GFFlowPort.Direction) -> GFFlowPort:
	var port: GFFlowPort = GFFlowPort.new()
	port.port_id = port_id
	port.direction = direction
	return port


func _make_typed_port(
	port_id: StringName,
	direction: GFFlowPort.Direction,
	value_type: GFFlowPort.ValueType
) -> GFFlowPort:
	var port: GFFlowPort = _make_port(port_id, direction)
	port.value_type = value_type
	return port
