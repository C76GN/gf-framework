## GFProjectLayoutValidator: Profile 驱动的项目结构校验工具。
##
## 按项目结构 profile 检查目录分区、Feature 模块契约、命名、生成物边界和大桶目录增长。
## 该工具只实现可选制作期校验，不把任意业务项目结构写入 GF 运行时包。
## 未知选项、字段、错误类型和非规范相对路径都会失败关闭；扫描预算在流式枚举期间全局生效。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 8.0.0
class_name GFProjectLayoutValidator
extends RefCounted


# --- 常量 ---

## 内置 Feature 内聚式项目结构 profile 路径。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_FEATURE_COHESIVE_PROFILE_PATH: String = "res://addons/gf/tools/project_layout/profiles/feature_cohesive_v1.json"

const _SCHEMA_VERSION: int = 1
const _RULE_BUCKET_SIZE: String = "bucket_size"
const _RULE_FEATURE_MODULE_CONTRACT: String = "feature_module_contract"
const _RULE_FORBID_ROOT_FILES: String = "forbid_root_files"
const _RULE_GENERATED_BOUNDARY: String = "generated_boundary"
const _RULE_NAMING_CONVENTION: String = "naming_convention"
const _SUPPORTED_RULE_KINDS: PackedStringArray = [
	_RULE_BUCKET_SIZE,
	_RULE_FEATURE_MODULE_CONTRACT,
	_RULE_FORBID_ROOT_FILES,
	_RULE_GENERATED_BOUNDARY,
	_RULE_NAMING_CONVENTION,
]
const _SUPPORTED_SEVERITIES: PackedStringArray = ["error", "warning", "info"]
const _PROFILE_ALLOWED_FIELDS: PackedStringArray = [
	"schema_version",
	"id",
	"display_name",
	"description",
	"zones",
	"rules",
	"metadata",
]
const _ZONE_ALLOWED_FIELDS: PackedStringArray = [
	"id",
	"description",
	"roots",
	"required",
	"allow_extensions",
	"deny_extensions",
	"exclude",
	"severity",
	"metadata",
]
const _RULE_COMMON_ALLOWED_FIELDS: PackedStringArray = [
	"id",
	"description",
	"kind",
	"severity",
	"metadata",
]
const _RULE_RESERVED_FIELDS: PackedStringArray = ["paths", "any", "extensions"]
const _VALIDATOR_OPTION_FIELDS: PackedStringArray = [
	"root_path",
	"include_hidden",
	"max_scanned_files",
	"max_scanned_directories",
	"max_scan_depth",
	"allow_missing_root",
	"allow_absolute_root",
]
const _VALIDATOR_BOOL_OPTION_FIELDS: PackedStringArray = [
	"include_hidden",
	"allow_missing_root",
	"allow_absolute_root",
]
const _VALIDATOR_INTEGER_OPTION_FIELDS: PackedStringArray = [
	"max_scanned_files",
	"max_scanned_directories",
	"max_scan_depth",
]
const _NAMING_TARGETS: PackedStringArray = ["path", "name", "stem"]


# --- 公共方法 ---

## 按内置 Feature 内聚式模板校验项目结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 校验选项。
## [br]
## @schema options: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth、allow_missing_root 和 allow_absolute_root。
## [br]
## @return: 校验报告。
## [br]
## @schema return: Dictionary，包含 success、profile_id、root_path、file_count、directory_count、issues、error_count、warning_count、info_count 和 rule_results。
func validate_default_profile(options: Dictionary = {}) -> Dictionary:
	return validate_profile_path(DEFAULT_FEATURE_COHESIVE_PROFILE_PATH, options)


## 从项目结构 profile 文件校验项目结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param profile_path: JSON profile 路径。
## [br]
## @param options: 校验选项。
## [br]
## @schema options: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth、allow_missing_root 和 allow_absolute_root。
## [br]
## @return: 校验报告。
## [br]
## @schema return: Dictionary，包含 success、profile_id、root_path、file_count、directory_count、issues、error_count、warning_count、info_count 和 rule_results。
func validate_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
	var load_result: Dictionary = _load_profile(profile_path)
	if not _get_bool(load_result, "success"):
		var root_path: String = _report_root_path(options)
		var report: Dictionary = _make_report("", root_path)
		_validate_options(options, report)
		_add_issue(
			report,
			"error",
			_get_string(load_result, "kind", "profile_load_failed"),
			profile_path,
			_get_string(load_result, "error"),
			{ "profile_path": profile_path }
		)
		return _finalize_report(report)

	var profile_value: Variant = load_result.get("profile", {})
	if profile_value is Dictionary:
		var profile: Dictionary = profile_value
		return validate_profile(profile, options)

	var fallback_report: Dictionary = _make_report("", _report_root_path(options))
	_validate_options(options, fallback_report)
	_add_issue(fallback_report, "error", "invalid_profile", profile_path, "项目结构 profile 必须是 Dictionary。")
	return _finalize_report(fallback_report)


## 按已解析的项目结构 profile 校验项目结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param profile: 项目结构 profile 字典。
## [br]
## @schema profile: Dictionary，包含 schema_version、id、zones 和 rules。
## [br]
## @param options: 校验选项。
## [br]
## @schema options: Dictionary，可包含 root_path、include_hidden、max_scanned_files、max_scanned_directories、max_scan_depth、allow_missing_root 和 allow_absolute_root。
## [br]
## @return: 校验报告。
## [br]
## @schema return: Dictionary，包含 success、profile_id、root_path、file_count、directory_count、issues、error_count、warning_count、info_count 和 rule_results。
func validate_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
	var root_path: String = _report_root_path(options)
	var report: Dictionary = _make_report(_get_string(profile, "id"), root_path)
	_validate_options(options, report)
	_validate_profile_header(profile, report)
	_validate_profile_schema(profile, report)
	_validate_root_path(root_path, options, report)
	if _get_int(report, "error_count") > 0:
		return _finalize_report(report)

	var scan: Dictionary = _scan_project(root_path, options, report)
	report["file_count"] = _get_int(scan, "file_count")
	report["directory_count"] = _get_int(scan, "directory_count")
	if _get_int(report, "error_count") > 0:
		return _finalize_report(report)

	_validate_zones(profile, scan, report)
	_validate_rules(profile, scan, report)
	return _finalize_report(report)


# --- 私有/辅助方法 ---

func _load_profile(profile_path: String) -> Dictionary:
	if profile_path.strip_edges().is_empty():
		return _make_load_result(false, {}, "missing_profile_path", "项目结构 profile 路径为空。")
	if not FileAccess.file_exists(profile_path):
		return _make_load_result(false, {}, "profile_path_not_found", "项目结构 profile 不存在：%s。" % profile_path)

	var file: FileAccess = FileAccess.open(profile_path, FileAccess.READ)
	if file == null:
		return _make_load_result(false, {}, "profile_open_failed", "无法读取项目结构 profile：%s。" % profile_path)

	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	if parse_error != OK:
		return _make_load_result(
			false,
			{},
			"profile_json_parse_failed",
			"项目结构 profile JSON 解析失败：%s:%d。" % [parser.get_error_message(), parser.get_error_line()]
		)

	var profile_value: Variant = parser.data
	if profile_value is Dictionary:
		var profile: Dictionary = profile_value
		return _make_load_result(true, profile, "", "")
	return _make_load_result(false, {}, "invalid_profile_root", "项目结构 profile 根节点必须是 Dictionary。")


func _make_load_result(success: bool, profile: Dictionary, kind: String, message: String) -> Dictionary:
	return {
		"success": success,
		"profile": profile,
		"kind": kind,
		"error": message,
	}


func _make_report(profile_id: String, root_path: String) -> Dictionary:
	return {
		"success": true,
		"profile_id": profile_id,
		"root_path": root_path,
		"file_count": 0,
		"directory_count": 0,
		"issues": [],
		"error_count": 0,
		"warning_count": 0,
		"info_count": 0,
		"rule_results": [],
	}


func _report_root_path(options: Dictionary) -> String:
	if not options.has("root_path"):
		return "res://"
	var root_value: Variant = options["root_path"]
	if not (root_value is String or root_value is StringName):
		return ""
	var root_path: String = _string_value(root_value)
	if root_path.strip_edges().is_empty():
		return ""
	return _normalize_root_path(root_path)


func _validate_options(options: Dictionary, report: Dictionary) -> void:
	for key_value: Variant in options.keys():
		var option_name: String = _string_value(key_value)
		if not option_name.is_empty() and _VALIDATOR_OPTION_FIELDS.has(option_name):
			continue
		_add_issue(
			report,
			"error",
			"unsupported_option",
			option_name,
			"项目结构 validator 包含不受支持的选项。",
			{ "actual": _describe_value(key_value) }
		)
	if options.has("root_path"):
		var root_value: Variant = options["root_path"]
		if not (root_value is String or root_value is StringName):
			_add_issue(report, "error", "invalid_option_type", "root_path", "root_path 必须是字符串。", { "actual": _describe_value(root_value) })
		elif _string_value(root_value).strip_edges().is_empty():
			_add_issue(report, "error", "invalid_option_value", "root_path", "root_path 不能为空。")
	for field_name: String in _VALIDATOR_BOOL_OPTION_FIELDS:
		if options.has(field_name) and not options[field_name] is bool:
			_add_issue(report, "error", "invalid_option_type", field_name, "%s 必须是 bool。" % field_name, { "actual": _describe_value(options[field_name]) })
	for field_name: String in _VALIDATOR_INTEGER_OPTION_FIELDS:
		if not options.has(field_name):
			continue
		var value: Variant = options[field_name]
		if value is int and value > 0:
			continue
		_add_issue(
			report,
			"error",
			"invalid_integer_option",
			field_name,
			"项目结构扫描选项 %s 必须是正整数。" % field_name,
			{ "option": field_name, "actual": _describe_value(value) }
		)


func _validate_profile_header(profile: Dictionary, report: Dictionary) -> void:
	var schema_version: Variant = profile.get("schema_version")
	if not _is_exact_integer(schema_version):
		_add_issue(
			report,
			"error",
			"invalid_integer_field",
			"schema_version",
			"项目结构 profile schema_version 必须是整数。",
			{ "field": "schema_version", "actual_type": typeof(schema_version) }
		)
	elif _exact_integer_value(schema_version) != _SCHEMA_VERSION:
		_add_issue(
			report,
			"error",
			"unsupported_schema_version",
			"",
			"项目结构 profile schema_version 必须为 %d。" % _SCHEMA_VERSION,
			{ "actual_value": schema_version }
		)
	if _get_string(profile, "id").is_empty():
		_add_issue(report, "error", "missing_profile_id", "", "项目结构 profile 缺少 id。")


func _validate_profile_schema(profile: Dictionary, report: Dictionary) -> void:
	_append_unsupported_fields(profile, _PROFILE_ALLOWED_FIELDS, "unsupported_profile_field", "profile", report)
	_validate_optional_string_field(profile, "display_name", "profile", report)
	_validate_optional_string_field(profile, "description", "profile", report)
	_validate_optional_dictionary_field(profile, "metadata", "profile", report)
	if not profile.get("zones") is Array:
		_add_issue(report, "error", "invalid_profile_field_type", "zones", "项目结构 profile zones 必须是 Array。")
	if not profile.get("rules") is Array:
		_add_issue(report, "error", "invalid_profile_field_type", "rules", "项目结构 profile rules 必须是 Array。")

	var zone_ids: Dictionary = {}
	var zones: Array = _get_array(profile, "zones")
	for zone_value: Variant in zones:
		if not (zone_value is Dictionary):
			_add_issue(report, "error", "invalid_zone", "", "项目结构 profile zones 条目必须是 Dictionary。")
			continue
		var zone: Dictionary = zone_value
		var zone_id: String = _get_string(zone, "id")
		_append_unsupported_fields(zone, _ZONE_ALLOWED_FIELDS, "unsupported_zone_field", zone_id, report)
		_validate_item_id(zone, "zone", zone_ids, report)
		_validate_optional_string_field(zone, "description", zone_id, report)
		_validate_optional_dictionary_field(zone, "metadata", zone_id, report)
		_validate_optional_bool_field(zone, "required", zone_id, report)
		_validate_relative_path_list_field(zone, "roots", zone_id, true, false, report)
		if zone.has("severity"):
			_validate_profile_severity_field(zone, "zones", zone_id, report)

	var rule_ids: Dictionary = {}
	var rules: Array = _get_array(profile, "rules")
	for rule_value: Variant in rules:
		if not (rule_value is Dictionary):
			_add_issue(report, "error", "invalid_rule", "", "项目结构 profile rules 条目必须是 Dictionary。")
			continue
		var rule: Dictionary = rule_value
		var rule_id: String = _get_string(rule, "id")
		var kind: String = _get_string(rule, "kind")
		_append_unsupported_fields(rule, _allowed_rule_fields(kind), "unsupported_rule_field", rule_id, report)
		_validate_item_id(rule, "rule", rule_ids, report)
		var _rule_kind_valid: bool = _validate_required_string_field(rule, "kind", rule_id, report)
		_validate_optional_string_field(rule, "description", rule_id, report)
		_validate_optional_dictionary_field(rule, "metadata", rule_id, report)
		if not _SUPPORTED_RULE_KINDS.has(kind):
			_add_issue(
				report,
				"error",
				"unsupported_rule_kind",
				kind,
				"项目结构 profile 包含未知规则类型：%s。" % kind,
				{ "rule_id": _get_string(rule, "id") }
			)
		if rule.has("severity"):
			_validate_profile_severity_field(rule, "rules", rule_id, report)
		_validate_rule_fields(rule, kind, rule_id, report)


func _allowed_rule_fields(kind: String) -> PackedStringArray:
	var result: PackedStringArray = _RULE_COMMON_ALLOWED_FIELDS.duplicate()
	for field_name: String in _RULE_RESERVED_FIELDS:
		var _append_reserved_field: bool = result.append(field_name)
	var kind_fields: PackedStringArray = PackedStringArray()
	if kind == _RULE_FORBID_ROOT_FILES:
		kind_fields = PackedStringArray(["allowed_files"])
	elif kind == _RULE_NAMING_CONVENTION:
		kind_fields = PackedStringArray(["roots", "exclude", "pattern", "target"])
	elif kind == _RULE_FEATURE_MODULE_CONTRACT:
		kind_fields = PackedStringArray([
			"roots",
			"feature_id_pattern",
			"required_subdirs",
			"allowed_subdirs",
			"allow_root_files",
		])
	elif kind == _RULE_GENERATED_BOUNDARY:
		kind_fields = PackedStringArray(["include", "roots"])
	elif kind == _RULE_BUCKET_SIZE:
		kind_fields = PackedStringArray(["roots", "max_files"])
	for field_name: String in kind_fields:
		var _append_kind_field: bool = result.append(field_name)
	return result


func _validate_rule_fields(rule: Dictionary, kind: String, rule_id: String, report: Dictionary) -> void:
	if kind == _RULE_FORBID_ROOT_FILES:
		_validate_relative_path_list_field(rule, "allowed_files", rule_id, false, true, report)
	elif kind == _RULE_NAMING_CONVENTION:
		_validate_relative_path_list_field(rule, "roots", rule_id, false, true, report)
		_validate_pattern_list_field(rule, "exclude", rule_id, false, report)
		_validate_optional_non_empty_string_field(rule, "pattern", rule_id, report)
		_validate_naming_target(rule, rule_id, report)
	elif kind == _RULE_FEATURE_MODULE_CONTRACT:
		_validate_relative_path_list_field(rule, "roots", rule_id, true, false, report)
		_validate_optional_non_empty_string_field(rule, "feature_id_pattern", rule_id, report)
		_validate_relative_path_list_field(rule, "required_subdirs", rule_id, false, true, report)
		_validate_relative_path_list_field(rule, "allowed_subdirs", rule_id, false, true, report)
		_validate_optional_bool_field(rule, "allow_root_files", rule_id, report)
	elif kind == _RULE_GENERATED_BOUNDARY:
		_validate_pattern_list_field(rule, "include", rule_id, true, report)
		_validate_relative_path_list_field(rule, "roots", rule_id, true, false, report)
	elif kind == _RULE_BUCKET_SIZE:
		_validate_relative_path_list_field(rule, "roots", rule_id, true, false, report)
		if rule.has("max_files"):
			_validate_positive_integer_field(rule, "max_files", rule_id, report)


func _validate_item_id(data: Dictionary, item_kind: String, seen_ids: Dictionary, report: Dictionary) -> void:
	var item_id: String = _get_string(data, "id")
	if not _validate_required_string_field(data, "id", item_kind, report):
		return
	if seen_ids.has(item_id):
		_add_issue(
			report,
			"error",
			"duplicate_profile_id",
			item_id,
			"项目结构 profile 包含重复 %s id：%s。" % [item_kind, item_id],
			{ "item_kind": item_kind }
		)
		return
	seen_ids[item_id] = true


func _validate_required_string_field(data: Dictionary, field_name: String, scope: String, report: Dictionary) -> bool:
	if not data.has(field_name) or not _is_non_empty_string_value(data[field_name]):
		_add_issue(
			report,
			"error",
			"invalid_string_field",
			scope,
			"项目结构 profile %s 必须是非空字符串。" % field_name,
			{ "field": field_name, "actual": _describe_value(data.get(field_name)) }
		)
		return false
	return true


func _validate_optional_string_field(data: Dictionary, field_name: String, scope: String, report: Dictionary) -> void:
	if not data.has(field_name):
		return
	var value: Variant = data[field_name]
	if value is String or value is StringName:
		return
	_add_issue(
		report,
		"error",
		"invalid_string_field",
		scope,
		"项目结构 profile %s 必须是字符串。" % field_name,
		{ "field": field_name, "actual": _describe_value(value) }
	)


func _validate_optional_non_empty_string_field(
	data: Dictionary,
	field_name: String,
	scope: String,
	report: Dictionary
) -> void:
	if not data.has(field_name):
		return
	var _field_valid: bool = _validate_required_string_field(data, field_name, scope, report)


func _validate_optional_dictionary_field(data: Dictionary, field_name: String, scope: String, report: Dictionary) -> void:
	if not data.has(field_name) or data[field_name] is Dictionary:
		return
	_add_issue(
		report,
		"error",
		"invalid_profile_field_type",
		scope,
		"项目结构 profile %s 必须是 Dictionary。" % field_name,
		{ "field": field_name, "actual": _describe_value(data[field_name]) }
	)


func _validate_optional_bool_field(data: Dictionary, field_name: String, scope: String, report: Dictionary) -> void:
	if not data.has(field_name) or data[field_name] is bool:
		return
	_add_issue(
		report,
		"error",
		"invalid_bool_field",
		scope,
		"项目结构 profile %s 必须是 bool。" % field_name,
		{ "field": field_name, "actual": _describe_value(data[field_name]) }
	)


func _validate_relative_path_list_field(
	data: Dictionary,
	field_name: String,
	scope: String,
	required: bool,
	allow_empty: bool,
	report: Dictionary
) -> void:
	if not _validate_string_list_field(data, field_name, scope, required, allow_empty, report):
		return
	for path_value: String in _get_string_list(data, field_name):
		if not _profile_relative_path_is_invalid(path_value):
			continue
		_add_issue(
			report,
			"error",
			"invalid_relative_path",
			path_value,
			"项目结构 profile %s 包含非法或非规范相对路径。" % field_name,
			{ "field": field_name, "scope": scope }
		)


func _validate_pattern_list_field(
	data: Dictionary,
	field_name: String,
	scope: String,
	required: bool,
	report: Dictionary
) -> void:
	if not _validate_string_list_field(data, field_name, scope, required, not required, report):
		return
	for pattern: String in _get_string_list(data, field_name):
		if not _profile_pattern_is_invalid(pattern):
			continue
		_add_issue(
			report,
			"error",
			"invalid_relative_path",
			pattern,
			"项目结构 profile %s 包含非法或非规范路径模式。" % field_name,
			{ "field": field_name, "scope": scope }
		)


func _validate_string_list_field(
	data: Dictionary,
	field_name: String,
	scope: String,
	required: bool,
	allow_empty: bool,
	report: Dictionary
) -> bool:
	if not data.has(field_name):
		if required:
			_add_issue(report, "error", "invalid_string_list_field", scope, "项目结构 profile 缺少 %s 字符串列表。" % field_name, { "field": field_name })
		return not required
	var value: Variant = data[field_name]
	if not (value is Array or value is PackedStringArray):
		_add_issue(
			report,
			"error",
			"invalid_string_list_field",
			scope,
			"项目结构 profile %s 必须是字符串数组。" % field_name,
			{ "field": field_name, "actual": _describe_value(value) }
		)
		return false
	var values: Array = []
	if value is Array:
		values = value
	else:
		var packed_values: PackedStringArray = value
		for packed_value: String in packed_values:
			values.append(packed_value)
	if not allow_empty and values.is_empty():
		_add_issue(report, "error", "invalid_string_list_field", scope, "项目结构 profile %s 不能为空。" % field_name, { "field": field_name })
		return false
	var valid: bool = true
	for item: Variant in values:
		if _is_non_empty_string_value(item):
			continue
		valid = false
		_add_issue(
			report,
			"error",
			"invalid_string_list_field",
			scope,
			"项目结构 profile %s 只能包含非空字符串。" % field_name,
			{ "field": field_name, "actual": _describe_value(item) }
		)
	return valid


func _validate_naming_target(rule: Dictionary, rule_id: String, report: Dictionary) -> void:
	if not rule.has("target"):
		return
	var target_value: Variant = rule["target"]
	var target: String = _string_value(target_value)
	if _NAMING_TARGETS.has(target):
		return
	_add_issue(
		report,
		"error",
		"invalid_naming_target",
		rule_id,
		"项目结构 naming_convention target 必须是 path、name 或 stem。",
		{ "actual": _describe_value(target_value) }
	)


func _append_unsupported_fields(
	data: Dictionary,
	allowed_fields: PackedStringArray,
	issue_kind: String,
	scope: String,
	report: Dictionary
) -> void:
	for field_value: Variant in data.keys():
		var field_name: String = _string_value(field_value)
		if field_name.is_empty():
			_add_issue(
				report,
				"error",
				issue_kind,
				scope,
				"项目结构 profile 字段名必须是非空字符串。",
				{ "actual": _describe_value(field_value) }
			)
			continue
		if allowed_fields.has(field_name):
			continue
		_add_issue(
			report,
			"error",
			issue_kind,
			scope,
			"项目结构 profile 包含不受支持的字段：%s。" % field_name,
			{ "field": field_name }
		)


func _validate_positive_integer_field(data: Dictionary, field_name: String, scope: String, report: Dictionary) -> void:
	var value: Variant = data.get(field_name)
	if _is_exact_integer(value) and _exact_integer_value(value) > 0:
		return
	_add_issue(
		report,
		"error",
		"invalid_integer_field",
		scope,
		"项目结构 profile %s 必须是正整数。" % field_name,
		{ "field": field_name, "actual": _describe_value(value) }
	)


func _validate_profile_severity_field(data: Dictionary, scope: String, item_id: String, report: Dictionary) -> void:
	var severity_value: Variant = data.get("severity")
	var severity: String = _string_value(severity_value)
	if _SUPPORTED_SEVERITIES.has(severity):
		return
	_add_issue(
		report,
		"error",
		"invalid_severity",
		item_id,
		"项目结构 profile %s 使用了非法 severity：%s。" % [scope, severity],
		{ "actual": _describe_value(severity_value) }
	)


func _validate_root_path(root_path: String, options: Dictionary, report: Dictionary) -> void:
	if root_path.is_empty():
		_add_issue(report, "error", "empty_root_path", root_path, "项目根路径为空。")
		return
	if _path_has_parent_segment(root_path):
		_add_issue(report, "error", "root_path_has_parent_segment", root_path, "项目根路径不能包含父级越界片段。")
		return
	if _path_crosses_link(root_path):
		_add_issue(report, "error", "linked_path_not_allowed", root_path, "项目根路径不能穿过符号链接或目录联接。")
		return
	if root_path.begins_with("res://") or root_path.begins_with("user://"):
		return
	if _is_filesystem_absolute_path(root_path) and _get_bool(options, "allow_absolute_root"):
		return
	_add_issue(report, "error", "unsupported_root_path", root_path, "项目根路径必须使用 res://、user://，或显式允许绝对路径。")


func _scan_project(root_path: String, options: Dictionary, report: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"files": PackedStringArray(),
		"directories": PackedStringArray(),
		"file_count": 0,
		"directory_count": 0,
		"_scan_aborted": false,
	}
	var absolute_root: String = ProjectSettings.globalize_path(root_path)
	if not DirAccess.dir_exists_absolute(absolute_root):
		if not _get_bool(options, "allow_missing_root"):
			_add_issue(report, "error", "root_path_not_found", root_path, "项目根目录不存在。")
		var _missing_root_scan_state_removed: bool = result.erase("_scan_aborted")
		return result

	var max_scanned_files: int = _get_positive_integer_option(options, "max_scanned_files", 20000, report)
	var max_scanned_directories: int = _get_positive_integer_option(options, "max_scanned_directories", 20000, report)
	var max_scan_depth: int = _get_positive_integer_option(options, "max_scan_depth", 32, report)
	if _get_int(report, "error_count") > 0:
		var _invalid_budget_scan_state_removed: bool = result.erase("_scan_aborted")
		return result
	_scan_directory(root_path, "", _get_bool(options, "include_hidden"), max_scanned_files, max_scanned_directories, max_scan_depth, 0, result, report)
	var _scan_state_removed: bool = result.erase("_scan_aborted")
	return result


func _scan_directory(
	root_path: String,
	relative_path: String,
	include_hidden: bool,
	max_scanned_files: int,
	max_scanned_directories: int,
	max_scan_depth: int,
	depth: int,
	result: Dictionary,
	report: Dictionary
) -> void:
	if _get_bool(result, "_scan_aborted"):
		return
	if depth > max_scan_depth:
		_abort_scan(result, report, "scan_depth_limit_reached", root_path, "项目结构扫描超过目录深度上限，无法证明项目结构有效。")
		return

	var current_path: String = root_path if relative_path.is_empty() else root_path.path_join(relative_path)
	var directory: DirAccess = DirAccess.open(ProjectSettings.globalize_path(current_path))
	if directory == null:
		_abort_scan(result, report, "directory_scan_failed", current_path, "目录无法扫描，无法证明项目结构有效。")
		return
	var list_begin_result: Error = directory.list_dir_begin()
	if list_begin_result != OK:
		_abort_scan(result, report, "directory_scan_failed", current_path, "目录无法枚举，无法证明项目结构有效。")
		return

	var entry_name: String = directory.get_next()
	while not entry_name.is_empty() and not _get_bool(result, "_scan_aborted"):
		if entry_name == "." or entry_name == ".." or (not include_hidden and entry_name.begins_with(".")):
			entry_name = directory.get_next()
			continue
		var entry_path: String = _join_relative_path(relative_path, entry_name)
		if directory.is_link(entry_name):
			_abort_scan(
				result,
				report,
				"linked_path_not_allowed",
				root_path.path_join(entry_path),
				"项目结构扫描不允许符号链接或目录联接。"
			)
			break
		if directory.current_is_dir():
			if _get_int(result, "directory_count") >= max_scanned_directories:
				_abort_scan(result, report, "scan_directory_limit_reached", root_path, "项目结构扫描超过目录数量上限，无法证明项目结构有效。")
				break
			var directory_list: PackedStringArray = _get_packed_string_array(result, "directories")
			var _append_directory: bool = directory_list.append(entry_path)
			result["directories"] = directory_list
			result["directory_count"] = _get_int(result, "directory_count") + 1
			_scan_directory(
				root_path,
				entry_path,
				include_hidden,
				max_scanned_files,
				max_scanned_directories,
				max_scan_depth,
				depth + 1,
				result,
				report
			)
		else:
			if _get_int(result, "file_count") >= max_scanned_files:
				_abort_scan(result, report, "scan_file_limit_reached", root_path, "项目结构扫描超过文件数量上限，无法证明项目结构有效。")
				break
			var file_list: PackedStringArray = _get_packed_string_array(result, "files")
			var _append_file: bool = file_list.append(entry_path)
			result["files"] = file_list
			result["file_count"] = _get_int(result, "file_count") + 1
		entry_name = directory.get_next()
	directory.list_dir_end()


func _abort_scan(
	result: Dictionary,
	report: Dictionary,
	kind: String,
	path: String,
	message: String
) -> void:
	if _get_bool(result, "_scan_aborted"):
		return
	result["_scan_aborted"] = true
	_add_issue(report, "error", kind, path, message)


func _validate_zones(profile: Dictionary, scan: Dictionary, report: Dictionary) -> void:
	var zones: Array = _get_array(profile, "zones")
	for zone_value: Variant in zones:
		if not (zone_value is Dictionary):
			_add_issue(report, "error", "invalid_zone", "", "项目结构 profile zones 条目必须是 Dictionary。")
			continue

		var zone: Dictionary = zone_value
		var severity: String = _get_string(zone, "severity", "error")
		if not _get_bool(zone, "required"):
			continue

		var roots: PackedStringArray = _get_string_list(zone, "roots")
		for relative_root: String in roots:
			var normalized_root: String = _normalize_relative_path(relative_root)
			if normalized_root.is_empty():
				continue
			if not _path_exists_in_scan(normalized_root, scan):
				_add_issue(
					report,
					severity,
					"missing_required_zone_root",
					normalized_root,
					"项目结构缺少必需目录：%s。" % normalized_root,
					{ "zone_id": _get_string(zone, "id") }
				)


func _validate_rules(profile: Dictionary, scan: Dictionary, report: Dictionary) -> void:
	var rules: Array = _get_array(profile, "rules")
	for rule_value: Variant in rules:
		if not (rule_value is Dictionary):
			_add_issue(report, "error", "invalid_rule", "", "项目结构 profile rules 条目必须是 Dictionary。")
			continue

		var rule: Dictionary = rule_value
		var rule_result: Dictionary = _make_rule_result(rule)
		var kind: String = _get_string(rule, "kind")
		if kind == _RULE_FORBID_ROOT_FILES:
			_validate_forbid_root_files(rule, scan, report, rule_result)
		elif kind == _RULE_NAMING_CONVENTION:
			_validate_naming_convention(rule, scan, report, rule_result)
		elif kind == _RULE_FEATURE_MODULE_CONTRACT:
			_validate_feature_module_contract(rule, scan, report, rule_result)
		elif kind == _RULE_GENERATED_BOUNDARY:
			_validate_generated_boundary(rule, scan, report, rule_result)
		elif kind == _RULE_BUCKET_SIZE:
			_validate_bucket_size(rule, scan, report, rule_result)
		else:
			_add_issue(report, "error", "unsupported_rule_kind", kind, "项目结构 profile 包含未知规则类型。")
		_finalize_rule_result(rule_result, report)


func _validate_forbid_root_files(rule: Dictionary, scan: Dictionary, report: Dictionary, rule_result: Dictionary) -> void:
	var allowed_files: PackedStringArray = _get_string_list(rule, "allowed_files")
	var severity: String = _get_string(rule, "severity", "warning")
	var files: PackedStringArray = _get_packed_string_array(scan, "files")
	for file_path: String in files:
		if file_path.contains("/"):
			continue
		rule_result["checked_count"] = _get_int(rule_result, "checked_count") + 1
		if not allowed_files.has(file_path):
			_add_rule_issue(
				report,
				rule_result,
				severity,
				"forbidden_root_file",
				file_path,
				"项目根目录文件未被 profile 声明：%s。" % file_path
			)


func _validate_naming_convention(rule: Dictionary, scan: Dictionary, report: Dictionary, rule_result: Dictionary) -> void:
	var pattern: String = _get_string(rule, "pattern", "^[a-z0-9_./-]+$")
	var target: String = _get_string(rule, "target", "path")
	var expression: RegEx = _compile_regex(pattern)
	if expression == null:
		_add_rule_issue(report, rule_result, "error", "invalid_naming_pattern", "", "路径命名规则正则无法编译。")
		return

	var severity: String = _get_string(rule, "severity", "warning")
	var roots: PackedStringArray = _get_string_list(rule, "roots")
	var exclude: PackedStringArray = _get_string_list(rule, "exclude")
	var all_paths: PackedStringArray = _make_scanned_paths(scan)
	for relative_path: String in all_paths:
		if not _is_under_any_root(relative_path, roots):
			continue
		if _matches_any_pattern(relative_path, exclude):
			continue
		rule_result["checked_count"] = _get_int(rule_result, "checked_count") + 1
		var target_value: String = _naming_target_value(relative_path, target)
		if expression.search(target_value) == null:
			_add_rule_issue(
				report,
				rule_result,
				severity,
				"path_naming_mismatch",
				relative_path,
				"项目路径不符合命名约定：%s。" % relative_path,
				{ "pattern": pattern, "target": target, "target_value": target_value }
			)


func _naming_target_value(relative_path: String, target: String) -> String:
	if target == "name":
		return relative_path.get_file()
	if target == "stem":
		return relative_path.get_file().get_basename()
	return relative_path


func _validate_feature_module_contract(rule: Dictionary, scan: Dictionary, report: Dictionary, rule_result: Dictionary) -> void:
	var severity: String = _get_string(rule, "severity", "error")
	var feature_id_pattern: String = _get_string(rule, "feature_id_pattern", "^[a-z][a-z0-9_]*$")
	var expression: RegEx = _compile_regex(feature_id_pattern)
	if expression == null:
		_add_rule_issue(report, rule_result, "error", "invalid_feature_id_pattern", "", "Feature ID 正则无法编译。")
		return

	var roots: PackedStringArray = _get_string_list(rule, "roots")
	var required_subdirs: PackedStringArray = _get_string_list(rule, "required_subdirs")
	var allowed_subdirs: PackedStringArray = _get_string_list(rule, "allowed_subdirs")
	for root: String in roots:
		var normalized_root: String = _normalize_relative_path(root)
		var feature_ids: PackedStringArray = _get_direct_child_directories(scan, normalized_root)
		for feature_id: String in feature_ids:
			rule_result["checked_count"] = _get_int(rule_result, "checked_count") + 1
			var feature_root: String = normalized_root.path_join(feature_id)
			if expression.search(feature_id) == null:
				_add_rule_issue(
					report,
					rule_result,
					severity,
					"invalid_feature_id",
					feature_root,
					"Feature 目录名不符合 profile 约定：%s。" % feature_id,
					{ "pattern": feature_id_pattern }
				)
			_validate_feature_subdirs(rule, scan, report, rule_result, feature_root, required_subdirs, allowed_subdirs, severity)
			if not _get_bool(rule, "allow_root_files"):
				_validate_feature_root_files(scan, report, rule_result, feature_root, severity)


func _validate_feature_subdirs(
	rule: Dictionary,
	scan: Dictionary,
	report: Dictionary,
	rule_result: Dictionary,
	feature_root: String,
	required_subdirs: PackedStringArray,
	allowed_subdirs: PackedStringArray,
	severity: String
) -> void:
	var child_dirs: PackedStringArray = _get_direct_child_directories(scan, feature_root)
	for required_subdir: String in required_subdirs:
		var required_path: String = feature_root.path_join(required_subdir)
		if not child_dirs.has(required_subdir):
			_add_rule_issue(
				report,
				rule_result,
				severity,
				"missing_feature_subdir",
				required_path,
				"Feature 模块缺少必需子目录：%s。" % required_path
			)

	for child_dir: String in child_dirs:
		if allowed_subdirs.has(child_dir):
			continue
		_add_rule_issue(
			report,
			rule_result,
			severity,
			"unsupported_feature_subdir",
			feature_root.path_join(child_dir),
			"Feature 模块包含未声明子目录：%s。" % child_dir,
			{ "rule_id": _get_string(rule, "id") }
		)


func _validate_feature_root_files(
	scan: Dictionary,
	report: Dictionary,
	rule_result: Dictionary,
	feature_root: String,
	severity: String
) -> void:
	var files: PackedStringArray = _get_packed_string_array(scan, "files")
	for file_path: String in files:
		if _get_parent_path(file_path) != feature_root:
			continue
		_add_rule_issue(
			report,
			rule_result,
			severity,
			"feature_root_file",
			file_path,
			"Feature 模块根目录不应直接放置文件：%s。" % file_path
		)


func _validate_generated_boundary(rule: Dictionary, scan: Dictionary, report: Dictionary, rule_result: Dictionary) -> void:
	var include: PackedStringArray = _get_string_list(rule, "include")
	var roots: PackedStringArray = _get_string_list(rule, "roots")
	var severity: String = _get_string(rule, "severity", "error")
	var all_paths: PackedStringArray = _make_scanned_paths(scan)
	for relative_path: String in all_paths:
		if not _matches_any_pattern(relative_path, include):
			continue
		rule_result["checked_count"] = _get_int(rule_result, "checked_count") + 1
		if not _is_under_any_root(relative_path, roots):
			_add_rule_issue(
				report,
				rule_result,
				severity,
				"generated_path_outside_roots",
				relative_path,
				"生成物路径必须位于 profile 声明的 generated roots 中：%s。" % relative_path
			)


func _validate_bucket_size(rule: Dictionary, scan: Dictionary, report: Dictionary, rule_result: Dictionary) -> void:
	var max_files: int = maxi(_get_int(rule, "max_files", 40), 1)
	var severity: String = _get_string(rule, "severity", "warning")
	var roots: PackedStringArray = _get_string_list(rule, "roots")
	for root: String in roots:
		var count: int = _count_files_under_root(scan, root)
		rule_result["checked_count"] = _get_int(rule_result, "checked_count") + 1
		if count > max_files:
			_add_rule_issue(
				report,
				rule_result,
				severity,
				"bucket_size_exceeded",
				_normalize_relative_path(root),
				"大桶目录文件数量超过上限：%d > %d。" % [count, max_files],
				{ "file_count": count, "max_files": max_files }
			)


func _make_rule_result(rule: Dictionary) -> Dictionary:
	return {
		"id": _get_string(rule, "id"),
		"kind": _get_string(rule, "kind"),
		"severity": _get_string(rule, "severity", "warning"),
		"checked_count": 0,
		"issue_count": 0,
		"success": true,
	}


func _finalize_rule_result(rule_result: Dictionary, report: Dictionary) -> void:
	rule_result["success"] = _get_int(rule_result, "issue_count") == 0
	var rule_results: Array = _get_array(report, "rule_results")
	rule_results.append(rule_result.duplicate(true))


func _add_rule_issue(
	report: Dictionary,
	rule_result: Dictionary,
	severity: String,
	kind: String,
	path: String,
	message: String,
	context: Dictionary = {}
) -> void:
	rule_result["issue_count"] = _get_int(rule_result, "issue_count") + 1
	_add_issue(report, severity, kind, path, message, context)


func _add_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	path: String,
	message: String,
	context: Dictionary = {}
) -> void:
	var issues: Array = _get_array(report, "issues")
	issues.append({
		"severity": severity,
		"kind": kind,
		"path": path,
		"message": message,
		"context": _sanitize_issue_context(context),
	})
	if severity == "error":
		report["error_count"] = _get_int(report, "error_count") + 1
	elif severity == "warning":
		report["warning_count"] = _get_int(report, "warning_count") + 1
	else:
		report["info_count"] = _get_int(report, "info_count") + 1


func _sanitize_issue_context(context: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var entry_index: int = 0
	for key_value: Variant in context.keys():
		var key: String = _string_value(key_value)
		if key.is_empty():
			key = "entry_%d" % entry_index
		result[key] = _sanitize_report_value(context[key_value], 0)
		entry_index += 1
	return result


func _sanitize_report_value(value: Variant, depth: int) -> Variant:
	if depth >= 8:
		return _describe_value(value)
	if value == null or value is bool or value is int or value is String:
		return value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	if value is float:
		var float_value: float = value
		if is_finite(float_value):
			return float_value
		return "NaN" if is_nan(float_value) else ("+Inf" if float_value > 0.0 else "-Inf")
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	if value is Array:
		var array_result: Array = []
		var array_value: Array = value
		for index: int in mini(array_value.size(), 128):
			array_result.append(_sanitize_report_value(array_value[index], depth + 1))
		return array_result
	if value is Dictionary:
		var dictionary_result: Dictionary = {}
		var dictionary_value: Dictionary = value
		var entry_index: int = 0
		for key_value: Variant in dictionary_value.keys():
			if entry_index >= 128:
				break
			var key: String = _string_value(key_value)
			if key.is_empty():
				key = "entry_%d" % entry_index
			dictionary_result[key] = _sanitize_report_value(dictionary_value[key_value], depth + 1)
			entry_index += 1
		return dictionary_result
	return _describe_value(value)


func _describe_value(value: Variant) -> Dictionary:
	var value_type: int = typeof(value)
	var result: Dictionary = {
		"type": value_type,
		"type_name": type_string(value_type),
	}
	if value == null or value is bool or value is int or value is String:
		result["value"] = value
	elif value is StringName:
		var string_name_value: StringName = value
		result["value"] = String(string_name_value)
	elif value is float:
		var float_value: float = value
		if is_finite(float_value):
			result["value"] = float_value
		elif is_nan(float_value):
			result["value"] = "NaN"
		else:
			result["value"] = "+Inf" if float_value > 0.0 else "-Inf"
	elif value is Array:
		var array_value: Array = value
		result["count"] = array_value.size()
	elif value is Dictionary:
		var dictionary_value: Dictionary = value
		result["count"] = dictionary_value.size()
	elif value is PackedStringArray:
		var packed_value: PackedStringArray = value
		result["count"] = packed_value.size()
	return result


func _finalize_report(report: Dictionary) -> Dictionary:
	report["success"] = _get_int(report, "error_count") == 0
	return report


func _path_exists_in_scan(relative_path: String, scan: Dictionary) -> bool:
	var directories: PackedStringArray = _get_packed_string_array(scan, "directories")
	if directories.has(relative_path):
		return true
	var files: PackedStringArray = _get_packed_string_array(scan, "files")
	return files.has(relative_path)


func _make_scanned_paths(scan: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var directories: PackedStringArray = _get_packed_string_array(scan, "directories")
	for directory_path: String in directories:
		var _append_directory: bool = result.append(directory_path)
	var files: PackedStringArray = _get_packed_string_array(scan, "files")
	for file_path: String in files:
		var _append_file: bool = result.append(file_path)
	return result


func _get_direct_child_directories(scan: Dictionary, root: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var normalized_root: String = _normalize_relative_path(root)
	var directories: PackedStringArray = _get_packed_string_array(scan, "directories")
	for directory_path: String in directories:
		if not _is_path_under_root(directory_path, normalized_root):
			continue
		var remainder: String = _relative_remainder(directory_path, normalized_root)
		if remainder.is_empty() or remainder.contains("/"):
			continue
		if not result.has(remainder):
			var _append_child: bool = result.append(remainder)
	return result


func _count_files_under_root(scan: Dictionary, root: String) -> int:
	var count: int = 0
	var normalized_root: String = _normalize_relative_path(root)
	var files: PackedStringArray = _get_packed_string_array(scan, "files")
	for file_path: String in files:
		if _is_path_under_root(file_path, normalized_root):
			count += 1
	return count


func _is_under_any_root(relative_path: String, roots: PackedStringArray) -> bool:
	if roots.is_empty():
		return true
	for root: String in roots:
		if _is_path_under_root(relative_path, _normalize_relative_path(root)):
			return true
	return false


func _is_path_under_root(relative_path: String, root: String) -> bool:
	if root.is_empty():
		return true
	return relative_path == root or relative_path.begins_with("%s/" % root)


func _relative_remainder(relative_path: String, root: String) -> String:
	if root.is_empty():
		return relative_path
	if relative_path == root:
		return ""
	if relative_path.begins_with("%s/" % root):
		return relative_path.substr(root.length() + 1)
	return ""


func _matches_any_pattern(relative_path: String, patterns: PackedStringArray) -> bool:
	if patterns.is_empty():
		return false
	for pattern: String in patterns:
		if _matches_pattern(relative_path, pattern):
			return true
	return false


func _matches_pattern(relative_path: String, pattern: String) -> bool:
	if pattern == "**/generated/**":
		return relative_path == "generated" or relative_path.begins_with("generated/") or relative_path.contains("/generated/")
	if pattern == "**/*.generated.*":
		return relative_path.get_file().contains(".generated.")
	if pattern.begins_with("**/*."):
		return relative_path.get_extension().to_lower() == pattern.substr(5).to_lower()
	if pattern.begins_with("**/") and pattern.ends_with("/**"):
		var middle: String = pattern.substr(3, pattern.length() - 6)
		return relative_path == middle or relative_path.begins_with("%s/" % middle) or relative_path.contains("/%s/" % middle)
	if pattern.begins_with("**/"):
		return relative_path.ends_with(pattern.substr(3))
	if pattern.contains("/**/") and pattern.ends_with("/**"):
		return _matches_middle_double_star_root(relative_path, pattern)
	if pattern.ends_with("/**"):
		var root: String = pattern.substr(0, pattern.length() - 3)
		return _is_path_under_root(relative_path, root)
	if pattern.contains("*"):
		var expression: RegEx = _compile_glob(pattern)
		return expression != null and expression.search(relative_path) != null
	return relative_path == pattern


func _matches_middle_double_star_root(relative_path: String, pattern: String) -> bool:
	var parts: PackedStringArray = pattern.split("/**/", true, 1)
	if parts.size() != 2:
		return false
	var prefix: String = parts[0]
	var suffix: String = parts[1]
	if suffix.ends_with("/**"):
		suffix = suffix.substr(0, suffix.length() - 3)
	if suffix.is_empty():
		return _is_path_under_root(relative_path, prefix)
	if not _is_path_under_root(relative_path, prefix):
		return false
	var remainder: String = _relative_remainder(relative_path, prefix)
	if remainder.is_empty():
		return false
	return remainder == suffix or remainder.begins_with("%s/" % suffix) or remainder.contains("/%s/" % suffix)


func _compile_glob(pattern: String) -> RegEx:
	var escaped: String = ""
	var index: int = 0
	while index < pattern.length():
		var character: String = pattern.substr(index, 1)
		if character == "*":
			if index + 1 < pattern.length() and pattern.substr(index + 1, 1) == "*":
				escaped += ".*"
				index += 2
			else:
				escaped += "[^/]*"
				index += 1
			continue
		if character == "?":
			escaped += "[^/]"
			index += 1
			continue
		if "\\.^$+{}[]()|".contains(character):
			escaped += "\\%s" % character
		else:
			escaped += character
		index += 1
	var expression: RegEx = RegEx.new()
	var compile_result: Error = expression.compile("^%s$" % escaped)
	if compile_result != OK:
		return null
	return expression


func _compile_regex(pattern: String) -> RegEx:
	var expression: RegEx = RegEx.new()
	var compile_result: Error = expression.compile(pattern)
	if compile_result != OK:
		return null
	return expression


func _join_relative_path(base_path: String, file_name: String) -> String:
	if base_path.is_empty():
		return file_name.replace("\\", "/")
	return base_path.path_join(file_name).replace("\\", "/")


func _get_parent_path(relative_path: String) -> String:
	var slash_index: int = relative_path.rfind("/")
	if slash_index < 0:
		return ""
	return relative_path.substr(0, slash_index)


func _normalize_relative_path(path: String) -> String:
	var normalized_path: String = path.replace("\\", "/").strip_edges()
	while normalized_path.ends_with("/"):
		normalized_path = normalized_path.substr(0, normalized_path.length() - 1)
	return normalized_path


func _profile_relative_path_is_invalid(path: String) -> bool:
	if path.is_empty() or path != path.strip_edges() or path.contains("\\") or path.ends_with("/"):
		return true
	if path.begins_with("/") or path.contains("://") or path.contains(":"):
		return true
	if path.is_absolute_path() or _is_filesystem_absolute_path(path):
		return true
	return _path_has_parent_segment(path)


func _profile_pattern_is_invalid(pattern: String) -> bool:
	if pattern.is_empty() or pattern != pattern.strip_edges() or pattern.contains("\\"):
		return true
	if pattern.begins_with("/") or pattern.contains("://") or pattern.contains(":"):
		return true
	return _path_has_parent_segment(pattern)


func _path_has_parent_segment(path: String) -> bool:
	var normalized_path: String = path.replace("\\", "/")
	var body: String = normalized_path
	if normalized_path.contains("://"):
		body = normalized_path.get_slice("://", 1)
	var parts: PackedStringArray = body.split("/", false)
	for part: String in parts:
		if part == "..":
			return true
	return false


func _path_crosses_link(path: String) -> bool:
	var probe_path: String = ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	while not probe_path.is_empty():
		var parent_path: String = probe_path.get_base_dir()
		if parent_path == probe_path or parent_path.is_empty():
			return false
		var parent_directory: DirAccess = DirAccess.open(parent_path)
		if parent_directory != null and parent_directory.is_link(probe_path.get_file()):
			return true
		probe_path = parent_path
	return false


func _is_filesystem_absolute_path(path: String) -> bool:
	var normalized_path: String = path.replace("\\", "/")
	if normalized_path.length() >= 3 and normalized_path.substr(1, 2) == ":/":
		return true
	return normalized_path.is_absolute_path()


func _normalize_root_path(path: String) -> String:
	var normalized_path: String = path.replace("\\", "/").strip_edges()
	if normalized_path.is_empty():
		return "res://"
	while normalized_path.ends_with("/") and normalized_path != "res://" and normalized_path != "user://":
		normalized_path = normalized_path.substr(0, normalized_path.length() - 1)
	return normalized_path


func _string_value(value: Variant) -> String:
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return ""


func _is_non_empty_string_value(value: Variant) -> bool:
	return not _string_value(value).strip_edges().is_empty()


func _get_string(source: Dictionary, key: String, default_value: String = "") -> String:
	if not source.has(key):
		return default_value
	var value: Variant = source[key]
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return default_value


func _get_bool(source: Dictionary, key: String, default_value: bool = false) -> bool:
	if not source.has(key):
		return default_value
	var value: Variant = source[key]
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return default_value


func _get_int(source: Dictionary, key: String, default_value: int = 0) -> int:
	if not source.has(key):
		return default_value
	var value: Variant = source[key]
	if value is int:
		var int_value: int = value
		return int_value
	if value is float and _is_exact_integer(value):
		return _exact_integer_value(value)
	return default_value


func _is_exact_integer(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var float_value: float = value
	return is_finite(float_value) and float_value == floorf(float_value)


func _exact_integer_value(value: Variant, default_value: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		var float_value: float = value
		if _is_exact_integer(float_value):
			return int(float_value)
	return default_value


func _get_positive_integer_option(options: Dictionary, key: String, default_value: int, report: Dictionary) -> int:
	if not options.has(key):
		return default_value
	var value: Variant = options[key]
	if value is int and value > 0:
		return value
	_add_issue(
		report,
		"error",
		"invalid_integer_option",
		key,
		"项目结构扫描选项 %s 必须是正整数。" % key,
		{ "option": key, "actual_value": value }
	)
	return default_value


func _get_array(source: Dictionary, key: String) -> Array:
	if not source.has(key):
		return []
	var value: Variant = source[key]
	if value is Array:
		var array_value: Array = value
		return array_value
	return []


func _get_packed_string_array(source: Dictionary, key: String) -> PackedStringArray:
	if not source.has(key):
		return PackedStringArray()
	var value: Variant = source[key]
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value
	return PackedStringArray()


func _get_string_list(source: Dictionary, key: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not source.has(key):
		return result

	var value: Variant = source[key]
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	if value is String:
		var string_value: String = value
		if not string_value.is_empty():
			var _append_string: bool = result.append(string_value)
		return result
	if value is StringName:
		var string_name_value: StringName = value
		if string_name_value != &"":
			var _append_string_name: bool = result.append(String(string_name_value))
		return result
	if value is Array:
		var array_value: Array = value
		for item: Variant in array_value:
			if item is String:
				var item_string: String = item
				if not item_string.is_empty():
					var _append_item_string: bool = result.append(item_string)
			elif item is StringName:
				var item_string_name: StringName = item
				if item_string_name != &"":
					var _append_item_string_name: bool = result.append(String(item_string_name))
	return result
