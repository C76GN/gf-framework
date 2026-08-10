@tool

## GFNetworkContractGenerator: 根据 GFNetworkContract 生成强类型消息辅助脚本。
##
## 生成结果保持为 GDScript 轻量封装，围绕 GFNetworkMessage / GFNetworkUtility
## 提供构造、发送、匹配和 payload 读取函数，不绑定任何具体业务协议。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
class_name GFNetworkContractGenerator
extends RefCounted


# --- 常量 ---

const _GF_PROJECT_ARTIFACT_PATHS_SCRIPT = preload("res://addons/gf/kernel/core/gf_project_artifact_paths.gd")

## 默认生成脚本输出目录。
## [br]
## @api public
## [br]
## @since 9.0.0
const DEFAULT_OUTPUT_DIR: String = _GF_PROJECT_ARTIFACT_PATHS_SCRIPT.NETWORK_OUTPUT_ROOT
const _GF_VALIDATION_REPORT_DICTIONARY = preload("res://addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd")
const _GENERATED_ARTIFACT_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")
const _GF_PATH_TOOLS_SCRIPT = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _NETWORK_TRANSPORT_VALUE_VALIDATOR_SCRIPT = preload("res://addons/gf/extensions/network/runtime/gf_network_transport_value_validator.gd")
const _GDSCRIPT_RESERVED_IDENTIFIERS: Dictionary = {
	"and": true,
	"as": true,
	"assert": true,
	"await": true,
	"break": true,
	"breakpoint": true,
	"class": true,
	"class_name": true,
	"const": true,
	"continue": true,
	"elif": true,
	"else": true,
	"enum": true,
	"extends": true,
	"false": true,
	"for": true,
	"func": true,
	"if": true,
	"in": true,
	"is": true,
	"match": true,
	"namespace": true,
	"not": true,
	"null": true,
	"or": true,
	"pass": true,
	"preload": true,
	"return": true,
	"self": true,
	"signal": true,
	"static": true,
	"super": true,
	"trait": true,
	"true": true,
	"var": true,
	"void": true,
	"when": true,
	"while": true,
}
const _DEFAULT_MAX_CONTRACTS: int = 256
const _ABSOLUTE_MAX_CONTRACTS: int = 4096
const _DEFAULT_MAX_MESSAGES_PER_CONTRACT: int = 256
const _ABSOLUTE_MAX_MESSAGES_PER_CONTRACT: int = 2048
const _DEFAULT_MAX_FIELDS_PER_MESSAGE: int = 512
const _ABSOLUTE_MAX_FIELDS_PER_MESSAGE: int = 4096
const _DEFAULT_MAX_IDENTIFIER_LENGTH: int = 256
const _ABSOLUTE_MAX_IDENTIFIER_LENGTH: int = 1024
const _DEFAULT_MAX_SOURCE_BYTES: int = 4 * 1024 * 1024
const _ABSOLUTE_MAX_SOURCE_BYTES: int = 64 * 1024 * 1024
const _DEFAULT_MAX_TOTAL_SOURCE_BYTES: int = 32 * 1024 * 1024
const _ABSOLUTE_MAX_TOTAL_SOURCE_BYTES: int = 256 * 1024 * 1024
const _MAX_CONTRACT_PATH_LENGTH: int = 4096


# --- 公共方法 ---

## 生成单个契约访问器脚本。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param contract: 网络契约资源。
## [br]
## @param output_path: 输出脚本路径；为空时按 contract_id 推导。
## [br]
## @param overwrite_existing: 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。
## [br]
## @param options: 可选项，支持 class_name。
## [br]
## @return Godot 错误码。
## [br]
## @schema options: Dictionary，支持 class_name。
func generate(
	contract: GFNetworkContract,
	output_path: String = "",
	overwrite_existing: bool = true,
	options: Dictionary = {}
) -> Error:
	var report: Dictionary = generate_with_report(contract, output_path, _merge_generation_save_options(options, overwrite_existing))
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(report)


## 生成单个契约访问器脚本并返回生成产物报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param contract: 网络契约资源。
## [br]
## @param output_path: 输出脚本路径；为空时按 contract_id 推导。
## [br]
## @param options: 可选项，支持 class_name、overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @schema options: Dictionary，可包含 class_name、overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @return: 生成产物报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
func generate_with_report(
	contract: GFNetworkContract,
	output_path: String = "",
	options: Dictionary = {}
) -> Dictionary:
	if contract == null:
		return _GENERATED_ARTIFACT_REPORT_SCRIPT.make_report(
			output_path,
			_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED,
			ERR_INVALID_PARAMETER,
			"Network contract is null.",
			_make_artifact_report_options(options)
		)
	var validation: Dictionary = contract.validate_contract()
	if not GFVariantData.get_option_bool(validation, "ok", false):
		return _GENERATED_ARTIFACT_REPORT_SCRIPT.make_report(
			output_path,
			_GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED,
			ERR_INVALID_DATA,
			"Network contract validation failed.",
			_make_artifact_report_options(options, contract)
		)

	var resolved_output_path: String = output_path
	if resolved_output_path.is_empty():
		var class_name_value: String = _resolve_class_name(contract, options)
		resolved_output_path = DEFAULT_OUTPUT_DIR.path_join("%s.gd" % class_name_value.to_snake_case())
	var source: String = build_source(contract, options)
	return save_source_with_report(resolved_output_path, source, _make_artifact_report_options(options, contract))


## 批量生成多个契约访问器脚本。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param contract_paths: 契约资源路径列表。
## [br]
## @param output_dir: 输出目录。
## [br]
## @param overwrite_existing: 为 false 时目标已存在会跳过。
## [br]
## @param options: 可选项，支持 class_name、dry_run、scan_filesystem、metadata、allowed_roots 和生成预算。
## [br]
## @return 生成报告。
## [br]
## @schema options: Dictionary，可包含 class_name、dry_run、scan_filesystem、metadata、allowed_roots、max_contracts、max_messages_per_contract、max_fields_per_message、max_identifier_length、max_source_bytes 和 max_total_source_bytes；预算必须为正整数并受框架硬上限约束。
## [br]
## @schema return: Dictionary，GFValidationReportDictionary 格式，包含 ok、generated_count、attempted_count、skipped_count、artifact_summary、generated、issues、issue_count、plan_fingerprint 和 next_actions。
func generate_many(
	contract_paths: PackedStringArray,
	output_dir: String = DEFAULT_OUTPUT_DIR,
	overwrite_existing: bool = true,
	options: Dictionary = {}
) -> Dictionary:
	var plan_result: Dictionary = _build_many_plan(contract_paths, output_dir, options)
	var generated: Array[Dictionary] = []
	var artifact_reports: Array[Dictionary] = []
	var issues: Array[Dictionary] = _get_record_array(plan_result, "issues")
	var plan: Array = _get_record_array(plan_result, "entries")
	var normalized_output_dir: String = GFVariantData.get_option_string(plan_result, "output_dir")
	var save_options: Dictionary = _make_batch_save_options(
		options,
		overwrite_existing,
		normalized_output_dir
	)
	if issues.is_empty():
		for plan_entry: Dictionary in plan:
			var contract_path: String = _get_record_string(plan_entry, "contract_path")
			var output_path: String = _get_record_string(plan_entry, "output_path")
			var contract: GFNetworkContract = _variant_to_contract(
				GFVariantData.get_option_value(plan_entry, "contract")
			)
			var source: String = _get_record_string(plan_entry, "source")
			var artifact_report: Dictionary = save_source_with_report(
				output_path,
				source,
				_make_artifact_report_options(save_options, contract)
			)
			artifact_reports.append(artifact_report)
			var artifact_status: StringName = GFVariantData.get_option_string_name(artifact_report, "status", &"")
			var error: Error = _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(artifact_report)
			generated.append({
				"contract_path": contract_path,
				"output_path": output_path,
				"status": String(artifact_status),
				"written": GFVariantData.get_option_bool(artifact_report, "written"),
				"changed": GFVariantData.get_option_bool(artifact_report, "changed"),
				"error": error,
				"error_name": error_string(error),
				"artifact_report": artifact_report,
			})
			if artifact_status == _GENERATED_ARTIFACT_REPORT_SCRIPT.STATUS_FAILED:
				issues.append({
					"severity": "error",
					"kind": "generate_failed",
					"path": contract_path,
					"message": _get_artifact_error_message(artifact_report),
				})

	var artifact_summary: Dictionary = _GENERATED_ARTIFACT_REPORT_SCRIPT.summarize_reports(
		artifact_reports,
		"Network contract generation"
	)
	var report: Dictionary = {
		"ok": issues.is_empty(),
		"generated_count": GFVariantData.get_option_int(artifact_summary, "written_count"),
		"attempted_count": contract_paths.size(),
		"skipped_count": GFVariantData.get_option_int(artifact_summary, "skipped_count"),
		"artifact_summary": artifact_summary,
		"artifact_reports": artifact_reports,
		"generated": generated,
		"issues": issues,
		"plan_fingerprint": GFVariantData.get_option_string(plan_result, "plan_fingerprint"),
	}
	return _GF_VALIDATION_REPORT_DICTIONARY.finalize_report(report, "Network contract generation", {
		"include_issue_count": true,
		"next_actions": _get_generation_next_actions(),
		"fallback_action": "Review the first network contract generation issue.",
		"no_action": "Network contract generation completed.",
	})


## 构建契约访问器源码。测试或项目工具可直接调用该方法。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param contract: 网络契约资源。
## [br]
## @param options: 可选项，支持 class_name。
## [br]
## @return GDScript 源码。
## [br]
## @schema options: Dictionary，支持 class_name。
func build_source(contract: GFNetworkContract, options: Dictionary = {}) -> String:
	var builder: GFSourceBuilder = GFSourceBuilder.new()
	var class_name_value: String = _resolve_class_name(contract, options)
	var message_records: Array[Dictionary] = _build_message_records(contract)

	builder.doc("%s: 自动生成的 GF Network 契约访问器。" % class_name_value)
	builder.doc()
	builder.doc("该文件由 GFNetworkContractGenerator 生成，可以提交到版本库；请不要手动编辑。")
	builder.line("class_name %s" % class_name_value)
	builder.line("extends RefCounted")
	builder.blank(2)
	_append_constants(builder, contract, message_records)
	builder.section("公共方法")
	_append_version_methods(builder)
	for record: Dictionary in message_records:
		_append_message_methods(builder, record)
	_append_private_helpers(builder)
	return builder.build()


## 保存生成源码到指定路径。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param output_path: 输出脚本路径。
## [br]
## @param source: 源码文本。
## [br]
## @param overwrite_existing: 为 false 时目标已存在会返回 ERR_ALREADY_EXISTS。
## [br]
## @return Godot 错误码。
func save_source(output_path: String, source: String, overwrite_existing: bool = true) -> Error:
	var report: Dictionary = save_source_with_report(output_path, source, {
		"overwrite_existing": overwrite_existing,
	})
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(report)


## 保存生成源码到指定路径并返回生成产物报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param output_path: 输出脚本路径。
## [br]
## @param source: 源码文本。
## [br]
## @param options: 保存选项，支持 overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @schema options: Dictionary，可包含 overwrite_existing、dry_run、scan_filesystem 和 metadata。
## [br]
## @return: 生成产物报告。
## [br]
## @schema return: Dictionary，包含 success、path、status、error_code、error、written、changed、dry_run、size_bytes 和 metadata。
func save_source_with_report(output_path: String, source: String, options: Dictionary = {}) -> Dictionary:
	var save_options: Dictionary = options.duplicate(true)
	save_options["label"] = "GFNetworkContractGenerator"
	return _GENERATED_ARTIFACT_REPORT_SCRIPT.save_text(output_path, source, save_options)


# --- 私有/辅助方法 ---

func _build_many_plan(
	contract_paths: PackedStringArray,
	output_dir: String,
	options: Dictionary
) -> Dictionary:
	var entries: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	var used_output_paths: Dictionary = {}
	var normalized_output_dir: String = _GF_PATH_TOOLS_SCRIPT.normalize_root_path(output_dir)
	var budgets: Dictionary = _resolve_generation_budgets(options)
	if not GFVariantData.get_option_bool(budgets, "ok"):
		issues.append(GFVariantData.get_option_dictionary(budgets, "issue"))
		return _make_many_plan_result(entries, issues, normalized_output_dir)
	var max_contracts: int = GFVariantData.get_option_int(budgets, "max_contracts")
	if contract_paths.size() > max_contracts:
		issues.append(_make_generation_budget_issue(
			"contract_count",
			max_contracts,
			contract_paths.size()
		))
		return _make_many_plan_result(entries, issues, normalized_output_dir)
	if normalized_output_dir.is_empty():
		issues.append({
			"severity": "error",
			"kind": "invalid_generation_output_root",
			"path": output_dir,
			"message": "Network contract output_dir must be a non-empty resource root.",
		})
		return _make_many_plan_result(entries, issues, normalized_output_dir)
	var total_source_bytes: int = 0
	for contract_path_value: String in contract_paths:
		var contract_path: String = _GF_PATH_TOOLS_SCRIPT.normalize_resource_path(
			contract_path_value
		)
		if contract_path.length() > _MAX_CONTRACT_PATH_LENGTH:
			issues.append(_make_generation_budget_issue(
				"contract_path_length",
				_MAX_CONTRACT_PATH_LENGTH,
				contract_path.length(),
				contract_path.left(128)
			))
			continue
		var contract: GFNetworkContract = _variant_to_contract(load(contract_path))
		if contract == null:
			issues.append({
				"severity": "error",
				"kind": "invalid_contract_resource",
				"path": contract_path,
				"resource_path": contract_path,
				"message": "Contract resource is not a GFNetworkContract resource.",
			})
			continue
		var contract_budget_issue: Dictionary = _get_contract_generation_budget_issue(
			contract,
			contract_path,
			budgets,
			options
		)
		if not contract_budget_issue.is_empty():
			issues.append(contract_budget_issue)
			continue
		var validation: Dictionary = contract.validate_contract()
		if not GFVariantData.get_option_bool(validation, "ok"):
			issues.append({
				"severity": "error",
				"kind": "invalid_contract_definition",
				"path": contract_path,
				"resource_path": contract_path,
				"message": "Network contract validation failed before generation planning.",
			})
			continue
		var class_name_value: String = _resolve_class_name(contract, options)
		var output_path: String = _GF_PATH_TOOLS_SCRIPT.normalize_resource_path(
			normalized_output_dir.path_join("%s.gd" % class_name_value.to_snake_case())
		)
		var output_identity: String = output_path.to_lower()
		if used_output_paths.has(output_identity):
			issues.append({
				"severity": "error",
				"kind": "duplicate_output_path",
				"path": contract_path,
				"resource_path": contract_path,
				"output_path": output_path,
				"first_contract_path": GFVariantData.get_option_string(
					GFVariantData.as_dictionary(used_output_paths[output_identity]),
					"contract_path"
				),
				"message": "Multiple network contracts map to the same canonical output path.",
			})
			continue
		var source: String = build_source(contract, options)
		var source_bytes: int = source.to_utf8_buffer().size()
		var max_source_bytes: int = GFVariantData.get_option_int(budgets, "max_source_bytes")
		if source_bytes > max_source_bytes:
			issues.append(_make_generation_budget_issue(
				"source_bytes",
				max_source_bytes,
				source_bytes,
				contract_path
			))
			continue
		total_source_bytes += source_bytes
		var max_total_source_bytes: int = GFVariantData.get_option_int(
			budgets,
			"max_total_source_bytes"
		)
		if total_source_bytes > max_total_source_bytes:
			issues.append(_make_generation_budget_issue(
				"total_source_bytes",
				max_total_source_bytes,
				total_source_bytes,
				contract_path
			))
			continue
		var entry: Dictionary = {
			"contract_path": contract_path,
			"contract": contract,
			"class_name": class_name_value,
			"output_path": output_path,
			"source": source,
			"content_sha256": source.sha256_text(),
		}
		used_output_paths[output_identity] = entry
		entries.append(entry)
	return _make_many_plan_result(entries, issues, normalized_output_dir)


func _make_many_plan_result(
	entries: Array[Dictionary],
	issues: Array[Dictionary],
	output_dir: String
) -> Dictionary:
	return {
		"ok": issues.is_empty(),
		"output_dir": output_dir,
		"entries": entries,
		"issues": issues,
		"plan_fingerprint": _make_plan_fingerprint(entries),
	}


func _resolve_generation_budgets(options: Dictionary) -> Dictionary:
	var specifications: Array[Dictionary] = [
		{
			"key": "max_contracts",
			"default": _DEFAULT_MAX_CONTRACTS,
			"absolute": _ABSOLUTE_MAX_CONTRACTS,
		},
		{
			"key": "max_messages_per_contract",
			"default": _DEFAULT_MAX_MESSAGES_PER_CONTRACT,
			"absolute": _ABSOLUTE_MAX_MESSAGES_PER_CONTRACT,
		},
		{
			"key": "max_fields_per_message",
			"default": _DEFAULT_MAX_FIELDS_PER_MESSAGE,
			"absolute": _ABSOLUTE_MAX_FIELDS_PER_MESSAGE,
		},
		{
			"key": "max_identifier_length",
			"default": _DEFAULT_MAX_IDENTIFIER_LENGTH,
			"absolute": _ABSOLUTE_MAX_IDENTIFIER_LENGTH,
		},
		{
			"key": "max_source_bytes",
			"default": _DEFAULT_MAX_SOURCE_BYTES,
			"absolute": _ABSOLUTE_MAX_SOURCE_BYTES,
		},
		{
			"key": "max_total_source_bytes",
			"default": _DEFAULT_MAX_TOTAL_SOURCE_BYTES,
			"absolute": _ABSOLUTE_MAX_TOTAL_SOURCE_BYTES,
		},
	]
	var budgets: Dictionary = { "ok": true }
	for specification: Dictionary in specifications:
		var key: String = GFVariantData.get_option_string(specification, "key")
		var default_value: int = GFVariantData.get_option_int(specification, "default")
		var absolute_value: int = GFVariantData.get_option_int(specification, "absolute")
		var has_value: bool = options.has(key) or options.has(StringName(key))
		var raw_value: Variant = GFVariantData.get_option_value(options, key, default_value)
		var budget_value: int = raw_value if raw_value is int else -1
		if has_value and budget_value <= 0:
			return {
				"ok": false,
				"issue": {
					"severity": "error",
					"kind": "invalid_generation_options",
					"path": key,
					"message": "%s must be a positive integer." % key,
				},
			}
		budgets[key] = mini(budget_value, absolute_value)
	return budgets


func _get_contract_generation_budget_issue(
	contract: GFNetworkContract,
	contract_path: String,
	budgets: Dictionary,
	options: Dictionary
) -> Dictionary:
	var max_identifier_length: int = GFVariantData.get_option_int(
		budgets,
		"max_identifier_length"
	)
	var configured_class_name: String = GFVariantData.get_option_string(
		options,
		"class_name"
	).strip_edges()
	if configured_class_name.length() > max_identifier_length:
		return _make_generation_budget_issue(
			"class_name_length",
			max_identifier_length,
			configured_class_name.length(),
			contract_path
		)
	if String(contract.contract_id).length() > max_identifier_length:
		return _make_generation_budget_issue(
			"contract_id_length",
			max_identifier_length,
			String(contract.contract_id).length(),
			contract_path
		)
	var max_messages: int = GFVariantData.get_option_int(
		budgets,
		"max_messages_per_contract"
	)
	if contract.messages.size() > max_messages:
		return _make_generation_budget_issue(
			"message_count",
			max_messages,
			contract.messages.size(),
			contract_path
		)
	var max_fields: int = GFVariantData.get_option_int(budgets, "max_fields_per_message")
	for message_contract: GFNetworkContractMessage in contract.messages:
		if message_contract == null:
			continue
		if String(message_contract.message_type).length() > max_identifier_length:
			return _make_generation_budget_issue(
				"message_type_length",
				max_identifier_length,
				String(message_contract.message_type).length(),
				contract_path
			)
		if message_contract.fields.size() > max_fields:
			return _make_generation_budget_issue(
				"field_count",
				max_fields,
				message_contract.fields.size(),
				contract_path
			)
		for field: GFNetworkContractField in message_contract.fields:
			if field != null and String(field.field_name).length() > max_identifier_length:
				return _make_generation_budget_issue(
					"field_name_length",
					max_identifier_length,
					String(field.field_name).length(),
					contract_path
				)
	return {}


func _make_generation_budget_issue(
	budget_name: String,
	expected_value: int,
	actual_value: int,
	path: String = ""
) -> Dictionary:
	return {
		"severity": "error",
		"kind": "generation_budget_exceeded",
		"path": path,
		"budget": budget_name,
		"expected_value": expected_value,
		"actual_value": actual_value,
		"message": "Network contract generation exceeded the %s budget." % budget_name,
	}


func _make_plan_fingerprint(entries: Array[Dictionary]) -> String:
	var records: Array[Dictionary] = []
	for entry: Dictionary in entries:
		records.append({
			"contract_path": _get_record_string(entry, "contract_path"),
			"output_path": _get_record_string(entry, "output_path"),
			"content_sha256": _get_record_string(entry, "content_sha256"),
		})
	return JSON.stringify(records).sha256_text()


func _make_batch_save_options(
	options: Dictionary,
	overwrite_existing: bool,
	output_dir: String
) -> Dictionary:
	var save_options: Dictionary = _merge_generation_save_options(options, overwrite_existing)
	if not save_options.has("allowed_roots") and not save_options.has(&"allowed_roots"):
		save_options["allowed_roots"] = PackedStringArray([output_dir])
	return save_options

func _merge_generation_save_options(options: Dictionary, overwrite_existing: bool) -> Dictionary:
	var save_options: Dictionary = options.duplicate(true)
	save_options["overwrite_existing"] = overwrite_existing
	return save_options


func _make_artifact_report_options(options: Dictionary, contract: GFNetworkContract = null) -> Dictionary:
	var report_options: Dictionary = options.duplicate(true)
	if not report_options.has("generator_id"):
		report_options["generator_id"] = "GFNetworkContractGenerator"
	if not report_options.has("source_id") and contract != null:
		var source_id: String = String(contract.contract_id)
		if source_id.is_empty():
			source_id = contract.resource_path
		report_options["source_id"] = source_id
	return report_options


func _get_artifact_error_message(report: Dictionary) -> String:
	var message: String = GFVariantData.get_option_string(report, "error")
	if not message.is_empty():
		return message
	var error_code: Error = _GENERATED_ARTIFACT_REPORT_SCRIPT.get_error_code(report)
	return error_string(error_code)


func _resolve_class_name(contract: GFNetworkContract, options: Dictionary) -> String:
	var configured: String = GFVariantData.get_option_string(options, "class_name").strip_edges()
	if not configured.is_empty():
		return _to_pascal_identifier(configured, "GFGeneratedNetworkContract")

	var base_name: String = String(contract.contract_id).strip_edges()
	if base_name.is_empty():
		base_name = contract.resource_path.get_file().get_basename()
	if base_name.is_empty():
		base_name = "generated"
	return _to_pascal_identifier("%s_network_messages" % base_name, "GFGeneratedNetworkContract")


func _build_message_records(contract: GFNetworkContract) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if contract == null:
		return records

	var used_suffixes: Dictionary = {}
	var used_constants: Dictionary = {}
	for message_contract: GFNetworkContractMessage in contract.messages:
		if message_contract == null:
			continue

		var suffix: String = _make_unique_name(
			_to_snake_identifier(String(message_contract.message_type), "message"),
			used_suffixes
		)
		var message_constant: String = _make_unique_name(
			"MESSAGE_%s" % _to_constant_name(String(message_contract.message_type), "MESSAGE"),
			used_constants
		)
		var channel_constant: String = _make_unique_name(
			"CHANNEL_%s" % _to_constant_name(String(message_contract.message_type), "MESSAGE"),
			used_constants
		)
		records.append({
			"message": message_contract,
			"suffix": suffix,
			"message_constant": message_constant,
			"channel_constant": channel_constant,
			"field_records": _build_field_records(message_contract, used_constants),
		})
	return records


func _build_field_records(
	message_contract: GFNetworkContractMessage,
	used_constants: Dictionary
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var used_parameters: Dictionary = {}
	var used_accessor_suffixes: Dictionary = {}
	used_parameters["options"] = true
	used_parameters["network"] = true
	used_parameters["peer_id"] = true

	var message_constant_part: String = _to_constant_name(String(message_contract.message_type), "MESSAGE")
	for field: GFNetworkContractField in _ordered_fields(message_contract.fields):
		if field == null or field.field_name == &"":
			continue

		var field_constant: String = _make_unique_name(
			"FIELD_%s_%s" % [
				message_constant_part,
				_to_constant_name(String(field.field_name), "FIELD"),
			],
			used_constants
		)
		records.append({
			"field": field,
			"field_constant": field_constant,
			"parameter_name": _allocate_identifier(String(field.field_name), "field", used_parameters, true),
			"accessor_suffix": _allocate_identifier(String(field.field_name), "field", used_accessor_suffixes),
		})
	return records


func _ordered_fields(fields: Array[GFNetworkContractField]) -> Array[GFNetworkContractField]:
	var required_fields: Array[GFNetworkContractField] = []
	var optional_fields: Array[GFNetworkContractField] = []
	for field: GFNetworkContractField in fields:
		if field == null:
			continue
		if field.required:
			required_fields.append(field)
		else:
			optional_fields.append(field)
	required_fields.append_array(optional_fields)
	return required_fields


func _append_constants(
	builder: GFSourceBuilder,
	contract: GFNetworkContract,
	message_records: Array[Dictionary]
) -> void:
	builder.section("常量")
	var contract_version: Dictionary = contract.get_contract_version()
	builder.line("const _GF_NETWORK_CONTRACT_VERSION_VALIDATOR_SCRIPT = preload(")
	builder.indent()
	builder.line("\"res://addons/gf/extensions/network/contracts/gf_network_contract_version_validator.gd\"")
	builder.dedent()
	builder.line(")")
	builder.blank()
	builder.line("const CONTRACT_ID: StringName = &\"%s\"" % String(contract.contract_id).c_escape())
	builder.line("const CONTRACT_VERSION_MAJOR: int = %d" % contract.contract_version_major)
	builder.line("const CONTRACT_VERSION_MINOR: int = %d" % contract.contract_version_minor)
	builder.line("const CONTRACT_SCHEMA_DESCRIPTOR_VERSION: int = %d" % GFVariantData.get_option_int(contract_version, "schema_descriptor_version", 1))
	builder.line("const CONTRACT_SCHEMA_DIGEST: String = \"%s\"" % contract.get_schema_digest().c_escape())
	builder.blank()

	if message_records.is_empty():
		builder.line("const _EMPTY_CONTRACT: bool = true")
		builder.blank(2)
		return

	for record: Dictionary in message_records:
		var message_contract: GFNetworkContractMessage = _get_record_message(record)
		if message_contract == null:
			continue
		builder.line("const %s: StringName = &\"%s\"" % [
			_get_record_string(record, "message_constant"),
			String(message_contract.message_type).c_escape(),
		])
		builder.line("const %s: StringName = &\"%s\"" % [
			_get_record_string(record, "channel_constant"),
			String(message_contract.channel_id).c_escape(),
		])
		for field_record: Dictionary in _get_record_array(record, "field_records"):
			var field: GFNetworkContractField = _get_record_field(field_record)
			if field == null:
				continue
			builder.line("const %s: StringName = &\"%s\"" % [
				_get_record_string(field_record, "field_constant"),
				String(field.field_name).c_escape(),
			])
		builder.blank()
	builder.blank()


func _append_version_methods(builder: GFSourceBuilder) -> void:
	builder.doc("获取生成脚本携带的契约版本信息。")
	builder.line("static func get_contract_version() -> Dictionary:")
	builder.indent()
	builder.line("return {")
	builder.indent()
	builder.line("\"contract_id\": CONTRACT_ID,")
	builder.line("\"version_major\": CONTRACT_VERSION_MAJOR,")
	builder.line("\"version_minor\": CONTRACT_VERSION_MINOR,")
	builder.line("\"schema_descriptor_version\": CONTRACT_SCHEMA_DESCRIPTOR_VERSION,")
	builder.line("\"schema_digest\": CONTRACT_SCHEMA_DIGEST,")
	builder.dedent()
	builder.line("}")
	builder.dedent()
	builder.blank(2)

	builder.doc("校验对端声明的契约版本。")
	builder.line("static func validate_peer_contract_version(peer_version: Dictionary, options: Dictionary = {}) -> Dictionary:")
	builder.indent()
	builder.line("return _GF_NETWORK_CONTRACT_VERSION_VALIDATOR_SCRIPT.validate(")
	builder.indent()
	builder.line("get_contract_version(),")
	builder.line("peer_version,")
	builder.line("options")
	builder.dedent()
	builder.line(")")
	builder.dedent()
	builder.blank(2)


func _append_message_methods(builder: GFSourceBuilder, record: Dictionary) -> void:
	var message_contract: GFNetworkContractMessage = _get_record_message(record)
	if message_contract == null:
		return
	var suffix: String = _get_record_string(record, "suffix", "message")
	var field_records: Array = _get_record_array(record, "field_records")
	var make_params: PackedStringArray = _build_function_parameters(field_records, true)
	var send_params: PackedStringArray = _build_function_parameters(field_records, true)
	var _peer_id_inserted: int = send_params.insert(0, "peer_id: int")
	var _network_inserted: int = send_params.insert(0, "network: GFNetworkUtility")

	builder.doc("创建 %s 消息。" % String(message_contract.message_type))
	builder.line("static func make_%s(%s) -> GFNetworkMessage:" % [suffix, ", ".join(make_params)])
	builder.indent()
	_append_payload_builder(builder, field_records)
	builder.line("return GFNetworkMessage.new(")
	builder.indent()
	builder.line("%s," % _get_record_string(record, "message_constant"))
	builder.line("payload,")
	builder.line("GFVariantData.get_option_int(options, \"sequence\"),")
	builder.line("GFVariantData.get_option_int(options, \"tick\"),")
	builder.line("GFVariantData.get_option_int(options, \"sender_id\", -1),")
	builder.line("GFVariantData.get_option_string_name(options, \"channel_id\", %s)" % _get_record_string(record, "channel_constant"))
	builder.dedent()
	builder.line(")")
	builder.dedent()
	builder.blank(2)

	builder.doc("发送 %s 消息。" % String(message_contract.message_type))
	builder.line("static func send_%s(%s) -> Error:" % [suffix, ", ".join(send_params)])
	builder.indent()
	builder.line("var message: GFNetworkMessage = make_%s(%s)" % [suffix, _build_make_call_arguments(field_records)])
	builder.line("var channel_id: StringName = GFVariantData.get_option_string_name(options, \"channel_id\", %s)" % _get_record_string(record, "channel_constant"))
	builder.line("return _send_contract_message(network, peer_id, message, channel_id, options)")
	builder.dedent()
	builder.blank(2)

	builder.doc("检查消息是否为 %s。" % String(message_contract.message_type))
	builder.line("static func is_%s(message: GFNetworkMessage) -> bool:" % suffix)
	builder.indent()
	builder.line("return message != null and message.message_type == %s" % _get_record_string(record, "message_constant"))
	builder.dedent()
	builder.blank(2)

	builder.doc("读取 %s 消息 payload 副本。" % String(message_contract.message_type))
	builder.line("static func get_%s_payload(message: GFNetworkMessage) -> Dictionary:" % suffix)
	builder.indent()
	builder.line("return message.payload.duplicate(true) if message != null else {}")
	builder.dedent()
	builder.blank(2)

	for field_record: Dictionary in field_records:
		_append_field_getter(builder, suffix, field_record)


func _append_payload_builder(builder: GFSourceBuilder, field_records: Array) -> void:
	builder.line("var payload: Dictionary = {}")
	for field_record: Dictionary in field_records:
		var field: GFNetworkContractField = _get_record_field(field_record)
		if field == null:
			continue
		var field_constant: String = _get_record_string(field_record, "field_constant")
		var parameter_name: String = _get_record_string(field_record, "parameter_name")
		if _should_omit_null_optional_parameter(field):
			builder.line("if %s != null or GFVariantData.get_option_bool(options, \"include_null_optional_fields\"):" % parameter_name)
			builder.indent()
			builder.line("payload[%s] = %s" % [field_constant, parameter_name])
			builder.dedent()
			continue

		builder.line("payload[%s] = %s" % [
			_get_record_string(field_record, "field_constant"),
			_get_record_string(field_record, "parameter_name"),
		])


func _append_field_getter(builder: GFSourceBuilder, suffix: String, field_record: Dictionary) -> void:
	var field: GFNetworkContractField = _get_record_field(field_record)
	if field == null:
		return
	var field_suffix: String = _get_record_string(field_record, "accessor_suffix", "field")
	var return_type: String = _get_accessor_return_type(field)
	var default_literal: String = _get_default_literal(field)
	builder.doc("读取 %s 字段。" % String(field.field_name))
	builder.line("static func get_%s_%s(message: GFNetworkMessage, default_value: %s = %s) -> %s:" % [
		suffix,
		field_suffix,
		return_type,
		default_literal,
		return_type,
	])
	builder.indent()
	builder.line("var value: Variant = _get_payload_value(message, %s, default_value)" % _get_record_string(field_record, "field_constant"))
	if field.allow_null:
		builder.line("if value == null:")
		builder.indent()
		builder.line("return null")
		builder.dedent()
	match field.value_type:
		GFNetworkContractField.ValueType.VARIANT:
			builder.line("return value")
		GFNetworkContractField.ValueType.BOOL:
			builder.line("return GFVariantData.to_bool(value, default_value)")
		GFNetworkContractField.ValueType.INT:
			builder.line("return GFVariantData.to_int(value, default_value)")
		GFNetworkContractField.ValueType.FLOAT:
			builder.line("return GFVariantData.to_float(value, default_value)")
		GFNetworkContractField.ValueType.STRING:
			builder.line("return GFVariantData.to_text(value, default_value)")
		GFNetworkContractField.ValueType.STRING_NAME:
			builder.line("return GFVariantData.to_string_name(value, default_value)")
		GFNetworkContractField.ValueType.VECTOR2:
			builder.line("return GFVariantData.to_vector2(value, default_value)")
		GFNetworkContractField.ValueType.VECTOR3:
			builder.line("return GFVariantData.to_vector3(value, default_value)")
		GFNetworkContractField.ValueType.VECTOR2I:
			builder.line("return _get_vector2i_value(value, default_value)")
		GFNetworkContractField.ValueType.VECTOR3I:
			builder.line("return _get_vector3i_value(value, default_value)")
		GFNetworkContractField.ValueType.COLOR:
			builder.line("return _get_color_value(value, default_value)")
		GFNetworkContractField.ValueType.DICTIONARY:
			builder.line("return GFVariantData.to_dictionary(value, default_value)")
		GFNetworkContractField.ValueType.ARRAY:
			builder.line("return GFVariantData.to_array(value, default_value)")
		GFNetworkContractField.ValueType.NODE_PATH:
			builder.line("return _get_node_path_value(value, default_value)")
		GFNetworkContractField.ValueType.OBJECT:
			builder.line("return _get_object_value(value, default_value)")
		_:
			builder.line("return value if value is %s else default_value" % return_type)
	builder.dedent()
	builder.blank(2)


func _append_private_helpers(builder: GFSourceBuilder) -> void:
	builder.section("私有/辅助方法")
	builder.line("static func _get_payload_value(message: GFNetworkMessage, field_name: StringName, default_value: Variant = null) -> Variant:")
	builder.indent()
	builder.line("if message == null:")
	builder.indent()
	builder.line("return default_value")
	builder.dedent()
	builder.line("return GFVariantData.get_option_value(message.payload, field_name, default_value)")
	builder.dedent()
	builder.blank(2)

	builder.line("static func _get_vector2i_value(value: Variant, default_value: Vector2i = Vector2i.ZERO) -> Vector2i:")
	builder.indent()
	builder.line("if value is Vector2i:")
	builder.indent()
	builder.line("var vector: Vector2i = value")
	builder.line("return vector")
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)

	builder.line("static func _get_vector3i_value(value: Variant, default_value: Vector3i = Vector3i.ZERO) -> Vector3i:")
	builder.indent()
	builder.line("if value is Vector3i:")
	builder.indent()
	builder.line("var vector: Vector3i = value")
	builder.line("return vector")
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)

	builder.line("static func _get_color_value(value: Variant, default_value: Color = Color.WHITE) -> Color:")
	builder.indent()
	builder.line("if value is Color:")
	builder.indent()
	builder.line("var color: Color = value")
	builder.line("return color")
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)

	builder.line("static func _get_node_path_value(value: Variant, default_value: NodePath = NodePath(\"\")) -> NodePath:")
	builder.indent()
	builder.line("if value is NodePath:")
	builder.indent()
	builder.line("var node_path: NodePath = value")
	builder.line("return node_path")
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)

	builder.line("static func _get_object_value(value: Variant, default_value: Object = null) -> Object:")
	builder.indent()
	builder.line("if value is Object:")
	builder.indent()
	builder.line("var object: Object = value")
	builder.line("return object")
	builder.dedent()
	builder.line("return default_value")
	builder.dedent()
	builder.blank(2)

	builder.line("static func _send_contract_message(network: GFNetworkUtility, peer_id: int, message: GFNetworkMessage, channel_id: StringName, options: Dictionary = {}) -> Error:")
	builder.indent()
	builder.line("if network == null:")
	builder.indent()
	builder.line("return ERR_UNCONFIGURED")
	builder.dedent()
	builder.line("var send_options: Dictionary = _get_send_options(options)")
	builder.line("if channel_id != &\"\" and network.get_channel(channel_id) != null:")
	builder.indent()
	builder.line("return network.send_message_on_channel(peer_id, message, channel_id, send_options)")
	builder.dedent()
	builder.line("return network.send_message(peer_id, message, send_options)")
	builder.dedent()
	builder.blank(2)

	builder.line("static func _get_send_options(options: Dictionary) -> Dictionary:")
	builder.indent()
	builder.line("return GFVariantData.get_option_dictionary(options, \"send_options\")")
	builder.dedent()


func _build_function_parameters(field_records: Array, include_options: bool) -> PackedStringArray:
	var params: PackedStringArray = PackedStringArray()
	for field_record: Dictionary in field_records:
		var field: GFNetworkContractField = _get_record_field(field_record)
		if field == null:
			continue
		var parameter: String = "%s: %s" % [
			_get_record_string(field_record, "parameter_name"),
			_get_parameter_type(field),
		]
		if not field.required:
			parameter += " = %s" % _get_parameter_default_literal(field)
		_append_packed_string(params, parameter)
	if include_options:
		_append_packed_string(params, "options: Dictionary = {}")
	return params


func _build_make_call_arguments(field_records: Array) -> String:
	var args: PackedStringArray = PackedStringArray()
	for field_record: Dictionary in field_records:
		_append_packed_string(args, _get_record_string(field_record, "parameter_name"))
	_append_packed_string(args, "options")
	return ", ".join(args)


func _get_record_message(record: Dictionary) -> GFNetworkContractMessage:
	return _variant_to_message(GFVariantData.get_option_value(record, "message"))


func _get_record_field(record: Dictionary) -> GFNetworkContractField:
	return _variant_to_field(GFVariantData.get_option_value(record, "field"))


func _get_record_array(record: Dictionary, field_name: String) -> Array:
	return GFVariantData.get_option_array(record, field_name)


func _get_record_string(record: Dictionary, field_name: String, default_value: String = "") -> String:
	return GFVariantData.get_option_string(record, field_name, default_value)


func _variant_to_contract(value: Variant) -> GFNetworkContract:
	if value is GFNetworkContract:
		var contract: GFNetworkContract = value
		return contract
	return null


func _variant_to_message(value: Variant) -> GFNetworkContractMessage:
	if value is GFNetworkContractMessage:
		var message_contract: GFNetworkContractMessage = value
		return message_contract
	return null


func _variant_to_field(value: Variant) -> GFNetworkContractField:
	if value is GFNetworkContractField:
		var field: GFNetworkContractField = value
		return field
	return null


func _coerce_literal_int(value: Variant, default_value: int = 0) -> int:
	if value == null:
		return default_value
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return roundi(float_value)
	if value is bool:
		var bool_value: bool = value
		return 1 if bool_value else 0
	var text: String = GFVariantData.to_text(value).strip_edges()
	return text.to_int() if text.is_valid_int() else default_value


func _coerce_literal_float(value: Variant, default_value: float = 0.0) -> float:
	if value == null:
		return default_value
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	if value is bool:
		var bool_value: bool = value
		return 1.0 if bool_value else 0.0
	var text: String = GFVariantData.to_text(value).strip_edges()
	return text.to_float() if text.is_valid_float() else default_value


func _variant_to_vector2(value: Variant) -> Vector2:
	if value is Vector2:
		var vector: Vector2 = value
		return vector
	return Vector2.ZERO


func _variant_to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		var vector: Vector3 = value
		return vector
	return Vector3.ZERO


func _variant_to_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		var vector: Vector2i = value
		return vector
	return Vector2i.ZERO


func _variant_to_vector3i(value: Variant) -> Vector3i:
	if value is Vector3i:
		var vector: Vector3i = value
		return vector
	return Vector3i.ZERO


func _variant_to_color(value: Variant) -> Color:
	if value is Color:
		var color: Color = value
		return color
	return Color.WHITE


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var _added: bool = target.append(value)


func _get_gdscript_type(field: GFNetworkContractField) -> String:
	match field.value_type:
		GFNetworkContractField.ValueType.BOOL:
			return "bool"
		GFNetworkContractField.ValueType.INT:
			return "int"
		GFNetworkContractField.ValueType.FLOAT:
			return "float"
		GFNetworkContractField.ValueType.STRING:
			return "String"
		GFNetworkContractField.ValueType.STRING_NAME:
			return "StringName"
		GFNetworkContractField.ValueType.VECTOR2:
			return "Vector2"
		GFNetworkContractField.ValueType.VECTOR3:
			return "Vector3"
		GFNetworkContractField.ValueType.VECTOR2I:
			return "Vector2i"
		GFNetworkContractField.ValueType.VECTOR3I:
			return "Vector3i"
		GFNetworkContractField.ValueType.COLOR:
			return "Color"
		GFNetworkContractField.ValueType.DICTIONARY:
			return "Dictionary"
		GFNetworkContractField.ValueType.ARRAY:
			return "Array"
		GFNetworkContractField.ValueType.NODE_PATH:
			return "NodePath"
		GFNetworkContractField.ValueType.OBJECT:
			return "Object"
		_:
			return "Variant"


func _get_parameter_type(field: GFNetworkContractField) -> String:
	if field.allow_null or _should_omit_null_optional_parameter(field):
		return "Variant"
	return _get_gdscript_type(field)


func _get_accessor_return_type(field: GFNetworkContractField) -> String:
	return "Variant" if field.allow_null else _get_gdscript_type(field)


func _get_parameter_default_literal(field: GFNetworkContractField) -> String:
	if _should_omit_null_optional_parameter(field):
		return "null"
	return _get_default_literal(field)


func _should_omit_null_optional_parameter(field: GFNetworkContractField) -> bool:
	return field != null and not field.required and field.default_value == null


func _get_default_literal(field: GFNetworkContractField) -> String:
	if field.default_value != null:
		var literal: String = _variant_literal(field.default_value)
		if not literal.is_empty():
			return literal

	match field.value_type:
		GFNetworkContractField.ValueType.BOOL:
			return "false"
		GFNetworkContractField.ValueType.INT:
			return "0"
		GFNetworkContractField.ValueType.FLOAT:
			return "0.0"
		GFNetworkContractField.ValueType.STRING:
			return "\"\""
		GFNetworkContractField.ValueType.STRING_NAME:
			return "&\"\""
		GFNetworkContractField.ValueType.VECTOR2:
			return "Vector2.ZERO"
		GFNetworkContractField.ValueType.VECTOR3:
			return "Vector3.ZERO"
		GFNetworkContractField.ValueType.VECTOR2I:
			return "Vector2i.ZERO"
		GFNetworkContractField.ValueType.VECTOR3I:
			return "Vector3i.ZERO"
		GFNetworkContractField.ValueType.COLOR:
			return "Color.WHITE"
		GFNetworkContractField.ValueType.DICTIONARY:
			return "{}"
		GFNetworkContractField.ValueType.ARRAY:
			return "[]"
		GFNetworkContractField.ValueType.NODE_PATH:
			return "NodePath(\"\")"
		GFNetworkContractField.ValueType.OBJECT:
			return "null"
		_:
			return "null"


func _variant_literal(value: Variant) -> String:
	var transport_report: Dictionary = _NETWORK_TRANSPORT_VALUE_VALIDATOR_SCRIPT.validate(value)
	if not GFVariantData.get_option_bool(transport_report, "ok"):
		return ""
	return _variant_literal_unchecked(value)


func _variant_literal_unchecked(value: Variant) -> String:
	if value == null:
		return "null"
	match typeof(value):
		TYPE_BOOL:
			return "true" if GFVariantData.to_bool(value) else "false"
		TYPE_INT:
			return str(_coerce_literal_int(value))
		TYPE_FLOAT:
			var text: String = str(_coerce_literal_float(value))
			return text if text.contains(".") else text + ".0"
		TYPE_STRING:
			return "\"%s\"" % GFVariantData.to_text(value).c_escape()
		TYPE_STRING_NAME:
			return "&\"%s\"" % GFVariantData.to_text(value).c_escape()
		TYPE_VECTOR2:
			var vector2: Vector2 = _variant_to_vector2(value)
			return "Vector2(%s, %s)" % [_float_literal(vector2.x), _float_literal(vector2.y)]
		TYPE_VECTOR3:
			var vector3: Vector3 = _variant_to_vector3(value)
			return "Vector3(%s, %s, %s)" % [_float_literal(vector3.x), _float_literal(vector3.y), _float_literal(vector3.z)]
		TYPE_VECTOR2I:
			var vector2i: Vector2i = _variant_to_vector2i(value)
			return "Vector2i(%d, %d)" % [vector2i.x, vector2i.y]
		TYPE_VECTOR3I:
			var vector3i: Vector3i = _variant_to_vector3i(value)
			return "Vector3i(%d, %d, %d)" % [vector3i.x, vector3i.y, vector3i.z]
		TYPE_COLOR:
			var color: Color = _variant_to_color(value)
			return "Color(%s, %s, %s, %s)" % [
				_float_literal(color.r),
				_float_literal(color.g),
				_float_literal(color.b),
				_float_literal(color.a),
			]
		TYPE_NODE_PATH:
			return "NodePath(\"%s\")" % GFVariantData.to_text(value).c_escape()
		TYPE_DICTIONARY:
			return _dictionary_literal(GFVariantData.as_dictionary(value))
		TYPE_ARRAY:
			return _array_literal(GFVariantData.as_array(value))
		_:
			return var_to_str(value)


func _dictionary_literal(value: Dictionary) -> String:
	var entries: Array[Dictionary] = []
	for key: Variant in value:
		var key_literal: String = _variant_literal_unchecked(key)
		var value_literal: String = _variant_literal_unchecked(value[key])
		if key_literal.is_empty() or value_literal.is_empty():
			return ""
		entries.append({
			"key": key_literal,
			"value": value_literal,
		})
	entries.sort_custom(func(first: Dictionary, second: Dictionary) -> bool:
		return GFVariantData.get_option_string(first, "key") < GFVariantData.get_option_string(second, "key")
	)
	var parts: PackedStringArray = PackedStringArray()
	for entry: Dictionary in entries:
		_append_packed_string(parts, "%s: %s" % [
			GFVariantData.get_option_string(entry, "key"),
			GFVariantData.get_option_string(entry, "value"),
		])
	return "{%s}" % ", ".join(parts)


func _array_literal(value: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for item: Variant in value:
		var item_literal: String = _variant_literal_unchecked(item)
		if item_literal.is_empty():
			return ""
		_append_packed_string(parts, item_literal)
	return "[%s]" % ", ".join(parts)


func _float_literal(value: float) -> String:
	var text: String = str(value)
	return text if text.contains(".") or text.contains("e") else text + ".0"


func _to_pascal_identifier(value: String, fallback: String) -> String:
	var base: String = _to_snake_identifier(value, fallback).to_pascal_case()
	if base.is_empty():
		base = fallback
	if _starts_with_digit(base):
		base = "%s%s" % [fallback, base]
	return base


func _to_snake_identifier(value: String, fallback: String) -> String:
	var snake: String = value.to_snake_case().to_lower()
	var result: String = ""
	var previous_was_separator: bool = false
	for index: int in range(snake.length()):
		var code: int = snake.unicode_at(index)
		var valid: bool = (
			(code >= 97 and code <= 122)
			or (code >= 48 and code <= 57)
			or code == 95
		)
		if valid:
			result += snake.substr(index, 1)
			previous_was_separator = code == 95
		elif not previous_was_separator:
			result += "_"
			previous_was_separator = true

	result = result.strip_edges().trim_prefix("_").trim_suffix("_")
	if result.is_empty():
		result = fallback.to_snake_case().to_lower()
	if _starts_with_digit(result):
		result = "%s_%s" % [fallback.to_snake_case().to_lower(), result]
	return result


func _to_constant_name(value: String, fallback: String) -> String:
	var constant_name: String = _to_snake_identifier(value, fallback).to_upper()
	return constant_name if not constant_name.is_empty() else fallback


func _make_unique_name(base_name: String, used_names: Dictionary) -> String:
	var candidate: String = base_name
	var index: int = 2
	while used_names.has(candidate):
		candidate = "%s_%d" % [base_name, index]
		index += 1
	used_names[candidate] = true
	return candidate


func _allocate_identifier(
	value: String,
	fallback: String,
	used_names: Dictionary,
	avoid_reserved: bool = false
) -> String:
	var base_name: String = _to_snake_identifier(value, fallback)
	if avoid_reserved and _GDSCRIPT_RESERVED_IDENTIFIERS.has(base_name):
		base_name = "%s_%s" % [fallback.to_snake_case().to_lower(), base_name]
	return _make_unique_name(base_name, used_names)


func _get_generation_next_actions() -> Dictionary:
	return {
		"invalid_contract_resource": "Check that the configured path points to a GFNetworkContract resource.",
		"invalid_contract_definition": "Fix every contract definition error before generating the batch.",
		"duplicate_output_path": "Use unique contract IDs and omit a shared class_name override for multi-contract batches.",
		"generation_budget_exceeded": "Reduce the batch, schema size, identifier length, or generated source size before retrying.",
		"invalid_generation_options": "Use positive integer generation budgets; caller budgets are clamped to framework hard caps.",
		"invalid_generation_output_root": "Use a non-empty res:// or user:// output directory.",
		"generate_failed": "Review the output path, overwrite setting, and filesystem error.",
	}


func _starts_with_digit(value: String) -> bool:
	return not value.is_empty() and value.unicode_at(0) >= 48 and value.unicode_at(0) <= 57
