## GFReplayTimeline: 通用回放时间线。
##
## 按时间保存命令、输入、快照或项目自定义事件的纯数据记录，便于测试、
## 诊断、重放和工具链串联。它只负责排序、查询、合并和序列化，不执行事件。
## [br]
## @api public
## [br]
## @category domain_model
## [br]
## @since 3.20.0
class_name GFReplayTimeline
extends RefCounted


# --- 常量 ---

## 通用命令事件类型。
## [br]
## @api public
const EVENT_COMMAND: StringName = &"command"

## 通用输入事件类型。
## [br]
## @api public
const EVENT_INPUT: StringName = &"input"

## 通用状态快照事件类型。
## [br]
## @api public
const EVENT_SNAPSHOT: StringName = &"snapshot"


# --- 公共变量 ---

## 时间线标识。
## [br]
## @api public
var timeline_id: StringName = &""

## 时间线总时长，单位秒。
## [br]
## @api public
var duration_seconds: float = 0.0

## 事件列表。每项包含 time_seconds、event_kind、sequence、payload 和 metadata。
## [br]
## @api public
## [br]
## @since 3.20.0
## [br]
## @schema events: Array[Dictionary]，包含 time_seconds: float、event_kind: StringName、sequence: int、payload: Variant 和 metadata: Dictionary。
var events: Array[Dictionary] = []

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，项目持有的录制、诊断或工具数据。
var metadata: Dictionary = {}


# --- 私有变量 ---

var _next_event_sequence: int = 0


# --- 公共方法 ---

## 添加通用事件。
## [br]
## @api public
## [br]
## @param time_seconds: 事件时间，单位秒。
## [br]
## @param event_kind: 事件类型。
## [br]
## @param payload: 事件载荷。
## [br]
## @param event_metadata: 事件元数据。
## [br]
## @return 新增事件字典。
## [br]
## @schema payload: Variant，命令、输入、快照或项目自定义纯数据。
## [br]
## @schema event_metadata: Dictionary，复制到当前事件中供项目诊断或工具使用。
## [br]
## @schema return: Dictionary，包含 time_seconds、event_kind、payload 和 metadata。
func add_event(
	time_seconds: float,
	event_kind: StringName,
	payload: Variant = null,
	event_metadata: Dictionary = {}
) -> Dictionary:
	var event: Dictionary = _make_event(time_seconds, event_kind, payload, event_metadata)
	_append_event_unsorted(event)
	sort_events()
	return event.duplicate(true)


## 添加通用命令事件。
## [br]
## @api public
## [br]
## @param time_seconds: 事件时间，单位秒。
## [br]
## @param command_payload: 命令载荷。
## [br]
## @param event_metadata: 事件元数据。
## [br]
## @return 新增事件字典。
## [br]
## @schema command_payload: Variant，通常为命令快照或命令 ID 与参数字典。
## [br]
## @schema event_metadata: Dictionary，复制到当前事件中供项目诊断或工具使用。
## [br]
## @schema return: Dictionary，包含 time_seconds、event_kind、payload 和 metadata。
func add_command(
	time_seconds: float,
	command_payload: Variant,
	event_metadata: Dictionary = {}
) -> Dictionary:
	return add_event(time_seconds, EVENT_COMMAND, command_payload, event_metadata)


## 添加通用输入事件。
## [br]
## @api public
## [br]
## @param time_seconds: 事件时间，单位秒。
## [br]
## @param input_payload: 输入载荷。
## [br]
## @param event_metadata: 事件元数据。
## [br]
## @return 新增事件字典。
## [br]
## @schema input_payload: Variant，通常为抽象动作输入事件字典。
## [br]
## @schema event_metadata: Dictionary，复制到当前事件中供项目诊断或工具使用。
## [br]
## @schema return: Dictionary，包含 time_seconds、event_kind、payload 和 metadata。
func add_input(
	time_seconds: float,
	input_payload: Variant,
	event_metadata: Dictionary = {}
) -> Dictionary:
	return add_event(time_seconds, EVENT_INPUT, input_payload, event_metadata)


## 添加通用快照事件。
## [br]
## @api public
## [br]
## @param time_seconds: 事件时间，单位秒。
## [br]
## @param snapshot_payload: 快照载荷。
## [br]
## @param event_metadata: 事件元数据。
## [br]
## @return 新增事件字典。
## [br]
## @schema snapshot_payload: Variant，通常为状态快照字典。
## [br]
## @schema event_metadata: Dictionary，复制到当前事件中供项目诊断或工具使用。
## [br]
## @schema return: Dictionary，包含 time_seconds、event_kind、payload 和 metadata。
func add_snapshot(
	time_seconds: float,
	snapshot_payload: Variant,
	event_metadata: Dictionary = {}
) -> Dictionary:
	return add_event(time_seconds, EVENT_SNAPSHOT, snapshot_payload, event_metadata)


## 合并另一条时间线。
## [br]
## @api public
## [br]
## @param timeline: 要合并的时间线。
## [br]
## @param time_offset: 合并时追加的时间偏移。
## [br]
## @param kind_filter: 可选事件类型过滤；为空时合并全部事件。
## [br]
## @return 合并的事件数量。
func append_timeline(
	timeline: RefCounted,
	time_offset: float = 0.0,
	kind_filter: PackedStringArray = PackedStringArray()
) -> int:
	if timeline == null or not ("events" in timeline):
		return 0
	var source_events: Array = _get_timeline_events(timeline)
	if source_events.is_empty():
		return 0

	var appended: int = 0
	var filter: Dictionary = {}
	for kind_text: String in kind_filter:
		filter[StringName(kind_text)] = true

	for event_value: Variant in source_events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		var event_kind: StringName = _get_event_kind(event)
		if not filter.is_empty() and not filter.has(event_kind):
			continue
		var event_metadata: Dictionary = GFVariantData.to_dictionary(GFVariantData.get_option_value(event, "metadata", {}))
		var appended_event: Dictionary = _make_event(
			_get_event_time(event) + time_offset,
			event_kind,
			GFVariantData.get_option_value(event, "payload"),
			event_metadata
		)
		_append_event_unsorted(appended_event)
		appended += 1
	if appended > 0:
		sort_events()
	return appended


## 清空时间线。
## [br]
## @api public
func clear() -> void:
	events.clear()
	duration_seconds = 0.0
	_next_event_sequence = 0


## 检查时间线是否为空。
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
	for event: Dictionary in events:
		_assign_restored_event_sequence(event)
	events.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_time: float = _get_event_time(left)
		var right_time: float = _get_event_time(right)
		if is_equal_approx(left_time, right_time):
			return _get_event_sequence(left) < _get_event_sequence(right)
		return left_time < right_time
	)


## 获取事件副本。
## [br]
## @api public
## [br]
## @return 事件副本数组。
## [br]
## @schema return: Array[Dictionary]，包含 time_seconds、event_kind、payload 和 metadata。
func get_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		result.append(event.duplicate(true))
	return result


## 获取指定类型事件。
## [br]
## @api public
## [br]
## @param event_kind: 事件类型。
## [br]
## @return 事件副本数组。
## [br]
## @schema return: Array[Dictionary]，包含 time_seconds、event_kind、payload 和 metadata。
func get_events_by_kind(event_kind: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		if _get_event_kind(event) == event_kind:
			result.append(event.duplicate(true))
	return result


## 获取与时间范围相交的事件。
## [br]
## @api public
## [br]
## @param range_start: 范围开始时间。
## [br]
## @param range_end: 范围结束时间。
## [br]
## @param inclusive_end: 为 true 时包含结束时间边界。
## [br]
## @return 事件副本数组。
## [br]
## @schema return: Array[Dictionary]，包含 time_seconds、event_kind、payload 和 metadata。
func get_events_in_range(
	range_start: float,
	range_end: float,
	inclusive_end: bool = false
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start_time: float = minf(range_start, range_end)
	var end_time: float = maxf(range_start, range_end)
	for event: Dictionary in events:
		var event_time: float = _get_event_time(event)
		var inside: bool = event_time >= start_time and event_time < end_time
		if inclusive_end:
			inside = event_time >= start_time and event_time <= end_time
		if inside:
			result.append(event.duplicate(true))
	return result


## 复制时间线。
## [br]
## @api public
## [br]
## @return 新时间线。
func duplicate_timeline() -> RefCounted:
	var timeline: GFReplayTimeline = GFReplayTimeline.new()
	timeline.apply_dictionary(to_dictionary())
	return timeline


## 转换为字典。
## [br]
## @api public
## [br]
## @param json_compatible: 为 true 时会把 payload 与 metadata 转换为 JSON 兼容值。
## [br]
## @return 时间线字典。
## [br]
## @schema return: Dictionary，包含 timeline_id、duration_seconds、events 和 metadata。
func to_dictionary(json_compatible: bool = false) -> Dictionary:
	var serialized_events: Array[Dictionary] = []
	for event: Dictionary in events:
		serialized_events.append(_event_to_dictionary(event, json_compatible))
	return {
		"timeline_id": String(timeline_id),
		"duration_seconds": duration_seconds,
		"events": serialized_events,
		"metadata": GFVariantJsonCodec.variant_to_json_compatible(metadata) if json_compatible else metadata.duplicate(true),
	}


## 应用字典数据。
## [br]
## @api public
## [br]
## @param data: 时间线字典。
## [br]
## @param json_compatible: 为 true 时会先恢复类型化 JSON 值。
## [br]
## @schema data: Dictionary，包含 timeline_id、duration_seconds、events 和 metadata。
func apply_dictionary(data: Dictionary, json_compatible: bool = false) -> void:
	timeline_id = GFVariantData.get_option_string_name(data, "timeline_id")
	duration_seconds = maxf(GFVariantData.get_option_float(data, "duration_seconds"), 0.0)
	events.clear()
	_next_event_sequence = 0
	var max_event_time: float = 0.0
	var serialized_events: Array = GFVariantData.get_option_array(data, "events")
	for event_value: Variant in serialized_events:
		if event_value is Dictionary:
			var event_dictionary: Dictionary = event_value
			var restored_event: Dictionary = _event_from_dictionary(event_dictionary, json_compatible)
			_assign_restored_event_sequence(restored_event)
			max_event_time = maxf(max_event_time, _get_event_time(restored_event))
			events.append(restored_event)

	var metadata_value: Variant = GFVariantData.get_option_value(data, "metadata", {})
	metadata_value = GFVariantJsonCodec.json_compatible_to_variant(metadata_value) if json_compatible else GFVariantData.duplicate_variant(metadata_value)
	metadata = GFVariantData.to_dictionary(metadata_value)
	duration_seconds = maxf(duration_seconds, max_event_time)
	sort_events()


## 从字典创建时间线。
## [br]
## @api public
## [br]
## @param data: 时间线字典。
## [br]
## @param json_compatible: 为 true 时会先恢复类型化 JSON 值。
## [br]
## @return 时间线。
## [br]
## @schema data: Dictionary，包含 timeline_id、duration_seconds、events 和 metadata。
static func from_dictionary(data: Dictionary, json_compatible: bool = false) -> RefCounted:
	var timeline: GFReplayTimeline = GFReplayTimeline.new()
	timeline.apply_dictionary(data, json_compatible)
	return timeline


# --- 私有/辅助方法 ---

func _make_event(
	time_seconds: float,
	event_kind: StringName,
	payload: Variant,
	event_metadata: Dictionary
) -> Dictionary:
	var clamped_time: float = maxf(time_seconds, 0.0)
	return {
		"time_seconds": clamped_time,
		"event_kind": event_kind,
		"sequence": _take_event_sequence(),
		"payload": GFVariantData.duplicate_variant(payload),
		"metadata": event_metadata.duplicate(true),
	}


func _append_event_unsorted(event: Dictionary) -> void:
	events.append(event)
	duration_seconds = maxf(duration_seconds, _get_event_time(event))


func _event_to_dictionary(event: Dictionary, json_compatible: bool) -> Dictionary:
	return {
		"time_seconds": _get_event_time(event),
		"event_kind": _get_event_kind_text(event),
		"sequence": _get_event_sequence(event),
		"payload": GFVariantJsonCodec.variant_to_json_compatible(GFVariantData.get_option_value(event, "payload")) if json_compatible else GFVariantData.duplicate_variant(GFVariantData.get_option_value(event, "payload")),
		"metadata": GFVariantJsonCodec.variant_to_json_compatible(GFVariantData.get_option_value(event, "metadata", {})) if json_compatible else GFVariantData.duplicate_variant(GFVariantData.get_option_value(event, "metadata", {})),
	}


func _event_from_dictionary(event: Dictionary, json_compatible: bool) -> Dictionary:
	var payload: Variant = GFVariantData.get_option_value(event, "payload")
	payload = GFVariantJsonCodec.json_compatible_to_variant(payload) if json_compatible else GFVariantData.duplicate_variant(payload)
	var event_metadata: Variant = GFVariantData.get_option_value(event, "metadata", {})
	event_metadata = GFVariantJsonCodec.json_compatible_to_variant(event_metadata) if json_compatible else GFVariantData.duplicate_variant(event_metadata)
	return {
		"time_seconds": maxf(_get_event_time(event), 0.0),
		"event_kind": _get_event_kind(event),
		"sequence": GFVariantData.get_option_int(event, "sequence", -1),
		"payload": payload,
		"metadata": GFVariantData.to_dictionary(event_metadata),
	}


func _get_timeline_events(timeline: RefCounted) -> Array:
	var value: Variant = _get_object_property(timeline, "events")
	if value is Array:
		var timeline_events: Array = value
		return timeline_events
	return []


func _get_event_time(event: Dictionary) -> float:
	return GFVariantData.get_option_float(event, "time_seconds")


func _get_event_kind(event: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(event, "event_kind")


func _get_event_kind_text(event: Dictionary) -> String:
	return GFVariantData.get_option_string(event, "event_kind")


func _get_event_sequence(event: Dictionary) -> int:
	return GFVariantData.get_option_int(event, "sequence", 0)


func _take_event_sequence() -> int:
	var event_sequence: int = _next_event_sequence
	_next_event_sequence += 1
	return event_sequence


func _assign_restored_event_sequence(event: Dictionary) -> void:
	var event_sequence: int = GFVariantData.get_option_int(event, "sequence", -1)
	if event_sequence < 0:
		event["sequence"] = _take_event_sequence()
		return
	_next_event_sequence = maxi(_next_event_sequence, event_sequence + 1)


func _get_object_property(target: Object, property_name: String) -> Variant:
	if target == null or property_name.is_empty():
		return null
	return target.get_indexed(NodePath(property_name))
