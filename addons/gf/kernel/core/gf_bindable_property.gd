## GFBindableProperty: 响应式数据绑定属性容器。
##
## 封装一个 Variant 值，当值发生变化时自动发出 value_changed 信号。
## 可用于 Controller 直接监听 Model 数据变化，无需通过事件总线中转。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFBindableProperty
extends RefCounted


# --- 信号 ---

## 当属性值被设置为不同的新值时发出。
## [br]
## @api public
## [br]
## @param old_value: 变化前的旧值。
## [br]
## @param new_value: 变化后的新值。
## [br]
## @schema old_value {
##   "type": "Variant",
##   "description": "变化前的旧值。"
## }
## [br]
## @schema new_value {
##   "type": "Variant",
##   "description": "变化后的新值。"
## }
signal value_changed(old_value: Variant, new_value: Variant)


# --- 常量 ---

const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共变量 ---

## 当前属性值。设置该属性等价于调用 `set_value()`。
## [br]
## @api public
## [br]
## @schema value {
##   "type": "Variant",
##   "description": "当前属性值。"
## }
var value: Variant:
	get:
		return get_value()
	set(new_value):
		set_value(new_value)


# --- 私有变量 ---

var _value: Variant
var _node_bindings: Array[Dictionary] = []
var _owned_value_connections: Array[Callable] = []
var _subscription_bindings: Array[Dictionary] = []


# --- Godot 生命周期方法 ---

## 构造函数。
## [br]
## @api public
## [br]
## @param default_value: 属性的初始值，默认为 null。
## [br]
## @schema default_value {
##   "type": "Variant",
##   "description": "属性的初始值。"
## }
func _init(default_value: Variant = null) -> void:
	_value = default_value


# --- 公共方法 ---

## 获取当前属性值。
## [br]
## @api public
## [br]
## @return 当前存储的值。
## [br]
## @schema return {
##   "type": "Variant",
##   "description": "当前存储的值。"
## }
func get_value() -> Variant:
	return _value


## 设置属性值。仅当新值与旧值不同时，才会更新并发出 value_changed 信号。
## [br]
## @api public
## [br]
## @param new_value: 要设置的新值。
## [br]
## @schema new_value {
##   "type": "Variant",
##   "description": "要设置的新值。"
## }
func set_value(new_value: Variant) -> void:
	if _are_values_equal(_value, new_value):
		return
	var old_value: Variant = _value
	_value = new_value
	_emit_value_changed(old_value, new_value)


## 订阅属性变化，并返回取消订阅函数。
## [br]
## @api public
## [br]
## @since 3.20.0
## [br]
## @param callback: 变化回调，签名应为 func(old_value: Variant, new_value: Variant)。
## [br]
## @param emit_current: 是否立即以当前值调用一次回调；为 true 时 old_value 和 new_value 都是当前值。
## [br]
## @return 可调用的取消订阅函数；callback 无效时返回空 Callable。
func subscribe(callback: Callable, emit_current: bool = false) -> Callable:
	if not callback.is_valid():
		push_error("[GFBindableProperty] subscribe 失败：callback 无效。")
		return Callable()
	var subscription_token: GFSubscriptionToken = _subscribe_callable_token(callback, emit_current)
	return _make_unsubscribe_callable(subscription_token)


## 订阅属性变化，并返回可取消订阅句柄。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param callback: 变化回调，签名应为 func(old_value: Variant, new_value: Variant)。
## [br]
## @param emit_current: 是否立即以当前值调用一次回调；为 true 时 old_value 和 new_value 都是当前值。
## [br]
## @return 可取消订阅句柄；callback 无效时返回非活动句柄。
func subscribe_token(callback: Callable, emit_current: bool = false) -> GFSubscriptionToken:
	if not callback.is_valid():
		push_error("[GFBindableProperty] subscribe_token 失败：callback 无效。")
		return GFSubscriptionToken.new()
	return _subscribe_callable_token(callback, emit_current)


## 订阅属性变化，并把订阅绑定到 owner 生命周期。
## owner 为 Node 时，节点退出场景树会自动取消订阅。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 订阅生命周期 owner。
## [br]
## @param callback: 变化回调，签名应为 func(old_value: Variant, new_value: Variant)。
## [br]
## @param emit_current: 是否立即以当前值调用一次回调；为 true 时 old_value 和 new_value 都是当前值。
## [br]
## @return 绑定 owner 生命周期的订阅句柄；owner 或 callback 无效时返回非活动句柄。
func subscribe_owned(owner: Object, callback: Callable, emit_current: bool = false) -> GFLifetimeSubscription:
	if owner == null or not is_instance_valid(owner):
		push_error("[GFBindableProperty] subscribe_owned 失败：owner 无效。")
		return GFLifetimeSubscription.new()
	if not callback.is_valid():
		push_error("[GFBindableProperty] subscribe_owned 失败：callback 无效。")
		return GFLifetimeSubscription.new()
	return _subscribe_owned_callable_token(owner, callback, emit_current)


## 通过 owner 与方法名订阅属性变化。
## 该入口只弱引用 owner，不会因为 Callable 捕获而延长 owner 生命周期。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 订阅生命周期 owner，也是方法所属对象。
## [br]
## @param method_name: 变化回调方法名，方法签名应为 func(old_value: Variant, new_value: Variant)。
## [br]
## @param emit_current: 是否立即以当前值调用一次回调；为 true 时 old_value 和 new_value 都是当前值。
## [br]
## @return 绑定 owner 生命周期的订阅句柄；owner 或方法无效时返回非活动句柄。
func subscribe_method(owner: Object, method_name: StringName, emit_current: bool = false) -> GFLifetimeSubscription:
	if owner == null or not is_instance_valid(owner):
		push_error("[GFBindableProperty] subscribe_method 失败：owner 无效。")
		return GFLifetimeSubscription.new()
	if method_name == &"" or not owner.has_method(method_name):
		push_error("[GFBindableProperty] subscribe_method 失败：method_name 无效。")
		return GFLifetimeSubscription.new()
	return _subscribe_owner_method_token(owner, method_name, emit_current)


## 强制发出 value_changed 信号。
## 适合在 Array、Dictionary 或 Object 发生原地变更后，由业务层显式通知监听者。
## [br]
## @api public
func force_emit() -> void:
	_emit_value_changed(_value, _value)


## 通过回调修改当前值并强制广播。
## [br]
## @api public
## [br]
## @param mutator: 修改当前值的回调。
## [br]
## @return 回调有效时返回 true。
func mutate(mutator: Callable) -> bool:
	if not mutator.is_valid():
		return false
	mutator.call(_value)
	force_emit()
	return true


## 向当前 Array 追加一个元素。
## [br]
## @api public
## [br]
## @param item: 要追加的元素。
## [br]
## @return 成功返回 true。
## [br]
## @schema item {
##   "type": "Variant",
##   "description": "要追加的元素。"
## }
func append_to_array(item: Variant) -> bool:
	if not (_value is Array):
		return false
	var array_value: Array = _GF_VARIANT_ACCESS_SCRIPT.as_array(_value)
	array_value.append(item)
	force_emit()
	return true


## 向当前 Array 追加多个元素。
## [br]
## @api public
## [br]
## @param items: 要追加的元素列表。
## [br]
## @return 成功返回 true。
## [br]
## @schema items {
##   "type": "Array",
##   "description": "要追加的元素列表。"
## }
func append_array(items: Array) -> bool:
	if not (_value is Array):
		return false
	var array_value: Array = _GF_VARIANT_ACCESS_SCRIPT.as_array(_value)
	array_value.append_array(items)
	force_emit()
	return true


## 从当前 Array 删除一个元素。
## [br]
## @api public
## [br]
## @param item: 要删除的元素。
## [br]
## @return 成功返回 true。
## [br]
## @schema item {
##   "type": "Variant",
##   "description": "要删除的元素。"
## }
func erase_from_array(item: Variant) -> bool:
	if not (_value is Array):
		return false
	var array_value: Array = _GF_VARIANT_ACCESS_SCRIPT.as_array(_value)
	if not array_value.has(item):
		return false
	array_value.erase(item)
	force_emit()
	return true


## 设置当前 Dictionary 的一个键值。
## [br]
## @api public
## [br]
## @param key: 键。
## [br]
## @param new_value: 新值。
## [br]
## @return 成功返回 true。
## [br]
## @schema key {
##   "type": "Variant",
##   "description": "Dictionary 键。"
## }
## [br]
## @schema new_value {
##   "type": "Variant",
##   "description": "Dictionary 新值。"
## }
func set_dictionary_value(key: Variant, new_value: Variant) -> bool:
	if not (_value is Dictionary):
		return false
	var dictionary_value: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(_value)
	dictionary_value[key] = new_value
	force_emit()
	return true


## 从当前 Dictionary 删除一个键。
## [br]
## @api public
## [br]
## @param key: 键。
## [br]
## @return 成功返回 true。
## [br]
## @schema key {
##   "type": "Variant",
##   "description": "Dictionary 键。"
## }
func erase_dictionary_key(key: Variant) -> bool:
	if not (_value is Dictionary):
		return false
	var dictionary_value: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(_value)
	if not dictionary_value.has(key):
		return false
	var _erase_result_273: Variant = dictionary_value.erase(key)
	force_emit()
	return true


## 清空当前 Array 或 Dictionary。
## [br]
## @api public
## [br]
## @return 成功返回 true。
func clear_collection() -> bool:
	if _value is Array:
		var array_value: Array = _GF_VARIANT_ACCESS_SCRIPT.as_array(_value)
		if array_value.is_empty():
			return false
		array_value.clear()
		force_emit()
		return true
	if _value is Dictionary:
		var dictionary_value: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(_value)
		if dictionary_value.is_empty():
			return false
		dictionary_value.clear()
		force_emit()
		return true
	return false


## 断开指定 Node 与 Callable 的绑定关系。
## [br]
## @api public
## [br]
## @param node: 绑定生命周期的节点；已失效对象会触发失效绑定清理。
## [br]
## @param callable: 要解绑的回调函数。
## [br]
## @schema node {
##   "type": "Variant",
##   "description": "绑定生命周期的 Node；已失效对象会触发失效绑定清理。"
## }
func unbind(node: Variant, callable: Callable) -> void:
	if not callable.is_valid():
		return

	if is_instance_valid(node) and node is Node:
		var bound_node: Node = node
		_disconnect_node_binding(bound_node, callable)
	else:
		_prune_invalid_node_bindings()
	_release_value_connection_if_unbound(callable)


## 断开所有由 bind_to() 创建的 Node 生命周期绑定。
## [br]
## @api public
func unbind_all() -> void:
	unbind_all_node_bindings()


## 断开所有由 bind_to() 创建的 Node 生命周期绑定。
## [br]
## @api public
func unbind_all_node_bindings() -> void:
	for binding: Dictionary in _node_bindings:
		var node_ref: WeakRef = _get_binding_weak_ref(binding, "node_ref")
		var exit_callable: Callable = _get_binding_callable(binding, "exit_callable")
		var node: Node = _INSTANCE_GUARD._get_live_node_from_ref(node_ref)
		if is_instance_valid(node) and node.tree_exited.is_connected(exit_callable):
			node.tree_exited.disconnect(exit_callable)

	_node_bindings.clear()
	for callable: Callable in _owned_value_connections:
		if callable.is_valid() and value_changed.is_connected(callable):
			value_changed.disconnect(callable)
	_owned_value_connections.clear()


## 断开 value_changed 信号上的所有订阅者，并清理 bind_to() 创建的 Node 生命周期绑定。
## [br]
## @api public
func disconnect_all_subscribers() -> void:
	for connection: Dictionary in value_changed.get_connections():
		var connection_callable: Callable = _get_binding_callable(connection, "callable")
		if connection_callable.is_valid():
			value_changed.disconnect(connection_callable)

	for binding: Dictionary in _subscription_bindings.duplicate():
		var subscription_token: GFSubscriptionToken = _get_binding_subscription_token(binding)
		if subscription_token != null:
			var _cancelled: bool = subscription_token.cancel()

	for binding: Dictionary in _node_bindings:
		var node_ref: WeakRef = _get_binding_weak_ref(binding, "node_ref")
		var exit_callable: Callable = _get_binding_callable(binding, "exit_callable")
		var node: Node = _INSTANCE_GUARD._get_live_node_from_ref(node_ref)
		if is_instance_valid(node) and node.tree_exited.is_connected(exit_callable):
			node.tree_exited.disconnect(exit_callable)

	_node_bindings.clear()
	_owned_value_connections.clear()
	_subscription_bindings.clear()


## 绑定信号到一个 Node 的 Callable。当该 Node 退出场景树时，自动断开连接。
## [br]
## @api public
## [br]
## @param node: 监听生命周期的节点。
## [br]
## @param callable: 绑定的回调函数。
func bind_to(node: Node, callable: Callable) -> void:
	if not is_instance_valid(node):
		push_error("[GFBindableProperty] 尝试绑定到一个无效的 Node。")
		return

	if not callable.is_valid():
		push_error("[GFBindableProperty] 尝试绑定一个无效的 Callable。")
		return

	if _find_node_binding_index(node, callable) != -1:
		return

	if not value_changed.is_connected(callable):
		var _connect_result_390: Variant = value_changed.connect(callable)
		_track_owned_value_connection(callable)

	var exit_callable: Callable = _on_node_exited.bind(node, callable)
	if not node.tree_exited.is_connected(exit_callable):
		var _connect_result_395: Variant = node.tree_exited.connect(
			exit_callable,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		)

	_node_bindings.append({
		"node_ref": weakref(node),
		"callable": callable,
		"exit_callable": exit_callable,
	})


# --- 私有/辅助方法 ---


func _emit_value_changed(old_value: Variant, new_value: Variant) -> void:
	_prune_inactive_subscription_bindings()
	value_changed.emit(_copy_signal_payload(old_value), _copy_signal_payload(new_value))


func _copy_signal_payload(source_value: Variant) -> Variant:
	return _GF_VARIANT_ACCESS_SCRIPT.duplicate_collection(source_value, true)


func _on_node_exited(node: Node, callable: Callable) -> void:
	_disconnect_node_binding(node, callable)
	_release_value_connection_if_unbound(callable)


static func _are_values_equal(left: Variant, right: Variant) -> bool:
	var left_type: int = typeof(left)
	var right_type: int = typeof(right)
	if left_type == right_type:
		return left == right
	if _is_numeric_variant_type(left_type) and _is_numeric_variant_type(right_type):
		return _variant_to_float(left) == _variant_to_float(right)
	return false


static func _is_numeric_variant_type(variant_type: int) -> bool:
	return variant_type == TYPE_INT or variant_type == TYPE_FLOAT


static func _variant_to_float(raw_value: Variant) -> float:
	if raw_value is int:
		var int_value: int = raw_value
		return float(int_value)
	if raw_value is float:
		var float_value: float = raw_value
		return float_value
	return 0.0


func _make_unsubscribe_callable(subscription_token: GFSubscriptionToken) -> Callable:
	if subscription_token == null or not subscription_token.is_active():
		return Callable()
	return func() -> void:
		var _cancelled: bool = subscription_token.cancel()


func _subscribe_callable_token(callback: Callable, emit_current: bool) -> GFSubscriptionToken:
	_prune_inactive_subscription_bindings()
	var existing_binding: Dictionary = _find_subscription_binding(&"callable", callback, 0, &"")
	var existing_token: GFSubscriptionToken = _get_binding_subscription_token(existing_binding)
	if existing_token != null:
		if emit_current:
			_call_subscription_callable(callback, _value, _value)
		return existing_token

	var signal_callback: Callable = func(old_value: Variant, new_value: Variant) -> void:
		if callback.is_valid():
			_call_subscription_callable(callback, old_value, new_value)
	var subscription_token: GFSubscriptionToken = _register_subscription({
		"kind": &"callable",
		"callback": callback,
		"owner_id": 0,
		"method_name": &"",
	}, signal_callback, null, "GFBindableProperty.subscribe")
	if emit_current and subscription_token.is_active():
		_call_subscription_callable(callback, _value, _value)
	return subscription_token


func _subscribe_owned_callable_token(owner: Object, callback: Callable, emit_current: bool) -> GFLifetimeSubscription:
	_prune_inactive_subscription_bindings()
	var owner_id: int = owner.get_instance_id()
	var existing_binding: Dictionary = _find_subscription_binding(&"owned_callable", callback, owner_id, &"")
	var existing_token: GFSubscriptionToken = _get_binding_subscription_token(existing_binding)
	if existing_token is GFLifetimeSubscription:
		var existing_lifetime_token: GFLifetimeSubscription = existing_token
		if emit_current:
			_call_subscription_callable(callback, _value, _value)
		return existing_lifetime_token

	var owner_ref: WeakRef = weakref(owner)
	var signal_callback: Callable = func(old_value: Variant, new_value: Variant) -> void:
		if _get_live_owner_from_ref(owner_ref) == null:
			return
		if callback.is_valid():
			_call_subscription_callable(callback, old_value, new_value)
	var subscription_token: GFLifetimeSubscription = _register_lifetime_subscription(owner, {
		"kind": &"owned_callable",
		"callback": callback,
		"owner_id": owner_id,
		"method_name": &"",
	}, signal_callback, "GFBindableProperty.subscribe_owned")
	if emit_current and subscription_token.is_active():
		_call_subscription_callable(callback, _value, _value)
	return subscription_token


func _subscribe_owner_method_token(owner: Object, method_name: StringName, emit_current: bool) -> GFLifetimeSubscription:
	_prune_inactive_subscription_bindings()
	var owner_id: int = owner.get_instance_id()
	var existing_binding: Dictionary = _find_subscription_binding(&"owner_method", Callable(), owner_id, method_name)
	var existing_token: GFSubscriptionToken = _get_binding_subscription_token(existing_binding)
	if existing_token is GFLifetimeSubscription:
		var existing_lifetime_token: GFLifetimeSubscription = existing_token
		if emit_current:
			var existing_owner_ref: WeakRef = weakref(owner)
			_call_owner_method(existing_owner_ref, method_name, _value, _value)
		return existing_lifetime_token

	var owner_ref: WeakRef = weakref(owner)
	var signal_callback: Callable = func(old_value: Variant, new_value: Variant) -> void:
		_call_owner_method(owner_ref, method_name, old_value, new_value)
	var subscription_token: GFLifetimeSubscription = _register_lifetime_subscription(owner, {
		"kind": &"owner_method",
		"callback": Callable(),
		"owner_id": owner_id,
		"method_name": method_name,
	}, signal_callback, "GFBindableProperty.subscribe_method")
	if emit_current and subscription_token.is_active():
		_call_owner_method(owner_ref, method_name, _value, _value)
	return subscription_token


func _register_subscription(
	binding: Dictionary,
	signal_callback: Callable,
	owner: Object,
	debug_label: String
) -> GFSubscriptionToken:
	var property_ref: WeakRef = weakref(self)
	var cancel_callback: Callable = func() -> void:
		var raw_property: Variant = property_ref.get_ref()
		if raw_property is GFBindableProperty:
			var property: GFBindableProperty = raw_property
			property._cancel_subscription(signal_callback)

	var subscription_token: GFSubscriptionToken = GFSubscriptionToken.new(cancel_callback, debug_label)
	if owner != null:
		subscription_token = GFLifetimeSubscription.new(owner, cancel_callback, debug_label)
	if not subscription_token.is_active():
		return subscription_token

	var _connect_result: Variant = value_changed.connect(signal_callback)
	binding["signal_callable"] = signal_callback
	binding["token"] = subscription_token
	_subscription_bindings.append(binding)
	return subscription_token


func _register_lifetime_subscription(
	owner: Object,
	binding: Dictionary,
	signal_callback: Callable,
	debug_label: String
) -> GFLifetimeSubscription:
	var subscription_token: GFSubscriptionToken = _register_subscription(binding, signal_callback, owner, debug_label)
	if subscription_token is GFLifetimeSubscription:
		var lifetime_subscription: GFLifetimeSubscription = subscription_token
		return lifetime_subscription
	return GFLifetimeSubscription.new()


func _cancel_subscription(signal_callback: Callable) -> void:
	if signal_callback.is_valid() and value_changed.is_connected(signal_callback):
		value_changed.disconnect(signal_callback)
	_remove_subscription_binding_by_signal_callable(signal_callback)


func _prune_inactive_subscription_bindings() -> void:
	for binding: Dictionary in _subscription_bindings.duplicate():
		var subscription_token: GFSubscriptionToken = _get_binding_subscription_token(binding)
		if subscription_token == null or subscription_token.is_active():
			continue
		var _cancelled: bool = subscription_token.cancel()
		_cancel_subscription(_get_binding_callable(binding, "signal_callable"))


func _call_subscription_callable(callback: Callable, old_value: Variant, new_value: Variant) -> void:
	callback.call(_copy_signal_payload(old_value), _copy_signal_payload(new_value))


func _call_owner_method(owner_ref: WeakRef, method_name: StringName, old_value: Variant, new_value: Variant) -> void:
	var owner: Object = _get_live_owner_from_ref(owner_ref)
	if owner == null or not owner.has_method(method_name):
		return
	var _callback_result: Variant = owner.callv(method_name, [
		_copy_signal_payload(old_value),
		_copy_signal_payload(new_value),
	])


func _get_live_owner_from_ref(owner_ref: WeakRef) -> Object:
	if owner_ref == null:
		return null
	var raw_owner: Variant = owner_ref.get_ref()
	if raw_owner is Object:
		var owner: Object = raw_owner
		if is_instance_valid(owner):
			return owner
	return null


func _find_subscription_binding(
	binding_kind: StringName,
	callback: Callable,
	owner_id: int,
	method_name: StringName
) -> Dictionary:
	for binding: Dictionary in _subscription_bindings:
		var subscription_token: GFSubscriptionToken = _get_binding_subscription_token(binding)
		if subscription_token != null and not subscription_token.is_active():
			continue
		if _get_binding_string_name(binding, "kind") != binding_kind:
			continue
		if _get_binding_int(binding, "owner_id") != owner_id:
			continue
		if _get_binding_string_name(binding, "method_name") != method_name:
			continue
		if callback.is_valid() and _get_binding_callable(binding, "callback") != callback:
			continue
		return binding
	return {}


func _remove_subscription_binding_by_signal_callable(signal_callable: Callable) -> void:
	for i: int in range(_subscription_bindings.size() - 1, -1, -1):
		if _get_binding_callable(_subscription_bindings[i], "signal_callable") == signal_callable:
			_subscription_bindings.remove_at(i)
			return


func _find_node_binding_index(node: Node, callable: Callable) -> int:
	_prune_invalid_node_bindings()
	for i: int in range(_node_bindings.size()):
		var binding: Dictionary = _node_bindings[i]
		var node_ref: WeakRef = _get_binding_weak_ref(binding, "node_ref")
		var tracked_node: Node = _INSTANCE_GUARD._get_live_node_from_ref(node_ref)
		if tracked_node == node and _get_binding_callable(binding, "callable") == callable:
			return i

	return -1


func _disconnect_node_binding(node: Node, callable: Callable) -> void:
	var binding_index: int = _find_node_binding_index(node, callable)
	if binding_index == -1:
		return

	var binding: Dictionary = _node_bindings[binding_index]
	var exit_callable: Callable = _get_binding_callable(binding, "exit_callable")
	if is_instance_valid(node) and exit_callable.is_valid() and node.tree_exited.is_connected(exit_callable):
		node.tree_exited.disconnect(exit_callable)
	_node_bindings.remove_at(binding_index)


func _has_node_binding_for_callable(callable: Callable, prune_invalid: bool = true) -> bool:
	if prune_invalid:
		_prune_invalid_node_bindings()

	for binding: Dictionary in _node_bindings:
		if _get_binding_callable(binding, "callable") == callable:
			return true

	return false


func _prune_invalid_node_bindings() -> void:
	var pruned_callables: Array[Callable] = []
	for i: int in range(_node_bindings.size() - 1, -1, -1):
		var binding: Dictionary = _node_bindings[i]
		var node_ref: WeakRef = _get_binding_weak_ref(binding, "node_ref")
		var tracked_node: Node = _INSTANCE_GUARD._get_live_node_from_ref(node_ref)
		if not is_instance_valid(tracked_node):
			var pruned_callable: Callable = _get_binding_callable(binding, "callable")
			if pruned_callable.is_valid() and not pruned_callables.has(pruned_callable):
				pruned_callables.append(pruned_callable)
			_node_bindings.remove_at(i)

	for pruned_callable: Callable in pruned_callables:
		_release_value_connection_if_unbound(pruned_callable, false)


func _track_owned_value_connection(callable: Callable) -> void:
	if callable.is_valid() and not _owned_value_connections.has(callable):
		_owned_value_connections.append(callable)


func _get_binding_weak_ref(binding: Dictionary, key: String) -> WeakRef:
	var raw_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(binding, key)
	if raw_value is WeakRef:
		var weak_ref: WeakRef = raw_value
		return weak_ref
	return null


func _get_binding_callable(binding: Dictionary, key: String) -> Callable:
	var raw_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(binding, key, Callable())
	if raw_value is Callable:
		var binding_callable: Callable = raw_value
		return binding_callable
	return Callable()


func _get_binding_subscription_token(binding: Dictionary) -> GFSubscriptionToken:
	var raw_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(binding, "token")
	if raw_value is GFSubscriptionToken:
		var subscription_token: GFSubscriptionToken = raw_value
		return subscription_token
	return null


func _get_binding_int(binding: Dictionary, key: String) -> int:
	var raw_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(binding, key, 0)
	if raw_value is int:
		var int_value: int = raw_value
		return int_value
	return 0


func _get_binding_string_name(binding: Dictionary, key: String) -> StringName:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(binding, key)


func _release_value_connection_if_unbound(callable: Callable, prune_invalid: bool = true) -> void:
	if not callable.is_valid():
		return
	if _has_node_binding_for_callable(callable, prune_invalid):
		return
	if not _owned_value_connections.has(callable):
		return

	_owned_value_connections.erase(callable)
	if value_changed.is_connected(callable):
		value_changed.disconnect(callable)
