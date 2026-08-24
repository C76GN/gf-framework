## GFStorageAsyncCallerResult: 单个 Storage consumer 的不可变 caller 终态。
##
## caller 终态与 `GFStorageAsyncOperation.completed` 表示的物理终态彼此独立。已接纳
## save/delete/reset 在 caller 提前离开时返回 `OUTCOME_UNKNOWN`，不会把“停止观察”伪装成
## 磁盘工作已取消；晚到物理结果仍由原 Operation 恰好结算一次。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFStorageAsyncCallerResult
extends RefCounted


# --- 枚举 ---

## caller 观察的闭合终态分类。
## [br]
## @api public
## [br]
## @since unreleased
enum Status {
	## caller 获得了同一请求的确定物理终态。
	PHYSICAL_SETTLED,
	## caller 已安全停止观察，且不会声称存在持久化副作用的不确定性。
	CANCELLED,
	## caller 已停止观察，但 save/delete/reset 的持久化结果仍未知。
	OUTCOME_UNKNOWN,
}

## caller 终态的稳定来源分类。
## [br]
## @api public
## [br]
## @since unreleased
enum EndKind {
	## 物理工作先结算。
	PHYSICAL_SETTLEMENT,
	## 调用方显式调用 `cancel_observation()`。
	EXPLICIT_CANCEL,
	## 绑定的 `GFCancellationToken` 首次请求取消。
	TOKEN_CANCELLED,
	## 单调 caller deadline 到期。
	DEADLINE_EXPIRED,
	## 弱 owner 已经释放。
	OWNER_RELEASED,
	## Utility dispose 在 worker 接纳前终止了排队请求。
	UTILITY_DISPOSED,
}


# --- 常量 ---

const _MAX_REASON_CHARACTERS: int = 128
const _OPERATION_SAVE: StringName = &"save"
const _OPERATION_LOAD: StringName = &"load"
const _OPERATION_DELETE: StringName = &"delete"
const _OPERATION_RESET: StringName = &"reset"


# --- 私有变量 ---

var _consumer_id: int = 0
var _request_id: int = 0
var _operation: StringName = &""
var _file_name: String = ""
var _status: Status = Status.CANCELLED
var _end_kind: EndKind = EndKind.PHYSICAL_SETTLEMENT
var _reason: StringName = &""
var _completed_at_msec: int = 0
var _error_code: Error = ERR_UNCONFIGURED
var _physical_result: GFStorageAsyncResult = null


# --- 公共方法 ---

## 获取当前 consumer 的 Utility 内唯一 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的当前 consumer ID；尚未配置时返回 0。
func get_consumer_id() -> int:
	return _consumer_id


## 获取物理请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的物理请求 ID；尚未配置时返回 0。
func get_request_id() -> int:
	return _request_id


## 获取请求类型。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `save`、`load`、`delete` 或 `reset`；尚未配置时返回空值。
func get_operation() -> StringName:
	return _operation


## 获取 portable logical 文件名。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已验证的 portable logical identity；校验前失败时可能为空。
func get_file_name() -> String:
	return _file_name


## 获取 caller 终态分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前 caller 终态分类。
func get_status() -> Status:
	return _status


## 获取 caller 结束来源分类。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前 caller 终态的稳定来源分类。
func get_end_kind() -> EndKind:
	return _end_kind


## 获取最长 128 字符的稳定原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已规范化且最长 128 字符的稳定原因。
func get_reason() -> StringName:
	return _reason


## 获取 caller 终态的单调毫秒时间。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return caller 终态写入时的非负单调毫秒值。
func get_completed_at_msec() -> int:
	return _completed_at_msec


## 获取 caller Error 码。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return caller 终态对应的 Godot `Error`。
func get_error_code() -> Error:
	return _error_code


## 返回 caller 是否获得了成功的物理领域结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return caller 获得成功物理领域结果时返回 true。
func is_successful() -> bool:
	return (
		_status == Status.PHYSICAL_SETTLED
		and _physical_result != null
		and _physical_result.is_successful()
	)


## 返回 caller 是否因潜在持久化副作用进入未知结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return caller 已离开但 save/delete/reset 物理结果未知时返回 true。
func is_outcome_unknown() -> bool:
	return _status == Status.OUTCOME_UNKNOWN


## 获取 caller 已知的物理终态副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `PHYSICAL_SETTLED` 时返回结果；其他 caller 终态返回 null。
func get_physical_result() -> GFStorageAsyncResult:
	return _physical_result.duplicate_result() if _physical_result != null else null


## 创建隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前不可变 caller 终态的隔离副本。
func duplicate_result() -> GFStorageAsyncCallerResult:
	var copy: GFStorageAsyncCallerResult = GFStorageAsyncCallerResult.new()
	var _configured: bool = copy.configure_for_framework(
		_consumer_id,
		_request_id,
		_operation,
		_file_name,
		_status,
		_end_kind,
		_reason,
		_completed_at_msec,
		_error_code,
		_physical_result
	)
	return copy


## 转换为可报告字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前 caller 终态的隔离字典表示。
## [br]
## @schema return: Exact Dictionary with consumer_id: int, request_id: int, operation: StringName, file_name: String, status: int enum, end_kind: int enum, reason: StringName, completed_at_msec: int, error_code: int, and physical_result: Dictionary fields.
func to_dict() -> Dictionary:
	return {
		"consumer_id": _consumer_id,
		"request_id": _request_id,
		"operation": _operation,
		"file_name": _file_name,
		"status": int(_status),
		"end_kind": int(_end_kind),
		"reason": _reason,
		"completed_at_msec": _completed_at_msec,
		"error_code": int(_error_code),
		"physical_result": (
			_physical_result.to_dict() if _physical_result != null else {}
		),
	}


# --- 框架内部方法 ---

## 由 Storage Operation 写入唯一 caller 终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
## [br]
## @param consumer_id: Utility 内唯一且大于零的 consumer ID。
## [br]
## @param request_id: 对应物理请求的大于零 ID。
## [br]
## @param operation: `save`、`load`、`delete` 或 `reset`。
## [br]
## @param file_name: 已验证的 portable logical identity；校验前失败时允许为空。
## [br]
## @param status: caller 闭合终态分类。
## [br]
## @param end_kind: caller 终态的稳定来源分类。
## [br]
## @param reason: 将被规范化到最长 128 字符的稳定原因。
## [br]
## @param completed_at_msec: 非负单调完成时间。
## [br]
## @param error_code: 必须与 status 及可选物理结果闭合匹配的 Error。
## [br]
## @param physical_result: `PHYSICAL_SETTLED` 必需的同身份物理结果；其他状态必须为 null。
## [br]
## @return 首次写入闭合 caller 终态时返回 true。
func configure_for_framework(
	consumer_id: int,
	request_id: int,
	operation: StringName,
	file_name: String,
	status: Status,
	end_kind: EndKind,
	reason: StringName,
	completed_at_msec: int,
	error_code: Error,
	physical_result: GFStorageAsyncResult = null
) -> bool:
	if _consumer_id != 0 or consumer_id <= 0 or request_id <= 0 or completed_at_msec < 0:
		return false
	if operation not in [
		_OPERATION_SAVE,
		_OPERATION_LOAD,
		_OPERATION_DELETE,
		_OPERATION_RESET,
	]:
		return false
	if not Status.values().has(int(status)) or not EndKind.values().has(int(end_kind)):
		return false
	if status == Status.PHYSICAL_SETTLED:
		if physical_result == null or not _matches_physical_result(
			physical_result,
			request_id,
			operation,
			file_name,
			error_code
		):
			return false
		if (
			physical_result.get_settlement_kind()
				== GFStorageAsyncResult.SettlementKind.DOMAIN_RESULT
			and end_kind != EndKind.PHYSICAL_SETTLEMENT
		):
			return false
		if (
			physical_result.get_settlement_kind()
				== GFStorageAsyncResult.SettlementKind.CANCELLED
			and end_kind == EndKind.PHYSICAL_SETTLEMENT
		):
			return false
	elif physical_result != null or end_kind == EndKind.PHYSICAL_SETTLEMENT:
		return false
	elif status == Status.CANCELLED:
		if operation != _OPERATION_LOAD or error_code != ERR_SKIP:
			return false
	elif status == Status.OUTCOME_UNKNOWN:
		if (
			operation not in [_OPERATION_SAVE, _OPERATION_DELETE, _OPERATION_RESET]
			or error_code != ERR_BUSY
		):
			return false

	_consumer_id = consumer_id
	_request_id = request_id
	_operation = operation
	_file_name = file_name
	_status = status
	_end_kind = end_kind
	_reason = _normalize_reason(reason, end_kind)
	_completed_at_msec = completed_at_msec
	_error_code = error_code
	_physical_result = physical_result.duplicate_result() if physical_result != null else null
	return true


# --- 私有/辅助方法 ---

static func _matches_physical_result(
	physical_result: GFStorageAsyncResult,
	request_id: int,
	operation: StringName,
	file_name: String,
	error_code: Error
) -> bool:
	return (
		physical_result.get_request_id() == request_id
		and physical_result.get_operation() == operation
		and physical_result.get_file_name() == file_name
		and physical_result.get_error_code() == error_code
	)


static func _normalize_reason(reason: StringName, end_kind: EndKind) -> StringName:
	var reason_text: String = String(reason)
	if reason_text.is_empty():
		reason_text = _default_reason(end_kind)
	if reason_text.length() > _MAX_REASON_CHARACTERS:
		reason_text = reason_text.left(_MAX_REASON_CHARACTERS)
	return StringName(reason_text)


static func _default_reason(end_kind: EndKind) -> String:
	match end_kind:
		EndKind.PHYSICAL_SETTLEMENT:
			return "physical_settlement"
		EndKind.EXPLICIT_CANCEL:
			return "cancelled"
		EndKind.TOKEN_CANCELLED:
			return "token_cancelled"
		EndKind.DEADLINE_EXPIRED:
			return "deadline_expired"
		EndKind.OWNER_RELEASED:
			return "owner_released"
		EndKind.UTILITY_DISPOSED:
			return "utility_disposed"
	return "caller_completed"
