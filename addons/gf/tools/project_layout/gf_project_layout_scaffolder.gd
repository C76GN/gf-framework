## GFProjectLayoutScaffolder: Profile 驱动的项目目录脚手架工具。
##
## 按项目结构 profile 创建必需目录和可选 Feature 模块目录，并返回可审查报告。
## 该工具只实现目录创建机制，不要求所有项目采用同一业务结构，也不把参考项目约定
## 写入 GF 运行时包。
## 所有选项和 profile 字段都会在写入前严格校验，dry-run 与 apply 共用目录可创建性预检。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since 8.0.0
class_name GFProjectLayoutScaffolder
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
const _SCAFFOLDER_OPTION_FIELDS: PackedStringArray = [
	"root_path",
	"feature_ids",
	"dry_run",
	"include_optional_zones",
	"include_optional_feature_subdirs",
	"allow_absolute_root",
]
const _SCAFFOLDER_BOOL_OPTION_FIELDS: PackedStringArray = [
	"dry_run",
	"include_optional_zones",
	"include_optional_feature_subdirs",
	"allow_absolute_root",
]
const _FEATURE_PATH_OPTION_FIELDS: PackedStringArray = ["include_optional_feature_subdirs"]
const _NAMING_TARGETS: PackedStringArray = ["path", "name", "stem"]


# --- 公共方法 ---

## 按内置 Feature 内聚式模板创建目录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 脚手架选项。
## [br]
## @schema options: Dictionary，可包含 root_path、feature_ids、dry_run、include_optional_zones、include_optional_feature_subdirs 和 allow_absolute_root。
## [br]
## @return: 脚手架报告。
## [br]
## @schema return: Dictionary，包含 success、profile_id、root_path、dry_run、planned_paths、created_paths、existing_paths、rolled_back_paths、rollback_failed_paths、operations、issues、error_count 和 warning_count。
func scaffold_default_profile(options: Dictionary = {}) -> Dictionary:
	return scaffold_profile_path(DEFAULT_FEATURE_COHESIVE_PROFILE_PATH, options)


## 从项目结构 profile 文件创建目录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param profile_path: JSON profile 路径。
## [br]
## @param options: 脚手架选项。
## [br]
## @schema options: Dictionary，可包含 root_path、feature_ids、dry_run、include_optional_zones、include_optional_feature_subdirs 和 allow_absolute_root。
## [br]
## @return: 脚手架报告。
## [br]
## @schema return: Dictionary，包含 success、profile_id、root_path、dry_run、planned_paths、created_paths、existing_paths、rolled_back_paths、rollback_failed_paths、operations、issues、error_count 和 warning_count。
func scaffold_profile_path(profile_path: String, options: Dictionary = {}) -> Dictionary:
	var load_result: Dictionary = _load_profile(profile_path)
	if not _get_bool(load_result, "success"):
		var root_path: String = _report_root_path(options)
		var report: Dictionary = _make_report("", root_path, _report_dry_run(options))
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
		return scaffold_profile(profile, options)

	var fallback_report: Dictionary = _make_report("", _report_root_path(options), _report_dry_run(options))
	_validate_options(options, fallback_report)
	_add_issue(fallback_report, "error", "invalid_profile", profile_path, "项目结构 profile 必须是 Dictionary。")
	return _finalize_report(fallback_report)


## 按已解析的项目结构 profile 创建目录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param profile: 项目结构 profile 字典。
## [br]
## @schema profile: Dictionary，包含 schema_version、id、zones 和 rules。
## [br]
## @param options: 脚手架选项。
## [br]
## @schema options: Dictionary，可包含 root_path、feature_ids、dry_run、include_optional_zones、include_optional_feature_subdirs 和 allow_absolute_root。
## [br]
## @return: 脚手架报告。
## [br]
## @schema return: Dictionary，包含 success、profile_id、root_path、dry_run、planned_paths、created_paths、existing_paths、rolled_back_paths、rollback_failed_paths、operations、issues、error_count 和 warning_count。
func scaffold_profile(profile: Dictionary, options: Dictionary = {}) -> Dictionary:
	var root_path: String = _report_root_path(options)
	var report: Dictionary = _make_report(_get_string(profile, "id"), root_path, _report_dry_run(options))
	_validate_options(options, report)
	_validate_profile_header(profile, report)
	_validate_profile_schema(profile, report)
	_validate_root_path(root_path, options, report)
	if _get_int(report, "error_count") > 0:
		return _finalize_report(report)

	_queue_root_path(root_path, report)
	_queue_zone_paths(profile, options, report)
	_queue_feature_paths(profile, options, report)
	if _get_int(report, "error_count") > 0:
		return _finalize_report(report)

	if not _get_bool(report, "dry_run"):
		_create_queued_paths(report)
	return _finalize_report(report)


## 根据 Feature 模块契约计算某个 Feature 应创建的相对目录。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param profile: 项目结构 profile 字典。
## [br]
## @schema profile: Dictionary，包含 feature_module_contract 规则。
## [br]
## @param feature_id: Feature 模块 ID。
## [br]
## @param options: 计算选项。
## [br]
## @schema options: Dictionary，可包含 include_optional_feature_subdirs。
## [br]
## @return: 相对目录列表，例如 features/inventory/scripts。
func make_feature_module_paths(profile: Dictionary, feature_id: String, options: Dictionary = {}) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not _feature_path_options_are_valid(options):
		return result
	var contract: Dictionary = _find_feature_contract(profile)
	if contract.is_empty() or feature_id.is_empty():
		return result
	var feature_id_pattern: String = _get_string(contract, "feature_id_pattern", "^[a-z][a-z0-9_]*$")
	if not _is_valid_feature_id(feature_id, feature_id_pattern):
		return result

	var roots: PackedStringArray = _get_string_list(contract, "roots")
	var subdirs: PackedStringArray = _get_string_list(contract, "required_subdirs")
	if _get_bool(options, "include_optional_feature_subdirs"):
		var allowed_subdirs: PackedStringArray = _get_string_list(contract, "allowed_subdirs")
		for allowed_subdir: String in allowed_subdirs:
			if not subdirs.has(allowed_subdir):
				var _append_allowed_subdir: bool = subdirs.append(allowed_subdir)
	for index: int in roots.size():
		if _profile_relative_path_is_invalid(roots[index]):
			return result
		var normalized_root: String = _normalize_relative_path(roots[index])
		roots[index] = normalized_root
	for index: int in subdirs.size():
		if _profile_relative_path_is_invalid(subdirs[index]):
			return result
		var normalized_subdir: String = _normalize_relative_path(subdirs[index])
		subdirs[index] = normalized_subdir

	for root: String in roots:
		var feature_root: String = root.path_join(feature_id)
		var _append_feature_root: bool = result.append(feature_root)
		for subdir: String in subdirs:
			var _append_feature_subdir: bool = result.append(feature_root.path_join(subdir))
	return result


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


func _make_report(profile_id: String, root_path: String, dry_run: bool) -> Dictionary:
	return {
		"success": true,
		"profile_id": profile_id,
		"root_path": root_path,
		"dry_run": dry_run,
		"planned_paths": [],
		"created_paths": [],
		"existing_paths": [],
		"rolled_back_paths": [],
		"rollback_failed_paths": [],
		"operations": [],
		"issues": [],
		"error_count": 0,
		"warning_count": 0,
		"_queued_paths": [],
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


func _report_dry_run(options: Dictionary) -> bool:
	if not options.has("dry_run") or not options["dry_run"] is bool:
		return false
	var dry_run: bool = options["dry_run"]
	return dry_run


func _validate_options(options: Dictionary, report: Dictionary) -> void:
	for key_value: Variant in options.keys():
		var option_name: String = _string_value(key_value)
		if not option_name.is_empty() and _SCAFFOLDER_OPTION_FIELDS.has(option_name):
			continue
		_add_issue(
			report,
			"error",
			"unsupported_option",
			option_name,
			"项目结构 scaffolder 包含不受支持的选项。",
			{ "actual": _describe_value(key_value) }
		)
	if options.has("root_path"):
		var root_value: Variant = options["root_path"]
		if not (root_value is String or root_value is StringName):
			_add_issue(report, "error", "invalid_option_type", "root_path", "root_path 必须是字符串。", { "actual": _describe_value(root_value) })
		elif _string_value(root_value).strip_edges().is_empty():
			_add_issue(report, "error", "invalid_option_value", "root_path", "root_path 不能为空。")
	for field_name: String in _SCAFFOLDER_BOOL_OPTION_FIELDS:
		if options.has(field_name) and not options[field_name] is bool:
			_add_issue(report, "error", "invalid_option_type", field_name, "%s 必须是 bool。" % field_name, { "actual": _describe_value(options[field_name]) })
	var _feature_ids_valid: bool = _validate_string_list_field(
		options,
		"feature_ids",
		"options",
		false,
		true,
		report,
		"invalid_option_type"
	)


func _feature_path_options_are_valid(options: Dictionary) -> bool:
	for key_value: Variant in options.keys():
		var option_name: String = _string_value(key_value)
		if option_name.is_empty() or not _FEATURE_PATH_OPTION_FIELDS.has(option_name):
			return false
	if options.has("include_optional_feature_subdirs") and not options["include_optional_feature_subdirs"] is bool:
		return false
	return true


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
	report: Dictionary,
	issue_kind: String = "invalid_string_list_field"
) -> bool:
	if not data.has(field_name):
		if required:
			_add_issue(report, "error", issue_kind, scope, "项目结构 profile 缺少 %s 字符串列表。" % field_name, { "field": field_name })
		return not required
	var value: Variant = data[field_name]
	if not (value is Array or value is PackedStringArray):
		_add_issue(
			report,
			"error",
			issue_kind,
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
		_add_issue(report, "error", issue_kind, scope, "项目结构 profile %s 不能为空。" % field_name, { "field": field_name })
		return false
	var valid: bool = true
	for item: Variant in values:
		if _is_non_empty_string_value(item):
			continue
		valid = false
		_add_issue(
			report,
			"error",
			issue_kind,
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


func _queue_root_path(root_path: String, report: Dictionary) -> void:
	if root_path == "res://" or root_path == "user://":
		return
	_queue_directory(root_path, report)


func _queue_zone_paths(profile: Dictionary, options: Dictionary, report: Dictionary) -> void:
	var zones: Array = _get_array(profile, "zones")
	var include_optional_zones: bool = _get_bool(options, "include_optional_zones")
	for zone_value: Variant in zones:
		if not (zone_value is Dictionary):
			_add_issue(report, "error", "invalid_zone", "", "项目结构 profile zones 条目必须是 Dictionary。")
			continue

		var zone: Dictionary = zone_value
		if not _get_bool(zone, "required") and not include_optional_zones:
			continue

		var roots: PackedStringArray = _get_string_list(zone, "roots")
		for relative_root: String in roots:
			_queue_relative_directory(_root_path_from_report(report), relative_root, report)


func _queue_feature_paths(profile: Dictionary, options: Dictionary, report: Dictionary) -> void:
	var feature_ids: PackedStringArray = _get_string_list(options, "feature_ids")
	if feature_ids.is_empty():
		return

	var contract: Dictionary = _find_feature_contract(profile)
	if contract.is_empty():
		_add_issue(report, "error", "missing_feature_module_contract", "", "项目结构 profile 没有 feature_module_contract 规则。")
		return

	var feature_id_pattern: String = _get_string(contract, "feature_id_pattern", "^[a-z][a-z0-9_]*$")
	var feature_paths_options: Dictionary = {
		"include_optional_feature_subdirs": _get_bool(options, "include_optional_feature_subdirs"),
	}
	for feature_id: String in feature_ids:
		if not _is_valid_feature_id(feature_id, feature_id_pattern):
			_add_issue(
				report,
				"error",
				"invalid_feature_id",
				feature_id,
				"Feature ID 不符合 profile 约定：%s。" % feature_id,
				{ "pattern": feature_id_pattern }
			)
			continue

		var relative_paths: PackedStringArray = make_feature_module_paths(profile, feature_id, feature_paths_options)
		for relative_path: String in relative_paths:
			_queue_relative_directory(_root_path_from_report(report), relative_path, report)


func _root_path_from_report(report: Dictionary) -> String:
	return _get_string(report, "root_path", "res://")


func _queue_relative_directory(root_path: String, relative_path: String, report: Dictionary) -> void:
	var normalized_relative_path: String = relative_path.replace("\\", "/").strip_edges()
	if normalized_relative_path.is_empty():
		return
	if _relative_path_is_invalid(normalized_relative_path):
		_add_issue(report, "error", "invalid_relative_path", normalized_relative_path, "项目结构 profile 包含非法相对路径。")
		return
	_queue_directory(root_path.path_join(normalized_relative_path), report)


func _queue_directory(path: String, report: Dictionary) -> void:
	var normalized_path: String = _normalize_root_path(path)
	var queued_paths: Array = _get_array(report, "_queued_paths")
	if queued_paths.has(normalized_path):
		return
	queued_paths.append(normalized_path)


func _create_queued_paths(report: Dictionary) -> void:
	var queued_paths: Array = _get_array(report, "_queued_paths")
	var created_this_run: Array[String] = []
	for path_value: Variant in queued_paths:
		if not (path_value is String):
			continue
		var path: String = path_value
		var absolute_path: String = ProjectSettings.globalize_path(path)
		var preflight: Dictionary = _preflight_directory_path(path)
		var preflight_state: String = _get_string(preflight, "state")
		if preflight_state == "linked":
			_append_operation(report, path, "create_directory", "failed", false)
			_add_issue(report, "error", "linked_path_not_allowed", path, "脚手架目标路径不能穿过符号链接或目录联接。")
			_rollback_created_paths(report, created_this_run)
			return
		if preflight_state == "existing":
			var existing_paths: Array = _get_array(report, "existing_paths")
			existing_paths.append(path)
			_append_operation(report, path, "create_directory", "skipped_existing", false)
			continue
		if preflight_state == "blocked":
			_append_operation(report, path, "create_directory", "failed", false)
			_add_issue(
				report,
				"error",
				"directory_create_failed",
				path,
				"目录创建失败：目标或路径祖先不是目录。",
				{
					"error_code": ERR_FILE_ALREADY_IN_USE,
					"blocking_path": _get_string(preflight, "blocking_path"),
				}
			)
			_rollback_created_paths(report, created_this_run)
			return

		var missing_paths: Array[String] = _missing_directory_chain(path)
		var create_error: Error = DirAccess.make_dir_recursive_absolute(absolute_path)
		_record_created_paths(report, missing_paths, path, created_this_run)
		if create_error == OK:
			continue
		else:
			_append_operation(report, path, "create_directory", "failed", false)
			_add_issue(
				report,
				"error",
				"directory_create_failed",
				path,
				"目录创建失败：%s。" % error_string(create_error),
				{ "error_code": create_error }
			)
			_rollback_created_paths(report, created_this_run)
			return


func _finalize_report(report: Dictionary) -> Dictionary:
	var queued_paths: Array = _get_array(report, "_queued_paths")
	var planned_paths: Array = _get_array(report, "planned_paths")
	if _get_bool(report, "dry_run"):
		for path_value: Variant in queued_paths:
			if path_value is String:
				var path: String = path_value
				var preflight: Dictionary = _preflight_directory_path(path)
				var preflight_state: String = _get_string(preflight, "state")
				if preflight_state == "linked":
					_append_operation(report, path, "create_directory", "failed", false)
					_add_issue(report, "error", "linked_path_not_allowed", path, "脚手架目标路径不能穿过符号链接或目录联接。")
				elif preflight_state == "existing":
					if not planned_paths.has(path):
						planned_paths.append(path)
					var existing_paths: Array = _get_array(report, "existing_paths")
					if not existing_paths.has(path):
						existing_paths.append(path)
					_append_operation(report, path, "create_directory", "skipped_existing", false)
				elif preflight_state == "blocked":
					_append_operation(report, path, "create_directory", "failed", false)
					_add_issue(
						report,
						"error",
						"directory_create_failed",
						path,
						"目录创建失败：目标或路径祖先不是目录。",
						{
							"error_code": ERR_FILE_ALREADY_IN_USE,
							"blocking_path": _get_string(preflight, "blocking_path"),
						}
					)
				else:
					if not planned_paths.has(path):
						planned_paths.append(path)
					_append_operation(report, path, "create_directory", "planned", false)
	else:
		for path_value: Variant in queued_paths:
			if path_value is String and not planned_paths.has(path_value):
				planned_paths.append(path_value)

	var _queued_paths_removed: bool = report.erase("_queued_paths")
	report["success"] = _get_int(report, "error_count") == 0
	return report


func _preflight_directory_path(path: String) -> Dictionary:
	if _path_crosses_link(path):
		return { "state": "linked" }
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return { "state": "existing" }
	var blocking_path: String = _find_non_directory_ancestor(path)
	if not blocking_path.is_empty():
		return {
			"state": "blocked",
			"blocking_path": blocking_path,
		}
	return { "state": "creatable" }


func _missing_directory_chain(path: String) -> Array[String]:
	var result: Array[String] = []
	var probe_path: String = _normalize_root_path(path)
	while not probe_path.is_empty() and probe_path != ".":
		var absolute_probe_path: String = ProjectSettings.globalize_path(probe_path)
		if DirAccess.dir_exists_absolute(absolute_probe_path) or FileAccess.file_exists(absolute_probe_path):
			break
		result.push_front(probe_path)
		var parent_path: String = probe_path.get_base_dir()
		if parent_path == probe_path:
			break
		probe_path = parent_path
	return result


func _record_created_paths(
	report: Dictionary,
	paths: Array[String],
	requested_path: String,
	created_this_run: Array[String]
) -> void:
	var created_paths: Array = _get_array(report, "created_paths")
	for path: String in paths:
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			continue
		if not created_paths.has(path):
			created_paths.append(path)
		if not created_this_run.has(path):
			created_this_run.append(path)
		_append_operation(report, path, "create_directory", "applied", path != requested_path)


func _append_operation(report: Dictionary, path: String, kind: String, state: String, implicit: bool) -> void:
	var operations: Array = _get_array(report, "operations")
	operations.append({
		"kind": kind,
		"path": path,
		"state": state,
		"implicit": implicit,
	})


func _set_applied_operation_state(report: Dictionary, path: String, state: String) -> void:
	var operations: Array = _get_array(report, "operations")
	for index: int in range(operations.size() - 1, -1, -1):
		var operation_value: Variant = operations[index]
		if not operation_value is Dictionary:
			continue
		var operation: Dictionary = operation_value
		if _get_string(operation, "path") == path and _get_string(operation, "state") == "applied":
			operation["state"] = state
			return


func _rollback_created_paths(report: Dictionary, created_paths: Array[String]) -> void:
	var rolled_back_paths: Array = _get_array(report, "rolled_back_paths")
	var rollback_failed_paths: Array = _get_array(report, "rollback_failed_paths")
	for index: int in range(created_paths.size() - 1, -1, -1):
		var path: String = created_paths[index]
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if not DirAccess.dir_exists_absolute(absolute_path):
			continue
		if not _directory_is_empty(absolute_path):
			rollback_failed_paths.append(path)
			_set_applied_operation_state(report, path, "rollback_failed")
			continue
		var remove_error: Error = DirAccess.remove_absolute(absolute_path)
		if remove_error == OK:
			rolled_back_paths.append(path)
			_set_applied_operation_state(report, path, "rolled_back")
		else:
			rollback_failed_paths.append(path)
			_set_applied_operation_state(report, path, "rollback_failed")
	if not created_paths.is_empty():
		_add_issue(
			report,
			"error",
			"scaffold_rolled_back_after_failure",
			"",
			"脚手架创建部分失败，已尝试回滚本轮创建的目录。",
			{
				"rolled_back_paths": rolled_back_paths.duplicate(true),
				"rollback_failed_paths": rollback_failed_paths.duplicate(true),
			}
		)


func _find_non_directory_ancestor(path: String) -> String:
	var probe_path: String = _normalize_root_path(path)
	while not probe_path.is_empty() and probe_path != ".":
		var absolute_probe_path: String = ProjectSettings.globalize_path(probe_path)
		if FileAccess.file_exists(absolute_probe_path):
			return probe_path
		if DirAccess.dir_exists_absolute(absolute_probe_path):
			return ""
		var parent_path: String = probe_path.get_base_dir()
		if parent_path == probe_path:
			break
		probe_path = parent_path
	return ""


func _directory_is_empty(absolute_path: String) -> bool:
	var directory: DirAccess = DirAccess.open(absolute_path)
	if directory == null:
		return false
	var list_begin_result: Error = directory.list_dir_begin()
	if list_begin_result != OK:
		return false
	var entry_name: String = directory.get_next()
	while not entry_name.is_empty():
		if entry_name != "." and entry_name != "..":
			directory.list_dir_end()
			return false
		entry_name = directory.get_next()
	directory.list_dir_end()
	return true


func _find_feature_contract(profile: Dictionary) -> Dictionary:
	var rules: Array = _get_array(profile, "rules")
	for rule_value: Variant in rules:
		if not (rule_value is Dictionary):
			continue
		var rule: Dictionary = rule_value
		if _get_string(rule, "kind") == _RULE_FEATURE_MODULE_CONTRACT:
			return rule
	return {}


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


func _is_valid_feature_id(feature_id: String, pattern: String) -> bool:
	if feature_id.contains("/") or feature_id.contains("\\") or feature_id.contains(":"):
		return false
	var expression: RegEx = RegEx.new()
	var compile_result: Error = expression.compile(pattern)
	if compile_result != OK:
		return false
	return expression.search(feature_id) != null


func _relative_path_is_invalid(path: String) -> bool:
	return _profile_relative_path_is_invalid(path)


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


func _normalize_relative_path(path: String) -> String:
	return path.replace("\\", "/").strip_edges().trim_prefix("./").trim_suffix("/")


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


func _get_array(source: Dictionary, key: String) -> Array:
	if not source.has(key):
		return []
	var value: Variant = source[key]
	if value is Array:
		var array_value: Array = value
		return array_value
	return []


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
