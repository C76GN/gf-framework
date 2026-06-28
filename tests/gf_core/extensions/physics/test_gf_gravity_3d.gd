## 测试通用 3D 重力场与采样器。
extends GutTest


func test_point_gravity_field_returns_acceleration_toward_origin() -> void:
	var field: GFGravityField3D = GFGravityField3D.new()
	add_child_autofree(field)
	field.global_position = Vector3.ZERO
	field.acceleration = 10.0

	var acceleration: Vector3 = field.get_acceleration_at(Vector3(0.0, 5.0, 0.0))

	assert_almost_eq(acceleration.y, -10.0, 0.001, "点重力应朝向力场原点。")
	assert_almost_eq(acceleration.x, 0.0, 0.001)


func test_gravity_field_linear_falloff_respects_radius() -> void:
	var field: GFGravityField3D = GFGravityField3D.new()
	add_child_autofree(field)
	field.acceleration = 10.0
	field.radius = 10.0
	field.falloff_mode = GFGravityField3D.FalloffMode.LINEAR

	assert_almost_eq(field.get_strength_at_distance(5.0), 5.0, 0.001, "线性衰减应按距离占比降低强度。")
	assert_almost_eq(field.get_strength_at_distance(11.0), 0.0, 0.001, "半径外应无力场强度。")
	assert_almost_eq(field.get_strength_at_distance(-5.0), 10.0, 0.001, "负距离应按零距离处理。")


func test_gravity_field_exposes_sampling_priority() -> void:
	var field: GFGravityField3D = GFGravityField3D.new()
	add_child_autofree(field)

	field.priority = 7

	assert_eq(field.get_gravity_priority(), 7, "力场应暴露稳定的采样优先级。")


func test_gravity_probe_sums_group_fields() -> void:
	var field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(field)
	add_child_autofree(probe)
	field.direction_mode = GFGravityField3D.DirectionMode.CONSTANT_DIRECTION
	field.constant_direction = Vector3.DOWN
	field.acceleration = 4.0
	probe.use_fallback_when_empty = false

	var acceleration: Vector3 = probe.sample()

	assert_almost_eq(acceleration.y, -4.0, 0.001, "采样器应汇总分组中的力场。")
	assert_eq(probe.get_up_direction(), Vector3.UP, "向上方向应与加速度方向相反。")


func test_gravity_probe_direction_resamples_after_movement() -> void:
	var field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(field)
	add_child_autofree(probe)
	field.global_position = Vector3.ZERO
	field.acceleration = 10.0
	probe.use_fallback_when_empty = false
	probe.global_position = Vector3(1.0, 0.0, 0.0)
	var first_direction: Vector3 = probe.get_down_direction()

	probe.global_position = Vector3(-1.0, 0.0, 0.0)
	var moved_direction: Vector3 = probe.get_down_direction()

	assert_almost_eq(first_direction.x, -1.0, 0.001, "初始方向应朝向力场。")
	assert_almost_eq(moved_direction.x, 1.0, 0.001, "移动后方向 helper 应重新采样当前位置。")


func test_gravity_probe_strongest_mode_selects_largest_acceleration() -> void:
	var weak_field: GFGravityField3D = GFGravityField3D.new()
	var strong_field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(weak_field)
	add_child_autofree(strong_field)
	add_child_autofree(probe)
	_configure_constant_field(weak_field, Vector3.DOWN, 2.0)
	_configure_constant_field(strong_field, Vector3.RIGHT, 5.0)
	probe.use_fallback_when_empty = false
	probe.combination_mode = GFGravityProbe3D.CombinationMode.STRONGEST

	var acceleration: Vector3 = probe.sample_fields([weak_field, strong_field])

	assert_almost_eq(acceleration.x, 5.0, 0.001, "最强模式应选择长度最大的加速度。")
	assert_almost_eq(acceleration.y, 0.0, 0.001)


func test_gravity_probe_highest_priority_mode_combines_active_top_priority_fields() -> void:
	var inactive_high_field: GFGravityField3D = GFGravityField3D.new()
	var low_field: GFGravityField3D = GFGravityField3D.new()
	var high_field: GFGravityField3D = GFGravityField3D.new()
	var high_tie_field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(inactive_high_field)
	add_child_autofree(low_field)
	add_child_autofree(high_field)
	add_child_autofree(high_tie_field)
	add_child_autofree(probe)
	_configure_constant_field(inactive_high_field, Vector3.LEFT, 99.0, 99)
	_configure_constant_field(low_field, Vector3.DOWN, 10.0, 0)
	_configure_constant_field(high_field, Vector3.RIGHT, 2.0, 5)
	_configure_constant_field(high_tie_field, Vector3.UP, 3.0, 5)
	inactive_high_field.global_position = Vector3(100.0, 0.0, 0.0)
	inactive_high_field.radius = 1.0
	probe.use_fallback_when_empty = false
	probe.combination_mode = GFGravityProbe3D.CombinationMode.HIGHEST_PRIORITY

	var acceleration: Vector3 = probe.sample_fields([
		inactive_high_field,
		low_field,
		high_field,
		high_tie_field,
	])

	assert_almost_eq(acceleration.x, 2.0, 0.001, "最高优先级模式应汇总最高优先级的有效力场。")
	assert_almost_eq(acceleration.y, 3.0, 0.001, "同优先级有效力场应被组合。")


func test_gravity_probe_cache_accounts_for_combination_mode() -> void:
	var weak_field: GFGravityField3D = GFGravityField3D.new()
	var strong_field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(weak_field)
	add_child_autofree(strong_field)
	add_child_autofree(probe)
	_configure_constant_field(weak_field, Vector3.DOWN, 2.0)
	_configure_constant_field(strong_field, Vector3.RIGHT, 5.0)
	probe.use_fallback_when_empty = false

	var summed: Vector3 = probe.sample()
	probe.combination_mode = GFGravityProbe3D.CombinationMode.STRONGEST
	var strongest: Vector3 = probe.sample()

	assert_almost_eq(summed.x, 5.0, 0.001, "默认模式仍应求和。")
	assert_almost_eq(summed.y, -2.0, 0.001)
	assert_almost_eq(strongest.x, 5.0, 0.001, "组合模式变化应使同帧缓存失效。")
	assert_almost_eq(strongest.y, 0.0, 0.001)


func test_gravity_probe_cache_accounts_for_fallback_configuration() -> void:
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(probe)
	probe.field_group = &""
	probe.use_fallback_when_empty = true
	probe.fallback_acceleration = Vector3.DOWN * 4.0

	var first: Vector3 = probe.sample()
	probe.fallback_acceleration = Vector3.RIGHT * 3.0
	var changed_acceleration: Vector3 = probe.sample()
	probe.use_fallback_when_empty = false
	var disabled_fallback: Vector3 = probe.sample()

	assert_eq(first, Vector3.DOWN * 4.0, "首次采样应使用当前 fallback 加速度。")
	assert_eq(changed_acceleration, Vector3.RIGHT * 3.0, "同帧修改 fallback 向量应使缓存失效。")
	assert_eq(disabled_fallback, Vector3.ZERO, "同帧关闭 fallback 应使缓存失效。")


func test_gravity_probe_reuses_same_frame_sample_cache() -> void:
	var field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(field)
	add_child_autofree(probe)
	field.direction_mode = GFGravityField3D.DirectionMode.CONSTANT_DIRECTION
	field.constant_direction = Vector3.DOWN
	field.acceleration = 4.0
	probe.use_fallback_when_empty = false

	var first: Vector3 = probe.sample()
	field.acceleration = 8.0
	var cached: Vector3 = probe.sample()
	probe.cache_samples_per_frame = false
	var uncached: Vector3 = probe.sample()

	assert_almost_eq(first.y, -4.0, 0.001, "首次采样应读取当前力场。")
	assert_almost_eq(cached.y, -4.0, 0.001, "同一帧重复采样应复用缓存。")
	assert_almost_eq(uncached.y, -8.0, 0.001, "关闭缓存后应重新读取力场。")


func test_gravity_probe_cache_accounts_for_same_frame_group_membership() -> void:
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(probe)
	probe.use_fallback_when_empty = false

	var empty_sample: Vector3 = probe.sample()
	var field: GFGravityField3D = GFGravityField3D.new()
	_configure_constant_field(field, Vector3.DOWN, 6.0)
	add_child_autofree(field)
	var field_sample: Vector3 = probe.sample()

	assert_eq(empty_sample, Vector3.ZERO, "首次采样没有力场时应返回零向量。")
	assert_almost_eq(field_sample.y, -6.0, 0.001, "同帧新增力场应使缓存失效并参与采样。")


func test_gravity_probe_sample_fields_ignores_freed_objects() -> void:
	var field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(probe)
	field.free()
	probe.use_fallback_when_empty = false

	var acceleration: Vector3 = probe.sample_fields([field])

	assert_eq(acceleration, Vector3.ZERO, "sample_fields 应跳过已释放对象引用。")


func test_gravity_probe_cache_uses_private_sample_value() -> void:
	var field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(field)
	add_child_autofree(probe)
	field.direction_mode = GFGravityField3D.DirectionMode.CONSTANT_DIRECTION
	field.constant_direction = Vector3.DOWN
	field.acceleration = 4.0
	probe.use_fallback_when_empty = false

	var first: Vector3 = probe.sample()
	probe.last_acceleration = Vector3.RIGHT * 99.0
	var cached: Vector3 = probe.sample()

	assert_almost_eq(first.y, -4.0, 0.001, "首次采样应读取当前力场。")
	assert_almost_eq(cached.y, -4.0, 0.001, "外部写 last_acceleration 不应污染同帧缓存值。")


func _configure_constant_field(
	field: GFGravityField3D,
	direction: Vector3,
	acceleration: float,
	priority: int = 0
) -> void:
	field.direction_mode = GFGravityField3D.DirectionMode.CONSTANT_DIRECTION
	field.constant_direction = direction
	field.acceleration = acceleration
	field.priority = priority
