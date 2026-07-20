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

const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")

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

## 当前是否正在执行。
## [br]
## @api public
## [br]
## @since 3.17.0
var is_running: bool = false

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
var signal_timeout_seconds: float = 30.0

## Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。
## [br]
## @api public
## [br]
## @since 3.17.0
var signal_timeout_respects_time_scale: bool = true

## 运行时是否把节点 runtime_state 隔离到 GFFlowContext，避免污染共享图资源。
## [br]
## @api public
## [br]
## @since 3.17.0
var isolate_graph_runtime_state: bool = true

## 运行报告最多保留多少条节点 trace；总数与丢弃数始终单独统计。
## [br]
## @api public
## [br]
## @since 9.0.0
var max_report_trace_entries: int = 128:
	set(value):
		max_report_trace_entries = maxi(value, 0)
		_trim_active_trace()


# --- 私有变量 ---

var _cancel_requested: bool = false
var _abort_reason: StringName = &""
var _architecture_ref: WeakRef = null
var _run_serial: int = 0
var _active_report: Dictionary = {}
var _active_trace: Array[Dictionary] = []
var _trace_entry_count: int = 0
var _dropped_trace_entry_count: int = 0
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
## @param context: 可选上下文。
## [br]
## @return 本次有界结构化运行报告；未开始时 outcome 为 rejected。
## [br]
## @schema return: Dictionary，包含 schema_version、run_id、outcome、reason、单调时间、节点计数、pending_node_count、Signal 等待状态计数、trace 截断统计和有界 trace。
func run(graph: GFFlowGraph, context: GFFlowContext = null) -> Dictionary:
	if graph == null:
		push_error("[GFFlowRunner] run 失败：graph 为空。")
		return _store_rejected_report(&"invalid_graph")
	if is_running:
		push_warning("[GFFlowRunner] 流程正在执行，忽略重复 run()。")
		return _store_rejected_report(&"run_in_progress")

	var flow_context: GFFlowContext = context if context != null else GFFlowContext.new(_get_architecture_or_null())
	if flow_context.get_architecture() == null:
		flow_context.set_architecture(_get_architecture_or_null())

	is_running = true
	_cancel_requested = false
	_abort_reason = &""
	_begin_run_report()
	flow_started.emit(graph)
	await _run_graph(graph, flow_context)
	is_running = false
	var outcome: StringName = OUTCOME_COMPLETED
	var reason: StringName = &""
	if _abort_reason != &"":
		outcome = OUTCOME_ABORTED
		reason = _abort_reason
	elif _cancel_requested:
		outcome = OUTCOME_CANCELLED
		reason = &"cancel_requested"
	var report: Dictionary = _finish_run_report(outcome, reason)
	if outcome == OUTCOME_COMPLETED:
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
	_cancel_requested = true


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
	signal_timeout_seconds = maxf(seconds, 0.0)
	signal_timeout_respects_time_scale = respect_time_scale
	return self


## 获取最近一次已结束或被拒绝的运行报告副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 最近报告；尚未调用 run() 时为空字典。
## [br]
## @schema return: Dictionary，与 run() 返回结构相同。
func get_last_run_report() -> Dictionary:
	return _last_run_report.duplicate(true)


# --- 私有/辅助方法 ---

func _run_graph(graph: GFFlowGraph, context: GFFlowContext) -> void:
	var pending: PackedStringArray = PackedStringArray([String(graph.start_node_id)])
	var pending_index: int = 0
	var executed_count: int = 0
	_active_report["pending_node_count"] = pending.size()
	while pending_index < pending.size() and not _cancel_requested:
		if max_executed_nodes > 0 and executed_count >= max_executed_nodes:
			_abort_reason = &"max_executed_nodes"
			push_warning("[GFFlowRunner] 达到最大节点执行数量，流程停止。")
			break

		var node_id: StringName = StringName(pending[pending_index])
		pending_index += 1
		_active_report["pending_node_count"] = maxi(pending.size() - pending_index, 0)
		if node_id == &"":
			continue

		var node: GFFlowNode = graph.get_node(node_id)
		if node == null:
			push_warning("[GFFlowRunner] 缺少流程节点：%s" % String(node_id))
			_increment_active_report_count("missing_node_count")
			_append_trace_entry(_make_trace_entry(
				node_id,
				&"missing",
				Time.get_ticks_usec(),
				Time.get_ticks_usec(),
				&"not_started",
				&"missing_node"
			))
			continue
		var node_started_usec: int = Time.get_ticks_usec()
		var runtime_state_lease_id: int = 0
		if isolate_graph_runtime_state:
			runtime_state_lease_id = node.acquire_runtime_state_lease()
			if runtime_state_lease_id <= 0:
				_abort_reason = &"node_runtime_state_busy"
				push_error("[GFFlowRunner] 节点运行态已被其他执行租约占用：%s" % String(node_id))
				_append_trace_entry(_make_trace_entry(
					node_id,
					&"aborted",
					node_started_usec,
					Time.get_ticks_usec(),
					&"not_started",
					_abort_reason
				))
				return

		context.clear_next_nodes()
		node_started.emit(node_id, node)
		if _cancel_requested:
			if runtime_state_lease_id > 0:
				var _released_after_cancel: bool = node.release_runtime_state_lease(runtime_state_lease_id)
			_append_trace_entry(_make_trace_entry(
				node_id,
				&"cancelled",
				node_started_usec,
				Time.get_ticks_usec(),
				&"not_started",
				&"cancel_requested"
			))
			return
		executed_count += 1
		_active_report["executed_node_count"] = executed_count
		var result: Variant = _execute_node_with_runtime_state(
			node,
			context,
			runtime_state_lease_id
		)
		if _abort_reason != &"":
			if runtime_state_lease_id > 0:
				var _released_after_abort: bool = node.release_runtime_state_lease(runtime_state_lease_id)
			_append_trace_entry(_make_trace_entry(
				node_id,
				&"aborted",
				node_started_usec,
				Time.get_ticks_usec(),
				&"not_started",
				_abort_reason
			))
			return
		var wait_status: StringName = &"not_requested"
		if result is Signal:
			var result_signal: Signal = result
			if node.wait_for_result:
				_increment_active_report_count("signal_wait_count")
				var wait_report: Dictionary = await _await_signal_safely(result_signal)
				wait_status = GFVariantData.get_option_string_name(
					wait_report,
					"status",
					&"invalid"
				)
				_record_signal_wait_status(wait_status)
				if runtime_state_lease_id > 0:
					if not node.release_runtime_state_lease(runtime_state_lease_id):
						_abort_reason = &"node_runtime_state_lease_release_failed"
						push_error("[GFFlowRunner] 无法释放异步节点运行态租约：%s" % String(node_id))
						_append_trace_entry(_make_trace_entry(
							node_id,
							&"aborted",
							node_started_usec,
							Time.get_ticks_usec(),
							wait_status,
							_abort_reason
						))
						return
					runtime_state_lease_id = 0
				if _cancel_requested:
					_append_trace_entry(_make_trace_entry(
						node_id,
						&"cancelled",
						node_started_usec,
						Time.get_ticks_usec(),
						wait_status,
						&"cancel_requested"
					))
					return
			elif runtime_state_lease_id > 0:
				if not _release_runtime_state_lease_when_signal_emits(
					node,
					result_signal,
					runtime_state_lease_id
				):
					_append_trace_entry(_make_trace_entry(
						node_id,
						&"aborted",
						node_started_usec,
						Time.get_ticks_usec(),
						wait_status,
						_abort_reason
					))
					return
				runtime_state_lease_id = 0
		elif runtime_state_lease_id > 0:
			if not node.release_runtime_state_lease(runtime_state_lease_id):
				_abort_reason = &"node_runtime_state_lease_release_failed"
				push_error("[GFFlowRunner] 无法释放同步节点运行态租约：%s" % String(node_id))
				_append_trace_entry(_make_trace_entry(
					node_id,
					&"aborted",
					node_started_usec,
					Time.get_ticks_usec(),
					wait_status,
					_abort_reason
				))
				return
			runtime_state_lease_id = 0
		_increment_active_report_count("completed_node_count")
		_append_trace_entry(_make_trace_entry(
			node_id,
			&"completed",
			node_started_usec,
			Time.get_ticks_usec(),
			wait_status,
			&""
		))
		node_completed.emit(node_id, node)

		var next_ids: PackedStringArray = _get_runtime_successor_node_ids(graph, node, context)
		for next_id: String in next_ids:
			_append_packed_string(pending, next_id)
		_active_report["pending_node_count"] = maxi(pending.size() - pending_index, 0)
	_active_report["pending_node_count"] = maxi(pending.size() - pending_index, 0)


func _await_signal_safely(result_signal: Signal) -> Dictionary:
	return await _GF_ASYNC_WAIT_SUPPORT.await_signal_state(result_signal, {
		"should_continue": _should_continue_waiting,
		"time_utility": _get_time_utility(),
		"timeout_seconds": signal_timeout_seconds,
		"respect_time_scale": signal_timeout_respects_time_scale,
		"timeout_warning": "[GFFlowRunner] 等待 Signal 超时，流程将继续执行后续节点。",
	})


func _execute_node_with_runtime_state(
	node: GFFlowNode,
	context: GFFlowContext,
	runtime_state_lease_id: int
) -> Variant:
	if not isolate_graph_runtime_state:
		return node.execute(context)
	if not node.begin_runtime_state_lease_write(runtime_state_lease_id):
		_abort_reason = &"node_runtime_state_lease_invalid"
		push_error("[GFFlowRunner] 无法进入节点运行态租约写阶段。")
		return null

	var original_state: Dictionary = node.serialize_runtime_state()
	_apply_context_runtime_state_to_node(node, context)
	var result: Variant = node.execute(context)
	_store_node_runtime_state_in_context(node, context)
	node.clear_runtime_state()
	node.deserialize_runtime_state(original_state)
	if not node.end_runtime_state_lease_write(runtime_state_lease_id):
		_abort_reason = &"node_runtime_state_lease_invalid"
		push_error("[GFFlowRunner] 无法结束节点运行态租约写阶段。")
		return null
	return result


func _apply_context_runtime_state_to_node(node: GFFlowNode, context: GFFlowContext) -> void:
	node.clear_runtime_state()
	node.deserialize_runtime_state(_get_context_node_runtime_state(context, node.node_id))


func _store_node_runtime_state_in_context(node: GFFlowNode, context: GFFlowContext) -> void:
	var context_state: Dictionary = context.serialize_runtime_state()
	var node_states: Dictionary = GFVariantData.get_option_dictionary(context_state, "nodes")
	var node_state: Dictionary = node.serialize_runtime_state()
	if node_state.is_empty():
		var _erased_name: bool = node_states.erase(node.node_id)
		var _erased_text: bool = node_states.erase(String(node.node_id))
	else:
		node_states[node.node_id] = node_state
	context.deserialize_runtime_state({
		"nodes": node_states,
	})


func _get_context_node_runtime_state(context: GFFlowContext, node_id: StringName) -> Dictionary:
	var context_state: Dictionary = context.serialize_runtime_state()
	var node_states: Dictionary = GFVariantData.get_option_dictionary(context_state, "nodes")
	var state_value: Variant = GFVariantData.get_option_value(node_states, node_id, null)
	if state_value == null:
		state_value = GFVariantData.get_option_value(node_states, String(node_id), {})
	if state_value is Dictionary:
		var state: Dictionary = state_value
		return state.duplicate(true)
	return {}


func _get_runtime_successor_node_ids(
	graph: GFFlowGraph,
	node: GFFlowNode,
	context: GFFlowContext
) -> PackedStringArray:
	if context.has_next_nodes_override():
		return context.next_node_ids.duplicate()

	var result: PackedStringArray = node.get_next_nodes(context)
	for connection: Dictionary in graph.get_connections_from(node.node_id):
		if (
			GFVariantData.get_option_string_name(connection, "from_port_id", &"") != &""
			or GFVariantData.get_option_string_name(connection, "to_port_id", &"") != &""
		):
			continue
		_append_unique_packed_string(
			result,
			String(GFVariantData.get_option_string_name(connection, "to_node_id", &""))
		)
	return result


func _release_runtime_state_lease_when_signal_emits(
	node: GFFlowNode,
	result_signal: Signal,
	runtime_state_lease_id: int
) -> bool:
	var release_callback: Callable = Callable(node, "release_runtime_state_lease").bind(
		runtime_state_lease_id
	)
	var signal_argument_count: int = _GF_ASYNC_WAIT_SUPPORT.get_signal_argument_count(
		result_signal
	)
	if signal_argument_count > 0:
		release_callback = release_callback.unbind(signal_argument_count)
	var connect_error: Error = result_signal.connect(
		release_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error == OK:
		return true
	var _released_after_connect_failure: bool = node.release_runtime_state_lease(
		runtime_state_lease_id
	)
	_abort_reason = &"node_runtime_state_lease_connect_failed"
	push_error("[GFFlowRunner] 无法建立非等待 Signal 的运行态租约释放连接。")
	return false


func _get_time_utility() -> GFTimeUtility:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	var utility: Object = architecture.get_utility(GFTimeUtility)
	if utility is GFTimeUtility:
		var time_utility: GFTimeUtility = utility
		return time_utility
	return null


func _should_continue_waiting() -> bool:
	return not _cancel_requested


func _get_architecture_or_null() -> GFArchitecture:
	if _architecture_ref != null:
		var architecture_value: Object = _architecture_ref.get_ref()
		if architecture_value is GFArchitecture:
			var architecture: GFArchitecture = architecture_value
			return architecture
	return GFAutoload.get_architecture_or_null()


func _begin_run_report() -> void:
	_active_trace.clear()
	_trace_entry_count = 0
	_dropped_trace_entry_count = 0
	_active_report = {
		"schema_version": 1,
		"run_id": _next_run_id(),
		"outcome": "running",
		"reason": "",
		"started_at_ticks_usec": Time.get_ticks_usec(),
		"finished_at_ticks_usec": 0,
		"duration_msec": 0.0,
		"executed_node_count": 0,
		"completed_node_count": 0,
		"missing_node_count": 0,
		"pending_node_count": 0,
		"signal_wait_count": 0,
		"timed_out_signal_wait_count": 0,
		"cancelled_signal_wait_count": 0,
		"invalid_signal_wait_count": 0,
		"trace_entry_count": 0,
		"retained_trace_entry_count": 0,
		"dropped_trace_entry_count": 0,
		"trace_truncated": false,
		"trace": [],
	}


func _finish_run_report(outcome: StringName, reason: StringName) -> Dictionary:
	var finished_at_usec: int = Time.get_ticks_usec()
	var started_at_usec: int = GFVariantData.get_option_int(
		_active_report,
		"started_at_ticks_usec",
		finished_at_usec
	)
	_trim_active_trace()
	_active_report["outcome"] = String(outcome)
	_active_report["reason"] = String(reason)
	_active_report["finished_at_ticks_usec"] = finished_at_usec
	_active_report["duration_msec"] = float(maxi(finished_at_usec - started_at_usec, 0)) / 1000.0
	_active_report["trace_entry_count"] = _trace_entry_count
	_active_report["retained_trace_entry_count"] = _active_trace.size()
	_active_report["dropped_trace_entry_count"] = _dropped_trace_entry_count
	_active_report["trace_truncated"] = _dropped_trace_entry_count > 0
	_active_report["trace"] = _active_trace.duplicate(true)
	_last_run_report = _active_report.duplicate(true)
	var report: Dictionary = _last_run_report.duplicate(true)
	_active_report.clear()
	_active_trace.clear()
	return report


func _store_rejected_report(reason: StringName) -> Dictionary:
	var report: Dictionary = _make_rejected_report(reason)
	_last_run_report = report.duplicate(true)
	return report


func _make_rejected_report(reason: StringName) -> Dictionary:
	var now_usec: int = Time.get_ticks_usec()
	return {
		"schema_version": 1,
		"run_id": _next_run_id(),
		"outcome": String(OUTCOME_REJECTED),
		"reason": String(reason),
		"started_at_ticks_usec": now_usec,
		"finished_at_ticks_usec": now_usec,
		"duration_msec": 0.0,
		"executed_node_count": 0,
		"completed_node_count": 0,
		"missing_node_count": 0,
		"pending_node_count": 0,
		"signal_wait_count": 0,
		"timed_out_signal_wait_count": 0,
		"cancelled_signal_wait_count": 0,
		"invalid_signal_wait_count": 0,
		"trace_entry_count": 0,
		"retained_trace_entry_count": 0,
		"dropped_trace_entry_count": 0,
		"trace_truncated": false,
		"trace": [],
	}


func _make_trace_entry(
	node_id: StringName,
	status: StringName,
	started_at_usec: int,
	finished_at_usec: int,
	wait_status: StringName,
	reason: StringName
) -> Dictionary:
	return {
		"sequence": _trace_entry_count + 1,
		"node_id": String(node_id),
		"status": String(status),
		"reason": String(reason),
		"wait_status": String(wait_status),
		"started_at_ticks_usec": started_at_usec,
		"finished_at_ticks_usec": finished_at_usec,
		"duration_msec": float(maxi(finished_at_usec - started_at_usec, 0)) / 1000.0,
	}


func _append_trace_entry(entry: Dictionary) -> void:
	_trace_entry_count += 1
	_active_trace.append(entry)
	_trim_active_trace()


func _trim_active_trace() -> void:
	var limit: int = maxi(max_report_trace_entries, 0)
	while _active_trace.size() > limit:
		_active_trace.pop_front()
		_dropped_trace_entry_count += 1


func _increment_active_report_count(key: String) -> void:
	_active_report[key] = GFVariantData.get_option_int(_active_report, key) + 1


func _record_signal_wait_status(wait_status: StringName) -> void:
	match wait_status:
		_GF_ASYNC_WAIT_SUPPORT.STATUS_TIMEOUT:
			_increment_active_report_count("timed_out_signal_wait_count")
		_GF_ASYNC_WAIT_SUPPORT.STATUS_CANCELLED:
			_increment_active_report_count("cancelled_signal_wait_count")
		_GF_ASYNC_WAIT_SUPPORT.STATUS_INVALID:
			_increment_active_report_count("invalid_signal_wait_count")


func _next_run_id() -> int:
	_run_serial += 1
	return _run_serial


func _append_unique_packed_string(target: PackedStringArray, value: String) -> void:
	if value.is_empty() or target.has(value):
		return
	var appended: bool = target.append(value)
	if appended:
		return


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	if value.is_empty():
		return
	var appended: bool = target.append(value)
	if appended:
		return
