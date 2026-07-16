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
const _ARTIFACT_REPORT_SUBJECT: String = "Content package artifact report"
const _PREFLIGHT_REPORT_SUBJECT: String = "Content package preflight"
const _KIND_INVALID_MANIFEST: String = "invalid_manifest"
const _KIND_MISSING_RESOURCE: String = "missing_resource"
const _KIND_RESOURCE_OUTSIDE_ROOT: String = "resource_outside_root"
const _KIND_INVALID_ARCHIVE_PATH: String = "invalid_archive_path"
const _KIND_DUPLICATE_ARCHIVE_PATH: String = "duplicate_archive_path"
const _KIND_DEPENDENCY_REPORT_ISSUE: String = "dependency_report_issue"
const _KIND_ARTIFACT_MISSING: String = "artifact_missing"
const _KIND_ARTIFACT_UNREADABLE: String = "artifact_unreadable"
const _KIND_ARTIFACT_SIZE_MISMATCH: String = "artifact_size_mismatch"
const _KIND_ARTIFACT_SHA256_MISMATCH: String = "artifact_sha256_mismatch"


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


# --- 私有变量 ---

var _archive_package_scope: String = ""


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
	_archive_package_scope = ""


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
		_append_issue("error", _KIND_INVALID_ARCHIVE_PATH, "archive path is invalid", {
			"source_path": normalized_source,
			"archive_path": archive_path,
		})
		return false
	if _has_archive_path(normalized_archive):
		_append_issue("error", _KIND_DUPLICATE_ARCHIVE_PATH, "archive path is duplicated", {
			"path": normalized_archive,
			"source_path": normalized_source,
		})
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
	var graph_report: Dictionary = catalog.get_graph_report({
		"check_resource_exists": GFVariantData.get_option_bool(options, "check_files", false),
	})
	for issue_value: Variant in GFVariantData.get_option_array(graph_report, "issues"):
		issues.append(GFValidationReportDictionary.issue_to_dict(issue_value))
	if not GFVariantData.get_option_bool(graph_report, "ok"):
		return self

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
	_append_archive_path_uniqueness_issues(report)
	return GFValidationReportDictionary.finalize_report(report, _REPORT_SUBJECT, {
		"fallback_action": "Review the first content package export plan issue.",
		"no_action": "Content package export plan is valid.",
	})


## 获取导出条目的本地 artifact 完整性报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param options: 报告选项。
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema options: Dictionary，可包含 include_sha256、include_modified_time、include_entry_metadata 和 verify_expected_metadata。
## [br]
## @schema return: Dictionary with ok, healthy, artifacts, artifact_count, existing_count, missing_count, unreadable_count, total_size_bytes, issues, summary, and next_action.
func get_artifact_report(options: Dictionary = {}) -> Dictionary:
	var artifacts: Array[Dictionary] = []
	var report: Dictionary = {
		"subject": _ARTIFACT_REPORT_SUBJECT,
		"package_id": package_id,
		"version": version,
		"root_path": root_path,
		"entry_count": entries.size(),
		"artifact_count": 0,
		"existing_count": 0,
		"missing_count": 0,
		"unreadable_count": 0,
		"total_size_bytes": 0,
		"artifacts": artifacts,
		"issues": _copy_issues(),
	}
	for index: int in range(entries.size()):
		var artifact: Dictionary = _make_artifact_entry(entries[index], index, options, report)
		artifacts.append(artifact)
		if GFVariantData.get_option_bool(artifact, "exists"):
			report["existing_count"] = GFVariantData.get_option_int(report, "existing_count") + 1
			report["total_size_bytes"] = (
				GFVariantData.get_option_int(report, "total_size_bytes")
				+ GFVariantData.get_option_int(artifact, "size_bytes")
			)
		elif GFVariantData.get_option_bool(artifact, "unreadable"):
			report["unreadable_count"] = GFVariantData.get_option_int(report, "unreadable_count") + 1
		else:
			report["missing_count"] = GFVariantData.get_option_int(report, "missing_count") + 1
	report["artifact_count"] = artifacts.size()
	report["artifacts"] = artifacts
	return GFValidationReportDictionary.finalize_report(report, _ARTIFACT_REPORT_SUBJECT, {
		"fallback_action": "Review the first content package artifact issue.",
		"no_action": "Content package artifacts are readable and match expected metadata.",
	})


## 获取内容包导出预检报告。
## [br]
## 该报告会合并导出计划校验、可选 artifact 完整性校验，以及调用方显式传入的兼容性 Profile 约束。
## GF 不在这里决定下载、启用、远程发布或业务内容策略。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param profile: 可选兼容性 Profile。
## [br]
## @param options: 预检选项。
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema options: Dictionary，可包含 include_artifacts、artifact_options、required_features、required_platforms、minimum_godot_version、minimum_framework_version 和 metadata。
## [br]
## @schema return: Dictionary with ok, healthy, profile, checks, issues, summary, and next_action.
func get_preflight_report(
	profile: GFCompatibilityProfile = null,
	options: Dictionary = {}
) -> Dictionary:
	var preflight: GFCompatibilityPreflight = GFCompatibilityPreflight.new()
	var _configured: GFCompatibilityPreflight = preflight.configure(
		_PREFLIGHT_REPORT_SUBJECT,
		profile,
		GFVariantData.get_option_dictionary(options, "metadata")
	)
	preflight.target_id = package_id
	preflight.target_version = version
	var _plan_report: GFCompatibilityPreflight = preflight.merge_report(get_validation_report(), {
		"check_id": &"content_package.export_plan",
		"component": &"content_package",
		"phase": &"plan",
	})

	if GFVariantData.get_option_bool(options, "include_artifacts", true):
		var artifact_options: Dictionary = GFVariantData.get_option_dictionary(options, "artifact_options")
		var _artifact_report: GFCompatibilityPreflight = preflight.merge_report(get_artifact_report(artifact_options), {
			"check_id": &"content_package.artifacts",
			"component": &"content_package",
			"phase": &"artifacts",
		})

	var minimum_godot_version: String = GFVariantData.get_option_string(options, "minimum_godot_version")
	var maximum_godot_version: String = GFVariantData.get_option_string(options, "maximum_godot_version_exclusive")
	if not minimum_godot_version.is_empty() or not maximum_godot_version.is_empty():
		var _godot_check: Dictionary = preflight.require_godot_version(minimum_godot_version, maximum_godot_version, {
			"check_id": &"content_package.godot_version",
			"metadata": {
				"package_id": package_id,
			},
		})

	var minimum_framework_version: String = GFVariantData.get_option_string(options, "minimum_framework_version")
	var maximum_framework_version: String = GFVariantData.get_option_string(options, "maximum_framework_version_exclusive")
	if not minimum_framework_version.is_empty() or not maximum_framework_version.is_empty():
		var _framework_check: Dictionary = preflight.require_framework_version(minimum_framework_version, maximum_framework_version, {
			"check_id": &"content_package.framework_version",
			"metadata": {
				"package_id": package_id,
			},
		})

	var required_platforms: PackedStringArray = GFVariantData.get_option_packed_string_array(options, "required_platforms")
	if not required_platforms.is_empty():
		var _platform_check: Dictionary = preflight.require_platforms(
			required_platforms,
			GFVariantData.get_option_string_name(options, "platform_match_mode", GFCompatibilityPreflight.MATCH_ANY),
			{
				"check_id": &"content_package.platforms",
			}
		)

	var required_features: PackedStringArray = GFVariantData.get_option_packed_string_array(options, "required_features")
	if not required_features.is_empty():
		var _feature_check: Dictionary = preflight.require_features(
			required_features,
			GFVariantData.get_option_string_name(options, "feature_match_mode", GFCompatibilityPreflight.MATCH_ALL),
			{
				"check_id": &"content_package.features",
			}
		)

	return preflight.get_report({
		"subject": _PREFLIGHT_REPORT_SUBJECT,
		"fallback_action": "Review the first content package preflight issue.",
		"no_action": "Content package preflight is healthy.",
		"warnings_as_errors": GFVariantData.get_option_bool(options, "warnings_as_errors", false),
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


## 转换为 JSON-safe 报告字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return 计划报告字典。
## [br]
## @schema options: Dictionary with GFReportValueCodec encoding options.
## [br]
## @schema return: JSON-safe Dictionary based on to_dictionary().
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(to_dictionary(), options)


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
	var previous_archive_package_scope: String = _archive_package_scope
	root_path = _normalize_root_path(manifest.root_path)
	_archive_package_scope = String(manifest.package_id)
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
	_archive_package_scope = previous_archive_package_scope


func _append_manifest_resource_entry(resource_entry: Dictionary, options: Dictionary) -> void:
	var source_path: String = GFVariantData.get_option_string(resource_entry, "path")
	var entry_metadata: Dictionary = GFVariantData.get_option_dictionary(resource_entry, "metadata")
	entry_metadata["resource_key"] = GFVariantData.get_option_string_name(resource_entry, "key")
	var owner_package_id: StringName = GFVariantData.get_option_string_name(resource_entry, "package_id", package_id)
	entry_metadata["package_id"] = owner_package_id
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
		_append_dependency_entries(source_path, owner_package_id, options)


func _append_dependency_entries(
	source_path: String,
	owner_package_id: StringName,
	options: Dictionary
) -> void:
	var dependency_options: Dictionary = GFVariantData.get_option_dictionary(options, "dependency_options")
	dependency_options["include_root"] = false
	var dependency_report: Dictionary = GFResourceRegistryTools.build_dependency_report(source_path, dependency_options)
	for dependency_path: Variant in GFVariantData.get_option_array(dependency_report, "paths"):
		var path: String = GFVariantData.to_text(dependency_path)
		if path.is_empty() or not _source_is_inside_root(path):
			continue
		var _dependency_added: bool = add_entry(path, "", &"dependency", {
			"package_id": owner_package_id,
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


func _append_archive_path_uniqueness_issues(report: Dictionary) -> void:
	var seen: Dictionary = {}
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		var archive_path: String = GFVariantData.get_option_string(entry, "archive_path")
		if archive_path.is_empty():
			continue
		if seen.has(archive_path):
			var _issue: Dictionary = GFValidationReportDictionary.append_issue(
				report,
				"error",
				StringName(_KIND_DUPLICATE_ARCHIVE_PATH),
				"archive path is duplicated",
				{
					"path": archive_path,
					"row_index": index,
				}
			)
			continue
		seen[archive_path] = true


func _has_archive_path(archive_path: String) -> bool:
	for entry: Dictionary in entries:
		if GFVariantData.get_option_string(entry, "archive_path") == archive_path:
			return true
	return false


func _make_artifact_entry(
	entry: Dictionary,
	entry_index: int,
	options: Dictionary,
	report: Dictionary
) -> Dictionary:
	var source_path: String = GFVariantData.get_option_string(entry, "source_path")
	var artifact: Dictionary = {
		"entry_index": entry_index,
		"source_path": source_path,
		"archive_path": GFVariantData.get_option_string(entry, "archive_path"),
		"role": GFVariantData.get_option_string_name(entry, "role"),
		"resource_key": GFVariantData.get_option_string_name(entry, "resource_key"),
		"package_id": GFVariantData.get_option_string_name(entry, "package_id", package_id),
		"type_hint": GFVariantData.get_option_string(entry, "type_hint"),
		"exists": false,
		"unreadable": false,
		"size_bytes": -1,
	}
	if GFVariantData.get_option_bool(options, "include_entry_metadata", false):
		artifact["metadata"] = GFVariantData.get_option_dictionary(entry, "metadata")
	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		_append_report_issue(report, "error", _KIND_ARTIFACT_MISSING, "artifact source file is missing", entry, entry_index, {
			"actual_value": source_path,
		})
		return artifact

	var size_bytes: int = _get_file_size(source_path)
	if size_bytes < 0:
		artifact["unreadable"] = true
		_append_report_issue(report, "error", _KIND_ARTIFACT_UNREADABLE, "artifact source file cannot be read", entry, entry_index, {
			"actual_value": source_path,
			"open_error": FileAccess.get_open_error(),
		})
		return artifact

	artifact["exists"] = true
	artifact["size_bytes"] = size_bytes
	if GFVariantData.get_option_bool(options, "include_modified_time", false):
		artifact["modified_time"] = int(FileAccess.get_modified_time(source_path))
	if GFVariantData.get_option_bool(options, "include_sha256", true):
		artifact["sha256"] = FileAccess.get_sha256(source_path).to_lower()
	if GFVariantData.get_option_bool(options, "verify_expected_metadata", true):
		_verify_artifact_expected_metadata(artifact, entry, entry_index, report)
	return artifact


func _verify_artifact_expected_metadata(
	artifact: Dictionary,
	entry: Dictionary,
	entry_index: int,
	report: Dictionary
) -> void:
	var expected_size: int = _get_entry_expected_size(entry)
	if (
		expected_size >= 0
		and expected_size != GFVariantData.get_option_int(artifact, "size_bytes", -1)
	):
		_append_report_issue(report, "error", _KIND_ARTIFACT_SIZE_MISMATCH, "artifact size does not match expected metadata", entry, entry_index, {
			"expected_size_bytes": expected_size,
			"actual_size_bytes": GFVariantData.get_option_int(artifact, "size_bytes", -1),
		})

	var expected_sha256: String = _get_entry_expected_sha256(entry)
	if expected_sha256.is_empty() or not artifact.has("sha256"):
		return
	var actual_sha256: String = GFVariantData.get_option_string(artifact, "sha256")
	if actual_sha256 != expected_sha256:
		_append_report_issue(report, "error", _KIND_ARTIFACT_SHA256_MISMATCH, "artifact sha256 does not match expected metadata", entry, entry_index, {
			"expected_sha256": expected_sha256,
			"actual_sha256": actual_sha256,
		})


func _append_report_issue(
	report: Dictionary,
	severity: String,
	kind: String,
	message: String,
	entry: Dictionary,
	entry_index: int,
	fields: Dictionary
) -> void:
	var issue_fields: Dictionary = {
		"entry_index": entry_index,
		"source_path": GFVariantData.get_option_string(entry, "source_path"),
		"source": GFVariantData.get_option_string(entry, "source_path"),
		"archive_path": GFVariantData.get_option_string(entry, "archive_path"),
		"role": GFVariantData.get_option_string_name(entry, "role"),
		"resource_key": GFVariantData.get_option_string_name(entry, "resource_key"),
		"package_id": GFVariantData.get_option_string_name(entry, "package_id", package_id),
	}
	var merged_fields: Dictionary = GFVariantData.merge_dictionary(issue_fields, fields, true)
	var _issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		severity,
		StringName(kind),
		message,
		merged_fields
	)


func _source_is_inside_root(source_path: String) -> bool:
	if root_path.is_empty():
		return false
	return _GF_PATH_TOOLS.is_path_under_root(source_path, root_path, true, false)


func _make_archive_path(source_path: String) -> String:
	var archive_root: String = GFVariantData.get_option_string(metadata, "archive_root")
	var relative_path: String = _GF_PATH_TOOLS.make_relative_path(source_path, root_path)
	if relative_path.is_empty() or relative_path == source_path:
		relative_path = source_path.trim_prefix("res://").trim_prefix("user://")
	if not _archive_package_scope.is_empty():
		relative_path = _archive_package_scope.path_join(relative_path)
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


static func _get_file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size_bytes: int = int(file.get_length())
	file.close()
	return size_bytes


static func _get_entry_expected_size(entry: Dictionary) -> int:
	var expected_size: int = _first_entry_int(entry, [
		"expected_size_bytes",
		"expected_size",
		"size_bytes",
		"size",
		"bytes",
	], -1)
	if expected_size >= 0:
		return expected_size
	return _first_entry_int(GFVariantData.get_option_dictionary(entry, "metadata"), [
		"expected_size_bytes",
		"expected_size",
		"size_bytes",
		"size",
		"bytes",
	], -1)


static func _get_entry_expected_sha256(entry: Dictionary) -> String:
	var expected_sha256: String = _normalize_sha256(_first_entry_string(entry, [
		"expected_sha256",
		"sha256",
	]))
	if not expected_sha256.is_empty():
		return expected_sha256
	var generic_hash: String = _normalize_sha256(_first_entry_string(entry, ["hash"]))
	if not generic_hash.is_empty():
		return generic_hash
	var entry_metadata: Dictionary = GFVariantData.get_option_dictionary(entry, "metadata")
	expected_sha256 = _normalize_sha256(_first_entry_string(entry_metadata, [
		"expected_sha256",
		"sha256",
	]))
	if not expected_sha256.is_empty():
		return expected_sha256
	return _normalize_sha256(_first_entry_string(entry_metadata, ["hash"]))


static func _first_entry_string(entry: Dictionary, keys: Array, default_value: String = "") -> String:
	for key: Variant in keys:
		if _has_dictionary_key(entry, key):
			return GFVariantData.to_text(GFVariantData.get_option_value(entry, key, default_value)).strip_edges()
	return default_value


static func _first_entry_int(entry: Dictionary, keys: Array, default_value: int = 0) -> int:
	for key: Variant in keys:
		if _has_dictionary_key(entry, key):
			return GFVariantData.get_option_int(entry, key, default_value)
	return default_value


static func _has_dictionary_key(source: Dictionary, key: Variant) -> bool:
	if source.has(key):
		return true
	if key is String:
		var string_key: String = key
		return source.has(StringName(string_key))
	if key is StringName:
		var string_name_key: StringName = key
		return source.has(String(string_name_key))
	return false


static func _normalize_sha256(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	return normalized if normalized.length() == 64 else ""


static func _normalize_archive_path(path: String) -> String:
	var normalized: String = path.strip_edges().replace("\\", "/")
	if normalized.is_empty():
		return ""
	if normalized.begins_with("/") or normalized.contains(":") or normalized.contains("//"):
		return ""
	var parts: PackedStringArray = normalized.split("/", true)
	for part: String in parts:
		if part.is_empty() or part == "." or part == "..":
			return ""
	return "/".join(parts)


static func _normalize_resource_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_resource_path(path, "", true)


static func _normalize_root_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_root_path(path, "", true)


static func _resource_path_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	return FileAccess.file_exists(path)
