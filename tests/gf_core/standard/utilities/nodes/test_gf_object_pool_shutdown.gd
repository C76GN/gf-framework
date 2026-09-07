# 验证对象池安全点清理与架构受控关闭之间的完成边界。
extends GutTest


# --- 私有变量 ---

var _architecture: GFArchitecture
var _pool: GFObjectPoolUtility
var _parent: Node
var _scene: PackedScene


# --- GUT 生命周期方法 ---

func before_each() -> void:
	_architecture = GFArchitecture.new()
	_pool = GFObjectPoolUtility.new()
	assert_true(await _architecture.register_utility_instance(_pool))
	assert_true(await _architecture.init())
	_parent = Node.new()
	add_child(_parent)
	_scene = PackedScene.new()
	var template: Node = Node.new()
	assert_eq(_scene.pack(template), OK)
	template.free()


func after_each() -> void:
	if _architecture != null:
		_architecture.dispose()
	if _pool != null:
		_pool.dispose()
		await _pool.wait_disposed()
	_pool = null
	_architecture = null
	if is_instance_valid(_parent):
		_parent.queue_free()
	_parent = null
	_scene = null
	await get_tree().process_frame


# --- 测试：受控退出 ---

func test_shutdown_waits_for_pool_nodes_leases_and_accepted_requests() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	var probe: ShutdownProbe = ShutdownProbe.new()
	_observe_lease(lease, probe, _pool)
	_start_probe_action(probe, _capture_acquire.bind(probe))
	_start_probe_action(probe, _capture_prewarm.bind(probe))

	var shutdown_result: GFArchitectureShutdownResult = await _architecture.shutdown_async()

	assert_true(shutdown_result.is_successful())
	assert_true(lease.is_settled(), "受控关闭返回前必须结算已有 Lease。")
	assert_eq(probe.exits, 1)
	assert_eq(probe.settlements, 1)
	assert_true(probe.callbacks_kept_old_registration)
	assert_true(probe.acquire_result != null, "已接纳的 acquire 必须先公布取消结果。")
	assert_true(probe.prewarm_result != null, "已接纳的 prewarm 必须先公布取消结果。")
	if probe.acquire_result != null:
		assert_eq(probe.acquire_result.get_status(), GFObjectPoolAcquireResult.Status.CANCELLED)
	if probe.prewarm_result != null:
		assert_eq(probe.prewarm_result.get_status(), GFObjectPoolPrewarmResult.Status.CANCELLED)
	assert_eq(_parent.get_child_count(), 0)
	assert_true(_pool.get_debug_snapshot().is_empty())


func test_replace_waits_for_old_pool_cleanup_before_registration_commit() -> void:
	var previous: GFObjectPoolUtility = _pool
	var result: GFObjectPoolAcquireResult = await previous.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	var probe: ShutdownProbe = ShutdownProbe.new()
	_observe_lease(lease, probe, previous)
	var replacement: GFObjectPoolUtility = GFObjectPoolUtility.new()

	assert_true(await _architecture.replace_utility(GFObjectPoolUtility, replacement))
	_pool = replacement

	assert_true(lease.is_settled())
	assert_eq(probe.exits, 1)
	assert_eq(probe.settlements, 1)
	assert_true(probe.callbacks_kept_old_registration, "退出和结算仍应看到旧 Pool 的注册。")
	assert_eq(_architecture.get_utility(GFObjectPoolUtility, true), replacement)
	assert_eq(_parent.get_child_count(), 0)
	await previous.wait_disposed()


func test_shutdown_reentered_from_first_settlement_waits_for_remaining_notifications() -> void:
	var first: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var second: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var probe: ShutdownProbe = ShutdownProbe.new()
	var _first_connected: Error = first.get_lease().settled.connect(
		_shutdown_from_settled.bind(probe), CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	_observe_lease(second.get_lease(), probe, _pool)

	_pool.dispose()
	await _pool.wait_disposed()
	await _wait_for_shutdown(probe)

	assert_true(probe.shutdown_result != null)
	assert_eq(probe.settlements_at_shutdown, 2, "首个 settled 重入不能越过第二个通知。")
	assert_true(probe.callbacks_kept_old_registration)
	assert_true(first.get_lease().is_settled())
	assert_true(second.get_lease().is_settled())


func test_cancelled_quiesce_completion_does_not_finish_wait_disposed() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	var scope: GFAsyncScope = GFAsyncScope.new()
	var completion: GFAsyncCompletion = _pool.begin_quiesce(scope)
	assert_true(completion.is_pending())
	var _cancelled: bool = completion.cancel(&"lifecycle_timeout")
	var probe: ShutdownProbe = ShutdownProbe.new()
	_start_probe_action(probe, _capture_disposed.bind(probe))

	assert_false(probe.dispose_wait_finished, "生命周期完成源取消不等于清理完成。")
	assert_false(lease.is_settled())
	await _pool.wait_disposed()
	assert_true(probe.dispose_wait_finished)
	assert_true(lease.is_settled())
	assert_true(completion.is_cancelled())
	scope.complete()


func test_cancelled_shutdown_reports_cancellation_and_cleanup_still_finishes_once() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	var probe: ShutdownProbe = ShutdownProbe.new()
	var _connected: Error = lease.settled.connect(_count_settlement.bind(probe)) as Error
	var cancellation: GFAsyncScope = GFAsyncScope.new()
	_start_probe_action(probe, _capture_shutdown.bind(probe, cancellation))
	assert_true(probe.shutdown_result == null, "有效 Pool 的关闭必须等待安全点。")
	var _cancelled: bool = cancellation.cancel("test_cancelled_shutdown")
	await _wait_for_shutdown(probe)

	assert_true(probe.shutdown_result != null)
	if probe.shutdown_result != null:
		assert_eq(probe.shutdown_result.get_status(), GFArchitectureShutdownResult.Status.CANCELLED)
	await _pool.wait_disposed()
	assert_true(lease.is_settled())
	assert_eq(probe.settlements, 1)
	assert_true(_architecture.is_disposed())


func test_timed_out_shutdown_keeps_nonblocking_forced_cleanup_fallback() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var lease: GFObjectPoolLease = result.get_lease()
	var probe: ShutdownProbe = ShutdownProbe.new()
	var _connected: Error = lease.settled.connect(_count_settlement.bind(probe)) as Error
	var blocker: PendingShutdownUtility = PendingShutdownUtility.new()
	blocker.lifecycle_priority = 100
	assert_true(await _architecture.register_utility_instance(blocker))

	var shutdown_result: GFArchitectureShutdownResult = await _architecture.shutdown_async(null, 0.001)

	assert_eq(shutdown_result.get_status(), GFArchitectureShutdownResult.Status.TIMED_OUT)
	assert_true(_architecture.is_disposed())
	assert_false(lease.is_settled(), "先行模块超时后走同步强制退出，不应绕过安全点。")
	await _pool.wait_disposed()
	assert_true(lease.is_settled())
	assert_eq(probe.settlements, 1)
	await _pool.wait_disposed()
	assert_eq(probe.settlements, 1)


func test_repeated_quiesce_waits_share_cleanup_but_not_cancellation() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var cancelled_scope: GFAsyncScope = GFAsyncScope.new()
	var active_scope: GFAsyncScope = GFAsyncScope.new()
	var first: GFAsyncCompletion = _pool.begin_quiesce(cancelled_scope)
	var second: GFAsyncCompletion = _pool.begin_quiesce(active_scope)
	assert_true(first.is_pending())
	assert_true(second.is_pending())
	var _cancelled: bool = cancelled_scope.cancel("first_wait_only")
	assert_true(first.is_cancelled())
	assert_true(second.is_pending())

	await _pool.wait_disposed()

	assert_true(result.get_lease().is_settled())
	assert_true(first.is_cancelled())
	assert_true(second.is_successful())
	var completed: GFAsyncCompletion = _pool.begin_quiesce(active_scope)
	assert_true(completed.is_successful(), "清理完成后再等待不得漏唤醒。")
	active_scope.complete()


func test_shutdown_waits_for_accepted_requests_beyond_one_drain() -> void:
	var probe: ShutdownProbe = ShutdownProbe.new()
	for _index: int in range(80):
		_start_probe_action(probe, _capture_acquire.bind(probe))
	assert_eq(probe.acquire_completions, 0)

	var shutdown_result: GFArchitectureShutdownResult = await _architecture.shutdown_async()

	assert_true(shutdown_result.is_successful())
	assert_eq(probe.acquire_completions, 80)
	assert_eq(_parent.get_child_count(), 0)
	assert_true(_pool.get_debug_snapshot().is_empty())


func test_settlement_reentry_rejects_new_work_and_waits_for_cleanup() -> void:
	var result: GFObjectPoolAcquireResult = await _pool.acquire(_scene, _parent, self)
	var probe: ShutdownProbe = ShutdownProbe.new()
	var _connected: Error = result.get_lease().settled.connect(
		_request_after_close.bind(probe), CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error

	_pool.dispose()
	await _pool.wait_disposed()
	if not probe.dispose_wait_finished:
		await probe.dispose_wait_completed
	if probe.nested_quiesce != null and probe.nested_quiesce.is_pending():
		await probe.nested_quiesce.completed

	assert_true(probe.acquire_result != null)
	assert_true(probe.prewarm_result != null)
	if probe.acquire_result != null:
		assert_eq(probe.acquire_result.get_status(), GFObjectPoolAcquireResult.Status.CANCELLED)
	if probe.prewarm_result != null:
		assert_eq(probe.prewarm_result.get_status(), GFObjectPoolPrewarmResult.Status.CANCELLED)
	assert_false(probe.dispose_finished_inside_settlement)
	assert_true(probe.dispose_wait_finished)
	assert_true(probe.nested_quiesce != null)
	if probe.nested_quiesce != null:
		assert_true(probe.nested_quiesce.is_successful())
	assert_eq(_parent.get_child_count(), 0)


# --- 私有/辅助方法 ---

func _start_probe_action(probe: ShutdownProbe, callback: Callable) -> void:
	var connected: Error = probe.action_requested.connect(callback, CONNECT_ONE_SHOT as Object.ConnectFlags) as Error
	assert_eq(connected, OK)
	probe.action_requested.emit()


func _observe_lease(lease: GFObjectPoolLease, probe: ShutdownProbe, expected_pool: GFObjectPoolUtility) -> void:
	var node: Node = lease.get_node()
	var _exit_connected: Error = node.tree_exiting.connect(
		_observe_exit.bind(probe, expected_pool), CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	var _settled_connected: Error = lease.settled.connect(
		_observe_settled.bind(probe, expected_pool), CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error


func _observe_exit(probe: ShutdownProbe, expected_pool: GFObjectPoolUtility) -> void:
	probe.exits += 1
	_record_registration(probe, expected_pool)


func _observe_settled(_reason: StringName, probe: ShutdownProbe, expected_pool: GFObjectPoolUtility) -> void:
	probe.settlements += 1
	_record_registration(probe, expected_pool)


func _record_registration(probe: ShutdownProbe, expected_pool: GFObjectPoolUtility) -> void:
	if _architecture.is_disposed():
		probe.callbacks_kept_old_registration = false
	elif _architecture.get_utility(GFObjectPoolUtility, true) != expected_pool:
		probe.callbacks_kept_old_registration = false


func _count_settlement(_reason: StringName, probe: ShutdownProbe) -> void:
	probe.settlements += 1


func _shutdown_from_settled(_reason: StringName, probe: ShutdownProbe) -> void:
	probe.settlements += 1
	probe.shutdown_result = await _architecture.shutdown_async()
	probe.settlements_at_shutdown = probe.settlements


func _capture_shutdown(probe: ShutdownProbe, token: GFCancellationToken) -> void:
	probe.shutdown_result = await _architecture.shutdown_async(token)


func _capture_disposed(probe: ShutdownProbe) -> void:
	await _pool.wait_disposed()
	probe.dispose_wait_finished = true
	probe.dispose_wait_completed.emit()


func _capture_acquire(probe: ShutdownProbe) -> void:
	probe.acquire_result = await _pool.acquire(_scene, _parent, self)
	probe.acquire_completions += 1


func _capture_prewarm(probe: ShutdownProbe) -> void:
	probe.prewarm_result = await _pool.prewarm(_scene, 3, 1)


func _request_after_close(_reason: StringName, probe: ShutdownProbe) -> void:
	_start_probe_action(probe, _capture_acquire.bind(probe))
	_start_probe_action(probe, _capture_prewarm.bind(probe))
	_start_probe_action(probe, _capture_disposed.bind(probe))
	probe.dispose_finished_inside_settlement = probe.dispose_wait_finished
	probe.nested_quiesce = _pool.begin_quiesce(null)


func _wait_for_shutdown(probe: ShutdownProbe) -> void:
	for _frame: int in range(20):
		if probe.shutdown_result != null:
			return
		await get_tree().process_frame


# --- 内部类 ---

class ShutdownProbe extends RefCounted:
	signal action_requested
	signal dispose_wait_completed
	var exits: int = 0
	var settlements: int = 0
	var settlements_at_shutdown: int = 0
	var callbacks_kept_old_registration: bool = true
	var dispose_wait_finished: bool = false
	var dispose_finished_inside_settlement: bool = false
	var acquire_completions: int = 0
	var nested_quiesce: GFAsyncCompletion = null
	var shutdown_result: GFArchitectureShutdownResult = null
	var acquire_result: GFObjectPoolAcquireResult = null
	var prewarm_result: GFObjectPoolPrewarmResult = null


class PendingShutdownUtility extends GFUtility:
	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		return GFAsyncCompletion.new()
