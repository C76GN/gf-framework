## GFProjectileMotion: 发射体移动策略基类。
##
## 移动策略只负责根据 delta 推进节点位置。需要跨帧保存的数据应写入
## projectile_context，避免共享 Resource 在多个发射体之间串状态。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFProjectileMotion
extends Resource


# --- 常量 ---

const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 公共方法 ---

## 发射体启动时调用。
## [br]
## @api public
## [br]
## @param projectile: 发射体节点。
## [br]
## @param projectile_context: 本次发射的上下文字典。
## [br]
## @schema projectile_context: Dictionary，本次发射上下文；移动策略可写入跨帧状态。
func setup(projectile: Node, projectile_context: Dictionary = {}) -> void:
	_setup(projectile, projectile_context)


## 推进一帧移动。
## [br]
## @api public
## [br]
## @param projectile: 发射体节点。
## [br]
## @param delta: 物理帧间隔。
## [br]
## @param projectile_context: 本次发射的上下文字典。
## [br]
## @schema projectile_context: Dictionary，本次发射上下文；移动策略可读取或写入跨帧状态。
func step(projectile: Node, delta: float, projectile_context: Dictionary = {}) -> void:
	if projectile == null or not _GF_COMBAT_FINITE_MATH.is_finite_float(delta) or delta < 0.0:
		projectile_context["motion_rejected_reason"] = &"non_finite_or_negative_delta"
		return
	_step(projectile, delta, projectile_context)


# --- 可重写钩子 / 虚方法 ---

## 发射体启动扩展点。
## [br]
## @api protected
## [br]
## @param _projectile: 发射体节点。
## [br]
## @param _projectile_context: 本次发射上下文字典。
## [br]
## @schema _projectile_context: Dictionary，本次发射上下文；移动策略可写入跨帧状态。
func _setup(_projectile: Node, _projectile_context: Dictionary = {}) -> void:
	pass


## 发射体移动扩展点。
## [br]
## @api protected
## [br]
## @param _projectile: 发射体节点。
## [br]
## @param _delta: 物理帧间隔。
## [br]
## @param _projectile_context: 本次发射上下文字典。
## [br]
## @schema _projectile_context: Dictionary，本次发射上下文；移动策略可读取或写入跨帧状态。
func _step(_projectile: Node, _delta: float, _projectile_context: Dictionary = {}) -> void:
	pass
