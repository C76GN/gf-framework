## 测试 GFLogUtility 的日志文件生成、旧日志清理及信号触发。
extends GutTest


# --- 常量 ---

const _LOG_DIR: String = "user://logs/"


# --- 私有变量 ---

var _log_util: GFLogUtility


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_log_util = GFLogUtility.new()
	_log_util.max_log_files = 10
	_log_util.init()


func after_each() -> void:
	if _log_util != null:
		_log_util.dispose()
		_log_util = null


# --- 测试：日志文件生成 ---

## 验证 init() 后，user://logs/ 目录下至少生成了一个 .log 文件。
func test_log_file_created() -> void:
	var dir: DirAccess = DirAccess.open(_LOG_DIR)
	assert_not_null(dir, "logs 目录应存在。")

	var found: bool = false
	var _list_begin_error: Error = dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".log"):
			found = true
			break
		file_name = dir.get_next()
	dir.list_dir_end()

	assert_true(found, "logs 目录中应至少存在一个 .log 文件。")


## 验证日志内容被写入文件。
func test_log_writes_to_file() -> void:
	_log_util.info("TestTag", "Hello Log")
	var log_file_path: String = _log_util.get_log_file_path()
	_log_util.dispose()

	var file: FileAccess = FileAccess.open(log_file_path, FileAccess.READ)
	assert_not_null(file, "日志文件应可成功打开。")

	var content: String = file.get_as_text()
	file.close()
	assert_true(content.contains("Hello Log"), "日志文件应包含写入的消息内容。")
	assert_true(content.contains("TestTag"), "日志文件应包含标签名称。")
	assert_true(content.contains("INFO"), "日志文件应包含日志级别。")


# --- 测试：旧日志清理 ---

## 验证当日志文件超出 max_log_files 时，旧文件被自动清理。
func test_old_logs_cleanup() -> void:
	_log_util.dispose()
	_log_util = null

	# 预先创建 12 个假日志文件
	for i: int in range(12):
		var fake_name: String = "gf_log_20250101_%04d.log" % i
		var f: FileAccess = FileAccess.open(_LOG_DIR + fake_name, FileAccess.WRITE)
		if f != null:
			var _store_line_result_77: Variant = f.store_line("test")
			f.close()

	_log_util = GFLogUtility.new()
	_log_util.max_log_files = 10
	_log_util.init()

	var dir: DirAccess = DirAccess.open(_LOG_DIR)
	assert_not_null(dir, "logs 目录应存在。")

	var count: int = 0
	var _list_begin_error: Error = dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("gf_log_") and file_name.ends_with(".log"):
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	assert_true(count <= 10, "清理后日志文件数量不应超过 max_log_files (10)，实际: %d。" % count)


func test_max_log_files_rejects_negative_values() -> void:
	_log_util.max_log_files = -5

	assert_eq(_log_util.max_log_files, 1, "max_log_files 不应允许负数导致清理越界。")


func test_remove_absolute_handles_user_paths_and_missing_files_silently() -> void:
	var path: String = _LOG_DIR + "gf_log_remove_user_path.log"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "测试应能创建待删除日志文件。")
	if file != null:
		var _store_line_result: Variant = file.store_line("temporary")
		file.close()

	GFLogUtility._remove_absolute(path)
	GFLogUtility._remove_absolute(path)

	assert_false(FileAccess.file_exists(path), "日志删除应支持 user:// 路径并忽略已不存在的文件。")


# --- 测试：信号触发 ---

## 验证调用 info() 后 log_emitted 信号正确触发。
func test_signal_emitted_on_info() -> void:
	watch_signals(_log_util)
	_log_util.info("Signal", "test message")
	assert_signal_emitted(_log_util, "log_emitted", "调用 info() 后应发出 log_emitted 信号。")


## 验证信号携带的参数正确。
func test_signal_params_correct() -> void:
	var received: LogTestState = LogTestState.new()

	var handler: Callable = func(level: int, tag: String, message: String) -> void:
		received.level = level
		received.tag = tag
		received.message = message

	var _connected: Variant = _log_util.log_emitted.connect(handler)
	_log_util.error("ErrTag", "something broke")

	assert_eq(received.level, GFLogUtility.LogLevel.ERROR, "信号中的 level 应为 ERROR。")
	assert_eq(received.tag, "ErrTag", "信号中的 tag 应正确传递。")
	assert_eq(received.message, "something broke", "信号中的 message 应正确传递。")
	assert_push_error("[ErrTag] something broke")


func test_structured_log_entry_signal_includes_context() -> void:
	var received: LogTestState = LogTestState.new()

	var entry_handler: Callable = func(log_entry: Dictionary) -> void:
		received.entry = log_entry
	var _connected: Variant = _log_util.log_entry_emitted.connect(entry_handler)

	_log_util.info("Struct", "with context", {
		"entity_id": 12,
		"state": "ready",
	})

	var received_entry: Dictionary = received.entry
	var context: Dictionary = GFVariantData.get_option_dictionary(received_entry, "context")
	assert_eq(GFVariantData.get_option_int(received_entry, "level"), GFLogUtility.LogLevel.INFO, "结构化条目应包含日志等级。")
	assert_eq(GFVariantData.get_option_string(received_entry, "tag"), "Struct", "结构化条目应包含标签。")
	assert_eq(GFVariantData.get_option_string(received_entry, "message"), "with context", "结构化条目应包含原始消息。")
	assert_eq(GFVariantData.get_option_int(context, "entity_id"), 12, "结构化条目应包含上下文字段。")
	assert_true(GFVariantData.get_option_string(received_entry, "text").contains("entity_id"), "格式化文本应包含上下文字段，便于文件和控制台查看。")


func test_trace_id_and_global_context_are_merged_into_entries() -> void:
	var received: LogTestState = LogTestState.new()
	_log_util.set_trace_id("trace-test")
	_log_util.set_global_context({
		"session": "global",
		"tags": PackedStringArray(["alpha", "beta"]),
	})
	_log_util.set_global_context_provider(func() -> Dictionary:
		return {
			"build": "debug",
			"session": "provider",
		}
	)
	var entry_handler: Callable = func(log_entry: Dictionary) -> void:
		received.entry = log_entry
	var _connected: Variant = _log_util.log_entry_emitted.connect(entry_handler)

	_log_util.info("Context", "merged", {
		"session": "local",
	})

	var received_entry: Dictionary = received.entry
	var context: Dictionary = GFVariantData.get_option_dictionary(received_entry, "context")
	assert_eq(GFVariantData.get_option_string(received_entry, "trace_id"), "trace-test", "结构化条目应包含 trace_id。")
	assert_eq(GFVariantData.get_option_string(context, "trace_id"), "trace-test", "上下文应默认带 trace_id。")
	assert_eq(GFVariantData.get_option_string(context, "session"), "local", "单条日志上下文应覆盖 provider 和全局上下文。")
	assert_eq(GFVariantData.get_option_string(context, "build"), "debug", "provider 上下文应参与合并。")
	assert_eq(GFVariantData.get_option_array(context, "tags"), ["alpha", "beta"], "PackedStringArray 应清洗为普通数组。")


func test_sanitize_log_value_marks_circular_references() -> void:
	var context: Dictionary = {}
	context["self"] = context

	var sanitized: Dictionary = GFVariantData.as_dictionary(GFLogUtility.sanitize_log_value(context))

	assert_eq(GFVariantData.get_option_string(sanitized, "self"), "<circular_reference>", "日志上下文循环引用应被稳定标记。")


func test_previous_crash_marker_is_reported_on_init() -> void:
	_log_util.dispose()
	_log_util = null
	if not DirAccess.dir_exists_absolute(_LOG_DIR):
		var _make_dir_error: Error = DirAccess.make_dir_recursive_absolute(_LOG_DIR)
	var marker_file: FileAccess = FileAccess.open(_LOG_DIR + "gf_log_running.marker", FileAccess.WRITE)
	var _store_string_result_198: Variant = marker_file.store_string(JSON.stringify({
		"trace_id": "previous-trace",
		"started_at": "2026-01-01T00:00:00",
	}))
	marker_file.close()

	_log_util = GFLogUtility.new()
	var received: LogTestState = LogTestState.new()
	var crash_handler: Callable = func(marker: Dictionary) -> void:
		received.marker = marker
	var _connected: Variant = _log_util.previous_crash_detected.connect(crash_handler)
	_log_util.init()

	assert_false(_log_util.was_previous_shutdown_clean(), "存在运行中标记时应报告上次未干净关闭。")
	assert_eq(GFVariantData.get_option_string(_log_util.get_previous_crash_marker(), "trace_id"), "previous-trace", "应保留上次运行标记内容。")
	assert_eq(GFVariantData.get_option_string(received.marker, "trace_id"), "previous-trace", "初始化时应发出上次异常退出信号。")


func test_sink_receives_structured_entries_and_lifecycle() -> void:
	var sink: CapturingLogSink = CapturingLogSink.new()

	_log_util.add_sink(sink)
	_log_util.warn("Sink", "captured", {"code": "W1"})
	assert_push_warning("[Sink] captured")
	_log_util.flush_sinks()
	_log_util.remove_sink(sink)

	assert_eq(sink.init_count, 1, "初始化后的日志工具注册 sink 时应立即调用 init。")
	assert_eq(sink.owner_instance, _log_util, "sink init 应收到日志工具实例。")
	assert_eq(sink.entries.size(), 1, "sink 应收到结构化日志条目。")
	var first_entry: Dictionary = sink.entries[0]
	var first_context: Dictionary = GFVariantData.get_option_dictionary(first_entry, "context")
	assert_eq(GFVariantData.get_option_string(first_context, "code"), "W1", "sink 应收到上下文副本。")
	assert_eq(sink.flush_count, 1, "flush_sinks 应转发到 sink。")
	assert_eq(sink.shutdown_count, 1, "remove_sink 默认应关闭 sink。")


func test_json_line_log_sink_writes_sanitized_entries() -> void:
	var jsonl_path: String = _LOG_DIR + "gf_json_line_sink_test.jsonl"
	var _remove_error: Error = DirAccess.remove_absolute(jsonl_path)
	var sink: GFJsonLineLogSink = GFJsonLineLogSink.new()
	sink.file_path = jsonl_path
	sink.flush_immediately = true

	_log_util.add_sink(sink)
	_log_util.info("JsonSink", "structured", {
		"profile": &"keyboard",
		"position": Vector2(1.0, 2.0),
	})
	_log_util.remove_sink(sink)

	var file: FileAccess = FileAccess.open(jsonl_path, FileAccess.READ)
	assert_not_null(file, "JSONL sink 应创建可读取文件。")
	var line: String = file.get_line()
	file.close()

	var parsed: Dictionary = GFVariantData.as_dictionary(JSON.parse_string(line))
	var parsed_context: Dictionary = GFVariantData.get_option_dictionary(parsed, "context")
	assert_not_null(parsed, "JSONL 每一行应是合法 JSON 对象。")
	assert_eq(GFVariantData.get_option_string(parsed, "tag"), "JsonSink", "JSONL 应保留 tag 字段。")
	assert_eq(GFVariantData.get_option_string(parsed, "message"), "structured", "JSONL 应保留 message 字段。")
	assert_eq(GFVariantData.get_option_string(parsed_context, "profile"), "keyboard", "StringName 上下文应被转成 JSON 字符串。")
	assert_true(GFVariantData.get_option_value(parsed_context, "position") is String, "非 JSON 原生值应被稳定字符串化。")
	assert_true(GFVariantData.get_option_string(parsed_context, "position").contains(","), "Vector2 字符串应保留坐标信息。")


func test_json_line_log_sink_derives_path_and_cleans_old_default_files() -> void:
	for index: int in range(4):
		var fake_file: FileAccess = FileAccess.open(_LOG_DIR + "gf_log_20240101_000000_%03d.jsonl" % index, FileAccess.WRITE)
		if fake_file != null:
			var _store_line_result_268: Variant = fake_file.store_line("{}")
			fake_file.close()

	var sink: GFJsonLineLogSink = GFJsonLineLogSink.new()
	sink.max_jsonl_files = 2
	_log_util.add_sink(sink)
	_log_util.remove_sink(sink)

	var count: int = 0
	var dir: DirAccess = DirAccess.open(_LOG_DIR)
	assert_not_null(dir, "logs 目录应存在。")
	var _list_begin_error: Error = dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("gf_log_") and file_name.ends_with(".jsonl"):
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()

	assert_true(sink.get_file_path().ends_with(".jsonl"), "默认 JSONL 路径应由当前日志文件派生。")
	assert_true(count <= 2, "默认 JSONL 文件数量应按 max_jsonl_files 清理。")


func test_batched_log_sink_flushes_to_callback_and_signal() -> void:
	var sink: GFBatchedLogSink = GFBatchedLogSink.new()
	sink.batch_size = 2
	sink.flush_interval_msec = 0
	var payloads: Array[Dictionary] = []
	var emitted_batches: Array = []
	sink.sender_callback = func(payload: Dictionary) -> Dictionary:
		payloads.append(payload.duplicate(true))
		return { "ok": true }
	var batch_handler: Callable = func(batch: Array[Dictionary]) -> void:
		emitted_batches.append(batch)
	var _connected: Variant = sink.batch_ready.connect(batch_handler)

	_log_util.add_sink(sink)
	_log_util.info("Batch", "one")
	_log_util.info("Batch", "two")

	assert_eq(payloads.size(), 1, "达到 batch_size 时应调用发送回调。")
	var batch_payload: Dictionary = payloads[0]
	assert_eq(GFVariantData.get_option_array(batch_payload, "logs").size(), 2, "发送载荷应包含一个完整批次。")
	assert_eq(emitted_batches.size(), 1, "flush 时应发出 batch_ready 信号。")
	assert_eq(sink.get_pending_count(), 0, "完整批次发送后队列应清空。")

	_log_util.remove_sink(sink)


func test_batched_log_sink_caps_queue_and_reports_snapshot() -> void:
	var sink: GFBatchedLogSink = GFBatchedLogSink.new()
	sink.batch_size = 10
	sink.max_queue_size = 1
	sink.flush_interval_msec = 0

	_log_util.add_sink(sink)
	_log_util.info("Batch", "one")
	_log_util.info("Batch", "two")

	var snapshot: Dictionary = sink.get_debug_snapshot()
	assert_eq(sink.get_pending_count(), 1, "队列应按 max_queue_size 裁剪。")
	assert_eq(sink.get_dropped_count(), 1, "被裁剪的日志应计入 dropped_count。")
	assert_eq(GFVariantData.get_option_int(snapshot, "pending_count"), 1, "调试快照应包含 pending_count。")
	assert_eq(GFVariantData.get_option_int(snapshot, "dropped_count"), 1, "调试快照应包含 dropped_count。")

	_log_util.remove_sink(sink)


func test_min_level_filters_lower_level_logs() -> void:
	watch_signals(_log_util)
	_log_util.min_level = GFLogUtility.LogLevel.WARN

	_log_util.info("Filtered", "hidden")

	assert_signal_not_emitted(_log_util, "log_emitted", "低于 min_level 的日志不应发出信号。")


func test_lazy_log_does_not_build_filtered_message() -> void:
	var counter: LogTestState = LogTestState.new()
	_log_util.min_level = GFLogUtility.LogLevel.ERROR

	_log_util.debug_lazy("Lazy", func() -> String:
		counter.build += 1
		return "expensive"
	)

	assert_eq(counter.build, 0, "被等级过滤的 lazy 日志不应执行 message_builder。")


func test_lazy_log_does_not_build_filtered_context() -> void:
	var counter: LogTestState = LogTestState.new()
	_log_util.min_level = GFLogUtility.LogLevel.ERROR

	var message_builder: Callable = func() -> String:
		counter.message_build_count += 1
		return "expensive"
	var context_builder: Callable = func() -> Dictionary:
		counter.context_build_count += 1
		return {"expensive": true}

	_log_util.debug_lazy("Lazy", message_builder, context_builder)

	assert_eq(counter.message_build_count, 0, "被等级过滤的 lazy 日志不应执行 message_builder。")
	assert_eq(counter.context_build_count, 0, "被等级过滤的 lazy 日志不应执行 context_builder。")


func test_lazy_log_builds_message_when_enabled() -> void:
	var counter: LogTestState = LogTestState.new()
	var received: LogTestState = LogTestState.new()
	var log_handler: Callable = func(_level: int, _tag: String, message: String) -> void:
		received.message = message
	var _connected: Variant = _log_util.log_emitted.connect(log_handler)

	_log_util.info_lazy("Lazy", func() -> String:
		counter.build += 1
		return "built"
	)

	assert_eq(counter.build, 1, "未被过滤的 lazy 日志应执行 message_builder。")
	assert_eq(received.message, "built", "lazy 日志应输出构造后的消息。")


func test_memory_entries_are_capped_and_ordered() -> void:
	_log_util.max_memory_entries = 2
	_log_util.clear_memory_entries()

	_log_util.info("Memory", "one")
	_log_util.info("Memory", "two")
	_log_util.info("Memory", "three")

	var entries: Array[Dictionary] = _log_util.get_recent_entries()
	assert_eq(entries.size(), 2, "内存日志应遵守容量上限。")
	var older_entry: Dictionary = entries[0]
	var newer_entry: Dictionary = entries[1]
	assert_eq(GFVariantData.get_option_string(older_entry, "message"), "two", "内存日志应保留较新的条目并保持从旧到新排序。")
	assert_eq(GFVariantData.get_option_string(newer_entry, "message"), "three", "最新条目应位于末尾。")
	assert_eq(_log_util.get_dropped_memory_entry_count(), 1, "超出容量的条目应计入丢弃数量。")


func test_memory_entries_support_offset_reads_after_wrap() -> void:
	_log_util.max_memory_entries = 3
	_log_util.clear_memory_entries()

	_log_util.info("Memory", "one")
	_log_util.info("Memory", "two")
	_log_util.info("Memory", "three")
	_log_util.info("Memory", "four")

	var entries: Array[Dictionary] = _log_util.get_entries(1, 2)
	assert_eq(entries.size(), 2, "按偏移读取应返回请求数量。")
	var first_entry: Dictionary = entries[0]
	var second_entry: Dictionary = entries[1]
	assert_eq(GFVariantData.get_option_string(first_entry, "message"), "three", "环形缓冲按偏移读取应保持逻辑顺序。")
	assert_eq(GFVariantData.get_option_string(second_entry, "message"), "four", "环形缓冲最新条目应位于读取结果末尾。")


func test_lowering_memory_limit_keeps_newest_entries() -> void:
	_log_util.max_memory_entries = 4
	_log_util.clear_memory_entries()

	_log_util.info("Memory", "one")
	_log_util.info("Memory", "two")
	_log_util.info("Memory", "three")
	_log_util.info("Memory", "four")

	_log_util.max_memory_entries = 2

	var entries: Array[Dictionary] = _log_util.get_recent_entries()
	assert_eq(entries.size(), 2, "降低容量后内存日志应立即裁剪。")
	var first_entry: Dictionary = entries[0]
	var second_entry: Dictionary = entries[1]
	assert_eq(GFVariantData.get_option_string(first_entry, "message"), "three", "降低容量后应保留较新的条目。")
	assert_eq(GFVariantData.get_option_string(second_entry, "message"), "four", "降低容量后最新条目应位于末尾。")
	assert_eq(_log_util.get_dropped_memory_entry_count(), 2, "降低容量裁剪的条目应计入丢弃数量。")


# --- 内部类 ---

class CapturingLogSink extends GFLogSink:
	var init_count: int = 0
	var flush_count: int = 0
	var shutdown_count: int = 0
	var owner_instance: Object
	var entries: Array[Dictionary] = []

	func init(owner: Object) -> void:
		init_count += 1
		owner_instance = owner

	func write(entry: Dictionary) -> void:
		entries.append(entry.duplicate(true))

	func flush() -> void:
		flush_count += 1

	func shutdown() -> void:
		shutdown_count += 1


class LogTestState:
	var level: int = -1
	var tag: String = ""
	var message: String = ""
	var entry: Dictionary = {}
	var marker: Dictionary = {}
	var build: int = 0
	var message_build_count: int = 0
	var context_build_count: int = 0
