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

## 提供依赖优先拓扑排序和循环依赖诊断。
## [br]
## @api private
const _GF_DEPENDENCY_GRAPH_TOOLS = preload("res://addons/gf/kernel/core/gf_dependency_graph_tools.gd")

## 内容包目录校验报告的默认主题。
## [br]
## @api private
const _REPORT_SUBJECT: String = "Content package catalog"

## 同一 package_id 重复注册时使用的问题类型。
## [br]
## @api private
const _KIND_DUPLICATE_PACKAGE_ID: String = "duplicate_package_id"

## 缺少有效 manifest 输入时使用的问题类型。
## [br]
## @api private
const _KIND_INVALID_MANIFEST: String = "invalid_manifest"

## manifest 引用了目录中不存在的依赖包时使用的问题类型。
## [br]
## @api private
const _KIND_MISSING_DEPENDENCY: String = "missing_dependency"

## 依赖图报告包含循环时使用的问题类型。
## [br]
## @api private
const _KIND_DEPENDENCY_CYCLE: String = "dependency_cycle"

## 将资源注册事务失败时使用的问题类型。
## [br]
## @api private
const _KIND_RESOURCE_REGISTRATION_FAILED: String = "resource_registration_failed"

## 未提供资源解析器时使用的问题类型。
## [br]
## @api private
const _KIND_MISSING_RESOURCE_RESOLVER: String = "missing_resource_resolver"

## 该目录在资源解析器中替换路径集合时使用的稳定 owner ID。
## [br]
## @api private
const _RESOLVER_OWNER_ID: StringName = &"gf.content_package.catalog"


# --- 私有变量 ---

## 按 package_id 保存目录持有的 manifest 副本。
## [br]
## @api private
var _manifests: Dictionary = {}

## 保存首次接受的 package_id 顺序，用于稳定遍历和依赖图排序输入。
## [br]
## @api private
var _manifest_order: Array[StringName] = []

## 记录输入过程中遇到的重复 package_id，供目录报告诊断。
## [br]
## @api private
var _duplicate_package_ids: PackedStringArray = PackedStringArray()

## 暂存 null 或缺少 package_id 的输入及其索引、来源和可用 manifest 副本。
## [br]
## @api private
var _rejected_manifest_inputs: Array[Dictionary] = []


# --- 公共方法 ---

## 清空目录。
## [br]
## @api public
func clear() -> void:
	_manifests.clear()
	_manifest_order.clear()
	_duplicate_package_ids.clear()
	_rejected_manifest_inputs.clear()


## 注册内容包 manifest。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param manifest: 内容包 manifest。
## [br]
## @return: 注册成功返回 true；空 manifest、重复或空 ID 返回 false，并可从 graph report 读取诊断。
func add_manifest(manifest: GFContentPackageManifest) -> bool:
	return _add_manifest_input(manifest, -1)


## 批量替换内容包 manifest。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param manifests: manifest 列表。
## [br]
## @return 当前目录。
## [br]
## @schema manifests: Array[GFContentPackageManifest]，无效项会被拒绝并进入诊断。
func set_manifests(manifests: Array[GFContentPackageManifest]) -> GFContentPackageCatalog:
	clear()
	for index: int in range(manifests.size()):
		var _added: bool = _add_manifest_input(manifests[index], index)
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
## @since 4.4.0
## [br]
## @param package_id: 内容包 ID。
## [br]
## @return manifest 深拷贝；不存在时返回 null。
func get_manifest(package_id: StringName) -> GFContentPackageManifest:
	var manifest: GFContentPackageManifest = _get_manifest_ref(package_id)
	return manifest.duplicate_manifest() if manifest != null else null


## 创建目录深拷贝。
## [br]
## @api public
## [br]
## @return 与当前依赖图和重复 ID 状态一致的新目录。
## [br]
## @since 8.0.0
func duplicate_catalog() -> GFContentPackageCatalog:
	var result: GFContentPackageCatalog = GFContentPackageCatalog.new()
	for package_id: StringName in _manifest_order:
		var manifest: GFContentPackageManifest = _get_manifest_ref(package_id)
		if manifest == null:
			continue
		result._manifests[package_id] = manifest.duplicate_manifest()
		result._manifest_order.append(package_id)
	result._duplicate_package_ids = _duplicate_package_ids.duplicate()
	for record: Dictionary in _rejected_manifest_inputs:
		var record_copy: Dictionary = record.duplicate()
		var manifest_value: Variant = record.get("manifest")
		if manifest_value is GFContentPackageManifest:
			var rejected_manifest: GFContentPackageManifest = manifest_value
			record_copy["manifest"] = rejected_manifest.duplicate_manifest()
		result._rejected_manifest_inputs.append(record_copy)
	return result


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
	var graph_report: Dictionary = _get_dependency_sort_report()
	return GFVariantData.get_option_packed_string_array(graph_report, "ordered_ids", PackedStringArray())


## 查询有效内容包并返回隔离结果。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param query: 通用内容包查询。
## [br]
## @param options: manifest 和依赖图校验选项。
## [br]
## @return 类型化查询终态；目录无效时不返回部分结果。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
func query_packages(
	query: GFContentPackageQuery,
	options: Dictionary = {}
) -> GFContentPackageQueryResult:
	if query == null:
		return _make_query_failure(
			GFContentPackageQueryResult.STATUS_INVALID_QUERY,
			&"",
			&"invalid_query",
			"content package query is required"
		)
	var graph_report: Dictionary = get_graph_report(options)
	if not GFVariantData.get_option_bool(graph_report, "ok", false):
		return GFContentPackageQueryResult.new().configure_result(
			false,
			GFContentPackageQueryResult.STATUS_INVALID_CATALOG,
			query.query_id,
			PackedStringArray(),
			PackedStringArray(),
			[],
			graph_report
		)

	var ordered_package_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		graph_report,
		"ordered_package_ids"
	)
	var direct_package_ids: PackedStringArray = PackedStringArray()
	for package_id_text: String in ordered_package_ids:
		var manifest: GFContentPackageManifest = _get_manifest_ref(StringName(package_id_text))
		if manifest == null or not query.matches(manifest):
			continue
		var _direct_id_appended: bool = direct_package_ids.append(package_id_text)
		if query.max_results > 0 and direct_package_ids.size() >= query.max_results:
			break

	var package_ids: PackedStringArray = direct_package_ids.duplicate()
	if query.include_dependencies:
		package_ids = _expand_dependency_closure(direct_package_ids, ordered_package_ids)
	var manifests: Array[GFContentPackageManifest] = []
	for package_id_text: String in package_ids:
		var manifest: GFContentPackageManifest = _get_manifest_ref(StringName(package_id_text))
		if manifest != null:
			manifests.append(manifest.duplicate_manifest())
	var report: Dictionary = _make_report("Content package query")
	report["query_id"] = query.query_id
	report["status"] = GFContentPackageQueryResult.STATUS_COMPLETED
	report["direct_package_ids"] = direct_package_ids.duplicate()
	report["package_ids"] = package_ids.duplicate()
	report["direct_package_count"] = direct_package_ids.size()
	report["package_count"] = package_ids.size()
	report = _finalize_report(report, "Content package query")
	return GFContentPackageQueryResult.new().configure_result(
		true,
		GFContentPackageQueryResult.STATUS_COMPLETED,
		query.query_id,
		direct_package_ids,
		package_ids,
		manifests,
		report
	)


## 获取依赖图和 manifest 诊断报告。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param options: 校验选项，透传给 GFContentPackageManifest。
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，并包含 package_count、package_ids、ordered_package_ids、duplicate_package_ids、rejected_manifest_count 和 rejected_manifest_inputs。
func get_graph_report(options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_report()
	var dependency_sort_report: Dictionary = _get_dependency_sort_report()
	report["package_count"] = _manifests.size()
	report["package_ids"] = get_package_ids()
	report["ordered_package_ids"] = GFVariantData.get_option_packed_string_array(
		dependency_sort_report,
		"ordered_ids"
	)
	report["duplicate_package_ids"] = _duplicate_package_ids.duplicate()
	report["rejected_manifest_count"] = _rejected_manifest_inputs.size()
	report["rejected_manifest_inputs"] = _get_rejected_manifest_summaries()

	_add_duplicate_issues(report)
	_add_rejected_manifest_issues(report, options)
	_add_manifest_issues(report, options)
	_add_dependency_issues(report, dependency_sort_report)
	return _finalize_report(report)


## 把内容包资源键注册到资源解析器。
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
	var report: Dictionary = _make_report("Content package resource registration")
	var graph_report: Dictionary = get_graph_report(options)
	var _merged_report: Dictionary = GFValidationReportDictionary.merge_report(report, graph_report, {
		"copy_fields": PackedStringArray([
			"package_count",
			"package_ids",
			"ordered_package_ids",
			"duplicate_package_ids",
			"rejected_manifest_count",
			"rejected_manifest_inputs",
		]),
	})
	var registered_count: int = 0
	var base_priority: int = GFVariantData.get_option_int(options, "base_priority")

	if resolver == null:
		var _missing_resolver_issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			StringName(_KIND_MISSING_RESOURCE_RESOLVER),
			"resource resolver is required"
		)
		report["registered_count"] = 0
		return _finalize_report(report, "Content package resource registration")

	if not GFVariantData.get_option_bool(graph_report, "ok"):
		report["registered_count"] = 0
		return _finalize_report(report, "Content package resource registration")

	var registration_entries: Array[Dictionary] = []
	for package_id_text: String in GFVariantData.get_option_packed_string_array(
		graph_report,
		"ordered_package_ids"
	):
		var manifest: GFContentPackageManifest = _get_manifest_ref(StringName(package_id_text))
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
			registration_entries.append({
				"resource_key": resource_key,
				"path": path,
				"type_hint": type_hint,
				"priority": priority,
				"metadata": metadata,
			})

	var replacement_report: Dictionary = resolver.replace_owner_paths(
		_RESOLVER_OWNER_ID,
		registration_entries
	)
	if GFVariantData.get_option_bool(replacement_report, "ok", false):
		registered_count = GFVariantData.get_option_int(replacement_report, "registered_count")
	else:
		var _issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			StringName(_KIND_RESOURCE_REGISTRATION_FAILED),
			"resource registration transaction failed",
			{
				"field": &"resources",
				"path": "packages.resources",
				"actual_value": GFVariantData.get_option_string_name(replacement_report, "reason"),
				"row_index": GFVariantData.get_option_int(replacement_report, "failed_index", -1),
			}
		)

	report["registered_count"] = registered_count
	return _finalize_report(report, "Content package resource registration")


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @return 目录快照。
## [br]
## @schema return: Dictionary，包含 package_count、package_ids、ordered_package_ids、duplicate_package_ids 和 rejected_manifest_count。
func get_debug_snapshot() -> Dictionary:
	return {
		"package_count": _manifests.size(),
		"package_ids": get_package_ids(),
		"ordered_package_ids": get_ordered_package_ids(),
		"duplicate_package_ids": _duplicate_package_ids.duplicate(),
		"rejected_manifest_count": _rejected_manifest_inputs.size(),
	}


# --- 私有/辅助方法 ---

## 从目录字典取出并类型检查 manifest；不存在或值类型不符时返回 null。
## [br]
## @api private
func _get_manifest_ref(package_id: StringName) -> GFContentPackageManifest:
	var manifest_value: Variant = _manifests.get(package_id)
	if manifest_value is GFContentPackageManifest:
		var manifest: GFContentPackageManifest = manifest_value
		return manifest
	return null


## 拒绝 null、空 ID 和重复输入；成功时把 manifest 副本按输入顺序存入目录。
## [br]
## @api private
func _add_manifest_input(manifest: GFContentPackageManifest, input_index: int) -> bool:
	if manifest == null:
		_rejected_manifest_inputs.append({
			"input_index": input_index,
			"reason": "null_manifest",
			"source_path": "",
		})
		return false
	if manifest.package_id == &"":
		_rejected_manifest_inputs.append({
			"input_index": input_index,
			"reason": "missing_package_id",
			"source_path": manifest.source_path,
			"manifest": manifest.duplicate_manifest(),
		})
		return false
	if _manifests.has(manifest.package_id):
		_add_duplicate_package_id(manifest.package_id)
		return false

	_manifests[manifest.package_id] = manifest.duplicate_manifest()
	_manifest_order.append(manifest.package_id)
	return true


## 生成被拒输入的轻量摘要，不包含其中可能保存的 manifest 对象。
## [br]
## @api private
func _get_rejected_manifest_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for record: Dictionary in _rejected_manifest_inputs:
		result.append({
			"input_index": GFVariantData.get_option_int(record, "input_index", -1),
			"reason": GFVariantData.get_option_string(record, "reason", _KIND_INVALID_MANIFEST),
			"source_path": GFVariantData.get_option_string(record, "source_path"),
		})
	return result


## 从直接命中 ID 遍历现存依赖，再按已排序 ID 顺序输出闭包成员。
## [br]
## @api private
func _expand_dependency_closure(
	direct_package_ids: PackedStringArray,
	ordered_package_ids: PackedStringArray
) -> PackedStringArray:
	var included_ids: Dictionary = {}
	var pending_ids: PackedStringArray = direct_package_ids.duplicate()
	while not pending_ids.is_empty():
		var package_id_text: String = pending_ids[pending_ids.size() - 1]
		pending_ids.remove_at(pending_ids.size() - 1)
		if included_ids.has(package_id_text):
			continue
		included_ids[package_id_text] = true
		var manifest: GFContentPackageManifest = _get_manifest_ref(StringName(package_id_text))
		if manifest == null:
			continue
		for dependency_id_text: String in manifest.dependencies:
			if _manifests.has(StringName(dependency_id_text)) and not included_ids.has(dependency_id_text):
				var _pending_id_appended: bool = pending_ids.append(dependency_id_text)
	var result: PackedStringArray = PackedStringArray()
	for package_id_text: String in ordered_package_ids:
		if included_ids.has(package_id_text):
			var _result_id_appended: bool = result.append(package_id_text)
	return result


## 构造失败状态的查询结果，报告指定问题并提供空 ID 和 manifest 列表。
## [br]
## @api private
func _make_query_failure(
	status: StringName,
	query_id: StringName,
	kind: StringName,
	message: String
) -> GFContentPackageQueryResult:
	var report: Dictionary = _make_report("Content package query")
	var _issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		"error",
		kind,
		message
	)
	report["query_id"] = query_id
	report["status"] = status
	report["direct_package_ids"] = PackedStringArray()
	report["package_ids"] = PackedStringArray()
	report = _finalize_report(report, "Content package query")
	return GFContentPackageQueryResult.new().configure_result(
		false,
		status,
		query_id,
		PackedStringArray(),
		PackedStringArray(),
		[],
		report
	)

## 将重复 package_id 以字符串形式加入诊断列表，列表中只保留一项。
## [br]
## @api private
func _add_duplicate_package_id(package_id: StringName) -> void:
	var package_id_text: String = String(package_id)
	if not _duplicate_package_ids.has(package_id_text):
		var _append_result: bool = _duplicate_package_ids.append(package_id_text)


## 从重复 ID 诊断列表中移除指定 package_id 的所有匹配项。
## [br]
## @api private
func _remove_duplicate_package_id(package_id: StringName) -> void:
	var package_id_text: String = String(package_id)
	var index: int = _duplicate_package_ids.find(package_id_text)
	while index >= 0:
		_duplicate_package_ids.remove_at(index)
		index = _duplicate_package_ids.find(package_id_text)


## 为重复 package_id 列表中的每个 ID 追加目录级错误。
## [br]
## @api private
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


## 按注册顺序校验目录中接纳的 manifest 并合并其问题。
## [br]
## @api private
func _add_manifest_issues(
	report: Dictionary,
	options: Dictionary
) -> void:
	for package_id: StringName in _manifest_order:
		var manifest: GFContentPackageManifest = _get_manifest_ref(package_id)
		if manifest == null:
			continue
		_append_manifest_validation_issues(report, manifest, package_id, options)


## 汇总被拒输入；有 manifest 快照时复用其校验结果，否则报告缺失 manifest。
## [br]
## @api private
func _add_rejected_manifest_issues(report: Dictionary, options: Dictionary) -> void:
	for record: Dictionary in _rejected_manifest_inputs:
		var input_index: int = GFVariantData.get_option_int(record, "input_index", -1)
		var manifest_value: Variant = record.get("manifest")
		if manifest_value is GFContentPackageManifest:
			var manifest: GFContentPackageManifest = manifest_value
			_append_manifest_validation_issues(report, manifest, manifest.package_id, options, input_index)
			continue
		var _issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			StringName(_KIND_INVALID_MANIFEST),
			"content package manifest is required",
			{
				"row_index": input_index,
				"field": &"manifest",
				"path": "packages[%d]" % input_index if input_index >= 0 else "packages",
				"actual_value": "null",
				"expected_value": "GFContentPackageManifest",
			}
		)


## 将单份 manifest 的问题合并到目录报告，并补充包 ID 和有效行索引。
## [br]
## @api private
func _append_manifest_validation_issues(
	report: Dictionary,
	manifest: GFContentPackageManifest,
	package_id: StringName,
	options: Dictionary,
	input_index: int = -1
) -> void:
	var manifest_report: Dictionary = manifest.get_validation_report(options)
	for issue_variant: Variant in GFVariantData.get_option_array(manifest_report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)
		var issue_row_index: int = GFVariantData.get_option_int(issue, "row_index", -1)
		if issue_row_index < 0:
			issue_row_index = input_index
		var issue_fields: Dictionary = {
			"key": package_id,
			"source_path": GFVariantData.get_option_string(issue, "source_path", manifest.source_path),
			"source": GFVariantData.get_option_string(issue, "source", manifest.source_path),
			"row_key": GFVariantData.get_option_value(issue, "row_key", package_id),
			"row_index": issue_row_index,
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


## 追加缺失依赖问题以及依赖排序报告中的循环依赖问题。
## [br]
## @api private
func _add_dependency_issues(report: Dictionary, dependency_sort_report: Dictionary) -> void:
	for package_id: StringName in _manifest_order:
		var manifest: GFContentPackageManifest = _get_manifest_ref(package_id)
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

	for cycle_variant: Variant in GFVariantData.get_option_array(dependency_sort_report, "dependency_cycles"):
		if not cycle_variant is PackedStringArray:
			continue
		var cycle: PackedStringArray = cycle_variant
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

## 按注册顺序建立只包含目录内依赖项的字符串 ID 邻接表。
## [br]
## @api private
func _build_dependency_map() -> Dictionary:
	var result: Dictionary = {}
	for package_id: StringName in _manifest_order:
		var manifest: GFContentPackageManifest = _get_manifest_ref(package_id)
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


## 把注册顺序和依赖邻接表交给图工具生成排序与循环诊断。
## [br]
## @api private
func _get_dependency_sort_report() -> Dictionary:
	return _GF_DEPENDENCY_GRAPH_TOOLS.sort_dependency_first(
		_get_manifest_order_as_strings(),
		_build_dependency_map()
	)


## 将注册顺序中的 StringName ID 转为 PackedStringArray。
## [br]
## @api private
func _get_manifest_order_as_strings() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for package_id: StringName in _manifest_order:
		var _package_appended: bool = result.append(String(package_id))
	return result


## 创建指定主题且 issues 初始为空的目录报告。
## [br]
## @api private
func _make_report(subject: String = _REPORT_SUBJECT) -> Dictionary:
	return {
		"subject": subject,
		"issues": [],
	}


## 使用目录专属的无问题与需复核行动文本完成报告。
## [br]
## @api private
func _finalize_report(report: Dictionary, subject: String = _REPORT_SUBJECT) -> Dictionary:
	return GFValidationReportDictionary.finalize_report(report, subject, {
		"fallback_action": "Review the first content package catalog issue.",
		"no_action": "Content package catalog is valid.",
	})
