## GFSettingsStoreUtility: 设置持久化的同步物理端口。
##
## 该协议只定义设置载荷的读取、写入与能力查询，不绑定文件、Storage Utility、
## 云服务或平台 SDK。Architecture 模式且启用持久化时应注册一个派生 Store Utility；
## standalone 模式会由 GFSettingsUtility 自动持有 File Store。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 11.0.0
class_name GFSettingsStoreUtility
extends GFUtility


# --- 公共方法 ---

## 检查当前 Store 是否可以接纳同步持久化请求。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 可以读取和写入设置时返回 true。
func is_persistence_enabled() -> bool:
	return false


## 读取一个设置载荷。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param file_name: Store 内的逻辑设置文件名。
## [br]
## @return 强类型读取结果；默认返回 UNAVAILABLE。
func read_settings(file_name: String) -> GFStorageReadResult:
	return _make_unavailable_read_result(file_name)


## 写入一个设置载荷。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param file_name: Store 内的逻辑设置文件名。
## [br]
## @param data: 已由 Settings Utility 序列化的设置字典。
## [br]
## @schema data: Dictionary[String, Variant] persisted settings payload produced by GFSettingsUtility.to_dict(true).
## [br]
## @return Godot Error 结果码；默认返回 ERR_UNAVAILABLE。
func write_settings(file_name: String, data: Dictionary) -> Error:
	return _reject_unavailable_write(file_name, data)


# --- 私有/辅助方法 ---

func _make_unavailable_read_result(_file_name: String) -> GFStorageReadResult:
	return GFStorageReadResult.new().configure_failure(
		"Settings persistence store is unavailable.",
		ERR_UNAVAILABLE,
		{},
		GFStorageReadResult.IntegrityStatus.NOT_CHECKED,
		0,
		GFStorageReadResult.FailureKind.UNAVAILABLE
	)


func _reject_unavailable_write(_file_name: String, _data: Dictionary) -> Error:
	return ERR_UNAVAILABLE
