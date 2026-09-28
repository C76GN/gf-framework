## GFBehaviorTree: 轻量级、纯代码的行为树实现。
##
## 提供无需编辑器的、以代码方式构建 AI 或通用决策逻辑的轻量方案。
## 可以在任何 System 中通过 Runner 来驱动 tick()。核心节点包含
## Sequence、Selector、Parallel、Action、Condition 以及常用装饰节点。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFBehaviorTree


# --- 枚举 ---

## 行为树节点的执行状态。
## [br]
## @api public
enum Status {
	## 节点尚未被 tick。
	FRESH = -1,
	## 节点本次执行成功。
	SUCCESS = 0,
	## 节点本次执行失败。
	FAILURE = 1,
	## 节点仍在运行，需要后续 tick 继续推进。
	RUNNING = 2,
	## 节点被外部中止。
	ABORTED = 3,
}

## Parallel 节点的完成策略。
## [br]
## @api public
enum ParallelPolicy {
	## 所有子节点成功才成功，任意子节点失败即失败。
	REQUIRE_ALL,
	## 任意子节点成功即成功，所有子节点失败才失败。
	REQUIRE_ONE,
}


# --- 常量 ---

## 秒数转换为毫秒时可表示的最大整数值。
## [br]
## @api private
const _MAX_DURATION_MSEC: int = 9_223_372_036_854_775_807

## 超过该秒数时毫秒转换饱和到最大整数值。
## [br]
## @api private
const _MAX_DURATION_SECONDS: float = 9_223_372_036_854_775.0

## 调试快照各预算选项的默认节点数量上限。
## [br]
## @api private
const _DEFAULT_DEBUG_MAX_NODES: int = 256

## 调试快照各预算选项的默认递归深度上限。
## [br]
## @api private
const _DEFAULT_DEBUG_MAX_DEPTH: int = 16

## 调试快照各预算选项的默认子节点数量上限。
## [br]
## @api private
const _DEFAULT_DEBUG_MAX_CHILDREN: int = 64

## 调试快照各预算选项的默认序列化字节上限。
## [br]
## @api private
const _DEFAULT_DEBUG_MAX_TOTAL_BYTES: int = 256 * 1024

## 调试快照各预算选项的默认文本长度上限。
## [br]
## @api private
const _DEFAULT_DEBUG_MAX_TEXT_LENGTH: int = 512

## Runner 调试快照的默认黑板键样本数量上限。
## [br]
## @api private
const _DEFAULT_DEBUG_MAX_BLACKBOARD_KEYS: int = 128

## 调试快照允许配置的节点数量硬上限。
## [br]
## @api private
const _HARD_DEBUG_MAX_NODES: int = 4096

## 调试快照允许配置的递归深度硬上限。
## [br]
## @api private
const _HARD_DEBUG_MAX_DEPTH: int = 64

## 调试快照允许配置的子节点数量硬上限。
## [br]
## @api private
const _HARD_DEBUG_MAX_CHILDREN: int = 256

## 调试快照允许配置的序列化字节硬上限。
## [br]
## @api private
const _HARD_DEBUG_MAX_TOTAL_BYTES: int = 1024 * 1024

## 调试快照允许配置的文本长度硬上限。
## [br]
## @api private
const _HARD_DEBUG_MAX_TEXT_LENGTH: int = 4096

## Runner 调试快照允许配置的黑板键样本硬上限。
## [br]
## @api private
const _HARD_DEBUG_MAX_BLACKBOARD_KEYS: int = 1024

## 调试报告编码器允许遍历的最大集合项数。
## [br]
## @api private
const _DEBUG_CODEC_MAX_COLLECTION_ITEMS: int = 1024

## 调试报告编码器集合节点预算的乘数。
## [br]
## @api private
const _DEBUG_CODEC_NODE_MULTIPLIER: int = 32

## 调试报告编码器集合节点预算的固定余量。
## [br]
## @api private
const _DEBUG_CODEC_NODE_OVERHEAD: int = 512


# --- 公共方法 ---

## 将状态枚举转换为稳定文本。
## [br]
## @api public
## [br]
## @param status: 行为树状态。
## [br]
## @return: 状态文本。
static func status_to_string(status: int) -> StringName:
	match status:
		Status.FRESH:
			return &"fresh"
		Status.SUCCESS:
			return &"success"
		Status.FAILURE:
			return &"failure"
		Status.RUNNING:
			return &"running"
		Status.ABORTED:
			return &"aborted"
		_:
			return &"unknown"


## 获取节点调试快照。
##
## 内建 BTNode 返回其已持有的子节点集合后，GF 会在递归前执行节点、深度和子项
## 预算；项目自定义的 _get_debug_children() 必须自行保证构造有界，GF 无法中断
## override 内部工作。Runner 会在黑板键物化前限流。通用 Object 则必须先由对象
## 自身完成 get_debug_snapshot()，GF 只能对其返回值执行有界后投影。
## [br]
## @api public
## [br]
## @since 3.3.0
## [br]
## @param node: 行为树节点。
## [br]
## @param options: 有界快照选项。
## [br]
## @return: 调试快照字典。
## [br]
## @schema node: GFBehaviorTree.BTNode、GFBehaviorTree.Runner、null 或提供 get_debug_snapshot() 的对象；内建 BTNode 在取得已有子节点集合后限制递归，Runner 在黑板键物化前限流；自定义 _get_debug_children() 与通用对象方法的内部工作不受 GF 抢占，仅其返回后的遍历或投影有界。
## [br]
## @schema options: Dictionary with optional max_nodes, max_depth, max_children, max_total_bytes, max_text_length, and max_blackboard_keys; values are clamped to framework hard limits.
## [br]
## @schema return: 包含节点调试状态和 debug_budget 的 Dictionary；null 节点返回空字典。
static func build_debug_snapshot(node: Variant, options: Dictionary = {}) -> Dictionary:
	if node is BTNode:
		var tree_node: BTNode = node
		var node_budget: Dictionary = _make_debug_snapshot_budget(options)
		var node_snapshot: Dictionary = tree_node._get_debug_snapshot_internal(
			{},
			{},
			node_budget,
			0
		)
		return _finalize_debug_snapshot(node_snapshot, node_budget)
	if node is Runner:
		var runner: Runner = node
		var runner_budget: Dictionary = _make_debug_snapshot_budget(options)
		var runner_snapshot: Dictionary = runner._get_debug_snapshot_raw(runner_budget)
		return _finalize_debug_snapshot(runner_snapshot, runner_budget)
	if node is Object:
		var snapshot_owner: Object = node
		var object_budget: Dictionary = _make_debug_snapshot_budget(options)
		var object_snapshot: Dictionary = _call_debug_snapshot(snapshot_owner)
		return _finalize_debug_snapshot(object_snapshot, object_budget)
	return {}


# --- 私有/辅助方法 ---

## 调用通用对象的 get_debug_snapshot() 并将结果收窄为字典。
## [br]
## @api private
static func _call_debug_snapshot(snapshot_owner: Object) -> Dictionary:
	if snapshot_owner == null or not snapshot_owner.has_method("get_debug_snapshot"):
		return {}

	var snapshot_value: Variant = snapshot_owner.call("get_debug_snapshot")
	return GFVariantData.as_dictionary(snapshot_value)


## 按默认值和硬上限建立调试快照预算及截断状态。
## [br]
## @api private
static func _make_debug_snapshot_budget(options: Dictionary) -> Dictionary:
	return {
		"max_nodes": _get_bounded_debug_option(options, "max_nodes", _DEFAULT_DEBUG_MAX_NODES, _HARD_DEBUG_MAX_NODES),
		"max_depth": _get_bounded_debug_option(options, "max_depth", _DEFAULT_DEBUG_MAX_DEPTH, _HARD_DEBUG_MAX_DEPTH),
		"max_children": _get_bounded_debug_option(options, "max_children", _DEFAULT_DEBUG_MAX_CHILDREN, _HARD_DEBUG_MAX_CHILDREN),
		"max_total_bytes": _get_bounded_debug_option(options, "max_total_bytes", _DEFAULT_DEBUG_MAX_TOTAL_BYTES, _HARD_DEBUG_MAX_TOTAL_BYTES),
		"max_text_length": _get_bounded_debug_option(options, "max_text_length", _DEFAULT_DEBUG_MAX_TEXT_LENGTH, _HARD_DEBUG_MAX_TEXT_LENGTH),
		"max_blackboard_keys": _get_bounded_debug_option(options, "max_blackboard_keys", _DEFAULT_DEBUG_MAX_BLACKBOARD_KEYS, _HARD_DEBUG_MAX_BLACKBOARD_KEYS),
		"node_count": 0,
		"truncated": false,
		"truncation_reasons": {},
	}


## 读取整数预算选项并限制在零至指定硬上限之间。
## [br]
## @api private
static func _get_bounded_debug_option(
	options: Dictionary,
	key: String,
	fallback: int,
	hard_maximum: int
) -> int:
	var value: Variant = options.get(key, fallback)
	if not value is int:
		return fallback
	var int_value: int = value
	return clampi(int_value, 0, hard_maximum)


## 标记快照已截断，并将原因加入预算字典。
## [br]
## @api private
static func _mark_debug_snapshot_truncated(budget: Dictionary, reason: StringName) -> void:
	budget["truncated"] = true
	var reasons_value: Variant = budget.get("truncation_reasons", {})
	var reasons: Dictionary = {}
	if reasons_value is Dictionary:
		reasons = reasons_value
	reasons[reason] = true
	budget["truncation_reasons"] = reasons


## 判断已计数节点是否仍低于快照预算上限。
## [br]
## @api private
static func _has_debug_node_capacity(budget: Dictionary) -> bool:
	return (
		_read_debug_budget_int(budget, "node_count")
		< _read_debug_budget_int(budget, "max_nodes", _DEFAULT_DEBUG_MAX_NODES)
	)


## 消耗一个节点预算；无容量时记录 max_nodes 截断原因。
## [br]
## @api private
static func _consume_debug_node(budget: Dictionary) -> bool:
	if not _has_debug_node_capacity(budget):
		_mark_debug_snapshot_truncated(budget, &"max_nodes")
		return false
	budget["node_count"] = _read_debug_budget_int(budget, "node_count") + 1
	return true


## 复制预算报告并将截断原因转换为排序后的文本数组。
## [br]
## @api private
static func _make_debug_budget_report(budget: Dictionary) -> Dictionary:
	var reasons: Array[String] = []
	var reasons_value: Variant = budget.get("truncation_reasons", {})
	if reasons_value is Dictionary:
		var reason_lookup: Dictionary = reasons_value
		for reason_value: Variant in reason_lookup.keys():
			reasons.append(GFVariantData.to_text(reason_value))
	reasons.sort()
	var report: Dictionary = budget.duplicate(true)
	report["truncation_reasons"] = reasons
	return report


## 预留预算字段字节后编码快照，超限时退回仅含预算报告的结果。
## [br]
## @api private
static func _finalize_debug_snapshot(snapshot: Dictionary, budget: Dictionary) -> Dictionary:
	var debug_budget_report: Dictionary = _make_debug_budget_report(budget)
	var debug_budget_field: Dictionary = {
		"debug_budget": debug_budget_report,
	}
	var reserved_debug_bytes: int = JSON.stringify(
		debug_budget_field
	).to_utf8_buffer().size()
	var isolation_budget: Dictionary = budget.duplicate(true)
	isolation_budget["max_total_bytes"] = maxi(
		_read_debug_budget_int(
			budget,
			"max_total_bytes",
			_DEFAULT_DEBUG_MAX_TOTAL_BYTES
		) - reserved_debug_bytes,
		0
	)
	var bounded_snapshot: Dictionary = _encode_debug_snapshot_with_budget(
		snapshot,
		isolation_budget
	)
	var finalized_snapshot: Dictionary = bounded_snapshot.duplicate(false)
	finalized_snapshot["debug_budget"] = debug_budget_report
	var max_total_bytes: int = _read_debug_budget_int(
		budget,
		"max_total_bytes",
		_DEFAULT_DEBUG_MAX_TOTAL_BYTES
	)
	if JSON.stringify(finalized_snapshot).to_utf8_buffer().size() <= max_total_bytes:
		return finalized_snapshot
	return _encode_debug_snapshot_with_budget(debug_budget_field, budget)


## 读取整数预算字段；缺失或类型不符时返回回退值。
## [br]
## @api private
static func _read_debug_budget_int(
	budget: Dictionary,
	key: String,
	fallback: int = 0
) -> int:
	var value: Variant = budget.get(key, fallback)
	if value is int:
		var int_value: int = value
		return int_value
	return fallback


## 将有效的整数 tick 状态保留，否则返回指定回退状态。
## [br]
## @api private
static func _variant_to_status(value: Variant, fallback_status: int = Status.FAILURE) -> int:
	if value is int:
		var status: int = value
		if _is_valid_tick_status(status):
			return status
	return fallback_status


## 判断状态是否属于 SUCCESS、FAILURE、RUNNING 或 ABORTED。
## [br]
## @api private
static func _is_valid_tick_status(status: int) -> bool:
	return (
		status == Status.SUCCESS
		or status == Status.FAILURE
		or status == Status.RUNNING
		or status == Status.ABORTED
	)


## 判断状态是否为 SUCCESS。
## [br]
## @api private
static func _is_success(status: int) -> bool:
	return status == Status.SUCCESS


## 判断状态是否为 FAILURE。
## [br]
## @api private
static func _is_failure(status: int) -> bool:
	return status == Status.FAILURE


## 判断状态是否为 RUNNING。
## [br]
## @api private
static func _is_running(status: int) -> bool:
	return status == Status.RUNNING


## 判断状态是否为 ABORTED。
## [br]
## @api private
static func _is_aborted(status: int) -> bool:
	return status == Status.ABORTED


## 由原始返回值和规范化状态确定无效或中止原因。
## [br]
## @api private
static func _status_reason_from_value(value: Variant, normalized_status: int) -> StringName:
	if not value is int:
		return &"invalid_status"
	if value is int:
		var status: int = value
		if not _is_valid_tick_status(status):
			return &"invalid_status"
	if normalized_status == Status.ABORTED:
		return &"aborted"
	return &""


## 将条件结果收窄为 bool；其他类型按 false 处理。
## [br]
## @api private
static func _condition_result_to_bool(value: Variant) -> bool:
	if value is bool:
		return value
	return false


## 为非布尔条件结果返回 invalid_condition_result 原因。
## [br]
## @api private
static func _condition_reason_from_value(value: Variant) -> StringName:
	if value is bool:
		return &""
	return &"invalid_condition_result"


## 判断原因是否属于状态、条件或运行时副本协议错误。
## [br]
## @api private
static func _is_error_reason(reason: StringName) -> bool:
	return (
		reason == &"invalid_status"
		or reason == &"invalid_condition"
		or reason == &"invalid_condition_result"
		or reason == &"runtime_duplicate_missing_override"
		or reason == &"missing_tick_override"
	)


## 判断子节点原因是否为中止或需向上传播的错误。
## [br]
## @api private
static func _should_propagate_child_reason(reason: StringName) -> bool:
	return reason == &"aborted" or _is_error_reason(reason)


## 优先返回显式随机源，否则读取黑板中的 rng 对象。
## [br]
## @api private
static func _resolve_rng_from_blackboard(
	blackboard: Dictionary,
	fallback_rng: RandomNumberGenerator = null
) -> RandomNumberGenerator:
	if fallback_rng != null:
		return fallback_rng

	var blackboard_rng: Variant = GFVariantData.get_option_value(blackboard, "rng")
	if blackboard_rng is RandomNumberGenerator:
		return blackboard_rng
	return null


## 创建并复制随机源的 seed 与 state。
## [br]
## @api private
static func _duplicate_rng(source: RandomNumberGenerator) -> RandomNumberGenerator:
	if source == null:
		return null

	var copy: RandomNumberGenerator = RandomNumberGenerator.new()
	copy.seed = source.seed
	copy.state = source.state
	return copy


## 复制子节点顺序并使用选定随机源打乱副本。
## [br]
## @api private
static func _make_random_node_order(
	children: Array[BTNode],
	blackboard: Dictionary,
	fallback_rng: RandomNumberGenerator = null
) -> Array[BTNode]:
	var result: Array[BTNode] = []
	result.append_array(children)
	var active_rng: RandomNumberGenerator = _resolve_rng_from_blackboard(
		blackboard,
		fallback_rng
	)
	if active_rng == null:
		result.shuffle()
	else:
		_shuffle_nodes_with_rng(result, active_rng)
	return result


## 使用指定随机源执行节点数组的 Fisher-Yates 洗牌。
## [br]
## @api private
static func _shuffle_nodes_with_rng(
	nodes: Array[BTNode],
	random_source: RandomNumberGenerator
) -> void:
	for index: int in range(nodes.size() - 1, 0, -1):
		var swap_index: int = random_source.randi_range(0, index)
		var temp: BTNode = nodes[index]
		nodes[index] = nodes[swap_index]
		nodes[swap_index] = temp


## 通过 Variant 工具复制字典；结果类型不符时返回空字典。
## [br]
## @api private
static func _duplicate_dictionary(value: Dictionary) -> Dictionary:
	var duplicated_value: Variant = GFVariantData.duplicate_variant(value)
	if duplicated_value is Dictionary:
		var duplicated_dictionary: Dictionary = duplicated_value
		return duplicated_dictionary
	return {}


## 创建节点运行时副本并检查独立身份和动态类型。
## [br]
## @api private
static func _duplicate_runtime_node(source: BTNode) -> BTNode:
	if source == null:
		return null
	var copy: BTNode = source.duplicate_runtime()
	if copy != null and _runtime_duplicate_error_reason(copy) != &"":
		return copy
	if (
		copy != null
		and copy != source
		and _runtime_node_types_match(source, copy)
	):
		return copy

	push_error("[GFBehaviorTree][behavior_tree.invalid_runtime_duplicate] duplicate_runtime() must return an independent node preserving its dynamic script type; custom subclasses of concrete built-in nodes must also override it explicitly.")
	var failure: BTNode = BTNode.new()
	source._copy_base_fields_to(failure)
	failure._runtime_duplicate_error = &"runtime_duplicate_missing_override"
	failure.metadata["_gf_runtime_duplicate_error"] = &"runtime_duplicate_missing_override"
	return failure


## 比较脚本化节点的脚本身份，或原生节点的类名。
## [br]
## @api private
static func _runtime_node_types_match(source: BTNode, copy: BTNode) -> bool:
	var source_script: Variant = source.get_script()
	var copy_script: Variant = copy.get_script()
	if source_script != null or copy_script != null:
		return source_script == copy_script
	return source.get_class() == copy.get_class()


## 读取副本记录的运行时复制错误原因。
## [br]
## @api private
static func _runtime_duplicate_error_reason(node: BTNode) -> StringName:
	if node == null:
		return &""
	return node._runtime_duplicate_error


## 返回有限非负值；输入非法时使用安全回退值或零。
## [br]
## @api private
static func _sanitize_non_negative_seconds(value: float, fallback: float) -> float:
	var safe_fallback: float = fallback if is_finite(fallback) and fallback >= 0.0 else 0.0
	return value if is_finite(value) and value >= 0.0 else safe_fallback


## 将秒数转换为毫秒整数，并在上界处饱和。
## [br]
## @api private
static func _seconds_to_msec(seconds: float) -> int:
	if seconds >= _MAX_DURATION_SECONDS:
		return _MAX_DURATION_MSEC
	return roundi(seconds * 1000.0)


## 读取系统或注入时钟，并保证结果不早于上一观测值。
## [br]
## @api private
static func _resolve_monotonic_time_msec(clock_msec: Callable, previous_msec: int) -> int:
	var current_msec: int = Time.get_ticks_msec()
	if clock_msec.is_valid():
		var clock_value: Variant = clock_msec.call()
		if clock_value is int:
			var injected_msec: int = clock_value
			if injected_msec >= 0:
				current_msec = injected_msec
	return maxi(current_msec, previous_msec)


## 以调试脱敏规则和预算边界编码快照字典。
## [br]
## @api private
static func _encode_debug_snapshot_with_budget(
	snapshot: Dictionary,
	budget: Dictionary
) -> Dictionary:
	var traversal_max_depth: int = _read_debug_budget_int(
		budget,
		"max_depth",
		_DEFAULT_DEBUG_MAX_DEPTH
	)
	var traversal_max_nodes: int = _read_debug_budget_int(
		budget,
		"max_nodes",
		_DEFAULT_DEBUG_MAX_NODES
	)
	return GFReportValueCodec.to_report_dictionary(
		snapshot,
		GFReportValueCodec.make_redaction_options(
			GFReportValueCodec.REDACTION_PROFILE_DEBUG,
			{
				"path_redaction": "none",
				"max_depth": traversal_max_depth * 2 + 8,
				"max_string_length": _read_debug_budget_int(
					budget,
					"max_text_length",
					_DEFAULT_DEBUG_MAX_TEXT_LENGTH
				),
				"max_collection_items": _DEBUG_CODEC_MAX_COLLECTION_ITEMS,
				"max_packed_length": _DEBUG_CODEC_MAX_COLLECTION_ITEMS,
				"max_total_nodes": (
					traversal_max_nodes * _DEBUG_CODEC_NODE_MULTIPLIER
					+ _DEBUG_CODEC_NODE_OVERHEAD
				),
				"max_total_bytes": _read_debug_budget_int(
					budget,
					"max_total_bytes",
					_DEFAULT_DEBUG_MAX_TOTAL_BYTES
				),
			}
		)
	)


# --- 内部类 ---

## 行为树所有节点的基类。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class BTNode extends RefCounted:
	## 节点名称，用于调试。
	## [br]
	## @api public
	var name: String = "BTNode"

	## 可选稳定节点标识。
	## [br]
	## @api public
	var node_id: StringName = &""

	## 最近一次 tick 状态。
	## [br]
	## @api public
	var last_status: int = Status.FRESH

	## 最近一次状态原因。
	## [br]
	## @api public
	var last_reason: StringName = &""

	## 累计 tick 次数。
	## [br]
	## @api public
	var tick_count: int = 0

	## 最近一次 tick 耗时，单位微秒。
	## [br]
	## @api public
	var last_tick_usec: int = 0

	## 调用方附加元数据。
	## [br]
	## @api public
	## [br]
	## @schema metadata: 项目自定义元数据 Dictionary；键和值由调用方维护。
	var metadata: Dictionary = {}

	# --- 私有变量 ---

	## 运行态复制失败节点携带的失败原因；缺失 tick 实现时优先报告该原因。
	## [br]
	## @api private
	var _runtime_duplicate_error: StringName = &""

	## reset 时递增的运行代次，用于识别 tick 回调期间发生的重置。
	## [br]
	## @api private
	var _runtime_generation: int = 0


	# --- 公共方法 ---

	## 执行该节点的逻辑。子类应重写此方法。
	## [br]
	## @api public
	## [br]
	## @param _blackboard: 运行时共享的数据字典。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema _blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(_blackboard: Dictionary) -> int:
		var reason: StringName = _get_missing_tick_reason()
		return _record_tick(Status.FAILURE, reason)


	## 重置节点内部运行状态。
	##
	## 基类不会取消项目持有的外部异步工作；自定义重写必须调用 super.reset()，
	## 使回调内的重置中止旧 tick，并自行清理外部所有权。
	## [br]
	## @api public
	## [br]
	## @since 3.17.0
	func reset() -> void:
		_runtime_generation += 1


	## 创建一份可独立运行的节点副本，不复制调试计数和正在运行的内部状态。
	##
	## 自定义节点必须重写此方法并复制自身动态脚本类型；这也适用于继承
	## Sequence、Decorator 等具体内置节点的自定义子类。默认实现或类型不匹配的
	## 复制结果会由 Runner 转为失败节点，避免静默共享或切片未知节点运行态。
	## [br]
	## @api public
	## [br]
	## @since 3.8.0
	## [br]
	## @return: 运行时副本。
	func duplicate_runtime() -> BTNode:
		push_error("[GFBehaviorTree][behavior_tree.missing_runtime_duplicate_override] BTNode subclasses must override duplicate_runtime() for the default Runner copy; return an independent runtime copy or explicitly create Runner(root, false) to share the runtime tree.")
		var copy: BTNode = BTNode.new()
		_copy_base_fields_to(copy)
		copy._runtime_duplicate_error = &"runtime_duplicate_missing_override"
		copy.metadata["_gf_runtime_duplicate_error"] = &"runtime_duplicate_missing_override"
		return copy


	## 清空节点调试状态。
	## [br]
	## @api public
	## [br]
	## @param recursive: 是否同时清空子节点调试状态。
	func clear_debug_state(recursive: bool = true) -> void:
		_clear_debug_state_internal(recursive, {})


	## 记录节点状态。
	## [br]
	## @api public
	## [br]
	## @param status: 新状态。
	## [br]
	## @param reason: 可选状态原因。
	## [br]
	## @param elapsed_usec: 可选耗时。
	## [br]
	## @return: 原状态值，便于子类直接 return。
	func record_status(status: int, reason: StringName = &"", elapsed_usec: int = 0) -> int:
		var normalized_status: int = GFBehaviorTree._variant_to_status(status)
		var normalized_reason: StringName = GFBehaviorTree._status_reason_from_value(
			status,
			normalized_status
		)
		last_status = normalized_status
		last_reason = normalized_reason if normalized_reason != &"" else reason
		last_tick_usec = maxi(elapsed_usec, 0)
		tick_count += 1
		return normalized_status


	## 获取调试快照。
	## [br]
	## @api public
	## [br]
	## @since 3.3.0
	## [br]
	## @return: 调试快照字典。
	## [br]
	## @schema return: 包含 node_id、name、status、status_text、reason、tick_count、last_tick_usec、child_count、captured_child_count、omitted_child_count、children 和 metadata 字段的 Dictionary；children 在 _get_debug_children() 返回后按递归预算限制，自定义 override 必须自行保证其内部构造有界；metadata 为有界 JSON-safe 投影；截断会通过节点字段和顶层 debug_budget 诊断；真实回边以 cycle=true 表示，非回边的重复 identity 以 shared_reference=true 表示。
	func get_debug_snapshot() -> Dictionary:
		return GFBehaviorTree.build_debug_snapshot(self)


	# --- 可重写钩子 / 虚方法 ---

	## 供调试遍历取得直接子节点的扩展点；默认返回空数组。重写应自行限制构造成本，调用方仅在返回后应用遍历预算。
	## [br]
	## @api protected
	## [br]
	## @since 3.17.0
	## [br]
	## @return: 直接子节点列表；返回节点引用，调试遍历会识别环和共享身份。
	func _get_debug_children() -> Array[BTNode]:
		return []


	# --- 私有/辅助方法 ---

	## 清空当前节点的调试计数与状态；递归模式使用实例标识集合避免重复处理或环形遍历。
	## [br]
	## @api private
	func _clear_debug_state_internal(recursive: bool, visited: Dictionary) -> void:
		var instance_id: int = get_instance_id()
		if visited.has(instance_id):
			return
		visited[instance_id] = true

		last_status = Status.FRESH
		last_reason = &""
		tick_count = 0
		last_tick_usec = 0
		if recursive:
			for child: BTNode in _get_debug_children():
				if child != null:
					child._clear_debug_state_internal(true, visited)


	## 在共享节点数、深度和子项预算内构建原始调试树；分别标记递归回边与非回边的共享引用，metadata 此处仍引用原字典，后续统一投影。
	## [br]
	## @api private
	func _get_debug_snapshot_internal(
		active_path: Dictionary,
		seen: Dictionary,
		budget: Dictionary,
		depth: int
	) -> Dictionary:
		if not GFBehaviorTree._consume_debug_node(budget):
			return {
				"truncated": true,
				"truncation_reason": "max_nodes",
			}
		var instance_id: int = get_instance_id()
		if active_path.has(instance_id):
			return {
				"node_id": String(node_id),
				"name": name,
				"status": last_status,
				"status_text": String(GFBehaviorTree.status_to_string(last_status)),
				"reason": "debug_cycle",
				"tick_count": tick_count,
				"last_tick_usec": last_tick_usec,
				"child_count": 0,
				"captured_child_count": 0,
				"omitted_child_count": 0,
				"children": [],
				"metadata": {},
				"cycle": true,
			}
		if seen.has(instance_id):
			return {
				"node_id": String(node_id),
				"name": name,
				"status": last_status,
				"status_text": String(GFBehaviorTree.status_to_string(last_status)),
				"reason": "debug_shared_reference",
				"tick_count": tick_count,
				"last_tick_usec": last_tick_usec,
				"child_count": 0,
				"captured_child_count": 0,
				"omitted_child_count": 0,
				"children": [],
				"metadata": {},
				"shared_reference": true,
			}
		active_path[instance_id] = true
		seen[instance_id] = true

		var children: Array[Dictionary] = []
		var debug_children: Array[BTNode] = _get_debug_children()
		var child_count: int = debug_children.size()
		var max_children: int = GFBehaviorTree._read_debug_budget_int(
			budget,
			"max_children",
			GFBehaviorTree._DEFAULT_DEBUG_MAX_CHILDREN
		)
		var child_limit: int = mini(child_count, max_children)
		var truncation_reason: StringName = &""
		for child_index: int in range(child_limit):
			var child: BTNode = debug_children[child_index]
			if child == null:
				if truncation_reason == &"":
					truncation_reason = &"null_child"
				GFBehaviorTree._mark_debug_snapshot_truncated(budget, &"null_child")
				continue
			if depth >= GFBehaviorTree._read_debug_budget_int(
				budget,
				"max_depth",
				GFBehaviorTree._DEFAULT_DEBUG_MAX_DEPTH
			):
				truncation_reason = &"max_depth"
				GFBehaviorTree._mark_debug_snapshot_truncated(budget, truncation_reason)
				break
			if not GFBehaviorTree._has_debug_node_capacity(budget):
				truncation_reason = &"max_nodes"
				GFBehaviorTree._mark_debug_snapshot_truncated(budget, truncation_reason)
				break
			children.append(child._get_debug_snapshot_internal(
				active_path,
				seen,
				budget,
				depth + 1
			))
		var _active_path_erased: bool = active_path.erase(instance_id)
		if child_count > child_limit:
			if truncation_reason == &"":
				truncation_reason = &"max_children"
			GFBehaviorTree._mark_debug_snapshot_truncated(budget, &"max_children")
		var omitted_child_count: int = child_count - children.size()
		var snapshot: Dictionary = {
			"node_id": String(node_id),
			"name": name,
			"status": last_status,
			"status_text": String(GFBehaviorTree.status_to_string(last_status)),
			"reason": String(last_reason),
			"tick_count": tick_count,
			"last_tick_usec": last_tick_usec,
			"child_count": child_count,
			"captured_child_count": children.size(),
			"omitted_child_count": omitted_child_count,
			"children": children,
			"metadata": metadata,
		}
		if omitted_child_count > 0:
			snapshot["truncated"] = true
			snapshot["truncation_reason"] = String(truncation_reason)
		return snapshot


	## 按正的起始微秒时间计算耗时并交给 record_status 归一化记录；未给起点时耗时按零计。
	## [br]
	## @api private
	func _record_tick(status: int, reason: StringName = &"", started_usec: int = 0) -> int:
		var elapsed: int = Time.get_ticks_usec() - started_usec if started_usec > 0 else 0
		return record_status(status, reason, elapsed)


	## 复制名称、节点标识并通过统一字典复制助手复制 metadata；不复制运行计数或当前执行状态。
	## [br]
	## @api private
	func _copy_base_fields_to(copy: BTNode) -> void:
		copy.name = name
		copy.node_id = node_id
		copy.metadata = GFBehaviorTree._duplicate_dictionary(metadata)


	## 逐项调用运行态复制入口；复制有效性与失败节点处理由该入口负责。
	## [br]
	## @api private
	func _duplicate_child_nodes(children: Array[BTNode]) -> Array[BTNode]:
		var result: Array[BTNode] = []
		for child: BTNode in children:
			result.append(GFBehaviorTree._duplicate_runtime_node(child))
		return result


	## 建立新的子节点数组并保留原节点引用，不复制节点运行态。
	## [br]
	## @api private
	func _copy_child_nodes(children: Array[BTNode]) -> Array[BTNode]:
		var result: Array[BTNode] = []
		for child: BTNode in children:
			result.append(child)
		return result


	## 检查候选子树是否包含当前节点；空候选不会形成环。
	## [br]
	## @api private
	func _would_create_cycle(candidate: BTNode) -> bool:
		if candidate == null:
			return false
		return _node_contains_descendant(candidate, self, {})


	## 按实例身份递归搜索目标节点，使用 visited 跳过已检查节点。
	## [br]
	## @api private
	func _node_contains_descendant(candidate: BTNode, target: BTNode, visited: Dictionary) -> bool:
		if candidate == null:
			return false
		if candidate == target:
			return true
		var instance_id: int = candidate.get_instance_id()
		if visited.has(instance_id):
			return false
		visited[instance_id] = true
		for child: BTNode in candidate._get_debug_children():
			if _node_contains_descendant(child, target, visited):
				return true
		return false


	## 优先使用返回值归一化产生的原因，否则按允许传播规则读取子节点原因。
	## [br]
	## @api private
	func _get_child_status_reason(child: BTNode, value: Variant, normalized_status: int) -> StringName:
		var reason: StringName = GFBehaviorTree._status_reason_from_value(value, normalized_status)
		if reason != &"":
			return reason
		if child != null and GFBehaviorTree._should_propagate_child_reason(child.last_reason):
			return child.last_reason
		return &""


	## 优先返回运行态复制失败原因，再读取兼容 metadata 标记；均无原因时报告缺失 tick 重写。
	## [br]
	## @api private
	func _get_missing_tick_reason() -> StringName:
		if _runtime_duplicate_error != &"":
			return _runtime_duplicate_error
		var duplicate_error: Variant = metadata.get("_gf_runtime_duplicate_error", &"")
		if duplicate_error is StringName:
			return duplicate_error
		if duplicate_error is String:
			var duplicate_error_text: String = duplicate_error
			return StringName(duplicate_error_text)
		return &"missing_tick_override"


## 行为树黑板作用域。
##
## 支持父级回退和局部覆盖，可在项目层按需转换为 Dictionary 传给既有节点。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class BlackboardScope extends RefCounted:
	## 当前作用域值。
	##
	## 该字段是当前作用域的 live mutable storage；直接写入会绕过 set_value() 的复制边界。
	## 需要隔离快照时应使用 set_value()、get_value() 与 to_dictionary()。
	## [br]
	## @api public
	## [br]
	## @since 3.17.0
	## [br]
	## @schema values: 当前作用域持有的黑板值 Dictionary；键通常为 StringName，值由项目自定义。
	var values: Dictionary = {}

	## 可选父级作用域。
	## [br]
	## @api public
	## [br]
	## @since 3.3.0
	var parent: BlackboardScope:
		get:
			return _parent
		set(value):
			var _set_parent_result: bool = set_parent(value)

	# --- 私有变量 ---

	## 父作用域引用；本地缺失的键沿该链查找，设置时拒绝形成环。
	## [br]
	## @api private
	var _parent: BlackboardScope = null


	# --- Godot 生命周期方法 ---

	## 通过统一字典复制助手初始化本地值，并经 set_parent 校验父作用域。
	## [br]
	## @api private
	func _init(initial_values: Dictionary = {}, parent_scope: BlackboardScope = null) -> void:
		values = GFBehaviorTree._duplicate_dictionary(initial_values)
		var _set_parent_result: bool = set_parent(parent_scope)


	# --- 公共方法 ---

	## 设置作用域值。
	## [br]
	## @api public
	## [br]
	## @param key: 值标识。
	## [br]
	## @param value: 值。
	## [br]
	## @schema value: 任意可存入黑板的项目值。
	func set_value(key: StringName, value: Variant) -> void:
		values[key] = GFVariantData.duplicate_variant(value)


	## 设置父级作用域。
	## [br]
	## @api public
	## [br]
	## @since 8.0.0
	## [br]
	## @param parent_scope: 新父级作用域；传入 null 表示清空父级。
	## [br]
	## @return: 设置成功返回 true；会形成循环时返回 false。
	func set_parent(parent_scope: BlackboardScope) -> bool:
		if _would_create_parent_cycle(parent_scope):
			push_error("[GFBehaviorTree][behavior_tree.cyclic_blackboard_parent] Cannot set a BlackboardScope parent that would create a cycle.")
			return false
		_parent = parent_scope
		return true


	## 获取作用域值。
	## [br]
	## @api public
	## [br]
	## @param key: 值标识。
	## [br]
	## @param default_value: 缺失时返回的默认值。
	## [br]
	## @return: 作用域值。
	## [br]
	## @schema default_value: 缺失时返回的任意项目值。
	## [br]
	## @schema return: 找到的黑板值，或传入的 default_value。
	func get_value(key: StringName, default_value: Variant = null) -> Variant:
		return _get_value_internal(key, default_value, {})


	## 检查作用域值是否存在。
	## [br]
	## @api public
	## [br]
	## @since 3.17.0
	## [br]
	## @param key: 值标识。
	## [br]
	## @return: 存在返回 true。
	func has_value(key: StringName) -> bool:
		return _has_value_internal(key, {})


	## 转换为合并后的字典。
	## [br]
	## @api public
	## [br]
	## @since 3.17.0
	## [br]
	## @return: 黑板字典。
	## [br]
	## @schema return: 父级与当前作用域合并后的 Dictionary；当前作用域同名键覆盖父级键。
	func to_dictionary() -> Dictionary:
		return _to_dictionary_internal({})


	# --- 私有/辅助方法 ---

	## 沿父链查找最近的键并复制返回值；重复作用域或整条链缺键时复制默认值。
	## [br]
	## @api private
	func _get_value_internal(key: StringName, default_value: Variant, visited: Dictionary) -> Variant:
		var instance_id: int = get_instance_id()
		if visited.has(instance_id):
			return GFVariantData.duplicate_variant(default_value)
		visited[instance_id] = true

		if values.has(key):
			return GFVariantData.duplicate_variant(values[key])
		if _parent != null:
			return _parent._get_value_internal(key, default_value, visited)
		return GFVariantData.duplicate_variant(default_value)


	## 检查本地或父链是否存在键；再次遇到相同实例时返回 false。
	## [br]
	## @api private
	func _has_value_internal(key: StringName, visited: Dictionary) -> bool:
		var instance_id: int = get_instance_id()
		if visited.has(instance_id):
			return false
		visited[instance_id] = true
		return values.has(key) or (_parent != null and _parent._has_value_internal(key, visited))


	## 先展开父作用域，再复制本地值覆盖同名键；重复作用域返回空字典以终止循环。
	## [br]
	## @api private
	func _to_dictionary_internal(visited: Dictionary) -> Dictionary:
		var instance_id: int = get_instance_id()
		if visited.has(instance_id):
			return {}
		visited[instance_id] = true

		var result: Dictionary = _parent._to_dictionary_internal(visited) if _parent != null else {}
		for key: Variant in values.keys():
			result[key] = GFVariantData.duplicate_variant(values[key])
		return result


	## 拒绝自身作为父作用域，以及父链中已经包含自身的候选。
	## [br]
	## @api private
	func _would_create_parent_cycle(parent_scope: BlackboardScope) -> bool:
		if parent_scope == null:
			return false
		if parent_scope == self:
			return true
		return _parent_chain_contains(parent_scope, self, {})


	## 以实例身份搜索父链，visited 防止既有环使遍历不终止。
	## [br]
	## @api private
	func _parent_chain_contains(candidate: BlackboardScope, target: BlackboardScope, visited: Dictionary) -> bool:
		if candidate == null:
			return false
		if candidate == target:
			return true
		var instance_id: int = candidate.get_instance_id()
		if visited.has(instance_id):
			return false
		visited[instance_id] = true
		return _parent_chain_contains(candidate.parent, target, visited)


## 顺序节点 (AND 逻辑)。
##
## 依次执行子节点，只有全部成功才返回 SUCCESS。遇到 RUNNING 或 FAILURE 则中断并返回对应状态。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class Sequence extends BTNode:
	# --- 私有变量 ---

	## 顺序执行的子节点引用列表；构造时复制数组，节点引用仍共享。
	## [br]
	## @api private
	var _children: Array[BTNode]

	## 本次执行尚未完成的子节点索引，reset 后回到零。
	## [br]
	## @api private
	var _current_child_idx: int = 0


	# --- Godot 生命周期方法 ---

	## 设置序列名称并复制子节点引用数组，保留各节点实例。
	## [br]
	## @api private
	func _init(children_nodes: Array[BTNode]) -> void:
		name = "Sequence"
		_children = _copy_child_nodes(children_nodes)


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		while _current_child_idx < _children.size():
			var child: BTNode = _children[_current_child_idx]
			if child == null:
				_current_child_idx += 1
				continue

			var generation: int = _runtime_generation
			var status_value: int = child.tick(blackboard)
			if generation != _runtime_generation:
				return _record_tick(Status.ABORTED, &"runtime_reset", started)
			var status: int = GFBehaviorTree._variant_to_status(status_value)
			var reason: StringName = _get_child_status_reason(child, status_value, status)
			if not GFBehaviorTree._is_success(status):
				if GFBehaviorTree._is_failure(status) or GFBehaviorTree._is_aborted(status):
					reset()
				return _record_tick(status, reason, started)
			_current_child_idx += 1

		reset()
		return _record_tick(Status.SUCCESS, &"", started)


	## 重置当前子节点索引与所有子节点状态。
	## [br]
	## @api public
	func reset() -> void:
		_current_child_idx = 0
		for child: BTNode in _children:
			if child != null:
				child.reset()
		super.reset()


	## 创建可独立运行的顺序节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: Sequence = Sequence.new(_duplicate_child_nodes(_children))
		_copy_base_fields_to(copy)
		return copy


	# --- 可重写钩子 / 虚方法 ---

	## 为调试遍历返回本序列的子节点引用数组。
	## [br]
	## @api protected
	## [br]
	## @since 3.17.0
	## [br]
	## @return: 当前子节点引用列表，不在此复制节点。
	func _get_debug_children() -> Array[BTNode]:
		return _children


## 选择节点 (OR 逻辑)。
##
## 依次执行子节点，直到有一个子节点返回 SUCCESS 或 RUNNING，否则返回 FAILURE。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class Selector extends BTNode:
	# --- 私有变量 ---

	## 按顺序尝试的候选子节点引用列表。
	## [br]
	## @api private
	var _children: Array[BTNode]

	## 本次选择正在尝试的子节点位置，reset 后回到零。
	## [br]
	## @api private
	var _current_child_idx: int = 0


	# --- Godot 生命周期方法 ---

	## 设置选择器名称并复制候选引用数组。
	## [br]
	## @api private
	func _init(children_nodes: Array[BTNode]) -> void:
		name = "Selector"
		_children = _copy_child_nodes(children_nodes)


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		while _current_child_idx < _children.size():
			var child: BTNode = _children[_current_child_idx]
			if child == null:
				_current_child_idx += 1
				continue

			var generation: int = _runtime_generation
			var status_value: int = child.tick(blackboard)
			if generation != _runtime_generation:
				return _record_tick(Status.ABORTED, &"runtime_reset", started)
			var status: int = GFBehaviorTree._variant_to_status(status_value)
			var reason: StringName = _get_child_status_reason(child, status_value, status)
			if reason == &"invalid_status" or GFBehaviorTree._is_aborted(status):
				reset()
				return _record_tick(status, reason, started)
			if not GFBehaviorTree._is_failure(status):
				if GFBehaviorTree._is_success(status):
					reset()
				return _record_tick(status, reason, started)
			_current_child_idx += 1

		reset()
		return _record_tick(Status.FAILURE, &"", started)


	## 重置当前子节点索引与所有子节点状态。
	## [br]
	## @api public
	func reset() -> void:
		_current_child_idx = 0
		for child: BTNode in _children:
			if child != null:
				child.reset()
		super.reset()


	## 创建可独立运行的选择节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: Selector = Selector.new(_duplicate_child_nodes(_children))
		_copy_base_fields_to(copy)
		return copy


	# --- 可重写钩子 / 虚方法 ---

	## 为调试遍历返回选择器的候选子节点引用数组。
	## [br]
	## @api protected
	## [br]
	## @since 3.17.0
	## [br]
	## @return: 当前候选节点引用列表。
	func _get_debug_children() -> Array[BTNode]:
		return _children


## 并行节点。
##
## 每次 tick 推进全部子节点，并根据 ParallelPolicy 汇总状态。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class Parallel extends BTNode:
	# --- 私有变量 ---

	## 并行策略管理的子节点引用列表。
	## [br]
	## @api private
	var _children: Array[BTNode]

	## 与子节点一一对应的缓存状态；长度变化时全部重新置为 RUNNING。
	## [br]
	## @api private
	var _child_statuses: Array[int] = []

	## 并行节点完成策略。
	## [br]
	## @api public
	var policy: ParallelPolicy = ParallelPolicy.REQUIRE_ALL


	# --- Godot 生命周期方法 ---

	## 复制子节点引用数组并保存完成策略。
	## [br]
	## @api private
	func _init(
		children_nodes: Array[BTNode],
		completion_policy: ParallelPolicy = ParallelPolicy.REQUIRE_ALL
	) -> void:
		name = "Parallel"
		_children = _copy_child_nodes(children_nodes)
		policy = completion_policy


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _children.is_empty():
			var empty_status: int = Status.SUCCESS if policy == ParallelPolicy.REQUIRE_ALL else Status.FAILURE
			return _record_tick(empty_status, &"empty_parallel", started)

		_ensure_child_statuses()
		var active_count: int = 0
		var has_running: bool = false
		var has_success: bool = false
		var has_failure: bool = false
		var has_aborted: bool = false
		for index: int in range(_children.size()):
			var child: BTNode = _children[index]
			if child == null:
				continue

			active_count += 1
			var status: int = _child_statuses[index]
			if GFBehaviorTree._is_running(status):
				var generation: int = _runtime_generation
				var status_value: int = child.tick(blackboard)
				if generation != _runtime_generation:
					return _record_tick(Status.ABORTED, &"runtime_reset", started)
				status = GFBehaviorTree._variant_to_status(status_value)
				var reason: StringName = _get_child_status_reason(child, status_value, status)
				if reason == &"invalid_status":
					reset()
					return _record_tick(Status.FAILURE, reason, started)
				if not GFBehaviorTree._is_running(status):
					_child_statuses[index] = status

			has_success = has_success or GFBehaviorTree._is_success(status)
			has_failure = has_failure or GFBehaviorTree._is_failure(status)
			has_running = has_running or GFBehaviorTree._is_running(status)
			has_aborted = has_aborted or GFBehaviorTree._is_aborted(status)

		if active_count <= 0:
			reset()
			var inactive_status: int = Status.SUCCESS if policy == ParallelPolicy.REQUIRE_ALL else Status.FAILURE
			return _record_tick(inactive_status, &"empty_parallel", started)

		if policy == ParallelPolicy.REQUIRE_ONE:
			if has_aborted:
				reset()
				return _record_tick(Status.ABORTED, &"aborted", started)
			if has_success:
				reset()
				return _record_tick(Status.SUCCESS, &"", started)
			if has_running:
				return _record_tick(Status.RUNNING, &"", started)
			reset()
			return _record_tick(Status.FAILURE, &"", started)

		if has_aborted:
			reset()
			return _record_tick(Status.ABORTED, &"aborted", started)
		if has_failure:
			reset()
			return _record_tick(Status.FAILURE, &"", started)
		if has_running:
			return _record_tick(Status.RUNNING, &"", started)

		reset()
		return _record_tick(Status.SUCCESS, &"", started)


	## 重置所有子节点状态。
	## [br]
	## @api public
	func reset() -> void:
		_child_statuses.clear()
		for child: BTNode in _children:
			if child != null:
				child.reset()
		super.reset()


	## 创建可独立运行的并行节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: Parallel = Parallel.new(_duplicate_child_nodes(_children), policy)
		_copy_base_fields_to(copy)
		return copy


	# --- 可重写钩子 / 虚方法 ---

	## 为调试遍历返回并行节点管理的子节点引用数组。
	## [br]
	## @api protected
	## [br]
	## @since 3.17.0
	## [br]
	## @return: 当前子节点引用列表。
	func _get_debug_children() -> Array[BTNode]:
		return _children


	# --- 私有/辅助方法 ---

	## 仅在缓存长度与子节点数不符时重建状态数组，每项初始化为 RUNNING。
	## [br]
	## @api private
	func _ensure_child_statuses() -> void:
		if _child_statuses.size() == _children.size():
			return
		_child_statuses.clear()
		for _index: int in range(_children.size()):
			_child_statuses.append(Status.RUNNING)


## 随机选择节点。
##
## 与 Selector 语义一致，但每轮从随机顺序尝试子节点。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class RandomSelector extends BTNode:
	## 可选随机源；为空时优先使用 blackboard["rng"]，否则退回全局随机。
	## [br]
	## @api public
	var rng: RandomNumberGenerator = null

	# --- 私有变量 ---

	## 随机选择器的原始候选引用列表，重置时也按此列表重置子节点。
	## [br]
	## @api private
	var _children: Array[BTNode]

	## 当前一次执行使用的随机排列，运行中沿用该顺序。
	## [br]
	## @api private
	var _active_order: Array[BTNode] = []

	## 当前随机排列中尚在尝试的位置。
	## [br]
	## @api private
	var _current_child_idx: int = 0


	# --- Godot 生命周期方法 ---

	## 复制候选引用数组并保存显式随机源；空随机源由黑板等后续解析。
	## [br]
	## @api private
	func _init(children_nodes: Array[BTNode], random_source: RandomNumberGenerator = null) -> void:
		name = "RandomSelector"
		_children = _copy_child_nodes(children_nodes)
		rng = random_source


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；可提供 rng: RandomNumberGenerator，其余字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _active_order.is_empty():
			_active_order = _make_random_order(blackboard)

		while _current_child_idx < _active_order.size():
			var child: BTNode = _active_order[_current_child_idx]
			if child == null:
				_current_child_idx += 1
				continue

			var generation: int = _runtime_generation
			var status_value: int = child.tick(blackboard)
			if generation != _runtime_generation:
				return _record_tick(Status.ABORTED, &"runtime_reset", started)
			var status: int = GFBehaviorTree._variant_to_status(status_value)
			var reason: StringName = _get_child_status_reason(child, status_value, status)
			if reason == &"invalid_status" or GFBehaviorTree._is_aborted(status):
				reset()
				return _record_tick(status, reason, started)
			if not GFBehaviorTree._is_failure(status):
				if GFBehaviorTree._is_success(status):
					reset()
				return _record_tick(status, reason, started)
			_current_child_idx += 1

		reset()
		return _record_tick(Status.FAILURE, &"", started)


	## 重置当前随机轮次与子节点状态。
	## [br]
	## @api public
	func reset() -> void:
		_active_order.clear()
		_current_child_idx = 0
		for child: BTNode in _children:
			if child != null:
				child.reset()
		super.reset()


	## 创建可独立运行的随机选择节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: RandomSelector = RandomSelector.new(_duplicate_child_nodes(_children), GFBehaviorTree._duplicate_rng(rng))
		_copy_base_fields_to(copy)
		return copy


	# --- 可重写钩子 / 虚方法 ---

	## 返回原始候选引用列表供调试查看，顺序不使用当前随机执行排列。
	## [br]
	## @api protected
	## [br]
	## @since 3.17.0
	## [br]
	## @return: 原始候选子节点引用列表。
	func _get_debug_children() -> Array[BTNode]:
		return _children


	# --- 私有/辅助方法 ---

	## 将候选引用交给统一随机排列助手，并传递黑板和显式随机源。
	## [br]
	## @api private
	func _make_random_order(blackboard: Dictionary) -> Array[BTNode]:
		return GFBehaviorTree._make_random_node_order(_children, blackboard, rng)


## 随机顺序节点。
##
## 与 Sequence 语义一致，但每轮从随机顺序尝试子节点。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class RandomSequence extends BTNode:
	## 可选随机源；为空时优先使用 blackboard["rng"]，否则退回全局随机。
	## [br]
	## @api public
	var rng: RandomNumberGenerator = null

	# --- 私有变量 ---

	## 随机序列的原始子节点引用列表。
	## [br]
	## @api private
	var _children: Array[BTNode]

	## 当前执行使用的随机排列，reset 后清空。
	## [br]
	## @api private
	var _active_order: Array[BTNode] = []

	## 当前随机排列中的执行位置。
	## [br]
	## @api private
	var _current_child_idx: int = 0


	# --- Godot 生命周期方法 ---

	## 复制子节点引用数组并保存显式随机源。
	## [br]
	## @api private
	func _init(children_nodes: Array[BTNode], random_source: RandomNumberGenerator = null) -> void:
		name = "RandomSequence"
		_children = _copy_child_nodes(children_nodes)
		rng = random_source


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；可提供 rng: RandomNumberGenerator，其余字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _active_order.is_empty():
			_active_order = _make_random_order(blackboard)

		while _current_child_idx < _active_order.size():
			var child: BTNode = _active_order[_current_child_idx]
			if child == null:
				_current_child_idx += 1
				continue

			var generation: int = _runtime_generation
			var status_value: int = child.tick(blackboard)
			if generation != _runtime_generation:
				return _record_tick(Status.ABORTED, &"runtime_reset", started)
			var status: int = GFBehaviorTree._variant_to_status(status_value)
			var reason: StringName = _get_child_status_reason(child, status_value, status)
			if not GFBehaviorTree._is_success(status):
				if GFBehaviorTree._is_failure(status) or GFBehaviorTree._is_aborted(status):
					reset()
				return _record_tick(status, reason, started)
			_current_child_idx += 1

		reset()
		return _record_tick(Status.SUCCESS, &"", started)


	## 重置当前随机轮次与子节点状态。
	## [br]
	## @api public
	func reset() -> void:
		_active_order.clear()
		_current_child_idx = 0
		for child: BTNode in _children:
			if child != null:
				child.reset()
		super.reset()


	## 创建可独立运行的随机顺序节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: RandomSequence = RandomSequence.new(_duplicate_child_nodes(_children), GFBehaviorTree._duplicate_rng(rng))
		_copy_base_fields_to(copy)
		return copy


	# --- 可重写钩子 / 虚方法 ---

	## 返回原始子节点引用列表供调试查看。
	## [br]
	## @api protected
	## [br]
	## @since 3.17.0
	## [br]
	## @return: 原始子节点列表，不使用当前随机执行排列。
	func _get_debug_children() -> Array[BTNode]:
		return _children


	# --- 私有/辅助方法 ---

	## 传递黑板与显式随机源，建立本次执行的子节点排列。
	## [br]
	## @api private
	func _make_random_order(blackboard: Dictionary) -> Array[BTNode]:
		return GFBehaviorTree._make_random_node_order(_children, blackboard, rng)


## 动作节点 (叶子节点)。
##
## 包装一个回调函数执行具体指令。回调需返回 Status 类型。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class Action extends BTNode:
	# --- 私有变量 ---

	## tick 时调用的动作回调，其返回值会归一为节点状态。
	## [br]
	## @api private
	var _action_func: Callable


	# --- Godot 生命周期方法 ---

	## 保存动作回调并设置默认节点名称。
	## [br]
	## @api private
	func _init(action_func: Callable) -> void:
		name = "Action"
		_action_func = action_func


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _action_func.is_valid():
			var status_value: Variant = _action_func.call(blackboard)
			var status: int = GFBehaviorTree._variant_to_status(status_value)
			var reason: StringName = GFBehaviorTree._status_reason_from_value(status_value, status)
			return _record_tick(status, reason, started)
		return _record_tick(Status.FAILURE, &"invalid_action", started)


	## 创建可独立运行的动作节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: Action = Action.new(_action_func)
		_copy_base_fields_to(copy)
		return copy


## 条件检查节点 (叶子节点)。
##
## 包装一个返回布尔值的回调。true 为 SUCCESS，false 为 FAILURE；无效 Callable
## 返回 FAILURE 并记录 invalid_condition，不与合法 condition_false 混同。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class Condition extends BTNode:
	# --- 私有变量 ---

	## tick 时执行的条件回调，供条件节点判定结果。
	## [br]
	## @api private
	var _condition_func: Callable


	# --- Godot 生命周期方法 ---

	## 保存条件回调并设置默认节点名称。
	## [br]
	## @api private
	func _init(condition_func: Callable) -> void:
		name = "Condition"
		_condition_func = condition_func


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if not _condition_func.is_valid():
			return _record_tick(Status.FAILURE, &"invalid_condition", started)

		var condition_value: Variant = _condition_func.call(blackboard)
		var reason: StringName = GFBehaviorTree._condition_reason_from_value(condition_value)
		if reason != &"":
			return _record_tick(Status.FAILURE, reason, started)
		if GFBehaviorTree._condition_result_to_bool(condition_value):
			return _record_tick(Status.SUCCESS, &"", started)
		return _record_tick(Status.FAILURE, &"condition_false", started)


	## 创建可独立运行的条件节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: Condition = Condition.new(_condition_func)
		_copy_base_fields_to(copy)
		return copy


## 单子节点装饰器基类。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class Decorator extends BTNode:
	# --- 私有变量 ---

	## 装饰器持有的可空子节点引用，通过 set_child 检查环。
	## [br]
	## @api private
	var _child: BTNode


	# --- Godot 生命周期方法 ---

	## 先清空子节点，再通过 set_child 接受非空候选，沿用该方法的环检查。
	## [br]
	## @api private
	func _init(child_node: BTNode = null) -> void:
		_child = null
		if child_node != null:
			var _set_child_result: Decorator = set_child(child_node)


	# --- 公共方法 ---

	## 设置被装饰的子节点。
	##
	## 替换不同 child 时先提交新 child，再 reset 旧 child；重复设置同一 identity 是无操作。
	## [br]
	## @api public
	## [br]
	## @since 3.17.0
	## [br]
	## @param child_node: 子节点。
	## [br]
	## @return: 当前装饰器。
	func set_child(child_node: BTNode) -> Decorator:
		if _would_create_cycle(child_node):
			push_error("[GFBehaviorTree][behavior_tree.cyclic_decorator_child] Cannot set a decorator child that would create a cycle.")
			return self
		if _child == child_node:
			return self
		_runtime_generation += 1
		var previous_child: BTNode = _child
		_child = child_node
		if previous_child != null:
			previous_child.reset()
		return self


	## 重置子节点状态。
	## [br]
	## @api public
	func reset() -> void:
		if _child != null:
			_child.reset()
		super.reset()


	## 创建可独立运行的装饰器副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: Decorator = Decorator.new(_duplicate_child())
		_copy_base_fields_to(copy)
		return copy


	# --- 可重写钩子 / 虚方法 ---

	## 将当前子节点包装成调试遍历列表；没有子节点时返回空数组。
	## [br]
	## @api protected
	## [br]
	## @since 3.17.0
	## [br]
	## @return: 最多含一个节点引用的新数组。
	func _get_debug_children() -> Array[BTNode]:
		var result: Array[BTNode] = []
		if _child != null:
			result.append(_child)
		return result


	# --- 私有/辅助方法 ---

	## 将当前子节点交给统一运行态复制入口，沿用其空值和复制失败约定。
	## [br]
	## @api private
	func _duplicate_child() -> BTNode:
		return GFBehaviorTree._duplicate_runtime_node(_child)


## 反转装饰节点。
##
## 翻转子节点的成功与失败状态。RUNNING 状态保持不变。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class Inverter extends Decorator:


	# --- Godot 生命周期方法 ---

	## 通过装饰器基类绑定子节点，并设置反转器名称。
	## [br]
	## @api private
	func _init(child_node: BTNode) -> void:
		super(child_node)
		name = "Inverter"


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null:
			return _record_tick(Status.FAILURE, &"missing_child", started)
		var generation: int = _runtime_generation
		var status_value: int = _child.tick(blackboard)
		if generation != _runtime_generation:
			return _record_tick(Status.ABORTED, &"runtime_reset", started)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if reason == &"invalid_status" or GFBehaviorTree._is_aborted(status):
			_child.reset()
			return _record_tick(status, reason, started)
		if GFBehaviorTree._is_success(status):
			_child.reset()
			return _record_tick(Status.FAILURE, &"", started)
		if GFBehaviorTree._is_failure(status):
			_child.reset()
			return _record_tick(Status.SUCCESS, &"", started)
		return _record_tick(status, reason, started)


	## 创建可独立运行的反转装饰节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: Inverter = Inverter.new(_duplicate_child())
		_copy_base_fields_to(copy)
		return copy


## 总是成功装饰节点。
##
## 子节点运行中时保持 RUNNING，子节点结束时统一返回 SUCCESS。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class AlwaysSucceed extends Decorator:


	# --- Godot 生命周期方法 ---

	## 通过装饰器基类绑定子节点，并设置成功装饰器名称。
	## [br]
	## @api private
	func _init(child_node: BTNode) -> void:
		super(child_node)
		name = "AlwaysSucceed"


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null:
			return _record_tick(Status.SUCCESS, &"missing_child", started)
		var generation: int = _runtime_generation
		var status_value: int = _child.tick(blackboard)
		if generation != _runtime_generation:
			return _record_tick(Status.ABORTED, &"runtime_reset", started)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if reason == &"invalid_status" or GFBehaviorTree._is_aborted(status):
			_child.reset()
			return _record_tick(status, reason, started)
		if GFBehaviorTree._is_running(status):
			return _record_tick(Status.RUNNING, &"", started)
		_child.reset()
		return _record_tick(Status.SUCCESS, &"", started)


	## 创建可独立运行的总是成功装饰节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: AlwaysSucceed = AlwaysSucceed.new(_duplicate_child())
		_copy_base_fields_to(copy)
		return copy


## 总是失败装饰节点。
##
## 子节点运行中时保持 RUNNING，子节点结束时统一返回 FAILURE。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class AlwaysFail extends Decorator:


	# --- Godot 生命周期方法 ---

	## 通过装饰器基类绑定子节点，并设置失败装饰器名称。
	## [br]
	## @api private
	func _init(child_node: BTNode) -> void:
		super(child_node)
		name = "AlwaysFail"


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null:
			return _record_tick(Status.FAILURE, &"missing_child", started)
		var generation: int = _runtime_generation
		var status_value: int = _child.tick(blackboard)
		if generation != _runtime_generation:
			return _record_tick(Status.ABORTED, &"runtime_reset", started)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if reason == &"invalid_status" or GFBehaviorTree._is_aborted(status):
			_child.reset()
			return _record_tick(status, reason, started)
		if GFBehaviorTree._is_running(status):
			return _record_tick(Status.RUNNING, &"", started)
		_child.reset()
		return _record_tick(Status.FAILURE, &"", started)


	## 创建可独立运行的总是失败装饰节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: AlwaysFail = AlwaysFail.new(_duplicate_child())
		_copy_base_fields_to(copy)
		return copy


## 概率装饰节点。
##
## 每轮按 probability 判定是否允许子节点执行，未命中时返回 FAILURE。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class Probability extends Decorator:
	## 执行概率，范围 0.0 到 1.0。
	## [br]
	## @api public
	var probability: float = 1.0

	## 可选随机源；为空时优先使用 blackboard["rng"]。
	## [br]
	## @api public
	var rng: RandomNumberGenerator = null

	# --- 私有变量 ---

	## 当前执行是否已经抽取概率决定，避免 RUNNING 期间重复抽样。
	## [br]
	## @api private
	var _decision_made: bool = false

	## 当前一次执行缓存的概率许可结果。
	## [br]
	## @api private
	var _allowed_this_run: bool = false


	# --- Godot 生命周期方法 ---

	## 绑定子节点，将概率限制在 0 到 1，并保存可选随机源。
	## [br]
	## @api private
	func _init(child_node: BTNode, chance: float = 1.0, random_source: RandomNumberGenerator = null) -> void:
		super(child_node)
		name = "Probability"
		probability = clampf(chance, 0.0, 1.0)
		rng = random_source


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；可提供 rng: RandomNumberGenerator，其余字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null:
			return _record_tick(Status.FAILURE, &"missing_child", started)
		if not _decision_made:
			var active_rng: RandomNumberGenerator = _resolve_rng(blackboard)
			var roll: float = active_rng.randf() if active_rng != null else randf()
			_allowed_this_run = roll <= probability
			_decision_made = true
		if not _allowed_this_run:
			reset()
			return _record_tick(Status.FAILURE, &"probability_miss", started)

		var generation: int = _runtime_generation
		var status_value: int = _child.tick(blackboard)
		if generation != _runtime_generation:
			return _record_tick(Status.ABORTED, &"runtime_reset", started)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if not GFBehaviorTree._is_running(status):
			reset()
		return _record_tick(status, reason, started)


	## 重置当前概率轮次与子节点状态。
	## [br]
	## @api public
	func reset() -> void:
		_decision_made = false
		_allowed_this_run = false
		super.reset()


	## 创建可独立运行的概率装饰节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: Probability = Probability.new(_duplicate_child(), probability, GFBehaviorTree._duplicate_rng(rng))
		_copy_base_fields_to(copy)
		return copy


	# --- 私有/辅助方法 ---

	## 通过统一规则从显式随机源和黑板解析本次使用的随机数生成器。
	## [br]
	## @api private
	func _resolve_rng(blackboard: Dictionary) -> RandomNumberGenerator:
		return GFBehaviorTree._resolve_rng_from_blackboard(blackboard, rng)


## 冷却装饰节点。
##
## 子节点结束并完成 reset 后进入冷却期，冷却未结束时返回 FAILURE。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class Cooldown extends Decorator:
	## 冷却秒数。
	## [br]
	## @api public
	## [br]
	## @since 3.17.0
	var cooldown_seconds: float:
		get:
			return _cooldown_seconds
		set(value):
			_cooldown_seconds = GFBehaviorTree._sanitize_non_negative_seconds(value, _cooldown_seconds)

	## 可选单调毫秒时钟；为空时使用 Time.get_ticks_msec()。
	## [br]
	## @api public
	## [br]
	## @since 8.0.0
	var clock_msec: Callable = Callable()

	# --- 私有变量 ---

	## 冷却属性的内部秒数存储，由属性 setter 进行归一化。
	## [br]
	## @api private
	var _cooldown_seconds: float = 0.0

	## 上次子节点结束的毫秒时间，负值表示尚未记录结束。
	## [br]
	## @api private
	var _last_finish_msec: int = -1

	## 上次观测的时钟毫秒值，用于钳制时钟倒退。
	## [br]
	## @api private
	var _last_observed_msec: int = -1


	# --- Godot 生命周期方法 ---

	## 绑定子节点，通过属性 setter 设置冷却秒数，并保存可选时钟回调。
	## [br]
	## @api private
	func _init(child_node: BTNode, seconds: float = 0.0, p_clock_msec: Callable = Callable()) -> void:
		super(child_node)
		name = "Cooldown"
		cooldown_seconds = seconds
		clock_msec = p_clock_msec


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @since 3.17.0
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null:
			return _record_tick(Status.FAILURE, &"missing_child", started)
		var now: int = _resolve_time_msec()
		if _last_finish_msec >= 0 and now - _last_finish_msec < GFBehaviorTree._seconds_to_msec(cooldown_seconds):
			return _record_tick(Status.FAILURE, &"cooldown_active", started)
		var generation: int = _runtime_generation
		var status_value: int = _child.tick(blackboard)
		if generation != _runtime_generation:
			return _record_tick(Status.ABORTED, &"runtime_reset", started)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if not GFBehaviorTree._is_running(status):
			_child.reset()
		if (
			(GFBehaviorTree._is_success(status) or GFBehaviorTree._is_failure(status))
			and not GFBehaviorTree._is_error_reason(reason)
		):
			_last_finish_msec = _resolve_time_msec()
		return _record_tick(status, reason, started)


	## 重置运行状态，保留已经开始的冷却。
	## [br]
	## @api public
	func reset() -> void:
		super.reset()


	## 清空冷却状态。
	## [br]
	## @api public
	func clear_cooldown() -> void:
		_last_finish_msec = -1


	## 创建可独立运行的冷却装饰节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: Cooldown = Cooldown.new(_duplicate_child(), cooldown_seconds, clock_msec)
		_copy_base_fields_to(copy)
		return copy


	# --- 私有/辅助方法 ---

	## 通过统一时钟解析器取得不小于此前观测值的毫秒时间，并更新观测值。
	## [br]
	## @api private
	func _resolve_time_msec() -> int:
		_last_observed_msec = GFBehaviorTree._resolve_monotonic_time_msec(
			clock_msec,
			_last_observed_msec
		)
		return _last_observed_msec


## 时间限制装饰节点。
##
## 子节点 RUNNING 持续达到限制时返回 FAILURE 并重置子节点；0 秒表示立即超时，
## 不会先 tick 子节点。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class TimeLimit extends Decorator:
	## 最大运行秒数。
	## [br]
	## @api public
	## [br]
	## @since 3.17.0
	var limit_seconds: float:
		get:
			return _limit_seconds
		set(value):
			_limit_seconds = GFBehaviorTree._sanitize_non_negative_seconds(value, _limit_seconds)

	## 可选单调毫秒时钟；为空时使用 Time.get_ticks_msec()。
	## [br]
	## @api public
	## [br]
	## @since 8.0.0
	var clock_msec: Callable = Callable()

	# --- 私有变量 ---

	## 时间限制属性的内部秒数存储。
	## [br]
	## @api private
	var _limit_seconds: float = 1.0

	## 本轮执行开始的毫秒时间；负值表示尚未开始。
	## [br]
	## @api private
	var _started_msec: int = -1

	## 最近一次时钟观测，用于防止时钟回退延长当前执行。
	## [br]
	## @api private
	var _last_observed_msec: int = -1


	# --- Godot 生命周期方法 ---

	## 绑定子节点，通过属性 setter 设置时间限制，并保存可选时钟回调。
	## [br]
	## @api private
	func _init(child_node: BTNode, seconds: float = 1.0, p_clock_msec: Callable = Callable()) -> void:
		super(child_node)
		name = "TimeLimit"
		limit_seconds = seconds
		clock_msec = p_clock_msec


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @since 3.17.0
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null:
			return _record_tick(Status.FAILURE, &"missing_child", started)
		var now: int = _resolve_time_msec()
		if _started_msec < 0:
			_started_msec = now
		if limit_seconds <= 0.0 or now - _started_msec >= GFBehaviorTree._seconds_to_msec(limit_seconds):
			reset()
			return _record_tick(Status.FAILURE, &"time_limit_exceeded", started)
		var generation: int = _runtime_generation
		var status_value: int = _child.tick(blackboard)
		if generation != _runtime_generation:
			return _record_tick(Status.ABORTED, &"runtime_reset", started)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if not GFBehaviorTree._is_running(status):
			reset()
		return _record_tick(status, reason, started)


	## 重置计时状态。
	## [br]
	## @api public
	func reset() -> void:
		_started_msec = -1
		super.reset()


	## 创建可独立运行的时间限制装饰节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: TimeLimit = TimeLimit.new(_duplicate_child(), limit_seconds, clock_msec)
		_copy_base_fields_to(copy)
		return copy


	# --- 私有/辅助方法 ---

	## 读取并缓存经单调钳制的毫秒时间。
	## [br]
	## @api private
	func _resolve_time_msec() -> int:
		_last_observed_msec = GFBehaviorTree._resolve_monotonic_time_msec(
			clock_msec,
			_last_observed_msec
		)
		return _last_observed_msec


## 次数限制装饰节点。
##
## 子节点最多被 tick 指定次数；超过次数后返回 FAILURE。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class Limit extends Decorator:
	## 最大允许 tick 次数。
	## [br]
	## @api public
	var max_ticks: int = 1

	# --- 私有变量 ---

	## 本轮已准入的子节点 tick 次数，reset 时清零。
	## [br]
	## @api private
	var _tick_count: int = 0


	# --- Godot 生命周期方法 ---

	## 绑定子节点，并将最大 tick 次数限制为非负值。
	## [br]
	## @api private
	func _init(child_node: BTNode, tick_limit: int = 1) -> void:
		super(child_node)
		name = "Limit"
		max_ticks = maxi(tick_limit, 0)


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null or max_ticks <= 0:
			return _record_tick(Status.FAILURE, &"limit_blocked", started)
		if _tick_count >= max_ticks:
			_child.reset()
			return _record_tick(Status.FAILURE, &"limit_exceeded", started)

		_tick_count += 1
		var generation: int = _runtime_generation
		var status_value: int = _child.tick(blackboard)
		if generation != _runtime_generation:
			return _record_tick(Status.ABORTED, &"runtime_reset", started)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		return _record_tick(status, reason, started)


	## 重置调用计数与子节点状态。
	## [br]
	## @api public
	func reset() -> void:
		_tick_count = 0
		super.reset()


	## 创建可独立运行的次数限制装饰节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: Limit = Limit.new(_duplicate_child(), max_ticks)
		_copy_base_fields_to(copy)
		return copy


## 重复装饰节点。
##
## 子节点成功后重复执行，达到 repeat_count 后返回 SUCCESS；repeat_count 为 0 表示无限重复。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class Repeat extends Decorator:
	## 成功重复次数；0 表示无限重复。
	## [br]
	## @api public
	var repeat_count: int = 1

	# --- 私有变量 ---

	## 本轮子节点已成功完成的次数，reset 时清零。
	## [br]
	## @api private
	var _success_count: int = 0


	# --- Godot 生命周期方法 ---

	## 绑定子节点并将重复次数限制为非负值；零次数的执行含义由 tick 决定。
	## [br]
	## @api private
	func _init(child_node: BTNode, count: int = 1) -> void:
		super(child_node)
		name = "Repeat"
		repeat_count = maxi(count, 0)


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null:
			return _record_tick(Status.FAILURE, &"missing_child", started)

		var generation: int = _runtime_generation
		var status_value: int = _child.tick(blackboard)
		if generation != _runtime_generation:
			return _record_tick(Status.ABORTED, &"runtime_reset", started)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if GFBehaviorTree._is_running(status):
			return _record_tick(Status.RUNNING, &"", started)
		if GFBehaviorTree._is_failure(status) or reason == &"invalid_status":
			reset()
			return _record_tick(Status.FAILURE, reason, started)
		if GFBehaviorTree._is_aborted(status):
			reset()
			return _record_tick(Status.ABORTED, reason, started)

		_success_count += 1
		_child.reset()
		if repeat_count > 0 and _success_count >= repeat_count:
			reset()
			return _record_tick(Status.SUCCESS, &"", started)
		return _record_tick(Status.RUNNING, &"", started)


	## 重置重复计数与子节点状态。
	## [br]
	## @api public
	func reset() -> void:
		_success_count = 0
		super.reset()


	## 创建可独立运行的重复装饰节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: Repeat = Repeat.new(_duplicate_child(), repeat_count)
		_copy_base_fields_to(copy)
		return copy


## 直到成功装饰节点。
##
## 子节点失败时继续返回 RUNNING，直到子节点成功。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class UntilSuccess extends Decorator:


	# --- Godot 生命周期方法 ---

	## 通过装饰器基类绑定子节点并设置节点名称。
	## [br]
	## @api private
	func _init(child_node: BTNode) -> void:
		super(child_node)
		name = "UntilSuccess"


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null:
			return _record_tick(Status.FAILURE, &"missing_child", started)
		var generation: int = _runtime_generation
		var status_value: int = _child.tick(blackboard)
		if generation != _runtime_generation:
			return _record_tick(Status.ABORTED, &"runtime_reset", started)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if reason == &"invalid_status" or GFBehaviorTree._is_aborted(status):
			reset()
			return _record_tick(status, reason, started)
		if GFBehaviorTree._is_success(status):
			reset()
			return _record_tick(Status.SUCCESS, &"", started)
		if GFBehaviorTree._is_failure(status):
			_child.reset()
		return _record_tick(Status.RUNNING, &"", started)


	## 创建可独立运行的直到成功装饰节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: UntilSuccess = UntilSuccess.new(_duplicate_child())
		_copy_base_fields_to(copy)
		return copy


## 直到失败装饰节点。
##
## 子节点成功时继续返回 RUNNING，直到子节点失败。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class UntilFail extends Decorator:


	# --- Godot 生命周期方法 ---

	## 通过装饰器基类绑定子节点并设置节点名称。
	## [br]
	## @api private
	func _init(child_node: BTNode) -> void:
		super(child_node)
		name = "UntilFail"


	# --- 公共方法 ---

	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null:
			return _record_tick(Status.FAILURE, &"missing_child", started)
		var generation: int = _runtime_generation
		var status_value: int = _child.tick(blackboard)
		if generation != _runtime_generation:
			return _record_tick(Status.ABORTED, &"runtime_reset", started)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if reason == &"invalid_status" or GFBehaviorTree._is_aborted(status):
			reset()
			return _record_tick(status, reason, started)
		if GFBehaviorTree._is_failure(status):
			reset()
			return _record_tick(Status.SUCCESS, &"", started)
		if GFBehaviorTree._is_success(status):
			_child.reset()
		return _record_tick(Status.RUNNING, &"", started)


	## 创建可独立运行的直到失败装饰节点副本。
	## [br]
	## @api public
	## [br]
	## @return: 复制后的运行时节点。
	func duplicate_runtime() -> BTNode:
		var copy: UntilFail = UntilFail.new(_duplicate_child())
		_copy_base_fields_to(copy)
		return copy


## 行为树的执行入口容器。
##
## Runner 默认复制节点运行态，并验证每个副本保持独立 identity 与动态脚本类型。
## 同一个 Runner 的 tick 不可同步重入；重入调用会失败关闭为 ABORTED。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class Runner extends RefCounted:
	## 运行时共享黑板。
	## [br]
	## @api public
	## [br]
	## @schema blackboard: 传给根节点 tick() 的共享 Dictionary；键和值由项目自定义。
	var blackboard: Dictionary = {}

	## 是否在构造运行器时复制内置节点运行态，避免多个 Runner 共享同一棵树的进度。
	## [br]
	## @api public
	var duplicates_runtime_tree: bool = true

	# --- 私有变量 ---

	## Runner 实际推进的根节点，依据构造选项为运行态副本或传入原实例。
	## [br]
	## @api private
	var _root_node: BTNode

	## 当前是否正处于 tick 调用，用于拒绝重入推进。
	## [br]
	## @api private
	var _is_ticking: bool = false

	## Runner 重置代次，用于识别执行回调期间的 reset。
	## [br]
	## @api private
	var _reset_serial: int = 0


	# --- Godot 生命周期方法 ---

	## 按 duplicate_runtime_tree 选择复制运行树或直接持有原根节点，并保存该选择。
	## [br]
	## @api private
	func _init(root: BTNode, duplicate_runtime_tree: bool = true) -> void:
		self.duplicates_runtime_tree = duplicate_runtime_tree
		_root_node = GFBehaviorTree._duplicate_runtime_node(root) if duplicate_runtime_tree else root


	# --- 公共方法 ---

	## 驱动行为树运行逻辑。
	## 通常在 GFSystem 的 tick 中被调用。
	## [br]
	## @api public
	## [br]
	## @return: 返回根节点 Status 枚举。
	func tick() -> int:
		if _root_node == null:
			return Status.FAILURE
		if _is_ticking:
			push_error("[GFBehaviorTree][behavior_tree.reentrant_tick] Runner.tick() cannot be reentered synchronously.")
			return Status.ABORTED
		_is_ticking = true
		var reset_serial: int = _reset_serial
		var status_value: Variant = _root_node.tick(blackboard)
		_is_ticking = false
		if reset_serial != _reset_serial:
			return Status.ABORTED
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = GFBehaviorTree._status_reason_from_value(status_value, status)
		if reason == &"invalid_status":
			return _root_node.record_status(Status.FAILURE, reason)
		return status


	## 重置整棵行为树的运行状态。
	## [br]
	## @api public
	func reset() -> void:
		_reset_serial += 1
		if _root_node != null:
			_root_node.reset()


	## 清空整棵行为树的调试状态。
	## [br]
	## @api public
	func clear_debug_state() -> void:
		if _root_node != null:
			_root_node.clear_debug_state(true)


	## 获取运行器调试快照。
	## [br]
	## @api public
	## [br]
	## @since 3.3.0
	## [br]
	## @return: 调试快照字典。
	## [br]
	## @schema return: 包含 root、blackboard_keys、blackboard_key_count、blackboard_keys_truncated 和 debug_budget 字段的 Dictionary；root 为遍历期受限的根节点调试快照；blackboard_keys 是按 max_blackboard_keys 在物化前限流后排序的键样本，不包含黑板值。
	func get_debug_snapshot() -> Dictionary:
		return GFBehaviorTree.build_debug_snapshot(self)


	# --- 私有/辅助方法 ---

	## 构建含根调试树和有界黑板键列表的原始快照；键被截断时同时更新共享预算诊断。
	## [br]
	## @api private
	func _get_debug_snapshot_raw(budget: Dictionary) -> Dictionary:
		var blackboard_keys: Array[String] = _get_blackboard_keys(budget)
		var blackboard_key_count: int = blackboard.size()
		var blackboard_keys_truncated: bool = (
			blackboard_key_count > blackboard_keys.size()
		)
		if blackboard_keys_truncated:
			GFBehaviorTree._mark_debug_snapshot_truncated(
				budget,
				&"max_blackboard_keys"
			)
		return {
			"root": _root_node._get_debug_snapshot_internal({}, {}, budget, 0) if _root_node != null else {},
			"blackboard_keys": blackboard_keys,
			"blackboard_key_count": blackboard_key_count,
			"blackboard_keys_truncated": blackboard_keys_truncated,
		}


	## 按预算从当前黑板迭代顺序截取键并转成字符串，再对已截取部分排序；不保证取到全体键中字典序最小的子集。
	## [br]
	## @api private
	func _get_blackboard_keys(budget: Dictionary) -> Array[String]:
		var result: Array[String] = []
		var max_blackboard_keys: int = GFBehaviorTree._read_debug_budget_int(
			budget,
			"max_blackboard_keys",
			GFBehaviorTree._DEFAULT_DEBUG_MAX_BLACKBOARD_KEYS
		)
		for key: Variant in blackboard:
			if result.size() >= max_blackboard_keys:
				break
			var key_text: String = GFVariantData.to_text(key)
			result.append(key_text)
		result.sort()
		return result
