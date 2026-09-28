## GFSteeringBehaviorResource: 可资源化配置的 steering 行为。
##
## 包装 GFSteeringMath 的纯算法，允许项目用 Resource 组合 seek、arrive、avoid 等
## 通用行为。动态目标、邻居和路径通过 context 传入，避免把业务对象写死进资源。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFSteeringBehaviorResource
extends Resource


# --- 枚举 ---

## Steering 行为类型。
## [br]
## @api public
enum BehaviorType {
	## 朝目标位置加速。
	SEEK,
	## 远离目标位置。
	FLEE,
	## 抵达目标位置并减速。
	ARRIVE,
	## 追逐目标代理。
	PURSUE,
	## 躲避目标代理。
	EVADE,
	## 面向目标位置。
	FACE,
	## 朝当前速度方向转向。
	LOOK_WHERE_YOU_GO,
	## 对齐指定朝向。
	ALIGN,
	## 与邻居保持距离。
	SEPARATION,
	## 朝邻居中心靠拢。
	COHESION,
	## 基于预测最近距离避让碰撞。
	AVOID_COLLISIONS,
	## 沿路径计算目标点并 seek。
	PATH_FOLLOW_SEEK,
}


# --- 导出变量 ---

## 行为类型。
## [br]
## @api public
@export var behavior_type: BehaviorType = BehaviorType.SEEK

## 是否启用该行为。
## [br]
## @api public
@export var enabled: bool = true

## 组合时使用的权重。
## [br]
## @api public
@export var weight: float = 1.0

## 静态目标位置；context 中的 `target_position` 会覆盖该值。
## [br]
## @api public
@export var target_position: Vector3 = Vector3.ZERO

## 静态目标朝向；context 中的 `target_orientation` 会覆盖该值。
## [br]
## @api public
@export var target_orientation: float = 0.0

## 抵达半径。
## [br]
## @api public
@export var arrival_radius: float = 4.0

## 减速半径。
## [br]
## @api public
@export var slow_radius: float = 64.0

## 逼近期望时间。
## [br]
## @api public
@export var time_to_target: float = 0.1

## 角度对齐容差。
## [br]
## @api public
@export var align_tolerance: float = 0.001

## 开始角速度减速的角度。
## [br]
## @api public
@export var slow_angle: float = 0.5

## 3D 转向是否使用 x/z 平面。
## [br]
## @api public
@export var use_z_axis: bool = false

## 目标预测最大秒数。
## [br]
## @api public
@export var max_prediction_seconds: float = 1.0

## 分离行为距离衰减系数。
## [br]
## @api public
@export var decay_coefficient: float = 1.0

## 最大影响距离；小于 0 时由算法使用代理半径。
## [br]
## @api public
@export var max_distance: float = -1.0

## 避让碰撞半径；小于 0 时由算法使用双方半径。
## [br]
## @api public
@export var collision_radius: float = -1.0

## 避让最小分离距离；小于 0 时由算法使用碰撞半径。
## [br]
## @api public
@export var minimum_separation: float = -1.0

## 路径跟随前进偏移。
## [br]
## @api public
@export var path_offset: float = 0.0


# --- 公共方法 ---

## 计算 steering 加速度。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param context: 动态上下文，支持 target_position、target_orientation、target_agent、neighbors、targets、path。
## [br]
## @schema context: Dictionary steering behavior context with optional target_position, target_orientation, target_agent, neighbors, targets, and path.
## [br]
## @return steering 加速度。
func calculate(agent: GFSteeringAgent, context: Dictionary = {}) -> GFSteeringAcceleration:
	if not enabled or agent == null:
		return GFSteeringAcceleration.new()

	match behavior_type:
		BehaviorType.FLEE:
			return GFSteeringMath.flee(agent, _get_vector3(context, &"target_position", target_position))
		BehaviorType.ARRIVE:
			return GFSteeringMath.arrive(
				agent,
				_get_vector3(context, &"target_position", target_position),
				arrival_radius,
				slow_radius,
				time_to_target
			)
		BehaviorType.PURSUE:
			return GFSteeringMath.pursue(agent, _get_agent(context, &"target_agent"), max_prediction_seconds)
		BehaviorType.EVADE:
			return GFSteeringMath.evade(agent, _get_agent(context, &"target_agent"), max_prediction_seconds)
		BehaviorType.FACE:
			return GFSteeringMath.face(
				agent,
				_get_vector3(context, &"target_position", target_position),
				use_z_axis,
				align_tolerance,
				slow_angle,
				time_to_target
			)
		BehaviorType.LOOK_WHERE_YOU_GO:
			return GFSteeringMath.look_where_you_go(agent, use_z_axis, align_tolerance, slow_angle, time_to_target)
		BehaviorType.ALIGN:
			return GFSteeringMath.align(
				agent,
				GFVariantData.to_float(_get_context_value(context, &"target_orientation", target_orientation), target_orientation),
				align_tolerance,
				slow_angle,
				time_to_target
			)
		BehaviorType.SEPARATION:
			return GFSteeringMath.separation(agent, _get_agents(context, &"neighbors"), decay_coefficient, max_distance)
		BehaviorType.COHESION:
			return GFSteeringMath.cohesion(agent, _get_agents(context, &"neighbors"))
		BehaviorType.AVOID_COLLISIONS:
			return GFSteeringMath.avoid_collisions(
				agent,
				_get_agents(context, &"targets"),
				max_prediction_seconds,
				collision_radius,
				minimum_separation
			)
		BehaviorType.PATH_FOLLOW_SEEK:
			var target: Vector3 = GFSteeringMath.path_follow_target(agent, _get_path(context), path_offset)
			return GFSteeringMath.seek(agent, target)
		_:
			return GFSteeringMath.seek(agent, _get_vector3(context, &"target_position", target_position))


## 创建配置副本。
## [br]
## @api public
## [br]
## @return 新行为资源。
func duplicate_behavior() -> Resource:
	var behavior_script: Script = _get_script_value(get_script())
	if behavior_script == null:
		return null

	var raw_behavior: Variant = behavior_script.call("new")
	if not (raw_behavior is Resource):
		return null

	var behavior: Resource = raw_behavior
	behavior.set("behavior_type", behavior_type)
	behavior.set("enabled", enabled)
	behavior.set("weight", weight)
	behavior.set("target_position", target_position)
	behavior.set("target_orientation", target_orientation)
	behavior.set("arrival_radius", arrival_radius)
	behavior.set("slow_radius", slow_radius)
	behavior.set("time_to_target", time_to_target)
	behavior.set("align_tolerance", align_tolerance)
	behavior.set("slow_angle", slow_angle)
	behavior.set("use_z_axis", use_z_axis)
	behavior.set("max_prediction_seconds", max_prediction_seconds)
	behavior.set("decay_coefficient", decay_coefficient)
	behavior.set("max_distance", max_distance)
	behavior.set("collision_radius", collision_radius)
	behavior.set("minimum_separation", minimum_separation)
	behavior.set("path_offset", path_offset)
	return behavior


# --- 私有/辅助方法 ---

## 仅将 Script Variant 转换为 Script，其它类型返回 null。
## [br]
## @api private
## [br]
func _get_script_value(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


## 优先按 String 键读取行为上下文，未找到时再读取 StringName 键。
## [br]
## @api private
## [br]
func _get_context_value(context: Dictionary, key: StringName, fallback: Variant = null) -> Variant:
	var string_key: String = String(key)
	if context.has(string_key):
		return GFVariantData.get_option_value(context, string_key, fallback)
	return GFVariantData.get_option_value(context, key, fallback)


## 读取上下文向量，接受 Vector3 或提升为 z 为零的 Vector2。
## [br]
## @api private
## [br]
func _get_vector3(context: Dictionary, key: StringName, fallback: Vector3) -> Vector3:
	var value: Variant = _get_context_value(context, key, fallback)
	if value is Vector3:
		return value
	if value is Vector2:
		var vector_2: Vector2 = value
		return Vector3(vector_2.x, vector_2.y, 0.0)
	return fallback


## 读取并验证指定上下文值为 GFSteeringAgent。
## [br]
## @api private
## [br]
func _get_agent(context: Dictionary, key: StringName) -> GFSteeringAgent:
	var value: Variant = _get_context_value(context, key)
	if value is GFSteeringAgent:
		var agent: GFSteeringAgent = value
		return agent
	return null


## 从上下文数组筛出所有 GFSteeringAgent 项并保留其相对顺序。
## [br]
## @api private
## [br]
func _get_agents(context: Dictionary, key: StringName) -> Array[GFSteeringAgent]:
	var result: Array[GFSteeringAgent] = []
	var value: Variant = _get_context_value(context, key, [])
	if not (value is Array):
		return result
	var agents: Array = GFVariantData.as_array(value)
	for item: Variant in agents:
		if item is GFSteeringAgent:
			var agent: GFSteeringAgent = item
			result.append(agent)
	return result


## 从 path 数组提取 Vector3 点，并将 Vector2 点提升为 z 为零的 Vector3。
## [br]
## @api private
## [br]
func _get_path(context: Dictionary) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var value: Variant = GFVariantData.get_option_value(context, "path", [])
	if not (value is Array):
		return result
	var path: Array = GFVariantData.as_array(value)
	for item: Variant in path:
		if item is Vector3:
			result.append(item)
		elif item is Vector2:
			var vector_2: Vector2 = item
			result.append(Vector3(vector_2.x, vector_2.y, 0.0))
	return result
