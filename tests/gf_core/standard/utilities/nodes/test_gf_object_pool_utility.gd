## 验证 GFObjectPoolUtility 的结构化借用、Lease 生命周期与物理安全点。
extends GutTest


# --- 私有变量 ---

var _pool: GFObjectPoolUtility
var _parent: Node
var _scene: PackedScene


# --- GUT 生命周期方法 ---

func before_each() -> void:
	_pool = GFObjectPoolUtility.new()
	_pool.init()
	_parent = Node.new()
	add_child(_parent)
	_scene = _make_node_scene()


func after_each() -> void:
	PrepareLifecycleNode.source_context = {}
	PrepareLifecycleNode.expected_object = null
	ReparentingPrepareNode.target_parent = null
	DisposingPrepareNode.pool = null
	CandidateEnterTreeHijackerNode.prepared_nodes.clear()
	CandidateEnterTreeHijackerNode.target_parent = null
	if _pool != null:
		_pool.dispose()
		await _pool.wait_disposed()
	_pool = null
	if is_instance_valid(_parent) and not _parent.is_queued_for_deletion():
		_parent.queue_free()
	_parent = null
	_scene = null
	await get_tree().process_frame


# --- 测试：借用结果 ---

func test_acquire_returns_structured_success_and_attached_lease() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)

	_assert_acquire_result(
		result,
		GFObjectPoolAcquireResult.Status.SUCCEEDED,
		&"complete",
		&"acquired"
	)
	var lease: GFObjectPoolLease = result.get_lease()
	assert_not_null(lease, "成功结果必须交付 Lease。")
	if lease == null:
		return
	var node: Node = lease.get_node()
	assert_not_null(node, "ACTIVE Lease 必须提供节点。")
	if node == null:
		return
	assert_same(node.get_parent(), _parent, "结果返回前节点必须已经挂到请求 parent。")
	assert_true(node.is_inside_tree(), "结果返回前节点必须已经入树。")
	assert_eq(lease.get_state(), GFObjectPoolLease.State.ACTIVE)
	assert_eq(lease.get_settlement_reason(), &"pending")
	assert_eq(_pool.get_active_count(_scene), 1)
	assert_eq(_pool.get_available_count(_scene), 0)


func test_acquire_rejects_invalid_scene_and_parent_with_typed_reasons() -> void:
	var invalid_scene_result: GFObjectPoolAcquireResult = await _pool.acquire(null, _parent, self)
	var detached_parent: Node = Node.new()
	var invalid_parent_result: GFObjectPoolAcquireResult = await _pool.acquire(
		_scene,
		detached_parent,
		self
	)
	detached_parent.free()

	_assert_acquire_result(
		invalid_scene_result,
		GFObjectPoolAcquireResult.Status.INVALID,
		&"validation",
		&"invalid_scene"
	)
	_assert_acquire_result(
		invalid_parent_result,
		GFObjectPoolAcquireResult.Status.INVALID,
		&"validation",
		&"invalid_parent"
	)
	assert_null(invalid_scene_result.get_lease())
	assert_null(invalid_parent_result.get_lease())


func test_acquire_rejects_missing_detached_and_queued_lifetime_owner() -> void:
	var null_owner_result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, null)
	var detached_owner_node: Node = Node.new()
	var detached_owner_result: GFObjectPoolAcquireResult = await _pool.acquire(
		_scene,
		_parent,
		detached_owner_node
	)
	var queued_owner_node: Node = Node.new()
	add_child(queued_owner_node)
	queued_owner_node.queue_free()
	var queued_owner_result: GFObjectPoolAcquireResult = await _pool.acquire(
		_scene,
		_parent,
		queued_owner_node
	)
	detached_owner_node.free()

	var invalid_results: Array[GFObjectPoolAcquireResult] = [
		null_owner_result,
		detached_owner_result,
		queued_owner_result,
	]
	for result: GFObjectPoolAcquireResult in invalid_results:
		_assert_acquire_result(
			result,
			GFObjectPoolAcquireResult.Status.INVALID,
			&"validation",
			&"invalid_owner"
		)
		assert_null(result.get_lease())
	assert_eq(_pool.get_active_count(_scene), 0)
	assert_eq(_pool.get_available_count(_scene), 0)


func test_empty_packed_scene_reports_allocation_failure() -> void:
	var empty_scene: PackedScene = PackedScene.new()
	var result: GFObjectPoolAcquireResult = await _pool.acquire(empty_scene, _parent, self)

	_assert_acquire_result(
		result,
		GFObjectPoolAcquireResult.Status.FAILED,
		&"allocation",
		&"scene_instantiation_failed"
	)
	assert_null(result.get_lease())
	assert_eq(_pool.get_active_count(empty_scene), 0)
	assert_eq(_pool.get_available_count(empty_scene), 0)


func test_parent_lost_while_request_waits_cancels_without_publishing_lease() -> void:
	var state: Dictionary = {}
	_start_acquire.call_deferred(_pool, _scene, _parent, {}, state)
	_parent.queue_free.call_deferred()

	var result: GFObjectPoolAcquireResult = await _wait_for_acquire_result(state)

	_assert_acquire_result(
		result,
		GFObjectPoolAcquireResult.Status.CANCELLED,
		&"validation",
		&"parent_lost"
	)
	assert_null(result.get_lease())
	assert_eq(_pool.get_active_count(_scene), 0)
	assert_eq(_pool.get_available_count(_scene), 0)


func test_disposed_pool_rejects_new_acquire_without_revival() -> void:
	_pool.dispose()
	await _pool.wait_disposed()
	_pool.init()

	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)

	_assert_acquire_result(
		result,
		GFObjectPoolAcquireResult.Status.CANCELLED,
		&"validation",
		&"pool_disposed"
	)
	assert_null(result.get_lease())


func test_pending_acquire_survives_caller_dropping_last_pool_reference() -> void:
	var local_pool: GFObjectPoolUtility = GFObjectPoolUtility.new()
	local_pool.init()
	var pool_weak_ref: WeakRef = weakref(local_pool)
	var state: Dictionary = {}
	_start_acquire.call_deferred(local_pool, _scene, _parent, {}, state)
	local_pool.dispose.call_deferred()
	local_pool = null

	var result: GFObjectPoolAcquireResult = await _wait_for_acquire_result(state)

	_assert_acquire_result(
		result,
		GFObjectPoolAcquireResult.Status.CANCELLED,
		&"validation",
		&"pool_disposed"
	)
	assert_null(result.get_lease())
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_parent.get_child_count(), 0, "失去 pool 外部引用不得遗留候选节点。")
	var released_pool_value: Variant = pool_weak_ref.get_ref()
	assert_true(
		released_pool_value == null,
		"pending completion 结束后局部 RefCounted pool 应释放自身。"
	)


func test_public_acquire_retires_request_when_awaiting_node_is_freed() -> void:
	var awaiter: PublicAcquireAwaiter = PublicAcquireAwaiter.new()
	_parent.add_child(awaiter)
	var awaiter_ref: WeakRef = weakref(awaiter)
	var state: Dictionary = {}
	awaiter.request_acquire.call_deferred(_pool, _scene, _parent, state)
	awaiter.free.call_deferred()

	for _frame_index: int in range(4):
		await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(state, "started"), "短命 awaiter 必须先提交公共 acquire 请求。")
	var released_awaiter_value: Variant = awaiter_ref.get_ref()
	assert_true(released_awaiter_value == null, "回归必须真实销毁等待方 Node。")
	assert_false(state.has("result"), "已销毁脚本不应继续接收 acquire 结果。")
	assert_eq(_parent.get_child_count(), 0, "无人接收的候选节点不得挂在长寿命 parent 下。")
	assert_eq(_pool.get_active_count(_scene), 0, "等待方销毁后不得留下 ACTIVE Lease。")
	assert_eq(_pool.get_available_count(_scene), 0)


func test_public_acquire_does_not_retain_ref_counted_owner_while_waiting() -> void:
	var emitter: PublicAcquireSignalEmitter = PublicAcquireSignalEmitter.new()
	var connect_error: Error = emitter.acquire_requested.connect(_pool.acquire) as Error
	assert_eq(connect_error, OK)
	var owner_holder: Array[RefCounted] = [RefCounted.new()]
	var owner_ref: WeakRef = weakref(owner_holder[0])
	emitter.acquire_requested.emit(_scene, _parent, owner_holder[0])
	owner_holder.clear()
	for _frame_index: int in range(4):
		await get_tree().process_frame

	var released_owner_value: Variant = owner_ref.get_ref()
	assert_true(released_owner_value == null, "pool 不得在等待期间强持有 RefCounted lifetime owner。")
	assert_eq(_parent.get_child_count(), 0)
	assert_eq(_pool.get_active_count(_scene), 0)
	assert_eq(_pool.get_available_count(_scene), 0)


func test_public_owner_exit_before_delivery_is_irreversible_after_reentry() -> void:
	var owner_node: Node = Node.new()
	_parent.add_child(owner_node)
	var state: Dictionary = {}
	_start_public_owner_acquire.call_deferred(_pool, _scene, _parent, owner_node, {}, state)
	_leave_and_return_for_review.call_deferred(owner_node, state)

	var result: GFObjectPoolAcquireResult = await _wait_for_acquire_result(state)

	_assert_acquire_result(
		result,
		GFObjectPoolAcquireResult.Status.CANCELLED,
		&"validation",
		&"owner_lost"
	)
	assert_null(result.get_lease())
	assert_eq(_parent.get_child_count(), 1, "owner 回树不得让已取消请求复活。")
	assert_eq(_pool.get_active_count(_scene), 0)
	owner_node.queue_free()


func test_delivered_lease_remains_callers_responsibility_after_owner_exit() -> void:
	var owner_node: Node = Node.new()
	_parent.add_child(owner_node)
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, owner_node)
	var lease: GFObjectPoolLease = result.get_lease()
	var node: Node = lease.get_node()

	_parent.remove_child(owner_node)
	owner_node.free()

	assert_eq(lease.get_state(), GFObjectPoolLease.State.ACTIVE)
	assert_same(lease.get_node(), node, "成功交付后 owner 退出不得隐式回收已转移 Lease。")
	assert_same(node.get_parent(), _parent)
	assert_eq(_pool.get_active_count(_scene), 1)
	assert_true(lease.release())
	assert_eq(await lease.wait_settled(), &"released")


# --- 测试：prepare 与原生节点生命周期 ---

func test_prepare_receives_snapshot_before_first_enter_tree_and_ready() -> void:
	var prepare_scene: PackedScene = _make_prepare_lifecycle_scene()
	var referenced_object: RefCounted = RefCounted.new()
	var context: Dictionary = {
		"nested": { "value": 7 },
		"object": referenced_object,
	}
	PrepareLifecycleNode.source_context = context
	PrepareLifecycleNode.expected_object = referenced_object

	var result: GFObjectPoolAcquireResult = await _pool.acquire(
		prepare_scene,
		_parent,
		self,
		context
	)
	var node: PrepareLifecycleNode = _prepare_node_from_result(result)

	assert_not_null(node)
	if node == null:
		return
	assert_eq(node.prepare_values, [7], "嵌套容器必须在接纳请求时复制。")
	assert_true(node.received_expected_object, "context 中 Object 必须保留身份。")
	assert_true(node.prepare_was_detached, "prepare 必须在完全离树且无 parent 时执行。")
	assert_true(node.ready_saw_prepare, "prepare 必须先于首次 _ready。")
	assert_eq(node.enter_count, 1)
	assert_eq(node.ready_count, 1)
	assert_eq(GFVariantData.get_option_int(
		GFVariantData.get_option_dictionary(context, "nested"),
		"value"
	), 99, "测试钩子必须确实改写调用方原字典以证明快照隔离。")


func test_reuse_runs_prepare_again_and_uses_enter_exit_tree_lifecycle() -> void:
	var prepare_scene: PackedScene = _make_prepare_lifecycle_scene()
	var first_result: GFObjectPoolAcquireResult = await _pool.acquire(
		prepare_scene,
		_parent,
		self,
		{ "nested": { "value": 1 } }
	)
	var first_lease: GFObjectPoolLease = first_result.get_lease()
	var node: PrepareLifecycleNode = _prepare_node_from_result(first_result)
	assert_not_null(node)
	if node == null or first_lease == null:
		return

	assert_true(first_lease.release())
	assert_eq(await first_lease.wait_settled(), &"released")
	assert_null(node.get_parent(), "结算后空闲节点必须完全离树。")
	assert_eq(node.exit_count, 1, "归还应由原生 _exit_tree 执行清理。")

	var second_result: GFObjectPoolAcquireResult = await _pool.acquire(
		prepare_scene,
		_parent,
		self,
		{ "nested": { "value": 2 } }
	)
	var reused: PrepareLifecycleNode = _prepare_node_from_result(second_result)

	assert_same(reused, node, "空闲实例应被复用。")
	assert_eq(reused.prepare_values, [1, 2], "fresh 与 reused 必须执行同一 prepare。")
	assert_eq(reused.enter_count, 2, "复用应通过原生 _enter_tree 恢复生命周期。")
	assert_eq(reused.ready_count, 1, "同一节点重新入树不应伪造第二次 _ready。")


func test_prepare_error_returns_typed_failure_and_retires_candidate() -> void:
	var failing_scene: PackedScene = _make_failing_prepare_scene()
	var result: GFObjectPoolAcquireResult = await _pool.acquire(failing_scene, _parent, self)

	_assert_acquire_result(
		result,
		GFObjectPoolAcquireResult.Status.FAILED,
		&"prepare",
		&"prepare_failed"
	)
	assert_null(result.get_lease())
	assert_eq(_pool.get_active_count(failing_scene), 0)
	assert_eq(_pool.get_available_count(failing_scene), 0)
	await get_tree().process_frame


func test_invalid_prepare_return_is_distinct_from_prepare_error() -> void:
	var invalid_scene: PackedScene = _make_invalid_prepare_scene()
	var result: GFObjectPoolAcquireResult = await _pool.acquire(invalid_scene, _parent, self)

	_assert_acquire_result(
		result,
		GFObjectPoolAcquireResult.Status.FAILED,
		&"prepare",
		&"invalid_prepare_result"
	)
	assert_null(result.get_lease())
	assert_eq(_pool.get_active_count(invalid_scene), 0)
	assert_eq(_pool.get_available_count(invalid_scene), 0)


func test_prepare_reparent_invalidates_candidate_instead_of_publishing_it() -> void:
	var stealing_parent: Node = Node.new()
	add_child(stealing_parent)
	ReparentingPrepareNode.target_parent = stealing_parent
	var invalidating_scene: PackedScene = _make_reparenting_prepare_scene()

	var result: GFObjectPoolAcquireResult = await _pool.acquire(
		invalidating_scene,
		_parent,
		self
	)

	_assert_acquire_result(
		result,
		GFObjectPoolAcquireResult.Status.FAILED,
		&"prepare",
		&"candidate_invalidated"
	)
	assert_null(result.get_lease())
	assert_eq(_pool.get_active_count(invalidating_scene), 0)
	assert_eq(_pool.get_available_count(invalidating_scene), 0)
	await get_tree().process_frame
	assert_eq(stealing_parent.get_child_count(), 0, "违规 hook 不能窃取池候选。")
	stealing_parent.queue_free()


func test_prepare_dispose_cancels_acquire_and_never_publishes_candidate() -> void:
	var disposing_scene: PackedScene = _make_disposing_prepare_scene()
	DisposingPrepareNode.pool = _pool

	var result: GFObjectPoolAcquireResult = await _pool.acquire(
		disposing_scene,
		_parent,
		self
	)

	_assert_acquire_result(
		result,
		GFObjectPoolAcquireResult.Status.CANCELLED,
		&"prepare",
		&"pool_disposed"
	)
	assert_null(result.get_lease(), "prepare 终止池后不得发布短暂 Lease。")
	await _pool.wait_disposed()
	assert_eq(_pool.get_active_count(disposing_scene), 0)
	assert_eq(_pool.get_available_count(disposing_scene), 0)
	assert_true(_pool.get_debug_snapshot().is_empty())


# --- 测试：批量原子性 ---

func test_batch_rejects_later_candidate_attached_to_requested_parent_during_enter_tree() -> void:
	await _assert_enter_tree_candidate_hijack_rejected(_parent)


func test_batch_rejects_later_candidate_attached_to_other_parent_during_enter_tree() -> void:
	var alternate_parent: Node = Node.new()
	add_child(alternate_parent)

	await _assert_enter_tree_candidate_hijack_rejected(alternate_parent)

	alternate_parent.queue_free()


# --- 测试：Lease 结算 ---

func test_release_revokes_access_synchronously_and_settles_once_at_safe_point() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	var node: Node = lease.get_node()
	watch_signals(lease)

	assert_true(lease.release(), "首次 release 必须同步接纳。")
	assert_null(lease.get_node(), "release 返回前必须撤销节点访问权。")
	assert_eq(lease.get_state(), GFObjectPoolLease.State.RELEASE_PENDING)
	assert_same(node.get_parent(), _parent, "物理离树必须推迟到安全点。")
	assert_eq(_pool.get_active_count(_scene), 0, "等待归还不再属于 active。")
	assert_eq(_pool.get_available_count(_scene), 0, "安全点前不能提前发布 available。")

	var reason: StringName = await lease.wait_settled()

	assert_eq(reason, &"released")
	assert_true(lease.is_settled())
	assert_eq(lease.get_state(), GFObjectPoolLease.State.SETTLED)
	assert_eq(lease.get_settlement_reason(), &"released")
	assert_null(node.get_parent())
	assert_eq(_pool.get_available_count(_scene), 1)
	assert_signal_emit_count(lease, "settled", 1, "每个 Lease 只能公布一个终态。")


func test_double_release_and_late_wait_are_idempotent() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	watch_signals(lease)

	assert_true(lease.release())
	assert_false(lease.release(), "RELEASE_PENDING 的 Lease 必须拒绝重复 release。")
	assert_eq(await lease.wait_settled(), &"released")
	assert_eq(await lease.wait_settled(), &"released", "晚到等待者必须立即读取缓存终态。")
	assert_false(lease.release(), "SETTLED 的 Lease 必须拒绝重复 release。")
	await get_tree().process_frame
	assert_signal_emit_count(lease, "settled", 1)
	assert_eq(_pool.get_available_count(_scene), 1)


func test_release_then_acquire_same_stack_reuses_without_stale_authority() -> void:
	var first_result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var first_lease: GFObjectPoolLease = first_result.get_lease()
	var first_node: Node = first_lease.get_node()

	assert_true(first_lease.release())
	assert_eq(first_lease.get_state(), GFObjectPoolLease.State.RELEASE_PENDING)
	var second_result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var second_lease: GFObjectPoolLease = second_result.get_lease()

	assert_true(second_result.is_successful())
	assert_eq(await first_lease.wait_settled(), &"released")
	assert_same(second_lease.get_node(), first_node, "release 后紧接 acquire 应安全复用。")
	assert_false(first_lease.release(), "旧 Lease 不能操作同一节点的新借用。")
	assert_eq(second_lease.get_state(), GFObjectPoolLease.State.ACTIVE)
	assert_eq(_pool.get_active_count(_scene), 1)


func test_one_instance_can_be_reused_one_hundred_times() -> void:
	var current_result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var expected_node: Node = current_result.get_lease().get_node()
	var previous_lease: GFObjectPoolLease = null

	for cycle_index: int in range(100):
		var current_lease: GFObjectPoolLease = current_result.get_lease()
		assert_same(current_lease.get_node(), expected_node, "第 %d 次借用应复用同一实例。" % cycle_index)
		assert_true(current_lease.release())
		current_result = await _pool.acquire(_scene, _parent, self)
		assert_true(current_result.is_successful())
		assert_eq(await current_lease.wait_settled(), &"released")
		if previous_lease != null:
			assert_false(previous_lease.release(), "更早的 Lease 必须永久失效。")
		previous_lease = current_lease

	assert_same(current_result.get_lease().get_node(), expected_node)
	assert_eq(_pool.get_active_count(_scene), 1)
	assert_eq(_pool.get_available_count(_scene), 0)


func test_external_free_settles_node_lost_and_never_reuses_dead_identity() -> void:
	var first_result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = first_result.get_lease()
	var node: Node = lease.get_node()
	var old_instance_id: int = node.get_instance_id()
	watch_signals(lease)

	node.free()
	assert_null(lease.get_node(), "外部 free 后 Lease 不得继续暴露失效节点。")
	var reason: StringName = await lease.wait_settled()

	assert_eq(reason, &"node_lost")
	assert_eq(_pool.get_available_count(_scene), 0)
	assert_eq(_pool.get_active_count(_scene), 0)
	assert_signal_emit_count(lease, "settled", 1)

	var replacement_result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var replacement: Node = replacement_result.get_lease().get_node()
	assert_ne(replacement.get_instance_id(), old_instance_id)
	assert_false(lease.release(), "丢失节点的旧 Lease 不能影响替代实例。")


func test_external_reparent_retires_candidate_instead_of_caching_it() -> void:
	var alternate_parent: Node = Node.new()
	add_child(alternate_parent)
	var first_result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = first_result.get_lease()
	var node: Node = lease.get_node()
	var old_instance_id: int = node.get_instance_id()
	var exit_state: Dictionary = { "count": 0 }
	var exit_callback: Callable = func() -> void:
		exit_state["count"] = GFVariantData.get_option_int(exit_state, "count") + 1
	var connect_error: Error = node.tree_exiting.connect(exit_callback) as Error
	assert_eq(connect_error, OK)

	node.reparent(alternate_parent)
	assert_eq(
		GFVariantData.get_option_int(exit_state, "count"),
		1,
		"同树 reparent 也必须产生一次真实 tree_exiting 生命周期。"
	)
	assert_null(lease.get_node(), "父级漂移返回前必须撤销 Lease 节点访问。")
	assert_eq(lease.get_state(), GFObjectPoolLease.State.RELEASE_PENDING)
	assert_false(lease.release(), "自动接纳父级丢失后不得重复接纳 release。")
	assert_eq(await lease.wait_settled(), &"node_lost")
	assert_eq(_pool.get_available_count(_scene), 0, "父级漂移节点不得进入缓存。")
	await get_tree().process_frame
	assert_false(is_instance_valid(node), "父级漂移节点应被淘汰。")

	var replacement_result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	assert_ne(replacement_result.get_lease().get_node().get_instance_id(), old_instance_id)
	alternate_parent.queue_free()


func test_capacity_minus_one_retires_every_release() -> void:
	_pool.max_available_per_scene = -1
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	var node: Node = lease.get_node()

	assert_true(lease.release())
	assert_eq(await lease.wait_settled(), &"capacity_retired")
	assert_eq(_pool.get_available_count(_scene), 0)
	await get_tree().process_frame
	assert_false(is_instance_valid(node))


func test_positive_capacity_retires_only_overflow() -> void:
	_pool.max_available_per_scene = 1
	var first_result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var second_result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var first_lease: GFObjectPoolLease = first_result.get_lease()
	var second_lease: GFObjectPoolLease = second_result.get_lease()

	assert_true(first_lease.release())
	assert_true(second_lease.release())
	assert_eq(await first_lease.wait_settled(), &"released")
	assert_eq(await second_lease.wait_settled(), &"capacity_retired")
	assert_eq(_pool.get_available_count(_scene), 1)
	assert_eq(_pool.get_active_count(_scene), 0)


func test_dispose_revokes_active_lease_and_clears_all_counts() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	var node: Node = lease.get_node()
	watch_signals(lease)

	_pool.dispose()
	assert_null(lease.get_node(), "dispose 返回前必须吊销所有 ACTIVE Lease。")
	assert_eq(lease.get_state(), GFObjectPoolLease.State.RELEASE_PENDING)
	assert_false(lease.release())
	await _pool.wait_disposed()

	assert_eq(await lease.wait_settled(), &"pool_disposed")
	assert_eq(_pool.get_available_count(_scene), 0)
	assert_eq(_pool.get_active_count(_scene), 0)
	assert_true(_pool.get_debug_snapshot().is_empty())
	assert_signal_emit_count(lease, "settled", 1)
	await get_tree().process_frame
	assert_false(is_instance_valid(node))


func test_debug_snapshot_contains_counts_but_no_nodes_or_leases() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	var active_snapshot: Dictionary = _debug_entry(_pool.get_debug_snapshot(), _scene)

	assert_eq(active_snapshot, { "total": 1, "available": 0, "active": 1 })
	assert_false(_contains_object(_pool.get_debug_snapshot()), "诊断快照不得泄漏 Node 或 Lease。")

	assert_true(lease.release())
	var _settled_reason: StringName = await lease.wait_settled()
	var idle_snapshot: Dictionary = _debug_entry(_pool.get_debug_snapshot(), _scene)
	assert_eq(idle_snapshot, { "total": 1, "available": 1, "active": 0 })
	assert_false(_contains_object(_pool.get_debug_snapshot()))


func test_debug_available_matches_count_when_idle_node_is_queued_for_deletion() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	var node: Node = lease.get_node()
	assert_true(lease.release())
	var _settled_reason: StringName = await lease.wait_settled()

	node.queue_free()
	var snapshot_entry: Dictionary = _debug_entry(_pool.get_debug_snapshot(), _scene)

	assert_eq(_pool.get_available_count(_scene), 0)
	assert_eq(GFVariantData.get_option_int(snapshot_entry, "available"), 0)
	assert_eq(GFVariantData.get_option_int(snapshot_entry, "active"), _pool.get_active_count(_scene))


func test_debug_available_matches_count_when_idle_node_is_reparented() -> void:
	var alternate_parent: Node = Node.new()
	add_child(alternate_parent)
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	var node: Node = lease.get_node()
	assert_true(lease.release())
	var _settled_reason: StringName = await lease.wait_settled()

	alternate_parent.add_child(node)
	var snapshot_entry: Dictionary = _debug_entry(_pool.get_debug_snapshot(), _scene)

	assert_eq(_pool.get_available_count(_scene), 0)
	assert_eq(GFVariantData.get_option_int(snapshot_entry, "available"), 0)
	assert_eq(GFVariantData.get_option_int(snapshot_entry, "active"), _pool.get_active_count(_scene))
	alternate_parent.queue_free()


# --- 测试：物理回调安全点 ---

func test_area_2d_callback_can_release_and_reacquire_same_instance() -> void:
	var area_scene: PackedScene = _make_area_2d_scene()
	var first_result: GFObjectPoolAcquireResult = await _pool.acquire(area_scene, _parent, self)
	var first_lease: GFObjectPoolLease = first_result.get_lease()
	var first_node: Node = first_lease.get_node()
	var trigger: Area2D = _make_live_area_2d()
	_parent.add_child(trigger)
	var state: Dictionary = {}
	var callback: Callable = func(_overlap: Area2D) -> void:
		state["callback_count"] = GFVariantData.get_option_int(state, "callback_count") + 1
		state["release_accepted"] = first_lease.release()
		state["revoked_in_callback"] = first_lease.get_node() == null
		state["result"] = await _pool.acquire(area_scene, _parent, self)
	var connect_error: Error = trigger.area_entered.connect(
		callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(connect_error, OK)

	var second_result: GFObjectPoolAcquireResult = await _wait_for_physics_acquire(state)
	if second_result == null:
		return

	assert_eq(GFVariantData.get_option_int(state, "callback_count"), 1)
	assert_true(GFVariantData.get_option_bool(state, "release_accepted"))
	assert_true(GFVariantData.get_option_bool(state, "revoked_in_callback"))
	assert_true(second_result.is_successful(), "物理查询 flush 结束后必须完成新借用。")
	assert_same(second_result.get_lease().get_node(), first_node)
	assert_eq(await first_lease.wait_settled(), &"released")
	assert_true(second_result.get_lease().release())
	var _second_settled_reason: StringName = await second_result.get_lease().wait_settled()
	trigger.queue_free()


func test_area_3d_callback_can_release_and_reacquire_same_instance() -> void:
	var area_scene: PackedScene = _make_area_3d_scene()
	var first_result: GFObjectPoolAcquireResult = await _pool.acquire(area_scene, _parent, self)
	var first_lease: GFObjectPoolLease = first_result.get_lease()
	var first_node: Node = first_lease.get_node()
	var trigger: Area3D = _make_live_area_3d()
	_parent.add_child(trigger)
	var state: Dictionary = {}
	var callback: Callable = func(_overlap: Area3D) -> void:
		state["callback_count"] = GFVariantData.get_option_int(state, "callback_count") + 1
		state["release_accepted"] = first_lease.release()
		state["revoked_in_callback"] = first_lease.get_node() == null
		state["result"] = await _pool.acquire(area_scene, _parent, self)
	var connect_error: Error = trigger.area_entered.connect(
		callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	assert_eq(connect_error, OK)

	var second_result: GFObjectPoolAcquireResult = await _wait_for_physics_acquire(state)
	if second_result == null:
		return

	assert_eq(GFVariantData.get_option_int(state, "callback_count"), 1)
	assert_true(GFVariantData.get_option_bool(state, "release_accepted"))
	assert_true(GFVariantData.get_option_bool(state, "revoked_in_callback"))
	assert_true(second_result.is_successful(), "3D physics callback 不得触发 flushing query 错误。")
	assert_same(second_result.get_lease().get_node(), first_node)
	assert_eq(await first_lease.wait_settled(), &"released")
	assert_true(second_result.get_lease().release())
	var _second_settled_reason: StringName = await second_result.get_lease().wait_settled()
	trigger.queue_free()


func test_pending_parent_exit_cannot_be_undone_by_reentry() -> void:
	var state: Dictionary = {}
	_capture_review_request.call_deferred(_scene, null, state)
	_leave_and_return_for_review.call_deferred(_parent, state)
	var result: GFObjectPoolAcquireResult = await _wait_for_acquire_result(state)
	if result == null:
		return
	_assert_acquire_result(result, GFObjectPoolAcquireResult.Status.CANCELLED, &"validation", &"parent_lost")
	assert_eq(_pool.get_available_count(_scene), 0)
	assert_eq(_parent.get_child_count(), 0)


func test_pending_owner_exit_cannot_be_undone_by_reentry() -> void:
	var owner_node: Node = Node.new()
	_parent.add_child(owner_node)
	var state: Dictionary = {}
	_capture_review_request.call_deferred(_scene, owner_node, state)
	_leave_and_return_for_review.call_deferred(owner_node, state)
	var result: GFObjectPoolAcquireResult = await _wait_for_acquire_result(state)
	if result == null:
		return
	_assert_acquire_result(result, GFObjectPoolAcquireResult.Status.CANCELLED, &"validation", &"owner_lost")
	assert_eq(_pool.get_available_count(_scene), 0)
	assert_eq(_parent.get_child_count(), 1)


func test_cancellation_before_publication_retires_unpublished_candidate() -> void:
	var owner_node: Node = Node.new()
	_parent.add_child(owner_node)
	var second_scene: PackedScene = _make_node_scene()
	var first_state: Dictionary = {}
	var second_state: Dictionary = {}
	_capture_review_request.call_deferred(_scene, null, first_state, owner_node)
	_capture_review_request.call_deferred(second_scene, owner_node, second_state)
	var first: GFObjectPoolAcquireResult = await _wait_for_acquire_result(first_state)
	var second: GFObjectPoolAcquireResult = await _wait_for_acquire_result(second_state)
	if first == null or second == null:
		owner_node.queue_free()
		return
	assert_true(first.is_successful())
	_assert_acquire_result(second, GFObjectPoolAcquireResult.Status.CANCELLED, &"complete", &"owner_lost")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_pool.get_available_count(second_scene), 0, "从未交付的失败候选不能当成正常归还缓存。")
	assert_eq(_pool.get_active_count(second_scene), 0)
	assert_eq(_parent.get_child_count(), 1, "只留下第一个请求成功交付的节点。")
	assert_true(first.get_lease().release())
	var _settled_reason: StringName = await first.get_lease().wait_settled()
	owner_node.queue_free()


# --- 私有/辅助方法 ---

func _start_public_owner_acquire(
	pool: GFObjectPoolUtility,
	packed_scene: PackedScene,
	request_parent: Node,
	lifetime_owner: Object,
	context: Dictionary,
	state: Dictionary
) -> void:
	state["started"] = true
	state["result"] = await pool.acquire(
		packed_scene, request_parent, lifetime_owner, context
	)


func _capture_review_request(
	packed_scene: PackedScene,
	owner_node: Node,
	state: Dictionary,
	remove_on_success: Node = null
) -> void:
	state["started"] = true
	var results: Array[GFObjectPoolAcquireResult] = await _pool.acquire_batch_for_framework(
		packed_scene, _parent, 1, {}, owner_node
	)
	state["result"] = results[0]
	if results[0].is_successful() and is_instance_valid(remove_on_success):
		remove_on_success.get_parent().remove_child(remove_on_success)


func _leave_and_return_for_review(node: Node, state: Dictionary) -> void:
	assert_true(GFVariantData.get_option_bool(state, "started"), "退出必须发生在请求已经接纳之后。")
	var original_parent: Node = node.get_parent()
	original_parent.remove_child(node)
	original_parent.add_child(node)


func _assert_enter_tree_candidate_hijack_rejected(hijack_parent: Node) -> void:
	CandidateEnterTreeHijackerNode.prepared_nodes.clear()
	CandidateEnterTreeHijackerNode.target_parent = hijack_parent
	var hijacking_scene: PackedScene = _make_candidate_enter_tree_hijacker_scene()
	var results: Array[GFObjectPoolAcquireResult] = await _pool.acquire_batch_for_framework(
		hijacking_scene, _parent, 2, {}, self
	)

	assert_eq(results.size(), 1, "候选节点被提前挂载时整批只能返回一个失败结果。")
	if results.is_empty():
		return
	_assert_acquire_result(
		results[0],
		GFObjectPoolAcquireResult.Status.FAILED,
		&"attach",
		&"candidate_invalidated"
	)
	assert_null(results[0].get_lease(), "整批失败不得发布任何 Lease。")
	assert_eq(_pool.get_active_count(hijacking_scene), 0)
	assert_eq(_pool.get_available_count(hijacking_scene), 0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_parent.get_child_count(), 0, "请求 parent 不得遗留失败候选。")
	if hijack_parent != _parent:
		assert_eq(hijack_parent.get_child_count(), 0, "其他 parent 不得保留被窃取候选。")


func _make_node_scene() -> PackedScene:
	return _pack_node(Node.new())


func _make_prepare_lifecycle_scene() -> PackedScene:
	return _pack_node(PrepareLifecycleNode.new())


func _make_failing_prepare_scene() -> PackedScene:
	return _pack_node(FailingPrepareNode.new())


func _make_invalid_prepare_scene() -> PackedScene:
	return _pack_node(InvalidPrepareNode.new())


func _make_reparenting_prepare_scene() -> PackedScene:
	return _pack_node(ReparentingPrepareNode.new())


func _make_disposing_prepare_scene() -> PackedScene:
	DisposingPrepareNode.pool = null
	return _pack_node(DisposingPrepareNode.new())


func _make_candidate_enter_tree_hijacker_scene() -> PackedScene:
	return _pack_node(CandidateEnterTreeHijackerNode.new())


func _make_area_2d_scene() -> PackedScene:
	var area: Area2D = _make_live_area_2d()
	for child: Node in area.get_children():
		child.owner = area
	return _pack_node(area)


func _make_area_3d_scene() -> PackedScene:
	var area: Area3D = _make_live_area_3d()
	for child: Node in area.get_children():
		child.owner = area
	return _pack_node(area)


func _make_live_area_2d() -> Area2D:
	var area: Area2D = Area2D.new()
	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 1
	area.collision_mask = 1
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 8.0
	collision_shape.shape = shape
	area.add_child(collision_shape)
	return area


func _make_live_area_3d() -> Area3D:
	var area: Area3D = Area3D.new()
	area.monitoring = true
	area.monitorable = true
	area.collision_layer = 1
	area.collision_mask = 1
	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = 8.0
	collision_shape.shape = shape
	area.add_child(collision_shape)
	return area


func _pack_node(root: Node) -> PackedScene:
	var packed_scene: PackedScene = PackedScene.new()
	var pack_error: Error = packed_scene.pack(root)
	root.free()
	assert_eq(pack_error, OK, "测试 PackedScene 必须成功打包。")
	return packed_scene


func _prepare_node_from_result(
	result: GFObjectPoolAcquireResult
) -> PrepareLifecycleNode:
	if result == null or result.get_lease() == null:
		return null
	var node: Node = result.get_lease().get_node()
	if node is PrepareLifecycleNode:
		var prepare_node: PrepareLifecycleNode = node
		return prepare_node
	return null


func _assert_acquire_result(
	result: GFObjectPoolAcquireResult,
	status: GFObjectPoolAcquireResult.Status,
	stage: StringName,
	reason: StringName
) -> void:
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.get_status(), status)
	assert_eq(result.get_stage(), stage)
	assert_eq(result.get_reason(), reason)
	assert_eq(result.is_successful(), status == GFObjectPoolAcquireResult.Status.SUCCEEDED)


func _start_acquire(
	pool: GFObjectPoolUtility,
	packed_scene: PackedScene,
	request_parent: Node,
	context: Dictionary,
	state: Dictionary
) -> void:
	state["result"] = await pool.acquire(packed_scene, request_parent, self, context)


func _wait_for_acquire_result(
	state: Dictionary,
	max_frames: int = 12
) -> GFObjectPoolAcquireResult:
	for _frame_index: int in range(max_frames):
		var raw_result: Variant = state.get("result")
		if raw_result is GFObjectPoolAcquireResult:
			var result: GFObjectPoolAcquireResult = raw_result
			return result
		await get_tree().process_frame
	fail_test("acquire 未在限定帧数内完成。")
	return null


func _wait_for_physics_acquire(
	state: Dictionary,
	max_physics_frames: int = 12
) -> GFObjectPoolAcquireResult:
	for _frame_index: int in range(max_physics_frames):
		var raw_result: Variant = state.get("result")
		if raw_result is GFObjectPoolAcquireResult:
			var result: GFObjectPoolAcquireResult = raw_result
			return result
		await get_tree().physics_frame
		await get_tree().process_frame
	fail_test("真实物理回调未在限定帧数内完成 release/acquire。")
	return null


func _debug_entry(snapshot: Dictionary, packed_scene: PackedScene) -> Dictionary:
	var key: String = packed_scene.resource_path
	if key.is_empty():
		key = str(packed_scene.get_instance_id())
	return GFVariantData.get_option_dictionary(snapshot, key)


func _contains_object(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		for nested_value: Variant in dictionary_value.values():
			if _contains_object(nested_value):
				return true
	if value is Array:
		var array_value: Array = value
		for nested_value: Variant in array_value:
			if _contains_object(nested_value):
				return true
	return false


# --- 内部类 ---

class PrepareLifecycleNode extends Node:
	static var source_context: Dictionary = {}
	static var expected_object: Object = null
	var prepare_values: Array[int] = []
	var received_expected_object: bool = false
	var prepare_was_detached: bool = false
	var ready_saw_prepare: bool = false
	var enter_count: int = 0
	var ready_count: int = 0
	var exit_count: int = 0

	func _enter_tree() -> void:
		enter_count += 1

	func _ready() -> void:
		ready_count += 1
		ready_saw_prepare = not prepare_values.is_empty()

	func _exit_tree() -> void:
		exit_count += 1

	func on_gf_pool_prepare(context: Dictionary) -> Error:
		prepare_was_detached = not is_inside_tree() and get_parent() == null
		var source_nested_value: Variant = source_context.get("nested")
		if source_nested_value is Dictionary:
			var source_nested: Dictionary = source_nested_value
			source_nested["value"] = 99
		var nested: Dictionary = GFVariantData.get_option_dictionary(context, "nested")
		prepare_values.append(GFVariantData.get_option_int(nested, "value"))
		var object_value: Variant = context.get("object")
		received_expected_object = object_value == expected_object
		return OK


class FailingPrepareNode extends Node:
	func on_gf_pool_prepare(_context: Dictionary) -> Error:
		return ERR_INVALID_DATA


class InvalidPrepareNode extends Node:
	func on_gf_pool_prepare(_context: Dictionary) -> Variant:
		return "not-an-error"


class ReparentingPrepareNode extends Node:
	static var target_parent: Node = null

	func on_gf_pool_prepare(_context: Dictionary) -> Error:
		if target_parent != null and is_instance_valid(target_parent):
			target_parent.add_child(self)
		return OK


class DisposingPrepareNode extends Node:
	static var pool: GFObjectPoolUtility = null

	func on_gf_pool_prepare(_context: Dictionary) -> Error:
		if pool != null:
			pool.dispose()
		return OK


class PublicAcquireAwaiter extends Node:
	func request_acquire(
		pool: GFObjectPoolUtility,
		packed_scene: PackedScene,
		request_parent: Node,
		state: Dictionary
	) -> void:
		state["started"] = true
		state["result"] = await pool.acquire(packed_scene, request_parent, self)


class PublicAcquireSignalEmitter extends RefCounted:
	signal acquire_requested(packed_scene: PackedScene, request_parent: Node, lifetime_owner: Object)


class CandidateEnterTreeHijackerNode extends Node:
	static var prepared_nodes: Array[Node] = []
	static var target_parent: Node = null

	func _enter_tree() -> void:
		if prepared_nodes.size() != 2 or prepared_nodes[0] != self:
			return
		var later_candidate: Node = prepared_nodes[1]
		if (is_instance_valid(later_candidate)
			and later_candidate.get_parent() == null
			and is_instance_valid(target_parent)
		):
			target_parent.add_child(later_candidate)

	func on_gf_pool_prepare(_context: Dictionary) -> Error:
		prepared_nodes.append(self)
		return OK
