extends GutTest


func test_async_tracker_is_disabled_by_default() -> void:
	var tracker: GFAsyncTrackerUtility = GFAsyncTrackerUtility.new()
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()

	var tracking_id: int = tracker.track_handle(completion, &"async.load")
	var snapshot: Dictionary = tracker.get_debug_snapshot()

	assert_eq(tracking_id, 0, "默认关闭时不应登记句柄。")
	assert_false(GFVariantData.get_option_bool(snapshot, "enabled"), "默认追踪状态应关闭。")
	assert_eq(GFVariantData.get_option_int(snapshot, "active_count"), 0, "关闭状态不应产生记录。")


func test_async_tracker_records_handles_and_dirty_state() -> void:
	var tracker: GFAsyncTrackerUtility = GFAsyncTrackerUtility.new()
	tracker.tracking_enabled = true
	tracker.stack_trace_enabled = true
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()

	var tracking_id: int = tracker.track_handle(
		completion,
		&"async.load",
		{ "scope": "loader" },
		Callable(completion, "get_debug_snapshot")
	)
	var records: Array[Dictionary] = tracker.get_active_records()
	var first_record: Dictionary = records[0]
	var metadata: Dictionary = GFVariantData.get_option_dictionary(first_record, "metadata")
	var snapshot: Dictionary = GFVariantData.get_option_dictionary(first_record, "snapshot")

	assert_gt(tracking_id, 0, "启用后应返回追踪 ID。")
	assert_true(tracker.check_and_reset_dirty(), "新增记录应设置 dirty。")
	assert_false(tracker.check_and_reset_dirty(), "读取 dirty 后应重置。")
	assert_eq(records.size(), 1, "应返回一条活动记录。")
	assert_eq(GFVariantData.get_option_string_name(first_record, "label"), &"async.load", "记录应保留标签。")
	assert_eq(GFVariantData.get_option_string(metadata, "scope"), "loader", "记录应保留元数据。")
	assert_false(snapshot.is_empty(), "有效快照 provider 应写入 snapshot。")
	assert_true(first_record.has("stack_trace"), "启用堆栈后记录应包含 stack_trace。")

	assert_true(tracker.untrack_id(tracking_id), "应能按 ID 移除记录。")
	assert_true(tracker.check_and_reset_dirty(), "移除记录应设置 dirty。")
	assert_eq(tracker.get_active_records().size(), 0, "移除后不应有活动记录。")


func test_async_tracker_clear_emits_untracked_for_each_record() -> void:
	var tracker: GFAsyncTrackerUtility = GFAsyncTrackerUtility.new()
	tracker.tracking_enabled = true
	var first: GFAsyncCompletion = GFAsyncCompletion.new()
	var second: GFAsyncCompletion = GFAsyncCompletion.new()
	var untracked_ids: PackedInt32Array = PackedInt32Array()
	var _connect_result: Error = tracker.async_handle_untracked.connect(func(tracking_id: int, _label: StringName) -> void:
		var _append_result: bool = untracked_ids.append(tracking_id)
	) as Error
	var first_id: int = tracker.track_handle(first, &"first")
	var second_id: int = tracker.track_handle(second, &"second")

	tracker.clear()

	assert_eq(untracked_ids.size(), 2, "clear 应为每条活动记录发出 untracked 信号。")
	assert_true(untracked_ids.has(first_id), "clear 应发出第一条记录的 untracked 信号。")
	assert_true(untracked_ids.has(second_id), "clear 应发出第二条记录的 untracked 信号。")
	assert_true(tracker.check_and_reset_dirty(), "clear 应设置 dirty，便于 UI 刷新。")
	assert_eq(tracker.get_active_records().size(), 0, "clear 后不应有活动记录。")


func test_diagnostics_utility_collects_async_tracker_tool_snapshot() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var tracker: GFAsyncTrackerUtility = GFAsyncTrackerUtility.new()
	tracker.tracking_enabled = true
	await arch.register_utility_instance(tracker)
	await arch.register_utility_instance(diagnostics)
	await arch.init()

	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _tracking_id: int = tracker.track_handle(completion, &"async.request")
	var snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_recent_logs": false,
	})
	var tools: Dictionary = GFVariantData.get_option_dictionary(snapshot, "tools")
	var tracker_snapshot: Dictionary = GFVariantData.get_option_dictionary(tools, &"async_tracker")

	assert_true(tools.has(&"async_tracker"), "诊断快照应采集已注册的异步追踪工具。")
	assert_eq(GFVariantData.get_option_int(tracker_snapshot, "active_count"), 1, "追踪工具快照应包含活动句柄数量。")

	arch.dispose()
