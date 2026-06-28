## 测试 GFInputDeviceUtility 与 GFInputDeviceAssignment 的设备映射行为。
extends GutTest


# --- 测试方法 ---

## 验证自动刷新可为首位玩家分配键鼠。
func test_refresh_assigns_keyboard_mouse() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.max_players = 1
	utility.include_keyboard_mouse = true
	utility.include_touch = false

	utility.refresh_connected_devices()
	var assignment: GFInputDeviceAssignment = utility.get_assignment(0)

	assert_not_null(assignment, "0 号玩家应获得默认键鼠映射。")
	assert_eq(assignment.device_type, GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE, "默认映射应为键鼠。")
	assert_eq(utility.get_assignments().size(), 1, "max_players 为 1 时只应返回一个映射。")


## 验证手动映射会替换同一玩家并保持排序。
func test_set_assignment_replaces_same_player() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.include_keyboard_mouse = false
	utility.include_touch = false

	utility.set_assignment(utility.create_assignment(2, GFInputDeviceAssignment.DeviceType.AI, -1))
	utility.set_assignment(utility.create_assignment(0, GFInputDeviceAssignment.DeviceType.CUSTOM, 77))
	utility.set_assignment(utility.create_assignment(2, GFInputDeviceAssignment.DeviceType.JOYPAD, 3))

	var assignments: Array[GFInputDeviceAssignment] = utility.get_assignments()

	assert_eq(assignments[0].player_index, 0, "映射应按玩家索引排序。")
	assert_eq(assignments[1].player_index, 2, "替换后仍应保留玩家索引。")
	assert_eq(assignments[1].device_type, GFInputDeviceAssignment.DeviceType.JOYPAD, "同玩家映射应被替换。")
	assert_eq(assignments[1].device_id, 3, "替换后的设备 ID 应生效。")


## 验证手动映射受玩家上限约束，并保持同一设备只归属一个玩家。
func test_set_assignment_rejects_out_of_range_and_keeps_device_unique() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.max_players = 2
	utility.include_keyboard_mouse = false
	utility.include_touch = false

	utility.set_assignment(utility.create_assignment(0, GFInputDeviceAssignment.DeviceType.JOYPAD, 5))
	utility.set_assignment(utility.create_assignment(1, GFInputDeviceAssignment.DeviceType.JOYPAD, 5))
	utility.set_assignment(utility.create_assignment(2, GFInputDeviceAssignment.DeviceType.CUSTOM, 77))

	assert_null(utility.get_assignment(0), "同一手柄重新分配给 1 号玩家后，应移除旧玩家映射。")
	assert_eq(utility.get_player_for_device(GFInputDeviceAssignment.DeviceType.JOYPAD, 5), 1, "同一设备应只映射到最新玩家。")
	assert_null(utility.get_assignment(2), "越过 max_players 的手动映射应被拒绝。")
	assert_push_warning("[GFInputDeviceUtility] 忽略越界玩家设备映射：2")


## 验证设备分配报告会记录原因、旧映射和触发输入。
func test_assignment_report_records_reasons_previous_assignment_and_input_event() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.max_assignment_events = 4
	utility.include_keyboard_mouse = false
	utility.include_touch = false

	utility.set_assignment(
		utility.create_assignment(0, GFInputDeviceAssignment.DeviceType.CUSTOM, 9),
		&"initial"
	)
	utility.set_assignment(
		utility.create_assignment(0, GFInputDeviceAssignment.DeviceType.JOYPAD, 3),
		&"rebinding",
		{ "slot": "primary" },
		_make_joy_button_event(3, JOY_BUTTON_A, true)
	)

	var report: Dictionary = utility.get_assignment_report()
	var events: Array = GFVariantData.get_option_array(report, "recent_events")
	var latest: Dictionary = GFVariantData.as_dictionary(events[events.size() - 1])
	var previous_assignment: Dictionary = GFVariantData.get_option_dictionary(latest, "previous_assignment")
	var input_event: Dictionary = GFVariantData.get_option_dictionary(latest, "input_event")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(latest, "metadata")

	assert_eq(GFVariantData.get_option_int(report, "assignment_count"), 1, "报告应包含当前映射数量。")
	assert_eq(GFVariantData.get_option_string_name(latest, "reason"), &"rebinding", "事件应保留调用方原因。")
	assert_eq(GFVariantData.get_option_int(previous_assignment, "device_id"), 9, "替换映射应记录旧设备。")
	assert_eq(GFVariantData.get_option_string(input_event, "class"), "InputEventJoypadButton", "事件应记录触发输入类型。")
	assert_eq(GFVariantData.get_option_int(input_event, "device"), 3, "事件应记录触发输入设备 ID。")
	assert_eq(GFVariantData.get_option_string(metadata, "slot"), "primary", "事件应保留调用方元数据。")


## 验证返回的映射是拷贝，避免外部直接污染内部表。
func test_get_assignments_returns_copies() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.include_keyboard_mouse = false
	utility.include_touch = false
	utility.set_assignment(utility.create_assignment(0, GFInputDeviceAssignment.DeviceType.CUSTOM, 9))

	var assignments: Array[GFInputDeviceAssignment] = utility.get_assignments()
	assignments[0].device_id = 999

	assert_eq(utility.get_assignment(0).device_id, 9, "外部修改副本不应影响内部映射。")


## 验证未登记手柄输入可自动分配到空玩家席位并更新活跃玩家。
func test_handle_input_event_auto_assigns_joypad_to_empty_player() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.max_players = 2
	utility.include_keyboard_mouse = true
	utility.include_touch = false
	utility.refresh_connected_devices()
	watch_signals(utility)

	var player_index: int = utility.handle_input_event(_make_joy_button_event(7, JOY_BUTTON_A, true))

	assert_eq(player_index, 1, "键鼠占用 0 号位后，未登记手柄应分配到 1 号玩家。")
	assert_eq(utility.get_assignment(1).device_id, 7, "新映射应记录手柄设备 ID。")
	assert_eq(utility.active_player_index, 1, "有效输入应更新最近活跃玩家。")
	assert_signal_emitted(utility, "active_player_changed", "活跃玩家变化时应发出信号。")
	assert_signal_emitted(utility, "active_device_changed", "活跃设备变化时应发出信号。")
	assert_eq(utility.get_active_assignment().device_id, 7, "应能读取当前活跃设备映射副本。")
	assert_eq(utility.get_active_device_name(), Input.get_joy_name(7), "活跃设备显示名应复用设备名解析。")


## 验证 join 输入只在匹配模板时请求本地玩家加入。
func test_handle_join_input_event_emits_join_request() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.max_players = 2
	utility.include_keyboard_mouse = false
	utility.include_touch = false
	utility.refresh_connected_devices()
	utility.configure_default_join_events(false, true)
	watch_signals(utility)

	var player_index: int = utility.handle_join_input_event(_make_joy_button_event(4, JOY_BUTTON_START, true))

	assert_eq(player_index, 0, "未登记手柄的 join 输入应占用第一个空玩家席位。")
	assert_eq(utility.get_assignment(0).device_id, 4, "join 自动分配应记录手柄设备 ID。")
	assert_signal_emitted(utility, "player_join_requested", "匹配 join 输入时应发出加入请求信号。")


## 验证非 join 输入不会触发加入请求。
func test_handle_join_input_event_ignores_unconfigured_input() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.max_players = 1
	utility.include_keyboard_mouse = false
	utility.include_touch = false
	utility.refresh_connected_devices()
	utility.configure_default_join_events(false, true)
	watch_signals(utility)

	var player_index: int = utility.handle_join_input_event(_make_joy_button_event(4, JOY_BUTTON_X, true))

	assert_eq(player_index, -1, "未配置的输入不应触发加入。")
	assert_signal_not_emitted(utility, "player_join_requested", "非 join 输入不应发出加入请求。")


## 验证弱手柄轴噪声不会触发自动分配。
func test_joypad_axis_noise_does_not_auto_assign() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.max_players = 1
	utility.include_keyboard_mouse = false
	utility.include_touch = false
	utility.refresh_connected_devices()

	var player_index: int = utility.handle_input_event(_make_joy_motion_event(3, JOY_AXIS_LEFT_X, 0.2))

	assert_eq(player_index, -1, "低于自动分配阈值的轴输入不应占用玩家席位。")
	assert_null(utility.get_assignment(0), "噪声输入后不应生成映射。")


## 验证已登记手柄的弱轴漂移不会切换最近活跃玩家。
func test_assigned_joypad_axis_noise_does_not_switch_active_player() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.max_players = 2
	utility.include_keyboard_mouse = false
	utility.include_touch = false
	utility.set_assignment(utility.create_assignment(0, GFInputDeviceAssignment.DeviceType.JOYPAD, 1))
	utility.set_assignment(utility.create_assignment(1, GFInputDeviceAssignment.DeviceType.JOYPAD, 2))
	utility.set_active_player(0)

	assert_eq(utility.handle_input_event(_make_joy_motion_event(2, JOY_AXIS_LEFT_X, 0.05)), 1, "已登记设备仍应能解析到玩家。")
	assert_eq(utility.active_player_index, 0, "低于 active_player_axis_threshold 的轴漂移不应切换活跃玩家。")

	assert_eq(utility.handle_input_event(_make_joy_motion_event(2, JOY_AXIS_LEFT_X, 0.5)), 1, "有效轴输入应解析到玩家。")
	assert_eq(utility.active_player_index, 1, "达到 active_player_axis_threshold 的轴输入应切换活跃玩家。")


## 验证玩家级死区覆盖可设置和清除。
func test_player_deadzone_override() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()

	utility.set_player_deadzone(2, 0.35)
	assert_almost_eq(utility.get_player_deadzone(2), 0.35, 0.001, "应能读取玩家级死区覆盖。")

	utility.set_player_deadzone(2, -1.0)
	assert_eq(utility.get_player_deadzone(2, -1.0), -1.0, "传入负数应清除玩家级死区覆盖。")


## 验证玩家震动封装只接受手柄设备。
func test_vibration_for_player_requires_joypad_assignment() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.include_keyboard_mouse = false
	utility.include_touch = false
	utility.set_assignment(utility.create_assignment(0, GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE, 0))
	utility.set_assignment(utility.create_assignment(1, GFInputDeviceAssignment.DeviceType.JOYPAD, 6))

	assert_false(utility.start_vibration_for_player(0, 1.5, -1.0, -2.0), "非手柄玩家不应启动震动。")
	assert_true(utility.start_vibration_for_player(1, 1.5, -1.0, -2.0), "手柄玩家应能启动震动。")
	assert_true(utility.stop_vibration_for_player(1), "手柄玩家应能停止震动。")


## 验证键鼠和触控设备查询会兼容不同原始 device id。
func test_get_player_for_device_normalizes_keyboard_mouse_and_touch_ids() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.include_keyboard_mouse = false
	utility.include_touch = false
	utility.set_assignment(utility.create_assignment(0, GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE, 999))
	utility.set_assignment(utility.create_assignment(1, GFInputDeviceAssignment.DeviceType.TOUCH, 42))

	assert_eq(utility.get_player_for_device(GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE, -7), 0, "键鼠应按逻辑设备匹配，而不是按原始 device id。")
	assert_eq(utility.get_player_for_device(GFInputDeviceAssignment.DeviceType.TOUCH, 99), 1, "触控应按逻辑设备匹配，而不是按原始 device id。")


## 验证公开 active player 切换只接受已分配玩家。
func test_set_active_player_rejects_unassigned_or_out_of_range_players() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.max_players = 2
	utility.include_keyboard_mouse = false
	utility.include_touch = false
	utility.set_assignment(utility.create_assignment(0, GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE, 0))

	utility.set_active_player(1)
	assert_eq(utility.active_player_index, 0, "未分配玩家不应成为 active player。")

	utility.set_active_player(99)
	assert_eq(utility.active_player_index, 0, "越界玩家不应成为 active player。")


## 验证移除当前活跃设备后会修正 active player。
func test_remove_active_assignment_repairs_active_player() -> void:
	var utility: GFInputDeviceUtility = GFInputDeviceUtility.new()
	utility.max_players = 2
	utility.include_keyboard_mouse = false
	utility.include_touch = false
	utility.set_assignment(utility.create_assignment(0, GFInputDeviceAssignment.DeviceType.KEYBOARD_MOUSE, 0))
	utility.set_assignment(utility.create_assignment(1, GFInputDeviceAssignment.DeviceType.JOYPAD, 7))
	utility.set_active_player(1)

	utility.remove_assignment(1)

	assert_eq(utility.active_player_index, 0, "移除当前活跃玩家后应切回仍存在的分配。")

	utility.clear_assignments()

	assert_eq(utility.active_player_index, -1, "没有任何分配时 active player 应进入空状态。")


# --- 私有/辅助方法 ---

func _make_joy_button_event(device: int, button: JoyButton, pressed: bool) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = pressed
	event.pressure = 1.0 if pressed else 0.0
	return event


func _make_joy_motion_event(device: int, axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = axis_value
	return event
