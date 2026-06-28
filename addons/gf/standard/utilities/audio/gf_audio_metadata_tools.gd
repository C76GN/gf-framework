@tool

## GFAudioMetadataTools: 通用音频元数据提取与规范化工具。
##
## 负责把 `AudioStream` 属性、`GFAudioClip.metadata` 和常见 ID3v2 文本帧
## 规范化为纯 Dictionary 报告。该类不接管导入器、不解码封面图片、不定义项目音频命名或播放策略。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFAudioMetadataTools
extends RefCounted


# --- 常量 ---

const _ID3_PREFIX: String = "ID3"
const _ID3_HEADER_SIZE: int = 10
const _DEFAULT_MAX_ID3_BYTES: int = 1024 * 1024
const _FRAME_HEADER_SIZE: int = 10
const _TEXT_ENCODING_UTF8: int = 3
const _TEXT_ENCODING_LATIN1: int = 0
const _TEXT_ENCODING_UTF16: int = 1
const _TEXT_ENCODING_UTF16BE: int = 2

const _FRAME_TO_TAG: Dictionary = {
	"TALB": "album",
	"TBPM": "bpm",
	"TCOP": "copyright",
	"TCON": "genre",
	"TDAT": "date",
	"TDRC": "date",
	"TIT2": "title",
	"TPE1": "artist",
	"TPE2": "album_artist",
	"TRCK": "track",
	"TYER": "year",
}


# --- 公共方法 ---

## 规范化音频元数据标签名。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param tag_name: 原始标签名。
## [br]
## @return 规范化后的标签名。
static func normalize_tag_name(tag_name: String) -> StringName:
	var text: String = tag_name.strip_edges().to_lower()
	text = text.replace("-", "_")
	text = text.replace(" ", "_")
	text = text.replace("/", "_")
	while text.contains("__"):
		text = text.replace("__", "_")
	text = text.strip_edges()
	if text == "tags" or text == "_property_name_cache":
		text += "_"
	return StringName(text)


## 规范化音频元数据字典。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param metadata: 原始元数据字典。
## [br]
## @schema metadata: Dictionary audio metadata payload.
## [br]
## @param options: 可选项，支持 `drop_null_values`。
## [br]
## @schema options: Dictionary normalization options.
## [br]
## @return 规范化后的元数据副本。
## [br]
## @schema return: Dictionary normalized audio metadata.
static func normalize_metadata(metadata: Dictionary, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	var drop_null_values: bool = GFVariantData.get_option_bool(options, "drop_null_values", false)
	for raw_key: Variant in metadata.keys():
		var key_text: String = _variant_to_key_text(raw_key)
		if key_text.strip_edges().is_empty():
			continue

		var normalized_key: StringName = normalize_tag_name(key_text)
		var value: Variant = metadata[raw_key]
		if value == null and drop_null_values:
			continue

		result[normalized_key] = GFVariantData.duplicate_variant(value, true, true)

	return result


## 合并两份音频元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param base_metadata: 基础元数据。
## [br]
## @schema base_metadata: Dictionary audio metadata payload.
## [br]
## @param overlay_metadata: 覆盖元数据。
## [br]
## @schema overlay_metadata: Dictionary audio metadata payload.
## [br]
## @param options: 可选项，支持 `overwrite` 与 normalize_metadata() 的选项。
## [br]
## @schema options: Dictionary merge options.
## [br]
## @return 合并后的元数据副本。
## [br]
## @schema return: Dictionary merged normalized audio metadata.
static func merge_metadata(
	base_metadata: Dictionary,
	overlay_metadata: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = normalize_metadata(base_metadata, options)
	var overlay: Dictionary = normalize_metadata(overlay_metadata, options)
	var overwrite: bool = GFVariantData.get_option_bool(options, "overwrite", true)
	for key: Variant in overlay.keys():
		if overwrite or not result.has(key):
			result[key] = GFVariantData.duplicate_variant(overlay[key], true, true)
	return result


## 从元数据生成展示摘要。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param metadata: 音频元数据。
## [br]
## @schema metadata: Dictionary audio metadata payload.
## [br]
## @param options: 可选项，支持 `fallback_title`。
## [br]
## @schema options: Dictionary summary options.
## [br]
## @return 展示摘要。
## [br]
## @schema return: Dictionary with `title`, `artist`, `album`, `album_artist`, `genre`, `track_number`, `track_count`, `year`, `bpm`, `duration_seconds`, and `has_cover`.
static func make_display_summary(metadata: Dictionary, options: Dictionary = {}) -> Dictionary:
	var normalized: Dictionary = normalize_metadata(metadata)
	var title: String = GFVariantData.get_option_string(
		normalized,
		"title",
		GFVariantData.get_option_string(options, "fallback_title", "")
	)
	var artist: String = GFVariantData.get_option_string(normalized, "artist", "")
	if artist.is_empty():
		artist = GFVariantData.get_option_string(normalized, "album_artist", "")
	return {
		"title": title,
		"artist": artist,
		"album": GFVariantData.get_option_string(normalized, "album", ""),
		"album_artist": GFVariantData.get_option_string(normalized, "album_artist", ""),
		"genre": GFVariantData.get_option_string(normalized, "genre", ""),
		"track_number": GFVariantData.get_option_int(normalized, "track_number", -1),
		"track_count": GFVariantData.get_option_int(normalized, "track_count", -1),
		"year": GFVariantData.get_option_int(normalized, "year", 0),
		"bpm": GFVariantData.get_option_float(normalized, "bpm", 0.0),
		"duration_seconds": GFVariantData.get_option_float(normalized, "duration_seconds", 0.0),
		"has_cover": GFVariantData.get_option_bool(normalized, "has_cover", false)
			or normalized.has("cover")
			or normalized.has("album_cover"),
	}


## 从 AudioStream 提取元数据报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param stream: 要读取的音频流。
## [br]
## @param options: 可选项，支持 `parse_stream_data`。
## [br]
## @schema options: Dictionary extraction options.
## [br]
## @return 元数据报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `recognized: bool`, `metadata: Dictionary`, `issues: Array[Dictionary]`, `issue_count: int`, and optional `id3_version`.
static func extract_stream_metadata(stream: AudioStream, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report("GFAudioMetadataTools.extract_stream_metadata")
	if stream == null:
		_add_issue(report, &"missing_stream", "AudioStream is null.")
		return report

	var metadata: Dictionary = {}
	var duration: float = stream.get_length()
	if _is_finite_float(duration) and duration > 0.0:
		metadata[&"duration_seconds"] = duration

	_copy_stream_property(stream, &"bpm", metadata)
	_copy_stream_property(stream, &"beat_count", metadata)
	_copy_stream_property(stream, &"bar_beats", metadata)

	if _object_has_property(stream, &"tags"):
		var raw_tags: Variant = stream.get("tags")
		if raw_tags is Dictionary:
			var tag_metadata: Dictionary = raw_tags
			metadata = merge_metadata(metadata, tag_metadata)

	if GFVariantData.get_option_bool(options, "parse_stream_data", true):
		var bytes: PackedByteArray = _get_audio_stream_bytes(stream)
		if not bytes.is_empty():
			var id3_report: Dictionary = parse_id3v2_metadata(bytes, options)
			_merge_child_report(report, id3_report)
			metadata = merge_metadata(
				metadata,
				GFVariantData.get_option_dictionary(id3_report, "metadata", {}),
				{ "overwrite": GFVariantData.get_option_bool(options, "id3_overwrites_stream", true) }
			)

	report["metadata"] = normalize_metadata(metadata)
	report["recognized"] = not GFVariantData.get_option_dictionary(report, "metadata", {}).is_empty()
	return report


## 解析 ID3v2 字节中的常见音频元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param bytes: 音频文件开头或完整文件字节。
## [br]
## @param options: 可选项，支持 `fail_on_frame_error`。
## [br]
## @schema options: Dictionary ID3 parsing options.
## [br]
## @return ID3v2 元数据报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `recognized: bool`, `metadata: Dictionary`, `issues: Array[Dictionary]`, `issue_count: int`, `id3_version: String`, `tag_size: int`, `frame_count: int`, and `skipped_frame_count: int`.
static func parse_id3v2_metadata(bytes: PackedByteArray, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report("GFAudioMetadataTools.parse_id3v2_metadata")
	report["recognized"] = false
	report["id3_version"] = ""
	report["tag_size"] = 0
	report["frame_count"] = 0
	report["skipped_frame_count"] = 0

	if bytes.size() < _ID3_HEADER_SIZE:
		return report
	if bytes.slice(0, 3).get_string_from_ascii() != _ID3_PREFIX:
		return report

	report["recognized"] = true
	var major_version: int = bytes[3]
	var revision: int = bytes[4]
	report["id3_version"] = "2.%d.%d" % [major_version, revision]
	if major_version != 3 and major_version != 4:
		_add_issue(report, &"unsupported_id3_version", "Only ID3v2.3 and ID3v2.4 are supported.")
		return report

	var tag_size: int = _syncsafe_to_int(bytes.slice(6, 10))
	report["tag_size"] = tag_size
	var end_offset: int = mini(_ID3_HEADER_SIZE + tag_size, bytes.size())
	var offset: int = _ID3_HEADER_SIZE
	var frame_count: int = 0
	var skipped_frame_count: int = 0

	while offset + _FRAME_HEADER_SIZE <= end_offset:
		var frame_id: String = bytes.slice(offset, offset + 4).get_string_from_ascii()
		if _is_padding_frame_id(frame_id):
			break

		var frame_size: int = _syncsafe_to_int(bytes.slice(offset + 4, offset + 8)) \
			if major_version == 4 else _bytes_to_int(bytes.slice(offset + 4, offset + 8))
		if frame_size <= 0:
			break

		var frame_start: int = offset + _FRAME_HEADER_SIZE
		var frame_end: int = frame_start + frame_size
		if frame_end > end_offset or frame_end > bytes.size():
			_add_issue(report, &"truncated_id3_frame", "ID3 frame extends beyond available bytes.", frame_id)
			if GFVariantData.get_option_bool(options, "fail_on_frame_error", false):
				return report
			break

		var frame_data: PackedByteArray = bytes.slice(frame_start, frame_end)
		var frame_parsed: bool = _parse_id3_frame(frame_id, frame_data, report, options)
		if frame_parsed:
			frame_count += 1
		else:
			skipped_frame_count += 1

		offset = frame_end

	report["frame_count"] = frame_count
	report["skipped_frame_count"] = skipped_frame_count
	report["metadata"] = normalize_metadata(GFVariantData.get_option_dictionary(report, "metadata", {}))
	return report


## 从本地路径读取音频元数据报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param path: `res://`、`user://` 或绝对路径。
## [br]
## @param options: 可选项，支持 `max_id3_bytes`。
## [br]
## @schema options: Dictionary read options.
## [br]
## @return 元数据报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `recognized: bool`, `metadata: Dictionary`, `issues: Array[Dictionary]`, `issue_count: int`, and `path: String`.
static func read_path_metadata(path: String, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report("GFAudioMetadataTools.read_path_metadata")
	report["path"] = path
	if path.strip_edges().is_empty():
		_add_issue(report, &"empty_path", "Audio metadata path is empty.")
		return report
	if not FileAccess.file_exists(path):
		_add_issue(report, &"missing_file", "Audio metadata file does not exist.")
		return report

	var max_id3_bytes: int = maxi(
		GFVariantData.get_option_int(options, "max_id3_bytes", _DEFAULT_MAX_ID3_BYTES),
		_ID3_HEADER_SIZE
	)
	var bytes: PackedByteArray = _read_file_prefix(path, max_id3_bytes)
	if bytes.is_empty():
		_add_issue(report, &"read_failed", "Audio metadata file could not be read.")
		return report

	var id3_report: Dictionary = parse_id3v2_metadata(bytes, options)
	_merge_child_report(report, id3_report)
	report["recognized"] = GFVariantData.get_option_bool(id3_report, "recognized", false)
	report["metadata"] = GFVariantData.get_option_dictionary(id3_report, "metadata", {})
	return report


## 读取音频片段的合并元数据报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param clip: 要读取的音频片段。
## [br]
## @param options: 可选项，支持 `include_stream`、`include_path` 和 `overwrite_existing`。
## [br]
## @schema options: Dictionary clip metadata options.
## [br]
## @return 元数据报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `recognized: bool`, `metadata: Dictionary`, `issues: Array[Dictionary]`, and `issue_count: int`.
static func read_clip_metadata(clip: GFAudioClip, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report("GFAudioMetadataTools.read_clip_metadata")
	if clip == null:
		_add_issue(report, &"missing_clip", "GFAudioClip is null.")
		return report

	var metadata: Dictionary = normalize_metadata(clip.metadata)
	var overwrite_existing: bool = GFVariantData.get_option_bool(options, "overwrite_existing", false)
	if GFVariantData.get_option_bool(options, "include_stream", true) and clip.stream != null:
		var stream_report: Dictionary = extract_stream_metadata(clip.stream, options)
		_merge_child_report(report, stream_report)
		metadata = merge_metadata(
			metadata,
			GFVariantData.get_option_dictionary(stream_report, "metadata", {}),
			{ "overwrite": overwrite_existing }
		)

	if GFVariantData.get_option_bool(options, "include_path", false) and not clip.path.is_empty():
		var path_report: Dictionary = read_path_metadata(clip.path, options)
		_merge_child_report(report, path_report)
		metadata = merge_metadata(
			metadata,
			GFVariantData.get_option_dictionary(path_report, "metadata", {}),
			{ "overwrite": overwrite_existing }
		)

	report["metadata"] = metadata
	report["recognized"] = not metadata.is_empty()
	return report


## 将读取到的元数据写回音频片段。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param clip: 要写入的音频片段。
## [br]
## @param options: 可选项，格式同 read_clip_metadata()。
## [br]
## @schema options: Dictionary clip metadata options.
## [br]
## @return 写入报告。
## [br]
## @schema return: Dictionary with `ok: bool`, `recognized: bool`, `metadata: Dictionary`, `issues: Array[Dictionary]`, `issue_count: int`, and `applied: bool`.
static func apply_clip_metadata(clip: GFAudioClip, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = read_clip_metadata(clip, options)
	report["applied"] = false
	if clip == null or not GFVariantData.get_option_bool(report, "ok", false):
		return report

	clip.metadata = GFVariantData.get_option_dictionary(report, "metadata", {})
	report["applied"] = true
	return report


# --- 私有/辅助方法 ---

static func _make_report(subject: String) -> Dictionary:
	return {
		"ok": true,
		"recognized": false,
		"subject": subject,
		"metadata": {},
		"issues": [],
		"issue_count": 0,
	}


static func _add_issue(
	report: Dictionary,
	kind: StringName,
	message: String,
	frame_id: String = ""
) -> void:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var issue: Dictionary = {
		"kind": kind,
		"message": message,
	}
	if not frame_id.is_empty():
		issue["frame_id"] = frame_id
	issues.append(issue)
	report["issues"] = issues
	report["issue_count"] = issues.size()
	report["ok"] = false


static func _merge_child_report(report: Dictionary, child_report: Dictionary) -> void:
	var child_issues: Array = GFVariantData.get_option_array(child_report, "issues")
	if not child_issues.is_empty():
		var issues: Array = GFVariantData.get_option_array(report, "issues")
		issues.append_array(child_issues)
		report["issues"] = issues
		report["issue_count"] = issues.size()
		report["ok"] = false
	if GFVariantData.get_option_bool(child_report, "recognized", false):
		report["recognized"] = true
	if child_report.has("id3_version"):
		report["id3_version"] = GFVariantData.get_option_string(child_report, "id3_version", "")


static func _variant_to_key_text(value: Variant) -> String:
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return str(value)


static func _object_has_property(object: Object, property_name: StringName) -> bool:
	if object == null:
		return false
	for property_info: Dictionary in object.get_property_list():
		if GFVariantData.get_option_string_name(property_info, "name") == property_name:
			return true
	return false


static func _copy_stream_property(
	stream: AudioStream,
	property_name: StringName,
	metadata: Dictionary
) -> void:
	if not _object_has_property(stream, property_name):
		return

	var value: Variant = stream.get(String(property_name))
	if value == null:
		return

	if value is float:
		var float_value: float = value
		if not _is_finite_float(float_value):
			return

	metadata[property_name] = GFVariantData.duplicate_variant(value, true, true)


static func _get_audio_stream_bytes(stream: AudioStream) -> PackedByteArray:
	if stream is AudioStreamMP3:
		var mp3_stream: AudioStreamMP3 = stream
		return mp3_stream.data
	return PackedByteArray()


static func _read_file_prefix(path: String, max_bytes: int) -> PackedByteArray:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()

	var read_size: int = mini(int(file.get_length()), max_bytes)
	var bytes: PackedByteArray = file.get_buffer(read_size)
	file.close()
	return bytes


static func _parse_id3_frame(
	frame_id: String,
	frame_data: PackedByteArray,
	report: Dictionary,
	_options: Dictionary
) -> bool:
	if frame_id == "COMM":
		return _parse_comment_frame(frame_data, report)
	if frame_id == "APIC":
		return _parse_picture_frame(frame_data, report)
	if frame_id == "TXXX":
		return _parse_user_text_frame(frame_data, report)
	if not frame_id.begins_with("T"):
		return false
	if not _FRAME_TO_TAG.has(frame_id):
		return false

	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata", {})
	var tag_name: String = GFVariantData.get_option_string(_FRAME_TO_TAG, frame_id, "")
	var text: String = _decode_id3_text(frame_data).strip_edges()
	if text.is_empty():
		return false

	match tag_name:
		"bpm":
			var bpm: float = GFVariantData.to_float(text, 0.0)
			if bpm > 0.0 and _is_finite_float(bpm):
				metadata[&"bpm"] = bpm
		"track":
			_apply_track_text(metadata, text)
		"year":
			var year: int = _parse_year(text)
			if year > 0:
				metadata[&"year"] = year
		"date":
			metadata[&"date"] = text
			var date_year: int = _parse_year(text)
			if date_year > 0 and not metadata.has(&"year"):
				metadata[&"year"] = date_year
		"genre":
			metadata[&"genre"] = _normalize_genre_text(text)
		_:
			metadata[normalize_tag_name(tag_name)] = text

	report["metadata"] = metadata
	return true


static func _parse_comment_frame(frame_data: PackedByteArray, report: Dictionary) -> bool:
	if frame_data.size() <= 4:
		return false

	var payload: PackedByteArray = PackedByteArray()
	payload.append_array(PackedByteArray([frame_data[0]]))
	payload.append_array(frame_data.slice(_find_id3_text_value_start(frame_data, 4, frame_data[0])))
	var text: String = _decode_id3_text(payload).strip_edges()
	if text.is_empty():
		return false

	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata", {})
	metadata[&"comments"] = text
	report["metadata"] = metadata
	return true


static func _parse_user_text_frame(frame_data: PackedByteArray, report: Dictionary) -> bool:
	if frame_data.is_empty():
		return false

	var payload: PackedByteArray = PackedByteArray()
	payload.append_array(PackedByteArray([frame_data[0]]))
	payload.append_array(frame_data.slice(_find_id3_text_value_start(frame_data, 1, frame_data[0])))
	var text: String = _decode_id3_text(payload).strip_edges()
	if text.is_empty():
		return false

	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata", {})
	var values: Array = GFVariantData.get_option_array(metadata, "user_defined_texts")
	values.append(text)
	metadata[&"user_defined_texts"] = values
	report["metadata"] = metadata
	return true


static func _parse_picture_frame(frame_data: PackedByteArray, report: Dictionary) -> bool:
	if frame_data.size() <= 4:
		return false

	var mime_end: int = frame_data.find(0, 1)
	if mime_end < 1:
		return false

	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata", {})
	var encoding: int = frame_data[0]
	var image_start: int = _find_id3_text_value_start(frame_data, mime_end + 2, encoding)
	metadata[&"has_cover"] = true
	metadata[&"cover_mime_type"] = frame_data.slice(1, mime_end).get_string_from_ascii()
	metadata[&"cover_byte_size"] = maxi(frame_data.size() - image_start, 0)
	report["metadata"] = metadata
	return true


static func _decode_id3_text(frame_data: PackedByteArray) -> String:
	if frame_data.is_empty():
		return ""

	var encoding: int = frame_data[0]
	var payload: PackedByteArray = frame_data.slice(1)
	match encoding:
		_TEXT_ENCODING_UTF8:
			return _trim_null_bytes(payload).get_string_from_utf8()
		_TEXT_ENCODING_LATIN1:
			return _trim_null_bytes(payload).get_string_from_ascii()
		_TEXT_ENCODING_UTF16:
			return _decode_utf16_text(_trim_utf16_terminator(payload))
		_TEXT_ENCODING_UTF16BE:
			return _decode_utf16be_text(_trim_utf16_terminator(payload))
		_:
			return _decode_lossy_utf16ish(_trim_null_bytes(payload))


static func _decode_utf16_text(payload: PackedByteArray) -> String:
	if payload.size() >= 2:
		if payload[0] == 0xfe and payload[1] == 0xff:
			return _decode_utf16_units(payload.slice(2), false)
		if payload[0] == 0xff and payload[1] == 0xfe:
			return _decode_utf16_units(payload.slice(2), true)
	return _decode_utf16_units(payload, true)


static func _decode_utf16be_text(payload: PackedByteArray) -> String:
	return _decode_utf16_units(payload, false)


static func _decode_utf16_units(payload: PackedByteArray, little_endian: bool) -> String:
	var result: String = ""
	var index: int = 0
	while index + 1 < payload.size():
		var code_unit: int = _read_utf16_code_unit(payload, index, little_endian)
		index += 2
		if code_unit == 0:
			break
		if code_unit >= 0xd800 and code_unit <= 0xdbff and index + 1 < payload.size():
			var low_surrogate: int = _read_utf16_code_unit(payload, index, little_endian)
			if low_surrogate >= 0xdc00 and low_surrogate <= 0xdfff:
				var codepoint: int = 0x10000 + ((code_unit - 0xd800) << 10) + (low_surrogate - 0xdc00)
				result += char(codepoint)
				index += 2
				continue
		if code_unit < 0xdc00 or code_unit > 0xdfff:
			result += char(code_unit)
	return result


static func _read_utf16_code_unit(payload: PackedByteArray, index: int, little_endian: bool) -> int:
	if little_endian:
		return payload[index] | (payload[index + 1] << 8)
	return (payload[index] << 8) | payload[index + 1]


static func _trim_utf16_terminator(value: PackedByteArray) -> PackedByteArray:
	var end_index: int = value.size()
	while end_index >= 2 and value[end_index - 1] == 0 and value[end_index - 2] == 0:
		end_index -= 2
	return value.slice(0, end_index)


static func _decode_lossy_utf16ish(payload: PackedByteArray) -> String:
	var filtered: PackedByteArray = PackedByteArray()
	for byte_value: int in payload:
		if byte_value == 0 or byte_value == 0xff or byte_value == 0xfe:
			continue
		var _append_result: bool = filtered.append(byte_value)
	return filtered.get_string_from_utf8()


static func _trim_null_bytes(value: PackedByteArray) -> PackedByteArray:
	var end_index: int = value.size()
	while end_index > 0 and value[end_index - 1] == 0:
		end_index -= 1
	return value.slice(0, end_index)


static func _find_id3_text_value_start(
	frame_data: PackedByteArray,
	description_start: int,
	encoding: int
) -> int:
	if description_start >= frame_data.size():
		return frame_data.size()

	if encoding == _TEXT_ENCODING_LATIN1 or encoding == _TEXT_ENCODING_UTF8:
		var terminator_index: int = frame_data.find(0, description_start)
		return terminator_index + 1 if terminator_index >= 0 else description_start

	for index: int in range(description_start, frame_data.size() - 1):
		if frame_data[index] == 0 and frame_data[index + 1] == 0:
			return index + 2
	return description_start


static func _apply_track_text(metadata: Dictionary, text: String) -> void:
	var parts: PackedStringArray = text.split("/", false)
	if parts.size() >= 1:
		metadata[&"track_number"] = GFVariantData.to_int(parts[0], -1)
	if parts.size() >= 2:
		metadata[&"track_count"] = GFVariantData.to_int(parts[1], -1)


static func _parse_year(text: String) -> int:
	var trimmed: String = text.strip_edges()
	if trimmed.length() >= 4:
		var prefix: String = trimmed.substr(0, 4)
		if prefix.is_valid_int():
			return int(prefix)
	if trimmed.is_valid_int():
		return int(trimmed)
	return 0


static func _normalize_genre_text(text: String) -> String:
	var genre: String = text.strip_edges()
	if genre.begins_with("(") and genre.ends_with(")") and genre.length() > 2:
		return genre.substr(1, genre.length() - 2).strip_edges()
	return genre


static func _is_padding_frame_id(frame_id: String) -> bool:
	if frame_id.length() < 4:
		return true
	for index: int in range(frame_id.length()):
		if frame_id.unicode_at(index) != 0:
			return false
	return true


static func _bytes_to_int(bytes: PackedByteArray) -> int:
	var result: int = 0
	for byte_value: int in bytes:
		result = result * 256 + byte_value
	return result


static func _syncsafe_to_int(bytes: PackedByteArray) -> int:
	var result: int = 0
	for byte_value: int in bytes:
		result = result * 128 + (byte_value & 0x7f)
	return result


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
