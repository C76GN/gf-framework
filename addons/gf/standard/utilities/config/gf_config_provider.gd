## GFConfigProvider: 通用的静态导表数据适配器基类。
##
## 为了让框架无缝衔接不同项目的导表工具（JSON、CSV 或自定义流水线），提供统一的读取接口。
## 具体项目应该继承此基类，并实现其数据加载和查询逻辑。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFConfigProvider
extends GFUtility


# --- 常量 ---

const _CONFIG_VALIDATION_REPORT = preload("res://addons/gf/standard/utilities/config/gf_config_validation_report.gd")


# --- 私有变量 ---

var _schemas: Dictionary = {}


# --- 公共方法 ---

## 根据表名和 ID 获取单条记录。
## [br]
## @api public
## [br]
## @param _table_name: 表名。
## [br]
## @param _id: 记录的唯一标识符。
## [br]
## @schema _id: Variant，项目配置表使用的记录键，通常为 String、StringName 或 int。
## [br]
## @return 返回对应的记录数据，默认返回 null 并报错。
## [br]
## @schema return: Variant，子类通常返回记录 Dictionary 或项目自定义记录对象；未命中时可返回 null。
func get_record(_table_name: StringName, _id: Variant) -> Variant:
	push_error("[GFConfigProvider][config_provider.get_record_unimplemented] Subclasses must implement get_record().")
	return null


## 根据表名获取整张表的数据。
## [br]
## @api public
## [br]
## @param _table_name: 表名。
## [br]
## @return 返回整张表的数据，默认返回 null 并报错。
## [br]
## @schema return: Variant，子类通常返回 Array[Dictionary]、Dictionary 或项目自定义表容器；未命中时可返回 null。
func get_table(_table_name: StringName) -> Variant:
	push_error("[GFConfigProvider][config_provider.get_table_unimplemented] Subclasses must implement get_table().")
	return null


## 注册导表结构声明。
## [br]
## @api public
## [br]
## @param schema: 表结构声明。
## [br]
## @return 注册成功返回 true。
func register_schema(schema: GFConfigTableSchema) -> bool:
	if schema == null or schema.get_table_key() == &"":
		push_error("[GFConfigProvider][config_provider.schema_registration_invalid] Cannot register_schema: schema is null or table_name is empty.")
		return false

	_schemas[schema.get_table_key()] = schema.duplicate_schema()
	return true


## 注销导表结构声明。
## [br]
## @api public
## [br]
## @param table_name: 表名。
func unregister_schema(table_name: StringName) -> void:
	var _erase_result_81: Variant = _schemas.erase(table_name)


## 检查是否注册了导表结构声明。
## [br]
## @api public
## [br]
## @param table_name: 表名。
## [br]
## @return 已注册返回 true。
func has_schema(table_name: StringName) -> bool:
	return _schemas.has(table_name)


## 获取导表结构声明。
## [br]
## @api public
## [br]
## @param table_name: 表名。
## [br]
## @return 已注册时返回 schema 拷贝，否则返回 null。
func get_schema(table_name: StringName) -> GFConfigTableSchema:
	var schema: GFConfigTableSchema = _get_schema_reference(table_name)
	return schema.duplicate_schema() if schema != null else null


## 获取已注册的导表结构标识。
## [br]
## @api public
## [br]
## @return 表名列表。
func get_schema_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for table_name: StringName in _schemas.keys():
		var _id_appended: bool = result.append(String(table_name))
	result.sort()
	return result


## 使用已注册 schema 校验单条记录。
## [br]
## @api public
## [br]
## @param table_name: 表名。
## [br]
## @param record: 记录字典。
## [br]
## @schema record: Dictionary，待校验的配置记录，键为字段名，值为字段数据。
## [br]
## @param row_key: 可选行标识。
## [br]
## @schema row_key: Variant，写入校验报告 issue 的行标识。
## [br]
## @param options: 可选校验上下文。
## [br]
## @schema options: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
## [br]
## @return 校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_record(
	table_name: StringName,
	record: Dictionary,
	row_key: Variant = null,
	options: Dictionary = {}
) -> Dictionary:
	var schema: GFConfigTableSchema = get_schema(table_name)
	if schema == null:
		return _make_missing_schema_report(table_name)
	return schema.validate_record(record, row_key, options)


## 使用已注册 schema 校验整张表。
## [br]
## @api public
## [br]
## @param table_name: 表名。
## [br]
## @param table_data: 可选表数据；为 null 时调用 get_table()。
## [br]
## @schema table_data: Variant，支持 Array[Dictionary]、Dictionary 或 null。
## [br]
## @param options: 可选校验上下文。
## [br]
## @schema options: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
## [br]
## @return 校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_table(table_name: StringName, table_data: Variant = null, options: Dictionary = {}) -> Dictionary:
	var schema: GFConfigTableSchema = get_schema(table_name)
	if schema == null:
		return _make_missing_schema_report(table_name)

	var data: Variant = table_data
	if data == null:
		data = get_table(table_name)
	return schema.validate_table(data, options)


## 使用已注册 schema 转换单条记录。
## [br]
## @api public
## [br]
## @param table_name: 表名。
## [br]
## @param record: 记录字典。
## [br]
## @schema record: Dictionary，待转换的配置记录，键为字段名，值为字段数据。
## [br]
## @return 转换后的新记录；缺少 schema 时返回记录拷贝。
## [br]
## @schema return: Dictionary，转换后的记录副本。
func coerce_record(table_name: StringName, record: Dictionary) -> Dictionary:
	var schema: GFConfigTableSchema = get_schema(table_name)
	if schema == null:
		return record.duplicate(true)
	return schema.coerce_record(record)


# --- 私有/辅助方法 ---

func _make_missing_schema_report(table_name: StringName) -> Dictionary:
	return _CONFIG_VALIDATION_REPORT.new().make_error_report(table_name, "missing_schema", "未注册导表结构声明：%s。" % String(table_name))


func _get_schema_reference(table_name: StringName) -> GFConfigTableSchema:
	return _variant_to_schema(GFVariantData.get_option_value(_schemas, table_name))


func _variant_to_schema(value: Variant) -> GFConfigTableSchema:
	if value is GFConfigTableSchema:
		var schema: GFConfigTableSchema = value
		return schema
	return null
