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
const FORMAT_VERSION: int = 1

const _ARTIFACT_OWNER: String = "gf.tool.config_pipeline"
const _ARTIFACT_OWNER_FIELD: String = "artifact_owner"
const _DEFAULT_JSON_INDENT: String = "\t"
const _DEFAULT_MAX_MANIFEST_BYTES: int = 4 * 1024 * 1024
const _DEFAULT_MAX_FRESHNESS_FILE_BYTES: int = 64 * 1024 * 1024
const _DEFAULT_MAX_FRESHNESS_TOTAL_BYTES: int = 256 * 1024 * 1024
const _DEFAULT_MAX_FRESHNESS_ENTRIES: int = 4096
const _DIGEST_CHUNK_BYTES: int = 64 * 1024
const _COMPILER_CONTRACT_VERSION: int = 2
const _PLUGIN_CONFIG_PATH: String = "res://addons/gf/plugin.cfg"
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
	},
	{
		"id": GFConfigPipelineLayoutStage.STAGE_ID,
		"implementation_version": GFConfigPipelineLayoutStage.IMPLEMENTATION_VERSION,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_layout_stage.gd",
	},
	{
		"id": GFConfigPipelineValidationStage.STAGE_ID,
		"implementation_version": GFConfigPipelineValidationStage.IMPLEMENTATION_VERSION,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_validation_stage.gd",
	},
	{
		"id": GFConfigPipelineTargetStage.STAGE_ID,
		"implementation_version": GFConfigPipelineTargetStage.IMPLEMENTATION_VERSION,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_target_stage.gd",
	},
	{
		"id": GFConfigPipelineCommitStage.STAGE_ID,
		"implementation_version": GFConfigPipelineCommitStage.IMPLEMENTATION_VERSION,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_commit_stage.gd",
	},
	{
		"id": "artifact_manifest",
		"implementation_version": 1,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_artifact_manifest.gd",
	},
	{
		"id": "pipeline_runner",
		"implementation_version": 1,
		"path": "res://addons/gf/tools/config_pipeline/gf_config_pipeline_runner.gd",
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
const _PIPELINE_STAGE_IDS: PackedStringArray = [
	GFConfigPipelineReaderStage.STAGE_ID,
	GFConfigPipelineLayoutStage.STAGE_ID,
	GFConfigPipelineValidationStage.STAGE_ID,
	GFConfigPipelineTargetStage.STAGE_ID,
	GFConfigPipelineCommitStage.STAGE_ID,
]
const _GENERATED_ARTIFACT_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")


# --- 私有变量 ---

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
## @schema run_result: Dictionary，可包含 success、operation、profile_id、output_path、save_result、access_result、report 和 error。
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
	var source_entries: Array[Dictionary] = _make_source_entries(profile, budget_state)
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
## @param manifest_path: manifest JSON 输出路径。
## [br]
## @param manifest: make_manifest() 返回的字典。
## [br]
## @schema manifest: Dictionary，包含 format、format_version、artifact_owner、profile_digest、input_digest、output_digest、options_digest、compiler_digest、compiler_fingerprint、profile_entries、source_entries、output_entries 和 scan_report。
## [br]
## @param options: 保存选项。
## [br]
## @schema options: Dictionary，可包含 dry_run、overwrite_existing、allow_unowned_overwrite、indent、sort_keys、allow_parent_output_path、allow_gf_source_output 和 allow_absolute_output_path；allow_unowned_overwrite 仅用于调用方已明确确认现有文件所有权的迁移场景。
## [br]
## @return: 保存报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、artifact_report、written、changed 和 dry_run。
func save_manifest(manifest_path: String, manifest: Dictionary, options: Dictionary = {}) -> Dictionary:
	if manifest_path.strip_edges().is_empty():
		return _make_save_result(false, manifest_path, ERR_INVALID_PARAMETER, "manifest 路径为空。", {})

	var path_error: String = _validate_manifest_path_policy(manifest_path, options)
	if not path_error.is_empty():
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
## @schema stage_descriptors: Array[Dictionary]，每项包含 stage_id、implementation_version 和 implementation_path。
func configure_compiler_stages(
	stage_descriptors: Array[Dictionary]
) -> void:
	_compiler_stage_descriptors.clear()
	for descriptor: Dictionary in stage_descriptors:
		_compiler_stage_descriptors.append(descriptor.duplicate(true))


# --- 私有/辅助方法 ---

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
		stage_entries.append({
			"id": GFVariantData.get_option_string(definition, "id"),
			"implementation_version": GFVariantData.get_option_int(definition, "implementation_version"),
			"path": stage_path,
			"exists": GFVariantData.get_option_bool(file_report, "exists"),
			"size_bytes": GFVariantData.get_option_int(file_report, "size_bytes"),
			"sha256": GFVariantData.get_option_string(file_report, "sha256"),
			"error": GFVariantData.get_option_string(file_report, "error"),
		})
		if not GFVariantData.get_option_bool(budget_state, "success", true):
			break
		if not GFVariantData.get_option_bool(file_report, "exists") or not GFVariantData.get_option_string(file_report, "error").is_empty():
			_set_digest_budget_failure(
				budget_state,
				"freshness_compiler_stage_unavailable",
				"配置编译阶段实现不可用：%s。" % stage_path
			)
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

		var file_report: Dictionary = _make_file_digest_report(source.source_path, budget_state)
		entries.append({
			"valid": true,
			"table_name": String(source.get_table_key()),
			"source_path": source.source_path,
			"source_format": String(source.get_resolved_format()),
			"exists": GFVariantData.get_option_bool(file_report, "exists"),
			"size_bytes": GFVariantData.get_option_int(file_report, "size_bytes"),
			"sha256": GFVariantData.get_option_string(file_report, "sha256"),
			"error": GFVariantData.get_option_string(file_report, "error"),
		})
	return entries


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


func _make_output_entry(kind: String, output_path: String, budget_state: Dictionary) -> Dictionary:
	var file_report: Dictionary = _make_file_digest_report(output_path, budget_state)
	return {
		"kind": kind,
		"path": output_path,
		"exists": GFVariantData.get_option_bool(file_report, "exists"),
		"size_bytes": GFVariantData.get_option_int(file_report, "size_bytes"),
		"sha256": GFVariantData.get_option_string(file_report, "sha256"),
	}


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


func _make_report_summary(report: Dictionary) -> Dictionary:
	if report.is_empty():
		return {}
	return {
		"ok": GFVariantData.get_option_bool(report, "ok"),
		"error_count": GFVariantData.get_option_int(report, "error_count"),
		"warning_count": GFVariantData.get_option_int(report, "warning_count"),
		"issue_count": GFVariantData.get_option_array(report, "issues").size(),
	}


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


func _make_digest_file_entry(path: String, file_report: Dictionary) -> Dictionary:
	return {
		"path": path,
		"exists": GFVariantData.get_option_bool(file_report, "exists"),
		"size_bytes": GFVariantData.get_option_int(file_report, "size_bytes"),
		"sha256": GFVariantData.get_option_string(file_report, "sha256"),
		"error": GFVariantData.get_option_string(file_report, "error"),
	}


func _should_scan_resource_dependencies(resource_path: String) -> bool:
	var extension: String = resource_path.get_extension().to_lower()
	return extension == "tres" or extension == "res" or extension == "tscn" or extension == "scn"


func _extract_dependency_resource_path(dependency_entry: String) -> String:
	for raw_part: String in dependency_entry.split("::", false):
		var candidate: String = raw_part.strip_edges().replace("\\", "/")
		if candidate.begins_with("res://") or candidate.begins_with("user://"):
			return candidate
	return ""


func _read_framework_version() -> String:
	var config: ConfigFile = ConfigFile.new()
	var load_result: Error = config.load(_PLUGIN_CONFIG_PATH)
	if load_result != OK:
		return ""
	return GFVariantData.to_text(config.get_value("plugin", "version", "")).strip_edges()


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


func _set_digest_budget_failure(budget_state: Dictionary, error_code: String, message: String) -> void:
	if not GFVariantData.get_option_bool(budget_state, "success", true):
		return
	budget_state["success"] = false
	budget_state["error_code"] = error_code
	budget_state["error"] = message


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


func _normalize_compiler_fingerprint(fingerprint: Dictionary) -> Dictionary:
	var engine_version: Dictionary = GFVariantData.get_option_dictionary(fingerprint, "godot_version")
	var stage_entries: Array[Dictionary] = []
	for entry_value: Variant in GFVariantData.get_option_array(fingerprint, "stage_entries"):
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		stage_entries.append({
			"id": GFVariantData.get_option_string(entry, "id"),
			"implementation_version": GFVariantData.get_option_int(entry, "implementation_version"),
			"path": GFVariantData.get_option_string(entry, "path"),
			"exists": GFVariantData.get_option_bool(entry, "exists"),
			"size_bytes": GFVariantData.get_option_int(entry, "size_bytes"),
			"sha256": GFVariantData.get_option_string(entry, "sha256"),
			"error": GFVariantData.get_option_string(entry, "error"),
		})
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


func _sha256_variant(value: Variant) -> String:
	var text: String = GFReportValueCodec.stringify_json_compatible(
		value,
		"",
		true,
		_make_report_codec_options()
	)
	return _sha256_bytes(text.to_utf8_buffer())


func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(bytes)
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


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


func _validate_manifest_path_policy(manifest_path: String, options: Dictionary) -> String:
	var raw_path: String = manifest_path.replace("\\", "/").strip_edges()
	if raw_path.is_empty():
		return "manifest 路径为空。"
	if _has_unsupported_output_scheme(raw_path):
		return "manifest 路径使用了不支持的 URI scheme：%s。" % manifest_path
	if _path_has_parent_segment(raw_path) and not GFVariantData.get_option_bool(options, "allow_parent_output_path", false):
		return "manifest 路径不能包含父级越界片段：%s。" % manifest_path
	if _is_filesystem_absolute_path(raw_path) and not GFVariantData.get_option_bool(options, "allow_absolute_output_path", false):
		return "manifest 路径不能是绝对文件系统路径：%s。" % manifest_path
	var normalized_path: String = _normalize_output_path(raw_path)
	if _is_gf_source_output_path(normalized_path) and not GFVariantData.get_option_bool(options, "allow_gf_source_output", false):
		return "manifest 路径不能写入 GF 框架源码目录：%s。" % manifest_path
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


func _packed_to_array(values: PackedStringArray) -> Array:
	var result: Array = []
	for value: String in values:
		result.append(value)
	return result
