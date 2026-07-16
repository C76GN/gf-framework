## GFConfigLocalizationKeyValidationRule: 文本 key 校验规则。
##
## 用于检查配置字段中的本地化 key 是否存在于显式 key 列表或字典中。
## 非严格模式可把 Godot TranslationServer 作为弱 fallback，但不能替代显式 key catalog。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigLocalizationKeyValidationRule
extends GFConfigValidationRule


# --- 常量 ---

const _SUPPORTED_VALUES_INLINE_LIMIT: int = 32


# --- 导出变量 ---

## 空字符串是否直接视为通过。
## [br]
## @api public
@export var allow_empty: bool = true

## 显式允许的文本 key。
## [br]
## @api public
@export var known_keys: PackedStringArray = PackedStringArray()

## 可选文本字典。只检查 key 是否存在，不解释 value。
## [br]
## @api public
## [br]
## @schema text_map: Dictionary，将本地化 key 映射到项目自有文本值。
@export var text_map: Dictionary = {}

## 是否要求提供 known_keys 或 text_map 作为精确 key 来源。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var require_explicit_key_source: bool = true

## 是否在非严格模式下尝试通过 TranslationServer 判断 key。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var use_translation_server: bool = true


# --- 公共方法 ---

## 导出规则摘要。
## [br]
## @api public
## [br]
## @return 规则摘要字典。
## [br]
## @schema return: Dictionary，包含基础规则字段和本地化 key 来源设置。
func describe() -> Dictionary:
	var result: Dictionary = super.describe()
	result["allow_empty"] = allow_empty
	result["known_keys"] = known_keys.duplicate()
	result["text_map"] = text_map.duplicate(true)
	result["require_explicit_key_source"] = require_explicit_key_source
	result["use_translation_server"] = use_translation_server
	return result


# --- 可重写钩子 / 虚方法 ---

## 返回本地化 key 规则的默认稳定标识。
## [br]
## @api protected
## [br]
## @return 默认规则标识。
func _get_default_rule_id() -> StringName:
	return &"localization_key"


## 校验单个字段值是否存在于配置的文本 key 来源中。
## [br]
## @api protected
## [br]
## @param value: 待校验值。
## [br]
## @param context: 校验上下文。
## [br]
## @param report: 当前校验报告。
## [br]
## @schema value: Variant，期望为 String 或 StringName 本地化 key。
## [br]
## @schema context: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
## [br]
## @schema report: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		_add_issue(report, _make_issue_context(context, value, "String or StringName"), "localization_key_invalid_type", "文本 key 校验只支持 String 或 StringName。")
		return

	var key: String = GFVariantData.to_text(value).strip_edges()
	if key.is_empty() and allow_empty:
		return
	if _has_explicit_key_source() and _explicit_key_exists(key):
		return
	if require_explicit_key_source:
		if not _has_explicit_key_source():
			_add_issue(report, _make_issue_context(context, value, "known key source"), "localization_key_source_missing", "文本 key 严格校验需要显式 key 来源。")
			return
		_add_issue(report, _make_issue_context(context, value, "known localization key"), "localization_key_missing", "文本 key 不存在：%s。" % key)
		return
	if use_translation_server:
		var translated_text: String = TranslationServer.translate(StringName(key))
		if translated_text != key:
			return
	if not _has_explicit_key_source() and not use_translation_server:
		_add_issue(report, _make_issue_context(context, value, "known key source"), "localization_key_source_missing", "文本 key 校验缺少 key 来源。")
		return
	_add_issue(report, _make_issue_context(context, value, "known localization key"), "localization_key_missing", "文本 key 不存在：%s。" % key)


# --- 私有/辅助方法 ---

func _has_explicit_key_source() -> bool:
	return not known_keys.is_empty() or not text_map.is_empty()


func _explicit_key_exists(key: String) -> bool:
	if known_keys.has(key):
		return true
	if text_map.has(key):
		return true
	return text_map.has(StringName(key))


func _make_issue_context(context: Dictionary, value: Variant, expected_value: Variant) -> Dictionary:
	var issue_context: Dictionary = context.duplicate(true)
	issue_context["value"] = GFVariantData.duplicate_variant(value)
	issue_context["actual_value"] = GFVariantData.duplicate_variant(value)
	issue_context["expected_value"] = GFVariantData.duplicate_variant(expected_value)
	var supported_keys: PackedStringArray = _get_supported_keys()
	if supported_keys.size() <= _SUPPORTED_VALUES_INLINE_LIMIT:
		issue_context["supported_values"] = supported_keys
	else:
		var summary: Dictionary = GFReportValueCodec.make_collection_summary(supported_keys, {
			"sample_count": _SUPPORTED_VALUES_INLINE_LIMIT,
			"encode_dictionary_keys": true,
		})
		issue_context["supported_values_count"] = GFVariantData.get_option_int(summary, "count")
		issue_context["supported_values_sample"] = GFVariantData.get_option_array(summary, "sample")
		issue_context["supported_values_hash"] = GFVariantData.get_option_string(summary, "hash")
		issue_context["supported_values_truncated"] = true
	issue_context["supported_content_types"] = ["localization_key"]
	return issue_context


func _get_supported_keys() -> PackedStringArray:
	var result: PackedStringArray = known_keys.duplicate()
	for key: Variant in text_map.keys():
		var key_text: String = GFVariantData.to_text(key)
		if not key_text.is_empty() and not result.has(key_text):
			var _appended: bool = result.append(key_text)
	result.sort()
	return result
