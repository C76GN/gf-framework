## GFSettingsFileStoreUtility: 基于 `user://` 的设置文件 Store。
##
## 该实现保留 GFSettingsUtility 历史 fallback 的同步 JSON 语义，只接受不含路径、
## `..`、盘符或前后空白的简单 basename，并返回严格 GFStorageReadResult。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFSettingsFileStoreUtility
extends GFSettingsStoreUtility


# --- 公共方法 ---

## 检查当前 FileAccess Store 是否可以接纳同步持久化请求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 始终返回 true；单次文件错误由读写结果报告。
func is_persistence_enabled() -> bool:
	return true


## 从 `user://` 读取一个 JSON 设置载荷。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param file_name: 不含目录部分的安全文件名。
## [br]
## @return 区分成功空载荷、缺失、损坏、无效请求与 IO 失败的读取结果。
func read_settings(file_name: String) -> GFStorageReadResult:
	var path: String = _get_fallback_path(file_name)
	if path.is_empty():
		return _make_read_failure(
			"Settings file name is invalid.",
			ERR_INVALID_PARAMETER,
			GFStorageReadResult.FailureKind.INVALID_REQUEST
		)
	if not FileAccess.file_exists(path):
		return _make_read_failure(
			"Settings file does not exist.",
			ERR_FILE_NOT_FOUND,
			GFStorageReadResult.FailureKind.NOT_FOUND
		)

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		return _make_read_failure(
			"Settings file could not be opened: %s" % error_string(open_error),
			open_error if open_error != OK else ERR_FILE_CANT_OPEN,
			GFStorageReadResult.FailureKind.IO_FAILED
		)

	var content: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		return _make_read_failure(
			"Settings file could not be read: %s" % error_string(read_error),
			read_error,
			GFStorageReadResult.FailureKind.IO_FAILED
		)
	if content.is_empty():
		return _make_read_failure(
			"Settings file is empty.",
			ERR_FILE_CORRUPT,
			GFStorageReadResult.FailureKind.CORRUPT
		)

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(content)
	if parse_error != OK:
		return _make_read_failure(
			"Settings JSON parse failed at line %d: %s" % [
				parser.get_error_line(),
				parser.get_error_message(),
			],
			ERR_PARSE_ERROR,
			GFStorageReadResult.FailureKind.CORRUPT
		)

	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return _make_read_failure(
			"Settings JSON root must be a Dictionary.",
			ERR_INVALID_DATA,
			GFStorageReadResult.FailureKind.CORRUPT
		)

	var data: Dictionary = parsed
	return GFStorageReadResult.new().configure_success(data)


## 向 `user://` 写入一个 JSON 设置载荷。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param file_name: 不含目录部分的安全文件名。
## [br]
## @param data: 已由 Settings Utility 序列化的设置字典。
## [br]
## @schema data: Dictionary[String, Variant] persisted settings payload produced by GFSettingsUtility.to_dict(true).
## [br]
## @return Godot Error 结果码。
func write_settings(file_name: String, data: Dictionary) -> Error:
	var path: String = _get_fallback_path(file_name)
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	var base_dir: String = path.get_base_dir()
	if not base_dir.is_empty():
		var dir_error: Error = DirAccess.make_dir_recursive_absolute(base_dir)
		if dir_error != OK:
			return dir_error

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()

	var store_error: Error = _store_string_checked(file, JSON.stringify(data, "\t"))
	file.close()
	return store_error


# --- 私有/辅助方法 ---

func _make_read_failure(
	error_message: String,
	error_code: Error,
	failure_kind: GFStorageReadResult.FailureKind
) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_failure(
		error_message,
		error_code,
		{},
		GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
		0,
		failure_kind
	)


func _store_string_checked(file: FileAccess, value: String) -> Error:
	if file == null:
		return ERR_INVALID_PARAMETER
	var stored: bool = file.store_string(value)
	var store_error: Error = file.get_error()
	if stored and store_error == OK:
		return OK
	return store_error if store_error != OK else ERR_FILE_CANT_WRITE


func _get_fallback_path(file_name: String) -> String:
	if file_name.is_absolute_path():
		push_error("[GFSettingsUtility] 已拒绝原生绝对设置路径：%s。" % file_name)
		return ""
	if not _is_safe_fallback_file_name(file_name):
		push_error("[GFSettingsUtility] 已拒绝不安全设置文件名：%s。" % file_name)
		return ""
	return "user://" + file_name


func _is_safe_fallback_file_name(file_name: String) -> bool:
	var normalized_file_name: String = file_name.strip_edges()
	if normalized_file_name.is_empty() or normalized_file_name != file_name:
		return false
	if normalized_file_name != normalized_file_name.get_file():
		return false
	if normalized_file_name.contains(".."):
		return false
	if normalized_file_name.contains("/") or normalized_file_name.contains("\\"):
		return false
	if normalized_file_name.contains(":"):
		return false
	return true
