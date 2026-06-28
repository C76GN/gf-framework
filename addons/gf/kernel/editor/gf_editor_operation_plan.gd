@tool

## GFEditorOperationPlan: 编辑器工具操作计划报告。
##
## 用于把预览、dry-run、执行步骤和产物报告统一成可展示、可测试的结构化结果。
## 它只描述编辑器操作计划和结果，不直接修改节点、资源或文件。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 7.0.0
## [br]
## @layer kernel/editor
class_name GFEditorOperationPlan
extends RefCounted


# --- 常量 ---

## 步骤已计划但尚未执行。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_PLANNED: StringName = &"planned"

## 步骤已预览。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_PREVIEWED: StringName = &"previewed"

## 步骤已应用。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_APPLIED: StringName = &"applied"

## 步骤已跳过。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_SKIPPED: StringName = &"skipped"

## 步骤失败。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_FAILED: StringName = &"failed"

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_GENERATED_ARTIFACT_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")


# --- 公共变量 ---

## 操作稳定标识。
## [br]
## @api public
## [br]
## @since 7.0.0
var operation_id: StringName = &""

## 操作显示名称。
## [br]
## @api public
## [br]
## @since 7.0.0
var label: String = ""

## 是否为 dry-run 预览。
## [br]
## @api public
## [br]
## @since 7.0.0
var dry_run: bool = false

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary for caller-defined editor operation metadata.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _steps: Array[Dictionary] = []
var _artifact_reports: Array[Dictionary] = []


# --- 公共方法 ---

## 配置操作计划。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_operation_id: 操作稳定标识。
## [br]
## @param p_label: 操作显示名称。
## [br]
## @param p_dry_run: 是否为 dry-run。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary copied into metadata.
## [br]
## @return 当前计划。
func configure(
	p_operation_id: StringName,
	p_label: String = "",
	p_dry_run: bool = false,
	p_metadata: Dictionary = {}
) -> GFEditorOperationPlan:
	operation_id = p_operation_id
	label = p_label
	dry_run = p_dry_run
	metadata = p_metadata.duplicate(true)
	return self


## 添加一个操作步骤。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param step_id: 步骤稳定标识。
## [br]
## @param step_label: 步骤显示名称。
## [br]
## @param options: 步骤选项。
## [br]
## @schema options: Dictionary，可包含 status、target、kind、metadata、error_code 和 error。
## [br]
## @return 步骤记录副本。
## [br]
## @schema return: Dictionary，包含 step_id、label、status、target、kind、error_code、error 和 metadata。
func add_step(step_id: StringName, step_label: String = "", options: Dictionary = {}) -> Dictionary:
	var step: Dictionary = {
		"step_id": step_id,
		"label": step_label,
		"status": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "status", STATUS_PLANNED),
		"target": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "target"),
		"kind": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "kind", &""),
		"error_code": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "error_code", OK),
		"error": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "error"),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata").duplicate(true),
	}
	_steps.append(step)
	return step.duplicate(true)


## 标记一个步骤状态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param step_id: 步骤稳定标识。
## [br]
## @param status: 新状态。
## [br]
## @param error_code: Godot Error 错误码。
## [br]
## @param error: 错误说明。
## [br]
## @param extra_metadata: 要合并到步骤 metadata 的额外元数据。
## [br]
## @schema extra_metadata: Dictionary merged into step metadata.
## [br]
## @return 找到并更新时返回 true。
func mark_step(
	step_id: StringName,
	status: StringName,
	error_code: Error = OK,
	error: String = "",
	extra_metadata: Dictionary = {}
) -> bool:
	for index: int in range(_steps.size()):
		var step: Dictionary = _steps[index]
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(step, "step_id") != step_id:
			continue
		step["status"] = status
		step["error_code"] = error_code
		step["error"] = error
		var step_metadata: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(step, "metadata")
		var _merged_metadata: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(step_metadata, extra_metadata, true, true)
		step["metadata"] = step_metadata
		_steps[index] = step
		return true
	return false


## 添加生成产物报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param report: GFGeneratedArtifactReport 兼容报告。
## [br]
## @schema report: Dictionary，包含 status、path、error_code、dry_run 等字段。
func add_artifact_report(report: Dictionary) -> void:
	_artifact_reports.append(report.duplicate(true))


## 获取步骤记录副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 步骤数组。
## [br]
## @schema return: Array[Dictionary]，每个元素是 add_step() 返回结构。
func get_steps() -> Array[Dictionary]:
	return _duplicate_dictionary_array(_steps)


## 获取产物报告副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 产物报告数组。
## [br]
## @schema return: Array[Dictionary]，每个元素是 GFGeneratedArtifactReport 兼容报告。
func get_artifact_reports() -> Array[Dictionary]:
	return _duplicate_dictionary_array(_artifact_reports)


## 清空步骤和产物报告。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_steps.clear()
	_artifact_reports.clear()


## 汇总操作计划。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 汇总选项，支持 include_steps、include_artifacts 和 metadata。
## [br]
## @schema options: Dictionary，可包含 include_steps、include_artifacts 和 metadata。
## [br]
## @return 操作摘要。
## [br]
## @schema return: Dictionary，包含 success、operation_id、label、dry_run、step_count、status_counts、failed_count、skipped_count、artifact_summary 和 metadata。
func summarize(options: Dictionary = {}) -> Dictionary:
	var status_counts: Dictionary = {}
	var failed_count: int = 0
	var skipped_count: int = 0
	for step: Dictionary in _steps:
		var status: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(step, "status", STATUS_PLANNED)
		var status_key: String = String(status)
		status_counts[status_key] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(status_counts, status_key, 0) + 1
		if status == STATUS_FAILED:
			failed_count += 1
		elif status == STATUS_SKIPPED:
			skipped_count += 1

	var artifact_summary: Dictionary = _GF_GENERATED_ARTIFACT_REPORT_SCRIPT.summarize_reports(
		_artifact_reports,
		label,
		{ "include_reports": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_artifacts", false) }
	)
	var extra_metadata: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata")
	var summary_metadata: Dictionary = metadata.duplicate(true)
	var _merged_summary_metadata: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(summary_metadata, extra_metadata, true, true)
	var result: Dictionary = {
		"success": failed_count == 0 and _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(artifact_summary, "success", true),
		"operation_id": operation_id,
		"label": label,
		"dry_run": dry_run,
		"step_count": _steps.size(),
		"status_counts": _sort_dictionary_by_key(status_counts),
		"failed_count": failed_count,
		"skipped_count": skipped_count,
		"artifact_summary": artifact_summary,
		"metadata": summary_metadata,
	}
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_steps", false):
		result["steps"] = get_steps()
	return result


# --- 私有/辅助方法 ---

func _duplicate_dictionary_array(values: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Dictionary in values:
		result.append(value.duplicate(true))
	return result


func _sort_dictionary_by_key(data: Dictionary) -> Dictionary:
	var keys: PackedStringArray = PackedStringArray()
	for raw_key: Variant in data.keys():
		var _append_key: bool = keys.append(_GF_VARIANT_ACCESS_SCRIPT.to_text(raw_key))
	keys.sort()
	var result: Dictionary = {}
	for key: String in keys:
		result[key] = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(data.get(key), true)
	return result
