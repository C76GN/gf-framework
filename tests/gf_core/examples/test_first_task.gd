# 相同基础合同同时约束同步和异步样例，不把错误路径从薄接入中删掉。
extends GutTest


# --- 常量 ---

const SESSION = preload("res://examples/first_task/task_session.gd")
const TASK_SERVICE = preload("res://examples/first_task/task_service.gd")
const ASYNC_CALL = preload("res://addons/gf/kernel/core/gf_async_call.gd")


# --- 私有变量 ---

var _sessions: Array[SESSION] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for session: SESSION in _sessions:
		session.dispose()
	_sessions.clear()
	await get_tree().process_frame


# --- 测试用例 ---

func test_basic_and_async_modes_share_persistence_and_cancel_contract() -> void:
	for asynchronous: bool in [false, true]:
		var store: StoreProbe = StoreProbe.new()
		var session: SESSION = _new_session()
		assert_true(
			await session.start(
				"memory",
				asynchronous,
				store
			)
		)
		var completed: GFAsyncCompletion = session.increment()
		session.tick(1.0)
		assert_true(completed.is_successful())
		assert_eq(session.count, 1)
		assert_eq(
			session.save(),
			OK
		)
		assert_eq(
			GFVariantData.get_option_int(
				store.payload,
				"count",
				-1
			),
			1
		)
		assert_true(await session.close())
		var restored_store: StoreProbe = StoreProbe.new()
		restored_store.payload = store.payload.duplicate(true)
		var restored: SESSION = _new_session()
		assert_true(
			await restored.start(
				"memory",
				asynchronous,
				restored_store
			)
		)
		assert_eq(restored.count, 1)
		assert_true(await restored.close())


func test_corrupt_settings_fail_without_overwrite() -> void:
	var store: StoreProbe = StoreProbe.new()
	store.corrupt = true
	var session: SESSION = _new_session()
	assert_false(
		await session.start(
			"memory",
			false,
			store
		)
	)
	assert_eq(store.writes, 0)
	assert_true(session.closed)
	assert_string_contains(session.last_error, "原文件未覆盖")


func test_invalid_count_types_and_bounds_fail_without_coercion_or_write() -> void:
	for value: Variant in [
		"not-an-integer",
		-1,
		0.5,
		SESSION.MAX_COUNT + 1,
	]:
		var store: StoreProbe = StoreProbe.new()
		store.payload = { "count": value }
		var session: SESSION = _new_session()
		assert_false(
			await session.start(
				"memory",
				false,
				store
			)
		)
		assert_eq(store.writes, 0)
		var preserved: Variant = store.payload["count"]
		assert_true(
			is_same(preserved, value),
			"无效原值及其类型都须保留。"
		)


func test_pending_increments_reserve_capacity_before_reaching_numeric_limit() -> void:
	var store: StoreProbe = StoreProbe.new()
	store.payload = { "count": SESSION.MAX_COUNT - 1 }
	var session: SESSION = _new_session()
	assert_true(
		await session.start(
			"memory",
			true,
			store
		)
	)
	var ticket: GFAsyncCompletion = session.increment()
	assert_true(session.increment().is_failed())
	session.tick(1.0)
	assert_true(ticket.is_successful())
	assert_eq(session.count, SESSION.MAX_COUNT)
	assert_true(session.increment().is_failed())
	assert_true(await session.close())


func test_full_queue_cancel_and_duplicate_completion_never_double_commit() -> void:
	var session: SESSION = _new_session()
	assert_true(
		await session.start(
			"memory",
			true,
			StoreProbe.new()
		)
	)
	var tickets: Array[GFAsyncCompletion] = []
	for index: int in range(4):
		tickets.append(session.increment())
	assert_true(session.increment().is_failed())
	assert_true(tickets[0].cancel(&"user_cancelled"))
	session.tick(1.0)
	assert_eq(session.count, 3)
	assert_false(
		tickets[1].succeed(1),
		"重复完成不能再发出完成信号。"
	)
	assert_eq(session.count, 3)
	assert_true(await session.close())


func test_close_drains_once_and_rejects_concurrent_work_and_exit() -> void:
	var session: SESSION = _new_session()
	var store: StoreProbe = StoreProbe.new()
	assert_true(
		await session.start(
			"memory",
			true,
			store
		)
	)
	var ticket: GFAsyncCompletion = session.increment()
	var state: Dictionary = { "finished": false, "ok": false }
	ASYNC_CALL.run_detached(
		_capture_close,
		[session, state]
	)
	assert_true(session.closing)
	assert_false(await session.close())
	assert_true(session.increment().is_failed())
	assert_eq(store.writes, 0)
	session.tick(1.0)
	await get_tree().process_frame
	assert_true(ticket.is_successful())
	assert_true(GFVariantData.get_option_bool(state, "finished"))
	assert_true(GFVariantData.get_option_bool(state, "ok"))
	assert_eq(store.writes, 1)
	assert_eq(
		GFVariantData.get_option_int(
			store.payload,
			"count",
			-1
		),
		1
	)
	assert_true(await session.close())
	assert_eq(
		store.writes,
		1,
		"已完成关闭重复调用不能重写设置。"
	)


func test_save_failure_retains_state_and_retry_does_not_replay_work() -> void:
	var session: SESSION = _new_session()
	var store: StoreProbe = StoreProbe.new()
	store.write_error = ERR_FILE_CANT_WRITE
	assert_true(
		await session.start(
			"memory",
			true,
			store
		)
	)
	var ticket: GFAsyncCompletion = session.increment()
	session.tick(1.0)
	assert_true(ticket.is_successful())
	assert_false(await session.close())
	assert_false(session.closed)
	assert_eq(session.count, 1)
	assert_true(session.increment().is_failed())
	store.write_error = OK
	assert_true(await session.close())
	assert_eq(
		GFVariantData.get_option_int(
			store.payload,
			"count",
			-1
		),
		1
	)
	assert_eq(store.writes, 2)


func test_mode_is_fixed_for_session_lifetime() -> void:
	var session: SESSION = _new_session()
	assert_true(
		await session.start(
			"memory",
			false,
			StoreProbe.new()
		)
	)
	assert_false(
		await session.start(
			"memory",
			true,
			StoreProbe.new()
		)
	)
	assert_true(session.increment().is_successful())
	assert_true(await session.close())


func test_forced_release_cancels_pending_jobs_without_late_state_write() -> void:
	var session: SESSION = _new_session()
	assert_true(
		await session.start(
			"memory",
			true,
			StoreProbe.new()
		)
	)
	var ticket: GFAsyncCompletion = session.increment()
	session.dispose()
	assert_true(ticket.is_cancelled())
	session.tick(1.0)
	assert_eq(session.count, 0)


func test_failed_shutdown_never_becomes_success_on_repeated_close() -> void:
	var session: SESSION = _new_session()
	assert_true(
		await session.start(
			"memory",
			false,
			FailingShutdownStore.new()
		)
	)
	assert_false(await session.close())
	assert_true(session.closed)
	assert_string_contains(session.last_error, "架构关闭未完全成功")
	assert_false(
		await session.close(),
		"失败终态必须在重复退出中保留。"
	)


# --- 私有/辅助方法 ---

func _new_session() -> SESSION:
	var session: SESSION = SESSION.new()
	_sessions.append(session)
	return session


func _capture_close(session: SESSION, state: Dictionary) -> void:
	state["ok"] = await session.close()
	state["finished"] = true


# --- 内部类 ---

class FailingShutdownStore extends StoreProbe:
	func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
		var completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _failed: bool = completion.fail("Injected store shutdown failure")
		return completion


class StoreProbe extends GFSettingsStoreUtility:
	var payload: Dictionary = {}
	var corrupt: bool = false
	var writes: int = 0
	var write_error: Error = OK

	func is_persistence_enabled() -> bool:
		return true


	func read_settings(_file_name: String) -> GFStorageReadResult:
		if corrupt:
			return (
				GFStorageReadResult.new().configure_failure(
					"Corrupt",
					ERR_FILE_CORRUPT,
					{},
					GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
					0,
					GFStorageReadResult.FailureKind.CORRUPT
				)
			)
		if payload.is_empty():
			return (
				GFStorageReadResult.new().configure_failure(
					"Missing",
					ERR_FILE_NOT_FOUND,
					{},
					GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
					0,
					GFStorageReadResult.FailureKind.NOT_FOUND
				)
			)
		return GFStorageReadResult.new().configure_success(payload.duplicate(true))


	func write_settings(_file_name: String, data: Dictionary) -> Error:
		writes += 1
		if write_error == OK:
			payload = data.duplicate(true)
		return write_error
