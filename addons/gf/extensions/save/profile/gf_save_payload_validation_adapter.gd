# GFSavePayloadValidationAdapter: Storage worker 诊断到 Save 校验报告的隔离适配器。
#
# Adapter 只复制稳定的结构索引和 Variant 类型信息；未知字段、原始 key、
# key 派生摘要与 payload 值永远不会进入 Save 结果。
extends RefCounted


# --- 常量 ---

const _MAX_PATH_SEGMENTS: int = 256


# --- 框架内部方法 ---

## 把 Storage worker payload 预检结果转换为标准 Save 校验报告。
## [br]
## @api framework_internal
## [br]
## @layer extensions/save
## [br]
## @since 11.0.0
## [br]
## @param worker_report: Storage worker 返回的隔离诊断。
## [br]
## @schema worker_report: Dictionary with ok, failure_kind, path_segments, variant_type, visited_values, and visited_bytes fields.
## [br]
## @param sections_entry_index: Save 文档根 Dictionary 中 sections 的结构索引。
## [br]
## @param section_ids_by_entry_index: sections Dictionary 插入顺序对应的 section ID。
## [br]
## @schema section_ids_by_entry_index: Array of StringName section IDs indexed by isolated Dictionary entry position.
## [br]
## @return 包含 failed_section_id 与 validation_report 的适配结果。
## [br]
## @schema return: Dictionary with failed_section_id and GFValidationReportDictionary-compatible validation_report.
static func adapt_for_framework(
	worker_report: Dictionary,
	sections_entry_index: int,
	section_ids_by_entry_index: Array[StringName]
) -> Dictionary:
	var path_segments: Array[Dictionary] = _sanitize_path_segments(
		GFVariantData.get_option_array(worker_report, "path_segments")
	)
	var failure_kind: StringName = _normalize_failure_kind(
		GFVariantData.get_option_string_name(
			worker_report,
			"failure_kind",
			&"payload_invalid"
		)
	)
	var variant_type: int = GFVariantData.get_option_int(
		worker_report,
		"variant_type",
		TYPE_NIL
	)
	var diagnostics: Dictionary = {
		"failure_kind": failure_kind,
		"path_segments": path_segments,
		"variant_type": variant_type,
		"variant_type_name": _get_variant_type_name(variant_type),
		"visited_values": maxi(
			GFVariantData.get_option_int(worker_report, "visited_values"),
			0
		),
		"visited_bytes": maxi(
			GFVariantData.get_option_int(worker_report, "visited_bytes"),
			0
		),
	}
	var report: Dictionary = {
		"issues": [],
		"worker_diagnostics": diagnostics,
	}
	var _issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		"error",
		&"invalid_save_payload_transfer",
		_get_failure_message(failure_kind),
		{
			"path": _format_structural_path(path_segments),
			"metadata": diagnostics,
		}
	)
	var finalized_report: Dictionary = GFValidationReportDictionary.finalize_report(
		report,
		"Save payload transfer",
		{
			"next_actions": {
				"invalid_save_payload_transfer": (
					"Convert the reported section payload to finite, acyclic, "
					+ "worker-safe Variant values within the documented budgets."
				),
			},
			"fallback_action": "Review the isolated Storage worker diagnostics.",
			"no_action": "Save payload transfer is valid.",
		}
	)
	return {
		"failed_section_id": _infer_section_id(
			path_segments,
			sections_entry_index,
			section_ids_by_entry_index
		),
		"validation_report": finalized_report,
	}


# --- 私有/辅助方法 ---

static func _sanitize_path_segments(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in source:
		if result.size() >= _MAX_PATH_SEGMENTS:
			break
		if not value is Dictionary:
			continue
		var source_segment: Dictionary = value
		var kind: String = GFVariantData.get_option_string(source_segment, "kind")
		match kind:
			"array_index":
				result.append({
					"kind": kind,
					"index": GFVariantData.get_option_int(
						source_segment,
						"index",
						-1
					),
				})

			"dictionary_key":
				result.append({
					"kind": kind,
					"entry_index": GFVariantData.get_option_int(
						source_segment,
						"entry_index",
						-1
					),
				})

			"dictionary_value":
				result.append({
					"kind": kind,
					"entry_index": GFVariantData.get_option_int(
						source_segment,
						"entry_index",
						-1
					),
				})
	return result


static func _infer_section_id(
	path_segments: Array[Dictionary],
	sections_entry_index: int,
	section_ids_by_entry_index: Array[StringName]
) -> StringName:
	if sections_entry_index < 0 or path_segments.size() < 2:
		return &""
	var root_segment: Dictionary = path_segments[0]
	var section_segment: Dictionary = path_segments[1]
	if (
		GFVariantData.get_option_string(root_segment, "kind")
			!= "dictionary_value"
		or GFVariantData.get_option_int(
			root_segment,
			"entry_index",
			-1
		) != sections_entry_index
		or GFVariantData.get_option_string(section_segment, "kind")
			!= "dictionary_value"
	):
		return &""
	var section_entry_index: int = GFVariantData.get_option_int(
		section_segment,
		"entry_index",
		-1
	)
	if (
		section_entry_index < 0
		or section_entry_index >= section_ids_by_entry_index.size()
	):
		return &""
	return section_ids_by_entry_index[section_entry_index]


static func _format_structural_path(path_segments: Array[Dictionary]) -> String:
	var result: String = "$"
	for segment: Dictionary in path_segments:
		match GFVariantData.get_option_string(segment, "kind"):
			"array_index":
				result += "[%d]" % GFVariantData.get_option_int(segment, "index")
			"dictionary_key":
				result += "{key:%d}" % GFVariantData.get_option_int(
					segment,
					"entry_index"
				)
			"dictionary_value":
				result += "{value:%d}" % GFVariantData.get_option_int(
					segment,
					"entry_index"
				)
	return result


static func _normalize_failure_kind(value: StringName) -> StringName:
	return value if value in [
		&"unsupported_variant_type",
		&"unsupported_typed_container",
		&"non_finite_number",
		&"circular_reference",
		&"depth_limit_exceeded",
		&"value_budget_exceeded",
		&"byte_budget_exceeded",
	] else &"payload_invalid"


static func _get_failure_message(failure_kind: StringName) -> String:
	match failure_kind:
		&"unsupported_variant_type":
			return "Save payload contains a Variant type that cannot cross the Storage worker boundary."
		&"unsupported_typed_container":
			return "Save payload contains typed container metadata that cannot cross the Storage worker boundary."
		&"non_finite_number":
			return "Save payload contains a non-finite numeric value."
		&"circular_reference":
			return "Save payload contains a circular Dictionary or Array reference."
		&"depth_limit_exceeded":
			return "Save payload exceeds the Storage worker depth budget."
		&"value_budget_exceeded":
			return "Save payload exceeds the Storage worker value budget."
		&"byte_budget_exceeded":
			return "Save payload exceeds the Storage worker byte budget."
		_:
			return "Save payload failed the Storage worker boundary validation."


static func _get_variant_type_name(value: int) -> String:
	if value < TYPE_NIL or value >= TYPE_MAX:
		return ""
	return type_string(value)
