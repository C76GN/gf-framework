## GFProjectileLifetimePolicy: 基于 session 观测值的生命周期策略。
## Runtime 在 launch 时强持有策略快照；Definition 后续替换/清空或外部引用释放
## 不改变 ACTIVE session，终态清理后 Runtime 释放该快照。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFProjectileLifetimePolicy
extends Resource


## 最大活动时长；不大于零表示不限制。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var max_seconds: float = 0.0

## 最大累计实际位移；不大于零表示不限制。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var max_distance: float = 0.0

## 最大已接受 impact 数；不大于零表示不限制。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var max_impacts: int = 0


## 计算当前 session 是否已触发生命周期终止条件。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param session: 当前 projectile session。
## [br]
## @return: 尚未结束时为 `NONE`，否则为首个匹配的生命周期原因。
func get_end_reason(session: GFProjectileSession) -> GFProjectileSession.EndReason:
	if session == null:
		return GFProjectileSession.EndReason.INTERNAL_FAILURE
	if max_seconds > 0.0 and session.get_elapsed_seconds() >= max_seconds:
		return GFProjectileSession.EndReason.LIFETIME_SECONDS
	if max_distance > 0.0 and session.get_travelled_distance() >= max_distance:
		return GFProjectileSession.EndReason.LIFETIME_DISTANCE
	if max_impacts > 0 and session.get_accepted_impact_count() >= max_impacts:
		return GFProjectileSession.EndReason.LIFETIME_IMPACTS
	if _should_finish(session):
		return GFProjectileSession.EndReason.LIFETIME_CUSTOM
	return GFProjectileSession.EndReason.NONE


# --- 可重写钩子 / 虚方法 ---

## 自定义生命周期终止钩子。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param _session: 当前 projectile session。
## [br]
## @return: 是否以 `LIFETIME_CUSTOM` 结束。
func _should_finish(_session: GFProjectileSession) -> bool:
	return false
