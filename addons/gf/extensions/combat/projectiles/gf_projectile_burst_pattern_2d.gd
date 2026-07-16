## GFProjectileBurstPattern2D: 2D 扇形/环形发射点模式。
##
## 通过数量、角度和半径生成一组通用发射变换，适合散射、圆环、扇形或单点发射。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFProjectileBurstPattern2D
extends GFProjectileSpawnPattern2D


# --- 导出变量 ---

## 默认发射数量。
## [br]
## @api public
@export_range(1, 256, 1) var projectile_count: int = 1

## 总扩散角度（度）。数量大于 1 时在该范围内均匀分布。
## [br]
## @api public
@export var spread_degrees: float = 0.0

## 相对发射器朝向的中心角度（度）。
## [br]
## @api public
@export var center_angle_degrees: float = 0.0

## 生成点距离发射器的半径。
## [br]
## @api public
@export var radius: float = 0.0

## 生成变换是否朝向对应发射方向。
## [br]
## @api public
@export var rotate_to_direction: bool = true

## 是否把发射器自身旋转计入方向。
## [br]
## @api public
@export var include_emitter_rotation: bool = true


# --- 可重写钩子 / 虚方法 ---

## 生成 2D 扇形或环形发射变换。
## [br]
## @api protected
## [br]
## @param emitter: 发射器节点。
## [br]
## @param _projectile_context: 本次发射上下文。
## [br]
## @param emit_count: 调用方请求的数量；小于等于 0 时使用 projectile_count。
## [br]
## @return 全局 Transform2D 列表。
## [br]
## @schema _projectile_context: Dictionary，本次发射上下文；当前实现不读取该字典。
func _get_spawn_transforms(
	emitter: Node2D,
	_projectile_context: Dictionary = {},
	emit_count: int = -1
) -> Array[Transform2D]:
	if emitter == null:
		return []

	var count: int = resolve_spawn_count(emit_count)
	var result: Array[Transform2D] = []
	var base_angle: float = emitter.global_rotation if include_emitter_rotation else 0.0
	var center_angle: float = base_angle + deg_to_rad(center_angle_degrees)
	var spread: float = deg_to_rad(spread_degrees)
	for index: int in range(count):
		var factor: float = 0.5
		if count > 1:
			factor = float(index) / float(count - 1)
		var angle: float = center_angle + ((factor - 0.5) * spread)
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var position: Vector2 = emitter.global_position + direction * maxf(radius, 0.0)
		var rotation: float = angle if rotate_to_direction else emitter.global_rotation
		result.append(Transform2D(rotation, position))
	return result


func _get_default_spawn_count() -> int:
	return projectile_count
