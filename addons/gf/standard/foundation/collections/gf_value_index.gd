## GFValueIndex: 通用值索引。
##
## 为任意 item_id 关联值和字段，并支持按字段快速查询。它只维护索引结构，
## 不规定字段含义、业务规则或生命周期。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFValueIndex
extends RefCounted


# --- 信号 ---

## 条目写入索引后发出。
## [br]
## @api public
## [br]
## @param item_id: 条目标识。
signal item_indexed(item_id: StringName)

## 条目从索引移除后发出。
## [br]
## @api public
## [br]
## @param item_id: 条目标识。
signal item_removed(item_id: StringName)

## 索引清空后发出。
## [br]
## @api public
signal cleared


# --- 常量 ---

const _GF_VARIANT_KEY_CODEC_SCRIPT = preload("res://addons/gf/standard/foundation/variant/gf_variant_key_codec.gd")


# --- 公共变量 ---

## 读取或写入值时是否复制 Dictionary / Array。
## [br]
## @api public
var duplicate_values: bool = true


# --- 私有变量 ---

var _items: Dictionary = {}
var _indexes: Dictionary = {}


# --- 公共方法 ---

## 写入或替换一个条目。
## [br]
## @api public
## [br]
## @param item_id: 条目标识。
## [br]
## @param value: 条目值。
## [br]
## @param fields: 可索引字段，字段值可为单值、Array 或 PackedStringArray。
## [br]
## @return 写入成功返回 true。
## [br]
## @schema value: Variant item value.
## [br]
## @schema fields: Dictionary from field id to scalar, Array, or PackedStringArray values.
func set_item(item_id: StringName, value: Variant, fields: Dictionary = {}) -> bool:
	if item_id == &"":
		return false

	var normalized_report: Dictionary = _try_normalize_fields(fields)
	if not GFVariantData.get_option_bool(normalized_report, "ok", false):
		return false
	var normalized_fields: Dictionary = GFVariantData.get_option_dictionary(normalized_report, "fields")
	var _removed_existing: bool = remove_item(item_id)
	_items[item_id] = {
		"value": _copy_value(value),
		"fields": normalized_fields,
	}
	_index_fields(item_id, normalized_fields)
	item_indexed.emit(item_id)
	return true


## 移除条目。
## [br]
## @api public
## [br]
## @param item_id: 条目标识。
## [br]
## @return 移除成功返回 true。
func remove_item(item_id: StringName) -> bool:
	if not _items.has(item_id):
		return false

	var entry: Dictionary = _get_item_entry(item_id)
	var fields: Dictionary = _get_entry_fields(entry)
	_remove_fields_from_indexes(item_id, fields)
	var _item_erased: bool = _items.erase(item_id)
	item_removed.emit(item_id)
	return true


## 检查条目是否存在。
## [br]
## @api public
## [br]
## @param item_id: 条目标识。
## [br]
## @return 存在返回 true。
func has_item(item_id: StringName) -> bool:
	return _items.has(item_id)


## 获取条目值。
## [br]
## @api public
## [br]
## @param item_id: 条目标识。
## [br]
## @param default_value: 不存在时返回的默认值。
## [br]
## @return 条目值或默认值。
## [br]
## @schema default_value: Variant fallback value.
## [br]
## @schema return: Variant item value or fallback value.
func get_item(item_id: StringName, default_value: Variant = null) -> Variant:
	if not _items.has(item_id):
		return default_value
	var entry: Dictionary = _get_item_entry(item_id)
	return _copy_value(GFVariantData.get_option_value(entry, "value", default_value))


## 获取条目字段。
## [br]
## @api public
## [br]
## @param item_id: 条目标识。
## [br]
## @return 字段副本。
## [br]
## @schema return: Dictionary indexed field values.
func get_fields(item_id: StringName) -> Dictionary:
	if not _items.has(item_id):
		return {}
	var entry: Dictionary = _get_item_entry(item_id)
	return _get_entry_fields(entry).duplicate(true)


## 按单个字段值查询条目标识。
## [br]
## @api public
## [br]
## @param field_id: 字段标识。
## [br]
## @param field_value: 字段值。
## [br]
## @return 条目标识列表。
## [br]
## @schema field_value: Variant indexed field value.
func query(field_id: StringName, field_value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var field_index: Dictionary = _get_field_index(field_id)
	if field_index.is_empty():
		return result

	if not _is_stable_field_value(field_value):
		return result
	var value_key: String = _make_value_key(field_value)
	var item_lookup: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(field_index, value_key, {}))
	if item_lookup.is_empty():
		return result

	for item_id_variant: Variant in item_lookup.keys():
		var _item_id_appended: bool = result.append(GFVariantData.to_text(item_id_variant))
	result.sort()
	return result


## 按多个字段查询条目标识。
## [br]
## @api public
## [br]
## @param criteria: 字段到值的查询条件。
## [br]
## @param match_all: true 表示交集查询，false 表示并集查询。
## [br]
## @return 条目标识列表。
## [br]
## @schema criteria: Dictionary from field id to query value.
func query_many(criteria: Dictionary, match_all: bool = true) -> PackedStringArray:
	var result_lookup: Dictionary = {}
	var initialized: bool = false
	for field_id_variant: Variant in criteria.keys():
		var field_id: StringName = GFVariantData.to_string_name(field_id_variant)
		var matches: PackedStringArray = query(field_id, criteria[field_id_variant])
		if not initialized:
			for item_id_text: String in matches:
				result_lookup[StringName(item_id_text)] = true
			initialized = true
			continue

		if match_all:
			result_lookup = _intersect_lookup(result_lookup, matches)
		else:
			for item_id_text: String in matches:
				result_lookup[StringName(item_id_text)] = true

	return _lookup_to_sorted_ids(result_lookup)


## 清空索引。
## [br]
## @api public
func clear() -> void:
	_items.clear()
	_indexes.clear()
	cleared.emit()


## 获取条目数量。
## [br]
## @api public
## [br]
## @return 条目数量。
func get_item_count() -> int:
	return _items.size()


## 获取字段索引数量。
## [br]
## @api public
## [br]
## @return 字段索引数量。
func get_index_count() -> int:
	return _indexes.size()


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary with item_count, index_count, and duplicate_values.
func get_debug_snapshot() -> Dictionary:
	return {
		"item_count": _items.size(),
		"index_count": _indexes.size(),
		"duplicate_values": duplicate_values,
	}


# --- 私有/辅助方法 ---

func _copy_value(value: Variant) -> Variant:
	if duplicate_values:
		return GFVariantData.duplicate_variant(value)
	return value


func _try_normalize_fields(fields: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field_id_variant: Variant in fields.keys():
		var field_id: StringName = GFVariantData.to_string_name(field_id_variant)
		if field_id == &"":
			continue
		var value_report: Dictionary = _try_normalize_field_values(fields[field_id_variant])
		if not GFVariantData.get_option_bool(value_report, "ok", false):
			return {
				"ok": false,
				"fields": {},
			}
		var values: Array = GFVariantData.get_option_array(value_report, "values")
		if not values.is_empty():
			result[field_id] = values
	return {
		"ok": true,
		"fields": result,
	}


func _try_normalize_field_values(value: Variant) -> Dictionary:
	var result: Array = []
	if value == null:
		return {
			"ok": true,
			"values": result,
		}
	if value is PackedStringArray:
		for text: String in value:
			result.append(text)
	elif value is Array:
		for item: Variant in value:
			if item == null:
				continue
			if not _is_stable_field_value(item):
				return {
					"ok": false,
					"values": [],
				}
			result.append(item)
	else:
		if not _is_stable_field_value(value):
			return {
				"ok": false,
				"values": [],
			}
		result.append(value)
	return {
		"ok": true,
		"values": result,
	}


func _index_fields(item_id: StringName, fields: Dictionary) -> void:
	for field_id: StringName in fields.keys():
		var values: Array = _get_field_values(fields, field_id)
		if values.is_empty():
			continue
		for value: Variant in values:
			_add_index_value(field_id, value, item_id)


func _remove_fields_from_indexes(item_id: StringName, fields: Dictionary) -> void:
	for field_id: StringName in fields.keys():
		var values: Array = _get_field_values(fields, field_id)
		if values.is_empty():
			continue
		for value: Variant in values:
			_remove_index_value(field_id, value, item_id)


func _add_index_value(field_id: StringName, field_value: Variant, item_id: StringName) -> void:
	var field_index: Dictionary = _get_or_create_field_index(field_id)
	var value_key: String = _make_value_key(field_value)
	if not field_index.has(value_key):
		field_index[value_key] = {}
	var item_lookup: Dictionary = GFVariantData.as_dictionary(field_index[value_key])
	item_lookup[item_id] = true


func _remove_index_value(field_id: StringName, field_value: Variant, item_id: StringName) -> void:
	var field_index: Dictionary = _get_field_index(field_id)
	if field_index.is_empty():
		return

	var value_key: String = _make_value_key(field_value)
	var item_lookup: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(field_index, value_key, {}))
	if item_lookup.is_empty():
		return

	var _item_erased: bool = item_lookup.erase(item_id)
	if item_lookup.is_empty():
		var _value_erased: bool = field_index.erase(value_key)
	if field_index.is_empty():
		var _field_erased: bool = _indexes.erase(field_id)


func _make_value_key(value: Variant) -> String:
	return _GF_VARIANT_KEY_CODEC_SCRIPT.make_key_token(value)


func _is_stable_field_value(value: Variant) -> bool:
	return _GF_VARIANT_KEY_CODEC_SCRIPT.is_stable_key(value)


func _intersect_lookup(left_lookup: Dictionary, right_ids: PackedStringArray) -> Dictionary:
	var right_lookup: Dictionary = {}
	for item_id_text: String in right_ids:
		right_lookup[StringName(item_id_text)] = true

	var result: Dictionary = {}
	for item_id: StringName in left_lookup.keys():
		if right_lookup.has(item_id):
			result[item_id] = true
	return result


func _lookup_to_sorted_ids(lookup: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item_id_variant: Variant in lookup.keys():
		var _item_id_appended: bool = result.append(GFVariantData.to_text(item_id_variant))
	result.sort()
	return result


func _get_item_entry(item_id: StringName) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_items, item_id, {}))


func _get_entry_fields(entry: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(entry, "fields", {}))


func _get_field_index(field_id: StringName) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_indexes, field_id, {}))


func _get_or_create_field_index(field_id: StringName) -> Dictionary:
	if not _indexes.has(field_id):
		_indexes[field_id] = {}
	return _get_field_index(field_id)


func _get_field_values(fields: Dictionary, field_id: StringName) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(fields, field_id, []))
