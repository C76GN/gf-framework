## GFNetworkContractMessage: 网络契约中的单个消息定义。
##
## 消息定义描述 message_type、默认通道和 payload 字段集合，可用于构造、
## 校验和生成强类型辅助函数。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNetworkContractMessage
extends Resource


# --- 常量 ---

## 生成统一验证报告字典的脚本资源。
## [br]
## @api private
## [br]
const _GF_VALIDATION_REPORT_DICTIONARY = preload("res://addons/gf/standard/foundation/validation/gf_validation_report_dictionary.gd")


# --- 导出变量 ---

## 消息类型标识。
## [br]
## @api public
@export var message_type: StringName = &""

## 编辑器展示名称。
## [br]
## @api public
@export var display_name: String = ""

## 默认逻辑通道。为空时发送时不强制通道。
## [br]
## @api public
@export var channel_id: StringName = &""

## payload 字段定义。
## [br]
## @api public
## [br]
## @schema fields: Array[GFNetworkContractField]，按声明顺序保存 payload 字段定义。
@export var fields: Array[GFNetworkContractField] = []

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存项目自定义消息元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 获取消息类型。
## [br]
## @api public
## [br]
## @return 消息类型。
func get_message_type() -> StringName:
	return message_type


## 获取展示名称。
## [br]
## @api public
## [br]
## @return 展示名称。
func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if message_type != &"":
		return String(message_type)
	return "Network Message"


## 查找字段定义。
## [br]
## @api public
## [br]
## @param target_field_name: 字段名称。
## [br]
## @return 字段定义；不存在时返回 null。
func get_field(target_field_name: StringName) -> GFNetworkContractField:
	for field: GFNetworkContractField in fields:
		if field != null and field.get_field_name() == target_field_name:
			return field
	return null


## 构建 payload 字典。
## [br]
## @api public
## [br]
## @param values: 字段值字典，可使用 StringName 或 String 作为键。
## [br]
## @param options: 可选项，支持 include_defaults。
## [br]
## @return payload 字典。
## [br]
## @schema values: Dictionary[StringName|String, Variant]，字段名到字段值的映射。
## [br]
## @schema options: Dictionary，支持 include_defaults。
## [br]
## @schema return: Dictionary[StringName, Variant]，按字段契约归一化后的 payload。
func build_payload(values: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var include_defaults: bool = GFVariantData.get_option_bool(options, "include_defaults", true)
	var payload: Dictionary = {}
	for field: GFNetworkContractField in fields:
		if field == null or field.get_field_name() == &"":
			continue

		var field_name: StringName = field.get_field_name()
		if _has_payload_key(values, field_name):
			payload[field_name] = field.normalize_value(_get_payload_value(values, field_name, null))
		elif include_defaults and field.default_value != null:
			payload[field_name] = field.get_default_value()
	return payload


## 构建 GFNetworkMessage。
## [br]
## @api public
## [br]
## @param values: 字段值字典。
## [br]
## @param options: 可选元信息，支持 sequence、tick、sender_id、channel_id。
## [br]
## @return 网络消息。
## [br]
## @schema values: Dictionary[StringName|String, Variant]，字段名到字段值的映射。
## [br]
## @schema options: Dictionary，支持 include_defaults、sequence、tick、sender_id、channel_id。
func make_message(values: Dictionary = {}, options: Dictionary = {}) -> GFNetworkMessage:
	var resolved_channel_id: StringName = channel_id
	if options.has("channel_id"):
		resolved_channel_id = GFVariantData.get_option_string_name(options, "channel_id")
	return GFNetworkMessage.new(
		message_type,
		build_payload(values, options),
		GFVariantData.get_option_int(options, "sequence"),
		GFVariantData.get_option_int(options, "tick"),
		GFVariantData.get_option_int(options, "sender_id", -1),
		resolved_channel_id
	)


## 校验消息定义是否完整。
## [br]
## @api public
## [br]
## @return 校验报告字典。
## [br]
## @schema return: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。
func validate_definition() -> Dictionary:
	var issues: Array[Dictionary] = []
	if message_type == &"":
		issues.append(_make_issue("error", "empty_message_type", "Network contract message_type is empty."))

	var seen_fields: Dictionary = {}
	for index: int in range(fields.size()):
		var field: GFNetworkContractField = fields[index]
		if field == null:
			issues.append(_make_issue("warning", "null_field", "Network contract message contains a null field.", str(index)))
			continue

		var field_report: Dictionary = field.validate_definition()
		issues.append_array(_with_message_context(GFVariantData.get_option_array(field_report, "issues")))
		var field_name: StringName = field.get_field_name()
		if field_name == &"":
			continue
		if seen_fields.has(field_name):
			issues.append(_make_issue("error", "duplicate_field_name", "Network contract field name is duplicated.", String(field_name)))
		seen_fields[field_name] = true
	return _finalize_report(issues)


## 校验 payload 是否符合字段契约。
## [br]
## @api public
## [br]
## @param payload: payload 字典。
## [br]
## @return 校验报告字典。
## [br]
## @schema payload: Dictionary[StringName|String, Variant]，待校验 payload 字段值。
## [br]
## @schema return: Dictionary，GFValidationReportDictionary 格式，包含 ok、issues、issue_count 和 next_actions。
func validate_payload(payload: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = []
	for field: GFNetworkContractField in fields:
		if field == null or field.get_field_name() == &"":
			continue

		var field_name: StringName = field.get_field_name()
		if not _has_payload_key(payload, field_name):
			if field.required:
				issues.append(_make_issue("error", "missing_required_field", "Network payload is missing a required field.", String(field_name)))
			continue

		var value: Variant = _get_payload_value(payload, field_name, null)
		var field_report: Dictionary = field.validate_value(value)
		issues.append_array(_with_message_context(GFVariantData.get_option_array(field_report, "issues")))
	return _finalize_report(issues)


## 校验 GFNetworkMessage 是否匹配该消息契约。
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
	if message.message_type != message_type:
		return _finalize_report([_make_issue("error", "message_type_mismatch", "Network message_type does not match contract.")])
	return validate_payload(message.payload)


## 描述消息契约。
## [br]
## @api public
## [br]
## @return 描述字典。
## [br]
## @schema return: Dictionary，包含 message_type、display_name、channel_id、field_count、fields、metadata。
func describe() -> Dictionary:
	var field_descriptions: Array[Dictionary] = []
	for field: GFNetworkContractField in fields:
		if field != null:
			field_descriptions.append(field.describe())
	return {
		"message_type": message_type,
		"display_name": get_display_name(),
		"channel_id": channel_id,
		"field_count": field_descriptions.size(),
		"fields": field_descriptions,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 检查 payload 是否以 StringName 或 String 形式包含字段键。
## [br]
## @api private
## [br]
func _has_payload_key(payload: Dictionary, field_name: StringName) -> bool:
	return payload.has(field_name) or payload.has(String(field_name))


## 按 StringName 或 String 字段键读取 payload，并在缺失时返回默认值。
## [br]
## @api private
## [br]
func _get_payload_value(payload: Dictionary, field_name: StringName, default_value: Variant) -> Variant:
	if payload.has(field_name):
		return payload[field_name]
	return GFVariantData.get_option_value(payload, String(field_name), default_value)


## 复制有效的问题字典并为每项补入当前 message_type。
## [br]
## @api private
## [br]
func _with_message_context(issues: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue_variant: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)
		if issue.is_empty():
			continue
		var copy: Dictionary = issue.duplicate(true)
		copy["message_type"] = message_type
		result.append(copy)
	return result


## 构造带消息类型及可选字段路径的验证问题字典。
## [br]
## @api private
## [br]
func _make_issue(severity: String, kind: String, message: String, field_name: String = "") -> Dictionary:
	var issue: Dictionary = {
		"severity": severity,
		"kind": kind,
		"message_type": message_type,
		"message": message,
	}
	if not field_name.is_empty():
		issue["field_name"] = field_name
		issue["path"] = field_name
	elif message_type != &"":
		issue["path"] = String(message_type)
	return issue


## 补齐消息字段修复建议并统一封装验证报告。
## [br]
## @api private
## [br]
func _finalize_report(issues: Array[Dictionary]) -> Dictionary:
	var report: Dictionary = {
		"subject": "Network contract message",
		"message_type": message_type,
		"issues": issues,
	}
	return _GF_VALIDATION_REPORT_DICTIONARY.finalize_report(report, "Network contract message", {
		"include_issue_count": true,
		"next_actions": _get_validation_next_actions(),
	})


## 按消息契约和字段错误类型提供修复建议文本。
## [br]
## @api private
## [br]
func _get_validation_next_actions() -> Dictionary:
	return {
		"empty_message_type": "Assign every network contract message a stable message_type.",
		"null_field": "Remove empty field slots or assign a GFNetworkContractField resource.",
		"empty_field_name": "Assign every network contract field a stable field_name.",
		"duplicate_field_name": "Make field_name unique within this network contract message.",
		"missing_required_field": "Add the required field to the payload or mark it optional.",
		"null_not_allowed": "Provide a value or allow null for this network contract field.",
		"type_mismatch": "Send a value matching the declared network contract field type.",
		"class_name_mismatch": "Send an Object or Resource matching class_name_hint.",
		"missing_message": "Pass a GFNetworkMessage before validating it.",
		"message_type_mismatch": "Validate the message against a contract with the same message_type.",
	}
