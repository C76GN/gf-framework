## 测试触屏控件默认不桥接项目级输入。
extends GutTest


const _TOUCH_BUTTON_ACTION: StringName = &"gf_test_touch_button"
const _TOUCH_BUTTON_NEXT_ACTION: StringName = &"gf_test_touch_button_next"
const _TOUCH_JOYSTICK_RIGHT_ACTION: StringName = &"gf_test_touch_joystick_right"
const _TOUCH_JOYSTICK_NEXT_ACTION: StringName = &"gf_test_touch_joystick_next"
const _TOUCH_SHARED_ACTION: StringName = &"gf_test_touch_shared"
const _TOUCH_LIFETIME_ACTION: StringName = &"gf_test_touch_lifetime"
const _GF_POINTER_CAPTURE_SCRIPT = preload("res://addons/gf/standard/input/common/gf_pointer_capture.gd")


# --- 辅助类 ---

class JoypadEventRecorder extends Node:
	var events: Array[InputEvent] = []

	func _input(event: InputEvent) -> void:
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			events.append(event.duplicate())


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


func test_pointer_capture_tracks_single_active_pointer() -> void:
	var capture: RefCounted = _GF_POINTER_CAPTURE_SCRIPT.new()

	assert_false(GFVariantData.to_bool(capture.call("is_active")), "初始状态不应存在活动指针。")
	assert_true(GFVariantData.to_bool(capture.call("try_capture", 2)), "空闲时应能捕获指针。")
	assert_true(GFVariantData.to_bool(capture.call("matches", 2)), "捕获后应匹配同一指针。")
	assert_false(GFVariantData.to_bool(capture.call("try_capture", 3)), "已有捕获时不应被其他指针抢占。")
	assert_false(GFVariantData.to_bool(capture.call("release", 3)), "不匹配指针不应释放捕获。")
	assert_true(GFVariantData.to_bool(capture.call("release", 2)), "匹配指针应能释放捕获。")
	assert_false(GFVariantData.to_bool(capture.call("is_active")), "释放后不应保留活动指针。")


func test_pointer_capture_rejects_inactive_sentinel() -> void:
	var capture: RefCounted = _GF_POINTER_CAPTURE_SCRIPT.new()

	assert_false(
		GFVariantData.to_bool(capture.call("try_capture", GFPointerCapture.NO_POINTER_ID)),
		"inactive sentinel 不能成为成功捕获的 pointer id。"
	)
	assert_false(GFVariantData.to_bool(capture.call("is_active")), "拒绝 sentinel 后必须保持 inactive。")
	assert_false(
		GFVariantData.to_bool(capture.call("matches", GFPointerCapture.NO_POINTER_ID)),
		"inactive 状态不得报告匹配 sentinel。"
	)


func test_touch_controls_share_base_touch_capture_state() -> void:
	var button: GFTouchButton = GFTouchButton.new()
	add_child_autofree(button)

	button._handle_touch(_make_touch_event(5, true, Vector2.ZERO))
	assert_true(button.is_touch_active(), "触屏按钮应通过共享底座记录活动触点。")
	assert_eq(button.get_active_touch_index(), 5, "共享底座应暴露当前触点 index。")

	button.release()
	assert_false(button.is_touch_active(), "释放后共享底座应清空触点捕获。")
	assert_eq(button._active_touch_index, -1, "历史内部状态应与共享底座保持同步。")


func test_overlapping_touch_buttons_real_input_path_has_single_owner() -> void:
	var first_button: GFTouchButton = GFTouchButton.new()
	var second_button: GFTouchButton = GFTouchButton.new()
	add_child_autofree(first_button)
	add_child_autofree(second_button)
	await get_tree().process_frame

	Input.parse_input_event(_make_touch_event(41, true, Vector2.ZERO))
	await get_tree().process_frame

	var active_count: int = int(first_button.is_touch_active()) + int(second_button.is_touch_active())
	assert_eq(active_count, 1, "真实 _input 路径中一个 touch 只能由一个重叠控件取得。")
	var capturing_button: GFTouchButton = first_button if first_button.is_touch_active() else second_button
	var other_button: GFTouchButton = second_button if capturing_button == first_button else first_button
	assert_true(capturing_button.is_pressed(), "取得 touch 的控件必须进入 pressed。")
	assert_false(other_button.is_pressed(), "Viewport handled 必须阻止另一个重叠控件重复取得 touch。")

	Input.parse_input_event(_make_touch_event(41, false, Vector2.ZERO))
	await get_tree().process_frame

	assert_false(capturing_button.is_touch_active(), "真实 release 必须清除 owner capture。")
	assert_false(capturing_button.is_pressed(), "真实 release 必须清除 owner pressed。")


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


func test_touch_button_releases_action_when_process_mode_is_disabled() -> void:
	InputMap.add_action(_TOUCH_BUTTON_ACTION)
	var button: GFTouchButton = GFTouchButton.new()
	button.action_name = _TOUCH_BUTTON_ACTION
	add_child_autofree(button)

	button._handle_touch(_make_touch_event(1, true, Vector2.ZERO))
	assert_true(Input.is_action_pressed(_TOUCH_BUTTON_ACTION), "测试前置 action 必须被按下。")

	button.process_mode = Node.PROCESS_MODE_DISABLED

	assert_false(Input.is_action_pressed(_TOUCH_BUTTON_ACTION), "process mode 禁用前必须释放动作 lease。")
	assert_false(button.is_pressed(), "process mode 禁用后按钮不得保留 pressed。")
	assert_false(button.is_touch_active(), "process mode 禁用后不得保留 touch capture。")


func test_touch_buttons_keep_shared_action_pressed_until_all_owners_release() -> void:
	InputMap.add_action(_TOUCH_SHARED_ACTION)
	var first_button: GFTouchButton = GFTouchButton.new()
	first_button.action_name = _TOUCH_SHARED_ACTION
	add_child_autofree(first_button)
	var second_button: GFTouchButton = GFTouchButton.new()
	second_button.action_name = _TOUCH_SHARED_ACTION
	add_child_autofree(second_button)

	first_button._handle_touch(_make_touch_event(1, true, Vector2.ZERO))
	second_button._handle_touch(_make_touch_event(2, true, Vector2.ZERO))
	assert_true(Input.is_action_pressed(_TOUCH_SHARED_ACTION), "任一触控 owner 按住时动作应保持按下。")

	first_button._handle_touch(_make_touch_event(1, false, Vector2.ZERO))
	assert_true(Input.is_action_pressed(_TOUCH_SHARED_ACTION), "仍有其他 owner 按住时动作不应被提前释放。")

	second_button._handle_touch(_make_touch_event(2, false, Vector2.ZERO))
	assert_false(Input.is_action_pressed(_TOUCH_SHARED_ACTION), "最后一个 owner 释放后动作才应释放。")


func test_virtual_input_bridge_releases_actions_when_node_owner_exits_tree() -> void:
	InputMap.add_action(_TOUCH_LIFETIME_ACTION)
	var owner_node: Node = Node.new()
	add_child(owner_node)

	assert_true(
		GFVirtualInputBridge.press_action(_TOUCH_LIFETIME_ACTION, owner_node, &"primary"),
		"有效 Node owner 应能按下虚拟动作。"
	)
	assert_true(Input.is_action_pressed(_TOUCH_LIFETIME_ACTION), "owner 存活时动作应保持按下。")

	owner_node.queue_free()
	await get_tree().process_frame

	assert_false(Input.is_action_pressed(_TOUCH_LIFETIME_ACTION), "Node owner 退出树时必须自动释放动作。")


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


func test_touch_joystick_dpad_same_direction_does_not_repeat_action_or_signal() -> void:
	InputMap.add_action(_TOUCH_JOYSTICK_RIGHT_ACTION)
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	joystick.radius = 100.0
	joystick.deadzone = 0.0
	joystick.output_mode = GFTouchJoystick.OutputMode.DPAD_4
	joystick.action_right = _TOUCH_JOYSTICK_RIGHT_ACTION
	add_child_autofree(joystick)
	watch_signals(joystick)

	joystick._begin_touch(1, Vector2.ZERO, Vector2.ZERO)
	joystick._update_from_local_position(Vector2(40.0, 0.0))
	joystick._update_from_local_position(Vector2(80.0, 0.0))

	assert_true(Input.is_action_pressed(_TOUCH_JOYSTICK_RIGHT_ACTION), "同方向 DPAD 拖动期间动作应保持按下。")
	assert_signal_emit_count(joystick, "direction_changed", 1, "DPAD 方向未变化时不应重复发方向信号。")

	joystick.release()
	assert_false(Input.is_action_pressed(_TOUCH_JOYSTICK_RIGHT_ACTION), "释放摇杆后动作应释放。")


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


func test_touch_control_rejects_inactive_sentinel_capture() -> void:
	var button: GFTouchButton = GFTouchButton.new()
	add_child_autofree(button)

	button._handle_touch(_make_touch_event(-1, true, Vector2.ZERO))

	assert_false(button.is_touch_active(), "inactive sentinel 不得成为 touch capture。")
	assert_false(button.is_pressed(), "捕获失败时按钮不得继续进入 pressed。")


func test_touch_button_disabling_mouse_input_releases_active_mouse_press() -> void:
	var button: GFTouchButton = GFTouchButton.new()
	button.accept_mouse_input = true
	add_child_autofree(button)
	watch_signals(button)
	var press: InputEventMouseButton = _make_mouse_button_event(true, Vector2.ZERO)
	var release_event: InputEventMouseButton = _make_mouse_button_event(false, Vector2.ZERO)

	button._input(press)
	assert_true(button.is_pressed(), "测试前置 mouse press 必须生效。")

	button.accept_mouse_input = false
	button._input(release_event)

	assert_false(button.is_pressed(), "停止接收 mouse 之前必须终结已取得的 mouse press。")
	assert_signal_emit_count(button, "button_released", 1, "配置切换只能发布一次 release。")


func test_touch_button_releases_begin_time_action_after_configuration_changes() -> void:
	InputMap.add_action(_TOUCH_BUTTON_ACTION)
	InputMap.add_action(_TOUCH_BUTTON_NEXT_ACTION)
	var button: GFTouchButton = GFTouchButton.new()
	button.action_name = _TOUCH_BUTTON_ACTION
	add_child_autofree(button)

	button._handle_touch(_make_touch_event(1, true, Vector2.ZERO))
	assert_true(Input.is_action_pressed(_TOUCH_BUTTON_ACTION), "测试前置 action 必须被按下。")

	button.action_name = _TOUCH_BUTTON_NEXT_ACTION
	button.release()

	assert_false(Input.is_action_pressed(_TOUCH_BUTTON_ACTION), "release 必须使用 begin-time action identity。")
	assert_false(Input.is_action_pressed(_TOUCH_BUTTON_NEXT_ACTION), "新配置不得收到伪 release 或 press。")

	button._handle_touch(_make_touch_event(2, true, Vector2.ZERO))
	assert_true(Input.is_action_pressed(_TOUCH_BUTTON_NEXT_ACTION), "下一 gesture 必须采用更新后的 action。")
	button.release()
	assert_false(Input.is_action_pressed(_TOUCH_BUTTON_NEXT_ACTION), "下一 gesture 的 action 也必须对称释放。")


func test_touch_button_releases_begin_time_joypad_lane_after_configuration_changes() -> void:
	var recorder: JoypadEventRecorder = JoypadEventRecorder.new()
	add_child_autofree(recorder)
	var button: GFTouchButton = GFTouchButton.new()
	button.emit_joypad_button = true
	button.joypad_device_id = -20
	button.joy_button = JOY_BUTTON_A
	add_child_autofree(button)
	await get_tree().process_frame

	button._handle_touch(_make_touch_event(1, true, Vector2.ZERO))
	button.emit_joypad_button = false
	button.joypad_device_id = -21
	button.joy_button = JOY_BUTTON_B
	button.release()
	await get_tree().process_frame

	var lane_events: Array[InputEventJoypadButton] = _get_joy_button_events(recorder.events, -20, JOY_BUTTON_A)
	assert_eq(lane_events.size(), 2, "begin-time Joypad button lane 必须收到 press/release 一对事件。")
	if lane_events.size() == 2:
		assert_true(lane_events[0].pressed, "首个 lane event 应为 press。")
		assert_false(lane_events[1].pressed, "第二个 lane event 应为 release。")
	assert_eq(_get_joy_button_events(recorder.events, -21, JOY_BUTTON_B).size(), 0, "新 lane 不得收到伪 release。")


func test_touch_joystick_releases_begin_time_actions_after_configuration_changes() -> void:
	InputMap.add_action(_TOUCH_JOYSTICK_RIGHT_ACTION)
	InputMap.add_action(_TOUCH_JOYSTICK_NEXT_ACTION)
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	joystick.radius = 100.0
	joystick.deadzone = 0.0
	joystick.action_right = _TOUCH_JOYSTICK_RIGHT_ACTION
	add_child_autofree(joystick)

	joystick._begin_touch(1, Vector2.ZERO, Vector2.ZERO)
	joystick._update_from_local_position(Vector2(80.0, 0.0))
	assert_true(Input.is_action_pressed(_TOUCH_JOYSTICK_RIGHT_ACTION), "测试前置 action 必须被按下。")

	joystick.action_right = _TOUCH_JOYSTICK_NEXT_ACTION
	joystick.release()

	assert_false(Input.is_action_pressed(_TOUCH_JOYSTICK_RIGHT_ACTION), "release 必须清理 begin-time joystick action。")
	assert_false(Input.is_action_pressed(_TOUCH_JOYSTICK_NEXT_ACTION), "新 action 不得收到伪输出。")

	joystick._begin_touch(2, Vector2.ZERO, Vector2.ZERO)
	joystick._update_from_local_position(Vector2(80.0, 0.0))
	assert_true(Input.is_action_pressed(_TOUCH_JOYSTICK_NEXT_ACTION), "下一 gesture 必须采用更新后的 action。")
	joystick.release()
	assert_false(Input.is_action_pressed(_TOUCH_JOYSTICK_NEXT_ACTION), "下一 gesture 的 action 也必须对称释放。")


func test_touch_joystick_releases_begin_time_joypad_lanes_after_configuration_changes() -> void:
	var recorder: JoypadEventRecorder = JoypadEventRecorder.new()
	add_child_autofree(recorder)
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	joystick.radius = 100.0
	joystick.deadzone = 0.0
	joystick.emit_joypad_motion = true
	joystick.joypad_device_id = -30
	joystick.joy_axis_x = JOY_AXIS_LEFT_X
	joystick.joy_axis_y = JOY_AXIS_LEFT_Y
	add_child_autofree(joystick)
	await get_tree().process_frame

	joystick._begin_touch(1, Vector2.ZERO, Vector2.ZERO)
	joystick._update_from_local_position(Vector2(80.0, 0.0))
	joystick.emit_joypad_motion = false
	joystick.joypad_device_id = -31
	joystick.joy_axis_x = JOY_AXIS_RIGHT_X
	joystick.joy_axis_y = JOY_AXIS_RIGHT_Y
	joystick.release()
	await get_tree().process_frame

	var x_events: Array[InputEventJoypadMotion] = _get_joy_axis_events(recorder.events, -30, JOY_AXIS_LEFT_X)
	var y_events: Array[InputEventJoypadMotion] = _get_joy_axis_events(recorder.events, -30, JOY_AXIS_LEFT_Y)
	assert_eq(x_events.size(), 2, "begin-time X lane 必须收到 active/zero 一对事件。")
	assert_eq(y_events.size(), 2, "begin-time Y lane 必须收到 active/zero 一对事件。")
	if x_events.size() == 2:
		assert_gt(absf(x_events[0].axis_value), 0.0, "X lane 首事件应携带活动值。")
		assert_eq(x_events[1].axis_value, 0.0, "X lane 终态必须归零。")
	if y_events.size() == 2:
		assert_eq(y_events[1].axis_value, 0.0, "Y lane 终态必须归零。")
	assert_eq(_get_joy_axis_events(recorder.events, -31, JOY_AXIS_RIGHT_X).size(), 0, "新 X lane 不得收到伪归零。")
	assert_eq(_get_joy_axis_events(recorder.events, -31, JOY_AXIS_RIGHT_Y).size(), 0, "新 Y lane 不得收到伪归零。")


func test_touch_joystick_release_uses_begin_time_relative_mode() -> void:
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	add_child_autofree(joystick)
	joystick.position_mode = GFTouchJoystick.PositionMode.RELATIVE
	joystick.global_position = Vector2(20.0, 30.0)
	var rest_position: Vector2 = joystick.global_position

	joystick._begin_touch(1, Vector2(100.0, 100.0), Vector2.ZERO)
	joystick.position_mode = GFTouchJoystick.PositionMode.FIXED
	joystick.release()

	assert_eq(joystick.global_position, rest_position, "RELATIVE acquire 必须按 begin-time mode 恢复位置。")


func test_touch_joystick_release_does_not_apply_stale_rest_to_fixed_gesture() -> void:
	var joystick: GFTouchJoystick = GFTouchJoystick.new()
	add_child_autofree(joystick)
	await get_tree().process_frame
	joystick.global_position = Vector2(50.0, 60.0)
	joystick.position_mode = GFTouchJoystick.PositionMode.FIXED
	var fixed_position: Vector2 = joystick.global_position

	joystick._begin_touch(1, Vector2(100.0, 100.0), Vector2.ZERO)
	joystick.position_mode = GFTouchJoystick.PositionMode.RELATIVE
	joystick.release()

	assert_eq(joystick.global_position, fixed_position, "FIXED acquire 不得因当前 mode 改变而恢复陈旧位置。")


func _cleanup_actions() -> void:
	GFVirtualInputBridge.clear_all_actions()
	for action_id: StringName in [
		_TOUCH_BUTTON_ACTION,
		_TOUCH_BUTTON_NEXT_ACTION,
		_TOUCH_JOYSTICK_RIGHT_ACTION,
		_TOUCH_JOYSTICK_NEXT_ACTION,
		_TOUCH_SHARED_ACTION,
		_TOUCH_LIFETIME_ACTION,
	]:
		if InputMap.has_action(action_id):
			InputMap.erase_action(action_id)


func _make_touch_event(index: int, pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	return event


func _make_mouse_button_event(pressed: bool, position: Vector2) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	return event


func _get_joy_button_events(
	events: Array[InputEvent],
	device_id: int,
	button: JoyButton
) -> Array[InputEventJoypadButton]:
	var result: Array[InputEventJoypadButton] = []
	for event: InputEvent in events:
		if not event is InputEventJoypadButton:
			continue
		var joy_button: InputEventJoypadButton = event
		if joy_button.device == device_id and joy_button.button_index == button:
			result.append(joy_button)
	return result


func _get_joy_axis_events(
	events: Array[InputEvent],
	device_id: int,
	axis: JoyAxis
) -> Array[InputEventJoypadMotion]:
	var result: Array[InputEventJoypadMotion] = []
	for event: InputEvent in events:
		if not event is InputEventJoypadMotion:
			continue
		var joy_motion: InputEventJoypadMotion = event
		if joy_motion.device == device_id and joy_motion.axis == axis:
			result.append(joy_motion)
	return result
