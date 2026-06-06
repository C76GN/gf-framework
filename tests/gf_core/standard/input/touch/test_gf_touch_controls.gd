## 测试触屏控件默认不桥接项目级输入。
extends GutTest


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
