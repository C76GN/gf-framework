@tool

# GF 内置可选工具编辑器贡献 catalog 读取器。
extends RefCounted


# --- 常量 ---

## 支持的内置可选工具贡献 catalog schema 版本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const SCHEMA_VERSION: int = 1

## 单个可选 catalog 输入允许读取的最大字节数。
## [br]
## @api private
const _MAX_CATALOG_BYTES: int = 262_144

## catalog JSON 解析允许的最大嵌套深度。
## [br]
## @api private
const _MAX_JSON_DEPTH: int = 16

## catalog 中可接受的 manifest 记录上限。
## [br]
## @api private
const _MAX_MANIFEST_RECORD_COUNT: int = 128

## 有界 JSON object reader 脚本，用于读取受字节数和深度限制的 catalog。
## [br]
## @api private
const _GF_BOUNDED_JSON_READER_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_bounded_json_reader.gd"
)

## manifest 校验及贡献记录结构的注册表脚本。
## [br]
## @api private
const _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_editor_contribution_registry.gd"
)

## 资源路径规范化工具脚本。
## [br]
## @api private
const _GF_PATH_TOOLS_SCRIPT = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## 从不可信 Variant 输入中读取类型化选项的工具脚本。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## catalog 根对象允许出现的字段名。
## [br]
## @api private
const _CATALOG_ALLOWED_KEYS: Array[String] = [
	"schema_version",
	"manifest_records",
]

## catalog 内单条 manifest 记录允许出现的字段名。
## [br]
## @api private
const _MANIFEST_RECORD_ALLOWED_KEYS: Array[String] = [
	"package_id",
	"manifest_path",
]


# --- 框架内部方法 ---

## 读取内置可选工具贡献 catalog，并把有效记录合并到基础记录集合。
## [br]
## 缺席的可选 manifest 保持静默；存在但无效的 manifest 会被隔离，
## 不会覆盖基础记录或其他有效工具记录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param catalog_path: data-only catalog JSON 路径。
## [br]
## @param base_records: 合并前已有的编辑器贡献记录。
## [br]
## @return catalog 读取与合并报告。
## [br]
## @schema base_records: Dictionary，结构同 GFEditorContributionRegistry.empty_records()。
## [br]
## @schema return: Dictionary，包含 ok、state、source_path、records、manifest_reports、issues、issue_count、manifest_count、loaded_manifest_count、absent_manifest_count、degraded_manifest_count 和 skipped_manifest_count；state 为 absent、valid、degraded 或 invalid。
static func load_catalog_report(
	catalog_path: String,
	base_records: Dictionary = {}
) -> Dictionary:
	var normalized_path: String = _GF_PATH_TOOLS_SCRIPT.normalize_resource_path(catalog_path)
	var merged_records: Dictionary = _copy_record_sets(base_records)
	var manifest_reports: Array[Dictionary] = []
	var issues: Array[Dictionary] = []
	if normalized_path.is_empty():
		issues.append(_make_issue(
			"invalid_catalog_path",
			"",
			catalog_path,
			"Built-in tool contribution catalog path is invalid."
		))
		return _make_report(
			false,
			"invalid",
			normalized_path,
			merged_records,
			manifest_reports,
			issues
		)
	if not FileAccess.file_exists(normalized_path):
		return _make_report(
			true,
			"absent",
			normalized_path,
			merged_records,
			manifest_reports,
			issues
		)

	var data: Dictionary = _read_catalog_object(normalized_path, issues)
	if not issues.is_empty():
		return _make_report(
			false,
			"invalid",
			normalized_path,
			merged_records,
			manifest_reports,
			issues
		)
	if not _catalog_uses_allowed_keys(data, normalized_path, issues):
		return _make_report(
			false,
			"invalid",
			normalized_path,
			merged_records,
			manifest_reports,
			issues
		)

	var schema_version: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		data,
		"schema_version",
		-1
	)
	if schema_version != SCHEMA_VERSION:
		issues.append(_make_issue(
			"unsupported_catalog_schema_version",
			"",
			normalized_path,
			"Built-in tool contribution catalog schema_version is unsupported.",
			"schema_version",
			str(schema_version)
		))
		return _make_report(
			false,
			"invalid",
			normalized_path,
			merged_records,
			manifest_reports,
			issues
		)

	var catalog_records: Array[Dictionary] = _collect_manifest_records(
		data,
		normalized_path,
		issues
	)
	if not issues.is_empty():
		return _make_report(
			false,
			"invalid",
			normalized_path,
			merged_records,
			manifest_reports,
			issues,
			catalog_records.size()
		)

	var source_ids: Dictionary = {}
	var payload_ids: Dictionary = {}
	_index_record_identities(merged_records, source_ids, payload_ids)
	var loaded_manifest_count: int = 0
	var absent_manifest_count: int = 0
	var degraded_manifest_count: int = 0
	var skipped_manifest_count: int = 0
	for catalog_record: Dictionary in catalog_records:
		var package_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			catalog_record,
			"package_id"
		)
		var manifest_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			catalog_record,
			"manifest_path"
		)
		var manifest_report: Dictionary = (
			_GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.load_manifest_report(manifest_path)
		)
		var manifest_state: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			manifest_report,
			"state"
		)
		var catalog_manifest_report: Dictionary = _make_catalog_manifest_report(
			package_id,
			manifest_path,
			manifest_report
		)
		if manifest_state == "absent":
			catalog_manifest_report["catalog_state"] = "absent"
			manifest_reports.append(catalog_manifest_report)
			absent_manifest_count += 1
			continue

		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(manifest_report, "ok", false):
			catalog_manifest_report["catalog_state"] = "rejected"
			manifest_reports.append(catalog_manifest_report)
			issues.append(_make_issue(
				"invalid_contribution_manifest",
				package_id,
				manifest_path,
				"Present built-in tool contribution manifest is invalid."
			))
			skipped_manifest_count += 1
			continue

		var actual_package_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			manifest_report,
			"package_id"
		)
		if actual_package_id != package_id:
			catalog_manifest_report["catalog_state"] = "rejected"
			manifest_reports.append(catalog_manifest_report)
			issues.append(_make_issue(
				"manifest_package_id_mismatch",
				package_id,
				manifest_path,
				"Contribution manifest package_id does not match its catalog record.",
				"package_id",
				actual_package_id
			))
			skipped_manifest_count += 1
			continue

		var manifest_records: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			manifest_report,
			"records",
			_GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.empty_records()
		)
		if not _try_merge_manifest_records(
			merged_records,
			manifest_records,
			source_ids,
			payload_ids,
			package_id,
			manifest_path,
			issues
		):
			catalog_manifest_report["catalog_state"] = "rejected"
			manifest_reports.append(catalog_manifest_report)
			skipped_manifest_count += 1
			continue

		catalog_manifest_report["catalog_state"] = "loaded"
		manifest_reports.append(catalog_manifest_report)
		loaded_manifest_count += 1
		if manifest_state == "degraded":
			degraded_manifest_count += 1

	var state: String = "valid"
	if not issues.is_empty() or degraded_manifest_count > 0:
		state = "degraded"
	return _make_report(
		true,
		state,
		normalized_path,
		merged_records,
		manifest_reports,
		issues,
		catalog_records.size(),
		loaded_manifest_count,
		absent_manifest_count,
		degraded_manifest_count,
		skipped_manifest_count
	)


# --- 私有/辅助方法 ---

## 通过有界 reader 解码 catalog object，并把读取错误映射为 catalog issue。
## payload 超限和嵌套过深会使用专用 issue 种类，其余 reader 错误保留原始种类前缀。
## [br]
## @api private
static func _read_catalog_object(
	path: String,
	issues: Array[Dictionary]
) -> Dictionary:
	var read_result: Dictionary = _GF_BOUNDED_JSON_READER_SCRIPT.read_object(
		path,
		_MAX_CATALOG_BYTES,
		_MAX_JSON_DEPTH
	)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(read_result, "ok", false):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(read_result, "data")

	var raw_kind: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
		read_result,
		"error_kind"
	)
	var issue_kind: String = "catalog_%s" % String(raw_kind)
	if raw_kind == &"payload_too_large":
		issue_kind = "catalog_too_large"
	elif raw_kind == &"nesting_too_deep":
		issue_kind = "catalog_too_deep"
	issues.append(_make_issue(
		issue_kind,
		"",
		path,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			read_result,
			"error",
			"Built-in tool contribution catalog could not be read."
		)
	))
	return {}


## 检查 manifest_records 数组和每条记录的字段、标识及路径，并收集有效规范化记录。
## 发现无效项时向 issues 追加诊断；调用方随后将有 issue 的 catalog 作为 invalid 处理。
## [br]
## @api private
static func _collect_manifest_records(
	data: Dictionary,
	catalog_path: String,
	issues: Array[Dictionary]
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if not data.has("manifest_records"):
		issues.append(_make_issue(
			"missing_manifest_records",
			"",
			catalog_path,
			"Built-in tool contribution catalog requires manifest_records.",
			"manifest_records"
		))
		return records

	var raw_records_value: Variant = data.get("manifest_records")
	if not raw_records_value is Array:
		issues.append(_make_issue(
			"invalid_manifest_records",
			"",
			catalog_path,
			"Built-in tool contribution catalog manifest_records must be an array.",
			"manifest_records"
		))
		return records

	var raw_records: Array = raw_records_value
	if raw_records.size() > _MAX_MANIFEST_RECORD_COUNT:
		issues.append(_make_issue(
			"manifest_record_budget_exceeded",
			"",
			catalog_path,
			"Built-in tool contribution catalog exceeds the manifest-record budget.",
			"manifest_records",
			str(_MAX_MANIFEST_RECORD_COUNT)
		))
		return records

	var used_package_ids: Dictionary = {}
	var used_manifest_paths: Dictionary = {}
	for index: int in raw_records.size():
		var raw_record_value: Variant = raw_records[index]
		if not raw_record_value is Dictionary:
			issues.append(_make_issue(
				"invalid_manifest_record",
				"",
				catalog_path,
				"Built-in tool contribution catalog record must be an object.",
				"manifest_records",
				str(index)
			))
			continue

		var raw_record: Dictionary = raw_record_value
		if not _record_uses_allowed_keys(raw_record, catalog_path, index, issues):
			continue
		var package_value: Variant = raw_record.get("package_id")
		var manifest_path_value: Variant = raw_record.get("manifest_path")
		if not package_value is String:
			issues.append(_make_issue(
				"invalid_catalog_package_id",
				"",
				catalog_path,
				"Catalog package_id must be a string gf.tool.* identifier.",
				"package_id",
				str(index)
			))
			continue
		var package_id: String = package_value
		if not manifest_path_value is String:
			issues.append(_make_issue(
				"invalid_catalog_manifest_path",
				package_id,
				catalog_path,
				"Catalog manifest_path must be a canonical res:// JSON path.",
				"manifest_path",
				str(index)
			))
			continue

		var raw_manifest_path: String = manifest_path_value
		var manifest_path: String = _GF_PATH_TOOLS_SCRIPT.normalize_resource_path(
			raw_manifest_path
		)
		if not _is_valid_tool_package_id(package_id):
			issues.append(_make_issue(
				"invalid_catalog_package_id",
				package_id,
				catalog_path,
				"Catalog package_id must be a canonical gf.tool.* identifier.",
				"package_id",
				package_id
			))
			continue
		if not _is_valid_manifest_path(raw_manifest_path, manifest_path):
			issues.append(_make_issue(
				"invalid_catalog_manifest_path",
				package_id,
				raw_manifest_path,
				"Catalog manifest_path must be a canonical res:// JSON path.",
				"manifest_path",
				raw_manifest_path
			))
			continue
		if used_package_ids.has(package_id):
			issues.append(_make_issue(
				"duplicate_catalog_package_id",
				package_id,
				manifest_path,
				"Catalog package_id must be unique.",
				"package_id",
				package_id
			))
			continue
		if used_manifest_paths.has(manifest_path):
			issues.append(_make_issue(
				"duplicate_catalog_manifest_path",
				package_id,
				manifest_path,
				"Catalog manifest_path must be unique.",
				"manifest_path",
				manifest_path
			))
			continue

		used_package_ids[package_id] = true
		used_manifest_paths[manifest_path] = true
		records.append({
			"package_id": package_id,
			"manifest_path": manifest_path,
		})
	return records


## 拒绝 catalog 根对象中首个不在稳定字段清单内的键。
## [br]
## @api private
static func _catalog_uses_allowed_keys(
	data: Dictionary,
	catalog_path: String,
	issues: Array[Dictionary]
) -> bool:
	for key_value: Variant in data.keys():
		var key: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(key_value)
		if not _CATALOG_ALLOWED_KEYS.has(key):
			issues.append(_make_issue(
				"unknown_catalog_field",
				"",
				catalog_path,
				"Built-in tool contribution catalog field is not part of the stable schema.",
				key
			))
			return false
	return true


## 拒绝 manifest 记录中首个不在记录字段清单内的键，并标记记录索引。
## [br]
## @api private
static func _record_uses_allowed_keys(
	record: Dictionary,
	catalog_path: String,
	record_index: int,
	issues: Array[Dictionary]
) -> bool:
	for key_value: Variant in record.keys():
		var key: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(key_value)
		if not _MANIFEST_RECORD_ALLOWED_KEYS.has(key):
			issues.append(_make_issue(
				"unknown_manifest_record_field",
				"",
				catalog_path,
				"Catalog manifest record field is not part of the stable schema.",
				key,
				str(record_index)
			))
			return false
	return true


## 校验 package id 是否由小写、非空的标识符段组成，且以 `gf.tool.` 开头。
## 输入首尾空白不被规范化接受。
## [br]
## @api private
static func _is_valid_tool_package_id(package_id: String) -> bool:
	if package_id != package_id.strip_edges() or not package_id.begins_with("gf.tool."):
		return false
	var segments: PackedStringArray = package_id.split(".", false)
	if segments.size() < 3:
		return false
	for segment: String in segments:
		if (
			segment.is_empty()
			or not segment.is_valid_identifier()
			or segment != segment.to_lower()
		):
			return false
	return true


## 要求输入路径原样等于规范化结果，并是无首尾空白的 `res://` JSON 路径。
## [br]
## @api private
static func _is_valid_manifest_path(raw_path: String, normalized_path: String) -> bool:
	return (
		raw_path == raw_path.strip_edges()
		and raw_path == normalized_path
		and normalized_path.begins_with("res://")
		and normalized_path.ends_with(".json")
	)


## 按注册表的记录族结构构造新字典，并从 source 提取各族中的有效记录。
## 记录字典由 `_get_record_array` 深复制。
## [br]
## @api private
static func _copy_record_sets(source: Dictionary) -> Dictionary:
	var records: Dictionary = _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.empty_records()
	for record_key: String in records.keys():
		records[record_key] = _get_record_array(source, record_key)
	return records


## 从指定记录族中筛出字典项并深复制；缺失或非数组字段返回空数组。
## [br]
## @api private
static func _get_record_array(records: Dictionary, record_key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_records_value: Variant = records.get(record_key, [])
	if not raw_records_value is Array:
		return result
	var raw_records: Array = raw_records_value
	for raw_record_value: Variant in raw_records:
		if raw_record_value is Dictionary:
			var raw_record: Dictionary = raw_record_value
			result.append(raw_record.duplicate(true))
	return result


## 将现有记录中首个非空 source_id 和 payload 标识写入两个去重索引。
## source_id 会去除首尾空白，payload 标识由 `_get_record_payload_id` 生成。
## [br]
## @api private
static func _index_record_identities(
	records: Dictionary,
	source_ids: Dictionary,
	payload_ids: Dictionary
) -> void:
	for record_key: String in _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.empty_records().keys():
		for record: Dictionary in _get_record_array(records, record_key):
			var source_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				record,
				"source_id"
			).strip_edges()
			if not source_id.is_empty() and not source_ids.has(source_id):
				source_ids[source_id] = true
			var payload_id: String = _get_record_payload_id(record)
			if not payload_id.is_empty() and not payload_ids.has(payload_id):
				payload_ids[payload_id] = true


## 先在副本索引上检查 incoming 的 source_id 与 payload 是否冲突，再合并各记录族。
## 有冲突时保留 target 和原索引；只有整批检查通过才提交记录与索引更新。
## [br]
## @api private
static func _try_merge_manifest_records(
	target: Dictionary,
	incoming: Dictionary,
	source_ids: Dictionary,
	payload_ids: Dictionary,
	package_id: String,
	manifest_path: String,
	issues: Array[Dictionary]
) -> bool:
	var candidate_source_ids: Dictionary = source_ids.duplicate()
	var candidate_payload_ids: Dictionary = payload_ids.duplicate()
	var issue_count_before: int = issues.size()
	for record_key: String in _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.empty_records().keys():
		for record: Dictionary in _get_record_array(incoming, record_key):
			var source_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				record,
				"source_id"
			).strip_edges()
			if source_id.is_empty() or candidate_source_ids.has(source_id):
				issues.append(_make_issue(
					"duplicate_catalog_source_id",
					package_id,
					manifest_path,
					"Tool contribution source_id conflicts with an earlier contribution.",
					"source_id",
					source_id
				))
			else:
				candidate_source_ids[source_id] = true

			var payload_id: String = _get_record_payload_id(record)
			if not payload_id.is_empty() and candidate_payload_ids.has(payload_id):
				issues.append(_make_issue(
					"duplicate_catalog_payload_identity",
					package_id,
					manifest_path,
					"Tool contribution payload conflicts with an earlier contribution.",
					"payload_identity",
					payload_id
				))
			elif not payload_id.is_empty():
				candidate_payload_ids[payload_id] = true
	if issues.size() != issue_count_before:
		return false

	for record_key: String in _GF_EDITOR_CONTRIBUTION_REGISTRY_SCRIPT.empty_records().keys():
		var merged_family: Array[Dictionary] = _get_record_array(target, record_key)
		merged_family.append_array(_get_record_array(incoming, record_key))
		target[record_key] = merged_family
	source_ids.clear()
	payload_ids.clear()
	for source_id_value: Variant in candidate_source_ids.keys():
		source_ids[source_id_value] = true
	for payload_id_value: Variant in candidate_payload_ids.keys():
		payload_ids[payload_id_value] = true
	return true


## 按 path、template_path、name 的顺序取首个非空值，并附带字段名形成去重标识。
## 没有可用字段时返回空字符串。
## [br]
## @api private
static func _get_record_payload_id(record: Dictionary) -> String:
	for field: String in ["path", "template_path", "name"]:
		var value: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			record,
			field
		).strip_edges()
		if not value.is_empty():
			return "%s:%s" % [field, value]
	return ""


## 深复制 manifest 报告，移除内部 records，并附加其 catalog package id 和路径。
## [br]
## @api private
static func _make_catalog_manifest_report(
	package_id: String,
	manifest_path: String,
	manifest_report: Dictionary
) -> Dictionary:
	var report: Dictionary = manifest_report.duplicate(true)
	var _records_erased: bool = report.erase("records")
	report["catalog_package_id"] = package_id
	report["catalog_manifest_path"] = manifest_path
	return report


## 组装 catalog 汇总报告，并深复制记录、manifest 报告和 issue 集合。
## issue_count 从传入 issues 的当前长度计算。
## [br]
## @api private
static func _make_report(
	ok: bool,
	state: String,
	source_path: String,
	records: Dictionary,
	manifest_reports: Array[Dictionary],
	issues: Array[Dictionary],
	manifest_count: int = 0,
	loaded_manifest_count: int = 0,
	absent_manifest_count: int = 0,
	degraded_manifest_count: int = 0,
	skipped_manifest_count: int = 0
) -> Dictionary:
	return {
		"ok": ok,
		"state": state,
		"source_path": source_path,
		"records": records.duplicate(true),
		"manifest_reports": manifest_reports.duplicate(true),
		"issues": issues.duplicate(true),
		"issue_count": issues.size(),
		"manifest_count": manifest_count,
		"loaded_manifest_count": loaded_manifest_count,
		"absent_manifest_count": absent_manifest_count,
		"degraded_manifest_count": degraded_manifest_count,
		"skipped_manifest_count": skipped_manifest_count,
	}


## 组装 catalog 诊断字典；package_id、field 和 actual_value 仅在非空时加入。
## [br]
## @api private
static func _make_issue(
	kind: String,
	package_id: String,
	path: String,
	message: String,
	field: String = "",
	actual_value: String = ""
) -> Dictionary:
	var issue: Dictionary = {
		"kind": kind,
		"path": path,
		"message": message,
	}
	if not package_id.is_empty():
		issue["package_id"] = package_id
	if not field.is_empty():
		issue["field"] = field
	if not actual_value.is_empty():
		issue["actual_value"] = actual_value
	return issue
