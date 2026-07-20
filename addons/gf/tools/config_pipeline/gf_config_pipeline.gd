## GFConfigPipeline: 配置导表工具的资源构建入口。
##
## 负责把 CSV / JSON / ConfigFile / XLSX 文件来源构建为 GFConfigTableResource 与 GFConfigDatabaseResource。
## 该工具只处理通用导入、校验、索引重建和 Resource 保存，不绑定任何项目业务表或发布流程。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 5.2.0
class_name GFConfigPipeline
extends RefCounted


# --- 常量 ---

const _FORMAT_AUTO: StringName = &"auto"
const _OUTPUT_FORMAT_AUTO: StringName = &"auto"
const _OUTPUT_FORMAT_JSON: StringName = &"json"
const _OUTPUT_FORMAT_RESOURCE: StringName = &"resource"
const _ARTIFACT_OWNER: String = "gf.tool.config_pipeline"
const _ARTIFACT_OWNER_FIELD: String = "artifact_owner"
const _RESOURCE_ARTIFACT_OWNER_META: StringName = &"_gf_config_pipeline_artifact_owner"
const _ACCESS_ARTIFACT_MARKER: String = "# @generated_by gf.tool.config_pipeline"
const _MAX_PROVIDER_ACCESSOR_LENGTH: int = 512
const _GENERATED_ARTIFACT_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")


# --- 私有变量 ---

var _reader_stage: GFConfigPipelineReaderStage = GFConfigPipelineReaderStage.new()
var _layout_stage: GFConfigPipelineLayoutStage = GFConfigPipelineLayoutStage.new()
var _validation_stage: GFConfigPipelineValidationStage = GFConfigPipelineValidationStage.new()
var _target_stage: GFConfigPipelineTargetStage = GFConfigPipelineTargetStage.new()
var _commit_stage: GFConfigPipelineCommitStage = GFConfigPipelineCommitStage.new()


# --- 公共方法 ---

## 替换 Pipeline 使用的阶段实现。传入 null 的阶段保持当前实现不变。
##
## 自定义实现应继承对应内置阶段并保持其输入、输出契约；Pipeline 只负责编排，不探测项目业务类型。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param reader_stage: 可选来源读取阶段。
## [br]
## @param layout_stage: 可选布局解析阶段。
## [br]
## @param validation_stage: 可选语义校验阶段。
## [br]
## @param target_stage: 可选目标物化阶段。
## [br]
## @param commit_stage: 可选文件提交事务阶段。
## [br]
## @return: 当前 Pipeline，便于链式配置。
func configure_stages(
	reader_stage: GFConfigPipelineReaderStage = null,
	layout_stage: GFConfigPipelineLayoutStage = null,
	validation_stage: GFConfigPipelineValidationStage = null,
	target_stage: GFConfigPipelineTargetStage = null,
	commit_stage: GFConfigPipelineCommitStage = null
) -> GFConfigPipeline:
	if reader_stage != null:
		_reader_stage = reader_stage
	if layout_stage != null:
		_layout_stage = layout_stage
	if validation_stage != null:
		_validation_stage = validation_stage
	if target_stage != null:
		_target_stage = target_stage
	if commit_stage != null:
		_commit_stage = commit_stage
	return self


## 获取当前阶段组合的稳定描述。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 按 Reader、Layout、Validation、Target、Commit 排列的阶段描述。
## [br]
## @schema return: Array[Dictionary]，每项包含 stage_id、implementation_version、implementation_path 和阶段契约字段。
func get_stage_descriptors() -> Array[Dictionary]:
	return [
		_with_stage_implementation_path(_reader_stage.get_stage_descriptor(), _reader_stage),
		_with_stage_implementation_path(_layout_stage.get_stage_descriptor(), _layout_stage),
		_with_stage_implementation_path(_validation_stage.get_stage_descriptor(), _validation_stage),
		_with_stage_implementation_path(_target_stage.get_stage_descriptor(), _target_stage),
		_with_stage_implementation_path(_commit_stage.get_stage_descriptor(), _commit_stage),
	]

## 从来源文件构建单表资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param source: 单表来源声明。
## [br]
## @param options: 可选构建选项，支持 parse_options、rebuild_indexes。
## [br]
## @schema options: Dictionary，可包含 parse_options 和 rebuild_indexes。
## [br]
## @return: 构建结果。
## [br]
## @schema return: Dictionary，包含 success、table、ir、report、source_path、format 和 error。
func build_table(source: GFConfigPipelineTableSource, options: Dictionary = {}) -> Dictionary:
	var compile_result: Dictionary = _compile_table(source, options)
	return _materialize_table_compile_result(compile_result, options)


## 从文本构建单表资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param source: 单表来源声明。
## [br]
## @param text: CSV、JSON 或 ConfigFile 文本。
## [br]
## @param options: 可选构建选项，支持 parse_options、rebuild_indexes。
## [br]
## @schema options: Dictionary，可包含 parse_options 和 rebuild_indexes。
## [br]
## @return: 构建结果。
## [br]
## @schema return: Dictionary，包含 success、table、ir、report、source_path、format 和 error。
func build_table_from_text(
	source: GFConfigPipelineTableSource,
	text: String,
	options: Dictionary = {}
) -> Dictionary:
	if source == null:
		return _make_table_failure(&"", "invalid_table_source", "表来源声明为空。")
	var resolved_format: StringName = source.get_resolved_format()
	var read_result: Dictionary = {
		"success": true,
		"phase": "reader",
		"source_path": source.source_path,
		"format": resolved_format,
		"payload_kind": "text",
		"text": text,
		"size_bytes": text.to_utf8_buffer().size(),
		"error_code": OK,
		"error_kind": "",
		"error": "",
		"context": {},
	}
	var compile_result: Dictionary = _compile_table_from_reader_result(source, read_result, options)
	return _materialize_table_compile_result(compile_result, options)


## 从一组来源文件构建配置数据库资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param sources: 单表来源声明列表。
## [br]
## @schema sources: Array[GFConfigPipelineTableSource]。
## [br]
## @param options: 可选构建选项，支持 database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes。
## [br]
## @schema options: Dictionary，可包含 database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。
## [br]
## @return: 构建结果。
## [br]
## @schema return: Dictionary，包含 success、database、ir、report、table_results 和 error。
func build_database(
	sources: Array,
	options: Dictionary = {}
) -> Dictionary:
	var compilation_ir: GFConfigPipelineIR = GFConfigPipelineIR.create(
		GFVariantData.get_option_string_name(options, "database_id", &""),
		GFVariantData.get_option_string(options, "version"),
		GFVariantData.get_option_dictionary(options, "metadata")
	)
	var database: GFConfigDatabaseResource = GFConfigDatabaseResource.new()
	database.database_id = compilation_ir.get_database_id()
	database.version = compilation_ir.get_version()
	database.metadata = compilation_ir.get_metadata()

	var report_builder: GFConfigValidationReport = GFConfigValidationReport.new()
	var report: Dictionary = report_builder.make_report(database.database_id)
	var table_results: Array[Dictionary] = []
	var registered_table_keys: Dictionary = {}
	var all_tables_succeeded: bool = true
	if sources.is_empty():
		var _empty_ir_seal_result: Dictionary = compilation_ir.seal()
		report_builder.add_issue(
			report,
			"error",
			"empty_table_sources",
			database.database_id,
			null,
			&"sources",
			"配置数据库没有表来源。",
			{}
		)
		report_builder.finalize_report(report)
		return {
			"success": false,
			"database": database,
			"ir": compilation_ir,
			"report": report,
			"table_results": table_results,
			"error": "配置数据库没有表来源。",
		}

	for source_value: Variant in sources:
		if not (source_value is GFConfigPipelineTableSource):
			var invalid_source_result: Dictionary = _make_table_failure(
				&"",
				"invalid_table_source",
				"表来源声明必须是 GFConfigPipelineTableSource。"
			)
			table_results.append(_duplicate_result_dictionary(invalid_source_result))
			report_builder.merge_report(report, GFVariantData.get_option_dictionary(invalid_source_result, "report"), true)
			all_tables_succeeded = false
			continue

		var source: GFConfigPipelineTableSource = source_value
		var table_result: Dictionary = _compile_table(source, options)
		table_results.append(_duplicate_result_dictionary(table_result))
		report_builder.merge_report(report, GFVariantData.get_option_dictionary(table_result, "report"), true)
		if GFVariantData.get_option_bool(table_result, "success"):
			var table_ir: GFConfigPipelineTableIR = _get_table_ir_from_result(table_result)
			if table_ir == null:
				all_tables_succeeded = false
				continue
			var table_key: StringName = table_ir.get_table_name()
			if registered_table_keys.has(table_key):
				report_builder.add_issue(
					report,
					"error",
					"duplicate_table_source",
					database.database_id,
					null,
					&"sources",
					"配置数据库有重复表来源：%s。" % String(table_key),
					{ "table_name": table_key }
				)
				all_tables_succeeded = false
				continue

			registered_table_keys[table_key] = true
			var add_result: Dictionary = compilation_ir.add_table(table_ir)
			if not GFVariantData.get_option_bool(add_result, "success"):
				report_builder.add_issue(
					report,
					"error",
					"table_registration_failed",
					database.database_id,
					null,
					&"sources",
					GFVariantData.get_option_string(add_result, "error"),
					{ "table_name": table_key }
				)
				all_tables_succeeded = false
		else:
			all_tables_succeeded = false

	var seal_result: Dictionary = compilation_ir.seal()
	if not GFVariantData.get_option_bool(seal_result, "success"):
		report_builder.add_issue(
			report,
			"error",
			"pipeline_ir_seal_failed",
			database.database_id,
			null,
			&"ir",
			GFVariantData.get_option_string(seal_result, "error"),
			{}
		)
		all_tables_succeeded = false
	var target_result: Dictionary = _target_stage.materialize_database(compilation_ir, options)
	var target_database: GFConfigDatabaseResource = _get_database_from_result(target_result)
	if target_database != null:
		database = target_database
	else:
		all_tables_succeeded = false
	var database_report: Dictionary = GFVariantData.get_option_dictionary(target_result, "report")
	if not database_report.is_empty():
		report_builder.merge_report(report, database_report, false)
	if not GFVariantData.get_option_bool(target_result, "success"):
		all_tables_succeeded = false

	report_builder.finalize_report(report)
	return {
		"success": all_tables_succeeded and GFVariantData.get_option_bool(report, "ok"),
		"database": database,
		"ir": compilation_ir,
		"report": report,
		"table_results": table_results,
		"error": GFVariantData.get_option_string(target_result, "error"),
	}


## 从导表 Profile 构建配置数据库资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param profile: 导表 Profile 资源。
## [br]
## @schema profile: GFConfigPipelineProfile resource。
## [br]
## @param options: 本次构建覆盖选项，支持 build_options 以及 build_database() 的直接选项。
## [br]
## @schema options: Dictionary，可包含 build_options、database_id、version、metadata、validate_database、validate_schema、parse_options 和 rebuild_indexes。
## [br]
## @return: 构建结果。
## [br]
## @schema return: Dictionary，包含 success、database、report、table_results、profile_id、output_path 和 error。
func build_profile(profile: GFConfigPipelineProfile, options: Dictionary = {}) -> Dictionary:
	if profile == null:
		return _make_profile_failure(&"", "invalid_pipeline_profile", "导表 Profile 为空。")

	var profile_id: StringName = profile.profile_id
	if profile.sources.is_empty():
		return _make_profile_failure(profile_id, "empty_pipeline_sources", "导表 Profile 没有配置表来源。")

	var build_options: Dictionary = profile.make_build_options(options)
	var build_result: Dictionary = build_database(profile.sources, build_options)
	build_result["profile_id"] = profile_id
	build_result["output_path"] = profile.resolve_output_path(options)
	return build_result


## 从导表 Profile 构建并保存配置数据库资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param profile: 导表 Profile 资源。
## [br]
## @schema profile: GFConfigPipelineProfile resource。
## [br]
## @param options: 本次导出覆盖选项，支持 output_path、build_options、save_options、access_output_path、access_options、access_class_name、access_provider_accessor、changed_only、manifest_path、write_manifest、manifest_options、manifest_metadata 以及 build_database() 的直接选项。
## [br]
## @schema options: Dictionary，可包含 output_path、build_options、save_options、access_output_path、access_options、access_class_name、access_provider_accessor、database_id、version、metadata、validate_database、validate_schema、parse_options、rebuild_indexes、changed_only、manifest_path、write_manifest、manifest_options、manifest_metadata、max_freshness_file_bytes、max_freshness_total_bytes 和 max_freshness_entries；save_options、access_options 与 manifest_options 可分别包含 allow_unowned_overwrite。
## [br]
## @return: 导出结果。
## [br]
## @schema return: Dictionary，包含 success、database、report、table_results、build_result、save_result、access_result、manifest_path、manifest、manifest_result、profile_id、output_path 和 error。
func export_profile(profile: GFConfigPipelineProfile, options: Dictionary = {}) -> Dictionary:
	var build_result: Dictionary = build_profile(profile, options)
	var profile_id: StringName = GFVariantData.get_option_string_name(build_result, "profile_id")
	var output_path: String = GFVariantData.get_option_string(build_result, "output_path")
	if not GFVariantData.get_option_bool(build_result, "success"):
		return _make_profile_export_result(
			false,
			build_result,
			{},
			{},
			profile_id,
			output_path,
			GFVariantData.get_option_string(build_result, "error")
		)

	var database: GFConfigDatabaseResource = _get_database_from_result(build_result)
	var save_options: Dictionary = profile.make_save_options(options) if profile != null else {}
	var access_output_path: String = profile.resolve_access_output_path(options) if profile != null else ""
	var access_options: Dictionary = profile.make_access_options(options) if profile != null else {}
	var manifest_helper: GFConfigPipelineArtifactManifest = GFConfigPipelineArtifactManifest.new()
	manifest_helper.configure_compiler_stages(get_stage_descriptors())
	var manifest_path: String = _resolve_manifest_path(profile, options, manifest_helper)
	var should_write_manifest: bool = _should_write_manifest(options, manifest_path)
	var manifest_options: Dictionary = _make_manifest_options(options)
	if GFVariantData.get_option_bool(options, "dry_run"):
		save_options["dry_run"] = true
		access_options["dry_run"] = true
		manifest_options["dry_run"] = true
	var save_preflight_result: Dictionary = save_database(database, output_path, _make_dry_run_options(save_options))
	if not GFVariantData.get_option_bool(save_preflight_result, "success"):
		return _make_profile_export_result(
			false,
			build_result,
			save_preflight_result,
			{},
			profile_id,
			output_path,
			GFVariantData.get_option_string(save_preflight_result, "error")
		)

	var access_result: Dictionary = _make_access_result(true, "", "", OK, "", true, 0)
	if not access_output_path.is_empty() and profile != null:
		var access_preflight_result: Dictionary = generate_access(
			database,
			access_output_path,
			profile.resolve_access_class_name(options),
			profile.resolve_access_provider_accessor(options),
			_make_dry_run_options(access_options)
		)
		if not GFVariantData.get_option_bool(access_preflight_result, "success", true):
			return _make_profile_export_result(
				false,
				build_result,
				save_preflight_result,
				access_preflight_result,
				profile_id,
				output_path,
				GFVariantData.get_option_string(access_preflight_result, "error")
			)
		access_result = access_preflight_result

	var manifest: Dictionary = {}
	var manifest_result: Dictionary = {}
	if should_write_manifest:
		var preflight_run_result: Dictionary = _make_profile_export_result(
			true,
			build_result,
			save_preflight_result,
			access_result,
			profile_id,
			output_path,
			"",
			manifest_path
		)
		manifest = manifest_helper.make_manifest(
			profile.resource_path if profile != null else "",
			profile,
			options,
			preflight_run_result
		)
		manifest_result = manifest_helper.save_manifest(
			manifest_path,
			manifest,
			_make_dry_run_options(manifest_options)
		)
		if not GFVariantData.get_option_bool(manifest_result, "success"):
			return _make_profile_export_result(
				false,
				build_result,
				save_preflight_result,
				access_result,
				profile_id,
				output_path,
				GFVariantData.get_option_string(manifest_result, "error"),
				manifest_path,
				manifest_result,
				manifest
			)

	if (
		GFVariantData.get_option_bool(save_options, "dry_run")
		or GFVariantData.get_option_bool(access_options, "dry_run")
		or (should_write_manifest and GFVariantData.get_option_bool(manifest_options, "dry_run"))
	):
		return _make_profile_export_result(
			true,
			build_result,
			save_preflight_result,
			access_result,
			profile_id,
			output_path,
			"",
			manifest_path,
			manifest_result,
			manifest
		)

	var transaction_snapshot: Dictionary = _commit_stage.begin(PackedStringArray([
		output_path,
		access_output_path,
		manifest_path if should_write_manifest else "",
	]))
	if not GFVariantData.get_option_bool(transaction_snapshot, "success"):
		return _make_profile_export_result(
			false,
			build_result,
			save_preflight_result,
			access_result,
			profile_id,
			output_path,
			GFVariantData.get_option_string(transaction_snapshot, "error"),
			manifest_path,
			manifest_result,
			manifest
		)

	var save_result: Dictionary = save_database(database, output_path, save_options)
	if GFVariantData.get_option_bool(save_result, "success") and not access_output_path.is_empty() and profile != null:
		access_result = generate_access(
			database,
			access_output_path,
			profile.resolve_access_class_name(options),
			profile.resolve_access_provider_accessor(options),
			access_options
		)

	var artifacts_success: bool = (
		GFVariantData.get_option_bool(save_result, "success")
		and GFVariantData.get_option_bool(access_result, "success", true)
	)
	if artifacts_success and should_write_manifest:
		var committed_run_result: Dictionary = _make_profile_export_result(
			true,
			build_result,
			save_result,
			access_result,
			profile_id,
			output_path,
			"",
			manifest_path
		)
		manifest = manifest_helper.make_manifest(
			profile.resource_path if profile != null else "",
			profile,
			options,
			committed_run_result
		)
		manifest_result = manifest_helper.save_manifest(manifest_path, manifest, manifest_options)
	var export_success: bool = (
		artifacts_success
		and (not should_write_manifest or GFVariantData.get_option_bool(manifest_result, "success"))
	)
	var export_error: String = GFVariantData.get_option_string(save_result, "error")
	if export_error.is_empty() and not GFVariantData.get_option_bool(access_result, "success", true):
		export_error = GFVariantData.get_option_string(access_result, "error")
	if export_error.is_empty() and should_write_manifest and not GFVariantData.get_option_bool(manifest_result, "success"):
		export_error = GFVariantData.get_option_string(manifest_result, "error")
	if export_success:
		var complete_result: Dictionary = _commit_stage.complete(transaction_snapshot)
		if not GFVariantData.get_option_bool(complete_result, "success"):
			export_success = false
			export_error = _join_commit_error(complete_result)
	else:
		var rollback_result: Dictionary = _commit_stage.rollback(transaction_snapshot)
		if not GFVariantData.get_option_bool(rollback_result, "success"):
			var rollback_error: String = _join_commit_error(rollback_result)
			export_error = "%s 回滚失败：%s" % [export_error, rollback_error]
	return _make_profile_export_result(
		export_success,
		build_result,
		save_result,
		access_result,
		profile_id,
		output_path,
		export_error,
		manifest_path,
		manifest_result,
		manifest
	)


## 创建可保存为 JSON 的配置数据库导出字典。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param database: 要导出的配置数据库资源。
## [br]
## @param options: 可选导出选项，支持 include_schema、include_indexes 和 max_depth。
## [br]
## @schema options: Dictionary，可包含 include_schema、include_indexes 和 max_depth。
## [br]
## @return: JSON 兼容导出字典；数据库为空或存在不支持的 Variant 时返回空字典。
## [br]
## @schema return: Dictionary，包含 format、format_version、database_id、version、metadata 和 tables。
func make_database_export(database: GFConfigDatabaseResource, options: Dictionary = {}) -> Dictionary:
	var export_result: Dictionary = _target_stage.make_database_export(database, options)
	if GFVariantData.get_option_bool(export_result, "success"):
		return GFVariantData.get_option_dictionary(export_result, "data")
	return {}


## 保存配置数据库资源。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param database: 要保存的配置数据库资源。
## [br]
## @param output_path: 输出路径，通常为 .tres、.res 或 .json。
## [br]
## @param options: 保存选项，支持 output_format、include_schema、include_indexes、indent、sort_keys、overwrite_existing、allow_unowned_overwrite、dry_run 和 artifact_metadata。
## [br]
## @schema options: Dictionary，可包含 output_format、include_schema、include_indexes、indent、sort_keys、overwrite_existing、allow_unowned_overwrite、dry_run 和 artifact_metadata；allow_unowned_overwrite 仅用于调用方已明确确认现有文件所有权的迁移场景。
## [br]
## @return: 保存结果。
## [br]
## @schema return: Dictionary，包含 success、path、format、error_code、error、artifact_report、status、written、changed 和 dry_run。
func save_database(
	database: GFConfigDatabaseResource,
	output_path: String,
	options: Dictionary = {}
) -> Dictionary:
	if database == null:
		return _make_save_result(false, output_path, _OUTPUT_FORMAT_AUTO, ERR_INVALID_PARAMETER, "配置数据库资源为空。")
	if output_path.is_empty():
		return _make_save_result(false, output_path, _OUTPUT_FORMAT_AUTO, ERR_INVALID_PARAMETER, "输出路径为空。")

	var output_format: StringName = _resolve_output_format(output_path, options)
	var output_path_error: String = _validate_output_path_policy(output_path, options, "配置数据库")
	if not output_path_error.is_empty():
		var output_path_artifact_report: Dictionary = _make_resource_artifact_report(
			output_path,
			output_format,
			_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED,
			ERR_INVALID_PARAMETER,
			output_path_error,
			options,
			false,
			false
		)
		return _make_save_result(false, output_path, output_format, ERR_INVALID_PARAMETER, output_path_error, output_path_artifact_report)
	if output_format == _OUTPUT_FORMAT_JSON:
		return _save_database_json(database, output_path, options)
	if output_format != _OUTPUT_FORMAT_RESOURCE:
		return _make_save_result(
			false,
			output_path,
			output_format,
			ERR_UNAVAILABLE,
			"不支持的配置数据库输出格式：%s。" % String(output_format)
		)
	var ownership_error: String = _validate_existing_artifact_ownership(
		output_path,
		&"database_resource",
		options
	)
	if not ownership_error.is_empty():
		var ownership_artifact_report: Dictionary = _make_resource_artifact_report(
			output_path,
			output_format,
			_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED,
			ERR_UNAUTHORIZED,
			ownership_error,
			options,
			false,
			false
		)
		return _make_save_result(false, output_path, output_format, ERR_UNAUTHORIZED, ownership_error, ownership_artifact_report)

	var resource_artifact_report: Dictionary = _make_pending_resource_artifact_report(output_path, output_format, options)
	var pending_error: Error = _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(resource_artifact_report)
	if pending_error != OK:
		return _make_save_result(
			false,
			output_path,
			output_format,
			pending_error,
			GFVariantData.get_option_string(resource_artifact_report, "error"),
			resource_artifact_report
		)
	if GFVariantData.get_option_bool(resource_artifact_report, "dry_run"):
		return _make_save_result(true, output_path, output_format, OK, "", resource_artifact_report)

	var owned_database_value: Variant = database.duplicate(true)
	if not (owned_database_value is GFConfigDatabaseResource):
		return _make_save_result(false, output_path, output_format, ERR_CANT_CREATE, "无法创建带所有权信息的配置数据库副本。", resource_artifact_report)
	var owned_database: GFConfigDatabaseResource = owned_database_value
	owned_database.set_meta(_RESOURCE_ARTIFACT_OWNER_META, _ARTIFACT_OWNER)
	var save_error: Error = ResourceSaver.save(owned_database, output_path)
	if save_error != OK:
		var failed_artifact_report: Dictionary = _make_resource_artifact_report(
			output_path,
			output_format,
			_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED,
			save_error,
			"保存配置数据库失败：%s。" % error_string(save_error),
			options,
			false,
			GFVariantData.get_option_bool(resource_artifact_report, "changed")
		)
		return _make_save_result(false, output_path, output_format, save_error, "保存配置数据库失败：%s。" % error_string(save_error), failed_artifact_report)
	var saved_artifact_report: Dictionary = _make_resource_artifact_report(
		output_path,
		output_format,
		GFVariantData.get_option_string_name(resource_artifact_report, "status"),
		OK,
		"",
		options,
		true,
		GFVariantData.get_option_bool(resource_artifact_report, "changed")
	)
	return _make_save_result(true, output_path, output_format, OK, "", saved_artifact_report)


## 根据配置数据库生成静态访问器脚本。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param database: 要生成访问器的配置数据库资源。
## [br]
## @param output_path: 访问器脚本输出路径。
## [br]
## @param access_class_name: 生成脚本的 class_name。
## [br]
## @param provider_accessor: 无显式 provider 参数时用于获取 provider 的表达式。
## [br]
## @param options: 访问器生成选项，支持 GFConfigAccessGenerator 选项、overwrite_existing、allow_unowned_overwrite、dry_run、scan_filesystem 和 metadata。
## [br]
## @schema options: Dictionary，可包含 method_name_style、constant_prefix、record_method_pattern、table_method_pattern、include_schema_comments、include_typed_records、typed_record_method_pattern、typed_record_class_suffix、overwrite_existing、allow_unowned_overwrite、dry_run、scan_filesystem 和 metadata；allow_unowned_overwrite 仅用于调用方已明确确认现有文件所有权的迁移场景。
## [br]
## @return: 访问器生成结果。
## [br]
## @schema return: Dictionary，包含 success、skipped、path、class_name、schema_count、error_code、error 和 artifact_report。
func generate_access(
	database: GFConfigDatabaseResource,
	output_path: String,
	access_class_name: String = "GFConfigAccess",
	provider_accessor: String = "null",
	options: Dictionary = {}
) -> Dictionary:
	var class_name_value: String = access_class_name if not access_class_name.is_empty() else "GFConfigAccess"
	if database == null:
		return _make_access_result(false, output_path, class_name_value, ERR_INVALID_PARAMETER, "配置数据库资源为空。", false, 0)
	if output_path.is_empty():
		return _make_access_result(false, output_path, class_name_value, ERR_INVALID_PARAMETER, "访问器输出路径为空。", false, 0)
	var output_path_error: String = _validate_output_path_policy(output_path, options, "配置访问器")
	if not output_path_error.is_empty():
		var failure_artifact_report: Dictionary = _make_resource_artifact_report(
			output_path,
			&"gdscript",
			_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED,
			ERR_INVALID_PARAMETER,
			output_path_error,
			options,
			false,
			false
		)
		return _make_access_result(false, output_path, class_name_value, ERR_INVALID_PARAMETER, output_path_error, false, 0, failure_artifact_report)

	var schemas: Array = _collect_access_schemas(database)
	if schemas.is_empty():
		return _make_access_result(false, output_path, class_name_value, ERR_INVALID_DATA, "配置数据库没有可生成访问器的表。", false, 0)

	var accessor: String = provider_accessor if not provider_accessor.is_empty() else "null"
	var accessor_error: String = _validate_provider_accessor(accessor)
	if not accessor_error.is_empty():
		var accessor_artifact_report: Dictionary = _make_resource_artifact_report(
			output_path,
			&"gdscript",
			_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED,
			ERR_INVALID_PARAMETER,
			accessor_error,
			options,
			false,
			false
		)
		return _make_access_result(false, output_path, class_name_value, ERR_INVALID_PARAMETER, accessor_error, false, schemas.size(), accessor_artifact_report)
	var overwrite_existing: bool = GFVariantData.get_option_bool(options, "overwrite_existing", true)
	var ownership_error: String = _validate_existing_artifact_ownership(output_path, &"access", options)
	if not ownership_error.is_empty():
		var ownership_artifact_report: Dictionary = _make_resource_artifact_report(
			output_path,
			&"gdscript",
			_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED,
			ERR_UNAUTHORIZED,
			ownership_error,
			options,
			false,
			false
		)
		return _make_access_result(false, output_path, class_name_value, ERR_UNAUTHORIZED, ownership_error, false, schemas.size(), ownership_artifact_report)
	var generation_options: Dictionary = options.duplicate(true)
	generation_options["overwrite_existing"] = overwrite_existing
	generation_options["label"] = "GFConfigAccessGenerator"
	generation_options["generator_id"] = _ARTIFACT_OWNER
	var generator: GFConfigAccessGenerator = GFConfigAccessGenerator.new()
	var generated_source: String = "%s\n%s" % [
		_ACCESS_ARTIFACT_MARKER,
		generator.build_source(schemas, class_name_value, accessor, generation_options),
	]
	var artifact_report: Dictionary = _GENERATED_ARTIFACT_REPORT_SCRIPT.save_text(output_path, generated_source, generation_options)
	var generate_error: Error = _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(artifact_report)
	var access_skipped: bool = (
		GFVariantData.get_option_string_name(artifact_report, "status")
		== _GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_SKIPPED
	)
	if generate_error != OK:
		return _make_access_result(
			false,
			output_path,
			class_name_value,
			generate_error,
			"生成配置访问器失败：%s。" % error_string(generate_error),
			access_skipped,
			schemas.size(),
			artifact_report
		)
	return _make_access_result(true, output_path, class_name_value, OK, "", false, schemas.size(), artifact_report)


# --- 私有/辅助方法 ---

func _compile_table(source: GFConfigPipelineTableSource, options: Dictionary) -> Dictionary:
	var read_result: Dictionary = _reader_stage.read_source(source, options)
	return _compile_table_from_reader_result(source, read_result, options)


func _with_stage_implementation_path(descriptor: Dictionary, stage: Object) -> Dictionary:
	var result: Dictionary = descriptor.duplicate(true)
	if not GFVariantData.get_option_string(result, "implementation_path").is_empty():
		return result
	var script_value: Variant = stage.get_script()
	if script_value is Script:
		var stage_script: Script = script_value
		result["implementation_path"] = stage_script.resource_path
	else:
		result["implementation_path"] = ""
	return result


func _compile_table_from_reader_result(
	source: GFConfigPipelineTableSource,
	read_result: Dictionary,
	options: Dictionary
) -> Dictionary:
	var layout_result: Dictionary = _layout_stage.decode_source(source, read_result, options)
	return _validation_stage.compile_table(source, layout_result, options)


func _materialize_table_compile_result(
	compile_result: Dictionary,
	options: Dictionary
) -> Dictionary:
	if not GFVariantData.get_option_bool(compile_result, "success"):
		return {
			"success": false,
			"table": null,
			"ir": null,
			"report": GFVariantData.get_option_dictionary(compile_result, "report"),
			"source_path": GFVariantData.get_option_string(compile_result, "source_path"),
			"format": GFVariantData.get_option_string_name(compile_result, "format", _FORMAT_AUTO),
			"error": GFVariantData.get_option_string(compile_result, "error"),
		}

	var table_ir: GFConfigPipelineTableIR = _get_table_ir_from_result(compile_result)
	if table_ir == null:
		return _make_table_failure(
			&"",
			"missing_table_ir",
			"Validation 阶段成功但未返回 Table IR。",
			{ "source": GFVariantData.get_option_string(compile_result, "source_path") }
		)
	var target_result: Dictionary = _target_stage.materialize_table(table_ir, options)
	if not GFVariantData.get_option_bool(target_result, "success"):
		return _make_table_failure(
			table_ir.get_table_name(),
			GFVariantData.get_option_string(target_result, "error_kind", "table_target_failed"),
			GFVariantData.get_option_string(target_result, "error"),
			{
				"source": table_ir.get_source_path(),
				"actual_value": table_ir.get_source_format(),
			}
		)
	target_result["report"] = GFVariantData.get_option_dictionary(compile_result, "report")
	target_result["source_path"] = table_ir.get_source_path()
	target_result["format"] = table_ir.get_source_format()
	target_result["ir"] = table_ir
	return target_result


func _get_table_ir_from_result(result: Dictionary) -> GFConfigPipelineTableIR:
	var ir_value: Variant = GFVariantData.get_option_value(result, "ir")
	if ir_value is GFConfigPipelineTableIR:
		var table_ir: GFConfigPipelineTableIR = ir_value
		return table_ir
	return null


func _join_commit_error(result: Dictionary) -> String:
	var message: String = GFVariantData.get_option_string(result, "error")
	var issues_value: Variant = GFVariantData.get_option_value(result, "issues")
	if issues_value is PackedStringArray:
		var issues: PackedStringArray = issues_value
		if not issues.is_empty():
			return "%s %s" % [message, "; ".join(issues)]
	return message


func _make_table_failure(
	table_name: StringName,
	kind: String,
	message: String,
	context: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = GFConfigValidationReport.new().make_error_report(table_name, kind, message, context)
	return {
		"success": false,
		"table": null,
		"report": report,
		"source_path": GFVariantData.get_option_string(context, "source"),
		"format": GFVariantData.get_option_string_name(context, "actual_value", _FORMAT_AUTO),
		"error": message,
	}


func _make_save_result(
	success: bool,
	output_path: String,
	output_format: StringName,
	error_code: Error,
	message: String,
	artifact_report: Dictionary = {}
) -> Dictionary:
	return {
		"success": success,
		"path": output_path,
		"format": output_format,
		"error_code": error_code,
		"error": message,
		"artifact_report": artifact_report.duplicate(true),
		"status": GFVariantData.get_option_string_name(artifact_report, "status"),
		"written": GFVariantData.get_option_bool(artifact_report, "written"),
		"changed": GFVariantData.get_option_bool(artifact_report, "changed"),
		"dry_run": GFVariantData.get_option_bool(artifact_report, "dry_run"),
	}


func _make_profile_failure(
	profile_id: StringName,
	kind: String,
	message: String,
	context: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = GFConfigValidationReport.new().make_error_report(profile_id, kind, message, context)
	return {
		"success": false,
		"database": null,
		"report": report,
		"table_results": [],
		"profile_id": profile_id,
		"output_path": GFVariantData.get_option_string(context, "output_path"),
		"error": message,
	}


func _make_profile_export_result(
	success: bool,
	build_result: Dictionary,
	save_result: Dictionary,
	access_result: Dictionary,
	profile_id: StringName,
	output_path: String,
	message: String,
	manifest_path: String = "",
	manifest_result: Dictionary = {},
	manifest: Dictionary = {}
) -> Dictionary:
	return {
		"success": success,
		"database": _get_database_from_result(build_result),
		"report": GFVariantData.get_option_dictionary(build_result, "report"),
		"table_results": GFVariantData.get_option_array(build_result, "table_results"),
		"build_result": _duplicate_database_result_dictionary(build_result),
		"save_result": save_result.duplicate(true),
		"access_result": access_result.duplicate(true),
		"manifest_path": manifest_path,
		"manifest": manifest.duplicate(true),
		"manifest_result": manifest_result.duplicate(true),
		"profile_id": profile_id,
		"output_path": output_path,
		"error": message,
	}


func _resolve_manifest_path(
	profile: GFConfigPipelineProfile,
	options: Dictionary,
	manifest_helper: GFConfigPipelineArtifactManifest
) -> String:
	var explicit_path: String = GFVariantData.get_option_string(options, "manifest_path")
	if not explicit_path.is_empty():
		return explicit_path
	if profile == null:
		return ""
	return manifest_helper.get_default_manifest_path(profile.resolve_output_path(options))


func _should_write_manifest(options: Dictionary, manifest_path: String) -> bool:
	if manifest_path.is_empty():
		return false
	return (
		GFVariantData.get_option_bool(options, "changed_only")
		or GFVariantData.get_option_bool(options, "write_manifest")
		or not GFVariantData.get_option_string(options, "manifest_path").is_empty()
	)


func _make_manifest_options(options: Dictionary) -> Dictionary:
	var result: Dictionary = GFVariantData.get_option_dictionary(options, "manifest_options").duplicate(true)
	for key: String in PackedStringArray([
		"allow_absolute_output_path",
		"allow_gf_source_output",
		"allow_parent_output_path",
		"allow_unowned_overwrite",
	]):
		if options.has(key) and not result.has(key):
			result[key] = options[key]
	return result


func _make_access_result(
	success: bool,
	output_path: String,
	access_class_name: String,
	error_code: Error,
	message: String,
	skipped: bool,
	schema_count: int,
	artifact_report: Dictionary = {}
) -> Dictionary:
	return {
		"success": success,
		"skipped": skipped,
		"path": output_path,
		"class_name": access_class_name,
		"schema_count": schema_count,
		"error_code": error_code,
		"error": message,
		"artifact_report": artifact_report.duplicate(true),
	}


func _collect_access_schemas(database: GFConfigDatabaseResource) -> Array:
	var schemas: Array = []
	if database == null:
		return schemas

	var table_ids: PackedStringArray = database.get_table_ids()
	for table_id: String in table_ids:
		var table_resource: GFConfigTableResource = database.get_table_resource(StringName(table_id), false)
		if table_resource == null:
			continue
		if table_resource.schema != null:
			schemas.append(table_resource.schema)
		else:
			schemas.append({ "table_name": table_resource.get_table_key() })
	return schemas


func _get_database_from_result(result: Dictionary) -> GFConfigDatabaseResource:
	var database_value: Variant = GFVariantData.get_option_value(result, "database")
	if database_value is GFConfigDatabaseResource:
		var database: GFConfigDatabaseResource = database_value
		return database
	return null


func _duplicate_result_dictionary(result: Dictionary) -> Dictionary:
	return _duplicate_dictionary_without_keys(result, { "table": true, "ir": true })


func _duplicate_database_result_dictionary(result: Dictionary) -> Dictionary:
	return _duplicate_dictionary_without_keys(result, { "database": true, "ir": true })


func _duplicate_dictionary_without_keys(result: Dictionary, skipped_keys: Dictionary) -> Dictionary:
	var copy: Dictionary = {}
	for key: Variant in result.keys():
		if skipped_keys.has(key):
			continue
		copy[key] = GFVariantData.duplicate_variant(result[key])
	return copy


func _validate_existing_artifact_ownership(
	output_path: String,
	artifact_kind: StringName,
	options: Dictionary
) -> String:
	if not FileAccess.file_exists(output_path):
		return ""
	if not GFVariantData.get_option_bool(options, "overwrite_existing", true):
		return ""
	if GFVariantData.get_option_bool(options, "allow_unowned_overwrite", false):
		return ""
	if _is_owned_artifact(output_path, artifact_kind):
		return ""
	return "拒绝覆盖不属于 GF Config Pipeline 的已有产物：%s。若已人工确认所有权，请显式传入 allow_unowned_overwrite。" % output_path


func _is_owned_artifact(output_path: String, artifact_kind: StringName) -> bool:
	if artifact_kind == &"database_resource":
		var loaded_value: Variant = ResourceLoader.load(output_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		if loaded_value is Resource:
			var loaded_resource: Resource = loaded_value
			return GFVariantData.to_text(loaded_resource.get_meta(_RESOURCE_ARTIFACT_OWNER_META, "")) == _ARTIFACT_OWNER
		return false
	var file: FileAccess = FileAccess.open(output_path, FileAccess.READ)
	if file == null:
		return false
	var prefix_size: int = mini(file.get_length(), 64 * 1024)
	var prefix: String = file.get_buffer(prefix_size).get_string_from_utf8()
	file.close()
	if artifact_kind == &"access":
		return prefix.begins_with(_ACCESS_ARTIFACT_MARKER)
	if artifact_kind == &"database_json":
		return (
			prefix.contains("\"%s\": \"%s\"" % [_ARTIFACT_OWNER_FIELD, _ARTIFACT_OWNER])
			or prefix.contains("\"%s\":\"%s\"" % [_ARTIFACT_OWNER_FIELD, _ARTIFACT_OWNER])
		)
	return false


func _validate_provider_accessor(accessor: String) -> String:
	if accessor.length() > _MAX_PROVIDER_ACCESSOR_LENGTH:
		return "provider_accessor 超过最大长度 %d。" % _MAX_PROVIDER_ACCESSOR_LENGTH
	if accessor.contains("\n") or accessor.contains("\r"):
		return "provider_accessor 必须是单行表达式。"
	for forbidden: String in PackedStringArray([";", "#", "\\", "="]):
		if accessor.contains(forbidden):
			return "provider_accessor 包含不允许的语句字符：%s。" % forbidden
	var expected_closings: PackedStringArray = PackedStringArray()
	var quote: String = ""
	var escaped: bool = false
	for index: int in range(accessor.length()):
		var character: String = accessor.substr(index, 1)
		if not quote.is_empty():
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote:
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
		elif character == "(":
			var _round_appended: bool = expected_closings.append(")")
		elif character == "[":
			var _square_appended: bool = expected_closings.append("]")
		elif character == "{":
			var _curly_appended: bool = expected_closings.append("}")
		elif character == ")" or character == "]" or character == "}":
			if expected_closings.is_empty() or expected_closings[expected_closings.size() - 1] != character:
				return "provider_accessor 的括号不匹配。"
			var _closing_removed: String = expected_closings[expected_closings.size() - 1]
			var _resize_result: int = expected_closings.resize(expected_closings.size() - 1)
	if not quote.is_empty() or not expected_closings.is_empty():
		return "provider_accessor 包含未闭合的字符串或括号。"
	return ""


func _make_pending_resource_artifact_report(
	output_path: String,
	output_format: StringName,
	options: Dictionary
) -> Dictionary:
	var exists: bool = FileAccess.file_exists(output_path)
	var status: StringName = _GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_CHANGED if exists else _GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_NEW
	var overwrite_existing: bool = GFVariantData.get_option_bool(options, "overwrite_existing", true)
	if exists and not overwrite_existing:
		var skipped_message: String = "目标文件已存在，已跳过：%s" % output_path
		push_warning("[GFConfigPipeline] %s" % skipped_message)
		return _make_resource_artifact_report(
			output_path,
			output_format,
			_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_SKIPPED,
			ERR_ALREADY_EXISTS,
			skipped_message,
			options,
			false,
			true
		)

	return _make_resource_artifact_report(
		output_path,
		output_format,
		status,
		OK,
		"",
		options,
		false,
		true
	)


func _make_resource_artifact_report(
	output_path: String,
	output_format: StringName,
	status: StringName,
	error_code: Error,
	message: String,
	options: Dictionary,
	written: bool,
	changed: bool
) -> Dictionary:
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.make_report(output_path, status, error_code, message, {
		"written": written,
		"changed": changed,
		"dry_run": GFVariantData.get_option_bool(options, "dry_run", false),
		"metadata": _make_artifact_metadata(options, output_format),
	})


func _make_text_artifact_options(options: Dictionary, output_format: StringName) -> Dictionary:
	var artifact_options: Dictionary = options.duplicate(true)
	artifact_options["label"] = "GFConfigPipeline"
	artifact_options["metadata"] = _make_artifact_metadata(options, output_format)
	return artifact_options


func _make_artifact_metadata(options: Dictionary, output_format: StringName) -> Dictionary:
	var metadata: Dictionary = GFVariantData.get_option_dictionary(options, "artifact_metadata").duplicate(true)
	metadata["format"] = output_format
	return metadata


func _make_dry_run_options(options: Dictionary) -> Dictionary:
	var result: Dictionary = options.duplicate(true)
	result["dry_run"] = true
	return result


func _validate_output_path_policy(output_path: String, options: Dictionary, artifact_label: String) -> String:
	var raw_path: String = output_path.replace("\\", "/").strip_edges()
	if raw_path.is_empty():
		return "%s输出路径为空。" % artifact_label
	if _has_unsupported_output_scheme(raw_path):
		return "%s输出路径使用了不支持的 URI scheme：%s。" % [artifact_label, output_path]
	if _path_has_parent_segment(raw_path) and not GFVariantData.get_option_bool(options, "allow_parent_output_path", false):
		return "%s输出路径不能包含父级越界片段：%s。" % [artifact_label, output_path]
	if _is_filesystem_absolute_path(raw_path):
		return "%s输出路径不能是绝对文件系统路径：%s。" % [artifact_label, output_path]
	var normalized_path: String = _normalize_output_path(raw_path)
	if _is_gf_source_output_path(normalized_path) and not GFVariantData.get_option_bool(options, "allow_gf_source_output", false):
		return "%s输出路径不能写入 GF 框架源码目录：%s。" % [artifact_label, output_path]
	return ""


func _normalize_output_path(path: String) -> String:
	var normalized: String = path.replace("\\", "/").strip_edges()
	if normalized.contains("://"):
		var scheme: String = normalized.get_slice("://", 0).to_lower()
		var body: String = normalized.get_slice("://", 1).simplify_path()
		return "%s://%s" % [scheme, body]
	return normalized.simplify_path()


func _path_has_parent_segment(path: String) -> bool:
	var body: String = path
	if path.contains("://"):
		body = path.get_slice("://", 1)
	var parts: PackedStringArray = body.split("/", false)
	for part: String in parts:
		if part == "..":
			return true
	return false


func _is_filesystem_absolute_path(path: String) -> bool:
	var lower_path: String = path.to_lower()
	if lower_path.begins_with("res://") or lower_path.begins_with("user://"):
		return false
	if path.is_absolute_path():
		return true
	return path.length() >= 3 and path.substr(1, 2) == ":/"


func _has_unsupported_output_scheme(path: String) -> bool:
	var lower_path: String = path.to_lower()
	if not lower_path.contains("://"):
		return false
	return not (lower_path.begins_with("res://") or lower_path.begins_with("user://"))


func _is_gf_source_output_path(path: String) -> bool:
	var lower_path: String = path.to_lower()
	var gf_source_root: String = "res://addons".path_join("gf")
	return lower_path == gf_source_root or lower_path.begins_with(gf_source_root.path_join(""))


func _resolve_output_format(output_path: String, options: Dictionary) -> StringName:
	var configured_format: StringName = GFVariantData.get_option_string_name(options, "output_format", _OUTPUT_FORMAT_AUTO)
	if configured_format != &"" and configured_format != _OUTPUT_FORMAT_AUTO:
		return configured_format

	var extension: String = output_path.get_extension().to_lower()
	if extension == "json":
		return _OUTPUT_FORMAT_JSON
	return _OUTPUT_FORMAT_RESOURCE


func _save_database_json(
	database: GFConfigDatabaseResource,
	output_path: String,
	options: Dictionary
) -> Dictionary:
	var ownership_error: String = _validate_existing_artifact_ownership(output_path, &"database_json", options)
	if not ownership_error.is_empty():
		var ownership_artifact_report: Dictionary = _make_resource_artifact_report(
			output_path,
			_OUTPUT_FORMAT_JSON,
			_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED,
			ERR_UNAUTHORIZED,
			ownership_error,
			options,
			false,
			false
		)
		return _make_save_result(false, output_path, _OUTPUT_FORMAT_JSON, ERR_UNAUTHORIZED, ownership_error, ownership_artifact_report)
	var export_result: Dictionary = _target_stage.make_database_json(database, options)
	if not GFVariantData.get_option_bool(export_result, "success"):
		return _make_save_result(
			false,
			output_path,
			_OUTPUT_FORMAT_JSON,
			ERR_INVALID_DATA,
			GFVariantData.get_option_string(export_result, "error")
		)

	var json_text: String = GFVariantData.get_option_string(export_result, "text")
	var artifact_options: Dictionary = _make_text_artifact_options(options, _OUTPUT_FORMAT_JSON)
	var artifact_report: Dictionary = _GENERATED_ARTIFACT_REPORT_SCRIPT.save_text(output_path, json_text, artifact_options)
	var save_error: Error = _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(artifact_report)
	if save_error != OK:
		return _make_save_result(
			false,
			output_path,
			_OUTPUT_FORMAT_JSON,
			save_error,
			GFVariantData.get_option_string(artifact_report, "error"),
			artifact_report
		)
	return _make_save_result(true, output_path, _OUTPUT_FORMAT_JSON, OK, "", artifact_report)
