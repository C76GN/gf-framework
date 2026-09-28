## GFConfigPipelineArtifactManifest: 配置导表产物 manifest 辅助。
##
## 为 GFConfigPipelineProfile 生成输入摘要、输出摘要和 freshness 报告，支持 CI、
## 编辑器按钮或命令行在导表前判断是否可以跳过未变化的产物。
## 该工具记录 Profile 资源依赖、数据来源、编译阶段、输出和导表选项摘要，
## 不表达项目业务版本、热更新策略或远端发布流程。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 8.0.0
class_name GFConfigPipelineArtifactManifest
extends RefCounted


# --- 常量 ---

## manifest JSON 格式标识。
## [br]
## @api public
## [br]
## @since 8.0.0
const FORMAT: String = "gf.config_pipeline.artifact_manifest"

## manifest 格式版本。
## [br]
## @api public
## [br]
## @since 8.0.0
const FORMAT_VERSION: int = 2

## GF Config Pipeline 产物所有者标识。
## [br]
## @api private
## [br]
const _ARTIFACT_OWNER: String = "gf.tool.config_pipeline"

## JSON 产物所有权字段名。
## [br]
## @api private
## [br]
const _ARTIFACT_OWNER_FIELD: String = "artifact_owner"

## manifest JSON 默认使用的缩进文本。
## [br]
## @api private
## [br]
const _DEFAULT_JSON_INDENT: String = "\t"

## 默认允许读取的 manifest 文件最大字节数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_MANIFEST_BYTES: int = 4 * 1024 * 1024

## 单个 freshness 文件默认允许的最大字节数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_FRESHNESS_FILE_BYTES: int = 64 * 1024 * 1024

## freshness 扫描默认累计允许的最大文件字节数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_FRESHNESS_TOTAL_BYTES: int = 256 * 1024 * 1024

## freshness 扫描默认允许登记的最大文件数。
## [br]
## @api private
## [br]
const _DEFAULT_MAX_FRESHNESS_ENTRIES: int = 4096

## 文件摘要分块处理时单个缓冲块的字节数。
## [br]
## @api private
## [br]
const _DIGEST_CHUNK_BYTES: int = 64 * 1024

## 编译器指纹契约当前版本。
## [br]
## @api private
## [br]
const _COMPILER_CONTRACT_VERSION: int = 3

## source receipt 格式标识。
## [br]
## @api private
## [br]
const _SOURCE_RECEIPT_FORMAT: String = "gf.config_pipeline.source_receipt"

## source receipt 当前格式版本。
## [br]
## @api private
## [br]
const _SOURCE_RECEIPT_FORMAT_VERSION: int = 1

## 读取框架版本使用的插件配置路径。
## [br]
## @api private
## [br]
const _PLUGIN_CONFIG_PATH: String = "res://addons/gf/plugin.cfg"

## 验证 manifest 输出路径的策略脚本。
## [br]
## @api private
## [br]
const _OUTPUT_PATH_POLICY_SCRIPT = preload(
	"res://addons/gf/tools/config_pipeline/gf_config_pipeline_output_path_policy.gd"
)

## 构成 compiler fingerprint 的阶段定义表。
## [br]
## @api private
## [br]
const _COMPILER_STAGE_DEFINITIONS: Array[Dictionary] = [
	{
		"id": "framework_metadata",
		"implementation_version": 1,
		"path": _PLUGIN_CONFIG_PATH,
	},
	{
		"id": "config_pipeline",
		"implementation_version": 1,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline.gd",
		"implementation_dependencies": [
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_output_path_policy.gd",
		],
	},
	{
		"id": GFConfigPipelineIR.FORMAT,
		"implementation_version": GFConfigPipelineIR.FORMAT_VERSION,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_ir.gd",
	},
	{
		"id": GFConfigPipelineTableIR.FORMAT,
		"implementation_version": GFConfigPipelineTableIR.FORMAT_VERSION,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_table_ir.gd",
	},
	{
		"id": GFConfigPipelineReaderStage.STAGE_ID,
		"implementation_version": GFConfigPipelineReaderStage.IMPLEMENTATION_VERSION,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_reader_stage.gd",
		"implementation_dependencies": [
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_table_source.gd",
			"res://addons/gf/standard/foundation/variant/gf_variant_data.gd",
		],
	},
	{
		"id": GFConfigPipelineLayoutStage.STAGE_ID,
		"implementation_version": GFConfigPipelineLayoutStage.IMPLEMENTATION_VERSION,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_layout_stage.gd",
		"implementation_dependencies": [
			"res://addons/gf/tools/config_pipeline/gf_bounded_zip_support.gd",
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_table_source.gd",
			"res://addons/gf/standard/utilities/config/gf_config_table_importer.gd",
			"res://addons/gf/standard/foundation/variant/gf_variant_data.gd",
		],
	},
	{
		"id": GFConfigPipelineValidationStage.STAGE_ID,
		"implementation_version": GFConfigPipelineValidationStage.IMPLEMENTATION_VERSION,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_validation_stage.gd",
		"implementation_dependencies": [
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_table_ir.gd",
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_table_source.gd",
			"res://addons/gf/standard/utilities/config/gf_config_table_schema.gd",
			"res://addons/gf/standard/utilities/config/gf_config_table_column.gd",
			"res://addons/gf/standard/utilities/config/gf_config_validation_report.gd",
			"res://addons/gf/standard/foundation/variant/gf_variant_data.gd",
		],
	},
	{
		"id": GFConfigPipelineTargetStage.STAGE_ID,
		"implementation_version": GFConfigPipelineTargetStage.IMPLEMENTATION_VERSION,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_target_stage.gd",
		"implementation_dependencies": [
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_ir.gd",
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_table_ir.gd",
			"res://addons/gf/standard/utilities/config/gf_config_database_resource.gd",
			"res://addons/gf/standard/utilities/config/gf_config_table_resource.gd",
			"res://addons/gf/standard/utilities/config/gf_config_reference_resolver.gd",
			"res://addons/gf/standard/utilities/config/gf_config_table_reference.gd",
			"res://addons/gf/standard/utilities/config/gf_config_validation_report.gd",
			"res://addons/gf/standard/foundation/variant/gf_variant_data.gd",
		],
	},
	{
		"id": GFConfigPipelineCommitStage.STAGE_ID,
		"implementation_version": GFConfigPipelineCommitStage.IMPLEMENTATION_VERSION,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_commit_stage.gd",
		"implementation_dependencies": [
			"res://addons/gf/kernel/editor/gf_artifact_write_transaction.gd",
		],
	},
	{
		"id": "artifact_manifest",
		"implementation_version": 1,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_artifact_manifest.gd",
		"implementation_dependencies": [
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_output_path_policy.gd",
		],
	},
	{
		"id": "pipeline_runner",
		"implementation_version": 1,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_runner.gd",
		"implementation_dependencies": [
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_output_path_policy.gd",
		],
	},
	{
		"id": "table_importer",
		"implementation_version": 1,
		"path": "res://addons/gf/standard/utilities/config/gf_config_table_importer.gd",
	},
	{
		"id": "config_database_resource",
		"implementation_version": 1,
		"path": "res://addons/gf/standard/utilities/config/gf_config_database_resource.gd",
	},
	{
		"id": "config_table_resource",
		"implementation_version": 1,
		"path": "res://addons/gf/standard/utilities/config/gf_config_table_resource.gd",
	},
	{
		"id": "config_reference_resolver",
		"implementation_version": 1,
		"path": "res://addons/gf/standard/utilities/config/gf_config_reference_resolver.gd",
	},
	{
		"id": "config_validation_report",
		"implementation_version": 1,
		"path": "res://addons/gf/standard/utilities/config/gf_config_validation_report.gd",
	},
	{
		"id": "generated_artifact_commit",
		"implementation_version": 1,
		"path": "res://addons/gf/kernel/editor/gf_generated_artifact_report.gd",
	},
	{
		"id": "report_value_codec",
		"implementation_version": 1,
		"path": "res://addons/gf/kernel/core/gf_report_value_codec.gd",
	},
	{
		"id": "variant_json_codec",
		"implementation_version": 1,
		"path": "res://addons/gf/standard/foundation/variant/gf_variant_json_codec.gd",
	},
	{
		"id": "variant_data",
		"implementation_version": 1,
		"path": "res://addons/gf/standard/foundation/variant/gf_variant_data.gd",
	},
]

## 构成 access generator fingerprint 的阶段定义表。
## [br]
## @api private
## [br]
const _ACCESS_COMPILER_STAGE_DEFINITIONS: Array[Dictionary] = [
	{
		"id": "config_access_generator",
		"implementation_version": 1,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_access_generator.gd",
	},
	{
		"id": "source_builder",
		"implementation_version": 1,
		"path": "res://addons/gf/kernel/editor/gf_source_builder.gd",
	},
	{
		"id": "variant_access",
		"implementation_version": 1,
		"path": "res://addons/gf/kernel/core/gf_variant_access.gd",
	},
]

## pipeline 与 access stage 定义允许登记的 stage ID 集合。
## [br]
## @api private
## [br]
const _PIPELINE_STAGE_IDS: PackedStringArray = [
	GFConfigPipelineReaderStage.STAGE_ID,
	GFConfigPipelineLayoutStage.STAGE_ID,
	GFConfigPipelineValidationStage.STAGE_ID,
	GFConfigPipelineTargetStage.STAGE_ID,
	GFConfigPipelineCommitStage.STAGE_ID,
]

## 生成产物保存与报告服务。
## [br]
## @api private
## [br]
const _GENERATED_ARTIFACT_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")


# --- 私有变量 ---

## 本实例登记的 compiler 阶段描述符。
## [br]
## @api private
## [br]
var _compiler_stage_descriptors: Array[Dictionary] = []


# --- 公共方法 ---

## 根据 Profile 和本次选项生成 manifest 字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param profile_path: Profile 资源路径。
## [br]
## @param profile: 导表 Profile 资源。
## [br]
## @param options: 本次导表选项。
## [br]
## @schema options: Dictionary，可包含 output_path、access_output_path、access_class_name、access_provider_accessor、build_options、save_options、access_options、manifest_metadata、max_freshness_file_bytes、max_freshness_total_bytes 和 max_freshness_entries；三个 freshness 预算必须为非负整数，分别限制单文件字节数、累计哈希字节数和扫描条目数。
## [br]
## @param run_result: 可选 Runner 或 Pipeline 结果；只会提取 JSON 兼容摘要。
## [br]
## @schema run_result: Dictionary，可包含 success、operation、profile_id、output_path、save_result、access_result、report、table_results 和 error；table_results 存在时，每项必须提供绑定实际读取字节的 source_receipt，manifest 不会回退到重新哈希来源路径。
## [br]
## @return: manifest 字典。
## [br]
## @schema return: Dictionary，包含 format、format_version、artifact_owner、profile_path、profile_id、profile_digest、input_digest、output_digest、options_digest、compiler_digest、compiler_fingerprint、profile_entries、source_entries、output_entries、scan_report、metadata、run_summary 和 manifest_digest。
func make_manifest(
	profile_path: String,
	profile: GFConfigPipelineProfile,
	options: Dictionary = {},
	run_result: Dictionary = {}
) -> Dictionary:
	if profile == null:
		return _make_empty_manifest(profile_path, options, run_result)

	var budget_state: Dictionary = _make_digest_budget_state(options)
	var profile_entries: Array[Dictionary] = _make_profile_resource_entries(profile_path, budget_state)
	var receipt_entries_result: Dictionary = _make_compilation_source_entries(
		profile,
		run_result,
		budget_state
	)
	var source_entries: Array[Dictionary] = (
		_get_dictionary_array_value(
			GFVariantData.get_option_value(receipt_entries_result, "entries")
		)
		if GFVariantData.get_option_bool(receipt_entries_result, "available")
		else _make_source_entries(profile, budget_state)
	)
	var compiler_fingerprint: Dictionary = _make_compiler_fingerprint(profile, options, budget_state)
	var output_entries: Array[Dictionary] = _make_output_entries(profile, options, budget_state)
	var profile_summary: Dictionary = {
		"profile": profile.describe(),
		"resource_entries": profile_entries,
	}
	var tracked_options: Dictionary = _make_tracked_options(profile, options)
	var manifest: Dictionary = {
		"format": FORMAT,
		"format_version": FORMAT_VERSION,
		"artifact_owner": _ARTIFACT_OWNER,
		"profile_path": profile_path,
		"profile_id": String(profile.profile_id),
		"profile_digest": _sha256_variant(profile_summary),
		"input_digest": _sha256_variant(source_entries),
		"output_digest": _sha256_variant(output_entries),
		"options_digest": _sha256_variant(tracked_options),
		"compiler_digest": _sha256_variant(compiler_fingerprint),
		"compiler_fingerprint": compiler_fingerprint,
		"profile_entries": profile_entries,
		"source_entries": source_entries,
		"output_entries": output_entries,
		"scan_report": _make_digest_scan_report(budget_state),
		"metadata": GFVariantData.get_option_dictionary(options, "manifest_metadata").duplicate(true),
		"run_summary": _make_run_summary(run_result),
	}
	manifest["manifest_digest"] = _sha256_variant(_make_digest_projection(manifest))
	return manifest


## 读取 manifest JSON 文件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param manifest_path: manifest JSON 路径。
## [br]
## @return: 读取报告。
## [br]
## @schema return: Dictionary，包含 success、path、manifest、error_code 和 error。
func load_manifest(manifest_path: String) -> Dictionary:
	if manifest_path.strip_edges().is_empty():
		return _make_load_result(false, manifest_path, {}, ERR_INVALID_PARAMETER, "manifest 路径为空。")
	if not FileAccess.file_exists(manifest_path):
		return _make_load_result(false, manifest_path, {}, ERR_FILE_NOT_FOUND, "manifest 文件不存在：%s。" % manifest_path)

	var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		return _make_load_result(false, manifest_path, {}, open_error, "无法读取 manifest：%s。" % manifest_path)

	var manifest_size: int = file.get_length()
	if manifest_size > _DEFAULT_MAX_MANIFEST_BYTES:
		file.close()
		return _make_load_result(
			false,
			manifest_path,
			{},
			ERR_OUT_OF_MEMORY,
			"manifest 超过最大读取预算：%d > %d。" % [manifest_size, _DEFAULT_MAX_MANIFEST_BYTES]
		)
	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		return _make_load_result(false, manifest_path, {}, read_error, "读取 manifest 失败：%s。" % error_string(read_error))
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(text)
	if parse_error != OK:
		return _make_load_result(
			false,
			manifest_path,
			{},
			parse_error,
			"manifest JSON 解析失败：%s:%d。" % [parser.get_error_message(), parser.get_error_line()]
		)

	var parsed_value: Variant = parser.data
	if not (parsed_value is Dictionary):
		return _make_load_result(false, manifest_path, {}, ERR_INVALID_DATA, "manifest 根节点必须是 Dictionary。")

	var manifest: Dictionary = parsed_value
	if GFVariantData.get_option_string(manifest, "format") != FORMAT:
		return _make_load_result(false, manifest_path, manifest, ERR_INVALID_DATA, "manifest format 不匹配。")
	if GFVariantData.get_option_int(manifest, "format_version") != FORMAT_VERSION:
		return _make_load_result(false, manifest_path, manifest, ERR_INVALID_DATA, "manifest format_version 不支持。")
	if GFVariantData.get_option_string(manifest, _ARTIFACT_OWNER_FIELD) != _ARTIFACT_OWNER:
		return _make_load_result(false, manifest_path, manifest, ERR_UNAUTHORIZED, "manifest artifact_owner 不匹配。")
	var has_compiler_fingerprint: bool = manifest.has("compiler_fingerprint")
	var has_compiler_digest: bool = manifest.has("compiler_digest")
	if has_compiler_fingerprint != has_compiler_digest:
		return _make_load_result(false, manifest_path, manifest, ERR_INVALID_DATA, "manifest compiler fingerprint 字段不完整。")
	if has_compiler_fingerprint:
		var compiler_fingerprint: Dictionary = _normalize_compiler_fingerprint(
			GFVariantData.get_option_dictionary(manifest, "compiler_fingerprint")
		)
		var stored_compiler_digest: String = GFVariantData.get_option_string(manifest, "compiler_digest")
		if stored_compiler_digest.is_empty() or stored_compiler_digest != _sha256_variant(compiler_fingerprint):
			return _make_load_result(false, manifest_path, manifest, ERR_INVALID_DATA, "manifest compiler_digest 校验失败。")
	var stored_digest: String = GFVariantData.get_option_string(manifest, "manifest_digest")
	var expected_digest: String = _sha256_variant(_make_digest_projection(manifest))
	if stored_digest.is_empty() or stored_digest != expected_digest:
		return _make_load_result(
			false,
			manifest_path,
			manifest,
			ERR_INVALID_DATA,
			"manifest_digest 校验失败。"
		)
	return _make_load_result(true, manifest_path, manifest, OK, "")


## 保存 manifest JSON 文件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param manifest_path: res:// 或 user:// manifest JSON 输出 URI；成功结果会返回规范化后的 URI。
## [br]
## @param manifest: make_manifest() 返回的字典。
## [br]
## @schema manifest: Dictionary，包含 format、format_version、artifact_owner、profile_digest、input_digest、output_digest、options_digest、compiler_digest、compiler_fingerprint、profile_entries、source_entries、output_entries 和 scan_report。
## [br]
## @param options: 保存选项。
## [br]
## @schema options: Dictionary，可包含 dry_run、overwrite_existing、allow_unowned_overwrite、indent、sort_keys、allow_parent_output_path 和 allow_gf_source_output；allow_parent_output_path 只允许规范化 URI 根内的父级片段，allow_gf_source_output 只放行 res://addons/gf 源码目录保护，allow_unowned_overwrite 仅用于调用方已明确确认现有文件所有权的迁移场景。
## [br]
## @return: 保存报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、artifact_report、written、changed 和 dry_run。
func save_manifest(manifest_path: String, manifest: Dictionary, options: Dictionary = {}) -> Dictionary:
	var path_result: Dictionary = _OUTPUT_PATH_POLICY_SCRIPT.resolve_output_path(
		manifest_path,
		options,
		"manifest"
	)
	if not GFVariantData.get_option_bool(path_result, "success"):
		var path_error: String = GFVariantData.get_option_string(path_result, "error")
		var failure_report: Dictionary = _GENERATED_ARTIFACT_REPORT_SCRIPT.make_report(
			manifest_path,
			_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED,
			ERR_INVALID_PARAMETER,
			path_error,
			{
				"dry_run": GFVariantData.get_option_bool(options, "dry_run", false),
				"generator_id": "gf.tool.config_pipeline",
				"source_id": GFVariantData.get_option_string(manifest, "profile_path"),
			}
		)
		return _make_save_result(false, manifest_path, ERR_INVALID_PARAMETER, path_error, failure_report)
	manifest_path = GFVariantData.get_option_string(path_result, "path")

	var scan_report: Dictionary = GFVariantData.get_option_dictionary(manifest, "scan_report")
	if not GFVariantData.get_option_bool(scan_report, "success", false):
		var scan_error: String = GFVariantData.get_option_string(scan_report, "error", "manifest freshness 扫描失败。")
		var scan_failure_report: Dictionary = _make_failure_artifact_report(
			manifest_path,
			ERR_OUT_OF_MEMORY,
			scan_error,
			options,
			GFVariantData.get_option_string(manifest, "profile_path")
		)
		return _make_save_result(false, manifest_path, ERR_OUT_OF_MEMORY, scan_error, scan_failure_report)

	var ownership_error: String = _validate_existing_manifest_ownership(manifest_path, options)
	if not ownership_error.is_empty():
		var ownership_failure_report: Dictionary = _make_failure_artifact_report(
			manifest_path,
			ERR_UNAUTHORIZED,
			ownership_error,
			options,
			GFVariantData.get_option_string(manifest, "profile_path")
		)
		return _make_save_result(false, manifest_path, ERR_UNAUTHORIZED, ownership_error, ownership_failure_report)

	var indent: String = GFVariantData.get_option_string(options, "indent", _DEFAULT_JSON_INDENT)
	var sort_keys: bool = GFVariantData.get_option_bool(options, "sort_keys", true)
	var text: String = GFReportValueCodec.stringify_json_compatible(
		manifest,
		indent,
		sort_keys,
		_make_report_codec_options()
	)
	var artifact_options: Dictionary = options.duplicate(true)
	artifact_options["label"] = "GFConfigPipelineArtifactManifest"
	artifact_options["generator_id"] = "gf.tool.config_pipeline"
	artifact_options["source_id"] = GFVariantData.get_option_string(manifest, "profile_path")
	var artifact_report: Dictionary = _GENERATED_ARTIFACT_REPORT_SCRIPT.save_text(manifest_path, text, artifact_options)
	var save_error: Error = _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(artifact_report)
	return _make_save_result(
		save_error == OK,
		manifest_path,
		save_error,
		GFVariantData.get_option_string(artifact_report, "error"),
		artifact_report
	)


## 生成当前 Profile 相对已有 manifest 的 freshness 报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param manifest_path: 已保存 manifest 路径。
## [br]
## @param profile_path: Profile 资源路径。
## [br]
## @param profile: 导表 Profile 资源。
## [br]
## @param options: 本次导表选项。
## [br]
## @schema options: Dictionary，可包含 output_path、access_output_path、access_class_name、access_provider_accessor、build_options、save_options、access_options、max_freshness_file_bytes、max_freshness_total_bytes 和 max_freshness_entries。
## [br]
## @return: freshness 报告。
## [br]
## @schema return: Dictionary，包含 fresh、success、manifest_path、current_manifest、stored_manifest、load_result、scan_report、reasons、missing_outputs 和 changed_fields。
func make_freshness_report(
	manifest_path: String,
	profile_path: String,
	profile: GFConfigPipelineProfile,
	options: Dictionary = {}
) -> Dictionary:
	var current_manifest: Dictionary = make_manifest(profile_path, profile, options)
	var scan_report: Dictionary = GFVariantData.get_option_dictionary(current_manifest, "scan_report")
	if not GFVariantData.get_option_bool(scan_report, "success", false):
		return _make_freshness_result(
			false,
			manifest_path,
			current_manifest,
			{},
			{},
			[GFVariantData.get_option_string(scan_report, "error_code", "freshness_budget_exceeded")],
			[],
			[]
		)
	var load_result: Dictionary = load_manifest(manifest_path)
	if not GFVariantData.get_option_bool(load_result, "success"):
		return _make_freshness_result(false, manifest_path, current_manifest, {}, load_result, ["manifest_unavailable"], [], [])

	var stored_manifest: Dictionary = GFVariantData.get_option_dictionary(load_result, "manifest")
	var changed_fields: PackedStringArray = _compare_manifest_fields(stored_manifest, current_manifest)
	var missing_outputs: PackedStringArray = _find_missing_outputs(stored_manifest)
	var reasons: PackedStringArray = PackedStringArray()
	for field: String in changed_fields:
		var _append_changed_reason: bool = reasons.append("changed_%s" % field)
	for output_path: String in missing_outputs:
		var _append_missing_reason: bool = reasons.append("missing_output:%s" % output_path)

	return _make_freshness_result(
		changed_fields.is_empty() and missing_outputs.is_empty(),
		manifest_path,
		current_manifest,
		stored_manifest,
		load_result,
		_packed_to_array(reasons),
		_packed_to_array(missing_outputs),
		_packed_to_array(changed_fields)
	)


## 根据输出路径推导默认 manifest 路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param output_path: 数据库输出路径。
## [br]
## @return: 默认 manifest 路径；output_path 为空时返回空字符串。
func get_default_manifest_path(output_path: String) -> String:
	if output_path.strip_edges().is_empty():
		return ""
	return "%s.manifest.json" % output_path


# --- 框架内部方法 ---

## 配置本次产物实际使用的 Pipeline 阶段描述。
## [br]
## @api framework_internal
## [br]
## @param stage_descriptors: 按 Reader、Layout、Validation、Target、Commit 排列的阶段描述。
## [br]
## @schema stage_descriptors: Array[Dictionary]，每项包含 stage_id、implementation_version、implementation_path 和可选 implementation_dependencies。
func configure_compiler_stages(
	stage_descriptors: Array[Dictionary]
) -> void:
	_compiler_stage_descriptors.clear()
	for descriptor: Dictionary in stage_descriptors:
		_compiler_stage_descriptors.append(descriptor.duplicate(true))


## 校验当前来源路径仍与本次编译实际读取的 source receipts 一致。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param profile: 本次编译的导表 Profile。
## [br]
## @param run_result: 包含 table_results/source_receipt 的构建或导出结果。
## [br]
## @schema run_result: Dictionary，必须包含与 profile.sources 一一对应的 table_results；每项包含 source_receipt。
## [br]
## @param options: freshness 哈希预算选项。
## [br]
## @schema options: Dictionary，可包含 max_freshness_file_bytes、max_freshness_total_bytes 和 max_freshness_entries。
## [br]
## @return: 来源稳定性报告；success 表示校验完成，stable 表示路径当前字节仍等于编译收据。
## [br]
## @schema return: Dictionary，包含 success、stable、error_code、error、receipt_entries、current_entries 和 scan_report。
func make_source_receipt_validation_report(
	profile: GFConfigPipelineProfile,
	run_result: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	if profile == null:
		return _make_source_receipt_validation_failure(
			"invalid_profile",
			"导表 Profile 为空，无法校验编译来源收据。"
		)
	var receipt_budget_state: Dictionary = _make_digest_budget_state(options)
	var receipt_result: Dictionary = _make_compilation_source_entries(
		profile,
		run_result,
		receipt_budget_state
	)
	if not GFVariantData.get_option_bool(receipt_result, "available"):
		return _make_source_receipt_validation_failure(
			"compilation_receipt_unavailable",
			"构建结果没有可验证的编译来源收据。"
		)
	var receipt_scan_report: Dictionary = _make_digest_scan_report(
		receipt_budget_state
	)
	if not GFVariantData.get_option_bool(receipt_scan_report, "success"):
		return _make_source_receipt_validation_failure(
			GFVariantData.get_option_string(
				receipt_scan_report,
				"error_code",
				"invalid_compilation_receipt"
			),
			GFVariantData.get_option_string(receipt_scan_report, "error"),
			receipt_scan_report
		)

	var current_budget_state: Dictionary = _make_digest_budget_state(options)
	var current_entries: Array[Dictionary] = _make_source_entries(
		profile,
		current_budget_state
	)
	var scan_report: Dictionary = _make_digest_scan_report(current_budget_state)
	if not GFVariantData.get_option_bool(scan_report, "success"):
		return _make_source_receipt_validation_failure(
			GFVariantData.get_option_string(
				scan_report,
				"error_code",
				"source_receipt_scan_failed"
			),
			GFVariantData.get_option_string(scan_report, "error"),
			scan_report
		)
	var receipt_entries: Array[Dictionary] = _get_dictionary_array_value(
		GFVariantData.get_option_value(receipt_result, "entries")
	)
	var stable: bool = (
		_normalize_digest_source_entries(receipt_entries)
		== _normalize_digest_source_entries(current_entries)
	)
	return {
		"success": true,
		"stable": stable,
		"error_code": "" if stable else "source_changed_during_export",
		"error": "" if stable else "配置表来源在编译后、事务完成前发生变化。",
		"receipt_entries": receipt_entries.duplicate(true),
		"current_entries": current_entries.duplicate(true),
		"scan_report": scan_report.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 为缺失 Profile 构造版本化失败 manifest，保留选项、编译器指纹和运行摘要并计算投影摘要；空输入、输出摘要不表示一次有效扫描。
## [br]
## @api private
func _make_empty_manifest(profile_path: String, options: Dictionary, run_result: Dictionary) -> Dictionary:
	var budget_state: Dictionary = _make_digest_budget_state(options)
	var compiler_fingerprint: Dictionary = _make_compiler_fingerprint(null, options, budget_state)
	var manifest: Dictionary = {
		"format": FORMAT,
		"format_version": FORMAT_VERSION,
		"artifact_owner": _ARTIFACT_OWNER,
		"profile_path": profile_path,
		"profile_id": "",
		"profile_digest": "",
		"input_digest": "",
		"output_digest": "",
		"options_digest": _sha256_variant(_make_semantic_options(options)),
		"compiler_digest": _sha256_variant(compiler_fingerprint),
		"compiler_fingerprint": compiler_fingerprint,
		"profile_entries": [],
		"source_entries": [],
		"output_entries": [],
		"scan_report": {
			"success": false,
			"error_code": "invalid_profile",
			"error": "导表 Profile 为空，无法生成 freshness manifest。",
			"entry_count": 0,
			"hashed_bytes": 0,
		},
		"metadata": GFVariantData.get_option_dictionary(options, "manifest_metadata").duplicate(true),
		"run_summary": _make_run_summary(run_result),
	}
	manifest["manifest_digest"] = _sha256_variant(_make_digest_projection(manifest))
	return manifest


## 从 Profile 路径广度遍历资源依赖，各层依赖排序并按路径去重；每文件计入共享摘要预算，依赖不可用或预算失败时停止并保留已有条目。
## [br]
## @api private
func _make_profile_resource_entries(profile_path: String, budget_state: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if profile_path.strip_edges().is_empty() or not FileAccess.file_exists(profile_path):
		return entries

	var pending_paths: PackedStringArray = PackedStringArray([profile_path])
	var visited_paths: Dictionary = {}
	var pending_index: int = 0
	while pending_index < pending_paths.size():
		if not GFVariantData.get_option_bool(budget_state, "success", true):
			break
		var resource_path: String = pending_paths[pending_index]
		pending_index += 1
		if visited_paths.has(resource_path):
			continue
		visited_paths[resource_path] = true
		if not _reserve_digest_entry(budget_state):
			break

		var file_report: Dictionary = _make_file_digest_report(resource_path, budget_state)
		entries.append(_make_digest_file_entry(resource_path, file_report))
		if not GFVariantData.get_option_bool(budget_state, "success", true):
			break
		if not GFVariantData.get_option_bool(file_report, "exists") or not GFVariantData.get_option_string(file_report, "error").is_empty():
			_set_digest_budget_failure(
				budget_state,
				"freshness_profile_dependency_unavailable",
				"Profile 语义依赖不可用：%s。" % resource_path
			)
			break
		if not _should_scan_resource_dependencies(resource_path) or not ResourceLoader.exists(resource_path):
			continue

		var dependency_paths: PackedStringArray = PackedStringArray()
		for dependency_entry: String in ResourceLoader.get_dependencies(resource_path):
			var dependency_path: String = _extract_dependency_resource_path(dependency_entry)
			if dependency_path.is_empty() or visited_paths.has(dependency_path) or dependency_paths.has(dependency_path):
				continue
			var _dependency_appended: bool = dependency_paths.append(dependency_path)
		dependency_paths.sort()
		for dependency_path: String in dependency_paths:
			var _pending_appended: bool = pending_paths.append(dependency_path)
	return entries


## 汇集契约、框架和 Godot 版本及阶段文件摘要；自定义阶段数量须匹配流水线，生成访问器时另纳入访问器阶段，失败仍返回可诊断的部分指纹。
## [br]
## @api private
func _make_compiler_fingerprint(
	profile: GFConfigPipelineProfile,
	options: Dictionary,
	budget_state: Dictionary
) -> Dictionary:
	var stage_definitions: Array[Dictionary] = []
	var use_configured_stages: bool = not _compiler_stage_descriptors.is_empty()
	if use_configured_stages and _compiler_stage_descriptors.size() != _PIPELINE_STAGE_IDS.size():
		_set_digest_budget_failure(
			budget_state,
			"freshness_compiler_stage_contract_invalid",
			"配置编译阶段描述数量无效：%d != %d。" % [
				_compiler_stage_descriptors.size(),
				_PIPELINE_STAGE_IDS.size(),
			]
		)
		use_configured_stages = false
	for definition: Dictionary in _COMPILER_STAGE_DEFINITIONS:
		var definition_id: String = GFVariantData.get_option_string(definition, "id")
		var configured_index: int = _PIPELINE_STAGE_IDS.find(definition_id)
		if use_configured_stages and configured_index >= 0:
			var descriptor: Dictionary = _compiler_stage_descriptors[configured_index]
			stage_definitions.append({
				"id": GFVariantData.get_option_string(descriptor, "stage_id"),
				"implementation_version": GFVariantData.get_option_int(descriptor, "implementation_version"),
				"path": GFVariantData.get_option_string(descriptor, "implementation_path"),
				"implementation_dependencies": GFVariantData.get_option_packed_string_array(
					descriptor,
					"implementation_dependencies"
				),
			})
		else:
			stage_definitions.append(definition)
	if profile != null and not profile.resolve_access_output_path(options).is_empty():
		for definition: Dictionary in _ACCESS_COMPILER_STAGE_DEFINITIONS:
			stage_definitions.append(definition)

	var stage_entries: Array[Dictionary] = []
	for definition: Dictionary in stage_definitions:
		if not GFVariantData.get_option_bool(budget_state, "success", true) or not _reserve_digest_entry(budget_state):
			break
		var stage_path: String = GFVariantData.get_option_string(definition, "path")
		var file_report: Dictionary = _make_file_digest_report(stage_path, budget_state)
		var stage_entry: Dictionary = {
			"id": GFVariantData.get_option_string(definition, "id"),
			"implementation_version": GFVariantData.get_option_int(definition, "implementation_version"),
			"path": stage_path,
			"exists": GFVariantData.get_option_bool(file_report, "exists"),
			"size_bytes": GFVariantData.get_option_int(file_report, "size_bytes"),
			"sha256": GFVariantData.get_option_string(file_report, "sha256"),
			"error": GFVariantData.get_option_string(file_report, "error"),
			"implementation_dependencies": [],
		}
		if not GFVariantData.get_option_bool(budget_state, "success", true):
			stage_entries.append(stage_entry)
			break
		if not GFVariantData.get_option_bool(file_report, "exists") or not GFVariantData.get_option_string(file_report, "error").is_empty():
			_set_digest_budget_failure(
				budget_state,
				"freshness_compiler_stage_unavailable",
				"配置编译阶段实现不可用：%s。" % stage_path
			)
			stage_entries.append(stage_entry)
			break
		stage_entry["implementation_dependencies"] = _make_compiler_dependency_entries(
			definition,
			stage_path,
			budget_state
		)
		stage_entries.append(stage_entry)
		if not GFVariantData.get_option_bool(budget_state, "success", true):
			break

	var engine_version_info: Dictionary = Engine.get_version_info()
	return {
		"contract_version": _COMPILER_CONTRACT_VERSION,
		"framework_version": _read_framework_version(),
		"godot_version": {
			"major": GFVariantData.get_option_int(engine_version_info, "major"),
			"minor": GFVariantData.get_option_int(engine_version_info, "minor"),
			"patch": GFVariantData.get_option_int(engine_version_info, "patch"),
			"status": GFVariantData.get_option_string(engine_version_info, "status"),
		},
		"stage_entries": stage_entries,
	}


## 只准入规范化后的 res:// 或 user:// 实现依赖，排除阶段自身并排序去重；在共享预算内读取摘要，首个无效或不可用依赖终止收集。
## [br]
## @api private
func _make_compiler_dependency_entries(
	definition: Dictionary,
	stage_path: String,
	budget_state: Dictionary
) -> Array[Dictionary]:
	var dependency_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(
		definition,
		"implementation_dependencies"
	)
	var normalized_paths: PackedStringArray = PackedStringArray()
	var primary_path: String = _normalize_output_path(stage_path)
	for raw_path: String in dependency_paths:
		var dependency_path: String = _normalize_output_path(raw_path)
		if (
			dependency_path.is_empty()
			or not (
				dependency_path.begins_with("res://")
				or dependency_path.begins_with("user://")
			)
		):
			_set_digest_budget_failure(
				budget_state,
				"freshness_compiler_dependency_invalid",
				"编译器实现依赖必须使用 res:// 或 user://：%s。" % raw_path
			)
			return []
		if (
			dependency_path == primary_path
			or normalized_paths.has(dependency_path)
		):
			continue
		var _path_appended: bool = normalized_paths.append(dependency_path)
	normalized_paths.sort()

	var entries: Array[Dictionary] = []
	for dependency_path: String in normalized_paths:
		if not GFVariantData.get_option_bool(budget_state, "success", true):
			break
		if not _reserve_digest_entry(budget_state):
			break
		var file_report: Dictionary = _make_file_digest_report(
			dependency_path,
			budget_state
		)
		entries.append({
			"path": dependency_path,
			"exists": GFVariantData.get_option_bool(file_report, "exists"),
			"size_bytes": GFVariantData.get_option_int(file_report, "size_bytes"),
			"sha256": GFVariantData.get_option_string(file_report, "sha256"),
			"error": GFVariantData.get_option_string(file_report, "error"),
		})
		if not GFVariantData.get_option_bool(budget_state, "success", true):
			break
		if (
			not GFVariantData.get_option_bool(file_report, "exists")
			or not GFVariantData.get_option_string(file_report, "error").is_empty()
		):
			_set_digest_budget_failure(
				budget_state,
				"freshness_compiler_dependency_unavailable",
				"配置编译阶段实现依赖不可用：%s。" % dependency_path
			)
			break
	return entries


## 按 Profile 来源顺序消费已有编译收据，要求结果数量和各收据身份匹配并计入预算；此处不重读文件，缺少 table_results 才报告收据不可用。
## [br]
## @api private
func _make_compilation_source_entries(
	profile: GFConfigPipelineProfile,
	run_result: Dictionary,
	budget_state: Dictionary
) -> Dictionary:
	if not run_result.has("table_results") and not run_result.has(&"table_results"):
		return { "available": false, "entries": [] }
	var entries: Array[Dictionary] = []
	var table_results: Array = GFVariantData.get_option_array(
		run_result,
		"table_results"
	)
	if table_results.size() != profile.sources.size():
		_set_digest_budget_failure(
			budget_state,
			"freshness_compilation_receipt_count_mismatch",
			"编译来源收据数量与 Profile 来源数量不一致：%d != %d。" % [
				table_results.size(),
				profile.sources.size(),
			]
		)
		return { "available": true, "entries": entries }

	for source_index: int in range(profile.sources.size()):
		if not GFVariantData.get_option_bool(budget_state, "success", true):
			break
		var source: GFConfigPipelineTableSource = profile.sources[source_index]
		var table_result: Dictionary = GFVariantData.as_dictionary(
			table_results[source_index]
		)
		var receipt: Dictionary = GFVariantData.get_option_dictionary(
			table_result,
			"source_receipt"
		)
		var receipt_error: String = _get_compilation_source_receipt_error(
			source,
			receipt
		)
		if not receipt_error.is_empty():
			_set_digest_budget_failure(
				budget_state,
				"freshness_compilation_receipt_invalid",
				receipt_error
			)
			break
		if not _reserve_digest_entry(budget_state):
			break
		var size_bytes: int = GFVariantData.get_option_int(receipt, "size_bytes")
		if not _reserve_receipt_bytes(
			budget_state,
			GFVariantData.get_option_string(receipt, "source_path"),
			size_bytes
		):
			break
		entries.append({
			"valid": true,
			"table_name": GFVariantData.get_option_string(receipt, "table_name"),
			"source_path": GFVariantData.get_option_string(receipt, "source_path"),
			"source_format": GFVariantData.get_option_string(receipt, "source_format"),
			"exists": true,
			"size_bytes": size_bytes,
			"sha256": GFVariantData.get_option_string(receipt, "sha256").to_lower(),
			"error": "",
		})
	return { "available": true, "entries": entries }


## 依次核对收据格式、版本、表名、规范路径、来源格式、非负精确整数字节数和 SHA-256 文本，返回首项错误而不验证当前磁盘内容。
## [br]
## @api private
func _get_compilation_source_receipt_error(
	source: GFConfigPipelineTableSource,
	receipt: Dictionary
) -> String:
	if source == null:
		return "Profile 包含空来源，无法绑定编译收据。"
	if receipt.is_empty():
		return "编译结果缺少来源收据：%s。" % source.source_path
	if GFVariantData.get_option_string(receipt, "format") != _SOURCE_RECEIPT_FORMAT:
		return "编译来源收据格式无效：%s。" % source.source_path
	if (
		GFVariantData.get_option_int(receipt, "format_version")
		!= _SOURCE_RECEIPT_FORMAT_VERSION
	):
		return "编译来源收据版本无效：%s。" % source.source_path
	if (
		GFVariantData.get_option_string(receipt, "table_name")
		!= String(source.get_table_key())
	):
		return "编译来源收据表名与 Profile 不一致：%s。" % source.source_path
	if (
		_normalize_output_path(
			GFVariantData.get_option_string(receipt, "source_path")
		)
		!= _normalize_output_path(source.source_path)
	):
		return "编译来源收据路径与 Profile 不一致：%s。" % source.source_path
	if (
		GFVariantData.get_option_string(receipt, "source_format")
		!= String(source.get_resolved_format())
	):
		return "编译来源收据格式与 Profile 不一致：%s。" % source.source_path
	var size_value: Variant = GFVariantData.get_option_value(
		receipt,
		"size_bytes",
		null
	)
	if not size_value is int:
		return "编译来源收据 size_bytes 必须是非负精确整数：%s。" % source.source_path
	var exact_size_bytes: int = size_value
	if exact_size_bytes < 0:
		return "编译来源收据 size_bytes 必须是非负精确整数：%s。" % source.source_path
	var sha256: String = GFVariantData.get_option_string(receipt, "sha256").to_lower()
	if not _is_lower_hex(sha256, 64):
		return "编译来源收据 sha256 无效：%s。" % source.source_path
	return ""


## 以收据声明的大小检查单文件和剩余总字节预算；成功才增加累计字节，失败保留已消费额度并记录首错。
## [br]
## @api private
func _reserve_receipt_bytes(
	budget_state: Dictionary,
	source_path: String,
	size_bytes: int
) -> bool:
	var max_file_bytes: int = GFVariantData.get_option_int(
		budget_state,
		"max_file_bytes"
	)
	if size_bytes > max_file_bytes:
		_set_digest_budget_failure(
			budget_state,
			"freshness_file_budget_exceeded",
			"freshness 单文件预算超限：%s (%d > %d)。" % [
				source_path,
				size_bytes,
				max_file_bytes,
			]
		)
		return false
	var hashed_bytes: int = GFVariantData.get_option_int(
		budget_state,
		"hashed_bytes"
	)
	var max_total_bytes: int = GFVariantData.get_option_int(
		budget_state,
		"max_total_bytes"
	)
	if size_bytes > max_total_bytes - hashed_bytes:
		_set_digest_budget_failure(
			budget_state,
			"freshness_total_budget_exceeded",
			"freshness 累计字节预算超限：%s (%d + %d > %d)。" % [
				source_path,
				hashed_bytes,
				size_bytes,
				max_total_bytes,
			]
		)
		return false
	budget_state["hashed_bytes"] = hashed_bytes + size_bytes
	return true


## 按 Profile 来源顺序重新读取文件摘要，每项先占条目预算；空来源登记无效项并继续，预算失败停止，文件错误留在条目中。
## [br]
## @api private
func _make_source_entries(profile: GFConfigPipelineProfile, budget_state: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for source: GFConfigPipelineTableSource in profile.sources:
		if not GFVariantData.get_option_bool(budget_state, "success", true):
			break
		if not _reserve_digest_entry(budget_state):
			break
		if source == null:
			entries.append({
				"valid": false,
				"exists": false,
				"error": "source_null",
			})
			continue

		var source_path: String = _normalize_output_path(source.source_path)
		var file_report: Dictionary = _make_file_digest_report(source_path, budget_state)
		entries.append({
			"valid": true,
			"table_name": String(source.get_table_key()),
			"source_path": source_path,
			"source_format": String(source.get_resolved_format()),
			"exists": GFVariantData.get_option_bool(file_report, "exists"),
			"size_bytes": GFVariantData.get_option_int(file_report, "size_bytes"),
			"sha256": GFVariantData.get_option_string(file_report, "sha256"),
			"error": GFVariantData.get_option_string(file_report, "error"),
		})
	return entries


## 按数据库、访问器顺序收集非空输出路径摘要；共享预算失败后不再收集后续访问器输出。
## [br]
## @api private
func _make_output_entries(
	profile: GFConfigPipelineProfile,
	options: Dictionary,
	budget_state: Dictionary
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var output_path: String = profile.resolve_output_path(options)
	if not output_path.is_empty() and _reserve_digest_entry(budget_state):
		entries.append(_make_output_entry("database", output_path, budget_state))

	var access_output_path: String = profile.resolve_access_output_path(options)
	if (
		not access_output_path.is_empty()
		and GFVariantData.get_option_bool(budget_state, "success", true)
		and _reserve_digest_entry(budget_state)
	):
		entries.append(_make_output_entry("access", access_output_path, budget_state))
	return entries


## 将文件摘要投影为输出种类、路径、存在性、长度和哈希；读取错误不单列于输出项，预算错误仍保留在共享扫描状态。
## [br]
## @api private
func _make_output_entry(kind: String, output_path: String, budget_state: Dictionary) -> Dictionary:
	var file_report: Dictionary = _make_file_digest_report(output_path, budget_state)
	return {
		"kind": kind,
		"path": output_path,
		"exists": GFVariantData.get_option_bool(file_report, "exists"),
		"size_bytes": GFVariantData.get_option_int(file_report, "size_bytes"),
		"sha256": GFVariantData.get_option_string(file_report, "sha256"),
	}


## 先去除非内容选项，再用 Profile 解析实际输出路径、访问器配置和各阶段选项，形成 freshness 的选项摘要输入。
## [br]
## @api private
func _make_tracked_options(profile: GFConfigPipelineProfile, options: Dictionary) -> Dictionary:
	var semantic_options: Dictionary = _make_semantic_options(options)
	return {
		"output_path": profile.resolve_output_path(semantic_options),
		"access_output_path": profile.resolve_access_output_path(semantic_options),
		"access_class_name": profile.resolve_access_class_name(semantic_options),
		"access_provider_accessor": profile.resolve_access_provider_accessor(semantic_options),
		"build_options": profile.make_build_options(semantic_options),
		"save_options": profile.make_save_options(semantic_options),
		"access_options": profile.make_access_options(semantic_options),
	}


## 复制选项并删除明确列出的缓存、展示、运行开关和 manifest 管理字段；其余未知键也保留在语义投影中。
## [br]
## @api private
func _make_semantic_options(options: Dictionary) -> Dictionary:
	var result: Dictionary = options.duplicate(true)
	var ignored_keys: PackedStringArray = PackedStringArray([
		"cache_mode",
		"changed_only",
		"dry_run",
		"json_report",
		"manifest_metadata",
		"manifest_options",
		"manifest_path",
		"pretty_output",
		"strict",
		"type_hint",
		"usage_requested",
		"write_manifest",
	])
	for key: String in ignored_keys:
		var _removed: bool = result.erase(key)
	return result


## 从运行结果投影 success、operation、profile、路径、错误及子报告摘要。
## [br]
## @api private
## [br]
func _make_run_summary(run_result: Dictionary) -> Dictionary:
	if run_result.is_empty():
		return {}
	return {
		"success": GFVariantData.get_option_bool(run_result, "success"),
		"operation": String(GFVariantData.get_option_string_name(run_result, "operation")),
		"profile_id": String(GFVariantData.get_option_string_name(run_result, "profile_id")),
		"output_path": GFVariantData.get_option_string(run_result, "output_path"),
		"error": GFVariantData.get_option_string(run_result, "error"),
		"report": _make_report_summary(GFVariantData.get_option_dictionary(run_result, "report")),
		"save_result": _make_artifact_result_summary(GFVariantData.get_option_dictionary(run_result, "save_result")),
		"access_result": _make_artifact_result_summary(GFVariantData.get_option_dictionary(run_result, "access_result")),
	}


## 将验证报告投影为 ok、错误/警告/issue 数量；空报告返回空字典。
## [br]
## @api private
## [br]
func _make_report_summary(report: Dictionary) -> Dictionary:
	if report.is_empty():
		return {}
	return {
		"ok": GFVariantData.get_option_bool(report, "ok"),
		"error_count": GFVariantData.get_option_int(report, "error_count"),
		"warning_count": GFVariantData.get_option_int(report, "warning_count"),
		"issue_count": GFVariantData.get_option_array(report, "issues").size(),
	}


## 将产物结果投影为路径、状态、写入/变更/dry-run 和 artifact 状态字段。
## [br]
## @api private
## [br]
func _make_artifact_result_summary(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {}
	var artifact_report: Dictionary = GFVariantData.get_option_dictionary(result, "artifact_report")
	return {
		"success": GFVariantData.get_option_bool(result, "success", true),
		"path": GFVariantData.get_option_string(result, "path"),
		"status": String(GFVariantData.get_option_string_name(result, "status")),
		"written": GFVariantData.get_option_bool(result, "written"),
		"changed": GFVariantData.get_option_bool(result, "changed"),
		"dry_run": GFVariantData.get_option_bool(result, "dry_run"),
		"artifact_status": String(GFVariantData.get_option_string_name(artifact_report, "status")),
	}


## 保留文件路径及读取报告的存在性、长度、哈希和错误文本，不把空摘要补写成成功摘要。
## [br]
## @api private
func _make_digest_file_entry(path: String, file_report: Dictionary) -> Dictionary:
	return {
		"path": path,
		"exists": GFVariantData.get_option_bool(file_report, "exists"),
		"size_bytes": GFVariantData.get_option_int(file_report, "size_bytes"),
		"sha256": GFVariantData.get_option_string(file_report, "sha256"),
		"error": GFVariantData.get_option_string(file_report, "error"),
	}


## 仅对 tres、res、tscn 和 scn 扩展名的资源路径扫描资源依赖。
## [br]
## @api private
## [br]
func _should_scan_resource_dependencies(resource_path: String) -> bool:
	var extension: String = resource_path.get_extension().to_lower()
	return extension == "tres" or extension == "res" or extension == "tscn" or extension == "scn"


## 从 :: 分段中返回首个经清理后以 res:// 或 user:// 开头的路径。
## [br]
## @api private
## [br]
func _extract_dependency_resource_path(dependency_entry: String) -> String:
	for raw_part: String in dependency_entry.split("::", false):
		var candidate: String = raw_part.strip_edges().replace("\\", "/")
		if candidate.begins_with("res://") or candidate.begins_with("user://"):
			return candidate
	return ""


## 从插件配置读取框架版本；无法读取或解析时返回空字符串。
## [br]
## @api private
## [br]
func _read_framework_version() -> String:
	var config: ConfigFile = ConfigFile.new()
	var load_result: Error = config.load(_PLUGIN_CONFIG_PATH)
	if load_result != OK:
		return ""
	return GFVariantData.to_text(config.get_value("plugin", "version", "")).strip_edges()


## 初始化一次共享扫描的条目与字节计数，读取限额覆盖值并把负数收紧为零。
## [br]
## @api private
func _make_digest_budget_state(options: Dictionary) -> Dictionary:
	return {
		"success": true,
		"error_code": "",
		"error": "",
		"entry_count": 0,
		"hashed_bytes": 0,
		"max_file_bytes": maxi(
			GFVariantData.get_option_int(
				options,
				"max_freshness_file_bytes",
				_DEFAULT_MAX_FRESHNESS_FILE_BYTES
			),
			0
		),
		"max_total_bytes": maxi(
			GFVariantData.get_option_int(
				options,
				"max_freshness_total_bytes",
				_DEFAULT_MAX_FRESHNESS_TOTAL_BYTES
			),
			0
		),
		"max_entries": maxi(
			GFVariantData.get_option_int(
				options,
				"max_freshness_entries",
				_DEFAULT_MAX_FRESHNESS_ENTRIES
			),
			0
		),
	}


## 仅在扫描仍成功且条目未到上限时递增计数；首次超限锁定失败，后续申请直接拒绝。
## [br]
## @api private
func _reserve_digest_entry(budget_state: Dictionary) -> bool:
	if not GFVariantData.get_option_bool(budget_state, "success", true):
		return false
	var entry_count: int = GFVariantData.get_option_int(budget_state, "entry_count")
	var max_entries: int = GFVariantData.get_option_int(budget_state, "max_entries")
	if entry_count >= max_entries:
		_set_digest_budget_failure(
			budget_state,
			"freshness_entry_budget_exceeded",
			"freshness 条目预算超限：%d >= %d。" % [entry_count, max_entries]
		)
		return false
	budget_state["entry_count"] = entry_count + 1
	return true


## 锁定扫描的首个错误码和说明；已失败状态不再被后续错误覆盖。
## [br]
## @api private
func _set_digest_budget_failure(budget_state: Dictionary, error_code: String, message: String) -> void:
	if not GFVariantData.get_option_bool(budget_state, "success", true):
		return
	budget_state["success"] = false
	budget_state["error_code"] = error_code
	budget_state["error"] = message


## 把共享预算状态投影为独立报告，保留首错、已预留条目和字节以及三类上限。
## [br]
## @api private
func _make_digest_scan_report(budget_state: Dictionary) -> Dictionary:
	return {
		"success": GFVariantData.get_option_bool(budget_state, "success", true),
		"error_code": GFVariantData.get_option_string(budget_state, "error_code"),
		"error": GFVariantData.get_option_string(budget_state, "error"),
		"entry_count": GFVariantData.get_option_int(budget_state, "entry_count"),
		"hashed_bytes": GFVariantData.get_option_int(budget_state, "hashed_bytes"),
		"max_file_bytes": GFVariantData.get_option_int(budget_state, "max_file_bytes"),
		"max_total_bytes": GFVariantData.get_option_int(budget_state, "max_total_bytes"),
		"max_entries": GFVariantData.get_option_int(budget_state, "max_entries"),
	}


## 打开文件并按当前长度预留字节预算后分块计算 SHA-256，所有打开后的退出路径关闭句柄；后续读取或哈希失败不退还已预留字节。
## [br]
## @api private
func _make_file_digest_report(path: String, budget_state: Dictionary) -> Dictionary:
	if path.strip_edges().is_empty():
		return {
			"exists": false,
			"size_bytes": 0,
			"sha256": "",
			"error": "empty_path",
		}
	if not FileAccess.file_exists(path):
		return {
			"exists": false,
			"size_bytes": 0,
			"sha256": "",
			"error": "file_not_found",
		}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"exists": true,
			"size_bytes": 0,
			"sha256": "",
			"error": "file_open_failed",
		}

	var length: int = file.get_length()
	var max_file_bytes: int = GFVariantData.get_option_int(budget_state, "max_file_bytes")
	if length > max_file_bytes:
		file.close()
		_set_digest_budget_failure(
			budget_state,
			"freshness_file_budget_exceeded",
			"freshness 单文件预算超限：%s (%d > %d)。" % [path, length, max_file_bytes]
		)
		return {
			"exists": true,
			"size_bytes": length,
			"sha256": "",
			"error": "freshness_file_budget_exceeded",
		}
	var hashed_bytes: int = GFVariantData.get_option_int(budget_state, "hashed_bytes")
	var max_total_bytes: int = GFVariantData.get_option_int(budget_state, "max_total_bytes")
	if length > max_total_bytes - hashed_bytes:
		file.close()
		_set_digest_budget_failure(
			budget_state,
			"freshness_total_budget_exceeded",
			"freshness 累计字节预算超限：%s (%d + %d > %d)。" % [path, hashed_bytes, length, max_total_bytes]
		)
		return {
			"exists": true,
			"size_bytes": length,
			"sha256": "",
			"error": "freshness_total_budget_exceeded",
		}
	budget_state["hashed_bytes"] = hashed_bytes + length
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		file.close()
		return {
			"exists": true,
			"size_bytes": length,
			"sha256": "",
			"error": "hash_start_failed",
		}
	while file.get_position() < length:
		var remaining: int = length - file.get_position()
		var chunk: PackedByteArray = file.get_buffer(mini(remaining, _DIGEST_CHUNK_BYTES))
		if file.get_error() != OK:
			file.close()
			return {
				"exists": true,
				"size_bytes": length,
				"sha256": "",
				"error": "file_read_failed",
			}
		var update_error: Error = context.update(chunk)
		if update_error != OK:
			file.close()
			return {
				"exists": true,
				"size_bytes": length,
				"sha256": "",
				"error": "hash_update_failed",
			}
	file.close()
	return {
		"exists": true,
		"size_bytes": length,
		"sha256": context.finish().hex_encode(),
		"error": "",
	}


## 比较 Profile 与 input/output/options/compiler digest 字段并返回不同字段名。
## [br]
## @api private
## [br]
func _compare_manifest_fields(stored_manifest: Dictionary, current_manifest: Dictionary) -> PackedStringArray:
	var changed_fields: PackedStringArray = PackedStringArray()
	var fields: PackedStringArray = PackedStringArray([
		"profile_path",
		"profile_id",
		"profile_digest",
		"input_digest",
		"output_digest",
		"options_digest",
		"compiler_digest",
	])
	for field: String in fields:
		if GFVariantData.get_option_string(stored_manifest, field) != GFVariantData.get_option_string(current_manifest, field):
			var _append_field: bool = changed_fields.append(field)
	return changed_fields


## 返回 output_entries 中 path 非空且当前不存在的文件路径。
## [br]
## @api private
## [br]
func _find_missing_outputs(manifest: Dictionary) -> PackedStringArray:
	var missing_outputs: PackedStringArray = PackedStringArray()
	var output_entries: Array = GFVariantData.get_option_array(manifest, "output_entries")
	for entry_value: Variant in output_entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		var path: String = GFVariantData.get_option_string(entry, "path")
		if path.is_empty():
			continue
		if not FileAccess.file_exists(path):
			var _append_missing: bool = missing_outputs.append(path)
	return missing_outputs


## 构造 manifest 加载结果，并复制 manifest 字典。
## [br]
## @api private
## [br]
func _make_load_result(
	success: bool,
	manifest_path: String,
	manifest: Dictionary,
	error_code: Error,
	message: String
) -> Dictionary:
	return {
		"success": success,
		"path": manifest_path,
		"manifest": manifest.duplicate(true),
		"error_code": error_code,
		"error": message,
	}


## 构造 manifest 保存结果，并投影产物报告状态和写入标志。
## [br]
## @api private
## [br]
func _make_save_result(
	success: bool,
	manifest_path: String,
	error_code: Error,
	message: String,
	artifact_report: Dictionary
) -> Dictionary:
	return {
		"success": success,
		"path": manifest_path,
		"error_code": error_code,
		"error": message,
		"artifact_report": artifact_report.duplicate(true),
		"status": GFVariantData.get_option_string_name(artifact_report, "status"),
		"written": GFVariantData.get_option_bool(artifact_report, "written"),
		"changed": GFVariantData.get_option_bool(artifact_report, "changed"),
		"dry_run": GFVariantData.get_option_bool(artifact_report, "dry_run"),
	}


## 构造 freshness 比较结果，并复制当前/存储清单及原因和差异数组。
## [br]
## @api private
## [br]
func _make_freshness_result(
	fresh: bool,
	manifest_path: String,
	current_manifest: Dictionary,
	stored_manifest: Dictionary,
	load_result: Dictionary,
	reasons: Array,
	missing_outputs: Array,
	changed_fields: Array
) -> Dictionary:
	return {
		"success": fresh,
		"fresh": fresh,
		"manifest_path": manifest_path,
		"current_manifest": current_manifest.duplicate(true),
		"stored_manifest": stored_manifest.duplicate(true),
		"load_result": load_result.duplicate(true),
		"scan_report": GFVariantData.get_option_dictionary(current_manifest, "scan_report").duplicate(true),
		"reasons": reasons.duplicate(true),
		"missing_outputs": missing_outputs.duplicate(true),
		"changed_fields": changed_fields.duplicate(true),
	}


## 构造不稳定的 source receipt 校验失败结果，并复制可选 scan_report。
## [br]
## @api private
## [br]
func _make_source_receipt_validation_failure(
	error_code: String,
	message: String,
	scan_report: Dictionary = {}
) -> Dictionary:
	return {
		"success": false,
		"stable": false,
		"error_code": error_code,
		"error": message,
		"receipt_entries": [],
		"current_entries": [],
		"scan_report": scan_report.duplicate(true),
	}


## 按固定字段投影 manifest 的内容身份与校验摘要，排除展示元数据；只有原始字段存在时才纳入 Profile 依赖和编译器扩展字段。
## [br]
## @api private
func _make_digest_projection(manifest: Dictionary) -> Dictionary:
	var projection: Dictionary = {
		"format": GFVariantData.get_option_string(manifest, "format"),
		"format_version": GFVariantData.get_option_int(manifest, "format_version"),
		"artifact_owner": GFVariantData.get_option_string(manifest, _ARTIFACT_OWNER_FIELD),
		"profile_path": GFVariantData.get_option_string(manifest, "profile_path"),
		"profile_id": GFVariantData.get_option_string(manifest, "profile_id"),
		"profile_digest": GFVariantData.get_option_string(manifest, "profile_digest"),
		"input_digest": GFVariantData.get_option_string(manifest, "input_digest"),
		"output_digest": GFVariantData.get_option_string(manifest, "output_digest"),
		"options_digest": GFVariantData.get_option_string(manifest, "options_digest"),
		"validation_summary": _make_validation_summary(GFVariantData.get_option_dictionary(manifest, "run_summary")),
		"source_entries": _normalize_digest_source_entries(GFVariantData.get_option_array(manifest, "source_entries")),
		"output_entries": _normalize_digest_output_entries(GFVariantData.get_option_array(manifest, "output_entries")),
	}
	if manifest.has("profile_entries"):
		projection["profile_entries"] = _normalize_digest_file_entries(
			GFVariantData.get_option_array(manifest, "profile_entries")
		)
	if manifest.has("compiler_fingerprint") or manifest.has("compiler_digest"):
		projection["compiler_fingerprint"] = _normalize_compiler_fingerprint(
			GFVariantData.get_option_dictionary(manifest, "compiler_fingerprint")
		)
		projection["compiler_digest"] = GFVariantData.get_option_string(manifest, "compiler_digest")
	return projection


## 从 run_summary 和其 report 投影 success、ok、错误、警告和 issue 数。
## [br]
## @api private
## [br]
func _make_validation_summary(run_summary: Dictionary) -> Dictionary:
	var report: Dictionary = GFVariantData.get_option_dictionary(run_summary, "report")
	return {
		"success": GFVariantData.get_option_bool(run_summary, "success"),
		"ok": GFVariantData.get_option_bool(report, "ok"),
		"error_count": GFVariantData.get_option_int(report, "error_count", -1),
		"warning_count": GFVariantData.get_option_int(report, "warning_count", -1),
		"issue_count": GFVariantData.get_option_int(report, "issue_count", -1),
	}


## 保留来源条目顺序并固定摘要字段；显式无效项只保留 valid、exists 和 error，其余项按有效来源形状投影。
## [br]
## @api private
func _normalize_digest_source_entries(entries: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for entry_value: Variant in entries:
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		if not GFVariantData.get_option_bool(entry, "valid", true):
			normalized.append({
				"valid": false,
				"exists": GFVariantData.get_option_bool(entry, "exists"),
				"error": GFVariantData.get_option_string(entry, "error"),
			})
			continue
		normalized.append({
			"valid": true,
			"table_name": GFVariantData.get_option_string(entry, "table_name"),
			"source_path": GFVariantData.get_option_string(entry, "source_path"),
			"source_format": GFVariantData.get_option_string(entry, "source_format"),
			"exists": GFVariantData.get_option_bool(entry, "exists"),
			"size_bytes": GFVariantData.get_option_int(entry, "size_bytes"),
			"sha256": GFVariantData.get_option_string(entry, "sha256"),
			"error": GFVariantData.get_option_string(entry, "error"),
		})
	return normalized


## 按原顺序将输出项投影为固定种类、路径、存在性、长度和哈希字段，缺失或错误类型使用读取帮助方法的默认值。
## [br]
## @api private
func _normalize_digest_output_entries(entries: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for entry_value: Variant in entries:
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		normalized.append({
			"kind": GFVariantData.get_option_string(entry, "kind"),
			"path": GFVariantData.get_option_string(entry, "path"),
			"exists": GFVariantData.get_option_bool(entry, "exists"),
			"size_bytes": GFVariantData.get_option_int(entry, "size_bytes"),
			"sha256": GFVariantData.get_option_string(entry, "sha256"),
		})
	return normalized


## 按原顺序投影文件摘要字段并保留 error，使依赖不可用的信息进入摘要输入。
## [br]
## @api private
func _normalize_digest_file_entries(entries: Array) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	for entry_value: Variant in entries:
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		normalized.append({
			"path": GFVariantData.get_option_string(entry, "path"),
			"exists": GFVariantData.get_option_bool(entry, "exists"),
			"size_bytes": GFVariantData.get_option_int(entry, "size_bytes"),
			"sha256": GFVariantData.get_option_string(entry, "sha256"),
			"error": GFVariantData.get_option_string(entry, "error"),
		})
	return normalized


## 固定版本和阶段摘要字段并保留阶段及依赖顺序；仅当原阶段显式带依赖字段时才输出该字段，区分旧格式缺省与空依赖列表。
## [br]
## @api private
func _normalize_compiler_fingerprint(fingerprint: Dictionary) -> Dictionary:
	var engine_version: Dictionary = GFVariantData.get_option_dictionary(fingerprint, "godot_version")
	var stage_entries: Array[Dictionary] = []
	for entry_value: Variant in GFVariantData.get_option_array(fingerprint, "stage_entries"):
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		var dependency_entries: Array[Dictionary] = []
		for dependency_value: Variant in GFVariantData.get_option_array(
			entry,
			"implementation_dependencies"
		):
			var dependency: Dictionary = GFVariantData.as_dictionary(
				dependency_value
			)
			dependency_entries.append({
				"path": GFVariantData.get_option_string(dependency, "path"),
				"exists": GFVariantData.get_option_bool(dependency, "exists"),
				"size_bytes": GFVariantData.get_option_int(dependency, "size_bytes"),
				"sha256": GFVariantData.get_option_string(dependency, "sha256"),
				"error": GFVariantData.get_option_string(dependency, "error"),
			})
		var normalized_entry: Dictionary = {
			"id": GFVariantData.get_option_string(entry, "id"),
			"implementation_version": GFVariantData.get_option_int(entry, "implementation_version"),
			"path": GFVariantData.get_option_string(entry, "path"),
			"exists": GFVariantData.get_option_bool(entry, "exists"),
			"size_bytes": GFVariantData.get_option_int(entry, "size_bytes"),
			"sha256": GFVariantData.get_option_string(entry, "sha256"),
			"error": GFVariantData.get_option_string(entry, "error"),
		}
		if (
			entry.has("implementation_dependencies")
			or entry.has(&"implementation_dependencies")
		):
			normalized_entry["implementation_dependencies"] = dependency_entries
		stage_entries.append(normalized_entry)
	return {
		"contract_version": GFVariantData.get_option_int(fingerprint, "contract_version"),
		"framework_version": GFVariantData.get_option_string(fingerprint, "framework_version"),
		"godot_version": {
			"major": GFVariantData.get_option_int(engine_version, "major"),
			"minor": GFVariantData.get_option_int(engine_version, "minor"),
			"patch": GFVariantData.get_option_int(engine_version, "patch"),
			"status": GFVariantData.get_option_string(engine_version, "status"),
		},
		"stage_entries": stage_entries,
	}


## 用当前报告编码配置生成紧凑、排序键的 JSON 兼容文本，再对 UTF-8 字节计算 SHA-256；摘要对象是编码投影而非原始 Variant。
## [br]
## @api private
func _sha256_variant(value: Variant) -> String:
	var text: String = GFReportValueCodec.stringify_json_compatible(
		value,
		"",
		true,
		_make_report_codec_options()
	)
	return _sha256_bytes(text.to_utf8_buffer())


## 计算 PackedByteArray 的 SHA-256 小写十六进制值；HashingContext 失败时返回空串。
## [br]
## @api private
## [br]
func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(bytes)
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


## 将 Array 中的 Dictionary 项收集为强类型数组；非 Array 输入返回空数组。
## [br]
## @api private
## [br]
func _get_dictionary_array_value(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var values: Array = value
	for item_value: Variant in values:
		if item_value is Dictionary:
			var item: Dictionary = item_value
			result.append(item)
	return result


## 验证字符串长度精确匹配且内容只含小写十六进制字符。
## [br]
## @api private
## [br]
func _is_lower_hex(value: String, expected_length: int) -> bool:
	if value.length() != expected_length:
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 97 and code <= 102)
		):
			return false
	return true


## 为 manifest 序列化和摘要共享 DEBUG 编码配置，限制深度、集合、总节点及总字节，取消单字符串长度截断并保留字典键。
## [br]
## @api private
func _make_report_codec_options() -> Dictionary:
	return GFReportValueCodec.make_redaction_options(
		GFReportValueCodec.REDACTION_PROFILE_DEBUG,
		{
			"max_depth": 64,
			"max_string_length": -1,
			"max_collection_items": _DEFAULT_MAX_FRESHNESS_ENTRIES,
			"max_packed_length": _DEFAULT_MAX_FRESHNESS_ENTRIES,
			"max_total_nodes": _DEFAULT_MAX_FRESHNESS_ENTRIES * 16,
			"max_total_bytes": _DEFAULT_MAX_MANIFEST_BYTES,
			"encode_dictionary_keys": false,
		}
	)


## 已有文件需要覆盖且未显式允许非受管覆盖时，要求 manifest 可成功加载并带 GF owner；关闭覆盖时交由保存阶段决定跳过。
## [br]
## @api private
func _validate_existing_manifest_ownership(manifest_path: String, options: Dictionary) -> String:
	if not FileAccess.file_exists(manifest_path):
		return ""
	if not GFVariantData.get_option_bool(options, "overwrite_existing", true):
		return ""
	if GFVariantData.get_option_bool(options, "allow_unowned_overwrite", false):
		return ""
	var load_result: Dictionary = load_manifest(manifest_path)
	if (
		GFVariantData.get_option_bool(load_result, "success")
		and GFVariantData.get_option_string(
			GFVariantData.get_option_dictionary(load_result, "manifest"),
			_ARTIFACT_OWNER_FIELD
		) == _ARTIFACT_OWNER
	):
		return ""
	return "拒绝覆盖不属于 GF Config Pipeline 的已有 manifest：%s。若已人工确认所有权，请显式传入 allow_unowned_overwrite。" % manifest_path


## 使用失败状态和给定错误构造生成产物报告。
## [br]
## @api private
## [br]
func _make_failure_artifact_report(
	manifest_path: String,
	error_code: Error,
	message: String,
	options: Dictionary,
	source_id: String
) -> Dictionary:
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.make_report(
		manifest_path,
		_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED,
		error_code,
		message,
		{
			"dry_run": GFVariantData.get_option_bool(options, "dry_run", false),
			"generator_id": _ARTIFACT_OWNER,
			"source_id": source_id,
		}
	)


## 统一分隔符及边缘空白，按协议分离后小写协议并简化路径；只生成比较用文本，不确认路径权限或文件存在。
## [br]
## @api private
func _normalize_output_path(path: String) -> String:
	var normalized: String = path.replace("\\", "/").strip_edges()
	if normalized.contains("://"):
		var scheme: String = normalized.get_slice("://", 0).to_lower()
		var body: String = normalized.get_slice("://", 1).simplify_path()
		return "%s://%s" % [scheme, body]
	return normalized.simplify_path()



## 将 PackedStringArray 的元素按原顺序复制到普通 Array。
## [br]
## @api private
## [br]
func _packed_to_array(values: PackedStringArray) -> Array:
	var result: Array = []
	for value: String in values:
		result.append(value)
	return result
