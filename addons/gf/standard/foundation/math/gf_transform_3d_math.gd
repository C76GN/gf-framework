## GFTransform3DMath: 通用 3D Transform 纯数学工具。
##
## 提供点、方向与 Transform3D 的平面反射、射线平面命中、表面吸附和锚点对齐计算。
## 它不创建节点、不处理镜面渲染，也不决定相机、材质、Portal、关卡编辑器或放置工具的业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFTransform3DMath
extends RefCounted


# --- 枚举 ---

## 3D 缩放权重的轴向锁定模式。
## [br]
## @api public
## [br]
## @since 8.0.0
enum ScaleAxisMode {
	## X/Y/Z 使用同一个权重。
	UNIFORM,
	## X/Y/Z 分别使用输入权重。
	FREE,
	## X/Y 共用 X 权重，Z 保留自身权重。
	LOCK_XY,
	## X/Z 共用 X 权重，Y 保留自身权重。
	LOCK_XZ,
	## Y/Z 共用 Y 权重，X 保留自身权重。
	LOCK_YZ,
}


# --- 常量 ---

const _EPSILON: float = 0.000001


# --- 公共方法 ---

## 构建相对指定平面的反射 Transform3D。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param plane_normal: 平面法线；函数会归一化。零向量时返回 Transform3D.IDENTITY。
## [br]
## @param plane_point: 平面上的任意一点。
## [br]
## @return 将世界点反射到平面另一侧的 Transform3D。
static func make_reflection_transform(plane_normal: Vector3, plane_point: Vector3) -> Transform3D:
	var normal: Vector3 = _get_safe_normal(plane_normal)
	if normal == Vector3.ZERO:
		return Transform3D.IDENTITY

	var x_axis: Vector3 = Vector3.RIGHT - 2.0 * normal.x * normal
	var y_axis: Vector3 = Vector3.UP - 2.0 * normal.y * normal
	var z_axis: Vector3 = Vector3.BACK - 2.0 * normal.z * normal
	var origin: Vector3 = 2.0 * normal.dot(plane_point) * normal
	return Transform3D(Basis(x_axis, y_axis, z_axis), origin)


## 将点按指定平面反射。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param point: 待反射的世界点。
## [br]
## @param plane_normal: 平面法线；函数会归一化。零向量时返回原点值。
## [br]
## @param plane_point: 平面上的任意一点。
## [br]
## @return 反射后的世界点。
static func reflect_point(point: Vector3, plane_normal: Vector3, plane_point: Vector3) -> Vector3:
	var normal: Vector3 = _get_safe_normal(plane_normal)
	if normal == Vector3.ZERO:
		return point

	var signed_distance: float = (point - plane_point).dot(normal)
	return point - 2.0 * signed_distance * normal


## 将方向向量按指定平面法线反射。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param direction: 待反射方向；不会被额外归一化。
## [br]
## @param plane_normal: 平面法线；函数会归一化。零向量时返回原方向。
## [br]
## @return 反射后的方向向量。
static func reflect_direction(direction: Vector3, plane_normal: Vector3) -> Vector3:
	var normal: Vector3 = _get_safe_normal(plane_normal)
	if normal == Vector3.ZERO:
		return direction

	return direction - 2.0 * direction.dot(normal) * normal


## 将 Transform3D 的 basis 与 origin 一起按指定平面反射。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param transform: 待反射 Transform3D。
## [br]
## @param plane_normal: 平面法线；函数会归一化。零向量时返回原 Transform。
## [br]
## @param plane_point: 平面上的任意一点。
## [br]
## @return 反射后的 Transform3D。
static func reflect_transform(
	transform: Transform3D,
	plane_normal: Vector3,
	plane_point: Vector3
) -> Transform3D:
	var normal: Vector3 = _get_safe_normal(plane_normal)
	if normal == Vector3.ZERO:
		return transform

	var reflected_origin: Vector3 = reflect_point(transform.origin, normal, plane_point)
	var reflected_basis: Basis = Basis(
		reflect_direction(transform.basis.x, normal),
		reflect_direction(transform.basis.y, normal),
		reflect_direction(transform.basis.z, normal)
	)
	return Transform3D(reflected_basis, reflected_origin)


## 计算射线与平面的交点。
##
## 返回字典中的 distance 使用归一化后的 ray_direction 计算；当 face_normal_to_ray 为 true 时，
## 返回 normal 会朝向射线来源，便于后续表面放置、预览朝向或命中提示使用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param ray_origin: 射线起点。
## [br]
## @param ray_direction: 射线方向；函数会归一化。
## [br]
## @param plane_normal: 平面法线；函数会归一化。
## [br]
## @param plane_point: 平面上的任意一点。
## [br]
## @param max_distance: 最大命中距离；小于等于 0 时不限制。
## [br]
## @param face_normal_to_ray: 是否让返回法线朝向射线来源。
## [br]
## @return 命中报告。
## [br]
## @schema return: Dictionary，包含 ok: bool、reason: StringName、position: Vector3、normal: Vector3、distance: float、ray_origin: Vector3 和 ray_direction: Vector3。
static func intersect_ray_plane(
	ray_origin: Vector3,
	ray_direction: Vector3,
	plane_normal: Vector3,
	plane_point: Vector3,
	max_distance: float = -1.0,
	face_normal_to_ray: bool = true
) -> Dictionary:
	var direction: Vector3 = _get_safe_normal(ray_direction)
	if not _is_finite_vector3(ray_origin) or direction == Vector3.ZERO:
		return _make_ray_plane_report(false, &"invalid_ray", Vector3.ZERO, Vector3.ZERO, 0.0, ray_origin, direction)

	var normal: Vector3 = _get_safe_normal(plane_normal)
	if not _is_finite_vector3(plane_point) or normal == Vector3.ZERO:
		return _make_ray_plane_report(false, &"invalid_plane", Vector3.ZERO, Vector3.ZERO, 0.0, ray_origin, direction)

	var denominator: float = direction.dot(normal)
	if absf(denominator) <= _EPSILON:
		return _make_ray_plane_report(false, &"parallel", Vector3.ZERO, normal, 0.0, ray_origin, direction)

	var distance: float = (plane_point - ray_origin).dot(normal) / denominator
	if distance < 0.0:
		return _make_ray_plane_report(false, &"behind_ray", Vector3.ZERO, normal, distance, ray_origin, direction)

	var safe_max_distance: float = max_distance if _is_finite_float(max_distance) else -1.0
	if safe_max_distance > 0.0 and distance > safe_max_distance:
		return _make_ray_plane_report(false, &"beyond_max_distance", Vector3.ZERO, normal, distance, ray_origin, direction)

	var hit_normal: Vector3 = normal
	if face_normal_to_ray and direction.dot(hit_normal) > 0.0:
		hit_normal = -hit_normal
	return _make_ray_plane_report(
		true,
		&"",
		ray_origin + direction * distance,
		hit_normal,
		distance,
		ray_origin,
		direction
	)


## 用目标 Y 轴和候选 Z 轴构建稳定正交 basis。
##
## 适合把物体局部 Y 轴贴合表面法线，同时尽量保持原本局部 Z 轴朝向。
## z_axis_hint 与 up_axis 近似平行时，会自动选择稳定的兜底轴。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param up_axis: 目标局部 Y 轴方向。
## [br]
## @param z_axis_hint: 期望局部 Z 轴尽量接近的方向。
## [br]
## @return 正交 basis；输入无效时返回 Basis.IDENTITY。
static func make_basis_from_up_and_z_hint(
	up_axis: Vector3,
	z_axis_hint: Vector3 = Vector3.BACK
) -> Basis:
	var up: Vector3 = _get_safe_normal(up_axis)
	if up == Vector3.ZERO:
		return Basis.IDENTITY

	var z_axis: Vector3 = _get_safe_normal(z_axis_hint)
	if z_axis == Vector3.ZERO or absf(up.dot(z_axis)) > 0.999:
		z_axis = _get_fallback_z_axis(up)

	var x_axis: Vector3 = up.cross(z_axis)
	if not _is_finite_vector3(x_axis) or x_axis.length_squared() <= _EPSILON:
		z_axis = _get_fallback_z_axis(up)
		x_axis = up.cross(z_axis)
	if not _is_finite_vector3(x_axis) or x_axis.length_squared() <= _EPSILON:
		return Basis.IDENTITY

	x_axis = x_axis.normalized()
	z_axis = x_axis.cross(up).normalized()
	return Basis(x_axis, up, z_axis).orthonormalized()


## 按轴向锁定模式归一 3D 缩放插值权重。
##
## 该方法只处理权重复制关系，不钳制 0 到 1 范围；调用方可以用超出范围的权重做外插。
## 输入包含非有限数时返回 Vector3.ZERO。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param weight: 原始 X/Y/Z 权重。
## [br]
## @param mode: 轴向锁定模式。
## [br]
## @return 应用于 X/Y/Z 的权重。
static func apply_scale_axis_mode(
	weight: Vector3,
	mode: ScaleAxisMode = ScaleAxisMode.UNIFORM
) -> Vector3:
	if not _is_finite_vector3(weight):
		return Vector3.ZERO

	match mode:
		ScaleAxisMode.FREE:
			return weight
		ScaleAxisMode.LOCK_XY:
			return Vector3(weight.x, weight.x, weight.z)
		ScaleAxisMode.LOCK_XZ:
			return Vector3(weight.x, weight.y, weight.x)
		ScaleAxisMode.LOCK_YZ:
			return Vector3(weight.x, weight.y, weight.y)
		_:
			return Vector3.ONE * weight.x


## 按轴向锁定模式在两个 3D 缩放向量之间插值。
##
## 输入包含非有限数时返回 Vector3.ONE。该方法不钳制权重，也不限制缩放正负。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param min_scale: 起始缩放向量。
## [br]
## @param max_scale: 结束缩放向量。
## [br]
## @param weight: 原始 X/Y/Z 插值权重。
## [br]
## @param mode: 轴向锁定模式。
## [br]
## @return 插值后的缩放向量。
static func interpolate_scale(
	min_scale: Vector3,
	max_scale: Vector3,
	weight: Vector3,
	mode: ScaleAxisMode = ScaleAxisMode.UNIFORM
) -> Vector3:
	if not _is_finite_vector3(min_scale) or not _is_finite_vector3(max_scale) or not _is_finite_vector3(weight):
		return Vector3.ONE

	var scale_weight: Vector3 = apply_scale_axis_mode(weight, mode)
	return Vector3(
		lerpf(min_scale.x, max_scale.x, scale_weight.x),
		lerpf(min_scale.y, max_scale.y, scale_weight.y),
		lerpf(min_scale.z, max_scale.z, scale_weight.z)
	)


## 在平面切向网格上吸附点，同时保留点到平面的法线距离。
##
## grid_step 小于等于 0 或输入包含非有限数时返回 ok=false，并给出稳定零向量结果。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param point: 要吸附的世界点。
## [br]
## @param plane_normal: 平面法线；函数会归一化。
## [br]
## @param grid_step: 切向网格间距。
## [br]
## @param plane_origin: 网格原点。
## [br]
## @return 吸附报告。
## [br]
## @schema return: Dictionary，包含 ok: bool、reason: StringName、point: Vector3、normal: Vector3、x_axis: Vector3、z_axis: Vector3、grid_step: float、normal_distance: float、x_distance: float 和 z_distance: float。
static func snap_point_to_plane_grid(
	point: Vector3,
	plane_normal: Vector3,
	grid_step: float,
	plane_origin: Vector3 = Vector3.ZERO
) -> Dictionary:
	if not _is_finite_vector3(point) or not _is_finite_vector3(plane_origin):
		return _make_snap_report(false, &"invalid_point", Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, 0.0, 0.0)

	var normal: Vector3 = _get_safe_normal(plane_normal)
	if normal == Vector3.ZERO:
		return _make_snap_report(false, &"invalid_plane", Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, 0.0, 0.0)

	if not _is_finite_float(grid_step) or grid_step <= _EPSILON:
		return _make_snap_report(false, &"invalid_grid_step", Vector3.ZERO, normal, Vector3.ZERO, Vector3.ZERO, 0.0, 0.0, 0.0, 0.0)

	var basis: Basis = make_basis_from_up_and_z_hint(normal)
	var x_axis: Vector3 = basis.x.normalized()
	var z_axis: Vector3 = basis.z.normalized()
	var relative: Vector3 = point - plane_origin
	var x_distance: float = x_axis.dot(relative)
	var z_distance: float = z_axis.dot(relative)
	var normal_distance: float = normal.dot(relative)
	var snapped_x: float = roundf(x_distance / grid_step) * grid_step
	var snapped_z: float = roundf(z_distance / grid_step) * grid_step
	var snapped_point: Vector3 = (
		plane_origin
		+ x_axis * snapped_x
		+ z_axis * snapped_z
		+ normal * normal_distance
	)
	return _make_snap_report(true, &"", snapped_point, normal, x_axis, z_axis, grid_step, normal_distance, snapped_x, snapped_z)


## 平移 Transform3D，使指定本地锚点落到目标世界点。
##
## 常用于把模型底部、抓取点、吸附点或自定义 pivot 对齐到命中位置。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param transform: 原始世界 Transform3D。
## [br]
## @param local_point: transform 本地空间中的锚点。
## [br]
## @param world_point: 锚点应对齐到的世界点。
## [br]
## @return 平移后的 Transform3D；输入无效时返回原 Transform。
static func move_local_point_to_world(
	transform: Transform3D,
	local_point: Vector3,
	world_point: Vector3
) -> Transform3D:
	if not _is_finite_transform3d(transform) or not _is_finite_vector3(local_point) or not _is_finite_vector3(world_point):
		return transform

	var current_world_point: Vector3 = transform * local_point
	var adjusted: Transform3D = transform
	adjusted.origin += world_point - current_world_point
	return adjusted


# --- 私有/辅助方法 ---

static func _get_safe_normal(plane_normal: Vector3) -> Vector3:
	if not _is_finite_vector3(plane_normal) or plane_normal.length_squared() <= _EPSILON:
		return Vector3.ZERO
	return plane_normal.normalized()


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_finite_vector3(value: Vector3) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y) and _is_finite_float(value.z)


static func _is_finite_basis(value: Basis) -> bool:
	return (
		_is_finite_vector3(value.x)
		and _is_finite_vector3(value.y)
		and _is_finite_vector3(value.z)
	)


static func _is_finite_transform3d(value: Transform3D) -> bool:
	return _is_finite_basis(value.basis) and _is_finite_vector3(value.origin)


static func _get_fallback_z_axis(up: Vector3) -> Vector3:
	if absf(up.dot(Vector3.BACK)) < 0.999:
		return Vector3.BACK
	if absf(up.dot(Vector3.RIGHT)) < 0.999:
		return Vector3.RIGHT
	return Vector3.UP


static func _make_ray_plane_report(
	ok: bool,
	reason: StringName,
	position: Vector3,
	normal: Vector3,
	distance: float,
	ray_origin: Vector3,
	ray_direction: Vector3
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"position": position,
		"normal": normal,
		"distance": distance,
		"ray_origin": ray_origin,
		"ray_direction": ray_direction,
	}


static func _make_snap_report(
	ok: bool,
	reason: StringName,
	point: Vector3,
	normal: Vector3,
	x_axis: Vector3,
	z_axis: Vector3,
	grid_step: float,
	normal_distance: float,
	x_distance: float,
	z_distance: float
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"point": point,
		"normal": normal,
		"x_axis": x_axis,
		"z_axis": z_axis,
		"grid_step": grid_step,
		"normal_distance": normal_distance,
		"x_distance": x_distance,
		"z_distance": z_distance,
	}
