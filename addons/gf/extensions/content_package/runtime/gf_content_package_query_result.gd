## GFContentPackageQueryResult: 内容包查询的不可变结果快照。
##
## 结果区分直接命中与依赖闭包，并保留隔离的 manifest 和验证报告，
## 调用方不需要从空数组推断查询失败或无匹配。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 10.0.0
class_name GFContentPackageQueryResult
extends RefCounted


# --- 常量 ---

## 查询成功完成。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_COMPLETED: StringName = &"completed"

## 查询对象为空或无效。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_INVALID_QUERY: StringName = &"invalid_query"

## 内容包目录依赖图或 manifest 无效。
## [br]
## @api public
## [br]
## @since 10.0.0
const STATUS_INVALID_CATALOG: StringName = &"invalid_catalog"


# --- 私有变量 ---

var _successful: bool = false
var _status: StringName = STATUS_INVALID_QUERY
var _query_id: StringName = &""
var _direct_package_ids: PackedStringArray = PackedStringArray()
var _package_ids: PackedStringArray = PackedStringArray()
var _manifests: Dictionary = {}
var _report: Dictionary = {}


# --- 公共方法 ---

## 检查查询是否成功完成。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 查询成功返回 true；零匹配仍属于成功。
func is_successful() -> bool:
	return _successful


## 获取稳定终态状态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 获取查询 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 查询稳定 ID。
func get_query_id() -> StringName:
	return _query_id


## 获取不含自动依赖扩展的直接命中 package ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return dependency-first 排序的 ID 副本。
func get_direct_package_ids() -> PackedStringArray:
	return _direct_package_ids.duplicate()


## 获取最终 package ID，包括请求的依赖闭包。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return dependency-first 排序的 ID 副本。
func get_package_ids() -> PackedStringArray:
	return _package_ids.duplicate()


## 获取一个命中 manifest 的隔离副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param package_id: 内容包 ID。
## [br]
## @return manifest 深拷贝；未命中返回 null。
func get_manifest(package_id: StringName) -> GFContentPackageManifest:
	var manifest: GFContentPackageManifest = _get_manifest_ref(package_id)
	return manifest.duplicate_manifest() if manifest != null else null


## 获取全部命中 manifest 的隔离副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 与 get_package_ids() 同序的 manifest 数组。
func get_manifests() -> Array[GFContentPackageManifest]:
	var result: Array[GFContentPackageManifest] = []
	for package_id_text: String in _package_ids:
		var manifest: GFContentPackageManifest = _get_manifest_ref(StringName(package_id_text))
		if manifest != null:
			result.append(manifest.duplicate_manifest())
	return result


## 获取验证报告副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return GFValidationReportDictionary 兼容字典。
## [br]
## @schema return: GFValidationReportDictionary-compatible Dictionary with query_id, status, direct_package_ids, and package_ids.
func get_report() -> Dictionary:
	return _report.duplicate(true)


## 转换为 JSON-safe 结果摘要。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 不包含 Resource 对象的结果字典。
## [br]
## @schema return: Dictionary with successful, status, query_id, direct_package_ids, package_ids, manifests, and report.
func to_dict() -> Dictionary:
	var manifest_records: Array[Dictionary] = []
	for manifest: GFContentPackageManifest in get_manifests():
		manifest_records.append(manifest.to_report_dictionary())
	return {
		"successful": _successful,
		"status": String(_status),
		"query_id": String(_query_id),
		"direct_package_ids": _direct_package_ids.duplicate(),
		"package_ids": _package_ids.duplicate(),
		"manifests": manifest_records,
		"report": GFReportValueCodec.to_report_dictionary(_report),
	}


# --- 框架内部方法 ---

## 写入查询终态快照。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param successful: 查询是否成功。
## [br]
## @param status: 稳定终态状态。
## [br]
## @param query_id: 查询 ID。
## [br]
## @param direct_package_ids: 直接命中 ID。
## [br]
## @param package_ids: 最终命中 ID。
## [br]
## @param manifests: 与最终命中 ID 对应的 manifest 快照。
## [br]
## @param report: 验证报告。
## [br]
## @return 当前结果。
## [br]
## @schema report: GFValidationReportDictionary-compatible Dictionary.
func configure_result(
	successful: bool,
	status: StringName,
	query_id: StringName,
	direct_package_ids: PackedStringArray,
	package_ids: PackedStringArray,
	manifests: Array[GFContentPackageManifest],
	report: Dictionary
) -> GFContentPackageQueryResult:
	_successful = successful
	_status = status
	_query_id = query_id
	_direct_package_ids = direct_package_ids.duplicate()
	_package_ids = package_ids.duplicate()
	_manifests.clear()
	for manifest: GFContentPackageManifest in manifests:
		if manifest == null or manifest.package_id == &"":
			continue
		_manifests[manifest.package_id] = manifest.duplicate_manifest()
	_report = report.duplicate(true)
	return self


# --- 私有/辅助方法 ---

func _get_manifest_ref(package_id: StringName) -> GFContentPackageManifest:
	var manifest_value: Variant = _manifests.get(package_id)
	if manifest_value is GFContentPackageManifest:
		var manifest: GFContentPackageManifest = manifest_value
		return manifest
	return null
