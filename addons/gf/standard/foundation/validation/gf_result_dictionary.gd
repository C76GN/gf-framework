## GFResultDictionary: 通用结果字典常量、归一化与轻量工厂。
##
## 用于统一 `ok`、`reason`、`message`、`data`、`metadata`、`issues` 等常见结果字段。
## 普通操作结果应使用该结构；需要严重级别、统计和下一步建议时再使用校验报告。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFResultDictionary
extends RefCounted


# --- 常量 ---

## 操作是否成功字段名。
## [br]
## @api public
const KEY_OK: String = "ok"

## 结果数据字段名。
## [br]
## @api public
const KEY_DATA: String = "data"

## 元数据字段名。
## [br]
## @api public
const KEY_METADATA: String = "metadata"

## 机器可读原因字段名。
## [br]
## @api public
const KEY_REASON: String = "reason"

## 人类可读说明字段名。
## [br]
## @api public
const KEY_MESSAGE: String = "message"

## 单个错误字段名。
## [br]
## @api public
const KEY_ERROR: String = "error"

## 多个错误字段名。
## [br]
## @api public
const KEY_ERRORS: String = "errors"

## 问题列表字段名。
## [br]
## @api public
const KEY_ISSUES: String = "issues"

## 问题总数字段名。
## [br]
## @api public
const KEY_ISSUE_COUNT: String = "issue_count"

## 健康状态字段名。
## [br]
## @api public
const KEY_HEALTHY: String = "healthy"

## 摘要字段名。
## [br]
## @api public
const KEY_SUMMARY: String = "summary"

## 下一步建议字段名。
## [br]
## @api public
const KEY_NEXT_ACTION: String = "next_action"

## 完整性校验结果字段名。
## [br]
## @api public
const KEY_INTEGRITY_VALID: String = "integrity_valid"


# --- 公共方法 ---

## 创建结果字典，并写入 ok 字段。
## [br]
## @api public
## [br]
## @param ok: 操作是否成功。
## [br]
## @param fields: 需要合并到结果中的附加字段。
## [br]
## @return 新结果字典。
## [br]
## @schema fields: Dictionary fields copied into the result.
## [br]
## @schema return: Dictionary with ok plus caller-provided fields.
static func make(ok: bool, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = fields.duplicate(true)
	result[KEY_OK] = ok
	return result


## 创建成功结果字典。
## [br]
## @api public
## [br]
## @param fields: 需要合并到结果中的附加字段。
## [br]
## @return 新结果字典。
## [br]
## @schema fields: Dictionary fields copied into the result.
## [br]
## @schema return: Dictionary with ok set to true plus caller-provided fields.
static func make_success(fields: Dictionary = {}) -> Dictionary:
	return make(true, fields)


## 创建失败结果字典，并写入 reason、message 和 error 字段。
## [br]
## @api public
## [br]
## @param error: 错误说明。该值会同时作为默认 reason 与 message，便于结果结构稳定读取。
## [br]
## @param fields: 需要合并到结果中的附加字段。
## [br]
## @return 新结果字典。
## [br]
## @schema fields: Dictionary fields copied into the result.
## [br]
## @schema return: Dictionary with ok set to false, reason, message, error, and caller-provided fields.
static func make_failure(error: String = "", fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = make(false, fields)
	result[KEY_ERROR] = error
	if not result.has(KEY_REASON):
		result[KEY_REASON] = error
	if not result.has(KEY_MESSAGE):
		result[KEY_MESSAGE] = error
	return result


## 创建带机器可读原因和人类可读说明的失败结果。
## [br]
## @api public
## [br]
## @since 3.22.0
## [br]
## @param reason: 稳定失败原因，推荐使用 snake_case。
## [br]
## @param message: 面向开发者或工具 UI 的说明；为空时使用 reason。
## [br]
## @param fields: 需要合并到结果中的附加字段。
## [br]
## @return 新结果字典。
## [br]
## @schema fields: Dictionary fields copied into the result.
## [br]
## @schema return: Dictionary with ok set to false, reason, message, and caller-provided fields.
static func make_rejected(
	reason: StringName,
	message: String = "",
	fields: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = make(false, fields)
	var reason_text: String = String(reason)
	var message_text: String = message if not message.is_empty() else reason_text
	result[KEY_REASON] = reason_text
	result[KEY_MESSAGE] = message_text
	if not result.has(KEY_ERROR):
		result[KEY_ERROR] = message_text
	return result


## 创建带 issues 的结果字典。
## [br]
## @api public
## [br]
## @since 3.22.0
## [br]
## @param ok: 操作是否成功。
## [br]
## @param issues: 问题数组。
## [br]
## @param fields: 需要合并到结果中的附加字段。
## [br]
## @return 新结果字典。
## [br]
## @schema issues: Array of caller-defined issue dictionaries or values.
## [br]
## @schema fields: Dictionary fields copied into the result.
## [br]
## @schema return: Dictionary with ok, issues, issue_count, healthy, and caller-provided fields.
static func make_with_issues(
	ok: bool,
	issues: Array = [],
	fields: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = make(ok, fields)
	result[KEY_ISSUES] = issues.duplicate(true)
	result[KEY_ISSUE_COUNT] = issues.size()
	if not result.has(KEY_HEALTHY):
		result[KEY_HEALTHY] = ok and issues.is_empty()
	return result


## 归一化已有结果字典，补齐标准字段并返回副本。
## [br]
## @api public
## [br]
## @since 3.22.0
## [br]
## @param result: 输入结果字典。
## [br]
## @param default_ok: 缺少 ok 字段时使用的默认值。
## [br]
## @param options: 可选控制，支持 include_issue_count、include_healthy、default_reason、default_message。
## [br]
## @return 归一化后的结果副本。
## [br]
## @schema result: Dictionary result payload.
## [br]
## @schema options: Dictionary controlling normalization.
## [br]
## @schema return: Dictionary normalized result payload.
static func normalize(
	result: Dictionary,
	default_ok: bool = false,
	options: Dictionary = {}
) -> Dictionary:
	var normalized: Dictionary = result.duplicate(true)
	normalized[KEY_OK] = GFVariantData.get_option_bool(
		normalized,
		KEY_OK,
		default_ok
	)

	var metadata_variant: Variant = GFVariantData.get_option_value(normalized, KEY_METADATA)
	if metadata_variant is Dictionary:
		var metadata_value: Dictionary = GFVariantData.as_dictionary(metadata_variant)
		normalized[KEY_METADATA] = metadata_value.duplicate(true)
	elif not normalized.has(KEY_METADATA):
		normalized[KEY_METADATA] = {}

	var reason_text: String = GFVariantData.to_text(
		GFVariantData.get_option_value(
			normalized,
			KEY_REASON,
			GFVariantData.get_option_string(options, "default_reason")
		)
	)
	if reason_text.is_empty() and normalized.has(KEY_ERROR):
		reason_text = GFVariantData.to_text(normalized[KEY_ERROR])
	if not reason_text.is_empty() or not GFVariantData.to_bool(normalized[KEY_OK]):
		normalized[KEY_REASON] = reason_text

	var message_text: String = GFVariantData.to_text(
		GFVariantData.get_option_value(
			normalized,
			KEY_MESSAGE,
			GFVariantData.get_option_string(options, "default_message")
		)
	)
	if message_text.is_empty() and normalized.has(KEY_ERROR):
		message_text = GFVariantData.to_text(normalized[KEY_ERROR])
	if message_text.is_empty():
		message_text = reason_text
	if not message_text.is_empty() or not GFVariantData.to_bool(normalized[KEY_OK]):
		normalized[KEY_MESSAGE] = message_text

	var issues_variant: Variant = GFVariantData.get_option_value(normalized, KEY_ISSUES)
	if issues_variant is Array:
		var issues: Array = GFVariantData.as_array(issues_variant)
		normalized[KEY_ISSUES] = issues.duplicate(true)
		if GFVariantData.get_option_bool(
			options,
			"include_issue_count",
			true
		):
			normalized[KEY_ISSUE_COUNT] = issues.size()
	elif GFVariantData.get_option_bool(
		options,
		"include_issue_count",
		false
	):
		normalized[KEY_ISSUE_COUNT] = 0

	if GFVariantData.get_option_bool(
		options,
		"include_healthy",
		normalized.has(KEY_HEALTHY)
	):
		var issue_count: int = GFVariantData.get_option_int(
			normalized,
			KEY_ISSUE_COUNT,
			0
		)
		normalized[KEY_HEALTHY] = GFVariantData.to_bool(normalized[KEY_OK]) and issue_count == 0
	return normalized


## 检查结果字典是否成功。
## [br]
## @api public
## [br]
## @param result: 输入结果字典。
## [br]
## @param default_value: 缺少 ok 字段时的默认值。
## [br]
## @return 成功时返回 true。
## [br]
## @schema result: Dictionary result payload.
static func is_ok(result: Dictionary, default_value: bool = false) -> bool:
	return GFVariantData.get_option_bool(
		result,
		KEY_OK,
		default_value
	)


## 合并元数据到结果字典并返回同一个字典。
## [br]
## @api public
## [br]
## @since 3.22.0
## [br]
## @param result: 目标结果字典。
## [br]
## @param metadata: 要合并的元数据。
## [br]
## @param overwrite: 为 true 时覆盖已有键。
## [br]
## @return 传入的 result。
## [br]
## @schema result: Dictionary result payload mutated in place.
## [br]
## @schema metadata: Dictionary metadata payload.
## [br]
## @schema return: Dictionary result payload mutated in place.
static func merge_metadata(
	result: Dictionary,
	metadata: Dictionary,
	overwrite: bool = true
) -> Dictionary:
	if not (GFVariantData.get_option_value(result, KEY_METADATA) is Dictionary):
		result[KEY_METADATA] = {}
	var result_metadata: Dictionary = result[KEY_METADATA]
	var _merged_metadata: Dictionary = GFVariantData.merge_metadata(
		result_metadata,
		metadata,
		overwrite
	)
	return result


# --- 私有/辅助方法 ---
