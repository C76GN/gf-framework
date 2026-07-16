## GFProjectileConePattern3D: 3D 水平扇形发射点模式。
##
## 围绕发射器局部 Y 轴分布 yaw，可叠加固定 pitch，并按变换前向生成点位。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFProjectileConePattern3D
extends GFProjectileSpawnPattern3D


# --- 导出变量 ---

## 默认发射数量。
## [br]
## @api public
@export_range(1, 256, 1) var projectile_count: int = 1

## 总水平扩散角度（度）。
## [br]
## @api public
@export var yaw_spread_degrees: float = 0.0

## 额外俯仰角度（度）。
## [br]
## @api public
@export var pitch_degrees: float = 0.0

## 生成点距离发射器的半径。
## [br]
## @api public
@export var radius: float = 0.0


# --- 可重写钩子 / 虚方法 ---

## 生成 3D 扇形发射变换。
## [br]
## @api protected
## [br]
## @param emitter: 发射器节点。
## [br]
## @param _projectile_context: 本次发射上下文。
## [br]
## @param emit_count: 调用方请求的数量；小于等于 0 时使用 projectile_count。
## [br]
## @return 全局 Transform3D 列表。
## [br]
## @schema _projectile_context: Dictionary，本次发射上下文；当前实现不读取该字典。
func _get_spawn_transforms(
	emitter: Node3D,
	_projectile_context: Dictionary = {},
	emit_count: int = -1
) -> Array[Transform3D]:
	if emitter == null:
		return []

	var count: int = resolve_spawn_count(emit_count)
	var result: Array[Transform3D] = []
	var yaw_spread: float = deg_to_rad(yaw_spread_degrees)
	var pitch: float = deg_to_rad(pitch_degrees)
	for index: int in range(count):
		var factor: float = 0.5
		if count > 1:
			factor = float(index) / float(count - 1)
		var yaw: float = (factor - 0.5) * yaw_spread
		var basis: Basis = emitter.global_basis * Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
		var direction: Vector3 = -basis.z.normalized()
		var position: Vector3 = emitter.global_position + direction * maxf(radius, 0.0)
		result.append(Transform3D(basis, position))
	return result


func _get_default_spawn_count() -> int:
	return projectile_count
