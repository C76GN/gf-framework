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
## @param graph: 流程图资源。
signal flow_started(graph: GFFlowGraph)

## 节点开始执行时发出。
## [br]
## @api public
## [br]
## @param node_id: 节点 ID。
## [br]
## @param node: 节点资源。
signal node_started(node_id: StringName, node: GFFlowNode)

## 节点完成执行时发出。
## [br]
## @api public
## [br]
## @param node_id: 节点 ID。
## [br]
## @param node: 节点资源。
signal node_completed(node_id: StringName, node: GFFlowNode)

## 流程完成时发出。
## [br]
## @api public
signal flow_completed

## 流程取消时发出。
## [br]
## @api public
signal flow_cancelled


# --- 常量 ---

const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")


# --- 公共变量 ---

## 当前是否正在执行。
## [br]
## @api public
var is_running: bool = false

## 最多执行节点数量，避免循环图无限运行。小于等于 0 表示不限制。
## [br]
## @api public
var max_executed_nodes: int = 1024

## Signal 等待超时时间。小于等于 0 表示不启用超时。
## [br]
## @api public
var signal_timeout_seconds: float = 30.0

## Signal 超时计时是否跟随 GFTimeUtility 的暂停与 time_scale。
## [br]
## @api public
var signal_timeout_respects_time_scale: bool = true

## 运行时是否把节点 runtime_state 隔离到 GFFlowContext，避免污染共享图资源。
## [br]
## @api public
var isolate_graph_runtime_state: bool = true


# --- 私有变量 ---

var _cancel_requested: bool = false
var _abort_reason: StringName = &""
var _architecture_ref: WeakRef = null


# --- 公共方法 ---

## 注入架构。通常由 GFArchitecture 创建或注册时自动调用。
## [br]
## @api framework_internal
## [br]
## @param architecture: 架构实例。
func inject_dependencies(architecture: GFArchitecture) -> void:
	_architecture_ref = weakref(architecture) if architecture != null else null


## 运行流程图。
## [br]
## @api public
## [br]
## @param graph: 流程图资源。
## [br]
## @param context: 可选上下文。
func run(graph: GFFlowGraph, context: GFFlowContext = null) -> void:
	if graph == null:
		push_error("[GFFlowRunner] run 失败：graph 为空。")
		return
	if is_running:
		push_warning("[GFFlowRunner] 流程正在执行，忽略重复 run()。")
		return

	var flow_context: GFFlowContext = context if context != null else GFFlowContext.new(_get_architecture_or_null())
	if flow_context.get_architecture() == null:
		flow_context.set_architecture(_get_architecture_or_null())

	is_running = true
	_cancel_requested = false
	_abort_reason = &""
	flow_started.emit(graph)
	await _run_graph(graph, flow_context)
	is_running = false
	if _cancel_requested or _abort_reason != &"":
		flow_cancelled.emit()
	else:
		flow_completed.emit()


## 请求取消流程。
## [br]
## @api public
func cancel() -> void:
	_cancel_requested = true


## 设置 Signal 等待超时时间。
## [br]
## @api public
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


# --- 私有/辅助方法 ---

func _run_graph(graph: GFFlowGraph, context: GFFlowContext) -> void:
	var pending: PackedStringArray = PackedStringArray([String(graph.start_node_id)])
	var pending_index: int = 0
	var executed_count: int = 0
	while pending_index < pending.size() and not _cancel_requested:
		if max_executed_nodes > 0 and executed_count >= max_executed_nodes:
			_abort_reason = &"max_executed_nodes"
			push_warning("[GFFlowRunner] 达到最大节点执行数量，流程停止。")
			break

		var node_id: StringName = StringName(pending[pending_index])
		pending_index += 1
		if node_id == &"":
			continue

		var node: GFFlowNode = graph.get_node(node_id)
		if node == null:
			push_warning("[GFFlowRunner] 缺少流程节点：%s" % String(node_id))
			continue

		executed_count += 1
		context.clear_next_nodes()
		node_started.emit(node_id, node)
		var result: Variant = _execute_node_with_runtime_state(node, context)
		if node.wait_for_result and result is Signal:
			var result_signal: Signal = result
			await _await_signal_safely(result_signal)
			if _cancel_requested:
				return
		node_completed.emit(node_id, node)

		var next_ids: PackedStringArray = _get_runtime_successor_node_ids(graph, node, context)
		for next_id: String in next_ids:
			_append_packed_string(pending, next_id)


func _await_signal_safely(result_signal: Signal) -> void:
	await _GF_ASYNC_WAIT_SUPPORT.await_signal_safely(
		result_signal,
		_should_continue_waiting,
		_get_time_utility(),
		signal_timeout_seconds,
		signal_timeout_respects_time_scale,
		"[GFFlowRunner] 等待 Signal 超时，流程将继续执行后续节点。"
	)


func _execute_node_with_runtime_state(node: GFFlowNode, context: GFFlowContext) -> Variant:
	if not isolate_graph_runtime_state:
		return node.execute(context)

	var original_state: Dictionary = node.serialize_runtime_state()
	_apply_context_runtime_state_to_node(node, context)
	var result: Variant = node.execute(context)
	_store_node_runtime_state_in_context(node, context)
	node.clear_runtime_state()
	node.deserialize_runtime_state(original_state)
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
	for next_id: String in graph.get_connected_node_ids_from(node.node_id):
		_append_unique_packed_string(result, next_id)
	return result


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
