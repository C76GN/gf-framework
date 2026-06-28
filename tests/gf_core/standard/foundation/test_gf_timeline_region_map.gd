## 测试时间段文本轨道与区域分块数据映射。
extends GutTest


# --- 测试 ---

func test_timed_text_track_queries_entries() -> void:
	var track: GFTimedTextTrack = GFTimedTextTrack.new()
	track.call("add_entry", 0.0, 1.0, "A")
	track.call("add_entry", 1.0, 2.0, "B")

	assert_eq(GFVariantData.to_text(track.call("get_text_at_time", 0.5)), "A", "时间查询应返回命中文本。")
	assert_eq(GFVariantData.as_array(track.call("get_entries_in_range", 0.5, 1.5)).size(), 2, "范围查询应返回相交条目。")
	assert_eq(GFVariantData.as_array(track.call("get_entries_in_range", 1.5, 0.5)).size(), 2, "反向范围查询应归一后返回相交条目。")
	assert_eq(GFVariantData.to_float(track.call("get_total_duration")), 2.0, "总时长应取最大结束时间。")


func test_timed_text_importer_parses_srt_and_lrc() -> void:
	var srt: String = "1\n00:00:01,000 --> 00:00:02,500\nHello\n"
	var srt_result: Dictionary = GFTimedTextImporter.parse_srt(srt, &"caption")
	var srt_track: GFTimedTextTrack = _as_timed_text_track(GFVariantData.get_option_value(srt_result, "track"))
	var lrc_result: Dictionary = GFTimedTextImporter.parse_lrc("[00:01.00]One\n[00:03.00]Two\n", 1.0)
	var lrc_track: GFTimedTextTrack = _as_timed_text_track(GFVariantData.get_option_value(lrc_result, "track"))

	assert_true(GFVariantData.get_option_bool(srt_result, "success", false), "SRT 应解析成功。")
	assert_not_null(srt_track, "SRT 应返回文本轨道。")
	assert_not_null(lrc_track, "LRC 应返回文本轨道。")
	assert_eq(srt_track.track_id, &"caption", "轨道 ID 应保留。")
	assert_eq(GFVariantData.to_text(srt_track.call("get_text_at_time", 1.25)), "Hello", "SRT 时间段应可查询。")
	assert_eq(GFVariantData.to_text(lrc_track.call("get_text_at_time", 1.5)), "One", "LRC 行应转换为时间段。")
	assert_eq(GFVariantData.to_float(lrc_track.call("get_total_duration")), 4.0, "LRC 最后一行应使用默认时长。")


func test_timed_text_importer_rejects_malformed_timestamps() -> void:
	var srt_result: Dictionary = GFTimedTextImporter.parse_srt("1\n00:xx:01,000 --> 00:00:02,000\nBroken\n")
	var track: GFTimedTextTrack = _as_timed_text_track(GFVariantData.get_option_value(srt_result, "track"))

	assert_true(GFVariantData.get_option_bool(srt_result, "success", false), "解析器应容忍无效块并返回空轨道。")
	assert_not_null(track, "解析结果应仍返回轨道对象。")
	assert_true(track != null and track.entries.is_empty(), "格式错误的时间戳不应生成 0 秒误匹配条目。")


func test_timed_text_importer_expands_multi_tag_lrc_lines() -> void:
	var lrc_result: Dictionary = GFTimedTextImporter.parse_lrc("[00:01.00][00:03.00]Echo\n[00:05.00]Tail\n", 1.0)
	var track: GFTimedTextTrack = _as_timed_text_track(GFVariantData.get_option_value(lrc_result, "track"))

	assert_not_null(track, "LRC 应返回文本轨道。")
	assert_eq(track.entries.size(), 3, "同一 LRC 行的多个时间标签应展开为多个条目。")
	assert_eq(GFVariantData.to_text(track.call("get_text_at_time", 1.5)), "Echo", "第一时间标签应生成可查询条目。")
	assert_eq(GFVariantData.to_text(track.call("get_text_at_time", 3.5)), "Echo", "第二时间标签应生成可查询条目。")


func test_timed_text_apply_dictionary_normalizes_invalid_time_ranges() -> void:
	var track: GFTimedTextTrack = GFTimedTextTrack.new()
	track.apply_dictionary({
		"entries": [
			{
				"start_time": -5.0,
				"end_time": -1.0,
				"text": "clamped",
			},
			{
				"start_time": 2.0,
				"end_time": 1.0,
				"text": "ordered",
			},
		],
	})
	var first_entry: GFTimedTextEntry = track.entries[0]
	var second_entry: GFTimedTextEntry = track.entries[1]

	assert_eq(first_entry.start_time, 0.0, "恢复条目时负开始时间应归零。")
	assert_eq(first_entry.end_time, 0.0, "恢复条目时结束时间不应早于开始时间。")
	assert_eq(second_entry.end_time, second_entry.start_time, "恢复条目应修正 end < start。")


func test_replay_timeline_records_queries_and_serializes_events() -> void:
	var timeline: GFReplayTimeline = GFReplayTimeline.new()
	timeline.timeline_id = &"session"
	var _add_input_result_36: Variant = timeline.add_input(0.1, { "action_id": &"jump", "value": true })
	var _add_command_result_37: Variant = timeline.add_command(0.2, { "command_id": &"open" })
	var _add_snapshot_result_38: Variant = timeline.add_snapshot(0.3, { "tick": 3, "state": { "hp": 10 } })

	var input_events: Array[Dictionary] = timeline.get_events_by_kind(GFReplayTimeline.EVENT_INPUT)
	var range_events: Array[Dictionary] = timeline.get_events_in_range(0.0, 0.25)
	var restored: GFReplayTimeline = GFReplayTimeline.from_dictionary(timeline.to_dictionary())

	assert_eq(timeline.get_event_count(), 3, "时间线应记录多种事件。")
	assert_eq(input_events.size(), 1, "应能按事件类型查询。")
	assert_eq(range_events.size(), 2, "应能按时间范围查询。")
	assert_eq(restored.timeline_id, &"session", "序列化应保留时间线 ID。")
	assert_eq(restored.get_event_count(), 3, "序列化应保留事件数量。")


func test_replay_timeline_keeps_same_time_events_in_insert_order() -> void:
	var timeline: GFReplayTimeline = GFReplayTimeline.new()
	var _add_first_result: Variant = timeline.add_input(1.0, { "action_id": &"first" })
	var _add_second_result: Variant = timeline.add_command(1.0, { "command_id": &"second" })

	timeline.sort_events()
	var events: Array[Dictionary] = timeline.get_events()
	var restored: GFReplayTimeline = GFReplayTimeline.from_dictionary(timeline.to_dictionary())
	restored.sort_events()
	var restored_events: Array[Dictionary] = restored.get_events()

	assert_eq(GFVariantData.get_option_string_name(events[0], "event_kind"), GFReplayTimeline.EVENT_INPUT, "同时间事件应按插入顺序排序。")
	assert_eq(GFVariantData.get_option_string_name(events[1], "event_kind"), GFReplayTimeline.EVENT_COMMAND, "同时间事件不应退化为按 kind 排序。")
	assert_eq(GFVariantData.get_option_string_name(restored_events[0], "event_kind"), GFReplayTimeline.EVENT_INPUT, "序列化后应保留同时间事件顺序。")
	assert_eq(GFVariantData.get_option_string_name(restored_events[1], "event_kind"), GFReplayTimeline.EVENT_COMMAND, "序列化后不应改变同时间事件顺序。")


func test_replay_timeline_add_event_returns_decoupled_copy() -> void:
	var timeline: GFReplayTimeline = GFReplayTimeline.new()
	var event: Dictionary = timeline.add_event(0.2, GFReplayTimeline.EVENT_INPUT, { "action_id": &"jump" })
	event["event_kind"] = &"mutated"
	var payload: Dictionary = GFVariantData.get_option_dictionary(event, "payload")
	payload["action_id"] = &"mutated"

	var events: Array[Dictionary] = timeline.get_events()
	var stored_event: Dictionary = events[0]
	var stored_payload: Dictionary = GFVariantData.get_option_dictionary(stored_event, "payload")

	assert_eq(GFVariantData.get_option_string_name(stored_event, "event_kind"), GFReplayTimeline.EVENT_INPUT, "add_event 返回值不应暴露内部事件字典。")
	assert_eq(GFVariantData.get_option_string_name(stored_payload, "action_id"), &"jump", "add_event 返回值的嵌套 payload 也应与内部状态解耦。")


func test_replay_timeline_apply_dictionary_extends_duration_to_events() -> void:
	var timeline: GFReplayTimeline = GFReplayTimeline.new()

	timeline.apply_dictionary({
		"timeline_id": "restored",
		"duration_seconds": 0.5,
		"events": [
			{
				"event_kind": "snapshot",
				"time_seconds": 2.0,
				"payload": {
					"tick": 20,
				},
			},
		],
	})

	assert_almost_eq(timeline.duration_seconds, 2.0, 0.001, "恢复数据时 duration 不应小于事件最大时间。")


func test_replay_timeline_appends_filtered_timeline_with_offset() -> void:
	var source: GFReplayTimeline = GFReplayTimeline.new()
	var _add_input_result_53: Variant = source.add_input(0.1, { "action_id": &"dash" })
	var _add_snapshot_result_54: Variant = source.add_snapshot(0.2, { "tick": 2 })
	var target: GFReplayTimeline = GFReplayTimeline.new()

	var appended: int = target.append_timeline(source, 1.0, PackedStringArray(["snapshot"]))
	var events: Array[Dictionary] = target.get_events()
	var event: Dictionary = events[0]

	assert_eq(appended, 1, "过滤合并时应只追加匹配类型事件。")
	assert_eq(events.size(), 1, "目标时间线应只包含追加事件。")
	assert_eq(GFVariantData.get_option_string_name(event, "event_kind"), GFReplayTimeline.EVENT_SNAPSHOT, "追加事件类型应保留。")
	assert_almost_eq(GFVariantData.get_option_float(event, "time_seconds", 0.0), 1.2, 0.001, "追加事件应应用时间偏移。")


func test_region_map_tracks_dirty_regions() -> void:
	var region_map: GFRegionMap2D = GFRegionMap2D.new()
	region_map.region_size = Vector2i(4, 4)
	region_map.set_cell(Vector2i(1, 1), { "value": 1 })
	region_map.set_cell(Vector2i(5, 1), { "value": 2 })

	assert_eq(region_map.get_region_key_for_cell(Vector2i(5, 1)), Vector2i(1, 0), "格坐标应映射到区域键。")
	assert_eq(GFVariantData.get_option_int(GFVariantData.as_dictionary(region_map.get_cell(Vector2i(1, 1))), "value", 0), 1, "应能读取格子数据。")
	assert_eq(region_map.get_dirty_region_keys().size(), 2, "写入两个区域后应标记两个脏区。")

	region_map.clear_dirty(Vector2i(1, 0))

	assert_eq(region_map.get_dirty_region_keys().size(), 1, "清理指定区域后应只剩一个脏区。")


func _as_timed_text_track(value: Variant) -> GFTimedTextTrack:
	if value is GFTimedTextTrack:
		var track: GFTimedTextTrack = value
		return track
	return null
