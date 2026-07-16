## GFRequestHandlerRegistry: 单处理器请求调用注册表。
##
## 用于表达 “Invoke / TryInvoke” 语义：每个 request_type 至多有一个处理器。
## 多订阅广播仍应使用 GFTypeEventSystem；本注册表只负责明确的一对一请求调用契约，
## 不规定请求载荷结构，也不执行业务路由策略。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFRequestHandlerRegistry
extends RefCounted


# --- 信号 ---

## handler 注册或替换时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_type: 请求类型。
## [br]
## @param replaced: 是否替换了旧 handler。
## [br]
## @param metadata: 注册元数据。
## [br]
## @schema metadata: Dictionary，调用方定义的 handler 上下文。
signal handler_registered(request_type: StringName, replaced: bool, metadata: Dictionary)

## handler 注销时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_type: 请求类型。
## [br]
## @param metadata: 注销元数据。
## [br]
## @schema metadata: Dictionary，调用方定义的 handler 上下文。
signal handler_unregistered(request_type: StringName, metadata: Dictionary)

## 请求成功调用时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_type: 请求类型。
## [br]
## @param result: handler 返回值副本。
## [br]
## @param metadata: 调用元数据。
## [br]
## @schema result: Variant，handler 返回值。
## [br]
## @schema metadata: Dictionary，包含 request_type、sequence、context 和 handler metadata。
signal request_invoked(request_type: StringName, result: Variant, metadata: Dictionary)


# --- 常量 ---

const _GF_ASYNC_RESULT_SUPPORT = preload("res://addons/gf/standard/common/gf_async_result_support.gd")
const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")

## handler 已注册。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_REGISTERED: StringName = &"registered"

## handler 已替换。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_REPLACED: StringName = &"replaced"

## handler 已注销。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_UNREGISTERED: StringName = &"unregistered"

## handler 已存在且不允许替换。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_DUPLICATE: StringName = &"duplicate"

## 未找到 handler。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_MISSING: StringName = &"missing"

## 请求已调用。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_INVOKED: StringName = &"invoked"

## 请求或 handler 无效。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_INVALID: StringName = &"invalid"

## handler 不匹配。
## [br]
## @api public
## [br]
## @since 7.0.0
const STATUS_MISMATCH: StringName = &"mismatch"

## 默认保留的最近调用事件数量。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_RECENT_EVENTS: int = 64


# --- 公共变量 ---

## 最近注册/调用事件历史上限。设置为 0 时不保留历史。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_recent_events: int = DEFAULT_MAX_RECENT_EVENTS:
	set(value):
		max_recent_events = maxi(value, 0)
		_trim_events()


# --- 私有变量 ---

var _handlers: Dictionary = {}
var _events: Array[Dictionary] = []
var _next_sequence: int = 1
var _registered_count: int = 0
var _replaced_count: int = 0
var _unregistered_count: int = 0
var _duplicate_count: int = 0
var _missing_count: int = 0
var _invoked_count: int = 0
var _invalid_count: int = 0


# --- 公共方法 ---

## 构建请求 handler 桥接契约条目。
## [br]
## 该方法只把请求类型和注册表快照转换为通用 bridge contract/adapters 条目，不生成最终验证报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param required_request_types: 必需请求类型列表。
## [br]
## @param registry: 请求 handler 注册表。
## [br]
## @param options: 构建选项，支持 kind、signature 和 adapter_kind。
## [br]
## @schema options: Dictionary request-handler bridge entry options.
## [br]
## @return 请求 handler bridge 条目数据。
## [br]
## @schema return: Dictionary with contract_entries and adapter_entries arrays.
static func make_bridge_contract_entries(
	required_request_types: PackedStringArray,
	registry: GFRequestHandlerRegistry,
	options: Dictionary = {}
) -> Dictionary:
	var contract_entries: Array[Dictionary] = []
	var adapter_entries: Array[Dictionary] = []
	var contract_kind: StringName = GFVariantData.get_option_string_name(options, "kind", &"request_handler")
	var signature: String = GFVariantData.get_option_string(options, "signature", "Dictionary(request) -> Variant")
	for request_type_text: String in required_request_types:
		var request_type: StringName = StringName(request_type_text.strip_edges())
		if request_type == &"":
			continue
		contract_entries.append({
			"contract_id": request_type,
			"kind": contract_kind,
			"signature": signature,
			"allow_multiple": false,
		})

	if registry != null:
		var adapter_kind: StringName = GFVariantData.get_option_string_name(options, "adapter_kind", &"request_handler")
		for request_type: StringName in registry.get_handler_ids():
			var snapshot: Dictionary = registry.get_handler_snapshot(request_type)
			adapter_entries.append({
				"adapter_id": StringName("handler:%s" % String(request_type)),
				"contract_id": request_type,
				"kind": adapter_kind,
				"signature": signature,
				"enabled": GFVariantData.get_option_bool(snapshot, "has_valid_handler"),
				"metadata": snapshot,
			})

	return {
		"contract_entries": contract_entries,
		"adapter_entries": adapter_entries,
	}


## 注册单处理器请求 handler。
## [br]
## handler 会收到一个 Dictionary 参数，包含 request_type、payload、context、sequence 和 handler_metadata。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_type: 稳定请求类型。
## [br]
## @param handler: 处理请求的 Callable，签名为 Callable(request: Dictionary) -> Variant。
## [br]
## @param options: 注册选项，支持 replace、owner_id 和 metadata。
## [br]
## @return 注册结果。
## [br]
## @schema options: Dictionary，包含 replace: bool、owner_id: StringName 和 metadata: Dictionary。
## [br]
## @schema return: Dictionary，包含 ok、status、request_type、replaced 和 metadata。
func register_handler(request_type: StringName, handler: Callable, options: Dictionary = {}) -> Dictionary:
	if request_type == &"" or not handler.is_valid():
		_invalid_count += 1
		return _make_result(false, STATUS_INVALID, request_type, null, {
			"error": "Request type or handler is invalid.",
		})

	var replace_existing: bool = GFVariantData.get_option_bool(options, "replace", false)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(options, "metadata")
	var owner_id: StringName = GFVariantData.get_option_string_name(options, "owner_id")
	var replaced: bool = _handlers.has(request_type)
	if replaced and not replace_existing:
		_duplicate_count += 1
		_record_event(&"register_duplicate", request_type, STATUS_DUPLICATE, metadata)
		return _make_result(false, STATUS_DUPLICATE, request_type, null, {
			"replaced": false,
			"metadata": metadata,
		})

	var sequence: int = _take_sequence()
	_handlers[request_type] = {
		"request_type": request_type,
		"handler": handler,
		"owner_id": owner_id,
		"metadata": metadata.duplicate(true),
		"registered_msec": Time.get_ticks_msec(),
		"registered_sequence": sequence,
		"last_invoked_msec": 0,
		"last_invoked_sequence": 0,
		"invocation_count": 0,
	}
	if replaced:
		_replaced_count += 1
	else:
		_registered_count += 1

	var status: StringName = STATUS_REPLACED if replaced else STATUS_REGISTERED
	handler_registered.emit(request_type, replaced, metadata.duplicate(true))
	_record_event(&"handler_registered", request_type, status, metadata)
	return _make_result(true, status, request_type, null, {
		"replaced": replaced,
		"metadata": metadata,
	})


## 注销请求 handler。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_type: 稳定请求类型。
## [br]
## @param handler: 可选 handler；有效时只有完全匹配才注销。
## [br]
## @param metadata: 注销元数据。
## [br]
## @return 注销结果。
## [br]
## @schema metadata: Dictionary，调用方定义的注销上下文。
## [br]
## @schema return: Dictionary with ok, status, request_type, result, error, handler_count, and metadata.
func unregister_handler(
	request_type: StringName,
	handler: Callable = Callable(),
	metadata: Dictionary = {}
) -> Dictionary:
	if request_type == &"":
		_invalid_count += 1
		return _make_result(false, STATUS_INVALID, request_type, null, {
			"error": "Request type is invalid.",
		})
	if not _handlers.has(request_type):
		_missing_count += 1
		return _make_result(false, STATUS_MISSING, request_type, null)

	var entry: Dictionary = GFVariantData.as_dictionary(_handlers[request_type])
	var existing_handler: Callable = _variant_to_callable(GFVariantData.get_option_value(entry, "handler"))
	if handler.is_valid() and existing_handler != handler:
		return _make_result(false, STATUS_MISMATCH, request_type, null)

	var _erased_handler: bool = _handlers.erase(request_type)
	_unregistered_count += 1
	handler_unregistered.emit(request_type, metadata.duplicate(true))
	_record_event(&"handler_unregistered", request_type, STATUS_UNREGISTERED, metadata)
	return _make_result(true, STATUS_UNREGISTERED, request_type, null, {
		"metadata": metadata,
	})


## 调用请求 handler。
## [br]
## 缺少 handler 会返回 missing 状态；handler 运行时错误由 Godot 按普通 Callable 调用规则报告。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_type: 稳定请求类型。
## [br]
## @param payload: 请求载荷。
## [br]
## @param context: 调用上下文。
## [br]
## @return 调用结果。
## [br]
## @schema payload: Variant，调用方定义的请求载荷。
## [br]
## @schema context: Dictionary，调用方定义的调用上下文。
## [br]
## @schema return: Dictionary，包含 ok、status、request_type、result、context 和 metadata。
func invoke(request_type: StringName, payload: Variant = null, context: Dictionary = {}) -> Dictionary:
	return _invoke_handler(request_type, payload, context, false)


## 尝试调用请求 handler。
## [br]
## 与 invoke() 相同，但缺少 handler 被视为可预期结果，并在返回值中标记 missing_allowed。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_type: 稳定请求类型。
## [br]
## @param payload: 请求载荷。
## [br]
## @param context: 调用上下文。
## [br]
## @return 调用结果。
## [br]
## @schema payload: Variant，调用方定义的请求载荷。
## [br]
## @schema context: Dictionary，调用方定义的调用上下文。
## [br]
## @schema return: Dictionary，包含 ok、status、request_type、result、context、metadata 和 missing_allowed。
func try_invoke(request_type: StringName, payload: Variant = null, context: Dictionary = {}) -> Dictionary:
	return _invoke_handler(request_type, payload, context, true)


## 将请求调用结果转换为 JSON.stringify() 安全的诊断报告。
## [br]
## 功能型 invoke()/try_invoke() 返回值保持原始 Variant；日志、快照和跨进程诊断应使用该方法输出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param result: invoke()/try_invoke() 返回的调用结果。
## [br]
## @param options: 编码选项，透传给 GFReportValueCodec。
## [br]
## @schema result: Dictionary raw request invocation result.
## [br]
## @schema options: Dictionary report value codec options.
## [br]
## @return JSON-safe 调用结果。
## [br]
## @schema return: Dictionary safe for JSON.stringify().
static func to_json_compatible_result(result: Dictionary, options: Dictionary = {}) -> Dictionary:
	return GFVariantData.as_dictionary(_GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(result, options))


## 判断请求类型是否已注册 handler。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_type: 稳定请求类型。
## [br]
## @return 已注册且 handler 有效时返回 true。
func has_handler(request_type: StringName) -> bool:
	if not _handlers.has(request_type):
		return false
	var entry: Dictionary = GFVariantData.as_dictionary(_handlers[request_type])
	return _variant_to_callable(GFVariantData.get_option_value(entry, "handler")).is_valid()


## 获取已注册请求类型。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 请求类型数组。
func get_handler_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for request_type: Variant in _handlers.keys():
		result.append(GFVariantData.to_string_name(request_type))
	result.sort()
	return result


## 获取某个 handler 的快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param request_type: 稳定请求类型。
## [br]
## @return handler 快照；未注册时为空字典。
## [br]
## @schema return: Dictionary，包含 request_type、owner_id、metadata、registered_msec、invocation_count、last_invoked_msec 和 has_valid_handler。
func get_handler_snapshot(request_type: StringName) -> Dictionary:
	if not _handlers.has(request_type):
		return {}
	return _entry_to_snapshot(GFVariantData.as_dictionary(_handlers[request_type]))


## 获取最近注册/调用事件。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 最近事件数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 sequence、event_type、request_type、status 和 metadata。
func get_recent_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in _events:
		result.append(event.duplicate(true))
	return result


## 获取 JSON.stringify() 安全的最近注册/调用事件。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 编码选项，透传给 GFReportValueCodec。
## [br]
## @return JSON-safe 最近事件数组。
## [br]
## @schema options: Dictionary report value codec options.
## [br]
## @schema return: Array[Dictionary]，每个元素均可安全传给 JSON.stringify()。
func get_json_compatible_recent_events(options: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw_events: Variant = _GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(get_recent_events(), options)
	if raw_events is Array:
		var events: Array = raw_events
		for event_value: Variant in events:
			if event_value is Dictionary:
				var event: Dictionary = event_value
				result.append(event.duplicate(true))
	return result


## 清空全部 handler 和历史事件。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_handlers.clear()
	_events.clear()
	_next_sequence = 1
	_registered_count = 0
	_replaced_count = 0
	_unregistered_count = 0
	_duplicate_count = 0
	_missing_count = 0
	_invoked_count = 0
	_invalid_count = 0


## 获取注册表调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 注册表状态快照。
## [br]
## @schema return: Dictionary，包含 handler_count、统计计数、handlers 和 recent_events。
func get_debug_snapshot() -> Dictionary:
	var handlers: Array[Dictionary] = []
	for request_type: StringName in get_handler_ids():
		handlers.append(get_handler_snapshot(request_type))
	return {
		"handler_count": _handlers.size(),
		"registered_count": _registered_count,
		"replaced_count": _replaced_count,
		"unregistered_count": _unregistered_count,
		"duplicate_count": _duplicate_count,
		"missing_count": _missing_count,
		"invoked_count": _invoked_count,
		"invalid_count": _invalid_count,
		"handlers": handlers,
		"recent_events": get_recent_events(),
	}


## 获取 JSON.stringify() 安全的注册表调试快照。
## [br]
## 功能型 get_debug_snapshot() 保留原始 Variant；日志、导出和跨进程诊断应使用该方法。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 编码选项，透传给 GFReportValueCodec。
## [br]
## @return JSON-safe 注册表状态快照。
## [br]
## @schema options: Dictionary report value codec options.
## [br]
## @schema return: Dictionary safe for JSON.stringify().
func get_json_compatible_debug_snapshot(options: Dictionary = {}) -> Dictionary:
	return GFVariantData.as_dictionary(_GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(get_debug_snapshot(), options))


# --- 私有/辅助方法 ---

func _invoke_handler(
	request_type: StringName,
	payload: Variant,
	context: Dictionary,
	missing_allowed: bool
) -> Dictionary:
	if request_type == &"":
		_invalid_count += 1
		return _make_result(false, STATUS_INVALID, request_type, null, {
			"error": "Request type is invalid.",
			"missing_allowed": missing_allowed,
		})
	if not _handlers.has(request_type):
		_missing_count += 1
		_record_event(&"request_missing", request_type, STATUS_MISSING, context)
		return _make_result(false, STATUS_MISSING, request_type, null, {
			"context": context,
			"missing_allowed": missing_allowed,
		})

	var entry: Dictionary = GFVariantData.as_dictionary(_handlers[request_type])
	var handler: Callable = _variant_to_callable(GFVariantData.get_option_value(entry, "handler"))
	if not handler.is_valid():
		_invalid_count += 1
		_record_event(&"handler_invalid", request_type, STATUS_INVALID, context)
		return _make_result(false, STATUS_INVALID, request_type, null, {
			"context": context,
			"missing_allowed": missing_allowed,
		})

	var sequence: int = _take_sequence()
	var request: Dictionary = {
		"request_type": request_type,
		"payload": GFVariantData.duplicate_variant(payload),
		"context": context.duplicate(true),
		"sequence": sequence,
		"handler_metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
	}
	var result_value: Variant = handler.call(request)
	entry["invocation_count"] = GFVariantData.get_option_int(entry, "invocation_count") + 1
	entry["last_invoked_msec"] = Time.get_ticks_msec()
	entry["last_invoked_sequence"] = sequence
	_handlers[request_type] = entry
	_invoked_count += 1

	var invoke_metadata: Dictionary = {
		"context": context.duplicate(true),
		"handler_metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
		"sequence": sequence,
	}
	request_invoked.emit(request_type, GFVariantData.duplicate_variant(result_value), invoke_metadata.duplicate(true))
	_record_event(&"request_invoked", request_type, STATUS_INVOKED, invoke_metadata)
	return _make_result(true, STATUS_INVOKED, request_type, result_value, {
		"context": context,
		"metadata": invoke_metadata,
		"missing_allowed": missing_allowed,
	})


func _entry_to_snapshot(entry: Dictionary) -> Dictionary:
	var handler: Callable = _variant_to_callable(GFVariantData.get_option_value(entry, "handler"))
	return {
		"request_type": GFVariantData.get_option_string_name(entry, "request_type"),
		"owner_id": GFVariantData.get_option_string_name(entry, "owner_id"),
		"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
		"registered_msec": GFVariantData.get_option_int(entry, "registered_msec"),
		"registered_sequence": GFVariantData.get_option_int(entry, "registered_sequence"),
		"last_invoked_msec": GFVariantData.get_option_int(entry, "last_invoked_msec"),
		"last_invoked_sequence": GFVariantData.get_option_int(entry, "last_invoked_sequence"),
		"invocation_count": GFVariantData.get_option_int(entry, "invocation_count"),
		"has_valid_handler": handler.is_valid(),
	}


func _make_result(
	ok: bool,
	status: StringName,
	request_type: StringName,
	result_value: Variant,
	extra: Dictionary = {}
) -> Dictionary:
	var result: Dictionary = {
		"ok": ok,
		"status": status,
		"request_type": request_type,
		"result": GFVariantData.duplicate_variant(result_value),
	}
	_GF_ASYNC_RESULT_SUPPORT.merge_extra(result, extra)
	return result


func _record_event(
	event_type: StringName,
	request_type: StringName,
	status: StringName,
	metadata: Dictionary
) -> void:
	if max_recent_events <= 0:
		return
	var event: Dictionary = {
		"sequence": _take_sequence(),
		"event_type": event_type,
		"request_type": request_type,
		"status": status,
		"metadata": metadata.duplicate(true),
		"timestamp_msec": Time.get_ticks_msec(),
	}
	_events.append(event)
	_trim_events()


func _trim_events() -> void:
	while _events.size() > max_recent_events:
		_events.pop_front()


func _take_sequence() -> int:
	var result: int = _next_sequence
	_next_sequence += 1
	return result


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callable: Callable = value
		return callable
	return Callable()
