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
## @since 3.17.0
## [br]
## @param record: 记录。
## [br]
## @return 带有删除标记时返回 true；未命中或预算失败均返回 false。直接调用时应传入共享 work_budget，并通过句柄的 is_ok()、get_report() 区分预算失败。
## [br]
## @schema record: Dictionary，用于检查删除标记字段的配置记录。
## [br]
## @param options: 与合并操作共享的预算选项。
## [br]
## @schema options: Dictionary，接受互斥的 work_limits 或 work_budget，语义见 GFConfigWorkBudget.from_options()。
func is_delete_record(record: Dictionary, options: Dictionary = {}) -> bool:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if delete_marker_field == &"":
		return false
	if not budget.is_ok() or not record.has(delete_marker_field):
		return false
	var marker: Variant = record[delete_marker_field]
	if not budget.admit_value(marker, "merge.delete_marker") or not budget.admit_value(delete_marker_value, "merge.delete_marker_value"):
		return false
	return typeof(marker) == typeof(delete_marker_value) and marker == delete_marker_value


## 根据记录生成稳定合并键。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param record: 记录。
## [br]
## @param outer_key: Dictionary 表外层 key。
## [br]
## @return 合并键；字段缺失、不是 String、StringName、int、bool、有限 float 或预算失败时返回空字符串。直接调用时应传入共享 work_budget，并通过句柄的 is_ok()、get_report() 区分预算失败。
## [br]
## @schema record: Dictionary，用于构建合并键的配置记录。
## [br]
## @schema outer_key: Variant，key_fields 为空时用于构建合并键的外层 key。
## [br]
## @param options: 与合并操作共享的预算选项。
## [br]
## @schema options: Dictionary，接受互斥的 work_limits 或 work_budget，语义见 GFConfigWorkBudget.from_options()。
func make_record_key(
	record: Dictionary,
	outer_key: Variant = null,
	options: Dictionary = {}
) -> String:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not budget.admit_value(key_fields, "merge.key_fields"):
		return ""
	if key_fields.is_empty() and outer_key != null:
		return _make_variant_key(outer_key, budget)
	if key_fields.is_empty():
		return ""

	var parts: PackedStringArray = PackedStringArray()
	for field_name: String in key_fields:
		var key: StringName = StringName(field_name)
		if not record.has(key):
			return ""
		var part: String = _make_variant_key(
			record[key],
			budget
		)
		if part.is_empty():
			return ""
		var _part_appended: bool = parts.append(part)
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
## MERGE_FIELDS 递归合并嵌套 Dictionary；输入与最终复制均由同一有限预算准入。
## [br]
## @param options: 新预算限额或已有批次预算。
## [br]
## @schema options: Dictionary，接受互斥的 work_limits 或 work_budget，语义见 GFConfigWorkBudget.from_options()。
## [br]
## @return 明确区分合法空记录与失败的结果报告。
## [br]
## @schema base_record: Dictionary，原始记录。
## [br]
## @schema patch_record: Dictionary，补丁记录。
## [br]
## @schema return: Dictionary，含 ok、data、error_kind、error、context、budget_report；成功 data 为独立记录，失败为 null。
func merge_record(
	base_record: Dictionary,
	patch_record: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	if not budget.admit_value(base_record, "merge.record.base") or not budget.admit_value(patch_record, "merge.record.patch"):
		return _record_result(null, budget)
	var merged: Dictionary = {}
	if update_mode == UpdateMode.REPLACE_RECORD:
		merged = patch_record
	else:
		merged = _merge_dictionaries(
			base_record,
			patch_record,
			budget,
			0
		)
	if not budget.admit_value(merged, "merge.record.output"):
		return _record_result(null, budget)
	return _record_result(
		merged.duplicate(true),
		budget
	)


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

## 以 base 字典为起点应用 patch 字段，并按配置处理删除标记。
## [br]
## @api private
## [br]
func _merge_dictionaries(
	base_record: Dictionary,
	patch_record: Dictionary,
	budget: GFConfigWorkBudget,
	depth: int
) -> Dictionary:
	if not budget.check_depth(depth, "merge.record.fields") or not budget.consume_work(
		base_record.size(),
		"merge.record.copy_fields"
	):
		return {}
	var result: Dictionary = base_record.duplicate()
	for key: Variant in patch_record:
		if not budget.consume_work(1, "merge.record.field"):
			return {}
		if key == delete_marker_field:
			continue
		var patch_value: Variant = patch_record[key]
		var base_value: Variant = GFVariantData.get_option_value(result, key)
		if base_value is Dictionary and patch_value is Dictionary:
			result[key] = _merge_dictionaries(
				GFVariantData.as_dictionary(base_value),
				GFVariantData.as_dictionary(patch_value),
				budget,
				depth + 1
			)
		else:
			result[key] = patch_value
		if not budget.is_ok():
			return {}
	return result


## 仅对稳定标量生成带类型及长度的键，避免任意资源序列化和转义放大。
## [br]
## @api private
## [br]
func _make_variant_key(value: Variant, budget: GFConfigWorkBudget) -> String:
	if not (
		value is String
		or value is StringName
		or value is int
		or value is bool
		or value is float
	):
		return ""
	if value is float:
		var number: float = value
		if not is_finite(number):
			return ""
	if not budget.admit_value(value, "merge.key"):
		return ""
	var value_text: String = str(value)
	if value is float:
		value_text = var_to_str(value)
	return (
		"%d:%d:%s"
		% [
			typeof(value),
			value_text.length(),
			value_text,
		]
	)


## 把预算结果与成功数据组成单条合并报告。
## [br]
## @api private
func _record_result(data: Variant, budget: GFConfigWorkBudget) -> Dictionary:
	var budget_report: Dictionary = budget.get_report()
	return {
		"ok": budget.is_ok(),
		"data": data if budget.is_ok() else null,
		"error_kind": budget_report["error_kind"],
		"error": budget_report["error"],
		"context": budget_report["context"],
		"budget_report": budget_report,
	}


## 仅当 Variant 值为 GFConfigTableMergePolicy 时返回该合并策略。
## [br]
## @api private
## [br]
func _variant_to_merge_policy(value: Variant) -> GFConfigTableMergePolicy:
	if value is GFConfigTableMergePolicy:
		var policy: GFConfigTableMergePolicy = value
		return policy
	return null
