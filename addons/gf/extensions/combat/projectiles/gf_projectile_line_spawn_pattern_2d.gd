## GFProjectileLineSpawnPattern2D: 沿 2D 局部线段生成发射点。
##
## 只描述发射点分布，适合多炮口、线性随机点或沿武器边缘生成发射体。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFProjectileLineSpawnPattern2D
extends GFProjectileSpawnPattern2D


# --- 导出变量 ---

## 默认发射数量。
## [br]
## @api public
@export_range(1, 256, 1) var point_count: int = 1

## 线段局部起点。
## [br]
## @api public
@export var local_start: Vector2 = Vector2.ZERO

## 线段局部终点。
## [br]
## @api public
@export var local_end: Vector2 = Vector2.ZERO

## 生成变换是否朝向线段方向。
## [br]
## @api public
@export var rotate_to_line: bool = false


# --- 可重写钩子 / 虚方法 ---

## 生成 2D 线段发射变换。
## [br]
## @api protected
## [br]
## @param emitter: 发射器节点。
## [br]
## @param _projectile_context: 本次发射上下文。
## [br]
## @param emit_count: 调用方请求的数量；小于等于 0 时使用 point_count。
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
	var local_direction: Vector2 = local_end - local_start
	var rotation: float = emitter.global_rotation
	if rotate_to_line and not local_direction.is_zero_approx():
		rotation += local_direction.angle()
	for index: int in range(count):
		var factor: float = 0.5
		if count > 1:
			factor = float(index) / float(count - 1)
		var local_position: Vector2 = local_start.lerp(local_end, factor)
		result.append(Transform2D(rotation, emitter.to_global(local_position)))
	return result


func _get_default_spawn_count() -> int:
	return point_count
