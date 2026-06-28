## GFLogUtility: 集中式日志系统。
##
## 取代原生 print / push_error，提供分级日志（DEBUG → FATAL），
## 每条日志同时写入本地按日期命名的日志文件，进入内存环形缓存，
## 并通过信号和可插拔 sink 广播结构化日志条目。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFLogUtility
extends GFUtility


# --- 信号 ---

## 每次打印日志时发出，供 UI 控制台等消费者捕捉。
## [br]
## @api public
## [br]
## @param level: LogLevel 枚举值。
## [br]
## @param tag: 日志标签。
## [br]
## @param message: 日志内容。
signal log_emitted(level: int, tag: String, message: String)

## 每次打印日志时发出完整结构化条目。
## [br]
## @api public
## [br]
## @param entry: 日志条目副本。
## [br]
## @schema entry: Dictionary log entry with timestamp, unix_time, ticks_msec, trace_id, level, level_name, tag, message, context, and text.
signal log_entry_emitted(entry: Dictionary)

## 初始化时检测到上次运行未干净关闭后发出。
## [br]
## @api public
## [br]
## @param marker: 上次运行留下的标记数据。
## [br]
## @schema marker: Dictionary crash marker with trace_id, started_at, and ticks_msec when available.
signal previous_crash_detected(marker: Dictionary)


# --- 枚举 ---

## 日志等级，数值越大越严重。
## [br]
## @api public
enum LogLevel {
	## 调试信息
	DEBUG,
	## 一般信息
	INFO,
	## 警告
	WARN,
	## 错误
	ERROR,
	## 致命错误
	FATAL,
}


# --- 常量 ---

const _LOG_DIR: String = "user://logs/"
const _CRASH_MARKER_PATH: String = _LOG_DIR + "gf_log_running.marker"
const _MAX_SANITIZE_DEPTH: int = 8
const _MAX_SANITIZE_STRING_LENGTH: int = 2048


# --- 公共变量 ---

## 最多保留的日志文件数量。
## [br]
## @api public
var max_log_files: int:
	get:
		return _max_log_files
	set(value):
		_max_log_files = maxi(value, 1)

## 日志文件自动 flush 间隔。设为 0 时每条日志都立即 flush。
## [br]
## @api public
var flush_interval_msec: int = 250

## 是否强制每条日志立即 flush。高可靠日志可开启，默认关闭以减少高频 IO。
## [br]
## @api public
var flush_immediately: bool = false

## 最小输出等级。低于该等级的日志不会打印、写文件或发信号。
## [br]
## @api public
var min_level: int = LogLevel.DEBUG

## 内存中最多保留的最近日志条数。设为 0 可关闭内存缓存。
## [br]
## @api public
var max_memory_entries: int:
	get:
		return _max_memory_entries
	set(value):
		_max_memory_entries = maxi(value, 0)
		_trim_memory_entries()

## 是否写入运行中标记，用于下一次启动时判断上次是否未干净关闭。
## [br]
## @api public
var crash_marker_enabled: bool = true

## 当前日志 trace id。为空时 init() 会生成一个短 id。
## [br]
## @api public
var trace_id: String = ""


# --- 私有变量 ---

var _max_log_files: int = 10
var _max_memory_entries: int = 500
static var _LEVEL_NAMES: PackedStringArray = PackedStringArray([
	"DEBUG",
	"INFO",
	"WARN",
	"ERROR",
	"FATAL",
])
var _file: FileAccess
var _log_file_path: String
var _muted_tags: Dictionary = {}
var _last_file_flush_msec: int = 0
var _memory_entries: Array[Dictionary] = []
var _memory_head: int = 0
var _memory_dropped_count: int = 0
var _sinks: Array[GFLogSink] = []
var _is_initialized: bool = false
var _global_context: Dictionary = {}
var _global_context_provider: Callable = Callable()
var _last_shutdown_was_clean: bool = true
var _previous_crash_marker: Dictionary = {}


# --- GF 生命周期方法 ---

## 第一阶段初始化：创建日志目录、打开日志文件、清理旧文件。
## [br]
## @api public
func init() -> void:
	clear_memory_entries()
	if not DirAccess.dir_exists_absolute(_LOG_DIR):
		var make_log_dir_result: Error = DirAccess.make_dir_recursive_absolute(_LOG_DIR)
		if make_log_dir_result != OK:
			push_warning("[GFLogUtility] 无法创建日志目录：%s，错误码：%s" % [_LOG_DIR, make_log_dir_result])

	if trace_id.is_empty():
		trace_id = _generate_trace_id()
	_check_previous_crash_marker()
	_write_crash_marker()

	var datetime: Dictionary = Time.get_datetime_dict_from_system()
	var file_name: String = "gf_log_%04d%02d%02d_%02d%02d%02d_%03d.log" % [
		datetime.year,
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute,
		datetime.second,
		Time.get_ticks_msec() % 1000,
	]
	_log_file_path = _LOG_DIR + file_name

	_file = FileAccess.open(_log_file_path, FileAccess.WRITE)
	if _file == null:
		push_error("[GFLogUtility] 无法创建日志文件：%s，错误码：%s" % [_log_file_path, FileAccess.get_open_error()])
	else:
		_last_file_flush_msec = Time.get_ticks_msec()

	_cleanup_old_logs()
	_is_initialized = true
	if not _last_shutdown_was_clean:
		previous_crash_detected.emit(_previous_crash_marker.duplicate(true))
	for sink: GFLogSink in _sinks:
		if sink != null:
			sink.init(self)


## 销毁时关闭文件句柄。
## [br]
## @api public
func dispose() -> void:
	flush_sinks()
	for sink: GFLogSink in _sinks:
		if sink != null:
			sink.shutdown()

	if _file != null:
		_file.flush()
		_file.close()
		_file = null

	_is_initialized = false
	_mark_shutdown_clean()


# --- 公共方法 ---

## 输出 DEBUG 级别日志。
## [br]
## @api public
## [br]
## @param tag: 日志标签（如模块名）。
## [br]
## @param msg: 日志内容。
## [br]
## @param context: 结构化上下文字典。
## [br]
## @schema context: Dictionary[String, Variant] structured context merged into the log entry.
func debug(tag: String, msg: String, context: Dictionary = {}) -> void:
	_log(LogLevel.DEBUG, tag, msg, context)


## 延迟输出 DEBUG 级别日志。只有日志未被过滤时才调用 message_builder。
## [br]
## @api public
## [br]
## @param tag: 日志标签。
## [br]
## @param message_builder: 延迟构造日志消息的回调。
## [br]
## @param context_builder: 延迟构造结构化上下文的回调。
func debug_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:
	_log_lazy(LogLevel.DEBUG, tag, message_builder, context_builder)


## 输出 INFO 级别日志。
## [br]
## @api public
## [br]
## @param tag: 日志标签。
## [br]
## @param msg: 日志内容。
## [br]
## @param context: 结构化上下文字典。
## [br]
## @schema context: Dictionary[String, Variant] structured context merged into the log entry.
func info(tag: String, msg: String, context: Dictionary = {}) -> void:
	_log(LogLevel.INFO, tag, msg, context)


## 延迟输出 INFO 级别日志。只有日志未被过滤时才调用 message_builder。
## [br]
## @api public
## [br]
## @param tag: 日志标签。
## [br]
## @param message_builder: 延迟构造日志消息的回调。
## [br]
## @param context_builder: 延迟构造结构化上下文的回调。
func info_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:
	_log_lazy(LogLevel.INFO, tag, message_builder, context_builder)


## 输出 WARN 级别日志。
## [br]
## @api public
## [br]
## @param tag: 日志标签。
## [br]
## @param msg: 日志内容。
## [br]
## @param context: 结构化上下文字典。
## [br]
## @schema context: Dictionary[String, Variant] structured context merged into the log entry.
func warn(tag: String, msg: String, context: Dictionary = {}) -> void:
	_log(LogLevel.WARN, tag, msg, context)


## 延迟输出 WARN 级别日志。只有日志未被过滤时才调用 message_builder。
## [br]
## @api public
## [br]
## @param tag: 日志标签。
## [br]
## @param message_builder: 延迟构造日志消息的回调。
## [br]
## @param context_builder: 延迟构造结构化上下文的回调。
func warn_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:
	_log_lazy(LogLevel.WARN, tag, message_builder, context_builder)


## 输出 ERROR 级别日志。
## [br]
## @api public
## [br]
## @param tag: 日志标签。
## [br]
## @param msg: 日志内容。
## [br]
## @param context: 结构化上下文字典。
## [br]
## @schema context: Dictionary[String, Variant] structured context merged into the log entry.
func error(tag: String, msg: String, context: Dictionary = {}) -> void:
	_log(LogLevel.ERROR, tag, msg, context)


## 延迟输出 ERROR 级别日志。只有日志未被过滤时才调用 message_builder。
## [br]
## @api public
## [br]
## @param tag: 日志标签。
## [br]
## @param message_builder: 延迟构造日志消息的回调。
## [br]
## @param context_builder: 延迟构造结构化上下文的回调。
func error_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:
	_log_lazy(LogLevel.ERROR, tag, message_builder, context_builder)


## 输出 FATAL 级别日志。
## [br]
## @api public
## [br]
## @param tag: 日志标签。
## [br]
## @param msg: 日志内容。
## [br]
## @param context: 结构化上下文字典。
## [br]
## @schema context: Dictionary[String, Variant] structured context merged into the log entry.
func fatal(tag: String, msg: String, context: Dictionary = {}) -> void:
	_log(LogLevel.FATAL, tag, msg, context)


## 延迟输出 FATAL 级别日志。只有日志未被过滤时才调用 message_builder。
## [br]
## @api public
## [br]
## @param tag: 日志标签。
## [br]
## @param message_builder: 延迟构造日志消息的回调。
## [br]
## @param context_builder: 延迟构造结构化上下文的回调。
func fatal_lazy(tag: String, message_builder: Callable, context_builder: Callable = Callable()) -> void:
	_log_lazy(LogLevel.FATAL, tag, message_builder, context_builder)


## 输出指定等级日志。
## [br]
## @api public
## [br]
## @param level: LogLevel 枚举值。
## [br]
## @param tag: 日志标签。
## [br]
## @param msg: 日志内容。
## [br]
## @param context: 结构化上下文字典。
## [br]
## @schema context: Dictionary[String, Variant] structured context merged into the log entry.
func log(level: int, tag: String, msg: String, context: Dictionary = {}) -> void:
	_log(level, tag, msg, context)


## 设置当前 trace id。
## [br]
## @api public
## [br]
## @param value: 新 trace id；为空时会重新生成。
func set_trace_id(value: String) -> void:
	trace_id = value if not value.is_empty() else _generate_trace_id()
	if _is_initialized and crash_marker_enabled:
		_write_crash_marker()


## 获取当前 trace id。
## [br]
## @api public
## [br]
## @return trace id 字符串。
func get_trace_id() -> String:
	if trace_id.is_empty():
		trace_id = _generate_trace_id()
	return trace_id


## 设置全局日志上下文字典。每条日志都会合并该字典，单条日志上下文优先级更高。
## [br]
## @api public
## [br]
## @param context: 全局上下文字典。
## [br]
## @schema context: Dictionary[String, Variant] sanitized global context merged into every log entry.
func set_global_context(context: Dictionary) -> void:
	_global_context = _sanitize_log_dictionary(context)


## 设置全局日志上下文提供者。每条日志输出时会调用一次，返回 Dictionary 时参与合并。
## [br]
## @api public
## [br]
## @param provider: 上下文提供者，签名为 `func() -> Dictionary`。
func set_global_context_provider(provider: Callable) -> void:
	_global_context_provider = provider


## 清空全局日志上下文和上下文提供者。
## [br]
## @api public
func clear_global_context() -> void:
	_global_context.clear()
	_global_context_provider = Callable()


## 获取全局日志上下文字典副本。
## [br]
## @api public
## [br]
## @return 全局上下文字典副本。
## [br]
## @schema return: Dictionary[String, Variant] sanitized global context.
func get_global_context() -> Dictionary:
	return _global_context.duplicate(true)


## 获取上次运行是否干净关闭。
## [br]
## @api public
## [br]
## @return 没有检测到运行中标记时返回 true。
func was_previous_shutdown_clean() -> bool:
	return _last_shutdown_was_clean


## 获取上次未干净关闭时留下的标记数据。
## [br]
## @api public
## [br]
## @return crash marker 副本。
## [br]
## @schema return: Dictionary crash marker with trace_id, started_at, and ticks_msec when available.
func get_previous_crash_marker() -> Dictionary:
	return _previous_crash_marker.duplicate(true)


## 动态设置是否忽略特定标签的日志。
## [br]
## @api public
## [br]
## @param tag: 要静音的标签。
## [br]
## @param muted: 是否静音。如果为 true，该 tag 的日志将不再打印及记录。
func set_tag_muted(tag: String, muted: bool) -> void:
	_muted_tags[tag] = muted


## 检查指定标签是否被静音。
## [br]
## @api public
## [br]
## @param tag: 日志标签。
## [br]
## @return 已静音时返回 true。
func is_tag_muted(tag: String) -> bool:
	return GFVariantData.get_option_bool(_muted_tags, tag)


## 注册日志 sink。
## [br]
## @api public
## [br]
## @param sink: 要注册的 sink 实例。
func add_sink(sink: GFLogSink) -> void:
	if sink == null or _sinks.has(sink):
		return

	_sinks.append(sink)
	if _is_initialized:
		sink.init(self)


## 注销日志 sink。
## [br]
## @api public
## [br]
## @param sink: 要注销的 sink 实例。
## [br]
## @param shutdown: 是否调用 sink.shutdown()。
func remove_sink(sink: GFLogSink, shutdown: bool = true) -> void:
	var index: int = _sinks.find(sink)
	if index < 0:
		return

	_sinks.remove_at(index)
	if shutdown and sink != null:
		sink.shutdown()


## 清空所有日志 sink。
## [br]
## @api public
## [br]
## @param shutdown: 是否调用每个 sink 的 shutdown()。
func clear_sinks(shutdown: bool = true) -> void:
	if shutdown:
		for sink: GFLogSink in _sinks:
			if sink != null:
				sink.shutdown()
	_sinks.clear()


## 获取已注册日志 sink。
## [br]
## @api public
## [br]
## @return sink 列表副本。
func get_sinks() -> Array[GFLogSink]:
	var result: Array[GFLogSink] = []
	for sink: GFLogSink in _sinks:
		result.append(sink)
	return result


## 刷新所有日志 sink。
## [br]
## @api public
func flush_sinks() -> void:
	for sink: GFLogSink in _sinks:
		if sink != null:
			sink.flush()


## 获取最近的内存日志条目。
## [br]
## @api public
## [br]
## @param count: 读取数量；小于 0 表示全部。
## [br]
## @return 从旧到新的日志条目数组。
## [br]
## @schema return: Array[Dictionary] of log entries from oldest to newest.
func get_recent_entries(count: int = -1) -> Array[Dictionary]:
	var size: int = _memory_entries.size()
	if count < 0 or count >= size:
		return get_entries(0, -1)
	return get_entries(size - count, count)


## 按偏移读取内存日志条目。
## [br]
## @api public
## [br]
## @param offset: 从最旧条目开始的偏移。
## [br]
## @param count: 读取数量；小于 0 表示直到末尾。
## [br]
## @return 从旧到新的日志条目数组。
## [br]
## @schema return: Array[Dictionary] of log entries from oldest to newest.
func get_entries(offset: int = 0, count: int = -1) -> Array[Dictionary]:
	var safe_offset: int = clampi(offset, 0, _memory_entries.size())
	var end: int = _memory_entries.size() if count < 0 else mini(safe_offset + count, _memory_entries.size())
	var result: Array[Dictionary] = []
	for logical_index: int in range(safe_offset, end):
		var physical_index: int = _memory_logical_to_physical(logical_index)
		if physical_index >= 0 and physical_index < _memory_entries.size():
			result.append(_memory_entries[physical_index].duplicate(true))
	return result


## 获取当前内存日志条目数量。
## [br]
## @api public
## [br]
## @return 条目数量。
func get_memory_entry_count() -> int:
	return _memory_entries.size()


## 获取因内存上限被丢弃的日志条目数量。
## [br]
## @api public
## [br]
## @return 丢弃数量。
func get_dropped_memory_entry_count() -> int:
	return _memory_dropped_count


## 获取当前日志文件路径。
## [br]
## @api public
## [br]
## @return 日志文件路径。
func get_log_file_path() -> String:
	return _log_file_path


## 清空内存日志缓存。
## [br]
## @api public
func clear_memory_entries() -> void:
	_memory_entries.clear()
	_memory_head = 0
	_memory_dropped_count = 0


## 清洗任意值，使它适合进入结构化日志和 JSON sink。
## [br]
## @api public
## [br]
## @param value: 要清洗的值。
## [br]
## @schema value: Variant log context value to sanitize.
## [br]
## @return 清洗后的值。
## [br]
## @schema return: Variant JSON-compatible value with object metadata, truncated strings, and circular references marked.
static func sanitize_log_value(value: Variant) -> Variant:
	return _sanitize_log_value(value, 0, [])


# --- 私有/辅助方法 ---

func _log(level: int, tag: String, msg: String, context: Dictionary = {}) -> void:
	if not _should_log(level, tag):
		return

	var level_str: String = _LEVEL_NAMES[level] if level < _LEVEL_NAMES.size() else "UNKNOWN"
	var datetime: Dictionary = Time.get_datetime_dict_from_system()
	var timestamp: String = "%04d-%02d-%02d %02d:%02d:%02d" % [
		datetime.year,
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute,
		datetime.second,
	]
	var entry: Dictionary = _make_entry(timestamp, level, level_str, tag, msg, context)
	var formatted: String = _get_log_entry_text(entry)
	_append_memory_entry(entry)

	if _file != null:
		_store_log_line(formatted)
		_flush_file_if_needed(level)

	match level:
		LogLevel.ERROR, LogLevel.FATAL:
			push_error(formatted)
		LogLevel.WARN:
			push_warning(formatted)
		_:
			print(formatted)

	_write_sinks(entry)
	log_emitted.emit(level, tag, msg)
	log_entry_emitted.emit(entry.duplicate(true))


func _log_lazy(
	level: int,
	tag: String,
	message_builder: Callable,
	context_builder: Callable = Callable()
) -> void:
	if not _should_log(level, tag):
		return
	if not message_builder.is_valid():
		push_error("[GFLogUtility] lazy 日志收到无效 message_builder。")
		return

	var context: Dictionary = {}
	if context_builder.is_valid():
		var context_variant: Variant = context_builder.call()
		if context_variant is Dictionary:
			context = GFVariantData.to_dictionary(context_variant)

	var message: String = _variant_to_log_string(message_builder.call())
	_log(level, tag, message, context)


func _should_log(level: int, tag: String) -> bool:
	if level < LogLevel.DEBUG:
		return false
	if level < min_level:
		return false
	if GFVariantData.get_option_bool(_muted_tags, tag):
		return false
	return true


func _cleanup_old_logs() -> void:
	var dir: DirAccess = DirAccess.open(_LOG_DIR)
	if dir == null:
		return

	var files: PackedStringArray = PackedStringArray()
	var list_result: Error = dir.list_dir_begin()
	if list_result != OK:
		return
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("gf_log_") and file_name.ends_with(".log"):
			var _append_result: bool = files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if files.size() <= max_log_files:
		return

	files.sort()
	var to_remove: int = files.size() - max_log_files
	for i: int in range(to_remove):
		var path: String = _LOG_DIR + files[i]
		_remove_absolute(path)


func _flush_file_if_needed(level: int) -> void:
	if _file == null:
		return

	var now: int = Time.get_ticks_msec()
	if (
		flush_immediately
		or flush_interval_msec <= 0
		or level >= LogLevel.ERROR
		or now - _last_file_flush_msec >= flush_interval_msec
	):
		_file.flush()
		_last_file_flush_msec = now


func _make_entry(
	timestamp: String,
	level: int,
	level_name: String,
	tag: String,
	message: String,
	context: Dictionary
) -> Dictionary:
	var safe_context: Dictionary = _merge_log_context(context)
	var text: String = "[%s][%s][%s] %s" % [timestamp, level_name, tag, message]
	if not safe_context.is_empty():
		text += " " + JSON.stringify(safe_context)

	return {
		"timestamp": timestamp,
		"unix_time": Time.get_unix_time_from_system(),
		"ticks_msec": Time.get_ticks_msec(),
		"trace_id": get_trace_id(),
		"level": level,
		"level_name": level_name,
		"tag": tag,
		"message": message,
		"context": safe_context,
		"text": text,
	}


func _write_sinks(entry: Dictionary) -> void:
	for sink: GFLogSink in _sinks:
		if sink != null:
			sink.write(entry.duplicate(true))


func _append_memory_entry(entry: Dictionary) -> void:
	if _max_memory_entries <= 0:
		_memory_dropped_count += 1
		return

	if _memory_entries.size() < _max_memory_entries:
		_memory_entries.append(entry.duplicate(true))
		_memory_head = _memory_entries.size() % _max_memory_entries
		return

	_memory_entries[_memory_head] = entry.duplicate(true)
	_memory_head = (_memory_head + 1) % _max_memory_entries
	_memory_dropped_count += 1


func _trim_memory_entries() -> void:
	if _max_memory_entries <= 0:
		_memory_dropped_count += _memory_entries.size()
		_memory_entries.clear()
		_memory_head = 0
		return

	if _memory_entries.size() <= _max_memory_entries:
		return

	var retained_count: int = _max_memory_entries
	var dropped_count: int = _memory_entries.size() - retained_count
	var retained: Array[Dictionary] = []
	for entry: Dictionary in get_recent_entries(retained_count):
		retained.append(entry)

	_memory_entries = retained
	_memory_head = _memory_entries.size() % _max_memory_entries
	_memory_dropped_count += dropped_count


func _memory_logical_to_physical(logical_index: int) -> int:
	if _memory_entries.is_empty():
		return -1
	if _max_memory_entries <= 0 or _memory_entries.size() < _max_memory_entries:
		return logical_index
	return (_memory_head + logical_index) % _memory_entries.size()


func _merge_log_context(context: Dictionary) -> Dictionary:
	var merged: Dictionary = _global_context.duplicate(true)
	if _global_context_provider.is_valid():
		var provided: Variant = _global_context_provider.call()
		if provided is Dictionary:
			var provided_context: Dictionary = GFVariantData.as_dictionary(provided)
			for key: Variant in provided_context.keys():
				merged[key] = provided_context[key]

	for key: Variant in context.keys():
		merged[key] = context[key]
	if not merged.has("trace_id"):
		merged["trace_id"] = get_trace_id()
	return _sanitize_log_dictionary(merged)


static func _sanitize_log_value(value: Variant, depth: int = 0, visited: Array = []) -> Variant:
	if depth >= _MAX_SANITIZE_DEPTH:
		return "<max_depth>"

	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return value
		TYPE_FLOAT:
			var float_value: float = value
			return _sanitize_log_float(float_value)
		TYPE_STRING:
			return _truncate_log_string(_variant_to_log_string(value))
		TYPE_STRING_NAME, TYPE_NODE_PATH:
			return _truncate_log_string(_variant_to_log_string(value))
		TYPE_DICTIONARY:
			if _visited_contains_reference(visited, value):
				return "<circular_reference>"
			visited.append(value)
			var result: Dictionary = {}
			var source: Dictionary = GFVariantData.as_dictionary(value)
			for key: Variant in source.keys():
				result[_variant_to_log_string(key)] = _sanitize_log_value(source[key], depth + 1, visited)
			visited.pop_back()
			return result
		TYPE_ARRAY:
			if _visited_contains_reference(visited, value):
				return "<circular_reference>"
			visited.append(value)
			var result: Array = []
			for item: Variant in GFVariantData.as_array(value):
				result.append(_sanitize_log_value(item, depth + 1, visited))
			visited.pop_back()
			return result
		TYPE_PACKED_BYTE_ARRAY:
			return {
				"type": "PackedByteArray",
				"size": _get_packed_array_size(value),
			}
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return {
				"type": type_string(typeof(value)),
				"size": _get_packed_array_size(value),
			}
		TYPE_PACKED_STRING_ARRAY:
			var strings: Array = []
			for item: String in _variant_to_packed_string_array(value):
				strings.append(_sanitize_log_value(item, depth + 1, visited))
			return strings
		TYPE_OBJECT:
			var object: Object = _variant_to_object(value)
			if object == null:
				return null
			var payload: Dictionary = {
				"type": object.get_class(),
				"id": object.get_instance_id(),
			}
			if object is Node:
				var node: Node = object
				payload["name"] = node.name
				payload["path"] = _variant_to_log_string(node.get_path()) if node.is_inside_tree() else ""
			return payload
		_:
			return _truncate_log_string(_variant_to_log_string(value))


func _store_log_line(line: String) -> void:
	if _file == null:
		return

	var stored: bool = _file.store_line(line)
	if not stored:
		push_warning("[GFLogUtility] 无法写入日志文件：%s" % _log_file_path)


func _get_log_entry_text(entry: Dictionary) -> String:
	if not entry.has("text"):
		return ""
	return _variant_to_log_string(entry["text"])


static func _remove_absolute(path: String, warn_on_failure: bool = false) -> void:
	var remove_path: String = path.strip_edges()
	if remove_path.is_empty():
		return
	if remove_path.begins_with("user://") or remove_path.begins_with("res://"):
		remove_path = ProjectSettings.globalize_path(remove_path)
	if not FileAccess.file_exists(remove_path) and not DirAccess.dir_exists_absolute(remove_path):
		return

	var remove_result: Error = DirAccess.remove_absolute(remove_path)
	if remove_result != OK and warn_on_failure:
		push_warning("[GFLogUtility] 无法移除文件：%s，错误码：%s" % [remove_path, remove_result])


static func _sanitize_log_dictionary(source: Dictionary) -> Dictionary:
	var sanitized: Variant = _sanitize_log_value(source, 0, [])
	return GFVariantData.as_dictionary(sanitized)


static func _sanitize_dictionary_variant(value: Variant) -> Dictionary:
	return _sanitize_log_dictionary(GFVariantData.as_dictionary(value))


static func _variant_to_packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var array: PackedStringArray = value
		return array
	return PackedStringArray()


static func _variant_to_object(value: Variant) -> Object:
	if value is Object:
		var object: Object = value
		return object
	return null


static func _get_packed_array_size(value: Variant) -> int:
	if value is PackedByteArray:
		var byte_array: PackedByteArray = value
		return byte_array.size()
	if value is PackedInt32Array:
		var int32_array: PackedInt32Array = value
		return int32_array.size()
	if value is PackedInt64Array:
		var int64_array: PackedInt64Array = value
		return int64_array.size()
	if value is PackedFloat32Array:
		var float32_array: PackedFloat32Array = value
		return float32_array.size()
	if value is PackedFloat64Array:
		var float64_array: PackedFloat64Array = value
		return float64_array.size()
	return 0


static func _variant_to_log_string(value: Variant) -> String:
	if value is String:
		return value
	if value is StringName:
		var name_value: StringName = value
		return String(name_value)
	if value is NodePath:
		var path_value: NodePath = value
		return String(path_value)
	return str(value)


static func _sanitize_log_float(value: float) -> Variant:
	if is_nan(value):
		return "NaN"
	if is_inf(value):
		return "Infinity" if value > 0.0 else "-Infinity"
	return value


static func _visited_contains_reference(visited: Array, value: Variant) -> bool:
	for item: Variant in visited:
		if is_same(item, value):
			return true
	return false


static func _truncate_log_string(value: String) -> String:
	if value.length() <= _MAX_SANITIZE_STRING_LENGTH:
		return value
	return value.substr(0, _MAX_SANITIZE_STRING_LENGTH) + "...<truncated>"


func _check_previous_crash_marker() -> void:
	_previous_crash_marker.clear()
	if not crash_marker_enabled:
		_last_shutdown_was_clean = true
		return
	if not FileAccess.file_exists(_CRASH_MARKER_PATH):
		_last_shutdown_was_clean = true
		return

	_last_shutdown_was_clean = false
	var content: String = FileAccess.get_file_as_string(_CRASH_MARKER_PATH)
	var parsed: Variant = JSON.parse_string(content)
	if parsed is Dictionary:
		_previous_crash_marker = _sanitize_dictionary_variant(parsed)


func _write_crash_marker() -> void:
	if not crash_marker_enabled:
		return

	var file: FileAccess = FileAccess.open(_CRASH_MARKER_PATH, FileAccess.WRITE)
	if file == null:
		return
	var stored: bool = file.store_string(JSON.stringify({
		"trace_id": get_trace_id(),
		"started_at": Time.get_datetime_string_from_system(true, true),
		"ticks_msec": Time.get_ticks_msec(),
	}))
	if not stored:
		push_warning("[GFLogUtility] 无法写入运行中标记：%s" % _CRASH_MARKER_PATH)
	file.close()


func _mark_shutdown_clean() -> void:
	if FileAccess.file_exists(_CRASH_MARKER_PATH):
		_remove_absolute(_CRASH_MARKER_PATH)


func _generate_trace_id() -> String:
	var source: String = "%s:%s:%s" % [
		Time.get_unix_time_from_system(),
		Time.get_ticks_usec(),
		randi(),
	]
	return source.sha256_text().substr(0, 16)
