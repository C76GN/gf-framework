## GFKernelRuntime: GFArchitecture 的内核运行时状态机。
##
## 该类型只承载架构主生命周期、generation 和事务上下文，不直接认识 Model、
## System、Utility 或项目业务对象。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 8.0.0
## [br]
## @layer kernel/core
class_name GFKernelRuntime
extends RefCounted


# --- 枚举 ---

## 架构主生命周期状态。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
enum LifecycleState {
	## 尚未初始化。
	NEW,
	## 正在推进模块生命周期。
	INITIALIZING,
	## 已完成 ready 阶段。
	READY,
	## 初始化失败，注册表应保持失败边界。
	FAILED,
	## 正在释放运行时。
	DISPOSING,
	## 已释放，进入终态。
	DISPOSED,
}


# --- 常量 ---

const _TRANSACTION_ACTIVE_KEY: String = "active"
const _TRANSACTION_CANCELLED_KEY: String = "cancelled"
const _TRANSACTION_FAILED_KEY: String = "failed"
const _TRANSACTION_GENERATION_KEY: String = "generation"
const _TRANSACTION_ID_KEY: String = "id"
const _TRANSACTION_LABEL_KEY: String = "label"


# --- 私有变量 ---

var _state: LifecycleState = LifecycleState.NEW
var _lifecycle_generation: int = 0
var _transactions: Array[Dictionary] = []
var _next_transaction_id: int = 1


# --- 框架内部方法 ---

## 返回当前主生命周期状态。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return 当前 LifecycleState 值。
func get_state() -> LifecycleState:
	return _state


## 返回当前主生命周期状态名称。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return 适合诊断输出的状态名称。
func get_state_name() -> String:
	match _state:
		LifecycleState.NEW:
			return "new"
		LifecycleState.INITIALIZING:
			return "initializing"
		LifecycleState.READY:
			return "ready"
		LifecycleState.FAILED:
			return "failed"
		LifecycleState.DISPOSING:
			return "disposing"
		LifecycleState.DISPOSED:
			return "disposed"
		_:
			return "unknown"


## 返回当前生命周期 generation。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return 当前 generation。
func get_lifecycle_generation() -> int:
	return _lifecycle_generation


## 检查指定 generation 是否仍为当前 generation。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param lifecycle_generation: 待检查的 generation。
## [br]
## @return generation 匹配时返回 true。
func is_generation_current(lifecycle_generation: int) -> bool:
	return _lifecycle_generation == lifecycle_generation


## 检查架构是否处于 ready 状态。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return ready 状态返回 true。
func is_ready() -> bool:
	return _state == LifecycleState.READY


## 检查架构是否正在初始化。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return initializing 状态返回 true。
func is_initializing() -> bool:
	return _state == LifecycleState.INITIALIZING


## 检查架构是否已失败。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return failed 状态返回 true。
func has_failed() -> bool:
	return _state == LifecycleState.FAILED


## 检查架构是否正在释放。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return disposing 状态返回 true。
func is_disposing() -> bool:
	return _state == LifecycleState.DISPOSING


## 检查架构是否已释放。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return disposed 状态返回 true。
func is_disposed() -> bool:
	return _state == LifecycleState.DISPOSED


## 检查当前生命周期是否允许异步写回继续提交。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return initializing 或 ready 状态返回 true。
func is_lifecycle_active() -> bool:
	return _state == LifecycleState.INITIALIZING or _state == LifecycleState.READY


## 开始一次初始化流程并推进 generation。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return 新初始化流程的 generation。
func begin_initialization() -> int:
	_lifecycle_generation += 1
	_state = LifecycleState.INITIALIZING
	return _lifecycle_generation


## 完成当前初始化流程。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param lifecycle_generation: 初始化流程持有的 generation。
## [br]
## @return generation 仍有效且状态可提交时返回 true。
func finish_initialization(lifecycle_generation: int) -> bool:
	if not is_generation_current(lifecycle_generation):
		return false
	if _state != LifecycleState.INITIALIZING:
		return false
	_state = LifecycleState.READY
	return true


## 将当前初始化流程标记为失败并推进 generation。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param lifecycle_generation: 触发失败的流程 generation。
## [br]
## @return 首次进入 failed 状态时返回 true。
func fail_initialization(lifecycle_generation: int) -> bool:
	if _state == LifecycleState.FAILED:
		return false
	if not is_generation_current(lifecycle_generation):
		return false
	_lifecycle_generation += 1
	_state = LifecycleState.FAILED
	_mark_transactions_failed()
	return true


## 将失败状态清回 NEW，供安全重试使用。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return 状态发生改变时返回 true。
func clear_failure() -> bool:
	if _state != LifecycleState.FAILED:
		return false
	_state = LifecycleState.NEW
	return true


## 开始释放流程并推进 generation。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @return 本次调用成功进入 disposing 状态时返回 true。
func begin_dispose() -> bool:
	if _state == LifecycleState.DISPOSING or _state == LifecycleState.DISPOSED:
		return false
	_lifecycle_generation += 1
	_state = LifecycleState.DISPOSING
	_mark_transactions_cancelled()
	return true


## 完成释放流程并进入 disposed 终态。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
func finish_dispose() -> void:
	_state = LifecycleState.DISPOSED
	_transactions.clear()


## 开始一个运行时事务上下文。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param label: 事务诊断名称。
## [br]
## @return 事务上下文字典。
## [br]
## @schema return: Dictionary with id, label, generation, active, failed, and cancelled fields.
func begin_transaction(label: String) -> Dictionary:
	var transaction: Dictionary = {
		_TRANSACTION_ID_KEY: _next_transaction_id,
		_TRANSACTION_LABEL_KEY: label,
		_TRANSACTION_GENERATION_KEY: _lifecycle_generation,
		_TRANSACTION_ACTIVE_KEY: true,
		_TRANSACTION_FAILED_KEY: false,
		_TRANSACTION_CANCELLED_KEY: false,
	}
	_next_transaction_id += 1
	_transactions.append(transaction)
	return transaction


## 完成一个运行时事务上下文。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param transaction: begin_transaction() 返回的事务上下文。
## [br]
## @schema transaction: Dictionary returned by begin_transaction().
func finish_transaction(transaction: Dictionary) -> void:
	if transaction.is_empty():
		return
	transaction[_TRANSACTION_ACTIVE_KEY] = false
	var transaction_id: int = _get_transaction_id(transaction)
	for index: int in range(_transactions.size() - 1, -1, -1):
		if _get_transaction_id(_transactions[index]) == transaction_id:
			_transactions.remove_at(index)
			return


## 检查事务是否已经被全局失败或 dispose 失效。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param transaction: begin_transaction() 返回的事务上下文。
## [br]
## @schema transaction: Dictionary returned by begin_transaction().
## [br]
## @return 事务已失效时返回 true。
func is_transaction_invalidated(transaction: Dictionary) -> bool:
	if transaction.is_empty():
		return true
	if _get_transaction_bool(transaction, _TRANSACTION_FAILED_KEY):
		return true
	if _get_transaction_bool(transaction, _TRANSACTION_CANCELLED_KEY):
		return true
	return _get_transaction_generation(transaction) != _lifecycle_generation


## 检查事务是否因为全局初始化失败而失效。
## [br]
## @api framework_internal
## [br]
## @layer kernel/core
## [br]
## @param transaction: begin_transaction() 返回的事务上下文。
## [br]
## @schema transaction: Dictionary returned by begin_transaction().
## [br]
## @return 全局初始化失败触发事务失效时返回 true。
func is_transaction_failed(transaction: Dictionary) -> bool:
	if transaction.is_empty():
		return false
	return _get_transaction_bool(transaction, _TRANSACTION_FAILED_KEY)


# --- 私有/辅助方法 ---

func _mark_transactions_failed() -> void:
	for transaction: Dictionary in _transactions:
		transaction[_TRANSACTION_FAILED_KEY] = true


func _mark_transactions_cancelled() -> void:
	for transaction: Dictionary in _transactions:
		transaction[_TRANSACTION_CANCELLED_KEY] = true


func _get_transaction_id(transaction: Dictionary) -> int:
	return _get_transaction_int(transaction, _TRANSACTION_ID_KEY)


func _get_transaction_generation(transaction: Dictionary) -> int:
	return _get_transaction_int(transaction, _TRANSACTION_GENERATION_KEY)


func _get_transaction_int(transaction: Dictionary, key: String) -> int:
	if not transaction.has(key):
		return 0
	var value: Variant = transaction[key]
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	return 0


func _get_transaction_bool(transaction: Dictionary, key: String) -> bool:
	if not transaction.has(key):
		return false
	var value: Variant = transaction[key]
	if value is bool:
		var bool_value: bool = value
		return bool_value
	return false
