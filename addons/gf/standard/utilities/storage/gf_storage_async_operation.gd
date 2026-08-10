## GFStorageAsyncOperation: 单次异步存储请求句柄。
##
## 句柄由 `GFStorageUtility` 分配唯一请求 ID，并且只接受一个终态。调用方应先
## 检查 `is_completed()`，再决定是否等待 `completed` 信号。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 10.0.0
class_name GFStorageAsyncOperation
extends RefCounted


# --- 信号 ---

## 请求进入终态时发出一次。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param result: 与当前请求 ID 匹配的隔离结果。
signal completed(result: GFStorageAsyncResult)


# --- 常量 ---

## 异步写入请求。
## [br]
## @api public
## [br]
## @since 10.0.0
const OPERATION_SAVE: StringName = &"save"

## 异步读取请求。
## [br]
## @api public
## [br]
## @since 10.0.0
const OPERATION_LOAD: StringName = &"load"


# --- 私有变量 ---

var _request_id: int = 0
var _operation: StringName = &""
var _file_name: String = ""
var _result: GFStorageAsyncResult = null
var _payload_transfer: GFStoragePayloadTransfer = null
var _payload_attempt_id: int = 0
var _payload_attempt_finished: bool = false
var _failed_payload_reclaimed: bool = false


# --- 公共方法 ---

## 获取 Utility 内唯一请求 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 大于零的请求 ID。
func get_request_id() -> int:
	return _request_id


## 获取请求类型。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return `OPERATION_SAVE` 或 `OPERATION_LOAD`。
func get_operation() -> StringName:
	return _operation


## 获取规范化存储文件名。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已通过路径校验的请求返回规范相对文件名；校验前被拒绝时返回空字符串。
func get_file_name() -> String:
	return _file_name


## 检查请求是否等待终态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已配置且未完成时返回 true。
func is_pending() -> bool:
	return _request_id > 0 and _result == null


## 检查请求是否已有终态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已完成时返回 true。
func is_completed() -> bool:
	return _result != null


## 获取终态结果副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 已完成结果；等待中返回 null。
func get_result() -> GFStorageAsyncResult:
	return _result.duplicate_result() if _result != null else null


## 获取当前请求关联的 opaque payload transfer。
##
## 该句柄不公开 payload，可在当前 attempt 仍运行时交给同一 Storage 和规范文件
## 发起 timeout retry。调用方完成整个重试 generation 后必须显式 `release()`。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 等待中的 transfer-backed save 请求返回句柄；终态及普通 save/load 请求返回 null。
func get_payload_transfer() -> GFStoragePayloadTransfer:
	if not is_pending():
		return null
	return _payload_transfer


## 一次性取回失败请求关联的 opaque payload transfer。
##
## 仅请求进入失败终态且 attempt lease 已结束后可取回。返回值仍不公开 payload，
## 但可直接用于同一冻结 Storage、文件名和 codec options 的重试。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 首次取回失败 transfer 时返回原句柄；其他情况返回 null。
func reclaim_failed_payload() -> GFStoragePayloadTransfer:
	if (
		_result == null
		or _result.is_successful()
		or _payload_transfer == null
		or not _payload_attempt_finished
		or _failed_payload_reclaimed
	):
		return null
	_failed_payload_reclaimed = true
	return _payload_transfer


# --- 框架内部方法 ---

## 由 Storage Utility 初始化请求身份。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param request_id: Utility 内唯一请求 ID。
## [br]
## @param operation: 请求类型。
## [br]
## @param file_name: 当前 Storage root 内的规范相对文件名；校验前初始化请求身份时允许为空。
## [br]
## @return 首次配置成功返回 true。
func configure_for_framework(request_id: int, operation: StringName, file_name: String) -> bool:
	if _request_id != 0 or request_id <= 0:
		return false
	if operation not in [OPERATION_SAVE, OPERATION_LOAD]:
		return false
	_request_id = request_id
	_operation = operation
	_file_name = file_name
	return true


## 在请求入队前写入 Storage 规范化后的文件名。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param file_name: 当前 Storage root 内的规范相对文件名。
## [br]
## @return 请求仍在等待且文件名非空时返回 true。
func set_file_name_for_framework(file_name: String) -> bool:
	if not is_pending() or file_name.is_empty():
		return false
	_file_name = file_name
	return true


## 关联一次 transfer-backed Storage attempt。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param transfer: 已取得 attempt lease 的 opaque transfer。
## [br]
## @param attempt_id: transfer 分配的活动 attempt ID。
## [br]
## @return 首次关联合法 attempt 时返回 true。
func configure_payload_attempt_for_framework(
	transfer: GFStoragePayloadTransfer,
	attempt_id: int
) -> bool:
	if (
		not is_pending()
		or transfer == null
		or attempt_id <= 0
		or _payload_transfer != null
	):
		return false
	_payload_transfer = transfer
	_payload_attempt_id = attempt_id
	return true


## 结束当前请求持有的 transfer attempt lease。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 首次结束关联 attempt 时返回 true。
func finish_payload_attempt_for_framework() -> bool:
	if (
		_payload_transfer == null
		or _payload_attempt_id <= 0
		or _payload_attempt_finished
	):
		return false
	if not _payload_transfer.finish_attempt_for_framework(_payload_attempt_id):
		return false
	_payload_attempt_finished = true
	return true


## 由 Storage Utility 写入并发出唯一终态。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param result: 与当前请求身份一致的结果。
## [br]
## @return 首次完成成功返回 true。
func complete_for_framework(result: GFStorageAsyncResult) -> bool:
	if not is_pending() or result == null:
		return false
	if result.get_request_id() != _request_id or result.get_operation() != _operation:
		return false
	if _payload_transfer != null and not _payload_attempt_finished:
		return false
	_result = result.duplicate_result()
	completed.emit(_result.duplicate_result())
	return true
