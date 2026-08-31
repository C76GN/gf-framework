## GFStorageAsyncResult: 单次异步存储请求的不可变终态。
##
## 结果通过请求 ID 与具体句柄绑定；读取结果保留 `GFStorageReadResult` 的类型化
## 失败分类；写入结果额外暴露稳定写入失败分类与隔离的 payload 预检报告；
## 删除与 reset 结果携带有界、路径无关的 family 成员终态。
## 未被 worker 接纳即取消的请求使用独立 `SettlementKind.CANCELLED` 分支，不会伪造
## save/load/delete/reset 的领域失败结果。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 10.0.0
class_name GFStorageAsyncResult
extends RefCounted


# --- 枚举 ---

## 物理终态的闭合判别种类。
## [br]
## @api public
## [br]
## @since 11.0.0
enum SettlementKind {
	## 存在对应 save/load/delete/reset 类型化领域结果；也包含接纳前校验或启动失败。
	DOMAIN_RESULT,
	## 请求在 worker 接纳前被取消，没有执行领域物理工作。
	CANCELLED,
}

## 异步写入失败的稳定分类。
## [br]
## @api public
## [br]
## @since 11.0.0
enum WriteFailureKind {
	## 写入成功，或当前结果不是写入请求。
	NONE,
	## 文件名、transfer 状态或冻结绑定无效。
	INVALID_REQUEST,
	## payload 不是 Storage worker 可安全处理的纯 Variant 图。
	PAYLOAD_INVALID,
	## worker 编码未能生成有效 bytes。
	ENCODE_FAILED,
	## threaded executor worker 未能启动。
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
var _settlement_kind: SettlementKind = SettlementKind.DOMAIN_RESULT
var _ok: bool = false
var _error_code: Error = FAILED
var _read_result: GFStorageReadResult = null
var _delete_result: GFStorageDeleteResult = null
var _reset_result: GFStorageFamilyResetResult = null
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


## 获取物理终态的判别种类。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `DOMAIN_RESULT` 或接纳前 `CANCELLED`。
func get_settlement_kind() -> SettlementKind:
	return _settlement_kind


## 返回请求是否在 worker 接纳前被取消。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 请求在 worker 接纳前被取消时返回 true。
func is_cancelled() -> bool:
	return _settlement_kind == SettlementKind.CANCELLED


## 检查请求是否成功。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前请求的类型化领域结果成功时返回 true。
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
## @return `DOMAIN_RESULT` load 请求的结果；save/delete/reset 或 `CANCELLED` 返回 null。
func get_read_result() -> GFStorageReadResult:
	return _read_result.duplicate_result() if _read_result != null else null


## 获取删除结果副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `DOMAIN_RESULT` delete 请求的结果；save/load/reset 或 `CANCELLED` 返回 null。
func get_delete_result() -> GFStorageDeleteResult:
	return _delete_result.duplicate_result() if _delete_result != null else null


## 获取 family reset/recreate 结果副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return DOMAIN_RESULT reset 请求的结果；save/load/delete 或 CANCELLED 返回 null。
func get_reset_result() -> GFStorageFamilyResetResult:
	return _reset_result.duplicate_result() if _reset_result != null else null


## 获取异步写入失败的稳定分类。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `WriteFailureKind` 枚举值；成功、load/delete/reset 或 `CANCELLED` 为 NONE。
func get_write_failure_kind() -> WriteFailureKind:
	return _write_failure_kind


## 获取 worker payload 预检报告副本。
## [br]
## @api public
## [br]
## @since 11.0.0
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
		_write_validation_report,
		_delete_result,
		_settlement_kind,
		_reset_result
	)
	return copy


## 转换为可报告字典。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 包含请求身份、终态、领域结果和写入诊断的字典。
## [br]
## @schema return: Exact Dictionary with request_id: int, operation: StringName, file_name: String, settlement_kind: int enum, ok: bool, error_code: int, read_result: Dictionary, write_failure_kind: int enum, write_validation_report: Dictionary, delete_result: Dictionary, and reset_result: Dictionary fields.
func to_dict() -> Dictionary:
	return {
		"request_id": _request_id,
		"operation": _operation,
		"file_name": _file_name,
		"settlement_kind": int(_settlement_kind),
		"ok": _ok,
		"error_code": int(_error_code),
		"read_result": _read_result.to_dict() if _read_result != null else {},
		"write_failure_kind": int(_write_failure_kind),
		"write_validation_report": _write_validation_report.duplicate(true),
		"delete_result": _delete_result.to_dict() if _delete_result != null else {},
		"reset_result": _reset_result.to_dict() if _reset_result != null else {},
	}


# --- 框架内部方法 ---

## 由 Storage Utility 写入唯一终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
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
## @param delete_result: 可选删除结果。
## [br]
## @param settlement_kind: 领域结果或 worker 接纳前取消的物理终态判别。
## [br]
## @param reset_result: 可选 family reset/recreate 结果。
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
	write_validation_report: Dictionary = {},
	delete_result: GFStorageDeleteResult = null,
	settlement_kind: SettlementKind = SettlementKind.DOMAIN_RESULT,
	reset_result: GFStorageFamilyResetResult = null
) -> bool:
	if _request_id != 0 or request_id <= 0:
		return false
	if not _is_valid_configuration(
		operation,
		ok,
		error_code,
		read_result,
		write_failure_kind,
		write_validation_report,
		delete_result,
		settlement_kind,
		reset_result
	):
		return false

	_request_id = request_id
	_operation = operation
	_file_name = file_name
	_settlement_kind = settlement_kind
	_ok = ok
	_error_code = error_code
	_read_result = read_result.duplicate_result() if read_result != null else null
	_delete_result = delete_result.duplicate_result() if delete_result != null else null
	_reset_result = reset_result.duplicate_result() if reset_result != null else null
	_write_failure_kind = write_failure_kind
	_write_validation_report = write_validation_report.duplicate(true)
	return true


## 配置一个 worker 接纳前取消的物理终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param request_id: Utility 内唯一且大于零的请求 ID。
## [br]
## @param operation: `save`、`load`、`delete` 或 `reset`。
## [br]
## @param file_name: 当前请求的 portable logical identity；校验前失败时允许为空。
## [br]
## @return 身份合法且对象尚未配置时返回 true。
func configure_cancelled_for_framework(
	request_id: int,
	operation: StringName,
	file_name: String
) -> bool:
	return configure_for_framework(
		request_id,
		operation,
		file_name,
		false,
		ERR_SKIP,
		null,
		WriteFailureKind.NONE,
		{},
		null,
		SettlementKind.CANCELLED,
		null
	)


# --- 私有/辅助方法 ---

static func _is_valid_configuration(
	operation: StringName,
	ok: bool,
	error_code: Error,
	read_result: GFStorageReadResult,
	write_failure_kind: WriteFailureKind,
	write_validation_report: Dictionary,
	delete_result: GFStorageDeleteResult,
	settlement_kind: SettlementKind,
	reset_result: GFStorageFamilyResetResult
) -> bool:
	if not WriteFailureKind.values().has(int(write_failure_kind)):
		return false
	if not SettlementKind.values().has(int(settlement_kind)):
		return false
	if operation not in [
		GFStorageAsyncOperation.OPERATION_SAVE,
		GFStorageAsyncOperation.OPERATION_LOAD,
		GFStorageAsyncOperation.OPERATION_DELETE,
		GFStorageAsyncOperation.OPERATION_RESET,
	]:
		return false
	if settlement_kind == SettlementKind.CANCELLED:
		return (
			not ok
			and error_code == ERR_SKIP
			and read_result == null
			and delete_result == null
			and reset_result == null
			and write_failure_kind == WriteFailureKind.NONE
			and write_validation_report.is_empty()
		)
	if ok != (error_code == OK):
		return false

	match operation:
		GFStorageAsyncOperation.OPERATION_SAVE:
			if read_result != null or delete_result != null or reset_result != null:
				return false
			return (
				write_failure_kind == WriteFailureKind.NONE
				if ok
				else write_failure_kind != WriteFailureKind.NONE
			)
		GFStorageAsyncOperation.OPERATION_LOAD:
			return (
				read_result != null
				and delete_result == null
				and reset_result == null
				and write_failure_kind == WriteFailureKind.NONE
				and write_validation_report.is_empty()
				and read_result.ok == ok
				and read_result.error_code == error_code
			)
		GFStorageAsyncOperation.OPERATION_DELETE:
			return (
				read_result == null
				and delete_result != null
				and reset_result == null
				and delete_result.is_configured_for_framework()
				and write_failure_kind == WriteFailureKind.NONE
				and write_validation_report.is_empty()
				and delete_result.is_successful() == ok
				and delete_result.get_error_code() == error_code
			)
		GFStorageAsyncOperation.OPERATION_RESET:
			return (
				read_result == null
				and delete_result == null
				and reset_result != null
				and reset_result.is_configured_for_framework()
				and write_failure_kind == WriteFailureKind.NONE
				and write_validation_report.is_empty()
				and reset_result.is_successful() == ok
				and reset_result.get_error_code() == error_code
			)
	return false
