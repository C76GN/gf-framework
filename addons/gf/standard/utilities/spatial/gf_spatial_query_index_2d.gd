## GFSpatialQueryIndex2D: 2D 空间查询策略 facade。
##
## 在统一 API 后面封装线性扫描与四叉树索引，让项目可按数据规模切换策略。
## 它只维护调用方提供的 Rect2 和 metadata，不解释实体身份或玩法过滤规则。
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
var _index_dirty: bool = true


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
## @param entity_id: 实体标识。
## [br]
## @param rect: 实体包围矩形。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary copied into entity record metadata.
## [br]
## @return 成功时返回 true。
func upsert(entity_id: int, rect: Rect2, p_metadata: Dictionary = {}) -> bool:
	if entity_id < 0:
		return false

	_records[entity_id] = {
		"entity_id": entity_id,
		"bounds": _normalize_rect(rect),
		"metadata": p_metadata.duplicate(true),
	}
	_mark_index_dirty()
	return true


## 插入或更新以点和半径表示的实体。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entity_id: 实体标识。
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
	entity_id: int,
	position: Vector2,
	radius: float = 0.0,
	p_metadata: Dictionary = {}
) -> bool:
	var safe_radius: float = maxf(radius, 0.0)
	return upsert(
		entity_id,
		Rect2(position - Vector2(safe_radius, safe_radius), Vector2(safe_radius * 2.0, safe_radius * 2.0)),
		p_metadata
	)


## 移除实体。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entity_id: 实体标识。
## [br]
## @return 找到并移除时返回 true。
func remove(entity_id: int) -> bool:
	if not _records.has(entity_id):
		return false
	var _removed: bool = _records.erase(entity_id)
	_mark_index_dirty()
	return true


## 清空索引。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_records.clear()
	_mark_index_dirty()


## 检查实体是否存在。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entity_id: 实体标识。
## [br]
## @return 存在时返回 true。
func has_entity(entity_id: int) -> bool:
	return _records.has(entity_id)


## 获取实体数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 实体数量。
func get_entity_count() -> int:
	return _records.size()


## 获取实体记录副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entity_id: 实体标识。
## [br]
## @return 实体记录；不存在时为空字典。
## [br]
## @schema return: Dictionary，包含 entity_id、bounds 和 metadata。
func get_entity_record(entity_id: int) -> Dictionary:
	if not _records.has(entity_id):
		return {}
	return _record_to_snapshot(GFVariantData.as_dictionary(_records[entity_id]))


## 查询与 Rect2 相交的实体 ID。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param area: 查询矩形。
## [br]
## @return 匹配实体 ID 数组。
func query_rect(area: Rect2) -> Array[int]:
	var result: Array[int] = []
	return query_rect_into(area, result)


## 查询与 Rect2 相交的实体 ID，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param area: 查询矩形。
## [br]
## @param out_entity_ids: 接收匹配实体 ID 的数组。
## [br]
## @param clear_output: 为 true 时先清空 out_entity_ids。
## [br]
## @return 同一个 out_entity_ids 数组。
func query_rect_into(area: Rect2, out_entity_ids: Array[int], clear_output: bool = true) -> Array[int]:
	var normalized_area: Rect2 = _normalize_rect(area)
	if clear_output:
		out_entity_ids.clear()
	if _get_active_strategy() == STRATEGY_QUADTREE and _ensure_quad_tree():
		out_entity_ids.append_array(_quad_tree.query_rect(normalized_area))
	else:
		_query_rect_linear_into(normalized_area, out_entity_ids)
	out_entity_ids.sort()
	return out_entity_ids


## 查询与圆相交的实体 ID。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param center: 圆心。
## [br]
## @param radius: 半径。
## [br]
## @return 匹配实体 ID 数组。
func query_radius(center: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	return query_radius_into(center, radius, result)


## 查询与圆相交的实体 ID，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param center: 圆心。
## [br]
## @param radius: 半径。
## [br]
## @param out_entity_ids: 接收匹配实体 ID 的数组。
## [br]
## @param clear_output: 为 true 时先清空 out_entity_ids。
## [br]
## @return 同一个 out_entity_ids 数组。
func query_radius_into(center: Vector2, radius: float, out_entity_ids: Array[int], clear_output: bool = true) -> Array[int]:
	var safe_radius: float = maxf(radius, 0.0)
	if clear_output:
		out_entity_ids.clear()
	if safe_radius == 0.0:
		return query_point_into(center, out_entity_ids, false)
	if _get_active_strategy() == STRATEGY_QUADTREE and _ensure_quad_tree():
		out_entity_ids.append_array(_quad_tree.query_radius(center, safe_radius))
	else:
		_query_radius_linear_into(center, safe_radius, out_entity_ids)
	out_entity_ids.sort()
	return out_entity_ids


## 查询包含点的实体 ID。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param point: 查询点。
## [br]
## @return 匹配实体 ID 数组。
func query_point(point: Vector2) -> Array[int]:
	var result: Array[int] = []
	return query_point_into(point, result)


## 查询包含点的实体 ID，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param point: 查询点。
## [br]
## @param out_entity_ids: 接收匹配实体 ID 的数组。
## [br]
## @param clear_output: 为 true 时先清空 out_entity_ids。
## [br]
## @return 同一个 out_entity_ids 数组。
func query_point_into(point: Vector2, out_entity_ids: Array[int], clear_output: bool = true) -> Array[int]:
	if clear_output:
		out_entity_ids.clear()
	if _get_active_strategy() == STRATEGY_QUADTREE and _ensure_quad_tree():
		out_entity_ids.append_array(_quad_tree.query_point(point, false))
	else:
		_query_point_linear_into(point, out_entity_ids)
	out_entity_ids.sort()
	return out_entity_ids


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
## @schema return: Array[Dictionary]，每个元素包含 entity_id、bounds 和 metadata。
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
## @schema return: Array[Dictionary]，同一个 out_records 数组；每个元素包含 entity_id、bounds 和 metadata。
## [br]
## @schema out_records: Array[Dictionary]，每个元素包含 entity_id、bounds 和 metadata。
func query_records_rect_into(area: Rect2, out_records: Array[Dictionary], clear_output: bool = true) -> Array[Dictionary]:
	var entity_ids: Array[int] = []
	var _query_rect_result: Array[int] = query_rect_into(area, entity_ids)
	_append_records_for_ids(entity_ids, out_records, clear_output)
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
## @schema return: Array[Dictionary]，每个元素包含 entity_id、bounds 和 metadata。
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
## @schema return: Array[Dictionary]，同一个 out_records 数组；每个元素包含 entity_id、bounds 和 metadata。
## [br]
## @schema out_records: Array[Dictionary]，每个元素包含 entity_id、bounds 和 metadata。
func query_records_radius_into(
	center: Vector2,
	radius: float,
	out_records: Array[Dictionary],
	clear_output: bool = true
) -> Array[Dictionary]:
	var entity_ids: Array[int] = []
	var _query_radius_result: Array[int] = query_radius_into(center, radius, entity_ids)
	_append_records_for_ids(entity_ids, out_records, clear_output)
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
	return {
		"strategy": strategy,
		"active_strategy": _get_active_strategy(),
		"bounds": bounds,
		"entity_count": _records.size(),
		"index_dirty": _index_dirty,
		"auto_quadtree_threshold": auto_quadtree_threshold,
		"quadtree_max_depth": quadtree_max_depth,
		"quadtree_max_entities": quadtree_max_entities,
	}


# --- 私有/辅助方法 ---

func _query_rect_linear_into(area: Rect2, out_entity_ids: Array[int]) -> void:
	for entity_id: int in _records.keys():
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_id])
		var entity_bounds: Rect2 = _get_record_bounds(entity_record)
		if entity_bounds.intersects(area):
			out_entity_ids.append(entity_id)


func _query_radius_linear_into(center: Vector2, radius: float, out_entity_ids: Array[int]) -> void:
	var area: Rect2 = Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0))
	var candidates: Array[int] = []
	_query_rect_linear_into(area, candidates)
	var radius_sq: float = radius * radius
	for entity_id: int in candidates:
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_id])
		var entity_bounds: Rect2 = _get_record_bounds(entity_record)
		var closest: Vector2 = Vector2(
			clampf(center.x, entity_bounds.position.x, entity_bounds.position.x + entity_bounds.size.x),
			clampf(center.y, entity_bounds.position.y, entity_bounds.position.y + entity_bounds.size.y)
		)
		if center.distance_squared_to(closest) <= radius_sq:
			out_entity_ids.append(entity_id)


func _query_point_linear_into(point: Vector2, out_entity_ids: Array[int]) -> void:
	for entity_id: int in _records.keys():
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_id])
		if _rect_contains_point(_get_record_bounds(entity_record), point):
			out_entity_ids.append(entity_id)


func _append_records_for_ids(
	entity_ids: Array[int],
	out_records: Array[Dictionary],
	clear_output: bool = true
) -> void:
	if clear_output:
		out_records.clear()
	for entity_id: int in entity_ids:
		if _records.has(entity_id):
			out_records.append(_record_to_snapshot(GFVariantData.as_dictionary(_records[entity_id])))


func _ensure_quad_tree() -> bool:
	var world_bounds: Rect2 = _get_effective_bounds()
	if not _rect_has_area(world_bounds):
		return false
	if _quad_tree != null and not _index_dirty:
		return true

	_quad_tree = GFQuadTreeUtility.new()
	_quad_tree.init()
	_quad_tree.setup(world_bounds, quadtree_max_depth, quadtree_max_entities)
	for entity_id: int in _records.keys():
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_id])
		_quad_tree.insert(entity_id, _get_record_bounds(entity_record))
	_index_dirty = false
	return true


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
	if strategy == STRATEGY_LINEAR:
		return STRATEGY_LINEAR
	if strategy == STRATEGY_QUADTREE:
		return STRATEGY_QUADTREE
	if _records.size() >= auto_quadtree_threshold and _rect_has_area(_get_effective_bounds()):
		return STRATEGY_QUADTREE
	return STRATEGY_LINEAR


func _record_to_snapshot(entity_record: Dictionary) -> Dictionary:
	return {
		"entity_id": GFVariantData.get_option_int(entity_record, "entity_id"),
		"bounds": _get_record_bounds(entity_record),
		"metadata": GFVariantData.get_option_dictionary(entity_record, "metadata").duplicate(true),
	}


func _get_record_bounds(entity_record: Dictionary) -> Rect2:
	var value: Variant = GFVariantData.get_option_value(entity_record, "bounds", Rect2())
	if value is Rect2:
		var rect: Rect2 = value
		return rect
	return Rect2()


func _mark_index_dirty() -> void:
	_index_dirty = true


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
	var position: Vector2 = rect.position
	var size: Vector2 = rect.size
	if size.x < 0.0:
		position.x += size.x
		size.x = -size.x
	if size.y < 0.0:
		position.y += size.y
		size.y = -size.y
	return Rect2(position, size)
