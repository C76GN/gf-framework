## GFPlatformAdapterConformance: Platform Adapter 静态一致性审查器。
##
## 在不调用外部 SDK 的前提下检查 Adapter 身份、状态、契约描述符、必需方法、
## 运行时能力和桥接覆盖。动态单终态、取消和结果 schema 由 GFPlatformAdapter
## 基类保证，并应由 Adapter 自己的契约测试覆盖。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since unreleased
class_name GFPlatformAdapterConformance
extends RefCounted


# --- 常量 ---

## Adapter 为空或身份未配置。
## [br]
## @api public
## [br]
## @since unreleased
const KIND_ADAPTER_INVALID: StringName = &"platform_adapter_invalid"

## Adapter 处于不可用终态。
## [br]
## @api public
## [br]
## @since unreleased
const KIND_ADAPTER_STATE_INVALID: StringName = &"platform_adapter_state_invalid"

## 缺少必需契约。
## [br]
## @api public
## [br]
## @since unreleased
const KIND_CONTRACT_MISSING: StringName = &"platform_contract_missing"

## 缺少契约描述符。
## [br]
## @api public
## [br]
## @since unreleased
const KIND_DESCRIPTOR_MISSING: StringName = &"platform_contract_descriptor_missing"

## 契约描述符定义无效。
## [br]
## @api public
## [br]
## @since unreleased
const KIND_DESCRIPTOR_INVALID: StringName = &"platform_contract_descriptor_invalid"

## 契约版本与消费方要求不一致。
## [br]
## @api public
## [br]
## @since unreleased
const KIND_CONTRACT_VERSION_MISMATCH: StringName = &"platform_contract_version_mismatch"

## 契约缺少必需方法。
## [br]
## @api public
## [br]
## @since unreleased
const KIND_METHOD_MISSING: StringName = &"platform_contract_method_missing"

## 运行时上下文缺少必需能力。
## [br]
## @api public
## [br]
## @since unreleased
const KIND_CAPABILITY_MISSING: StringName = &"platform_capability_missing"


# --- 公共方法 ---

## 校验 Platform Adapter 的静态契约。
##
## options 支持 required_contract_ids、required_contract_versions、
## required_capability_ids、required_methods、require_descriptors（默认 true）和
## require_ready（默认 false）。版本采用精确匹配；required_methods 是 contract_id
## 到 method ID 列表的字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param adapter: 待审查 Adapter。
## [br]
## @param options: 审查约束。
## [br]
## @schema options: Dictionary platform adapter conformance requirements.
## [br]
## @return 强类型校验报告。
static func validate(
	adapter: GFPlatformAdapter,
	options: Dictionary = {}
) -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new(
		"Platform adapter conformance"
	)
	if adapter == null:
		var _invalid_adapter: RefCounted = report.add_error(
			KIND_ADAPTER_INVALID,
			"Platform adapter is null."
		)
		return report
	var adapter_id: StringName = adapter.get_adapter_id()
	var platform_id: StringName = adapter.get_platform_id()
	var contract_ids: PackedStringArray = adapter.get_contract_ids()
	if adapter_id == &"" or platform_id == &"" or contract_ids.is_empty():
		var _invalid_identity: RefCounted = report.add_error(
			KIND_ADAPTER_INVALID,
			"Platform adapter identity and contract IDs must be configured.",
			adapter_id
		)
	var state: GFPlatformAdapter.State = adapter.get_state()
	if state in [GFPlatformAdapter.State.FAILED, GFPlatformAdapter.State.SHUTDOWN]:
		var _invalid_state: RefCounted = report.add_error(
			KIND_ADAPTER_STATE_INVALID,
			"Platform adapter is in a terminal unavailable state.",
			adapter_id,
			"",
			{"state": state}
		)
	elif GFVariantData.get_option_bool(options, "require_ready") and not adapter.is_ready():
		var _not_ready: RefCounted = report.add_error(
			KIND_ADAPTER_STATE_INVALID,
			"Platform adapter must be READY for this conformance profile.",
			adapter_id,
			"",
			{"state": state}
		)

	var required_contract_ids: PackedStringArray = _normalize_string_set(
		GFVariantData.get_option_packed_string_array(
			options,
			"required_contract_ids"
		)
	)
	for contract_id_text: String in required_contract_ids:
		if contract_ids.has(contract_id_text):
			continue
		var _missing_contract: RefCounted = report.add_error(
			KIND_CONTRACT_MISSING,
			"Platform adapter does not declare a required contract.",
			StringName(contract_id_text)
		)

	var require_descriptors: bool = GFVariantData.get_option_bool(
		options,
		"require_descriptors",
		true
	)
	var required_methods: Dictionary = GFVariantData.get_option_dictionary(
		options,
		"required_methods"
	)
	var required_contract_versions: Dictionary = GFVariantData.get_option_dictionary(
		options,
		"required_contract_versions"
	)
	for contract_id_text: String in contract_ids:
		var contract_id: StringName = StringName(contract_id_text)
		var descriptor: GFPlatformContractDescriptor = adapter.get_contract_descriptor(
			contract_id
		)
		if descriptor == null:
			if require_descriptors:
				var _missing_descriptor: RefCounted = report.add_error(
					KIND_DESCRIPTOR_MISSING,
					"Declared platform contract has no descriptor.",
					contract_id
				)
			continue
		var definition_report: GFValidationReport = descriptor.validate_definition()
		if not definition_report.is_ok():
			var _invalid_descriptor: RefCounted = report.add_error(
				KIND_DESCRIPTOR_INVALID,
				"Platform contract descriptor is invalid.",
				contract_id,
				"",
				{"validation": definition_report.to_dict()}
			)
		var required_version: String = GFVariantData.get_option_string(
			required_contract_versions,
			contract_id_text
		).strip_edges()
		if not required_version.is_empty() and descriptor.contract_version != required_version:
			var _version_mismatch: RefCounted = report.add_error(
				KIND_CONTRACT_VERSION_MISMATCH,
				"Platform contract version does not match the required version.",
				contract_id,
				"",
				{
					"actual_version": descriptor.contract_version,
					"required_version": required_version,
				}
			)
		var method_ids: PackedStringArray = _get_string_set(
			required_methods,
			contract_id_text
		)
		for method_id_text: String in method_ids:
			if descriptor.get_method(StringName(method_id_text)) != null:
				continue
			var _missing_method: RefCounted = report.add_error(
				KIND_METHOD_MISSING,
				"Platform contract descriptor does not declare a required method.",
				StringName(method_id_text),
				contract_id_text
			)

	var context: GFPlatformRuntimeContext = adapter.get_context()
	var required_capability_ids: PackedStringArray = _normalize_string_set(
		GFVariantData.get_option_packed_string_array(
			options,
			"required_capability_ids"
		)
	)
	for capability_id_text: String in required_capability_ids:
		if context != null and context.has_capability(StringName(capability_id_text)):
			continue
		var _missing_capability: RefCounted = report.add_error(
			KIND_CAPABILITY_MISSING,
			"Platform runtime context does not provide a required capability.",
			StringName(capability_id_text)
		)
	report.metadata = {
		"adapter_id": adapter_id,
		"platform_id": platform_id,
		"state": state,
		"contract_ids": contract_ids,
	}
	return report


## 生成 JSON 安全的一致性报告和桥接覆盖附录。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param adapter: 待审查 Adapter。
## [br]
## @param options: 传给 validate 的审查约束。
## [br]
## @schema options: Dictionary platform adapter conformance requirements.
## [br]
## @return JSON 安全报告字典。
## [br]
## @schema return: Dictionary validation report with bridge_coverage.
static func inspect(
	adapter: GFPlatformAdapter,
	options: Dictionary = {}
) -> Dictionary:
	var report: GFValidationReport = validate(adapter, options)
	var bridge_entries: Dictionary = make_bridge_entries(adapter, options)
	var coverage: Dictionary = GFBridgeContractReport.from_entries(
		_get_dictionary_entries(bridge_entries, "contract_entries"),
		_get_dictionary_entries(bridge_entries, "adapter_entries"),
		{"subject": "Platform adapter contract coverage"}
	)
	return report.to_json_compatible_dict({"bridge_coverage": coverage})


## 构建通用 GFBridgeContractReport 输入条目。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param adapter: Platform Adapter。
## [br]
## @param options: 可包含 required_contract_ids。
## [br]
## @schema options: Dictionary platform adapter conformance requirements.
## [br]
## @return contract_entries 与 adapter_entries。
## [br]
## @schema return: Dictionary bridge contract and adapter entry arrays.
static func make_bridge_entries(
	adapter: GFPlatformAdapter,
	options: Dictionary = {}
) -> Dictionary:
	var contract_ids: PackedStringArray = PackedStringArray()
	if adapter != null:
		contract_ids = adapter.get_contract_ids()
	for required_id: String in GFVariantData.get_option_packed_string_array(
		options,
		"required_contract_ids"
	):
		if not contract_ids.has(required_id):
			var _appended: bool = contract_ids.append(required_id)
	contract_ids = _normalize_string_set(contract_ids)
	var contract_entries: Array[Dictionary] = []
	for contract_id_text: String in contract_ids:
		contract_entries.append({
			"contract_id": StringName(contract_id_text),
			"required": true,
		})
	var adapter_entries: Array[Dictionary] = []
	if adapter != null:
		var context: GFPlatformRuntimeContext = adapter.get_context()
		adapter_entries.append({
			"adapter_id": adapter.get_adapter_id(),
			"contract_ids": adapter.get_contract_ids(),
			"enabled": adapter.get_state() not in [
				GFPlatformAdapter.State.FAILED,
				GFPlatformAdapter.State.SHUTDOWN,
			],
			"capabilities": (
				context.capabilities.capabilities.duplicate()
				if context != null and context.capabilities != null
				else PackedStringArray()
			),
		})
	return {
		"contract_entries": contract_entries,
		"adapter_entries": adapter_entries,
	}


# --- 私有/辅助方法 ---

static func _get_string_set(source: Dictionary, key: String) -> PackedStringArray:
	return _normalize_string_set(
		GFVariantData.get_option_packed_string_array(source, key)
	)


static func _normalize_string_set(values: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: String in values:
		var normalized: String = value.strip_edges()
		if not normalized.is_empty() and not result.has(normalized):
			var _appended: bool = result.append(normalized)
	result.sort()
	return result


static func _get_dictionary_entries(source: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in GFVariantData.get_option_array(source, key):
		if value is Dictionary:
			var entry: Dictionary = value
			result.append(entry.duplicate(true))
	return result
