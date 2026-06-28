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

const _OPERATION_BUILD: StringName = &"build"
const _OPERATION_EXPORT: StringName = &"export"
const _OPERATION_LOAD: StringName = &"load"


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
		return _make_load_failure(profile_path, "missing_profile_path", "导表 Profile 路径为空。", ERR_INVALID_PARAMETER)
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

	var type_hint: String = GFVariantData.get_option_string(options, "type_hint", "Resource")
	var raw_cache_mode: int = GFVariantData.get_option_int(options, "cache_mode", ResourceLoader.CACHE_MODE_IGNORE)
	var cache_mode: ResourceLoader.CacheMode = raw_cache_mode as ResourceLoader.CacheMode
	var resource: Resource = ResourceLoader.load(profile_path, type_hint, cache_mode)
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
		return _make_run_failure(_OPERATION_BUILD, profile_path, load_result)

	var profile: GFConfigPipelineProfile = _get_profile_from_load_result(load_result)
	var pipeline: GFConfigPipeline = GFConfigPipeline.new()
	var build_result: Dictionary = pipeline.build_profile(profile, options)
	return _make_build_run_result(profile_path, load_result, build_result)


## 从 Profile 路径构建并保存配置数据库资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param profile_path: Profile 资源路径，通常为 .tres 或 .res。
## [br]
## @param options: 加载、构建、保存和访问器生成覆盖选项。
## [br]
## @schema options: Dictionary，可包含 type_hint、cache_mode、output_path、build_options、save_options、access_output_path、access_options、access_class_name、access_provider_accessor、database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。
## [br]
## @return: 运行结果。
## [br]
## @schema return: Dictionary，包含 success、operation、profile_path、profile_id、output_path、database、report、table_results、load_result、build_result、save_result、access_result、export_result、error_code 和 error。
func export_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
	var load_result: Dictionary = load_profile(profile_path, options)
	if not GFVariantData.get_option_bool(load_result, "success"):
		return _make_run_failure(_OPERATION_EXPORT, profile_path, load_result)

	var profile: GFConfigPipelineProfile = _get_profile_from_load_result(load_result)
	var pipeline: GFConfigPipeline = GFConfigPipeline.new()
	var export_result: Dictionary = pipeline.export_profile(profile, options)
	return _make_export_run_result(profile_path, load_result, export_result)


# --- 私有/辅助方法 ---

func _make_load_failure(
	profile_path: String,
	kind: String,
	message: String,
	error_code: Error
) -> Dictionary:
	var report: Dictionary = GFConfigValidationReport.new().make_error_report(
		_OPERATION_LOAD,
		kind,
		message,
		{ "profile_path": profile_path, "error_code": error_code }
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


func _make_run_failure(operation: StringName, profile_path: String, load_result: Dictionary) -> Dictionary:
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
		"error_code": GFVariantData.get_option_int(load_result, "error_code", ERR_INVALID_PARAMETER),
		"error": GFVariantData.get_option_string(load_result, "error"),
	}


func _make_build_run_result(profile_path: String, load_result: Dictionary, build_result: Dictionary) -> Dictionary:
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
		"error_code": OK if GFVariantData.get_option_bool(build_result, "success") else ERR_INVALID_DATA,
		"error": GFVariantData.get_option_string(build_result, "error"),
	}


func _make_export_run_result(profile_path: String, load_result: Dictionary, export_result: Dictionary) -> Dictionary:
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
		"error_code": OK if GFVariantData.get_option_bool(export_result, "success") else ERR_INVALID_DATA,
		"error": GFVariantData.get_option_string(export_result, "error"),
	}


func _get_profile_from_load_result(load_result: Dictionary) -> GFConfigPipelineProfile:
	var profile_value: Variant = GFVariantData.get_option_value(load_result, "profile")
	if profile_value is GFConfigPipelineProfile:
		var profile: GFConfigPipelineProfile = profile_value
		return profile
	return null


func _get_database_from_result(result: Dictionary) -> GFConfigDatabaseResource:
	var database_value: Variant = GFVariantData.get_option_value(result, "database")
	if database_value is GFConfigDatabaseResource:
		var database: GFConfigDatabaseResource = database_value
		return database
	return null


func _resource_path_exists(profile_path: String) -> bool:
	if ResourceLoader.exists(profile_path):
		return true
	return FileAccess.file_exists(ProjectSettings.globalize_path(profile_path))


func _is_godot_resource_path(profile_path: String) -> bool:
	return profile_path.begins_with("res://") or profile_path.begins_with("user://")


func _duplicate_load_result(load_result: Dictionary) -> Dictionary:
	return _duplicate_dictionary_without_keys(load_result, { "profile": true })


func _duplicate_database_result(result: Dictionary) -> Dictionary:
	return _duplicate_dictionary_without_keys(result, { "database": true })


func _duplicate_dictionary_without_keys(result: Dictionary, skipped_keys: Dictionary) -> Dictionary:
	var copy: Dictionary = {}
	for key: Variant in result.keys():
		if skipped_keys.has(key):
			continue
		copy[key] = GFVariantData.duplicate_variant(result[key])
	return copy
