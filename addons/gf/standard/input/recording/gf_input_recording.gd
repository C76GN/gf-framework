## GFInputRecording: 抽象动作输入录制数据。
##
## 记录 action_id、时间、值、玩家索引和元数据，可交给 GFInputPlayback 通过
## GFVirtualInputSource 回放。它不读取具体设备，也不绑定任何玩法语义。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.17.0
class_name GFInputRecording
extends RefCounted


# --- 常量 ---

const _ORDER_INDEX_KEY: String = "_order_index"


# --- 公共变量 ---

## 录制标识。
## [br]
## @api public
var recording_id: StringName = &""

## 录制总时长，单位秒。
## [br]
## @api public
var duration_seconds: float = 0.0

## 事件列表。每项包含 time_seconds、action_id、value、player_index、source_id 和 metadata。
## [br]
## @api public
## [br]
## @schema events: Array，包含 time_seconds: float、action_id: StringName、value: Variant、player_index: int、source_id: StringName 和 metadata: Dictionary 的 Dictionary 条目。
var events: Array[Dictionary] = []

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目持有的录制标签、工具或存档数据。
var metadata: Dictionary = {}


# --- 私有变量 ---

var _next_event_order_index: int = 0


# --- 公共方法 ---

## 添加一个动作值事件。
## [br]
## @api public
## [br]
## @param action_id: 动作标识。
## [br]
## @param value: 动作值。
## [br]
## @param time_seconds: 事件时间，单位秒。
## [br]
## @param player_index: 玩家索引；小于 0 表示不指定。
## [br]
## @param source_id: 可选来源标识。
## [br]
## @param event_metadata: 事件元数据。
## [br]
## @schema value: Variant，要记录的动作值；常见值为 bool、float、Vector2、Vector3，或 GFVariantData 支持的项目自定义数据。
## [br]
## @schema event_metadata: Dictionary，复制到当前事件中供项目诊断或工具使用。
## [br]
## @schema return: Dictionary，包含 time_seconds、action_id、value、player_index、source_id 和 metadata。
## [br]
## @return 新增事件字典。
func add_event(
	action_id: StringName,
	value: Variant,
	time_seconds: float,
	player_index: int = -1,
	source_id: StringName = &"",
	event_metadata: Dictionary = {}
) -> Dictionary:
	var event: Dictionary = {
		"time_seconds": maxf(time_seconds, 0.0),
		"action_id": action_id,
		"value": GFVariantData.duplicate_variant(value),
		"player_index": player_index,
		"source_id": source_id,
		"metadata": event_metadata.duplicate(true),
		_ORDER_INDEX_KEY: _next_event_order_index,
	}
	_next_event_order_index += 1
	events.append(event)
	duration_seconds = maxf(duration_seconds, _get_event_time_seconds(event))
	sort_events()
	return event


## 清空录制。
## [br]
## @api public
func clear() -> void:
	events.clear()
	duration_seconds = 0.0
	_next_event_order_index = 0


## 检查录制是否为空。
## [br]
## @api public
## [br]
## @return 为空时返回 true。
func is_empty() -> bool:
	return events.is_empty()


## 获取事件数量。
## [br]
## @api public
## [br]
## @return 事件数量。
func get_event_count() -> int:
	return events.size()


## 按事件时间排序。
## [br]
## @api public
func sort_events() -> void:
	events.sort_custom(_sort_recording_events)


## 获取事件副本。
## [br]
## @api public
## [br]
## @schema return: Array，包含 time_seconds、action_id、value、player_index、source_id 和 metadata 的 Dictionary 条目。
## [br]
## @return 事件副本数组。
func get_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		result.append(_event_to_dict(event, false))
	return result


## 复制录制。
## [br]
## @api public
## [br]
## @return 新录制。
func duplicate_recording() -> GFInputRecording:
	var duplicated: GFInputRecording = _new_recording_instance()
	duplicated.apply_dict(to_dict())
	return duplicated


## 转为字典。
## [br]
## @api public
## [br]
## @param json_compatible: 为 true 时会把事件值与元数据转换为 JSON 兼容值。
## [br]
## @schema return: Dictionary，包含 recording_id: String、duration_seconds: float、events: Array[Dictionary] 和 metadata: Dictionary。
## [br]
## @return 录制字典。
func to_dict(json_compatible: bool = false) -> Dictionary:
	var serialized_events: Array[Dictionary] = []
	for event: Dictionary in events:
		serialized_events.append(_event_to_dict(event, json_compatible))

	return {
		"recording_id": String(recording_id),
		"duration_seconds": duration_seconds,
		"events": serialized_events,
		"metadata": GFVariantJsonCodec.variant_to_json_compatible(metadata) if json_compatible else metadata.duplicate(true),
	}


## 从字典恢复录制。
## [br]
## @api public
## [br]
## @param data: 录制字典。
## [br]
## @param json_compatible: 为 true 时会先恢复类型化 JSON 值。
## [br]
## @schema data: Dictionary，包含 recording_id、duration_seconds、events 和 metadata。
func apply_dict(data: Dictionary, json_compatible: bool = false) -> void:
	recording_id = GFVariantData.get_option_string_name(data, "recording_id")
	duration_seconds = maxf(GFVariantData.get_option_float(data, "duration_seconds"), 0.0)
	events.clear()
	_next_event_order_index = 0
	for event_value: Variant in GFVariantData.get_option_array(data, "events"):
		if event_value is Dictionary:
			var event_data: Dictionary = event_value
			var event: Dictionary = _event_from_dict(event_data, json_compatible)
			event[_ORDER_INDEX_KEY] = _next_event_order_index
			_next_event_order_index += 1
			events.append(event)

	var metadata_value: Variant = GFVariantData.get_option_value(data, "metadata", {})
	metadata_value = GFVariantJsonCodec.json_compatible_to_variant(metadata_value) if json_compatible else GFVariantData.duplicate_variant(metadata_value)
	metadata = GFVariantData.as_dictionary(metadata_value)
	sort_events()


## 从字典创建录制。
## [br]
## @api public
## [br]
## @param data: 录制字典。
## [br]
## @param json_compatible: 为 true 时会先恢复类型化 JSON 值。
## [br]
## @schema data: Dictionary，包含 recording_id、duration_seconds、events 和 metadata。
## [br]
## @return 录制。
static func from_dict(data: Dictionary, json_compatible: bool = false) -> GFInputRecording:
	var recording: GFInputRecording = GFInputRecording.new()
	recording.apply_dict(data, json_compatible)
	return recording


# --- 私有/辅助方法 ---

func _new_recording_instance() -> GFInputRecording:
	var recording_script: Script = _variant_to_script(get_script())
	if recording_script != null:
		var recording: GFInputRecording = _variant_to_recording(recording_script.call("new"))
		if recording != null:
			return recording
	return GFInputRecording.new()


func _variant_to_script(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


func _variant_to_recording(value: Variant) -> GFInputRecording:
	if value is GFInputRecording:
		var recording: GFInputRecording = value
		return recording
	return null


func _event_to_dict(event: Dictionary, json_compatible: bool) -> Dictionary:
	return {
		"time_seconds": _get_event_time_seconds(event),
		"action_id": String(_get_event_action_id(event)),
		"value": (
			GFVariantJsonCodec.variant_to_json_compatible(_get_event_value(event))
			if json_compatible
			else GFVariantData.duplicate_variant(_get_event_value(event))
		),
		"player_index": _get_event_player_index(event),
		"source_id": String(_get_event_source_id(event)),
		"metadata": (
			GFVariantJsonCodec.variant_to_json_compatible(_get_event_metadata(event))
			if json_compatible
			else GFVariantData.duplicate_variant(_get_event_metadata(event))
		),
	}


func _event_from_dict(event: Dictionary, json_compatible: bool) -> Dictionary:
	var value: Variant = _get_event_value(event)
	value = (
		GFVariantJsonCodec.json_compatible_to_variant(value)
		if json_compatible
		else GFVariantData.duplicate_variant(value)
	)
	var event_metadata: Variant = GFVariantData.get_option_value(event, "metadata", {})
	event_metadata = (
		GFVariantJsonCodec.json_compatible_to_variant(event_metadata)
		if json_compatible
		else GFVariantData.duplicate_variant(event_metadata)
	)
	return {
		"time_seconds": maxf(_get_event_time_seconds(event), 0.0),
		"action_id": _get_event_action_id(event),
		"value": value,
		"player_index": _get_event_player_index(event),
		"source_id": _get_event_source_id(event),
		"metadata": GFVariantData.as_dictionary(event_metadata),
	}


func _sort_recording_events(left: Dictionary, right: Dictionary) -> bool:
	var left_time: float = _get_event_time_seconds(left)
	var right_time: float = _get_event_time_seconds(right)
	if left_time < right_time:
		return true
	if left_time > right_time:
		return false
	return _get_event_order_index(left) < _get_event_order_index(right)


func _get_event_time_seconds(event: Dictionary) -> float:
	return GFVariantData.get_option_float(event, "time_seconds")


func _get_event_action_id(event: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(event, "action_id")


func _get_event_value(event: Dictionary) -> Variant:
	return GFVariantData.get_option_value(event, "value")


func _get_event_player_index(event: Dictionary) -> int:
	return GFVariantData.get_option_int(event, "player_index", -1)


func _get_event_source_id(event: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(event, "source_id")


func _get_event_metadata(event: Dictionary) -> Dictionary:
	return GFVariantData.get_option_dictionary(event, "metadata")


func _get_event_order_index(event: Dictionary) -> int:
	return GFVariantData.get_option_int(event, _ORDER_INDEX_KEY)
