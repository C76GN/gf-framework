## GFResourceFeatureRemapTools: 资源 feature 重映射计划工具。
##
## 根据调用方提供的 feature 集合与 remap 声明，生成纯数据解析计划。
## 它不读取 ProjectSettings、不注册导出插件、不写文件，也不决定平台策略；
## 编辑器导出、资源打包或项目 Installer 可在审查计划后自行执行替换。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.1.0
class_name GFResourceFeatureRemapTools
extends RefCounted


# --- 公共方法 ---

## 归一化资源 feature 重映射声明。
##
## 支持 `Dictionary[source_path] = entries` 或条目数组。每个 entry 可为
## `[feature, target_path]`、`PackedStringArray([feature, target_path])`，
## 或包含 `feature` / `features` 与 `target_path` / `path` / `remap_path` 的 Dictionary；
## source 值也可直接使用单条 `[feature, target_path]` 简写。
## [br]
## @api public
## [br]
## @since 6.1.0
## [br]
## @param remaps: 待归一化的 remap 声明。
## [br]
## @param options: 可选项，支持 keep_invalid_entries。
## [br]
## @return 归一化报告。
## [br]
## @schema remaps: Dictionary 或 Array 形式的资源 feature remap 声明。
## [br]
## @schema options: Dictionary，可包含 keep_invalid_entries 字段。
## [br]
## @schema return: Dictionary，包含 ok、remaps、sources、issues、source_count、entry_count、issue_count、error_count、warning_count 与 summary 字段。
static func normalize_remaps(remaps: Variant, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_normalize_report()
	if remaps is Dictionary:
		var remap_dictionary: Dictionary = remaps
		_normalize_dictionary_remaps(remap_dictionary, options, report)
	elif remaps is Array:
		var remap_array: Array = remaps
		_normalize_array_remaps(remap_array, options, report)
	else:
		_append_issue(
			report,
			"error",
			"invalid_remaps_payload",
			"",
			"",
			-1,
			"Resource feature remaps must be a Dictionary or Array."
		)
	return _finalize_normalize_report(report)


## 为单个资源路径选择第一个命中的 feature 重映射。
##
## entry 顺序就是优先级；当多个 active feature 同时命中时，返回声明中最靠前的 entry。
## 未命中时 `selected=false`，`resolved_path` 保持为原始路径。
## [br]
## @api public
## [br]
## @since 6.1.0
## [br]
## @param path: 待解析的原始资源路径。
## [br]
## @param remaps: 资源 feature remap 声明。
## [br]
## @param active_features: 当前启用的 feature 集合。
## [br]
## @param options: 传给 normalize_remaps() 的可选项。
## [br]
## @return 路径解析报告。
## [br]
## @schema remaps: Dictionary 或 Array 形式的资源 feature remap 声明。
## [br]
## @schema options: Dictionary，可包含 keep_invalid_entries 字段。
## [br]
## @schema return: Dictionary，包含 ok、selected、source_path、target_path、resolved_path、feature、entry、entry_index、issues 与计数字段。
static func select_remap_for_path(
	path: String,
	remaps: Variant,
	active_features: PackedStringArray,
	options: Dictionary = {}
) -> Dictionary:
	var normalized: Dictionary = normalize_remaps(remaps, options)
	var report: Dictionary = _make_selection_report(path, normalized)
	var source_path: String = _normalize_path(path)
	if source_path.is_empty():
		_append_issue(
			report,
			"error",
			"empty_source_path",
			"",
			"",
			-1,
			"Source path is empty."
		)
		return _finalize_selection_report(report)

	var normalized_remaps: Dictionary = GFVariantData.get_option_dictionary(normalized, "remaps")
	var entries: Array = GFVariantData.get_option_array(normalized_remaps, source_path)
	var active_set: Dictionary = _make_feature_set(active_features)
	var selected_entry: Dictionary = _select_entry(entries, active_set)
	if selected_entry.is_empty():
		report["resolved_path"] = source_path
		return _finalize_selection_report(report)

	var target_path: String = GFVariantData.get_option_string(selected_entry, "target_path")
	report["selected"] = true
	report["target_path"] = target_path
	report["resolved_path"] = target_path
	report["feature"] = GFVariantData.get_option_string(selected_entry, "feature")
	report["entry"] = selected_entry
	report["entry_index"] = GFVariantData.get_option_int(selected_entry, "entry_index", -1)
	return _finalize_selection_report(report)


## 生成一组资源 feature 重映射的执行计划。
##
## 计划报告只描述 source 到 target 的选择结果、未命中 source，以及可由外层工具跳过的
## unused target 路径；调用方仍需自行决定如何替换 Resource、原始文件或导出包内容。
## [br]
## @api public
## [br]
## @since 6.1.0
## [br]
## @param remaps: 资源 feature remap 声明。
## [br]
## @param active_features: 当前启用的 feature 集合。
## [br]
## @param options: 可选项，支持 keep_invalid_entries、resource_extensions、exported_paths、protected_paths、protect_original_paths、protect_selected_targets、skip_unused_targets 与 include_unmatched。
## [br]
## @return 重映射计划报告。
## [br]
## @schema remaps: Dictionary 或 Array 形式的资源 feature remap 声明。
## [br]
## @schema options: Dictionary，可包含归一化、资源扩展名、导出路径和 skip 保护选项。
## [br]
## @schema return: Dictionary，包含 ok、active_features、selected_targets、resolved、unmatched、skip_paths、issues 与计数字段。
static func build_remap_plan(
	remaps: Variant,
	active_features: PackedStringArray,
	options: Dictionary = {}
) -> Dictionary:
	var normalized: Dictionary = normalize_remaps(remaps, options)
	var plan: Dictionary = _make_plan_report(active_features, normalized)
	var normalized_remaps: Dictionary = GFVariantData.get_option_dictionary(normalized, "remaps")
	var active_set: Dictionary = _make_feature_set(active_features)
	var extensions: PackedStringArray = GFVariantData.get_option_packed_string_array(
		options,
		"resource_extensions",
		GFResourceRegistryTools.RESOURCE_EXTENSIONS
	)
	var source_paths: PackedStringArray = _get_sorted_keys(normalized_remaps)
	var source_path_set: Dictionary = _make_string_set(source_paths)
	var selected_target_set: Dictionary = {}
	var all_target_set: Dictionary = {}
	var selected_targets: Dictionary = {}
	var resolved: Array = []
	var unmatched: Array = []

	for source_path: String in source_paths:
		var entries: Array = GFVariantData.get_option_array(normalized_remaps, source_path)
		for entry_value: Variant in entries:
			var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
			var target_path: String = GFVariantData.get_option_string(entry, "target_path")
			if not target_path.is_empty():
				all_target_set[target_path] = true

		var selected_entry: Dictionary = _select_entry(entries, active_set)
		if selected_entry.is_empty():
			if GFVariantData.get_option_bool(options, "include_unmatched", true):
				unmatched.append(_make_unmatched_record(source_path, entries, extensions))
			continue

		var selected_target: String = GFVariantData.get_option_string(selected_entry, "target_path")
		selected_targets[source_path] = selected_target
		selected_target_set[selected_target] = true
		resolved.append(_make_resolved_record(source_path, selected_entry, extensions))

	plan["selected_targets"] = selected_targets
	plan["resolved"] = resolved
	plan["unmatched"] = unmatched
	if GFVariantData.get_option_bool(options, "skip_unused_targets", true):
		plan["skip_paths"] = _make_skip_paths(all_target_set, source_path_set, selected_target_set, options)
	return _finalize_plan_report(plan)


# --- 私有/辅助方法 ---

static func _make_normalize_report() -> Dictionary:
	return {
		"ok": true,
		"remaps": {},
		"sources": PackedStringArray(),
		"issues": [],
		"source_count": 0,
		"entry_count": 0,
		"issue_count": 0,
		"error_count": 0,
		"warning_count": 0,
		"summary": "",
	}


static func _make_selection_report(path: String, normalized: Dictionary) -> Dictionary:
	return {
		"ok": GFVariantData.get_option_bool(normalized, "ok", true),
		"selected": false,
		"source_path": _normalize_path(path),
		"target_path": "",
		"resolved_path": _normalize_path(path),
		"feature": "",
		"entry": {},
		"entry_index": -1,
		"issues": GFVariantData.duplicate_collection(GFVariantData.get_option_array(normalized, "issues")),
		"issue_count": 0,
		"error_count": 0,
		"warning_count": 0,
		"summary": "",
	}


static func _make_plan_report(active_features: PackedStringArray, normalized: Dictionary) -> Dictionary:
	return {
		"ok": GFVariantData.get_option_bool(normalized, "ok", true),
		"active_features": _normalize_feature_list(active_features),
		"selected_targets": {},
		"resolved": [],
		"unmatched": [],
		"skip_paths": PackedStringArray(),
		"issues": GFVariantData.duplicate_collection(GFVariantData.get_option_array(normalized, "issues")),
		"source_count": GFVariantData.get_option_int(normalized, "source_count"),
		"entry_count": GFVariantData.get_option_int(normalized, "entry_count"),
		"selected_count": 0,
		"unmatched_count": 0,
		"skip_count": 0,
		"resource_remap_count": 0,
		"raw_file_remap_count": 0,
		"issue_count": 0,
		"error_count": 0,
		"warning_count": 0,
		"summary": "",
	}


static func _normalize_dictionary_remaps(remaps: Dictionary, options: Dictionary, report: Dictionary) -> void:
	for source_key: Variant in remaps.keys():
		_normalize_source_entries(GFVariantData.to_text(source_key), remaps[source_key], options, report)


static func _normalize_array_remaps(remaps: Array, options: Dictionary, report: Dictionary) -> void:
	for index: int in range(remaps.size()):
		var record: Dictionary = GFVariantData.as_dictionary(remaps[index])
		if record.is_empty():
			_append_issue(
				report,
				"error",
				"invalid_remap_record",
				"",
				"",
				index,
				"Remap array entries must be dictionaries with a source path."
			)
			continue
		var source_path: String = _extract_source_path(record)
		if record.has("entries"):
			_normalize_source_entries(source_path, record["entries"], options, report)
		else:
			_normalize_source_entries(source_path, [record], options, report)


static func _normalize_source_entries(
	source_path_value: String,
	entries_payload: Variant,
	options: Dictionary,
	report: Dictionary
) -> void:
	var source_path: String = _normalize_path(source_path_value)
	if source_path.is_empty():
		_append_issue(
			report,
			"error",
			"empty_source_path",
			"",
			"",
			-1,
			"Remap source path is empty."
		)
		return

	var entries: Array = _extract_entry_payloads(entries_payload)
	if entries.is_empty():
		_append_issue(
			report,
			"error",
			"empty_remap_entries",
			source_path,
			"",
			-1,
			"Remap source has no entries."
		)
		_ensure_source(report, source_path)
		return

	_ensure_source(report, source_path)
	for entry_index: int in range(entries.size()):
		_normalize_entry(source_path, entries[entry_index], entry_index, options, report)


static func _normalize_entry(
	source_path: String,
	entry_payload: Variant,
	entry_index: int,
	options: Dictionary,
	report: Dictionary
) -> void:
	var features: PackedStringArray = PackedStringArray()
	var target_path: String = ""
	var metadata: Dictionary = {}
	var priority: int = entry_index

	if entry_payload is Dictionary:
		var entry: Dictionary = entry_payload
		features = _extract_entry_features(entry)
		target_path = _extract_target_path(entry)
		metadata = GFVariantData.get_option_dictionary(entry, "metadata")
		priority = GFVariantData.get_option_int(entry, "priority", entry_index)
	elif entry_payload is Array or entry_payload is PackedStringArray:
		var values: Array = _packed_or_array_to_array(entry_payload)
		if values.size() >= 2:
			var _feature_appended: bool = features.append(_normalize_feature(GFVariantData.to_text(values[0])))
			target_path = _normalize_path(GFVariantData.to_text(values[1]))
		if values.size() >= 3:
			metadata = GFVariantData.as_dictionary(values[2])
	else:
		_append_issue(
			report,
			"error",
			"invalid_entry_payload",
			source_path,
			"",
			entry_index,
			"Remap entry must be an Array, PackedStringArray, or Dictionary."
		)
		if GFVariantData.get_option_bool(options, "keep_invalid_entries", false):
			_append_normalized_entry(report, source_path, _make_invalid_entry(source_path, entry_index, entry_payload))
		return

	target_path = _normalize_path(target_path)
	if target_path.is_empty():
		_append_issue(
			report,
			"error",
			"empty_target_path",
			source_path,
			"",
			entry_index,
			"Remap target path is empty."
		)
		if not GFVariantData.get_option_bool(options, "keep_invalid_entries", false):
			return

	if features.is_empty() or _all_features_empty(features):
		_append_issue(
			report,
			"error",
			"empty_feature",
			source_path,
			target_path,
			entry_index,
			"Remap entry feature is empty."
		)
		if not GFVariantData.get_option_bool(options, "keep_invalid_entries", false):
			return

	for feature: String in features:
		var normalized_feature: String = _normalize_feature(feature)
		if normalized_feature.is_empty():
			continue
		if _source_has_feature(report, source_path, normalized_feature):
			_append_issue(
				report,
				"warning",
				"duplicate_feature_for_source",
				source_path,
				target_path,
				entry_index,
				"Source path has more than one remap entry for the same feature; first matching entry wins."
			)
		_append_normalized_entry(report, source_path, {
			"source_path": source_path,
			"target_path": target_path,
			"feature": normalized_feature,
			"entry_index": entry_index,
			"priority": priority,
			"metadata": GFVariantData.duplicate_collection(metadata),
		})


static func _extract_entry_payloads(entries_payload: Variant) -> Array:
	if entries_payload is Array:
		var entries: Array = GFVariantData.as_array(entries_payload)
		if _looks_like_single_array_entry(entries):
			return [entries]
		return entries
	if entries_payload is PackedStringArray:
		return [entries_payload]
	if entries_payload is Dictionary:
		var entry: Dictionary = entries_payload
		if entry.has("entries"):
			return GFVariantData.get_option_array(entry, "entries")
		return [entry]
	return []


static func _looks_like_single_array_entry(values: Array) -> bool:
	if values.size() < 2:
		return false
	return (values[0] is String or values[0] is StringName) and (values[1] is String or values[1] is StringName)


static func _packed_or_array_to_array(value: Variant) -> Array:
	if value is PackedStringArray:
		var packed_values: PackedStringArray = value
		var result: Array = []
		for packed_value: String in packed_values:
			result.append(packed_value)
		return result
	return GFVariantData.as_array(value)


static func _extract_source_path(record: Dictionary) -> String:
	var path: String = GFVariantData.get_option_string(record, "source_path")
	if path.is_empty():
		path = GFVariantData.get_option_string(record, "path")
	if path.is_empty():
		path = GFVariantData.get_option_string(record, "from")
	return _normalize_path(path)


static func _extract_target_path(entry: Dictionary) -> String:
	var path: String = GFVariantData.get_option_string(entry, "target_path")
	if path.is_empty():
		path = GFVariantData.get_option_string(entry, "path")
	if path.is_empty():
		path = GFVariantData.get_option_string(entry, "remap_path")
	if path.is_empty():
		path = GFVariantData.get_option_string(entry, "to")
	return _normalize_path(path)


static func _extract_entry_features(entry: Dictionary) -> PackedStringArray:
	if entry.has("features"):
		return _normalize_feature_list(GFVariantData.get_option_packed_string_array(entry, "features"))
	var feature: String = _normalize_feature(GFVariantData.get_option_string(entry, "feature"))
	if feature.is_empty():
		return PackedStringArray()
	return PackedStringArray([feature])


static func _make_invalid_entry(source_path: String, entry_index: int, payload: Variant) -> Dictionary:
	return {
		"source_path": source_path,
		"target_path": "",
		"feature": "",
		"entry_index": entry_index,
		"priority": entry_index,
		"metadata": {
			"invalid_payload_type": type_string(typeof(payload)),
		},
	}


static func _ensure_source(report: Dictionary, source_path: String) -> void:
	var remaps: Dictionary = GFVariantData.get_option_dictionary(report, "remaps")
	if remaps.has(source_path):
		return
	remaps[source_path] = []
	report["remaps"] = remaps
	var sources: PackedStringArray = GFVariantData.get_option_packed_string_array(report, "sources")
	var _source_appended: bool = sources.append(source_path)
	sources.sort()
	report["sources"] = sources


static func _append_normalized_entry(report: Dictionary, source_path: String, entry: Dictionary) -> void:
	var remaps: Dictionary = GFVariantData.get_option_dictionary(report, "remaps")
	var entries: Array = GFVariantData.get_option_array(remaps, source_path)
	entries.append(entry)
	remaps[source_path] = entries
	report["remaps"] = remaps


static func _source_has_feature(report: Dictionary, source_path: String, feature: String) -> bool:
	var remaps: Dictionary = GFVariantData.get_option_dictionary(report, "remaps")
	for entry_value: Variant in GFVariantData.get_option_array(remaps, source_path):
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		if GFVariantData.get_option_string(entry, "feature") == feature:
			return true
	return false


static func _select_entry(entries: Array, active_set: Dictionary) -> Dictionary:
	for entry_value: Variant in entries:
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		var feature: String = GFVariantData.get_option_string(entry, "feature")
		if active_set.has(feature):
			return entry
	return {}


static func _make_resolved_record(source_path: String, entry: Dictionary, extensions: PackedStringArray) -> Dictionary:
	var target_path: String = GFVariantData.get_option_string(entry, "target_path")
	return {
		"source_path": source_path,
		"target_path": target_path,
		"resolved_path": target_path,
		"feature": GFVariantData.get_option_string(entry, "feature"),
		"entry_index": GFVariantData.get_option_int(entry, "entry_index", -1),
		"priority": GFVariantData.get_option_int(entry, "priority"),
		"source_is_resource": GFResourceRegistryTools.is_resource_path(source_path, extensions),
		"target_is_resource": GFResourceRegistryTools.is_resource_path(target_path, extensions),
		"metadata": GFVariantData.duplicate_collection(GFVariantData.get_option_dictionary(entry, "metadata")),
	}


static func _make_unmatched_record(source_path: String, entries: Array, extensions: PackedStringArray) -> Dictionary:
	return {
		"source_path": source_path,
		"resolved_path": source_path,
		"reason": "no_active_feature",
		"candidate_count": entries.size(),
		"source_is_resource": GFResourceRegistryTools.is_resource_path(source_path, extensions),
	}


static func _make_skip_paths(
	all_target_set: Dictionary,
	source_path_set: Dictionary,
	selected_target_set: Dictionary,
	options: Dictionary
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var exported_path_set: Dictionary = _make_string_set(GFVariantData.get_option_packed_string_array(options, "exported_paths"))
	var protected_path_set: Dictionary = _make_string_set(GFVariantData.get_option_packed_string_array(options, "protected_paths"))
	var protect_original_paths: bool = GFVariantData.get_option_bool(options, "protect_original_paths", true)
	var protect_selected_targets: bool = GFVariantData.get_option_bool(options, "protect_selected_targets", true)
	for target_value: Variant in all_target_set.keys():
		var target_path: String = _normalize_path(GFVariantData.to_text(target_value))
		if target_path.is_empty():
			continue
		if not exported_path_set.is_empty() and not exported_path_set.has(target_path):
			continue
		if protected_path_set.has(target_path):
			continue
		if protect_original_paths and source_path_set.has(target_path):
			continue
		if protect_selected_targets and selected_target_set.has(target_path):
			continue
		if not result.has(target_path):
			var _skip_appended: bool = result.append(target_path)
	result.sort()
	return result


static func _finalize_normalize_report(report: Dictionary) -> Dictionary:
	var remaps: Dictionary = GFVariantData.get_option_dictionary(report, "remaps")
	var entry_count: int = 0
	for source_path: Variant in remaps.keys():
		entry_count += GFVariantData.get_option_array(remaps, source_path).size()
	report["source_count"] = remaps.size()
	report["entry_count"] = entry_count
	_finalize_issue_counts(report)
	report["summary"] = "sources=%d entries=%d issues=%d" % [
		GFVariantData.get_option_int(report, "source_count"),
		GFVariantData.get_option_int(report, "entry_count"),
		GFVariantData.get_option_int(report, "issue_count"),
	]
	return report


static func _finalize_selection_report(report: Dictionary) -> Dictionary:
	_finalize_issue_counts(report)
	report["summary"] = "selected=%s resolved_path=%s issues=%d" % [
		str(GFVariantData.get_option_bool(report, "selected")),
		GFVariantData.get_option_string(report, "resolved_path"),
		GFVariantData.get_option_int(report, "issue_count"),
	]
	return report


static func _finalize_plan_report(plan: Dictionary) -> Dictionary:
	var resolved: Array = GFVariantData.get_option_array(plan, "resolved")
	var unmatched: Array = GFVariantData.get_option_array(plan, "unmatched")
	var skip_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(plan, "skip_paths")
	var resource_count: int = 0
	for record_value: Variant in resolved:
		var record: Dictionary = GFVariantData.as_dictionary(record_value)
		if GFVariantData.get_option_bool(record, "target_is_resource"):
			resource_count += 1

	plan["selected_count"] = resolved.size()
	plan["unmatched_count"] = unmatched.size()
	plan["skip_count"] = skip_paths.size()
	plan["resource_remap_count"] = resource_count
	plan["raw_file_remap_count"] = maxi(resolved.size() - resource_count, 0)
	_finalize_issue_counts(plan)
	plan["summary"] = "selected=%d unmatched=%d skip=%d issues=%d" % [
		GFVariantData.get_option_int(plan, "selected_count"),
		GFVariantData.get_option_int(plan, "unmatched_count"),
		GFVariantData.get_option_int(plan, "skip_count"),
		GFVariantData.get_option_int(plan, "issue_count"),
	]
	return plan


static func _append_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	source_path: String,
	target_path: String,
	entry_index: int,
	message: String
) -> void:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	issues.append({
		"severity": severity,
		"kind": kind,
		"source_path": source_path,
		"target_path": target_path,
		"entry_index": entry_index,
		"message": message,
	})
	report["issues"] = issues


static func _finalize_issue_counts(report: Dictionary) -> void:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var error_count: int = 0
	var warning_count: int = 0
	for issue_value: Variant in issues:
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		match GFVariantData.get_option_string(issue, "severity"):
			"error":
				error_count += 1
			"warning":
				warning_count += 1
	report["issue_count"] = issues.size()
	report["error_count"] = error_count
	report["warning_count"] = warning_count
	report["ok"] = error_count == 0


static func _normalize_path(path: String) -> String:
	return path.replace("\\", "/").strip_edges()


static func _normalize_feature(feature: String) -> String:
	return feature.strip_edges()


static func _normalize_feature_list(features: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for feature: String in features:
		var normalized_feature: String = _normalize_feature(feature)
		if not normalized_feature.is_empty() and not result.has(normalized_feature):
			var _feature_appended: bool = result.append(normalized_feature)
	return result


static func _all_features_empty(features: PackedStringArray) -> bool:
	for feature: String in features:
		if not _normalize_feature(feature).is_empty():
			return false
	return true


static func _make_feature_set(features: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for feature: String in _normalize_feature_list(features):
		result[feature] = true
	return result


static func _make_string_set(values: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for value: String in values:
		var normalized_value: String = _normalize_path(value)
		if not normalized_value.is_empty():
			result[normalized_value] = true
	return result


static func _get_sorted_keys(dictionary: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in dictionary.keys():
		var path: String = _normalize_path(GFVariantData.to_text(key))
		if not path.is_empty():
			var _key_appended: bool = result.append(path)
	result.sort()
	return result
