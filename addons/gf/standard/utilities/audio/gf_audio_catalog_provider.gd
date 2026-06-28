## GFAudioCatalogProvider: 通用音频目录提供器。
##
## 为编辑器选择器或构建工具提供事件、参数、状态和开关 ID 查询入口。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFAudioCatalogProvider
extends RefCounted


# --- 公共变量 ---

## 事件目录。
## [br]
## @api public
## [br]
## @schema events: 事件目录 Dictionary，键为事件 ID，值为条目元数据 Dictionary。
var events: Dictionary = {}

## 参数目录。
## [br]
## @api public
## [br]
## @schema parameters: 参数目录 Dictionary，键为参数 ID，值为条目元数据 Dictionary。
var parameters: Dictionary = {}

## 状态目录。
## [br]
## @api public
## [br]
## @schema states: 状态目录 Dictionary，键为状态 ID，值为条目元数据 Dictionary。
var states: Dictionary = {}

## 开关目录。
## [br]
## @api public
## [br]
## @schema switches: 开关目录 Dictionary，键为开关 ID，值为条目元数据 Dictionary。
var switches: Dictionary = {}


# --- 公共方法 ---

## 设置目录条目。
## [br]
## @api public
## [br]
## @param catalog_id: 目录标识，如 events、parameters、states、switches。
## [br]
## @param entry_id: 条目标识。
## [br]
## @param metadata: 条目元数据。
## [br]
## @schema metadata: 条目元数据 Dictionary；键和值由目录提供器或项目工具约定。
func set_entry(catalog_id: StringName, entry_id: StringName, metadata: Dictionary = {}) -> void:
	if entry_id == &"":
		return
	if not _is_known_catalog_id(catalog_id):
		push_warning("[GFAudioCatalogProvider] 未知音频目录：%s。" % String(catalog_id))
		return
	_get_catalog(catalog_id)[entry_id] = metadata.duplicate(true)


## 移除目录条目。
## [br]
## @api public
## [br]
## @param catalog_id: 目录标识。
## [br]
## @param entry_id: 条目标识。
func remove_entry(catalog_id: StringName, entry_id: StringName) -> void:
	if not _is_known_catalog_id(catalog_id):
		push_warning("[GFAudioCatalogProvider] 未知音频目录：%s。" % String(catalog_id))
		return
	var _erase_result_72: Variant = _get_catalog(catalog_id).erase(entry_id)


## 获取目录 ID 列表。
## [br]
## @api public
## [br]
## @param catalog_id: 目录标识。
## [br]
## @return: 排序后的条目 ID。
func get_ids(catalog_id: StringName) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in _get_catalog(catalog_id).keys():
		var _id_appended: bool = result.append(GFVariantData.to_text(key))
	result.sort()
	return result


## 获取目录条目描述。
## [br]
## @api public
## [br]
## @param catalog_id: 目录标识。
## [br]
## @param entry_id: 条目标识。
## [br]
## @return: 条目元数据副本。
## [br]
## @schema return: 条目元数据 Dictionary；键和值由目录提供器或项目工具约定。
func describe_entry(catalog_id: StringName, entry_id: StringName) -> Dictionary:
	return GFVariantData.to_dictionary(GFVariantData.get_option_value(_get_catalog(catalog_id), entry_id, {}))


## 获取完整目录快照。
## [br]
## @api public
## [br]
## @return: 目录快照字典。
## [br]
## @schema return: 目录快照 Dictionary，包含 events、parameters、states 和 switches 字段。
func describe_catalog() -> Dictionary:
	return {
		"events": events.duplicate(true),
		"parameters": parameters.duplicate(true),
		"states": states.duplicate(true),
		"switches": switches.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _get_catalog(catalog_id: StringName) -> Dictionary:
	match catalog_id:
		&"events":
			return events
		&"parameters":
			return parameters
		&"states":
			return states
		&"switches":
			return switches
		_:
			return {}


func _is_known_catalog_id(catalog_id: StringName) -> bool:
	return catalog_id == &"events" or catalog_id == &"parameters" or catalog_id == &"states" or catalog_id == &"switches"
