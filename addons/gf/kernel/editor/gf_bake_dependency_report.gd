@tool

## GFBakeDependencyReport: 编辑器烘焙依赖与失效报告。
##
## 用于编辑器工具、导入流程或项目构建脚本记录输入、输出、依赖项和失效原因。
## 它只生成结构化诊断报告，不执行烘焙、不规定项目目录，也不写入任何资源。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 7.0.0
## [br]
## @layer kernel/editor
class_name GFBakeDependencyReport
extends RefCounted


# --- 常量 ---

## 依赖当前有效。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_CURRENT: StringName = &"current"

## 依赖或输出需要重建。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_STALE: StringName = &"stale"

## 必需输入或输出缺失。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_MISSING: StringName = &"missing"

## 依赖分析或产物处理失败。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_FAILED: StringName = &"failed"

## 没有足够信息判断状态。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_UNKNOWN: StringName = &"unknown"

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_GENERATED_ARTIFACT_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")


# --- 公共变量 ---

## 报告稳定标识。
## [br]
## @api public
## [br]
## @since 7.0.0
var report_id: StringName = &""

## 报告显示名称。
## [br]
## @api public
## [br]
## @since 7.0.0
var label: String = ""

## 调用方元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary for caller-defined bake metadata.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _inputs: Array[Dictionary] = []
var _outputs: Array[Dictionary] = []
var _dependencies: Array[Dictionary] = []
var _invalidations: Array[Dictionary] = []
var _artifact_reports: Array[Dictionary] = []


# --- 公共方法 ---

## 配置报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_report_id: 报告稳定标识。
## [br]
## @param p_label: 显示名称。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary copied into metadata.
## [br]
## @return 当前报告。
func configure(
	p_report_id: StringName,
	p_label: String = "",
	p_metadata: Dictionary = {}
) -> GFBakeDependencyReport:
	report_id = p_report_id
	label = p_label
	metadata = p_metadata.duplicate(true)
	return self


## 添加一个输入资源或文件记录。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param path: 输入路径或稳定资源标识。
## [br]
## @param options: 输入选项，支持 dependency_id、exists、required、status、content_sha256、modified_time、check_filesystem 和 metadata。
## [br]
## @schema options: Dictionary，可包含 dependency_id、exists、required、status、content_sha256、modified_time、check_filesystem 和 metadata。
## [br]
## @return 输入记录副本。
## [br]
## @schema return: Dictionary，包含 path、dependency_id、exists、required、status、content_sha256、modified_time 和 metadata。
func add_input(path: String, options: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = _make_path_entry(path, options, true)
	_inputs.append(entry)
	return entry.duplicate(true)


## 添加一个输出产物记录。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param path: 输出路径或稳定产物标识。
## [br]
## @param options: 输出选项，支持 dependency_id、exists、required、status、content_sha256、modified_time、check_filesystem 和 metadata。
## [br]
## @schema options: Dictionary，可包含 dependency_id、exists、required、status、content_sha256、modified_time、check_filesystem 和 metadata。
## [br]
## @return 输出记录副本。
## [br]
## @schema return: Dictionary，包含 path、dependency_id、exists、required、status、content_sha256、modified_time 和 metadata。
func add_output(path: String, options: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = _make_path_entry(path, options, true)
	_outputs.append(entry)
	return entry.duplicate(true)


## 添加一个逻辑依赖项记录。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param dependency_id: 依赖稳定标识。
## [br]
## @param options: 依赖选项，支持 status、version、content_sha256、error 和 metadata。
## [br]
## @schema options: Dictionary，可包含 status、version、content_sha256、error 和 metadata。
## [br]
## @return 依赖记录副本。
## [br]
## @schema return: Dictionary，包含 dependency_id、status、version、content_sha256、error 和 metadata。
func add_dependency(dependency_id: StringName, options: Dictionary = {}) -> Dictionary:
	if dependency_id == &"":
		return {}

	var dependency: Dictionary = {
		"dependency_id": dependency_id,
		"status": _normalize_status(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "status", STATUS_CURRENT)),
		"version": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "version"),
		"content_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "content_sha256"),
		"error": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "error"),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata").duplicate(true),
	}
	_dependencies.append(dependency)
	return dependency.duplicate(true)


## 记录一个失效原因。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 失效原因。
## [br]
## @param options: 失效选项，支持 path、dependency_id、severity 和 metadata。
## [br]
## @schema options: Dictionary，可包含 path、dependency_id、severity 和 metadata。
## [br]
## @return 失效记录副本。
## [br]
## @schema return: Dictionary，包含 reason、path、dependency_id、severity、timestamp_msec 和 metadata。
func mark_stale(reason: String, options: Dictionary = {}) -> Dictionary:
	var invalidation: Dictionary = {
		"reason": reason,
		"path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "path"),
		"dependency_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "dependency_id"),
		"severity": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "severity", STATUS_STALE),
		"timestamp_msec": Time.get_ticks_msec(),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata").duplicate(true),
	}
	_invalidations.append(invalidation)
	return invalidation.duplicate(true)


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


## 获取输入记录副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 输入记录数组。
## [br]
## @schema return: Array[Dictionary]，每个元素为 add_input() 返回结构。
func get_inputs() -> Array[Dictionary]:
	return _duplicate_dictionary_array(_inputs)


## 获取输出记录副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 输出记录数组。
## [br]
## @schema return: Array[Dictionary]，每个元素为 add_output() 返回结构。
func get_outputs() -> Array[Dictionary]:
	return _duplicate_dictionary_array(_outputs)


## 获取依赖记录副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 依赖记录数组。
## [br]
## @schema return: Array[Dictionary]，每个元素为 add_dependency() 返回结构。
func get_dependencies() -> Array[Dictionary]:
	return _duplicate_dictionary_array(_dependencies)


## 获取失效记录副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 失效记录数组。
## [br]
## @schema return: Array[Dictionary]，每个元素为 mark_stale() 返回结构。
func get_invalidations() -> Array[Dictionary]:
	return _duplicate_dictionary_array(_invalidations)


## 获取生成产物报告副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 生成产物报告数组。
## [br]
## @schema return: Array[Dictionary]，每个元素为 GFGeneratedArtifactReport 兼容报告。
func get_artifact_reports() -> Array[Dictionary]:
	return _duplicate_dictionary_array(_artifact_reports)


## 清空输入、输出、依赖、失效和产物记录。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_inputs.clear()
	_outputs.clear()
	_dependencies.clear()
	_invalidations.clear()
	_artifact_reports.clear()


## 汇总烘焙依赖状态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 汇总选项，支持 include_inputs、include_outputs、include_dependencies、include_invalidations、include_artifacts 和 metadata。
## [br]
## @schema options: Dictionary，可包含 include_inputs、include_outputs、include_dependencies、include_invalidations、include_artifacts 和 metadata。
## [br]
## @return 烘焙依赖摘要。
## [br]
## @schema return: Dictionary，包含 success、current、status、report_id、label、计数、缺失路径、失效记录、artifact_summary 和 metadata。
func summarize(options: Dictionary = {}) -> Dictionary:
	var missing_inputs: Array[String] = _collect_missing_paths(_inputs)
	var missing_outputs: Array[String] = _collect_missing_paths(_outputs)
	var stale_dependencies: Array[StringName] = _collect_dependencies_by_status(STATUS_STALE)
	var failed_dependencies: Array[StringName] = _collect_dependencies_by_status(STATUS_FAILED)
	var artifact_summary: Dictionary = _GF_GENERATED_ARTIFACT_REPORT_SCRIPT.summarize_reports(
		_artifact_reports,
		label,
		{ "include_reports": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_artifacts", false) }
	)
	var status: StringName = _derive_status(missing_inputs, missing_outputs, stale_dependencies, failed_dependencies, artifact_summary)
	var extra_metadata: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata")
	var summary_metadata: Dictionary = metadata.duplicate(true)
	var _merged_metadata: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(summary_metadata, extra_metadata, true, true)
	var result: Dictionary = {
		"success": status != STATUS_FAILED and missing_inputs.is_empty(),
		"current": status == STATUS_CURRENT,
		"status": status,
		"report_id": report_id,
		"label": label,
		"input_count": _inputs.size(),
		"output_count": _outputs.size(),
		"dependency_count": _dependencies.size(),
		"invalidation_count": _invalidations.size(),
		"artifact_count": _artifact_reports.size(),
		"missing_inputs": missing_inputs,
		"missing_outputs": missing_outputs,
		"stale_dependencies": _string_name_array_to_array(stale_dependencies),
		"failed_dependencies": _string_name_array_to_array(failed_dependencies),
		"artifact_summary": artifact_summary,
		"metadata": summary_metadata,
	}
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_inputs", false):
		result["inputs"] = get_inputs()
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_outputs", false):
		result["outputs"] = get_outputs()
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_dependencies", false):
		result["dependencies"] = get_dependencies()
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_invalidations", false):
		result["invalidations"] = get_invalidations()
	return result


# --- 私有/辅助方法 ---

func _make_path_entry(path: String, options: Dictionary, default_required: bool) -> Dictionary:
	var exists: bool = _read_exists(path, options)
	var status: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
		options,
		"status",
		STATUS_CURRENT if exists else STATUS_MISSING
	)
	return {
		"path": path,
		"dependency_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "dependency_id"),
		"exists": exists,
		"required": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "required", default_required),
		"status": _normalize_status(status),
		"content_sha256": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "content_sha256"),
		"modified_time": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "modified_time"),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata").duplicate(true),
	}


func _read_exists(path: String, options: Dictionary) -> bool:
	if options.has("exists"):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "exists", false)
	if path.is_empty() or not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "check_filesystem", false):
		return false
	return FileAccess.file_exists(path)


func _derive_status(
	missing_inputs: Array[String],
	missing_outputs: Array[String],
	stale_dependencies: Array[StringName],
	failed_dependencies: Array[StringName],
	artifact_summary: Dictionary
) -> StringName:
	if not failed_dependencies.is_empty() or not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(artifact_summary, "success", true):
		return STATUS_FAILED
	if not missing_inputs.is_empty():
		return STATUS_MISSING
	if not missing_outputs.is_empty() or not stale_dependencies.is_empty() or not _invalidations.is_empty():
		return STATUS_STALE
	if _inputs.is_empty() and _outputs.is_empty() and _dependencies.is_empty() and _artifact_reports.is_empty():
		return STATUS_UNKNOWN
	return STATUS_CURRENT


func _collect_missing_paths(entries: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in entries:
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry, "required", true):
			continue
		var status: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(entry, "status", STATUS_CURRENT)
		var exists: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry, "exists", false)
		if status == STATUS_MISSING or not exists:
			result.append(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(entry, "path"))
	return result


func _collect_dependencies_by_status(status: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for dependency: Dictionary in _dependencies:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(dependency, "status", STATUS_CURRENT) == status:
			result.append(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(dependency, "dependency_id"))
	return result


func _duplicate_dictionary_array(values: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Dictionary in values:
		result.append(value.duplicate(true))
	return result


func _string_name_array_to_array(values: Array[StringName]) -> Array:
	var result: Array = []
	for value: StringName in values:
		result.append(value)
	return result


func _normalize_status(status: StringName) -> StringName:
	match status:
		STATUS_CURRENT, STATUS_STALE, STATUS_MISSING, STATUS_FAILED:
			return status
		_:
			return STATUS_UNKNOWN
