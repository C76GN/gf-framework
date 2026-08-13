## GFObjectPoolPrewarmResult: 单次对象池预热请求的不可变终态。
##
## 结果冻结请求身份、容量准入和每个请求单位的唯一 disposition。调用方可以区分
## 完成、容量部分接纳、拒绝、取消、Utility 生命周期终结、输入无效与执行失败。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
## [br]
## @layer standard/utilities/nodes
class_name GFObjectPoolPrewarmResult
extends RefCounted


# --- 枚举 ---

## 预热请求的唯一终态。
## [br]
## @api public
## [br]
## @since unreleased
enum Status {
	## 全部请求单位已经成功创建。
	COMPLETED,
	## 容量只接纳了部分单位，已接纳单位全部成功创建。
	PARTIAL,
	## 有效请求没有可用容量。
	REJECTED,
	## 请求因 caller、token、scope、owner 或 parent 生命周期终结。
	CANCELLED,
	## Object Pool Utility 释放或重新初始化了请求代际。
	DISPOSED,
	## 请求输入不符合契约。
	INVALID,
	## 场景实例化、准备回调或候选提交失败。
	FAILED,
}


# --- 常量 ---

## 全部请求单位已经创建。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_COMPLETED: StringName = &"completed"

## 容量只接纳部分请求单位。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_CAPACITY_LIMITED: StringName = &"capacity_limited"

## 当前没有可接纳容量。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_CAPACITY_UNAVAILABLE: StringName = &"capacity_unavailable"

## caller 显式取消请求。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_CALLER_CANCELLED: StringName = &"caller_cancelled"

## 绑定的 cancellation token 请求取消。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_TOKEN_CANCELLED: StringName = &"token_cancelled"

## 绑定的异步作用域已经正常完成。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_CANCELLATION_SCOPE_COMPLETED: StringName = &"cancellation_scope_completed"

## 请求 owner 已释放或离开场景树。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_OWNER_RELEASED: StringName = &"owner_released"

## 请求 parent 已释放、离树或排队删除。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_PARENT_RELEASED: StringName = &"parent_released"

## Object Pool Utility 已释放。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_UTILITY_DISPOSED: StringName = &"utility_disposed"

## Object Pool Utility 已重新初始化。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_UTILITY_REINITIALIZED: StringName = &"utility_reinitialized"

## PackedScene 无效。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_INVALID_SCENE: StringName = &"invalid_scene"

## 请求数量小于零。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_INVALID_COUNT: StringName = &"invalid_count"

## parent 在接纳时无效或已排队删除。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_INVALID_PARENT: StringName = &"invalid_parent"

## owner 在接纳时无效或 Node owner 不在场景树中。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_INVALID_OWNER: StringName = &"invalid_owner"

## prepare_callback 不是空 Callable 或有效 Callable。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_INVALID_PREPARE_CALLBACK: StringName = &"invalid_prepare_callback"

## PackedScene 无法实例化为有效 Node。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_SCENE_INSTANTIATION_FAILED: StringName = &"scene_instantiation_failed"

## prepare_callback 显式返回非 OK Error。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_PREPARE_CALLBACK_FAILED: StringName = &"prepare_callback_failed"

## prepare_callback 返回值不是合法 Error 整数。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_INVALID_PREPARE_CALLBACK_RESULT: StringName = &"invalid_prepare_callback_result"

## 候选在提交前被重入或生命周期变化失效。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_CANDIDATE_INVALIDATED: StringName = &"candidate_invalidated"

## 框架无法安全归类的内部失败。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_INTERNAL_FAILURE: StringName = &"internal_failure"


# --- 私有变量 ---

var _status: Status = Status.INVALID
var _request_id: int = 0
var _scene_identity: String = ""
var _requested_count: int = 0
var _admitted_count: int = 0
var _created_count: int = 0
var _skipped_count: int = 0
var _cancelled_count: int = 0
var _failed_count: int = 0
var _reason: StringName = &""
var _error_code: Error = ERR_UNCONFIGURED
var _configured: bool = false


# --- 公共方法 ---

## 获取请求终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `Status` 闭合枚举值。
func get_status() -> Status:
	return _status


## 检查请求是否完成了全部或部分容量准入。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `COMPLETED` 或 `PARTIAL` 返回 true。
func is_successful() -> bool:
	return _configured and _status in [Status.COMPLETED, Status.PARTIAL]


## 获取 Utility 内唯一请求 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 大于零的请求 ID；尚未配置时返回 0。
func get_request_id() -> int:
	return _request_id


## 获取请求冻结的场景身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 资源路径或实例 ID 身份。
func get_scene_identity() -> String:
	return _scene_identity


## 获取调用方请求数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非负数量。
func get_requested_count() -> int:
	return _requested_count


## 获取容量准入数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非负且不大于 requested 的数量。
func get_admitted_count() -> int:
	return _admitted_count


## 获取成功提交到池中的数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 成功创建数量。
func get_created_count() -> int:
	return _created_count


## 获取未获容量准入的数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `requested - admitted`。
func get_skipped_count() -> int:
	return _skipped_count


## 获取因取消或生命周期终结而未创建的准入数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 取消数量。
func get_cancelled_count() -> int:
	return _cancelled_count


## 获取因执行失败而未创建的准入数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 失败数量。
func get_failed_count() -> int:
	return _failed_count


## 获取唯一终态原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 与 status/error 对应的 `REASON_*`。
func get_reason() -> StringName:
	return _reason


## 获取终态 Error。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 与 status/reason 对应的 Error。
func get_error_code() -> Error:
	return _error_code


## 创建隔离结果副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 新结果对象。
func duplicate_result() -> GFObjectPoolPrewarmResult:
	var copy: GFObjectPoolPrewarmResult = GFObjectPoolPrewarmResult.new()
	if _configured:
		var _configured_copy: bool = copy.configure_for_framework(
			_status,
			_request_id,
			_scene_identity,
			_requested_count,
			_admitted_count,
			_created_count,
			_skipped_count,
			_cancelled_count,
			_failed_count,
			_reason,
			_error_code
		)
	return copy


## 转换为不含 Object 引用的闭合诊断字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 请求身份、计数与终态。
## [br]
## @schema return: Exact Dictionary with status: int enum, request_id: int, scene_identity: String, requested_count: int, admitted_count: int, created_count: int, skipped_count: int, cancelled_count: int, failed_count: int, reason: StringName, error_code: int, and successful: bool fields.
func to_dict() -> Dictionary:
	return {
		"status": int(_status),
		"request_id": _request_id,
		"scene_identity": _scene_identity,
		"requested_count": _requested_count,
		"admitted_count": _admitted_count,
		"created_count": _created_count,
		"skipped_count": _skipped_count,
		"cancelled_count": _cancelled_count,
		"failed_count": _failed_count,
		"reason": _reason,
		"error_code": int(_error_code),
		"successful": is_successful(),
	}


# --- 框架内部方法 ---

## 由 Object Pool Utility 一次性冻结闭合终态。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/nodes
## [br]
## @since unreleased
## [br]
## @param status: 唯一终态。
## [br]
## @param request_id: Utility 内唯一请求 ID。
## [br]
## @param scene_identity: 冻结的场景身份。
## [br]
## @param requested_count: 非负请求数量。
## [br]
## @param admitted_count: 容量准入数量。
## [br]
## @param created_count: 成功提交数量。
## [br]
## @param skipped_count: 未获容量准入数量。
## [br]
## @param cancelled_count: 取消数量。
## [br]
## @param failed_count: 失败数量。
## [br]
## @param reason: 与 status 对应的原因。
## [br]
## @param error_code: 与 status/reason 对应的 Error。
## [br]
## @return 首次完整配置且联合合法时返回 true。
func configure_for_framework(
	status: Status,
	request_id: int,
	scene_identity: String,
	requested_count: int,
	admitted_count: int,
	created_count: int,
	skipped_count: int,
	cancelled_count: int,
	failed_count: int,
	reason: StringName,
	error_code: Error
) -> bool:
	if (
		_configured
		or request_id <= 0
		or not Status.values().has(int(status))
		or not _counts_are_valid(
			requested_count,
			admitted_count,
			created_count,
			skipped_count,
			cancelled_count,
			failed_count
		)
		or not _terminal_union_is_valid(
			status,
			reason,
			error_code,
			requested_count,
			admitted_count,
			created_count,
			skipped_count,
			cancelled_count,
			failed_count
		)
	):
		return false
	_status = status
	_request_id = request_id
	_scene_identity = scene_identity
	_requested_count = requested_count
	_admitted_count = admitted_count
	_created_count = created_count
	_skipped_count = skipped_count
	_cancelled_count = cancelled_count
	_failed_count = failed_count
	_reason = reason
	_error_code = error_code
	_configured = true
	return true


## 检查结果是否已完整配置。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/nodes
## [br]
## @since unreleased
## [br]
## @return 闭合联合已冻结时返回 true。
func is_configured_for_framework() -> bool:
	return _configured


# --- 私有/辅助方法 ---

static func _counts_are_valid(
	requested_count: int,
	admitted_count: int,
	created_count: int,
	skipped_count: int,
	cancelled_count: int,
	failed_count: int
) -> bool:
	if (
		requested_count < 0
		or admitted_count < 0
		or created_count < 0
		or skipped_count < 0
		or cancelled_count < 0
		or failed_count < 0
	):
		return false
	return (
		requested_count == admitted_count + skipped_count
		and admitted_count == created_count + cancelled_count + failed_count
	)


static func _terminal_union_is_valid(
	status: Status,
	reason: StringName,
	error_code: Error,
	requested_count: int,
	admitted_count: int,
	created_count: int,
	skipped_count: int,
	cancelled_count: int,
	failed_count: int
) -> bool:
	match status:
		Status.COMPLETED:
			return (
				reason == REASON_COMPLETED
				and error_code == OK
				and admitted_count == requested_count
				and created_count == requested_count
				and skipped_count == 0
				and cancelled_count == 0
				and failed_count == 0
			)
		Status.PARTIAL:
			return (
				reason == REASON_CAPACITY_LIMITED
				and error_code == OK
				and admitted_count > 0
				and admitted_count < requested_count
				and created_count == admitted_count
				and skipped_count > 0
				and cancelled_count == 0
				and failed_count == 0
			)
		Status.REJECTED:
			return (
				reason == REASON_CAPACITY_UNAVAILABLE
				and error_code == ERR_BUSY
				and requested_count > 0
				and admitted_count == 0
				and skipped_count == requested_count
			)
		Status.CANCELLED:
			return (
				reason in [
					REASON_CALLER_CANCELLED,
					REASON_TOKEN_CANCELLED,
					REASON_CANCELLATION_SCOPE_COMPLETED,
					REASON_OWNER_RELEASED,
					REASON_PARENT_RELEASED,
				]
				and error_code == ERR_SKIP
				and cancelled_count > 0
				and failed_count == 0
			)
		Status.DISPOSED:
			return (
				reason in [REASON_UTILITY_DISPOSED, REASON_UTILITY_REINITIALIZED]
				and error_code == ERR_UNAVAILABLE
				and failed_count == 0
				and admitted_count == created_count + cancelled_count
			)
		Status.INVALID:
			return (
				reason in [
					REASON_INVALID_SCENE,
					REASON_INVALID_COUNT,
					REASON_INVALID_PARENT,
					REASON_INVALID_OWNER,
					REASON_INVALID_PREPARE_CALLBACK,
				]
				and error_code == ERR_INVALID_PARAMETER
				and admitted_count == 0
				and created_count == 0
				and cancelled_count == 0
				and failed_count == 0
				and skipped_count == requested_count
			)
		Status.FAILED:
			return (
				_failed_reason_error_is_valid(reason, error_code)
				and failed_count > 0
				and cancelled_count == 0
			)
	return false


static func _failed_reason_error_is_valid(reason: StringName, error_code: Error) -> bool:
	match reason:
		REASON_SCENE_INSTANTIATION_FAILED:
			return error_code == ERR_CANT_CREATE
		REASON_PREPARE_CALLBACK_FAILED:
			return error_code != OK
		REASON_INVALID_PREPARE_CALLBACK_RESULT:
			return error_code == ERR_INVALID_DATA
		REASON_CANDIDATE_INVALIDATED:
			return error_code == ERR_UNAVAILABLE
		REASON_INTERNAL_FAILURE:
			return error_code == FAILED
	return false
