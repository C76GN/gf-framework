## 测试 GFInputEventIdentity 的输入事件稳定身份。
extends GutTest


# --- 常量 ---

const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")


# --- 测试方法 ---

func test_key_identity_includes_modifiers_and_icon_candidates() -> void:
	var event: InputEventKey = _make_key_event(KEY_K)
	event.ctrl_pressed = true
	event.shift_pressed = true

	var identity: GFInputEventIdentity = GFInputEventIdentity.from_event(event)
	var candidates: PackedStringArray = GFInputEventIdentity.get_icon_candidates(event)

	assert_eq(identity.kind, GFInputEventIdentity.KIND_KEY, "键盘事件应归类为 key。")
	assert_eq(identity.conflict_key, "key:%d:1:0:1:0" % int(KEY_K), "冲突键应包含修饰键。")
	assert_eq(candidates[0], "key:ctrl+shift+k", "组合键图标候选应优先。")
	assert_true(candidates.has("key:k"), "候选应包含主键图标。")


func test_joy_axis_identity_can_override_direction_for_binding_semantics() -> void:
	var event: InputEventJoypadMotion = _make_joy_motion_event(JOY_AXIS_LEFT_X, 1.0)

	var identity: GFInputEventIdentity = GFInputEventIdentity.from_event(event, { "joy_axis_sign": -1 })
	var candidates: PackedStringArray = GFInputEventIdentity.get_icon_candidates(event, { "joy_axis_sign": -1 })

	assert_eq(identity.kind, GFInputEventIdentity.KIND_JOY_AXIS, "手柄轴应归类为 joy_axis。")
	assert_eq(identity.axis_sign, -1, "绑定语义应可覆盖事件瞬时轴方向。")
	assert_eq(identity.conflict_key, "joy_axis:%d:-" % int(JOY_AXIS_LEFT_X), "冲突键应使用覆盖后的方向。")
	assert_true(candidates.has("joy_axis:left_x_negative"), "图标候选也应使用覆盖后的方向。")


func test_identity_dictionary_roundtrip_preserves_json_safe_metadata() -> void:
	var event: InputEventMouseButton = _make_mouse_event(MOUSE_BUTTON_RIGHT)
	var identity: GFInputEventIdentity = GFInputEventIdentity.from_event(event)
	identity.metadata["cell"] = Vector2i(4, 7)

	var data: Dictionary = identity.to_dictionary(true)
	var restored: GFInputEventIdentity = GFInputEventIdentity.from_dictionary(data)

	assert_eq(restored.kind, GFInputEventIdentity.KIND_MOUSE_BUTTON, "事件类别应保留。")
	assert_eq(restored.conflict_key, "mouse_button:%d" % int(MOUSE_BUTTON_RIGHT), "冲突键应保留。")
	assert_eq(_as_vector2i(restored.metadata["cell"]), Vector2i(4, 7), "JSON-safe metadata 应可往返。")


func test_legacy_event_record_rechecks_supported_event_allowlist() -> void:
	var unsupported_event: InputEventShortcut = InputEventShortcut.new()
	var event_text: String = var_to_str(unsupported_event)
	var legacy_value: Variant = str_to_var(event_text)

	assert_true(legacy_value is InputEventShortcut, "测试夹具应能从旧文本恢复白名单外 InputEvent。")
	assert_null(
		_INPUT_EVENT_TOOLS.input_event_from_record({ "event": event_text }),
		"旧文本记录也必须经过与结构化记录相同的事件白名单。"
	)


# --- 私有/辅助方法 ---

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


func _make_joy_motion_event(axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	return event


func _as_vector2i(value: Variant) -> Vector2i:
	assert_true(value is Vector2i, "测试观察值应为 Vector2i。")
	if value is Vector2i:
		var vector: Vector2i = value
		return vector
	return Vector2i.ZERO
