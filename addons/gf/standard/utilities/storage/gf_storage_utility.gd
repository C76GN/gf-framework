## GFStorageUtility: 基于 `user://` 的轻量存档系统。
##
## 支持槽位存档、元数据分离读取、`Resource` 存取，
## 以及可配置 codec、完整性校验、版本迁移和简单混淆，适合通用本地持久化场景。
## 所有公开文件与目录入口只接受当前 Storage root 内的规范相对路径；运行时不提供
## 任意绝对路径能力，需要访问外部路径的可信编辑器工具应直接使用其自有 FileAccess 边界。
## 这是 GF API 的词法路径与所有权边界，不是抵御同进程 FileAccess、宿主链接或挂载点的文件系统沙箱。
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


# --- 枚举 ---

## 异步 Storage 请求的执行模式。
## [br]
## @api public
## [br]
## @since 11.0.0
enum AsyncExecutionMode {
	## 自动选择；无线程能力的构建使用 cooperative，否则使用线程。
	AUTOMATIC = 0,
	## 强制使用线程；无线程能力时 activation 确定性失败。
	THREADED = 1,
	## 由 lifecycle tick 在主线程逐项推进，不创建 Thread。
	COOPERATIVE = 2,
}

enum _AsyncTaskState {
	QUEUED,
	ACCEPTED,
	RUNNING,
	SETTLING,
}


# --- 常量 ---

const _GF_STORAGE_FAMILY_STORE_SCRIPT = preload(
	"res://addons/gf/standard/utilities/storage/gf_storage_family_store.gd"
)
const _TRANSACTION_PREPARE_SCHEMA: String = "gf.storage.transaction-prepare"
const _TRANSACTION_COMMIT_SCHEMA: String = "gf.storage.transaction-commit"
const _TRANSACTION_MARKER_SCHEMA_VERSION: int = 2
const _MAX_TRANSACTION_FILES: int = 64
const _PAYLOAD_VALIDATION_MAX_DEPTH: int = 128
const _PAYLOAD_VALIDATION_MAX_VALUES: int = 1_000_000
const _PAYLOAD_VALIDATION_MAX_BYTES: int = 64 * 1024 * 1024
const _ASYNC_LATE_SETTLEMENT_CAPACITY: int = 64
const _DELETE_MEMBER_BACKUP: StringName = &"backup"
const _DELETE_MEMBER_TRANSACTION_PREPARE_PENDING: StringName = &"transaction_prepare_pending"
const _DELETE_MEMBER_TRANSACTION_PREPARE: StringName = &"transaction_prepare"
const _DELETE_MEMBER_TRANSACTION_COMMIT_PENDING: StringName = &"transaction_commit_pending"
const _DELETE_MEMBER_TRANSACTION_COMMIT: StringName = &"transaction_commit"
const _DELETE_MEMBER_CANDIDATE: StringName = &"candidate"
const _DELETE_MEMBER_RESOURCE_STAGE: StringName = &"resource_stage"
const _DELETE_MEMBER_FINAL: StringName = &"final"
const _RESET_MEMBER_CATALOG: StringName = &"catalog"
const _RESET_MEMBER_FAMILY_CONTAINER: StringName = &"family_container"
const _RESET_MEMBER_INTENT: StringName = &"reset_intent"
const _RESET_INTENT_SCHEMA: String = "gf.storage.family-reset-intent"
const _RESET_INTENT_SCHEMA_VERSION: int = 1
const _RESET_STAGING_SEPARATOR: String = ".reset-"
const _RESET_INTENT_SUFFIX: String = ".intent.json"
const _RESET_MAX_INTENT_BYTES: int = 16 * 1024
const _RESET_MAX_TREE_DEPTH: int = 16
const _RESET_MAX_TREE_ENTRIES: int = 1024
const _RESET_MAX_REVERSE_SCAN_ENTRIES: int = 16 * 1024
const _RESET_MAX_SHARD_ENTRIES: int = 256
const _RESET_MAX_PENDING_INTENTS: int = 1024

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

## Storage root 的 portable logical 目录名；为空时使用 `user://`。
## 首次 activation、显式 `init()` 或合法 I/O 尝试后冻结；非法配置失败关闭。
## [br]
## @api public
## [br]
## @since 3.17.0
var save_dir_name: String = "saves":
	set(value):
		var _root_changed: bool = value != save_dir_name
		if _storage_root_frozen and _root_changed:
			push_error("[GFStorageUtility] save_dir_name 已在 Storage 初始化后冻结；请为另一个 root 创建新的 Utility。")
			return
		save_dir_name = value
		if _family_store != null:
			var _storage_root_path: String = GFStorageFamilyStore.make_storage_root_path_for_framework(
				value
			)
			if not _storage_root_path.is_empty():
				var _configured: bool = _family_store.configure_for_framework(_storage_root_path)
				if _root_changed:
					_storage_reconciled = false

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

## 异步 Storage 请求的执行模式。首个合法异步请求入队后冻结。
## [br]
## @api public
## [br]
## @since 11.0.0
var async_execution_mode: AsyncExecutionMode = AsyncExecutionMode.AUTOMATIC:
	set(value):
		if value == async_execution_mode:
			return
		if not AsyncExecutionMode.values().has(value):
			push_error("[GFStorageUtility] async_execution_mode 不属于闭合枚举。")
			return
		if _async_execution_mode_frozen:
			push_error("[GFStorageUtility] async_execution_mode 已在首个异步请求后冻结。")
			return
		async_execution_mode = value

## 线程模式同时运行的异步存取线程数量，小于 1 时会被钳制为 1。
## cooperative 模式固定每个 lifecycle tick 最多执行一个任务。
## [br]
## @api public
## [br]
## @since 3.17.0
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
var _async_settling_records: Dictionary = {}
var _async_observers: Dictionary = {}
var _async_late_settlements: Array[Dictionary] = []
var _clock: GFClock = GFClock.new()
var _next_async_request_id: int = 1
var _next_async_consumer_id: int = 1
var _next_async_record_id: int = 1
var _next_async_transaction_id: int = 1
var _next_family_reset_authorization_id: int = 1
var _async_scheduler_running: bool = false
var _async_scheduler_requested: bool = false
var _async_start_only_running: bool = false
var _async_start_only_requested: bool = false
var _async_completion_depth: int = 0
var _async_execution_depth: int = 0
var _async_deferred_dispose_requested: bool = false
var _async_execution_mode_frozen: bool = false
var _effective_async_execution_mode: AsyncExecutionMode = AsyncExecutionMode.AUTOMATIC
var _is_disposing: bool = false
var _io_admission_open: bool = true
var _quiesce_completion: GFAsyncCompletion = null
var _migration_steps: Dictionary = {}
var _path_policy: _StoragePathPolicy
var _file_ops: _StorageFileOps
var _family_store: GFStorageFamilyStore
var _transaction_manager: _StorageTransactionManager
var _read_result_origin_token: String = ""
var _storage_root_frozen: bool = false
var _storage_reconciled: bool = false


# --- Godot 生命周期方法 ---

func _init() -> void:
	_read_result_origin_token = GFUuid.generate_v4()
	_ensure_storage_helpers()


# --- GF 生命周期方法 ---

## 初始化存储目录和内部帮助器。
## [br]
## @api public
func init() -> void:
	if not _io_admission_open:
		return
	ignore_pause = true
	var layout_error: Error = _ensure_storage_ready()
	if layout_error != OK:
		push_error("[GFStorageUtility] 无法初始化私有 Storage layout，错误码：%s" % layout_error)


## 等待并清理异步存取任务。
## [br]
## @api public
func dispose() -> void:
	if _is_disposing:
		return
	_io_admission_open = false
	if _async_completion_depth > 0 or _async_execution_depth > 0:
		_async_deferred_dispose_requested = true
		return
	_async_deferred_dispose_requested = false
	_is_disposing = true
	_wait_for_async_tasks()
	_async_tasks.clear()
	_async_queue.clear()
	_async_file_locks.clear()
	_async_settling_records.clear()
	_async_observers.clear()
	_async_scheduler_requested = false
	_async_start_only_requested = false
	_migration_steps.clear()
	_storage_reconciled = false
	last_load_result = null
	_release_storage_helpers()
	_is_disposing = false
	_async_deferred_dispose_requested = false
	_try_complete_quiesce()


## 驱动异步存档任务完成检查；cooperative 模式还会在主线程执行至多一个完整 I/O。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _delta: 本帧时间增量（秒），默认实现不直接使用。
func tick(_delta: float = 0.0) -> void:
	_poll_async_tasks()
	_try_complete_quiesce()


## 激活 Storage 的同步与异步 I/O 准入。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param _scope: 当前 Storage 激活阶段的取消作用域。
## [br]
## 强制线程模式缺少 `threads` 能力时，失败 metadata.error_code 为 ERR_CANT_CREATE。
## [br]
## @return 成功打开 I/O 准入；否则返回失败终态。
func begin_activation(_scope: GFAsyncScope) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	if _is_disposing or _async_deferred_dispose_requested:
		var _failed: bool = completion.fail("Storage utility is disposing.")
		return completion
	if _quiesce_completion != null:
		var _failed_quiesced: bool = completion.fail(
			"Storage utility cannot reactivate after quiesce."
		)
		return completion
	if (
		_get_effective_async_execution_mode() == AsyncExecutionMode.THREADED
		and not has_async_thread_capability_for_framework()
	):
		_io_admission_open = false
		var _failed_capability: bool = completion.fail(
			"Storage threaded execution is unavailable on this runtime.",
			{"error_code": ERR_CANT_CREATE}
		)
		return completion
	_quiesce_completion = null
	_io_admission_open = true
	ignore_pause = true
	_storage_reconciled = false
	var readiness_error: Error = _ensure_storage_ready()
	if readiness_error != OK:
		_io_admission_open = false
		var _failed_readiness: bool = completion.fail(
			"Storage private layout could not be activated.",
			{"error_code": readiness_error}
		)
		return completion
	var _succeeded: bool = completion.succeed()
	return completion


## 关闭新 I/O 准入，并等待此前接纳的队列、执行任务和文件锁全部收敛。
##
## 已接纳任务继续由 lifecycle tick 推进；强制 dispose 仍会使用同步 join fallback。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param scope: 当前 Storage 静默阶段的取消作用域。
## [br]
## @return 队列、任务和锁全部终态后成功的一次性完成源。
func begin_quiesce(scope: GFAsyncScope) -> GFAsyncCompletion:
	_io_admission_open = false
	if _quiesce_completion != null:
		return _quiesce_completion
	_quiesce_completion = GFAsyncCompletion.new()
	if scope != null:
		var _bound: bool = _quiesce_completion.bind_cancel_token(scope)
	_try_complete_quiesce()
	return _quiesce_completion


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
	if not _io_admission_open:
		return ERR_UNAVAILABLE
	if not _validate_public_resource_file_name(file_name, "save_resource"):
		return ERR_INVALID_PARAMETER
	if resource == null:
		push_error("[GFStorageUtility] save_resource 失败：resource 为空。")
		return ERR_INVALID_PARAMETER

	init()
	if not _wait_for_async_tasks_for_file(file_name):
		return ERR_BUSY
	if not _is_sync_io_admission_current():
		return ERR_UNAVAILABLE
	var prepare_error: Error = _prepare_family_for_write(file_name)
	if prepare_error != OK:
		return prepare_error
	var marker_error: Error = _write_transaction_markers([file_name], false)
	if marker_error != OK:
		return marker_error

	var descriptor: Dictionary = _make_family_descriptor(file_name)
	var temp_path: String = GFVariantData.get_option_string(descriptor, "candidate_path")
	var resource_temp_path: String = GFVariantData.get_option_string(
		descriptor,
		"resource_stage_path"
	)
	var remove_stage_error: Error = _remove_absolute_file(resource_temp_path)
	if remove_stage_error != OK:
		var cleanup_error: Error = _cleanup_transaction_files([file_name])
		return remove_stage_error if cleanup_error == OK else cleanup_error
	var dir_error: Error = _ensure_parent_directory(temp_path)
	if dir_error != OK:
		var cleanup_error: Error = _cleanup_transaction_files([file_name])
		return dir_error if cleanup_error == OK else cleanup_error
	var save_error: Error = ResourceSaver.save(resource, resource_temp_path)
	if save_error != OK:
		_remove_file_if_exists(resource_temp_path)
		var cleanup_error: Error = _cleanup_transaction_files([file_name])
		return save_error if cleanup_error == OK else cleanup_error
	var copy_error: Error = _copy_file_bytes(resource_temp_path, temp_path)
	_remove_file_if_exists(resource_temp_path)
	if copy_error != OK:
		var cleanup_error: Error = _cleanup_transaction_files([file_name])
		return copy_error if cleanup_error == OK else cleanup_error
	return _commit_transaction([file_name], true)


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
	if not _io_admission_open:
		return null
	if not _validate_public_resource_file_name(file_name, "load_resource"):
		return null
	if not allow_resource_loads:
		push_error("[GFStorageUtility] load_resource 已被默认安全策略拒绝：请先显式启用 allow_resource_loads。")
		return null

	init()
	if not _wait_for_async_tasks_for_file(file_name):
		return null
	if not _is_sync_io_admission_current():
		return null
	var prepare_error: Error = _prepare_family_for_read(file_name)
	if prepare_error != OK:
		return null

	var path: String = GFVariantData.get_option_string(
		_make_family_descriptor(file_name),
		"payload_path"
	)
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

## 枚举指定存储目录下的文件。
## [br]
## @api public
## [br]
## @since 2.3.0
## [br]
## @param directory_name: 相对存储目录；为空时枚举根存储目录。
## [br]
## @param extension_filter: 可选 canonical lowercase 扩展名过滤，不包含点号。
## [br]
## @param recursive: 是否递归枚举子目录。
## [br]
## @param options: 可选参数，支持 `max_scan_depth` 与 `max_file_count`。
## [br]
## @schema options: Dictionary，包含 max_scan_depth: int 和 max_file_count: int。
## [br]
## @return 从已校验 catalog 投影的 committed portable logical file identity 数组。
func list_files(
	directory_name: String = "",
	extension_filter: String = "",
	recursive: bool = false,
	options: Dictionary = {}
) -> PackedStringArray:
	if not _io_admission_open:
		return PackedStringArray()
	if not _validate_public_directory_name(directory_name, "list_files"):
		return PackedStringArray()
	if not GFStorageFamilyStore.is_valid_extension_filter_for_framework(extension_filter):
		push_error("[GFStorageUtility] list_files 失败：extension_filter 非法。")
		return PackedStringArray()
	var readiness_error: Error = _ensure_storage_ready()
	if readiness_error != OK:
		push_error("[GFStorageUtility] list_files 无法加载 Storage layout，错误码：%s" % readiness_error)
		return PackedStringArray()
	var transaction_manager_at_entry: _StorageTransactionManager = _transaction_manager
	var family_store_at_entry: GFStorageFamilyStore = _family_store
	wait_for_async_tasks()
	if (
		not _io_admission_open
		or not _async_queue.is_empty()
		or not _async_file_locks.is_empty()
		or _transaction_manager != transaction_manager_at_entry
		or _family_store != family_store_at_entry
	):
		return PackedStringArray()
	readiness_error = _ensure_storage_ready()
	if readiness_error != OK:
		push_error("[GFStorageUtility] list_files 无法收敛 Storage 恢复，错误码：%s" % readiness_error)
		return PackedStringArray()
	var recovery_error: Error = _transaction_manager._recover_all_catalog_transactions()
	if recovery_error != OK:
		_storage_reconciled = false
		push_error("[GFStorageUtility] list_files 无法收敛 Storage 事务，错误码：%s" % recovery_error)
		return PackedStringArray()
	_storage_reconciled = true
	var max_scan_depth: int = maxi(GFVariantData.get_option_int(options, "max_scan_depth", DEFAULT_MAX_LIST_DEPTH), 0)
	var max_file_count: int = maxi(GFVariantData.get_option_int(options, "max_file_count", DEFAULT_MAX_LISTED_FILES), 0)
	var list_result: Dictionary = _family_store.list_files_for_framework(
		directory_name,
		extension_filter,
		recursive,
		max_scan_depth,
		max_file_count
	)
	var list_error: Error = GFVariantData.get_option_int(list_result, "error", OK) as Error
	if list_error != OK:
		push_error("[GFStorageUtility] list_files 无法读取 logical catalog，错误码：%s" % list_error)
		return PackedStringArray()
	var files_value: Variant = list_result.get("files")
	if files_value is PackedStringArray:
		var files: PackedStringArray = files_value
		return files
	return PackedStringArray()


## 判断一个 logical file 是否存在 committed payload。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param file_name: portable logical file identity。
## [br]
## @return catalog、owner 与 payload 均有效时返回 true。
func has_file(file_name: String) -> bool:
	if not _io_admission_open:
		return false
	if not _validate_public_file_name(file_name, "has_file"):
		return false
	init()
	if not _wait_for_async_tasks_for_file(file_name):
		return false
	if not _is_sync_io_admission_current():
		return false
	if _prepare_family_for_read(file_name) != OK:
		return false
	return _family_store.has_file_for_framework(_make_family_descriptor(file_name))


## 删除一个精确 logical family 的全部可变成员。
##
## 该方法不会扫描或收养 Storage root 下的旧版可见文件；immutable catalog/owner claim 会保留。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param file_name: portable logical file identity。
## [br]
## @return Godot 的 `Error` 结果码；family 未 claim 或没有可变成员时返回 `ERR_FILE_NOT_FOUND`。
func delete_file(file_name: String) -> Error:
	if not _io_admission_open:
		return ERR_UNAVAILABLE
	if not _validate_public_file_name(file_name, "delete_file"):
		return ERR_INVALID_PARAMETER
	var canonical_file_name: String = _canonicalize_storage_file_name(file_name)
	if canonical_file_name.is_empty():
		return ERR_INVALID_PARAMETER
	var target_family: Dictionary = _freeze_async_target_family(canonical_file_name)
	if target_family.is_empty():
		return ERR_INVALID_PARAMETER

	if not _wait_for_async_tasks_for_file(canonical_file_name):
		return ERR_BUSY
	if not _is_sync_io_admission_current():
		return ERR_UNAVAILABLE
	var worker_result: Dictionary = _delete_file_thread(
		GFVariantData.get_option_string(target_family, "storage_root_path"),
		canonical_file_name
	)
	return _make_delete_result_from_worker(worker_result).get_error_code()


## 通过当前 Storage executor 删除一个精确 logical family，并返回请求专属句柄。
##
## 请求只删除冻结 family 的八个可变物理成员；catalog 与 owner identity 保留。
## 删除不会隐式恢复事务，也不会扫描或收养 sibling family。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param file_name: portable logical file identity。
## [br]
## @param options: 可选 caller owner、取消 token 与单调 deadline；null 表示无 caller 生命周期约束。
## [br]
## @return 已配置的 typed 请求句柄；路径或生命周期校验失败时立即进入失败终态。
func delete_file_request_async(
	file_name: String,
	options: GFStorageAsyncRequestOptions = null
) -> GFStorageAsyncOperation:
	var operation: GFStorageAsyncOperation = _make_async_operation(
		GFStorageAsyncOperation.OPERATION_DELETE,
		options
	)
	if operation.is_completed():
		return operation
	var _error: Error = _enqueue_async_delete(
		file_name,
		operation,
		"delete_file_request_async"
	)
	return operation


## 为一次显式的破坏性 family reset 创建绑定授权。
##
## 只有当前 GFStorageUtility 对同一 logical identity 返回的 CORRUPT 读取结果才可
## 创建授权。授权冻结 Utility、Storage root、canonical logical identity 与当前 family 观察，
## 且只能消费一次；签发前或后发生的较新同 family 写入/修复会使旧观察失效。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param file_name: portable logical file identity。
## [br]
## @param observed_result: 调用方已经检查并决定破坏性恢复的 CORRUPT 读取结果。
## [br]
## @return 可用的一次性授权；输入或读取分类不匹配时返回 stale 授权。
func create_family_reset_authorization(
	file_name: String,
	observed_result: GFStorageReadResult
) -> GFStorageFamilyResetAuthorization:
	var authorization: GFStorageFamilyResetAuthorization = (
		GFStorageFamilyResetAuthorization.new()
	)
	if (
		not _io_admission_open
		or observed_result == null
		or observed_result.ok
		or observed_result.error_code == OK
		or observed_result.failure_kind != GFStorageReadResult.FailureKind.CORRUPT
		or not _validate_public_file_name(file_name, "create_family_reset_authorization")
	):
		return authorization
	var canonical_file_name: String = _canonicalize_storage_file_name(file_name)
	if canonical_file_name.is_empty():
		return authorization
	var target_family: Dictionary = _make_async_target_family(canonical_file_name)
	if (
		target_family.is_empty()
		or not observed_result.matches_origin_for_framework(
			get_instance_id(),
			canonical_file_name,
			GFVariantData.get_option_string(target_family, "file_key"),
			_read_result_origin_token
		)
	):
		return authorization
	var observation_token: String = (
		observed_result.get_origin_observation_token_for_framework(
			get_instance_id(),
			canonical_file_name,
			GFVariantData.get_option_string(target_family, "file_key"),
			_read_result_origin_token
		)
	)
	if observation_token.is_empty():
		return authorization
	target_family = _freeze_async_target_family(canonical_file_name)
	if (
		target_family.is_empty()
		or observation_token != _make_family_observation_token(canonical_file_name)
	):
		return authorization
	var authorization_id: int = _next_family_reset_authorization_id
	_next_family_reset_authorization_id += 1
	if _next_family_reset_authorization_id <= 0:
		_next_family_reset_authorization_id = 1
	var _configured: bool = authorization.configure_for_framework(
		authorization_id,
		get_instance_id(),
		canonical_file_name,
		GFVariantData.get_option_string(target_family, "file_key"),
		observation_token,
		GFStorageFamilyResetAuthorization.REASON_CORRUPT
	)
	return authorization


## 同步 retire 并重新 claim 一个显式授权的 logical family。
##
## 该入口与同 family 的异步 save/load/delete/reset 串行。missing target 与 future layout
## 都在零写入前失败；同执行栈仍有该 family 工作时以 ERR_BUSY / UNAVAILABLE 拒绝。
## 结果不暴露任何 private path 或 retirement staging 名称。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param file_name: 必须与 authorization 绑定完全一致的 portable logical identity。
## [br]
## @param authorization: 由 create_family_reset_authorization() 创建的一次性授权。
## [br]
## @return reset/recreate 的不可变 typed 终态。
func reset_file_family(
	file_name: String,
	authorization: GFStorageFamilyResetAuthorization
) -> GFStorageFamilyResetResult:
	if not _io_admission_open:
		return _make_reset_result(
			ERR_UNAVAILABLE,
			GFStorageFamilyResetResult.FailureKind.UNAVAILABLE,
			GFStorageFamilyResetResult.SourceKind.UNKNOWN,
			GFStorageFamilyResetResult.Phase.PREFLIGHT,
			0,
			0,
			0,
			GFStorageFamilyResetResult.FamilyMember.NONE
		)
	if not _validate_public_file_name(file_name, "reset_file_family"):
		return _make_reset_invalid_result()
	var canonical_file_name: String = _canonicalize_storage_file_name(file_name)
	if canonical_file_name.is_empty():
		return _make_reset_invalid_result()
	var target_family: Dictionary = _freeze_async_target_family(canonical_file_name)
	if target_family.is_empty():
		return _make_reset_invalid_result()
	if not _wait_for_async_tasks_for_file(canonical_file_name):
		return _make_reset_result(
			ERR_BUSY,
			GFStorageFamilyResetResult.FailureKind.UNAVAILABLE,
			GFStorageFamilyResetResult.SourceKind.UNKNOWN,
			GFStorageFamilyResetResult.Phase.PREFLIGHT,
			0,
			0,
			0,
			GFStorageFamilyResetResult.FamilyMember.NONE
		)
	if not _is_sync_io_admission_current():
		return _make_reset_result(
			ERR_UNAVAILABLE,
			GFStorageFamilyResetResult.FailureKind.UNAVAILABLE,
			GFStorageFamilyResetResult.SourceKind.UNKNOWN,
			GFStorageFamilyResetResult.Phase.PREFLIGHT,
			0,
			0,
			0,
			GFStorageFamilyResetResult.FamilyMember.NONE
		)
	if not _claim_family_reset_authorization(
		authorization,
		canonical_file_name,
		target_family
	):
		return _make_reset_unauthorized_result()
	return _make_reset_result_from_worker(
		_reset_file_family_thread(
			GFVariantData.get_option_string(target_family, "storage_root_path"),
			canonical_file_name,
			authorization.get_observation_token_for_framework()
		)
	)


## 通过当前 Storage executor 异步 retire 并重新 claim 一个显式授权的 logical family。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param file_name: 必须与 authorization 绑定完全一致的 portable logical identity。
## [br]
## @param authorization: 由 create_family_reset_authorization() 创建的一次性授权。
## [br]
## @param options: 可选 caller owner、取消 token 与单调 deadline。
## [br]
## @return 请求专属句柄；终态通过 GFStorageAsyncResult.get_reset_result() 读取。
func reset_file_family_request_async(
	file_name: String,
	authorization: GFStorageFamilyResetAuthorization,
	options: GFStorageAsyncRequestOptions = null
) -> GFStorageAsyncOperation:
	var operation: GFStorageAsyncOperation = _make_async_operation(
		GFStorageAsyncOperation.OPERATION_RESET,
		options
	)
	if operation.is_completed():
		return operation
	var _error: Error = _enqueue_async_reset(
		file_name,
		authorization,
		operation,
		"reset_file_family_request_async"
	)
	return operation


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
	if not _io_admission_open:
		return ERR_UNAVAILABLE
	if not _validate_public_file_name(file_name, "save_data"):
		return ERR_INVALID_PARAMETER

	init()
	if not _wait_for_async_tasks_for_file(file_name):
		return ERR_BUSY
	if not _is_sync_io_admission_current():
		return ERR_UNAVAILABLE
	var prepare_error: Error = _prepare_family_for_write(file_name)
	if prepare_error != OK:
		return prepare_error
	var marker_error: Error = _write_transaction_markers([file_name], false)
	if marker_error != OK:
		return marker_error

	var temp_file_name: String = _get_temp_filename(file_name)
	var write_error: Error = _write_json(temp_file_name, data)
	if write_error != OK:
		var cleanup_error: Error = _cleanup_transaction_files([file_name])
		return write_error if cleanup_error == OK else cleanup_error

	var commit_error: Error = _commit_transaction([file_name], true)
	return commit_error


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
## @schema files: Dictionary，键必须是未经改写的 String portable logical identity，值为要序列化并保存的 Dictionary 载荷。
func save_data_group(files: Dictionary) -> Error:
	if not _io_admission_open:
		return ERR_UNAVAILABLE
	if files.is_empty():
		push_error("[GFStorageUtility] save_data_group 失败：files 为空。")
		return ERR_INVALID_PARAMETER
	if files.size() > _MAX_TRANSACTION_FILES:
		push_error(
			"[GFStorageUtility] save_data_group 失败：成员数超过上限 %d。"
			% _MAX_TRANSACTION_FILES
		)
		return ERR_INVALID_PARAMETER

	var file_names: Array[String] = []
	var payloads_by_file: Dictionary = {}
	for raw_file_name: Variant in files.keys():
		if not raw_file_name is String:
			push_error("[GFStorageUtility] save_data_group 失败：文件名键必须是 String。")
			return ERR_INVALID_PARAMETER
		var raw_file_name_text: String = raw_file_name
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
	var readiness_error: Error = _ensure_storage_ready()
	if readiness_error != OK:
		return readiness_error
	for file_name: String in file_names:
		if not _wait_for_async_tasks_for_file(file_name):
			return ERR_BUSY
		if not _is_sync_io_admission_current():
			return ERR_UNAVAILABLE
	for file_name: String in file_names:
		var reset_recovery_error: Error = _resume_pending_reset_for_file(
			_get_save_base_path(),
			file_name
		)
		if reset_recovery_error != OK:
			return reset_recovery_error
	for file_name: String in file_names:
		var claim_error: Error = _family_store.claim_family_for_framework(
			_make_family_descriptor(file_name)
		)
		if claim_error != OK:
			return claim_error
	var recovery_error: Error = _recover_transaction_files(file_names)
	if recovery_error != OK:
		return recovery_error
	var marker_error: Error = _write_transaction_markers(file_names, false)
	if marker_error != OK:
		var cleanup_error: Error = _cleanup_transaction_files(file_names)
		return marker_error if cleanup_error == OK else cleanup_error

	for file_name: String in file_names:
		var temp_file_name: String = _get_temp_filename(file_name)
		var write_error: Error = _write_json(temp_file_name, GFVariantData.get_option_dictionary(payloads_by_file, file_name))
		if write_error != OK:
			var cleanup_error: Error = _cleanup_transaction_files(file_names)
			return write_error if cleanup_error == OK else cleanup_error

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
	if not _io_admission_open:
		last_load_result = _make_load_failure(
			"Storage I/O admission is closed.",
			ERR_UNAVAILABLE,
			GFStorageReadResult.FailureKind.UNAVAILABLE
		)
		_bind_read_result_origin(last_load_result, file_name)
		return last_load_result.duplicate_result()
	if not _validate_public_file_name(file_name, "load_data"):
		last_load_result = _make_load_failure(
			"Storage file name is invalid.",
			ERR_INVALID_PARAMETER,
			GFStorageReadResult.FailureKind.INVALID_REQUEST
		)
		return last_load_result.duplicate_result()

	ignore_pause = true
	var readiness_error: Error = _ensure_storage_ready()
	if readiness_error != OK:
		last_load_result = _make_readiness_load_failure_for_target(
			file_name,
			readiness_error
		)
		return last_load_result.duplicate_result()
	if not _wait_for_async_tasks_for_file(file_name):
		last_load_result = _make_load_failure(
			"Storage file is still settling an async result.",
			ERR_BUSY,
			GFStorageReadResult.FailureKind.UNAVAILABLE
		)
		return last_load_result.duplicate_result()
	if not _is_sync_io_admission_current():
		last_load_result = _make_load_failure(
			"Storage I/O admission closed while waiting for async work.",
			ERR_UNAVAILABLE,
			GFStorageReadResult.FailureKind.UNAVAILABLE
		)
		return last_load_result.duplicate_result()
	readiness_error = _ensure_storage_ready()
	if readiness_error != OK:
		last_load_result = _make_readiness_load_failure_for_target(
			file_name,
			readiness_error
		)
		return last_load_result.duplicate_result()
	var prepare_error: Error = _prepare_family_for_read_after_readiness(file_name)
	if prepare_error != OK:
		var failure_kind: GFStorageReadResult.FailureKind = _classify_load_failure(
			prepare_error
		)
		last_load_result = _make_load_failure(
			"File not found" if prepare_error == ERR_FILE_NOT_FOUND else "Storage family unavailable",
			prepare_error,
			failure_kind
		)
		_bind_read_result_origin(last_load_result, file_name)
		return last_load_result.duplicate_result()
	return _read_json(file_name)


## 校验一个已经 canonical 的 portable logical 数据文件名。
##
## 返回值与异步队列的同文件锁使用相同路径规则，可用于建立稳定所有权键。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param file_name: 待校验文件名。
## [br]
## @return 输入本身满足 portable-ascii-v1 时原样返回；不会改写别名，非法时返回空字符串。
func canonicalize_data_file_name(file_name: String) -> String:
	if not _validate_public_file_name(file_name, "canonicalize_data_file_name"):
		return ""
	return _canonicalize_storage_file_name(file_name)


## 通过当前 Storage executor 异步保存纯字典数据。完成后从主线程发出 save_completed。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param file_name: 目标文件名。
## [br]
## @param data: 要保存的字典。
## [br]
## @schema data: Dictionary，要序列化并保存的数据载荷。
## [br]
## @return 请求接纳结果码；成功入队时返回 OK。
func save_data_async(file_name: String, data: Dictionary) -> Error:
	return _enqueue_async_save(file_name, data, null, "save_data_async")


## 通过当前 Storage executor 异步保存纯字典数据，并返回请求专属句柄。
##
## 句柄终态不会与共享 Storage 上同文件的其他请求混淆。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param file_name: 目标文件名。
## [br]
## @param data: 要保存的字典。
## [br]
## @schema data: Dictionary，要序列化并保存的数据载荷。
## [br]
## @param options: 可选 caller owner、取消 token 与单调 deadline；null 表示无 caller 生命周期约束。
## [br]
## @return 已配置的请求句柄；输入无效或启动失败时句柄立即进入失败终态。
func save_data_request_async(
	file_name: String,
	data: Dictionary,
	options: GFStorageAsyncRequestOptions = null
) -> GFStorageAsyncOperation:
	var operation: GFStorageAsyncOperation = _make_async_operation(
		GFStorageAsyncOperation.OPERATION_SAVE,
		options
	)
	if operation.is_completed():
		return operation
	var _error: Error = _enqueue_async_save(file_name, data, operation, "save_data_request_async")
	return operation


## 通过当前 Storage executor 保存由单所有者 transfer 移交的纯 Variant payload。
##
## 路径校验在 claim 前完成；非法路径不会消费 transfer。首次合法请求会冻结当前
## Storage 实例、规范文件名与 codec options。同一 transfer 可在旧 attempt 尚未
## 完成时提交给相同绑定，用于 timeout retry；所有 attempt 只读同一逻辑快照。
## 调用方完成整个重试 generation 后必须显式调用 transfer.release()。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param file_name: 目标文件名。
## [br]
## @param transfer: 已通过 take_ownership() 接收 payload 的 opaque transfer。
## [br]
## @param options: 可选 caller owner、取消 token 与单调 deadline；null 表示无 caller 生命周期约束。
## [br]
## @return 已配置请求句柄；输入无效或启动失败时句柄立即进入失败终态。
func save_payload_request_async(
	file_name: String,
	transfer: GFStoragePayloadTransfer,
	options: GFStorageAsyncRequestOptions = null
) -> GFStorageAsyncOperation:
	var operation: GFStorageAsyncOperation = _make_async_operation(
		GFStorageAsyncOperation.OPERATION_SAVE,
		options
	)
	if operation.is_completed():
		return operation
	var _error: Error = _enqueue_async_payload_save(
		file_name,
		transfer,
		operation,
		"save_payload_request_async"
	)
	return operation


## 通过当前 Storage executor 异步读取纯字典数据。完成后从主线程发出 load_completed。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param file_name: 目标文件名。
## [br]
## @return 请求接纳结果码；成功入队时返回 OK。
func load_data_async(file_name: String) -> Error:
	return _enqueue_async_load(file_name, null, "load_data_async")


## 通过当前 Storage executor 异步读取纯字典数据，并返回请求专属句柄。
##
## 读取终态通过句柄携带 `GFStorageReadResult`，调用方无需监听全局文件名信号。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param file_name: 目标文件名。
## [br]
## @param options: 可选 caller owner、取消 token 与单调 deadline；null 表示无 caller 生命周期约束。
## [br]
## @return 已配置的请求句柄；输入无效或启动失败时句柄立即进入失败终态。
func load_data_request_async(
	file_name: String,
	options: GFStorageAsyncRequestOptions = null
) -> GFStorageAsyncOperation:
	var operation: GFStorageAsyncOperation = _make_async_operation(
		GFStorageAsyncOperation.OPERATION_LOAD,
		options
	)
	if operation.is_completed():
		return operation
	var _error: Error = _enqueue_async_load(file_name, operation, "load_data_request_async")
	return operation


## 获取最近的 late physical settlement 脱敏诊断。
##
## 诊断按物理终态到达顺序保留最近 64 条；不包含读载荷、写 payload、绝对路径或
## family 私有身份。返回值为深复制，调用方修改不会影响 Utility 内部 ring。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 最旧到最新排列的有界 late settlement 诊断副本。
## [br]
## @schema return: Array of exact Dictionary entries with consumer_id, request_id, operation, file_name, caller_status, caller_end_kind, caller_reason, caller_completed_msec, worker_accepted, physical_cancel_requested, settlement_kind, physical_ok, physical_error_code, physical_completed_msec, late_duration_msec, read_failure_kind, write_failure_kind, delete_failure_kind, delete_existing_member_count, delete_removed_member_count, delete_remaining_member_count, delete_failed_member, reset_failure_kind, reset_source_kind, reset_failed_phase, reset_retired_member_count, reset_recreated_member_count, reset_remaining_evidence_count, and reset_failed_member fields.
func get_late_settlement_diagnostics() -> Array[Dictionary]:
	return _async_late_settlements.duplicate(true)


## 等待已经入队和正在执行的异步 save/load/delete/reset 任务全部完成。
## 需要在同一路径上混合同步与异步操作时，可先调用该方法收敛顺序。
## Storage executor 的同步执行栈内会拒绝重入等待，避免等待当前调用栈自身完成。
## [br]
## @api public
## [br]
## @since 3.17.0
func wait_for_async_tasks() -> void:
	if _async_execution_depth > 0:
		push_error(
			"[GFStorageUtility] wait_for_async_tasks 不能在 Storage executor 同步执行栈内重入。"
		)
		return
	while not _async_tasks.is_empty() or not _async_queue.is_empty():
		var scheduler_was_running: bool = _async_scheduler_running
		_request_async_scheduler_run()
		if (
			scheduler_was_running
			and not _is_disposing
			and not _async_deferred_dispose_requested
		):
			_harvest_finished_async_tasks()
			_poll_async_operation_lifecycles()
			if not _is_disposing and not _async_deferred_dispose_requested:
				_start_queued_async_tasks()
		if _async_tasks.is_empty():
			break

		var task: Dictionary = GFVariantData.as_dictionary(_async_tasks.front())
		if task.is_empty():
			break
		_join_async_task(task)
	_try_complete_quiesce()


## 使用已注册步骤迁移存档数据。
## [br]
## @api public
## [br]
## @since 1.19.0
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
	var execution: Dictionary = _execute_registered_migrations(
		data,
		_from_version,
		_to_version
	)
	if not GFVariantData.get_option_bool(execution, "ok", false):
		push_error(
			"[GFStorageUtility] migrate_data 失败：%s" % GFVariantData.get_option_string(
				execution,
				"error",
				"Migration failed."
			)
		)
		return data.duplicate(true)
	var migrated: Dictionary = GFVariantData.get_option_dictionary(execution, "payload")
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


# --- 框架内部方法 ---

## 在不消费授权的情况下复核当前 family 是否仍等于签发 corrupt read 时的观察快照。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param file_name: 必须与 authorization 绑定一致的 canonical logical identity。
## [br]
## @param authorization: 待复核的一次性 reset 授权。
## [br]
## @return 快照、Utility 与 logical identity 都仍精确匹配时返回 true。
func validate_family_reset_authorization_for_framework(
	file_name: String,
	authorization: GFStorageFamilyResetAuthorization
) -> bool:
	if (
		not _io_admission_open
		or authorization == null
		or not authorization.is_available()
		or not _validate_public_file_name(
			file_name,
			"validate_family_reset_authorization_for_framework"
		)
	):
		return false
	var canonical_file_name: String = _canonicalize_storage_file_name(file_name)
	var target_family: Dictionary = _freeze_async_target_family(canonical_file_name)
	if target_family.is_empty():
		return false
	return authorization.validate_for_framework(
		get_instance_id(),
		canonical_file_name,
		GFVariantData.get_option_string(target_family, "file_key"),
		_make_family_observation_token(canonical_file_name)
	)

## 在首个异步请求前替换异步生命周期使用的单调时钟。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param clock: 非空单调时钟。
## [br]
## @return 尚未分配请求且没有排队或活动任务时返回 true。
func set_async_clock_for_framework(clock: GFClock) -> bool:
	if (
		clock == null
		or _next_async_request_id != 1
		or not _async_queue.is_empty()
		or not _async_tasks.is_empty()
	):
		return false
	_clock = clock
	return true


## 查询当前运行时是否具备创建 Storage 异步线程的能力。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @return Godot feature tags 声明 `threads` 时返回 true。
func has_async_thread_capability_for_framework() -> bool:
	return OS.has_feature("threads")


## 启动一个已经完成主线程冻结与校验的 Storage worker。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param task_type: `save`、`load`、`delete` 或 `reset`。
## [br]
## @param thread: 由 Utility 为当前请求独占创建的线程。
## [br]
## @param callback: 只捕获冻结纯数据的 worker Callable。
## [br]
## @return `Thread.start()` 的 Error；参数不合法时返回 `ERR_INVALID_PARAMETER`。
func start_async_worker_for_framework(
	task_type: StringName,
	thread: Thread,
	callback: Callable
) -> Error:
	if (
		thread == null
		or not callback.is_valid()
		or task_type not in [&"save", &"load", &"delete", &"reset"]
	):
		return ERR_INVALID_PARAMETER
	return thread.start(callback)


## 由请求句柄在线性化点提交 caller 取消、deadline 或 owner 释放。
##
## 尚未接纳的记录会被精确移出队列并形成真实的接纳前取消物理终态；已接纳记录
## 只结束 caller 观察，执行任务、slot 与同文件锁继续保留到 executor work 退出。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param operation: 发起请求的同一 consumer operation。
## [br]
## @param end_kind: `GFStorageAsyncCallerResult.EndKind` 的稳定终结分类。
## [br]
## @param reason: 有界稳定原因。
## [br]
## @return 本次调用首次线性化 caller 终态时返回 true。
func request_async_operation_cancel_for_framework(
	operation: GFStorageAsyncOperation,
	end_kind: int,
	reason: StringName
) -> bool:
	if not Thread.is_main_thread() or operation == null or not operation.is_caller_pending():
		return false
	if not GFStorageAsyncCallerResult.EndKind.values().has(end_kind):
		return false
	var observer: Dictionary = _get_async_observer(operation)
	if (
		observer.is_empty()
		or _get_observer_operation(observer) != operation
		or GFVariantData.get_option_int(observer, "consumer_id", 0)
			!= operation.get_consumer_id()
	):
		return false

	var record_id: int = GFVariantData.get_option_int(observer, "record_id", 0)
	var active_index: int = _find_active_async_task_index(record_id)
	if active_index >= 0:
		var active_task: Dictionary = GFVariantData.as_dictionary(_async_tasks[active_index])
		var active_thread: Thread = _get_task_thread(active_task)
		if active_thread != null and not active_thread.is_alive():
			_join_async_task(active_task)
			return false
		var caller_status: GFStorageAsyncCallerResult.Status = (
			GFStorageAsyncCallerResult.Status.CANCELLED
			if operation.get_operation() == GFStorageAsyncOperation.OPERATION_LOAD
			else GFStorageAsyncCallerResult.Status.OUTCOME_UNKNOWN
		)
		return operation.complete_caller_for_framework(
			caller_status,
			end_kind as GFStorageAsyncCallerResult.EndKind,
			reason,
			end_kind != GFStorageAsyncCallerResult.EndKind.OWNER_RELEASED
		)
	if _async_settling_records.has(record_id):
		return false

	var queued_index: int = _find_queued_async_task_index(record_id)
	var queued_task: Dictionary = {}
	if queued_index >= 0:
		queued_task = GFVariantData.as_dictionary(_async_queue[queued_index])
	return _complete_cancelled_before_acceptance(
		operation,
		queued_task,
		end_kind as GFStorageAsyncCallerResult.EndKind,
		reason,
		end_kind != GFStorageAsyncCallerResult.EndKind.OWNER_RELEASED
	)


## 删除一个冻结 delete family 的精确物理成员。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param member_kind: 八个冻结 delete stage kind 之一。
## [br]
## @param path: 已由 exact descriptor 派生的私有绝对成员路径。
## [br]
## @return 删除成功或成员已不存在时返回 `OK`。
func remove_delete_family_member_for_framework(
	member_kind: StringName,
	path: String
) -> Error:
	if (
		path.is_empty()
		or member_kind not in [
			_DELETE_MEMBER_BACKUP,
			_DELETE_MEMBER_TRANSACTION_PREPARE_PENDING,
			_DELETE_MEMBER_TRANSACTION_PREPARE,
			_DELETE_MEMBER_TRANSACTION_COMMIT_PENDING,
			_DELETE_MEMBER_TRANSACTION_COMMIT,
			_DELETE_MEMBER_CANDIDATE,
			_DELETE_MEMBER_RESOURCE_STAGE,
			_DELETE_MEMBER_FINAL,
		]
	):
		return ERR_INVALID_PARAMETER
	return _remove_absolute_file(path)


## 原子移动一个由 exact reset descriptor 派生的 identity root。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param member_kind: catalog 或 family_container。
## [br]
## @param source_path: exact 或 retirement identity root。
## [br]
## @param target_path: 同一 identity 的对应 retirement 或 rollback 位置。
## [br]
## @return 原子 rename 的 Error；参数无效时返回 ERR_INVALID_PARAMETER。
func move_reset_family_member_for_framework(
	member_kind: StringName,
	source_path: String,
	target_path: String
) -> Error:
	if (
		member_kind not in [_RESET_MEMBER_CATALOG, _RESET_MEMBER_FAMILY_CONTAINER]
		or source_path.is_empty()
		or target_path.is_empty()
		or source_path == target_path
		or _absolute_storage_leaf_exists(target_path)
	):
		return ERR_INVALID_PARAMETER
	if not _absolute_storage_leaf_exists(source_path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.rename_absolute(source_path, target_path)


## 删除一个 exact reset intent 或 retirement identity root。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param member_kind: catalog、family_container 或 reset_intent。
## [br]
## @param path: 已由 exact descriptor 与 reset ID 派生的私有绝对路径。
## [br]
## @return 删除成功或成员已不存在时返回 OK。
func remove_reset_family_member_for_framework(
	member_kind: StringName,
	path: String
) -> Error:
	if (
		path.is_empty()
		or member_kind not in [
			_RESET_MEMBER_CATALOG,
			_RESET_MEMBER_FAMILY_CONTAINER,
			_RESET_MEMBER_INTENT,
		]
	):
		return ERR_INVALID_PARAMETER
	var entry_budget: Array[int] = [_RESET_MAX_TREE_ENTRIES]
	return _remove_reset_tree(path, 0, entry_budget)


## 执行 reset recreate claim；测试替身可在精确发布边界注入故障。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param family_store: 已绑定冻结 Storage root 的 family store。
## [br]
## @param descriptor: 当前 logical family 的精确 descriptor。
## [br]
## @schema descriptor: Dictionary，必须精确匹配 make_family_descriptor_for_framework() 的固定字段与派生路径。
## [br]
## @return claim 的 Godot Error。
func claim_reset_family_for_framework(
	family_store: GFStorageFamilyStore,
	descriptor: Dictionary
) -> Error:
	if family_store == null or descriptor.is_empty():
		return ERR_INVALID_PARAMETER
	return family_store.claim_family_for_framework(descriptor)


# --- 私有/辅助方法 ---

func _make_async_operation(
	operation_kind: StringName,
	options: GFStorageAsyncRequestOptions = null
) -> GFStorageAsyncOperation:
	var operation: GFStorageAsyncOperation = GFStorageAsyncOperation.new()
	var request_id: int = _next_async_request_id
	_next_async_request_id += 1
	if _next_async_request_id <= 0:
		_next_async_request_id = 1
	var configured: bool = operation.configure_for_framework(request_id, operation_kind, "")
	if not configured:
		return operation
	var consumer_id: int = _next_async_consumer_id
	_next_async_consumer_id += 1
	if _next_async_consumer_id <= 0:
		_next_async_consumer_id = 1
	var options_invalid: bool = options != null and not options.is_valid()
	var effective_options: GFStorageAsyncRequestOptions = null if options_invalid else options
	var consumer_configured: bool = operation.configure_consumer_for_framework(
		consumer_id,
		effective_options,
		_clock,
		Callable(self, &"request_async_operation_cancel_for_framework")
	)
	if not consumer_configured:
		_complete_invalid_async_consumer(operation)
		return operation
	_async_observers[request_id] = {
		"consumer_id": consumer_id,
		"operation": operation,
		"record_id": 0,
	}
	var observer_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(
		self,
		&"_on_async_operation_completed_for_observer"
	)
	var observer_callback: Callable = func(_result: GFStorageAsyncResult) -> void:
		var _invocation_result: Dictionary = observer_invocation.invoke([request_id])
	var observer_connect_error: Error = operation.completed.connect(
		observer_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if observer_connect_error != OK:
		push_error("[GFStorageUtility] 无法连接异步请求物理终态观察器。")
	if options_invalid:
		_complete_invalid_async_consumer(operation)
	return operation


func _complete_invalid_async_consumer(operation: GFStorageAsyncOperation) -> void:
	match operation.get_operation():
		GFStorageAsyncOperation.OPERATION_SAVE:
			_complete_async_operation(
				operation,
				ERR_INVALID_PARAMETER,
				null,
				GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
			)
		GFStorageAsyncOperation.OPERATION_LOAD:
			var read_result: GFStorageReadResult = _make_load_failure(
				"Storage async request options are invalid.",
				ERR_INVALID_PARAMETER,
				GFStorageReadResult.FailureKind.INVALID_REQUEST
			)
			_complete_async_operation(operation, read_result.error_code, read_result)
		GFStorageAsyncOperation.OPERATION_DELETE:
			var delete_result: GFStorageDeleteResult = _make_delete_result(
				ERR_INVALID_PARAMETER,
				GFStorageDeleteResult.FailureKind.INVALID_REQUEST,
				0,
				0,
				0,
				GFStorageDeleteResult.FamilyMember.NONE
			)
			_complete_async_operation(
				operation,
				delete_result.get_error_code(),
				null,
				GFStorageAsyncResult.WriteFailureKind.NONE,
				{},
				delete_result
			)
		GFStorageAsyncOperation.OPERATION_RESET:
			var reset_result: GFStorageFamilyResetResult = _make_reset_invalid_result()
			_complete_async_operation(
				operation,
				reset_result.get_error_code(),
				null,
				GFStorageAsyncResult.WriteFailureKind.NONE,
				{},
				null,
				reset_result
			)


func _queue_async_task(task: Dictionary) -> void:
	_freeze_async_execution_mode()
	var record_id: int = _next_async_record_id
	_next_async_record_id += 1
	if _next_async_record_id <= 0:
		_next_async_record_id = 1
	task["record_id"] = record_id
	task["state"] = _AsyncTaskState.QUEUED
	var operation: GFStorageAsyncOperation = _get_task_operation(task)
	if operation != null:
		var observer: Dictionary = _get_async_observer(operation)
		if not observer.is_empty():
			observer["record_id"] = record_id
			observer["file_key"] = _get_task_file_key(task)
	_async_queue.append(task)


func _freeze_async_execution_mode() -> void:
	if _async_execution_mode_frozen:
		return
	_effective_async_execution_mode = _resolve_async_execution_mode()
	_async_execution_mode_frozen = true


func _get_effective_async_execution_mode() -> AsyncExecutionMode:
	if _async_execution_mode_frozen:
		return _effective_async_execution_mode
	return _resolve_async_execution_mode()


func _resolve_async_execution_mode() -> AsyncExecutionMode:
	match async_execution_mode:
		AsyncExecutionMode.THREADED:
			return AsyncExecutionMode.THREADED
		AsyncExecutionMode.COOPERATIVE:
			return AsyncExecutionMode.COOPERATIVE
		_:
			return (
				AsyncExecutionMode.THREADED
				if has_async_thread_capability_for_framework()
				else AsyncExecutionMode.COOPERATIVE
			)


func _cancel_async_operation_before_queue_if_needed(
	operation: GFStorageAsyncOperation
) -> bool:
	if operation == null:
		return false
	var _terminal_linearized: bool = operation.poll_caller_lifecycle_for_framework()
	return operation.is_completed()


func _make_async_target_family(canonical_file_name: String) -> Dictionary:
	var storage_root_path: String = _get_save_base_path()
	var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
		storage_root_path,
		canonical_file_name
	)
	return {
		"storage_root_path": storage_root_path,
		"family_id": GFVariantData.get_option_string(descriptor, "family_id"),
		"file_key": GFVariantData.get_option_string(descriptor, "file_key"),
		"catalog_path": GFVariantData.get_option_string(descriptor, "catalog_path"),
		"owner_path": GFVariantData.get_option_string(descriptor, "owner_path"),
		"final_path": GFVariantData.get_option_string(descriptor, "payload_path"),
		"temp_path": GFVariantData.get_option_string(descriptor, "candidate_path"),
		"backup_path": GFVariantData.get_option_string(descriptor, "backup_path"),
		"transaction_path": GFVariantData.get_option_string(descriptor, "transaction_path"),
		"transaction_pending_path": GFVariantData.get_option_string(descriptor, "transaction_pending_path"),
		"transaction_commit_path": GFVariantData.get_option_string(descriptor, "transaction_commit_path"),
		"transaction_commit_pending_path": GFVariantData.get_option_string(descriptor, "transaction_commit_pending_path"),
		"resource_stage_path": GFVariantData.get_option_string(descriptor, "resource_stage_path"),
	}


func _freeze_async_target_family(canonical_file_name: String) -> Dictionary:
	var target_family: Dictionary = _make_async_target_family(canonical_file_name)
	for required_key: String in [
		"storage_root_path",
		"family_id",
		"file_key",
		"catalog_path",
		"owner_path",
		"final_path",
		"temp_path",
		"backup_path",
		"transaction_path",
		"transaction_pending_path",
		"transaction_commit_path",
		"transaction_commit_pending_path",
		"resource_stage_path",
	]:
		if GFVariantData.get_option_string(target_family, required_key).is_empty():
			return {}
	_storage_root_frozen = true
	return target_family


func _make_async_transaction_id() -> String:
	var transaction_id: String = "async:%d:%d:%d" % [
		get_instance_id(),
		Time.get_ticks_usec(),
		_next_async_transaction_id,
	]
	_next_async_transaction_id += 1
	if _next_async_transaction_id <= 0:
		_next_async_transaction_id = 1
	return transaction_id


func _enqueue_async_save(
	file_name: String,
	data: Dictionary,
	operation: GFStorageAsyncOperation,
	operation_name: String
) -> Error:
	if _is_disposing or not _io_admission_open:
		_complete_async_operation(
			operation,
			ERR_UNAVAILABLE,
			null,
			GFStorageAsyncResult.WriteFailureKind.UNAVAILABLE
		)
		save_completed.emit(file_name, ERR_UNAVAILABLE)
		return ERR_UNAVAILABLE
	var canonical_file_name: String = ""
	if _validate_public_file_name(file_name, operation_name):
		canonical_file_name = _canonicalize_storage_file_name(file_name)
	if canonical_file_name.is_empty():
		_complete_async_operation(
			operation,
			ERR_INVALID_PARAMETER,
			null,
			GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
		)
		save_completed.emit(file_name, ERR_INVALID_PARAMETER)
		return ERR_INVALID_PARAMETER
	if operation != null:
		var _updated: bool = operation.set_file_name_for_framework(canonical_file_name)
		if _cancel_async_operation_before_queue_if_needed(operation):
			return ERR_SKIP
	ignore_pause = true
	var readiness_error: Error = _ensure_storage_ready()
	if readiness_error != OK:
		_complete_async_operation(
			operation,
			readiness_error,
			null,
			_classify_readiness_write_failure(readiness_error)
		)
		save_completed.emit(file_name, readiness_error)
		return readiness_error
	var target_family: Dictionary = _make_async_target_family(canonical_file_name)
	_queue_async_task({
		"type": &"save",
		"file_name": file_name,
		"storage_file_name": canonical_file_name,
		"storage_root_path": GFVariantData.get_option_string(target_family, "storage_root_path"),
		"family_id": GFVariantData.get_option_string(target_family, "family_id"),
		"file_key": GFVariantData.get_option_string(target_family, "file_key"),
		"catalog_path": GFVariantData.get_option_string(target_family, "catalog_path"),
		"owner_path": GFVariantData.get_option_string(target_family, "owner_path"),
		"final_path": GFVariantData.get_option_string(target_family, "final_path"),
		"temp_path": GFVariantData.get_option_string(target_family, "temp_path"),
		"backup_path": GFVariantData.get_option_string(target_family, "backup_path"),
		"transaction_path": GFVariantData.get_option_string(target_family, "transaction_path"),
		"transaction_pending_path": GFVariantData.get_option_string(target_family, "transaction_pending_path"),
		"transaction_commit_path": GFVariantData.get_option_string(target_family, "transaction_commit_path"),
		"transaction_commit_pending_path": GFVariantData.get_option_string(target_family, "transaction_commit_pending_path"),
		"resource_stage_path": GFVariantData.get_option_string(target_family, "resource_stage_path"),
		"transaction_id": _make_async_transaction_id(),
		"data": data.duplicate(true),
		"codec_options": _get_codec_options(),
		"operation": operation,
	})
	_request_async_start_only()
	return OK


func _enqueue_async_payload_save(
	file_name: String,
	transfer: GFStoragePayloadTransfer,
	operation: GFStorageAsyncOperation,
	operation_name: String
) -> Error:
	if _is_disposing or not _io_admission_open:
		_complete_async_operation(
			operation,
			ERR_UNAVAILABLE,
			null,
			GFStorageAsyncResult.WriteFailureKind.UNAVAILABLE
		)
		save_completed.emit(file_name, ERR_UNAVAILABLE)
		return ERR_UNAVAILABLE
	var canonical_file_name: String = ""
	if _validate_public_file_name(file_name, operation_name):
		canonical_file_name = _canonicalize_storage_file_name(file_name)
	if canonical_file_name.is_empty():
		_complete_async_operation(
			operation,
			ERR_INVALID_PARAMETER,
			null,
			GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
		)
		save_completed.emit(file_name, ERR_INVALID_PARAMETER)
		return ERR_INVALID_PARAMETER
	var _updated: bool = operation.set_file_name_for_framework(canonical_file_name)
	if transfer == null:
		_complete_async_operation(
			operation,
			ERR_INVALID_PARAMETER,
			null,
			GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
		)
		save_completed.emit(file_name, ERR_INVALID_PARAMETER)
		return ERR_INVALID_PARAMETER
	if _cancel_async_operation_before_queue_if_needed(operation):
		return ERR_SKIP

	ignore_pause = true
	var readiness_error: Error = _ensure_storage_ready()
	if readiness_error != OK:
		_complete_async_operation(
			operation,
			readiness_error,
			null,
			_classify_readiness_write_failure(readiness_error)
		)
		save_completed.emit(file_name, readiness_error)
		return readiness_error
	var target_family: Dictionary = _make_async_target_family(canonical_file_name)
	var target_file_key: String = GFVariantData.get_option_string(
		target_family,
		"file_key"
	)
	var codec_options: Dictionary = _get_codec_options()
	var attempt: Dictionary = transfer.begin_attempt_for_framework(
		get_instance_id(),
		canonical_file_name,
		target_file_key,
		codec_options
	)
	if not GFVariantData.get_option_bool(attempt, "ok"):
		_complete_async_operation(
			operation,
			ERR_INVALID_PARAMETER,
			null,
			GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
		)
		save_completed.emit(file_name, ERR_INVALID_PARAMETER)
		return ERR_INVALID_PARAMETER

	var attempt_id: int = GFVariantData.get_option_int(attempt, "attempt_id", 0)
	var payload_value: Variant = attempt.get("payload")
	if (
		attempt_id <= 0
		or not payload_value is Dictionary
		or not operation.configure_payload_attempt_for_framework(transfer, attempt_id)
	):
		var _finished: bool = transfer.finish_attempt_for_framework(attempt_id)
		_complete_async_operation(
			operation,
			ERR_INVALID_PARAMETER,
			null,
			GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
		)
		save_completed.emit(file_name, ERR_INVALID_PARAMETER)
		return ERR_INVALID_PARAMETER

	var payload: Dictionary = payload_value
	_queue_async_task({
		"type": &"save",
		"file_name": file_name,
		"storage_file_name": canonical_file_name,
		"storage_root_path": GFVariantData.get_option_string(target_family, "storage_root_path"),
		"family_id": GFVariantData.get_option_string(target_family, "family_id"),
		"file_key": target_file_key,
		"catalog_path": GFVariantData.get_option_string(target_family, "catalog_path"),
		"owner_path": GFVariantData.get_option_string(target_family, "owner_path"),
		"final_path": GFVariantData.get_option_string(target_family, "final_path"),
		"temp_path": GFVariantData.get_option_string(target_family, "temp_path"),
		"backup_path": GFVariantData.get_option_string(target_family, "backup_path"),
		"transaction_path": GFVariantData.get_option_string(target_family, "transaction_path"),
		"transaction_pending_path": GFVariantData.get_option_string(target_family, "transaction_pending_path"),
		"transaction_commit_path": GFVariantData.get_option_string(target_family, "transaction_commit_path"),
		"transaction_commit_pending_path": GFVariantData.get_option_string(target_family, "transaction_commit_pending_path"),
		"resource_stage_path": GFVariantData.get_option_string(target_family, "resource_stage_path"),
		"transaction_id": _make_async_transaction_id(),
		"data": payload,
		"codec_options": codec_options,
		"operation": operation,
	})
	_request_async_start_only()
	return OK


func _enqueue_async_load(
	file_name: String,
	operation: GFStorageAsyncOperation,
	operation_name: String
) -> Error:
	if _is_disposing or not _io_admission_open:
		var unavailable_result: GFStorageReadResult = _make_load_failure(
			"Storage utility is not accepting new I/O.",
			ERR_UNAVAILABLE,
			GFStorageReadResult.FailureKind.UNAVAILABLE
		)
		last_load_result = unavailable_result.duplicate_result()
		_complete_async_operation(
			operation,
			unavailable_result.error_code,
			unavailable_result
		)
		load_completed.emit(file_name, unavailable_result.duplicate_result())
		return ERR_UNAVAILABLE
	var canonical_file_name: String = ""
	if _validate_public_file_name(file_name, operation_name):
		canonical_file_name = _canonicalize_storage_file_name(file_name)
	if canonical_file_name.is_empty():
		var failed_result: GFStorageReadResult = _make_load_failure(
			"Storage file name is invalid.",
			ERR_INVALID_PARAMETER,
			GFStorageReadResult.FailureKind.INVALID_REQUEST
		)
		last_load_result = failed_result.duplicate_result()
		_complete_async_operation(operation, failed_result.error_code, failed_result)
		load_completed.emit(file_name, failed_result.duplicate_result())
		return ERR_INVALID_PARAMETER
	if operation != null:
		var _updated: bool = operation.set_file_name_for_framework(canonical_file_name)
		if _cancel_async_operation_before_queue_if_needed(operation):
			return ERR_SKIP
	ignore_pause = true
	var readiness_error: Error = _ensure_storage_ready()
	if readiness_error != OK:
		var readiness_result: GFStorageReadResult = (
			_make_readiness_load_failure_for_target(
				canonical_file_name,
				readiness_error
			)
		)
		last_load_result = readiness_result.duplicate_result()
		_complete_async_operation(
			operation,
			readiness_result.error_code,
			readiness_result
		)
		load_completed.emit(file_name, readiness_result.duplicate_result())
		return readiness_result.error_code
	var target_family: Dictionary = _make_async_target_family(canonical_file_name)
	_queue_async_task({
		"type": &"load",
		"file_name": file_name,
		"storage_file_name": canonical_file_name,
		"storage_root_path": GFVariantData.get_option_string(target_family, "storage_root_path"),
		"family_id": GFVariantData.get_option_string(target_family, "family_id"),
		"file_key": GFVariantData.get_option_string(target_family, "file_key"),
		"catalog_path": GFVariantData.get_option_string(target_family, "catalog_path"),
		"owner_path": GFVariantData.get_option_string(target_family, "owner_path"),
		"final_path": GFVariantData.get_option_string(target_family, "final_path"),
		"temp_path": GFVariantData.get_option_string(target_family, "temp_path"),
		"backup_path": GFVariantData.get_option_string(target_family, "backup_path"),
		"transaction_path": GFVariantData.get_option_string(target_family, "transaction_path"),
		"transaction_pending_path": GFVariantData.get_option_string(target_family, "transaction_pending_path"),
		"transaction_commit_path": GFVariantData.get_option_string(target_family, "transaction_commit_path"),
		"transaction_commit_pending_path": GFVariantData.get_option_string(target_family, "transaction_commit_pending_path"),
		"resource_stage_path": GFVariantData.get_option_string(target_family, "resource_stage_path"),
		"codec_options": _get_codec_options(),
		"operation": operation,
	})
	_request_async_start_only()
	return OK


func _enqueue_async_delete(
	file_name: String,
	operation: GFStorageAsyncOperation,
	operation_name: String
) -> Error:
	if _is_disposing or not _io_admission_open:
		var unavailable_result: GFStorageDeleteResult = _make_delete_result(
			ERR_UNAVAILABLE,
			GFStorageDeleteResult.FailureKind.UNAVAILABLE,
			0,
			0,
			0,
			GFStorageDeleteResult.FamilyMember.NONE
		)
		_complete_async_operation(
			operation,
			unavailable_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			unavailable_result
		)
		return ERR_UNAVAILABLE

	var canonical_file_name: String = ""
	if _validate_public_file_name(file_name, operation_name):
		canonical_file_name = _canonicalize_storage_file_name(file_name)
	if canonical_file_name.is_empty():
		var invalid_result: GFStorageDeleteResult = _make_delete_result(
			ERR_INVALID_PARAMETER,
			GFStorageDeleteResult.FailureKind.INVALID_REQUEST,
			0,
			0,
			0,
			GFStorageDeleteResult.FamilyMember.NONE
		)
		_complete_async_operation(
			operation,
			invalid_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			invalid_result
		)
		return ERR_INVALID_PARAMETER

	if operation != null:
		var file_name_updated: bool = operation.set_file_name_for_framework(canonical_file_name)
		if not file_name_updated:
			var identity_result: GFStorageDeleteResult = _make_delete_result(
				ERR_INVALID_PARAMETER,
				GFStorageDeleteResult.FailureKind.INVALID_REQUEST,
				0,
				0,
				0,
				GFStorageDeleteResult.FamilyMember.NONE
			)
			_complete_async_operation(
				operation,
				identity_result.get_error_code(),
				null,
				GFStorageAsyncResult.WriteFailureKind.NONE,
				{},
				identity_result
			)
			return ERR_INVALID_PARAMETER
		if _cancel_async_operation_before_queue_if_needed(operation):
			return ERR_SKIP

	var target_family: Dictionary = _freeze_async_target_family(canonical_file_name)
	if target_family.is_empty():
		var target_result: GFStorageDeleteResult = _make_delete_result(
			ERR_INVALID_PARAMETER,
			GFStorageDeleteResult.FailureKind.INVALID_REQUEST,
			0,
			0,
			0,
			GFStorageDeleteResult.FamilyMember.NONE
		)
		_complete_async_operation(
			operation,
			target_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			target_result
		)
		return ERR_INVALID_PARAMETER
	var layout_error: Error = _ensure_storage_layout_ready()
	if layout_error != OK:
		var layout_failure_kind: GFStorageDeleteResult.FailureKind = (
			GFStorageDeleteResult.FailureKind.CONFLICT
			if layout_error == ERR_FILE_CORRUPT
			else GFStorageDeleteResult.FailureKind.IO_FAILED
		)
		var layout_result: GFStorageDeleteResult = _make_delete_result(
			layout_error,
			layout_failure_kind,
			0,
			0,
			0,
			GFStorageDeleteResult.FamilyMember.FAMILY_METADATA
		)
		_complete_async_operation(
			operation,
			layout_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			layout_result
		)
		return layout_error

	_queue_async_task({
		"type": &"delete",
		"file_name": file_name,
		"storage_file_name": canonical_file_name,
		"storage_root_path": GFVariantData.get_option_string(target_family, "storage_root_path"),
		"family_id": GFVariantData.get_option_string(target_family, "family_id"),
		"file_key": GFVariantData.get_option_string(target_family, "file_key"),
		"catalog_path": GFVariantData.get_option_string(target_family, "catalog_path"),
		"owner_path": GFVariantData.get_option_string(target_family, "owner_path"),
		"final_path": GFVariantData.get_option_string(target_family, "final_path"),
		"temp_path": GFVariantData.get_option_string(target_family, "temp_path"),
		"backup_path": GFVariantData.get_option_string(target_family, "backup_path"),
		"transaction_path": GFVariantData.get_option_string(target_family, "transaction_path"),
		"transaction_pending_path": GFVariantData.get_option_string(target_family, "transaction_pending_path"),
		"transaction_commit_path": GFVariantData.get_option_string(target_family, "transaction_commit_path"),
		"transaction_commit_pending_path": GFVariantData.get_option_string(target_family, "transaction_commit_pending_path"),
		"resource_stage_path": GFVariantData.get_option_string(target_family, "resource_stage_path"),
		"operation": operation,
	})
	_request_async_start_only()
	return OK


func _enqueue_async_reset(
	file_name: String,
	authorization: GFStorageFamilyResetAuthorization,
	operation: GFStorageAsyncOperation,
	operation_name: String
) -> Error:
	if _is_disposing or not _io_admission_open:
		var unavailable_result: GFStorageFamilyResetResult = _make_reset_result(
			ERR_UNAVAILABLE,
			GFStorageFamilyResetResult.FailureKind.UNAVAILABLE,
			GFStorageFamilyResetResult.SourceKind.UNKNOWN,
			GFStorageFamilyResetResult.Phase.PREFLIGHT,
			0,
			0,
			0,
			GFStorageFamilyResetResult.FamilyMember.NONE
		)
		_complete_async_operation(
			operation,
			unavailable_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			null,
			unavailable_result
		)
		return ERR_UNAVAILABLE

	var canonical_file_name: String = ""
	if _validate_public_file_name(file_name, operation_name):
		canonical_file_name = _canonicalize_storage_file_name(file_name)
	if canonical_file_name.is_empty():
		var invalid_result: GFStorageFamilyResetResult = _make_reset_invalid_result()
		_complete_async_operation(
			operation,
			invalid_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			null,
			invalid_result
		)
		return ERR_INVALID_PARAMETER

	if operation != null:
		var file_name_updated: bool = operation.set_file_name_for_framework(canonical_file_name)
		if not file_name_updated:
			var identity_result: GFStorageFamilyResetResult = _make_reset_invalid_result()
			_complete_async_operation(
				operation,
				identity_result.get_error_code(),
				null,
				GFStorageAsyncResult.WriteFailureKind.NONE,
				{},
				null,
				identity_result
			)
			return ERR_INVALID_PARAMETER
		if _cancel_async_operation_before_queue_if_needed(operation):
			return ERR_SKIP

	var target_family: Dictionary = _freeze_async_target_family(canonical_file_name)
	if target_family.is_empty():
		var target_result: GFStorageFamilyResetResult = _make_reset_invalid_result()
		_complete_async_operation(
			operation,
			target_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			null,
			target_result
		)
		return ERR_INVALID_PARAMETER
	if not _claim_family_reset_authorization(
		authorization,
		canonical_file_name,
		target_family
	):
		var unauthorized_result: GFStorageFamilyResetResult = (
			_make_reset_unauthorized_result()
		)
		_complete_async_operation(
			operation,
			unauthorized_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			null,
			unauthorized_result
		)
		return ERR_UNAUTHORIZED

	_queue_async_task({
		"type": &"reset",
		"file_name": file_name,
		"storage_file_name": canonical_file_name,
		"storage_root_path": GFVariantData.get_option_string(target_family, "storage_root_path"),
		"family_id": GFVariantData.get_option_string(target_family, "family_id"),
		"file_key": GFVariantData.get_option_string(target_family, "file_key"),
		"catalog_path": GFVariantData.get_option_string(target_family, "catalog_path"),
		"owner_path": GFVariantData.get_option_string(target_family, "owner_path"),
		"final_path": GFVariantData.get_option_string(target_family, "final_path"),
		"temp_path": GFVariantData.get_option_string(target_family, "temp_path"),
		"backup_path": GFVariantData.get_option_string(target_family, "backup_path"),
		"transaction_path": GFVariantData.get_option_string(target_family, "transaction_path"),
		"transaction_pending_path": GFVariantData.get_option_string(target_family, "transaction_pending_path"),
		"transaction_commit_path": GFVariantData.get_option_string(target_family, "transaction_commit_path"),
		"transaction_commit_pending_path": GFVariantData.get_option_string(target_family, "transaction_commit_pending_path"),
		"resource_stage_path": GFVariantData.get_option_string(target_family, "resource_stage_path"),
		"reset_observation_token": authorization.get_observation_token_for_framework(),
		"operation": operation,
	})
	_request_async_start_only()
	return OK


func _complete_async_operation(
	operation: GFStorageAsyncOperation,
	error_code: Error,
	read_result: GFStorageReadResult,
	write_failure_kind: GFStorageAsyncResult.WriteFailureKind = GFStorageAsyncResult.WriteFailureKind.NONE,
	write_validation_report: Dictionary = {},
	delete_result: GFStorageDeleteResult = null,
	reset_result: GFStorageFamilyResetResult = null
) -> void:
	if operation == null or operation.is_completed():
		return

	var operation_kind: StringName = operation.get_operation()
	match operation_kind:
		GFStorageAsyncOperation.OPERATION_SAVE:
			read_result = null
			delete_result = null
			reset_result = null
		GFStorageAsyncOperation.OPERATION_LOAD:
			write_failure_kind = GFStorageAsyncResult.WriteFailureKind.NONE
			write_validation_report = {}
			delete_result = null
			reset_result = null
		GFStorageAsyncOperation.OPERATION_DELETE:
			read_result = null
			write_failure_kind = GFStorageAsyncResult.WriteFailureKind.NONE
			write_validation_report = {}
			if delete_result == null or not delete_result.is_configured_for_framework():
				delete_result = _make_delete_result_fallback()
			error_code = delete_result.get_error_code()
			reset_result = null
		GFStorageAsyncOperation.OPERATION_RESET:
			read_result = null
			write_failure_kind = GFStorageAsyncResult.WriteFailureKind.NONE
			write_validation_report = {}
			delete_result = null
			if reset_result == null or not reset_result.is_configured_for_framework():
				reset_result = _make_reset_result_fallback()
			error_code = reset_result.get_error_code()

	var ok: bool = error_code == OK
	if operation_kind == GFStorageAsyncOperation.OPERATION_LOAD:
		ok = read_result != null and read_result.ok
	elif operation_kind == GFStorageAsyncOperation.OPERATION_DELETE:
		ok = delete_result != null and delete_result.is_successful()
	elif operation_kind == GFStorageAsyncOperation.OPERATION_RESET:
		ok = reset_result != null and reset_result.is_successful()
	var result: GFStorageAsyncResult = GFStorageAsyncResult.new()
	var configured: bool = result.configure_for_framework(
		operation.get_request_id(),
		operation_kind,
		operation.get_file_name(),
		ok,
		error_code,
		read_result,
		write_failure_kind,
		write_validation_report,
		delete_result,
		GFStorageAsyncResult.SettlementKind.DOMAIN_RESULT,
		reset_result
	)
	if not configured:
		result = _make_async_operation_fallback_result(operation)
	if result == null:
		push_error("[GFStorageUtility] 无法构造异步请求 fallback 终态。")
		return

	var completed: bool = operation.complete_for_framework(result)
	if completed:
		_finalize_async_observer_after_physical_settlement(operation)
		return
	if not operation.is_pending():
		_finalize_async_observer_after_physical_settlement(operation)
		return
	_finish_payload_attempt(operation)
	var fallback_result: GFStorageAsyncResult = _make_async_operation_fallback_result(operation)
	if fallback_result == null:
		push_error("[GFStorageUtility] 无法构造异步请求 guaranteed fallback 终态。")
		return
	var fallback_completed: bool = operation.complete_for_framework(fallback_result)
	if not fallback_completed:
		push_error("[GFStorageUtility] 异步请求未能进入 guaranteed fallback 终态。")
		return
	_finalize_async_observer_after_physical_settlement(operation)


func _finalize_async_observer_after_physical_settlement(
	operation: GFStorageAsyncOperation
) -> void:
	if operation == null:
		return
	var diagnostic: Dictionary = operation.take_late_settlement_diagnostic_for_framework()
	if not diagnostic.is_empty():
		_async_late_settlements.append(diagnostic.duplicate(true))
		while _async_late_settlements.size() > _ASYNC_LATE_SETTLEMENT_CAPACITY:
			_async_late_settlements.pop_front()
	var _removed: bool = _async_observers.erase(operation.get_request_id())


func _on_async_operation_completed_for_observer(request_id: int) -> void:
	var observer_value: Variant = _async_observers.get(request_id)
	if not observer_value is Dictionary:
		return
	var observer: Dictionary = observer_value
	var operation: GFStorageAsyncOperation = _get_observer_operation(observer)
	if operation == null or operation.get_request_id() != request_id:
		return
	var record_id: int = GFVariantData.get_option_int(observer, "record_id", 0)
	var file_key: String = GFVariantData.get_option_string(observer, "file_key")
	_finalize_async_observer_after_physical_settlement(operation)
	_release_async_file_lock_for_record(
		record_id,
		file_key
	)


func _make_async_operation_fallback_result(
	operation: GFStorageAsyncOperation
) -> GFStorageAsyncResult:
	if operation == null:
		return null
	var result: GFStorageAsyncResult = GFStorageAsyncResult.new()
	var configured: bool = false
	match operation.get_operation():
		GFStorageAsyncOperation.OPERATION_SAVE:
			configured = result.configure_for_framework(
				operation.get_request_id(),
				operation.get_operation(),
				operation.get_file_name(),
				false,
				ERR_BUG,
				null,
				GFStorageAsyncResult.WriteFailureKind.IO_FAILED
			)
		GFStorageAsyncOperation.OPERATION_LOAD:
			var read_failure: GFStorageReadResult = _make_load_failure(
				"Storage async result configuration failed.",
				ERR_BUG,
				GFStorageReadResult.FailureKind.IO_FAILED
			)
			configured = result.configure_for_framework(
				operation.get_request_id(),
				operation.get_operation(),
				operation.get_file_name(),
				false,
				read_failure.error_code,
				read_failure
			)
		GFStorageAsyncOperation.OPERATION_DELETE:
			var delete_failure: GFStorageDeleteResult = _make_delete_result_fallback()
			configured = result.configure_for_framework(
				operation.get_request_id(),
				operation.get_operation(),
				operation.get_file_name(),
				false,
				delete_failure.get_error_code(),
				null,
				GFStorageAsyncResult.WriteFailureKind.NONE,
				{},
				delete_failure
			)
		GFStorageAsyncOperation.OPERATION_RESET:
			var reset_failure: GFStorageFamilyResetResult = _make_reset_result_fallback()
			configured = result.configure_for_framework(
				operation.get_request_id(),
				operation.get_operation(),
				operation.get_file_name(),
				false,
				reset_failure.get_error_code(),
				null,
				GFStorageAsyncResult.WriteFailureKind.NONE,
				{},
				null,
				GFStorageAsyncResult.SettlementKind.DOMAIN_RESULT,
				reset_failure
			)
	return result if configured else null


func _get_task_operation(task: Dictionary) -> GFStorageAsyncOperation:
	var value: Variant = GFVariantData.get_option_value(task, "operation")
	if value is GFStorageAsyncOperation:
		var operation: GFStorageAsyncOperation = value
		return operation
	return null


func _get_task_record_id(task: Dictionary) -> int:
	return GFVariantData.get_option_int(task, "record_id", 0)


func _get_async_observer(operation: GFStorageAsyncOperation) -> Dictionary:
	if operation == null:
		return {}
	var observer_value: Variant = _async_observers.get(operation.get_request_id())
	if observer_value is Dictionary:
		var observer: Dictionary = observer_value
		return observer
	return {}


func _get_observer_operation(observer: Dictionary) -> GFStorageAsyncOperation:
	var operation_value: Variant = GFVariantData.get_option_value(observer, "operation")
	if operation_value is GFStorageAsyncOperation:
		var operation: GFStorageAsyncOperation = operation_value
		return operation
	return null


func _wait_for_async_tasks_for_file(file_name: String) -> bool:
	if not _has_pending_async_task_for_file(file_name):
		return true
	wait_for_async_tasks()
	return not _has_pending_async_task_for_file(file_name)


func _has_pending_async_task_for_file(file_name: String) -> bool:
	var file_key: String = _get_async_file_key(file_name)
	if _async_file_locks.has(file_key):
		return true
	for task_value: Variant in _async_queue:
		var task: Dictionary = GFVariantData.as_dictionary(task_value)
		if _get_task_file_key(task) == file_key:
			return true
	return false


func _is_sync_io_admission_current() -> bool:
	return (
		_io_admission_open
		and not _is_disposing
		and not _async_deferred_dispose_requested
	)


func _has_async_executor_work() -> bool:
	return (
		not _async_queue.is_empty()
		or not _async_tasks.is_empty()
		or not _async_file_locks.is_empty()
		or not _async_settling_records.is_empty()
		or _async_execution_depth > 0
		or _async_completion_depth > 0
	)


func _ensure_storage_helpers() -> void:
	if _path_policy == null:
		_path_policy = _StoragePathPolicy.new(self)
	if _family_store == null:
		_family_store = _GF_STORAGE_FAMILY_STORE_SCRIPT.new()
		var storage_root_path: String = GFStorageFamilyStore.make_storage_root_path_for_framework(
			save_dir_name
		)
		if not storage_root_path.is_empty():
			var _configured: bool = _family_store.configure_for_framework(storage_root_path)
	if _file_ops == null:
		_file_ops = _StorageFileOps.new(self, _path_policy)
	if _transaction_manager == null:
		_transaction_manager = _StorageTransactionManager.new(
			self,
			_path_policy,
			_file_ops,
			_family_store
		)


func _ensure_storage_layout_ready() -> Error:
	_ensure_storage_helpers()
	var storage_root_path: String = _get_save_base_path()
	if storage_root_path.is_empty():
		return ERR_INVALID_PARAMETER
	var ancestry_error: Error = _validate_reset_mutation_ancestry(
		storage_root_path,
		{}
	)
	if ancestry_error != OK:
		return ancestry_error
	if not _family_store.configure_for_framework(storage_root_path):
		return ERR_INVALID_PARAMETER
	_storage_root_frozen = true
	var layout_error: Error = _family_store.ensure_layout_for_framework()
	if layout_error != OK:
		return layout_error
	return OK


func _ensure_storage_ready() -> Error:
	var layout_error: Error = _ensure_storage_layout_ready()
	if layout_error != OK:
		return layout_error
	if not _storage_reconciled:
		# 全局恢复会触及多个 family；异步执行器持有任何 ownership 时只确认 layout，
		# 让当前 worker 在自己的 file lock 内走精确 per-family 恢复，并把全局扫描延后到 idle。
		if _has_async_executor_work():
			return OK
		var reset_recovery_error: Error = _recover_all_pending_family_resets()
		if reset_recovery_error != OK:
			return reset_recovery_error
		var recovery_error: Error = _transaction_manager._recover_all_catalog_transactions()
		if recovery_error != OK:
			return recovery_error
		_storage_reconciled = true
	return OK


func _recover_all_pending_family_resets() -> Error:
	var storage_root_path: String = _get_save_base_path()
	if storage_root_path.is_empty():
		return ERR_INVALID_PARAMETER
	var ancestry_error: Error = _validate_reset_mutation_ancestry(
		storage_root_path,
		{}
	)
	if ancestry_error != OK:
		return ancestry_error
	var families_root: String = storage_root_path.path_join(
		".gf-storage/v1/families"
	)
	if not DirAccess.dir_exists_absolute(families_root):
		return OK
	var discovery: Dictionary = _discover_pending_reset_logical_names(families_root)
	var discovery_error: Error = GFVariantData.get_option_int(
		discovery,
		"error",
		ERR_FILE_CORRUPT
	) as Error
	if discovery_error != OK:
		return discovery_error
	var logical_names: Array[String] = []
	for value: Variant in GFVariantData.get_option_array(discovery, "logical_names"):
		if not value is String:
			return ERR_FILE_CORRUPT
		var logical_name: String = value
		logical_names.append(logical_name)
	logical_names.sort()
	for logical_name: String in logical_names:
		var worker_result: Dictionary = _reset_file_family_thread(
			storage_root_path,
			logical_name
		)
		var reset_result: GFStorageFamilyResetResult = _make_reset_result_from_worker(
			worker_result
		)
		var recovery_error: Error = reset_result.get_error_code()
		if recovery_error != OK:
			return recovery_error
	return OK


func _discover_pending_reset_logical_names(families_root: String) -> Dictionary:
	var logical_names: Dictionary = {}
	var pending_intent_count: Array[int] = [0]
	var first_level: Dictionary = _list_reset_recovery_shards(families_root)
	var first_error: Error = GFVariantData.get_option_int(
		first_level,
		"error",
		ERR_FILE_CANT_READ
	) as Error
	if first_error != OK:
		return {"error": int(first_error), "logical_names": []}
	for first_entry: Dictionary in GFVariantData.get_option_array(first_level, "entries"):
		var first_name: String = GFVariantData.get_option_string(first_entry, "name")
		if (
			not _is_reset_shard_name(first_name)
			or not GFVariantData.get_option_bool(first_entry, "is_directory")
			or GFVariantData.get_option_bool(first_entry, "is_link")
		):
			return {"error": int(ERR_FILE_CORRUPT), "logical_names": []}
		var second_path: String = families_root.path_join(first_name)
		var second_level: Dictionary = _list_reset_recovery_shards(second_path)
		var second_error: Error = GFVariantData.get_option_int(
			second_level,
			"error",
			ERR_FILE_CANT_READ
		) as Error
		if second_error != OK:
			return {"error": int(second_error), "logical_names": []}
		for second_entry: Dictionary in GFVariantData.get_option_array(
			second_level,
			"entries"
		):
			var second_name: String = GFVariantData.get_option_string(
				second_entry,
				"name"
			)
			if (
				not _is_reset_shard_name(second_name)
				or not GFVariantData.get_option_bool(second_entry, "is_directory")
				or GFVariantData.get_option_bool(second_entry, "is_link")
			):
				return {"error": int(ERR_FILE_CORRUPT), "logical_names": []}
			var family_parent: String = second_path.path_join(second_name)
			var family_discovery: Error = _discover_reset_intents_in_family_parent(
				family_parent,
				logical_names,
				pending_intent_count
			)
			if family_discovery != OK:
				return {"error": int(family_discovery), "logical_names": []}
	return {
		"error": int(OK),
		"logical_names": logical_names.keys(),
	}


func _list_reset_recovery_shards(
	path: String,
	entry_budget: Array[int] = []
) -> Dictionary:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return {"error": int(ERR_FILE_CANT_OPEN), "entries": []}
	var begin_error: Error = directory.list_dir_begin()
	if begin_error != OK:
		return {"error": int(begin_error), "entries": []}
	var entries: Array[Dictionary] = []
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if entries.size() >= _RESET_MAX_SHARD_ENTRIES:
			directory.list_dir_end()
			return {"error": int(ERR_OUT_OF_MEMORY), "entries": []}
		if (
			not entry_budget.is_empty()
			and not _consume_reset_scan_budget(entry_budget)
		):
			directory.list_dir_end()
			return {"error": int(ERR_OUT_OF_MEMORY), "entries": []}
		entries.append({
			"name": entry,
			"is_directory": directory.current_is_dir(),
			"is_link": directory.is_link(entry),
		})
		entry = directory.get_next()
	directory.list_dir_end()
	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return GFVariantData.get_option_string(left, "name") < GFVariantData.get_option_string(
			right,
			"name"
		)
	)
	return {"error": int(OK), "entries": entries}


func _discover_reset_intents_in_family_parent(
	family_parent: String,
	logical_names: Dictionary,
	pending_intent_count: Array[int]
) -> Error:
	if pending_intent_count.is_empty():
		return ERR_INVALID_PARAMETER
	var directory: DirAccess = DirAccess.open(family_parent)
	if directory == null:
		return ERR_FILE_CANT_OPEN
	var begin_error: Error = directory.list_dir_begin()
	if begin_error != OK:
		return begin_error
	var malformed_pending_paths: Array[String] = []
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if not entry.contains(_RESET_INTENT_SUFFIX):
			entry = directory.get_next()
			continue
		if directory.is_link(entry) or directory.current_is_dir():
			directory.list_dir_end()
			return ERR_FILE_CORRUPT
		pending_intent_count[0] += 1
		if pending_intent_count[0] > _RESET_MAX_PENDING_INTENTS:
			directory.list_dir_end()
			return ERR_OUT_OF_MEMORY
		var intent_path: String = family_parent.path_join(entry)
		var intent: Dictionary = _read_reset_intent(intent_path)
		if intent.is_empty():
			if not _is_reset_intent_pending_leaf_shape(entry):
				directory.list_dir_end()
				return ERR_FILE_CORRUPT
			malformed_pending_paths.append(intent_path)
			entry = directory.get_next()
			continue
		var logical_name: String = GFVariantData.get_option_string(
			intent,
			"logical_path"
		)
		var descriptor: Dictionary = (
			GFStorageFamilyStore.make_family_descriptor_for_framework(
				_get_save_base_path(),
				logical_name
			)
		)
		var reset_id: String = _reset_id_from_intent_leaf(
			entry,
			GFVariantData.get_option_string(descriptor, "family_path").get_file()
			+ _RESET_STAGING_SEPARATOR
		)
		if (
			descriptor.is_empty()
			or GFVariantData.get_option_string(descriptor, "family_path").get_base_dir()
			!= family_parent
			or not _reset_intent_matches_descriptor(intent, descriptor, reset_id)
		):
			if _is_reset_intent_pending_leaf_shape(entry):
				malformed_pending_paths.append(intent_path)
				entry = directory.get_next()
				continue
			directory.list_dir_end()
			return ERR_FILE_CORRUPT
		logical_names[logical_name] = true
		entry = directory.get_next()
	directory.list_dir_end()
	for malformed_pending_path: String in malformed_pending_paths:
		var cleanup_error: Error = _remove_absolute_file(malformed_pending_path)
		if cleanup_error != OK:
			return cleanup_error
	return OK


static func _is_reset_shard_name(value: String) -> bool:
	if value.length() != 2:
		return false
	for index: int in range(2):
		var character: String = value.substr(index, 1)
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func _is_reset_intent_pending_leaf_shape(leaf_name: String) -> bool:
	var pending_marker: String = _RESET_INTENT_SUFFIX + ".pending-"
	var pending_index: int = leaf_name.find(pending_marker)
	if pending_index <= 0:
		return false
	var pending_id: String = leaf_name.substr(
		pending_index + pending_marker.length()
	)
	if not GFUuid.is_valid(pending_id, 4):
		return false
	var exact_leaf: String = leaf_name.substr(0, pending_index) + _RESET_INTENT_SUFFIX
	var stem: String = exact_leaf.trim_suffix(_RESET_INTENT_SUFFIX)
	var reset_separator_index: int = stem.rfind(_RESET_STAGING_SEPARATOR)
	if reset_separator_index <= 0:
		return false
	var family_id: String = stem.substr(0, reset_separator_index)
	var reset_id: String = stem.substr(
		reset_separator_index + _RESET_STAGING_SEPARATOR.length()
	)
	return GFUuid.is_valid(family_id, 8) and GFUuid.is_valid(reset_id, 4)


func _release_storage_helpers() -> void:
	if _transaction_manager != null:
		_transaction_manager._dispose()
	if _file_ops != null:
		_file_ops._dispose()
	if _path_policy != null:
		_path_policy._dispose()
	_transaction_manager = null
	_file_ops = null
	_family_store = null
	_path_policy = null
	_storage_reconciled = false


func _ensure_directory_absolute(path: String) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	if DirAccess.dir_exists_absolute(path):
		return OK
	return DirAccess.make_dir_recursive_absolute(path)


func _classify_load_failure(error: Error) -> GFStorageReadResult.FailureKind:
	match error:
		OK:
			return GFStorageReadResult.FailureKind.NONE
		ERR_INVALID_PARAMETER:
			return GFStorageReadResult.FailureKind.INVALID_REQUEST
		ERR_FILE_NOT_FOUND:
			return GFStorageReadResult.FailureKind.NOT_FOUND
		ERR_FILE_CORRUPT:
			return GFStorageReadResult.FailureKind.CORRUPT
		ERR_UNAVAILABLE:
			return GFStorageReadResult.FailureKind.UNAVAILABLE
		_:
			return GFStorageReadResult.FailureKind.IO_FAILED


func _classify_readiness_load_failure(
	error: Error
) -> GFStorageReadResult.FailureKind:
	match error:
		ERR_INVALID_PARAMETER:
			return GFStorageReadResult.FailureKind.INVALID_REQUEST
		ERR_UNAVAILABLE:
			return GFStorageReadResult.FailureKind.UNAVAILABLE
		_:
			return GFStorageReadResult.FailureKind.IO_FAILED


func _make_readiness_load_failure_for_target(
	canonical_file_name: String,
	readiness_error: Error
) -> GFStorageReadResult:
	var target_preparation: Dictionary = _prepare_family_for_read_after_readiness_result(
		canonical_file_name
	)
	var target_error: Error = GFVariantData.get_option_int(
		target_preparation,
		"error",
		ERR_BUG
	) as Error
	var target_descriptor: Dictionary = (
		GFStorageFamilyStore.make_family_descriptor_for_framework(
			_get_save_base_path(),
			canonical_file_name
		)
	)
	if (
		target_error == ERR_FILE_CORRUPT
		and GFVariantData.get_option_bool(
			target_preparation,
			"target_provenance"
		)
		and not target_descriptor.is_empty()
		and _validate_reset_mutation_ancestry(
			_get_save_base_path(),
			target_descriptor
		) == OK
	):
		var target_result: GFStorageReadResult = _make_load_failure(
			"Storage family unavailable",
			ERR_FILE_CORRUPT,
			GFStorageReadResult.FailureKind.CORRUPT
		)
		_bind_read_result_origin(target_result, canonical_file_name)
		return target_result
	return _make_load_failure(
		"Storage recovery is unavailable",
		readiness_error,
		_classify_readiness_load_failure(readiness_error)
	)


func _classify_readiness_write_failure(
	error: Error
) -> GFStorageAsyncResult.WriteFailureKind:
	match error:
		ERR_INVALID_PARAMETER:
			return GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST
		ERR_UNAVAILABLE:
			return GFStorageAsyncResult.WriteFailureKind.UNAVAILABLE
		_:
			return GFStorageAsyncResult.WriteFailureKind.IO_FAILED


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


func _get_task_execution_mode(task: Dictionary) -> AsyncExecutionMode:
	var raw_mode: int = GFVariantData.get_option_int(
		task,
		"execution_mode",
		AsyncExecutionMode.THREADED
	)
	if AsyncExecutionMode.values().has(raw_mode):
		return raw_mode as AsyncExecutionMode
	return AsyncExecutionMode.THREADED


func _get_task_state(task: Dictionary) -> _AsyncTaskState:
	var raw_state: int = GFVariantData.get_option_int(task, "state", _AsyncTaskState.QUEUED)
	if _AsyncTaskState.values().has(raw_state):
		return raw_state as _AsyncTaskState
	return _AsyncTaskState.QUEUED


func _get_task_file_name(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "file_name")


func _get_task_storage_file_name(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "storage_file_name", _get_task_file_name(task))


func _get_task_storage_root_path(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "storage_root_path")


func _get_task_family_id(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "family_id")


func _get_task_file_key(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "file_key")


func _get_task_catalog_path(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "catalog_path")


func _get_task_owner_path(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "owner_path")


func _get_task_final_path(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "final_path")


func _get_task_temp_path(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "temp_path")


func _get_task_backup_path(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "backup_path")


func _get_task_transaction_path(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "transaction_path")


func _get_task_transaction_pending_path(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "transaction_pending_path")


func _get_task_transaction_commit_path(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "transaction_commit_path")


func _get_task_transaction_commit_pending_path(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "transaction_commit_pending_path")


func _get_task_resource_stage_path(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "resource_stage_path")


func _get_task_transaction_id(task: Dictionary) -> String:
	return GFVariantData.get_option_string(task, "transaction_id")


func _get_task_type(task: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(task, "type")


func _get_task_dictionary(task: Dictionary, key: String) -> Dictionary:
	return GFVariantData.get_option_dictionary(task, key)


func _get_task_dictionary_reference(task: Dictionary, key: String) -> Dictionary:
	var value: Variant = task.get(key)
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary
	return {}


func _get_result_error(result: Dictionary, default_value: Error = ERR_BUG) -> Error:
	return GFVariantData.get_option_int(result, "error", default_value) as Error


func _poll_async_tasks() -> void:
	_request_async_scheduler_run()


func _request_async_scheduler_run() -> void:
	_async_scheduler_requested = true
	if _async_scheduler_running:
		return
	_async_scheduler_running = true
	var cooperative_eligible_record_ids: Array[int] = []
	for task: Dictionary in _async_tasks:
		if (
			_get_task_execution_mode(task) == AsyncExecutionMode.COOPERATIVE
			and _get_task_state(task) == _AsyncTaskState.ACCEPTED
		):
			cooperative_eligible_record_ids.append(_get_task_record_id(task))
	var cooperative_execution_budget: int = 1
	while _async_scheduler_requested:
		_async_scheduler_requested = false
		_harvest_finished_async_tasks()
		_poll_async_operation_lifecycles()
		if (
			cooperative_execution_budget > 0
			and _run_next_cooperative_async_task(cooperative_eligible_record_ids)
		):
			cooperative_execution_budget -= 1
		if not _is_disposing:
			_start_queued_async_tasks()
	_async_scheduler_running = false


func _request_async_start_only() -> void:
	if _get_effective_async_execution_mode() == AsyncExecutionMode.COOPERATIVE:
		return
	_async_start_only_requested = true
	if _async_start_only_running or _is_disposing:
		return
	_async_start_only_running = true
	while _async_start_only_requested and not _is_disposing:
		_async_start_only_requested = false
		_start_queued_async_tasks()
	_async_start_only_running = false


func _harvest_finished_async_tasks() -> void:
	var active_tasks: Array[Dictionary] = _async_tasks.duplicate()
	for task: Dictionary in active_tasks:
		var thread: Thread = _get_task_thread(task)
		if thread == null or thread.is_alive():
			continue
		_join_async_task(task)


func _run_next_cooperative_async_task(eligible_record_ids: Array[int]) -> bool:
	var active_tasks: Array[Dictionary] = _async_tasks.duplicate()
	for task: Dictionary in active_tasks:
		if (
			_get_task_execution_mode(task) != AsyncExecutionMode.COOPERATIVE
			or _get_task_state(task) != _AsyncTaskState.ACCEPTED
			or _get_task_record_id(task) not in eligible_record_ids
		):
			continue
		_start_async_task(task)
		return true
	return false


func _poll_async_operation_lifecycles() -> void:
	var observer_values: Array = _async_observers.values().duplicate()
	for observer_value: Variant in observer_values:
		var observer: Dictionary = GFVariantData.as_dictionary(observer_value)
		var operation: GFStorageAsyncOperation = _get_observer_operation(observer)
		if operation == null or not operation.is_caller_pending():
			continue
		var _terminal_linearized: bool = operation.poll_caller_lifecycle_for_framework()


func _try_complete_quiesce() -> void:
	if (
		_quiesce_completion == null
		or not _quiesce_completion.is_pending()
		or not _async_tasks.is_empty()
		or not _async_queue.is_empty()
		or not _async_file_locks.is_empty()
	):
		return
	var _succeeded: bool = _quiesce_completion.succeed()


func _wait_for_async_tasks() -> void:
	_harvest_finished_async_tasks()
	_poll_async_operation_lifecycles()
	_cancel_all_queued_async_tasks_for_dispose()
	while not _async_tasks.is_empty() or not _async_queue.is_empty():
		_start_queued_async_tasks(true)
		if _async_tasks.is_empty():
			break
		var task: Dictionary = GFVariantData.as_dictionary(_async_tasks.front())
		if task.is_empty():
			break
		_join_async_task(task)


func _start_queued_async_tasks(allow_during_dispose: bool = false) -> void:
	if (
		(_is_disposing or _async_deferred_dispose_requested)
		and not allow_during_dispose
	):
		return
	var execution_mode: AsyncExecutionMode = _get_effective_async_execution_mode()
	var active_task_limit: int = (
		1
		if execution_mode == AsyncExecutionMode.COOPERATIVE
		else maxi(max_async_thread_count, 1)
	)
	while (
		(
			allow_during_dispose
			or (not _is_disposing and not _async_deferred_dispose_requested)
		)
		and _async_tasks.size() < active_task_limit
	):
		var task_index: int = _find_startable_async_task_index()
		if task_index < 0:
			return

		var task: Dictionary = GFVariantData.as_dictionary(_async_queue[task_index])
		var operation: GFStorageAsyncOperation = _get_task_operation(task)
		if operation != null:
			var _terminal_linearized: bool = operation.poll_caller_lifecycle_for_framework()
			if (
				(_is_disposing or _async_deferred_dispose_requested)
				and not allow_during_dispose
			):
				return
			task_index = _find_queued_async_task_index(_get_task_record_id(task))
			if task_index < 0:
				continue
			if not operation.mark_worker_accepted_for_framework():
				var _cancelled: bool = _cancel_queued_async_task(
					task,
					GFStorageAsyncCallerResult.EndKind.EXPLICIT_CANCEL,
					&"request_not_accepted",
					true
				)
				continue

		_async_queue.remove_at(task_index)
		task["state"] = _AsyncTaskState.ACCEPTED
		task["execution_mode"] = execution_mode
		_async_tasks.append(task)
		var file_key: String = _get_task_file_key(task)
		if not file_key.is_empty():
			_async_file_locks[file_key] = _get_task_record_id(task)
		if execution_mode == AsyncExecutionMode.THREADED:
			_start_async_task(task)


func _find_startable_async_task_index() -> int:
	for i: int in range(_async_queue.size()):
		var task: Dictionary = GFVariantData.as_dictionary(_async_queue[i])
		var file_key: String = _get_task_file_key(task)
		if file_key.is_empty() or not _async_file_locks.has(file_key):
			return i
	return -1


func _start_async_task(task: Dictionary) -> void:
	var storage_file_name: String = _get_task_storage_file_name(task)
	var task_type: StringName = _get_task_type(task)
	var target_error: Error = _validate_frozen_async_target(task)
	if target_error != OK:
		if _begin_async_task_settlement(task):
			_emit_async_start_failed(
				task,
				target_error,
				GFStorageAsyncResult.WriteFailureKind.INVALID_REQUEST,
				"Frozen target validation failed",
				GFStorageDeleteResult.FailureKind.INVALID_REQUEST,
				GFStorageFamilyResetResult.FailureKind.INVALID_REQUEST
			)
			_end_async_task_settlement(task)
		return
	if (
		_get_task_execution_mode(task) == AsyncExecutionMode.THREADED
		and not has_async_thread_capability_for_framework()
	):
		_settle_async_task_start_failure(
			task,
			ERR_CANT_CREATE,
			_has_exact_active_task_ownership(task)
		)
		return
	if task_type not in [&"delete", &"reset"]:
		var recovery_result: Dictionary = _recover_frozen_async_transaction(task)
		var recovery_error: Error = GFVariantData.get_option_int(
			recovery_result,
			"error",
			ERR_BUG
		) as Error
		if recovery_error != OK:
			if _begin_async_task_settlement(task):
				_emit_async_start_failed(
					task,
					recovery_error,
					GFStorageAsyncResult.WriteFailureKind.IO_FAILED,
					"Transaction recovery failed",
					GFStorageDeleteResult.FailureKind.THREAD_START_FAILED,
					GFStorageFamilyResetResult.FailureKind.THREAD_START_FAILED,
					GFVariantData.get_option_bool(
						recovery_result,
						"target_provenance"
					)
				)
				_end_async_task_settlement(task)
			return

	var callback: Callable = Callable()
	if task_type == &"save":
		callback = Callable(self, "_save_data_thread").bind(
			storage_file_name,
			_get_task_final_path(task),
			_get_task_temp_path(task),
			_get_task_backup_path(task),
			_get_task_transaction_path(task),
			_get_task_transaction_pending_path(task),
			_get_task_transaction_commit_path(task),
			_get_task_transaction_commit_pending_path(task),
			_get_task_transaction_id(task),
			_get_task_dictionary_reference(task, "data"),
			_get_task_dictionary(task, "codec_options")
		)
	elif task_type == &"load":
		callback = Callable(self, "_load_data_thread").bind(
			storage_file_name,
			_get_task_final_path(task),
			_get_task_dictionary(task, "codec_options")
		)
	elif task_type == &"delete":
		callback = Callable(self, "_delete_file_thread").bind(
			_get_task_storage_root_path(task),
			storage_file_name
		)
	elif task_type == &"reset":
		callback = Callable(self, "_reset_file_family_thread").bind(
			_get_task_storage_root_path(task),
			storage_file_name,
			GFVariantData.get_option_string(task, "reset_observation_token")
		)
	if not callback.is_valid():
		_settle_async_task_start_failure(
			task,
			ERR_INVALID_PARAMETER,
			_has_exact_active_task_ownership(task)
		)
		return
	if _get_task_execution_mode(task) == AsyncExecutionMode.COOPERATIVE:
		_run_cooperative_async_task(task, callback)
		return

	var thread: Thread = Thread.new()
	_async_execution_depth += 1
	var error: Error = start_async_worker_for_framework(task_type, thread, callback)
	_async_execution_depth = maxi(_async_execution_depth - 1, 0)
	var worker_started: bool = thread.is_started()
	var ownership_valid: bool = _has_exact_active_task_ownership(task)
	if worker_started:
		task["thread"] = thread
		task["state"] = _AsyncTaskState.RUNNING
		if not ownership_valid and not _restore_exact_active_task_ownership(task):
			push_error("[GFStorageUtility] worker 启动后丢失 exact active/file-lock ownership。")
			var emergency_result: Variant = thread.wait_to_finish()
			_begin_unowned_async_task_settlement(task)
			_complete_finished_async_task(task, emergency_result)
			_end_async_task_settlement(task)
			return
		_run_deferred_async_dispose_if_ready()
		return

	var start_error: Error = error if error != OK else ERR_CANT_CREATE
	_settle_async_task_start_failure(task, start_error, ownership_valid)


func _run_cooperative_async_task(task: Dictionary, callback: Callable) -> void:
	task["state"] = _AsyncTaskState.RUNNING
	_async_execution_depth += 1
	var result_variant: Variant = callback.call()
	_async_execution_depth = maxi(_async_execution_depth - 1, 0)
	var ownership_valid: bool = _has_exact_active_task_ownership(task)
	if not ownership_valid and not _restore_exact_active_task_ownership(task):
		push_error("[GFStorageUtility] cooperative worker 丢失 exact active/file-lock ownership。")
		_begin_unowned_async_task_settlement(task)
		_complete_finished_async_task(task, result_variant)
		_end_async_task_settlement(task)
		return
	if not _begin_async_task_settlement(task):
		push_error("[GFStorageUtility] cooperative worker 无法取得 settling ownership。")
		return
	_complete_finished_async_task(task, result_variant)
	_end_async_task_settlement(task)


func _settle_async_task_start_failure(
	task: Dictionary,
	error: Error,
	ownership_valid: bool
) -> void:
	if ownership_valid and _begin_async_task_settlement(task):
		_emit_async_start_failed(task, error)
		_end_async_task_settlement(task)
		return
	push_error("[GFStorageUtility] worker 未启动且丢失 exact active/file-lock ownership。")
	_begin_unowned_async_task_settlement(task)
	_emit_async_start_failed(task, error)
	_end_async_task_settlement(task)


func _join_async_task(task: Dictionary) -> void:
	var active_index: int = _find_active_async_task_index(_get_task_record_id(task))
	if active_index < 0:
		return
	if _get_task_execution_mode(task) == AsyncExecutionMode.COOPERATIVE:
		if _get_task_state(task) == _AsyncTaskState.ACCEPTED:
			_start_async_task(task)
		return
	var thread: Thread = _get_task_thread(task)
	if thread == null:
		return
	var result_variant: Variant = thread.wait_to_finish()
	if not _begin_async_task_settlement(task):
		push_error("[GFStorageUtility] worker 退出后无法取得 settling ownership。")
		return
	_complete_finished_async_task(task, result_variant)
	_end_async_task_settlement(task)


func _begin_async_task_settlement(task: Dictionary) -> bool:
	var record_id: int = _get_task_record_id(task)
	var file_key: String = _get_task_file_key(task)
	if (
		record_id <= 0
		or _async_settling_records.has(record_id)
		or _find_active_async_task_index(record_id) < 0
		or (
			not file_key.is_empty()
			and GFVariantData.get_option_int(_async_file_locks, file_key, 0) != record_id
		)
	):
		return false
	var active_index: int = _find_active_async_task_index(record_id)
	_async_tasks.remove_at(active_index)
	task["state"] = _AsyncTaskState.SETTLING
	task["settlement_depth_owned"] = true
	_async_settling_records[record_id] = {
		"file_key": file_key,
	}
	_async_completion_depth += 1
	return true


func _begin_unowned_async_task_settlement(task: Dictionary) -> void:
	var active_index: int = _find_active_async_task_index(_get_task_record_id(task))
	if active_index >= 0:
		_async_tasks.remove_at(active_index)
	task["state"] = _AsyncTaskState.SETTLING
	task["settlement_depth_owned"] = true
	_async_completion_depth += 1


func _end_async_task_settlement(task: Dictionary) -> void:
	_release_async_file_lock_for_record(
		_get_task_record_id(task),
		_get_task_file_key(task)
	)
	if GFVariantData.get_option_bool(task, "settlement_depth_owned", false):
		task["settlement_depth_owned"] = false
		_async_completion_depth = maxi(_async_completion_depth - 1, 0)
	_run_deferred_async_dispose_if_ready()


func _release_async_file_lock_for_record(record_id: int, file_key: String) -> void:
	if record_id <= 0:
		return
	var settling_value: Variant = _async_settling_records.get(record_id)
	if not settling_value is Dictionary:
		return
	var settling_record: Dictionary = settling_value
	if GFVariantData.get_option_string(settling_record, "file_key") != file_key:
		return
	if (
		not file_key.is_empty()
		and GFVariantData.get_option_int(_async_file_locks, file_key, 0) == record_id
	):
		_erase_dictionary_key(_async_file_locks, file_key)
	var _settling_removed: bool = _async_settling_records.erase(record_id)
	_try_complete_quiesce()


func _release_async_file_lock_for_task(task: Dictionary) -> void:
	_release_async_file_lock_for_record(
		_get_task_record_id(task),
		_get_task_file_key(task)
	)


func _has_exact_active_task_ownership(task: Dictionary) -> bool:
	var record_id: int = _get_task_record_id(task)
	if record_id <= 0 or _find_active_async_task_index(record_id) < 0:
		return false
	var file_key: String = _get_task_file_key(task)
	return (
		file_key.is_empty()
		or GFVariantData.get_option_int(_async_file_locks, file_key, 0) == record_id
	)


func _restore_exact_active_task_ownership(task: Dictionary) -> bool:
	var record_id: int = _get_task_record_id(task)
	if record_id <= 0 or _async_settling_records.has(record_id):
		return false
	var file_key: String = _get_task_file_key(task)
	var lock_owner: int = GFVariantData.get_option_int(_async_file_locks, file_key, 0)
	if not file_key.is_empty() and lock_owner not in [0, record_id]:
		return false
	if _find_active_async_task_index(record_id) < 0:
		_async_tasks.append(task)
	if not file_key.is_empty():
		_async_file_locks[file_key] = record_id
	return true


func _run_deferred_async_dispose_if_ready() -> void:
	if (
		not _async_deferred_dispose_requested
		or _is_disposing
		or _async_completion_depth > 0
		or _async_execution_depth > 0
	):
		return
	_async_deferred_dispose_requested = false
	dispose()


func _find_active_async_task_index(record_id: int) -> int:
	if record_id <= 0:
		return -1
	for index: int in range(_async_tasks.size()):
		var task: Dictionary = GFVariantData.as_dictionary(_async_tasks[index])
		if _get_task_record_id(task) == record_id:
			return index
	return -1


func _find_queued_async_task_index(record_id: int) -> int:
	if record_id <= 0:
		return -1
	for index: int in range(_async_queue.size()):
		var task: Dictionary = GFVariantData.as_dictionary(_async_queue[index])
		if _get_task_record_id(task) == record_id:
			return index
	return -1


func _cancel_all_queued_async_tasks_for_dispose() -> void:
	var queued_tasks: Array[Dictionary] = _async_queue.duplicate()
	for task: Dictionary in queued_tasks:
		var operation: GFStorageAsyncOperation = _get_task_operation(task)
		if operation != null:
			var _cancelled: bool = _complete_cancelled_before_acceptance(
				operation,
				task,
				GFStorageAsyncCallerResult.EndKind.UTILITY_DISPOSED,
				&"utility_disposed",
				true
			)
			continue
		var queued_index: int = _find_queued_async_task_index(_get_task_record_id(task))
		if queued_index >= 0:
			_async_queue.remove_at(queued_index)
		_complete_legacy_queued_dispose(task)


func _complete_legacy_queued_dispose(task: Dictionary) -> void:
	var file_name: String = _get_task_file_name(task)
	match _get_task_type(task):
		&"save":
			save_completed.emit(file_name, ERR_UNAVAILABLE)
		&"load":
			var failed_result: GFStorageReadResult = _make_load_failure(
				"Storage utility disposed before task started.",
				ERR_UNAVAILABLE,
				GFStorageReadResult.FailureKind.UNAVAILABLE
			)
			last_load_result = failed_result.duplicate_result()
			load_completed.emit(file_name, failed_result.duplicate_result())


func _cancel_queued_async_task(
	task: Dictionary,
	end_kind: GFStorageAsyncCallerResult.EndKind,
	reason: StringName,
	emit_caller_signal: bool
) -> bool:
	var operation: GFStorageAsyncOperation = _get_task_operation(task)
	if operation == null:
		return false
	return _complete_cancelled_before_acceptance(
		operation,
		task,
		end_kind,
		reason,
		emit_caller_signal
	)


func _complete_cancelled_before_acceptance(
	operation: GFStorageAsyncOperation,
	task: Dictionary,
	end_kind: GFStorageAsyncCallerResult.EndKind,
	reason: StringName,
	emit_caller_signal: bool
) -> bool:
	if operation == null or not operation.is_caller_pending():
		return false
	if not task.is_empty() and _get_task_operation(task) != operation:
		return false
	_finish_payload_attempt(operation)
	if not operation.is_payload_attempt_ready_for_settlement_for_framework():
		var degraded: bool = operation.complete_caller_for_framework(
			GFStorageAsyncCallerResult.Status.OUTCOME_UNKNOWN,
			end_kind,
			reason,
			emit_caller_signal
		)
		if degraded:
			_request_async_start_only()
		return degraded
	var cancelled_result: GFStorageAsyncResult = GFStorageAsyncResult.new()
	if not cancelled_result.configure_cancelled_for_framework(
		operation.get_request_id(),
		operation.get_operation(),
		operation.get_file_name()
	):
		push_error("[GFStorageUtility] 接纳前取消无法构造闭合物理终态。")
		return false
	if not operation.mark_physical_cancel_requested_for_framework():
		return false
	if not task.is_empty():
		var queued_index: int = _find_queued_async_task_index(_get_task_record_id(task))
		if queued_index < 0:
			push_error("[GFStorageUtility] 接纳前取消丢失权威 queued record。")
			return false
		_async_queue.remove_at(queued_index)
	var completed: bool = operation.complete_for_framework(
		cancelled_result,
		end_kind,
		reason,
		emit_caller_signal
	)
	if not completed:
		push_error("[GFStorageUtility] 接纳前取消未能提交 guaranteed physical terminal。")
		return false
	_finalize_async_observer_after_physical_settlement(operation)
	_request_async_start_only()
	return true


func _validate_frozen_async_target(task: Dictionary) -> Error:
	var storage_file_name: String = _get_task_storage_file_name(task)
	var storage_root_path: String = _get_task_storage_root_path(task)
	_ensure_storage_helpers()
	if storage_file_name.is_empty() or not _path_policy._is_valid_frozen_storage_root_path(
		storage_root_path
	):
		return ERR_INVALID_PARAMETER
	var expected: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
		storage_root_path,
		storage_file_name
	)
	if (
		expected.is_empty()
		or _get_task_family_id(task) != GFVariantData.get_option_string(expected, "family_id")
		or _get_task_file_key(task) != GFVariantData.get_option_string(expected, "file_key")
		or _get_task_catalog_path(task) != GFVariantData.get_option_string(expected, "catalog_path")
		or _get_task_owner_path(task) != GFVariantData.get_option_string(expected, "owner_path")
		or _get_task_final_path(task) != GFVariantData.get_option_string(expected, "payload_path")
		or _get_task_temp_path(task) != GFVariantData.get_option_string(expected, "candidate_path")
		or _get_task_backup_path(task) != GFVariantData.get_option_string(expected, "backup_path")
		or _get_task_transaction_path(task) != GFVariantData.get_option_string(expected, "transaction_path")
		or _get_task_transaction_pending_path(task) != GFVariantData.get_option_string(expected, "transaction_pending_path")
		or _get_task_transaction_commit_path(task) != GFVariantData.get_option_string(expected, "transaction_commit_path")
		or _get_task_transaction_commit_pending_path(task) != GFVariantData.get_option_string(expected, "transaction_commit_pending_path")
		or _get_task_resource_stage_path(task) != GFVariantData.get_option_string(expected, "resource_stage_path")
	):
		return ERR_INVALID_PARAMETER
	return OK


func _recover_frozen_async_transaction(task: Dictionary) -> Dictionary:
	var storage_file_name: String = _get_task_storage_file_name(task)
	var storage_root_path: String = _get_task_storage_root_path(task)
	var expected: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
		storage_root_path,
		storage_file_name
	)
	if expected.is_empty():
		return {"error": int(ERR_INVALID_PARAMETER), "target_provenance": false}
	var ancestry_error: Error = _validate_reset_mutation_ancestry(
		storage_root_path,
		expected
	)
	if ancestry_error != OK:
		return {"error": int(ancestry_error), "target_provenance": false}
	var frozen_family_store: GFStorageFamilyStore = _GF_STORAGE_FAMILY_STORE_SCRIPT.new()
	if not frozen_family_store.configure_for_framework(storage_root_path):
		return {"error": int(ERR_INVALID_PARAMETER), "target_provenance": false}
	var layout_error: Error = frozen_family_store.ensure_layout_for_framework()
	if layout_error != OK:
		return {"error": int(layout_error), "target_provenance": false}
	var reset_recovery_result: Dictionary = _resume_pending_reset_for_file_result(
		storage_root_path,
		storage_file_name
	)
	var reset_recovery_error: Error = GFVariantData.get_option_int(
		reset_recovery_result,
		"error",
		ERR_BUG
	) as Error
	var target_provenance: bool = GFVariantData.get_option_bool(
		reset_recovery_result,
		"target_provenance"
	)
	if reset_recovery_error != OK:
		return reset_recovery_result
	var family_error: Error
	if _get_task_type(task) == &"save":
		family_error = frozen_family_store.claim_family_for_framework(expected)
	else:
		family_error = frozen_family_store.validate_family_for_framework(expected)
	if family_error != OK:
		return {
			"error": int(family_error),
			"target_provenance": target_provenance,
		}
	var frozen_transaction_manager: _StorageTransactionManager = _StorageTransactionManager.new(
		self,
		_FrozenStoragePathPolicy.new(storage_root_path),
		_file_ops,
		frozen_family_store
	)
	var recovery_error: Error = frozen_transaction_manager._recover_frozen_file_family(
		storage_file_name,
		_get_task_final_path(task),
		_get_task_temp_path(task),
		_get_task_backup_path(task),
		_get_task_transaction_path(task),
		_get_task_transaction_commit_path(task)
	)
	frozen_transaction_manager._dispose()
	return {
		"error": int(recovery_error),
		"target_provenance": target_provenance,
	}


func _emit_async_start_failed(
	task: Dictionary,
	error: Error,
	write_failure_kind: GFStorageAsyncResult.WriteFailureKind = GFStorageAsyncResult.WriteFailureKind.THREAD_START_FAILED,
	failure_reason: String = "Thread start failed",
	delete_failure_kind: GFStorageDeleteResult.FailureKind = GFStorageDeleteResult.FailureKind.THREAD_START_FAILED,
	reset_failure_kind: GFStorageFamilyResetResult.FailureKind = GFStorageFamilyResetResult.FailureKind.THREAD_START_FAILED,
	load_has_target_provenance: bool = false
) -> void:
	var file_name: String = _get_task_file_name(task)
	var task_type: StringName = _get_task_type(task)
	var operation: GFStorageAsyncOperation = _get_task_operation(task)
	if task_type == &"save":
		push_error("[GFStorageUtility] 异步保存失败：%s，原因：%s，错误码：%s" % [
			file_name,
			failure_reason,
			error,
		])
		_finish_payload_attempt(operation)
		_complete_async_operation(
			operation,
			error,
			null,
			write_failure_kind
		)
		_release_async_file_lock_for_task(task)
		save_completed.emit(file_name, error)
	elif task_type == &"load":
		if error != ERR_FILE_NOT_FOUND:
			push_error("[GFStorageUtility] 异步读取失败：%s，原因：%s，错误码：%s" % [
				file_name,
				failure_reason,
				error,
			])
		var failure_kind: GFStorageReadResult.FailureKind = _classify_load_failure(error)
		var failed_result: GFStorageReadResult = _make_load_failure(
			"%s: %s" % [failure_reason, error_string(error)],
			error,
			failure_kind
		)
		if load_has_target_provenance:
			_bind_read_result_origin(failed_result, _get_task_storage_file_name(task))
		last_load_result = failed_result.duplicate_result()
		_complete_async_operation(operation, failed_result.error_code, failed_result)
		_release_async_file_lock_for_task(task)
		load_completed.emit(file_name, failed_result.duplicate_result())
	elif task_type == &"delete":
		push_error("[GFStorageUtility] 异步删除失败：%s，原因：%s，错误码：%s" % [
			file_name,
			failure_reason,
			error,
		])
		var delete_result: GFStorageDeleteResult = _make_delete_result(
			error,
			delete_failure_kind,
			0,
			0,
			0,
			GFStorageDeleteResult.FamilyMember.NONE
		)
		_complete_async_operation(
			operation,
			delete_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			delete_result
		)
		_release_async_file_lock_for_task(task)
	elif task_type == &"reset":
		push_error("[GFStorageUtility] 异步 family reset 失败：%s，原因：%s，错误码：%s" % [
			file_name,
			failure_reason,
			error,
		])
		var reset_result: GFStorageFamilyResetResult = _make_reset_result(
			error,
			reset_failure_kind,
			GFStorageFamilyResetResult.SourceKind.UNKNOWN,
			GFStorageFamilyResetResult.Phase.PREFLIGHT,
			0,
			0,
			0,
			GFStorageFamilyResetResult.FamilyMember.NONE
		)
		_complete_async_operation(
			operation,
			reset_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			null,
			reset_result
		)
		_release_async_file_lock_for_task(task)


func _complete_finished_async_task(task: Dictionary, result_variant: Variant) -> void:
	var file_name: String = _get_task_file_name(task)
	var task_type: StringName = _get_task_type(task)
	var operation: GFStorageAsyncOperation = _get_task_operation(task)
	if task_type == &"save":
		var save_result: Dictionary = GFVariantData.as_dictionary(result_variant)
		var error: Error = ERR_BUG
		var write_failure_kind: GFStorageAsyncResult.WriteFailureKind = GFStorageAsyncResult.WriteFailureKind.IO_FAILED
		var validation_report: Dictionary = {}
		if not save_result.is_empty():
			error = _get_result_error(save_result, ERR_BUG)
			write_failure_kind = _to_write_failure_kind(
				GFVariantData.get_option_int(
					save_result,
					"write_failure_kind",
					GFStorageAsyncResult.WriteFailureKind.IO_FAILED
				)
			)
			validation_report = GFVariantData.get_option_dictionary(
				save_result,
				"validation_report"
			)
		_finish_payload_attempt(operation)
		_complete_async_operation(
			operation,
			error,
			null,
			write_failure_kind,
			validation_report
		)
		_release_async_file_lock_for_task(task)
		save_completed.emit(file_name, error)
	elif task_type == &"load":
		_complete_async_load(task, result_variant, operation)
	elif task_type == &"delete":
		var delete_result: GFStorageDeleteResult = _make_delete_result_from_worker(
			result_variant
		)
		_complete_async_operation(
			operation,
			delete_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			delete_result
		)
		_release_async_file_lock_for_task(task)
	elif task_type == &"reset":
		var reset_result: GFStorageFamilyResetResult = _make_reset_result_from_worker(
			result_variant
		)
		_complete_async_operation(
			operation,
			reset_result.get_error_code(),
			null,
			GFStorageAsyncResult.WriteFailureKind.NONE,
			{},
			null,
			reset_result
		)
		_release_async_file_lock_for_task(task)


func _finish_payload_attempt(operation: GFStorageAsyncOperation) -> void:
	if operation == null:
		return
	var _finished: bool = operation.finish_payload_attempt_for_framework()


func _to_write_failure_kind(value: int) -> GFStorageAsyncResult.WriteFailureKind:
	if GFStorageAsyncResult.WriteFailureKind.values().has(value):
		return value as GFStorageAsyncResult.WriteFailureKind
	return GFStorageAsyncResult.WriteFailureKind.IO_FAILED


func _make_delete_result(
	error_code: Error,
	failure_kind: GFStorageDeleteResult.FailureKind,
	existing_member_count: int,
	removed_member_count: int,
	remaining_member_count: int,
	failed_member: GFStorageDeleteResult.FamilyMember
) -> GFStorageDeleteResult:
	var result: GFStorageDeleteResult = GFStorageDeleteResult.new()
	var configured: bool = result.configure_for_framework(
		error_code,
		failure_kind,
		existing_member_count,
		removed_member_count,
		remaining_member_count,
		failed_member
	)
	return result if configured else _make_delete_result_fallback()


func _make_delete_result_fallback() -> GFStorageDeleteResult:
	var result: GFStorageDeleteResult = GFStorageDeleteResult.new()
	var configured: bool = result.configure_for_framework(
		ERR_BUG,
		GFStorageDeleteResult.FailureKind.IO_FAILED,
		0,
		0,
		0,
		GFStorageDeleteResult.FamilyMember.FAMILY_METADATA
	)
	if not configured:
		push_error("[GFStorageUtility] 无法配置删除 fallback 结果。")
	return result


func _make_delete_result_from_worker(result_variant: Variant) -> GFStorageDeleteResult:
	if not result_variant is Dictionary:
		return _make_delete_result_fallback()
	var raw_result: Dictionary = result_variant
	var required_keys: Array[String] = [
		"error_code",
		"failure_kind",
		"existing_member_count",
		"removed_member_count",
		"remaining_member_count",
		"failed_member",
	]
	if raw_result.size() != required_keys.size():
		return _make_delete_result_fallback()
	for required_key: String in required_keys:
		if not raw_result.has(required_key):
			return _make_delete_result_fallback()

	var error_code_value: Variant = raw_result.get("error_code")
	var failure_kind_value: Variant = raw_result.get("failure_kind")
	var existing_count_value: Variant = raw_result.get("existing_member_count")
	var removed_count_value: Variant = raw_result.get("removed_member_count")
	var remaining_count_value: Variant = raw_result.get("remaining_member_count")
	var failed_member_value: Variant = raw_result.get("failed_member")
	if (
		not error_code_value is int
		or not failure_kind_value is int
		or not existing_count_value is int
		or not removed_count_value is int
		or not remaining_count_value is int
		or not failed_member_value is int
	):
		return _make_delete_result_fallback()

	var numeric_error_code: int = error_code_value
	var numeric_failure_kind: int = failure_kind_value
	var existing_member_count: int = existing_count_value
	var removed_member_count: int = removed_count_value
	var remaining_member_count: int = remaining_count_value
	var numeric_failed_member: int = failed_member_value
	if (
		numeric_error_code < OK
		or numeric_error_code > ERR_PRINTER_ON_FIRE
		or not GFStorageDeleteResult.FailureKind.values().has(numeric_failure_kind)
		or not GFStorageDeleteResult.FamilyMember.values().has(numeric_failed_member)
	):
		return _make_delete_result_fallback()
	var result: GFStorageDeleteResult = GFStorageDeleteResult.new()
	var configured: bool = result.configure_for_framework(
		numeric_error_code as Error,
		numeric_failure_kind as GFStorageDeleteResult.FailureKind,
		existing_member_count,
		removed_member_count,
		remaining_member_count,
		numeric_failed_member as GFStorageDeleteResult.FamilyMember
	)
	return result if configured else _make_delete_result_fallback()


func _make_reset_result(
	error_code: Error,
	failure_kind: GFStorageFamilyResetResult.FailureKind,
	source_kind: GFStorageFamilyResetResult.SourceKind,
	failed_phase: GFStorageFamilyResetResult.Phase,
	retired_member_count: int,
	recreated_member_count: int,
	remaining_evidence_count: int,
	failed_member: GFStorageFamilyResetResult.FamilyMember
) -> GFStorageFamilyResetResult:
	var result: GFStorageFamilyResetResult = GFStorageFamilyResetResult.new()
	var configured: bool = result.configure_for_framework(
		error_code,
		failure_kind,
		source_kind,
		failed_phase,
		retired_member_count,
		recreated_member_count,
		remaining_evidence_count,
		failed_member
	)
	return result if configured else _make_reset_result_fallback()


func _make_reset_result_fallback() -> GFStorageFamilyResetResult:
	var result: GFStorageFamilyResetResult = GFStorageFamilyResetResult.new()
	var configured: bool = result.configure_for_framework(
		ERR_BUG,
		GFStorageFamilyResetResult.FailureKind.IO_FAILED,
		GFStorageFamilyResetResult.SourceKind.UNKNOWN,
		GFStorageFamilyResetResult.Phase.PREFLIGHT,
		0,
		0,
		0,
		GFStorageFamilyResetResult.FamilyMember.NONE
	)
	if not configured:
		push_error("[GFStorageUtility] 无法配置 family reset fallback 结果。")
	return result


func _make_reset_invalid_result() -> GFStorageFamilyResetResult:
	return _make_reset_result(
		ERR_INVALID_PARAMETER,
		GFStorageFamilyResetResult.FailureKind.INVALID_REQUEST,
		GFStorageFamilyResetResult.SourceKind.UNKNOWN,
		GFStorageFamilyResetResult.Phase.PREFLIGHT,
		0,
		0,
		0,
		GFStorageFamilyResetResult.FamilyMember.NONE
	)


func _make_reset_unauthorized_result() -> GFStorageFamilyResetResult:
	return _make_reset_result(
		ERR_UNAUTHORIZED,
		GFStorageFamilyResetResult.FailureKind.UNAUTHORIZED,
		GFStorageFamilyResetResult.SourceKind.UNKNOWN,
		GFStorageFamilyResetResult.Phase.PREFLIGHT,
		0,
		0,
		0,
		GFStorageFamilyResetResult.FamilyMember.NONE
	)


func _make_reset_result_from_worker(result_variant: Variant) -> GFStorageFamilyResetResult:
	if not result_variant is Dictionary:
		return _make_reset_result_fallback()
	var raw_result: Dictionary = result_variant
	var required_keys: Array[String] = [
		"error_code",
		"failure_kind",
		"source_kind",
		"failed_phase",
		"retired_member_count",
		"recreated_member_count",
		"remaining_evidence_count",
		"failed_member",
	]
	if raw_result.size() != required_keys.size():
		return _make_reset_result_fallback()
	for required_key: String in required_keys:
		if not raw_result.has(required_key):
			return _make_reset_result_fallback()
	for required_key: String in required_keys:
		if not raw_result.get(required_key) is int:
			return _make_reset_result_fallback()

	var numeric_error_code: int = raw_result.get("error_code")
	var numeric_failure_kind: int = raw_result.get("failure_kind")
	var numeric_source_kind: int = raw_result.get("source_kind")
	var numeric_failed_phase: int = raw_result.get("failed_phase")
	var retired_member_count: int = raw_result.get("retired_member_count")
	var recreated_member_count: int = raw_result.get("recreated_member_count")
	var remaining_evidence_count: int = raw_result.get("remaining_evidence_count")
	var numeric_failed_member: int = raw_result.get("failed_member")
	if (
		numeric_error_code < OK
		or numeric_error_code > ERR_PRINTER_ON_FIRE
		or not GFStorageFamilyResetResult.FailureKind.values().has(numeric_failure_kind)
		or not GFStorageFamilyResetResult.SourceKind.values().has(numeric_source_kind)
		or not GFStorageFamilyResetResult.Phase.values().has(numeric_failed_phase)
		or not GFStorageFamilyResetResult.FamilyMember.values().has(numeric_failed_member)
	):
		return _make_reset_result_fallback()
	return _make_reset_result(
		numeric_error_code as Error,
		numeric_failure_kind as GFStorageFamilyResetResult.FailureKind,
		numeric_source_kind as GFStorageFamilyResetResult.SourceKind,
		numeric_failed_phase as GFStorageFamilyResetResult.Phase,
		retired_member_count,
		recreated_member_count,
		remaining_evidence_count,
		numeric_failed_member as GFStorageFamilyResetResult.FamilyMember
	)


static func _reset_failed_member_from_claim_state(
	failed_member: StringName
) -> GFStorageFamilyResetResult.FamilyMember:
	match failed_member:
		&"family_container":
			return GFStorageFamilyResetResult.FamilyMember.FAMILY_CONTAINER
		&"catalog":
			return GFStorageFamilyResetResult.FamilyMember.CATALOG
		&"none":
			return GFStorageFamilyResetResult.FamilyMember.NONE
		_:
			return GFStorageFamilyResetResult.FamilyMember.OWNER


func _claim_family_reset_authorization(
	authorization: GFStorageFamilyResetAuthorization,
	canonical_file_name: String,
	target_family: Dictionary
) -> bool:
	return (
		authorization != null
		and authorization.claim_for_framework(
			get_instance_id(),
			canonical_file_name,
			GFVariantData.get_option_string(target_family, "file_key"),
			_make_family_observation_token(canonical_file_name)
		)
	)


func _bind_read_result_origin(
	result: GFStorageReadResult,
	canonical_file_name: String
) -> void:
	if (
		result == null
		or result.ok
		or result.error_code == OK
		or result.failure_kind != GFStorageReadResult.FailureKind.CORRUPT
		or canonical_file_name.is_empty()
	):
		return
	var target_family: Dictionary = _make_async_target_family(canonical_file_name)
	var file_key: String = GFVariantData.get_option_string(target_family, "file_key")
	var observation_token: String = _make_family_observation_token(
		canonical_file_name
	)
	if file_key.is_empty() or observation_token.is_empty():
		return
	var _bound: bool = result.bind_origin_for_framework(
		get_instance_id(),
		canonical_file_name,
		file_key,
		_read_result_origin_token,
		observation_token
	)


func _make_family_observation_token(
	canonical_file_name: String,
	storage_root_path: String = ""
) -> String:
	var resolved_storage_root_path: String = (
		_get_save_base_path()
		if storage_root_path.is_empty()
		else storage_root_path
	)
	var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
		resolved_storage_root_path,
		canonical_file_name
	)
	if descriptor.is_empty():
		return ""
	var records: Array[String] = []
	for path_key: String in [
		"catalog_path",
		"family_path",
		"owner_path",
		"payload_path",
		"candidate_path",
		"backup_path",
		"transaction_path",
		"transaction_pending_path",
		"transaction_commit_path",
		"transaction_commit_pending_path",
		"resource_stage_path",
	]:
		var path: String = GFVariantData.get_option_string(descriptor, path_key)
		if path.is_empty():
			return ""
		if _absolute_storage_path_is_link(path):
			records.append(path_key + ":link")
		elif FileAccess.file_exists(path):
			var digest: String = FileAccess.get_sha256(path)
			if digest.is_empty():
				return ""
			records.append(path_key + ":file:" + digest)
		elif DirAccess.dir_exists_absolute(path):
			records.append(path_key + ":directory")
		else:
			records.append(path_key + ":missing")
	return JSON.stringify(records).sha256_text()


func _complete_async_load(
	task: Dictionary,
	result_variant: Variant,
	operation: GFStorageAsyncOperation
) -> void:
	var file_name: String = _get_task_file_name(task)
	var result_data: Dictionary = GFVariantData.as_dictionary(result_variant)
	var result: GFStorageReadResult
	if result_data.is_empty():
		result = _make_load_failure(
			"Async load failed",
			ERR_CANT_ACQUIRE_RESOURCE,
			GFStorageReadResult.FailureKind.IO_FAILED
		)
	else:
		result = GFStorageReadResult.from_dict(result_data)
	var from_version: int = result.data_version if result != null else 0
	result = _apply_schema_migrations(file_name, result, false)
	_bind_read_result_origin(result, _get_task_storage_file_name(task))
	var migration_to_version: int = result.data_version if result != null else from_version
	var should_emit_migrated: bool = (
		result != null
		and result.ok
		and result.migrated
		and migration_to_version > from_version
	)
	var integrity_failure: String = ""
	last_load_result = result.duplicate_result()
	if not result.ok:
		if _should_emit_load_integrity_failed(result):
			integrity_failure = result.error
		_complete_async_operation(operation, result.error_code, result)
		_release_async_file_lock_for_task(task)
		if should_emit_migrated:
			data_migrated.emit(file_name, from_version, migration_to_version)
		if not integrity_failure.is_empty():
			data_integrity_failed.emit(file_name, integrity_failure)
		load_completed.emit(file_name, last_load_result.duplicate_result())
		return

	if result.integrity_status == GFStorageReadResult.IntegrityStatus.INVALID:
		integrity_failure = "Integrity checksum mismatch"
	_complete_async_operation(operation, OK, result)
	_release_async_file_lock_for_task(task)
	if should_emit_migrated:
		data_migrated.emit(file_name, from_version, migration_to_version)
	if not integrity_failure.is_empty():
		data_integrity_failed.emit(file_name, integrity_failure)
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


static func _make_transaction_marker(
	file_names: Array[String],
	file_key: String,
	transaction_id: String,
	committed: bool,
	had_final_by_file: Dictionary
) -> Dictionary:
	var sorted_file_names: Array[String] = file_names.duplicate()
	sorted_file_names.sort()
	var members: Array[Dictionary] = []
	for member_file_name: String in sorted_file_names:
		members.append({
			"logical_path": member_file_name,
			"family_id": GFStorageFamilyStore.make_family_id_for_framework(member_file_name),
			"had_final": GFVariantData.get_option_bool(
				had_final_by_file,
				member_file_name
			),
		})
	return {
		"schema": _TRANSACTION_COMMIT_SCHEMA if committed else _TRANSACTION_PREPARE_SCHEMA,
		"schema_version": _TRANSACTION_MARKER_SCHEMA_VERSION,
		"transaction_id": transaction_id,
		"owner": {
			"logical_path": file_key,
			"family_id": GFStorageFamilyStore.make_family_id_for_framework(file_key),
		},
		"members": members,
		"committed": committed,
	}


static func _is_valid_single_file_transaction_marker(
	marker: Dictionary,
	file_name: String
) -> bool:
	if marker.size() != 6:
		return false
	var committed_value: Variant = marker.get("committed")
	if not committed_value is bool:
		return false
	var committed: bool = committed_value
	var schema_value: Variant = marker.get("schema")
	if not schema_value is String or schema_value != (
		_TRANSACTION_COMMIT_SCHEMA if committed else _TRANSACTION_PREPARE_SCHEMA
	):
		return false
	var schema_version_value: Variant = marker.get("schema_version")
	var transaction_value: Variant = marker.get("transaction_id")
	var owner_value: Variant = marker.get("owner")
	var members_value: Variant = marker.get("members")
	if (
		not transaction_value is String
		or not owner_value is Dictionary
		or not members_value is Array
	):
		return false
	var schema_version: int = GFVariantData.to_exact_int(schema_version_value, -1)
	var marker_transaction_id: String = transaction_value
	var owner: Dictionary = owner_value
	var owner_logical_path_value: Variant = owner.get("logical_path")
	var owner_family_id_value: Variant = owner.get("family_id")
	if (
		schema_version != _TRANSACTION_MARKER_SCHEMA_VERSION
		or marker_transaction_id.is_empty()
		or owner.size() != 2
		or not owner_logical_path_value is String
		or not owner_family_id_value is String
		or owner_logical_path_value != file_name
		or owner_family_id_value != GFStorageFamilyStore.make_family_id_for_framework(file_name)
	):
		return false
	var members: Array = members_value
	if members.size() != 1:
		return false
	var only_member_value: Variant = members[0]
	if not only_member_value is Dictionary:
		return false
	var only_member: Dictionary = only_member_value
	var member_logical_path_value: Variant = only_member.get("logical_path")
	var member_family_id_value: Variant = only_member.get("family_id")
	return (
		only_member.size() == 3
		and member_logical_path_value is String
		and member_family_id_value is String
		and member_logical_path_value == file_name
		and member_family_id_value == GFStorageFamilyStore.make_family_id_for_framework(file_name)
		and only_member.get("had_final") is bool
	)


func _delete_file_thread(storage_root_path: String, logical_name: String) -> Dictionary:
	var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
		storage_root_path,
		logical_name
	)
	if descriptor.is_empty():
		return _make_delete_worker_result(
			ERR_INVALID_PARAMETER,
			GFStorageDeleteResult.FailureKind.INVALID_REQUEST,
			0,
			0,
			0,
			GFStorageDeleteResult.FamilyMember.NONE
		)
	var reset_recovery_error: Error = _resume_pending_reset_for_file(
		storage_root_path,
		logical_name
	)
	if reset_recovery_error != OK:
		return _make_delete_metadata_worker_failure(reset_recovery_error, 0)
	var members: Array[Dictionary] = _make_delete_family_members(descriptor)
	if members.size() != 8:
		return _make_delete_worker_result(
			ERR_INVALID_PARAMETER,
			GFStorageDeleteResult.FailureKind.INVALID_REQUEST,
			0,
			0,
			0,
			GFStorageDeleteResult.FamilyMember.NONE
		)
	var existing_member_count: int = _count_existing_delete_members(members)

	var family_store: GFStorageFamilyStore = _GF_STORAGE_FAMILY_STORE_SCRIPT.new()
	if not family_store.configure_for_framework(storage_root_path):
		return _make_delete_worker_result(
			ERR_INVALID_PARAMETER,
			GFStorageDeleteResult.FailureKind.INVALID_REQUEST,
			0,
			0,
			0,
			GFStorageDeleteResult.FamilyMember.NONE
		)
	var layout_error: Error = family_store.ensure_layout_for_framework()
	if layout_error != OK:
		return _make_delete_metadata_worker_failure(
			layout_error,
			existing_member_count
		)
	var family_error: Error = family_store.validate_family_for_framework(descriptor)
	if family_error == ERR_FILE_NOT_FOUND:
		return _make_delete_worker_result(
			ERR_FILE_NOT_FOUND,
			GFStorageDeleteResult.FailureKind.NOT_FOUND,
			0,
			0,
			0,
			GFStorageDeleteResult.FamilyMember.NONE
		)
	if family_error != OK:
		return _make_delete_metadata_worker_failure(
			family_error,
			existing_member_count
		)
	if existing_member_count == 0:
		return _make_delete_worker_result(
			ERR_FILE_NOT_FOUND,
			GFStorageDeleteResult.FailureKind.NOT_FOUND,
			0,
			0,
			0,
			GFStorageDeleteResult.FamilyMember.NONE
		)

	var evidence_error: Error = _validate_delete_transaction_evidence(
		logical_name,
		descriptor
	)
	if evidence_error != OK:
		return _make_delete_worker_result(
			evidence_error,
			(
				GFStorageDeleteResult.FailureKind.CONFLICT
				if evidence_error == ERR_FILE_CORRUPT
				else GFStorageDeleteResult.FailureKind.IO_FAILED
			),
			existing_member_count,
			0,
			existing_member_count,
			GFStorageDeleteResult.FamilyMember.TRANSACTION_EVIDENCE
		)

	var existing_paths: Dictionary = {}
	for member: Dictionary in members:
		var member_path: String = GFVariantData.get_option_string(member, "path")
		if FileAccess.file_exists(member_path):
			existing_paths[member_path] = true
	var removed_member_count: int = 0
	for member: Dictionary in members:
		var member_path: String = GFVariantData.get_option_string(member, "path")
		if not existing_paths.has(member_path):
			continue
		var member_kind: StringName = GFVariantData.get_option_string_name(member, "kind")
		var numeric_family_member: int = GFVariantData.get_option_int(
			member,
			"family_member",
			GFStorageDeleteResult.FamilyMember.FAMILY_METADATA
		)
		var family_member: GFStorageDeleteResult.FamilyMember = (
			numeric_family_member as GFStorageDeleteResult.FamilyMember
		)
		var remove_error: Error = remove_delete_family_member_for_framework(
			member_kind,
			member_path
		)
		var member_still_exists: bool = (
			FileAccess.file_exists(member_path)
			or DirAccess.dir_exists_absolute(member_path)
		)
		if not member_still_exists:
			removed_member_count += 1
		if remove_error != OK or member_still_exists:
			return _make_delete_worker_result(
				remove_error if remove_error != OK else FAILED,
				GFStorageDeleteResult.FailureKind.IO_FAILED,
				existing_member_count,
				removed_member_count,
				existing_member_count - removed_member_count,
				family_member
			)
	return _make_delete_worker_result(
		OK,
		GFStorageDeleteResult.FailureKind.NONE,
		existing_member_count,
		removed_member_count,
		0,
		GFStorageDeleteResult.FamilyMember.NONE
	)


func _make_delete_family_members(descriptor: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = [
		{
			"kind": _DELETE_MEMBER_BACKUP,
			"family_member": GFStorageDeleteResult.FamilyMember.BACKUP,
			"path": GFVariantData.get_option_string(descriptor, "backup_path"),
		},
		{
			"kind": _DELETE_MEMBER_TRANSACTION_PREPARE_PENDING,
			"family_member": GFStorageDeleteResult.FamilyMember.TRANSACTION_EVIDENCE,
			"path": GFVariantData.get_option_string(descriptor, "transaction_pending_path"),
		},
		{
			"kind": _DELETE_MEMBER_TRANSACTION_PREPARE,
			"family_member": GFStorageDeleteResult.FamilyMember.TRANSACTION_EVIDENCE,
			"path": GFVariantData.get_option_string(descriptor, "transaction_path"),
		},
		{
			"kind": _DELETE_MEMBER_TRANSACTION_COMMIT_PENDING,
			"family_member": GFStorageDeleteResult.FamilyMember.TRANSACTION_EVIDENCE,
			"path": GFVariantData.get_option_string(
				descriptor,
				"transaction_commit_pending_path"
			),
		},
		{
			"kind": _DELETE_MEMBER_TRANSACTION_COMMIT,
			"family_member": GFStorageDeleteResult.FamilyMember.TRANSACTION_EVIDENCE,
			"path": GFVariantData.get_option_string(descriptor, "transaction_commit_path"),
		},
		{
			"kind": _DELETE_MEMBER_CANDIDATE,
			"family_member": GFStorageDeleteResult.FamilyMember.CANDIDATE,
			"path": GFVariantData.get_option_string(descriptor, "candidate_path"),
		},
		{
			"kind": _DELETE_MEMBER_RESOURCE_STAGE,
			"family_member": GFStorageDeleteResult.FamilyMember.RESOURCE_STAGE,
			"path": GFVariantData.get_option_string(descriptor, "resource_stage_path"),
		},
		{
			"kind": _DELETE_MEMBER_FINAL,
			"family_member": GFStorageDeleteResult.FamilyMember.FINAL,
			"path": GFVariantData.get_option_string(descriptor, "payload_path"),
		},
	]
	var unique_paths: Dictionary = {}
	for member: Dictionary in result:
		var member_path: String = GFVariantData.get_option_string(member, "path")
		if member_path.is_empty() or unique_paths.has(member_path):
			return []
		unique_paths[member_path] = true
	return result


func _count_existing_delete_members(members: Array[Dictionary]) -> int:
	var result: int = 0
	for member: Dictionary in members:
		if FileAccess.file_exists(GFVariantData.get_option_string(member, "path")):
			result += 1
	return result


func _make_delete_metadata_worker_failure(
	error_code: Error,
	existing_member_count: int
) -> Dictionary:
	var failure_kind: GFStorageDeleteResult.FailureKind = (
		GFStorageDeleteResult.FailureKind.CONFLICT
		if error_code == ERR_FILE_CORRUPT
		else GFStorageDeleteResult.FailureKind.IO_FAILED
	)
	return _make_delete_worker_result(
		error_code,
		failure_kind,
		existing_member_count,
		0,
		existing_member_count,
		GFStorageDeleteResult.FamilyMember.FAMILY_METADATA
	)


func _validate_delete_transaction_evidence(
	logical_name: String,
	descriptor: Dictionary
) -> Error:
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	if family_path.is_empty():
		return ERR_INVALID_PARAMETER
	if _absolute_storage_leaf_exists(family_path):
		if (
			_absolute_storage_path_is_link(family_path)
			or not DirAccess.dir_exists_absolute(family_path)
		):
			return ERR_FILE_CORRUPT
	else:
		return OK
	var evidence: Array[Dictionary] = [
		{
			"path": GFVariantData.get_option_string(descriptor, "transaction_pending_path"),
			"committed": false,
			"phase": &"prepare",
		},
		{
			"path": GFVariantData.get_option_string(descriptor, "transaction_path"),
			"committed": false,
			"phase": &"prepare",
		},
		{
			"path": GFVariantData.get_option_string(
				descriptor,
				"transaction_commit_pending_path"
			),
			"committed": true,
			"phase": &"commit",
		},
		{
			"path": GFVariantData.get_option_string(descriptor, "transaction_commit_path"),
			"committed": true,
			"phase": &"commit",
		},
	]
	var prepare_reference: Dictionary = {}
	var commit_reference: Dictionary = {}
	for evidence_entry: Dictionary in evidence:
		var evidence_path: String = GFVariantData.get_option_string(evidence_entry, "path")
		if _absolute_storage_path_is_link(evidence_path):
			return ERR_FILE_CORRUPT
		if not FileAccess.file_exists(evidence_path):
			continue
		var marker_read: Dictionary = _read_transaction_record_result_absolute(evidence_path)
		var marker_error: Error = GFVariantData.get_option_int(
			marker_read,
			"error",
			ERR_FILE_CORRUPT
		) as Error
		if marker_error != OK:
			return marker_error
		var marker: Dictionary = GFVariantData.get_option_dictionary(marker_read, "record")
		var expected_committed: bool = GFVariantData.get_option_bool(
			evidence_entry,
			"committed"
		)
		if (
			marker.is_empty()
			or not _is_valid_single_file_transaction_marker(marker, logical_name)
			or GFVariantData.get_option_bool(marker, "committed") != expected_committed
		):
			return ERR_FILE_CORRUPT
		var phase: StringName = GFVariantData.get_option_string_name(evidence_entry, "phase")
		if phase == &"prepare":
			if prepare_reference.is_empty():
				prepare_reference = marker
			elif not _single_transaction_records_match(
				prepare_reference,
				marker,
				logical_name
			):
				return ERR_FILE_CORRUPT
		else:
			if commit_reference.is_empty():
				commit_reference = marker
			elif not _single_transaction_records_match(
				commit_reference,
				marker,
				logical_name
			):
				return ERR_FILE_CORRUPT
	if (
		not prepare_reference.is_empty()
		and not commit_reference.is_empty()
		and not _single_transaction_snapshots_match(
			prepare_reference,
			commit_reference,
			logical_name
		)
	):
		return ERR_FILE_CORRUPT
	return OK


func _single_transaction_snapshots_match(
	prepare_record: Dictionary,
	commit_record: Dictionary,
	logical_name: String
) -> bool:
	return (
		_is_valid_single_file_transaction_marker(prepare_record, logical_name)
		and _is_valid_single_file_transaction_marker(commit_record, logical_name)
		and not GFVariantData.get_option_bool(prepare_record, "committed")
		and GFVariantData.get_option_bool(commit_record, "committed")
		and GFVariantData.get_option_string(prepare_record, "transaction_id")
		== GFVariantData.get_option_string(commit_record, "transaction_id")
		and GFVariantData.get_option_dictionary(prepare_record, "owner")
		== GFVariantData.get_option_dictionary(commit_record, "owner")
		and GFVariantData.get_option_array(prepare_record, "members")
		== GFVariantData.get_option_array(commit_record, "members")
	)


func _make_delete_worker_result(
	error_code: Error,
	failure_kind: GFStorageDeleteResult.FailureKind,
	existing_member_count: int,
	removed_member_count: int,
	remaining_member_count: int,
	failed_member: GFStorageDeleteResult.FamilyMember
) -> Dictionary:
	return {
		"error_code": int(error_code),
		"failure_kind": int(failure_kind),
		"existing_member_count": existing_member_count,
		"removed_member_count": removed_member_count,
		"remaining_member_count": remaining_member_count,
		"failed_member": int(failed_member),
	}


func _resume_pending_reset_for_file(
	storage_root_path: String,
	logical_name: String
) -> Error:
	var result: Dictionary = _resume_pending_reset_for_file_result(
		storage_root_path,
		logical_name
	)
	return GFVariantData.get_option_int(result, "error", ERR_BUG) as Error


func _resume_pending_reset_for_file_result(
	storage_root_path: String,
	logical_name: String
) -> Dictionary:
	var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
		storage_root_path,
		logical_name
	)
	if descriptor.is_empty():
		return {"error": int(ERR_INVALID_PARAMETER), "target_provenance": false}
	var family_store: GFStorageFamilyStore = _GF_STORAGE_FAMILY_STORE_SCRIPT.new()
	if not family_store.configure_for_framework(storage_root_path):
		return {"error": int(ERR_INVALID_PARAMETER), "target_provenance": false}
	var ancestry_error: Error = _validate_reset_mutation_ancestry(
		storage_root_path,
		descriptor
	)
	if ancestry_error != OK:
		return {"error": int(ancestry_error), "target_provenance": false}
	var layout_inspection: Dictionary = family_store.inspect_layout_for_reset_for_framework()
	var layout_status: StringName = GFVariantData.get_option_string_name(
		layout_inspection,
		"status"
	)
	if layout_status == &"missing":
		return {"error": int(OK), "target_provenance": false}
	if layout_status == &"future":
		return {"error": int(ERR_UNAVAILABLE), "target_provenance": false}
	if layout_status == &"corrupt":
		return {"error": int(ERR_FILE_CORRUPT), "target_provenance": false}
	if layout_status != &"current":
		var layout_error: Error = GFVariantData.get_option_int(
			layout_inspection,
			"error",
			ERR_FILE_CANT_READ
		) as Error
		return {"error": int(layout_error), "target_provenance": false}
	var intent_lookup: Dictionary = _find_reset_intent(descriptor)
	var lookup_error: Error = GFVariantData.get_option_int(
		intent_lookup,
		"error",
		ERR_FILE_CORRUPT
	) as Error
	if lookup_error != OK:
		return {"error": int(lookup_error), "target_provenance": true}
	if not GFVariantData.get_option_bool(intent_lookup, "exists"):
		return {"error": int(OK), "target_provenance": true}
	var worker_result: Dictionary = _reset_file_family_thread(
		storage_root_path,
		logical_name
	)
	var worker_reset_result: GFStorageFamilyResetResult = (
		_make_reset_result_from_worker(worker_result)
	)
	return {
		"error": int(worker_reset_result.get_error_code()),
		"target_provenance": (
			worker_reset_result.get_error_code() == OK
			or (
				worker_reset_result.get_failed_member()
				!= GFStorageFamilyResetResult.FamilyMember.LAYOUT
			)
		),
	}


func _reset_file_family_thread(
	storage_root_path: String,
	logical_name: String,
	expected_observation_token: String = ""
) -> Dictionary:
	var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
		storage_root_path,
		logical_name
	)
	if descriptor.is_empty():
		return _make_reset_worker_result(
			ERR_INVALID_PARAMETER,
			GFStorageFamilyResetResult.FailureKind.INVALID_REQUEST,
			GFStorageFamilyResetResult.SourceKind.UNKNOWN,
			GFStorageFamilyResetResult.Phase.PREFLIGHT,
			0,
			0,
			0,
			GFStorageFamilyResetResult.FamilyMember.NONE
		)
	if (
		not expected_observation_token.is_empty()
		and _make_family_observation_token(logical_name, storage_root_path)
		!= expected_observation_token
	):
		return _make_reset_worker_result(
			ERR_UNAUTHORIZED,
			GFStorageFamilyResetResult.FailureKind.UNAUTHORIZED,
			GFStorageFamilyResetResult.SourceKind.UNKNOWN,
			GFStorageFamilyResetResult.Phase.PREFLIGHT,
			0,
			0,
			0,
			GFStorageFamilyResetResult.FamilyMember.NONE
		)
	var family_store: GFStorageFamilyStore = _GF_STORAGE_FAMILY_STORE_SCRIPT.new()
	if not family_store.configure_for_framework(storage_root_path):
		return _make_reset_worker_result(
			ERR_INVALID_PARAMETER,
			GFStorageFamilyResetResult.FailureKind.INVALID_REQUEST,
			GFStorageFamilyResetResult.SourceKind.UNKNOWN,
			GFStorageFamilyResetResult.Phase.PREFLIGHT,
			0,
			0,
			0,
			GFStorageFamilyResetResult.FamilyMember.NONE
		)
	var ancestry_error: Error = _validate_reset_mutation_ancestry(
		storage_root_path,
		descriptor
	)
	if ancestry_error != OK:
		return _make_reset_worker_result(
			ancestry_error,
			GFStorageFamilyResetResult.FailureKind.CONFLICT,
			GFStorageFamilyResetResult.SourceKind.UNKNOWN,
			GFStorageFamilyResetResult.Phase.PREFLIGHT,
			0,
			0,
			0,
			GFStorageFamilyResetResult.FamilyMember.LAYOUT
		)

	var layout_inspection: Dictionary = family_store.inspect_layout_for_reset_for_framework()
	var layout_status: StringName = GFVariantData.get_option_string_name(
		layout_inspection,
		"status"
	)
	var layout_error: Error = GFVariantData.get_option_int(
		layout_inspection,
		"error",
		ERR_FILE_CORRUPT
	) as Error
	match layout_status:
		&"current":
			pass
		&"missing":
			return _make_reset_worker_result(
				ERR_FILE_NOT_FOUND,
				GFStorageFamilyResetResult.FailureKind.NOT_FOUND,
				GFStorageFamilyResetResult.SourceKind.MISSING,
				GFStorageFamilyResetResult.Phase.PREFLIGHT,
				0,
				0,
				0,
				GFStorageFamilyResetResult.FamilyMember.NONE
			)
		&"future":
			return _make_reset_worker_result(
				ERR_UNAVAILABLE,
				GFStorageFamilyResetResult.FailureKind.UNSUPPORTED_LAYOUT,
				GFStorageFamilyResetResult.SourceKind.UNKNOWN,
				GFStorageFamilyResetResult.Phase.PREFLIGHT,
				0,
				0,
				0,
				GFStorageFamilyResetResult.FamilyMember.LAYOUT
			)
		&"corrupt":
			return _make_reset_worker_result(
				ERR_FILE_CORRUPT,
				GFStorageFamilyResetResult.FailureKind.CONFLICT,
				GFStorageFamilyResetResult.SourceKind.UNKNOWN,
				GFStorageFamilyResetResult.Phase.PREFLIGHT,
				0,
				0,
				0,
				GFStorageFamilyResetResult.FamilyMember.LAYOUT
			)
		_:
			return _make_reset_worker_result(
				layout_error,
				GFStorageFamilyResetResult.FailureKind.IO_FAILED,
				GFStorageFamilyResetResult.SourceKind.UNKNOWN,
				GFStorageFamilyResetResult.Phase.PREFLIGHT,
				0,
				0,
				0,
				GFStorageFamilyResetResult.FamilyMember.LAYOUT
			)

	var intent_lookup: Dictionary = _find_reset_intent(descriptor)
	var intent_error: Error = GFVariantData.get_option_int(
		intent_lookup,
		"error",
		ERR_FILE_CORRUPT
	) as Error
	if intent_error != OK:
		return _make_reset_worker_result(
			intent_error,
			(
				GFStorageFamilyResetResult.FailureKind.CONFLICT
				if intent_error == ERR_FILE_CORRUPT
				else GFStorageFamilyResetResult.FailureKind.IO_FAILED
			),
			GFStorageFamilyResetResult.SourceKind.UNKNOWN,
			GFStorageFamilyResetResult.Phase.PREFLIGHT,
			0,
			0,
			_count_reset_evidence(descriptor, {}),
			GFStorageFamilyResetResult.FamilyMember.RESET_INTENT
		)
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	var has_exact_catalog: bool = _absolute_storage_leaf_exists(catalog_path)
	var has_exact_family: bool = _absolute_storage_leaf_exists(family_path)
	var has_existing_intent: bool = GFVariantData.get_option_bool(intent_lookup, "exists")
	var resuming_existing_intent: bool = has_existing_intent
	if not has_existing_intent and not has_exact_catalog and not has_exact_family:
		return _make_reset_worker_result(
			ERR_FILE_NOT_FOUND,
			GFStorageFamilyResetResult.FailureKind.NOT_FOUND,
			GFStorageFamilyResetResult.SourceKind.MISSING,
			GFStorageFamilyResetResult.Phase.PREFLIGHT,
			0,
			0,
			0,
			GFStorageFamilyResetResult.FamilyMember.NONE
		)

	var source_kind: GFStorageFamilyResetResult.SourceKind
	var reset_id: String
	var intent_path: String
	var initial_retired_member_count: int = 0
	if has_existing_intent:
		reset_id = GFVariantData.get_option_string(intent_lookup, "reset_id")
		intent_path = GFVariantData.get_option_string(intent_lookup, "intent_path")
		var numeric_source_kind: int = GFVariantData.get_option_int(
			intent_lookup,
			"source_kind",
			GFStorageFamilyResetResult.SourceKind.UNKNOWN
		)
		if not GFStorageFamilyResetResult.SourceKind.values().has(numeric_source_kind):
			return _make_reset_worker_result(
				ERR_FILE_CORRUPT,
				GFStorageFamilyResetResult.FailureKind.CONFLICT,
				GFStorageFamilyResetResult.SourceKind.UNKNOWN,
				GFStorageFamilyResetResult.Phase.PREFLIGHT,
				0,
				0,
				_count_reset_evidence(descriptor, intent_lookup),
				GFStorageFamilyResetResult.FamilyMember.RESET_INTENT
			)
		source_kind = numeric_source_kind as GFStorageFamilyResetResult.SourceKind
		initial_retired_member_count = GFVariantData.get_option_int(
			intent_lookup,
			"initial_retired_member_count"
		)
	else:
		var multi_member_evidence: Dictionary = _inspect_multi_member_reset_evidence(
			logical_name,
			descriptor
		)
		if (
			GFVariantData.get_option_int(
				multi_member_evidence,
				"error",
				ERR_FILE_CORRUPT
			) == OK
			and not GFVariantData.get_option_bool(
				multi_member_evidence,
				"is_valid_multi"
			)
		):
			multi_member_evidence = (
				_inspect_reverse_multi_member_reset_evidence(
					storage_root_path,
					logical_name,
					descriptor
				)
			)
		var multi_member_error: Error = GFVariantData.get_option_int(
			multi_member_evidence,
			"error",
			ERR_FILE_CORRUPT
		) as Error
		if multi_member_error != OK:
			return _make_reset_worker_result(
				multi_member_error,
				GFStorageFamilyResetResult.FailureKind.IO_FAILED,
				GFStorageFamilyResetResult.SourceKind.UNKNOWN,
				GFStorageFamilyResetResult.Phase.PREFLIGHT,
				0,
				0,
				_count_reset_evidence(descriptor, {}),
				GFStorageFamilyResetResult.FamilyMember.MUTABLE_EVIDENCE
			)
		if GFVariantData.get_option_bool(multi_member_evidence, "is_valid_multi"):
			return _make_reset_worker_result(
				ERR_BUSY,
				GFStorageFamilyResetResult.FailureKind.CONFLICT,
				GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY,
				GFStorageFamilyResetResult.Phase.PREFLIGHT,
				0,
				0,
				_count_reset_evidence(descriptor, {}),
				GFStorageFamilyResetResult.FamilyMember.MUTABLE_EVIDENCE
			)
		var family_error: Error = family_store.validate_family_for_framework(descriptor)
		var evidence_error: Error = _validate_delete_transaction_evidence(
			logical_name,
			descriptor
		)
		if family_error not in [OK, ERR_FILE_NOT_FOUND, ERR_FILE_CORRUPT]:
			return _make_reset_worker_result(
				family_error,
				GFStorageFamilyResetResult.FailureKind.IO_FAILED,
				GFStorageFamilyResetResult.SourceKind.UNKNOWN,
				GFStorageFamilyResetResult.Phase.PREFLIGHT,
				0,
				0,
				_count_reset_evidence(descriptor, {}),
				GFStorageFamilyResetResult.FamilyMember.FAMILY_CONTAINER
			)
		if evidence_error not in [OK, ERR_FILE_CORRUPT]:
			return _make_reset_worker_result(
				evidence_error,
				GFStorageFamilyResetResult.FailureKind.IO_FAILED,
				GFStorageFamilyResetResult.SourceKind.UNKNOWN,
				GFStorageFamilyResetResult.Phase.PREFLIGHT,
				0,
				0,
				_count_reset_evidence(descriptor, {}),
				GFStorageFamilyResetResult.FamilyMember.MUTABLE_EVIDENCE
			)
		source_kind = (
			GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY
			if family_error == OK and evidence_error == OK
			else GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY
		)
		reset_id = GFUuid.generate_v4()
		intent_path = _make_reset_intent_path(descriptor, reset_id)
		initial_retired_member_count = int(has_exact_catalog) + int(has_exact_family)
		var intent: Dictionary = _make_reset_intent(
			descriptor,
			reset_id,
			source_kind,
			initial_retired_member_count
		)
		var publish_error: Error = _publish_reset_intent(intent_path, intent)
		if publish_error != OK:
			return _make_reset_worker_result(
				publish_error,
				GFStorageFamilyResetResult.FailureKind.IO_FAILED,
				source_kind,
				GFStorageFamilyResetResult.Phase.RETIRE,
				0,
				0,
				_count_reset_evidence(descriptor, {}),
				GFStorageFamilyResetResult.FamilyMember.RESET_INTENT
			)
		intent_lookup = {
			"error": int(OK),
			"exists": true,
			"reset_id": reset_id,
			"intent_path": intent_path,
			"source_kind": int(source_kind),
			"initial_retired_member_count": initial_retired_member_count,
		}

	var retired_paths: Dictionary = _make_reset_retired_paths(descriptor, reset_id)
	var retired_catalog_path: String = GFVariantData.get_option_string(
		retired_paths,
		"catalog_path"
	)
	var retired_family_path: String = GFVariantData.get_option_string(
		retired_paths,
		"family_path"
	)
	if retired_catalog_path.is_empty() or retired_family_path.is_empty():
		return _make_reset_worker_result(
			ERR_INVALID_PARAMETER,
			GFStorageFamilyResetResult.FailureKind.INVALID_REQUEST,
			source_kind,
			GFStorageFamilyResetResult.Phase.RETIRE,
			0,
			0,
			_count_reset_evidence(descriptor, intent_lookup),
			GFStorageFamilyResetResult.FamilyMember.RESET_INTENT
		)

	var retired_family_exists: bool = _absolute_storage_leaf_exists(retired_family_path)
	var retired_catalog_exists: bool = _absolute_storage_leaf_exists(retired_catalog_path)
	var exact_claim_state: Dictionary = (
		family_store.inspect_reset_claim_for_framework(descriptor)
		if resuming_existing_intent
		else {}
	)
	var exact_is_fresh: bool = (
		resuming_existing_intent
		and GFVariantData.get_option_int(exact_claim_state, "error", FAILED) == OK
		and GFVariantData.get_option_string_name(exact_claim_state, "state") == &"complete"
	)
	var retired_member_count: int = (
		initial_retired_member_count
		if exact_is_fresh
		else int(retired_family_exists) + int(retired_catalog_exists)
	)
	var moved_family_now: bool = false
	if (
		not exact_is_fresh
		and not retired_family_exists
		and _absolute_storage_leaf_exists(family_path)
	):
		var move_family_error: Error = move_reset_family_member_for_framework(
			_RESET_MEMBER_FAMILY_CONTAINER,
			family_path,
			retired_family_path
		)
		if move_family_error != OK:
			return _make_reset_worker_result(
				move_family_error,
				GFStorageFamilyResetResult.FailureKind.IO_FAILED,
				source_kind,
				GFStorageFamilyResetResult.Phase.RETIRE,
				retired_member_count,
				0,
				_count_reset_evidence(descriptor, intent_lookup),
				GFStorageFamilyResetResult.FamilyMember.FAMILY_CONTAINER
			)
		retired_family_exists = true
		moved_family_now = true
		retired_member_count += 1
	if (
		not exact_is_fresh
		and not retired_catalog_exists
		and _absolute_storage_leaf_exists(catalog_path)
	):
		var move_catalog_error: Error = move_reset_family_member_for_framework(
			_RESET_MEMBER_CATALOG,
			catalog_path,
			retired_catalog_path
		)
		if move_catalog_error != OK:
			if moved_family_now:
				var _rollback_error: Error = move_reset_family_member_for_framework(
					_RESET_MEMBER_FAMILY_CONTAINER,
					retired_family_path,
					family_path
				)
			return _make_reset_worker_result(
				move_catalog_error,
				GFStorageFamilyResetResult.FailureKind.IO_FAILED,
				source_kind,
				GFStorageFamilyResetResult.Phase.RETIRE,
				_count_existing_reset_retired_roots(retired_paths),
				0,
				_count_reset_evidence(descriptor, intent_lookup),
				GFStorageFamilyResetResult.FamilyMember.CATALOG
			)
		retired_catalog_exists = true
		retired_member_count += 1

	var recreated_member_count: int = 0
	if not exact_is_fresh:
		var preclaim_state: Dictionary = (
			family_store.inspect_reset_claim_for_framework(descriptor)
		)
		var preclaim_state_name: StringName = GFVariantData.get_option_string_name(
			preclaim_state,
			"state"
		)
		var preclaim_error: Error = GFVariantData.get_option_int(
			preclaim_state,
			"error",
			ERR_FILE_CORRUPT
		) as Error
		if preclaim_error != OK or preclaim_state_name not in [&"empty", &"owner_only"]:
			recreated_member_count = clampi(
				GFVariantData.get_option_int(
					preclaim_state,
					"recreated_member_count"
				),
				0,
				3
			)
			return _make_reset_worker_result(
				ERR_FILE_CORRUPT if preclaim_error == OK else preclaim_error,
				(
					GFStorageFamilyResetResult.FailureKind.CONFLICT
					if preclaim_error in [OK, ERR_FILE_CORRUPT]
					else GFStorageFamilyResetResult.FailureKind.IO_FAILED
				),
				source_kind,
				GFStorageFamilyResetResult.Phase.RECREATE,
				retired_member_count,
				recreated_member_count,
				_count_reset_evidence(descriptor, intent_lookup),
				_reset_failed_member_from_claim_state(
					GFVariantData.get_option_string_name(
						preclaim_state,
						"failed_member"
					)
				)
			)
		var recreate_error: Error = claim_reset_family_for_framework(
			family_store,
			descriptor
		)
		if recreate_error != OK:
			var recreated_state: Dictionary = (
				family_store.inspect_reset_claim_for_framework(descriptor)
			)
			recreated_member_count = clampi(
				GFVariantData.get_option_int(
					recreated_state,
					"recreated_member_count"
				),
				0,
				3
			)
			var failed_member: GFStorageFamilyResetResult.FamilyMember = (
				_reset_failed_member_from_claim_state(
					GFVariantData.get_option_string_name(
						recreated_state,
						"failed_member"
					)
				)
			)
			return _make_reset_worker_result(
				recreate_error,
				(
					GFStorageFamilyResetResult.FailureKind.CONFLICT
					if recreate_error == ERR_FILE_CORRUPT
					else GFStorageFamilyResetResult.FailureKind.IO_FAILED
				),
				source_kind,
				GFStorageFamilyResetResult.Phase.RECREATE,
				retired_member_count,
				recreated_member_count,
				_count_reset_evidence(descriptor, intent_lookup),
				failed_member
			)
	var completed_claim_state: Dictionary = (
		family_store.inspect_reset_claim_for_framework(descriptor)
	)
	var completed_claim_error: Error = GFVariantData.get_option_int(
		completed_claim_state,
		"error",
		ERR_FILE_CORRUPT
	) as Error
	if (
		completed_claim_error != OK
		or GFVariantData.get_option_string_name(
			completed_claim_state,
			"state"
		) != &"complete"
	):
		recreated_member_count = clampi(
			GFVariantData.get_option_int(
				completed_claim_state,
				"recreated_member_count"
			),
			0,
			3
		)
		return _make_reset_worker_result(
			ERR_FILE_CORRUPT if completed_claim_error == OK else completed_claim_error,
			(
				GFStorageFamilyResetResult.FailureKind.CONFLICT
				if completed_claim_error in [OK, ERR_FILE_CORRUPT]
				else GFStorageFamilyResetResult.FailureKind.IO_FAILED
			),
			source_kind,
			GFStorageFamilyResetResult.Phase.RECREATE,
			retired_member_count,
			recreated_member_count,
			_count_reset_evidence(descriptor, intent_lookup),
			_reset_failed_member_from_claim_state(
				GFVariantData.get_option_string_name(
					completed_claim_state,
					"failed_member"
				)
			)
		)
	recreated_member_count = 3

	if _absolute_storage_leaf_exists(retired_family_path):
		var cleanup_family_error: Error = remove_reset_family_member_for_framework(
			_RESET_MEMBER_FAMILY_CONTAINER,
			retired_family_path
		)
		if cleanup_family_error != OK:
			return _make_reset_worker_result(
				cleanup_family_error,
				GFStorageFamilyResetResult.FailureKind.IO_FAILED,
				source_kind,
				GFStorageFamilyResetResult.Phase.CLEANUP,
				retired_member_count,
				recreated_member_count,
				_count_reset_evidence(descriptor, intent_lookup, true),
				GFStorageFamilyResetResult.FamilyMember.FAMILY_CONTAINER
			)
	if _absolute_storage_leaf_exists(retired_catalog_path):
		var cleanup_catalog_error: Error = remove_reset_family_member_for_framework(
			_RESET_MEMBER_CATALOG,
			retired_catalog_path
		)
		if cleanup_catalog_error != OK:
			return _make_reset_worker_result(
				cleanup_catalog_error,
				GFStorageFamilyResetResult.FailureKind.IO_FAILED,
				source_kind,
				GFStorageFamilyResetResult.Phase.CLEANUP,
				retired_member_count,
				recreated_member_count,
				_count_reset_evidence(descriptor, intent_lookup, true),
				GFStorageFamilyResetResult.FamilyMember.CATALOG
			)
	var cleanup_intent_error: Error = remove_reset_family_member_for_framework(
		_RESET_MEMBER_INTENT,
		intent_path
	)
	if cleanup_intent_error != OK:
		return _make_reset_worker_result(
			cleanup_intent_error,
			GFStorageFamilyResetResult.FailureKind.IO_FAILED,
			source_kind,
			GFStorageFamilyResetResult.Phase.CLEANUP,
			retired_member_count,
			recreated_member_count,
			_count_reset_evidence(descriptor, intent_lookup, true),
			GFStorageFamilyResetResult.FamilyMember.RESET_INTENT
		)
	return _make_reset_worker_result(
		OK,
		GFStorageFamilyResetResult.FailureKind.NONE,
		source_kind,
		GFStorageFamilyResetResult.Phase.NONE,
		retired_member_count,
		recreated_member_count,
		0,
		GFStorageFamilyResetResult.FamilyMember.NONE
	)


func _make_reset_worker_result(
	error_code: Error,
	failure_kind: GFStorageFamilyResetResult.FailureKind,
	source_kind: GFStorageFamilyResetResult.SourceKind,
	failed_phase: GFStorageFamilyResetResult.Phase,
	retired_member_count: int,
	recreated_member_count: int,
	remaining_evidence_count: int,
	failed_member: GFStorageFamilyResetResult.FamilyMember
) -> Dictionary:
	return {
		"error_code": int(error_code),
		"failure_kind": int(failure_kind),
		"source_kind": int(source_kind),
		"failed_phase": int(failed_phase),
		"retired_member_count": clampi(retired_member_count, 0, 2),
		"recreated_member_count": clampi(recreated_member_count, 0, 3),
		"remaining_evidence_count": clampi(remaining_evidence_count, 0, 5),
		"failed_member": int(failed_member),
	}


func _make_reset_intent(
	descriptor: Dictionary,
	reset_id: String,
	source_kind: GFStorageFamilyResetResult.SourceKind,
	initial_retired_member_count: int
) -> Dictionary:
	return {
		"schema": _RESET_INTENT_SCHEMA,
		"schema_version": _RESET_INTENT_SCHEMA_VERSION,
		"reset_id": reset_id,
		"logical_path": GFVariantData.get_option_string(descriptor, "logical_path"),
		"logical_sha256": GFVariantData.get_option_string(descriptor, "logical_sha256"),
		"family_id": GFVariantData.get_option_string(descriptor, "family_id"),
		"source_kind": int(source_kind),
		"initial_retired_member_count": initial_retired_member_count,
	}


func _make_reset_intent_path(descriptor: Dictionary, reset_id: String) -> String:
	if not GFUuid.is_valid(reset_id, 4):
		return ""
	return (
		GFVariantData.get_option_string(descriptor, "family_path")
		+ _RESET_STAGING_SEPARATOR
		+ reset_id
		+ _RESET_INTENT_SUFFIX
	)


func _make_reset_retired_paths(descriptor: Dictionary, reset_id: String) -> Dictionary:
	if not GFUuid.is_valid(reset_id, 4):
		return {}
	var suffix: String = _RESET_STAGING_SEPARATOR + reset_id
	return {
		"catalog_path": GFVariantData.get_option_string(descriptor, "catalog_path") + suffix,
		"family_path": GFVariantData.get_option_string(descriptor, "family_path") + suffix,
	}


static func _reset_id_from_intent_leaf(leaf_name: String, prefix: String) -> String:
	if prefix.is_empty() or not leaf_name.begins_with(prefix):
		return ""
	var pending_marker: String = _RESET_INTENT_SUFFIX + ".pending-"
	var pending_index: int = leaf_name.find(pending_marker)
	var exact_leaf: String = leaf_name
	if pending_index >= 0:
		var pending_id: String = leaf_name.substr(
			pending_index + pending_marker.length()
		)
		if not GFUuid.is_valid(pending_id, 4):
			return ""
		exact_leaf = leaf_name.substr(0, pending_index) + _RESET_INTENT_SUFFIX
	if not exact_leaf.ends_with(_RESET_INTENT_SUFFIX):
		return ""
	var reset_id: String = exact_leaf.trim_prefix(prefix).trim_suffix(
		_RESET_INTENT_SUFFIX
	)
	return reset_id if GFUuid.is_valid(reset_id, 4) else ""


func _publish_reset_intent(path: String, intent: Dictionary) -> Error:
	if path.is_empty() or not _is_valid_reset_intent(intent):
		return ERR_INVALID_PARAMETER
	if FileAccess.file_exists(path):
		return (
			OK
			if _reset_intents_match(_read_reset_intent(path), intent)
			else ERR_FILE_CORRUPT
		)
	var parent_error: Error = _ensure_directory_absolute(path.get_base_dir())
	if parent_error != OK:
		return parent_error
	var pending_path: String = path + ".pending-" + GFUuid.generate_v4()
	var file: FileAccess = FileAccess.open(pending_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var _stored: bool = file.store_string(JSON.stringify(intent, "\t")) != null
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		var _pending_cleanup_error: Error = _remove_absolute_file(pending_path)
		return write_error
	if not _reset_intents_match(_read_reset_intent(pending_path), intent):
		var _invalid_cleanup_error: Error = _remove_absolute_file(pending_path)
		return ERR_FILE_CORRUPT
	var publish_error: Error = DirAccess.rename_absolute(pending_path, path)
	if publish_error == OK:
		return OK
	if (
		FileAccess.file_exists(path)
		and _reset_intents_match(_read_reset_intent(path), intent)
	):
		var _race_cleanup_error: Error = _remove_absolute_file(pending_path)
		return OK
	return publish_error


func _find_reset_intent(descriptor: Dictionary) -> Dictionary:
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	var family_parent: String = family_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(family_parent):
		return {"error": int(OK), "exists": false}
	var directory: DirAccess = DirAccess.open(family_parent)
	if directory == null:
		return {"error": int(ERR_FILE_CANT_OPEN), "exists": false}
	var begin_error: Error = directory.list_dir_begin()
	if begin_error != OK:
		return {"error": int(begin_error), "exists": false}
	var prefix: String = family_path.get_file() + _RESET_STAGING_SEPARATOR
	var pending_marker: String = _RESET_INTENT_SUFFIX + ".pending-"
	var exact_candidates: Array[String] = []
	var pending_candidates: Array[String] = []
	var target_candidate_count: int = 0
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var is_target_like: bool = (
			entry.begins_with(prefix) and entry.contains(_RESET_INTENT_SUFFIX)
		)
		if not is_target_like:
			entry = directory.get_next()
			continue
		target_candidate_count += 1
		if target_candidate_count > _RESET_MAX_PENDING_INTENTS:
			directory.list_dir_end()
			return {"error": int(ERR_OUT_OF_MEMORY), "exists": false}
		var pending_marker_index: int = entry.find(pending_marker)
		var is_exact_intent: bool = (
			entry.begins_with(prefix) and entry.ends_with(_RESET_INTENT_SUFFIX)
		)
		var is_pending_intent: bool = (
			entry.begins_with(prefix)
			and pending_marker_index > prefix.length()
			and GFUuid.is_valid(
				entry.substr(pending_marker_index + pending_marker.length()),
				4
			)
		)
		if (
			not is_exact_intent
			and not is_pending_intent
			or directory.is_link(entry)
			or directory.current_is_dir()
		):
			directory.list_dir_end()
			return {"error": int(ERR_FILE_CORRUPT), "exists": false}
		if is_exact_intent:
			if not exact_candidates.is_empty():
				directory.list_dir_end()
				return {"error": int(ERR_FILE_CORRUPT), "exists": false}
			exact_candidates.append(family_parent.path_join(entry))
		else:
			pending_candidates.append(family_parent.path_join(entry))
		entry = directory.get_next()
	directory.list_dir_end()
	exact_candidates.sort()
	pending_candidates.sort()
	if exact_candidates.is_empty() and pending_candidates.is_empty():
		return {"error": int(OK), "exists": false}
	var records: Array[Dictionary] = []
	for candidate_path: String in exact_candidates + pending_candidates:
		var leaf_name: String = candidate_path.get_file()
		var pending_index: int = leaf_name.find(pending_marker)
		var is_pending: bool = pending_index >= 0
		var exact_leaf: String = (
			leaf_name.substr(0, pending_index) + _RESET_INTENT_SUFFIX
			if is_pending
			else leaf_name
		)
		var reset_id: String = exact_leaf.trim_prefix(prefix).trim_suffix(
			_RESET_INTENT_SUFFIX
		)
		var intent: Dictionary = _read_reset_intent(candidate_path)
		if (
			not GFUuid.is_valid(reset_id, 4)
			or not _reset_intent_matches_descriptor(intent, descriptor, reset_id)
		):
			if is_pending:
				var cleanup_staging_error: Error = _remove_absolute_file(candidate_path)
				if cleanup_staging_error != OK:
					return {"error": int(cleanup_staging_error), "exists": false}
				continue
			return {"error": int(ERR_FILE_CORRUPT), "exists": false}
		records.append({
			"path": candidate_path,
			"exact_path": family_parent.path_join(exact_leaf),
			"reset_id": reset_id,
			"intent": intent,
			"pending": is_pending,
		})
	if records.is_empty():
		return {"error": int(OK), "exists": false}
	var canonical_record: Dictionary = records[0]
	var canonical_reset_id: String = GFVariantData.get_option_string(
		canonical_record,
		"reset_id"
	)
	var canonical_intent: Dictionary = GFVariantData.get_option_dictionary(
		canonical_record,
		"intent"
	)
	for record: Dictionary in records:
		if (
			GFVariantData.get_option_string(record, "reset_id") != canonical_reset_id
			or not _reset_intents_match(
				GFVariantData.get_option_dictionary(record, "intent"),
				canonical_intent
			)
		):
			return {"error": int(ERR_FILE_CORRUPT), "exists": false}

	var intent_path: String = (
		exact_candidates[0]
		if not exact_candidates.is_empty()
		else GFVariantData.get_option_string(canonical_record, "exact_path")
	)
	if exact_candidates.is_empty():
		var source_pending_path: String = GFVariantData.get_option_string(
			canonical_record,
			"path"
		)
		var publish_error: Error = DirAccess.rename_absolute(
			source_pending_path,
			intent_path
		)
		if publish_error != OK:
			if (
				not FileAccess.file_exists(intent_path)
				or not _reset_intents_match(
					_read_reset_intent(intent_path),
					canonical_intent
				)
			):
				return {"error": int(publish_error), "exists": false}
	for pending_path: String in pending_candidates:
		if not FileAccess.file_exists(pending_path):
			continue
		var cleanup_error: Error = _remove_absolute_file(pending_path)
		if cleanup_error != OK:
			return {"error": int(cleanup_error), "exists": false}
	return {
		"error": int(OK),
		"exists": true,
		"reset_id": canonical_reset_id,
		"intent_path": intent_path,
		"source_kind": GFVariantData.get_option_int(
			canonical_intent,
			"source_kind",
			GFStorageFamilyResetResult.SourceKind.UNKNOWN
		),
		"initial_retired_member_count": GFVariantData.get_option_int(
			canonical_intent,
			"initial_retired_member_count"
		),
	}


func _read_reset_intent(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var length: int = file.get_length()
	if length <= 0 or length > _RESET_MAX_INTENT_BYTES:
		file.close()
		return {}
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		return {}
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {}
	var intent: Dictionary = parser.data
	return intent if _is_valid_reset_intent(intent) else {}


static func _is_valid_reset_intent(intent: Dictionary) -> bool:
	if intent.size() != 8:
		return false
	var source_kind: int = GFVariantData.to_exact_int(intent.get("source_kind"), -1)
	var initial_retired_member_count: int = GFVariantData.to_exact_int(
		intent.get("initial_retired_member_count"),
		-1
	)
	return (
		intent.get("schema") is String
		and intent.get("schema") == _RESET_INTENT_SCHEMA
		and GFVariantData.to_exact_int(intent.get("schema_version"), -1)
		== _RESET_INTENT_SCHEMA_VERSION
		and intent.get("reset_id") is String
		and GFUuid.is_valid(GFVariantData.get_option_string(intent, "reset_id"), 4)
		and intent.get("logical_path") is String
		and intent.get("logical_sha256") is String
		and intent.get("family_id") is String
		and source_kind in [
			GFStorageFamilyResetResult.SourceKind.PAYLOAD_ONLY,
			GFStorageFamilyResetResult.SourceKind.STRUCTURAL_IDENTITY,
		]
		and initial_retired_member_count in [1, 2]
	)


func _reset_intent_matches_descriptor(
	intent: Dictionary,
	descriptor: Dictionary,
	reset_id: String
) -> bool:
	return (
		_is_valid_reset_intent(intent)
		and GFVariantData.get_option_string(intent, "reset_id") == reset_id
		and GFVariantData.get_option_string(intent, "logical_path")
		== GFVariantData.get_option_string(descriptor, "logical_path")
		and GFVariantData.get_option_string(intent, "logical_sha256")
		== GFVariantData.get_option_string(descriptor, "logical_sha256")
		and GFVariantData.get_option_string(intent, "family_id")
		== GFVariantData.get_option_string(descriptor, "family_id")
	)


static func _reset_intents_match(left: Dictionary, right: Dictionary) -> bool:
	return (
		_is_valid_reset_intent(left)
		and _is_valid_reset_intent(right)
		and GFVariantData.get_option_string(left, "schema")
		== GFVariantData.get_option_string(right, "schema")
		and GFVariantData.to_exact_int(left.get("schema_version"), -1)
		== GFVariantData.to_exact_int(right.get("schema_version"), -1)
		and GFVariantData.get_option_string(left, "reset_id")
		== GFVariantData.get_option_string(right, "reset_id")
		and GFVariantData.get_option_string(left, "logical_path")
		== GFVariantData.get_option_string(right, "logical_path")
		and GFVariantData.get_option_string(left, "logical_sha256")
		== GFVariantData.get_option_string(right, "logical_sha256")
		and GFVariantData.get_option_string(left, "family_id")
		== GFVariantData.get_option_string(right, "family_id")
		and GFVariantData.to_exact_int(left.get("source_kind"), -1)
		== GFVariantData.to_exact_int(right.get("source_kind"), -1)
		and GFVariantData.to_exact_int(left.get("initial_retired_member_count"), -1)
		== GFVariantData.to_exact_int(right.get("initial_retired_member_count"), -1)
	)


func _count_existing_reset_retired_roots(retired_paths: Dictionary) -> int:
	var count: int = 0
	var catalog_path: String = GFVariantData.get_option_string(retired_paths, "catalog_path")
	var family_path: String = GFVariantData.get_option_string(retired_paths, "family_path")
	if _absolute_storage_leaf_exists(catalog_path):
		count += 1
	if _absolute_storage_leaf_exists(family_path):
		count += 1
	return count


func _count_reset_evidence(
	descriptor: Dictionary,
	intent_lookup: Dictionary,
	exclude_recreated_exact_claim: bool = false
) -> int:
	var count: int = 0
	var catalog_path: String = GFVariantData.get_option_string(descriptor, "catalog_path")
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	if not exclude_recreated_exact_claim and _absolute_storage_leaf_exists(catalog_path):
		count += 1
	if not exclude_recreated_exact_claim and _absolute_storage_leaf_exists(family_path):
		count += 1
	count += _count_reset_intent_artifacts(descriptor)
	if GFVariantData.get_option_bool(intent_lookup, "exists"):
		var retired_paths: Dictionary = _make_reset_retired_paths(
			descriptor,
			GFVariantData.get_option_string(intent_lookup, "reset_id")
		)
		count += _count_existing_reset_retired_roots(retired_paths)
	return clampi(count, 0, 5)


func _count_reset_intent_artifacts(descriptor: Dictionary) -> int:
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	var family_parent: String = family_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(family_parent):
		return 0
	var directory: DirAccess = DirAccess.open(family_parent)
	if directory == null or directory.list_dir_begin() != OK:
		return 0
	var prefix: String = family_path.get_file() + _RESET_STAGING_SEPARATOR
	var count: int = 0
	var entry: String = directory.get_next()
	while not entry.is_empty():
		if (
			entry.begins_with(prefix)
			and (
				entry.contains(_RESET_INTENT_SUFFIX)
			)
		):
			count += 1
			if count >= 5:
				directory.list_dir_end()
				return 5
		entry = directory.get_next()
	directory.list_dir_end()
	return count


func _inspect_multi_member_reset_evidence(
	logical_name: String,
	descriptor: Dictionary
) -> Dictionary:
	var family_path: String = GFVariantData.get_option_string(descriptor, "family_path")
	if family_path.is_empty():
		return {"error": int(ERR_INVALID_PARAMETER), "is_valid_multi": false}
	if not _absolute_storage_leaf_exists(family_path):
		return {"error": int(OK), "is_valid_multi": false}
	if (
		_absolute_storage_path_is_link(family_path)
		or not DirAccess.dir_exists_absolute(family_path)
	):
		return {"error": int(OK), "is_valid_multi": false}
	for entry: Dictionary in [
		{"path": GFVariantData.get_option_string(descriptor, "transaction_pending_path"), "committed": false},
		{"path": GFVariantData.get_option_string(descriptor, "transaction_path"), "committed": false},
		{"path": GFVariantData.get_option_string(descriptor, "transaction_commit_pending_path"), "committed": true},
		{"path": GFVariantData.get_option_string(descriptor, "transaction_commit_path"), "committed": true},
	]:
		var path: String = GFVariantData.get_option_string(entry, "path")
		if _absolute_storage_path_is_link(path):
			continue
		if not FileAccess.file_exists(path):
			continue
		var marker_read: Dictionary = _read_transaction_record_result_absolute(path)
		var marker_error: Error = GFVariantData.get_option_int(
			marker_read,
			"error",
			ERR_FILE_CORRUPT
		) as Error
		if marker_error == ERR_FILE_CORRUPT:
			continue
		if marker_error != OK:
			return {"error": int(marker_error), "is_valid_multi": false}
		var marker: Dictionary = GFVariantData.get_option_dictionary(marker_read, "record")
		if _is_valid_multi_member_reset_marker(
			marker,
			logical_name,
			GFVariantData.get_option_bool(entry, "committed")
		):
			return {"error": int(OK), "is_valid_multi": true}
	return {"error": int(OK), "is_valid_multi": false}


func _get_reset_reverse_scan_entry_limit() -> int:
	return _RESET_MAX_REVERSE_SCAN_ENTRIES


func _inspect_reverse_multi_member_reset_evidence(
	storage_root_path: String,
	logical_name: String,
	target_descriptor: Dictionary
) -> Dictionary:
	var families_root: String = storage_root_path.path_join(
		".gf-storage/v1/families"
	)
	if not DirAccess.dir_exists_absolute(families_root):
		return {"error": int(OK), "is_valid_multi": false}
	var target_family_path: String = GFVariantData.get_option_string(
		target_descriptor,
		"family_path"
	)
	var entry_budget: Array[int] = [maxi(0, _get_reset_reverse_scan_entry_limit())]
	var first_level: Dictionary = _list_reset_recovery_shards(
		families_root,
		entry_budget
	)
	var first_error: Error = GFVariantData.get_option_int(
		first_level,
		"error",
		ERR_FILE_CANT_READ
	) as Error
	if first_error != OK:
		return {"error": int(first_error), "is_valid_multi": false}
	var first_entries: Array = GFVariantData.get_option_array(
		first_level,
		"entries"
	)
	var family_entry_count: int = 0
	for first_entry_value: Variant in first_entries:
		if not first_entry_value is Dictionary:
			return {"error": int(ERR_FILE_CORRUPT), "is_valid_multi": false}
		var first_entry: Dictionary = first_entry_value
		var first_name: String = GFVariantData.get_option_string(first_entry, "name")
		if (
			not _is_reset_shard_name(first_name)
			or not GFVariantData.get_option_bool(first_entry, "is_directory")
			or GFVariantData.get_option_bool(first_entry, "is_link")
		):
			return {"error": int(ERR_FILE_CORRUPT), "is_valid_multi": false}
		var second_root: String = families_root.path_join(first_name)
		var second_level: Dictionary = _list_reset_recovery_shards(
			second_root,
			entry_budget
		)
		var second_error: Error = GFVariantData.get_option_int(
			second_level,
			"error",
			ERR_FILE_CANT_READ
		) as Error
		if second_error != OK:
			return {"error": int(second_error), "is_valid_multi": false}
		var second_entries: Array = GFVariantData.get_option_array(
			second_level,
			"entries"
		)
		for second_entry_value: Variant in second_entries:
			if not second_entry_value is Dictionary:
				return {"error": int(ERR_FILE_CORRUPT), "is_valid_multi": false}
			var second_entry: Dictionary = second_entry_value
			var second_name: String = GFVariantData.get_option_string(
				second_entry,
				"name"
			)
			if (
				not _is_reset_shard_name(second_name)
				or not GFVariantData.get_option_bool(second_entry, "is_directory")
				or GFVariantData.get_option_bool(second_entry, "is_link")
			):
				return {"error": int(ERR_FILE_CORRUPT), "is_valid_multi": false}
			var family_parent: String = second_root.path_join(second_name)
			var family_directory: DirAccess = DirAccess.open(family_parent)
			if family_directory == null:
				return {"error": int(ERR_FILE_CANT_OPEN), "is_valid_multi": false}
			var begin_error: Error = family_directory.list_dir_begin()
			if begin_error != OK:
				return {"error": int(begin_error), "is_valid_multi": false}
			var family_leaf: String = family_directory.get_next()
			while not family_leaf.is_empty():
				family_entry_count += 1
				if family_entry_count > _RESET_MAX_TREE_ENTRIES:
					family_directory.list_dir_end()
					return {
						"error": int(ERR_OUT_OF_MEMORY),
						"is_valid_multi": false,
					}
				if not _consume_reset_scan_budget(entry_budget):
					family_directory.list_dir_end()
					return {
						"error": int(ERR_OUT_OF_MEMORY),
						"is_valid_multi": false,
					}
				var family_path: String = family_parent.path_join(family_leaf)
				var is_family_identity: bool = GFUuid.is_valid(family_leaf, 8)
				var compact_family_id: String = family_leaf.replace("-", "")
				var is_surviving_family: bool = (
					is_family_identity
					and family_path != target_family_path
				)
				if is_surviving_family and (
					compact_family_id.substr(0, 2) != first_name
					or compact_family_id.substr(2, 2) != second_name
				):
					family_directory.list_dir_end()
					return {
						"error": int(ERR_FILE_CORRUPT),
						"is_valid_multi": false,
					}
				if is_surviving_family and (
					not family_directory.current_is_dir()
					or family_directory.is_link(family_leaf)
				):
					family_directory.list_dir_end()
					return {
						"error": int(ERR_FILE_CORRUPT),
						"is_valid_multi": false,
					}
				if is_surviving_family:
					var surviving_evidence: Dictionary = (
						_inspect_surviving_family_for_reset_target(
							family_path,
							family_leaf,
							logical_name,
							entry_budget
						)
					)
					var surviving_error: Error = GFVariantData.get_option_int(
						surviving_evidence,
						"error",
						ERR_FILE_CORRUPT
					) as Error
					if surviving_error != OK:
						family_directory.list_dir_end()
						return {
							"error": int(surviving_error),
							"is_valid_multi": false,
						}
					if GFVariantData.get_option_bool(
						surviving_evidence,
						"is_valid_multi"
					):
						family_directory.list_dir_end()
						return {"error": int(OK), "is_valid_multi": true}
				family_leaf = family_directory.get_next()
			family_directory.list_dir_end()
	return {"error": int(OK), "is_valid_multi": false}


func _inspect_surviving_family_for_reset_target(
	family_path: String,
	owner_family_id: String,
	target_logical_name: String,
	entry_budget: Array[int]
) -> Dictionary:
	if entry_budget.is_empty():
		return {"error": int(ERR_INVALID_PARAMETER), "is_valid_multi": false}
	if (
		_absolute_storage_path_is_link(family_path)
		or not DirAccess.dir_exists_absolute(family_path)
	):
		return {"error": int(ERR_FILE_CORRUPT), "is_valid_multi": false}
	var committed_by_leaf: Dictionary = {
		"transaction.prepare.pending.json": false,
		"transaction.prepare.json": false,
		"transaction.commit.pending.json": true,
		"transaction.commit.json": true,
	}
	var directory: DirAccess = DirAccess.open(family_path)
	if directory == null:
		return {"error": int(ERR_FILE_CANT_OPEN), "is_valid_multi": false}
	var begin_error: Error = directory.list_dir_begin()
	if begin_error != OK:
		return {"error": int(begin_error), "is_valid_multi": false}
	var marker_entries: Array[Dictionary] = []
	var family_entry: String = directory.get_next()
	while not family_entry.is_empty():
		if not _consume_reset_scan_budget(entry_budget):
			directory.list_dir_end()
			return {"error": int(ERR_OUT_OF_MEMORY), "is_valid_multi": false}
		if committed_by_leaf.has(family_entry):
			if directory.current_is_dir() or directory.is_link(family_entry):
				directory.list_dir_end()
				return {"error": int(ERR_FILE_CORRUPT), "is_valid_multi": false}
			marker_entries.append({
				"leaf": family_entry,
				"committed": GFVariantData.get_option_bool(
					committed_by_leaf,
					family_entry
				),
			})
		family_entry = directory.get_next()
	directory.list_dir_end()
	marker_entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return GFVariantData.get_option_string(left, "leaf") < GFVariantData.get_option_string(
			right,
			"leaf"
		)
	)
	for marker_entry: Dictionary in marker_entries:
		var marker_path: String = family_path.path_join(
			GFVariantData.get_option_string(marker_entry, "leaf")
		)
		if _absolute_storage_path_is_link(marker_path):
			return {"error": int(ERR_FILE_CORRUPT), "is_valid_multi": false}
		var marker_read: Dictionary = _read_transaction_record_result_absolute(
			marker_path
		)
		var marker_error: Error = GFVariantData.get_option_int(
			marker_read,
			"error",
			ERR_FILE_CORRUPT
		) as Error
		if marker_error != OK:
			return {"error": int(marker_error), "is_valid_multi": false}
		var marker: Dictionary = GFVariantData.get_option_dictionary(
			marker_read,
			"record"
		)
		var owner: Dictionary = GFVariantData.get_option_dictionary(marker, "owner")
		var owner_logical_path: String = GFVariantData.get_option_string(
			owner,
			"logical_path"
		)
		var expected_committed: bool = GFVariantData.get_option_bool(
			marker_entry,
			"committed"
		)
		var committed_value: Variant = marker.get("committed")
		var valid_single: bool = (
			committed_value is bool
			and committed_value == expected_committed
			and _is_valid_single_file_transaction_marker(
				marker,
				owner_logical_path
			)
		)
		var valid_multi: bool = _is_valid_multi_member_transaction_marker(
			marker,
			expected_committed
		)
		if (
			GFVariantData.get_option_string(owner, "family_id") != owner_family_id
			or (not valid_single and not valid_multi)
		):
			return {"error": int(ERR_FILE_CORRUPT), "is_valid_multi": false}
		if valid_multi and _is_valid_multi_member_reset_marker(
			marker,
			target_logical_name,
			expected_committed
		):
			return {"error": int(OK), "is_valid_multi": true}
	return {"error": int(OK), "is_valid_multi": false}


static func _is_valid_multi_member_reset_marker(
	marker: Dictionary,
	logical_name: String,
	expected_committed: bool
) -> bool:
	if not _is_valid_multi_member_transaction_marker(marker, expected_committed):
		return false
	for member_value: Variant in GFVariantData.get_option_array(marker, "members"):
		if not member_value is Dictionary:
			return false
		var member: Dictionary = member_value
		if GFVariantData.get_option_string(member, "logical_path") == logical_name:
			return true
	return false


static func _is_valid_multi_member_transaction_marker(
	marker: Dictionary,
	expected_committed: bool
) -> bool:
	if marker.size() != 6:
		return false
	if not marker.get("committed") is bool or marker.get("committed") != expected_committed:
		return false
	var expected_schema: String = (
		_TRANSACTION_COMMIT_SCHEMA if expected_committed else _TRANSACTION_PREPARE_SCHEMA
	)
	if not marker.get("schema") is String or marker.get("schema") != expected_schema:
		return false
	if (
		GFVariantData.to_exact_int(marker.get("schema_version"), -1)
		!= _TRANSACTION_MARKER_SCHEMA_VERSION
		or not marker.get("transaction_id") is String
		or GFVariantData.get_option_string(marker, "transaction_id").is_empty()
		or not marker.get("owner") is Dictionary
		or not marker.get("members") is Array
	):
		return false
	var members: Array = GFVariantData.get_option_array(marker, "members")
	if members.size() <= 1 or members.size() > _MAX_TRANSACTION_FILES:
		return false
	var seen: Dictionary = {}
	var previous_member_path: String = ""
	for member_value: Variant in members:
		if not member_value is Dictionary:
			return false
		var member: Dictionary = member_value
		var member_path: String = GFVariantData.get_option_string(member, "logical_path")
		if (
			member.size() != 3
			or not GFStorageFamilyStore.is_valid_logical_file_path_for_framework(member_path)
			or seen.has(member_path)
			or (not previous_member_path.is_empty() and member_path <= previous_member_path)
			or GFVariantData.get_option_string(member, "family_id")
			!= GFStorageFamilyStore.make_family_id_for_framework(member_path)
			or not member.get("had_final") is bool
		):
			return false
		seen[member_path] = true
		previous_member_path = member_path
	var owner: Dictionary = GFVariantData.get_option_dictionary(marker, "owner")
	var owner_path: String = GFVariantData.get_option_string(owner, "logical_path")
	return (
		owner.size() == 2
		and seen.has(owner_path)
		and GFVariantData.get_option_string(owner, "family_id")
		== GFStorageFamilyStore.make_family_id_for_framework(owner_path)
	)


static func _consume_reset_scan_budget(
	entry_budget: Array[int],
	amount: int = 1
) -> bool:
	if entry_budget.is_empty() or amount < 0 or entry_budget[0] < amount:
		return false
	entry_budget[0] -= amount
	return true


func _remove_reset_tree(path: String, depth: int, entry_budget: Array[int]) -> Error:
	if path.is_empty() or entry_budget.is_empty() or depth > _RESET_MAX_TREE_DEPTH:
		return ERR_INVALID_PARAMETER
	if _absolute_storage_path_is_link(path):
		return DirAccess.remove_absolute(path)
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path)
	if not DirAccess.dir_exists_absolute(path):
		return OK
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return ERR_FILE_CANT_OPEN
	var begin_error: Error = directory.list_dir_begin()
	if begin_error != OK:
		return begin_error
	var entries: Array[Dictionary] = []
	var entry: String = directory.get_next()
	while not entry.is_empty():
		entry_budget[0] -= 1
		if entry_budget[0] < 0:
			directory.list_dir_end()
			return ERR_OUT_OF_MEMORY
		entries.append({
			"name": entry,
			"is_directory": directory.current_is_dir(),
			"is_link": directory.is_link(entry),
		})
		entry = directory.get_next()
	directory.list_dir_end()
	for entry_data: Dictionary in entries:
		var child_path: String = path.path_join(
			GFVariantData.get_option_string(entry_data, "name")
		)
		var remove_error: Error
		if GFVariantData.get_option_bool(entry_data, "is_link"):
			remove_error = DirAccess.remove_absolute(child_path)
		elif GFVariantData.get_option_bool(entry_data, "is_directory"):
			remove_error = _remove_reset_tree(child_path, depth + 1, entry_budget)
		else:
			remove_error = DirAccess.remove_absolute(child_path)
		if remove_error != OK:
			return remove_error
	return DirAccess.remove_absolute(path)


static func _absolute_storage_path_is_link(path: String) -> bool:
	var parent_path: String = path.get_base_dir()
	var leaf_name: String = path.get_file()
	if parent_path.is_empty() or leaf_name.is_empty():
		return false
	var parent: DirAccess = DirAccess.open(parent_path)
	return parent != null and parent.is_link(leaf_name)


static func _absolute_storage_leaf_exists(path: String) -> bool:
	return (
		FileAccess.file_exists(path)
		or DirAccess.dir_exists_absolute(path)
		or _absolute_storage_path_is_link(path)
	)


static func _validate_reset_mutation_ancestry(
	storage_root_path: String,
	descriptor: Dictionary
) -> Error:
	if (
		storage_root_path != "user://"
		and (
			not storage_root_path.begins_with("user://")
			or storage_root_path.ends_with("/")
		)
	):
		return ERR_INVALID_PARAMETER
	var target_directories: Array[String] = [
		storage_root_path,
		storage_root_path.path_join(".gf-storage"),
		storage_root_path.path_join(".gf-storage/v1"),
		storage_root_path.path_join(".gf-storage/v1/catalog"),
		storage_root_path.path_join(".gf-storage/v1/families"),
	]
	if not descriptor.is_empty():
		for key: String in ["catalog_path", "family_path"]:
			var identity_path: String = GFVariantData.get_option_string(descriptor, key)
			if identity_path.is_empty():
				return ERR_INVALID_PARAMETER
			target_directories.append(identity_path.get_base_dir())
	var visited: Dictionary = {}
	for target_directory: String in target_directories:
		var relative_path: String
		if storage_root_path == "user://":
			if not target_directory.begins_with("user://"):
				return ERR_INVALID_PARAMETER
			relative_path = target_directory.trim_prefix("user://")
		else:
			if (
				target_directory != storage_root_path
				and not target_directory.begins_with(storage_root_path + "/")
			):
				return ERR_INVALID_PARAMETER
			relative_path = target_directory.trim_prefix(storage_root_path).trim_prefix("/")
		var current_path: String = storage_root_path
		if current_path != "user://":
			var root_relative_path: String = current_path.trim_prefix("user://")
			current_path = "user://"
			for root_segment: String in root_relative_path.split("/", false):
				current_path = current_path.path_join(root_segment)
				var root_error: Error = _validate_reset_directory_component(
					current_path,
					visited
				)
				if root_error != OK:
					return root_error
		for segment: String in relative_path.split("/", false):
			current_path = current_path.path_join(segment)
			var component_error: Error = _validate_reset_directory_component(
				current_path,
				visited
			)
			if component_error != OK:
				return component_error
	return OK


static func _validate_reset_directory_component(
	path: String,
	visited: Dictionary
) -> Error:
	if visited.has(path):
		return OK
	visited[path] = true
	if _absolute_storage_path_is_link(path) or FileAccess.file_exists(path):
		return ERR_FILE_CORRUPT
	return OK


func _save_data_thread(
	file_name: String,
	final_path: String,
	temp_path: String,
	backup_path: String,
	transaction_path: String,
	transaction_pending_path: String,
	transaction_commit_path: String,
	transaction_commit_pending_path: String,
	transaction_id: String,
	data: Dictionary,
	codec_options: Dictionary
) -> Dictionary:
	var validation_report: Dictionary = _validate_thread_payload(data)
	if not GFVariantData.get_option_bool(validation_report, "ok"):
		return _make_thread_save_result(
			ERR_INVALID_DATA,
			GFStorageAsyncResult.WriteFailureKind.PAYLOAD_INVALID,
			validation_report
		)

	var dir_error: Error = _ensure_absolute_parent_directory(final_path)
	if dir_error != OK:
		return _make_thread_save_result(
			dir_error,
			GFStorageAsyncResult.WriteFailureKind.IO_FAILED,
			validation_report
		)

	var thread_codec: GFStorageCodec = GFStorageCodec.new()
	var bytes: PackedByteArray = thread_codec.encode(data, codec_options)
	if bytes.is_empty():
		return _make_thread_save_result(
			ERR_INVALID_DATA,
			GFStorageAsyncResult.WriteFailureKind.ENCODE_FAILED,
			validation_report
		)
	var had_final: bool = FileAccess.file_exists(final_path)
	var had_final_by_file: Dictionary = {file_name: had_final}
	var prepare_record: Dictionary = _make_transaction_marker(
		[file_name],
		file_name,
		transaction_id,
		false,
		had_final_by_file
	)
	var marker_error: Error = _publish_single_transaction_record_absolute(
		transaction_path,
		transaction_pending_path,
		prepare_record,
		file_name
	)
	if marker_error != OK:
		return _make_thread_save_result(
			marker_error,
			GFStorageAsyncResult.WriteFailureKind.IO_FAILED,
			validation_report
		)

	var write_error: Error = _write_buffer_absolute(temp_path, bytes)
	if write_error != OK:
		var cleanup_error: Error = _abort_single_absolute_transaction(
			temp_path,
			backup_path,
			transaction_path,
			transaction_pending_path,
			transaction_commit_path,
			transaction_commit_pending_path
		)
		return _make_thread_save_result(
			write_error if cleanup_error == OK else cleanup_error,
			GFStorageAsyncResult.WriteFailureKind.IO_FAILED,
			validation_report
		)

	if had_final:
		var backup_error: Error = DirAccess.rename_absolute(final_path, backup_path)
		if backup_error != OK:
			var rollback_error: Error = _rollback_single_absolute_transaction(
				final_path,
				temp_path,
				backup_path,
				transaction_path,
				transaction_pending_path,
				transaction_commit_path,
				transaction_commit_pending_path,
				had_final
			)
			return _make_thread_save_result(
				backup_error if rollback_error == OK else rollback_error,
				GFStorageAsyncResult.WriteFailureKind.IO_FAILED,
				validation_report
			)

	var commit_error: Error = DirAccess.rename_absolute(temp_path, final_path)
	if commit_error != OK:
		var rollback_error: Error = _rollback_single_absolute_transaction(
			final_path,
			temp_path,
			backup_path,
			transaction_path,
			transaction_pending_path,
			transaction_commit_path,
			transaction_commit_pending_path,
			had_final
		)
		return _make_thread_save_result(
			commit_error if rollback_error == OK else rollback_error,
			GFStorageAsyncResult.WriteFailureKind.IO_FAILED,
			validation_report
		)

	var commit_record: Dictionary = _make_transaction_marker(
		[file_name],
		file_name,
		transaction_id,
		true,
		had_final_by_file
	)
	var complete_marker_error: Error = _publish_single_transaction_record_absolute(
		transaction_commit_path,
		transaction_commit_pending_path,
		commit_record,
		file_name
	)
	if complete_marker_error != OK:
		var rollback_error: Error = _rollback_single_absolute_transaction(
			final_path,
			temp_path,
			backup_path,
			transaction_path,
			transaction_pending_path,
			transaction_commit_path,
			transaction_commit_pending_path,
			had_final
		)
		return _make_thread_save_result(
			complete_marker_error if rollback_error == OK else rollback_error,
			GFStorageAsyncResult.WriteFailureKind.IO_FAILED,
			validation_report
		)

	var terminal_error: Error = _validate_single_committed_absolute_transaction(
		final_path,
		temp_path
	)
	if terminal_error != OK:
		return _make_thread_save_result(
			terminal_error,
			GFStorageAsyncResult.WriteFailureKind.IO_FAILED,
			validation_report
		)
	var _cleanup_error: Error = _finalize_single_absolute_transaction(
		final_path,
		temp_path,
		backup_path,
		transaction_path,
		transaction_pending_path,
		transaction_commit_path,
		transaction_commit_pending_path
	)
	return _make_thread_save_result(
		OK,
		GFStorageAsyncResult.WriteFailureKind.NONE,
		validation_report
	)


func _make_thread_save_result(
	error_code: Error,
	write_failure_kind: GFStorageAsyncResult.WriteFailureKind,
	validation_report: Dictionary
) -> Dictionary:
	return {
		"error": error_code,
		"write_failure_kind": int(write_failure_kind),
		"validation_report": validation_report,
	}


func _validate_thread_payload(
	payload: Dictionary,
	max_values: int = _PAYLOAD_VALIDATION_MAX_VALUES,
	max_bytes: int = _PAYLOAD_VALIDATION_MAX_BYTES,
	max_depth: int = _PAYLOAD_VALIDATION_MAX_DEPTH
) -> Dictionary:
	var state: Dictionary = {
		"visited_values": 0,
		"visited_bytes": 0,
		"max_values": maxi(max_values, 1),
		"max_bytes": maxi(max_bytes, 1),
		"max_depth": maxi(max_depth, 1),
		"active_collections": [],
		"failure_kind": "",
		"failure_path": "",
		"failure_path_segments": [],
		"variant_type": TYPE_NIL,
		"variant_type_name": "",
	}
	_validate_thread_payload_value(payload, "$", [], 0, state)
	var failure_kind: String = GFVariantData.get_option_string(state, "failure_kind")
	return {
		"ok": failure_kind.is_empty(),
		"failure_kind": failure_kind,
		"failure_path": GFVariantData.get_option_string(state, "failure_path"),
		"path_segments": GFVariantData.as_array(
			state.get("failure_path_segments")
		).duplicate(true),
		"variant_type": GFVariantData.get_option_int(state, "variant_type", TYPE_NIL),
		"variant_type_name": GFVariantData.get_option_string(state, "variant_type_name"),
		"visited_values": GFVariantData.get_option_int(state, "visited_values"),
		"visited_bytes": GFVariantData.get_option_int(state, "visited_bytes"),
	}


func _validate_thread_payload_value(
	value: Variant,
	path: String,
	path_segments: Array[Dictionary],
	depth: int,
	state: Dictionary
) -> void:
	if not GFVariantData.get_option_string(state, "failure_kind").is_empty():
		return
	var visited_values: int = GFVariantData.get_option_int(state, "visited_values") + 1
	state["visited_values"] = visited_values
	if visited_values > GFVariantData.get_option_int(state, "max_values"):
		_set_payload_validation_failure(
			state,
			&"value_budget_exceeded",
			path,
			path_segments,
			typeof(value)
		)
		return
	if depth > GFVariantData.get_option_int(state, "max_depth"):
		_set_payload_validation_failure(
			state,
			&"depth_limit_exceeded",
			path,
			path_segments,
			typeof(value)
		)
		return

	var value_type: Variant.Type = typeof(value) as Variant.Type
	if not _is_thread_payload_value_type_supported(value_type):
		_set_payload_validation_failure(
			state,
			&"unsupported_variant_type",
			path,
			path_segments,
			value_type
		)
		return
	if not _is_thread_payload_container_type_safe(value, value_type):
		_set_payload_validation_failure(
			state,
			&"unsupported_typed_container",
			path,
			path_segments,
			value_type
		)
		return
	if not _charge_thread_payload_bytes(
		value,
		value_type,
		path,
		path_segments,
		state
	):
		return
	var packed_element_count: int = _get_packed_array_element_count(
		value,
		value_type
	)
	if packed_element_count > 0:
		visited_values += packed_element_count
		state["visited_values"] = visited_values
		if visited_values > GFVariantData.get_option_int(state, "max_values"):
			_set_payload_validation_failure(
				state,
				&"value_budget_exceeded",
				path,
				path_segments,
				value_type
			)
			return
	if not _is_thread_payload_value_finite(value, value_type):
		_set_payload_validation_failure(
			state,
			&"non_finite_number",
			path,
			path_segments,
			value_type
		)
		return
	if value_type != TYPE_ARRAY and value_type != TYPE_DICTIONARY:
		return

	var active_collections: Array = GFVariantData.as_array(state.get("active_collections"))
	for collection: Variant in active_collections:
		if is_same(collection, value):
			_set_payload_validation_failure(
				state,
				&"circular_reference",
				path,
				path_segments,
				value_type
			)
			return
	active_collections.append(value)
	state["active_collections"] = active_collections
	if value_type == TYPE_ARRAY:
		var array: Array = value
		for index: int in range(array.size()):
			var item_segments: Array[Dictionary] = path_segments.duplicate()
			item_segments.append({
				"kind": "array_index",
				"index": index,
			})
			_validate_thread_payload_value(
				array[index],
				"%s[%d]" % [path, index],
				item_segments,
				depth + 1,
				state
			)
			if not GFVariantData.get_option_string(state, "failure_kind").is_empty():
				break
	else:
		var dictionary: Dictionary = value
		var entry_index: int = 0
		for key: Variant in dictionary:
			var key_segments: Array[Dictionary] = path_segments.duplicate()
			key_segments.append({
				"kind": "dictionary_key",
				"entry_index": entry_index,
			})
			_validate_thread_payload_value(
				key,
				"%s{key:%d}" % [path, entry_index],
				key_segments,
				depth + 1,
				state
			)
			if not GFVariantData.get_option_string(state, "failure_kind").is_empty():
				break
			var value_segments: Array[Dictionary] = path_segments.duplicate()
			value_segments.append({
				"kind": "dictionary_value",
				"entry_index": entry_index,
			})
			_validate_thread_payload_value(
				dictionary[key],
				"%s{value:%d}" % [path, entry_index],
				value_segments,
				depth + 1,
				state
			)
			if not GFVariantData.get_option_string(state, "failure_kind").is_empty():
				break
			entry_index += 1
	var _removed_collection: Variant = active_collections.pop_back()
	state["active_collections"] = active_collections


func _is_thread_payload_value_type_supported(value_type: Variant.Type) -> bool:
	return value_type in [
		TYPE_NIL,
		TYPE_BOOL,
		TYPE_INT,
		TYPE_FLOAT,
		TYPE_STRING,
		TYPE_VECTOR2,
		TYPE_VECTOR2I,
		TYPE_RECT2,
		TYPE_RECT2I,
		TYPE_VECTOR3,
		TYPE_VECTOR3I,
		TYPE_TRANSFORM2D,
		TYPE_VECTOR4,
		TYPE_VECTOR4I,
		TYPE_PLANE,
		TYPE_QUATERNION,
		TYPE_AABB,
		TYPE_BASIS,
		TYPE_TRANSFORM3D,
		TYPE_COLOR,
		TYPE_STRING_NAME,
		TYPE_NODE_PATH,
		TYPE_DICTIONARY,
		TYPE_ARRAY,
		TYPE_PACKED_BYTE_ARRAY,
		TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY,
		TYPE_PACKED_STRING_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY,
		TYPE_PACKED_VECTOR3_ARRAY,
		TYPE_PACKED_COLOR_ARRAY,
		TYPE_PACKED_VECTOR4_ARRAY,
	]


func _is_thread_payload_container_type_safe(
	value: Variant,
	value_type: Variant.Type
) -> bool:
	if value_type == TYPE_ARRAY:
		var array: Array = value
		if not array.is_typed():
			return true
		if array.get_typed_script() != null or not array.get_typed_class_name().is_empty():
			return false
		return _is_thread_payload_value_type_supported(
			array.get_typed_builtin() as Variant.Type
		)
	if value_type == TYPE_DICTIONARY:
		var dictionary: Dictionary = value
		if not dictionary.is_typed():
			return true
		if (
			dictionary.get_typed_key_script() != null
			or dictionary.get_typed_value_script() != null
			or not dictionary.get_typed_key_class_name().is_empty()
			or not dictionary.get_typed_value_class_name().is_empty()
		):
			return false
		return (
			_is_thread_payload_value_type_supported(
				dictionary.get_typed_key_builtin() as Variant.Type
			)
			and _is_thread_payload_value_type_supported(
				dictionary.get_typed_value_builtin() as Variant.Type
			)
		)
	return true


func _charge_thread_payload_bytes(
	value: Variant,
	value_type: Variant.Type,
	path: String,
	path_segments: Array[Dictionary],
	state: Dictionary
) -> bool:
	var max_bytes: int = GFVariantData.get_option_int(state, "max_bytes")
	var visited_bytes: int = GFVariantData.get_option_int(state, "visited_bytes")
	var remaining_bytes: int = maxi(max_bytes - visited_bytes, 0)
	var byte_count: int = _measure_thread_payload_bytes(
		value,
		value_type,
		remaining_bytes
	)
	if byte_count > remaining_bytes:
		state["visited_bytes"] = max_bytes + 1
		_set_payload_validation_failure(
			state,
			&"byte_budget_exceeded",
			path,
			path_segments,
			value_type
		)
		return false
	state["visited_bytes"] = visited_bytes + byte_count
	return true


func _measure_thread_payload_bytes(
	value: Variant,
	value_type: Variant.Type,
	limit: int
) -> int:
	match value_type:
		TYPE_NIL:
			return 0
		TYPE_BOOL:
			return 1
		TYPE_INT, TYPE_FLOAT:
			return 8
		TYPE_STRING:
			var text: String = value
			return _measure_utf8_bytes_bounded(text, limit)
		TYPE_STRING_NAME:
			var string_name_value: StringName = value
			return _measure_utf8_bytes_bounded(String(string_name_value), limit)
		TYPE_NODE_PATH:
			var node_path_value: NodePath = value
			return _measure_utf8_bytes_bounded(String(node_path_value), limit)
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return 16
		TYPE_RECT2, TYPE_RECT2I, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_QUATERNION, TYPE_COLOR:
			return 32
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return 24
		TYPE_TRANSFORM2D:
			return 48
		TYPE_PLANE:
			return 32
		TYPE_AABB:
			return 48
		TYPE_BASIS:
			return 72
		TYPE_TRANSFORM3D:
			return 96
		TYPE_ARRAY, TYPE_DICTIONARY:
			return 16
		TYPE_PACKED_BYTE_ARRAY:
			var packed_bytes: PackedByteArray = value
			return _bounded_byte_product(packed_bytes.size(), 1, limit)
		TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY:
			return _bounded_byte_product(
				_get_packed_array_element_count(value, value_type),
				4,
				limit
			)
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			return _bounded_byte_product(
				_get_packed_array_element_count(value, value_type),
				8,
				limit
			)
		TYPE_PACKED_VECTOR2_ARRAY:
			return _bounded_byte_product(
				_get_packed_array_element_count(value, value_type),
				8,
				limit
			)
		TYPE_PACKED_VECTOR3_ARRAY:
			return _bounded_byte_product(
				_get_packed_array_element_count(value, value_type),
				12,
				limit
			)
		TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
			return _bounded_byte_product(
				_get_packed_array_element_count(value, value_type),
				16,
				limit
			)
		TYPE_PACKED_STRING_ARRAY:
			var packed_strings: PackedStringArray = value
			var total_bytes: int = 0
			for text: String in packed_strings:
				var text_bytes: int = _measure_utf8_bytes_bounded(
					text,
					maxi(limit - total_bytes, 0)
				)
				total_bytes += text_bytes
				if total_bytes > limit:
					return limit + 1
			return total_bytes
	return limit + 1


func _bounded_byte_product(element_count: int, element_width: int, limit: int) -> int:
	if element_count < 0 or element_width <= 0:
		return limit + 1
	var maximum_element_count: int = int(float(limit) / float(element_width))
	if element_count > maximum_element_count:
		return limit + 1
	return element_count * element_width


func _measure_utf8_bytes_bounded(text: String, limit: int) -> int:
	var byte_count: int = 0
	for index: int in range(text.length()):
		var codepoint: int = text.unicode_at(index)
		if codepoint <= 0x7f:
			byte_count += 1
		elif codepoint <= 0x7ff:
			byte_count += 2
		elif codepoint <= 0xffff:
			byte_count += 3
		else:
			byte_count += 4
		if byte_count > limit:
			return limit + 1
	return byte_count


func _get_packed_array_element_count(
	value: Variant,
	value_type: Variant.Type
) -> int:
	match value_type:
		TYPE_PACKED_BYTE_ARRAY:
			var packed_bytes: PackedByteArray = value
			return packed_bytes.size()
		TYPE_PACKED_INT32_ARRAY:
			var packed_int_32: PackedInt32Array = value
			return packed_int_32.size()
		TYPE_PACKED_INT64_ARRAY:
			var packed_int_64: PackedInt64Array = value
			return packed_int_64.size()
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed_float_32: PackedFloat32Array = value
			return packed_float_32.size()
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed_float_64: PackedFloat64Array = value
			return packed_float_64.size()
		TYPE_PACKED_STRING_ARRAY:
			var packed_strings: PackedStringArray = value
			return packed_strings.size()
		TYPE_PACKED_VECTOR2_ARRAY:
			var packed_vector_2: PackedVector2Array = value
			return packed_vector_2.size()
		TYPE_PACKED_VECTOR3_ARRAY:
			var packed_vector_3: PackedVector3Array = value
			return packed_vector_3.size()
		TYPE_PACKED_COLOR_ARRAY:
			var packed_colors: PackedColorArray = value
			return packed_colors.size()
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed_vector_4: PackedVector4Array = value
			return packed_vector_4.size()
	return 0


func _is_thread_payload_value_finite(value: Variant, value_type: Variant.Type) -> bool:
	match value_type:
		TYPE_FLOAT:
			var float_value: float = value
			return _is_finite_float(float_value)
		TYPE_VECTOR2:
			var vector_2: Vector2 = value
			return _are_finite_floats([vector_2.x, vector_2.y])
		TYPE_RECT2:
			var rect_2: Rect2 = value
			return _are_finite_floats([
				rect_2.position.x,
				rect_2.position.y,
				rect_2.size.x,
				rect_2.size.y,
			])
		TYPE_VECTOR3:
			var vector_3: Vector3 = value
			return _are_finite_floats([vector_3.x, vector_3.y, vector_3.z])
		TYPE_TRANSFORM2D:
			var transform_2d: Transform2D = value
			return _are_finite_floats([
				transform_2d.x.x,
				transform_2d.x.y,
				transform_2d.y.x,
				transform_2d.y.y,
				transform_2d.origin.x,
				transform_2d.origin.y,
			])
		TYPE_VECTOR4:
			var vector_4: Vector4 = value
			return _are_finite_floats([vector_4.x, vector_4.y, vector_4.z, vector_4.w])
		TYPE_PLANE:
			var plane: Plane = value
			return _are_finite_floats([
				plane.normal.x,
				plane.normal.y,
				plane.normal.z,
				plane.d,
			])
		TYPE_QUATERNION:
			var quaternion: Quaternion = value
			return _are_finite_floats([
				quaternion.x,
				quaternion.y,
				quaternion.z,
				quaternion.w,
			])
		TYPE_AABB:
			var bounds: AABB = value
			return _are_finite_floats([
				bounds.position.x,
				bounds.position.y,
				bounds.position.z,
				bounds.size.x,
				bounds.size.y,
				bounds.size.z,
			])
		TYPE_BASIS:
			var basis: Basis = value
			return _are_finite_floats([
				basis.x.x,
				basis.x.y,
				basis.x.z,
				basis.y.x,
				basis.y.y,
				basis.y.z,
				basis.z.x,
				basis.z.y,
				basis.z.z,
			])
		TYPE_TRANSFORM3D:
			var transform_3d: Transform3D = value
			return (
				_is_thread_payload_value_finite(transform_3d.basis, TYPE_BASIS)
				and _is_thread_payload_value_finite(transform_3d.origin, TYPE_VECTOR3)
			)
		TYPE_COLOR:
			var color: Color = value
			return _are_finite_floats([color.r, color.g, color.b, color.a])
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed_float_32: PackedFloat32Array = value
			for item: float in packed_float_32:
				if not _is_finite_float(item):
					return false
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed_float_64: PackedFloat64Array = value
			for item: float in packed_float_64:
				if not _is_finite_float(item):
					return false
		TYPE_PACKED_VECTOR2_ARRAY:
			var packed_vector_2: PackedVector2Array = value
			for item: Vector2 in packed_vector_2:
				if not _is_thread_payload_value_finite(item, TYPE_VECTOR2):
					return false
		TYPE_PACKED_VECTOR3_ARRAY:
			var packed_vector_3: PackedVector3Array = value
			for item: Vector3 in packed_vector_3:
				if not _is_thread_payload_value_finite(item, TYPE_VECTOR3):
					return false
		TYPE_PACKED_COLOR_ARRAY:
			var packed_color: PackedColorArray = value
			for item: Color in packed_color:
				if not _is_thread_payload_value_finite(item, TYPE_COLOR):
					return false
		TYPE_PACKED_VECTOR4_ARRAY:
			var packed_vector_4: PackedVector4Array = value
			for item: Vector4 in packed_vector_4:
				if not _is_thread_payload_value_finite(item, TYPE_VECTOR4):
					return false
	return true


func _are_finite_floats(values: Array[float]) -> bool:
	for value: float in values:
		if not _is_finite_float(value):
			return false
	return true


func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _set_payload_validation_failure(
	state: Dictionary,
	failure_kind: StringName,
	path: String,
	path_segments: Array[Dictionary],
	value_type: Variant.Type
) -> void:
	state["failure_kind"] = String(failure_kind)
	state["failure_path"] = path
	state["failure_path_segments"] = path_segments.duplicate(true)
	state["variant_type"] = int(value_type)
	state["variant_type_name"] = type_string(value_type)


func _load_data_thread(_file_name: String, path: String, codec_options: Dictionary) -> Dictionary:
	if path.is_empty():
		return _make_thread_load_failure(
			"Storage path is invalid",
			ERR_INVALID_PARAMETER,
			GFStorageReadResult.FailureKind.INVALID_REQUEST
		)
	if not FileAccess.file_exists(path):
		return _make_thread_load_failure(
			"File not found",
			ERR_FILE_NOT_FOUND,
			GFStorageReadResult.FailureKind.NOT_FOUND
		)

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _make_thread_load_failure(
			"File open failed: %s" % error_string(FileAccess.get_open_error()),
			ERR_FILE_CANT_OPEN,
			GFStorageReadResult.FailureKind.IO_FAILED
		)

	var expected_length: int = file.get_length()
	if expected_length <= 0:
		file.close()
		return _make_thread_load_failure(
			"File is empty",
			ERR_FILE_CORRUPT,
			GFStorageReadResult.FailureKind.CORRUPT
		)
	var bytes: PackedByteArray = file.get_buffer(expected_length)
	var read_error: Error = file.get_error()
	file.close()
	if (
		bytes.size() != expected_length
		or (read_error != OK and read_error != ERR_FILE_EOF)
	):
		return _make_thread_load_failure(
			"File read failed: %s" % error_string(read_error),
			read_error if read_error not in [OK, ERR_FILE_EOF] else ERR_FILE_CANT_READ,
			GFStorageReadResult.FailureKind.IO_FAILED
		)

	var thread_codec: GFStorageCodec = GFStorageCodec.new()
	return thread_codec.decode(bytes, codec_options).to_dict()


func _make_thread_load_failure(
	error_message: String,
	error_code: Error,
	failure_kind: GFStorageReadResult.FailureKind
) -> Dictionary:
	return GFStorageReadResult.new().configure_failure(
		error_message,
		error_code,
		{},
		GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
		0,
		failure_kind
	).to_dict()


func _ensure_absolute_parent_directory(path: String) -> Error:
	_ensure_storage_helpers()
	return _file_ops._ensure_absolute_parent_directory(path)


func _write_buffer_absolute(path: String, bytes: PackedByteArray) -> Error:
	_ensure_storage_helpers()
	return _file_ops._write_buffer_absolute(path, bytes)


func _copy_file_bytes(source_path: String, target_path: String) -> Error:
	if source_path.is_empty() or target_path.is_empty():
		return ERR_INVALID_PARAMETER
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


func _remove_absolute_file(path: String) -> Error:
	if path.is_empty():
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(path)


func _publish_single_transaction_record_absolute(
	path: String,
	pending_path: String,
	record: Dictionary,
	file_name: String
) -> Error:
	if not _is_valid_single_file_transaction_marker(record, file_name):
		return ERR_INVALID_DATA
	if FileAccess.file_exists(path):
		return _match_single_transaction_record_at_path(record, path, file_name)
	if FileAccess.file_exists(pending_path):
		var pending_match_error: Error = _match_single_transaction_record_at_path(
			record,
			pending_path,
			file_name
		)
		if pending_match_error != OK:
			return pending_match_error
	else:
		var write_error: Error = _write_plain_json_absolute(pending_path, record)
		if write_error != OK:
			return write_error
		var written_match_error: Error = _match_single_transaction_record_at_path(
			record,
			pending_path,
			file_name
		)
		if written_match_error != OK:
			return written_match_error
	var publish_error: Error = DirAccess.rename_absolute(pending_path, path)
	if publish_error == OK:
		return OK
	if not FileAccess.file_exists(path):
		return publish_error
	var published_match_error: Error = _match_single_transaction_record_at_path(
		record,
		path,
		file_name
	)
	if published_match_error != OK:
		return published_match_error
	var _pending_cleanup_error: Error = _remove_absolute_file(pending_path)
	return OK


func _match_single_transaction_record_at_path(
	expected: Dictionary,
	path: String,
	file_name: String
) -> Error:
	var read_result: Dictionary = _read_transaction_record_result_absolute(path)
	var read_error: Error = GFVariantData.get_option_int(
		read_result,
		"error",
		ERR_FILE_CORRUPT
	) as Error
	if read_error != OK:
		return read_error
	return (
		OK
		if _single_transaction_records_match(
			expected,
			GFVariantData.get_option_dictionary(read_result, "record"),
			file_name
		)
		else ERR_FILE_CORRUPT
	)


static func _read_transaction_record_result_absolute(path: String) -> Dictionary:
	if path.is_empty():
		return {"error": int(ERR_INVALID_PARAMETER), "record": {}}
	if not FileAccess.file_exists(path):
		return {"error": int(ERR_FILE_NOT_FOUND), "record": {}}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": int(FileAccess.get_open_error()), "record": {}}
	var expected_length: int = file.get_length()
	var length_error: Error = file.get_error()
	if length_error != OK:
		file.close()
		return {"error": int(length_error), "record": {}}
	if expected_length <= 0 or expected_length > 64 * 1024:
		file.close()
		return {"error": int(ERR_FILE_CORRUPT), "record": {}}
	var bytes: PackedByteArray = file.get_buffer(expected_length)
	var read_error: Error = file.get_error()
	file.close()
	if (
		bytes.size() != expected_length
		or (read_error != OK and read_error != ERR_FILE_EOF)
	):
		return {
			"error": int(
				read_error if read_error not in [OK, ERR_FILE_EOF] else ERR_FILE_CANT_READ
			),
			"record": {},
		}
	var json_parser: JSON = JSON.new()
	var parse_error: Error = json_parser.parse(bytes.get_string_from_utf8())
	if parse_error != OK:
		return {"error": int(ERR_FILE_CORRUPT), "record": {}}
	var parsed: Variant = json_parser.data
	if not parsed is Dictionary:
		return {"error": int(ERR_FILE_CORRUPT), "record": {}}
	return {"error": int(OK), "record": GFVariantData.as_dictionary(parsed)}


func _read_transaction_record_absolute(path: String) -> Dictionary:
	return GFVariantData.get_option_dictionary(
		_read_transaction_record_result_absolute(path),
		"record"
	)


func _single_transaction_records_match(
	expected: Dictionary,
	actual: Dictionary,
	file_name: String
) -> bool:
	return (
		_is_valid_single_file_transaction_marker(expected, file_name)
		and _is_valid_single_file_transaction_marker(actual, file_name)
		and GFVariantData.get_option_string(expected, "transaction_id")
		== GFVariantData.get_option_string(actual, "transaction_id")
		and GFVariantData.get_option_bool(expected, "committed")
		== GFVariantData.get_option_bool(actual, "committed")
		and GFVariantData.get_option_dictionary(expected, "owner")
		== GFVariantData.get_option_dictionary(actual, "owner")
		and GFVariantData.get_option_array(expected, "members")
		== GFVariantData.get_option_array(actual, "members")
	)


func _abort_single_absolute_transaction(
	temp_path: String,
	backup_path: String,
	transaction_path: String,
	transaction_pending_path: String,
	transaction_commit_path: String,
	transaction_commit_pending_path: String
) -> Error:
	if FileAccess.file_exists(backup_path) or FileAccess.file_exists(transaction_commit_path):
		return ERR_FILE_CORRUPT
	for cleanup_path: String in [
		temp_path,
		transaction_commit_pending_path,
		transaction_pending_path,
		transaction_path,
	]:
		var cleanup_error: Error = _remove_absolute_file(cleanup_path)
		if cleanup_error != OK:
			return cleanup_error
	return OK


func _rollback_single_absolute_transaction(
	final_path: String,
	temp_path: String,
	backup_path: String,
	transaction_path: String,
	transaction_pending_path: String,
	transaction_commit_path: String,
	transaction_commit_pending_path: String,
	had_final: bool
) -> Error:
	if had_final:
		if FileAccess.file_exists(backup_path):
			var remove_new_final: Error = _remove_absolute_file(final_path)
			if remove_new_final != OK:
				return remove_new_final
			var restore_error: Error = DirAccess.rename_absolute(backup_path, final_path)
			if restore_error != OK:
				return restore_error
		elif not FileAccess.file_exists(final_path):
			return ERR_FILE_CORRUPT
	else:
		if FileAccess.file_exists(backup_path):
			return ERR_FILE_CORRUPT
		var remove_new_file: Error = _remove_absolute_file(final_path)
		if remove_new_file != OK:
			return remove_new_file
	var remove_candidate: Error = _remove_absolute_file(temp_path)
	if remove_candidate != OK:
		return remove_candidate
	if FileAccess.file_exists(final_path) != had_final:
		return ERR_FILE_CORRUPT
	for evidence_path: String in [
		transaction_commit_pending_path,
		transaction_commit_path,
		transaction_pending_path,
		transaction_path,
	]:
		var cleanup_error: Error = _remove_absolute_file(evidence_path)
		if cleanup_error != OK:
			return cleanup_error
	return OK


func _finalize_single_absolute_transaction(
	_final_path: String,
	_temp_path: String,
	backup_path: String,
	transaction_path: String,
	transaction_pending_path: String,
	transaction_commit_path: String,
	transaction_commit_pending_path: String
) -> Error:
	for cleanup_path: String in [
		backup_path,
		transaction_pending_path,
		transaction_path,
		transaction_commit_pending_path,
		transaction_commit_path,
	]:
		var cleanup_error: Error = _remove_absolute_file(cleanup_path)
		if cleanup_error != OK:
			return cleanup_error
	return OK


func _validate_single_committed_absolute_transaction(
	final_path: String,
	temp_path: String
) -> Error:
	return OK if FileAccess.file_exists(final_path) and not FileAccess.file_exists(
		temp_path
	) else ERR_FILE_CORRUPT


func _get_save_base_path() -> String:
	_ensure_storage_helpers()
	return _path_policy._get_save_base_path()


func _make_family_descriptor(file_name: String) -> Dictionary:
	_ensure_storage_helpers()
	return GFStorageFamilyStore.make_family_descriptor_for_framework(
		_get_save_base_path(),
		file_name
	)


func _prepare_family_for_write(file_name: String) -> Error:
	var readiness_error: Error = _ensure_storage_ready()
	if readiness_error != OK:
		return readiness_error
	var reset_recovery_error: Error = _resume_pending_reset_for_file(
		_get_save_base_path(),
		file_name
	)
	if reset_recovery_error != OK:
		return reset_recovery_error
	var descriptor: Dictionary = _make_family_descriptor(file_name)
	if descriptor.is_empty():
		return ERR_INVALID_PARAMETER
	var claim_error: Error = _family_store.claim_family_for_framework(descriptor)
	if claim_error != OK:
		return claim_error
	var recovery_error: Error = _recover_transaction_files([file_name])
	return recovery_error


func _prepare_family_for_read(file_name: String) -> Error:
	var readiness_error: Error = _ensure_storage_ready()
	if readiness_error != OK:
		return readiness_error
	return _prepare_family_for_read_after_readiness(file_name)


func _prepare_family_for_read_after_readiness(file_name: String) -> Error:
	var result: Dictionary = _prepare_family_for_read_after_readiness_result(file_name)
	return GFVariantData.get_option_int(result, "error", ERR_BUG) as Error


func _prepare_family_for_read_after_readiness_result(file_name: String) -> Dictionary:
	var reset_recovery_result: Dictionary = _resume_pending_reset_for_file_result(
		_get_save_base_path(),
		file_name
	)
	var reset_recovery_error: Error = GFVariantData.get_option_int(
		reset_recovery_result,
		"error",
		ERR_BUG
	) as Error
	var target_provenance: bool = GFVariantData.get_option_bool(
		reset_recovery_result,
		"target_provenance"
	)
	if reset_recovery_error != OK:
		return reset_recovery_result
	var descriptor: Dictionary = _make_family_descriptor(file_name)
	if descriptor.is_empty():
		return {"error": int(ERR_INVALID_PARAMETER), "target_provenance": false}
	var validate_error: Error = _family_store.validate_family_for_framework(descriptor)
	if validate_error != OK:
		return {
			"error": int(validate_error),
			"target_provenance": target_provenance,
		}
	var recovery_error: Error = _recover_transaction_files([file_name])
	if recovery_error != OK:
		return {
			"error": int(recovery_error),
			"target_provenance": target_provenance,
		}
	var payload_exists: bool = FileAccess.file_exists(
		GFVariantData.get_option_string(descriptor, "payload_path")
	)
	return {
		"error": int(OK if payload_exists else ERR_FILE_NOT_FOUND),
		"target_provenance": target_provenance,
	}


func _resolve_internal_storage_path(file_name: String) -> String:
	var storage_root_path: String = _get_save_base_path()
	if storage_root_path.is_empty():
		return ""
	if GFStorageFamilyStore.is_valid_private_relative_path_for_framework(file_name):
		return (
			"user://" + file_name
			if storage_root_path == "user://"
			else storage_root_path + "/" + file_name
		)
	var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
		storage_root_path,
		file_name
	)
	return GFVariantData.get_option_string(descriptor, "payload_path")


func _get_full_path(file_name: String) -> String:
	_ensure_storage_helpers()
	return _path_policy._get_full_path(file_name)


func _get_resource_temp_filename(file_name: String) -> String:
	return GFVariantData.get_option_string(
		_make_family_descriptor(file_name),
		"resource_stage_relative_path"
	)


func _is_resource_load_extension_allowed(path: String) -> bool:
	var extension: String = path.get_extension()
	if extension.is_empty():
		return false
	for allowed_extension: String in allowed_resource_load_extensions:
		if (
			GFStorageFamilyStore.is_valid_extension_filter_for_framework(allowed_extension)
			and allowed_extension == extension
		):
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
	if directory_path.is_empty():
		return
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
	if file_name.is_empty():
		push_error("[GFStorageUtility] %s 失败：file_name 为空。" % operation)
		return false
	if not GFStorageFamilyStore.is_valid_logical_file_path_for_framework(file_name):
		push_error("[GFStorageUtility] %s 失败：file_name 不满足 portable logical path profile。" % operation)
		return false
	return not _get_save_base_path().is_empty()


func _validate_public_resource_file_name(file_name: String, operation: String) -> bool:
	if not _validate_public_file_name(file_name, operation):
		return false
	var extension: String = file_name.get_extension()
	if (
		extension.is_empty()
		or not GFStorageFamilyStore.is_valid_extension_filter_for_framework(extension)
	):
		push_error(
			"[GFStorageUtility] %s 失败：Resource logical path 必须包含 canonical lowercase 扩展名。"
			% operation
		)
		return false
	return true


func _validate_public_directory_name(directory_name: String, operation: String) -> bool:
	if not GFStorageFamilyStore.is_valid_logical_directory_path_for_framework(directory_name):
		push_error("[GFStorageUtility] %s 失败：directory_name 非法。" % operation)
		return false
	return not _get_save_base_path().is_empty()


func _is_parent_directory_path(path: String) -> bool:
	_ensure_storage_helpers()
	return _path_policy._is_parent_directory_path(path)


func _is_safe_storage_path(path: String, label: String) -> bool:
	_ensure_storage_helpers()
	return _path_policy._is_safe_storage_path(path, label)


func _get_async_file_key(file_name: String) -> String:
	return GFVariantData.get_option_string(_make_family_descriptor(file_name), "file_key")


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


func _get_transaction_pending_filename(file_name: String) -> String:
	_ensure_storage_helpers()
	return _transaction_manager._get_transaction_pending_filename(file_name)


func _get_transaction_commit_filename(file_name: String) -> String:
	_ensure_storage_helpers()
	return _transaction_manager._get_transaction_commit_filename(file_name)


func _get_transaction_commit_pending_filename(file_name: String) -> String:
	_ensure_storage_helpers()
	return _transaction_manager._get_transaction_commit_pending_filename(file_name)


func _cleanup_transaction_files(file_names: Array[String]) -> Error:
	_ensure_storage_helpers()
	return _transaction_manager._cleanup_transaction_files(file_names)


func _recover_transaction_files(file_names: Array[String]) -> Error:
	_ensure_storage_helpers()
	return _transaction_manager._recover_transaction_files(file_names)


func _recover_transaction_group(file_names: Array[String]) -> Error:
	_ensure_storage_helpers()
	return _transaction_manager._recover_transaction_group(file_names)


func _recover_transaction_file(file_name: String) -> Error:
	_ensure_storage_helpers()
	return _transaction_manager._recover_transaction_file(file_name)


func _commit_transaction(file_names: Array[String], markers_prepared: bool = false) -> Error:
	_ensure_storage_helpers()
	return _transaction_manager._commit_transaction(file_names, markers_prepared)


func _rollback_transaction(file_names: Array[String], transaction_state: Dictionary) -> Error:
	_ensure_storage_helpers()
	return _transaction_manager._rollback_transaction(file_names, transaction_state)


func _write_transaction_markers(file_names: Array[String], committed: bool) -> Error:
	_ensure_storage_helpers()
	return _transaction_manager._write_transaction_markers(file_names, committed)


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
	var path: String = _get_full_path(file_name)
	if not FileAccess.file_exists(path):
		last_load_result = _make_load_failure(
			"File not found",
			ERR_FILE_NOT_FOUND,
			GFStorageReadResult.FailureKind.NOT_FOUND
		)
		_bind_read_result_origin(last_load_result, file_name)
		return last_load_result.duplicate_result()

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		push_error("[GFStorageUtility] 无法读取文件：%s，错误码：%s" % [path, open_error])
		last_load_result = _make_load_failure(
			"File open failed: %s" % error_string(open_error),
			open_error,
			GFStorageReadResult.FailureKind.IO_FAILED
		)
		_bind_read_result_origin(last_load_result, file_name)
		return last_load_result.duplicate_result()

	var expected_length: int = file.get_length()
	if expected_length <= 0:
		file.close()
		last_load_result = _make_load_failure(
			"File is empty",
			ERR_FILE_CORRUPT,
			GFStorageReadResult.FailureKind.CORRUPT
		)
		_bind_read_result_origin(last_load_result, file_name)
		return last_load_result.duplicate_result()
	var bytes: PackedByteArray = file.get_buffer(expected_length)
	var read_error: Error = file.get_error()
	file.close()
	if (
		bytes.size() != expected_length
		or (read_error != OK and read_error != ERR_FILE_EOF)
	):
		var reported_read_error: Error = (
			read_error
			if read_error not in [OK, ERR_FILE_EOF]
			else ERR_FILE_CANT_READ
		)
		push_error(
			"[GFStorageUtility] 无法完整读取文件：%s，错误码：%s"
			% [path, reported_read_error]
		)
		last_load_result = _make_load_failure(
			"File read failed: %s" % error_string(reported_read_error),
			reported_read_error,
			GFStorageReadResult.FailureKind.IO_FAILED
		)
		_bind_read_result_origin(last_load_result, file_name)
		return last_load_result.duplicate_result()

	var result: GFStorageReadResult = _get_codec().decode(bytes, _get_codec_options())
	result = _apply_schema_migrations(file_name, result)
	_bind_read_result_origin(result, file_name)
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


func _apply_schema_migrations(
	file_name: String,
	result: GFStorageReadResult,
	emit_migrated_signal: bool = true
) -> GFStorageReadResult:
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

	var migrated_payload: Dictionary = {}
	if _has_migrate_data_override():
		migrated_payload = migrate_data(result.payload, from_version, to_version)
	else:
		var execution: Dictionary = _execute_registered_migrations(
			result.payload,
			from_version,
			to_version
		)
		if not GFVariantData.get_option_bool(execution, "ok", false):
			return _make_migration_failure(
				result,
				GFVariantData.get_option_string(
					execution,
					"error",
					"Storage migration failed."
				),
				GFStorageReadResult.FailureKind.MIGRATION_FAILED
			)
		migrated_payload = GFVariantData.get_option_dictionary(execution, "payload")
		if not default_values_for_new_keys.is_empty():
			migrated_payload = _merge_default_values(
				migrated_payload,
				default_values_for_new_keys
			)
	var migrated_metadata: Dictionary = result.metadata.duplicate(true)
	migrated_metadata[GFStorageCodec.VERSION_KEY] = to_version
	result.payload = migrated_payload
	result.metadata = migrated_metadata
	result.data_version = to_version
	result.migrated = true
	if emit_migrated_signal:
		data_migrated.emit(file_name, from_version, to_version)
	return result


func _has_migrate_data_override() -> bool:
	var script: Script = _get_script_value(get_script())
	var framework_method_count: int = _count_script_methods(
		GFStorageUtility,
		&"migrate_data"
	)
	while script != null and script != GFStorageUtility:
		if _count_script_methods(script, &"migrate_data") > framework_method_count:
			return true
		script = script.get_base_script()
	return false


func _count_script_methods(script: Script, method_name: StringName) -> int:
	if script == null:
		return 0
	var count: int = 0
	for method: Dictionary in script.get_script_method_list():
		if GFVariantData.get_option_string(method, "name") == String(method_name):
			count += 1
	return count


func _execute_registered_migrations(
	data: Dictionary,
	from_version: int,
	to_version: int
) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	var chain: Array[int] = _resolve_migration_chain(from_version, to_version)
	if chain.is_empty():
		return {"ok": true, "payload": migrated}

	var current_version: int = from_version
	for next_version: int in chain:
		var entry: Dictionary = GFVariantData.get_option_dictionary(_migration_steps, _make_migration_key(current_version, next_version))
		var callback: Callable = _get_callable_value(GFVariantData.get_option_value(entry, "callback", Callable()))
		if not callback.is_valid():
			return {
				"ok": false,
				"error": "Migration step %d -> %d is no longer callable." % [
					current_version,
					next_version,
				],
			}

		var step_result: Variant = callback.call(
			migrated.duplicate(true),
			current_version,
			next_version
		)
		if not step_result is Dictionary:
			return {
				"ok": false,
				"error": "Migration step %d -> %d must return Dictionary." % [
					current_version,
					next_version,
				],
			}
		migrated = GFVariantData.as_dictionary(step_result)
		current_version = next_version
	return {"ok": true, "payload": migrated}


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
	return _make_migration_failure(
		result,
		error_message,
		GFStorageReadResult.FailureKind.MIGRATION_FAILED
	)


func _fail_future_storage_version(
	result: GFStorageReadResult,
	from_version: int,
	to_version: int
) -> GFStorageReadResult:
	var error_message: String = "Unsupported future storage version: %d > %d" % [from_version, to_version]
	return _make_migration_failure(
		result,
		error_message,
		GFStorageReadResult.FailureKind.FUTURE_VERSION
	)


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


func _make_load_failure(
	error_message: String,
	error_code: Error,
	failure_kind: GFStorageReadResult.FailureKind = GFStorageReadResult.FailureKind.IO_FAILED
) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_failure(
		error_message,
		error_code,
		{},
		GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
		0,
		failure_kind
	)


func _make_migration_failure(
	result: GFStorageReadResult,
	error_message: String,
	failure_kind: GFStorageReadResult.FailureKind
) -> GFStorageReadResult:
	if result == null:
		return _make_load_failure(error_message, ERR_INVALID_DATA, failure_kind)
	return GFStorageReadResult.new().configure_failure(
		error_message,
		ERR_INVALID_DATA,
		result.metadata,
		result.integrity_status,
		result.document_schema_version,
		failure_kind
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

	func _get_save_base_path() -> String:
		var save_dir_name: String = _get_string_property("save_dir_name")
		var storage_root_path: String = GFStorageFamilyStore.make_storage_root_path_for_framework(
			save_dir_name
		)
		if storage_root_path.is_empty():
			push_error("[GFStorageUtility] save_dir_name 必须满足 portable logical directory profile。")
		return storage_root_path

	func _is_absolute_storage_path(path: String) -> bool:
		return path.replace("\\", "/").is_absolute_path()

	func _has_invalid_storage_root_character(path: String) -> bool:
		const FORBIDDEN_CHARACTERS: String = "<>:\"|?*"
		for index: int in range(path.length()):
			var codepoint: int = path.unicode_at(index)
			if codepoint < 32 or codepoint == 127:
				return true
			if FORBIDDEN_CHARACTERS.contains(String.chr(codepoint)):
				return true
		return false

	func _is_valid_frozen_storage_root_path(storage_root_path: String) -> bool:
		if storage_root_path == "user://":
			return true
		if not storage_root_path.begins_with("user://"):
			return false
		var relative_root: String = storage_root_path.trim_prefix("user://")
		return GFStorageFamilyStore.is_valid_logical_directory_path_for_framework(relative_root)

	func _get_full_path(file_name: String) -> String:
		if (
			not GFStorageFamilyStore.is_valid_private_relative_path_for_framework(file_name)
			and not GFStorageFamilyStore.is_valid_logical_file_path_for_framework(file_name)
		):
			return ""
		var resolved: Variant = _owner.call("_resolve_internal_storage_path", file_name)
		return GFVariantData.to_text(resolved)

	func _get_full_directory_path_from_normalized(directory_name: String) -> String:
		if not GFStorageFamilyStore.is_valid_logical_directory_path_for_framework(directory_name):
			return ""
		var storage_root_path: String = _get_save_base_path()
		if storage_root_path.is_empty() or directory_name.is_empty():
			return storage_root_path
		if storage_root_path == "user://":
			return "user://" + directory_name
		return storage_root_path.path_join(directory_name)

	func _normalize_storage_directory_name(directory_name: String) -> String:
		if directory_name.is_empty():
			return ""
		return directory_name if GFStorageFamilyStore.is_valid_logical_directory_path_for_framework(
			directory_name
		) else "_invalid_storage_directory"

	func _normalize_extension_filter(extension_filter: String) -> String:
		return extension_filter if GFStorageFamilyStore.is_valid_extension_filter_for_framework(
			extension_filter
		) else "_invalid_extension_filter"

	func _file_matches_extension(file_name: String, extension_filter: String) -> bool:
		return extension_filter.is_empty() or file_name.get_extension() == extension_filter

	func _sanitize_storage_relative_path(path: String, label: String) -> String:
		if not GFStorageFamilyStore.is_valid_logical_file_path_for_framework(path):
			push_error("[GFStorageUtility] %s 不满足 portable logical path profile。" % label)
			return ""
		return path

	func _is_parent_directory_path(path: String) -> bool:
		return path == ".." or path.begins_with("../") or path.contains("/../")

	func _contains_parent_segment(path: String) -> bool:
		for segment: String in path.replace("\\", "/").split("/", true):
			if segment == "..":
				return true
		return false

	func _canonicalize_file_name(path: String, label: String) -> String:
		return _sanitize_storage_relative_path(path, label)

	func _is_safe_storage_path(path: String, label: String) -> bool:
		if GFStorageFamilyStore.is_valid_logical_file_path_for_framework(path):
			return true
		push_error("[GFStorageUtility] %s 不满足 portable logical path profile。" % label)
		return false


class _FrozenStoragePathPolicy extends _StoragePathPolicy:
	var _storage_root_path: String

	func _init(storage_root_path: String) -> void:
		_storage_root_path = storage_root_path

	func _get_save_base_path() -> String:
		return _storage_root_path

	func _get_full_path(file_name: String) -> String:
		if GFStorageFamilyStore.is_valid_private_relative_path_for_framework(file_name):
			return (
				"user://" + file_name
				if _storage_root_path == "user://"
				else _storage_root_path + "/" + file_name
			)
		var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
			_storage_root_path,
			file_name
		)
		return GFVariantData.get_option_string(descriptor, "payload_path")

	func _canonicalize_file_name(path: String, label: String) -> String:
		return _sanitize_storage_relative_path(path, label)


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
		var remove_error: Error = _remove_absolute(path)
		if remove_error != OK:
			push_warning("[GFStorageUtility] 删除文件失败：错误码：%s" % remove_error)

	func _remove_absolute(path: String) -> Error:
		if not FileAccess.file_exists(path):
			return OK
		return DirAccess.remove_absolute(path)

	func _ensure_absolute_parent_directory(path: String) -> Error:
		if path.is_empty():
			return ERR_INVALID_PARAMETER
		var base_dir: String = path.get_base_dir()
		if base_dir.is_empty() or base_dir == "user://":
			return OK
		if DirAccess.dir_exists_absolute(base_dir):
			return OK
		return DirAccess.make_dir_recursive_absolute(base_dir)

	func _ensure_parent_directory(path: String) -> Error:
		if path.is_empty():
			return ERR_INVALID_PARAMETER
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
		if path.is_empty():
			return ERR_INVALID_PARAMETER
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		_store_buffer_checked(file, bytes)
		var error: Error = file.get_error()
		file.close()
		return error

	func _write_plain_json_absolute(path: String, data: Dictionary) -> Error:
		if path.is_empty():
			return ERR_INVALID_PARAMETER
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
		if from_path.is_empty() or to_path.is_empty():
			return ERR_INVALID_PARAMETER
		if not FileAccess.file_exists(from_path):
			return ERR_FILE_NOT_FOUND
		return DirAccess.rename_absolute(from_path, to_path)

	func _write_json(file_name: String, data: Dictionary) -> Error:
		var path: String = _path_policy._get_full_path(file_name)
		if path.is_empty():
			return ERR_INVALID_PARAMETER
		var codec: GFStorageCodec = _get_codec()
		var codec_options: Dictionary = _get_codec_options()
		var bytes: PackedByteArray = codec.encode(data, codec_options)
		if bytes.is_empty():
			return ERR_INVALID_DATA
		var dir_error: Error = _ensure_parent_directory(path)
		if dir_error != OK:
			return dir_error
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("[GFStorageUtility] 无法写入文件：%s，错误码：%s" % [path, FileAccess.get_open_error()])
			return FileAccess.get_open_error()

		_store_buffer_checked(file, bytes)
		var write_error: Error = file.get_error()
		file.close()
		if write_error != OK:
			push_error("[GFStorageUtility] 写入文件失败：%s，错误码：%s" % [path, write_error])
		return write_error

	func _write_plain_json(file_name: String, data: Dictionary) -> Error:
		var path: String = _path_policy._get_full_path(file_name)
		if path.is_empty():
			return ERR_INVALID_PARAMETER
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
	var _owner: Object
	var _path_policy: _StoragePathPolicy
	var _file_ops: _StorageFileOps
	var _family_store: GFStorageFamilyStore
	var _next_transaction_id: int = 1

	func _init(
		p_owner: Object,
		p_path_policy: _StoragePathPolicy,
		p_file_ops: _StorageFileOps,
		p_family_store: GFStorageFamilyStore
	) -> void:
		_owner = p_owner
		_path_policy = p_path_policy
		_file_ops = p_file_ops
		_family_store = p_family_store

	func _dispose() -> void:
		_owner = null
		_path_policy = null
		_file_ops = null
		_family_store = null

	func _get_temp_filename(file_name: String) -> String:
		return GFVariantData.get_option_string(
			GFStorageFamilyStore.make_family_descriptor_for_framework(
				_path_policy._get_save_base_path(),
				file_name
			),
			"candidate_relative_path"
		)

	func _get_backup_filename(file_name: String) -> String:
		return GFVariantData.get_option_string(
			GFStorageFamilyStore.make_family_descriptor_for_framework(
				_path_policy._get_save_base_path(),
				file_name
			),
			"backup_relative_path"
		)

	func _get_transaction_filename(file_name: String) -> String:
		return GFVariantData.get_option_string(
			GFStorageFamilyStore.make_family_descriptor_for_framework(
				_path_policy._get_save_base_path(),
				file_name
			),
			"transaction_relative_path"
		)

	func _get_transaction_pending_filename(file_name: String) -> String:
		return GFVariantData.get_option_string(
			GFStorageFamilyStore.make_family_descriptor_for_framework(
				_path_policy._get_save_base_path(),
				file_name
			),
			"transaction_pending_relative_path"
		)

	func _get_transaction_commit_filename(file_name: String) -> String:
		return GFVariantData.get_option_string(
			GFStorageFamilyStore.make_family_descriptor_for_framework(
				_path_policy._get_save_base_path(),
				file_name
			),
			"transaction_commit_relative_path"
		)

	func _get_transaction_commit_pending_filename(file_name: String) -> String:
		return GFVariantData.get_option_string(
			GFStorageFamilyStore.make_family_descriptor_for_framework(
				_path_policy._get_save_base_path(),
				file_name
			),
			"transaction_commit_pending_relative_path"
		)

	func _cleanup_transaction_files(file_names: Array[String]) -> Error:
		file_names = _unique_file_names(file_names)
		for file_name: String in file_names:
			if (
				FileAccess.file_exists(_path_policy._get_full_path(_get_backup_filename(file_name)))
				or FileAccess.file_exists(_path_policy._get_full_path(_get_transaction_commit_filename(file_name)))
			):
				return ERR_FILE_CORRUPT
			for cleanup_path: String in [
				_path_policy._get_full_path(_get_temp_filename(file_name)),
				GFVariantData.get_option_string(
					GFStorageFamilyStore.make_family_descriptor_for_framework(
						_path_policy._get_save_base_path(),
						file_name
					),
					"resource_stage_path"
				),
			]:
				var cleanup_error: Error = _file_ops._remove_absolute(cleanup_path)
				if cleanup_error != OK:
					return cleanup_error
		return _cleanup_prepare_records(file_names)

	func _recover_all_catalog_transactions() -> Error:
		var descriptors_result: Dictionary = (
			_family_store.list_claimed_family_descriptors_for_framework()
		)
		var descriptors_error: Error = GFVariantData.get_option_int(
			descriptors_result,
			"error",
			OK
		) as Error
		if descriptors_error != OK:
			return descriptors_error
		for descriptor_value: Variant in GFVariantData.get_option_array(
			descriptors_result,
			"descriptors"
		):
			var descriptor: Dictionary = GFVariantData.as_dictionary(descriptor_value)
			var logical_path: String = GFVariantData.get_option_string(
				descriptor,
				"logical_path"
			)
			var recovery_error: Error = _recover_transaction_file(logical_path)
			if recovery_error != OK:
				return recovery_error
		return OK

	func _recover_transaction_files(file_names: Array[String]) -> Error:
		file_names = _unique_file_names(file_names)
		var recovered_files: Dictionary = {}
		for file_name: String in file_names:
			var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
				_path_policy._get_save_base_path(),
				file_name
			)
			var family_error: Error = _family_store.validate_family_for_framework(descriptor)
			if family_error == ERR_FILE_NOT_FOUND:
				continue
			if family_error != OK:
				return family_error
			var pending_error: Error = _reconcile_pending_records_for_file(file_name)
			if pending_error != OK:
				return pending_error
			var record_error: Error = _validate_final_transaction_records_for_file(
				file_name
			)
			if record_error != OK:
				return record_error
			var marker_read: Dictionary = _read_first_transaction_marker_result(file_name)
			var marker_error: Error = GFVariantData.get_option_int(
				marker_read,
				"error",
				ERR_FILE_CORRUPT
			) as Error
			if marker_error == ERR_FILE_NOT_FOUND:
				continue
			if marker_error != OK:
				return marker_error
			var marker: Dictionary = GFVariantData.get_option_dictionary(marker_read, "record")

			var transaction_files_result: Dictionary = _discover_transaction_marker_files(
				marker,
				file_name
			)
			var transaction_files_error: Error = GFVariantData.get_option_int(
				transaction_files_result,
				"error",
				ERR_FILE_CORRUPT
			) as Error
			if transaction_files_error != OK:
				return transaction_files_error
			var transaction_files: Array[String] = []
			transaction_files.assign(
				GFVariantData.get_option_array(transaction_files_result, "files")
			)
			var recovery_error: Error = _recover_transaction_group(transaction_files)
			if recovery_error != OK:
				return recovery_error
			for transaction_file_name: String in transaction_files:
				recovered_files[transaction_file_name] = true

		for file_name: String in file_names:
			if not recovered_files.has(file_name):
				var recovery_error: Error = _recover_transaction_file(file_name)
				if recovery_error != OK:
					return recovery_error
		return OK

	func _recover_frozen_file_family(
		file_name: String,
		final_path: String,
		temp_path: String,
		backup_path: String,
		transaction_path: String,
		transaction_commit_path: String
	) -> Error:
		if (
			_path_policy._get_full_path(file_name) != final_path
			or _path_policy._get_full_path(_get_temp_filename(file_name)) != temp_path
			or _path_policy._get_full_path(_get_backup_filename(file_name)) != backup_path
			or _path_policy._get_full_path(_get_transaction_filename(file_name)) != transaction_path
			or _path_policy._get_full_path(_get_transaction_commit_filename(file_name)) != transaction_commit_path
		):
			return ERR_INVALID_PARAMETER
		return _recover_transaction_file(file_name)

	func _recover_single_file_family(
		file_name: String,
		final_path: String,
		temp_path: String,
		backup_path: String,
		transaction_path: String
	) -> Error:
		if (
			_path_policy._get_full_path(file_name) != final_path
			or _path_policy._get_full_path(_get_temp_filename(file_name)) != temp_path
			or _path_policy._get_full_path(_get_backup_filename(file_name)) != backup_path
			or _path_policy._get_full_path(_get_transaction_filename(file_name)) != transaction_path
		):
			return ERR_INVALID_PARAMETER
		return _recover_transaction_group([file_name])

	func _recover_transaction_group(file_names: Array[String]) -> Error:
		file_names = _unique_file_names(file_names)
		file_names.sort()
		if file_names.is_empty():
			return ERR_INVALID_PARAMETER
		for file_name: String in file_names:
			var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
				_path_policy._get_save_base_path(),
				file_name
			)
			var family_error: Error = _family_store.validate_family_for_framework(descriptor)
			if family_error != OK:
				return family_error
			var pending_error: Error = _reconcile_pending_records_for_file(file_name)
			if pending_error != OK:
				return pending_error
			var record_error: Error = _validate_final_transaction_records_for_file(
				file_name
			)
			if record_error != OK:
				return record_error

		var transaction_reference_read: Dictionary = _find_transaction_reference(file_names)
		var transaction_reference_error: Error = GFVariantData.get_option_int(
			transaction_reference_read,
			"error",
			ERR_FILE_CORRUPT
		) as Error
		if transaction_reference_error == ERR_FILE_NOT_FOUND:
			return _validate_stable_group_without_evidence(file_names)
		if transaction_reference_error != OK:
			return transaction_reference_error
		var transaction_reference: Dictionary = GFVariantData.get_option_dictionary(
			transaction_reference_read,
			"record"
		)
		if _get_transaction_marker_files(
			transaction_reference,
			GFVariantData.get_option_string(
				GFVariantData.get_option_dictionary(transaction_reference, "owner"),
				"logical_path"
			),
			file_names
		) != file_names:
			return ERR_FILE_CORRUPT

		var prepare_count: int = 0
		var commit_count: int = 0
		for file_name: String in file_names:
			var prepare_read: Dictionary = _read_transaction_marker_result(file_name)
			var prepare_error: Error = GFVariantData.get_option_int(
				prepare_read,
				"error",
				ERR_FILE_CORRUPT
			) as Error
			if prepare_error == OK:
				var prepare: Dictionary = GFVariantData.get_option_dictionary(
					prepare_read,
					"record"
				)
				if not _markers_share_snapshot(transaction_reference, prepare, file_name, false):
					return ERR_FILE_CORRUPT
				prepare_count += 1
			elif prepare_error != ERR_FILE_NOT_FOUND:
				return prepare_error
			var commit_read: Dictionary = _read_transaction_commit_marker_result(file_name)
			var commit_error: Error = GFVariantData.get_option_int(
				commit_read,
				"error",
				ERR_FILE_CORRUPT
			) as Error
			if commit_error == OK:
				var commit: Dictionary = GFVariantData.get_option_dictionary(
					commit_read,
					"record"
				)
				if not _markers_share_snapshot(transaction_reference, commit, file_name, true):
					return ERR_FILE_CORRUPT
				commit_count += 1
			elif commit_error != ERR_FILE_NOT_FOUND:
				return commit_error

		if commit_count == file_names.size():
			return _finalize_committed_group(file_names)
		if commit_count > 0:
			if prepare_count == file_names.size():
				return _rollback_group_from_record(file_names, transaction_reference)
			if prepare_count == 0 and _group_matches_committed_cleanup(
				file_names,
				transaction_reference
			):
				return _finalize_committed_group(file_names)
			return ERR_FILE_CORRUPT
		if prepare_count == file_names.size():
			return _rollback_group_from_record(file_names, transaction_reference)
		if prepare_count > 0 and _group_matches_rolled_back_state(
			file_names,
			transaction_reference
		):
			return _cleanup_prepare_records(file_names)
		return ERR_FILE_CORRUPT

	func _recover_transaction_file(file_name: String) -> Error:
		var pending_error: Error = _reconcile_pending_records_for_file(file_name)
		if pending_error != OK:
			return pending_error
		var record_error: Error = _validate_final_transaction_records_for_file(file_name)
		if record_error != OK:
			return record_error
		var marker_read: Dictionary = _read_first_transaction_marker_result(file_name)
		var marker_error: Error = GFVariantData.get_option_int(
			marker_read,
			"error",
			ERR_FILE_CORRUPT
		) as Error
		if marker_error == ERR_FILE_NOT_FOUND:
			return _validate_stable_group_without_evidence([file_name])
		if marker_error != OK:
			return marker_error
		var marker: Dictionary = GFVariantData.get_option_dictionary(marker_read, "record")
		var transaction_files_result: Dictionary = _discover_transaction_marker_files(
			marker,
			file_name
		)
		var transaction_files_error: Error = GFVariantData.get_option_int(
			transaction_files_result,
			"error",
			ERR_FILE_CORRUPT
		) as Error
		if transaction_files_error != OK:
			return transaction_files_error
		var transaction_files: Array[String] = []
		transaction_files.assign(
			GFVariantData.get_option_array(transaction_files_result, "files")
		)
		return _recover_transaction_group(transaction_files)

	func _reconcile_pending_records_for_file(file_name: String) -> Error:
		for committed: bool in [false, true]:
			var final_path: String = _path_policy._get_full_path(
				_get_transaction_commit_filename(file_name)
				if committed
				else _get_transaction_filename(file_name)
			)
			var pending_path: String = _path_policy._get_full_path(
				_get_transaction_commit_pending_filename(file_name)
				if committed
				else _get_transaction_pending_filename(file_name)
			)
			if not FileAccess.file_exists(pending_path):
				continue
			var pending_read: Dictionary = _read_transaction_marker_result_absolute(pending_path)
			var pending_error: Error = GFVariantData.get_option_int(
				pending_read,
				"error",
				ERR_FILE_CORRUPT
			) as Error
			if pending_error != OK:
				return pending_error
			var pending: Dictionary = GFVariantData.get_option_dictionary(pending_read, "record")
			if (
				not _is_valid_marker_for_member(pending, file_name)
				or GFVariantData.get_option_bool(pending, "committed") != committed
			):
				return ERR_FILE_CORRUPT
			if FileAccess.file_exists(final_path):
				var final_read: Dictionary = _read_transaction_marker_result_absolute(final_path)
				var final_error: Error = GFVariantData.get_option_int(
					final_read,
					"error",
					ERR_FILE_CORRUPT
				) as Error
				if final_error != OK:
					return final_error
				var final_record: Dictionary = GFVariantData.get_option_dictionary(
					final_read,
					"record"
				)
				if not _transaction_records_match(final_record, pending):
					return ERR_FILE_CORRUPT
				var remove_stale_pending: Error = _file_ops._remove_absolute(pending_path)
				if remove_stale_pending != OK:
					return remove_stale_pending
				continue
			if committed and not FileAccess.file_exists(
				_path_policy._get_full_path(_get_transaction_filename(file_name))
			):
				return ERR_FILE_CORRUPT
			var promote_error: Error = DirAccess.rename_absolute(pending_path, final_path)
			if promote_error != OK:
				if not FileAccess.file_exists(final_path):
					return promote_error
				var promoted_read: Dictionary = _read_transaction_marker_result_absolute(final_path)
				var promoted_error: Error = GFVariantData.get_option_int(
					promoted_read,
					"error",
					ERR_FILE_CORRUPT
				) as Error
				if promoted_error != OK:
					return promoted_error
				var promoted: Dictionary = GFVariantData.get_option_dictionary(
					promoted_read,
					"record"
				)
				if not _transaction_records_match(pending, promoted):
					return ERR_FILE_CORRUPT
				var remove_raced_pending: Error = _file_ops._remove_absolute(pending_path)
				if remove_raced_pending != OK:
					return remove_raced_pending
		return OK

	func _validate_final_transaction_records_for_file(file_name: String) -> Error:
		for committed: bool in [false, true]:
			var record_path: String = _path_policy._get_full_path(
				_get_transaction_commit_filename(file_name)
				if committed
				else _get_transaction_filename(file_name)
			)
			if not FileAccess.file_exists(record_path):
				continue
			var record_read: Dictionary = _read_transaction_marker_result_absolute(record_path)
			var read_error: Error = GFVariantData.get_option_int(
				record_read,
				"error",
				ERR_FILE_CORRUPT
			) as Error
			if read_error != OK:
				return read_error
			var record: Dictionary = GFVariantData.get_option_dictionary(record_read, "record")
			if (
				not _is_valid_marker_for_member(record, file_name)
				or GFVariantData.get_option_bool(record, "committed") != committed
			):
				return ERR_FILE_CORRUPT
		return OK

	func _find_transaction_reference(file_names: Array[String]) -> Dictionary:
		for file_name: String in file_names:
			var prepare_read: Dictionary = _read_transaction_marker_result(file_name)
			var prepare_error: Error = GFVariantData.get_option_int(
				prepare_read,
				"error",
				ERR_FILE_CORRUPT
			) as Error
			if prepare_error == OK:
				return prepare_read
			if prepare_error != ERR_FILE_NOT_FOUND:
				return prepare_read
			var commit_read: Dictionary = _read_transaction_commit_marker_result(file_name)
			var commit_error: Error = GFVariantData.get_option_int(
				commit_read,
				"error",
				ERR_FILE_CORRUPT
			) as Error
			if commit_error != ERR_FILE_NOT_FOUND:
				return commit_read
		return {"error": int(ERR_FILE_NOT_FOUND), "record": {}}

	func _validate_stable_group_without_evidence(file_names: Array[String]) -> Error:
		for file_name: String in file_names:
			for sidecar_path: String in [
				_path_policy._get_full_path(_get_temp_filename(file_name)),
				_path_policy._get_full_path(_get_backup_filename(file_name)),
			]:
				if FileAccess.file_exists(sidecar_path):
					return ERR_FILE_CORRUPT
			var resource_stage_path: String = GFVariantData.get_option_string(
				GFStorageFamilyStore.make_family_descriptor_for_framework(
					_path_policy._get_save_base_path(),
					file_name
				),
				"resource_stage_path"
			)
			var cleanup_error: Error = _file_ops._remove_absolute(resource_stage_path)
			if cleanup_error != OK:
				return cleanup_error
		return OK

	func _group_matches_committed_cleanup(
		file_names: Array[String],
		_reference: Dictionary
	) -> bool:
		for file_name: String in file_names:
			if not FileAccess.file_exists(_path_policy._get_full_path(file_name)):
				return false
			if (
				FileAccess.file_exists(_path_policy._get_full_path(_get_temp_filename(file_name)))
				or FileAccess.file_exists(_path_policy._get_full_path(_get_backup_filename(file_name)))
			):
				return false
		return true

	func _group_matches_rolled_back_state(
		file_names: Array[String],
		transaction_reference: Dictionary
	) -> bool:
		for file_name: String in file_names:
			var final_exists: bool = FileAccess.file_exists(
				_path_policy._get_full_path(file_name)
			)
			if final_exists != _get_marker_had_final(transaction_reference, file_name):
				return false
			if (
				FileAccess.file_exists(_path_policy._get_full_path(_get_temp_filename(file_name)))
				or FileAccess.file_exists(_path_policy._get_full_path(_get_backup_filename(file_name)))
			):
				return false
		return true

	func _finalize_committed_group(file_names: Array[String]) -> Error:
		var terminal_error: Error = _validate_committed_group_state(file_names)
		if terminal_error != OK:
			return terminal_error
		return _cleanup_committed_group_evidence(file_names)

	func _validate_committed_group_state(file_names: Array[String]) -> Error:
		for file_name: String in file_names:
			if not FileAccess.file_exists(_path_policy._get_full_path(file_name)):
				return ERR_FILE_CORRUPT
			if FileAccess.file_exists(_path_policy._get_full_path(_get_temp_filename(file_name))):
				return ERR_FILE_CORRUPT
		return OK

	func _cleanup_committed_group_evidence(file_names: Array[String]) -> Error:
		for file_name: String in file_names:
			for cleanup_path: String in [
				_path_policy._get_full_path(_get_backup_filename(file_name)),
				GFVariantData.get_option_string(
					GFStorageFamilyStore.make_family_descriptor_for_framework(
						_path_policy._get_save_base_path(),
						file_name
					),
					"resource_stage_path"
				),
			]:
				var cleanup_error: Error = _file_ops._remove_absolute(cleanup_path)
				if cleanup_error != OK:
					return cleanup_error
		var prepare_cleanup_error: Error = _cleanup_prepare_records(file_names)
		if prepare_cleanup_error != OK:
			return prepare_cleanup_error
		return _cleanup_commit_records(file_names)

	func _rollback_group_from_record(
		file_names: Array[String],
		transaction_reference: Dictionary
	) -> Error:
		for file_name: String in file_names:
			var final_path: String = _path_policy._get_full_path(file_name)
			var temp_path: String = _path_policy._get_full_path(_get_temp_filename(file_name))
			var backup_path: String = _path_policy._get_full_path(_get_backup_filename(file_name))
			var had_final: bool = _get_marker_had_final(transaction_reference, file_name)
			if had_final:
				if FileAccess.file_exists(backup_path):
					var remove_new_final: Error = _file_ops._remove_absolute(final_path)
					if remove_new_final != OK:
						return remove_new_final
					var restore_error: Error = _file_ops._move_file(backup_path, final_path)
					if restore_error != OK:
						return restore_error
				elif not FileAccess.file_exists(final_path):
					return ERR_FILE_CORRUPT
			else:
				if FileAccess.file_exists(backup_path):
					return ERR_FILE_CORRUPT
				var remove_new_file: Error = _file_ops._remove_absolute(final_path)
				if remove_new_file != OK:
					return remove_new_file
			var remove_candidate: Error = _file_ops._remove_absolute(temp_path)
			if remove_candidate != OK:
				return remove_candidate
			var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
				_path_policy._get_save_base_path(),
				file_name
			)
			var remove_resource_stage: Error = _file_ops._remove_absolute(
				GFVariantData.get_option_string(descriptor, "resource_stage_path")
			)
			if remove_resource_stage != OK:
				return remove_resource_stage
		if not _group_matches_rolled_back_state(file_names, transaction_reference):
			return ERR_FILE_CORRUPT
		var commit_cleanup_error: Error = _cleanup_commit_records(file_names)
		if commit_cleanup_error != OK:
			return commit_cleanup_error
		return _cleanup_prepare_records(file_names)

	func _cleanup_prepare_records(file_names: Array[String]) -> Error:
		for file_name: String in file_names:
			for path: String in [
				_path_policy._get_full_path(_get_transaction_pending_filename(file_name)),
				_path_policy._get_full_path(_get_transaction_filename(file_name)),
			]:
				var cleanup_error: Error = _file_ops._remove_absolute(path)
				if cleanup_error != OK:
					return cleanup_error
		return OK

	func _cleanup_commit_records(file_names: Array[String]) -> Error:
		for file_name: String in file_names:
			for path: String in [
				_path_policy._get_full_path(_get_transaction_commit_pending_filename(file_name)),
				_path_policy._get_full_path(_get_transaction_commit_filename(file_name)),
			]:
				var cleanup_error: Error = _file_ops._remove_absolute(path)
				if cleanup_error != OK:
					return cleanup_error
		return OK

	func _commit_transaction(file_names: Array[String], markers_prepared: bool = false) -> Error:
		file_names = _unique_file_names(file_names)
		file_names.sort()
		if file_names.is_empty():
			return ERR_INVALID_PARAMETER
		if markers_prepared:
			var prepared_error: Error = _validate_transaction_group(file_names)
			if prepared_error != OK:
				return prepared_error
		else:
			var marker_error: Error = _write_transaction_markers(file_names, false)
			if marker_error != OK:
				return marker_error

		for file_name: String in file_names:
			var backup_path: String = _path_policy._get_full_path(_get_backup_filename(file_name))
			var final_path: String = _path_policy._get_full_path(file_name)
			if FileAccess.file_exists(final_path):
				var backup_error: Error = _file_ops._move_file(final_path, backup_path)
				if backup_error != OK:
					var rollback_error: Error = _recover_transaction_group(file_names)
					return backup_error if rollback_error == OK else rollback_error

		for file_name: String in file_names:
			var temp_path: String = _path_policy._get_full_path(_get_temp_filename(file_name))
			var final_path: String = _path_policy._get_full_path(file_name)
			var commit_error: Error = _file_ops._move_file(temp_path, final_path)
			if commit_error != OK:
				var rollback_error: Error = _recover_transaction_group(file_names)
				return commit_error if rollback_error == OK else rollback_error

		var complete_marker_error: Error = _write_transaction_markers(file_names, true)
		if complete_marker_error != OK:
			var rollback_error: Error = _recover_transaction_group(file_names)
			return complete_marker_error if rollback_error == OK else rollback_error

		var terminal_error: Error = _validate_committed_group_state(file_names)
		if terminal_error != OK:
			return terminal_error
		var cleanup_error: Error = _cleanup_committed_group_evidence(file_names)
		if cleanup_error != OK:
			push_warning(
				"[GFStorageUtility] 事务已提交，但证据清理尚未收敛，错误码：%s。" % cleanup_error
			)
		return OK

	func _rollback_transaction(
		file_names: Array[String],
		_transaction_state: Dictionary
	) -> Error:
		file_names = _unique_file_names(file_names)
		file_names.sort()
		var transaction_reference_read: Dictionary = _find_transaction_reference(file_names)
		var transaction_reference_error: Error = GFVariantData.get_option_int(
			transaction_reference_read,
			"error",
			ERR_FILE_CORRUPT
		) as Error
		if transaction_reference_error != OK:
			return (
				ERR_FILE_CORRUPT
				if transaction_reference_error == ERR_FILE_NOT_FOUND
				else transaction_reference_error
			)
		var transaction_reference: Dictionary = GFVariantData.get_option_dictionary(
			transaction_reference_read,
			"record"
		)
		return _rollback_group_from_record(file_names, transaction_reference)

	func _write_transaction_markers(file_names: Array[String], committed: bool) -> Error:
		file_names = _unique_file_names(file_names)
		file_names.sort()
		if file_names.is_empty() or file_names.size() > GFStorageUtility._MAX_TRANSACTION_FILES:
			return ERR_INVALID_PARAMETER
		var transaction_id: String
		var had_final_by_file: Dictionary = {}
		if committed:
			var first_prepare_read: Dictionary = _read_transaction_marker_result(file_names[0])
			var first_prepare_error: Error = GFVariantData.get_option_int(
				first_prepare_read,
				"error",
				ERR_FILE_CORRUPT
			) as Error
			if first_prepare_error != OK:
				return (
					ERR_FILE_CORRUPT
					if first_prepare_error == ERR_FILE_NOT_FOUND
					else first_prepare_error
				)
			var first_prepare: Dictionary = GFVariantData.get_option_dictionary(
				first_prepare_read,
				"record"
			)
			if not _is_valid_marker_for_member(first_prepare, file_names[0]):
				return ERR_FILE_CORRUPT
			transaction_id = GFVariantData.get_option_string(first_prepare, "transaction_id")
			for file_name: String in file_names:
				var prepare_read: Dictionary = _read_transaction_marker_result(file_name)
				var prepare_error: Error = GFVariantData.get_option_int(
					prepare_read,
					"error",
					ERR_FILE_CORRUPT
				) as Error
				if prepare_error != OK:
					return (
						ERR_FILE_CORRUPT
						if prepare_error == ERR_FILE_NOT_FOUND
						else prepare_error
					)
				var prepare_marker: Dictionary = GFVariantData.get_option_dictionary(
					prepare_read,
					"record"
				)
				if not _markers_share_snapshot(first_prepare, prepare_marker, file_name, false):
					return ERR_FILE_CORRUPT
				had_final_by_file[file_name] = _get_marker_had_final(first_prepare, file_name)
		else:
			transaction_id = "%d:%d" % [Time.get_ticks_usec(), _next_transaction_id]
			_next_transaction_id += 1
			for file_name: String in file_names:
				had_final_by_file[file_name] = FileAccess.file_exists(
					_path_policy._get_full_path(file_name)
				)
		for file_name: String in file_names:
			var marker: Dictionary = GFStorageUtility._make_transaction_marker(
				file_names,
				file_name,
				transaction_id,
				committed,
				had_final_by_file
			)
			var marker_path: String = _path_policy._get_full_path(
				_get_transaction_commit_filename(file_name)
				if committed
				else _get_transaction_filename(file_name)
			)
			var pending_path: String = _path_policy._get_full_path(
				_get_transaction_commit_pending_filename(file_name)
				if committed
				else _get_transaction_pending_filename(file_name)
			)
			var error: Error = _publish_transaction_record(marker_path, pending_path, marker)
			if error != OK:
				if not committed:
					var _aborted: Error = _abort_partial_prepare(file_names, transaction_id)
				return error
		return OK

	func _read_transaction_marker(file_name: String) -> Dictionary:
		return GFVariantData.get_option_dictionary(
			_read_transaction_marker_result(file_name),
			"record"
		)

	func _read_transaction_commit_marker(file_name: String) -> Dictionary:
		return GFVariantData.get_option_dictionary(
			_read_transaction_commit_marker_result(file_name),
			"record"
		)

	func _read_transaction_marker_result(file_name: String) -> Dictionary:
		var path: String = _path_policy._get_full_path(_get_transaction_filename(file_name))
		return _read_transaction_marker_result_absolute(path)

	func _read_transaction_commit_marker_result(file_name: String) -> Dictionary:
		var path: String = _path_policy._get_full_path(
			_get_transaction_commit_filename(file_name)
		)
		return _read_transaction_marker_result_absolute(path)

	func _read_first_transaction_marker_result(file_name: String) -> Dictionary:
		var prepare_read: Dictionary = _read_transaction_marker_result(file_name)
		var prepare_error: Error = GFVariantData.get_option_int(
			prepare_read,
			"error",
			ERR_FILE_CORRUPT
		) as Error
		if prepare_error != ERR_FILE_NOT_FOUND:
			return prepare_read
		return _read_transaction_commit_marker_result(file_name)

	func _publish_transaction_record(
		path: String,
		pending_path: String,
		record: Dictionary
	) -> Error:
		var owner: Dictionary = GFVariantData.get_option_dictionary(record, "owner")
		var owner_file_name: String = GFVariantData.get_option_string(owner, "logical_path")
		if not _is_valid_marker_for_member(record, owner_file_name):
			return ERR_INVALID_DATA
		if FileAccess.file_exists(path):
			return _match_transaction_record_at_path(record, path)
		if FileAccess.file_exists(pending_path):
			var pending_match_error: Error = _match_transaction_record_at_path(
				record,
				pending_path
			)
			if pending_match_error != OK:
				return pending_match_error
		else:
			var write_error: Error = _file_ops._write_plain_json_absolute(
				pending_path,
				record
			)
			if write_error != OK:
				return write_error
			var written_match_error: Error = _match_transaction_record_at_path(
				record,
				pending_path
			)
			if written_match_error != OK:
				return written_match_error
		var publish_error: Error = DirAccess.rename_absolute(pending_path, path)
		if publish_error == OK:
			return OK
		if not FileAccess.file_exists(path):
			return publish_error
		var published_match_error: Error = _match_transaction_record_at_path(
			record,
			path
		)
		if published_match_error != OK:
			return published_match_error
		var _pending_cleanup_error: Error = _file_ops._remove_absolute(pending_path)
		return OK

	func _abort_partial_prepare(file_names: Array[String], transaction_id: String) -> Error:
		for file_name: String in file_names:
			if (
				FileAccess.file_exists(_path_policy._get_full_path(_get_temp_filename(file_name)))
				or FileAccess.file_exists(_path_policy._get_full_path(_get_backup_filename(file_name)))
				or FileAccess.file_exists(_path_policy._get_full_path(_get_transaction_commit_filename(file_name)))
			):
				return ERR_FILE_CORRUPT
		for file_name: String in file_names:
			var prepare_path: String = _path_policy._get_full_path(
				_get_transaction_filename(file_name)
			)
			if FileAccess.file_exists(prepare_path):
				var prepare_read: Dictionary = _read_transaction_marker_result_absolute(
					prepare_path
				)
				var prepare_error: Error = GFVariantData.get_option_int(
					prepare_read,
					"error",
					ERR_FILE_CORRUPT
				) as Error
				if prepare_error != OK:
					return prepare_error
				var prepare: Dictionary = GFVariantData.get_option_dictionary(
					prepare_read,
					"record"
				)
				if GFVariantData.get_option_string(prepare, "transaction_id") != transaction_id:
					return ERR_FILE_CORRUPT
				var remove_prepare_error: Error = _file_ops._remove_absolute(prepare_path)
				if remove_prepare_error != OK:
					return remove_prepare_error
			var remove_pending_error: Error = _file_ops._remove_absolute(
				_path_policy._get_full_path(_get_transaction_pending_filename(file_name))
			)
			if remove_pending_error != OK:
				return remove_pending_error
		return OK

	func _transaction_records_match(expected: Dictionary, actual: Dictionary) -> bool:
		var expected_owner: Dictionary = GFVariantData.get_option_dictionary(
			expected,
			"owner"
		)
		var owner_file_name: String = GFVariantData.get_option_string(
			expected_owner,
			"logical_path"
		)
		if not _is_valid_marker_for_member(expected, owner_file_name):
			return false
		if not _is_valid_marker_for_member(actual, owner_file_name):
			return false
		return (
			GFVariantData.get_option_string(expected, "transaction_id")
			== GFVariantData.get_option_string(actual, "transaction_id")
			and GFVariantData.get_option_bool(expected, "committed")
			== GFVariantData.get_option_bool(actual, "committed")
			and GFVariantData.get_option_dictionary(expected, "owner")
			== GFVariantData.get_option_dictionary(actual, "owner")
			and GFVariantData.get_option_array(expected, "members")
			== GFVariantData.get_option_array(actual, "members")
		)

	func _markers_share_snapshot(
		transaction_reference: Dictionary,
		candidate: Dictionary,
		candidate_owner: String,
		expected_committed: bool
	) -> bool:
		return (
			_is_valid_marker_for_member(candidate, candidate_owner)
			and GFVariantData.get_option_bool(candidate, "committed") == expected_committed
			and GFVariantData.get_option_string(transaction_reference, "transaction_id")
			== GFVariantData.get_option_string(candidate, "transaction_id")
			and GFVariantData.get_option_array(transaction_reference, "members")
			== GFVariantData.get_option_array(candidate, "members")
		)

	func _get_marker_had_final(marker: Dictionary, file_name: String) -> bool:
		for member_value: Variant in GFVariantData.get_option_array(marker, "members"):
			var member: Dictionary = GFVariantData.as_dictionary(member_value)
			if GFVariantData.get_option_string(member, "logical_path") == file_name:
				return GFVariantData.get_option_bool(member, "had_final")
		return false

	func _match_transaction_record_at_path(expected: Dictionary, path: String) -> Error:
		var read_result: Dictionary = _read_transaction_marker_result_absolute(path)
		var read_error: Error = GFVariantData.get_option_int(
			read_result,
			"error",
			ERR_FILE_CORRUPT
		) as Error
		if read_error != OK:
			return read_error
		return (
			OK
			if _transaction_records_match(
				expected,
				GFVariantData.get_option_dictionary(read_result, "record")
			)
			else ERR_FILE_CORRUPT
		)

	func _read_transaction_marker_result_absolute(path: String) -> Dictionary:
		return GFStorageUtility._read_transaction_record_result_absolute(path)

	func _read_transaction_marker_absolute(path: String) -> Dictionary:
		return GFVariantData.get_option_dictionary(
			_read_transaction_marker_result_absolute(path),
			"record"
		)

	func _get_transaction_marker_files(
		marker: Dictionary,
		fallback_file_name: String,
		allowed_file_names: Array[String] = []
	) -> Array[String]:
		fallback_file_name = _canonicalize_marker_file_name(fallback_file_name)
		if fallback_file_name.is_empty() or not _is_valid_marker_for_member(
			marker,
			fallback_file_name
		):
			return []
		var result: Array[String] = []
		for member_value: Variant in GFVariantData.get_option_array(marker, "members"):
			var member: Dictionary = GFVariantData.as_dictionary(member_value)
			result.append(GFVariantData.get_option_string(member, "logical_path"))
		var canonical_allowed_file_names: Array[String] = _unique_file_names(allowed_file_names)
		canonical_allowed_file_names.sort()
		if not canonical_allowed_file_names.is_empty() and result != canonical_allowed_file_names:
			return []
		return result

	func _discover_transaction_marker_files(
		marker: Dictionary,
		fallback_file_name: String
	) -> Dictionary:
		var declared_files: Array[String] = _get_transaction_marker_files(
			marker,
			fallback_file_name
		)
		if declared_files.is_empty():
			return {"error": int(ERR_FILE_CORRUPT), "files": []}
		for file_name: String in declared_files:
			var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
				_path_policy._get_save_base_path(),
				file_name
			)
			var family_error: Error = _family_store.validate_family_for_framework(descriptor)
			if family_error != OK:
				return {
					"error": int(
						ERR_FILE_CORRUPT
						if family_error in [ERR_FILE_NOT_FOUND, ERR_FILE_CORRUPT]
						else family_error
					),
					"files": [],
				}
		return {"error": int(OK), "files": declared_files}

	func _is_transaction_group_committed(file_names: Array[String]) -> bool:
		return _is_transaction_group_in_state(file_names, true)

	func _is_transaction_group_in_state(file_names: Array[String], committed: bool) -> bool:
		file_names = _unique_file_names(file_names)
		file_names.sort()
		if file_names.is_empty():
			return false
		var transaction_reference: Dictionary = {}
		for file_name: String in file_names:
			var marker: Dictionary = (
				_read_transaction_commit_marker(file_name)
				if committed
				else _read_transaction_marker(file_name)
			)
			var marker_files: Array[String] = _get_transaction_marker_files(marker, file_name, file_names)
			if (
				marker.is_empty()
				or GFVariantData.get_option_bool(marker, "committed") != committed
				or marker_files != file_names
			):
				return false
			if transaction_reference.is_empty():
				transaction_reference = marker
			elif not _markers_share_snapshot(transaction_reference, marker, file_name, committed):
				return false
			if not committed and FileAccess.file_exists(
				_path_policy._get_full_path(_get_transaction_commit_filename(file_name))
			):
				return false
		return true

	func _validate_transaction_group(file_names: Array[String]) -> Error:
		file_names = _unique_file_names(file_names)
		file_names.sort()
		if file_names.is_empty():
			return ERR_INVALID_PARAMETER
		var transaction_reference: Dictionary = {}
		for file_name: String in file_names:
			var descriptor: Dictionary = GFStorageFamilyStore.make_family_descriptor_for_framework(
				_path_policy._get_save_base_path(),
				file_name
			)
			var family_error: Error = _family_store.validate_family_for_framework(descriptor)
			if family_error != OK:
				return family_error
			var marker_read: Dictionary = _read_transaction_marker_result(file_name)
			var marker_error: Error = GFVariantData.get_option_int(
				marker_read,
				"error",
				ERR_FILE_CORRUPT
			) as Error
			if marker_error != OK:
				return (
					ERR_FILE_CORRUPT
					if marker_error == ERR_FILE_NOT_FOUND
					else marker_error
				)
			var marker: Dictionary = GFVariantData.get_option_dictionary(
				marker_read,
				"record"
			)
			if not _is_valid_marker_for_member(marker, file_name):
				return ERR_FILE_CORRUPT
			if GFVariantData.get_option_bool(marker, "committed"):
				return ERR_FILE_CORRUPT
			if _get_transaction_marker_files(marker, file_name, file_names) != file_names:
				return ERR_FILE_CORRUPT
			if transaction_reference.is_empty():
				transaction_reference = marker
			elif not _markers_share_snapshot(transaction_reference, marker, file_name, false):
				return ERR_FILE_CORRUPT
		return OK

	func _is_valid_marker_for_member(marker: Dictionary, file_name: String) -> bool:
		if marker.size() != 6:
			return false
		var committed_value: Variant = marker.get("committed")
		if not committed_value is bool:
			return false
		var committed: bool = committed_value
		var schema_value: Variant = marker.get("schema")
		var transaction_id_value: Variant = marker.get("transaction_id")
		var expected_schema: String = (
			GFStorageUtility._TRANSACTION_COMMIT_SCHEMA
			if committed
			else GFStorageUtility._TRANSACTION_PREPARE_SCHEMA
		)
		if not schema_value is String or not transaction_id_value is String:
			return false
		var schema: String = schema_value
		var transaction_id: String = transaction_id_value
		if (
			schema != expected_schema
			or GFVariantData.to_exact_int(marker.get("schema_version"), -1) != GFStorageUtility._TRANSACTION_MARKER_SCHEMA_VERSION
			or transaction_id.is_empty()
		):
			return false
		var owner_value: Variant = marker.get("owner")
		var members_value: Variant = marker.get("members")
		if not owner_value is Dictionary or not members_value is Array:
			return false
		var owner: Dictionary = GFVariantData.as_dictionary(owner_value)
		var owner_logical_path_value: Variant = owner.get("logical_path")
		var owner_family_id_value: Variant = owner.get("family_id")
		if (
			owner.size() != 2
			or not owner_logical_path_value is String
			or not owner_family_id_value is String
			or owner_logical_path_value != file_name
			or owner_family_id_value != GFStorageFamilyStore.make_family_id_for_framework(file_name)
		):
			return false
		var previous_file_name: String = ""
		var member_count: int = 0
		var has_owner: bool = false
		for member_value: Variant in GFVariantData.get_option_array(marker, "members"):
			var member: Dictionary = GFVariantData.as_dictionary(member_value)
			var member_logical_path_value: Variant = member.get("logical_path")
			var member_family_id_value: Variant = member.get("family_id")
			if not member_logical_path_value is String or not member_family_id_value is String:
				return false
			var member_file_name: String = member_logical_path_value
			if (
				member.size() != 3
				or not GFStorageFamilyStore.is_valid_logical_file_path_for_framework(member_file_name)
				or member_family_id_value != GFStorageFamilyStore.make_family_id_for_framework(member_file_name)
				or not member.get("had_final") is bool
				or (not previous_file_name.is_empty() and member_file_name <= previous_file_name)
			):
				return false
			previous_file_name = member_file_name
			member_count += 1
			has_owner = has_owner or member_file_name == file_name
		return member_count > 0 and member_count <= GFStorageUtility._MAX_TRANSACTION_FILES and has_owner

	func _unique_file_names(file_names: Array[String]) -> Array[String]:
		var result: Array[String] = []
		for raw_file_name: String in file_names:
			var file_name: String = _path_policy._canonicalize_file_name(raw_file_name, "file_name")
			if not file_name.is_empty() and not result.has(file_name):
				result.append(file_name)
		return result

	func _canonicalize_marker_file_name(file_name: String) -> String:
		return file_name if GFStorageFamilyStore.is_valid_logical_file_path_for_framework(
			file_name
		) else ""
