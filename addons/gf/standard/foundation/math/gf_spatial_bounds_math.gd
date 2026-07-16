# GFSpatialBoundsMath: 空间边界的有限性与归一化契约。
#
# 集中定义 Rect2/AABB 进入空间索引、排序和物理查询前必须满足的基础条件。
# 该辅助只处理数值几何，不负责索引策略或业务过滤。
extends RefCounted


# --- 公共方法 ---

## 判断浮点值是否有限。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param value: 待检查值。
## [br]
## @return 有限时返回 true。
static func is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


## 判断 Vector2 的所有分量是否有限。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param value: 待检查向量。
## [br]
## @return 所有分量有限时返回 true。
static func is_finite_vector2(value: Vector2) -> bool:
	return is_finite_float(value.x) and is_finite_float(value.y)


## 判断 Vector3 的所有分量是否有限。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param value: 待检查向量。
## [br]
## @return 所有分量有限时返回 true。
static func is_finite_vector3(value: Vector3) -> bool:
	return is_finite_float(value.x) and is_finite_float(value.y) and is_finite_float(value.z)


## 判断 Rect2 的起点、尺寸和终点是否都有限。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param rect: 待检查矩形。
## [br]
## @return 可安全参与空间运算时返回 true。
static func is_finite_rect2(rect: Rect2) -> bool:
	return (
		is_finite_vector2(rect.position)
		and is_finite_vector2(rect.size)
		and is_finite_vector2(rect.position + rect.size)
	)


## 判断 AABB 的起点、尺寸和终点是否都有限。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param bounds: 待检查包围盒。
## [br]
## @return 可安全参与空间运算时返回 true。
static func is_finite_aabb(bounds: AABB) -> bool:
	return (
		is_finite_vector3(bounds.position)
		and is_finite_vector3(bounds.size)
		and is_finite_vector3(bounds.position + bounds.size)
	)


## 把 Rect2 的负尺寸转换为等价的非负尺寸表示。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param rect: 待归一化矩形。
## [br]
## @return 等价的非负尺寸矩形。
static func normalize_rect2(rect: Rect2) -> Rect2:
	var position: Vector2 = rect.position
	var size: Vector2 = rect.size
	if size.x < 0.0:
		position.x += size.x
		size.x = -size.x
	if size.y < 0.0:
		position.y += size.y
		size.y = -size.y
	return Rect2(position, size)


## 把 AABB 的负尺寸转换为等价的非负尺寸表示。
## [br]
## @api framework_internal
## [br]
## @since 8.0.0
## [br]
## @param bounds: 待归一化包围盒。
## [br]
## @return 等价的非负尺寸包围盒。
static func normalize_aabb(bounds: AABB) -> AABB:
	var position: Vector3 = bounds.position
	var size: Vector3 = bounds.size
	if size.x < 0.0:
		position.x += size.x
		size.x = -size.x
	if size.y < 0.0:
		position.y += size.y
		size.y = -size.y
	if size.z < 0.0:
		position.z += size.z
		size.z = -size.z
	return AABB(position, size)
