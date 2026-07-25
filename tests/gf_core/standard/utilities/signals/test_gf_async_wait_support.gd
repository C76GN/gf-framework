extends GutTest


# --- 常量 ---

const GF_ASYNC_WAIT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_wait_support.gd")


# --- 测试方法 ---

func test_await_signal_payload_safely_keeps_nine_signal_arguments() -> void:
	var emitter: WideSignalEmitter = WideSignalEmitter.new()
	add_child_autofree(emitter)

	emitter.call_deferred("emit_payload_ready")
	var result: Dictionary = await GF_ASYNC_WAIT_SUPPORT.await_signal_payload_safely(
		emitter.payload_ready,
		Callable(),
		null,
		1.0,
		false
	)

	assert_true(GFVariantData.get_option_bool(result, "completed"), "信号发出后等待应完成。")
	assert_eq(GFVariantData.get_option_array(result, "args"), [1, 2, 3, 4, 5, 6, 7, 8, 9], "Signal payload 应保留 9 个参数。")


func test_await_signal_state_reports_cancelled_token() -> void:
	var emitter: WideSignalEmitter = WideSignalEmitter.new()
	var source: GFCancellationSource = GFCancellationSource.new()
	add_child_autofree(emitter)
	var _cancelled: bool = source.cancel(&"already_cancelled", { "scope": "test" })

	var result: Dictionary = await GF_ASYNC_WAIT_SUPPORT.await_signal_state(emitter.payload_ready, {
		"tree": get_tree(),
		"cancel_token": source.get_token(),
		"capture_payload": true,
	})
	var metadata: Dictionary = GFVariantData.get_option_dictionary(result, "metadata")

	assert_eq(GFVariantData.get_option_string_name(result, "status"), GF_ASYNC_WAIT_SUPPORT.STATUS_CANCELLED, "取消 token 应得到 cancelled 状态。")
	assert_false(GFVariantData.get_option_bool(result, "completed"), "取消不应伪装成 completed。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"already_cancelled", "等待状态应保留取消原因。")
	assert_eq(GFVariantData.get_option_string(metadata, "scope"), "test", "等待状态应保留取消元数据。")


func test_await_signal_state_prioritizes_cancellation_over_due_timeout() -> void:
	var emitter: WideSignalEmitter = WideSignalEmitter.new()
	var continue_state: Dictionary = { "check_count": 0 }
	add_child_autofree(emitter)

	var result: Dictionary = await GF_ASYNC_WAIT_SUPPORT.await_signal_state(emitter.payload_ready, {
		"tree": get_tree(),
		"timeout_seconds": 0.001,
		"respect_time_scale": false,
		"timeout_warning": "[GFAsyncWaitSupportTest] cancellation must win over timeout.",
		"should_continue": func() -> bool:
			continue_state["check_count"] = (
				GFVariantData.get_option_int(continue_state, "check_count") + 1
			)
			return GFVariantData.get_option_int(continue_state, "check_count") < 2,
	})

	assert_eq(GFVariantData.get_option_string_name(result, "status"), GF_ASYNC_WAIT_SUPPORT.STATUS_CANCELLED, "同一帧同时满足取消与超时时必须优先返回 cancelled。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"should_continue_false", "取消结果应保留 should_continue 终止原因。")
	assert_eq(GFVariantData.get_option_int(continue_state, "check_count"), 2, "测试必须跨帧进入取消与 timeout 同时成立的仲裁点。")
	assert_push_warning_count(0, "取消优先时不得迟发 timeout warning。")


func test_await_signal_state_cancels_when_continue_owner_is_released() -> void:
	var emitter: WideSignalEmitter = WideSignalEmitter.new()
	var continue_owner: ContinueOwner = ContinueOwner.new()
	add_child_autofree(emitter)
	continue_owner.call_deferred(&"free")

	var result: Dictionary = await GF_ASYNC_WAIT_SUPPORT.await_signal_state(emitter.payload_ready, {
		"tree": get_tree(),
		"timeout_seconds": 0.001,
		"respect_time_scale": false,
		"timeout_warning": "[GFAsyncWaitSupportTest] invalid continuation must cancel.",
		"should_continue": Callable(continue_owner, &"should_continue"),
	})

	assert_eq(GFVariantData.get_option_string_name(result, "status"), GF_ASYNC_WAIT_SUPPORT.STATUS_CANCELLED, "继续检查宿主释放后应取消等待。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"should_continue_invalid", "取消结果应区分失效回调与主动返回 false。")
	assert_push_warning_count(0, "失效继续检查必须先于 timeout 结束等待，不得迟发 warning。")


func test_await_signal_state_rejects_continue_owner_released_before_wait() -> void:
	var emitter: WideSignalEmitter = WideSignalEmitter.new()
	var continue_owner: ContinueOwner = ContinueOwner.new()
	add_child_autofree(emitter)
	var stale_continue: Callable = Callable(continue_owner, &"should_continue")
	continue_owner.free()

	var result: Dictionary = await GF_ASYNC_WAIT_SUPPORT.await_signal_state(
		emitter.payload_ready,
		{
			"tree": get_tree(),
			"timeout_seconds": 0.1,
			"respect_time_scale": false,
			"should_continue": stale_continue,
		}
	)

	assert_eq(GFVariantData.get_option_string_name(result, "status"), GF_ASYNC_WAIT_SUPPORT.STATUS_CANCELLED, "等待开始前已经失效的继续检查必须立即取消。")
	assert_eq(GFVariantData.get_option_string_name(result, "reason"), &"should_continue_invalid", "预先失效的继续检查必须保留稳定原因。")


func test_await_signal_safely_source_checks_connect_results() -> void:
	var source: String = _read_text_file("res://addons/gf/standard/common/gf_async_wait_support.gd")

	assert_true(source.contains("if result_connect_result != OK:"), "等待辅助必须处理目标 Signal 连接失败。")
	assert_true(source.contains("if tree_exit_connect_result != OK:"), "等待辅助必须处理 tree_exited 连接失败。")
	assert_true(source.contains("if guard_exit_connect_result != OK:"), "等待辅助必须处理 guard tree_exited 连接失败。")


# --- 内部类 ---

class WideSignalEmitter:
	extends Node

	signal payload_ready(
		first: int,
		second: int,
		third: int,
		fourth: int,
		fifth: int,
		sixth: int,
		seventh: int,
		eighth: int,
		ninth: int
	)

	func emit_payload_ready() -> void:
		payload_ready.emit(1, 2, 3, 4, 5, 6, 7, 8, 9)


class ContinueOwner:
	extends Object

	func should_continue() -> bool:
		return true


# --- 私有/辅助方法 ---

func _read_text_file(path: String) -> String:
	var read_path: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var file: FileAccess = FileAccess.open(read_path, FileAccess.READ)
	assert_not_null(file, "测试应能读取文本文件：%s" % path)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text
