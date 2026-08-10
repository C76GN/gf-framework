# Network 契约 Resource 与生成访问器共享的纯值版本校验器。
extends RefCounted


# --- 常量 ---

const _REPORT_SUBJECT: String = "Network contract version"
const _GF_VALIDATION_REPORT_DICTIONARY = preload(
	"res://addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd"
)


# --- 框架内部方法 ---

## 按同一规则比较本地与对端契约版本字典。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param local_version: 本地契约的规范版本字典。
## [br]
## @param peer_version: 对端声明的契约版本字典。
## [br]
## @param options: 严重度以及 contract ID、schema digest 校验开关。
## [br]
## @schema local_version: Dictionary with contract_id, version_major, and optional schema_digest.
## [br]
## @schema peer_version: Dictionary with contract_id, version_major, and optional schema_digest received from the peer.
## [br]
## @schema options: Dictionary with severity, require_contract_id, and require_schema_digest options.
## [br]
## @return: 规范化兼容性校验报告。
## [br]
## @schema return: Dictionary with ok, subject, contract_id, local_version, peer_version, issues, issue_count, summary, and next_action.
static func validate(
	local_version: Dictionary,
	peer_version: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var issues: Array[Dictionary] = []
	var severity: String = GFVariantData.get_option_string(options, "severity", "error")
	var require_contract_id: bool = GFVariantData.get_option_bool(
		options,
		"require_contract_id",
		true
	)
	var require_schema_digest: bool = GFVariantData.get_option_bool(
		options,
		"require_schema_digest",
		false
	)
	var contract_id: StringName = GFVariantData.get_option_string_name(
		local_version,
		"contract_id"
	)
	var local_major: int = GFVariantData.get_option_int(local_version, "version_major", -1)
	var local_digest: String = GFVariantData.get_option_string(
		local_version,
		"schema_digest"
	)
	var peer_contract_id: StringName = GFVariantData.get_option_string_name(
		peer_version,
		"contract_id"
	)

	if require_contract_id and contract_id != &"":
		if peer_contract_id == &"":
			issues.append(_make_issue(
				contract_id,
				severity,
				"contract_id_missing",
				"Peer network contract version is missing contract_id.",
				{
					"expected_value": contract_id,
					"actual_value": peer_contract_id,
				}
			))
		elif peer_contract_id != contract_id:
			issues.append(_make_issue(
				contract_id,
				severity,
				"contract_id_mismatch",
				"Peer network contract_id does not match.",
				{
					"expected_value": contract_id,
					"actual_value": peer_contract_id,
				}
			))

	if not peer_version.has("version_major") and not peer_version.has(&"version_major"):
		issues.append(_make_issue(
			contract_id,
			severity,
			"contract_version_major_missing",
			"Peer network contract version is missing version_major.",
			{
				"expected_value": local_major,
				"actual_value": null,
			}
		))
	else:
		var peer_major: int = GFVariantData.get_option_int(peer_version, "version_major", -1)
		if peer_major != local_major:
			issues.append(_make_issue(
				contract_id,
				severity,
				"contract_version_major_mismatch",
				"Peer network contract major version does not match.",
				{
					"expected_value": local_major,
					"actual_value": peer_major,
				}
			))

	if require_schema_digest:
		var peer_digest: String = GFVariantData.get_option_string(
			peer_version,
			"schema_digest"
		).strip_edges()
		if peer_digest.is_empty():
			issues.append(_make_issue(
				contract_id,
				severity,
				"contract_schema_digest_missing",
				"Peer network contract version is missing schema_digest.",
				{
					"expected_value": local_digest,
					"actual_value": peer_digest,
				}
			))
		elif local_digest.is_empty():
			issues.append(_make_issue(
				contract_id,
				severity,
				"contract_schema_digest_unavailable",
				"Local network contract schema_digest is unavailable.",
				{
					"expected_value": "non-empty schema_digest",
					"actual_value": local_digest,
				}
			))
		elif peer_digest != local_digest:
			issues.append(_make_issue(
				contract_id,
				severity,
				"contract_schema_digest_mismatch",
				"Peer network contract schema_digest does not match.",
				{
					"expected_value": local_digest,
					"actual_value": peer_digest,
				}
			))

	return _GF_VALIDATION_REPORT_DICTIONARY.finalize_report({
		"subject": _REPORT_SUBJECT,
		"contract_id": contract_id,
		"local_version": local_version.duplicate(true),
		"peer_version": peer_version.duplicate(true),
		"issues": issues,
	}, _REPORT_SUBJECT, {
		"include_issue_count": true,
		"next_actions": _get_next_actions(),
		"fallback_action": "Review the first network contract version mismatch.",
		"no_action": "Network contract version is compatible.",
	})


# --- 私有/辅助方法 ---

static func _make_issue(
	contract_id: StringName,
	severity: String,
	kind: String,
	message: String,
	fields: Dictionary
) -> Dictionary:
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"contract_id": contract_id,
		"message": message,
	}
	var _merge_result: Dictionary = GFVariantData.merge_dictionary(issue, fields, true)
	return issue


static func _get_next_actions() -> Dictionary:
	return {
		"contract_id_missing": "Send contract_id with the peer network contract version or disable require_contract_id.",
		"contract_id_mismatch": "Use the same network contract resource on both peers, or connect to the matching protocol endpoint.",
		"contract_version_major_missing": "Send version_major with the peer network contract version.",
		"contract_version_major_mismatch": "Update one side to the same compatible network contract major version.",
		"contract_schema_digest_missing": "Send schema_digest or disable require_schema_digest for this preflight.",
		"contract_schema_digest_unavailable": "Ensure the local network contract schema only uses deterministic Variant values.",
		"contract_schema_digest_mismatch": "Regenerate or sync the network contract schema before exchanging messages.",
	}
