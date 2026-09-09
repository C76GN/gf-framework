## GFConfigTableReference: 导表跨表引用声明。
##
## 描述当前记录的一组字段如何指向另一张表的一组字段，或声明一维数组中每个标量值的引用约束。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigTableReference
extends Resource


# --- 枚举 ---

## 来源引用的取值方式。
## [br]
## @api public
## [br]
## @since unreleased
enum SourceMode {
	## 将来源字段的完整值组成一个引用键。
	FIELDS,
	## 逐项校验单个 Array 字段，目标必须是单字段键；不自动解析目标记录。
	ARRAY_ELEMENTS,
}


# --- 导出变量 ---

## 引用稳定标识。为空时会根据来源字段和目标表生成。
## [br]
## @api public
@export var reference_id: StringName = &""

## 当前表中参与引用的字段名。
## [br]
## @api public
@export var source_fields: PackedStringArray = PackedStringArray()

## 来源取值方式。ARRAY_ELEMENTS 只接受单个一维 Array 字段，不转换元素类型。
## 元素支持 bool、int、有限 float、String、StringName，以及允许的 null；空数组合法，重复值按各自位置校验。
## [br]
## @api public
## [br]
## @since unreleased
@export var source_mode: SourceMode = SourceMode.FIELDS

## 目标表名。
## [br]
## @api public
@export var target_table_name: StringName = &""

## 目标表中参与匹配的字段名。为空时由目标 schema 的 id_field 补齐。
## [br]
## @api public
@export var target_fields: PackedStringArray = PackedStringArray()

## 为 true 时，来源字段必须存在且每个引用键必须匹配目标；为 false 时允许来源缺失或目标不匹配。
## ARRAY_ELEMENTS 的容器与元素类型约束不受此开关影响。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var required: bool = true

## 是否允许来源字段值为 null；ARRAY_ELEMENTS 中只作用于元素，整个来源字段仍必须为 Array。
## 允许的 null 作为键参与目标匹配，不会跳过 required 约束。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var allow_null_values: bool = true

## 可选元数据，供导入器、编辑器或项目层扩展使用。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存导入器、编辑器或项目层附加到当前引用的元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取稳定引用标识。
## [br]
## @api public
## [br]
## @return 引用标识。
func get_reference_id() -> StringName:
	if reference_id != &"":
		return reference_id
	var source_suffix: String = "[]" if source_mode == SourceMode.ARRAY_ELEMENTS else ""
	return StringName("%s%s->%s" % ["+".join(source_fields), source_suffix, String(target_table_name)])


## 检查引用声明是否有效。
## [br]
## @api public
## [br]
## @return 有效返回 true。
func is_valid_definition() -> bool:
	if source_fields.is_empty() or target_table_name == &"":
		return false
	match source_mode:
		SourceMode.FIELDS:
			return true
		SourceMode.ARRAY_ELEMENTS:
			return (
				source_fields.size() == 1
				and not source_fields[0].is_empty()
				and (target_fields.is_empty() or (target_fields.size() == 1 and not target_fields[0].is_empty()))
			)
	return false


## 获取目标字段名。
## [br]
## @api public
## [br]
## @param target_schema: 可选目标 schema。
## [br]
## @return 目标字段列表。
func get_target_fields(target_schema: GFConfigTableSchema = null) -> PackedStringArray:
	if not target_fields.is_empty():
		return target_fields.duplicate()
	var result: PackedStringArray = PackedStringArray()
	if target_schema != null and target_schema.id_field != &"":
		var _target_field_appended: bool = result.append(String(target_schema.id_field))
	return result


## 根据来源记录构建 FIELDS 模式的引用键。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param record: 来源记录。
## [br]
## @return 引用键；字段缺失、null 不允许或使用 ARRAY_ELEMENTS 时返回空字符串。
## [br]
## @schema record: Dictionary，用于构建引用键的来源配置记录。
func make_source_key(record: Dictionary) -> String:
	if source_mode != SourceMode.FIELDS:
		return ""
	return _make_key(record, source_fields)


## 根据目标记录构建引用键。
## [br]
## @api public
## [br]
## @param record: 目标记录。
## [br]
## @param target_schema: 可选目标 schema。
## [br]
## @return 引用键；字段缺失或 null 不允许时返回空字符串。
## [br]
## @schema record: Dictionary，用于构建引用键的目标配置记录。
func make_target_key(record: Dictionary, target_schema: GFConfigTableSchema = null) -> String:
	return _make_key(record, get_target_fields(target_schema))


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新引用声明。
func duplicate_reference() -> GFConfigTableReference:
	var reference_copy: GFConfigTableReference = GFConfigTableReference.new()
	reference_copy.reference_id = reference_id
	reference_copy.source_fields = source_fields.duplicate()
	reference_copy.source_mode = source_mode
	reference_copy.target_table_name = target_table_name
	reference_copy.target_fields = target_fields.duplicate()
	reference_copy.required = required
	reference_copy.allow_null_values = allow_null_values
	reference_copy.metadata = metadata.duplicate(true)
	return reference_copy


## 导出引用声明摘要。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 引用声明字典。
## [br]
## @schema return: Dictionary，包含 reference_id、source_fields、source_mode、target_table_name、target_fields、required、allow_null_values 和 metadata。
func describe() -> Dictionary:
	return {
		"reference_id": get_reference_id(),
		"source_fields": source_fields.duplicate(),
		"source_mode": source_mode,
		"target_table_name": target_table_name,
		"target_fields": target_fields.duplicate(),
		"required": required,
		"allow_null_values": allow_null_values,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _make_key(record: Dictionary, fields: PackedStringArray) -> String:
	if fields.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for field_name: String in fields:
		var key: StringName = StringName(field_name)
		if not record.has(key):
			return ""
		var value: Variant = record[key]
		if value == null and not allow_null_values:
			return ""
		var _part_appended: bool = parts.append("%d:%s" % [typeof(value), var_to_str(value)])
	return "|".join(parts)
