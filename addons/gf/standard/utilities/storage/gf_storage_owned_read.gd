## GFStorageOwnedRead: 独占异步读取的一次性领取句柄。
##
## 只能由 `GFStorageUtility.load_data_owned_request_async()` 取得有效句柄；手动
## 构造的实例不可领取。共享句柄即共享领取权，同一结果仅允许一次成功领取。
## caller 成功后，结果由句柄持有，直到领取、显式释放或句柄的最后一个引用释放。
## owner、取消令牌和超时只约束等待阶段，不撤销已经就绪或领取的结果。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFStorageOwnedRead
extends RefCounted


# --- 信号 ---

## caller 首次完成时发出不包含载荷的诊断；可在回调内立即调用 `take()`。
##
## 请求可能在入口返回前完成，应先检查 `is_completed()`。owner 已释放时可以
## 抑制通知，但终态仍可通过 `get_result()` 查询；晚到物理结果不会再次通知。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param receipt: 不含载荷或领取权限的不可变 caller 终态。
signal completed(receipt: GFStorageOwnedReadReceipt)


# --- 枚举 ---

## 独占读取句柄的领取权状态。
## [br]
## @api public
## [br]
## @since unreleased
enum State {
	## 未绑定请求的手动构造实例。
	INVALID,
	## 正在等待 caller 终态。
	WAITING,
	## 成功结果已经就绪，允许领取一次。
	READY,
	## 完整结果已经移交给领取方。
	TAKEN,
	## 已放弃领取权；尚未完成的物理请求仍由 Storage 收敛。
	RELEASED,
	## caller 已失败或取消，没有可领取结果。
	FAILED,
}


# --- 私有变量 ---

var _request: GFStorageAsyncRequestState = null
var _state: State = State.INVALID
var _receipt: GFStorageOwnedReadReceipt = null
var _read_result: GFStorageReadResult = null
var _completion_notified: bool = false


# --- 公共方法 ---

## 检查句柄是否由 Storage 绑定到合法请求。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已绑定的句柄返回 true，包括失败、已领取或已释放的句柄。
func is_valid() -> bool:
	return _request != null


## 获取 Utility 内唯一的物理请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 合法请求的大于零 ID；无效句柄返回 0。
func get_request_id() -> int:
	return _request.get_request_id() if _request != null else 0


## 获取 Utility 内唯一的 consumer ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 合法 consumer 的大于零 ID；无效句柄返回 0。
func get_consumer_id() -> int:
	return _request.get_consumer_id() if _request != null else 0


## 获取请求的规范逻辑文件名。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已验证的逻辑文件名；文件名校验前失败时可能为空。
func get_file_name() -> String:
	return _request.get_file_name() if _request != null else ""


## 获取当前领取权状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前 State 枚举值。
func get_state() -> State:
	return _state


## 检查是否仍在等待 caller 终态。
##
## 等待中调用 `release()` 只放弃领取权，仍可能返回 true，直到请求正常收敛。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 合法请求尚未取得 caller 终态时返回 true。
func is_pending() -> bool:
	return is_valid() and _receipt == null


## 检查 caller 终态是否已经写入。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已取得成功、失败或取消诊断时返回 true。
func is_completed() -> bool:
	return _receipt != null


## 获取不包含载荷和领取权限的不可变终态诊断。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已完成时返回同一不可变诊断，等待中或无效句柄返回 null。
func get_result() -> GFStorageOwnedReadReceipt:
	return _receipt


## 在主线程显式结束对尚未完成请求的观察。
##
## 返回 true 表示取消先于成功结算，不保证底层 worker 已经停止。
## 已经 READY 或 TAKEN 的结果不受取消影响。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param reason: 由共享生命周期规范化的稳定取消原因。
## [br]
## @return 本次调用首次结束 caller 观察时返回 true；非主线程返回 false。
func cancel_observation(reason: StringName = &"cancelled") -> bool:
	if not Thread.is_main_thread() or not is_pending():
		return false
	return _request.cancel_observation(reason)


## 在主线程一次性领取完整结果，不复制载荷或调用外部回调。
##
## 可以在 `completed` 回调内调用。成功移交前先清空句柄的载荷引用，重复领取
## 返回 ALREADY_TAKEN；失败状态与成功的空 Dictionary 不会混淆。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 包含闭合状态的领取结果，只有 SUCCESS 持有完整 GFStorageReadResult。
func take() -> GFStorageOwnedReadTakeResult:
	if not Thread.is_main_thread():
		return _make_take_result(GFStorageOwnedReadTakeResult.Status.WRONG_THREAD)
	match _state:
		State.WAITING:
			return _make_take_result(GFStorageOwnedReadTakeResult.Status.NOT_READY)
		State.READY:
			var claimed_result: GFStorageReadResult = _read_result
			_read_result = null
			_state = State.TAKEN
			return _make_take_result(GFStorageOwnedReadTakeResult.Status.SUCCESS, claimed_result)
		State.TAKEN:
			return _make_take_result(GFStorageOwnedReadTakeResult.Status.ALREADY_TAKEN)
		State.RELEASED:
			return _make_take_result(GFStorageOwnedReadTakeResult.Status.RELEASED)
		State.FAILED:
			return _make_take_result(GFStorageOwnedReadTakeResult.Status.FAILED)
	return _make_take_result(GFStorageOwnedReadTakeResult.Status.INVALID)


## 在主线程放弃领取权，立即释放已经就绪的载荷。
##
## 等待中的请求仍按原生命周期收敛，终态诊断仍可查询。重复释放没有副作用，
## 也不会撤销已经移交给领取方的结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 首次从 WAITING 或 READY 释放时返回 true；其他状态或非主线程返回 false。
func release() -> bool:
	if not Thread.is_main_thread() or _state not in [State.WAITING, State.READY]:
		return false
	_read_result = null
	_state = State.RELEASED
	return true


# --- 框架内部方法 ---

## 在请求可能同步完成之前绑定唯一内部生命周期。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param request_state: 已分配请求与 consumer 身份的共享内部状态。
## [br]
## @return 首次绑定合法等待中请求时返回 true。
func configure_for_framework(request_state: GFStorageAsyncRequestState) -> bool:
	if not Thread.is_main_thread() or _request != null or request_state == null:
		return false
	if (
		request_state.get_request_id() <= 0
		or request_state.get_consumer_id() <= 0
		or not request_state.is_caller_pending()
	):
		return false
	_request = request_state
	_state = State.WAITING
	return true


## 安装 caller 终态并按需通知，接收已隔离结果的唯一引用。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param receipt: 已冻结且与请求身份匹配的小型诊断。
## [br]
## @param read_result: 成功时已经完成迁移与隔离的结果；不复制。
## [br]
## @param emit_completion_signal: Utility 使用 false 安装终态，清除内部结果引用后另行通知。
## [br]
## @return 首次接受 caller 终态时返回 true。
func complete_for_framework(
	receipt: GFStorageOwnedReadReceipt,
	read_result: GFStorageReadResult = null,
	emit_completion_signal: bool = true
) -> bool:
	if not Thread.is_main_thread() or not is_pending() or receipt == null:
		return false
	if (
		receipt.get_request_id() != get_request_id()
		or receipt.get_consumer_id() != get_consumer_id()
		or receipt.get_file_name() != get_file_name()
	):
		return false
	if receipt.is_ok():
		if _state == State.WAITING and (
			read_result == null
			or not read_result.ok
			or read_result.error_code != OK
		):
			return false
	elif read_result != null:
		return false
	_receipt = receipt
	if _state == State.WAITING:
		if receipt.is_ok():
			_read_result = read_result
			_state = State.READY
		else:
			_state = State.FAILED
	if emit_completion_signal:
		read_result = null
		notify_completion_for_framework()
	return true


## 在安装终态且清除所有交付临时引用后发送一次小型通知。
## [br]
## @api framework_internal
## [br]
## @param emit_completion_signal: owner 已释放时为 false，消费通知权但保留可查询终态。
func notify_completion_for_framework(emit_completion_signal: bool = true) -> void:
	if not Thread.is_main_thread() or _receipt == null or _completion_notified:
		return
	_completion_notified = true
	if emit_completion_signal:
		completed.emit(_receipt)


# --- 私有/辅助方法 ---

func _make_take_result(
	status: GFStorageOwnedReadTakeResult.Status,
	read_result: GFStorageReadResult = null
) -> GFStorageOwnedReadTakeResult:
	var result: GFStorageOwnedReadTakeResult = GFStorageOwnedReadTakeResult.new()
	var _configured: bool = result.configure_for_framework(status, read_result)
	return result
