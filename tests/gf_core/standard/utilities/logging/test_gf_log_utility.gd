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


func test_log_entry_bounds_long_tag_and_message_consistently() -> void:
	var received: LogTestState = LogTestState.new()
	var entry_handler: Callable = func(log_entry: Dictionary) -> void:
		received.entry = log_entry
	var log_handler: Callable = func(level: int, tag: String, message: String) -> void:
		received.level = level
		received.tag = tag
		received.message = message
	var _entry_connected: Variant = _log_util.log_entry_emitted.connect(entry_handler)
	var _log_connected: Variant = _log_util.log_emitted.connect(log_handler)
	var long_tag: String = "T".repeat(4096) + "TAG_TAIL"
	var long_message: String = "M".repeat(4096) + "MESSAGE_TAIL"

	_log_util.info(long_tag, long_message)

	var received_entry: Dictionary = received.entry
	var entry_tag: String = GFVariantData.get_option_string(received_entry, "tag")
	var entry_message: String = GFVariantData.get_option_string(received_entry, "message")
	var entry_text: String = GFVariantData.get_option_string(received_entry, "text")
	var recent_entries: Array[Dictionary] = _log_util.get_recent_entries(1)
	var recent_entry: Dictionary = recent_entries[0]
	assert_true(entry_tag.length() < long_tag.length(), "超长 tag 应按日志字符串预算截断。")
	assert_true(entry_message.length() < long_message.length(), "超长 message 应按日志字符串预算截断。")
	assert_true(entry_tag.ends_with("..."), "截断后的 tag 应保留明确省略标记。")
	assert_true(entry_message.ends_with("..."), "截断后的 message 应保留明确省略标记。")
	assert_eq(received.tag, entry_tag, "兼容日志信号应广播实际写入条目的 tag。")
	assert_eq(received.message, entry_message, "兼容日志信号应广播实际写入条目的 message。")
	assert_true(entry_text.contains("[%s] %s" % [entry_tag, entry_message]), "格式化文本应由预算后的 tag 和 message 构建。")
	assert_false(entry_text.contains("TAG_TAIL"), "格式化文本不得保留被截断的 tag 尾部。")
	assert_false(entry_text.contains("MESSAGE_TAIL"), "格式化文本不得保留被截断的 message 尾部。")
	assert_eq(GFVariantData.get_option_string(recent_entry, "tag"), entry_tag, "内存日志应保留同一份预算后的 tag。")
	assert_eq(GFVariantData.get_option_string(recent_entry, "message"), entry_message, "内存日志应保留同一份预算后的 message。")


func test_log_entry_preserves_short_values_and_message_newlines() -> void:
	var received: LogTestState = LogTestState.new()
	var entry_handler: Callable = func(log_entry: Dictionary) -> void:
		received.entry = log_entry
	var log_handler: Callable = func(level: int, tag: String, message: String) -> void:
		received.level = level
		received.tag = tag
		received.message = message
	var _entry_connected: Variant = _log_util.log_entry_emitted.connect(entry_handler)
	var _log_connected: Variant = _log_util.log_emitted.connect(log_handler)
	var short_tag: String = "ShortTag"
	var short_message: String = "first line\nsecond line"

	_log_util.info(short_tag, short_message)

	var received_entry: Dictionary = received.entry
	assert_eq(GFVariantData.get_option_string(received_entry, "tag"), short_tag, "预算内 tag 不应被修改。")
	assert_eq(GFVariantData.get_option_string(received_entry, "message"), short_message, "预算内 message 与换行不应被修改。")
	assert_eq(received.tag, short_tag, "兼容日志信号应保留预算内 tag。")
	assert_eq(received.message, short_message, "兼容日志信号应保留预算内 message 与换行。")
	assert_true(GFVariantData.get_option_string(received_entry, "text").contains(short_message), "格式化文本应保留预算内多行 message。")


func test_trace_id_uses_log_budget_across_entry_memory_and_public_sink() -> void:
	var received: LogTestState = LogTestState.new()
	var entry_handler: Callable = func(log_entry: Dictionary) -> void:
		received.entry = log_entry
	var _connected: Variant = _log_util.log_entry_emitted.connect(entry_handler)
	var sink: CapturingLogSink = CapturingLogSink.new()
	var long_trace_id: String = "T".repeat(4096) + "TRACE_TAIL"

	_log_util.set_trace_id(long_trace_id)
	_log_util.add_sink(sink)
	_log_util.info("Trace", "bounded")
	_log_util.remove_sink(sink)

	var bounded_trace_id: String = _log_util.get_trace_id()
	var received_entry: Dictionary = received.entry
	var entry_context: Dictionary = GFVariantData.get_option_dictionary(received_entry, "context")
	var recent_entries: Array[Dictionary] = _log_util.get_recent_entries(1)
	var recent_entry: Dictionary = recent_entries[0]
	var sink_entry: Dictionary = sink.entries[0]
	assert_true(bounded_trace_id.length() < long_trace_id.length(), "超长 trace_id 应复用日志字符串预算。")
	assert_true(bounded_trace_id.ends_with("..."), "预算截断后的 trace_id 应保留明确省略标记。")
	assert_false(bounded_trace_id.contains("TRACE_TAIL"), "trace_id 不得保留预算外尾部。")
	assert_eq(GFVariantData.get_option_string(received_entry, "trace_id"), bounded_trace_id, "结构化条目应使用预算后的 trace_id。")
	assert_eq(GFVariantData.get_option_string(entry_context, "trace_id"), bounded_trace_id, "结构化上下文应使用同一份预算后的 trace_id。")
	assert_eq(GFVariantData.get_option_string(recent_entry, "trace_id"), bounded_trace_id, "内存日志应使用同一份预算后的 trace_id。")
	assert_eq(GFVariantData.get_option_string(sink_entry, "trace_id"), bounded_trace_id, "普通 public sink 应接收预算后的 trace_id。")


func test_public_sink_redacts_path_like_trace_id_without_changing_debug_entry() -> void:
	var sink: CapturingLogSink = CapturingLogSink.new()
	var private_trace_id: String = "C:\\Users\\PrivatePlayer\\session.trace"

	_log_util.set_trace_id(private_trace_id)
	_log_util.add_sink(sink)
	_log_util.info("Trace", "profile boundary")
	_log_util.remove_sink(sink)

	var recent_entries: Array[Dictionary] = _log_util.get_recent_entries(1)
	var recent_entry: Dictionary = recent_entries[0]
	var sink_entry: Dictionary = sink.entries[0]
	var sink_context: Dictionary = GFVariantData.get_option_dictionary(sink_entry, "context")
	assert_eq(_log_util.get_trace_id(), private_trace_id, "预算内 trace_id 应保留 canonical debug 值。")
	assert_eq(GFVariantData.get_option_string(recent_entry, "trace_id"), private_trace_id, "本地 debug 条目应保留路径型 trace_id。")
	assert_eq(GFVariantData.get_option_string(sink_entry, "trace_id"), "<redacted_path>", "普通 public sink 应脱敏顶层 trace_id。")
	assert_eq(GFVariantData.get_option_string(sink_context, "trace_id"), "<redacted_path>", "普通 public sink 的 context 应使用相同脱敏语义。")
	assert_false(JSON.stringify(sink_entry).contains("PrivatePlayer"), "普通 public sink 不得残留 trace_id 中的私有路径。")


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
	var tags_marker: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(context, "tags"),
		"__gf_report_value__"
	)
	assert_eq(GFVariantData.get_option_int(tags_marker, "version"), 1)
	assert_eq(GFVariantData.get_option_string(tags_marker, "type"), "PackedArray")
	assert_true(GFVariantData.get_option_bool(tags_marker, "redacted"))
	assert_eq(
		GFVariantData.get_option_string(tags_marker, "collection_type"),
		"PackedStringArray"
	)
	assert_eq(GFVariantData.get_option_int(tags_marker, "count"), 2)
	assert_eq(GFVariantData.get_option_array(tags_marker, "items"), ["alpha", "beta"])


func test_sanitize_log_value_marks_circular_references() -> void:
	var context: Dictionary = {}
	context["self"] = context

	var sanitized: Dictionary = GFVariantData.as_dictionary(GFLogUtility.sanitize_log_value(context))

	var marker: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(sanitized, "self"),
		"__gf_report_value__"
	)
	assert_eq(GFVariantData.get_option_string(marker, "type"), "CircularReference", "日志上下文循环引用应使用统一 report marker。")


func test_sanitize_log_value_converts_nonfinite_floats_to_json_safe_text() -> void:
	var sanitized: Dictionary = GFVariantData.as_dictionary(GFLogUtility.sanitize_log_value({
		"nan": NAN,
		"positive_inf": INF,
		"negative_inf": -INF,
	}))
	var json_text: String = JSON.stringify(sanitized)

	assert_false(json_text.contains(":null"), "日志清洗不应让非有限 float 被 JSON.stringify 替换成 null。")
	var nan_marker: Dictionary = GFVariantData.get_option_dictionary(GFVariantData.get_option_dictionary(sanitized, "nan"), "__gf_variant__")
	var positive_marker: Dictionary = GFVariantData.get_option_dictionary(GFVariantData.get_option_dictionary(sanitized, "positive_inf"), "__gf_variant__")
	var negative_marker: Dictionary = GFVariantData.get_option_dictionary(GFVariantData.get_option_dictionary(sanitized, "negative_inf"), "__gf_variant__")
	assert_eq(GFVariantData.get_option_string(nan_marker, "value"), "NaN", "日志中的 NaN 应使用统一 typed marker。")
	assert_eq(GFVariantData.get_option_string(positive_marker, "value"), "INF", "日志中的正无穷应使用统一 typed marker。")
	assert_eq(GFVariantData.get_option_string(negative_marker, "value"), "-INF", "日志中的负无穷应使用统一 typed marker。")


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


func test_log_utility_tick_forwards_idle_progress_to_sinks() -> void:
	var sink: CapturingLogSink = CapturingLogSink.new()
	_log_util.add_sink(sink)

	_log_util.tick(0.25)

	assert_eq(sink.tick_count, 1, "每次 GF tick 应把时间推进一次转发给 sink。")
	assert_eq(sink.last_tick_delta, 0.25, "sink 应收到未改写的帧间隔。")
	_log_util.remove_sink(sink)


func test_log_utility_tick_flushes_idle_builtin_file() -> void:
	_log_util.flush_immediately = false
	_log_util.flush_interval_msec = 100_000
	_log_util.info("IdleFlush", "builtin file")

	assert_true(_log_util._file_has_unflushed_data, "写入后应存在尚未 flush 的内置日志。")
	_log_util.tick(100.0)

	assert_false(_log_util._file_has_unflushed_data, "达到空闲间隔后应 flush 内置日志。")


func test_log_utility_init_is_idempotent_for_file_and_sinks() -> void:
	var sink: CapturingLogSink = CapturingLogSink.new()
	_log_util.add_sink(sink)
	var original_path: String = _log_util.get_log_file_path()

	_log_util.init()

	assert_eq(_log_util.get_log_file_path(), original_path, "重复 init 不应替换仍在使用的日志文件。")
	assert_eq(sink.init_count, 1, "重复 init 不应重复初始化已注册 sink。")
	_log_util.remove_sink(sink)


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
	var profile_marker: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(parsed_context, "profile"),
		"__gf_variant__"
	)
	assert_eq(GFVariantData.get_option_string(profile_marker, "type"), "StringName", "StringName 上下文应使用统一 typed marker。")
	var position_marker: Dictionary = GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(parsed_context, "position"),
		"__gf_variant__"
	)
	assert_eq(GFVariantData.get_option_string(position_marker, "type"), "Vector2", "非 JSON 原生值应使用统一 typed marker。")


func test_json_line_log_sink_appends_custom_file_when_configured() -> void:
	var jsonl_path: String = _LOG_DIR + "gf_json_line_sink_append_test.jsonl"
	var seed_file: FileAccess = FileAccess.open(jsonl_path, FileAccess.WRITE)
	assert_not_null(seed_file, "测试应能创建 JSONL 种子文件。")
	if seed_file != null:
		var _seed_written: Variant = seed_file.store_line("{\"seed\":true}")
		seed_file.close()
	var sink: GFJsonLineLogSink = GFJsonLineLogSink.new()
	sink.file_path = jsonl_path
	sink.file_open_mode = GFJsonLineLogSink.FileOpenMode.APPEND
	sink.flush_immediately = true

	_log_util.add_sink(sink)
	_log_util.info("JsonSink", "append")
	_log_util.remove_sink(sink)

	var file: FileAccess = FileAccess.open(jsonl_path, FileAccess.READ)
	assert_not_null(file, "JSONL append 文件应可读取。")
	var first_line: String = file.get_line()
	var second_line: String = file.get_line()
	file.close()

	assert_eq(first_line, "{\"seed\":true}", "append 模式不应截断已有 JSONL 内容。")
	assert_false(second_line.is_empty(), "append 模式应在已有内容后追加新日志。")


func test_json_line_log_sink_repeated_init_does_not_truncate_active_file() -> void:
	var jsonl_path: String = _LOG_DIR + "gf_json_line_sink_reinit_test.jsonl"
	var _remove_error: Error = DirAccess.remove_absolute(jsonl_path)
	var sink: GFJsonLineLogSink = GFJsonLineLogSink.new()
	sink.file_path = jsonl_path
	sink.flush_immediately = true

	_log_util.add_sink(sink)
	_log_util.info("JsonSink", "before reinit")
	sink.init(_log_util)
	_log_util.info("JsonSink", "after reinit")
	_log_util.remove_sink(sink)

	var file: FileAccess = FileAccess.open(jsonl_path, FileAccess.READ)
	assert_not_null(file, "重复 init 后 JSONL 文件仍应可读。")
	var lines: PackedStringArray = PackedStringArray()
	while file != null and not file.eof_reached():
		var line: String = file.get_line()
		if not line.is_empty():
			var _line_appended: bool = lines.append(line)
	if file != null:
		file.close()
	assert_eq(lines.size(), 2, "重复 init 不得截断活动 JSONL 文件或泄漏旧句柄。")


func test_json_line_log_sink_normalizes_relative_paths_under_user_logs() -> void:
	var relative_name: String = "gf_relative_json_line_sink_%d.jsonl" % Time.get_ticks_usec()
	var normalized_path: String = _LOG_DIR.path_join(relative_name)
	var sink: GFJsonLineLogSink = GFJsonLineLogSink.new()
	sink.file_path = relative_name

	_log_util.add_sink(sink)
	_log_util.remove_sink(sink)

	assert_eq(sink.get_file_path(), normalized_path, "相对 JSONL 路径应稳定归一到 user://logs。")
	var _normalized_remove_error: Error = DirAccess.remove_absolute(normalized_path)
	var _relative_remove_error: Error = DirAccess.remove_absolute(relative_name)


func test_json_line_log_sink_can_fail_when_custom_file_exists() -> void:
	var jsonl_path: String = _LOG_DIR + "gf_json_line_sink_fail_exists_test.jsonl"
	var seed_file: FileAccess = FileAccess.open(jsonl_path, FileAccess.WRITE)
	assert_not_null(seed_file, "测试应能创建 JSONL 已存在文件。")
	if seed_file != null:
		var _seed_written: Variant = seed_file.store_line("{\"seed\":true}")
		seed_file.close()
	var sink: GFJsonLineLogSink = GFJsonLineLogSink.new()
	sink.file_path = jsonl_path
	sink.file_open_mode = GFJsonLineLogSink.FileOpenMode.FAIL_IF_EXISTS

	_log_util.add_sink(sink)
	var snapshot: Dictionary = sink.get_debug_snapshot()
	assert_push_warning(
		"[GFJsonLineLogSink] JSONL 日志文件已存在：%s，错误码：%d"
		% [jsonl_path, ERR_ALREADY_EXISTS]
	)

	assert_false(GFVariantData.get_option_bool(snapshot, "is_open", true), "FAIL_IF_EXISTS 应拒绝打开已有 JSONL 文件。")
	assert_eq(GFVariantData.get_option_int(snapshot, "last_error"), ERR_ALREADY_EXISTS, "FAIL_IF_EXISTS 应报告 ERR_ALREADY_EXISTS。")

	_log_util.remove_sink(sink)


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


func test_json_line_log_sinks_derive_distinct_default_paths() -> void:
	var first_sink: GFJsonLineLogSink = GFJsonLineLogSink.new()
	var second_sink: GFJsonLineLogSink = GFJsonLineLogSink.new()
	first_sink.max_jsonl_files = 100
	second_sink.max_jsonl_files = 100
	first_sink.flush_immediately = true
	second_sink.flush_immediately = true

	_log_util.add_sink(first_sink)
	_log_util.add_sink(second_sink)
	var first_path: String = first_sink.get_file_path()
	var second_path: String = second_sink.get_file_path()
	_log_util.info("JsonSink", "independent writers")
	_log_util.remove_sink(first_sink)
	_log_util.remove_sink(second_sink)

	assert_ne(first_path, second_path, "两个活动默认 JSONL sink 不得共享同一个可写文件。")
	assert_true(FileAccess.file_exists(first_path), "第一个默认 sink 应拥有自己的文件。")
	assert_true(FileAccess.file_exists(second_path), "第二个默认 sink 应拥有自己的文件。")
	var _first_remove_error: Error = DirAccess.remove_absolute(first_path)
	var _second_remove_error: Error = DirAccess.remove_absolute(second_path)


func test_json_line_log_sink_flushes_idle_file_on_utility_tick() -> void:
	var sink: GFJsonLineLogSink = GFJsonLineLogSink.new()
	sink.max_jsonl_files = 100
	sink.flush_interval_msec = 100_000

	_log_util.add_sink(sink)
	_log_util.info("JsonSink", "idle flush")
	assert_true(sink._has_unflushed_data, "JSONL 写入后应保持待 flush 状态。")

	_log_util.tick(100.0)

	assert_false(sink._has_unflushed_data, "GF tick 达到间隔后应 flush JSONL 文件。")
	var sink_path: String = sink.get_file_path()
	_log_util.remove_sink(sink)
	var _remove_error: Error = DirAccess.remove_absolute(sink_path)


func test_json_line_log_sink_reports_parent_directory_errors() -> void:
	var blocker_path: String = _LOG_DIR + "jsonl_parent_blocker"
	var _remove_blocker_error: Error = DirAccess.remove_absolute(blocker_path)
	var blocker_file: FileAccess = FileAccess.open(blocker_path, FileAccess.WRITE)
	assert_not_null(blocker_file, "测试应能创建阻塞目录创建的文件。")
	if blocker_file != null:
		var _store_result: Variant = blocker_file.store_string("blocker")
		blocker_file.close()

	var sink: GFJsonLineLogSink = GFJsonLineLogSink.new()
	sink.file_path = blocker_path.path_join("out.jsonl")

	_log_util.add_sink(sink)
	var snapshot: Dictionary = sink.get_debug_snapshot()
	var last_error: int = GFVariantData.get_option_int(snapshot, "last_error")
	assert_push_warning(
		"[GFJsonLineLogSink] 无法创建日志文件：%s，错误码：%d"
		% [sink.file_path, last_error]
	)

	assert_false(GFVariantData.get_option_bool(snapshot, "is_open", true), "目录创建失败时 JSONL 文件不应保持打开。")
	assert_ne(last_error, OK, "目录创建失败应记录错误码。")
	assert_true(
		GFVariantData.get_option_string(snapshot, "last_error_message").contains(blocker_path),
		"调试快照应保留失败路径。"
	)

	_log_util.remove_sink(sink)
	var _cleanup_blocker_error: Error = DirAccess.remove_absolute(blocker_path)


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
	assert_eq(emitted_batches.size(), 0, "sender_callback 有效时由 callback 独占交付，不应重复发出 batch_ready。")
	assert_eq(sink.get_pending_count(), 0, "完整批次发送后队列应清空。")

	_log_util.remove_sink(sink)


func test_batched_log_sink_flushes_idle_partial_batch_on_utility_tick() -> void:
	var sink: GFBatchedLogSink = GFBatchedLogSink.new()
	sink.batch_size = 10
	sink.flush_interval_msec = 1000
	var payloads: Array[Dictionary] = []
	sink.sender_callback = func(payload: Dictionary) -> Dictionary:
		payloads.append(payload.duplicate(true))
		return { "ok": true }

	_log_util.add_sink(sink)
	_log_util.info("Batch", "idle partial")
	assert_eq(sink.get_pending_count(), 1, "未达到 batch_size 的日志应先保留。")
	_log_util.tick(1.0)

	assert_eq(payloads.size(), 1, "达到 flush 间隔后，即使没有新日志也应发送部分批次。")
	assert_eq(sink.get_pending_count(), 0, "空闲间隔 flush 后队列应清空。")
	_log_util.remove_sink(sink)


func test_batched_log_sink_shutdown_drains_all_synchronous_batches() -> void:
	var sink: GFBatchedLogSink = GFBatchedLogSink.new()
	sink.batch_size = 10
	sink.flush_interval_msec = 0
	var payloads: Array[Dictionary] = []
	sink.sender_callback = func(payload: Dictionary) -> Dictionary:
		payloads.append(payload.duplicate(true))
		return { "ok": true }

	_log_util.add_sink(sink)
	for index: int in range(5):
		_log_util.info("Batch", "shutdown-%d" % index)
	sink.batch_size = 2
	_log_util.remove_sink(sink)

	assert_eq(payloads.size(), 3, "shutdown 应连续发送全部同步批次，而不是只处理第一批。")
	assert_eq(sink.get_pending_count(), 0, "成功的 shutdown drain 不得留下不可达日志。")


func test_batched_log_sink_receives_privacy_encoded_context() -> void:
	var private_node: Node = Node.new()
	private_node.name = "PrivateBatchedLogNode"
	var private_trace_id: String = "C:\\Users\\PrivatePlayer\\batch.trace"
	var sink: GFBatchedLogSink = GFBatchedLogSink.new()
	sink.batch_size = 1
	sink.flush_interval_msec = 0
	var payloads: Array[Dictionary] = []
	sink.sender_callback = func(payload: Dictionary) -> Dictionary:
		payloads.append(payload.duplicate(true))
		return { "ok": true, "accepted": 1 }

	_log_util.set_trace_id(private_trace_id)
	_log_util.add_sink(sink)
	_log_util.info("/private/log/tag", "\\\\server\\private\\message.txt", {
		"node": private_node,
		"asset": "res://private/batched_asset.tres",
	})
	private_node.free()

	assert_eq(payloads.size(), 1, "达到 batch_size 时应生成一个外发载荷。")
	var payload_text: String = JSON.stringify(payloads[0])
	assert_false(payload_text.contains("PrivateBatchedLogNode"), "批量外发日志不得继承本地 debug 节点名。")
	assert_false(payload_text.contains("batched_asset.tres"), "批量外发日志必须按 privacy profile 脱敏路径。")
	assert_false(payload_text.contains("/private/log/tag"), "批量外发日志的 tag 必须按 privacy profile 脱敏。")
	assert_false(payload_text.contains("server\\private"), "批量外发日志的 message 必须按 privacy profile 脱敏。")
	assert_false(payload_text.contains("PrivatePlayer"), "批量外发日志的 trace_id 必须按 privacy profile 脱敏。")
	var first_log: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_array(payloads[0], "logs")[0])
	assert_eq(GFVariantData.get_option_string(first_log, "trace_id"), "<redacted_path>", "批量外发日志的顶层 trace_id 应使用 privacy profile。")
	assert_false(GFVariantData.get_option_string(first_log, "text").contains("private"), "外发 text 必须由已清洗 tag/message/context 重建。")

	_log_util.remove_sink(sink)


func test_batched_log_sink_requeues_batch_when_sender_fails() -> void:
	var sink: GFBatchedLogSink = GFBatchedLogSink.new()
	sink.batch_size = 2
	sink.flush_interval_msec = 0
	var emitted_batches: Array = []
	sink.sender_callback = func(_payload: Dictionary) -> Dictionary:
		return { "ok": false, "error": "offline" }
	var batch_handler: Callable = func(batch: Array[Dictionary]) -> void:
		emitted_batches.append(batch)
	var _connected: Variant = sink.batch_ready.connect(batch_handler)

	_log_util.add_sink(sink)
	_log_util.info("Batch", "one")
	_log_util.info("Batch", "two")

	assert_eq(sink.get_pending_count(), 2, "sender 失败时批次应回到队列。")
	assert_eq(emitted_batches.size(), 0, "未成功交付的批次不应发出 batch_ready。")

	_log_util.remove_sink(sink)


func test_batched_log_sink_requeues_batch_when_sender_contract_is_invalid() -> void:
	var sink: GFBatchedLogSink = GFBatchedLogSink.new()
	sink.batch_size = 2
	sink.flush_interval_msec = 0
	sink.sender_callback = func(_payload: Dictionary) -> String:
		return "invalid"

	_log_util.add_sink(sink)
	_log_util.info("Batch", "one")
	_log_util.info("Batch", "two")
	var snapshot: Dictionary = sink.get_debug_snapshot()

	assert_eq(sink.get_pending_count(), 2, "sender 返回非 Dictionary 时不得丢失批次。")
	assert_eq(GFVariantData.get_option_int(snapshot, "failed_send_count"), 1, "非法 sender 结果应进入可观测失败计数。")
	assert_true(GFVariantData.get_option_string(snapshot, "last_error").contains("Dictionary"), "调试快照应解释 sender 契约失败。")
	_log_util.remove_sink(sink)


func test_batched_log_sink_requires_ok_and_rejects_legacy_success_field() -> void:
	var sink: GFBatchedLogSink = GFBatchedLogSink.new()
	sink.batch_size = 1
	sink.flush_interval_msec = 0
	sink.sender_callback = func(_payload: Dictionary) -> Dictionary:
		return { "success": true }

	_log_util.add_sink(sink)
	_log_util.info("Batch", "legacy contract")
	var snapshot: Dictionary = sink.get_debug_snapshot()

	assert_eq(sink.get_pending_count(), 1, "缺失 ok 的 sender 结果必须 fail-closed 并回队。")
	assert_eq(GFVariantData.get_option_int(snapshot, "failed_send_count"), 1, "双契约结果必须进入失败计数。")
	assert_true(GFVariantData.get_option_string(snapshot, "last_error").contains("ok: bool"), "失败信息应明确唯一 ok 契约。")
	_log_util.remove_sink(sink)


func test_batched_log_sink_requeues_unaccepted_partial_batch() -> void:
	var sink: GFBatchedLogSink = GFBatchedLogSink.new()
	sink.batch_size = 3
	sink.flush_interval_msec = 0
	var emitted_batches: Array = []
	sink.sender_callback = func(_payload: Dictionary) -> Dictionary:
		return { "ok": true, "accepted": 1 }
	var batch_handler: Callable = func(batch: Array[Dictionary]) -> void:
		emitted_batches.append(batch)
	var _connected: Variant = sink.batch_ready.connect(batch_handler)

	_log_util.add_sink(sink)
	_log_util.info("Batch", "one")
	_log_util.info("Batch", "two")
	_log_util.info("Batch", "three")

	assert_eq(sink.get_pending_count(), 2, "partial accepted 后未接受日志应回到队列。")
	assert_eq(emitted_batches.size(), 0, "sender_callback 已处理 partial ack 时不应重复发出 batch_ready。")

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


func test_sink_dispatch_uses_snapshot_when_sink_unregisters_itself() -> void:
	var removing_sink: RemovingLogSink = RemovingLogSink.new()
	var capturing_sink: CapturingLogSink = CapturingLogSink.new()
	_log_util.add_sink(removing_sink)
	_log_util.add_sink(capturing_sink)

	_log_util.info("Sink", "snapshot")

	assert_eq(removing_sink.write_count, 1, "自注销 sink 应只接收当前一次分发。")
	assert_eq(capturing_sink.entries.size(), 1, "分发期间修改 registry 不应跳过快照中的后续 sink。")
	_log_util.remove_sink(capturing_sink)


func test_sink_dispatch_blocks_recursive_sink_fanout() -> void:
	var reentrant_sink: ReentrantLogSink = ReentrantLogSink.new()
	var capturing_sink: CapturingLogSink = CapturingLogSink.new()
	_log_util.add_sink(reentrant_sink)
	_log_util.add_sink(capturing_sink)

	_log_util.info("Sink", "outer")

	assert_eq(reentrant_sink.write_count, 1, "sink 内部日志不得递归进入 sink fanout。")
	assert_eq(capturing_sink.entries.size(), 1, "递归日志不得造成后续 sink 重复接收。")
	_log_util.remove_sink(reentrant_sink)
	_log_util.remove_sink(capturing_sink)


func test_sanitize_log_value_applies_collection_width_budget() -> void:
	var values: Array = []
	for index: int in range(1000):
		values.append(index)

	var sanitized: Array = GFVariantData.as_array(GFLogUtility.sanitize_log_value(values))
	var last_entry: Dictionary = GFVariantData.as_dictionary(sanitized[sanitized.size() - 1])
	var marker: Dictionary = GFVariantData.get_option_dictionary(last_entry, "__gf_report_value__")

	assert_true(sanitized.size() < values.size(), "日志清洗必须限制集合宽度。")
	assert_eq(GFVariantData.get_option_string(marker, "type"), "CollectionBudget", "集合截断应使用统一 report marker。")


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


func test_memory_entries_since_reads_incrementally() -> void:
	_log_util.max_memory_entries = 3
	_log_util.clear_memory_entries()
	var cursor: int = _log_util.get_memory_sequence()

	_log_util.info("Memory", "one")
	_log_util.info("Memory", "two")

	var result: Dictionary = _log_util.get_entries_since(cursor)
	var entries: Array = GFVariantData.get_option_array(result, "entries")
	var first_entry: Dictionary = GFVariantData.as_dictionary(entries[0])
	var second_entry: Dictionary = GFVariantData.as_dictionary(entries[1])

	assert_eq(entries.size(), 2, "增量读取应返回游标之后的所有可用日志。")
	assert_eq(GFVariantData.get_option_string(first_entry, "message"), "one", "增量读取应保持从旧到新的顺序。")
	assert_eq(GFVariantData.get_option_string(second_entry, "message"), "two", "增量读取应包含最新日志。")
	assert_eq(GFVariantData.get_option_int(result, "next_sequence"), cursor + 2, "next_sequence 应指向下一条待读序列。")
	assert_eq(GFVariantData.get_option_int(result, "current_sequence"), _log_util.get_memory_sequence(), "报告应包含当前序列。")
	assert_false(GFVariantData.get_option_bool(result, "truncated"), "未越过环形缓存时不应标记截断。")
	assert_false(GFVariantData.get_option_bool(result, "has_more"), "未限制读取数量时不应还有剩余。")


func test_memory_entries_since_reports_limit_and_has_more() -> void:
	_log_util.max_memory_entries = 4
	_log_util.clear_memory_entries()
	var cursor: int = _log_util.get_memory_sequence()

	_log_util.info("Memory", "one")
	_log_util.info("Memory", "two")
	_log_util.info("Memory", "three")

	var result: Dictionary = _log_util.get_entries_since(cursor, 1)
	var entries: Array = GFVariantData.get_option_array(result, "entries")
	var first_entry: Dictionary = GFVariantData.as_dictionary(entries[0])

	assert_eq(entries.size(), 1, "limit 应限制本次返回条目数。")
	assert_eq(GFVariantData.get_option_string(first_entry, "message"), "one", "limit 读取应从请求游标开始。")
	assert_eq(GFVariantData.get_option_int(result, "next_sequence"), cursor + 1, "受 limit 限制时 next_sequence 应只前进已返回数量。")
	assert_true(GFVariantData.get_option_bool(result, "has_more"), "仍有未返回条目时应标记 has_more。")


func test_memory_entries_since_zero_limit_is_non_blocking_status_probe() -> void:
	_log_util.clear_memory_entries()
	var cursor: int = _log_util.get_memory_sequence()
	_log_util.info("Memory", "one")

	var result: Dictionary = _log_util.get_entries_since(cursor, 0)

	assert_eq(GFVariantData.get_option_array(result, "entries").size(), 0, "limit=0 不应返回条目。")
	assert_eq(GFVariantData.get_option_int(result, "next_sequence"), cursor, "limit=0 不应伪造游标进度。")
	assert_false(GFVariantData.get_option_bool(result, "has_more"), "limit=0 不得形成 has_more=true 且游标永不前进的循环。")


func test_memory_entries_since_reports_truncated_cursor_after_wrap() -> void:
	_log_util.max_memory_entries = 2
	_log_util.clear_memory_entries()
	var cursor: int = _log_util.get_memory_sequence()

	_log_util.info("Memory", "one")
	_log_util.info("Memory", "two")
	_log_util.info("Memory", "three")

	var result: Dictionary = _log_util.get_entries_since(cursor)
	var entries: Array = GFVariantData.get_option_array(result, "entries")
	var first_entry: Dictionary = GFVariantData.as_dictionary(entries[0])
	var second_entry: Dictionary = GFVariantData.as_dictionary(entries[1])

	assert_true(GFVariantData.get_option_bool(result, "truncated"), "请求游标早于最旧保留序列时应标记截断。")
	assert_eq(GFVariantData.get_option_int(result, "missed_count"), 1, "截断报告应说明调用方错过的条目数。")
	assert_eq(GFVariantData.get_option_int(result, "dropped_count"), 1, "截断报告应包含内存缓存总丢弃数。")
	assert_eq(GFVariantData.get_option_string(first_entry, "message"), "two", "截断后应从最旧仍保留的日志开始返回。")
	assert_eq(GFVariantData.get_option_string(second_entry, "message"), "three", "截断后仍应返回最新日志。")


func test_clear_memory_entries_preserves_sequence_cursor() -> void:
	_log_util.max_memory_entries = 3
	_log_util.clear_memory_entries()
	_log_util.info("Memory", "one")
	var cursor: int = _log_util.get_memory_sequence()

	_log_util.clear_memory_entries()
	_log_util.info("Memory", "two")

	var result: Dictionary = _log_util.get_entries_since(cursor)
	var entries: Array = GFVariantData.get_option_array(result, "entries")
	var first_entry: Dictionary = GFVariantData.as_dictionary(entries[0])

	assert_eq(entries.size(), 1, "清空缓存不应让旧游标重新读取旧日志。")
	assert_eq(GFVariantData.get_option_string(first_entry, "message"), "two", "清空后旧游标应只读取后续新增日志。")
	assert_false(GFVariantData.get_option_bool(result, "truncated"), "游标等于清空时序列时不应标记截断。")


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


func test_expanding_memory_limit_after_wrap_preserves_order() -> void:
	_log_util.max_memory_entries = 2
	_log_util.clear_memory_entries()

	_log_util.info("Memory", "one")
	_log_util.info("Memory", "two")
	_log_util.info("Memory", "three")

	_log_util.max_memory_entries = 4
	_log_util.info("Memory", "four")

	var entries: Array[Dictionary] = _log_util.get_recent_entries()
	assert_eq(entries.size(), 3, "扩容后应保留当前缓存中的日志并接收新日志。")
	assert_eq(GFVariantData.get_option_string(entries[0], "message"), "two", "扩容后旧数据顺序应保持。")
	assert_eq(GFVariantData.get_option_string(entries[1], "message"), "three", "扩容后旧数据顺序应保持。")
	assert_eq(GFVariantData.get_option_string(entries[2], "message"), "four", "扩容后新日志应追加到末尾。")


# --- 内部类 ---

class CapturingLogSink extends GFLogSink:
	var init_count: int = 0
	var flush_count: int = 0
	var shutdown_count: int = 0
	var tick_count: int = 0
	var last_tick_delta: float = 0.0
	var owner_instance: Object
	var entries: Array[Dictionary] = []

	func init(owner: Object) -> void:
		init_count += 1
		owner_instance = owner

	func write(entry: Dictionary) -> void:
		entries.append(entry.duplicate(true))

	func flush() -> void:
		flush_count += 1

	func tick(delta: float) -> void:
		tick_count += 1
		last_tick_delta = delta

	func shutdown() -> void:
		shutdown_count += 1


class RemovingLogSink extends GFLogSink:
	var owner_utility: GFLogUtility
	var write_count: int = 0

	func init(owner: Object) -> void:
		if owner is GFLogUtility:
			owner_utility = owner

	func write(_entry: Dictionary) -> void:
		write_count += 1
		if owner_utility != null:
			owner_utility.remove_sink(self)


class ReentrantLogSink extends GFLogSink:
	var owner_utility: GFLogUtility
	var write_count: int = 0

	func init(owner: Object) -> void:
		if owner is GFLogUtility:
			owner_utility = owner

	func write(_entry: Dictionary) -> void:
		write_count += 1
		if owner_utility != null:
			owner_utility.info("Sink", "nested")


class LogTestState:
	var level: int = -1
	var tag: String = ""
	var message: String = ""
	var entry: Dictionary = {}
	var marker: Dictionary = {}
	var build: int = 0
	var message_build_count: int = 0
	var context_build_count: int = 0
