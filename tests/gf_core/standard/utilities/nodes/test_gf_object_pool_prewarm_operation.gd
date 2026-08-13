## 测试 GFObjectPoolUtility 的 request-scoped typed prewarm operation。
extends GutTest


# --- 私有变量 ---

var _pool: GFObjectPoolUtility
var _parent: Node
var _scene: PackedScene


# --- 内部类 ---

class RefCountedPrepareOwner extends RefCounted:
	func prepare(_node: Node) -> Error:
		return OK


class QueueFreePrepareOwner extends Node:
	var call_count: int = 0

	func prepare(_node: Node) -> Error:
		call_count += 1
		if call_count >= 2:
			queue_free()
			return ERR_INVALID_DATA
		return OK


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
	if is_instance_valid(_parent):
		_parent.queue_free()
	_parent = null
	_scene = null
	await get_tree().process_frame


# --- 测试：类型化请求 ---

func test_cancel_releases_only_own_reservation_and_completes_once() -> void:
	_pool.max_available_per_scene = 4
	var first: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene,
		_parent,
		2,
		1
	)
	var second: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene,
		_parent,
		2,
		1
	)
	watch_signals(first)

	assert_eq(first.get_created_count(), 1, "A 返回时应提交首批一个节点。")
	assert_eq(second.get_created_count(), 1, "B 返回时应提交首批一个节点。")
	assert_true(first.cancel(), "A 首次取消应被同步接纳。")
	assert_false(first.cancel(), "A 终态后的重复取消应幂等返回 false。")
	assert_signal_emit_count(first, "completed", 1, "A completed 应 exact-once。")

	_pool.prewarm(_scene, _parent, 4)
	assert_eq(
		_pool.get_available_count(_scene),
		3,
		"A 应释放自身余量，B 的余量仍须保持 reservation。"
	)
	assert_true(await _wait_until_completed(second), "B 应在有界帧内完成。")
	assert_eq(_pool.get_available_count(_scene), 4, "B 完成后池应精确达到容量。")

	var first_result: GFObjectPoolPrewarmResult = first.get_result()
	assert_not_null(first_result, "A 应冻结类型化终态。")
	if first_result == null:
		return
	assert_eq(first_result.get_status(), GFObjectPoolPrewarmResult.Status.CANCELLED)
	assert_eq(first_result.get_reason(), GFObjectPoolPrewarmResult.REASON_CALLER_CANCELLED)
	assert_eq(first_result.get_error_code(), ERR_SKIP)
	assert_eq(first_result.get_requested_count(), 2)
	assert_eq(first_result.get_admitted_count(), 2)
	assert_eq(first_result.get_created_count(), 1)
	assert_eq(first_result.get_skipped_count(), 0)
	assert_eq(first_result.get_cancelled_count(), 1)
	assert_eq(first_result.get_failed_count(), 0)
	await get_tree().process_frame
	assert_signal_emit_count(first, "completed", 1, "后续 driver 不得重复终结 A。")


func test_nested_progress_cancel_never_delivers_progress_after_completed() -> void:
	var events: Array[String] = []
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, _parent, 3, 1
	)
	var _first_connect_error: int = operation.progressed.connect(func(
		current: GFObjectPoolPrewarmOperation,
	) -> void:
		events.append("first:%d" % current.get_processed_count())
		if current.is_pending() and current.get_created_count() == 2:
			var _cancelled: bool = current.cancel()
	) as Error
	var _second_connect_error: int = operation.progressed.connect(func(
		current: GFObjectPoolPrewarmOperation,
	) -> void:
		events.append("second:%d" % current.get_processed_count())
	) as Error
	var _completed_connect_error: int = operation.completed.connect(func(
		_result: GFObjectPoolPrewarmResult,
	) -> void:
		events.append("completed")
	) as Error

	assert_true(await _wait_until_completed(operation), "progress listener 取消应有界终结请求。")
	await get_tree().process_frame

	assert_eq(
		events,
		["first:2", "second:2", "first:3", "second:3", "completed"],
		"普通 progress 分发应先完成，终态 progress 必须先于 completed，且 completed 后不得再分发。"
	)


func test_pending_terminal_blocks_late_progress_and_early_completion_publish() -> void:
	var operation: GFObjectPoolPrewarmOperation = GFObjectPoolPrewarmOperation.new()
	assert_true(operation.configure_for_framework(
		Callable(self, &"_reject_direct_operation_cancel"),
		RefCounted.new(),
		9001,
		_scene,
		2,
		2
	))
	var events: Array[String] = []
	var late_record_results: Array[bool] = []
	var early_completion_results: Array[bool] = []
	var _progress_error: int = operation.progressed.connect(func(
		current: GFObjectPoolPrewarmOperation,
	) -> void:
		events.append("progress:%d" % current.get_processed_count())
		if current.is_pending() and late_record_results.is_empty():
			var _finished: bool = current.finish_for_framework(
				GFObjectPoolPrewarmResult.Status.CANCELLED,
				GFObjectPoolPrewarmResult.REASON_CALLER_CANCELLED,
				ERR_SKIP
			)
			late_record_results.append(current.record_created_for_framework())
		elif current.is_completed():
			early_completion_results.append(current.emit_completed_for_framework())
	) as Error
	var _completed_error: int = operation.completed.connect(func(
		_result: GFObjectPoolPrewarmResult,
	) -> void:
		events.append("completed")
	) as Error

	assert_true(operation.record_created_for_framework())

	assert_eq(late_record_results, [false], "待定终态不得再接纳进度写入。")
	assert_eq(early_completion_results, [false], "终态 progress 分发中不得提前发布 completed。")
	assert_eq(events, ["progress:1", "progress:2", "completed"])
	var result: GFObjectPoolPrewarmResult = operation.get_result()
	assert_not_null(result)
	if result == null:
		return
	assert_eq(operation.get_created_count(), 1)
	assert_eq(operation.get_cancelled_count(), 1)
	assert_eq(result.get_created_count(), 1)
	assert_eq(result.get_cancelled_count(), 1)


func test_concurrent_operations_keep_identity_progress_and_completion_correlated() -> void:
	_pool.max_available_per_scene = 2
	var second_scene: PackedScene = _make_node_scene()
	var first: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, _parent, 2, 1
	)
	var second: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		second_scene, _parent, 2, 1
	)
	watch_signals(first)
	watch_signals(second)
	var first_progress: Array[GFObjectPoolPrewarmOperation] = []
	var second_progress: Array[GFObjectPoolPrewarmOperation] = []
	var first_completed: Array[GFObjectPoolPrewarmResult] = []
	var second_completed: Array[GFObjectPoolPrewarmResult] = []
	var _first_progress_error: int = first.progressed.connect(func(
		current: GFObjectPoolPrewarmOperation,
	) -> void:
		first_progress.append(current)
	) as Error
	var _second_progress_error: int = second.progressed.connect(func(
		current: GFObjectPoolPrewarmOperation,
	) -> void:
		second_progress.append(current)
	) as Error
	var _first_completed_error: int = first.completed.connect(func(
		result: GFObjectPoolPrewarmResult,
	) -> void:
		first_completed.append(result)
	) as Error
	var _second_completed_error: int = second.completed.connect(func(
		result: GFObjectPoolPrewarmResult,
	) -> void:
		second_completed.append(result)
	) as Error

	assert_ne(first.get_request_id(), second.get_request_id(), "并发请求 ID 必须唯一。")
	assert_same(first.get_scene(), _scene, "A 应保持自身 scene 弱身份。")
	assert_same(second.get_scene(), second_scene, "B 应保持自身 scene 弱身份。")
	assert_ne(first.get_scene_identity(), second.get_scene_identity(), "不同 scene 身份不得串线。")
	assert_true(await _wait_until_completed(first), "A 应在有界帧内完成。")
	assert_true(await _wait_until_completed(second), "B 应在有界帧内完成。")
	await get_tree().process_frame

	assert_eq(first_progress, [first], "A progress payload 只应关联 A。")
	assert_eq(second_progress, [second], "B progress payload 只应关联 B。")
	assert_eq(first_completed.size(), 1, "A completed payload 应 exact-once。")
	assert_eq(second_completed.size(), 1, "B completed payload 应 exact-once。")
	assert_signal_emit_count(first, "completed", 1)
	assert_signal_emit_count(second, "completed", 1)
	if first_completed.size() == 1:
		assert_eq(first_completed[0].get_request_id(), first.get_request_id())
		assert_eq(first_completed[0].get_scene_identity(), first.get_scene_identity())
	if second_completed.size() == 1:
		assert_eq(second_completed[0].get_request_id(), second.get_request_id())
		assert_eq(second_completed[0].get_scene_identity(), second.get_scene_identity())


func test_legacy_batch_wrapper_awaits_typed_terminal() -> void:
	await _pool.prewarm_async(_scene, _parent, 3, 1)

	assert_eq(_pool.get_available_count(_scene), 3, "legacy await 返回时预热应已完成。")
	assert_eq(_parent.get_child_count(), 3, "legacy parent 挂载语义应保持。")


func test_validation_and_capacity_return_closed_synchronous_results() -> void:
	var zero: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(_scene, null, 0)
	var negative: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(_scene, null, -1)
	var invalid_scene: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(null, null, 2)
	_pool.max_available_per_scene = 1
	_pool.prewarm(_scene, _parent, 1)
	var rejected: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(_scene, null, 2)

	_assert_terminal(
		zero,
		GFObjectPoolPrewarmResult.Status.COMPLETED,
		GFObjectPoolPrewarmResult.REASON_COMPLETED,
		OK,
		0,
		0,
		0,
		0,
		0,
		0
	)
	_assert_terminal(
		negative,
		GFObjectPoolPrewarmResult.Status.INVALID,
		GFObjectPoolPrewarmResult.REASON_INVALID_COUNT,
		ERR_INVALID_PARAMETER,
		0,
		0,
		0,
		0,
		0,
		0
	)
	_assert_terminal(
		invalid_scene,
		GFObjectPoolPrewarmResult.Status.INVALID,
		GFObjectPoolPrewarmResult.REASON_INVALID_SCENE,
		ERR_INVALID_PARAMETER,
		2,
		0,
		0,
		2,
		0,
		0
	)
	_assert_terminal(
		rejected,
		GFObjectPoolPrewarmResult.Status.REJECTED,
		GFObjectPoolPrewarmResult.REASON_CAPACITY_UNAVAILABLE,
		ERR_BUSY,
		2,
		0,
		0,
		2,
		0,
		0
	)


func test_queued_parent_is_invalid_without_capacity_admission() -> void:
	var queued_parent: Node = Node.new()
	add_child(queued_parent)
	queued_parent.queue_free()

	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, queued_parent, 2
	)

	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.INVALID,
		GFObjectPoolPrewarmResult.REASON_INVALID_PARENT,
		ERR_INVALID_PARAMETER,
		2,
		0,
		0,
		2,
		0,
		0
	)
	assert_eq(_pool.get_available_count(_scene), 0, "无效 parent 不得取得容量。")


func test_empty_packed_scene_returns_typed_failure_and_releases_reservation() -> void:
	_pool.max_available_per_scene = 2
	var empty_scene: PackedScene = PackedScene.new()

	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		empty_scene, null, 2, 0
	)
	assert_engine_error(
		"Condition \"nc == 0\" is true. Returning: nullptr",
		"空 PackedScene 的原生实例化诊断应被测试显式接纳。"
	)

	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.FAILED,
		GFObjectPoolPrewarmResult.REASON_SCENE_INSTANTIATION_FAILED,
		ERR_CANT_CREATE,
		2,
		2,
		0,
		0,
		0,
		2
	)
	_pool.prewarm(_scene, _parent, 2)
	assert_eq(_pool.get_available_count(_scene), 2, "实例化失败必须释放全部 reservation。")


func test_pre_cancelled_token_settles_without_leaking_reservation() -> void:
	_pool.max_available_per_scene = 2
	var source: GFCancellationSource = GFCancellationSource.new()
	var _cancelled: bool = source.cancel(&"test_cancelled")

	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene,
		null,
		2,
		1,
		null,
		source.get_token()
	)

	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		GFObjectPoolPrewarmResult.REASON_TOKEN_CANCELLED,
		ERR_SKIP,
		2,
		2,
		0,
		0,
		2,
		0
	)
	_pool.prewarm(_scene, _parent, 2)
	assert_eq(_pool.get_available_count(_scene), 2, "pre-cancel 不得泄漏容量 reservation。")
	source.dispose()


func test_ref_counted_owner_bound_prepare_callable_does_not_keep_owner_alive() -> void:
	_pool.max_available_per_scene = 2
	var request_owner: RefCountedPrepareOwner = RefCountedPrepareOwner.new()
	var owner_ref: WeakRef = weakref(request_owner)
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene,
		_parent,
		2,
		1,
		request_owner,
		null,
		Callable(request_owner, &"prepare")
	)
	watch_signals(operation)

	assert_eq(operation.get_created_count(), 1, "首批后请求应仍持有一个未用 reservation。")
	request_owner = null
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(
		owner_ref.get_ref() == null,
		"请求记录不得通过绑定 prepare Callable 强保活 owner。"
	)
	_assert_cancelled_reason(operation, GFObjectPoolPrewarmResult.REASON_OWNER_RELEASED)
	assert_signal_emit_count(operation, "completed", 1, "owner 释放只应终结请求一次。")
	_pool.prewarm(_scene, _parent, 2)
	assert_eq(_pool.get_available_count(_scene), 2, "owner 释放必须归还自身未用 reservation。")


func test_node_owner_release_is_delayed_exact_once_and_capacity_recoverable() -> void:
	_pool.max_available_per_scene = 2
	var request_owner: Node = Node.new()
	add_child(request_owner)
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, _parent, 2, 1, request_owner
	)
	watch_signals(operation)

	request_owner.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		GFObjectPoolPrewarmResult.REASON_OWNER_RELEASED,
		ERR_SKIP,
		2,
		2,
		1,
		0,
		1,
		0
	)
	assert_signal_emit_count(operation, "completed", 1, "延迟 owner 释放应 exact-once。")
	_pool.prewarm(_scene, _parent, 2)
	assert_eq(_pool.get_available_count(_scene), 2, "owner 释放后容量应可补满。")


func test_parent_release_is_delayed_exact_once_and_capacity_recoverable() -> void:
	_pool.max_available_per_scene = 2
	var parent: Node = Node.new()
	add_child(parent)
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, parent, 2, 1
	)
	watch_signals(operation)

	parent.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		GFObjectPoolPrewarmResult.REASON_PARENT_RELEASED,
		ERR_SKIP,
		2,
		2,
		1,
		0,
		1,
		0
	)
	assert_signal_emit_count(operation, "completed", 1, "延迟 parent 释放应 exact-once。")
	_pool.prewarm(_scene, _parent, 2)
	assert_eq(_pool.get_available_count(_scene), 2, "parent 释放后容量应可补满。")


func test_owner_parent_and_token_are_or_cancellation_anchors() -> void:
	var request_owner: Node = Node.new()
	add_child(request_owner)
	var source: GFCancellationSource = GFCancellationSource.new()
	var owner_operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, _parent, 3, 1, request_owner
	)
	request_owner.queue_free()
	assert_true(await _wait_until_completed(owner_operation), "owner 退出应终结请求。")
	_assert_cancelled_reason(owner_operation, GFObjectPoolPrewarmResult.REASON_OWNER_RELEASED)

	var token_operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, _parent, 3, 1, null, source.get_token()
	)
	var _token_cancelled: bool = source.cancel(&"test_cancelled")
	assert_true(await _wait_until_completed(token_operation), "token 取消应终结请求。")
	_assert_cancelled_reason(token_operation, GFObjectPoolPrewarmResult.REASON_TOKEN_CANCELLED)

	var parent: Node = Node.new()
	add_child(parent)
	var parent_operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, parent, 3, 1
	)
	parent.queue_free()
	assert_true(await _wait_until_completed(parent_operation), "parent 退出应终结请求。")
	_assert_cancelled_reason(parent_operation, GFObjectPoolPrewarmResult.REASON_PARENT_RELEASED)
	source.dispose()


func test_prepare_failure_preserves_committed_nodes_and_releases_capacity() -> void:
	_pool.max_available_per_scene = 3
	var prepare_state: Dictionary = {"calls": 0}
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene,
		_parent,
		3,
		0,
		null,
		null,
		func(_node: Node) -> Error:
			prepare_state["calls"] = GFVariantData.get_option_int(prepare_state, "calls") + 1
			return OK if GFVariantData.get_option_int(prepare_state, "calls") == 1 else ERR_INVALID_DATA
	)

	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.FAILED,
		GFObjectPoolPrewarmResult.REASON_PREPARE_CALLBACK_FAILED,
		ERR_INVALID_DATA,
		3,
		3,
		1,
		0,
		0,
		2
	)
	assert_eq(_pool.get_available_count(_scene), 1, "失败前已提交的节点不得回滚。")
	_pool.prewarm(_scene, _parent, 3)
	assert_eq(_pool.get_available_count(_scene), 3, "失败请求的未用 reservation 应全部释放。")


func test_prepare_owner_release_takes_precedence_over_callback_failure() -> void:
	_pool.max_available_per_scene = 2
	var request_owner: QueueFreePrepareOwner = QueueFreePrepareOwner.new()
	add_child(request_owner)
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene,
		_parent,
		2,
		1,
		request_owner,
		null,
		Callable(request_owner, &"prepare")
	)
	watch_signals(operation)

	assert_true(await _wait_until_completed(operation), "callback queue_free owner 应有界终结。")
	await get_tree().process_frame
	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		GFObjectPoolPrewarmResult.REASON_OWNER_RELEASED,
		ERR_SKIP,
		2,
		2,
		1,
		0,
		1,
		0
	)
	assert_signal_emit_count(operation, "completed", 1, "owner anchor 应抢占 callback failure 且 exact-once。")
	_pool.prewarm(_scene, _parent, 2)
	assert_eq(_pool.get_available_count(_scene), 2, "owner callback 取消应释放当前候选 reservation。")


func test_prepare_parent_release_takes_precedence_over_callback_failure() -> void:
	_pool.max_available_per_scene = 2
	var parent: Node = Node.new()
	add_child(parent)
	var prepare_state: Dictionary = {"calls": 0}
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene,
		parent,
		2,
		1,
		null,
		null,
		func(_node: Node) -> Error:
			prepare_state["calls"] = GFVariantData.get_option_int(prepare_state, "calls") + 1
			if GFVariantData.get_option_int(prepare_state, "calls") >= 2:
				parent.queue_free()
				return ERR_INVALID_DATA
			return OK
	)
	watch_signals(operation)

	assert_true(await _wait_until_completed(operation), "callback queue_free parent 应有界终结。")
	await get_tree().process_frame
	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		GFObjectPoolPrewarmResult.REASON_PARENT_RELEASED,
		ERR_SKIP,
		2,
		2,
		1,
		0,
		1,
		0
	)
	assert_signal_emit_count(operation, "completed", 1, "parent anchor 应抢占 callback failure 且 exact-once。")
	_pool.prewarm(_scene, _parent, 2)
	assert_eq(_pool.get_available_count(_scene), 2, "parent callback 取消应释放当前候选 reservation。")


func test_prepare_scope_completion_takes_precedence_over_callback_failure() -> void:
	_pool.max_available_per_scene = 2
	var scope: GFAsyncScope = GFAsyncScope.new()
	var prepare_state: Dictionary = {"calls": 0}
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene,
		_parent,
		2,
		1,
		null,
		scope,
		func(_node: Node) -> Error:
			prepare_state["calls"] = GFVariantData.get_option_int(prepare_state, "calls") + 1
			if GFVariantData.get_option_int(prepare_state, "calls") >= 2:
				scope.complete()
				return ERR_INVALID_DATA
			return OK
	)
	watch_signals(operation)

	assert_true(await _wait_until_completed(operation), "callback complete scope 应有界终结。")
	await get_tree().process_frame
	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.CANCELLED,
		GFObjectPoolPrewarmResult.REASON_CANCELLATION_SCOPE_COMPLETED,
		ERR_SKIP,
		2,
		2,
		1,
		0,
		1,
		0
	)
	assert_signal_emit_count(operation, "completed", 1, "scope anchor 应抢占 callback failure 且 exact-once。")
	_pool.prewarm(_scene, _parent, 2)
	assert_eq(_pool.get_available_count(_scene), 2, "scope callback 取消应释放当前候选 reservation。")


func test_dispose_and_reinitialize_settle_pending_operations_once() -> void:
	var dispose_operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, _parent, 3, 1
	)
	watch_signals(dispose_operation)
	_pool.dispose()
	_assert_disposed_reason(
		dispose_operation,
		GFObjectPoolPrewarmResult.REASON_UTILITY_DISPOSED
	)
	assert_signal_emit_count(dispose_operation, "completed", 1)

	_pool.init()
	var reinitialize_operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, _parent, 3, 1
	)
	watch_signals(reinitialize_operation)
	_pool.init()
	_assert_disposed_reason(
		reinitialize_operation,
		GFObjectPoolPrewarmResult.REASON_UTILITY_REINITIALIZED
	)
	assert_signal_emit_count(reinitialize_operation, "completed", 1)


func test_dispose_settlement_cannot_be_overridden_by_completed_reentry_cancel() -> void:
	_pool.max_available_per_scene = 4
	var first: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, _parent, 2, 1
	)
	var second: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, _parent, 2, 1
	)
	watch_signals(first)
	watch_signals(second)
	var cancel_results: Array[bool] = []
	var _connect_error: int = first.completed.connect(func(
		_result: GFObjectPoolPrewarmResult,
	) -> void:
		cancel_results.append(second.cancel())
	)

	_pool.dispose()
	await get_tree().process_frame
	await get_tree().process_frame

	_assert_disposed_reason(first, GFObjectPoolPrewarmResult.REASON_UTILITY_DISPOSED)
	_assert_disposed_reason(second, GFObjectPoolPrewarmResult.REASON_UTILITY_DISPOSED)
	assert_eq(cancel_results, [false], "dispose settlement 中 caller cancel 不得抢占 B 的终态。")
	assert_signal_emit_count(first, "completed", 1)
	assert_signal_emit_count(second, "completed", 1)

	_pool.init()
	_pool.max_available_per_scene = 4
	_pool.prewarm(_scene, _parent, 4)
	assert_eq(_pool.get_available_count(_scene), 4, "dispose 后新代应能完整补满容量。")


func test_reinitialize_settlement_cannot_be_overridden_by_completed_reentry_cancel() -> void:
	_pool.max_available_per_scene = 4
	var first: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, _parent, 2, 1
	)
	var second: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene, _parent, 2, 1
	)
	watch_signals(first)
	watch_signals(second)
	var cancel_results: Array[bool] = []
	var _connect_error: int = first.completed.connect(func(
		_result: GFObjectPoolPrewarmResult,
	) -> void:
		cancel_results.append(second.cancel())
	)

	_pool.init()
	await get_tree().process_frame
	await get_tree().process_frame

	_assert_disposed_reason(first, GFObjectPoolPrewarmResult.REASON_UTILITY_REINITIALIZED)
	_assert_disposed_reason(second, GFObjectPoolPrewarmResult.REASON_UTILITY_REINITIALIZED)
	assert_eq(cancel_results, [false], "init settlement 中 caller cancel 不得抢占 B 的终态。")
	assert_signal_emit_count(first, "completed", 1)
	assert_signal_emit_count(second, "completed", 1)

	_pool.max_available_per_scene = 4
	_pool.prewarm(_scene, _parent, 4)
	assert_eq(_pool.get_available_count(_scene), 4, "init 新代应能完整补满容量。")


func test_partial_capacity_and_budget_progress_are_request_scoped() -> void:
	_pool.max_available_per_scene = 2
	var progress_counts: Array[int] = []
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_budget_request_async(
		_scene,
		null,
		3,
		0.001,
		null,
		null,
		func(_node: Node) -> Error:
			var deadline_usec: int = Time.get_ticks_usec() + 1000
			while Time.get_ticks_usec() < deadline_usec:
				pass
			return OK
	)
	var _progress_connect_error: int = operation.progressed.connect(func(
		current: GFObjectPoolPrewarmOperation,
	) -> void:
		progress_counts.append(current.get_processed_count())
	)
	assert_true(await _wait_until_completed(operation), "budget request 应在有界帧内完成。")

	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.PARTIAL,
		GFObjectPoolPrewarmResult.REASON_CAPACITY_LIMITED,
		OK,
		3,
		2,
		2,
		1,
		0,
		0
	)
	assert_eq(_pool.get_available_count(_scene), 2)
	assert_eq(operation.get_progress_ratio(), 1.0)
	assert_eq(operation.get_remaining_count(), 0)
	assert_eq(progress_counts, [3], "连接后应只观察第二个提交对应的最终进度。")


func test_prepare_callback_invalid_result_is_typed_failure() -> void:
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene,
		null,
		2,
		0,
		null,
		null,
		func(_node: Node) -> Variant:
			return "not-an-error"
	)

	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.FAILED,
		GFObjectPoolPrewarmResult.REASON_INVALID_PREPARE_CALLBACK_RESULT,
		ERR_INVALID_DATA,
		2,
		2,
		0,
		0,
		0,
		2
	)
	assert_eq(_pool.get_available_count(_scene), 0, "无效回调返回不得提交候选。")


func test_prepare_callback_cancel_discards_current_candidate() -> void:
	var operation_ref: Array[GFObjectPoolPrewarmOperation] = []
	var completed_total_counts: Array[int] = []
	var rogue_barrier_results: Array[bool] = []
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene,
		_parent,
		2,
		1,
		null,
		null,
		func(_node: Node) -> Error:
			if not operation_ref.is_empty():
				var rogue_authority: RefCounted = RefCounted.new()
				rogue_barrier_results.append(
					operation_ref[0].begin_settlement_barrier_for_framework(
						rogue_authority
					)
				)
				var _cancelled: bool = operation_ref[0].cancel()
				rogue_barrier_results.append(
					operation_ref[0].end_settlement_barrier_for_framework(
						rogue_authority
					)
				)
			return OK
	)
	operation_ref.append(operation)
	var _completed_connect_error: int = operation.completed.connect(func(
		_result: GFObjectPoolPrewarmResult,
	) -> void:
		var scene_snapshot: Dictionary = GFVariantData.get_option_dictionary(
			_pool.get_debug_snapshot(),
			operation.get_scene_identity()
		)
		completed_total_counts.append(GFVariantData.get_option_int(scene_snapshot, "total"))
	)

	assert_true(await _wait_until_completed(operation), "第二候选 callback 应取消请求。")
	_assert_cancelled_reason(operation, GFObjectPoolPrewarmResult.REASON_CALLER_CANCELLED)
	assert_eq(operation.get_created_count(), 1, "取消前已提交首个候选应保留。")
	assert_eq(operation.get_cancelled_count(), 1, "当前未提交候选应归入 cancelled。")
	assert_eq(completed_total_counts, [1], "completed observer 不得看到未丢弃的 provisional candidate。")
	assert_eq(rogue_barrier_results, [false, false], "回调不得伪造或提前结束 Utility barrier。")
	assert_eq(_pool.get_available_count(_scene), 1, "callback 内取消不得提交当前候选。")


func test_last_progress_cancellation_cannot_strand_operation() -> void:
	var source: GFCancellationSource = GFCancellationSource.new()
	var operation: GFObjectPoolPrewarmOperation = _pool.prewarm_request_async(
		_scene,
		_parent,
		2,
		1,
		null,
		source.get_token()
	)
	var _progress_connect_error: int = operation.progressed.connect(func(
		current: GFObjectPoolPrewarmOperation,
	) -> void:
		if current.get_created_count() == current.get_admitted_count():
			var _cancelled: bool = source.cancel(&"after_last_progress")
	)

	assert_true(await _wait_until_completed(operation), "最后一次 progress 重入不得悬挂 Operation。")
	_assert_terminal(
		operation,
		GFObjectPoolPrewarmResult.Status.COMPLETED,
		GFObjectPoolPrewarmResult.REASON_COMPLETED,
		OK,
		2,
		2,
		2,
		0,
		0,
		0
	)
	assert_eq(_pool.get_available_count(_scene), 2, "最后候选已提交时取消不得回滚。")
	source.dispose()


# --- 私有/辅助方法 ---

func _make_node_scene() -> PackedScene:
	var node: Node = Node.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_error: Error = scene.pack(node)
	node.free()
	return scene


func _wait_until_completed(
	operation: GFObjectPoolPrewarmOperation,
	max_frames: int = 8
) -> bool:
	for _frame_index: int in range(max_frames):
		if operation.is_completed():
			return true
		await get_tree().process_frame
	return operation.is_completed()


func _assert_terminal(
	operation: GFObjectPoolPrewarmOperation,
	status: GFObjectPoolPrewarmResult.Status,
	reason: StringName,
	error_code: Error,
	requested: int,
	admitted: int,
	created: int,
	skipped: int,
	cancelled: int,
	failed: int
) -> void:
	assert_true(operation.is_completed(), "Operation 应同步或有界进入终态。")
	var result: GFObjectPoolPrewarmResult = operation.get_result()
	assert_not_null(result, "终态应提供隔离 Result。")
	if result == null:
		return
	assert_eq(result.get_status(), status)
	assert_eq(result.get_reason(), reason)
	assert_eq(result.get_error_code(), error_code)
	assert_eq(result.get_requested_count(), requested)
	assert_eq(result.get_admitted_count(), admitted)
	assert_eq(result.get_created_count(), created)
	assert_eq(result.get_skipped_count(), skipped)
	assert_eq(result.get_cancelled_count(), cancelled)
	assert_eq(result.get_failed_count(), failed)
	assert_eq(
		requested,
		created + skipped + cancelled + failed,
		"终态每个请求单位应有唯一 disposition。"
	)


func _reject_direct_operation_cancel(
	_operation: GFObjectPoolPrewarmOperation,
	_reason: StringName,
) -> bool:
	return false


func _assert_cancelled_reason(
	operation: GFObjectPoolPrewarmOperation,
	reason: StringName
) -> void:
	var result: GFObjectPoolPrewarmResult = operation.get_result()
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.get_status(), GFObjectPoolPrewarmResult.Status.CANCELLED)
	assert_eq(result.get_reason(), reason)
	assert_eq(result.get_error_code(), ERR_SKIP)


func _assert_disposed_reason(
	operation: GFObjectPoolPrewarmOperation,
	reason: StringName
) -> void:
	var result: GFObjectPoolPrewarmResult = operation.get_result()
	assert_not_null(result)
	if result == null:
		return
	assert_eq(result.get_status(), GFObjectPoolPrewarmResult.Status.DISPOSED)
	assert_eq(result.get_reason(), reason)
	assert_eq(result.get_error_code(), ERR_UNAVAILABLE)
	assert_eq(
		result.get_admitted_count(),
		result.get_created_count() + result.get_cancelled_count(),
		"lifecycle 终态应保留已提交节点并取消余量。"
	)
