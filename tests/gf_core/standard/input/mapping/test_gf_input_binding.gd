## 测试 GFInputBinding 的深拷贝、事件匹配与贡献值计算。
extends GutTest


func test_duplicate_binding_copies_fields_without_aliasing() -> void:
	var orig: GFInputBinding = GFInputBinding.new()
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F
	key.physical_keycode = KEY_NONE
	orig.input_event = key
	orig.scale = 2.0
	orig.remappable = false
	orig.match_touch_index = true
	var dup: GFInputBinding = orig.duplicate_binding()

	assert_ne(dup, orig, "duplicate_binding 应返回新实例。")
	dup.scale = 0.5
	assert_eq(orig.scale, 2.0, "修改拷贝不应影响原绑定的 scale。")

	var dup_key: InputEventKey = _key_event(dup.input_event)
	dup_key.keycode = KEY_G
	var orig_key: InputEventKey = _key_event(orig.input_event)
	assert_eq(orig_key.keycode, KEY_F, "input_event 应深拷贝。")


func test_matches_event_returns_false_when_template_or_event_null() -> void:
	var binding: GFInputBinding = GFInputBinding.new()
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = KEY_A
	ev.pressed = true
	assert_false(binding.matches_event(ev), "未设置模板事件时不应匹配。")

	var template: InputEventKey = InputEventKey.new()
	template.keycode = KEY_B
	binding.input_event = template
	assert_false(binding.matches_event(null), "运行时事件为 null 时不应匹配。")


func test_match_device_requires_same_device_id() -> void:
	var template: InputEventJoypadButton = InputEventJoypadButton.new()
	template.device = 0
	template.button_index = JOY_BUTTON_A
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = template
	binding.match_device = true
	var other_device: InputEventJoypadButton = InputEventJoypadButton.new()
	other_device.device = 1
	other_device.button_index = JOY_BUTTON_A
	assert_false(binding.matches_event(other_device), "设备 ID 不同时不应匹配。")
	other_device.device = 0
	assert_true(binding.matches_event(other_device), "设备与按键一致时应匹配。")


func test_match_device_accepts_legacy_keyboard_device_zero() -> void:
	var template: InputEventKey = InputEventKey.new()
	template.device = 0
	template.keycode = KEY_A
	template.physical_keycode = KEY_A
	template.pressed = true
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = template
	binding.match_device = true

	var runtime_key: InputEventKey = InputEventKey.new()
	runtime_key.device = -1
	runtime_key.keycode = KEY_A
	runtime_key.physical_keycode = KEY_A
	runtime_key.pressed = true

	assert_true(binding.matches_event(runtime_key), "旧键盘模板 device 0 应匹配 Godot 4.7 的键盘设备 ID。")


func test_match_device_accepts_legacy_mouse_device_zero() -> void:
	var template: InputEventMouseButton = InputEventMouseButton.new()
	template.device = 0
	template.button_index = MOUSE_BUTTON_LEFT
	template.pressed = true
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = template
	binding.match_device = true

	var runtime_mouse: InputEventMouseButton = InputEventMouseButton.new()
	runtime_mouse.device = -2
	runtime_mouse.button_index = MOUSE_BUTTON_LEFT
	runtime_mouse.pressed = true

	assert_true(binding.matches_event(runtime_mouse), "旧鼠标模板 device 0 应匹配 Godot 4.7 的鼠标设备 ID。")


func test_match_device_keeps_explicit_keyboard_devices_exact() -> void:
	var template: InputEventKey = InputEventKey.new()
	template.device = 2
	template.keycode = KEY_A
	template.physical_keycode = KEY_A
	template.pressed = true
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = template
	binding.match_device = true

	var runtime_key: InputEventKey = InputEventKey.new()
	runtime_key.device = 3
	runtime_key.keycode = KEY_A
	runtime_key.physical_keycode = KEY_A
	runtime_key.pressed = true
	assert_false(binding.matches_event(runtime_key), "明确非 0 键盘设备 ID 仍应精确匹配。")

	runtime_key.device = 2
	assert_true(binding.matches_event(runtime_key), "明确非 0 键盘设备 ID 一致时应匹配。")


func test_key_release_matches_template_without_modifier_state() -> void:
	var template: InputEventKey = InputEventKey.new()
	template.keycode = KEY_A
	template.pressed = true
	template.ctrl_pressed = true

	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = template

	var release: InputEventKey = InputEventKey.new()
	release.keycode = KEY_A
	release.pressed = false
	release.ctrl_pressed = false

	assert_true(binding.matches_event(release), "按键释放事件应按键位匹配，避免修饰键释放顺序导致动作卡住。")


func test_match_touch_index_controls_screen_touch_index() -> void:
	var template: InputEventScreenTouch = InputEventScreenTouch.new()
	template.index = 1
	var binding: GFInputBinding = GFInputBinding.new()
	binding.input_event = template
	binding.match_touch_index = false
	var ev: InputEventScreenTouch = InputEventScreenTouch.new()
	ev.index = 2
	assert_true(binding.matches_event(ev), "关闭 index 精确匹配时应接受任意 index。")
	binding.match_touch_index = true
	assert_false(binding.matches_event(ev), "index 不同时不应匹配。")
	ev.index = 1
	assert_true(binding.matches_event(ev), "index 一致时应匹配。")


func test_get_display_name_respects_override() -> void:
	var binding: GFInputBinding = GFInputBinding.new()
	binding.display_name = "自定义跳跃"
	binding.input_event = InputEventKey.new()
	assert_eq(binding.get_display_name(), "自定义跳跃", "非空 display_name 应优先返回。")


func test_get_contribution_bool_respects_scale() -> void:
	var binding: GFInputBinding = GFInputBinding.new()
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_X
	key.pressed = true
	binding.input_event = key
	binding.value_target = GFInputBinding.ValueTarget.BOOL
	binding.scale = 0.5
	var value: Vector3 = binding.get_contribution(key, GFInputAction.ValueType.BOOL)
	assert_almost_eq(value.x, 0.5, 0.0001, "BOOL 目标应将 scale 应用到 x 分量。")


func test_get_contribution_joy_axis_negative_target_uses_positive_magnitude() -> void:
	var binding: GFInputBinding = GFInputBinding.new()
	var template: InputEventJoypadMotion = InputEventJoypadMotion.new()
	template.axis = JOY_AXIS_LEFT_X
	binding.input_event = template
	binding.deadzone = 0.1
	binding.value_target = GFInputBinding.ValueTarget.AXIS_1D_NEGATIVE
	binding.scale = 1.0
	var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = -0.9
	var value: Vector3 = binding.get_contribution(motion, GFInputAction.ValueType.AXIS_1D)
	assert_almost_eq(value.x, -0.9, 0.0001, "负向轴绑定应将负轴量级写入负 x 分量。")


# --- 私有/辅助方法 ---

func _key_event(event: InputEvent) -> InputEventKey:
	if event is InputEventKey:
		var key: InputEventKey = event
		return key
	return null
