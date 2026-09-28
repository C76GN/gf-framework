## GFReactiveStateControlBinder: GFReactiveStateStore 与 Control 值的双向绑定器。
##
## 只负责把 store path 映射到 Godot Control 值，复用 `GFControlValueAdapter`
## 的控件读写和信号连接能力。状态归属仍由 `GFReactiveStateStore` 负责。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 5.0.0
class_name GFReactiveStateControlBinder
extends RefCounted


# --- 常量 ---

## 用于状态存储类型检查、路径规整和订阅的脚本预载。
## [br]
## @api private
const _GF_REACTIVE_STATE_STORE_SCRIPT = preload("res://addons/gf/standard/utilities/state/gf_reactive_state_store.gd")

## 用于从弱引用解析有效对象的实例检查脚本预载。
## [br]
## @api private
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 私有变量 ---

## 本实例创建的 store 路径到 Control 双向绑定。
## [br]
## @api private
var _bindings: Array[Dictionary] = []

## 下一个新绑定使用的递增 id。
## [br]
## @api private
var _next_binding_id: int = 1


# --- 公共方法 ---

## 绑定一个 Control 到 store 路径。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param store: `GFReactiveStateStore` 实例。
## [br]
## @param path: 状态路径。
## [br]
## @param control: 控件节点。
## [br]
## @param options: 可选项。支持 default_value、sync_initial、write_initial_to_store。
## [br]
## @return 成功绑定时返回 true。
## [br]
## @schema store: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
## [br]
## @schema path: Variant，路径表达。
## [br]
## @schema options: Dictionary，default_value 为控件或状态缺省值；sync_initial 默认为 true；write_initial_to_store 为 true 时用控件当前值初始化 store。
func bind_control(
	store: RefCounted,
	path: Variant,
	control: Control,
	options: Dictionary = {}
) -> bool:
	var state_store: _GF_REACTIVE_STATE_STORE_SCRIPT = _as_state_store(store)
	if state_store == null:
		push_error("[GFReactiveStateControlBinder][reactive_state_control_binder.store_type_invalid] Cannot bind_control: store must be a GFReactiveStateStore.")
		return false
	if not is_instance_valid(control):
		push_error("[GFReactiveStateControlBinder][reactive_state_control_binder.control_invalid] Cannot bind_control: control is invalid.")
		return false

	var _previous_binding_removed: bool = unbind_control(control)

	var binding_id: int = _next_binding_id
	_next_binding_id += 1
	var path_segments: Array = _GF_REACTIVE_STATE_STORE_SCRIPT.normalize_path(path)
	var path_text: String = _GF_REACTIVE_STATE_STORE_SCRIPT.format_path(path_segments)
	var default_value: Variant = GFVariantData.get_option_value(options, "default_value")
	var binding: Dictionary = {
		"binding_id": binding_id,
		"store_ref": weakref(state_store),
		"control_ref": weakref(control),
		"path_segments": path_segments,
		"path": path_text,
		"default_value": GFVariantData.duplicate_variant(default_value),
		"updating_control": false,
		"unsubscribe": Callable(),
		"value_changed_connections": [],
		"tree_exited_callable": Callable(),
	}
	_bindings.append(binding)

	if GFVariantData.get_option_bool(options, "sync_initial", true):
		if GFVariantData.get_option_bool(options, "write_initial_to_store", false):
			var initial_value: Variant = GFControlValueAdapter.get_value(control, default_value)
			var _set_initial_result: Variant = state_store.set_value(path_segments, initial_value)
		else:
			var state_value: Variant = state_store.get_value(path_segments, default_value)
			var _set_control_result: Variant = GFControlValueAdapter.set_value(control, state_value)
	if binding.is_empty():
		return false
	if not is_instance_valid(control):
		var _removed_invalid: bool = _remove_binding(binding)
		return false

	var unsubscribe: Callable = state_store.subscribe(
		path_segments,
		func(change: Dictionary, _store: RefCounted) -> void:
			_apply_store_change_to_control(binding, change),
		{
			"mode": _GF_REACTIVE_STATE_STORE_SCRIPT.SUBSCRIBE_EXACT,
			"owner": control,
		}
	)
	if not unsubscribe.is_valid():
		var _removed_failed: bool = _remove_binding(binding)
		return false
	binding["unsubscribe"] = unsubscribe

	var value_connections: Array[Dictionary] = GFControlValueAdapter.connect_value_changed_with_handles(
		control,
		func() -> void:
			_apply_control_change_to_store(binding)
	)
	binding["value_changed_connections"] = value_connections

	var tree_exited_callback: Callable = Callable(self, "_on_control_tree_exited").bind(binding_id)
	if not control.tree_exited.is_connected(tree_exited_callback):
		var _tree_exited_result: Variant = control.tree_exited.connect(
			tree_exited_callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		)
	binding["tree_exited_callable"] = tree_exited_callback

	return true


## 解绑指定 Control。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param control: 控件节点。
## [br]
## @return 找到并解绑时返回 true。
func unbind_control(control: Control) -> bool:
	if control == null:
		return false

	var removed: bool = false
	for index: int in range(_bindings.size() - 1, -1, -1):
		var binding: Dictionary = _bindings[index]
		var bound_control: Control = _get_binding_control(binding)
		if bound_control == control:
			_disconnect_binding(binding)
			_bindings.remove_at(index)
			removed = true
	return removed


## 解绑指定 store 路径上的所有 Control。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param store: `GFReactiveStateStore` 实例。
## [br]
## @param path: 状态路径。
## [br]
## @return 解绑数量。
## [br]
## @schema store: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
## [br]
## @schema path: Variant，路径表达。
func unbind_path(store: RefCounted, path: Variant) -> int:
	var state_store: _GF_REACTIVE_STATE_STORE_SCRIPT = _as_state_store(store)
	var path_text: String = _GF_REACTIVE_STATE_STORE_SCRIPT.format_path(path)
	var removed_count: int = 0
	for index: int in range(_bindings.size() - 1, -1, -1):
		var binding: Dictionary = _bindings[index]
		if _get_binding_store(binding) == state_store and GFVariantData.get_option_string(binding, "path") == path_text:
			_disconnect_binding(binding)
			_bindings.remove_at(index)
			removed_count += 1
	return removed_count


## 清理所有绑定。
## [br]
## @api public
## [br]
## @since 5.0.0
func clear() -> void:
	for binding: Dictionary in _bindings:
		_disconnect_binding(binding)
	_bindings.clear()


## 获取当前有效绑定数量。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 有效绑定数量。
func get_binding_count() -> int:
	_prune_invalid_bindings()
	return _bindings.size()


## 释放所有绑定。
## [br]
## @api public
## [br]
## @since 5.0.0
func dispose() -> void:
	clear()


# --- 私有/辅助方法 ---

## 将 store 新值写入绑定控件；路径被删除时使用 default_value。
## [br]
## @api private
func _apply_store_change_to_control(binding: Dictionary, change: Dictionary) -> void:
	var control: Control = _get_binding_control(binding)
	if control == null:
		var _removed_invalid_control_binding: bool = _remove_binding(binding)
		return

	binding["updating_control"] = true
	var value: Variant = GFVariantData.get_option_value(
		change,
		"new_value",
		GFVariantData.get_option_value(binding, "default_value")
	)
	if not GFVariantData.get_option_bool(change, "new_exists", true):
		value = GFVariantData.get_option_value(binding, "default_value")
	var _set_control_result: Variant = GFControlValueAdapter.set_value(control, value)
	binding["updating_control"] = false


## 忽略由 store 回写触发的控件变化，否则读取控件值并写入绑定路径。
## [br]
## @api private
func _apply_control_change_to_store(binding: Dictionary) -> void:
	if GFVariantData.get_option_bool(binding, "updating_control", false):
		return

	var store: _GF_REACTIVE_STATE_STORE_SCRIPT = _get_binding_store(binding)
	var control: Control = _get_binding_control(binding)
	if store == null or control == null:
		var _removed_invalid_binding: bool = _remove_binding(binding)
		return

	var value: Variant = GFControlValueAdapter.get_value(
		control,
		GFVariantData.get_option_value(binding, "default_value")
	)
	var path_segments: Array = GFVariantData.get_option_array(binding, "path_segments")
	var _set_value_result: Variant = store.set_value(path_segments, value)


## 按 binding_id 从本实例移除绑定并断开其关联；未找到时返回 false。
## [br]
## @api private
func _remove_binding(binding: Dictionary) -> bool:
	var binding_id: int = GFVariantData.get_option_int(binding, "binding_id", -1)
	if binding_id == -1:
		return false

	for index: int in range(_bindings.size() - 1, -1, -1):
		if GFVariantData.get_option_int(_bindings[index], "binding_id", -1) == binding_id:
			_disconnect_binding(_bindings[index])
			_bindings.remove_at(index)
			return true
	return false


## 调用取消订阅句柄，断开控件值变化与 tree_exited 连接，并清空绑定字典。
## [br]
## @api private
func _disconnect_binding(binding: Dictionary) -> void:
	var unsubscribe: Callable = _get_binding_callable(binding, "unsubscribe")
	if unsubscribe.is_valid():
		var _unsubscribe_result: Variant = unsubscribe.call()

	var value_connections: Array = GFVariantData.get_option_array(binding, "value_changed_connections")
	GFControlValueAdapter.disconnect_value_changed_handles(value_connections)

	var control: Control = _get_binding_control(binding)
	var tree_exited_callable: Callable = _get_binding_callable(binding, "tree_exited_callable")
	if (
		control != null
		and tree_exited_callable.is_valid()
		and control.tree_exited.is_connected(tree_exited_callable)
	):
		control.tree_exited.disconnect(tree_exited_callable)

	# Binding callbacks capture this Dictionary, so releasing external connections alone
	# does not break the self-reference cycle.
	binding.clear()


## 通过绑定中的 store 弱引用取得仍存活且类型匹配的状态存储。
## [br]
## @api private
func _get_binding_store(binding: Dictionary) -> _GF_REACTIVE_STATE_STORE_SCRIPT:
	var store_ref: WeakRef = _get_binding_weak_ref(binding, "store_ref")
	var raw_store: Object = _INSTANCE_GUARD._get_live_object_from_ref(store_ref)
	if raw_store is _GF_REACTIVE_STATE_STORE_SCRIPT:
		var store: _GF_REACTIVE_STATE_STORE_SCRIPT = raw_store
		return store
	return null


## 将 RefCounted 输入收窄为状态存储实例；类型不符时返回 null。
## [br]
## @api private
func _as_state_store(store: RefCounted) -> _GF_REACTIVE_STATE_STORE_SCRIPT:
	if store is _GF_REACTIVE_STATE_STORE_SCRIPT:
		var state_store: _GF_REACTIVE_STATE_STORE_SCRIPT = store
		return state_store
	return null


## 通过绑定中的控件弱引用取得仍有效的 Control。
## [br]
## @api private
func _get_binding_control(binding: Dictionary) -> Control:
	var control_ref: WeakRef = _get_binding_weak_ref(binding, "control_ref")
	return _INSTANCE_GUARD._get_live_control_from_ref(control_ref)


## 从绑定字典读取指定键，并仅在值为 WeakRef 时返回该引用。
## [br]
## @api private
func _get_binding_weak_ref(binding: Dictionary, key: String) -> WeakRef:
	var value: Variant = GFVariantData.get_option_value(binding, key)
	if value is WeakRef:
		var weak_ref: WeakRef = value
		return weak_ref
	return null


## 从绑定字典读取指定键，并仅在值为 Callable 时返回该回调。
## [br]
## @api private
func _get_binding_callable(binding: Dictionary, key: String) -> Callable:
	var value: Variant = GFVariantData.get_option_value(binding, key, Callable())
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


## 移除 store 或控件弱引用目标已经失效的绑定。
## [br]
## @api private
func _prune_invalid_bindings() -> void:
	for index: int in range(_bindings.size() - 1, -1, -1):
		var binding: Dictionary = _bindings[index]
		if _get_binding_store(binding) == null or _get_binding_control(binding) == null:
			_disconnect_binding(binding)
			_bindings.remove_at(index)




# --- 信号处理函数 ---

## 控件离树时按捕获的绑定标识找到并移除记录，统一解除状态与控件之间的监听。
## [br]
## @api private
func _on_control_tree_exited(binding_id: int) -> void:
	for index: int in range(_bindings.size() - 1, -1, -1):
		if GFVariantData.get_option_int(_bindings[index], "binding_id", -1) == binding_id:
			var _removed_exited_binding: bool = _remove_binding(_bindings[index])
			return
