## GFAssetCatalogRuntime: owner-scoped 资产目录快照挂载与原子合并服务。
##
## Runtime 只接收已经构建的目录快照或 Provider 输出，按稳定优先级合并并以 revision 发布。
## 任何无效请求、Provider 失败或严格冲突都不会替换上一份已提交目录。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 10.0.0
class_name GFAssetCatalogRuntime
extends GFUtility


# --- 信号 ---

## 资产目录成功提交新 revision 后发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param catalog: 已提交目录的隔离快照。
## [br]
## @param revision: 新 revision。
signal catalog_changed(catalog: GFAssetCatalog, revision: int)


# --- 常量 ---

## 任一重复 asset ID 都拒绝整次事务。
## [br]
## @api public
## [br]
## @since 10.0.0
const CONFLICT_REJECT: StringName = &"reject"

## 重复 asset ID 显式保留高优先级 Mount 的条目。
## [br]
## @api public
## [br]
## @since 10.0.0
const CONFLICT_KEEP_HIGH_PRIORITY: StringName = &"keep_high_priority"


# --- 私有变量 ---

var _conflict_policy: StringName = CONFLICT_REJECT
var _mount_records: Array[Dictionary] = []
var _catalog: GFAssetCatalog = GFAssetCatalog.new()
var _revision: int = 0
var _next_token: int = 1
var _last_report: Dictionary = {}
var _disposed: bool = false


# --- GF 生命周期方法 ---

## 初始化空目录和 Mount 状态，同时保留 configure() 选择的冲突政策。
## [br]
## @api framework_internal
func init() -> void:
	_complete_all_mounts(GFAssetCatalogMount.STATUS_DISPOSED, _revision)
	_mount_records.clear()
	_catalog = GFAssetCatalog.new()
	_revision = 0
	_next_token = 1
	_last_report = {}
	_disposed = false


## 释放全部 Mount 并使外部句柄进入 disposed 终态。
## [br]
## @api framework_internal
func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	_complete_all_mounts(GFAssetCatalogMount.STATUS_DISPOSED, _revision)
	_mount_records.clear()
	_catalog = GFAssetCatalog.new()
	_last_report = _make_runtime_report(true, &"disposed", [])


# --- 公共方法 ---

## 配置全局 asset ID 冲突政策。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param conflict_policy: CONFLICT_REJECT 或 CONFLICT_KEEP_HIGH_PRIORITY。
## [br]
## @return 当前 Runtime；已有 Mount 或政策无效时保持原配置。
func configure(conflict_policy: StringName = CONFLICT_REJECT) -> GFAssetCatalogRuntime:
	if not _mount_records.is_empty():
		return self
	if conflict_policy == CONFLICT_REJECT or conflict_policy == CONFLICT_KEEP_HIGH_PRIORITY:
		_conflict_policy = conflict_policy
	return self


## 原子挂载一个资产目录快照。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param owner_id: 非空 owner ID。
## [br]
## @param mount_id: owner scope 内非空稳定 ID。
## [br]
## @param catalog: 要挂载的目录；Runtime 保存深拷贝。
## [br]
## @param priority: 合并优先级，数值越大越先处理。
## [br]
## @param source_id: 可选来源 ID；为空时使用 mount_id。
## [br]
## @return 活动 Mount 或带稳定失败状态的非活动 Mount。
func mount_catalog(
	owner_id: StringName,
	mount_id: StringName,
	catalog: GFAssetCatalog,
	priority: int = 0,
	source_id: StringName = &""
) -> GFAssetCatalogMount:
	var effective_source_id: StringName = source_id if source_id != &"" else mount_id
	if _disposed:
		return _make_failed_mount(
			GFAssetCatalogMount.STATUS_DISPOSED,
			owner_id,
			mount_id,
			effective_source_id,
			priority,
			&"runtime_disposed",
			"asset catalog runtime is disposed"
		)
	if owner_id == &"" or mount_id == &"" or catalog == null:
		return _make_failed_mount(
			GFAssetCatalogMount.STATUS_INVALID_REQUEST,
			owner_id,
			mount_id,
			effective_source_id,
			priority,
			&"invalid_mount_request",
			"owner_id, mount_id, and catalog are required"
		)
	if _find_mount_record_index(owner_id, mount_id) >= 0:
		return _make_failed_mount(
			GFAssetCatalogMount.STATUS_DUPLICATE_MOUNT,
			owner_id,
			mount_id,
			effective_source_id,
			priority,
			&"duplicate_mount",
			"owner already has this mount_id"
		)

	var token: int = _next_token
	var catalog_snapshot: GFAssetCatalog = _duplicate_catalog(catalog)
	var candidate_records: Array[Dictionary] = _copy_mount_records(_mount_records)
	candidate_records.append({
		"token": token,
		"owner_id": owner_id,
		"mount_id": mount_id,
		"source_id": effective_source_id,
		"priority": priority,
		"catalog": catalog_snapshot,
		"handle": null,
	})
	var composition: Dictionary = _compose_mount_records(candidate_records)
	if not GFVariantData.get_option_bool(composition, "ok", false):
		var failure_status: StringName = (
			GFAssetCatalogMount.STATUS_CONFLICT
			if GFVariantData.get_option_bool(composition, "has_conflicts", false)
			else GFAssetCatalogMount.STATUS_BUILD_FAILED
		)
		var failure_report: Dictionary = GFVariantData.get_option_dictionary(composition, "report")
		_last_report = failure_report.duplicate(true)
		return GFAssetCatalogMount.new().configure_failure(
			failure_status,
			owner_id,
			mount_id,
			effective_source_id,
			priority,
			failure_report
		)

	_next_token += 1
	var committed_catalog: GFAssetCatalog = _get_composed_catalog(composition)
	_revision += 1
	var report: Dictionary = GFVariantData.get_option_dictionary(composition, "report")
	var mount: GFAssetCatalogMount = GFAssetCatalogMount.new().configure_active(
		self,
		token,
		owner_id,
		mount_id,
		effective_source_id,
		priority,
		_revision,
		catalog_snapshot,
		report
	)
	candidate_records[candidate_records.size() - 1]["handle"] = mount
	_commit_composition(candidate_records, committed_catalog, report)
	return mount


## 构建 Provider 快照并原子挂载。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param owner_id: 非空 owner ID。
## [br]
## @param mount_id: owner scope 内稳定 ID。
## [br]
## @param provider: 资产目录来源 Provider。
## [br]
## @param options: 传给 Provider 的构建选项。
## [br]
## @schema options: Dictionary with provider-defined build options.
## [br]
## @return 活动 Mount 或带构建失败状态的非活动 Mount。
func mount_provider(
	owner_id: StringName,
	mount_id: StringName,
	provider: GFAssetCatalogSourceProvider,
	options: Dictionary = {}
) -> GFAssetCatalogMount:
	if provider == null:
		return _make_failed_mount(
			GFAssetCatalogMount.STATUS_INVALID_REQUEST,
			owner_id,
			mount_id,
			&"",
			0,
			&"missing_provider",
			"asset catalog provider is required"
		)
	if _disposed:
		return _make_failed_mount(
			GFAssetCatalogMount.STATUS_DISPOSED,
			owner_id,
			mount_id,
			provider.get_source_id(),
			provider.get_priority(),
			&"runtime_disposed",
			"asset catalog runtime is disposed"
		)
	if owner_id == &"" or mount_id == &"":
		return _make_failed_mount(
			GFAssetCatalogMount.STATUS_INVALID_REQUEST,
			owner_id,
			mount_id,
			provider.get_source_id(),
			provider.get_priority(),
			&"invalid_mount_request",
			"owner_id and mount_id are required"
		)
	if _find_mount_record_index(owner_id, mount_id) >= 0:
		return _make_failed_mount(
			GFAssetCatalogMount.STATUS_DUPLICATE_MOUNT,
			owner_id,
			mount_id,
			provider.get_source_id(),
			provider.get_priority(),
			&"duplicate_mount",
			"owner already has this mount_id"
		)
	var source_catalog: GFAssetCatalog = provider.build_catalog(options)
	if source_catalog == null:
		return _make_failed_mount(
			GFAssetCatalogMount.STATUS_BUILD_FAILED,
			owner_id,
			mount_id,
			provider.get_source_id(),
			provider.get_priority(),
			&"provider_build_failed",
			"asset catalog provider returned no catalog"
		)
	return mount_catalog(
		owner_id,
		mount_id,
		source_catalog,
		provider.get_priority(),
		provider.get_source_id()
	)


## 原子替换一个活动 Mount 的目录快照。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param mount: 当前 Runtime 返回的活动 Mount。
## [br]
## @param catalog: 新目录快照。
## [br]
## @return 完整候选成功提交返回 true；失败时保留原 Mount、目录和 revision。
func replace_mount_catalog(mount: GFAssetCatalogMount, catalog: GFAssetCatalog) -> bool:
	if _disposed or mount == null or not mount.is_active() or catalog == null:
		return false
	var record_index: int = _find_mount_record_index_by_handle(mount)
	if record_index < 0:
		return false
	var catalog_snapshot: GFAssetCatalog = _duplicate_catalog(catalog)
	var candidate_records: Array[Dictionary] = _copy_mount_records(_mount_records)
	candidate_records[record_index]["catalog"] = catalog_snapshot
	var composition: Dictionary = _compose_mount_records(candidate_records)
	var report: Dictionary = GFVariantData.get_option_dictionary(composition, "report")
	if not GFVariantData.get_option_bool(composition, "ok", false):
		_last_report = report.duplicate(true)
		return false
	_revision += 1
	mount.refresh_catalog(catalog_snapshot, _revision, report)
	_commit_composition(candidate_records, _get_composed_catalog(composition), report)
	return true


## 批量释放一个 owner 的全部 Mount，并只提交一个新 revision。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param owner_id: 要释放的 owner ID。
## [br]
## @return 释放的 Mount 数量。
func unmount_owner(owner_id: StringName) -> int:
	if _disposed or owner_id == &"":
		return 0
	var candidate_records: Array[Dictionary] = []
	var removed_records: Array[Dictionary] = []
	for mount_record: Dictionary in _mount_records:
		if GFVariantData.get_option_string_name(mount_record, "owner_id") == owner_id:
			removed_records.append(mount_record)
		else:
			candidate_records.append(_copy_mount_record(mount_record))
	if removed_records.is_empty():
		return 0
	var composition: Dictionary = _compose_mount_records(candidate_records)
	if not GFVariantData.get_option_bool(composition, "ok", false):
		return 0
	_revision += 1
	for removed_record: Dictionary in removed_records:
		var mount: GFAssetCatalogMount = _get_mount_handle(removed_record)
		if mount != null:
			mount.complete(GFAssetCatalogMount.STATUS_UNMOUNTED, _revision)
	_commit_composition(
		candidate_records,
		_get_composed_catalog(composition),
		GFVariantData.get_option_dictionary(composition, "report")
	)
	return removed_records.size()


## 获取当前已提交资产目录快照。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 深拷贝目录。
func get_catalog() -> GFAssetCatalog:
	return _duplicate_catalog(_catalog)


## 获取当前目录 revision。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 从 0 开始、仅成功提交时递增的 revision。
func get_revision() -> int:
	return _revision


## 获取全部活动 Mount。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 按合并顺序排列的 Mount 句柄。
func get_mounts() -> Array[GFAssetCatalogMount]:
	var result: Array[GFAssetCatalogMount] = []
	var ordered_records: Array[Dictionary] = _copy_mount_records(_mount_records)
	ordered_records.sort_custom(_compare_mount_records)
	for mount_record: Dictionary in ordered_records:
		var mount: GFAssetCatalogMount = _get_mount_handle(mount_record)
		if mount != null and mount.is_active():
			result.append(mount)
	return result


## 获取最近一次运行时报告。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return GFValidationReport 兼容字典副本。
## [br]
## @schema return: GFValidationReport-compatible Dictionary with conflict_policy, revision, mount_count, asset_count, and issues.
func get_last_report() -> Dictionary:
	return _last_report.duplicate(true)


## 获取 JSON-safe 调试快照。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return Runtime、Mount 和目录摘要。
## [br]
## @schema return: Dictionary with conflict_policy, disposed, revision, mount_count, mounts, catalog, and last_report.
func get_debug_snapshot() -> Dictionary:
	var mount_records: Array[Dictionary] = []
	for mount: GFAssetCatalogMount in get_mounts():
		mount_records.append(mount.to_dict())
	return {
		"conflict_policy": String(_conflict_policy),
		"disposed": _disposed,
		"revision": _revision,
		"mount_count": mount_records.size(),
		"mounts": mount_records,
		"catalog": _catalog.get_debug_snapshot(),
		"last_report": GFReportValueCodec.to_report_dictionary(_last_report),
	}


# --- 框架内部方法 ---

## 按内部 token 释放一个 Mount。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param token: GFAssetCatalogMount 持有的 Runtime token。
## [br]
## @return 本次调用完成释放返回 true。
func release_mount(token: int) -> bool:
	if _disposed or token <= 0:
		return false
	var record_index: int = _find_mount_record_index_by_token(token)
	if record_index < 0:
		return false
	var removed_record: Dictionary = _mount_records[record_index]
	var candidate_records: Array[Dictionary] = _copy_mount_records(_mount_records)
	candidate_records.remove_at(record_index)
	var composition: Dictionary = _compose_mount_records(candidate_records)
	if not GFVariantData.get_option_bool(composition, "ok", false):
		return false
	_revision += 1
	var mount: GFAssetCatalogMount = _get_mount_handle(removed_record)
	if mount != null:
		mount.complete(GFAssetCatalogMount.STATUS_UNMOUNTED, _revision)
	_commit_composition(
		candidate_records,
		_get_composed_catalog(composition),
		GFVariantData.get_option_dictionary(composition, "report")
	)
	return true


# --- 私有/辅助方法 ---

func _compose_mount_records(records: Array[Dictionary]) -> Dictionary:
	var ordered_records: Array[Dictionary] = _copy_mount_records(records)
	ordered_records.sort_custom(_compare_mount_records)
	var result_catalog: GFAssetCatalog = GFAssetCatalog.new()
	var issues: Array[Dictionary] = []
	var has_conflicts: bool = false
	for mount_record: Dictionary in ordered_records:
		var source_catalog: GFAssetCatalog = _get_mount_catalog(mount_record)
		if source_catalog == null:
			issues.append({
				"severity": "error",
				"kind": "missing_mount_catalog",
				"owner_id": String(GFVariantData.get_option_string_name(mount_record, "owner_id")),
				"mount_id": String(GFVariantData.get_option_string_name(mount_record, "mount_id")),
			})
			continue
		for asset_id_text: String in source_catalog.get_all_ids():
			var asset_id: StringName = StringName(asset_id_text)
			if result_catalog.has_entry(asset_id):
				has_conflicts = true
				issues.append({
					"severity": "error" if _conflict_policy == CONFLICT_REJECT else "warning",
					"kind": "duplicate_asset_id",
					"asset_id": asset_id_text,
					"owner_id": String(GFVariantData.get_option_string_name(mount_record, "owner_id")),
					"mount_id": String(GFVariantData.get_option_string_name(mount_record, "mount_id")),
				})
				continue
			var entry: GFAssetCatalogEntry = source_catalog.get_entry(asset_id)
			if entry == null or not result_catalog.set_entry(entry):
				issues.append({
					"severity": "error",
					"kind": "invalid_asset_entry",
					"asset_id": asset_id_text,
				})
	var ok: bool = _issues_have_no_errors(issues)
	return {
		"ok": ok,
		"has_conflicts": has_conflicts,
		"catalog": result_catalog,
		"report": _make_runtime_report(ok, &"composed", issues, records.size(), result_catalog.get_all_ids().size()),
	}


func _commit_composition(
	records: Array[Dictionary],
	committed_catalog: GFAssetCatalog,
	report: Dictionary
) -> void:
	_mount_records = _copy_mount_records(records)
	_catalog = _duplicate_catalog(committed_catalog)
	_last_report = report.duplicate(true)
	_last_report["revision"] = _revision
	_last_report["mount_count"] = _mount_records.size()
	_last_report["asset_count"] = _catalog.get_all_ids().size()
	catalog_changed.emit(_duplicate_catalog(_catalog), _revision)


func _make_failed_mount(
	status: StringName,
	owner_id: StringName,
	mount_id: StringName,
	source_id: StringName,
	priority: int,
	kind: StringName,
	message: String
) -> GFAssetCatalogMount:
	var issue: Dictionary = {
		"severity": "error",
		"kind": String(kind),
		"message": message,
		"owner_id": String(owner_id),
		"mount_id": String(mount_id),
		"source_id": String(source_id),
	}
	var report: Dictionary = _make_runtime_report(false, status, [issue])
	_last_report = report.duplicate(true)
	return GFAssetCatalogMount.new().configure_failure(
		status,
		owner_id,
		mount_id,
		source_id,
		priority,
		report
	)


func _make_runtime_report(
	ok: bool,
	status: StringName,
	issues: Array[Dictionary],
	mount_count: int = -1,
	asset_count: int = -1
) -> Dictionary:
	var error_count: int = 0
	var warning_count: int = 0
	for issue: Dictionary in issues:
		var severity: String = GFVariantData.get_option_string(issue, "severity")
		if severity == "error":
			error_count += 1
		elif severity == "warning":
			warning_count += 1
	return {
		"ok": ok,
		"healthy": ok and warning_count == 0,
		"subject": "Asset catalog runtime",
		"status": String(status),
		"conflict_policy": String(_conflict_policy),
		"revision": _revision,
		"mount_count": _mount_records.size() if mount_count < 0 else mount_count,
		"asset_count": _catalog.get_all_ids().size() if asset_count < 0 else asset_count,
		"issues": issues.duplicate(true),
		"error_count": error_count,
		"warning_count": warning_count,
		"issue_count": issues.size(),
	}


func _find_mount_record_index(owner_id: StringName, mount_id: StringName) -> int:
	for index: int in range(_mount_records.size()):
		var mount_record: Dictionary = _mount_records[index]
		if (
			GFVariantData.get_option_string_name(mount_record, "owner_id") == owner_id
			and GFVariantData.get_option_string_name(mount_record, "mount_id") == mount_id
		):
			return index
	return -1


func _find_mount_record_index_by_token(token: int) -> int:
	for index: int in range(_mount_records.size()):
		if GFVariantData.get_option_int(_mount_records[index], "token") == token:
			return index
	return -1


func _find_mount_record_index_by_handle(mount: GFAssetCatalogMount) -> int:
	for index: int in range(_mount_records.size()):
		if _get_mount_handle(_mount_records[index]) == mount:
			return index
	return -1


func _copy_mount_records(records: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mount_record: Dictionary in records:
		result.append(_copy_mount_record(mount_record))
	return result


func _copy_mount_record(mount_record: Dictionary) -> Dictionary:
	return {
		"token": GFVariantData.get_option_int(mount_record, "token"),
		"owner_id": GFVariantData.get_option_string_name(mount_record, "owner_id"),
		"mount_id": GFVariantData.get_option_string_name(mount_record, "mount_id"),
		"source_id": GFVariantData.get_option_string_name(mount_record, "source_id"),
		"priority": GFVariantData.get_option_int(mount_record, "priority"),
		"catalog": _get_mount_catalog(mount_record),
		"handle": GFVariantData.get_option_value(mount_record, "handle"),
	}


func _get_mount_catalog(mount_record: Dictionary) -> GFAssetCatalog:
	var catalog_value: Variant = mount_record.get("catalog")
	if catalog_value is GFAssetCatalog:
		var source_catalog: GFAssetCatalog = catalog_value
		return source_catalog
	return null


func _get_mount_handle(mount_record: Dictionary) -> GFAssetCatalogMount:
	var handle_value: Variant = mount_record.get("handle")
	if handle_value is GFAssetCatalogMount:
		var mount: GFAssetCatalogMount = handle_value
		return mount
	return null


func _complete_all_mounts(status: StringName, revision: int) -> void:
	for mount_record: Dictionary in _mount_records:
		var mount: GFAssetCatalogMount = _get_mount_handle(mount_record)
		if mount != null:
			mount.complete(status, revision)


func _get_composed_catalog(composition: Dictionary) -> GFAssetCatalog:
	var catalog_value: Variant = composition.get("catalog")
	if catalog_value is GFAssetCatalog:
		var composed_catalog: GFAssetCatalog = catalog_value
		return composed_catalog
	return GFAssetCatalog.new()


static func _duplicate_catalog(catalog: GFAssetCatalog) -> GFAssetCatalog:
	return GFAssetCatalog.from_dict(catalog.to_dict()) if catalog != null else GFAssetCatalog.new()


static func _compare_mount_records(left: Dictionary, right: Dictionary) -> bool:
	var left_priority: int = GFVariantData.get_option_int(left, "priority")
	var right_priority: int = GFVariantData.get_option_int(right, "priority")
	if left_priority != right_priority:
		return left_priority > right_priority
	var left_owner: String = GFVariantData.get_option_string(left, "owner_id")
	var right_owner: String = GFVariantData.get_option_string(right, "owner_id")
	if left_owner != right_owner:
		return left_owner < right_owner
	var left_mount: String = GFVariantData.get_option_string(left, "mount_id")
	var right_mount: String = GFVariantData.get_option_string(right, "mount_id")
	if left_mount != right_mount:
		return left_mount < right_mount
	return GFVariantData.get_option_int(left, "token") < GFVariantData.get_option_int(right, "token")


static func _issues_have_no_errors(issues: Array[Dictionary]) -> bool:
	for issue: Dictionary in issues:
		if GFVariantData.get_option_string(issue, "severity") == "error":
			return false
	return true
