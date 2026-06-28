## 测试 GFInputFormatter 的输入动作格式化入口。
extends GutTest


# --- 常量 ---

const _INPUT_MAP_ACTION: StringName = &"gf_test_formatter_jump"
const _PROJECT_SETTINGS_ACTION: StringName = &"gf_test_formatter_project_jump"


# --- 测试方法 ---

func before_each() -> void:
	GFInputFormatter.clear_icon_providers()
	_clear_input_action(_INPUT_MAP_ACTION)
	_clear_input_action(_PROJECT_SETTINGS_ACTION)
	_clear_project_settings_action(_INPUT_MAP_ACTION)
	_clear_project_settings_action(_PROJECT_SETTINGS_ACTION)


func after_each() -> void:
	GFInputFormatter.clear_icon_providers()
	_clear_input_action(_INPUT_MAP_ACTION)
	_clear_input_action(_PROJECT_SETTINGS_ACTION)
	_clear_project_settings_action(_INPUT_MAP_ACTION)
	_clear_project_settings_action(_PROJECT_SETTINGS_ACTION)


## 验证动作 RichText 可按首选设备类型选择 InputMap 事件。
func test_action_rich_text_uses_preferred_device_event() -> void:
	var provider: GFInputIconAtlasProvider = GFInputIconAtlasProvider.new()
	provider.set_icon_path(&"key:k", "res://icons/key_k.png")
	provider.set_icon_path(&"joy_button:south", "res://icons/joy_south.png")
	GFInputFormatter.add_icon_provider(provider)
	_set_input_map_action(_INPUT_MAP_ACTION, [
		_make_key_event(KEY_K),
		_make_joy_button_event(JOY_BUTTON_A),
	])

	var keyboard_text: String = GFInputFormatter.action_as_rich_text(
		_INPUT_MAP_ACTION,
		{
			"allow_missing_paths": true,
			"preferred_device_type": &"keyboard_mouse",
			"icon_size": 16,
		}
	)
	var joypad_text: String = GFInputFormatter.action_as_rich_text(
		_INPUT_MAP_ACTION,
		{
			"allow_missing_paths": true,
			"preferred_device_type": &"joypad",
			"icon_size": 16,
		}
	)

	assert_true(keyboard_text.contains("key_k.png"), "键鼠偏好应选择键盘事件图标。")
	assert_true(joypad_text.contains("joy_south.png"), "手柄偏好应选择手柄事件图标。")
	assert_eq(
		GFInputFormatter.action_as_text(_INPUT_MAP_ACTION, { "preferred_device_type": &"joypad" }),
		"Button South",
		"动作文本也应复用同一套事件选择规则。"
	)


## 验证项目可显式要求 action 级图标优先。
func test_action_rich_text_can_prefer_action_icon() -> void:
	var provider: GFInputIconAtlasProvider = GFInputIconAtlasProvider.new()
	provider.set_icon_path(&"action:gf_test_formatter_jump", "res://icons/action_jump.png")
	provider.set_icon_path(&"key:k", "res://icons/key_k.png")
	GFInputFormatter.add_icon_provider(provider)
	_set_input_map_action(_INPUT_MAP_ACTION, [_make_key_event(KEY_K)])

	var rich_text: String = GFInputFormatter.action_as_rich_text(
		_INPUT_MAP_ACTION,
		{
			"allow_missing_paths": true,
			"prefer_action_icon": true,
		}
	)

	assert_true(rich_text.contains("action_jump.png"), "显式 action 图标应可覆盖物理绑定图标。")


## 验证动作格式化可回退读取 ProjectSettings 中的编辑器态 Input Map 数据。
func test_action_rich_text_reads_project_settings_action_events() -> void:
	var provider: GFInputIconAtlasProvider = GFInputIconAtlasProvider.new()
	provider.set_icon_path(&"mouse:right", "res://icons/mouse_right.png")
	GFInputFormatter.add_icon_provider(provider)
	ProjectSettings.set_setting(
		"input/%s" % String(_PROJECT_SETTINGS_ACTION),
		{
			"deadzone": 0.5,
			"events": [_make_mouse_event(MOUSE_BUTTON_RIGHT)],
		}
	)

	var rich_text: String = GFInputFormatter.action_as_rich_text(
		_PROJECT_SETTINGS_ACTION,
		{ "allow_missing_paths": true }
	)

	assert_true(rich_text.contains("mouse_right.png"), "未注册到 runtime InputMap 时应读取 ProjectSettings 事件。")


## 验证富文本格式化会稳定转义显示名和回退文本中的 BBCode 括号。
func test_rich_text_escapes_bbcode_brackets_without_reescaping_replacements() -> void:
	var binding: GFInputBinding = GFInputBinding.new()
	binding.display_name = "[A]"

	assert_eq(GFInputFormatter.binding_as_rich_text(binding), "[lb]A[rb]", "显示名中的 BBCode 括号应被转义一次。")
	assert_eq(
		GFInputFormatter.input_event_as_rich_text(null, { "unbound_text": "[none]" }),
		"[lb]none[rb]",
		"解绑文本中的 BBCode 括号也应被转义一次。"
	)


# --- 私有/辅助方法 ---

func _set_input_map_action(action_name: StringName, events: Array[InputEvent]) -> void:
	_clear_input_action(action_name)
	InputMap.add_action(action_name)
	for input_event: InputEvent in events:
		InputMap.action_add_event(action_name, input_event)


func _clear_input_action(action_name: StringName) -> void:
	if InputMap.has_action(action_name):
		InputMap.erase_action(action_name)


func _clear_project_settings_action(action_name: StringName) -> void:
	var setting_name: String = "input/%s" % String(action_name)
	if ProjectSettings.has_setting(setting_name):
		ProjectSettings.clear(setting_name)


func _make_key_event(key: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	return event


func _make_mouse_event(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _make_joy_button_event(button: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	event.pressure = 1.0
	return event
