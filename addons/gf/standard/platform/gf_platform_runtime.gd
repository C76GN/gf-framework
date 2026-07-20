## GFPlatformRuntime: 平台 adapter 注册、路由与请求生命周期服务。
##
## 运行时允许多个外部 adapter 共存，但不会在同一契约存在多个候选时按注册顺序
## 猜测实现。项目必须通过 `set_contract_route` 显式消除歧义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 9.0.0
class_name GFPlatformRuntime
extends GFUtility


# --- 信号 ---

## Adapter 注册后发出。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter_id: Adapter ID。
signal adapter_registered(adapter_id: StringName)

## Adapter 注销后发出。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter_id: Adapter ID。
signal adapter_unregistered(adapter_id: StringName)

## Adapter 状态变化后转发。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter_id: Adapter ID。
## [br]
## @param previous_state: 变化前状态。
## [br]
## @param current_state: 变化后状态。
signal adapter_state_changed(adapter_id: StringName, previous_state: int, current_state: int)

## Adapter 上下文变化后转发。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter_id: Adapter ID。
## [br]
## @param context: 平台上下文副本。
signal context_changed(adapter_id: StringName, context: GFPlatformRuntimeContext)

## Adapter 生命周期事件转发。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter_id: Adapter ID。
## [br]
## @param event: 生命周期事件副本。
signal lifecycle_event(adapter_id: StringName, event: GFPlatformLifecycleEvent)

## 请求交给 adapter 前发出。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter_id: 已解析的 Adapter ID；路由失败时为空。
## [br]
## @param request: 请求副本。
signal request_started(adapter_id: StringName, request: GFPlatformBridgeRequest)

## 请求进入终态后发出。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter_id: 处理请求的 Adapter ID；路由失败时为空。
## [br]
## @param result: 请求终态结果副本。
signal request_completed(adapter_id: StringName, result: GFPlatformBridgeResult)


# --- 私有变量 ---

var _adapters: Dictionary = {}
var _contract_candidates: Dictionary = {}
var _contract_routes: Dictionary = {}
var _pending_requests: Dictionary = {}
var _request_serial: int = 0
var _clock: GFClock = null
var _clock_explicit: bool = false


# --- Godot 生命周期方法 ---

func _init(clock: GFClock = null) -> void:
	_clock = clock if clock != null else GFClock.new()
	_clock_explicit = clock != null
	tick_enabled = true
	ignore_pause = true
	ignore_time_scale = true


# --- GF 生命周期方法 ---

## 在架构中自动采用已注册 GFTimeProvider 的底层时钟。
##
## 通过构造函数或 `set_clock()` 显式注入后不会被自动覆盖。
## [br]
## @api public
## [br]
## @since 9.0.0
func ready() -> void:
	if _clock_explicit:
		return
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return
	var provider_value: Variant = architecture.get_utility(GFTimeProvider)
	if provider_value is GFTimeProvider:
		var provider: GFTimeProvider = provider_value
		var _clock_applied: bool = _apply_clock(provider.get_clock(), false)

## 推进 adapter callback pump 并处理请求超时。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param delta: 引擎原始帧间隔。
func tick(delta: float) -> void:
	for adapter_id: String in get_adapter_ids():
		var adapter: GFPlatformAdapter = _get_adapter(StringName(adapter_id))
		if adapter != null:
			adapter.poll(delta)
	_expire_requests(_clock.get_monotonic_msec())


## 取消全部请求、注销 adapter 并关闭平台资源。
## [br]
## @api public
## [br]
## @since 9.0.0
func dispose() -> void:
	for request_key: Variant in _pending_requests.keys().duplicate():
		var pending_handle: GFPlatformRequestHandle = _get_pending_handle(StringName(str(request_key)))
		if pending_handle != null:
			var _cancelled: bool = pending_handle.cancel(&"runtime_disposed")
	for adapter_id: String in get_adapter_ids():
		var _removed: bool = unregister_adapter(StringName(adapter_id), true)
	_contract_candidates.clear()
	_contract_routes.clear()
	_pending_requests.clear()


# --- 公共方法 ---

## 设置平台请求截止时间与结果耗时使用的统一单调时钟。
##
## 存在等待请求时拒绝替换，避免绝对截止值跨越两个时间域。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param clock: 新平台时钟。
## [br]
## @return 时钟合法且当前没有等待请求时返回 true。
func set_clock(clock: GFClock) -> bool:
	return _apply_clock(clock, true)


## 获取当前平台时钟。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 当前时钟。
func get_clock() -> GFClock:
	return _clock

## 注册平台 adapter。
##
## 注册只建立候选关系，不自动初始化 adapter，也不在冲突候选间建立隐式优先级。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter: 已配置的外部平台 adapter。
## [br]
## @return 注册成功返回 true。
func register_adapter(adapter: GFPlatformAdapter) -> bool:
	if adapter == null:
		return false
	var adapter_id: StringName = adapter.get_adapter_id()
	var contract_ids: PackedStringArray = adapter.get_contract_ids()
	if (
		adapter_id == &""
		or adapter.get_platform_id() == &""
		or contract_ids.is_empty()
		or _adapters.has(String(adapter_id))
		or adapter.get_state() in [GFPlatformAdapter.State.FAILED, GFPlatformAdapter.State.SHUTDOWN]
	):
		return false
	var _clock_set: bool = adapter._gf_set_clock(_clock)
	if not _clock_set:
		return false
	_adapters[String(adapter_id)] = adapter
	for contract_id: String in contract_ids:
		var candidates: PackedStringArray = _get_contract_candidates(StringName(contract_id))
		if not candidates.has(String(adapter_id)):
			var _appended: bool = candidates.append(String(adapter_id))
			candidates.sort()
		_contract_candidates[contract_id] = candidates
	_connect_adapter(adapter)
	adapter_registered.emit(adapter_id)
	return true


## 注销平台 adapter。
##
## 该 adapter 的等待请求会先进入 `adapter_unregistered` 取消终态，显式路由也会清除。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter_id: Adapter ID。
## [br]
## @param shutdown_adapter: 是否关闭 adapter 底层资源。
## [br]
## @return 找到并注销返回 true。
func unregister_adapter(adapter_id: StringName, shutdown_adapter: bool = true) -> bool:
	var adapter: GFPlatformAdapter = _get_adapter(adapter_id)
	if adapter == null:
		return false
	_cancel_adapter_requests(adapter_id, &"adapter_unregistered")
	_disconnect_adapter(adapter)
	var _erased: bool = _adapters.erase(String(adapter_id))
	for contract_id: String in adapter.get_contract_ids():
		var candidates: PackedStringArray = _get_contract_candidates(StringName(contract_id))
		if candidates.has(String(adapter_id)):
			candidates.remove_at(candidates.find(String(adapter_id)))
		if candidates.is_empty():
			var _candidates_erased: bool = _contract_candidates.erase(contract_id)
		else:
			_contract_candidates[contract_id] = candidates
		if GFVariantData.get_option_string_name(_contract_routes, contract_id) == adapter_id:
			var _route_erased: bool = _contract_routes.erase(contract_id)
	if shutdown_adapter:
		adapter.shutdown()
	adapter_unregistered.emit(adapter_id)
	return true


## 初始化指定 adapter。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter_id: Adapter ID。
## [br]
## @param options: Adapter 定义的初始化选项。
## [br]
## @schema options: Dictionary adapter-defined initialization options.
## [br]
## @return 初始化完成源；adapter 不存在时立即失败。
func initialize_adapter(adapter_id: StringName, options: Dictionary = {}) -> GFAsyncCompletion:
	var adapter: GFPlatformAdapter = _get_adapter(adapter_id)
	if adapter != null:
		return adapter.initialize(options)
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	var _failed: bool = completion.fail("Platform adapter is not registered.", {"adapter_id": adapter_id})
	return completion


## 为桥接契约设置显式 adapter 路由。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param contract_id: 桥接契约 ID。
## [br]
## @param adapter_id: 必须声明支持该契约的 Adapter ID。
## [br]
## @return 路由有效并写入成功返回 true。
func set_contract_route(contract_id: StringName, adapter_id: StringName) -> bool:
	var normalized_contract: StringName = StringName(String(contract_id).strip_edges())
	var adapter: GFPlatformAdapter = _get_adapter(adapter_id)
	if normalized_contract == &"" or adapter == null or not adapter.supports_contract(normalized_contract):
		return false
	_contract_routes[String(normalized_contract)] = adapter_id
	return true


## 清除桥接契约显式路由。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param contract_id: 桥接契约 ID。
## [br]
## @return 找到并清除返回 true。
func clear_contract_route(contract_id: StringName) -> bool:
	return _contract_routes.erase(String(contract_id))


## 获取桥接契约当前显式路由。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param contract_id: 桥接契约 ID。
## [br]
## @return Adapter ID；未设置返回空。
func get_contract_route(contract_id: StringName) -> StringName:
	return GFVariantData.get_option_string_name(_contract_routes, String(contract_id))


## 提交完整平台桥接请求。
##
## `adapter_id` 非空时优先使用指定 adapter；否则使用显式路由；只有恰好一个
## 候选时才允许自动解析。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param request: 完整桥接请求。
## [br]
## @param adapter_id: 可选显式 Adapter ID。
## [br]
## @return 一次性请求句柄；所有输入和路由失败也返回终态句柄。
func invoke(
	request: GFPlatformBridgeRequest,
	adapter_id: StringName = &""
) -> GFPlatformRequestHandle:
	if request == null or request.is_empty():
		return _make_rejected_handle(request, &"invalid_request", "Platform bridge request is incomplete.")
	if _pending_requests.has(String(request.request_id)):
		return _make_rejected_handle(request, &"duplicate_request_id", "Platform request ID is already pending.")
	var resolution: Dictionary = _resolve_adapter(request.contract_id, adapter_id)
	var resolved_adapter_id: StringName = GFVariantData.get_option_string_name(resolution, "adapter_id")
	request_started.emit(resolved_adapter_id, request.duplicate_request())
	var routing_error: StringName = GFVariantData.get_option_string_name(resolution, "error")
	if routing_error != &"":
		var rejected: GFPlatformRequestHandle = _make_rejected_handle(
			request,
			routing_error,
			GFVariantData.get_option_string(resolution, "message")
		)
		_emit_completed_handle(resolved_adapter_id, rejected)
		return rejected
	var adapter: GFPlatformAdapter = _get_adapter(resolved_adapter_id)
	if adapter == null:
		var missing: GFPlatformRequestHandle = _make_rejected_handle(
			request,
			&"adapter_not_found",
			"Resolved platform adapter is no longer registered."
		)
		_emit_completed_handle(resolved_adapter_id, missing)
		return missing
	var handle: GFPlatformRequestHandle = adapter.invoke(request)
	if handle.is_pending():
		_track_pending_handle(resolved_adapter_id, request, handle)
	else:
		_emit_completed_handle(resolved_adapter_id, handle)
	return handle


## 构建并提交平台桥接请求。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param contract_id: 桥接契约 ID。
## [br]
## @param method_id: 方法 ID。
## [br]
## @param payload: Adapter 定义的请求载荷。
## [br]
## @param options: 可包含 adapter_id、request_id、timeout_msec 和 metadata。
## [br]
## @schema payload: Dictionary adapter-defined request payload.
## [br]
## @schema options: Dictionary with optional adapter_id, request_id, timeout_msec, and metadata fields.
## [br]
## @return 一次性请求句柄。
func invoke_contract(
	contract_id: StringName,
	method_id: StringName,
	payload: Dictionary = {},
	options: Dictionary = {}
) -> GFPlatformRequestHandle:
	var request_id: StringName = GFVariantData.get_option_string_name(options, "request_id")
	if request_id == &"":
		_request_serial += 1
		request_id = StringName("gf_platform_%d" % _request_serial)
	var request: GFPlatformBridgeRequest = GFPlatformBridgeRequest.new().configure(
		request_id,
		contract_id,
		method_id,
		payload,
		GFVariantData.get_option_int(options, "timeout_msec"),
		GFVariantData.get_option_dictionary(options, "metadata")
	)
	return invoke(request, GFVariantData.get_option_string_name(options, "adapter_id"))


## 取消等待中的请求。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param request_id: 请求 ID。
## [br]
## @param reason: 取消原因。
## [br]
## @return 找到等待请求并首次取消返回 true。
func cancel_request(request_id: StringName, reason: StringName = &"cancelled") -> bool:
	var handle: GFPlatformRequestHandle = _get_pending_handle(request_id)
	return handle != null and handle.cancel(reason)


## 获取注册的 Adapter ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 排序后的 Adapter ID。
func get_adapter_ids() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in _adapters.keys():
		var _appended: bool = result.append(str(key))
	result.sort()
	return result


## 获取 adapter 上下文副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter_id: Adapter ID。
## [br]
## @return 上下文副本；adapter 不存在时返回 null。
func get_context(adapter_id: StringName) -> GFPlatformRuntimeContext:
	var adapter: GFPlatformAdapter = _get_adapter(adapter_id)
	return adapter.get_context() if adapter != null else null


## 检查一个或任意已就绪 adapter 是否声明能力。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param capability_id: 能力 ID。
## [br]
## @param adapter_id: 指定 Adapter ID；为空时查询全部 READY adapter。
## [br]
## @return 能力存在返回 true。
func has_capability(capability_id: StringName, adapter_id: StringName = &"") -> bool:
	if adapter_id != &"":
		var selected: GFPlatformAdapter = _get_adapter(adapter_id)
		return selected != null and selected.is_ready() and selected.get_context().has_capability(capability_id)
	for candidate_id: String in get_adapter_ids():
		var candidate: GFPlatformAdapter = _get_adapter(StringName(candidate_id))
		if candidate != null and candidate.is_ready() and candidate.get_context().has_capability(capability_id):
			return true
	return false


## 获取运行时调试快照。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return Adapter、路由和等待请求摘要。
## [br]
## @schema return: Dictionary with adapters, contract_routes, and pending_request_count.
func get_debug_snapshot() -> Dictionary:
	var adapter_snapshots: Array[Dictionary] = []
	for adapter_id: String in get_adapter_ids():
		var adapter: GFPlatformAdapter = _get_adapter(StringName(adapter_id))
		if adapter != null:
			adapter_snapshots.append(adapter.get_debug_snapshot())
	return {
		"adapters": adapter_snapshots,
		"contract_routes": _contract_routes.duplicate(true),
		"pending_request_count": _pending_requests.size(),
	}


# --- 私有/辅助方法 ---

func _get_adapter(adapter_id: StringName) -> GFPlatformAdapter:
	if not _adapters.has(String(adapter_id)):
		return null
	var value: Variant = _adapters[String(adapter_id)]
	if value is GFPlatformAdapter:
		var adapter: GFPlatformAdapter = value
		return adapter
	return null


func _get_contract_candidates(contract_id: StringName) -> PackedStringArray:
	if not _contract_candidates.has(String(contract_id)):
		return PackedStringArray()
	var value: Variant = _contract_candidates[String(contract_id)]
	if value is PackedStringArray:
		var candidates: PackedStringArray = value
		return candidates.duplicate()
	return PackedStringArray()


func _resolve_adapter(contract_id: StringName, explicit_adapter_id: StringName) -> Dictionary:
	var normalized_contract: StringName = StringName(String(contract_id).strip_edges())
	if normalized_contract == &"":
		return _routing_failure(&"invalid_contract", "Platform contract ID is empty.")
	if explicit_adapter_id != &"":
		var explicit_adapter: GFPlatformAdapter = _get_adapter(explicit_adapter_id)
		if explicit_adapter == null:
			return _routing_failure(&"adapter_not_found", "Explicit platform adapter is not registered.", explicit_adapter_id)
		if not explicit_adapter.supports_contract(normalized_contract):
			return _routing_failure(&"unsupported_contract", "Explicit platform adapter does not support the contract.", explicit_adapter_id)
		return {"adapter_id": explicit_adapter_id, "error": &"", "message": ""}
	var routed_adapter_id: StringName = get_contract_route(normalized_contract)
	if routed_adapter_id != &"":
		var routed_adapter: GFPlatformAdapter = _get_adapter(routed_adapter_id)
		if routed_adapter == null or not routed_adapter.supports_contract(normalized_contract):
			return _routing_failure(&"stale_contract_route", "Configured platform route is no longer valid.", routed_adapter_id)
		return {"adapter_id": routed_adapter_id, "error": &"", "message": ""}
	var candidates: PackedStringArray = _get_contract_candidates(normalized_contract)
	if candidates.is_empty():
		return _routing_failure(&"unbound_contract", "No platform adapter supports the requested contract.")
	if candidates.size() > 1:
		return _routing_failure(
			&"ambiguous_adapter",
			"Multiple platform adapters support the contract; set an explicit route."
		)
	return {"adapter_id": StringName(candidates[0]), "error": &"", "message": ""}


func _routing_failure(error: StringName, message: String, adapter_id: StringName = &"") -> Dictionary:
	return {"adapter_id": adapter_id, "error": error, "message": message}


func _make_rejected_handle(
	request: GFPlatformBridgeRequest,
	status: StringName,
	error: String
) -> GFPlatformRequestHandle:
	var handle: GFPlatformRequestHandle = GFPlatformRequestHandle.new()
	var _rejected: bool = handle._gf_reject(request, status, error, _clock)
	return handle


func _track_pending_handle(
	adapter_id: StringName,
	request: GFPlatformBridgeRequest,
	handle: GFPlatformRequestHandle
) -> void:
	var deadline_msec: int = 0
	if request.timeout_msec > 0:
		deadline_msec = _clock.get_monotonic_msec() + request.timeout_msec
	_pending_requests[String(request.request_id)] = {
		"adapter_id": adapter_id,
		"deadline_msec": deadline_msec,
		"handle": handle,
	}
	var completed_callback: Callable = _on_request_handle_completed.bind(adapter_id, request.request_id)
	var connect_error: Error = handle.completed.connect(
		completed_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		var _failed: bool = handle._gf_fail(&"signal_connection_failed", "Platform runtime could not track request completion.")
		var _erased: bool = _pending_requests.erase(String(request.request_id))
		_emit_completed_handle(adapter_id, handle)


func _get_pending_handle(request_id: StringName) -> GFPlatformRequestHandle:
	if not _pending_requests.has(String(request_id)):
		return null
	var record_value: Variant = _pending_requests[String(request_id)]
	if not (record_value is Dictionary):
		return null
	var record: Dictionary = record_value
	var handle_value: Variant = GFVariantData.get_option_value(record, "handle")
	if handle_value is GFPlatformRequestHandle:
		var handle: GFPlatformRequestHandle = handle_value
		return handle
	return null


func _expire_requests(now_msec: int) -> void:
	for request_key: Variant in _pending_requests.keys().duplicate():
		if not _pending_requests.has(request_key):
			continue
		var record_value: Variant = _pending_requests[request_key]
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var deadline_msec: int = GFVariantData.get_option_int(record, "deadline_msec")
		if deadline_msec <= 0 or now_msec < deadline_msec:
			continue
		var handle_value: Variant = GFVariantData.get_option_value(record, "handle")
		if handle_value is GFPlatformRequestHandle:
			var handle: GFPlatformRequestHandle = handle_value
			var _timed_out: bool = handle._gf_timeout()


func _apply_clock(clock: GFClock, explicit: bool) -> bool:
	if clock == null or not _pending_requests.is_empty():
		return false
	_clock = clock
	if explicit:
		_clock_explicit = true
	for adapter_id: String in get_adapter_ids():
		var adapter: GFPlatformAdapter = _get_adapter(StringName(adapter_id))
		if adapter != null:
			var _clock_set: bool = adapter._gf_set_clock(_clock)
	return true


func _cancel_adapter_requests(adapter_id: StringName, reason: StringName) -> void:
	for request_key: Variant in _pending_requests.keys().duplicate():
		if not _pending_requests.has(request_key):
			continue
		var record_value: Variant = _pending_requests[request_key]
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		if GFVariantData.get_option_string_name(record, "adapter_id") != adapter_id:
			continue
		var handle_value: Variant = GFVariantData.get_option_value(record, "handle")
		if handle_value is GFPlatformRequestHandle:
			var handle: GFPlatformRequestHandle = handle_value
			var _cancelled: bool = handle.cancel(reason)


func _connect_adapter(adapter: GFPlatformAdapter) -> void:
	var adapter_id: StringName = adapter.get_adapter_id()
	var _state_connected: Error = adapter.state_changed.connect(
		_on_adapter_state_changed.bind(adapter_id)
	) as Error
	var _context_connected: Error = adapter.context_changed.connect(
		_on_adapter_context_changed.bind(adapter_id)
	) as Error
	var _lifecycle_connected: Error = adapter.lifecycle_event.connect(
		_on_adapter_lifecycle_event.bind(adapter_id)
	) as Error


func _disconnect_adapter(adapter: GFPlatformAdapter) -> void:
	var adapter_id: StringName = adapter.get_adapter_id()
	var state_callback: Callable = _on_adapter_state_changed.bind(adapter_id)
	var context_callback: Callable = _on_adapter_context_changed.bind(adapter_id)
	var lifecycle_callback: Callable = _on_adapter_lifecycle_event.bind(adapter_id)
	if adapter.state_changed.is_connected(state_callback):
		adapter.state_changed.disconnect(state_callback)
	if adapter.context_changed.is_connected(context_callback):
		adapter.context_changed.disconnect(context_callback)
	if adapter.lifecycle_event.is_connected(lifecycle_callback):
		adapter.lifecycle_event.disconnect(lifecycle_callback)


func _emit_completed_handle(adapter_id: StringName, handle: GFPlatformRequestHandle) -> void:
	var result: GFPlatformBridgeResult = handle.get_result()
	if result != null:
		request_completed.emit(adapter_id, result)


func _on_request_handle_completed(
	result: GFPlatformBridgeResult,
	adapter_id: StringName,
	request_id: StringName
) -> void:
	var _erased: bool = _pending_requests.erase(String(request_id))
	request_completed.emit(adapter_id, result.duplicate_result())


func _on_adapter_state_changed(
	previous_state: int,
	current_state: int,
	adapter_id: StringName
) -> void:
	adapter_state_changed.emit(adapter_id, previous_state, current_state)


func _on_adapter_context_changed(
	context: GFPlatformRuntimeContext,
	adapter_id: StringName
) -> void:
	context_changed.emit(adapter_id, context.duplicate_context())


func _on_adapter_lifecycle_event(
	event: GFPlatformLifecycleEvent,
	adapter_id: StringName
) -> void:
	lifecycle_event.emit(adapter_id, event.duplicate_event())
