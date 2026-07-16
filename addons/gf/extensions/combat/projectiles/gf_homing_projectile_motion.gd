## GFHomingProjectileMotion: 2D/3D 通用追踪发射体移动策略。
##
## 目标可通过 launch() 上下文中的 target、target_position、target_position_2d
## 或 target_position_3d 传入，也可以用 target_path 从发射体节点相对查找。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFHomingProjectileMotion
extends GFProjectileMotion


# --- 常量 ---

const _DIRECTION_2D_KEY: StringName = &"homing_direction_2d"
const _DIRECTION_3D_KEY: StringName = &"homing_direction_3d"


# --- 导出变量 ---

## 每秒移动距离。
## [br]
## @api public
@export var speed: float = 0.0

## 可选目标节点路径。为空时只读取 projectile_context。
## [br]
## @api public
@export var target_path: NodePath = NodePath("")

## 从 projectile_context 读取目标对象或位置的键。
## [br]
## @api public
@export var target_context_key: StringName = &"target"

## 从 projectile_context 读取通用目标位置的键。
## [br]
## @api public
@export var target_position_context_key: StringName = &"target_position"

## 到目标的距离小于等于该值时视为到达。小于 0 表示不标记到达。
## [br]
## @api public
@export var arrival_distance: float = 0.0

## 是否每帧重新朝向当前目标。关闭后只在首次解析目标时锁定方向。
## [br]
## @api public
@export var track_target: bool = true

## 到达目标范围时是否停止并夹住位移，避免越过目标。
## [br]
## @api public
@export var stop_when_reached: bool = true


# --- 可重写钩子 / 虚方法 ---

## 缓存初始追踪方向。
## [br]
## @api protected
## [br]
## @param projectile: 发射体节点。
## [br]
## @param projectile_context: 本次发射上下文字典。
## [br]
## @schema projectile_context: Dictionary，本次发射上下文；可包含 target、target_position、target_position_2d 或 target_position_3d。
func _setup(projectile: Node, projectile_context: Dictionary = {}) -> void:
	if projectile is Node2D:
		var projectile_2d: Node2D = projectile
		_cache_direction_2d(projectile_2d, projectile_context)
	elif projectile is Node3D:
		var projectile_3d: Node3D = projectile
		_cache_direction_3d(projectile_3d, projectile_context)


## 推进追踪移动。
## [br]
## @api protected
## [br]
## @param projectile: 发射体节点。
## [br]
## @param delta: 物理帧间隔。
## [br]
## @param projectile_context: 本次发射上下文字典。
## [br]
## @schema projectile_context: Dictionary，本次发射上下文；会写入目标距离、速度和到达状态。
func _step(projectile: Node, delta: float, projectile_context: Dictionary = {}) -> void:
	if (
		delta <= 0.0
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(delta)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(speed)
		or not _GF_COMBAT_FINITE_MATH.is_finite_float(arrival_distance)
	):
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
	var target_position_variant: Variant = _get_target_position_2d(projectile, projectile_context)
	if not (target_position_variant is Vector2):
		projectile_context["target_missing"] = true
		projectile_context["velocity_2d"] = Vector2.ZERO
		return

	var target_position: Vector2 = target_position_variant
	var current_position: Vector2 = _get_projectile_position_2d(projectile)
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_vector2(target_position)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector2(current_position)
	):
		_reject_motion_2d(projectile_context)
		return
	var offset: Vector2 = target_position - current_position
	var distance: float = offset.length()
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(distance):
		_reject_motion_2d(projectile_context)
		return
	projectile_context["target_distance_2d"] = distance
	if _is_arrived(distance):
		projectile_context["target_reached"] = true
		projectile_context["velocity_2d"] = Vector2.ZERO
		if stop_when_reached:
			return

	var direction: Vector2 = _get_direction_2d(offset, projectile_context)
	if direction.is_zero_approx():
		projectile_context["velocity_2d"] = Vector2.ZERO
		return

	var travel_distance: float = speed * delta
	if stop_when_reached and arrival_distance >= 0.0:
		travel_distance = minf(travel_distance, maxf(distance - arrival_distance, 0.0))

	var velocity: Vector2 = direction * (travel_distance / delta)
	var next_position: Vector2 = current_position + direction * travel_distance
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_float(travel_distance)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector2(velocity)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector2(next_position)
	):
		_reject_motion_2d(projectile_context)
		return
	_set_projectile_position_2d(projectile, next_position)
	projectile_context["velocity_2d"] = velocity
	if _is_arrived(distance - travel_distance):
		projectile_context["target_reached"] = true


func _step_3d(projectile: Node3D, delta: float, projectile_context: Dictionary) -> void:
	var target_position_variant: Variant = _get_target_position_3d(projectile, projectile_context)
	if not (target_position_variant is Vector3):
		projectile_context["target_missing"] = true
		projectile_context["velocity_3d"] = Vector3.ZERO
		return

	var target_position: Vector3 = target_position_variant
	var current_position: Vector3 = _get_projectile_position_3d(projectile)
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_vector3(target_position)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector3(current_position)
	):
		_reject_motion_3d(projectile_context)
		return
	var offset: Vector3 = target_position - current_position
	var distance: float = offset.length()
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(distance):
		_reject_motion_3d(projectile_context)
		return
	projectile_context["target_distance_3d"] = distance
	if _is_arrived(distance):
		projectile_context["target_reached"] = true
		projectile_context["velocity_3d"] = Vector3.ZERO
		if stop_when_reached:
			return

	var direction: Vector3 = _get_direction_3d(offset, projectile_context)
	if direction.is_zero_approx():
		projectile_context["velocity_3d"] = Vector3.ZERO
		return

	var travel_distance: float = speed * delta
	if stop_when_reached and arrival_distance >= 0.0:
		travel_distance = minf(travel_distance, maxf(distance - arrival_distance, 0.0))

	var velocity: Vector3 = direction * (travel_distance / delta)
	var next_position: Vector3 = current_position + direction * travel_distance
	if (
		not _GF_COMBAT_FINITE_MATH.is_finite_float(travel_distance)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector3(velocity)
		or not _GF_COMBAT_FINITE_MATH.is_finite_vector3(next_position)
	):
		_reject_motion_3d(projectile_context)
		return
	_set_projectile_position_3d(projectile, next_position)
	projectile_context["velocity_3d"] = velocity
	if _is_arrived(distance - travel_distance):
		projectile_context["target_reached"] = true


func _cache_direction_2d(projectile: Node2D, projectile_context: Dictionary) -> void:
	var target_position_variant: Variant = _get_target_position_2d(projectile, projectile_context)
	if not (target_position_variant is Vector2):
		return
	var target_position: Vector2 = target_position_variant
	var offset: Vector2 = target_position - _get_projectile_position_2d(projectile)
	if not offset.is_zero_approx():
		projectile_context[_DIRECTION_2D_KEY] = offset.normalized()


func _cache_direction_3d(projectile: Node3D, projectile_context: Dictionary) -> void:
	var target_position_variant: Variant = _get_target_position_3d(projectile, projectile_context)
	if not (target_position_variant is Vector3):
		return
	var target_position: Vector3 = target_position_variant
	var offset: Vector3 = target_position - _get_projectile_position_3d(projectile)
	if not offset.is_zero_approx():
		projectile_context[_DIRECTION_3D_KEY] = offset.normalized()


func _get_direction_2d(offset: Vector2, projectile_context: Dictionary) -> Vector2:
	if track_target or not projectile_context.has(_DIRECTION_2D_KEY):
		if offset.is_zero_approx():
			return Vector2.ZERO
		var direction: Vector2 = offset.normalized()
		projectile_context[_DIRECTION_2D_KEY] = direction
		return direction

	var cached_direction: Variant = GFVariantData.get_option_value(projectile_context, _DIRECTION_2D_KEY, Vector2.ZERO)
	if cached_direction is Vector2:
		var direction: Vector2 = cached_direction
		if _GF_COMBAT_FINITE_MATH.is_finite_vector2(direction) and not direction.is_zero_approx():
			return direction.normalized()
	return Vector2.ZERO


func _get_direction_3d(offset: Vector3, projectile_context: Dictionary) -> Vector3:
	if track_target or not projectile_context.has(_DIRECTION_3D_KEY):
		if offset.is_zero_approx():
			return Vector3.ZERO
		var direction: Vector3 = offset.normalized()
		projectile_context[_DIRECTION_3D_KEY] = direction
		return direction

	var cached_direction: Variant = GFVariantData.get_option_value(projectile_context, _DIRECTION_3D_KEY, Vector3.ZERO)
	if cached_direction is Vector3:
		var direction: Vector3 = cached_direction
		if _GF_COMBAT_FINITE_MATH.is_finite_vector3(direction) and not direction.is_zero_approx():
			return direction.normalized()
	return Vector3.ZERO


func _get_target_position_2d(projectile: Node2D, projectile_context: Dictionary) -> Variant:
	if projectile_context.has(&"target_position_2d"):
		var typed_position: Variant = GFVariantData.get_option_value(projectile_context, &"target_position_2d")
		if typed_position is Vector2:
			var typed_vector: Vector2 = typed_position
			if _GF_COMBAT_FINITE_MATH.is_finite_vector2(typed_vector):
				return typed_vector

	var common_position: Variant = GFVariantData.get_option_value(projectile_context, target_position_context_key)
	if common_position is Vector2:
		var common_vector: Vector2 = common_position
		if _GF_COMBAT_FINITE_MATH.is_finite_vector2(common_vector):
			return common_vector

	var target: Variant = GFVariantData.get_option_value(projectile_context, target_context_key)
	if target is Vector2:
		var target_vector: Vector2 = target
		if _GF_COMBAT_FINITE_MATH.is_finite_vector2(target_vector):
			return target_vector
	var target_2d: Node2D = _variant_to_valid_node_2d(target)
	if target_2d != null:
		return target_2d.global_position if target_2d.is_inside_tree() else target_2d.position

	var path_target_2d: Node2D = _variant_to_valid_node_2d(_get_path_target(projectile))
	if path_target_2d != null:
		return path_target_2d.global_position if path_target_2d.is_inside_tree() else path_target_2d.position
	return null


func _get_target_position_3d(projectile: Node3D, projectile_context: Dictionary) -> Variant:
	if projectile_context.has(&"target_position_3d"):
		var typed_position: Variant = GFVariantData.get_option_value(projectile_context, &"target_position_3d")
		if typed_position is Vector3:
			var typed_vector: Vector3 = typed_position
			if _GF_COMBAT_FINITE_MATH.is_finite_vector3(typed_vector):
				return typed_vector

	var common_position: Variant = GFVariantData.get_option_value(projectile_context, target_position_context_key)
	if common_position is Vector3:
		var common_vector: Vector3 = common_position
		if _GF_COMBAT_FINITE_MATH.is_finite_vector3(common_vector):
			return common_vector

	var target: Variant = GFVariantData.get_option_value(projectile_context, target_context_key)
	if target is Vector3:
		var target_vector: Vector3 = target
		if _GF_COMBAT_FINITE_MATH.is_finite_vector3(target_vector):
			return target_vector
	var target_3d: Node3D = _variant_to_valid_node_3d(target)
	if target_3d != null:
		return target_3d.global_position if target_3d.is_inside_tree() else target_3d.position

	var path_target_3d: Node3D = _variant_to_valid_node_3d(_get_path_target(projectile))
	if path_target_3d != null:
		return path_target_3d.global_position if path_target_3d.is_inside_tree() else path_target_3d.position
	return null


func _get_path_target(projectile: Node) -> Node:
	if target_path == NodePath(""):
		return null
	return projectile.get_node_or_null(target_path)


func _variant_to_valid_node_2d(value: Variant) -> Node2D:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	var object: Object = value
	if object is Node2D:
		var node: Node2D = object
		return node
	return null


func _variant_to_valid_node_3d(value: Variant) -> Node3D:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	var object: Object = value
	if object is Node3D:
		var node: Node3D = object
		return node
	return null


func _get_projectile_position_2d(projectile: Node2D) -> Vector2:
	return projectile.global_position if projectile.is_inside_tree() else projectile.position


func _set_projectile_position_2d(projectile: Node2D, position: Vector2) -> void:
	if projectile.is_inside_tree():
		projectile.global_position = position
	else:
		projectile.position = position


func _get_projectile_position_3d(projectile: Node3D) -> Vector3:
	return projectile.global_position if projectile.is_inside_tree() else projectile.position


func _set_projectile_position_3d(projectile: Node3D, position: Vector3) -> void:
	if projectile.is_inside_tree():
		projectile.global_position = position
	else:
		projectile.position = position


func _is_arrived(distance: float) -> bool:
	return (
		_GF_COMBAT_FINITE_MATH.is_finite_float(distance)
		and _GF_COMBAT_FINITE_MATH.is_finite_float(arrival_distance)
		and arrival_distance >= 0.0
		and distance <= arrival_distance
	)


func _reject_motion_2d(projectile_context: Dictionary) -> void:
	projectile_context["motion_rejected_reason"] = &"non_finite_motion_state"
	projectile_context["velocity_2d"] = Vector2.ZERO


func _reject_motion_3d(projectile_context: Dictionary) -> void:
	projectile_context["motion_rejected_reason"] = &"non_finite_motion_state"
	projectile_context["velocity_3d"] = Vector3.ZERO
