## GFProjectLayoutValidator: Profile 驱动的项目结构校验工具。
##
## 按项目结构 profile 检查目录分区、Feature 模块契约、命名、生成物边界和大桶目录增长。
## 该工具只实现可选制作期校验，不把任意业务项目结构写入 GF 运行时包。
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
const _RULE_ALLOWED_FIELDS: PackedStringArray = [
	"id",
	"description",
	"kind",
	"paths",
	"any",
	"roots",
	"include",
	"exclude",
	"extensions",
	"pattern",
	"target",
	"allowed_files",
	"feature_id_pattern",
	"required_subdirs",
	"allowed_subdirs",
	"allow_root_files",
	"max_files",
	"severity",
	"metadata",
]


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
		var root_path: String = _normalize_root_path(_get_string(options, "root_path", "res://"))
		var report: Dictionary = _make_report("", root_path)
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

	var fallback_report: Dictionary = _make_report("", _normalize_root_path(_get_string(options, "root_path", "res://")))
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
	var root_path: String = _normalize_root_path(_get_string(options, "root_path", "res://"))
	var report: Dictionary = _make_report(_get_string(profile, "id"), root_path)
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
	if not profile.get("zones", []) is Array:
		_add_issue(report, "error", "invalid_profile_field_type", "zones", "项目结构 profile zones 必须是 Array。")
	if not profile.get("rules", []) is Array:
		_add_issue(report, "error", "invalid_profile_field_type", "rules", "项目结构 profile rules 必须是 Array。")
	var zones: Array = _get_array(profile, "zones")
	for zone_value: Variant in zones:
		if not (zone_value is Dictionary):
			_add_issue(report, "error", "invalid_zone", "", "项目结构 profile zones 条目必须是 Dictionary。")
			continue
		var zone: Dictionary = zone_value
		_append_unsupported_fields(zone, _ZONE_ALLOWED_FIELDS, "unsupported_zone_field", _get_string(zone, "id"), report)
		if zone.has("severity"):
			_validate_profile_severity(_get_string(zone, "severity"), "zones", _get_string(zone, "id"), report)

	var rules: Array = _get_array(profile, "rules")
	for rule_value: Variant in rules:
		if not (rule_value is Dictionary):
			_add_issue(report, "error", "invalid_rule", "", "项目结构 profile rules 条目必须是 Dictionary。")
			continue
		var rule: Dictionary = rule_value
		_append_unsupported_fields(rule, _RULE_ALLOWED_FIELDS, "unsupported_rule_field", _get_string(rule, "id"), report)
		var kind: String = _get_string(rule, "kind")
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
			_validate_profile_severity(_get_string(rule, "severity"), "rules", _get_string(rule, "id"), report)
		if rule.has("max_files"):
			_validate_positive_integer_field(rule, "max_files", _get_string(rule, "id"), report)


func _append_unsupported_fields(
	data: Dictionary,
	allowed_fields: PackedStringArray,
	issue_kind: String,
	scope: String,
	report: Dictionary
) -> void:
	for field_value: Variant in data.keys():
		var field_name: String = str(field_value)
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
		{ "field": field_name, "actual_value": value }
	)


func _validate_profile_severity(severity: String, scope: String, item_id: String, report: Dictionary) -> void:
	if _SUPPORTED_SEVERITIES.has(severity):
		return
	_add_issue(
		report,
		"error",
		"invalid_severity",
		item_id,
		"项目结构 profile %s 使用了非法 severity：%s。" % [scope, severity],
		{ "severity": severity }
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
	}
	var absolute_root: String = ProjectSettings.globalize_path(root_path)
	if not DirAccess.dir_exists_absolute(absolute_root):
		if not _get_bool(options, "allow_missing_root"):
			_add_issue(report, "error", "root_path_not_found", root_path, "项目根目录不存在。")
		return result

	var max_scanned_files: int = _get_positive_integer_option(options, "max_scanned_files", 20000, report)
	var max_scanned_directories: int = _get_positive_integer_option(options, "max_scanned_directories", 20000, report)
	var max_scan_depth: int = _get_positive_integer_option(options, "max_scan_depth", 32, report)
	if _get_int(report, "error_count") > 0:
		return result
	_scan_directory(root_path, "", _get_bool(options, "include_hidden"), max_scanned_files, max_scanned_directories, max_scan_depth, 0, result, report)
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
	if depth > max_scan_depth:
		_add_issue(report, "error", "scan_depth_limit_reached", root_path, "项目结构扫描超过目录深度上限，无法证明项目结构有效。")
		return

	var current_path: String = root_path if relative_path.is_empty() else root_path.path_join(relative_path)
	var directory: DirAccess = DirAccess.open(ProjectSettings.globalize_path(current_path))
	if directory == null:
		_add_issue(report, "error", "directory_scan_failed", current_path, "目录无法扫描，无法证明项目结构有效。")
		return

	var files: PackedStringArray = directory.get_files()
	for file_name: String in files:
		if not include_hidden and file_name.begins_with("."):
			continue
		if directory.is_link(file_name):
			_add_issue(report, "error", "linked_path_not_allowed", current_path.path_join(file_name), "项目结构扫描不允许符号链接文件。")
			continue
		if _get_int(result, "file_count") >= max_scanned_files:
			_add_issue(report, "error", "scan_file_limit_reached", root_path, "项目结构扫描超过文件数量上限，无法证明项目结构有效。")
			return
		var file_path: String = _join_relative_path(relative_path, file_name)
		var file_list: PackedStringArray = _get_packed_string_array(result, "files")
		var _append_file: bool = file_list.append(file_path)
		result["files"] = file_list
		result["file_count"] = _get_int(result, "file_count") + 1

	var directories: PackedStringArray = directory.get_directories()
	for directory_name: String in directories:
		if not include_hidden and directory_name.begins_with("."):
			continue
		var child_path: String = _join_relative_path(relative_path, directory_name)
		if directory.is_link(directory_name):
			_add_issue(report, "error", "linked_path_not_allowed", root_path.path_join(child_path), "项目结构扫描不允许符号链接或目录联接。")
			continue
		if _get_int(result, "directory_count") >= max_scanned_directories:
			_add_issue(report, "error", "scan_directory_limit_reached", root_path, "项目结构扫描超过目录数量上限，无法证明项目结构有效。")
			return
		var directory_list: PackedStringArray = _get_packed_string_array(result, "directories")
		var _append_directory: bool = directory_list.append(child_path)
		result["directories"] = directory_list
		result["directory_count"] = _get_int(result, "directory_count") + 1
		_scan_directory(root_path, child_path, include_hidden, max_scanned_files, max_scanned_directories, max_scan_depth, depth + 1, result, report)


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
		if expression.search(relative_path) == null:
			_add_rule_issue(
				report,
				rule_result,
				severity,
				"path_naming_mismatch",
				relative_path,
				"项目路径不符合命名约定：%s。" % relative_path,
				{ "pattern": pattern }
			)


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
		"context": context.duplicate(true),
	})
	if severity == "error":
		report["error_count"] = _get_int(report, "error_count") + 1
	elif severity == "warning":
		report["warning_count"] = _get_int(report, "warning_count") + 1
	else:
		report["info_count"] = _get_int(report, "info_count") + 1


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
	while normalized_path.begins_with("/"):
		normalized_path = normalized_path.substr(1)
	while normalized_path.ends_with("/"):
		normalized_path = normalized_path.substr(0, normalized_path.length() - 1)
	return normalized_path


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
