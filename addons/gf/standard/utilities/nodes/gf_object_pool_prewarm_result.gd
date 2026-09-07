## GFObjectPoolPrewarmResult: 离树实例预分配的最终结果。
##
## 取消只停止未创建的实例，已经缓存的实例保留。预分配不执行入树或 ready。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFObjectPoolPrewarmResult
extends RefCounted


# --- 枚举 ---

## 预分配请求的终态。
## [br]
## @api public
## [br]
## @since 11.0.0
enum Status {
	## 已创建全部请求实例。
	SUCCEEDED,
	## 缓存容量不足，仅创建部分实例。
	PARTIAL,
	## 请求参数无效。
	INVALID,
	## 请求被令牌或池生命周期取消。
	CANCELLED,
	## 实例化失败。
	FAILED,
}


# --- 私有变量 ---

var _status: Status = Status.INVALID
var _reason: StringName = &"unconfigured"
var _requested_count: int = 0
var _created_count: int = 0
var _configured: bool = false


# --- 公共方法 ---

## 检查是否完成全部预分配。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 仅 SUCCEEDED 返回 true。
func is_successful() -> bool:
	return _status == Status.SUCCEEDED


## 获取终态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 请求的最终 Status。
func get_status() -> Status:
	return _status


## 获取结果原因。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: prewarmed、capacity_limited、invalid_scene、invalid_count、invalid_batch_size、main_thread_required、cancelled、pool_disposed 或 scene_instantiation_failed；未配置时为 unconfigured。
func get_reason() -> StringName:
	return _reason


## 获取有效的请求数量。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 非负请求数量；负数输入的无效结果归零。
func get_requested_count() -> int:
	return _requested_count


## 获取本次已成功缓存的实例数量。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 完成时已创建数量，不保证这些实例以后仍留在缓存中。
func get_created_count() -> int:
	return _created_count


# --- 框架内部方法 ---

## 冻结一次预分配结果。
## [br]
## @api framework_internal
## [br]
## @param status: 预分配请求的最终状态。
## [br]
## @param reason: 对应终态的稳定结果原因。
## [br]
## @param requested_count: 本次请求数量；无效负数输入会归零。
## [br]
## @param created_count: 本次请求实际成功缓存的实例数量。
func configure_for_framework(
	status: Status,
	reason: StringName,
	requested_count: int,
	created_count: int
) -> void:
	if _configured:
		return
	_configured = true
	_status = status
	_reason = reason
	_requested_count = maxi(0, requested_count)
	_created_count = created_count
