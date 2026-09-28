## GFAssetAttributionTools: 资产授权与署名元数据工具。
##
## 提供纯数据归一、路径覆盖检查和通知文本格式化，便于项目导入管线、CI
## 或 Credits 页面复用同一套资产归因字段约定。它不内置许可证模板、不下载外部数据，
## 也不替项目做法律判断。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFAssetAttributionTools
extends RefCounted

# --- 常量 ---

## 未指定 attribution_key 时，从元数据读取归因载荷的默认键。
## [br]
## @api private
const _ATTRIBUTION_KEY: String = "attribution"

## 格式化时许可证标识为空所使用的显示文字。
## [br]
## @api private
const _UNSPECIFIED_LICENSE_LABEL: String = "Unspecified license"

## 按优先顺序查找资源路径的输入字段别名。
## [br]
## @api private
const _PATH_FIELDS: PackedStringArray = ["path", "resource_path", "source_path", "asset_path"]

## 按优先顺序查找许可证标识的输入字段别名。
## [br]
## @api private
const _LICENSE_FIELDS: PackedStringArray = ["license_id", "spdx_id", "license", "license_type"]

## 按优先顺序查找资产标题的输入字段别名。
## [br]
## @api private
const _TITLE_FIELDS: PackedStringArray = ["title", "name", "asset_name", "display_name"]

## 按优先顺序查找创作者署名的输入字段别名。
## [br]
## @api private
const _CREATOR_FIELDS: PackedStringArray = ["creator", "author", "authors", "copyright_holder"]

## 按优先顺序查找来源链接的输入字段别名。
## [br]
## @api private
const _SOURCE_URL_FIELDS: PackedStringArray = ["source_url", "origin_url", "url", "source"]

## 按优先顺序查找署名通知文本的输入字段别名。
## [br]
## @api private
const _NOTICE_FIELDS: PackedStringArray = ["notice", "attribution_notice"]

## 按优先顺序查找版权声明的输入字段别名。
## [br]
## @api private
const _COPYRIGHT_FIELDS: PackedStringArray = ["copyright", "copyright_notice"]


# --- 公共方法 ---

## 将资产归因字典归一为稳定字段。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 输入归因字典；也可传入 GFAssetMetadataRecord.to_dict() 形状的字典。
## [br]
## @schema data: Dictionary，可包含 path/resource_path/source_path、license_id/license、title/name、creator/author、source_url/source、notice、copyright、metadata 或 metadata.attribution。
## [br]
## @param options: 可选项，支持 attribution_key。
## [br]
## @schema options: Dictionary，可包含 attribution_key 字段；默认为 attribution。
## [br]
## @return 归一化归因条目。
## [br]
## @schema return: Dictionary，包含 path、license_id、title、creator、source_url、notice、copyright、metadata、subject_path 与 subject_kind 字段。
static func normalize_attribution(data: Dictionary, options: Dictionary = {}) -> Dictionary:
	var payload: Dictionary = _select_attribution_payload(data, options)
	var result: Dictionary = {
		"path": _normalize_path(_first_text(payload, _PATH_FIELDS)),
		"license_id": _first_text(payload, _LICENSE_FIELDS),
		"title": _first_text(payload, _TITLE_FIELDS),
		"creator": _first_text(payload, _CREATOR_FIELDS),
		"source_url": _first_text(payload, _SOURCE_URL_FIELDS),
		"notice": _first_text(payload, _NOTICE_FIELDS),
		"copyright": _first_text(payload, _COPYRIGHT_FIELDS),
		"metadata": GFVariantData.get_option_dictionary(payload, "metadata"),
	}
	_copy_optional_text(result, payload, "subject_path")
	_copy_optional_text(result, payload, "subject_kind")
	return result


## 按资源路径解析最匹配的归因条目。
## [br]
## 精确路径优先；inherit_from_parent 为 true 时，父目录归因可覆盖其子资源。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param path: 要解析的资源路径。
## [br]
## @param entries: 归因条目数组；每项可为 Dictionary 或 GFAssetMetadataRecord。
## [br]
## @schema entries: Array，每项可为归因 Dictionary、GFAssetMetadataRecord 或 GFAssetMetadataRecord.to_dict() 形状字典。
## [br]
## @param options: 可选项，支持 inherit_from_parent 与 attribution_key。
## [br]
## @schema options: Dictionary，可包含 inherit_from_parent 和 attribution_key。
## [br]
## @return 解析结果。
## [br]
## @schema return: Dictionary，包含 found、path、attribution_path、inherited、inherited_from 和 entry 字段。
static func resolve_attribution(path: String, entries: Array, options: Dictionary = {}) -> Dictionary:
	var normalized_entries: Array[Dictionary] = _normalize_entries(entries, options)
	return _resolve_normalized_attribution(_normalize_path(path), normalized_entries, options)


## 构建资产归因覆盖报告。
## [br]
## 传入 resource_paths 时，报告会检查每个资源路径是否能命中归因条目。
## 缺少 path、重复 path、冲突别名、无效覆盖输入、缺少 license_id 或未覆盖资源路径都会作为错误报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param entries: 归因条目数组；每项可为 Dictionary 或 GFAssetMetadataRecord。
## [br]
## @schema entries: Array，每项可为归因 Dictionary、GFAssetMetadataRecord 或 GFAssetMetadataRecord.to_dict() 形状字典。
## [br]
## @param resource_paths: 需要被归因覆盖的资源路径。
## [br]
## @schema resource_paths: PackedStringArray，通常来自资源扫描或导入计划。
## [br]
## @param options: 可选项，支持 require_license_id、inherit_from_parent 与 attribution_key。
## [br]
## @schema options: Dictionary，可包含 require_license_id、inherit_from_parent 和 attribution_key。
## [br]
## @return GFValidationReport 兼容字典，并附带 entries、covered_paths、uncovered_paths 和 license_ids。
## [br]
## @schema return: Dictionary，包含 ok、healthy、summary、entries、entry_count、resource_path_input_count、resource_path_count、valid_resource_path_count、invalid_resource_path_count、duplicate_resource_path_count、covered_paths、uncovered_paths、license_ids 等字段；resource_path_count 与 valid_resource_path_count 都表示规范化后的有效唯一资源路径数。
static func build_attribution_report(
	entries: Array,
	resource_paths: PackedStringArray = PackedStringArray(),
	options: Dictionary = {}
) -> Dictionary:
	var report: GFValidationReport = GFValidationReport.new("Asset attribution")
	var normalized_entries: Array[Dictionary] = []
	var paths_by_entry_index: Dictionary = {}
	var require_license_id: bool = GFVariantData.get_option_bool(options, "require_license_id", true)

	for index: int in range(entries.size()):
		var entry_data: Dictionary = _entry_to_data(entries[index])
		var normalized_entry: Dictionary = normalize_attribution(entry_data, options)
		normalized_entry["index"] = index
		normalized_entries.append(normalized_entry)
		_add_attribution_conflict_issues(entry_data, index, options, report)
		_validate_entry(normalized_entry, index, paths_by_entry_index, require_license_id, report)

	var normalized_path_inputs: Dictionary = _normalize_resource_path_inputs(resource_paths, report)
	var normalized_resource_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(
		normalized_path_inputs,
		"paths"
	)
	var coverage: Dictionary = _build_coverage(
		normalized_resource_paths,
		normalized_entries,
		options,
		report
	)
	var covered_paths: Array[Dictionary] = GFVariantData.get_option_array(coverage, "covered_paths")
	var uncovered_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(
		coverage,
		"uncovered_paths"
	)

	var raw_report: Dictionary = report.to_dict({
		"entry_count": normalized_entries.size(),
		"resource_path_input_count": resource_paths.size(),
		"resource_path_count": normalized_resource_paths.size(),
		"valid_resource_path_count": normalized_resource_paths.size(),
		"invalid_resource_path_count": GFVariantData.get_option_int(
			normalized_path_inputs,
			"invalid_count"
		),
		"duplicate_resource_path_count": GFVariantData.get_option_int(
			normalized_path_inputs,
			"duplicate_count"
		),
		"covered_path_count": covered_paths.size(),
		"uncovered_path_count": uncovered_paths.size(),
		"entries": normalized_entries,
		"covered_paths": covered_paths,
		"uncovered_paths": _packed_strings_to_array(uncovered_paths),
		"license_ids": _packed_strings_to_array(_collect_license_ids(normalized_entries)),
	}, _report_options())
	return GFReportValueCodec.to_report_dictionary(raw_report, _get_report_encoding_options())


## 将归因报告格式化为稳定的通知文本。
## [br]
## 该方法只输出条目摘要，不注入许可证全文；项目应自行决定最终 Credits 或 NOTICE 格式。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report: build_attribution_report() 返回的报告字典。
## [br]
## @schema report: Dictionary，包含 entries 字段的归因报告。
## [br]
## @param options: 可选项，支持 title 与 include_paths。
## [br]
## @schema options: Dictionary，可包含 title 和 include_paths。
## [br]
## @return 通知文本。
static func format_notice_text(report: Dictionary, options: Dictionary = {}) -> String:
	var entries: Array[Dictionary] = _get_report_entries(report)
	var license_ids: PackedStringArray = _collect_license_ids(entries)
	var title: String = _sanitize_single_line_text(
		GFVariantData.get_option_string(options, "title", "Third-party attributions")
	)
	var include_paths: bool = GFVariantData.get_option_bool(options, "include_paths", true)
	var lines: PackedStringArray = PackedStringArray()

	_append_line(lines, title)
	if entries.is_empty():
		return "\n".join(lines)
	if license_ids.is_empty():
		_append_unique_text(license_ids, _UNSPECIFIED_LICENSE_LABEL)

	for license_id: String in license_ids:
		_append_line(lines, "")
		_append_line(lines, license_id)
		for entry: Dictionary in entries:
			if _get_notice_license_id(entry) != license_id:
				continue
			_append_notice_entry(lines, entry, include_paths)

	return "\n".join(lines)


# --- 私有/辅助方法 ---

## 将支持的记录、字典或其他输入收窄为归因数据字典。
## [br]
## @api private
static func _entry_to_data(entry: Variant) -> Dictionary:
	if entry is GFAssetMetadataRecord:
		var record: GFAssetMetadataRecord = entry
		return record.to_dict()
	if entry is Dictionary:
		var entry_data: Dictionary = entry
		return GFVariantData.to_dictionary(entry_data)
	return {}


## 将输入条目逐项转换并归一化为字典数组。
## [br]
## @api private
static func _normalize_entries(entries: Array, options: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Variant in entries:
		result.append(normalize_attribution(_entry_to_data(entry), options))
	return result


## 从顶层、metadata 或指定 attribution 子字典中选择归因字段来源。
## [br]
## @api private
static func _select_attribution_payload(data: Dictionary, options: Dictionary) -> Dictionary:
	var payload: Dictionary = {}
	var metadata: Dictionary = GFVariantData.get_option_dictionary(data, "metadata")
	var attribution_key: String = GFVariantData.get_option_string(options, "attribution_key", _ATTRIBUTION_KEY)

	if not metadata.is_empty():
		var nested_payload: Dictionary = {}
		if not attribution_key.is_empty():
			nested_payload = GFVariantData.get_option_dictionary(metadata, attribution_key)
		if not nested_payload.is_empty():
			payload = nested_payload
		elif _has_any_known_field(metadata):
			payload = metadata

	if payload.is_empty():
		payload = GFVariantData.to_dictionary(data)
	else:
		payload = GFVariantData.to_dictionary(payload)
		_copy_missing_field(payload, metadata, "source_path")
		_copy_missing_field(payload, metadata, "subject_path")
		_copy_missing_field(payload, metadata, "subject_kind")
		_copy_missing_field(payload, data, "source_path")
		_copy_missing_field(payload, data, "subject_path")
		_copy_missing_field(payload, data, "subject_kind")

	return payload


## 检查所有归因字段别名是否声明互相冲突的规范化值。
## [br]
## @api private
static func _add_attribution_conflict_issues(
	data: Dictionary,
	index: int,
	options: Dictionary,
	report: GFValidationReport
) -> void:
	_add_attribution_field_conflict(data, index, options, "path", _PATH_FIELDS, true, report)
	_add_attribution_field_conflict(data, index, options, "license_id", _LICENSE_FIELDS, false, report)
	_add_attribution_field_conflict(data, index, options, "title", _TITLE_FIELDS, false, report)
	_add_attribution_field_conflict(data, index, options, "creator", _CREATOR_FIELDS, false, report)
	_add_attribution_field_conflict(data, index, options, "source_url", _SOURCE_URL_FIELDS, false, report)
	_add_attribution_field_conflict(data, index, options, "notice", _NOTICE_FIELDS, false, report)
	_add_attribution_field_conflict(data, index, options, "copyright", _COPYRIGHT_FIELDS, false, report)


## 收集单一字段的别名候选值，并在不同非空值并存时添加错误。
## [br]
## @api private
static func _add_attribution_field_conflict(
	data: Dictionary,
	index: int,
	options: Dictionary,
	field_name: String,
	aliases: PackedStringArray,
	normalize_as_path: bool,
	report: GFValidationReport
) -> void:
	var candidates: Array[Dictionary] = _collect_attribution_field_candidates(
		data,
		options,
		aliases,
		normalize_as_path
	)
	var distinct_values: Dictionary = {}
	var source_fields: Array[String] = []
	for candidate: Dictionary in candidates:
		var normalized_value: String = GFVariantData.get_option_string(candidate, "normalized_value")
		if normalized_value.is_empty():
			continue
		distinct_values[normalized_value] = true
		source_fields.append(GFVariantData.get_option_string(candidate, "source_field"))
	if distinct_values.size() <= 1:
		return

	var _conflict_issue: RefCounted = report.add_error(
		&"conflicting_attribution_field",
		"Attribution aliases declare conflicting normalized values.",
		index,
		"entries[%d].%s" % [index, field_name],
		{
			"index": index,
			"field_name": field_name,
			"source_fields": source_fields,
		}
	)


## 从顶层、metadata 和 attribution 子字典收集指定别名候选。
## [br]
## @api private
static func _collect_attribution_field_candidates(
	data: Dictionary,
	options: Dictionary,
	aliases: PackedStringArray,
	normalize_as_path: bool
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_append_attribution_field_candidates(result, data, "", aliases, normalize_as_path)

	var metadata: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(data, "metadata")
	)
	if metadata.is_empty():
		return result
	_append_attribution_field_candidates(result, metadata, "metadata.", aliases, normalize_as_path)

	var attribution_key: String = GFVariantData.get_option_string(
		options,
		"attribution_key",
		_ATTRIBUTION_KEY
	)
	if attribution_key.is_empty():
		return result
	var nested_payload: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(metadata, attribution_key)
	)
	if nested_payload.is_empty():
		return result
	_append_attribution_field_candidates(
		result,
		nested_payload,
		"metadata.%s." % attribution_key,
		aliases,
		normalize_as_path
	)
	return result


## 将载荷中的非空别名值格式化后追加到候选列表。
## [br]
## @api private
static func _append_attribution_field_candidates(
	result: Array[Dictionary],
	payload: Dictionary,
	prefix: String,
	aliases: PackedStringArray,
	normalize_as_path: bool
) -> void:
	for alias: String in aliases:
		if not payload.has(alias) and not payload.has(StringName(alias)):
			continue
		var text: String = _field_text(GFVariantData.get_option_value(payload, alias))
		if normalize_as_path:
			text = _normalize_path(text)
		if text.is_empty():
			continue
		result.append({
			"source_field": prefix + alias,
			"normalized_value": text,
		})


## 校验条目的路径、重复路径以及按选项要求的许可证标识。
## [br]
## @api private
static func _validate_entry(
	entry: Dictionary,
	index: int,
	paths_by_entry_index: Dictionary,
	require_license_id: bool,
	report: GFValidationReport
) -> void:
	var path: String = GFVariantData.get_option_string(entry, "path")
	var license_id: String = GFVariantData.get_option_string(entry, "license_id")
	if path.is_empty():
		var _missing_path_issue: RefCounted = report.add_error(
			&"missing_attribution_path",
			"Attribution entry is missing a resource path.",
			index,
			"entries[%d]" % index,
			_make_entry_issue_metadata(entry, index, "path")
		)
	else:
		if paths_by_entry_index.has(path):
			var _duplicate_path_issue: RefCounted = report.add_error(
				&"duplicate_attribution_path",
				"Attribution path is declared more than once.",
				path,
				path,
				{
					"first_index": GFVariantData.get_option_int(paths_by_entry_index, path),
					"duplicate_index": index,
				}
			)
		else:
			paths_by_entry_index[path] = index

	if require_license_id and license_id.is_empty():
		var issue_key: Variant = path
		if path.is_empty():
			issue_key = index
		var _missing_license_issue: RefCounted = report.add_error(
			&"missing_license_id",
			"Attribution entry is missing license_id.",
			issue_key,
			path,
			_make_entry_issue_metadata(entry, index, "license_id")
		)


## 解析每个资源路径并构建已覆盖、未覆盖列表及缺失覆盖错误。
## [br]
## @api private
static func _build_coverage(
	normalized_resource_paths: PackedStringArray,
	entries: Array[Dictionary],
	options: Dictionary,
	report: GFValidationReport
) -> Dictionary:
	var covered_paths: Array[Dictionary] = []
	var uncovered_paths: PackedStringArray = PackedStringArray()
	for resource_path: String in normalized_resource_paths:
		var resolution: Dictionary = _resolve_normalized_attribution(resource_path, entries, options)
		if GFVariantData.get_option_bool(resolution, "found"):
			covered_paths.append({
				"path": resource_path,
				"attribution_path": GFVariantData.get_option_string(resolution, "attribution_path"),
				"inherited": GFVariantData.get_option_bool(resolution, "inherited"),
				"inherited_from": GFVariantData.get_option_string(resolution, "inherited_from"),
			})
			continue

		_append_unique_text(uncovered_paths, resource_path)
		var _uncovered_issue: RefCounted = report.add_error(
			&"uncovered_resource_path",
			"Resource path has no matching attribution entry.",
			resource_path,
			resource_path
		)

	return {
		"covered_paths": covered_paths,
		"uncovered_paths": uncovered_paths,
	}


## 规范化资源路径输入、去重并报告无效值数量。
## [br]
## @api private
static func _normalize_resource_path_inputs(
	resource_paths: PackedStringArray,
	report: GFValidationReport
) -> Dictionary:
	var normalized_paths: PackedStringArray = PackedStringArray()
	var first_index_by_path: Dictionary = {}
	var invalid_count: int = 0
	var duplicate_count: int = 0

	for input_index: int in range(resource_paths.size()):
		var normalized_path: String = _normalize_path(resource_paths[input_index])
		if normalized_path.is_empty():
			invalid_count += 1
			var _invalid_path_issue: RefCounted = report.add_error(
				&"invalid_resource_path",
				"Resource path is empty after normalization.",
				input_index,
				"resource_paths[%d]" % input_index,
				{
					"input_index": input_index,
					"reason": "empty_after_normalization",
				}
			)
			continue
		if first_index_by_path.has(normalized_path):
			duplicate_count += 1
			continue
		first_index_by_path[normalized_path] = input_index
		var _path_appended: bool = normalized_paths.append(normalized_path)

	return {
		"paths": normalized_paths,
		"invalid_count": invalid_count,
		"duplicate_count": duplicate_count,
	}


## 在归一化条目中选择精确项或最长匹配父路径归因。
## [br]
## @api private
static func _resolve_normalized_attribution(
	path: String,
	entries: Array[Dictionary],
	options: Dictionary
) -> Dictionary:
	var normalized_path: String = _normalize_path(path)
	var inherit_from_parent: bool = GFVariantData.get_option_bool(options, "inherit_from_parent", true)
	var best_entry: Dictionary = {}
	var best_path: String = ""
	var best_score: int = -1
	var best_exact: bool = false

	if normalized_path.is_empty():
		return _make_empty_resolution(normalized_path)

	for entry: Dictionary in entries:
		var entry_path: String = GFVariantData.get_option_string(entry, "path")
		if entry_path.is_empty():
			continue

		var exact_match: bool = normalized_path == entry_path
		var parent_match: bool = (
			inherit_from_parent
			and not exact_match
			and GFPathTools.is_path_under_root(normalized_path, entry_path, false, false)
		)
		if not exact_match and not parent_match:
			continue

		var score: int = entry_path.length()
		if score > best_score or (exact_match and not best_exact):
			best_entry = entry
			best_path = entry_path
			best_score = score
			best_exact = exact_match

	if best_entry.is_empty():
		return _make_empty_resolution(normalized_path)

	return {
		"found": true,
		"path": normalized_path,
		"attribution_path": best_path,
		"inherited": not best_exact,
		"inherited_from": best_path if not best_exact else "",
		"entry": best_entry.duplicate(true),
	}


## 创建表示未找到归因条目的标准结果字典。
## [br]
## @api private
static func _make_empty_resolution(path: String) -> Dictionary:
	return {
		"found": false,
		"path": path,
		"attribution_path": "",
		"inherited": false,
		"inherited_from": "",
		"entry": {},
	}


## 通过资源身份工具获取规范化路径，不要求目标文件存在。
## [br]
## @api private
static func _normalize_path(path: String) -> String:
	var identity: GFResourceIdentity = GFResourceIdentity.from_path(path, &"", "", {
		"check_exists": false,
	})
	return identity.canonical_path


## 按别名顺序返回第一个非空文本值。
## [br]
## @api private
static func _first_text(data: Dictionary, keys: PackedStringArray) -> String:
	for key: String in keys:
		var value: Variant = GFVariantData.get_option_value(data, key)
		var text: String = _field_text(value)
		if not text.is_empty():
			return text
	return ""


## 将常见字符串容器或标量值转换为去空白文本。
## [br]
## @api private
static func _field_text(value: Variant) -> String:
	if value == null:
		return ""
	if value is PackedStringArray:
		var packed_strings: PackedStringArray = value
		return ", ".join(packed_strings).strip_edges()
	if value is Array:
		var parts: PackedStringArray = PackedStringArray()
		var values: Array = value
		for item: Variant in values:
			_append_unique_text(parts, GFVariantData.to_text(item).strip_edges())
		return ", ".join(parts).strip_edges()
	return GFVariantData.to_text(value).strip_edges()


## 将非空且已去首尾空白的可选文本字段写入目标字典。
## [br]
## @api private
static func _copy_optional_text(target: Dictionary, source: Dictionary, key: String) -> void:
	var text: String = GFVariantData.get_option_string(source, key).strip_edges()
	if not text.is_empty():
		target[key] = text


## 仅在目标字典缺少字段且来源包含字段时复制其值。
## [br]
## @api private
static func _copy_missing_field(target: Dictionary, source: Dictionary, key: String) -> void:
	if target.has(key) or not source.has(key):
		return
	target[key] = GFVariantData.duplicate_variant(source[key])


## 生成包含条目索引、路径和字段名的校验问题元数据。
## [br]
## @api private
static func _make_entry_issue_metadata(entry: Dictionary, index: int, field_name: String) -> Dictionary:
	return {
		"index": index,
		"path": GFVariantData.get_option_string(entry, "path"),
		"field_name": field_name,
	}


## 创建保留资源路径字段的公开报告编码与脱敏选项。
## [br]
## @api private
static func _get_report_encoding_options() -> Dictionary:
	return GFReportValueCodec.make_redaction_options(
		GFReportValueCodec.REDACTION_PROFILE_PUBLIC,
		{
			"path_redaction": "none",
			"include_resource_path": true,
		}
	)


## 将 PackedStringArray 逐项复制到 Array[String]。
## [br]
## @api private
static func _packed_strings_to_array(values: PackedStringArray) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		result.append(value)
	return result


## 检查字典是否包含任一种已知归因字段别名。
## [br]
## @api private
static func _has_any_known_field(data: Dictionary) -> bool:
	return (
		_has_any_field(data, _PATH_FIELDS)
		or _has_any_field(data, _LICENSE_FIELDS)
		or _has_any_field(data, _TITLE_FIELDS)
		or _has_any_field(data, _CREATOR_FIELDS)
		or _has_any_field(data, _SOURCE_URL_FIELDS)
		or _has_any_field(data, _NOTICE_FIELDS)
		or _has_any_field(data, _COPYRIGHT_FIELDS)
	)


## 检查字典是否包含给定别名的 String 或 StringName 键。
## [br]
## @api private
static func _has_any_field(data: Dictionary, keys: PackedStringArray) -> bool:
	for key: String in keys:
		if data.has(key) or data.has(StringName(key)):
			return true
	return false


## 从字典条目提取唯一许可证标签并排序。
## [br]
## @api private
static func _collect_license_ids(entries: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for entry_value: Variant in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		_append_unique_text(result, _get_notice_license_id(entry))
	result.sort()
	return result


## 从报告 entries 字段筛选字典并转换为标准字典副本。
## [br]
## @api private
static func _get_report_entries(report: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_value: Variant in GFVariantData.get_option_array(report, "entries"):
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		result.append(GFVariantData.to_dictionary(entry))
	return result


## 获取单行许可证标签；清理后为空时返回未指定标签。
## [br]
## @api private
static func _get_notice_license_id(entry: Dictionary) -> String:
	var license_id: String = _sanitize_single_line_text(
		GFVariantData.get_option_string(entry, "license_id")
	)
	return license_id if not license_id.is_empty() else _UNSPECIFIED_LICENSE_LABEL


## 按标题和选项追加资产行及可用的署名、来源、版权和通知字段。
## [br]
## @api private
static func _append_notice_entry(lines: PackedStringArray, entry: Dictionary, include_paths: bool) -> void:
	var title: String = _sanitize_single_line_text(GFVariantData.get_option_string(entry, "title"))
	var path: String = _sanitize_single_line_text(GFVariantData.get_option_string(entry, "path"))
	var label: String = title if not title.is_empty() else path
	if label.is_empty():
		label = "Untitled asset"
	if include_paths and not path.is_empty() and path != label:
		label += " (%s)" % path

	_append_line(lines, "- %s" % label)
	_append_optional_notice_field(lines, "Creator", GFVariantData.get_option_string(entry, "creator"))
	_append_optional_notice_field(lines, "Source", GFVariantData.get_option_string(entry, "source_url"))
	_append_optional_notice_field(lines, "Copyright", GFVariantData.get_option_string(entry, "copyright"))
	_append_multiline_notice_field(lines, "Notice", GFVariantData.get_option_string(entry, "notice"))


## 清理后仅在值非空时追加单行通知字段。
## [br]
## @api private
static func _append_optional_notice_field(lines: PackedStringArray, label: String, value: String) -> void:
	var text: String = _sanitize_single_line_text(value)
	if not text.is_empty():
		_append_line(lines, "  %s: %s" % [label, text])


## 追加已拆分和清理的通知文本，并缩进后续行。
## [br]
## @api private
static func _append_multiline_notice_field(
	lines: PackedStringArray,
	label: String,
	value: String
) -> void:
	var notice_lines: PackedStringArray = _split_sanitized_notice_lines(value)
	if notice_lines.is_empty():
		return
	_append_line(lines, "  %s: %s" % [label, notice_lines[0]])
	for line_index: int in range(1, notice_lines.size()):
		_append_line(lines, "    %s" % notice_lines[line_index])


## 统一换行符、去除首尾空白并清理各条通知文本行。
## [br]
## @api private
static func _split_sanitized_notice_lines(value: String) -> PackedStringArray:
	var normalized: String = value.replace("\r\n", "\n").replace("\r", "\n")
	normalized = normalized.replace(String.chr(0x85), "\n")
	normalized = normalized.replace(String.chr(0x2028), "\n")
	normalized = normalized.replace(String.chr(0x2029), "\n").strip_edges()
	if normalized.is_empty():
		return PackedStringArray()

	var result: PackedStringArray = PackedStringArray()
	for raw_line: String in normalized.split("\n", true):
		var _line_appended: bool = result.append(_sanitize_single_line_text(raw_line))
	return result


## 将控制字符或行分隔符折叠为空格并去除首尾空白。
## [br]
## @api private
static func _sanitize_single_line_text(value: String) -> String:
	var result: String = ""
	var separator_pending: bool = false
	for character_index: int in range(value.length()):
		var codepoint: int = value.unicode_at(character_index)
		if _is_text_control_or_line_separator(codepoint):
			separator_pending = true
			continue
		if separator_pending:
			if not result.is_empty() and not result.ends_with(" "):
				result += " "
			separator_pending = false
		result += String.chr(codepoint)
	return result.strip_edges()


## 判断码点是否为控制字符或受支持的 Unicode 行分隔符。
## [br]
## @api private
static func _is_text_control_or_line_separator(codepoint: int) -> bool:
	return (
		codepoint <= 0x1f
		or codepoint == 0x7f
		or codepoint == 0x85
		or codepoint == 0x2028
		or codepoint == 0x2029
	)


## 将一行文本追加到通知行数组。
## [br]
## @api private
static func _append_line(lines: PackedStringArray, text: String) -> void:
	var _line_appended: bool = lines.append(text)


## 去除首尾空白后，仅将非空且未出现的文本追加到数组。
## [br]
## @api private
static func _append_unique_text(values: PackedStringArray, value: String) -> void:
	var text: String = value.strip_edges()
	if text.is_empty() or values.has(text):
		return
	var _text_appended: bool = values.append(text)


## 返回归因校验报告使用的下一步建议和兜底说明。
## [br]
## @api private
static func _report_options() -> Dictionary:
	return {
		"next_actions": {
			"conflicting_attribution_field": "Remove conflicting aliases or make every alias for the field normalize to the same value.",
			"missing_attribution_path": "Add a path, resource_path, source_path, or asset_path to the attribution entry.",
			"duplicate_attribution_path": "Keep one attribution entry per normalized path.",
			"missing_license_id": "Add a project-approved license_id or relax require_license_id explicitly.",
			"invalid_resource_path": "Provide a non-empty resource path that remains valid after normalization.",
			"uncovered_resource_path": "Add an exact attribution entry or a parent directory attribution entry.",
		},
		"fallback_action": "Review the first asset attribution issue.",
		"no_action": "No action required.",
	}
