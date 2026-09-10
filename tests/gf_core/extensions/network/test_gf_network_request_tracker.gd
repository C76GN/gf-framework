# 测试显式网络请求关联的终态、预算、会话隔离和项目适配接线。
extends GutTest


# --- 测试用例 ---

func test_requests_correlate_out_of_order_without_consuming_wrong_peer_or_unknown_id() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var first: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var second: GFNetworkRequestHandle = tracker.request(3, sender.send)

	assert_eq(first.get_peer_id(), 2)
	assert_eq(second.get_peer_id(), 3)
	assert_ne(first.get_request_id(), second.get_request_id())
	assert_eq(tracker.get_pending_count(), 2)
	assert_false(tracker.receive_reply(3, first.get_request_id(), "wrong peer"))
	assert_false(tracker.receive_reply(2, "unknown-request", "unknown"))
	assert_true(first.is_pending())
	assert_true(tracker.receive_reply(3, second.get_request_id(), "second"))
	_assert_status(second, &"received")
	assert_true(first.is_pending())
	assert_true(tracker.receive_reply(2, first.get_request_id(), "first"))
	_assert_status(first, &"received")
	assert_eq(tracker.get_pending_count(), 0)
	tracker.dispose()


func test_request_is_registered_before_synchronous_reply_and_sent_only_once() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	var counts_during_send: Array[int] = []
	var accepted_during_send: Array[bool] = []
	assert_eq(tracker.begin_session(), OK)
	sender.on_send = func(request_id: String) -> void:
		counts_during_send.append(tracker.get_pending_count())
		accepted_during_send.append(tracker.receive_reply(4, request_id, 7))

	var handle: GFNetworkRequestHandle = tracker.request(4, sender.send)

	assert_eq(sender.request_ids.size(), 1)
	assert_eq(counts_during_send, [1])
	assert_eq(accepted_during_send, [true])
	_assert_status(handle, &"received")
	assert_true(handle.is_successful())
	assert_eq(_response_int(handle), 7)
	assert_eq(tracker.get_pending_count(), 0)
	sender.on_send = Callable()
	tracker.dispose()


func test_synchronous_reply_wins_later_send_error() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	sender.send_error = ERR_CANT_CONNECT
	assert_eq(tracker.begin_session(), OK)
	sender.on_send = func(request_id: String) -> void:
		var _accepted: bool = tracker.receive_reply(4, request_id, "accepted")

	var handle: GFNetworkRequestHandle = tracker.request(4, sender.send)

	_assert_status(handle, &"received")
	assert_true(handle.is_successful())
	assert_eq(handle.get_result().get_send_error(), OK)
	assert_eq(tracker.get_pending_count(), 0)
	sender.on_send = Callable()
	tracker.dispose()


func test_send_failure_releases_capacity_and_late_reply_cannot_complete_it() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(null, 1)
	var sender: SendProbe = SendProbe.new()
	sender.send_error = ERR_CANT_CONNECT
	assert_eq(tracker.begin_session(), OK)
	var failed: GFNetworkRequestHandle = tracker.request(4, sender.send)

	_assert_status(failed, &"send_failed")
	assert_eq(failed.get_result().get_send_error(), ERR_CANT_CONNECT)
	assert_false(failed.is_successful())
	assert_eq(tracker.get_pending_count(), 0)
	assert_false(tracker.receive_reply(4, failed.get_request_id(), "late"))
	sender.send_error = OK
	var next: GFNetworkRequestHandle = tracker.request(4, sender.send)
	assert_true(next.is_pending())
	assert_eq(tracker.get_pending_count(), 1)
	tracker.dispose()


func test_completed_signal_and_cancellation_have_one_terminal_owner() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	var completion: CompletionProbe = CompletionProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var connection_error: int = handle.completed.connect(completion.record)
	assert_eq(connection_error, OK)

	assert_true(handle.cancel())
	assert_false(handle.cancel())
	assert_false(tracker.receive_reply(2, handle.get_request_id(), "late"))
	tracker.tick()
	tracker.end_session()

	_assert_status(handle, &"cancelled")
	assert_eq(completion.results.size(), 1)
	assert_eq(tracker.get_pending_count(), 0)
	tracker.dispose()


func test_duplicate_reply_cannot_overwrite_success_or_emit_again() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	var completion: CompletionProbe = CompletionProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var _connection_error: int = handle.completed.connect(completion.record)

	assert_true(tracker.receive_reply(2, handle.get_request_id(), 10))
	assert_false(tracker.receive_reply(2, handle.get_request_id(), 20))
	assert_false(handle.cancel())
	assert_eq(_response_int(handle), 10)
	assert_eq(completion.results.size(), 1)
	tracker.dispose()


func test_reply_at_exact_deadline_times_out_without_waiting_for_tick() -> void:
	var clock: GFManualClock = GFManualClock.new()
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(clock)
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var early: GFNetworkRequestHandle = tracker.request(2, sender.send, 10)
	var due: GFNetworkRequestHandle = tracker.request(2, sender.send, 10)

	assert_true(clock.advance_msec(9))
	assert_true(tracker.receive_reply(2, early.get_request_id(), null))
	assert_true(clock.advance_msec(1))
	assert_false(tracker.receive_reply(2, due.get_request_id(), "too late"))
	_assert_status(early, &"received")
	_assert_status(due, &"timed_out")
	assert_eq(tracker.get_pending_count(), 0)
	tracker.dispose()


func test_invalid_response_validation_crossing_deadline_finishes_as_timed_out() -> void:
	var clock: ObservedMonotonicClock = ObservedMonotonicClock.new()
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(clock)
	var sender: SendProbe = SendProbe.new()
	var completion: CompletionProbe = CompletionProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var handle: GFNetworkRequestHandle = tracker.request(2, sender.send, 10)
	assert_true(handle.is_pending())
	var _connection_error: int = handle.completed.connect(completion.record)
	# 请求登记和发送返回也会读时钟，完成后才安排回复校验前后的观测。
	clock.queue_observations([9, 10])

	assert_false(tracker.receive_reply(2, handle.get_request_id(), { "object": RefCounted.new() }))

	_assert_status(handle, &"timed_out")
	assert_false(handle.is_successful())
	assert_eq(completion.results.size(), 1)
	assert_eq(tracker.get_pending_count(), 0)
	assert_false(tracker.receive_reply(2, handle.get_request_id(), "late"))
	assert_eq(completion.results.size(), 1)
	tracker.dispose()


func test_valid_response_validation_crossing_deadline_finishes_as_timed_out() -> void:
	var clock: ObservedMonotonicClock = ObservedMonotonicClock.new()
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(clock)
	var sender: SendProbe = SendProbe.new()
	var completion: CompletionProbe = CompletionProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var handle: GFNetworkRequestHandle = tracker.request(2, sender.send, 10)
	assert_true(handle.is_pending())
	var _connection_error: int = handle.completed.connect(completion.record)
	clock.queue_observations([9, 10])

	assert_false(tracker.receive_reply(2, handle.get_request_id(), { "answer": 7 }))

	_assert_status(handle, &"timed_out")
	assert_false(handle.is_successful())
	assert_eq(completion.results.size(), 1)
	assert_eq(tracker.get_pending_count(), 0)
	assert_false(handle.cancel())
	assert_eq(completion.results.size(), 1)
	tracker.dispose()


func test_response_snapshot_crossing_deadline_finishes_once_without_retaining_response() -> void:
	var clock: ObservedMonotonicClock = ObservedMonotonicClock.new()
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(clock)
	var sender: SendProbe = SendProbe.new()
	var completion: CompletionProbe = CompletionProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var handle: GFNetworkRequestHandle = tracker.request(2, sender.send, 10)
	var _connection_error: int = handle.completed.connect(completion.record)
	var response: Array[Dictionary] = []
	for index: int in range(1000):
		response.append({ "value": index })
	# 校验前后仍未到期，但准备隔离副本后已恰好到达截止时刻。
	clock.queue_observations([9, 9, 10])

	assert_false(tracker.receive_reply(2, handle.get_request_id(), response))

	_assert_status(handle, &"timed_out")
	var response_value: Variant = handle.get_result().get_response()
	assert_true(response_value == null)
	assert_false(handle.is_successful())
	assert_eq(completion.results.size(), 1)
	assert_same(completion.results[0], handle.get_result())
	assert_eq(tracker.get_pending_count(), 0)
	assert_false(handle.cancel())
	assert_false(tracker.receive_reply(2, handle.get_request_id(), response))
	tracker.tick()
	tracker.end_session()
	tracker.dispose()
	assert_eq(completion.results.size(), 1)


func test_response_snapshot_before_deadline_commits_an_isolated_success() -> void:
	var clock: ObservedMonotonicClock = ObservedMonotonicClock.new()
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(clock)
	var sender: SendProbe = SendProbe.new()
	var completion: CompletionProbe = CompletionProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var handle: GFNetworkRequestHandle = tracker.request(2, sender.send, 10)
	var _connection_error: int = handle.completed.connect(completion.record)
	var response: Array[Dictionary] = []
	for index: int in range(1000):
		response.append({ "value": index })
	clock.queue_observations([8, 8, 9])

	assert_true(tracker.receive_reply(2, handle.get_request_id(), response))

	_assert_status(handle, &"received")
	assert_eq(_response_array(handle), response)
	response[0]["value"] = -1
	var retained: Array = _response_array(handle)
	var first_value: Variant = retained[0]
	assert_true(first_value is Dictionary)
	if first_value is Dictionary:
		var first_row: Dictionary = first_value
		assert_eq(first_row, { "value": 0 })
	assert_eq(completion.results.size(), 1)
	assert_eq(tracker.get_pending_count(), 0)
	clock.queue_observations([10])
	tracker.tick()
	_assert_status(handle, &"received")
	tracker.dispose()
	assert_eq(completion.results.size(), 1)


func test_tick_uses_monotonic_clock_and_ignores_wall_clock_jumps() -> void:
	var clock: GFManualClock = GFManualClock.new(0, 1000)
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(clock)
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var handle: GFNetworkRequestHandle = tracker.request(2, sender.send, 20)

	assert_true(clock.set_unix_time_msec(900000000))
	tracker.tick()
	assert_true(handle.is_pending())
	assert_true(clock.set_unix_time_msec(0))
	assert_true(clock.advance_msec(19))
	tracker.tick()
	assert_true(handle.is_pending())
	assert_true(clock.advance_msec(1))
	tracker.tick()
	_assert_status(handle, &"timed_out")
	assert_false(handle.cancel())
	assert_false(tracker.receive_reply(2, handle.get_request_id(), null))
	tracker.dispose()


func test_invalid_capacity_rejects_session_and_never_calls_sender() -> void:
	var sender: SendProbe = SendProbe.new()
	for capacity: int in [-1, 0, 4097]:
		var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(null, capacity)
		assert_ne(tracker.begin_session(), OK)
		var rejected: GFNetworkRequestHandle = tracker.request(2, sender.send)
		_assert_status(rejected, &"rejected")
		assert_eq(tracker.get_pending_count(), 0)
		tracker.dispose()
	assert_true(sender.request_ids.is_empty())
	var largest: GFNetworkRequestTracker = GFNetworkRequestTracker.new(null, 4096)
	assert_eq(largest.begin_session(), OK)
	largest.dispose()


func test_invalid_requests_and_full_capacity_are_rejected_before_send() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(null, 1)
	var sender: SendProbe = SendProbe.new()
	var inactive: GFNetworkRequestHandle = tracker.request(2, sender.send)
	_assert_rejected(inactive, ERR_UNCONFIGURED)
	assert_eq(tracker.begin_session(), OK)
	for peer_id: int in [-1, 0]:
		_assert_rejected(tracker.request(peer_id, sender.send), ERR_INVALID_PARAMETER)
	for timeout_msec: int in [-1, 0, 86400001]:
		_assert_rejected(tracker.request(2, sender.send, timeout_msec), ERR_INVALID_PARAMETER)
	_assert_rejected(tracker.request(2, Callable()), ERR_INVALID_PARAMETER)
	assert_true(sender.request_ids.is_empty())
	var pending_handle: GFNetworkRequestHandle = tracker.request(2, sender.send, 86400000)
	assert_true(pending_handle.is_pending())
	_assert_rejected(tracker.request(3, sender.send), ERR_BUSY)
	assert_eq(sender.request_ids.size(), 1)
	assert_true(pending_handle.cancel())
	assert_true(tracker.request(3, sender.send, 1).is_pending())
	tracker.dispose()


func test_synchronous_send_reentry_cannot_exceed_capacity() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(null, 1)
	var sender: SendProbe = SendProbe.new()
	var nested_sender: SendProbe = SendProbe.new()
	var nested_handles: Array[GFNetworkRequestHandle] = []
	assert_eq(tracker.begin_session(), OK)
	sender.on_send = func(_request_id: String) -> void:
		nested_handles.append(tracker.request(3, nested_sender.send))

	var original: GFNetworkRequestHandle = tracker.request(2, sender.send)

	assert_eq(nested_handles.size(), 1)
	if not nested_handles.is_empty():
		_assert_rejected(nested_handles[0], ERR_BUSY)
	assert_true(original.is_pending())
	assert_true(nested_sender.request_ids.is_empty())
	assert_eq(tracker.get_pending_count(), 1)
	sender.on_send = Callable()
	tracker.dispose()


func test_session_reopen_closes_old_requests_and_never_reuses_ids() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var another_tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var first: GFNetworkRequestHandle = tracker.request(2, sender.send)
	assert_true(first.cancel())
	var second: GFNetworkRequestHandle = tracker.request(2, sender.send)
	assert_eq(tracker.begin_session(), OK)
	_assert_status(second, &"session_closed")
	var current: GFNetworkRequestHandle = tracker.request(2, sender.send)
	assert_eq(another_tracker.begin_session(), OK)
	var independent: GFNetworkRequestHandle = another_tracker.request(2, sender.send)
	var unique_ids: Dictionary[String, bool] = {}
	for handle: GFNetworkRequestHandle in [first, second, current, independent]:
		assert_false(handle.get_request_id().is_empty())
		unique_ids[handle.get_request_id()] = true
	assert_eq(unique_ids.size(), 4)
	assert_false(tracker.receive_reply(2, first.get_request_id(), null))
	assert_false(tracker.receive_reply(2, second.get_request_id(), null))
	assert_false(tracker.receive_reply(2, independent.get_request_id(), null))
	assert_true(current.is_pending())
	assert_true(tracker.receive_reply(2, current.get_request_id(), null))
	tracker.dispose()
	another_tracker.dispose()


func test_peer_disconnect_only_finishes_that_peers_pending_requests() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var first: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var second: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var other: GFNetworkRequestHandle = tracker.request(3, sender.send)
	var observed_counts: Array[int] = []
	var observed_second_completed: Array[bool] = []
	var _connection_error: int = first.completed.connect(
		func(_result: GFNetworkRequestResult) -> void:
			observed_counts.append(tracker.get_pending_count())
			observed_second_completed.append(second.is_completed())
	)

	tracker.disconnect_peer(2)

	_assert_status(first, &"peer_disconnected")
	_assert_status(second, &"peer_disconnected")
	assert_eq(observed_counts, [1])
	assert_eq(observed_second_completed, [true])
	assert_true(other.is_pending())
	assert_false(tracker.receive_reply(2, first.get_request_id(), null))
	assert_true(tracker.receive_reply(3, other.get_request_id(), null))
	tracker.dispose()


func test_end_session_commits_batch_before_callbacks_and_blocks_close_reentry() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	var nested_sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var first: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var second: GFNetworkRequestHandle = tracker.request(3, sender.send)
	var observed_counts: Array[int] = []
	var observed_second_completed: Array[bool] = []
	var nested_begin_errors: Array[int] = []
	var nested_handles: Array[GFNetworkRequestHandle] = []
	var _connection_error: int = first.completed.connect(
		func(_result: GFNetworkRequestResult) -> void:
			observed_counts.append(tracker.get_pending_count())
			observed_second_completed.append(second.is_completed())
			nested_begin_errors.append(tracker.begin_session())
			nested_handles.append(tracker.request(2, nested_sender.send))
	)

	tracker.end_session()

	_assert_status(first, &"session_closed")
	_assert_status(second, &"session_closed")
	assert_eq(observed_counts, [0])
	assert_eq(observed_second_completed, [true])
	assert_eq(nested_begin_errors, [ERR_BUSY])
	assert_eq(nested_handles.size(), 1)
	if not nested_handles.is_empty():
		_assert_rejected(nested_handles[0], ERR_BUSY)
	assert_true(nested_sender.request_ids.is_empty())
	assert_eq(tracker.begin_session(), OK)
	assert_true(tracker.request(2, sender.send).is_pending())
	tracker.dispose()


func test_dispose_during_session_reopen_callback_is_irreversible() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var first: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var second: GFNetworkRequestHandle = tracker.request(3, sender.send)
	var _connection_error: int = first.completed.connect(
		func(_result: GFNetworkRequestResult) -> void:
			tracker.dispose()
	)

	assert_ne(tracker.begin_session(), OK)

	_assert_status(first, &"session_closed")
	_assert_status(second, &"session_closed")
	assert_ne(tracker.begin_session(), OK)
	_assert_status(tracker.request(2, sender.send), &"disposed")
	assert_eq(sender.request_ids.size(), 2)
	assert_eq(tracker.get_pending_count(), 0)
	tracker.end_session()
	tracker.dispose()


func test_end_session_during_session_reopen_callback_keeps_tracker_inactive() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	var first_completion: CompletionProbe = CompletionProbe.new()
	var second_completion: CompletionProbe = CompletionProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var first: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var second: GFNetworkRequestHandle = tracker.request(3, sender.send)
	var _first_connection: int = first.completed.connect(first_completion.record)
	var _second_connection: int = second.completed.connect(second_completion.record)
	var _close_connection: int = first.completed.connect(
		func(_result: GFNetworkRequestResult) -> void:
			tracker.end_session()
	)

	assert_eq(tracker.begin_session(), ERR_UNAVAILABLE)

	_assert_status(first, &"session_closed")
	_assert_status(second, &"session_closed")
	assert_eq(first_completion.results.size(), 1)
	assert_eq(second_completion.results.size(), 1)
	_assert_rejected(tracker.request(2, sender.send), ERR_UNCONFIGURED)
	assert_eq(sender.request_ids.size(), 2, "回调关闭会话后，外层不能恢复发送准入。")
	assert_eq(tracker.get_pending_count(), 0)
	# end_session 不等于 dispose；之后显式开始另一个会话仍应成功。
	assert_eq(tracker.begin_session(), OK)
	assert_true(tracker.request(2, sender.send).is_pending())
	assert_eq(sender.request_ids.size(), 3)
	tracker.dispose()


func test_tick_commits_all_expired_requests_before_first_notification() -> void:
	var clock: GFManualClock = GFManualClock.new()
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(clock)
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var first: GFNetworkRequestHandle = tracker.request(2, sender.send, 10)
	var second: GFNetworkRequestHandle = tracker.request(3, sender.send, 10)
	var later: GFNetworkRequestHandle = tracker.request(4, sender.send, 20)
	var observed_counts: Array[int] = []
	var observed_second_completed: Array[bool] = []
	var _connection_error: int = first.completed.connect(
		func(_result: GFNetworkRequestResult) -> void:
			observed_counts.append(tracker.get_pending_count())
			observed_second_completed.append(second.is_completed())
	)

	assert_true(clock.advance_msec(10))
	tracker.tick()

	_assert_status(first, &"timed_out")
	_assert_status(second, &"timed_out")
	assert_eq(observed_counts, [1])
	assert_eq(observed_second_completed, [true])
	assert_true(later.is_pending())
	tracker.dispose()


func test_completion_callback_can_use_released_capacity_without_outer_cleanup_erasing_it() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new(null, 1)
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var first: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var replacements: Array[GFNetworkRequestHandle] = []
	var _connection_error: int = first.completed.connect(
		func(_result: GFNetworkRequestResult) -> void:
			replacements.append(tracker.request(3, sender.send))
	)

	assert_true(tracker.receive_reply(2, first.get_request_id(), null))

	assert_eq(replacements.size(), 1)
	if not replacements.is_empty():
		assert_true(replacements[0].is_pending())
		assert_true(tracker.receive_reply(3, replacements[0].get_request_id(), null))
	assert_eq(sender.request_ids.size(), 2)
	assert_eq(tracker.get_pending_count(), 0)
	tracker.dispose()


func test_session_ended_inside_send_cannot_be_resurrected_by_send_return() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	sender.on_send = func(_request_id: String) -> void:
		tracker.end_session()

	var handle: GFNetworkRequestHandle = tracker.request(2, sender.send)

	_assert_status(handle, &"session_closed")
	assert_eq(tracker.get_pending_count(), 0)
	assert_false(tracker.receive_reply(2, handle.get_request_id(), null))
	_assert_rejected(tracker.request(2, sender.send), ERR_UNCONFIGURED)
	sender.on_send = Callable()
	tracker.dispose()


func test_send_callable_is_not_retained_while_request_is_pending() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	assert_eq(tracker.begin_session(), OK)
	var sender_ref: WeakRef = _request_with_temporary_sender(tracker)

	assert_true(_weak_ref_is_empty(sender_ref))
	assert_eq(tracker.get_pending_count(), 1)
	tracker.dispose()


func test_response_is_copied_on_acceptance_and_each_read() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var source_items: Array[int] = [1, 2]
	var response: Dictionary = { "items": source_items }
	assert_true(tracker.receive_reply(2, handle.get_request_id(), response))
	source_items[0] = 99
	response["extra"] = "changed"
	var first_copy: Dictionary = _response_dictionary(handle)
	assert_false(first_copy.has("extra"))
	var first_items: Array = _array_field(first_copy, "items")
	assert_eq(_int_at(first_items, 0), 1)
	first_items[0] = 88
	first_copy["copy_only"] = true
	var second_copy: Dictionary = _response_dictionary(handle)
	assert_false(second_copy.has("copy_only"))
	assert_eq(_int_at(_array_field(second_copy, "items"), 0), 1)
	tracker.dispose()


func test_unsafe_response_types_terminate_only_the_matched_request() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var untouched: GFNetworkRequestHandle = tracker.request(3, sender.send)
	var unsafe_values: Array[Variant] = [
		RefCounted.new(),
		Callable(),
		untouched.completed,
		RID(),
		INF,
		NAN,
		Vector2(INF, 0.0),
		Vector3(0.0, NAN, 0.0),
		Color(0.0, 0.0, 0.0, INF),
	]
	for unsafe_value: Variant in unsafe_values:
		var handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
		assert_false(tracker.receive_reply(3, handle.get_request_id(), unsafe_value))
		assert_true(handle.is_pending(), "错误 peer 不能用非法 response 终结请求。")
		assert_false(tracker.receive_reply(2, handle.get_request_id(), { "value": unsafe_value }))
		_assert_status(handle, &"invalid_response")
		assert_false(handle.is_successful())
		assert_true(untouched.is_pending())
	assert_eq(tracker.get_pending_count(), 1)
	tracker.dispose()


func test_empty_object_typed_containers_are_rejected_even_when_nested() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var object_array: Array[Resource] = []
	var object_dictionary: Dictionary[String, Resource] = {}
	var unsafe_responses: Array[Variant] = [
		object_array,
		object_dictionary,
		{ "nested": [object_array] },
		{ "nested": { "items": object_dictionary } },
	]
	for response: Variant in unsafe_responses:
		var handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
		assert_false(tracker.receive_reply(2, handle.get_request_id(), response))
		_assert_status(handle, &"invalid_response")
	assert_eq(tracker.get_pending_count(), 0)
	tracker.dispose()


func test_scalar_typed_containers_are_accepted_and_copied_at_every_boundary() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var source_items: Array[int] = [2, 4]
	var source_lookup: Dictionary[String, int] = { "value": 7 }
	var array_handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var dictionary_handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var nested_handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
	assert_true(tracker.receive_reply(2, array_handle.get_request_id(), source_items))
	assert_true(tracker.receive_reply(2, dictionary_handle.get_request_id(), source_lookup))
	assert_true(tracker.receive_reply(2, nested_handle.get_request_id(), {
		"items": source_items,
		"lookup": source_lookup,
	}))
	source_items[0] = 99
	source_lookup["value"] = 88
	var array_copy: Array = _response_array(array_handle)
	var dictionary_copy: Dictionary = _response_dictionary(dictionary_handle)
	assert_eq(_int_at(array_copy, 0), 2)
	assert_eq(_int_field(dictionary_copy, "value"), 7)
	array_copy[0] = 66
	dictionary_copy["value"] = 55
	assert_eq(_int_at(_response_array(array_handle), 0), 2)
	assert_eq(_int_field(_response_dictionary(dictionary_handle), "value"), 7)
	var nested_copy: Dictionary = _response_dictionary(nested_handle)
	assert_eq(_int_at(_array_field(nested_copy, "items"), 0), 2)
	var nested_lookup_value: Variant = nested_copy.get("lookup")
	assert_true(nested_lookup_value is Dictionary)
	if nested_lookup_value is Dictionary:
		var nested_lookup: Dictionary = nested_lookup_value
		assert_eq(_int_field(nested_lookup, "value"), 7)
		var nested_items: Array = _array_field(nested_copy, "items")
		nested_items[0] = 44
		nested_lookup["value"] = 33
	var fresh_nested: Dictionary = _response_dictionary(nested_handle)
	assert_eq(_int_at(_array_field(fresh_nested, "items"), 0), 2)
	var fresh_lookup_value: Variant = fresh_nested.get("lookup")
	assert_true(fresh_lookup_value is Dictionary)
	if fresh_lookup_value is Dictionary:
		var fresh_lookup: Dictionary = fresh_lookup_value
		assert_eq(_int_field(fresh_lookup, "value"), 7)
	assert_eq(tracker.get_pending_count(), 0)
	tracker.dispose()


func test_cycles_and_response_depth_node_and_byte_limits_fail_closed() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var cycle: Array = []
	cycle.append(cycle)
	var cycle_handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
	assert_false(tracker.receive_reply(2, cycle_handle.get_request_id(), cycle))
	_assert_status(cycle_handle, &"invalid_response")
	cycle.clear()
	var nested: Variant = 1
	for _index: int in range(18):
		nested = [nested]
	var too_many_nodes: Array = []
	var node_resize_error: int = too_many_nodes.resize(4097)
	assert_eq(node_resize_error, OK)
	var too_many_bytes: PackedByteArray = PackedByteArray()
	var byte_resize_error: int = too_many_bytes.resize(65537)
	assert_eq(byte_resize_error, OK)
	for oversized_value: Variant in [nested, too_many_nodes, too_many_bytes]:
		var handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
		assert_false(tracker.receive_reply(2, handle.get_request_id(), oversized_value))
		_assert_status(handle, &"invalid_response")
	assert_eq(tracker.get_pending_count(), 0)
	var valid: GFNetworkRequestHandle = tracker.request(2, sender.send)
	assert_true(tracker.receive_reply(2, valid.get_request_id(), { "small": [true, 7, "ok", null] }))
	tracker.dispose()


func test_node_path_response_enforces_byte_budget_and_preserves_normal_paths() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var oversized_handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var oversized_path: NodePath = NodePath("a/".repeat(40000) + "b")
	assert_false(tracker.receive_reply(2, oversized_handle.get_request_id(), oversized_path))
	_assert_status(oversized_handle, &"invalid_response")
	var normal_handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var expected_path: NodePath = NodePath("Root/Child:position:x")
	assert_true(tracker.receive_reply(2, normal_handle.get_request_id(), expected_path))
	_assert_status(normal_handle, &"received")
	var received_value: Variant = normal_handle.get_result().get_response()
	assert_true(received_value is NodePath)
	if received_value is NodePath:
		var received_path: NodePath = received_value
		assert_eq(received_path, expected_path)
	assert_eq(tracker.get_pending_count(), 0)
	tracker.dispose()


func test_debug_snapshot_contains_no_request_id_or_response_and_is_independent() -> void:
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var sender: SendProbe = SendProbe.new()
	assert_eq(tracker.begin_session(), OK)
	var handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
	var pending_snapshot: Dictionary = tracker.get_debug_snapshot()
	assert_false(JSON.stringify(pending_snapshot).contains(handle.get_request_id()))
	pending_snapshot["injected"] = "synthetic-snapshot-canary"
	assert_false(tracker.get_debug_snapshot().has("injected"))
	assert_true(tracker.receive_reply(2, handle.get_request_id(), "synthetic-response-canary"))
	var completed_text: String = JSON.stringify(tracker.get_debug_snapshot())
	assert_false(completed_text.contains(handle.get_request_id()))
	assert_false(completed_text.contains("synthetic-response-canary"))
	tracker.dispose()
	_assert_status(tracker.request(2, sender.send), &"disposed")
	assert_eq(tracker.get_pending_count(), 0)


func test_project_adapter_round_trips_sync_reply_and_preserves_ordinary_messages() -> void:
	var backend: ReplyBackend = ReplyBackend.new()
	backend.reply_during_send = true
	var adapter: ProjectAdapter = ProjectAdapter.new(backend)
	assert_eq(adapter.utility.connect_to_endpoint("mock://request-tracker"), OK)
	var completed: GFNetworkRequestHandle = adapter.request(2)
	_assert_status(completed, &"received")
	assert_eq(backend.sent_messages.size(), 1)
	assert_eq(adapter.accepted_replies, [true])
	backend.emit_event(2)
	assert_eq(adapter.ordinary_message_count, 1)
	backend.reply_during_send = false
	var pending_handle: GFNetworkRequestHandle = adapter.request(2)
	backend.emit_reply(3, pending_handle.get_request_id(), "wrong transport peer")
	assert_true(pending_handle.is_pending())
	backend.emit_reply(2, pending_handle.get_request_id(), "correct transport peer")
	_assert_status(pending_handle, &"received")
	assert_eq(adapter.accepted_replies, [true, false, true])
	adapter.dispose()


func test_project_adapter_session_signal_covers_backend_replacement_and_late_old_reply() -> void:
	var old_backend: ReplyBackend = ReplyBackend.new()
	var next_backend: ReplyBackend = ReplyBackend.new()
	var adapter: ProjectAdapter = ProjectAdapter.new(old_backend)
	assert_eq(adapter.utility.connect_to_endpoint("mock://old-session"), OK)
	var old_request: GFNetworkRequestHandle = adapter.request(2)

	adapter.utility.set_backend(next_backend)

	_assert_status(old_request, &"session_closed")
	assert_eq(adapter.tracker.get_pending_count(), 0)
	assert_eq(adapter.utility.connect_to_endpoint("mock://new-session"), OK)
	var current: GFNetworkRequestHandle = adapter.request(2)
	old_backend.emit_reply(2, old_request.get_request_id(), "old backend")
	assert_true(adapter.accepted_replies.is_empty(), "Utility 必须断开旧后端信号。")
	next_backend.emit_reply(2, old_request.get_request_id(), "old request on current backend")
	assert_true(current.is_pending())
	assert_eq(adapter.accepted_replies, [false])
	next_backend.peer_disconnected.emit(2)
	_assert_status(current, &"peer_disconnected")
	adapter.dispose()


# --- 私有/辅助方法 ---

func _assert_status(handle: GFNetworkRequestHandle, expected_status: StringName) -> void:
	assert_not_null(handle)
	if handle == null:
		return
	assert_true(handle.is_completed())
	assert_false(handle.is_pending())
	var result: GFNetworkRequestResult = handle.get_result()
	assert_not_null(result)
	if result != null:
		assert_eq(result.get_status(), expected_status)
		assert_eq(handle.is_successful(), result.is_successful())


func _assert_rejected(handle: GFNetworkRequestHandle, expected_error: Error) -> void:
	_assert_status(handle, &"rejected")
	if handle != null and handle.get_result() != null:
		assert_eq(handle.get_result().get_send_error(), expected_error)


func _response_int(handle: GFNetworkRequestHandle) -> int:
	if handle == null or handle.get_result() == null:
		fail_test("已完成请求必须提供结果。")
		return -1
	var value: Variant = handle.get_result().get_response()
	assert_true(value is int)
	if value is int:
		var typed_value: int = value
		return typed_value
	return -1


func _response_dictionary(handle: GFNetworkRequestHandle) -> Dictionary:
	if handle == null or handle.get_result() == null:
		fail_test("已完成请求必须提供结果。")
		return {}
	var value: Variant = handle.get_result().get_response()
	assert_true(value is Dictionary)
	if value is Dictionary:
		var typed_value: Dictionary = value
		return typed_value
	return {}


func _response_array(handle: GFNetworkRequestHandle) -> Array:
	if handle == null or handle.get_result() == null:
		fail_test("已完成请求必须提供结果。")
		return []
	var value: Variant = handle.get_result().get_response()
	assert_true(value is Array)
	if value is Array:
		var typed_value: Array = value
		return typed_value
	return []


func _int_field(value: Dictionary, key: String) -> int:
	var field: Variant = value.get(key)
	assert_true(field is int)
	if field is int:
		var typed_field: int = field
		return typed_field
	return -1


func _array_field(value: Dictionary, key: String) -> Array:
	var field: Variant = value.get(key)
	assert_true(field is Array)
	if field is Array:
		var typed_field: Array = field
		return typed_field
	return []


func _int_at(values: Array, index: int) -> int:
	assert_gt(values.size(), index)
	if values.size() <= index:
		return -1
	var value: Variant = values[index]
	assert_true(value is int)
	if value is int:
		var typed_value: int = value
		return typed_value
	return -1


func _request_with_temporary_sender(tracker: GFNetworkRequestTracker) -> WeakRef:
	var sender: SendProbe = SendProbe.new()
	var sender_ref: WeakRef = weakref(sender)
	var handle: GFNetworkRequestHandle = tracker.request(2, sender.send)
	assert_true(handle.is_pending())
	return sender_ref


func _weak_ref_is_empty(value: WeakRef) -> bool:
	return value.get_ref() == null


# --- 内部类 ---

class ObservedMonotonicClock extends GFClock:
	var _observations: Array[int] = []
	var _last_msec: int = 0

	func get_monotonic_msec() -> int:
		if not _observations.is_empty():
			_last_msec = _observations[0]
			_observations.remove_at(0)
		return _last_msec

	# 模拟外部单调时间在两次观测之间推进，不依赖休眠或机器速度。
	func queue_observations(values: Array[int]) -> void:
		_observations.assign(values)


class SendProbe extends RefCounted:
	var request_ids: Array[String] = []
	var send_error: Error = OK
	var on_send: Callable = Callable()

	func send(request_id: String) -> Error:
		request_ids.append(request_id)
		if on_send.is_valid():
			var _callback_result: Variant = on_send.call(request_id)
		return send_error


class CompletionProbe extends RefCounted:
	var results: Array[GFNetworkRequestResult] = []

	func record(result: GFNetworkRequestResult) -> void:
		results.append(result)


class ReplyBackend extends GFNetworkBackend:
	var serializer: GFNetworkSerializer = GFNetworkSerializer.new()
	var sent_messages: Array[GFNetworkMessage] = []
	var reply_during_send: bool = false

	func connect_to_endpoint(_endpoint: String, _options: Dictionary = {}) -> Error:
		connected.emit()
		return OK

	func disconnect_backend() -> void:
		disconnected.emit("closed")

	func send_bytes(peer_id: int, bytes: PackedByteArray, _options: Dictionary = {}) -> Error:
		var message: GFNetworkMessage = serializer.deserialize_message(bytes)
		if message == null:
			return ERR_INVALID_DATA
		sent_messages.append(message)
		var request_id_value: Variant = message.payload.get("request_id")
		if reply_during_send and request_id_value is String:
			var request_id: String = request_id_value
			emit_reply(peer_id, request_id, { "answer": 7 })
		return OK

	func emit_reply(peer_id: int, request_id: String, response: Variant) -> void:
		var message: GFNetworkMessage = GFNetworkMessage.new(&"reply", {
			"request_id": request_id,
			"response": response,
		})
		message.sender_id = 999
		message_received.emit(peer_id, serializer.serialize_message(message))

	func emit_event(peer_id: int) -> void:
		var message: GFNetworkMessage = GFNetworkMessage.new(&"event", { "value": 3 })
		message_received.emit(peer_id, serializer.serialize_message(message))


class ProjectAdapter extends RefCounted:
	var utility: GFNetworkUtility = GFNetworkUtility.new()
	var tracker: GFNetworkRequestTracker = GFNetworkRequestTracker.new()
	var ordinary_message_count: int = 0
	var accepted_replies: Array[bool] = []

	func _init(backend: ReplyBackend) -> void:
		utility.set_backend(backend)
		var _message_connection: int = utility.message_received.connect(_on_message_received)
		var _started_connection: int = utility.session.session_started.connect(_on_session_started)
		var _closed_connection: int = utility.session.session_closed.connect(_on_session_closed)
		var _peer_connection: int = utility.peer_disconnected.connect(_on_peer_disconnected)

	func request(peer_id: int) -> GFNetworkRequestHandle:
		return tracker.request(peer_id, _send.bind(peer_id))

	func dispose() -> void:
		tracker.dispose()
		utility.message_received.disconnect(_on_message_received)
		utility.session.session_started.disconnect(_on_session_started)
		utility.session.session_closed.disconnect(_on_session_closed)
		utility.peer_disconnected.disconnect(_on_peer_disconnected)
		utility.dispose()

	func _send(request_id: String, peer_id: int) -> Error:
		return utility.send_message(peer_id, GFNetworkMessage.new(&"request", {
			"request_id": request_id,
		}))

	func _on_message_received(peer_id: int, message: GFNetworkMessage) -> void:
		if message.message_type != &"reply":
			ordinary_message_count += 1
			return
		var request_id_value: Variant = message.payload.get("request_id")
		if request_id_value is String:
			var request_id: String = request_id_value
			accepted_replies.append(tracker.receive_reply(
				peer_id,
				request_id,
				message.payload.get("response")
			))

	func _on_session_started(_mode: int, _endpoint: String) -> void:
		var _session_error: Error = tracker.begin_session()

	func _on_session_closed(_reason: String) -> void:
		tracker.end_session()

	func _on_peer_disconnected(peer_id: int) -> void:
		tracker.disconnect_peer(peer_id)
