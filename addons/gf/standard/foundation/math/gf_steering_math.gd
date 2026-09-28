## GFSteeringMath: 通用 steering 行为的纯算法集合。
##
## 提供 seek、flee、arrive、pursue、separation、cohesion、blend、priority 等
## 可组合计算，不负责把结果应用到具体 Node、物理体或业务状态。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSteeringMath
extends RefCounted


# --- 常量 ---

## 避免除以近零长度并判定退化方向的容差。
## [br]
## @api private
## [br]
const _EPSILON: float = 0.00001


# --- 公共方法 ---

## 创建加速度结果。
## [br]
## @api public
## [br]
## @param linear: 线性加速度。
## [br]
## @param angular: 角加速度。
## [br]
## @return 新加速度结果。
static func acceleration(linear: Vector3 = Vector3.ZERO, angular: float = 0.0) -> GFSteeringAcceleration:
	return GFSteeringAcceleration.new(linear, angular)


## 计算朝目标点加速的 seek 行为。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param target_position: 目标位置。
## [br]
## @return steering 加速度。
static func seek(agent: GFSteeringAgent, target_position: Vector3) -> GFSteeringAcceleration:
	if agent == null:
		return GFSteeringAcceleration.new()

	var direction: Vector3 = target_position - agent.position
	if direction.length_squared() <= _EPSILON:
		return GFSteeringAcceleration.new()
	return GFSteeringAcceleration.new(direction.normalized() * agent.linear_acceleration_max)


## 计算远离目标点的 flee 行为。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param target_position: 目标位置。
## [br]
## @return steering 加速度。
static func flee(agent: GFSteeringAgent, target_position: Vector3) -> GFSteeringAcceleration:
	if agent == null:
		return GFSteeringAcceleration.new()

	var direction: Vector3 = agent.position - target_position
	if direction.length_squared() <= _EPSILON:
		return GFSteeringAcceleration.new()
	return GFSteeringAcceleration.new(direction.normalized() * agent.linear_acceleration_max)


## 计算抵达目标点并在近处减速的 arrive 行为。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param target_position: 目标位置。
## [br]
## @param arrival_radius: 视为到达的半径。
## [br]
## @param slow_radius: 开始减速的半径。
## [br]
## @param time_to_target: 期望在多少秒内逼近目标速度。
## [br]
## @return steering 加速度。
static func arrive(
	agent: GFSteeringAgent,
	target_position: Vector3,
	arrival_radius: float = 4.0,
	slow_radius: float = 64.0,
	time_to_target: float = 0.1
) -> GFSteeringAcceleration:
	if agent == null:
		return GFSteeringAcceleration.new()

	var direction: Vector3 = target_position - agent.position
	var distance: float = direction.length()
	if distance <= maxf(arrival_radius, 0.0) or distance <= _EPSILON:
		return GFSteeringAcceleration.new(-agent.velocity).clamp_to(agent.linear_acceleration_max)

	var target_speed: float = agent.linear_speed_max
	if distance < maxf(slow_radius, arrival_radius):
		target_speed *= distance / maxf(slow_radius, _EPSILON)

	var desired_velocity: Vector3 = direction.normalized() * target_speed
	var linear: Vector3 = (desired_velocity - agent.velocity) / maxf(time_to_target, _EPSILON)
	return GFSteeringAcceleration.new(linear).clamp_to(agent.linear_acceleration_max)


## 计算追逐移动目标的 pursue 行为。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param target_agent: 目标代理状态。
## [br]
## @param max_prediction_seconds: 最大预测秒数。
## [br]
## @return steering 加速度。
static func pursue(
	agent: GFSteeringAgent,
	target_agent: GFSteeringAgent,
	max_prediction_seconds: float = 1.0
) -> GFSteeringAcceleration:
	if agent == null or target_agent == null:
		return GFSteeringAcceleration.new()

	var prediction: float = _predict_seconds(agent, target_agent, max_prediction_seconds)
	return seek(agent, target_agent.position + target_agent.velocity * prediction)


## 计算逃离移动目标的 evade 行为。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param target_agent: 目标代理状态。
## [br]
## @param max_prediction_seconds: 最大预测秒数。
## [br]
## @return steering 加速度。
static func evade(
	agent: GFSteeringAgent,
	target_agent: GFSteeringAgent,
	max_prediction_seconds: float = 1.0
) -> GFSteeringAcceleration:
	if agent == null or target_agent == null:
		return GFSteeringAcceleration.new()

	var prediction: float = _predict_seconds(agent, target_agent, max_prediction_seconds)
	return flee(agent, target_agent.position + target_agent.velocity * prediction)


## 计算面向目标点的角加速度。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param target_position: 目标位置。
## [br]
## @param use_z_axis: 为 true 时使用 x/z 平面，否则使用 x/y 平面。
## [br]
## @param align_tolerance: 视为对齐的角度阈值。
## [br]
## @param slow_angle: 开始减速的角度。
## [br]
## @param time_to_target: 期望在多少秒内逼近目标角速度。
## [br]
## @return steering 加速度。
static func face(
	agent: GFSteeringAgent,
	target_position: Vector3,
	use_z_axis: bool = false,
	align_tolerance: float = 0.001,
	slow_angle: float = 0.5,
	time_to_target: float = 0.1
) -> GFSteeringAcceleration:
	if agent == null:
		return GFSteeringAcceleration.new()

	var direction: Vector3 = target_position - agent.position
	if direction.length_squared() <= _EPSILON:
		return GFSteeringAcceleration.new()

	return align(
		agent,
		_direction_to_orientation(direction, use_z_axis),
		align_tolerance,
		slow_angle,
		time_to_target
	)


## 计算朝当前速度方向转向的角加速度。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param use_z_axis: 为 true 时使用 x/z 平面，否则使用 x/y 平面。
## [br]
## @param align_tolerance: 视为对齐的角度阈值。
## [br]
## @param slow_angle: 开始减速的角度。
## [br]
## @param time_to_target: 期望在多少秒内逼近目标角速度。
## [br]
## @return steering 加速度。
static func look_where_you_go(
	agent: GFSteeringAgent,
	use_z_axis: bool = false,
	align_tolerance: float = 0.001,
	slow_angle: float = 0.5,
	time_to_target: float = 0.1
) -> GFSteeringAcceleration:
	if agent == null or agent.velocity.length_squared() <= _EPSILON:
		return GFSteeringAcceleration.new()
	return align(
		agent,
		_direction_to_orientation(agent.velocity, use_z_axis),
		align_tolerance,
		slow_angle,
		time_to_target
	)


## 计算对齐指定朝向的角加速度。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param target_orientation: 目标朝向弧度。
## [br]
## @param align_tolerance: 视为对齐的角度阈值。
## [br]
## @param slow_angle: 开始减速的角度。
## [br]
## @param time_to_target: 期望在多少秒内逼近目标角速度。
## [br]
## @return steering 加速度。
static func align(
	agent: GFSteeringAgent,
	target_orientation: float,
	align_tolerance: float = 0.001,
	slow_angle: float = 0.5,
	time_to_target: float = 0.1
) -> GFSteeringAcceleration:
	if agent == null:
		return GFSteeringAcceleration.new()

	var rotation: float = _map_to_pi(target_orientation - agent.orientation)
	var rotation_size: float = absf(rotation)
	if rotation_size <= align_tolerance:
		return GFSteeringAcceleration.new(Vector3.ZERO, -agent.angular_velocity).clamp_to(
			-1.0,
			agent.angular_acceleration_max
		)

	var target_rotation_speed: float = agent.angular_speed_max
	if rotation_size < maxf(slow_angle, align_tolerance):
		target_rotation_speed *= rotation_size / maxf(slow_angle, _EPSILON)
	target_rotation_speed *= signf(rotation)

	var angular: float = (target_rotation_speed - agent.angular_velocity) / maxf(time_to_target, _EPSILON)
	return GFSteeringAcceleration.new(Vector3.ZERO, angular).clamp_to(-1.0, agent.angular_acceleration_max)


## 计算邻居分离行为。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param neighbors: 邻居代理列表。
## [br]
## @param decay_coefficient: 距离衰减系数。
## [br]
## @param max_distance: 最大影响距离；小于等于 0 时使用双方半径之和。
## [br]
## @return steering 加速度。
static func separation(
	agent: GFSteeringAgent,
	neighbors: Array[GFSteeringAgent],
	decay_coefficient: float = 1.0,
	max_distance: float = -1.0
) -> GFSteeringAcceleration:
	if agent == null:
		return GFSteeringAcceleration.new()

	var result: GFSteeringAcceleration = GFSteeringAcceleration.new()
	for neighbor: GFSteeringAgent in neighbors:
		if neighbor == null or neighbor == agent:
			continue

		var direction: Vector3 = agent.position - neighbor.position
		var distance: float = direction.length()
		var effective_distance: float = max_distance
		if effective_distance <= 0.0:
			effective_distance = agent.radius + neighbor.radius
		if distance <= _EPSILON or distance > effective_distance:
			continue

		var strength: float = minf(decay_coefficient / (distance * distance), agent.linear_acceleration_max)
		result.linear += direction.normalized() * strength

	return result.clamp_to(agent.linear_acceleration_max)


## 计算朝邻居中心靠拢的 cohesion 行为。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param neighbors: 邻居代理列表。
## [br]
## @return steering 加速度。
static func cohesion(agent: GFSteeringAgent, neighbors: Array[GFSteeringAgent]) -> GFSteeringAcceleration:
	if agent == null:
		return GFSteeringAcceleration.new()

	var center: Vector3 = Vector3.ZERO
	var count: int = 0
	for neighbor: GFSteeringAgent in neighbors:
		if neighbor == null or neighbor == agent:
			continue
		center += neighbor.position
		count += 1

	if count <= 0:
		return GFSteeringAcceleration.new()
	return seek(agent, center / float(count))


## 混合多个 steering 加速度。
## [br]
## @api public
## [br]
## @param accelerations: 加速度列表。
## [br]
## @param weights: 对应权重；缺失时使用 1。
## [br]
## @param max_linear: 最大线性加速度；小于 0 时不限制。
## [br]
## @param max_angular: 最大角加速度；小于 0 时不限制。
## [br]
## @return 混合后的加速度。
static func blend(
	accelerations: Array[GFSteeringAcceleration],
	weights: Array[float] = [],
	max_linear: float = -1.0,
	max_angular: float = -1.0
) -> GFSteeringAcceleration:
	var result: GFSteeringAcceleration = GFSteeringAcceleration.new()
	for index: int in range(accelerations.size()):
		var acceleration_item: GFSteeringAcceleration = accelerations[index]
		var weight: float = weights[index] if index < weights.size() else 1.0
		result = result.add_scaled(acceleration_item, weight)
	return result.clamp_to(max_linear, max_angular)


## 从多个 steering 加速度中选择第一个超过阈值的结果。
## [br]
## @api public
## [br]
## @param accelerations: 加速度列表。
## [br]
## @param threshold: 非零阈值。
## [br]
## @return 第一个有效加速度；没有时返回零加速度。
static func priority(
	accelerations: Array[GFSteeringAcceleration],
	threshold: float = 0.001
) -> GFSteeringAcceleration:
	for acceleration_item: GFSteeringAcceleration in accelerations:
		if acceleration_item != null and not acceleration_item.is_zero(threshold):
			return acceleration_item.duplicate_acceleration()
	return GFSteeringAcceleration.new()


## 获取半径内的邻居代理。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param candidates: 候选代理列表。
## [br]
## @param radius: 查询半径；小于 0 时使用 agent.radius。
## [br]
## @return 半径内邻居列表。
static func radius_neighbors(
	agent: GFSteeringAgent,
	candidates: Array[GFSteeringAgent],
	radius: float = -1.0
) -> Array[GFSteeringAgent]:
	var result: Array[GFSteeringAgent] = []
	if agent == null:
		return result

	var effective_radius: float = agent.radius if radius < 0.0 else radius
	var radius_squared: float = effective_radius * effective_radius
	for candidate: GFSteeringAgent in candidates:
		if candidate == null or candidate == agent:
			continue
		if agent.position.distance_squared_to(candidate.position) <= radius_squared:
			result.append(candidate)
	return result


## 计算基于未来最近距离的动态碰撞避让行为。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param targets: 需要避让的目标代理列表。
## [br]
## @param max_prediction_seconds: 最大预测秒数；小于等于 0 时只处理当前重叠。
## [br]
## @param collision_radius: 碰撞半径；小于 0 时使用双方半径之和。
## [br]
## @param minimum_separation: 预测最近距离阈值；小于 0 时使用碰撞半径。
## [br]
## @return steering 加速度。
static func avoid_collisions(
	agent: GFSteeringAgent,
	targets: Array[GFSteeringAgent],
	max_prediction_seconds: float = 1.0,
	collision_radius: float = -1.0,
	minimum_separation: float = -1.0
) -> GFSteeringAcceleration:
	if agent == null:
		return GFSteeringAcceleration.new()

	var best_target: GFSteeringAgent = null
	var best_time: float = INF
	var best_current_distance: float = INF
	var best_relative_velocity: Vector3 = Vector3.ZERO
	var prediction_limit: float = maxf(max_prediction_seconds, 0.0)

	for target: GFSteeringAgent in targets:
		if target == null or target == agent:
			continue

		var relative_position: Vector3 = target.position - agent.position
		var current_distance: float = relative_position.length()
		var effective_collision_radius: float = _resolve_collision_radius(agent, target, collision_radius)
		var effective_minimum_separation: float = _resolve_minimum_separation(
			effective_collision_radius,
			minimum_separation
		)

		if current_distance <= effective_collision_radius:
			best_target = target
			best_time = 0.0
			best_current_distance = current_distance
			best_relative_velocity = target.velocity - agent.velocity
			break

		var relative_velocity: Vector3 = target.velocity - agent.velocity
		var relative_speed_squared: float = relative_velocity.length_squared()
		if relative_speed_squared <= _EPSILON:
			continue

		var time_to_closest: float = -relative_position.dot(relative_velocity) / relative_speed_squared
		if time_to_closest <= 0.0:
			continue
		if prediction_limit > 0.0 and time_to_closest > prediction_limit:
			continue
		if prediction_limit <= 0.0:
			continue

		var closest_relative_position: Vector3 = relative_position + relative_velocity * time_to_closest
		var closest_distance: float = closest_relative_position.length()
		if closest_distance > effective_minimum_separation:
			continue
		if time_to_closest >= best_time:
			continue

		best_target = target
		best_time = time_to_closest
		best_current_distance = current_distance
		best_relative_velocity = relative_velocity

	if best_target == null:
		return GFSteeringAcceleration.new()

	var direction: Vector3 = _get_avoidance_direction(
		agent,
		best_target,
		best_time,
		best_current_distance,
		collision_radius,
		best_relative_velocity
	)
	if direction.length_squared() <= _EPSILON:
		return GFSteeringAcceleration.new()
	return GFSteeringAcceleration.new(direction.normalized() * agent.linear_acceleration_max)


## 计算路径跟随的下一个目标点。
## [br]
## @api public
## [br]
## @param agent: 代理状态。
## [br]
## @param path: 路径点列表。
## [br]
## @param path_offset: 沿路径前进的距离。
## [br]
## @return 路径上的目标点；路径为空时返回代理当前位置。
static func path_follow_target(
	agent: GFSteeringAgent,
	path: Array[Vector3],
	path_offset: float = 0.0
) -> Vector3:
	if agent == null or path.is_empty():
		return Vector3.ZERO if agent == null else agent.position
	if path.size() == 1:
		return path[0]

	var closest: _PathProjection = _find_closest_path_projection(agent.position, path)
	return _advance_along_path(path, closest._segment_index, closest._segment_t, path_offset)


# --- 私有/辅助方法 ---

## 按当前距离除以代理速度估算预测时间，并限制在非负最大时长内。
## [br]
## @api private
## [br]
static func _predict_seconds(
	agent: GFSteeringAgent,
	target_agent: GFSteeringAgent,
	max_prediction_seconds: float
) -> float:
	var direction: Vector3 = target_agent.position - agent.position
	var distance: float = direction.length()
	var speed: float = agent.velocity.length()
	if speed <= _EPSILON:
		return maxf(max_prediction_seconds, 0.0)
	return minf(distance / speed, maxf(max_prediction_seconds, 0.0))


## 将 XY 平面方向或 XZ 平面方向转换为对应的 atan2 朝向角。
## [br]
## @api private
## [br]
static func _direction_to_orientation(direction: Vector3, use_z_axis: bool) -> float:
	if use_z_axis:
		return atan2(direction.x, direction.z)
	return atan2(direction.y, direction.x)


## 将角度周期映射到 [-PI, PI) 区间。
## [br]
## @api private
## [br]
static func _map_to_pi(angle: float) -> float:
	var mapped: float = fmod(angle + PI, TAU)
	if mapped < 0.0:
		mapped += TAU
	return mapped - PI


## 将位置投影到每条路径线段并返回最近投影对应的线段索引与插值比例。
## [br]
## @api private
## [br]
static func _find_closest_path_projection(position: Vector3, path: Array[Vector3]) -> _PathProjection:
	var best_distance_squared: float = INF
	var best_segment_index: int = 0
	var best_t: float = 0.0

	for index: int in range(path.size() - 1):
		var start: Vector3 = path[index]
		var end: Vector3 = path[index + 1]
		var segment: Vector3 = end - start
		var length_squared: float = segment.length_squared()
		var t: float = 0.0
		if length_squared > _EPSILON:
			t = clampf((position - start).dot(segment) / length_squared, 0.0, 1.0)
		var projection: Vector3 = start + segment * t
		var distance_squared: float = position.distance_squared_to(projection)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_segment_index = index
			best_t = t

	return _PathProjection.new(best_segment_index, best_t)


## 从线段投影位置沿折线路径前进非负距离，超出末端时停在最后一点。
## [br]
## @api private
## [br]
static func _advance_along_path(
	path: Array[Vector3],
	segment_index: int,
	segment_t: float,
	distance: float
) -> Vector3:
	var index: int = clampi(segment_index, 0, path.size() - 2)
	var current: Vector3 = path[index].lerp(path[index + 1], clampf(segment_t, 0.0, 1.0))
	var remaining: float = maxf(distance, 0.0)

	while remaining > _EPSILON and index < path.size() - 1:
		var end: Vector3 = path[index + 1]
		var segment_remaining: float = current.distance_to(end)
		if remaining <= segment_remaining:
			var direction: Vector3 = (end - current).normalized()
			return current + direction * remaining
		remaining -= segment_remaining
		index += 1
		if index >= path.size() - 1:
			return path[path.size() - 1]
		current = path[index]

	return current


## 使用显式非负碰撞半径，或将两个代理的非负半径相加。
## [br]
## @api private
## [br]
static func _resolve_collision_radius(
	agent: GFSteeringAgent,
	target: GFSteeringAgent,
	collision_radius: float
) -> float:
	if collision_radius >= 0.0:
		return collision_radius
	return maxf(agent.radius, 0.0) + maxf(target.radius, 0.0)


## 用碰撞半径替代负分离距离，否则返回两者较大值。
## [br]
## @api private
## [br]
static func _resolve_minimum_separation(collision_radius: float, minimum_separation: float) -> float:
	if minimum_separation < 0.0:
		return collision_radius
	return maxf(minimum_separation, collision_radius)


## 按即时位置差、预测位置差和速度垂线的顺序选择避让方向。
## [br]
## @api private
## [br]
static func _get_avoidance_direction(
	agent: GFSteeringAgent,
	target: GFSteeringAgent,
	time_to_collision: float,
	current_distance: float,
	collision_radius: float,
	relative_velocity: Vector3
) -> Vector3:
	var effective_collision_radius: float = _resolve_collision_radius(agent, target, collision_radius)
	if time_to_collision <= _EPSILON or current_distance <= effective_collision_radius:
		var immediate_direction: Vector3 = agent.position - target.position
		if immediate_direction.length_squared() > _EPSILON:
			return immediate_direction

	var future_agent_position: Vector3 = agent.position + agent.velocity * time_to_collision
	var future_target_position: Vector3 = target.position + target.velocity * time_to_collision
	var future_direction: Vector3 = future_agent_position - future_target_position
	if future_direction.length_squared() > _EPSILON:
		return future_direction
	if relative_velocity.length_squared() > _EPSILON:
		return _get_perpendicular_direction(relative_velocity)
	if agent.velocity.length_squared() > _EPSILON:
		return _get_perpendicular_direction(agent.velocity)
	return Vector3.ZERO


## 依次尝试与 FORWARD、UP 和 RIGHT 的叉积，取得非退化垂直方向。
## [br]
## @api private
## [br]
static func _get_perpendicular_direction(direction: Vector3) -> Vector3:
	var perpendicular: Vector3 = direction.cross(Vector3.FORWARD)
	if perpendicular.length_squared() > _EPSILON:
		return perpendicular
	perpendicular = direction.cross(Vector3.UP)
	if perpendicular.length_squared() > _EPSILON:
		return perpendicular
	return direction.cross(Vector3.RIGHT)


# --- 内部类 ---

## 保存最近路径投影对应的线段索引和线段内插值比例。
## [br]
## @api private
## [br]
class _PathProjection:
	# --- 私有变量 ---

	## 最近投影命中的路径线段起点索引。
	## [br]
	## @api private
	var _segment_index: int = 0

	## 命中点在线段内的插值比例，后续沿路径推进从此位置开始。
	## [br]
	## @api private
	var _segment_t: float = 0.0

	# --- Godot 生命周期方法 ---

	func _init(p_segment_index: int = 0, p_segment_t: float = 0.0) -> void:
		_segment_index = p_segment_index
		_segment_t = p_segment_t
