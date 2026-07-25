## 测试 GFTypeEventSystem 的注册、发送、注销及遍历中注销的边界情况。
extends GutTest


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

# --- 私有变量 ---

var _system: GFTypeEventSystem


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_system = GFTypeEventSystem.new()


func after_each() -> void:
	_system.clear()
	_system = null


# --- 私有/辅助方法 ---

func _type_listener(callback: Callable, debug_label: String = "type_event") -> GFEventListener:
	return GFEventListener.from_callable(callback, 1, debug_label)


func _simple_listener(callback: Callable, debug_label: String = "simple_event") -> GFEventListener:
	return GFEventListener.from_callable(callback, 1, debug_label)


func _clear_state_callbacks(state: EventTestState) -> void:
	state.cb_a = Callable()
	state.cb_b = Callable()
	state.late_cb = Callable()
	state.replacement = Callable()


# --- 辅助类型 ---

class SampleEventA:
	var value: int = 0
	var is_consumed: bool = false


class SampleEventB:
	pass


class SampleEventChild extends SampleEventA:
	pass


class EventTestState:
	var value: int = -1
	var count: int = 0
	var assignable: int = 0
	var exact: int = 0
	var child: int = 0
	var other: int = 0
	var typed: int = 0
	var simple: int = 0
	var nested_sent: bool = false
	var called: bool = false
	var payload: Variant = null
	var order: Array[String] = []
	var cb_a: Callable = Callable()
	var cb_b: Callable = Callable()
	var late_cb: Callable = Callable()
	var replacement: Callable = Callable()

class SimpleReceiver:
	var payload: Variant = null

	func on_simple_event(p_payload: Variant) -> void:
		payload = p_payload


class ArgumentReceiver:
	var count: int = 0

	func on_type_one(_event: SampleEventA) -> void:
		count += 1

	func on_type_extra_required(_event: SampleEventA, _extra: Variant) -> void:
		count += 1

	func on_type_extra_default(_event: SampleEventA, _extra: Variant = null) -> void:
		count += 1

	func on_simple_extra_required(_payload: Variant, _extra: Variant) -> void:
		count += 1


class OwnedUnregisterReceiver:
	var system: GFTypeEventSystem
	var state: EventTestState
	var target_owner: Object
	var type_listener: GFEventListener = null
	var simple_listener: GFEventListener = null

	func on_type_event(_event: SampleEventA) -> void:
		state.count += 1
		if state.count == 1:
			system.unregister_owned(target_owner, SampleEventA, type_listener)

	func on_simple_event(_payload: Variant) -> void:
		state.simple += 1
		if state.simple == 1:
			system.unregister_simple_owned(target_owner, &"owned_simple", simple_listener)


# --- 测试：类型事件 ---

## 验证无效监听器不会通过 assert 造成不一致行为，而是输出错误并跳过注册。
func test_register_invalid_listener_reports_error_without_registration() -> void:
	_system.register(SampleEventA, _type_listener(Callable()))
	_system.send(SampleEventA.new())

	assert_push_error("[GFEventListener] 注册的类型事件回调无效。")


## 验证监听器必须显式声明当前派发形态会传入的参数数量。
func test_register_rejects_listener_with_mismatched_dispatch_argument_count() -> void:
	var state: EventTestState = EventTestState.new()
	var listener: GFEventListener = GFEventListener.from_callable(
		func() -> void:
			state.called = true,
		0,
		"no_event_arg"
	)

	_system.register(SampleEventA, listener)
	_system.send(SampleEventA.new())

	assert_false(state.called, "派发参数契约不匹配的监听器不应被注册。")
	assert_push_error("[GFEventListener] 注册的类型事件回调 no_event_arg 声明接收 0 个派发参数，但当前事件会传入 1 个。")


## 验证事件回调不能要求比派发参数更多的未绑定必填参数。
func test_register_rejects_callback_requiring_extra_unbound_args() -> void:
	var receiver: ArgumentReceiver = ArgumentReceiver.new()

	_system.register(SampleEventA, _type_listener(Callable(receiver, "on_type_extra_required")))
	_system.send(SampleEventA.new())

	assert_eq(receiver.count, 0, "必填参数过多的回调不应被注册。")
	assert_push_error("[GFEventListener] 注册的类型事件回调 on_type_extra_required 不能要求超过 1 个未绑定参数，当前必填 2 个。")


## 验证默认参数或绑定参数可以满足额外参数需求。
func test_register_accepts_default_or_bound_extra_args() -> void:
	var receiver: ArgumentReceiver = ArgumentReceiver.new()

	_system.register(SampleEventA, _type_listener(Callable(receiver, "on_type_extra_default")))
	_system.register(SampleEventA, _type_listener(Callable(receiver, "on_type_extra_required").bind("bound")))
	_system.send(SampleEventA.new())

	assert_eq(receiver.count, 2, "默认参数和 bind 参数都应允许回调正常注册。")


func test_register_rejects_bound_args_that_exceed_callback_arity() -> void:
	var receiver: ArgumentReceiver = ArgumentReceiver.new()

	_system.register(SampleEventA, _type_listener(Callable(receiver, "on_type_one").bind("too_much")))
	_system.send(SampleEventA.new())

	assert_eq(receiver.count, 0, "bind 后实参超过目标方法参数数量时不应注册。")
	assert_push_error("[GFEventListener] 注册的类型事件回调 on_type_one 最多接收 1 个参数，当前会传入 2 个。")


## 验证简单事件也会拒绝必填参数过多的回调。
func test_register_simple_rejects_callback_requiring_extra_unbound_args() -> void:
	var receiver: ArgumentReceiver = ArgumentReceiver.new()

	_system.register_simple(&"simple_extra_required", _simple_listener(Callable(receiver, "on_simple_extra_required")))
	_system.send_simple(&"simple_extra_required", "payload")

	assert_eq(receiver.count, 0, "必填参数过多的简单事件回调不应被注册。")
	assert_push_error("[GFEventListener] 注册的简单事件回调 on_simple_extra_required 不能要求超过 1 个未绑定参数，当前必填 2 个。")


## 验证注册后，send 能正确调用回调。
func test_register_and_send() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA
	_system.register(script_a, _type_listener(func(e: SampleEventA) -> void: state.value = e.value))

	var evt: SampleEventA = SampleEventA.new()
	evt.value = 42
	_system.send(evt)

	assert_eq(state.value, 42, "回调应接收到事件并读取 value。")


## 验证普通类型事件保持精确脚本匹配。
func test_exact_listener_does_not_receive_child_event() -> void:
	var state: EventTestState = EventTestState.new()
	_system.register(
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			state.count += 1,
		)
	)

	_system.send(SampleEventChild.new())

	assert_eq(state.count, 0, "普通 register 应保持精确类型匹配。")


## 验证可赋值类型监听能收到子类事件。
func test_assignable_listener_receives_child_event() -> void:
	var state: EventTestState = EventTestState.new()
	_system.register_assignable(
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			state.count += 1,
		)
	)

	_system.send(SampleEventChild.new())

	assert_eq(state.count, 1, "register_assignable 应接收继承自基类的事件。")


## 验证类型事件派发缓存会在注册和注销后刷新。
func test_type_dispatch_cache_updates_after_register_and_unregister() -> void:
	var state: EventTestState = EventTestState.new()
	var assignable_callback: Callable = func(_e: SampleEventA) -> void:
		state.assignable += 1
	var exact_callback: Callable = func(_e: SampleEventChild) -> void:
		state.exact += 1

	_system.register_assignable(SampleEventA, _type_listener(assignable_callback))
	_system.send(SampleEventChild.new())
	_system.register(SampleEventChild, _type_listener(exact_callback))
	_system.send(SampleEventChild.new())
	_system.unregister_assignable(SampleEventA, _type_listener(assignable_callback))
	_system.send(SampleEventChild.new())

	assert_eq(state.assignable, 2, "注销可赋值监听后缓存不应继续触发旧回调。")
	assert_eq(state.exact, 2, "后续新增的精确监听应进入刷新后的缓存。")


## 验证类型事件派发缓存只刷新受影响的类型条目。
func test_type_dispatch_cache_invalidates_only_affected_entries() -> void:
	var state: EventTestState = EventTestState.new()
	var child_callback: Callable = func(_e: SampleEventA) -> void:
		state.child += 1
	var other_callback: Callable = func(_e: SampleEventB) -> void:
		state.other += 1

	_system.register_assignable(SampleEventA, _type_listener(child_callback))
	_system.register(SampleEventB, _type_listener(other_callback))
	_system.send(SampleEventChild.new())
	_system.send(SampleEventB.new())

	assert_true(_system._type_dispatch_cache.has(SampleEventChild), "子类事件派发后应建立缓存。")
	assert_true(_system._type_dispatch_cache.has(SampleEventB), "独立事件派发后应建立缓存。")

	_system.register(
		SampleEventB,
		_type_listener(func(_e: SampleEventB) -> void:
			state.other += 10,
		)
	)

	assert_true(_system._type_dispatch_cache.has(SampleEventChild), "独立精确监听变更不应清掉子类事件缓存。")
	assert_false(_system._type_dispatch_cache.has(SampleEventB), "精确监听变更应刷新对应事件缓存。")

	_system.send(SampleEventB.new())
	_system.register_assignable(
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			state.child += 10,
		)
	)

	assert_false(_system._type_dispatch_cache.has(SampleEventChild), "可赋值监听变更应刷新继承事件缓存。")
	assert_true(_system._type_dispatch_cache.has(SampleEventB), "不相关事件缓存应保留。")

	_system.send(SampleEventChild.new())

	assert_eq(state.child, 12, "刷新后的子类事件缓存应包含新增可赋值监听。")


## 验证可赋值类型监听可注销。
func test_unregister_assignable_listener() -> void:
	var state: EventTestState = EventTestState.new()
	var callback: Callable = func(_e: SampleEventA) -> void:
		state.count += 1
	_system.register_assignable(SampleEventA, _type_listener(callback))
	_system.unregister_assignable(SampleEventA, _type_listener(callback))

	_system.send(SampleEventChild.new())

	assert_eq(state.count, 0, "unregister_assignable 后不应再收到子类事件。")


## 验证 owner 注销会移除可赋值类型监听。
func test_unregister_owner_removes_assignable_listeners() -> void:
	var listener_owner: RefCounted = RefCounted.new()
	var state: EventTestState = EventTestState.new()
	_system.register_assignable_owned(
		listener_owner,
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			state.count += 1,
		),
		0
	)

	_system.send(SampleEventChild.new())
	_system.unregister_owner(listener_owner)
	_system.send(SampleEventChild.new())

	assert_eq(state.count, 1, "owner 注销后可赋值类型监听不应继续触发。")


## 验证相同 Callable 可以用不同 owner 注册为独立监听。
func test_same_callable_can_register_with_different_owners() -> void:
	var owner_a: RefCounted = RefCounted.new()
	var owner_b: RefCounted = RefCounted.new()
	var state: EventTestState = EventTestState.new()
	var callback: Callable = func(_e: SampleEventA) -> void:
		state.count += 1

	_system.register_owned(owner_a, SampleEventA, _type_listener(callback), 0)
	_system.register_owned(owner_b, SampleEventA, _type_listener(callback), 0)
	_system.send(SampleEventA.new())
	_system.unregister_owner(owner_a)
	_system.send(SampleEventA.new())

	assert_eq(state.count, 3, "不同 owner 的同一 Callable 应分别注册并可独立注销。")


## 验证普通 unregister 不会误删带 owner 的同 Callable 监听。
func test_unregister_without_owner_does_not_remove_owned_listener() -> void:
	var listener_owner: RefCounted = RefCounted.new()
	var state: EventTestState = EventTestState.new()
	var callback: Callable = func(_e: SampleEventA) -> void:
		state.count += 1

	_system.register_owned(listener_owner, SampleEventA, _type_listener(callback), 0)
	_system.unregister(SampleEventA, _type_listener(callback))
	_system.send(SampleEventA.new())
	_system.unregister_owned(listener_owner, SampleEventA, _type_listener(callback))
	_system.send(SampleEventA.new())

	assert_eq(state.count, 1, "普通 unregister 只应移除无 owner 监听，owned 监听需用 unregister_owned。")


## 验证派发中按 owner 注销同 Callable 监听不会跳过或误删其它 owner。
func test_unregister_owned_during_dispatch_matches_owner() -> void:
	var owner_a: RefCounted = RefCounted.new()
	var owner_b: RefCounted = RefCounted.new()
	var state: EventTestState = EventTestState.new()
	var receiver: OwnedUnregisterReceiver = OwnedUnregisterReceiver.new()
	receiver.system = _system
	receiver.state = state
	receiver.target_owner = owner_b
	receiver.type_listener = _type_listener(Callable(receiver, &"on_type_event"))

	_system.register_owned(owner_a, SampleEventA, receiver.type_listener, 0)
	_system.register_owned(owner_b, SampleEventA, receiver.type_listener, 0)
	_system.send(SampleEventA.new())
	_system.send(SampleEventA.new())

	assert_eq(state.count, 2, "派发中注销 owner_b 后，本轮和后续派发都不应再调用 owner_b 的监听。")


## 验证简单事件派发中的 owner 精确注销同样按 owner 匹配。
func test_unregister_simple_owned_during_dispatch_matches_owner() -> void:
	var owner_a: RefCounted = RefCounted.new()
	var owner_b: RefCounted = RefCounted.new()
	var state: EventTestState = EventTestState.new()
	var receiver: OwnedUnregisterReceiver = OwnedUnregisterReceiver.new()
	receiver.system = _system
	receiver.state = state
	receiver.target_owner = owner_b
	receiver.simple_listener = _simple_listener(Callable(receiver, &"on_simple_event"))

	_system.register_simple_owned(owner_a, &"owned_simple", receiver.simple_listener)
	_system.register_simple_owned(owner_b, &"owned_simple", receiver.simple_listener)
	_system.send_simple(&"owned_simple")
	_system.send_simple(&"owned_simple")

	assert_eq(state.simple, 2, "简单事件派发中注销 owner_b 后不应影响 owner_a。")


## 验证诊断统计会报告各事件轨道监听数量。
func test_debug_stats_reports_listener_counts() -> void:
	_system.register(
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			pass,
		)
	)
	_system.register_assignable(
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			pass,
		)
	)
	_system.register_simple(
		&"debug_simple",
		_simple_listener(func(_payload: Variant) -> void:
			pass,
		)
	)

	var stats: Dictionary = _system.get_debug_stats()

	assert_eq(_sum_listener_counts(_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(stats, "type_events")), 1, "诊断统计应包含精确类型监听数量。")
	assert_eq(_sum_listener_counts(_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(stats, "assignable_type_events")), 1, "诊断统计应包含可赋值类型监听数量。")
	assert_eq(_sum_listener_counts(_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(stats, "simple_events")), 1, "诊断统计应包含简单事件监听数量。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(stats, "listener_count"), 3, "诊断统计应报告总监听器数量。")


func test_listener_diagnostics_reports_stale_owner_entries_and_compacts() -> void:
	var listener_owner: RefCounted = RefCounted.new()
	var state: EventTestState = EventTestState.new()
	_system.register_owned(
		listener_owner,
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			state.count += 1,
		),
		0
	)
	_system.register_simple_owned(
		listener_owner,
		&"stale_owner_simple",
		_simple_listener(func(_payload: Variant) -> void:
			state.simple += 1,
		)
	)

	listener_owner = null
	var diagnostics: Dictionary = _system.get_listener_diagnostics({
		"include_entries": true,
	})
	var tracks: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(diagnostics, "tracks")
	var type_track: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(tracks, "type")
	var simple_track: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(tracks, "simple")
	var type_entries: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(type_track, "entries")
	var first_type_entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(type_entries[0])

	assert_false(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(diagnostics, "ok"), "存在已释放 owner 时诊断不应 ok。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(diagnostics, "listener_count"), 2, "诊断应统计所有轨道监听器。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(diagnostics, "stale_owner_count"), 2, "诊断应统计已释放 owner。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(type_track, "stale_owner_count"), 1, "类型轨道应报告 stale owner。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(simple_track, "stale_owner_count"), 1, "简单事件轨道应报告 stale owner。")
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(first_type_entry, "owner_released"), "明细条目应暴露 owner_released。")
	assert_true(_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(first_type_entry, "callable_valid"), "owner 释放不代表 Callable 本身无效。")

	var compacted_count: int = _system.compact_released_owner_listeners()
	var compacted_diagnostics: Dictionary = _system.get_listener_diagnostics()

	assert_eq(compacted_count, 2, "compact 应移除所有已释放 owner 的监听器。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(compacted_diagnostics, "listener_count"), 0, "compact 后不应残留监听器。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(compacted_diagnostics, "stale_owner_count"), 0, "compact 后不应残留 stale owner。")


## 验证诊断统计会报告派发次数和嵌套深度。
func test_debug_stats_reports_dispatch_counts_and_depth() -> void:
	var state: EventTestState = EventTestState.new()
	_system.register(
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			if not state.nested_sent:
				state.nested_sent = true
				_system.send(SampleEventA.new()),
		)
	)
	_system.register_simple(
		&"debug_depth",
		_simple_listener(func(_payload: Variant) -> void:
			if state.nested_sent:
				return,
		)
	)

	_system.send(SampleEventA.new())
	_system.send_simple(&"debug_depth")
	var stats: Dictionary = _system.get_debug_stats()

	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(stats, "type_dispatch_count"), 2, "嵌套类型事件应记录两次派发。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(stats, "max_type_dispatch_depth_observed"), 2, "嵌套类型事件应记录最大深度。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(stats, "simple_dispatch_count"), 1, "简单事件派发次数应记录到诊断统计。")


## 验证最大派发深度能阻止递归事件无限嵌套。
func test_max_dispatch_depth_defaults_to_guarded_value() -> void:
	var stats: Dictionary = _system.get_debug_stats()

	assert_eq(_system.max_dispatch_depth, GFTypeEventSystem.DEFAULT_MAX_DISPATCH_DEPTH, "2.0 默认应启用事件嵌套保护。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(stats, "max_dispatch_depth"), GFTypeEventSystem.DEFAULT_MAX_DISPATCH_DEPTH, "诊断统计应报告默认最大派发深度。")


## 验证显式关闭最大派发深度时，有限递归事件仍可完整派发。
func test_max_dispatch_depth_can_be_disabled_explicitly() -> void:
	_system.max_dispatch_depth = 0
	var state: EventTestState = EventTestState.new()
	_system.register(
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			state.count += 1
			if state.count < 3:
				_system.send(SampleEventA.new()),
		)
	)

	_system.send(SampleEventA.new())
	var stats: Dictionary = _system.get_debug_stats()

	assert_eq(state.count, 3, "显式设置 0 后应允许项目自己的有限递归事件链。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(stats, "max_dispatch_depth"), 0, "诊断统计应报告保护已关闭。")


## 验证最大派发深度能阻止递归事件无限嵌套。
func test_max_dispatch_depth_stops_recursive_type_dispatch() -> void:
	_system.max_dispatch_depth = 1
	var state: EventTestState = EventTestState.new()
	_system.register(
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			state.count += 1
			_system.send(SampleEventA.new()),
		)
	)

	_system.send(SampleEventA.new())
	var stats: Dictionary = _system.get_debug_stats()

	assert_eq(state.count, 1, "达到最大深度后不应继续递归派发。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(stats, "type_dispatch_count"), 1, "被深度保护拒绝的派发不应计入成功派发次数。")
	assert_push_error("[GFTypeEventSystem] type 事件派发超过最大嵌套深度 1")


## 验证派发追踪会按容量保留最近记录。
func test_dispatch_trace_records_recent_events() -> void:
	_system.trace_enabled = true
	_system.max_trace_entries = 2
	_system.register(
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			pass,
		)
	)

	_system.send_simple(&"missing_trace_event")
	_system.send(SampleEventA.new())
	_system.send_simple(&"missing_trace_event_2")
	var trace: Array = _system.get_dispatch_trace()
	var first_trace_entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(trace[0])
	var second_trace_entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(trace[1])

	assert_eq(trace.size(), 2, "追踪记录应按容量保留最近条目。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(first_trace_entry, "track"), "type", "较旧的简单事件应被容量淘汰。")
	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(second_trace_entry, "event"), "missing_trace_event_2", "最新简单事件应保留。")

	_system.clear_dispatch_trace()
	assert_true(_system.get_dispatch_trace().is_empty(), "clear_dispatch_trace 应清空追踪记录。")


## 验证 unregister 后，send 不再调用该回调。
func test_unregister() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA
	var cb: Callable = func(_e: SampleEventA) -> void: state.count += 1

	_system.register(script_a, _type_listener(cb))
	_system.unregister(script_a, _type_listener(cb))
	_system.send(SampleEventA.new())

	assert_eq(state.count, 0, "注销后不应再被调用。")


## 验证在回调 A 内注销回调 B 时，回调 B 在本次 send 中不被执行（遍历中注销边界情况）。
func test_unregister_during_traversal() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA

	var cb_a: Callable = func(_e: SampleEventA) -> void:
		state.order.append("A")
		_system.unregister(script_a, _type_listener(state.cb_b))

	state.cb_b = func(_e: SampleEventA) -> void:
		state.order.append("B")

	_system.register(script_a, _type_listener(cb_a))
	_system.register(script_a, _type_listener(state.cb_b))
	_system.send(SampleEventA.new())

	assert_eq(state.order.size(), 1, "回调 B 被注销后不应在本次 send 中执行。")
	assert_eq(state.order[0], "A", "只有回调 A 应被执行。")
	_clear_state_callbacks(state)


## 验证在回调内注销自身时，不会崩溃且逻辑正确。
func test_unregister_self_during_traversal() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA

	state.cb_a = func(_e: SampleEventA) -> void:
		state.count += 1
		_system.unregister(script_a, _type_listener(state.cb_a))

	_system.register(script_a, _type_listener(state.cb_a))
	_system.send(SampleEventA.new())
	_system.send(SampleEventA.new())

	assert_eq(state.count, 1, "回调应该只执行一次，并在本次调用后注销自身。")
	_clear_state_callbacks(state)


## 验证多个监听器都能收到事件。
func test_multiple_listeners() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA
	_system.register(script_a, _type_listener(func(_e: SampleEventA) -> void: state.count += 1))
	_system.register(script_a, _type_listener(func(_e: SampleEventA) -> void: state.count += 1))
	_system.send(SampleEventA.new())

	assert_eq(state.count, 2, "两个监听器都应被调用。")


## 验证 clear 后，send 不再触发任何回调。
func test_clear() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA
	_system.register(script_a, _type_listener(func(_e: SampleEventA) -> void: state.called = true))
	_system.clear()
	_system.send(SampleEventA.new())

	assert_false(state.called, "clear 后不应再触发回调。")


## 验证类型事件派发中 clear 不会破坏派发深度计数。
func test_clear_during_type_dispatch_stops_current_dispatch_safely() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA
	_system.register(
		script_a,
		_type_listener(func(_e: SampleEventA) -> void:
			state.order.append("first")
			_system.clear(),
		)
	)
	_system.register(
		script_a,
		_type_listener(func(_e: SampleEventA) -> void:
			state.order.append("second"),
		)
	)

	_system.send(SampleEventA.new())
	_system.send(SampleEventA.new())

	assert_eq(state.order, ["first"], "clear 后本轮后续监听与下一轮派发都不应触发。")
	assert_eq(_system._type_dispatch_depth, 0, "clear 不应让类型事件派发深度变成负数。")


# --- 测试：简单事件 ---

## 验证简单事件注册与发送。
func test_send_simple_register_and_send() -> void:
	var state: EventTestState = EventTestState.new()
	var event_id: StringName = &"test_event"

	_system.register_simple(event_id, _simple_listener(func(p: Variant) -> void: state.payload = p))
	_system.send_simple(event_id, 99)

	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.to_int(state.payload), 99, "简单事件回调应接收到正确的 payload。")


func test_register_simple_rejects_empty_event_id() -> void:
	var state: EventTestState = EventTestState.new()

	_system.register_simple(
		&"",
		_simple_listener(func(_payload: Variant) -> void:
			state.called = true,
		)
	)
	_system.send_simple(&"valid_event", 1)

	assert_false(state.called, "空简单事件 ID 不应注册监听。")
	assert_push_error("[GFTypeEventSystem] register_simple 失败：event_id 不能为空。")


func test_send_simple_rejects_empty_event_id() -> void:
	_system.send_simple(&"", 1)

	assert_push_error("[GFTypeEventSystem] send_simple 失败：event_id 不能为空。")


## 验证简单事件支持对象方法回调，并会走签名校验路径。
func test_send_simple_register_method_callback() -> void:
	var receiver: SimpleReceiver = SimpleReceiver.new()
	var event_id: StringName = &"method_simple_event"

	_system.register_simple(event_id, _simple_listener(Callable(receiver, "on_simple_event")))
	_system.send_simple(event_id, "ok")

	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.to_text(receiver.payload), "ok", "对象方法形式的简单事件回调应接收到 payload。")


## 验证简单事件在回调内注销另一回调时，被注销的回调不被执行。
func test_send_simple_unregister_during_traversal() -> void:
	var state: EventTestState = EventTestState.new()
	var event_id: StringName = &"traversal_test"

	var cb_a: Callable = func(_p: Variant) -> void:
		state.order.append("A")
		_system.unregister_simple(event_id, _simple_listener(state.cb_b))

	state.cb_b = func(_p: Variant) -> void:
		state.order.append("B")

	_system.register_simple(event_id, _simple_listener(cb_a))
	_system.register_simple(event_id, _simple_listener(state.cb_b))
	_system.send_simple(event_id)

	assert_eq(state.order.size(), 1, "简单事件：回调 B 被注销后不应在本次 send 中执行。")
	assert_eq(state.order[0], "A", "只有回调 A 应被执行。")
	_clear_state_callbacks(state)


## 验证简单事件回调注销自身时，不会崩溃且逻辑正确。
func test_send_simple_unregister_self_during_traversal() -> void:
	var state: EventTestState = EventTestState.new()
	var event_id: StringName = &"self_traversal_test"

	state.cb_a = func(_p: Variant) -> void:
		state.count += 1
		_system.unregister_simple(event_id, _simple_listener(state.cb_a))

	_system.register_simple(event_id, _simple_listener(state.cb_a))
	_system.send_simple(event_id)
	_system.send_simple(event_id)

	assert_eq(state.count, 1, "回调应该只执行一次，并在本次调用后注销自身。")
	_clear_state_callbacks(state)


## 验证注销简单事件后不再触发。
func test_send_simple_unregister() -> void:
	var state: EventTestState = EventTestState.new()
	var event_id: StringName = &"remove_test"

	var cb: Callable = func(_p: Variant) -> void: state.called = true
	_system.register_simple(event_id, _simple_listener(cb))
	_system.unregister_simple(event_id, _simple_listener(cb))
	_system.send_simple(event_id)

	assert_false(state.called, "注销后简单事件回调不应被触发。")


## 验证简单事件派发中 clear 不会破坏派发深度计数。
func test_clear_during_simple_dispatch_stops_current_dispatch_safely() -> void:
	var state: EventTestState = EventTestState.new()
	var event_id: StringName = &"clear_simple"
	_system.register_simple(
		event_id,
		_simple_listener(func(_p: Variant) -> void:
			state.order.append("first")
			_system.clear(),
		)
	)
	_system.register_simple(
		event_id,
		_simple_listener(func(_p: Variant) -> void:
			state.order.append("second"),
		)
	)

	_system.send_simple(event_id)
	_system.send_simple(event_id)

	assert_eq(state.order, ["first"], "clear 后本轮后续简单监听与下一轮派发都不应触发。")
	assert_eq(_system._simple_dispatch_depth, 0, "clear 不应让简单事件派发深度变成负数。")


## 验证嵌套简单事件期间注册的新回调不会在当前派发链中提前生效。
func test_send_simple_register_during_nested_dispatch_waits_for_outermost_flush() -> void:
	var state: EventTestState = EventTestState.new()
	var event_id: StringName = &"nested_simple_event"

	state.late_cb = func(_p: Variant) -> void:
		state.order.append("late")

	var cb_outer: Callable = func(_p: Variant) -> void:
		state.order.append("outer")
		if not state.nested_sent:
			state.nested_sent = true
			_system.register_simple(event_id, _simple_listener(state.late_cb))
			_system.send_simple(event_id)

	var cb_existing: Callable = func(_p: Variant) -> void:
		state.order.append("existing")

	_system.register_simple(event_id, _simple_listener(cb_outer))
	_system.register_simple(event_id, _simple_listener(cb_existing))

	_system.send_simple(event_id)

	assert_eq(state.order, ["outer", "outer", "existing", "existing"], "嵌套简单事件期间新增回调应等最外层结束后才生效。")

	_system.send_simple(event_id)
	assert_eq(state.order.slice(4), ["outer", "existing", "late"], "下一次简单事件派发应包含之前新增的回调。")
	_clear_state_callbacks(state)


## 验证同一轮简单事件中先注册再注销的回调不会在 flush 后残留。
func test_send_simple_register_then_unregister_during_dispatch_does_not_leave_listener() -> void:
	var state: EventTestState = EventTestState.new()
	var event_id: StringName = &"register_then_unregister_simple"

	state.late_cb = func(_p: Variant) -> void:
		state.count += 10

	var cb_outer: Callable = func(_p: Variant) -> void:
		state.count += 1
		_system.register_simple(event_id, _simple_listener(state.late_cb))
		_system.unregister_simple(event_id, _simple_listener(state.late_cb))

	_system.register_simple(event_id, _simple_listener(cb_outer))
	_system.send_simple(event_id)
	_system.send_simple(event_id)

	assert_eq(state.count, 2, "同一轮派发中先注册再注销的简单事件回调不应残留到下一次派发。")
	_clear_state_callbacks(state)


## 验证派发中跨简单事件 ID 先注册再注销的回调不会在 flush 后残留。
func test_send_simple_register_then_unregister_different_id_during_dispatch_does_not_leave_listener() -> void:
	var state: EventTestState = EventTestState.new()
	var outer_id: StringName = &"register_then_unregister_simple_outer"
	var inner_id: StringName = &"register_then_unregister_simple_inner"

	state.late_cb = func(_p: Variant) -> void:
		state.count += 10

	var cb_outer: Callable = func(_p: Variant) -> void:
		state.count += 1
		_system.register_simple(inner_id, _simple_listener(state.late_cb))
		_system.unregister_simple(inner_id, _simple_listener(state.late_cb))

	_system.register_simple(outer_id, _simple_listener(cb_outer))
	_system.send_simple(outer_id)
	_system.send_simple(inner_id)

	assert_eq(state.count, 1, "跨简单事件 ID pending add 被注销后不应在下一次派发中触发。")
	_clear_state_callbacks(state)


# --- 测试：拥有者绑定 ---

## 验证注销 owner 会同时移除类型事件和简单事件监听。
func test_unregister_owner_removes_type_and_simple_listeners() -> void:
	var listener_owner: RefCounted = RefCounted.new()
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA
	var event_id: StringName = &"owned_simple"

	_system.register_owned(listener_owner, script_a, _type_listener(func(_e: SampleEventA) -> void: state.typed += 1), 0)
	_system.register_simple_owned(listener_owner, event_id, _simple_listener(func(_p: Variant) -> void: state.simple += 1))

	_system.send(SampleEventA.new())
	_system.send_simple(event_id)
	_system.unregister_owner(listener_owner)
	_system.send(SampleEventA.new())
	_system.send_simple(event_id)

	assert_eq(state.typed, 1, "owner 注销后类型事件不应继续触发。")
	assert_eq(state.simple, 1, "owner 注销后简单事件不应继续触发。")


## 验证派发中注销 owner 会阻止同一 owner 后续监听在本轮继续执行。
func test_unregister_owner_during_dispatch_skips_later_owned_callbacks() -> void:
	var listener_owner: RefCounted = RefCounted.new()
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA

	_system.register_owned(
		listener_owner,
		script_a,
		_type_listener(func(_e: SampleEventA) -> void:
			state.order.append("first")
			_system.unregister_owner(listener_owner),
		),
		10
	)
	_system.register_owned(
		listener_owner,
		script_a,
		_type_listener(func(_e: SampleEventA) -> void:
			state.order.append("second"),
		),
		0
	)

	_system.send(SampleEventA.new())
	_system.send(SampleEventA.new())

	assert_eq(state.order, ["first"], "派发中注销 owner 后，同 owner 后续回调和下一轮回调都不应执行。")


## 验证类型派发中注销 owner 会同时阻止后续可赋值监听。
func test_unregister_owner_during_type_dispatch_skips_later_assignable_callback() -> void:
	var listener_owner: RefCounted = RefCounted.new()
	var state: EventTestState = EventTestState.new()

	_system.register_owned(
		listener_owner,
		SampleEventChild,
		_type_listener(func(_e: SampleEventChild) -> void:
			state.order.append("exact")
			_system.unregister_owner(listener_owner),
		),
		10
	)
	_system.register_assignable_owned(
		listener_owner,
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			state.order.append("assignable"),
		),
		0
	)

	_system.send(SampleEventChild.new())
	_system.send(SampleEventChild.new())

	assert_eq(state.order, ["exact"], "类型派发中注销 owner 后，可赋值轨道的同 owner 后续监听也不应执行。")


## 验证简单事件派发中注销 owner 会阻止同 owner 后续监听。
func test_unregister_owner_during_simple_dispatch_skips_later_owned_callbacks() -> void:
	var listener_owner: RefCounted = RefCounted.new()
	var state: EventTestState = EventTestState.new()
	var event_id: StringName = &"owned_simple_dispatch"

	_system.register_simple_owned(
		listener_owner,
		event_id,
		_simple_listener(func(_p: Variant) -> void:
			state.order.append("first")
			_system.unregister_owner(listener_owner),
		)
	)
	_system.register_simple_owned(
		listener_owner,
		event_id,
		_simple_listener(func(_p: Variant) -> void:
			state.order.append("second"),
		)
	)

	_system.send_simple(event_id)
	_system.send_simple(event_id)

	assert_eq(state.order, ["first"], "简单事件派发中注销 owner 后，同 owner 后续回调和下一轮回调都不应执行。")


## 验证派发中注销 owner 后重新注册的新回调会在下一轮生效。
func test_unregister_owner_then_register_same_owner_during_dispatch_keeps_new_listener() -> void:
	var listener_owner: RefCounted = RefCounted.new()
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA

	state.replacement = func(_e: SampleEventA) -> void:
		state.order.append("replacement")

	_system.register_owned(
		listener_owner,
		script_a,
		_type_listener(func(_e: SampleEventA) -> void:
		state.order.append("old")
		_system.unregister_owner(listener_owner)
		_system.register_owned(listener_owner, script_a, _type_listener(state.replacement), 0),
		),
		10
	)

	_system.send(SampleEventA.new())
	_system.send(SampleEventA.new())

	assert_eq(state.order, ["old", "replacement"], "同一 owner 重新注册的新监听应在下一轮派发生效。")
	_clear_state_callbacks(state)


# --- 测试：优先级排序 ---

## 验证高优先级回调先于低优先级执行。
func test_priority_high_executes_first() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA
	_system.register(script_a, _type_listener(func(_e: SampleEventA) -> void: state.order.append("low")), 0)
	_system.register(script_a, _type_listener(func(_e: SampleEventA) -> void: state.order.append("high")), 10)
	_system.send(SampleEventA.new())

	assert_eq(state.order.size(), 2, "两个回调都应被调用。")
	assert_eq(state.order[0], "high", "高优先级应先执行。")
	assert_eq(state.order[1], "low", "低优先级应后执行。")


## 验证精确监听与可赋值监听按全局优先级合并排序。
func test_exact_and_assignable_listeners_share_priority_order() -> void:
	var state: EventTestState = EventTestState.new()
	_system.register(
		SampleEventChild,
		_type_listener(func(_e: SampleEventChild) -> void:
			state.order.append("exact_low"),
		),
		0
	)
	_system.register_assignable(
		SampleEventA,
		_type_listener(func(_e: SampleEventA) -> void:
			state.order.append("assignable_high"),
		),
		10
	)

	_system.send(SampleEventChild.new())

	assert_eq(state.order, ["assignable_high", "exact_low"], "精确与可赋值监听应按全局 priority 排序。")


## 验证相同优先级保持注册顺序。
func test_same_priority_keeps_registration_order() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA
	_system.register(script_a, _type_listener(func(_e: SampleEventA) -> void: state.order.append("first")), 5)
	_system.register(script_a, _type_listener(func(_e: SampleEventA) -> void: state.order.append("second")), 5)
	_system.send(SampleEventA.new())

	assert_eq(state.order[0], "first", "同优先级应按注册顺序执行。")
	assert_eq(state.order[1], "second", "同优先级应按注册顺序执行。")


# --- 测试：事件消费拦截 ---

## 验证高优先级设置 is_consumed 后，低优先级不被执行。
func test_consumed_event_stops_propagation() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA

	_system.register(
		script_a,
		_type_listener(func(e: SampleEventA) -> void:
			state.order.append("high")
			e.is_consumed = true,
		),
		10
	)

	_system.register(
		script_a,
		_type_listener(func(_e: SampleEventA) -> void:
			state.order.append("low"),
		),
		0
	)

	var evt: SampleEventA = SampleEventA.new()
	_system.send(evt)

	assert_eq(state.order.size(), 1, "消费后应只有高优先级被调用。")
	assert_eq(state.order[0], "high", "只有高优先级回调应执行。")
	assert_true(evt.is_consumed, "事件应被标记为已消费。")


## 验证未设置 is_consumed 时所有优先级正常触发。
func test_unconsumed_event_propagates_to_all() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA
	_system.register(script_a, _type_listener(func(_e: SampleEventA) -> void: state.count += 1), 10)
	_system.register(script_a, _type_listener(func(_e: SampleEventA) -> void: state.count += 1), 5)
	_system.register(script_a, _type_listener(func(_e: SampleEventA) -> void: state.count += 1), 0)
	_system.send(SampleEventA.new())

	assert_eq(state.count, 3, "未消费时所有优先级回调都应被调用。")


## 验证三级优先级中，中间级消费后最低级不执行。
func test_mid_priority_consumes() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA

	_system.register(
		script_a,
		_type_listener(func(_e: SampleEventA) -> void:
			state.order.append("high"),
		),
		10
	)

	_system.register(
		script_a,
		_type_listener(func(e: SampleEventA) -> void:
			state.order.append("mid")
			e.is_consumed = true,
		),
		5
	)

	_system.register(
		script_a,
		_type_listener(func(_e: SampleEventA) -> void:
			state.order.append("low"),
		),
		0
	)

	_system.send(SampleEventA.new())

	assert_eq(state.order.size(), 2, "中间级消费后应只有高和中被调用。")
	assert_eq(state.order[0], "high", "高优先级应先执行。")
	assert_eq(state.order[1], "mid", "中优先级应第二执行。")


# --- 测试：遍历中注册 (Task 6) ---

## 验证在回调内注册新事件，不会破坏当前遍历且能在下次生效。
func test_register_during_traversal() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA

	var cb_inner: Callable = func(_e: SampleEventA) -> void:
		state.count += 10

	var cb_outer: Callable = func(_e: SampleEventA) -> void:
		state.count += 1
		_system.register(script_a, _type_listener(cb_inner))

	_system.register(script_a, _type_listener(cb_outer))

	# 第一次发送：触发 outer，注册 inner
	_system.send(SampleEventA.new())
	assert_eq(state.count, 1, "第一次发送应只触发 outer，inner 暂存。")

	# 第二次发送：触发 outer 和 inner
	_system.send(SampleEventA.new())
	assert_eq(state.count, 12, "第二次发送应触发 outer(1) 和 inner(10)。")


## 验证嵌套发送期间注册的新回调不会在内层或当前外层派发中提前生效。
func test_register_during_nested_dispatch_waits_for_outermost_flush() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA

	state.late_cb = func(_e: SampleEventA) -> void:
		state.order.append("late")

	var cb_outer: Callable = func(_e: SampleEventA) -> void:
		state.order.append("outer")
		if not state.nested_sent:
			state.nested_sent = true
			_system.register(script_a, _type_listener(state.late_cb))
			_system.send(SampleEventA.new())

	var cb_existing: Callable = func(_e: SampleEventA) -> void:
		state.order.append("existing")

	_system.register(script_a, _type_listener(cb_outer))
	_system.register(script_a, _type_listener(cb_existing))

	_system.send(SampleEventA.new())

	assert_eq(state.order, ["outer", "outer", "existing", "existing"], "嵌套派发期间新增回调应等最外层结束后才生效。")

	_system.send(SampleEventA.new())
	assert_eq(state.order.slice(4), ["outer", "existing", "late"], "下一次派发应包含之前新增的回调。")
	_clear_state_callbacks(state)


## 验证同一轮类型事件中先注册再注销的回调不会在 flush 后残留。
func test_register_then_unregister_during_dispatch_does_not_leave_listener() -> void:
	var state: EventTestState = EventTestState.new()
	var script_a: Script = SampleEventA

	state.late_cb = func(_e: SampleEventA) -> void:
		state.count += 10

	var cb_outer: Callable = func(_e: SampleEventA) -> void:
		state.count += 1
		_system.register(script_a, _type_listener(state.late_cb))
		_system.unregister(script_a, _type_listener(state.late_cb))

	_system.register(script_a, _type_listener(cb_outer))
	_system.send(SampleEventA.new())
	_system.send(SampleEventA.new())

	assert_eq(state.count, 2, "同一轮派发中先注册再注销的类型事件回调不应残留到下一次派发。")
	_clear_state_callbacks(state)


## 验证派发中跨事件类型先注册再注销的回调不会在 flush 后残留。
func test_register_then_unregister_different_type_during_dispatch_does_not_leave_listener() -> void:
	var state: EventTestState = EventTestState.new()

	state.late_cb = func(_e: SampleEventB) -> void:
		state.count += 10

	var cb_outer: Callable = func(_e: SampleEventA) -> void:
		state.count += 1
		_system.register(SampleEventB, _type_listener(state.late_cb))
		_system.unregister(SampleEventB, _type_listener(state.late_cb))

	_system.register(SampleEventA, _type_listener(cb_outer))
	_system.send(SampleEventA.new())
	_system.send(SampleEventB.new())

	assert_eq(state.count, 1, "跨事件类型 pending add 被注销后不应在下一次派发中触发。")
	_clear_state_callbacks(state)


## 验证派发中跨可赋值类型先注册再注销的回调不会在 flush 后残留。
func test_register_then_unregister_different_assignable_type_during_dispatch_does_not_leave_listener() -> void:
	var state: EventTestState = EventTestState.new()

	state.late_cb = func(_e: SampleEventB) -> void:
		state.count += 10

	var cb_outer: Callable = func(_e: SampleEventA) -> void:
		state.count += 1
		_system.register_assignable(SampleEventB, _type_listener(state.late_cb))
		_system.unregister_assignable(SampleEventB, _type_listener(state.late_cb))

	_system.register(SampleEventA, _type_listener(cb_outer))
	_system.send(SampleEventA.new())
	_system.send(SampleEventB.new())

	assert_eq(state.count, 1, "跨可赋值类型 pending add 被注销后不应在下一次派发中触发。")
	_clear_state_callbacks(state)


func _sum_listener_counts(value: Variant) -> int:
	var listeners: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(value)
	var total: int = 0
	for count: Variant in listeners.values():
		total += _GF_VARIANT_ACCESS_SCRIPT.to_int(count)
	return total
