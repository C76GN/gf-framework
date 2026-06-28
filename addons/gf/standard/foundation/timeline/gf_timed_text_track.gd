## GFTimedTextTrack: 通用时间段文本轨道。
##
## 管理一组按时间查询的 `GFTimedTextEntry`，不绑定字幕格式或具体 UI。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFTimedTextTrack
extends Resource


# --- 导出变量 ---

## 轨道标识。
## [br]
## @api public
@export var track_id: StringName = &""

## 时间段文本条目列表。
## [br]
## @api public
@export var entries: Array[GFTimedTextEntry] = []

## 可选元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary extension metadata for the timed text track.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 添加时间段文本条目。
## [br]
## @api public
## [br]
## @param start_time: 开始时间，单位秒。
## [br]
## @param end_time: 结束时间，单位秒。
## [br]
## @param text: 文本内容。
## [br]
## @param entry_metadata: 条目元数据。
## [br]
## @schema entry_metadata: Dictionary metadata copied into the new entry.
## [br]
## @return 新条目。
func add_entry(
	start_time: float,
	end_time: float,
	text: String,
	entry_metadata: Dictionary = {}
) -> GFTimedTextEntry:
	var entry: GFTimedTextEntry = GFTimedTextEntry.new()
	entry.start_time = _normalize_time_seconds(start_time)
	entry.end_time = maxf(_normalize_time_seconds(end_time), entry.start_time)
	entry.text = text
	entry.metadata = entry_metadata.duplicate(true)
	entries.append(entry)
	return entry


## 清空轨道。
## [br]
## @api public
func clear() -> void:
	entries.clear()


## 按开始时间排序条目。
## [br]
## @api public
func sort_entries() -> void:
	var sequence_by_instance_id: Dictionary = _make_entry_sequence_lookup()
	entries.sort_custom(func(left: GFTimedTextEntry, right: GFTimedTextEntry) -> bool:
		if left == null:
			return false
		if right == null:
			return true
		if is_equal_approx(left.start_time, right.start_time):
			if is_equal_approx(left.end_time, right.end_time):
				return _get_entry_sequence(left, sequence_by_instance_id) < _get_entry_sequence(right, sequence_by_instance_id)
			return left.end_time < right.end_time
		return left.start_time < right.start_time
	)


## 获取指定时间的第一条文本条目。
## [br]
## @api public
## [br]
## @param time_seconds: 时间，单位秒。
## [br]
## @return 命中的条目；没有命中时返回 null。
func get_entry_at_time(time_seconds: float) -> GFTimedTextEntry:
	for entry: GFTimedTextEntry in entries:
		if entry != null and entry.contains_time(time_seconds):
			return entry
	return null


## 获取指定时间的文本。
## [br]
## @api public
## [br]
## @param time_seconds: 时间，单位秒。
## [br]
## @param default_text: 没有命中时返回的文本。
## [br]
## @return 文本内容。
func get_text_at_time(time_seconds: float, default_text: String = "") -> String:
	var entry: GFTimedTextEntry = get_entry_at_time(time_seconds)
	return entry.text if entry != null else default_text


## 获取与时间范围相交的条目。
## [br]
## @api public
## [br]
## @param range_start: 范围开始时间。
## [br]
## @param range_end: 范围结束时间。
## [br]
## @return 条目列表。
func get_entries_in_range(range_start: float, range_end: float) -> Array[GFTimedTextEntry]:
	var result: Array[GFTimedTextEntry] = []
	var start_time: float = minf(range_start, range_end)
	var end_time: float = maxf(range_start, range_end)
	for entry: GFTimedTextEntry in entries:
		if entry != null and entry.intersects_range(start_time, end_time):
			result.append(entry)
	return result


## 获取轨道总时长。
## [br]
## @api public
## [br]
## @return 最大结束时间。
func get_total_duration() -> float:
	var duration: float = 0.0
	for entry: GFTimedTextEntry in entries:
		if entry != null:
			duration = maxf(duration, entry.end_time)
	return duration


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新轨道。
func duplicate_track() -> GFTimedTextTrack:
	var track: GFTimedTextTrack = GFTimedTextTrack.new()
	track.track_id = track_id
	track.metadata = metadata.duplicate(true)
	for entry: GFTimedTextEntry in entries:
		track.entries.append(entry.duplicate_entry() if entry != null else null)
	return track


## 转换为字典。
## [br]
## @api public
## [br]
## @return 轨道字典。
## [br]
## @schema return: Dictionary serialized timed text track.
func to_dictionary() -> Dictionary:
	var entry_data: Array[Dictionary] = []
	for entry: GFTimedTextEntry in entries:
		if entry != null:
			entry_data.append(entry.to_dictionary())
	return {
		"track_id": track_id,
		"entries": entry_data,
		"metadata": metadata.duplicate(true),
	}


## 应用字典数据。
## [br]
## @api public
## [br]
## @param data: 字典数据。
## [br]
## @schema data: Dictionary serialized timed text track.
func apply_dictionary(data: Dictionary) -> void:
	track_id = GFVariantData.get_option_string_name(data, "track_id", track_id)
	entries.clear()
	var raw_entries: Array = GFVariantData.as_array(GFVariantData.get_option_value(data, "entries", []))
	for raw_entry: Variant in raw_entries:
		if raw_entry is Dictionary:
			var entry: GFTimedTextEntry = GFTimedTextEntry.new()
			entry.apply_dictionary(GFVariantData.as_dictionary(raw_entry))
			entries.append(entry)
	var raw_metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(data, "metadata", {}))
	metadata = raw_metadata.duplicate(true)
	sort_entries()


# --- 私有/辅助方法 ---

static func _normalize_time_seconds(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return maxf(value, 0.0)


func _make_entry_sequence_lookup() -> Dictionary:
	var result: Dictionary = {}
	for index: int in range(entries.size()):
		var entry: GFTimedTextEntry = entries[index]
		if entry != null:
			result[entry.get_instance_id()] = index
	return result


func _get_entry_sequence(entry: GFTimedTextEntry, sequence_by_instance_id: Dictionary) -> int:
	return GFVariantData.get_option_int(sequence_by_instance_id, entry.get_instance_id(), 0)
