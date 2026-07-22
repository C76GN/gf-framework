## GFStorageAsyncResult: 单次异步存储请求的不可变终态。
##
## 结果通过请求 ID 与具体句柄绑定；读取结果保留 `GFStorageReadResult` 的类型化
## 失败分类，写入结果只暴露稳定 Error 码。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageAsyncResult
extends RefCounted


# --- 私有变量 ---

var _request_id: int = 0
var _operation: StringName = &""
var _file_name: String = ""
var _ok: bool = false
var _error_code: Error = FAILED
var _read_result: GFStorageReadResult = null


# --- 公共方法 ---

## 获取 Storage Utility 分配的请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的 Utility 内唯一请求 ID。
func get_request_id() -> int:
	return _request_id


## 获取请求类型。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `GFStorageAsyncOperation.OPERATION_*` 常量之一。
func get_operation() -> StringName:
	return _operation


## 获取规范化存储文件名。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求实际使用的存储相对文件名或绝对文件名。
func get_file_name() -> String:
	return _file_name


## 检查请求是否成功。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 写入错误码为 OK，或读取结果成功时返回 true。
func is_successful() -> bool:
	return _ok


## 获取请求 Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功时为 OK。
func get_error_code() -> Error:
	return _error_code


## 获取读取结果副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return load 请求的结果；save 请求返回 null。
func get_read_result() -> GFStorageReadResult:
	return _read_result.duplicate_result() if _read_result != null else null


## 创建隔离结果副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新结果对象。
func duplicate_result() -> GFStorageAsyncResult:
	var copy: GFStorageAsyncResult = GFStorageAsyncResult.new()
	var _configured: bool = copy.configure_for_framework(
		_request_id,
		_operation,
		_file_name,
		_ok,
		_error_code,
		_read_result
	)
	return copy


## 转换为可报告字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 包含请求身份、终态和读取摘要的字典。
## [br]
## @schema return: Dictionary with request_id, operation, file_name, ok, error_code, and read_result fields.
func to_dict() -> Dictionary:
	return {
		"request_id": _request_id,
		"operation": _operation,
		"file_name": _file_name,
		"ok": _ok,
		"error_code": int(_error_code),
		"read_result": _read_result.to_dict() if _read_result != null else {},
	}


# --- 框架内部方法 ---

## 由 Storage Utility 写入唯一终态。
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
## @param ok: 请求是否成功。
## [br]
## @param error_code: 请求 Error 码。
## [br]
## @param read_result: 可选读取结果。
## [br]
## @return 首次配置成功返回 true。
func configure_for_framework(
	request_id: int,
	operation: StringName,
	file_name: String,
	ok: bool,
	error_code: Error,
	read_result: GFStorageReadResult = null
) -> bool:
	if _request_id != 0 or request_id <= 0:
		return false
	_request_id = request_id
	_operation = operation
	_file_name = file_name
	_ok = ok
	_error_code = error_code
	_read_result = read_result.duplicate_result() if read_result != null else null
	return true
