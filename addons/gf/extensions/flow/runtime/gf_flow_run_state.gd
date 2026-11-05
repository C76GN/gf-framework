## GFFlowRunState: 一轮 Flow 的调度和节点进度。不同 Runner 各自持有独立状态，即使它们共用业务 Context。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFFlowRunState
extends RefCounted


# --- 常量 ---

## 共享 Signal 等待状态码，用于分类本轮的等待结果。
## [br]
## @api private
const _GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")


# --- 私有变量 ---

## 当前运行的调用栈，末尾为正在执行的图。
## [br]
## @api private
var _frames: Array[_CallFrame] = []

## 逻辑运行自己的根节点状态，用于结束后读取此次进度。
## [br]
## @api private
var _root_nodes: Dictionary = {}

## 单调递增的帧序号，区分重复进入同一张图。
## [br]
## @api private
var _frame_serial: int = 0

## 所有活动帧尚未消费的节点数。
## [br]
## @api private
var _pending_count: int = 0

## 当前节点执行的独立身份；终止时由 Runner 撤销。
## [br]
## @api private
var _execution: GFFlowNodeExecution = null

## 运行自己的当前/终态报告，供持有旧状态的监听器独立查询。
## [br]
## @api private
var _report: Dictionary = {}

## 同一节点多次执行的轨迹属于不同执行序号。
## [br]
## @api private
var _execution_serial: int = 0

## 标记当前节点是否已签发句柄，缺失节点和租约冲突的轨迹没有执行序号。
## [br]
## @api private
var _issued_execution_id: int = 0

## 本轮尚未结束。终态回调开始前一定设为 false。
## [br]
## @api private
var _running: bool = false

## 只取消这一轮调度，旧 RunState 的请求不影响另一次运行。
## [br]
## @api private
var _cancel_requested: bool = false

## 保护条件中止当前运行的原因。
## [br]
## @api private
var _abort_reason: StringName = &""

## 每轮只保留最后这部分轨迹。
## [br]
## @api private
var _trace_limit: int = 128

## 按发生次序保留的轨迹。
## [br]
## @api private
var _trace: Array[Dictionary] = []

## 轨迹总数，包含已经裁剪的记录。
## [br]
## @api private
var _trace_count: int = 0


# --- 公共方法 ---

## 读取根图的节点进度副本。可将 nodes 显式传给另一次运行作为初始进度。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 根图数据，不包含等待、调用帧或运行位置。
## [br]
## @schema return: nodes 按节点 ID 保存进度字典。
func create_data_snapshot() -> Dictionary:
	return { "nodes": _root_nodes.duplicate(true) }


## 列出当前调用帧与各自的待执行节点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 按根至子图的顺序返回帧报告。
## [br]
## @schema return: 每项含 frame_id 和 pending 节点 ID 列表。
func describe_frames() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for frame: _CallFrame in _frames:
		result.append({ "frame_id": frame._id, "pending": frame._queue.slice(frame._cursor), })
	return result


## 读取此轮运行的进展或终态。Runner 被重用后，旧状态仍返回自己的报告。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前运行报告副本。
## [br]
## @schema return: 与 Runner 报告相同，waiting_node_id 记录活动等待的节点。
func get_report() -> Dictionary:
	var result: Dictionary = _report.duplicate(true)
	if result.is_empty():
		return result
	result["trace"] = _trace.duplicate(true)
	result["trace_entry_count"] = _trace_count
	result["retained_trace_entry_count"] = _trace.size()
	result["dropped_trace_entry_count"] = _trace_count - _trace.size()
	result["trace_truncated"] = _trace_count > _trace.size()
	return result


## 只对这一次运行请求取消，立即封闭在途节点写权限。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 首次接纳取消时返回 true；结束后或已取消时返回 false。
func cancel() -> bool:
	if not _running or _cancel_requested:
		return false
	_cancel_requested = true
	close_execution()
	return true


# --- 框架内部方法 ---

## 校验并复制新运行的初始节点进度。只允许新实例启动一次。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param graph: 根图。
## [br]
## @param initial_nodes: 本轮初始节点进度。
## [br]
## @return: 数据验证并开帧成功时返回 true。
## [br]
## @schema initial_nodes: 非空节点 ID 到 Dictionary 的映射。
func start(graph: GFFlowGraph, initial_nodes: Dictionary) -> bool:
	if graph == null or _frame_serial != 0:
		return false
	# 两层调度表都要接受新的字段类型；项目提供的字段值继续按原 Variant 类型复制。
	var normalized_nodes: Dictionary = {}
	for key: Variant in initial_nodes:
		if not key is String and not key is StringName:
			return false
		if GFVariantData.to_string_name(key) == &"":
			return false
		var raw_fields: Variant = initial_nodes[key]
		if not raw_fields is Dictionary:
			return false
		var source_fields: Dictionary = raw_fields
		var fields: Dictionary = {}
		fields.merge(source_fields.duplicate(true))
		normalized_nodes[key] = fields
	_root_nodes = normalized_nodes
	_frame_serial = 1
	_frames.append(
		_CallFrame.new(
			graph,
			_frame_serial,
			_root_nodes
		)
	)
	_pending_count = 1
	return true


## 返回上一层调用的队列，直至找到有待执行节点的帧。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: 仍有待执行节点时返回 true。
func advance_frame() -> bool:
	while not _frames.is_empty():
		var frame: _CallFrame = _frames[-1]
		if frame._cursor < frame._queue.size():
			return true
		_frames.remove_at(_frames.size() - 1)
	return false


## 读取当前活动图。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: advance_frame 成功后的活动图。
func current_graph() -> GFFlowGraph:
	return _frames[-1]._graph


## 取出本帧下一个节点并推进帧游标。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: 队列中下一个节点标识。
func take_next_node() -> StringName:
	var frame: _CallFrame = _frames[-1]
	var node_id: StringName = StringName(frame._queue[frame._cursor])
	_issued_execution_id = 0
	frame._cursor += 1
	_pending_count -= 1
	_report["pending_node_count"] = _pending_count
	return node_id


## 为此帧的当前节点签发独立执行句柄。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param node_id: 当前帧的节点 ID。
## [br]
## @return: 只属于此节点这次执行的句柄。
func begin_execution(node_id: StringName) -> GFFlowNodeExecution:
	var frame: _CallFrame = _frames[-1]
	if not frame._nodes.has(node_id):
		frame._nodes[node_id] = {}
	var state: Dictionary = frame._nodes[node_id]
	_execution_serial += 1
	_issued_execution_id = _execution_serial
	_execution = GFFlowNodeExecution.new(state)
	return _execution


## 撤销当前执行，迟到的回调即使同 ID 再次执行也不能修改状态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
func close_execution() -> void:
	if _execution != null:
		_execution.close()
		_execution = null


## 先将后继保存到父队列，再压入新子图帧。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param next_ids: 当前节点在本帧中的后继。
## [br]
## @param child: 要先进入的子图，无子调用时为 null。
func schedule(next_ids: PackedStringArray, child: GFFlowGraph) -> void:
	var frame: _CallFrame = _frames[-1]
	frame._queue.append_array(next_ids)
	_pending_count += next_ids.size()
	if child != null:
		_frame_serial += 1
		_frames.append(
			_CallFrame.new(
				child,
				_frame_serial,
				{}
			)
		)
		_pending_count += 1
	_report["pending_node_count"] = _pending_count


## 创建运行和拒绝报告的共同结构。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param run_id: 此 Runner 分配的运行序号。
## [br]
## @param outcome: 当前或拒绝结果。
## [br]
## @param reason: 结果原因。
## [br]
## @return: 新的运行报告。
## [br]
## @schema return: 与 run() 返回的诊断字段一致。
static func make_report(
	run_id: int,
	outcome: StringName,
	reason: StringName
) -> Dictionary:
	var now: int = Time.get_ticks_usec()
	return {
		"schema_version": 1,
		"run_id": run_id,
		"outcome": String(outcome),
		"reason": String(reason),
		"started_at_ticks_usec": now,
		"finished_at_ticks_usec": now if outcome == &"rejected" else 0,
		"duration_msec": 0.0,
		"executed_node_count": 0,
		"completed_node_count": 0,
		"missing_node_count": 0,
		"pending_node_count": 0,
		"signal_wait_count": 0,
		"timed_out_signal_wait_count": 0,
		"cancelled_signal_wait_count": 0,
		"invalid_signal_wait_count": 0,
		"waiting_node_id": "",
		"trace_entry_count": 0,
		"retained_trace_entry_count": 0,
		"dropped_trace_entry_count": 0,
		"trace_truncated": false,
		"trace": [],
	}


## 在发出 flow_started 之前建好此轮报告。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param run_id: 此 Runner 的递增运行序号。
## [br]
## @param trace_limit: 本轮保留的轨迹条数。
func begin_report(run_id: int, trace_limit: int) -> void:
	_report = make_report(
		run_id,
		&"running",
		&""
	)
	_report["pending_node_count"] = _pending_count
	_trace_limit = trace_limit
	_running = true


## 调度和等待只检查其所属的运行实例。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: 本轮尚可继续时返回 true。
func should_continue() -> bool:
	return (
		_running
		and not _cancel_requested
		and _abort_reason == &""
	)


## 记录本轮中止并撤回现有节点写入资格。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param reason: 中止原因。
func abort(reason: StringName) -> void:
	_abort_reason = reason
	close_execution()


## 累加报告的单个计数。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param key: 本轮报告的计数字段。
func increment(key: StringName) -> void:
	_report[key] = GFVariantData.get_option_int(_report, key) + 1


## 登记当前等待的节点。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param node_id: 当前等待 Signal 的节点。
func begin_wait(node_id: StringName) -> void:
	_report["waiting_node_id"] = String(node_id)
	increment(&"signal_wait_count")


## 结束本轮等待并统计结果。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param status: Signal 等待结果。
func end_wait(status: StringName) -> void:
	_report["waiting_node_id"] = ""
	match status:
		_GF_ASYNC_WAIT_SUPPORT.STATUS_TIMEOUT:
			increment(&"timed_out_signal_wait_count")
		_GF_ASYNC_WAIT_SUPPORT.STATUS_CANCELLED:
			increment(&"cancelled_signal_wait_count")
		_GF_ASYNC_WAIT_SUPPORT.STATUS_INVALID:
			increment(&"invalid_signal_wait_count")


## 修改当前运行的轨迹上限，完成后的历史报告保持其既有容量。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param limit: 新的保留条数。
func set_trace_limit(limit: int) -> void:
	if _running:
		_trace_limit = maxi(limit, 0)
		_trim_trace()


## 将节点结果记录在所属运行和子图帧。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param node_id: 当前节点。
## [br]
## @param status: 节点结果。
## [br]
## @param started_at_usec: 节点开始时间。
## [br]
## @param wait_status: 此节点的等待结果。
## [br]
## @param reason: 失败或取消原因。
func record_node(
	node_id: StringName,
	status: StringName,
	started_at_usec: int,
	wait_status: StringName,
	reason: StringName
) -> void:
	var finished: int = Time.get_ticks_usec()
	_trace_count += 1
	_trace.append(
		{
			"sequence": _trace_count,
			"node_id": String(node_id),
			"frame_id": _frames[-1]._id,
			"execution_id": _issued_execution_id,
			"status": String(status),
			"reason": String(reason),
			"wait_status": String(wait_status),
			"started_at_ticks_usec": started_at_usec,
			"finished_at_ticks_usec": finished,
			"duration_msec": float(
				maxi(
					finished - started_at_usec,
					0
				)
			) / 1000.0,
		}
	)
	_trim_trace()


## 封闭本轮状态，保存终态报告并释放图和等待引用。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: 本轮终态报告副本。
## [br]
## @schema return: 与 Runner.run() 返回结构一致。
func finish() -> Dictionary:
	close_execution()
	_running = false
	var finished: int = Time.get_ticks_usec()
	var started: int = GFVariantData.get_option_int(
		_report,
		"started_at_ticks_usec",
		finished
	)
	_report["finished_at_ticks_usec"] = finished
	_report["duration_msec"] = float(
		maxi(
			finished - started,
			0
		)
	) / 1000.0
	_report["waiting_node_id"] = ""
	_report["pending_node_count"] = _pending_count
	if _abort_reason != &"":
		_report["outcome"] = "aborted"
		_report["reason"] = String(_abort_reason)
	elif _cancel_requested:
		_report["outcome"] = "cancelled"
		_report["reason"] = "cancel_requested"
	else:
		_report["outcome"] = "completed"
	_frames.clear()
	_pending_count = 0
	return get_report()


# --- 私有/辅助方法 ---

## 只裁剪超过容量的最旧轨迹，总数另外保留。
## [br]
## @api private
func _trim_trace() -> void:
	while _trace.size() > _trace_limit:
		_trace.remove_at(0)


# --- 内部类 ---

## 子图单次调用的队列和节点状态；同名节点只在本帧中共享进度。
## [br]
## @api private
class _CallFrame extends RefCounted:


	# --- 私有变量 ---

	## 本帧执行的图。
	## [br]
	## @api private
	var _graph: GFFlowGraph

	## 调用栈中的运行内序号。
	## [br]
	## @api private
	var _id: int

	## 尚未遍历完的节点队列。
	## [br]
	## @api private
	var _queue: PackedStringArray

	## 下次出队位置。
	## [br]
	## @api private
	var _cursor: int = 0

	## 按本帧内的节点 ID 保存进度。
	## [br]
	## @api private
	var _nodes: Dictionary


	# --- Godot 生命周期方法 ---

	func _init(
		source_graph: GFFlowGraph,
		frame_id: int,
		initial_nodes: Dictionary
	) -> void:
		_graph = source_graph
		_id = frame_id
		_nodes = initial_nodes
		_queue = PackedStringArray([String(_graph.start_node_id)])
