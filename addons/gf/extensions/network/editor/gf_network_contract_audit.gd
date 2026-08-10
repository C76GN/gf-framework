@tool

## GFNetworkContractAudit: 网络契约编辑器审计器。
##
## 对 GFNetworkContract 执行 fail-closed 倾向的结构审计，帮助项目在运行前发现
## 松散 payload、未知通道、缺少版本和过宽 Variant 字段等风险。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 8.0.0
class_name GFNetworkContractAudit
extends RefCounted


# --- 常量 ---

const _GF_VALIDATION_REPORT_DICTIONARY = preload("res://addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd")
const _GF_PATH_TOOLS_SCRIPT = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _DEFAULT_MAX_CONTRACT_PATHS: int = 256
const _ABSOLUTE_MAX_CONTRACT_PATHS: int = 4096
const _DEFAULT_MAX_KNOWN_CHANNEL_IDS: int = 1024
const _ABSOLUTE_MAX_KNOWN_CHANNEL_IDS: int = 4096
const _DEFAULT_MAX_CHANNEL_ID_LENGTH: int = 256
const _ABSOLUTE_MAX_CHANNEL_ID_LENGTH: int = 1024


# --- 公共方法 ---

## 审计网络契约。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param contract: 网络契约。
## [br]
## @param options: 审计选项，支持 known_channel_ids、require_contract_id、require_version、require_channel_ids、warn_variant_fields、warn_collection_bounds_review、max_messages、max_fields_per_message、max_known_channel_ids 和 max_channel_id_length。
## [br]
## @schema options: Dictionary audit options.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, issues, issue_count, summary, and next_action.
func audit_contract(contract: GFNetworkContract, options: Dictionary = {}) -> Dictionary:
	var issues: Array[Dictionary] = []
	if contract == null:
		issues.append(_make_issue("error", "contract_missing", "Network contract is missing."))
		return _finalize_report(&"", issues)
	var input_budget_issue: Dictionary = _get_contract_audit_input_budget_issue(options)
	if not input_budget_issue.is_empty():
		return _finalize_report(
			contract.contract_id,
			_copy_issues([input_budget_issue], &"input_budget")
		)

	issues.append_array(_copy_issues(GFVariantData.get_option_array(contract.validate_contract(), "issues"), &"definition"))
	var policy_issues: Array[Dictionary] = []
	_append_contract_policy_issues(contract, options, policy_issues)
	_append_message_policy_issues(contract, options, policy_issues)
	issues.append_array(_copy_issues(policy_issues, &"policy"))
	return _finalize_report(contract.contract_id, issues)


## 审计多个网络契约资源路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param contract_paths: 契约资源路径列表。
## [br]
## @param options: 审计选项，另支持正整数 max_contract_paths、max_known_channel_ids 和 max_channel_id_length；调用方预算受框架硬上限约束。
## [br]
## @schema options: Dictionary audit options.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, issues, issue_count, contract_count, summary, and next_action.
func audit_paths(contract_paths: PackedStringArray, options: Dictionary = {}) -> Dictionary:
	var issues: Array[Dictionary] = []
	var contract_count: int = 0
	var seen_input_paths: Dictionary = {}
	var seen_resource_paths: Dictionary = {}
	var max_contract_paths: int = _read_positive_bounded_option(
		options,
		"max_contract_paths",
		_DEFAULT_MAX_CONTRACT_PATHS,
		_ABSOLUTE_MAX_CONTRACT_PATHS
	)
	if max_contract_paths < 0:
		issues.append(_make_issue(
			"error",
			"invalid_audit_options",
			"max_contract_paths must be a positive integer.",
			{ "path": "max_contract_paths" }
		))
	elif contract_paths.size() > max_contract_paths:
		issues.append(_make_audit_budget_issue(
			"contract_path_count",
			max_contract_paths,
			contract_paths.size()
		))
	if not issues.is_empty():
		return _finalize_paths_report(contract_count, issues)
	for path: String in contract_paths:
		var normalized_path: String = _GF_PATH_TOOLS_SCRIPT.normalize_resource_path(path)
		var input_identity: String = normalized_path.to_lower()
		if normalized_path.is_empty() or seen_input_paths.has(input_identity):
			continue
		seen_input_paths[input_identity] = true
		var resource: Resource = ResourceLoader.load(normalized_path)
		if not (resource is GFNetworkContract):
			issues.append(_make_issue(
				"error",
				"contract_load_failed",
				"Network contract path did not load a GFNetworkContract resource.",
				{
					"path": normalized_path,
					"resource_path": normalized_path,
				}
			))
			continue
		var contract: GFNetworkContract = resource
		var canonical_resource_path: String = _GF_PATH_TOOLS_SCRIPT.normalize_resource_path(
			contract.resource_path,
			normalized_path
		)
		var resource_identity: String = canonical_resource_path.to_lower()
		if seen_resource_paths.has(resource_identity):
			continue
		seen_resource_paths[resource_identity] = true
		contract_count += 1
		issues.append_array(_copy_issues(
			GFVariantData.get_option_array(audit_contract(contract, options), "issues"),
			&"path_audit",
			{ "resource_path": canonical_resource_path }
		))

	return _finalize_paths_report(contract_count, issues)


# --- 私有/辅助方法 ---

func _get_contract_audit_input_budget_issue(options: Dictionary) -> Dictionary:
	var max_known_channel_ids: int = _read_positive_bounded_option(
		options,
		"max_known_channel_ids",
		_DEFAULT_MAX_KNOWN_CHANNEL_IDS,
		_ABSOLUTE_MAX_KNOWN_CHANNEL_IDS
	)
	var max_channel_id_length: int = _read_positive_bounded_option(
		options,
		"max_channel_id_length",
		_DEFAULT_MAX_CHANNEL_ID_LENGTH,
		_ABSOLUTE_MAX_CHANNEL_ID_LENGTH
	)
	if max_known_channel_ids < 0:
		return _make_issue(
			"error",
			"invalid_audit_options",
			"max_known_channel_ids must be a positive integer.",
			{ "path": "max_known_channel_ids" }
		)
	if max_channel_id_length < 0:
		return _make_issue(
			"error",
			"invalid_audit_options",
			"max_channel_id_length must be a positive integer.",
			{ "path": "max_channel_id_length" }
		)
	var known_channel_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		options,
		"known_channel_ids"
	)
	if known_channel_ids.size() > max_known_channel_ids:
		return _make_audit_budget_issue(
			"known_channel_id_count",
			max_known_channel_ids,
			known_channel_ids.size()
		)
	for channel_id: String in known_channel_ids:
		if channel_id.length() > max_channel_id_length:
			return _make_audit_budget_issue(
				"known_channel_id_length",
				max_channel_id_length,
				channel_id.length()
			)
	return {}


func _read_positive_bounded_option(
	options: Dictionary,
	key: String,
	default_value: int,
	absolute_value: int
) -> int:
	if not options.has(key) and not options.has(StringName(key)):
		return default_value
	var raw_value: Variant = GFVariantData.get_option_value(options, key)
	var option_value: int = raw_value if raw_value is int else -1
	if option_value <= 0:
		return -1
	return mini(option_value, absolute_value)


func _make_audit_budget_issue(
	budget_name: String,
	expected_value: int,
	actual_value: int
) -> Dictionary:
	return _make_issue(
		"error",
		"audit_budget_exceeded",
		"Network contract audit exceeded the %s budget." % budget_name,
		{
			"budget": budget_name,
			"expected_value": expected_value,
			"actual_value": actual_value,
		}
	)

func _append_contract_policy_issues(
	contract: GFNetworkContract,
	options: Dictionary,
	issues: Array[Dictionary]
) -> void:
	if GFVariantData.get_option_bool(options, "require_contract_id", true) and contract.contract_id == &"":
		issues.append(_make_issue("error", "contract_id_missing", "Network contract should declare a stable contract_id."))
	if GFVariantData.get_option_bool(options, "require_version", true):
		if contract.contract_version_major <= 0 and contract.contract_version_minor <= 0:
			issues.append(_make_issue("warning", "contract_version_missing", "Network contract should declare a non-zero version before production use.", {
				"contract_id": contract.contract_id,
			}))
	if contract.messages.is_empty():
		issues.append(_make_issue("warning", "no_messages", "Network contract does not declare any messages.", {
			"contract_id": contract.contract_id,
		}))
	var max_messages: int = GFVariantData.get_option_int(options, "max_messages", 0)
	if max_messages > 0 and contract.messages.size() > max_messages:
		issues.append(_make_issue("warning", "message_count_above_budget", "Network contract declares more messages than the configured audit budget.", {
			"contract_id": contract.contract_id,
			"expected_value": max_messages,
			"actual_value": contract.messages.size(),
		}))


func _append_message_policy_issues(
	contract: GFNetworkContract,
	options: Dictionary,
	issues: Array[Dictionary]
) -> void:
	var known_channels: PackedStringArray = _normalize_string_set(GFVariantData.get_option_packed_string_array(options, "known_channel_ids"))
	var require_channel_ids: bool = GFVariantData.get_option_bool(options, "require_channel_ids", false)
	var warn_variant_fields: bool = GFVariantData.get_option_bool(options, "warn_variant_fields", true)
	var warn_collection_bounds_review: bool = GFVariantData.get_option_bool(
		options,
		"warn_collection_bounds_review",
		true
	)
	var max_fields_per_message: int = GFVariantData.get_option_int(options, "max_fields_per_message", 0)

	for message_contract: GFNetworkContractMessage in contract.messages:
		if message_contract == null:
			continue
		if require_channel_ids and message_contract.channel_id == &"":
			issues.append(_make_issue("warning", "message_channel_missing", "Network contract message does not declare a default channel_id.", {
				"contract_id": contract.contract_id,
				"message_type": message_contract.message_type,
			}))
		if not known_channels.is_empty() and message_contract.channel_id != &"" and not known_channels.has(String(message_contract.channel_id)):
			issues.append(_make_issue("error", "unknown_channel_id", "Network contract message references an unknown channel_id.", {
				"contract_id": contract.contract_id,
				"message_type": message_contract.message_type,
				"channel_id": message_contract.channel_id,
			}))
		if message_contract.fields.is_empty():
			issues.append(_make_issue("warning", "message_has_no_fields", "Network contract message has no payload fields.", {
				"contract_id": contract.contract_id,
				"message_type": message_contract.message_type,
			}))
		if max_fields_per_message > 0 and message_contract.fields.size() > max_fields_per_message:
			issues.append(_make_issue("warning", "field_count_above_budget", "Network contract message declares more fields than the configured audit budget.", {
				"contract_id": contract.contract_id,
				"message_type": message_contract.message_type,
				"expected_value": max_fields_per_message,
				"actual_value": message_contract.fields.size(),
			}))
		_append_field_policy_issues(
			message_contract,
			warn_variant_fields,
			warn_collection_bounds_review,
			issues
		)


func _append_field_policy_issues(
	message_contract: GFNetworkContractMessage,
	warn_variant_fields: bool,
	warn_collection_bounds_review: bool,
	issues: Array[Dictionary]
) -> void:
	for field: GFNetworkContractField in message_contract.fields:
		if field == null:
			continue
		if warn_variant_fields and field.value_type == GFNetworkContractField.ValueType.VARIANT:
			issues.append(_make_issue("warning", "loose_variant_field", "Network contract field uses unrestricted Variant.", {
				"message_type": message_contract.message_type,
				"field_name": field.field_name,
			}))
		if warn_collection_bounds_review and (
			field.value_type == GFNetworkContractField.ValueType.DICTIONARY
			or field.value_type == GFNetworkContractField.ValueType.ARRAY
		):
			issues.append(_make_issue("warning", "collection_bounds_review_required", "Network contract collection bounds require manual review because GF does not interpret project-owned field metadata.", {
				"message_type": message_contract.message_type,
				"field_name": field.field_name,
			}))


func _copy_issues(
	source_issues: Array,
	phase: StringName,
	context: Dictionary = {}
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue_value: Variant in source_issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if issue.is_empty():
			continue
		var copy: Dictionary = issue.duplicate(true)
		if copy.has("phase") or copy.has(&"phase"):
			copy["aggregation_phase"] = phase
		else:
			copy["phase"] = phase
		var _merge_context_result: Dictionary = GFVariantData.merge_dictionary(
			copy,
			context,
			true
		)
		result.append(copy)
	return result


func _make_issue(
	severity: String,
	kind: String,
	message: String,
	fields: Dictionary = {}
) -> Dictionary:
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"message": message,
	}
	var _merge_result: Dictionary = GFVariantData.merge_dictionary(issue, fields, true)
	return issue


func _finalize_report(contract_id: StringName, issues: Array[Dictionary]) -> Dictionary:
	var report: Dictionary = {
		"subject": "Network contract audit",
		"contract_id": contract_id,
		"issues": issues,
	}
	return _GF_VALIDATION_REPORT_DICTIONARY.finalize_report(report, "Network contract audit", {
		"include_issue_count": true,
		"next_actions": _get_next_actions(),
		"fallback_action": "Review the first network contract audit issue.",
		"no_action": "Network contract audit is healthy.",
	})


func _finalize_paths_report(
	contract_count: int,
	issues: Array[Dictionary]
) -> Dictionary:
	var report: Dictionary = {
		"subject": "Network contract audit",
		"contract_count": contract_count,
		"issues": issues,
	}
	return _GF_VALIDATION_REPORT_DICTIONARY.finalize_report(report, "Network contract audit", {
		"include_issue_count": true,
		"next_actions": _get_next_actions(),
		"fallback_action": "Review the first network contract audit issue.",
		"no_action": "Network contract audit is healthy.",
	})


func _get_next_actions() -> Dictionary:
	return {
		"contract_missing": "Assign a GFNetworkContract before running the audit.",
		"contract_load_failed": "Use a resource path that points to a GFNetworkContract.",
		"contract_id_missing": "Assign a stable contract_id so peers and reports can identify the protocol.",
		"contract_version_missing": "Assign contract_version_major or contract_version_minor before production use.",
		"no_messages": "Add at least one GFNetworkContractMessage to the contract.",
		"message_count_above_budget": "Split or review the contract before it becomes too broad for safe operation.",
		"message_channel_missing": "Assign channel_id or disable require_channel_ids for this audit.",
		"unknown_channel_id": "Register the channel or change the message channel_id.",
		"message_has_no_fields": "Confirm the message is intentionally payload-free or add explicit fields.",
		"field_count_above_budget": "Split the message or raise the audit budget with evidence.",
		"loose_variant_field": "Prefer a concrete GFNetworkContractField.ValueType over unrestricted Variant.",
		"collection_bounds_review_required": "Document and enforce collection size and shape limits at an executable project boundary, or disable warn_collection_bounds_review only after an independent gate exists.",
		"audit_budget_exceeded": "Reduce the configured contract paths or known channels before retrying the synchronous audit.",
		"invalid_audit_options": "Use positive integer audit budgets; caller budgets are clamped to framework hard caps.",
	}


static func _normalize_string_set(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for item: String in items:
		var normalized: String = item.strip_edges()
		if normalized.is_empty() or seen.has(normalized):
			continue
		seen[normalized] = true
		var _appended: bool = result.append(normalized)
	result.sort()
	return result
