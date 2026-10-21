## GFConfigPipelineRunner: 配置导表 Profile 的 Godot 原生运行入口。
##
## 负责从 Godot 资源路径加载 GFConfigPipelineProfile，并调用 GFConfigPipeline 构建或导出。
## Runner 不处理命令行参数、编辑器 UI、外部进程、项目目录约定或发布策略。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 5.2.0
class_name GFConfigPipelineRunner
extends RefCounted


# --- 常量 ---

## Runner 结果使用的构建操作标识。
## [br]
## @api private
## [br]
const _OPERATION_BUILD: StringName = &"build"

## Runner 结果使用的导出操作标识。
## [br]
## @api private
## [br]
const _OPERATION_EXPORT: StringName = &"export"

## Runner 结果使用的 Profile 加载操作标识。
## [br]
## @api private
## [br]
const _OPERATION_LOAD: StringName = &"load"

## 校验当前输入并只返回生效结构与来源摘要的操作标识。
## [br]
## @api private
const _OPERATION_INSPECT: StringName = &"inspect"

## 用于校验并规范化生成产物路径的内部策略脚本。
## [br]
## @api private
## [br]
const _OUTPUT_PATH_POLICY_SCRIPT = preload("res://addons/gf/tools/config_pipeline/gf_config_pipeline_output_path_policy.gd")


# --- 公共方法 ---

## 加载导表 Profile 资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param profile_path: Profile 资源路径，通常为 .tres 或 .res。
## [br]
## @param options: 加载选项，支持 type_hint 和 cache_mode。
## [br]
## @schema options: Dictionary，可包含 type_hint: String 和 cache_mode: ResourceLoader.CacheMode 对应整数。
## [br]
## @return: 加载结果。
## [br]
## @schema return: Dictionary，包含 success、operation、profile_path、profile、profile_id、report、error_code 和 error。
func load_profile(profile_path: String, options: Dictionary = {}) -> Dictionary:
	if profile_path.is_empty():
		return _make_load_failure(
			profile_path,
			"missing_profile_path",
			"导表 Profile 路径为空。",
			ERR_INVALID_PARAMETER
		)
	if not _is_godot_resource_path(profile_path):
		return _make_load_failure(
			profile_path,
			"invalid_profile_path",
			"导表 Profile 路径必须使用 res:// 或 user://：%s。" % profile_path,
			ERR_INVALID_PARAMETER
		)
	if not _resource_path_exists(profile_path):
		return _make_load_failure(
			profile_path,
			"profile_path_not_found",
			"导表 Profile 资源不存在：%s。" % profile_path,
			ERR_FILE_NOT_FOUND
		)

	var type_hint: String = GFVariantData.get_option_string(
		options,
		"type_hint",
		"Resource"
	)
	var raw_cache_mode: int = GFVariantData.get_option_int(
		options,
		"cache_mode",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	var cache_mode: ResourceLoader.CacheMode = raw_cache_mode as ResourceLoader.CacheMode
	var resource: Resource = ResourceLoader.load(
		profile_path,
		type_hint,
		cache_mode
	)
	if resource == null:
		return _make_load_failure(
			profile_path,
			"profile_load_failed",
			"导表 Profile 资源加载失败：%s。" % profile_path,
			ERR_CANT_OPEN
		)
	if not (resource is GFConfigPipelineProfile):
		return _make_load_failure(
			profile_path,
			"invalid_pipeline_profile_resource",
			"导表 Profile 资源必须是 GFConfigPipelineProfile。",
			ERR_INVALID_DATA
		)

	var profile: GFConfigPipelineProfile = resource
	return {
		"success": true,
		"operation": _OPERATION_LOAD,
		"profile_path": profile_path,
		"profile": profile,
		"profile_id": profile.profile_id,
		"report": GFConfigValidationReport.new().make_report(profile.profile_id),
		"error_code": OK,
		"error": "",
	}


## 从 Profile 路径构建配置数据库资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param profile_path: Profile 资源路径，通常为 .tres 或 .res。
## [br]
## @param options: 加载和构建覆盖选项。
## [br]
## @schema options: Dictionary，可包含 type_hint、cache_mode、build_options、database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。
## [br]
## @return: 运行结果。
## [br]
## @schema return: Dictionary，包含 success、operation、profile_path、profile_id、output_path、database、report、table_results、load_result、build_result、error_code 和 error。
func build_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
	var load_result: Dictionary = load_profile(profile_path, options)
	if not GFVariantData.get_option_bool(load_result, "success"):
		return _make_run_failure(
			_OPERATION_BUILD,
			profile_path,
			load_result
		)

	var profile: GFConfigPipelineProfile = _get_profile_from_load_result(load_result)
	var pipeline: GFConfigPipeline = GFConfigPipeline.new()
	var build_result: Dictionary = pipeline.build_profile(profile, options)
	return _make_build_run_result(
		profile_path,
		load_result,
		build_result
	)


## 加载并完整校验 Profile，返回本次已封存 IR 的结构与来源摘要，不写入任何产物。
##
## 摘要只在整批构建成功后交付，不包含记录值；失败保留原校验报告，不显示部分表为已生效。
## 来源收据取自本次实际读取，结构取自同一次构建的 IR，不重新推导或重新读取来源。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param profile_path: Profile 的 res:// 或 user:// 资源路径。
## [br]
## @param options: 与 build_profile_path 相同的加载和构建覆盖选项。
## [br]
## @schema options: Dictionary，可包含 type_hint、cache_mode、build_options、database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes 和 work_limits；inspect 强制完整数据库与 Schema 校验。
## [br]
## @return: 无数据记录载荷的只读检查报告。
## [br]
## @schema return: Dictionary，包含 success、operation、profile_path、profile_id、report、schema_report、error_code 和 error；schema_report 成功时包含 format、format_version、database_id、version、table_count、tables 和 target_capabilities，每表含 table_name、source_path、source_format、record_count、schema、schema_origin、source_receipt 和 header_location；schema_origin 为 explicit、typed_headers、inferred 或 none；失败时 schema_report 为空。
func inspect_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
	# 只复制需要覆盖的外层；嵌套输入由既有构建链先做循环与预算准入。
	var inspection_options: Dictionary = options.duplicate()
	var build_options: Dictionary = GFVariantData.as_dictionary(inspection_options.get("build_options")).duplicate()
	build_options["validate_database"] = true
	build_options["validate_schema"] = true
	inspection_options["build_options"] = build_options
	inspection_options["validate_database"] = true
	inspection_options["validate_schema"] = true
	var run_result: Dictionary = build_profile_path(profile_path, inspection_options)
	var success: bool = GFVariantData.get_option_bool(run_result, "success")
	var schema_report: Dictionary = {}
	if success:
		schema_report = _describe_validated_build(run_result)
		success = not schema_report.is_empty()
	var error_text: String = GFVariantData.get_option_string(run_result, "error")
	if not success and error_text.is_empty():
		error_text = "无法完整读取并描述已校验的配置结构。"
	var error_code: int = GFVariantData.get_option_int(run_result, "error_code")
	if not success and error_code == OK:
		error_code = ERR_INVALID_DATA
	return {
		"success": success,
		"operation": _OPERATION_INSPECT,
		"profile_path": profile_path,
		"profile_id": GFVariantData.get_option_string_name(run_result, "profile_id"),
		"report": GFVariantData.get_option_dictionary(run_result, "report").duplicate(true),
		"schema_report": schema_report,
		"error_code": OK if success else error_code,
		"error": error_text,
	}


## 从 Profile 路径构建并保存配置数据库资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param profile_path: Profile 资源路径，通常为 .tres 或 .res。
## [br]
## @param options: 加载、构建、保存、访问器生成和增量导出覆盖选项；output_path、非空 access_output_path 与使用中的 manifest_path 必须位于 res:// 或 user:// URI 域，并在 freshness 判断前完成规范化与校验。
## [br]
## @schema options: Dictionary，可包含 type_hint、cache_mode、output_path、build_options、save_options、access_output_path、access_options、access_class_name、access_provider_accessor、database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes、changed_only、manifest_path、write_manifest、manifest_options、manifest_metadata、max_freshness_file_bytes、max_freshness_total_bytes 和 max_freshness_entries；各产物 options 可包含 allow_parent_output_path、allow_gf_source_output 和 allow_unowned_overwrite，其中 parent opt-in 不能越过 resource URI 根。
## [br]
## @return: 运行结果。
## [br]
## @schema return: Dictionary，包含 success、operation、profile_path、profile_id、output_path、database、report、table_results、load_result、build_result、save_result、access_result、export_result、manifest_path、manifest、manifest_result、freshness_report、skipped、changed_only、error_code 和 error。
func export_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
	var load_result: Dictionary = load_profile(profile_path, options)
	if not GFVariantData.get_option_bool(load_result, "success"):
		return _make_run_failure(
			_OPERATION_EXPORT,
			profile_path,
			load_result
		)

	var profile: GFConfigPipelineProfile = _get_profile_from_load_result(load_result)
	var manifest_helper: GFConfigPipelineArtifactManifest = GFConfigPipelineArtifactManifest.new()
	var path_plan: Dictionary = _make_export_output_path_plan(
		profile,
		options,
		manifest_helper
	)
	if not GFVariantData.get_option_bool(path_plan, "success"):
		return _make_output_path_failure_run_result(
			profile_path,
			load_result,
			profile,
			options,
			path_plan
		)
	var effective_options: Dictionary = (GFVariantData.get_option_dictionary(path_plan, "options").duplicate(true))
	var manifest_path: String = GFVariantData.get_option_string(path_plan, "manifest_path")
	var changed_only: bool = GFVariantData.get_option_bool(effective_options, "changed_only")
	var freshness_report: Dictionary = {}
	if changed_only:
		freshness_report = manifest_helper.make_freshness_report(
			manifest_path,
			profile_path,
			profile,
			effective_options
		)
		var scan_report: Dictionary = GFVariantData.get_option_dictionary(freshness_report, "scan_report")
		if not GFVariantData.get_option_bool(
			scan_report,
			"success",
			true
		):
			return _make_freshness_scan_failure_run_result(
				profile_path,
				load_result,
				profile,
				effective_options,
				manifest_path,
				freshness_report,
				scan_report
			)
		var stored_manifest: Dictionary = GFVariantData.get_option_dictionary(freshness_report, "stored_manifest")
		var run_summary: Dictionary = GFVariantData.get_option_dictionary(stored_manifest, "run_summary")
		var stored_report: Dictionary = GFVariantData.get_option_dictionary(run_summary, "report")
		if (
			GFVariantData.get_option_bool(freshness_report, "fresh")
			and GFVariantData.get_option_bool(run_summary, "success")
			and GFVariantData.get_option_bool(stored_report, "ok")
			and GFVariantData.get_option_int(
				stored_report,
				"issue_count",
				-1
			) == 0
			and GFVariantData.get_option_int(
				stored_report,
				"warning_count",
				-1
			) == 0
			and GFVariantData.get_option_int(
				stored_report,
				"error_count",
				-1
			) == 0
		):
			return _make_skipped_export_run_result(
				profile_path,
				load_result,
				profile,
				effective_options,
				manifest_path,
				freshness_report
			)

	var pipeline: GFConfigPipeline = GFConfigPipeline.new()
	var export_result: Dictionary = pipeline.export_profile(profile, effective_options)
	var run_result: Dictionary = _make_export_run_result(
		profile_path,
		load_result,
		export_result
	)
	run_result["changed_only"] = changed_only
	run_result["skipped"] = false
	run_result["manifest_path"] = manifest_path
	run_result["manifest_result"] = (GFVariantData.get_option_dictionary(export_result, "manifest_result").duplicate(true))
	run_result["manifest"] = GFVariantData.get_option_dictionary(export_result, "manifest").duplicate(true)
	run_result["freshness_report"] = freshness_report.duplicate(true)
	if not GFVariantData.get_option_bool(run_result, "success"):
		var manifest_result: Dictionary = GFVariantData.get_option_dictionary(run_result, "manifest_result")
		if not manifest_result.is_empty():
			run_result["error_code"] = GFVariantData.get_option_int(
				manifest_result,
				"error_code",
				ERR_CANT_CREATE
			)
	return run_result


# --- 私有/辅助方法 ---

## 仅接受本次成功构建的 sealed IR；从各表实际读取收据补齐来源，不泄漏记录与工作 Resource。
## [br]
## @api private
func _describe_validated_build(run_result: Dictionary) -> Dictionary:
	var build_result: Dictionary = GFVariantData.get_option_dictionary(run_result, "build_result")
	var raw_ir: Variant = build_result.get("ir")
	if not (raw_ir is GFConfigPipelineIR):
		return {}
	var pipeline_ir: GFConfigPipelineIR = raw_ir
	var description: Dictionary = pipeline_ir.describe()
	if not GFVariantData.get_option_bool(description, "sealed"):
		return {}
	var table_results: Array = GFVariantData.get_option_array(run_result, "table_results")
	var descriptions: Array = GFVariantData.get_option_array(description, "tables")
	if table_results.size() != descriptions.size():
		return {}
	var tables: Array[Dictionary] = []
	for index: int in range(descriptions.size()):
		var table_description: Dictionary = GFVariantData.as_dictionary(descriptions[index])
		var table_result: Dictionary = GFVariantData.as_dictionary(table_results[index])
		var source_map: Dictionary = GFVariantData.get_option_dictionary(table_description, "source_map")
		var table_metadata: Dictionary = GFVariantData.get_option_dictionary(table_description, "metadata")
		var schema_description: Dictionary = GFVariantData.get_option_dictionary(table_description, "schema")
		if not _is_schema_description_complete(schema_description):
			return {}
		tables.append(
			{
				"table_name": GFVariantData.get_option_string_name(table_description, "table_name"),
				"source_path": GFVariantData.get_option_string(table_description, "source_path"),
				"source_format": GFVariantData.get_option_string_name(table_description, "source_format"),
				"record_count": GFVariantData.get_option_int(table_description, "record_count"),
				"schema": schema_description.duplicate(true),
				"schema_origin": GFVariantData.get_option_string(table_metadata, "schema_origin"),
				"source_receipt": GFVariantData.get_option_dictionary(table_result, "source_receipt").duplicate(true),
				"header_location": GFVariantData.get_option_dictionary(source_map, "header_location").duplicate(true),
			}
		)
	return {
		"format": "gf.config_pipeline.schema_report",
		"format_version": 1,
		"database_id": GFVariantData.get_option_string_name(description, "database_id"),
		"version": GFVariantData.get_option_string(description, "version"),
		"table_count": tables.size(),
		"tables": tables,
		"target_capabilities": GFConfigAccessGenerator.get_capabilities(),
	}


## 描述本身可能耗尽预算；不可把含失败类型报告的摘要当作完整生效结构交付。
## [br]
## @api private
func _is_schema_description_complete(schema: Dictionary) -> bool:
	for column_value: Variant in GFVariantData.get_option_array(schema, "columns"):
		var column: Dictionary = GFVariantData.as_dictionary(column_value)
		var definition: Variant = column.get("type_definition")
		if definition is Dictionary:
			var definition_report: Dictionary = definition
			if not GFVariantData.get_option_bool(definition_report, "ok"):
				return false
	return true


## 生成 Profile 加载失败结果，并附带加载操作的验证报告。
## [br]
## @api private
## [br]
func _make_load_failure(
	profile_path: String,
	kind: String,
	message: String,
	error_code: Error
) -> Dictionary:
	var report: Dictionary = (
		GFConfigValidationReport.new().make_error_report(
			_OPERATION_LOAD,
			kind,
			message,
			{ "profile_path": profile_path, "error_code": error_code }
		)
	)
	return {
		"success": false,
		"operation": _OPERATION_LOAD,
		"profile_path": profile_path,
		"profile": null,
		"profile_id": &"",
		"report": report,
		"error_code": error_code,
		"error": message,
	}


## 将加载失败转换为统一 Runner 失败结果，并排除嵌套 Profile 资源。
## [br]
## @api private
## [br]
func _make_run_failure(
	operation: StringName,
	profile_path: String,
	load_result: Dictionary
) -> Dictionary:
	return {
		"success": false,
		"operation": operation,
		"profile_path": profile_path,
		"profile_id": GFVariantData.get_option_string_name(load_result, "profile_id"),
		"output_path": "",
		"database": null,
		"report": GFVariantData.get_option_dictionary(load_result, "report"),
		"table_results": [],
		"load_result": _duplicate_load_result(load_result),
		"build_result": {},
		"save_result": {},
		"access_result": {},
		"export_result": {},
		"manifest_path": "",
		"manifest": {},
		"manifest_result": {},
		"freshness_report": {},
		"skipped": false,
		"changed_only": false,
		"error_code": GFVariantData.get_option_int(
			load_result,
			"error_code",
			ERR_INVALID_PARAMETER
		),
		"error": GFVariantData.get_option_string(load_result, "error"),
	}


## 把构建阶段结果整理为包含来源加载结果和默认导出字段的 Runner 结果。
## [br]
## @api private
## [br]
func _make_build_run_result(
	profile_path: String,
	load_result: Dictionary,
	build_result: Dictionary
) -> Dictionary:
	return {
		"success": GFVariantData.get_option_bool(build_result, "success"),
		"operation": _OPERATION_BUILD,
		"profile_path": profile_path,
		"profile_id": GFVariantData.get_option_string_name(build_result, "profile_id"),
		"output_path": GFVariantData.get_option_string(build_result, "output_path"),
		"database": _get_database_from_result(build_result),
		"report": GFVariantData.get_option_dictionary(build_result, "report"),
		"table_results": GFVariantData.get_option_array(build_result, "table_results"),
		"load_result": _duplicate_load_result(load_result),
		"build_result": _duplicate_database_result(build_result),
		"save_result": {},
		"access_result": {},
		"export_result": {},
		"manifest_path": "",
		"manifest": {},
		"manifest_result": {},
		"freshness_report": {},
		"skipped": false,
		"changed_only": false,
		"error_code": OK if GFVariantData.get_option_bool(build_result, "success") else ERR_INVALID_DATA,
		"error": GFVariantData.get_option_string(build_result, "error"),
	}


## 把导出阶段结果整理为 Runner 结果，并保留构建、保存和访问器子结果。
## [br]
## @api private
## [br]
func _make_export_run_result(
	profile_path: String,
	load_result: Dictionary,
	export_result: Dictionary
) -> Dictionary:
	return {
		"success": GFVariantData.get_option_bool(export_result, "success"),
		"operation": _OPERATION_EXPORT,
		"profile_path": profile_path,
		"profile_id": GFVariantData.get_option_string_name(export_result, "profile_id"),
		"output_path": GFVariantData.get_option_string(export_result, "output_path"),
		"database": _get_database_from_result(export_result),
		"report": GFVariantData.get_option_dictionary(export_result, "report"),
		"table_results": GFVariantData.get_option_array(export_result, "table_results"),
		"load_result": _duplicate_load_result(load_result),
		"build_result": GFVariantData.get_option_dictionary(export_result, "build_result").duplicate(true),
		"save_result": GFVariantData.get_option_dictionary(export_result, "save_result").duplicate(true),
		"access_result": GFVariantData.get_option_dictionary(export_result, "access_result").duplicate(true),
		"export_result": _duplicate_database_result(export_result),
		"manifest_path": "",
		"manifest": GFVariantData.get_option_dictionary(export_result, "manifest").duplicate(true),
		"manifest_result": {},
		"freshness_report": {},
		"skipped": false,
		"changed_only": false,
		"error_code": OK if GFVariantData.get_option_bool(export_result, "success") else ERR_INVALID_DATA,
		"error": GFVariantData.get_option_string(export_result, "error"),
	}


## 为 freshness 判定后跳过的导出构造成功结果，并携带已存储 manifest 和 freshness 摘要。
## [br]
## @api private
## [br]
func _make_skipped_export_run_result(
	profile_path: String,
	load_result: Dictionary,
	profile: GFConfigPipelineProfile,
	options: Dictionary,
	manifest_path: String,
	freshness_report: Dictionary
) -> Dictionary:
	var profile_id: StringName = &""
	var output_path: String = ""
	if profile != null:
		profile_id = profile.profile_id
		output_path = profile.resolve_output_path(options)
	return {
		"success": true,
		"operation": _OPERATION_EXPORT,
		"profile_path": profile_path,
		"profile_id": profile_id,
		"output_path": output_path,
		"database": null,
		"report": GFConfigValidationReport.new().make_report(profile_id),
		"table_results": [],
		"load_result": _duplicate_load_result(load_result),
		"build_result": {},
		"save_result": {},
		"access_result": {},
		"export_result": {},
		"manifest_path": manifest_path,
		"manifest": GFVariantData.get_option_dictionary(freshness_report, "stored_manifest").duplicate(true),
		"manifest_result": {},
		"freshness_report": freshness_report.duplicate(true),
		"skipped": true,
		"changed_only": true,
		"error_code": OK,
		"error": "",
	}


## 将 freshness 扫描失败转换为 changed_only 导出失败结果。
## [br]
## @api private
## [br]
func _make_freshness_scan_failure_run_result(
	profile_path: String,
	load_result: Dictionary,
	profile: GFConfigPipelineProfile,
	options: Dictionary,
	manifest_path: String,
	freshness_report: Dictionary,
	scan_report: Dictionary
) -> Dictionary:
	var profile_id: StringName = profile.profile_id if profile != null else &""
	var output_path: String = profile.resolve_output_path(options) if profile != null else ""
	var message: String = GFVariantData.get_option_string(
		scan_report,
		"error",
		"freshness 扫描预算校验失败。"
	)
	return {
		"success": false,
		"operation": _OPERATION_EXPORT,
		"profile_path": profile_path,
		"profile_id": profile_id,
		"output_path": output_path,
		"database": null,
		"report": (
			GFConfigValidationReport.new().make_error_report(
				profile_id,
				GFVariantData.get_option_string(
					scan_report,
					"error_code",
					"freshness_budget_exceeded"
				),
				message,
				scan_report
			)
		),
		"table_results": [],
		"load_result": _duplicate_load_result(load_result),
		"build_result": {},
		"save_result": {},
		"access_result": {},
		"export_result": {},
		"manifest_path": manifest_path,
		"manifest": GFVariantData.get_option_dictionary(freshness_report, "current_manifest").duplicate(true),
		"manifest_result": {},
		"freshness_report": freshness_report.duplicate(true),
		"skipped": false,
		"changed_only": true,
		"error_code": ERR_OUT_OF_MEMORY,
		"error": message,
	}


## 将输出路径计划失败转换为 Runner 失败结果；manifest 路径失败时也请求一次 dry_run 保存结果。
## [br]
## @api private
## [br]
func _make_output_path_failure_run_result(
	profile_path: String,
	load_result: Dictionary,
	profile: GFConfigPipelineProfile,
	options: Dictionary,
	path_plan: Dictionary
) -> Dictionary:
	var profile_id: StringName = profile.profile_id if profile != null else &""
	var output_path: String = GFVariantData.get_option_string(path_plan, "output_path")
	if output_path.is_empty() and profile != null:
		output_path = profile.resolve_output_path(options)
	var message: String = GFVariantData.get_option_string(path_plan, "error")
	var artifact: String = GFVariantData.get_option_string(path_plan, "artifact")
	var invalid_path: String = GFVariantData.get_option_string(path_plan, "input_path")
	var manifest_result: Dictionary = {}
	if artifact == "manifest":
		var manifest_options: Dictionary = _make_manifest_path_options(options)
		manifest_options["dry_run"] = true
		manifest_result = (
			GFConfigPipelineArtifactManifest.new().save_manifest(
				invalid_path,
				{},
				manifest_options
			)
		)
	var result: Dictionary = _make_run_failure(
		_OPERATION_EXPORT,
		profile_path,
		load_result
	)
	result["profile_id"] = profile_id
	result["output_path"] = output_path
	result["report"] = (
		GFConfigValidationReport.new().make_error_report(
			profile_id,
			"invalid_output_path",
			message,
			{ "artifact": artifact, "path": invalid_path, }
		)
	)
	result["manifest_path"] = GFVariantData.get_option_string(path_plan, "manifest_path")
	result["manifest_result"] = manifest_result
	result["changed_only"] = GFVariantData.get_option_bool(options, "changed_only")
	result["error_code"] = ERR_INVALID_PARAMETER
	result["error"] = message
	return result


## 优先返回显式 manifest_path；未指定时从 Profile 的数据库输出路径推导默认路径。
## [br]
## @api private
## [br]
func _resolve_manifest_path(
	profile: GFConfigPipelineProfile,
	options: Dictionary,
	manifest_helper: GFConfigPipelineArtifactManifest
) -> String:
	var explicit_manifest_path: String = GFVariantData.get_option_string(options, "manifest_path")
	if not explicit_manifest_path.is_empty():
		return explicit_manifest_path
	if profile == null:
		return ""
	return manifest_helper.get_default_manifest_path(profile.resolve_output_path(options))


## 复制选项并依次准入数据库、可选访问器和启用的 manifest 输出路径，把规范路径写回副本；在 freshness 扫描前统一路径身份，失败保留已完成的计划信息。
## [br]
## @api private
func _make_export_output_path_plan(
	profile: GFConfigPipelineProfile,
	options: Dictionary,
	manifest_helper: GFConfigPipelineArtifactManifest
) -> Dictionary:
	var effective_options: Dictionary = options.duplicate(true)
	var output_path: String = profile.resolve_output_path(options) if profile != null else ""
	var output_options: Dictionary = profile.make_save_options(options) if profile != null else {}
	var output_result: Dictionary = _OUTPUT_PATH_POLICY_SCRIPT.resolve_output_path(
		output_path,
		output_options,
		"配置数据库"
	)
	if not GFVariantData.get_option_bool(output_result, "success"):
		return _make_output_path_plan_failure(
			"database",
			output_path,
			"",
			GFVariantData.get_option_string(output_result, "error"),
			effective_options
		)
	output_path = GFVariantData.get_option_string(output_result, "path")
	effective_options["output_path"] = output_path

	var access_output_path: String = (profile.resolve_access_output_path(options) if profile != null else "")
	if not access_output_path.is_empty():
		var access_options: Dictionary = profile.make_access_options(options)
		var access_result: Dictionary = _OUTPUT_PATH_POLICY_SCRIPT.resolve_output_path(
			access_output_path,
			access_options,
			"配置访问器"
		)
		if not GFVariantData.get_option_bool(access_result, "success"):
			return _make_output_path_plan_failure(
				"access",
				access_output_path,
				"",
				GFVariantData.get_option_string(access_result, "error"),
				effective_options,
				output_path
			)
		access_output_path = GFVariantData.get_option_string(access_result, "path")
		effective_options["access_output_path"] = access_output_path

	var manifest_path: String = _resolve_manifest_path(
		profile,
		effective_options,
		manifest_helper
	)
	var should_use_manifest: bool = (
		GFVariantData.get_option_bool(options, "changed_only")
		or GFVariantData.get_option_bool(options, "write_manifest")
		or not GFVariantData.get_option_string(options, "manifest_path").is_empty()
	)
	if should_use_manifest:
		var manifest_options: Dictionary = _make_manifest_path_options(options)
		var manifest_result: Dictionary = _OUTPUT_PATH_POLICY_SCRIPT.resolve_output_path(
			manifest_path,
			manifest_options,
			"manifest"
		)
		if not GFVariantData.get_option_bool(manifest_result, "success"):
			return _make_output_path_plan_failure(
				"manifest",
				manifest_path,
				manifest_path,
				GFVariantData.get_option_string(manifest_result, "error"),
				effective_options,
				output_path,
				access_output_path
			)
		manifest_path = GFVariantData.get_option_string(manifest_result, "path")
		effective_options["manifest_path"] = manifest_path

	return {
		"success": true,
		"options": effective_options,
		"output_path": output_path,
		"access_output_path": access_output_path,
		"manifest_path": manifest_path,
		"artifact": "",
		"input_path": "",
		"error_code": OK,
		"error": "",
	}


## 深复制嵌套 manifest_options，并仅在其未设置对应键时继承两个顶层路径许可选项。
## [br]
## @api private
## [br]
func _make_manifest_path_options(options: Dictionary) -> Dictionary:
	var result: Dictionary = (GFVariantData.get_option_dictionary(options, "manifest_options").duplicate(true))
	for key: String in PackedStringArray(["allow_gf_source_output", "allow_parent_output_path",]):
		if options.has(key) and not result.has(key):
			result[key] = options[key]
	return result


## 组装输出路径计划失败结果，并深复制当前有效选项。
## [br]
## @api private
## [br]
func _make_output_path_plan_failure(
	artifact: String,
	input_path: String,
	manifest_path: String,
	message: String,
	effective_options: Dictionary,
	output_path: String = "",
	access_output_path: String = ""
) -> Dictionary:
	return {
		"success": false,
		"options": effective_options.duplicate(true),
		"output_path": output_path,
		"access_output_path": access_output_path,
		"manifest_path": manifest_path,
		"artifact": artifact,
		"input_path": input_path,
		"error_code": ERR_INVALID_PARAMETER,
		"error": message,
	}


## 仅当加载结果中的 profile 值为 GFConfigPipelineProfile 时返回该资源。
## [br]
## @api private
## [br]
func _get_profile_from_load_result(load_result: Dictionary) -> GFConfigPipelineProfile:
	var profile_value: Variant = GFVariantData.get_option_value(load_result, "profile")
	if profile_value is GFConfigPipelineProfile:
		var profile: GFConfigPipelineProfile = profile_value
		return profile
	return null


## 仅当阶段结果中的 database 值为 GFConfigDatabaseResource 时返回该资源。
## [br]
## @api private
## [br]
func _get_database_from_result(result: Dictionary) -> GFConfigDatabaseResource:
	var database_value: Variant = GFVariantData.get_option_value(result, "database")
	if database_value is GFConfigDatabaseResource:
		var database: GFConfigDatabaseResource = database_value
		return database
	return null


## 先查询 ResourceLoader，再查询路径全局化后的文件是否存在。
## [br]
## @api private
## [br]
func _resource_path_exists(profile_path: String) -> bool:
	if ResourceLoader.exists(profile_path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(profile_path))


## 判断 Profile 路径是否以 res:// 或 user:// 开头。
## [br]
## @api private
## [br]
func _is_godot_resource_path(profile_path: String) -> bool:
	return profile_path.begins_with("res://") or profile_path.begins_with("user://")


## 复制加载结果字典时排除 profile 资源值。
## [br]
## @api private
## [br]
func _duplicate_load_result(load_result: Dictionary) -> Dictionary:
	return _duplicate_dictionary_without_keys(
		load_result,
		{ "profile": true }
	)


## 复制阶段结果字典时排除 database 资源值。
## [br]
## @api private
## [br]
func _duplicate_database_result(result: Dictionary) -> Dictionary:
	return _duplicate_dictionary_without_keys(
		result,
		{ "database": true }
	)


## 新建结果字典，跳过指定键，并通过 GFVariantData.duplicate_variant 复制其余值。
## [br]
## @api private
## [br]
func _duplicate_dictionary_without_keys(result: Dictionary, skipped_keys: Dictionary) -> Dictionary:
	var copy: Dictionary = {}
	for key: Variant in result.keys():
		if skipped_keys.has(key):
			continue
		copy[key] = GFVariantData.duplicate_variant(result[key])
	return copy
