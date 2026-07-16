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
const _FORMAT_CSV: StringName = &"csv"
const _FORMAT_JSON: StringName = &"json"
const _FORMAT_CONFIG_FILE: StringName = &"config_file"
const _FORMAT_XLSX: StringName = &"xlsx"
const _OUTPUT_FORMAT_AUTO: StringName = &"auto"
const _OUTPUT_FORMAT_JSON: StringName = &"json"
const _OUTPUT_FORMAT_RESOURCE: StringName = &"resource"
const _JSON_EXPORT_FORMAT: String = "gf.config.database"
const _JSON_EXPORT_VERSION: int = 1
const _ARTIFACT_OWNER: String = "gf.tool.config_pipeline"
const _ARTIFACT_OWNER_FIELD: String = "artifact_owner"
const _RESOURCE_ARTIFACT_OWNER_META: StringName = &"_gf_config_pipeline_artifact_owner"
const _ACCESS_ARTIFACT_MARKER: String = "# @generated_by gf.tool.config_pipeline"
const _JSON_VARIANT_TYPE_KEY: String = "__gf_variant_type"
const _JSON_VARIANT_VALUE_KEY: String = "value"
const _DEFAULT_JSON_INDENT: String = "\t"
const _DEFAULT_MAX_SOURCE_FILE_BYTES: int = 64 * 1024 * 1024
const _MAX_PROVIDER_ACCESSOR_LENGTH: int = 512
const _DEFAULT_MAX_XLSX_ENTRY_BYTES: int = 8 * 1024 * 1024
const _DEFAULT_MAX_XLSX_FILE_BYTES: int = 64 * 1024 * 1024
const _DEFAULT_MAX_XLSX_ENTRY_COUNT: int = 4096
const _DEFAULT_MAX_XLSX_SHARED_STRINGS: int = 100000
const _DEFAULT_MAX_XLSX_ROWS: int = 100000
const _DEFAULT_MAX_XLSX_COLUMNS: int = 512
const _GENERATED_ARTIFACT_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")


# --- 公共方法 ---

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
## @schema return: Dictionary，包含 success、table、report、source_path、format 和 error。
func build_table(source: GFConfigPipelineTableSource, options: Dictionary = {}) -> Dictionary:
	if source == null:
		return _make_table_failure(&"", "invalid_table_source", "表来源声明为空。")

	var resolved_format: StringName = source.get_resolved_format()
	if resolved_format == _FORMAT_XLSX:
		return _build_table_from_xlsx(source, options)

	var read_result: Dictionary = _read_text_file(source.source_path, source.get_table_key(), options)
	if not GFVariantData.get_option_bool(read_result, "success"):
		return read_result
	return build_table_from_text(source, GFVariantData.get_option_string(read_result, "text"), options)


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
## @schema return: Dictionary，包含 success、table、report、source_path、format 和 error。
func build_table_from_text(
	source: GFConfigPipelineTableSource,
	text: String,
	options: Dictionary = {}
) -> Dictionary:
	if source == null:
		return _make_table_failure(&"", "invalid_table_source", "表来源声明为空。")

	var table_name: StringName = source.get_table_key()
	if table_name == &"":
		return _make_table_failure(&"", "empty_table_name", "无法确定配置表名。")

	var resolved_format: StringName = source.get_resolved_format()
	if not _is_supported_format(resolved_format):
		return _make_table_failure(
			table_name,
			"unsupported_source_format",
			"不支持的配置表来源格式：%s。" % String(resolved_format),
			{
				"source": source.source_path,
				"actual_value": resolved_format,
				"supported_formats": [String(_FORMAT_CSV), String(_FORMAT_JSON), String(_FORMAT_CONFIG_FILE)],
			}
		)

	var parse_result: Dictionary = _parse_table_text(source, text, resolved_format, options)
	if not GFVariantData.get_option_bool(parse_result, "success"):
		return _make_table_failure(
			table_name,
			"parse_failed",
			GFVariantData.get_option_string(parse_result, "error"),
			{
				"source": source.source_path,
				"line": GFVariantData.get_option_int(parse_result, "error_line"),
				"column": GFVariantData.get_option_int(parse_result, "error_column"),
			}
		)

	return _build_table_from_parse_result(source, table_name, resolved_format, parse_result, options)


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
## @schema return: Dictionary，包含 success、database、report、table_results 和 error。
func build_database(
	sources: Array,
	options: Dictionary = {}
) -> Dictionary:
	var database: GFConfigDatabaseResource = GFConfigDatabaseResource.new()
	database.database_id = GFVariantData.get_option_string_name(options, "database_id", &"")
	database.version = GFVariantData.get_option_string(options, "version")
	database.metadata = GFVariantData.get_option_dictionary(options, "metadata").duplicate(true)

	var report_builder: GFConfigValidationReport = GFConfigValidationReport.new()
	var report: Dictionary = report_builder.make_report(database.database_id)
	var table_results: Array[Dictionary] = []
	var registered_table_keys: Dictionary = {}
	var all_tables_succeeded: bool = true
	if sources.is_empty():
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
		var table_result: Dictionary = build_table(source, options)
		table_results.append(_duplicate_result_dictionary(table_result))
		report_builder.merge_report(report, GFVariantData.get_option_dictionary(table_result, "report"), true)
		if GFVariantData.get_option_bool(table_result, "success"):
			var table: GFConfigTableResource = _get_table_from_result(table_result)
			if table != null:
				var table_key: StringName = table.get_table_key()
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
				var registered: bool = database.register_table(table)
				if not registered:
					report_builder.add_issue(
						report,
						"error",
						"table_registration_failed",
						database.database_id,
						null,
						&"sources",
						"配置表注册失败：%s。" % String(table_key),
						{ "table_name": table_key }
					)
					all_tables_succeeded = false
		else:
			all_tables_succeeded = false

	if GFVariantData.get_option_bool(options, "validate_database", true):
		var validate_options: Dictionary = options.duplicate(true)
		if not validate_options.has("validate_schema"):
			validate_options["validate_schema"] = false
		var database_report: Dictionary = database.validate_database(validate_options)
		report_builder.merge_report(report, database_report, false)

	report_builder.finalize_report(report)
	return {
		"success": all_tables_succeeded and GFVariantData.get_option_bool(report, "ok"),
		"database": database,
		"report": report,
		"table_results": table_results,
		"error": "",
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

	var transaction_snapshot: Dictionary = _capture_export_snapshots(PackedStringArray([
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
		_discard_export_snapshots(transaction_snapshot)
	else:
		var rollback_issues: PackedStringArray = _restore_export_snapshots(transaction_snapshot)
		if not rollback_issues.is_empty():
			export_error = "%s 回滚失败：%s" % [export_error, "; ".join(rollback_issues)]
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
	var export_result: Dictionary = _make_database_export_result(database, options)
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

func _read_text_file(path: String, table_name: StringName, options: Dictionary) -> Dictionary:
	if path.is_empty():
		return _make_table_failure(table_name, "missing_source_path", "配置表来源路径为空。")

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		return _make_table_failure(
			table_name,
			"source_read_failed",
			"读取配置表来源失败：%s。" % error_string(open_error),
			{
				"source": path,
				"error_code": open_error,
			}
		)
	var max_source_file_bytes: int = GFVariantData.get_option_int(
		options,
		"max_source_file_bytes",
		_DEFAULT_MAX_SOURCE_FILE_BYTES
	)
	var source_size: int = file.get_length()
	if max_source_file_bytes >= 0 and source_size > max_source_file_bytes:
		file.close()
		return _make_table_failure(
			table_name,
			"source_budget_exceeded",
			"配置表来源超过 max_source_file_bytes：%d > %d。" % [source_size, max_source_file_bytes],
			{
				"source": path,
				"actual_value": source_size,
				"expected_value": max_source_file_bytes,
			}
		)

	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		return _make_table_failure(
			table_name,
			"source_read_failed",
			"读取配置表来源失败：%s。" % error_string(read_error),
			{
				"source": path,
				"error_code": read_error,
			}
		)
	return {
		"success": true,
		"text": text,
		"report": GFConfigValidationReport.new().make_report(table_name),
		"source_path": path,
		"format": _FORMAT_AUTO,
		"error": "",
	}


func _parse_table_text(
	source: GFConfigPipelineTableSource,
	text: String,
	resolved_format: StringName,
	options: Dictionary
) -> Dictionary:
	var parse_options: Dictionary = source.parse_options.duplicate(true)
	var _merge_parse_options_result: Dictionary = GFVariantData.merge_dictionary(parse_options, GFVariantData.get_option_dictionary(options, "parse_options"))
	if not source.source_path.is_empty():
		parse_options["source"] = source.source_path

	if resolved_format == _FORMAT_CSV:
		return GFConfigTableImporter.parse_csv_table(text, parse_options)
	if resolved_format == _FORMAT_JSON:
		return GFConfigTableImporter.parse_json_table(text, parse_options)
	if resolved_format == _FORMAT_CONFIG_FILE:
		return GFConfigTableImporter.parse_config_file_table(text, parse_options)
	return {
		"success": false,
		"data": null,
		"error": "unsupported_source_format",
		"error_line": 0,
		"error_column": 0,
		"source": source.source_path,
	}


func _build_table_from_xlsx(source: GFConfigPipelineTableSource, options: Dictionary) -> Dictionary:
	var table_name: StringName = source.get_table_key()
	if table_name == &"":
		return _make_table_failure(&"", "empty_table_name", "无法确定配置表名。")
	if source.source_path.is_empty():
		return _make_table_failure(table_name, "missing_source_path", "配置表来源路径为空。")

	var parse_options: Dictionary = source.parse_options.duplicate(true)
	var _merge_parse_options_result: Dictionary = GFVariantData.merge_dictionary(parse_options, GFVariantData.get_option_dictionary(options, "parse_options"))
	if not source.source_path.is_empty():
		parse_options["source"] = source.source_path

	var parse_result: Dictionary = _parse_xlsx_file(source.source_path, parse_options)
	if not GFVariantData.get_option_bool(parse_result, "success"):
		return _make_table_failure(
			table_name,
			"parse_failed",
			GFVariantData.get_option_string(parse_result, "error"),
			{
				"source": source.source_path,
				"actual_value": _FORMAT_XLSX,
				"line": GFVariantData.get_option_int(parse_result, "error_line"),
				"column": GFVariantData.get_option_int(parse_result, "error_column"),
			}
		)
	return _build_table_from_parse_result(source, table_name, _FORMAT_XLSX, parse_result, options)


func _build_table_from_parse_result(
	source: GFConfigPipelineTableSource,
	table_name: StringName,
	resolved_format: StringName,
	parse_result: Dictionary,
	options: Dictionary
) -> Dictionary:
	var records_result: Dictionary = _normalize_records(GFVariantData.get_option_value(parse_result, "data"))
	if not GFVariantData.get_option_bool(records_result, "success"):
		return _make_table_failure(
			table_name,
			"invalid_table_data",
			"配置表数据必须是 Array[Dictionary] 或 Dictionary[String, Dictionary]。",
			{
				"source": source.source_path,
				"actual_value": GFVariantData.get_option_string(records_result, "actual_value"),
				"expected_value": "Array[Dictionary] or Dictionary[String, Dictionary]",
			}
		)

	var records: Array[Dictionary] = _get_result_records(records_result)
	var typed_header_result: Dictionary = _apply_typed_header_schema(source, table_name, records, parse_result)
	if not GFVariantData.get_option_bool(typed_header_result, "success", true):
		var typed_header_context: Dictionary = GFVariantData.get_option_dictionary(typed_header_result, "context")
		if not source.source_path.is_empty():
			typed_header_context["source"] = source.source_path
		return _make_table_failure(
			table_name,
			GFVariantData.get_option_string(typed_header_result, "kind", "invalid_typed_header"),
			GFVariantData.get_option_string(typed_header_result, "error"),
			typed_header_context
		)

	records = _get_result_records(typed_header_result)
	var declared_schema: GFConfigTableSchema = _get_schema_from_result(typed_header_result)
	var schema: GFConfigTableSchema = _resolve_schema(source, table_name, records, declared_schema)
	var report: Dictionary = _validate_table_source(source, table_name, records, schema, parse_result)
	if schema != null and schema.coerce_values and source.coerce_records and GFVariantData.get_option_bool(report, "ok"):
		records = _coerce_records(records, schema)

	var table: GFConfigTableResource = GFConfigTableResource.new()
	table.table_name = table_name
	table.schema = schema
	table.records = records
	table.metadata = _make_table_metadata(source, resolved_format)
	if GFVariantData.get_option_bool(options, "rebuild_indexes", true):
		var _id_index_count: int = table.rebuild_index()
		var _named_index_count: int = table.rebuild_indexes()

	return {
		"success": GFVariantData.get_option_bool(report, "ok"),
		"table": table,
		"report": report,
		"source_path": source.source_path,
		"format": resolved_format,
		"error": "",
	}


func _parse_xlsx_file(path: String, options: Dictionary) -> Dictionary:
	var file_limit: int = _get_xlsx_limit(options, "max_xlsx_file_bytes", _DEFAULT_MAX_XLSX_FILE_BYTES)
	var size_file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if size_file == null:
		return _make_xlsx_parse_failure("XLSX open failed: %s" % error_string(FileAccess.get_open_error()), path)
	var file_size: int = int(size_file.get_length())
	size_file.close()
	if _is_xlsx_limit_exceeded(file_size, file_limit):
		return _make_xlsx_parse_failure("XLSX file exceeds max_xlsx_file_bytes.", path)

	var reader: ZIPReader = ZIPReader.new()
	var open_error: Error = reader.open(path)
	if open_error != OK:
		return _make_xlsx_parse_failure("XLSX open failed: %s" % error_string(open_error), path)

	var files: PackedStringArray = reader.get_files()
	if _is_xlsx_limit_exceeded(files.size(), _get_xlsx_limit(options, "max_xlsx_entry_count", _DEFAULT_MAX_XLSX_ENTRY_COUNT)):
		_close_zip_reader(reader)
		return _make_xlsx_parse_failure("XLSX archive exceeds max_xlsx_entry_count.", path)
	var shared_strings_result: Dictionary = _read_xlsx_shared_strings(reader, files, options)
	if not GFVariantData.get_option_bool(shared_strings_result, "success"):
		_close_zip_reader(reader)
		return _make_xlsx_parse_failure(GFVariantData.get_option_string(shared_strings_result, "error"), path)
	var shared_strings: PackedStringArray = _get_packed_string_array_value(GFVariantData.get_option_value(shared_strings_result, "strings"))
	var workbook_sheets: Array[Dictionary] = _read_xlsx_workbook_sheets(reader, files)
	var worksheet_path: String = _resolve_xlsx_worksheet_path(files, workbook_sheets, options)
	if worksheet_path.is_empty():
		_close_zip_reader(reader)
		return _make_xlsx_parse_failure("XLSX sheet not found.", path)

	var worksheet_bytes: PackedByteArray = _zip_read_bytes(reader, files, worksheet_path)
	_close_zip_reader(reader)
	if worksheet_bytes.size() == 0:
		return _make_xlsx_parse_failure("XLSX worksheet is empty: %s" % worksheet_path, path)
	if _is_xlsx_limit_exceeded(worksheet_bytes.size(), _get_xlsx_limit(options, "max_xlsx_entry_bytes", _DEFAULT_MAX_XLSX_ENTRY_BYTES)):
		return _make_xlsx_parse_failure("XLSX worksheet exceeds max_xlsx_entry_bytes: %s." % worksheet_path, path)
	return _parse_xlsx_sheet(worksheet_bytes, shared_strings, options)


func _read_xlsx_shared_strings(reader: ZIPReader, files: PackedStringArray, options: Dictionary) -> Dictionary:
	var result: PackedStringArray = PackedStringArray()
	var bytes: PackedByteArray = _zip_read_bytes(reader, files, "xl/sharedStrings.xml")
	if bytes.size() == 0:
		return _make_xlsx_shared_strings_result(true, result)
	if _is_xlsx_limit_exceeded(bytes.size(), _get_xlsx_limit(options, "max_xlsx_entry_bytes", _DEFAULT_MAX_XLSX_ENTRY_BYTES)):
		return _make_xlsx_shared_strings_result(false, result, "XLSX sharedStrings.xml exceeds max_xlsx_entry_bytes.")

	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return _make_xlsx_shared_strings_result(false, result, "XLSX sharedStrings.xml parse failed: %s" % error_string(open_error))

	var max_shared_strings: int = _get_xlsx_limit(options, "max_xlsx_shared_strings", _DEFAULT_MAX_XLSX_SHARED_STRINGS)
	var current_text: String = ""
	var in_shared_string: bool = false
	var in_text: bool = false
	while parser.read() == OK:
		var node_type: XMLParser.NodeType = parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name: String = parser.get_node_name()
			if node_name == "si":
				in_shared_string = true
				current_text = ""
			elif in_shared_string and node_name == "t":
				in_text = true
		elif node_type == XMLParser.NODE_TEXT or node_type == XMLParser.NODE_CDATA:
			if in_shared_string and in_text:
				current_text += parser.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name: String = parser.get_node_name()
			if end_name == "t":
				in_text = false
			elif end_name == "si":
				if _is_xlsx_limit_exceeded(result.size() + 1, max_shared_strings):
					return _make_xlsx_shared_strings_result(false, result, "XLSX shared string count exceeds max_xlsx_shared_strings.")
				var _text_appended: bool = result.append(current_text)
				in_shared_string = false
				in_text = false
				current_text = ""
	return _make_xlsx_shared_strings_result(true, result)


func _make_xlsx_shared_strings_result(
	success: bool,
	strings: PackedStringArray,
	error: String = ""
) -> Dictionary:
	return {
		"success": success,
		"strings": strings.duplicate(),
		"error": error,
	}


func _read_xlsx_workbook_sheets(reader: ZIPReader, files: PackedStringArray) -> Array[Dictionary]:
	var workbook_bytes: PackedByteArray = _zip_read_bytes(reader, files, "xl/workbook.xml")
	if workbook_bytes.size() == 0:
		return []

	var sheets: Array[Dictionary] = _parse_xlsx_workbook_sheet_entries(workbook_bytes)
	var relationships: Dictionary = _parse_xlsx_workbook_relationships(_zip_read_bytes(reader, files, "xl/_rels/workbook.xml.rels"))
	for sheet: Dictionary in sheets:
		var relation_id: String = GFVariantData.get_option_string(sheet, "relation_id")
		var target: String = GFVariantData.get_option_string(relationships, relation_id)
		if not target.is_empty():
			sheet["path"] = _normalize_xlsx_relationship_target("xl/workbook.xml", target)
	return sheets


func _parse_xlsx_workbook_sheet_entries(bytes: PackedByteArray) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return result

	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if parser.get_node_name() != "sheet":
			continue

		var entry: Dictionary = {
			"name": _get_xml_attribute(parser, "name"),
			"sheet_id": _get_xml_attribute(parser, "sheetId"),
			"relation_id": _get_xml_attribute_any(parser, PackedStringArray(["r:id", "id"])),
			"path": "",
		}
		result.append(entry)
	return result


func _parse_xlsx_workbook_relationships(bytes: PackedByteArray) -> Dictionary:
	var result: Dictionary = {}
	if bytes.size() == 0:
		return result

	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return result

	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if parser.get_node_name() != "Relationship":
			continue

		var relation_id: String = _get_xml_attribute(parser, "Id")
		if relation_id.is_empty():
			continue
		result[relation_id] = _get_xml_attribute(parser, "Target")
	return result


func _resolve_xlsx_worksheet_path(
	files: PackedStringArray,
	sheets: Array[Dictionary],
	options: Dictionary
) -> String:
	var sheet_name: String = GFVariantData.get_option_string(options, "sheet_name")
	if not sheet_name.is_empty():
		for sheet: Dictionary in sheets:
			if GFVariantData.get_option_string(sheet, "name") != sheet_name:
				continue
			var named_path: String = GFVariantData.get_option_string(sheet, "path")
			return named_path if _zip_has_file(files, named_path) else ""
		return ""

	var sheet_index: int = maxi(GFVariantData.get_option_int(options, "sheet_index", 0), 0)
	if sheet_index < sheets.size():
		var sheet: Dictionary = sheets[sheet_index]
		var indexed_path: String = GFVariantData.get_option_string(sheet, "path")
		if _zip_has_file(files, indexed_path):
			return indexed_path

	var fallback_path: String = "xl/worksheets/sheet%d.xml" % (sheet_index + 1)
	return fallback_path if _zip_has_file(files, fallback_path) else ""


func _parse_xlsx_sheet(
	bytes: PackedByteArray,
	shared_strings: PackedStringArray,
	options: Dictionary
) -> Dictionary:
	var parser: XMLParser = XMLParser.new()
	var open_error: Error = parser.open_buffer(bytes)
	if open_error != OK:
		return _make_xlsx_parse_failure("XLSX worksheet parse failed: %s" % error_string(open_error), GFVariantData.get_option_string(options, "source"))

	var rows: Array[Dictionary] = []
	var max_rows: int = _get_xlsx_limit(options, "max_xlsx_rows", _DEFAULT_MAX_XLSX_ROWS)
	var max_columns: int = _get_xlsx_limit(options, "max_xlsx_columns", _DEFAULT_MAX_XLSX_COLUMNS)
	var current_cells: Dictionary = {}
	var current_row_number: int = 0
	var row_fallback_number: int = 0
	var current_cell_ref: String = ""
	var current_cell_type: String = ""
	var current_cell_value: String = ""
	var in_cell: bool = false
	var in_value: bool = false
	var in_inline_text: bool = false

	while parser.read() == OK:
		var node_type: XMLParser.NodeType = parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT:
			var node_name: String = parser.get_node_name()
			if node_name == "row":
				row_fallback_number += 1
				current_row_number = _parse_positive_int(_get_xml_attribute(parser, "r"), row_fallback_number)
				current_cells = {}
			elif node_name == "c":
				in_cell = true
				current_cell_ref = _get_xml_attribute(parser, "r")
				current_cell_type = _get_xml_attribute(parser, "t")
				current_cell_value = ""
			elif in_cell and node_name == "v":
				in_value = true
			elif in_cell and current_cell_type == "inlineStr" and node_name == "t":
				in_inline_text = true
		elif node_type == XMLParser.NODE_TEXT or node_type == XMLParser.NODE_CDATA:
			if in_value or in_inline_text:
				current_cell_value += parser.get_node_data()
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var end_name: String = parser.get_node_name()
			if end_name == "v":
				in_value = false
			elif end_name == "t":
				in_inline_text = false
			elif end_name == "c":
				var column_index: int = _xlsx_column_index_from_cell_ref(current_cell_ref)
				if column_index >= 0:
					if _is_xlsx_limit_exceeded(column_index + 1, max_columns):
						return _make_xlsx_parse_failure(
							"XLSX column count exceeds max_xlsx_columns.",
							GFVariantData.get_option_string(options, "source"),
							current_row_number,
							column_index + 1
						)
					var cell_result: Dictionary = _resolve_xlsx_cell_value(current_cell_value, current_cell_type, shared_strings)
					if not GFVariantData.get_option_bool(cell_result, "success"):
						return _make_xlsx_parse_failure(
							GFVariantData.get_option_string(cell_result, "error"),
							GFVariantData.get_option_string(options, "source"),
							current_row_number,
							column_index + 1
						)
					current_cells[column_index] = GFVariantData.get_option_string(cell_result, "value")
				in_cell = false
				in_value = false
				in_inline_text = false
			elif end_name == "row":
				if _is_xlsx_limit_exceeded(rows.size() + 1, max_rows):
					return _make_xlsx_parse_failure(
						"XLSX row count exceeds max_xlsx_rows.",
						GFVariantData.get_option_string(options, "source"),
						current_row_number,
						1
					)
				rows.append({
					"row_number": current_row_number,
					"cells": current_cells.duplicate(true),
				})
				current_cells = {}

	return _xlsx_rows_to_parse_result(rows, options)


func _xlsx_rows_to_parse_result(rows: Array[Dictionary], options: Dictionary) -> Dictionary:
	var trim_cells: bool = GFVariantData.get_option_bool(options, "trim_cells", true)
	var parsed_rows: Array[PackedStringArray] = []
	var row_numbers: PackedInt32Array = PackedInt32Array()
	for row_info: Dictionary in rows:
		var row_number: int = GFVariantData.get_option_int(row_info, "row_number")
		var cells: Dictionary = GFVariantData.get_option_dictionary(row_info, "cells")
		parsed_rows.append(_xlsx_cells_to_row(cells, trim_cells))
		var _row_number_appended: bool = row_numbers.append(row_number)

	var row_options: Dictionary = options.duplicate(true)
	row_options["row_numbers"] = row_numbers
	row_options["require_header"] = true
	row_options["reject_empty_header"] = true
	row_options["error_prefix"] = "XLSX"
	return GFConfigTableImporter.parse_rows_table(parsed_rows, row_options)


func _xlsx_cells_to_row(cells: Dictionary, trim_cells: bool) -> PackedStringArray:
	var max_column_index: int = -1
	for key: Variant in cells.keys():
		if key is int:
			var column_index: int = key
			max_column_index = maxi(max_column_index, column_index)

	var result: PackedStringArray = PackedStringArray()
	for column_index: int in range(max_column_index + 1):
		var text: String = GFVariantData.to_text(GFVariantData.get_option_value(cells, column_index, ""))
		var _cell_appended: bool = result.append(text.strip_edges() if trim_cells else text)
	return result


func _resolve_xlsx_cell_value(
	raw_value: String,
	cell_type: String,
	shared_strings: PackedStringArray
) -> Dictionary:
	var text: String = raw_value.strip_edges()
	if cell_type == "s":
		if not text.is_valid_int():
			return {
				"success": false,
				"value": "",
				"error": "XLSX shared string index is invalid: %s." % text,
			}
		var shared_index: int = text.to_int()
		if shared_index < 0 or shared_index >= shared_strings.size():
			return {
				"success": false,
				"value": "",
				"error": "XLSX shared string index is out of range: %d." % shared_index,
			}
		return {
			"success": true,
			"value": shared_strings[shared_index],
			"error": "",
		}
	if cell_type == "b":
		return {
			"success": true,
			"value": "true" if text == "1" else "false",
			"error": "",
		}
	return {
		"success": true,
		"value": raw_value,
		"error": "",
	}


func _xlsx_column_index_from_cell_ref(cell_ref: String) -> int:
	var result: int = 0
	var has_letters: bool = false
	for index: int in range(cell_ref.length()):
		var character: String = cell_ref.substr(index, 1).to_upper()
		var code: int = character.unicode_at(0)
		if code < 65 or code > 90:
			break
		result = result * 26 + code - 64
		has_letters = true
	return result - 1 if has_letters else -1


func _parse_positive_int(text: String, fallback_value: int) -> int:
	if text.is_valid_int():
		return maxi(text.to_int(), 1)
	return fallback_value


func _zip_read_bytes(
	reader: ZIPReader,
	files: PackedStringArray,
	path: String
) -> PackedByteArray:
	if not _zip_has_file(files, path):
		return PackedByteArray()
	return reader.read_file(path)


func _zip_has_file(files: PackedStringArray, path: String) -> bool:
	if path.is_empty():
		return false
	return files.has(path)


func _close_zip_reader(reader: ZIPReader) -> void:
	var _close_result: Variant = reader.call("close")


func _normalize_xlsx_relationship_target(base_path: String, target: String) -> String:
	var normalized_target: String = target.replace("\\", "/")
	if normalized_target.begins_with("/"):
		return _normalize_zip_path(normalized_target.trim_prefix("/"))
	return _normalize_zip_path("%s/%s" % [base_path.get_base_dir(), normalized_target])


func _normalize_zip_path(path: String) -> String:
	var stack: PackedStringArray = PackedStringArray()
	var parts: PackedStringArray = path.split("/", false)
	for part: String in parts:
		if part.is_empty() or part == ".":
			continue
		if part == "..":
			if stack.is_empty():
				return ""
			stack.remove_at(stack.size() - 1)
			continue
		var _part_appended: bool = stack.append(part)
	return "/".join(stack)


func _get_xml_attribute(parser: XMLParser, attribute_name: String) -> String:
	for attribute_index: int in range(parser.get_attribute_count()):
		if parser.get_attribute_name(attribute_index) == attribute_name:
			return parser.get_attribute_value(attribute_index)
	return ""


func _get_xml_attribute_any(parser: XMLParser, attribute_names: PackedStringArray) -> String:
	for attribute_name: String in attribute_names:
		var value: String = _get_xml_attribute(parser, attribute_name)
		if not value.is_empty():
			return value
	return ""


func _make_xlsx_parse_failure(
	message: String,
	source: String,
	line: int = 0,
	column: int = 0
) -> Dictionary:
	return {
		"success": false,
		"data": null,
		"row_locations": [],
		"error": message,
		"error_line": line,
		"error_column": column,
		"source": source,
	}


func _get_xlsx_limit(options: Dictionary, key: String, default_value: int) -> int:
	if not options.has(key):
		return default_value
	return maxi(GFVariantData.get_option_int(options, key, default_value), 0)


func _is_xlsx_limit_exceeded(value: int, limit: int) -> bool:
	return limit > 0 and value > limit


func _get_packed_string_array_value(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var array_value: PackedStringArray = value
		return array_value
	return PackedStringArray()


func _normalize_records(table_data: Variant) -> Dictionary:
	var records: Array[Dictionary] = []
	if table_data is Array:
		var rows: Array = GFVariantData.as_array(table_data)
		for row_value: Variant in rows:
			if not (row_value is Dictionary):
				return _make_records_failure(table_data)
			var row: Dictionary = row_value
			records.append(row.duplicate(true))
		return {
			"success": true,
			"records": records,
			"actual_value": "Array",
		}

	if table_data is Dictionary:
		var table: Dictionary = GFVariantData.as_dictionary(table_data)
		var keys: Array = table.keys()
		keys.sort()
		for key: Variant in keys:
			var row_value: Variant = table[key]
			if not (row_value is Dictionary):
				return _make_records_failure(table_data)
			var row: Dictionary = row_value
			records.append(row.duplicate(true))
		return {
			"success": true,
			"records": records,
			"actual_value": "Dictionary",
		}

	return _make_records_failure(table_data)


func _resolve_schema(
	source: GFConfigPipelineTableSource,
	table_name: StringName,
	records: Array[Dictionary],
	declared_schema: GFConfigTableSchema = null
) -> GFConfigTableSchema:
	var source_schema: GFConfigTableSchema = source.schema
	var schema: GFConfigTableSchema = source_schema.duplicate_schema() if source_schema != null else null
	if schema == null and declared_schema != null:
		schema = declared_schema.duplicate_schema()
	if schema == null and source.infer_schema:
		schema = GFConfigTableSchema.infer_from_records(table_name, records, source.schema_options)
	if schema != null and schema.table_name == &"":
		schema.table_name = table_name
	return schema


func _validate_table_source(
	source: GFConfigPipelineTableSource,
	table_name: StringName,
	records: Array[Dictionary],
	schema: GFConfigTableSchema,
	parse_result: Dictionary
) -> Dictionary:
	var report_builder: GFConfigValidationReport = GFConfigValidationReport.new()
	var report: Dictionary = report_builder.make_report(table_name, records.size())
	if schema == null:
		report_builder.add_issue(
			report,
			"warning",
			"missing_schema",
			table_name,
			null,
			&"",
			"配置表来源没有 schema，已跳过结构校验。",
			{ "source": source.source_path }
		)
		report_builder.finalize_report(report)
		return report

	var validation_options: Dictionary = source.parse_options.duplicate(true)
	if not source.source_path.is_empty():
		validation_options["source"] = source.source_path
	if parse_result.has("row_locations"):
		validation_options["row_locations"] = GFVariantData.get_option_value(parse_result, "row_locations")
	report_builder.merge_report(report, schema.validate_definition(validation_options), false)
	report_builder.merge_report(report, schema.validate_table(records, validation_options), false)
	report_builder.finalize_report(report)
	return report


func _apply_typed_header_schema(
	source: GFConfigPipelineTableSource,
	table_name: StringName,
	records: Array[Dictionary],
	parse_result: Dictionary
) -> Dictionary:
	if not GFVariantData.get_option_bool(source.schema_options, "typed_headers", false):
		return {
			"success": true,
			"records": records,
			"schema": null,
		}

	var source_records: Array[Dictionary] = records
	var raw_fields: Array[StringName] = []
	if GFVariantData.get_option_bool(source.schema_options, "typed_header_type_row", false):
		var type_row_result: Dictionary = _collect_typed_header_type_row_field_names(parse_result, records)
		if not GFVariantData.get_option_bool(type_row_result, "success", true):
			return type_row_result
		raw_fields = _get_typed_header_field_array(type_row_result)
		source_records = _drop_first_record(records)
		_drop_first_parse_result_row_location(parse_result)
	else:
		raw_fields = _collect_typed_header_field_names(parse_result, records)

	var schema: GFConfigTableSchema = _make_typed_header_schema(table_name, source.schema_options)
	var field_name_map: Dictionary = {}
	var seen_fields: Dictionary = {}
	for raw_field_name: StringName in raw_fields:
		var header_result: Dictionary = _parse_typed_header_column(raw_field_name)
		if not GFVariantData.get_option_bool(header_result, "success"):
			return header_result

		var column: GFConfigTableColumn = _get_column_from_result(header_result)
		if column == null:
			return _make_typed_header_failure(
				"invalid_typed_header",
				"类型化表头声明无效：%s。" % String(raw_field_name),
				raw_field_name
			)

		var field_name: StringName = column.get_field_key()
		if seen_fields.has(field_name):
			return _make_typed_header_failure(
				"duplicate_typed_header_field",
				"类型化表头声明了重复字段：%s。" % String(field_name),
				raw_field_name
			)

		seen_fields[field_name] = true
		field_name_map[raw_field_name] = field_name
		schema.columns.append(column)

	_remap_parse_result_field_locations(parse_result, field_name_map)
	return {
		"success": true,
		"records": _remap_record_fields(source_records, field_name_map),
		"schema": schema,
	}


func _collect_typed_header_field_names(parse_result: Dictionary, records: Array[Dictionary]) -> Array[StringName]:
	var header_fields: Array[StringName] = _collect_header_field_names(GFVariantData.get_option_value(parse_result, "header"))
	if not header_fields.is_empty():
		return header_fields
	return _collect_record_field_names(records)


func _collect_header_field_names(header_value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	var seen_fields: Dictionary = {}
	if header_value is PackedStringArray:
		var packed_header: PackedStringArray = header_value
		for column_name: String in packed_header:
			_append_header_field_name(result, seen_fields, column_name)
	elif header_value is Array:
		var header_array: Array = header_value
		for column_value: Variant in header_array:
			_append_header_field_name(result, seen_fields, GFVariantData.to_text(column_value))
	return result


func _append_header_field_name(target: Array[StringName], seen_fields: Dictionary, column_name: String) -> void:
	var field_name: StringName = StringName(column_name.strip_edges())
	if field_name == &"" or seen_fields.has(field_name):
		return
	seen_fields[field_name] = true
	target.append(field_name)


func _collect_record_field_names(records: Array[Dictionary]) -> Array[StringName]:
	var result: Array[StringName] = []
	var seen_fields: Dictionary = {}
	for record: Dictionary in records:
		for field_key: Variant in record.keys():
			var field_name: StringName = GFVariantData.to_string_name(field_key)
			if field_name == &"" or seen_fields.has(field_name):
				continue
			seen_fields[field_name] = true
			result.append(field_name)
	return result


func _collect_typed_header_type_row_field_names(
	parse_result: Dictionary,
	records: Array[Dictionary]
) -> Dictionary:
	if records.is_empty():
		return _make_typed_header_failure(
			"missing_typed_header_type_row",
			"启用了 typed_header_type_row，但配置表缺少类型行。",
			&""
		)

	var header_fields: Array[StringName] = _collect_header_field_names(GFVariantData.get_option_value(parse_result, "header"))
	if header_fields.is_empty():
		header_fields = _collect_record_field_names(records)
	if header_fields.is_empty():
		return _make_typed_header_failure(
			"missing_typed_header_fields",
			"启用了 typed_header_type_row，但配置表缺少表头字段。",
			&""
		)

	var type_record: Dictionary = records[0]
	var result: Array[StringName] = []
	for raw_field_name: StringName in header_fields:
		var field_text: String = String(raw_field_name).strip_edges()
		if field_text.is_empty():
			continue
		var type_text: String = GFVariantData.to_text(_get_record_field_value(type_record, raw_field_name)).strip_edges()
		if type_text.is_empty():
			result.append(StringName(field_text))
		else:
			result.append(StringName("%s:%s" % [field_text, type_text]))
	return {
		"success": true,
		"fields": result,
	}


func _get_typed_header_field_array(data: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	for field_value: Variant in GFVariantData.get_option_array(data, "fields"):
		var field_name: StringName = GFVariantData.to_string_name(field_value)
		if field_name != &"":
			result.append(field_name)
	return result


func _get_record_field_value(record: Dictionary, field_name: StringName) -> Variant:
	if record.has(field_name):
		return record[field_name]
	var field_text: String = String(field_name)
	if record.has(field_text):
		return record[field_text]
	return null


func _drop_first_record(records: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(1, records.size()):
		result.append(records[index])
	return result


func _drop_first_parse_result_row_location(parse_result: Dictionary) -> void:
	var row_locations_value: Variant = GFVariantData.get_option_value(parse_result, "row_locations", [])
	if not (row_locations_value is Array):
		return
	var row_locations: Array = row_locations_value
	if row_locations.is_empty():
		return
	row_locations.remove_at(0)
	parse_result["row_locations"] = row_locations


func _make_typed_header_schema(table_name: StringName, schema_options: Dictionary) -> GFConfigTableSchema:
	var schema: GFConfigTableSchema = GFConfigTableSchema.new()
	schema.table_name = table_name
	schema.id_field = GFVariantData.get_option_string_name(schema_options, "id_field", &"id")
	schema.allow_extra_fields = GFVariantData.get_option_bool(schema_options, "allow_extra_fields", false)
	schema.coerce_values = GFVariantData.get_option_bool(schema_options, "coerce_values", true)
	schema.fail_on_coerce_error = GFVariantData.get_option_bool(schema_options, "fail_on_coerce_error", true)
	schema.require_unique_id = GFVariantData.get_option_bool(schema_options, "require_unique_id", false)
	var uses_type_row: bool = GFVariantData.get_option_bool(schema_options, "typed_header_type_row", false)
	schema.metadata = {
		"schema_source": "typed_header_type_row" if uses_type_row else "typed_headers",
		"header_syntax": "gf.typed_header_type_row.v1" if uses_type_row else "gf.typed_headers.v1",
	}
	return schema


func _parse_typed_header_column(raw_field_name: StringName) -> Dictionary:
	var raw_text: String = String(raw_field_name).strip_edges()
	if raw_text.is_empty():
		return _make_typed_header_failure("empty_typed_header", "类型化表头字段名为空。", raw_field_name)

	var separator_index: int = raw_text.rfind(":")
	var field_text: String = raw_text
	var type_text: String = "any"
	if separator_index >= 0:
		field_text = raw_text.substr(0, separator_index).strip_edges()
		type_text = raw_text.substr(separator_index + 1).strip_edges().to_lower()

	var markers: Dictionary = _strip_typed_header_markers(field_text, type_text)
	field_text = GFVariantData.get_option_string(markers, "field_text")
	type_text = GFVariantData.get_option_string(markers, "type_text", "any")
	if field_text.is_empty():
		return _make_typed_header_failure("empty_typed_header_field", "类型化表头字段名为空：%s。" % raw_text, raw_field_name)

	var column: GFConfigTableColumn = GFConfigTableColumn.new()
	column.field_name = StringName(field_text)
	column.required = GFVariantData.get_option_bool(markers, "required")
	column.allow_null = GFVariantData.get_option_bool(markers, "allow_null", true) and not column.required
	column.metadata = { "source_header": raw_text }
	if not _assign_typed_header_value_type(column, type_text):
		return _make_typed_header_failure(
			"unsupported_typed_header_type",
			"类型化表头字段 %s 使用了不支持的类型：%s。" % [field_text, type_text],
			raw_field_name
		)

	return {
		"success": true,
		"column": column,
		"error": "",
	}


func _strip_typed_header_markers(field_text: String, type_text: String) -> Dictionary:
	var required: bool = false
	var allow_null: bool = true
	while field_text.ends_with("!") or field_text.ends_with("?"):
		if field_text.ends_with("!"):
			required = true
			allow_null = false
		else:
			allow_null = true
		field_text = field_text.substr(0, field_text.length() - 1).strip_edges()
	while type_text.ends_with("!") or type_text.ends_with("?"):
		if type_text.ends_with("!"):
			required = true
			allow_null = false
		else:
			allow_null = true
		type_text = type_text.substr(0, type_text.length() - 1).strip_edges()
	if type_text.is_empty():
		type_text = "any"
	return {
		"field_text": field_text,
		"type_text": type_text,
		"required": required,
		"allow_null": allow_null,
	}


func _assign_typed_header_value_type(column: GFConfigTableColumn, type_text: String) -> bool:
	match type_text:
		"", "any", "variant":
			column.value_type = GFConfigTableColumn.ValueType.ANY
		"bool", "boolean":
			column.value_type = GFConfigTableColumn.ValueType.BOOL
		"int", "integer":
			column.value_type = GFConfigTableColumn.ValueType.INT
		"float", "double", "number":
			column.value_type = GFConfigTableColumn.ValueType.FLOAT
		"string", "str":
			column.value_type = GFConfigTableColumn.ValueType.STRING
		"string_name", "stringname", "name":
			column.value_type = GFConfigTableColumn.ValueType.STRING_NAME
		"vector2", "vec2":
			column.value_type = GFConfigTableColumn.ValueType.VECTOR2
		"vector2i", "vec2i":
			column.value_type = GFConfigTableColumn.ValueType.VECTOR2I
		"color", "colour":
			column.value_type = GFConfigTableColumn.ValueType.COLOR
		"dictionary", "dict", "object":
			column.value_type = GFConfigTableColumn.ValueType.DICTIONARY
		"array", "list":
			column.value_type = GFConfigTableColumn.ValueType.ARRAY
		_:
			return false
	return true


func _remap_record_fields(records: Array[Dictionary], field_name_map: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in records:
		var remapped_record: Dictionary = {}
		for field_key: Variant in record.keys():
			var raw_field_name: StringName = GFVariantData.to_string_name(field_key)
			var target_field_name: StringName = GFVariantData.get_option_string_name(field_name_map, raw_field_name, raw_field_name)
			if target_field_name == &"":
				continue
			remapped_record[target_field_name] = GFVariantData.duplicate_variant(record[field_key])
		result.append(remapped_record)
	return result


func _remap_parse_result_field_locations(parse_result: Dictionary, field_name_map: Dictionary) -> void:
	var raw_locations: Variant = GFVariantData.get_option_value(parse_result, "row_locations", [])
	if not (raw_locations is Array):
		return

	var locations: Array = raw_locations
	for row_location_value: Variant in locations:
		if not (row_location_value is Dictionary):
			continue
		var row_location: Dictionary = row_location_value
		var raw_fields: Variant = GFVariantData.get_option_value(row_location, "fields", {})
		if not (raw_fields is Dictionary):
			continue
		var fields: Dictionary = raw_fields
		for raw_key_variant: Variant in field_name_map.keys():
			var raw_field_name: StringName = GFVariantData.to_string_name(raw_key_variant)
			var target_field_name: StringName = GFVariantData.get_option_string_name(field_name_map, raw_field_name, raw_field_name)
			var field_location: Variant = GFVariantData.get_option_value(fields, raw_field_name)
			if not (field_location is Dictionary):
				field_location = GFVariantData.get_option_value(fields, String(raw_field_name))
			if field_location is Dictionary:
				fields[target_field_name] = field_location
				fields[String(target_field_name)] = field_location


func _make_typed_header_failure(
	kind: String,
	message: String,
	raw_field_name: StringName
) -> Dictionary:
	return {
		"success": false,
		"kind": kind,
		"error": message,
		"context": {
			"field": raw_field_name,
			"actual_value": String(raw_field_name),
			"supported_values": PackedStringArray([
				"any",
				"bool",
				"int",
				"float",
				"string",
				"string_name",
				"vector2",
				"vector2i",
				"color",
				"dictionary",
				"array",
			]),
		},
	}


func _coerce_records(records: Array[Dictionary], schema: GFConfigTableSchema) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in records:
		result.append(schema.coerce_record(record))
	return result


func _make_table_metadata(source: GFConfigPipelineTableSource, resolved_format: StringName) -> Dictionary:
	var result: Dictionary = source.metadata.duplicate(true)
	result["source_path"] = source.source_path
	result["source_format"] = resolved_format
	return result


func _is_supported_format(resolved_format: StringName) -> bool:
	return (
		resolved_format == _FORMAT_CSV
		or resolved_format == _FORMAT_JSON
		or resolved_format == _FORMAT_CONFIG_FILE
	)


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


func _make_records_failure(table_data: Variant) -> Dictionary:
	return {
		"success": false,
		"records": [],
		"actual_value": type_string(typeof(table_data)),
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


func _get_result_records(result: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var raw_records: Variant = GFVariantData.get_option_value(result, "records", [])
	if not (raw_records is Array):
		return records
	var raw_array: Array = raw_records
	for row_value: Variant in raw_array:
		if row_value is Dictionary:
			var row: Dictionary = row_value
			records.append(row)
	return records


func _get_schema_from_result(result: Dictionary) -> GFConfigTableSchema:
	var schema_value: Variant = GFVariantData.get_option_value(result, "schema")
	if schema_value is GFConfigTableSchema:
		var schema: GFConfigTableSchema = schema_value
		return schema
	return null


func _get_column_from_result(result: Dictionary) -> GFConfigTableColumn:
	var column_value: Variant = GFVariantData.get_option_value(result, "column")
	if column_value is GFConfigTableColumn:
		var column: GFConfigTableColumn = column_value
		return column
	return null


func _get_table_from_result(result: Dictionary) -> GFConfigTableResource:
	var table_value: Variant = GFVariantData.get_option_value(result, "table")
	if table_value is GFConfigTableResource:
		var table: GFConfigTableResource = table_value
		return table
	return null


func _get_database_from_result(result: Dictionary) -> GFConfigDatabaseResource:
	var database_value: Variant = GFVariantData.get_option_value(result, "database")
	if database_value is GFConfigDatabaseResource:
		var database: GFConfigDatabaseResource = database_value
		return database
	return null


func _duplicate_result_dictionary(result: Dictionary) -> Dictionary:
	return _duplicate_dictionary_without_keys(result, { "table": true })


func _duplicate_database_result_dictionary(result: Dictionary) -> Dictionary:
	return _duplicate_dictionary_without_keys(result, { "database": true })


func _duplicate_dictionary_without_keys(result: Dictionary, skipped_keys: Dictionary) -> Dictionary:
	var copy: Dictionary = {}
	for key: Variant in result.keys():
		if skipped_keys.has(key):
			continue
		copy[key] = GFVariantData.duplicate_variant(result[key])
	return copy


func _capture_export_snapshots(paths: PackedStringArray) -> Dictionary:
	var entries: Array[Dictionary] = []
	var seen_paths: Dictionary = {}
	var transaction_id: int = Time.get_ticks_usec()
	for path: String in paths:
		if path.is_empty() or seen_paths.has(path):
			continue
		seen_paths[path] = true
		var exists: bool = FileAccess.file_exists(path)
		var backup_path: String = ""
		if exists:
			backup_path = "%s.gf-config-transaction-%d-%d.bak" % [path, transaction_id, entries.size()]
			var copy_error: Error = _copy_file(path, backup_path)
			if copy_error != OK:
				_discard_export_snapshots({ "entries": entries })
				return {
					"success": false,
					"entries": [],
					"error": "无法为导表事务创建回滚快照：%s (%s)。" % [path, error_string(copy_error)],
				}
		entries.append({
			"path": path,
			"existed": exists,
			"backup_path": backup_path,
		})
	return {
		"success": true,
		"entries": entries,
		"error": "",
	}


func _restore_export_snapshots(snapshot: Dictionary) -> PackedStringArray:
	var issues: PackedStringArray = PackedStringArray()
	var entries: Array = GFVariantData.get_option_array(snapshot, "entries")
	for entry_index: int in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = GFVariantData.as_dictionary(entries[entry_index])
		var path: String = GFVariantData.get_option_string(entry, "path")
		var existed: bool = GFVariantData.get_option_bool(entry, "existed")
		var backup_path: String = GFVariantData.get_option_string(entry, "backup_path")
		if existed:
			var remove_error: Error = _remove_file_path(path)
			if remove_error != OK:
				var _remove_issue_appended: bool = issues.append("无法移除失败产物 %s：%s" % [path, error_string(remove_error)])
				continue
			var restore_error: Error = DirAccess.rename_absolute(
				ProjectSettings.globalize_path(backup_path),
				ProjectSettings.globalize_path(path)
			)
			if restore_error != OK:
				var _restore_issue_appended: bool = issues.append("无法恢复产物 %s：%s" % [path, error_string(restore_error)])
		else:
			var delete_error: Error = _remove_file_path(path)
			if delete_error != OK:
				var _delete_issue_appended: bool = issues.append("无法删除新增产物 %s：%s" % [path, error_string(delete_error)])
	_discard_export_snapshots(snapshot)
	return issues


func _discard_export_snapshots(snapshot: Dictionary) -> void:
	var entries: Array = GFVariantData.get_option_array(snapshot, "entries")
	for entry_value: Variant in entries:
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		var backup_path: String = GFVariantData.get_option_string(entry, "backup_path")
		if not backup_path.is_empty():
			var _remove_backup_error: Error = _remove_file_path(backup_path)


func _copy_file(source_path: String, target_path: String) -> Error:
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return FileAccess.get_open_error()
	var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		var target_open_error: Error = FileAccess.get_open_error()
		source_file.close()
		return target_open_error
	while source_file.get_position() < source_file.get_length():
		var remaining: int = source_file.get_length() - source_file.get_position()
		var chunk: PackedByteArray = source_file.get_buffer(mini(remaining, 64 * 1024))
		if source_file.get_error() != OK:
			var read_error: Error = source_file.get_error()
			source_file.close()
			target_file.close()
			var _remove_partial_error: Error = _remove_file_path(target_path)
			return read_error
		var _store_chunk_result: Variant = target_file.store_buffer(chunk)
		if target_file.get_error() != OK:
			var write_error: Error = target_file.get_error()
			source_file.close()
			target_file.close()
			var _remove_partial_error: Error = _remove_file_path(target_path)
			return write_error
	source_file.close()
	target_file.close()
	return OK


func _remove_file_path(path: String) -> Error:
	if path.is_empty() or not FileAccess.file_exists(path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


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


func _are_finite_floats(values: Array) -> bool:
	for value: Variant in values:
		var number: float = 0.0
		if value is float:
			number = value
		elif value is int:
			var integer_value: int = value
			number = integer_value
		else:
			return false
		if is_nan(number) or is_inf(number):
			return false
	return true


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
	var export_result: Dictionary = _make_database_export_result(database, options)
	if not GFVariantData.get_option_bool(export_result, "success"):
		return _make_save_result(
			false,
			output_path,
			_OUTPUT_FORMAT_JSON,
			ERR_INVALID_DATA,
			GFVariantData.get_option_string(export_result, "error")
		)

	var export_data: Dictionary = GFVariantData.get_option_dictionary(export_result, "data")
	var indent: String = GFVariantData.get_option_string(options, "indent", _DEFAULT_JSON_INDENT)
	var sort_keys: bool = GFVariantData.get_option_bool(options, "sort_keys", true)
	var json_text: String = JSON.stringify(export_data, indent, sort_keys)
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


func _make_database_export_result(database: GFConfigDatabaseResource, options: Dictionary) -> Dictionary:
	if database == null:
		return _make_export_failure("配置数据库资源为空。")

	var state: Dictionary = _make_json_state(options)
	var tables: Array[Dictionary] = []
	var table_ids: PackedStringArray = database.get_table_ids()
	for table_id: String in table_ids:
		var table_resource: GFConfigTableResource = database.get_table_resource(StringName(table_id), false)
		if table_resource == null:
			continue
		var table_data: Dictionary = _make_table_export(table_resource, state, options)
		if not GFVariantData.get_option_bool(state, "success", true):
			return _make_export_failure(GFVariantData.get_option_string(state, "error"))
		tables.append(table_data)

	var export_data: Dictionary = {
		"format": _JSON_EXPORT_FORMAT,
		"format_version": _JSON_EXPORT_VERSION,
		"artifact_owner": _ARTIFACT_OWNER,
		"database_id": String(database.database_id),
		"version": database.version,
		"metadata": _to_json_compatible(database.metadata, state, 0),
		"tables": tables,
	}
	if not GFVariantData.get_option_bool(state, "success", true):
		return _make_export_failure(GFVariantData.get_option_string(state, "error"))
	return {
		"success": true,
		"data": export_data,
		"error": "",
	}


func _make_table_export(
	table_resource: GFConfigTableResource,
	state: Dictionary,
	options: Dictionary
) -> Dictionary:
	var include_schema: bool = GFVariantData.get_option_bool(options, "include_schema", true)
	var include_indexes: bool = GFVariantData.get_option_bool(options, "include_indexes", false)
	var result: Dictionary = {
		"table_name": String(table_resource.get_table_key()),
		"metadata": _to_json_compatible(table_resource.metadata, state, 0),
		"records": _to_json_compatible(table_resource.records, state, 0),
	}
	if include_schema and table_resource.schema != null:
		result["schema"] = _to_json_compatible(table_resource.schema.describe(), state, 0)
	if include_indexes:
		result["records_by_id"] = _to_json_compatible(table_resource.records_by_id, state, 0)
		result["records_by_index"] = _to_json_compatible(table_resource.records_by_index, state, 0)
	return result


func _resolve_output_format(output_path: String, options: Dictionary) -> StringName:
	var configured_format: StringName = GFVariantData.get_option_string_name(options, "output_format", _OUTPUT_FORMAT_AUTO)
	if configured_format != &"" and configured_format != _OUTPUT_FORMAT_AUTO:
		return configured_format

	var extension: String = output_path.get_extension().to_lower()
	if extension == "json":
		return _OUTPUT_FORMAT_JSON
	return _OUTPUT_FORMAT_RESOURCE


func _make_export_failure(message: String) -> Dictionary:
	return {
		"success": false,
		"data": {},
		"error": message,
	}


func _make_json_state(options: Dictionary) -> Dictionary:
	return {
		"success": true,
		"error": "",
		"max_depth": maxi(GFVariantData.get_option_int(options, "max_depth", 256), 1),
	}


func _to_json_compatible(value: Variant, state: Dictionary, depth: int) -> Variant:
	if not GFVariantData.get_option_bool(state, "success", true):
		return null
	if depth > GFVariantData.get_option_int(state, "max_depth", 256):
		return _fail_json_export(state, "配置数据库 JSON 导出结构超过 max_depth。")

	match typeof(value):
		TYPE_NIL:
			return null
		TYPE_BOOL:
			var bool_value: bool = value
			return bool_value
		TYPE_INT:
			var int_value: int = value
			return int_value
		TYPE_FLOAT:
			var float_value: float = value
			if is_nan(float_value) or is_inf(float_value):
				return _fail_json_export(state, "配置数据库 JSON 导出不支持 NaN 或 Inf。")
			return float_value
		TYPE_STRING:
			var string_value: String = value
			return string_value
		TYPE_STRING_NAME:
			var string_name_value: StringName = value
			return String(string_name_value)
		TYPE_NODE_PATH:
			var node_path_value: NodePath = value
			return String(node_path_value)
		TYPE_VECTOR2:
			var vector_2: Vector2 = value
			if not _are_finite_floats([vector_2.x, vector_2.y]):
				return _fail_json_export(state, "配置数据库 JSON 导出不支持包含 NaN 或 Inf 的 Vector2。")
			return _make_json_variant("Vector2", [vector_2.x, vector_2.y])
		TYPE_VECTOR2I:
			var vector_2i: Vector2i = value
			return _make_json_variant("Vector2i", [vector_2i.x, vector_2i.y])
		TYPE_VECTOR3:
			var vector_3: Vector3 = value
			if not _are_finite_floats([vector_3.x, vector_3.y, vector_3.z]):
				return _fail_json_export(state, "配置数据库 JSON 导出不支持包含 NaN 或 Inf 的 Vector3。")
			return _make_json_variant("Vector3", [vector_3.x, vector_3.y, vector_3.z])
		TYPE_VECTOR3I:
			var vector_3i: Vector3i = value
			return _make_json_variant("Vector3i", [vector_3i.x, vector_3i.y, vector_3i.z])
		TYPE_COLOR:
			var color_value: Color = value
			if not _are_finite_floats([color_value.r, color_value.g, color_value.b, color_value.a]):
				return _fail_json_export(state, "配置数据库 JSON 导出不支持包含 NaN 或 Inf 的 Color。")
			return _make_json_variant("Color", [color_value.r, color_value.g, color_value.b, color_value.a])
		TYPE_ARRAY:
			return _array_to_json_compatible(value, state, depth)
		TYPE_DICTIONARY:
			return _dictionary_to_json_compatible(value, state, depth)
		TYPE_PACKED_STRING_ARRAY:
			var packed_strings: PackedStringArray = value
			return _packed_string_array_to_json(packed_strings)
		TYPE_PACKED_INT32_ARRAY:
			var packed_int32: PackedInt32Array = value
			return _packed_int32_array_to_json(packed_int32)
		TYPE_PACKED_INT64_ARRAY:
			var packed_int64: PackedInt64Array = value
			return _packed_int64_array_to_json(packed_int64)
		TYPE_PACKED_FLOAT32_ARRAY:
			var packed_float32: PackedFloat32Array = value
			return _packed_float32_array_to_json(packed_float32, state)
		TYPE_PACKED_FLOAT64_ARRAY:
			var packed_float64: PackedFloat64Array = value
			return _packed_float64_array_to_json(packed_float64, state)

	return _fail_json_export(state, "配置数据库 JSON 导出不支持 Variant 类型：%s。" % type_string(typeof(value)))


func _array_to_json_compatible(value: Variant, state: Dictionary, depth: int) -> Array:
	var source: Array = GFVariantData.as_array(value)
	var result: Array = []
	for item: Variant in source:
		result.append(_to_json_compatible(item, state, depth + 1))
		if not GFVariantData.get_option_bool(state, "success", true):
			return []
	return result


func _dictionary_to_json_compatible(value: Variant, state: Dictionary, depth: int) -> Dictionary:
	var source: Dictionary = GFVariantData.as_dictionary(value)
	var result: Dictionary = {}
	for key: Variant in source.keys():
		var key_text: String = _json_key_to_text(key, state)
		if not GFVariantData.get_option_bool(state, "success", true):
			return {}
		if result.has(key_text):
			var _failed_duplicate_key: Variant = _fail_json_export(state, "配置数据库 JSON 导出遇到重复 JSON key：%s。" % key_text)
			return {}
		result[key_text] = _to_json_compatible(source[key], state, depth + 1)
		if not GFVariantData.get_option_bool(state, "success", true):
			return {}
	return result


func _json_key_to_text(key: Variant, state: Dictionary) -> String:
	match typeof(key):
		TYPE_STRING:
			var string_key: String = key
			return string_key
		TYPE_STRING_NAME:
			var string_name_key: StringName = key
			return String(string_name_key)
		TYPE_INT:
			var int_key: int = key
			return str(int_key)
	var _failed_key_type: Variant = _fail_json_export(state, "配置数据库 JSON 导出不支持 Dictionary key 类型：%s。" % type_string(typeof(key)))
	return ""


func _packed_string_array_to_json(values: PackedStringArray) -> Array:
	var result: Array = []
	for value: String in values:
		result.append(value)
	return result


func _packed_int32_array_to_json(values: PackedInt32Array) -> Array:
	var result: Array = []
	for value: int in values:
		result.append(value)
	return result


func _packed_int64_array_to_json(values: PackedInt64Array) -> Array:
	var result: Array = []
	for value: int in values:
		result.append(value)
	return result


func _packed_float32_array_to_json(values: PackedFloat32Array, state: Dictionary) -> Array:
	var result: Array = []
	for value: float in values:
		if is_nan(value) or is_inf(value):
			var _failed_non_finite: Variant = _fail_json_export(state, "配置数据库 JSON 导出不支持 NaN 或 Inf。")
			return []
		result.append(value)
	return result


func _packed_float64_array_to_json(values: PackedFloat64Array, state: Dictionary) -> Array:
	var result: Array = []
	for value: float in values:
		if is_nan(value) or is_inf(value):
			var _failed_non_finite: Variant = _fail_json_export(state, "配置数据库 JSON 导出不支持 NaN 或 Inf。")
			return []
		result.append(value)
	return result


func _make_json_variant(type_name: String, variant_value: Variant) -> Dictionary:
	return {
		_JSON_VARIANT_TYPE_KEY: type_name,
		_JSON_VARIANT_VALUE_KEY: variant_value,
	}


func _fail_json_export(state: Dictionary, message: String) -> Variant:
	if GFVariantData.get_option_bool(state, "success", true):
		state["success"] = false
		state["error"] = message
	return null
