## 测试 GFAudioMetadataTools 的音频元数据规范化、ID3v2 解析和 Clip 合并。
extends GutTest


# --- 常量 ---

const GFAudioMetadataToolsScript = preload("res://addons/gf/standard/utilities/audio/gf_audio_metadata_tools.gd")


func test_normalize_metadata_merges_common_key_shapes() -> void:
	var normalized: Dictionary = GFAudioMetadataToolsScript.normalize_metadata({
		"Track-Number": 3,
		"album artist": "Band",
		&"genre/name": "Ambient",
		"": "ignored",
	})

	assert_eq(GFVariantData.get_option_int(normalized, "track_number"), 3)
	assert_eq(GFVariantData.get_option_string(normalized, "album_artist"), "Band")
	assert_eq(GFVariantData.get_option_string(normalized, "genre_name"), "Ambient")
	assert_false(normalized.has(""))


func test_parse_id3v2_metadata_reads_common_text_frames() -> void:
	var id3_bytes: PackedByteArray = _make_id3_bytes([
		_make_text_frame("TIT2", "Track Title"),
		_make_text_frame("TPE1", "Artist Name"),
		_make_text_frame("TALB", "Album Name"),
		_make_text_frame("TRCK", "4/12"),
		_make_text_frame("TDRC", "2026-02-03"),
		_make_text_frame("TBPM", "128.5"),
		_make_text_frame("TCON", "(Electronic)"),
		_make_comment_frame("Short description", "Visible comment"),
		_make_user_text_frame("mood", "calm"),
		_make_picture_frame("image/png", "front", PackedByteArray([1, 2, 3, 4])),
	])

	var report: Dictionary = GFAudioMetadataToolsScript.parse_id3v2_metadata(id3_bytes)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_true(GFVariantData.get_option_bool(report, "recognized"))
	assert_eq(GFVariantData.get_option_string(report, "id3_version"), "2.3.0")
	assert_eq(GFVariantData.get_option_int(report, "frame_count"), 10)
	assert_eq(GFVariantData.get_option_string(metadata, "title"), "Track Title")
	assert_eq(GFVariantData.get_option_string(metadata, "artist"), "Artist Name")
	assert_eq(GFVariantData.get_option_string(metadata, "album"), "Album Name")
	assert_eq(GFVariantData.get_option_int(metadata, "track_number"), 4)
	assert_eq(GFVariantData.get_option_int(metadata, "track_count"), 12)
	assert_eq(GFVariantData.get_option_int(metadata, "year"), 2026)
	assert_almost_eq(GFVariantData.get_option_float(metadata, "bpm"), 128.5, 0.001)
	assert_eq(GFVariantData.get_option_string(metadata, "genre"), "Electronic")
	assert_eq(GFVariantData.get_option_string(metadata, "comments"), "Visible comment")
	assert_eq(GFVariantData.get_option_array(metadata, "user_defined_texts"), ["calm"])
	assert_true(GFVariantData.get_option_bool(metadata, "has_cover"))
	assert_eq(GFVariantData.get_option_string(metadata, "cover_mime_type"), "image/png")
	assert_eq(GFVariantData.get_option_int(metadata, "cover_byte_size"), 4)


func test_parse_id3v2_metadata_decodes_utf16_text_frames() -> void:
	var id3_bytes: PackedByteArray = _make_id3_bytes([
		_make_utf16le_title_frame(),
	])

	var report: Dictionary = GFAudioMetadataToolsScript.parse_id3v2_metadata(id3_bytes)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "UTF-16 文本帧不应破坏 ID3 解析。")
	assert_eq(GFVariantData.get_option_string(metadata, "title"), "标题", "ID3v2 UTF-16LE 标题应按原文解码。")


func test_make_display_summary_uses_fallbacks_and_cover_markers() -> void:
	var summary: Dictionary = GFAudioMetadataToolsScript.make_display_summary({
		"album-artist": "Album Artist",
		"album_cover": "res://cover.png",
		"track_number": 2,
	}, {
		"fallback_title": "Fallback Title",
	})

	assert_eq(GFVariantData.get_option_string(summary, "title"), "Fallback Title")
	assert_eq(GFVariantData.get_option_string(summary, "artist"), "Album Artist")
	assert_eq(GFVariantData.get_option_int(summary, "track_number"), 2)
	assert_true(GFVariantData.get_option_bool(summary, "has_cover"))


func test_read_path_metadata_reads_prefix_without_importer() -> void:
	var path: String = "user://gf_audio_metadata_id3_test.mp3"
	var bytes: PackedByteArray = _make_id3_bytes([
		_make_text_frame("TIT2", "Path Title"),
	])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var _store_buffer_result: Variant = file.store_buffer(bytes)
	file.close()

	var report: Dictionary = GFAudioMetadataToolsScript.read_path_metadata(path)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_true(GFVariantData.get_option_bool(report, "recognized"))
	assert_eq(GFVariantData.get_option_string(metadata, "title"), "Path Title")

	var _remove_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_apply_clip_metadata_preserves_existing_by_default() -> void:
	var path: String = "user://gf_audio_metadata_clip_test.mp3"
	var bytes: PackedByteArray = _make_id3_bytes([
		_make_text_frame("TIT2", "Path Title"),
		_make_text_frame("TPE1", "Path Artist"),
	])
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var _store_buffer_result: Variant = file.store_buffer(bytes)
	file.close()

	var clip: GFAudioClip = GFAudioClip.new()
	clip.path = path
	clip.metadata = {
		"title": "Manual Title",
	}

	var report: Dictionary = GFAudioMetadataToolsScript.apply_clip_metadata(clip, {
		"include_path": true,
	})

	assert_true(GFVariantData.get_option_bool(report, "applied"))
	assert_eq(GFVariantData.get_option_string(clip.metadata, "title"), "Manual Title")
	assert_eq(GFVariantData.get_option_string(clip.metadata, "artist"), "Path Artist")

	var _remove_result: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _make_id3_bytes(frames: Array[PackedByteArray]) -> PackedByteArray:
	var frame_bytes: PackedByteArray = PackedByteArray()
	for frame: PackedByteArray in frames:
		frame_bytes.append_array(frame)

	var bytes: PackedByteArray = PackedByteArray()
	bytes.append_array("ID3".to_ascii_buffer())
	bytes.append_array(PackedByteArray([3, 0, 0]))
	bytes.append_array(_syncsafe_bytes(frame_bytes.size()))
	bytes.append_array(frame_bytes)
	return bytes


func _make_text_frame(frame_id: String, value: String) -> PackedByteArray:
	var payload: PackedByteArray = PackedByteArray()
	payload.append_array(PackedByteArray([3]))
	payload.append_array(value.to_utf8_buffer())
	return _make_frame(frame_id, payload)


func _make_utf16le_title_frame() -> PackedByteArray:
	var payload: PackedByteArray = PackedByteArray()
	payload.append_array(PackedByteArray([
		1,
		0xff,
		0xfe,
		0x07,
		0x68,
		0x98,
		0x98,
		0x00,
		0x00,
	]))
	return _make_frame("TIT2", payload)


func _make_comment_frame(description: String, value: String) -> PackedByteArray:
	var payload: PackedByteArray = PackedByteArray()
	payload.append_array(PackedByteArray([3]))
	payload.append_array("eng".to_ascii_buffer())
	payload.append_array(description.to_utf8_buffer())
	payload.append_array(PackedByteArray([0]))
	payload.append_array(value.to_utf8_buffer())
	return _make_frame("COMM", payload)


func _make_user_text_frame(description: String, value: String) -> PackedByteArray:
	var payload: PackedByteArray = PackedByteArray()
	payload.append_array(PackedByteArray([3]))
	payload.append_array(description.to_utf8_buffer())
	payload.append_array(PackedByteArray([0]))
	payload.append_array(value.to_utf8_buffer())
	return _make_frame("TXXX", payload)


func _make_picture_frame(
	mime_type: String,
	description: String,
	image_bytes: PackedByteArray
) -> PackedByteArray:
	var payload: PackedByteArray = PackedByteArray()
	payload.append_array(PackedByteArray([3]))
	payload.append_array(mime_type.to_ascii_buffer())
	payload.append_array(PackedByteArray([0, 3]))
	payload.append_array(description.to_utf8_buffer())
	payload.append_array(PackedByteArray([0]))
	payload.append_array(image_bytes)
	return _make_frame("APIC", payload)


func _make_frame(frame_id: String, payload: PackedByteArray) -> PackedByteArray:
	var frame: PackedByteArray = PackedByteArray()
	frame.append_array(frame_id.to_ascii_buffer())
	frame.append_array(_uint32_bytes(payload.size()))
	frame.append_array(PackedByteArray([0, 0]))
	frame.append_array(payload)
	return frame


func _uint32_bytes(value: int) -> PackedByteArray:
	return PackedByteArray([
		(value >> 24) & 0xff,
		(value >> 16) & 0xff,
		(value >> 8) & 0xff,
		value & 0xff,
	])


func _syncsafe_bytes(value: int) -> PackedByteArray:
	return PackedByteArray([
		(value >> 21) & 0x7f,
		(value >> 14) & 0x7f,
		(value >> 7) & 0x7f,
		value & 0x7f,
	])
