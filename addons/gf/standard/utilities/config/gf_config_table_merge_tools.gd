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

## 创建配置表合并校验报告的类脚本引用。
## [br]
## @api private
## [br]
const _CONFIG_VALIDATION_REPORT = preload("res://addons/gf/standard/utilities/config/gf_config_validation_report.gd")


# --- 公共方法 ---

## 合并 base 表与 patch 表。
## [br]
## @api public
## [br]
## @since 3.17.0
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
## @param options: 新预算限额或已有批次预算。
## [br]
## @schema options: Dictionary，接受互斥的 work_limits 或 work_budget，语义见 GFConfigWorkBudget.from_options()。
## [br]
## @return 结果字典，包含 ok、data、issues 与统计信息。
## [br]
## @schema return: GFConfigValidationReport 兼容 Dictionary，额外包含 data、dictionary_output、base_count、inserted_count、updated_count、deleted_count、budget_report。任何失败的 data 均为 null；计数仅表示诊断期间已执行的操作。
static func merge_tables(
	base_table: Variant,
	patch_table: Variant,
	policy: GFConfigTableMergePolicy = null,
	options: Dictionary = {}
) -> Dictionary:
	var budget: GFConfigWorkBudget = GFConfigWorkBudget.from_options(options)
	var resolved_policy: GFConfigTableMergePolicy = policy if policy != null else GFConfigTableMergePolicy.new()
	var report: Dictionary = _make_result(
		_is_dictionary_table(base_table),
		base_table
	)
	if not budget.admit_value(base_table, "merge.base") or not budget.admit_value(patch_table, "merge.patch"):
		_finalize_result(report, budget)
		return report
	var base_rows_variant: Variant = _normalize_table(base_table, budget)
	var patch_rows_variant: Variant = _normalize_table(patch_table, budget)
	if not budget.is_ok():
		_finalize_result(report, budget)
		return report
	if base_rows_variant == null:
		_add_issue(
			report,
			"error",
			"invalid_base_table",
			null,
			"base_table 必须是 Array[Dictionary] 或 Dictionary。"
		)
		_finalize_result(report, budget)
		return report
	if patch_rows_variant == null:
		_add_issue(
			report,
			"error",
			"invalid_patch_table",
			null,
			"patch_table 必须是 Array[Dictionary] 或 Dictionary。"
		)
		_finalize_result(report, budget)
		return report

	var base_rows: Array[Dictionary] = base_rows_variant
	var patch_rows: Array[Dictionary] = patch_rows_variant
	var state: Dictionary = _build_base_state(
		base_rows,
		resolved_policy,
		report,
		budget
	)
	_finalize_result(report, budget)
	if not GFVariantData.get_option_bool(report, "ok"):
		return report
	_apply_patch_rows(
		state,
		patch_rows,
		resolved_policy,
		report,
		budget
	)
	_finalize_result(report, budget)
	if not GFVariantData.get_option_bool(report, "ok"):
		return report
	var output_data: Variant = _build_output_data(
		state,
		GFVariantData.get_option_bool(report, "dictionary_output"),
		resolved_policy,
		budget
	)
	if budget.admit_value(output_data, "merge.output"):
		report["data"] = GFVariantData.duplicate_variant(output_data)
	_finalize_result(report, budget)
	return report


# --- 私有/辅助方法 ---

## 将输入表数据规范化为记录条目数组。
## [br]
## @api private
## [br]
static func _normalize_table(table_data: Variant, budget: GFConfigWorkBudget) -> Variant:
	var rows: Array[Dictionary] = []
	if table_data is Array:
		var array_table: Array = table_data
		for index: int in range(array_table.size()):
			if not budget.consume_work(1, "merge.normalize_row"):
				return null
			var row_variant: Variant = array_table[index]
			if not (row_variant is Dictionary):
				return null
			var row: Dictionary = row_variant
			rows.append({ "outer_key": index, "record": row, })
		return rows
	if table_data is Dictionary:
		var dictionary_table: Dictionary = table_data
		for key: Variant in dictionary_table:
			if not budget.consume_work(1, "merge.normalize_row"):
				return null
			var row_variant: Variant = dictionary_table[key]
			if not (row_variant is Dictionary):
				return null
			var row: Dictionary = row_variant
			rows.append({ "outer_key": key, "record": row, })
		return rows
	return null


## 检查表数据是否为 Dictionary 形式。
## [br]
## @api private
## [br]
static func _is_dictionary_table(table_data: Variant) -> bool:
	return table_data is Dictionary


## 创建合并结果报告；完整成功前不公开结果数据。
## [br]
## @api private
## [br]
static func _make_result(dictionary_output: bool, base_table: Variant) -> Dictionary:
	var result: Dictionary = _CONFIG_VALIDATION_REPORT.new().make_report()
	result["data"] = null
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


## 从基础记录构造有序行状态，供后续 patch 操作使用。
## [br]
## @api private
## [br]
static func _build_base_state(
	rows: Array[Dictionary],
	policy: GFConfigTableMergePolicy,
	report: Dictionary,
	budget: GFConfigWorkBudget
) -> Dictionary:
	var state: Dictionary = {
		"order": [],
		"records": {},
		"outer_keys": {},
		"outer_key_owners": {},
	}
	var order: Array = _get_state_array(state, "order")
	var records: Dictionary = _get_state_dictionary(state, "records")
	var outer_keys: Dictionary = _get_state_dictionary(state, "outer_keys")
	for row_entry: Dictionary in rows:
		if not budget.consume_work(1, "merge.base_row"):
			break
		var record: Dictionary = _get_row_record(row_entry)
		var outer_key: Variant = _get_row_outer_key(row_entry)
		var key: String = policy.make_record_key(
			record,
			outer_key,
			{ "work_budget": budget }
		)
		if not budget.is_ok():
			break
		if key.is_empty():
			_add_issue(
				report,
				"error",
				"missing_base_key",
				outer_key,
				"基础记录缺少合并键。"
			)
			continue
		if records.has(key):
			_add_issue(
				report,
				"error",
				"duplicate_base_key",
				outer_key,
				"基础记录合并键重复。"
			)
			continue
		order.append(key)
		records[key] = record
		outer_keys[key] = outer_key
		_get_state_dictionary(state, "outer_key_owners")[outer_key] = key
	return state


## 按顺序将 patch 行操作应用到合并状态。
## [br]
## @api private
## [br]
static func _apply_patch_rows(
	state: Dictionary,
	rows: Array[Dictionary],
	policy: GFConfigTableMergePolicy,
	report: Dictionary,
	budget: GFConfigWorkBudget
) -> void:
	var records: Dictionary = _get_state_dictionary(state, "records")
	for row_entry: Dictionary in rows:
		if not budget.consume_work(1, "merge.patch_row"):
			break
		var record: Dictionary = _get_row_record(row_entry)
		var outer_key: Variant = _get_row_outer_key(row_entry)
		var key: String = policy.make_record_key(
			record,
			outer_key,
			{ "work_budget": budget }
		)
		if not budget.is_ok():
			break
		if key.is_empty():
			_add_issue(
				report,
				"error",
				"missing_patch_key",
				outer_key,
				"补丁记录缺少合并键。"
			)
			continue
		var is_delete: bool = policy.is_delete_record(
			record,
			{ "work_budget": budget }
		)
		if not budget.is_ok():
			break
		if is_delete:
			_apply_delete(
				state,
				key,
				outer_key,
				policy,
				report
			)
		elif records.has(key):
			_apply_update(
				state,
				key,
				record,
				outer_key,
				policy,
				report,
				budget
			)
		else:
			_apply_insert(
				state,
				key,
				record,
				outer_key,
				policy,
				report
			)


## 从合并状态删除匹配的记录。
## [br]
## @api private
## [br]
static func _apply_delete(
	state: Dictionary,
	key: String,
	row_key: Variant,
	policy: GFConfigTableMergePolicy,
	report: Dictionary
) -> void:
	if not policy.allow_delete:
		_add_issue(
			report,
			"error",
			"delete_not_allowed",
			row_key,
			"当前合并策略不允许删除记录。"
		)
		return
	var records: Dictionary = _get_state_dictionary(state, "records")
	if not records.has(key):
		_add_issue(
			report,
			"warning",
			"delete_missing_record",
			row_key,
			"删除标记没有命中已有记录。"
		)
		return
	var _record_removed: bool = records.erase(key)
	_increment_report_count(report, "deleted_count")


## 将 patch 字段合并到已存在的目标记录。
## [br]
## @api private
## [br]
static func _apply_update(
	state: Dictionary,
	key: String,
	record: Dictionary,
	row_key: Variant,
	policy: GFConfigTableMergePolicy,
	report: Dictionary,
	budget: GFConfigWorkBudget
) -> void:
	if not policy.allow_update:
		_add_issue(
			report,
			"error",
			"update_not_allowed",
			row_key,
			"当前合并策略不允许更新记录。"
		)
		return
	var records: Dictionary = _get_state_dictionary(state, "records")
	var merged: Dictionary = policy.merge_record(
		_get_record_by_key(records, key),
		record,
		{ "work_budget": budget }
	)
	if not budget.is_ok():
		return
	if not GFVariantData.get_option_bool(merged, "ok"):
		var kind: String = GFVariantData.get_option_string(merged, "error_kind")
		var message: String = GFVariantData.get_option_string(merged, "error")
		_add_issue(
			report,
			"error",
			"merge_record_failed" if kind.is_empty() else kind,
			row_key,
			"合并策略拒绝更新记录。" if message.is_empty() else message,
			{ "source": GFVariantData.get_option_string(merged, "context") }
		)
		return
	var merged_data: Variant = GFVariantData.get_option_value(merged, "data")
	if not (merged_data is Dictionary):
		_add_issue(
			report,
			"error",
			"invalid_merge_record_result",
			row_key,
			"合并策略成功报告的 data 必须是 Dictionary。",
			{ "source": GFVariantData.get_option_string(merged, "context") }
		)
		return
	records[key] = merged_data
	_increment_report_count(report, "updated_count")


## 将新记录加入合并状态。
## [br]
## @api private
## [br]
static func _apply_insert(
	state: Dictionary,
	key: String,
	record: Dictionary,
	row_key: Variant,
	policy: GFConfigTableMergePolicy,
	report: Dictionary
) -> void:
	if not policy.allow_insert:
		_add_issue(
			report,
			"error",
			"insert_not_allowed",
			row_key,
			"当前合并策略不允许插入记录。"
		)
		return
	var outer_key_owners: Dictionary = _get_state_dictionary(state, "outer_key_owners")
	if GFVariantData.get_option_bool(report, "dictionary_output") and outer_key_owners.has(row_key):
		var existing_key: Variant = outer_key_owners[row_key]
		if _get_state_dictionary(state, "records").has(existing_key):
			_add_issue(
				report,
				"error",
				"outer_key_collision",
				row_key,
				"外层键已属于另一条逻辑记录。"
			)
			return
	var order: Array = _get_state_array(state, "order")
	if not _get_state_dictionary(state, "outer_keys").has(key):
		order.append(key)
	_get_state_dictionary(state, "records")[key] = record
	_get_state_dictionary(state, "outer_keys")[key] = row_key
	outer_key_owners[row_key] = key
	_increment_report_count(report, "inserted_count")


## 按合并状态和输出表形状组装最终数据。
## [br]
## @api private
## [br]
static func _build_output_data(
	state: Dictionary,
	dictionary_output: bool,
	policy: GFConfigTableMergePolicy,
	budget: GFConfigWorkBudget
) -> Variant:
	var records: Dictionary = _get_state_dictionary(state, "records")
	var order: Array = _get_state_array(state, "order")
	var outer_keys: Dictionary = _get_state_dictionary(state, "outer_keys")
	var ordered_keys: PackedStringArray = _ordered_keys(
		order,
		records,
		policy.preserve_base_order,
		budget
	)
	if not budget.is_ok():
		return null
	if dictionary_output:
		var dictionary_result: Dictionary = {}
		for key: String in ordered_keys:
			if not budget.consume_work(1, "merge.output_row"):
				return null
			var outer_key: Variant = GFVariantData.get_option_value(
				outer_keys,
				key,
				key
			)
			dictionary_result[outer_key] = _get_record_by_key(records, key)
		return dictionary_result

	var array_result: Array[Dictionary] = []
	for key: String in ordered_keys:
		if not budget.consume_work(1, "merge.output_row"):
			return null
		array_result.append(_get_record_by_key(records, key))
	return array_result


## 按配置保留基础键顺序或输出排序后的记录键。
## [br]
## @api private
## [br]
static func _ordered_keys(
	order: Array,
	records: Dictionary,
	preserve_base_order: bool,
	budget: GFConfigWorkBudget
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var included: Dictionary = {}
	if preserve_base_order:
		for key_variant: Variant in order:
			if not budget.consume_work(1, "merge.output_order"):
				return PackedStringArray()
			var key: String = GFVariantData.to_text(key_variant)
			if records.has(key) and not included.has(key):
				var _base_key_appended: bool = result.append(key)
				included[key] = true
		for key_variant: Variant in records:
			if not budget.consume_work(1, "merge.output_order"):
				return PackedStringArray()
			var key: String = GFVariantData.to_text(key_variant)
			if not included.has(key):
				var _record_key_appended: bool = result.append(key)
	else:
		var sort_work: int = records.size()
		if records.size() > 1:
			sort_work *= ceili(log(float(records.size())) / log(2.0))
		if not budget.consume_work(sort_work, "merge.output_sort"):
			return PackedStringArray()
		for key_variant: Variant in records:
			var _key_appended: bool = result.append(GFVariantData.to_text(key_variant))
		result.sort()
	return result


## 将一条行级问题追加到合并报告。
## [br]
## @api private
## [br]
static func _add_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	row_key: Variant,
	message: String,
	context: Dictionary = {}
) -> void:
	_CONFIG_VALIDATION_REPORT.new().add_issue(
		report,
		severity,
		kind,
		&"",
		row_key,
		&"",
		message,
		context
	)


## 完成合并报告的计数与汇总字段。
## [br]
## @api private
## [br]
static func _finalize_result(report: Dictionary, budget: GFConfigWorkBudget) -> void:
	var budget_report: Dictionary = budget.get_report()
	report["budget_report"] = budget_report
	if not budget.is_ok():
		var error_kind: String = budget_report["error_kind"]
		var error_message: String = budget_report["error"]
		_add_issue(
			report,
			"error",
			error_kind,
			null,
			error_message
		)
	_CONFIG_VALIDATION_REPORT.new().finalize_report(report)
	if not GFVariantData.get_option_bool(report, "ok"):
		report["data"] = null


## 从合并状态中读取数组字段。
## [br]
## @api private
## [br]
static func _get_state_array(state: Dictionary, key: String) -> Array:
	var value: Variant = GFVariantData.get_option_value(
		state,
		key,
		[]
	)
	if value is Array:
		return value
	var created: Array = []
	state[key] = created
	return created


## 从合并状态中读取字典字段。
## [br]
## @api private
## [br]
static func _get_state_dictionary(state: Dictionary, key: String) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(
		state,
		key,
		{}
	)
	if value is Dictionary:
		return value
	var created: Dictionary = {}
	state[key] = created
	return created


## 从标准化行条目读取记录字典。
## [br]
## @api private
## [br]
static func _get_row_record(row_entry: Dictionary) -> Dictionary:
	return GFVariantData.as_dictionary(
		GFVariantData.get_option_value(
			row_entry,
			"record",
			{}
		)
	)


## 从标准化行条目读取字典表外层键。
## [br]
## @api private
## [br]
static func _get_row_outer_key(row_entry: Dictionary) -> Variant:
	return GFVariantData.get_option_value(row_entry, "outer_key")


## 按内部行键从记录映射读取记录字典。
## [br]
## @api private
## [br]
static func _get_record_by_key(records: Dictionary, key: String) -> Dictionary:
	return GFVariantData.as_dictionary(
		GFVariantData.get_option_value(
			records,
			key,
			{}
		)
	)


## 将报告中的指定计数增加一。
## [br]
## @api private
## [br]
static func _increment_report_count(report: Dictionary, key: String) -> void:
	report[key] = GFVariantData.get_option_int(report, key) + 1
