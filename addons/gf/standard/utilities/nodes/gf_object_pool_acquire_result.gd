## GFObjectPoolAcquireResult: 单次节点借用的结果。
##
## 结果记录完成时的事实；成功结果中的 Lease 仍有自己的后续生命周期。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFObjectPoolAcquireResult
extends RefCounted


# --- 枚举 ---

## 借用请求的最终结果。
## [br]
## @api public
## [br]
## @since unreleased
enum Status {
	## 已完成挂载并交付借用。
	SUCCEEDED,
	## 输入或调用线程不符合要求。
	INVALID,
	## 父节点或对象池生命周期已经结束。
	CANCELLED,
	## 实例化、准备或挂载失败。
	FAILED,
}


# --- 私有变量 ---

var _status: Status = Status.INVALID
var _stage: StringName = &"validation"
var _reason: StringName = &"unconfigured"
var _lease: GFObjectPoolLease = null
var _configured: bool = false


# --- 公共方法 ---

## 检查请求是否成功交付过借用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: status 为 SUCCEEDED 时为 true。
func is_successful() -> bool:
	return _status == Status.SUCCEEDED


## 获取最终状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 本次请求的 Status。
func get_status() -> Status:
	return _status


## 获取完成或失败的业务阶段。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: validation、allocation、prepare、attach 或 complete。
func get_stage() -> StringName:
	return _stage


## 获取稳定的结果原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: acquired、invalid_scene、invalid_parent、invalid_owner、main_thread_required、pool_disposed、parent_lost、owner_lost、scene_instantiation_failed、prepare_failed、invalid_prepare_result 或 candidate_invalidated；未配置结果为 unconfigured。
func get_reason() -> StringName:
	return _reason


## 获取成功交付的借用。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 仅成功时非 null；是否仍可使用节点应查询 Lease。
func get_lease() -> GFObjectPoolLease:
	return _lease


# --- 框架内部方法 ---

## 由对象池冻结一次结果。
## [br]
## @api framework_internal
## [br]
## @param status: 本次请求的最终状态。
## [br]
## @param stage: 请求完成或失败时的业务阶段。
## [br]
## @param reason: 对应状态与阶段的稳定结果原因。
## [br]
## @param lease: 成功交付的借用；非成功状态不会保留该值。
func configure_for_framework(
	status: Status,
	stage: StringName,
	reason: StringName,
	lease: GFObjectPoolLease = null
) -> void:
	if _configured:
		return
	_configured = true
	_status = status
	_stage = stage
	_reason = reason
	_lease = lease if status == Status.SUCCEEDED else null
