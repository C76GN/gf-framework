## 测试触屏控件默认不桥接项目级输入。
extends GutTest


const _TOUCH_BUTTON_ACTION: StringName = &"gf_test_touch_button"
const _TOUCH_JOYSTICK_RIGHT_ACTION: StringName = &"gf_test_touch_joystick_right"


func before_each() -> void:
	_cleanup_actions()


func after_each() -> void:
	_cleanup_actions()


func test_touch_button_mouse_and_action_bridges_are_opt_in_by_default() -> void:
	var button: GFTouchButton = GFTouchButton.new()
	add_child_autofree(button)

	assert_false(button.accept_mouse_input, "触屏按钮默认不应接管鼠标左键。")
	assert_eq(button.action_name, &"", "触屏按钮默认不应映射 InputMap 动作。")
	assert_false(button.emit_joypad_button, "触屏按钮默认不应发送虚拟手柄事件。")


func test_touch_joystick_action_bridges_are_opt_in_by_default() -> void:
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	add_child_autofree(joystick)

	assert_eq(joystick.action_left, &"", "触屏摇杆默认不应映射左方向动作。")
	assert_eq(joystick.action_right, &"", "触屏摇杆默认不应映射右方向动作。")
	assert_eq(joystick.action_up, &"", "触屏摇杆默认不应映射上方向动作。")
	assert_eq(joystick.action_down, &"", "触屏摇杆默认不应映射下方向动作。")
	assert_false(joystick.emit_joypad_motion, "触屏摇杆默认不应发送虚拟手柄轴事件。")


func test_touch_joystick_preserves_analog_strength_after_deadzone() -> void:
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	add_child_autofree(joystick)
	joystick.radius = 100.0
	joystick.deadzone = 0.2

	joystick._update_from_local_position(Vector2(10.0, 0.0))
	assert_eq(joystick.get_direction(), Vector2.ZERO, "死区内应输出零向量。")

	joystick._update_from_local_position(Vector2(60.0, 0.0))
	assert_almost_eq(joystick.get_direction().x, 0.5, 0.001, "死区外应按剩余行程保留模拟强度。")
	assert_almost_eq(joystick.get_direction().y, 0.0, 0.001, "水平输入不应产生垂直分量。")


func test_touch_joystick_dpad_modes_quantize_direction() -> void:
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	add_child_autofree(joystick)
	joystick.radius = 100.0
	joystick.deadzone = 0.1

	joystick.output_mode = GFTouchJoystick.OutputMode.DPAD_4
	joystick._update_from_local_position(Vector2(40.0, 80.0))
	assert_eq(joystick.get_direction(), Vector2(0.0, 1.0), "四方向模式应选择主轴方向。")

	joystick.output_mode = GFTouchJoystick.OutputMode.DPAD_8
	joystick._update_from_local_position(Vector2(40.0, 80.0))
	assert_eq(joystick.get_direction(), Vector2(1.0, 1.0), "八方向模式应允许对角方向。")


func test_touch_joystick_active_region_blocks_start_and_release_outside() -> void:
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	add_child_autofree(joystick)
	joystick.radius = 100.0
	joystick.deadzone = 0.0
	joystick.use_active_region = true
	joystick.active_region = Rect2(Vector2(10.0, 10.0), Vector2(50.0, 50.0))

	assert_false(
		joystick._can_begin_at(Vector2(0.0, 0.0), Vector2(5.0, 5.0)),
		"active region 外不应开始触控。"
	)
	assert_true(
		joystick._can_begin_at(Vector2(0.0, 0.0), Vector2(20.0, 20.0)),
		"active region 内应允许开始触控。"
	)

	joystick._begin_touch(2, Vector2.ZERO, Vector2.ZERO)
	assert_eq(joystick._active_touch_index, 2, "测试应能建立触控状态。")

	var drag: InputEventScreenDrag = InputEventScreenDrag.new()
	drag.index = 2
	drag.position = Vector2(90.0, 90.0)
	joystick._handle_drag(drag)

	assert_eq(joystick._active_touch_index, -1, "拖出 active region 后应自动释放。")


func test_touch_joystick_empty_active_region_rejects_and_warns_once() -> void:
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	add_child_autofree(joystick)
	joystick.use_active_region = true
	joystick.active_region = Rect2()

	assert_false(
		joystick._can_begin_at(Vector2.ZERO, Vector2(10.0, 10.0)),
		"启用 active_region 但区域为空时应拒绝触摸起点。"
	)
	assert_push_warning("[GFTouchJoystick] use_active_region 已启用，但 active_region 为空；触摸起点和拖动将被拒绝。")

	assert_false(
		joystick._can_begin_at(Vector2.ZERO, Vector2(10.0, 10.0)),
		"空 active_region 后续仍应拒绝触摸起点。"
	)
	assert_push_warning_count(1, "空 active_region warning 应只发出一次，避免每帧刷屏。")


func test_touch_joystick_active_region_accepts_negative_size_rect_after_normalization() -> void:
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	add_child_autofree(joystick)
	joystick.use_active_region = true
	joystick.active_region = Rect2(Vector2(60.0, 60.0), Vector2(-50.0, -50.0))

	assert_true(
		joystick._can_begin_at(Vector2.ZERO, Vector2(20.0, 20.0)),
		"负尺寸 active_region 应先规范化再判断命中。"
	)


func test_touch_joystick_follow_mode_moves_origin_when_touch_exceeds_radius() -> void:
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	add_child_autofree(joystick)
	joystick.radius = 50.0
	joystick.deadzone = 0.0
	joystick.position_mode = GFTouchJoystick.PositionMode.FOLLOW
	joystick.global_position = Vector2(10.0, 20.0)

	joystick._update_from_local_position(Vector2(80.0, 0.0))

	assert_almost_eq(joystick.global_position.x, 40.0, 0.001, "FOLLOW 模式应让摇杆中心跟随超出半径的触点。")
	assert_almost_eq(joystick.global_position.y, 20.0, 0.001, "水平拖动不应移动垂直中心。")
	assert_almost_eq(joystick.get_direction().x, 1.0, 0.001, "超出半径后手柄应保持满强度方向。")
	assert_almost_eq(joystick.get_direction().y, 0.0, 0.001, "FOLLOW 模式不应改变输入方向。")


func test_touch_button_releases_action_when_hidden() -> void:
	InputMap.add_action(_TOUCH_BUTTON_ACTION)
	var button: GFTouchButton = GFTouchButton.new()
	button.action_name = _TOUCH_BUTTON_ACTION
	add_child_autofree(button)
	watch_signals(button)

	button._handle_touch(_make_touch_event(1, true, Vector2.ZERO))
	assert_true(Input.is_action_pressed(_TOUCH_BUTTON_ACTION), "触屏按钮按下后应桥接动作。")

	button.visible = false
	button._notification(CanvasItem.NOTIFICATION_VISIBILITY_CHANGED)

	assert_false(button.is_pressed(), "隐藏按钮应释放内部按下状态。")
	assert_false(Input.is_action_pressed(_TOUCH_BUTTON_ACTION), "隐藏按钮应释放桥接动作。")
	assert_signal_emit_count(button, "button_released", 1, "隐藏释放只应发出一次释放信号。")


func test_touch_joystick_releases_action_when_hidden() -> void:
	InputMap.add_action(_TOUCH_JOYSTICK_RIGHT_ACTION)
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	joystick.radius = 100.0
	joystick.deadzone = 0.0
	joystick.action_right = _TOUCH_JOYSTICK_RIGHT_ACTION
	add_child_autofree(joystick)
	watch_signals(joystick)

	joystick._begin_touch(1, Vector2.ZERO, Vector2.ZERO)
	joystick._update_from_local_position(Vector2(80.0, 0.0))
	assert_true(Input.is_action_pressed(_TOUCH_JOYSTICK_RIGHT_ACTION), "摇杆右向输入应桥接动作。")

	joystick.visible = false
	joystick._notification(CanvasItem.NOTIFICATION_VISIBILITY_CHANGED)

	assert_eq(joystick.get_direction(), Vector2.ZERO, "隐藏摇杆应清空方向。")
	assert_false(Input.is_action_pressed(_TOUCH_JOYSTICK_RIGHT_ACTION), "隐藏摇杆应释放桥接动作。")
	assert_signal_emit_count(joystick, "joystick_released", 1, "隐藏释放只应发出一次释放信号。")


func test_touch_joystick_relative_release_restores_pre_touch_position() -> void:
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	add_child_autofree(joystick)
	joystick.position_mode = GFTouchJoystick.PositionMode.RELATIVE
	joystick.global_position = Vector2(20.0, 30.0)
	var rest_position: Vector2 = joystick.global_position

	joystick._begin_touch(1, Vector2(100.0, 100.0), Vector2.ZERO)
	joystick.release()

	assert_eq(joystick.global_position, rest_position, "RELATIVE 模式释放后应回到触摸前中心。")


func test_touch_joystick_release_is_idempotent() -> void:
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	add_child_autofree(joystick)
	watch_signals(joystick)

	joystick.release()
	joystick.release()
	assert_signal_emit_count(joystick, "joystick_released", 0, "未激活时重复释放不应发信号。")

	joystick._begin_touch(1, Vector2.ZERO, Vector2.ZERO)
	joystick.release()
	joystick.release()

	assert_signal_emit_count(joystick, "joystick_released", 1, "活跃触点只应释放一次。")


func _cleanup_actions() -> void:
	for action_id: StringName in [_TOUCH_BUTTON_ACTION, _TOUCH_JOYSTICK_RIGHT_ACTION]:
		if InputMap.has_action(action_id):
			InputMap.erase_action(action_id)


func _make_touch_event(index: int, pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	return event
