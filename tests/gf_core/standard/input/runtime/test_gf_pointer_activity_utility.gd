## 测试 GFPointerActivityUtility 的指针活动状态。
extends GutTest


func test_drag_end_callback_new_press_survives_old_release() -> void:
	var utility: GFPointerActivityUtility = GFPointerActivityUtility.new()
	utility.drag_threshold_pixels = 4.0
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	var _pressed: bool = utility.handle_input_event(press)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(8.0, 0.0)
	var _moved: bool = utility.handle_input_event(motion)
	var replacement: InputEventMouseButton = InputEventMouseButton.new()
	replacement.button_index = MOUSE_BUTTON_LEFT
	replacement.pressed = true
	replacement.position = Vector2(50.0, 20.0)
	var ended_callback: Callable = func(
		_pointer_id: int,
		_position: Vector2,
		_event: InputEvent
	) -> void:
		var _replaced: bool = utility.handle_input_event(replacement)
	var _ended_connected: int = utility.pointer_drag_ended.connect(ended_callback)
	watch_signals(utility)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = motion.position
	var _released: bool = utility.handle_input_event(release)
	assert_true(utility.is_pointer_pressed)
	assert_eq(utility.active_pointer_id, 0)
	assert_eq(utility.press_position, replacement.position)
	assert_signal_not_emitted(utility, "pointer_released")
	utility.pointer_drag_ended.disconnect(ended_callback)
	release.position = replacement.position
	var _new_released: bool = utility.handle_input_event(release)
	assert_false(utility.is_pointer_pressed)
	assert_signal_emit_count(
		utility,
		"pointer_released",
		1
	)


func test_idle_end_callback_reset_cancels_old_pointer_press_notification() -> void:
	var utility: GFPointerActivityUtility = GFPointerActivityUtility.new()
	var idle_callback: Callable = func(_pointer_id: int, _position: Vector2) -> void:
		utility.reset_activity()
	var _idle_connected: int = utility.pointer_idle_ended.connect(idle_callback)
	watch_signals(utility)
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	var _pressed: bool = utility.handle_input_event(press)
	assert_false(utility.is_pointer_pressed)
	assert_signal_not_emitted(utility, "pointer_pressed")
	utility.pointer_idle_ended.disconnect(idle_callback)


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
