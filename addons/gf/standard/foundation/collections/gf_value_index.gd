## GFValueIndex: 通用值索引。
##
## 为任意 item_id 关联值和字段，并支持按字段快速查询。它只维护索引结构，
## 不规定字段含义、业务规则或生命周期。
## 所有 mutation 都在同步信号前完整提交；信号监听器若重入修改同一索引，
## mutation 会失败关闭，调用方可在信号返回后或 deferred 阶段重试。
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

## 将字段值映射为稳定索引 token 的 Variant key codec 脚本。
## [br]
## @api private
const _GF_VARIANT_KEY_CODEC_SCRIPT = preload("res://addons/gf/standard/foundation/variant/gf_variant_key_codec.gd")


# --- 公共变量 ---

## 读取或写入值时是否复制 Dictionary / Array。
## [br]
## @api public
var duplicate_values: bool = true


# --- 私有变量 ---

## 按 item_id 保存值与规范化字段的条目表。
## [br]
## @api private
var _items: Dictionary = {}

## 按字段标识和值 token 保存 item_id 集合的反向索引。
## [br]
## @api private
var _indexes: Dictionary = {}

## 同步 mutation 信号派发期间阻止同一索引再次修改的标记。
## [br]
## @api private
var _is_emitting_mutation_signal: bool = false


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
	if item_id == &"" or _is_emitting_mutation_signal:
		return false

	var normalized_report: Dictionary = _try_normalize_fields(fields)
	if not GFVariantData.get_option_bool(normalized_report, "ok", false):
		return false
	var normalized_fields: Dictionary = GFVariantData.get_option_dictionary(normalized_report, "fields")
	var removed_existing: bool = _remove_item_state(item_id)
	if removed_existing:
		_emit_item_removed(item_id)
	_items[item_id] = {
		"value": _copy_value(value),
		"fields": normalized_fields,
	}
	_index_fields(item_id, normalized_fields)
	_emit_item_indexed(item_id)
	return true


## 移除条目。
## [br]
## @api public
## [br]
## @param item_id: 条目标识。
## [br]
## @return 移除成功返回 true。
func remove_item(item_id: StringName) -> bool:
	if _is_emitting_mutation_signal or not _remove_item_state(item_id):
		return false
	_emit_item_removed(item_id)
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
## [br]
## @since 3.17.0
## [br]
## 同步 mutation 信号派发期间调用时不执行；需要重入清理时应 deferred 调用。
func clear() -> void:
	if _is_emitting_mutation_signal:
		return
	_items.clear()
	_indexes.clear()
	_emit_cleared()


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

## 移除条目并从各字段索引中删除其值，不派发信号。
## [br]
## @api private
func _remove_item_state(item_id: StringName) -> bool:
	if not _items.has(item_id):
		return false
	var entry: Dictionary = _get_item_entry(item_id)
	var fields: Dictionary = _get_entry_fields(entry)
	_remove_fields_from_indexes(item_id, fields)
	var _item_erased: bool = _items.erase(item_id)
	return true


## 设置 mutation 信号派发标记并发出 item_indexed。
## [br]
## @api private
func _emit_item_indexed(item_id: StringName) -> void:
	_is_emitting_mutation_signal = true
	item_indexed.emit(item_id)
	_is_emitting_mutation_signal = false


## 设置 mutation 信号派发标记并发出 item_removed。
## [br]
## @api private
func _emit_item_removed(item_id: StringName) -> void:
	_is_emitting_mutation_signal = true
	item_removed.emit(item_id)
	_is_emitting_mutation_signal = false


## 设置 mutation 信号派发标记并发出 cleared。
## [br]
## @api private
func _emit_cleared() -> void:
	_is_emitting_mutation_signal = true
	cleared.emit()
	_is_emitting_mutation_signal = false


## 按 duplicate_values 配置处理存储或返回的值。
## [br]
## @api private
func _copy_value(value: Variant) -> Variant:
	if duplicate_values:
		return GFVariantData.duplicate_variant(value)
	return value


## 规范字段标识和值集合；遇到任一无效值时返回失败报告。
## [br]
## @api private
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


## 将单字段输入转为值数组；数组中 null 项会跳过。
## [br]
## @api private
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


## 将条目的每个字段值登记到反向索引。
## [br]
## @api private
func _index_fields(item_id: StringName, fields: Dictionary) -> void:
	for field_id: StringName in fields.keys():
		var values: Array = _get_field_values(fields, field_id)
		if values.is_empty():
			continue
		for value: Variant in values:
			_add_index_value(field_id, value, item_id)


## 从反向索引移除条目的每个字段值。
## [br]
## @api private
func _remove_fields_from_indexes(item_id: StringName, fields: Dictionary) -> void:
	for field_id: StringName in fields.keys():
		var values: Array = _get_field_values(fields, field_id)
		if values.is_empty():
			continue
		for value: Variant in values:
			_remove_index_value(field_id, value, item_id)


## 将 item_id 加入字段值 token 对应的索引集合。
## [br]
## @api private
func _add_index_value(field_id: StringName, field_value: Variant, item_id: StringName) -> void:
	var field_index: Dictionary = _get_or_create_field_index(field_id)
	var value_key: String = _make_value_key(field_value)
	if not field_index.has(value_key):
		field_index[value_key] = {}
	var item_lookup: Dictionary = GFVariantData.as_dictionary(field_index[value_key])
	item_lookup[item_id] = true


## 从字段值索引中移除 item_id，并清理空值项及空字段索引。
## [br]
## @api private
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


## 使用 Variant key codec 生成字段值的索引 token。
## [br]
## @api private
func _make_value_key(value: Variant) -> String:
	return _GF_VARIANT_KEY_CODEC_SCRIPT.make_key_token(value)


## 委托 Variant key codec 判断字段值是否可稳定索引。
## [br]
## @api private
func _is_stable_field_value(value: Variant) -> bool:
	return _GF_VARIANT_KEY_CODEC_SCRIPT.is_stable_key(value)


## 将右侧 ID 集合转为查找表，并返回左右两表交集。
## [br]
## @api private
func _intersect_lookup(left_lookup: Dictionary, right_ids: PackedStringArray) -> Dictionary:
	var right_lookup: Dictionary = {}
	for item_id_text: String in right_ids:
		right_lookup[StringName(item_id_text)] = true

	var result: Dictionary = {}
	for item_id: StringName in left_lookup.keys():
		if right_lookup.has(item_id):
			result[item_id] = true
	return result


## 将 lookup 中的 item_id 转成排序后的文本数组。
## [br]
## @api private
func _lookup_to_sorted_ids(lookup: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item_id_variant: Variant in lookup.keys():
		var _item_id_appended: bool = result.append(GFVariantData.to_text(item_id_variant))
	result.sort()
	return result


## 获取 item_id 对应条目；不存在时返回空字典。
## [br]
## @api private
func _get_item_entry(item_id: StringName) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_items, item_id, {}))


## 从条目读取规范字段字典；字段缺失时返回空字典。
## [br]
## @api private
func _get_entry_fields(entry: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(entry, "fields", {}))


## 获取 field_id 对应的反向索引；不存在时返回空字典。
## [br]
## @api private
func _get_field_index(field_id: StringName) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_indexes, field_id, {}))


## 确保字段索引存在并返回该索引字典。
## [br]
## @api private
func _get_or_create_field_index(field_id: StringName) -> Dictionary:
	if not _indexes.has(field_id):
		_indexes[field_id] = {}
	return _get_field_index(field_id)


## 从规范字段字典读取某字段的值数组。
## [br]
## @api private
func _get_field_values(fields: Dictionary, field_id: StringName) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(fields, field_id, []))
