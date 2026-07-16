## GFStorageBackend: 存储后端扩展接口。
##
## 该类只定义通用后端协议，不绑定本地、云、平台 SDK 或同步策略。
## 默认实现返回不可用结果；项目可继承它并由自定义 Utility 或派生的
## GFStorageUtility 组合使用。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFStorageBackend
extends RefCounted


# --- 公共方法 ---

## 初始化后端。
## [br]
## @api public
## [br]
## @param config: 后端配置字典。
## [br]
## @schema config: Dictionary，包含后端特定的初始化选项。
## [br]
## @return Godot Error 结果码。
func initialize(config: Dictionary = {}) -> Error:
	return _initialize(config)


## 关闭后端并释放资源。
## [br]
## @api public
func shutdown() -> void:
	_shutdown()


## 保存纯字典数据。
## [br]
## @api public
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @param data: 要保存的数据。
## [br]
## @param metadata: 可选元数据。
## [br]
## @schema data: Dictionary，存储后端持有的数据载荷。
## [br]
## @schema metadata: Dictionary，包含时间戳或修订号等后端特定元数据。
## [br]
## @return Godot Error 结果码。
func save_data(file_name: String, data: Dictionary, metadata: Dictionary = {}) -> Error:
	if file_name.is_empty():
		return ERR_INVALID_PARAMETER
	return _save_data(file_name, data.duplicate(true), metadata.duplicate(true))


## 读取纯字典数据。
## [br]
## @api public
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @return 结果字典，包含 ok、data、metadata、error。
## [br]
## @schema return: Dictionary，包含 ok: bool、data: Dictionary、metadata: Dictionary 和 error: String。
func load_data(file_name: String) -> Dictionary:
	if file_name.is_empty():
		return _make_result(false, {}, {}, "file_name is empty")
	return _load_data(file_name)


## 删除纯字典数据。
## [br]
## @api public
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @return Godot Error 结果码。
func delete_data(file_name: String) -> Error:
	if file_name.is_empty():
		return ERR_INVALID_PARAMETER
	return _delete_data(file_name)


## 判断逻辑文件是否存在。
## [br]
## @api public
## [br]
## @param file_name: 逻辑文件名。
## [br]
## @return 存在时返回 true。
func has_data(file_name: String) -> bool:
	if file_name.is_empty():
		return false
	return _has_data(file_name)


## 枚举后端中的逻辑文件。
## [br]
## @api public
## [br]
## @return 文件摘要数组。
## [br]
## @schema return: Array，包含 file_name: String 和可选 metadata: Dictionary 的 Dictionary 条目。
func list_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in _list_data():
		result.append(item.duplicate(true))
	return result


## 获取后端能力描述。
## [br]
## @api public
## [br]
## @return 能力字典副本。
## [br]
## @schema return: Dictionary，包含 read、write、delete、list 和 sync 布尔能力标记。
func get_capabilities() -> Dictionary:
	return _get_capabilities().duplicate(true)


## 获取后端能力报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 报告选项，支持 label、metadata、include_data_count、include_data_names。
## [br]
## @return 能力报告字典。
## [br]
## @schema options: Dictionary，包含 label、metadata、include_data_count 和 include_data_names。
## [br]
## @schema return: Dictionary，包含 ok、backend_class、label、capabilities、data_count、data_names 和 metadata。
func get_capability_report(options: Dictionary = {}) -> Dictionary:
	var capabilities: Dictionary = get_capabilities()
	var include_data_names: bool = GFVariantData.get_option_bool(options, "include_data_names", false)
	var include_data_count: bool = GFVariantData.get_option_bool(options, "include_data_count", true)
	var entries: Array[Dictionary] = list_data() if GFVariantData.get_option_bool(capabilities, "list") else []
	var data_names: PackedStringArray = _get_data_names_from_list(entries) if include_data_names else PackedStringArray()
	return {
		"ok": true,
		"backend_class": get_class(),
		"label": GFVariantData.get_option_string(options, "label"),
		"capabilities": capabilities,
		"data_count": entries.size() if include_data_count else -1,
		"data_names": data_names,
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}


# --- 可重写钩子 / 虚方法 ---

## 初始化具体后端。
## [br]
## @api protected
## [br]
## @param _config: 后端配置字典。
## [br]
## @schema _config: Dictionary，包含后端特定的初始化选项。
## [br]
## @return Godot Error 结果码。
func _initialize(_config: Dictionary) -> Error:
	return OK


## 释放具体后端持有的资源。
## [br]
## @api protected
func _shutdown() -> void:
	pass


## 保存纯字典数据到具体后端。
## [br]
## @api protected
## [br]
## @param _file_name: 逻辑文件名。
## [br]
## @param _data: 要保存的数据副本。
## [br]
## @param _metadata: 可选元数据副本。
## [br]
## @schema _data: Dictionary，存储后端持有的数据载荷。
## [br]
## @schema _metadata: Dictionary，包含时间戳或修订号等后端特定元数据。
## [br]
## @return Godot Error 结果码。
func _save_data(_file_name: String, _data: Dictionary, _metadata: Dictionary) -> Error:
	return ERR_UNAVAILABLE


## 从具体后端读取纯字典数据。
## [br]
## @api protected
## [br]
## @param _file_name: 逻辑文件名。
## [br]
## @return 结果字典，包含 ok、data、metadata、error。
## [br]
## @schema return: Dictionary，包含 ok: bool、data: Dictionary、metadata: Dictionary 和 error: String。
func _load_data(_file_name: String) -> Dictionary:
	return _make_result(false, {}, {}, "backend unavailable")


## 从具体后端删除纯字典数据。
## [br]
## @api protected
## [br]
## @param _file_name: 逻辑文件名。
## [br]
## @return Godot Error 结果码。
func _delete_data(_file_name: String) -> Error:
	return ERR_UNAVAILABLE


## 判断具体后端是否存在逻辑文件。
## [br]
## @api protected
## [br]
## @param _file_name: 逻辑文件名。
## [br]
## @return 存在时返回 true。
func _has_data(_file_name: String) -> bool:
	return false


## 枚举具体后端中的逻辑文件。
## [br]
## @api protected
## [br]
## @return 文件摘要数组。
## [br]
## @schema return: Array，包含 file_name: String 和可选 metadata: Dictionary 的 Dictionary 条目。
func _list_data() -> Array[Dictionary]:
	return []


## 获取具体后端能力描述。
## [br]
## @api protected
## [br]
## @return 能力字典。
## [br]
## @schema return: Dictionary，包含 read、write、delete、list 和 sync 布尔能力标记。
func _get_capabilities() -> Dictionary:
	return {
		"read": false,
		"write": false,
		"delete": false,
		"list": false,
		"sync": false,
	}


# --- 私有/辅助方法 ---

func _make_result(ok: bool, data: Dictionary, metadata: Dictionary, error: String) -> Dictionary:
	return GFResultDictionary.make(ok, {
		GFResultDictionary.KEY_DATA: data.duplicate(true),
		GFResultDictionary.KEY_METADATA: metadata.duplicate(true),
		GFResultDictionary.KEY_ERROR: error,
	})


func _get_data_names_from_list(entries: Array[Dictionary]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		var file_name: String = GFVariantData.get_option_string(entry, "file_name")
		if file_name.is_empty():
			continue
		var _append_result: bool = result.append(file_name)
	result.sort()
	return result
