## 测试 GFPointerActivityUtility 的指针活动状态。
extends GutTest


func test_pointer_activity_tracks_mouse_drag_and_idle() -> void:
	var utility: GFPointerActivityUtility = GFPointerActivityUtility.new()
	utility.drag_threshold_pixels = 4.0
	utility.idle_threshold_seconds = 0.1
	watch_signals(utility)

	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(0.0, 0.0)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(8.0, 0.0)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(8.0, 0.0)

	assert_true(
		utility.handle_input_event(press),
		"鼠标主按钮应被识别。"
	)
	assert_true(utility.is_pointer_pressed, "按下后应记录按压状态。")
	assert_true(
		utility.handle_input_event(motion),
		"鼠标移动应被识别。"
	)
	assert_true(utility.is_pointer_dragging, "超过阈值后应进入拖拽状态。")
	assert_true(
		utility.handle_input_event(release),
		"鼠标释放应被识别。"
	)
	assert_false(utility.is_pointer_pressed, "释放后应清理按压状态。")

	utility.tick(0.0)
	utility.tick(0.11)

	assert_true(utility.is_pointer_idle, "无活动超过阈值后应进入空闲状态。")
	assert_signal_emitted(
		utility,
		"pointer_pressed",
		"按下应发出信号。"
	)
	assert_signal_emitted(
		utility,
		"pointer_drag_started",
		"进入拖拽应发出信号。"
	)
	assert_signal_emitted(
		utility,
		"pointer_drag_ended",
		"释放拖拽应发出结束信号。"
	)
	assert_signal_emitted(
		utility,
		"pointer_idle_started",
		"空闲开始应发出信号。"
	)


func test_pointer_activity_ignores_non_primary_mouse_button() -> void:
	var utility: GFPointerActivityUtility = GFPointerActivityUtility.new()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = Vector2.ONE

	assert_false(
		utility.handle_input_event(press),
		"非主按钮不应被默认追踪。"
	)
	assert_false(utility.is_pointer_pressed, "忽略事件不应改变按压状态。")


func test_pointer_activity_tracks_single_touch_pointer() -> void:
	var utility: GFPointerActivityUtility = GFPointerActivityUtility.new()
	var first_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	first_touch.index = 1
	first_touch.pressed = true
	first_touch.position = Vector2(2.0, 3.0)
	var second_touch: InputEventScreenTouch = InputEventScreenTouch.new()
	second_touch.index = 2
	second_touch.pressed = true
	second_touch.position = Vector2(5.0, 6.0)

	assert_true(
		utility.handle_input_event(first_touch),
		"第一个触点应被追踪。"
	)
	assert_false(
		utility.handle_input_event(second_touch),
		"已有活动触点时应忽略其他触点。"
	)
	assert_eq(
		utility.active_pointer_id,
		1,
		"活动触点 ID 应保持为第一个触点。"
	)
