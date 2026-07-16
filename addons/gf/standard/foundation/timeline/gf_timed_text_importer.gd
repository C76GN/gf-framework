## GFTimedTextImporter: 通用时间段文本解析器。
##
## 提供 SRT、WebVTT 与 LRC 的轻量解析入口，输出 `GFTimedTextTrack`。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFTimedTextImporter
extends RefCounted


# --- 公共方法 ---

## 解析 SRT 文本。
## [br]
## @api public
## [br]
## @param text: SRT 文本。
## [br]
## @param track_id: 可选轨道标识。
## [br]
## @return 解析结果字典，包含 success、track 与 error。
## [br]
## @schema return: Dictionary with success: bool, track: GFTimedTextTrack, error: String.
static func parse_srt(text: String, track_id: StringName = &"") -> Dictionary:
	var track: GFTimedTextTrack = GFTimedTextTrack.new()
	track.track_id = track_id
	var blocks: PackedStringArray = text.replace("\r\n", "\n").replace("\r", "\n").split("\n\n", false)
	for block: String in blocks:
		var lines: PackedStringArray = block.split("\n", false)
		if lines.size() < 2:
			continue
		var time_line_index: int = 0
		if not String(lines[0]).contains("-->") and lines.size() >= 3:
			time_line_index = 1
		var time_range: Dictionary = _parse_time_range(String(lines[time_line_index]))
		if time_range.is_empty():
			continue
		var text_lines: PackedStringArray = PackedStringArray()
		for index: int in range(time_line_index + 1, lines.size()):
			_append_packed_string(text_lines, String(lines[index]))
		var _add_entry_result_44: Variant = track.add_entry(
			GFVariantData.get_option_float(time_range, "start"),
			GFVariantData.get_option_float(time_range, "end"),
			"\n".join(text_lines)
		)
	track.sort_entries()
	if not text.strip_edges().is_empty() and track.entries.is_empty():
		return _make_result(false, track, "no_valid_entries")
	return _make_result(true, track, "")


## 解析 WebVTT 文本。
## [br]
## @api public
## [br]
## @param text: WebVTT 文本。
## [br]
## @param track_id: 可选轨道标识。
## [br]
## @return 解析结果字典，包含 success、track 与 error。
## [br]
## @schema return: Dictionary with success: bool, track: GFTimedTextTrack, error: String.
static func parse_vtt(text: String, track_id: StringName = &"") -> Dictionary:
	var normalized: String = text.replace("\r\n", "\n").replace("\r", "\n")
	if normalized.begins_with("WEBVTT"):
		var first_newline: int = normalized.find("\n")
		normalized = normalized.substr(first_newline + 1) if first_newline >= 0 else ""
	return parse_srt(normalized, track_id)


## 解析 LRC 文本。
## [br]
## @api public
## [br]
## @param text: LRC 文本。
## [br]
## @param default_duration: 单行没有下一行时使用的默认时长。
## [br]
## @param track_id: 可选轨道标识。
## [br]
## @return 解析结果字典，包含 success、track 与 error。
## [br]
## @schema return: Dictionary with success: bool, track: GFTimedTextTrack, error: String.
static func parse_lrc(
	text: String,
	default_duration: float = 2.0,
	track_id: StringName = &""
) -> Dictionary:
	var raw_entries: Array[Dictionary] = []
	var entry_sequence: int = 0
	for line: String in text.replace("\r\n", "\n").replace("\r", "\n").split("\n", false):
		var parsed_entries: Array[Dictionary] = _parse_lrc_line(line)
		for parsed: Dictionary in parsed_entries:
			parsed["sequence"] = entry_sequence
			entry_sequence += 1
			raw_entries.append(parsed)
	raw_entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_start: float = GFVariantData.get_option_float(left, "start")
		var right_start: float = GFVariantData.get_option_float(right, "start")
		if left_start == right_start:
			return GFVariantData.get_option_int(left, "sequence") < GFVariantData.get_option_int(right, "sequence")
		return left_start < right_start
	)

	var track: GFTimedTextTrack = GFTimedTextTrack.new()
	track.track_id = track_id
	for index: int in range(raw_entries.size()):
		var current: Dictionary = raw_entries[index]
		var current_start: float = GFVariantData.get_option_float(current, "start")
		var next_start: float = (
			GFVariantData.get_option_float(raw_entries[index + 1], "start")
			if index + 1 < raw_entries.size()
			else current_start + default_duration
		)
		var _add_entry_result_109: Variant = track.add_entry(current_start, next_start, GFVariantData.get_option_string(current, "text"))
	if not text.strip_edges().is_empty() and track.entries.is_empty():
		return _make_result(false, track, "no_valid_entries")
	return _make_result(true, track, "")


# --- 私有/辅助方法 ---

static func _parse_time_range(line: String) -> Dictionary:
	var parts: PackedStringArray = line.split("-->", false)
	if parts.size() < 2:
		return {}
	var start: float = _parse_timestamp(parts[0].strip_edges())
	var end: float = _parse_timestamp(parts[1].strip_edges().split(" ", false)[0])
	if start < 0.0 or end < start:
		return {}
	return {
		"start": start,
		"end": end,
	}


static func _parse_timestamp(text: String) -> float:
	var normalized: String = text.replace(",", ".").strip_edges()
	var parts: PackedStringArray = normalized.split(":", false)
	if parts.size() == 2:
		var minute_value: float = _parse_timestamp_component(parts[0], false)
		var second_value: float = _parse_timestamp_component(parts[1], true)
		if minute_value < 0.0 or second_value < 0.0:
			return -1.0
		return minute_value * 60.0 + second_value
	if parts.size() == 3:
		var hour_value: float = _parse_timestamp_component(parts[0], false)
		var hour_minute_value: float = _parse_timestamp_component(parts[1], false)
		var hour_second_value: float = _parse_timestamp_component(parts[2], true)
		if hour_value < 0.0 or hour_minute_value < 0.0 or hour_second_value < 0.0:
			return -1.0
		return hour_value * 3600.0 + hour_minute_value * 60.0 + hour_second_value
	return -1.0


static func _parse_timestamp_component(text: String, allow_decimal: bool) -> float:
	var component: String = text.strip_edges()
	if component.is_empty():
		return -1.0
	var dot_count: int = 0
	var digit_count: int = 0
	for index: int in range(component.length()):
		var code: int = component.unicode_at(index)
		if allow_decimal and code == 46:
			dot_count += 1
			if dot_count > 1:
				return -1.0
			continue
		if code < 48 or code > 57:
			return -1.0
		digit_count += 1
	if digit_count <= 0:
		return -1.0
	return component.to_float()


static func _parse_lrc_line(line: String) -> Array[Dictionary]:
	var starts: Array[float] = []
	var cursor: int = 0
	while cursor < line.length() and line.substr(cursor, 1) == "[":
		var end_index: int = line.find("]", cursor)
		if end_index <= cursor + 1:
			return []

		var time_text: String = line.substr(cursor + 1, end_index - cursor - 1)
		var start: float = _parse_timestamp(time_text)
		if start < 0.0:
			return []

		starts.append(start)
		cursor = end_index + 1

	if starts.is_empty():
		return []

	var lyric_text: String = line.substr(cursor)
	var result: Array[Dictionary] = []
	for start_time: float in starts:
		result.append({
			"start": start_time,
			"text": lyric_text,
		})
	return result


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


static func _make_result(success: bool, track: GFTimedTextTrack, error: String) -> Dictionary:
	return {
		"success": success,
		"track": track,
		"error": error,
	}
