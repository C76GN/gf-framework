## GFStorageSettingsStoreUtility: GFStorageUtility 的设置持久化适配器。
##
## 该 Utility 声明显式 Storage 生命周期依赖，只在依赖完成 ready 后缓存并同步转发
## 设置读取和写入；释放依赖时清理缓存，避免在 Storage quiesce 或 dispose 后继续访问。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 11.0.0
class_name GFStorageSettingsStoreUtility
extends GFSettingsStoreUtility


# --- 私有变量 ---

var _storage_utility: GFStorageUtility = null


# --- GF 生命周期方法 ---

## 在已声明的 Storage 依赖完成 ready 后缓存其实例。
## [br]
## @api public
## [br]
## @since 11.0.0
func ready() -> void:
	_storage_utility = null
	var utility: Object = get_utility(GFStorageUtility, true)
	if utility is GFStorageUtility:
		var storage_utility: GFStorageUtility = utility
		_storage_utility = storage_utility


## 释放缓存的 Storage 引用和架构依赖作用域。
## [br]
## @api public
## [br]
## @since 11.0.0
func release_dependencies() -> void:
	_storage_utility = null
	super.release_dependencies()


# --- 公共方法 ---

## 声明同步设置持久化所需的 Storage Utility。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 只包含 GFStorageUtility 的依赖声明。
func get_required_utilities() -> Array[Script]:
	return [GFStorageUtility]


## 检查 ready 阶段是否已经解析到 Storage Utility。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return Storage 依赖已缓存时返回 true。
func is_persistence_enabled() -> bool:
	return _storage_utility != null


## 通过缓存的 GFStorageUtility 同步读取设置。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param file_name: Storage root 内的逻辑文件名。
## [br]
## @return GFStorageUtility 的隔离读取结果；依赖不可用时返回 UNAVAILABLE。
func read_settings(file_name: String) -> GFStorageReadResult:
	if _storage_utility == null:
		return super.read_settings(file_name)
	var read_result: GFStorageReadResult = _storage_utility.load_data(file_name)
	if read_result == null:
		return GFStorageReadResult.new().configure_failure(
			"Settings storage returned no read result.",
			ERR_INVALID_DATA,
			{},
			GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
			0,
			GFStorageReadResult.FailureKind.IO_FAILED
		)
	return read_result.duplicate_result()


## 通过缓存的 GFStorageUtility 同步写入设置。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param file_name: Storage root 内的逻辑文件名。
## [br]
## @param data: 已由 Settings Utility 序列化的设置字典。
## [br]
## @schema data: Dictionary[String, Variant] persisted settings payload produced by GFSettingsUtility.to_dict(true).
## [br]
## @return GFStorageUtility 返回的 Godot Error 结果码；依赖不可用时返回 ERR_UNAVAILABLE。
func write_settings(file_name: String, data: Dictionary) -> Error:
	if _storage_utility == null:
		return super.write_settings(file_name, data)
	return _storage_utility.save_data(file_name, data)
