## GFStorageAsyncResult: 单次异步存储请求的不可变终态。
##
## 结果通过请求 ID 与具体句柄绑定；读取结果保留 `GFStorageReadResult` 的类型化
## 失败分类；写入结果额外暴露稳定写入失败分类与隔离的 payload 预检报告。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 10.0.0
class_name GFStorageAsyncResult
extends RefCounted


# --- 枚举 ---

## 异步写入失败的稳定分类。
## [br]
## @api public
## [br]
## @since unreleased
enum WriteFailureKind {
	## 写入成功，或当前结果不是写入请求。
	NONE,
	## 文件名、transfer 状态或冻结绑定无效。
	INVALID_REQUEST,
	## payload 不是 Storage worker 可安全处理的纯 Variant 图。
	PAYLOAD_INVALID,
	## worker 编码未能生成有效 bytes。
	ENCODE_FAILED,
	## worker 线程未能启动。
	THREAD_START_FAILED,
	## Utility dispose 等生命周期边界使任务不可执行。
	UNAVAILABLE,
	## 目录、临时文件或事务提交 I/O 失败。
	IO_FAILED,
}


# --- 私有变量 ---

var _request_id: int = 0
var _operation: StringName = &""
var _file_name: String = ""
var _ok: bool = false
var _error_code: Error = FAILED
var _read_result: GFStorageReadResult = null
var _write_failure_kind: WriteFailureKind = WriteFailureKind.NONE
var _write_validation_report: Dictionary = {}


# --- 公共方法 ---

## 获取 Storage Utility 分配的请求 ID。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 大于零的 Utility 内唯一请求 ID。
func get_request_id() -> int:
	return _request_id


## 获取请求类型。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return `GFStorageAsyncOperation.OPERATION_*` 常量之一。
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


## 检查请求是否成功。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 写入错误码为 OK，或读取结果成功时返回 true。
func is_successful() -> bool:
	return _ok


## 获取请求 Error 码。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 成功时为 OK。
func get_error_code() -> Error:
	return _error_code


## 获取读取结果副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return load 请求的结果；save 请求返回 null。
func get_read_result() -> GFStorageReadResult:
	return _read_result.duplicate_result() if _read_result != null else null


## 获取异步写入失败的稳定分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `WriteFailureKind` 枚举值；成功或 load 请求为 NONE。
func get_write_failure_kind() -> WriteFailureKind:
	return _write_failure_kind


## 获取 worker payload 预检报告副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 包含 ok、failure_kind、failure_path、path_segments、variant_type、visited_values 和 visited_bytes 的隔离字典；未执行预检时为空。
## [br]
## @schema return: Dictionary with ok, failure_kind, failure_path, path_segments, variant_type, variant_type_name, visited_values, and visited_bytes fields; path segments contain only structural indexes, never payload keys, values, or correlatable key digests.
func get_write_validation_report() -> Dictionary:
	return _write_validation_report.duplicate(true)


## 创建隔离结果副本。
## [br]
## @api public
## [br]
## @since 10.0.0
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
		_read_result,
		_write_failure_kind,
		_write_validation_report
	)
	return copy


## 转换为可报告字典。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 包含请求身份、终态、读取摘要和写入诊断的字典。
## [br]
## @schema return: Dictionary with request_id, operation, file_name, ok, error_code, read_result, write_failure_kind, and write_validation_report fields.
func to_dict() -> Dictionary:
	return {
		"request_id": _request_id,
		"operation": _operation,
		"file_name": _file_name,
		"ok": _ok,
		"error_code": int(_error_code),
		"read_result": _read_result.to_dict() if _read_result != null else {},
		"write_failure_kind": int(_write_failure_kind),
		"write_validation_report": _write_validation_report.duplicate(true),
	}


# --- 框架内部方法 ---

## 由 Storage Utility 写入唯一终态。
## [br]
## @api framework_internal
## [br]
## @since 10.0.0
## [br]
## @param request_id: Utility 内唯一请求 ID。
## [br]
## @param operation: 请求类型。
## [br]
## @param file_name: 当前 Storage root 内的规范相对文件名；请求在路径校验前失败时为空。
## [br]
## @param ok: 请求是否成功。
## [br]
## @param error_code: 请求 Error 码。
## [br]
## @param read_result: 可选读取结果。
## [br]
## @param write_failure_kind: 写入失败稳定分类。
## [br]
## @param write_validation_report: worker payload 预检报告。
## [br]
## @schema write_validation_report: Dictionary with isolated payload validation diagnostics.
## [br]
## @return 首次配置成功返回 true。
func configure_for_framework(
	request_id: int,
	operation: StringName,
	file_name: String,
	ok: bool,
	error_code: Error,
	read_result: GFStorageReadResult = null,
	write_failure_kind: WriteFailureKind = WriteFailureKind.NONE,
	write_validation_report: Dictionary = {}
) -> bool:
	if _request_id != 0 or request_id <= 0:
		return false
	_request_id = request_id
	_operation = operation
	_file_name = file_name
	_ok = ok
	_error_code = error_code
	_read_result = read_result.duplicate_result() if read_result != null else null
	_write_failure_kind = WriteFailureKind.NONE
	if not ok and operation == GFStorageAsyncOperation.OPERATION_SAVE:
		_write_failure_kind = _to_write_failure_kind(int(write_failure_kind))
		if _write_failure_kind == WriteFailureKind.NONE:
			_write_failure_kind = WriteFailureKind.IO_FAILED
	_write_validation_report = write_validation_report.duplicate(true)
	return true


# --- 私有/辅助方法 ---

static func _to_write_failure_kind(value: int) -> WriteFailureKind:
	if WriteFailureKind.values().has(value):
		return value as WriteFailureKind
	return WriteFailureKind.IO_FAILED
