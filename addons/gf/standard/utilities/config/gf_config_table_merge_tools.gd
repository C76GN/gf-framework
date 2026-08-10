## GFConfigTableMergeTools: 配置表补丁合并工具。
##
## 提供 Array[Dictionary] 与 Dictionary 表的通用补丁合并，适合导表后处理、
## 编辑器工具或项目自己的配置包流程使用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFConfigTableMergeTools
extends RefCounted


# --- 常量 ---

const _CONFIG_VALIDATION_REPORT = preload("res://addons/gf/standard/utilities/config/gf_config_validation_report.gd")


# --- 公共方法 ---

## 合并 base 表与 patch 表。
## [br]
## @api public
## [br]
## @param base_table: Array[Dictionary] 或 Dictionary 形式的基础表。
## [br]
## @schema base_table: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
## [br]
## @param patch_table: Array[Dictionary] 或 Dictionary 形式的补丁表。
## [br]
## @schema patch_table: Variant，支持 Array[Dictionary] 或 Dictionary，记录值必须为 Dictionary。
## [br]
## @param policy: 可选合并策略；为空时使用默认策略。
## [br]
## @return 结果字典，包含 ok、data、issues 与统计信息。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary，额外包含 data、dictionary_output、base_count、inserted_count、updated_count 和 deleted_count。
static func merge_tables(
	base_table: Variant,
	patch_table: Variant,
	policy: GFConfigTableMergePolicy = null
) -> Dictionary:
	var resolved_policy: GFConfigTableMergePolicy = policy if policy != null else GFConfigTableMergePolicy.new()
	var base_rows_variant: Variant = _normalize_table(base_table)
	var patch_rows_variant: Variant = _normalize_table(patch_table)
	var report: Dictionary = _make_result(_is_dictionary_table(base_table), base_table)
	if base_rows_variant == null:
		_add_issue(report, "error", "invalid_base_table", null, "base_table 必须是 Array[Dictionary] 或 Dictionary。")
		_finalize_result(report)
		return report
	if patch_rows_variant == null:
		_add_issue(report, "error", "invalid_patch_table", null, "patch_table 必须是 Array[Dictionary] 或 Dictionary。")
		_finalize_result(report)
		return report

	var base_rows: Array[Dictionary] = _collect_row_entries(base_rows_variant)
	var patch_rows: Array[Dictionary] = _collect_row_entries(patch_rows_variant)
	var state: Dictionary = _build_base_state(base_rows, resolved_policy, report)
	_apply_patch_rows(state, patch_rows, resolved_policy, report)
	report["data"] = _build_output_data(state, GFVariantData.get_option_bool(report, "dictionary_output"), resolved_policy)
	_finalize_result(report)
	return report


# --- 私有/辅助方法 ---

static func _normalize_table(table_data: Variant) -> Variant:
	var rows: Array[Dictionary] = []
	if table_data is Array:
		var array_table: Array = table_data
		for index: int in range(array_table.size()):
			var row_variant: Variant = array_table[index]
			if not (row_variant is Dictionary):
				return null
			var row: Dictionary = row_variant
			rows.append({
				"outer_key": index,
				"record": row.duplicate(true),
			})
		return rows
	if table_data is Dictionary:
		var dictionary_table: Dictionary = table_data
		for key: Variant in dictionary_table.keys():
			var row_variant: Variant = dictionary_table[key]
			if not (row_variant is Dictionary):
				return null
			var row: Dictionary = row_variant
			rows.append({
				"outer_key": key,
				"record": row.duplicate(true),
			})
		return rows
	return null


static func _is_dictionary_table(table_data: Variant) -> bool:
	return table_data is Dictionary


static func _make_result(dictionary_output: bool, base_table: Variant) -> Dictionary:
	var result: Dictionary = _CONFIG_VALIDATION_REPORT.new().make_report()
	if dictionary_output:
		result["data"] = {}
	else:
		result["data"] = []
	result["dictionary_output"] = dictionary_output
	if base_table is Dictionary:
		var dictionary_table: Dictionary = base_table
		result["base_count"] = dictionary_table.size()
	elif base_table is Array:
		var array_table: Array = base_table
		result["base_count"] = array_table.size()
	else:
		result["base_count"] = 0
	result["inserted_count"] = 0
	result["updated_count"] = 0
	result["deleted_count"] = 0
	return result


static func _build_base_state(rows: Array[Dictionary], policy: GFConfigTableMergePolicy, report: Dictionary) -> Dictionary:
	var state: Dictionary = {
		"order": [],
		"records": {},
		"outer_keys": {},
	}
	var order: Array = _get_state_array(state, "order")
	var records: Dictionary = _get_state_dictionary(state, "records")
	var outer_keys: Dictionary = _get_state_dictionary(state, "outer_keys")
	for row_entry: Dictionary in rows:
		var record: Dictionary = _get_row_record(row_entry)
		var outer_key: Variant = _get_row_outer_key(row_entry)
		var key: String = policy.make_record_key(record, outer_key)
		if key.is_empty():
			_add_issue(report, "error", "missing_base_key", outer_key, "基础记录缺少合并键。")
			continue
		if records.has(key):
			_add_issue(report, "error", "duplicate_base_key", outer_key, "基础记录合并键重复。")
			continue
		order.append(key)
		records[key] = record
		outer_keys[key] = outer_key
	return state


static func _apply_patch_rows(
	state: Dictionary,
	rows: Array[Dictionary],
	policy: GFConfigTableMergePolicy,
	report: Dictionary
) -> void:
	var records: Dictionary = _get_state_dictionary(state, "records")
	for row_entry: Dictionary in rows:
		var record: Dictionary = _get_row_record(row_entry)
		var outer_key: Variant = _get_row_outer_key(row_entry)
		var key: String = policy.make_record_key(record, outer_key)
		if key.is_empty():
			_add_issue(report, "error", "missing_patch_key", outer_key, "补丁记录缺少合并键。")
			continue
		if policy.is_delete_record(record):
			_apply_delete(state, key, outer_key, policy, report)
		elif records.has(key):
			_apply_update(state, key, record, outer_key, policy, report)
		else:
			_apply_insert(state, key, record, outer_key, policy, report)


static func _apply_delete(
	state: Dictionary,
	key: String,
	row_key: Variant,
	policy: GFConfigTableMergePolicy,
	report: Dictionary
) -> void:
	if not policy.allow_delete:
		_add_issue(report, "error", "delete_not_allowed", row_key, "当前合并策略不允许删除记录。")
		return
	var records: Dictionary = _get_state_dictionary(state, "records")
	if not records.has(key):
		_add_issue(report, "warning", "delete_missing_record", row_key, "删除标记没有命中已有记录。")
		return
	var _record_removed: bool = records.erase(key)
	_increment_report_count(report, "deleted_count")


static func _apply_update(
	state: Dictionary,
	key: String,
	record: Dictionary,
	row_key: Variant,
	policy: GFConfigTableMergePolicy,
	report: Dictionary
) -> void:
	if not policy.allow_update:
		_add_issue(report, "error", "update_not_allowed", row_key, "当前合并策略不允许更新记录。")
		return
	var records: Dictionary = _get_state_dictionary(state, "records")
	records[key] = policy.merge_record(_get_record_by_key(records, key), record)
	_increment_report_count(report, "updated_count")


static func _apply_insert(
	state: Dictionary,
	key: String,
	record: Dictionary,
	row_key: Variant,
	policy: GFConfigTableMergePolicy,
	report: Dictionary
) -> void:
	if not policy.allow_insert:
		_add_issue(report, "error", "insert_not_allowed", row_key, "当前合并策略不允许插入记录。")
		return
	_get_state_dictionary(state, "records")[key] = record.duplicate(true)
	_get_state_dictionary(state, "outer_keys")[key] = row_key
	var order: Array = _get_state_array(state, "order")
	if not order.has(key):
		order.append(key)
	_increment_report_count(report, "inserted_count")


static func _build_output_data(state: Dictionary, dictionary_output: bool, policy: GFConfigTableMergePolicy) -> Variant:
	var records: Dictionary = _get_state_dictionary(state, "records")
	var order: Array = _get_state_array(state, "order")
	var outer_keys: Dictionary = _get_state_dictionary(state, "outer_keys")
	if dictionary_output:
		var dictionary_result: Dictionary = {}
		for key: String in _ordered_keys(order, records, policy.preserve_base_order):
			var outer_key: Variant = GFVariantData.get_option_value(outer_keys, key, key)
			dictionary_result[outer_key] = _get_record_by_key(records, key).duplicate(true)
		return dictionary_result

	var array_result: Array[Dictionary] = []
	for key: String in _ordered_keys(order, records, policy.preserve_base_order):
		array_result.append(_get_record_by_key(records, key).duplicate(true))
	return array_result


static func _ordered_keys(order: Array, records: Dictionary, preserve_base_order: bool) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if preserve_base_order:
		for key_variant: Variant in order:
			var key: String = GFVariantData.to_text(key_variant)
			if records.has(key):
				var _base_key_appended: bool = result.append(key)
		for key_variant: Variant in records.keys():
			var key: String = GFVariantData.to_text(key_variant)
			if not result.has(key):
				var _record_key_appended: bool = result.append(key)
	else:
		for key_variant: Variant in records.keys():
			var _key_appended: bool = result.append(GFVariantData.to_text(key_variant))
		result.sort()
	return result


static func _add_issue(report: Dictionary, severity: String, kind: String, row_key: Variant, message: String) -> void:
	_CONFIG_VALIDATION_REPORT.new().add_issue(report, severity, kind, &"", row_key, &"", message)


static func _finalize_result(report: Dictionary) -> void:
	_CONFIG_VALIDATION_REPORT.new().finalize_report(report)


static func _collect_row_entries(value: Variant) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if value is Array:
		var array_value: Array = GFVariantData.as_array(value)
		for row_variant: Variant in array_value:
			if row_variant is Dictionary:
				var row: Dictionary = GFVariantData.as_dictionary(row_variant)
				rows.append(row)
	return rows


static func _get_state_array(state: Dictionary, key: String) -> Array:
	var value: Variant = GFVariantData.get_option_value(state, key, [])
	if value is Array:
		return value
	var created: Array = []
	state[key] = created
	return created


static func _get_state_dictionary(state: Dictionary, key: String) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(state, key, {})
	if value is Dictionary:
		return value
	var created: Dictionary = {}
	state[key] = created
	return created


static func _get_row_record(row_entry: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(row_entry, "record", {}))


static func _get_row_outer_key(row_entry: Dictionary) -> Variant:
	return GFVariantData.get_option_value(row_entry, "outer_key")


static func _get_record_by_key(records: Dictionary, key: String) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(records, key, {}))


static func _increment_report_count(report: Dictionary, key: String) -> void:
	report[key] = GFVariantData.get_option_int(report, key) + 1
