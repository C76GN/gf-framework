## GFPlatformAdapter: 外部平台 adapter 协议。
##
## Steam、微信小游戏、主机平台或自建平台实现应继承该类型，把具体 SDK 回调
## 转换为 GF 的上下文、生命周期事件和桥接结果。该基类不依赖任何平台 SDK。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 9.0.0
class_name GFPlatformAdapter
extends RefCounted


# --- 信号 ---

## Adapter 状态变化后发出。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param previous_state: 变化前状态。
## [br]
## @param current_state: 变化后状态。
signal state_changed(previous_state: State, current_state: State)

## 平台运行时上下文变化后发出。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param context: 新上下文副本。
signal context_changed(context: GFPlatformRuntimeContext)

## 收到平台生命周期事件后发出。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param event: 生命周期事件副本。
signal lifecycle_event(event: GFPlatformLifecycleEvent)

## 收到平台激活入口后发出。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param intent: 已规范化的激活意图副本。
signal activation_intent(intent: GFPlatformActivationIntent)


# --- 枚举 ---

## Adapter 生命周期状态。
## [br]
## @api public
## [br]
## @since 9.0.0
enum State {
	## 尚未初始化。
	CREATED,
	## 正在执行 adapter 初始化。
	INITIALIZING,
	## 可接受平台请求。
	READY,
	## 初始化失败。
	FAILED,
	## 已关闭且不可重新使用。
	SHUTDOWN,
}


# --- 私有变量 ---

var _adapter_id: StringName = &""
var _platform_id: StringName = &""
var _contract_ids: PackedStringArray = PackedStringArray()
var _state: State = State.CREATED
var _context: GFPlatformRuntimeContext = GFPlatformRuntimeContext.new()
var _initialization: GFAsyncCompletion = null
var _lifecycle_sequence: int = 0
var _clock: GFClock = GFClock.new()
var _contract_descriptors: Dictionary = {}
var _active_handles: Dictionary = {}
var _active_method_counts: Dictionary = {}


# --- 公共方法 ---

## 配置 adapter 身份和支持的桥接契约。
##
## 配置只允许在 CREATED 状态执行，防止运行期间改变路由身份。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param adapter_id: Adapter 稳定标识。
## [br]
## @param platform_id: 平台稳定标识。
## [br]
## @param contract_ids: 支持的桥接契约 ID。
## [br]
## @param contract_descriptors: 平台契约描述符；必须与 contract_ids 一一对应。
## [br]
## @schema contract_descriptors: Array[GFPlatformContractDescriptor] complete contract descriptors.
## [br]
## @param initial_context: 可选初始上下文。
## [br]
## @return 配置成功返回 true。
func configure(
	adapter_id: StringName,
	platform_id: StringName,
	contract_ids: PackedStringArray,
	contract_descriptors: Array[GFPlatformContractDescriptor],
	initial_context: GFPlatformRuntimeContext = null
) -> bool:
	if _state != State.CREATED:
		return false
	var normalized_adapter_id: StringName = StringName(String(adapter_id).strip_edges())
	var normalized_platform_id: StringName = StringName(String(platform_id).strip_edges())
	var normalized_contracts: PackedStringArray = _normalize_string_set(contract_ids)
	if normalized_adapter_id == &"" or normalized_platform_id == &"" or normalized_contracts.is_empty():
		return false
	_adapter_id = normalized_adapter_id
	_platform_id = normalized_platform_id
	_contract_ids = normalized_contracts
	_context = GFPlatformRuntimeContext.new().configure(_platform_id, {"adapter_id": _adapter_id})
	if not _apply_contract_descriptors(contract_descriptors):
		_reset_configuration()
		return false
	if initial_context != null and not _apply_context(initial_context):
		_reset_configuration()
		return false
	return true


## 获取 adapter ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return Adapter ID。
func get_adapter_id() -> StringName:
	return _adapter_id


## 获取平台 ID。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 平台 ID。
func get_platform_id() -> StringName:
	return _platform_id


## 获取支持的桥接契约 ID 副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 排序去重后的契约 ID。
func get_contract_ids() -> PackedStringArray:
	return _contract_ids.duplicate()


## 获取声明的契约描述符副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 按 contract_id 排序的描述符副本。
## [br]
## @schema return: Array[GFPlatformContractDescriptor] declared platform contracts.
func get_contract_descriptors() -> Array[GFPlatformContractDescriptor]:
	var result: Array[GFPlatformContractDescriptor] = []
	var descriptor_ids: PackedStringArray = PackedStringArray()
	for key: Variant in _contract_descriptors.keys():
		var _appended: bool = descriptor_ids.append(str(key))
	descriptor_ids.sort()
	for descriptor_id: String in descriptor_ids:
		var descriptor: GFPlatformContractDescriptor = _get_contract_descriptor_internal(
			StringName(descriptor_id)
		)
		if descriptor != null:
			result.append(descriptor.duplicate_descriptor())
	return result


## 获取一个契约描述符副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param contract_id: 契约 ID。
## [br]
## @return 找到时返回描述符副本，否则返回 null。
func get_contract_descriptor(contract_id: StringName) -> GFPlatformContractDescriptor:
	var descriptor: GFPlatformContractDescriptor = _get_contract_descriptor_internal(contract_id)
	return descriptor.duplicate_descriptor() if descriptor != null else null


## 检查 adapter 是否支持桥接契约。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param contract_id: 桥接契约 ID。
## [br]
## @return 已声明支持时返回 true。
func supports_contract(contract_id: StringName) -> bool:
	return _contract_ids.has(String(contract_id).strip_edges())


## 获取当前状态。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return Adapter 状态。
func get_state() -> State:
	return _state


## 检查 adapter 是否可接受请求。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return READY 状态返回 true。
func is_ready() -> bool:
	return _state == State.READY


## 初始化 adapter。
##
## 同一次初始化期间重复调用会返回同一个 completion；READY 状态返回立即成功的
## completion。FAILED 或 SHUTDOWN 状态不会隐式重试。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param options: Adapter 定义的初始化选项。
## [br]
## @schema options: Dictionary adapter-defined initialization options.
## [br]
## @return 初始化完成源，成功结果为 `GFPlatformRuntimeContext`。
func initialize(options: Dictionary = {}) -> GFAsyncCompletion:
	if _state == State.READY:
		var ready_completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _ready_completed: bool = ready_completion.succeed(get_context())
		return ready_completion
	if _state == State.INITIALIZING and _initialization != null:
		return _initialization
	if _state in [State.FAILED, State.SHUTDOWN] or not _is_configured():
		var blocked_completion: GFAsyncCompletion = GFAsyncCompletion.new()
		var _blocked_completed: bool = blocked_completion.fail("Platform adapter cannot be initialized in its current state.")
		return blocked_completion
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	_initialization = completion
	_set_state(State.INITIALIZING)
	_initialize(options.duplicate(true))
	return completion


## 获取运行时上下文副本。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return 平台运行时上下文副本。
func get_context() -> GFPlatformRuntimeContext:
	return _context.duplicate_context()


## 发起桥接请求。
##
## 该入口统一做状态、请求身份和契约支持检查，具体 adapter 只重写 `_dispatch`。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param request: 平台桥接请求。
## [br]
## @return 一次性请求句柄。
func invoke(request: GFPlatformBridgeRequest) -> GFPlatformRequestHandle:
	return invoke_from_runtime(request, -1)


## 推进需要 callback pump 的平台 SDK。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @param delta: 未受游戏暂停和时间缩放影响的帧间隔。
func poll(delta: float) -> void:
	if _state in [State.INITIALIZING, State.READY]:
		_poll(maxf(delta, 0.0))


## 关闭 adapter 并释放平台资源。
##
## SHUTDOWN 为终态；需要重新连接时应创建新 adapter 实例。
## [br]
## @api public
## [br]
## @since 9.0.0
func shutdown() -> void:
	if _state == State.SHUTDOWN:
		return
	_set_state(State.SHUTDOWN)
	if _initialization != null and _initialization.is_pending():
		var _cancelled: bool = _initialization.cancel(&"adapter_shutdown")
	for request_key: Variant in _active_handles.keys().duplicate():
		var active_handle: GFPlatformRequestHandle = _get_active_handle(
			StringName(str(request_key))
		)
		if active_handle != null:
			var _request_cancelled: bool = active_handle.cancel(&"adapter_shutdown")
	_shutdown()
	_active_handles.clear()
	_active_method_counts.clear()


## 获取 adapter 调试快照。
## [br]
## @api public
## [br]
## @since 9.0.0
## [br]
## @return Adapter 身份、状态、契约与脱敏上下文摘要。
## [br]
## @schema return: Dictionary with adapter identity, state, contracts, and redacted context summary.
func get_debug_snapshot() -> Dictionary:
	var descriptor_entries: Array[Dictionary] = []
	for descriptor: GFPlatformContractDescriptor in get_contract_descriptors():
		descriptor_entries.append(descriptor.to_dict())
	return {
		"adapter_id": _adapter_id,
		"platform_id": _platform_id,
		"state": _state,
		"state_name": State.keys()[_state],
		"contract_ids": _contract_ids.duplicate(),
		"contract_descriptors": descriptor_entries,
		"active_request_count": _active_handles.size(),
		"context": _make_context_debug_summary(),
	}


# --- 可重写钩子 / 虚方法 ---

## 执行平台初始化。
##
## 异步实现应在回调中调用 `_complete_initialization` 或 `_fail_initialization`；
## 基类实现立即使用当前上下文完成。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param _options: Adapter 初始化选项。
## [br]
## @schema _options: Dictionary adapter-defined initialization options.
func _initialize(_options: Dictionary) -> void:
	var _completed: bool = _complete_initialization(_context)


## 派发平台请求。
##
## 实现可同步或异步调用 `_succeed_request` / `_fail_request`。返回 false 表示请求
## 未被接受，基类会生成 dispatch_rejected 终态。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param _request: 请求副本。
## [br]
## @param _handle: 由基类拥有的请求句柄。
## [br]
## @return 请求被接受时返回 true。
func _dispatch(_request: GFPlatformBridgeRequest, _handle: GFPlatformRequestHandle) -> bool:
	return false


## 推进底层平台 callback pump。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param _delta: 未缩放帧间隔。
func _poll(_delta: float) -> void:
	pass


## 处理请求取消或超时通知。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param _handle: 已进入取消或超时终态的句柄。
## [br]
## @param _reason: 取消原因。
func _cancel_request(_handle: GFPlatformRequestHandle, _reason: StringName) -> void:
	pass


## 确认底层 Provider 调用已经停止并释放请求租约。
##
## 本地取消和超时只结束调用方 Handle，不代表不可取消或异步取消的 SDK 调用已经
## 停止。Adapter 应在 Provider 确认取消后调用本方法；迟到成功或失败回调通过
## `_succeed_request` / `_fail_request` 也会自动释放租约。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param handle: 已停止底层工作的请求句柄。
## [br]
## @return 当前 Adapter 仍持有该请求租约并已释放时返回 true。
func _release_request(handle: GFPlatformRequestHandle) -> bool:
	if handle == null:
		return false
	var request: GFPlatformBridgeRequest = handle.get_request()
	if request == null:
		return false
	var active_handle: GFPlatformRequestHandle = _get_active_handle(request.request_id)
	if active_handle != handle:
		return false
	var _erased: bool = _active_handles.erase(String(request.request_id))
	var method_key: String = _make_method_key(request.contract_id, request.method_id)
	var active_count: int = GFVariantData.get_option_int(_active_method_counts, method_key)
	if active_count <= 1:
		var _count_erased: bool = _active_method_counts.erase(method_key)
	else:
		_active_method_counts[method_key] = active_count - 1
	return true


## 释放底层平台资源。
## [br]
## @api protected
## [br]
## @since 9.0.0
func _shutdown() -> void:
	pass


## 完成 adapter 初始化。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param context: 已验证的平台上下文。
## [br]
## @return 首次成功完成返回 true。
func _complete_initialization(context: GFPlatformRuntimeContext) -> bool:
	if _state != State.INITIALIZING or _initialization == null or not _apply_context(context):
		return false
	_set_state(State.READY)
	var completed: bool = _initialization.succeed(get_context())
	_initialization = null
	return completed


## 标记 adapter 初始化失败。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param error: 失败说明。
## [br]
## @param metadata: Adapter 定义的失败元数据。
## [br]
## @schema metadata: Dictionary adapter-defined initialization failure metadata.
## [br]
## @return 首次失败完成返回 true。
func _fail_initialization(error: String, metadata: Dictionary = {}) -> bool:
	if _state != State.INITIALIZING or _initialization == null:
		return false
	_set_state(State.FAILED)
	var completed: bool = _initialization.fail(error.strip_edges(), metadata)
	_initialization = null
	return completed


## 发布更新后的平台上下文。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param context: 新上下文。
## [br]
## @return 身份匹配且发布成功返回 true。
func _publish_context(context: GFPlatformRuntimeContext) -> bool:
	if not _apply_context(context):
		return false
	context_changed.emit(get_context())
	return true


## 发布平台生命周期事件。
##
## 基类会覆盖 adapter 提供的 sequence，确保每个 adapter 的事件严格单调。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param event: 生命周期事件。
## [br]
## @return 事件有效并已发布时返回 true。
func _publish_lifecycle_event(event: GFPlatformLifecycleEvent) -> bool:
	if event == null or event.event_type == &"":
		return false
	var copy: GFPlatformLifecycleEvent = event.duplicate_event()
	if copy.platform_id == &"":
		copy.platform_id = _platform_id
	if copy.platform_id != _platform_id:
		return false
	_lifecycle_sequence += 1
	copy.sequence = _lifecycle_sequence
	if copy.timestamp_msec <= 0:
		copy.timestamp_msec = _clock.get_monotonic_msec()
	lifecycle_event.emit(copy)
	return true


## 发布平台激活意图。
##
## 基类补齐并校验 adapter/platform 身份和单调时间戳。Intent ID 必须由 adapter
## 根据平台事件生成，确保重放回调可以去重。
## [br]
## @api protected
## [br]
## @since 10.0.0
## [br]
## @param intent: 平台激活意图。
## [br]
## @return 意图有效并已发布时返回 true。
func _publish_activation_intent(intent: GFPlatformActivationIntent) -> bool:
	if intent == null or intent.is_empty():
		return false
	var copy: GFPlatformActivationIntent = intent.duplicate_intent()
	if copy.platform_id == &"":
		copy.platform_id = _platform_id
	if copy.adapter_id == &"":
		copy.adapter_id = _adapter_id
	if copy.platform_id != _platform_id or copy.adapter_id != _adapter_id:
		return false
	if copy.timestamp_msec <= 0:
		copy.timestamp_msec = _clock.get_monotonic_msec()
	activation_intent.emit(copy)
	return true


## 以成功结果完成请求。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param handle: 待完成句柄。
## [br]
## @param value: Adapter 返回值。
## [br]
## @param status: 成功状态。
## [br]
## @param metadata: Adapter 结果元数据。
## [br]
## @schema value: Adapter-defined result value.
## [br]
## @schema metadata: Dictionary adapter-defined result metadata.
## [br]
## @return 首次完成成功返回 true。
func _succeed_request(
	handle: GFPlatformRequestHandle,
	value: Variant = null,
	status: StringName = &"ok",
	metadata: Dictionary = {}
) -> bool:
	if handle == null or not handle.is_pending():
		return false
	var request: GFPlatformBridgeRequest = handle.get_request()
	var method: GFPlatformContractMethodDescriptor = _get_method_descriptor(request)
	if method != null:
		var result_report: GFValidationReport = method.validate_result(value)
		if not result_report.is_ok():
			var invalid_completed: bool = handle.fail_from_platform_layer(
				&"invalid_adapter_result",
				"Platform adapter result does not satisfy its declared contract.",
				{"validation": result_report.to_dict()}
			)
			var _invalid_released: bool = _release_request(handle)
			return invalid_completed
	var completed: bool = handle.succeed_from_platform_layer(value, status, metadata)
	var _released: bool = _release_request(handle)
	return completed


## 以失败结果完成请求。
## [br]
## @api protected
## [br]
## @since 9.0.0
## [br]
## @param handle: 待完成句柄。
## [br]
## @param status: 稳定失败状态。
## [br]
## @param error: 失败说明。
## [br]
## @param metadata: Adapter 失败元数据。
## [br]
## @schema metadata: Dictionary adapter-defined failure metadata.
## [br]
## @return 首次完成成功返回 true。
func _fail_request(
	handle: GFPlatformRequestHandle,
	status: StringName,
	error: String,
	metadata: Dictionary = {}
) -> bool:
	if handle == null:
		return false
	var completed: bool = handle.fail_from_platform_layer(
		status,
		error.strip_edges(),
		metadata
	)
	var _released: bool = _release_request(handle)
	return completed


# --- 层内方法 ---

## 使用 Runtime 已捕获的单调起始时间发起桥接请求。
## [br]
## @api layer_internal
## [br]
## @layer standard/platform
## [br]
## @since 10.0.0
## [br]
## @param request: 平台桥接请求。
## [br]
## @param started_at_msec: Runtime 在开始信号前捕获的同时钟域起始时间。
## [br]
## @return 一次性请求句柄。
func invoke_from_runtime(
	request: GFPlatformBridgeRequest,
	started_at_msec: int
) -> GFPlatformRequestHandle:
	var handle: GFPlatformRequestHandle = GFPlatformRequestHandle.new()
	if (
		request == null
		or not handle.configure_from_platform_layer(request, _clock, started_at_msec)
	):
		var _invalid: bool = handle.reject_from_platform_layer(
			request,
			&"invalid_request",
			"Platform bridge request is incomplete.",
			_clock
		)
		return handle
	var cancel_callback: Callable = _on_handle_cancel_requested.bind(handle)
	var _cancel_connected: Error = handle.cancel_requested.connect(
		cancel_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if not is_ready():
		var _not_ready: bool = _fail_request(
			handle,
			&"adapter_not_ready",
			"Platform adapter is not ready."
		)
		return handle
	if not supports_contract(request.contract_id):
		var _unsupported: bool = _fail_request(
			handle,
			&"unsupported_contract",
			"Platform adapter does not support the requested contract."
		)
		return handle
	if _active_handles.has(String(request.request_id)):
		var _duplicate: bool = _fail_request(
			handle,
			&"duplicate_request_id",
			"Platform request ID is already pending in this adapter."
		)
		return handle
	var method: GFPlatformContractMethodDescriptor = _get_method_descriptor(request)
	if _get_contract_descriptor_internal(request.contract_id) != null and method == null:
		var _unknown_method: bool = _fail_request(
			handle,
			&"unknown_contract_method",
			"Platform contract does not declare the requested method."
		)
		return handle
	if method != null:
		var request_report: GFValidationReport = method.validate_request(
			request.payload,
			_context.capabilities
		)
		if not request_report.is_ok():
			var _invalid_contract_request: bool = _fail_request(
				handle,
				&"invalid_contract_request",
				"Platform request does not satisfy its declared contract.",
				{"validation": request_report.to_dict()}
			)
			return handle
		var method_key: String = _make_method_key(request.contract_id, request.method_id)
		if (
			method.max_concurrent_requests > 0
			and GFVariantData.get_option_int(_active_method_counts, method_key)
				>= method.max_concurrent_requests
		):
			var _concurrency_rejected: bool = _fail_request(
				handle,
				&"contract_concurrency_exceeded",
				"Platform contract method concurrency limit is reached."
			)
			return handle
	_track_handle(request, handle)
	var accepted: bool = _dispatch(request.duplicate_request(), handle)
	if not accepted and handle.is_pending():
		var _rejected: bool = _fail_request(
			handle,
			&"dispatch_rejected",
			"Platform adapter rejected the request."
		)
	return handle


## 注入 Runtime 统一单调时钟。
## [br]
## @api layer_internal
## [br]
## @layer standard/platform
## [br]
## @since 10.0.0
## [br]
## @param clock: Runtime 使用的时钟。
## [br]
## @return 时钟有效、当前没有活跃 Provider 请求租约并已采用时返回 true。
func set_runtime_clock(clock: GFClock) -> bool:
	if clock == null or not _active_handles.is_empty():
		return false
	_clock = clock
	return true


# --- 私有/辅助方法 ---

func _make_context_debug_summary() -> Dictionary:
	var storage_root_ids: PackedStringArray = PackedStringArray()
	for key: Variant in _context.storage_roots.keys():
		var _appended: bool = storage_root_ids.append(str(key))
	storage_root_ids.sort()
	return {
		"platform_id": _context.platform_id,
		"adapter_id": _context.adapter_id,
		"display_name": _context.display_name,
		"locale": _context.locale,
		"fallback_locale": _context.fallback_locale,
		"capability_ids": _context.capabilities.capabilities.duplicate(),
		"storage_root_ids": storage_root_ids,
		"launch_option_count": _context.launch_options.size(),
		"metadata_count": _context.metadata.size(),
	}

func _apply_context(context: GFPlatformRuntimeContext) -> bool:
	if context == null:
		return false
	var copy: GFPlatformRuntimeContext = context.duplicate_context()
	if copy.platform_id == &"":
		copy.platform_id = _platform_id
	if copy.adapter_id == &"":
		copy.adapter_id = _adapter_id
	if copy.platform_id != _platform_id or copy.adapter_id != _adapter_id:
		return false
	if copy.capabilities == null:
		return false
	if copy.capabilities.platform_id == &"":
		copy.capabilities.platform_id = _platform_id
	if copy.capabilities.adapter_id == &"":
		copy.capabilities.adapter_id = _adapter_id
	if (
		copy.capabilities.platform_id != _platform_id
		or copy.capabilities.adapter_id != _adapter_id
	):
		return false
	_context = copy
	return true


func _is_configured() -> bool:
	return _adapter_id != &"" and _platform_id != &"" and not _contract_ids.is_empty()


func _reset_configuration() -> void:
	_adapter_id = &""
	_platform_id = &""
	_contract_ids.clear()
	_contract_descriptors.clear()
	_active_handles.clear()
	_active_method_counts.clear()
	_context = GFPlatformRuntimeContext.new()


func _set_state(next_state: State) -> void:
	if _state == next_state:
		return
	var previous_state: State = _state
	_state = next_state
	state_changed.emit(previous_state, _state)


func _on_handle_cancel_requested(reason: StringName, handle: GFPlatformRequestHandle) -> void:
	var request: GFPlatformBridgeRequest = handle.get_request()
	var method: GFPlatformContractMethodDescriptor = _get_method_descriptor(request)
	if method == null or method.supports_cancellation:
		_cancel_request(handle, reason)


func _apply_contract_descriptors(
	descriptors: Array[GFPlatformContractDescriptor]
) -> bool:
	_contract_descriptors.clear()
	for descriptor: GFPlatformContractDescriptor in descriptors:
		if descriptor == null or not descriptor.validate_definition().is_ok():
			return false
		if not _contract_ids.has(String(descriptor.contract_id)):
			return false
		if _contract_descriptors.has(String(descriptor.contract_id)):
			return false
		_contract_descriptors[String(descriptor.contract_id)] = descriptor.duplicate_descriptor()
	return _contract_descriptors.size() == _contract_ids.size()


func _get_contract_descriptor_internal(
	contract_id: StringName
) -> GFPlatformContractDescriptor:
	var value: Variant = GFVariantData.get_option_value(
		_contract_descriptors,
		String(contract_id)
	)
	if value is GFPlatformContractDescriptor:
		var descriptor: GFPlatformContractDescriptor = value
		return descriptor
	return null


func _get_method_descriptor(
	request: GFPlatformBridgeRequest
) -> GFPlatformContractMethodDescriptor:
	if request == null:
		return null
	var descriptor: GFPlatformContractDescriptor = _get_contract_descriptor_internal(
		request.contract_id
	)
	return descriptor.get_method(request.method_id) if descriptor != null else null


func _track_handle(
	request: GFPlatformBridgeRequest,
	handle: GFPlatformRequestHandle
) -> void:
	_active_handles[String(request.request_id)] = handle
	var method: GFPlatformContractMethodDescriptor = _get_method_descriptor(request)
	if method != null:
		var method_key: String = _make_method_key(request.contract_id, request.method_id)
		_active_method_counts[method_key] = (
			GFVariantData.get_option_int(_active_method_counts, method_key) + 1
		)


func _get_active_handle(request_id: StringName) -> GFPlatformRequestHandle:
	var value: Variant = GFVariantData.get_option_value(_active_handles, String(request_id))
	if value is GFPlatformRequestHandle:
		var handle: GFPlatformRequestHandle = value
		return handle
	return null


static func _make_method_key(contract_id: StringName, method_id: StringName) -> String:
	return "%s::%s" % [String(contract_id), String(method_id)]


static func _normalize_string_set(values: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: String in values:
		var normalized: String = value.strip_edges()
		if not normalized.is_empty() and not result.has(normalized):
			var _appended: bool = result.append(normalized)
	result.sort()
	return result
