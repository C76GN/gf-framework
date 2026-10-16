## GFSteeringAgent: steering 计算使用的通用代理状态。
##
## 只描述位置、速度、朝向和运动上限，不持有 Node 或物理体。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFSteeringAgent
extends RefCounted


# --- 公共变量 ---

## 当前世界位置。2D 项目可使用 x/y，z 保持 0。
## [br]
## @api public
var position: Vector3 = Vector3.ZERO

## 当前线性速度。2D 项目可使用 x/y，z 保持 0。
## [br]
## @api public
var velocity: Vector3 = Vector3.ZERO

## 当前朝向角，单位为弧度。
## [br]
## @api public
var orientation: float = 0.0

## 当前角速度，单位为弧度每秒。
## [br]
## @api public
var angular_velocity: float = 0.0

## 代理半径，用于邻域或避让计算。
## [br]
## @api public
var radius: float = 8.0

## 最大线性速度。
## [br]
## @api public
var linear_speed_max: float = 240.0

## 最大线性加速度。
## [br]
## @api public
var linear_acceleration_max: float = 800.0

## 最大角速度。
## [br]
## @api public
var angular_speed_max: float = TAU

## 最大角加速度。
## [br]
## @api public
var angular_acceleration_max: float = TAU * 4.0


# --- Godot 生命周期方法 ---

func _init(p_position: Vector3 = Vector3.ZERO, p_velocity: Vector3 = Vector3.ZERO) -> void:
	position = p_position
	velocity = p_velocity


# --- 公共方法 ---

## 从 Node2D 同步位置与朝向。
## [br]
## @api public
## [br]
## @param node: 目标 Node2D。
## [br]
## @param linear_velocity: 可选线性速度。
func set_from_node_2d(node: Node2D, linear_velocity: Vector2 = Vector2.ZERO) -> void:
	if not is_instance_valid(node):
		return
	position = Vector3(
		node.global_position.x,
		node.global_position.y,
		0.0
	)
	velocity = Vector3(
		linear_velocity.x,
		linear_velocity.y,
		0.0
	)
	orientation = node.global_rotation


## 从 Node3D 同步位置与朝向。
## [br]
## @api public
## [br]
## @param node: 目标 Node3D。
## [br]
## @param linear_velocity: 可选线性速度。
func set_from_node_3d(node: Node3D, linear_velocity: Vector3 = Vector3.ZERO) -> void:
	if not is_instance_valid(node):
		return
	position = node.global_position
	velocity = linear_velocity
	orientation = node.global_rotation.y


## 创建深拷贝。
## [br]
## @api public
## [br]
## @return 新代理状态。
func duplicate_agent() -> GFSteeringAgent:
	var agent: GFSteeringAgent = GFSteeringAgent.new(position, velocity)
	agent.orientation = orientation
	agent.angular_velocity = angular_velocity
	agent.radius = radius
	agent.linear_speed_max = linear_speed_max
	agent.linear_acceleration_max = linear_acceleration_max
	agent.angular_speed_max = angular_speed_max
	agent.angular_acceleration_max = angular_acceleration_max
	return agent
