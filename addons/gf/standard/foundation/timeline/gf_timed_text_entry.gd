## GFTimedTextEntry: 通用时间段文本条目。
##
## 表示一段开始时间、结束时间和文本，可用于字幕、对白、提示或时间轴注释。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFTimedTextEntry
extends Resource


# --- 导出变量 ---

## 开始时间，单位秒。
## [br]
## @api public
@export var start_time: float = 0.0

## 结束时间，单位秒。
## [br]
## @api public
@export var end_time: float = 0.0

## 文本内容。
## [br]
## @api public
@export_multiline var text: String = ""

## 可选元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary extension metadata for the timed text entry.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 检查时间是否落在条目范围内。
## [br]
## @api public
## [br]
## @param time_seconds: 时间，单位秒。
## [br]
## @return 落在范围内返回 true。
func contains_time(time_seconds: float) -> bool:
	return time_seconds >= start_time and time_seconds < end_time


## 检查条目是否与时间范围相交。
## [br]
## @api public
## [br]
## @param range_start: 范围开始时间。
## [br]
## @param range_end: 范围结束时间。
## [br]
## @return 相交返回 true。
func intersects_range(range_start: float, range_end: float) -> bool:
	return end_time > range_start and start_time < range_end


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新条目。
func duplicate_entry() -> GFTimedTextEntry:
	var entry: GFTimedTextEntry = GFTimedTextEntry.new()
	entry.start_time = start_time
	entry.end_time = end_time
	entry.text = text
	entry.metadata = metadata.duplicate(true)
	return entry


## 转换为字典。
## [br]
## @api public
## [br]
## @return 条目字典。
## [br]
## @schema return: Dictionary serialized timed text entry.
func to_dictionary() -> Dictionary:
	return {
		"start_time": start_time,
		"end_time": end_time,
		"text": text,
		"metadata": metadata.duplicate(true),
	}


## 应用字典数据。
## [br]
## @api public
## [br]
## @param data: 字典数据。
## [br]
## @schema data: Dictionary serialized timed text entry.
func apply_dictionary(data: Dictionary) -> void:
	start_time = _normalize_time_seconds(GFVariantData.get_option_float(data, "start_time", start_time))
	end_time = maxf(_normalize_time_seconds(GFVariantData.get_option_float(data, "end_time", end_time)), start_time)
	text = GFVariantData.get_option_string(data, "text", text)
	var raw_metadata: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(data, "metadata", {}))
	metadata = raw_metadata.duplicate(true)


# --- 私有/辅助方法 ---

static func _normalize_time_seconds(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return maxf(value, 0.0)
