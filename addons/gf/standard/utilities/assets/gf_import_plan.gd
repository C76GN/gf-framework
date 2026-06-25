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
## @schema options: Dictionary，可包含 check_source_exists、target_root 和 allow_empty_target。
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() output with entry_count and source_traces.
func get_validation_report(options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = {
		"subject": _REPORT_SUBJECT,
		"entry_count": entries.size(),
		"source_traces": get_source_traces(),
		"issues": [],
	}
	for index: int in range(entries.size()):
		_validate_entry(entries[index], index, options, report)
	return GFValidationReportDictionary.finalize_report(report, _REPORT_SUBJECT, {
		"fallback_action": "Review the first import plan issue.",
		"no_action": "Import plan is valid.",
	})


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
