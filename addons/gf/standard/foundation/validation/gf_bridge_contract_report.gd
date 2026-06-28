## GFBridgeContractReport: 外部桥接契约覆盖报告构建器。
##
## 用于比较“框架或工具期望存在的桥接契约”和“项目、SDK、GDExtension
## 或编辑器工具实际注册的适配器”。它只处理纯数据报告，不注册适配器、
## 不调用 handler，也不规定项目侧路由策略。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFBridgeContractReport
extends RefCounted


# --- 常量 ---

## 契约条目缺少有效 contract_id。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_CONTRACT_INVALID: StringName = &"bridge_contract_invalid"

## 同一 contract_id 被重复声明。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_CONTRACT_DUPLICATE: StringName = &"bridge_contract_duplicate"

## 必需契约没有任何启用的适配器覆盖。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_CONTRACT_MISSING: StringName = &"bridge_contract_missing"

## 适配器条目缺少有效 adapter_id 或 contract_ids。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_ADAPTER_INVALID: StringName = &"bridge_adapter_invalid"

## 适配器引用了未知契约。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_ADAPTER_EXTRA: StringName = &"bridge_adapter_extra"

## 适配器已声明但当前未启用。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_ADAPTER_DISABLED: StringName = &"bridge_adapter_disabled"

## 不允许多适配器的契约被多个启用适配器覆盖。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_ADAPTER_DUPLICATE: StringName = &"bridge_adapter_duplicate"

## 适配器签名不满足契约签名。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_ADAPTER_SIGNATURE_MISMATCH: StringName = &"bridge_adapter_signature_mismatch"

## 适配器版本不满足契约版本。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_ADAPTER_VERSION_MISMATCH: StringName = &"bridge_adapter_version_mismatch"

## 适配器缺少契约要求的能力。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_ADAPTER_CAPABILITY_MISSING: StringName = &"bridge_adapter_capability_missing"

const _DEFAULT_SUBJECT: String = "Bridge contract coverage"


# --- 公共变量 ---

## 报告主题。
## [br]
## @api public
## [br]
## @since 7.0.0
var subject: String = _DEFAULT_SUBJECT

## 期望存在的桥接契约条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema contracts: Array[Dictionary]，每项可包含 contract_id/id、kind、signature、version、required、allow_multiple、capabilities 和 metadata。
var contracts: Array[Dictionary] = []

## 实际注册或发现的适配器条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema adapters: Array[Dictionary]，每项可包含 adapter_id/id、contract_id、contract_ids、kind、signature、version、enabled、capabilities 和 metadata。
var adapters: Array[Dictionary] = []

## 调用方自定义元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @schema metadata: Dictionary caller-defined report metadata.
var metadata: Dictionary = {}


# --- 公共方法 ---

## 配置报告构建器。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_subject: 报告主题。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary caller-defined report metadata.
## [br]
## @return 当前构建器。
func configure(p_subject: String = _DEFAULT_SUBJECT, p_metadata: Dictionary = {}) -> GFBridgeContractReport:
	subject = p_subject if not p_subject.strip_edges().is_empty() else _DEFAULT_SUBJECT
	metadata = p_metadata.duplicate(true)
	return self


## 清空契约、适配器和元数据。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	contracts.clear()
	adapters.clear()
	metadata.clear()


## 添加一个期望桥接契约。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param contract_id: 稳定契约 ID。
## [br]
## @param options: 契约选项，支持 kind、signature、version、required、allow_multiple、capabilities 和 metadata。
## [br]
## @schema options: Dictionary bridge contract metadata.
## [br]
## @return 添加后的契约条目副本。
## [br]
## @schema return: Dictionary normalized bridge contract entry.
func add_contract(contract_id: StringName, options: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = options.duplicate(true)
	entry["contract_id"] = contract_id
	entry["id"] = contract_id
	contracts.append(entry)
	return _normalize_contract(entry, contracts.size() - 1).duplicate(true)


## 批量添加期望桥接契约。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entries: 契约条目数组。
## [br]
## @schema entries: Array[Dictionary] bridge contract entries.
## [br]
## @return 当前构建器。
func add_contracts(entries: Array[Dictionary]) -> GFBridgeContractReport:
	for entry: Dictionary in entries:
		contracts.append(entry.duplicate(true))
	return self


## 添加一个实际桥接适配器。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param adapter_id: 稳定适配器 ID。
## [br]
## @param contract_id: 适配器覆盖的主要契约 ID；为空时可通过 options.contract_ids 提供。
## [br]
## @param options: 适配器选项，支持 contract_ids、kind、signature、version、enabled、capabilities 和 metadata。
## [br]
## @schema options: Dictionary bridge adapter metadata.
## [br]
## @return 添加后的适配器条目副本。
## [br]
## @schema return: Dictionary normalized bridge adapter entry.
func add_adapter(
	adapter_id: StringName,
	contract_id: StringName = &"",
	options: Dictionary = {}
) -> Dictionary:
	var entry: Dictionary = options.duplicate(true)
	entry["adapter_id"] = adapter_id
	entry["id"] = adapter_id
	if contract_id != &"":
		entry["contract_id"] = contract_id
	adapters.append(entry)
	return _normalize_adapter(entry, adapters.size() - 1).duplicate(true)


## 批量添加实际桥接适配器。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entries: 适配器条目数组。
## [br]
## @schema entries: Array[Dictionary] bridge adapter entries.
## [br]
## @return 当前构建器。
func add_adapters(entries: Array[Dictionary]) -> GFBridgeContractReport:
	for entry: Dictionary in entries:
		adapters.append(entry.duplicate(true))
	return self


## 构建桥接契约覆盖报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 报告选项，支持 default_allow_multiple、missing_severity、extra_severity、duplicate_severity、disabled_severity、mismatch_severity、warnings_as_errors、fallback_action 和 no_action。
## [br]
## @schema options: Dictionary report options.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok、healthy、contracts、adapters、coverage counts、issues、summary and next_action.
func get_report(options: Dictionary = {}) -> Dictionary:
	return _build_report(contracts, adapters, subject, metadata, options)


## 从契约和适配器数组直接创建覆盖报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param contract_entries: 契约条目数组。
## [br]
## @param adapter_entries: 适配器条目数组。
## [br]
## @param options: 构建器与报告选项，支持 subject、metadata 以及 get_report() 选项。
## [br]
## @schema contract_entries: Array[Dictionary] bridge contract entries.
## [br]
## @schema adapter_entries: Array[Dictionary] bridge adapter entries.
## [br]
## @schema options: Dictionary builder and report options.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary bridge contract coverage report.
static func from_entries(
	contract_entries: Array[Dictionary],
	adapter_entries: Array[Dictionary],
	options: Dictionary = {}
) -> Dictionary:
	return _build_report(
		contract_entries,
		adapter_entries,
		GFVariantData.get_option_string(options, "subject", _DEFAULT_SUBJECT),
		GFVariantData.get_option_dictionary(options, "metadata"),
		options
	)


## 为 GFRequestHandlerRegistry 生成请求 handler 覆盖报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param required_request_types: 必需请求类型列表。
## [br]
## @param registry: 请求 handler 注册表。
## [br]
## @param options: 构建器与报告选项，支持 subject、metadata、kind、signature、adapter_kind 以及 get_report() 选项。
## [br]
## @schema options: Dictionary builder and report options.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary request handler bridge coverage report.
static func report_request_handlers(
	required_request_types: PackedStringArray,
	registry: GFRequestHandlerRegistry,
	options: Dictionary = {}
) -> Dictionary:
	var contract_entries: Array[Dictionary] = []
	var adapter_entries: Array[Dictionary] = []
	var contract_kind: StringName = GFVariantData.get_option_string_name(options, "kind", &"request_handler")
	for request_type_text: String in required_request_types:
		var request_type: StringName = StringName(request_type_text.strip_edges())
		if request_type == &"":
			continue
		contract_entries.append({
			"contract_id": request_type,
			"kind": contract_kind,
			"signature": GFVariantData.get_option_string(options, "signature", "Dictionary(request) -> Variant"),
			"allow_multiple": false,
		})

	if registry != null:
		var adapter_kind: StringName = GFVariantData.get_option_string_name(options, "adapter_kind", &"request_handler")
		for request_type: StringName in registry.get_handler_ids():
			var snapshot: Dictionary = registry.get_handler_snapshot(request_type)
			adapter_entries.append({
				"adapter_id": StringName("handler:%s" % String(request_type)),
				"contract_id": request_type,
				"kind": adapter_kind,
				"signature": GFVariantData.get_option_string(options, "signature", "Dictionary(request) -> Variant"),
				"enabled": GFVariantData.get_option_bool(snapshot, "has_valid_handler"),
				"metadata": snapshot,
			})

	return _build_report(
		contract_entries,
		adapter_entries,
		GFVariantData.get_option_string(options, "subject", "Request handler coverage"),
		GFVariantData.get_option_dictionary(options, "metadata"),
		options
	)


# --- 私有/辅助方法 ---

static func _build_report(
	source_contracts: Array[Dictionary],
	source_adapters: Array[Dictionary],
	report_subject: String,
	report_metadata: Dictionary,
	options: Dictionary
) -> Dictionary:
	var normalized_contracts: Array[Dictionary] = []
	var normalized_adapters: Array[Dictionary] = []
	var contract_lookup: Dictionary = {}
	var adapter_lookup: Dictionary = {}
	var report: Dictionary = {
		"subject": report_subject,
		"contract_count": 0,
		"adapter_count": 0,
		"covered_count": 0,
		"compatible_count": 0,
		"missing_count": 0,
		"optional_missing_count": 0,
		"extra_count": 0,
		"duplicate_count": 0,
		"mismatch_count": 0,
		"disabled_count": 0,
		"invalid_count": 0,
		"covered": [],
		"compatible": [],
		"missing": [],
		"optional_missing": [],
		"extra_adapters": [],
		"duplicate_contracts": [],
		"mismatched_contracts": [],
		"contracts": [],
		"adapters": [],
		"issues": [],
		"metadata": report_metadata.duplicate(true),
	}

	_collect_contracts(source_contracts, normalized_contracts, contract_lookup, report, options)
	_collect_adapters(source_adapters, normalized_adapters, adapter_lookup, contract_lookup, report, options)
	_evaluate_contracts(normalized_contracts, adapter_lookup, report, options)

	report["contract_count"] = normalized_contracts.size()
	report["adapter_count"] = normalized_adapters.size()
	report["contracts"] = _copy_entries(normalized_contracts)
	report["adapters"] = _copy_entries(normalized_adapters)
	return GFValidationReportDictionary.finalize_report(report, report_subject, {
		"fallback_action": GFVariantData.get_option_string(options, "fallback_action", "Review bridge contract coverage before relying on the adapter boundary."),
		"no_action": GFVariantData.get_option_string(options, "no_action", "Bridge contracts are covered by compatible adapters."),
		"warnings_as_errors": GFVariantData.get_option_bool(options, "warnings_as_errors", false),
	})


static func _collect_contracts(
	source_contracts: Array[Dictionary],
	normalized_contracts: Array[Dictionary],
	contract_lookup: Dictionary,
	report: Dictionary,
	options: Dictionary
) -> void:
	for index: int in range(source_contracts.size()):
		var source_contract: Dictionary = source_contracts[index]
		var contract: Dictionary = _normalize_contract(source_contract, index)
		var contract_id: StringName = GFVariantData.get_option_string_name(contract, "contract_id")
		if contract_id == &"":
			_increment_report_count(report, "invalid_count")
			_append_issue(
				report,
				"error",
				KIND_CONTRACT_INVALID,
				"bridge contract id is empty",
				{ "entry_index": index }
			)
			continue
		if contract_lookup.has(contract_id):
			_increment_report_count(report, "invalid_count")
			_append_issue(
				report,
				"error",
				KIND_CONTRACT_DUPLICATE,
				"bridge contract is declared more than once",
				{
					"contract_id": contract_id,
					"entry_index": index,
				}
			)
			continue
		var default_allow_multiple: bool = GFVariantData.get_option_bool(options, "default_allow_multiple", false)
		if not _entry_has_any(source_contract, PackedStringArray(["allow_multiple", "multi_adapter"])):
			contract["allow_multiple"] = default_allow_multiple
		contract_lookup[contract_id] = contract
		normalized_contracts.append(contract)


static func _collect_adapters(
	source_adapters: Array[Dictionary],
	normalized_adapters: Array[Dictionary],
	adapter_lookup: Dictionary,
	contract_lookup: Dictionary,
	report: Dictionary,
	options: Dictionary
) -> void:
	for index: int in range(source_adapters.size()):
		var adapter: Dictionary = _normalize_adapter(source_adapters[index], index)
		normalized_adapters.append(adapter)
		var adapter_id: StringName = GFVariantData.get_option_string_name(adapter, "adapter_id")
		var contract_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(adapter, "contract_ids")
		if adapter_id == &"" or contract_ids.is_empty():
			_increment_report_count(report, "invalid_count")
			_append_issue(
				report,
				"error",
				KIND_ADAPTER_INVALID,
				"bridge adapter id or contract ids are empty",
				{
					"adapter_id": adapter_id,
					"entry_index": index,
				}
			)
			continue

		if not GFVariantData.get_option_bool(adapter, "enabled", true):
			_increment_report_count(report, "disabled_count")
			_append_issue(
				report,
				GFVariantData.get_option_value(options, "disabled_severity", "warning"),
				KIND_ADAPTER_DISABLED,
				"bridge adapter is disabled",
				{
					"adapter_id": adapter_id,
					"contract_ids": contract_ids,
				}
			)
			continue

		for contract_text: String in contract_ids:
			var contract_id: StringName = StringName(contract_text)
			if not contract_lookup.has(contract_id):
				_increment_report_count(report, "extra_count")
				_append_string_unique(report, "extra_adapters", String(adapter_id))
				_append_issue(
					report,
					GFVariantData.get_option_value(options, "extra_severity", "warning"),
					KIND_ADAPTER_EXTRA,
					"bridge adapter targets an unknown contract",
					{
						"adapter_id": adapter_id,
						"contract_id": contract_id,
					}
				)
				continue
			if not adapter_lookup.has(contract_id):
				adapter_lookup[contract_id] = []
			var entries: Array = GFVariantData.as_array(adapter_lookup[contract_id])
			entries.append(adapter)
			adapter_lookup[contract_id] = entries


static func _evaluate_contracts(
	normalized_contracts: Array[Dictionary],
	adapter_lookup: Dictionary,
	report: Dictionary,
	options: Dictionary
) -> void:
	for index: int in range(normalized_contracts.size()):
		var contract: Dictionary = normalized_contracts[index]
		var contract_id: StringName = GFVariantData.get_option_string_name(contract, "contract_id")
		if contract_id == &"":
			continue

		var expected_adapters: Array = GFVariantData.as_array(adapter_lookup.get(contract_id, []))
		var adapter_ids: PackedStringArray = _get_adapter_ids(expected_adapters)
		var compatible_adapter_ids: PackedStringArray = PackedStringArray()
		contract["adapter_ids"] = adapter_ids
		contract["compatible_adapter_ids"] = compatible_adapter_ids

		if expected_adapters.is_empty():
			_handle_missing_contract(contract, report, options)
			continue

		_increment_report_count(report, "covered_count")
		_append_string_unique(report, "covered", String(contract_id))
		_check_duplicate_adapters(contract, adapter_ids, report, options)
		for adapter_value: Variant in expected_adapters:
			if not (adapter_value is Dictionary):
				continue
			var adapter: Dictionary = adapter_value
			if _adapter_matches_contract(adapter, contract, report, options):
				var adapter_id: StringName = GFVariantData.get_option_string_name(adapter, "adapter_id")
				var _appended_compatible_id: bool = compatible_adapter_ids.append(String(adapter_id))

		compatible_adapter_ids.sort()
		contract["compatible_adapter_ids"] = compatible_adapter_ids
		if not compatible_adapter_ids.is_empty():
			_increment_report_count(report, "compatible_count")
			_append_string_unique(report, "compatible", String(contract_id))


static func _handle_missing_contract(contract: Dictionary, report: Dictionary, options: Dictionary) -> void:
	var contract_id: StringName = GFVariantData.get_option_string_name(contract, "contract_id")
	if GFVariantData.get_option_bool(contract, "required", true):
		_increment_report_count(report, "missing_count")
		_append_string_unique(report, "missing", String(contract_id))
		_append_issue(
			report,
			GFVariantData.get_option_value(options, "missing_severity", "error"),
			KIND_CONTRACT_MISSING,
			"required bridge contract has no enabled adapter",
			{
				"contract_id": contract_id,
				"contract_kind": GFVariantData.get_option_string_name(contract, "kind"),
			}
		)
		return

	_increment_report_count(report, "optional_missing_count")
	_append_string_unique(report, "optional_missing", String(contract_id))
	if GFVariantData.get_option_bool(options, "report_optional_missing", false):
		_append_issue(
			report,
			GFVariantData.get_option_value(options, "optional_missing_severity", "info"),
			KIND_CONTRACT_MISSING,
			"optional bridge contract has no enabled adapter",
			{
				"contract_id": contract_id,
				"contract_kind": GFVariantData.get_option_string_name(contract, "kind"),
			}
		)


static func _check_duplicate_adapters(
	contract: Dictionary,
	adapter_ids: PackedStringArray,
	report: Dictionary,
	options: Dictionary
) -> void:
	if adapter_ids.size() <= 1 or GFVariantData.get_option_bool(contract, "allow_multiple", false):
		return
	var contract_id: StringName = GFVariantData.get_option_string_name(contract, "contract_id")
	_increment_report_count(report, "duplicate_count")
	_append_string_unique(report, "duplicate_contracts", String(contract_id))
	_append_issue(
		report,
		GFVariantData.get_option_value(options, "duplicate_severity", "warning"),
		KIND_ADAPTER_DUPLICATE,
		"bridge contract is covered by multiple adapters",
		{
			"contract_id": contract_id,
			"adapter_ids": adapter_ids,
		}
	)


static func _adapter_matches_contract(
	adapter: Dictionary,
	contract: Dictionary,
	report: Dictionary,
	options: Dictionary
) -> bool:
	var matches: bool = true
	if not _check_signature(adapter, contract, report, options):
		matches = false
	if not _check_version(adapter, contract, report, options):
		matches = false
	if not _check_capabilities(adapter, contract, report, options):
		matches = false
	return matches


static func _check_signature(
	adapter: Dictionary,
	contract: Dictionary,
	report: Dictionary,
	options: Dictionary
) -> bool:
	var expected_signature: String = GFVariantData.get_option_string(contract, "signature").strip_edges()
	if expected_signature.is_empty():
		return true
	var actual_signature: String = GFVariantData.get_option_string(adapter, "signature").strip_edges()
	if expected_signature == actual_signature:
		return true
	_append_mismatch_issue(
		report,
		options,
		KIND_ADAPTER_SIGNATURE_MISMATCH,
		"bridge adapter signature does not match contract",
		adapter,
		contract,
		{
			"expected_signature": expected_signature,
			"actual_signature": actual_signature,
		}
	)
	return false


static func _check_version(
	adapter: Dictionary,
	contract: Dictionary,
	report: Dictionary,
	options: Dictionary
) -> bool:
	var expected_version: String = GFVariantData.get_option_string(contract, "version").strip_edges()
	if expected_version.is_empty():
		return true
	var actual_version: String = GFVariantData.get_option_string(adapter, "version").strip_edges()
	if expected_version == actual_version:
		return true
	_append_mismatch_issue(
		report,
		options,
		KIND_ADAPTER_VERSION_MISMATCH,
		"bridge adapter version does not match contract",
		adapter,
		contract,
		{
			"expected_version": expected_version,
			"actual_version": actual_version,
		}
	)
	return false


static func _check_capabilities(
	adapter: Dictionary,
	contract: Dictionary,
	report: Dictionary,
	options: Dictionary
) -> bool:
	var required_capabilities: PackedStringArray = GFVariantData.get_option_packed_string_array(contract, "capabilities")
	if required_capabilities.is_empty():
		return true
	var adapter_capabilities: PackedStringArray = GFVariantData.get_option_packed_string_array(adapter, "capabilities")
	var missing_capabilities: PackedStringArray = PackedStringArray()
	for capability: String in required_capabilities:
		if not adapter_capabilities.has(capability):
			var _appended: bool = missing_capabilities.append(capability)
	if missing_capabilities.is_empty():
		return true
	_append_mismatch_issue(
		report,
		options,
		KIND_ADAPTER_CAPABILITY_MISSING,
		"bridge adapter does not provide required capabilities",
		adapter,
		contract,
		{
			"expected_capabilities": required_capabilities,
			"actual_capabilities": adapter_capabilities,
			"missing_capabilities": missing_capabilities,
		}
	)
	return false


static func _append_mismatch_issue(
	report: Dictionary,
	options: Dictionary,
	kind: StringName,
	message: String,
	adapter: Dictionary,
	contract: Dictionary,
	fields: Dictionary
) -> void:
	var contract_id: StringName = GFVariantData.get_option_string_name(contract, "contract_id")
	var adapter_id: StringName = GFVariantData.get_option_string_name(adapter, "adapter_id")
	_increment_report_count(report, "mismatch_count")
	_append_string_unique(report, "mismatched_contracts", String(contract_id))
	var issue_fields: Dictionary = {
		"contract_id": contract_id,
		"adapter_id": adapter_id,
	}
	var _merged_fields: Dictionary = GFVariantData.merge_dictionary(issue_fields, fields, true)
	_append_issue(
		report,
		GFVariantData.get_option_value(options, "mismatch_severity", "error"),
		kind,
		message,
		issue_fields
	)


static func _normalize_contract(entry: Dictionary, entry_index: int) -> Dictionary:
	var contract_id: StringName = _get_first_string_name(entry, PackedStringArray([
		"contract_id",
		"id",
		"request_type",
	]), &"")
	return {
		"contract_id": contract_id,
		"id": contract_id,
		"kind": _get_first_string_name(entry, PackedStringArray(["kind", "contract_kind"]), &""),
		"signature": _get_first_string(entry, PackedStringArray(["signature", "expected_signature"])),
		"version": _get_first_string(entry, PackedStringArray(["version", "expected_version"])),
		"required": _get_first_bool(entry, PackedStringArray(["required", "is_required"]), true),
		"allow_multiple": _get_first_bool(entry, PackedStringArray(["allow_multiple", "multi_adapter"]), false),
		"capabilities": _get_first_packed_string_array(entry, PackedStringArray([
			"capabilities",
			"required_capabilities",
			"capability_ids",
		])),
		"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
		"entry_index": entry_index,
	}


static func _normalize_adapter(entry: Dictionary, entry_index: int) -> Dictionary:
	var adapter_id: StringName = _get_first_string_name(entry, PackedStringArray([
		"adapter_id",
		"id",
		"handler_id",
	]), &"")
	var contract_ids: PackedStringArray = _get_adapter_contract_ids(entry)
	return {
		"adapter_id": adapter_id,
		"id": adapter_id,
		"contract_ids": contract_ids,
		"kind": _get_first_string_name(entry, PackedStringArray(["kind", "adapter_kind"]), &""),
		"signature": _get_first_string(entry, PackedStringArray(["signature", "provided_signature"])),
		"version": _get_first_string(entry, PackedStringArray(["version", "provided_version"])),
		"enabled": _get_first_bool(entry, PackedStringArray(["enabled", "active", "has_valid_handler"]), true),
		"capabilities": _get_first_packed_string_array(entry, PackedStringArray([
			"capabilities",
			"provided_capabilities",
			"capability_ids",
		])),
		"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
		"entry_index": entry_index,
	}


static func _get_adapter_contract_ids(entry: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	_append_string_name_value(result, GFVariantData.get_option_value(entry, "contract_id"))
	_append_string_name_value(result, GFVariantData.get_option_value(entry, "request_type"))
	for key: String in ["contract_ids", "contracts", "supported_contracts"]:
		var values: PackedStringArray = GFVariantData.get_option_packed_string_array(entry, key)
		for value: String in values:
			_append_string_name_value(result, value)
	result.sort()
	return result


static func _get_adapter_ids(adapter_entries: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for adapter_value: Variant in adapter_entries:
		if not (adapter_value is Dictionary):
			continue
		var adapter: Dictionary = adapter_value
		_append_string_name_value(result, GFVariantData.get_option_value(adapter, "adapter_id"))
	result.sort()
	return result


static func _get_first_string(entry: Dictionary, keys: PackedStringArray, default_value: String = "") -> String:
	for key: String in keys:
		if entry.has(key):
			return GFVariantData.to_text(entry[key], default_value).strip_edges()
		var key_name: StringName = StringName(key)
		if entry.has(key_name):
			return GFVariantData.to_text(entry[key_name], default_value).strip_edges()
	return default_value


static func _get_first_string_name(entry: Dictionary, keys: PackedStringArray, default_value: StringName = &"") -> StringName:
	var text: String = _get_first_string(entry, keys, String(default_value))
	return StringName(text) if not text.is_empty() else default_value


static func _get_first_bool(entry: Dictionary, keys: PackedStringArray, default_value: bool = false) -> bool:
	for key: String in keys:
		if entry.has(key):
			return GFVariantData.to_bool(entry[key], default_value)
		var key_name: StringName = StringName(key)
		if entry.has(key_name):
			return GFVariantData.to_bool(entry[key_name], default_value)
	return default_value


static func _get_first_packed_string_array(entry: Dictionary, keys: PackedStringArray) -> PackedStringArray:
	for key: String in keys:
		var values: PackedStringArray = GFVariantData.get_option_packed_string_array(entry, key)
		if not values.is_empty():
			values.sort()
			return values
	return PackedStringArray()


static func _append_string_name_value(target: PackedStringArray, value: Variant) -> void:
	var text: String = GFVariantData.to_text(value).strip_edges()
	if text.is_empty() or target.has(text):
		return
	var _appended: bool = target.append(text)


static func _append_issue(
	report: Dictionary,
	severity: Variant,
	kind: StringName,
	message: String,
	fields: Dictionary
) -> void:
	var _issue: Dictionary = GFValidationReportDictionary.append_issue(report, severity, kind, message, fields)


static func _append_string_unique(report: Dictionary, field_name: String, value: String) -> void:
	var values: Array = GFVariantData.get_option_array(report, field_name)
	if values.has(value):
		return
	values.append(value)
	values.sort()
	report[field_name] = values


static func _increment_report_count(report: Dictionary, field_name: String) -> void:
	report[field_name] = GFVariantData.get_option_int(report, field_name) + 1


static func _copy_entries(source_entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in source_entries:
		result.append(entry.duplicate(true))
	return result


static func _entry_has_any(entry: Dictionary, keys: PackedStringArray) -> bool:
	for key: String in keys:
		if entry.has(key):
			return true
		if entry.has(StringName(key)):
			return true
	return false
