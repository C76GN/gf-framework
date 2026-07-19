## GFStorageUtility: 基于 `user://` 的轻量存档系统。
##
## 支持槽位存档、元数据分离读取、`Resource` 存取，
## 以及可配置 codec、完整性校验、版本迁移和简单混淆，适合通用本地持久化场景。
## 该混淆不提供安全加密能力，请勿用于保护敏感数据。
## `Resource` 存取只面向项目生成或项目已确认来源与格式的本地文件；它不是未确认来源资源的沙盒化导入器。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFStorageUtility
extends GFUtility


# --- 信号 ---

## 解码数据失败或发现完整性校验失败后发出。
## [br]
## @api public
## [br]
## @param file_name: 文件名。
## [br]
## @param error: 错误描述。
signal data_integrity_failed(file_name: String, error: String)

## 数据版本迁移后发出。
## [br]
## @api public
## [br]
## @param file_name: 文件名。
## [br]
## @param from_version: 原版本。
## [br]
## @param to_version: 目标版本。
signal data_migrated(file_name: String, from_version: int, to_version: int)

## 异步保存完成后发出。
## [br]
## @api public
## [br]
## @param file_name: 文件名。
## [br]
## @param error: Godot 的 Error 结果码。
signal save_completed(file_name: String, error: Error)

## 异步读取完成后发出。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param file_name: 文件名。
## [br]
## @param result: 强类型读取结果。
signal load_completed(file_name: String, result: GFStorageReadResult)


# --- 常量 ---

const _TEMP_SUFFIX: String = ".tmp"
const _BACKUP_SUFFIX: String = ".bak"
const _TRANSACTION_SUFFIX: String = ".txn"

## 递归枚举文件时默认允许进入的最大目录深度。
## [br]
## @api public
const DEFAULT_MAX_LIST_DEPTH: int = 32

## 单次文件枚举默认最多返回的文件数量。
## [br]
## @api public
const DEFAULT_MAX_LISTED_FILES: int = 10000


# --- 公共变量 ---

## 用于简单 XOR + Base64 混淆的密钥；为 `0` 时直接保存明文 JSON。该字段不是安全加密密钥。
## [br]
## @api public
var encrypt_key: int = 42

## 保存子目录名；为空时直接写入 `user://`。
## [br]
## @api public
var save_dir_name: String = "saves"

## 存档 codec。为 null 时会自动创建默认 GFStorageCodec。
## [br]
## @api public
var codec: GFStorageCodec = GFStorageCodec.new()

## 数据序列化格式。
## [br]
## @api public
var file_format: GFStorageCodec.Format = GFStorageCodec.Format.JSON

## 是否压缩存档载荷。
## [br]
## @api public
var use_compression: bool = false

## JSON 读取时是否把接近整数的 float 归一为 int。Binary 格式不受影响。
## [br]
## @api public
var normalize_json_numbers: bool = false

## 是否写入并校验 SHA-256 完整性校验。
## [br]
## @api public
var use_integrity_checksum: bool = false

## 完整性校验失败时是否拒绝读取。
## [br]
## @api public
var strict_integrity: bool = true

## 启用完整性校验时，是否要求载荷必须包含 `_meta.checksum`。
## [br]
## @api public
var require_integrity_checksum: bool = true

## 是否写入时间戳、编码格式和压缩方式等诊断元数据。
## 数据版本始终写入独立文档 metadata，不受该选项影响。
## [br]
## @api public
## [br]
## @since 9.0.0
var include_storage_metadata: bool = false

## 是否允许传入绝对路径。关闭后绝对路径会被拒绝。
## [br]
## @api public
## [br]
## @since 2.0.0
var allow_absolute_paths: bool = false

## 是否允许通过 `load_resource()` 调用 Godot `ResourceLoader`。默认关闭，避免未确认来源文件进入资源加载链路。
## [br]
## @api public
## [br]
## @since 6.0.0
var allow_resource_loads: bool = false

## `load_resource()` 允许读取的文件扩展名。不包含点号；空列表表示不允许任何 Resource 读取。
## [br]
## @api public
## [br]
## @since 6.0.0
var allowed_resource_load_extensions: PackedStringArray = PackedStringArray(["tres", "res"])

## `load_resource()` 允许的类型提示。空列表表示不允许任何 Resource 读取；启用时 `type_hint` 必须精确匹配其中之一。
## [br]
## @api public
## [br]
## @since 6.0.0
var allowed_resource_load_type_hints: PackedStringArray = PackedStringArray()

## `load_resource()` 是否要求调用方传入非空 `type_hint`。
## [br]
## @api public
## [br]
## @since 6.0.0
var require_resource_load_type_hint: bool = true

## 写入嵌套相对路径时是否自动创建目录。
## [br]
## @api public
var create_directories_for_nested_paths: bool = true

## 同时运行的异步存取线程数量。小于 1 时会被钳制为 1。
## [br]
## @api public
var max_async_thread_count: int = 4:
	set(value):
		max_async_thread_count = maxi(value, 1)

## 当前存档数据版本。小于 1 会被钳制为 1。
## [br]
## @api public
var save_version: int = 1:
	set(value):
		save_version = maxi(value, 1)

## 为 true 时，读取旧版本存档必须存在完整迁移链，不能仅更新数据版本。
## [br]
## @api public
## [br]
## @since 9.0.0
var strict_schema_migrations: bool = false

## 读取旧版本数据时需要补齐的新字段默认值。
## [br]
## @api public
## [br]
## @schema default_values_for_new_keys: Dictionary，包含迁移旧存档时合并进去的新字段默认值。
var default_values_for_new_keys: Dictionary = {}

## 最近一次同步或异步读取结果；尚未读取或 dispose 后为 null。
## [br]
## @api public
## [br]
## @since 9.0.0
var last_load_result: GFStorageReadResult


# --- 私有变量 ---

var _async_tasks: Array[Dictionary] = []
var _async_queue: Array[Dictionary] = []
var _async_file_locks: Dictionary = {}
var _migration_steps: Dictionary = {}
var _path_policy: _StoragePathPolicy
var _file_ops: _StorageFileOps
var _transaction_manager: _StorageTransactionManager


# --- Godot 生命周期方法 ---

func _init() -> void:
	_ensure_storage_helpers()


# --- GF 生命周期方法 ---

## 初始化存储目录和内部帮助器。
## [br]
## @api public
func init() -> void:
	_ensure_storage_helpers()
	ignore_pause = true
	var dir_path: String = _get_save_base_path()
	var dir_error: Error = _ensure_directory_absolute(dir_path)
	if dir_error != OK:
		push_error("[GFStorageUtility] 无法初始化存储目录：%s，错误码：%s" % [dir_path, dir_error])


## 等待并清理异步存取任务。
## [br]
## @api public
func dispose() -> void:
	_wait_for_async_tasks()
	_async_tasks.clear()
	_async_queue.clear()
	_async_file_locks.clear()
	_migration_steps.clear()
	last_load_result = null
	_release_storage_helpers()


## 驱动异步存档任务完成检查。
## [br]
## @api public
## [br]
## @param _delta: 本帧时间增量（秒），默认实现不直接使用。
func tick(_delta: float = 0.0) -> void:
	_poll_async_tasks()


# --- 公共方法（Resource 存取） ---

## 保存一个 `Resource` 文件。
## [br]
## @api public
## [br]
## @param file_name: 目标文件名。
## [br]
## @param resource: 要保存的资源实例。
## [br]
## @return Godot 的 `Error` 结果码。
func save_resource(file_name: String, resource: Resource) -> Error:
	if not _validate_public_file_name(file_name, "save_resource"):
		return ERR_INVALID_PARAMETER
	if resource == null:
		push_error("[GFStorageUtility] save_resource 失败：resource 为空。")
		return ERR_INVALID_PARAMETER

	init()
	_wait_for_async_tasks_for_file(file_name)
	_recover_transaction_files([file_name])

	var temp_path: String = _get_full_path(_get_temp_filename(file_name))
	var resource_temp_path: String = _get_full_path(_get_resource_temp_filename(file_name))
	_remove_file_if_exists(resource_temp_path)
	var dir_error: Error = _ensure_parent_directory(temp_path)
	if dir_error != OK:
		return dir_error
	var save_error: Error = ResourceSaver.save(resource, resource_temp_path)
	if save_error != OK:
		_remove_file_if_exists(resource_temp_path)
		_cleanup_transaction_files([file_name])
		return save_error
	var copy_error: Error = _copy_file_bytes(resource_temp_path, temp_path)
	_remove_file_if_exists(resource_temp_path)
	if copy_error != OK:
		_cleanup_transaction_files([file_name])
		return copy_error
	return _commit_transaction([file_name])


## 读取一个 `Resource` 文件。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param file_name: 目标文件名。
## [br]
## @param type_hint: 可选类型提示。
## [br]
## @return 读取到的资源实例；不存在时返回 `null`。
## [br]
## 该方法会调用 Godot `ResourceLoader`，默认关闭。调用方必须先启用 `allow_resource_loads`，并通过类型提示 allowlist、扩展名 allowlist 与存储路径策略收窄加载边界。
func load_resource(file_name: String, type_hint: String = "") -> Resource:
	if not _validate_public_file_name(file_name, "load_resource"):
		return null
	if not allow_resource_loads:
		push_error("[GFStorageUtility] load_resource 已被默认安全策略拒绝：请先显式启用 allow_resource_loads。")
		return null

	init()
	_wait_for_async_tasks_for_file(file_name)
	_recover_transaction_files([file_name])

	var path: String = _get_full_path(file_name)
	if not FileAccess.file_exists(path):
		return null
	if not _is_resource_load_extension_allowed(path):
		push_error("[GFStorageUtility] load_resource 拒绝读取未允许扩展名的文件：%s。" % path)
		return null

	var normalized_type_hint: String = type_hint.strip_edges()
	if require_resource_load_type_hint and normalized_type_hint.is_empty():
		push_error("[GFStorageUtility] load_resource 需要显式 type_hint。")
		return null
	if not _is_resource_load_type_hint_allowed(normalized_type_hint):
		push_error("[GFStorageUtility] load_resource 拒绝未允许的 type_hint：%s。" % normalized_type_hint)
		return null

	var loaded_resource: Resource = ResourceLoader.load(path, normalized_type_hint, ResourceLoader.CACHE_MODE_IGNORE)
	if loaded_resource == null:
		return null
	if not _is_loaded_resource_compatible(loaded_resource, normalized_type_hint):
		push_error("[GFStorageUtility] load_resource 读取结果类型与 type_hint 不匹配：%s。" % normalized_type_hint)
		return null
	return loaded_resource


# --- 公共方法（文件管理） ---

## 确保存储相对目录存在。
## [br]
## @api public
## [br]
## @param directory_name: 相对存储目录；为空时只确保根存储目录存在。
## [br]
## @return Godot 的 `Error` 结果码。
func ensure_directory(directory_name: String = "") -> Error:
	if not _validate_public_directory_name(directory_name, "ensure_directory"):
		return ERR_INVALID_PARAMETER
	init()
	var normalized_directory: String = _normalize_storage_directory_name(directory_name)
	var path: String = _get_full_directory_path_from_normalized(normalized_directory)
	var error: Error = _ensure_directory_absolute(path)
	if error != OK:
		push_error("[GFStorageUtility] 无法创建目录：%s，错误码：%s" % [path, error])
	return error


## 获取存储目录路径，不创建目录。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param directory_name: 相对存储目录；为空时返回根存储目录。
## [br]
## @return 按当前路径策略解析后的目录路径。
func get_storage_directory_path(directory_name: String = "") -> String:
	if not _validate_public_directory_name(directory_name, "get_storage_directory_path"):
		return ""
	var normalized_directory: String = _normalize_storage_directory_name(directory_name)
	return _get_full_directory_path_from_normalized(normalized_directory)


## 枚举指定存储目录下的文件。
## [br]
## @api public
## [br]
## @param directory_name: 相对存储目录；为空时枚举根存储目录。
## [br]
## @param extension_filter: 可选扩展名过滤，允许传入 `"json"` 或 `".json"`。
## [br]
## @param recursive: 是否递归枚举子目录。
## [br]
## @param options: 可选参数，支持 `max_scan_depth` 与 `max_file_count`。
## [br]
## @schema options: Dictionary，包含 max_scan_depth: int 和 max_file_count: int。
## [br]
## @return 存储相对文件路径数组；若传入允许的绝对目录，则返回绝对文件路径。
func list_files(
	directory_name: String = "",
	extension_filter: String = "",
	recursive: bool = false,
	options: Dictionary = {}
) -> PackedStringArray:
	if not _validate_public_directory_name(directory_name, "list_files"):
		return PackedStringArray()
	init()
	var result: PackedStringArray = PackedStringArray()
	var normalized_directory: String = _normalize_storage_directory_name(directory_name)
	var directory_path: String = _get_full_directory_path_from_normalized(normalized_directory)
	var normalized_extension: String = _normalize_extension_filter(extension_filter)
	var max_scan_depth: int = maxi(GFVariantData.get_option_int(options, "max_scan_depth", DEFAULT_MAX_LIST_DEPTH), 0)
	var max_file_count: int = maxi(GFVariantData.get_option_int(options, "max_file_count", DEFAULT_MAX_LISTED_FILES), 0)
	var scan_state: Dictionary = _make_list_scan_state()
	_append_listed_files(
		directory_path,
		normalized_directory,
		normalized_extension,
		recursive,
		result,
		0,
		max_scan_depth,
		max_file_count,
		scan_state
	)
	result.sort()
	return result


## 删除一个存储文件。
## 同时清理同名事务临时文件、备份文件和事务标记，避免删除后被遗留事务恢复。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param file_name: 存储相对文件路径。
## [br]
## @return Godot 的 `Error` 结果码；文件不存在时返回 `ERR_FILE_NOT_FOUND`。
func delete_file(file_name: String) -> Error:
	if not _validate_public_file_name(file_name, "delete_file"):
		return ERR_INVALID_PARAMETER

	init()
	_wait_for_async_tasks_for_file(file_name)

	var path: String = _get_full_path(file_name)
	var temp_path: String = _get_full_path(_get_temp_filename(file_name))
	var backup_path: String = _get_full_path(_get_backup_filename(file_name))
	var transaction_path: String = _get_full_path(_get_transaction_filename(file_name))
	var has_storage_family: bool = (
		FileAccess.file_exists(path)
		or FileAccess.file_exists(temp_path)
		or FileAccess.file_exists(backup_path)
		or FileAccess.file_exists(transaction_path)
	)
	if not has_storage_family:
		return ERR_FILE_NOT_FOUND

	var delete_error: Error = OK
	if FileAccess.file_exists(path):
		delete_error = DirAccess.remove_absolute(path)
	_cleanup_transaction_files([file_name])
	return delete_error


# --- 公共方法（纯数据存取） ---

## 保存纯字典数据。
## [br]
## @api public
## [br]
## @param file_name: 目标文件名。
## [br]
## @param data: 要保存的字典。
## [br]
## @schema data: Dictionary，要序列化并保存的数据载荷。
## [br]
## @return Godot 的 `Error` 结果码。
func save_data(file_name: String, data: Dictionary) -> Error:
	if not _validate_public_file_name(file_name, "save_data"):
		return ERR_INVALID_PARAMETER

	init()
	_wait_for_async_tasks_for_file(file_name)
	_recover_transaction_files([file_name])

	var temp_file_name: String = _get_temp_filename(file_name)
	var write_error: Error = _write_json(temp_file_name, data)
	if write_error != OK:
		_cleanup_transaction_files([file_name])
		return write_error

	return _commit_transaction([file_name])


## 以同一个事务保存多个纯字典文件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param files: 文件名到字典载荷的映射。
## [br]
## @return Godot 的 `Error` 结果码。
## [br]
## @schema files: Dictionary，键为存储相对文件名，值为要序列化并保存的 Dictionary 载荷。
func save_data_group(files: Dictionary) -> Error:
	if files.is_empty():
		push_error("[GFStorageUtility] save_data_group 失败：files 为空。")
		return ERR_INVALID_PARAMETER

	var file_names: Array[String] = []
	var payloads_by_file: Dictionary = {}
	for raw_file_name: Variant in files.keys():
		var raw_file_name_text: String = GFVariantData.to_text(raw_file_name)
		if not _validate_public_file_name(raw_file_name_text, "save_data_group"):
			return ERR_INVALID_PARAMETER
		var file_name: String = _canonicalize_storage_file_name(raw_file_name_text, "file_name")
		if file_name.is_empty():
			return ERR_INVALID_PARAMETER
		if file_names.has(file_name):
			push_error("[GFStorageUtility] save_data_group 失败：文件名解析到同一存储目标 %s。" % file_name)
			return ERR_INVALID_PARAMETER
		var payload_value: Variant = files[raw_file_name]
		if not (payload_value is Dictionary):
			push_error("[GFStorageUtility] save_data_group 失败：%s 的载荷必须是 Dictionary。" % file_name)
			return ERR_INVALID_DATA
		file_names.append(file_name)
		payloads_by_file[file_name] = GFVariantData.as_dictionary(payload_value)

	init()
	for file_name: String in file_names:
		_wait_for_async_tasks_for_file(file_name)
	_recover_transaction_files(file_names)
	var marker_error: Error = _write_transaction_markers(file_names, false)
	if marker_error != OK:
		_cleanup_transaction_files(file_names)
		return marker_error

	for file_name: String in file_names:
		var temp_file_name: String = _get_temp_filename(file_name)
		var write_error: Error = _write_json(temp_file_name, GFVariantData.get_option_dictionary(payloads_by_file, file_name))
		if write_error != OK:
			_cleanup_transaction_files(file_names)
			return write_error

	return _commit_transaction(file_names, true)


## 严格读取纯字典数据。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param file_name: 目标文件名。
## [br]
## @return 强类型读取结果；调用方必须先检查 ok，再读取 payload。
func load_data(file_name: String) -> GFStorageReadResult:
	if not _validate_public_file_name(file_name, "load_data"):
		last_load_result = _make_load_failure("file_name is empty", ERR_INVALID_PARAMETER)
		return last_load_result.duplicate_result()

	init()
	_wait_for_async_tasks_for_file(file_name)
	_recover_transaction_files([file_name])
	return _read_json(file_name)


## 在线程中异步保存纯字典数据。完成后从主线程发出 save_completed。
## [br]
## @api public
## [br]
## @param file_name: 目标文件名。
## [br]
## @param data: 要保存的字典。
## [br]
## @schema data: Dictionary，要序列化并保存的数据载荷。
## [br]
## @return 启动线程的 Error 结果码。
func save_data_async(file_name: String, data: Dictionary) -> Error:
	if not _validate_public_file_name(file_name, "save_data_async"):
		save_completed.emit(file_name, ERR_INVALID_PARAMETER)
		return ERR_INVALID_PARAMETER

	init()
	_async_queue.append({
		"type": &"save",
		"file_name": file_name,
		"file_key": _get_async_file_key(file_name),
		"data": data.duplicate(true),
		"codec_options": _get_codec_options(),
	})
	_start_queued_async_tasks()
	return OK


## 在线程中异步读取纯字典数据。完成后从主线程发出 load_completed。
## [br]
## @api public
## [br]
## @param file_name: 目标文件名。
## [br]
## @return 启动线程的 Error 结果码。
func load_data_async(file_name: String) -> Error:
	if not _validate_public_file_name(file_name, "load_data_async"):
		var failed_result: GFStorageReadResult = _make_load_failure("file_name is empty", ERR_INVALID_PARAMETER)
		last_load_result = failed_result.duplicate_result()
		load_completed.emit(file_name, failed_result.duplicate_result())
		return ERR_INVALID_PARAMETER

	_async_queue.append({
		"type": &"load",
		"file_name": file_name,
		"file_key": _get_async_file_key(file_name),
		"codec_options": _get_codec_options(),
	})
	_start_queued_async_tasks()
	return OK


## 等待已经入队和正在执行的异步纯数据任务全部完成。
## 需要在同一路径上混合同步与异步读写时，可先调用该方法收敛顺序。
## [br]
## @api public
func wait_for_async_tasks() -> void:
	while not _async_tasks.is_empty() or not _async_queue.is_empty():
		_start_queued_async_tasks()
		if _async_tasks.is_empty():
			break

		var tasks: Array = _async_tasks.duplicate()
		_async_tasks.clear()
		for task_variant: Variant in tasks:
			var task: Dictionary = GFVariantData.as_dictionary(task_variant)
			if task.is_empty():
				continue
			var thread: Thread = _get_task_thread(task)
			var result_variant: Variant = null
			if thread != null:
				result_variant = thread.wait_to_finish()
			_erase_dictionary_key(_async_file_locks, _get_task_file_key(task))
			_complete_finished_async_task(task, result_variant)
		_start_queued_async_tasks()


## 迁移存档数据。项目可继承 GFStorageUtility 并重写该方法。
## [br]
## @api public
## [br]
## @param data: 已读取的数据副本。
## [br]
## @param _from_version: 原版本。
## [br]
## @param _to_version: 目标版本。
## [br]
## @schema data: Dictionary，在存档 schema 版本之间迁移的数据载荷。
## [br]
## @return 迁移后的数据。
## [br]
## @schema return: Dictionary，应用已注册迁移和默认值后的数据载荷。
func migrate_data(data: Dictionary, _from_version: int, _to_version: int) -> Dictionary:
	var migrated: Dictionary = _apply_registered_migrations(data, _from_version, _to_version)
	if not default_values_for_new_keys.is_empty():
		migrated = _merge_default_values(migrated, default_values_for_new_keys)
	return migrated


## 注册一个版本迁移步骤。
## [br]
## @api public
## [br]
## @param from_version: 来源版本。
## [br]
## @param to_version: 目标版本，必须大于来源版本。
## [br]
## @param callback: 迁移回调，签名为 `func(data: Dictionary, from_version: int, to_version: int) -> Dictionary`。
## [br]
## @return 注册成功时返回 true。
func register_migration(from_version: int, to_version: int, callback: Callable) -> bool:
	if from_version < 1 or to_version <= from_version or not callback.is_valid():
		push_error("[GFStorageUtility] register_migration 失败：版本范围或 callback 无效。")
		return false

	_migration_steps[_make_migration_key(from_version, to_version)] = {
		"from_version": from_version,
		"to_version": to_version,
		"callback": callback,
	}
	return true


## 注销一个版本迁移步骤。
## [br]
## @api public
## [br]
## @param from_version: 来源版本。
## [br]
## @param to_version: 目标版本。
func unregister_migration(from_version: int, to_version: int) -> void:
	_erase_dictionary_key(_migration_steps, _make_migration_key(from_version, to_version))


## 清空所有注册的版本迁移步骤。
## [br]
## @api public
func clear_migrations() -> void:
	_migration_steps.clear()


## 获取已注册迁移步骤。
## [br]
## @api public
## [br]
## @return 迁移步骤摘要数组。
## [br]
## @schema return: Array，包含 from_version: int 和 to_version: int 的 Dictionary 条目。
func get_registered_migrations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _migration_steps.values():
		result.append({
			"from_version": GFVariantData.get_option_int(entry, "from_version", 0),
			"to_version": GFVariantData.get_option_int(entry, "to_version", 0),
		})
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_from_version: int = GFVariantData.get_option_int(left, "from_version", 0)
		var right_from_version: int = GFVariantData.get_option_int(right, "from_version", 0)
		if left_from_version == right_from_version:
			return GFVariantData.get_option_int(left, "to_version", 0) < GFVariantData.get_option_int(right, "to_version", 0)
		return left_from_version < right_from_version
	)
	return result


# --- 私有/辅助方法 ---

func _wait_for_async_tasks_for_file(file_name: String) -> void:
	if not _has_pending_async_task_for_file(file_name):
		return
	wait_for_async_tasks()


func _has_pending_async_task_for_file(file_name: String) -> bool:
	var file_key: String = _get_async_file_key(file_name)
	if _async_file_locks.has(file_key):
		return true
	for task_value: Variant in _async_queue:
		var task: Dictionary = GFVariantData.as_dictionary(task_value)
		if _get_task_file_key(task) == file_key:
			return true
	return false


func _ensure_storage_helpers() -> void:
	if _path_policy == null:
		_path_policy = _StoragePathPolicy.new(self)
	if _file_ops == null:
		_file_ops = _StorageFileOps.new(self, _path_policy)
	if _transaction_manager == null:
		_transaction_manager = _StorageTransactionManager.new(self, _path_policy, _file_ops)


func _release_storage_helpers() -> void:
	if _transaction_manager != null:
		_transaction_manager._dispose()
	if _file_ops != null:
		_file_ops._dispose()
	if _path_policy != null:
		_path_policy._dispose()
	_transaction_manager = null
	_file_ops = null
	_path_policy = null


func _ensure_directory_absolute(path: String) -> Error:
	if path.is_empty() or DirAccess.dir_exists_absolute(path):
		return OK
	return DirAccess.make_dir_recursive_absolute(path)


func _begin_dir_listing(dir: DirAccess) -> Error:
	return dir.list_dir_begin()


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _merge_default_values(target: Dictionary, defaults: Dictionary) -> Dictionary:
	return GFVariantData.deep_merge_defaults(target, defaults)


func _get_thread_value(value: Variant) -> Thread:
	if value is Thread:
		return value
	return null


func _get_callable_value(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _get_task_thread(task: Dictionary) -> Thread:
	return _get_thread_value(GFVariantData.get_option_value(task, "thread"))


func _get_task_file_name(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "file_name")


func _get_task_file_key(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "file_key")


func _get_task_type(task: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(task, "type")


func _get_task_dictionary(task: Dictionary, key: String) -> Dictionary:
	return GFVariantData.get_option_dictionary(task, key)


func _get_result_error(result: Dictionary, default_value: Error = ERR_BUG) -> Error:
	return GFVariantData.get_option_int(result, "error", default_value) as Error


func _poll_async_tasks() -> void:
	for i: int in range(_async_tasks.size() - 1, -1, -1):
		var task: Dictionary = GFVariantData.as_dictionary(_async_tasks[i])
		var thread: Thread = _get_task_thread(task)
		if thread == null or thread.is_alive():
			continue

		var result_variant: Variant = thread.wait_to_finish()
		_async_tasks.remove_at(i)
		_erase_dictionary_key(_async_file_locks, _get_task_file_key(task))
		_complete_finished_async_task(task, result_variant)
	_start_queued_async_tasks()


func _wait_for_async_tasks() -> void:
	for task: Dictionary in _async_tasks:
		var thread: Thread = _get_task_thread(task)
		if thread != null:
			var result_variant: Variant = thread.wait_to_finish()
			_complete_finished_async_task(task, result_variant)
	_async_tasks.clear()
	_async_file_locks.clear()
	_fail_queued_async_tasks("Storage utility disposed before task started.")
	_async_queue.clear()


func _start_queued_async_tasks() -> void:
	while _async_tasks.size() < maxi(max_async_thread_count, 1):
		var task_index: int = _find_startable_async_task_index()
		if task_index < 0:
			return

		var task: Dictionary = GFVariantData.as_dictionary(_async_queue[task_index])
		_async_queue.remove_at(task_index)
		_start_async_task(task)


func _find_startable_async_task_index() -> int:
	for i: int in range(_async_queue.size()):
		var task: Dictionary = GFVariantData.as_dictionary(_async_queue[i])
		var file_key: String = _get_task_file_key(task)
		if file_key.is_empty() or not _async_file_locks.has(file_key):
			return i
	return -1


func _start_async_task(task: Dictionary) -> void:
	var file_name: String = _get_task_file_name(task)
	var task_type: StringName = _get_task_type(task)
	var thread: Thread = Thread.new()
	_recover_transaction_files([file_name])

	var error: Error = ERR_INVALID_PARAMETER
	if task_type == &"save":
		error = thread.start(Callable(self, "_save_data_thread").bind(
			file_name,
			_get_full_path(file_name),
			_get_full_path(_get_temp_filename(file_name)),
			_get_full_path(_get_backup_filename(file_name)),
			_get_full_path(_get_transaction_filename(file_name)),
			_get_task_dictionary(task, "data"),
			_get_task_dictionary(task, "codec_options")
		))
	elif task_type == &"load":
		error = thread.start(Callable(self, "_load_data_thread").bind(
			file_name,
			_get_full_path(file_name),
			_get_task_dictionary(task, "codec_options")
		))

	if error != OK:
		_emit_async_start_failed(task, error)
		return

	task["thread"] = thread
	_async_file_locks[_get_task_file_key(task)] = true
	_async_tasks.append(task)


func _emit_async_start_failed(task: Dictionary, error: Error) -> void:
	var file_name: String = _get_task_file_name(task)
	var task_type: StringName = _get_task_type(task)
	if task_type == &"save":
		push_error("[GFStorageUtility] 无法启动异步保存线程：%s，错误码：%s" % [file_name, error])
		save_completed.emit(file_name, error)
	elif task_type == &"load":
		push_error("[GFStorageUtility] 无法启动异步读取线程：%s，错误码：%s" % [file_name, error])
		var failed_result: GFStorageReadResult = _make_load_failure(
			"Thread start failed: %s" % error_string(error),
			error
		)
		last_load_result = failed_result.duplicate_result()
		load_completed.emit(file_name, failed_result.duplicate_result())


func _complete_finished_async_task(task: Dictionary, result_variant: Variant) -> void:
	var file_name: String = _get_task_file_name(task)
	var task_type: StringName = _get_task_type(task)
	if task_type == &"save":
		var save_result: Dictionary = GFVariantData.as_dictionary(result_variant)
		var error: Error = ERR_BUG
		if not save_result.is_empty():
			error = _get_result_error(save_result, ERR_BUG)
		save_completed.emit(file_name, error)
	elif task_type == &"load":
		_complete_async_load(file_name, result_variant)


func _fail_queued_async_tasks(reason: String) -> void:
	for task: Dictionary in _async_queue:
		var file_name: String = _get_task_file_name(task)
		var task_type: StringName = _get_task_type(task)
		if task_type == &"save":
			save_completed.emit(file_name, ERR_UNAVAILABLE)
		elif task_type == &"load":
			var failed_result: GFStorageReadResult = _make_load_failure(reason, ERR_UNAVAILABLE)
			last_load_result = failed_result.duplicate_result()
			load_completed.emit(file_name, failed_result.duplicate_result())


func _complete_async_load(file_name: String, result_variant: Variant) -> void:
	var result_data: Dictionary = GFVariantData.as_dictionary(result_variant)
	var result: GFStorageReadResult
	if result_data.is_empty():
		result = _make_load_failure("Async load failed", ERR_CANT_ACQUIRE_RESOURCE)
	else:
		result = GFStorageReadResult.from_dict(result_data)
	result = _apply_schema_migrations(file_name, result)
	last_load_result = result.duplicate_result()
	if not result.ok:
		if _should_emit_load_integrity_failed(result):
			data_integrity_failed.emit(file_name, result.error)
		load_completed.emit(file_name, last_load_result.duplicate_result())
		return

	if result.integrity_status == GFStorageReadResult.IntegrityStatus.INVALID:
		data_integrity_failed.emit(file_name, "Integrity checksum mismatch")
	load_completed.emit(file_name, last_load_result.duplicate_result())


func _should_emit_load_integrity_failed(result: GFStorageReadResult) -> bool:
	if result == null:
		return false
	if (
		result.error_code == ERR_FILE_NOT_FOUND
		or result.error_code == ERR_FILE_CANT_OPEN
		or result.error == "File is empty"
	):
		return false
	return true


func _save_data_thread(
	file_name: String,
	final_path: String,
	temp_path: String,
	backup_path: String,
	transaction_path: String,
	data: Dictionary,
	codec_options: Dictionary
) -> Dictionary:
	var dir_error: Error = _ensure_absolute_parent_directory(final_path)
	if dir_error != OK:
		return { "error": dir_error }

	var thread_codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = thread_codec.encode(data, codec_options)
	var write_error: Error = _write_buffer_absolute(temp_path, bytes)
	if write_error != OK:
		_remove_absolute_file_if_exists(temp_path)
		return { "error": write_error }

	var had_final: bool = FileAccess.file_exists(final_path)
	var marker_error: Error = _write_plain_json_absolute(transaction_path, {
		"files": [file_name],
		"committed": false,
		"had_final": had_final,
	})
	if marker_error != OK:
		_remove_absolute_file_if_exists(temp_path)
		return { "error": marker_error }

	var backed_up: bool = false
	var committed: bool = false
	if had_final:
		var backup_error: Error = DirAccess.rename_absolute(final_path, backup_path)
		if backup_error != OK:
			_remove_absolute_file_if_exists(temp_path)
			_remove_absolute_file_if_exists(transaction_path)
			return { "error": backup_error }
		backed_up = true

	var commit_error: Error = DirAccess.rename_absolute(temp_path, final_path)
	if commit_error != OK:
		_rollback_absolute_transaction(final_path, temp_path, backup_path, backed_up, committed)
		_remove_absolute_file_if_exists(transaction_path)
		return { "error": commit_error }
	committed = true

	var complete_marker_error: Error = _write_plain_json_absolute(transaction_path, {
		"files": [file_name],
		"committed": true,
		"had_final": had_final,
	})
	if complete_marker_error != OK:
		_rollback_absolute_transaction(final_path, temp_path, backup_path, backed_up, committed)
		_remove_absolute_file_if_exists(transaction_path)
		return { "error": complete_marker_error }

	_remove_absolute_file_if_exists(backup_path)
	_remove_absolute_file_if_exists(transaction_path)
	return { "error": OK }


func _load_data_thread(_file_name: String, path: String, codec_options: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _make_thread_load_failure("File not found", ERR_FILE_NOT_FOUND)

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _make_thread_load_failure(
			"File open failed: %s" % error_string(FileAccess.get_open_error()),
			ERR_FILE_CANT_OPEN
		)

	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	if bytes.is_empty():
		return _make_thread_load_failure("File is empty", ERR_FILE_CORRUPT)

	var thread_codec: GFStorageCodec = GFStorageCodec.new()
	return thread_codec.decode(bytes, codec_options).to_dict()


func _make_thread_load_failure(error_message: String, error_code: Error) -> Dictionary:
	return GFStorageReadResult.new().configure_failure(error_message, error_code).to_dict()


func _ensure_absolute_parent_directory(path: String) -> Error:
	_ensure_storage_helpers()
	return _file_ops._ensure_absolute_parent_directory(path)


func _write_buffer_absolute(path: String, bytes: PackedByteArray) -> Error:
	_ensure_storage_helpers()
	return _file_ops._write_buffer_absolute(path, bytes)


func _copy_file_bytes(source_path: String, target_path: String) -> Error:
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return FileAccess.get_open_error()

	var bytes: PackedByteArray = source_file.get_buffer(source_file.get_length())
	var read_error: Error = source_file.get_error()
	source_file.close()
	if read_error != OK:
		return read_error
	return _write_buffer_absolute(target_path, bytes)


func _write_plain_json_absolute(path: String, data: Dictionary) -> Error:
	_ensure_storage_helpers()
	return _file_ops._write_plain_json_absolute(path, data)


func _remove_absolute_file_if_exists(path: String) -> void:
	_ensure_storage_helpers()
	_file_ops._remove_absolute_file_if_exists(path)


func _rollback_absolute_transaction(
	final_path: String,
	temp_path: String,
	backup_path: String,
	backed_up: bool,
	committed: bool
) -> void:
	if committed or backed_up:
		_remove_absolute_file_if_exists(final_path)
	_remove_absolute_file_if_exists(temp_path)
	if backed_up and FileAccess.file_exists(backup_path):
		var restore_error: Error = DirAccess.rename_absolute(backup_path, final_path)
		if restore_error != OK:
			push_warning("[GFStorageUtility] 回滚事务恢复备份失败：%s -> %s，错误码：%s" % [backup_path, final_path, restore_error])


func _get_save_base_path() -> String:
	_ensure_storage_helpers()
	return _path_policy._get_save_base_path()


func _get_full_path(file_name: String) -> String:
	_ensure_storage_helpers()
	return _path_policy._get_full_path(file_name)


func _get_resource_temp_filename(file_name: String) -> String:
	var extension: String = file_name.get_extension()
	if extension.is_empty():
		return _get_temp_filename(file_name)
	var suffix: String = ".%s" % extension
	return "%s%s%s" % [file_name.trim_suffix(suffix), _TEMP_SUFFIX, suffix]


func _is_resource_load_extension_allowed(path: String) -> bool:
	var extension: String = path.get_extension().to_lower()
	if extension.is_empty():
		return false
	for allowed_extension: String in allowed_resource_load_extensions:
		var normalized_extension: String = allowed_extension.strip_edges().trim_prefix(".").to_lower()
		if normalized_extension == extension:
			return true
	return false


func _is_resource_load_type_hint_allowed(type_hint: String) -> bool:
	if allowed_resource_load_type_hints.is_empty():
		return false
	for allowed_type_hint: String in allowed_resource_load_type_hints:
		if allowed_type_hint.strip_edges() == type_hint:
			return true
	return false


func _is_loaded_resource_compatible(resource: Resource, type_hint: String) -> bool:
	if resource == null or type_hint.is_empty():
		return false
	if resource.is_class(type_hint):
		return true

	var script: Script = _get_script_value(resource.get_script())
	while script != null:
		if GFVariantData.to_text(script.get_global_name()) == type_hint or script.resource_path == type_hint:
			return true
		script = script.get_base_script()
	return false


func _get_script_value(value: Variant) -> Script:
	if value is Script:
		return value
	return null


func _get_full_directory_path_from_normalized(directory_name: String) -> String:
	_ensure_storage_helpers()
	return _path_policy._get_full_directory_path_from_normalized(directory_name)


func _normalize_storage_directory_name(directory_name: String) -> String:
	_ensure_storage_helpers()
	return _path_policy._normalize_storage_directory_name(directory_name)


func _append_listed_files(
	directory_path: String,
	relative_prefix: String,
	extension_filter: String,
	recursive: bool,
	result: PackedStringArray,
	depth: int,
	max_scan_depth: int,
	max_file_count: int,
	scan_state: Dictionary
) -> void:
	if not _can_append_listed_file(result, max_file_count):
		_warn_list_file_limit(max_file_count, scan_state)
		return

	var dir: DirAccess = DirAccess.open(directory_path)
	if dir == null:
		return

	var list_error: Error = _begin_dir_listing(dir)
	if list_error != OK:
		return
	var entry_name: String = dir.get_next()
	while not entry_name.is_empty():
		if not _can_append_listed_file(result, max_file_count):
			_warn_list_file_limit(max_file_count, scan_state)
			break

		if entry_name.begins_with("."):
			entry_name = dir.get_next()
			continue

		if dir.current_is_dir():
			if recursive and _can_scan_list_deeper(
				directory_path.path_join(entry_name),
				depth,
				max_scan_depth,
				scan_state
			):
				_append_listed_files(
					directory_path.path_join(entry_name),
					_get_storage_relative_file_path(relative_prefix, entry_name),
					extension_filter,
					recursive,
					result,
					depth + 1,
					max_scan_depth,
					max_file_count,
					scan_state
				)
		elif _file_matches_extension(entry_name, extension_filter):
			_append_packed_string(result, _get_storage_relative_file_path(relative_prefix, entry_name))
		entry_name = dir.get_next()
	dir.list_dir_end()


func _can_scan_list_deeper(path: String, current_depth: int, max_scan_depth: int, scan_state: Dictionary) -> bool:
	if max_scan_depth <= 0 or current_depth < max_scan_depth:
		return true
	_warn_list_depth_limit(path, max_scan_depth, scan_state)
	return false


func _can_append_listed_file(result: PackedStringArray, max_file_count: int) -> bool:
	return max_file_count <= 0 or result.size() < max_file_count


func _make_list_scan_state() -> Dictionary:
	return {
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
	}


func _warn_list_file_limit(max_file_count: int, scan_state: Dictionary) -> void:
	if max_file_count <= 0 or GFVariantData.get_option_bool(scan_state, "count_warning_emitted", false):
		return
	scan_state["count_warning_emitted"] = true
	push_warning("[GFStorageUtility] list_files 已达到 max_file_count=%d，后续文件已跳过。" % max_file_count)


func _warn_list_depth_limit(path: String, max_scan_depth: int, scan_state: Dictionary) -> void:
	if max_scan_depth <= 0 or GFVariantData.get_option_bool(scan_state, "depth_warning_emitted", false):
		return
	scan_state["depth_warning_emitted"] = true
	push_warning("[GFStorageUtility] list_files 已达到 max_scan_depth=%d，已跳过更深目录：%s。" % [max_scan_depth, path])


func _get_storage_relative_file_path(directory_name: String, file_name: String) -> String:
	if directory_name.is_empty():
		return file_name
	return directory_name.path_join(file_name)


func _normalize_extension_filter(extension_filter: String) -> String:
	_ensure_storage_helpers()
	return _path_policy._normalize_extension_filter(extension_filter)


func _file_matches_extension(file_name: String, extension_filter: String) -> bool:
	_ensure_storage_helpers()
	return _path_policy._file_matches_extension(file_name, extension_filter)


func _sanitize_storage_relative_path(path: String, label: String) -> String:
	_ensure_storage_helpers()
	return _path_policy._sanitize_storage_relative_path(path, label)


func _canonicalize_storage_file_name(path: String, label: String = "file_name") -> String:
	_ensure_storage_helpers()
	return _path_policy._canonicalize_file_name(path, label)


func _validate_public_file_name(file_name: String, operation: String) -> bool:
	if file_name.strip_edges().is_empty():
		push_error("[GFStorageUtility] %s 失败：file_name 为空。" % operation)
		return false
	if not _is_safe_storage_path(file_name, "file_name"):
		return false
	return true


func _validate_public_directory_name(directory_name: String, operation: String) -> bool:
	if directory_name.is_empty() or directory_name == ".":
		return true
	if not _is_safe_storage_path(directory_name, "directory_name"):
		push_error("[GFStorageUtility] %s 失败：directory_name 非法。" % operation)
		return false
	return true


func _is_parent_directory_path(path: String) -> bool:
	_ensure_storage_helpers()
	return _path_policy._is_parent_directory_path(path)


func _is_safe_storage_path(path: String, label: String) -> bool:
	_ensure_storage_helpers()
	return _path_policy._is_safe_storage_path(path, label)


func _get_async_file_key(file_name: String) -> String:
	return _get_full_path(file_name)


func _remove_file_if_exists(path: String) -> void:
	_ensure_storage_helpers()
	_file_ops._remove_file_if_exists(path)


func _get_temp_filename(file_name: String) -> String:
	_ensure_storage_helpers()
	return _transaction_manager._get_temp_filename(file_name)


func _get_backup_filename(file_name: String) -> String:
	_ensure_storage_helpers()
	return _transaction_manager._get_backup_filename(file_name)


func _get_transaction_filename(file_name: String) -> String:
	_ensure_storage_helpers()
	return _transaction_manager._get_transaction_filename(file_name)


func _cleanup_transaction_files(file_names: Array[String]) -> void:
	_ensure_storage_helpers()
	_transaction_manager._cleanup_transaction_files(file_names)


func _recover_transaction_files(file_names: Array[String]) -> void:
	_ensure_storage_helpers()
	_transaction_manager._recover_transaction_files(file_names)


func _recover_transaction_group(file_names: Array[String]) -> void:
	_ensure_storage_helpers()
	_transaction_manager._recover_transaction_group(file_names)


func _recover_transaction_file(file_name: String) -> void:
	_ensure_storage_helpers()
	_transaction_manager._recover_transaction_file(file_name)


func _commit_transaction(file_names: Array[String], markers_prepared: bool = false) -> Error:
	_ensure_storage_helpers()
	return _transaction_manager._commit_transaction(file_names, markers_prepared)


func _rollback_transaction(file_names: Array[String], transaction_state: Dictionary) -> void:
	_ensure_storage_helpers()
	_transaction_manager._rollback_transaction(file_names, transaction_state)


func _write_transaction_markers(file_names: Array[String], committed: bool) -> Error:
	_ensure_storage_helpers()
	return _transaction_manager._write_transaction_markers(file_names, committed)


func _cleanup_transaction_markers(file_names: Array[String]) -> void:
	_ensure_storage_helpers()
	_transaction_manager._cleanup_transaction_markers(file_names)


func _read_transaction_marker(file_name: String) -> Dictionary:
	_ensure_storage_helpers()
	return _transaction_manager._read_transaction_marker(file_name)


func _get_transaction_marker_files(marker: Dictionary, fallback_file_name: String) -> Array[String]:
	_ensure_storage_helpers()
	return _transaction_manager._get_transaction_marker_files(marker, fallback_file_name)


func _is_transaction_group_committed(file_names: Array[String]) -> bool:
	_ensure_storage_helpers()
	return _transaction_manager._is_transaction_group_committed(file_names)


func _unique_file_names(file_names: Array[String]) -> Array[String]:
	_ensure_storage_helpers()
	return _transaction_manager._unique_file_names(file_names)


func _move_file(from_path: String, to_path: String) -> Error:
	_ensure_storage_helpers()
	return _file_ops._move_file(from_path, to_path)


func _write_json(file_name: String, data: Dictionary) -> Error:
	_ensure_storage_helpers()
	return _file_ops._write_json(file_name, data)


func _write_plain_json(file_name: String, data: Dictionary) -> Error:
	_ensure_storage_helpers()
	return _file_ops._write_plain_json(file_name, data)


func _ensure_parent_directory(path: String) -> Error:
	_ensure_storage_helpers()
	return _file_ops._ensure_parent_directory(path)


func _read_json(file_name: String) -> GFStorageReadResult:
	_recover_transaction_files([file_name])

	var path: String = _get_full_path(file_name)
	if not FileAccess.file_exists(path):
		last_load_result = _make_load_failure("File not found", ERR_FILE_NOT_FOUND)
		return last_load_result.duplicate_result()

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		push_error("[GFStorageUtility] 无法读取文件：%s，错误码：%s" % [path, open_error])
		last_load_result = _make_load_failure(
			"File open failed: %s" % error_string(open_error),
			open_error
		)
		return last_load_result.duplicate_result()

	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()

	if bytes.is_empty():
		last_load_result = _make_load_failure("File is empty", ERR_FILE_CORRUPT)
		return last_load_result.duplicate_result()

	var result: GFStorageReadResult = _get_codec().decode(bytes, _get_codec_options())
	result = _apply_schema_migrations(file_name, result)
	last_load_result = result.duplicate_result()
	if not result.ok:
		if _should_emit_load_integrity_failed(result):
			data_integrity_failed.emit(file_name, result.error)
		if not result.is_integrity_accepted():
			push_warning("[GFStorageUtility] 读取数据失败：%s，原因：%s" % [path, result.error])
		else:
			push_error("[GFStorageUtility] 读取数据失败：%s，原因：%s" % [path, result.error])
		return result

	if result.integrity_status == GFStorageReadResult.IntegrityStatus.INVALID:
		data_integrity_failed.emit(file_name, "Integrity checksum mismatch")
	return result


func _get_codec() -> GFStorageCodec:
	if codec == null:
		codec = GFStorageCodec.new()
	return codec


func _get_codec_options() -> Dictionary:
	return {
		"format": file_format,
		"use_compression": use_compression,
		"normalize_json_numbers": normalize_json_numbers,
		"use_integrity_checksum": use_integrity_checksum,
		"strict_integrity": strict_integrity,
		"require_integrity_checksum": require_integrity_checksum,
		"include_metadata": include_storage_metadata,
		"version": save_version,
		"obfuscation_key": encrypt_key,
	}


func _apply_schema_migrations(file_name: String, result: GFStorageReadResult) -> GFStorageReadResult:
	if result == null or not result.ok:
		return result
	var from_version: int = result.data_version
	var to_version: int = save_version
	if from_version > to_version:
		return _fail_future_storage_version(result, from_version, to_version)
	if from_version >= to_version:
		if not default_values_for_new_keys.is_empty():
			result.payload = _merge_default_values(result.payload, default_values_for_new_keys)
		return result

	var migration_chain: Array[int] = _resolve_migration_chain(from_version, to_version)
	if (strict_schema_migrations or not _migration_steps.is_empty()) and migration_chain.is_empty():
		return _fail_schema_migration(result, from_version, to_version)

	var migrated_payload: Dictionary = migrate_data(result.payload, from_version, to_version)
	var migrated_metadata: Dictionary = result.metadata.duplicate(true)
	migrated_metadata[GFStorageCodec.VERSION_KEY] = to_version
	result.payload = migrated_payload
	result.metadata = migrated_metadata
	result.data_version = to_version
	result.migrated = true
	data_migrated.emit(file_name, from_version, to_version)
	return result


func _apply_registered_migrations(data: Dictionary, from_version: int, to_version: int) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	var chain: Array[int] = _resolve_migration_chain(from_version, to_version)
	if chain.is_empty():
		return migrated

	var current_version: int = from_version
	for next_version: int in chain:
		var entry: Dictionary = GFVariantData.get_option_dictionary(_migration_steps, _make_migration_key(current_version, next_version))
		var callback: Callable = _get_callable_value(GFVariantData.get_option_value(entry, "callback", Callable()))
		if not callback.is_valid():
			push_warning("[GFStorageUtility] 迁移步骤无效，已跳过：%d -> %d。" % [current_version, next_version])
			current_version = next_version
			continue

		var result: Variant = callback.call(migrated.duplicate(true), current_version, next_version)
		if result is Dictionary:
			migrated = GFVariantData.as_dictionary(result)
		else:
			push_warning("[GFStorageUtility] 迁移步骤未返回 Dictionary，保留原数据：%d -> %d。" % [current_version, next_version])
		current_version = next_version
	return migrated


func _resolve_migration_chain(from_version: int, to_version: int) -> Array[int]:
	if from_version >= to_version:
		return []
	var queue: Array[Dictionary] = [{
		"version": from_version,
		"chain": [],
	}]
	var best_depth_by_version: Dictionary = { from_version: 0 }
	while not queue.is_empty():
		var candidate_path: Dictionary = queue.pop_front()
		var current_version: int = GFVariantData.get_option_int(candidate_path, "version")
		var current_chain: Array[int] = _to_int_array(GFVariantData.get_option_array(candidate_path, "chain"))
		var next_versions: Array[int] = _get_migration_targets(current_version, to_version)
		for next_version: int in next_versions:
			var next_chain: Array[int] = current_chain.duplicate()
			next_chain.append(next_version)
			if next_version == to_version:
				return next_chain
			var next_depth: int = next_chain.size()
			if best_depth_by_version.has(next_version) and GFVariantData.get_option_int(best_depth_by_version, next_version) <= next_depth:
				continue
			best_depth_by_version[next_version] = next_depth
			queue.append({
				"version": next_version,
				"chain": next_chain,
			})
	if not _migration_steps.is_empty():
		push_warning("[GFStorageUtility] 未找到完整迁移链：%d -> %d。" % [from_version, to_version])
	return []


func _fail_schema_migration(
	result: GFStorageReadResult,
	from_version: int,
	to_version: int
) -> GFStorageReadResult:
	var error_message: String = "Missing migration chain: %d -> %d" % [from_version, to_version]
	return _make_migration_failure(result, error_message)


func _fail_future_storage_version(
	result: GFStorageReadResult,
	from_version: int,
	to_version: int
) -> GFStorageReadResult:
	var error_message: String = "Unsupported future storage version: %d > %d" % [from_version, to_version]
	return _make_migration_failure(result, error_message)


func _get_migration_targets(from_version: int, to_version: int) -> Array[int]:
	var result: Array[int] = []
	for entry: Dictionary in _migration_steps.values():
		if GFVariantData.get_option_int(entry, "from_version", 0) != from_version:
			continue
		var candidate: int = GFVariantData.get_option_int(entry, "to_version", 0)
		if candidate <= from_version or candidate > to_version or result.has(candidate):
			continue
		result.append(candidate)
	result.sort_custom(func(left: int, right: int) -> bool:
		return left > right
	)
	return result


func _to_int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value: Variant in values:
		result.append(GFVariantData.to_int(value))
	return result


func _make_migration_key(from_version: int, to_version: int) -> String:
	return "%d>%d" % [from_version, to_version]


func _make_load_failure(error_message: String, error_code: Error) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_failure(error_message, error_code)


func _make_migration_failure(result: GFStorageReadResult, error_message: String) -> GFStorageReadResult:
	if result == null:
		return _make_load_failure(error_message, ERR_INVALID_DATA)
	return GFStorageReadResult.new().configure_failure(
		error_message,
		ERR_INVALID_DATA,
		result.metadata,
		result.integrity_status,
		result.document_schema_version
	)


# --- 内部类 ---

class _StoragePathPolicy:
	var _owner: Object

	func _init(p_owner: Object) -> void:
		_owner = p_owner

	func _dispose() -> void:
		_owner = null

	func _get_owner_property(property_name: String) -> Variant:
		if _owner == null:
			return null
		return _owner.get_indexed(NodePath(property_name))

	func _get_string_property(property_name: String, fallback: String = "") -> String:
		var value: Variant = _get_owner_property(property_name)
		if value is String:
			return value
		if value is StringName:
			var string_name_value: StringName = value
			return String(string_name_value)
		if value is NodePath:
			var node_path_value: NodePath = value
			return String(node_path_value)
		if value == null:
			return fallback
		return str(value)

	func _get_bool_property(property_name: String, fallback: bool = false) -> bool:
		var value: Variant = _get_owner_property(property_name)
		if value is bool:
			return value
		if value is int:
			var int_value: int = value
			return int_value != 0
		if value is float:
			var float_value: float = value
			return not is_zero_approx(float_value)
		return fallback

	func _get_save_base_path() -> String:
		var save_dir_name: String = _get_string_property("save_dir_name")
		if save_dir_name.is_empty():
			return "user://"
		return "user://" + _sanitize_storage_relative_path(save_dir_name, "save_dir_name")

	func _get_full_path(file_name: String) -> String:
		if file_name.is_absolute_path():
			if _get_bool_property("allow_absolute_paths"):
				return file_name
			push_error("[GFStorageUtility] 已禁用绝对路径：%s" % file_name)
			return ""

		file_name = _sanitize_storage_relative_path(file_name, "file_name")
		if file_name.is_empty():
			return ""
		if _get_string_property("save_dir_name").is_empty():
			return "user://" + file_name
		return _get_save_base_path() + "/" + file_name

	func _get_full_directory_path_from_normalized(directory_name: String) -> String:
		if directory_name.is_empty():
			return _get_save_base_path()
		if directory_name.is_absolute_path():
			return directory_name
		if _get_string_property("save_dir_name").is_empty():
			return "user://" + directory_name
		return _get_save_base_path().path_join(directory_name)

	func _normalize_storage_directory_name(directory_name: String) -> String:
		if directory_name.is_empty() or directory_name == ".":
			return ""
		if directory_name.is_absolute_path():
			if _get_bool_property("allow_absolute_paths"):
				return directory_name.replace("\\", "/").simplify_path()
			push_error("[GFStorageUtility] 已禁用绝对路径：%s" % directory_name)
			return "_invalid_storage_directory"

		var original_path: String = directory_name
		var normalized: String = directory_name.replace("\\", "/").simplify_path()
		if normalized == ".":
			return ""
		if _is_parent_directory_path(normalized):
			push_error("[GFStorageUtility] 已拒绝跨目录路径（directory_name）：%s" % original_path)
			return "_invalid_storage_directory"
		if normalized.is_empty() or normalized == "." or normalized == "..":
			push_error("[GFStorageUtility] directory_name 为空。")
			return "_invalid_storage_directory"
		return normalized

	func _normalize_extension_filter(extension_filter: String) -> String:
		return extension_filter.strip_edges().trim_prefix(".").to_lower()

	func _file_matches_extension(file_name: String, extension_filter: String) -> bool:
		return extension_filter.is_empty() or file_name.get_extension().to_lower() == extension_filter

	func _sanitize_storage_relative_path(path: String, label: String) -> String:
		var original_path: String = path
		if _contains_parent_segment(path):
			push_error("[GFStorageUtility] 已拒绝跨目录路径（%s）：%s" % [label, original_path])
			return ""
		var normalized: String = path.replace("\\", "/").simplify_path()
		if normalized == ".":
			normalized = ""
		if _is_parent_directory_path(normalized):
			push_error("[GFStorageUtility] 已拒绝跨目录路径（%s）：%s" % [label, original_path])
			return ""
		if normalized.is_empty() or normalized == "." or normalized == "..":
			push_error("[GFStorageUtility] %s 为空。" % label)
			return ""
		return normalized

	func _is_parent_directory_path(path: String) -> bool:
		return path == ".." or path.begins_with("../") or path.contains("/../")

	func _contains_parent_segment(path: String) -> bool:
		for segment: String in path.replace("\\", "/").split("/", true):
			if segment == "..":
				return true
		return false

	func _canonicalize_file_name(path: String, label: String) -> String:
		if path.is_absolute_path():
			if not _get_bool_property("allow_absolute_paths"):
				push_error("[GFStorageUtility] 已禁用绝对路径：%s" % path)
				return ""
			return path.replace("\\", "/").simplify_path()
		return _sanitize_storage_relative_path(path, label)

	func _is_safe_storage_path(path: String, label: String) -> bool:
		if path.is_absolute_path():
			if _get_bool_property("allow_absolute_paths"):
				return true
			push_error("[GFStorageUtility] 已禁用绝对路径：%s" % path)
			return false

		if _contains_parent_segment(path):
			push_error("[GFStorageUtility] 已拒绝跨目录路径（%s）：%s" % [label, path])
			return false
		var normalized: String = path.replace("\\", "/").simplify_path()
		if normalized == ".":
			normalized = ""
		if _is_parent_directory_path(normalized):
			push_error("[GFStorageUtility] 已拒绝跨目录路径（%s）：%s" % [label, path])
			return false
		if normalized.is_empty() or normalized == "." or normalized == "..":
			push_error("[GFStorageUtility] %s 为空。" % label)
			return false
		return true


class _StorageFileOps:
	var _owner: Object
	var _path_policy: _StoragePathPolicy

	func _init(p_owner: Object, p_path_policy: _StoragePathPolicy) -> void:
		_owner = p_owner
		_path_policy = p_path_policy

	func _dispose() -> void:
		_owner = null
		_path_policy = null

	func _get_owner_property(property_name: String) -> Variant:
		if _owner == null:
			return null
		return _owner.get_indexed(NodePath(property_name))

	func _get_bool_property(property_name: String, fallback: bool = false) -> bool:
		var value: Variant = _get_owner_property(property_name)
		if value is bool:
			return value
		if value is int:
			var int_value: int = value
			return int_value != 0
		if value is float:
			var float_value: float = value
			return not is_zero_approx(float_value)
		return fallback

	func _get_codec() -> GFStorageCodec:
		var codec_value: Variant = _owner.call("_get_codec")
		if codec_value is GFStorageCodec:
			return codec_value
		return GFStorageCodec.new()

	func _get_codec_options() -> Dictionary:
		var options_value: Variant = _owner.call("_get_codec_options")
		if options_value is Dictionary:
			return options_value
		return {}

	func _store_buffer_checked(file: FileAccess, bytes: PackedByteArray) -> void:
		var store_result: Variant = file.store_buffer(bytes)
		if store_result != null:
			return

	func _store_string_checked(file: FileAccess, value: String) -> void:
		var store_result: Variant = file.store_string(value)
		if store_result != null:
			return

	func _remove_absolute_if_exists(path: String) -> void:
		if not FileAccess.file_exists(path):
			return
		var remove_error: Error = DirAccess.remove_absolute(path)
		if remove_error != OK:
			push_warning("[GFStorageUtility] 删除文件失败：%s，错误码：%s" % [path, remove_error])

	func _ensure_absolute_parent_directory(path: String) -> Error:
		var base_dir: String = path.get_base_dir()
		if base_dir.is_empty() or base_dir == "user://":
			return OK
		if DirAccess.dir_exists_absolute(base_dir):
			return OK
		return DirAccess.make_dir_recursive_absolute(base_dir)

	func _ensure_parent_directory(path: String) -> Error:
		if not _get_bool_property("create_directories_for_nested_paths"):
			return OK

		var base_dir: String = path.get_base_dir()
		if base_dir.is_empty() or base_dir == "user://":
			return OK
		if DirAccess.dir_exists_absolute(base_dir):
			return OK

		var error: Error = DirAccess.make_dir_recursive_absolute(base_dir)
		if error != OK:
			push_error("[GFStorageUtility] 无法创建目录：%s，错误码：%s" % [base_dir, error])
		return error

	func _write_buffer_absolute(path: String, bytes: PackedByteArray) -> Error:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		_store_buffer_checked(file, bytes)
		var error: Error = file.get_error()
		file.close()
		return error

	func _write_plain_json_absolute(path: String, data: Dictionary) -> Error:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		_store_string_checked(file, JSON.stringify(data, "\t"))
		var error: Error = file.get_error()
		file.close()
		return error

	func _remove_absolute_file_if_exists(path: String) -> void:
		_remove_absolute_if_exists(path)

	func _remove_file_if_exists(path: String) -> void:
		_remove_absolute_if_exists(path)

	func _move_file(from_path: String, to_path: String) -> Error:
		if not FileAccess.file_exists(from_path):
			return ERR_FILE_NOT_FOUND
		return DirAccess.rename_absolute(from_path, to_path)

	func _write_json(file_name: String, data: Dictionary) -> Error:
		var path: String = _path_policy._get_full_path(file_name)
		var dir_error: Error = _ensure_parent_directory(path)
		if dir_error != OK:
			return dir_error
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("[GFStorageUtility] 无法写入文件：%s，错误码：%s" % [path, FileAccess.get_open_error()])
			return FileAccess.get_open_error()

		var codec: GFStorageCodec = _get_codec()
		var codec_options: Dictionary = _get_codec_options()
		var bytes: PackedByteArray = codec.encode(data, codec_options)
		_store_buffer_checked(file, bytes)
		var write_error: Error = file.get_error()
		file.close()
		if write_error != OK:
			push_error("[GFStorageUtility] 写入文件失败：%s，错误码：%s" % [path, write_error])
		return write_error

	func _write_plain_json(file_name: String, data: Dictionary) -> Error:
		var path: String = _path_policy._get_full_path(file_name)
		var dir_error: Error = _ensure_parent_directory(path)
		if dir_error != OK:
			return dir_error
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("[GFStorageUtility] 无法写入文件：%s，错误码：%s" % [path, FileAccess.get_open_error()])
			return FileAccess.get_open_error()

		_store_string_checked(file, JSON.stringify(data, "\t"))
		var write_error: Error = file.get_error()
		file.close()
		if write_error != OK:
			push_error("[GFStorageUtility] 写入文件失败：%s，错误码：%s" % [path, write_error])
		return write_error


class _StorageTransactionManager:
	const _TEMP_SUFFIX: String = ".tmp"
	const _BACKUP_SUFFIX: String = ".bak"
	const _TRANSACTION_SUFFIX: String = ".txn"
	const _MARKER_SCHEMA_VERSION: int = 1
	const _MAX_TRANSACTION_FILES: int = 64

	var _owner: Object
	var _path_policy: _StoragePathPolicy
	var _file_ops: _StorageFileOps
	var _next_transaction_id: int = 1

	func _init(p_owner: Object, p_path_policy: _StoragePathPolicy, p_file_ops: _StorageFileOps) -> void:
		_owner = p_owner
		_path_policy = p_path_policy
		_file_ops = p_file_ops

	func _dispose() -> void:
		_owner = null
		_path_policy = null
		_file_ops = null

	func _get_temp_filename(file_name: String) -> String:
		return file_name + _TEMP_SUFFIX

	func _get_backup_filename(file_name: String) -> String:
		return file_name + _BACKUP_SUFFIX

	func _get_transaction_filename(file_name: String) -> String:
		return file_name + _TRANSACTION_SUFFIX

	func _cleanup_transaction_files(file_names: Array[String]) -> void:
		file_names = _unique_file_names(file_names)
		for file_name: String in file_names:
			_file_ops._remove_file_if_exists(_path_policy._get_full_path(_get_temp_filename(file_name)))
			_file_ops._remove_file_if_exists(_path_policy._get_full_path(_get_backup_filename(file_name)))
			_file_ops._remove_file_if_exists(_path_policy._get_full_path(_get_transaction_filename(file_name)))

	func _recover_transaction_files(file_names: Array[String]) -> void:
		file_names = _unique_file_names(file_names)
		var recovered_files: Dictionary = {}
		for file_name: String in file_names:
			var marker: Dictionary = _read_transaction_marker(file_name)
			if marker.is_empty():
				continue

			var transaction_files: Array[String] = _discover_transaction_marker_files(marker, file_name)
			_recover_transaction_group(transaction_files)
			for transaction_file_name: String in transaction_files:
				recovered_files[transaction_file_name] = true

		for file_name: String in file_names:
			if not recovered_files.has(file_name):
				_recover_transaction_file(file_name)

	func _recover_transaction_group(file_names: Array[String]) -> void:
		file_names = _unique_file_names(file_names)
		if file_names.is_empty():
			return

		var should_keep_new_files: bool = _is_transaction_group_committed(file_names)
		if should_keep_new_files:
			for file_name: String in file_names:
				var final_path: String = _path_policy._get_full_path(file_name)
				var temp_path: String = _path_policy._get_full_path(_get_temp_filename(file_name))
				if not FileAccess.file_exists(final_path) and FileAccess.file_exists(temp_path):
					var promote_error: Error = _file_ops._move_file(temp_path, final_path)
					if promote_error != OK:
						push_error("[GFStorageUtility] 恢复已提交事务文件失败：%s，错误码：%s" % [final_path, promote_error])
						continue
				_file_ops._remove_file_if_exists(temp_path)
				_file_ops._remove_file_if_exists(_path_policy._get_full_path(_get_backup_filename(file_name)))
				_file_ops._remove_file_if_exists(_path_policy._get_full_path(_get_transaction_filename(file_name)))
			return

		for file_name: String in file_names:
			var marker: Dictionary = _read_transaction_marker(file_name)
			var final_path: String = _path_policy._get_full_path(file_name)
			var temp_path: String = _path_policy._get_full_path(_get_temp_filename(file_name))
			var backup_path: String = _path_policy._get_full_path(_get_backup_filename(file_name))
			var had_final: bool = GFVariantData.get_option_bool(marker, "had_final", true)

			if FileAccess.file_exists(backup_path):
				_file_ops._remove_file_if_exists(final_path)
				var restore_error: Error = _file_ops._move_file(backup_path, final_path)
				if restore_error != OK:
					push_error("[GFStorageUtility] 回滚事务文件失败：%s，错误码：%s" % [final_path, restore_error])
			elif not had_final:
				_file_ops._remove_file_if_exists(final_path)

			_file_ops._remove_file_if_exists(temp_path)
			_file_ops._remove_file_if_exists(_path_policy._get_full_path(_get_transaction_filename(file_name)))

	func _recover_transaction_file(file_name: String) -> void:
		var final_path: String = _path_policy._get_full_path(file_name)
		var temp_path: String = _path_policy._get_full_path(_get_temp_filename(file_name))
		var backup_path: String = _path_policy._get_full_path(_get_backup_filename(file_name))
		var has_final: bool = FileAccess.file_exists(final_path)
		var has_temp: bool = FileAccess.file_exists(temp_path)
		var has_backup: bool = FileAccess.file_exists(backup_path)

		if has_backup and (not has_final or has_temp):
			if has_final:
				_file_ops._remove_file_if_exists(final_path)

			var restore_error: Error = _file_ops._move_file(backup_path, final_path)
			if restore_error != OK:
				push_error("[GFStorageUtility] 恢复备份文件失败：%s，错误码：%s" % [final_path, restore_error])
				return

			_file_ops._remove_file_if_exists(temp_path)
			return

		if has_backup and has_final:
			_file_ops._remove_file_if_exists(backup_path)
			has_backup = false

		if has_temp and not has_final and not has_backup:
			var promote_error: Error = _file_ops._move_file(temp_path, final_path)
			if promote_error != OK:
				push_error("[GFStorageUtility] 恢复临时文件失败：%s，错误码：%s" % [final_path, promote_error])
			return

		if has_temp and has_final:
			_file_ops._remove_file_if_exists(temp_path)

	func _commit_transaction(file_names: Array[String], markers_prepared: bool = false) -> Error:
		file_names = _unique_file_names(file_names)
		if file_names.is_empty():
			return ERR_INVALID_PARAMETER
		if markers_prepared:
			if not _is_transaction_group_in_state(file_names, false):
				_cleanup_transaction_files(file_names)
				return ERR_INVALID_DATA
		else:
			var marker_error: Error = _write_transaction_markers(file_names, false)
			if marker_error != OK:
				_cleanup_transaction_files(file_names)
				return marker_error

		var transaction_state: Dictionary = {}
		for file_name: String in file_names:
			transaction_state[file_name] = {
				"backed_up": false,
				"committed": false,
			}

		for file_name: String in file_names:
			var backup_path: String = _path_policy._get_full_path(_get_backup_filename(file_name))
			var final_path: String = _path_policy._get_full_path(file_name)
			if FileAccess.file_exists(final_path):
				var backup_error: Error = _file_ops._move_file(final_path, backup_path)
				if backup_error != OK:
					_rollback_transaction(file_names, transaction_state)
					return backup_error
				transaction_state[file_name]["backed_up"] = true

		for file_name: String in file_names:
			var temp_path: String = _path_policy._get_full_path(_get_temp_filename(file_name))
			var final_path: String = _path_policy._get_full_path(file_name)
			var commit_error: Error = _file_ops._move_file(temp_path, final_path)
			if commit_error != OK:
				_rollback_transaction(file_names, transaction_state)
				_cleanup_transaction_markers(file_names)
				return commit_error
			transaction_state[file_name]["committed"] = true

		var complete_marker_error: Error = _write_transaction_markers(file_names, true)
		if complete_marker_error != OK:
			_rollback_transaction(file_names, transaction_state)
			_cleanup_transaction_markers(file_names)
			return complete_marker_error

		for file_name: String in file_names:
			_file_ops._remove_file_if_exists(_path_policy._get_full_path(_get_backup_filename(file_name)))
			_file_ops._remove_file_if_exists(_path_policy._get_full_path(_get_transaction_filename(file_name)))

		return OK

	func _rollback_transaction(file_names: Array[String], transaction_state: Dictionary) -> void:
		for file_name: String in file_names:
			var final_path: String = _path_policy._get_full_path(file_name)
			var temp_path: String = _path_policy._get_full_path(_get_temp_filename(file_name))
			var backup_path: String = _path_policy._get_full_path(_get_backup_filename(file_name))
			var state: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(transaction_state, file_name, {}))
			var committed: bool = GFVariantData.get_option_bool(state, "committed", false)
			var backed_up: bool = GFVariantData.get_option_bool(state, "backed_up", false)

			if committed or backed_up:
				_file_ops._remove_file_if_exists(final_path)
			_file_ops._remove_file_if_exists(temp_path)

			if backed_up and FileAccess.file_exists(backup_path):
				var restore_error: Error = _file_ops._move_file(backup_path, final_path)
				if restore_error != OK:
					push_error("[GFStorageUtility] 回滚文件失败：%s，错误码：%s" % [final_path, restore_error])

	func _write_transaction_markers(file_names: Array[String], committed: bool) -> Error:
		file_names = _unique_file_names(file_names)
		if file_names.is_empty() or file_names.size() > _MAX_TRANSACTION_FILES:
			return ERR_INVALID_PARAMETER
		var transaction_id: String = ""
		if committed:
			var first_marker: Dictionary = _read_transaction_marker(file_names[0])
			transaction_id = GFVariantData.get_option_string(first_marker, "transaction_id")
		if transaction_id.is_empty():
			transaction_id = "%d:%d" % [Time.get_ticks_usec(), _next_transaction_id]
			_next_transaction_id += 1
		for file_name: String in file_names:
			var existing_marker: Dictionary = _read_transaction_marker(file_name)
			var had_final: bool = GFVariantData.get_option_bool(
				existing_marker,
				"had_final",
				FileAccess.file_exists(_path_policy._get_full_path(file_name))
			)
			var marker: Dictionary = {
				"schema_version": _MARKER_SCHEMA_VERSION,
				"transaction_id": transaction_id,
				"file_key": file_name,
				"files": file_names,
				"committed": committed,
				"had_final": had_final,
			}
			var error: Error = _file_ops._write_plain_json(_get_transaction_filename(file_name), marker)
			if error != OK:
				return error
		return OK

	func _cleanup_transaction_markers(file_names: Array[String]) -> void:
		for file_name: String in file_names:
			_file_ops._remove_file_if_exists(_path_policy._get_full_path(_get_transaction_filename(file_name)))

	func _read_transaction_marker(file_name: String) -> Dictionary:
		var path: String = _path_policy._get_full_path(_get_transaction_filename(file_name))
		if not FileAccess.file_exists(path):
			return {}

		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("[GFStorageUtility] 无法读取事务标记：%s，错误码：%s" % [path, FileAccess.get_open_error()])
			return {}

		var content: String = file.get_as_text()
		file.close()
		var parsed: Variant = JSON.parse_string(content)
		if parsed is Dictionary:
			return GFVariantData.as_dictionary(parsed)
		push_warning("[GFStorageUtility] 事务标记格式无效，将按单文件恢复处理：%s" % path)
		return {}

	func _get_transaction_marker_files(
		marker: Dictionary,
		fallback_file_name: String,
		allowed_file_names: Array[String] = []
	) -> Array[String]:
		fallback_file_name = _canonicalize_marker_file_name(fallback_file_name)
		if fallback_file_name.is_empty():
			return []
		var fallback_result: Array[String] = [fallback_file_name]
		if (
			GFVariantData.get_option_int(marker, "schema_version", -1) != _MARKER_SCHEMA_VERSION
			or GFVariantData.get_option_string(marker, "transaction_id").is_empty()
			or _canonicalize_marker_file_name(GFVariantData.get_option_string(marker, "file_key")) != fallback_file_name
		):
			return fallback_result
		var allowed_keys: Dictionary = {}
		var canonical_allowed_file_names: Array[String] = _unique_file_names(allowed_file_names)
		if canonical_allowed_file_names.is_empty():
			canonical_allowed_file_names.append(fallback_file_name)
		for allowed_file_name: String in canonical_allowed_file_names:
			allowed_keys[allowed_file_name] = true
		var result: Array[String] = []
		var raw_files: Variant = GFVariantData.get_option_value(marker, "files", [])
		if raw_files is Array:
			for raw_file: Variant in raw_files:
				var file_name: String = _canonicalize_marker_file_name(GFVariantData.to_text(raw_file))
				if file_name.is_empty() or not allowed_keys.has(file_name):
					return fallback_result
				if not result.has(file_name):
					result.append(file_name)
				if result.size() > _MAX_TRANSACTION_FILES:
					return fallback_result

		if result.is_empty() or not result.has(fallback_file_name):
			return fallback_result
		return result

	func _discover_transaction_marker_files(marker: Dictionary, fallback_file_name: String) -> Array[String]:
		fallback_file_name = _canonicalize_marker_file_name(fallback_file_name)
		if fallback_file_name.is_empty():
			return []
		var fallback_result: Array[String] = [fallback_file_name]
		var raw_files: Variant = GFVariantData.get_option_value(marker, "files", [])
		if not (raw_files is Array):
			return fallback_result
		var declared_files: Array[String] = []
		for raw_file: Variant in raw_files:
			var file_name: String = _canonicalize_marker_file_name(GFVariantData.to_text(raw_file))
			if file_name.is_empty() or declared_files.has(file_name):
				return fallback_result
			declared_files.append(file_name)
			if declared_files.size() > _MAX_TRANSACTION_FILES:
				return fallback_result
		if declared_files.is_empty() or not declared_files.has(fallback_file_name):
			return fallback_result

		var transaction_id: String = GFVariantData.get_option_string(marker, "transaction_id")
		if transaction_id.is_empty():
			return fallback_result
		for file_name: String in declared_files:
			var member_marker: Dictionary = marker if file_name == fallback_file_name else _read_transaction_marker(file_name)
			if (
				member_marker.is_empty()
				or GFVariantData.get_option_string(member_marker, "transaction_id") != transaction_id
				or _get_transaction_marker_files(member_marker, file_name, declared_files) != declared_files
			):
				return fallback_result
		return declared_files

	func _is_transaction_group_committed(file_names: Array[String]) -> bool:
		return _is_transaction_group_in_state(file_names, true)

	func _is_transaction_group_in_state(file_names: Array[String], committed: bool) -> bool:
		file_names = _unique_file_names(file_names)
		if file_names.is_empty():
			return false
		var transaction_id: String = ""
		for file_name: String in file_names:
			var marker: Dictionary = _read_transaction_marker(file_name)
			var marker_files: Array[String] = _get_transaction_marker_files(marker, file_name, file_names)
			var marker_transaction_id: String = GFVariantData.get_option_string(marker, "transaction_id")
			if (
				marker.is_empty()
				or GFVariantData.get_option_bool(marker, "committed", false) != committed
				or marker_files != file_names
				or marker_transaction_id.is_empty()
			):
				return false
			if transaction_id.is_empty():
				transaction_id = marker_transaction_id
			elif transaction_id != marker_transaction_id:
				return false
		return true

	func _unique_file_names(file_names: Array[String]) -> Array[String]:
		var result: Array[String] = []
		for raw_file_name: String in file_names:
			var file_name: String = _path_policy._canonicalize_file_name(raw_file_name, "file_name")
			if not file_name.is_empty() and not result.has(file_name):
				result.append(file_name)
		return result

	func _canonicalize_marker_file_name(file_name: String) -> String:
		if file_name.is_empty():
			return ""
		if file_name.is_absolute_path():
			return file_name.replace("\\", "/").simplify_path()
		if _path_policy._contains_parent_segment(file_name):
			return ""
		var normalized: String = file_name.replace("\\", "/").simplify_path()
		if normalized.is_empty() or normalized == "." or normalized == "..":
			return ""
		return normalized
