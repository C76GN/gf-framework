## 测试 GFSteeringMath 的通用 steering 计算。
extends GutTest


func test_seek_and_flee_use_agent_acceleration_limit() -> void:
	var agent: GFSteeringAgent = GFSteeringAgent.new(Vector3.ZERO)
	agent.linear_acceleration_max = 10.0

	var seek: GFSteeringAcceleration = GFSteeringMath.seek(
		agent,
		Vector3.RIGHT * 100.0
	)
	var flee: GFSteeringAcceleration = GFSteeringMath.flee(
		agent,
		Vector3.RIGHT * 100.0
	)

	assert_almost_eq(
		seek.linear.length(),
		10.0,
		0.001
	)
	assert_almost_eq(
		seek.linear.x,
		10.0,
		0.001
	)
	assert_almost_eq(
		flee.linear.x,
		-10.0,
		0.001
	)


func test_arrive_slows_inside_slow_radius() -> void:
	var agent: GFSteeringAgent = GFSteeringAgent.new(Vector3.ZERO, Vector3.ZERO)
	agent.linear_speed_max = 100.0
	agent.linear_acceleration_max = 1000.0

	var far: GFSteeringAcceleration = GFSteeringMath.arrive(
		agent,
		Vector3(
			100.0,
			0.0,
			0.0
		),
		1.0,
		50.0,
		1.0
	)
	var near: GFSteeringAcceleration = GFSteeringMath.arrive(
		agent,
		Vector3(
			10.0,
			0.0,
			0.0
		),
		1.0,
		50.0,
		1.0
	)

	assert_gt(
		far.linear.length(),
		near.linear.length(),
		"远处应请求更高目标速度。"
	)
	assert_gt(
		near.linear.length(),
		0.0,
		"减速半径内仍应继续靠近目标。"
	)


func test_blend_and_priority_combine_accelerations() -> void:
	var first: GFSteeringAcceleration = GFSteeringAcceleration.new(Vector3.RIGHT * 2.0)
	var second: GFSteeringAcceleration = GFSteeringAcceleration.new(Vector3.UP * 4.0)
	var accelerations: Array[GFSteeringAcceleration] = [first, second]
	var weights: Array[float] = [1.0, 0.5]

	var blended: GFSteeringAcceleration = GFSteeringMath.blend(
		accelerations,
		weights,
		10.0
	)
	assert_eq(
		blended.linear,
		Vector3(
			2.0,
			2.0,
			0.0
		)
	)

	var priority_candidates: Array[GFSteeringAcceleration] = [GFSteeringAcceleration.new(), second,]
	var priority: GFSteeringAcceleration = GFSteeringMath.priority(priority_candidates)
	assert_eq(priority.linear, second.linear)
	assert_ne(
		priority,
		second,
		"priority 应返回副本，避免调用方误改原对象。"
	)


func test_separation_and_cohesion_use_neighbor_positions() -> void:
	var agent: GFSteeringAgent = GFSteeringAgent.new(Vector3.ZERO)
	agent.linear_acceleration_max = 100.0
	var left: GFSteeringAgent = GFSteeringAgent.new(Vector3.LEFT * 2.0)
	var right_far: GFSteeringAgent = GFSteeringAgent.new(Vector3.RIGHT * 20.0)
	var neighbors: Array[GFSteeringAgent] = [left, right_far]

	var separation: GFSteeringAcceleration = GFSteeringMath.separation(
		agent,
		neighbors,
		100.0,
		5.0
	)
	assert_gt(
		separation.linear.x,
		0.0,
		"左侧近邻应把代理推向右侧。"
	)

	var cohesion: GFSteeringAcceleration = GFSteeringMath.cohesion(agent, neighbors)
	assert_gt(
		cohesion.linear.x,
		0.0,
		"邻居中心在右侧时 cohesion 应朝右。"
	)


func test_align_brakes_angular_velocity_without_affecting_linear_velocity() -> void:
	var agent: GFSteeringAgent = GFSteeringAgent.new(
		Vector3.ZERO,
		Vector3.RIGHT * 20.0
	)
	agent.orientation = 1.0
	agent.angular_velocity = 2.0
	agent.angular_acceleration_max = 10.0

	var result: GFSteeringAcceleration = GFSteeringMath.align(agent, 1.0)

	assert_eq(
		result.linear,
		Vector3.ZERO,
		"对齐朝向时不应让 steering 层隐式刹停线速度。"
	)
	assert_almost_eq(
		result.angular,
		-2.0,
		0.001,
		"对齐朝向时仍可请求角速度刹停。"
	)


func test_radius_neighbors_and_path_follow_target() -> void:
	var agent: GFSteeringAgent = GFSteeringAgent.new(Vector3.ZERO)
	var near: GFSteeringAgent = GFSteeringAgent.new(
		Vector3(
			3.0,
			0.0,
			0.0
		)
	)
	var far: GFSteeringAgent = GFSteeringAgent.new(
		Vector3(
			10.0,
			0.0,
			0.0
		)
	)
	var candidates: Array[GFSteeringAgent] = [near, far]

	var neighbors: Array[GFSteeringAgent] = GFSteeringMath.radius_neighbors(
		agent,
		candidates,
		5.0
	)
	assert_eq(
		neighbors,
		[near]
	)

	var path_points: Array[Vector3] = [
		Vector3.ZERO,
		Vector3(
			10.0,
			0.0,
			0.0
		),
		Vector3(
			10.0,
			10.0,
			0.0
		),
	]
	var target: Vector3 = GFSteeringMath.path_follow_target(
		GFSteeringAgent.new(
			Vector3(
				2.0,
				1.0,
				0.0
			)
		),
		path_points,
		3.0
	)
	assert_eq(
		target,
		Vector3(
			5.0,
			0.0,
			0.0
		)
	)


func test_avoid_collisions_predicts_future_overlap() -> void:
	var agent: GFSteeringAgent = GFSteeringAgent.new(
		Vector3(
			-10.0,
			0.0,
			0.0
		),
		Vector3.RIGHT * 10.0
	)
	agent.radius = 1.0
	agent.linear_acceleration_max = 20.0
	var target: GFSteeringAgent = GFSteeringAgent.new(
		Vector3(
			10.0,
			0.0,
			0.0
		),
		Vector3.LEFT * 10.0
	)
	target.radius = 1.0
	var targets: Array[GFSteeringAgent] = [target]

	var avoidance: GFSteeringAcceleration = GFSteeringMath.avoid_collisions(
		agent,
		targets,
		2.0,
		-1.0,
		3.0
	)

	assert_almost_eq(
		avoidance.linear.length(),
		20.0,
		0.001,
		"预测到未来碰撞时应使用最大加速度避让。"
	)
	assert_gt(
		absf(avoidance.linear.y),
		0.0,
		"完全迎面相遇时应选择侧向避让方向。"
	)


func test_avoid_collisions_ignores_non_threatening_targets() -> void:
	var agent: GFSteeringAgent = GFSteeringAgent.new(
		Vector3.ZERO,
		Vector3.RIGHT * 10.0
	)
	var target: GFSteeringAgent = GFSteeringAgent.new(
		Vector3.RIGHT * 50.0,
		Vector3.RIGHT * 10.0
	)
	var targets: Array[GFSteeringAgent] = [target]

	var avoidance: GFSteeringAcceleration = GFSteeringMath.avoid_collisions(
		agent,
		targets,
		1.0
	)

	assert_true(
		avoidance.is_zero(),
		"相对速度不会缩短距离时不应产生避让。"
	)


func test_steering_behavior_resource_uses_context_target() -> void:
	var agent: GFSteeringAgent = GFSteeringAgent.new(Vector3.ZERO)
	agent.linear_acceleration_max = 12.0
	var behavior: GFSteeringBehaviorResource = GFSteeringBehaviorResource.new()
	behavior.behavior_type = GFSteeringBehaviorResource.BehaviorType.SEEK

	var acceleration: GFSteeringAcceleration = behavior.calculate(
		agent,
		{ "target_position": Vector3.RIGHT * 40.0 }
	)

	assert_almost_eq(
		acceleration.linear.x,
		12.0,
		0.001,
		"资源化 seek 应复用 GFSteeringMath 的加速度上限。"
	)


func test_steering_behavior_stack_blends_weighted_behaviors() -> void:
	var agent: GFSteeringAgent = GFSteeringAgent.new(Vector3.ZERO)
	agent.linear_acceleration_max = 10.0
	var seek_right: GFSteeringBehaviorResource = GFSteeringBehaviorResource.new()
	seek_right.behavior_type = GFSteeringBehaviorResource.BehaviorType.SEEK
	seek_right.target_position = Vector3.RIGHT
	var seek_up: GFSteeringBehaviorResource = GFSteeringBehaviorResource.new()
	seek_up.behavior_type = GFSteeringBehaviorResource.BehaviorType.SEEK
	seek_up.target_position = Vector3.UP
	seek_up.weight = 0.5
	var stack: GFSteeringBehaviorStack = GFSteeringBehaviorStack.new()
	stack.max_linear = 100.0
	var _add_behavior_result_152: Variant = stack.add_behavior(seek_right)
	var _add_behavior_result_153: Variant = stack.add_behavior(seek_up)

	var acceleration: GFSteeringAcceleration = stack.calculate(agent)

	assert_eq(
		acceleration.linear,
		Vector3(
			10.0,
			5.0,
			0.0
		),
		"BLEND 模式应按行为权重混合结果。"
	)
