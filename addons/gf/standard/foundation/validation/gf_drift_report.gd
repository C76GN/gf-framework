## GFDriftReport: 通用集合与目录漂移报告辅助。
##
## 用于比较两个来源中的 ID 或条目，输出 matched、missing、extra 和 stale
## 结果。它不绑定资源、配置、包或编辑器业务语义，调用方负责提供稳定 key。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 7.0.0
class_name GFDriftReport
extends RefCounted


# --- 常量 ---

## 期望来源中存在，但实际来源中缺失。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_MISSING: StringName = &"drift_missing"

## 实际来源中存在，但期望来源中不存在。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_EXTRA: StringName = &"drift_extra"

## 两个来源都存在同一 key，但条目内容不同。
## [br]
## @api public
## [br]
## @since 7.0.0
const KIND_STALE: StringName = &"drift_stale"

const _DEFAULT_SUBJECT: String = "Drift report"


# --- 公共方法 ---

## 比较两个 ID 集合。
## [br]
## 只比较 key 是否存在，不比较条目值。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param expected_ids: 期望来源 ID。
## [br]
## @param actual_ids: 实际来源 ID。
## [br]
## @param options: 报告选项，支持 subject、expected_label、actual_label、metadata、missing_severity 和 extra_severity。
## [br]
## @schema options: Dictionary controlling labels, metadata, and issue severities.
## [br]
## @return 漂移报告字典。
## [br]
## @schema return: Dictionary report payload with matched、missing、extra、stale and count fields.
static func compare_ids(
	expected_ids: PackedStringArray,
	actual_ids: PackedStringArray,
	options: Dictionary = {}
) -> Dictionary:
	var expected_entries: Dictionary = {}
	for expected_id: String in expected_ids:
		var normalized_expected_id: String = expected_id.strip_edges()
		if not normalized_expected_id.is_empty():
			expected_entries[normalized_expected_id] = true

	var actual_entries: Dictionary = {}
	for actual_id: String in actual_ids:
		var normalized_actual_id: String = actual_id.strip_edges()
		if not normalized_actual_id.is_empty():
			actual_entries[normalized_actual_id] = true

	var compare_options: Dictionary = options.duplicate(true)
	compare_options["compare_values"] = false
	return compare_entries(expected_entries, actual_entries, compare_options)


## 比较两个 key -> entry 字典。
## [br]
## 默认会比较同名 key 的值；如果只需要集合差异，可传入 `{ "compare_values": false }`。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param expected_entries: 期望来源条目。
## [br]
## @schema expected_entries: Dictionary keyed by stable entry id.
## [br]
## @param actual_entries: 实际来源条目。
## [br]
## @schema actual_entries: Dictionary keyed by stable entry id.
## [br]
## @param options: 报告选项，支持 subject、expected_label、actual_label、metadata、compare_values、include_values、numeric_epsilon、match_string_names、missing_severity、extra_severity 和 stale_severity。
## [br]
## @schema options: Dictionary controlling labels, value comparison, metadata, and issue severities.
## [br]
## @return 漂移报告字典。
## [br]
## @schema return: Dictionary report payload with matched、missing、extra、stale and count fields.
static func compare_entries(
	expected_entries: Dictionary,
	actual_entries: Dictionary,
	options: Dictionary = {}
) -> Dictionary:
	var subject: String = GFVariantData.get_option_string(options, "subject", _DEFAULT_SUBJECT)
	var expected_label: String = GFVariantData.get_option_string(options, "expected_label", "expected")
	var actual_label: String = GFVariantData.get_option_string(options, "actual_label", "actual")
	var compare_values: bool = GFVariantData.get_option_bool(options, "compare_values", true)
	var include_values: bool = GFVariantData.get_option_bool(options, "include_values", false)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(options, "metadata", {})
	var report: GFValidationReport = GFValidationReport.new(subject, metadata)

	var expected: Dictionary = _normalize_entry_keys(expected_entries)
	var actual: Dictionary = _normalize_entry_keys(actual_entries)
	var matched: PackedStringArray = PackedStringArray()
	var missing: PackedStringArray = PackedStringArray()
	var extra: PackedStringArray = PackedStringArray()
	var stale: PackedStringArray = PackedStringArray()

	for key: String in _sorted_dictionary_keys(expected):
		if not actual.has(key):
			var _append_missing: bool = missing.append(key)
			_add_drift_issue(
				report,
				GFVariantData.get_option_string(options, "missing_severity", "error"),
				KIND_MISSING,
				"%s is missing from %s." % [key, actual_label],
				key,
				{
					"expected_label": expected_label,
					"actual_label": actual_label,
				}
			)
			continue

		var expected_value: Variant = expected[key]
		var actual_value: Variant = actual[key]
		if compare_values and not _variant_values_equal(expected_value, actual_value, options):
			var _append_stale: bool = stale.append(key)
			var stale_metadata: Dictionary = {
				"expected_label": expected_label,
				"actual_label": actual_label,
			}
			if include_values:
				stale_metadata["expected"] = GFVariantData.duplicate_variant(expected_value)
				stale_metadata["actual"] = GFVariantData.duplicate_variant(actual_value)
			_add_drift_issue(
				report,
				GFVariantData.get_option_string(options, "stale_severity", "warning"),
				KIND_STALE,
				"%s differs between %s and %s." % [key, expected_label, actual_label],
				key,
				stale_metadata
			)
			continue

		var _append_matched: bool = matched.append(key)

	for key: String in _sorted_dictionary_keys(actual):
		if expected.has(key):
			continue
		var _append_extra: bool = extra.append(key)
		_add_drift_issue(
			report,
			GFVariantData.get_option_string(options, "extra_severity", "warning"),
			KIND_EXTRA,
			"%s exists only in %s." % [key, actual_label],
			key,
			{
				"expected_label": expected_label,
				"actual_label": actual_label,
			}
		)

	return report.to_dict({
		"expected_count": expected.size(),
		"actual_count": actual.size(),
		"matched_count": matched.size(),
		"missing_count": missing.size(),
		"extra_count": extra.size(),
		"stale_count": stale.size(),
		"matched": _packed_to_array(matched),
		"missing": _packed_to_array(missing),
		"extra": _packed_to_array(extra),
		"stale": _packed_to_array(stale),
	}, {
		"include_metadata": true,
		"fallback_action": "Review the reported drift before using the generated or mirrored data.",
		"no_action": "No drift found.",
	})


# --- 私有/辅助方法 ---

static func _normalize_entry_keys(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for raw_key: Variant in source.keys():
		var key: String = GFVariantData.to_text(raw_key).strip_edges()
		if key.is_empty():
			continue
		result[key] = GFVariantData.duplicate_variant(source[raw_key])
	return result


static func _add_drift_issue(
	report: GFValidationReport,
	severity: String,
	kind: StringName,
	message: String,
	key: String,
	metadata: Dictionary
) -> void:
	match severity.strip_edges().to_lower():
		"info":
			var _info_issue: RefCounted = report.add_info(kind, message, key, "", metadata)
		"warning":
			var _warning_issue: RefCounted = report.add_warning(kind, message, key, "", metadata)
		_:
			var _error_issue: RefCounted = report.add_error(kind, message, key, "", metadata)


static func _variant_values_equal(left: Variant, right: Variant, options: Dictionary) -> bool:
	return GFVariantData.values_equal(left, right, options)


static func _sorted_dictionary_keys(data: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for raw_key: Variant in data.keys():
		var _append_key: bool = result.append(GFVariantData.to_text(raw_key))
	result.sort()
	return result


static func _packed_to_array(values: PackedStringArray) -> Array:
	var result: Array = []
	for value: String in values:
		result.append(value)
	return result
