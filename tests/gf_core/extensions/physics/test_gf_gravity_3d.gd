## 测试通用 3D 重力场与采样器。
extends GutTest


# --- 常量 ---

const GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT = preload("res://addons/gf/standard/common/gf_object_candidate_registry.gd")


# --- 辅助类 ---

class CandidateProvider extends RefCounted:
	var candidates: Array = []
	var received_options: Dictionary = {}

	func get_candidate_objects(options: Dictionary) -> Array:
		received_options = options
		return candidates


class CountingField extends Node3D:
	var call_count: int = 0
	var acceleration_value: Vector3 = Vector3.DOWN
	var priority_value: Variant = 0

	func get_acceleration_at(_world_position: Vector3) -> Vector3:
		call_count += 1
		return acceleration_value

	func get_gravity_priority() -> Variant:
		return priority_value


class AppendingField extends Node3D:
	var source_fields: Array = []
	var appended_field: Object = null
	var has_appended: bool = false

	func get_acceleration_at(_world_position: Vector3) -> Vector3:
		if not has_appended:
			has_appended = true
			source_fields.append(appended_field)
		return Vector3.RIGHT


class ExtraRequiredArgumentField extends Node3D:
	var call_count: int = 0

	func get_acceleration_at(_world_position: Vector3, _scale: float) -> Vector3:
		call_count += 1
		return Vector3.LEFT * 100.0


class OptionalArgumentField extends Node3D:
	var call_count: int = 0

	func get_acceleration_at(_world_position: Vector3, p_scale: float = 2.0) -> Vector3:
		call_count += 1
		return Vector3.RIGHT * p_scale


# --- 测试方法 ---

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


func test_gravity_probe_cache_accounts_for_same_frame_field_parameters() -> void:
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
	var changed: Vector3 = probe.sample()

	assert_almost_eq(first.y, -4.0, 0.001, "首次采样应读取当前力场。")
	assert_almost_eq(changed.y, -8.0, 0.001, "同帧修改力场参数应使缓存失效。")


func test_gravity_probe_cache_accounts_for_same_curve_content_mutation() -> void:
	var curve: Curve = Curve.new()
	var _first_point_index: int = curve.add_point(Vector2(0.0, 1.0))
	var _second_point_index: int = curve.add_point(Vector2(1.0, 1.0))
	var field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(field)
	add_child_autofree(probe)
	field.acceleration = 8.0
	field.radius = 10.0
	field.falloff_mode = GFGravityField3D.FalloffMode.CURVE
	field.falloff_curve = curve
	probe.global_position = Vector3(5.0, 0.0, 0.0)
	probe.use_fallback_when_empty = false

	var first: Vector3 = probe.sample()
	curve.set_point_value(0, 0.25)
	curve.set_point_value(1, 0.25)
	var changed: Vector3 = probe.sample()

	assert_almost_eq(first.x, -8.0, 0.001, "首次采样应读取曲线当前内容。")
	assert_almost_eq(changed.x, -2.0, 0.001, "同帧原位修改 Curve 内容应使缓存失效。")


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


func test_gravity_probe_cache_ignores_non_field_group_members() -> void:
	var field: CountingField = CountingField.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(field)
	add_child_autofree(probe)
	field.add_to_group(probe.field_group)
	probe.use_fallback_when_empty = false

	var first: Vector3 = probe.sample()
	var unrelated_node: Node3D = Node3D.new()
	add_child_autofree(unrelated_node)
	unrelated_node.add_to_group(probe.field_group)
	var cached: Vector3 = probe.sample()

	assert_eq(first, Vector3.DOWN, "有效 field 应正常参与首次采样。")
	assert_eq(cached, Vector3.DOWN, "非 field 分组成员不应改变采样值。")
	assert_eq(field.call_count, 1, "非 field 分组成员不应使同帧缓存失效。")


func test_gravity_probe_sample_fields_ignores_freed_objects() -> void:
	var field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(probe)
	field.free()
	probe.use_fallback_when_empty = false

	var acceleration: Vector3 = probe.sample_fields([field, "not_a_field", null])

	assert_eq(acceleration, Vector3.ZERO, "sample_fields 应跳过已释放对象引用和非对象输入。")


func test_gravity_probe_provider_ignores_freed_candidates() -> void:
	var provider: CandidateProvider = CandidateProvider.new()
	var field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(probe)
	field.free()
	provider.candidates = [field]
	probe.use_fallback_when_empty = false

	var acceleration: Vector3 = probe.sample_field_provider(provider)

	assert_eq(acceleration, Vector3.ZERO, "provider 返回的已释放候选必须被安全跳过。")


func test_gravity_probe_provider_preserves_nested_option_identity() -> void:
	var provider: CandidateProvider = CandidateProvider.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	var nested_options: Dictionary = {"predicate_state": [1, 2, 3]}
	var options: Dictionary = {"nested": nested_options}
	add_child_autofree(probe)

	var _sample: Vector3 = probe.sample_field_provider(provider, options)

	assert_true(
		is_same(provider.received_options.get("nested"), nested_options),
		"透传 provider options 时只应复制顶层容器，不应无界深拷贝任意嵌套值。"
	)
	assert_false(options.has("method_name"), "框架补默认查询条件时不得修改调用方 options。")


func test_gravity_probe_samples_a_snapshot_when_callback_mutates_candidate_array() -> void:
	var field: AppendingField = AppendingField.new()
	var appended_field: CountingField = CountingField.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	var fields: Array = [field]
	add_child_autofree(field)
	add_child_autofree(appended_field)
	add_child_autofree(probe)
	field.source_fields = fields
	field.appended_field = appended_field
	appended_field.acceleration_value = Vector3.DOWN * 10.0
	probe.use_fallback_when_empty = false

	var acceleration: Vector3 = probe.sample_fields(fields)

	assert_eq(acceleration, Vector3.RIGHT, "回调新增候选只能从下一次采样开始生效。")


func test_gravity_probe_validates_required_and_default_method_arity() -> void:
	var invalid_field: ExtraRequiredArgumentField = ExtraRequiredArgumentField.new()
	var optional_field: OptionalArgumentField = OptionalArgumentField.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(invalid_field)
	add_child_autofree(optional_field)
	add_child_autofree(probe)
	probe.use_fallback_when_empty = false

	var acceleration: Vector3 = probe.sample_fields([invalid_field, optional_field])

	assert_eq(invalid_field.call_count, 0, "存在第二个必填参数的方法不得通过 duck-typed 调用检查。")
	assert_eq(optional_field.call_count, 1, "第二个参数有默认值时应允许只传世界坐标。")
	assert_eq(acceleration, Vector3.RIGHT * 2.0, "合法默认参数方法应正常参与采样。")


func test_gravity_probe_rejects_non_finite_field_acceleration() -> void:
	var field: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(field)
	add_child_autofree(probe)
	field.direction_mode = GFGravityField3D.DirectionMode.CONSTANT_DIRECTION
	field.constant_direction = Vector3(NAN, 0.0, 0.0)
	field.acceleration = INF
	probe.use_fallback_when_empty = false

	var acceleration: Vector3 = probe.sample_fields([field])

	assert_eq(acceleration, Vector3.ZERO, "非有限力场参数不应进入采样结果。")


func test_gravity_field_normalizes_invalid_enum_state() -> void:
	var field: GFGravityField3D = GFGravityField3D.new()
	add_child_autofree(field)

	field.set(&"direction_mode", 999)
	field.set(&"falloff_mode", -100)

	assert_eq(
		field.direction_mode,
		GFGravityField3D.DirectionMode.TOWARD_ORIGIN,
		"非法方向枚举必须归一到稳定默认值。"
	)
	assert_eq(
		field.falloff_mode,
		GFGravityField3D.FalloffMode.CONSTANT,
		"非法衰减枚举必须归一到稳定默认值。"
	)


func test_gravity_probe_normalizes_non_finite_duck_priority() -> void:
	var invalid_priority_field: CountingField = CountingField.new()
	var finite_priority_field: CountingField = CountingField.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(invalid_priority_field)
	add_child_autofree(finite_priority_field)
	add_child_autofree(probe)
	invalid_priority_field.acceleration_value = Vector3.RIGHT * 9.0
	invalid_priority_field.priority_value = INF
	finite_priority_field.acceleration_value = Vector3.UP * 3.0
	finite_priority_field.priority_value = 1.0
	probe.combination_mode = GFGravityProbe3D.CombinationMode.HIGHEST_PRIORITY
	probe.use_fallback_when_empty = false

	var acceleration: Vector3 = probe.sample_fields([invalid_priority_field, finite_priority_field])

	assert_eq(acceleration, Vector3.UP * 3.0, "非有限 duck priority 应归一为零，不得污染优先级比较。")


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


func test_gravity_probe_samples_field_provider_candidates() -> void:
	var registry: RefCounted = GF_OBJECT_CANDIDATE_REGISTRY_SCRIPT.new()
	var field_a: GFGravityField3D = GFGravityField3D.new()
	var field_b: GFGravityField3D = GFGravityField3D.new()
	var probe: GFGravityProbe3D = GFGravityProbe3D.new()
	add_child_autofree(field_a)
	add_child_autofree(field_b)
	add_child_autofree(probe)
	_configure_constant_field(field_a, Vector3.DOWN, 3.0)
	_configure_constant_field(field_b, Vector3.RIGHT, 4.0)

	assert_true(GFVariantData.to_bool(registry.call("register_candidate", field_a, { "group": &"gravity" })))
	assert_true(GFVariantData.to_bool(registry.call("register_candidate", field_b, { "group": &"gravity" })))

	var acceleration: Vector3 = probe.sample_field_provider(registry, { "group": &"gravity" })

	assert_almost_eq(acceleration.y, -3.0, 0.001, "provider 候选 field_a 应参与采样。")
	assert_almost_eq(acceleration.x, 4.0, 0.001, "provider 候选 field_b 应参与采样。")


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
