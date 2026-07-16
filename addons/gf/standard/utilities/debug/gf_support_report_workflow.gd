## GFSupportReportWorkflow: 支持报告构建、提交与离线重放协调器。
##
## 组合 GFSupportReportUtility 与 GFRequestOutboxUtility，提供“先直接提交，失败或离线时入队，
## 之后通过调用方传入的 transport 重放”的通用工作流。它不绑定任何工单系统、账号、网络 SDK 或 UI。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFSupportReportWorkflow
extends GFUtility


# --- 信号 ---

## 工作流构建支持报告后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report: 已构建的支持报告。
## [br]
## @schema report: Dictionary，GFSupportReportUtility.build_report() 返回结构。
signal workflow_report_built(report: Dictionary)

## 工作流直接提交支持报告成功后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report: 已提交的支持报告。
## [br]
## @param result: 提交结果。
## [br]
## @schema report: Dictionary，GFSupportReportUtility.build_report() 返回结构。
## [br]
## @schema result: Dictionary，包含 ok、value、error、metadata。
signal workflow_report_submitted(report: Dictionary, result: Dictionary)

## 工作流把支持报告写入离线队列后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report: 已入队的支持报告。
## [br]
## @param envelope: 入队请求描述。
## [br]
## @schema report: Dictionary，GFSupportReportUtility.build_report() 返回结构。
signal workflow_report_queued(report: Dictionary, envelope: GFRequestEnvelope)

## 工作流完成一次离线队列重放后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param result: 重放报告。
## [br]
## @schema result: Dictionary，GFRequestOutboxUtility.replay() 返回结构。
signal workflow_replay_completed(result: Dictionary)


# --- 公共变量 ---

## 底层支持报告工具。为空时会按需创建。
## [br]
## @api public
## [br]
## @since 8.0.0
var support_report_utility: GFSupportReportUtility = null

## 可选离线请求队列。为空时 workflow 只尝试直接提交。
## [br]
## @api public
## [br]
## @since 8.0.0
var request_outbox: GFRequestOutboxUtility = null

## 直接提交或重放时使用的传输回调，建议签名为 func(report: Dictionary, options: Dictionary) -> Variant。
## [br]
## @api public
## [br]
## @since 8.0.0
var transport_callback: Callable = Callable()

## 离线队列请求目标。它只是逻辑端点，项目可按自己的传输层解释。
## [br]
## @api public
## [br]
## @since 8.0.0
var request_url: String = "gf://support-report"

## 直接提交失败时是否尝试写入 request_outbox。
## [br]
## @api public
## [br]
## @since 8.0.0
var queue_on_submit_failure: bool = true

## 缺少 transport_callback 时是否尝试写入 request_outbox。
## [br]
## @api public
## [br]
## @since 8.0.0
var queue_when_transport_missing: bool = true

## 设置 transport_callback 后是否自动把 request_outbox.transport_callback 指向本工作流。
## [br]
## @api public
## [br]
## @since 8.0.0
var auto_wire_outbox_transport: bool = true

## 每次构建报告都会合并的会话元数据。调用 build_report() 时传入的 metadata 优先生效。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @schema session_metadata: Dictionary，项目自定义诊断上下文。
var session_metadata: Dictionary = {}


# --- 私有变量 ---

var _reports_built_count: int = 0
var _reports_submitted_count: int = 0
var _reports_queued_count: int = 0
var _replay_completed_count: int = 0


# --- GF 生命周期方法 ---

## 释放工作流运行时状态。
## [br]
## @api public
## [br]
## @since 8.0.0
func dispose() -> void:
	support_report_utility = null
	request_outbox = null
	transport_callback = Callable()
	session_metadata.clear()
	_reports_built_count = 0
	_reports_submitted_count = 0
	_reports_queued_count = 0
	_replay_completed_count = 0


# --- 公共方法 ---

## 配置底层报告工具与离线队列。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report_utility: 支持报告工具；为空时保持现有值。
## [br]
## @param outbox: 离线请求队列；为空时保持现有值。
## [br]
## @return 当前工作流。
func setup(
	report_utility: GFSupportReportUtility = null,
	outbox: GFRequestOutboxUtility = null
) -> GFSupportReportWorkflow:
	if report_utility != null:
		support_report_utility = report_utility
	if outbox != null:
		request_outbox = outbox
	_wire_outbox_transport()
	return self


## 设置直接提交与离线重放使用的传输回调。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param callback: 传输回调，建议签名为 func(report: Dictionary, options: Dictionary) -> Variant。
## [br]
## @return 当前工作流。
func set_transport(callback: Callable) -> GFSupportReportWorkflow:
	transport_callback = callback
	_wire_outbox_transport()
	return self


## 设置会话元数据。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param metadata: 新元数据。
## [br]
## @param merge_existing: 为 true 时合并到现有 session_metadata；为 false 时替换。
## [br]
## @return 当前工作流。
## [br]
## @schema metadata: Dictionary，项目自定义诊断上下文。
func set_session_metadata(metadata: Dictionary, merge_existing: bool = false) -> GFSupportReportWorkflow:
	if merge_existing:
		session_metadata.merge(metadata.duplicate(true), true)
	else:
		session_metadata = metadata.duplicate(true)
	return self


## 构建支持报告，并自动合并 session_metadata。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param description: 用户描述或问题摘要。
## [br]
## @param options: GFSupportReportUtility.build_report() 选项。
## [br]
## @return 支持报告字典。
## [br]
## @schema options: Dictionary，支持 GFSupportReportUtility.build_report() 的全部选项。
## [br]
## @schema return: Dictionary，GFSupportReportUtility.build_report() 返回结构。
func build_report(description: String = "", options: Dictionary = {}) -> Dictionary:
	var build_options: Dictionary = options.duplicate(true)
	var metadata: Dictionary = session_metadata.duplicate(true)
	metadata.merge(GFVariantData.get_option_dictionary(options, "metadata"), true)
	build_options["metadata"] = metadata

	var report: Dictionary = _get_support_report_utility().build_report(description, build_options)
	_reports_built_count += 1
	workflow_report_built.emit(report)
	return report


## 构建并提交支持报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param description: 用户描述或问题摘要。
## [br]
## @param options: 提交选项，支持 transport、transport_options、queue_on_failure、queue_when_missing_transport、request_url、headers、request_metadata、max_attempts。
## [br]
## @return 工作流结果。
## [br]
## @schema options: Dictionary，包含构建选项以及 transport、transport_options、queue_on_failure、queue_when_missing_transport、request_url、headers、request_metadata、max_attempts。
## [br]
## @schema return: Dictionary，包含 ok、status、report、submit_result、queue_result、error。
func submit_report(description: String = "", options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = build_report(description, options)
	return submit_built_report(report, options)


## 提交已经构建好的支持报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report: 支持报告字典。
## [br]
## @param options: 提交选项，支持 transport、transport_options、queue_on_failure、queue_when_missing_transport、request_url、headers、request_metadata、max_attempts。
## [br]
## @return 工作流结果。
## [br]
## @schema report: Dictionary，GFSupportReportUtility.build_report() 返回结构。
## [br]
## @schema options: Dictionary，包含 transport、transport_options、queue_on_failure、queue_when_missing_transport、request_url、headers、request_metadata、max_attempts。
## [br]
## @schema return: Dictionary，包含 ok、status、report、submit_result、queue_result、error。
func submit_built_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
	if report.is_empty():
		return _make_workflow_result(false, &"failed", report, {}, {}, "report is empty")

	var transport: Callable = _get_transport_from_options(options)
	if transport.is_valid():
		var submit_result: Dictionary = _get_support_report_utility().submit_report(
			report,
			transport,
			GFVariantData.get_option_dictionary(options, "transport_options")
		)
		if GFVariantData.get_option_bool(submit_result, "ok"):
			_reports_submitted_count += 1
			workflow_report_submitted.emit(report, submit_result)
			return _make_workflow_result(true, &"submitted", report, submit_result, {}, "")

		if GFVariantData.get_option_bool(options, "queue_on_failure", queue_on_submit_failure):
			var failed_queue_result: Dictionary = queue_report(report, options)
			if GFVariantData.get_option_bool(failed_queue_result, "ok"):
				return _make_workflow_result(true, &"queued", report, submit_result, failed_queue_result, "")
		return _make_workflow_result(false, &"failed", report, submit_result, {}, GFVariantData.get_option_string(submit_result, "error", "submit failed"))

	if GFVariantData.get_option_bool(options, "queue_when_missing_transport", queue_when_transport_missing):
		var missing_transport_queue_result: Dictionary = queue_report(report, options)
		if GFVariantData.get_option_bool(missing_transport_queue_result, "ok"):
			return _make_workflow_result(true, &"queued", report, {}, missing_transport_queue_result, "")
	return _make_workflow_result(false, &"failed", report, {}, {}, "transport callback is invalid")


## 将支持报告写入离线请求队列。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report: 支持报告字典。
## [br]
## @param options: 入队选项，支持 request_url、headers、request_metadata、transport_options、max_attempts、idempotency_key。
## [br]
## @return 入队结果。
## [br]
## @schema report: Dictionary，GFSupportReportUtility.build_report() 返回结构。
## [br]
## @schema options: Dictionary，包含 request_url、headers、request_metadata、transport_options、max_attempts、idempotency_key。
## [br]
## @schema return: Dictionary，包含 ok、status、envelope、error。
func queue_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
	if request_outbox == null:
		return _make_queue_result(false, &"failed", null, "request outbox is null")
	if report.is_empty():
		return _make_queue_result(false, &"failed", null, "report is empty")

	_wire_outbox_transport()
	var metadata: Dictionary = GFVariantData.get_option_dictionary(options, "request_metadata")
	metadata["request_kind"] = "support_report"
	metadata["report_id"] = GFVariantData.get_option_string(report, "report_id")
	metadata["transport_options"] = GFVariantData.get_option_dictionary(options, "transport_options")

	var body: Dictionary = {
		"report": report.duplicate(true),
	}
	var envelope: GFRequestEnvelope = request_outbox.enqueue_request(
		HTTPClient.METHOD_POST,
		GFVariantData.get_option_string(options, "request_url", request_url),
		body,
		GFVariantData.get_option_packed_string_array(options, "headers"),
		metadata
	)
	if envelope == null:
		return _make_queue_result(false, &"failed", null, "enqueue failed")

	var max_attempts: int = GFVariantData.get_option_int(options, "max_attempts", envelope.max_attempts)
	envelope.max_attempts = max_attempts
	envelope.idempotency_key = GFVariantData.get_option_string(options, "idempotency_key", envelope.idempotency_key)
	_reports_queued_count += 1
	workflow_report_queued.emit(report, envelope)
	return _make_queue_result(true, &"queued", envelope, "")


## 重放离线支持报告队列。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param max_count: 最多处理数量；小于等于 0 表示不限制。
## [br]
## @return 重放报告。
## [br]
## @schema return: Dictionary，GFRequestOutboxUtility.replay() 返回结构；缺少 outbox 时包含 ok=false 和 reason。
func replay_queued(max_count: int = 0) -> Dictionary:
	if request_outbox == null:
		return {
			"ok": false,
			"processed": 0,
			"succeeded": 0,
			"failed": 0,
			"skipped": 0,
			"pending": 0,
			"failed_stored": 0,
			"reason": "request_outbox_is_null",
		}

	_wire_outbox_transport()
	var result: Dictionary = await request_outbox.replay(max_count)
	_replay_completed_count += 1
	workflow_replay_completed.emit(result)
	return result


## 获取工作流调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含工具配置、计数和 outbox 快照。
func get_debug_snapshot() -> Dictionary:
	return {
		"has_support_report_utility": support_report_utility != null,
		"has_request_outbox": request_outbox != null,
		"has_transport": transport_callback.is_valid(),
		"request_url": request_url,
		"queue_on_submit_failure": queue_on_submit_failure,
		"queue_when_transport_missing": queue_when_transport_missing,
		"auto_wire_outbox_transport": auto_wire_outbox_transport,
		"session_metadata": session_metadata.duplicate(true),
		"reports_built_count": _reports_built_count,
		"reports_submitted_count": _reports_submitted_count,
		"reports_queued_count": _reports_queued_count,
		"replay_completed_count": _replay_completed_count,
		"outbox": request_outbox.get_debug_snapshot() if request_outbox != null else {},
	}


# --- 私有/辅助方法 ---

func _get_support_report_utility() -> GFSupportReportUtility:
	if support_report_utility == null:
		support_report_utility = GFSupportReportUtility.new()
	return support_report_utility


func _get_transport_from_options(options: Dictionary) -> Callable:
	var transport_value: Variant = GFVariantData.get_option_value(options, "transport", transport_callback)
	if transport_value is Callable:
		var callback: Callable = transport_value
		return callback
	return Callable()


func _wire_outbox_transport() -> void:
	if request_outbox == null or not auto_wire_outbox_transport or not transport_callback.is_valid():
		return
	request_outbox.transport_callback = Callable(self, "_send_outbox_envelope")


func _send_outbox_envelope(envelope: GFRequestEnvelope) -> Variant:
	if envelope == null:
		return {
			"ok": false,
			"error": "envelope is null",
		}
	if not transport_callback.is_valid():
		return {
			"ok": false,
			"error": "transport callback is invalid",
		}

	var report: Dictionary = GFVariantData.get_option_dictionary(envelope.body, "report")
	var transport_options: Dictionary = GFVariantData.get_option_dictionary(envelope.metadata, "transport_options")
	return transport_callback.call(report, transport_options)


func _make_workflow_result(
	ok: bool,
	status: StringName,
	report: Dictionary,
	submit_result: Dictionary,
	queue_result: Dictionary,
	error: String
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"report": report.duplicate(true),
		"submit_result": submit_result.duplicate(true),
		"queue_result": queue_result.duplicate(true),
		"error": error,
	}


func _make_queue_result(ok: bool, status: StringName, envelope: GFRequestEnvelope, error: String) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"envelope": envelope,
		"error": error,
	}
