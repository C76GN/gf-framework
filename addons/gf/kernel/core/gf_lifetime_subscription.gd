## GFLifetimeSubscription: 绑定 owner 生命周期的订阅句柄。
##
## owner 为 Node 时，节点退出场景树会自动取消订阅；owner 为普通 Object 时，
## 使用方或订阅源可通过 owner_is_released() 检查弱引用是否已经失效并执行清理。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
## [br]
## @layer kernel/core
class_name GFLifetimeSubscription
extends GFSubscriptionToken


# --- 私有变量 ---

var _owner_ref: WeakRef = null
var _owner_id: int = 0
var _owner_exit_callable: Callable = Callable()


# --- Godot 生命周期方法 ---

## 构造函数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param owner: 订阅生命周期 owner。
## [br]
## @param cancel_callback: 首次取消时执行的无参清理回调。
## [br]
## @param debug_label: 可选诊断标签。
func _init(owner: Object = null, cancel_callback: Callable = Callable(), debug_label: String = "") -> void:
	super._init(cancel_callback, debug_label)
	_set_owner(owner)


# --- 公共方法 ---

## 取消订阅并解除 owner 自动取消监听。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 本次调用是否首次取消了活动订阅。
func cancel() -> bool:
	_disconnect_owner_signal()
	return super.cancel()


## 返回订阅是否仍处于活动状态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return token 未取消且 owner 未释放时返回 true。
func is_active() -> bool:
	return super.is_active() and not owner_is_released()


## 返回生命周期 owner；未设置或已释放时返回 null。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前 owner 或 null。
func get_owner() -> Object:
	if _owner_ref == null:
		return null
	var raw_owner: Variant = _owner_ref.get_ref()
	if raw_owner is Object:
		var owner: Object = raw_owner
		if is_instance_valid(owner):
			return owner
	return null


## 返回 owner 的实例 ID；未设置时为 0。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return owner 实例 ID。
func get_owner_id() -> int:
	return _owner_id


## 返回 owner 是否已经释放。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return owner 曾经设置且当前已无法解析时返回 true。
func owner_is_released() -> bool:
	return _owner_id != 0 and get_owner() == null


# --- 私有/辅助方法 ---

func _set_owner(owner: Object) -> void:
	if owner == null:
		_owner_ref = null
		_owner_id = 0
		_cancel_callback = Callable()
		_active = false
		return

	_owner_ref = weakref(owner)
	_owner_id = owner.get_instance_id()
	if owner is Node:
		var owner_node: Node = owner
		_owner_exit_callable = Callable(self, "_on_owner_tree_exited")
		if not owner_node.tree_exited.is_connected(_owner_exit_callable):
			var _connect_result: Variant = owner_node.tree_exited.connect(
				_owner_exit_callable,
				CONNECT_ONE_SHOT as Object.ConnectFlags
			)


func _disconnect_owner_signal() -> void:
	if not _owner_exit_callable.is_valid():
		return
	var owner: Object = get_owner()
	if owner is Node:
		var owner_node: Node = owner
		if owner_node.tree_exited.is_connected(_owner_exit_callable):
			owner_node.tree_exited.disconnect(_owner_exit_callable)
	_owner_exit_callable = Callable()


func _on_owner_tree_exited() -> void:
	var _cancelled: bool = cancel()
