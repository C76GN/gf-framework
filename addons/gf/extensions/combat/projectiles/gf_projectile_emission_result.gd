## GFProjectileEmissionResult: 一次原子发射请求的不可变终态。
##
## 单发和批量发射共享同一结果类型。成功结果持有按稳定生成顺序排列的已激活
## Session；失败结果不持有任何部分成功 Session。结果描述已经完成的发射，
## 不延长 Session 的生命；通知回调可以立即结束 Session。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFProjectileEmissionResult
extends RefCounted


# --- 枚举 ---

## 发射请求的唯一终态。
## [br]
## @api public
## [br]
## @since unreleased
enum Status {
	## 全批 Session 曾进入 ACTIVE 并完成公开通知。
	SUCCEEDED,
	## 请求在返回任何 Session 前失败或被生命周期取消。
	FAILED,
}


# --- 私有变量 ---

var _status: Status = Status.FAILED
var _stage: StringName = &"unconfigured"
var _reason: StringName = &"unconfigured"
var _requested_count: int = 0
var _sessions: Array[GFProjectileSession] = []
var _configured: bool = false


# --- 公共方法 ---

## 检查全批发射是否成功。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 全批 Session 曾进入 ACTIVE 并完成公开通知时返回 true。
func is_successful() -> bool:
	return _configured and _status == Status.SUCCEEDED


## 获取请求终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `Status` 闭合枚举值。
func get_status() -> Status:
	return _status


## 获取终止请求的事务阶段。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 稳定阶段名；成功时为 `completed`。
func get_stage() -> StringName:
	return _stage


## 获取终态原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 稳定原因；成功时为空 StringName。
func get_reason() -> StringName:
	return _reason


## 获取 spawn pattern 解析后的请求数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 非负请求数量；在数量解析前失败时为 0。
func get_requested_count() -> int:
	return _requested_count


## 获取成功发射的 Session 快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 按 spawn transform 稳定顺序排列的 Session；失败时为空数组。
## [br]
## @schema return: Array[GFProjectileSession]，返回新的数组容器，Session 本身保持同一身份。
func get_sessions() -> Array[GFProjectileSession]:
	return _sessions.duplicate()


## 获取成功发射数量。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `get_sessions()` 的当前快照数量。
func get_emitted_count() -> int:
	return _sessions.size()


# --- 框架内部方法 ---

## 由 Emitter 一次性冻结原子发射终态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param status: 唯一终态。
## [br]
## @param stage: 终止请求的稳定事务阶段。
## [br]
## @param reason: 稳定失败原因；成功时必须为空。
## [br]
## @param requested_count: spawn pattern 解析后的非负请求数量。
## [br]
## @param sessions: 成功发射的 Session，允许在通知中结束；失败时必须为空。
## [br]
## @return 首次配置且终态联合合法时返回 true。
func configure_for_framework(
	status: Status,
	stage: StringName,
	reason: StringName,
	requested_count: int,
	sessions: Array[GFProjectileSession]
) -> bool:
	if (
		_configured
		or not Status.values().has(int(status))
		or stage == &""
		or requested_count < 0
		or not _terminal_union_is_valid(status, stage, reason, sessions)
	):
		return false
	_status = status
	_stage = stage
	_reason = reason
	_requested_count = requested_count
	_sessions = sessions.duplicate()
	_configured = true
	return true


# --- 私有/辅助方法 ---

static func _terminal_union_is_valid(
	status: Status,
	stage: StringName,
	reason: StringName,
	sessions: Array[GFProjectileSession]
) -> bool:
	if status == Status.FAILED:
		return reason != &"" and sessions.is_empty()
	if stage != &"completed" or reason != &"" or sessions.is_empty():
		return false
	var session_ids: Dictionary = {}
	for projectile_session: GFProjectileSession in sessions:
		if (
			projectile_session == null
			or not is_instance_valid(projectile_session)
			or projectile_session.get_status() == GFProjectileSession.Status.UNCONFIGURED
		):
			return false
		var session_id: int = projectile_session.get_instance_id()
		if session_ids.has(session_id):
			return false
		session_ids[session_id] = true
	return true
