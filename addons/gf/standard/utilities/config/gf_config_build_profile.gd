## GFConfigBuildProfile: 配置表构建过滤配置。
##
## 用 groups 与 tags 描述一组通用过滤条件，可用于导出前裁剪 schema 或记录。
## 具体分组名称由项目决定，GF 不内置 client、server 或 editor 语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigBuildProfile
extends Resource


# --- 导出变量 ---

## Profile 稳定标识。
## [br]
## @api public
@export var profile_id: StringName = &""

## 为空时不限制包含分组；非空时 metadata 至少命中一个分组才通过。
## [br]
## @api public
@export var include_groups: PackedStringArray = PackedStringArray()

## 命中任意排除分组时过滤。
## [br]
## @api public
@export var exclude_groups: PackedStringArray = PackedStringArray()

## 为空时不限制包含标签；非空时 metadata 至少命中一个标签才通过。
## [br]
## @api public
@export var include_tags: PackedStringArray = PackedStringArray()

## 命中任意排除标签时过滤。
## [br]
## @api public
@export var exclude_tags: PackedStringArray = PackedStringArray()

## metadata 缺少 groups/tags 时是否默认保留。
## [br]
## @api public
@export var default_include: bool = true

## 记录中存放元数据的字段名。
## [br]
## @api public
@export var record_metadata_field: StringName = &"_metadata"

## metadata 中表示分组的键。
## [br]
## @api public
@export var groups_key: StringName = &"groups"

## metadata 中表示标签的键。
## [br]
## @api public
@export var tags_key: StringName = &"tags"

## 可选元数据，供项目工具扩展使用。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存项目工具附加到当前构建 Profile 的元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 判断一份 metadata 是否通过当前 Profile。
## [br]
## @api public
## [br]
## @param source_metadata: 待检查元数据。
## [br]
## @return 通过时返回 true。
## [br]
## @schema source_metadata: Dictionary，包含可选 groups_key / tags_key 条目，值可为字符串或字符串数组。
func allows_metadata(source_metadata: Dictionary) -> bool:
	var groups: PackedStringArray = _to_packed_string_array(
		GFVariantData.get_option_value(source_metadata, groups_key, PackedStringArray())
	)
	var tags: PackedStringArray = _to_packed_string_array(
		GFVariantData.get_option_value(source_metadata, tags_key, PackedStringArray())
	)
	if groups.is_empty() and tags.is_empty():
		return default_include
	if _intersects(groups, exclude_groups) or _intersects(tags, exclude_tags):
		return false
	if not include_groups.is_empty() and not _intersects(groups, include_groups):
		return false
	if not include_tags.is_empty() and not _intersects(tags, include_tags):
		return false
	return true


## 过滤 schema，返回 schema 副本。
## [br]
## @api public
## [br]
## @param schema: 原 schema。
## [br]
## @return 过滤后的 schema；schema 为空时返回 null。
func filter_schema(schema: GFConfigTableSchema) -> GFConfigTableSchema:
	if schema == null:
		return null

	var result: GFConfigTableSchema = schema.duplicate_schema()
	result.columns = _filter_columns(result.columns)
	result.indexes = _filter_indexes(result.indexes, result.get_column_names())
	result.references = _filter_references(result.references, result.get_column_names())
	result.record_validation_rules = _filter_validation_rules(result.record_validation_rules)
	result.table_validation_rules = _filter_validation_rules(result.table_validation_rules)
	return result


## 过滤表记录。
## [br]
## @api public
## [br]
## @param table_data: Array[Dictionary] 或 Dictionary 表。
## [br]
## @return 与输入同形状的过滤结果；输入无效时返回原值副本。
## [br]
## @schema table_data: Variant，支持 Array[Dictionary]、Dictionary 表；其他值会按原形复制返回。
## [br]
## @schema return: Variant，过滤后的表数据；有效表会保持输入容器形态。
func filter_records(table_data: Variant) -> Variant:
	if table_data is Array:
		var rows: Array[Dictionary] = []
		var table_rows: Array = table_data
		for row_variant: Variant in table_rows:
			if not (row_variant is Dictionary):
				continue
			var row: Dictionary = GFVariantData.to_dictionary(row_variant)
			if allows_metadata(_get_record_metadata(row)):
				rows.append(row)
		return rows
	if table_data is Dictionary:
		var result: Dictionary = {}
		var table: Dictionary = table_data
		for key: Variant in table.keys():
			var row_variant: Variant = table[key]
			if not (row_variant is Dictionary):
				continue
			var row: Dictionary = GFVariantData.to_dictionary(row_variant)
			if allows_metadata(_get_record_metadata(row)):
				result[key] = row
		return result
	return GFVariantData.duplicate_variant(table_data)


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新 Profile。
func duplicate_profile() -> GFConfigBuildProfile:
	return _variant_to_build_profile(duplicate(true))


## 导出 Profile 摘要。
## [br]
## @api public
## [br]
## @return Profile 摘要字典。
## [br]
## @schema return: Dictionary，包含 profile_id、分组/标签过滤器、元数据键设置和 metadata。
func describe() -> Dictionary:
	return {
		"profile_id": profile_id,
		"include_groups": include_groups.duplicate(),
		"exclude_groups": exclude_groups.duplicate(),
		"include_tags": include_tags.duplicate(),
		"exclude_tags": exclude_tags.duplicate(),
		"default_include": default_include,
		"record_metadata_field": record_metadata_field,
		"groups_key": groups_key,
		"tags_key": tags_key,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _filter_columns(columns: Array[GFConfigTableColumn]) -> Array[GFConfigTableColumn]:
	var result: Array[GFConfigTableColumn] = []
	for column: GFConfigTableColumn in columns:
		if column != null and allows_metadata(column.metadata):
			result.append(column)
	return result


func _filter_indexes(
	indexes: Array[GFConfigTableIndexDefinition],
	column_names: PackedStringArray
) -> Array[GFConfigTableIndexDefinition]:
	var result: Array[GFConfigTableIndexDefinition] = []
	for index: GFConfigTableIndexDefinition in indexes:
		if index == null:
			continue
		if not index.metadata.is_empty() and not allows_metadata(index.metadata):
			continue
		if _all_fields_exist(index.field_names, column_names):
			result.append(index)
	return result


func _filter_references(
	references: Array[GFConfigTableReference],
	column_names: PackedStringArray
) -> Array[GFConfigTableReference]:
	var result: Array[GFConfigTableReference] = []
	for reference_definition: GFConfigTableReference in references:
		if reference_definition == null:
			continue
		if not reference_definition.metadata.is_empty() and not allows_metadata(reference_definition.metadata):
			continue
		if _all_fields_exist(reference_definition.source_fields, column_names):
			result.append(reference_definition)
	return result


func _filter_validation_rules(rules: Array[GFConfigValidationRule]) -> Array[GFConfigValidationRule]:
	var result: Array[GFConfigValidationRule] = []
	for rule: GFConfigValidationRule in rules:
		if rule == null:
			continue
		if not rule.metadata.is_empty() and not allows_metadata(rule.metadata):
			continue
		result.append(rule)
	return result


func _all_fields_exist(fields: PackedStringArray, column_names: PackedStringArray) -> bool:
	for field_name: String in fields:
		if not column_names.has(field_name):
			return false
	return true


func _get_record_metadata(record: Dictionary) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(record, record_metadata_field, {})
	return GFVariantData.as_dictionary(value)


func _intersects(left: PackedStringArray, right: PackedStringArray) -> bool:
	for item: String in left:
		if right.has(item):
			return true
	return false


func _to_packed_string_array(value: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		var packed: PackedStringArray = value
		return packed.duplicate()
	if value is Array:
		for item: Variant in value:
			var _array_item_appended: bool = result.append(GFVariantData.to_text(item))
	elif typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME:
		var _text_item_appended: bool = result.append(GFVariantData.to_text(value))
	return result


func _variant_to_build_profile(value: Variant) -> GFConfigBuildProfile:
	if value is GFConfigBuildProfile:
		var profile: GFConfigBuildProfile = value
		return profile
	return null
