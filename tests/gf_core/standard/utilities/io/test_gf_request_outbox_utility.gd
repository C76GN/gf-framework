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
	if FileAccess.file_exists(_storage_path):
		var remove_error: Error = DirAccess.remove_absolute(_storage_path)
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
	assert_eq(envelope.retry_after_msec, 0, "0ms 重试延迟应允许立即重试。")
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
	var save_error: Error = _outbox.save_queue()

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = _storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	var load_error: Error = loaded.load_queue()
	var requests: Array[GFRequestEnvelope] = loaded.get_pending_requests()

	assert_eq(save_error, OK, "保存队列应成功。")
	assert_eq(load_error, OK, "读取队列应成功。")
	assert_eq(requests.size(), 1, "读取后应恢复一个请求。")
	assert_eq(GFVariantData.get_option_vector2(requests[0].body, "position"), Vector2(3.0, 4.0), "请求 body 中的 Godot 类型应经 JSON 持久化恢复。")
	assert_eq(GFVariantData.get_option_packed_string_array(requests[0].metadata, "tags"), PackedStringArray(["state"]), "请求 metadata 中的 PackedStringArray 应恢复。")
	loaded.dispose()


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


class ReplayState:
	extends RefCounted

	var done: bool = false
	var report: Dictionary = {}


class AttemptState:
	extends RefCounted

	var count: int = 0
