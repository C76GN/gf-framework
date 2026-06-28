## GFConfigProviderAdapter: 通用配置表 Provider 适配器。
##
## 用于把项目自己的生成表对象、字典表、数组表或懒加载 Callable 接入 GFConfigProvider。
## 适配器只负责统一查询协议、懒加载缓存和诊断报告，不绑定具体导表工具、文件格式或业务字段。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFConfigProviderAdapter
extends GFConfigProvider


# --- 常量 ---

## 表源已经注册。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_REGISTERED: StringName = &"registered"

## 表源已经加载。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_LOADED: StringName = &"loaded"

## 表源不存在。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_MISSING: StringName = &"missing"

## 表源加载失败。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_FAILED: StringName = &"failed"


# --- 私有变量 ---

var _sources: Dictionary = {}
var _loaded_tables: Dictionary = {}
var _load_reports: Dictionary = {}


# --- 公共方法 ---

## 注册一个配置表源。
## [br]
## source 可以是 Array、Dictionary、自定义 Object 或 Callable。Callable 会在首次查询时以
## `(table_name: StringName, metadata: Dictionary)` 调用，并返回实际表数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 表名。
## [br]
## @param source: 表源。
## [br]
## @schema source: Variant，支持 Array、Dictionary、Object 或 Callable；Object 可通过 table_method/record_method 适配。
## [br]
## @param options: 注册选项。
## [br]
## @schema options: Dictionary，可包含 schema: GFConfigTableSchema、id_field: StringName/String、table_method: StringName/String、record_method: StringName/String、cache: bool、duplicate_values: bool 和 metadata: Dictionary。
## [br]
## @return 注册成功返回 true。
func register_table_source(table_name: StringName, source: Variant, options: Dictionary = {}) -> bool:
	if table_name == &"":
		push_error("[GFConfigProviderAdapter] register_table_source 失败：table_name 为空。")
		return false
	if not _is_supported_source(source):
		push_error("[GFConfigProviderAdapter] register_table_source 失败：source 类型不受支持。")
		return false

	var schema: GFConfigTableSchema = _variant_to_schema(GFVariantData.get_option_value(options, "schema"))
	var normalized_schema: GFConfigTableSchema = null
	if schema != null:
		normalized_schema = _normalize_source_schema(table_name, schema)
		if normalized_schema == null:
			push_error("[GFConfigProviderAdapter] register_table_source 失败：schema.table_name 与 table_name 不一致。")
			return false

	unregister_schema(table_name)
	if normalized_schema != null:
		var _schema_registered: bool = register_schema(normalized_schema)
	_sources[table_name] = {
		"source": source,
		"id_field": GFVariantData.get_option_string_name(options, "id_field", &"id"),
		"table_method": GFVariantData.get_option_string_name(options, "table_method", &"get_table"),
		"record_method": GFVariantData.get_option_string_name(options, "record_method", &"get_record"),
		"cache": GFVariantData.get_option_bool(options, "cache", true),
		"duplicate_values": GFVariantData.get_option_bool(options, "duplicate_values", true),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	var _removed_table: bool = _loaded_tables.erase(table_name)
	_load_reports[table_name] = _make_report(table_name, STATUS_REGISTERED, true)
	return true


## 注销一个配置表源。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 表名。
## [br]
## @return 找到并注销时返回 true。
func unregister_table_source(table_name: StringName) -> bool:
	var removed: bool = _sources.erase(table_name)
	var _removed_loaded: bool = _loaded_tables.erase(table_name)
	var _removed_report: bool = _load_reports.erase(table_name)
	unregister_schema(table_name)
	return removed


## 清空所有表源、缓存和 schema。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear_table_sources() -> void:
	for table_name: StringName in get_table_ids():
		unregister_schema(table_name)
	_sources.clear()
	_loaded_tables.clear()
	_load_reports.clear()


## 检查是否注册了表源。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 表名。
## [br]
## @return 已注册返回 true。
func has_table_source(table_name: StringName) -> bool:
	return _sources.has(table_name)


## 获取已注册表名。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 排序后的表名列表。
func get_table_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for table_name: Variant in _sources.keys():
		var table_key: StringName = GFVariantData.to_string_name(table_name)
		if table_key != &"":
			var _appended: bool = result.append(String(table_key))
	result.sort()
	return result


## 预加载指定表源并返回加载报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 表名。
## [br]
## @return 加载报告。
## [br]
## @schema return: Dictionary，包含 ok、status、table_name、loaded、record_count、cached 和 error。
func preload_table(table_name: StringName) -> Dictionary:
	var table_data: Variant = _load_table(table_name)
	if table_data == null:
		return _get_load_report(table_name)
	return _get_load_report(table_name)


## 清理指定表的懒加载缓存。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 表名。
## [br]
## @return 找到并清理缓存时返回 true。
func clear_table_cache(table_name: StringName) -> bool:
	var removed: bool = _loaded_tables.erase(table_name)
	if _sources.has(table_name):
		_load_reports[table_name] = _make_report(table_name, STATUS_REGISTERED, true)
	return removed


## 清理全部懒加载缓存。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear_cache() -> void:
	for table_name: Variant in _loaded_tables.keys():
		var table_key: StringName = GFVariantData.to_string_name(table_name)
		if _sources.has(table_key):
			_load_reports[table_key] = _make_report(table_key, STATUS_REGISTERED, true)
	_loaded_tables.clear()


## 根据表名和 ID 获取单条记录。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 表名。
## [br]
## @param record_id: 记录 ID。
## [br]
## @schema record_id: Variant，项目配置表使用的记录键。
## [br]
## @return 记录数据；未命中时返回 null。
## [br]
## @schema return: Variant，通常为 Dictionary 或项目自定义记录对象。
func get_record(table_name: StringName, record_id: Variant) -> Variant:
	var table_data: Variant = _load_table(table_name)
	if table_data == null:
		return null

	var source_record: Dictionary = _get_source_record(table_name)
	var record: Variant = _read_record_from_table(table_data, record_id, source_record)
	return _copy_value_if_needed(record, source_record)


## 根据表名获取整张表数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 表名。
## [br]
## @return 表数据；未命中时返回 null。
## [br]
## @schema return: Variant，通常为 Array、Dictionary 或项目自定义表对象。
func get_table(table_name: StringName) -> Variant:
	var table_data: Variant = _load_table(table_name)
	if table_data == null:
		return null
	return _copy_value_if_needed(table_data, _get_source_record(table_name))


## 获取指定表的最近加载报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param table_name: 表名。
## [br]
## @return 加载报告。
## [br]
## @schema return: Dictionary，包含 ok、status、table_name、loaded、record_count、cached 和 error。
func get_load_report(table_name: StringName) -> Dictionary:
	return _get_load_report(table_name)


## 获取适配器调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 table_count、loaded_count、table_ids、loaded_table_ids 和 load_reports。
func get_debug_snapshot() -> Dictionary:
	var loaded_ids: PackedStringArray = PackedStringArray()
	for table_name: Variant in _loaded_tables.keys():
		var _loaded_appended: bool = loaded_ids.append(String(GFVariantData.to_string_name(table_name)))
	loaded_ids.sort()
	return {
		"table_count": _sources.size(),
		"loaded_count": _loaded_tables.size(),
		"table_ids": get_table_ids(),
		"loaded_table_ids": loaded_ids,
		"load_reports": _copy_reports(),
	}


# --- 私有/辅助方法 ---

func _load_table(table_name: StringName) -> Variant:
	if not _sources.has(table_name):
		_load_reports[table_name] = _make_report(table_name, STATUS_MISSING, false, "表源未注册。")
		return null

	var source_record: Dictionary = _get_source_record(table_name)
	var cache_enabled: bool = GFVariantData.get_option_bool(source_record, "cache", true)
	if cache_enabled and _loaded_tables.has(table_name):
		_load_reports[table_name] = _make_report(table_name, STATUS_LOADED, true, "", true, _estimate_record_count(_loaded_tables[table_name]))
		return _loaded_tables[table_name]

	var source: Variant = GFVariantData.get_option_value(source_record, "source")
	var loaded: Variant = _resolve_source_value(table_name, source_record, source)
	if loaded == null:
		_load_reports[table_name] = _make_report(table_name, STATUS_FAILED, false, "表源返回空值。")
		return null

	if cache_enabled:
		_loaded_tables[table_name] = loaded
	_load_reports[table_name] = _make_report(table_name, STATUS_LOADED, true, "", cache_enabled, _estimate_record_count(loaded))
	return loaded


func _resolve_source_value(table_name: StringName, source_record: Dictionary, source: Variant) -> Variant:
	if source is Callable:
		var loader: Callable = source
		return loader.call(table_name, GFVariantData.get_option_dictionary(source_record, "metadata"))

	if source is Object:
		var source_object: Object = source
		var table_method: StringName = GFVariantData.get_option_string_name(source_record, "table_method")
		if table_method != &"" and source_object.has_method(String(table_method)):
			return source_object.call(String(table_method))
		return source_object

	return source


func _read_record_from_table(table_data: Variant, record_id: Variant, source_record: Dictionary) -> Variant:
	if table_data is Dictionary:
		var table_dictionary: Dictionary = table_data
		return _read_record_from_dictionary(table_dictionary, record_id)

	if table_data is Array:
		var table_array: Array = table_data
		var id_field: StringName = GFVariantData.get_option_string_name(source_record, "id_field", &"id")
		return _read_record_from_array(table_array, record_id, id_field)

	if table_data is Object:
		var table_object: Object = table_data
		var record_method: StringName = GFVariantData.get_option_string_name(source_record, "record_method")
		if record_method != &"" and table_object.has_method(String(record_method)):
			return table_object.call(String(record_method), record_id)
	return null


func _read_record_from_dictionary(table_dictionary: Dictionary, record_id: Variant) -> Variant:
	if table_dictionary.has(record_id):
		return table_dictionary[record_id]
	for candidate_key: Variant in table_dictionary.keys():
		if _ids_match(candidate_key, record_id):
			return table_dictionary[candidate_key]
	return null


func _read_record_from_array(table_array: Array, record_id: Variant, id_field: StringName) -> Variant:
	for item: Variant in table_array:
		if not item is Dictionary:
			continue
		var record: Dictionary = item
		var candidate_id: Variant = GFVariantData.get_option_value(record, id_field)
		if _ids_match(candidate_id, record_id):
			return record
	return null


func _ids_match(left: Variant, right: Variant) -> bool:
	return GFVariantData.values_equal(left, right, { "match_string_names": true })


func _copy_value_if_needed(value: Variant, source_record: Dictionary) -> Variant:
	if value == null:
		return null
	if not GFVariantData.get_option_bool(source_record, "duplicate_values", true):
		return value
	return GFVariantData.duplicate_variant(value, true, false)


func _get_source_record(table_name: StringName) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_sources, table_name))


func _get_load_report(table_name: StringName) -> Dictionary:
	return GFVariantData.get_option_dictionary(_load_reports, table_name, _make_report(table_name, STATUS_MISSING, false, "尚未加载。"))


func _make_report(
	table_name: StringName,
	status: StringName,
	ok: bool,
	error: String = "",
	cached: bool = false,
	record_count: int = 0
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"table_name": table_name,
		"loaded": status == STATUS_LOADED,
		"record_count": record_count,
		"cached": cached,
		"error": error,
	}


func _estimate_record_count(table_data: Variant) -> int:
	if table_data is Dictionary:
		var table_dictionary: Dictionary = table_data
		return table_dictionary.size()
	if table_data is Array:
		var table_array: Array = table_data
		return table_array.size()
	if table_data is Object:
		var table_object: Object = table_data
		if table_object.has_method("get_record_count"):
			return GFVariantData.to_int(table_object.call("get_record_count"), 0)
	return 0


func _copy_reports() -> Dictionary:
	var result: Dictionary = {}
	for table_name: Variant in _load_reports.keys():
		result[table_name] = GFVariantData.get_option_dictionary(_load_reports, table_name)
	return result


func _is_supported_source(source: Variant) -> bool:
	return source is Callable or source is Array or source is Dictionary or source is Object


func _variant_to_schema(value: Variant) -> GFConfigTableSchema:
	if value is GFConfigTableSchema:
		var schema: GFConfigTableSchema = value
		return schema
	return null


func _normalize_source_schema(table_name: StringName, schema: GFConfigTableSchema) -> GFConfigTableSchema:
	if schema == null:
		return null
	var schema_key: StringName = schema.get_table_key()
	if schema_key != &"" and schema_key != table_name:
		return null
	var result: GFConfigTableSchema = schema.duplicate_schema()
	if result.table_name == &"":
		result.table_name = table_name
	return result
