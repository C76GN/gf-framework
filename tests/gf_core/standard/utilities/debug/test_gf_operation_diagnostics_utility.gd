extends GutTest


func test_operation_diagnostics_records_operation_phases_and_health() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.slow_operation_threshold_ms = 10.0

	var operation_id: StringName = diagnostics.begin_operation(&"tools.import", {
		"component": &"importer",
		"metadata": {
			"source": "fixture",
		},
		"started_ticks_usec": 1000,
	})
	var phase: Dictionary = diagnostics.record_phase(operation_id, &"parse", 5.5, {
		"metadata": {
			"rows": 3,
		},
	})
	var operation: Dictionary = diagnostics.finish_operation(operation_id, true, {
		"ended_ticks_usec": 22000,
		"metadata": {
			"output": "ok",
		},
	})
	var health: Dictionary = diagnostics.get_health_snapshot()
	var phases: Array = GFVariantData.get_option_array(operation, "phases")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(operation, "metadata")

	assert_false(operation_id == &"", "有效操作应生成操作 ID。")
	assert_eq(GFVariantData.get_option_string_name(phase, "phase_id"), &"parse", "阶段记录应保留阶段 ID。")
	assert_eq(GFVariantData.get_option_string_name(operation, "state"), &"completed", "成功完成的操作应标记为 completed。")
	assert_eq(phases.size(), 1, "操作应包含阶段记录。")
	assert_eq(GFVariantData.get_option_string(metadata, "source"), "fixture", "完成操作时应保留初始 metadata。")
	assert_eq(GFVariantData.get_option_string(metadata, "output"), "ok", "完成操作时应合并最终 metadata。")
	assert_eq(GFVariantData.get_option_int(health, "slow_operation_count"), 1, "超过阈值的操作应计入慢操作。")
	assert_eq(GFVariantData.get_option_string_name(health, "status"), &"warning", "只有慢操作时健康状态应为 warning。")


func test_operation_diagnostics_records_state_trace_progress_and_user_action() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.max_state_trace_entries = 2

	var operation_id: StringName = diagnostics.begin_operation(&"package.install", {
		"component": &"package_manager",
	})
	var _pending: Dictionary = diagnostics.record_state_snapshot(
		operation_id,
		&"resolve",
		GFOperationDiagnosticsUtility.STATE_RUNNING,
		{
			"progress": 0.25,
			"attempt": 1,
			"max_attempts": 3,
		}
	)
	var retrying: Dictionary = diagnostics.record_state_snapshot(
		operation_id,
		&"download",
		GFOperationDiagnosticsUtility.STATE_RETRYING,
		{
			"progress": 0.5,
			"attempt": 2,
			"max_attempts": 3,
			"error": "checksum",
		}
	)
	var waiting: Dictionary = diagnostics.record_state_snapshot(
		operation_id,
		&"confirm",
		GFOperationDiagnosticsUtility.STATE_WAITING_FOR_USER,
		{
			"progress": 0.75,
			"user_action_required": true,
		}
	)
	var operation: Dictionary = diagnostics.get_operation(operation_id)
	var trace: Array[Dictionary] = diagnostics.get_operation_state_trace(operation_id)
	var health: Dictionary = diagnostics.get_health_snapshot()

	assert_eq(GFVariantData.get_option_string_name(retrying, "status"), GFOperationDiagnosticsUtility.STATE_RETRYING, "状态轨迹应记录 retrying。")
	assert_true(GFVariantData.get_option_bool(waiting, "user_action_required"), "等待用户状态应记录决策点。")
	assert_eq(trace.size(), 2, "状态轨迹应受 max_state_trace_entries 限制。")
	assert_eq(GFVariantData.get_option_string_name(trace[0], "state_id"), &"download", "超过上限时应保留较新的状态。")
	assert_eq(GFVariantData.get_option_string_name(operation, "current_state_id"), &"confirm", "操作记录应更新当前状态 ID。")
	assert_eq(GFVariantData.get_option_float(operation, "progress"), 0.75, "操作记录应保留最近进度。")
	assert_eq(GFVariantData.get_option_string(operation, "last_error"), "checksum", "操作记录应保留最近错误文本。")
	assert_eq(GFVariantData.get_option_int(health, "user_action_required_count"), 1, "健康快照应统计等待用户决策的操作。")


func test_operation_diagnostics_deduplicates_incidents_and_filters_timeline() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()

	var first: Dictionary = diagnostics.record_incident(
		GFOperationDiagnosticsUtility.SEVERITY_ERROR,
		&"config_invalid",
		"Config failed.",
		{
			"category": &"config",
			"component": &"loader",
			"metadata": {
				"path": "a.cfg",
			},
		}
	)
	var second: Dictionary = diagnostics.record_incident(
		GFOperationDiagnosticsUtility.SEVERITY_ERROR,
		&"config_invalid",
		"Config failed.",
		{
			"category": &"config",
			"component": &"loader",
			"metadata": {
				"line": 12,
			},
		}
	)
	var health: Dictionary = diagnostics.get_health_snapshot()
	var incidents: Array[Dictionary] = diagnostics.get_incidents(0, {
		"category": &"config",
	})
	var timeline: Array[Dictionary] = diagnostics.get_timeline(0, {
		"entry_type": &"incident",
		"component": &"loader",
	})
	var metadata: Dictionary = GFVariantData.get_option_dictionary(second, "metadata")

	assert_eq(GFVariantData.get_option_string_name(first, "incident_id"), GFVariantData.get_option_string_name(second, "incident_id"), "相同事件应聚合到同一个 incident。")
	assert_eq(GFVariantData.get_option_int(second, "occurrence_count"), 2, "重复事件应增加 occurrence_count。")
	assert_eq(GFVariantData.get_option_string(metadata, "path"), "a.cfg", "重复事件应保留原始 metadata。")
	assert_eq(GFVariantData.get_option_int(metadata, "line"), 12, "重复事件应合并新 metadata。")
	assert_eq(incidents.size(), 1, "过滤后的异常列表应只包含匹配事件。")
	assert_eq(timeline.size(), 1, "时间线过滤应支持 entry_type 和 component。")
	assert_eq(GFVariantData.get_option_string_name(health, "status"), &"error", "错误事件应把健康状态提升到 error。")


func test_operation_diagnostics_records_async_snapshots() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()

	var pending_operation: Dictionary = diagnostics.record_async_snapshot(&"async.load", {
		"completed": false,
		"status": &"pending",
	}, {
		"component": &"loader",
	})
	var failed_operation: Dictionary = diagnostics.record_async_snapshot(&"async.load", {
		"completed": true,
		"failed": true,
		"status": &"failed",
		"error": "network",
		"duration_msec": 25,
	}, {
		"component": &"loader",
	})
	var incidents: Array[Dictionary] = diagnostics.get_incidents(0, {
		"category": &"async",
		"code": &"async_failed",
	})
	var pending_metadata: Dictionary = GFVariantData.get_option_dictionary(pending_operation, "metadata")
	var failed_metadata: Dictionary = GFVariantData.get_option_dictionary(failed_operation, "metadata")

	assert_eq(GFVariantData.get_option_string_name(pending_operation, "state"), &"running", "pending async snapshot 应记录为 running 操作。")
	assert_eq(GFVariantData.get_option_string_name(failed_operation, "state"), &"failed", "失败 async snapshot 应记录为 failed 操作。")
	assert_eq(GFVariantData.get_option_float(failed_operation, "duration_ms"), 25.0, "异步耗时应进入操作记录。")
	assert_true(pending_metadata.has("async_snapshot"), "pending 操作 metadata 应包含原始 snapshot。")
	assert_true(failed_metadata.has("async_snapshot"), "failed 操作 metadata 应包含原始 snapshot。")
	assert_eq(incidents.size(), 1, "失败异步快照应记录 async incident。")
	assert_eq(GFVariantData.get_option_string(incidents[0], "message"), "network", "incident 应优先使用 snapshot error。")


func test_operation_diagnostics_json_compatible_export_redacts_raw_metadata() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	var operation: Dictionary = diagnostics.record_async_snapshot(&"async.load", {
		"completed": false,
		"owner": self,
		"path": "res://private/debug.json",
		"unstable": NAN,
	}, {
		"component": &"loader",
		"metadata": {
			"owner": self,
			"path": "res://private/debug.json",
		},
	})

	var exported: Dictionary = diagnostics.to_json_compatible_record(operation)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(exported, "metadata")
	var async_snapshot: Dictionary = GFVariantData.get_option_dictionary(metadata, "async_snapshot")
	var owner_marker: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(async_snapshot, "owner"),
		"__gf_report_value__"
	)
	var json_text: String = JSON.stringify(exported)

	assert_true(GFVariantData.get_option_bool(owner_marker, "redacted"), "JSON-safe 导出应脱敏运行时对象。")
	assert_eq(GFVariantData.get_option_string(metadata, "path"), "<redacted_path>", "metadata 路径默认应脱敏。")
	assert_eq(GFVariantData.get_option_string(async_snapshot, "path"), "<redacted_path>", "async snapshot 路径默认应脱敏。")
	assert_true(json_text.contains("\"Float\""), "非有限 float 应通过 typed marker 输出。")
	assert_false(json_text.contains(":null"), "JSON-safe 导出不应触发 NaN -> null。")


func test_operation_diagnostics_updates_existing_async_operation_id() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()

	var pending_operation: Dictionary = diagnostics.record_async_snapshot(&"async.load", {
		"completed": false,
		"status": &"pending",
		"progress": 0.25,
	}, {
		"operation_id": &"asset_main_menu",
		"component": &"loader",
	})
	var completed_operation: Dictionary = diagnostics.record_async_snapshot(&"async.load", {
		"completed": true,
		"succeeded": true,
		"status": &"completed",
		"duration_msec": 12,
	}, {
		"operation_id": &"asset_main_menu",
		"component": &"loader",
	})
	var health: Dictionary = diagnostics.get_health_snapshot()

	assert_eq(GFVariantData.get_option_string_name(pending_operation, "operation_id"), &"asset_main_menu", "pending 快照应使用稳定 operation_id。")
	assert_eq(GFVariantData.get_option_string_name(completed_operation, "operation_id"), &"asset_main_menu", "terminal 快照应完成同一个 operation_id。")
	assert_eq(diagnostics.get_operations().size(), 1, "同一 operation_id 的 async 生命周期不应生成重复操作。")
	assert_eq(GFVariantData.get_option_string_name(completed_operation, "state"), &"completed", "terminal 快照应更新原操作状态。")
	assert_eq(GFVariantData.get_option_int(health, "open_operation_count"), 0, "terminal 快照后不应残留 running 操作。")


func test_operation_diagnostics_records_cancelled_async_snapshot_as_cancelled() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()

	var _pending_operation: Dictionary = diagnostics.record_async_snapshot(&"async.load", {
		"completed": false,
		"status": &"pending",
	}, {
		"operation_id": &"asset_cancelled",
		"component": &"loader",
	})
	var cancelled_operation: Dictionary = diagnostics.record_async_snapshot(&"async.load", {
		"completed": true,
		"cancelled": true,
		"status": &"cancelled",
		"cancel_reason": &"user",
		"duration_msec": 8,
	}, {
		"operation_id": &"asset_cancelled",
		"component": &"loader",
	})
	var health: Dictionary = diagnostics.get_health_snapshot()
	var incidents: Array[Dictionary] = diagnostics.get_incidents(0, {
		"category": &"async",
		"code": &"async_cancelled",
	})

	assert_eq(GFVariantData.get_option_string_name(cancelled_operation, "state"), &"cancelled", "取消的 async 快照应记录为 cancelled 终态。")
	assert_eq(GFVariantData.get_option_string_name(cancelled_operation, "current_state_status"), GFOperationDiagnosticsUtility.STATE_CANCELLED, "取消终态应保留 cancelled 状态语义。")
	assert_false(GFVariantData.get_option_bool(cancelled_operation, "success"), "取消不应被记录为成功。")
	assert_eq(GFVariantData.get_option_int(health, "failed_operation_count"), 0, "取消操作不应计入 failed operation。")
	assert_eq(GFVariantData.get_option_int(health, "open_operation_count"), 0, "取消操作不应残留为 open operation。")
	assert_eq(incidents.size(), 1, "取消异步快照应记录 async_cancelled incident。")
	assert_eq(GFVariantData.get_option_string_name(incidents[0], "severity"), GFOperationDiagnosticsUtility.SEVERITY_WARNING, "取消 incident 应保持 warning 级别。")


func test_operation_diagnostics_records_sample_stats_and_health() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.slow_operation_threshold_ms = 10.0

	var first_sample: Dictionary = diagnostics.record_sample(&"tools.parse", 4.0, {
		"component": &"importer",
		"metadata": {
			"rows": 2,
		},
	})
	var second_sample: Dictionary = diagnostics.record_sample(&"tools.parse", 12.0, {
		"component": &"importer",
		"metadata": {
			"chunks": 3,
		},
	})
	var health: Dictionary = diagnostics.get_health_snapshot()
	var debug_snapshot: Dictionary = diagnostics.get_debug_snapshot()
	var metadata: Dictionary = GFVariantData.get_option_dictionary(second_sample, "metadata")
	var slowest_sample: Dictionary = GFVariantData.get_option_dictionary(health, "slowest_sample")

	assert_eq(GFVariantData.get_option_int(first_sample, "sample_count"), 1, "首次采样应创建统计。")
	assert_eq(GFVariantData.get_option_int(second_sample, "sample_count"), 2, "同一 sample_id 应聚合调用次数。")
	assert_eq(GFVariantData.get_option_float(second_sample, "total_duration_ms"), 16.0, "采样统计应累计总耗时。")
	assert_eq(GFVariantData.get_option_float(second_sample, "average_duration_ms"), 8.0, "采样统计应计算平均耗时。")
	assert_eq(GFVariantData.get_option_float(second_sample, "min_duration_ms"), 4.0, "采样统计应保留最小耗时。")
	assert_eq(GFVariantData.get_option_float(second_sample, "max_duration_ms"), 12.0, "采样统计应保留最大耗时。")
	assert_eq(GFVariantData.get_option_int(second_sample, "slow_sample_count"), 1, "超过阈值的采样应计入慢采样。")
	assert_eq(GFVariantData.get_option_int(metadata, "rows"), 2, "采样 metadata 应保留首次写入字段。")
	assert_eq(GFVariantData.get_option_int(metadata, "chunks"), 3, "采样 metadata 应合并后续写入字段。")
	assert_eq(GFVariantData.get_option_int(health, "sample_stat_count"), 1, "健康快照应包含采样统计数量。")
	assert_eq(GFVariantData.get_option_int(health, "slow_sample_count"), 1, "健康快照应包含慢采样数量。")
	assert_eq(GFVariantData.get_option_string_name(health, "status"), &"warning", "慢采样应把健康状态提升为 warning。")
	assert_eq(GFVariantData.get_option_string_name(slowest_sample, "sample_id"), &"tools.parse", "健康快照应包含最慢采样统计。")
	assert_eq(GFVariantData.get_option_int(debug_snapshot, "sample_stat_count"), 1, "调试快照应包含采样统计数量。")


func test_operation_diagnostics_records_samples_from_ticks_and_filters() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()

	var first_sample: Dictionary = diagnostics.record_sample_from_ticks(&"tools.read", 1000, {
		"component": &"loader",
		"ended_ticks_usec": 6000,
	})
	var _second_sample: Dictionary = diagnostics.record_sample(&"tools.write", 3.0, {
		"component": &"writer",
	})
	var loader_stats: Array[Dictionary] = diagnostics.get_sample_stats(0, {
		"component": &"loader",
	})
	var write_stats: Array[Dictionary] = diagnostics.get_sample_stats(0, {
		"sample_id": &"tools.write",
	})
	var read_stat: Dictionary = diagnostics.get_sample_stat(&"tools.read")
	var removed_count: int = diagnostics.clear_sample_stats(&"tools.read")

	assert_eq(GFVariantData.get_option_float(first_sample, "last_duration_ms"), 5.0, "tick 采样应按微秒差换算毫秒。")
	assert_eq(loader_stats.size(), 1, "采样统计应支持 component 过滤。")
	assert_eq(write_stats.size(), 1, "采样统计应支持 sample_id 过滤。")
	assert_eq(GFVariantData.get_option_string_name(read_stat, "sample_id"), &"tools.read", "单项读取应返回采样统计。")
	assert_eq(removed_count, 1, "指定 sample_id 清理应返回移除数量。")
	assert_true(diagnostics.get_sample_stat(&"tools.read").is_empty(), "指定采样统计清理后不应继续存在。")


func test_operation_diagnostics_keeps_bounded_sample_stats() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.max_sample_stats = 2

	var _first_sample: Dictionary = diagnostics.record_sample(&"sample.first", 1.0)
	var second_sample: Dictionary = diagnostics.record_sample(&"sample.second", 2.0)
	var third_sample: Dictionary = diagnostics.record_sample(&"sample.third", 3.0)
	var stats: Array[Dictionary] = diagnostics.get_sample_stats()
	diagnostics.max_sample_stats = 0
	var disabled_sample: Dictionary = diagnostics.record_sample(&"sample.disabled", 1.0)

	assert_eq(stats.size(), 2, "采样统计应受 max_sample_stats 限制。")
	assert_true(diagnostics.get_sample_stat(&"sample.first").is_empty(), "超出窗口的旧采样统计应被移除。")
	assert_eq(GFVariantData.get_option_string_name(second_sample, "sample_id"), &"sample.second", "保留窗口内采样统计应仍可读取。")
	assert_eq(GFVariantData.get_option_string_name(third_sample, "sample_id"), &"sample.third", "最新采样统计应保留。")
	assert_true(disabled_sample.is_empty(), "禁用采样统计后 record_sample 应返回空字典。")
	assert_true(diagnostics.get_sample_stats().is_empty(), "禁用采样统计应清空已记录统计。")


func test_operation_diagnostics_keeps_bounded_history() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.max_completed_operations = 2
	diagnostics.max_incidents = 1

	var _first_operation: Dictionary = diagnostics.record_completed_operation(&"first", 1.0)
	var second_operation: Dictionary = diagnostics.record_completed_operation(&"second", 2.0)
	var third_operation: Dictionary = diagnostics.record_completed_operation(&"third", 3.0)
	var _first_incident: Dictionary = diagnostics.record_incident(GFOperationDiagnosticsUtility.SEVERITY_WARNING, &"first_warning")
	var second_incident: Dictionary = diagnostics.record_incident(GFOperationDiagnosticsUtility.SEVERITY_WARNING, &"second_warning")
	var operations: Array[Dictionary] = diagnostics.get_operations()
	var incidents: Array[Dictionary] = diagnostics.get_incidents()

	assert_eq(operations.size(), 2, "完成操作历史应受 max_completed_operations 限制。")
	assert_eq(incidents.size(), 1, "事件历史应受 max_incidents 限制。")
	assert_true(diagnostics.has_operation(GFVariantData.get_option_string_name(second_operation, "operation_id")), "保留窗口内的操作仍应可查询。")
	assert_true(diagnostics.has_operation(GFVariantData.get_option_string_name(third_operation, "operation_id")), "最新操作应保留。")
	assert_false(diagnostics.has_operation(&"first:1"), "超出窗口的旧操作应被移除。")
	assert_eq(GFVariantData.get_option_string_name(incidents[0], "incident_id"), GFVariantData.get_option_string_name(second_incident, "incident_id"), "事件历史应保留最新事件。")


func test_operation_diagnostics_keeps_recently_repeated_incidents() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.max_incidents = 2

	var _first_a: Dictionary = diagnostics.record_incident(
		GFOperationDiagnosticsUtility.SEVERITY_ERROR,
		&"incident.a"
	)
	var _first_b: Dictionary = diagnostics.record_incident(
		GFOperationDiagnosticsUtility.SEVERITY_ERROR,
		&"incident.b"
	)
	var repeated_a: Dictionary = diagnostics.record_incident(
		GFOperationDiagnosticsUtility.SEVERITY_ERROR,
		&"incident.a"
	)
	var _first_c: Dictionary = diagnostics.record_incident(
		GFOperationDiagnosticsUtility.SEVERITY_ERROR,
		&"incident.c"
	)
	var incidents: Array[Dictionary] = diagnostics.get_incidents()
	var retained_codes: PackedStringArray = PackedStringArray()
	for incident: Dictionary in incidents:
		var _appended: bool = retained_codes.append(
			String(GFVariantData.get_option_string_name(incident, "code"))
		)

	assert_eq(incidents.size(), 2, "incident 历史仍应遵守容量上限。")
	assert_true(retained_codes.has("incident.a"), "刚刚重复发生的 incident 不应按首次插入位置淘汰。")
	assert_true(retained_codes.has("incident.c"), "最新的新 incident 应被保留。")
	assert_false(retained_codes.has("incident.b"), "last_sequence 最旧的 incident 应先被淘汰。")
	assert_eq(
		GFVariantData.get_option_int(repeated_a, "occurrence_count"),
		2,
		"重复 incident 的聚合计数应保持正确。"
	)


func test_operation_diagnostics_terminal_state_is_idempotent_and_rejects_late_mutation() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	var operation_id: StringName = diagnostics.begin_operation(&"terminal.guard")
	var terminal: Dictionary = diagnostics.finish_operation(operation_id, false, {
		"duration_ms": 12.0,
		"metadata": {
			"winner": "first",
		},
	})
	var repeated_finish: Dictionary = diagnostics.finish_operation(operation_id, true, {
		"duration_ms": 1.0,
		"metadata": {
			"winner": "late",
		},
	})
	var late_phase: Dictionary = diagnostics.record_phase(operation_id, &"late", 1.0)
	var late_state: Dictionary = diagnostics.record_state_snapshot(
		operation_id,
		&"late",
		GFOperationDiagnosticsUtility.STATE_RUNNING
	)
	var retained: Dictionary = diagnostics.get_operation(operation_id)

	assert_eq(repeated_finish, terminal, "重复 finish 应幂等返回首次终态，而不是改写历史。")
	assert_true(late_phase.is_empty(), "终态后的 phase 必须稳定拒绝。")
	assert_true(late_state.is_empty(), "终态后的 state snapshot 必须稳定拒绝。")
	assert_eq(retained, terminal, "所有迟到回调之后，保留的终态记录必须字节等价不变。")
	assert_eq(GFVariantData.get_option_string_name(retained, "state"), &"failed", "首次失败终态不可逆。")
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(retained, "metadata"),
			"winner"
		),
		"first",
		"迟到 finish 不得合并 metadata。"
	)


func test_operation_diagnostics_async_terminal_uses_first_terminal_snapshot() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	var _pending: Dictionary = diagnostics.record_async_snapshot(&"async.race", {
		"status": &"pending",
	}, {
		"operation_id": &"async_race",
	})
	var failed: Dictionary = diagnostics.record_async_snapshot(&"async.race", {
		"completed": true,
		"failed": true,
		"error": "timeout",
	}, {
		"operation_id": &"async_race",
	})
	var late_success: Dictionary = diagnostics.record_async_snapshot(&"async.race", {
		"completed": true,
		"success": true,
	}, {
		"operation_id": &"async_race",
	})
	var incidents: Array[Dictionary] = diagnostics.get_incidents()

	assert_eq(late_success, failed, "异步竞态中的迟到成功不得覆盖首次失败终态。")
	assert_eq(GFVariantData.get_option_string_name(late_success, "state"), &"failed", "异步终态必须单调。")
	assert_eq(incidents.size(), 1, "迟到终态不应额外制造与保留终态矛盾的 incident。")
	assert_eq(
		GFVariantData.get_option_string_name(incidents[0], "code"),
		&"async_failed",
		"incident 应与首次提交的终态保持一致。"
	)


func test_operation_diagnostics_keeps_bounded_phase_history() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.max_phases_per_operation = 2
	var operation_id: StringName = diagnostics.begin_operation(&"phase.guard")

	var _first: Dictionary = diagnostics.record_phase(operation_id, &"first", 1.0)
	var _second: Dictionary = diagnostics.record_phase(operation_id, &"second", 2.0)
	var _third: Dictionary = diagnostics.record_phase(operation_id, &"third", 3.0)
	var retained: Dictionary = diagnostics.get_operation(operation_id)
	var phases: Array = GFVariantData.get_option_array(retained, "phases")

	assert_eq(phases.size(), 2, "单条 operation 的 phase 历史应遵守独立上限。")
	assert_eq(
		GFVariantData.get_option_string_name(GFVariantData.as_dictionary(phases[0]), "phase_id"),
		&"second",
		"phase 窗口应保留最近记录。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(GFVariantData.as_dictionary(phases[1]), "phase_id"),
		&"third",
		"最新 phase 应位于窗口末尾。"
	)
	assert_eq(
		GFVariantData.get_option_int(retained, "dropped_phase_count"),
		1,
		"phase 淘汰必须通过累计计数可观察。"
	)

	diagnostics.max_phases_per_operation = 1
	retained = diagnostics.get_operation(operation_id)
	phases = GFVariantData.get_option_array(retained, "phases")
	assert_eq(phases.size(), 1, "降低 phase 上限时应立即收紧既有记录。")
	assert_eq(
		GFVariantData.get_option_int(retained, "dropped_phase_count"),
		2,
		"配置收紧造成的淘汰也必须计入 dropped_phase_count。"
	)


func test_operation_diagnostics_zero_completed_history_keeps_only_active_operations() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.max_completed_operations = 0

	var operation_id: StringName = diagnostics.begin_operation(&"active")
	var completed: Dictionary = diagnostics.record_completed_operation(&"disabled.completed", 1.0)
	var operations_before_finish: Array[Dictionary] = diagnostics.get_operations()
	var finished: Dictionary = diagnostics.finish_operation(operation_id)

	assert_ne(operation_id, &"", "关闭完成历史不应阻止活动操作追踪。")
	assert_false(completed.is_empty(), "关闭完成历史时直接记录仍应返回本次完成结果。")
	assert_eq(operations_before_finish.size(), 1, "关闭完成历史时只应保留仍活动的操作。")
	assert_false(finished.is_empty(), "活动操作应仍可正常结束。")
	assert_true(diagnostics.get_operations().is_empty(), "完成历史关闭后，终态操作不应继续驻留。")


func test_operation_diagnostics_rejects_active_operations_over_capacity() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.max_active_operations = 2

	var first_id: StringName = diagnostics.begin_operation(&"first")
	var second_id: StringName = diagnostics.begin_operation(&"second")
	var rejected_id: StringName = diagnostics.begin_operation(&"third")
	var health: Dictionary = diagnostics.get_health_snapshot()

	assert_ne(first_id, &"", "活动容量内的第一条操作应被接受。")
	assert_ne(second_id, &"", "活动容量内的第二条操作应被接受。")
	assert_eq(rejected_id, &"", "超过活动容量的新操作应被拒绝。")
	assert_eq(diagnostics.get_operations().size(), 2, "全部活动时也不能绕过容量上限。")
	assert_eq(GFVariantData.get_option_int(health, "rejected_active_operation_count"), 1, "容量拒绝应可观察。")
	assert_eq(GFVariantData.get_option_string_name(health, "status"), &"warning", "发生容量拒绝时健康状态应告警。")


func test_operation_diagnostics_history_trim_preserves_running_operations() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.max_completed_operations = 2

	var running_id: StringName = diagnostics.begin_operation(&"install.package")
	var _second_operation: Dictionary = diagnostics.record_completed_operation(&"short.a", 1.0)
	var _third_operation: Dictionary = diagnostics.record_completed_operation(&"short.b", 1.0)
	var finished_running: Dictionary = diagnostics.finish_operation(running_id, true)

	assert_true(diagnostics.has_operation(running_id), "容量裁剪不应删除未完成操作。")
	assert_false(finished_running.is_empty(), "被容量压力覆盖后 running operation 仍应可完成。")
	assert_eq(GFVariantData.get_option_string_name(finished_running, "state"), &"completed", "完成后 running operation 应进入 completed。")


func test_operation_diagnostics_rejects_non_finite_numeric_inputs_without_mutation() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	var operation_id: StringName = diagnostics.begin_operation(&"finite.guard")
	var rejected_phase: Dictionary = diagnostics.record_phase(operation_id, &"bad", INF)
	var rejected_state: Dictionary = diagnostics.record_state_snapshot(operation_id, &"bad", GFOperationDiagnosticsUtility.STATE_RUNNING, {
		"progress": NAN,
	})
	var rejected_finish: Dictionary = diagnostics.finish_operation(operation_id, true, {
		"duration_ms": INF,
	})
	var rejected_sample: Dictionary = diagnostics.record_sample(&"bad.sample", NAN)
	var rejected_completed: Dictionary = diagnostics.record_completed_operation(&"bad.completed", INF)
	var operation: Dictionary = diagnostics.get_operation(operation_id)

	assert_true(rejected_phase.is_empty(), "非有限阶段耗时应被拒绝。")
	assert_true(rejected_state.is_empty(), "非有限进度应被拒绝。")
	assert_true(rejected_finish.is_empty(), "非有限完成耗时应被拒绝。")
	assert_true(rejected_sample.is_empty(), "非有限采样耗时应被拒绝。")
	assert_true(rejected_completed.is_empty(), "非有限直接完成耗时应被拒绝。")
	assert_eq(GFVariantData.get_option_string_name(operation, "state"), &"running", "被拒绝的完成输入不应改变操作状态。")
	assert_true(GFVariantData.get_option_array(operation, "phases").is_empty(), "被拒绝的阶段不应进入操作记录。")
	assert_true(diagnostics.get_sample_stats().is_empty(), "被拒绝的采样不应污染聚合统计。")


func test_operation_diagnostics_bounds_metadata_unique_keys() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.max_metadata_keys = 2
	var operation_id: StringName = diagnostics.begin_operation(&"metadata.guard", {
		"metadata": {
			"a": 1,
			"b": 2,
			"c": 3,
		},
	})
	var operation: Dictionary = diagnostics.finish_operation(operation_id, true, {
		"metadata": {
			"a": 10,
			"d": 4,
		},
	})
	var metadata: Dictionary = GFVariantData.get_option_dictionary(operation, "metadata")

	assert_eq(GFVariantData.get_option_int(metadata, "a"), 10, "覆盖已有 metadata 键不应消耗新额度。")
	assert_eq(GFVariantData.get_option_int(metadata, "b"), 2, "容量内的已有 metadata 键应保留。")
	assert_false(metadata.has("c"), "超过 metadata 唯一键预算的初始键应被丢弃。")
	assert_false(metadata.has("d"), "容量已满时新增 metadata 键应被丢弃。")
	assert_eq(GFVariantData.get_option_int(metadata, "__gf_dropped_key_count"), 2, "metadata 应累计报告丢弃的唯一键数量。")


func test_diagnostics_utility_collects_operation_diagnostics_tool_snapshot() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var diagnostics: GFDiagnosticsUtility = GFDiagnosticsUtility.new()
	var operation_diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	await arch.register_utility_instance(operation_diagnostics)
	await arch.register_utility_instance(diagnostics)
	await arch.init()

	var _operation: Dictionary = operation_diagnostics.record_completed_operation(&"tools.refresh", 3.0)
	var snapshot: Dictionary = diagnostics.collect_snapshot({
		"include_recent_logs": false,
	})
	var tools: Dictionary = GFVariantData.get_option_dictionary(snapshot, "tools")
	var operation_snapshot: Dictionary = GFVariantData.get_option_dictionary(tools, &"operation_diagnostics")
	var health: Dictionary = GFVariantData.get_option_dictionary(operation_snapshot, "health")

	assert_true(tools.has(&"operation_diagnostics"), "诊断快照应采集已注册的操作诊断工具。")
	assert_eq(GFVariantData.get_option_int(health, "operation_count"), 1, "操作诊断快照应包含健康摘要。")

	arch.dispose()
