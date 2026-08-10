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

## register_source_root() 等便捷入口使用的显式 owner scope。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_SOURCE_ROOT_OWNER_ID: StringName = &"gf.content_package.manual"

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")


# --- 私有变量 ---

var _source_roots_by_owner: Dictionary = {}
var _catalog: GFContentPackageCatalog = GFContentPackageCatalog.new()


# --- GF 生命周期方法 ---

## 初始化内容包服务。
## [br]
## @api framework_internal
func init() -> void:
	_source_roots_by_owner.clear()
	_catalog = GFContentPackageCatalog.new()


## 释放内容包服务状态。
## [br]
## @api framework_internal
func dispose() -> void:
	_source_roots_by_owner.clear()
	_catalog = GFContentPackageCatalog.new()


# --- 公共方法 ---

## 把内容包 source root 注册到默认 manual owner scope。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param root_path: `res://` 或 `user://` 下的内容包根目录。该目录自身或其直接子目录可包含 `gf_content_package.json`。
## [br]
## @return 注册成功返回 true。
func register_source_root(root_path: String) -> bool:
	return register_source_root_for_owner(DEFAULT_SOURCE_ROOT_OWNER_ID, root_path)


## 从默认 manual owner scope 注销内容包 source root。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param root_path: 已注册的 source root。
## [br]
## @return 注销成功返回 true。
func unregister_source_root(root_path: String) -> bool:
	return unregister_source_root_for_owner(DEFAULT_SOURCE_ROOT_OWNER_ID, root_path)


## 清空默认 manual owner scope 的内容包 source root。
## [br]
## @api public
## [br]
## @since 6.0.0
func clear_source_roots() -> void:
	var _cleared_count: int = clear_owner_source_roots(DEFAULT_SOURCE_ROOT_OWNER_ID)


## 为稳定 owner 注册内容包 source root。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param owner_id: 非空 owner ID，用于批量释放来源。
## [br]
## @param root_path: `res://` 或 `user://` 根目录。
## [br]
## @return owner 首次取得该 root 时返回 true。
func register_source_root_for_owner(owner_id: StringName, root_path: String) -> bool:
	if owner_id == &"":
		return false
	var normalized_root: String = _normalize_root_path(root_path)
	if normalized_root.is_empty() or not _is_supported_source_root(normalized_root):
		return false
	var owner_roots: PackedStringArray = _get_owner_roots_ref(owner_id).duplicate()
	if owner_roots.has(normalized_root):
		return false
	var previous_effective_roots: PackedStringArray = get_source_roots()
	var _root_appended: bool = owner_roots.append(normalized_root)
	owner_roots.sort()
	_source_roots_by_owner[owner_id] = owner_roots
	_reset_catalog_if_effective_roots_changed(previous_effective_roots)
	return true


## 从稳定 owner 注销一个内容包 source root。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param owner_id: 注册时使用的 owner ID。
## [br]
## @param root_path: 已注册 root。
## [br]
## @return 找到并释放时返回 true。
func unregister_source_root_for_owner(owner_id: StringName, root_path: String) -> bool:
	if owner_id == &"":
		return false
	var normalized_root: String = _normalize_root_path(root_path)
	var owner_roots: PackedStringArray = _get_owner_roots_ref(owner_id).duplicate()
	var root_index: int = owner_roots.find(normalized_root)
	if root_index < 0:
		return false
	var previous_effective_roots: PackedStringArray = get_source_roots()
	owner_roots.remove_at(root_index)
	if owner_roots.is_empty():
		var _owner_erased: bool = _source_roots_by_owner.erase(owner_id)
	else:
		_source_roots_by_owner[owner_id] = owner_roots
	_reset_catalog_if_effective_roots_changed(previous_effective_roots)
	return true


## 原子替换一个 owner 的全部 source root。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param owner_id: 非空 owner ID。
## [br]
## @param root_paths: 新 root 集合；空集合表示释放 owner。
## [br]
## @return 类型化验证报告；任一 root 无效时不修改现有状态。
func replace_owner_source_roots(
	owner_id: StringName,
	root_paths: PackedStringArray
) -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new("Content package owner source roots", {
		"owner_id": String(owner_id),
	})
	var normalized_roots: PackedStringArray = PackedStringArray()
	if owner_id == &"":
		var _owner_issue: RefCounted = report.add_error(
			&"invalid_owner_id",
			"owner_id must not be empty",
			owner_id,
			"owner_id"
		)
	for root_path: String in root_paths:
		var normalized_root: String = _normalize_root_path(root_path)
		if normalized_root.is_empty() or not _is_supported_source_root(normalized_root):
			var _root_issue: RefCounted = report.add_error(
				&"invalid_source_root",
				"source root must use res:// or user://",
				root_path,
				"source_roots"
			)
			continue
		if not normalized_roots.has(normalized_root):
			var _root_appended: bool = normalized_roots.append(normalized_root)
	normalized_roots.sort()
	report.extra_fields["requested_source_roots"] = normalized_roots.duplicate()
	if not report.is_ok():
		report.extra_fields["applied"] = false
		report.extra_fields["source_roots"] = get_owner_source_roots(owner_id)
		return report

	var previous_effective_roots: PackedStringArray = get_source_roots()
	if normalized_roots.is_empty():
		var _owner_erased: bool = _source_roots_by_owner.erase(owner_id)
	else:
		_source_roots_by_owner[owner_id] = normalized_roots
	_reset_catalog_if_effective_roots_changed(previous_effective_roots)
	report.extra_fields["applied"] = true
	report.extra_fields["source_roots"] = normalized_roots.duplicate()
	return report


## 释放一个 owner 的全部 source root。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param owner_id: 要释放的 owner ID。
## [br]
## @return 释放的 owner-root 关系数量。
func clear_owner_source_roots(owner_id: StringName) -> int:
	if owner_id == &"":
		return 0
	var owner_roots: PackedStringArray = _get_owner_roots_ref(owner_id)
	if owner_roots.is_empty():
		return 0
	var removed_count: int = owner_roots.size()
	var previous_effective_roots: PackedStringArray = get_source_roots()
	var _owner_erased: bool = _source_roots_by_owner.erase(owner_id)
	_reset_catalog_if_effective_roots_changed(previous_effective_roots)
	return removed_count


## 获取一个 owner 持有的 source root。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param owner_id: owner ID。
## [br]
## @return 排序后的 root 副本。
func get_owner_source_roots(owner_id: StringName) -> PackedStringArray:
	return _get_owner_roots_ref(owner_id).duplicate()


## 获取当前持有 source root 的 owner ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 排序后的 owner ID 文本。
func get_source_root_owner_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for owner_key: Variant in _source_roots_by_owner.keys():
		var owner_id: StringName = _variant_to_owner_id(owner_key)
		if owner_id != &"":
			var _owner_appended: bool = result.append(String(owner_id))
	result.sort()
	return result


## 获取内容包 source root 列表。
## [br]
## @api public
## [br]
## @return source root 副本。
func get_source_roots() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for owner_id_text: String in get_source_root_owner_ids():
		for root_path: String in _get_owner_roots_ref(StringName(owner_id_text)):
			if not result.has(root_path):
				var _root_appended: bool = result.append(root_path)
	result.sort()
	return result


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
		for source_root: String in get_source_roots():
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
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 package_count、package_ids、ordered_package_ids、duplicate_package_ids、rejected_manifest_count 和 rejected_manifest_inputs。
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
## @schema manifests: Array[GFContentPackageManifest]，无效项会被拒绝并进入诊断。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 package_count、package_ids、ordered_package_ids、duplicate_package_ids、rejected_manifest_count 和 rejected_manifest_inputs。
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
## @since 4.4.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 source_roots、source_root_owners 和 catalog。
func get_debug_snapshot() -> Dictionary:
	var source_root_owners: Dictionary = {}
	for owner_id_text: String in get_source_root_owner_ids():
		source_root_owners[owner_id_text] = get_owner_source_roots(StringName(owner_id_text))
	return {
		"source_roots": get_source_roots(),
		"source_root_owners": source_root_owners,
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


func _reset_catalog_if_effective_roots_changed(previous_roots: PackedStringArray) -> void:
	if previous_roots == get_source_roots():
		return
	_reset_catalog_after_roots_changed()


func _get_owner_roots_ref(owner_id: StringName) -> PackedStringArray:
	var roots_value: Variant = _source_roots_by_owner.get(owner_id)
	if roots_value is PackedStringArray:
		var roots: PackedStringArray = roots_value
		return roots
	return PackedStringArray()


static func _variant_to_owner_id(value: Variant) -> StringName:
	if value is StringName:
		var owner_id: StringName = value
		return owner_id
	if value is String:
		var owner_text: String = value
		return StringName(owner_text)
	return &""


static func _normalize_root_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_root_path(path)


static func _is_supported_source_root(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("user://")
