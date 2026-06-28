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
## [br]
## @api public
## [br]
## @param node: 行为树节点。
## [br]
## @return: 调试快照字典。
## [br]
## @schema node: GFBehaviorTree.BTNode、null 或提供 get_debug_snapshot() 的对象。
## [br]
## @schema return: 包含节点调试状态的 Dictionary；null 节点返回空字典。
static func build_debug_snapshot(node: Variant) -> Dictionary:
	if node is Object:
		var snapshot_owner: Object = node
		return _call_debug_snapshot(snapshot_owner)
	return {}


# --- 私有/辅助方法 ---

static func _call_debug_snapshot(snapshot_owner: Object) -> Dictionary:
	if snapshot_owner == null or not snapshot_owner.has_method("get_debug_snapshot"):
		return {}

	var snapshot_value: Variant = snapshot_owner.call("get_debug_snapshot")
	return GFVariantData.as_dictionary(snapshot_value)


static func _variant_to_status(value: Variant, fallback_status: int = Status.FAILURE) -> int:
	if value is int:
		var status: int = value
		if _is_valid_status(status):
			return status
	return fallback_status


static func _is_valid_status(status: int) -> bool:
	return (
		status == Status.FRESH
		or status == Status.SUCCESS
		or status == Status.FAILURE
		or status == Status.RUNNING
		or status == Status.ABORTED
	)


static func _is_success(status: int) -> bool:
	return status == Status.SUCCESS


static func _is_failure(status: int) -> bool:
	return status == Status.FAILURE


static func _is_running(status: int) -> bool:
	return status == Status.RUNNING


static func _is_aborted(status: int) -> bool:
	return status == Status.ABORTED


static func _status_reason_from_value(value: Variant, normalized_status: int) -> StringName:
	if value is int:
		var status: int = value
		if not _is_valid_status(status):
			return &"invalid_status"
	if normalized_status == Status.ABORTED:
		return &"aborted"
	return &""


static func _condition_result_to_bool(value: Variant) -> bool:
	if value is bool:
		return value
	return false


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


static func _duplicate_rng(source: RandomNumberGenerator) -> RandomNumberGenerator:
	if source == null:
		return null

	var copy: RandomNumberGenerator = RandomNumberGenerator.new()
	copy.seed = source.seed
	copy.state = source.state
	return copy


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
		return _record_tick(Status.SUCCESS)


	## 重置节点内部运行状态。
	## [br]
	## @api public
	func reset() -> void:
		pass


	## 创建一份可独立运行的节点副本，不复制调试计数和正在运行的内部状态。
	##
	## 自定义节点若持有运行态，应重写此方法并复制自身类型；默认返回自身，
	## 以避免未知子类被错误降级为基础 BTNode。
	## [br]
	## @api public
	## [br]
	## @return: 运行时副本。
	func duplicate_runtime() -> BTNode:
		return self


	## 清空节点调试状态。
	## [br]
	## @api public
	## [br]
	## @param recursive: 是否同时清空子节点调试状态。
	func clear_debug_state(recursive: bool = true) -> void:
		last_status = Status.FRESH
		last_reason = &""
		tick_count = 0
		last_tick_usec = 0
		if recursive:
			for child: BTNode in _get_debug_children():
				if child != null:
					child.clear_debug_state(true)


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
		last_status = status
		last_reason = reason
		last_tick_usec = maxi(elapsed_usec, 0)
		tick_count += 1
		return status


	## 获取调试快照。
	## [br]
	## @api public
	## [br]
	## @return: 调试快照字典。
	## [br]
	## @schema return: 包含 node_id、name、status、status_text、reason、tick_count、last_tick_usec、child_count、children 和 metadata 字段的 Dictionary；children 为子节点快照数组。
	func get_debug_snapshot() -> Dictionary:
		var children: Array[Dictionary] = []
		for child: BTNode in _get_debug_children():
			if child != null:
				children.append(child.get_debug_snapshot())
		return {
			"node_id": node_id,
			"name": name,
			"status": last_status,
			"status_text": GFBehaviorTree.status_to_string(last_status),
			"reason": last_reason,
			"tick_count": tick_count,
			"last_tick_usec": last_tick_usec,
			"child_count": children.size(),
			"children": children,
			"metadata": metadata.duplicate(true),
		}


	func _record_tick(status: int, reason: StringName = &"", started_usec: int = 0) -> int:
		var elapsed: int = Time.get_ticks_usec() - started_usec if started_usec > 0 else 0
		return record_status(status, reason, elapsed)


	func _copy_base_fields_to(copy: BTNode) -> void:
		copy.name = name
		copy.node_id = node_id
		copy.metadata = metadata.duplicate(true)


	func _duplicate_child_nodes(children: Array[BTNode]) -> Array[BTNode]:
		var result: Array[BTNode] = []
		for child: BTNode in children:
			result.append(child.duplicate_runtime() if child != null else null)
		return result


	func _copy_child_nodes(children: Array[BTNode]) -> Array[BTNode]:
		var result: Array[BTNode] = []
		for child: BTNode in children:
			result.append(child)
		return result


	func _would_create_cycle(candidate: BTNode) -> bool:
		if candidate == null:
			return false
		return _node_contains_descendant(candidate, self, {})


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


	func _get_child_status_reason(child: BTNode, value: Variant, normalized_status: int) -> StringName:
		var reason: StringName = GFBehaviorTree._status_reason_from_value(value, normalized_status)
		if reason != &"":
			return reason
		if child != null and (child.last_reason == &"invalid_status" or child.last_reason == &"aborted"):
			return child.last_reason
		return &""


	func _get_debug_children() -> Array[BTNode]:
		return []


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
	## [br]
	## @api public
	## [br]
	## @schema values: 当前作用域持有的黑板值 Dictionary；键通常为 StringName，值由项目自定义。
	var values: Dictionary = {}

	## 可选父级作用域。
	## [br]
	## @api public
	var parent: BlackboardScope = null

	func _init(initial_values: Dictionary = {}, parent_scope: BlackboardScope = null) -> void:
		values = initial_values.duplicate(true)
		parent = parent_scope


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
		if values.has(key):
			return GFVariantData.duplicate_variant(values[key])
		if parent != null:
			return parent.get_value(key, default_value)
		return GFVariantData.duplicate_variant(default_value)


	## 检查作用域值是否存在。
	## [br]
	## @api public
	## [br]
	## @param key: 值标识。
	## [br]
	## @return: 存在返回 true。
	func has_value(key: StringName) -> bool:
		return values.has(key) or (parent != null and parent.has_value(key))


	## 转换为合并后的字典。
	## [br]
	## @api public
	## [br]
	## @return: 黑板字典。
	## [br]
	## @schema return: 父级与当前作用域合并后的 Dictionary；当前作用域同名键覆盖父级键。
	func to_dictionary() -> Dictionary:
		var result: Dictionary = parent.to_dictionary() if parent != null else {}
		for key: Variant in values.keys():
			result[key] = GFVariantData.duplicate_variant(values[key])
		return result


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
	var _children: Array[BTNode]
	var _current_child_idx: int = 0

	func _init(children_nodes: Array[BTNode]) -> void:
		name = "Sequence"
		_children = _copy_child_nodes(children_nodes)


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

			var status_value: int = child.tick(blackboard)
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
	var _children: Array[BTNode]
	var _current_child_idx: int = 0

	func _init(children_nodes: Array[BTNode]) -> void:
		name = "Selector"
		_children = _copy_child_nodes(children_nodes)


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

			var status_value: int = child.tick(blackboard)
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
	var _children: Array[BTNode]
	var _child_statuses: Array[int] = []

	## 并行节点完成策略。
	## [br]
	## @api public
	var policy: ParallelPolicy = ParallelPolicy.REQUIRE_ALL

	func _init(
		children_nodes: Array[BTNode],
		completion_policy: ParallelPolicy = ParallelPolicy.REQUIRE_ALL
	) -> void:
		name = "Parallel"
		_children = _copy_child_nodes(children_nodes)
		policy = completion_policy


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
				var status_value: int = child.tick(blackboard)
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


	func _ensure_child_statuses() -> void:
		if _child_statuses.size() == _children.size():
			return
		_child_statuses.clear()
		for _index: int in range(_children.size()):
			_child_statuses.append(Status.RUNNING)


	func _get_debug_children() -> Array[BTNode]:
		return _children


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

	var _children: Array[BTNode]
	var _active_order: Array[BTNode] = []
	var _current_child_idx: int = 0

	func _init(children_nodes: Array[BTNode], random_source: RandomNumberGenerator = null) -> void:
		name = "RandomSelector"
		_children = _copy_child_nodes(children_nodes)
		rng = random_source


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

			var status_value: int = child.tick(blackboard)
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


	func _make_random_order(blackboard: Dictionary) -> Array[BTNode]:
		var result: Array[BTNode] = []
		result.append_array(_children)
		var active_rng: RandomNumberGenerator = _resolve_rng(blackboard)
		if active_rng == null:
			result.shuffle()
		else:
			_shuffle_with_rng(result, active_rng)
		return result


	func _resolve_rng(blackboard: Dictionary) -> RandomNumberGenerator:
		return GFBehaviorTree._resolve_rng_from_blackboard(blackboard, rng)


	func _shuffle_with_rng(nodes: Array[BTNode], random_source: RandomNumberGenerator) -> void:
		for index: int in range(nodes.size() - 1, 0, -1):
			var swap_index: int = random_source.randi_range(0, index)
			var temp: BTNode = nodes[index]
			nodes[index] = nodes[swap_index]
			nodes[swap_index] = temp


	func _duplicate_rng(source: RandomNumberGenerator) -> RandomNumberGenerator:
		return GFBehaviorTree._duplicate_rng(source)


	func _get_debug_children() -> Array[BTNode]:
		return _children


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

	var _children: Array[BTNode]
	var _active_order: Array[BTNode] = []
	var _current_child_idx: int = 0

	func _init(children_nodes: Array[BTNode], random_source: RandomNumberGenerator = null) -> void:
		name = "RandomSequence"
		_children = _copy_child_nodes(children_nodes)
		rng = random_source


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

			var status_value: int = child.tick(blackboard)
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


	func _make_random_order(blackboard: Dictionary) -> Array[BTNode]:
		var result: Array[BTNode] = []
		result.append_array(_children)
		var active_rng: RandomNumberGenerator = _resolve_rng(blackboard)
		if active_rng == null:
			result.shuffle()
		else:
			_shuffle_with_rng(result, active_rng)
		return result


	func _resolve_rng(blackboard: Dictionary) -> RandomNumberGenerator:
		return GFBehaviorTree._resolve_rng_from_blackboard(blackboard, rng)


	func _shuffle_with_rng(nodes: Array[BTNode], random_source: RandomNumberGenerator) -> void:
		for index: int in range(nodes.size() - 1, 0, -1):
			var swap_index: int = random_source.randi_range(0, index)
			var temp: BTNode = nodes[index]
			nodes[index] = nodes[swap_index]
			nodes[swap_index] = temp


	func _duplicate_rng(source: RandomNumberGenerator) -> RandomNumberGenerator:
		return GFBehaviorTree._duplicate_rng(source)


	func _get_debug_children() -> Array[BTNode]:
		return _children


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
	var _action_func: Callable

	func _init(action_func: Callable) -> void:
		name = "Action"
		_action_func = action_func


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
## 包装一个返回布尔值的回调。true 为 SUCCESS，false 为 FAILURE。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class Condition extends BTNode:
	var _condition_func: Callable

	func _init(condition_func: Callable) -> void:
		name = "Condition"
		_condition_func = condition_func


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
			return _record_tick(Status.FAILURE, &"condition_false", started)

		var condition_value: Variant = _condition_func.call(blackboard)
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
	var _child: BTNode

	func _init(child_node: BTNode = null) -> void:
		_child = null
		if child_node != null:
			var _set_child_result: Decorator = set_child(child_node)


	## 设置被装饰的子节点。
	## [br]
	## @api public
	## [br]
	## @param child_node: 子节点。
	## [br]
	## @return: 当前装饰器。
	func set_child(child_node: BTNode) -> Decorator:
		if _would_create_cycle(child_node):
			push_error("[GFBehaviorTree] 拒绝设置会形成循环的 decorator 子节点。")
			return self
		_child = child_node
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


	func _get_debug_children() -> Array[BTNode]:
		var result: Array[BTNode] = []
		if _child != null:
			result.append(_child)
		return result


	func _duplicate_child() -> BTNode:
		if _child == null:
			return null
		return _child.duplicate_runtime()


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
	func _init(child_node: BTNode) -> void:
		super(child_node)
		name = "Inverter"


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
		var status_value: int = _child.tick(blackboard)
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
	func _init(child_node: BTNode) -> void:
		super(child_node)
		name = "AlwaysSucceed"


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
		var status_value: int = _child.tick(blackboard)
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
	func _init(child_node: BTNode) -> void:
		super(child_node)
		name = "AlwaysFail"


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
		var status_value: int = _child.tick(blackboard)
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
	var _decision_made: bool = false
	var _allowed_this_run: bool = false

	func _init(child_node: BTNode, chance: float = 1.0, random_source: RandomNumberGenerator = null) -> void:
		super(child_node)
		name = "Probability"
		probability = clampf(chance, 0.0, 1.0)
		rng = random_source


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

		var status_value: int = _child.tick(blackboard)
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


	func _resolve_rng(blackboard: Dictionary) -> RandomNumberGenerator:
		return GFBehaviorTree._resolve_rng_from_blackboard(blackboard, rng)


	func _duplicate_rng(source: RandomNumberGenerator) -> RandomNumberGenerator:
		return GFBehaviorTree._duplicate_rng(source)


## 冷却装饰节点。
##
## 子节点结束后进入冷却期，冷却未结束时返回 FAILURE。
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
	var cooldown_seconds: float = 0.0
	var _last_finish_msec: int = -1

	func _init(child_node: BTNode, seconds: float = 0.0) -> void:
		super(child_node)
		name = "Cooldown"
		cooldown_seconds = maxf(seconds, 0.0)


	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；可提供 time_msec: int，其余字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null:
			return _record_tick(Status.FAILURE, &"missing_child", started)
		var now: int = _resolve_time_msec(blackboard)
		if _last_finish_msec >= 0 and now - _last_finish_msec < roundi(cooldown_seconds * 1000.0):
			return _record_tick(Status.FAILURE, &"cooldown_active", started)
		var status_value: int = _child.tick(blackboard)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if reason == &"" and (GFBehaviorTree._is_success(status) or GFBehaviorTree._is_failure(status)):
			_last_finish_msec = now
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
		var copy: Cooldown = Cooldown.new(_duplicate_child(), cooldown_seconds)
		_copy_base_fields_to(copy)
		return copy


	func _resolve_time_msec(blackboard: Dictionary) -> int:
		return GFVariantData.get_option_int(blackboard, "time_msec", Time.get_ticks_msec())


## 时间限制装饰节点。
##
## 子节点 RUNNING 持续超过限制时返回 FAILURE 并重置子节点。
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
	var limit_seconds: float = 1.0
	var _started_msec: int = -1

	func _init(child_node: BTNode, seconds: float = 1.0) -> void:
		super(child_node)
		name = "TimeLimit"
		limit_seconds = maxf(seconds, 0.0)


	## 推进运行时逻辑。
	## [br]
	## @api public
	## [br]
	## @param blackboard: 行为树本次 tick 使用的黑板数据。
	## [br]
	## @return: 返回 Status 枚举。
	## [br]
	## @schema blackboard: Dictionary 形式黑板；可提供 time_msec: int，其余字段由项目自定义。
	func tick(blackboard: Dictionary) -> int:
		var started: int = Time.get_ticks_usec()
		if _child == null:
			return _record_tick(Status.FAILURE, &"missing_child", started)
		var now: int = GFVariantData.get_option_int(blackboard, "time_msec", Time.get_ticks_msec())
		if _started_msec < 0:
			_started_msec = now
		if now - _started_msec > roundi(limit_seconds * 1000.0):
			reset()
			return _record_tick(Status.FAILURE, &"time_limit_exceeded", started)
		var status_value: int = _child.tick(blackboard)
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
		var copy: TimeLimit = TimeLimit.new(_duplicate_child(), limit_seconds)
		_copy_base_fields_to(copy)
		return copy


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
	var _tick_count: int = 0

	func _init(child_node: BTNode, tick_limit: int = 1) -> void:
		super(child_node)
		name = "Limit"
		max_ticks = maxi(tick_limit, 0)


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
		var status_value: int = _child.tick(blackboard)
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
	var _success_count: int = 0

	func _init(child_node: BTNode, count: int = 1) -> void:
		super(child_node)
		name = "Repeat"
		repeat_count = maxi(count, 0)


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

		var status_value: int = _child.tick(blackboard)
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
	func _init(child_node: BTNode) -> void:
		super(child_node)
		name = "UntilSuccess"


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
		var status_value: int = _child.tick(blackboard)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if reason == &"invalid_status" or GFBehaviorTree._is_aborted(status):
			reset()
			return _record_tick(status, reason, started)
		if GFBehaviorTree._is_success(status):
			reset()
			return _record_tick(Status.SUCCESS, &"", started)
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
	func _init(child_node: BTNode) -> void:
		super(child_node)
		name = "UntilFail"


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
		var status_value: int = _child.tick(blackboard)
		var status: int = GFBehaviorTree._variant_to_status(status_value)
		var reason: StringName = _get_child_status_reason(_child, status_value, status)
		if reason == &"invalid_status" or GFBehaviorTree._is_aborted(status):
			reset()
			return _record_tick(status, reason, started)
		if GFBehaviorTree._is_failure(status):
			reset()
			return _record_tick(Status.SUCCESS, &"", started)
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

	var _root_node: BTNode

	func _init(root: BTNode, duplicate_runtime_tree: bool = true) -> void:
		self.duplicates_runtime_tree = duplicate_runtime_tree
		_root_node = root.duplicate_runtime() if duplicate_runtime_tree and root != null else root


	## 驱动行为树运行逻辑。
	## 通常在 GFSystem 的 tick 中被调用。
	## [br]
	## @api public
	## [br]
	## @return: 返回根节点 Status 枚举。
	func tick() -> int:
		if _root_node == null:
			return Status.FAILURE
		return _root_node.tick(blackboard)


	## 重置整棵行为树的运行状态。
	## [br]
	## @api public
	func reset() -> void:
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
	## @return: 调试快照字典。
	## [br]
	## @schema return: 包含 root 和 blackboard_keys 字段的 Dictionary；root 为根节点调试快照，blackboard_keys 为排序后的黑板键列表。
	func get_debug_snapshot() -> Dictionary:
		return {
			"root": _root_node.get_debug_snapshot() if _root_node != null else {},
			"blackboard_keys": _get_blackboard_keys(),
		}


	func _get_blackboard_keys() -> PackedStringArray:
		var result: PackedStringArray = PackedStringArray()
		for key: Variant in blackboard.keys():
			var key_text: String = GFVariantData.to_text(key)
			var _key_appended: bool = result.append(key_text)
		result.sort()
		return result
