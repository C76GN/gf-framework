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
	GFAutoload.reset_tree_exit_state()
	InstantiationLifecycleNode.pool = null
	InstantiationLifecycleNode.restart_pool = false
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


func test_acquire_runs_before_add_callback_before_ready() -> void:
	var ready_scene: PackedScene = _make_ready_check_scene()

	var node: Node = _pool.acquire(ready_scene, _parent, func(ready_node: Node) -> void:
		ready_node.set_meta(&"prepared_before_ready", true)
	)
	var ready_check: ReadyCheckNode = _ready_check_node(node)

	assert_not_null(ready_check, "测试场景应实例化为 ReadyCheckNode。")
	if ready_check == null:
		return
	assert_true(ready_check.prepared_in_ready, "before_add 回调应先于 _ready() 执行。")


func test_acquire_discards_candidate_when_instantiation_restarts_pool() -> void:
	var lifecycle_scene: PackedScene = _make_instantiation_lifecycle_scene()
	InstantiationLifecycleNode.pool = _pool
	InstantiationLifecycleNode.restart_pool = true

	var node: Node = _pool.acquire(lifecycle_scene, _parent)
	InstantiationLifecycleNode.pool = null
	InstantiationLifecycleNode.restart_pool = false

	assert_null(node, "instantiate 重启对象池后，旧 acquire 不得发布候选。")
	assert_eq(_parent.get_child_count(), 0, "失效 instantiate 候选不得挂到请求父节点。")
	assert_eq(_pool.get_active_count(lifecycle_scene), 0, "重启后不得残留旧代次 active 借用。")
	assert_eq(_pool.get_available_count(lifecycle_scene), 0, "重启后不得提交旧代次 available 候选。")


func test_acquire_rejects_parent_queued_for_deletion() -> void:
	var queued_parent: Node = Node.new()
	add_child(queued_parent)
	queued_parent.queue_free()

	var node: Node = _pool.acquire(_scene, queued_parent)

	assert_null(node, "已排队删除的 parent 不得接收新的借用节点。")
	assert_push_error("[GFObjectPoolUtility] acquire 失败：parent 无效。")


func test_before_add_queued_parent_cancels_acquire() -> void:
	var node: Node = _pool.acquire(_scene, _parent, func(_candidate: Node) -> void:
		_parent.queue_free()
	)

	assert_null(node, "before_add 排队删除 parent 后，旧 acquire 不得发布节点。")
	assert_eq(_pool.get_active_count(_scene), 0, "取消 acquire 后不得保留 active 节点。")
	assert_eq(_pool.get_available_count(_scene), 1, "取消 acquire 后候选应安全归还对象池。")


# --- 测试：release ---

## 验证 release 后节点的 metadata 被标记为未激活。
func test_release_marks_node_inactive() -> void:
	var node: Node = _pool.acquire(_scene, _parent)
	_pool.release(node, _scene)

	assert_eq(_pool.get_active_count(_scene), 0, "release 后对象池不应继续报告激活节点。")
	assert_eq(_pool.get_available_count(_scene), 1, "release 后节点应进入可用池。")


func test_lost_lease_retirement_requires_exact_invalid_active_identity() -> void:
	var lost_scene: PackedScene = _make_lifecycle_hook_scene()
	var wrong_scene: PackedScene = _make_node_scene()
	var node: LifecycleHookNode = _acquire_lifecycle_hook_node(lost_scene)
	var hook_log: Array[StringName] = node.event_log
	var instance_id: int = node.get_instance_id()

	assert_false(
		_pool.retire_lost_lease_for_framework(lost_scene, instance_id),
		"live lease（包括潜在 id-reuse）不得被 lost-lease 入口结算。"
	)
	assert_false(_pool.retire_lost_lease_for_framework(wrong_scene, instance_id))
	assert_false(_pool.retire_lost_lease_for_framework(lost_scene, instance_id + 1))
	node.free()

	assert_false(
		_pool.retire_lost_lease_for_framework(wrong_scene, instance_id),
		"scene 与 id 必须同时匹配 acquire owner linkage。"
	)
	assert_true(
		_pool.retire_lost_lease_for_framework(lost_scene, instance_id),
		"已同步销毁的精确 ACTIVE lease 必须无 hook 地首次结算。"
	)
	assert_false(
		_pool.retire_lost_lease_for_framework(lost_scene, instance_id),
		"lost lease 结算必须幂等，重复调用返回 false。"
	)
	var snapshot: Dictionary = _pool.get_debug_snapshot()
	var scene_snapshot: Dictionary = GFVariantData.get_option_dictionary(
		snapshot,
		_pool_debug_key(lost_scene)
	)
	assert_eq(GFVariantData.get_option_int(scene_snapshot, "total", -1), 0)
	assert_eq(GFVariantData.get_option_int(scene_snapshot, "active", -1), 0)
	assert_eq(GFVariantData.get_option_int(scene_snapshot, "available", -1), 0)
	assert_true(hook_log.is_empty(), "lost-lease 结算不得执行 public/internal release hook。")


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


func test_visible_setter_release_stops_stale_descendant_activation() -> void:
	var control_scene: PackedScene = _make_visibility_release_scene()
	var node: VisibilityReleaseControl = _visibility_release_control(
		_pool.acquire(control_scene, _parent)
	)
	var child: Control = _child_control(node, "Child")
	_pool.release(node, control_scene)

	var cancelled: Node = _pool.acquire(
		control_scene,
		_parent,
		func(candidate: Node) -> void:
			var root: VisibilityReleaseControl = _visibility_release_control(candidate)
			root.pool = _pool
			root.pool_scene = control_scene
			root.release_on_visibility = true
	)

	assert_null(cancelled, "visible setter 重入 release 后，旧 acquire 必须失效。")
	assert_eq(_pool.get_active_count(control_scene), 0, "setter 重入后不得保留 active 节点。")
	assert_eq(_pool.get_available_count(control_scene), 1, "setter 重入后节点应只归还一次。")
	assert_false(node.visible, "重入 release 的根节点应保持隐藏。")
	assert_false(child.visible, "旧激活遍历不得在重入 release 后重新显示子节点。")
	assert_eq(child.process_mode, Node.PROCESS_MODE_DISABLED, "旧激活遍历不得重新启用子节点。")


func test_release_snapshots_runtime_child_before_root_setter_mutates_it() -> void:
	var control_scene: PackedScene = _make_control_scene()
	var root: Control = _acquire_control(control_scene)
	var runtime_child: Control = Control.new()
	runtime_child.visible = true
	root.add_child(runtime_child)
	var _connection_error: Error = root.visibility_changed.connect(func() -> void:
		if not root.visible:
			runtime_child.visible = false
	) as Error

	_pool.release(root, control_scene)
	var reused: Control = _acquire_control(control_scene)

	assert_eq(reused, root, "快照测试应复用同一根节点。")
	assert_true(runtime_child.visible, "根 setter 修改子节点前必须先保存整棵树的原始状态。")


func test_state_phase_snapshots_sibling_added_by_prepare_getter() -> void:
	var control_scene: PackedScene = _make_control_scene()
	var root: Control = _acquire_control(control_scene)
	var spawner: PrepareSiblingSpawner = PrepareSiblingSpawner.new()
	spawner.spawn_parent = root
	root.add_child(spawner)

	_pool.release(root, control_scene)
	var spawned: Control = spawner.spawned
	assert_not_null(spawned, "PREPARE getter 应动态添加测试 sibling。")
	assert_false(spawned.visible, "release 状态阶段应隐藏动态 sibling。")

	var reused: Control = _acquire_control(control_scene)

	assert_eq(reused, root, "动态 sibling 快照测试应复用同一根节点。")
	assert_true(spawned.visible, "状态阶段首次看到 sibling 时必须补采原始快照。")


func test_release_manages_runtime_internal_children() -> void:
	var control_scene: PackedScene = _make_control_scene()
	var node: Control = _acquire_control(control_scene)
	var internal_child: Control = Control.new()
	internal_child.visible = true
	node.add_child(internal_child, false, Node.INTERNAL_MODE_FRONT)

	_pool.release(node, control_scene)

	assert_false(internal_child.visible, "release 应隐藏 internal child。")
	assert_eq(internal_child.process_mode, Node.PROCESS_MODE_DISABLED, "release 应禁用 internal child 处理。")

	var reused: Control = _acquire_control(control_scene)

	assert_eq(reused, node, "internal child 测试应复用同一节点。")
	assert_true(internal_child.visible, "acquire 应恢复 internal child 可见性。")
	assert_eq(internal_child.process_mode, Node.PROCESS_MODE_INHERIT, "acquire 应恢复 internal child process_mode。")


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


func test_reused_node_before_add_release_wins_without_double_loan() -> void:
	var node: Node = _pool.acquire(_scene, _parent)
	_pool.release(node, _scene)

	var cancelled_acquire: Node = _pool.acquire(
		_scene,
		_parent,
		func(reused_node: Node) -> void:
			_pool.release(reused_node, _scene)
	)

	assert_null(cancelled_acquire, "before_add 已归还复用节点时，外层 acquire 不得发布同一借用。")
	assert_eq(_pool.get_active_count(_scene), 0, "callback 归还后不应保留 active 节点。")
	assert_eq(_pool.get_available_count(_scene), 1, "callback 归还后节点应恰好进入 available 一次。")

	var next_acquire: Node = _pool.acquire(_scene, _parent)
	assert_eq(next_acquire, node, "下一次 acquire 可以安全复用已归还节点。")
	assert_eq(_pool.get_active_count(_scene), 1, "复用节点只能有一个 active borrower。")
	assert_eq(_pool.get_available_count(_scene), 0, "active 节点不能同时留在 available。")


func test_prewarmed_candidate_before_add_init_discards_stale_node() -> void:
	_pool.prewarm(_scene, _parent, 1)
	var candidate: Node = _parent.get_child(0)

	var cancelled_acquire: Node = _pool.acquire(
		_scene,
		_parent,
		func(_reused_node: Node) -> void:
			_pool.init()
	)

	assert_null(cancelled_acquire, "before_add 重启池后，旧预热候选不得发布。")
	assert_eq(_parent.get_child_count(), 0, "跨生命周期候选必须从外部 parent 脱离。")
	assert_true(candidate.is_queued_for_deletion(), "跨生命周期候选必须被废弃。")
	assert_eq(_pool.get_active_count(_scene), 0, "新生命周期不得追踪旧候选。")
	assert_eq(_pool.get_available_count(_scene), 0, "旧候选不得进入新生命周期 available。")


func test_node_acquire_hook_release_wins_without_double_loan() -> void:
	var hooked_scene: PackedScene = _make_hooked_scene()
	var node: HookedNode = _acquire_hooked_node(hooked_scene)
	_pool.release(node, hooked_scene)
	node.pool = _pool
	node.pool_scene = hooked_scene
	node.release_on_acquire = true

	var cancelled_acquire: Node = _pool.acquire(hooked_scene, _parent)

	assert_null(cancelled_acquire, "acquire hook 已归还节点时，外层 acquire 不得发布同一借用。")
	assert_eq(_pool.get_active_count(hooked_scene), 0, "hook 归还后不应保留 active 节点。")
	assert_eq(_pool.get_available_count(hooked_scene), 1, "hook 归还后节点应恰好进入 available 一次。")

	node.release_on_acquire = false
	var next_acquire: Node = _pool.acquire(hooked_scene, _parent)
	assert_eq(next_acquire, node, "下一次 acquire 可以安全复用 hook 已归还节点。")
	assert_eq(_pool.get_active_count(hooked_scene), 1, "复用节点只能有一个 active borrower。")
	assert_eq(_pool.get_available_count(hooked_scene), 0, "active 节点不能同时留在 available。")
	node.pool = null
	node.pool_scene = null


func test_acquire_hook_release_stops_stale_descendant_acquire_hook() -> void:
	var hooked_scene: PackedScene = _make_nested_hooked_scene()
	var node: HookedNode = _acquire_hooked_node(hooked_scene)
	var child: HookedNode = _child_hooked_node(node, "Child")
	_pool.release(node, hooked_scene)
	node.acquire_count = 0
	node.release_count = 0
	child.acquire_count = 0
	child.release_count = 0
	node.pool = _pool
	node.pool_scene = hooked_scene
	node.release_on_acquire = true

	var cancelled_acquire: Node = _pool.acquire(hooked_scene, _parent)

	assert_null(cancelled_acquire, "根 hook 已归还节点时，旧 acquire 必须失效。")
	assert_eq(node.acquire_count, 1, "根节点应只执行触发归还的 acquire hook。")
	assert_eq(node.release_count, 1, "重入 release 应执行根节点 release hook。")
	assert_eq(child.release_count, 1, "重入 release 应完成子节点 release hook。")
	assert_eq(child.acquire_count, 0, "旧 acquire 失效后不得继续调用子节点 acquire hook。")
	node.release_on_acquire = false
	node.pool = null
	node.pool_scene = null


func test_internal_acquire_hook_queued_parent_stops_public_and_child_hooks() -> void:
	var hooked_scene: PackedScene = _make_lifecycle_hook_scene()
	var event_log: Array[StringName] = []

	var cancelled_acquire: Node = _pool.acquire(
		hooked_scene,
		_parent,
		func(candidate: Node) -> void:
			if not (candidate is LifecycleHookNode):
				return
			var root: LifecycleHookNode = candidate
			var child: LifecycleHookNode = _child_lifecycle_hook_node(root, "Child")
			root.acquire_event_log = event_log
			root.acquire_event_label = &"root"
			root.parent_to_queue_on_internal_acquire = _parent
			child.acquire_event_log = event_log
			child.acquire_event_label = &"child"
	)

	assert_null(cancelled_acquire, "internal acquire hook 排队删除 parent 后旧借用必须失效。")
	assert_eq(
		event_log,
		[&"root_internal_acquire"],
		"parent 失效后不得继续根 public 或子节点 acquire hook。"
	)
	assert_eq(_pool.get_active_count(hooked_scene), 0, "失效 acquire 不得保留 active 节点。")
	assert_eq(_pool.get_available_count(hooked_scene), 1, "同生命周期候选应安全归还池中。")


func test_node_release_hook_reentry_is_rejected_without_duplicate_available_entry() -> void:
	var hooked_scene: PackedScene = _make_hooked_scene()
	var node: HookedNode = _acquire_hooked_node(hooked_scene)
	node.pool = _pool
	node.pool_scene = hooked_scene
	node.release_on_release = true

	_pool.release(node, hooked_scene)

	assert_eq(node.release_count, 1, "release hook 的同项重入必须在再次调用 hook 前被拒绝。")
	assert_eq(_pool.get_active_count(hooked_scene), 0, "release 完成后不应保留 active 节点。")
	assert_eq(_pool.get_available_count(hooked_scene), 1, "节点只能进入 available 一次。")
	node.pool = null
	node.pool_scene = null


func test_release_hook_dispose_stops_internal_and_descendant_hooks() -> void:
	var hooked_scene: PackedScene = _make_lifecycle_hook_scene()
	var node: LifecycleHookNode = _acquire_lifecycle_hook_node(hooked_scene)
	var child: LifecycleHookNode = _child_lifecycle_hook_node(node, "Child")
	var event_log: Array[StringName] = []
	node.event_log = event_log
	node.event_label = &"root"
	node.pool = _pool
	node.dispose_on_release = true
	child.event_log = event_log
	child.event_label = &"child"

	_pool.release(node, hooked_scene)

	assert_eq(
		event_log,
		[&"root_public_release"],
		"dispose 使 release 失效后，不得继续根 internal 或子节点 hook。"
	)
	assert_eq(_pool.get_active_count(hooked_scene), 0, "dispose 后不得保留 active 节点。")
	assert_eq(_pool.get_available_count(hooked_scene), 0, "dispose 后不得提交 available 节点。")


func test_release_hook_init_discards_untracked_root() -> void:
	var hooked_scene: PackedScene = _make_lifecycle_hook_scene()
	var node: LifecycleHookNode = _acquire_lifecycle_hook_node(hooked_scene)
	node.pool = _pool
	node.init_on_release = true

	_pool.release(node, hooked_scene)

	assert_eq(_parent.get_child_count(), 0, "release hook 重启池后必须移除外部 parent 下的旧根节点。")
	assert_true(node.is_queued_for_deletion(), "release 失效后的跨生命周期根节点必须被废弃。")
	assert_eq(_pool.get_active_count(hooked_scene), 0, "新生命周期不得追踪旧 active 节点。")
	assert_eq(_pool.get_available_count(hooked_scene), 0, "旧节点不得进入新生命周期 available。")


func test_pooled_controller_events_pause_on_release_and_resume_on_acquire() -> void:
	var architecture: GFArchitecture = _setup_test_architecture()
	assert_true(
		await architecture.init(),
		"对象池 Controller 事件测试必须先完成 Architecture activation。"
	)
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
	assert_true(
		await architecture.init(),
		"对象池预热事件测试必须先完成 Architecture activation。"
	)
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


func test_prewarm_internal_release_dispose_stops_descendant_hook() -> void:
	var hooked_scene: PackedScene = _make_lifecycle_hook_scene()
	var event_log: Array[StringName] = []
	_pool.prewarm(hooked_scene, _parent, 1, func(candidate: Node) -> void:
		if not (candidate is LifecycleHookNode):
			return
		var node: LifecycleHookNode = candidate
		var child: LifecycleHookNode = _child_lifecycle_hook_node(node, "Child")
		node.event_log = event_log
		node.event_label = &"root"
		node.pool = _pool
		node.dispose_on_internal_release = true
		child.event_log = event_log
		child.event_label = &"child"
	)

	assert_eq(
		event_log,
		[&"root_internal_release"],
		"prewarm 的根 internal hook dispose 后不得继续子节点 hook。"
	)
	assert_eq(_pool.get_available_count(hooked_scene), 0, "失效 prewarm 不得提交候选。")


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


func test_concurrent_async_prewarms_share_capacity() -> void:
	_pool.max_available_per_scene = 4
	@warning_ignore("missing_await")
	_pool.prewarm_async(_scene, _parent, 4, 1)
	assert_eq(_pool.get_available_count(_scene), 1, "首个异步预热应在首次让帧前创建一个节点。")

	@warning_ignore("missing_await")
	_pool.prewarm_async(_scene, _parent, 4, 1)
	for _frame: int in range(8):
		await get_tree().process_frame

	assert_eq(_pool.get_available_count(_scene), 4, "并发异步预热必须共享同一场景的容量准入。")


func test_sync_prewarm_cannot_consume_async_reserved_capacity() -> void:
	_pool.max_available_per_scene = 4
	@warning_ignore("missing_await")
	_pool.prewarm_async(_scene, _parent, 4, 1)

	_pool.prewarm(_scene, _parent, 4)
	for _frame: int in range(6):
		await get_tree().process_frame

	assert_eq(_pool.get_available_count(_scene), 4, "同步预热不能占用异步请求尚未创建的预留容量。")


func test_sync_prewarm_cannot_consume_budgeted_reserved_capacity() -> void:
	_pool.max_available_per_scene = 4
	@warning_ignore("missing_await")
	_pool.prewarm_async_budget(
		_scene,
		_parent,
		4,
		0.001,
		Callable(self, &"_consume_prewarm_frame_budget")
	)
	assert_eq(_pool.get_available_count(_scene), 1, "budget 预热应在耗尽首帧预算后保留未提交预留。")

	_pool.prewarm(_scene, _parent, 4)
	for _frame: int in range(8):
		await get_tree().process_frame

	assert_eq(_pool.get_available_count(_scene), 4, "同步预热不能占用 budget 请求跨帧持有的容量预留。")


func test_budgeted_prewarm_cannot_reenter_sync_reservation() -> void:
	_pool.max_available_per_scene = 4
	var reentry_state: Array[bool] = [false]
	_pool.prewarm(_scene, _parent, 4, func(_node: Node) -> void:
		if reentry_state[0]:
			return
		reentry_state[0] = true
		@warning_ignore("missing_await")
		_pool.prewarm_async_budget(_scene, _parent, 4, 0.001)
	)

	for _frame: int in range(8):
		await get_tree().process_frame

	assert_eq(_pool.get_available_count(_scene), 4, "budget 预热重入时必须服从同步请求已取得的容量预留。")


func test_unbounded_prewarm_tracks_reservation_if_limit_is_enabled_reentrantly() -> void:
	_pool.max_available_per_scene = 0
	var reentry_state: Array[bool] = [false]
	_pool.prewarm(_scene, _parent, 4, func(_node: Node) -> void:
		if reentry_state[0]:
			return
		reentry_state[0] = true
		_pool.max_available_per_scene = 4
		_pool.prewarm(_scene, _parent, 4)
	)

	assert_eq(_pool.get_available_count(_scene), 4, "无限容量下开始的请求也必须登记预留，供重入启用上限时复验。")


func test_release_can_fill_capacity_before_prewarm_commit() -> void:
	_pool.max_available_per_scene = 1
	var active_node: Node = _pool.acquire(_scene, _parent)
	var rejected_candidates: Array[Variant] = []
	_pool.prewarm(_scene, _parent, 1, func(candidate: Node) -> void:
		rejected_candidates.append(candidate)
		_pool.release(active_node, _scene)
	)

	assert_eq(_pool.get_available_count(_scene), 1, "归还节点先填满实际容量时，预留候选不得无条件提交。")
	await get_tree().process_frame
	assert_eq(rejected_candidates.size(), 1, "测试应观察到一个未提交候选。")
	assert_false(is_instance_valid(rejected_candidates[0]), "失去容量的预热候选必须被释放。")


func test_async_prewarm_rechecks_lowered_capacity_after_yield() -> void:
	_pool.max_available_per_scene = 4
	@warning_ignore("missing_await")
	_pool.prewarm_async(_scene, _parent, 4, 1)
	assert_eq(_pool.get_available_count(_scene), 1, "异步预热应先创建一个节点再让帧。")

	_pool.max_available_per_scene = 2
	for _frame: int in range(6):
		await get_tree().process_frame

	assert_eq(_pool.get_available_count(_scene), 2, "运行中缩小容量后，旧预热计划不能继续写穿新上限。")


func test_invalidated_parent_releases_reservation_for_retry() -> void:
	_pool.max_available_per_scene = 2
	var invalidated_parent: Node = _parent
	var rejected_candidates: Array[Variant] = []
	_pool.prewarm(_scene, invalidated_parent, 2, func(candidate: Node) -> void:
		rejected_candidates.append(candidate)
		invalidated_parent.queue_free()
	)

	_parent = Node.new()
	add_child(_parent)
	_pool.prewarm(_scene, _parent, 2)
	await get_tree().process_frame

	assert_eq(_pool.get_available_count(_scene), 2, "父节点失效后必须释放全部未提交预留，使同场景可完整重试。")
	assert_false(is_instance_valid(rejected_candidates[0]), "父节点失效时尚未挂树的候选必须被释放。")


func test_sync_prewarm_rejects_stale_generation_after_reentrant_init() -> void:
	_pool.max_available_per_scene = 2
	var restart_state: Array[bool] = [false]
	var stale_candidates: Array[Variant] = []
	_pool.prewarm(_scene, _parent, 2, func(candidate: Node) -> void:
		if restart_state[0]:
			return
		restart_state[0] = true
		stale_candidates.append(candidate)
		_pool.dispose()
		_pool.init()
		_pool.max_available_per_scene = 2
		@warning_ignore("missing_await")
		_pool.prewarm_async(_scene, _parent, 2, 1)
	)

	assert_eq(_pool.get_available_count(_scene), 1, "新生命周期应保留一个尚未提交的异步预留。")
	_pool.prewarm(_scene, _parent, 2)
	assert_eq(_pool.get_available_count(_scene), 1, "旧代清理不得扣减新代 pending 预留并放开重复准入。")

	for _frame: int in range(4):
		await get_tree().process_frame

	assert_eq(_pool.get_available_count(_scene), 2, "dispose/init 后旧代同步预热不能写入新代对象池。")
	assert_eq(_parent.get_child_count(), 2, "旧代候选节点必须被释放，不能混入新代父节点。")
	assert_false(is_instance_valid(stale_candidates[0]), "dispose/init 前创建的 provisional 节点不得泄漏。")


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


func test_init_preserves_active_borrowed_node_while_clearing_pool_tracking() -> void:
	var active_node: Node = _pool.acquire(_scene, _parent)

	_pool.init()

	assert_eq(active_node.get_parent(), _parent, "init 不应移除业务父节点下已借出的节点。")
	assert_false(active_node.is_queued_for_deletion(), "init 不应释放已借出的节点。")
	assert_eq(_pool.get_active_count(_scene), 0, "init 应清空旧生命周期的 active 追踪。")
	await get_tree().process_frame
	assert_true(is_instance_valid(active_node), "init 后已借出的节点应继续由调用方持有。")


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


func test_dispose_leaves_pool_nodes_attached_during_autoload_tree_exit() -> void:
	var active_node: Node = _pool.acquire(_scene, _parent)
	var pool_root: Node = _pool._ensure_pool_root()
	GFAutoload.begin_tree_exit_scope()

	_pool.dispose()

	assert_eq(active_node.get_parent(), _parent, "AutoLoad 退出时不应主动从业务父节点 remove_child。")
	assert_not_null(pool_root.get_parent(), "AutoLoad 退出时对象池根节点应继续由树持有。")

	GFAutoload.end_tree_exit_scope()
	await get_tree().process_frame
	assert_false(is_instance_valid(active_node), "退出阶段登记 queue_free 后 active 节点仍应释放。")
	assert_false(is_instance_valid(pool_root), "退出阶段登记 queue_free 后对象池根节点仍应释放。")


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

func _consume_prewarm_frame_budget(_node: Node) -> void:
	var deadline_usec: int = Time.get_ticks_usec() + 1000
	while Time.get_ticks_usec() < deadline_usec:
		pass


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


func _make_nested_hooked_scene() -> PackedScene:
	var root: HookedNode = HookedNode.new()
	var child: HookedNode = HookedNode.new()
	child.name = "Child"
	root.add_child(child)
	child.owner = root
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(root)
	root.free()
	return scene


func _make_lifecycle_hook_scene() -> PackedScene:
	var root: LifecycleHookNode = LifecycleHookNode.new()
	var child: LifecycleHookNode = LifecycleHookNode.new()
	child.name = "Child"
	root.add_child(child)
	child.owner = root
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(root)
	root.free()
	return scene


func _make_ready_check_scene() -> PackedScene:
	var node: ReadyCheckNode = ReadyCheckNode.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(node)
	node.free()
	return scene


func _make_instantiation_lifecycle_scene() -> PackedScene:
	var node: InstantiationLifecycleNode = InstantiationLifecycleNode.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(node)
	node.free()
	return scene


func _make_visibility_release_scene() -> PackedScene:
	var root: VisibilityReleaseControl = VisibilityReleaseControl.new()
	var child: Control = Control.new()
	child.name = "Child"
	root.add_child(child)
	child.owner = root
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(root)
	root.free()
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


func _child_hooked_node(root: Node, child_path: NodePath) -> HookedNode:
	var node: Node = root.get_node(child_path)
	if node is HookedNode:
		var hooked_node: HookedNode = node
		return hooked_node
	return null


func _child_lifecycle_hook_node(root: Node, child_path: NodePath) -> LifecycleHookNode:
	var node: Node = root.get_node(child_path)
	if node is LifecycleHookNode:
		var hooked_node: LifecycleHookNode = node
		return hooked_node
	return null


func _acquire_hooked_node(scene: PackedScene) -> HookedNode:
	var node: Node = _pool.acquire(scene, _parent)
	if node is HookedNode:
		var hooked_node: HookedNode = node
		return hooked_node
	return null


func _acquire_lifecycle_hook_node(scene: PackedScene) -> LifecycleHookNode:
	var node: Node = _pool.acquire(scene, _parent)
	if node is LifecycleHookNode:
		var hooked_node: LifecycleHookNode = node
		return hooked_node
	return null


func _acquire_pooled_controller(scene: PackedScene) -> PooledEventController:
	var node: Node = _pool.acquire(scene, _parent)
	if node is PooledEventController:
		var controller: PooledEventController = node
		return controller
	return null


func _ready_check_node(value: Variant) -> ReadyCheckNode:
	if value is ReadyCheckNode:
		var node: ReadyCheckNode = value
		return node
	return null


func _visibility_release_control(value: Variant) -> VisibilityReleaseControl:
	if value is VisibilityReleaseControl:
		var control: VisibilityReleaseControl = value
		return control
	return null


func _pool_debug_key(scene: PackedScene) -> String:
	return "PackedScene:%d" % scene.get_instance_id()


# --- 内部类 ---

class HookedNode extends Node:
	var acquire_count: int = 0
	var release_count: int = 0
	var pool: GFObjectPoolUtility = null
	var pool_scene: PackedScene = null
	var release_on_acquire: bool = false
	var release_on_release: bool = false
	var release_reentered: bool = false

	func on_gf_pool_acquire() -> void:
		acquire_count += 1
		if release_on_acquire and pool != null:
			pool.release(self, pool_scene)

	func on_gf_pool_release() -> void:
		release_count += 1
		if release_on_release and not release_reentered and pool != null:
			release_reentered = true
			pool.release(self, pool_scene)


class LifecycleHookNode extends Node:
	var event_log: Array[StringName] = []
	var event_label: StringName = &""
	var acquire_event_log: Array[StringName] = []
	var acquire_event_label: StringName = &""
	var pool: GFObjectPoolUtility = null
	var parent_to_queue_on_internal_acquire: Node = null
	var dispose_on_release: bool = false
	var dispose_on_internal_release: bool = false
	var init_on_release: bool = false

	func _gf_on_object_pool_acquire() -> void:
		acquire_event_log.append(StringName("%s_internal_acquire" % String(acquire_event_label)))
		if parent_to_queue_on_internal_acquire != null:
			parent_to_queue_on_internal_acquire.queue_free()

	func on_gf_pool_acquire() -> void:
		acquire_event_log.append(StringName("%s_public_acquire" % String(acquire_event_label)))

	func on_gf_pool_release() -> void:
		event_log.append(StringName("%s_public_release" % String(event_label)))
		if pool != null:
			if init_on_release:
				pool.init()
			elif dispose_on_release:
				pool.dispose()

	func _gf_on_object_pool_release() -> void:
		event_log.append(StringName("%s_internal_release" % String(event_label)))
		if dispose_on_internal_release and pool != null:
			pool.dispose()


class InstantiationLifecycleNode extends Node:
	static var pool: GFObjectPoolUtility = null
	static var restart_pool: bool = false

	func _init() -> void:
		if pool == null:
			return
		pool.dispose()
		if restart_pool:
			pool.init()


class VisibilityReleaseControl extends Control:
	var pool: GFObjectPoolUtility = null
	var pool_scene: PackedScene = null
	var release_on_visibility: bool = false
	var release_reentered: bool = false

	func _init() -> void:
		var _connection_error: Error = visibility_changed.connect(_on_visibility_changed) as Error

	func _on_visibility_changed() -> void:
		if not release_on_visibility or release_reentered or pool == null:
			return
		release_reentered = true
		pool.release(self, pool_scene)


class PrepareSiblingSpawner extends Node:
	var spawn_parent: Node = null
	var spawned: Control = null
	var disabled: bool:
		get:
			if spawned == null and spawn_parent != null:
				spawned = Control.new()
				spawned.visible = true
				spawn_parent.add_child(spawned)
			return false
		set(_value):
			pass


class ReadyCheckNode extends Node:
	var prepared_in_ready: bool = false

	func _ready() -> void:
		prepared_in_ready = GFVariantData.to_bool(get_meta(&"prepared_before_ready", false), false)


class PooledEventController extends GFController:
	var payloads: Array[Variant] = []

	func _ready() -> void:
		register_simple_event(
			&"pooled_controller_event",
			GFEventListener.from_method(self, &"_on_pooled_controller_event", 1)
		)

	func _on_pooled_controller_event(payload: Variant) -> void:
		payloads.append(payload)
