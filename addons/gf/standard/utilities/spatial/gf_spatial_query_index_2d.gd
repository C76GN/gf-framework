## GFSpatialQueryIndex2D: 2D 空间查询策略 facade。
##
## 在统一 API 后面封装线性扫描与四叉树索引，让项目可按数据规模切换策略。
## 它只维护调用方提供的 Rect2、metadata 和 GFSpatialQueryIdentity，不解释玩法过滤规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFSpatialQueryIndex2D
extends RefCounted


# --- 常量 ---

## 根据实体数量和 bounds 自动选择策略。
## [br]
## @api public
## [br]
## @since 7.0.0
const STRATEGY_AUTO: StringName = &"auto"

## 使用线性扫描。
## [br]
## @api public
## [br]
## @since 7.0.0
const STRATEGY_LINEAR: StringName = &"linear"

## 使用 GFQuadTreeUtility。
## [br]
## @api public
## [br]
## @since 7.0.0
const STRATEGY_QUADTREE: StringName = &"quadtree"

const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")
const _SPATIAL_BOUNDS_MATH = preload("res://addons/gf/standard/foundation/math/gf_spatial_bounds_math.gd")


# --- 公共变量 ---

## 当前策略。
## [br]
## @api public
## [br]
## @since 7.0.0
var strategy: StringName = STRATEGY_AUTO:
	set(value):
		strategy = _normalize_strategy(value)
		_mark_index_dirty()

## 索引世界边界。
## [br]
## @api public
## [br]
## @since 7.0.0
var bounds: Rect2 = Rect2():
	set(value):
		if not _SPATIAL_BOUNDS_MATH.is_finite_rect2(value):
			push_error("[GFSpatialQueryIndex2D] bounds 必须只包含有限值。")
			return
		bounds = _normalize_rect(value)
		_mark_index_dirty()

## auto 策略切换到四叉树的实体数量阈值。
## [br]
## @api public
## [br]
## @since 7.0.0
var auto_quadtree_threshold: int = 64:
	set(value):
		auto_quadtree_threshold = maxi(value, 1)
		_mark_index_dirty()

## 四叉树最大深度。
## [br]
## @api public
## [br]
## @since 7.0.0
var quadtree_max_depth: int = GFQuadTreeUtility.DEFAULT_MAX_DEPTH:
	set(value):
		quadtree_max_depth = maxi(value, 0)
		_mark_index_dirty()

## 四叉树单节点实体上限。
## [br]
## @api public
## [br]
## @since 7.0.0
var quadtree_max_entities: int = GFQuadTreeUtility.DEFAULT_MAX_ENTITIES:
	set(value):
		quadtree_max_entities = maxi(value, 1)
		_mark_index_dirty()


# --- 私有变量 ---

var _records: Dictionary = {}
var _quad_tree: GFQuadTreeUtility
var _quad_tree_key_by_id: Dictionary = {}
var _index_dirty: bool = true
var _backend_build_failed: bool = false


# --- 公共方法 ---

## 配置索引。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param world_bounds: 索引世界边界。
## [br]
## @param p_strategy: 查询策略。
## [br]
## @param options: 配置选项，支持 auto_quadtree_threshold、quadtree_max_depth 和 quadtree_max_entities。
## [br]
## @schema options: Dictionary，可包含 auto_quadtree_threshold、quadtree_max_depth 和 quadtree_max_entities。
## [br]
## @return 当前索引。
func configure(
	world_bounds: Rect2,
	p_strategy: StringName = STRATEGY_AUTO,
	options: Dictionary = {}
) -> GFSpatialQueryIndex2D:
	bounds = world_bounds
	strategy = p_strategy
	auto_quadtree_threshold = GFVariantData.get_option_int(options, "auto_quadtree_threshold", auto_quadtree_threshold)
	quadtree_max_depth = GFVariantData.get_option_int(options, "quadtree_max_depth", quadtree_max_depth)
	quadtree_max_entities = GFVariantData.get_option_int(options, "quadtree_max_entities", quadtree_max_entities)
	_mark_index_dirty()
	return self


## 插入或更新实体 Rect2。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entity: 实体标识或 Object。
## [br]
## @schema entity: Object, StringName, String, or int identity stored by value or weak Object reference.
## [br]
## @param rect: 实体包围矩形。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary copied into entity record metadata.
## [br]
## @return 成功时返回 true。
func upsert(entity: Variant, rect: Rect2, p_metadata: Dictionary = {}) -> bool:
	if not _SPATIAL_BOUNDS_MATH.is_finite_rect2(rect):
		return false
	var entity_key: String = _make_entity_key(entity)
	if entity_key.is_empty():
		return false

	var entity_record: Dictionary = _make_record(entity, _normalize_rect(rect), p_metadata)
	if entity_record.is_empty():
		return false
	_records[entity_key] = entity_record
	_mark_index_dirty()
	return true


## 插入或更新以点和半径表示的实体。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entity: 实体标识或 Object。
## [br]
## @schema entity: Object, StringName, String, or int identity stored by value or weak Object reference.
## [br]
## @param position: 实体位置。
## [br]
## @param radius: 包围半径。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary copied into entity record metadata.
## [br]
## @return 成功时返回 true。
func upsert_point(
	entity: Variant,
	position: Vector2,
	radius: float = 0.0,
	p_metadata: Dictionary = {}
) -> bool:
	if not _SPATIAL_BOUNDS_MATH.is_finite_vector2(position) or not _SPATIAL_BOUNDS_MATH.is_finite_float(radius):
		return false
	var safe_radius: float = maxf(radius, 0.0)
	return upsert(
		entity,
		Rect2(position - Vector2(safe_radius, safe_radius), Vector2(safe_radius * 2.0, safe_radius * 2.0)),
		p_metadata
	)


## 移除实体。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entity: 实体标识或 Object。
## [br]
## @schema entity: Object, StringName, String, or int identity stored by value or weak Object reference.
## [br]
## @return 找到并移除时返回 true。
func remove(entity: Variant) -> bool:
	var entity_key: String = _make_entity_key(entity)
	if entity_key.is_empty() or not _records.has(entity_key):
		return false
	var _removed: bool = _records.erase(entity_key)
	_mark_index_dirty()
	return true


## 清空索引。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_records.clear()
	_quad_tree_key_by_id.clear()
	_mark_index_dirty()


## 检查实体是否存在。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entity: 实体标识或 Object。
## [br]
## @schema entity: Object, StringName, String, or int identity stored by value or weak Object reference.
## [br]
## @return 存在时返回 true。
func has_entity(entity: Variant) -> bool:
	var entity_key: String = _make_entity_key(entity)
	if entity_key.is_empty():
		return false
	prune_invalid_entities()
	return _records.has(entity_key)


## 获取实体数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 实体数量。
func get_entity_count() -> int:
	prune_invalid_entities()
	return _records.size()


## 清理已释放 Object 实体。
## [br]
## @api public
## [br]
## @since 8.0.0
func prune_invalid_entities() -> void:
	var keys_to_remove: Array[String] = []
	for entity_key: String in _records.keys():
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_key])
		if not _record_is_valid(entity_record):
			keys_to_remove.append(entity_key)

	for entity_key: String in keys_to_remove:
		var _removed: bool = _records.erase(entity_key)
	if not keys_to_remove.is_empty():
		_mark_index_dirty()


## 获取实体记录副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entity: 实体标识或 Object。
## [br]
## @schema entity: Object, StringName, String, or int identity stored by value or weak Object reference.
## [br]
## @return 实体记录；不存在时为空字典。
## [br]
## @schema return: Dictionary，包含 identity、entity、bounds 和 metadata；int 身份会额外包含 entity_id。
func get_entity_record(entity: Variant) -> Dictionary:
	var entity_key: String = _make_entity_key(entity)
	if entity_key.is_empty() or not _records.has(entity_key):
		return {}
	return _record_to_snapshot(GFVariantData.as_dictionary(_records[entity_key]))


## 查询与 Rect2 相交的实体。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param area: 查询矩形。
## [br]
## @return 匹配实体数组。
## [br]
## @schema return: Array[Variant]，实体值来自调用方传入的 entity。
func query_rect(area: Rect2) -> Array[Variant]:
	var result: Array[Variant] = []
	return query_rect_into(area, result)


## 查询与 Rect2 相交的实体，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param area: 查询矩形。
## [br]
## @param out_entities: 接收匹配实体的数组。
## [br]
## @schema out_entities: Array[Variant]，实体值来自调用方传入的 entity。
## [br]
## @param clear_output: 为 true 时先清空 out_entities。
## [br]
## @return 同一个 out_entities 数组。
## [br]
## @schema return: Array[Variant]，同一个 out_entities 数组。
func query_rect_into(area: Rect2, out_entities: Array, clear_output: bool = true) -> Array:
	if clear_output:
		out_entities.clear()
	var records: Array[Dictionary] = []
	var _query_records_rect_result: Array[Dictionary] = query_records_rect_into(area, records)
	for entity_record: Dictionary in records:
		out_entities.append(GFVariantData.get_option_value(entity_record, "entity"))
	return out_entities


## 查询与圆相交的实体。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param center: 圆心。
## [br]
## @param radius: 半径。
## [br]
## @return 匹配实体数组。
## [br]
## @schema return: Array[Variant]，实体值来自调用方传入的 entity。
func query_radius(center: Vector2, radius: float) -> Array[Variant]:
	var result: Array[Variant] = []
	return query_radius_into(center, radius, result)


## 查询与圆相交的实体，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param center: 圆心。
## [br]
## @param radius: 半径。
## [br]
## @param out_entities: 接收匹配实体的数组。
## [br]
## @schema out_entities: Array[Variant]，实体值来自调用方传入的 entity。
## [br]
## @param clear_output: 为 true 时先清空 out_entities。
## [br]
## @return 同一个 out_entities 数组。
## [br]
## @schema return: Array[Variant]，同一个 out_entities 数组。
func query_radius_into(center: Vector2, radius: float, out_entities: Array, clear_output: bool = true) -> Array:
	if clear_output:
		out_entities.clear()
	var records: Array[Dictionary] = []
	var _query_records_radius_result: Array[Dictionary] = query_records_radius_into(center, radius, records)
	for entity_record: Dictionary in records:
		out_entities.append(GFVariantData.get_option_value(entity_record, "entity"))
	return out_entities


## 查询包含点的实体。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param point: 查询点。
## [br]
## @return 匹配实体数组。
## [br]
## @schema return: Array[Variant]，实体值来自调用方传入的 entity。
func query_point(point: Vector2) -> Array[Variant]:
	var result: Array[Variant] = []
	return query_point_into(point, result)


## 查询包含点的实体，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param point: 查询点。
## [br]
## @param out_entities: 接收匹配实体的数组。
## [br]
## @schema out_entities: Array[Variant]，实体值来自调用方传入的 entity。
## [br]
## @param clear_output: 为 true 时先清空 out_entities。
## [br]
## @return 同一个 out_entities 数组。
## [br]
## @schema return: Array[Variant]，同一个 out_entities 数组。
func query_point_into(point: Vector2, out_entities: Array, clear_output: bool = true) -> Array:
	if clear_output:
		out_entities.clear()
	var records: Array[Dictionary] = []
	_append_records_for_keys(_query_point_candidate_keys(point), records)
	for entity_record: Dictionary in records:
		out_entities.append(GFVariantData.get_option_value(entity_record, "entity"))
	return out_entities


## 查询与 Rect2 相交的实体记录。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param area: 查询矩形。
## [br]
## @return 匹配实体记录数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 identity、entity、bounds 和 metadata；int 身份会额外包含 entity_id。
func query_records_rect(area: Rect2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	return query_records_rect_into(area, result)


## 查询与 Rect2 相交的实体记录，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param area: 查询矩形。
## [br]
## @param out_records: 接收匹配实体记录的数组。
## [br]
## @param clear_output: 为 true 时先清空 out_records。
## [br]
## @return 同一个 out_records 数组。
## [br]
## @schema return: Array[Dictionary]，同一个 out_records 数组；每个元素包含 identity、entity、bounds 和 metadata。
## [br]
## @schema out_records: Array[Dictionary]，每个元素包含 identity、entity、bounds 和 metadata。
func query_records_rect_into(area: Rect2, out_records: Array[Dictionary], clear_output: bool = true) -> Array[Dictionary]:
	if clear_output:
		out_records.clear()
	if not _SPATIAL_BOUNDS_MATH.is_finite_rect2(area):
		return out_records
	var normalized_area: Rect2 = _normalize_rect(area)
	_append_records_for_keys(_query_rect_candidate_keys(normalized_area), out_records)
	return out_records


## 查询与圆相交的实体记录。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param center: 圆心。
## [br]
## @param radius: 半径。
## [br]
## @return 匹配实体记录数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 identity、entity、bounds 和 metadata；int 身份会额外包含 entity_id。
func query_records_radius(center: Vector2, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	return query_records_radius_into(center, radius, result)


## 查询与圆相交的实体记录，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param center: 圆心。
## [br]
## @param radius: 半径。
## [br]
## @param out_records: 接收匹配实体记录的数组。
## [br]
## @param clear_output: 为 true 时先清空 out_records。
## [br]
## @return 同一个 out_records 数组。
## [br]
## @schema return: Array[Dictionary]，同一个 out_records 数组；每个元素包含 identity、entity、bounds 和 metadata。
## [br]
## @schema out_records: Array[Dictionary]，每个元素包含 identity、entity、bounds 和 metadata。
func query_records_radius_into(
	center: Vector2,
	radius: float,
	out_records: Array[Dictionary],
	clear_output: bool = true
) -> Array[Dictionary]:
	if clear_output:
		out_records.clear()
	if not _SPATIAL_BOUNDS_MATH.is_finite_vector2(center) or not _SPATIAL_BOUNDS_MATH.is_finite_float(radius):
		return out_records
	var safe_radius: float = maxf(radius, 0.0)
	if safe_radius == 0.0:
		_append_records_for_keys(_query_point_candidate_keys(center), out_records)
		return out_records
	_append_records_for_keys(_query_radius_candidate_keys(center, safe_radius), out_records)
	return out_records


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 strategy、active_strategy、bounds、entity_count 和 index_dirty。
func get_debug_snapshot() -> Dictionary:
	prune_invalid_entities()
	return {
		"strategy": strategy,
		"active_strategy": _get_active_strategy(),
		"bounds": bounds,
		"entity_count": _records.size(),
		"index_dirty": _index_dirty,
		"backend_build_failed": _backend_build_failed,
		"auto_quadtree_threshold": auto_quadtree_threshold,
		"quadtree_max_depth": quadtree_max_depth,
		"quadtree_max_entities": quadtree_max_entities,
	}


## 获取 JSON.stringify() 安全的调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 报告编码选项，透传给 GFReportValueCodec。
## [br]
## @return: JSON 兼容调试快照。
## [br]
## @schema options: Dictionary with GFReportValueCodec options.
## [br]
## @schema return: Dictionary safe for JSON.stringify().
func get_json_compatible_debug_snapshot(options: Dictionary = {}) -> Dictionary:
	return GFVariantData.as_dictionary(_GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(get_debug_snapshot(), options))


# --- 私有/辅助方法 ---

func _query_rect_candidate_keys(area: Rect2) -> Array[String]:
	prune_invalid_entities()
	if _get_active_strategy() == STRATEGY_QUADTREE:
		return _surrogate_ids_to_entity_keys(_quad_tree.query_rect(area))
	return _query_rect_linear_keys(area)


func _query_radius_candidate_keys(center: Vector2, radius: float) -> Array[String]:
	prune_invalid_entities()
	if _get_active_strategy() == STRATEGY_QUADTREE:
		return _surrogate_ids_to_entity_keys(_quad_tree.query_radius(center, radius))
	return _query_radius_linear_keys(center, radius)


func _query_point_candidate_keys(point: Vector2) -> Array[String]:
	prune_invalid_entities()
	if not _SPATIAL_BOUNDS_MATH.is_finite_vector2(point):
		return []
	if _get_active_strategy() == STRATEGY_QUADTREE:
		return _surrogate_ids_to_entity_keys(_quad_tree.query_point(point, false))
	return _query_point_linear_keys(point)


func _query_rect_linear_keys(area: Rect2) -> Array[String]:
	var result: Array[String] = []
	for entity_key: String in _records.keys():
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_key])
		var entity_bounds: Rect2 = _get_record_bounds(entity_record)
		if entity_bounds.intersects(area):
			result.append(entity_key)
	return result


func _query_radius_linear_keys(center: Vector2, radius: float) -> Array[String]:
	var area: Rect2 = Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	var candidates: Array[String] = _query_rect_linear_keys(area)
	var result: Array[String] = []
	var radius_sq: float = radius * radius
	for entity_key: String in candidates:
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_key])
		var entity_bounds: Rect2 = _get_record_bounds(entity_record)
		var closest: Vector2 = Vector2(
			clampf(center.x, entity_bounds.position.x, entity_bounds.position.x + entity_bounds.size.x),
			clampf(center.y, entity_bounds.position.y, entity_bounds.position.y + entity_bounds.size.y)
		)
		if center.distance_squared_to(closest) <= radius_sq:
			result.append(entity_key)
	return result


func _query_point_linear_keys(point: Vector2) -> Array[String]:
	var result: Array[String] = []
	for entity_key: String in _records.keys():
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_key])
		if _rect_contains_point(_get_record_bounds(entity_record), point):
			result.append(entity_key)
	return result


func _append_records_for_keys(entity_keys: Array[String], out_records: Array[Dictionary]) -> void:
	var sorted_keys: Array[String] = entity_keys.duplicate()
	sorted_keys.sort_custom(GFSpatialQueryIdentity.sort_keys)
	var seen: Dictionary = {}
	for entity_key: String in sorted_keys:
		if seen.has(entity_key) or not _records.has(entity_key):
			continue
		seen[entity_key] = true
		out_records.append(_record_to_snapshot(GFVariantData.as_dictionary(_records[entity_key])))


func _ensure_quad_tree() -> bool:
	var world_bounds: Rect2 = _get_effective_bounds()
	if not _SPATIAL_BOUNDS_MATH.is_finite_rect2(world_bounds) or not _rect_has_area(world_bounds):
		return false
	if not _index_dirty:
		return _quad_tree != null and not _backend_build_failed

	var candidate_tree: GFQuadTreeUtility = GFQuadTreeUtility.new()
	candidate_tree.init()
	candidate_tree.setup(world_bounds, quadtree_max_depth, quadtree_max_entities)
	var candidate_keys: Dictionary = {}
	var surrogate_id: int = 0
	for entity_key: String in _records.keys():
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_key])
		candidate_keys[surrogate_id] = entity_key
		if not candidate_tree.insert(surrogate_id, _get_record_bounds(entity_record)):
			_quad_tree = null
			_quad_tree_key_by_id.clear()
			_index_dirty = false
			_backend_build_failed = true
			return false
		surrogate_id += 1
	_quad_tree = candidate_tree
	_quad_tree_key_by_id = candidate_keys
	_index_dirty = false
	_backend_build_failed = false
	return true


func _surrogate_ids_to_entity_keys(surrogate_ids: Array[int]) -> Array[String]:
	var result: Array[String] = []
	for surrogate_id: int in surrogate_ids:
		var entity_key: String = GFVariantData.get_option_string(_quad_tree_key_by_id, surrogate_id)
		if not entity_key.is_empty():
			result.append(entity_key)
	return result


func _derive_bounds_from_records() -> Rect2:
	var initialized: bool = false
	var result: Rect2 = Rect2()
	for entity_value: Variant in _records.values():
		var entity_record: Dictionary = GFVariantData.as_dictionary(entity_value)
		var entity_bounds: Rect2 = _get_record_bounds(entity_record)
		if not initialized:
			result = entity_bounds
			initialized = true
		else:
			result = result.merge(entity_bounds)
	return result


func _get_effective_bounds() -> Rect2:
	var record_bounds: Rect2 = _derive_bounds_from_records()
	if _rect_has_area(bounds) and _rect_has_area(record_bounds):
		return bounds.merge(record_bounds)
	if _rect_has_area(bounds):
		return bounds
	return record_bounds


func _get_active_strategy() -> StringName:
	var preferred_strategy: StringName = _get_preferred_strategy()
	if preferred_strategy == STRATEGY_QUADTREE and _ensure_quad_tree():
		return STRATEGY_QUADTREE
	return STRATEGY_LINEAR


func _get_preferred_strategy() -> StringName:
	if strategy == STRATEGY_LINEAR:
		return STRATEGY_LINEAR
	if strategy == STRATEGY_QUADTREE:
		return STRATEGY_QUADTREE
	if _records.size() >= auto_quadtree_threshold and _rect_has_area(_get_effective_bounds()):
		return STRATEGY_QUADTREE
	return STRATEGY_LINEAR


func _make_record(entity: Variant, rect: Rect2, p_metadata: Dictionary) -> Dictionary:
	var identity: GFSpatialQueryIdentity = GFSpatialQueryIdentity.from_value(entity)
	if identity.key.is_empty():
		return {}
	if identity.kind == GFSpatialQueryIdentity.KIND_OBJECT:
		var object: Object = identity.get_object()
		if object == null:
			return {}
		return {
			"identity": identity.to_dictionary(),
			"entity_ref": weakref(object),
			"entity": null,
			"bounds": rect,
			"metadata": p_metadata.duplicate(true),
		}
	return {
		"identity": identity.to_dictionary(),
		"entity_ref": null,
		"entity": identity.get_value(),
		"bounds": rect,
		"metadata": p_metadata.duplicate(true),
	}


func _record_to_snapshot(entity_record: Dictionary) -> Dictionary:
	var identity: Dictionary = GFVariantData.get_option_dictionary(entity_record, "identity").duplicate(true)
	var snapshot: Dictionary = {
		"identity": identity,
		"entity": _record_to_entity(entity_record),
		"bounds": _get_record_bounds(entity_record),
		"metadata": GFVariantData.get_option_dictionary(entity_record, "metadata").duplicate(true),
	}
	if GFVariantData.get_option_string_name(identity, "kind") == GFSpatialQueryIdentity.KIND_INT:
		snapshot["entity_id"] = GFVariantData.get_option_int(identity, "entity_id")
	return snapshot


func _record_to_entity(entity_record: Dictionary) -> Variant:
	var entity_ref_variant: Variant = GFVariantData.get_option_value(entity_record, "entity_ref")
	if entity_ref_variant is WeakRef:
		var entity_ref: WeakRef = _variant_to_weak_ref(entity_ref_variant)
		return entity_ref.get_ref()
	return GFVariantData.get_option_value(entity_record, "entity")


func _record_is_valid(entity_record: Dictionary) -> bool:
	if entity_record.is_empty():
		return false
	var entity_ref_variant: Variant = GFVariantData.get_option_value(entity_record, "entity_ref")
	if entity_ref_variant is WeakRef:
		var entity_ref: WeakRef = _variant_to_weak_ref(entity_ref_variant)
		return entity_ref.get_ref() != null
	return true


func _get_record_bounds(entity_record: Dictionary) -> Rect2:
	var value: Variant = GFVariantData.get_option_value(entity_record, "bounds", Rect2())
	if value is Rect2:
		var rect: Rect2 = value
		return rect
	return Rect2()


func _make_entity_key(entity: Variant) -> String:
	return GFSpatialQueryIdentity.make_key(entity)


func _mark_index_dirty() -> void:
	_index_dirty = true
	_backend_build_failed = false


func _normalize_strategy(value: StringName) -> StringName:
	match value:
		STRATEGY_LINEAR, STRATEGY_QUADTREE:
			return value
		_:
			return STRATEGY_AUTO


func _rect_has_area(rect: Rect2) -> bool:
	return rect.size.x > 0.0 and rect.size.y > 0.0


func _rect_contains_point(rect: Rect2, point: Vector2) -> bool:
	return (
		point.x >= rect.position.x
		and point.y >= rect.position.y
		and point.x <= rect.position.x + rect.size.x
		and point.y <= rect.position.y + rect.size.y
	)


func _normalize_rect(rect: Rect2) -> Rect2:
	return _SPATIAL_BOUNDS_MATH.normalize_rect2(rect)


func _variant_to_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var entity_ref: WeakRef = value
		return entity_ref
	return null
