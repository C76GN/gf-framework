## GFContentPackageUtility: 内容包发现、目录构建和资源解析注册服务。
##
## 维护显式 source root 列表，加载其中的 `gf_content_package.json`，构建 GFContentPackageCatalog，
## 并把内容包资源键映射同步到 GFResourceResolverUtility。它不下载内容、不扫描全项目、不决定包启用策略。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.4.0
class_name GFContentPackageUtility
extends GFUtility

# --- 信号 ---

## 当内容包目录重建后发出。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param catalog: 当前内容包目录的隔离快照。
signal catalog_rebuilt(catalog: GFContentPackageCatalog)


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")


# --- 私有变量 ---

var _source_roots: PackedStringArray = PackedStringArray()
var _catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()


# --- GF 生命周期方法 ---

## 初始化内容包服务。
## [br]
## @api framework_internal
func init() -> void:
	_source_roots.clear()
	_catalog = GFContentPackageCatalog.new()


## 释放内容包服务状态。
## [br]
## @api framework_internal
func dispose() -> void:
	_source_roots.clear()
	_catalog = GFContentPackageCatalog.new()


# --- 公共方法 ---

## 注册内容包 source root。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param root_path: `res://` 或 `user://` 下的内容包根目录。该目录自身或其直接子目录可包含 `gf_content_package.json`。
## [br]
## @return 注册成功返回 true。
func register_source_root(root_path: String) -> bool:
	var normalized_root: String = _normalize_root_path(root_path)
	if normalized_root.is_empty() or not _is_supported_source_root(normalized_root):
		return false
	if _source_roots.has(normalized_root):
		return false

	var _append_result: bool = _source_roots.append(normalized_root)
	_reset_catalog_after_roots_changed()
	return true


## 注销内容包 source root。
## [br]
## @api public
## [br]
## @param root_path: 已注册的 source root。
## [br]
## @return 注销成功返回 true。
func unregister_source_root(root_path: String) -> bool:
	var normalized_root: String = _normalize_root_path(root_path)
	for index: int in range(_source_roots.size()):
		if _source_roots[index] != normalized_root:
			continue
		_source_roots.remove_at(index)
		_reset_catalog_after_roots_changed()
		return true
	return false


## 清空内容包 source root。
## [br]
## @api public
func clear_source_roots() -> void:
	_source_roots.clear()
	_reset_catalog_after_roots_changed()


## 获取内容包 source root 列表。
## [br]
## @api public
## [br]
## @return source root 副本。
func get_source_roots() -> PackedStringArray:
	return _source_roots.duplicate()


## 获取当前内容包目录。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @return 当前内容包目录的深拷贝。
func get_catalog() -> GFContentPackageCatalog:
	return _catalog.duplicate_catalog()


## 发现 source root 中的内容包 manifest 路径。
## [br]
## @api public
## [br]
## @param root_path: 可选 source root；为空时使用全部已注册 source root。
## [br]
## @return manifest 路径列表。
func discover_manifest_paths(root_path: String = "") -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if root_path.strip_edges().is_empty():
		for source_root: String in _source_roots:
			_append_manifest_paths_for_root(source_root, result)
	else:
		_append_manifest_paths_for_root(_normalize_root_path(root_path), result)
	result.sort()
	return result


## 从 manifest 路径加载内容包。
## [br]
## @api public
## [br]
## @param path: manifest 文件路径。
## [br]
## @return 内容包 manifest；加载失败返回 null。
func load_manifest(path: String) -> GFContentPackageManifest:
	return GFContentPackageManifest.load_from_path(path)


## 从已注册 source root 重建内容包目录。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param options: 校验选项，透传给 GFContentPackageCatalog。
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 package_count、package_ids、ordered_package_ids 和 duplicate_package_ids。
func rebuild_catalog(options: Dictionary = {}) -> Dictionary:
	var manifests: Array[GFContentPackageManifest] = []
	var failed_manifest_paths: PackedStringArray = PackedStringArray()
	for manifest_path: String in discover_manifest_paths():
		var manifest: GFContentPackageManifest = load_manifest(manifest_path)
		if manifest != null:
			manifests.append(manifest)
		else:
			var _append_failed_result: bool = failed_manifest_paths.append(manifest_path)
	var candidate_catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()
	var _candidate_updated: GFContentPackageCatalog = candidate_catalog.set_manifests(manifests)
	var report: Dictionary = _add_manifest_load_failures(candidate_catalog.get_graph_report(options), failed_manifest_paths)
	if _report_ok(report):
		_catalog = candidate_catalog
		catalog_rebuilt.emit(_catalog.duplicate_catalog())
	return report


## 手动替换内容包目录。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param manifests: 内容包 manifest 列表。
## [br]
## @param options: 校验选项，透传给 GFContentPackageCatalog。
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema manifests: Array[GFContentPackageManifest]，无效项会被忽略或进入诊断。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 package_count、package_ids、ordered_package_ids 和 duplicate_package_ids。
func set_manifests(
	manifests: Array[GFContentPackageManifest],
	options: Dictionary = {}
) -> Dictionary:
	var candidate_catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()
	var _candidate_updated: GFContentPackageCatalog = candidate_catalog.set_manifests(manifests)
	var report: Dictionary = candidate_catalog.get_graph_report(options)
	if _report_ok(report):
		_catalog = candidate_catalog
		catalog_rebuilt.emit(_catalog.duplicate_catalog())
	return report


## 把当前内容包目录同步到资源解析器。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param resolver: 标准资源解析器。
## [br]
## @param options: 注册选项。`base_priority` 默认为 0；校验选项透传给 manifest。
## [br]
## @return GFValidationReportDictionary 兼容报告，并包含 registered_count。
## [br]
## @schema options: Dictionary，可包含 base_priority: int、check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 registered_count。
func register_resources(resolver: GFResourceResolverUtility, options: Dictionary = {}) -> Dictionary:
	if resolver == null:
		var report: Dictionary = {
			"subject": "Content package resource registration",
			"registered_count": 0,
			"issues": [],
		}
		var _issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"missing_resource_resolver",
			"resource resolver is required"
		)
		return GFValidationReportDictionary.finalize_report(report, "Content package resource registration", {
			"fallback_action": "Pass a valid GFResourceResolverUtility instance.",
			"no_action": "Content package resources are registered.",
		})
	return _catalog.register_resources(resolver, options)


## 获取内容包服务调试快照。
## [br]
## @api public
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 source_roots 和 catalog。
func get_debug_snapshot() -> Dictionary:
	return {
		"source_roots": _source_roots.duplicate(),
		"catalog": _catalog.get_debug_snapshot(),
	}


# --- 私有/辅助方法 ---

func _append_manifest_paths_for_root(root_path: String, result: PackedStringArray) -> void:
	if root_path.is_empty() or not _is_supported_source_root(root_path):
		return

	var direct_manifest_path: String = root_path.path_join(GFContentPackageManifest.FILE_NAME)
	if FileAccess.file_exists(direct_manifest_path):
		_append_unique_path(result, direct_manifest_path)

	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result: Error = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with("."):
			var manifest_path: String = root_path.path_join(entry).path_join(GFContentPackageManifest.FILE_NAME)
			if FileAccess.file_exists(manifest_path):
				_append_unique_path(result, manifest_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _append_unique_path(result: PackedStringArray, path: String) -> void:
	var normalized_path: String = _normalize_root_path(path)
	if result.has(normalized_path):
		return
	var _append_result: bool = result.append(normalized_path)


func _add_manifest_load_failures(report: Dictionary, failed_manifest_paths: PackedStringArray) -> Dictionary:
	if failed_manifest_paths.is_empty():
		return report

	for manifest_path: String in failed_manifest_paths:
		var _issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			&"invalid_manifest_file",
			"manifest file could not be loaded",
			{
				"key": manifest_path,
				"source_path": manifest_path,
				"source": manifest_path,
				"field": &"source_path",
				"path": manifest_path,
				"actual_value": manifest_path,
				"expected_value": "valid JSON object",
			}
		)
	return GFValidationReportDictionary.finalize_report(report, "Content package catalog", {
		"fallback_action": "Review the first content package catalog issue.",
		"no_action": "Content package catalog is valid.",
	})


func _report_ok(report: Dictionary) -> bool:
	return GFVariantData.get_option_bool(report, "ok", false)


func _reset_catalog_after_roots_changed() -> void:
	_catalog = GFContentPackageCatalog.new()
	catalog_rebuilt.emit(_catalog.duplicate_catalog())


static func _normalize_root_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_root_path(path)


static func _is_supported_source_root(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("user://")
