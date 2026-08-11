## 测试表面坐标到 Viewport 指针事件的有界、代际安全桥接。
extends GutTest


# --- 辅助类 ---

class ReentrantInputReceiver extends Node:
	var events: Array[InputEvent] = []
	var _handler: Callable = Callable()
	var _armed: bool = false

	func arm(handler: Callable) -> void:
		_handler = handler
		_armed = handler.is_valid()
		set_process_input(_armed)

	func _input(event: InputEvent) -> void:
		events.append(event.duplicate())
		if not _armed:
			return
		_armed = false
		_handler.call(event)


# --- 私有变量 ---

var _bridge: GFViewportSurfaceInputBridge
var _events: Array[InputEvent] = []
var _forwarded_generations: Array[int] = []
var _reentrant_capture: GFViewportSurfaceInputCapture = null


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_bridge = GFViewportSurfaceInputBridge.new()
	var connection_error: int = _bridge.input_forwarded.connect(_on_input_forwarded)
	assert_eq(connection_error, OK)
	_events.clear()
	_forwarded_generations.clear()
	_reentrant_capture = null


func after_each() -> void:
	if _bridge != null:
		_bridge.dispose()
		_bridge = null
	await get_tree().process_frame


# --- 测试方法 ---

## 验证 hover 投递中的 source 终止会使尚未发布的旧调用栈失效。
func test_reentrant_cancel_source_invalidates_hover_dispatch() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var receiver: ReentrantInputReceiver = ReentrantInputReceiver.new()
	viewport.add_child(receiver)
	receiver.arm(func(_event: InputEvent) -> void:
		assert_eq(_bridge.cancel_source(&"hover_cancel", 20), 0)
	)

	assert_false(_bridge.forward_mouse_hover(
		&"hover_cancel",
		1,
		0,
		viewport,
		1,
		Vector2(0.5, 0.5),
		10
	))
	assert_eq(_events.size(), 0, "已终止 source 的旧 hover 不得再发布 input_forwarded。")
	assert_eq(_bridge.get_pointer_timestamp_count(), 0)


## 验证 Viewport 输入回调取消并重捕获同 key 时，外层 press 不得返回或发布旧代际。
func test_reentrant_recapture_suppresses_stale_outer_press_completion() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var receiver: ReentrantInputReceiver = ReentrantInputReceiver.new()
	viewport.add_child(receiver)
	receiver.arm(func(_event: InputEvent) -> void:
		assert_eq(_bridge.cancel_source(&"reentrant", 11), 1)
		_reentrant_capture = _capture_mouse(
			viewport, &"reentrant", 1, 0, 7, Vector2(0.75, 0.5), 12
		)
	)

	var stale_capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"reentrant", 1, 0, 7, Vector2(0.25, 0.5), 10
	)

	assert_null(stale_capture, "push_input 期间已被取消的外层 capture 不得报告成功。")
	assert_not_null(_reentrant_capture)
	if _reentrant_capture == null:
		return
	assert_true(_bridge.has_capture(_reentrant_capture))
	assert_eq(_bridge.get_active_pointer_count(), 1)
	assert_eq(_forwarded_generations.size(), 2, "旧 press 的 input_forwarded 必须被抑制。")
	assert_eq(
		_forwarded_generations[_forwarded_generations.size() - 1],
		_reentrant_capture.get_capture_generation(),
		"最后发布的代际必须是重入创建的新 capture。"
	)


## 验证终止 push 内重捕获后立即停止剩余 cancel，且旧栈不得删除新双击历史。
func test_reentrant_recapture_stops_remaining_cancel_and_preserves_new_history() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var receiver: ReentrantInputReceiver = ReentrantInputReceiver.new()
	viewport.add_child(receiver)
	var stale_capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"terminal", 2, 0, 9, Vector2(0.25, 0.5), 10
	)
	assert_not_null(stale_capture)
	if stale_capture == null:
		return
	assert_true(_bridge.press_mouse_button(
		stale_capture,
		viewport,
		9,
		Vector2(0.25, 0.5),
		11,
		MOUSE_BUTTON_RIGHT
	))
	receiver.events.clear()
	_events.clear()
	_forwarded_generations.clear()
	receiver.arm(func(_event: InputEvent) -> void:
		var replacement: GFViewportSurfaceInputCapture = _capture_mouse(
			viewport, &"terminal", 2, 0, 9, Vector2(0.5, 0.5), 20
		)
		assert_not_null(replacement)
		if replacement == null:
			return
		assert_true(_bridge.release_pointer(replacement, 21))
		_reentrant_capture = _capture_mouse(
			viewport, &"terminal", 2, 0, 9, Vector2(0.51, 0.5), 22
		)
	)

	assert_false(
		_bridge.cancel_pointer(stale_capture, 12),
		"终止 push 内已换代时，旧 cancel 不得报告完整成功。"
	)
	assert_not_null(_reentrant_capture)
	if _reentrant_capture == null:
		return
	assert_true(_bridge.has_capture(_reentrant_capture))
	assert_eq(_bridge.get_active_pointer_count(), 1)
	var cancelled_event_count: int = 0
	for input_event: InputEvent in receiver.events:
		if input_event is InputEventMouseButton:
			var mouse_button_event: InputEventMouseButton = input_event
			if mouse_button_event.canceled:
				cancelled_event_count += 1
	assert_eq(cancelled_event_count, 1, "首个 cancel 发生重入后必须停止剩余旧按钮事件。")
	assert_eq(_bridge.get_click_history_count(), 1, "旧 cancel 栈不得删除重入 release 建立的新历史。")
	var replacement_press: InputEventMouseButton = _events.back()
	assert_not_null(replacement_press)
	if replacement_press != null:
		assert_true(replacement_press.double_click, "新代际必须看到重入 release 的最新历史。")


## 验证重入新代际已终止且 key 再次为空时，仍能通过操作 epoch 拒绝旧 tombstone。
func test_terminal_reentry_with_empty_final_key_invalidates_old_tombstone() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var receiver: ReentrantInputReceiver = ReentrantInputReceiver.new()
	viewport.add_child(receiver)
	var stale_capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"tombstone", 3, 0, 10, Vector2(0.25, 0.5), 10
	)
	assert_not_null(stale_capture)
	if stale_capture == null:
		return
	assert_true(_bridge.press_mouse_button(
		stale_capture,
		viewport,
		10,
		Vector2(0.25, 0.5),
		11,
		MOUSE_BUTTON_RIGHT
	))
	receiver.events.clear()
	_events.clear()
	_forwarded_generations.clear()
	receiver.arm(func(_event: InputEvent) -> void:
		_reentrant_capture = _capture_mouse(
			viewport, &"tombstone", 3, 0, 10, Vector2(0.5, 0.5), 20
		)
		assert_not_null(_reentrant_capture)
		if _reentrant_capture != null:
			assert_true(_bridge.release_pointer(_reentrant_capture, 21))
	)

	assert_false(
		_bridge.cancel_pointer(stale_capture, 12),
		"即使重入操作最终也留下空 key，旧 tombstone epoch 也已失效。"
	)
	assert_not_null(_reentrant_capture)
	assert_eq(_bridge.get_active_pointer_count(), 0)
	assert_eq(_bridge.get_click_history_count(), 1)
	var cancelled_event_count: int = 0
	for input_event: InputEvent in receiver.events:
		if input_event is InputEventMouseButton:
			var mouse_button_event: InputEventMouseButton = input_event
			if mouse_button_event.canceled:
				cancelled_event_count += 1
	assert_eq(cancelled_event_count, 1, "发现 tombstone epoch 改变后必须停止其余旧 cancel。")
	assert_eq(_forwarded_generations.size(), 2, "外层旧 cancel 代际不得发布。")
	if _reentrant_capture != null:
		for generation: int in _forwarded_generations:
			assert_eq(generation, _reentrant_capture.get_capture_generation())


## 验证批量取消只处理入口快照代际，不得沿用 key 删除回调中新建的 capture。
func test_bulk_cancel_snapshot_does_not_remove_reentrant_generation() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var first: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"batch", 4, 0, 11, Vector2(0.25, 0.5), 10
	)
	var second: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"batch", 4, 1, 11, Vector2(0.75, 0.5), 11
	)
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	var receiver: ReentrantInputReceiver = ReentrantInputReceiver.new()
	viewport.add_child(receiver)
	receiver.arm(func(_event: InputEvent) -> void:
		assert_true(_bridge.cancel_pointer(second, 20))
		_reentrant_capture = _capture_touch(
			viewport, &"batch", 4, 1, 11, Vector2(0.5, 0.5), 21
		)
	)

	assert_eq(
		_bridge.cancel_source(&"batch", 12),
		1,
		"外层批量操作只计数自己从入口快照移除的记录。"
	)
	assert_not_null(_reentrant_capture)
	if _reentrant_capture == null:
		return
	assert_true(_bridge.has_capture(_reentrant_capture))
	assert_eq(_bridge.get_active_pointer_count(), 1)


## 验证 move 的 Viewport 回调 dispose 桥后，外层不得发布成功且所有状态必须终止。
func test_reentrant_dispose_during_move_fails_closed() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var capture: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"dispose", 5, 0, 12, Vector2(0.25, 0.5), 10
	)
	assert_not_null(capture)
	if capture == null:
		return
	var receiver: ReentrantInputReceiver = ReentrantInputReceiver.new()
	viewport.add_child(receiver)
	_events.clear()
	_forwarded_generations.clear()
	receiver.arm(func(_event: InputEvent) -> void:
		_bridge.dispose(20)
	)

	assert_false(_bridge.move_pointer(capture, viewport, 12, Vector2(0.5, 0.5), 11))
	assert_true(_bridge.is_disposed())
	assert_false(_bridge.has_capture(capture))
	assert_eq(_bridge.get_active_pointer_count(), 0)
	assert_eq(_bridge.get_click_history_count(), 0)
	assert_eq(_events.size(), 1, "dispose 只发布自己完成的 cancel，不得发布外层 move。")
	var disposed_cancel: InputEventScreenTouch = _touch_event_at(0)
	assert_not_null(disposed_cancel)
	if disposed_cancel != null:
		assert_true(disposed_cancel.canceled)


## 验证 release 的 Viewport 回调重捕获同 key 后，旧 release 不得完成新代际。
func test_reentrant_recapture_during_release_keeps_new_generation() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var stale_capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"release", 6, 0, 13, Vector2(0.25, 0.5), 10
	)
	assert_not_null(stale_capture)
	if stale_capture == null:
		return
	var receiver: ReentrantInputReceiver = ReentrantInputReceiver.new()
	viewport.add_child(receiver)
	_events.clear()
	_forwarded_generations.clear()
	receiver.arm(func(_event: InputEvent) -> void:
		_reentrant_capture = _capture_mouse(
			viewport, &"release", 6, 0, 13, Vector2(0.5, 0.5), 20
		)
	)

	assert_false(_bridge.release_pointer(stale_capture, 11))
	assert_not_null(_reentrant_capture)
	if _reentrant_capture == null:
		return
	assert_true(_bridge.has_capture(_reentrant_capture))
	assert_eq(_bridge.get_active_pointer_count(), 1)
	assert_eq(_forwarded_generations.size(), 1, "只能发布重入 press，不得随后发布旧 release。")
	assert_eq(_forwarded_generations[0], _reentrant_capture.get_capture_generation())


## 验证 terminal 回调中的 source 终止使旧 release 失效，并允许新的 source 生命周期。
func test_reentrant_cancel_source_invalidates_release_and_allows_restart() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var stale_capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"release_cancel", 6, 0, 13, Vector2(0.25, 0.5), 10
	)
	assert_not_null(stale_capture)
	if stale_capture == null:
		return
	var receiver: ReentrantInputReceiver = ReentrantInputReceiver.new()
	viewport.add_child(receiver)
	_events.clear()
	_forwarded_generations.clear()
	receiver.arm(func(_event: InputEvent) -> void:
		assert_eq(_bridge.cancel_source(&"release_cancel", 20), 0)
	)

	assert_false(_bridge.release_pointer(stale_capture, 11))
	assert_eq(_events.size(), 0, "已终止 source 的旧 release 不得再发布 input_forwarded。")
	_reentrant_capture = _capture_mouse(
		viewport, &"release_cancel", 6, 0, 13, Vector2(0.5, 0.5), 1
	)
	assert_not_null(_reentrant_capture)
	if _reentrant_capture != null:
		assert_true(_bridge.has_capture(_reentrant_capture))


## 验证主动 dispose 会先完整转发每个已按下鼠标按钮的 cancel，再保持终态。
func test_dispose_forwards_all_pressed_mouse_button_cancels() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"dispose_buttons", 7, 0, 14, Vector2(0.5, 0.5), 10
	)
	assert_not_null(capture)
	if capture == null:
		return
	assert_true(_bridge.press_mouse_button(
		capture,
		viewport,
		14,
		Vector2(0.5, 0.5),
		11,
		MOUSE_BUTTON_RIGHT
	))
	_events.clear()
	_forwarded_generations.clear()

	_bridge.dispose(12)

	assert_true(_bridge.is_disposed())
	assert_eq(_events.size(), 2)
	var left_cancel: InputEventMouseButton = _mouse_button_event_at(0)
	var right_cancel: InputEventMouseButton = _mouse_button_event_at(1)
	assert_not_null(left_cancel)
	assert_not_null(right_cancel)
	if left_cancel != null and right_cancel != null:
		assert_true(left_cancel.canceled)
		assert_eq(left_cancel.button_index, MOUSE_BUTTON_LEFT)
		assert_true(right_cancel.canceled)
		assert_eq(right_cancel.button_index, MOUSE_BUTTON_RIGHT)

## 验证旧 capture receipt 不能在同一指针 key 重用后结束新代际。
func test_stale_capture_receipt_cannot_release_reused_pointer_key() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var first: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"plane", 2, 0, 7, Vector2(0.25, 0.5), 100
	)
	assert_not_null(first)
	if first == null:
		return
	assert_eq(_bridge.get_active_pointer_count(), 1)
	assert_true(_bridge.has_capture(first))
	assert_true(_bridge.release_pointer(first, 110))

	var second: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"plane", 2, 0, 7, Vector2(0.5, 0.5), 120
	)
	assert_not_null(second)
	if second == null:
		return
	assert_ne(first.get_capture_generation(), second.get_capture_generation())

	assert_false(_bridge.release_pointer(first, 130), "旧 receipt 必须被代际校验拒绝。")
	assert_true(_bridge.has_capture(second), "迟到 release 不得终止新 capture。")
	assert_true(_bridge.release_pointer(second, 140))


## 验证 resize 后使用当前 Viewport 尺寸，离面 release 使用最后合法坐标。
func test_mouse_move_and_off_surface_release_use_current_viewport_size() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"panel", 3, 0, 9, Vector2(0.25, 0.5), 100
	)
	assert_not_null(capture)
	if capture == null:
		return
	var press: InputEventMouseButton = _mouse_button_event_at(0)
	assert_not_null(press)
	if press == null:
		return
	assert_eq(press.position, Vector2(49.75, 49.5))
	assert_true(press.pressed)

	viewport.size = Vector2i(400, 200)
	assert_true(_bridge.move_pointer(capture, viewport, 9, Vector2(0.75, 0.25), 110))
	var motion: InputEventMouseMotion = _mouse_motion_event_at(1)
	assert_not_null(motion)
	if motion == null:
		return
	assert_eq(motion.position, Vector2(299.25, 49.75))
	assert_eq(motion.relative, Vector2(199.5, -49.75))

	viewport.size = Vector2i(800, 400)
	assert_true(_bridge.release_pointer(capture, 120))
	var release: InputEventMouseButton = _mouse_button_event_at(2)
	assert_not_null(release)
	if release == null:
		return
	assert_eq(release.position, Vector2(599.25, 99.75))
	assert_false(release.pressed)
	assert_eq(release.button_mask, 0)


## 验证 source/device/pointer 三元 key 隔离且 Touch 保持事件类型。
func test_touch_capture_keys_are_isolated_and_typed() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(300, 150))
	var first: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"left_hand", 4, 0, 11, Vector2(0.1, 0.2), 10
	)
	var second: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"right_hand", 4, 0, 11, Vector2(0.8, 0.7), 20
	)
	assert_not_null(first)
	assert_not_null(second)
	if first == null or second == null:
		return
	assert_eq(_bridge.get_active_pointer_count(), 2)
	var first_press: InputEventScreenTouch = _touch_event_at(0)
	var second_press: InputEventScreenTouch = _touch_event_at(1)
	assert_not_null(first_press)
	assert_not_null(second_press)
	if first_press == null or second_press == null:
		return
	assert_eq(first_press.index, 0)
	assert_eq(second_press.index, 0)
	assert_true(first_press.position.is_equal_approx(Vector2(29.9, 29.8)))
	assert_true(second_press.position.is_equal_approx(Vector2(239.2, 104.3)))

	assert_true(_bridge.release_pointer(first, 30))
	assert_false(_bridge.has_capture(first))
	assert_true(_bridge.has_capture(second))
	assert_eq(_bridge.get_active_pointer_count(), 1)
	assert_true(_bridge.cancel_pointer(second, 40))
	var cancelled: InputEventScreenTouch = _touch_event_at(3)
	assert_not_null(cancelled)
	if cancelled != null:
		assert_false(cancelled.pressed)
		assert_true(cancelled.canceled)


## 验证无效坐标、错误目标代际、回退时间与已释放目标均 fail-closed。
func test_invalid_samples_and_freed_targets_fail_closed() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(120, 80))
	assert_null(_capture_mouse(viewport, &"bad", 1, 0, 1, Vector2(NAN, 0.5), 10))
	assert_null(_capture_mouse(viewport, &"bad", 1, 0, 1, Vector2(0.5, INF), 10))
	assert_null(_capture_mouse(viewport, &"bad", 1, 0, 1, Vector2(-0.01, 0.5), 10))
	assert_null(_capture_mouse(viewport, &"bad", 1, 0, 1, Vector2(0.5, 1.01), 10))
	assert_null(_capture_mouse(
		viewport,
		StringName("x".repeat(129)),
		1,
		0,
		1,
		Vector2(0.5, 0.5),
		10
	))
	assert_null(_capture_mouse(
		viewport,
		&"bad_device",
		2_147_483_648,
		0,
		1,
		Vector2(0.5, 0.5),
		10
	))
	assert_null(_capture_mouse(
		viewport,
		&"bad_pointer",
		1,
		2_147_483_648,
		1,
		Vector2(0.5, 0.5),
		10
	))
	assert_eq(_events.size(), 0)
	assert_eq(_bridge.get_active_pointer_count(), 0)

	var capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"valid", 1, 0, 5, Vector2(0.25, 0.5), 100
	)
	assert_not_null(capture)
	if capture == null:
		return
	assert_false(_bridge.move_pointer(capture, viewport, 6, Vector2(0.5, 0.5), 110))
	assert_false(_bridge.move_pointer(capture, viewport, 5, Vector2(INF, 0.5), 110))
	assert_false(_bridge.move_pointer(capture, viewport, 5, Vector2(0.5, 0.5), 99))
	assert_eq(_events.size(), 1)
	assert_true(_bridge.release_pointer(capture, 120))
	var release: InputEventMouseButton = _mouse_button_event_at(1)
	assert_not_null(release)
	if release != null:
		assert_eq(release.position, Vector2(29.75, 39.5))

	var doomed: SubViewport = _make_viewport(Vector2i(100, 100))
	var doomed_capture: GFViewportSurfaceInputCapture = _capture_touch(
		doomed, &"doomed", 2, 1, 3, Vector2(0.5, 0.5), 200
	)
	assert_not_null(doomed_capture)
	if doomed_capture == null:
		return
	doomed.queue_free()
	await get_tree().process_frame
	assert_false(_bridge.release_pointer(doomed_capture, 210))
	assert_false(_bridge.has_capture(doomed_capture))
	assert_eq(_bridge.get_active_pointer_count(), 0)


## 验证闭区间 UV 全域连续单调地映射到首尾有效像素。
func test_inclusive_uv_mapping_is_continuous_monotonic_and_in_bounds() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(120, 80))
	var normalized_values: Array[float] = [0.0, 0.5, 0.999, 1.0]
	var expected_positions: Array[float] = [0.0, 59.5, 118.881, 119.0]
	var mapped_positions: Array[float] = []
	for index: int in normalized_values.size():
		assert_true(_bridge.forward_mouse_hover(
			&"inclusive_edge",
			1,
			0,
			viewport,
			1,
			Vector2(normalized_values[index], 0.0),
			10 + index
		))
		var motion: InputEventMouseMotion = _mouse_motion_event_at(index)
		assert_not_null(motion)
		if motion != null:
			mapped_positions.append(motion.position.x)
			assert_almost_eq(motion.position.x, expected_positions[index], 0.0001)
	assert_eq(mapped_positions.size(), normalized_values.size())
	for index: int in range(1, mapped_positions.size()):
		assert_gt(mapped_positions[index], mapped_positions[index - 1])


## 验证禁用双击历史时，同一指针上一代之后的迟到 press 仍按时间高水位拒绝。
func test_stale_press_is_rejected_across_capture_generations_without_click_history() -> void:
	assert_true(_bridge.configure_limits(4, 0, 100, 10.0))
	var viewport: SubViewport = _make_viewport(Vector2i(120, 80))
	var first: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"monotonic", 1, 0, 1, Vector2(0.25, 0.5), 100
	)
	assert_not_null(first)
	if first == null:
		return
	assert_true(_bridge.release_pointer(first, 200))
	assert_null(_capture_touch(
		viewport, &"monotonic", 1, 0, 1, Vector2(0.5, 0.5), 150
	))
	var next: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"monotonic", 1, 0, 1, Vector2(0.75, 0.5), 201
	)
	assert_not_null(next)


## 验证 cancel 终止样本也会封存跨代际时间高水位。
func test_cancel_timestamp_rejects_late_press_in_next_generation() -> void:
	assert_true(_bridge.configure_limits(4, 0, 100, 10.0))
	var viewport: SubViewport = _make_viewport(Vector2i(120, 80))
	var capture: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"cancel_monotonic", 1, 0, 1, Vector2(0.25, 0.5), 100
	)
	assert_not_null(capture)
	if capture == null:
		return
	assert_true(_bridge.cancel_pointer(capture, 200))
	assert_null(_capture_touch(
		viewport, &"cancel_monotonic", 1, 0, 1, Vector2(0.5, 0.5), 150
	))


## 验证 source 生命周期终止会清除已释放指针的双击与时间高水位。
func test_cancel_source_clears_completed_pointer_lifecycle_state() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(120, 80))
	var first: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"provider", 1, 0, 1, Vector2(0.25, 0.5), 100
	)
	assert_not_null(first)
	if first == null:
		return
	assert_true(_bridge.release_pointer(first, 110))
	assert_eq(_bridge.get_click_history_count(), 1)
	assert_eq(_bridge.get_pointer_timestamp_count(), 1)

	assert_eq(_bridge.cancel_source(&"provider", 120), 0)
	assert_eq(_bridge.get_click_history_count(), 0)
	assert_eq(_bridge.get_pointer_timestamp_count(), 0)
	var restarted: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"provider", 1, 0, 1, Vector2(0.25, 0.5), 1
	)
	assert_not_null(restarted, "新 provider 生命周期必须允许从自己的单调时钟起点开始。")
	if restarted != null:
		var restarted_press: InputEventMouseButton = _mouse_button_event_at(2)
		assert_not_null(restarted_press)
		if restarted_press != null:
			assert_false(restarted_press.double_click)


## 验证时间高水位拥有独立有界预算，双击历史裁剪不会移除仍在预算内的时间保护。
func test_pointer_timestamp_history_is_independent_and_bounded() -> void:
	assert_false(_bridge.configure_limits(4, 1, 100, 10.0, 0))
	assert_false(_bridge.configure_limits(4, 1, 100, 10.0, 4097))
	assert_true(_bridge.configure_limits(4, 1, 100, 10.0, 2))
	var viewport: SubViewport = _make_viewport(Vector2i(120, 80))
	var first: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"timestamp_a", 1, 0, 1, Vector2(0.25, 0.5), 100
	)
	assert_not_null(first)
	if first == null:
		return
	assert_true(_bridge.release_pointer(first, 110))
	var second: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"timestamp_b", 1, 0, 1, Vector2(0.5, 0.5), 120
	)
	assert_not_null(second)
	if second == null:
		return
	assert_true(_bridge.release_pointer(second, 130))
	assert_eq(_bridge.get_click_history_count(), 1)
	assert_null(_capture_touch(
		viewport, &"timestamp_a", 1, 0, 1, Vector2(0.75, 0.5), 105
	))
	var third: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"timestamp_c", 1, 0, 1, Vector2(0.5, 0.5), 140
	)
	assert_not_null(third)
	if third != null:
		assert_true(_bridge.release_pointer(third, 150))
	assert_eq(_bridge.get_pointer_timestamp_count(), 2)


## 验证带表面位置的 release 与离面 release 一样拒绝滚轮等不支持按钮。
func test_on_surface_release_rejects_unsupported_mouse_button() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(120, 80))
	var capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"unsupported_release", 1, 0, 1, Vector2(0.25, 0.5), 100
	)
	assert_not_null(capture)
	if capture == null:
		return
	assert_false(_bridge.release_pointer_on_surface(
		capture,
		viewport,
		1,
		Vector2(0.75, 0.5),
		110,
		MOUSE_BUTTON_WHEEL_UP
	))
	assert_true(_bridge.has_capture(capture))
	assert_eq(_events.size(), 1)
	assert_true(_bridge.release_pointer(capture, 120))
	var release: InputEventMouseButton = _mouse_button_event_at(1)
	assert_not_null(release)
	if release != null:
		assert_eq(release.position, Vector2(29.75, 39.5), "失败 release 不得更新最后合法位置。")


## 验证同一 pointer key 已捕获时，未按下 hover 不能伪造无按钮 motion。
func test_mouse_hover_fails_closed_while_pointer_key_is_captured() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(120, 80))
	var capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"captured_hover", 1, 0, 1, Vector2(0.25, 0.5), 100
	)
	assert_not_null(capture)
	if capture == null:
		return
	assert_false(_bridge.forward_mouse_hover(
		&"captured_hover",
		1,
		0,
		viewport,
		1,
		Vector2(0.75, 0.5),
		110
	))
	assert_eq(_events.size(), 1)
	assert_true(_bridge.release_pointer(capture, 105), "失败 hover 不得推进捕获时间。")


## 验证成功的重复 press 虽不重复发事件，仍会推进最后合法位置与单调时间。
func test_duplicate_capture_press_advances_last_sample() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(120, 80))
	var capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"duplicate_time", 1, 0, 1, Vector2(0.25, 0.5), 100
	)
	assert_not_null(capture)
	if capture == null:
		return
	var duplicate_capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"duplicate_time", 1, 0, 1, Vector2(0.75, 0.5), 200
	)
	assert_true(duplicate_capture == capture)
	assert_eq(_events.size(), 1)
	assert_false(_bridge.move_pointer(
		capture, viewport, 1, Vector2(0.5, 0.5), 150
	))
	assert_true(_bridge.release_pointer(capture, 210))
	var release: InputEventMouseButton = _mouse_button_event_at(1)
	assert_not_null(release)
	if release != null:
		assert_eq(release.position, Vector2(89.25, 39.5))


## 验证成功的重复按钮 press/release 会推进捕获的单调时间而不重复发事件。
func test_duplicate_mouse_button_samples_advance_monotonic_time() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(120, 80))
	var capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"duplicate_button_time", 1, 0, 1, Vector2(0.25, 0.5), 100
	)
	assert_not_null(capture)
	if capture == null:
		return
	assert_true(_bridge.press_mouse_button(
		capture, viewport, 1, Vector2(0.5, 0.5), 200, MOUSE_BUTTON_RIGHT
	))
	assert_true(_bridge.press_mouse_button(
		capture, viewport, 1, Vector2(0.75, 0.5), 300, MOUSE_BUTTON_RIGHT
	))
	assert_eq(_events.size(), 2)
	assert_false(_bridge.release_pointer(capture, 250, MOUSE_BUTTON_RIGHT))
	assert_true(_bridge.release_pointer(capture, 310, MOUSE_BUTTON_RIGHT))
	assert_true(_bridge.release_pointer(capture, 400, MOUSE_BUTTON_RIGHT))
	assert_eq(_events.size(), 3)
	assert_false(_bridge.move_pointer(
		capture, viewport, 1, Vector2(0.5, 0.5), 350
	))
	assert_true(_bridge.release_pointer(capture, 410))


## 验证活动预算、多鼠标按钮以及重复 press/release 均保持幂等。
func test_limits_and_duplicate_mouse_states_are_bounded_and_idempotent() -> void:
	assert_false(_bridge.configure_limits(0, 2, 500, 8.0))
	assert_false(_bridge.configure_limits(1, 513, 500, 8.0))
	assert_false(_bridge.configure_limits(1, 2, 500, INF))
	assert_true(_bridge.configure_limits(1, 2, 500, 8.0))
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"mouse", 1, 0, 1, Vector2(0.5, 0.5), 10
	)
	assert_not_null(capture)
	if capture == null:
		return
	var duplicate_capture: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"mouse", 1, 0, 1, Vector2(0.5, 0.5), 11
	)
	assert_true(duplicate_capture == capture)
	assert_eq(_events.size(), 1)
	assert_null(_capture_touch(viewport, &"touch", 1, 0, 1, Vector2(0.5, 0.5), 12))

	assert_true(_bridge.press_mouse_button(
		capture, viewport, 1, Vector2(0.5, 0.5), 20, MOUSE_BUTTON_RIGHT
	))
	assert_true(_bridge.press_mouse_button(
		capture, viewport, 1, Vector2(0.5, 0.5), 21, MOUSE_BUTTON_RIGHT
	))
	assert_eq(_events.size(), 2)
	assert_true(_bridge.release_pointer(capture, 30, MOUSE_BUTTON_RIGHT))
	assert_true(_bridge.release_pointer(capture, 31, MOUSE_BUTTON_RIGHT))
	assert_eq(_events.size(), 3)
	assert_true(_bridge.has_capture(capture))
	assert_true(_bridge.release_pointer(capture, 40))
	assert_false(_bridge.has_capture(capture))
	assert_eq(_bridge.get_active_pointer_count(), 0)
	assert_false(_bridge.configure_limits(2, 2, 500, 8.0), "首个样本后禁止改变预算。")


## 验证双击只在同 key、同目标代际、时间与像素距离窗口内成立。
func test_double_click_history_is_windowed_and_bounded() -> void:
	assert_true(_bridge.configure_limits(4, 2, 100, 10.0))
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var first: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"a", 1, 0, 1, Vector2(0.1, 0.5), 0
	)
	assert_not_null(first)
	if first == null:
		return
	assert_true(_bridge.release_pointer(first, 10))
	var second: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"a", 1, 0, 1, Vector2(0.12, 0.5), 50
	)
	assert_not_null(second)
	if second == null:
		return
	var double_press: InputEventMouseButton = _mouse_button_event_at(2)
	assert_not_null(double_press)
	if double_press != null:
		assert_true(double_press.double_click)
	assert_true(_bridge.release_pointer(second, 60))

	var far: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"a", 1, 0, 1, Vector2(0.5, 0.5), 80
	)
	assert_not_null(far)
	if far == null:
		return
	var far_press: InputEventMouseButton = _mouse_button_event_at(4)
	assert_not_null(far_press)
	if far_press != null:
		assert_false(far_press.double_click)
	assert_true(_bridge.release_pointer(far, 90))

	for index: int in range(2):
		var source_id: StringName = StringName("history_%d" % index)
		var history_capture: GFViewportSurfaceInputCapture = _capture_mouse(
			viewport, source_id, 1, 0, 1, Vector2(0.2, 0.2), 100 + index * 10
		)
		assert_not_null(history_capture)
		if history_capture != null:
			assert_true(_bridge.release_pointer(history_capture, 105 + index * 10))
	assert_eq(_bridge.get_click_history_count(), 2)


## 验证重入的历史预算淘汰不会伪装成另一指针的 capture 代际变化。
func test_click_history_eviction_does_not_invalidate_unrelated_active_dispatch() -> void:
	assert_true(_bridge.configure_limits(4, 1, 100, 10.0))
	var viewport: SubViewport = _make_viewport(Vector2i(200, 100))
	var receiver: ReentrantInputReceiver = ReentrantInputReceiver.new()
	viewport.add_child(receiver)
	var previous_a: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"evict_a", 1, 0, 1, Vector2(0.2, 0.5), 0
	)
	assert_not_null(previous_a)
	if previous_a == null:
		return
	assert_true(_bridge.release_pointer(previous_a, 10))
	var active_b: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"evict_b", 1, 0, 1, Vector2(0.8, 0.5), 20
	)
	assert_not_null(active_b)
	if active_b == null:
		return
	receiver.arm(func(_event: InputEvent) -> void:
		assert_true(_bridge.release_pointer(active_b, 30))
	)

	var active_a: GFViewportSurfaceInputCapture = _capture_mouse(
		viewport, &"evict_a", 1, 0, 1, Vector2(0.21, 0.5), 25
	)

	assert_not_null(active_a, "历史淘汰不能使已投递的 A press 报告失败。")
	if active_a != null:
		assert_true(_bridge.has_capture(active_a))
	assert_eq(_bridge.get_click_history_count(), 1)


## 验证 cancel 使用 resize 后的最后合法位置，并发出 Touch cancel。
func test_cancel_uses_last_legal_position_after_resize() -> void:
	var viewport: SubViewport = _make_viewport(Vector2i(100, 80))
	var capture: GFViewportSurfaceInputCapture = _capture_touch(
		viewport, &"touch", 2, 7, 8, Vector2(0.25, 0.5), 100
	)
	assert_not_null(capture)
	if capture == null:
		return
	assert_true(_bridge.move_pointer(capture, viewport, 8, Vector2(0.5, 0.25), 110))
	viewport.size = Vector2i(200, 160)
	assert_true(_bridge.cancel_pointer(capture, 120))
	var cancelled: InputEventScreenTouch = _touch_event_at(2)
	assert_not_null(cancelled)
	if cancelled == null:
		return
	assert_eq(cancelled.position, Vector2(99.5, 39.75))
	assert_false(cancelled.pressed)
	assert_true(cancelled.canceled)
	assert_eq(_bridge.get_active_pointer_count(), 0)


## 验证 source/target 批量清理与 dispose 均有界终止且不可复用。
func test_bulk_cancellation_and_dispose_clear_owned_state() -> void:
	var first_viewport: SubViewport = _make_viewport(Vector2i(100, 100))
	var second_viewport: SubViewport = _make_viewport(Vector2i(100, 100))
	var source_device_one: GFViewportSurfaceInputCapture = _capture_touch(
		first_viewport, &"source", 1, 0, 1, Vector2(0.2, 0.2), 10
	)
	var source_device_two: GFViewportSurfaceInputCapture = _capture_touch(
		first_viewport, &"source", 2, 0, 1, Vector2(0.3, 0.3), 20
	)
	var other_target: GFViewportSurfaceInputCapture = _capture_touch(
		second_viewport, &"other", 3, 0, 4, Vector2(0.4, 0.4), 30
	)
	assert_not_null(source_device_one)
	assert_not_null(source_device_two)
	assert_not_null(other_target)
	assert_eq(_bridge.get_active_pointer_count(), 3)
	assert_eq(_bridge.cancel_source(&"source", 40, 1), 1)
	assert_false(_bridge.has_capture(source_device_one))
	assert_true(_bridge.has_capture(source_device_two))
	assert_eq(_bridge.cancel_target(first_viewport, 1, 50), 1)
	assert_false(_bridge.has_capture(source_device_two))
	assert_true(_bridge.has_capture(other_target))

	_bridge.dispose(60)
	assert_true(_bridge.is_disposed())
	assert_eq(_bridge.get_active_pointer_count(), 0)
	assert_eq(_bridge.get_click_history_count(), 0)
	assert_eq(_bridge.get_pointer_timestamp_count(), 0)
	assert_false(_bridge.has_capture(other_target))
	assert_null(_capture_touch(
		second_viewport, &"late", 3, 1, 4, Vector2(0.5, 0.5), 70
	))


# --- 私有/辅助方法 ---

func _make_viewport(size: Vector2i) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	add_child_autofree(viewport)
	return viewport


func _capture_mouse(
	viewport: SubViewport,
	source_id: StringName,
	device_id: int,
	pointer_id: int,
	target_generation: int,
	normalized_position: Vector2,
	timestamp_msec: int
) -> GFViewportSurfaceInputCapture:
	return _bridge.capture_pointer(
		source_id,
		device_id,
		pointer_id,
		GFViewportSurfaceInputBridge.PointerType.MOUSE,
		viewport,
		target_generation,
		normalized_position,
		timestamp_msec
	)


func _capture_touch(
	viewport: SubViewport,
	source_id: StringName,
	device_id: int,
	pointer_id: int,
	target_generation: int,
	normalized_position: Vector2,
	timestamp_msec: int
) -> GFViewportSurfaceInputCapture:
	return _bridge.capture_pointer(
		source_id,
		device_id,
		pointer_id,
		GFViewportSurfaceInputBridge.PointerType.TOUCH,
		viewport,
		target_generation,
		normalized_position,
		timestamp_msec
	)


func _mouse_button_event_at(index: int) -> InputEventMouseButton:
	if index < 0 or index >= _events.size():
		return null
	var event: InputEvent = _events[index]
	if event is InputEventMouseButton:
		return event
	return null


func _mouse_motion_event_at(index: int) -> InputEventMouseMotion:
	if index < 0 or index >= _events.size():
		return null
	var event: InputEvent = _events[index]
	if event is InputEventMouseMotion:
		return event
	return null


func _touch_event_at(index: int) -> InputEventScreenTouch:
	if index < 0 or index >= _events.size():
		return null
	var event: InputEvent = _events[index]
	if event is InputEventScreenTouch:
		return event
	return null


func _on_input_forwarded(
	_source_id: StringName,
	_device_id: int,
	_pointer_id: int,
	capture_generation: int,
	_target_generation: int,
	_target: Viewport,
	event: InputEvent
) -> void:
	_events.append(event)
	_forwarded_generations.append(capture_generation)
