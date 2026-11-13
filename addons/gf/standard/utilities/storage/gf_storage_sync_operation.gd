## GFStorageSyncOperation: 一次同步观察的取消与唯一终态句柄。
##
## 取消只结束调用方等待，不能证明远端停止写入。已发送提交的取消、超时或释放结果
## 由引擎报告为未知，并通过原操作 ID 恢复；迟到响应不会改变已经交付的终态。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFStorageSyncOperation
extends RefCounted


# --- 信号 ---

## 进入唯一终态时发出一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 不可变终态。
signal completed(result: GFStorageSyncResult)

## 引擎处理调用方的停止等待请求。
## [br]
## @api framework_internal
## [br]
## @since unreleased
signal cancel_requested


# --- 私有变量 ---

## 复用主线程完成源保证唯一终态。
## [br]
## @api private
var _completion: GFAsyncCompletion = GFAsyncCompletion.new()

## 已封存结果，只通过只读公开入口暴露。
## [br]
## @api private
var _result: GFStorageSyncResult = null

## 是否已经请求停止等待。
## [br]
## @api private
var _cancel_requested: bool = false


# --- 公共方法 ---

## 检查当前观察是否已经结束。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已交付终态返回 true。
func is_completed() -> bool:
	return _completion.is_completed()


## 获取已封存结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 终态；等待中为空。
func get_result() -> GFStorageSyncResult:
	return _result


## 等待唯一终态；已经完成时立即返回，不再次启动同步。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 不可变终态。
func wait_result_async() -> GFStorageSyncResult:
	if not is_completed():
		await completed
	return _result


## 请求结束调用方等待；不取消远端物理提交。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 首次仍在等待的请求返回 true。
func cancel_wait() -> bool:
	if is_completed() or _cancel_requested:
		return false
	_cancel_requested = true
	cancel_requested.emit()
	return true


## 检查是否曾请求结束等待。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已请求返回 true。
func is_cancel_requested() -> bool:
	return _cancel_requested


# --- 框架内部方法 ---

## 首次提交结果；引擎应先撤销在途观察和所有权，再调用本入口。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param result: 已封存的有效结果。
## [br]
## @return 首次合法终结成功时为 true。
func complete_for_framework(result: GFStorageSyncResult) -> bool:
	if (
		result == null
		or not result.is_valid()
		or not _completion.succeed()
	):
		return false
	_result = result
	completed.emit(result)
	return true
