## GFLinearProjectileMotion: 2D/3D 通用直线发射体移动策略。
##
## 该策略只处理线性位移，不处理碰撞、伤害、生命周期或目标选择。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFLinearProjectileMotion
extends GFProjectileMotion


# --- 导出变量 ---

## 每秒移动距离。
## [br]
## @api public
@export var speed: float = 0.0

## 2D 方向。use_local_direction 为 true 时按发射体当前变换转换。
## [br]
## @api public
@export var direction_2d: Vector2 = Vector2.RIGHT

## 3D 方向。use_local_direction 为 true 时按发射体当前变换转换。
## [br]
## @api public
@export var direction_3d: Vector3 = Vector3.FORWARD

## 是否把方向视为发射体本地坐标。
## [br]
## @api public
@export var use_local_direction: bool = true

## 是否归一化方向。
## [br]
## @api public
@export var normalize_direction: bool = true


# --- 可重写钩子 / 虚方法 ---

## 推进直线移动。
## [br]
## @api protected
## [br]
## @param projectile: 发射体节点。
## [br]
## @param delta: 物理帧间隔。
## [br]
## @param projectile_context: 本次发射上下文字典。
## [br]
## @schema projectile_context: Dictionary，本次发射上下文；会写入 velocity_2d 或 velocity_3d。
func _step(projectile: Node, delta: float, projectile_context: Dictionary = {}) -> void:
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(delta) or not _GF_COMBAT_FINITE_MATH.is_finite_float(speed):
		projectile_context["motion_rejected_reason"] = &"non_finite_motion_configuration"
		return
	if projectile is Node2D:
		var projectile_2d: Node2D = projectile
		_step_2d(projectile_2d, delta, projectile_context)
	elif projectile is Node3D:
		var projectile_3d: Node3D = projectile
		_step_3d(projectile_3d, delta, projectile_context)


# --- 私有/辅助方法 ---

func _step_2d(projectile: Node2D, delta: float, projectile_context: Dictionary) -> void:
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector2(direction_2d):
		_reject_motion_2d(projectile_context)
		return
	var direction: Vector2 = direction_2d
	if use_local_direction:
		var transform: Transform2D = projectile.global_transform if projectile.is_inside_tree() else projectile.transform
		if not _GF_COMBAT_FINITE_MATH.is_finite_transform2d(transform):
			_reject_motion_2d(projectile_context)
			return
		direction = transform.x * direction_2d.x + transform.y * direction_2d.y
	if normalize_direction and not direction.is_zero_approx():
		direction = direction.normalized()

	var velocity: Vector2 = direction * speed
	var current_position: Vector2 = projectile.global_position if projectile.is_inside_tree() else projectile.position
	var next_position: Vector2 = current_position + velocity * delta
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_vector2(velocity)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector2(current_position)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector2(next_position)
	):
		_reject_motion_2d(projectile_context)
		return
	if projectile.is_inside_tree():
		projectile.global_position = next_position
	else:
		projectile.position = next_position
	projectile_context["velocity_2d"] = velocity


func _step_3d(projectile: Node3D, delta: float, projectile_context: Dictionary) -> void:
	if not _GF_COMBAT_FINITE_MATH.is_finite_vector3(direction_3d):
		_reject_motion_3d(projectile_context)
		return
	var direction: Vector3 = direction_3d
	if use_local_direction:
		var transform: Transform3D = projectile.global_transform if projectile.is_inside_tree() else projectile.transform
		if not _GF_COMBAT_FINITE_MATH.is_finite_transform3d(transform):
			_reject_motion_3d(projectile_context)
			return
		direction = transform.basis * direction_3d
	if normalize_direction and not direction.is_zero_approx():
		direction = direction.normalized()

	var velocity: Vector3 = direction * speed
	var current_position: Vector3 = projectile.global_position if projectile.is_inside_tree() else projectile.position
	var next_position: Vector3 = current_position + velocity * delta
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_vector3(velocity)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector3(current_position)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector3(next_position)
	):
		_reject_motion_3d(projectile_context)
		return
	if projectile.is_inside_tree():
		projectile.global_position = next_position
	else:
		projectile.position = next_position
	projectile_context["velocity_3d"] = velocity


func _reject_motion_2d(projectile_context: Dictionary) -> void:
	projectile_context["motion_rejected_reason"] = &"non_finite_motion_state"
	projectile_context["velocity_2d"] = Vector2.ZERO


func _reject_motion_3d(projectile_context: Dictionary) -> void:
	projectile_context["motion_rejected_reason"] = &"non_finite_motion_state"
	projectile_context["velocity_3d"] = Vector3.ZERO
