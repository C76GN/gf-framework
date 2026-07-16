## GFInputRemapConfig: 输入重映射配置。
##
## 只保存玩家或项目层覆盖过的输入事件，默认绑定仍来自 GFInputContext。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFInputRemapConfig
extends Resource


# --- 常量 ---

const _INPUT_EVENT_TOOLS = preload("res://addons/gf/standard/input/common/gf_input_event_tools.gd")


# --- 导出变量 ---

## 重绑定输入。结构为 context_id -> action_id -> binding_index -> InputEvent 或 null。
## [br]
## @api public
## [br]
## @schema remapped_events: Dictionary，按 context_id、action_id、binding_index 分层索引，值为 InputEvent 或表示显式解绑的 null。
@export var remapped_events: Dictionary = {}

## 项目自定义数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema custom_data: Dictionary，项目持有的 profile 标签、设备元数据或 UI 状态。
@export var custom_data: Dictionary = {}


# --- 公共方法 ---

## 设置绑定覆盖。
## [br]
## @api public
## [br]
## @param context_id: 上下文标识。
## [br]
## @param action_id: 动作标识。
## [br]
## @param binding_index: 绑定索引。
## [br]
## @param input_event: 新输入事件；null 表示显式解绑。
func set_binding(
	context_id: StringName,
	action_id: StringName,
	binding_index: int,
	input_event: InputEvent
) -> void:
	if context_id == &"" or action_id == &"" or binding_index < 0:
		return

	var action_map: Dictionary = _ensure_action_map(context_id, action_id)
	action_map[binding_index] = _duplicate_input_event(input_event) if input_event != null else null


## 显式解绑某个绑定。
## [br]
## @api public
## [br]
## @param context_id: 上下文标识。
## [br]
## @param action_id: 动作标识。
## [br]
## @param binding_index: 绑定索引。
func unbind(context_id: StringName, action_id: StringName, binding_index: int) -> void:
	set_binding(context_id, action_id, binding_index, null)


## 清除某个覆盖，使其回退到默认绑定。
## [br]
## @api public
## [br]
## @param context_id: 上下文标识。
## [br]
## @param action_id: 动作标识。
## [br]
## @param binding_index: 绑定索引。
func clear_binding(context_id: StringName, action_id: StringName, binding_index: int) -> void:
	if not has_binding(context_id, action_id, binding_index):
		return

	var context_key: Variant = _find_dictionary_key(remapped_events, context_id)
	var context_map: Dictionary = _get_dictionary_reference(remapped_events, context_key)
	var action_key: Variant = _find_dictionary_key(context_map, action_id)
	var action_map: Dictionary = _get_dictionary_reference(context_map, action_key)
	_erase_dictionary_key(action_map, binding_index)
	if action_map.is_empty():
		_erase_dictionary_key(context_map, action_key)
	if context_map.is_empty():
		_erase_dictionary_key(remapped_events, context_key)


## 检查是否存在覆盖记录。显式解绑也会返回 true。
## [br]
## @api public
## [br]
## @param context_id: 上下文标识。
## [br]
## @param action_id: 动作标识。
## [br]
## @param binding_index: 绑定索引。
## [br]
## @return 是否存在覆盖。
func has_binding(context_id: StringName, action_id: StringName, binding_index: int) -> bool:
	var context_map: Dictionary = _get_context_map(context_id)
	if context_map.is_empty():
		return false
	var action_map: Dictionary = _get_action_map(context_map, action_id)
	return action_map.has(binding_index)


## 获取覆盖输入事件。
## [br]
## @api public
## [br]
## @param context_id: 上下文标识。
## [br]
## @param action_id: 动作标识。
## [br]
## @param binding_index: 绑定索引。
## [br]
## @return 覆盖事件；显式解绑或未覆盖时均可能返回 null，应先调用 has_binding() 区分。
func get_bound_event_or_null(context_id: StringName, action_id: StringName, binding_index: int) -> InputEvent:
	if not has_binding(context_id, action_id, binding_index):
		return null
	var context_map: Dictionary = _get_context_map(context_id)
	var action_map: Dictionary = _get_action_map(context_map, action_id)
	return _variant_to_input_event(_get_binding_value(action_map, binding_index))


## 设置自定义数据。
## [br]
## @api public
## [br]
## @param key: 键。
## [br]
## @param value: 值。
## [br]
## @schema key: Variant，项目侧自定义数据键。
## [br]
## @schema value: Variant，项目侧自定义数据值。
func set_custom_data(key: Variant, value: Variant) -> void:
	custom_data[key] = value


## 获取自定义数据。
## [br]
## @api public
## [br]
## @param key: 键。
## [br]
## @param default_value: 默认值。
## [br]
## @schema key: Variant，项目侧自定义数据键。
## [br]
## @schema default_value: Variant，key 不存在时返回的默认值。
## [br]
## @schema return: Variant，自定义数据值或 default_value。
## [br]
## @return 自定义数据。
func get_custom_data(key: Variant, default_value: Variant = null) -> Variant:
	if custom_data.has(key):
		return custom_data[key]
	return default_value


## 转换为可写入 JSON/存档的 Dictionary。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param json_compatible: 为 true 时将 custom_data 转为 JSON 兼容值。
## [br]
## @schema return: Dictionary，包含 remapped_events 和 custom_data；remapped_events 为 context_id -> action_id -> binding_index -> event record。
## [br]
## @return 重映射配置字典。
func to_dict(json_compatible: bool = true) -> Dictionary:
	var serialized_events: Dictionary = {}
	for context_key: Variant in remapped_events.keys():
		var context_map: Dictionary = _get_dictionary_reference(remapped_events, context_key)
		if context_map.is_empty():
			continue

		var serialized_context: Dictionary = {}
		for action_key: Variant in context_map.keys():
			var action_map: Dictionary = _get_dictionary_reference(context_map, action_key)
			if action_map.is_empty():
				continue

			var serialized_action: Dictionary = {}
			for binding_key: Variant in action_map.keys():
				var binding_index: int = GFVariantData.to_int(binding_key, -1)
				if binding_index < 0:
					continue
				serialized_action[str(binding_index)] = _event_to_record(
					_variant_to_input_event(_get_binding_value(action_map, binding_key))
				)
			if not serialized_action.is_empty():
				serialized_context[GFVariantData.to_text(action_key)] = serialized_action

		if not serialized_context.is_empty():
			serialized_events[GFVariantData.to_text(context_key)] = serialized_context

	return {
		"remapped_events": serialized_events,
		"custom_data": GFVariantJsonCodec.variant_to_json_compatible(custom_data) if json_compatible else GFVariantData.duplicate_variant(custom_data),
	}


## 应用由 to_dict() 生成的重映射配置。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 重映射配置字典。
## [br]
## @param json_compatible: 为 true 时会先恢复 custom_data 的 JSON 兼容值。
## [br]
## @schema data: Dictionary，包含 remapped_events 和 custom_data。
## [br]
## @return 应用报告；任一记录无效时不修改当前配置。
## [br]
## @schema return: Dictionary with ok, committed, binding_count, bound_count, unbound_count, and issues.
func apply_dict(data: Dictionary, json_compatible: bool = true) -> Dictionary:
	var issues: Array[Dictionary] = []
	var report: Dictionary = {
		"ok": true,
		"committed": false,
		"binding_count": 0,
		"bound_count": 0,
		"unbound_count": 0,
		"issues": issues,
	}
	var serialized_events_value: Variant = GFVariantData.get_option_value(data, "remapped_events", {})
	if not (serialized_events_value is Dictionary):
		_append_apply_issue(issues, "remapped_events", "invalid_map", "remapped_events must be a Dictionary.")
		return _finish_apply_report(report, false)
	var serialized_events: Dictionary = serialized_events_value
	var candidate: GFInputRemapConfig = GFInputRemapConfig.new()
	for context_key: Variant in serialized_events.keys():
		var context_value: Variant = GFVariantData.get_option_value(serialized_events, context_key)
		var context_id: StringName = GFVariantData.to_string_name(context_key)
		var context_path: String = "remapped_events.%s" % GFVariantData.to_text(context_key)
		if context_id == &"" or not (context_value is Dictionary):
			_append_apply_issue(issues, context_path, "invalid_context", "Context id and map must be valid.")
			continue
		var context_map: Dictionary = context_value
		for action_key: Variant in context_map.keys():
			var action_value: Variant = GFVariantData.get_option_value(context_map, action_key)
			var action_id: StringName = GFVariantData.to_string_name(action_key)
			var action_path: String = "%s.%s" % [context_path, GFVariantData.to_text(action_key)]
			if action_id == &"" or not (action_value is Dictionary):
				_append_apply_issue(issues, action_path, "invalid_action", "Action id and map must be valid.")
				continue
			var action_map: Dictionary = action_value
			for binding_key: Variant in action_map.keys():
				var binding_path: String = "%s.%s" % [action_path, GFVariantData.to_text(binding_key)]
				var binding_result: Dictionary = _parse_binding_index(binding_key)
				if not GFVariantData.get_option_bool(binding_result, "ok"):
					_append_apply_issue(issues, binding_path, "invalid_binding_index", "Binding index must be a non-negative integer.")
					continue
				var binding_index: int = GFVariantData.get_option_int(binding_result, "value")
				var record_value: Variant = GFVariantData.get_option_value(action_map, binding_key)
				if not (record_value is Dictionary):
					_append_apply_issue(issues, binding_path, "invalid_record", "Binding record must be a Dictionary.")
					continue
				var record: Dictionary = record_value
				if record.is_empty():
					_append_apply_issue(issues, binding_path, "empty_record", "Binding record cannot be empty.")
					continue
				if candidate.has_binding(context_id, action_id, binding_index):
					_append_apply_issue(issues, binding_path, "duplicate_binding", "Binding index is duplicated after normalization.")
					continue
				if GFVariantData.get_option_bool(record, "unbound"):
					candidate.unbind(context_id, action_id, binding_index)
					report["unbound_count"] += 1
				else:
					var input_event: InputEvent = _event_from_record(record)
					if input_event == null:
						_append_apply_issue(issues, binding_path, "invalid_event", "Binding event record is invalid or unsupported.")
						continue
					candidate.set_binding(context_id, action_id, binding_index, input_event)
					report["bound_count"] += 1
				report["binding_count"] += 1

	var custom_data_value: Variant = GFVariantData.get_option_value(data, "custom_data", {})
	custom_data_value = GFVariantJsonCodec.json_compatible_to_variant(custom_data_value) if json_compatible else GFVariantData.duplicate_variant(custom_data_value)
	if not (custom_data_value is Dictionary):
		_append_apply_issue(issues, "custom_data", "invalid_custom_data", "custom_data must decode to a Dictionary.")
	if not issues.is_empty():
		return _finish_apply_report(report, false)

	remapped_events = candidate.remapped_events.duplicate(true)
	custom_data = GFVariantData.as_dictionary(custom_data_value).duplicate(true)
	return _finish_apply_report(report, true)


## 从 Dictionary 创建重映射配置。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 重映射配置字典。
## [br]
## @param json_compatible: 为 true 时会先恢复 custom_data 的 JSON 兼容值。
## [br]
## @schema data: Dictionary，包含 remapped_events 和 custom_data。
## [br]
## @return 新重映射配置。
static func from_dict(data: Dictionary, json_compatible: bool = true) -> GFInputRemapConfig:
	var config: GFInputRemapConfig = GFInputRemapConfig.new()
	var _apply_report: Dictionary = config.apply_dict(data, json_compatible)
	return config


## 复制重映射配置。
## [br]
## @api public
## [br]
## @return 深拷贝后的重映射配置。
func duplicate_config() -> GFInputRemapConfig:
	return GFInputRemapConfig.from_dict(to_dict(false), false)


# --- 私有/辅助方法 ---

static func _append_apply_issue(
	issues: Array[Dictionary],
	path: String,
	code: String,
	message: String
) -> void:
	issues.append({
		"path": path,
		"code": code,
		"message": message,
	})


static func _finish_apply_report(report: Dictionary, committed: bool) -> Dictionary:
	report["committed"] = committed
	report["ok"] = committed and GFVariantData.get_option_array(report, "issues").is_empty()
	return report


static func _parse_binding_index(value: Variant) -> Dictionary:
	if value is int:
		var int_value: int = value
		return { "ok": int_value >= 0, "value": int_value }
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value)
		if text.is_valid_int():
			var parsed: int = int(text)
			return { "ok": parsed >= 0, "value": parsed }
	return { "ok": false, "value": -1 }

func _ensure_action_map(context_id: StringName, action_id: StringName) -> Dictionary:
	var context_key: Variant = _find_dictionary_key(remapped_events, context_id)
	var context_map: Dictionary = {}
	if context_key != null:
		var context_value: Variant = remapped_events[context_key]
		if context_value is Dictionary:
			context_map = context_value
		else:
			remapped_events[context_key] = context_map
	else:
		remapped_events[context_id] = context_map

	var action_key: Variant = _find_dictionary_key(context_map, action_id)
	if action_key != null:
		var action_value: Variant = context_map[action_key]
		if action_value is Dictionary:
			var action_map: Dictionary = action_value
			return action_map

	var new_action_map: Dictionary = {}
	if action_key != null:
		context_map[action_key] = new_action_map
	else:
		context_map[action_id] = new_action_map
	return new_action_map


func _get_context_map(context_id: StringName) -> Dictionary:
	return _get_dictionary_reference(remapped_events, context_id)


func _get_action_map(context_map: Dictionary, action_id: StringName) -> Dictionary:
	return _get_dictionary_reference(context_map, action_id)


func _get_dictionary_reference(source: Dictionary, key: Variant) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(source, key)
	return GFVariantData.as_dictionary(value)


func _get_binding_value(action_map: Dictionary, binding_key: Variant) -> Variant:
	return GFVariantData.get_option_value(action_map, binding_key)


func _find_dictionary_key(source: Dictionary, key: Variant) -> Variant:
	if source.has(key):
		return key
	if key is StringName:
		var text_key: String = GFVariantData.to_text(key)
		if source.has(text_key):
			return text_key
	elif key is String:
		var name_key: StringName = GFVariantData.to_string_name(key)
		if source.has(name_key):
			return name_key
	return null


func _event_to_record(input_event: InputEvent) -> Dictionary:
	return _INPUT_EVENT_TOOLS.input_event_to_record(input_event)


func _event_from_record(record: Dictionary) -> InputEvent:
	return _INPUT_EVENT_TOOLS.input_event_from_record(record)


func _duplicate_input_event(input_event: InputEvent) -> InputEvent:
	return _INPUT_EVENT_TOOLS.duplicate_input_event(input_event)


func _variant_to_input_event(value: Variant) -> InputEvent:
	return _INPUT_EVENT_TOOLS.get_input_event(value)


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return
