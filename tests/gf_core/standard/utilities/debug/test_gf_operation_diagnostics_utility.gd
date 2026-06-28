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


func test_operation_diagnostics_keeps_bounded_history() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.max_operations = 2
	diagnostics.max_incidents = 1

	var _first_operation: Dictionary = diagnostics.record_completed_operation(&"first", 1.0)
	var second_operation: Dictionary = diagnostics.record_completed_operation(&"second", 2.0)
	var third_operation: Dictionary = diagnostics.record_completed_operation(&"third", 3.0)
	var _first_incident: Dictionary = diagnostics.record_incident(GFOperationDiagnosticsUtility.SEVERITY_WARNING, &"first_warning")
	var second_incident: Dictionary = diagnostics.record_incident(GFOperationDiagnosticsUtility.SEVERITY_WARNING, &"second_warning")
	var operations: Array[Dictionary] = diagnostics.get_operations()
	var incidents: Array[Dictionary] = diagnostics.get_incidents()

	assert_eq(operations.size(), 2, "操作历史应受 max_operations 限制。")
	assert_eq(incidents.size(), 1, "事件历史应受 max_incidents 限制。")
	assert_true(diagnostics.has_operation(GFVariantData.get_option_string_name(second_operation, "operation_id")), "保留窗口内的操作仍应可查询。")
	assert_true(diagnostics.has_operation(GFVariantData.get_option_string_name(third_operation, "operation_id")), "最新操作应保留。")
	assert_false(diagnostics.has_operation(&"first:1"), "超出窗口的旧操作应被移除。")
	assert_eq(GFVariantData.get_option_string_name(incidents[0], "incident_id"), GFVariantData.get_option_string_name(second_incident, "incident_id"), "事件历史应保留最新事件。")


func test_operation_diagnostics_history_trim_preserves_running_operations() -> void:
	var diagnostics: GFOperationDiagnosticsUtility = GFOperationDiagnosticsUtility.new()
	diagnostics.max_operations = 2

	var running_id: StringName = diagnostics.begin_operation(&"install.package")
	var _second_operation: Dictionary = diagnostics.record_completed_operation(&"short.a", 1.0)
	var _third_operation: Dictionary = diagnostics.record_completed_operation(&"short.b", 1.0)
	var finished_running: Dictionary = diagnostics.finish_operation(running_id, true)

	assert_true(diagnostics.has_operation(running_id), "容量裁剪不应删除未完成操作。")
	assert_false(finished_running.is_empty(), "被容量压力覆盖后 running operation 仍应可完成。")
	assert_eq(GFVariantData.get_option_string_name(finished_running, "state"), &"completed", "完成后 running operation 应进入 completed。")


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
