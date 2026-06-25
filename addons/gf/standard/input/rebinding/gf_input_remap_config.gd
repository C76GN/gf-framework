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
	if binding_index < 0:
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
## @schema return: Dictionary，包含 remapped_events 和 custom_data；remapped_events 为 context_id -> action_id -> binding_index -> event record。
## [br]
## @return 重映射配置字典。
func to_dict() -> Dictionary:
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
		"custom_data": GFVariantData.duplicate_variant(custom_data),
	}


## 应用由 to_dict() 生成的重映射配置。
## [br]
## @api public
## [br]
## @param data: 重映射配置字典。
## [br]
## @schema data: Dictionary，包含 remapped_events 和 custom_data。
func apply_dict(data: Dictionary) -> void:
	remapped_events.clear()
	var serialized_events: Dictionary = GFVariantData.get_option_dictionary(data, "remapped_events")
	for context_key: Variant in serialized_events.keys():
		var context_map: Dictionary = _get_dictionary_reference(serialized_events, context_key)
		if context_map.is_empty():
			continue

		var context_id: StringName = GFVariantData.to_string_name(context_key)
		for action_key: Variant in context_map.keys():
			var action_map: Dictionary = _get_dictionary_reference(context_map, action_key)
			if action_map.is_empty():
				continue

			var action_id: StringName = GFVariantData.to_string_name(action_key)
			for binding_key: Variant in action_map.keys():
				var binding_index: int = GFVariantData.to_int(binding_key, -1)
				if binding_index < 0:
					continue
				var record: Dictionary = _get_dictionary_reference(action_map, binding_key)
				if record.is_empty():
					continue
				if GFVariantData.get_option_bool(record, "unbound"):
					unbind(context_id, action_id, binding_index)
				else:
					var input_event: InputEvent = _event_from_record(record)
					if input_event != null:
						set_binding(context_id, action_id, binding_index, input_event)

	custom_data = GFVariantData.get_option_dictionary(data, "custom_data")


## 从 Dictionary 创建重映射配置。
## [br]
## @api public
## [br]
## @param data: 重映射配置字典。
## [br]
## @schema data: Dictionary，包含 remapped_events 和 custom_data。
## [br]
## @return 新重映射配置。
static func from_dict(data: Dictionary) -> GFInputRemapConfig:
	var config: GFInputRemapConfig = GFInputRemapConfig.new()
	config.apply_dict(data)
	return config


## 复制重映射配置。
## [br]
## @api public
## [br]
## @return 深拷贝后的重映射配置。
func duplicate_config() -> GFInputRemapConfig:
	return GFInputRemapConfig.from_dict(to_dict())


# --- 私有/辅助方法 ---

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
