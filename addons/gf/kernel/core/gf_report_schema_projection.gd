# 固定报告 schema 的内部投影辅助。
#
# GFReportValueCodec 会保真编码 StringName/non-String Dictionary key。对于公开契约明确声明为
# JSON object 的字段，本辅助先把单层 String/StringName key 规范化为 String，再执行一次报告编码。
# 非字符串 key、规范化冲突或超出集合预算时直接回退到 codec 的保真 marker，避免静默覆盖。
extends RefCounted


# --- 常量 ---

const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")
const _DEFAULT_MAX_COLLECTION_ITEMS: int = 1024


# --- 框架内部方法 ---

## 将固定 object schema 的 Dictionary 投影为单次编码的报告 Dictionary。
## [br]
## @api framework_internal
## [br]
## @param source: 待投影的原始 Dictionary。
## [br]
## @schema source: Dictionary；键为 String 或 StringName，值可为任意 Variant。
## [br]
## @param options: 传递给 GFReportValueCodec 的编码选项。
## [br]
## @schema options: Dictionary；字段与 GFReportValueCodec.to_report_dictionary() 的 options 一致。
## [br]
## @return 字符串键安全时返回稳定 object；否则返回保真 marker。
## [br]
## @schema return: JSON-safe Dictionary；键不安全、冲突或超预算时为 Dictionary marker。
static func to_report_dictionary(source: Dictionary, options: Dictionary = {}) -> Dictionary:
	var max_collection_items: int = _get_int_option(
		options,
		"max_collection_items",
		_DEFAULT_MAX_COLLECTION_ITEMS
	)
	if max_collection_items >= 0 and source.size() > max_collection_items:
		return _GF_REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(source, options)

	var normalized: Dictionary = {}
	for raw_key: Variant in source.keys():
		if not (raw_key is String or raw_key is StringName):
			return _GF_REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(source, options)
		var key: String = str(raw_key)
		if normalized.has(key):
			return _GF_REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(source, options)
		normalized[key] = source[raw_key]
	return _GF_REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(normalized, options)


# --- 私有/辅助方法 ---

static func _get_int_option(options: Dictionary, key: String, default_value: int) -> int:
	var value: Variant = options.get(key, default_value)
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		if is_finite(float_value):
			return int(float_value)
	return default_value
