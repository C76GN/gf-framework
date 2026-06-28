## GFImportPlan: 通用导入计划与预检报告。
##
## 描述一组来源到目标的导入、复制或转换条目，并提供 source trace、预检和修复动作报告。
## 该类不执行文件复制或格式转换，具体导入器可把它作为编辑器工具和 CI 的共享计划格式。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 6.0.0
class_name GFImportPlan
extends Resource


# --- 常量 ---

## 复制来源文件。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_COPY: StringName = &"copy"

## 转换来源文件。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_CONVERT: StringName = &"convert"

## 跳过来源文件。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPERATION_SKIP: StringName = &"skip"

const _REPORT_SUBJECT: String = "Import plan"


# --- 导出变量 ---

## 导入条目列表。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema entries: Array[Dictionary] where each entry contains source_path, target_path, operation, source_trace, repair_actions, and metadata.
@export var entries: Array[Dictionary] = []

## 调用方附加元数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary for caller-defined import plan metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 添加导入条目。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param source_path: 来源路径。
## [br]
## @param target_path: 目标路径。
## [br]
## @param operation: 导入操作。
## [br]
## @param options: 条目选项。
## [br]
## @schema options: Dictionary，可包含 source_format、target_format、type_hint、source_trace、repair_actions 和 metadata。
## [br]
## @return 当前计划。
func add_entry(
	source_path: String,
	target_path: String,
	operation: StringName = OPERATION_COPY,
	options: Dictionary = {}
) -> GFImportPlan:
	entries.append(_make_entry(source_path, target_path, operation, options))
	return self


## 清空导入条目。
## [br]
## @api public
## [br]
## @since 6.0.0
func clear() -> void:
	entries.clear()


## 获取条目副本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 条目副本。
## [br]
## @schema return: Array[Dictionary] import plan entries.
func get_entries() -> Array[Dictionary]:
	return _copy_entries(entries)


## 获取 source trace 列表。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return source trace 字典数组。
## [br]
## @schema return: Array[Dictionary] where each trace contains source_path, target_path, operation, source_format, target_format, and metadata.
func get_source_traces() -> Array[Dictionary]:
	var traces: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var trace: Dictionary = GFVariantData.get_option_dictionary(entry, "source_trace")
		trace["source_path"] = GFVariantData.get_option_string(entry, "source_path")
		trace["target_path"] = GFVariantData.get_option_string(entry, "target_path")
		trace["operation"] = GFVariantData.get_option_string_name(entry, "operation")
		trace["source_format"] = GFVariantData.get_option_string(entry, "source_format")
		trace["target_format"] = GFVariantData.get_option_string(entry, "target_format")
		traces.append(trace)
	return traces


## 生成导入预检报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param options: 预检选项。
## [br]
## @schema options: Dictionary，可包含 check_source_exists、target_root、allow_empty_target、check_duplicate_targets 和 include_skip_targets。
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() output with entry_count, source_traces, and operation_summary.
func get_validation_report(options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"subject": _REPORT_SUBJECT,
		"entry_count": entries.size(),
		"source_traces": get_source_traces(),
		"operation_summary": get_operation_summary(),
		"issues": [],
	}
	for index: int in range(entries.size()):
		_validate_entry(entries[index], index, options, report)
	if GFVariantData.get_option_bool(options, "check_duplicate_targets", true):
		_validate_duplicate_targets(options, report)
	return GFValidationReportDictionary.finalize_report(report, _REPORT_SUBJECT, {
		"fallback_action": "Review the first import plan issue.",
		"no_action": "Import plan is valid.",
	})


## 生成导入计划摘要。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param options: 摘要选项，include_skip_targets=true 时把 skip 条目纳入重复目标统计。
## [br]
## @schema options: Dictionary import plan summary options.
## [br]
## @return 摘要字典。
## [br]
## @schema return: Dictionary with entry_count, actionable_entry_count, skipped_entry_count, counts_by_operation, counts_by_source_format, counts_by_target_format, missing_target_count, duplicate_targets, and metadata.
func get_operation_summary(options: Dictionary = {}) -> Dictionary:
	var counts_by_operation: Dictionary = {}
	var counts_by_source_format: Dictionary = {}
	var counts_by_target_format: Dictionary = {}
	var target_entries: Dictionary = {}
	var actionable_entry_count: int = 0
	var skipped_entry_count: int = 0
	var missing_target_count: int = 0
	var include_skip_targets: bool = GFVariantData.get_option_bool(options, "include_skip_targets", false)

	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var operation: StringName = GFVariantData.get_option_string_name(entry, "operation")
		var operation_key: String = _summary_key(String(operation))
		var source_format_key: String = _summary_key(GFVariantData.get_option_string(entry, "source_format"))
		var target_format_key: String = _summary_key(GFVariantData.get_option_string(entry, "target_format"))
		var target_path: String = GFVariantData.get_option_string(entry, "target_path")
		_increment_count(counts_by_operation, operation_key)
		_increment_count(counts_by_source_format, source_format_key)
		_increment_count(counts_by_target_format, target_format_key)
		if operation == OPERATION_SKIP:
			skipped_entry_count += 1
		else:
			actionable_entry_count += 1
		if target_path.is_empty():
			missing_target_count += 1
		if target_path.is_empty() or (operation == OPERATION_SKIP and not include_skip_targets):
			continue
		_add_target_entry_index(target_entries, target_path, index)

	return {
		"entry_count": entries.size(),
		"actionable_entry_count": actionable_entry_count,
		"skipped_entry_count": skipped_entry_count,
		"missing_target_count": missing_target_count,
		"counts_by_operation": counts_by_operation,
		"counts_by_source_format": counts_by_source_format,
		"counts_by_target_format": counts_by_target_format,
		"duplicate_targets": _collect_duplicate_targets(target_entries),
		"metadata": metadata.duplicate(true),
	}


## 生成修复动作报告，不执行修复。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 修复动作报告。
## [br]
## @schema return: Dictionary with action_count, actions, source_traces, and metadata.
func get_repair_report() -> Dictionary:
	var actions: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var source_path: String = GFVariantData.get_option_string(entry, "source_path")
		var target_path: String = GFVariantData.get_option_string(entry, "target_path")
		for action_value: Variant in GFVariantData.get_option_array(entry, "repair_actions"):
			var action: Dictionary = GFVariantData.as_dictionary(action_value).duplicate(true)
			action["source_path"] = source_path
			action["target_path"] = target_path
			actions.append(action)
	return {
		"action_count": actions.size(),
		"actions": actions,
		"source_traces": get_source_traces(),
		"metadata": metadata.duplicate(true),
	}


## 转换为可序列化字典。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 导入计划字典。
## [br]
## @schema return: Dictionary with entries and metadata.
func to_dict() -> Dictionary:
	return {
		"entries": _copy_entries(entries),
		"metadata": metadata.duplicate(true),
	}


## 应用字典数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param data: 导入计划字典。
## [br]
## @schema data: Dictionary with entries and metadata.
func apply_dict(data: Dictionary) -> void:
	entries = _copy_entries(_get_entry_array(data))
	metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 从字典创建导入计划。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param data: 导入计划字典。
## [br]
## @schema data: Dictionary with entries and metadata.
## [br]
## @return 新导入计划。
static func from_dict(data: Dictionary) -> GFImportPlan:
	var plan: GFImportPlan = GFImportPlan.new()
	plan.apply_dict(data)
	return plan


# --- 私有/辅助方法 ---

static func _make_entry(
	source_path: String,
	target_path: String,
	operation: StringName,
	options: Dictionary
) -> Dictionary:
	var source_trace: Dictionary = GFVariantData.get_option_dictionary(options, "source_trace")
	var entry: Dictionary = {
		"source_path": source_path.strip_edges(),
		"target_path": target_path.strip_edges(),
		"operation": operation,
		"source_format": GFVariantData.get_option_string(options, "source_format"),
		"target_format": GFVariantData.get_option_string(options, "target_format"),
		"type_hint": GFVariantData.get_option_string(options, "type_hint"),
		"source_trace": source_trace,
		"repair_actions": GFVariantData.get_option_array(options, "repair_actions"),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}
	return entry


func _validate_entry(entry: Dictionary, index: int, options: Dictionary, report: Dictionary) -> void:
	var source_path: String = GFVariantData.get_option_string(entry, "source_path")
	var target_path: String = GFVariantData.get_option_string(entry, "target_path")
	var operation: StringName = GFVariantData.get_option_string_name(entry, "operation")
	if source_path.is_empty():
		_append_entry_issue(report, index, &"missing_source_path", "source_path is required", &"source_path")
	if target_path.is_empty() and not GFVariantData.get_option_bool(options, "allow_empty_target", false):
		_append_entry_issue(report, index, &"missing_target_path", "target_path is required", &"target_path")
	if not _is_supported_operation(operation):
		_append_entry_issue(report, index, &"unsupported_operation", "operation is not supported", &"operation", {
			"actual_value": operation,
			"expected_value": PackedStringArray([String(OPERATION_COPY), String(OPERATION_CONVERT), String(OPERATION_SKIP)]),
		})
	if (
		GFVariantData.get_option_bool(options, "check_source_exists", false)
		and not source_path.is_empty()
		and not FileAccess.file_exists(source_path)
	):
		_append_entry_issue(report, index, &"missing_source_file", "source file does not exist", &"source_path", {
			"actual_value": source_path,
		})
	var target_root: String = GFVariantData.get_option_string(options, "target_root")
	if not target_root.is_empty() and not target_path.is_empty() and not GFPathTools.is_path_under_root(target_path, target_root, true, false):
		_append_entry_issue(report, index, &"target_outside_root", "target_path must stay inside target_root", &"target_path", {
			"actual_value": target_path,
			"expected_value": target_root,
		})


func _validate_duplicate_targets(options: Dictionary, report: Dictionary) -> void:
	var include_skip_targets: bool = GFVariantData.get_option_bool(options, "include_skip_targets", false)
	var target_entries: Dictionary = {}
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var target_path: String = GFVariantData.get_option_string(entry, "target_path")
		var operation: StringName = GFVariantData.get_option_string_name(entry, "operation")
		if target_path.is_empty() or (operation == OPERATION_SKIP and not include_skip_targets):
			continue
		_add_target_entry_index(target_entries, target_path, index)

	for duplicate_target_value: Variant in _collect_duplicate_targets(target_entries):
		var duplicate_target: Dictionary = GFVariantData.as_dictionary(duplicate_target_value)
		var target_path: String = GFVariantData.get_option_string(duplicate_target, "target_path")
		var entry_indexes: Array = GFVariantData.get_option_array(duplicate_target, "entry_indexes")
		for entry_index_value: Variant in entry_indexes:
			var entry_index: int = GFVariantData.to_int(entry_index_value, -1)
			if entry_index < 0:
				continue
			_append_entry_issue(report, entry_index, &"duplicate_target_path", "target_path is used by multiple import entries", &"target_path", {
				"actual_value": target_path,
				"entry_indexes": entry_indexes.duplicate(true),
			})


func _append_entry_issue(
	report: Dictionary,
	index: int,
	kind: StringName,
	message: String,
	field_name: StringName,
	context: Dictionary = {}
) -> void:
	var issue_context: Dictionary = {
		"row_index": index,
		"field": field_name,
		"path": "entries[%d].%s" % [index, String(field_name)],
	}
	var merged_context: Dictionary = GFVariantData.merge_dictionary(issue_context, context, true)
	var _issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		"error",
		kind,
		message,
		merged_context
	)


static func _is_supported_operation(operation: StringName) -> bool:
	return operation == OPERATION_COPY or operation == OPERATION_CONVERT or operation == OPERATION_SKIP


static func _increment_count(counts: Dictionary, key: String) -> void:
	counts[key] = GFVariantData.get_option_int(counts, key, 0) + 1


static func _summary_key(value: String) -> String:
	return value if not value.is_empty() else "unknown"


static func _add_target_entry_index(target_entries: Dictionary, target_path: String, entry_index: int) -> void:
	if not target_entries.has(target_path):
		target_entries[target_path] = []
	var indexes: Array = GFVariantData.get_option_array(target_entries, target_path)
	indexes.append(entry_index)
	target_entries[target_path] = indexes


static func _collect_duplicate_targets(target_entries: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for target_path_variant: Variant in target_entries.keys():
		var target_path: String = GFVariantData.to_text(target_path_variant)
		var indexes: Array = GFVariantData.get_option_array(target_entries, target_path)
		if indexes.size() < 2:
			continue
		result.append({
			"target_path": target_path,
			"entry_count": indexes.size(),
			"entry_indexes": indexes.duplicate(true),
		})
	return result


static func _copy_entries(source_entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in source_entries:
		result.append(entry.duplicate(true))
	return result


static func _get_entry_array(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in GFVariantData.get_option_array(data, "entries"):
		if value is Dictionary:
			var entry: Dictionary = value
			result.append(entry.duplicate(true))
	return result
