## 测试 GFRequestOutboxUtility 的通用请求排队、重放和持久化。
extends GutTest


# --- 私有变量 ---

var _outbox: GFRequestOutboxUtility
var _storage_path: String = ""


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_storage_path = "user://gf_request_outbox_test_%d.json" % Time.get_ticks_usec()
	_outbox = GFRequestOutboxUtility.new()
	_outbox.storage_path = _storage_path
	_outbox.auto_load_on_init = false
	_outbox.auto_persist = false
	_outbox.retry_delays_msec = [0]
	_outbox.init()


func after_each() -> void:
	if _outbox != null:
		_outbox.dispose()
		_outbox = null
	for path: String in [_storage_path, _storage_path + ".tmp", _storage_path + ".bak"]:
		if FileAccess.file_exists(path):
			var remove_error: Error = DirAccess.remove_absolute(path)
			assert_eq(remove_error, OK, "测试应能删除 request outbox 临时文件。")


# --- 测试方法 ---

func test_replay_success_removes_request_from_queue() -> void:
	var captured: Array[GFRequestEnvelope] = []
	_outbox.transport_callback = func(envelope: GFRequestEnvelope) -> Dictionary:
		captured.append(envelope)
		return { "ok": true, "accepted": true }
	var _enqueued: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/events",
		{ "value": 1 }
	)

	var report: Dictionary = await _outbox.replay()

	assert_eq(captured.size(), 1, "重放应调用一次 transport。")
	assert_eq(GFVariantData.get_option_int(report, "succeeded"), 1, "成功请求应计入报告。")
	assert_eq(_outbox.get_queue_size(), 0, "成功后请求应从等待队列移除。")


func test_replay_waits_for_async_transport_signal() -> void:
	var transport: AsyncTransport = AsyncTransport.new()
	_outbox.transport_callback = Callable(transport, "send")
	var _enqueued: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/events",
		{ "value": 1 }
	)

	var report: Dictionary = await _outbox.replay()

	assert_eq(transport.captured.size(), 1, "异步重放应调用一次 transport。")
	assert_eq(GFVariantData.get_option_int(report, "succeeded"), 1, "异步成功请求应计入报告。")
	assert_eq(_outbox.get_queue_size(), 0, "异步成功后请求应从等待队列移除。")


func test_replay_keeps_queue_consistent_when_current_request_is_removed_during_async_transport() -> void:
	var transport: ManualTransport = ManualTransport.new()
	_outbox.transport_callback = Callable(transport, "send")
	var first: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/first")
	var second: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/second")
	var replay_state: ReplayState = ReplayState.new()

	@warning_ignore("missing_await")
	_await_outbox_replay(replay_state, 1)
	await get_tree().process_frame

	assert_eq(transport.captured.size(), 1, "重放应先发送队首请求。")
	assert_eq(transport.captured[0].request_id, first.request_id, "等待中的请求应是第一个请求。")
	assert_true(_outbox.remove_request(first.request_id), "外部应能在异步发送期间移除等待中的请求。")

	transport.emit_success()
	await get_tree().process_frame
	await get_tree().process_frame

	var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()
	assert_true(replay_state.done, "异步 transport 返回后 replay 应结束。")
	assert_eq(GFVariantData.get_option_int(replay_state.report, "succeeded"), 1, "已被外部移除的成功请求仍应计入成功报告。")
	assert_eq(GFVariantData.get_option_int(replay_state.report, "pending"), 1, "报告应反映剩余等待队列。")
	assert_eq(_outbox.get_queue_size(), 1, "外部移除当前请求后不应误删后续请求。")
	assert_eq(pending_requests[0].request_id, second.request_id, "后续请求应继续保留在等待队列中。")


func test_replay_rejects_concurrent_replay_while_transport_is_waiting() -> void:
	var transport: ManualTransport = ManualTransport.new()
	_outbox.transport_callback = Callable(transport, "send")
	var _enqueued: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/events")
	var first_state: ReplayState = ReplayState.new()
	var second_state: ReplayState = ReplayState.new()

	@warning_ignore("missing_await")
	_await_outbox_replay(first_state)
	await get_tree().process_frame
	@warning_ignore("missing_await")
	_await_outbox_replay(second_state)
	await get_tree().process_frame

	assert_false(first_state.done, "第一轮 replay 应仍在等待 transport。")
	assert_true(second_state.done, "并发 replay 应立即返回。")
	assert_false(GFVariantData.get_option_bool(second_state.report, "ok"), "并发 replay 应返回失败报告。")
	assert_eq(GFVariantData.get_option_string(second_state.report, "reason"), "replay_in_progress", "并发 replay 应给出稳定原因。")
	assert_eq(transport.captured.size(), 1, "并发 replay 不应重复发送同一个请求。")

	transport.emit_success()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(first_state.done, "第一轮 replay 应在 transport 返回后完成。")
	assert_eq(_outbox.get_queue_size(), 0, "第一轮成功完成后队列应清空。")


func test_dispose_during_async_replay_invalidates_late_transport_result() -> void:
	var transport: ManualTransport = ManualTransport.new()
	var completed_count: Array[int] = [0]
	_outbox.transport_callback = Callable(transport, "send")
	var _enqueued: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/events")
	var _connect_result: Error = _outbox.request_completed.connect(func(_envelope: GFRequestEnvelope, _result: Dictionary) -> void:
		completed_count[0] += 1
	) as Error
	var replay_state: ReplayState = ReplayState.new()

	@warning_ignore("missing_await")
	_await_outbox_replay(replay_state)
	await get_tree().process_frame

	_outbox.dispose()
	transport.emit_success()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(replay_state.done, "dispose 后迟到 transport 应让 replay 结束。")
	assert_false(GFVariantData.get_option_bool(replay_state.report, "ok"), "dispose 后 replay 应返回失败报告。")
	assert_eq(GFVariantData.get_option_string(replay_state.report, "reason"), "disposed", "dispose 中断应给出稳定原因。")
	assert_eq(completed_count[0], 0, "dispose 后迟到成功不应再发 request_completed。")


func test_replay_failure_retries_until_success() -> void:
	var attempts: AttemptState = AttemptState.new()
	_outbox.transport_callback = func(_envelope: GFRequestEnvelope) -> Dictionary:
		attempts.count += 1
		return { "ok": attempts.count >= 2, "error": "offline" }
	var envelope: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/retry")
	envelope.max_attempts = 3

	var failed_report: Dictionary = await _outbox.replay()
	assert_eq(envelope.next_attempt_at_unix_msec, 0, "0ms 重试延迟应允许立即重试。")
	var success_report: Dictionary = await _outbox.replay()

	assert_eq(GFVariantData.get_option_int(failed_report, "failed"), 1, "首次失败应计入失败报告。")
	assert_eq(GFVariantData.get_option_int(success_report, "succeeded"), 1, "第二次成功应计入成功报告。")
	assert_eq(attempts.count, 2, "应按重试机制再次调用 transport。")
	assert_eq(_outbox.get_queue_size(), 0, "成功后队列应清空。")


func test_exhausted_request_moves_to_failed_store() -> void:
	_outbox.transport_callback = func(_envelope: GFRequestEnvelope) -> Dictionary:
		return { "ok": false, "error": "denied" }
	var envelope: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_DELETE, "https://example.test/delete")
	envelope.max_attempts = 1

	await _outbox.replay()

	assert_eq(_outbox.get_queue_size(), 0, "耗尽尝试次数后应离开等待队列。")
	assert_eq(_outbox.get_failed_request_count(), 1, "耗尽请求应进入失败列表。")
	assert_eq(_outbox.get_failed_requests()[0].last_error, "denied", "失败列表应保留最近错误。")


func test_queue_persistence_round_trips_typed_body_values() -> void:
	var envelope: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_PUT, "https://example.test/state", {
		"position": Vector2(3.0, 4.0),
	})
	envelope.metadata = { "tags": PackedStringArray(["state"]) }
	assert_false(GFVariantData.get_option_bool(_outbox.get_debug_snapshot(), "is_persisted"), "关闭自动保存后，入队应标记内存状态尚未落盘。")
	var save_error: Error = _outbox.save_queue()

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	var load_error: Error = loaded.load_queue()
	var requests: Array[GFRequestEnvelope] = loaded.get_pending_requests()

	assert_eq(save_error, OK, "保存队列应成功。")
	assert_true(GFVariantData.get_option_bool(_outbox.get_debug_snapshot(), "is_persisted"), "事务保存成功后应标记内存与磁盘一致。")
	assert_eq(load_error, OK, "读取队列应成功。")
	assert_eq(requests.size(), 1, "读取后应恢复一个请求。")
	assert_eq(GFVariantData.get_option_vector2(requests[0].body, "position"), Vector2(3.0, 4.0), "请求 body 中的 Godot 类型应经 JSON 持久化恢复。")
	assert_eq(GFVariantData.get_option_packed_string_array(requests[0].metadata, "tags"), PackedStringArray(["state"]), "请求 metadata 中的 PackedStringArray 应恢复。")
	loaded.dispose()


func test_queue_persistence_keeps_restart_safe_retry_deadline_and_idempotency_key() -> void:
	var envelope: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/restart"
	)
	var stable_idempotency_key: String = envelope.idempotency_key
	envelope.mark_attempt()
	envelope.mark_failure("offline", 5000, 1_700_000_000_000)
	var save_error: Error = _outbox.save_queue()

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	var load_error: Error = loaded.load_queue()
	var requests: Array[GFRequestEnvelope] = loaded.get_pending_requests()

	assert_eq(save_error, OK, "带重试截止时间的队列应能保存。")
	assert_eq(load_error, OK, "新进程应能恢复队列。")
	assert_false(stable_idempotency_key.is_empty(), "Outbox 应为重放请求分配稳定幂等键。")
	assert_eq(requests[0].idempotency_key, stable_idempotency_key, "幂等键跨保存与加载必须保持不变。")
	assert_eq(requests[0].next_attempt_at_unix_msec, 1_700_000_005_000, "重试截止时间应使用跨进程 Unix 毫秒。")
	assert_false(requests[0].can_attempt(1_700_000_004_999), "截止时间之前不得重试。")
	assert_true(requests[0].can_attempt(1_700_000_005_000), "到达截止时间后应允许重试。")
	loaded.dispose()


func test_enqueue_uses_request_identity_as_default_idempotency_key_without_overwriting_explicit_key() -> void:
	var generated: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/generated-key"
	)
	var explicit: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/explicit-key"
	)
	explicit.idempotency_key = "business-operation-42"
	assert_true(_outbox.enqueue(explicit), "带显式幂等键的请求应可入队。")

	assert_false(generated.request_id == &"", "Outbox 应先生成稳定请求身份。")
	assert_eq(generated.idempotency_key, String(generated.request_id), "默认幂等键应与请求身份完全一致。")
	assert_eq(explicit.idempotency_key, "business-operation-42", "项目显式提供的幂等键不得被框架覆盖。")


func test_load_queue_recovers_committed_backup_after_interrupted_replace() -> void:
	var envelope: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/recover"
	)
	var save_error: Error = _outbox.save_queue()
	var backup_path: String = _storage_path + ".bak"
	var interrupt_error: Error = DirAccess.rename_absolute(_storage_path, backup_path)
	assert_eq(save_error, OK, "恢复测试的初始事务应保存成功。")
	assert_eq(interrupt_error, OK, "测试应能模拟 final 已移走但新 final 尚未提交的窗口。")

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	var load_error: Error = loaded.load_queue()
	var requests: Array[GFRequestEnvelope] = loaded.get_pending_requests()

	assert_eq(load_error, OK, "加载应从有效备份恢复事务。")
	assert_eq(requests.size(), 1, "恢复后应保留完整请求。")
	assert_eq(requests[0].request_id, envelope.request_id, "恢复不得改变请求身份。")
	assert_true(FileAccess.file_exists(_storage_path), "有效备份应被提升为正式存储。")
	assert_false(FileAccess.file_exists(backup_path), "成功恢复后不应残留备份文件。")
	loaded.dispose()


func test_load_queue_promotes_valid_temp_when_final_is_missing() -> void:
	var envelope: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/recover-temp"
	)
	assert_eq(_outbox.save_queue(), OK, "恢复测试的初始事务应保存成功。")
	var temp_path: String = _storage_path + ".tmp"
	assert_eq(DirAccess.rename_absolute(_storage_path, temp_path), OK, "测试应能模拟仅临时事务已完整写入的状态。")

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	var load_error: Error = loaded.load_queue()
	var requests: Array[GFRequestEnvelope] = loaded.get_pending_requests()

	assert_eq(load_error, OK, "正式文件缺失时应从有效临时事务恢复。")
	assert_eq(requests.size(), 1, "临时事务恢复后应保留完整请求。")
	assert_eq(requests[0].request_id, envelope.request_id, "临时事务恢复不得改变请求身份。")
	assert_true(FileAccess.file_exists(_storage_path), "有效临时事务应被提升为正式存储。")
	assert_false(FileAccess.file_exists(temp_path), "成功恢复后不应残留临时文件。")
	loaded.dispose()


func test_load_queue_uses_valid_backup_when_final_is_corrupt() -> void:
	var envelope: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/recover-corrupt-final"
	)
	assert_eq(_outbox.save_queue(), OK, "恢复测试的初始事务应保存成功。")
	var backup_path: String = _storage_path + ".bak"
	assert_eq(DirAccess.rename_absolute(_storage_path, backup_path), OK, "测试应能保留有效备份。")
	var corrupt_file: FileAccess = FileAccess.open(_storage_path, FileAccess.WRITE)
	assert_not_null(corrupt_file, "测试应能创建损坏的正式存储。")
	if corrupt_file != null:
		var _stored_corrupt_text: Variant = corrupt_file.store_string("{corrupt-final")
		corrupt_file.close()

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	var load_error: Error = loaded.load_queue()
	var requests: Array[GFRequestEnvelope] = loaded.get_pending_requests()

	assert_eq(load_error, OK, "正式文件损坏时应回退到有效备份。")
	assert_eq(requests.size(), 1, "备份恢复后应保留完整请求。")
	assert_eq(requests[0].request_id, envelope.request_id, "备份恢复不得改变请求身份。")
	assert_false(FileAccess.file_exists(backup_path), "成功提升备份后不应残留旧备份。")
	loaded.dispose()


func test_replay_checkpoints_each_terminal_transition_before_next_transport() -> void:
	var transport: CheckpointTransport = CheckpointTransport.new()
	_outbox.auto_persist = true
	_outbox.transport_callback = Callable(transport, "send")
	var first: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/first"
	)
	var second: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/second"
	)
	var replay_state: ReplayState = ReplayState.new()

	@warning_ignore("missing_await")
	_await_outbox_replay(replay_state)
	await get_tree().process_frame

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	var load_error: Error = loaded.load_queue()
	var persisted: Array[GFRequestEnvelope] = loaded.get_pending_requests()

	assert_eq(load_error, OK, "处理中间检查点应始终是可读取的完整队列。")
	assert_eq(transport.captured.size(), 2, "第二个请求应已进入等待中的 transport。")
	assert_eq(persisted.size(), 1, "第一个成功终态应在发送第二个请求前持久化。")
	assert_eq(persisted[0].request_id, second.request_id, "检查点只应保留尚未完成的第二个请求。")
	assert_ne(persisted[0].request_id, first.request_id, "已经成功的请求不得残留在检查点中。")

	transport.emit_success()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(replay_state.done, "释放第二个 transport 后重放应结束。")
	loaded.dispose()


func test_replay_checkpoints_retryable_failure_before_waiting_on_next_request() -> void:
	var transport: FirstFailureThenManualTransport = FirstFailureThenManualTransport.new()
	_outbox.retry_delays_msec = [10_000]
	_outbox.auto_persist = true
	_outbox.transport_callback = Callable(transport, "send")
	var first: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/retryable")
	first.max_attempts = 3
	var second: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/waiting")
	var replay_state: ReplayState = ReplayState.new()

	@warning_ignore("missing_await")
	_await_outbox_replay(replay_state)
	await get_tree().process_frame

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	assert_eq(loaded.load_queue(), OK, "可重试失败检查点应保持可读取。")
	var persisted: Array[GFRequestEnvelope] = loaded.get_pending_requests()
	var persisted_first: GFRequestEnvelope = _find_request(persisted, first.request_id)

	assert_eq(transport.captured.size(), 2, "第二个请求应已进入等待中的 transport。")
	assert_eq(persisted.size(), 2, "可重试失败仍应与后续请求一起保留在 pending。")
	assert_not_null(persisted_first, "检查点应保留第一个可重试请求。")
	if persisted_first != null:
		assert_eq(persisted_first.attempt_count, 1, "检查点应记录已经发生的发送尝试。")
		assert_eq(persisted_first.last_error, "offline", "检查点应记录最近失败原因。")
		assert_gt(persisted_first.next_attempt_at_unix_msec, 0, "检查点应记录跨重启重试截止时间。")
	assert_not_null(_find_request(persisted, second.request_id), "等待中的第二个请求不得被检查点遗漏。")

	transport.emit_success()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(replay_state.done, "释放第二个 transport 后重放应结束。")
	loaded.dispose()


func test_replay_checkpoints_exhausted_failure_before_waiting_on_next_request() -> void:
	var transport: FirstFailureThenManualTransport = FirstFailureThenManualTransport.new()
	_outbox.auto_persist = true
	_outbox.transport_callback = Callable(transport, "send")
	var first: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/exhausted")
	first.max_attempts = 1
	var second: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/waiting")
	var replay_state: ReplayState = ReplayState.new()

	@warning_ignore("missing_await")
	_await_outbox_replay(replay_state)
	await get_tree().process_frame

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	assert_eq(loaded.load_queue(), OK, "耗尽失败检查点应保持可读取。")
	var pending_requests: Array[GFRequestEnvelope] = loaded.get_pending_requests()
	var failed: Array[GFRequestEnvelope] = loaded.get_failed_requests()

	assert_eq(pending_requests.size(), 1, "耗尽请求应在下一次发送前离开 pending。")
	assert_eq(pending_requests[0].request_id, second.request_id, "pending 只应保留等待中的第二个请求。")
	assert_eq(failed.size(), 1, "耗尽请求应在同一检查点进入 failed store。")
	assert_eq(failed[0].request_id, first.request_id, "failed store 应保留耗尽请求身份。")

	transport.emit_success()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(replay_state.done, "释放第二个 transport 后重放应结束。")
	loaded.dispose()


func test_replay_repairs_exhausted_pending_request_after_restart_without_resending() -> void:
	var exhausted: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/restart-exhausted"
	)
	exhausted.max_attempts = 1
	exhausted.mark_attempt()
	assert_eq(_outbox.save_queue(), OK, "测试应保存模拟崩溃前的耗尽 pending 状态。")

	var transport_calls: Array[int] = [0]
	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	assert_eq(loaded.load_queue(), OK, "新进程应能加载耗尽 pending 状态。")
	loaded.auto_persist = true
	loaded.transport_callback = func(_envelope: GFRequestEnvelope) -> Dictionary:
		transport_calls[0] += 1
		return { "ok": true }
	var report: Dictionary = await loaded.replay()
	loaded.auto_persist = false

	var verified: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	verified.storage_path = _storage_path
	verified.auto_load_on_init = false
	verified.auto_persist = false
	assert_eq(verified.load_queue(), OK, "修复后的检查点应可被再次加载。")

	assert_eq(transport_calls[0], 0, "跨重启恢复不得再次发送已经耗尽的请求。")
	assert_eq(GFVariantData.get_option_int(report, "recovered_exhausted"), 1, "报告应记录修复的耗尽 pending 数量。")
	assert_eq(verified.get_queue_size(), 0, "修复状态持久化后 pending 应为空。")
	assert_eq(verified.get_failed_request_count(), 1, "修复状态持久化后请求应位于 failed store。")
	verified.dispose()
	loaded.dispose()


func test_replay_stops_before_next_transport_when_terminal_checkpoint_fails() -> void:
	var captured: Array[GFRequestEnvelope] = []
	var persistence_failures: Array[Dictionary] = []
	_outbox.transport_callback = func(envelope: GFRequestEnvelope) -> Dictionary:
		captured.append(envelope)
		return { "ok": true }
	var _first: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/first")
	var second: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/second")
	var connect_error: Error = _outbox.persistence_failed.connect(
		func(operation: StringName, error: Error, path: String) -> void:
			persistence_failures.append({
				"operation": String(operation),
				"error": error,
				"path": path,
			})
	) as Error
	assert_eq(connect_error, OK, "测试应能监听持久化失败。")
	_outbox.storage_path = "res://gf_request_outbox_forbidden.json"
	_outbox.auto_persist = true

	var report: Dictionary = await _outbox.replay()
	var snapshot: Dictionary = _outbox.get_debug_snapshot()

	assert_false(GFVariantData.get_option_bool(report, "ok"), "终态检查点失败应使 replay 失败关闭。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "persistence_failed", "失败报告应提供稳定原因。")
	assert_eq(captured.size(), 1, "第一个终态尚未可靠落盘时不得发送第二个请求。")
	assert_eq(_outbox.get_queue_size(), 1, "未发送的第二个请求应继续保留。")
	assert_eq(_outbox.get_pending_requests()[0].request_id, second.request_id, "检查点失败不得误删后续请求。")
	assert_eq(persistence_failures.size(), 1, "检查点失败应发出一次可观测事件。")
	assert_false(GFVariantData.get_option_bool(snapshot, "is_persisted"), "失败后快照应明确内存状态未持久化。")
	_outbox.auto_persist = false
	_outbox.storage_path = _storage_path


func test_queue_persistence_parse_failure_preserves_live_state() -> void:
	var live_request: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/live"
	)
	var file: FileAccess = FileAccess.open(_storage_path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入损坏的 outbox 文件。")
	if file != null:
		var _store_result: Variant = file.store_string("{not-json")
		file.close()

	var load_error: Error = _outbox.load_queue()
	var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()

	assert_eq(load_error, ERR_PARSE_ERROR, "损坏文件应报告解析失败。")
	assert_eq(pending_requests.size(), 1, "解析失败不得清空当前内存队列。")
	assert_eq(pending_requests[0].request_id, live_request.request_id, "解析失败后应保留原请求身份。")


func test_queue_persistence_rejects_storage_paths_outside_user() -> void:
	var _enqueued: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_POST, "https://example.test/state")
	_outbox.storage_path = "res://gf_request_outbox_forbidden.json"

	var save_error: Error = _outbox.save_queue()
	var load_error: Error = _outbox.load_queue()

	assert_eq(save_error, ERR_UNAUTHORIZED, "请求队列不应保存到 user:// 之外。")
	assert_eq(load_error, ERR_UNAUTHORIZED, "请求队列不应从 user:// 之外读取。")
	assert_eq(_outbox.get_queue_size(), 1, "拒绝读取非法路径时不应清空当前队列。")


func _await_outbox_replay(state: ReplayState, max_count: int = 0) -> void:
	state.report = await _outbox.replay(max_count)
	state.done = true


func _find_request(
	requests: Array[GFRequestEnvelope],
	request_id: StringName
) -> GFRequestEnvelope:
	for envelope: GFRequestEnvelope in requests:
		if envelope.request_id == request_id:
			return envelope
	return null


# --- 辅助类 ---

class AsyncTransport:
	extends RefCounted

	signal finished(result: Dictionary)

	var captured: Array[GFRequestEnvelope] = []

	func send(envelope: GFRequestEnvelope) -> Signal:
		captured.append(envelope)
		call_deferred("_emit_success")
		return finished

	func _emit_success() -> void:
		finished.emit({ "ok": true, "accepted": true })


class ManualTransport:
	extends RefCounted

	signal finished(result: Dictionary)

	var captured: Array[GFRequestEnvelope] = []

	func send(envelope: GFRequestEnvelope) -> Signal:
		captured.append(envelope)
		return finished

	func emit_success() -> void:
		finished.emit({ "ok": true, "accepted": true })


class CheckpointTransport:
	extends RefCounted

	signal finished(result: Dictionary)

	var captured: Array[GFRequestEnvelope] = []

	func send(envelope: GFRequestEnvelope) -> Variant:
		captured.append(envelope)
		if captured.size() == 1:
			return { "ok": true }
		return finished

	func emit_success() -> void:
		finished.emit({ "ok": true })


class FirstFailureThenManualTransport:
	extends RefCounted

	signal finished(result: Dictionary)

	var captured: Array[GFRequestEnvelope] = []

	func send(envelope: GFRequestEnvelope) -> Variant:
		captured.append(envelope)
		if captured.size() == 1:
			return { "ok": false, "error": "offline" }
		return finished

	func emit_success() -> void:
		finished.emit({ "ok": true })


class ReplayState:
	extends RefCounted

	var done: bool = false
	var report: Dictionary = {}


class AttemptState:
	extends RefCounted

	var count: int = 0
