## GFSurfaceScatterSampler3D: 通用 3D 表面散布 Transform 采样器。
##
## 在 X/Z 区域或候选点集上调用高度/法线提供者，按高度、坡度、旋转和缩放约束
## 输出纯 Transform3D 与诊断报告。它不创建 Node、MultiMesh、碰撞体或项目对象。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFSurfaceScatterSampler3D
extends RefCounted


# --- 常量 ---

## 区域随机采样的默认最大尝试倍数。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_ATTEMPT_MULTIPLIER: int = 12

## 默认最大候选点数量，避免误把超大散布任务交给单帧纯 GDScript。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_RANDOM_ATTEMPTS: int = 65536

const _EPSILON: float = 0.000001


# --- 公共方法 ---

## 在高度场覆盖的 X/Z 区域中生成散布 Transform。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param heightfield: 高度场数据。
## [br]
## @param area: X/Z 采样区域，Rect2.position 为最小 X/Z，Rect2.size 为范围尺寸。
## [br]
## @param count: 目标 Transform 数量。
## [br]
## @param options: 采样选项。
## [br]
## @schema options: Dictionary supports seed, max_attempt_multiplier, max_random_attempts, height_min, height_max, slope_min, slope_max, yaw_min, yaw_max, scale_min, scale_max, scale_axis_mode, y_offset, align_to_normal, and vertical_scale. scale_min/scale_max may be number or Vector3; scale_axis_mode accepts GFTransform3DMath.ScaleAxisMode or uniform/free/lock_xy/lock_xz/lock_yz.
## [br]
## @return 散布报告。
## [br]
## @schema return: Dictionary with ok, error, area, target_count, accepted_count, attempt_count, max_attempts, seed, transforms, points, normals, exhausted_attempts, rejected_height_count, rejected_slope_count, and rejected_invalid_count.
static func sample_heightfield(
	heightfield: GFHeightfield3D,
	area: Rect2,
	count: int,
	options: Dictionary = {}
) -> Dictionary:
	if heightfield == null or not heightfield.is_valid():
		return _make_failure_result(area, count, options, "heightfield must be valid.")

	var height_provider: Callable = Callable(heightfield, "sample_world")
	var normal_provider: Callable = Callable(heightfield, "sample_normal_world")
	return sample(area, count, height_provider, normal_provider, options)


## 将候选 X/Z 点投射到高度场并生成散布 Transform。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param heightfield: 高度场数据。
## [br]
## @param points: 候选 X/Z 点集。
## [br]
## @param options: 采样选项。
## [br]
## @schema options: Dictionary supports seed, max_points, height_min, height_max, slope_min, slope_max, yaw_min, yaw_max, scale_min, scale_max, scale_axis_mode, y_offset, align_to_normal, and vertical_scale. scale_min/scale_max may be number or Vector3; scale_axis_mode accepts GFTransform3DMath.ScaleAxisMode or uniform/free/lock_xy/lock_xz/lock_yz.
## [br]
## @return 散布报告。
## [br]
## @schema return: Dictionary with ok, error, area, target_count, accepted_count, attempt_count, max_attempts, seed, transforms, points, normals, exhausted_attempts, rejected_height_count, rejected_slope_count, and rejected_invalid_count.
static func sample_heightfield_points(
	heightfield: GFHeightfield3D,
	points: PackedVector2Array,
	options: Dictionary = {}
) -> Dictionary:
	if heightfield == null or not heightfield.is_valid():
		return _make_failure_result(Rect2(), points.size(), options, "heightfield must be valid.")

	var height_provider: Callable = Callable(heightfield, "sample_world")
	var normal_provider: Callable = Callable(heightfield, "sample_normal_world")
	return sample_points(points, height_provider, normal_provider, options)


## 在 X/Z 区域中随机生成候选点并采样散布 Transform。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param area: X/Z 采样区域，Rect2.position 为最小 X/Z，Rect2.size 为范围尺寸。
## [br]
## @param count: 目标 Transform 数量。
## [br]
## @param height_provider: 高度回调，签名为 func(world_x: float, world_z: float) -> float。
## [br]
## @param normal_provider: 法线回调，签名为 func(world_x: float, world_z: float, vertical_scale: float) -> Vector3；无效时使用 Vector3.UP。
## [br]
## @param options: 采样选项。
## [br]
## @schema options: Dictionary supports seed, max_attempt_multiplier, max_random_attempts, height_min, height_max, slope_min, slope_max, yaw_min, yaw_max, scale_min, scale_max, scale_axis_mode, y_offset, align_to_normal, and vertical_scale. scale_min/scale_max may be number or Vector3; scale_axis_mode accepts GFTransform3DMath.ScaleAxisMode or uniform/free/lock_xy/lock_xz/lock_yz.
## [br]
## @return 散布报告。
## [br]
## @schema return: Dictionary with ok, error, area, target_count, accepted_count, attempt_count, max_attempts, seed, transforms, points, normals, exhausted_attempts, rejected_height_count, rejected_slope_count, and rejected_invalid_count.
static func sample(
	area: Rect2,
	count: int,
	height_provider: Callable,
	normal_provider: Callable = Callable(),
	options: Dictionary = {}
) -> Dictionary:
	var validation_error: String = _get_random_input_error(area, count, height_provider)
	if not validation_error.is_empty():
		return _make_failure_result(area, count, options, validation_error)

	var settings: Dictionary = _make_settings(options)
	var target_count: int = maxi(count, 0)
	var max_attempts: int = _get_random_max_attempts(target_count, settings)
	var rng: GFDeterministicRandom = GFDeterministicRandom.from_seed(
		GFVariantData.get_option_int(settings, "seed", 0)
	)
	var transforms: Array[Transform3D] = []
	var sampled_points: PackedVector3Array = PackedVector3Array()
	var sampled_normals: PackedVector3Array = PackedVector3Array()
	var rejected_height_count: int = 0
	var rejected_slope_count: int = 0
	var rejected_invalid_count: int = 0
	var attempt_count: int = 0

	for _attempt_index: int in range(max_attempts):
		if transforms.size() >= target_count:
			break

		attempt_count += 1
		var candidate_point: Vector2 = Vector2(
			area.position.x + rng.next_float_unit() * area.size.x,
			area.position.y + rng.next_float_unit() * area.size.y
		)
		var candidate_result: Dictionary = _evaluate_candidate(
			candidate_point,
			height_provider,
			normal_provider,
			settings,
			rng
		)
		if _candidate_is_accepted(candidate_result):
			transforms.append(_get_candidate_transform(candidate_result))
			var _point_appended: bool = sampled_points.append(_get_candidate_position(candidate_result))
			var _normal_appended: bool = sampled_normals.append(_get_candidate_normal(candidate_result))
			continue

		match GFVariantData.get_option_string(candidate_result, "rejection", "invalid"):
			"height":
				rejected_height_count += 1
			"slope":
				rejected_slope_count += 1
			_:
				rejected_invalid_count += 1

	return _make_success_result(
		area,
		target_count,
		max_attempts,
		attempt_count,
		settings,
		transforms,
		sampled_points,
		sampled_normals,
		rejected_height_count,
		rejected_slope_count,
		rejected_invalid_count
	)


## 将已有候选 X/Z 点投射为散布 Transform。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param points: 候选 X/Z 点集。
## [br]
## @param height_provider: 高度回调，签名为 func(world_x: float, world_z: float) -> float。
## [br]
## @param normal_provider: 法线回调，签名为 func(world_x: float, world_z: float, vertical_scale: float) -> Vector3；无效时使用 Vector3.UP。
## [br]
## @param options: 采样选项。
## [br]
## @schema options: Dictionary supports seed, max_points, height_min, height_max, slope_min, slope_max, yaw_min, yaw_max, scale_min, scale_max, scale_axis_mode, y_offset, align_to_normal, and vertical_scale. scale_min/scale_max may be number or Vector3; scale_axis_mode accepts GFTransform3DMath.ScaleAxisMode or uniform/free/lock_xy/lock_xz/lock_yz.
## [br]
## @return 散布报告。
## [br]
## @schema return: Dictionary with ok, error, area, target_count, accepted_count, attempt_count, max_attempts, seed, transforms, points, normals, exhausted_attempts, rejected_height_count, rejected_slope_count, and rejected_invalid_count.
static func sample_points(
	points: PackedVector2Array,
	height_provider: Callable,
	normal_provider: Callable = Callable(),
	options: Dictionary = {}
) -> Dictionary:
	if not height_provider.is_valid():
		return _make_failure_result(Rect2(), points.size(), options, "height_provider must be valid.")

	var settings: Dictionary = _make_settings(options)
	var max_points: int = GFVariantData.get_option_int(options, "max_points", 0)
	var target_count: int = points.size() if max_points <= 0 else mini(max_points, points.size())
	var rng: GFDeterministicRandom = GFDeterministicRandom.from_seed(
		GFVariantData.get_option_int(settings, "seed", 0)
	)
	var transforms: Array[Transform3D] = []
	var sampled_points: PackedVector3Array = PackedVector3Array()
	var sampled_normals: PackedVector3Array = PackedVector3Array()
	var rejected_height_count: int = 0
	var rejected_slope_count: int = 0
	var rejected_invalid_count: int = 0
	var attempt_count: int = 0

	for candidate_point: Vector2 in points:
		if transforms.size() >= target_count:
			break
		if not _is_finite_vector2(candidate_point):
			rejected_invalid_count += 1
			attempt_count += 1
			continue

		attempt_count += 1
		var candidate_result: Dictionary = _evaluate_candidate(
			candidate_point,
			height_provider,
			normal_provider,
			settings,
			rng
		)
		if _candidate_is_accepted(candidate_result):
			transforms.append(_get_candidate_transform(candidate_result))
			var _point_appended: bool = sampled_points.append(_get_candidate_position(candidate_result))
			var _normal_appended: bool = sampled_normals.append(_get_candidate_normal(candidate_result))
			continue

		match GFVariantData.get_option_string(candidate_result, "rejection", "invalid"):
			"height":
				rejected_height_count += 1
			"slope":
				rejected_slope_count += 1
			_:
				rejected_invalid_count += 1

	return _make_success_result(
		_make_points_area(points),
		target_count,
		points.size(),
		attempt_count,
		settings,
		transforms,
		sampled_points,
		sampled_normals,
		rejected_height_count,
		rejected_slope_count,
		rejected_invalid_count
	)


## 将表面散布报告转换为 JSON.stringify() 安全的结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report: sample_heightfield()、sample_heightfield_points()、sample_points() 或 sample() 返回的报告。
## [br]
## @param options: 报告编码选项，透传给 GFReportValueCodec。
## [br]
## @return: JSON 兼容报告。
## [br]
## @schema report: GFSurfaceScatterSampler3D 返回的表面散布报告。
## [br]
## @schema options: GFReportValueCodec 编码选项字典。
## [br]
## @schema return: 可安全交给 JSON.stringify() 的 Dictionary。
static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
	return GFVariantData.as_dictionary(GFReportValueCodec.to_json_compatible(report, options))


# --- 私有/辅助方法 ---

static func _get_random_input_error(area: Rect2, count: int, height_provider: Callable) -> String:
	if count < 0:
		return "count must be greater than or equal to 0."
	if not height_provider.is_valid():
		return "height_provider must be valid."
	if not _is_finite_vector2(area.position) or not _is_finite_vector2(area.size):
		return "area must contain finite values."
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return "area size must be positive."
	return ""


static func _make_settings(options: Dictionary) -> Dictionary:
	var height_min: float = _get_height_limit(options, "height_min", -INF)
	var height_max: float = _get_height_limit(options, "height_max", INF)
	if height_max < height_min:
		var old_height_min: float = height_min
		height_min = height_max
		height_max = old_height_min

	var slope_min: float = clampf(_get_finite_option_float(options, "slope_min", 0.0), 0.0, 1.0)
	var slope_max: float = clampf(_get_finite_option_float(options, "slope_max", 1.0), 0.0, 1.0)
	if slope_max < slope_min:
		var old_slope_min: float = slope_min
		slope_min = slope_max
		slope_max = old_slope_min

	var yaw_min: float = _get_finite_option_float(options, "yaw_min", 0.0)
	var yaw_max: float = _get_finite_option_float(options, "yaw_max", TAU)
	if yaw_max < yaw_min:
		var old_yaw_min: float = yaw_min
		yaw_min = yaw_max
		yaw_max = old_yaw_min

	var raw_scale_min: Vector3 = _get_non_negative_scale(_get_scale_option(options, "scale_min", Vector3.ONE))
	var raw_scale_max: Vector3 = _get_non_negative_scale(_get_scale_option(options, "scale_max", Vector3.ONE))
	var scale_min: Vector3 = Vector3(
		minf(raw_scale_min.x, raw_scale_max.x),
		minf(raw_scale_min.y, raw_scale_max.y),
		minf(raw_scale_min.z, raw_scale_max.z)
	)
	var scale_max: Vector3 = Vector3(
		maxf(raw_scale_min.x, raw_scale_max.x),
		maxf(raw_scale_min.y, raw_scale_max.y),
		maxf(raw_scale_min.z, raw_scale_max.z)
	)

	return {
		"seed": GFVariantData.get_option_int(options, "seed", 0),
		"max_attempt_multiplier": maxi(
			GFVariantData.get_option_int(options, "max_attempt_multiplier", DEFAULT_MAX_ATTEMPT_MULTIPLIER),
			1
		),
		"max_random_attempts": maxi(
			GFVariantData.get_option_int(options, "max_random_attempts", DEFAULT_MAX_RANDOM_ATTEMPTS),
			0
		),
		"height_min": height_min,
		"height_max": height_max,
		"slope_min": slope_min,
		"slope_max": slope_max,
		"yaw_min": yaw_min,
		"yaw_max": yaw_max,
		"scale_min": scale_min,
		"scale_max": scale_max,
		"scale_axis_mode": _get_scale_axis_mode(options),
		"y_offset": _get_finite_option_float(options, "y_offset", 0.0),
		"align_to_normal": GFVariantData.get_option_bool(options, "align_to_normal", true),
		"vertical_scale": _get_finite_option_float(options, "vertical_scale", 1.0),
	}


static func _get_random_max_attempts(target_count: int, settings: Dictionary) -> int:
	if target_count <= 0:
		return 0

	var attempt_count: int = target_count * GFVariantData.get_option_int(
		settings,
		"max_attempt_multiplier",
		DEFAULT_MAX_ATTEMPT_MULTIPLIER
	)
	var max_random_attempts: int = GFVariantData.get_option_int(
		settings,
		"max_random_attempts",
		DEFAULT_MAX_RANDOM_ATTEMPTS
	)
	if max_random_attempts <= 0:
		return attempt_count
	return mini(attempt_count, max_random_attempts)


static func _evaluate_candidate(
	candidate_point: Vector2,
	height_provider: Callable,
	normal_provider: Callable,
	settings: Dictionary,
	rng: GFDeterministicRandom
) -> Dictionary:
	var height_sample: Dictionary = _call_height_provider(height_provider, candidate_point.x, candidate_point.y)
	if not GFVariantData.get_option_bool(height_sample, "ok", false):
		return _make_candidate_rejection("height")

	var height: float = GFVariantData.get_option_float(height_sample, "height", 0.0)
	if (
		height < GFVariantData.get_option_float(settings, "height_min", -INF)
		or height > GFVariantData.get_option_float(settings, "height_max", INF)
	):
		return _make_candidate_rejection("height")

	var normal: Vector3 = _call_normal_provider(
		normal_provider,
		candidate_point.x,
		candidate_point.y,
		GFVariantData.get_option_float(settings, "vertical_scale", 1.0)
	)
	var slope: float = _normal_to_slope(normal)
	if (
		slope < GFVariantData.get_option_float(settings, "slope_min", 0.0)
		or slope > GFVariantData.get_option_float(settings, "slope_max", 1.0)
	):
		return _make_candidate_rejection("slope")

	var yaw: float = rng.next_float_range(
		GFVariantData.get_option_float(settings, "yaw_min", 0.0),
		GFVariantData.get_option_float(settings, "yaw_max", TAU)
	)
	var scale_value: Vector3 = _get_random_scale(settings, rng)
	var position: Vector3 = Vector3(
		candidate_point.x,
		height + GFVariantData.get_option_float(settings, "y_offset", 0.0),
		candidate_point.y
	)
	var basis: Basis = _make_surface_basis(
		normal,
		yaw,
		GFVariantData.get_option_bool(settings, "align_to_normal", true)
	)
	basis = basis.scaled(scale_value)
	return {
		"accepted": true,
		"rejection": "",
		"transform": Transform3D(basis, position),
		"position": position,
		"normal": normal,
	}


static func _call_height_provider(height_provider: Callable, world_x: float, world_z: float) -> Dictionary:
	var value: Variant = height_provider.call(world_x, world_z)
	if value is int or value is float:
		var height: float = GFVariantData.to_float(value, NAN)
		if _is_finite_float(height):
			return { "ok": true, "height": height }
	return { "ok": false, "height": NAN }


static func _call_normal_provider(
	normal_provider: Callable,
	world_x: float,
	world_z: float,
	vertical_scale: float
) -> Vector3:
	if not normal_provider.is_valid():
		return Vector3.UP

	var value: Variant = normal_provider.call(world_x, world_z, vertical_scale)
	if value is Vector3:
		var normal: Vector3 = value
		if _is_finite_vector3(normal) and normal.length_squared() > _EPSILON:
			return normal.normalized()
	return Vector3.UP


static func _normal_to_slope(normal: Vector3) -> float:
	return GFHeightfield3D.normal_to_slope(normal)


static func _make_surface_basis(normal: Vector3, yaw: float, align_to_normal: bool) -> Basis:
	var up: Vector3 = normal.normalized() if align_to_normal and normal.length_squared() > _EPSILON else Vector3.UP
	var yaw_forward: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, yaw).normalized()
	var right: Vector3 = yaw_forward.cross(up)
	if right.length_squared() <= _EPSILON:
		var helper: Vector3 = Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		right = helper.cross(up)

	right = right.normalized()
	var forward: Vector3 = up.cross(right).normalized()
	return Basis(right, up, -forward)


static func _make_success_result(
	area: Rect2,
	target_count: int,
	max_attempts: int,
	attempt_count: int,
	settings: Dictionary,
	transforms: Array[Transform3D],
	points: PackedVector3Array,
	normals: PackedVector3Array,
	rejected_height_count: int,
	rejected_slope_count: int,
	rejected_invalid_count: int
) -> Dictionary:
	return {
		"ok": true,
		"error": "",
		"area": area,
		"target_count": target_count,
		"accepted_count": transforms.size(),
		"attempt_count": attempt_count,
		"max_attempts": max_attempts,
		"seed": GFVariantData.get_option_int(settings, "seed", 0),
		"transforms": transforms,
		"points": points,
		"normals": normals,
		"exhausted_attempts": transforms.size() < target_count and attempt_count >= max_attempts,
		"rejected_height_count": rejected_height_count,
		"rejected_slope_count": rejected_slope_count,
		"rejected_invalid_count": rejected_invalid_count,
	}


static func _make_failure_result(area: Rect2, target_count: int, options: Dictionary, error: String) -> Dictionary:
	return {
		"ok": false,
		"error": error,
		"area": area,
		"target_count": maxi(target_count, 0),
		"accepted_count": 0,
		"attempt_count": 0,
		"max_attempts": 0,
		"seed": GFVariantData.get_option_int(options, "seed", 0),
		"transforms": [],
		"points": PackedVector3Array(),
		"normals": PackedVector3Array(),
		"exhausted_attempts": false,
		"rejected_height_count": 0,
		"rejected_slope_count": 0,
		"rejected_invalid_count": 0,
	}


static func _make_candidate_rejection(reason: String) -> Dictionary:
	return {
		"accepted": false,
		"rejection": reason,
		"transform": Transform3D.IDENTITY,
		"position": Vector3.ZERO,
		"normal": Vector3.UP,
	}


static func _candidate_is_accepted(candidate_result: Dictionary) -> bool:
	return GFVariantData.get_option_bool(candidate_result, "accepted", false)


static func _get_candidate_transform(candidate_result: Dictionary) -> Transform3D:
	var value: Variant = GFVariantData.get_option_value(candidate_result, "transform", Transform3D.IDENTITY)
	if value is Transform3D:
		var transform: Transform3D = value
		return transform
	return Transform3D.IDENTITY


static func _get_candidate_position(candidate_result: Dictionary) -> Vector3:
	var value: Variant = GFVariantData.get_option_value(candidate_result, "position", Vector3.ZERO)
	if value is Vector3:
		var position: Vector3 = value
		return position
	return Vector3.ZERO


static func _get_candidate_normal(candidate_result: Dictionary) -> Vector3:
	var value: Variant = GFVariantData.get_option_value(candidate_result, "normal", Vector3.UP)
	if value is Vector3:
		var normal: Vector3 = value
		return normal
	return Vector3.UP


static func _make_points_area(points: PackedVector2Array) -> Rect2:
	var found_finite_point: bool = false
	var min_point: Vector2 = Vector2.ZERO
	var max_point: Vector2 = Vector2.ZERO
	for index: int in range(points.size()):
		var point: Vector2 = points[index]
		if not _is_finite_vector2(point):
			continue
		if not found_finite_point:
			min_point = point
			max_point = point
			found_finite_point = true
			continue

		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	if not found_finite_point:
		return Rect2()
	return Rect2(min_point, max_point - min_point)


static func _get_height_limit(options: Dictionary, key: String, default_value: float) -> float:
	var value: float = GFVariantData.get_option_float(options, key, default_value)
	if is_nan(value):
		return default_value
	return value


static func _get_scale_option(options: Dictionary, key: String, default_value: Vector3) -> Vector3:
	var value: Variant = GFVariantData.get_option_value(options, key, default_value)
	if value is Vector3:
		var vector: Vector3 = value
		if _is_finite_vector3(vector):
			return vector
	if value is int or value is float:
		var scalar: float = GFVariantData.to_float(value, NAN)
		if _is_finite_float(scalar):
			return Vector3.ONE * scalar
	return default_value


static func _get_non_negative_scale(value: Vector3) -> Vector3:
	return Vector3(
		maxf(value.x, 0.0),
		maxf(value.y, 0.0),
		maxf(value.z, 0.0)
	)


static func _get_scale_axis_mode(options: Dictionary) -> GFTransform3DMath.ScaleAxisMode:
	var value: Variant = GFVariantData.get_option_value(
		options,
		"scale_axis_mode",
		GFTransform3DMath.ScaleAxisMode.UNIFORM
	)
	if value is int:
		var mode_id: int = value
		match mode_id:
			GFTransform3DMath.ScaleAxisMode.FREE:
				return GFTransform3DMath.ScaleAxisMode.FREE
			GFTransform3DMath.ScaleAxisMode.LOCK_XY:
				return GFTransform3DMath.ScaleAxisMode.LOCK_XY
			GFTransform3DMath.ScaleAxisMode.LOCK_XZ:
				return GFTransform3DMath.ScaleAxisMode.LOCK_XZ
			GFTransform3DMath.ScaleAxisMode.LOCK_YZ:
				return GFTransform3DMath.ScaleAxisMode.LOCK_YZ
			_:
				return GFTransform3DMath.ScaleAxisMode.UNIFORM
	if value is String:
		var mode_text: String = value
		return _scale_axis_mode_from_text(mode_text)
	if value is StringName:
		var mode_name: StringName = value
		return _scale_axis_mode_from_text(String(mode_name))
	return GFTransform3DMath.ScaleAxisMode.UNIFORM


static func _scale_axis_mode_from_text(value: String) -> GFTransform3DMath.ScaleAxisMode:
	match value.strip_edges().to_lower():
		"free":
			return GFTransform3DMath.ScaleAxisMode.FREE
		"lock_xy", "xy":
			return GFTransform3DMath.ScaleAxisMode.LOCK_XY
		"lock_xz", "xz":
			return GFTransform3DMath.ScaleAxisMode.LOCK_XZ
		"lock_yz", "yz":
			return GFTransform3DMath.ScaleAxisMode.LOCK_YZ
		_:
			return GFTransform3DMath.ScaleAxisMode.UNIFORM


static func _get_scale_setting(settings: Dictionary, key: String, default_value: Vector3) -> Vector3:
	var value: Variant = GFVariantData.get_option_value(settings, key, default_value)
	if value is Vector3:
		var scale_value: Vector3 = value
		if _is_finite_vector3(scale_value):
			return scale_value
	return default_value


static func _get_scale_axis_mode_setting(settings: Dictionary) -> GFTransform3DMath.ScaleAxisMode:
	return _get_scale_axis_mode(settings)


static func _get_random_scale(settings: Dictionary, rng: GFDeterministicRandom) -> Vector3:
	var mode: GFTransform3DMath.ScaleAxisMode = _get_scale_axis_mode_setting(settings)
	var weight: Vector3 = _get_random_scale_weight(mode, rng)
	return GFTransform3DMath.interpolate_scale(
		_get_scale_setting(settings, "scale_min", Vector3.ONE),
		_get_scale_setting(settings, "scale_max", Vector3.ONE),
		weight,
		mode
	)


static func _get_random_scale_weight(
	mode: GFTransform3DMath.ScaleAxisMode,
	rng: GFDeterministicRandom
) -> Vector3:
	match mode:
		GFTransform3DMath.ScaleAxisMode.FREE:
			return Vector3(rng.next_float_unit(), rng.next_float_unit(), rng.next_float_unit())
		GFTransform3DMath.ScaleAxisMode.LOCK_XY:
			return Vector3(rng.next_float_unit(), 0.0, rng.next_float_unit())
		GFTransform3DMath.ScaleAxisMode.LOCK_XZ:
			return Vector3(rng.next_float_unit(), rng.next_float_unit(), 0.0)
		GFTransform3DMath.ScaleAxisMode.LOCK_YZ:
			return Vector3(rng.next_float_unit(), rng.next_float_unit(), 0.0)
		_:
			return Vector3.ONE * rng.next_float_unit()


static func _get_finite_option_float(options: Dictionary, key: String, default_value: float) -> float:
	var value: float = GFVariantData.get_option_float(options, key, default_value)
	if not _is_finite_float(value):
		return default_value
	return value


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_finite_vector2(value: Vector2) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y)


static func _is_finite_vector3(value: Vector3) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y) and _is_finite_float(value.z)
