## 测试 GFSupportReportWorkflow 的支持报告提交、离线入队与重放。
extends GutTest


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

	assert_eq(GFVariantData.get_option_string_name(queued_result, "status"), &"queued", "缺少 transport 时应进入离线队列。")
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


# --- 私有/辅助方法 ---

func _make_outbox() -> GFRequestOutboxUtility:
	var outbox: GFRequestOutboxUtility = GFRequestOutboxUtility.new()
	outbox.auto_load_on_init = false
	outbox.auto_persist = false
	outbox.retry_delays_msec = [0]
	outbox.init()
	return outbox
