## 测试 GFSupportReportWorkflow 的支持报告提交、离线入队与重放。
extends GutTest


# --- 私有变量 ---

var _storage_paths: Array[String] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for storage_path: String in _storage_paths:
		_remove_outbox_files(storage_path)
	_storage_paths.clear()


# --- 测试方法 ---

func test_workflow_queues_when_transport_is_missing_and_replays_later() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(GFSupportReportUtility.new(), outbox)
	var queued_result: Dictionary = workflow.submit_report("Offline", {
		"include_diagnostics": false,
		"include_scene": false,
		"metadata": {
			"screen": "menu",
		},
		"transport_options": {
			"channel": "qa",
		},
	})
	var captured_reports: Array[Dictionary] = []
	var _workflow_with_transport: GFSupportReportWorkflow = workflow.set_transport(func(report: Dictionary, options: Dictionary) -> Dictionary:
		captured_reports.append(report)
		return {
			"ok": true,
			"metadata": options.duplicate(true),
		}
	)

	var replay_result: Dictionary = await workflow.replay_queued()
	var captured_metadata: Dictionary = GFVariantData.get_option_dictionary(captured_reports[0], "metadata")
	var queue_result: Dictionary = GFVariantData.get_option_dictionary(queued_result, "queue_result")

	assert_eq(GFVariantData.get_option_string_name(queued_result, "status"), &"queued", "缺少 transport 时应进入离线队列。")
	assert_true(GFVariantData.get_option_bool(queue_result, "persisted"), "离线交接成功必须确认已持久化。")
	assert_true(FileAccess.file_exists(outbox.storage_path), "离线交接应创建独立测试事务文件。")
	assert_eq(outbox.get_queue_size(), 0, "重放成功后队列应清空。")
	assert_eq(GFVariantData.get_option_int(replay_result, "succeeded"), 1, "重放应成功提交一个报告。")
	assert_eq(captured_reports.size(), 1, "transport 应收到离线报告。")
	assert_eq(GFVariantData.get_option_string(captured_metadata, "screen"), "menu", "构建报告应保留元数据。")
	outbox.dispose()


func test_workflow_queues_failed_direct_submit() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(GFSupportReportUtility.new(), outbox)
	var _workflow_with_transport: GFSupportReportWorkflow = workflow.set_transport(func(_report: Dictionary, _options: Dictionary) -> Dictionary:
		return {
			"ok": false,
			"error": "offline",
		}
	)

	var result: Dictionary = workflow.submit_report("Submit", {
		"include_diagnostics": false,
		"include_scene": false,
	})
	var submit_result: Dictionary = GFVariantData.get_option_dictionary(result, "submit_result")

	assert_eq(GFVariantData.get_option_string_name(result, "status"), &"queued", "直接提交失败时应按默认策略入队。")
	assert_eq(GFVariantData.get_option_string(submit_result, "error"), "offline", "结果应保留直接提交失败原因。")
	assert_eq(outbox.get_queue_size(), 1, "失败报告应进入 outbox。")
	outbox.dispose()


func test_queue_report_forces_persistence_when_auto_persist_is_disabled() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	outbox.auto_persist = false
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)

	var result: Dictionary = workflow.queue_report({
		"report_id": "forced-persistence",
		"description": "offline",
	})

	assert_true(GFVariantData.get_option_bool(result, "ok"), "queue_report 应强制完成持久化检查点。")
	assert_true(GFVariantData.get_option_bool(result, "persisted"), "成功结果必须明确已经落盘。")
	assert_true(FileAccess.file_exists(outbox.storage_path), "即使关闭自动保存也应创建可靠事务。")
	outbox.dispose()


func test_queue_failure_is_propagated_without_success_notification() -> void:
	var outbox: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	outbox.storage_path = "res://gf_support_report_forbidden.json"
	outbox.auto_load_on_init = false
	outbox.auto_persist = false
	outbox.init()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)
	var queued_signal_count: Array[int] = [0]
	var _queued_connected: Error = workflow.workflow_report_queued.connect(
		func(_report: Dictionary, _envelope: GFRequestEnvelope) -> void:
			queued_signal_count[0] += 1
	) as Error
	var report: Dictionary = {
		"report_id": "must-not-drop",
		"description": "offline",
	}

	var queue_result: Dictionary = workflow.queue_report(report)
	var submit_result: Dictionary = workflow.submit_built_report(report)
	var propagated_queue_result: Dictionary = GFVariantData.get_option_dictionary(
		submit_result,
		"queue_result"
	)

	assert_false(GFVariantData.get_option_bool(queue_result, "ok"), "落盘失败时 queue_report 必须失败。")
	assert_eq(
		GFVariantData.get_option_string_name(queue_result, "reason"),
		&"persistence_failed",
		"queue_report 应传播 Outbox 的稳定原因。"
	)
	assert_eq(
		GFVariantData.get_option_int(queue_result, "persistence_error"),
		ERR_UNAUTHORIZED,
		"queue_report 应传播持久化错误码。"
	)
	assert_false(GFVariantData.get_option_bool(submit_result, "ok"), "缺少 transport 且落盘失败时提交必须失败。")
	assert_eq(
		GFVariantData.get_option_string_name(propagated_queue_result, "reason"),
		&"persistence_failed",
		"顶层提交结果不得丢弃失败的 queue_result。"
	)
	assert_eq(outbox.get_queue_size(), 0, "可靠入队失败必须回滚内存请求。")
	assert_eq(queued_signal_count[0], 0, "持久化失败不得发出 queued 成功通知。")
	outbox.dispose()


func test_workflow_queue_notification_runs_after_durable_receipt() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)
	var _queued_connected: Error = workflow.workflow_report_queued.connect(
		func(_report: Dictionary, _envelope: GFRequestEnvelope) -> void:
			outbox.clear_queue()
	) as Error

	var result: Dictionary = workflow.queue_report({
		"report_id": "listener-cleared",
		"description": "offline",
	})

	assert_true(GFVariantData.get_option_bool(result, "ok"), "成功后通知中的后续消费不应反转已完成的耐久回执。")
	assert_eq(
		GFVariantData.get_option_string_name(result, "reason"),
		&"queued",
		"Workflow 成功后通知仍应保留原始 queued 回执。"
	)
	assert_true(GFVariantData.get_option_bool(result, "persisted"), "通知前的 Outbox 交接必须已经可靠持久化。")
	assert_eq(outbox.get_queue_size(), 0, "成功后监听器可作为后续操作清理队列。")
	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = outbox.storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	assert_eq(loaded.load_queue(), OK, "监听器清理应留下可读取的检查点。")
	assert_eq(loaded.get_queue_size(), 0, "重启不得恢复已被同步监听器清理的报告。")
	loaded.dispose()
	outbox.dispose()


func test_queue_report_clamps_retry_attempts_to_safe_range() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)

	var minimum_result: Dictionary = workflow.queue_report(
		{ "report_id": "minimum" },
		{ "max_attempts": 0 }
	)
	var maximum_result: Dictionary = workflow.queue_report(
		{ "report_id": "maximum" },
		{ "max_attempts": 1000 }
	)
	var pending_requests: Array[GFRequestEnvelope] = outbox.get_pending_requests()

	assert_true(GFVariantData.get_option_bool(minimum_result, "ok"), "最小边界请求应可靠入队。")
	assert_true(GFVariantData.get_option_bool(maximum_result, "ok"), "最大边界请求应可靠入队。")
	assert_eq(pending_requests[0].max_attempts, 1, "非正尝试次数应钳制为 1。")
	assert_eq(pending_requests[1].max_attempts, 64, "尝试次数应钳制到 64 的硬上限。")
	outbox.dispose()


func test_workflow_queue_listener_observes_count_and_dispose_keeps_it_reset() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)
	var observed_queued_count: Array[int] = [-1]
	var on_workflow_report_queued: Callable = func(
		_report: Dictionary,
		_envelope: GFRequestEnvelope
	) -> void:
		observed_queued_count[0] = GFVariantData.get_option_int(
			workflow.get_debug_snapshot(),
			"reports_queued_count"
		)
		workflow.dispose()
	var _queued_connected: Error = workflow.workflow_report_queued.connect(
		on_workflow_report_queued
	) as Error

	var result: Dictionary = workflow.queue_report({
		"report_id": "listener-disposed",
		"description": "offline",
	})

	assert_true(GFVariantData.get_option_bool(result, "ok"), "通知中的 dispose 不应反转既有耐久回执。")
	assert_eq(observed_queued_count[0], 1, "queued 监听器应看到已经提交的计数。")
	assert_eq(
		GFVariantData.get_option_int(workflow.get_debug_snapshot(), "reports_queued_count"),
		0,
		"监听器 dispose 后不得由通知尾部重新写回旧计数。"
	)
	assert_eq(outbox.get_queue_size(), 1, "工作流 dispose 不得撤销外部 Outbox 的耐久所有权。")
	workflow.workflow_report_queued.disconnect(on_workflow_report_queued)
	outbox.dispose()


func test_replay_completion_after_dispose_is_stale_and_does_not_revive_workflow() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)
	var queue_result: Dictionary = workflow.queue_report({
		"report_id": "dispose-during-replay",
		"description": "offline",
	})
	var transport: ManualWorkflowTransport = ManualWorkflowTransport.new()
	var _configured_workflow: GFSupportReportWorkflow = workflow.set_transport(
		Callable(transport, "send")
	)
	var completion_count: Array[int] = [0]
	var _completion_connected: Error = workflow.workflow_replay_completed.connect(
		func(_result: Dictionary) -> void:
			completion_count[0] += 1
	) as Error
	var replay_state: WorkflowReplayState = WorkflowReplayState.new()
	@warning_ignore("missing_await")
	_await_workflow_replay(workflow, replay_state)
	await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(queue_result, "ok"), "测试报告应先可靠入队。")
	assert_eq(transport.captured_reports.size(), 1, "replay 应已进入可控的异步 transport。")
	workflow.dispose()
	transport.emit_success()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(replay_state.done, "底层 transport 结束后旧 replay 调用应有限完成。")
	assert_true(
		GFVariantData.get_option_bool(replay_state.report, "workflow_stale"),
		"dispose 前启动的 replay 结果必须显式标记为 stale。"
	)
	assert_false(GFVariantData.get_option_bool(replay_state.report, "ok"), "stale replay 不得伪装为当前 workflow 成功。")
	assert_eq(
		GFVariantData.get_option_string(replay_state.report, "reason"),
		"workflow_lifecycle_changed",
		"stale replay 应返回稳定原因。"
	)
	assert_eq(completion_count[0], 0, "dispose 后不得发出 workflow_replay_completed。")
	assert_eq(
		GFVariantData.get_option_int(workflow.get_debug_snapshot(), "replay_completed_count"),
		0,
		"dispose 后旧 continuation 不得复活 replay 计数。"
	)
	outbox.dispose()


func test_queue_report_persists_final_retry_and_idempotency_values_atomically() -> void:
	var storage_path: String = "user://gf_support_report_outbox_test_%d.json" % Time.get_ticks_usec()
	var outbox: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	outbox.storage_path = storage_path
	outbox.auto_load_on_init = false
	outbox.auto_persist = true
	outbox.init()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)
	var queued_signal_envelope: Array[GFRequestEnvelope] = []
	var _queued_connected: Error = workflow.workflow_report_queued.connect(
		func(report: Dictionary, envelope: GFRequestEnvelope) -> void:
			report["report_id"] = "mutated-by-listener"
			envelope.idempotency_key = "mutated-by-listener"
			envelope.max_attempts = 1
			queued_signal_envelope.append(envelope)
	) as Error
	var queue_result: Dictionary = workflow.queue_report(
		{
			"report_id": "report-atomic",
			"description": "atomic",
		},
		{
			"max_attempts": 9,
			"idempotency_key": "support-operation-42",
		}
	)
	var result_envelope: GFRequestEnvelope = _variant_to_request_envelope(
		GFVariantData.get_option_value(queue_result, "envelope")
	)
	var pending_requests: Array[GFRequestEnvelope] = outbox.get_pending_requests()

	assert_true(GFVariantData.get_option_bool(queue_result, "ok"), "支持报告应通过原子入口入队。")
	assert_not_null(result_envelope, "入队结果应返回隔离请求快照。")
	assert_eq(queued_signal_envelope.size(), 1, "成功入队应发出一次 workflow 通知。")
	assert_eq(pending_requests[0].idempotency_key, "support-operation-42", "监听器不得改写队列幂等键。")
	assert_eq(pending_requests[0].max_attempts, 9, "监听器不得改写队列尝试上限。")
	assert_eq(
		GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(pending_requests[0].body, "report"),
			"report_id"
		),
		"report-atomic",
		"监听器不得改写持久化报告。"
	)

	var loaded: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	loaded.storage_path = storage_path
	loaded.auto_load_on_init = false
	loaded.auto_persist = false
	assert_eq(loaded.load_queue(), OK, "支持报告首次原子事务应可恢复。")
	var restored: GFRequestEnvelope = loaded.get_pending_requests()[0]
	assert_eq(restored.idempotency_key, "support-operation-42", "首次持久化应包含最终幂等键。")
	assert_eq(restored.max_attempts, 9, "首次持久化应包含最终尝试上限。")

	loaded.dispose()
	outbox.dispose()
	_remove_outbox_files(storage_path)


func test_queue_report_rejects_report_ids_that_cannot_be_replayed() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)
	var invalid_reports: Array[Dictionary] = [
		{ "description": "missing" },
		{ "report_id": "" },
		{ "report_id": 42 },
		{ "report_id": "report\u0001hidden" },
		{ "report_id": "x".repeat(4097) },
	]

	for report: Dictionary in invalid_reports:
		var result: Dictionary = workflow.queue_report(report)
		assert_false(GFVariantData.get_option_bool(result, "ok"), "不可重放的 report_id 必须在入队前拒绝。")
		assert_eq(
			GFVariantData.get_option_string_name(result, "reason"),
			&"invalid_report",
			"report_id 协议失败应返回稳定原因。"
		)
	assert_eq(outbox.get_queue_size(), 0, "入口协议失败不得留下永久不可重放请求。")
	outbox.dispose()


func test_handles_request_matches_the_queue_report_protocol() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)
	var queue_result: Dictionary = workflow.queue_report({
		"report_id": "protocol-match",
		"description": "offline",
	})
	var valid: GFRequestEnvelope = _variant_to_request_envelope(
		GFVariantData.get_option_value(queue_result, "envelope")
	)

	assert_not_null(valid, "成功入口应返回协议信封。")
	if valid == null:
		outbox.dispose()
		return
	assert_true(workflow.handles_request(valid), "queue_report 接受的信封必须可由同一工作流重放。")

	var wrong_method: GFRequestEnvelope = valid.duplicate_request()
	wrong_method.method = HTTPClient.METHOD_GET
	var extra_body: GFRequestEnvelope = valid.duplicate_request()
	extra_body.body["extra"] = true
	var mismatched_id: GFRequestEnvelope = valid.duplicate_request()
	mismatched_id.metadata["report_id"] = "other"
	var wrong_kind: GFRequestEnvelope = valid.duplicate_request()
	wrong_kind.metadata["request_kind"] = "other"
	var invalid_retry_state: GFRequestEnvelope = valid.duplicate_request()
	invalid_retry_state.attempt_count = -1
	for invalid: GFRequestEnvelope in [
		wrong_method,
		extra_body,
		mismatched_id,
		wrong_kind,
		invalid_retry_state,
	]:
		assert_false(workflow.handles_request(invalid), "篡改后的请求必须在共享边界 fail closed。")
	outbox.dispose()


func test_auto_wire_does_not_replace_an_existing_outbox_transport() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	var existing_transport: Callable = func(_envelope: GFRequestEnvelope) -> Dictionary:
		return { "ok": true }
	outbox.transport_callback = existing_transport
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)
	var _configured_workflow: GFSupportReportWorkflow = workflow.set_transport(
		func(_report: Dictionary, _options: Dictionary) -> Dictionary:
			return { "ok": true }
	)

	assert_eq(outbox.transport_callback, existing_transport, "工作流不得覆盖共享 Outbox 已安装的 transport。")
	outbox.dispose()


func test_auto_wire_releases_only_its_owned_outbox_binding() -> void:
	var first_outbox: GFRequestOutboxUtility = _make_outbox()
	var second_outbox: GFRequestOutboxUtility = _make_outbox()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		first_outbox
	)
	var transport: Callable = func(_report: Dictionary, _options: Dictionary) -> Dictionary:
		return { "ok": true }
	var _configured_workflow: GFSupportReportWorkflow = workflow.set_transport(transport)
	assert_true(first_outbox.transport_callback.is_valid(), "有效 transport 应自动绑定首个专用 Outbox。")

	var _configured_second_outbox: GFSupportReportWorkflow = workflow.setup(null, second_outbox)

	assert_false(first_outbox.transport_callback.is_valid(), "切换 Outbox 时必须解除工作流拥有的旧绑定。")
	assert_true(second_outbox.transport_callback.is_valid(), "切换后应绑定新的专用 Outbox。")

	var _configured_empty_transport: GFSupportReportWorkflow = workflow.set_transport(Callable())
	assert_false(second_outbox.transport_callback.is_valid(), "清空 transport 时必须解除工作流拥有的绑定。")

	var _configured_restored_transport: GFSupportReportWorkflow = workflow.set_transport(transport)
	assert_true(second_outbox.transport_callback.is_valid(), "恢复 transport 后应允许重新自动绑定。")
	workflow.auto_wire_outbox_transport = false
	assert_false(second_outbox.transport_callback.is_valid(), "关闭自动绑定时必须解除工作流拥有的绑定。")

	workflow.auto_wire_outbox_transport = true
	assert_true(second_outbox.transport_callback.is_valid(), "重新启用后应恢复自动绑定。")
	workflow.dispose()
	assert_false(second_outbox.transport_callback.is_valid(), "dispose 必须解除工作流拥有的最终绑定。")
	first_outbox.dispose()
	second_outbox.dispose()


func test_dispose_preserves_transport_replaced_after_auto_wire() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)
	var _configured_workflow: GFSupportReportWorkflow = workflow.set_transport(
		func(_report: Dictionary, _options: Dictionary) -> Dictionary:
			return { "ok": true }
	)
	assert_true(outbox.transport_callback.is_valid(), "有效 transport 应先自动绑定专用 Outbox。")

	var project_transport: Callable = func(_envelope: GFRequestEnvelope) -> Dictionary:
		return { "ok": true }
	outbox.transport_callback = project_transport
	workflow.dispose()

	assert_eq(
		outbox.transport_callback,
		project_transport,
		"项目替换自动绑定后，dispose 不得清除项目拥有的 transport。"
	)
	outbox.dispose()


func test_auto_wired_transport_rejects_unrelated_requests_without_project_dispatch() -> void:
	var outbox: GFRequestOutboxUtility = _make_outbox()
	var workflow: GFSupportReportWorkflow = GFSupportReportWorkflow.new().setup(
		GFSupportReportUtility.new(),
		outbox
	)
	var project_transport_calls: Array[int] = [0]
	var _configured_workflow: GFSupportReportWorkflow = workflow.set_transport(
		func(_report: Dictionary, _options: Dictionary) -> Dictionary:
			project_transport_calls[0] += 1
			return { "ok": true }
	)
	var unrelated: GFRequestEnvelope = GFRequestEnvelope.new(
		HTTPClient.METHOD_POST,
		"gf://other/request",
		{ "value": 1 }
	)
	unrelated.max_attempts = 2
	assert_true(outbox.enqueue(unrelated), "测试无关请求应进入共享 Outbox。")

	var replay_result: Dictionary = await outbox.replay(1)

	assert_eq(project_transport_calls[0], 0, "非 Support 请求不得进入项目 Support transport。")
	assert_eq(GFVariantData.get_option_int(replay_result, "failed"), 1, "协议拒绝应记录一次可重试失败。")
	assert_eq(outbox.get_queue_size(), 1, "无关请求必须保留给其真正 owner，不能被误删。")
	outbox.dispose()


# --- 私有/辅助方法 ---

func _make_outbox() -> GFRequestOutboxUtility:
	var outbox: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	var storage_path: String = "user://gf_support_report_outbox_test_%d.json" % Time.get_ticks_usec()
	_storage_paths.append(storage_path)
	outbox.storage_path = storage_path
	outbox.auto_load_on_init = false
	outbox.auto_persist = true
	outbox.retry_delays_msec = [0]
	outbox.init()
	return outbox


func _variant_to_request_envelope(value: Variant) -> GFRequestEnvelope:
	if value is GFRequestEnvelope:
		var envelope: GFRequestEnvelope = value
		return envelope
	return null


func _await_workflow_replay(
	workflow: GFSupportReportWorkflow,
	state: WorkflowReplayState
) -> void:
	state.report = await workflow.replay_queued()
	state.done = true


func _remove_outbox_files(storage_path: String) -> void:
	for path: String in [storage_path, storage_path + ".tmp", storage_path + ".bak"]:
		if FileAccess.file_exists(path):
			var remove_error: Error = DirAccess.remove_absolute(path)
			assert_eq(remove_error, OK, "测试应能删除支持报告 outbox 临时文件。")


class ManualWorkflowTransport:
	extends RefCounted

	signal finished(result: Dictionary)

	var captured_reports: Array[Dictionary] = []

	func send(report: Dictionary, _options: Dictionary) -> Signal:
		captured_reports.append(report.duplicate(true))
		return finished

	func emit_success() -> void:
		finished.emit({ "ok": true })


class WorkflowReplayState:
	extends RefCounted

	var done: bool = false
	var report: Dictionary = {}
