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
var _lifecycle_serial: int = 0
var _pool_root: Node = null
var _is_disposed: bool = false


# --- GF 生命周期方法 ---

## 第一阶段初始化：清空内部池字典。
## [br]
## @api public
func init() -> void:
	_lifecycle_serial += 1
	_is_disposed = false
	if is_instance_valid(_pool_root):
		_queue_free_detached(_pool_root)
	_all_nodes = {}
	_available_pools = {}
	_pool_root = null


## 销毁阶段：释放所有池中的节点。
## [br]
## @api public
func dispose() -> void:
	_lifecycle_serial += 1
	_is_disposed = true
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
	_pool_root = null


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
	if not is_instance_valid(parent):
		push_error("[GFObjectPoolUtility] acquire 失败：parent 无效。")
		return null

	if not _available_pools.has(scene):
		_available_pools[scene] = []
		_all_nodes[scene] = []

	_prune_invalid_available_nodes_if_needed(scene)

	var available_pool: Array = _get_available_pool(scene)

	while not available_pool.is_empty():
		var popped_item: Variant = available_pool.pop_back()
		var node: Node = _get_valid_pool_node(popped_item)
		if node != null:
			node.set_meta(_META_ACTIVE, true)
			node.set_meta(_META_SOURCE_SCENE, scene)
			_call_before_add(before_add, node)
			_set_node_tree_active_state(node, true)
			
			if is_instance_valid(parent) and node.get_parent() != parent:
				if node.get_parent() != null:
					node.reparent(parent, false)
				else:
					parent.add_child(node)

			_call_node_tree_hook(node, HOOK_ON_ACQUIRE)
			return node

	var new_node: Node = _variant_to_node(scene.instantiate())
	if new_node == null:
		push_error("[GFObjectPoolUtility] PackedScene 未能实例化为 Node。")
		return null
	new_node.set_meta(_META_ACTIVE, true)
	new_node.set_meta(_META_SOURCE_SCENE, scene)
	_prepare_node_tree(new_node)
	_set_node_tree_active_state(new_node, true)
	_call_before_add(before_add, new_node)
	if is_instance_valid(parent):
		parent.add_child(new_node)

	var all_nodes: Array = _get_all_nodes_pool(scene)
	all_nodes.push_back(new_node)
	_call_node_tree_hook(new_node, HOOK_ON_ACQUIRE)
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

	_call_node_tree_hook(node, HOOK_ON_RELEASE)
	node.set_meta(_META_ACTIVE, false)
	_set_node_tree_active_state(node, false)

	if not _available_pools.has(owner_scene):
		_available_pools[owner_scene] = []

	_prune_invalid_available_nodes_if_needed(owner_scene)
	var available_pool: Array = _get_available_pool(owner_scene)
	if max_available_per_scene > 0 and available_pool.size() >= max_available_per_scene:
		_remove_node_from_scene_pool(node, owner_scene)
		_queue_free_detached(node)
		return

	_move_to_pool_root(node)
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

	var create_count: int = _get_limited_prewarm_count(scene, count)
	for _i: int in range(create_count):
		_prewarm_node(scene, parent, before_add)


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
	if not _ensure_scene_pool(scene):
		return
	if count <= 0:
		return
	if batch_size <= 0:
		prewarm(scene, parent, count, before_add)
		return

	var current_serial: int = _lifecycle_serial
	var create_count: int = _get_limited_prewarm_count(scene, count)
	var scene_tree: SceneTree = _get_scene_tree()
	for i: int in range(create_count):
		if current_serial != _lifecycle_serial:
			return
		if parent != null and not is_instance_valid(parent):
			return
		_prewarm_node(scene, parent, before_add)
		if scene_tree != null and (i + 1) % batch_size == 0:
			await scene_tree.process_frame
			if current_serial != _lifecycle_serial:
				return
			if parent != null and not is_instance_valid(parent):
				return


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
	if not _ensure_scene_pool(scene):
		return
	if count <= 0:
		return
	if msec_budget_per_frame <= 0.0:
		prewarm(scene, parent, count, before_add)
		return

	var current_serial: int = _lifecycle_serial
	var create_count: int = _get_limited_prewarm_count(scene, count)
	var created_count: int = 0
	var scene_tree: SceneTree = _get_scene_tree()
	while created_count < create_count:
		var frame_start_usec: int = Time.get_ticks_usec()
		var created_this_frame: int = 0
		while created_count < create_count:
			if current_serial != _lifecycle_serial:
				return
			if parent != null and not is_instance_valid(parent):
				return
			_prewarm_node(scene, parent, before_add)
			created_count += 1
			created_this_frame += 1

			var elapsed_msec: float = float(Time.get_ticks_usec() - frame_start_usec) / 1000.0
			if created_this_frame > 0 and elapsed_msec >= msec_budget_per_frame:
				break

		if created_count < create_count and scene_tree != null:
			await scene_tree.process_frame
			if current_serial != _lifecycle_serial:
				return
			if parent != null and not is_instance_valid(parent):
				return


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


# --- 私有/辅助方法 ---

func _prepare_node_tree(node: Node) -> void:
	_prepare_node_for_pool(node)
	for child: Node in node.get_children(true):
		_prepare_node_tree(child)


func _ensure_scene_pool(scene: PackedScene) -> bool:
	if not is_instance_valid(scene):
		push_error("[GFObjectPoolUtility] 传入了无效的 PackedScene。")
		return false

	if not _available_pools.has(scene):
		_available_pools[scene] = []
		_all_nodes[scene] = []

	_prune_invalid_available_nodes_if_needed(scene)
	return true


func _prewarm_node(scene: PackedScene, parent: Node, before_add: Callable = Callable()) -> void:
	if not _ensure_scene_pool(scene):
		return
	if parent != null and not is_instance_valid(parent):
		return

	var node: Node = _variant_to_node(scene.instantiate())
	if node == null:
		push_error("[GFObjectPoolUtility] PackedScene 未能实例化为 Node。")
		return
	node.set_meta(_META_ACTIVE, false)
	node.set_meta(_META_SOURCE_SCENE, scene)
	_prepare_node_tree(node)
	_set_node_tree_active_state(node, false)
	_call_before_add(before_add, node)
	if is_instance_valid(parent):
		parent.add_child(node)

	_call_node_tree_internal_hook(node, _HOOK_INTERNAL_ON_RELEASE)
	_get_all_nodes_pool(scene).push_back(node)
	_get_available_pool(scene).push_back(node)


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


func _get_limited_prewarm_count(scene: PackedScene, requested_count: int) -> int:
	if max_available_per_scene <= 0:
		return requested_count

	return maxi(0, mini(requested_count, max_available_per_scene - get_available_count(scene)))


func _prepare_node_for_pool(node: Node) -> void:
	if not node.has_meta(_META_ORIGINAL_PROCESS_MODE):
		node.set_meta(_META_ORIGINAL_PROCESS_MODE, node.process_mode)
		
	var canvas_item: CanvasItem = _variant_to_canvas_item(node)
	if canvas_item != null and not node.has_meta(_META_ORIGINAL_VISIBLE):
		node.set_meta(_META_ORIGINAL_VISIBLE, canvas_item.visible)
		
	if "disabled" in node and not node.has_meta(_META_ORIGINAL_DISABLED):
		node.set_meta(_META_ORIGINAL_DISABLED, GFObjectPropertyTools.read_property(node, NodePath("disabled")))


func _set_node_tree_active_state(node: Node, active: bool) -> void:
	_set_node_active_state(node, active)
	if not manage_descendant_active_state:
		return
	for child: Node in node.get_children(true):
		_set_node_tree_active_state(child, active)


func _set_node_active_state(node: Node, active: bool) -> void:
	_prepare_node_for_pool(node)
	
	if active:
		var original_process_mode: int = GFVariantData.to_int(
			node.get_meta(_META_ORIGINAL_PROCESS_MODE, Node.PROCESS_MODE_INHERIT),
			Node.PROCESS_MODE_INHERIT
		)
		node.process_mode = _to_process_mode(original_process_mode)
		var canvas_item: CanvasItem = _variant_to_canvas_item(node)
		if canvas_item != null:
			canvas_item.visible = GFVariantData.to_bool(node.get_meta(_META_ORIGINAL_VISIBLE, true), true)
		if "disabled" in node:
			node.set("disabled", node.get_meta(_META_ORIGINAL_DISABLED))
	else:
		node.process_mode = Node.PROCESS_MODE_DISABLED as Node.ProcessMode
		var canvas_item: CanvasItem = _variant_to_canvas_item(node)
		if canvas_item != null:
			canvas_item.visible = false
		if "disabled" in node:
			node.set("disabled", true)


func _call_node_tree_hook(node: Node, hook_name: StringName) -> void:
	_call_node_hook(node, hook_name)
	for child: Node in node.get_children(true):
		_call_node_tree_hook(child, hook_name)


func _call_node_hook(node: Node, hook_name: StringName) -> void:
	if hook_name == HOOK_ON_ACQUIRE and node.has_method(_HOOK_INTERNAL_ON_ACQUIRE):
		var _internal_acquire_result: Variant = node.call(_HOOK_INTERNAL_ON_ACQUIRE)
	if node.has_method(hook_name):
		var _hook_result: Variant = node.call(hook_name)
	if hook_name == HOOK_ON_RELEASE and node.has_method(_HOOK_INTERNAL_ON_RELEASE):
		var _internal_release_result: Variant = node.call(_HOOK_INTERNAL_ON_RELEASE)


func _call_node_tree_internal_hook(node: Node, hook_name: StringName) -> void:
	if node.has_method(hook_name):
		var _hook_result: Variant = node.call(hook_name)
	for child: Node in node.get_children(true):
		_call_node_tree_internal_hook(child, hook_name)


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
	if _all_nodes.has(scene):
		_get_all_nodes_pool(scene).erase(node)
	if _available_pools.has(scene):
		_get_available_pool(scene).erase(node)


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
