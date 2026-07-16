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
