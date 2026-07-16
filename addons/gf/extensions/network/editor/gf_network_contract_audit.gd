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


# --- 公共方法 ---

## 审计网络契约。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param contract: 网络契约。
## [br]
## @param options: 审计选项，支持 known_channel_ids、require_contract_id、require_version、require_channel_ids、warn_variant_fields、warn_unbounded_collections、max_messages 和 max_fields_per_message。
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

	issues.append_array(_copy_issues(GFVariantData.get_option_array(contract.validate_contract(), "issues"), &"definition"))
	_append_contract_policy_issues(contract, options, issues)
	_append_message_policy_issues(contract, options, issues)
	return _finalize_report(contract.contract_id, issues)


## 审计多个网络契约资源路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param contract_paths: 契约资源路径列表。
## [br]
## @param options: 审计选项。
## [br]
## @schema options: Dictionary audit options.
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, issues, issue_count, contract_count, summary, and next_action.
func audit_paths(contract_paths: PackedStringArray, options: Dictionary = {}) -> Dictionary:
	var issues: Array[Dictionary] = []
	var contract_count: int = 0
	for path: String in contract_paths:
		var normalized_path: String = path.strip_edges()
		if normalized_path.is_empty():
			continue
		var resource: Resource = ResourceLoader.load(normalized_path)
		if not (resource is GFNetworkContract):
			issues.append(_make_issue(
				"error",
				"contract_load_failed",
				"Network contract path did not load a GFNetworkContract resource.",
				{
					"path": normalized_path,
				}
			))
			continue
		var contract: GFNetworkContract = resource
		contract_count += 1
		issues.append_array(_copy_issues(GFVariantData.get_option_array(audit_contract(contract, options), "issues"), &"path_audit"))

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


# --- 私有/辅助方法 ---

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
	var warn_unbounded_collections: bool = GFVariantData.get_option_bool(options, "warn_unbounded_collections", true)
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
		_append_field_policy_issues(message_contract, warn_variant_fields, warn_unbounded_collections, issues)


func _append_field_policy_issues(
	message_contract: GFNetworkContractMessage,
	warn_variant_fields: bool,
	warn_unbounded_collections: bool,
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
		if warn_unbounded_collections and (
			field.value_type == GFNetworkContractField.ValueType.DICTIONARY
			or field.value_type == GFNetworkContractField.ValueType.ARRAY
		):
			issues.append(_make_issue("warning", "unbounded_collection_field", "Network contract collection field should document size and shape limits in metadata.", {
				"message_type": message_contract.message_type,
				"field_name": field.field_name,
			}))


func _copy_issues(source_issues: Array, phase: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue_value: Variant in source_issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if issue.is_empty():
			continue
		var copy: Dictionary = issue.duplicate(true)
		copy["phase"] = phase
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
		"unbounded_collection_field": "Document collection size and shape limits in field metadata or use typed scalar fields.",
	}


static func _normalize_string_set(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items:
		var normalized: String = item.strip_edges()
		if normalized.is_empty() or result.has(normalized):
			continue
		var _appended: bool = result.append(normalized)
	result.sort()
	return result
