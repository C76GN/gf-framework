## GFAssetUtility: 异步资源加载管理器，带 LRU 缓存。
##
## 封装 Godot 的 threaded `ResourceLoader` 请求，
## 用于避免大资源同步加载阻塞主线程，并在完成后统一分发回调与维护缓存。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFAssetUtility
extends GFUtility


# --- 信号 ---

## 创建资源句柄时发出。
## [br]
## @api public
## [br]
## @param handle: 新创建的资源句柄。
signal asset_handle_acquired(handle: GFAssetHandle)

## 资源句柄释放时发出。
## [br]
## @api public
## [br]
## @param path: 资源路径。
## [br]
## @param reference_count: 剩余引用数量。
signal asset_handle_released(path: String, reference_count: int)

## 资源异步加载进度更新时发出。
## [br]
## @api public
## [br]
## @since 5.1.0
## [br]
## @param path: 资源路径。
## [br]
## @param progress: 当前加载进度，范围 0.0 到 1.0。
signal asset_load_progress(path: String, progress: float)

## 资源分组预加载完成时发出。
## [br]
## @api public
## [br]
## @param group_id: 分组标识。
## [br]
## @param report: 预加载报告。
## [br]
## @schema report: Dictionary with `ok: bool`, `group_id: StringName`, `paths: PackedStringArray`, `failed_paths: PackedStringArray`, `total: int`, and `completed: int`.
signal asset_group_preloaded(group_id: StringName, report: Dictionary)


## 资源加载进入队列时发出。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param path: 资源路径。
## [br]
## @param lane_id: 加载 lane 标识。
signal asset_load_queued(path: String, lane_id: StringName)


# --- 常量 ---

## 未显式指定 lane 但启用全局并发限制时使用的默认 lane。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEFAULT_LOAD_LANE_ID: StringName = &"_default"
const _THREADED_RESOURCE_LOAD_ADAPTER = preload("res://addons/gf/standard/utilities/assets/gf_threaded_resource_load_adapter.gd")


# --- 公共变量 ---

## LRU 缓存最大容量；设为 `0` 时表示禁用缓存。
## [br]
## @api public
var max_cache_size: int:
	get:
		return _max_cache_size
	set(value):
		_max_cache_size = maxi(value, 0)
		if _max_cache_size == 0:
			clear_cache()
			return

		_evict_lru()


## 默认最大并发加载数；设为 `0` 表示默认不限制并发。
## [br]
## @api public
## [br]
## @since 6.0.0
var default_max_concurrent_loads: int = 0


# --- 私有变量 ---

var _max_cache_size: int = 64

# 正在加载中的请求：`path -> { type_hint: String, callbacks: Array[Callable], cancelled: bool }`。
var _pending: Dictionary = {}

# 等待开始的请求。
var _queued_requests: Array = []
var _queued_by_path: Dictionary = {}
var _lane_active_counts: Dictionary = {}

# 资源缓存：`path -> Resource`。
var _cache: Dictionary = {}

# LRU 访问序号，数值越大表示越新。
var _cache_access_order: Dictionary = {}
var _cache_access_serial: int = 0
var _pinned_cache_paths: Dictionary = {}
var _reference_counts: Dictionary = {}
var _owner_reference_counts: Dictionary = {}
var _owner_refs: Dictionary = {}
var _owner_release_connected: Dictionary = {}
var _handle_refs: Array[WeakRef] = []
var _group_paths: Dictionary = {}
var _group_pin_counts: Dictionary = {}
var _cache_diagnostics: GFCacheDiagnostics = GFCacheDiagnostics.new()


# --- GF 生命周期方法 ---

## 初始化资源加载工具的运行时状态。
## [br]
## @api public
func init() -> void:
	ignore_pause = true
	_pending = {}
	_queued_requests.clear()
	_queued_by_path.clear()
	_lane_active_counts.clear()
	_cache.clear()
	_cache_access_order.clear()
	_pinned_cache_paths.clear()
	_reference_counts.clear()
	_owner_reference_counts.clear()
	_owner_refs.clear()
	_owner_release_connected.clear()
	_handle_refs.clear()
	_group_paths.clear()
	_group_pin_counts.clear()
	_cache_access_serial = 0
	_cache_diagnostics.cache_id = &"asset"
	_cache_diagnostics.reset()


## 释放资源加载工具持有的运行时状态。
## [br]
## @api public
func dispose() -> void:
	_cancel_pending_requests_for_dispose()
	_release_all_handles()
	_pending.clear()
	_queued_requests.clear()
	_queued_by_path.clear()
	_lane_active_counts.clear()
	_cache.clear()
	_cache_access_order.clear()
	_pinned_cache_paths.clear()
	_reference_counts.clear()
	_owner_reference_counts.clear()
	_owner_refs.clear()
	_owner_release_connected.clear()
	_handle_refs.clear()
	_group_paths.clear()
	_group_pin_counts.clear()
	_cache_access_serial = 0


# --- 公共方法 ---

## 发起异步资源加载。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param path: 目标资源路径。
## [br]
## @param on_loaded: 加载完成后的回调。
## [br]
## @param type_hint: 可选资源类型提示。
## [br]
## @param options: 可选参数，支持 serial_lane_id、lane_id、max_concurrent_loads。
## [br]
## @schema options: Dictionary with optional `serial_lane_id: StringName`, `lane_id: StringName`, and `max_concurrent_loads: int`. A non-empty lane defaults to serial loading when no limit is provided.
func load_async(path: String, on_loaded: Callable, type_hint: String = "", options: Dictionary = {}) -> void:
	if path.is_empty() or not on_loaded.is_valid():
		push_error("[GFAssetUtility] 无效的路径或回调。")
		return

	var cached: Resource = get_cached(path)
	if cached != null:
		if not _is_resource_compatible(cached, type_hint):
			push_warning("[GFAssetUtility] 缓存资源类型与请求 type_hint 不匹配：%s (%s)" % [path, type_hint])
			on_loaded.call(null)
			return

		on_loaded.call(cached)
		return

	if _pending.has(path):
		var pending_request: Dictionary = _get_pending_request(path)
		var pending_type_hint: String = _get_pending_type_hint(pending_request)
		if not _pending_type_hints_are_compatible(pending_type_hint, type_hint):
			push_warning("[GFAssetUtility] 已存在相同路径但 type_hint 不同的加载请求，已拒绝新请求：%s (%s -> %s)" % [path, pending_type_hint, type_hint])
			on_loaded.call(null)
			return

		var callbacks: Array = _get_pending_callbacks(pending_request)
		if _is_pending_cancelled(pending_request):
			callbacks.clear()
			pending_request["cancelled"] = false
		if not _callback_entries_have_callable(callbacks, on_loaded):
			_append_array_value(callbacks, _make_callback_entry(on_loaded, type_hint))
		return

	if _queued_by_path.has(path):
		var queued_request: Dictionary = _get_queued_request(path)
		var queued_type_hint: String = _get_pending_type_hint(queued_request)
		if not _pending_type_hints_are_compatible(queued_type_hint, type_hint):
			push_warning("[GFAssetUtility] 已存在相同路径但 type_hint 不同的排队加载请求，已拒绝新请求：%s (%s -> %s)" % [path, queued_type_hint, type_hint])
			on_loaded.call(null)
			return

		var queued_callbacks: Array = _get_pending_callbacks(queued_request)
		if _is_pending_cancelled(queued_request):
			queued_callbacks.clear()
			queued_request["cancelled"] = false
		if not _callback_entries_have_callable(queued_callbacks, on_loaded):
			_append_array_value(queued_callbacks, _make_callback_entry(on_loaded, type_hint))
		return

	var request: Dictionary = {
		"type_hint": type_hint,
		"callbacks": [_make_callback_entry(on_loaded, type_hint)],
		"cancelled": false,
		"progress": 0.0,
		"lane_id": _resolve_load_lane_id(options),
		"max_concurrent_loads": _resolve_load_lane_limit(options),
	}
	_start_or_queue_request(path, request)


## 异步加载资源并在成功后返回所有权句柄。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param path: 目标资源路径。
## [br]
## @param on_loaded: 加载完成回调，签名为 func(handle: GFAssetHandle)；失败时传入 null。
## [br]
## @param type_hint: 可选资源类型提示。
## [br]
## @param owner: 可选拥有者。若为 Node，会在退出树时自动释放其持有的句柄引用。
## [br]
## @param group_id: 可选资源分组。
## [br]
## @param options: 传给 load_async() 的加载选项。
## [br]
## @schema options: Dictionary with optional serial loading lane fields.
func load_handle_async(
	path: String,
	on_loaded: Callable,
	type_hint: String = "",
	owner: Object = null,
	group_id: StringName = &"",
	options: Dictionary = {}
) -> void:
	if path.is_empty() or not on_loaded.is_valid():
		push_error("[GFAssetUtility] load_handle_async 失败：路径或回调无效。")
		return

	var owner_ref: WeakRef = weakref(owner) if owner != null else null
	var on_resource_loaded: Callable = func(resource: Resource) -> void:
		if resource == null:
			on_loaded.call(null)
			return
		var resolved_owner: Object = _get_live_object_from_ref(owner_ref)
		if owner_ref != null and resolved_owner == null:
			on_loaded.call(null)
			return

		on_loaded.call(acquire_handle(path, resolved_owner, group_id, type_hint, resource))

	load_async(path, on_resource_loaded, type_hint, options)


## 为已缓存或指定资源创建所有权句柄。
## [br]
## @api public
## [br]
## @param path: 资源路径。
## [br]
## @param owner: 可选拥有者。若为 Node，会在退出树时自动释放其持有的句柄引用。
## [br]
## @param group_id: 可选资源分组。
## [br]
## @param type_hint: 可选资源类型提示。
## [br]
## @param resource_override: 可选资源实例；为空时使用当前缓存。
## [br]
## @return 成功时返回句柄；资源不可用时返回 null。
func acquire_handle(
	path: String,
	owner: Object = null,
	group_id: StringName = &"",
	type_hint: String = "",
	resource_override: Resource = null
) -> GFAssetHandle:
	if path.is_empty():
		push_error("[GFAssetUtility] acquire_handle 失败：路径为空。")
		return null

	var resource: Resource = resource_override if resource_override != null else get_cached(path)
	if resource == null:
		return null
	if not _is_resource_compatible(resource, type_hint):
		push_warning("[GFAssetUtility] acquire_handle 失败：缓存资源类型与 type_hint 不匹配：%s (%s)" % [path, type_hint])
		return null

	if not is_cached(path):
		put_cache(path, resource)

	var owner_id: int = _owner_instance_id(owner)
	_increment_reference(path, owner, group_id)

	var handle: GFAssetHandle = GFAssetHandle.new()
	handle.setup_from_utility(self, path, resource, type_hint, group_id, owner_id)
	_track_handle(handle)
	asset_handle_acquired.emit(handle)
	return handle


## 释放资源句柄。
## [br]
## @api public
## [br]
## @param handle: 要释放的资源句柄。
## [br]
## @return 释放成功返回 true。
func release_handle(handle: GFAssetHandle) -> bool:
	if handle == null or handle.path.is_empty() or handle.is_released():
		return false

	var path: String = handle.path
	var remaining: int = _decrement_reference(path, handle.get_owner_id())
	handle.release_local_reference()
	_prune_handle_refs()
	asset_handle_released.emit(path, remaining)
	return true


## 释放指定 owner 持有的所有资源引用。
## [br]
## @api public
## [br]
## @param owner: 拥有者对象。
## [br]
## @return 释放的引用数量。
func release_owner(owner: Object) -> int:
	if owner == null:
		return 0
	return _release_owner_id(owner.get_instance_id())


## 获取指定资源路径当前句柄引用数量。
## [br]
## @api public
## [br]
## @param path: 资源路径。
## [br]
## @return 引用数量。
func get_asset_reference_count(path: String) -> int:
	return _get_count_value(_reference_counts, path)


## 注册资源路径到分组。
## [br]
## @api public
## [br]
## @param group_id: 分组标识。
## [br]
## @param path: 资源路径。
## [br]
## @param pin: 是否以分组名义锁定缓存，避免 LRU 淘汰。
func register_group_path(group_id: StringName, path: String, pin: bool = false) -> void:
	if group_id == &"" or path.is_empty():
		return
	if not _group_paths.has(group_id):
		_group_paths[group_id] = {}
	_group_paths[group_id][path] = true
	if pin:
		if not _group_pin_counts.has(group_id):
			_group_pin_counts[group_id] = {}
		var pin_counts: Dictionary = GFVariantData.as_dictionary(_group_pin_counts[group_id])
		pin_counts[path] = _get_count_value(pin_counts, path) + 1
		pin_cache(path)


## 获取分组中的资源路径。
## [br]
## @api public
## [br]
## @param group_id: 分组标识。
## [br]
## @return 路径列表。
func get_group_paths(group_id: StringName) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var paths: Dictionary = _get_group_path_map(group_id)
	for path: String in paths.keys():
		_append_packed_string(result, path)
	result.sort()
	return result


## 异步预加载资源分组。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param group_id: 分组标识。
## [br]
## @param entries: 路径字符串，或包含 path/type_hint 字段的字典数组。
## [br]
## @schema entries: Array[String|Dictionary] where dictionary entries may contain `path: String` and `type_hint: String`.
## [br]
## @param on_completed: 完成回调，签名为 func(report: Dictionary)。
## [br]
## @param options: 可选参数，支持 pin_cache。
## [br]
## @schema options: Dictionary with optional `pin_cache: bool`, `serial_lane_id: StringName`, `lane_id: StringName`, and `max_concurrent_loads: int`.
func preload_group_async(
	group_id: StringName,
	entries: Array,
	on_completed: Callable = Callable(),
	options: Dictionary = {}
) -> void:
	if group_id == &"":
		push_error("[GFAssetUtility] preload_group_async 失败：group_id 为空。")
		return

	var pin_loaded: bool = GFVariantData.get_option_bool(options, "pin_cache", true)
	var report: Dictionary = {
		"ok": true,
		"group_id": group_id,
		"paths": PackedStringArray(),
		"failed_paths": PackedStringArray(),
		"total": entries.size(),
		"completed": 0,
	}
	var finished: Array = [false]
	if entries.is_empty():
		_finish_group_preload(group_id, report, on_completed)
		return

	var load_options: Dictionary = _make_group_load_options(options, group_id)
	for entry: Variant in entries:
		var request: Dictionary = _normalize_group_entry(entry)
		var path: String = _get_group_entry_path(request)
		var type_hint: String = _get_group_entry_type_hint(request)
		if path.is_empty():
			report["ok"] = false
			_append_report_path(report, "failed_paths", path)
			_increment_report_completed(report)
			continue

		var request_path: String = path
		var request_type_hint: String = type_hint
		load_async(request_path, func(resource: Resource) -> void:
			if resource == null:
				report["ok"] = false
				_append_report_path(report, "failed_paths", request_path)
			else:
				register_group_path(group_id, request_path, pin_loaded)
				_append_report_path(report, "paths", request_path)

			_increment_report_completed(report)
			if _is_group_preload_finished(report, finished):
				finished[0] = true
				_finish_group_preload(group_id, report, on_completed)
		, request_type_hint, load_options)

	if _is_group_preload_finished(report, finished):
		finished[0] = true
		_finish_group_preload(group_id, report, on_completed)


## 卸载资源分组。
## [br]
## @api public
## [br]
## @param group_id: 分组标识。
## [br]
## @param remove_unreferenced_cache: 是否移除没有句柄引用的缓存项。
func unload_group(group_id: StringName, remove_unreferenced_cache: bool = false) -> void:
	var paths: Dictionary = _get_group_path_map(group_id)
	var pin_counts: Dictionary = _get_group_pin_map(group_id)
	for path: String in paths.keys():
		var pin_count: int = _get_count_value(pin_counts, path)
		for _i: int in range(pin_count):
			unpin_cache(path)
		if remove_unreferenced_cache and get_asset_reference_count(path) <= 0:
			remove_cache(path)

	_erase_dictionary_key(_group_paths, group_id)
	_erase_dictionary_key(_group_pin_counts, group_id)


## 驱动异步加载轮询。
## [br]
## @api public
## [br]
## @param _delta: 为兼容统一 tick 签名而保留的参数。
func tick(_delta: float = 0.0) -> void:
	_poll_pending()


## 获取缓存中的资源。
## [br]
## @api public
## [br]
## @param path: 资源路径。
## [br]
## @return 命中缓存时返回资源，否则返回 `null`。
func get_cached(path: String) -> Resource:
	if _cache.has(path):
		_cache_diagnostics.record_hit(path)
		_touch_cache(path)
		return _cache[path]

	if not path.is_empty():
		_cache_diagnostics.record_miss(path)
	return null


## 检查指定路径是否正在加载中。
## [br]
## @api public
## [br]
## @param path: 资源路径。
## [br]
## @param type_hint: 可选资源类型提示；为空时只检查路径。
## [br]
## @return 正在加载时返回 `true`。
func is_loading(path: String, type_hint: String = "") -> bool:
	if not _pending.has(path):
		if not _queued_by_path.has(path):
			return false
		var queued_request: Dictionary = _get_queued_request(path)
		if _is_pending_cancelled(queued_request):
			return false
		if type_hint.is_empty():
			return true
		return _get_pending_type_hint(queued_request) == type_hint

	var pending_request: Dictionary = _get_pending_request(path)
	if _is_pending_cancelled(pending_request):
		return false
	if type_hint.is_empty():
		return true

	return _get_pending_type_hint(pending_request) == type_hint


## 获取资源异步加载进度。
## [br]
## @api public
## [br]
## @since 5.1.0
## [br]
## @param path: 资源路径。
## [br]
## @return 已缓存返回 1.0，正在加载返回最近轮询进度，其余返回 0.0。
func get_load_progress(path: String) -> float:
	if path.is_empty():
		return 0.0
	if is_cached(path):
		return 1.0
	if _queued_by_path.has(path):
		var queued_request: Dictionary = _get_queued_request(path)
		return 0.0 if not _is_pending_cancelled(queued_request) else 0.0
	if not _pending.has(path):
		return 0.0

	var pending_request: Dictionary = _get_pending_request(path)
	if _is_pending_cancelled(pending_request):
		return 0.0
	return clampf(_get_pending_progress(pending_request), 0.0, 1.0)


## 检查指定路径是否已缓存。
## [br]
## @api public
## [br]
## @param path: 资源路径。
## [br]
## @return 已缓存时返回 `true`。
func is_cached(path: String) -> bool:
	return _cache.has(path)


## 取消指定路径的异步加载请求。
## [br]
## @api public
## [br]
## @param path: 资源路径。
## [br]
## @param type_hint: 可选资源类型提示；为空时取消该路径的当前请求。
func cancel(path: String, type_hint: String = "") -> void:
	if _queued_by_path.has(path):
		var queued_request: Dictionary = _get_queued_request(path)
		var queued_type_hint: String = _get_pending_type_hint(queued_request)
		if type_hint.is_empty() or queued_type_hint == type_hint:
			_get_pending_callbacks(queued_request).clear()
			queued_request["cancelled"] = true
		return

	if not _pending.has(path):
		return

	var pending_request: Dictionary = _get_pending_request(path)
	var pending_type_hint: String = _get_pending_type_hint(pending_request)
	if not type_hint.is_empty() and pending_type_hint != type_hint:
		return

	var callbacks: Array = _get_pending_callbacks(pending_request)
	callbacks.clear()
	pending_request["cancelled"] = true


## 手动写入缓存。
## [br]
## @api public
## [br]
## @param path: 资源路径。
## [br]
## @param resource: 要缓存的资源实例。
func put_cache(path: String, resource: Resource) -> void:
	if path.is_empty() or resource == null or max_cache_size <= 0:
		return

	_cache[path] = resource
	_cache_diagnostics.record_write(path)
	_touch_cache(path)
	_evict_lru()


## 手动移除缓存项。
## [br]
## @api public
## [br]
## @param path: 资源路径。
func remove_cache(path: String) -> void:
	if _cache.has(path):
		_cache_diagnostics.record_invalidation(&"manual_remove", path)
	_release_handles_for_path(path)
	_erase_dictionary_key(_cache, path)
	_erase_dictionary_key(_cache_access_order, path)
	_erase_dictionary_key(_pinned_cache_paths, path)
	_erase_dictionary_key(_reference_counts, path)
	_erase_dictionary_key(_owner_reference_counts, path)
	_remove_path_from_groups(path)


## 清空全部缓存。
## [br]
## @api public
func clear_cache() -> void:
	if not _cache.is_empty():
		_cache_diagnostics.record_invalidation(&"clear", "", _cache.size())
	_cache.clear()
	_cache_access_order.clear()
	_pinned_cache_paths.clear()
	_reference_counts.clear()
	_owner_reference_counts.clear()
	_owner_refs.clear()
	_release_all_handles()
	_group_paths.clear()
	_group_pin_counts.clear()
	_cache_access_serial = 0


## 获取当前缓存数量。
## [br]
## @api public
## [br]
## @return 当前缓存中的资源数。
func get_cache_count() -> int:
	return _cache.size()


## 锁定指定缓存路径，使其不参与 LRU 淘汰。
## [br]
## @api public
## [br]
## @param path: 资源路径。
func pin_cache(path: String) -> void:
	if path.is_empty():
		return
	_pinned_cache_paths[path] = _get_count_value(_pinned_cache_paths, path) + 1


## 解除指定缓存路径的 LRU 锁定。
## [br]
## @api public
## [br]
## @param path: 资源路径。
func unpin_cache(path: String) -> void:
	if not _pinned_cache_paths.has(path):
		return

	var count: int = _get_count_value(_pinned_cache_paths, path) - 1
	if count > 0:
		_pinned_cache_paths[path] = count
	else:
		_erase_dictionary_key(_pinned_cache_paths, path)
	_evict_lru()


## 检查指定缓存路径是否已被锁定。
## [br]
## @api public
## [br]
## @param path: 资源路径。
## [br]
## @return 已锁定返回 true。
func is_cache_pinned(path: String) -> bool:
	return _get_count_value(_pinned_cache_paths, path) > 0


## 获取资源加载工具诊断快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 诊断快照字典。
## [br]
## @schema return: Dictionary with cache, pending, pending_progress, pinned, reference count, and group count diagnostic fields.
func get_debug_snapshot() -> Dictionary:
	var cached_paths: PackedStringArray = PackedStringArray()
	for path: String in _cache.keys():
		_append_packed_string(cached_paths, path)
	cached_paths.sort()

	var pending_paths: PackedStringArray = PackedStringArray()
	for path: String in _pending.keys():
		var pending_request: Dictionary = _get_pending_request(path)
		if not _is_pending_cancelled(pending_request):
			_append_packed_string(pending_paths, path)
	pending_paths.sort()

	var pending_progress: Dictionary = {}
	for path: String in pending_paths:
		var pending_request: Dictionary = _get_pending_request(path)
		pending_progress[path] = clampf(_get_pending_progress(pending_request), 0.0, 1.0)

	var pinned_paths: PackedStringArray = PackedStringArray()
	for path: String in _pinned_cache_paths.keys():
		if _get_count_value(_pinned_cache_paths, path) > 0:
			_append_packed_string(pinned_paths, path)
	pinned_paths.sort()

	return {
		"max_cache_size": max_cache_size,
		"cache_count": _cache.size(),
		"cached_paths": cached_paths,
		"pending_count": pending_paths.size(),
		"pending_paths": pending_paths,
		"pending_progress": pending_progress,
		"pinned_count": pinned_paths.size(),
		"pinned_paths": pinned_paths,
		"reference_counts": _reference_counts.duplicate(),
		"group_count": _group_paths.size(),
		"queued_count": _queued_requests.size(),
		"queued_paths": _get_queued_paths(),
		"lane_active_counts": _lane_active_counts.duplicate(),
		"cache_diagnostics": _cache_diagnostics.get_debug_snapshot(),
	}


# --- 私有/辅助方法 ---

func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var erased: bool = target.erase(key)
	if erased:
		return


func _append_array_value(target: Array, value: Variant) -> void:
	target.append(value)


func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _get_dictionary_reference(source: Dictionary, key: Variant) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(source, key, {}))


func _get_pending_request(path: String) -> Dictionary:
	return _get_dictionary_reference(_pending, path)


func _get_queued_request(path: String) -> Dictionary:
	return _get_dictionary_reference(_queued_by_path, path)


func _get_pending_type_hint(pending_request: Dictionary) -> String:
	return GFVariantData.get_option_string(pending_request, "type_hint", "")


func _get_pending_callbacks(pending_request: Dictionary) -> Array:
	return GFVariantData.as_array(GFVariantData.get_option_value(pending_request, "callbacks", []))


func _get_pending_progress(pending_request: Dictionary) -> float:
	return GFVariantData.get_option_float(pending_request, "progress", 0.0)


func _get_pending_lane_id(pending_request: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(pending_request, "lane_id", &"")


func _get_pending_lane_limit(pending_request: Dictionary) -> int:
	return GFVariantData.get_option_int(pending_request, "max_concurrent_loads", 0)


func _is_pending_cancelled(pending_request: Dictionary) -> bool:
	return GFVariantData.get_option_bool(pending_request, "cancelled", false)


func _get_group_path_map(group_id: StringName) -> Dictionary:
	return _get_dictionary_reference(_group_paths, group_id)


func _get_group_pin_map(group_id: StringName) -> Dictionary:
	return _get_dictionary_reference(_group_pin_counts, group_id)


func _get_count_value(source: Dictionary, key: Variant) -> int:
	return GFVariantData.get_option_int(source, key, 0)


func _get_report_completed(report: Dictionary) -> int:
	return GFVariantData.get_option_int(report, "completed", 0)


func _get_report_total(report: Dictionary) -> int:
	return GFVariantData.get_option_int(report, "total", 0)


func _increment_report_completed(report: Dictionary) -> void:
	report["completed"] = _get_report_completed(report) + 1


func _is_group_preload_finished(report: Dictionary, finished: Array) -> bool:
	return _get_report_completed(report) >= _get_report_total(report) and not GFVariantData.to_bool(finished[0])


func _get_group_entry_path(request: Dictionary) -> String:
	return GFVariantData.get_option_string(request, "path", "")


func _get_group_entry_type_hint(request: Dictionary) -> String:
	return GFVariantData.get_option_string(request, "type_hint", "")


func _get_report_paths(report: Dictionary, key: String) -> PackedStringArray:
	return _get_packed_string_array_value(GFVariantData.get_option_value(report, key, PackedStringArray()))


func _get_callback_entry_callable(entry: Dictionary) -> Callable:
	return _get_callable_value(GFVariantData.get_option_value(entry, "callable", Callable()))


func _get_callback_entry_type_hint(entry: Dictionary) -> String:
	return GFVariantData.get_option_string(entry, "type_hint", "")


func _connect_signal_checked(
	source_signal: Signal,
	callback: Callable,
	one_shot: bool = false
) -> void:
	if not source_signal.is_null() and callback.is_valid():
		var connected_callback: Callable = callback
		if one_shot:
			var one_shot_callback: Callable
			one_shot_callback = func() -> void:
				if source_signal.is_connected(one_shot_callback):
					source_signal.disconnect(one_shot_callback)
				var callback_result: Variant = callback.call()
				if callback_result != null:
					return
			connected_callback = one_shot_callback
		var error: Error = source_signal.connect(connected_callback) as Error
		if error != OK and error != ERR_ALREADY_EXISTS:
			push_warning("[GFAssetUtility] Signal 连接失败：%d。" % error)


func _append_report_path(report: Dictionary, key: String, path: String) -> void:
	var paths: PackedStringArray = _get_packed_string_array_value(
		GFVariantData.get_option_value(report, key, PackedStringArray())
	)
	_append_packed_string(paths, path)
	report[key] = paths


func _get_packed_string_array_value(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	return PackedStringArray()


func _get_callable_value(value: Variant) -> Callable:
	if value is Callable:
		return value
	return Callable()


func _start_or_queue_request(path: String, request: Dictionary) -> void:
	var lane_id: StringName = _get_pending_lane_id(request)
	var lane_limit: int = _get_pending_lane_limit(request)
	if _should_queue_request(lane_id, lane_limit):
		_queued_requests.append(request)
		_queued_by_path[path] = request
		request["path"] = path
		asset_load_queued.emit(path, lane_id)
		asset_load_progress.emit(path, 0.0)
		return

	var error: Error = _activate_load_request(path, request, true)
	if error != OK:
		return


func _activate_load_request(path: String, request: Dictionary, emit_initial_progress: bool) -> Error:
	var lane_id: StringName = _get_pending_lane_id(request)
	_begin_lane_request(lane_id)

	var type_hint: String = _get_pending_type_hint(request)
	var error: Error = _request_threaded(path, type_hint)
	if error != OK:
		_end_lane_request(lane_id)
		push_error("[GFAssetUtility] 无法发起异步加载请求：%s (错误码：%d)" % [path, error])
		_dispatch_callbacks(_get_pending_callbacks(request), null)
		return error

	_pending[path] = request
	if emit_initial_progress:
		asset_load_progress.emit(path, 0.0)
	return OK


func _should_queue_request(lane_id: StringName, lane_limit: int) -> bool:
	if lane_id == &"" or lane_limit <= 0:
		return false
	return _get_count_value(_lane_active_counts, lane_id) >= lane_limit


func _begin_lane_request(lane_id: StringName) -> void:
	if lane_id == &"":
		return
	_lane_active_counts[lane_id] = _get_count_value(_lane_active_counts, lane_id) + 1


func _end_lane_request(lane_id: StringName) -> void:
	if lane_id == &"":
		return
	var next_count: int = _get_count_value(_lane_active_counts, lane_id) - 1
	if next_count > 0:
		_lane_active_counts[lane_id] = next_count
	else:
		_erase_dictionary_key(_lane_active_counts, lane_id)


func _drain_load_queue() -> void:
	var index: int = 0
	while index < _queued_requests.size():
		var request: Dictionary = GFVariantData.as_dictionary(_queued_requests[index])
		var path: String = GFVariantData.get_option_string(request, "path", "")
		if path.is_empty() or _is_pending_cancelled(request):
			_queued_requests.remove_at(index)
			_erase_dictionary_key(_queued_by_path, path)
			continue

		var lane_id: StringName = _get_pending_lane_id(request)
		var lane_limit: int = _get_pending_lane_limit(request)
		if _should_queue_request(lane_id, lane_limit):
			index += 1
			continue

		_queued_requests.remove_at(index)
		_erase_dictionary_key(_queued_by_path, path)
		var _error: Error = _activate_load_request(path, request, false)


func _resolve_load_lane_id(options: Dictionary) -> StringName:
	var lane_id: StringName = GFVariantData.get_option_string_name(options, "serial_lane_id", &"")
	if lane_id == &"":
		lane_id = GFVariantData.get_option_string_name(options, "lane_id", &"")
	if lane_id != &"":
		return lane_id
	if _resolve_load_lane_limit(options) > 0:
		return DEFAULT_LOAD_LANE_ID
	return &""


func _resolve_load_lane_limit(options: Dictionary) -> int:
	var explicit_limit: int = GFVariantData.get_option_int(options, "max_concurrent_loads", 0)
	if explicit_limit > 0:
		return explicit_limit
	if default_max_concurrent_loads > 0:
		return default_max_concurrent_loads
	var explicit_lane: StringName = GFVariantData.get_option_string_name(options, "serial_lane_id", &"")
	if explicit_lane == &"":
		explicit_lane = GFVariantData.get_option_string_name(options, "lane_id", &"")
	return 1 if explicit_lane != &"" else 0


func _make_group_load_options(options: Dictionary, group_id: StringName) -> Dictionary:
	var load_options: Dictionary = options.duplicate(true)
	if (
		not load_options.has("serial_lane_id")
		and not load_options.has("lane_id")
		and GFVariantData.get_option_int(load_options, "max_concurrent_loads", 0) > 0
	):
		load_options["serial_lane_id"] = group_id
	return load_options


func _get_queued_paths() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for request_variant: Variant in _queued_requests:
		var request: Dictionary = GFVariantData.as_dictionary(request_variant)
		var path: String = GFVariantData.get_option_string(request, "path")
		if not path.is_empty() and not _is_pending_cancelled(request):
			_append_packed_string(paths, path)
	paths.sort()
	return paths


func _get_resource_value(value: Variant) -> Resource:
	if value is Resource:
		return value
	return null


func _get_script_value(value: Variant) -> Script:
	if value is Script:
		return value
	return null


func _get_asset_handle_value(value: Variant) -> GFAssetHandle:
	if value is GFAssetHandle:
		return value
	return null


func _get_live_object_from_ref(object_ref: WeakRef) -> Object:
	if object_ref == null:
		return null
	var value: Variant = object_ref.get_ref()
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	var object: Object = value
	return object


func _poll_pending() -> void:
	if _pending.is_empty():
		return

	var pending_paths: Array = _pending.keys()
	for path: String in pending_paths:
		if not _pending.has(path):
			continue

		var pending_request: Dictionary = _get_pending_request(path)
		var callbacks: Array = _get_pending_callbacks(pending_request)
		var cancelled: bool = _is_pending_cancelled(pending_request)
		var progress_result: Array = []
		var status: ResourceLoader.ThreadLoadStatus = _get_threaded_status_with_progress(path, progress_result)
		if not cancelled:
			var progress: float = _get_threaded_progress(pending_request, progress_result, status)
			_update_pending_progress(path, pending_request, progress)

		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				var resource: Resource = _take_threaded_resource(path)
				if resource != null and not cancelled:
					_update_pending_progress(path, pending_request, 1.0)
				_erase_dictionary_key(_pending, path)
				if resource != null and not cancelled:
					put_cache(path, resource)
				if not cancelled:
					_dispatch_callbacks(callbacks, resource)
				_complete_pending_lane(pending_request)

			ResourceLoader.THREAD_LOAD_FAILED:
				_erase_dictionary_key(_pending, path)
				if not cancelled:
					push_error("[GFAssetUtility] 异步加载失败：%s" % path)
					_dispatch_callbacks(callbacks, null)
				_complete_pending_lane(pending_request)

			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				_erase_dictionary_key(_pending, path)
				if not cancelled:
					push_error("[GFAssetUtility] 无效资源：%s" % path)
					_dispatch_callbacks(callbacks, null)
				_complete_pending_lane(pending_request)


func _get_threaded_progress(
	pending_request: Dictionary,
	progress_result: Array,
	status: ResourceLoader.ThreadLoadStatus
) -> float:
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		return 1.0
	if progress_result.size() > 0:
		return clampf(GFVariantData.to_float(progress_result[0], _get_pending_progress(pending_request)), 0.0, 1.0)
	return _get_pending_progress(pending_request)


func _update_pending_progress(path: String, pending_request: Dictionary, progress: float) -> void:
	var clamped_progress: float = clampf(progress, 0.0, 1.0)
	var previous_progress: float = _get_pending_progress(pending_request)
	if is_equal_approx(previous_progress, clamped_progress):
		return

	pending_request["progress"] = clamped_progress
	asset_load_progress.emit(path, clamped_progress)


func _complete_pending_lane(pending_request: Dictionary) -> void:
	_end_lane_request(_get_pending_lane_id(pending_request))
	_drain_load_queue()


func _dispatch_callbacks(callbacks: Array, resource: Resource) -> void:
	for callback_entry: Variant in callbacks:
		var entry: Dictionary = GFVariantData.as_dictionary(callback_entry)
		var callback: Callable = Callable()
		var type_hint: String = ""
		if not entry.is_empty():
			callback = _get_callback_entry_callable(entry)
			type_hint = _get_callback_entry_type_hint(entry)
		elif callback_entry is Callable:
			callback = callback_entry
		if callback.is_valid():
			callback.call(resource if resource == null or _is_resource_compatible(resource, type_hint) else null)


func _cancel_pending_requests_for_dispose() -> void:
	for pending_value: Variant in _pending.values():
		var pending_request: Dictionary = GFVariantData.as_dictionary(pending_value)
		if _is_pending_cancelled(pending_request):
			continue
		pending_request["cancelled"] = true
		_dispatch_callbacks(_get_pending_callbacks(pending_request).duplicate(), null)

	for queued_value: Variant in _queued_requests:
		var queued_request: Dictionary = GFVariantData.as_dictionary(queued_value)
		if _is_pending_cancelled(queued_request):
			continue
		queued_request["cancelled"] = true
		_dispatch_callbacks(_get_pending_callbacks(queued_request).duplicate(), null)


func _owner_instance_id(owner: Object) -> int:
	return owner.get_instance_id() if owner != null else 0


func _increment_reference(path: String, owner: Object, group_id: StringName) -> void:
	_reference_counts[path] = _get_count_value(_reference_counts, path) + 1
	pin_cache(path)
	if group_id != &"":
		register_group_path(group_id, path)

	var owner_id: int = _owner_instance_id(owner)
	if owner_id == 0:
		return

	if not _owner_reference_counts.has(path):
		_owner_reference_counts[path] = {}
	var owner_counts: Dictionary = GFVariantData.as_dictionary(_owner_reference_counts[path])
	owner_counts[owner_id] = _get_count_value(owner_counts, owner_id) + 1
	_track_owner(owner)


func _decrement_reference(path: String, owner_id: int, release_count: int = 1) -> int:
	var count_to_release: int = maxi(release_count, 1)
	var current_count: int = _get_count_value(_reference_counts, path)
	var next_count: int = maxi(current_count - count_to_release, 0)
	if next_count > 0:
		_reference_counts[path] = next_count
	else:
		_erase_dictionary_key(_reference_counts, path)

	for _i: int in range(current_count - next_count):
		unpin_cache(path)

	if owner_id != 0 and _owner_reference_counts.has(path):
		var owner_counts: Dictionary = GFVariantData.as_dictionary(_owner_reference_counts[path])
		var owner_count: int = _get_count_value(owner_counts, owner_id) - count_to_release
		if owner_count > 0:
			owner_counts[owner_id] = owner_count
		else:
			_erase_dictionary_key(owner_counts, owner_id)
		if owner_counts.is_empty():
			_erase_dictionary_key(_owner_reference_counts, path)

	return next_count


func _track_owner(owner: Object) -> void:
	if owner == null:
		return

	var owner_id: int = owner.get_instance_id()
	_owner_refs[owner_id] = weakref(owner)
	if owner is Node and not GFVariantData.get_option_bool(_owner_release_connected, owner_id, false):
		var owner_node: Node = owner
		_connect_signal_checked(owner_node.tree_exited, _release_owner_id.bind(owner_id), true)
		_owner_release_connected[owner_id] = true


func _track_handle(handle: GFAssetHandle) -> void:
	if handle != null:
		_append_array_value(_handle_refs, weakref(handle))


func _prune_handle_refs() -> void:
	for index: int in range(_handle_refs.size() - 1, -1, -1):
		var handle: GFAssetHandle = _get_asset_handle_value(_handle_refs[index].get_ref())
		if handle == null or handle.is_released():
			_handle_refs.remove_at(index)


func _release_all_handles() -> void:
	for handle_ref: WeakRef in _handle_refs:
		var handle: GFAssetHandle = _get_asset_handle_value(handle_ref.get_ref())
		if handle != null:
			handle.release_local_reference()
	_handle_refs.clear()


func _release_handles_for_path(path: String) -> void:
	for index: int in range(_handle_refs.size() - 1, -1, -1):
		var handle: GFAssetHandle = _get_asset_handle_value(_handle_refs[index].get_ref())
		if handle == null or handle.is_released():
			_handle_refs.remove_at(index)
		elif handle.path == path:
			handle.release_local_reference()
			_handle_refs.remove_at(index)


func _release_owner_handles(owner_id: int) -> void:
	for index: int in range(_handle_refs.size() - 1, -1, -1):
		var handle: GFAssetHandle = _get_asset_handle_value(_handle_refs[index].get_ref())
		if handle == null or handle.is_released():
			_handle_refs.remove_at(index)
		elif handle.get_owner_id() == owner_id:
			handle.release_local_reference()
			_handle_refs.remove_at(index)


func _release_owner_id(owner_id: int) -> int:
	if owner_id == 0:
		return 0

	var released_count: int = 0
	var paths: Array = _owner_reference_counts.keys()
	for path: String in paths:
		if not _owner_reference_counts.has(path):
			continue

		var owner_counts: Dictionary = GFVariantData.as_dictionary(_owner_reference_counts[path])
		if not owner_counts.has(owner_id):
			continue

		var count: int = _get_count_value(owner_counts, owner_id)
		released_count += count
		var remaining: int = _decrement_reference(path, owner_id, count)
		asset_handle_released.emit(path, remaining)

	_release_owner_handles(owner_id)
	_erase_dictionary_key(_owner_refs, owner_id)
	_erase_dictionary_key(_owner_release_connected, owner_id)
	return released_count


func _remove_path_from_groups(path: String) -> void:
	for group_id: Variant in _group_paths.keys():
		var paths: PackedStringArray = _get_packed_string_array_value(_group_paths[group_id])
		if not paths.has(path):
			continue
		paths.remove_at(paths.find(path))
		if paths.is_empty():
			_erase_dictionary_key(_group_paths, group_id)
			_erase_dictionary_key(_group_pin_counts, group_id)
		else:
			_group_paths[group_id] = paths


func _normalize_group_entry(entry: Variant) -> Dictionary:
	if entry is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(entry)
		return {
			"path": GFVariantData.get_option_string(data, "path", ""),
			"type_hint": GFVariantData.get_option_string(data, "type_hint", ""),
		}

	return {
		"path": GFVariantData.to_text(entry),
		"type_hint": "",
	}


func _finish_group_preload(group_id: StringName, report: Dictionary, on_completed: Callable) -> void:
	var paths: PackedStringArray = _get_report_paths(report, "paths")
	paths.sort()
	report["paths"] = paths

	var failed_paths: PackedStringArray = _get_report_paths(report, "failed_paths")
	failed_paths.sort()
	report["failed_paths"] = failed_paths

	var report_copy: Dictionary = report.duplicate(true)
	asset_group_preloaded.emit(group_id, report_copy)
	if on_completed.is_valid():
		on_completed.call(report_copy.duplicate(true))


func _is_resource_compatible(resource: Resource, type_hint: String) -> bool:
	if resource == null:
		return false
	if type_hint.is_empty() or resource.is_class(type_hint):
		return true

	var script: Script = _get_script_value(resource.get_script())
	while script != null:
		if GFVariantData.to_text(script.get_global_name()) == type_hint or script.resource_path == type_hint:
			return true
		script = script.get_base_script()
	return false


func _pending_type_hints_are_compatible(pending_type_hint: String, requested_type_hint: String) -> bool:
	return (
		pending_type_hint == requested_type_hint
		or pending_type_hint.is_empty()
		or requested_type_hint.is_empty()
	)


func _make_callback_entry(callback: Callable, type_hint: String) -> Dictionary:
	return {
		"callable": callback,
		"type_hint": type_hint,
	}


func _callback_entries_have_callable(callbacks: Array, callback: Callable) -> bool:
	for callback_entry: Variant in callbacks:
		var entry: Dictionary = GFVariantData.as_dictionary(callback_entry)
		if not entry.is_empty() and _get_callback_entry_callable(entry) == callback:
			return true
		if callback_entry is Callable and callback_entry == callback:
			return true
	return false


func _touch_cache(path: String) -> void:
	_cache_access_serial += 1
	_cache_access_order[path] = _cache_access_serial


func _evict_lru() -> void:
	while _cache.size() > max_cache_size and max_cache_size > 0:
		var oldest_path: String = _get_oldest_cached_path()
		if oldest_path.is_empty() or not _cache.has(oldest_path):
			return

		_cache_diagnostics.record_eviction(&"lru_capacity", oldest_path)
		_erase_dictionary_key(_cache, oldest_path)
		_erase_dictionary_key(_cache_access_order, oldest_path)


func _get_oldest_cached_path() -> String:
	var oldest_path: String = ""
	var oldest_access: int = 0
	var has_oldest: bool = false
	for path: String in _cache:
		if is_cache_pinned(path):
			continue
		var access: int = _get_count_value(_cache_access_order, path)
		if not has_oldest or access < oldest_access:
			oldest_path = path
			oldest_access = access
			has_oldest = true

	return oldest_path


func _request_threaded(path: String, type_hint: String) -> Error:
	return _THREADED_RESOURCE_LOAD_ADAPTER.request(path, type_hint)


func _get_threaded_status_with_progress(path: String, progress: Array) -> ResourceLoader.ThreadLoadStatus:
	return _THREADED_RESOURCE_LOAD_ADAPTER.get_status_with_progress(path, progress)


func _take_threaded_resource(path: String) -> Resource:
	return _THREADED_RESOURCE_LOAD_ADAPTER.take_resource(path)
