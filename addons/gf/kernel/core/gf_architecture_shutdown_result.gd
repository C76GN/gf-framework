## GFArchitectureShutdownResult: 架构关闭流程的不可变终态快照。
##
## 结果显式区分正常完成、失败、取消、超时、强制释放和重复释放，并以有界、
## JSON-safe 的模块条目保留关闭证据。所有集合在写入和读取边界都会重新复制，
## 调用方不能借由返回值修改已提交终态。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
## [br]
## @layer kernel/core
class_name GFArchitectureShutdownResult
extends RefCounted


# --- 枚举 ---

## 架构关闭终态。
## [br]
## @api public
## [br]
## @since 11.0.0
enum Status {
	## 所有关闭阶段正常完成。
	SUCCEEDED,
	## 至少一个关闭阶段失败。
	FAILED,
	## 调用方取消了关闭流程。
	CANCELLED,
	## 关闭流程超过了时间预算。
	TIMED_OUT,
	## 框架跳过未完成的静默工作并执行了强制释放。
	FORCED,
	## 架构在本次请求前已经释放。
	ALREADY_DISPOSED,
}


# --- 常量 ---

const _MAX_MODULE_ENTRIES: int = 256
const _MAX_IDENTIFIER_LENGTH: int = 128
const _MAX_SCRIPT_LENGTH: int = 512
const _MAX_REASON_LENGTH: int = 1024
const _MAX_ERROR_LENGTH: int = 2048


# --- 私有变量 ---

var _status: Status = Status.FAILED
var _started_at_msec: int = 0
var _completed_at_msec: int = 0
var _module_results: Array[Dictionary] = []
var _unfinished_modules: Array[Dictionary] = []
var _duplicate_request_count: int = 0
var _error_code: Error = FAILED
var _error: String = ""
var _cancel_reason: String = ""


# --- 公共方法 ---

## 创建一个规范化的架构关闭结果。
##
## 模块条目最多各保留 256 项，并且只保留 kind、script、instance_id、status、
## reason 和 duration_msec 字段。字符串和非负 duration 会被限制到固定预算；
## instance_id 保留 Godot 返回的有符号 int 身份值。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param status: `Status` 终态。
## [br]
## @param started_at_msec: 单调开始时间；负值归零。
## [br]
## @param completed_at_msec: 单调完成时间；早于开始时间时收敛到开始时间。
## [br]
## @param module_results: 已进入终态的模块关闭结果。
## [br]
## @param unfinished_modules: 强制释放时仍未完成的模块快照。
## [br]
## @param duplicate_request_count: 复用同一关闭流程的并发重复请求数量。
## [br]
## @param error_code: 关闭错误码；成功终态强制归一为 OK。
## [br]
## @param error: 稳定失败说明；最多保留 2048 个字符。
## [br]
## @param cancel_reason: 取消原因；仅取消终态保留，最多 1024 个字符。
## [br]
## @return 新的不可变结果。
## [br]
## @schema module_results: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
## [br]
## @schema unfinished_modules: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
static func create(
	status: Status,
	started_at_msec: int,
	completed_at_msec: int,
	module_results: Array[Dictionary] = [],
	unfinished_modules: Array[Dictionary] = [],
	duplicate_request_count: int = 0,
	error_code: Error = OK,
	error: String = "",
	cancel_reason: String = ""
) -> GFArchitectureShutdownResult:
	var result: GFArchitectureShutdownResult = GFArchitectureShutdownResult.new()
	result._status = _normalize_status(status)
	result._started_at_msec = maxi(started_at_msec, 0)
	result._completed_at_msec = maxi(completed_at_msec, result._started_at_msec)
	result._module_results = _normalize_module_entries(module_results)
	result._unfinished_modules = _normalize_module_entries(unfinished_modules)
	result._duplicate_request_count = maxi(duplicate_request_count, 0)
	result._error_code = (
		OK
		if result.is_successful()
		else error_code
	)
	result._error = error.left(_MAX_ERROR_LENGTH)
	result._cancel_reason = (
		cancel_reason.left(_MAX_REASON_LENGTH)
		if result._status == Status.CANCELLED and not cancel_reason.is_empty()
		else ("cancelled" if result._status == Status.CANCELLED else "")
	)
	return result


## 创建正常完成结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param module_results: 已完成的模块关闭结果。
## [br]
## @param started_at_msec: 单调开始时间。
## [br]
## @param completed_at_msec: 单调完成时间。
## [br]
## @param duplicate_request_count: 并发重复请求数量。
## [br]
## @return 新的成功结果。
## [br]
## @schema module_results: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
static func succeeded(
	module_results: Array[Dictionary] = [],
	started_at_msec: int = 0,
	completed_at_msec: int = 0,
	duplicate_request_count: int = 0
) -> GFArchitectureShutdownResult:
	return create(
		Status.SUCCEEDED,
		started_at_msec,
		completed_at_msec,
		module_results,
		[],
		duplicate_request_count
	)


## 创建失败结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param error_code: 关闭错误码。
## [br]
## @param error: 稳定失败说明。
## [br]
## @param module_results: 已完成的模块关闭结果。
## [br]
## @param unfinished_modules: 尚未完成的模块快照。
## [br]
## @param started_at_msec: 单调开始时间。
## [br]
## @param completed_at_msec: 单调完成时间。
## [br]
## @param duplicate_request_count: 并发重复请求数量。
## [br]
## @return 新的失败结果。
## [br]
## @schema module_results: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
## [br]
## @schema unfinished_modules: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
static func failed(
	error_code: Error,
	error: String,
	module_results: Array[Dictionary] = [],
	unfinished_modules: Array[Dictionary] = [],
	started_at_msec: int = 0,
	completed_at_msec: int = 0,
	duplicate_request_count: int = 0
) -> GFArchitectureShutdownResult:
	return create(
		Status.FAILED,
		started_at_msec,
		completed_at_msec,
		module_results,
		unfinished_modules,
		duplicate_request_count,
		error_code,
		error
	)


## 创建取消结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param reason: 稳定取消原因。
## [br]
## @param module_results: 已完成的模块关闭结果。
## [br]
## @param unfinished_modules: 尚未完成的模块快照。
## [br]
## @param started_at_msec: 单调开始时间。
## [br]
## @param completed_at_msec: 单调完成时间。
## [br]
## @param duplicate_request_count: 并发重复请求数量。
## [br]
## @return 新的取消结果。
## [br]
## @schema module_results: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
## [br]
## @schema unfinished_modules: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
static func cancelled(
	reason: String = "cancelled",
	module_results: Array[Dictionary] = [],
	unfinished_modules: Array[Dictionary] = [],
	started_at_msec: int = 0,
	completed_at_msec: int = 0,
	duplicate_request_count: int = 0
) -> GFArchitectureShutdownResult:
	return create(
		Status.CANCELLED,
		started_at_msec,
		completed_at_msec,
		module_results,
		unfinished_modules,
		duplicate_request_count,
		ERR_SKIP,
		"",
		reason
	)


## 创建超时结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param error: 稳定超时说明。
## [br]
## @param module_results: 已完成的模块关闭结果。
## [br]
## @param unfinished_modules: 超时时尚未完成的模块快照。
## [br]
## @param started_at_msec: 单调开始时间。
## [br]
## @param completed_at_msec: 单调完成时间。
## [br]
## @param duplicate_request_count: 并发重复请求数量。
## [br]
## @return 新的超时结果。
## [br]
## @schema module_results: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
## [br]
## @schema unfinished_modules: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
static func timed_out(
	error: String,
	module_results: Array[Dictionary] = [],
	unfinished_modules: Array[Dictionary] = [],
	started_at_msec: int = 0,
	completed_at_msec: int = 0,
	duplicate_request_count: int = 0
) -> GFArchitectureShutdownResult:
	return create(
		Status.TIMED_OUT,
		started_at_msec,
		completed_at_msec,
		module_results,
		unfinished_modules,
		duplicate_request_count,
		ERR_TIMEOUT,
		error
	)


## 创建强制释放结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param error: 强制释放原因。
## [br]
## @param module_results: 已完成的模块关闭结果。
## [br]
## @param unfinished_modules: 被强制跳过的模块快照。
## [br]
## @param started_at_msec: 单调开始时间。
## [br]
## @param completed_at_msec: 单调完成时间。
## [br]
## @param duplicate_request_count: 并发重复请求数量。
## [br]
## @return 新的强制释放结果。
## [br]
## @schema module_results: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
## [br]
## @schema unfinished_modules: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
static func forced(
	error: String,
	module_results: Array[Dictionary] = [],
	unfinished_modules: Array[Dictionary] = [],
	started_at_msec: int = 0,
	completed_at_msec: int = 0,
	duplicate_request_count: int = 0
) -> GFArchitectureShutdownResult:
	return create(
		Status.FORCED,
		started_at_msec,
		completed_at_msec,
		module_results,
		unfinished_modules,
		duplicate_request_count,
		FAILED,
		error
	)


## 创建已释放幂等结果。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param started_at_msec: 单调开始时间。
## [br]
## @param completed_at_msec: 单调完成时间。
## [br]
## @param duplicate_request_count: 并发重复请求数量。
## [br]
## @return 新的已释放结果。
static func already_disposed(
	started_at_msec: int = 0,
	completed_at_msec: int = 0,
	duplicate_request_count: int = 0
) -> GFArchitectureShutdownResult:
	return create(
		Status.ALREADY_DISPOSED,
		started_at_msec,
		completed_at_msec,
		[],
		[],
		duplicate_request_count
	)


## 检查关闭是否以正常或幂等成功结束。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 正常完成或此前已释放时返回 true。
func is_successful() -> bool:
	return _status == Status.SUCCEEDED or _status == Status.ALREADY_DISPOSED


## 获取关闭终态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return `Status` 终态。
func get_status() -> Status:
	return _status


## 获取关闭终态名称。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 小写稳定状态名称。
func get_status_name() -> StringName:
	return _status_name(_status)


## 获取关闭开始时间。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 非负单调毫秒时间。
func get_started_at_msec() -> int:
	return _started_at_msec


## 获取关闭完成时间。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 不早于开始时间的单调毫秒时间。
func get_completed_at_msec() -> int:
	return _completed_at_msec


## 获取关闭耗时。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 非负单调毫秒耗时。
func get_duration_msec() -> int:
	return maxi(_completed_at_msec - _started_at_msec, 0)


## 获取已完成模块结果的隔离副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 最多 256 个规范化模块条目。
## [br]
## @schema return: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
func get_module_results() -> Array[Dictionary]:
	return _duplicate_module_entries(_module_results)


## 获取未完成模块快照的隔离副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 最多 256 个规范化模块条目。
## [br]
## @schema return: Array of Dictionaries with kind, script, instance_id, status, reason, and duration_msec.
func get_unfinished_modules() -> Array[Dictionary]:
	return _duplicate_module_entries(_unfinished_modules)


## 获取复用同一关闭流程的重复请求数量。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 非负重复请求数量。
func get_duplicate_request_count() -> int:
	return _duplicate_request_count


## 获取关闭错误码。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 成功终态为 OK。
func get_error_code() -> Error:
	return _error_code


## 获取稳定失败说明。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 最多 2048 个字符的失败说明。
func get_error() -> String:
	return _error


## 获取取消原因。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 最多 1024 个字符的取消原因；非取消终态为空。
func get_cancel_reason() -> String:
	return _cancel_reason


## 创建隔离结果副本。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 新的不可变结果对象。
func duplicate_result() -> GFArchitectureShutdownResult:
	return create(
		_status,
		_started_at_msec,
		_completed_at_msec,
		_module_results,
		_unfinished_modules,
		_duplicate_request_count,
		_error_code,
		_error,
		_cancel_reason
	)


## 转换为可报告字典。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 关闭终态、时间、模块结果和错误证据的隔离快照。
## [br]
## @schema return: Dictionary with ok, status, status_name, started_at_msec, completed_at_msec, duration_msec, module_results, unfinished_modules, duplicate_request_count, error_code, error, and cancel_reason.
func to_dict() -> Dictionary:
	return {
		"ok": is_successful(),
		"status": _status,
		"status_name": _status_name(_status),
		"started_at_msec": _started_at_msec,
		"completed_at_msec": _completed_at_msec,
		"duration_msec": get_duration_msec(),
		"module_results": _duplicate_module_entries(_module_results),
		"unfinished_modules": _duplicate_module_entries(_unfinished_modules),
		"duplicate_request_count": _duplicate_request_count,
		"error_code": int(_error_code),
		"error": _error,
		"cancel_reason": _cancel_reason,
	}


# --- 私有/辅助方法 ---

static func _normalize_status(status: Status) -> Status:
	if status in [
		Status.SUCCEEDED,
		Status.FAILED,
		Status.CANCELLED,
		Status.TIMED_OUT,
		Status.FORCED,
		Status.ALREADY_DISPOSED,
	]:
		return status
	return Status.FAILED


static func _status_name(status: Status) -> StringName:
	match status:
		Status.SUCCEEDED:
			return &"succeeded"
		Status.FAILED:
			return &"failed"
		Status.CANCELLED:
			return &"cancelled"
		Status.TIMED_OUT:
			return &"timed_out"
		Status.FORCED:
			return &"forced"
		Status.ALREADY_DISPOSED:
			return &"already_disposed"
		_:
			return &"failed"


static func _normalize_module_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var normalized_entries: Array[Dictionary] = []
	var entry_count: int = mini(entries.size(), _MAX_MODULE_ENTRIES)
	var _resize_error: Error = normalized_entries.resize(entry_count) as Error
	for index: int in range(entry_count):
		var entry: Dictionary = entries[index]
		var normalized_entry: Dictionary = {
			"kind": _get_bounded_string_name(entry, "kind", _MAX_IDENTIFIER_LENGTH),
			"script": _get_bounded_string(entry, "script", _MAX_SCRIPT_LENGTH),
			"instance_id": _get_int(entry, "instance_id"),
			"status": _get_bounded_string_name(entry, "status", _MAX_IDENTIFIER_LENGTH),
			"reason": _get_bounded_string(entry, "reason", _MAX_REASON_LENGTH),
			"duration_msec": _get_non_negative_int(entry, "duration_msec"),
		}
		normalized_entries[index] = normalized_entry
	return normalized_entries


static func _duplicate_module_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var duplicated_entries: Array[Dictionary] = []
	var _resize_error: Error = duplicated_entries.resize(entries.size()) as Error
	for index: int in range(entries.size()):
		duplicated_entries[index] = entries[index].duplicate(true)
	return duplicated_entries


static func _get_bounded_string(
	entry: Dictionary,
	key: String,
	max_length: int
) -> String:
	var value: Variant = entry.get(key)
	if value is String:
		var text: String = value
		return text.left(max_length)
	if value is StringName:
		var text_name: StringName = value
		return String(text_name).left(max_length)
	return ""


static func _get_bounded_string_name(
	entry: Dictionary,
	key: String,
	max_length: int
) -> StringName:
	return StringName(_get_bounded_string(entry, key, max_length))


static func _get_non_negative_int(entry: Dictionary, key: String) -> int:
	var value: Variant = entry.get(key)
	if value is int:
		var int_value: int = value
		return maxi(int_value, 0)
	return 0


static func _get_int(entry: Dictionary, key: String) -> int:
	var value: Variant = entry.get(key)
	if value is int:
		return value
	return 0
