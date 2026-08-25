## GFObjectPoolUtility: 节点对象池管理器。
##
## 继承自 GFUtility，管理 Node 对象的实例化与回收，
## 避免高频 instance/free 操作带来的内存碎片和性能抖动。
## 适合管理大量同类对象，如子弹、敌人单位、特效粒子、棋盘方块等。
## 内部使用 Node metadata 键 _gf_pool_active 跟踪节点使用状态，
## 因此兼容任意 Node 子类型（无需 CanvasItem/visible 支持）。
##
## 工作流程：
##   1. 调用 acquire(scene, parent) 从池中取出一个可用节点（或自动实例化）。
##   2. 对节点进行配置使用。
##   3. 对象生命周期结束后，调用 release(node, scene) 将其归还至池中。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFObjectPoolUtility
extends GFUtility


# --- 枚举 ---

enum _NodeOwnershipPhase {
	ACTIVE,
	TRANSITION,
}

enum _TreeOperation {
	PREPARE,
	ACTIVATE,
	DEACTIVATE,
	ACQUIRE_HOOKS,
	RELEASE_HOOKS,
	INTERNAL_RELEASE_HOOK,
}

enum _GuardStatus {
	ABORT_OPERATION,
	STOP_NODE,
	CONTINUE,
}

enum _PrewarmMode {
	BATCH,
	BUDGET,
}

enum _PoolLifecycleTransition {
	NONE,
	INITIALIZE,
	DISPOSE,
}


# --- 常量 ---

# 用于标记节点当前是否被激活使用的 metadata 键。
const _META_ACTIVE: StringName = &"_gf_pool_active"

# 用于保存节点进入池前的 process_mode。
const _META_ORIGINAL_PROCESS_MODE: StringName = &"_gf_pool_original_process_mode"

# 用于保存 CanvasItem 进入池前的 visible 状态。
const _META_ORIGINAL_VISIBLE: StringName = &"_gf_pool_original_visible"

# 用于保存节点进入池前的 disabled 属性。
const _META_ORIGINAL_DISABLED: StringName = &"_gf_pool_original_disabled"

# 用于追踪节点原始所属的 PackedScene，避免错误 release 污染其他池。
const _META_SOURCE_SCENE: StringName = &"_gf_pool_source_scene"

## 节点可选实现：归还对象池前调用，用于清理 Tween、临时信号、运行时状态等。
## [br]
## @api public
const HOOK_ON_RELEASE: StringName = &"on_gf_pool_release"

## 节点可选实现：从对象池取出并恢复激活后调用，用于重置本次使用状态。
## [br]
## @api public
const HOOK_ON_ACQUIRE: StringName = &"on_gf_pool_acquire"

# 框架内部对象池归还钩子。用于让 GFController 等基础类型同步生命周期。
const _HOOK_INTERNAL_ON_RELEASE: StringName = &"_gf_on_object_pool_release"

# 框架内部对象池取出钩子。用于让 GFController 等基础类型同步生命周期。
const _HOOK_INTERNAL_ON_ACQUIRE: StringName = &"_gf_on_object_pool_acquire"

const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 公共变量 ---

## 每个 PackedScene 最多保留的可用节点数量。为 0 时不限制。
## [br]
## @api public
var max_available_per_scene: int = 0

## 是否递归管理子节点的 process_mode、visible 与 disabled 状态。
## [br]
## @api public
var manage_descendant_active_state: bool = true

## 是否在 acquire/release/count 等高频操作前立即清理失效节点。
## [br]
## @api public
var prune_invalid_on_each_operation: bool = true


# --- 私有变量 ---

# 对象池全量字典。Key 为 PackedScene 资源，Value 为该场景产生的所有节点数组。
# 仅用于销毁时统一释放。
var _all_nodes: Dictionary = {}

# 可用对象池字典。Key 为 PackedScene 资源，Value 为当前可用的节点栈。
var _available_pools: Dictionary = {}

# 每个 PackedScene 尚未提交的预热容量总账。
var _prewarm_reserved_counts: Dictionary = {}
var _active_prewarm_requests: Dictionary = {}
var _next_prewarm_request_id: int = 1
var _prewarm_request_id_mutex: Mutex = Mutex.new()
var _pool_lifecycle_transition: int = _PoolLifecycleTransition.NONE
var _queued_pool_lifecycle_transition: int = _PoolLifecycleTransition.NONE
var _active_generations: Dictionary = {}
var _active_lease_scenes: Dictionary = {}
var _active_lease_nodes: Dictionary = {}
var _transition_generations: Dictionary = {}
var _operation_generation: int = 0
var _lifecycle_serial: int = 0
var _pool_root: Node = null
var _is_disposed: bool = false


# --- GF 生命周期方法 ---

## 第一阶段初始化：清空内部池字典。
## [br]
## @api public
func init() -> void:
	_request_pool_lifecycle_transition(_PoolLifecycleTransition.INITIALIZE)


## 销毁阶段：释放所有池中的节点。
## [br]
## @api public
func dispose() -> void:
	_request_pool_lifecycle_transition(_PoolLifecycleTransition.DISPOSE)


# --- 公共方法 ---

## 从池中获取一个节点实例。若池为空则自动实例化并加入父节点。
## [br]
## @api public
## [br]
## @param scene: 要实例化的 PackedScene 资源。
## [br]
## @param parent: 借出的节点将加入或移动到此父节点；释放时会移动到内部池根节点。
## [br]
## @param before_add: 可选入树前回调，签名为 `func(node: Node) -> void`。
## [br]
## @return 可直接使用的节点实例。
## [br]
## @since 8.0.0
func acquire(scene: PackedScene, parent: Node, before_add: Callable = Callable()) -> Node:
	if _is_disposed:
		push_warning("[GFObjectPoolUtility] 对象池已销毁，忽略 acquire。")
		return null
	if not is_instance_valid(scene):
		push_error("[GFObjectPoolUtility] 传入了无效的 PackedScene。")
		return null
	if not _is_valid_acquire_parent(parent):
		push_error("[GFObjectPoolUtility] acquire 失败：parent 无效。")
		return null

	if not _available_pools.has(scene):
		_available_pools[scene] = []
		_all_nodes[scene] = []

	_prune_invalid_available_nodes_if_needed(scene)

	var current_serial: int = _lifecycle_serial
	var available_pool: Array = _get_available_pool(scene)

	while not available_pool.is_empty():
		var popped_item: Variant = available_pool.pop_back()
		var node: Node = _get_valid_pool_node(popped_item)
		if node != null:
			var node_id: int = node.get_instance_id()
			if _active_generations.has(node_id) or _transition_generations.has(node_id):
				continue
			var acquire_generation: int = _begin_node_acquire(node, scene)
			_call_before_add(before_add, node)
			if not _acquire_operation_matches(
				scene, parent, node, node_id, acquire_generation, current_serial
			):
				_cancel_or_discard_stale_acquire(node, scene, acquire_generation, current_serial)
				return null
			if not _run_guarded_tree_state_operation(
				node, true, node_id, _NodeOwnershipPhase.ACTIVE,
				acquire_generation, current_serial
			):
				_cancel_or_discard_stale_acquire(node, scene, acquire_generation, current_serial)
				return null

			if not _acquire_operation_matches(
				scene, parent, node, node_id, acquire_generation, current_serial
			):
				_cancel_or_discard_stale_acquire(node, scene, acquire_generation, current_serial)
				return null
			if node.get_parent() != parent:
				if node.get_parent() != null:
					node.reparent(parent, false)
				else:
					parent.add_child(node)
			if not _acquire_operation_matches(
				scene, parent, node, node_id, acquire_generation, current_serial
			) or node.get_parent() != parent:
				_cancel_or_discard_stale_acquire(node, scene, acquire_generation, current_serial)
				return null

			if not _run_guarded_tree_operation(
				node, _TreeOperation.ACQUIRE_HOOKS, node_id, _NodeOwnershipPhase.ACTIVE,
				acquire_generation, current_serial, parent
			):
				_cancel_or_discard_stale_acquire(node, scene, acquire_generation, current_serial)
				return null
			if not _acquire_operation_matches(
				scene, parent, node, node_id, acquire_generation, current_serial
			) or node.get_parent() != parent:
				_cancel_or_discard_stale_acquire(node, scene, acquire_generation, current_serial)
				return null
			return node

	var new_node: Node = _variant_to_node(scene.instantiate())
	if new_node == null:
		push_error("[GFObjectPoolUtility] PackedScene 未能实例化为 Node。")
		return null
	if not _is_acquire_context_valid(scene, parent, current_serial):
		_discard_pool_candidate(new_node)
		return null
	var new_node_id: int = new_node.get_instance_id()
	var new_acquire_generation: int = _begin_node_acquire(new_node, scene)
	var all_nodes: Array = _get_all_nodes_pool(scene)
	all_nodes.push_back(new_node)
	if not _run_guarded_tree_state_operation(
		new_node, true, new_node_id, _NodeOwnershipPhase.ACTIVE,
		new_acquire_generation, current_serial
	):
		_cancel_or_discard_stale_acquire(new_node, scene, new_acquire_generation, current_serial)
		return null
	if not _acquire_operation_matches(
		scene, parent, new_node, new_node_id, new_acquire_generation, current_serial
	):
		_cancel_or_discard_stale_acquire(new_node, scene, new_acquire_generation, current_serial)
		return null
	_call_before_add(before_add, new_node)
	if not _acquire_operation_matches(
		scene, parent, new_node, new_node_id, new_acquire_generation, current_serial
	):
		_cancel_or_discard_stale_acquire(new_node, scene, new_acquire_generation, current_serial)
		return null
	parent.add_child(new_node)
	if not _acquire_operation_matches(
		scene, parent, new_node, new_node_id, new_acquire_generation, current_serial
	) or new_node.get_parent() != parent:
		_cancel_or_discard_stale_acquire(new_node, scene, new_acquire_generation, current_serial)
		return null

	if not _run_guarded_tree_operation(
		new_node, _TreeOperation.ACQUIRE_HOOKS, new_node_id, _NodeOwnershipPhase.ACTIVE,
		new_acquire_generation, current_serial, parent
	):
		_cancel_or_discard_stale_acquire(new_node, scene, new_acquire_generation, current_serial)
		return null
	if not _acquire_operation_matches(
		scene, parent, new_node, new_node_id, new_acquire_generation, current_serial
	) or new_node.get_parent() != parent:
		_cancel_or_discard_stale_acquire(new_node, scene, new_acquire_generation, current_serial)
		return null
	return new_node


## 将节点归还到对象池，隐藏它以待下次复用。
## [br]
## @api public
## [br]
## @param node: 要归还的节点实例（必须由此工具创建）。
## [br]
## @param scene: 该节点所属的 PackedScene 资源，用于匹配正确的池。
func release(node: Node, scene: PackedScene) -> void:
	if _is_disposed:
		push_warning("[GFObjectPoolUtility] 对象池已销毁，忽略 release。")
		return
	if not is_instance_valid(node):
		return

	if node.has_meta(_META_ACTIVE) and not node.get_meta(_META_ACTIVE):
		return

	var owner_scene: PackedScene = _resolve_owner_scene(node, scene)
	if owner_scene == null:
		push_warning("[GFObjectPoolUtility] release 失败：节点未记录所属 PackedScene。")
		return

	if not _all_nodes.has(owner_scene) or not _get_all_nodes_pool(owner_scene).has(node):
		push_warning("[GFObjectPoolUtility] release 失败：节点不属于当前对象池。")
		return

	var node_id: int = node.get_instance_id()
	if not _active_generations.has(node_id):
		push_warning("[GFObjectPoolUtility] release 失败：节点不属于当前借用代次。")
		return

	var current_serial: int = _lifecycle_serial
	var release_generation: int = _take_operation_generation()
	_erase_active_lease(node_id)
	node.set_meta(_META_ACTIVE, false)
	_transition_generations[node_id] = release_generation
	if not _run_guarded_tree_operation(
		node,
		_TreeOperation.RELEASE_HOOKS,
		node_id,
		_NodeOwnershipPhase.TRANSITION,
		release_generation,
		current_serial
	):
		_discard_candidate_if_lifecycle_changed(node, current_serial)
		return
	if not _run_guarded_tree_state_operation(
		node, false, node_id, _NodeOwnershipPhase.TRANSITION,
		release_generation, current_serial
	):
		_discard_candidate_if_lifecycle_changed(node, current_serial)
		return

	if not _available_pools.has(owner_scene):
		_available_pools[owner_scene] = []

	_prune_invalid_available_nodes_if_needed(owner_scene)
	var available_pool: Array = _get_available_pool(owner_scene)
	if max_available_per_scene > 0 and available_pool.size() >= max_available_per_scene:
		var _capacity_transition_erased: bool = _transition_generations.erase(node_id)
		_remove_node_from_scene_pool(node, owner_scene)
		_queue_free_detached(node)
		return

	_move_to_pool_root(node)
	if not _node_operation_matches(
		node,
		node_id,
		_NodeOwnershipPhase.TRANSITION,
		release_generation,
		current_serial
	):
		_discard_candidate_if_lifecycle_changed(node, current_serial)
		return
	var _release_transition_erased: bool = _transition_generations.erase(node_id)
	available_pool.push_back(node)


## 预热对象池，预先实例化指定数量的节点以避免首次使用时的卡顿。
## [br]
## @api public
## [br]
## @param scene: 要预热的 PackedScene 资源。
## [br]
## @param parent: 预热节点将加入此父节点。
## [br]
## @param count: 预热的数量。
## [br]
## @param before_add: 可选入树前回调，签名为 `func(node: Node) -> void`。
## [br]
## @since 8.0.0
func prewarm(scene: PackedScene, parent: Node, count: int, before_add: Callable = Callable()) -> void:
	if _is_disposed:
		push_warning("[GFObjectPoolUtility] 对象池已销毁，忽略 prewarm。")
		return
	if not _ensure_scene_pool(scene):
		return
	if count <= 0:
		return

	var current_serial: int = _lifecycle_serial
	var reserved_remaining: int = _reserve_prewarm_capacity(scene, count)
	while reserved_remaining > 0:
		var node_created: bool = _prewarm_node(scene, parent, before_add, current_serial)
		_release_prewarm_capacity(scene, 1, current_serial)
		reserved_remaining -= 1
		if not node_created:
			break
	_release_prewarm_capacity(scene, reserved_remaining, current_serial)


## 分批预热对象池，避免一次性实例化大量节点造成单帧卡顿。
## [br]
## @api public
## [br]
## @param scene: 要预热的 PackedScene 资源。
## [br]
## @param parent: 预热节点将加入此父节点。
## [br]
## @param count: 预热的数量。
## [br]
## @param batch_size: 每帧最多实例化数量；小于等于 0 时退化为同步预热。
## [br]
## @param before_add: 可选入树前回调，签名为 `func(node: Node) -> void`。
## [br]
## @since 8.0.0
func prewarm_async(
	scene: PackedScene,
	parent: Node,
	count: int,
	batch_size: int = 32,
	before_add: Callable = Callable()
) -> void:
	if _is_disposed:
		push_warning("[GFObjectPoolUtility] 对象池已销毁，忽略 prewarm_async。")
		return
	if not is_instance_valid(scene):
		push_error("[GFObjectPoolUtility] 传入了无效的 PackedScene。")
		return
	if count <= 0:
		return
	var prepare_callback: Callable = func(node: Node) -> Error:
		_call_before_add(before_add, node)
		return OK
	var operation: GFObjectPoolPrewarmOperation = prewarm_request_async(
		scene,
		parent,
		count,
		batch_size,
		null,
		null,
		prepare_callback
	)
	if operation.is_pending():
		var _legacy_result: GFObjectPoolPrewarmResult = await operation.completed
	_report_legacy_prewarm_failure(operation.get_result())


## 按单帧时间预算预热对象池，适合复杂度差异较大的 PackedScene。
## [br]
## @api public
## [br]
## @param scene: 要预热的 PackedScene 资源。
## [br]
## @param parent: 预热节点将加入此父节点。
## [br]
## @param count: 预热的数量。
## [br]
## @param msec_budget_per_frame: 每帧实例化预算毫秒数；小于等于 0 时退化为同步预热。
## [br]
## @param before_add: 可选入树前回调，签名为 `func(node: Node) -> void`。
## [br]
## @since 8.0.0
func prewarm_async_budget(
	scene: PackedScene,
	parent: Node,
	count: int,
	msec_budget_per_frame: float = 8.0,
	before_add: Callable = Callable()
) -> void:
	if _is_disposed:
		push_warning("[GFObjectPoolUtility] 对象池已销毁，忽略 prewarm_async_budget。")
		return
	if not is_instance_valid(scene):
		push_error("[GFObjectPoolUtility] 传入了无效的 PackedScene。")
		return
	if count <= 0:
		return
	var prepare_callback: Callable = func(node: Node) -> Error:
		_call_before_add(before_add, node)
		return OK
	var operation: GFObjectPoolPrewarmOperation = prewarm_budget_request_async(
		scene,
		parent,
		count,
		msec_budget_per_frame,
		null,
		null,
		prepare_callback
	)
	if operation.is_pending():
		var _legacy_result: GFObjectPoolPrewarmResult = await operation.completed
	_report_legacy_prewarm_failure(operation.get_result())


## 创建一个按每帧批量驱动的 request-scoped 类型化预热请求。
## [br]
## 请求只释放自身尚未消费的容量 reservation；取消不会回滚已经提交的节点。
## `batch_size <= 0` 时保留旧 API 的同步退化语义。同步终态可能在方法返回前完成。
## 该入口只接受主线程调用；其他线程会同步返回 `INVALID/main_thread_required`，且不改变池状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param scene: 要预热的 PackedScene 资源。
## [br]
## @param parent: 可选挂载父节点；null 表示 detached prewarm。
## [br]
## @param count: 请求数量；0 立即完成，负数返回 INVALID。
## [br]
## @param batch_size: 每帧最多创建数量；小于等于 0 时同步执行。
## [br]
## @param owner: 可选请求生命周期 owner；Node 必须已在场景树中。
## [br]
## @param cancellation_token: 可选取消令牌或 GFAsyncScope。
## [br]
## @param prepare_callback: 可选 `func(node: Node) -> Error`；非 OK 终止请求。
## [br]
## @return 请求专属 Operation；调用方应先检查同步终态再连接 completed。
func prewarm_request_async(
	scene: PackedScene,
	parent: Node,
	count: int,
	batch_size: int = 32,
	owner: Object = null,
	cancellation_token: GFCancellationToken = null,
	prepare_callback: Callable = Callable()
) -> GFObjectPoolPrewarmOperation:
	return _begin_prewarm_request(
		scene,
		parent,
		count,
		_PrewarmMode.BATCH,
		batch_size,
		0.0,
		owner,
		cancellation_token,
		prepare_callback
	)


## 创建一个按每帧时间预算驱动的 request-scoped 类型化预热请求。
## [br]
## 请求只释放自身尚未消费的容量 reservation；取消不会回滚已经提交的节点。
## `msec_budget_per_frame <= 0` 时保留旧 API 的同步退化语义。
## 该入口只接受主线程调用；其他线程会同步返回 `INVALID/main_thread_required`，且不改变池状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param scene: 要预热的 PackedScene 资源。
## [br]
## @param parent: 可选挂载父节点；null 表示 detached prewarm。
## [br]
## @param count: 请求数量；0 立即完成，负数返回 INVALID。
## [br]
## @param msec_budget_per_frame: 每帧预算；小于等于 0 时同步执行。
## [br]
## @param owner: 可选请求生命周期 owner；Node 必须已在场景树中。
## [br]
## @param cancellation_token: 可选取消令牌或 GFAsyncScope。
## [br]
## @param prepare_callback: 可选 `func(node: Node) -> Error`；非 OK 终止请求。
## [br]
## @return 请求专属 Operation；调用方应先检查同步终态再连接 completed。
func prewarm_budget_request_async(
	scene: PackedScene,
	parent: Node,
	count: int,
	msec_budget_per_frame: float = 8.0,
	owner: Object = null,
	cancellation_token: GFCancellationToken = null,
	prepare_callback: Callable = Callable()
) -> GFObjectPoolPrewarmOperation:
	return _begin_prewarm_request(
		scene,
		parent,
		count,
		_PrewarmMode.BUDGET,
		0,
		msec_budget_per_frame,
		owner,
		cancellation_token,
		prepare_callback
	)


## 获取指定场景当前池中可用（未使用）的节点数量。
## [br]
## @api public
## [br]
## @param scene: 要查询的 PackedScene 资源。
## [br]
## @return 池中可用节点数量。
func get_available_count(scene: PackedScene) -> int:
	if not _available_pools.has(scene):
		return 0

	_prune_invalid_available_nodes_if_needed(scene)

	var count: int = 0
	for item: Variant in _available_pools[scene]:
		if _get_valid_pool_node(item) != null:
			count += 1
	return count


## 获取指定场景当前正在使用中的节点数量。
## [br]
## @api public
## [br]
## @param scene: 要查询的 PackedScene 资源。
## [br]
## @return 当前激活节点数量。
func get_active_count(scene: PackedScene) -> int:
	return get_active_nodes(scene).size()


## 获取指定场景当前正在使用中的节点列表。
## [br]
## @api public
## [br]
## @param scene: 要查询的 PackedScene 资源。
## [br]
## @return 当前激活节点数组。
func get_active_nodes(scene: PackedScene) -> Array[Node]:
	var result: Array[Node] = []
	if not _all_nodes.has(scene):
		return result

	for item: Variant in _get_all_nodes_pool(scene):
		var node: Node = _get_valid_pool_node(item)
		if node != null and GFVariantData.to_bool(node.get_meta(_META_ACTIVE, false)):
			result.append(node)
	return result


## 主动清理全部池中的失效节点引用。
## [br]
## @api public
func prune_invalid_nodes() -> void:
	for scene_key: Variant in _all_nodes.keys():
		var scene: PackedScene = _variant_to_packed_scene(scene_key)
		if scene == null:
			continue
		_prune_invalid_scene_nodes(scene)
	_prune_invalid_generations()


## 获取对象池诊断快照。
## [br]
## @api public
## [br]
## @return 以资源路径或实例 ID 为键的池状态字典。
## [br]
## @schema return: Dictionary[String, Dictionary] keyed by PackedScene resource path or instance id, with total, available, and active counts.
func get_debug_snapshot() -> Dictionary:
	prune_invalid_nodes()
	var snapshot: Dictionary = {}
	for scene_key: Variant in _all_nodes.keys():
		var scene: PackedScene = _variant_to_packed_scene(scene_key)
		if scene == null:
			continue
		var key: String = _get_scene_debug_key(scene)
		snapshot[key] = {
			"total": _get_all_nodes_pool(scene).size(),
			"available": get_available_count(scene),
			"active": get_active_count(scene),
		}
	return snapshot


# --- 框架内部方法 ---

## 仅在 scene 与 node 仍精确属于当前 ACTIVE lease 时执行归还。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param node: 待归还的 live 节点；若已排队删除，则仅同步退休精确 lease tracking。
## [br]
## @param scene: acquire 时冻结的 PackedScene identity。
## [br]
## @return: 当前 active generation 被本次调用接纳时返回 true；queued-live 节点不执行 hook 或树操作，仅移除精确 tracking；生命周期切换已清除 lease 或身份不匹配时返回 false 且零 mutation。
func release_for_framework(node: Node, scene: PackedScene) -> bool:
	if (
		_is_disposed
		or node == null
		or not is_instance_valid(node)
		or scene == null
		or not is_instance_valid(scene)
	):
		return false
	var node_id: int = node.get_instance_id()
	if (
		not _active_generations.has(node_id)
		or not _active_lease_scenes.has(node_id)
		or not _active_lease_nodes.has(node_id)
		or not _all_nodes.has(scene)
		or not _get_all_nodes_pool(scene).has(node)
	):
		return false
	var tracked_scene: PackedScene = _variant_to_packed_scene(
		_active_lease_scenes[node_id]
	)
	var tracked_node: Node = _variant_to_node(_active_lease_nodes[node_id])
	if tracked_scene != scene or tracked_node != node:
		return false
	if node.is_queued_for_deletion():
		return _retire_exact_active_lease_tracking(
			scene,
			node_id,
			tracked_node
		)
	release(node, scene)
	return true


## 结算已被外部同步销毁、无法再走 `release()` 的 ACTIVE lease。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param scene: acquire 时记录的同一 PackedScene identity。
## [br]
## @param instance_id: acquire 时记录的正 Object instance id。
## [br]
## @return: 仅当 scene 与 id 精确匹配当前 ACTIVE lease、且该 id 当前没有 live Object 时首次返回 true。
## [br]
## @schema return: bool；成功仅同步移除丢失 lease 的 active generation、scene/node owner linkage 与 scene tracked-node identity；不调用 hook、signal，不修改 SceneTree，重复或任一准入失败返回 false 且零 mutation。
func retire_lost_lease_for_framework(scene: PackedScene, instance_id: int) -> bool:
	if (
		_is_disposed
		or scene == null
		or not is_instance_valid(scene)
		or instance_id <= 0
		or not _active_generations.has(instance_id)
		or not _active_lease_scenes.has(instance_id)
		or not _active_lease_nodes.has(instance_id)
	):
		return false
	var tracked_scene_value: Variant = _active_lease_scenes[instance_id]
	if not tracked_scene_value is PackedScene:
		return false
	var tracked_scene: PackedScene = tracked_scene_value
	if not is_instance_valid(tracked_scene) or not is_same(tracked_scene, scene):
		return false
	var live_value: Object = instance_from_id(instance_id)
	if live_value != null and is_instance_valid(live_value):
		return false
	var tracked_node_value: Variant = _active_lease_nodes[instance_id]
	if typeof(tracked_node_value) != TYPE_OBJECT or is_instance_valid(tracked_node_value):
		return false
	return _retire_exact_active_lease_tracking(
		scene,
		instance_id,
		tracked_node_value
	)


# --- 私有/辅助方法 ---

func _request_pool_lifecycle_transition(transition: int) -> void:
	if transition not in [_PoolLifecycleTransition.INITIALIZE, _PoolLifecycleTransition.DISPOSE]:
		return
	if _pool_lifecycle_transition != _PoolLifecycleTransition.NONE:
		_queued_pool_lifecycle_transition = transition
		return
	var current_transition: int = transition
	while current_transition != _PoolLifecycleTransition.NONE:
		_pool_lifecycle_transition = current_transition
		_queued_pool_lifecycle_transition = _PoolLifecycleTransition.NONE
		_perform_pool_lifecycle_transition(current_transition)
		current_transition = _queued_pool_lifecycle_transition
	_pool_lifecycle_transition = _PoolLifecycleTransition.NONE
	_queued_pool_lifecycle_transition = _PoolLifecycleTransition.NONE


func _perform_pool_lifecycle_transition(transition: int) -> void:
	_is_disposed = true
	_finish_all_prewarm_requests()
	_lifecycle_serial += 1
	if transition == _PoolLifecycleTransition.DISPOSE:
		for scene_key: Variant in _all_nodes:
			var scene: PackedScene = _variant_to_packed_scene(scene_key)
			if scene == null:
				continue
			var pool: Array = _get_all_nodes_pool(scene)
			for node_variant: Variant in pool:
				var node: Node = _get_valid_pool_node(node_variant)
				if node != null:
					_queue_free_detached(node)
	if is_instance_valid(_pool_root):
		_queue_free_detached(_pool_root)
	_all_nodes.clear()
	_available_pools.clear()
	_prewarm_reserved_counts.clear()
	_active_prewarm_requests.clear()
	_active_generations.clear()
	_active_lease_scenes.clear()
	_active_lease_nodes.clear()
	_transition_generations.clear()
	_pool_root = null
	_is_disposed = transition == _PoolLifecycleTransition.DISPOSE


func _take_operation_generation() -> int:
	_operation_generation += 1
	return _operation_generation


func _begin_node_acquire(node: Node, scene: PackedScene) -> int:
	var generation: int = _take_operation_generation()
	var node_id: int = node.get_instance_id()
	node.set_meta(_META_ACTIVE, true)
	node.set_meta(_META_SOURCE_SCENE, scene)
	_active_generations[node_id] = generation
	_active_lease_scenes[node_id] = scene
	_active_lease_nodes[node_id] = node
	return generation


func _node_generation_matches(
	node: Node,
	node_id: int,
	generations: Dictionary,
	expected_generation: int,
	clear_active_lease: bool = false
) -> bool:
	if _get_valid_pool_node(node) == null:
		if clear_active_lease:
			_erase_active_lease(node_id)
		else:
			var _invalid_generation_erased: bool = generations.erase(node_id)
		return false
	if not generations.has(node_id):
		return false
	var generation_value: Variant = generations[node_id]
	if generation_value is int:
		var current_generation: int = generation_value
		return current_generation == expected_generation
	return false


func _node_operation_matches(
	owner_node: Node,
	owner_node_id: int,
	ownership_phase: int,
	expected_generation: int,
	expected_lifecycle_serial: int
) -> bool:
	if expected_lifecycle_serial != _lifecycle_serial:
		return false
	match ownership_phase:
		_NodeOwnershipPhase.ACTIVE:
			return _node_generation_matches(
				owner_node,
				owner_node_id,
				_active_generations,
				expected_generation,
				true
			)
		_NodeOwnershipPhase.TRANSITION:
			return _node_generation_matches(
				owner_node, owner_node_id, _transition_generations, expected_generation
			)
	return false


func _is_valid_acquire_parent(parent: Node) -> bool:
	return is_instance_valid(parent) and not parent.is_queued_for_deletion()


func _is_acquire_context_valid(
	scene: PackedScene,
	parent: Node,
	expected_lifecycle_serial: int
) -> bool:
	return (
		not _is_disposed
		and expected_lifecycle_serial == _lifecycle_serial
		and is_instance_valid(scene)
		and _is_valid_acquire_parent(parent)
		and _all_nodes.has(scene)
		and _available_pools.has(scene)
	)


func _acquire_operation_matches(
	scene: PackedScene,
	parent: Node,
	node: Node,
	node_id: int,
	expected_generation: int,
	expected_lifecycle_serial: int
) -> bool:
	return (
		_is_acquire_context_valid(scene, parent, expected_lifecycle_serial)
		and _node_operation_matches(
			node,
			node_id,
			_NodeOwnershipPhase.ACTIVE,
			expected_generation,
			expected_lifecycle_serial
		)
	)


func _guard_tree_node(
	node_value: Variant,
	owner_node: Node,
	owner_node_id: int,
	ownership_phase: int,
	expected_generation: int,
	expected_lifecycle_serial: int,
	expected_parent: Node = null
) -> int:
	if not _node_operation_matches(
		owner_node, owner_node_id, ownership_phase,
		expected_generation, expected_lifecycle_serial
	):
		return _GuardStatus.ABORT_OPERATION
	if expected_parent != null and (
		not _is_valid_acquire_parent(expected_parent)
		or owner_node.get_parent() != expected_parent
	):
		return _GuardStatus.ABORT_OPERATION
	var node: Node = _get_valid_pool_node(node_value)
	if node == null:
		return _GuardStatus.STOP_NODE
	if node != owner_node and not owner_node.is_ancestor_of(node):
		return _GuardStatus.STOP_NODE
	return _GuardStatus.CONTINUE


func _run_guarded_tree_operation(
	owner_node: Node,
	operation: int,
	owner_node_id: int,
	ownership_phase: int,
	expected_generation: int,
	expected_lifecycle_serial: int,
	expected_parent: Node = null
) -> bool:
	var pending_nodes: Array[Variant] = [owner_node]
	var visited_ids: Dictionary = {}
	while not pending_nodes.is_empty():
		var node_value: Variant = pending_nodes.pop_back()
		var guard_status: int = _guard_tree_node(
			node_value,
			owner_node,
			owner_node_id,
			ownership_phase,
			expected_generation,
			expected_lifecycle_serial,
			expected_parent
		)
		if guard_status == _GuardStatus.ABORT_OPERATION:
			return false
		if guard_status == _GuardStatus.STOP_NODE:
			continue
		var node: Node = _get_valid_pool_node(node_value)
		var node_id: int = node.get_instance_id()
		if visited_ids.has(node_id):
			continue
		visited_ids[node_id] = true

		guard_status = _apply_guarded_tree_node_operation(
			node,
			operation,
			owner_node,
			owner_node_id,
			ownership_phase,
			expected_generation,
			expected_lifecycle_serial,
			expected_parent
		)
		if guard_status == _GuardStatus.ABORT_OPERATION:
			return false
		if guard_status == _GuardStatus.STOP_NODE:
			continue
		if (
			(operation == _TreeOperation.ACTIVATE or operation == _TreeOperation.DEACTIVATE)
			and not manage_descendant_active_state
		):
			continue

		var children: Array[Node] = node.get_children(true)
		for child_index: int in range(children.size() - 1, -1, -1):
			pending_nodes.push_back(children[child_index])
	return _guard_tree_node(
		owner_node, owner_node, owner_node_id, ownership_phase,
		expected_generation, expected_lifecycle_serial, expected_parent
	) == _GuardStatus.CONTINUE


func _run_guarded_tree_state_operation(
	owner_node: Node,
	active: bool,
	owner_node_id: int,
	ownership_phase: int,
	expected_generation: int,
	expected_lifecycle_serial: int
) -> bool:
	if not _run_guarded_tree_operation(
		owner_node, _TreeOperation.PREPARE, owner_node_id, ownership_phase,
		expected_generation, expected_lifecycle_serial
	):
		return false
	return _run_guarded_tree_operation(
		owner_node, _TreeOperation.ACTIVATE if active else _TreeOperation.DEACTIVATE,
		owner_node_id, ownership_phase, expected_generation, expected_lifecycle_serial
	)


func _apply_guarded_tree_node_operation(
	node: Node,
	operation: int,
	owner_node: Node,
	owner_node_id: int,
	ownership_phase: int,
	expected_generation: int,
	expected_lifecycle_serial: int,
	expected_parent: Node
) -> int:
	match operation:
		_TreeOperation.ACQUIRE_HOOKS, _TreeOperation.RELEASE_HOOKS, _TreeOperation.INTERNAL_RELEASE_HOOK:
			return _run_guarded_node_hooks(
				node, operation, owner_node, owner_node_id,
				ownership_phase, expected_generation, expected_lifecycle_serial, expected_parent
			)
		_TreeOperation.PREPARE:
			return _prepare_guarded_node(
				node, owner_node, owner_node_id, ownership_phase,
				expected_generation, expected_lifecycle_serial
			)
		_TreeOperation.ACTIVATE, _TreeOperation.DEACTIVATE:
			return _set_guarded_node_active_state(
				node, operation == _TreeOperation.ACTIVATE, owner_node, owner_node_id,
				ownership_phase, expected_generation, expected_lifecycle_serial
			)
	return _GuardStatus.CONTINUE


func _set_guarded_node_active_state(
	node: Node,
	active: bool,
	owner_node: Node,
	owner_node_id: int,
	ownership_phase: int,
	expected_generation: int,
	expected_lifecycle_serial: int
) -> int:
	var guard_status: int = _prepare_guarded_node(
		node, owner_node, owner_node_id, ownership_phase,
		expected_generation, expected_lifecycle_serial
	)
	if guard_status != _GuardStatus.CONTINUE:
		return guard_status
	var process_mode: int = Node.PROCESS_MODE_DISABLED
	if active:
		process_mode = GFVariantData.to_int(
			node.get_meta(_META_ORIGINAL_PROCESS_MODE, Node.PROCESS_MODE_INHERIT),
			Node.PROCESS_MODE_INHERIT
		)
	node.process_mode = _to_process_mode(process_mode)
	guard_status = _guard_tree_node(
		node, owner_node, owner_node_id, ownership_phase,
		expected_generation, expected_lifecycle_serial
	)
	if guard_status != _GuardStatus.CONTINUE:
		return guard_status

	var canvas_item: CanvasItem = _variant_to_canvas_item(node)
	if canvas_item != null:
		canvas_item.visible = (
			GFVariantData.to_bool(node.get_meta(_META_ORIGINAL_VISIBLE, true), true)
			if active
			else false
		)
		guard_status = _guard_tree_node(
			node, owner_node, owner_node_id, ownership_phase,
			expected_generation, expected_lifecycle_serial
		)
		if guard_status != _GuardStatus.CONTINUE:
			return guard_status

	if "disabled" in node:
		node.set("disabled", node.get_meta(_META_ORIGINAL_DISABLED) if active else true)
		return _guard_tree_node(
			node, owner_node, owner_node_id, ownership_phase,
			expected_generation, expected_lifecycle_serial
		)
	return _GuardStatus.CONTINUE


func _prepare_guarded_node(
	node: Node,
	owner_node: Node,
	owner_node_id: int,
	ownership_phase: int,
	expected_generation: int,
	expected_lifecycle_serial: int
) -> int:
	if not node.has_meta(_META_ORIGINAL_PROCESS_MODE):
		node.set_meta(_META_ORIGINAL_PROCESS_MODE, node.process_mode)
	var canvas_item: CanvasItem = _variant_to_canvas_item(node)
	if canvas_item != null and not node.has_meta(_META_ORIGINAL_VISIBLE):
		node.set_meta(_META_ORIGINAL_VISIBLE, canvas_item.visible)
	if "disabled" in node and not node.has_meta(_META_ORIGINAL_DISABLED):
		var original_disabled: Variant = GFObjectPropertyTools.read_property(
			node,
			NodePath("disabled")
		)
		var guard_status: int = _guard_tree_node(
			node, owner_node, owner_node_id, ownership_phase,
			expected_generation, expected_lifecycle_serial
		)
		if guard_status != _GuardStatus.CONTINUE:
			return guard_status
		node.set_meta(_META_ORIGINAL_DISABLED, original_disabled)
	return _GuardStatus.CONTINUE


func _run_guarded_node_hooks(
	node: Node,
	operation: int,
	owner_node: Node,
	owner_node_id: int,
	ownership_phase: int,
	expected_generation: int,
	expected_lifecycle_serial: int,
	expected_parent: Node
) -> int:
	var guard_status: int = _GuardStatus.CONTINUE
	if operation == _TreeOperation.ACQUIRE_HOOKS:
		guard_status = _call_guarded_node_hook(
			node, _HOOK_INTERNAL_ON_ACQUIRE, owner_node, owner_node_id,
			ownership_phase, expected_generation, expected_lifecycle_serial, expected_parent
		)
		if guard_status != _GuardStatus.CONTINUE:
			return guard_status
		return _call_guarded_node_hook(
			node, HOOK_ON_ACQUIRE, owner_node, owner_node_id,
			ownership_phase, expected_generation, expected_lifecycle_serial, expected_parent
		)
	if operation == _TreeOperation.RELEASE_HOOKS:
		guard_status = _call_guarded_node_hook(
			node, HOOK_ON_RELEASE, owner_node, owner_node_id,
			ownership_phase, expected_generation, expected_lifecycle_serial, expected_parent
		)
		if guard_status != _GuardStatus.CONTINUE:
			return guard_status
	return _call_guarded_node_hook(
		node, _HOOK_INTERNAL_ON_RELEASE, owner_node, owner_node_id,
		ownership_phase, expected_generation, expected_lifecycle_serial, expected_parent
	)


func _call_guarded_node_hook(
	node: Node,
	hook_name: StringName,
	owner_node: Node,
	owner_node_id: int,
	ownership_phase: int,
	expected_generation: int,
	expected_lifecycle_serial: int,
	expected_parent: Node
) -> int:
	if not node.has_method(hook_name):
		return _GuardStatus.CONTINUE
	var _hook_result: Variant = node.call(hook_name)
	return _guard_tree_node(
		node, owner_node, owner_node_id, ownership_phase,
		expected_generation, expected_lifecycle_serial, expected_parent
	)


func _cancel_or_discard_stale_acquire(
	node: Node,
	scene: PackedScene,
	expected_generation: int,
	expected_lifecycle_serial: int
) -> void:
	if expected_lifecycle_serial != _lifecycle_serial:
		_discard_pool_candidate(node)
		return
	if not is_instance_valid(node):
		return
	var node_id: int = node.get_instance_id()
	if not _node_generation_matches(
		node,
		node_id,
		_active_generations,
		expected_generation,
		true
	):
		return
	release(node, scene)
	if expected_lifecycle_serial != _lifecycle_serial:
		_discard_pool_candidate(node)


func _discard_candidate_if_lifecycle_changed(
	node: Node,
	expected_lifecycle_serial: int
) -> void:
	if expected_lifecycle_serial != _lifecycle_serial:
		_discard_pool_candidate(node)


func _ensure_scene_pool(scene: PackedScene) -> bool:
	if not is_instance_valid(scene):
		push_error("[GFObjectPoolUtility] 传入了无效的 PackedScene。")
		return false

	if not _available_pools.has(scene):
		_available_pools[scene] = []
		_all_nodes[scene] = []

	_prune_invalid_available_nodes_if_needed(scene)
	return true


func _begin_prewarm_request(
	scene: PackedScene,
	parent: Node,
	count: int,
	mode: int,
	batch_size: int,
	budget_msec: float,
	owner: Object,
	cancellation_token: GFCancellationToken,
	prepare_callback: Callable
) -> GFObjectPoolPrewarmOperation:
	var request_id: int = _take_prewarm_request_id()
	var requested_count: int = maxi(count, 0)
	var operation: GFObjectPoolPrewarmOperation = GFObjectPoolPrewarmOperation.new()
	if not Thread.is_main_thread():
		var _worker_configured: bool = operation.configure_terminal_for_framework(
			request_id,
			requested_count,
			GFObjectPoolPrewarmResult.Status.INVALID,
			GFObjectPoolPrewarmResult.REASON_MAIN_THREAD_REQUIRED,
			ERR_INVALID_PARAMETER
		)
		return operation
	var cancel_delegate: Callable = _make_rejecting_prewarm_cancel_delegate()
	if _is_disposed or _pool_lifecycle_transition != _PoolLifecycleTransition.NONE:
		var disposed_reason: StringName = GFObjectPoolPrewarmResult.REASON_UTILITY_DISPOSED
		if _pool_lifecycle_transition == _PoolLifecycleTransition.INITIALIZE:
			disposed_reason = GFObjectPoolPrewarmResult.REASON_UTILITY_REINITIALIZED
		_configure_and_finish_prewarm_operation(
			operation,
			cancel_delegate,
			request_id,
			scene,
			requested_count,
			0,
			GFObjectPoolPrewarmResult.Status.DISPOSED,
			disposed_reason,
			ERR_UNAVAILABLE
		)
		return operation
	if count < 0:
		_configure_and_finish_prewarm_operation(
			operation,
			cancel_delegate,
			request_id,
			scene,
			0,
			0,
			GFObjectPoolPrewarmResult.Status.INVALID,
			GFObjectPoolPrewarmResult.REASON_INVALID_COUNT,
			ERR_INVALID_PARAMETER
		)
		return operation
	var validation_reason: StringName = _get_prewarm_request_validation_reason(
		scene,
		parent,
		owner,
		prepare_callback
	)
	if not validation_reason.is_empty():
		_configure_and_finish_prewarm_operation(
			operation,
			cancel_delegate,
			request_id,
			scene,
			requested_count,
			0,
			GFObjectPoolPrewarmResult.Status.INVALID,
			validation_reason,
			ERR_INVALID_PARAMETER
		)
		return operation
	if count == 0:
		_configure_and_finish_prewarm_operation(
			operation,
			cancel_delegate,
			request_id,
			scene,
			0,
			0,
			GFObjectPoolPrewarmResult.Status.COMPLETED,
			GFObjectPoolPrewarmResult.REASON_COMPLETED,
			OK
		)
		return operation
	if _token_is_cancelled_or_completed(cancellation_token):
		var token_reason: StringName = _get_prewarm_token_terminal_reason(
			cancellation_token
		)
		_configure_and_finish_prewarm_operation(
			operation,
			cancel_delegate,
			request_id,
			scene,
			requested_count,
			requested_count,
			GFObjectPoolPrewarmResult.Status.CANCELLED,
			token_reason,
			ERR_SKIP
		)
		return operation
	var _scene_pool_ready: bool = _ensure_scene_pool(scene)
	var admitted_count: int = _reserve_prewarm_capacity(scene, requested_count)
	var settlement_authority: Callable = _make_prewarm_settlement_authority()
	var settlement_validator: Callable = _make_prewarm_settlement_validator(
		settlement_authority
	)
	cancel_delegate = _make_prewarm_cancel_delegate(settlement_authority)
	var configured: bool = operation.configure_for_framework(
		cancel_delegate,
		settlement_validator,
		request_id,
		scene,
		requested_count,
		admitted_count
	)
	if not configured:
		_release_prewarm_capacity(scene, admitted_count, _lifecycle_serial)
		return operation
	if admitted_count == 0:
		var _rejected: bool = operation.finish_for_framework(
			settlement_authority,
			GFObjectPoolPrewarmResult.Status.REJECTED,
			GFObjectPoolPrewarmResult.REASON_CAPACITY_UNAVAILABLE,
			ERR_BUSY
		)
		return operation
	var entry: Dictionary = _make_prewarm_request_entry(
		request_id,
		operation,
		scene,
		parent,
		owner,
		cancellation_token,
		prepare_callback,
		mode,
		batch_size,
		budget_msec,
		admitted_count
	)
	entry["lifecycle_callback"] = _make_prewarm_lifecycle_callback(
		request_id,
		operation,
		GFVariantData.get_option_int(entry, "lifecycle_serial"),
		settlement_authority
	)
	_active_prewarm_requests[request_id] = entry
	if not _bind_prewarm_request_anchors(entry, settlement_authority):
		var _binding_failed: bool = _finish_prewarm_request(
			request_id,
			operation,
			GFObjectPoolPrewarmResult.Status.FAILED,
			GFObjectPoolPrewarmResult.REASON_INTERNAL_FAILURE,
			FAILED,
			settlement_authority
		)
		return operation
	if not _poll_prewarm_request(request_id, operation, settlement_authority):
		return operation
	@warning_ignore("missing_await")
	_drive_prewarm_request(request_id, operation, settlement_authority)
	return operation


func _get_prewarm_request_validation_reason(
	scene: PackedScene,
	parent: Node,
	owner: Object,
	prepare_callback: Callable
) -> StringName:
	if not is_instance_valid(scene):
		return GFObjectPoolPrewarmResult.REASON_INVALID_SCENE
	if parent != null and (not is_instance_valid(parent) or parent.is_queued_for_deletion()):
		return GFObjectPoolPrewarmResult.REASON_INVALID_PARENT
	if owner != null:
		if not is_instance_valid(owner):
			return GFObjectPoolPrewarmResult.REASON_INVALID_OWNER
		if owner is Node:
			var owner_node: Node = owner
			if not owner_node.is_inside_tree():
				return GFObjectPoolPrewarmResult.REASON_INVALID_OWNER
	if not prepare_callback.is_null() and not prepare_callback.is_valid():
		return GFObjectPoolPrewarmResult.REASON_INVALID_PREPARE_CALLBACK
	return &""


func _configure_and_finish_prewarm_operation(
	operation: GFObjectPoolPrewarmOperation,
	cancel_delegate: Callable,
	request_id: int,
	scene: PackedScene,
	requested_count: int,
	admitted_count: int,
	status: GFObjectPoolPrewarmResult.Status,
	reason: StringName,
	error_code: Error
) -> void:
	var settlement_authority: Callable = _make_prewarm_settlement_authority()
	var settlement_validator: Callable = _make_prewarm_settlement_validator(
		settlement_authority
	)
	if not operation.configure_for_framework(
		cancel_delegate,
		settlement_validator,
		request_id,
		scene,
		requested_count,
		admitted_count
	):
		return
	var _finished: bool = operation.finish_for_framework(
		settlement_authority,
		status,
		reason,
		error_code
	)


func _make_prewarm_cancel_delegate(settlement_authority: Callable) -> Callable:
	var utility_instance_id: int = get_instance_id()
	return func(
		current: GFObjectPoolPrewarmOperation,
		reason: StringName,
	) -> bool:
		var utility_value: Variant = instance_from_id(utility_instance_id)
		if not (utility_value is Object):
			return false
		var utility: Object = utility_value
		if not is_instance_valid(utility):
			return false
		var raw_result: Variant = utility.call(
			&"_cancel_prewarm_operation",
			current,
			reason,
			settlement_authority
		)
		return raw_result is bool and raw_result


static func _make_rejecting_prewarm_cancel_delegate() -> Callable:
	return func(
		_current: GFObjectPoolPrewarmOperation,
		_reason: StringName,
	) -> bool:
		return false


func _make_prewarm_lifecycle_callback(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	expected_lifecycle_serial: int,
	settlement_authority: Callable
) -> Callable:
	var utility_instance_id: int = get_instance_id()
	return func() -> bool:
		var utility_value: Variant = instance_from_id(utility_instance_id)
		if not (utility_value is Object):
			return false
		var utility: Object = utility_value
		if not is_instance_valid(utility):
			return false
		var raw_result: Variant = utility.call(
			&"_finish_prewarm_request_for_lifecycle",
			request_id,
			operation,
			expected_lifecycle_serial,
			settlement_authority
		)
		return raw_result is bool and raw_result


static func _make_prewarm_settlement_authority() -> Callable:
	return func() -> void:
		pass


static func _make_prewarm_settlement_validator(authority: Callable) -> Callable:
	return func(candidate: Callable) -> bool:
		return candidate == authority


func _make_prewarm_request_entry(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	scene: PackedScene,
	parent: Node,
	owner: Object,
	cancellation_token: GFCancellationToken,
	prepare_callback: Callable,
	mode: int,
	batch_size: int,
	budget_msec: float,
	admitted_count: int
) -> Dictionary:
	return {
		"request_id": request_id,
		"operation": operation,
		"scene": scene,
		"parent_ref": weakref(parent) if parent != null else null,
		"parent_id": parent.get_instance_id() if parent != null else 0,
		"parent_lifetime": null,
		"parent_lifetime_check": Callable(),
		"parent_tree_entered_callback": Callable(),
		"owner_ref": weakref(owner) if owner != null else null,
		"owner_id": owner.get_instance_id() if owner != null else 0,
		"owner_lifetime": null,
		"owner_lifetime_check": Callable(),
		"cancellation_token": cancellation_token,
		"token_callback": Callable(),
		"prepare_callback": prepare_callback,
		"mode": mode,
		"batch_size": batch_size,
		"budget_msec": budget_msec,
		"lifecycle_serial": _lifecycle_serial,
		"reserved_remaining": admitted_count,
	}


func _bind_prewarm_request_anchors(
	entry: Dictionary,
	settlement_authority: Callable
) -> bool:
	var request_id: int = GFVariantData.get_option_int(entry, "request_id")
	var operation: GFObjectPoolPrewarmOperation = _entry_prewarm_operation(entry)
	if operation == null:
		return false
	var owner: Object = _entry_weak_object(entry, "owner_ref", "owner_id")
	if GFVariantData.get_option_int(entry, "owner_id") != 0:
		if owner == null:
			return false
		var owner_callbacks: Dictionary = _make_prewarm_lifetime_callbacks(owner, true)
		var owner_check: Callable = _entry_callable(owner_callbacks, "check")
		entry["owner_lifetime_check"] = owner_check
		entry["owner_lifetime"] = _make_prewarm_lifetime_subscription(
			owner,
			request_id,
			operation,
			GFObjectPoolPrewarmResult.REASON_OWNER_RELEASED,
			"object_pool_prewarm_owner:%d" % request_id,
			owner_check,
			settlement_authority
		)
	var parent: Object = _entry_weak_object(entry, "parent_ref", "parent_id")
	if GFVariantData.get_option_int(entry, "parent_id") != 0:
		if parent == null:
			return false
		var parent_callbacks: Dictionary = _make_prewarm_lifetime_callbacks(parent, false)
		var parent_check: Callable = _entry_callable(parent_callbacks, "check")
		var parent_entered: Callable = _entry_callable(parent_callbacks, "entered")
		entry["parent_lifetime_check"] = parent_check
		if parent is Node:
			var parent_node: Node = parent
			entry["parent_tree_entered_callback"] = parent_entered
			if not parent_node.tree_entered.is_connected(parent_entered):
				var tree_entered_error: Error = parent_node.tree_entered.connect(
					parent_entered
				) as Error
				if tree_entered_error != OK:
					return false
		entry["parent_lifetime"] = _make_prewarm_lifetime_subscription(
			parent,
			request_id,
			operation,
			GFObjectPoolPrewarmResult.REASON_PARENT_RELEASED,
			"object_pool_prewarm_parent:%d" % request_id,
			parent_check,
			settlement_authority
		)
	var cancellation_token: GFCancellationToken = _entry_cancellation_token(entry)
	if cancellation_token != null:
		var token_callback: Callable = _make_prewarm_token_callback(
			request_id,
			operation,
			cancellation_token,
			settlement_authority
		)
		entry["token_callback"] = token_callback
		var connect_error: Error = cancellation_token.cancel_requested.connect(
			token_callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error
		if connect_error != OK:
			return false
	return true


func _make_prewarm_lifetime_subscription(
	owner: Object,
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	reason: StringName,
	debug_label: String,
	lifetime_check: Callable,
	settlement_authority: Callable
) -> GFLifetimeSubscription:
	var utility_instance_id: int = get_instance_id()
	var anchor_instance_id: int = owner.get_instance_id()
	var callback: Callable = func() -> void:
		var utility_value: Variant = instance_from_id(utility_instance_id)
		if not (utility_value is Object):
			return
		var utility: Object = utility_value
		if not is_instance_valid(utility):
			return
		var _invoke_result: Variant = utility.call(
			&"_on_prewarm_lifetime_released",
			request_id,
			operation,
			reason,
			anchor_instance_id,
			lifetime_check,
			settlement_authority
		)
	return GFLifetimeSubscription.new(owner, callback, debug_label)


func _make_prewarm_token_callback(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	cancellation_token: GFCancellationToken,
	settlement_authority: Callable
) -> Callable:
	var utility_instance_id: int = get_instance_id()
	var token_ref: WeakRef = weakref(cancellation_token)
	var token_instance_id: int = cancellation_token.get_instance_id()
	return func(_reason: StringName) -> void:
		var utility_value: Variant = instance_from_id(utility_instance_id)
		if not (utility_value is Object):
			return
		var utility: Object = utility_value
		if not is_instance_valid(utility):
			return
		var _invoke_result: Variant = utility.call(
			&"_on_prewarm_token_cancelled",
			request_id,
			operation,
			token_ref,
			token_instance_id,
			settlement_authority
		)


static func _make_prewarm_lifetime_callbacks(
	anchor: Object,
	require_inside_tree: bool
) -> Dictionary:
	var anchor_ref: WeakRef = weakref(anchor)
	var anchor_instance_id: int = anchor.get_instance_id()
	var initially_inside_tree: bool = false
	if anchor is Node:
		var initial_node: Node = anchor
		initially_inside_tree = initial_node.is_inside_tree()
	var seen_inside_tree: Array[bool] = [initially_inside_tree]
	var entered: Callable = func() -> void:
		var raw_anchor: Variant = anchor_ref.get_ref()
		if not (raw_anchor is Node):
			return
		var anchor_node: Node = raw_anchor
		if (
			is_instance_valid(anchor_node)
			and anchor_node.get_instance_id() == anchor_instance_id
			and anchor_node.is_inside_tree()
		):
			seen_inside_tree[0] = true
	var check: Callable = func() -> bool:
		var raw_anchor: Variant = anchor_ref.get_ref()
		if not (raw_anchor is Object):
			return true
		var current_anchor: Object = raw_anchor
		if (
			not is_instance_valid(current_anchor)
			or current_anchor.get_instance_id() != anchor_instance_id
		):
			return true
		if not (current_anchor is Node):
			return false
		var anchor_node: Node = current_anchor
		if anchor_node.is_queued_for_deletion():
			return true
		if anchor_node.is_inside_tree():
			seen_inside_tree[0] = true
			return false
		return require_inside_tree or seen_inside_tree[0]
	return {"check": check, "entered": entered}


func _drive_prewarm_request(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	settlement_authority: Callable
) -> void:
	var scene_tree: SceneTree = _get_scene_tree()
	var frame_attempt_count: int = 0
	var frame_start_usec: int = Time.get_ticks_usec()
	while _poll_prewarm_request(request_id, operation, settlement_authority):
		var entry: Dictionary = _get_prewarm_request_entry(request_id, operation)
		if entry.is_empty():
			return
		if GFVariantData.get_option_int(entry, "reserved_remaining") <= 0:
			var _completed_without_attempt: bool = _finish_completed_prewarm_request(
				request_id,
				operation,
				settlement_authority
			)
			return
		var barrier_began: bool = operation.begin_settlement_barrier_for_framework(
			settlement_authority
		)
		if not barrier_began:
			var _barrier_failed: bool = _finish_prewarm_request(
				request_id,
				operation,
				GFObjectPoolPrewarmResult.Status.FAILED,
				GFObjectPoolPrewarmResult.REASON_INTERNAL_FAILURE,
				FAILED,
				settlement_authority
			)
			return
		var attempt: Dictionary = _prewarm_request_node_attempt(
			request_id,
			operation,
			settlement_authority
		)
		var _barrier_ended: bool = operation.end_settlement_barrier_for_framework(
			settlement_authority
		)
		if not _prewarm_request_is_active(request_id, operation):
			return
		if GFVariantData.get_option_bool(attempt, "capacity_limited"):
			entry = _get_prewarm_request_entry(request_id, operation)
			if entry.is_empty():
				return
			_release_request_prewarm_capacity(
				entry,
				GFVariantData.get_option_int(entry, "reserved_remaining")
			)
			var capacity_recorded: bool = operation.record_capacity_skipped_for_framework(
				settlement_authority
			)
			if not capacity_recorded:
				var _capacity_record_failed: bool = _finish_prewarm_request(
					request_id,
					operation,
					GFObjectPoolPrewarmResult.Status.FAILED,
					GFObjectPoolPrewarmResult.REASON_INTERNAL_FAILURE,
					FAILED,
					settlement_authority
				)
				return
			if _prewarm_request_is_active(request_id, operation):
				var _capacity_completed: bool = _finish_completed_prewarm_request(
					request_id,
					operation,
					settlement_authority
				)
			return
		if not GFVariantData.get_option_bool(attempt, "ok"):
			if not _poll_prewarm_request(request_id, operation, settlement_authority):
				return
			var _attempt_failed: bool = _finish_prewarm_request(
				request_id,
				operation,
				GFObjectPoolPrewarmResult.Status.FAILED,
				GFVariantData.get_option_string_name(
					attempt,
					"reason",
					GFObjectPoolPrewarmResult.REASON_INTERNAL_FAILURE
				),
				GFVariantData.get_option_int(attempt, "error_code", FAILED) as Error,
				settlement_authority
			)
			return
		entry = _get_prewarm_request_entry(request_id, operation)
		if entry.is_empty():
			return
		_release_request_prewarm_capacity(entry, 1)
		var created_recorded: bool = operation.record_created_for_framework(
			settlement_authority
		)
		if not created_recorded:
			var _record_failed: bool = _finish_prewarm_request(
				request_id,
				operation,
				GFObjectPoolPrewarmResult.Status.FAILED,
				GFObjectPoolPrewarmResult.REASON_INTERNAL_FAILURE,
				FAILED,
				settlement_authority
			)
			return
		if not _prewarm_request_is_active(request_id, operation):
			return
		frame_attempt_count += 1
		if not _prewarm_request_should_await(entry, frame_attempt_count, frame_start_usec):
			continue
		if scene_tree == null:
			continue
		await scene_tree.process_frame
		frame_attempt_count = 0
		frame_start_usec = Time.get_ticks_usec()
	var _completed_after_driver: bool = _finish_completed_prewarm_request(
		request_id,
		operation,
		settlement_authority
	)


func _prewarm_request_should_await(
	entry: Dictionary,
	frame_attempt_count: int,
	frame_start_usec: int
) -> bool:
	var mode: int = GFVariantData.get_option_int(entry, "mode", _PrewarmMode.BATCH)
	if mode == _PrewarmMode.BATCH:
		var batch_size: int = GFVariantData.get_option_int(entry, "batch_size")
		return batch_size > 0 and frame_attempt_count >= batch_size
	var budget_msec: float = GFVariantData.get_option_float(entry, "budget_msec")
	if budget_msec <= 0.0:
		return false
	var elapsed_msec: float = float(Time.get_ticks_usec() - frame_start_usec) / 1000.0
	return frame_attempt_count > 0 and elapsed_msec >= budget_msec


func _prewarm_request_node_attempt(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	settlement_authority: Callable
) -> Dictionary:
	var entry: Dictionary = _get_prewarm_request_entry(request_id, operation)
	var scene: PackedScene = _entry_prewarm_scene(entry)
	var parent: Node = _entry_prewarm_parent(entry)
	var current_serial: int = GFVariantData.get_option_int(entry, "lifecycle_serial")
	if entry.is_empty() or scene == null:
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_CANDIDATE_INVALIDATED,
			ERR_UNAVAILABLE
		)
	var node: Node = _variant_to_node(scene.instantiate())
	if node == null:
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_SCENE_INSTANTIATION_FAILED,
			ERR_CANT_CREATE
		)
	if _prewarm_request_capacity_is_saturated(scene):
		_discard_pool_candidate(node)
		return {"capacity_limited": true}
	if not _prewarm_request_candidate_context_is_valid(
		request_id,
		operation,
		settlement_authority,
		scene,
		parent,
		node,
		current_serial
	):
		_discard_pool_candidate(node)
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_CANDIDATE_INVALIDATED,
			ERR_UNAVAILABLE
		)
	var node_id: int = node.get_instance_id()
	var transition_generation: int = _take_operation_generation()
	node.set_meta(_META_ACTIVE, false)
	node.set_meta(_META_SOURCE_SCENE, scene)
	_transition_generations[node_id] = transition_generation
	_get_all_nodes_pool(scene).push_back(node)
	if not _run_guarded_tree_state_operation(
		node,
		false,
		node_id,
		_NodeOwnershipPhase.TRANSITION,
		transition_generation,
		current_serial
	):
		_discard_tracked_pool_candidate(node, scene)
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_CANDIDATE_INVALIDATED,
			ERR_UNAVAILABLE
		)
	var prepare_outcome: Dictionary = _run_prewarm_prepare_callback(entry, node)
	if not _prewarm_request_is_active(request_id, operation):
		_discard_tracked_pool_candidate(node, scene)
		return {"settled": true}
	if not GFVariantData.get_option_bool(prepare_outcome, "ok"):
		_discard_tracked_pool_candidate(node, scene)
		return prepare_outcome
	if _prewarm_request_capacity_is_saturated(scene):
		_discard_tracked_pool_candidate(node, scene)
		return {"capacity_limited": true}
	if not _typed_prewarm_operation_matches(
		request_id,
		operation,
		settlement_authority,
		scene,
		parent,
		node,
		node_id,
		transition_generation,
		current_serial
	) or node.get_parent() != null:
		_discard_tracked_pool_candidate(node, scene)
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_CANDIDATE_INVALIDATED,
			ERR_UNAVAILABLE
		)
	if parent != null:
		parent.add_child(node)
	if _prewarm_request_capacity_is_saturated(scene):
		_discard_tracked_pool_candidate(node, scene)
		return {"capacity_limited": true}
	if not _typed_prewarm_operation_matches(
		request_id,
		operation,
		settlement_authority,
		scene,
		parent,
		node,
		node_id,
		transition_generation,
		current_serial
	) or (parent != null and node.get_parent() != parent):
		_discard_tracked_pool_candidate(node, scene)
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_CANDIDATE_INVALIDATED,
			ERR_UNAVAILABLE
		)
	if not _run_guarded_tree_operation(
		node,
		_TreeOperation.INTERNAL_RELEASE_HOOK,
		node_id,
		_NodeOwnershipPhase.TRANSITION,
		transition_generation,
		current_serial
	):
		_discard_tracked_pool_candidate(node, scene)
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_CANDIDATE_INVALIDATED,
			ERR_UNAVAILABLE
		)
	if _prewarm_request_capacity_is_saturated(scene):
		_discard_tracked_pool_candidate(node, scene)
		return {"capacity_limited": true}
	if not _typed_prewarm_operation_matches(
		request_id,
		operation,
		settlement_authority,
		scene,
		parent,
		node,
		node_id,
		transition_generation,
		current_serial
	) or (parent != null and node.get_parent() != parent):
		_discard_tracked_pool_candidate(node, scene)
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_CANDIDATE_INVALIDATED,
			ERR_UNAVAILABLE
		)
	var _transition_erased: bool = _transition_generations.erase(node_id)
	_get_available_pool(scene).push_back(node)
	return {"ok": true}


func _run_prewarm_prepare_callback(entry: Dictionary, node: Node) -> Dictionary:
	var prepare_callback: Callable = _entry_callable(entry, "prepare_callback")
	if prepare_callback.is_null():
		return {"ok": true}
	if not prepare_callback.is_valid():
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_INVALID_PREPARE_CALLBACK_RESULT,
			ERR_INVALID_DATA
		)
	var raw_result: Variant = prepare_callback.call(node)
	if not raw_result is int:
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_INVALID_PREPARE_CALLBACK_RESULT,
			ERR_INVALID_DATA
		)
	var numeric_error: int = raw_result
	if numeric_error < OK or numeric_error > ERR_PRINTER_ON_FIRE:
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_INVALID_PREPARE_CALLBACK_RESULT,
			ERR_INVALID_DATA
		)
	var error_code: Error = numeric_error as Error
	if error_code != OK:
		return _make_prewarm_attempt_failure(
			GFObjectPoolPrewarmResult.REASON_PREPARE_CALLBACK_FAILED,
			error_code
		)
	return {"ok": true}


func _make_prewarm_attempt_failure(reason: StringName, error_code: Error) -> Dictionary:
	return {"ok": false, "reason": reason, "error_code": int(error_code)}


func _typed_prewarm_operation_matches(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	settlement_authority: Callable,
	scene: PackedScene,
	parent: Node,
	node: Node,
	node_id: int,
	expected_generation: int,
	expected_lifecycle_serial: int
) -> bool:
	return (
		_prewarm_request_candidate_context_is_valid(
			request_id,
			operation,
			settlement_authority,
			scene,
			parent,
			node,
			expected_lifecycle_serial
		)
		and _node_operation_matches(
			node,
			node_id,
			_NodeOwnershipPhase.TRANSITION,
			expected_generation,
			expected_lifecycle_serial
		)
	)


func _prewarm_request_candidate_context_is_valid(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	settlement_authority: Callable,
	scene: PackedScene,
	parent: Node,
	node: Node,
	expected_lifecycle_serial: int
) -> bool:
	if not _poll_prewarm_request(request_id, operation, settlement_authority):
		return false
	if expected_lifecycle_serial != _lifecycle_serial or not is_instance_valid(node):
		return false
	if not _all_nodes.has(scene) or not _available_pools.has(scene):
		return false
	if parent != null and (not is_instance_valid(parent) or parent.is_queued_for_deletion()):
		return false
	return not node.is_queued_for_deletion()


func _prewarm_request_capacity_is_saturated(scene: PackedScene) -> bool:
	return max_available_per_scene > 0 and get_available_count(scene) >= max_available_per_scene


func _poll_prewarm_request(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	settlement_authority: Callable
) -> bool:
	var entry: Dictionary = _get_prewarm_request_entry(request_id, operation)
	if entry.is_empty():
		return false
	if _is_disposed or GFVariantData.get_option_int(entry, "lifecycle_serial") != _lifecycle_serial:
		var _disposed: bool = _finish_prewarm_request(
			request_id,
			operation,
			GFObjectPoolPrewarmResult.Status.DISPOSED,
			GFObjectPoolPrewarmResult.REASON_UTILITY_DISPOSED,
			ERR_UNAVAILABLE,
			settlement_authority
		)
		return false
	var cancellation_token: GFCancellationToken = _entry_cancellation_token(entry)
	if cancellation_token != null:
		var token_reason: StringName = _get_prewarm_token_terminal_reason(
			cancellation_token
		)
		if not token_reason.is_empty():
			var _token_cancelled: bool = _finish_prewarm_request(
				request_id,
				operation,
				GFObjectPoolPrewarmResult.Status.CANCELLED,
				token_reason,
				ERR_SKIP,
				settlement_authority
			)
			return false
	if _prewarm_lifetime_is_released(
		entry,
		"owner_lifetime_check"
	):
		var _owner_released: bool = _finish_prewarm_request(
			request_id,
			operation,
			GFObjectPoolPrewarmResult.Status.CANCELLED,
			GFObjectPoolPrewarmResult.REASON_OWNER_RELEASED,
			ERR_SKIP,
			settlement_authority
		)
		return false
	if _prewarm_lifetime_is_released(
		entry,
		"parent_lifetime_check"
	):
		var _parent_released: bool = _finish_prewarm_request(
			request_id,
			operation,
			GFObjectPoolPrewarmResult.Status.CANCELLED,
			GFObjectPoolPrewarmResult.REASON_PARENT_RELEASED,
			ERR_SKIP,
			settlement_authority
		)
		return false
	var parent: Node = _entry_prewarm_parent(entry)
	if parent != null and parent.is_queued_for_deletion():
		var _queued_parent_released: bool = _finish_prewarm_request(
			request_id,
			operation,
			GFObjectPoolPrewarmResult.Status.CANCELLED,
			GFObjectPoolPrewarmResult.REASON_PARENT_RELEASED,
			ERR_SKIP,
			settlement_authority
		)
		return false
	return true


func _prewarm_lifetime_is_released(
	entry: Dictionary,
	probe_key: String
) -> bool:
	var lifetime_probe: Callable = _entry_callable(entry, probe_key)
	if not lifetime_probe.is_valid():
		return false
	var raw_result: Variant = lifetime_probe.call()
	return raw_result is bool and raw_result


func _cancel_prewarm_operation(
	operation: GFObjectPoolPrewarmOperation,
	reason: StringName,
	settlement_authority: Callable
) -> bool:
	if (
		operation == null
		or reason != GFObjectPoolPrewarmResult.REASON_CALLER_CANCELLED
		or _pool_lifecycle_transition != _PoolLifecycleTransition.NONE
	):
		return false
	return _finish_prewarm_request(
		operation.get_request_id(),
		operation,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		GFObjectPoolPrewarmResult.REASON_CALLER_CANCELLED,
		ERR_SKIP,
		settlement_authority
	)


func _on_prewarm_token_cancelled(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	token_ref: WeakRef,
	token_instance_id: int,
	settlement_authority: Callable
) -> void:
	var entry: Dictionary = _get_prewarm_request_entry(request_id, operation)
	if entry.is_empty():
		return
	var cancellation_token: GFCancellationToken = _entry_cancellation_token(entry)
	var raw_expected_token: Variant = token_ref.get_ref() if token_ref != null else null
	if not (raw_expected_token is GFCancellationToken):
		return
	var expected_token: GFCancellationToken = raw_expected_token
	if (
		cancellation_token != expected_token
		or expected_token.get_instance_id() != token_instance_id
	):
		return
	var reason: StringName = _get_prewarm_token_terminal_reason(expected_token)
	if reason.is_empty():
		return
	var _cancelled: bool = _finish_prewarm_request(
		request_id,
		operation,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		reason,
		ERR_SKIP,
		settlement_authority
	)


func _on_prewarm_lifetime_released(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	reason: StringName,
	anchor_instance_id: int,
	lifetime_check: Callable,
	settlement_authority: Callable
) -> void:
	var entry: Dictionary = _get_prewarm_request_entry(request_id, operation)
	if entry.is_empty():
		return
	var lifetime_released: bool = false
	if reason == GFObjectPoolPrewarmResult.REASON_OWNER_RELEASED:
		lifetime_released = _prewarm_lifetime_callback_matches(
			entry,
			"owner_ref",
			"owner_id",
			"owner_lifetime_check",
			anchor_instance_id,
			lifetime_check
		)
	elif reason == GFObjectPoolPrewarmResult.REASON_PARENT_RELEASED:
		lifetime_released = _prewarm_lifetime_callback_matches(
			entry,
			"parent_ref",
			"parent_id",
			"parent_lifetime_check",
			anchor_instance_id,
			lifetime_check
		)
	if not lifetime_released:
		return
	var _cancelled: bool = _finish_prewarm_request(
		request_id,
		operation,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		reason,
		ERR_SKIP,
		settlement_authority
	)


func _prewarm_lifetime_callback_matches(
	entry: Dictionary,
	ref_key: String,
	id_key: String,
	probe_key: String,
	anchor_instance_id: int,
	lifetime_check: Callable
) -> bool:
	if (
		anchor_instance_id <= 0
		or GFVariantData.get_option_int(entry, id_key) != anchor_instance_id
		or _entry_callable(entry, probe_key) != lifetime_check
	):
		return false
	var anchor: Object = _entry_weak_object(entry, ref_key, id_key)
	if anchor != null and anchor.get_instance_id() != anchor_instance_id:
		return false
	var raw_result: Variant = lifetime_check.call()
	return raw_result is bool and raw_result


func _finish_completed_prewarm_request(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	settlement_authority: Callable
) -> bool:
	var status: GFObjectPoolPrewarmResult.Status = GFObjectPoolPrewarmResult.Status.COMPLETED
	var reason: StringName = GFObjectPoolPrewarmResult.REASON_COMPLETED
	var error_code: Error = OK
	if operation.get_admitted_count() == 0 and operation.get_skipped_count() > 0:
		status = GFObjectPoolPrewarmResult.Status.REJECTED
		reason = GFObjectPoolPrewarmResult.REASON_CAPACITY_UNAVAILABLE
		error_code = ERR_BUSY
	elif operation.get_skipped_count() > 0:
		status = GFObjectPoolPrewarmResult.Status.PARTIAL
		reason = GFObjectPoolPrewarmResult.REASON_CAPACITY_LIMITED
	return _finish_prewarm_request(
		request_id,
		operation,
		status,
		reason,
		error_code,
		settlement_authority
	)


func _finish_prewarm_request(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	status: GFObjectPoolPrewarmResult.Status,
	reason: StringName,
	error_code: Error,
	settlement_authority: Callable
) -> bool:
	var entry: Dictionary = _get_prewarm_request_entry(request_id, operation)
	if entry.is_empty():
		return false
	if not operation.accepts_settlement_authority_for_framework(settlement_authority):
		return false
	var final_status: GFObjectPoolPrewarmResult.Status = status
	var final_reason: StringName = reason
	var final_error_code: Error = error_code
	if _pool_lifecycle_transition != _PoolLifecycleTransition.NONE:
		final_status = GFObjectPoolPrewarmResult.Status.DISPOSED
		final_reason = GFObjectPoolPrewarmResult.REASON_UTILITY_DISPOSED
		if _pool_lifecycle_transition == _PoolLifecycleTransition.INITIALIZE:
			final_reason = GFObjectPoolPrewarmResult.REASON_UTILITY_REINITIALIZED
		final_error_code = ERR_UNAVAILABLE
	elif (
		status == GFObjectPoolPrewarmResult.Status.CANCELLED
		and operation.get_created_count() == operation.get_admitted_count()
	):
		final_status = GFObjectPoolPrewarmResult.Status.COMPLETED
		final_reason = GFObjectPoolPrewarmResult.REASON_COMPLETED
		if operation.get_skipped_count() > 0:
			final_status = GFObjectPoolPrewarmResult.Status.PARTIAL
			final_reason = GFObjectPoolPrewarmResult.REASON_CAPACITY_LIMITED
		final_error_code = OK
	_disconnect_prewarm_request_anchors(entry)
	_release_request_prewarm_capacity(
		entry,
		GFVariantData.get_option_int(entry, "reserved_remaining")
	)
	var _erased: bool = _active_prewarm_requests.erase(request_id)
	var finished: bool = operation.finish_for_framework(
		settlement_authority,
		final_status,
		final_reason,
		final_error_code
	)
	return finished


func _finish_prewarm_request_for_lifecycle(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation,
	expected_lifecycle_serial: int,
	settlement_authority: Callable
) -> bool:
	var entry: Dictionary = _get_prewarm_request_entry(request_id, operation)
	if (
		entry.is_empty()
		or not _is_disposed
		or _pool_lifecycle_transition == _PoolLifecycleTransition.NONE
		or GFVariantData.get_option_int(entry, "lifecycle_serial")
		!= expected_lifecycle_serial
		or expected_lifecycle_serial != _lifecycle_serial
	):
		return false
	var reason: StringName = GFObjectPoolPrewarmResult.REASON_UTILITY_DISPOSED
	if _pool_lifecycle_transition == _PoolLifecycleTransition.INITIALIZE:
		reason = GFObjectPoolPrewarmResult.REASON_UTILITY_REINITIALIZED
	return _finish_prewarm_request(
		request_id,
		operation,
		GFObjectPoolPrewarmResult.Status.DISPOSED,
		reason,
		ERR_UNAVAILABLE,
		settlement_authority
	)


func _finish_all_prewarm_requests() -> void:
	var request_ids: Array = _active_prewarm_requests.keys()
	request_ids.sort()
	for request_id_value: Variant in request_ids:
		if not request_id_value is int:
			continue
		var request_id: int = request_id_value
		var entry: Dictionary = _get_prewarm_request_entry_unchecked(request_id)
		var operation: GFObjectPoolPrewarmOperation = _entry_prewarm_operation(entry)
		if operation != null:
			var lifecycle_callback: Callable = _entry_callable(
				entry,
				"lifecycle_callback"
			)
			if lifecycle_callback.is_valid():
				var _finished: Variant = lifecycle_callback.call()


func _disconnect_prewarm_request_anchors(entry: Dictionary) -> void:
	var cancellation_token: GFCancellationToken = _entry_cancellation_token(entry)
	var token_callback: Callable = _entry_callable(entry, "token_callback")
	if (
		cancellation_token != null
		and token_callback.is_valid()
		and cancellation_token.cancel_requested.is_connected(token_callback)
	):
		cancellation_token.cancel_requested.disconnect(token_callback)
	var parent: Node = _entry_prewarm_parent(entry)
	var parent_tree_entered_callback: Callable = _entry_callable(
		entry,
		"parent_tree_entered_callback"
	)
	if (
		parent != null
		and parent_tree_entered_callback.is_valid()
		and parent.tree_entered.is_connected(parent_tree_entered_callback)
	):
		parent.tree_entered.disconnect(parent_tree_entered_callback)
	for key: String in ["owner_lifetime", "parent_lifetime"]:
		var subscription: GFLifetimeSubscription = _entry_lifetime_subscription(entry, key)
		if subscription != null:
			var _deactivated: bool = subscription._deactivate_from_source()


func _release_request_prewarm_capacity(entry: Dictionary, count: int) -> void:
	var reserved_remaining: int = GFVariantData.get_option_int(entry, "reserved_remaining")
	var release_count: int = mini(maxi(count, 0), reserved_remaining)
	if release_count <= 0:
		return
	var scene: PackedScene = _entry_prewarm_scene(entry)
	var current_serial: int = GFVariantData.get_option_int(entry, "lifecycle_serial")
	if scene != null:
		_release_prewarm_capacity(scene, release_count, current_serial)
	entry["reserved_remaining"] = reserved_remaining - release_count


func _get_prewarm_request_entry(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation
) -> Dictionary:
	if request_id <= 0 or operation == null:
		return {}
	var entry: Dictionary = _get_prewarm_request_entry_unchecked(request_id)
	return entry if _entry_prewarm_operation(entry) == operation else {}


func _get_prewarm_request_entry_unchecked(request_id: int) -> Dictionary:
	var value: Variant = _active_prewarm_requests.get(request_id)
	if value is Dictionary:
		var entry: Dictionary = value
		return entry
	return {}


func _prewarm_request_is_active(
	request_id: int,
	operation: GFObjectPoolPrewarmOperation
) -> bool:
	return not _get_prewarm_request_entry(request_id, operation).is_empty()


func _take_prewarm_request_id() -> int:
	_prewarm_request_id_mutex.lock()
	var request_id: int = _next_prewarm_request_id
	_next_prewarm_request_id += 1
	if _next_prewarm_request_id <= 0:
		_next_prewarm_request_id = 1
	_prewarm_request_id_mutex.unlock()
	return request_id


func _token_is_cancelled_or_completed(cancellation_token: GFCancellationToken) -> bool:
	return not _get_prewarm_token_terminal_reason(cancellation_token).is_empty()


func _get_prewarm_token_terminal_reason(
	cancellation_token: GFCancellationToken
) -> StringName:
	if cancellation_token == null:
		return &""
	if cancellation_token is GFAsyncScope:
		var async_scope: GFAsyncScope = cancellation_token
		if async_scope.is_completed():
			return GFObjectPoolPrewarmResult.REASON_CANCELLATION_SCOPE_COMPLETED
	if cancellation_token.is_cancel_requested():
		return GFObjectPoolPrewarmResult.REASON_TOKEN_CANCELLED
	return &""


func _entry_prewarm_operation(entry: Dictionary) -> GFObjectPoolPrewarmOperation:
	var value: Variant = GFVariantData.get_option_value(entry, "operation")
	if value is GFObjectPoolPrewarmOperation:
		var operation: GFObjectPoolPrewarmOperation = value
		return operation
	return null


func _entry_prewarm_scene(entry: Dictionary) -> PackedScene:
	return _variant_to_packed_scene(GFVariantData.get_option_value(entry, "scene"))


func _entry_prewarm_parent(entry: Dictionary) -> Node:
	var value: Object = _entry_weak_object(entry, "parent_ref", "parent_id")
	return value as Node if value is Node else null


func _entry_cancellation_token(entry: Dictionary) -> GFCancellationToken:
	var value: Variant = GFVariantData.get_option_value(entry, "cancellation_token")
	if value is GFCancellationToken:
		var token: GFCancellationToken = value
		return token
	return null


func _entry_callable(entry: Dictionary, key: String) -> Callable:
	var value: Variant = GFVariantData.get_option_value(entry, key)
	return value if value is Callable else Callable()


func _entry_lifetime_subscription(
	entry: Dictionary,
	key: String
) -> GFLifetimeSubscription:
	var value: Variant = GFVariantData.get_option_value(entry, key)
	if value is GFLifetimeSubscription:
		var subscription: GFLifetimeSubscription = value
		return subscription
	return null


func _entry_weak_object(entry: Dictionary, ref_key: String, id_key: String) -> Object:
	var ref_value: Variant = GFVariantData.get_option_value(entry, ref_key)
	if not ref_value is WeakRef:
		return null
	var owner_ref: WeakRef = ref_value
	var owner_value: Variant = owner_ref.get_ref()
	if not owner_value is Object:
		return null
	var owner: Object = owner_value
	if (
		not is_instance_valid(owner)
		or owner.get_instance_id() != GFVariantData.get_option_int(entry, id_key)
	):
		return null
	return owner


func _prewarm_node(
	scene: PackedScene,
	parent: Node,
	before_add: Callable,
	current_serial: int
) -> bool:
	if not _is_prewarm_context_valid(scene, parent, current_serial):
		return false

	var node: Node = _variant_to_node(scene.instantiate())
	if node == null:
		push_error("[GFObjectPoolUtility] PackedScene 未能实例化为 Node。")
		return false
	if not _is_prewarm_candidate_valid(scene, parent, node, current_serial):
		_discard_pool_candidate(node)
		return false

	var node_id: int = node.get_instance_id()
	var transition_generation: int = _take_operation_generation()
	node.set_meta(_META_ACTIVE, false)
	node.set_meta(_META_SOURCE_SCENE, scene)
	_transition_generations[node_id] = transition_generation
	_get_all_nodes_pool(scene).push_back(node)
	if not _run_guarded_tree_state_operation(
		node, false, node_id, _NodeOwnershipPhase.TRANSITION,
		transition_generation, current_serial
	):
		_discard_tracked_pool_candidate(node, scene)
		return false

	_call_before_add(before_add, node)
	if (
		not _prewarm_operation_matches(
			scene, parent, node, node_id, transition_generation, current_serial
		)
		or node.get_parent() != null
	):
		_discard_tracked_pool_candidate(node, scene)
		return false

	if parent != null:
		parent.add_child(node)
	if (
		not _prewarm_operation_matches(
			scene, parent, node, node_id, transition_generation, current_serial
		)
		or (parent != null and node.get_parent() != parent)
	):
		_discard_tracked_pool_candidate(node, scene)
		return false

	if not _run_guarded_tree_operation(
		node,
		_TreeOperation.INTERNAL_RELEASE_HOOK,
		node_id,
		_NodeOwnershipPhase.TRANSITION,
		transition_generation,
		current_serial
	):
		_discard_tracked_pool_candidate(node, scene)
		return false
	if (
		not _prewarm_operation_matches(
			scene, parent, node, node_id, transition_generation, current_serial
		)
		or (parent != null and node.get_parent() != parent)
	):
		_discard_tracked_pool_candidate(node, scene)
		return false

	var _prewarm_transition_erased: bool = _transition_generations.erase(node_id)
	_get_available_pool(scene).push_back(node)
	return true


func _move_to_pool_root(node: Node) -> void:
	var pool_root: Node = _ensure_pool_root()
	if pool_root == null or node.get_parent() == pool_root:
		return

	if node.get_parent() != null:
		node.reparent(pool_root, false)
	else:
		pool_root.add_child(node)


func _call_before_add(before_add: Callable, node: Node) -> void:
	if not before_add.is_valid() or node == null:
		return
	var _before_add_result: Variant = before_add.call(node)


func _report_legacy_prewarm_failure(result: GFObjectPoolPrewarmResult) -> void:
	if (
		result != null
		and result.get_status() == GFObjectPoolPrewarmResult.Status.FAILED
		and result.get_reason() == GFObjectPoolPrewarmResult.REASON_SCENE_INSTANTIATION_FAILED
	):
		push_error("[GFObjectPoolUtility] PackedScene 未能实例化为 Node。")


func _queue_free_detached(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var parent: Node = node.get_parent()
	if parent != null and not GFAutoload.is_tree_exit_in_progress():
		parent.remove_child(node)
	if not node.is_queued_for_deletion():
		node.queue_free()


func _ensure_pool_root() -> Node:
	if is_instance_valid(_pool_root):
		return _pool_root

	var scene_tree: SceneTree = _get_scene_tree()
	if scene_tree == null:
		return null

	_pool_root = Node.new()
	_pool_root.name = "GFObjectPoolRoot"
	scene_tree.root.add_child(_pool_root)
	return _pool_root


func _reserve_prewarm_capacity(scene: PackedScene, requested_count: int) -> int:
	if requested_count <= 0:
		return 0

	var reserved_count: int = _get_prewarm_reserved_count(scene)
	var admitted_count: int = requested_count
	if max_available_per_scene > 0:
		var remaining_capacity: int = (
			max_available_per_scene
			- get_available_count(scene)
			- reserved_count
		)
		admitted_count = maxi(0, mini(requested_count, remaining_capacity))
	if admitted_count <= 0:
		return 0

	_prewarm_reserved_counts[scene] = reserved_count + admitted_count
	return admitted_count


func _release_prewarm_capacity(scene: PackedScene, count: int, current_serial: int) -> void:
	if count <= 0 or current_serial != _lifecycle_serial:
		return

	var reserved_count: int = _get_prewarm_reserved_count(scene)
	var remaining_count: int = maxi(0, reserved_count - count)
	if remaining_count == 0:
		var _erased_reservation: bool = _prewarm_reserved_counts.erase(scene)
	else:
		_prewarm_reserved_counts[scene] = remaining_count


func _get_prewarm_reserved_count(scene: PackedScene) -> int:
	var raw_count: Variant = _prewarm_reserved_counts.get(scene, 0)
	if raw_count is int:
		var count: int = raw_count
		return maxi(0, count)
	return 0


func _is_prewarm_context_valid(
	scene: PackedScene,
	parent: Node,
	current_serial: int
) -> bool:
	if _is_disposed or current_serial != _lifecycle_serial:
		return false
	if not is_instance_valid(scene):
		return false
	if parent != null:
		if not is_instance_valid(parent) or parent.is_queued_for_deletion():
			return false
	if not _all_nodes.has(scene) or not _available_pools.has(scene):
		return false
	if max_available_per_scene > 0 and get_available_count(scene) >= max_available_per_scene:
		return false
	return true


func _is_prewarm_candidate_valid(
	scene: PackedScene,
	parent: Node,
	node_value: Variant,
	current_serial: int
) -> bool:
	if not _is_prewarm_context_valid(scene, parent, current_serial):
		return false
	return _get_valid_pool_node(node_value) != null


func _prewarm_operation_matches(
	scene: PackedScene,
	parent: Node,
	node: Node,
	node_id: int,
	expected_generation: int,
	expected_lifecycle_serial: int
) -> bool:
	return (
		_is_prewarm_candidate_valid(scene, parent, node, expected_lifecycle_serial)
		and _node_operation_matches(
			node,
			node_id,
			_NodeOwnershipPhase.TRANSITION,
			expected_generation,
			expected_lifecycle_serial
		)
	)


func _discard_pool_candidate(node_value: Variant) -> void:
	var node: Node = _INSTANCE_GUARD._get_live_node(node_value)
	if node != null:
		_queue_free_detached(node)


func _discard_tracked_pool_candidate(node: Node, scene: PackedScene) -> void:
	_remove_node_from_scene_pool(node, scene)
	_discard_pool_candidate(node)


func _get_valid_pool_node(value: Variant) -> Node:
	var node: Node = _INSTANCE_GUARD._get_live_node(value)
	if node == null:
		return null
	if node.is_queued_for_deletion():
		return null
	return node


func _resolve_owner_scene(node: Node, fallback_scene: PackedScene) -> PackedScene:
	var owner_scene: PackedScene = fallback_scene

	if node.has_meta(_META_SOURCE_SCENE):
		var tracked_scene: PackedScene = _variant_to_packed_scene(node.get_meta(_META_SOURCE_SCENE))
		if tracked_scene != null:
			if fallback_scene != null and tracked_scene != fallback_scene:
				push_warning("[GFObjectPoolUtility] release 收到不匹配的 PackedScene，已回退到节点原始所属池。")
			owner_scene = tracked_scene

	return owner_scene


func _remove_node_from_scene_pool(node: Node, scene: PackedScene) -> void:
	if is_instance_valid(node):
		var node_id: int = node.get_instance_id()
		_erase_active_lease(node_id)
		var _transition_generation_erased: bool = _transition_generations.erase(node_id)
	if _all_nodes.has(scene):
		_get_all_nodes_pool(scene).erase(node)
	if _available_pools.has(scene):
		_get_available_pool(scene).erase(node)


func _retire_exact_active_lease_tracking(
	scene: PackedScene,
	instance_id: int,
	tracked_node_value: Variant
) -> bool:
	if not _all_nodes.has(scene):
		return false
	var all_nodes: Array = _get_all_nodes_pool(scene)
	var tracked_index: int = -1
	for index: int in range(all_nodes.size()):
		if is_same(all_nodes[index], tracked_node_value):
			tracked_index = index
			break
	if tracked_index < 0:
		return false
	all_nodes.remove_at(tracked_index)
	if _available_pools.has(scene):
		var available_pool: Array = _get_available_pool(scene)
		for index: int in range(available_pool.size() - 1, -1, -1):
			if is_same(available_pool[index], tracked_node_value):
				available_pool.remove_at(index)
	var _transition_generation_erased: bool = _transition_generations.erase(instance_id)
	_erase_active_lease(instance_id)
	return true


func _prune_invalid_scene_nodes(scene: PackedScene) -> void:
	if not is_instance_valid(scene):
		return

	if _all_nodes.has(scene):
		var all_nodes: Array = _get_all_nodes_pool(scene)
		for i: int in range(all_nodes.size() - 1, -1, -1):
			var node_variant: Variant = all_nodes[i]
			if _get_valid_pool_node(node_variant) == null:
				all_nodes.remove_at(i)

	if _available_pools.has(scene):
		var available_pool: Array = _get_available_pool(scene)
		for i: int in range(available_pool.size() - 1, -1, -1):
			var node_variant: Variant = available_pool[i]
			if _get_valid_pool_node(node_variant) == null:
				available_pool.remove_at(i)


func _prune_invalid_available_nodes(scene: PackedScene) -> void:
	if not is_instance_valid(scene) or not _available_pools.has(scene):
		return

	var available_pool: Array = _get_available_pool(scene)
	for i: int in range(available_pool.size() - 1, -1, -1):
		var node_variant: Variant = available_pool[i]
		if _get_valid_pool_node(node_variant) == null:
			available_pool.remove_at(i)


func _prune_invalid_generations() -> void:
	var tracked_ids: Dictionary = {}
	for scene_key: Variant in _all_nodes.keys():
		var scene: PackedScene = _variant_to_packed_scene(scene_key)
		if scene == null:
			continue
		for node_variant: Variant in _get_all_nodes_pool(scene):
			var node: Node = _get_valid_pool_node(node_variant)
			if node != null:
				tracked_ids[node.get_instance_id()] = true

	for active_node_id_variant: Variant in _active_generations.keys():
		if not tracked_ids.has(active_node_id_variant):
			if active_node_id_variant is int:
				var active_node_id: int = active_node_id_variant
				_erase_active_lease(active_node_id)
	for transition_node_id_variant: Variant in _transition_generations.keys():
		if not tracked_ids.has(transition_node_id_variant):
			var _transition_generation_erased: bool = (
				_transition_generations.erase(transition_node_id_variant)
			)


func _erase_active_lease(instance_id: int) -> void:
	var _active_generation_erased: bool = _active_generations.erase(instance_id)
	var _active_scene_erased: bool = _active_lease_scenes.erase(instance_id)
	var _active_node_erased: bool = _active_lease_nodes.erase(instance_id)


func _prune_invalid_available_nodes_if_needed(scene: PackedScene) -> void:
	if prune_invalid_on_each_operation:
		_prune_invalid_available_nodes(scene)


func _get_scene_debug_key(scene: PackedScene) -> String:
	if scene == null:
		return ""
	if not scene.resource_path.is_empty():
		return scene.resource_path
	return "PackedScene:%d" % scene.get_instance_id()


func _get_all_nodes_pool(scene: PackedScene) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(_all_nodes, scene, []))


func _get_available_pool(scene: PackedScene) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(_available_pools, scene, []))


func _get_scene_tree() -> SceneTree:
	return _variant_to_scene_tree(Engine.get_main_loop())


static func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


static func _to_process_mode(value: int) -> Node.ProcessMode:
	match value:
		Node.PROCESS_MODE_PAUSABLE:
			return Node.PROCESS_MODE_PAUSABLE
		Node.PROCESS_MODE_WHEN_PAUSED:
			return Node.PROCESS_MODE_WHEN_PAUSED
		Node.PROCESS_MODE_ALWAYS:
			return Node.PROCESS_MODE_ALWAYS
		Node.PROCESS_MODE_DISABLED:
			return Node.PROCESS_MODE_DISABLED
		_:
			return Node.PROCESS_MODE_INHERIT


static func _variant_to_canvas_item(value: Variant) -> CanvasItem:
	if value is CanvasItem:
		var canvas_item: CanvasItem = value
		return canvas_item
	return null


static func _variant_to_packed_scene(value: Variant) -> PackedScene:
	if value is PackedScene:
		var scene: PackedScene = value
		return scene
	return null


static func _variant_to_scene_tree(value: Variant) -> SceneTree:
	if value is SceneTree:
		var tree: SceneTree = value
		return tree
	return null
