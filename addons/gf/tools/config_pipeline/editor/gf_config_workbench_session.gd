@tool

# 工作台草稿、显式保存、调用参数和恢复状态；执行使用同一个 CLI Command/Runner。
extends RefCounted


# --- 常量 ---

const _PRESET_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_preset.gd")
const _COMMAND_SCRIPT = preload("res://addons/gf/tools/config_pipeline/gf_config_pipeline_command.gd")
const _OUTPUT_PATH_POLICY_SCRIPT = preload("res://addons/gf/tools/config_pipeline/gf_config_pipeline_output_path_policy.gd")
const _MAX_SOURCES: int = 16
const _MAX_SOURCE_BYTES: int = 2 * 1024 * 1024
const _MAX_TOTAL_BYTES: int = 8 * 1024 * 1024


# --- 私有变量 ---

var _profile: GFConfigPipelineProfile = null
var _profile_path: String = ""
var _saved_digest: String = ""
var _dirty: bool = false
var _stale: bool = true
var _result: Dictionary = {}
var _input_digests: Dictionary = {}
var _recovery_result: Dictionary = {}


# --- 框架内部方法 ---

## 获取仅属于本页面的工作草稿；调用方修改后必须调用 mark_changed。
## [br]
## @api framework_internal
## [br]
## @return: 草稿或 null。
func get_profile() -> GFConfigPipelineProfile:
	return _profile


## 返回保存、新鲜度和执行结果三个独立维度。
## [br]
## @api framework_internal
## [br]
## @return: 当前快照。
## [br]
## @schema return: Dictionary，包含 profile_path、dirty、stale、result、recovery_required。
func get_state() -> Dictionary:
	return { "profile_path": _profile_path, "dirty": _dirty, "stale": _stale, "result": _result, "recovery_required": GFVariantData.get_option_bool(_recovery_result, "recovery_required") }


## 采用新建预设；不保存任何文件。
## [br]
## @api framework_internal
## [br]
## @param source_path: 来源路径。
## [br]
## @param database_name: 任务名称。
## [br]
## @param output_root: 输出根。
func create_profile(source_path: String, database_name: String, output_root: String) -> void:
	_profile = _PRESET_SCRIPT.make_profile(source_path, database_name, output_root)
	_profile_path = ""
	_saved_digest = ""
	_result = {}
	mark_changed()


## 从磁盘加载并深复制来源和 Schema，避免修改共享 ResourceLoader 对象。
## [br]
## @api framework_internal
## [br]
## @param path: Profile 路径。
## [br]
## @return: 是否成功。
func load_profile(path: String) -> bool:
	var loaded: Dictionary = GFConfigPipelineRunner.new().load_profile(path)
	var value: Variant = loaded.get("profile")
	if not (value is GFConfigPipelineProfile):
		_result = loaded
		return false
	var original: GFConfigPipelineProfile = value
	var editor_error: String = _check_editor_resources(original)
	if not editor_error.is_empty():
		_result = { "success": false, "error": editor_error }
		return false
	_profile = original.duplicate(true)
	_profile.sources.clear()
	for source: GFConfigPipelineTableSource in original.sources:
		if source == null:
			_profile.sources.append(null)
			continue
		var copied: GFConfigPipelineTableSource = source.duplicate(true)
		copied.schema = source.schema.duplicate_schema() if source.schema != null else null
		_profile.sources.append(copied)
	_profile_path = path
	_saved_digest = FileAccess.get_sha256(path)
	_dirty = false
	_stale = true
	_result = {}
	return true


## 将草稿标为未保存，并使旧结果过期。
## [br]
## @api framework_internal
func mark_changed() -> void:
	_dirty = true
	_stale = true


## 关闭已由调用方处理保存/放弃选择的任务；不会删除磁盘 Profile。
## [br]
## @api framework_internal
func clear_profile() -> void:
	_profile = null
	_profile_path = ""
	_saved_digest = ""
	_dirty = false
	_stale = true
	_result = {}
	_input_digests.clear()


## 显式保存草稿。原文件变化或新路径已存在时拒绝覆盖；Schema 以草稿副本嵌入。
## [br]
## @api framework_internal
## [br]
## @param path: 新建或另存路径；空值表示原路径。
## [br]
## @return: 保存或恢复报告。
## [br]
## @schema return: Dictionary，包含 success、error 和 transaction_result。
func save_profile(path: String = "") -> Dictionary:
	var target: String = path if not path.is_empty() else _profile_path
	if _profile == null or target.is_empty() or not target.ends_with(".tres"):
		return { "success": false, "error": "Select a .tres Profile path." }
	var resolved: Dictionary = _OUTPUT_PATH_POLICY_SCRIPT.resolve_output_path(target, {}, "Profile ")
	if not GFVariantData.get_option_bool(resolved, "success"):
		return { "success": false, "error": GFVariantData.get_option_string(resolved, "error") }
	target = GFVariantData.get_option_string(resolved, "path")
	if target.begins_with("res://.godot/"):
		return { "success": false, "error": "Save the Profile in a user-owned project directory." }
	if get_state()["recovery_required"]:
		return { "success": false, "error": "Resolve the pending file transaction first." }
	if FileAccess.file_exists(target) and (target != _profile_path or FileAccess.get_sha256(target) != _saved_digest):
		return { "success": false, "error": "The Profile changed on disk or the destination already exists. Reload or save to a new path." }
	var transaction: Dictionary = GFArtifactWriteTransaction.begin(PackedStringArray([target]), { "allowed_roots": ["res://", "user://"] })
	if not GFVariantData.get_option_bool(transaction, "ok"):
		adopt_recovery_report(transaction)
		return { "success": false, "error": "Profile transaction could not begin.", "transaction_result": transaction }
	var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target.get_base_dir()))
	var save_error: Error = mkdir_error if mkdir_error != OK else ResourceSaver.save(_profile, target)
	var final_result: Dictionary = GFArtifactWriteTransaction.complete(transaction) if save_error == OK else GFArtifactWriteTransaction.rollback(transaction)
	_recovery_result = final_result
	var success: bool = save_error == OK and GFVariantData.get_option_bool(final_result, "ok")
	if success:
		_profile_path = target
		_saved_digest = FileAccess.get_sha256(target)
		_dirty = false
	return { "success": success, "error": "" if success else (error_string(save_error) if save_error != OK else "Profile transaction cleanup requires recovery."), "transaction_result": final_result }


## 使用保存的 Profile 与显式执行参数调用既有 Command；严格失败可发生在文件提交之后。
## [br]
## @api framework_internal
## [br]
## @param operation: build 或 export。
## [br]
## @param options: 本次执行开关。
## [br]
## @schema options: Dictionary，支持 dry_run、changed_only、write_manifest、strict。
## [br]
## @return: 原始 Command 报告，附 elapsed_msec。
## [br]
## @schema return: Dictionary，与 GFConfigPipelineCommand.run 相同。
func run_operation(operation: String, options: Dictionary) -> Dictionary:
	var admission: Dictionary = get_admission_report()
	if not GFVariantData.get_option_bool(admission, "success"):
		_result = admission
		return admission
	if _dirty or _profile_path.is_empty():
		_result = { "success": false, "error": "Save the Profile before running." }
		return _result
	if FileAccess.get_sha256(_profile_path) != _saved_digest:
		_stale = true
		_result = { "success": false, "error": "The saved Profile changed on disk. Reload it before running." }
		return _result
	var before_inputs: Dictionary = _capture_inputs()
	var start_usec: int = Time.get_ticks_usec()
	_result = _COMMAND_SCRIPT.new().run(make_arguments(operation, options))
	_result["elapsed_msec"] = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var runner_result: Dictionary = GFVariantData.get_option_dictionary(_result, "runner_result")
	_recovery_result = GFVariantData.get_option_dictionary(runner_result, "export_result")
	_input_digests = before_inputs
	_stale = before_inputs != _capture_inputs()
	return _result


## 构建 CLI 参数数组；UI 与复制命令使用同一数组。
## [br]
## @api framework_internal
## [br]
## @param operation: 执行操作。
## [br]
## @param options: 本次执行开关。
## [br]
## @schema options: Dictionary，支持 dry_run、changed_only、write_manifest、strict。
## [br]
## @return: 不包含 shell 语法的参数数组。
func make_arguments(operation: String, options: Dictionary) -> PackedStringArray:
	var arguments: PackedStringArray = ["--profile", _profile_path, "--operation", operation, "--json", "--max-validation-cells", "4000", "--max-source-bytes", str(_MAX_SOURCE_BYTES)]
	for option: String in ["dry_run", "changed_only", "write_manifest", "strict"]:
		if GFVariantData.get_option_bool(options, option):
			var _appended: bool = arguments.append("--" + option.replace("_", "-"))
	return arguments


## 检查工作台小表支持范围；该字节预算不构成执行时长或内存保证。
## [br]
## @api framework_internal
## [br]
## @return: 有界来源准入报告。
## [br]
## @schema return: Dictionary，包含 success、error、source_count、total_bytes。
func get_admission_report() -> Dictionary:
	if _profile == null or _profile.sources.is_empty() or _profile.sources.size() > _MAX_SOURCES:
		return { "success": false, "error": "The workbench supports 1–16 sources. Use the CLI for larger batches." }
	if GFVariantData.get_option_bool(_recovery_result, "recovery_required"):
		return { "success": false, "error": "A file transaction requires recovery before another operation." }
	var total: int = 0
	for source: GFConfigPipelineTableSource in _profile.sources:
		if source == null:
			return { "success": false, "error": "A table source is null." }
		var file: FileAccess = FileAccess.open(source.source_path, FileAccess.READ)
		if file == null:
			return { "success": false, "error": "Cannot read source: " + source.source_path }
		var size: int = file.get_length()
		file.close()
		total += size
		if size > _MAX_SOURCE_BYTES or total > _MAX_TOTAL_BYTES:
			return { "success": false, "error": "Workbench limit: 2 MiB per file, 8 MiB total. Use the CLI for larger inputs." }
	return { "success": true, "source_count": _profile.sources.size(), "total_bytes": total }


## 重新核对有界输入摘要；只将旧结果变为过期，不自动执行。
## [br]
## @api framework_internal
func refresh_freshness() -> void:
	if _stale or _input_digests.is_empty():
		return
	if not GFVariantData.get_option_bool(get_admission_report(), "success") or _capture_inputs() != _input_digests:
		_stale = true


## 接管创建样例时尚未终结的事务报告，供同一恢复入口继续处理。
## [br]
## @api framework_internal
## [br]
## @param report: 样例或文件提交返回的真实事务报告。
## [br]
## @schema report: Dictionary，包含 recovery_required、recovery_action、recovery_transaction。
func adopt_recovery_report(report: Dictionary) -> void:
	if GFVariantData.get_option_bool(report, "recovery_required"):
		_recovery_result = report


## 重试后端要求的终态动作，保留 opaque 恢复句柄。
## [br]
## @api framework_internal
## [br]
## @return: 恢复报告。
## [br]
## @schema return: Dictionary，GFArtifactWriteTransaction 恢复结果。
func recover() -> Dictionary:
	var transaction: Dictionary = GFVariantData.get_option_dictionary(_recovery_result, "recovery_transaction")
	var action: String = GFVariantData.get_option_string(_recovery_result, "recovery_action")
	if transaction.is_empty() or action not in ["complete", "rollback"]:
		return { "ok": false, "error": "No pending recovery." }
	_recovery_result = GFArtifactWriteTransaction.complete(transaction) if action == "complete" else GFArtifactWriteTransaction.rollback(transaction)
	_stale = true
	return _recovery_result


# --- 私有/辅助方法 ---

func _check_editor_resources(profile: GFConfigPipelineProfile) -> String:
	if not Engine.is_editor_hint():
		return ""
	var resources: Array[Resource] = [profile]
	for source: GFConfigPipelineTableSource in profile.sources:
		if source == null:
			continue
		resources.append(source)
		if source.schema == null:
			continue
		var schema: GFConfigTableSchema = source.schema
		resources.append(schema)
		resources.append_array(schema.columns)
		resources.append_array(schema.indexes)
		resources.append_array(schema.references)
		resources.append_array(schema.record_validation_rules)
		resources.append_array(schema.table_validation_rules)
		for column: GFConfigTableColumn in schema.columns:
			if column != null:
				resources.append_array(column.validation_rules)
				resources.append_array(column.element_validation_rules)
	for resource: Resource in resources:
		if resource == null:
			continue
		var script_value: Variant = resource.get_script()
		if script_value is Script:
			var script: Script = script_value
			if not script.is_tool():
				return "Editor execution requires @tool on configuration Resources and custom rules. Use the CLI for: " + script.resource_path
	return ""


func _capture_inputs() -> Dictionary:
	var result: Dictionary = { _profile_path: FileAccess.get_sha256(_profile_path) }
	_capture_resource_dependencies(_profile_path, result)
	for source: GFConfigPipelineTableSource in _profile.sources:
		result[source.source_path] = FileAccess.get_sha256(source.source_path)
	return result


func _capture_resource_dependencies(path: String, result: Dictionary) -> void:
	for dependency: String in ResourceLoader.get_dependencies(path):
		var dependency_path: String = dependency.get_slice("::", dependency.get_slice_count("::") - 1)
		if result.has(dependency_path) or dependency_path.get_extension() not in ["tres", "res", "gd"]:
			continue
		result[dependency_path] = FileAccess.get_sha256(dependency_path)
		if dependency_path.get_extension() != "gd":
			_capture_resource_dependencies(dependency_path, result)
