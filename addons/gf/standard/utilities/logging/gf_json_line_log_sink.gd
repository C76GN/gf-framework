## GFJsonLineLogSink: 把结构化日志条目写入 JSON Lines 文件。
##
## 该 sink 只负责把 GFLogUtility 传入的条目序列化为一行一个 JSON 对象，
## 不规定采集服务、上传时机或业务字段 schema。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFJsonLineLogSink
extends GFLogSink


# --- 枚举 ---

## JSONL 文件打开策略。
## [br]
## @api public
## [br]
## @since 8.0.0
enum FileOpenMode {
	## 每次 init() 截断已有文件。
	TRUNCATE,
	## 每次 init() 追加到已有文件末尾。
	APPEND,
	## 目标文件已存在时拒绝打开。
	FAIL_IF_EXISTS,
}


# --- 导出变量 ---

## 输出文件路径。留空时会根据 GFLogUtility 当前日志文件和 sink 实例派生独占 `.jsonl` 文件。
## [br]
## @api public
## [br]
## @since 11.0.0
@export var file_path: String = ""

## 是否在写入前移除 `text` 字段，减少重复存储。
## [br]
## @api public
@export var omit_formatted_text: bool = false

## 文件自动 flush 间隔。设为 0 时每条日志都会立即 flush。
## [br]
## @api public
@export var flush_interval_msec: int = 250

## 是否强制每条 JSONL 日志立即 flush。
## [br]
## @api public
@export var flush_immediately: bool = false

## 使用默认派生路径时最多保留的 JSONL 文件数量。
## [br]
## @api public
@export var max_jsonl_files: int = 10:
	set(value):
		max_jsonl_files = maxi(value, 1)

## 自定义 file_path 重复初始化时的打开策略。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var file_open_mode: FileOpenMode = FileOpenMode.TRUNCATE


# --- 私有变量 ---

## 所有实例当前打开文件的弱引用，用于清理时跳过仍在使用的文件。
## [br]
## @api private
## [br]
static var _active_files: Array[WeakRef] = []

## 当前 JSONL 文件句柄；未成功打开或已关闭时为空引用。
## [br]
## @api private
## [br]
var _file: FileAccess

## 初始化解析出的实际输出路径。
## [br]
## @api private
## [br]
var _effective_file_path: String = ""

## 最近一次 flush 的单调毫秒 tick。
## [br]
## @api private
## [br]
var _last_flush_msec: int = 0

## 由 tick 累加的自动 flush 毫秒数。
## [br]
## @api private
## [br]
var _elapsed_since_flush_msec: float = 0.0

## 文件中是否有尚未 flush 的写入。
## [br]
## @api private
## [br]
var _has_unflushed_data: bool = false

## 当前实际路径是否由空 file_path 派生。
## [br]
## @api private
## [br]
var _uses_default_file_path: bool = false

## 最近一次记录的文件或目录操作错误码。
## [br]
## @api private
## [br]
var _last_error: Error = OK

## 最近一次文件或目录操作错误的格式化消息。
## [br]
## @api private
## [br]
var _last_error_message: String = ""

## JSONL 写入失败累计数。
## [br]
## @api private
## [br]
var _write_error_count: int = 0

## 旧 JSONL 文件清理失败累计数。
## [br]
## @api private
## [br]
var _cleanup_error_count: int = 0

## 当前实例是否已成功初始化并打开文件。
## [br]
## @api private
## [br]
var _is_initialized: bool = false


# --- 公共方法 ---

## 使用本地 JSONL 诊断所需的 debug 脱敏 profile。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return debug profile 名称。
## [br]
## @schema return: String naming GFReportValueCodec.REDACTION_PROFILE_DEBUG.
func get_report_redaction_profile() -> String:
	return GFReportValueCodec.REDACTION_PROFILE_DEBUG


## 初始化 sink 并打开 JSONL 文件。
## [br]
## @api public
## [br]
## @param owner: 持有该 sink 的日志工具。
func init(owner: Object) -> void:
	if _is_initialized and _file != null:
		return
	_last_error = OK
	_last_error_message = ""
	_effective_file_path = _resolve_file_path(owner)
	if _effective_file_path.is_empty():
		return
	var directory_error: Error = _ensure_parent_dir(_effective_file_path)
	if directory_error != OK:
		return
	_file = _open_jsonl_file(_effective_file_path)
	if _file == null:
		if _last_error == OK:
			_record_error(FileAccess.get_open_error(), "Cannot create log file: %s" % _effective_file_path, true)
	else:
		_active_files.append(weakref(_file))
		_last_flush_msec = Time.get_ticks_msec()
		_elapsed_since_flush_msec = 0.0
		_has_unflushed_data = false
		_is_initialized = true

	if _uses_default_file_path:
		_cleanup_old_jsonl_files()


## 写入一条结构化日志。
## [br]
## @api public
## [br]
## @param entry: 日志条目字典。
## [br]
## @schema entry: Dictionary log entry produced by GFLogUtility.
func write(entry: Dictionary) -> void:
	if _file == null:
		return

	var payload: Dictionary = entry.duplicate(true)
	if omit_formatted_text:
		var _erase_result_90: Variant = payload.erase("text")

	var stored: bool = _file.store_line(JSON.stringify(payload))
	if not stored:
		_write_error_count += 1
		_record_error(_file.get_error(), "Cannot write JSONL log: %s" % _effective_file_path, true)
		return
	_has_unflushed_data = true
	_flush_if_needed()


## 推进自动 flush 计时；由持有该 sink 的 GFLogUtility 调用。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param delta: 本帧时间增量（秒）；非有限或非正数不会推进状态。
func tick(delta: float) -> void:
	if (
		not is_finite(delta)
		or delta <= 0.0
		or flush_interval_msec <= 0
		or not _has_unflushed_data
	):
		return
	_elapsed_since_flush_msec += delta * 1000.0
	if _elapsed_since_flush_msec >= float(flush_interval_msec):
		flush()


## 刷新尚未写出的 JSONL 内容。
## [br]
## @api public
func flush() -> void:
	if _file != null:
		_file.flush()
		_last_flush_msec = Time.get_ticks_msec()
		_elapsed_since_flush_msec = 0.0
		_has_unflushed_data = false


## 关闭文件句柄。
## [br]
## @api public
func shutdown() -> void:
	if _file != null:
		flush()
		for index: int in range(_active_files.size() - 1, -1, -1):
			var active_file: Variant = _active_files[index].get_ref()
			if active_file == null or active_file == _file:
				_active_files.remove_at(index)
		_file.close()
		_file = null
	_is_initialized = false


## 获取当前实际输出路径。
## [br]
## @api public
## [br]
## @return JSONL 文件路径。
func get_file_path() -> String:
	return _effective_file_path


## 获取 JSONL sink 的调试快照。
## [br]
## @api public
## [br]
## @return 当前文件、打开状态和最近错误信息。
## [br]
## @schema return: Dictionary，包含 file_path、is_open、last_error、last_error_message、write_error_count、cleanup_error_count 和 uses_default_file_path。
## [br]
## @since 8.0.0
func get_debug_snapshot() -> Dictionary:
	return {
		"file_path": _effective_file_path,
		"is_open": _file != null,
		"last_error": int(_last_error),
		"last_error_message": _last_error_message,
		"write_error_count": _write_error_count,
		"cleanup_error_count": _cleanup_error_count,
		"uses_default_file_path": _uses_default_file_path,
	}


# --- 私有/辅助方法 ---

## 规范自定义路径；否则从 owner 日志路径派生独占文件名，或生成 user:// 默认名。
## [br]
## @api private
## [br]
func _resolve_file_path(owner: Object) -> String:
	_uses_default_file_path = file_path.is_empty()
	if not file_path.is_empty():
		return _normalize_custom_file_path(file_path)

	if owner != null and owner.has_method("get_log_file_path"):
		var owner_path: String = GFVariantData.to_text(owner.call("get_log_file_path"))
		if not owner_path.is_empty():
			return "%s_sink_%d.jsonl" % [owner_path.get_basename(), get_instance_id()]

	return "user://logs/gf_log_%d_sink_%d.jsonl" % [Time.get_ticks_msec(), get_instance_id()]


## 将自定义路径限制在 user://；相对路径置于 user://logs 并拒绝绝对路径及 .. 段。
## [br]
## @api private
## [br]
func _normalize_custom_file_path(path: String) -> String:
	var normalized: String = path.replace("\\", "/").strip_edges()
	if normalized.is_empty():
		_record_error(ERR_INVALID_PARAMETER, "JSONL log path is empty", true)
		return ""
	if not normalized.contains("://"):
		if normalized.is_absolute_path() or normalized.contains(":") or _has_parent_segment(normalized):
			_record_error(ERR_INVALID_PARAMETER, "Relative JSONL log path must stay under user://logs: %s" % path, true)
			return ""
		return "user://logs".path_join(normalized.simplify_path())
	if not normalized.begins_with("user://") or _has_parent_segment(normalized):
		_record_error(ERR_INVALID_PARAMETER, "JSONL log path must stay under user:// without parent traversal: %s" % path, true)
		return ""
	return "user://%s" % normalized.trim_prefix("user://").simplify_path()


## 检查去掉 user:// 前缀后的路径片段是否含独立的 ..。
## [br]
## @api private
## [br]
func _has_parent_segment(path: String) -> bool:
	for segment: String in path.trim_prefix("user://").split("/", false):
		if segment == "..":
			return true
	return false


## 必要时创建目标文件的父目录，返回目录创建错误码。
## [br]
## @api private
## [br]
func _ensure_parent_dir(path: String) -> Error:
	var base_dir: String = path.get_base_dir()
	if base_dir.is_empty() or base_dir == ".":
		return OK

	var absolute_base_dir: String = ProjectSettings.globalize_path(base_dir)
	if not DirAccess.dir_exists_absolute(absolute_base_dir):
		var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_base_dir)
		if make_dir_error != OK:
			_record_error(make_dir_error, "Cannot create JSONL log directory: %s" % base_dir, true)
			return make_dir_error
	return OK


## 按 FAIL_IF_EXISTS、APPEND 或默认 WRITE 策略打开 JSONL 文件。
## APPEND 会先尝试 READ_WRITE，失败时用 WRITE 创建，再定位到末尾。
## [br]
## @api private
## [br]
func _open_jsonl_file(path: String) -> FileAccess:
	if file_open_mode == FileOpenMode.FAIL_IF_EXISTS and FileAccess.file_exists(path):
		_record_error(ERR_ALREADY_EXISTS, "JSONL log file already exists: %s" % path, true)
		return null

	if file_open_mode == FileOpenMode.APPEND:
		var append_file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
		if append_file == null:
			append_file = FileAccess.open(path, FileAccess.WRITE)
		if append_file != null:
			append_file.seek_end()
		return append_file

	return FileAccess.open(path, FileAccess.WRITE)


## 文件已打开且立即刷新、间隔为 0 或 tick 间隔到期时执行 flush。
## [br]
## @api private
## [br]
func _flush_if_needed() -> void:
	if _file == null:
		return

	var now: int = Time.get_ticks_msec()
	if (
		flush_immediately
		or flush_interval_msec <= 0
		or now - _last_flush_msec >= flush_interval_msec
	):
		flush()


## 按文件名排序清理默认日志目录的旧 gf_log_*.jsonl 文件，并跳过活动文件。
## [br]
## @api private
## [br]
func _cleanup_old_jsonl_files() -> void:
	var base_dir: String = _effective_file_path.get_base_dir()
	var dir: DirAccess = DirAccess.open(base_dir)
	if dir == null:
		return

	var files: PackedStringArray = PackedStringArray()
	var list_error: Error = dir.list_dir_begin()
	if list_error != OK:
		_cleanup_error_count += 1
		_record_error(list_error, "Cannot list JSONL log directory: %s" % base_dir)
		return
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("gf_log_") and file_name.ends_with(".jsonl"):
			var _append_result_173: Variant = files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if files.size() <= max_jsonl_files:
		return

	files.sort()
	var to_remove: int = files.size() - max_jsonl_files
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
		var candidate_path: String = base_dir.path_join(candidate)
		if active_paths.has(ProjectSettings.globalize_path(candidate_path)):
			continue
		var remove_error: Error = DirAccess.remove_absolute(candidate_path)
		if remove_error != OK:
			_cleanup_error_count += 1
			_record_error(remove_error, "Cannot remove old JSONL log: %s" % candidate_path)
		else:
			to_remove -= 1


## 保存错误码和格式化消息，并发出 sink_failed 警告。
## [br]
## @api private
## [br]
func _record_error(error: Error, message: String, _as_error: bool = false) -> void:
	_last_error = error
	_last_error_message = "%s, error code: %s" % [message, error]
	push_warning("[GFJsonLineLogSink][json_line_log_sink.sink_failed] Log sink failed: %s." % _last_error_message)
