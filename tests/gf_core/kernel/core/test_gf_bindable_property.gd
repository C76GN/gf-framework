## 测试 GFBindableProperty 的值绑定、信号触发及 unbind_all 清理功能。
extends GutTest


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _prop: GFBindableProperty


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_prop = GFBindableProperty.new(0)


func after_each() -> void:
	_prop = null


# --- 测试：基本功能 ---

## 验证构造函数设置的初始值正确。
func test_initial_value() -> void:
	var prop_str: GFBindableProperty = GFBindableProperty.new("hello")
	assert_eq(_value_text(prop_str), "hello", "初始值应为构造时传入的值。")


## 验证 get_value 返回当前存储的值。
func test_get_value() -> void:
	_prop.set_value(7)
	assert_eq(_value_int(_prop), 7, "get_value 应返回最新设置的值。")


## 验证 value 属性与 get_value()/set_value() 保持一致。
func test_value_property_gets_and_sets_value() -> void:
	_prop.value = 9

	assert_eq(_value_int(_prop), 9, "value 属性应返回最新设置的值。")
	assert_eq(_value_int(_prop), 9, "value 属性写入应同步到底层值。")


# --- 测试：信号 ---

## 验证设置新值时 value_changed 信号被发出，并携带正确的 old_value 和 new_value。
func test_set_value_emits_signal() -> void:
	watch_signals(_prop)
	_prop.set_value(10)
	assert_signal_emitted_with_parameters(_prop, "value_changed", [0, 10])


## 验证设置相同值时不触发 value_changed 信号。
func test_set_same_value_no_signal() -> void:
	_prop.set_value(5)
	watch_signals(_prop)
	_prop.set_value(5)
	assert_signal_not_emitted(_prop, "value_changed", "设置相同值不应触发 value_changed 信号。")


func test_set_value_compares_incompatible_variant_types_safely() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new(Resource.new())
	watch_signals(prop)

	prop.set_value("resource_id")

	assert_signal_emitted(prop, "value_changed", "Object -> String 应视为变化且不触发 Variant 比较错误。")


func test_set_value_compares_object_to_null_safely() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new(Resource.new())
	watch_signals(prop)

	prop.set_value(null)

	assert_signal_emitted(prop, "value_changed", "Object -> null 应视为变化且不触发 Variant 比较错误。")


func test_set_value_compares_dictionary_to_string_safely() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new({ "id": 1 })
	watch_signals(prop)

	prop.set_value("id:1")

	assert_signal_emitted(prop, "value_changed", "Dictionary -> String 应视为变化且不触发 Variant 比较错误。")


func test_set_value_treats_numeric_variants_as_equal() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new(1)
	watch_signals(prop)

	prop.set_value(1.0)

	assert_signal_not_emitted(prop, "value_changed", "int 与等值 float 不应触发重复变化。")


## 验证信号的 old_value / new_value 参数准确。
func test_signal_parameters_are_correct() -> void:
	_prop.set_value(3)
	watch_signals(_prop)
	_prop.set_value(99)
	var params: Array = get_signal_parameters(_prop, "value_changed")
	assert_eq(_variant_int(params[0]), 3, "old_value 应为变化前的值 3。")
	assert_eq(_variant_int(params[1]), 99, "new_value 应为变化后的值 99。")


func test_subscribe_returns_unsubscribe_callable() -> void:
	var state: CounterState = CounterState.new()
	var unsubscribe: Callable = _prop.subscribe(func(_old_value: Variant, _new_value: Variant) -> void:
		state.count += 1
	)

	_prop.value = 1
	unsubscribe.call()
	_prop.value = 2

	assert_true(unsubscribe.is_valid(), "subscribe 应返回可调用的取消订阅函数。")
	assert_eq(state.count, 1, "取消订阅后回调不应继续触发。")


func test_subscribe_can_emit_current_value_immediately() -> void:
	var values: Array[int] = []

	var unsubscribe: Callable = _prop.subscribe(func(_old_value: Variant, new_value: Variant) -> void:
		values.append(_variant_int(new_value))
	, true)
	_prop.value = 4
	unsubscribe.call()

	assert_eq(values, [0, 4], "emit_current 为 true 时应先推送当前值，再响应后续变化。")


func test_subscribe_rejects_invalid_callback() -> void:
	var unsubscribe: Callable = _prop.subscribe(Callable())

	assert_false(unsubscribe.is_valid(), "无效 callback 不应返回有效取消函数。")
	assert_push_error("[GFBindableProperty] subscribe 失败：callback 无效。")


func test_subscribe_token_cancels_subscription() -> void:
	var state: CounterState = CounterState.new()
	var subscription_token: GFSubscriptionToken = _prop.subscribe_token(func(_old_value: Variant, _new_value: Variant) -> void:
		state.count += 1
	)

	_prop.value = 1
	assert_true(subscription_token.cancel(), "首次 cancel 应返回 true。")
	_prop.value = 2

	assert_false(subscription_token.is_active(), "cancel 后 token 应进入非活动状态。")
	assert_false(subscription_token.cancel(), "重复 cancel 应返回 false。")
	assert_eq(state.count, 1, "token 取消后回调不应继续触发。")


func test_subscribe_owned_auto_cancels_when_owner_exits_tree() -> void:
	var owner_node: Node = Node.new()
	var state: CounterState = CounterState.new()
	add_child_autofree(owner_node)

	var subscription_token: GFLifetimeSubscription = _prop.subscribe_owned(owner_node, func(_old_value: Variant, _new_value: Variant) -> void:
		state.count += 1
	)

	_prop.value = 1
	remove_child(owner_node)
	owner_node.tree_exited.emit()
	_prop.value = 2

	assert_eq(state.count, 1, "owner 退出树后 owned 订阅不应继续触发。")
	assert_false(subscription_token.is_active(), "owner 退出树后 lifetime token 应进入非活动状态。")
	assert_eq(_prop.value_changed.get_connections().size(), 0, "owner 自动取消后不应残留托管信号连接。")
	owner_node.free()


func test_subscribe_owned_prunes_released_non_node_owner() -> void:
	var state: CounterState = CounterState.new()
	var owner_refcounted: RefCounted = RefCounted.new()
	var subscription_token: GFLifetimeSubscription = _prop.subscribe_owned(owner_refcounted, func(_old_value: Variant, _new_value: Variant) -> void:
		state.count += 1
	)

	owner_refcounted = null
	_prop.value = 1

	assert_eq(state.count, 0, "普通 Object owner 释放后应在下一次发射前剪枝订阅。")
	assert_false(subscription_token.is_active(), "owner 释放后 lifetime token 应失活。")
	assert_eq(_prop.value_changed.get_connections().size(), 0, "释放 owner 的订阅剪枝后不应残留托管信号连接。")


func test_subscribe_method_uses_weak_owner_method() -> void:
	var owner_node: SubscriptionMethodOwner = SubscriptionMethodOwner.new()
	add_child_autofree(owner_node)

	var subscription_token: GFLifetimeSubscription = _prop.subscribe_method(owner_node, &"record_value_change", true)
	_prop.value = 4
	var _cancel_result: bool = subscription_token.cancel()
	_prop.value = 5

	assert_eq(owner_node.values, [0, 4], "method 订阅应支持 emit_current 和后续变化。")
	assert_false(subscription_token.is_active(), "手动 cancel 后 method 订阅应失活。")


## 验证 force_emit 可在引用类型原地变更后主动广播。
func test_force_emit_broadcasts_current_value() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new({ "hp": 10 })
	watch_signals(prop)

	var value: Dictionary = _value_dictionary(prop)
	value["hp"] = 5
	prop.force_emit()

	assert_signal_emitted_with_parameters(prop, "value_changed", [value, value])


func test_subscribe_collection_payloads_are_isolated_between_listeners() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new({ "hp": 10 })
	var second_listener_values: Array[Dictionary] = []
	var _unsubscribe_first: Callable = prop.subscribe(func(_old_value: Variant, new_value: Variant) -> void:
		var payload: Dictionary = GFVariantData.as_dictionary(new_value)
		payload["hp"] = 1
	)
	var _unsubscribe_second: Callable = prop.subscribe(func(_old_value: Variant, new_value: Variant) -> void:
		second_listener_values.append(GFVariantData.as_dictionary(new_value))
	)

	prop.set_value({ "hp": 20 })
	var _unsubscribe_first_result: Variant = _unsubscribe_first.call()
	var _unsubscribe_second_result: Variant = _unsubscribe_second.call()

	assert_eq(second_listener_values.size(), 1, "第二个监听者应收到一次变化。")
	if second_listener_values.size() == 1:
		assert_eq(GFVariantData.get_option_int(second_listener_values[0], "hp"), 20, "后续监听者不应看到前一个监听者改写过的集合 payload。")
	assert_eq(GFVariantData.get_option_int(_value_dictionary(prop), "hp"), 20, "监听者改写信号 payload 不应影响属性内部值。")


func test_value_changed_respects_godot_signal_blocking() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new(1)
	var state: CounterState = CounterState.new()
	var _connect_result: Variant = prop.value_changed.connect(func(_old_value: Variant, _new_value: Variant) -> void:
		state.count += 1
	)

	prop.set_block_signals(true)
	prop.set_value(2)
	prop.set_block_signals(false)
	prop.set_value(3)

	assert_eq(state.count, 1, "value_changed 应使用 Godot 原生 signal 发射并尊重 set_block_signals。")


func test_mutate_helper_emits_after_in_place_change() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new({ "hp": 10 })
	watch_signals(prop)

	assert_true(prop.mutate(func(value: Dictionary) -> void:
		value["hp"] = 7
	))

	assert_eq(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(_value_dictionary(prop), "hp"), 7)
	assert_signal_emitted(prop, "value_changed")


func test_array_mutation_helpers_emit_changes() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new([])
	watch_signals(prop)

	assert_true(prop.append_to_array("a"))
	assert_true(prop.append_array(["b", "c"]))
	assert_true(prop.erase_from_array("b"))
	assert_eq(_value_array(prop), ["a", "c"])
	assert_signal_emit_count(prop, "value_changed", 3)


func test_dictionary_mutation_helpers_emit_changes() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new({})
	watch_signals(prop)

	assert_true(prop.set_dictionary_value("hp", 10))
	assert_true(prop.erase_dictionary_key("hp"))
	assert_eq(_value_dictionary(prop), {})
	assert_signal_emit_count(prop, "value_changed", 2)


func test_clear_collection_handles_array_and_dictionary() -> void:
	var array_prop: GFBindableProperty = GFBindableProperty.new([1])
	var dict_prop: GFBindableProperty = GFBindableProperty.new({ "a": 1 })

	assert_true(array_prop.clear_collection())
	assert_true(dict_prop.clear_collection())
	assert_eq(_value_array(array_prop), [])
	assert_eq(_value_dictionary(dict_prop), {})


# --- 测试：解绑 ---

## 验证 unbind_all 只清理 GF 管理的节点绑定，不断开业务层直接订阅。
func test_unbind_all_preserves_direct_subscribers() -> void:
	var state: CounterState = CounterState.new()
	var _connect_result_167: Variant = _prop.value_changed.connect(func(_o: Variant, _n: Variant) -> void: state.count += 1)

	_prop.set_value(1)
	assert_eq(state.count, 1, "断开前，修改值应触发回调。")

	_prop.unbind_all()
	_prop.set_value(2)
	assert_eq(state.count, 2, "unbind_all 不应断开非 bind_to 创建的业务订阅。")


## 验证 disconnect_all_subscribers 明确断开所有订阅。
func test_disconnect_all_subscribers_removes_all_value_changed_connections() -> void:
	var state: CounterState = CounterState.new()
	var _connect_result_180: Variant = _prop.value_changed.connect(func(_o: Variant, _n: Variant) -> void: state.total += 1)
	var _connect_result_181: Variant = _prop.value_changed.connect(func(_o: Variant, _n: Variant) -> void: state.total += 10)

	_prop.disconnect_all_subscribers()
	_prop.set_value(42)

	assert_eq(state.total, 0, "disconnect_all_subscribers 后所有连接都应断开，total 应保持为 0。")


## 验证 disconnect_all_subscribers 后可以重新绑定。
func test_rebind_after_disconnect_all_subscribers() -> void:
	var state: CounterState = CounterState.new()
	var _connect_result_192: Variant = _prop.value_changed.connect(func(_o: Variant, _n: Variant) -> void: state.count += 1)
	_prop.disconnect_all_subscribers()

	var _connect_result_195: Variant = _prop.value_changed.connect(func(_o: Variant, _n: Variant) -> void: state.count += 100)
	_prop.set_value(5)

	assert_eq(state.count, 100, "disconnect_all_subscribers 后重新绑定的回调应正常工作。")


## 验证 unbind_all 会同时清理 bind_to 附加的 tree_exited 监听。
func test_unbind_all_removes_tree_exited_helper_connections() -> void:
	var node: Node = Node.new()
	add_child_autofree(node)

	_prop.bind_to(node, func(_o: Variant, _n: Variant) -> void: pass)
	assert_eq(node.tree_exited.get_connections().size(), 1, "bind_to 后应注册一个 tree_exited 自动解绑监听。")

	_prop.unbind_all()
	assert_eq(node.tree_exited.get_connections().size(), 0, "unbind_all 后不应残留 tree_exited 自动解绑监听。")


func test_unbind_all_node_bindings_removes_bound_callbacks_only() -> void:
	var direct_count: CounterState = CounterState.new()
	var bound_count: CounterState = CounterState.new()
	var node: Node = Node.new()
	var bound_callback: Callable = func(_o: Variant, _n: Variant) -> void:
		bound_count.value += 1
	add_child_autofree(node)

	var _connect_result_221: Variant = _prop.value_changed.connect(func(_o: Variant, _n: Variant) -> void:
		direct_count.value += 1
	)
	_prop.bind_to(node, bound_callback)
	_prop.unbind_all_node_bindings()
	_prop.set_value(1)

	assert_eq(direct_count.value, 1, "节点绑定清理后，直接订阅仍应触发。")
	assert_eq(bound_count.value, 0, "节点绑定清理后，bind_to 回调不应触发。")
	assert_eq(node.tree_exited.get_connections().size(), 0, "节点绑定清理后不应残留 tree_exited 辅助连接。")


## 验证 unbind 只移除指定节点与回调，不影响其他监听者。
func test_unbind_removes_single_node_binding_only() -> void:
	var first_count: CounterState = CounterState.new()
	var second_count: CounterState = CounterState.new()
	var first_node: Node = Node.new()
	var second_node: Node = Node.new()
	var first_callback: Callable = func(_o: Variant, _n: Variant) -> void:
		first_count.value += 1
	var second_callback: Callable = func(_o: Variant, _n: Variant) -> void:
		second_count.value += 1
	add_child_autofree(first_node)
	add_child_autofree(second_node)

	_prop.bind_to(first_node, first_callback)
	_prop.bind_to(second_node, second_callback)
	_prop.unbind(first_node, first_callback)
	_prop.set_value(1)

	assert_eq(first_count.value, 0, "被 unbind 的回调不应再触发。")
	assert_eq(second_count.value, 1, "其他节点绑定不应受影响。")
	assert_eq(first_node.tree_exited.get_connections().size(), 0, "指定节点的 tree_exited 辅助连接应被清理。")


## 验证节点已经失效时，手动 unbind 仍会清理 bind_to 持有的回调。
func test_unbind_prunes_invalid_node_binding() -> void:
	var count: CounterState = CounterState.new()
	var node: Node = Node.new()
	var callback: Callable = func(_old_value: Variant, _new_value: Variant) -> void:
		count.value += 1

	_prop.bind_to(node, callback)
	node.free()
	_prop.unbind(node, callback)
	_prop.set_value(1)

	assert_eq(count.value, 0, "失效节点的 bind_to 回调不应残留在 value_changed 上。")
	assert_eq(_prop.value_changed.get_connections().size(), 0, "失效节点解绑后不应残留托管信号连接。")


# --- 测试：bind_to (Task 4) ---

## 验证 bind_to 能在节点销毁时自动解绑。
func test_bind_to_auto_unbinds_on_tree_exited() -> void:
	var state: CounterState = CounterState.new()
	var node: Node = Node.new()
	add_child_autofree(node)

	_prop.bind_to(node, func(_o: Variant, _n: Variant) -> void: state.count += 1)

	_prop.set_value(1)
	assert_eq(state.count, 1, "解绑前应触发一次。")

	# 模拟节点退出场景树
	remove_child(node)
	var _emit_signal_result_287: Variant = node.emit_signal("tree_exited")

	_prop.set_value(2)
	assert_eq(state.count, 1, "节点退出树后，不应再触发回调（已自动解绑）。")

	node.free()


## 验证同一 Callable 绑定到多个节点时，一个节点退出不会误断开仍存活的绑定。
func test_bind_to_same_callable_survives_until_last_bound_node_exits() -> void:
	var state: CounterState = CounterState.new()
	var first_node: Node = Node.new()
	var second_node: Node = Node.new()
	var callback: Callable = func(_o: Variant, _n: Variant) -> void:
		state.count += 1
	add_child_autofree(first_node)
	add_child_autofree(second_node)

	_prop.bind_to(first_node, callback)
	_prop.bind_to(second_node, callback)
	_prop.set_value(1)

	remove_child(first_node)
	first_node.tree_exited.emit()
	_prop.set_value(2)

	remove_child(second_node)
	second_node.tree_exited.emit()
	_prop.set_value(3)

	assert_eq(state.count, 2, "同一回调仍有存活节点绑定时应保持连接，最后一个节点退出后才断开。")

	first_node.free()
	second_node.free()


func test_bind_to_same_callable_prunes_all_invalid_nodes_together() -> void:
	var state: CounterState = CounterState.new()
	var first_node: Node = Node.new()
	var second_node: Node = Node.new()
	var callback: Callable = func(_o: Variant, _n: Variant) -> void:
		state.count += 1

	_prop.bind_to(first_node, callback)
	_prop.bind_to(second_node, callback)
	first_node.free()
	second_node.free()

	_prop.unbind(first_node, callback)
	_prop.set_value(1)

	assert_eq(state.count, 0, "同一回调的所有节点都失效后应整体断开托管连接。")
	assert_eq(_prop.value_changed.get_connections().size(), 0, "批量剪枝失效节点后不应残留托管信号连接。")


func test_reactive_effect_runs_when_any_source_changes() -> void:
	var first: GFBindableProperty = GFBindableProperty.new(1)
	var second: GFBindableProperty = GFBindableProperty.new(2)
	var values: Array[int] = []
	var effect: GFReactiveEffect = GFReactiveEffect.new([first, second], func() -> int:
		var total: int = _value_int(first) + _value_int(second)
		values.append(total)
		return total
	)

	first.value = 3
	second.value = 4
	effect.stop()
	first.value = 10

	assert_eq(values, [3, 5, 7], "effect 应立即运行，并在来源变化时刷新；stop 后不再运行。")


func test_reactive_effect_reruns_when_source_changes_during_callback() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new(1)
	var values: Array[int] = []
	var effect: GFReactiveEffect = GFReactiveEffect.new([prop], func() -> int:
		var value: int = _value_int(prop)
		values.append(value)
		if value == 1:
			prop.value = 2
		return value
	)

	assert_eq(values, [1, 2], "callback 运行中发生的来源变化应在本轮结束后补跑一次。")
	effect.stop()


func test_reactive_effect_stops_with_owner_node() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new(1)
	var owner_node: Node = Node.new()
	var count: CounterState = CounterState.new()
	add_child(owner_node)

	var effect: GFReactiveEffect = GFReactiveEffect.new([prop], func() -> void:
		count.value += 1
	, owner_node, false)

	prop.value = 2
	remove_child(owner_node)
	owner_node.tree_exited.emit()
	prop.value = 3

	assert_eq(count.value, 1, "owner 退出树后 effect 应自动停止。")
	assert_false(effect.is_active(), "owner 退出树后 effect 应进入非激活状态。")
	owner_node.free()


func test_reactive_effect_stop_prunes_source_binding_when_owner_is_already_freed() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new(1)
	var owner_node: Node = Node.new()
	var count: CounterState = CounterState.new()
	var effect: GFReactiveEffect = GFReactiveEffect.new([prop], func() -> void:
		count.value += 1
	, owner_node, false)

	owner_node.free()
	effect.stop()
	prop.value = 2

	assert_eq(count.value, 0, "owner 已失效后 stop 仍应断开 effect 回调。")
	assert_eq(prop.value_changed.get_connections().size(), 0, "owner 已失效后 source 侧 bind_to 账本也应被清理。")


func test_reactive_effect_dispose_stops_sources() -> void:
	var prop: GFBindableProperty = GFBindableProperty.new(1)
	var count: CounterState = CounterState.new()
	var effect: GFReactiveEffect = GFReactiveEffect.new([prop], func() -> void:
		count.value += 1
	, null, false)

	prop.value = 2
	effect.dispose()
	prop.value = 3

	assert_eq(count.value, 1, "dispose 后 effect 不应继续响应来源变化。")
	assert_false(effect.is_active(), "dispose 后 effect 应进入非激活状态。")


func test_computed_property_updates_from_sources() -> void:
	var first: GFBindableProperty = GFBindableProperty.new(2)
	var second: GFBindableProperty = GFBindableProperty.new(3)
	var computed: GFComputedProperty = GFComputedProperty.new([first, second], func() -> int:
		return _value_int(first) * _value_int(second)
	)

	assert_eq(_value_int(computed), 6, "computed 属性应立即计算初始值。")

	first.value = 4

	assert_eq(_value_int(computed), 12, "来源属性变化后 computed 属性应刷新。")
	computed.dispose()


func test_computed_property_dispose_stops_auto_refresh() -> void:
	var source: GFBindableProperty = GFBindableProperty.new(1)
	var computed: GFComputedProperty = GFComputedProperty.new([source], func() -> int:
		return _value_int(source) + 1
	)

	computed.dispose()
	source.value = 4

	assert_eq(_value_int(computed), 2, "dispose 后 computed 属性不应继续自动刷新。")
	assert_false(computed.is_computing(), "dispose 后 computed 属性不应保持计算状态。")


func test_computed_property_rejects_external_set() -> void:
	var source: GFBindableProperty = GFBindableProperty.new(1)
	var computed: GFComputedProperty = GFComputedProperty.new([source], func() -> int:
		return _value_int(source) + 1
	)

	computed.value = 10

	assert_eq(_value_int(computed), 2, "外部写入 computed 属性不应改变派生值。")
	assert_push_error("[GFComputedProperty] 当前属性由 compute 回调派生，请修改来源属性。")
	computed.dispose()


func test_computed_property_rejects_in_place_mutation_helpers() -> void:
	var source: GFBindableProperty = GFBindableProperty.new(1)
	var computed_array: GFComputedProperty = GFComputedProperty.new([source], func() -> Array:
		return ["base"]
	)
	var computed_dict: GFComputedProperty = GFComputedProperty.new([source], func() -> Dictionary:
		return { "hp": 1 }
	)
	watch_signals(computed_array)
	watch_signals(computed_dict)

	assert_false(computed_array.mutate(func(value: Array) -> void:
		value.append("mutated")
	))
	assert_false(computed_array.append_to_array("extra"))
	assert_false(computed_array.append_array(["extra"]))
	assert_false(computed_array.erase_from_array("base"))
	assert_false(computed_array.clear_collection())
	assert_false(computed_dict.set_dictionary_value("hp", 99))
	assert_false(computed_dict.erase_dictionary_key("hp"))

	assert_eq(_value_array(computed_array), ["base"], "computed 数组值不应被外部原地修改。")
	assert_eq(_value_dictionary(computed_dict), { "hp": 1 }, "computed 字典值不应被外部原地修改。")
	assert_signal_not_emitted(computed_array, "value_changed", "拒绝原地修改时不应发出数组变化信号。")
	assert_signal_not_emitted(computed_dict, "value_changed", "拒绝原地修改时不应发出字典变化信号。")
	assert_push_error_count(7, "每次外部原地修改尝试都应报告只读错误。")
	computed_array.dispose()
	computed_dict.dispose()


func test_computed_property_get_value_returns_collection_copy() -> void:
	var source: GFBindableProperty = GFBindableProperty.new(1)
	var computed_array: GFComputedProperty = GFComputedProperty.new([source], func() -> Array:
		return ["base"]
	)
	var computed_dict: GFComputedProperty = GFComputedProperty.new([source], func() -> Dictionary:
		return { "hp": 1 }
	)

	var leaked_array: Array = _value_array(computed_array)
	var leaked_dict: Dictionary = _value_dictionary(computed_dict)
	leaked_array.append("external")
	leaked_dict["hp"] = 99

	assert_eq(_value_array(computed_array), ["base"], "computed get_value() 返回的数组副本不应影响内部值。")
	assert_eq(_value_dictionary(computed_dict), { "hp": 1 }, "computed get_value() 返回的字典副本不应影响内部值。")
	computed_array.dispose()
	computed_dict.dispose()


func test_read_only_bindable_property_rejects_in_place_mutation_helpers() -> void:
	var read_only_array: GFReadOnlyBindableProperty = GFReadOnlyBindableProperty.new(["base"])
	var read_only_dict: GFReadOnlyBindableProperty = GFReadOnlyBindableProperty.new({ "hp": 1 })
	watch_signals(read_only_array)
	watch_signals(read_only_dict)

	assert_false(read_only_array.mutate(func(value: Array) -> void:
		value.append("mutated")
	))
	assert_false(read_only_array.append_to_array("extra"))
	assert_false(read_only_array.append_array(["extra"]))
	assert_false(read_only_array.erase_from_array("base"))
	assert_false(read_only_array.clear_collection())
	assert_false(read_only_dict.set_dictionary_value("hp", 99))
	assert_false(read_only_dict.erase_dictionary_key("hp"))

	assert_eq(_value_array(read_only_array), ["base"], "只读数组视图不应被外部原地修改。")
	assert_eq(_value_dictionary(read_only_dict), { "hp": 1 }, "只读字典视图不应被外部原地修改。")
	assert_signal_not_emitted(read_only_array, "value_changed", "拒绝原地修改时不应发出数组变化信号。")
	assert_signal_not_emitted(read_only_dict, "value_changed", "拒绝原地修改时不应发出字典变化信号。")
	assert_push_error_count(7, "每次外部原地修改尝试都应报告只读错误。")


func test_read_only_bindable_property_get_value_returns_collection_copy() -> void:
	var read_only_array: GFReadOnlyBindableProperty = GFReadOnlyBindableProperty.new(["base"])
	var read_only_dict: GFReadOnlyBindableProperty = GFReadOnlyBindableProperty.new({ "hp": 1 })

	var leaked_array: Array = _value_array(read_only_array)
	var leaked_dict: Dictionary = _value_dictionary(read_only_dict)
	leaked_array.append("external")
	leaked_dict["hp"] = 99

	assert_eq(_value_array(read_only_array), ["base"], "只读 get_value() 返回的数组副本不应影响内部值。")
	assert_eq(_value_dictionary(read_only_dict), { "hp": 1 }, "只读 get_value() 返回的字典副本不应影响内部值。")


# --- 私有/辅助方法 ---

func _value_dictionary(prop: GFBindableProperty) -> Dictionary:
	return _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(prop.get_value())


func _value_array(prop: GFBindableProperty) -> Array:
	return _GF_VARIANT_ACCESS_SCRIPT.as_array(prop.get_value())


func _value_int(prop: GFBindableProperty) -> int:
	return _variant_int(prop.get_value())


func _value_text(prop: GFBindableProperty) -> String:
	return _GF_VARIANT_ACCESS_SCRIPT.to_text(prop.get_value())


func _variant_int(value: Variant) -> int:
	return _GF_VARIANT_ACCESS_SCRIPT.to_int(value)


# --- 内部类 ---

class CounterState:
	var count: int = 0
	var total: int = 0
	var value: int = 0


class SubscriptionMethodOwner:
	extends Node

	var values: Array[int] = []

	func record_value_change(_old_value: Variant, new_value: Variant) -> void:
		if new_value is int:
			var int_value: int = new_value
			values.append(int_value)
		elif new_value is float:
			var float_value: float = new_value
			values.append(int(float_value))
