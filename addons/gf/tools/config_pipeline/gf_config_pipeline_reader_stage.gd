## GFConfigPipelineReaderStage: Config Pipeline 的内置来源读取阶段。
##
## 只负责来源存在性、读取预算和原始载荷取得，不解析表布局或业务字段。
## 文本来源返回原文，XLSX 来源返回已完成预算检查的文件载荷描述。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 9.0.0
class_name GFConfigPipelineReaderStage
extends RefCounted


# --- 常量 ---

## Reader 阶段的稳定实现标识。
## [br]
## @api public
## [br]
## @since 9.0.0
const STAGE_ID: String = "gf.config.reader.builtin"

## Reader 阶段的实现版本；改变读取语义时递增。
## [br]
## @api public
## [br]
## @since 9.0.0
const IMPLEMENTATION_VERSION: int = 2

const _DEFAULT_MAX_SOURCE_FILE_BYTES: int = 64 * 1024 * 1024
const _DEFAULT_MAX_XLSX_FILE_BYTES: int = 64 * 1024 * 1024
const _SOURCE_RECEIPT_FORMAT: String = "gf.config_pipeline.source_receipt"
const _SOURCE_RECEIPT_FORMAT_VERSION: int = 1


# --- 公共方法 ---

## 读取来源的原始载荷，并在分配大载荷前执行大小预算检查。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param source: 单表来源声明。
## [br]
## @param options: 读取选项。
## [br]
## @schema options: Dictionary，可包含 max_source_file_bytes 和 max_xlsx_file_bytes；负值表示不限制。
## [br]
## @return: Reader 阶段结果。
## [br]
## @schema return: Dictionary，包含 success、phase、source_path、format、payload_kind、text、size_bytes、source_receipt、error_code、error_kind、error 和 context；source_receipt 绑定本次实际读取的字节数与 SHA-256。
func read_source(source: GFConfigPipelineTableSource, options: Dictionary = {}) -> Dictionary:
	if source == null:
		return _make_failure(&"", "", "invalid_table_source", ERR_INVALID_PARAMETER, "表来源声明为空。")
	var table_name: StringName = source.get_table_key()
	var source_path: String = source.source_path
	var resolved_format: StringName = source.get_resolved_format()
	if table_name == &"":
		return _make_failure(&"", source_path, "empty_table_name", ERR_INVALID_DATA, "无法确定配置表名。", resolved_format)
	if source_path.is_empty():
		return _make_failure(table_name, source_path, "missing_source_path", ERR_FILE_NOT_FOUND, "配置表来源路径为空。", resolved_format)
	if not _is_supported_format(resolved_format):
		return _make_failure(
			table_name,
			source_path,
			"unsupported_source_format",
			ERR_FILE_UNRECOGNIZED,
			"不支持的配置表来源格式：%s。" % String(resolved_format),
			resolved_format,
			{ "supported_formats": ["csv", "json", "config_file", "xlsx"] }
		)

	var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		return _make_failure(
			table_name,
			source_path,
			"source_read_failed",
			open_error,
			"读取配置表来源失败：%s。" % error_string(open_error),
			resolved_format,
			{ "error_code": open_error }
		)

	var source_size: int = file.get_length()
	var budget_key: String = "max_xlsx_file_bytes" if resolved_format == GFConfigPipelineTableSource.FORMAT_XLSX else "max_source_file_bytes"
	var default_budget: int = _DEFAULT_MAX_XLSX_FILE_BYTES if resolved_format == GFConfigPipelineTableSource.FORMAT_XLSX else _DEFAULT_MAX_SOURCE_FILE_BYTES
	var source_budget: int = GFVariantData.get_option_int(options, budget_key, default_budget)
	if source_budget >= 0 and source_size > source_budget:
		file.close()
		return _make_failure(
			table_name,
			source_path,
			"source_budget_exceeded",
			ERR_OUT_OF_MEMORY,
			"配置表来源超过 %s：%d > %d。" % [budget_key, source_size, source_budget],
			resolved_format,
			{
				"actual_value": source_size,
				"expected_value": source_budget,
				"budget_key": budget_key,
			}
		)

	var source_bytes: PackedByteArray = file.get_buffer(source_size)
	var read_error: Error = file.get_error()
	var final_source_size: int = file.get_length()
	file.close()
	if (
		read_error != OK
		or source_bytes.size() != source_size
		or final_source_size != source_size
	):
		return _make_failure(
			table_name,
			source_path,
			"source_read_failed",
			ERR_FILE_CORRUPT if read_error == OK else read_error,
			"读取配置表来源时文件发生变化或未完整读取。",
			resolved_format,
			{
				"error_code": read_error,
				"expected_size": source_size,
				"actual_size": source_bytes.size(),
				"final_size": final_source_size,
			}
		)
	var source_sha256: String = _sha256_bytes(source_bytes)
	if source_sha256.is_empty():
		return _make_failure(
			table_name,
			source_path,
			"source_digest_failed",
			ERR_CANT_CREATE,
			"无法为配置表来源创建编译收据。",
			resolved_format
		)
	var source_receipt: Dictionary = _make_source_receipt(
		table_name,
		source_path,
		resolved_format,
		source_bytes.size(),
		source_sha256
	)
	if resolved_format == GFConfigPipelineTableSource.FORMAT_XLSX:
		return _make_success(
			source_path,
			resolved_format,
			"file",
			"",
			source_size,
			source_receipt
		)
	return _make_success(
		source_path,
		resolved_format,
		"text",
		source_bytes.get_string_from_utf8(),
		source_size,
		source_receipt
	)


## 返回阶段实现的稳定描述，用于流水线诊断和编译指纹。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return: 阶段描述。
## [br]
## @schema return: Dictionary，包含 stage_id、implementation_version、implementation_dependencies、input_contract、output_contract 和 supported_formats。
func get_stage_descriptor() -> Dictionary:
	return {
		"stage_id": STAGE_ID,
		"implementation_version": IMPLEMENTATION_VERSION,
		"input_contract": "GFConfigPipelineTableSource@1",
		"output_contract": "gf.config_pipeline.reader_result@2",
		"implementation_dependencies": [
			"res://addons/gf/tools/config_pipeline/gf_config_pipeline_table_source.gd",
			"res://addons/gf/standard/foundation/variant/gf_variant_data.gd",
		],
		"supported_formats": ["csv", "json", "config_file", "xlsx"],
	}


# --- 私有/辅助方法 ---

func _is_supported_format(resolved_format: StringName) -> bool:
	return resolved_format == GFConfigPipelineTableSource.FORMAT_CSV \
		or resolved_format == GFConfigPipelineTableSource.FORMAT_JSON \
		or resolved_format == GFConfigPipelineTableSource.FORMAT_CONFIG_FILE \
		or resolved_format == GFConfigPipelineTableSource.FORMAT_XLSX


func _make_success(
	source_path: String,
	resolved_format: StringName,
	payload_kind: String,
	text: String,
	size_bytes: int,
	source_receipt: Dictionary
) -> Dictionary:
	return {
		"success": true,
		"phase": "reader",
		"source_path": source_path,
		"format": resolved_format,
		"payload_kind": payload_kind,
		"text": text,
		"size_bytes": size_bytes,
		"source_receipt": source_receipt.duplicate(true),
		"error_code": OK,
		"error_kind": "",
		"error": "",
		"context": {},
	}


func _make_source_receipt(
	table_name: StringName,
	source_path: String,
	resolved_format: StringName,
	size_bytes: int,
	sha256: String
) -> Dictionary:
	return {
		"format": _SOURCE_RECEIPT_FORMAT,
		"format_version": _SOURCE_RECEIPT_FORMAT_VERSION,
		"table_name": String(table_name),
		"source_path": source_path.replace("\\", "/").simplify_path(),
		"source_format": String(resolved_format),
		"size_bytes": size_bytes,
		"sha256": sha256.to_lower(),
	}


func _sha256_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(bytes) != OK:
		return ""
	return context.finish().hex_encode()


func _make_failure(
	table_name: StringName,
	source_path: String,
	error_kind: String,
	error_code: Error,
	message: String,
	resolved_format: StringName = &"",
	context: Dictionary = {}
) -> Dictionary:
	var failure_context: Dictionary = context.duplicate(true)
	failure_context["table_name"] = table_name
	failure_context["source"] = source_path
	return {
		"success": false,
		"phase": "reader",
		"source_path": source_path,
		"format": resolved_format,
		"payload_kind": "",
		"text": "",
		"size_bytes": 0,
		"source_receipt": {},
		"error_code": error_code,
		"error_kind": error_kind,
		"error": message,
		"context": failure_context,
	}
