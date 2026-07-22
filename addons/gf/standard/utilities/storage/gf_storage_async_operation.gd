## GFStorageAsyncOperation: 单次异步存储请求句柄。
##
## 句柄由 `GFStorageUtility` 分配唯一请求 ID，并且只接受一个终态。调用方应先
## 检查 `is_completed()`，再决定是否等待 `completed` 信号。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFStorageAsyncOperation
extends RefCounted


# --- 信号 ---

## 请求进入终态时发出一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 与当前请求 ID 匹配的隔离结果。
signal completed(result: GFStorageAsyncResult)


# --- 常量 ---

## 异步写入请求。
## [br]
## @api public
## [br]
## @since unreleased
const OPERATION_SAVE: StringName = &"save"

## 异步读取请求。
## [br]
## @api public
## [br]
## @since unreleased
const OPERATION_LOAD: StringName = &"load"


# --- 私有变量 ---

var _request_id: int = 0
var _operation: StringName = &""
var _file_name: String = ""
var _result: GFStorageAsyncResult = null


# --- 公共方法 ---

## 获取 Utility 内唯一请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的请求 ID。
func get_request_id() -> int:
	return _request_id


## 获取请求类型。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `OPERATION_SAVE` 或 `OPERATION_LOAD`。
func get_operation() -> StringName:
	return _operation


## 获取规范化存储文件名。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求实际使用的文件名。
func get_file_name() -> String:
	return _file_name


## 检查请求是否等待终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置且未完成时返回 true。
func is_pending() -> bool:
	return _request_id > 0 and _result == null


## 检查请求是否已有终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已完成时返回 true。
func is_completed() -> bool:
	return _result != null


## 获取终态结果副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已完成结果；等待中返回 null。
func get_result() -> GFStorageAsyncResult:
	return _result.duplicate_result() if _result != null else null


# --- 框架内部方法 ---

## 由 Storage Utility 初始化请求身份。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param request_id: Utility 内唯一请求 ID。
## [br]
## @param operation: 请求类型。
## [br]
## @param file_name: 规范化文件名。
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
## @since unreleased
## [br]
## @param file_name: 规范化文件名。
## [br]
## @return 请求仍在等待且文件名非空时返回 true。
func set_file_name_for_framework(file_name: String) -> bool:
	if not is_pending() or file_name.is_empty():
		return false
	_file_name = file_name
	return true


## 由 Storage Utility 写入并发出唯一终态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param result: 与当前请求身份一致的结果。
## [br]
## @return 首次完成成功返回 true。
func complete_for_framework(result: GFStorageAsyncResult) -> bool:
	if not is_pending() or result == null:
		return false
	if result.get_request_id() != _request_id or result.get_operation() != _operation:
		return false
	_result = result.duplicate_result()
	completed.emit(_result.duplicate_result())
	return true
