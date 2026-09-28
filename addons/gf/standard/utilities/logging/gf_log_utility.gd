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

## 本地日志文件和运行中标记所在的目录。
## [br]
## @api private
## [br]
const _LOG_DIR: String = "user://logs/"

## 用于判断上次运行是否干净关闭的标记文件路径。
## [br]
## @api private
## [br]
const _CRASH_MARKER_PATH: String = _LOG_DIR + "gf_log_running.marker"

## 日志内容脱敏时允许的最大递归深度。
## [br]
## @api private
## [br]
const _MAX_SANITIZE_DEPTH: int = 8

## 日志内容脱敏时允许的最大字符串长度。
## [br]
## @api private
## [br]
const _MAX_SANITIZE_STRING_LENGTH: int = 2048

## 日志内容脱敏时单个集合允许的最大项数及 packed 长度。
## [br]
## @api private
## [br]
const _MAX_SANITIZE_COLLECTION_ITEMS: int = 256

## 日志内容脱敏时允许累计的最大节点数。
## [br]
## @api private
## [br]
const _MAX_SANITIZE_TOTAL_NODES: int = 4096


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
		if maxi(value, 0) > _max_memory_entries:
			_linearize_memory_entries()
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

## 所有实例当前打开日志文件的弱引用，供清理流程排除活动文件。
## [br]
## @api private
## [br]
static var _active_files: Array[WeakRef] = []

## max_log_files 公共属性的存储值，setter 至少保留一个文件。
## [br]
## @api private
## [br]
var _max_log_files: int = 10

## max_memory_entries 公共属性的当前容量。
## [br]
## @api private
## [br]
var _max_memory_entries: int = 500

## LogLevel 数值到显示名称的顺序表。
## [br]
## @api private
## [br]
static var _LEVEL_NAMES: PackedStringArray = PackedStringArray([
	"DEBUG",
	"INFO",
	"WARN",
	"ERROR",
	"FATAL",
])

## 当前本地日志文件句柄。
## [br]
## @api private
## [br]
var _file: FileAccess

## 本次初始化创建的本地日志文件路径。
## [br]
## @api private
## [br]
var _log_file_path: String

## 以日志标签为键记录的静音状态。
## [br]
## @api private
## [br]
var _muted_tags: Dictionary = {}

## 最近一次文件 flush 的单调毫秒 tick。
## [br]
## @api private
## [br]
var _last_file_flush_msec: int = 0

## 由 tick 累加的文件 flush 毫秒数。
## [br]
## @api private
## [br]
var _file_flush_elapsed_msec: float = 0.0

## 日志文件是否有尚未 flush 的写入。
## [br]
## @api private
## [br]
var _file_has_unflushed_data: bool = false

## 按环形布局保存的近期日志条目副本。
## [br]
## @api private
## [br]
var _memory_entries: Array[Dictionary] = []

## 下一条覆盖写入位置，也是环形缓存的逻辑起点。
## [br]
## @api private
## [br]
var _memory_head: int = 0

## 因内存容量限制被丢弃的日志累计数。
## [br]
## @api private
## [br]
var _memory_dropped_count: int = 0

## 已进入内存日志序列的条目累计数，不因清空缓存而重置。
## [br]
## @api private
## [br]
var _memory_appended_total: int = 0

## 按注册顺序写入日志的 sink 列表。
## [br]
## @api private
## [br]
var _sinks: Array[GFLogSink] = []

## 日志文件、标记和 sink 初始化是否已完成。
## [br]
## @api private
## [br]
var _is_initialized: bool = false

## 每条日志默认合并的全局上下文。
## [br]
## @api private
## [br]
var _global_context: Dictionary = {}

## 每条日志调用一次以提供动态全局上下文的回调。
## [br]
## @api private
## [br]
var _global_context_provider: Callable = Callable()

## 上次初始化时是否未发现运行中标记。
## [br]
## @api private
## [br]
var _last_shutdown_was_clean: bool = true

## 从上次运行标记读取并脱敏的诊断数据。
## [br]
## @api private
## [br]
var _previous_crash_marker: Dictionary = {}

## 防止 sink 写日志时递归进入 sink 分发循环。
## [br]
## @api private
## [br]
var _is_dispatching_sinks: bool = false


# --- GF 生命周期方法 ---

## 第一阶段初始化：创建日志目录、打开日志文件、清理旧文件。
## [br]
## @api public
func init() -> void:
	if _is_initialized:
		return
	ignore_pause = true
	clear_memory_entries()
	if not DirAccess.dir_exists_absolute(_LOG_DIR):
		var make_log_dir_result: Error = DirAccess.make_dir_recursive_absolute(_LOG_DIR)
		if make_log_dir_result != OK:
			push_warning("[GFLogUtility][log_utility.log_directory_failed] Cannot create the log directory: %s, error code: %s." % [_LOG_DIR, make_log_dir_result])

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
		push_error("[GFLogUtility][log_utility.log_file_creation_failed] Cannot create the log file: %s, error code: %s." % [_log_file_path, FileAccess.get_open_error()])
	else:
		_active_files.append(weakref(_file))
		_last_file_flush_msec = Time.get_ticks_msec()
		_file_flush_elapsed_msec = 0.0
		_file_has_unflushed_data = false

	_cleanup_old_logs()
	_is_initialized = true
	if not _last_shutdown_was_clean:
		previous_crash_detected.emit(_previous_crash_marker.duplicate(true))
	for sink: GFLogSink in _get_sink_snapshot():
		if sink != null:
			sink.init(self)


## 销毁时关闭文件句柄。
## [br]
## @api public
func dispose() -> void:
	if not _is_initialized:
		return
	flush_sinks()
	for sink: GFLogSink in _get_sink_snapshot():
		if sink != null:
			sink.shutdown()

	if _file != null:
		_flush_file()
		for index: int in range(_active_files.size() - 1, -1, -1):
			var active_file: Variant = _active_files[index].get_ref()
			if active_file == null or active_file == _file:
				_active_files.remove_at(index)
		_file.close()
		_file = null

	_is_initialized = false
	_mark_shutdown_clean()


## 推进日志文件和已注册 sink 的空闲时间行为。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param delta: 本帧时间增量（秒）；非有限或非正数不会推进状态。
func tick(delta: float) -> void:
	if not _is_initialized or not is_finite(delta) or delta <= 0.0:
		return
	_file_flush_elapsed_msec += delta * 1000.0
	if (
		_file_has_unflushed_data
		and not flush_immediately
		and flush_interval_msec > 0
		and _file_flush_elapsed_msec >= float(flush_interval_msec)
	):
		_flush_file()
	for sink: GFLogSink in _get_sink_snapshot():
		if sink != null:
			sink.tick(delta)


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
	var next_trace_id: String = value if not value.is_empty() else _generate_trace_id()
	trace_id = _sanitize_log_text(next_trace_id, GFReportValueCodec.REDACTION_PROFILE_DEBUG)
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
	trace_id = _sanitize_log_text(trace_id, GFReportValueCodec.REDACTION_PROFILE_DEBUG)
	return trace_id


## 设置全局日志上下文字典。每条日志都会合并该字典，单条日志上下文优先级更高。
## [br]
## @api public
## [br]
## @param context: 全局上下文字典。
## [br]
## @schema context: Dictionary[String, Variant] sanitized global context merged into every log entry.
func set_global_context(context: Dictionary) -> void:
	_global_context = context.duplicate(false)


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
	return _sanitize_log_dictionary(_global_context)


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
	var sinks_to_shutdown: Array[GFLogSink] = _get_sink_snapshot()
	_sinks.clear()
	if shutdown:
		for sink: GFLogSink in sinks_to_shutdown:
			if sink != null:
				sink.shutdown()


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
	for sink: GFLogSink in _get_sink_snapshot():
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


## 获取内存日志的下一个序列游标。
## 该值随每条通过过滤的日志递增，可作为 get_entries_since() 的 since_sequence。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 下一条日志将使用的序列号。
func get_memory_sequence() -> int:
	return _memory_appended_total


## 按序列游标读取新增内存日志。
## 适合诊断 UI、远端采集器或支持报告面板轮询日志缓存，而不需要每次重新读取全部最近日志。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param since_sequence: 调用方上次保存的 next_sequence；表示下一条想读取的日志序列。
## [br]
## @param limit: 最多返回的条目数量；小于 0 表示读取所有可用条目。
## [br]
## @return 增量读取报告。
## [br]
## @schema return: Dictionary with requested_sequence, oldest_sequence, next_sequence, current_sequence, entries, truncated, has_more, missed_count, and dropped_count fields.
func get_entries_since(since_sequence: int, limit: int = -1) -> Dictionary:
	var retained_count: int = _memory_entries.size()
	var oldest_sequence: int = _memory_appended_total - retained_count
	var requested_sequence: int = maxi(since_sequence, 0)
	var start_sequence: int = clampi(requested_sequence, oldest_sequence, _memory_appended_total)
	var start_offset: int = start_sequence - oldest_sequence
	var available_count: int = maxi(retained_count - start_offset, 0)
	var read_count: int = available_count
	if limit >= 0:
		read_count = mini(available_count, limit)

	var entries: Array[Dictionary] = get_entries(start_offset, read_count)
	var next_sequence: int = start_sequence + entries.size()
	var has_more: bool = next_sequence < _memory_appended_total
	if limit == 0:
		has_more = false
	return {
		"requested_sequence": since_sequence,
		"oldest_sequence": oldest_sequence,
		"next_sequence": next_sequence,
		"current_sequence": _memory_appended_total,
		"entries": entries,
		"truncated": requested_sequence < oldest_sequence,
		"has_more": has_more,
		"missed_count": maxi(oldest_sequence - requested_sequence, 0),
		"dropped_count": _memory_dropped_count,
	}


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
## 已分配的序列游标不会重置；调用方仍可用 get_memory_sequence() 继续进行增量读取。
## [br]
## @api public
## [br]
## @since 3.17.0
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
	return GFReportValueCodec.to_json_compatible(
		value,
		_make_log_report_options(GFReportValueCodec.REDACTION_PROFILE_DEBUG)
	)


# --- 私有/辅助方法 ---

## 过滤后合并上下文、构造脱敏条目，写入缓存与文件，再分发给 sink 和信号。
## [br]
## @api private
## [br]
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
	var merged_context: Dictionary = _merge_log_context(context)
	var entry: Dictionary = _make_entry(
		timestamp,
		level,
		level_str,
		tag,
		msg,
		merged_context,
		GFReportValueCodec.REDACTION_PROFILE_DEBUG
	)
	var entry_tag: String = GFVariantData.get_option_string(entry, "tag")
	var entry_message: String = GFVariantData.get_option_string(entry, "message")
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

	_write_sinks(entry, merged_context)
	log_emitted.emit(level, entry_tag, entry_message)
	log_entry_emitted.emit(entry.duplicate(true))


## 过滤通过后才调用消息与上下文构造器，并将结果交给普通日志流程。
## [br]
## @api private
## [br]
func _log_lazy(
	level: int,
	tag: String,
	message_builder: Callable,
	context_builder: Callable = Callable()
) -> void:
	if not _should_log(level, tag):
		return
	if not message_builder.is_valid():
		push_error("[GFLogUtility][log_utility.message_builder_invalid] Lazy logging received an invalid message_builder.")
		return

	var context: Dictionary = {}
	if context_builder.is_valid():
		var context_variant: Variant = context_builder.call()
		if context_variant is Dictionary:
			context = GFVariantData.to_dictionary(context_variant)

	var message: String = _variant_to_log_string(message_builder.call())
	_log(level, tag, message, context)


## 拒绝低于 DEBUG、低于 min_level 或标签已静音的日志。
## [br]
## @api private
## [br]
func _should_log(level: int, tag: String) -> bool:
	if level < LogLevel.DEBUG:
		return false
	if level < min_level:
		return false
	if GFVariantData.get_option_bool(_muted_tags, tag):
		return false
	return true


## 按文件名排序清理超出上限的 gf_log_*.log，并跳过仍打开的活动文件。
## [br]
## @api private
## [br]
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
	var active_paths: Dictionary = {}
	for index: int in range(_active_files.size() - 1, -1, -1):
		var active_value: Variant = _active_files[index].get_ref()
		if active_value is FileAccess:
			var active_file: FileAccess = active_value
			if active_file.is_open():
				active_paths[active_file.get_path_absolute()] = true
				continue
		_active_files.remove_at(index)
	for candidate: String in files:
		if to_remove <= 0:
			break
		var candidate_path: String = _LOG_DIR + candidate
		if active_paths.has(ProjectSettings.globalize_path(candidate_path)):
			continue
		_remove_absolute(candidate_path)
		to_remove -= 1


## 立即刷新、间隔关闭、ERROR/FATAL 或刷新间隔到期时刷新日志文件。
## [br]
## @api private
## [br]
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
		_flush_file(now)


## 刷新当前文件，并更新最近刷新 tick、清零时间累计和未刷新标记。
## [br]
## @api private
## [br]
func _flush_file(now_msec: int = -1) -> void:
	if _file == null:
		return
	_file.flush()
	_last_file_flush_msec = Time.get_ticks_msec() if now_msec < 0 else now_msec
	_file_flush_elapsed_msec = 0.0
	_file_has_unflushed_data = false


## 按指定脱敏 profile 清洗标签、消息和上下文，并构造带时间及 trace 信息的条目。
## [br]
## @api private
## [br]
func _make_entry(
	timestamp: String,
	level: int,
	level_name: String,
	tag: String,
	message: String,
	context: Dictionary,
	redaction_profile: String
) -> Dictionary:
	var safe_tag: String = _sanitize_log_text(tag, redaction_profile)
	var safe_message: String = _sanitize_log_text(message, redaction_profile)
	var safe_context: Dictionary = _sanitize_log_dictionary(context, redaction_profile)
	var text: String = _format_log_entry_text(
		timestamp,
		level_name,
		safe_tag,
		safe_message,
		safe_context
	)

	return {
		"timestamp": timestamp,
		"unix_time": Time.get_unix_time_from_system(),
		"ticks_msec": Time.get_ticks_msec(),
		"trace_id": get_trace_id(),
		"level": level,
		"level_name": level_name,
		"tag": safe_tag,
		"message": safe_message,
		"context": safe_context,
		"text": text,
	}


## 重入时跳过嵌套 sink 分发；否则对快照中的每个 sink 按其 profile 构造条目。
## [br]
## @api private
## [br]
func _write_sinks(entry: Dictionary, raw_context: Dictionary) -> void:
	if _is_dispatching_sinks:
		return
	_is_dispatching_sinks = true
	for sink: GFLogSink in _get_sink_snapshot():
		if sink != null:
			var sink_entry: Dictionary = _make_entry_for_profile(
				entry,
				raw_context,
				sink.get_report_redaction_profile()
			)
			sink.write(sink_entry)
	_is_dispatching_sinks = false


## 为 debug sink 返回条目深副本；其他 profile 重清洗敏感字段并重建 text。
## [br]
## @api private
## [br]
func _make_entry_for_profile(
	entry: Dictionary,
	raw_context: Dictionary,
	redaction_profile: String
) -> Dictionary:
	if redaction_profile == GFReportValueCodec.REDACTION_PROFILE_DEBUG:
		return entry.duplicate(true)
	var result: Dictionary = entry.duplicate(false)
	var safe_trace_id: String = _sanitize_log_text(
		GFVariantData.get_option_string(entry, "trace_id"),
		redaction_profile
	)
	var safe_context: Dictionary = _sanitize_log_dictionary(raw_context, redaction_profile)
	var safe_tag: String = _sanitize_log_text(
		GFVariantData.get_option_string(entry, "tag"),
		redaction_profile
	)
	var safe_message: String = _sanitize_log_text(
		GFVariantData.get_option_string(entry, "message"),
		redaction_profile
	)
	result["trace_id"] = safe_trace_id
	result["tag"] = safe_tag
	result["message"] = safe_message
	result["context"] = safe_context
	result["text"] = _format_log_entry_text(
		GFVariantData.get_option_string(entry, "timestamp"),
		GFVariantData.get_option_string(entry, "level_name"),
		safe_tag,
		safe_message,
		safe_context
	)
	return result


## 按时间、级别、标签和消息格式化文本，非空 context 作为 JSON 后缀追加。
## [br]
## @api private
## [br]
func _format_log_entry_text(
	timestamp: String,
	level_name: String,
	tag: String,
	message: String,
	context: Dictionary
) -> String:
	var text: String = "[%s][%s][%s] %s" % [timestamp, level_name, tag, message]
	if not context.is_empty():
		text += " " + JSON.stringify(context)
	return text


## 按注册顺序返回当前非空 sink 列表快照。
## [br]
## @api private
## [br]
func _get_sink_snapshot() -> Array[GFLogSink]:
	var snapshot: Array[GFLogSink] = []
	for sink: GFLogSink in _sinks:
		if sink != null:
			snapshot.append(sink)
	return snapshot


## 增加序列计数并存入条目深副本；容量满时覆盖 head 指向的旧条目。
## 容量为 0 时不保存条目并增加 dropped_count。
## [br]
## @api private
## [br]
func _append_memory_entry(entry: Dictionary) -> void:
	_memory_appended_total += 1
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


## 按新容量裁剪缓存；容量为 0 时清空并将现有条目计入丢弃数。
## 超限时仅保留最近条目并更新环形 head 与丢弃计数。
## [br]
## @api private
## [br]
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


## 将环形缓存按旧到新顺序重排，并重置下一次覆盖位置。
## [br]
## @api private
## [br]
func _linearize_memory_entries() -> void:
	if _memory_entries.is_empty():
		return
	var retained: Array[Dictionary] = get_recent_entries(-1)
	_memory_entries = retained
	_memory_head = 0 if _max_memory_entries <= 0 else _memory_entries.size() % _max_memory_entries


## 将旧到新的逻辑索引映射到环形数组位置；缓存为空时返回 -1。
## [br]
## @api private
## [br]
func _memory_logical_to_physical(logical_index: int) -> int:
	if _memory_entries.is_empty():
		return -1
	if _max_memory_entries <= 0 or _memory_entries.size() < _max_memory_entries:
		return logical_index
	return (_memory_head + logical_index) % _memory_entries.size()


## 依次合并全局副本、动态 provider 字典和单条上下文，并补入缺失 trace_id。
## 后合并的字段覆盖先前同名字段。
## [br]
## @api private
## [br]
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
	return merged


## 向已打开日志文件写一行；写入成功后标记文件存在未刷新数据。
## [br]
## @api private
## [br]
func _store_log_line(line: String) -> void:
	if _file == null:
		return

	var stored: bool = _file.store_line(line)
	if not stored:
		push_warning("[GFLogUtility][log_utility.log_file_write_failed] Cannot write the log file: %s." % _log_file_path)
		return
	_file_has_unflushed_data = true


## 读取条目的 text 字段并转为日志字符串；字段缺失时返回空串。
## [br]
## @api private
## [br]
func _get_log_entry_text(entry: Dictionary) -> String:
	if not entry.has("text"):
		return ""
	return _variant_to_log_string(entry["text"])


## 删除绝对或 Godot 虚拟路径对应的文件/目录；不存在时不操作，可选发出失败警告。
## [br]
## @api private
## [br]
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
		push_warning("[GFLogUtility][log_utility.file_remove_failed] Cannot remove file: %s, error code: %s." % [remove_path, remove_result])


## 使用指定报告脱敏 profile 和固定预算清洗字典。
## [br]
## @api private
## [br]
static func _sanitize_log_dictionary(
	source: Dictionary,
	redaction_profile: String = GFReportValueCodec.REDACTION_PROFILE_DEBUG
) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(
		source,
		_make_log_report_options(redaction_profile)
	)


## 以指定 profile 编码文本；编码结果不是 String 时序列化为 JSON 文本。
## [br]
## @api private
## [br]
static func _sanitize_log_text(value: String, redaction_profile: String) -> String:
	var encoded: Variant = GFReportValueCodec.to_json_compatible(
		value,
		_make_log_report_options(redaction_profile)
	)
	if encoded is String:
		var encoded_text: String = encoded
		return encoded_text
	return JSON.stringify(encoded)


## 创建带固定深度、长度、集合、节点及字节预算的报告脱敏选项。
## [br]
## @api private
## [br]
static func _make_log_report_options(redaction_profile: String) -> Dictionary:
	return GFReportValueCodec.make_redaction_options(
		redaction_profile,
		{
			"max_depth": _MAX_SANITIZE_DEPTH,
			"max_string_length": _MAX_SANITIZE_STRING_LENGTH,
			"max_collection_items": _MAX_SANITIZE_COLLECTION_ITEMS,
			"max_packed_length": _MAX_SANITIZE_COLLECTION_ITEMS,
			"max_total_nodes": _MAX_SANITIZE_TOTAL_NODES,
			"max_total_bytes": _MAX_SANITIZE_STRING_LENGTH * 8,
			"encode_dictionary_keys": false,
		}
	)


## 将 Variant 收窄为 Dictionary 后按默认 debug profile 清洗。
## [br]
## @api private
## [br]
static func _sanitize_dictionary_variant(value: Variant) -> Dictionary:
	return _sanitize_log_dictionary(GFVariantData.as_dictionary(value))


## 将 String、StringName 和 NodePath 保留为自然文本，其他值使用 str()。
## [br]
## @api private
## [br]
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


## 检查运行中标记；禁用或文件缺失时按干净关闭处理，否则解析并清洗字典内容。
## [br]
## @api private
## [br]
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


## 启用标记时写入 trace_id、系统启动时间和单调 tick 的 JSON 文件。
## [br]
## @api private
## [br]
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
		push_warning("[GFLogUtility][log_utility.running_marker_write_failed] Cannot write the running marker: %s." % _CRASH_MARKER_PATH)
	file.close()


## 若运行中标记文件存在则尝试删除，以记录本次正常关闭。
## [br]
## @api private
## [br]
func _mark_shutdown_clean() -> void:
	if FileAccess.file_exists(_CRASH_MARKER_PATH):
		_remove_absolute(_CRASH_MARKER_PATH)


## 哈希 Unix 时间、单调微秒和随机整数，取前 16 个字符作为 trace id。
## [br]
## @api private
## [br]
func _generate_trace_id() -> String:
	var source: String = "%s:%s:%s" % [
		Time.get_unix_time_from_system(),
		Time.get_ticks_usec(),
		randi(),
	]
	return source.sha256_text().substr(0, 16)
