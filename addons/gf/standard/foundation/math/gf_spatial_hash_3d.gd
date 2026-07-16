## GFSpatialHash3D: 纯逻辑 3D 空间哈希。
##
## 适用于大量动态 3D 实体的粗粒度范围查询。它只维护 AABB 索引，
## 不负责物理碰撞、可见性或玩法规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFSpatialHash3D
extends RefCounted


# --- 常量 ---

## 单次插入或查询允许覆盖的默认最大哈希格子数。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_MAX_COVERED_CELLS: int = 262144

const _CELL_BOUNDARY_EPSILON_RATIO: float = 0.000001
const _DEFAULT_CELL_SIZE: float = 4.0
const _MIN_CELL_SIZE: float = 0.0001
const _MAX_SAFE_CELL_COORDINATE: float = 9.0e18
const _SPATIAL_BOUNDS_MATH = preload("res://addons/gf/standard/foundation/math/gf_spatial_bounds_math.gd")


# --- 公共变量 ---

## 单个哈希格子的世界尺寸。
## [br]
## @api public
var cell_size: float:
	get:
		return _cell_size
	set(value):
		if not _SPATIAL_BOUNDS_MATH.is_finite_float(value):
			push_error("[GFSpatialHash3D] cell_size 必须是有限浮点值。")
			return
		_cell_size = maxf(value, _MIN_CELL_SIZE)
		_rebuild()


## 单个 AABB 或格子范围允许覆盖的最大哈希格子数。
##
## 超过上限的插入会返回 false；超过上限的查询会返回空结果，避免误用超大范围导致
## 一帧内分配海量中间数组。
## [br]
## @api public
## [br]
## @since 7.0.0
var max_covered_cells: int:
	get:
		return _max_covered_cells
	set(value):
		_max_covered_cells = maxi(value, 1)
		_rebuild()


# --- 私有变量 ---

var _cell_size: float = _DEFAULT_CELL_SIZE
var _max_covered_cells: int = DEFAULT_MAX_COVERED_CELLS
var _entity_records: Dictionary = {}
var _bucket_entities: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(p_cell_size: float = _DEFAULT_CELL_SIZE) -> void:
	if not _SPATIAL_BOUNDS_MATH.is_finite_float(p_cell_size):
		push_error("[GFSpatialHash3D] cell_size 必须是有限浮点值。")
		_cell_size = _DEFAULT_CELL_SIZE
		return
	_cell_size = maxf(p_cell_size, _MIN_CELL_SIZE)


# --- 公共方法 ---

## 配置格子尺寸并清空索引。
## [br]
## @api public
## [br]
## @param p_cell_size: 单格世界尺寸。
func configure(p_cell_size: float) -> void:
	if not _SPATIAL_BOUNDS_MATH.is_finite_float(p_cell_size):
		push_error("[GFSpatialHash3D] cell_size 必须是有限浮点值。")
		return
	_cell_size = maxf(p_cell_size, _MIN_CELL_SIZE)
	clear()


## 获取世界坐标所在的哈希格子。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param position: 世界坐标。
## [br]
## @return 哈希格子坐标。
func get_cell_for_position(position: Vector3) -> Vector3i:
	if not _position_can_map_to_cell(position):
		return Vector3i.ZERO
	return _world_to_cell(position)


## 插入实体。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param entity: 实体标识或 Object。
## [br]
## @schema entity: Object, StringName, String, or int identity stored by value or weak Object reference.
## [br]
## @param bounds: 实体 AABB。
## [br]
## @return 成功时返回 true。
func insert(entity: Variant, bounds: AABB) -> bool:
	if not _SPATIAL_BOUNDS_MATH.is_finite_aabb(bounds):
		return false
	var entity_key: String = _make_entity_key(entity)
	if entity_key.is_empty():
		return false

	var normalized_bounds: AABB = _normalize_aabb(bounds)
	if not _aabb_can_map_to_cells(normalized_bounds):
		return false
	var span: Array[Vector3i] = _get_cell_span_for_aabb(normalized_bounds)
	if not _is_cell_span_within_limit(span):
		return false

	remove(entity)
	var cells: Array[Vector3i] = _get_cells_for_span(span)
	_entity_records[entity_key] = _make_entity_record(entity, normalized_bounds, cells)
	for cell_key: Vector3i in cells:
		var bucket: Array = _get_or_create_bucket(cell_key)
		if not bucket.has(entity_key):
			bucket.append(entity_key)
	return true


## 移除实体。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param entity: 实体标识或 Object。
## [br]
## @schema entity: Object, StringName, String, or int identity stored by value or weak Object reference.
func remove(entity: Variant) -> void:
	var entity_key: String = _make_entity_key(entity)
	if entity_key.is_empty() or not _entity_records.has(entity_key):
		return
	_remove_by_key(entity_key)


## 更新实体 AABB。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param entity: 实体标识或 Object。
## [br]
## @schema entity: Object, StringName, String, or int identity stored by value or weak Object reference.
## [br]
## @param bounds: 新 AABB。
## [br]
## @return 成功时返回 true。
func update(entity: Variant, bounds: AABB) -> bool:
	return insert(entity, bounds)


## 检查实体是否存在。
## [br]
## @api public
## [br]
## @since 3.17.0
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

	var record: Dictionary = _get_record(entity_key)
	if record.is_empty():
		return false
	if not _record_is_valid(record):
		_remove_by_key(entity_key)
		return false
	return true


## 获取实体数量。
## [br]
## @api public
## [br]
## @return 实体数量。
func get_entity_count() -> int:
	prune_invalid_entities()
	return _entity_records.size()


## 获取空间哈希调试快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary with cell_size, max_covered_cells, entity_count, bucket_count, max_bucket_size, and average_bucket_size.
func get_debug_snapshot() -> Dictionary:
	prune_invalid_entities()
	var bucket_count: int = _bucket_entities.size()
	var total_bucket_size: int = 0
	var max_bucket_size: int = 0
	for cell_key: Vector3i in _bucket_entities.keys():
		var bucket_size: int = _get_bucket(cell_key).size()
		total_bucket_size += bucket_size
		max_bucket_size = maxi(max_bucket_size, bucket_size)

	var average_bucket_size: float = 0.0
	if bucket_count > 0:
		average_bucket_size = float(total_bucket_size) / float(bucket_count)

	return {
		"cell_size": _cell_size,
		"max_covered_cells": _max_covered_cells,
		"entity_count": _entity_records.size(),
		"bucket_count": bucket_count,
		"max_bucket_size": max_bucket_size,
		"average_bucket_size": average_bucket_size,
	}


## 查询与 AABB 相交的实体。
## [br]
## @api public
## [br]
## @param area: 查询 AABB。
## [br]
## @return 实体数组。
## [br]
## @schema return: Array entity values restored from spatial hash records.
func query_aabb(area: AABB) -> Array[Variant]:
	prune_invalid_entities()
	if not _SPATIAL_BOUNDS_MATH.is_finite_aabb(area):
		return []
	var normalized_area: AABB = _normalize_aabb(area)
	if not _aabb_can_map_to_cells(normalized_area):
		return []
	var candidate_keys: Array[String] = _query_candidate_keys(normalized_area)
	var result: Array[Variant] = []
	for entity_key: String in candidate_keys:
		var record: Dictionary = _get_record(entity_key)
		if record.is_empty():
			continue
		var bounds: AABB = _get_record_bounds(record)
		if bounds.intersects(normalized_area):
			result.append(_record_to_entity(record))
	return result


## 查询与球体相交的实体。
## [br]
## @api public
## [br]
## @param center: 球心。
## [br]
## @param radius: 半径。
## [br]
## @return 实体数组。
## [br]
## @schema return: Array entity values restored from spatial hash records.
func query_radius(center: Vector3, radius: float) -> Array[Variant]:
	if not _SPATIAL_BOUNDS_MATH.is_finite_vector3(center) or not _SPATIAL_BOUNDS_MATH.is_finite_float(radius):
		return []
	var safe_radius: float = maxf(radius, 0.0)
	if not _SPATIAL_BOUNDS_MATH.is_finite_vector3(center - Vector3.ONE * safe_radius):
		return []
	if not _SPATIAL_BOUNDS_MATH.is_finite_vector3(center + Vector3.ONE * safe_radius):
		return []
	var candidates: Array[Variant] = []
	if safe_radius == 0.0:
		candidates = query_cell(_world_to_cell(center))
	else:
		var query_bounds: AABB = AABB(
			center - Vector3.ONE * safe_radius,
			Vector3.ONE * safe_radius * 2.0
		)
		candidates = query_aabb(query_bounds)
	var result: Array[Variant] = []
	var radius_sq: float = safe_radius * safe_radius
	for entity: Variant in candidates:
		var record: Dictionary = _get_record(_make_entity_key(entity))
		if record.is_empty():
			continue
		var bounds: AABB = _get_record_bounds(record)
		var closest: Vector3 = Vector3(
			clampf(center.x, bounds.position.x, bounds.position.x + bounds.size.x),
			clampf(center.y, bounds.position.y, bounds.position.y + bounds.size.y),
			clampf(center.z, bounds.position.z, bounds.position.z + bounds.size.z)
		)
		if center.distance_squared_to(closest) <= radius_sq:
			result.append(entity)
	return result


## 查询指定哈希格子中的候选实体。
##
## 返回值是该格子桶内的粗筛候选，调用方如需精确几何或玩法规则过滤，应继续使用自己的规则处理。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param cell: 哈希格子坐标。
## [br]
## @return 实体数组。
## [br]
## @schema return: Array entity values restored from spatial hash records.
func query_cell(cell: Vector3i) -> Array[Variant]:
	prune_invalid_entities()
	var result: Array[Variant] = []
	var seen: Dictionary = {}
	_append_cell_entities(cell, result, seen)
	return result


## 查询以中心格子为基准的哈希格子范围。
##
## `radius` 按轴表示要向外扩展的格子数；例如 `Vector3i(2, 0, 2)` 会查询同一 Y 层上
## X/Z 各扩展 2 格的区域。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param center_cell: 中心哈希格子。
## [br]
## @param radius: 各轴扩展格子数，负数会按绝对值处理。
## [br]
## @return 去重后的实体数组。
## [br]
## @schema return: Array entity values restored from spatial hash records.
func query_cell_range(center_cell: Vector3i, radius: Vector3i = Vector3i.ZERO) -> Array[Variant]:
	prune_invalid_entities()
	var safe_radius: Vector3i = Vector3i(absi(radius.x), absi(radius.y), absi(radius.z))
	var result: Array[Variant] = []
	if _get_cell_range_count(safe_radius) > _max_covered_cells:
		return result

	var seen: Dictionary = {}
	for x: int in range(center_cell.x - safe_radius.x, center_cell.x + safe_radius.x + 1):
		for y: int in range(center_cell.y - safe_radius.y, center_cell.y + safe_radius.y + 1):
			for z: int in range(center_cell.z - safe_radius.z, center_cell.z + safe_radius.z + 1):
				_append_cell_entities(Vector3i(x, y, z), result, seen)
	return result


## 清理已释放 Object 实体。
## [br]
## @api public
func prune_invalid_entities() -> void:
	var keys_to_remove: Array[String] = []
	for entity_key: String in _entity_records.keys():
		if not _record_is_valid(_get_record(entity_key)):
			keys_to_remove.append(entity_key)

	for entity_key: String in keys_to_remove:
		_remove_by_key(entity_key)


## 清空索引。
## [br]
## @api public
func clear() -> void:
	_entity_records.clear()
	_bucket_entities.clear()


# --- 私有/辅助方法 ---

func _get_or_create_bucket(cell_key: Vector3i) -> Array:
	if _bucket_entities.has(cell_key):
		return _get_bucket(cell_key)

	var bucket: Array = []
	_bucket_entities[cell_key] = bucket
	return bucket


func _get_bucket(cell_key: Vector3i) -> Array:
	var bucket_value: Variant = GFVariantData.get_option_value(_bucket_entities, cell_key, [])
	if bucket_value is Array:
		return GFVariantData.as_array(bucket_value)
	return []


func _get_record_bounds(record: Dictionary) -> AABB:
	return _variant_to_aabb(GFVariantData.get_option_value(record, "bounds", AABB()))


func _get_record_cells(record: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var cells_value: Variant = GFVariantData.get_option_value(record, "cells", [])
	if not (cells_value is Array):
		return result

	var cells: Array = GFVariantData.as_array(cells_value)
	for cell_value: Variant in cells:
		if cell_value is Vector3i:
			var cell: Vector3i = cell_value
			result.append(cell)
	return result


func _erase_dictionary_key(target: Dictionary, key: Variant) -> void:
	var _removed: bool = target.erase(key)


func _variant_to_aabb(value: Variant) -> AABB:
	if value is AABB:
		var result: AABB = value
		return result
	return AABB()


func _variant_to_object(value: Variant) -> Object:
	if value is Object:
		var result: Object = value
		return result
	return null


func _variant_to_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var result: WeakRef = value
		return result
	return null


func _query_candidate_keys(area: AABB) -> Array[String]:
	var result: Array[String] = []
	var span: Array[Vector3i] = _get_cell_span_for_aabb(area)
	if not _is_cell_span_within_limit(span):
		return result

	var seen: Dictionary = {}
	for cell_key: Vector3i in _get_cells_for_span(span):
		var bucket: Array = _get_bucket(cell_key)
		for entity_key: String in bucket:
			if seen.has(entity_key):
				continue
			seen[entity_key] = true
			result.append(entity_key)
	return result


func _append_cell_entities(cell_key: Vector3i, result: Array[Variant], seen: Dictionary) -> void:
	var bucket: Array = _get_bucket(cell_key)
	for entity_key: String in bucket:
		if seen.has(entity_key):
			continue
		var record: Dictionary = _get_record(entity_key)
		if record.is_empty():
			continue
		seen[entity_key] = true
		result.append(_record_to_entity(record))


func _get_cells_for_aabb(bounds: AABB) -> Array[Vector3i]:
	var span: Array[Vector3i] = _get_cell_span_for_aabb(bounds)
	if not _is_cell_span_within_limit(span):
		return []
	return _get_cells_for_span(span)


func _get_cells_for_span(span: Array[Vector3i]) -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if span.size() < 2:
		return cells
	var min_cell: Vector3i = span[0]
	var max_cell: Vector3i = span[1]
	for x: int in range(min_cell.x, max_cell.x + 1):
		for y: int in range(min_cell.y, max_cell.y + 1):
			for z: int in range(min_cell.z, max_cell.z + 1):
				cells.append(Vector3i(x, y, z))
	return cells


func _get_cell_span_for_aabb(bounds: AABB) -> Array[Vector3i]:
	var min_cell: Vector3i = _world_to_cell(bounds.position)
	var max_corner: Vector3 = _get_half_open_max_corner(bounds)
	var max_cell: Vector3i = _world_to_cell(max_corner)
	return [min_cell, max_cell]


func _is_cell_span_within_limit(span: Array[Vector3i]) -> bool:
	if span.size() < 2:
		return false
	var min_cell: Vector3i = span[0]
	var max_cell: Vector3i = span[1]
	var x_count: int = _get_limited_axis_cell_count(min_cell.x, max_cell.x)
	var y_count: int = _get_limited_axis_cell_count(min_cell.y, max_cell.y)
	var z_count: int = _get_limited_axis_cell_count(min_cell.z, max_cell.z)
	if x_count <= 0 or y_count <= 0 or z_count <= 0:
		return false
	if x_count > _divide_truncated(_max_covered_cells, y_count):
		return false
	var xy_count: int = x_count * y_count
	return z_count <= _divide_truncated(_max_covered_cells, xy_count)


func _get_cell_range_count(radius: Vector3i) -> int:
	var x_count: int = radius.x * 2 + 1
	var y_count: int = radius.y * 2 + 1
	var z_count: int = radius.z * 2 + 1
	return x_count * y_count * z_count


func _world_to_cell(position: Vector3) -> Vector3i:
	return Vector3i(
		floori(position.x / _cell_size),
		floori(position.y / _cell_size),
		floori(position.z / _cell_size)
	)


func _get_limited_axis_cell_count(minimum: int, maximum: int) -> int:
	var count: float = float(maximum) - float(minimum) + 1.0
	if not _SPATIAL_BOUNDS_MATH.is_finite_float(count) or count <= 0.0 or count > float(_max_covered_cells):
		return -1
	return int(count)


func _divide_truncated(numerator: int, denominator: int) -> int:
	@warning_ignore("integer_division")
	return numerator / denominator


func _aabb_can_map_to_cells(bounds: AABB) -> bool:
	return _position_can_map_to_cell(bounds.position) and _position_can_map_to_cell(_get_half_open_max_corner(bounds))


func _position_can_map_to_cell(position: Vector3) -> bool:
	if not _SPATIAL_BOUNDS_MATH.is_finite_vector3(position):
		return false
	var scaled: Vector3 = position / _cell_size
	return (
		_SPATIAL_BOUNDS_MATH.is_finite_vector3(scaled)
		and absf(scaled.x) <= _MAX_SAFE_CELL_COORDINATE
		and absf(scaled.y) <= _MAX_SAFE_CELL_COORDINATE
		and absf(scaled.z) <= _MAX_SAFE_CELL_COORDINATE
	)


func _make_entity_key(entity: Variant) -> String:
	return GFSpatialQueryIdentity.make_key(entity)


func _make_entity_record(entity: Variant, bounds: AABB, cells: Array[Vector3i]) -> Dictionary:
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
			"bounds": bounds,
			"cells": cells,
		}

	return {
		"identity": identity.to_dictionary(),
		"entity_ref": null,
		"entity": identity.get_value(),
		"bounds": bounds,
		"cells": cells,
	}


func _record_to_entity(record: Dictionary) -> Variant:
	var entity_ref_variant: Variant = GFVariantData.get_option_value(record, "entity_ref")
	if entity_ref_variant is WeakRef:
		var entity_ref: WeakRef = _variant_to_weak_ref(entity_ref_variant)
		return entity_ref.get_ref()
	return GFVariantData.get_option_value(record, "entity")


func _record_is_valid(record: Dictionary) -> bool:
	if record.is_empty():
		return false

	var entity_ref_variant: Variant = GFVariantData.get_option_value(record, "entity_ref")
	if entity_ref_variant is WeakRef:
		var entity_ref: WeakRef = _variant_to_weak_ref(entity_ref_variant)
		return entity_ref.get_ref() != null
	return true


func _get_record(entity_key: String) -> Dictionary:
	var record_variant: Variant = GFVariantData.get_option_value(_entity_records, entity_key, {})
	if record_variant is Dictionary:
		return GFVariantData.as_dictionary(record_variant)
	return {}


func _remove_by_key(entity_key: String) -> void:
	var record: Dictionary = _get_record(entity_key)
	if record.is_empty():
		return

	var cells: Array[Vector3i] = _get_record_cells(record)
	for cell_key: Vector3i in cells:
		if not _bucket_entities.has(cell_key):
			continue
		var bucket: Array = _get_bucket(cell_key)
		bucket.erase(entity_key)
		if bucket.is_empty():
			_erase_dictionary_key(_bucket_entities, cell_key)
	_erase_dictionary_key(_entity_records, entity_key)


func _normalize_aabb(bounds: AABB) -> AABB:
	return _SPATIAL_BOUNDS_MATH.normalize_aabb(bounds)


func _get_half_open_max_corner(bounds: AABB) -> Vector3:
	var max_corner: Vector3 = bounds.position + bounds.size
	if bounds.size.x > 0.0:
		max_corner.x = _get_half_open_axis_max(bounds.position.x, bounds.size.x)
	if bounds.size.y > 0.0:
		max_corner.y = _get_half_open_axis_max(bounds.position.y, bounds.size.y)
	if bounds.size.z > 0.0:
		max_corner.z = _get_half_open_axis_max(bounds.position.z, bounds.size.z)
	return max_corner


func _get_half_open_axis_max(axis_min: float, axis_size: float) -> float:
	var axis_max: float = axis_min + axis_size
	var epsilon: float = minf(axis_size * 0.5, _cell_size * _CELL_BOUNDARY_EPSILON_RATIO)
	return maxf(axis_min, axis_max - maxf(epsilon, 0.000000001))


func _rebuild() -> void:
	var records: Dictionary = _entity_records.duplicate(true)
	_entity_records.clear()
	_bucket_entities.clear()
	for record_variant: Variant in records.values():
		var record: Dictionary = GFVariantData.as_dictionary(record_variant)
		if record.is_empty() or not _record_is_valid(record):
			continue
		var _inserted: bool = insert(_record_to_entity(record), _get_record_bounds(record))
