## GFTypeEventSystem: 基于类型和 StringName 的双轨事件系统。
##
## 轨道一（类型事件）：使用 Script 类型作为键，以对象实例为载体分发事件。
## 轨道二（简单事件）：使用 StringName 作为键，以 Variant 为 payload 分发事件。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
## [br]
## @layer kernel/core
class_name GFTypeEventSystem


# --- 常量 ---

## 默认最大事件嵌套派发深度。
## [br]
## @api public
const DEFAULT_MAX_DISPATCH_DEPTH: int = 64
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")
const _SCRIPT_TYPE_INSPECTOR = preload("res://addons/gf/kernel/core/gf_script_type_inspector.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共变量 ---

## 最大事件嵌套派发深度。小于等于 0 时不限制。
## [br]
## @api public
var max_dispatch_depth: int = DEFAULT_MAX_DISPATCH_DEPTH:
	set(value):
		max_dispatch_depth = maxi(value, 0)

## 是否记录事件派发追踪。默认关闭，避免调试数据持有过多运行时引用。
## [br]
## @api public
var trace_enabled: bool = false

## 最多保留的事件派发追踪条目数。
## [br]
## @api public
var max_trace_entries: int = 64:
	set(value):
		max_trace_entries = maxi(value, 0)
		_trim_dispatch_trace()


# --- 私有变量 ---

var _type_track: EventListenerTrack = EventListenerTrack.new(&"event_type")
var _assignable_type_track: EventListenerTrack = EventListenerTrack.new(&"event_type")
var _simple_track: EventListenerTrack = EventListenerTrack.new(&"event_id")
var _event_listeners: Dictionary = _type_track.listeners
var _assignable_event_listeners: Dictionary = _assignable_type_track.listeners
var _simple_event_listeners: Dictionary = _simple_track.listeners
var _type_dispatch_cache: Dictionary = {}
var _script_ancestry_cache: Dictionary = {}
var _type_dispatch_depth: int = 0
var _type_dispatch_count: int = 0
var _max_type_dispatch_depth_observed: int = 0
var _clear_requested_type: bool = false

var _simple_dispatch_depth: int = 0
var _simple_dispatch_count: int = 0
var _max_simple_dispatch_depth_observed: int = 0
var _clear_requested_simple: bool = false
var _listener_order_counter: int = 0
var _dispatch_trace: Array[Dictionary] = []


# --- 公共方法 (类型事件) ---

## 注册特定脚本类型的事件监听器。
## [br]
## @api public
## [br]
## @param event_type: 要监听的脚本类型。
## [br]
## @param on_event: 事件发送时执行的回调函数。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
## [br]
## @param owner: 可选监听拥有者，用于批量注销。
func register(event_type: Script, on_event: Callable, priority: int = 0, owner: Object = null) -> void:
	if event_type == null:
		push_error("[GFTypeEventSystem] register 失败：event_type 为空。")
		return
	if not _validate_callable_min_args(on_event, 1, "类型事件回调", "事件实例"):
		return

	if _type_dispatch_depth > 0:
		_type_track.queue_add(
			event_type,
			on_event,
			priority,
			_make_owner_ref(owner),
			_owner_instance_id(owner),
			_next_listener_order()
		)
		return

	_add_listener_entry(_event_listeners, event_type, on_event, priority, owner, _next_listener_order(), false)


## 注销特定脚本类型的事件监听器。
## [br]
## @api public
## [br]
## @param event_type: 要注销的脚本类型。
## [br]
## @param on_event: 要移除的回调函数。
func unregister(event_type: Script, on_event: Callable) -> void:
	if event_type == null:
		return
	if _type_dispatch_depth > 0:
		_type_track.remove_pending_add(event_type, on_event, 0, true)
		_type_track.queue_remove(event_type, on_event, 0, true)
		return

	if _event_listeners.has(event_type):
		var listeners: Array = _get_registry_array(_event_listeners, event_type)
		_remove_entry_by_callable(listeners, on_event, event_type, false, 0, true)
		_erase_listener_key_if_empty(_event_listeners, event_type)


## 注销带拥有者的特定脚本类型事件监听器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param owner: 注册监听时使用的拥有者。
## [br]
## @param event_type: 要注销的脚本类型。
## [br]
## @param on_event: 要移除的回调函数。
func unregister_owned(owner: Object, event_type: Script, on_event: Callable) -> void:
	if owner == null or event_type == null:
		return
	var owner_id: int = owner.get_instance_id()
	if _type_dispatch_depth > 0:
		_type_track.remove_pending_add(event_type, on_event, owner_id, true)
		_type_track.queue_remove(event_type, on_event, owner_id, true)
		return

	if _event_listeners.has(event_type):
		var listeners: Array = _get_registry_array(_event_listeners, event_type)
		_remove_entry_by_callable(listeners, on_event, event_type, false, owner_id, true)
		_erase_listener_key_if_empty(_event_listeners, event_type)


## 注册可赋值类型事件监听器。
## 监听 base_event_type 时，也会收到继承自该脚本类型的事件实例。
## [br]
## @api public
## [br]
## @param base_event_type: 要监听的基类脚本类型。
## [br]
## @param on_event: 事件发送时执行的回调函数。
## [br]
## @param priority: 回调优先级，数值越大越先执行，默认为 0。
## [br]
## @param owner: 可选监听拥有者，用于批量注销。
func register_assignable(base_event_type: Script, on_event: Callable, priority: int = 0, owner: Object = null) -> void:
	if base_event_type == null:
		push_error("[GFTypeEventSystem] register_assignable 失败：base_event_type 为空。")
		return
	if not _validate_callable_min_args(on_event, 1, "可赋值事件回调", "事件实例"):
		return

	if _type_dispatch_depth > 0:
		_assignable_type_track.queue_add(
			base_event_type,
			on_event,
			priority,
			_make_owner_ref(owner),
			_owner_instance_id(owner),
			_next_listener_order()
		)
		return

	_add_listener_entry(_assignable_event_listeners, base_event_type, on_event, priority, owner, _next_listener_order(), true)


## 注销可赋值类型事件监听器。
## [br]
## @api public
## [br]
## @param base_event_type: 注册时使用的基类脚本类型。
## [br]
## @param on_event: 要移除的回调函数。
func unregister_assignable(base_event_type: Script, on_event: Callable) -> void:
	if base_event_type == null:
		return
	if _type_dispatch_depth > 0:
		_assignable_type_track.remove_pending_add(base_event_type, on_event, 0, true)
		_assignable_type_track.queue_remove(base_event_type, on_event, 0, true)
		return

	if _assignable_event_listeners.has(base_event_type):
		var listeners: Array = _get_registry_array(_assignable_event_listeners, base_event_type)
		_remove_entry_by_callable(listeners, on_event, base_event_type, true, 0, true)
		_erase_listener_key_if_empty(_assignable_event_listeners, base_event_type)


## 注销带拥有者的可赋值类型事件监听器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param owner: 注册监听时使用的拥有者。
## [br]
## @param base_event_type: 注册时使用的基类脚本类型。
## [br]
## @param on_event: 要移除的回调函数。
func unregister_assignable_owned(owner: Object, base_event_type: Script, on_event: Callable) -> void:
	if owner == null or base_event_type == null:
		return
	var owner_id: int = owner.get_instance_id()
	if _type_dispatch_depth > 0:
		_assignable_type_track.remove_pending_add(base_event_type, on_event, owner_id, true)
		_assignable_type_track.queue_remove(base_event_type, on_event, owner_id, true)
		return

	if _assignable_event_listeners.has(base_event_type):
		var listeners: Array = _get_registry_array(_assignable_event_listeners, base_event_type)
		_remove_entry_by_callable(listeners, on_event, base_event_type, true, owner_id, true)
		_erase_listener_key_if_empty(_assignable_event_listeners, base_event_type)


## 将事件实例发送给其脚本类型的所有注册监听器。
## [br]
## @api public
## [br]
## @param event_instance: 要分发的事件实例。
func send(event_instance: Object) -> void:
	if event_instance == null:
		push_error("[GFTypeEventSystem] 发送的事件实例为空。")
		return

	var event_type_variant: Variant = event_instance.get_script()
	if event_type_variant == null:
		push_error("[GFTypeEventSystem] 发送的事件必须是附加了脚本的类实例。")
		return
	if not (event_type_variant is Script):
		push_error("[GFTypeEventSystem] 发送的事件脚本类型无效。")
		return
	var event_type: Script = event_type_variant
	if _would_exceed_dispatch_depth(_type_dispatch_depth):
		_report_dispatch_depth_exceeded("type", _script_debug_key(event_type))
		return

	var dispatch_entries: Array[Dictionary] = _get_type_dispatch_entries(event_type)
	_record_dispatch_trace("type", _script_debug_key(event_type), dispatch_entries.size(), _type_dispatch_depth + 1)
	if dispatch_entries.is_empty():
		return

	_type_dispatch_depth += 1
	_type_dispatch_count += 1
	_max_type_dispatch_depth_observed = maxi(_max_type_dispatch_depth_observed, _type_dispatch_depth)

	_dispatch_type_listener_entries(event_instance, dispatch_entries)

	_type_dispatch_depth = maxi(_type_dispatch_depth - 1, 0)
	if _type_dispatch_depth == 0:
		_clear_requested_type = false
		_flush_type_pending()


# --- 公共方法 (简单事件) ---

## 注册轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param on_event: 回调函数，签名为 func(payload: Variant)。
## [br]
## @param owner: 可选监听拥有者，用于批量注销。
func register_simple(event_id: StringName, on_event: Callable, owner: Object = null) -> void:
	if not _validate_simple_event_id(event_id, "register_simple"):
		return
	if not _validate_callable_min_args(on_event, 1, "简单事件回调", "payload"):
		return

	if _simple_dispatch_depth > 0:
		_simple_track.queue_add(
			event_id,
			on_event,
			0,
			_make_owner_ref(owner),
			_owner_instance_id(owner),
			_next_listener_order()
		)
		return

	_add_simple_listener_entry(event_id, on_event, owner, _next_listener_order())


## 注销轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param on_event: 要移除的回调函数。
func unregister_simple(event_id: StringName, on_event: Callable) -> void:
	if not _validate_simple_event_id(event_id, "unregister_simple"):
		return
	if _simple_dispatch_depth > 0:
		_simple_track.remove_pending_add(event_id, on_event, 0, true)
		_simple_track.queue_remove(event_id, on_event, 0, true)
		return

	if _simple_event_listeners.has(event_id):
		var listeners: Array = _get_registry_array(_simple_event_listeners, event_id)
		_remove_entry_by_callable(listeners, on_event, null, false, 0, true)
		_erase_listener_key_if_empty(_simple_event_listeners, event_id)


## 注销带拥有者的轻量级 StringName 事件监听器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param owner: 注册监听时使用的拥有者。
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param on_event: 要移除的回调函数。
func unregister_simple_owned(owner: Object, event_id: StringName, on_event: Callable) -> void:
	if owner == null or not _validate_simple_event_id(event_id, "unregister_simple_owned"):
		return
	var owner_id: int = owner.get_instance_id()
	if _simple_dispatch_depth > 0:
		_simple_track.remove_pending_add(event_id, on_event, owner_id, true)
		_simple_track.queue_remove(event_id, on_event, owner_id, true)
		return

	if _simple_event_listeners.has(event_id):
		var listeners: Array = _get_registry_array(_simple_event_listeners, event_id)
		_remove_entry_by_callable(listeners, on_event, null, false, owner_id, true)
		_erase_listener_key_if_empty(_simple_event_listeners, event_id)


## 将 payload 发送给指定 StringName 事件的所有注册监听器。
## [br]
## @api public
## [br]
## @param event_id: StringName 事件标识符。
## [br]
## @param payload: 传递给监听器的数据，可为任意类型。
## [br]
## @schema payload: Variant payload passed unchanged to simple event listeners.
func send_simple(event_id: StringName, payload: Variant = null) -> void:
	if not _validate_simple_event_id(event_id, "send_simple"):
		return
	if _would_exceed_dispatch_depth(_simple_dispatch_depth):
		_report_dispatch_depth_exceeded("simple", String(event_id))
		return

	if not _simple_event_listeners.has(event_id):
		_record_dispatch_trace("simple", String(event_id), 0, _simple_dispatch_depth + 1)
		return
	var listeners: Array = _get_registry_array(_simple_event_listeners, event_id)
	_record_dispatch_trace("simple", String(event_id), listeners.size(), _simple_dispatch_depth + 1)

	_simple_dispatch_depth += 1
	_simple_dispatch_count += 1
	_max_simple_dispatch_depth_observed = maxi(_max_simple_dispatch_depth_observed, _simple_dispatch_depth)
	var has_pending_owner_removes: bool = not _simple_track.pending_owner_removes.is_empty()
	var has_pending_removes: bool = not _simple_track.pending_removes.is_empty()

	for entry: Dictionary in listeners:
		if _clear_requested_simple:
			break

		var callback: Callable = entry.callable

		if _entry_owner_is_released(entry):
			_simple_track.queue_remove(event_id, callback, _entry_owner_id(entry), true)
			has_pending_removes = true
			continue
		if has_pending_owner_removes and _is_pending_owner_remove(entry, _simple_track.pending_owner_removes):
			continue
		if not callback.is_valid() or (callback.get_object() != null and not is_instance_valid(callback.get_object())):
			_simple_track.queue_remove(event_id, callback, _entry_owner_id(entry), true)
			has_pending_removes = true
			continue
		if has_pending_removes and _simple_track.has_pending_remove(event_id, callback, _entry_owner_id(entry), true):
			continue

		callback.call(payload)

		if _clear_requested_simple:
			break
		if not has_pending_owner_removes and not _simple_track.pending_owner_removes.is_empty():
			has_pending_owner_removes = true
		if not has_pending_removes and not _simple_track.pending_removes.is_empty():
			has_pending_removes = true

	_simple_dispatch_depth = maxi(_simple_dispatch_depth - 1, 0)
	if _simple_dispatch_depth == 0:
		_clear_requested_simple = false
		_flush_simple_pending()


## 注销指定拥有者注册过的所有事件监听器。
## [br]
## @api public
## [br]
## @param owner: 监听拥有者。
func unregister_owner(owner: Object) -> void:
	if owner == null:
		return

	var owner_id: int = owner.get_instance_id()
	if _type_dispatch_depth > 0:
		_type_track.remove_pending_adds_for_owner_id(owner_id)
		_assignable_type_track.remove_pending_adds_for_owner_id(owner_id)
		_type_track.append_unique_owner_remove(owner_id)
		_assignable_type_track.append_unique_owner_remove(owner_id)
	else:
		_remove_owner_from_type_listeners(owner_id)
		_remove_owner_from_assignable_type_listeners(owner_id)

	if _simple_dispatch_depth > 0:
		_simple_track.remove_pending_adds_for_owner_id(owner_id)
		_simple_track.append_unique_owner_remove(owner_id)
	else:
		_remove_owner_from_simple_listeners(owner_id)


## 获取事件系统诊断统计。
## [br]
## @api public
## [br]
## @return 包含类型事件、可赋值事件和简单事件监听数量的字典。
## [br]
## @schema return: Dictionary containing listener counts, pending operation counts, dispatch counters, depth limits, and trace counters.
func get_debug_stats() -> Dictionary:
	var listener_diagnostics: Dictionary = get_listener_diagnostics()
	return {
		"type_events": _collect_listener_stats(_event_listeners),
		"assignable_type_events": _collect_listener_stats(_assignable_event_listeners),
		"simple_events": _collect_simple_listener_stats(),
		"listener_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(listener_diagnostics, "listener_count", 0),
		"stale_owner_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(listener_diagnostics, "stale_owner_count", 0),
		"pending_type_adds": _type_track.pending_adds.size() + _assignable_type_track.pending_adds.size(),
		"pending_type_removes": _type_track.pending_removes.size() + _assignable_type_track.pending_removes.size(),
		"pending_type_owner_removes": _type_track.pending_owner_removes.size() + _assignable_type_track.pending_owner_removes.size(),
		"pending_simple_adds": _simple_track.pending_adds.size(),
		"pending_simple_removes": _simple_track.pending_removes.size(),
		"pending_simple_owner_removes": _simple_track.pending_owner_removes.size(),
		"type_dispatch_count": _type_dispatch_count,
		"simple_dispatch_count": _simple_dispatch_count,
		"type_dispatch_depth": _type_dispatch_depth,
		"simple_dispatch_depth": _simple_dispatch_depth,
		"max_type_dispatch_depth_observed": _max_type_dispatch_depth_observed,
		"max_simple_dispatch_depth_observed": _max_simple_dispatch_depth_observed,
		"max_dispatch_depth": max_dispatch_depth,
		"type_dispatch_cache_size": _type_dispatch_cache.size(),
		"script_ancestry_cache_size": _script_ancestry_cache.size(),
		"trace_enabled": trace_enabled,
		"trace_count": _dispatch_trace.size(),
		"max_trace_entries": max_trace_entries,
	}


## 获取事件监听器诊断明细。
## [br]
## 默认只返回每条轨道的数量统计；传入 `{ "include_entries": true }` 时会附带每个监听器的事件 key、owner 状态、优先级和 Callable 状态。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param options: 诊断选项。
## [br]
## @schema options: Dictionary，可包含 include_entries。
## [br]
## @return 监听器诊断报告。
## [br]
## @schema return: Dictionary containing listener counts, stale owner counts, track summaries, and optional entry rows.
func get_listener_diagnostics(options: Dictionary = {}) -> Dictionary:
	var include_entries: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_entries", false)
	var type_track: Dictionary = _collect_track_diagnostics("type", _type_track, include_entries)
	var assignable_track: Dictionary = _collect_track_diagnostics("assignable_type", _assignable_type_track, include_entries)
	var simple_track: Dictionary = _collect_track_diagnostics("simple", _simple_track, include_entries)
	var listener_count: int = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(type_track, "listener_count", 0)
		+ _GF_VARIANT_ACCESS_SCRIPT.get_option_int(assignable_track, "listener_count", 0)
		+ _GF_VARIANT_ACCESS_SCRIPT.get_option_int(simple_track, "listener_count", 0)
	)
	var stale_owner_count: int = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(type_track, "stale_owner_count", 0)
		+ _GF_VARIANT_ACCESS_SCRIPT.get_option_int(assignable_track, "stale_owner_count", 0)
		+ _GF_VARIANT_ACCESS_SCRIPT.get_option_int(simple_track, "stale_owner_count", 0)
	)
	return {
		"ok": stale_owner_count == 0,
		"listener_count": listener_count,
		"stale_owner_count": stale_owner_count,
		"type_dispatch_cache_size": _type_dispatch_cache.size(),
		"script_ancestry_cache_size": _script_ancestry_cache.size(),
		"tracks": {
			"type": type_track,
			"assignable_type": assignable_track,
			"simple": simple_track,
		},
	}


## 清理 owner 已释放的监听器并返回清理数量。
## [br]
## 派发期间调用时只会把清理动作加入 pending 队列，并在最外层派发结束后合并。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 本次立即移除或排队清理的监听器数量。
func compact_released_owner_listeners() -> int:
	var compacted_count: int = 0
	compacted_count += _compact_released_owner_entries(_type_track, false, _type_dispatch_depth > 0)
	compacted_count += _compact_released_owner_entries(_assignable_type_track, true, _type_dispatch_depth > 0)
	compacted_count += _compact_released_owner_entries(_simple_track, false, _simple_dispatch_depth > 0)
	return compacted_count


## 获取最近事件派发追踪条目。
## [br]
## @api public
## [br]
## @return 从旧到新的追踪条目副本。
## [br]
## @schema return: Array of Dictionary trace entries with event, listener, owner, and dispatch metadata.
func get_dispatch_trace() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _dispatch_trace:
		result.append(entry.duplicate(true))
	return result


## 清空事件派发追踪。
## [br]
## @api public
func clear_dispatch_trace() -> void:
	_dispatch_trace.clear()


## 清空所有已注册的事件监听器（包括类型事件和简单事件）。
## [br]
## @api public
func clear() -> void:
	_type_track.clear_all()
	_assignable_type_track.clear_all()
	_simple_track.clear_all()
	_invalidate_type_dispatch_cache()
	_script_ancestry_cache.clear()
	if _type_dispatch_depth > 0:
		_clear_requested_type = true
	else:
		_type_dispatch_depth = 0
		_clear_requested_type = false
	if _simple_dispatch_depth > 0:
		_clear_requested_simple = true
	else:
		_simple_dispatch_depth = 0
		_clear_requested_simple = false
	_type_dispatch_count = 0
	_simple_dispatch_count = 0
	_max_type_dispatch_depth_observed = 0
	_max_simple_dispatch_depth_observed = 0


# --- 私有/辅助方法 ---

func _get_type_track(assignable: bool) -> EventListenerTrack:
	return _assignable_type_track if assignable else _type_track


func _is_pending_owner_remove(entry: Dictionary, pending_owner_ids: Array[int]) -> bool:
	var owner_id: int = _entry_owner_id(entry)
	return owner_id != 0 and pending_owner_ids.has(owner_id)


func _add_listener_entry(
	registry: Dictionary,
	event_type: Script,
	on_event: Callable,
	priority: int,
	owner: Object,
	order: int,
	assignable: bool
) -> void:
	if not registry.has(event_type):
		registry[event_type] = []
	var listeners: Array = _get_registry_array(registry, event_type)

	for entry: Dictionary in listeners:
		if _listener_entry_matches(entry, on_event, owner):
			return

	var new_entry: Dictionary = {
		"callable": on_event,
		"priority": priority,
		"owner_ref": _make_owner_ref(owner),
		"owner_id": _owner_instance_id(owner),
		"order": order,
	}
	var inserted: bool = false
	for i: int in range(listeners.size()):
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(listeners[i])
		var entry_priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "priority", 0)
		if (
			priority > entry_priority
			or (priority == entry_priority and order < _GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "order", 0))
		):
			var _insert_result_478: Variant = listeners.insert(i, new_entry)
			inserted = true
			break
	if not inserted:
		listeners.append(new_entry)
	_invalidate_type_dispatch_cache_for_event(event_type, assignable)


func _add_simple_listener_entry(
	event_id: StringName,
	on_event: Callable,
	owner: Object,
	order: int
) -> void:
	if not _simple_event_listeners.has(event_id):
		_simple_event_listeners[event_id] = []
	var listeners: Array = _get_registry_array(_simple_event_listeners, event_id)

	for entry: Dictionary in listeners:
		if _listener_entry_matches(entry, on_event, owner):
			return

	listeners.append({
		"callable": on_event,
		"owner_ref": _make_owner_ref(owner),
		"owner_id": _owner_instance_id(owner),
		"order": order,
	})


func _get_type_dispatch_entries(event_type: Script) -> Array[Dictionary]:
	if _type_dispatch_cache.has(event_type):
		return _get_registry_array(_type_dispatch_cache, event_type)

	var result: Array[Dictionary] = []
	if _event_listeners.has(event_type):
		var exact_listeners: Array = _get_registry_array(_event_listeners, event_type)
		for entry: Dictionary in exact_listeners:
			var dispatch_entry: Dictionary = entry.duplicate()
			dispatch_entry["event_type"] = event_type
			dispatch_entry["assignable"] = false
			result.append(dispatch_entry)

	for base_event_type: Script in _assignable_event_listeners.keys():
		if not _script_extends_or_equals(event_type, base_event_type):
			continue
		var assignable_listeners: Array = _get_registry_array(_assignable_event_listeners, base_event_type)
		for entry: Dictionary in assignable_listeners:
			var dispatch_entry: Dictionary = entry.duplicate()
			dispatch_entry["event_type"] = base_event_type
			dispatch_entry["assignable"] = true
			result.append(dispatch_entry)

	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "priority", 0)
		var right_priority: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "priority", 0)
		if left_priority != right_priority:
			return left_priority > right_priority
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "order", 0) < _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "order", 0)
	)
	_type_dispatch_cache[event_type] = result
	return result


func _dispatch_type_listener_entries(event_instance: Object, listeners: Array[Dictionary]) -> void:
	for entry: Dictionary in listeners:
		if _clear_requested_type:
			break

		var callback: Callable = entry.callable
		var event_type: Script = _get_script_option(entry, "event_type")
		var assignable: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(entry, "assignable", false)
		var track: EventListenerTrack = _get_type_track(assignable)
		if _entry_owner_is_released(entry):
			_append_pending_type_remove(event_type, callback, assignable, _entry_owner_id(entry), true)
			continue
		if _is_pending_owner_remove(entry, track.pending_owner_removes):
			continue
		if not callback.is_valid() or (callback.get_object() != null and not is_instance_valid(callback.get_object())):
			_append_pending_type_remove(event_type, callback, assignable, _entry_owner_id(entry), true)
			continue
		if track.has_pending_remove(event_type, callback, _entry_owner_id(entry), true):
			continue

		callback.call(event_instance)

		if _clear_requested_type or _event_is_consumed(event_instance):
			break


func _event_is_consumed(event_instance: Object) -> bool:
	if event_instance == null:
		return false
	if not "is_consumed" in event_instance:
		return false
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(event_instance.get_indexed(NodePath("is_consumed")))


func _append_pending_type_remove(
	event_type: Script,
	callback: Callable,
	assignable: bool,
	owner_id: int,
	owner_filter_enabled: bool
) -> void:
	_get_type_track(assignable).queue_remove(event_type, callback, owner_id, owner_filter_enabled)


func _would_exceed_dispatch_depth(current_depth: int) -> bool:
	return max_dispatch_depth > 0 and current_depth >= max_dispatch_depth


func _report_dispatch_depth_exceeded(track: String, event_key: String) -> void:
	var key_suffix: String = "：%s" % event_key if not event_key.is_empty() else ""
	push_error("[GFTypeEventSystem] %s 事件派发超过最大嵌套深度 %d%s。" % [track, max_dispatch_depth, key_suffix])


func _record_dispatch_trace(track: String, event_key: String, listener_count: int, depth: int) -> void:
	if not trace_enabled or max_trace_entries <= 0:
		return

	_dispatch_trace.append({
		"track": track,
		"event": event_key,
		"listener_count": listener_count,
		"depth": depth,
		"dispatch_index": _type_dispatch_count + _simple_dispatch_count + 1,
		"ticks_msec": Time.get_ticks_msec(),
	})
	_trim_dispatch_trace()


func _trim_dispatch_trace() -> void:
	if max_trace_entries <= 0:
		_dispatch_trace.clear()
		return

	var remove_count: int = _dispatch_trace.size() - max_trace_entries
	if remove_count <= 0:
		return

	var kept_trace: Array[Dictionary] = []
	for index: int in range(remove_count, _dispatch_trace.size()):
		kept_trace.append(_dispatch_trace[index])
	_dispatch_trace = kept_trace


func _script_extends_or_equals(script_cls: Script, base_script: Script) -> bool:
	if script_cls == null or base_script == null:
		return false

	var ancestry: Dictionary = _get_script_ancestry(script_cls)
	return ancestry.has(base_script)


func _get_script_ancestry(script_cls: Script) -> Dictionary:
	if _script_ancestry_cache.has(script_cls):
		return _get_registry_dictionary(_script_ancestry_cache, script_cls)

	var ancestry: Dictionary = {}
	for script: Script in _SCRIPT_TYPE_INSPECTOR.get_inheritance_chain(script_cls):
		ancestry[script] = true
	_script_ancestry_cache[script_cls] = ancestry
	return ancestry


func _collect_listener_stats(registry: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for event_type: Script in registry.keys():
		result[_script_debug_key(event_type)] = _get_registry_array(registry, event_type).size()
	return result


func _collect_simple_listener_stats() -> Dictionary:
	var result: Dictionary = {}
	for event_id: StringName in _simple_event_listeners.keys():
		result[String(event_id)] = _get_registry_array(_simple_event_listeners, event_id).size()
	return result


func _collect_track_diagnostics(track_name: String, track: EventListenerTrack, include_entries: bool) -> Dictionary:
	var key_count: int = 0
	var listener_count: int = 0
	var stale_owner_count: int = 0
	var invalid_callable_count: int = 0
	var entries: Array[Dictionary] = []
	for key: Variant in track.listeners.keys():
		key_count += 1
		var listeners: Array = _get_registry_array(track.listeners, key)
		for entry_variant: Variant in listeners:
			var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(entry_variant)
			listener_count += 1
			var owner_released: bool = _entry_owner_is_released(entry)
			if owner_released:
				stale_owner_count += 1
			if not _entry_callable_is_valid(entry):
				invalid_callable_count += 1
			if include_entries:
				entries.append(_make_listener_diagnostic_entry(track_name, key, entry, owner_released))

	var result: Dictionary = {
		"key_count": key_count,
		"listener_count": listener_count,
		"stale_owner_count": stale_owner_count,
		"invalid_callable_count": invalid_callable_count,
		"pending_add_count": track.pending_adds.size(),
		"pending_remove_count": track.pending_removes.size(),
		"pending_owner_remove_count": track.pending_owner_removes.size(),
	}
	if include_entries:
		result["entries"] = entries
	return result


func _make_listener_diagnostic_entry(
	track_name: String,
	key: Variant,
	entry: Dictionary,
	owner_released: bool
) -> Dictionary:
	var callback: Callable = _get_callable_option(entry, "callable")
	var owner_id: int = _entry_owner_id(entry)
	return {
		"track": track_name,
		"event": _track_key_debug_string(key),
		"owner_id": owner_id,
		"has_owner": owner_id != 0,
		"owner_released": owner_released,
		"callable_valid": _entry_callable_is_valid(entry),
		"callable_method": String(callback.get_method()) if callback.is_valid() else "",
		"priority": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "priority", 0),
		"order": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "order", 0),
	}


func _track_key_debug_string(key: Variant) -> String:
	if key is Script:
		var script_cls: Script = key
		return _script_debug_key(script_cls)
	if key is StringName:
		var event_id: StringName = key
		return String(event_id)
	return _GF_VARIANT_ACCESS_SCRIPT.to_text(key)


func _script_debug_key(script_cls: Script) -> String:
	if script_cls == null:
		return ""
	var global_name: StringName = script_cls.get_global_name()
	if global_name != &"":
		return String(global_name)
	if not script_cls.resource_path.is_empty():
		return script_cls.resource_path
	return "Script:%d" % script_cls.get_instance_id()


func _event_type_from_key(key: Variant) -> Script:
	return _variant_to_script(key)


func _variant_to_script(value: Variant) -> Script:
	if value is Script:
		return value
	return null


func _get_script_option(source: Dictionary, key: Variant) -> Script:
	return _variant_to_script(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, key))


func _get_callable_option(source: Dictionary, key: Variant) -> Callable:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(source, key, Callable())
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _get_registry_dictionary(registry: Dictionary, key: Variant) -> Dictionary:
	return _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(registry, key, {}))


func _get_registry_array(registry: Dictionary, key: Variant) -> Array:
	return _GF_VARIANT_ACCESS_SCRIPT.as_array(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(registry, key, []))


func _flush_type_pending() -> void:
	_flush_listener_track_removes(_type_track, false)
	_flush_listener_track_removes(_assignable_type_track, true)
	_flush_listener_track_owner_removes(_type_track, false)
	_flush_listener_track_owner_removes(_assignable_type_track, true)
	_flush_type_track_adds(_type_track, false)
	_flush_type_track_adds(_assignable_type_track, true)


func _flush_simple_pending() -> void:
	_flush_listener_track_removes(_simple_track, false)
	_flush_listener_track_owner_removes(_simple_track, false)
	_flush_simple_track_adds()


func _flush_listener_track_removes(track: EventListenerTrack, assignable: bool) -> void:
	for pending: Dictionary in track.pending_removes:
		var key: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(pending, track.key_field)
		if not track.listeners.has(key):
			continue
		var listeners: Array = _get_registry_array(track.listeners, key)
		_remove_entry_by_callable(
			listeners,
			_get_callable_option(pending, "callable"),
			_event_type_from_key(key),
			assignable,
			_get_pending_owner_id(pending),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(pending, "owner_filter_enabled", true)
		)
		_erase_listener_key_if_empty(track.listeners, key)
	track.pending_removes.clear()


func _flush_listener_track_owner_removes(track: EventListenerTrack, assignable: bool) -> void:
	for owner_id: int in track.pending_owner_removes:
		_remove_owner_from_listener_track(track, owner_id, assignable)
	track.pending_owner_removes.clear()


func _flush_type_track_adds(track: EventListenerTrack, assignable: bool) -> void:
	for pending: Dictionary in track.pending_adds:
		var owner_ref: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(pending, "owner_ref")
		var binding_owner: Object = _owner_from_ref(owner_ref)
		if owner_ref != null and binding_owner == null:
			continue
		var event_type: Script = _get_script_option(pending, track.key_field)
		if event_type == null:
			continue
		_add_listener_entry(
			track.listeners,
			event_type,
			_get_callable_option(pending, "callable"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(pending, "priority", 0),
			binding_owner,
			_pending_listener_order(pending),
			assignable
		)
	track.pending_adds.clear()


func _flush_simple_track_adds() -> void:
	for pending: Dictionary in _simple_track.pending_adds:
		var owner_ref: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(pending, "owner_ref")
		var binding_owner: Object = _owner_from_ref(owner_ref)
		if owner_ref != null and binding_owner == null:
			continue
		var event_id: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(pending, _simple_track.key_field, &"")
		_add_simple_listener_entry(
			event_id,
			_get_callable_option(pending, "callable"),
			binding_owner,
			_pending_listener_order(pending)
		)
	_simple_track.pending_adds.clear()


func _remove_owner_from_type_listeners(owner_id: int) -> void:
	_remove_owner_from_listener_track(_type_track, owner_id, false)


func _remove_owner_from_assignable_type_listeners(owner_id: int) -> void:
	_remove_owner_from_listener_track(_assignable_type_track, owner_id, true)


func _remove_owner_from_simple_listeners(owner_id: int) -> void:
	_remove_owner_from_listener_track(_simple_track, owner_id, false)


func _remove_owner_from_listener_track(track: EventListenerTrack, owner_id: int, assignable: bool) -> void:
	for key: Variant in track.listeners.keys():
		var listeners: Array = _get_registry_array(track.listeners, key)
		_remove_entries_by_owner_id(listeners, owner_id, _event_type_from_key(key), assignable)
		_erase_listener_key_if_empty(track.listeners, key)


func _remove_entry_by_callable(
	listeners: Array,
	on_event: Callable,
	event_type: Script = null,
	assignable: bool = false,
	owner_id: int = 0,
	owner_filter_enabled: bool = true
) -> void:
	var removed: bool = false
	for i: int in range(listeners.size() - 1, -1, -1):
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(listeners[i])
		if entry.callable == on_event and (not owner_filter_enabled or _entry_owner_id(entry) == owner_id):
			listeners.remove_at(i)
			removed = true
	if removed and event_type != null:
		_invalidate_type_dispatch_cache_for_event(event_type, assignable)


func _remove_entries_by_owner_id(
	listeners: Array,
	owner_id: int,
	event_type: Script = null,
	assignable: bool = false
) -> void:
	var removed: bool = false
	for i: int in range(listeners.size() - 1, -1, -1):
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(listeners[i])
		if _entry_owner_id(entry) == owner_id:
			listeners.remove_at(i)
			removed = true
	if removed and event_type != null:
		_invalidate_type_dispatch_cache_for_event(event_type, assignable)


func _erase_listener_key_if_empty(registry: Dictionary, key: Variant) -> void:
	if not registry.has(key):
		return
	var listeners: Array = _get_registry_array(registry, key)
	if listeners != null and listeners.is_empty():
		var _erase_result_818: Variant = registry.erase(key)


func _entry_owner_is_released(entry: Dictionary) -> bool:
	var owner_ref: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "owner_ref")
	return owner_ref != null and _owner_from_ref(owner_ref) == null


func _entry_callable_is_valid(entry: Dictionary) -> bool:
	var callback: Callable = _get_callable_option(entry, "callable")
	return callback.is_valid() and (callback.get_object() == null or is_instance_valid(callback.get_object()))


func _entry_owner_id(entry: Dictionary) -> int:
	var stored_owner_id: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(entry, "owner_id", 0)
	if stored_owner_id != 0:
		return stored_owner_id
	return _owner_id_from_ref(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "owner_ref"))


func _get_pending_owner_id(pending: Dictionary) -> int:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(pending, "owner_id", 0)


func _make_owner_ref(owner: Object) -> WeakRef:
	if owner == null:
		return null
	return weakref(owner)


func _owner_instance_id(owner: Object) -> int:
	if owner == null:
		return 0
	return owner.get_instance_id()


func _owner_from_ref(owner_ref_variant: Variant) -> Object:
	if not (owner_ref_variant is WeakRef):
		return null
	var owner_ref: WeakRef = owner_ref_variant
	return _INSTANCE_GUARD._get_live_object_from_ref(owner_ref)


func _owner_id_from_ref(owner_ref_variant: Variant) -> int:
	var owner: Object = _owner_from_ref(owner_ref_variant)
	if owner == null:
		return 0
	return owner.get_instance_id()


func _listener_entry_matches(entry: Dictionary, on_event: Callable, owner: Object) -> bool:
	if entry.callable != on_event:
		return false
	var owner_id: int = _owner_instance_id(owner)
	if owner_id == 0:
		return _entry_owner_id(entry) == 0
	return _entry_owner_id(entry) == owner_id


func _next_listener_order() -> int:
	_listener_order_counter += 1
	return _listener_order_counter


func _pending_listener_order(pending: Dictionary) -> int:
	if pending.has("order"):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(pending, "order", 0)
	return _next_listener_order()


func _validate_callable_min_args(on_event: Callable, min_args: int, callback_label: String, arg_label: String) -> bool:
	if not on_event.is_valid():
		push_error("[GFTypeEventSystem] 注册的%s无效。" % callback_label)
		return false

	var target_obj: Object = on_event.get_object()
	if target_obj == null:
		return true

	var method_name: StringName = on_event.get_method()
	var methods: Array[Dictionary] = target_obj.get_method_list()
	for m: Dictionary in methods:
		if m["name"] == String(method_name):
			var args: Array = _get_registry_array(m, "args")
			var default_args: Array = _get_registry_array(m, "default_args")
			var required_arg_count: int = maxi(args.size() - default_args.size(), 0)
			var provided_arg_count: int = min_args + on_event.get_bound_arguments_count()
			var accepts_varargs: bool = (_GF_VARIANT_ACCESS_SCRIPT.get_option_int(m, "flags", 0) & METHOD_FLAG_VARARG) != 0
			if args.size() < min_args:
				push_error("[GFTypeEventSystem] 注册的%s %s 必须至少包含 %d 个参数用于接收%s！" % [
					callback_label,
					method_name,
					min_args,
					arg_label,
				])
				return false
			if not accepts_varargs and args.size() < provided_arg_count:
				push_error("[GFTypeEventSystem] 注册的%s %s 最多接收 %d 个参数，当前会传入 %d 个。" % [
					callback_label,
					method_name,
					args.size(),
					provided_arg_count,
				])
				return false
			if required_arg_count > provided_arg_count:
				push_error("[GFTypeEventSystem] 注册的%s %s 不能要求超过 %d 个未绑定参数，当前必填 %d 个。" % [
					callback_label,
					method_name,
					min_args,
					required_arg_count - on_event.get_bound_arguments_count(),
				])
				return false
			break
	return true


func _validate_simple_event_id(event_id: StringName, operation: String) -> bool:
	if event_id != &"":
		return true
	push_error("[GFTypeEventSystem] %s 失败：event_id 不能为空。" % operation)
	return false


func _invalidate_type_dispatch_cache_for_event(event_type: Script, assignable: bool) -> void:
	if event_type == null:
		_invalidate_type_dispatch_cache()
		return
	if not assignable:
		var _erase_result_937: Variant = _type_dispatch_cache.erase(event_type)
		return

	var cached_event_types: Array = _type_dispatch_cache.keys()
	for cached_event_type_variant: Variant in cached_event_types:
		var cached_event_type: Script = _variant_to_script(cached_event_type_variant)
		if cached_event_type != null and _script_extends_or_equals(cached_event_type, event_type):
			var _erase_result_944: Variant = _type_dispatch_cache.erase(cached_event_type)


func _invalidate_type_dispatch_cache() -> void:
	_type_dispatch_cache.clear()


func _compact_released_owner_entries(track: EventListenerTrack, assignable: bool, defer_remove: bool) -> int:
	var compacted_count: int = 0
	for key: Variant in track.listeners.keys():
		var listeners: Array = _get_registry_array(track.listeners, key)
		for index: int in range(listeners.size() - 1, -1, -1):
			var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(listeners[index])
			if not _entry_owner_is_released(entry):
				continue
			compacted_count += 1
			var callback: Callable = _get_callable_option(entry, "callable")
			if defer_remove:
				track.queue_remove(key, callback, _entry_owner_id(entry), true)
			else:
				listeners.remove_at(index)
				var event_type: Script = _event_type_from_key(key)
				if event_type != null:
					_invalidate_type_dispatch_cache_for_event(event_type, assignable)
		if not defer_remove:
			_erase_listener_key_if_empty(track.listeners, key)
	return compacted_count


# --- 内部类 ---

## EventListenerTrack: 派发期间监听器变更的暂存轨道。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
class EventListenerTrack:
	## 监听器字典使用的键字段名。
	## [br]
	## @api framework_internal
	var key_field: StringName = &""

	## 已落地的监听器映射。
	## [br]
	## @api framework_internal
	## [br]
	## @schema listeners: Dictionary keyed by Script or StringName, storing ordered listener entry arrays.
	var listeners: Dictionary = {}

	## 派发期间暂存的监听注册列表。
	## [br]
	## @api framework_internal
	## [br]
	## @schema pending_adds: Array of Dictionary listener registration records.
	var pending_adds: Array[Dictionary] = []

	## 派发期间暂存的监听注销列表。
	## [br]
	## @api framework_internal
	## [br]
	## @schema pending_removes: Array of Dictionary listener removal records.
	var pending_removes: Array[Dictionary] = []

	## 派发期间暂存的 owner 注销列表。
	## [br]
	## @api framework_internal
	var pending_owner_removes: Array[int] = []

	func _init(p_key_field: StringName) -> void:
		key_field = p_key_field

	## 暂存派发中的监听注册。
	## [br]
	## @api framework_internal
	## [br]
	## @param key: 监听轨道键。
	## [br]
	## @schema key: Script or StringName listener key matching key_field.
	## [br]
	## @param on_event: 事件回调。
	## [br]
	## @param priority: 类型事件优先级。
	## [br]
	## @param owner_ref: 监听 owner 弱引用。
	## [br]
	## @param owner_id: 监听 owner 实例 ID。
	## [br]
	## @param order: 注册顺序。
	func queue_add(
		key: Variant,
		on_event: Callable,
		priority: int,
		owner_ref: WeakRef,
		owner_id: int,
		order: int
	) -> void:
		var pending: Dictionary = {
			"callable": on_event,
			"priority": priority,
			"owner_ref": owner_ref,
			"owner_id": owner_id,
			"order": order,
		}
		pending[key_field] = key
		pending_adds.append(pending)

	## 暂存派发中的监听注销。
	## [br]
	## @api framework_internal
	## [br]
	## @param key: 监听轨道键。
	## [br]
	## @schema key: Script or StringName listener key matching key_field.
	## [br]
	## @param on_event: 要注销的事件回调。
	## [br]
	## @param owner_id: 要匹配的监听 owner 实例 ID；0 表示无 owner。
	## [br]
	## @param owner_filter_enabled: 是否要求 owner_id 精确匹配。
	func queue_remove(
		key: Variant,
		on_event: Callable,
		owner_id: int = 0,
		owner_filter_enabled: bool = true
	) -> void:
		var pending: Dictionary = {
			"callable": on_event,
			"owner_id": owner_id,
			"owner_filter_enabled": owner_filter_enabled,
		}
		pending[key_field] = key
		pending_removes.append(pending)

	## 移除同一派发周期内尚未落地的注册。
	## [br]
	## @api framework_internal
	## [br]
	## @param key: 监听轨道键。
	## [br]
	## @schema key: Script or StringName listener key matching key_field.
	## [br]
	## @param on_event: 要移除的事件回调。
	## [br]
	## @param owner_id: 要匹配的监听 owner 实例 ID；0 表示无 owner。
	## [br]
	## @param owner_filter_enabled: 是否要求 owner_id 精确匹配。
	func remove_pending_add(
		key: Variant,
		on_event: Callable,
		owner_id: int = 0,
		owner_filter_enabled: bool = true
	) -> void:
		for i: int in range(pending_adds.size() - 1, -1, -1):
			var pending_variant: Variant = pending_adds[i]
			if not (pending_variant is Dictionary):
				continue
			var pending: Dictionary = pending_variant
			var pending_key: Variant = pending[key_field] if pending.has(key_field) else null
			var pending_callable: Variant = pending["callable"] if pending.has("callable") else Callable()
			var pending_owner_id: int = _get_owner_id_from_pending(pending)
			if (
				pending_key == key
				and pending_callable == on_event
				and (not owner_filter_enabled or pending_owner_id == owner_id)
			):
				pending_adds.remove_at(i)

	## 移除指定 owner 在同一派发周期内尚未落地的注册。
	## [br]
	## @api framework_internal
	## [br]
	## @param owner_id: 监听 owner 实例 ID。
	func remove_pending_adds_for_owner_id(owner_id: int) -> void:
		for i: int in range(pending_adds.size() - 1, -1, -1):
			var pending_variant: Variant = pending_adds[i]
			if not (pending_variant is Dictionary):
				continue
			var pending: Dictionary = pending_variant
			var pending_owner_id: int = _get_owner_id_from_pending(pending)
			if pending_owner_id == owner_id:
				pending_adds.remove_at(i)

	## 查询指定监听是否已暂存注销。
	## [br]
	## @api framework_internal
	## [br]
	## @param key: 监听轨道键。
	## [br]
	## @schema key: Script or StringName listener key matching key_field.
	## [br]
	## @param on_event: 要查询的事件回调。
	## [br]
	## @param owner_id: 要匹配的监听 owner 实例 ID；0 表示无 owner。
	## [br]
	## @param owner_filter_enabled: 是否要求 owner_id 精确匹配。
	## [br]
	## @return 已暂存注销时返回 true。
	func has_pending_remove(
		key: Variant,
		on_event: Callable,
		owner_id: int = 0,
		owner_filter_enabled: bool = true
	) -> bool:
		for pending: Dictionary in pending_removes:
			var pending_key: Variant = pending[key_field] if pending.has(key_field) else null
			var pending_callable: Variant = pending["callable"] if pending.has("callable") else Callable()
			var pending_owner_filter_enabled: bool = true
			if pending.has("owner_filter_enabled") and pending["owner_filter_enabled"] is bool:
				pending_owner_filter_enabled = pending["owner_filter_enabled"]
			var pending_owner_id: int = _get_owner_id_from_pending(pending)
			if (
				pending_key == key
				and pending_callable == on_event
				and (
					not pending_owner_filter_enabled
					or not owner_filter_enabled
					or pending_owner_id == owner_id
				)
			):
				return true
		return false

	func _get_owner_id_from_pending(pending: Dictionary) -> int:
		if not pending.has("owner_id"):
			return 0
		var owner_id_value: Variant = pending["owner_id"]
		if owner_id_value is int:
			var owner_id: int = owner_id_value
			return owner_id
		if owner_id_value is float:
			var owner_id_float: float = owner_id_value
			return int(owner_id_float)
		return 0

	## 暂存 owner 注销，重复 owner 只记录一次。
	## [br]
	## @api framework_internal
	## [br]
	## @param owner_id: 监听 owner 实例 ID。
	func append_unique_owner_remove(owner_id: int) -> void:
		if not pending_owner_removes.has(owner_id):
			pending_owner_removes.append(owner_id)

	## 清空已落地监听器和所有暂存操作。
	## [br]
	## @api framework_internal
	func clear_all() -> void:
		listeners.clear()
		clear_pending()

	## 清空所有暂存操作。
	## [br]
	## @api framework_internal
	func clear_pending() -> void:
		pending_adds.clear()
		pending_removes.clear()
		pending_owner_removes.clear()
