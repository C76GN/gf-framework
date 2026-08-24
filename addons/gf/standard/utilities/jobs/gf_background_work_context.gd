## GFBackgroundWorkContext: CPU/IO worker 的线程安全只读协作取消句柄。
##
## Utility 为已接纳的 CPU/IO work record 建立并由 Task 持有。
## opt-in 时作为 worker 第二参数；无需 release，终态、clear、dispose 后仍可读且不延长 Utility/线程寿命。
## 自行 new() 得到未绑定对象，不能作为取消入口。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFBackgroundWorkContext
extends RefCounted


# --- 枚举 ---

## 框架拥有的稳定取消原因。
## [br]
## @api public
## [br]
## @since unreleased
enum CancellationReason {
	## 尚未请求取消。
	NONE = 0,
	## cancel_work() 请求取消。
	CANCEL_WORK = 1,
	## cancel_all() 请求取消。
	CANCEL_ALL = 2,
	## clear_all() 请求取消并清空任务。
	CLEAR_ALL = 3,
	## GFBackgroundWorkUtility.dispose() 请求取消。
	UTILITY_DISPOSED = 4,
}


# --- 私有变量 ---

var _mutex: Mutex = Mutex.new()
var _work_id: StringName = &""
var _cancel_requested: bool = false
var _cancel_reason: CancellationReason = CancellationReason.NONE
var _cancel_requested_msec: int = 0


# --- 公共方法 ---

## 返回所属工作的稳定 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 建立上下文时从 work record 冻结的工作 ID。
func get_work_id() -> StringName:
	_mutex.lock()
	var work_id: StringName = _work_id
	_mutex.unlock()
	return work_id


## 返回是否已经收到取消请求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已请求取消时返回 true。
func is_cancel_requested() -> bool:
	_mutex.lock()
	var requested: bool = _cancel_requested
	_mutex.unlock()
	return requested


## 返回稳定取消原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 首次取消请求提供的原因；未取消时为 NONE。
func get_cancel_reason() -> CancellationReason:
	_mutex.lock()
	var reason: CancellationReason = _cancel_reason
	_mutex.unlock()
	return reason


## 返回首次取消请求发生时的 Time.get_ticks_msec()。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 首次取消请求的毫秒 tick；未取消时为 0。
func get_cancel_requested_msec() -> int:
	_mutex.lock()
	var requested_msec: int = _cancel_requested_msec
	_mutex.unlock()
	return requested_msec


## 获取纯数据取消状态快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 同一锁采样的取消状态快照。
## [br]
## @schema return: Dictionary，精确包含 work_id: String、cancel_requested: bool、cancel_reason: int、cancel_reason_name: String 和 cancel_requested_msec: int。
func get_debug_snapshot() -> Dictionary:
	_mutex.lock()
	var snapshot: Dictionary = {
		"work_id": String(_work_id),
		"cancel_requested": _cancel_requested,
		"cancel_reason": _cancel_reason,
		"cancel_reason_name": cancellation_reason_name(_cancel_reason),
		"cancel_requested_msec": _cancel_requested_msec,
	}
	_mutex.unlock()
	return snapshot


## 获取取消原因名称。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: 取消原因。
## [br]
## @return 稳定的小写原因名称。
static func cancellation_reason_name(reason: CancellationReason) -> String:
	match reason:
		CancellationReason.NONE:
			return "none"
		CancellationReason.CANCEL_WORK:
			return "cancel_work"
		CancellationReason.CANCEL_ALL:
			return "cancel_all"
		CancellationReason.CLEAR_ALL:
			return "clear_all"
		CancellationReason.UTILITY_DISPOSED:
			return "utility_disposed"
	return "unknown"


# --- 框架内部方法 ---

## 绑定所属工作 ID。
## [br]
## @api framework_internal
## [br]
## @param work_id: 已冻结的非空工作 ID。
## [br]
## @return 首次绑定或同值重复绑定返回 OK；其它情况返回错误。
func configure_for_framework(work_id: StringName) -> Error:
	if work_id == &"":
		return ERR_INVALID_PARAMETER
	_mutex.lock()
	var error: Error = OK
	if _work_id == &"":
		_work_id = work_id
	elif _work_id != work_id:
		error = ERR_ALREADY_IN_USE
	_mutex.unlock()
	return error


## 原子发布取消请求。
## [br]
## @api framework_internal
## [br]
## @param reason: 非 NONE 的稳定取消原因。
## [br]
## @return 首次发布返回 true；重复请求返回 false 且不覆盖原原因。
func request_cancel_for_framework(reason: CancellationReason) -> bool:
	if reason == CancellationReason.NONE:
		return false
	_mutex.lock()
	if _cancel_requested:
		_mutex.unlock()
		return false
	_cancel_requested = true
	_cancel_reason = reason
	_cancel_requested_msec = Time.get_ticks_msec()
	_mutex.unlock()
	return true
