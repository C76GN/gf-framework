## GFConfigDatabaseResource: 可保存为 Godot Resource 的通用配置数据库。
##
## 用于聚合多张 GFConfigTableResource，作为导表工具生成的整包配置产物。
## 该资源只承载通用表集合、校验入口和元数据，不绑定业务表语义、构建 profile 或热更新策略。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 5.2.0
class_name GFConfigDatabaseResource
extends Resource


# --- 导出变量 ---

## 配置数据库稳定标识。可用于区分主配置、测试配置或项目侧不同配置集合。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var database_id: StringName = &""

## 可选配置版本。GF 不解释版本语义，只保存导表工具或项目层写入的字符串。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var version: String = ""

## 配置表资源列表。表名由每张 GFConfigTableResource.get_table_key() 决定。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema tables: Array[GFConfigTableResource]，每个元素是一张配置表资源。
@export var tables: Array[GFConfigTableResource] = []

## 可选元数据，供导入器、编辑器或项目层扩展使用。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema metadata: Dictionary，保存导表来源、构建摘要或项目侧附加信息。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取配置数据库稳定标识。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 配置数据库 ID；未声明时返回空 StringName。
func get_database_key() -> StringName:
	return database_id


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
		push_error("[GFConfigDatabaseResource] register_table 失败：table_resource 为空或 table_name 为空。")
		return false

	_remove_table_entry(table_resource.get_table_key())
	tables.append(table_resource)
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
	if not has_table(table_name):
		return false
	_remove_table_entry(table_name)
	return true


## 清空所有配置表资源。
## [br]
## @api public
## [br]
## @since 5.2.0
func clear_tables() -> void:
	tables.clear()


## 检查配置表是否存在。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @return: 存在返回 true。
func has_table(table_name: StringName) -> bool:
	return _get_table_reference(table_name) != null


## 获取配置表名列表。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 排序后的表名列表。
func get_table_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for table_resource: GFConfigTableResource in tables:
		if table_resource == null:
			continue
		_append_table_id(result, table_resource.get_table_key())
	result.sort()
	return result


## 获取表名到表数据的字典。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param duplicate_records: 为 true 时返回记录深拷贝，避免调用方修改数据库资源内数据。
## [br]
## @return: 表名到表数据的字典。
## [br]
## @schema return: Dictionary，键为表名 StringName，值为 Array[Dictionary] 表数据。
func get_tables_by_name(duplicate_records: bool = true) -> Dictionary:
	var result: Dictionary = {}
	for table_resource: GFConfigTableResource in tables:
		if table_resource == null or table_resource.get_table_key() == &"":
			continue
		result[table_resource.get_table_key()] = table_resource.get_records(duplicate_records)
	return result


## 获取数据库中的 schema 列表。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param duplicate_schemas: 为 true 时返回 schema 深拷贝，避免调用方修改数据库资源内数据。
## [br]
## @return: schema 列表。
## [br]
## @schema return: Array[GFConfigTableSchema]，每个元素是一张表的 schema。
func get_schemas(duplicate_schemas: bool = true) -> Array[GFConfigTableSchema]:
	var result: Array[GFConfigTableSchema] = []
	for table_resource: GFConfigTableResource in tables:
		if table_resource == null or table_resource.schema == null:
			continue
		result.append(table_resource.schema.duplicate_schema() if duplicate_schemas else table_resource.schema)
	return result


## 获取配置表资源列表。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param duplicate_tables: 为 true 时返回资源深拷贝，避免调用方修改数据库资源内数据。
## [br]
## @return: 表资源列表。
## [br]
## @schema return: Array[GFConfigTableResource]，每个元素是一张配置表资源。
func get_table_resources(duplicate_tables: bool = true) -> Array[GFConfigTableResource]:
	var result: Array[GFConfigTableResource] = []
	for table_resource: GFConfigTableResource in tables:
		if table_resource == null:
			continue
		result.append(table_resource.duplicate_table() if duplicate_tables else table_resource)
	return result


## 获取配置表资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param table_name: 表名。
## [br]
## @param duplicate_table: 为 true 时返回资源深拷贝，避免调用方修改数据库资源内数据。
## [br]
## @return: 配置表资源；未命中时返回 null。
func get_table_resource(table_name: StringName, duplicate_table: bool = true) -> GFConfigTableResource:
	var table_resource: GFConfigTableResource = _get_table_reference(table_name)
	if table_resource == null:
		return null
	return table_resource.duplicate_table() if duplicate_table else table_resource


## 校验数据库中的表结构、表数据和跨表引用。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param options: 可选上下文，支持 validate_schema，并透传给引用校验器。
## [br]
## @schema options: Dictionary，可包含 validate_schema。
## [br]
## @return: 聚合校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_database(options: Dictionary = {}) -> Dictionary:
	var report_builder: GFConfigValidationReport = GFConfigValidationReport.new()
	var report: Dictionary = report_builder.make_report(database_id, _count_records())
	_validate_table_resource_entries(report, options)

	var reference_options: Dictionary = options.duplicate(true)
	reference_options["validate_schema"] = false
	var reference_report: Dictionary = GFConfigReferenceResolver.validate_tables(
		get_tables_by_name(false),
		get_schemas(false),
		reference_options
	)
	report_builder.merge_report(report, reference_report)
	report_builder.finalize_report(report)
	return report


## 重建所有表资源的 ID 索引和命名索引缓存。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 成功处理的有效表数量。
func rebuild_table_indexes() -> int:
	var count: int = 0
	for table_resource: GFConfigTableResource in tables:
		if table_resource == null or table_resource.get_table_key() == &"":
			continue
		var _id_index_count: int = table_resource.rebuild_index()
		var _named_index_count: int = table_resource.rebuild_indexes()
		count += 1
	return count


## 创建同内容拷贝，避免运行时修改污染共享 Resource。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 新配置数据库资源。
func duplicate_database() -> GFConfigDatabaseResource:
	var script_value: Variant = get_script()
	var created_resource: Variant = null
	if script_value is GDScript:
		var gdscript: GDScript = script_value
		created_resource = gdscript.new()
	if not (created_resource is GFConfigDatabaseResource):
		return GFConfigDatabaseResource.new()

	var database: GFConfigDatabaseResource = created_resource
	database.database_id = database_id
	database.version = version
	var copied_tables: Array[GFConfigTableResource] = []
	for table_resource: GFConfigTableResource in tables:
		copied_tables.append(table_resource.duplicate_table() if table_resource != null else null)
	database.tables = copied_tables
	database.metadata = metadata.duplicate(true)
	return database


# --- 私有/辅助方法 ---

func _get_table_reference(table_name: StringName) -> GFConfigTableResource:
	for table_resource: GFConfigTableResource in tables:
		if table_resource != null and table_resource.get_table_key() == table_name:
			return table_resource
	return null


func _remove_table_entry(table_name: StringName) -> void:
	var retained: Array[GFConfigTableResource] = []
	for table_resource: GFConfigTableResource in tables:
		if table_resource == null or table_resource.get_table_key() != table_name:
			retained.append(table_resource)
	tables = retained


func _append_table_id(target: PackedStringArray, table_name: StringName) -> void:
	if table_name == &"" or target.has(String(table_name)):
		return
	var _appended: bool = target.append(String(table_name))


func _count_records() -> int:
	var count: int = 0
	for table_resource: GFConfigTableResource in tables:
		if table_resource != null:
			count += table_resource.records.size()
	return count


func _validate_table_resource_entries(report: Dictionary, options: Dictionary) -> void:
	var seen_tables: Dictionary = {}
	var report_builder: GFConfigValidationReport = GFConfigValidationReport.new()
	var validate_schema: bool = GFVariantData.get_option_bool(options, "validate_schema", true)
	for index: int in range(tables.size()):
		var table_resource: GFConfigTableResource = tables[index]
		if table_resource == null:
			report_builder.add_issue(
				report,
				"error",
				"null_table_resource",
				&"",
				index,
				&"",
				"配置数据库包含空表资源。",
				{ "row_index": index }
			)
			continue

		var table_key: StringName = table_resource.get_table_key()
		if table_key == &"":
			report_builder.add_issue(
				report,
				"error",
				"empty_table_name",
				&"",
				index,
				&"",
				"配置数据库包含空表名资源。",
				{ "row_index": index }
			)
			continue

		if seen_tables.has(table_key):
			report_builder.add_issue(
				report,
				"error",
				"duplicate_table_name",
				table_key,
				index,
				&"",
				"配置数据库表名重复：%s。" % String(table_key),
				{ "row_index": index }
			)
		seen_tables[table_key] = true

		if table_resource.schema == null:
			report_builder.add_issue(
				report,
				"error",
				"missing_schema",
				table_key,
				null,
				&"",
				"配置表资源缺少 schema：%s。" % String(table_key)
			)
			continue

		var schema_key: StringName = table_resource.schema.get_table_key()
		if schema_key != table_key:
			report_builder.add_issue(
				report,
				"error",
				"schema_table_name_mismatch",
				table_key,
				null,
				&"table_name",
				"配置表资源 table_name 与 schema.table_name 不一致：%s != %s。" % [String(table_key), String(schema_key)],
				{
					"expected_value": table_key,
					"actual_value": schema_key,
				}
			)
			continue

		if validate_schema:
			report_builder.merge_report(report, table_resource.schema.validate_definition(options), false)
			report_builder.merge_report(report, table_resource.validate_records(options), false)
