## 测试 GFObjectPoolUtility 的 acquire、release、prewarm 及 get_available_count。
extends GutTest


# --- 私有变量 ---

var _pool: GFObjectPoolUtility
var _parent: Node
var _scene: PackedScene
var _test_architecture: GFArchitecture = null


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_pool = GFObjectPoolUtility.new()
	_pool.init()

	_parent = Node.new()
	add_child(_parent)

	_scene = _make_node_scene()


func after_each() -> void:
	_pool.dispose()
	_pool = null
	if _test_architecture != null:
		if Gf.has_architecture() and Gf.get_architecture() == _test_architecture:
			Gf._architecture = null
		_test_architecture.dispose()
		_test_architecture = null
	if is_instance_valid(_parent):
		_parent.queue_free()
	_parent = null
	_scene = null
	await get_tree().process_frame

# --- 测试：acquire ---

## 验证 acquire 返回有效节点并将其添加到父节点。
func test_acquire_returns_valid_node() -> void:
	var node: Node = _pool.acquire(_scene, _parent)

	assert_not_null(node, "acquire 应返回有效节点。")
	assert_true(is_instance_valid(node), "返回的节点应为有效实例。")


## 验证 acquire 后节点的 metadata 被标记为激活状态。
func test_acquire_node_is_active() -> void:
	var node: Node = _pool.acquire(_scene, _parent)

	assert_eq(_pool.get_active_count(_scene), 1, "acquire 后对象池应报告一个激活节点。")
	assert_true(_pool.get_active_nodes(_scene).has(node), "acquire 返回的节点应出现在激活节点列表中。")


# --- 测试：release ---

## 验证 release 后节点的 metadata 被标记为未激活。
func test_release_marks_node_inactive() -> void:
	var node: Node = _pool.acquire(_scene, _parent)
	_pool.release(node, _scene)

	assert_eq(_pool.get_active_count(_scene), 0, "release 后对象池不应继续报告激活节点。")
	assert_eq(_pool.get_available_count(_scene), 1, "release 后节点应进入可用池。")


## 验证 release 后 CanvasItem 会被隐藏并暂停处理，acquire 时恢复。
func test_release_disables_visible_node_and_acquire_restores_it() -> void:
	var control_scene: PackedScene = _make_control_scene()
	var node: Control = _acquire_control(control_scene)

	assert_true(node.visible, "acquire 后 Control 应保持可见。")
	assert_eq(node.process_mode, Node.PROCESS_MODE_INHERIT, "acquire 后应保持原 process_mode。")

	_pool.release(node, control_scene)

	assert_false(node.visible, "release 后 Control 应被隐藏。")
	assert_eq(node.process_mode, Node.PROCESS_MODE_DISABLED, "release 后节点应停止处理。")

	var reused: Control = _acquire_control(control_scene)

	assert_eq(reused, node, "再次 acquire 应复用同一 Control。")
	assert_true(reused.visible, "复用后 Control 应恢复可见。")
	assert_eq(reused.process_mode, Node.PROCESS_MODE_INHERIT, "复用后应恢复原 process_mode。")


func test_can_disable_descendant_active_state_management() -> void:
	var nested_scene: PackedScene = _make_nested_control_scene()
	_pool.manage_descendant_active_state = false
	var root: Control = _acquire_control(nested_scene)
	var child: Control = _child_control(root, "Child")

	_pool.release(root, nested_scene)

	assert_false(root.visible, "关闭递归管理时仍应隐藏根节点。")
	assert_true(child.visible, "关闭递归管理时不应改写子节点 visible 属性。")
	assert_eq(child.process_mode, Node.PROCESS_MODE_INHERIT, "关闭递归管理时不应改写子节点 process_mode。")


## 验证 release 后再次 acquire 复用同一节点而不创建新实例。
func test_acquire_after_release_reuses_node() -> void:
	var node1: Node = _pool.acquire(_scene, _parent)
	_pool.release(node1, _scene)

	var node2: Node = _pool.acquire(_scene, _parent)

	assert_eq(node1, node2, "release 后再次 acquire 应复用同一节点。")


## 验证节点可通过 on_gf_pool_acquire/release hook 清理和重置自身状态。
func test_acquire_release_calls_node_hooks() -> void:
	var hooked_scene: PackedScene = _make_hooked_scene()
	var node: HookedNode = _acquire_hooked_node(hooked_scene)

	assert_eq(node.acquire_count, 1, "首次 acquire 应调用 on_gf_pool_acquire。")
	assert_eq(node.release_count, 0, "未 release 前不应调用 release hook。")

	_pool.release(node, hooked_scene)
	assert_eq(node.release_count, 1, "release 应调用 on_gf_pool_release。")

	var reused: HookedNode = _acquire_hooked_node(hooked_scene)
	assert_eq(reused, node, "hook 测试应复用同一节点。")
	assert_eq(reused.acquire_count, 2, "复用 acquire 应再次调用 on_gf_pool_acquire。")


func test_pooled_controller_events_pause_on_release_and_resume_on_acquire() -> void:
	var architecture: GFArchitecture = _setup_test_architecture()
	var controller_scene: PackedScene = _make_pooled_controller_scene()
	var controller: PooledEventController = _acquire_pooled_controller(controller_scene)

	architecture.send_simple_event(&"pooled_controller_event", "active")
	assert_eq(controller.payloads, ["active"], "Controller 激活时应接收事件。")

	_pool.release(controller, controller_scene)
	architecture.send_simple_event(&"pooled_controller_event", "pooled")
	assert_eq(controller.payloads, ["active"], "Controller 回收到对象池后不应继续接收事件。")

	var reused: PooledEventController = _acquire_pooled_controller(controller_scene)
	architecture.send_simple_event(&"pooled_controller_event", "reused")

	assert_eq(reused, controller, "Controller 应被对象池复用。")
	assert_eq(controller.payloads, ["active", "reused"], "Controller 复用后应恢复事件监听。")


func test_prewarmed_controller_events_stay_paused_until_acquire() -> void:
	var architecture: GFArchitecture = _setup_test_architecture()
	var controller_scene: PackedScene = _make_pooled_controller_scene()

	_pool.prewarm(controller_scene, _parent, 1)
	assert_eq(_pool.get_available_count(controller_scene), 1, "prewarm 后应有一个可用 Controller。")
	architecture.send_simple_event(&"pooled_controller_event", "prewarmed")

	var acquired: PooledEventController = _acquire_pooled_controller(controller_scene)
	assert_eq(acquired.payloads, [], "预热但未取出的 Controller 不应接收事件。")
	architecture.send_simple_event(&"pooled_controller_event", "active")

	assert_eq(acquired.payloads, ["active"], "Controller acquire 后应恢复事件监听。")


## 验证对有效池的连续 acquire/release 循环不产生额外实例。
func test_repeated_acquire_release_does_not_leak() -> void:
	var node: Node = _pool.acquire(_scene, _parent)
	_pool.release(node, _scene)

	var count_before: int = _parent.get_child_count()

	var _acquire_result_168: Variant = _pool.acquire(_scene, _parent)

	assert_eq(count_before, 0, "release 后节点应被移到对象池根节点，脱离原父节点。")
	assert_eq(_parent.get_child_count(), 1, "复用节点时应重新挂回请求的父节点。")


# --- 测试：prewarm ---

## 验证 prewarm 预先创建指定数量的节点并加入父节点。
func test_prewarm_creates_nodes_in_parent() -> void:
	_pool.prewarm(_scene, _parent, 3)

	assert_eq(_parent.get_child_count(), 3, "prewarm(3) 应在父节点下创建 3 个子节点。")


## 验证 prewarm 后可用节点数等于预热数量。
func test_prewarm_sets_available_count() -> void:
	_pool.prewarm(_scene, _parent, 5)

	assert_eq(_pool.get_available_count(_scene), 5, "prewarm(5) 后可用节点数应为 5。")


func test_prewarm_rejects_invalid_scene() -> void:
	_pool.prewarm(null, _parent, 1)

	assert_push_error("[GFObjectPoolUtility] 传入了无效的 PackedScene。")
	assert_eq(_parent.get_child_count(), 0, "无效 PackedScene 不应创建任何节点。")


func test_acquire_rejects_invalid_parent() -> void:
	var node: Node = _pool.acquire(_scene, null)

	assert_null(node, "parent 为空时 acquire 应返回 null。")
	assert_push_error("[GFObjectPoolUtility] acquire 失败：parent 无效。")
	assert_eq(_parent.get_child_count(), 0, "无效 parent 不应创建或挂载节点。")


func test_prewarm_async_batches_nodes() -> void:
	await _pool.prewarm_async(_scene, _parent, 3, 1)

	assert_eq(_parent.get_child_count(), 3, "prewarm_async 应完成指定数量的预热。")
	assert_eq(_pool.get_available_count(_scene), 3, "prewarm_async 后可用节点数应正确。")


func test_prewarm_async_stops_after_dispose() -> void:
	@warning_ignore("missing_await")
	_pool.prewarm_async(_scene, _parent, 5, 1)
	await get_tree().process_frame
	_pool.dispose()
	var count_after_dispose: int = _parent.get_child_count()

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(_parent.get_child_count() <= count_after_dispose, "dispose 后未完成的 prewarm_async 不应继续创建节点。")


func test_prewarm_async_budget_completes_nodes() -> void:
	await _pool.prewarm_async_budget(_scene, _parent, 3, 0.001)

	assert_eq(_parent.get_child_count(), 3, "prewarm_async_budget 应完成指定数量的预热。")
	assert_eq(_pool.get_available_count(_scene), 3, "prewarm_async_budget 后可用节点数应正确。")


func test_release_reparents_to_pool_root_and_survives_original_parent_free() -> void:
	var node: Node = _pool.acquire(_scene, _parent)
	_pool.release(node, _scene)

	assert_ne(node.get_parent(), _parent, "release 后节点不应继续挂在原父节点下。")
	assert_eq(_pool.get_available_count(_scene), 1, "release 后节点应进入可用池。")

	_parent.queue_free()
	await get_tree().process_frame
	var new_parent: Node = Node.new()
	add_child(new_parent)
	var reused: Node = _pool.acquire(_scene, new_parent)

	assert_eq(reused, node, "原父节点释放后，对象池仍应能复用已回收节点。")
	assert_eq(reused.get_parent(), new_parent, "复用时节点应挂到新的父节点。")

	new_parent.queue_free()
	await get_tree().process_frame


func test_max_available_per_scene_limits_retained_nodes() -> void:
	_pool.max_available_per_scene = 1
	var node_a: Node = _pool.acquire(_scene, _parent)
	var node_b: Node = _pool.acquire(_scene, _parent)

	_pool.release(node_a, _scene)
	_pool.release(node_b, _scene)

	assert_eq(_pool.get_available_count(_scene), 1, "超过容量上限的归还节点不应继续留在可用池。")


func test_release_over_capacity_detaches_rejected_node_immediately() -> void:
	_pool.max_available_per_scene = 1
	var node_a: Node = _pool.acquire(_scene, _parent)
	var node_b: Node = _pool.acquire(_scene, _parent)

	_pool.release(node_a, _scene)
	_pool.release(node_b, _scene)

	assert_null(node_b.get_parent(), "超过对象池容量的归还节点应立即脱离原父节点。")
	assert_eq(_parent.get_child_count(), 0, "超过容量的归还节点不应在原父节点残留到帧尾。")

	await get_tree().process_frame
	assert_false(is_instance_valid(node_b), "超过容量的归还节点下一帧应完成释放。")


func test_dispose_detaches_active_and_pooled_nodes_immediately() -> void:
	var active_node: Node = _pool.acquire(_scene, _parent)
	var pooled_node: Node = _pool.acquire(_scene, _parent)
	_pool.release(pooled_node, _scene)
	var pool_root: Node = pooled_node.get_parent()

	_pool.dispose()

	assert_null(active_node.get_parent(), "dispose 应立即移除仍在使用中的对象池节点。")
	assert_null(pooled_node.get_parent(), "dispose 应立即移除已回收的对象池节点。")
	assert_null(pool_root.get_parent(), "dispose 应立即移除对象池根节点。")
	assert_eq(_parent.get_child_count(), 0, "dispose 后业务父节点不应残留对象池节点。")

	await get_tree().process_frame
	assert_false(is_instance_valid(active_node), "dispose 后 active 节点下一帧应完成释放。")
	assert_false(is_instance_valid(pooled_node), "dispose 后 pooled 节点下一帧应完成释放。")
	assert_false(is_instance_valid(pool_root), "dispose 后对象池根节点下一帧应完成释放。")


# --- 测试：get_available_count ---

## 验证初始时可用数量为 0。
func test_initial_available_count_is_zero() -> void:
	assert_eq(_pool.get_available_count(_scene), 0, "初始时可用节点数应为 0。")


## 验证 acquire 后可用数量减少，release 后恢复。
func test_available_count_changes_with_acquire_release() -> void:
	_pool.prewarm(_scene, _parent, 2)
	assert_eq(_pool.get_available_count(_scene), 2, "预热 2 个后可用数应为 2。")

	var node: Node = _pool.acquire(_scene, _parent)
	assert_eq(_pool.get_available_count(_scene), 1, "acquire 一个后可用数应为 1。")

	_pool.release(node, _scene)
	assert_eq(_pool.get_available_count(_scene), 2, "release 后可用数应恢复为 2。")


func test_active_count_and_debug_snapshot_report_pool_state() -> void:
	var node: Node = _pool.acquire(_scene, _parent)
	var snapshot: Dictionary = _pool.get_debug_snapshot()
	var key: String = _pool_debug_key(_scene)
	var pool_entry: Dictionary = GFVariantData.get_option_dictionary(snapshot, key)

	assert_eq(_pool.get_active_count(_scene), 1, "acquire 后 active 数应为 1。")
	assert_eq(GFVariantData.get_option_int(pool_entry, "active"), 1, "诊断快照应包含 active 数。")
	assert_eq(GFVariantData.get_option_int(pool_entry, "available"), 0, "诊断快照应包含 available 数。")

	_pool.release(node, _scene)


func test_active_nodes_tolerates_stale_freed_node_when_auto_prune_disabled() -> void:
	_pool.prune_invalid_on_each_operation = false
	var node: Node = _pool.acquire(_scene, _parent)
	_parent.remove_child(node)
	node.free()

	assert_eq(_pool.get_active_nodes(_scene).size(), 0, "active 查询不应对已释放池节点执行类型转换。")
	assert_eq(_pool.get_active_count(_scene), 0, "active 计数应忽略已释放池节点。")


func test_disposed_pool_rejects_new_operations() -> void:
	_pool.dispose()

	var node: Node = _pool.acquire(_scene, _parent)

	assert_null(node, "dispose 后 acquire 应返回 null。")
	assert_push_warning("[GFObjectPoolUtility] 对象池已销毁，忽略 acquire。")


## 验证重复 release 同一个节点不会导致池内出现重复引用。
func test_double_release_is_ignored() -> void:
	var node: Node = _pool.acquire(_scene, _parent)

	_pool.release(node, _scene) # 第一下归还
	var count1: int = _pool.get_available_count(_scene)

	_pool.release(node, _scene) # 第二下归还应当被忽略
	var count2: int = _pool.get_available_count(_scene)

	assert_eq(count1, count2, "对同一个早已处于池中的节点重复 release，不应当增加可用节点计数。")

## 验证当对象池中含有被外部错误 queue_free 退出的游离旧节点时，acquire 不会崩溃。
func test_release_wrong_scene_returns_to_original_pool() -> void:
	var other_scene: PackedScene = _make_node_scene()
	var node: Node = _pool.acquire(_scene, _parent)

	_pool.release(node, other_scene)

	assert_eq(_pool.get_available_count(_scene), 1, "传错 scene 时，节点仍应回收到原始所属池。")
	assert_eq(_pool.get_available_count(other_scene), 0, "传错 scene 不应污染其他对象池。")
	assert_push_warning("[GFObjectPoolUtility] release 收到不匹配的 PackedScene，已回退到节点原始所属池。")


func test_acquire_invalid_freed_instance_is_safe() -> void:
	var node: Node = _pool.acquire(_scene, _parent)
	_pool.release(node, _scene)

	# 模拟外部错误地连带释放了已经被还回池子的节点
	node.free()

	# 如果没有安全类型推断和防崩溃处理，下面这行就会报错
	var new_node: Node = _pool.acquire(_scene, _parent)
	var snapshot: Dictionary = _pool.get_debug_snapshot()
	var key: String = _pool_debug_key(_scene)
	var pool_entry: Dictionary = GFVariantData.get_option_dictionary(snapshot, key)

	assert_not_null(new_node, "池内存在非法实例时，acquire 应该平稳度过并返回一个新的有效实例。")
	assert_true(is_instance_valid(new_node), "新获得的 node 应该是有效的新实例。")
	assert_ne(new_node, node, "新实例不能是那个被强制 free 的原实例。")
	assert_eq(GFVariantData.get_option_int(pool_entry, "total"), 1, "清理无效实例后，全量池中不应继续保留死对象引用。")


# --- 私有/辅助方法 ---

## 创建一个最简 PackedScene（仅包含一个根 Node），用于测试。
func _make_node_scene() -> PackedScene:
	var node: Node = Node.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(node)
	node.free()
	return scene


## 创建一个 Control PackedScene，用于验证可见性和 process_mode 回收状态。
func _make_control_scene() -> PackedScene:
	var control: Control = Control.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(control)
	control.free()
	return scene


## 创建一个带子节点的 Control PackedScene。
func _make_nested_control_scene() -> PackedScene:
	var root: Control = Control.new()
	var child: Control = Control.new()
	child.name = "Child"
	root.add_child(child)
	child.owner = root
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(root)
	root.free()
	return scene


## 创建一个带对象池 hook 的 PackedScene。
func _make_hooked_scene() -> PackedScene:
	var node: HookedNode = HookedNode.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(node)
	node.free()
	return scene


## 创建一个会在 _ready 注册轻量事件的 GFController PackedScene。
func _make_pooled_controller_scene() -> PackedScene:
	var node: PooledEventController = PooledEventController.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(node)
	node.free()
	return scene


func _setup_test_architecture() -> GFArchitecture:
	_test_architecture = GFArchitecture.new()
	Gf._architecture = _test_architecture
	return _test_architecture


func _acquire_control(scene: PackedScene) -> Control:
	var node: Node = _pool.acquire(scene, _parent)
	if node is Control:
		var control: Control = node
		return control
	return null


func _child_control(root: Node, child_path: NodePath) -> Control:
	var node: Node = root.get_node(child_path)
	if node is Control:
		var control: Control = node
		return control
	return null


func _acquire_hooked_node(scene: PackedScene) -> HookedNode:
	var node: Node = _pool.acquire(scene, _parent)
	if node is HookedNode:
		var hooked_node: HookedNode = node
		return hooked_node
	return null


func _acquire_pooled_controller(scene: PackedScene) -> PooledEventController:
	var node: Node = _pool.acquire(scene, _parent)
	if node is PooledEventController:
		var controller: PooledEventController = node
		return controller
	return null


func _pool_debug_key(scene: PackedScene) -> String:
	return "PackedScene:%d" % scene.get_instance_id()


# --- 内部类 ---

class HookedNode extends Node:
	var acquire_count: int = 0
	var release_count: int = 0

	func on_gf_pool_acquire() -> void:
		acquire_count += 1

	func on_gf_pool_release() -> void:
		release_count += 1


class PooledEventController extends GFController:
	var payloads: Array[Variant] = []

	func _ready() -> void:
		register_simple_event(&"pooled_controller_event", _on_pooled_controller_event)

	func _on_pooled_controller_event(payload: Variant) -> void:
		payloads.append(payload)
