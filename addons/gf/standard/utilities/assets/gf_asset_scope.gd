## 贯穿资源请求和句柄的生命周期。关闭会取消 pending 请求并释放全部句柄。
## Node owner 退出树时自动关闭；其他 owner 失效由资源服务 tick 检测。
## scope 只撤销 GF 保留及交付资格，不销毁调用者已经保存的 Resource 引用。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFAssetScope
extends RefCounted


# --- 私有变量 ---

## 生命周期是否已关闭。
## [br]
## @api private
var _closed: bool = false

## 绑定服务的弱引用。
## [br]
## @api private
var _utility_ref: WeakRef

## 可选 owner 的弱引用。
## [br]
## @api private
var _owner_ref: WeakRef

## 本 scope 尚未完成的请求。
## [br]
## @api private
var _operations: Array[GFAssetLoadOperation] = []

## 本 scope 持有的资源句柄。
## [br]
## @api private
var _handles: Array[GFAssetHandle] = []


# --- Godot 回调方法 ---

## 最后一个 scope 引用丢弃时释放资源。
## [br]
## @api private
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Godot has invalidated self for method dispatch at this point; release
		# the owned records directly instead of calling a method on this scope.
		_closed = true
		for operation: GFAssetLoadOperation in _operations:
			var _cancelled: bool = operation.cancel()
		for handle: GFAssetHandle in _handles:
			var _released: bool = handle.release()


# --- 公共方法 ---

## 关闭生命周期；重复关闭无副作用。
## [br]
## @api public
## [br]
## @since unreleased
func close() -> void:
	stop_accepting_for_framework()
	var operations: Array[GFAssetLoadOperation] = _operations.duplicate()
	var handles: Array[GFAssetHandle] = _handles.duplicate()
	_operations.clear()
	_handles.clear()
	for operation: GFAssetLoadOperation in operations:
		var _cancelled: bool = operation.cancel()
	for handle: GFAssetHandle in handles:
		var _released: bool = handle.release()


## 判断 scope 是否仍允许请求与句柄保留。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 未关闭且 owner 存活时为 true。
func is_open() -> bool:
	if (
		not _closed
		and _owner_ref != null
		and _owner_ref.get_ref() == null
	):
		close()
	return not _closed


# --- 框架内部方法 ---

## 在批量 owner 释放中先同步撤销本 scope 准入，不执行任何消费者回调。
## 调用方必须在同一同步批次中继续 close()，消费 pending 操作与句柄。
## [br]
## @api framework_internal
## [br]
## @since unreleased
func stop_accepting_for_framework() -> void:
	if _closed:
		return
	_closed = true
	var owner: Object = _owner_ref.get_ref() if _owner_ref != null else null
	if owner is Node:
		var owner_node: Node = owner
		if owner_node.tree_exiting.is_connected(close):
			owner_node.tree_exiting.disconnect(close)


## 绑定服务及可选 owner。
## [br]
## @api framework_internal
## [br]
## @param utility: 资源服务。
## [br]
## @param owner: 可选生命周期拥有者。
func bind_for_framework(utility: GFAssetUtility, owner: Object) -> void:
	_utility_ref = weakref(utility)
	_owner_ref = weakref(owner) if owner != null else null
	if owner is Node:
		var owner_node: Node = owner
		var _connected: Error = owner_node.tree_exiting.connect(close) as Error


## 验证 scope 来自指定服务。
## [br]
## @api framework_internal
## [br]
## @param utility: 要比较的资源服务。
## [br]
## @return 同一个服务且 scope 开启时为 true。
func accepts_for_framework(utility: GFAssetUtility) -> bool:
	return (
		is_open()
		and _utility_ref != null
		and _utility_ref.get_ref() == utility
	)


## 返回 scope 唯一 owner，供服务账本归因使用。
## [br]
## @api framework_internal
## [br]
## @return 活着的 owner 或 null。
func get_owner_for_framework() -> Object:
	return _owner_ref.get_ref() if _owner_ref != null else null


## 登记 pending 请求。
## [br]
## @api framework_internal
## [br]
## @param operation: 当前 scope 的请求。
func track_operation_for_framework(operation: GFAssetLoadOperation) -> void:
	_operations.append(operation)


## 移除已完成请求。
## [br]
## @api framework_internal
## [br]
## @param operation: 已完成请求。
func finish_for_framework(operation: GFAssetLoadOperation) -> void:
	_operations.erase(operation)


## 登记成功句柄；如果关闭已发生则立即释放。
## [br]
## @api framework_internal
## [br]
## @param handle: 服务创建的句柄。
## [br]
## @return scope 接受并持有句柄时为 true。
func track_handle_for_framework(handle: GFAssetHandle) -> bool:
	if not is_open():
		var _released: bool = handle.release()
		return false
	_handles.append(handle)
	return true
