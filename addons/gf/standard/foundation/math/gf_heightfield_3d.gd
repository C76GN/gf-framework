## GFHeightfield3D: 通用 X/Z 平面高度场采样数据。
##
## 保存一组行优先高度样本，并提供世界坐标到网格坐标转换、双线性高度采样、
## 法线估算和诊断快照。它只处理纯数据，不创建地形节点、碰撞体、材质或渲染资源。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFHeightfield3D
extends RefCounted


# --- 常量 ---

const _MIN_WORLD_SPAN: float = 0.000001


# --- 私有变量 ---

var _grid_size: Vector2i = Vector2i.ZERO
var _world_min: Vector2 = Vector2.ZERO
var _world_max: Vector2 = Vector2.ONE
var _height_samples: PackedFloat32Array = PackedFloat32Array()


# --- Godot 生命周期方法 ---

func _init(
	p_grid_size: Vector2i = Vector2i.ZERO,
	p_height_samples: PackedFloat32Array = PackedFloat32Array(),
	p_world_min: Vector2 = Vector2.ZERO,
	p_world_max: Vector2 = Vector2.ONE
) -> void:
	if p_grid_size.x > 0 or p_grid_size.y > 0 or not p_height_samples.is_empty():
		var _configured: bool = configure(p_grid_size, p_height_samples, p_world_min, p_world_max)


# --- 公共方法 ---

## 从样本创建高度场。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param grid_size: 高度网格尺寸，x 为世界 X 轴样本数，y 为世界 Z 轴样本数。
## [br]
## @param height_samples: 行优先高度样本，数量必须等于 grid_size.x * grid_size.y。
## [br]
## @param world_min: 高度场覆盖的最小 X/Z 世界坐标。
## [br]
## @param world_max: 高度场覆盖的最大 X/Z 世界坐标。
## [br]
## @return 新高度场实例；输入无效时返回未配置实例。
static func from_samples(
	grid_size: Vector2i,
	height_samples: PackedFloat32Array,
	world_min: Vector2 = Vector2.ZERO,
	world_max: Vector2 = Vector2.ONE
) -> GFHeightfield3D:
	var heightfield: GFHeightfield3D = GFHeightfield3D.new()
	var _configured: bool = heightfield.configure(grid_size, height_samples, world_min, world_max)
	return heightfield


## 从 Terrain-RGB 图像创建高度场。
##
## Terrain-RGB 使用 RGB 三通道编码米制高度：-10000 + (R * 65536 + G * 256 + B) * 0.1。
## 该方法只读取 Image 像素并生成高度样本，不加载网络瓦片、创建网格或绑定地图服务。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param image: Terrain-RGB 图像。
## [br]
## @param world_min: 高度场覆盖的最小 X/Z 世界坐标。
## [br]
## @param world_max: 高度场覆盖的最大 X/Z 世界坐标。
## [br]
## @param options: 可选项，支持 height_scale 和 height_offset。
## [br]
## @return 新高度场实例；输入无效时返回未配置实例。
## [br]
## @schema options: Dictionary，可包含 height_scale 和 height_offset，用于在解码米制高度后进行线性变换。
static func from_terrain_rgb_image(
	image: Image,
	world_min: Vector2 = Vector2.ZERO,
	world_max: Vector2 = Vector2.ONE,
	options: Dictionary = {}
) -> GFHeightfield3D:
	var heightfield: GFHeightfield3D = GFHeightfield3D.new()
	var _configured: bool = heightfield.configure_from_terrain_rgb_image(image, world_min, world_max, options)
	return heightfield


## 解码 Terrain-RGB 像素高度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param color: Terrain-RGB 像素颜色。
## [br]
## @return 解码后的米制高度。
static func decode_terrain_rgb_height(color: Color) -> float:
	var red: int = _color_channel_to_byte(color.r)
	var green: int = _color_channel_to_byte(color.g)
	var blue: int = _color_channel_to_byte(color.b)
	return -10000.0 + float(red * 65536 + green * 256 + blue) * 0.1


## 将表面法线转换为归一化坡度。
##
## 返回值范围为 0.0 到 1.0；0.0 表示朝上的平面，1.0 表示垂直、倒置或无效法线。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param normal: 表面法线。
## [br]
## @return 归一化坡度。
static func normal_to_slope(normal: Vector3) -> float:
	if not _is_finite_vector3(normal) or normal.length_squared() <= _MIN_WORLD_SPAN:
		return 1.0

	var up_dot: float = clampf(normal.normalized().dot(Vector3.UP), -1.0, 1.0)
	return clampf(1.0 - up_dot, 0.0, 1.0)


## 从 Terrain-RGB 图像生成行优先高度样本报告。
##
## 报告中的 grid_size.x 对应图像宽度，grid_size.y 对应图像高度；samples 使用行优先顺序。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param image: Terrain-RGB 图像。
## [br]
## @param options: 可选项，支持 height_scale 和 height_offset。
## [br]
## @return 样本生成报告。
## [br]
## @schema options: Dictionary，可包含 height_scale 和 height_offset，用于在解码米制高度后进行线性变换。
## [br]
## @schema return: Dictionary，包含 ok、grid_size、samples、sample_count、min_height、max_height、issues、counts 与 summary 字段。
static func samples_from_terrain_rgb_image(image: Image, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_terrain_rgb_samples_report()
	if image == null or image.get_width() <= 0 or image.get_height() <= 0:
		_append_terrain_rgb_issue(report, "invalid_image", "image must have positive width and height.")
		return _finalize_terrain_rgb_samples_report(report)

	var height_scale: float = GFVariantData.get_option_float(options, "height_scale", 1.0)
	var height_offset: float = GFVariantData.get_option_float(options, "height_offset", 0.0)
	if not _is_finite_float(height_scale):
		_append_terrain_rgb_issue(report, "invalid_height_scale", "height_scale must be finite.")
	if not _is_finite_float(height_offset):
		_append_terrain_rgb_issue(report, "invalid_height_offset", "height_offset must be finite.")
	if not GFVariantData.get_option_array(report, "issues").is_empty():
		return _finalize_terrain_rgb_samples_report(report)

	var width: int = image.get_width()
	var height: int = image.get_height()
	var samples: PackedFloat32Array = PackedFloat32Array()
	var _resize_result: int = samples.resize(width * height)
	var min_height: float = 0.0
	var max_height: float = 0.0
	var has_sample: bool = false

	for y: int in range(height):
		for x: int in range(width):
			var sample_index: int = y * width + x
			var height_value: float = decode_terrain_rgb_height(image.get_pixel(x, y)) * height_scale + height_offset
			samples[sample_index] = height_value
			if not has_sample:
				min_height = height_value
				max_height = height_value
				has_sample = true
			else:
				min_height = minf(min_height, height_value)
				max_height = maxf(max_height, height_value)

	report["grid_size"] = Vector2i(width, height)
	report["samples"] = samples
	report["sample_count"] = samples.size()
	report["min_height"] = min_height
	report["max_height"] = max_height
	return _finalize_terrain_rgb_samples_report(report)


## 配置高度场数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param grid_size: 高度网格尺寸，x 为世界 X 轴样本数，y 为世界 Z 轴样本数。
## [br]
## @param height_samples: 行优先高度样本，数量必须等于 grid_size.x * grid_size.y。
## [br]
## @param world_min: 高度场覆盖的最小 X/Z 世界坐标。
## [br]
## @param world_max: 高度场覆盖的最大 X/Z 世界坐标。
## [br]
## @return 输入有效并已应用时返回 true；无效输入不会覆盖现有数据。
func configure(
	grid_size: Vector2i,
	height_samples: PackedFloat32Array,
	world_min: Vector2 = Vector2.ZERO,
	world_max: Vector2 = Vector2.ONE
) -> bool:
	if not _can_configure(grid_size, height_samples, world_min, world_max):
		return false

	_grid_size = grid_size
	_world_min = world_min
	_world_max = world_max
	_height_samples = _copy_float_samples(height_samples)
	return true


## 使用 Terrain-RGB 图像配置高度场。
##
## 输入无效时不会覆盖现有数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param image: Terrain-RGB 图像。
## [br]
## @param world_min: 高度场覆盖的最小 X/Z 世界坐标。
## [br]
## @param world_max: 高度场覆盖的最大 X/Z 世界坐标。
## [br]
## @param options: 可选项，支持 height_scale 和 height_offset。
## [br]
## @return 输入有效并已应用时返回 true；无效输入不会覆盖现有数据。
## [br]
## @schema options: Dictionary，可包含 height_scale 和 height_offset，用于在解码米制高度后进行线性变换。
func configure_from_terrain_rgb_image(
	image: Image,
	world_min: Vector2 = Vector2.ZERO,
	world_max: Vector2 = Vector2.ONE,
	options: Dictionary = {}
) -> bool:
	var report: Dictionary = samples_from_terrain_rgb_image(image, options)
	if not GFVariantData.get_option_bool(report, "ok"):
		return false

	var grid_size_value: Variant = GFVariantData.get_option_value(report, "grid_size", Vector2i.ZERO)
	var samples_value: Variant = GFVariantData.get_option_value(report, "samples", PackedFloat32Array())
	if not (grid_size_value is Vector2i) or not (samples_value is PackedFloat32Array):
		return false

	var grid_size: Vector2i = grid_size_value
	var samples: PackedFloat32Array = samples_value
	return configure(grid_size, samples, world_min, world_max)


## 清空高度场数据。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_grid_size = Vector2i.ZERO
	_world_min = Vector2.ZERO
	_world_max = Vector2.ONE
	_height_samples = PackedFloat32Array()


## 判断当前高度场是否可采样。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 高度场尺寸、范围和样本数量有效时返回 true。
func is_valid() -> bool:
	return _can_configure(_grid_size, _height_samples, _world_min, _world_max)


## 获取高度网格尺寸。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 网格尺寸，x 对应世界 X，y 对应世界 Z。
func get_grid_size() -> Vector2i:
	return _grid_size


## 获取高度场最小 X/Z 世界坐标。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 最小 X/Z 世界坐标。
func get_world_min() -> Vector2:
	return _world_min


## 获取高度场最大 X/Z 世界坐标。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 最大 X/Z 世界坐标。
func get_world_max() -> Vector2:
	return _world_max


## 获取高度场覆盖的 X/Z 世界矩形。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 世界矩形。
func get_world_rect() -> Rect2:
	return Rect2(_world_min, _world_max - _world_min)


## 获取高度样本副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 行优先高度样本副本。
func get_height_samples() -> PackedFloat32Array:
	return _copy_float_samples(_height_samples)


## 获取样本数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前样本数量。
func get_sample_count() -> int:
	return _height_samples.size()


## 判断 X/Z 世界坐标是否位于高度场范围内。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param world_x: 世界 X 坐标。
## [br]
## @param world_z: 世界 Z 坐标。
## [br]
## @return 坐标位于高度场范围内时返回 true。
func contains_world_xz(world_x: float, world_z: float) -> bool:
	if not is_valid() or not _is_finite_float(world_x) or not _is_finite_float(world_z):
		return false
	return (
		world_x >= _world_min.x
		and world_x <= _world_max.x
		and world_z >= _world_min.y
		and world_z <= _world_max.y
	)


## 判断 3D 世界坐标的 X/Z 是否位于高度场范围内。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param position: 3D 世界坐标。
## [br]
## @return 坐标位于高度场范围内时返回 true。
func contains_world_position(position: Vector3) -> bool:
	return contains_world_xz(position.x, position.z)


## 将 X/Z 世界坐标映射为连续网格坐标。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param world_x: 世界 X 坐标。
## [br]
## @param world_z: 世界 Z 坐标。
## [br]
## @return 连续网格坐标；无效高度场返回 Vector2.ZERO。
func world_to_grid(world_x: float, world_z: float) -> Vector2:
	if not is_valid():
		return Vector2.ZERO

	var world_span: Vector2 = _world_max - _world_min
	return Vector2(
		(world_x - _world_min.x) / world_span.x * float(_grid_size.x - 1),
		(world_z - _world_min.y) / world_span.y * float(_grid_size.y - 1)
	)


## 将连续网格坐标映射为 3D 世界坐标。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param grid_position: 连续网格坐标。
## [br]
## @param height: 返回坐标使用的 Y 值。
## [br]
## @return 3D 世界坐标；无效高度场返回 Vector3.ZERO。
func grid_to_world(grid_position: Vector2, height: float = 0.0) -> Vector3:
	if not is_valid():
		return Vector3.ZERO

	var world_span: Vector2 = _world_max - _world_min
	var x_ratio: float = 0.0 if _grid_size.x <= 1 else grid_position.x / float(_grid_size.x - 1)
	var z_ratio: float = 0.0 if _grid_size.y <= 1 else grid_position.y / float(_grid_size.y - 1)
	return Vector3(
		_world_min.x + x_ratio * world_span.x,
		height,
		_world_min.y + z_ratio * world_span.y
	)


## 读取整数网格格点高度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param cell: 网格格点坐标，x 对应世界 X，y 对应世界 Z。
## [br]
## @param fallback: 坐标无效时返回的高度；为 null 时返回 NAN。
## [br]
## @return 格点高度或 fallback。
## [br]
## @schema fallback: Variant，null 或数字高度。
func sample_cell(cell: Vector2i, fallback: Variant = null) -> float:
	var fallback_height: float = _sample_fallback_to_float(fallback)
	if not is_valid() or not _cell_is_inside(cell):
		return fallback_height
	return _height_samples[_cell_to_index(cell)]


## 按连续网格坐标双线性采样高度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param grid_position: 连续网格坐标。
## [br]
## @param fallback: 坐标无效时返回的高度；为 null 时返回 NAN。
## [br]
## @return 双线性高度或 fallback。
## [br]
## @schema fallback: Variant，null 或数字高度。
func sample_grid_bilinear(grid_position: Vector2, fallback: Variant = null) -> float:
	var fallback_height: float = _sample_fallback_to_float(fallback)
	if not is_valid() or not _grid_position_is_inside(grid_position):
		return fallback_height
	return _sample_grid_bilinear_clamped(grid_position)


## 按 X/Z 世界坐标采样高度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param world_x: 世界 X 坐标。
## [br]
## @param world_z: 世界 Z 坐标。
## [br]
## @param fallback: 坐标无效时返回的高度；为 null 时返回 NAN。
## [br]
## @return 双线性高度或 fallback。
## [br]
## @schema fallback: Variant，null 或数字高度。
func sample_world(world_x: float, world_z: float, fallback: Variant = null) -> float:
	var fallback_height: float = _sample_fallback_to_float(fallback)
	if not contains_world_xz(world_x, world_z):
		return fallback_height
	return sample_grid_bilinear(world_to_grid(world_x, world_z), fallback_height)


## 按 3D 世界坐标的 X/Z 采样高度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param position: 3D 世界坐标。
## [br]
## @param fallback: 坐标无效时返回的高度；为 null 时返回 NAN。
## [br]
## @return 双线性高度或 fallback。
## [br]
## @schema fallback: Variant，null 或数字高度。
func sample_world_position(position: Vector3, fallback: Variant = null) -> float:
	return sample_world(position.x, position.z, fallback)


## 按连续网格坐标估算表面法线。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param grid_position: 连续网格坐标。
## [br]
## @param vertical_scale: 高度差缩放，用于匹配项目世界单位。
## [br]
## @return 归一化法线；无效高度场返回 Vector3.UP。
func sample_normal_grid(grid_position: Vector2, vertical_scale: float = 1.0) -> Vector3:
	if not is_valid() or not _grid_position_is_inside(grid_position):
		return Vector3.UP

	var left_x: float = maxf(grid_position.x - 1.0, 0.0)
	var right_x: float = minf(grid_position.x + 1.0, float(_grid_size.x - 1))
	var down_z: float = maxf(grid_position.y - 1.0, 0.0)
	var up_z: float = minf(grid_position.y + 1.0, float(_grid_size.y - 1))
	var left_height: float = _sample_grid_bilinear_clamped(Vector2(left_x, grid_position.y))
	var right_height: float = _sample_grid_bilinear_clamped(Vector2(right_x, grid_position.y))
	var down_height: float = _sample_grid_bilinear_clamped(Vector2(grid_position.x, down_z))
	var up_height: float = _sample_grid_bilinear_clamped(Vector2(grid_position.x, up_z))
	var cell_world_size: Vector2 = _get_cell_world_size()
	var x_distance: float = maxf((right_x - left_x) * cell_world_size.x, _MIN_WORLD_SPAN)
	var z_distance: float = maxf((up_z - down_z) * cell_world_size.y, _MIN_WORLD_SPAN)
	var safe_vertical_scale: float = 1.0 if not _is_finite_float(vertical_scale) else vertical_scale
	var tangent_x: Vector3 = Vector3(
		x_distance,
		(right_height - left_height) * safe_vertical_scale,
		0.0
	)
	var tangent_z: Vector3 = Vector3(
		0.0,
		(up_height - down_height) * safe_vertical_scale,
		z_distance
	)
	var normal: Vector3 = tangent_z.cross(tangent_x)
	if normal.length_squared() <= 0.0:
		return Vector3.UP
	return normal.normalized()


## 按连续网格坐标估算归一化坡度。
##
## 返回值范围为 0.0 到 1.0；无效高度场或坐标返回 1.0，便于调用方按保守策略拒绝无效表面。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param grid_position: 连续网格坐标。
## [br]
## @param vertical_scale: 高度差缩放，用于匹配项目世界单位。
## [br]
## @return 归一化坡度。
func sample_slope_grid(grid_position: Vector2, vertical_scale: float = 1.0) -> float:
	if not is_valid() or not _grid_position_is_inside(grid_position):
		return 1.0
	return normal_to_slope(sample_normal_grid(grid_position, vertical_scale))


## 按 X/Z 世界坐标估算表面法线。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param world_x: 世界 X 坐标。
## [br]
## @param world_z: 世界 Z 坐标。
## [br]
## @param vertical_scale: 高度差缩放，用于匹配项目世界单位。
## [br]
## @return 归一化法线；无效坐标返回 Vector3.UP。
func sample_normal_world(world_x: float, world_z: float, vertical_scale: float = 1.0) -> Vector3:
	if not contains_world_xz(world_x, world_z):
		return Vector3.UP
	return sample_normal_grid(world_to_grid(world_x, world_z), vertical_scale)


## 按 X/Z 世界坐标估算归一化坡度。
##
## 返回值范围为 0.0 到 1.0；无效高度场或坐标返回 1.0，便于调用方按保守策略拒绝无效表面。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param world_x: 世界 X 坐标。
## [br]
## @param world_z: 世界 Z 坐标。
## [br]
## @param vertical_scale: 高度差缩放，用于匹配项目世界单位。
## [br]
## @return 归一化坡度。
func sample_slope_world(world_x: float, world_z: float, vertical_scale: float = 1.0) -> float:
	if not contains_world_xz(world_x, world_z):
		return 1.0
	return sample_slope_grid(world_to_grid(world_x, world_z), vertical_scale)


## 获取最小高度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param fallback: 高度场无效时返回的值。
## [br]
## @return 最小高度或 fallback。
func get_min_height(fallback: float = 0.0) -> float:
	if not is_valid():
		return fallback

	var result: float = _height_samples[0]
	for index: int in range(1, _height_samples.size()):
		result = minf(result, _height_samples[index])
	return result


## 获取最大高度。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param fallback: 高度场无效时返回的值。
## [br]
## @return 最大高度或 fallback。
func get_max_height(fallback: float = 0.0) -> float:
	if not is_valid():
		return fallback

	var result: float = _height_samples[0]
	for index: int in range(1, _height_samples.size()):
		result = maxf(result, _height_samples[index])
	return result


## 获取高度场诊断快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 诊断快照。
## [br]
## @schema return: Dictionary with valid, grid_size, world_min, world_max, sample_count, min_height, and max_height.
func get_debug_snapshot() -> Dictionary:
	return {
		"valid": is_valid(),
		"grid_size": _grid_size,
		"world_min": _world_min,
		"world_max": _world_max,
		"sample_count": _height_samples.size(),
		"min_height": get_min_height(NAN),
		"max_height": get_max_height(NAN),
	}


# --- 私有/辅助方法 ---

static func _copy_float_samples(samples: PackedFloat32Array) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	var _resize_result: int = result.resize(samples.size())
	for index: int in range(samples.size()):
		result[index] = samples[index]
	return result


static func _color_channel_to_byte(channel: float) -> int:
	if not _is_finite_float(channel):
		return 0
	return clampi(roundi(clampf(channel, 0.0, 1.0) * 255.0), 0, 255)


static func _make_terrain_rgb_samples_report() -> Dictionary:
	return {
		"ok": true,
		"grid_size": Vector2i.ZERO,
		"samples": PackedFloat32Array(),
		"sample_count": 0,
		"min_height": 0.0,
		"max_height": 0.0,
		"issues": [],
		"counts": {},
		"summary": "",
	}


static func _append_terrain_rgb_issue(report: Dictionary, kind: String, message: String) -> void:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	issues.append({
		"kind": kind,
		"message": message,
	})
	report["issues"] = issues


static func _finalize_terrain_rgb_samples_report(report: Dictionary) -> Dictionary:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var counts: Dictionary = GFVariantData.get_option_dictionary(report, "counts")
	counts["issue_count"] = issues.size()
	counts["sample_count"] = GFVariantData.get_option_int(report, "sample_count")
	report["counts"] = counts
	report["ok"] = issues.is_empty()
	report["summary"] = "ok" if issues.is_empty() else "issues=%s" % issues.size()
	return report


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _sample_fallback_to_float(value: Variant) -> float:
	if value == null:
		return NAN
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	return NAN


static func _is_finite_vector2(value: Vector2) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y)


static func _is_finite_vector3(value: Vector3) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y) and _is_finite_float(value.z)


static func _samples_are_finite(samples: PackedFloat32Array) -> bool:
	for height_value: float in samples:
		if not _is_finite_float(height_value):
			return false
	return true


static func _can_configure(
	grid_size: Vector2i,
	height_samples: PackedFloat32Array,
	world_min: Vector2,
	world_max: Vector2
) -> bool:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return false
	if height_samples.size() != grid_size.x * grid_size.y:
		return false
	if not _is_finite_vector2(world_min) or not _is_finite_vector2(world_max):
		return false
	if world_max.x - world_min.x < _MIN_WORLD_SPAN or world_max.y - world_min.y < _MIN_WORLD_SPAN:
		return false
	return _samples_are_finite(height_samples)


func _cell_is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < _grid_size.x and cell.y >= 0 and cell.y < _grid_size.y


func _grid_position_is_inside(grid_position: Vector2) -> bool:
	if not _is_finite_vector2(grid_position):
		return false
	return (
		grid_position.x >= 0.0
		and grid_position.x <= float(_grid_size.x - 1)
		and grid_position.y >= 0.0
		and grid_position.y <= float(_grid_size.y - 1)
	)


func _cell_to_index(cell: Vector2i) -> int:
	return cell.y * _grid_size.x + cell.x


func _sample_grid_bilinear_clamped(grid_position: Vector2) -> float:
	var clamped_x: float = clampf(grid_position.x, 0.0, float(_grid_size.x - 1))
	var clamped_z: float = clampf(grid_position.y, 0.0, float(_grid_size.y - 1))
	var x0: int = floori(clamped_x)
	var z0: int = floori(clamped_z)
	var x1: int = mini(x0 + 1, _grid_size.x - 1)
	var z1: int = mini(z0 + 1, _grid_size.y - 1)
	var tx: float = clamped_x - float(x0)
	var tz: float = clamped_z - float(z0)
	var h00: float = _height_samples[_cell_to_index(Vector2i(x0, z0))]
	var h10: float = _height_samples[_cell_to_index(Vector2i(x1, z0))]
	var h01: float = _height_samples[_cell_to_index(Vector2i(x0, z1))]
	var h11: float = _height_samples[_cell_to_index(Vector2i(x1, z1))]
	var h0: float = lerpf(h00, h10, tx)
	var h1: float = lerpf(h01, h11, tx)
	return lerpf(h0, h1, tz)


func _get_cell_world_size() -> Vector2:
	var world_span: Vector2 = _world_max - _world_min
	return Vector2(
		world_span.x / maxf(float(_grid_size.x - 1), 1.0),
		world_span.y / maxf(float(_grid_size.y - 1), 1.0)
	)
