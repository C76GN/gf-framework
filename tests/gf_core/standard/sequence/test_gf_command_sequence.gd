## 测试 GFCommandSequence 的顺序执行、上下文传递与 Signal 等待。
extends GutTest


# --- 辅助类 ---

class RecordingStep extends GFSequenceStep:
	var order: Array[String] = []
	var label: String = ""

	func _init(p_order: Array[String], p_label: String) -> void:
		order = p_order
		label = p_label

	func execute(context: GFSequenceContext) -> Variant:
		order.append(label)
		var _set_value_result_17: Variant = context.set_value(StringName(label), true)
		return null


class ManualSignalStep extends GFSequenceStep:
	signal completed

	var order: Array[String] = []
	var label: String = ""

	func _init(p_order: Array[String], p_label: String) -> void:
		order = p_order
		label = p_label

	func execute(_context: GFSequenceContext) -> Variant:
		order.append(label)
		return completed


class CancellableSignalStep extends ManualSignalStep:
	var cancel_count: int = 0

	func _init(p_order: Array[String], p_label: String) -> void:
		super._init(p_order, p_label)

	func cancel(context: GFSequenceContext) -> void:
		cancel_count += 1
		order.append("cancel_" + label)
		var _set_value_result_45: Variant = context.set_value(&"cancelled_step", label)


class ManyArgumentSignalStep extends GFSequenceStep:
	signal completed(a: int, b: int, c: int, d: int, e: int)

	var order: Array[String] = []
	var label: String = ""

	func _init(p_order: Array[String], p_label: String) -> void:
		order = p_order
		label = p_label

	func execute(_context: GFSequenceContext) -> Variant:
		order.append(label)
		return completed


class FailingSignalStep extends GFSequenceStep:
	signal completed(result: Dictionary)

	func execute(_context: GFSequenceContext) -> Variant:
		call_deferred("_emit_failure")
		return completed

	func _emit_failure() -> void:
		completed.emit({ "ok": false, "error": "async_broken" })


class UndoableRecordingStep extends RecordingStep:
	func undo() -> void:
		order.append("undo_" + label)


class FailingUndoStep extends RecordingStep:
	func undo() -> Dictionary:
		order.append("undo_" + label)
		return {
			"ok": false,
			"error": "undo_broken",
		}


class AsyncUndoStep extends RecordingStep:
	signal undo_finished(result: Dictionary)

	var cancel_count: int = 0

	func _init(p_order: Array[String], p_label: String) -> void:
		super._init(p_order, p_label)

	func undo() -> Signal:
		order.append("undo_" + label)
		return undo_finished

	func cancel(_context: GFSequenceContext) -> void:
		cancel_count += 1
		order.append("cancel_undo_" + label)


class NodeUndoStep extends Node:
	var order: Array[String] = []
	var label: String = ""

	func _init(p_order: Array[String], p_label: String) -> void:
		order = p_order
		label = p_label

	func execute() -> void:
		order.append(label)

	func undo() -> void:
		order.append("undo_" + label)


class FailingStep extends GFSequenceStep:
	var order: Array[String] = []
	var label: String = ""
	var result: Dictionary = {}

	func _init(p_order: Array[String], p_label: String, p_error: String = "failed") -> void:
		order = p_order
		label = p_label
		result = {
			"ok": false,
			"error": p_error,
		}

	func execute(_context: GFSequenceContext) -> Variant:
		order.append(label)
		return result


class SuccessFlagFailingStep extends FailingStep:
	func _init(p_order: Array[String], p_label: String) -> void:
		super._init(p_order, p_label)
		result = {
			"success": false,
		}


class StructuredErrorStep extends GFSequenceStep:
	func execute(_context: GFSequenceContext) -> Variant:
		return {
			"ok": false,
			"error": {
				"owner": self,
				"value": NAN,
			},
		}


class FreeingFailingStep extends FailingStep:
	var target: Object = null

	func _init(p_order: Array[String], p_label: String, p_target: Object) -> void:
		super._init(p_order, p_label)
		target = p_target

	func execute(_context: GFSequenceContext) -> Variant:
		order.append(label)
		if target is Node:
			var node: Node = target
			if is_instance_valid(node):
				node.free()
		return result


class CompensatingFailingStep extends FailingStep:
	func _init(p_order: Array[String], p_label: String) -> void:
		super._init(p_order, p_label)
		result[GFCommandSequence.FAILED_STEP_ROLLBACK_REQUEST_KEY] = true

	func undo() -> void:
		order.append("undo_" + label)


class UnsupportedInjectableStep extends RefCounted:
	var injection_count: int = 0

	func inject_dependencies(_architecture: GFArchitecture) -> void:
		injection_count += 1


# --- 测试方法 ---

## 验证同步步骤按顺序执行并共享上下文。
func test_sequence_runs_steps_in_order() -> void:
	var order: Array[String] = []
	var context: GFSequenceContext = GFSequenceContext.new()
	var sequence: GFCommandSequence = GFCommandSequence.new([
		RecordingStep.new(order, "first"),
		RecordingStep.new(order, "second"),
	], context)

	await sequence.run()

	assert_eq(order, ["first", "second"], "同步步骤应按声明顺序执行。")
	assert_true(GFVariantData.to_bool(context.get_value(&"first", false)), "步骤应能写入共享上下文。")
	assert_false(sequence.is_running, "同步执行完成后不应保持 running。")


## 验证返回 Signal 的步骤会阻塞后续步骤直到完成。
func test_sequence_waits_for_signal_step() -> void:
	var order: Array[String] = []
	var wait_step: ManualSignalStep = ManualSignalStep.new(order, "wait")
	var sequence: GFCommandSequence = GFCommandSequence.new([
		RecordingStep.new(order, "before"),
		wait_step,
		RecordingStep.new(order, "after"),
	])

	@warning_ignore("missing_await")
	sequence.run()
	assert_eq(order, ["before", "wait"], "Signal 未完成前不应执行后续步骤。")
	assert_true(sequence.is_running, "等待 Signal 时序列应保持运行中。")

	var completed: Array[bool] = [false]
	var on_completed: Callable = func() -> void:
		completed[0] = true
	var _connect_result_172: Variant = sequence.sequence_completed.connect(
		on_completed,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	)
	wait_step.completed.emit()
	await get_tree().process_frame

	assert_eq(order, ["before", "wait", "after"], "Signal 完成后应继续执行后续步骤。")
	assert_true(completed[0], "序列应发出完成信号。")
	assert_false(sequence.is_running, "完成后应清除 running 状态。")


func test_sequence_waits_for_signal_with_many_arguments() -> void:
	var order: Array[String] = []
	var wait_step: ManyArgumentSignalStep = ManyArgumentSignalStep.new(order, "wait")
	var sequence: GFCommandSequence = GFCommandSequence.new([
		wait_step,
		RecordingStep.new(order, "after"),
	])

	@warning_ignore("missing_await")
	sequence.run()
	assert_eq(order, ["wait"], "多参数 Signal 未完成前不应执行后续步骤。")

	wait_step.completed.emit(1, 2, 3, 4, 5)
	await get_tree().process_frame

	assert_eq(order, ["wait", "after"], "多参数 Signal 完成后应继续执行后续步骤。")
	assert_false(sequence.is_running, "完成后应清除 running 状态。")


func test_sequence_uses_signal_payload_as_step_result() -> void:
	var sequence: GFCommandSequence = GFCommandSequence.new([
		FailingSignalStep.new(),
		RecordingStep.new([], "after"),
	]).with_failure_policy(true, false)
	watch_signals(sequence)

	await sequence.run()
	await get_tree().process_frame

	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "failed", false), "异步步骤 Signal 发出的失败结果应被识别。")
	assert_eq(GFVariantData.get_option_string(sequence.last_run_report, "error", ""), "async_broken", "失败原因应来自 Signal payload。")
	assert_signal_emitted(sequence, "sequence_failed", "异步失败且 stop_on_error 时应发出失败信号。")


## 验证可取消正在等待的序列。
func test_sequence_cancel_stops_following_steps_after_wait() -> void:
	var order: Array[String] = []
	var wait_step: ManualSignalStep = ManualSignalStep.new(order, "wait")
	var sequence: GFCommandSequence = GFCommandSequence.new([
		RecordingStep.new(order, "before"),
		wait_step,
		RecordingStep.new(order, "after"),
	])

	@warning_ignore("missing_await")
	sequence.run()
	sequence.cancel()
	var cancelled: Array[bool] = [false]
	var on_cancelled: Callable = func() -> void:
		cancelled[0] = true
	var _connect_result_231: Variant = sequence.sequence_cancelled.connect(
		on_cancelled,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	)
	wait_step.completed.emit()
	await get_tree().process_frame

	assert_eq(order, ["before", "wait"], "取消后不应执行后续步骤。")
	assert_true(cancelled[0], "序列应发出取消信号。")


## 验证取消等待中的序列不需要等外部 Signal 触发。
func test_sequence_cancel_breaks_wait_without_signal() -> void:
	var order: Array[String] = []
	var wait_step: ManualSignalStep = ManualSignalStep.new(order, "wait")
	var sequence: GFCommandSequence = GFCommandSequence.new([
		wait_step,
		RecordingStep.new(order, "after"),
	])

	@warning_ignore("missing_await")
	sequence.run()
	await get_tree().process_frame
	sequence.cancel()
	await get_tree().process_frame

	assert_eq(order, ["wait"], "取消后不应等待外部 Signal 才停止。")
	assert_false(sequence.is_running, "取消检查后序列应停止运行。")


func test_sequence_cancel_calls_current_step_cancel() -> void:
	var order: Array[String] = []
	var context: GFSequenceContext = GFSequenceContext.new()
	var wait_step: CancellableSignalStep = CancellableSignalStep.new(order, "wait")
	var sequence: GFCommandSequence = GFCommandSequence.new([
		wait_step,
		RecordingStep.new(order, "after"),
	], context)

	@warning_ignore("missing_await")
	sequence.run()
	sequence.cancel()
	await get_tree().process_frame

	assert_eq(order, ["wait", "cancel_wait"], "取消时应通知当前步骤并停止后续步骤。")
	assert_eq(wait_step.cancel_count, 1, "当前步骤的取消入口应只调用一次。")
	assert_eq(GFVariantData.to_text(context.get_value(&"cancelled_step", "")), "wait", "取消入口应收到序列上下文。")
	assert_false(sequence.is_running, "取消检查后序列应停止运行。")
	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "cancelled", false), "运行报告应标记取消。")


## 验证 Signal 超时后序列会继续后续步骤，但报告失败状态。
func test_sequence_signal_timeout_continues() -> void:
	var order: Array[String] = []
	var wait_step: ManualSignalStep = ManualSignalStep.new(order, "wait")
	var sequence: GFCommandSequence = GFCommandSequence.new([
		wait_step,
		RecordingStep.new(order, "after"),
	]).with_signal_timeout(0.001)

	@warning_ignore("missing_await")
	sequence.run()
	await get_tree().create_timer(0.05).timeout
	await get_tree().process_frame

	assert_push_warning("[GFCommandSequence] 等待 Signal 超时，序列已标记当前步骤失败。")
	assert_eq(order, ["wait", "after"], "Signal 超时后应继续执行后续步骤。")
	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "failed", false), "Signal 超时应进入顶层失败状态。")
	assert_eq(GFVariantData.get_option_string(sequence.last_run_report, "error"), String(GFAsyncWaitUtility.STATUS_TIMEOUT), "顶层错误应保留 timeout 状态。")
	var results: Array = GFVariantData.get_option_array(sequence.last_run_report, "results")
	var wait_report: Dictionary = GFVariantData.as_dictionary(results[0])
	assert_false(GFVariantData.get_option_bool(wait_report, "ok", true), "超时步骤报告不应标记为 ok。")
	assert_eq(GFVariantData.get_option_string_name(wait_report, "wait_status"), GFAsyncWaitUtility.STATUS_TIMEOUT, "步骤报告应保留等待状态。")
	assert_false(GFVariantData.get_option_bool(wait_report, "wait_completed", true), "步骤报告应标记等待未完成。")


func test_sequence_stop_on_error_reports_failure() -> void:
	var order: Array[String] = []
	var sequence: GFCommandSequence = GFCommandSequence.new([
		RecordingStep.new(order, "before"),
		FailingStep.new(order, "fail", "broken"),
		RecordingStep.new(order, "after"),
	]).with_failure_policy(true, false)
	watch_signals(sequence)

	await sequence.run()

	assert_eq(order, ["before", "fail"], "stop_on_error 时失败后不应继续执行后续步骤。")
	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "failed", false), "运行报告应标记失败。")
	assert_eq(GFVariantData.get_option_int(sequence.last_run_report, "failed_index", -1), 1, "运行报告应记录失败步骤索引。")
	assert_eq(GFVariantData.get_option_string(sequence.last_run_report, "error", ""), "broken", "运行报告应记录失败原因。")
	assert_eq(GFVariantData.get_option_int(sequence.last_run_report, "succeeded", -1), 1, "运行报告应只统计失败前已成功步骤。")
	assert_signal_emitted(sequence, "step_failed", "失败步骤应发出 step_failed。")
	assert_signal_emitted(sequence, "sequence_failed", "stop_on_error 时序列应发出 sequence_failed。")


func test_sequence_report_sanitizes_structured_error_values() -> void:
	var sequence: GFCommandSequence = GFCommandSequence.new([
		StructuredErrorStep.new(),
	]).with_failure_policy(true, false)

	await sequence.run()

	var results: Array = GFVariantData.get_option_array(sequence.last_run_report, "results")
	var step_report: Dictionary = GFVariantData.as_dictionary(results[0])
	var json_text: String = JSON.stringify(sequence.last_run_report)

	assert_false(json_text.contains(":null"), "命令序列报告不应把 NaN 直接交给 JSON.stringify。")
	assert_true(json_text.contains("__gf_report_value__"), "命令序列报告应脱敏运行时对象。")
	assert_true(GFVariantData.get_option_value(step_report, "result") is Dictionary, "步骤结果应以 JSON-safe 字典记录。")


func test_sequence_failure_without_stop_does_not_complete_failed_step() -> void:
	var order: Array[String] = []
	var failed_indices: Array[int] = []
	var completed_indices: Array[int] = []
	var sequence: GFCommandSequence = GFCommandSequence.new([
		RecordingStep.new(order, "before"),
		FailingStep.new(order, "fail", "broken"),
		RecordingStep.new(order, "after"),
	]).with_failure_policy(false, false)
	var _connect_result_326: Variant = sequence.step_failed.connect(func(index: int, _step: Variant, _error: String) -> void:
		failed_indices.append(index)
	)
	var _connect_result_329: Variant = sequence.step_completed.connect(func(index: int, _step: Variant) -> void:
		completed_indices.append(index)
	)

	await sequence.run()

	assert_eq(order, ["before", "fail", "after"], "stop_on_error=false 时失败后应继续执行后续步骤。")
	assert_eq(failed_indices, [1], "失败步骤应只发出 step_failed。")
	assert_eq(completed_indices, [0, 2], "失败步骤不应再发出 step_completed。")
	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "failed", false), "运行报告仍应记录曾发生失败。")


func test_sequence_rollback_on_failure_undoes_completed_steps_reverse_order() -> void:
	var order: Array[String] = []
	var sequence: GFCommandSequence = GFCommandSequence.new([
		UndoableRecordingStep.new(order, "first"),
		UndoableRecordingStep.new(order, "second"),
		FailingStep.new(order, "fail"),
		RecordingStep.new(order, "after"),
	]).with_failure_policy(true, true)

	await sequence.run()

	assert_eq(order, ["first", "second", "fail", "undo_second", "undo_first"], "失败回滚应逆序 undo 已完成步骤。")
	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "rolled_back", false), "运行报告应标记已回滚。")


func test_sequence_rollback_reports_undo_failure() -> void:
	var order: Array[String] = []
	var sequence: GFCommandSequence = GFCommandSequence.new([
		FailingUndoStep.new(order, "first"),
		FailingStep.new(order, "fail"),
	]).with_failure_policy(true, true)

	await sequence.run()

	var rollback_errors: Array = GFVariantData.get_option_array(sequence.last_run_report, "rollback_errors")
	var rollback_error: Dictionary = GFVariantData.as_dictionary(rollback_errors[0])
	assert_eq(order, ["first", "fail", "undo_first"], "失败回滚仍应尝试 undo 已完成步骤。")
	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "rolled_back", false), "运行报告应标记已回滚。")
	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "rollback_failed", false), "undo 失败应写入运行报告。")
	assert_eq(rollback_errors.size(), 1, "运行报告应记录每个 undo 失败。")
	assert_eq(GFVariantData.get_option_string(rollback_error, "error"), "undo_broken", "undo 失败原因应保留。")


func test_sequence_rollback_reports_async_undo_timeout() -> void:
	var order: Array[String] = []
	var undo_step: AsyncUndoStep = AsyncUndoStep.new(order, "first")
	var sequence: GFCommandSequence = GFCommandSequence.new([
		undo_step,
		FailingStep.new(order, "fail"),
	]).with_failure_policy(true, true).with_signal_timeout(0.001, false)

	await sequence.run()

	var rollback_errors: Array = GFVariantData.get_option_array(sequence.last_run_report, "rollback_errors")
	var rollback_error: Dictionary = GFVariantData.as_dictionary(rollback_errors[0])
	assert_push_warning("[GFCommandSequence] 等待 Signal 超时，序列已标记当前步骤失败。")
	assert_eq(order, ["first", "fail", "undo_first"], "异步 undo 超时时应记录已进入 rollback。")
	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "rollback_failed", false), "rollback 超时应标记 rollback_failed。")
	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "rollback_timeout", false), "rollback 超时应有一等 timeout 字段。")
	assert_eq(
		GFVariantData.get_option_string_name(sequence.last_run_report, "rollback_status"),
		GFCommandSequence.ROLLBACK_STATUS_TIMEOUT,
		"rollback_status 应报告 timeout。"
	)
	assert_eq(GFVariantData.get_option_string_name(rollback_error, "wait_status"), GFAsyncWaitUtility.STATUS_TIMEOUT, "rollback error 应保留 wait_status。")


func test_sequence_cancel_calls_current_rollback_step_cancel() -> void:
	var order: Array[String] = []
	var undo_step: AsyncUndoStep = AsyncUndoStep.new(order, "first")
	var sequence: GFCommandSequence = GFCommandSequence.new([
		undo_step,
		FailingStep.new(order, "fail"),
	]).with_failure_policy(true, true).with_signal_timeout(10.0, false)

	@warning_ignore("missing_await")
	sequence.run()
	await get_tree().process_frame
	sequence.cancel()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order, ["first", "fail", "undo_first", "cancel_undo_first"], "取消 rollback 时应通知当前 undo step。")
	assert_eq(undo_step.cancel_count, 1, "rollback 当前步骤的 cancel 入口应只调用一次。")
	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "rollback_cancelled", false), "rollback 取消应有一等 cancelled 字段。")
	assert_eq(
		GFVariantData.get_option_string_name(sequence.last_run_report, "rollback_status"),
		GFCommandSequence.ROLLBACK_STATUS_CANCELLED,
		"rollback_status 应报告 cancelled。"
	)


func test_sequence_rollback_skips_freed_completed_step_without_cast_error() -> void:
	var order: Array[String] = []
	var freed_step: NodeUndoStep = NodeUndoStep.new(order, "first")
	var sequence: GFCommandSequence = GFCommandSequence.new([
		freed_step,
		FreeingFailingStep.new(order, "fail", freed_step),
	]).with_failure_policy(true, true)

	await sequence.run()

	assert_eq(order, ["first", "fail"], "已释放完成步骤不应在失败回滚时再次 undo。")
	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "rolled_back", false), "运行报告仍应标记已执行回滚流程。")


func test_sequence_success_false_uses_default_error() -> void:
	var order: Array[String] = []
	var sequence: GFCommandSequence = GFCommandSequence.new([
		SuccessFlagFailingStep.new(order, "fail"),
	]).with_failure_policy(true, false)

	await sequence.run()

	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "failed", false), "success=false 应被识别为失败。")
	assert_eq(GFVariantData.get_option_string(sequence.last_run_report, "error", ""), "Step failed.", "缺少错误字段时应提供稳定默认错误。")


func test_sequence_rejects_unsupported_non_null_step() -> void:
	var order: Array[String] = []
	var unsupported_step: RefCounted = RefCounted.new()
	var sequence: GFCommandSequence = GFCommandSequence.new([
		unsupported_step,
		RecordingStep.new(order, "after"),
	]).with_failure_policy(true, false)
	watch_signals(sequence)

	await sequence.run()

	assert_true(GFVariantData.get_option_bool(sequence.last_run_report, "failed", false), "非空但不支持的 step 不应静默成功。")
	assert_eq(GFVariantData.get_option_int(sequence.last_run_report, "failed_index", -1), 0, "不支持的 step 应定位到当前索引。")
	assert_eq(GFVariantData.get_option_string(sequence.last_run_report, "error", ""), "unsupported_step", "失败原因应稳定。")
	assert_true(order.is_empty(), "stop_on_error 时不应继续执行后续步骤。")
	assert_signal_emitted(sequence, "sequence_failed", "不支持 step 应触发失败信号。")


func test_sequence_rejects_null_step_instead_of_skipping_it() -> void:
	var order: Array[String] = []
	var sequence: GFCommandSequence = GFCommandSequence.new([
		null,
		RecordingStep.new(order, "after"),
	]).with_failure_policy(true, false)

	await sequence.run()

	assert_eq(GFVariantData.get_option_int(sequence.last_run_report, "failed_index", -1), 0, "空步骤应定位为失败步骤。")
	assert_eq(GFVariantData.get_option_string(sequence.last_run_report, "error"), "unsupported_step", "空步骤不应被静默跳过。")
	assert_true(order.is_empty(), "严格失败后不应执行后续步骤。")


func test_sequence_uses_immutable_step_snapshot_for_each_run() -> void:
	var order: Array[String] = []
	var wait_step: ManualSignalStep = ManualSignalStep.new(order, "wait")
	var original_after: RecordingStep = RecordingStep.new(order, "original")
	var sequence: GFCommandSequence = GFCommandSequence.new([wait_step, original_after])

	@warning_ignore("missing_await")
	sequence.run()
	sequence.steps[1] = RecordingStep.new(order, "mutated")
	wait_step.completed.emit()
	await get_tree().process_frame

	assert_eq(order, ["wait", "original"], "运行中的步骤集合应使用 run() 开始时的快照。")


func test_sequence_does_not_inject_unsupported_object() -> void:
	var step: UnsupportedInjectableStep = UnsupportedInjectableStep.new()
	var sequence: GFCommandSequence = GFCommandSequence.new([step]).with_failure_policy(true, false)
	sequence.inject_dependencies(GFArchitecture.new())

	await sequence.run()

	assert_eq(step.injection_count, 0, "不满足执行协议的对象不应收到依赖注入。")
	assert_eq(GFVariantData.get_option_string(sequence.last_run_report, "error"), "unsupported_step", "对象仍应按不支持步骤失败。")


func test_sequence_compensates_failed_step_only_when_explicitly_requested() -> void:
	var order: Array[String] = []
	var sequence: GFCommandSequence = GFCommandSequence.new([
		UndoableRecordingStep.new(order, "completed"),
		CompensatingFailingStep.new(order, "failed"),
	]).with_failure_policy(true, true)

	await sequence.run()

	assert_eq(order, ["completed", "failed", "undo_failed", "undo_completed"], "显式请求补偿的失败步骤应先于已完成步骤逆序撤销。")
	assert_eq(GFVariantData.get_option_int(sequence.last_run_report, "succeeded"), 1, "失败步骤补偿不应增加成功计数。")
	assert_eq(GFVariantData.get_option_int(sequence.last_run_report, "rollback_attempted_count"), 2, "回滚报告应记录实际补偿尝试数。")
