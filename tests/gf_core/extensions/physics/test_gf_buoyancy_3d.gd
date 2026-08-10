## 测试浮力纯数学与可扩展点采样场。
extends GutTest

# --- 常量 ---

const GF_BUOYANCY_MATH_3D_SCRIPT = preload("res://addons/gf/extensions/physics/core/gf_buoyancy_math_3d.gd")
const GF_BUOYANCY_FIELD_3D_SCRIPT = preload("res://addons/gf/extensions/physics/nodes/gf_buoyancy_field_3d.gd")


# --- 测试方法 ---

func test_submersion_ratio_uses_centered_immersion_range() -> void:
	assert_almost_eq(GF_BUOYANCY_MATH_3D_SCRIPT.calculate_submersion_ratio(-2.0, 2.0), 0.0, 0.0001, "探针高于表面一个半径时应完全离水。")
	assert_almost_eq(GF_BUOYANCY_MATH_3D_SCRIPT.calculate_submersion_ratio(0.0, 2.0), 0.5, 0.0001, "探针中心位于表面时应半浸没。")
	assert_almost_eq(GF_BUOYANCY_MATH_3D_SCRIPT.calculate_submersion_ratio(2.0, 2.0), 1.0, 0.0001, "探针低于表面一个半径时应完全浸没。")
	assert_eq(GF_BUOYANCY_MATH_3D_SCRIPT.calculate_submersion_ratio(1.0, 0.0), 0.0, "无效浸没半径应失败关闭。")


func test_submersion_ratio_preserves_endpoints_at_large_finite_scale() -> void:
	var immersion_radius: float = 1.0e308

	assert_eq(
		GF_BUOYANCY_MATH_3D_SCRIPT.calculate_submersion_ratio(immersion_radius, immersion_radius),
		1.0,
		"完全浸没端点不应因 2 * radius 的中间溢出退化为半浸没。"
	)
	assert_eq(
		GF_BUOYANCY_MATH_3D_SCRIPT.calculate_submersion_ratio(-immersion_radius, immersion_radius),
		0.0,
		"完全离水端点不应因 2 * radius 的中间溢出退化为半浸没。"
	)
	assert_eq(
		GF_BUOYANCY_MATH_3D_SCRIPT.calculate_submersion_ratio(0.0, immersion_radius),
		0.5,
		"半浸没中点应与数值尺度无关。"
	)


func test_buoyancy_force_opposes_gravity_and_scales_with_displacement() -> void:
	var force: Vector3 = GF_BUOYANCY_MATH_3D_SCRIPT.calculate_buoyancy_force(
		Vector3.DOWN * 10.0,
		1000.0,
		0.002,
		0.5
	)

	assert_almost_eq(force.y, 10.0, 0.0001, "半浸没排水点应按密度、体积和重力产生反向浮力。")
	assert_almost_eq(force.x, 0.0, 0.0001)


func test_drag_force_uses_relative_fluid_velocity() -> void:
	var force: Vector3 = GF_BUOYANCY_MATH_3D_SCRIPT.calculate_point_force(
		Vector3.ZERO,
		Vector3.RIGHT * 3.0,
		Vector3.RIGHT,
		1000.0,
		1.0,
		0.5,
		3.0,
		0.5
	)

	assert_almost_eq(force.x, -4.0, 0.0001, "阻力应只响应物体相对流体的速度。")


func test_buoyancy_math_rejects_non_finite_calculation_results() -> void:
	var buoyancy_force: Vector3 = GF_BUOYANCY_MATH_3D_SCRIPT.calculate_buoyancy_force(
		Vector3.DOWN * 1.0e200,
		1.0e200,
		1.0,
		1.0
	)
	var drag_force: Vector3 = GF_BUOYANCY_MATH_3D_SCRIPT.calculate_drag_force(
		Vector3.RIGHT * 1.0e200,
		1.0,
		1.0,
		1.0
	)
	var combined_force: Vector3 = GF_BUOYANCY_MATH_3D_SCRIPT.calculate_point_force(
		Vector3.DOWN * 9.0e153,
		Vector3.DOWN,
		Vector3.ZERO,
		1.0e154,
		1.0,
		1.0,
		9.0e307,
		0.0
	)

	assert_eq(buoyancy_force, Vector3.ZERO, "有限输入乘法溢出时浮力应失败关闭。")
	assert_eq(drag_force, Vector3.ZERO, "有限速度的长度溢出时阻力应失败关闭。")
	assert_eq(combined_force, Vector3.ZERO, "两个有限分量相加溢出时总力应失败关闭。")


func test_default_field_samples_local_y_plane_without_applying_body_force() -> void:
	var field: GF_BUOYANCY_FIELD_3D_SCRIPT = GF_BUOYANCY_FIELD_3D_SCRIPT.new()
	add_child_autofree(field)
	field.fluid_density = 1000.0
	field.linear_drag_coefficient = 2.0
	field.fluid_velocity = Vector3.RIGHT

	var sample: Dictionary = field.sample_point(
		Vector3.ZERO,
		Vector3.RIGHT * 3.0,
		0.002,
		1.0,
		Vector3.DOWN * 10.0
	)
	var buoyancy_force: Vector3 = _get_vector3(sample, "buoyancy_force")
	var drag_force: Vector3 = _get_vector3(sample, "drag_force")

	assert_true(GFVariantData.get_option_bool(sample, "available"), "默认平面场应可采样。")
	assert_true(GFVariantData.get_option_bool(sample, "active"), "表面中心点应处于半浸没状态。")
	assert_almost_eq(GFVariantData.get_option_float(sample, "submersion_ratio"), 0.5, 0.0001)
	assert_almost_eq(buoyancy_force.y, 10.0, 0.0001, "采样应返回浮力分量。")
	assert_almost_eq(drag_force.x, -2.0, 0.0001, "采样应使用相对流速计算阻力分量。")
	assert_false(sample.has("body"), "浮力场结果不应持有或修改业务刚体。")


func test_field_fails_closed_when_finite_force_components_overflow_in_sum() -> void:
	var field: GF_BUOYANCY_FIELD_3D_SCRIPT = GF_BUOYANCY_FIELD_3D_SCRIPT.new()
	add_child_autofree(field)
	field.fluid_density = 1.0e19
	field.linear_drag_coefficient = 2.0e38

	var sample: Dictionary = field.sample_point(
		Vector3.DOWN,
		Vector3.DOWN,
		1.0,
		1.0,
		Vector3.DOWN * 2.0e19
	)
	var buoyancy_force: Vector3 = _get_vector3(sample, "buoyancy_force")
	var drag_force: Vector3 = _get_vector3(sample, "drag_force")
	var total_force: Vector3 = _get_vector3(sample, "force")

	assert_true(GFVariantData.get_option_bool(sample, "available"), "几何和输入有效时采样仍应可用。")
	assert_true(_is_finite_vector3(buoyancy_force), "单独浮力分量应保持有限。")
	assert_true(_is_finite_vector3(drag_force), "单独阻力分量应保持有限。")
	assert_false(buoyancy_force.is_zero_approx(), "夹具必须实际产生非零浮力分量。")
	assert_false(drag_force.is_zero_approx(), "夹具必须实际产生非零阻力分量。")
	assert_eq(total_force, Vector3.ZERO, "两个有限分量相加溢出时总力应失败关闭。")


func test_field_surface_follows_node_transform() -> void:
	var field: GF_BUOYANCY_FIELD_3D_SCRIPT = GF_BUOYANCY_FIELD_3D_SCRIPT.new()
	add_child_autofree(field)
	field.global_position = Vector3(0.0, 5.0, 0.0)
	field.surface_offset = 1.0

	assert_almost_eq(field.get_signed_depth_at(Vector3(0.0, 5.0, 0.0)), 1.0, 0.0001, "表面偏移应在节点局部空间解释。")
	assert_almost_eq(field.get_signed_depth_at(Vector3(0.0, 7.0, 0.0)), -1.0, 0.0001, "表面上方应返回负深度。")


func test_field_supports_custom_surface_without_changing_force_contract() -> void:
	var field: ConstantDepthField = ConstantDepthField.new()
	add_child_autofree(field)
	field.sampled_depth = 2.0

	var sample: Dictionary = field.sample_point(
		Vector3(100.0, 200.0, 300.0),
		Vector3.ZERO,
		0.001,
		2.0,
		Vector3.DOWN * 10.0
	)

	assert_almost_eq(GFVariantData.get_option_float(sample, "submersion_ratio"), 1.0, 0.0001, "自定义表面钩子应复用统一浸没与力计算。")
	assert_eq(GFVariantData.get_option_string_name(sample, "reason"), &"", "有效自定义表面不应产生失败原因。")


func test_field_rejects_invalid_sampling_inputs() -> void:
	var field: GF_BUOYANCY_FIELD_3D_SCRIPT = GF_BUOYANCY_FIELD_3D_SCRIPT.new()
	add_child_autofree(field)

	var sample: Dictionary = field.sample_point(
		Vector3(NAN, 0.0, 0.0),
		Vector3.ZERO,
		1.0,
		1.0,
		Vector3.DOWN
	)

	assert_false(GFVariantData.get_option_bool(sample, "available"), "非有限采样输入应失败关闭。")
	assert_eq(GFVariantData.get_option_string_name(sample, "reason"), &"invalid_input", "失败原因应稳定。")
	assert_eq(_get_vector3(sample, "force"), Vector3.ZERO, "失败采样不得产生力。")
	assert_eq(field.get_surface_normal_at(Vector3(NAN, 0.0, 0.0)), Vector3.UP, "直接法线查询也应拒绝非有限位置。")
	assert_eq(field.get_fluid_velocity_at(Vector3(NAN, 0.0, 0.0)), Vector3.ZERO, "直接流速查询也应拒绝非有限位置。")


# --- 私有/辅助方法 ---

func _get_vector3(data: Dictionary, key: String) -> Vector3:
	var value: Variant = GFVariantData.get_option_value(data, key, Vector3.ZERO)
	if value is Vector3:
		var vector_value: Vector3 = value
		return vector_value
	return Vector3.ZERO


func _is_finite_vector3(value: Vector3) -> bool:
	return (
		not is_nan(value.x)
		and not is_inf(value.x)
		and not is_nan(value.y)
		and not is_inf(value.y)
		and not is_nan(value.z)
		and not is_inf(value.z)
	)


# --- 内部类 ---

class ConstantDepthField extends GF_BUOYANCY_FIELD_3D_SCRIPT:
	var sampled_depth: float = 0.0

	func _get_signed_depth_at(_world_position: Vector3) -> float:
		return sampled_depth
