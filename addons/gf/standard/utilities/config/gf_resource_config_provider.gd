## GFResourceConfigProvider: 读取 GFConfigTableResource 的运行时配置 Provider。
##
## 用于把导表工具生成的 `.tres` / `.res` 表资源接入 `GFConfigProvider` 查询协议。
## 它只处理通用表资源注册、表查询和记录查询，不绑定业务字段、构建 profile 或热更新策略。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.2.0
class_name GFResourceConfigProvider
extends GFConfigProvider


# --- 私有变量 ---

var _tables: Array[GFConfigTableResource] = []
var _tables_by_name: Dictionary = {}


# --- 公共方法 ---

## 注册一张配置表资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_resource: 要注册的配置表资源。
## [br]
## @return: 注册成功返回 true。
func register_table(table_resource: GFConfigTableResource) -> bool:
	if table_resource == null or table_resource.get_table_key() == &"":
		push_error("[GFResourceConfigProvider] register_table 失败：table_resource 为空或 table_name 为空。")
		return false

	var table_key: StringName = table_resource.get_table_key()
	if table_resource.schema != null and table_resource.schema.get_table_key() != table_key:
		push_error("[GFResourceConfigProvider] register_table 失败：table_name 与 schema.table_name 不一致。")
		return false

	_remove_table_entry(table_key)
	unregister_schema(table_key)
	_tables.append(table_resource)
	_tables_by_name[table_key] = table_resource
	if table_resource.schema != null:
		var _schema_registered: bool = register_schema(table_resource.schema)
	return true


## 批量注册配置表资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_resources: 要注册的配置表资源列表。
## [br]
## @schema table_resources: Array[GFConfigTableResource]，每个元素是一张配置表资源。
## [br]
## @return: 成功注册的数量。
func register_tables(table_resources: Array[GFConfigTableResource]) -> int:
	var count: int = 0
	for table_resource: GFConfigTableResource in table_resources:
		if register_table(table_resource):
			count += 1
	return count


## 批量替换配置表资源并重建内部查询索引。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_resources: 要设置的配置表资源列表。
## [br]
## @param duplicate_tables: 为 true 时保存表资源副本。
## [br]
## @schema table_resources: Array[GFConfigTableResource]，每个元素是一张配置表资源。
## [br]
## @return: 成功注册的表数量。
func set_table_resources(table_resources: Array[GFConfigTableResource], duplicate_tables: bool = false) -> int:
	clear_tables()
	var count: int = 0
	for table_resource: GFConfigTableResource in table_resources:
		var registered_table: GFConfigTableResource = (
			table_resource.duplicate_table()
			if duplicate_tables and table_resource != null
			else table_resource
		)
		if register_table(registered_table):
			count += 1
	return count


## 获取已注册配置表资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param duplicate_tables: 为 true 时返回资源深拷贝，避免调用方修改 Provider 内部数据。
## [br]
## @return: 配置表资源列表。
## [br]
## @schema return: Array[GFConfigTableResource]，每个元素是一张配置表资源。
func get_table_resources(duplicate_tables: bool = true) -> Array[GFConfigTableResource]:
	var result: Array[GFConfigTableResource] = []
	for table_resource: GFConfigTableResource in _tables:
		result.append(table_resource.duplicate_table() if duplicate_tables else table_resource)
	return result


## 从配置数据库资源创建 Provider。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param database: 配置数据库资源。
## [br]
## @param duplicate_tables: 为 true 时把表资源副本注册到 Provider。
## [br]
## @return: 新 Resource Provider；database 为空时返回 null。
static func from_database(database: GFConfigDatabaseResource, duplicate_tables: bool = false) -> GFResourceConfigProvider:
	if database == null:
		push_error("[GFResourceConfigProvider] from_database 失败：database 为空。")
		return null

	var provider: GFResourceConfigProvider = GFResourceConfigProvider.new()
	var _registered_count: int = provider.set_table_resources(database.get_table_resources(duplicate_tables), false)
	return provider


## 重新建立内部查询索引和 schema registry。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 成功注册的表数量。
func rebuild_table_registry() -> int:
	var source_tables: Array[GFConfigTableResource] = _tables.duplicate()
	clear_tables()
	for table_resource: GFConfigTableResource in source_tables:
		if table_resource == null or table_resource.get_table_key() == &"":
			continue
		var _registered: bool = register_table(table_resource)
	return _tables_by_name.size()


## 注销配置表资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @return: 找到并移除时返回 true。
func unregister_table(table_name: StringName) -> bool:
	var table_resource: GFConfigTableResource = _get_table_reference(table_name)
	if table_resource == null:
		return false

	_remove_table_entry(table_name)
	unregister_schema(table_name)
	return true


## 清空所有配置表资源和由表资源注册的 schema。
## [br]
## @api public
## [br]
## @since 5.2.0
func clear_tables() -> void:
	for table_name: StringName in _collect_table_names():
		unregister_schema(table_name)
	_tables.clear()
	_tables_by_name.clear()


## 检查配置表是否已注册。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @return: 已注册返回 true。
func has_table(table_name: StringName) -> bool:
	return _get_table_reference(table_name) != null


## 获取已注册配置表名。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 排序后的表名列表。
func get_table_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for table_name: StringName in _collect_table_names():
		var _id_appended: bool = result.append(String(table_name))
	result.sort()
	return result


## 获取配置表资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param duplicate_table: 为 true 时返回资源深拷贝，避免调用方修改 Provider 内部数据。
## [br]
## @return: 配置表资源；未命中时返回 null。
func get_table_resource(table_name: StringName, duplicate_table: bool = true) -> GFConfigTableResource:
	var table_resource: GFConfigTableResource = _get_table_reference(table_name)
	if table_resource == null:
		return null
	return table_resource.duplicate_table() if duplicate_table else table_resource


## 根据表名和 ID 获取单条记录。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param record_id: 记录的唯一标识符。
## [br]
## @schema record_id: Variant，项目配置表使用的记录键，通常为 String、StringName 或 int。
## [br]
## @return: 返回对应记录副本，未命中时返回 null。
## [br]
## @schema return: Variant，找到时为 Dictionary，未命中时为 null。
func get_record(table_name: StringName, record_id: Variant) -> Variant:
	var table_resource: GFConfigTableResource = _get_table_reference(table_name)
	if table_resource == null:
		return null
	return table_resource.get_record(record_id, true)


## 根据表名和索引声明构建索引键。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param record: 用于构建索引键的记录或字段值字典。
## [br]
## @schema record: Dictionary，键为索引字段名，值为字段数据。
## [br]
## @return: 索引键；表、索引或字段无效时返回空字符串。
func make_index_key(table_name: StringName, index_id: StringName, record: Dictionary) -> String:
	var table_resource: GFConfigTableResource = _get_table_reference(table_name)
	if table_resource == null:
		return ""
	return table_resource.make_index_key(index_id, record)


## 检查表资源中的命名索引键是否存在。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 由 make_index_key() 或同等规则生成的索引键。
## [br]
## @return: 存在返回 true。
func has_index_key(table_name: StringName, index_id: StringName, index_key: String) -> bool:
	var table_resource: GFConfigTableResource = _get_table_reference(table_name)
	if table_resource == null:
		return false
	return table_resource.has_index_key(index_id, index_key)


## 根据表名和命名索引获取记录列表。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 由 make_index_key() 或同等规则生成的索引键。
## [br]
## @return: 命中的记录列表；未命中时返回空数组。
## [br]
## @schema return: Array[Dictionary]，每个 Dictionary 是一条配置记录。
func get_index_records(table_name: StringName, index_id: StringName, index_key: String) -> Array[Dictionary]:
	var table_resource: GFConfigTableResource = _get_table_reference(table_name)
	if table_resource == null:
		return []
	return table_resource.get_index_records(index_id, index_key, true)


## 根据表名和命名索引获取第一条记录。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 由 make_index_key() 或同等规则生成的索引键。
## [br]
## @return: 找到时返回第一条记录 Dictionary，否则返回 null。
## [br]
## @schema return: Variant，找到时为 Dictionary，未命中时为 null。
func get_index_record(table_name: StringName, index_id: StringName, index_key: String) -> Variant:
	var table_resource: GFConfigTableResource = _get_table_reference(table_name)
	if table_resource == null:
		return null
	return table_resource.get_index_record(index_id, index_key, true)


## 根据表名获取整张表的数据。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @return: 返回 Array[Dictionary] 表数据副本，未命中时返回 null。
## [br]
## @schema return: Variant，找到时为 Array[Dictionary]，未命中时为 null。
func get_table(table_name: StringName) -> Variant:
	var table_resource: GFConfigTableResource = _get_table_reference(table_name)
	if table_resource == null:
		return null
	return table_resource.get_records(true)


# --- 私有/辅助方法 ---

func _get_table_reference(table_name: StringName) -> GFConfigTableResource:
	var cached: Variant = GFVariantData.get_option_value(_tables_by_name, table_name, null)
	if cached is GFConfigTableResource:
		var cached_table: GFConfigTableResource = cached
		if cached_table.get_table_key() == table_name:
			return cached_table
		var _rebuilt_count: int = rebuild_table_registry()
		return _get_cached_table_reference(table_name)

	for table_resource: GFConfigTableResource in _tables:
		if table_resource != null and table_resource.get_table_key() == table_name:
			var _rebuilt_count_after_miss: int = rebuild_table_registry()
			return _get_cached_table_reference(table_name)
	return null


func _get_cached_table_reference(table_name: StringName) -> GFConfigTableResource:
	var cached: Variant = GFVariantData.get_option_value(_tables_by_name, table_name, null)
	if cached is GFConfigTableResource:
		var cached_table: GFConfigTableResource = cached
		if cached_table.get_table_key() == table_name:
			return cached_table
	return null


func _remove_table_entry(table_name: StringName) -> void:
	var retained: Array[GFConfigTableResource] = []
	for table_resource: GFConfigTableResource in _tables:
		if table_resource == null or table_resource.get_table_key() != table_name:
			retained.append(table_resource)
	_tables = retained
	var _erase_result: bool = _tables_by_name.erase(table_name)


func _collect_table_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for table_name: Variant in _tables_by_name.keys():
		var table_key: StringName = GFVariantData.to_string_name(table_name)
		if table_key != &"" and not names.has(table_key):
			names.append(table_key)
	for table_resource: GFConfigTableResource in _tables:
		if table_resource == null:
			continue
		var table_key: StringName = table_resource.get_table_key()
		if table_key != &"" and not names.has(table_key):
			names.append(table_key)
	return names
