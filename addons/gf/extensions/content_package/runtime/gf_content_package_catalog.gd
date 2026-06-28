## GFContentPackageCatalog: 内容包集合与依赖图诊断。
##
## 管理一组 GFContentPackageManifest，提供包查询、依赖顺序、重复/缺失/循环依赖报告，
## 并可把内容包资源键映射注册到 GFResourceResolverUtility。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.4.0
class_name GFContentPackageCatalog
extends RefCounted


# --- 常量 ---

const _GF_DEPENDENCY_GRAPH_TOOLS = preload("res://addons/gf/kernel/core/gf_dependency_graph_tools.gd")

const _REPORT_SUBJECT: String = "Content package catalog"
const _KIND_DUPLICATE_PACKAGE_ID: String = "duplicate_package_id"
const _KIND_INVALID_MANIFEST: String = "invalid_manifest"
const _KIND_MISSING_DEPENDENCY: String = "missing_dependency"
const _KIND_DEPENDENCY_CYCLE: String = "dependency_cycle"
const _KIND_RESOURCE_REGISTRATION_FAILED: String = "resource_registration_failed"


# --- 私有变量 ---

var _manifests: Dictionary = {}
var _manifest_order: Array[StringName] = []
var _duplicate_package_ids: PackedStringArray = PackedStringArray()


# --- 公共方法 ---

## 清空目录。
## [br]
## @api public
func clear() -> void:
	_manifests.clear()
	_manifest_order.clear()
	_duplicate_package_ids.clear()


## 注册内容包 manifest。
## [br]
## @api public
## [br]
## @param manifest: 内容包 manifest。
## [br]
## @return 注册成功返回 true；重复或空 ID 返回 false。
func add_manifest(manifest: GFContentPackageManifest) -> bool:
	if manifest == null or manifest.package_id == &"":
		return false
	if _manifests.has(manifest.package_id):
		_add_duplicate_package_id(manifest.package_id)
		return false

	_manifests[manifest.package_id] = manifest
	_manifest_order.append(manifest.package_id)
	return true


## 批量替换内容包 manifest。
## [br]
## @api public
## [br]
## @param manifests: manifest 列表。
## [br]
## @return 当前目录。
## [br]
## @schema manifests: Array[GFContentPackageManifest]，无效项会被忽略或进入诊断。
func set_manifests(manifests: Array[GFContentPackageManifest]) -> GFContentPackageCatalog:
	clear()
	for manifest: GFContentPackageManifest in manifests:
		var _added: bool = add_manifest(manifest)
	return self


## 移除内容包 manifest。
## [br]
## @api public
## [br]
## @param package_id: 内容包 ID。
## [br]
## @return 移除成功返回 true。
func remove_manifest(package_id: StringName) -> bool:
	if not _manifests.has(package_id):
		return false
	var _erase_result: bool = _manifests.erase(package_id)
	var order_index: int = _manifest_order.find(package_id)
	if order_index >= 0:
		_manifest_order.remove_at(order_index)
	_remove_duplicate_package_id(package_id)
	return true


## 检查内容包是否存在。
## [br]
## @api public
## [br]
## @param package_id: 内容包 ID。
## [br]
## @return 存在返回 true。
func has_package(package_id: StringName) -> bool:
	return _manifests.has(package_id)


## 获取内容包 manifest。
## [br]
## @api public
## [br]
## @param package_id: 内容包 ID。
## [br]
## @return manifest；不存在时返回 null。
func get_manifest(package_id: StringName) -> GFContentPackageManifest:
	var manifest_value: Variant = _manifests.get(package_id)
	if manifest_value is GFContentPackageManifest:
		var manifest: GFContentPackageManifest = manifest_value
		return manifest
	return null


## 获取内容包 ID 列表。
## [br]
## @api public
## [br]
## @return 按注册顺序排列的内容包 ID。
func get_package_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for package_id: StringName in _manifest_order:
		var _append_result: bool = result.append(String(package_id))
	return result


## 获取按依赖优先排序的内容包 ID。
## [br]
## @api public
## [br]
## @return 依赖包先于依赖方出现的内容包 ID 列表。
func get_ordered_package_ids() -> PackedStringArray:
	var graph_report: Dictionary = _GF_DEPENDENCY_GRAPH_TOOLS.sort_dependency_first(
		_get_manifest_order_as_strings(),
		_build_dependency_map()
	)
	return GFVariantData.get_option_packed_string_array(graph_report, "ordered_ids", PackedStringArray())


## 获取依赖图和 manifest 诊断报告。
## [br]
## @api public
## [br]
## @param options: 校验选项，透传给 GFContentPackageManifest。
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 package_count、package_ids、ordered_package_ids 和 duplicate_package_ids。
func get_graph_report(options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report()
	report["package_count"] = _manifests.size()
	report["package_ids"] = get_package_ids()
	report["ordered_package_ids"] = get_ordered_package_ids()
	report["duplicate_package_ids"] = _duplicate_package_ids.duplicate()

	_add_duplicate_issues(report)
	_add_manifest_issues(report, options)
	_add_dependency_issues(report)
	return _finalize_report(report)


## 把内容包资源键注册到资源解析器。
## [br]
## @api public
## [br]
## @param resolver: 标准资源解析器。
## [br]
## @param options: 注册选项。`base_priority` 默认为 0；`check_resource_exists` 默认为 false。
## [br]
## @return GFValidationReportDictionary 兼容报告，并包含 registered_count。
## [br]
## @schema options: Dictionary，可包含 base_priority: int 和 check_resource_exists: bool。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 registered_count。
func register_resources(resolver: GFResourceResolverUtility, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report("Content package resource registration")
	_unregister_content_package_resources(resolver)
	var graph_report: Dictionary = get_graph_report(options)
	var _merged_report: Dictionary = GFValidationReportDictionary.merge_report(report, graph_report, {
		"copy_fields": PackedStringArray([
			"package_count",
			"package_ids",
			"ordered_package_ids",
			"duplicate_package_ids",
		]),
	})
	var registered_count: int = 0
	var base_priority: int = GFVariantData.get_option_int(options, "base_priority")

	if not GFVariantData.get_option_bool(graph_report, "ok"):
		report["registered_count"] = 0
		return _finalize_report(report, "Content package resource registration")

	for package_id_text: String in get_ordered_package_ids():
		var manifest: GFContentPackageManifest = get_manifest(StringName(package_id_text))
		if manifest == null:
			continue
		for resource_entry: Dictionary in manifest.get_normalized_resources():
			var resource_key: StringName = GFVariantData.get_option_string_name(resource_entry, "key")
			var path: String = GFVariantData.get_option_string(resource_entry, "path")
			var type_hint: String = GFVariantData.get_option_string(resource_entry, "type_hint")
			var priority: int = base_priority + GFVariantData.get_option_int(resource_entry, "priority")
			var metadata: Dictionary = GFVariantData.get_option_dictionary(resource_entry, "metadata")
			metadata["content_package_id"] = StringName(package_id_text)
			metadata["content_package_resource_key"] = resource_key
			metadata["_gf_content_package_resource"] = true
			if resolver.register_path(resource_key, path, type_hint, priority, metadata):
				registered_count += 1
				continue

			var _issue: Dictionary = GFValidationReportDictionary.append_issue(
				report,
				"error",
				StringName(_KIND_RESOURCE_REGISTRATION_FAILED),
				"resource registration failed",
				{
					"key": package_id_text,
					"row_key": resource_key,
					"field": &"resources",
					"path": "packages.%s.resources" % package_id_text,
					"actual_value": path,
				}
			)

	report["registered_count"] = registered_count
	return _finalize_report(report, "Content package resource registration")


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 目录快照。
## [br]
## @schema return: Dictionary，包含 package_count、package_ids、ordered_package_ids 和 duplicate_package_ids。
func get_debug_snapshot() -> Dictionary:
	return {
		"package_count": _manifests.size(),
		"package_ids": get_package_ids(),
		"ordered_package_ids": get_ordered_package_ids(),
		"duplicate_package_ids": _duplicate_package_ids.duplicate(),
	}


# --- 私有/辅助方法 ---

func _add_duplicate_package_id(package_id: StringName) -> void:
	var package_id_text: String = String(package_id)
	if not _duplicate_package_ids.has(package_id_text):
		var _append_result: bool = _duplicate_package_ids.append(package_id_text)


func _remove_duplicate_package_id(package_id: StringName) -> void:
	var package_id_text: String = String(package_id)
	var index: int = _duplicate_package_ids.find(package_id_text)
	while index >= 0:
		_duplicate_package_ids.remove_at(index)
		index = _duplicate_package_ids.find(package_id_text)


func _unregister_content_package_resources(resolver: GFResourceResolverUtility) -> void:
	if resolver == null:
		return
	for key_text: String in resolver.get_registered_keys():
		var key: StringName = StringName(key_text)
		var report: Dictionary = resolver.resolve(key, "", { "check_exists": false })
		var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")
		if not GFVariantData.get_option_bool(metadata, "_gf_content_package_resource"):
			continue
		var _unregistered: bool = resolver.unregister_path(key)


func _add_duplicate_issues(report: Dictionary) -> void:
	for package_id_text: String in _duplicate_package_ids:
		var _issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			StringName(_KIND_DUPLICATE_PACKAGE_ID),
			"package_id is duplicated",
			{
				"key": package_id_text,
				"row_key": package_id_text,
				"field": &"package_id",
				"path": "packages.%s.package_id" % package_id_text,
				"actual_value": package_id_text,
			}
		)


func _add_manifest_issues(
	report: Dictionary,
	options: Dictionary
) -> void:
	for package_id: StringName in _manifest_order:
		var manifest: GFContentPackageManifest = get_manifest(package_id)
		if manifest == null:
			continue
		var manifest_report: Dictionary = manifest.get_validation_report(options)
		for issue_variant: Variant in GFVariantData.get_option_array(manifest_report, "issues"):
			var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)
			var issue_fields: Dictionary = {
				"key": package_id,
				"source_path": GFVariantData.get_option_string(issue, "source_path", manifest.source_path),
				"source": GFVariantData.get_option_string(issue, "source", manifest.source_path),
				"row_key": GFVariantData.get_option_value(issue, "row_key", package_id),
				"row_index": GFVariantData.get_option_int(issue, "row_index", -1),
				"field": GFVariantData.get_option_string_name(issue, "field"),
				"path": GFVariantData.get_option_string(issue, "path"),
				"actual_value": GFVariantData.get_option_value(issue, "actual_value"),
				"expected_value": GFVariantData.get_option_value(issue, "expected_value"),
			}
			var _added_issue: Dictionary = GFValidationReportDictionary.append_issue(
				report,
				GFVariantData.get_option_string(issue, "severity", "error"),
				StringName(GFVariantData.get_option_string(issue, "kind", _KIND_INVALID_MANIFEST)),
				GFVariantData.get_option_string(issue, "message"),
				issue_fields
			)


func _add_dependency_issues(report: Dictionary) -> void:
	for package_id: StringName in _manifest_order:
		var manifest: GFContentPackageManifest = get_manifest(package_id)
		if manifest == null:
			continue
		for dependency_id_text: String in manifest.dependencies:
			var dependency_id: StringName = StringName(dependency_id_text)
			if _manifests.has(dependency_id):
				continue
			var _missing_issue: Dictionary = GFValidationReportDictionary.append_issue(
				report,
				"error",
				StringName(_KIND_MISSING_DEPENDENCY),
				"dependency package is missing",
				{
					"key": package_id,
					"row_key": package_id,
					"field": &"dependencies",
					"path": "packages.%s.dependencies" % String(package_id),
					"actual_value": dependency_id_text,
				}
			)

	var cycles: Array[PackedStringArray] = _collect_dependency_cycles()
	for cycle: PackedStringArray in cycles:
		var _cycle_issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			StringName(_KIND_DEPENDENCY_CYCLE),
			"dependency cycle detected",
			{
				"field": &"dependencies",
				"path": "dependencies",
				"actual_value": cycle,
			}
		)


func _collect_dependency_cycles() -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var graph_report: Dictionary = _GF_DEPENDENCY_GRAPH_TOOLS.sort_dependency_first(
		_get_manifest_order_as_strings(),
		_build_dependency_map()
	)
	for cycle_variant: Variant in GFVariantData.get_option_array(graph_report, "dependency_cycles"):
		if cycle_variant is PackedStringArray:
			var cycle: PackedStringArray = cycle_variant
			result.append(cycle.duplicate())
	return result


func _build_dependency_map() -> Dictionary:
	var result: Dictionary = {}
	for package_id: StringName in _manifest_order:
		var manifest: GFContentPackageManifest = get_manifest(package_id)
		if manifest == null:
			continue
		var dependencies: PackedStringArray = PackedStringArray()
		for dependency_id_text: String in manifest.dependencies:
			var dependency_id: StringName = StringName(dependency_id_text)
			if not _manifests.has(dependency_id):
				continue
			var _dependency_appended: bool = dependencies.append(String(dependency_id))
		result[String(package_id)] = dependencies
	return result


func _get_manifest_order_as_strings() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for package_id: StringName in _manifest_order:
		var _package_appended: bool = result.append(String(package_id))
	return result


func _make_report(subject: String = _REPORT_SUBJECT) -> Dictionary:
	return {
		"subject": subject,
		"issues": [],
	}


func _finalize_report(report: Dictionary, subject: String = _REPORT_SUBJECT) -> Dictionary:
	return GFValidationReportDictionary.finalize_report(report, subject, {
		"fallback_action": "Review the first content package catalog issue.",
		"no_action": "Content package catalog is valid.",
	})
