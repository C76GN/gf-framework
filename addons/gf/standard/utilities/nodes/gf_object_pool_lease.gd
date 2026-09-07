## GFObjectPoolLease: 一次节点借用的使用权。
##
## 归还后立即停止提供节点；物理离树和最终通知由对象池在安全点执行。
## 每次借用使用新的 Lease，旧 Lease 永远不能归还同一节点的新借用。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFObjectPoolLease
extends RefCounted


# --- 信号 ---

## 归还、节点丢失或池销毁完成时恰好发出一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: released、node_lost、pool_disposed 或 capacity_retired。
signal settled(reason: StringName)


# --- 枚举 ---

## 本次借用的状态；节点丢失也是 SETTLED，原因由 get_settlement_reason 提供。
## [br]
## @api public
## [br]
## @since unreleased
enum State {
	## 调用方仍持有节点使用权。
	ACTIVE,
	## 使用权已撤销，等待安全点清理。
	RELEASE_PENDING,
	## 本次借用已经结束。
	SETTLED,
}


# --- 私有变量 ---

var _state: State = State.SETTLED
var _reason: StringName = &"unconfigured"
var _pool_ref: WeakRef = null
var _node_ref: WeakRef = null
var _node_id: int = 0
var _configured: bool = false


# --- 公共方法 ---

## 取得仍由本次借用持有的节点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: ACTIVE 且仍存活的节点；归还、排队删除或丢失后返回 null。
func get_node() -> Node:
	if _state != State.ACTIVE or _node_ref == null:
		return null
	var value: Variant = _node_ref.get_ref()
	if value is Node and is_instance_valid(value):
		var node: Node = value
		if not node.is_queued_for_deletion():
			return node
	return null


## 归还本次借用。首次接纳后立即失去使用权，不支持撤销归还。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 本次调用首次接纳归还时为 true；重复或陈旧借用为 false。
func release() -> bool:
	if _state != State.ACTIVE or not Thread.is_main_thread():
		return false
	var value: Variant = _pool_ref.get_ref() if _pool_ref != null else null
	if value is GFObjectPoolUtility and is_instance_valid(value):
		var pool: GFObjectPoolUtility = value
		return pool.release_lease_for_framework(self, _node_id)
	mark_pending_for_framework()
	settle_for_framework(&"pool_disposed")
	return true


## 读取当前借用状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 当前 State。
func get_state() -> State:
	return _state


## 检查本次借用是否已经结束。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 任意终态均返回 true。
func is_settled() -> bool:
	return _state == State.SETTLED


## 等待归还完成；已完成时直接返回缓存的原因，允许多次等待。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 与 get_settlement_reason 相同的最终原因。
func wait_settled() -> StringName:
	if not is_settled():
		await settled
	return _reason


## 读取本次借用的最终原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 未结束时为 pending，未配置时为 unconfigured，否则为 settled 的原因。
func get_settlement_reason() -> StringName:
	return _reason


# --- 框架内部方法 ---

## 仅由池在成功挂载后初始化一次借用。
## [br]
## @api framework_internal
## [br]
## @param pool: 拥有该节点并接纳本轮归还的对象池，Lease 只保留弱引用。
## [br]
## @param node: 已成功挂载并交付本轮使用权的节点，Lease 记录其弱引用与实例 ID。
func configure_for_framework(pool: GFObjectPoolUtility, node: Node) -> void:
	if _configured:
		return
	_configured = true
	_pool_ref = weakref(pool)
	_node_ref = weakref(node)
	_node_id = node.get_instance_id()
	_state = State.ACTIVE
	_reason = &"pending"


## 同步吊销使用权，物理处理及通知尚未完成。
## [br]
## @api framework_internal
func mark_pending_for_framework() -> void:
	if _state == State.ACTIVE:
		_state = State.RELEASE_PENDING
		_node_ref = null


## 在池的状态提交后公布唯一终态。
## [br]
## @api framework_internal
## [br]
## @param reason: released、node_lost、pool_disposed 或 capacity_retired，首次结算后保持不变。
func settle_for_framework(reason: StringName) -> void:
	if _state == State.SETTLED:
		return
	_state = State.SETTLED
	_reason = reason
	_node_ref = null
	_pool_ref = null
	settled.emit(_reason)
