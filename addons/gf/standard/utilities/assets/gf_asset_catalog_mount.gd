## GFAssetCatalogMount: 资产目录运行时挂载的生命周期句柄。
##
## 句柄保存提交时的目录快照、owner、mount ID、来源和 revision，
## 并提供幂等显式卸载入口。失败请求也返回带稳定状态与报告的非活动句柄。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFAssetCatalogMount
extends RefCounted


# --- 常量 ---

## Mount 已提交且仍活动。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_ACTIVE: StringName = &"active"

## Mount 已由调用方或 owner scope 释放。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_UNMOUNTED: StringName = &"unmounted"

## Mount 与已提交资产 ID 冲突。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_CONFLICT: StringName = &"conflict"

## Provider 未能构建目录。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_BUILD_FAILED: StringName = &"build_failed"

## 同一 owner 已存在相同 mount ID。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_DUPLICATE_MOUNT: StringName = &"duplicate_mount"

## Mount 请求缺少 owner、mount ID 或有效目录。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"

## 所属 Runtime 已释放。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_DISPOSED: StringName = &"disposed"


# --- 私有变量 ---

var _runtime_ref: WeakRef = null
var _token: int = 0
var _owner_id: StringName = &""
var _mount_id: StringName = &""
var _source_id: StringName = &""
var _priority: int = 0
var _revision: int = 0
var _status: StringName = STATUS_INVALID_REQUEST
var _active: bool = false
var _catalog: GFAssetCatalog = GFAssetCatalog.new()
var _report: Dictionary = {}


# --- 公共方法 ---

## 检查 Mount 是否仍在 Runtime 中活动。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 活动返回 true。
func is_active() -> bool:
	return _active


## 获取稳定终态状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 获取 owner ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Mount owner ID。
func get_owner_id() -> StringName:
	return _owner_id


## 获取 owner scope 内稳定 mount ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Mount ID。
func get_mount_id() -> StringName:
	return _mount_id


## 获取来源 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Provider 来源 ID；直接目录 Mount 默认等于 mount ID。
func get_source_id() -> StringName:
	return _source_id


## 获取 Mount 优先级。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 合并优先级。
func get_priority() -> int:
	return _priority


## 获取最近一次提交该 Mount 的 Runtime revision。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非负 revision。
func get_revision() -> int:
	return _revision


## 获取 Mount 自身的资产目录快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 深拷贝目录。
func get_catalog() -> GFAssetCatalog:
	return GFAssetCatalog.from_dict(_catalog.to_dict())


## 获取 Mount 请求或提交报告。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return GFValidationReport 兼容字典副本。
## [br]
## @schema return: GFValidationReport-compatible Dictionary with status, owner_id, mount_id, source_id, priority, and revision.
func get_report() -> Dictionary:
	return _report.duplicate(true)


## 从所属 Runtime 卸载当前 Mount。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 本次调用完成卸载返回 true；已终态返回 false。
func unmount() -> bool:
	if not _active or _runtime_ref == null:
		return false
	var runtime_value: Variant = _runtime_ref.get_ref()
	if not (runtime_value is GFAssetCatalogRuntime):
		_active = false
		_status = STATUS_DISPOSED
		return false
	var runtime: GFAssetCatalogRuntime = runtime_value
	return runtime.release_mount(_token)


## 转换为 JSON-safe 诊断摘要。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Mount 摘要。
## [br]
## @schema return: Dictionary with active, status, owner_id, mount_id, source_id, priority, revision, token, asset_ids, and report.
func to_dict() -> Dictionary:
	return {
		"active": _active,
		"status": String(_status),
		"owner_id": String(_owner_id),
		"mount_id": String(_mount_id),
		"source_id": String(_source_id),
		"priority": _priority,
		"revision": _revision,
		"token": _token,
		"asset_ids": _catalog.get_all_ids(),
		"report": GFReportValueCodec.to_report_dictionary(_report),
	}


# --- 框架内部方法 ---

## 配置已提交 Mount。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param runtime: 所属 Runtime。
## [br]
## @param token: Runtime 内部 token。
## [br]
## @param owner_id: owner ID。
## [br]
## @param mount_id: mount ID。
## [br]
## @param source_id: 来源 ID。
## [br]
## @param priority: 合并优先级。
## [br]
## @param revision: 提交 revision。
## [br]
## @param catalog: Mount 目录快照。
## [br]
## @param report: 提交报告。
## [br]
## @return 当前 Mount。
## [br]
## @schema report: GFValidationReport-compatible Dictionary.
func configure_active(
	runtime: GFAssetCatalogRuntime,
	token: int,
	owner_id: StringName,
	mount_id: StringName,
	source_id: StringName,
	priority: int,
	revision: int,
	catalog: GFAssetCatalog,
	report: Dictionary
) -> GFAssetCatalogMount:
	_runtime_ref = weakref(runtime) if runtime != null else null
	_token = token
	_owner_id = owner_id
	_mount_id = mount_id
	_source_id = source_id
	_priority = priority
	_revision = revision
	_status = STATUS_ACTIVE
	_active = runtime != null
	_catalog = GFAssetCatalog.from_dict(catalog.to_dict()) if catalog != null else GFAssetCatalog.new()
	_report = report.duplicate(true)
	_report["status"] = String(STATUS_ACTIVE)
	_report["owner_id"] = String(owner_id)
	_report["mount_id"] = String(mount_id)
	_report["source_id"] = String(source_id)
	_report["priority"] = priority
	_report["revision"] = revision
	return self


## 配置未提交的失败 Mount。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param status: 失败状态。
## [br]
## @param owner_id: owner ID。
## [br]
## @param mount_id: mount ID。
## [br]
## @param source_id: 来源 ID。
## [br]
## @param priority: 请求优先级。
## [br]
## @param report: 失败报告。
## [br]
## @return 当前 Mount。
## [br]
## @schema report: GFValidationReport-compatible Dictionary.
func configure_failure(
	status: StringName,
	owner_id: StringName,
	mount_id: StringName,
	source_id: StringName,
	priority: int,
	report: Dictionary
) -> GFAssetCatalogMount:
	_runtime_ref = null
	_token = 0
	_owner_id = owner_id
	_mount_id = mount_id
	_source_id = source_id
	_priority = priority
	_revision = 0
	_status = status
	_active = false
	_catalog = GFAssetCatalog.new()
	_report = report.duplicate(true)
	_report["status"] = String(status)
	_report["owner_id"] = String(owner_id)
	_report["mount_id"] = String(mount_id)
	_report["source_id"] = String(source_id)
	_report["priority"] = priority
	_report["revision"] = 0
	return self


## 标记 Mount 离开 Runtime。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param status: unmounted 或 disposed。
## [br]
## @param revision: 终态 revision。
func complete(status: StringName, revision: int) -> void:
	_active = false
	_status = status
	_revision = revision
	_runtime_ref = null
	_report["status"] = String(status)
	_report["revision"] = revision


## 刷新已原子替换的 Mount 快照。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param catalog: 新目录快照。
## [br]
## @param revision: 提交 revision。
## [br]
## @param report: 提交报告。
## [br]
## @schema report: GFValidationReport-compatible Dictionary.
func refresh_catalog(catalog: GFAssetCatalog, revision: int, report: Dictionary) -> void:
	if not _active or catalog == null:
		return
	_catalog = GFAssetCatalog.from_dict(catalog.to_dict())
	_revision = revision
	_report = report.duplicate(true)
	_report["status"] = String(STATUS_ACTIVE)
	_report["owner_id"] = String(_owner_id)
	_report["mount_id"] = String(_mount_id)
	_report["source_id"] = String(_source_id)
	_report["priority"] = _priority
	_report["revision"] = revision
