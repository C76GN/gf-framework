## GFResourceBroker: framework-level threaded ResourceLoader admission broker。
##
## 一个显式共享实例可以注入 Asset、Scene 与 BackgroundWork Utility，
## 统一执行有界 FIFO admission、同资源身份复用、消费者级取消和底层请求 drain。
## Broker 不使用全局 singleton；架构模式应把它注册为 Utility，独立模式应显式
## 创建并传给每个消费者。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFResourceBroker
extends GFUtility


# --- 常量 ---

## 默认同时允许的底层 threaded resource request 数量。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_ACTIVE_REQUESTS: int = 4

## 同时活动的底层 threaded resource request 数量绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_ACTIVE_REQUESTS: int = 64

## 默认最多等待 admission 的不同资源请求数量。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_PENDING_REQUESTS: int = 256

## 等待 admission 的不同资源请求数量绝对上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_PENDING_REQUESTS: int = 4096

## 活动请求无法追溯收紧 type hint 时写入 Lease 的稳定失败原因。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_ACTIVE_TYPE_HINT_NOT_SATISFIED: String = "active_type_hint_not_satisfied"

## 活动请求无法追溯升级 admission 约束时写入 Lease 的稳定失败原因。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_ACTIVE_ADMISSION_CONSTRAINTS_NOT_SATISFIED: String = "active_admission_constraints_not_satisfied"

const _THREADED_RESOURCE_LOAD_ADAPTER = preload("res://addons/gf/standard/utilities/assets/gf_threaded_resource_load_adapter.gd")
const _RESOURCE_LEASE_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_lease.gd")
const _REQUEST_QUEUED: int = 0
const _REQUEST_ACTIVE: int = 1
const _REQUEST_DRAINING: int = 2


# --- 公共变量 ---

## 同时允许的底层 threaded resource request 数量。
## [br]
## @api public
## [br]
## @since unreleased
var max_active_requests: int = DEFAULT_MAX_ACTIVE_REQUESTS:
	set(value):
		max_active_requests = clampi(
			value,
			1,
			ABSOLUTE_MAX_ACTIVE_REQUESTS
		)
		_admit_pending_requests()

## 最多等待 admission 的不同资源请求数量。
##
## 同一路径复用只增加消费者 Lease，不占用额外 pending 配额。
## [br]
## @api public
## [br]
## @since unreleased
var max_pending_requests: int = DEFAULT_MAX_PENDING_REQUESTS:
	set(value):
		max_pending_requests = clampi(
			value,
			1,
			ABSOLUTE_MAX_PENDING_REQUESTS
		)


# --- 私有变量 ---

var _requests_by_key: Dictionary = {}
var _pending_requests: Array[ResourceRequestRecord] = []
var _active_requests: Array[ResourceRequestRecord] = []
var _active_exclusive: bool = false
var _disposed: bool = false


# --- GF 生命周期方法 ---

## 初始化 Broker。
## [br]
## @api public
## [br]
## @since unreleased
func init() -> void:
	ignore_pause = true
	tick_enabled = true
	_disposed = false


## 推进底层请求轮询与 admission。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _delta: 统一 Utility tick 参数。
func tick(_delta: float = 0.0) -> void:
	pump()


## 取消所有消费者，并让已发起的请求保留为 drain 状态。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	_disposed = true
	cancel_all(&"broker_disposed")


# --- 公共方法 ---

## 请求一个资源消费者 Lease。
##
## admission 使用严格 FIFO：队首独占请求会等待全部活动请求 drain，
## 后续共享请求不能绕过它。同资源身份且类型提示兼容的请求复用底层加载。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param path: `res://` 或 `uid://` 资源路径。
## [br]
## @param type_hint: 可选 ResourceLoader 类型提示。
## [br]
## @param options: admission 与诊断选项。
## [br]
## @return 独立消费者 Lease；拒绝时返回 failed Lease。
## [br]
## @schema options: Dictionary with optional exclusive: bool, require_idle: bool, and consumer_id: StringName.
func request(path: String, type_hint: String = "", options: Dictionary = {}) -> GFResourceLease:
	var identity: GFResourceIdentity = GFResourceIdentity.from_path(
		path,
		&"",
		type_hint,
		{ "check_exists": false }
	)
	var load_path: String = identity.canonical_path if not identity.canonical_path.is_empty() else identity.raw_path
	var request_key: String = identity.cache_key if not identity.cache_key.is_empty() else load_path
	var exclusive: bool = GFVariantData.get_option_bool(options, "exclusive", false)
	var require_idle: bool = GFVariantData.get_option_bool(options, "require_idle", false)
	var consumer_id: StringName = GFVariantData.get_option_string_name(options, "consumer_id", &"")
	var lease: GFResourceLease = _RESOURCE_LEASE_SCRIPT.new()
	lease.broker_bind(self, request_key, load_path, type_hint, consumer_id, exclusive, require_idle)

	if _disposed:
		lease.broker_mark_failed(ERR_UNAVAILABLE, "broker_disposed")
		return lease
	if load_path.is_empty() or request_key.is_empty():
		lease.broker_mark_failed(ERR_INVALID_PARAMETER, "invalid_resource_path")
		return lease

	var existing: ResourceRequestRecord = _get_request_record(request_key)
	if existing != null:
		if not _type_hints_are_compatible(existing.type_hint, type_hint):
			lease.broker_mark_failed(ERR_ALREADY_IN_USE, "incompatible_type_hint")
			return lease
		if existing.state == _REQUEST_QUEUED:
			if existing.type_hint.is_empty() and not type_hint.is_empty():
				existing.type_hint = type_hint
			existing.exclusive = existing.exclusive or exclusive
			existing.require_idle = existing.require_idle or require_idle
		else:
			if existing.type_hint.is_empty() and not type_hint.is_empty():
				lease.broker_mark_failed(
					ERR_ALREADY_IN_USE,
					REASON_ACTIVE_TYPE_HINT_NOT_SATISFIED
				)
				return lease
			if (
				(exclusive and not existing.exclusive)
				or (
					require_idle
					and not existing.require_idle
					and not existing.exclusive
				)
			):
				lease.broker_mark_failed(
					ERR_BUSY,
					REASON_ACTIVE_ADMISSION_CONSTRAINTS_NOT_SATISFIED
				)
				return lease
		existing.leases.append(lease)
		if existing.state != _REQUEST_QUEUED:
			existing.state = _REQUEST_ACTIVE
			lease.broker_mark_loading()
		return lease

	if _pending_requests.size() >= max_pending_requests:
		lease.broker_mark_failed(ERR_BUSY, "pending_budget_exhausted")
		return lease

	var record: ResourceRequestRecord = ResourceRequestRecord.new()
	record.request_key = request_key
	record.path = load_path
	record.type_hint = type_hint
	record.exclusive = exclusive
	record.require_idle = require_idle
	record.leases.append(lease)
	_requests_by_key[request_key] = record
	_pending_requests.append(record)
	_admit_pending_requests()
	return lease


## 推进所有活动请求并尝试 admission。
##
## 架构注册的 Broker 会由 Utility tick 自动调用；独立使用时由调用方显式调用。
## [br]
## @api public
## [br]
## @since unreleased
func pump() -> void:
	_poll_active_requests()
	_admit_pending_requests()


## 推进 Broker 并导出指定 Lease 的状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param lease: 要观察的消费者 Lease。
## [br]
## @return Lease 状态字典。
## [br]
## @schema return: Dictionary with status, progress, resource, has_resource, error, request_error, path, type_hint, consumer_id, exclusive, require_idle, cancel_reason, and released.
func poll_lease(lease: GFResourceLease) -> Dictionary:
	pump()
	if lease == null:
		return _make_missing_lease_result()
	return lease.to_poll_result()


## 取消所有尚未完成的消费者 Lease。
##
## 尚未 admission 的请求会立即移除；已经发起的请求继续 drain 到 ResourceLoader 终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: 用于诊断的稳定取消原因。
func cancel_all(reason: StringName = &"cancelled") -> void:
	var records: Array = _requests_by_key.values()
	for value: Variant in records:
		if value is ResourceRequestRecord:
			var record: ResourceRequestRecord = value
			for lease: GFResourceLease in record.leases:
				if lease != null and not lease.is_terminal():
					lease.broker_mark_cancelled(reason)
			if record.state == _REQUEST_QUEUED:
				_remove_pending_record(record)
			else:
				record.state = _REQUEST_DRAINING


## Broker 是否已经没有 queued、active 或 draining 请求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 完全 idle 时返回 true。
func is_idle() -> bool:
	return _pending_requests.is_empty() and _active_requests.is_empty()


## 导出有界 admission 与底层请求调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Broker 状态字典。
## [br]
## @schema return: Dictionary with active_count, pending_count, draining_count, active_exclusive, active_paths, pending_paths, draining_paths, max_active_requests, and max_pending_requests.
func get_debug_snapshot() -> Dictionary:
	var active_paths: PackedStringArray = PackedStringArray()
	var draining_paths: PackedStringArray = PackedStringArray()
	for record: ResourceRequestRecord in _active_requests:
		if record.state == _REQUEST_DRAINING:
			var _draining_appended: bool = draining_paths.append(record.path)
		else:
			var _active_appended: bool = active_paths.append(record.path)
	var pending_paths: PackedStringArray = PackedStringArray()
	for record: ResourceRequestRecord in _pending_requests:
		var _pending_appended: bool = pending_paths.append(record.path)
	return {
		"active_count": _active_requests.size(),
		"pending_count": _pending_requests.size(),
		"draining_count": draining_paths.size(),
		"active_exclusive": _active_exclusive,
		"active_paths": active_paths,
		"pending_paths": pending_paths,
		"draining_paths": draining_paths,
		"max_active_requests": max_active_requests,
		"max_pending_requests": max_pending_requests,
	}


# --- 可重写钩子 / 虚方法 ---

## 发起底层 ResourceLoader threaded request。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param path: 规范化资源路径。
## [br]
## @param type_hint: ResourceLoader 类型提示。
## [br]
## @return Godot Error。
func _request_threaded_resource(path: String, type_hint: String) -> Error:
	return _THREADED_RESOURCE_LOAD_ADAPTER.request(path, type_hint)


## 轮询底层 ResourceLoader threaded request。
## [br]
## @api protected
## [br]
## @since unreleased
## [br]
## @param path: 规范化资源路径。
## [br]
## @param previous_progress: 上次已知进度。
## [br]
## @return adapter 状态字典。
## [br]
## @schema return: Dictionary with status, progress, resource, has_resource, and error.
func _poll_threaded_resource(path: String, previous_progress: float) -> Dictionary:
	return _THREADED_RESOURCE_LOAD_ADAPTER.poll(path, previous_progress)


# --- 框架内部方法 ---

## 释放一个消费者 Lease。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities
## [br]
## @since unreleased
## [br]
## @param lease: 要释放的 Lease。
## [br]
## @param reason: 取消原因。
func release_lease(lease: GFResourceLease, reason: StringName = &"released") -> void:
	if lease == null or lease.is_terminal():
		return
	lease.broker_mark_cancelled(reason)
	var record: ResourceRequestRecord = _get_request_record(lease.broker_get_request_key())
	if record == null:
		return
	if record.state == _REQUEST_QUEUED:
		if _record_has_live_consumers(record):
			_recompute_queued_record_constraints(record)
			_admit_pending_requests()
			return
		_remove_pending_record(record)
		_admit_pending_requests()
		return
	if _record_has_live_consumers(record):
		return
	record.state = _REQUEST_DRAINING


# --- 私有/辅助方法 ---

func _admit_pending_requests() -> void:
	if _disposed or _active_exclusive:
		return

	while not _pending_requests.is_empty() and _active_requests.size() < max_active_requests:
		var record: ResourceRequestRecord = _pending_requests[0]
		if record == null:
			_pending_requests.remove_at(0)
			continue
		if not _record_has_live_consumers(record):
			_remove_pending_record(record)
			continue
		if record.exclusive and not _active_requests.is_empty():
			return
		if record.require_idle and not _active_requests.is_empty():
			return

		_pending_requests.remove_at(0)
		var request_error: Error = _request_threaded_resource(record.path, record.type_hint)
		if request_error != OK:
			_fail_record(record, request_error, "threaded_request_failed:%d" % request_error)
			continue

		record.state = _REQUEST_ACTIVE
		_active_requests.append(record)
		for lease: GFResourceLease in record.leases:
			if lease != null and not lease.is_terminal():
				lease.broker_mark_loading()
		if record.exclusive:
			_active_exclusive = true
			return


func _poll_active_requests() -> void:
	if _active_requests.is_empty():
		return

	var records: Array[ResourceRequestRecord] = _active_requests.duplicate()
	for record: ResourceRequestRecord in records:
		if record == null:
			continue
		var poll_result: Dictionary = _poll_threaded_resource(record.path, record.progress)
		record.progress = clampf(
			GFVariantData.get_option_float(poll_result, "progress", record.progress),
			0.0,
			1.0
		)
		for lease: GFResourceLease in record.leases:
			if lease != null and not lease.is_terminal():
				lease.broker_update_progress(record.progress)

		var status: StringName = GFVariantData.get_option_string_name(
			poll_result,
			"status",
			_THREADED_RESOURCE_LOAD_ADAPTER.STATUS_INVALID
		)
		match status:
			_THREADED_RESOURCE_LOAD_ADAPTER.STATUS_IN_PROGRESS:
				pass

			_THREADED_RESOURCE_LOAD_ADAPTER.STATUS_LOADED:
				var resource: Resource = _get_resource_value(
					GFVariantData.get_option_value(poll_result, "resource")
				)
				if resource == null:
					_fail_record(record, ERR_INVALID_DATA, "loaded_resource_missing")
				else:
					_complete_record(record, resource)

			_THREADED_RESOURCE_LOAD_ADAPTER.STATUS_FAILED:
				_fail_record(
					record,
					ERR_CANT_OPEN,
					GFVariantData.get_option_string(poll_result, "error", "thread_load_failed")
				)

			_:
				_fail_record(
					record,
					ERR_INVALID_DATA,
					GFVariantData.get_option_string(poll_result, "error", "invalid_thread_load_status")
				)


func _complete_record(record: ResourceRequestRecord, resource: Resource) -> void:
	for lease: GFResourceLease in record.leases:
		if lease != null and not lease.is_terminal():
			lease.broker_mark_completed(resource)
	_remove_active_record(record)


func _fail_record(record: ResourceRequestRecord, request_error: Error, message: String) -> void:
	for lease: GFResourceLease in record.leases:
		if lease != null and not lease.is_terminal():
			lease.broker_mark_failed(request_error, message)
	if record.state == _REQUEST_QUEUED:
		_remove_pending_record(record)
	else:
		_remove_active_record(record)


func _remove_pending_record(record: ResourceRequestRecord) -> void:
	var index: int = _pending_requests.find(record)
	if index >= 0:
		_pending_requests.remove_at(index)
	_forget_record(record)


func _remove_active_record(record: ResourceRequestRecord) -> void:
	var index: int = _active_requests.find(record)
	if index >= 0:
		_active_requests.remove_at(index)
	if record.exclusive:
		_active_exclusive = false
	_forget_record(record)


func _forget_record(record: ResourceRequestRecord) -> void:
	if record == null:
		return
	if _get_request_record(record.request_key) == record:
		var _erased: bool = _requests_by_key.erase(record.request_key)


func _get_request_record(request_key: String) -> ResourceRequestRecord:
	var value: Variant = GFVariantData.get_option_value(_requests_by_key, request_key)
	if value is ResourceRequestRecord:
		var record: ResourceRequestRecord = value
		return record
	return null


func _record_has_live_consumers(record: ResourceRequestRecord) -> bool:
	for lease: GFResourceLease in record.leases:
		if lease != null and not lease.is_released() and not lease.is_terminal():
			return true
	return false


func _recompute_queued_record_constraints(record: ResourceRequestRecord) -> void:
	record.type_hint = ""
	record.exclusive = false
	record.require_idle = false
	for index: int in range(record.leases.size() - 1, -1, -1):
		var lease: GFResourceLease = record.leases[index]
		if lease == null or lease.is_released() or lease.is_terminal():
			record.leases.remove_at(index)
			continue
		var lease_type_hint: String = lease.get_type_hint()
		if record.type_hint.is_empty() and not lease_type_hint.is_empty():
			record.type_hint = lease_type_hint
		var lease_snapshot: Dictionary = lease.to_poll_result()
		record.exclusive = (
			record.exclusive
			or GFVariantData.get_option_bool(lease_snapshot, "exclusive")
		)
		record.require_idle = (
			record.require_idle
			or GFVariantData.get_option_bool(lease_snapshot, "require_idle")
		)


func _type_hints_are_compatible(left: String, right: String) -> bool:
	return left.is_empty() or right.is_empty() or left == right


func _get_resource_value(value: Variant) -> Resource:
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


func _make_missing_lease_result() -> Dictionary:
	return {
		"status": _RESOURCE_LEASE_SCRIPT.STATUS_FAILED,
		"progress": 0.0,
		"resource": null,
		"has_resource": false,
		"error": "missing_lease",
		"request_error": ERR_INVALID_PARAMETER,
		"path": "",
		"type_hint": "",
		"consumer_id": &"",
		"exclusive": false,
		"require_idle": false,
		"cancel_reason": &"",
		"released": true,
	}


# --- 内部类 ---

## Broker 内部请求记录。
## [br]
## @api framework_internal
class ResourceRequestRecord:
	## Broker 内部请求身份。
	## [br]
	## @api framework_internal
	var request_key: String = ""

	## 已规范化的资源路径。
	## [br]
	## @api framework_internal
	var path: String = ""

	## 冻结的资源类型提示。
	## [br]
	## @api framework_internal
	var type_hint: String = ""

	## 内部请求状态。
	## [br]
	## @api framework_internal
	var state: int = _REQUEST_QUEUED

	## 是否独占 admission。
	## [br]
	## @api framework_internal
	var exclusive: bool = false

	## 是否要求其他活动请求已排空。
	## [br]
	## @api framework_internal
	var require_idle: bool = false

	## 最近一次 ResourceLoader 进度。
	## [br]
	## @api framework_internal
	var progress: float = 0.0

	## 当前消费者 Lease。
	## [br]
	## @api framework_internal
	var leases: Array[GFResourceLease] = []
