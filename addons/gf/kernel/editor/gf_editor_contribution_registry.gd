@tool

## GFEditorContributionRegistry: GF 编辑器贡献清单读取器。
##
## 只读取 data-only JSON manifest 和模板文本，不加载贡献来源脚本。
## 根插件用它在标准库部分安装或残留时保持可恢复启动。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 8.0.0
## [br]
## @layer kernel/editor
class_name GFEditorContributionRegistry
extends RefCounted


# --- 常量 ---

## 支持的编辑器贡献清单 schema 版本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const SCHEMA_VERSION: int = 5

## 工作区任务与资源动作的纯数据校验器。
## [br]
## @api private
const _WORKSPACE_RECORDS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_workspace_contribution_records.gd")

## 单个 manifest JSON 允许读取的最大字节数。
## [br]
## @api private
const _MAX_MANIFEST_BYTES: int = 1_048_576

## manifest JSON 解析允许的最大嵌套深度。
## [br]
## @api private
const _MAX_JSON_DEPTH: int = 64

## 单份 manifest 中所有记录族合计的记录上限。
## [br]
## @api private
const _MAX_RECORD_COUNT: int = 1024

## 单个模板文本允许读取的最大字节数。
## [br]
## @api private
const _MAX_TEMPLATE_BYTES: int = 1_048_576

## 单份 manifest 中全部模板文本共用的最大字节预算。
## [br]
## @api private
const _MAX_TEMPLATE_TOTAL_BYTES: int = 4_194_304

## 有界 JSON object reader 脚本，用于限制 manifest 的读取大小和深度。
## [br]
## @api private
const _GF_BOUNDED_JSON_READER_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_bounded_json_reader.gd"
)

## 资源路径规范化工具脚本。
## [br]
## @api private
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## 从不可信 Variant 输入中读取类型化选项的工具脚本。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## manifest 根对象允许出现的字段名。
## [br]
## @api private
const _MANIFEST_ALLOWED_KEYS: Array[String] = [
	"schema_version",
	"package_id",
	"inspector_plugin_records",
	"export_plugin_records",
	"debugger_plugin_records",
	"dock_records",
	"template_records",
	"project_setting_records",
	"project_setting_section_records",
]

## inspector、export 和 debugger 脚本记录可复制的字段名。
## [br]
## @api private
const _SCRIPT_RECORD_ALLOWED_KEYS: Array[String] = [
	"owner_package_id",
	"source_id",
	"path",
	"label",
]

## Dock 记录可复制的字段名。
## [br]
## @api private
const _DOCK_RECORD_ALLOWED_KEYS: Array[String] = [
	"owner_package_id",
	"source_id",
	"path",
	"label",
	"short_label",
	"order",
]

## 模板记录可复制的字段名。
## [br]
## @api private
const _TEMPLATE_RECORD_ALLOWED_KEYS: Array[String] = [
	"owner_package_id",
	"source_id",
	"type",
	"label",
	"section",
	"base_class",
	"template_path",
]

## ProjectSettings 记录可复制的字段名。
## [br]
## @api private
const _PROJECT_SETTING_RECORD_ALLOWED_KEYS: Array[String] = [
	"owner_package_id",
	"source_id",
	"name",
	"default_value",
	"type",
	"type_name",
	"hint",
	"hint_string",
	"basic",
	"restart_if_changed",
	"internal",
	"update_initial_value",
	"usage",
	"editor_labels",
	"editor_descriptions",
	"editor_enum_labels",
	"editor_enum_descriptions",
]

## ProjectSettings section 记录可复制的字段名。
## [br]
## @api private
const _PROJECT_SETTING_SECTION_RECORD_ALLOWED_KEYS: Array[String] = [
	"owner_package_id",
	"source_id",
	"path",
	"editor_labels",
	"editor_descriptions",
]


# --- 框架内部方法 ---

## 创建空编辑器贡献记录集合。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 空记录集合。
## [br]
## @schema return: Dictionary，包含 inspector_plugin_records、export_plugin_records、debugger_plugin_records、dock_records、template_records、project_setting_records、project_setting_section_records、task_records 和 resource_action_records 数组。
static func empty_records() -> Dictionary:
	return {
		"inspector_plugin_records": [],
		"export_plugin_records": [],
		"debugger_plugin_records": [],
		"dock_records": [],
		"template_records": [],
		"project_setting_records": [],
		"project_setting_section_records": [],
		"task_records": [],
		"resource_action_records": [],
	}


## 读取编辑器贡献清单并返回可直接交给插件 helper 的记录集合。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param manifest_path: JSON manifest 路径。
## [br]
## @return 规范化后的记录集合。
## [br]
## @schema return: Dictionary，结构同 empty_records()；模板记录会把 template_path 解析为 template 文本。
static func load_manifest_records(manifest_path: String) -> Dictionary:
	var report: Dictionary = load_manifest_report(manifest_path)
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(report, "records", empty_records())


## 读取编辑器贡献清单并返回包含跳过记录的诊断报告。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param manifest_path: JSON manifest 路径。
## [br]
## @return manifest 读取报告。
## [br]
## @schema return: Dictionary，包含 ok、state、source_path、package_id、records、issues、skipped_records、issue_count 和 skipped_record_count；state 为 absent、valid、degraded 或 invalid。
static func load_manifest_report(manifest_path: String) -> Dictionary:
	var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(manifest_path)
	var records: Dictionary = empty_records()
	var issues: Array[Dictionary] = []
	var skipped_records: Array[Dictionary] = []
	if normalized_path.is_empty():
		issues.append(_make_issue(
			"invalid_manifest_path",
			manifest_path,
			"Editor contribution manifest path is invalid."
		))
		return _make_report(false, normalized_path, records, issues, skipped_records)
	if not FileAccess.file_exists(normalized_path):
		return _make_report(true, normalized_path, records, issues, skipped_records, "absent")

	var data: Dictionary = _read_json_object(normalized_path, issues)
	if not issues.is_empty():
		return _make_report(false, normalized_path, records, issues, skipped_records)

	var schema_version: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(data, "schema_version", -1)
	if schema_version not in [4, SCHEMA_VERSION]:
		issues.append(_make_issue(
			"unsupported_schema_version",
			normalized_path,
			"Editor contribution manifest schema_version is unsupported.",
			"schema_version",
			str(schema_version)
		))
		return _make_report(false, normalized_path, records, issues, skipped_records)

	if not _manifest_uses_allowed_keys(data, normalized_path, issues):
		return _make_report(false, normalized_path, records, issues, skipped_records)
	if _count_manifest_records(data) > _MAX_RECORD_COUNT:
		issues.append(_make_issue(
			"record_budget_exceeded",
			normalized_path,
			"Editor contribution manifest exceeds the record-count budget.",
			"",
			str(_MAX_RECORD_COUNT)
		))
		return _make_report(false, normalized_path, records, issues, skipped_records)

	var package_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "package_id").strip_edges()
	if package_id.is_empty():
		issues.append(_make_issue(
			"missing_package_id",
			normalized_path,
			"Editor contribution manifest package_id is required.",
			"package_id"
		))
		return _make_report(false, normalized_path, records, issues, skipped_records)

	records["inspector_plugin_records"] = _collect_script_records(
		data,
		"inspector_plugin_records",
		package_id,
		_SCRIPT_RECORD_ALLOWED_KEYS,
		issues,
		skipped_records
	)
	records["export_plugin_records"] = _collect_script_records(
		data,
		"export_plugin_records",
		package_id,
		_SCRIPT_RECORD_ALLOWED_KEYS,
		issues,
		skipped_records
	)
	records["debugger_plugin_records"] = _collect_script_records(
		data,
		"debugger_plugin_records",
		package_id,
		_SCRIPT_RECORD_ALLOWED_KEYS,
		issues,
		skipped_records
	)
	records["dock_records"] = _collect_script_records(
		data,
		"dock_records",
		package_id,
		_DOCK_RECORD_ALLOWED_KEYS,
		issues,
		skipped_records
	)
	records["template_records"] = _collect_template_records(
		data,
		"template_records",
		package_id,
		issues,
		skipped_records
	)
	records["project_setting_records"] = _collect_project_setting_records(
		data,
		"project_setting_records",
		package_id,
		issues
	)
	records["project_setting_section_records"] = _collect_project_setting_section_records(
		data,
		"project_setting_section_records",
		package_id,
		issues
	)
	if schema_version == 5:
		var page_owners: Dictionary = {}
		for page: Dictionary in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(records, "dock_records"):
			page_owners[page["path"]] = page["owner_package_id"]
		for family: String in ["task_records", "resource_action_records"]:
			var parsed: Dictionary = _WORKSPACE_RECORDS_SCRIPT.parse_records(
				data.get(family, []), package_id, page_owners, family == "resource_action_records"
			)
			records[family] = parsed["records"]
			for message: String in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(parsed, "errors"):
				issues.append(_make_issue("invalid_workspace_record", normalized_path, message, family))
	_validate_record_identities(records, issues)
	return _make_report(
		issues.is_empty(),
		normalized_path,
		records,
		issues,
		skipped_records,
		"",
		package_id
	)


# --- 私有/辅助方法 ---

## 用有界 reader 解码 manifest object，并将读取失败追加为 manifest issue。
## 超大 payload 和过深嵌套分别改用专用 issue 种类。
## [br]
## @api private
static func _read_json_object(path: String, issues: Array[Dictionary]) -> Dictionary:
	var read_result: Dictionary = _GF_BOUNDED_JSON_READER_SCRIPT.read_object(
		path,
		_MAX_MANIFEST_BYTES,
		_MAX_JSON_DEPTH
	)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(read_result, "ok", false):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(read_result, "data")
	var raw_kind: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(
		read_result,
		"error_kind"
	)
	var issue_kind: String = String(raw_kind)
	if raw_kind == &"payload_too_large":
		issue_kind = "manifest_too_large"
	elif raw_kind == &"nesting_too_deep":
		issue_kind = "manifest_too_deep"
	issues.append(_make_issue(
		issue_kind,
		path,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			read_result,
			"error",
			"Editor contribution manifest could not be read."
		)
	))
	return {}


## 校验并规范化脚本贡献或 Dock 记录，确认资源脚本存在后加入返回数组。
## 缺失脚本记入 skipped_records；字段或必需值无效时记入 issues 并跳过该记录。
## [br]
## @api private
static func _collect_script_records(
	data: Dictionary,
	record_key: String,
	package_id: String,
	allowed_keys: Array[String],
	issues: Array[Dictionary],
	skipped_records: Array[Dictionary]
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for raw_record: Dictionary in _get_record_dictionaries(data, record_key, issues):
		if not _record_uses_allowed_keys(raw_record, record_key, allowed_keys, issues):
			continue

		var owner_package_id: String = _get_owner_package_id(raw_record, record_key, issues)
		if owner_package_id.is_empty():
			continue
		var source_id: String = _make_source_id(owner_package_id, raw_record, record_key, issues)
		if source_id.is_empty():
			continue
		var script_path: String = _GF_PATH_TOOLS.normalize_resource_path(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_record, "path")
		)
		if script_path.is_empty():
			issues.append(_make_issue("missing_path", record_key, "Contribution record path is required.", "path", "", source_id))
			continue
		var label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_record, "label").strip_edges()
		if label.is_empty():
			issues.append(_make_issue("missing_label", record_key, "Contribution record label is required.", "label", "", source_id))
			continue
		var short_label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_record, "short_label").strip_edges()
		if record_key == "dock_records" and short_label.is_empty():
			issues.append(_make_issue("missing_short_label", record_key, "Dock record short_label is required.", "short_label", "", source_id))
			continue
		if record_key == "dock_records" and not raw_record.has("order"):
			issues.append(_make_issue("missing_order", record_key, "Dock record order is required.", "order", "", source_id))
			continue
		if not ResourceLoader.exists(script_path, "Script"):
			skipped_records.append(_make_issue(
				"missing_script",
				record_key,
				"Contribution script is missing and the record was skipped.",
				"path",
				script_path,
				source_id
			))
			continue

		var record: Dictionary = _copy_allowed_record(raw_record, allowed_keys)
		record["manifest_package_id"] = package_id
		record["owner_package_id"] = owner_package_id
		record["package_id"] = owner_package_id
		record["source_id"] = source_id
		record["path"] = script_path
		record["label"] = label
		if record_key == "dock_records":
			record["short_label"] = short_label
			record["order"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(raw_record, "order", 0)
		records.append(record)
	return records


## 校验模板记录并在单文件与累计字节预算内读取模板文本。
## 缺失模板记入 skipped_records，超出累计预算时停止后续模板读取。
## [br]
## @api private
static func _collect_template_records(
	data: Dictionary,
	record_key: String,
	package_id: String,
	issues: Array[Dictionary],
	skipped_records: Array[Dictionary]
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var total_template_bytes: int = 0
	for raw_record: Dictionary in _get_record_dictionaries(data, record_key, issues):
		if not _record_uses_allowed_keys(raw_record, record_key, _TEMPLATE_RECORD_ALLOWED_KEYS, issues):
			continue

		var owner_package_id: String = _get_owner_package_id(raw_record, record_key, issues)
		if owner_package_id.is_empty():
			continue
		var source_id: String = _make_source_id(owner_package_id, raw_record, record_key, issues)
		if source_id.is_empty():
			continue
		var template_type: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_record, "type").strip_edges()
		var label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_record, "label").strip_edges()
		var base_class: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_record, "base_class").strip_edges()
		if template_type.is_empty():
			issues.append(_make_issue("missing_template_type", record_key, "Template record type is required.", "type", "", source_id))
			continue
		if label.is_empty():
			issues.append(_make_issue("missing_label", record_key, "Template record label is required.", "label", "", source_id))
			continue
		if base_class.is_empty():
			issues.append(_make_issue("missing_base_class", record_key, "Template record base_class is required.", "base_class", "", source_id))
			continue
		if not _is_valid_gdscript_identifier(base_class):
			issues.append(_make_issue(
				"invalid_base_class",
				record_key,
				"Template record base_class must be a valid GDScript identifier.",
				"base_class",
				"",
				source_id
			))
			continue
		var template_path: String = _GF_PATH_TOOLS.normalize_resource_path(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_record, "template_path")
		)
		if template_path.is_empty():
			issues.append(_make_issue("missing_template_path", record_key, "Template record template_path is required.", "template_path", "", source_id))
			continue
		if not FileAccess.file_exists(template_path):
			skipped_records.append(_make_issue(
				"missing_template",
				record_key,
				"Template source file is missing and the record was skipped.",
				"template_path",
				template_path,
				source_id
			))
			continue

		var read_result: Dictionary = _read_template_text(
			template_path,
			record_key,
			issues,
			source_id,
			_MAX_TEMPLATE_TOTAL_BYTES - total_template_bytes
		)
		total_template_bytes += _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			read_result,
			"size_bytes",
			0
		)
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			read_result,
			"total_budget_exceeded",
			false
		):
			break
		var template_text: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			read_result,
			"text"
		)
		if template_text.is_empty():
			continue

		var record: Dictionary = _copy_allowed_record(raw_record, _TEMPLATE_RECORD_ALLOWED_KEYS)
		record["manifest_package_id"] = package_id
		record["owner_package_id"] = owner_package_id
		record["package_id"] = owner_package_id
		record["source_id"] = source_id
		record["type"] = template_type
		record["label"] = label
		record["base_class"] = base_class
		record["template_path"] = template_path
		record["template"] = template_text
		records.append(record)
	return records


## 校验 ProjectSettings 记录名称、类型和本地化展示字段，再生成规范化记录。
## 校验过程新增任一 issue 时，该记录不会加入结果。
## [br]
## @api private
static func _collect_project_setting_records(
	data: Dictionary,
	record_key: String,
	package_id: String,
	issues: Array[Dictionary]
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for raw_record: Dictionary in _get_record_dictionaries(data, record_key, issues):
		if not _record_uses_allowed_keys(raw_record, record_key, _PROJECT_SETTING_RECORD_ALLOWED_KEYS, issues):
			continue

		var owner_package_id: String = _get_owner_package_id(raw_record, record_key, issues)
		if owner_package_id.is_empty():
			continue
		var source_id: String = _make_source_id(owner_package_id, raw_record, record_key, issues)
		if source_id.is_empty():
			continue
		var setting_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_record, "name").strip_edges()
		if setting_name.is_empty():
			issues.append(_make_issue("missing_setting_name", record_key, "ProjectSettings record name is required.", "name", "", source_id))
			continue

		var default_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(raw_record, "default_value")
		var issue_count_before: int = issues.size()
		var variant_type: int = _record_variant_type(raw_record, default_value, record_key, source_id, issues)
		_validate_project_setting_presentation(raw_record, record_key, source_id, issues)
		if issues.size() != issue_count_before:
			continue
		var record: Dictionary = _copy_allowed_record(raw_record, _PROJECT_SETTING_RECORD_ALLOWED_KEYS)
		var _type_name_erased: bool = record.erase("type_name")
		record["manifest_package_id"] = package_id
		record["owner_package_id"] = owner_package_id
		record["package_id"] = owner_package_id
		record["source_id"] = source_id
		record["name"] = setting_name
		record["type"] = variant_type
		records.append(record)
	return records


## 校验可选的 ProjectSettings 本地化展示字段及枚举展示映射。
## 一旦提供展示信息，就要求同时提供 editor_labels 与 editor_descriptions。
## [br]
## @api private
static func _validate_project_setting_presentation(
	record: Dictionary,
	record_key: String,
	source_id: String,
	issues: Array[Dictionary]
) -> void:
	var presentation_fields: Array[String] = [
		"editor_labels",
		"editor_descriptions",
		"editor_enum_labels",
		"editor_enum_descriptions",
	]
	var has_presentation: bool = false
	for field: String in presentation_fields:
		if record.has(field):
			has_presentation = true
			break
	if not has_presentation:
		return

	if not record.has("editor_labels") or not record.has("editor_descriptions"):
		issues.append(_make_issue(
			"incomplete_setting_presentation",
			record_key,
			"ProjectSettings presentation requires both editor_labels and editor_descriptions.",
			"editor_labels",
			"",
			source_id
		))
		return

	_validate_locale_text_map(record["editor_labels"], "editor_labels", record_key, source_id, issues)
	_validate_locale_text_map(record["editor_descriptions"], "editor_descriptions", record_key, source_id, issues)
	for field: String in ["editor_enum_labels", "editor_enum_descriptions"]:
		if record.has(field):
			_validate_localized_enum_map(record[field], field, record_key, source_id, issues)


## 校验相对 section 路径和必需的本地化标题、描述后生成 section 记录。
## 路径不得为空、以斜线开头或包含双斜线。
## [br]
## @api private
static func _collect_project_setting_section_records(
	data: Dictionary,
	record_key: String,
	package_id: String,
	issues: Array[Dictionary]
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for raw_record: Dictionary in _get_record_dictionaries(data, record_key, issues):
		if not _record_uses_allowed_keys(
			raw_record,
			record_key,
			_PROJECT_SETTING_SECTION_RECORD_ALLOWED_KEYS,
			issues
		):
			continue

		var owner_package_id: String = _get_owner_package_id(raw_record, record_key, issues)
		if owner_package_id.is_empty():
			continue
		var source_id: String = _make_source_id(owner_package_id, raw_record, record_key, issues)
		if source_id.is_empty():
			continue
		var section_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			raw_record,
			"path"
		).strip_edges().trim_suffix("/")
		if section_path.is_empty() or section_path.begins_with("/") or section_path.contains("//"):
			issues.append(_make_issue(
				"invalid_project_setting_section_path",
				record_key,
				"ProjectSettings section path must be a non-empty relative path.",
				"path",
				section_path,
				source_id
			))
			continue

		var issue_count_before: int = issues.size()
		if not raw_record.has("editor_labels") or not raw_record.has("editor_descriptions"):
			issues.append(_make_issue(
				"incomplete_setting_section_presentation",
				record_key,
				"ProjectSettings section presentation requires editor_labels and editor_descriptions.",
				"editor_labels",
				"",
				source_id
			))
		else:
			_validate_locale_text_map(
				raw_record["editor_labels"],
				"editor_labels",
				record_key,
				source_id,
				issues
			)
			_validate_locale_text_map(
				raw_record["editor_descriptions"],
				"editor_descriptions",
				record_key,
				source_id,
				issues
			)
		if issues.size() != issue_count_before:
			continue

		var record: Dictionary = _copy_allowed_record(
			raw_record,
			_PROJECT_SETTING_SECTION_RECORD_ALLOWED_KEYS
		)
		record["manifest_package_id"] = package_id
		record["owner_package_id"] = owner_package_id
		record["package_id"] = owner_package_id
		record["source_id"] = source_id
		record["path"] = section_path
		records.append(record)
	return records


## 要求本地化文本为非空字典，包含非空 `en` fallback，且每个语言和值均为非空字符串。
## 不符合条件的键值分别追加到 issues。
## [br]
## @api private
static func _validate_locale_text_map(
	value: Variant,
	field: String,
	record_key: String,
	source_id: String,
	issues: Array[Dictionary]
) -> void:
	if not value is Dictionary:
		issues.append(_make_issue(
			"invalid_setting_locale_map",
			record_key,
			"ProjectSettings presentation locale map must be an object.",
			field,
			str(value),
			source_id
		))
		return

	var text_map: Dictionary = value
	if text_map.is_empty() or not text_map.has("en"):
		issues.append(_make_issue(
			"missing_setting_presentation_fallback",
			record_key,
			"ProjectSettings presentation locale map requires a non-empty en fallback.",
			field,
			"",
			source_id
		))
		return

	for locale_value: Variant in text_map:
		if not locale_value is String:
			issues.append(_make_issue(
				"invalid_setting_presentation_locale",
				record_key,
				"ProjectSettings presentation locale keys must be strings.",
				field,
				str(locale_value),
				source_id
			))
			continue
		var locale: String = locale_value
		var text_value: Variant = text_map[locale_value]
		var localized_text: String = ""
		if text_value is String:
			localized_text = text_value
		if locale.strip_edges().is_empty() or localized_text.strip_edges().is_empty():
			issues.append(_make_issue(
				"invalid_setting_presentation_text",
				record_key,
				"ProjectSettings presentation text must use non-empty locale and string values.",
				field,
				locale,
				source_id
			))


## 校验枚举展示映射为字典，且每个枚举键为非空字符串并关联有效本地化文本表。
## [br]
## @api private
static func _validate_localized_enum_map(
	value: Variant,
	field: String,
	record_key: String,
	source_id: String,
	issues: Array[Dictionary]
) -> void:
	if not value is Dictionary:
		issues.append(_make_issue(
			"invalid_setting_enum_presentation",
			record_key,
			"ProjectSettings enum presentation must be an object.",
			field,
			str(value),
			source_id
		))
		return

	var enum_map: Dictionary = value
	for enum_value: Variant in enum_map:
		if not enum_value is String:
			issues.append(_make_issue(
				"invalid_setting_enum_value",
				record_key,
				"ProjectSettings enum presentation keys must be non-empty strings.",
				field,
				str(enum_value),
				source_id
			))
			continue
		var enum_key: String = enum_value
		if enum_key.strip_edges().is_empty():
			issues.append(_make_issue(
				"invalid_setting_enum_value",
				record_key,
				"ProjectSettings enum presentation keys must be non-empty strings.",
				field,
				enum_key,
				source_id
			))
			continue
		_validate_locale_text_map(
			enum_map[enum_value],
			"%s.%s" % [field, enum_key],
			record_key,
			source_id,
			issues
		)


## 读取指定记录族数组并收集其中的字典项；列表类型或单项类型错误会追加 issue。
## 非字典项被跳过，返回数组中的字典仍引用输入项。
## [br]
## @api private
static func _get_record_dictionaries(
	data: Dictionary,
	record_key: String,
	issues: Array[Dictionary]
) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(data, record_key, [])
	if not (value is Array):
		issues.append(_make_issue("invalid_record_list", record_key, "Contribution record list must be an array.", record_key))
		return records

	var raw_records: Array = value
	for index: int in raw_records.size():
		var raw_record: Variant = raw_records[index]
		if raw_record is Dictionary:
			var record: Dictionary = raw_record
			records.append(record)
			continue
		issues.append(_make_issue(
			"invalid_record_type",
			record_key,
			"Contribution record must be an object.",
			record_key,
			str(index)
		))
	return records


## 累加所有已知记录族的数组长度，超过预算时立即返回当前累计值。
## 非数组字段不计入数量。
## [br]
## @api private
static func _count_manifest_records(data: Dictionary) -> int:
	var count: int = 0
	for record_key: String in empty_records().keys():
		var value: Variant = data.get(record_key, [])
		if value is Array:
			var records: Array = value
			count += records.size()
			if count > _MAX_RECORD_COUNT:
				return count
	return count


## 在单模板和剩余累计字节预算内读取模板文本，并返回文本、实际字节数及累计超限标记。
## 文件打开、读取、空白内容或大小检查失败时追加 issue，文本保持为空。
## [br]
## @api private
static func _read_template_text(
	template_path: String,
	record_key: String,
	issues: Array[Dictionary],
	source_id: String,
	remaining_total_bytes: int
) -> Dictionary:
	var result: Dictionary = {
		"text": "",
		"size_bytes": 0,
		"total_budget_exceeded": false,
	}
	if remaining_total_bytes <= 0:
		issues.append(_make_issue(
			"template_total_budget_exceeded",
			record_key,
			"Editor contribution templates exceed the cumulative byte budget.",
			"template_path",
			str(_MAX_TEMPLATE_TOTAL_BYTES),
			source_id
		))
		result["total_budget_exceeded"] = true
		return result
	var file: FileAccess = FileAccess.open(template_path, FileAccess.READ)
	if file == null:
		issues.append(_make_issue(
			"template_open_failed",
			record_key,
			"Template source file could not be opened.",
			"template_path",
			error_string(FileAccess.get_open_error()),
			source_id
		))
		return result
	var declared_size: int = file.get_length()
	if declared_size > _MAX_TEMPLATE_BYTES:
		file.close()
		issues.append(_make_issue(
			"template_too_large",
			record_key,
			"Template source file exceeds the byte budget.",
			"template_path",
			str(_MAX_TEMPLATE_BYTES),
			source_id
		))
		return result
	if declared_size > remaining_total_bytes:
		file.close()
		issues.append(_make_issue(
			"template_total_budget_exceeded",
			record_key,
			"Editor contribution templates exceed the cumulative byte budget.",
			"template_path",
			str(_MAX_TEMPLATE_TOTAL_BYTES),
			source_id
		))
		result["total_budget_exceeded"] = true
		return result

	var text: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	var actual_size: int = text.to_utf8_buffer().size()
	result["size_bytes"] = actual_size
	if read_error != OK:
		issues.append(_make_issue(
			"template_read_failed",
			record_key,
			"Template source file could not be read.",
			"template_path",
			error_string(read_error),
			source_id
		))
		return result
	if actual_size > _MAX_TEMPLATE_BYTES:
		issues.append(_make_issue(
			"template_too_large",
			record_key,
			"Template source file exceeds the byte budget.",
			"template_path",
			str(_MAX_TEMPLATE_BYTES),
			source_id
		))
		return result
	if actual_size > remaining_total_bytes:
		issues.append(_make_issue(
			"template_total_budget_exceeded",
			record_key,
			"Editor contribution templates exceed the cumulative byte budget.",
			"template_path",
			str(_MAX_TEMPLATE_TOTAL_BYTES),
			source_id
		))
		result["total_budget_exceeded"] = true
		return result
	if text.strip_edges().is_empty():
		issues.append(_make_issue(
			"empty_template",
			record_key,
			"Template source file must contain non-whitespace text.",
			"template_path",
			template_path,
			source_id
		))
		return result
	result["text"] = text
	return result


## 拒绝记录中首个不在对应字段白名单内的键，并把该键记入 issue。
## [br]
## @api private
static func _record_uses_allowed_keys(
	record: Dictionary,
	record_key: String,
	allowed_keys: Array[String],
	issues: Array[Dictionary]
) -> bool:
	for key_value: Variant in record.keys():
		var key: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(key_value)
		if not allowed_keys.has(key):
			issues.append(_make_issue(
				"unknown_record_field",
				record_key,
				"Contribution record field is not part of the stable schema.",
				key
			))
			return false
	return true


## 拒绝 manifest 根对象中首个不在根字段白名单内的键。
## [br]
## @api private
static func _manifest_uses_allowed_keys(
	data: Dictionary,
	manifest_path: String,
	issues: Array[Dictionary]
) -> bool:
	for key_value: Variant in data.keys():
		var key: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(key_value)
		var workspace_key: bool = key in ["task_records", "resource_action_records"]
		var supports_workspace: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(data, "schema_version") == 5
		if not _MANIFEST_ALLOWED_KEYS.has(key) and not (supports_workspace and workspace_key):
			issues.append(_make_issue(
				"unknown_manifest_field",
				manifest_path,
				"Editor contribution manifest field is not part of the stable schema.",
				key
			))
			return false
	return true


## 仅将允许字段复制到新字典；字段值本身不在此处递归复制。
## [br]
## @api private
static func _copy_allowed_record(record: Dictionary, allowed_keys: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for key: String in allowed_keys:
		if record.has(key):
			result[key] = record[key]
	return result


## 读取并清理记录本地 source_id，拒绝缺失值和含冒号的非本地标识，再加上 owner 前缀。
## 无效时追加 issue 并返回空字符串。
## [br]
## @api private
static func _make_source_id(
	owner_package_id: String,
	record: Dictionary,
	record_key: String,
	issues: Array[Dictionary]
) -> String:
	var source_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "source_id").strip_edges()
	if source_id.is_empty():
		issues.append(_make_issue("missing_source_id", record_key, "Contribution record source_id is required.", "source_id"))
		return ""
	if source_id.contains(":"):
		issues.append(_make_issue(
			"invalid_local_source_id",
			record_key,
			"Contribution record source_id must be local to owner_package_id.",
			"source_id",
			source_id
		))
		return ""
	return "%s:%s" % [owner_package_id, source_id]


## 读取并去除 owner_package_id 首尾空白；缺失时追加 issue 并返回空字符串。
## [br]
## @api private
static func _get_owner_package_id(
	record: Dictionary,
	record_key: String,
	issues: Array[Dictionary]
) -> String:
	var owner_package_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		record,
		"owner_package_id"
	).strip_edges()
	if owner_package_id.is_empty():
		issues.append(_make_issue(
			"missing_owner_package_id",
			record_key,
			"Contribution record owner_package_id is required.",
			"owner_package_id"
		))
	return owner_package_id


## 跨所有记录族检查 source_id 与 payload 身份的唯一性，并重写各族为保留项数组。
## 重复项会报告并从重写后的记录族中剔除，首次出现的记录优先保留。
## [br]
## @api private
static func _validate_record_identities(records: Dictionary, issues: Array[Dictionary]) -> void:
	var source_ids: Dictionary = {}
	var payload_ids: Dictionary = {}
	for record_key: String in empty_records().keys():
		var validated_records: Array[Dictionary] = []
		var raw_records: Variant = records.get(record_key, [])
		if not (raw_records is Array):
			continue
		var record_array: Array = raw_records
		for record_value: Variant in record_array:
			if not (record_value is Dictionary):
				continue
			var record: Dictionary = record_value
			var source_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
				record,
				"source_id"
			)
			if source_ids.has(source_id):
				issues.append(_make_issue(
					"duplicate_source_id",
					record_key,
					"Contribution source_id must be globally unique within the manifest.",
					"source_id",
					source_id,
					source_id
				))
				continue

			var payload_id: String = _get_record_payload_id(record)
			if not payload_id.is_empty() and payload_ids.has(payload_id):
				issues.append(_make_issue(
					"duplicate_payload_identity",
					record_key,
					"Contribution payload identity must be globally unique within the manifest.",
					"path",
					payload_id,
					source_id
				))
				continue

			source_ids[source_id] = record_key
			if not payload_id.is_empty():
				payload_ids[payload_id] = source_id
			validated_records.append(record)
		records[record_key] = validated_records


## 按 path、template_path、name 顺序取首个非空文本，并以字段名作为身份前缀。
## 没有可用值时返回空字符串。
## [br]
## @api private
static func _get_record_payload_id(record: Dictionary) -> String:
	for field: String in ["path", "template_path", "name"]:
		var value: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, field).strip_edges()
		if not value.is_empty():
			return "%s:%s" % [field, value]
	return ""


## 优先把 type_name 映射为 Variant 类型；未提供时读取整数 type 字段。
## 缺少两者或遇到未知 type_name 时追加 issue，并回退到 default_value 的实际类型。
## [br]
## @api private
static func _record_variant_type(
	record: Dictionary,
	default_value: Variant,
	record_key: String,
	source_id: String,
	issues: Array[Dictionary]
) -> int:
	var type_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "type_name").strip_edges().to_lower()
	if type_name.is_empty():
		if not record.has("type"):
			issues.append(_make_issue("missing_setting_type", record_key, "ProjectSettings record type_name or type is required.", "type_name", "", source_id))
			return typeof(default_value)
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "type", typeof(default_value))

	match type_name:
		"nil":
			return TYPE_NIL
		"bool":
			return TYPE_BOOL
		"int":
			return TYPE_INT
		"float":
			return TYPE_FLOAT
		"string":
			return TYPE_STRING
		"array":
			return TYPE_ARRAY
		"dictionary":
			return TYPE_DICTIONARY
		_:
			issues.append(_make_issue("unknown_type_name", record_key, "ProjectSettings record type_name is unknown.", "type_name", type_name, source_id))
			return typeof(default_value)


## 接受 GDScript 标识符语法且不是此处列出的语言关键字。
## [br]
## @api private
static func _is_valid_gdscript_identifier(value: String) -> bool:
	if not value.is_valid_identifier():
		return false
	match value:
		"and", "as", "assert", "await", "break", "breakpoint", "class", "class_name", "const", "continue", "elif", "else", "enum", "extends", "false", "for", "func", "if", "in", "is", "match", "not", "null", "or", "pass", "preload", "return", "self", "signal", "static", "super", "true", "var", "void", "while", "yield":
			return false
		_:
			return true


## 组装 manifest 报告并深复制记录、issue 与跳过记录集合。
## 未指定状态时按 ok 和 skipped_records 推导 invalid、degraded 或 valid。
## [br]
## @api private
static func _make_report(
	ok: bool,
	source_path: String,
	records: Dictionary,
	issues: Array[Dictionary],
	skipped_records: Array[Dictionary],
	explicit_state: String = "",
	package_id: String = ""
) -> Dictionary:
	var state: String = explicit_state
	if state.is_empty():
		if not ok:
			state = "invalid"
		elif not skipped_records.is_empty():
			state = "degraded"
		else:
			state = "valid"
	return {
		"ok": ok,
		"state": state,
		"source_path": source_path,
		"package_id": package_id,
		"records": records.duplicate(true),
		"issues": issues.duplicate(true),
		"skipped_records": skipped_records.duplicate(true),
		"issue_count": issues.size(),
		"skipped_record_count": skipped_records.size(),
	}


## 组装 manifest issue 字典；空的 field、actual_value 和 source_id 不加入结果。
## [br]
## @api private
static func _make_issue(
	kind: String,
	path: String,
	message: String,
	field: String = "",
	actual_value: String = "",
	source_id: String = ""
) -> Dictionary:
	var issue: Dictionary = {
		"kind": kind,
		"path": path,
		"message": message,
	}
	if not field.is_empty():
		issue["field"] = field
	if not actual_value.is_empty():
		issue["actual_value"] = actual_value
	if not source_id.is_empty():
		issue["source_id"] = source_id
	return issue
