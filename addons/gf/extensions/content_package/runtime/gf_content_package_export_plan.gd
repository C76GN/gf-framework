## GFContentPackageExportPlan: 内容包导出计划。
##
## 从 GFContentPackageManifest 或 GFContentPackageCatalog 构建可审计的资源条目列表，
## 供编辑器工具、构建脚本或项目安装器决定后续打包方式。本类只生成计划和诊断，不写 zip、不改 remap、
## 不规定项目目录结构。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
class_name GFContentPackageExportPlan
extends RefCounted


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

const _REPORT_SUBJECT: String = "Content package export plan"
const _KIND_INVALID_MANIFEST: String = "invalid_manifest"
const _KIND_MISSING_RESOURCE: String = "missing_resource"
const _KIND_RESOURCE_OUTSIDE_ROOT: String = "resource_outside_root"
const _KIND_DUPLICATE_ARCHIVE_PATH: String = "duplicate_archive_path"
const _KIND_DEPENDENCY_REPORT_ISSUE: String = "dependency_report_issue"


# --- 公共变量 ---

## 计划关联的主内容包 ID。
## [br]
## @api public
## [br]
## @since 6.0.0
var package_id: StringName = &""

## 计划关联的主内容包版本。
## [br]
## @api public
## [br]
## @since 6.0.0
var version: String = ""

## 计划关联的内容包根目录。
## [br]
## @api public
## [br]
## @since 6.0.0
var root_path: String = ""

## 导出条目列表。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema entries: Array[Dictionary]，每项包含 source_path、archive_path、role、resource_key、package_id、type_hint 和 metadata。
var entries: Array[Dictionary] = []

## 计划诊断问题。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema issues: Array[Dictionary] GFValidationReportDictionary-compatible issue payloads.
var issues: Array[Dictionary] = []

## 调用方自定义元数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary project-defined export metadata.
var metadata: Dictionary = {}


# --- 公共方法 ---

## 清空计划。
## [br]
## @api public
## [br]
## @since 6.0.0
func clear() -> void:
	package_id = &""
	version = ""
	root_path = ""
	entries.clear()
	issues.clear()
	metadata.clear()


## 添加导出条目。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param source_path: 源资源路径。
## [br]
## @param archive_path: 归档内路径；为空时按 root_path 推导相对路径。
## [br]
## @param role: 条目角色，例如 manifest、resource 或 dependency。
## [br]
## @param entry_metadata: 条目元数据。
## [br]
## @return 成功加入返回 true。
## [br]
## @schema entry_metadata: Dictionary project-defined entry metadata.
func add_entry(
	source_path: String,
	archive_path: String = "",
	role: StringName = &"resource",
	entry_metadata: Dictionary = {}
) -> bool:
	var normalized_source: String = _normalize_resource_path(source_path)
	if normalized_source.is_empty():
		return false
	var normalized_archive: String = _normalize_archive_path(
		archive_path if not archive_path.strip_edges().is_empty() else _make_archive_path(normalized_source)
	)
	if normalized_archive.is_empty():
		return false
	entries.append({
		"source_path": normalized_source,
		"archive_path": normalized_archive,
		"role": role,
		"resource_key": GFVariantData.get_option_string_name(entry_metadata, "resource_key"),
		"package_id": GFVariantData.get_option_string_name(entry_metadata, "package_id", package_id),
		"type_hint": GFVariantData.get_option_string(entry_metadata, "type_hint"),
		"metadata": entry_metadata.duplicate(true),
	})
	return true


## 从单个内容包 manifest 构建计划。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param manifest: 内容包 manifest。
## [br]
## @param options: 构建选项。
## [br]
## @return 当前计划。
## [br]
## @schema options: Dictionary，可包含 include_manifest、include_resource_dependencies、check_files、archive_root、dependency_options 和 metadata。
func build_from_manifest(
	manifest: GFContentPackageManifest,
	options: Dictionary = {}
) -> GFContentPackageExportPlan:
	clear()
	if manifest == null:
		_append_issue("error", _KIND_INVALID_MANIFEST, "content package manifest is null", {})
		return self

	package_id = manifest.package_id
	version = manifest.version
	root_path = _normalize_root_path(manifest.root_path)
	metadata = GFVariantData.get_option_dictionary(options, "metadata")
	metadata["archive_root"] = GFVariantData.get_option_string(options, "archive_root")

	var manifest_report: Dictionary = manifest.get_validation_report({
		"check_resource_exists": GFVariantData.get_option_bool(options, "check_files", false),
	})
	if not GFVariantData.get_option_bool(manifest_report, "ok"):
		for issue_value: Variant in GFVariantData.get_option_array(manifest_report, "issues"):
			issues.append(GFValidationReportDictionary.issue_to_dict(issue_value))

	if GFVariantData.get_option_bool(options, "include_manifest", true) and not manifest.source_path.is_empty():
		var _manifest_added: bool = add_entry(manifest.source_path, "", &"manifest", {
			"package_id": package_id,
			"type_hint": "JSON",
		})

	for resource_entry: Dictionary in manifest.get_normalized_resources():
		_append_manifest_resource_entry(resource_entry, options)

	_validate_archive_path_uniqueness()
	return self


## 从内容包目录构建多包计划。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param catalog: 内容包目录。
## [br]
## @param options: 构建选项。
## [br]
## @return 当前计划。
## [br]
## @schema options: Dictionary，可包含 package_ids、include_manifest、include_resource_dependencies、check_files、archive_root、dependency_options 和 metadata。
func build_from_catalog(
	catalog: GFContentPackageCatalog,
	options: Dictionary = {}
) -> GFContentPackageExportPlan:
	clear()
	if catalog == null:
		_append_issue("error", _KIND_INVALID_MANIFEST, "content package catalog is null", {})
		return self

	metadata = GFVariantData.get_option_dictionary(options, "metadata")
	metadata["archive_root"] = GFVariantData.get_option_string(options, "archive_root")
	var selected_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(options, "package_ids")
	var ids: PackedStringArray = catalog.get_ordered_package_ids()
	for package_id_text: String in ids:
		if not selected_ids.is_empty() and not selected_ids.has(package_id_text):
			continue
		var manifest: GFContentPackageManifest = catalog.get_manifest(StringName(package_id_text))
		if manifest == null:
			continue
		if package_id == &"":
			package_id = manifest.package_id
			version = manifest.version
			root_path = _normalize_root_path(manifest.root_path)
		_append_manifest_to_existing_plan(manifest, options)

	_validate_archive_path_uniqueness()
	return self


## 获取导出计划诊断报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema return: Dictionary with ok, healthy, entries, entry_count, issues, summary, and next_action.
func get_validation_report() -> Dictionary:
	var report: Dictionary = {
		"subject": _REPORT_SUBJECT,
		"package_id": package_id,
		"version": version,
		"root_path": root_path,
		"entry_count": entries.size(),
		"entries": _copy_entries(),
		"issues": [],
	}
	var report_issues: Array = GFVariantData.get_option_array(report, "issues")
	for issue: Dictionary in issues:
		report_issues.append(issue.duplicate(true))
	report["issues"] = report_issues
	return GFValidationReportDictionary.finalize_report(report, _REPORT_SUBJECT, {
		"fallback_action": "Review the first content package export plan issue.",
		"no_action": "Content package export plan is valid.",
	})


## 转换为可序列化字典。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 计划字典。
## [br]
## @schema return: Dictionary with package_id, version, root_path, entries, issues, and metadata.
func to_dictionary() -> Dictionary:
	return {
		"package_id": package_id,
		"version": version,
		"root_path": root_path,
		"entries": _copy_entries(),
		"issues": _copy_issues(),
		"metadata": metadata.duplicate(true),
	}


## 从 manifest 创建计划。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param manifest: 内容包 manifest。
## [br]
## @param options: 构建选项，见 build_from_manifest()。
## [br]
## @return 新计划。
## [br]
## @schema options: Dictionary，可包含 include_manifest、include_resource_dependencies、check_files、archive_root、dependency_options 和 metadata。
static func from_manifest(
	manifest: GFContentPackageManifest,
	options: Dictionary = {}
) -> GFContentPackageExportPlan:
	var plan: GFContentPackageExportPlan = GFContentPackageExportPlan.new()
	return plan.build_from_manifest(manifest, options)


## 从 catalog 创建计划。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param catalog: 内容包目录。
## [br]
## @param options: 构建选项，见 build_from_catalog()。
## [br]
## @return 新计划。
## [br]
## @schema options: Dictionary，可包含 package_ids、include_manifest、include_resource_dependencies、check_files、archive_root、dependency_options 和 metadata。
static func from_catalog(
	catalog: GFContentPackageCatalog,
	options: Dictionary = {}
) -> GFContentPackageExportPlan:
	var plan: GFContentPackageExportPlan = GFContentPackageExportPlan.new()
	return plan.build_from_catalog(catalog, options)


# --- 私有/辅助方法 ---

func _append_manifest_to_existing_plan(manifest: GFContentPackageManifest, options: Dictionary) -> void:
	var previous_root_path: String = root_path
	root_path = _normalize_root_path(manifest.root_path)
	var manifest_report: Dictionary = manifest.get_validation_report({
		"check_resource_exists": GFVariantData.get_option_bool(options, "check_files", false),
	})
	if not GFVariantData.get_option_bool(manifest_report, "ok"):
		for issue_value: Variant in GFVariantData.get_option_array(manifest_report, "issues"):
			issues.append(GFValidationReportDictionary.issue_to_dict(issue_value))

	if GFVariantData.get_option_bool(options, "include_manifest", true) and not manifest.source_path.is_empty():
		var _manifest_added: bool = add_entry(manifest.source_path, "", &"manifest", {
			"package_id": manifest.package_id,
			"type_hint": "JSON",
		})

	for resource_entry: Dictionary in manifest.get_normalized_resources():
		_append_manifest_resource_entry(resource_entry, options)
	root_path = previous_root_path


func _append_manifest_resource_entry(resource_entry: Dictionary, options: Dictionary) -> void:
	var source_path: String = GFVariantData.get_option_string(resource_entry, "path")
	var entry_metadata: Dictionary = GFVariantData.get_option_dictionary(resource_entry, "metadata")
	entry_metadata["resource_key"] = GFVariantData.get_option_string_name(resource_entry, "key")
	entry_metadata["package_id"] = GFVariantData.get_option_string_name(resource_entry, "package_id", package_id)
	entry_metadata["type_hint"] = GFVariantData.get_option_string(resource_entry, "type_hint")
	if not _source_is_inside_root(source_path):
		_append_issue("error", _KIND_RESOURCE_OUTSIDE_ROOT, "resource path is outside package root", {
			"path": source_path,
			"key": entry_metadata["resource_key"],
		})
		return
	var _resource_added: bool = add_entry(source_path, "", &"resource", entry_metadata)
	if GFVariantData.get_option_bool(options, "check_files", false) and not _resource_path_exists(source_path):
		_append_issue("error", _KIND_MISSING_RESOURCE, "resource file is missing", {
			"path": source_path,
			"key": entry_metadata["resource_key"],
		})

	if GFVariantData.get_option_bool(options, "include_resource_dependencies", false):
		_append_dependency_entries(source_path, options)


func _append_dependency_entries(source_path: String, options: Dictionary) -> void:
	var dependency_options: Dictionary = GFVariantData.get_option_dictionary(options, "dependency_options")
	dependency_options["include_root"] = false
	var dependency_report: Dictionary = GFResourceRegistryTools.build_dependency_report(source_path, dependency_options)
	for dependency_path: Variant in GFVariantData.get_option_array(dependency_report, "paths"):
		var path: String = GFVariantData.to_text(dependency_path)
		if path.is_empty() or not _source_is_inside_root(path):
			continue
		var _dependency_added: bool = add_entry(path, "", &"dependency", {
			"package_id": package_id,
			"source_resource_path": source_path,
		})

	for issue_value: Variant in GFVariantData.get_option_array(dependency_report, "issues"):
		var issue: Dictionary = GFValidationReportDictionary.issue_to_dict(issue_value)
		if issue.is_empty():
			continue
		issue["kind"] = _KIND_DEPENDENCY_REPORT_ISSUE
		issues.append(issue)


func _validate_archive_path_uniqueness() -> void:
	var seen: Dictionary = {}
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var archive_path: String = GFVariantData.get_option_string(entry, "archive_path")
		if archive_path.is_empty():
			continue
		if seen.has(archive_path):
			_append_issue("error", _KIND_DUPLICATE_ARCHIVE_PATH, "archive path is duplicated", {
				"path": archive_path,
				"row_index": index,
			})
			continue
		seen[archive_path] = true


func _source_is_inside_root(source_path: String) -> bool:
	if root_path.is_empty():
		return true
	return _GF_PATH_TOOLS.is_path_under_root(source_path, root_path, true, false)


func _make_archive_path(source_path: String) -> String:
	var archive_root: String = GFVariantData.get_option_string(metadata, "archive_root")
	var relative_path: String = _GF_PATH_TOOLS.make_relative_path(source_path, root_path)
	if relative_path.is_empty() or relative_path == source_path:
		relative_path = source_path.trim_prefix("res://").trim_prefix("user://")
	if archive_root.is_empty():
		return relative_path
	return archive_root.path_join(relative_path)


func _append_issue(severity: String, kind: String, message: String, fields: Dictionary) -> void:
	var report: Dictionary = {
		"issues": [],
	}
	var issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		severity,
		StringName(kind),
		message,
		fields
	)
	issues.append(issue)


func _copy_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		result.append(entry.duplicate(true))
	return result


func _copy_issues() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue: Dictionary in issues:
		result.append(issue.duplicate(true))
	return result


static func _normalize_archive_path(path: String) -> String:
	var normalized: String = path.strip_edges().replace("\\", "/").simplify_path()
	while normalized.begins_with("/"):
		normalized = normalized.substr(1)
	if normalized.begins_with("../") or normalized == "..":
		return ""
	return normalized


static func _normalize_resource_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_resource_path(path, "", true)


static func _normalize_root_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_root_path(path, "", true)


static func _resource_path_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(path)
