## GFNetworkContract: 网络消息契约集合。
##
## 契约集合用于集中描述一组 GFNetworkMessage 的 message_type、字段和默认通道，
## 方便项目生成强类型辅助代码或在运行前校验消息结构。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNetworkContract
extends Resource


# --- 常量 ---

const _GF_VALIDATION_REPORT_DICTIONARY = preload("res://addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd")
const _SCHEMA_DESCRIPTOR_VERSION: int = 1
const _VERSION_REPORT_SUBJECT: String = "Network contract version"


# --- 导出变量 ---

## 契约稳定标识。
## [br]
## @api public
@export var contract_id: StringName = &""

## 编辑器展示名称。
## [br]
## @api public
@export var display_name: String = ""

## 契约兼容大版本。项目可在不兼容的消息结构变化时显式递增。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var contract_version_major: int = 0

## 契约兼容小版本。小版本只用于日志、排查或构建追踪，不参与默认兼容判断。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var contract_version_minor: int = 0

## 消息契约列表。
## [br]
## @api public
## [br]
## @schema messages: Array[GFNetworkContractMessage]，按声明顺序保存消息契约。
@export var messages: Array[GFNetworkContractMessage] = []

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存项目自定义契约元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取展示名称。
## [br]
## @api public
## [br]
## @return 展示名称。
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if contract_id != &"":
		return String(contract_id)
	return "Network Contract"


## 设置或替换一个消息契约。
## [br]
## @api public
## [br]
## @param message_contract: 消息契约。
func set_message_contract(message_contract: GFNetworkContractMessage) -> void:
	if message_contract == null or message_contract.message_type == &"":
		return

	for index: int in range(messages.size()):
		if messages[index] != null and messages[index].message_type == message_contract.message_type:
			messages[index] = message_contract
			return
	messages.append(message_contract)


## 获取消息契约。
## [br]
## @api public
## [br]
## @param message_type: 消息类型。
## [br]
## @return 消息契约；不存在时返回 null。
func get_message_contract(message_type: StringName) -> GFNetworkContractMessage:
	for message_contract: GFNetworkContractMessage in messages:
		if message_contract != null and message_contract.message_type == message_type:
			return message_contract
	return null


## 检查消息契约是否存在。
## [br]
## @api public
## [br]
## @param message_type: 消息类型。
## [br]
## @return 存在返回 true。
func has_message_contract(message_type: StringName) -> bool:
	return get_message_contract(message_type) != null


## 按消息契约创建 GFNetworkMessage。
## [br]
## @api public
## [br]
## @param message_type: 消息类型。
## [br]
## @param values: 字段值字典。
## [br]
## @param options: 可选元信息。
## [br]
## @return 网络消息；契约不存在时返回 null。
## [br]
## @schema values: Dictionary[StringName|String, Variant]，字段名到字段值的映射。
## [br]
## @schema options: Dictionary，支持 include_defaults、sequence、tick、sender_id、channel_id。
func make_message(message_type: StringName, values: Dictionary = {}, options: Dictionary = {}) -> GFNetworkMessage:
	var message_contract: GFNetworkContractMessage = get_message_contract(message_type)
	if message_contract == null:
		return null
	return message_contract.make_message(values, options)


## 校验网络消息是否匹配本契约集合。
## [br]
## @api public
## [br]
## @param message: 网络消息。
## [br]
## @return 校验报告字典。
## [br]
## @schema return: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。
func validate_message(message: GFNetworkMessage) -> Dictionary:
	if message == null:
		return _finalize_report([_make_issue("error", "missing_message", "Network message is null.")])

	var message_contract: GFNetworkContractMessage = get_message_contract(message.message_type)
	if message_contract == null:
		return _finalize_report([_make_issue("error", "unknown_message_type", "Network message_type is not declared by this contract.", String(message.message_type))])
	return message_contract.validate_message(message)


## 校验契约定义是否完整。
## [br]
## @api public
## [br]
## @return 校验报告字典。
## [br]
## @schema return: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。
func validate_contract() -> Dictionary:
	var issues: Array[Dictionary] = []
	if contract_id == &"":
		issues.append(_make_issue("warning", "empty_contract_id", "Network contract_id is empty."))
	if contract_version_major < 0:
		issues.append(_make_issue("error", "negative_contract_version_major", "Network contract major version must be greater than or equal to 0."))
	if contract_version_minor < 0:
		issues.append(_make_issue("error", "negative_contract_version_minor", "Network contract minor version must be greater than or equal to 0."))

	var seen_messages: Dictionary = {}
	for index: int in range(messages.size()):
		var message_contract: GFNetworkContractMessage = messages[index]
		if message_contract == null:
			issues.append(_make_issue("warning", "null_message_contract", "Network contract contains a null message.", str(index)))
			continue

		var message_report: Dictionary = message_contract.validate_definition()
		issues.append_array(GFVariantData.get_option_array(message_report, "issues"))
		if message_contract.message_type == &"":
			continue
		if seen_messages.has(message_contract.message_type):
			issues.append(_make_issue(
				"error",
				"duplicate_message_type",
				"Network contract message_type is duplicated.",
				String(message_contract.message_type)
			))
		seen_messages[message_contract.message_type] = true
	return _finalize_report(issues)


## 描述契约集合。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 描述字典。
## [br]
## @schema return: Dictionary，包含 contract_id、display_name、contract_version_major、contract_version_minor、schema_digest、message_count、messages、metadata。
func describe() -> Dictionary:
	var message_descriptions: Array[Dictionary] = []
	for message_contract: GFNetworkContractMessage in messages:
		if message_contract != null:
			message_descriptions.append(message_contract.describe())
	return {
		"contract_id": contract_id,
		"display_name": get_display_name(),
		"contract_version_major": contract_version_major,
		"contract_version_minor": contract_version_minor,
		"schema_digest": get_schema_digest(),
		"message_count": message_descriptions.size(),
		"messages": message_descriptions,
		"metadata": metadata.duplicate(true),
	}


## 导出只包含协议结构的稳定 schema 描述。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return schema 描述字典。
## [br]
## @schema return: Dictionary，包含 schema_version、contract_id 和 messages；不包含 display_name 或 metadata。
func get_schema_descriptor() -> Dictionary:
	var message_entries: Array[Dictionary] = []
	for message_contract: GFNetworkContractMessage in messages:
		if message_contract == null:
			continue
		message_entries.append(_describe_message_schema(message_contract))
	return {
		"schema_version": _SCHEMA_DESCRIPTOR_VERSION,
		"contract_id": contract_id,
		"messages": message_entries,
	}


## 计算契约 schema 描述的稳定 SHA-256。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 传给 GFDeterministicVariantSerializer.sha256() 的选项；默认允许有限浮点默认值参与摘要。
## [br]
## @return SHA-256 hex；schema 中存在不支持的 Variant 时返回空字符串。
## [br]
## @schema options: Dictionary，支持 allow_floats 和 max_depth。
func get_schema_digest(options: Dictionary = {}) -> String:
	var digest_options: Dictionary = options.duplicate(true)
	if not digest_options.has("allow_floats"):
		digest_options["allow_floats"] = true
	return GFDeterministicVariantSerializer.sha256(get_schema_descriptor(), digest_options)


## 获取可通过网络、日志或预检报告传递的契约版本字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 契约版本字典。
## [br]
## @schema return: Dictionary，包含 contract_id、version_major、version_minor、schema_descriptor_version 和 schema_digest。
func get_contract_version() -> Dictionary:
	return {
		"contract_id": contract_id,
		"version_major": contract_version_major,
		"version_minor": contract_version_minor,
		"schema_descriptor_version": _SCHEMA_DESCRIPTOR_VERSION,
		"schema_digest": get_schema_digest(),
	}


## 校验对端声明的契约版本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param peer_version: 对端通过 get_contract_version() 或等价结构上报的版本字典。
## [br]
## @param options: 校验选项，支持 require_contract_id、require_schema_digest 和 severity。
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema peer_version: Dictionary，包含 contract_id、version_major、version_minor 和 schema_digest。
## [br]
## @schema options: Dictionary，require_contract_id 默认 true，require_schema_digest 默认 false，severity 默认为 error。
## [br]
## @schema return: Dictionary，包含 ok、local_version、peer_version、issues、issue_count 和 next_actions。
func validate_peer_contract_version(peer_version: Dictionary, options: Dictionary = {}) -> Dictionary:
	var issues: Array[Dictionary] = []
	var severity: String = GFVariantData.get_option_string(options, "severity", "error")
	var require_contract_id: bool = GFVariantData.get_option_bool(options, "require_contract_id", true)
	var require_schema_digest: bool = GFVariantData.get_option_bool(options, "require_schema_digest", false)
	var peer_contract_id: StringName = GFVariantData.get_option_string_name(peer_version, "contract_id")

	if require_contract_id and contract_id != &"":
		if peer_contract_id == &"":
			issues.append(_make_version_issue(severity, "contract_id_missing", "Peer network contract version is missing contract_id.", {
				"expected_value": contract_id,
				"actual_value": peer_contract_id,
			}))
		elif peer_contract_id != contract_id:
			issues.append(_make_version_issue(severity, "contract_id_mismatch", "Peer network contract_id does not match.", {
				"expected_value": contract_id,
				"actual_value": peer_contract_id,
			}))

	if not peer_version.has("version_major"):
		issues.append(_make_version_issue(severity, "contract_version_major_missing", "Peer network contract version is missing version_major.", {
			"expected_value": contract_version_major,
			"actual_value": null,
		}))
	else:
		var peer_major: int = GFVariantData.get_option_int(peer_version, "version_major", -1)
		if peer_major != contract_version_major:
			issues.append(_make_version_issue(severity, "contract_version_major_mismatch", "Peer network contract major version does not match.", {
				"expected_value": contract_version_major,
				"actual_value": peer_major,
			}))

	if require_schema_digest:
		var local_digest: String = get_schema_digest()
		var peer_digest: String = GFVariantData.get_option_string(peer_version, "schema_digest").strip_edges()
		if peer_digest.is_empty():
			issues.append(_make_version_issue(severity, "contract_schema_digest_missing", "Peer network contract version is missing schema_digest.", {
				"expected_value": local_digest,
				"actual_value": peer_digest,
			}))
		elif local_digest.is_empty():
			issues.append(_make_version_issue(severity, "contract_schema_digest_unavailable", "Local network contract schema_digest is unavailable.", {
				"expected_value": "non-empty schema_digest",
				"actual_value": local_digest,
			}))
		elif peer_digest != local_digest:
			issues.append(_make_version_issue(severity, "contract_schema_digest_mismatch", "Peer network contract schema_digest does not match.", {
				"expected_value": local_digest,
				"actual_value": peer_digest,
			}))

	var report: Dictionary = {
		"subject": _VERSION_REPORT_SUBJECT,
		"contract_id": contract_id,
		"local_version": get_contract_version(),
		"peer_version": peer_version.duplicate(true),
		"issues": issues,
	}
	return _GF_VALIDATION_REPORT_DICTIONARY.finalize_report(report, _VERSION_REPORT_SUBJECT, {
		"include_issue_count": true,
		"next_actions": _get_version_next_actions(),
		"fallback_action": "Review the first network contract version mismatch.",
		"no_action": "Network contract version is compatible.",
	})


# --- 私有/辅助方法 ---

func _make_issue(severity: String, kind: String, message: String, key: String = "") -> Dictionary:
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"contract_id": contract_id,
		"message": message,
	}
	if not key.is_empty():
		issue["key"] = key
		issue["path"] = key
	elif contract_id != &"":
		issue["path"] = String(contract_id)
	return issue


func _make_version_issue(severity: String, kind: String, message: String, fields: Dictionary) -> Dictionary:
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"contract_id": contract_id,
		"message": message,
	}
	var _merge_result: Dictionary = GFVariantData.merge_dictionary(issue, fields, true)
	return issue


func _describe_message_schema(message_contract: GFNetworkContractMessage) -> Dictionary:
	var field_entries: Array[Dictionary] = []
	for field: GFNetworkContractField in message_contract.fields:
		if field == null:
			continue
		field_entries.append(_describe_field_schema(field))
	return {
		"message_type": message_contract.message_type,
		"channel_id": message_contract.channel_id,
		"fields": field_entries,
	}


func _describe_field_schema(field: GFNetworkContractField) -> Dictionary:
	return {
		"field_name": field.field_name,
		"value_type": int(field.value_type),
		"required": field.required,
		"allow_null": field.allow_null,
		"default_value": field.get_default_value(),
		"class_name_hint": field.class_name_hint,
	}


func _finalize_report(issues: Array[Dictionary]) -> Dictionary:
	var report: Dictionary = {
		"subject": "Network contract",
		"contract_id": contract_id,
		"issues": issues,
	}
	return _GF_VALIDATION_REPORT_DICTIONARY.finalize_report(report, "Network contract", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions(),
	})


func _get_validation_next_actions() -> Dictionary:
	return {
		"missing_message": "Pass a GFNetworkMessage before validating it.",
		"unknown_message_type": "Declare the message_type in this network contract before validating the message.",
		"empty_contract_id": "Assign the network contract a stable contract_id.",
		"negative_contract_version_major": "Set contract_version_major to 0 or a positive integer.",
		"negative_contract_version_minor": "Set contract_version_minor to 0 or a positive integer.",
		"null_message_contract": "Remove empty message slots or assign a GFNetworkContractMessage resource.",
		"empty_message_type": "Assign every network contract message a stable message_type.",
		"duplicate_message_type": "Make message_type unique within this network contract.",
		"null_field": "Remove empty field slots or assign a GFNetworkContractField resource.",
		"empty_field_name": "Assign every network contract field a stable field_name.",
		"duplicate_field_name": "Make field_name unique within its network contract message.",
		"missing_required_field": "Add the required field to the payload or mark it optional.",
		"null_not_allowed": "Provide a value or allow null for this network contract field.",
		"type_mismatch": "Send a value matching the declared network contract field type.",
		"class_name_mismatch": "Send an Object or Resource matching class_name_hint.",
		"message_type_mismatch": "Validate the message against a contract with the same message_type.",
	}


func _get_version_next_actions() -> Dictionary:
	return {
		"contract_id_missing": "Send contract_id with the peer network contract version or disable require_contract_id.",
		"contract_id_mismatch": "Use the same network contract resource on both peers, or connect to the matching protocol endpoint.",
		"contract_version_major_missing": "Send version_major with the peer network contract version.",
		"contract_version_major_mismatch": "Update one side to the same compatible network contract major version.",
		"contract_schema_digest_missing": "Send schema_digest or disable require_schema_digest for this preflight.",
		"contract_schema_digest_unavailable": "Ensure the local network contract schema only uses deterministic Variant values.",
		"contract_schema_digest_mismatch": "Regenerate or sync the network contract schema before exchanging messages.",
	}
