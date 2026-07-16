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

## 输出文件路径。留空时会根据 GFLogUtility 当前日志文件派生同名 `.jsonl` 文件。
## [br]
## @api public
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

var _file: FileAccess
var _effective_file_path: String = ""
var _last_flush_msec: int = 0
var _uses_default_file_path: bool = false
var _last_error: Error = OK
var _last_error_message: String = ""
var _write_error_count: int = 0
var _cleanup_error_count: int = 0
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
			_record_error(FileAccess.get_open_error(), "无法创建日志文件：%s" % _effective_file_path, true)
	else:
		_last_flush_msec = Time.get_ticks_msec()
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
		_record_error(_file.get_error(), "无法写入 JSONL 日志：%s" % _effective_file_path, true)
		return
	_flush_if_needed()


## 刷新尚未写出的 JSONL 内容。
## [br]
## @api public
func flush() -> void:
	if _file != null:
		_file.flush()
		_last_flush_msec = Time.get_ticks_msec()


## 关闭文件句柄。
## [br]
## @api public
func shutdown() -> void:
	if _file != null:
		_file.flush()
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

func _resolve_file_path(owner: Object) -> String:
	_uses_default_file_path = file_path.is_empty()
	if not file_path.is_empty():
		return _normalize_custom_file_path(file_path)

	if owner != null and owner.has_method("get_log_file_path"):
		var owner_path: String = GFVariantData.to_text(owner.call("get_log_file_path"))
		if not owner_path.is_empty():
			return owner_path.get_basename() + ".jsonl"

	return "user://logs/gf_log_%d.jsonl" % Time.get_ticks_msec()


func _normalize_custom_file_path(path: String) -> String:
	var normalized: String = path.replace("\\", "/").strip_edges()
	if normalized.is_empty():
		_record_error(ERR_INVALID_PARAMETER, "JSONL 日志路径为空", true)
		return ""
	if not normalized.contains("://"):
		if normalized.is_absolute_path() or normalized.contains(":") or _has_parent_segment(normalized):
			_record_error(ERR_INVALID_PARAMETER, "相对 JSONL 日志路径不能越过 user://logs：%s" % path, true)
			return ""
		return "user://logs".path_join(normalized.simplify_path())
	if not normalized.begins_with("user://") or _has_parent_segment(normalized):
		_record_error(ERR_INVALID_PARAMETER, "JSONL 日志路径必须位于 user:// 且不能包含父级越界片段：%s" % path, true)
		return ""
	return "user://%s" % normalized.trim_prefix("user://").simplify_path()


func _has_parent_segment(path: String) -> bool:
	for segment: String in path.trim_prefix("user://").split("/", false):
		if segment == "..":
			return true
	return false


func _ensure_parent_dir(path: String) -> Error:
	var base_dir: String = path.get_base_dir()
	if base_dir.is_empty() or base_dir == ".":
		return OK

	var absolute_base_dir: String = ProjectSettings.globalize_path(base_dir)
	if not DirAccess.dir_exists_absolute(absolute_base_dir):
		var make_dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute_base_dir)
		if make_dir_error != OK:
			_record_error(make_dir_error, "无法创建 JSONL 日志目录：%s" % base_dir, true)
			return make_dir_error
	return OK


func _open_jsonl_file(path: String) -> FileAccess:
	if file_open_mode == FileOpenMode.FAIL_IF_EXISTS and FileAccess.file_exists(path):
		_record_error(ERR_ALREADY_EXISTS, "JSONL 日志文件已存在：%s" % path, true)
		return null

	if file_open_mode == FileOpenMode.APPEND:
		var append_file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
		if append_file == null:
			append_file = FileAccess.open(path, FileAccess.WRITE)
		if append_file != null:
			append_file.seek_end()
		return append_file

	return FileAccess.open(path, FileAccess.WRITE)


func _flush_if_needed() -> void:
	if _file == null:
		return

	var now: int = Time.get_ticks_msec()
	if (
		flush_immediately
		or flush_interval_msec <= 0
		or now - _last_flush_msec >= flush_interval_msec
	):
		_file.flush()
		_last_flush_msec = now


func _cleanup_old_jsonl_files() -> void:
	var base_dir: String = _effective_file_path.get_base_dir()
	var dir: DirAccess = DirAccess.open(base_dir)
	if dir == null:
		return

	var files: PackedStringArray = PackedStringArray()
	var list_error: Error = dir.list_dir_begin()
	if list_error != OK:
		_cleanup_error_count += 1
		_record_error(list_error, "无法列出 JSONL 日志目录：%s" % base_dir)
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
	for index: int in range(to_remove):
		var remove_error: Error = DirAccess.remove_absolute(base_dir.path_join(files[index]))
		if remove_error != OK:
			_cleanup_error_count += 1
			_record_error(remove_error, "无法清理旧 JSONL 日志：%s" % base_dir.path_join(files[index]))


func _record_error(error: Error, message: String, _as_error: bool = false) -> void:
	_last_error = error
	_last_error_message = "%s，错误码：%s" % [message, error]
	push_warning("[GFJsonLineLogSink] %s" % _last_error_message)
