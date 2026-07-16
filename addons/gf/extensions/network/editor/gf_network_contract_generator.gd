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

## 默认生成脚本输出目录。
## [br]
## @api public
const DEFAULT_OUTPUT_DIR: String = "res://gf/generated/network"
const _GF_VALIDATION_REPORT_DICTIONARY = preload("res://addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd")
const _GENERATED_ARTIFACT_REPORT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")


# --- 公共方法 ---

## 生成单个契约访问器脚本。
## [br]
## @api public
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
## @param options: 可选项，支持 class_name、dry_run、scan_filesystem 和 metadata。
## [br]
## @return 生成报告。
## [br]
## @schema options: Dictionary，可包含 class_name、dry_run、scan_filesystem 和 metadata。
## [br]
## @schema return: Dictionary，GFValidationReportDictionary 格式，包含 ok、generated_count、attempted_count、skipped_count、artifact_summary、generated、issues、issue_count 和 next_actions。
func generate_many(
	contract_paths: PackedStringArray,
	output_dir: String = DEFAULT_OUTPUT_DIR,
	overwrite_existing: bool = true,
	options: Dictionary = {}
) -> Dictionary:
	var generated: Array[Dictionary] = []
	var artifact_reports: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	var save_options: Dictionary = _merge_generation_save_options(options, overwrite_existing)
	for contract_path: String in contract_paths:
		var contract: GFNetworkContract = _variant_to_contract(load(contract_path))
		if contract == null:
			issues.append({
				"severity": "error",
				"kind": "invalid_contract_resource",
				"path": contract_path,
				"message": "Contract resource is not a GFNetworkContract resource.",
			})
			continue

		var class_name_value: String = _resolve_class_name(contract, options)
		var output_path: String = output_dir.path_join("%s.gd" % class_name_value.to_snake_case())
		var artifact_report: Dictionary = generate_with_report(contract, output_path, save_options)
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
			"parameter_name": _make_unique_name(_to_snake_identifier(String(field.field_name), "field"), used_parameters),
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
	builder.line("var issues: Array[Dictionary] = []")
	builder.line("var severity: String = GFVariantData.get_option_string(options, \"severity\", \"error\")")
	builder.line("var require_contract_id: bool = GFVariantData.get_option_bool(options, \"require_contract_id\", true)")
	builder.line("var require_schema_digest: bool = GFVariantData.get_option_bool(options, \"require_schema_digest\", false)")
	builder.line("var peer_contract_id: StringName = GFVariantData.get_option_string_name(peer_version, \"contract_id\")")
	builder.blank()
	builder.line("if require_contract_id and CONTRACT_ID != &\"\":")
	builder.indent()
	builder.line("if peer_contract_id == &\"\":")
	builder.indent()
	builder.line("issues.append(_make_version_issue(severity, \"contract_id_missing\", \"Peer network contract version is missing contract_id.\", {")
	builder.indent()
	builder.line("\"expected_value\": CONTRACT_ID,")
	builder.line("\"actual_value\": peer_contract_id,")
	builder.dedent()
	builder.line("}))")
	builder.dedent()
	builder.line("elif peer_contract_id != CONTRACT_ID:")
	builder.indent()
	builder.line("issues.append(_make_version_issue(severity, \"contract_id_mismatch\", \"Peer network contract_id does not match.\", {")
	builder.indent()
	builder.line("\"expected_value\": CONTRACT_ID,")
	builder.line("\"actual_value\": peer_contract_id,")
	builder.dedent()
	builder.line("}))")
	builder.dedent()
	builder.dedent()
	builder.blank()
	builder.line("if not peer_version.has(\"version_major\"):")
	builder.indent()
	builder.line("issues.append(_make_version_issue(severity, \"contract_version_major_missing\", \"Peer network contract version is missing version_major.\", {")
	builder.indent()
	builder.line("\"expected_value\": CONTRACT_VERSION_MAJOR,")
	builder.line("\"actual_value\": null,")
	builder.dedent()
	builder.line("}))")
	builder.dedent()
	builder.line("else:")
	builder.indent()
	builder.line("var peer_major: int = GFVariantData.get_option_int(peer_version, \"version_major\", -1)")
	builder.line("if peer_major != CONTRACT_VERSION_MAJOR:")
	builder.indent()
	builder.line("issues.append(_make_version_issue(severity, \"contract_version_major_mismatch\", \"Peer network contract major version does not match.\", {")
	builder.indent()
	builder.line("\"expected_value\": CONTRACT_VERSION_MAJOR,")
	builder.line("\"actual_value\": peer_major,")
	builder.dedent()
	builder.line("}))")
	builder.dedent()
	builder.dedent()
	builder.blank()
	builder.line("if require_schema_digest:")
	builder.indent()
	builder.line("var peer_digest: String = GFVariantData.get_option_string(peer_version, \"schema_digest\").strip_edges()")
	builder.line("if peer_digest.is_empty():")
	builder.indent()
	builder.line("issues.append(_make_version_issue(severity, \"contract_schema_digest_missing\", \"Peer network contract version is missing schema_digest.\", {")
	builder.indent()
	builder.line("\"expected_value\": CONTRACT_SCHEMA_DIGEST,")
	builder.line("\"actual_value\": peer_digest,")
	builder.dedent()
	builder.line("}))")
	builder.dedent()
	builder.line("elif CONTRACT_SCHEMA_DIGEST.is_empty():")
	builder.indent()
	builder.line("issues.append(_make_version_issue(severity, \"contract_schema_digest_unavailable\", \"Local network contract schema_digest is unavailable.\", {")
	builder.indent()
	builder.line("\"expected_value\": \"non-empty schema_digest\",")
	builder.line("\"actual_value\": CONTRACT_SCHEMA_DIGEST,")
	builder.dedent()
	builder.line("}))")
	builder.dedent()
	builder.line("elif peer_digest != CONTRACT_SCHEMA_DIGEST:")
	builder.indent()
	builder.line("issues.append(_make_version_issue(severity, \"contract_schema_digest_mismatch\", \"Peer network contract schema_digest does not match.\", {")
	builder.indent()
	builder.line("\"expected_value\": CONTRACT_SCHEMA_DIGEST,")
	builder.line("\"actual_value\": peer_digest,")
	builder.dedent()
	builder.line("}))")
	builder.dedent()
	builder.dedent()
	builder.blank()
	builder.line("return GFValidationReportDictionary.finalize_report({")
	builder.indent()
	builder.line("\"subject\": \"Network contract version\",")
	builder.line("\"local_version\": get_contract_version(),")
	builder.line("\"peer_version\": peer_version.duplicate(true),")
	builder.line("\"issues\": issues,")
	builder.dedent()
	builder.line("}, \"Network contract version\", {")
	builder.indent()
	builder.line("\"include_issue_count\": true,")
	builder.line("\"next_actions\": _get_version_next_actions(),")
	builder.line("\"fallback_action\": \"Review the first network contract version mismatch.\",")
	builder.line("\"no_action\": \"Network contract version is compatible.\",")
	builder.dedent()
	builder.line("})")
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
	var field_suffix: String = _to_snake_identifier(String(field.field_name), "field")
	var return_type: String = _get_gdscript_type(field)
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
	builder.line("static func _make_version_issue(severity: String, kind: String, message: String, fields: Dictionary) -> Dictionary:")
	builder.indent()
	builder.line("var issue: Dictionary = {")
	builder.indent()
	builder.line("\"severity\": severity,")
	builder.line("\"kind\": kind,")
	builder.line("\"contract_id\": CONTRACT_ID,")
	builder.line("\"message\": message,")
	builder.dedent()
	builder.line("}")
	builder.line("var _merge_result: Dictionary = GFVariantData.merge_dictionary(issue, fields, true)")
	builder.line("return issue")
	builder.dedent()
	builder.blank(2)

	builder.line("static func _get_version_next_actions() -> Dictionary:")
	builder.indent()
	builder.line("return {")
	builder.indent()
	builder.line("\"contract_id_missing\": \"Send contract_id with the peer network contract version or disable require_contract_id.\",")
	builder.line("\"contract_id_mismatch\": \"Use the same network contract resource on both peers, or connect to the matching protocol endpoint.\",")
	builder.line("\"contract_version_major_missing\": \"Send version_major with the peer network contract version.\",")
	builder.line("\"contract_version_major_mismatch\": \"Update one side to the same compatible network contract major version.\",")
	builder.line("\"contract_schema_digest_missing\": \"Send schema_digest or disable require_schema_digest for this preflight.\",")
	builder.line("\"contract_schema_digest_unavailable\": \"Ensure the local network contract schema only uses deterministic Variant values.\",")
	builder.line("\"contract_schema_digest_mismatch\": \"Regenerate or sync the network contract schema before exchanging messages.\",")
	builder.dedent()
	builder.line("}")
	builder.dedent()
	builder.blank(2)

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
	if _should_omit_null_optional_parameter(field):
		return "Variant"
	return _get_gdscript_type(field)


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
		_:
			return ""


func _float_literal(value: float) -> String:
	var text: String = str(value)
	return text if text.contains(".") else text + ".0"


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


func _get_generation_next_actions() -> Dictionary:
	return {
		"invalid_contract_resource": "Check that the configured path points to a GFNetworkContract resource.",
		"generate_failed": "Review the output path, overwrite setting, and filesystem error.",
	}


func _starts_with_digit(value: String) -> bool:
	return not value.is_empty() and value.unicode_at(0) >= 48 and value.unicode_at(0) <= 57
