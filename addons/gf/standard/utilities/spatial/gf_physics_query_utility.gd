## GFPhysicsQueryUtility: 通用物理查询辅助。
##
## 提供不绑定玩法语义的物理查询方法。调用方负责决定命中结果如何排序、
## 过滤、解释和分发；本工具只封装稳定的查询流程和结果补充字段。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.1.0
class_name GFPhysicsQueryUtility
extends GFUtility


# --- 常量 ---

## 多命中射线查询的默认最大命中数。
## [br]
## @api public
const DEFAULT_MAX_RAYCAST_RESULTS: int = 32

## 多命中射线查询命中后沿射线推进的默认距离。
## [br]
## @api public
const DEFAULT_RAYCAST_MARGIN: float = 0.01
const _SPATIAL_BOUNDS_MATH = preload("res://addons/gf/standard/foundation/math/gf_spatial_bounds_math.gd")


# --- 公共方法 ---

## 沿一条 3D 射线收集多个命中结果。
##
## 每次命中后会把命中的 RID 加入本次查询的排除列表，并沿射线方向推进
## margin，直到没有更多命中、到达终点或达到 max_results。
## 返回的每个 Dictionary 保留 Godot `intersect_ray()` 的原始字段，并额外包含
## `index` 与 `distance` 字段。
## [br]
## @api public
## [br]
## @param world: 用于执行查询的 World3D。
## [br]
## @param from: 射线起点。
## [br]
## @param to: 射线终点。
## [br]
## @param options: 可选查询参数。
## [br]
## @return: 按射线方向排序的命中结果列表。
## [br]
## @schema options: Dictionary，支持 collision_mask: int、exclude: Array[RID or CollisionObject3D]、max_results: int、margin: float、collide_with_bodies: bool、collide_with_areas: bool、hit_back_faces: bool 和 hit_from_inside: bool。
## [br]
## @schema return: Array[Dictionary]，每项包含 Godot intersect_ray() 返回字段，并额外包含 index: int 与 distance: float。
func raycast_all_3d(
	world: World3D,
	from: Vector3,
	to: Vector3,
	options: Dictionary = {}
) -> Array[Dictionary]:
	if world == null or not _SPATIAL_BOUNDS_MATH.is_finite_vector3(from) or not _SPATIAL_BOUNDS_MATH.is_finite_vector3(to):
		return []

	var total_length: float = from.distance_to(to)
	if not _SPATIAL_BOUNDS_MATH.is_finite_float(total_length) or total_length <= 0.0:
		return []

	var max_results: int = maxi(GFVariantData.get_option_int(options, "max_results", DEFAULT_MAX_RAYCAST_RESULTS), 0)
	if max_results <= 0:
		return []

	var direction: Vector3 = (to - from).normalized()
	var requested_margin: float = GFVariantData.get_option_float(options, "margin", DEFAULT_RAYCAST_MARGIN)
	if not _SPATIAL_BOUNDS_MATH.is_finite_float(requested_margin):
		return []
	var margin: float = maxf(requested_margin, 0.0)
	var current_distance: float = 0.0
	var current_from: Vector3 = from
	var excludes: Array[RID] = _get_exclude_rids(options)
	var results: Array[Dictionary] = []
	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state

	for index: int in range(max_results):
		var query: PhysicsRayQueryParameters3D = _make_raycast_query_3d(current_from, to, excludes, options)
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			break

		var hit_position: Vector3 = GFVariantData.get_option_vector3(hit, "position", current_from)
		if not _SPATIAL_BOUNDS_MATH.is_finite_vector3(hit_position):
			break
		var hit_distance: float = clampf((hit_position - from).dot(direction), 0.0, total_length)
		var result: Dictionary = hit.duplicate(true)
		result["index"] = index
		result["distance"] = hit_distance
		results.append(result)

		var hit_rid: RID = _get_hit_rid(hit)
		if hit_rid.is_valid() and not excludes.has(hit_rid):
			excludes.append(hit_rid)

		var next_distance: float = hit_distance + margin
		if next_distance <= current_distance:
			next_distance = current_distance + DEFAULT_RAYCAST_MARGIN
		if next_distance >= total_length:
			break

		current_distance = next_distance
		current_from = from + direction * current_distance

	return results


# --- 私有/辅助方法 ---

func _make_raycast_query_3d(
	from: Vector3,
	to: Vector3,
	excludes: Array[RID],
	options: Dictionary
) -> PhysicsRayQueryParameters3D:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = GFVariantData.get_option_int(options, "collision_mask", 0xffffffff)
	query.exclude = excludes
	query.collide_with_bodies = GFVariantData.get_option_bool(options, "collide_with_bodies", true)
	query.collide_with_areas = GFVariantData.get_option_bool(options, "collide_with_areas", false)
	query.hit_back_faces = GFVariantData.get_option_bool(options, "hit_back_faces", true)
	query.hit_from_inside = GFVariantData.get_option_bool(options, "hit_from_inside", true)
	return query


func _get_exclude_rids(options: Dictionary) -> Array[RID]:
	var result: Array[RID] = []
	var values: Array = GFVariantData.get_option_array(options, "exclude", [])
	for value: Variant in values:
		if value is RID:
			var rid: RID = value
			if rid.is_valid() and not result.has(rid):
				result.append(rid)
		elif value is CollisionObject3D:
			var collision_object: CollisionObject3D = value
			var object_rid: RID = collision_object.get_rid()
			if object_rid.is_valid() and not result.has(object_rid):
				result.append(object_rid)
	return result


func _get_hit_rid(hit: Dictionary) -> RID:
	var rid_value: Variant = GFVariantData.get_option_value(hit, "rid", RID())
	if rid_value is RID:
		var rid: RID = rid_value
		return rid

	var collider_value: Variant = GFVariantData.get_option_value(hit, "collider")
	if collider_value is CollisionObject3D:
		var collider: CollisionObject3D = collider_value
		return collider.get_rid()

	return RID()
