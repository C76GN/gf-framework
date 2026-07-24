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


func test_enqueue_with_report_uses_snapshot_and_can_force_persistence() -> void:
	var source: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/atomic",
		{ "value": 1 }
	)
	source.idempotency_key = "atomic-operation"
	source.max_attempts = 7

	var enqueue_report: Dictionary = _outbox.enqueue_with_report(source, true)
	var queued: GFRequestEnvelope = _variant_to_request_envelope(
		GFVariantData.get_option_value(enqueue_report, "envelope")
	)
	source.body["value"] = 99
	source.idempotency_key = "mutated"
	source.max_attempts = 1
	var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()

	assert_true(GFVariantData.get_option_bool(enqueue_report, "ok"), "强制持久入队应成功。")
	assert_true(GFVariantData.get_option_bool(enqueue_report, "persisted"), "成功报告应确认请求已经落盘。")
	assert_not_null(queued, "成功报告应返回隔离的请求快照。")
	assert_eq(pending_requests.size(), 1, "原子入队应增加一个等待请求。")
	assert_eq(GFVariantData.get_option_int(pending_requests[0].body, "value"), 1, "调用方后续修改不得污染队列快照。")
	assert_eq(pending_requests[0].idempotency_key, "atomic-operation", "队列应保留入队前设置的幂等键。")
	assert_eq(pending_requests[0].max_attempts, 7, "队列应保留入队前设置的尝试上限。")

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	assert_eq(loaded.load_queue(), OK, "原子入队生成的事务应可恢复。")
	assert_eq(loaded.get_pending_requests()[0].idempotency_key, "atomic-operation", "首次持久化应包含显式幂等键。")
	assert_eq(loaded.get_pending_requests()[0].max_attempts, 7, "首次持久化应包含显式尝试上限。")
	loaded.dispose()


func test_enqueue_with_report_rolls_back_when_required_persistence_fails() -> void:
	_outbox.storage_path = "res://gf_request_outbox_forbidden.json"
	var queue_sizes_at_failure: Array[int] = []
	var _failure_connected: Error = _outbox.persistence_failed.connect(
		func(_operation: StringName, _error: Error, _path: String) -> void:
			queue_sizes_at_failure.append(_outbox.get_queue_size())
	) as Error
	var source: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/atomic-failure"
	)

	var enqueue_report: Dictionary = _outbox.enqueue_with_report(source, true)

	assert_false(GFVariantData.get_option_bool(enqueue_report, "ok"), "强制持久化失败应拒绝入队。")
	assert_eq(
		GFVariantData.get_option_string_name(enqueue_report, "reason"),
		&"persistence_failed",
		"失败报告应提供稳定原因。"
	)
	assert_eq(
		GFVariantData.get_option_int(enqueue_report, "persistence_error"),
		ERR_UNAUTHORIZED,
		"失败报告应保留持久化错误码。"
	)
	assert_eq(_outbox.get_queue_size(), 0, "持久化失败必须回滚本次内存入队。")
	assert_eq(queue_sizes_at_failure, [0], "持久化失败通知应在原子入队回滚后发出。")
	_outbox.storage_path = _storage_path


func test_required_enqueue_rolls_back_when_storage_byte_limit_is_exceeded() -> void:
	var seed_request: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/already-durable"
	)
	seed_request.request_id = &"already-durable"
	assert_true(_outbox.enqueue(seed_request), "测试前置请求应进入内存队列。")
	assert_eq(_outbox.save_queue(), OK, "测试前置请求应先形成有效事务。")
	var previous_storage_size: int = FileAccess.get_file_as_bytes(_storage_path).size()
	_outbox.max_storage_bytes = previous_storage_size + 128
	var source: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/storage-limit",
		{ "padding": "x".repeat(1024) }
	)

	var enqueue_report: Dictionary = _outbox.enqueue_with_report(source, true)

	assert_false(GFVariantData.get_option_bool(enqueue_report, "ok"), "超出存储字节上限时必须拒绝可靠入队。")
	assert_eq(
		GFVariantData.get_option_string_name(enqueue_report, "reason"),
		&"persistence_failed",
		"字节上限失败应使用稳定的持久化失败原因。"
	)
	assert_eq(
		GFVariantData.get_option_int(enqueue_report, "persistence_error"),
		ERR_OUT_OF_MEMORY,
		"字节上限失败应保留明确错误码。"
	)
	assert_eq(_outbox.get_queue_size(), 1, "字节上限失败必须只回滚本次内存入队。")
	_outbox.max_storage_bytes = 16 * 1024 * 1024
	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	assert_eq(loaded.load_queue(), OK, "失败前的有效事务仍应可恢复。")
	var restored: Array[GFRequestEnvelope] = loaded.get_pending_requests()
	assert_eq(restored.size(), 1, "保存超限不得改写之前的有效事务。")
	assert_eq(restored[0].request_id, seed_request.request_id, "旧事务应只保留原请求。")
	loaded.dispose()


func test_required_enqueue_fails_when_request_signal_clears_queue() -> void:
	var _connected: Error = _outbox.request_enqueued.connect(
		func(_envelope: GFRequestEnvelope) -> void:
			_outbox.clear_queue()
	) as Error
	var source: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/reentrant-clear"
	)

	var enqueue_report: Dictionary = _outbox.enqueue_with_report(source, true)

	assert_false(GFVariantData.get_option_bool(enqueue_report, "ok"), "同步监听器撤销入队后不得返回成功回执。")
	assert_eq(
		GFVariantData.get_option_string_name(enqueue_report, "reason"),
		&"enqueue_invalidated",
		"撤销后的回执应说明入队已失效。"
	)
	assert_eq(_outbox.get_queue_size(), 0, "监听器清理后的队列应保持为空。")
	_assert_persisted_queue_is_empty()


func test_required_enqueue_fails_when_queue_changed_listener_removes_request() -> void:
	var is_handling: Array[bool] = [false]
	var _connected: Error = _outbox.queue_changed.connect(
		func(_snapshot: Dictionary) -> void:
			if is_handling[0]:
				return
			var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()
			if pending_requests.is_empty():
				return
			is_handling[0] = true
			var _removed: bool = _outbox.remove_request(pending_requests[0].request_id)
			is_handling[0] = false
	) as Error
	var source: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/reentrant-remove"
	)

	var enqueue_report: Dictionary = _outbox.enqueue_with_report(source, true)

	assert_false(GFVariantData.get_option_bool(enqueue_report, "ok"), "queue_changed 监听器移除请求后不得返回成功。")
	assert_eq(
		GFVariantData.get_option_string_name(enqueue_report, "reason"),
		&"enqueue_invalidated",
		"移除后的回执应说明入队已失效。"
	)
	assert_eq(_outbox.get_queue_size(), 0, "监听器移除后不应残留等待请求。")
	_assert_persisted_queue_is_empty()


func test_required_enqueue_fails_when_request_signal_disposes_outbox() -> void:
	var _connected: Error = _outbox.request_enqueued.connect(
		func(_envelope: GFRequestEnvelope) -> void:
			_outbox.dispose()
	) as Error
	var source: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/reentrant-dispose"
	)

	var enqueue_report: Dictionary = _outbox.enqueue_with_report(source, true)

	assert_false(GFVariantData.get_option_bool(enqueue_report, "ok"), "监听器释放 Outbox 后不得返回成功回执。")
	assert_eq(
		GFVariantData.get_option_string_name(enqueue_report, "reason"),
		&"enqueue_invalidated",
		"释放后的回执应说明入队已失效。"
	)
	assert_eq(_outbox.get_queue_size(), 0, "释放 Outbox 后内存队列应为空。")
	_assert_persisted_queue_is_empty()


func test_required_enqueue_pins_storage_path_across_synchronous_notifications() -> void:
	var changed_path: String = _storage_path + ".changed"
	var _connected: Error = _outbox.request_enqueued.connect(
		func(_envelope: GFRequestEnvelope) -> void:
			_outbox.storage_path = changed_path
	) as Error
	var source: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/reentrant-path"
	)

	var enqueue_report: Dictionary = _outbox.enqueue_with_report(source, true)

	assert_true(GFVariantData.get_option_bool(enqueue_report, "ok"), "事务期间的路径改写不得破坏已完成的原路径回执。")
	assert_true(GFVariantData.get_option_bool(enqueue_report, "persisted"), "原路径事务仍应报告可靠持久化。")
	assert_eq(_outbox.storage_path, _storage_path, "可靠入队应把同步监听器的路径改写恢复到事务原路径。")
	assert_false(FileAccess.file_exists(changed_path), "同步路径改写不得产生第二份持久化所有权。")
	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	assert_eq(loaded.load_queue(), OK, "事务原路径应保持可恢复。")
	assert_eq(loaded.get_queue_size(), 1, "事务原路径应恢复已确认接管的请求。")
	loaded.dispose()
	for path: String in [changed_path, changed_path + ".tmp", changed_path + ".bak"]:
		if FileAccess.file_exists(path):
			var _remove_error: Error = DirAccess.remove_absolute(path)


func test_required_enqueue_repersists_original_path_after_listener_saves_new_revision_elsewhere() -> void:
	var alternate_path: String = _storage_path + ".alternate"
	var seed_request: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/seed"
	)
	seed_request.request_id = &"seed-request"
	assert_true(
		GFVariantData.get_option_bool(_outbox.enqueue_with_report(seed_request, true), "ok"),
		"测试前置请求应先可靠写入原路径。"
	)
	var listener_save_errors: Array[Error] = []
	var _connected: Error = _outbox.request_enqueued.connect(
		func(envelope: GFRequestEnvelope) -> void:
			if envelope.request_id == &"seed-request":
				return
			assert_true(_outbox.remove_request(&"seed-request"), "监听器应能移除旧请求。")
			_outbox.storage_path = alternate_path
			listener_save_errors.append(_outbox.save_queue())
	) as Error
	var source: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/revision-pinned"
	)
	source.request_id = &"revision-pinned"

	var enqueue_report: Dictionary = _outbox.enqueue_with_report(source, true)

	assert_eq(listener_save_errors, [OK], "监听器应在替代路径保存新的队列 revision。")
	assert_true(GFVariantData.get_option_bool(enqueue_report, "ok"), "可靠入口应补偿保存原路径的最新 revision。")
	assert_true(GFVariantData.get_option_bool(enqueue_report, "persisted"), "回执必须绑定原路径和当前 revision。")
	assert_eq(_outbox.storage_path, _storage_path, "通知结束后应恢复事务原路径。")
	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	assert_eq(loaded.load_queue(), OK, "原路径的补偿事务应可恢复。")
	var restored: Array[GFRequestEnvelope] = loaded.get_pending_requests()
	assert_eq(restored.size(), 1, "原路径不得复活监听器已移除的旧请求。")
	assert_eq(restored[0].request_id, &"revision-pinned", "原路径应只保留已确认的新请求。")
	loaded.dispose()
	for path: String in [alternate_path, alternate_path + ".tmp", alternate_path + ".bak"]:
		if FileAccess.file_exists(path):
			var _remove_error: Error = DirAccess.remove_absolute(path)


func test_persistence_proof_detects_mutation_through_legacy_enqueue_alias() -> void:
	var legacy_alias: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/legacy-alias",
		{ "value": 1 }
	)
	assert_eq(_outbox.save_queue(), OK, "测试前置队列应成功持久化。")
	assert_true(
		GFVariantData.get_option_bool(_outbox.get_debug_snapshot(), "is_persisted"),
		"未变化的队列应具有当前路径的持久化证明。"
	)

	legacy_alias.body["value"] = 2

	assert_false(
		GFVariantData.get_option_bool(_outbox.get_debug_snapshot(), "is_persisted"),
		"旧入口暴露的别名发生修改后不得继续报告过期的耐久证明。"
	)
	var reliable: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/reliable-after-alias"
	)
	var enqueue_report: Dictionary = _outbox.enqueue_with_report(reliable, true)
	assert_true(GFVariantData.get_option_bool(enqueue_report, "ok"), "可靠入口应重新保存别名修改后的完整队列。")
	assert_true(GFVariantData.get_option_bool(enqueue_report, "persisted"), "重新保存后应恢复精确状态证明。")

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	assert_eq(loaded.load_queue(), OK, "重启应能恢复重新保存的队列。")
	assert_eq(
		GFVariantData.get_option_int(loaded.get_pending_requests()[0].body, "value"),
		2,
		"重新保存必须包含调用方通过旧别名完成的修改。"
	)
	loaded.dispose()


func test_enqueue_with_report_rejects_unsupported_and_circular_values() -> void:
	var invalid_values: Array = [
		RefCounted.new(),
		func() -> void:
			pass,
		_outbox.queue_changed,
		RID(),
	]
	for invalid_value: Variant in invalid_values:
		var source: GFRequestEnvelope = GFRequestEnvelope.new(
			HTTPClient.METHOD_POST,
			"https://example.test/non-persistable"
		)
		source.body = { "value": invalid_value }
		var report: Dictionary = _outbox.enqueue_with_report(source, true)
		assert_false(GFVariantData.get_option_bool(report, "ok"), "不受 codec 支持的 Variant 必须在复制与保存前拒绝。")
		assert_eq(
			GFVariantData.get_option_string_name(report, "reason"),
			&"non_persistable_envelope",
			"不支持的 Variant 应使用稳定拒绝原因。"
		)

	var circular: Dictionary = {}
	circular["self"] = circular
	var circular_source: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/circular"
	)
	circular_source.body = circular
	var circular_report: Dictionary = _outbox.enqueue_with_report(circular_source, true)

	assert_false(GFVariantData.get_option_bool(circular_report, "ok"), "循环集合必须在深复制前拒绝。")
	assert_eq(
		GFVariantData.get_option_string_name(circular_report, "reason"),
		&"non_persistable_envelope",
		"循环集合应使用稳定拒绝原因。"
	)
	assert_eq(_outbox.get_queue_size(), 0, "所有不可持久化请求都不得进入内存队列。")


func test_required_enqueue_rejects_persistence_structure_limits_before_encoding() -> void:
	var long_text: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/long-text"
	)
	long_text.body = { "value": "x".repeat(65537) }
	var long_text_report: Dictionary = _outbox.enqueue_with_report(long_text, true)

	var packed: PackedByteArray = PackedByteArray()
	var packed_resize_error: Error = packed.resize(65_537) as Error
	assert_eq(packed_resize_error, OK, "测试夹具应成功构造超限 PackedByteArray。")
	var large_collection: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/large-collection"
	)
	large_collection.body = { "value": packed }
	var large_collection_report: Dictionary = _outbox.enqueue_with_report(
		large_collection,
		true
	)

	var nested_root: Array = []
	var nested_cursor: Array = nested_root
	for _index: int in range(66):
		var child: Array = []
		nested_cursor.append(child)
		nested_cursor = child
	var deep: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/deep"
	)
	deep.body = { "value": nested_root }
	var deep_report: Dictionary = _outbox.enqueue_with_report(deep, true)

	for report: Dictionary in [
		long_text_report,
		large_collection_report,
		deep_report,
	]:
		assert_false(
			GFVariantData.get_option_bool(report, "ok"),
			"持久化结构硬上限必须在 JSON 编码前拒绝。"
		)
		assert_eq(
			GFVariantData.get_option_string_name(report, "reason"),
			&"non_persistable_envelope",
			"结构预算失败应使用稳定拒绝原因。"
		)
	assert_eq(_outbox.get_queue_size(), 0, "结构预算失败不得修改队列。")
	assert_false(FileAccess.file_exists(_storage_path), "结构预算失败不得创建事务文件。")


func test_non_required_enqueue_preserves_memory_only_acceptance_for_unsupported_value() -> void:
	var source: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/memory-only"
	)
	source.body = { "value": RefCounted.new() }

	var report: Dictionary = _outbox.enqueue_with_report(source, false)

	assert_true(
		GFVariantData.get_option_bool(report, "ok"),
		"非可靠入口应保留仅内存接受语义。"
	)
	assert_false(
		GFVariantData.get_option_bool(report, "persisted"),
		"不可持久化的仅内存请求不得伪装为已落盘。"
	)
	assert_eq(_outbox.get_queue_size(), 1, "仅内存请求应保留在等待队列中。")


func test_save_queue_rejects_unsupported_legacy_envelope_without_rewriting_value() -> void:
	var source: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"https://example.test/legacy-unsupported"
	)
	source.body = { "value": RefCounted.new() }
	assert_true(_outbox.enqueue(source), "旧入口仍可保留其内存接受语义。")

	var save_error: Error = _outbox.save_queue()

	assert_eq(save_error, ERR_INVALID_DATA, "显式保存不得把不支持的 Variant 静默改写为 null。")
	assert_false(FileAccess.file_exists(_storage_path), "拒绝持久化时不应提交不等价的事务文件。")
	assert_eq(_outbox.get_queue_size(), 1, "保存失败不应删除调用方已放入内存的旧入口请求。")


func test_persistence_failure_signal_does_not_recurse_when_listener_saves_again() -> void:
	var failure_count: Array[int] = [0]
	_outbox.storage_path = "res://gf_request_outbox_forbidden.json"
	var _failure_connected: Error = _outbox.persistence_failed.connect(
		func(_operation: StringName, _error: Error, _path: String) -> void:
			failure_count[0] += 1
			var _nested_save_error: Error = _outbox.save_queue()
	) as Error

	var save_error: Error = _outbox.save_queue()

	assert_eq(save_error, ERR_UNAUTHORIZED, "非法路径保存应失败。")
	assert_eq(failure_count[0], 1, "持久化失败监听器重试保存时不得递归发出信号。")
	_outbox.storage_path = _storage_path


func test_request_signals_filter_and_transport_receive_isolated_envelopes() -> void:
	var original_request_id: Array[StringName] = [&""]
	var _enqueued_connected: Error = _outbox.request_enqueued.connect(
		func(envelope: GFRequestEnvelope) -> void:
			original_request_id[0] = envelope.request_id
			envelope.request_id = &"mutated_by_enqueue_signal"
			envelope.body["value"] = 10
	) as Error
	var _started_connected: Error = _outbox.request_started.connect(
		func(envelope: GFRequestEnvelope) -> void:
			envelope.request_id = &"mutated_by_started_signal"
			envelope.body["value"] = 20
	) as Error
	var _failed_connected: Error = _outbox.request_failed.connect(
		func(envelope: GFRequestEnvelope, _result: Dictionary) -> void:
			envelope.request_id = &"mutated_by_failed_signal"
			envelope.body["value"] = 30
	) as Error
	_outbox.replay_filter = func(envelope: GFRequestEnvelope) -> bool:
		envelope.request_id = &"mutated_by_filter"
		envelope.body["value"] = 40
		return true
	_outbox.transport_callback = func(envelope: GFRequestEnvelope) -> Dictionary:
		envelope.request_id = &"mutated_by_transport"
		envelope.body["value"] = 50
		return { "ok": false, "error": "offline" }
	var source: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/isolated",
		{ "value": 1 }
	)
	source.max_attempts = 3

	await _outbox.replay(1)
	var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()

	assert_eq(pending_requests.size(), 1, "可重试失败应继续保留请求。")
	assert_eq(pending_requests[0].request_id, original_request_id[0], "所有回调中的身份修改都不得污染内部请求。")
	assert_eq(GFVariantData.get_option_int(pending_requests[0].body, "value"), 1, "所有回调中的载荷修改都不得污染内部请求。")
	assert_eq(pending_requests[0].attempt_count, 1, "内部请求仍应记录真实发送尝试。")


func test_request_started_clear_invalidates_replay_before_transport() -> void:
	var transport_calls: Array[int] = [0]
	var _started_connected: Error = _outbox.request_started.connect(
		func(_envelope: GFRequestEnvelope) -> void:
			_outbox.clear_queue()
	) as Error
	_outbox.transport_callback = func(_envelope: GFRequestEnvelope) -> Dictionary:
		transport_calls[0] += 1
		return { "ok": true }
	var _enqueued: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/reentrant-clear"
	)

	var report: Dictionary = await _outbox.replay()

	assert_eq(transport_calls[0], 0, "request_started 清理队列后不得继续发送。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "被通知重入失效的 replay 应失败关闭。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "replay_invalidated", "报告应说明 replay 已失效。")


func test_replay_filter_clear_invalidates_replay_before_transport() -> void:
	var transport_calls: Array[int] = [0]
	_outbox.replay_filter = func(_envelope: GFRequestEnvelope) -> bool:
		_outbox.clear_queue()
		return true
	_outbox.transport_callback = func(_envelope: GFRequestEnvelope) -> Dictionary:
		transport_calls[0] += 1
		return { "ok": true }
	var _enqueued: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/filter-clear"
	)

	var report: Dictionary = await _outbox.replay()

	assert_eq(transport_calls[0], 0, "replay_filter 清理队列后不得继续发送。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "filter 重入失效应失败关闭。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "replay_invalidated", "报告应说明 replay 已失效。")


func test_exhausted_failure_signal_cannot_remove_next_request_with_stale_index() -> void:
	_outbox.transport_callback = func(_envelope: GFRequestEnvelope) -> Dictionary:
		return { "ok": false, "error": "denied" }
	var first: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/first"
	)
	first.max_attempts = 1
	var second: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/second"
	)
	var _failed_connected: Error = _outbox.request_failed.connect(
		func(envelope: GFRequestEnvelope, _result: Dictionary) -> void:
			var _removed: bool = _outbox.remove_request(envelope.request_id)
	) as Error

	var report: Dictionary = await _outbox.replay(1)
	var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()

	assert_eq(GFVariantData.get_option_int(report, "failed"), 1, "第一条失败应计入报告。")
	assert_eq(_outbox.get_failed_request_count(), 1, "耗尽请求应进入失败列表。")
	assert_eq(pending_requests.size(), 1, "失败信号重入不得误删后续请求。")
	assert_eq(pending_requests[0].request_id, second.request_id, "等待队列应保留第二条请求。")


func test_removed_async_failure_does_not_resurrect_in_failed_store() -> void:
	var transport: ManualTransport = ManualTransport.new()
	_outbox.transport_callback = Callable(transport, "send")
	var source: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/removed-failure"
	)
	source.max_attempts = 1
	var replay_state: ReplayState = ReplayState.new()
	@warning_ignore("missing_await")
	_await_outbox_replay(replay_state, 1)
	await get_tree().process_frame

	assert_true(_outbox.remove_request(source.request_id), "异步等待期间应能显式移除请求。")
	transport.emit_failure()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(replay_state.done, "迟到失败后 replay 应结束。")
	assert_eq(_outbox.get_queue_size(), 0, "显式移除的请求不得回到 pending。")
	assert_eq(_outbox.get_failed_request_count(), 0, "显式移除的请求不得被迟到失败复活。")


func test_queue_persistence_round_trips_typed_body_values() -> void:
	var envelope: GFRequestEnvelope = _outbox.enqueue_request(HTTPClient.METHOD_PUT, "https://example.test/state", {
		"position": Vector2(3.0, 4.0),
		"typed_keys": {
			42: "integer",
			Vector2i(2, 3): "vector",
			&"named": "string-name",
		},
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
	var typed_keys: Dictionary = GFVariantData.get_option_dictionary(requests[0].body, "typed_keys")
	assert_true(typed_keys.has(42), "整数 Dictionary 键跨持久化后应保持类型。")
	assert_true(typed_keys.has(Vector2i(2, 3)), "Godot 值类型 Dictionary 键跨持久化后应保持类型。")
	assert_true(typed_keys.has(&"named"), "StringName Dictionary 键跨持久化后应保持类型。")
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


func test_queue_load_rejects_storage_over_byte_limit_and_preserves_live_state() -> void:
	var live_request: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/live-byte-limit"
	)
	_outbox.max_storage_bytes = 32
	var file: FileAccess = FileAccess.open(_storage_path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入超限 outbox 文件。")
	if file != null:
		var _store_result: Variant = file.store_string("{\"padding\":\"%s\"}" % "x".repeat(128))
		file.close()

	var load_error: Error = _outbox.load_queue()
	var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()

	assert_eq(load_error, ERR_PARSE_ERROR, "超出字节上限的持久化文件应被拒绝。")
	assert_eq(pending_requests.size(), 1, "字节上限失败不得清空当前内存队列。")
	assert_eq(pending_requests[0].request_id, live_request.request_id, "字节上限失败后应保留当前请求。")


func test_queue_load_rejects_persistence_structure_limits_and_preserves_live_state() -> void:
	var live_request: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/live-structure-limit"
	)
	var oversized_request: GFRequestEnvelope = _make_persisted_envelope(
		&"oversized-structure",
		"https://example.test/oversized-structure"
	)
	oversized_request.body = {
		"value": "x".repeat(65_537),
	}
	_write_storage_document([oversized_request], [])

	var load_error: Error = _outbox.load_queue()
	var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()

	assert_eq(load_error, ERR_PARSE_ERROR, "超过固定结构预算的恢复候选应被拒绝。")
	assert_eq(pending_requests.size(), 1, "结构预算失败不得清空当前内存队列。")
	assert_eq(
		pending_requests[0].request_id,
		live_request.request_id,
		"结构预算失败后应保留当前请求身份。"
	)


func test_queue_load_rejects_noncanonical_outer_and_envelope_fields() -> void:
	var live_request: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/live-exact-schema"
	)
	var encoded_request: Dictionary = GFVariantJsonCodec.variant_to_json_compatible(
		_make_persisted_envelope(
			&"exact-schema",
			"https://example.test/exact-schema"
		).to_dict(true)
	)
	var missing_method: Dictionary = encoded_request.duplicate(true)
	var method_erased: bool = missing_method.erase("method")
	assert_true(method_erased, "测试夹具应成功移除 method 字段。")
	var string_method: Dictionary = encoded_request.duplicate(true)
	string_method["method"] = "2"
	var fractional_method: Dictionary = encoded_request.duplicate(true)
	fractional_method["method"] = 2.5
	var mismatched_method_name: Dictionary = encoded_request.duplicate(true)
	mismatched_method_name["method_name"] = "GET"
	var invalid_body: Dictionary = encoded_request.duplicate(true)
	invalid_body["body"] = []
	var invalid_headers: Dictionary = encoded_request.duplicate(true)
	invalid_headers["headers"] = [42]
	var invalid_metadata: Dictionary = encoded_request.duplicate(true)
	invalid_metadata["metadata"] = []
	var extra_envelope_field: Dictionary = encoded_request.duplicate(true)
	extra_envelope_field["ignored"] = true
	var invalid_created_at: Dictionary = encoded_request.duplicate(true)
	invalid_created_at["created_at_unix"] = 0
	var invalid_documents: Array[Dictionary] = [
		{
			"version": 2,
			"pending": [encoded_request],
			"failed": [],
			"ignored": true,
		},
		{ "version": "2", "pending": [encoded_request], "failed": [] },
		{ "version": 2, "pending": [missing_method], "failed": [] },
		{ "version": 2, "pending": [string_method], "failed": [] },
		{ "version": 2, "pending": [fractional_method], "failed": [] },
		{ "version": 2, "pending": [mismatched_method_name], "failed": [] },
		{ "version": 2, "pending": [invalid_body], "failed": [] },
		{ "version": 2, "pending": [invalid_headers], "failed": [] },
		{ "version": 2, "pending": [invalid_metadata], "failed": [] },
		{ "version": 2, "pending": [extra_envelope_field], "failed": [] },
		{ "version": 2, "pending": [invalid_created_at], "failed": [] },
	]

	for index: int in range(invalid_documents.size()):
		_write_raw_storage_value(invalid_documents[index])
		var load_error: Error = _outbox.load_queue()
		var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()
		assert_eq(load_error, ERR_PARSE_ERROR, "损坏的精确存储 Schema 必须 fail closed：%d。" % index)
		assert_eq(pending_requests.size(), 1, "Schema 失败不得替换当前内存队列：%d。" % index)
		assert_eq(
			pending_requests[0].request_id,
			live_request.request_id,
			"Schema 失败后必须保留当前请求身份：%d。" % index
		)


func test_queue_load_rejects_oversized_raw_codec_marker_before_decode() -> void:
	var live_request: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/live-codec-marker-limit"
	)
	var encoded_request: Dictionary = GFVariantJsonCodec.variant_to_json_compatible(
		_make_persisted_envelope(
			&"oversized-codec-marker",
			"https://example.test/oversized-codec-marker"
		).to_dict(true)
	)
	var oversized_marker_value: Array = []
	var marker_resize_error: Error = oversized_marker_value.resize(65_537) as Error
	assert_eq(marker_resize_error, OK, "测试夹具应成功构造超限 codec marker。")
	oversized_marker_value.fill(0)
	encoded_request["body"] = {
		GFVariantJsonCodec.JSON_MARKER_KEY: {
			GFVariantJsonCodec.JSON_VERSION_KEY: GFVariantJsonCodec.JSON_SCHEMA_VERSION,
			GFVariantJsonCodec.JSON_CODEC_KEY: GFVariantJsonCodec.JSON_CODEC_ID,
			GFVariantJsonCodec.JSON_TYPE_KEY: "Vector2",
			GFVariantJsonCodec.JSON_VALUE_KEY: oversized_marker_value,
		},
	}
	_write_raw_storage_value({
		"version": 2,
		"pending": [encoded_request],
		"failed": [],
	})

	var load_error: Error = _outbox.load_queue()
	var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()

	assert_eq(load_error, ERR_PARSE_ERROR, "解码前超过集合硬上限的 typed marker 应被拒绝。")
	assert_eq(pending_requests.size(), 1, "typed marker 预算失败不得清空当前内存队列。")
	assert_eq(
		pending_requests[0].request_id,
		live_request.request_id,
		"typed marker 预算失败后应保留当前请求身份。"
	)


func test_queue_load_rejects_malformed_typed_marker_without_normalizing_it() -> void:
	var live_request: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/live-malformed-marker"
	)
	var encoded_request: Dictionary = GFVariantJsonCodec.variant_to_json_compatible(
		_make_persisted_envelope(
			&"malformed-marker",
			"https://example.test/malformed-marker"
		).to_dict(true)
	)
	encoded_request["body"] = {
		"position": {
			GFVariantJsonCodec.JSON_MARKER_KEY: {
				GFVariantJsonCodec.JSON_VERSION_KEY: GFVariantJsonCodec.JSON_SCHEMA_VERSION,
				GFVariantJsonCodec.JSON_CODEC_KEY: GFVariantJsonCodec.JSON_CODEC_ID,
				GFVariantJsonCodec.JSON_TYPE_KEY: "Vector2",
				GFVariantJsonCodec.JSON_VALUE_KEY: [1.0],
			},
		},
	}
	_write_raw_storage_value({
		"version": 2,
		"pending": [encoded_request],
		"failed": [],
	})

	var load_error: Error = _outbox.load_queue()
	var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()

	assert_eq(load_error, ERR_PARSE_ERROR, "缺失分量的 typed marker 不得被补零后接受。")
	assert_eq(pending_requests.size(), 1, "损坏 marker 不得替换当前内存队列。")
	assert_eq(
		pending_requests[0].request_id,
		live_request.request_id,
		"损坏 marker 失败后应保留当前请求身份。"
	)


func test_queue_load_rejects_non_utf8_json_without_replacement_decoding() -> void:
	var live_request: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/live-invalid-utf8"
	)
	var raw_bytes: PackedByteArray = (
		"{\"version\":2,\"pending\":[],\"failed\":[],\"ignored\":\""
	).to_utf8_buffer()
	var _invalid_byte_appended: bool = raw_bytes.append(0xff)
	raw_bytes.append_array("\"}".to_utf8_buffer())
	_write_raw_storage_bytes(raw_bytes)

	var load_error: Error = _outbox.load_queue()
	var pending_requests: Array[GFRequestEnvelope] = _outbox.get_pending_requests()

	assert_eq(load_error, ERR_PARSE_ERROR, "非法 UTF-8 不得通过替换字符规范化为有效事务。")
	assert_eq(pending_requests.size(), 1, "UTF-8 解码失败不得清空当前内存队列。")
	assert_eq(
		pending_requests[0].request_id,
		live_request.request_id,
		"UTF-8 解码失败后应保留当前请求身份。"
	)


func test_queue_load_rejects_excessive_pending_count_and_duplicate_request_ids() -> void:
	var live_request: GFRequestEnvelope = _outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		"https://example.test/live-count-limit"
	)
	var first: GFRequestEnvelope = _make_persisted_envelope(
		&"duplicate-id",
		"https://example.test/first"
	)
	var second: GFRequestEnvelope = _make_persisted_envelope(
		&"second-id",
		"https://example.test/second"
	)
	_outbox.max_queue_size = 1
	_write_storage_document([first, second], [])

	var count_error: Error = _outbox.load_queue()
	assert_eq(count_error, ERR_PARSE_ERROR, "超过 pending 数量上限的事务应被拒绝。")
	assert_eq(_outbox.get_pending_requests()[0].request_id, live_request.request_id, "数量失败不得替换当前状态。")

	_outbox.max_queue_size = 8
	var duplicated_failed: GFRequestEnvelope = _make_persisted_envelope(
		&"duplicate-id",
		"https://example.test/failed"
	)
	_write_storage_document([first], [duplicated_failed])

	var duplicate_error: Error = _outbox.load_queue()
	assert_eq(duplicate_error, ERR_PARSE_ERROR, "pending 与 failed 中重复的 request_id 应被拒绝。")
	assert_eq(_outbox.get_pending_requests()[0].request_id, live_request.request_id, "重复身份失败不得替换当前状态。")


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


func _assert_persisted_queue_is_empty() -> void:
	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	assert_eq(loaded.load_queue(), OK, "失效补偿事务应保持可读取。")
	assert_eq(loaded.get_queue_size(), 0, "失效补偿事务不得在重启后恢复已撤销请求。")
	loaded.dispose()


func _make_persisted_envelope(request_id: StringName, request_url: String) -> GFRequestEnvelope:
	var envelope: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		request_url
	)
	envelope.request_id = request_id
	envelope.idempotency_key = String(request_id)
	return envelope


func _write_storage_document(
	pending_requests: Array[GFRequestEnvelope],
	failed: Array[GFRequestEnvelope]
) -> void:
	var pending_data: Array[Dictionary] = []
	for envelope: GFRequestEnvelope in pending_requests:
		pending_data.append(envelope.to_dict(true))
	var failed_data: Array[Dictionary] = []
	for envelope: GFRequestEnvelope in failed:
		failed_data.append(envelope.to_dict(true))
	var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible({
		"version": 2,
		"pending": pending_data,
		"failed": failed_data,
	})
	var file: FileAccess = FileAccess.open(_storage_path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入 outbox 存储夹具。")
	if file != null:
		var _store_result: Variant = file.store_string(JSON.stringify(encoded))
		file.close()


func _write_raw_storage_value(value: Variant) -> void:
	var file: FileAccess = FileAccess.open(_storage_path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入原始 outbox 存储夹具。")
	if file != null:
		var _store_result: Variant = file.store_string(JSON.stringify(value))
		file.close()


func _write_raw_storage_bytes(value: PackedByteArray) -> void:
	var file: FileAccess = FileAccess.open(_storage_path, FileAccess.WRITE)
	assert_not_null(file, "测试应能写入原始 outbox 字节夹具。")
	if file != null:
		var _store_buffer_result: Variant = file.store_buffer(value)
		file.close()


func _variant_to_request_envelope(value: Variant) -> GFRequestEnvelope:
	if value is GFRequestEnvelope:
		var envelope: GFRequestEnvelope = value
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

	func emit_failure() -> void:
		finished.emit({ "ok": false, "error": "offline" })


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
