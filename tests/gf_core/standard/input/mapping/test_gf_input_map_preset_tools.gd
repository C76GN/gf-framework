## 测试 GFInputMapPresetTools 的 InputMap 捕获和应用行为。
extends GutTest


const _CAPTURE_ACTION: StringName = &"gf_test_capture_input_map_preset"
const _APPLY_ACTION: StringName = &"gf_test_apply_input_map_preset"
const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")


# --- 生命周期 ---

func before_each() -> void:
	_cleanup_test_actions()


func after_each() -> void:
	_cleanup_test_actions()


# --- 测试方法 ---

func test_capture_input_map_preserves_action_events_and_metadata() -> void:
	InputMap.add_action(_CAPTURE_ACTION, 0.35)
	InputMap.action_add_event(_CAPTURE_ACTION, _make_key_event(KEY_F, true))

	var preset: Dictionary = GFInputMapPresetTools.capture_input_map({
		"action_ids": PackedStringArray([String(_CAPTURE_ACTION)]),
		"metadata": {
			"profile": "keyboard",
		},
	})
	var actions: Array = GFVariantData.get_option_array(preset, "actions")
	var action_record: Dictionary = GFVariantData.as_dictionary(actions[0])
	var event_records: Array = GFVariantData.get_option_array(action_record, "events")
	var event_record: Dictionary = GFVariantData.as_dictionary(event_records[0])

	assert_eq(GFVariantData.get_option_int(preset, "version"), GFInputMapPresetTools.PRESET_VERSION)
	assert_eq(actions.size(), 1)
	assert_eq(GFVariantData.get_option_string(action_record, "action_id"), String(_CAPTURE_ACTION))
	assert_almost_eq(GFVariantData.get_option_float(action_record, "deadzone"), 0.35, 0.001)
	assert_eq(GFVariantData.get_option_string(event_record, "event_class"), "InputEventKey")
	assert_eq(GFVariantData.get_option_string(GFVariantData.get_option_dictionary(preset, "metadata"), "profile"), "keyboard")


func test_apply_input_map_preset_creates_action_and_replaces_events() -> void:
	InputMap.add_action(_CAPTURE_ACTION, 0.2)
	InputMap.action_add_event(_CAPTURE_ACTION, _make_key_event(KEY_G, true))
	InputMap.add_action(_APPLY_ACTION, 0.8)
	InputMap.action_add_event(_APPLY_ACTION, _make_key_event(KEY_A, true))

	var preset: Dictionary = GFInputMapPresetTools.capture_input_map({
		"action_ids": PackedStringArray([String(_CAPTURE_ACTION)]),
	})
	var actions: Array = GFVariantData.as_array(preset["actions"])
	var action_record: Dictionary = GFVariantData.as_dictionary(actions[0])
	action_record["action_id"] = String(_APPLY_ACTION)

	var report: Dictionary = GFInputMapPresetTools.apply_input_map_preset(preset)
	var applied_event: InputEventKey = _get_first_key_event(_APPLY_ACTION)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效预设应能应用。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "event_count"), 1)
	assert_not_null(applied_event, "应用后目标动作应包含恢复出的按键事件。")
	assert_eq(applied_event.physical_keycode, KEY_G)
	assert_almost_eq(InputMap.action_get_deadzone(_APPLY_ACTION), 0.2, 0.001)


func test_apply_input_map_preset_reports_invalid_event_records() -> void:
	var preset: Dictionary = {
		"version": GFInputMapPresetTools.PRESET_VERSION,
		"actions": [
			{
				"action_id": String(_APPLY_ACTION),
				"deadzone": 0.5,
				"events": [
					{
						"event_class": "NotInputEvent",
					},
				],
			},
		],
	}

	var report: Dictionary = GFInputMapPresetTools.apply_input_map_preset(preset)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "非法事件记录应进入 issues。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 0)
	assert_eq(GFVariantData.get_option_int(report, "event_count"), 0)
	assert_false(InputMap.has_action(_APPLY_ACTION), "存在非法事件时不应创建或修改任何动作。")


func test_apply_input_map_preset_is_all_or_nothing_for_invalid_event_records() -> void:
	var preset: Dictionary = {
		"version": GFInputMapPresetTools.PRESET_VERSION,
		"actions": [
			{
				"action_id": String(_CAPTURE_ACTION),
				"deadzone": 0.2,
				"events": [_event_to_record(_make_key_event(KEY_H, true))],
			},
			{
				"action_id": String(_APPLY_ACTION),
				"deadzone": 0.5,
				"events": [{ "event_class": "NotInputEvent" }],
			},
		],
	}

	var report: Dictionary = GFInputMapPresetTools.apply_input_map_preset(preset)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "任一事件非法时整批应用应失败。")
	assert_false(InputMap.has_action(_CAPTURE_ACTION), "事务失败时前面的有效动作也不应被创建。")
	assert_false(InputMap.has_action(_APPLY_ACTION), "事务失败时非法动作不应被创建。")


# --- 私有/辅助方法 ---

func _cleanup_test_actions() -> void:
	for action_id: StringName in [_CAPTURE_ACTION, _APPLY_ACTION]:
		if InputMap.has_action(action_id):
			InputMap.erase_action(action_id)


func _make_key_event(key: Key, pressed: bool) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	return event


func _event_to_record(input_event: InputEvent) -> Dictionary:
	return _INPUT_EVENT_TOOLS.input_event_to_record(input_event)


func _get_first_key_event(action_id: StringName) -> InputEventKey:
	for event_value: Variant in InputMap.action_get_events(action_id):
		if event_value is InputEventKey:
			var event: InputEventKey = event_value
			return event
	return null
