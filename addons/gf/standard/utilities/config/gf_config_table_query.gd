## GFConfigTableQuery: 配置表记录的通用查询器。
##
## 面向 GFConfigTableResource、导表记录数组和编辑器工具提供纯数据筛选、排序与分页。
## 它不改变配置表存储模型，也不绑定任何业务表语义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
class_name GFConfigTableQuery
extends RefCounted


# --- 枚举 ---

## 过滤条件操作符。
## [br]
## @api public
## [br]
## @since 8.0.0
enum Operator {
	## 字段值等于目标值。
	EQ,
	## 字段值不等于目标值。
	NE,
	## 字段值大于目标值。
	GT,
	## 字段值大于等于目标值。
	GTE,
	## 字段值小于目标值。
	LT,
	## 字段值小于等于目标值。
	LTE,
	## 字段值包含在目标集合中。
	IN,
	## 字段值包含目标值。
	CONTAINS,
	## 字段路径是否存在。
	EXISTS,
	## 使用 Callable 判断整条记录。
	PREDICATE,
	## 任一子条件匹配。
	ANY,
	## 所有子条件都不匹配。
	NONE,
}


# --- 私有变量 ---

var _records: Array[Dictionary] = []
var _filters: Array[Dictionary] = []
var _sort_path: String = ""
var _sort_ascending: bool = true
var _limit: int = -1
var _offset: int = 0


# --- 公共方法 ---

## 从配置表资源创建查询器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param table: 配置表资源。
## [br]
## @param duplicate_records: 是否复制表记录，避免查询器持有资源内可变记录引用。
## [br]
## @return 新查询器。
static func from_table(table: GFConfigTableResource, duplicate_records: bool = true) -> GFConfigTableQuery:
	var query: GFConfigTableQuery = GFConfigTableQuery.new()
	if table != null:
		var _set_records_result: GFConfigTableQuery = query.set_records(table.get_records(duplicate_records), false)
	return query


## 从记录数组创建查询器。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param records: 配置记录数组。
## [br]
## @param duplicate_records: 是否复制 Dictionary 记录。
## [br]
## @return 新查询器。
## [br]
## @schema records: Array[Dictionary]，每个 Dictionary 是一条配置记录。
static func from_records(records: Array[Dictionary], duplicate_records: bool = true) -> GFConfigTableQuery:
	var query: GFConfigTableQuery = GFConfigTableQuery.new()
	var _set_records_result: GFConfigTableQuery = query.set_records(records, duplicate_records)
	return query


## 设置查询源记录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param records: 配置记录数组。
## [br]
## @param duplicate_records: 是否复制 Dictionary 记录。
## [br]
## @return 当前查询器。
## [br]
## @schema records: Array[Dictionary]，每个 Dictionary 是一条配置记录。
func set_records(records: Array[Dictionary], duplicate_records: bool = true) -> GFConfigTableQuery:
	_records.clear()
	for record: Dictionary in records:
		_records.append(record.duplicate(true) if duplicate_records else record)
	return self


## 清空所有过滤条件、排序和分页。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前查询器。
func clear_query() -> GFConfigTableQuery:
	_filters.clear()
	_sort_path = ""
	_sort_ascending = true
	_limit = -1
	_offset = 0
	return self


## 添加等值过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。
## [br]
## @param value: 目标值。
## [br]
## @return 当前查询器。
## [br]
## @schema value: Variant，筛选目标值。
func where_eq(path: String, value: Variant) -> GFConfigTableQuery:
	return _add_value_filter(Operator.EQ, path, value)


## 添加不等值过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。
## [br]
## @param value: 目标值。
## [br]
## @return 当前查询器。
## [br]
## @schema value: Variant，筛选目标值。
func where_ne(path: String, value: Variant) -> GFConfigTableQuery:
	return _add_value_filter(Operator.NE, path, value)


## 添加大于过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。
## [br]
## @param value: 目标值。
## [br]
## @return 当前查询器。
## [br]
## @schema value: Variant，筛选目标值。
func where_gt(path: String, value: Variant) -> GFConfigTableQuery:
	return _add_value_filter(Operator.GT, path, value)


## 添加大于等于过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。
## [br]
## @param value: 目标值。
## [br]
## @return 当前查询器。
## [br]
## @schema value: Variant，筛选目标值。
func where_gte(path: String, value: Variant) -> GFConfigTableQuery:
	return _add_value_filter(Operator.GTE, path, value)


## 添加小于过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。
## [br]
## @param value: 目标值。
## [br]
## @return 当前查询器。
## [br]
## @schema value: Variant，筛选目标值。
func where_lt(path: String, value: Variant) -> GFConfigTableQuery:
	return _add_value_filter(Operator.LT, path, value)


## 添加小于等于过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。
## [br]
## @param value: 目标值。
## [br]
## @return 当前查询器。
## [br]
## @schema value: Variant，筛选目标值。
func where_lte(path: String, value: Variant) -> GFConfigTableQuery:
	return _add_value_filter(Operator.LTE, path, value)


## 添加集合包含过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。
## [br]
## @param candidate_values: 目标值集合。
## [br]
## @return 当前查询器。
## [br]
## @schema candidate_values: Array，筛选候选值。
func where_in(path: String, candidate_values: Array) -> GFConfigTableQuery:
	return _add_value_filter(Operator.IN, path, candidate_values.duplicate(true))


## 添加字段包含过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。
## [br]
## @param value: 目标值。
## [br]
## @return 当前查询器。
## [br]
## @schema value: Variant，筛选目标值。
func where_contains(path: String, value: Variant) -> GFConfigTableQuery:
	return _add_value_filter(Operator.CONTAINS, path, value)


## 添加字段存在性过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。
## [br]
## @param exists: 为 true 时要求路径存在，为 false 时要求路径不存在。
## [br]
## @return 当前查询器。
func where_exists(path: String, exists: bool = true) -> GFConfigTableQuery:
	return _add_value_filter(Operator.EXISTS, path, exists)


## 添加自定义记录过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param predicate: 判断回调，签名为 Callable(record: Dictionary) -> bool。
## [br]
## @param description: 可选描述 ID，进入 describe_query() 便于调试。
## [br]
## @return 当前查询器。
func where_predicate(predicate: Callable, description: StringName = &"") -> GFConfigTableQuery:
	if not predicate.is_valid():
		return self
	_filters.append({
		"operator": Operator.PREDICATE,
		"path": "",
		"value": predicate,
		"description": description,
	})
	return self


## 创建可传给 where_filter()、where_any() 或 where_none() 的条件字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param operator: 过滤操作符。
## [br]
## @param path: 字段路径；PREDICATE、ANY 和 NONE 可为空。
## [br]
## @param value: 目标值、Callable，或条件组数组。
## [br]
## @schema value: Variant 目标值、Callable 谓词、Array[Dictionary] 条件组或 null。
## [br]
## @param description: 可选描述 ID，进入 describe_query() 便于调试。
## [br]
## @return 条件字典。
## [br]
## @schema return: Dictionary，可直接传给 where_filter()、where_any() 或 where_none()。
static func condition(
	operator: Operator,
	path: String = "",
	value: Variant = null,
	description: StringName = &""
) -> Dictionary:
	return {
		"operator": operator,
		"path": path,
		"value": GFVariantData.duplicate_variant(value, true, false),
		"description": description,
	}


## 添加一个声明式条件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param condition_data: 条件字典，通常由 condition() 创建。
## [br]
## @return 当前查询器。
## [br]
## @schema condition_data: Dictionary，包含 operator、path、value、description 或嵌套 filters/conditions。
func where_filter(condition_data: Dictionary) -> GFConfigTableQuery:
	var normalized: Dictionary = _normalize_filter_condition(condition_data)
	if normalized.is_empty():
		return self
	_filters.append(normalized)
	return self


## 添加任一条件匹配过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param conditions: 条件字典数组，任一条件匹配即通过。
## [br]
## @param description: 可选描述 ID，进入 describe_query() 便于调试。
## [br]
## @return 当前查询器。
## [br]
## @schema conditions: Array[Dictionary]，每个元素通常由 condition() 创建。
func where_any(conditions: Array[Dictionary], description: StringName = &"") -> GFConfigTableQuery:
	return _add_condition_group(Operator.ANY, conditions, description)


## 添加所有条件都不匹配过滤。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param conditions: 条件字典数组，只要其中任一条件匹配即拒绝记录。
## [br]
## @param description: 可选描述 ID，进入 describe_query() 便于调试。
## [br]
## @return 当前查询器。
## [br]
## @schema conditions: Array[Dictionary]，每个元素通常由 condition() 创建。
func where_none(conditions: Array[Dictionary], description: StringName = &"") -> GFConfigTableQuery:
	return _add_condition_group(Operator.NONE, conditions, description)


## 设置排序字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。
## [br]
## @param ascending: 是否升序。
## [br]
## @return 当前查询器。
func order_by(path: String, ascending: bool = true) -> GFConfigTableQuery:
	_sort_path = path.strip_edges()
	_sort_ascending = ascending
	return self


## 设置分页。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param offset: 跳过记录数量。
## [br]
## @param limit: 最多返回记录数量；小于 0 表示不限制。
## [br]
## @return 当前查询器。
func page(offset: int = 0, limit: int = -1) -> GFConfigTableQuery:
	_offset = maxi(offset, 0)
	_limit = limit
	return self


## 返回匹配记录数组。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param duplicate_records: 是否复制返回记录。
## [br]
## @return 匹配记录数组。
## [br]
## @schema return: Array[Dictionary]，每个 Dictionary 是一条匹配记录。
func to_array(duplicate_records: bool = true) -> Array[Dictionary]:
	var matched: Array[Dictionary] = _collect_matched_records()
	if not _sort_path.is_empty():
		matched.sort_custom(_compare_records)
	return _slice_records(matched, duplicate_records)


## 返回第一条匹配记录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param duplicate_record: 是否复制返回记录。
## [br]
## @return 匹配记录；没有匹配时返回 null。
## [br]
## @schema return: Variant，找到时为 Dictionary，未命中时为 null。
func first(duplicate_record: bool = true) -> Variant:
	var records: Array[Dictionary] = to_array(duplicate_record)
	if records.is_empty():
		return null
	return records[0]


## 返回匹配记录数量，不应用分页。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 匹配记录数量。
func count() -> int:
	return _collect_matched_records().size()


## 返回匹配记录中的字段值。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 字段路径。为空时使用整条记录。
## [br]
## @return 字段值数组。
## [br]
## @schema return: Array，字段值列表。
func values(path: String = "") -> Array:
	var result: Array = []
	for record: Dictionary in to_array(false):
		if path.strip_edges().is_empty():
			result.append(record)
			continue

		var read_result: Dictionary = _read_path(record, path)
		if GFVariantData.get_option_bool(read_result, "found"):
			result.append(GFVariantData.get_option_value(read_result, "value"))
	return result


## 读取任意源对象的路径值。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param source: 源数据。
## [br]
## @param path: 字段路径，支持用 "." 访问嵌套 Dictionary、Array 下标或 Object 属性。
## [br]
## @param default_value: 路径不存在时返回的默认值。
## [br]
## @return 读取到的值或默认值。
## [br]
## @schema source: Variant，Dictionary、Array、Object 或标量数据。
## [br]
## @schema default_value: Variant，路径不存在时返回的默认值。
## [br]
## @schema return: Variant，读取到的值或默认值。
static func read_path(source: Variant, path: String, default_value: Variant = null) -> Variant:
	var read_result: Dictionary = _read_path(source, path)
	if GFVariantData.get_option_bool(read_result, "found"):
		return GFVariantData.get_option_value(read_result, "value")
	return default_value


## 描述当前查询。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 查询描述。
## [br]
## @schema return: Dictionary，包含 source_count、filter_count、filters、sort_path、sort_ascending、offset 和 limit。
func describe_query() -> Dictionary:
	var filter_descriptions: Array[Dictionary] = []
	for filter: Dictionary in _filters:
		filter_descriptions.append(_describe_filter(filter))
	return {
		"source_count": _records.size(),
		"filter_count": _filters.size(),
		"filters": filter_descriptions,
		"sort_path": _sort_path,
		"sort_ascending": _sort_ascending,
		"offset": _offset,
		"limit": _limit,
	}


# --- 私有/辅助方法 ---

func _add_value_filter(operator: Operator, path: String, value: Variant) -> GFConfigTableQuery:
	var normalized_path: String = path.strip_edges()
	if normalized_path.is_empty():
		return self
	_filters.append({
		"operator": operator,
		"path": normalized_path,
		"value": GFVariantData.duplicate_variant(value, true, false),
		"description": &"",
	})
	return self


func _add_condition_group(
	operator: Operator,
	conditions: Array[Dictionary],
	description: StringName = &""
) -> GFConfigTableQuery:
	var normalized_filters: Array[Dictionary] = _normalize_condition_array(conditions)
	if normalized_filters.is_empty():
		return self
	_filters.append({
		"operator": operator,
		"path": "",
		"value": null,
		"filters": normalized_filters,
		"description": description,
	})
	return self


func _collect_matched_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in _records:
		if _record_matches(record):
			result.append(record)
	return result


func _record_matches(record: Dictionary) -> bool:
	for filter: Dictionary in _filters:
		if not _filter_matches(record, filter):
			return false
	return true


func _filter_matches(record: Dictionary, filter: Dictionary) -> bool:
	var operator: int = GFVariantData.get_option_int(filter, "operator", Operator.EQ)
	if operator == Operator.PREDICATE:
		var predicate: Callable = _variant_to_callable(GFVariantData.get_option_value(filter, "value"))
		return predicate.is_valid() and GFVariantData.to_bool(predicate.call(record.duplicate(true)), false)
	if operator == Operator.ANY:
		return _any_child_filter_matches(record, GFVariantData.get_option_array(filter, "filters"))
	if operator == Operator.NONE:
		return not _any_child_filter_matches(record, GFVariantData.get_option_array(filter, "filters"))

	var path: String = GFVariantData.get_option_string(filter, "path", "")
	var value: Variant = GFVariantData.get_option_value(filter, "value")
	var read_result: Dictionary = _read_path(record, path)
	var found: bool = GFVariantData.get_option_bool(read_result, "found")
	if operator == Operator.EXISTS:
		return found == GFVariantData.to_bool(value, true)
	if not found:
		return false

	var source_value: Variant = GFVariantData.get_option_value(read_result, "value")
	match operator:
		Operator.EQ:
			return source_value == value
		Operator.NE:
			return source_value != value
		Operator.GT:
			return _compare_values(source_value, value) > 0
		Operator.GTE:
			return _compare_values(source_value, value) >= 0
		Operator.LT:
			return _compare_values(source_value, value) < 0
		Operator.LTE:
			return _compare_values(source_value, value) <= 0
		Operator.IN:
			return value is Array and GFVariantData.as_array(value).has(source_value)
		Operator.CONTAINS:
			return _matches_contains(source_value, value)
		_:
			return false


func _any_child_filter_matches(record: Dictionary, child_filters: Array) -> bool:
	for child_filter_value: Variant in child_filters:
		var child_filter: Dictionary = GFVariantData.as_dictionary(child_filter_value)
		if not child_filter.is_empty() and _filter_matches(record, child_filter):
			return true
	return false


func _compare_records(left_record: Dictionary, right_record: Dictionary) -> bool:
	var left_read: Dictionary = _read_path(left_record, _sort_path)
	var right_read: Dictionary = _read_path(right_record, _sort_path)
	var left_found: bool = GFVariantData.get_option_bool(left_read, "found")
	var right_found: bool = GFVariantData.get_option_bool(right_read, "found")
	if left_found != right_found:
		return left_found if _sort_ascending else right_found

	var comparison: int = _compare_values(
		GFVariantData.get_option_value(left_read, "value"),
		GFVariantData.get_option_value(right_read, "value")
	)
	if comparison == 0:
		return false
	return comparison < 0 if _sort_ascending else comparison > 0


func _slice_records(records: Array[Dictionary], duplicate_records: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start_index: int = mini(_offset, records.size())
	var end_index: int = records.size()
	if _limit >= 0:
		end_index = mini(start_index + _limit, records.size())
	for index: int in range(start_index, end_index):
		var record: Dictionary = records[index]
		result.append(record.duplicate(true) if duplicate_records else record)
	return result


func _normalize_filter_condition(condition_data: Dictionary) -> Dictionary:
	if condition_data.is_empty():
		return {}

	var operator: int = GFVariantData.get_option_int(condition_data, "operator", Operator.EQ)
	var description: StringName = GFVariantData.get_option_string_name(condition_data, "description", &"")
	if operator == Operator.PREDICATE:
		var predicate: Callable = _variant_to_callable(GFVariantData.get_option_value(condition_data, "value"))
		if not predicate.is_valid():
			return {}
		return {
			"operator": Operator.PREDICATE,
			"path": "",
			"value": predicate,
			"description": description,
		}

	if operator == Operator.ANY or operator == Operator.NONE:
		var raw_filters: Array = GFVariantData.get_option_array(condition_data, "filters")
		if raw_filters.is_empty():
			raw_filters = GFVariantData.get_option_array(condition_data, "conditions")
		if raw_filters.is_empty():
			raw_filters = GFVariantData.get_option_array(condition_data, "value")
		var normalized_filters: Array[Dictionary] = _normalize_condition_array(raw_filters)
		if normalized_filters.is_empty():
			return {}
		return {
			"operator": operator,
			"path": "",
			"value": null,
			"filters": normalized_filters,
			"description": description,
		}

	var path: String = GFVariantData.get_option_string(condition_data, "path").strip_edges()
	if path.is_empty():
		return {}
	return {
		"operator": operator,
		"path": path,
		"value": GFVariantData.duplicate_variant(GFVariantData.get_option_value(condition_data, "value"), true, false),
		"description": description,
	}


func _normalize_condition_array(conditions: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for condition_value: Variant in conditions:
		var condition_data: Dictionary = GFVariantData.as_dictionary(condition_value)
		var normalized: Dictionary = _normalize_filter_condition(condition_data)
		if not normalized.is_empty():
			result.append(normalized)
	return result


func _describe_filter(filter: Dictionary) -> Dictionary:
	var operator: int = GFVariantData.get_option_int(filter, "operator", Operator.EQ)
	var description: Dictionary = {
		"operator": operator,
		"operator_name": Operator.keys()[operator] if operator >= 0 and operator < Operator.size() else "UNKNOWN",
		"path": GFVariantData.get_option_string(filter, "path", ""),
		"description": GFVariantData.get_option_string_name(filter, "description", &""),
	}
	if operator == Operator.ANY or operator == Operator.NONE:
		var child_descriptions: Array[Dictionary] = []
		for child_filter_value: Variant in GFVariantData.get_option_array(filter, "filters"):
			var child_filter: Dictionary = GFVariantData.as_dictionary(child_filter_value)
			if not child_filter.is_empty():
				child_descriptions.append(_describe_filter(child_filter))
		description["filters"] = child_descriptions
	return description


static func _read_path(source: Variant, path: String) -> Dictionary:
	var normalized_path: String = path.strip_edges()
	if normalized_path.is_empty():
		return {
			"found": true,
			"value": source,
		}

	var current: Variant = source
	for segment: String in normalized_path.split(".", false):
		var segment_result: Dictionary = _read_segment(current, segment)
		if not GFVariantData.get_option_bool(segment_result, "found"):
			return {
				"found": false,
				"value": null,
			}
		current = GFVariantData.get_option_value(segment_result, "value")
	return {
		"found": true,
		"value": current,
	}


static func _read_segment(source: Variant, segment: String) -> Dictionary:
	if source is Dictionary:
		var dictionary: Dictionary = source
		if _dictionary_has_key(dictionary, segment):
			return {
				"found": true,
				"value": _get_dictionary_value(dictionary, segment),
			}
		return {
			"found": false,
			"value": null,
		}

	if source is Array:
		var source_array: Array = source
		var array_index: int = _parse_non_negative_index(segment)
		if array_index >= 0 and array_index < source_array.size():
			return {
				"found": true,
				"value": source_array[array_index],
			}
		return {
			"found": false,
			"value": null,
		}

	if source is Object:
		var object_ref: Object = source
		for property_info: Dictionary in object_ref.get_property_list():
			var raw_property_name: Variant = GFVariantData.get_option_value(property_info, "name")
			var property_name: String = GFVariantData.to_text(raw_property_name)
			if property_name == segment:
				return {
					"found": true,
					"value": object_ref.get(segment),
				}
	return {
		"found": false,
		"value": null,
	}


static func _dictionary_has_key(dictionary: Dictionary, key: String) -> bool:
	return dictionary.has(key) or dictionary.has(StringName(key))


static func _get_dictionary_value(dictionary: Dictionary, key: String) -> Variant:
	if dictionary.has(key):
		return dictionary[key]
	return dictionary[StringName(key)]


static func _parse_non_negative_index(text: String) -> int:
	if text.is_empty() or not text.is_valid_int():
		return -1
	var index: int = text.to_int()
	return index if index >= 0 else -1


static func _compare_values(left: Variant, right: Variant) -> int:
	if GFVariantData.values_equal(left, right, { "match_string_names": true }):
		return 0

	if _is_number(left) and _is_number(right):
		var left_float: float = GFVariantData.to_float(left, 0.0)
		var right_float: float = GFVariantData.to_float(right, 0.0)
		var left_is_nan: bool = is_nan(left_float)
		var right_is_nan: bool = is_nan(right_float)
		if left_is_nan or right_is_nan:
			if left_is_nan and right_is_nan:
				return 0
			return 1 if left_is_nan else -1
		if is_equal_approx(left_float, right_float):
			return 0
		return -1 if left_float < right_float else 1

	if _is_text_value(left) and _is_text_value(right):
		var left_text: String = GFVariantData.to_text(left)
		var right_text: String = GFVariantData.to_text(right)
		if left_text == right_text:
			return 0
		return -1 if left_text < right_text else 1

	var left_type: int = typeof(left)
	var right_type: int = typeof(right)
	if left_type != right_type:
		return -1 if left_type < right_type else 1

	var left_fallback_text: String = str(left)
	var right_fallback_text: String = str(right)
	if left_fallback_text == right_fallback_text:
		return 0
	return -1 if left_fallback_text < right_fallback_text else 1


static func _matches_contains(source_value: Variant, value: Variant) -> bool:
	if source_value is Array:
		var source_array: Array = source_value
		return source_array.has(value)
	if source_value is Dictionary:
		var source_dictionary: Dictionary = source_value
		return source_dictionary.has(value)
	if source_value is PackedStringArray and _is_text_value(value):
		var source_strings: PackedStringArray = source_value
		return source_strings.has(GFVariantData.to_text(value))
	if source_value is String and _is_text_value(value):
		var source_text: String = source_value
		return source_text.contains(GFVariantData.to_text(value))
	if source_value is StringName and _is_text_value(value):
		var source_name: StringName = source_value
		return String(source_name).contains(GFVariantData.to_text(value))
	return false


static func _is_number(value: Variant) -> bool:
	return value is int or value is float


static func _is_text_value(value: Variant) -> bool:
	return value is String or value is StringName


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callable_value: Callable = value
		return callable_value
	return Callable()
