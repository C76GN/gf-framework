## 验证 GFObjectPoolUtility 的离树分帧 prewarm 结果、容量和取消语义。
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
	PrewarmLifecycleNode.reset_observations()
	_scene = _make_prewarm_lifecycle_scene()
	PrewarmLifecycleNode.reset_observations()
	CancellingPrewarmNode.cancel_source = null
	CancellingPrewarmNode.instantiation_count = 0
	DisposingPrewarmNode.pool = null
	DisposingPrewarmNode.instantiation_count = 0


func after_each() -> void:
	CancellingPrewarmNode.cancel_source = null
	CancellingPrewarmNode.instantiation_count = 0
	DisposingPrewarmNode.pool = null
	DisposingPrewarmNode.instantiation_count = 0
	if _pool != null:
		_pool.dispose()
		await _pool.wait_disposed()
	_pool = null
	if is_instance_valid(_parent) and not _parent.is_queued_for_deletion():
		_parent.queue_free()
	_parent = null
	_scene = null
	await get_tree().process_frame


# --- 测试：结果与离树语义 ---

func test_prewarm_creates_requested_detached_instances_without_lifecycle_hooks() -> void:
	var result: GFObjectPoolPrewarmResult = await _pool.prewarm(_scene, 3, 2)

	_assert_prewarm_result(
		result,
		GFObjectPoolPrewarmResult.Status.SUCCEEDED,
		&"prewarmed",
		3,
		3
	)
	assert_eq(_pool.get_available_count(_scene), 3)
	assert_eq(_pool.get_active_count(_scene), 0)
	assert_eq(PrewarmLifecycleNode.instantiation_count, 3)
	assert_eq(PrewarmLifecycleNode.prepare_count, 0, "prewarm 不得执行 prepare。")
	assert_eq(PrewarmLifecycleNode.enter_count, 0, "prewarm 不得临时挂树。")
	assert_eq(PrewarmLifecycleNode.ready_count, 0, "prewarm 不得触发 ready。")


func test_first_acquire_after_prewarm_runs_prepare_and_tree_lifecycle() -> void:
	var prewarm_result: GFObjectPoolPrewarmResult = await _pool.prewarm(_scene, 1)
	assert_true(prewarm_result.is_successful())

	var acquire_result: GFObjectPoolAcquireResult = await _pool.acquire(
		_scene,
		_parent,
		self,
		{ "value": 42 }
	)
	var lease: GFObjectPoolLease = acquire_result.get_lease()
	var node: Node = lease.get_node()

	assert_true(acquire_result.is_successful())
	assert_true(node is PrewarmLifecycleNode)
	assert_eq(PrewarmLifecycleNode.instantiation_count, 1, "借用必须消费已预热实例。")
	assert_eq(PrewarmLifecycleNode.prepare_count, 1)
	assert_eq(PrewarmLifecycleNode.enter_count, 1)
	assert_eq(PrewarmLifecycleNode.ready_count, 1)
	if node is PrewarmLifecycleNode:
		var lifecycle_node: PrewarmLifecycleNode = node
		assert_eq(lifecycle_node.prepared_value, 42)


func test_zero_count_is_successful_no_op() -> void:
	var result: GFObjectPoolPrewarmResult = await _pool.prewarm(_scene, 0)

	_assert_prewarm_result(
		result,
		GFObjectPoolPrewarmResult.Status.SUCCEEDED,
		&"prewarmed",
		0,
		0
	)
	assert_eq(_pool.get_available_count(_scene), 0)
	assert_eq(PrewarmLifecycleNode.instantiation_count, 0)


func test_invalid_scene_count_and_batch_size_have_distinct_reasons() -> void:
	var null_scene_result: GFObjectPoolPrewarmResult = await _pool.prewarm(null, 1)
	var empty_scene_result: GFObjectPoolPrewarmResult = await _pool.prewarm(
		PackedScene.new(),
		1
	)
	var invalid_count_result: GFObjectPoolPrewarmResult = await _pool.prewarm(
		_scene,
		-1
	)
	var invalid_batch_result: GFObjectPoolPrewarmResult = await _pool.prewarm(
		_scene,
		1,
		0
	)

	_assert_prewarm_result(
		null_scene_result,
		GFObjectPoolPrewarmResult.Status.INVALID,
		&"invalid_scene",
		1,
		0
	)
	_assert_prewarm_result(
		empty_scene_result,
		GFObjectPoolPrewarmResult.Status.INVALID,
		&"invalid_scene",
		1,
		0
	)
	_assert_prewarm_result(
		invalid_count_result,
		GFObjectPoolPrewarmResult.Status.INVALID,
		&"invalid_count",
		0,
		0
	)
	_assert_prewarm_result(
		invalid_batch_result,
		GFObjectPoolPrewarmResult.Status.INVALID,
		&"invalid_batch_size",
		1,
		0
	)


# --- 测试：容量 ---

func test_zero_capacity_limit_means_unlimited() -> void:
	_pool.max_available_per_scene = 0
	var first_result: GFObjectPoolPrewarmResult = await _pool.prewarm(_scene, 3)
	var second_result: GFObjectPoolPrewarmResult = await _pool.prewarm(_scene, 2)

	assert_true(first_result.is_successful())
	assert_true(second_result.is_successful())
	assert_eq(first_result.get_created_count() + second_result.get_created_count(), 5)
	assert_eq(_pool.get_available_count(_scene), 5)


func test_positive_capacity_returns_partial_result_at_limit() -> void:
	_pool.max_available_per_scene = 2
	var result: GFObjectPoolPrewarmResult = await _pool.prewarm(_scene, 5, 3)

	_assert_prewarm_result(
		result,
		GFObjectPoolPrewarmResult.Status.PARTIAL,
		&"capacity_limited",
		5,
		2
	)
	assert_eq(_pool.get_available_count(_scene), 2)
	assert_eq(PrewarmLifecycleNode.instantiation_count, 2)


func test_existing_available_instances_count_toward_capacity() -> void:
	_pool.max_available_per_scene = 3
	var first_result: GFObjectPoolPrewarmResult = await _pool.prewarm(_scene, 2)
	var second_result: GFObjectPoolPrewarmResult = await _pool.prewarm(_scene, 3)

	_assert_prewarm_result(
		first_result,
		GFObjectPoolPrewarmResult.Status.SUCCEEDED,
		&"prewarmed",
		2,
		2
	)
	_assert_prewarm_result(
		second_result,
		GFObjectPoolPrewarmResult.Status.PARTIAL,
		&"capacity_limited",
		3,
		1
	)
	assert_eq(_pool.get_available_count(_scene), 3)


func test_minus_one_capacity_disables_caching() -> void:
	_pool.max_available_per_scene = -1
	var result: GFObjectPoolPrewarmResult = await _pool.prewarm(_scene, 1)

	_assert_prewarm_result(
		result,
		GFObjectPoolPrewarmResult.Status.PARTIAL,
		&"capacity_limited",
		1,
		0
	)
	assert_eq(_pool.get_available_count(_scene), 0)
	assert_eq(PrewarmLifecycleNode.instantiation_count, 0)


func test_concurrent_requests_share_the_same_capacity_limit() -> void:
	_pool.max_available_per_scene = 3
	var first_state: Dictionary = {}
	var second_state: Dictionary = {}
	_start_prewarm.call_deferred(_pool, _scene, 2, 1, null, first_state)
	_start_prewarm.call_deferred(_pool, _scene, 2, 1, null, second_state)

	var first_result: GFObjectPoolPrewarmResult = await _wait_for_prewarm_result(
		first_state
	)
	var second_result: GFObjectPoolPrewarmResult = await _wait_for_prewarm_result(
		second_state
	)
	var statuses: Array[int] = [
		first_result.get_status(),
		second_result.get_status(),
	]

	assert_eq(first_result.get_created_count() + second_result.get_created_count(), 3)
	assert_true(statuses.has(GFObjectPoolPrewarmResult.Status.PARTIAL))
	assert_eq(_pool.get_available_count(_scene), 3)


# --- 测试：分帧、取消与 dispose ---

func test_batch_size_one_yields_between_instantiations() -> void:
	var result: GFObjectPoolPrewarmResult = await _pool.prewarm(_scene, 4, 1)

	assert_true(result.is_successful())
	assert_eq(PrewarmLifecycleNode.instantiation_frames.size(), 4)
	if PrewarmLifecycleNode.instantiation_frames.size() != 4:
		return
	assert_gt(
		PrewarmLifecycleNode.instantiation_frames[3],
		PrewarmLifecycleNode.instantiation_frames[0],
		"batch_size=1 必须跨真实 process frame，而不是同帧反复 deferred。"
	)


func test_prewarm_continuations_do_not_overtake_accepted_release_and_acquire() -> void:
	var initial_result: GFObjectPoolAcquireResult = await _pool.acquire(
		_scene,
		_parent,
		self
	)
	assert_true(initial_result.is_successful())
	var initial_lease: GFObjectPoolLease = initial_result.get_lease()
	assert_not_null(initial_lease)
	if initial_lease == null:
		return
	watch_signals(initial_lease)
	PrewarmLifecycleNode.reset_observations()

	var source: GFCancellationSource = GFCancellationSource.new()
	var long_states: Array[Dictionary] = []
	# 64 个长请求占满首轮；短见证必须在下一轮推进，而非等待全部续任务。
	for _request_index: int in range(64):
		var state: Dictionary = {}
		long_states.append(state)
		_start_prewarm.call_deferred(_pool, _scene, 4, 1, source.get_token(), state)
	var release_state: Dictionary = {}
	var acquire_state: Dictionary = {}
	var witness_state: Dictionary = {}
	var witness_scene: PackedScene = _pack_node(Node.new())
	_start_fairness_release.call_deferred(initial_lease, release_state)
	_start_fairness_acquire.call_deferred(acquire_state)
	_start_prewarm.call_deferred(_pool, witness_scene, 1, 1, null, witness_state)

	var witness_result: GFObjectPoolPrewarmResult = await _wait_for_prewarm_result(
		witness_state
	)
	assert_not_null(witness_result)
	if witness_result != null:
		assert_true(witness_result.is_successful())
	assert_true(GFVariantData.get_option_bool(release_state, "accepted"))
	assert_signal_emit_count(initial_lease, "settled", 1)
	assert_lte(
		GFVariantData.get_option_int(witness_state, "instantiation_count", -1),
		128,
		"已接纳的 release/acquire 及短见证必须先于长预热的第二轮续任务。"
	)
	assert_eq(GFVariantData.get_option_int(witness_state, "completion_count"), 1)
	var completed_long_requests: int = 0
	for state: Dictionary in long_states:
		if state.has("result"):
			completed_long_requests += 1
	assert_eq(completed_long_requests, 0, "短见证不应等待任何四批预热全部完成。")

	var next_lease: GFObjectPoolLease = null
	var raw_acquire_result: Variant = acquire_state.get("result")
	assert_true(raw_acquire_result is GFObjectPoolAcquireResult)
	if raw_acquire_result is GFObjectPoolAcquireResult:
		var acquire_result: GFObjectPoolAcquireResult = raw_acquire_result
		assert_true(acquire_result.is_successful())
		next_lease = acquire_result.get_lease()
		assert_not_null(next_lease)
	assert_eq(GFVariantData.get_option_int(acquire_state, "completion_count"), 1)

	assert_true(source.cancel(&"fairness_observed"))
	for state: Dictionary in long_states:
		var result: GFObjectPoolPrewarmResult = await _wait_for_prewarm_result(state)
		assert_not_null(result)
		if result != null:
			assert_true(result.get_status() in [
				GFObjectPoolPrewarmResult.Status.CANCELLED,
				GFObjectPoolPrewarmResult.Status.SUCCEEDED,
			])
		assert_eq(GFVariantData.get_option_int(state, "completion_count"), 1)
	source.dispose()
	if next_lease != null:
		watch_signals(next_lease)
		assert_true(next_lease.release())
		assert_eq(await next_lease.wait_settled(), &"released")
		assert_signal_emit_count(next_lease, "settled", 1)
	_pool.dispose()
	await _pool.wait_disposed()
	assert_signal_emit_count(initial_lease, "settled", 1)
	if next_lease != null:
		assert_signal_emit_count(next_lease, "settled", 1)
	assert_eq(_parent.get_child_count(), 0)
	assert_true(_pool.get_debug_snapshot().is_empty())


func test_already_cancelled_token_creates_nothing() -> void:
	var source: GFCancellationSource = GFCancellationSource.new()
	assert_true(source.cancel(&"test_cancel"))

	var result: GFObjectPoolPrewarmResult = await _pool.prewarm(
		_scene,
		3,
		2,
		source.get_token()
	)

	_assert_prewarm_result(
		result,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		&"cancelled",
		3,
		0
	)
	assert_eq(_pool.get_available_count(_scene), 0)
	assert_eq(PrewarmLifecycleNode.instantiation_count, 0)
	source.dispose()


func test_cancellation_mid_batch_keeps_committed_instances_without_leak() -> void:
	var source: GFCancellationSource = GFCancellationSource.new()
	var cancelling_scene: PackedScene = _make_cancelling_scene()
	CancellingPrewarmNode.instantiation_count = 0
	CancellingPrewarmNode.cancel_source = source

	var result: GFObjectPoolPrewarmResult = await _pool.prewarm(
		cancelling_scene,
		4,
		4,
		source.get_token()
	)

	_assert_prewarm_result(
		result,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		&"cancelled",
		4,
		1
	)
	assert_eq(_pool.get_available_count(cancelling_scene), 1)
	assert_eq(_pool.get_active_count(cancelling_scene), 0)
	assert_eq(_debug_total(_pool.get_debug_snapshot(), cancelling_scene), 1)
	await get_tree().process_frame
	assert_eq(_debug_total(_pool.get_debug_snapshot(), cancelling_scene), 1)
	source.dispose()


func test_dispose_mid_batch_cancels_request_and_retires_committed_instances() -> void:
	var disposing_scene: PackedScene = _make_disposing_scene()
	DisposingPrewarmNode.instantiation_count = 0
	DisposingPrewarmNode.pool = _pool

	var result: GFObjectPoolPrewarmResult = await _pool.prewarm(
		disposing_scene,
		4,
		4
	)

	_assert_prewarm_result(
		result,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		&"pool_disposed",
		4,
		1
	)
	await _pool.wait_disposed()
	assert_eq(_pool.get_available_count(disposing_scene), 0)
	assert_eq(_pool.get_active_count(disposing_scene), 0)
	assert_true(_pool.get_debug_snapshot().is_empty())
	await get_tree().process_frame


func test_dispose_cancels_request_waiting_for_next_batch() -> void:
	var state: Dictionary = {}
	_start_prewarm.call_deferred(_pool, _scene, 4, 1, null, state)
	await get_tree().process_frame
	assert_gt(_pool.get_available_count(_scene), 0, "首批必须先提交至少一个实例。")
	assert_lt(_pool.get_available_count(_scene), 4, "请求必须仍有后续批次。")

	_pool.dispose()
	var result: GFObjectPoolPrewarmResult = await _wait_for_prewarm_result(state)
	await _pool.wait_disposed()

	assert_eq(result.get_status(), GFObjectPoolPrewarmResult.Status.CANCELLED)
	assert_eq(result.get_reason(), &"pool_disposed")
	assert_gt(result.get_created_count(), 0)
	assert_lt(result.get_created_count(), result.get_requested_count())
	assert_eq(_pool.get_available_count(_scene), 0)


# --- 私有/辅助方法 ---

func _make_prewarm_lifecycle_scene() -> PackedScene:
	return _pack_node(PrewarmLifecycleNode.new())


func _make_cancelling_scene() -> PackedScene:
	CancellingPrewarmNode.cancel_source = null
	CancellingPrewarmNode.instantiation_count = 0
	return _pack_node(CancellingPrewarmNode.new())


func _make_disposing_scene() -> PackedScene:
	DisposingPrewarmNode.pool = null
	DisposingPrewarmNode.instantiation_count = 0
	return _pack_node(DisposingPrewarmNode.new())


func _pack_node(root: Node) -> PackedScene:
	var packed_scene: PackedScene = PackedScene.new()
	var pack_error: Error = packed_scene.pack(root)
	root.free()
	assert_eq(pack_error, OK, "测试 PackedScene 必须成功打包。")
	return packed_scene


func _assert_prewarm_result(
	result: GFObjectPoolPrewarmResult,
	status: GFObjectPoolPrewarmResult.Status,
	reason: StringName,
	requested_count: int,
	created_count: int
) -> void:
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.get_status(), status)
	assert_eq(result.get_reason(), reason)
	assert_eq(result.get_requested_count(), requested_count)
	assert_eq(result.get_created_count(), created_count)
	assert_eq(result.is_successful(), status == GFObjectPoolPrewarmResult.Status.SUCCEEDED)
	assert_gte(result.get_created_count(), 0)
	assert_lte(result.get_created_count(), result.get_requested_count())


func _start_prewarm(
	pool: GFObjectPoolUtility,
	packed_scene: PackedScene,
	count: int,
	batch_size: int,
	token: GFCancellationToken,
	state: Dictionary
) -> void:
	state["result"] = await pool.prewarm(packed_scene, count, batch_size, token)
	state["instantiation_count"] = PrewarmLifecycleNode.instantiation_count
	state["completion_count"] = GFVariantData.get_option_int(state, "completion_count") + 1


func _start_fairness_release(lease: GFObjectPoolLease, state: Dictionary) -> void:
	state["accepted"] = lease.release()


func _start_fairness_acquire(state: Dictionary) -> void:
	state["result"] = await _pool.acquire(_scene, _parent, self)
	state["completion_count"] = GFVariantData.get_option_int(state, "completion_count") + 1


func _wait_for_prewarm_result(
	state: Dictionary,
	max_frames: int = 16
) -> GFObjectPoolPrewarmResult:
	for _frame_index: int in range(max_frames):
		var raw_result: Variant = state.get("result")
		if raw_result is GFObjectPoolPrewarmResult:
			var result: GFObjectPoolPrewarmResult = raw_result
			return result
		await get_tree().process_frame
	fail_test("prewarm 未在限定帧数内完成。")
	return null


func _debug_total(snapshot: Dictionary, packed_scene: PackedScene) -> int:
	var key: String = packed_scene.resource_path
	if key.is_empty():
		key = str(packed_scene.get_instance_id())
	var entry: Dictionary = GFVariantData.get_option_dictionary(snapshot, key)
	return GFVariantData.get_option_int(entry, "total")


# --- 内部类 ---

class PrewarmLifecycleNode extends Node:
	static var instantiation_count: int = 0
	static var instantiation_frames: Array[int] = []
	static var prepare_count: int = 0
	static var enter_count: int = 0
	static var ready_count: int = 0
	var prepared_value: int = 0

	func _init() -> void:
		instantiation_count += 1
		instantiation_frames.append(Engine.get_process_frames())

	func _enter_tree() -> void:
		enter_count += 1

	func _ready() -> void:
		ready_count += 1

	func on_gf_pool_prepare(context: Dictionary) -> Error:
		prepare_count += 1
		prepared_value = GFVariantData.get_option_int(context, "value")
		return OK

	static func reset_observations() -> void:
		instantiation_count = 0
		instantiation_frames = []
		prepare_count = 0
		enter_count = 0
		ready_count = 0


class CancellingPrewarmNode extends Node:
	static var cancel_source: GFCancellationSource = null
	static var instantiation_count: int = 0

	func _init() -> void:
		instantiation_count += 1
		if instantiation_count == 2 and cancel_source != null:
			var _cancelled: bool = cancel_source.cancel(&"mid_batch")


class DisposingPrewarmNode extends Node:
	static var pool: GFObjectPoolUtility = null
	static var instantiation_count: int = 0

	func _init() -> void:
		instantiation_count += 1
		if instantiation_count == 2 and pool != null:
			pool.dispose()
