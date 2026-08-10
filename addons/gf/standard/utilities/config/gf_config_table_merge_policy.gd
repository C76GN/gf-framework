## GFConfigTableMergePolicy: 配置表补丁合并策略。
##
## 描述如何识别记录、覆盖记录和处理删除标记。它只定义通用合并规则，
## 不绑定热更、模组、DLC 或任意项目业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigTableMergePolicy
extends Resource


# --- 枚举 ---

## 记录更新方式。
## [br]
## @api public
enum UpdateMode {
	## patch 记录整体替换 base 记录。
	REPLACE_RECORD,
	## patch 记录与 base 记录按字段合并，嵌套 Dictionary 递归合并。
	MERGE_FIELDS,
}


# --- 导出变量 ---

## 用于生成记录键的字段。为空时 Dictionary 表会优先使用外层 key。
## [br]
## @api public
@export var key_fields: PackedStringArray = PackedStringArray(["id"])

## 更新已有记录时采用的合并方式。
## [br]
## @api public
@export var update_mode: UpdateMode = UpdateMode.MERGE_FIELDS

## 是否允许 patch 插入新记录。
## [br]
## @api public
@export var allow_insert: bool = true

## 是否允许 patch 更新已有记录。
## [br]
## @api public
@export var allow_update: bool = true

## 是否允许 patch 删除已有记录。
## [br]
## @api public
@export var allow_delete: bool = true

## 删除标记字段。为空时不启用删除标记。
## [br]
## @api public
@export var delete_marker_field: StringName = &"_delete"

## 删除标记需要匹配的值。
## [br]
## @api public
## [br]
## @schema delete_marker_value: Variant，与删除标记字段比较的目标值。
@export var delete_marker_value: Variant = true

## Array 表输出时是否保留 base 原有顺序，并把新增记录追加到末尾。
## [br]
## @api public
@export var preserve_base_order: bool = true

## 可选元数据，供项目工具扩展使用。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存项目层附加到当前合并策略的元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 检查记录是否带有删除标记。
## [br]
## @api public
## [br]
## @param record: 记录。
## [br]
## @return 带有删除标记时返回 true。
## [br]
## @schema record: Dictionary，用于检查删除标记字段的配置记录。
func is_delete_record(record: Dictionary) -> bool:
	if delete_marker_field == &"":
		return false
	return record.has(delete_marker_field) and _make_variant_key(record[delete_marker_field]) == _make_variant_key(delete_marker_value)


## 根据记录生成稳定合并键。
## [br]
## @api public
## [br]
## @param record: 记录。
## [br]
## @param outer_key: Dictionary 表外层 key。
## [br]
## @return 合并键，字段缺失时返回空字符串。
## [br]
## @schema record: Dictionary，用于构建合并键的配置记录。
## [br]
## @schema outer_key: Variant，key_fields 为空时用于构建合并键的外层 key。
func make_record_key(record: Dictionary, outer_key: Variant = null) -> String:
	if key_fields.is_empty() and outer_key != null:
		return _make_variant_key(outer_key)
	if key_fields.is_empty():
		return ""

	var parts: PackedStringArray = PackedStringArray()
	for field_name: String in key_fields:
		var key: StringName = StringName(field_name)
		if not record.has(key):
			return ""
		var _part_appended: bool = parts.append(_make_variant_key(record[key]))
	return "|".join(parts)


## 合并两条记录。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param base_record: 原始记录。
## [br]
## @param patch_record: 补丁记录。
## [br]
## MERGE_FIELDS 会递归复制并合并嵌套 Dictionary；当前入口不执行深度或节点预算，只应接收已通过项目容量预检的配置记录。
## [br]
## @return 合并后的记录。
## [br]
## @schema base_record: Dictionary，原始记录。
## [br]
## @schema patch_record: Dictionary，补丁记录。
## [br]
## @schema return: Dictionary，合并后的记录。
func merge_record(base_record: Dictionary, patch_record: Dictionary) -> Dictionary:
	if update_mode == UpdateMode.REPLACE_RECORD:
		return patch_record.duplicate(true)
	return _merge_dictionaries(base_record, patch_record)


## 创建同内容拷贝。
## [br]
## @api public
## [br]
## @return 新合并策略。
func duplicate_policy() -> GFConfigTableMergePolicy:
	return _variant_to_merge_policy(duplicate(true))


## 导出策略摘要。
## [br]
## @api public
## [br]
## @return 策略摘要字典。
## [br]
## @schema return: Dictionary，包含 key_fields、update_mode、权限开关、删除标记设置、preserve_base_order 和 metadata。
func describe() -> Dictionary:
	return {
		"key_fields": key_fields.duplicate(),
		"update_mode": update_mode,
		"allow_insert": allow_insert,
		"allow_update": allow_update,
		"allow_delete": allow_delete,
		"delete_marker_field": delete_marker_field,
		"delete_marker_value": GFVariantData.duplicate_variant(delete_marker_value),
		"preserve_base_order": preserve_base_order,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _merge_dictionaries(base_record: Dictionary, patch_record: Dictionary) -> Dictionary:
	var result: Dictionary = base_record.duplicate(true)
	for key: Variant in patch_record.keys():
		if key == delete_marker_field:
			continue
		var patch_value: Variant = patch_record[key]
		var base_value: Variant = GFVariantData.get_option_value(result, key)
		if base_value is Dictionary and patch_value is Dictionary:
			result[key] = _merge_dictionaries(
				GFVariantData.as_dictionary(base_value),
				GFVariantData.as_dictionary(patch_value)
			)
		else:
			result[key] = GFVariantData.duplicate_variant(patch_value)
	return result


func _make_variant_key(value: Variant) -> String:
	return "%d:%s" % [typeof(value), var_to_str(value)]


func _variant_to_merge_policy(value: Variant) -> GFConfigTableMergePolicy:
	if value is GFConfigTableMergePolicy:
		var policy: GFConfigTableMergePolicy = value
		return policy
	return null
