## GFPlatformContractMethodDescriptor: 平台桥接方法契约。
##
## 描述单个 provider-neutral 方法的请求/结果 schema、能力前置条件、载荷预算、
## 并发上限与取消语义。具体 SDK 错误码和项目业务规则不得写入该描述符。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since unreleased
class_name GFPlatformContractMethodDescriptor
extends Resource


# --- 导出变量 ---

## 方法稳定标识。
## [br]
## @api public
## [br]
## @since unreleased
@export var method_id: StringName = &""

## 可选请求 Dictionary schema。
## [br]
## @api public
## [br]
## @since unreleased
@export var request_schema: GFDictionarySchema = null

## 可选成功结果 Dictionary schema。为空时允许任意结果值。
## [br]
## @api public
## [br]
## @since unreleased
@export var result_schema: GFDictionarySchema = null

## 调用该方法前 adapter 必须声明的全部能力。
## [br]
## @api public
## [br]
## @since unreleased
@export var required_capability_ids: PackedStringArray = PackedStringArray()

## 请求 JSON-compatible 编码后的最大字节数；0 表示不额外限制。
## [br]
## @api public
## [br]
## @since unreleased
@export var max_request_bytes: int = 0

## 成功结果 JSON-compatible 编码后的最大字节数；0 表示不额外限制。
## [br]
## @api public
## [br]
## @since unreleased
@export var max_result_bytes: int = 0

## 同一 adapter 上该方法允许的最大并发请求数；0 表示不额外限制。
## [br]
## @api public
## [br]
## @since unreleased
@export var max_concurrent_requests: int = 0

## 底层 provider 是否支持主动取消。
## [br]
## @api public
## [br]
## @since unreleased
@export var supports_cancellation: bool = true

## 请求或结果中必须在日志、诊断和支持报告中脱敏的字段名。
## [br]
## @api public
## [br]
## @since unreleased
@export var sensitive_fields: PackedStringArray = PackedStringArray()

## Adapter 作者定义的非业务元数据。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @schema metadata: Dictionary adapter-authoring metadata.
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置方法契约。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param p_method_id: 方法稳定标识。
## [br]
## @param options: 可包含 request_schema、result_schema、required_capability_ids、max_request_bytes、max_result_bytes、max_concurrent_requests、supports_cancellation、sensitive_fields 和 metadata。
## [br]
## @schema options: Dictionary platform contract method options.
## [br]
## @return 当前描述符。
func configure(
	p_method_id: StringName,
	options: Dictionary = {}
) -> GFPlatformContractMethodDescriptor:
	method_id = StringName(String(p_method_id).strip_edges())
	request_schema = _get_dictionary_schema(options, "request_schema")
	result_schema = _get_dictionary_schema(options, "result_schema")
	required_capability_ids = _normalize_string_set(
		GFVariantData.get_option_packed_string_array(options, "required_capability_ids")
	)
	max_request_bytes = maxi(GFVariantData.get_option_int(options, "max_request_bytes"), 0)
	max_result_bytes = maxi(GFVariantData.get_option_int(options, "max_result_bytes"), 0)
	max_concurrent_requests = maxi(
		GFVariantData.get_option_int(options, "max_concurrent_requests"),
		0
	)
	supports_cancellation = GFVariantData.get_option_bool(
		options,
		"supports_cancellation",
		true
	)
	sensitive_fields = _normalize_string_set(
		GFVariantData.get_option_packed_string_array(options, "sensitive_fields")
	)
	metadata = GFVariantData.get_option_dictionary(options, "metadata")
	return self


## 校验描述符定义。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 标准校验报告。
func validate_definition() -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new(
		"Platform contract method %s" % String(method_id)
	)
	if method_id == &"":
		var _method_issue: RefCounted = report.add_error(
			&"missing_method_id",
			"Platform contract method ID is required."
		)
	for schema: GFDictionarySchema in [request_schema, result_schema]:
		if schema == null:
			continue
		var schema_report: GFValidationReport = schema.validate_definition()
		var _merged_schema: RefCounted = report.merge(schema_report)
	return report


## 校验请求载荷和能力前置条件。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param payload: 请求载荷。
## [br]
## @param capabilities: Adapter 当前能力集合。
## [br]
## @schema payload: Dictionary platform method request payload.
## [br]
## @return 标准校验报告。
func validate_request(
	payload: Dictionary,
	capabilities: GFPlatformCapabilitySet = null
) -> GFValidationReport:
	var report: GFValidationReport = validate_definition()
	if capabilities == null and not required_capability_ids.is_empty():
		var _capability_set_issue: RefCounted = report.add_error(
			&"missing_capability_set",
			"Platform adapter did not expose a capability set."
		)
	elif capabilities != null:
		for capability_id: String in required_capability_ids:
			if not capabilities.has_capability(StringName(capability_id)):
				var _capability_issue: RefCounted = report.add_error(
					&"missing_capability",
					"Required platform capability is unavailable.",
					capability_id
				)
	if request_schema != null:
		var request_report: GFValidationReport = request_schema.validate_dictionary(payload)
		var _merged_request: RefCounted = report.merge(request_report)
	if max_request_bytes > 0 and _estimate_size_bytes(payload) > max_request_bytes:
		var _request_budget_issue: RefCounted = report.add_error(
			&"request_budget_exceeded",
			"Platform request payload exceeds the declared byte budget."
		)
	return report


## 校验成功结果的 schema 与字节预算。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param value: Adapter 成功结果值。
## [br]
## @schema value: Adapter-defined result value.
## [br]
## @return 标准校验报告。
func validate_result(value: Variant) -> GFValidationReport:
	var report: GFValidationReport = validate_definition()
	if result_schema != null:
		if value is Dictionary:
			var result_dictionary: Dictionary = value
			var result_report: GFValidationReport = result_schema.validate_dictionary(result_dictionary)
			var _merged_result: RefCounted = report.merge(result_report)
		else:
			var _result_type_issue: RefCounted = report.add_error(
				&"invalid_result_type",
				"Platform method result must be a Dictionary when result_schema is declared."
			)
	if max_result_bytes > 0 and _estimate_size_bytes(value) > max_result_bytes:
		var _result_budget_issue: RefCounted = report.add_error(
			&"result_budget_exceeded",
			"Platform method result exceeds the declared byte budget."
		)
	return report


## 创建描述符深拷贝。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新描述符。
func duplicate_descriptor() -> GFPlatformContractMethodDescriptor:
	return GFPlatformContractMethodDescriptor.new().configure(method_id, {
		"request_schema": request_schema.duplicate_schema() if request_schema != null else null,
		"result_schema": result_schema.duplicate_schema() if result_schema != null else null,
		"required_capability_ids": required_capability_ids,
		"max_request_bytes": max_request_bytes,
		"max_result_bytes": max_result_bytes,
		"max_concurrent_requests": max_concurrent_requests,
		"supports_cancellation": supports_cancellation,
		"sensitive_fields": sensitive_fields,
		"metadata": metadata,
	})


## 转换为不包含敏感载荷的描述字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 方法契约摘要。
## [br]
## @schema return: Dictionary platform contract method descriptor summary.
func to_dict() -> Dictionary:
	return {
		"method_id": method_id,
		"request_schema_id": request_schema.schema_id if request_schema != null else &"",
		"result_schema_id": result_schema.schema_id if result_schema != null else &"",
		"required_capability_ids": required_capability_ids.duplicate(),
		"max_request_bytes": max_request_bytes,
		"max_result_bytes": max_result_bytes,
		"max_concurrent_requests": max_concurrent_requests,
		"supports_cancellation": supports_cancellation,
		"sensitive_fields": sensitive_fields.duplicate(),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _get_dictionary_schema(options: Dictionary, key: String) -> GFDictionarySchema:
	var value: Variant = GFVariantData.get_option_value(options, key)
	if value is GFDictionarySchema:
		var schema: GFDictionarySchema = value
		return schema.duplicate_schema()
	return null


func _estimate_size_bytes(value: Variant) -> int:
	return GFVariantJsonCodec.stringify_json_compatible(value, "", true).to_utf8_buffer().size()


static func _normalize_string_set(values: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: String in values:
		var normalized: String = value.strip_edges()
		if not normalized.is_empty() and not result.has(normalized):
			var _appended: bool = result.append(normalized)
	result.sort()
	return result
