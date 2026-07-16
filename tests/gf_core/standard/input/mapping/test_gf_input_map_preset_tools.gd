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


func test_apply_input_map_preset_rejects_unsupported_version() -> void:
	var preset: Dictionary = {
		"version": GFInputMapPresetTools.PRESET_VERSION + 1,
		"actions": [
			{
				"action_id": String(_APPLY_ACTION),
				"deadzone": 0.5,
				"events": [_event_to_record(_make_key_event(KEY_H, true))],
			},
		],
	}

	var report: Dictionary = GFInputMapPresetTools.apply_input_map_preset(preset)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "版本不匹配的 preset 不应被应用。")
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "unsupported_version")
	assert_false(InputMap.has_action(_APPLY_ACTION), "版本不匹配时不应创建动作。")


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


func test_apply_input_map_preset_rejects_nonfinite_deadzone_transactionally() -> void:
	InputMap.add_action(_APPLY_ACTION, 0.75)
	InputMap.action_add_event(_APPLY_ACTION, _make_key_event(KEY_A, true))
	var preset: Dictionary = {
		"version": GFInputMapPresetTools.PRESET_VERSION,
		"actions": [{
			"action_id": String(_APPLY_ACTION),
			"deadzone": NAN,
			"events": [_event_to_record(_make_key_event(KEY_B, true))],
		}],
	}

	var report: Dictionary = GFInputMapPresetTools.apply_input_map_preset(preset)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "非有限 deadzone 应拒绝整批应用。")
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "invalid_deadzone")
	assert_almost_eq(InputMap.action_get_deadzone(_APPLY_ACTION), 0.75, 0.001, "失败不得覆盖原 deadzone。")
	assert_eq(_count_key_events(_APPLY_ACTION, KEY_A), 1, "失败不得清除原绑定。")
	assert_eq(_count_key_events(_APPLY_ACTION, KEY_B), 0, "失败不得写入候选绑定。")


func test_ensure_input_map_preset_creates_missing_action_and_events() -> void:
	var preset: Dictionary = {
		"version": GFInputMapPresetTools.PRESET_VERSION,
		"actions": [
			{
				"action_id": String(_APPLY_ACTION),
				"deadzone": 0.25,
				"events": [_event_to_record(_make_key_event(KEY_J, true))],
			},
		],
	}

	var report: Dictionary = GFInputMapPresetTools.ensure_input_map_preset(preset)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效预设应能确保到 InputMap。")
	assert_eq(GFVariantData.get_option_int(report, "ensured_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "missing_action_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "created_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "added_event_count"), 1)
	assert_true(InputMap.has_action(_APPLY_ACTION), "缺失动作应被创建。")
	assert_almost_eq(InputMap.action_get_deadzone(_APPLY_ACTION), 0.25, 0.001)
	assert_eq(_count_key_events(_APPLY_ACTION, KEY_J), 1)


func test_ensure_input_map_preset_preserves_existing_bindings_and_is_idempotent() -> void:
	InputMap.add_action(_APPLY_ACTION, 0.8)
	InputMap.action_add_event(_APPLY_ACTION, _make_key_event(KEY_A, true))
	var preset: Dictionary = {
		"version": GFInputMapPresetTools.PRESET_VERSION,
		"actions": [
			{
				"action_id": String(_APPLY_ACTION),
				"deadzone": 0.2,
				"events": [
					_event_to_record(_make_key_event(KEY_A, true)),
					_event_to_record(_make_key_event(KEY_B, true)),
				],
			},
		],
	}

	var report: Dictionary = GFInputMapPresetTools.ensure_input_map_preset(preset)
	var second_report: Dictionary = GFInputMapPresetTools.ensure_input_map_preset(preset)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "已有动作应能只补缺失事件。")
	assert_eq(GFVariantData.get_option_int(report, "existing_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "missing_action_count"), 0)
	assert_eq(GFVariantData.get_option_int(report, "missing_event_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "added_event_count"), 1)
	assert_almost_eq(InputMap.action_get_deadzone(_APPLY_ACTION), 0.8, 0.001)
	assert_eq(_count_key_events(_APPLY_ACTION, KEY_A), 1)
	assert_eq(_count_key_events(_APPLY_ACTION, KEY_B), 1)
	assert_eq(GFVariantData.get_option_int(second_report, "missing_event_count"), 0)
	assert_eq(GFVariantData.get_option_int(second_report, "added_event_count"), 0)
	assert_eq(_count_key_events(_APPLY_ACTION, KEY_B), 1)


func test_ensure_input_map_preset_can_update_existing_deadzone_when_requested() -> void:
	InputMap.add_action(_APPLY_ACTION, 0.8)
	var preset: Dictionary = {
		"version": GFInputMapPresetTools.PRESET_VERSION,
		"actions": [
			{
				"action_id": String(_APPLY_ACTION),
				"deadzone": 0.2,
				"events": [],
			},
		],
	}

	var report: Dictionary = GFInputMapPresetTools.ensure_input_map_preset(preset, {
		"add_missing_events": false,
		"update_existing_deadzone": true,
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "显式允许时应能更新已有 deadzone。")
	assert_eq(GFVariantData.get_option_int(report, "updated_deadzone_count"), 1)
	assert_almost_eq(InputMap.action_get_deadzone(_APPLY_ACTION), 0.2, 0.001)


func test_ensure_input_map_preset_can_dry_run_without_mutating_input_map() -> void:
	var preset: Dictionary = {
		"version": GFInputMapPresetTools.PRESET_VERSION,
		"actions": [
			{
				"action_id": String(_APPLY_ACTION),
				"deadzone": 0.5,
				"events": [_event_to_record(_make_key_event(KEY_K, true))],
			},
		],
	}

	var report: Dictionary = GFInputMapPresetTools.ensure_input_map_preset(preset, {
		"dry_run": true,
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "dry-run 有效预设应返回成功诊断。")
	assert_true(GFVariantData.get_option_bool(report, "dry_run"))
	assert_eq(GFVariantData.get_option_int(report, "missing_action_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "missing_event_count"), 1)
	assert_eq(GFVariantData.get_option_int(report, "created_count"), 0)
	assert_eq(GFVariantData.get_option_int(report, "added_event_count"), 0)
	assert_false(InputMap.has_action(_APPLY_ACTION), "dry-run 不应创建动作。")


func test_ensure_input_map_preset_is_all_or_nothing_for_invalid_event_records() -> void:
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

	var report: Dictionary = GFInputMapPresetTools.ensure_input_map_preset(preset)

	assert_false(GFVariantData.get_option_bool(report, "ok"), "任一事件非法时整批确保应失败。")
	assert_eq(GFVariantData.get_option_int(report, "created_count"), 0)
	assert_false(InputMap.has_action(_CAPTURE_ACTION), "事务失败时前面的有效动作也不应被创建。")
	assert_false(InputMap.has_action(_APPLY_ACTION), "事务失败时非法动作不应被创建。")


func test_ensure_input_map_preset_rejects_out_of_range_deadzone_without_mutation() -> void:
	var preset: Dictionary = {
		"version": GFInputMapPresetTools.PRESET_VERSION,
		"actions": [{
			"action_id": String(_APPLY_ACTION),
			"deadzone": 1.25,
			"events": [_event_to_record(_make_key_event(KEY_B, true))],
		}],
	}

	var report: Dictionary = GFInputMapPresetTools.ensure_input_map_preset(preset)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "越界 deadzone 应拒绝整批确保。")
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "invalid_deadzone")
	assert_false(InputMap.has_action(_APPLY_ACTION), "校验失败不得创建动作。")


func test_ensure_input_map_preset_rejects_unsupported_version() -> void:
	var preset: Dictionary = {
		"version": GFInputMapPresetTools.PRESET_VERSION + 1,
		"actions": [
			{
				"action_id": String(_APPLY_ACTION),
				"deadzone": 0.5,
				"events": [_event_to_record(_make_key_event(KEY_H, true))],
			},
		],
	}

	var report: Dictionary = GFInputMapPresetTools.ensure_input_map_preset(preset)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "版本不匹配的 preset 不应被确保。")
	assert_eq(GFVariantData.get_option_string(issue, "kind"), "unsupported_version")
	assert_false(InputMap.has_action(_APPLY_ACTION), "版本不匹配时不应创建动作。")


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


func _count_key_events(action_id: StringName, key: Key) -> int:
	if not InputMap.has_action(action_id):
		return 0

	var count: int = 0
	for event_value: Variant in InputMap.action_get_events(action_id):
		if event_value is InputEventKey:
			var input_event: InputEventKey = event_value
			if input_event.physical_keycode == key:
				count += 1
	return count
