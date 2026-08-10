## 测试 GFHeightfield3D 的高度/法线采样和 GFSurfaceScatterSampler3D 的纯数据散布报告。
extends GutTest


# --- 测试 ---

func test_heightfield_samples_world_height_and_normal() -> void:
	var heightfield: GFHeightfield3D = _make_gradient_heightfield()

	assert_true(heightfield.is_valid(), "有效样本应生成可采样高度场。")
	assert_eq(heightfield.get_grid_size(), Vector2i(2, 2), "高度场应保留网格尺寸。")
	assert_eq(heightfield.get_sample_count(), 4, "高度场应保留样本数量。")
	assert_eq(heightfield.sample_cell(Vector2i(1, 1), -1.0), 30.0, "整数格点应读取行优先样本。")
	assert_true(absf(heightfield.sample_world(5.0, 5.0, -1.0) - 15.0) <= 0.001, "世界中心应双线性插值。")
	assert_eq(heightfield.world_to_grid(10.0, 10.0), Vector2(1.0, 1.0), "世界最大边界应映射到末端格点。")
	assert_eq(heightfield.grid_to_world(Vector2(0.5, 0.5), 15.0), Vector3(5.0, 15.0, 5.0), "连续格点应能还原世界坐标。")
	assert_eq(heightfield.get_min_height(-1.0), 0.0, "最小高度应来自样本。")
	assert_eq(heightfield.get_max_height(-1.0), 30.0, "最大高度应来自样本。")

	var normal: Vector3 = heightfield.sample_normal_world(5.0, 5.0)
	assert_true(normal.length() > 0.999, "采样法线应归一化。")
	assert_true(normal.y > 0.0, "高度场法线应朝向上方半球。")


func test_heightfield_samples_slope_with_shared_normal_metric() -> void:
	var flat_heightfield: GFHeightfield3D = _make_flat_heightfield()
	var gradient_heightfield: GFHeightfield3D = _make_gradient_heightfield()
	var low_scale_slope: float = gradient_heightfield.sample_slope_world(5.0, 5.0, 0.25)
	var high_scale_slope: float = gradient_heightfield.sample_slope_world(5.0, 5.0, 2.0)
	var grid_slope: float = gradient_heightfield.sample_slope_grid(Vector2(0.5, 0.5), 1.0)
	var world_slope: float = gradient_heightfield.sample_slope_world(5.0, 5.0, 1.0)

	assert_true(absf(GFHeightfield3D.normal_to_slope(Vector3.UP)) <= 0.001, "朝上法线应映射为平面坡度。")
	assert_true(absf(GFHeightfield3D.normal_to_slope(Vector3.RIGHT) - 1.0) <= 0.001, "水平法线应映射为最大坡度。")
	assert_true(absf(GFHeightfield3D.normal_to_slope(Vector3.ZERO) - 1.0) <= 0.001, "无效法线应按保守坡度处理。")
	assert_true(absf(flat_heightfield.sample_slope_world(5.0, 5.0)) <= 0.001, "平面高度场坡度应接近 0。")
	assert_true(low_scale_slope > 0.0, "斜面高度场应产生非零坡度。")
	assert_true(high_scale_slope > low_scale_slope, "更大的 vertical_scale 应产生更高坡度。")
	assert_true(absf(grid_slope - world_slope) <= 0.001, "网格和世界坡度采样应共享语义。")
	assert_true(absf(gradient_heightfield.sample_slope_world(99.0, 99.0) - 1.0) <= 0.001, "无效世界坐标应按保守坡度处理。")


func test_heightfield_rejects_invalid_configuration_without_overwriting_previous_data() -> void:
	var heightfield: GFHeightfield3D = _make_gradient_heightfield()
	var invalid_samples: PackedFloat32Array = PackedFloat32Array([1.0, 2.0, 3.0])

	assert_false(
		heightfield.configure(Vector2i(2, 2), invalid_samples, Vector2.ZERO, Vector2(1.0, 1.0)),
		"样本数量不匹配时配置应失败。"
	)
	assert_true(heightfield.is_valid(), "失败配置不应清空已有有效数据。")
	assert_eq(heightfield.get_sample_count(), 4, "失败配置不应覆盖原样本。")
	assert_eq(heightfield.sample_cell(Vector2i(1, 1), -1.0), 30.0, "失败配置后仍应可读取旧数据。")


func test_heightfield_decodes_terrain_rgb_height() -> void:
	var sea_level: float = GFHeightfield3D.decode_terrain_rgb_height(Color8(1, 134, 160))
	var ten_meters: float = GFHeightfield3D.decode_terrain_rgb_height(_terrain_rgb_color_for_height(10.0))

	assert_true(absf(sea_level) <= 0.001, "Terrain-RGB 标准海平面颜色应解码为 0 米。")
	assert_true(absf(ten_meters - 10.0) <= 0.001, "Terrain-RGB 编码应能还原米制高度。")


func test_heightfield_builds_from_terrain_rgb_image() -> void:
	var image: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, _terrain_rgb_color_for_height(0.0))
	image.set_pixel(1, 0, _terrain_rgb_color_for_height(10.0))
	image.set_pixel(0, 1, _terrain_rgb_color_for_height(20.0))
	image.set_pixel(1, 1, _terrain_rgb_color_for_height(30.0))

	var report: Dictionary = GFHeightfield3D.samples_from_terrain_rgb_image(image)
	var heightfield: GFHeightfield3D = GFHeightfield3D.from_terrain_rgb_image(
		image,
		Vector2.ZERO,
		Vector2(10.0, 10.0)
	)

	var grid_size_value: Variant = GFVariantData.get_option_value(report, "grid_size", Vector2i.ZERO)
	var report_grid_size: Vector2i = Vector2i.ZERO
	if grid_size_value is Vector2i:
		var narrowed_grid_size: Vector2i = grid_size_value
		report_grid_size = narrowed_grid_size

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效 Terrain-RGB 图像应生成样本报告。")
	assert_eq(report_grid_size, Vector2i(2, 2), "报告应保留图像尺寸。")
	assert_eq(GFVariantData.get_option_int(report, "sample_count"), 4, "报告应保留样本数量。")
	assert_true(absf(GFVariantData.get_option_float(report, "min_height") - 0.0) <= 0.001, "报告应记录最小高度。")
	assert_true(absf(GFVariantData.get_option_float(report, "max_height") - 30.0) <= 0.001, "报告应记录最大高度。")
	assert_true(heightfield.is_valid(), "有效 Terrain-RGB 图像应创建可采样高度场。")
	assert_true(absf(heightfield.sample_cell(Vector2i(1, 1), -1.0) - 30.0) <= 0.001, "整数格点应读取解码样本。")
	assert_true(absf(heightfield.sample_world(5.0, 5.0, -1.0) - 15.0) <= 0.001, "世界中心应对解码样本双线性插值。")


func test_heightfield_terrain_rgb_options_and_invalid_image_do_not_overwrite() -> void:
	var heightfield: GFHeightfield3D = _make_gradient_heightfield()
	var invalid_image: Image = Image.new()

	assert_false(
		heightfield.configure_from_terrain_rgb_image(invalid_image, Vector2.ZERO, Vector2.ONE),
		"空图像不应配置高度场。"
	)
	assert_eq(heightfield.sample_cell(Vector2i(1, 1), -1.0), 30.0, "空图像不应覆盖已有样本。")

	var image: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, _terrain_rgb_color_for_height(10.0))

	assert_true(
		heightfield.configure_from_terrain_rgb_image(
			image,
			Vector2.ZERO,
			Vector2.ONE,
			{ "height_scale": 2.0, "height_offset": -5.0 }
		),
		"有效图像和线性变换选项应能配置高度场。"
	)
	assert_true(absf(heightfield.sample_cell(Vector2i.ZERO, -1.0) - 15.0) <= 0.001, "scale 与 offset 应作用于解码高度。")


func test_heightfield_terrain_rgb_rejects_non_finite_derived_samples() -> void:
	var image: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, _terrain_rgb_color_for_height(10.0))

	var report: Dictionary = GFHeightfield3D.samples_from_terrain_rgb_image(
		image,
		{ "height_scale": 1.0e308 }
	)
	var samples_value: Variant = GFVariantData.get_option_value(report, "samples", PackedFloat32Array())
	var samples: PackedFloat32Array = PackedFloat32Array()
	if samples_value is PackedFloat32Array:
		samples = samples_value

	assert_false(GFVariantData.get_option_bool(report, "ok"), "有限输入的乘加结果溢出时必须失败。")
	assert_true(samples.is_empty(), "失败报告不得保留非有限或部分样本。")


func test_scatter_heightfield_is_deterministic_and_returns_transforms() -> void:
	var heightfield: GFHeightfield3D = _make_flat_heightfield()
	var options: Dictionary = {
		"seed": 42,
		"max_attempt_multiplier": 1,
		"yaw_min": 0.0,
		"yaw_max": 0.0,
		"scale_min": 1.0,
		"scale_max": 1.0,
		"align_to_normal": true,
	}
	var first_report: Dictionary = GFSurfaceScatterSampler3D.sample_heightfield(
		heightfield,
		Rect2(Vector2.ZERO, Vector2(10.0, 10.0)),
		4,
		options
	)
	var second_report: Dictionary = GFSurfaceScatterSampler3D.sample_heightfield(
		heightfield,
		Rect2(Vector2.ZERO, Vector2(10.0, 10.0)),
		4,
		options
	)
	var first_transforms: Array = GFVariantData.get_option_array(first_report, "transforms")
	var second_transforms: Array = GFVariantData.get_option_array(second_report, "transforms")

	assert_true(GFVariantData.get_option_bool(first_report, "ok"), "有效高度场散布应成功。")
	assert_eq(GFVariantData.get_option_int(first_report, "accepted_count"), 4, "平面高度场应接受目标数量。")
	assert_eq(first_transforms.size(), 4, "报告应包含 Transform 数组。")
	assert_eq(
		_packed_vector3_array_size(GFVariantData.get_option_value(first_report, "points", PackedVector3Array())),
		4,
		"报告应包含采样点数组。"
	)

	for index: int in range(first_transforms.size()):
		var first_transform: Transform3D = _transform_at(first_transforms, index)
		var second_transform: Transform3D = _transform_at(second_transforms, index)
		assert_eq(first_transform.origin, second_transform.origin, "相同 seed 应生成稳定位置。")
		assert_true(first_transform.basis.y.normalized().dot(Vector3.UP) > 0.999, "平面散布的 Y 轴应对齐上法线。")


func test_scatter_attempt_budget_is_checked_before_multiplication() -> void:
	var report: Dictionary = GFSurfaceScatterSampler3D.sample(
		Rect2(Vector2.ZERO, Vector2.ONE),
		2,
		func(_world_x: float, _world_z: float) -> float:
			return 0.0,
		Callable(),
		{
			"max_attempt_multiplier": 9_223_372_036_854_775_807,
			"max_random_attempts": 4,
		}
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "合法绝对上限应约束乘法前的尝试数。")
	assert_eq(GFVariantData.get_option_int(report, "max_attempts"), 4)
	assert_eq(GFVariantData.get_option_int(report, "accepted_count"), 2)
	assert_eq(GFVariantData.get_option_int(report, "attempt_count"), 2)


func test_surface_scatter_report_has_json_compatible_export() -> void:
	var report: Dictionary = GFSurfaceScatterSampler3D.sample_points(
		PackedVector2Array([Vector2(1.0, 2.0)]),
		func(world_x: float, world_z: float) -> float:
			return world_x + world_z,
		func(_world_x: float, _world_z: float, _vertical_scale: float) -> Vector3:
			return Vector3.UP,
		{
			"seed": 5,
			"yaw_min": 0.0,
			"yaw_max": 0.0,
			"scale_min": 1.0,
			"scale_max": 1.0,
		}
	)
	var safe_report: Dictionary = GFSurfaceScatterSampler3D.to_json_compatible_report(report)
	var json_text: String = JSON.stringify(safe_report)

	assert_false(json_text.is_empty(), "JSON-safe SurfaceScatter 报告应可序列化。")
	assert_false(json_text.contains(":null"), "JSON-safe SurfaceScatter 报告不应依赖 JSON.stringify 降级非法值。")


func test_scatter_points_supports_custom_providers_and_caps_results() -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(1.0, 1.0),
		Vector2(2.0, 2.0),
		Vector2(3.0, 3.0),
	])
	var report: Dictionary = GFSurfaceScatterSampler3D.sample_points(
		points,
		func(world_x: float, world_z: float) -> float:
			return world_x + world_z,
		func(_world_x: float, _world_z: float, _vertical_scale: float) -> Vector3:
			return Vector3.UP,
		{
			"seed": 7,
			"max_points": 2,
			"yaw_min": 0.0,
			"yaw_max": 0.0,
			"scale_min": 2.0,
			"scale_max": 2.0,
			"y_offset": 1.0,
			"align_to_normal": false,
		}
	)
	var transforms: Array = GFVariantData.get_option_array(report, "transforms")
	var first_transform: Transform3D = _transform_at(transforms, 0)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效候选点散布应成功。")
	assert_eq(GFVariantData.get_option_int(report, "target_count"), 2, "max_points 应限制目标数量。")
	assert_eq(GFVariantData.get_option_int(report, "accepted_count"), 2, "前两个候选点应被接受。")
	assert_eq(first_transform.origin, Vector3(1.0, 3.0, 1.0), "高度和 y_offset 应写入 Transform 原点。")
	assert_true(absf(first_transform.basis.x.length() - 2.0) <= 0.001, "scale 选项应缩放 Transform basis。")


func test_scatter_points_supports_vector3_scale_and_axis_lock() -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(1.0, 1.0),
	])
	var fixed_report: Dictionary = GFSurfaceScatterSampler3D.sample_points(
		points,
		func(_world_x: float, _world_z: float) -> float:
			return 0.0,
		func(_world_x: float, _world_z: float, _vertical_scale: float) -> Vector3:
			return Vector3.UP,
		{
			"seed": 3,
			"scale_min": Vector3(1.0, 2.0, 3.0),
			"scale_max": Vector3(1.0, 2.0, 3.0),
			"scale_axis_mode": "free",
			"yaw_min": 0.0,
			"yaw_max": 0.0,
			"align_to_normal": false,
		}
	)
	var locked_report: Dictionary = GFSurfaceScatterSampler3D.sample_points(
		points,
		func(_world_x: float, _world_z: float) -> float:
			return 0.0,
		func(_world_x: float, _world_z: float, _vertical_scale: float) -> Vector3:
			return Vector3.UP,
		{
			"seed": 5,
			"scale_min": Vector3.ONE,
			"scale_max": Vector3(2.0, 2.0, 2.0),
			"scale_axis_mode": "lock_xy",
			"yaw_min": 0.0,
			"yaw_max": 0.0,
			"align_to_normal": false,
		}
	)
	var fixed_transform: Transform3D = _transform_at(GFVariantData.get_option_array(fixed_report, "transforms"), 0)
	var locked_transform: Transform3D = _transform_at(GFVariantData.get_option_array(locked_report, "transforms"), 0)

	assert_true(GFVariantData.get_option_bool(fixed_report, "ok"), "Vector3 缩放散布应成功。")
	assert_true(absf(fixed_transform.basis.x.length() - 1.0) <= 0.001, "Vector3 scale_min/max 应写入 X 轴缩放。")
	assert_true(absf(fixed_transform.basis.y.length() - 2.0) <= 0.001, "Vector3 scale_min/max 应写入 Y 轴缩放。")
	assert_true(absf(fixed_transform.basis.z.length() - 3.0) <= 0.001, "Vector3 scale_min/max 应写入 Z 轴缩放。")
	assert_true(GFVariantData.get_option_bool(locked_report, "ok"), "轴锁缩放散布应成功。")
	assert_true(absf(locked_transform.basis.x.length() - locked_transform.basis.y.length()) <= 0.001, "lock_xy 应让 X/Y 使用相同缩放权重。")


func test_scatter_reports_height_and_slope_rejections() -> void:
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(1.0, 1.0),
		Vector2(2.0, 2.0),
		Vector2(3.0, 3.0),
	])
	var slope_report: Dictionary = GFSurfaceScatterSampler3D.sample_points(
		points,
		func(_world_x: float, _world_z: float) -> float:
			return 0.0,
		func(_world_x: float, _world_z: float, _vertical_scale: float) -> Vector3:
			return Vector3.UP,
		{ "slope_min": 0.5 }
	)
	var height_report: Dictionary = GFSurfaceScatterSampler3D.sample_points(
		points,
		func(_world_x: float, _world_z: float) -> float:
			return NAN,
		Callable()
	)

	assert_eq(GFVariantData.get_option_int(slope_report, "accepted_count"), 0, "坡度不满足时不应产生 Transform。")
	assert_eq(GFVariantData.get_option_int(slope_report, "rejected_slope_count"), 3, "坡度拒绝数量应进入报告。")
	assert_eq(GFVariantData.get_option_int(height_report, "rejected_height_count"), 3, "无效高度应进入高度拒绝报告。")
	assert_true(GFVariantData.get_option_bool(height_report, "exhausted_attempts"), "候选耗尽且未满足目标时应标记 exhausted。")


# --- 私有/辅助方法 ---

func _make_gradient_heightfield() -> GFHeightfield3D:
	return GFHeightfield3D.from_samples(
		Vector2i(2, 2),
		PackedFloat32Array([0.0, 10.0, 20.0, 30.0]),
		Vector2.ZERO,
		Vector2(10.0, 10.0)
	)


func _make_flat_heightfield() -> GFHeightfield3D:
	return GFHeightfield3D.from_samples(
		Vector2i(2, 2),
		PackedFloat32Array([0.0, 0.0, 0.0, 0.0]),
		Vector2.ZERO,
		Vector2(10.0, 10.0)
	)


func _terrain_rgb_color_for_height(height: float) -> Color:
	var encoded_height: int = clampi(roundi((height + 10000.0) / 0.1), 0, 16777215)
	var red: int = clampi(floori(float(encoded_height) / 65536.0), 0, 255)
	var green: int = clampi(floori(float(encoded_height - red * 65536) / 256.0), 0, 255)
	var blue: int = clampi(encoded_height - red * 65536 - green * 256, 0, 255)
	return Color8(red, green, blue)


func _transform_at(values: Array, index: int) -> Transform3D:
	if index < 0 or index >= values.size():
		return Transform3D.IDENTITY

	var value: Variant = values[index]
	if value is Transform3D:
		var transform: Transform3D = value
		return transform
	return Transform3D.IDENTITY


func _packed_vector3_array_size(value: Variant) -> int:
	if value is PackedVector3Array:
		var points: PackedVector3Array = value
		return points.size()
	return 0
