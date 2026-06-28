## GFInputMapPresetTools: Godot InputMap 预设转换工具。
##
## 用于把当前运行时 InputMap 捕获为通用字典，或把字典预设应用回
## InputMap。它不负责保存文件、写入 ProjectSettings、玩家 profile 语义或 UI 流程。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
## [br]
## @layer standard/input
class_name GFInputMapPresetTools
extends RefCounted


# --- 常量 ---

## InputMap 预设格式版本。
## [br]
## @api public
## [br]
## @since 6.0.0
const PRESET_VERSION: int = 1

const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")


# --- 公共方法 ---

## 捕获当前 InputMap 为可序列化预设字典。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param options: 可选项，支持 action_ids、include_ui_actions、include_empty_actions、sort_actions、metadata。
## [br]
## @schema options: Dictionary with optional action_ids: Array[String] or PackedStringArray, include_ui_actions: bool, include_empty_actions: bool, sort_actions: bool, metadata: Dictionary.
## [br]
## @return InputMap 预设字典。
## [br]
## @schema return: Dictionary { version: int, actions: Array[Dictionary], metadata: Dictionary }. Each action has action_id, deadzone, and events.
static func capture_input_map(options: Dictionary = {}) -> Dictionary:
	var selected_action_ids: PackedStringArray = _get_action_ids_from_options(options)
	var explicit_selection: bool = not selected_action_ids.is_empty()
	var include_ui_actions: bool = GFVariantData.get_option_bool(options, "include_ui_actions", false)
	var include_empty_actions: bool = GFVariantData.get_option_bool(options, "include_empty_actions", true)
	var sort_actions: bool = GFVariantData.get_option_bool(options, "sort_actions", true)
	var action_ids: PackedStringArray = selected_action_ids if explicit_selection else _get_all_input_map_actions()
	if sort_actions:
		action_ids.sort()

	var actions: Array[Dictionary] = []
	for action_id_string: String in action_ids:
		var action_id: StringName = StringName(action_id_string)
		if action_id == &"" or not InputMap.has_action(action_id):
			continue
		if not explicit_selection and not include_ui_actions and _is_ui_action(action_id):
			continue

		var event_records: Array[Dictionary] = []
		for event_value: Variant in InputMap.action_get_events(action_id):
			var input_event: InputEvent = _INPUT_EVENT_TOOLS.get_input_event(event_value)
			if input_event != null:
				event_records.append(_INPUT_EVENT_TOOLS.input_event_to_record(input_event))
		if event_records.is_empty() and not include_empty_actions:
			continue

		actions.append({
			"action_id": String(action_id),
			"deadzone": InputMap.action_get_deadzone(action_id),
			"events": event_records,
		})

	return {
		"version": PRESET_VERSION,
		"actions": actions,
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}


## 将预设字典应用到当前 InputMap。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param preset: InputMap 预设字典。
## [br]
## @param options: 可选项，支持 action_ids、include_ui_actions、clear_existing_events。
## [br]
## @schema preset: Dictionary created by capture_input_map().
## [br]
## @schema options: Dictionary with optional action_ids: Array[String] or PackedStringArray, include_ui_actions: bool, clear_existing_events: bool.
## [br]
## @return 应用报告。
## [br]
## @schema return: Dictionary { ok: bool, applied_count: int, event_count: int, skipped_count: int, issues: Array[Dictionary] }.
static func apply_input_map_preset(preset: Dictionary, options: Dictionary = {}) -> Dictionary:
	var issues: Array[Dictionary] = []
	var report: Dictionary = {
		"ok": true,
		"applied_count": 0,
		"event_count": 0,
		"skipped_count": 0,
		"issues": issues,
	}
	var selected_action_ids: PackedStringArray = _get_action_ids_from_options(options)
	var explicit_selection: bool = not selected_action_ids.is_empty()
	var selected_lookup: Dictionary = _make_action_lookup(selected_action_ids)
	var include_ui_actions: bool = GFVariantData.get_option_bool(options, "include_ui_actions", false)
	var clear_existing_events: bool = GFVariantData.get_option_bool(options, "clear_existing_events", true)
	var actions: Array = GFVariantData.get_option_array(preset, "actions")
	var plans: Array[Dictionary] = []

	for action_value: Variant in actions:
		var action_record: Dictionary = GFVariantData.as_dictionary(action_value)
		var action_id: StringName = GFVariantData.get_option_string_name(action_record, "action_id", &"")
		if action_id == &"":
			_append_issue(issues, action_id, "invalid_action", "Action id is empty.")
			report["skipped_count"] += 1
			continue
		if explicit_selection and not selected_lookup.has(action_id):
			report["skipped_count"] += 1
			continue
		if not explicit_selection and not include_ui_actions and _is_ui_action(action_id):
			report["skipped_count"] += 1
			continue

		var deadzone: float = GFVariantData.get_option_float(action_record, "deadzone", 0.5)
		var input_events: Array[InputEvent] = []
		var event_records: Array = GFVariantData.get_option_array(action_record, "events")
		for event_record_value: Variant in event_records:
			var event_record: Dictionary = GFVariantData.as_dictionary(event_record_value)
			var input_event: InputEvent = _INPUT_EVENT_TOOLS.input_event_from_record(event_record)
			if input_event == null:
				_append_issue(issues, action_id, "invalid_event", "Input event record is invalid.")
				report["skipped_count"] += 1
				continue
			input_events.append(input_event)
		plans.append({
			"action_id": action_id,
			"deadzone": deadzone,
			"events": input_events,
		})

	if not issues.is_empty():
		report["ok"] = false
		return report

	for plan: Dictionary in plans:
		var plan_action_id: StringName = GFVariantData.get_option_string_name(plan, "action_id")
		var plan_deadzone: float = GFVariantData.get_option_float(plan, "deadzone", 0.5)
		if not InputMap.has_action(plan_action_id):
			InputMap.add_action(plan_action_id, plan_deadzone)
		else:
			InputMap.action_set_deadzone(plan_action_id, plan_deadzone)
			if clear_existing_events:
				InputMap.action_erase_events(plan_action_id)

		var plan_events: Array = GFVariantData.get_option_array(plan, "events")
		for event_value: Variant in plan_events:
			var input_event: InputEvent = _INPUT_EVENT_TOOLS.get_input_event(event_value)
			if input_event != null:
				InputMap.action_add_event(plan_action_id, input_event)
				report["event_count"] += 1
		report["applied_count"] += 1

	report["ok"] = issues.is_empty()
	return report


# --- 私有/辅助方法 ---

static func _get_all_input_map_actions() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for action_value: Variant in InputMap.get_actions():
		var action_id: StringName = GFVariantData.to_string_name(action_value)
		if action_id != &"":
			var _append_result_190: bool = result.append(String(action_id))
	return result


static func _get_action_ids_from_options(options: Dictionary) -> PackedStringArray:
	var raw_action_ids: Variant = GFVariantData.get_option_value(options, "action_ids")
	var result: PackedStringArray = PackedStringArray()
	if raw_action_ids is PackedStringArray:
		var packed_ids: PackedStringArray = raw_action_ids
		for action_id_string: String in packed_ids:
			_append_action_id(result, action_id_string)
	elif raw_action_ids is Array:
		var action_ids: Array = raw_action_ids
		for action_id_value: Variant in action_ids:
			_append_action_id(result, GFVariantData.to_text(action_id_value))
	elif raw_action_ids is String or raw_action_ids is StringName:
		_append_action_id(result, GFVariantData.to_text(raw_action_ids))
	return result


static func _append_action_id(action_ids: PackedStringArray, action_id_text: String) -> void:
	if action_id_text.is_empty() or action_ids.has(action_id_text):
		return
	var _append_result_209: bool = action_ids.append(action_id_text)


static func _make_action_lookup(action_ids: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for action_id_string: String in action_ids:
		var action_id: StringName = StringName(action_id_string)
		if action_id != &"":
			result[action_id] = true
	return result


static func _is_ui_action(action_id: StringName) -> bool:
	return String(action_id).begins_with("ui_")


static func _append_issue(
	issues: Array[Dictionary],
	action_id: StringName,
	kind: String,
	message: String
) -> void:
	issues.append({
		"action_id": action_id,
		"kind": kind,
		"message": message,
	})
