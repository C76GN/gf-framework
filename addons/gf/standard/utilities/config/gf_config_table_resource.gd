## GFConfigTableResource: 可保存为 Godot Resource 的通用配置表。
##
## 用于承载导表工具生成的单表数据，保留稳定顺序、可选 schema、可选 ID 索引和元数据。
## 该资源不绑定业务表语义，适合保存为 `.tres` / `.res` 后由运行时 Provider 读取。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 5.2.0
class_name GFConfigTableResource
extends Resource


# --- 导出变量 ---

## 表名。为空时优先使用 schema.table_name。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var table_name: StringName = &""

## 可选表结构声明，用于校验、字段转换和默认 ID 字段声明。
## [br]
## @api public
## [br]
## @since 5.2.0
@export var schema: GFConfigTableSchema = null

## 表记录列表。记录顺序应保持导出时的稳定顺序，便于 Inspector、调试和确定性导出。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema records: Array[Dictionary]，每个 Dictionary 是一条配置记录。
@export var records: Array[Dictionary] = []

## 可选 ID 索引。为空时 get_record() 会按 schema.id_field 或默认 id 字段扫描 records。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema records_by_id: Dictionary，键为配置记录 ID，值为对应记录 Dictionary。
@export var records_by_id: Dictionary = {}

## 可选命名索引缓存。为空时索引查询会按 schema.indexes 临时构建。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema records_by_index: Dictionary，键为索引 ID，值为索引键到记录列表的 Dictionary。
@export var records_by_index: Dictionary = {}

## 可选元数据，供导入器、编辑器或项目层扩展使用。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema metadata: Dictionary，保存导表来源、构建摘要或项目侧附加信息。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取稳定表键。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 表名；本资源未声明且 schema 也未声明时返回空 StringName。
func get_table_key() -> StringName:
	if table_name != &"":
		return table_name
	if schema != null:
		return schema.get_table_key()
	return &""


## 获取用于构建默认索引的 ID 字段。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: ID 字段名；schema 显式声明空 id_field 时返回空 StringName。
func get_id_field() -> StringName:
	if schema != null:
		return schema.id_field
	return &"id"


## 获取表记录列表。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param duplicate_records: 为 true 时返回记录深拷贝，避免调用方修改资源内数据。
## [br]
## @return: 表记录列表。
## [br]
## @schema return: Array[Dictionary]，每个 Dictionary 是一条配置记录。
func get_records(duplicate_records: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in records:
		result.append(_duplicate_record(record) if duplicate_records else record)
	return result


## 获取 ID 索引。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param duplicate_records: 为 true 时返回记录深拷贝，避免调用方修改资源内数据。
## [br]
## @return: 按当前 records 构建的 ID 索引副本。
## [br]
## @schema return: Dictionary，键为配置记录 ID，值为对应记录 Dictionary。
func get_records_by_id(duplicate_records: bool = true) -> Dictionary:
	var source_index: Dictionary = _build_index_from_records()
	return _duplicate_record_index(source_index, duplicate_records)


## 获取当前可查询的命名索引 ID。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 排序后的索引 ID 列表。
func get_index_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for index_id: Variant in records_by_index.keys():
		_append_index_id(result, GFVariantData.to_string_name(index_id))
	if schema != null:
		for index: GFConfigTableIndexDefinition in schema.indexes:
			if index != null and index.is_valid_definition():
				_append_index_id(result, index.get_index_id())
	result.sort()
	return result


## 检查记录是否存在。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param record_id: 记录 ID。
## [br]
## @schema record_id: Variant，项目配置表使用的记录键，通常为 String、StringName 或 int。
## [br]
## @return: 存在返回 true。
func has_record(record_id: Variant) -> bool:
	return get_record(record_id, false) != null


## 根据 ID 获取记录。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param record_id: 记录 ID。
## [br]
## @schema record_id: Variant，项目配置表使用的记录键，通常为 String、StringName 或 int。
## [br]
## @param duplicate_record: 为 true 时返回记录深拷贝，避免调用方修改资源内数据。
## [br]
## @return: 找到时返回记录 Dictionary，否则返回 null。
## [br]
## @schema return: Variant，找到时为 Dictionary，未命中时为 null。
func get_record(record_id: Variant, duplicate_record: bool = true) -> Variant:
	for record: Dictionary in records:
		if _record_matches_id(record, record_id):
			return _duplicate_record(record) if duplicate_record else record
	return null


## 根据索引声明构建索引键。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param index_id: 索引 ID。
## [br]
## @param record: 用于构建索引键的记录或字段值字典。
## [br]
## @schema record: Dictionary，键为索引字段名，值为字段数据。
## [br]
## @return: 索引键；索引不存在、字段缺失或字段值不符合索引声明时返回空字符串。
func make_index_key(index_id: StringName, record: Dictionary) -> String:
	var index: GFConfigTableIndexDefinition = _get_index_definition(index_id)
	if index == null:
		return ""
	return index.make_key(record)


## 检查命名索引键是否存在。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 由 make_index_key() 或同等规则生成的索引键。
## [br]
## @return: 存在返回 true。
func has_index_key(index_id: StringName, index_key: String) -> bool:
	var index_data: Dictionary = _get_index_data(index_id)
	var value: Variant = GFVariantData.get_option_value(index_data, index_key, null)
	return value is Array and not GFVariantData.as_array(value).is_empty()


## 根据命名索引获取记录列表。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 由 make_index_key() 或同等规则生成的索引键。
## [br]
## @param duplicate_records: 为 true 时返回记录深拷贝，避免调用方修改资源内数据。
## [br]
## @return: 命中的记录列表；未命中时返回空数组。
## [br]
## @schema return: Array[Dictionary]，每个 Dictionary 是一条配置记录。
func get_index_records(index_id: StringName, index_key: String, duplicate_records: bool = true) -> Array[Dictionary]:
	var index_data: Dictionary = _get_index_data(index_id)
	var value: Variant = GFVariantData.get_option_value(index_data, index_key, [])
	if not (value is Array):
		return []
	return _duplicate_record_array(GFVariantData.as_array(value), duplicate_records)


## 根据命名索引获取第一条记录。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param index_id: 索引 ID。
## [br]
## @param index_key: 由 make_index_key() 或同等规则生成的索引键。
## [br]
## @param duplicate_record: 为 true 时返回记录深拷贝，避免调用方修改资源内数据。
## [br]
## @return: 找到时返回第一条记录 Dictionary，否则返回 null。
## [br]
## @schema return: Variant，找到时为 Dictionary，未命中时为 null。
func get_index_record(index_id: StringName, index_key: String, duplicate_record: bool = true) -> Variant:
	var index_data: Dictionary = _get_index_data(index_id)
	var value: Variant = GFVariantData.get_option_value(index_data, index_key, [])
	if not (value is Array):
		return null
	var matches: Array = GFVariantData.as_array(value)
	if matches.is_empty():
		return null
	var first_value: Variant = matches[0]
	if not (first_value is Dictionary):
		return null
	var first_record: Dictionary = GFVariantData.as_dictionary(first_value)
	return first_record.duplicate(true) if duplicate_record else first_record


## 按 records 重建 records_by_id。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 新索引中的记录数量。
func rebuild_index() -> int:
	records_by_id = _build_index_from_records()
	return records_by_id.size()


## 按 schema.indexes 重建 records_by_index。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 新索引缓存中的索引数量。
func rebuild_indexes() -> int:
	records_by_index = _build_indexes_from_records()
	return records_by_index.size()


## 使用 schema 校验当前记录列表。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param options: 可选上下文，支持 source、row_locations 等校验报告字段。
## [br]
## @schema options: Dictionary，可包含 source、line、column、row_index、column_index 和 row_locations。
## [br]
## @return: 校验报告字典。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary。
func validate_records(options: Dictionary = {}) -> Dictionary:
	if schema == null:
		return GFConfigValidationReport.new().make_error_report(
			get_table_key(),
			"missing_schema",
			"配置表资源缺少 schema：%s。" % String(get_table_key())
		)
	return schema.validate_table(records, options)


## 创建同内容拷贝，避免运行时修改污染共享 Resource。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @return: 新配置表资源。
func duplicate_table() -> GFConfigTableResource:
	var table: GFConfigTableResource = GFConfigTableResource.new()
	table.table_name = table_name
	table.schema = schema.duplicate_schema() if schema != null else null
	table.records = get_records(true)
	table.records_by_id = _duplicate_record_index(records_by_id, true)
	table.records_by_index = _duplicate_records_by_index(records_by_index, true)
	table.metadata = metadata.duplicate(true)
	return table


# --- 私有/辅助方法 ---

func _build_index_from_records() -> Dictionary:
	var id_field: StringName = get_id_field()
	if id_field == &"":
		return {}

	var result: Dictionary = {}
	for record: Dictionary in records:
		if not _record_has_id_field(record, id_field):
			continue
		var record_id: Variant = GFVariantData.get_option_value(record, id_field)
		result[record_id] = record
	return result


func _build_indexes_from_records() -> Dictionary:
	var result: Dictionary = {}
	if schema == null:
		return result

	for index: GFConfigTableIndexDefinition in schema.indexes:
		if index == null or not index.is_valid_definition():
			continue
		result[index.get_index_id()] = _build_index_from_definition(index)
	return result


func _build_index_from_definition(index: GFConfigTableIndexDefinition) -> Dictionary:
	var result: Dictionary = {}
	for record: Dictionary in records:
		var index_key: String = index.make_key(record)
		if index_key.is_empty():
			continue
		var bucket: Array = GFVariantData.as_array(GFVariantData.get_option_value(result, index_key, []))
		bucket.append(record)
		result[index_key] = bucket
	return result


func _record_matches_id(record: Dictionary, record_id: Variant) -> bool:
	var id_field: StringName = get_id_field()
	if id_field == &"" or not _record_has_id_field(record, id_field):
		return false
	return GFVariantData.get_option_value(record, id_field) == record_id


func _record_has_id_field(record: Dictionary, id_field: StringName) -> bool:
	return record.has(id_field) or record.has(String(id_field))


func _duplicate_record(record: Dictionary) -> Dictionary:
	return record.duplicate(true)


func _duplicate_record_index(source_index: Dictionary, duplicate_records: bool) -> Dictionary:
	var result: Dictionary = {}
	for record_id: Variant in source_index.keys():
		var value: Variant = source_index[record_id]
		if duplicate_records and value is Dictionary:
			var record: Dictionary = value
			result[record_id] = _duplicate_record(record)
		else:
			result[record_id] = value
	return result


func _duplicate_records_by_index(source_index: Dictionary, duplicate_records: bool) -> Dictionary:
	var result: Dictionary = {}
	for index_id: Variant in source_index.keys():
		var value: Variant = source_index[index_id]
		if not (value is Dictionary):
			result[index_id] = value
			continue

		var source_records_by_key: Dictionary = value
		var records_by_key: Dictionary = {}
		for index_key: Variant in source_records_by_key.keys():
			var rows: Variant = source_records_by_key[index_key]
			if rows is Array:
				records_by_key[index_key] = _duplicate_record_array(GFVariantData.as_array(rows), duplicate_records)
			else:
				records_by_key[index_key] = rows
		result[index_id] = records_by_key
	return result


func _duplicate_record_array(source_records: Array, duplicate_records: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in source_records:
		if value is Dictionary:
			var record: Dictionary = value
			result.append(_duplicate_record(record) if duplicate_records else record)
	return result


func _get_index_definition(index_id: StringName) -> GFConfigTableIndexDefinition:
	if schema == null:
		return null
	return schema.get_index(index_id)


func _get_index_data(index_id: StringName) -> Dictionary:
	var index: GFConfigTableIndexDefinition = _get_index_definition(index_id)
	if index != null and index.is_valid_definition():
		return _build_index_from_definition(index)

	var value: Variant = GFVariantData.get_option_value(records_by_index, index_id, null)
	if value is Dictionary:
		var index_data: Dictionary = value
		return index_data
	return {}


func _append_index_id(target: PackedStringArray, index_id: StringName) -> void:
	if index_id == &"" or target.has(String(index_id)):
		return
	var _appended: bool = target.append(String(index_id))
