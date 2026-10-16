## GFHitCollisionShapeConfig3D: 3D 命中区域碰撞形状配置。
##
## 用于把可复用的 Shape3D、偏移、旋转、缩放、调试颜色和禁用状态应用到 HitBox / HurtBox
## 自动生成的 CollisionShape3D 上。不表达伤害、阵营或其他玩法规则。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFHitCollisionShapeConfig3D
extends Resource


# --- 导出变量 ---

## 要应用的 Godot 3D 碰撞形状。
## [br]
## @api public
@export var shape: Shape3D = null

## 碰撞形状相对 HitBox / HurtBox 节点的位置。
## [br]
## @api public
@export var position: Vector3 = Vector3.ZERO

## 碰撞形状相对 HitBox / HurtBox 节点的旋转角度。
## [br]
## @api public
@export var rotation_degrees: Vector3 = Vector3.ZERO

## 碰撞形状相对 HitBox / HurtBox 节点的缩放。
## [br]
## @api public
@export var scale: Vector3 = Vector3.ONE

## 调试绘制颜色。透明色会沿用 Godot 默认调试显示。
## [br]
## @api public
## [br]
## @since 3.2.0
@export var debug_color: Color = Color(
	0.0,
	0.0,
	0.0,
	0.0
)

## 是否禁用生成的 CollisionShape3D。
## [br]
## @api public
@export var disabled: bool = false


# --- 公共方法 ---

## 将配置应用到指定 CollisionShape3D。
## [br]
## @api public
## [br]
## @param collision_shape: 目标 CollisionShape3D。
## [br]
## @return 应用成功返回 true。
func apply_to(collision_shape: CollisionShape3D) -> bool:
	if collision_shape == null or shape == null:
		return false

	collision_shape.shape = shape
	collision_shape.position = position
	collision_shape.rotation_degrees = rotation_degrees
	collision_shape.scale = scale
	collision_shape.debug_color = debug_color
	collision_shape.disabled = disabled
	return true


## 创建一个已应用当前配置的 CollisionShape3D。
## [br]
## @api public
## [br]
## @return 创建成功返回 CollisionShape3D；配置缺少 shape 时返回 null。
func instantiate_collision_shape() -> CollisionShape3D:
	if shape == null:
		return null

	var collision_shape: CollisionShape3D = CollisionShape3D.new()
	if not apply_to(collision_shape):
		return null
	return collision_shape
