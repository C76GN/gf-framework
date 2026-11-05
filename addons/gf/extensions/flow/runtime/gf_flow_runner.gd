## GFFlowRunner: 通用流程图执行器。
##
## 按节点后继关系执行 GFFlowGraph，支持 Signal 等待、取消和简单循环保护。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFFlowRunner
extends RefCounted


# --- 信号 ---

## 流程开始时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param graph: 流程图资源。
signal flow_started(graph: GFFlowGraph)

## 节点开始执行时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param node_id: 节点 ID。
## [br]
## @param node: 节点资源。
signal node_started(node_id: StringName, node: GFFlowNode)

## 节点完成执行时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param node_id: 节点 ID。
## [br]
## @param node: 节点资源。
signal node_completed(node_id: StringName, node: GFFlowNode)

## 流程完成时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param report: 本次有界结构化运行报告。
## [br]
## @schema report: Dictionary，与 get_last_run_report() 返回结构相同。
signal flow_completed(report: Dictionary)

## 流程取消时发出。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param report: 本次取消或中止的有界结构化运行报告。
## [br]
## @schema report: Dictionary，与 get_last_run_report() 返回结构相同。
signal flow_cancelled(report: Dictionary)


# --- 常量 ---

## 异步信号等待与状态查询工具脚本。
## [br]
## @api private
const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")

## 默认 Signal 等待超时时长。
## [br]
## @api private
const _DEFAULT_SIGNAL_TIMEOUT_SECONDS: float = 30.0

## 流程正常完成。
## [br]
## @api public
## [br]
## @since 9.0.0
const OUTCOME_COMPLETED: StringName = &"completed"

## 流程收到显式取消请求。
## [br]
## @api public
## [br]
## @since 9.0.0
const OUTCOME_CANCELLED: StringName = &"cancelled"

## 流程因运行时保护条件中止。
## [br]
## @api public
## [br]
## @since 9.0.0
const OUTCOME_ABORTED: StringName = &"aborted"

## run() 请求在开始执行前被拒绝。
## [br]
## @api public
## [br]
## @since 9.0.0
const OUTCOME_REJECTED: StringName = &"rejected"


# --- 公共变量 ---

## 当前是否正在执行。该状态只读；调用方不能用它控制或结束流程。
## [br]
## @api public
## [br]
## @since 3.17.0
var is_running: bool:
	get:
		return _is_running
	set(_value):
		push_error("[GFFlowRunner][flow_runner.read_only_running_state] is_running is read-only runtime state and cannot be modified by callers.")

## 最多执行节点数量，避免循环图无限运行。小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 3.17.0
var max_executed_nodes: int = 1024

## Signal 等待超时时间。小于等于 0 表示不启用超时。
## [br]
## @api public
## [br]
## @since 3.17.0
var signal_timeout_seconds: float = _DEFAULT_SIGNAL_TIMEOUT_SECONDS:
	set(value):
		if not is_finite(value):
			signal_timeout_seconds = _DEFAULT_SIGNAL_TIMEOUT_SECONDS
			return
		signal_timeout_seconds = maxf(value, 0.0)

## Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。
## [br]
## @api public
## [br]
## @since 3.17.0
var signal_timeout_respects_time_scale: bool = true

## 运行报告最多保留多少条节点 trace；总数与丢弃数始终单独统计。
## [br]
## @api public
## [br]
## @since 9.0.0
var max_report_trace_entries: int = 128:
	set(value):
		max_report_trace_entries = maxi(value, 0)
		if _is_running:
			_run_state.set_trace_limit(max_report_trace_entries)


# --- 私有变量 ---

## 当前或最近完成一次运行的状态，结束时先封闭再通知。
## [br]
## @api private
var _run_state: GFFlowRunState = null

## 标记流程运行状态。
## [br]
## @api private
var _is_running: bool = false

## 弱引用运行此反馈流程的架构。
## [br]
## @api private
var _architecture_ref: WeakRef = null

## 生成运行报告使用的递增序号。
## [br]
## @api private
var _run_serial: int = 0

## 最近一次完成或拒绝的流程运行报告。
## [br]
## @api private
var _last_run_report: Dictionary = {}


# --- 公共方法 ---

## 注入架构。通常由 GFArchitecture 创建或注册时自动调用。
## [br]
## @api framework_internal
## [br]
## @since 3.17.0
## [br]
## @param architecture: 架构实例。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null


## 运行流程图。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param graph: 流程图资源。
## [br]
## @param context: 可选业务上下文，可供其他 Runner 同时使用。
## [br]
## @param initial_nodes: 显式提供给根帧的初始节点进度。
## [br]
## @schema initial_nodes: 节点 ID 到 Dictionary 的映射，本轮复制后使用。
## [br]
## @return: 本次有界结构化运行报告；未开始时 outcome 为 rejected。
## [br]
## @schema return: Dictionary，包含 schema_version、run_id、outcome、reason、单调时间、节点计数、pending_node_count、Signal 等待状态计数、trace 截断统计和有界 trace。
func run(
	graph: GFFlowGraph,
	context: GFFlowContext = null,
	initial_nodes: Dictionary = {}
) -> Dictionary:
	if graph == null:
		push_error("[GFFlowRunner][flow_runner.missing_graph] run failed: graph is null.")
		return _store_rejected_report(&"invalid_graph")
	if _is_running:
		push_warning("[GFFlowRunner][flow_runner.already_running] The flow is already running; the duplicate run() call was ignored.")
		return _store_rejected_report(&"run_in_progress")

	var state: GFFlowRunState = GFFlowRunState.new()
	if not state.start(graph, initial_nodes):
		return _store_rejected_report(&"invalid_initial_nodes")
	_run_state = state
	var flow_context: GFFlowContext = context if context != null else GFFlowContext.new(_get_architecture_or_null())

	_is_running = true
	state.begin_report(
		_next_run_id(),
		max_report_trace_entries
	)
	flow_started.emit(graph)
	await _run_graph(flow_context, state)
	var report: Dictionary = state.finish()
	_last_run_report = report.duplicate(true)
	_is_running = false
	if GFVariantData.get_option_string_name(report, "outcome") == OUTCOME_COMPLETED:
		flow_completed.emit(report.duplicate(true))
	else:
		flow_cancelled.emit(report.duplicate(true))
	return report


## 请求取消流程。
## [br]
## @api public
## [br]
## @since 3.17.0
func cancel() -> void:
	if _is_running:
		var _accepted: bool = _run_state.cancel()


## 获取正在运行或最近完成的状态。每次成功接纳运行都会创建新对象。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前或最近结束的 RunState，从未接纳过运行时为 null。
func get_run_state() -> GFFlowRunState:
	return _run_state


## 设置 Signal 等待超时时间。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param seconds: 秒数；小于等于 0 时表示不启用超时。
## [br]
## @param respect_time_scale: 是否跟随 GFTimeUtility 的暂停与 time_scale。
## [br]
## @return: 当前执行器。
func with_signal_timeout(seconds: float, respect_time_scale: bool = true) -> GFFlowRunner:
	signal_timeout_seconds = seconds
	signal_timeout_respects_time_scale = respect_time_scale
	return self


## 获取最近一次已结束或被拒绝的运行报告副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 最近报告；尚未调用 run() 时为空字典。
## [br]
## @schema return: Dictionary，与 run() 返回结构相同。
func get_last_run_report() -> Dictionary:
	return _last_run_report.duplicate(true)


# --- 私有/辅助方法 ---

## 按队列顺序执行流程图节点，处理取消、限制、异步等待、运行时状态隔离并记录轨迹。
## [br]
## @api private
func _run_graph(context: GFFlowContext, state: GFFlowRunState) -> void:
	var executed_count: int = 0
	while state.should_continue() and state.advance_frame():
		if max_executed_nodes > 0 and executed_count >= max_executed_nodes:
			state.abort(&"max_executed_nodes")
			push_warning("[GFFlowRunner][flow_runner.node_execution_limit] The maximum node execution count was reached; the flow stopped.")
			break

		var graph: GFFlowGraph = state.current_graph()
		var node_id: StringName = state.take_next_node()
		if node_id == &"":
			continue

		var node: GFFlowNode = graph.get_node(node_id)
		if node == null:
			push_warning("[GFFlowRunner][flow_runner.missing_node] Flow node was not found: %s." % String(node_id))
			state.increment(&"missing_node_count")
			state.record_node(
				node_id,
				&"missing",
				Time.get_ticks_usec(),
				&"not_started",
				&"missing_node"
			)
			state.abort(&"missing_node")
			return
		var node_started_usec: int = Time.get_ticks_usec()
		var runtime_state_lease_id: int = node.acquire_runtime_state_lease()
		if runtime_state_lease_id <= 0:
			state.abort(&"node_runtime_state_busy")
			push_error("[GFFlowRunner][flow_runner.runtime_lease_active] Node runtime state is held by another execution lease: %s." % String(node_id))
			state.record_node(
				node_id,
				&"aborted",
				node_started_usec,
				&"not_started",
				&"node_runtime_state_busy"
			)
			return
		var execution: GFFlowNodeExecution = state.begin_execution(node_id)
		node_started.emit(node_id, node)
		if not state.should_continue():
			if runtime_state_lease_id > 0:
				var _released_after_cancel: bool = node.release_runtime_state_lease(runtime_state_lease_id)
			state.record_node(
				node_id,
				&"cancelled",
				node_started_usec,
				&"not_started",
				&"cancel_requested"
			)
			return
		executed_count += 1
		state.increment(&"executed_node_count")
		var result: Variant = node.execute(context, execution)
		var wait_status: StringName = &"not_requested"
		if result is Signal:
			var result_signal: Signal = result
			if node.wait_for_result:
				state.begin_wait(node_id)
				var wait_report: Dictionary = await _await_signal_safely(result_signal, state)
				wait_status = GFVariantData.get_option_string_name(
					wait_report,
					"status",
					&"invalid"
				)
				state.end_wait(wait_status)
				if runtime_state_lease_id > 0:
					if not node.release_runtime_state_lease(runtime_state_lease_id):
						state.abort(&"node_runtime_state_lease_release_failed")
						push_error("[GFFlowRunner][flow_runner.async_lease_release_failed] Could not release the asynchronous node runtime lease: %s." % String(node_id))
						state.record_node(
							node_id,
							&"aborted",
							node_started_usec,
							wait_status,
							&"node_runtime_state_lease_release_failed"
						)
						return
					runtime_state_lease_id = 0
			elif runtime_state_lease_id > 0:
				if not _release_runtime_state_lease_when_signal_emits(
					node,
					result_signal,
					runtime_state_lease_id,
					state
				):
					state.record_node(
						node_id,
						&"aborted",
						node_started_usec,
						wait_status,
						&"node_runtime_state_lease_connect_failed"
					)
					return
				runtime_state_lease_id = 0
		elif runtime_state_lease_id > 0:
			if not node.release_runtime_state_lease(runtime_state_lease_id):
				state.abort(&"node_runtime_state_lease_release_failed")
				push_error("[GFFlowRunner][flow_runner.sync_lease_release_failed] Could not release the synchronous node runtime lease: %s." % String(node_id))
				state.record_node(
					node_id,
					&"aborted",
					node_started_usec,
					wait_status,
					&"node_runtime_state_lease_release_failed"
				)
				return
			runtime_state_lease_id = 0
		if not state.should_continue():
			state.record_node(
				node_id,
				&"cancelled",
				node_started_usec,
				wait_status,
				&"cancel_requested"
			)
			return
		var child: GFFlowGraph = execution.take_child_graph()
		state.close_execution()
		state.increment(&"completed_node_count")
		state.record_node(
			node_id,
			&"completed",
			node_started_usec,
			wait_status,
			&""
		)
		node_completed.emit(node_id, node)

		if not state.should_continue():
			return
		var next_ids: PackedStringArray = _get_runtime_successor_node_ids(
			graph,
			node,
			context,
			execution
		)
		if not state.should_continue():
			return
		state.schedule(next_ids, child)


## 使用共享等待工具等待节点 Signal，并应用取消、时间工具和超时配置。
## [br]
## @api private
func _await_signal_safely(result_signal: Signal, state: GFFlowRunState) -> Dictionary:
	return await (
		_GF_ASYNC_WAIT_SUPPORT.await_signal_state(
			result_signal,
			{
				"should_continue": state.should_continue,
				"time_utility": _get_time_utility(),
				"timeout_seconds": signal_timeout_seconds,
				"respect_time_scale": signal_timeout_respects_time_scale,
				"timeout_warning": "[GFFlowRunner][flow_runner.signal_timeout] Waiting for the Signal timed out; the flow will continue with subsequent nodes.",
			}
		)
	)


## 优先使用本次节点执行捕获的后继，否则合并默认后继与节点级图连接。
## [br]
## @api private
func _get_runtime_successor_node_ids(
	graph: GFFlowGraph,
	node: GFFlowNode,
	context: GFFlowContext,
	execution: GFFlowNodeExecution
) -> PackedStringArray:
	if execution.has_next_nodes_override():
		return execution.get_next_node_ids()

	var result: PackedStringArray = node.get_next_nodes(context)
	for connection: Dictionary in graph.get_connections_from(node.node_id):
		if (
			GFVariantData.get_option_string_name(
				connection,
				"from_port_id",
				&""
			) != &""
			or GFVariantData.get_option_string_name(
				connection,
				"to_port_id",
				&""
			) != &""
		):
			continue
		_append_unique_packed_string(
			result,
			String(
				GFVariantData.get_option_string_name(
					connection,
					"to_node_id",
					&""
				)
			)
		)
	return result


## 为非等待 Signal 连接一次性租约释放回调；连接失败时立即释放并中止。
## [br]
## @api private
func _release_runtime_state_lease_when_signal_emits(
	node: GFFlowNode,
	result_signal: Signal,
	runtime_state_lease_id: int,
	state: GFFlowRunState
) -> bool:
	var release_callback: Callable = (Callable(node, "release_runtime_state_lease").bind(runtime_state_lease_id))
	var signal_argument_count: int = _GF_ASYNC_WAIT_SUPPORT.get_signal_argument_count(result_signal)
	if signal_argument_count > 0:
		release_callback = release_callback.unbind(signal_argument_count)
	var connect_error: Error = result_signal.connect(
		release_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error == OK:
		return true
	var _released_after_connect_failure: bool = node.release_runtime_state_lease(runtime_state_lease_id)
	state.abort(&"node_runtime_state_lease_connect_failed")
	push_error("[GFFlowRunner][flow_runner.lease_release_connection_failed] Could not connect runtime lease release for a non-waited Signal.")
	return false


## 从架构获取有效 GFTimeUtility。
## [br]
## @api private
func _get_time_utility() -> GFTimeUtility:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	var utility: Object = architecture.get_utility(GFTimeUtility)
	if utility is GFTimeUtility:
		var time_utility: GFTimeUtility = utility
		return time_utility
	return null


## 优先从弱引用读取架构，失效时回退到 GFAutoload。
## [br]
## @api private
func _get_architecture_or_null() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture_value: Object = _architecture_ref.get_ref()
		if architecture_value is GFArchitecture:
			var architecture: GFArchitecture = architecture_value
			return architecture
	return GFAutoload.get_architecture_or_null()


## 构造并保存一次被拒绝运行的报告。
## [br]
## @api private
func _store_rejected_report(reason: StringName) -> Dictionary:
	var report: Dictionary = GFFlowRunState.make_report(
		_next_run_id(),
		OUTCOME_REJECTED,
		reason
	)
	_last_run_report = report.duplicate(true)
	return report


## 递增并返回下一运行 ID。
## [br]
## @api private
func _next_run_id() -> int:
	_run_serial += 1
	return _run_serial


## 跳过空值和重复项后追加字符串。
## [br]
## @api private
func _append_unique_packed_string(target: PackedStringArray, value: String) -> void:
	if value.is_empty() or target.has(value):
		return
	var appended: bool = target.append(value)
	if appended:
		return
