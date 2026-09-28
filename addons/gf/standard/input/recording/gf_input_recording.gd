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

## 录制内部用于同一时间戳事件稳定排序的顺序索引键。
## [br]
## @api private
## [br]
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

## 事件列表只读快照。每项包含 time_seconds、action_id、value、player_index、source_id 和 metadata。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema events: Array，包含 time_seconds: float、action_id: StringName、value: Variant、player_index: int、source_id: StringName 和 metadata: Dictionary 的 Dictionary 条目。
var events: Array[Dictionary]:
	get:
		return get_events()

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目持有的录制标签、工具或存档数据。
var metadata: Dictionary = {}


# --- 私有变量 ---

## 新增事件将使用的下一个稳定顺序索引。
## [br]
## @api private
## [br]
var _next_event_order_index: int = 0

## 按时间和顺序索引排列的内部事件记录。
## [br]
## @api private
## [br]
var _events: Array[Dictionary] = []


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
		"time_seconds": _normalize_time_seconds(time_seconds),
		"action_id": action_id,
		"value": GFVariantData.duplicate_variant(value),
		"player_index": player_index,
		"source_id": source_id,
		"metadata": event_metadata.duplicate(true),
		_ORDER_INDEX_KEY: _next_event_order_index,
	}
	_next_event_order_index += 1
	_add_event_sorted(event)
	duration_seconds = maxf(duration_seconds, _get_event_time_seconds(event))
	return _event_to_dict(event, false)


## 清空录制。
## [br]
## @api public
func clear() -> void:
	_events.clear()
	duration_seconds = 0.0
	_next_event_order_index = 0


## 检查录制是否为空。
## [br]
## @api public
## [br]
## @return 为空时返回 true。
func is_empty() -> bool:
	return _events.is_empty()


## 获取事件数量。
## [br]
## @api public
## [br]
## @return 事件数量。
func get_event_count() -> int:
	return _events.size()


## 按事件时间排序。
## [br]
## @api public
func sort_events() -> void:
	for index: int in range(_events.size()):
		_events[index]["time_seconds"] = _normalize_time_seconds(_get_event_time_seconds(_events[index]))
		_events[index][_ORDER_INDEX_KEY] = index
	_events.sort_custom(_sort_recording_events)
	_next_event_order_index = _events.size()
	duration_seconds = maxf(_normalize_time_seconds(duration_seconds), _get_max_event_time_seconds())


## 获取事件副本。
## [br]
## @api public
## [br]
## @schema return: Array，包含 time_seconds、action_id、value、player_index、source_id 和 metadata 的 Dictionary 条目。
## [br]
## @return 事件副本数组。
func get_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in _events:
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
	for event: Dictionary in _events:
		serialized_events.append(_event_to_dict(event, json_compatible))

	return {
		"recording_id": String(recording_id),
		"duration_seconds": _normalize_time_seconds(duration_seconds),
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
	var serialized_duration: float = _normalize_time_seconds(GFVariantData.get_option_float(data, "duration_seconds"))
	_events.clear()
	_next_event_order_index = 0
	for event_value: Variant in GFVariantData.get_option_array(data, "events"):
		if event_value is Dictionary:
			var event_data: Dictionary = event_value
			var event: Dictionary = _event_from_dict(event_data, json_compatible)
			event[_ORDER_INDEX_KEY] = _next_event_order_index
			_next_event_order_index += 1
			_events.append(event)

	var metadata_value: Variant = GFVariantData.get_option_value(data, "metadata", {})
	metadata_value = GFVariantJsonCodec.json_compatible_to_variant(metadata_value) if json_compatible else GFVariantData.duplicate_variant(metadata_value)
	metadata = GFVariantData.as_dictionary(metadata_value)
	sort_events()
	duration_seconds = maxf(serialized_duration, _get_max_event_time_seconds())


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

## 尝试通过当前实例脚本构造同类录制并收窄类型；脚本或结果不可用时退回 GFInputRecording。
## [br]
## @api private
## [br]
func _new_recording_instance() -> GFInputRecording:
	var recording_script: Script = _variant_to_script(get_script())
	if recording_script != null:
		var recording: GFInputRecording = _variant_to_recording(recording_script.call("new"))
		if recording != null:
			return recording
	return GFInputRecording.new()


## 将事件追加到已排序列表末尾；若它应排在已有事件之前，则通过二分定位插入位置。
## [br]
## @api private
## [br]
func _add_event_sorted(event: Dictionary) -> void:
	if _events.is_empty():
		_events.append(event)
		return

	var last_event: Dictionary = _events[_events.size() - 1]
	if not _sort_recording_events(event, last_event):
		_events.append(event)
		return

	var insert_index: int = _find_event_insert_index(event)
	var _insert_result: Variant = _events.insert(insert_index, event)


## 使用二分查找确定事件在当前列表中的排序插入索引。
## [br]
## @api private
## [br]
func _find_event_insert_index(event: Dictionary) -> int:
	var low: int = 0
	var high: int = _events.size()
	while low < high:
		var middle: int = floori(float(low + high) * 0.5)
		var current_event: Dictionary = _events[middle]
		if _sort_recording_events(event, current_event):
			high = middle
		else:
			low = middle + 1
	return low


## 将 Variant 收窄为 Script；类型不匹配时返回 null。
## [br]
## @api private
## [br]
func _variant_to_script(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


## 将 Variant 收窄为 GFInputRecording；类型不匹配时返回 null。
## [br]
## @api private
## [br]
func _variant_to_recording(value: Variant) -> GFInputRecording:
	if value is GFInputRecording:
		var recording: GFInputRecording = value
		return recording
	return null


## 将内部事件映射为公开字典，并按 json_compatible 选择值与元数据的 JSON 转换或 Variant 复制路径。
## [br]
## @api private
## [br]
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


## 从公开事件字典构建内部事件记录，规范化时间并按 json_compatible 转换值与元数据。
## [br]
## @api private
## [br]
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
		"time_seconds": _normalize_time_seconds(_get_event_time_seconds(event)),
		"action_id": _get_event_action_id(event),
		"value": value,
		"player_index": _get_event_player_index(event),
		"source_id": _get_event_source_id(event),
		"metadata": GFVariantData.as_dictionary(event_metadata),
	}


## 按事件时间升序比较；时间相同时按内部顺序索引升序排列。
## [br]
## @api private
## [br]
func _sort_recording_events(left: Dictionary, right: Dictionary) -> bool:
	var left_time: float = _get_event_time_seconds(left)
	var right_time: float = _get_event_time_seconds(right)
	if left_time < right_time:
		return true
	if left_time > right_time:
		return false
	return _get_event_order_index(left) < _get_event_order_index(right)


## 读取事件时间并转换为 float。
## [br]
## @api private
## [br]
func _get_event_time_seconds(event: Dictionary) -> float:
	return GFVariantData.get_option_float(event, "time_seconds")


## 读取事件动作标识并转换为 StringName。
## [br]
## @api private
## [br]
func _get_event_action_id(event: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(event, "action_id")


## 读取事件的 value Variant。
## [br]
## @api private
## [br]
func _get_event_value(event: Dictionary) -> Variant:
	return GFVariantData.get_option_value(event, "value")


## 读取事件玩家索引；缺少字段时返回 -1。
## [br]
## @api private
## [br]
func _get_event_player_index(event: Dictionary) -> int:
	return GFVariantData.get_option_int(event, "player_index", -1)


## 读取事件来源标识并转换为 StringName。
## [br]
## @api private
## [br]
func _get_event_source_id(event: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(event, "source_id")


## 读取事件元数据并转换为 Dictionary。
## [br]
## @api private
## [br]
func _get_event_metadata(event: Dictionary) -> Dictionary:
	return GFVariantData.get_option_dictionary(event, "metadata")


## 读取事件的内部排序索引。
## [br]
## @api private
## [br]
func _get_event_order_index(event: Dictionary) -> int:
	return GFVariantData.get_option_int(event, _ORDER_INDEX_KEY)


## 扫描内部事件并返回最大的事件时间；空列表时从 0 开始返回。
## [br]
## @api private
## [br]
func _get_max_event_time_seconds() -> float:
	var result: float = 0.0
	for event: Dictionary in _events:
		result = maxf(result, _get_event_time_seconds(event))
	return result


## 将事件时间规范为有限非负值；NaN、无穷值转换为 0。
## [br]
## @api private
## [br]
func _normalize_time_seconds(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return maxf(value, 0.0)
