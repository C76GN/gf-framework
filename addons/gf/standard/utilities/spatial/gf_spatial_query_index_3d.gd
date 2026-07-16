## GFSpatialQueryIndex3D: 3D 空间查询策略 facade。
##
## 在统一 API 后面封装线性扫描与空间哈希索引，让项目可按数据规模切换策略。
## 它只维护调用方提供的 AABB 和 metadata，不解释实体身份或玩法过滤规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 7.0.0
class_name GFSpatialQueryIndex3D
extends RefCounted


# --- 常量 ---

## 根据实体数量自动选择策略。
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

## 使用 GFSpatialHash3D。
## [br]
## @api public
## [br]
## @since 7.0.0
const STRATEGY_SPATIAL_HASH: StringName = &"spatial_hash"

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

## 空间哈希格子尺寸。
## [br]
## @api public
## [br]
## @since 7.0.0
var cell_size: float = 4.0:
	set(value):
		if not _SPATIAL_BOUNDS_MATH.is_finite_float(value):
			push_error("[GFSpatialQueryIndex3D] cell_size 必须是有限浮点值。")
			return
		cell_size = maxf(value, 0.0001)
		_mark_index_dirty()

## auto 策略切换到空间哈希的实体数量阈值。
## [br]
## @api public
## [br]
## @since 7.0.0
var auto_spatial_hash_threshold: int = 64:
	set(value):
		auto_spatial_hash_threshold = maxi(value, 1)
		_mark_index_dirty()


# --- 私有变量 ---

var _records: Dictionary = {}
var _spatial_hash: GFSpatialHash3D
var _index_dirty: bool = true
var _backend_build_failed: bool = false


# --- 公共方法 ---

## 配置索引。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param p_strategy: 查询策略。
## [br]
## @param options: 配置选项，支持 cell_size 和 auto_spatial_hash_threshold。
## [br]
## @schema options: Dictionary，可包含 cell_size: float 和 auto_spatial_hash_threshold: int。
## [br]
## @return 当前索引。
func configure(p_strategy: StringName = STRATEGY_AUTO, options: Dictionary = {}) -> GFSpatialQueryIndex3D:
	strategy = p_strategy
	cell_size = GFVariantData.get_option_float(options, "cell_size", cell_size)
	auto_spatial_hash_threshold = GFVariantData.get_option_int(options, "auto_spatial_hash_threshold", auto_spatial_hash_threshold)
	_mark_index_dirty()
	return self


## 插入或更新实体 AABB。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param entity: 实体标识或 Object。
## [br]
## @schema entity: Object, StringName, String, or int identity stored by value or weak Object reference.
## [br]
## @param entity_bounds: 实体包围盒。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary copied into entity record metadata.
## [br]
## @return 成功时返回 true。
func upsert(entity: Variant, entity_bounds: AABB, p_metadata: Dictionary = {}) -> bool:
	if not _SPATIAL_BOUNDS_MATH.is_finite_aabb(entity_bounds):
		return false
	var entity_key: String = _make_entity_key(entity)
	if entity_key.is_empty():
		return false

	_records[entity_key] = _make_record(entity, _normalize_aabb(entity_bounds), p_metadata)
	_mark_index_dirty()
	return true


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
## @since 7.0.0
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
## @schema return: Dictionary，包含 entity、bounds 和 metadata。
func get_entity_record(entity: Variant) -> Dictionary:
	var entity_key: String = _make_entity_key(entity)
	if entity_key.is_empty() or not _records.has(entity_key):
		return {}
	return _record_to_snapshot(GFVariantData.as_dictionary(_records[entity_key]))


## 查询与 AABB 相交的实体。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param area: 查询 AABB。
## [br]
## @return 匹配实体数组。
## [br]
## @schema return: Array[Variant]，实体值来自调用方传入的 entity。
func query_aabb(area: AABB) -> Array[Variant]:
	var result: Array[Variant] = []
	return query_aabb_into(area, result)


## 查询与 AABB 相交的实体，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param area: 查询 AABB。
## [br]
## @param out_entities: 接收匹配实体的数组。
## [br]
## @param clear_output: 为 true 时先清空 out_entities。
## [br]
## @return 同一个 out_entities 数组。
## [br]
## @schema return: Array[Variant]，同一个 out_entities 数组；实体值来自调用方传入的 entity。
## [br]
## @schema out_entities: Array[Variant]，实体值来自调用方传入的 entity。
func query_aabb_into(area: AABB, out_entities: Array, clear_output: bool = true) -> Array:
	if clear_output:
		out_entities.clear()
	var records: Array[Dictionary] = []
	var _query_records_aabb_result: Array[Dictionary] = query_records_aabb_into(area, records)
	for entity_record: Dictionary in records:
		out_entities.append(GFVariantData.get_option_value(entity_record, "entity"))
	return out_entities


## 查询与球体相交的实体。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param center: 球心。
## [br]
## @param radius: 半径。
## [br]
## @return 匹配实体数组。
## [br]
## @schema return: Array[Variant]，实体值来自调用方传入的 entity。
func query_radius(center: Vector3, radius: float) -> Array[Variant]:
	var result: Array[Variant] = []
	return query_radius_into(center, radius, result)


## 查询与球体相交的实体，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param center: 球心。
## [br]
## @param radius: 半径。
## [br]
## @param out_entities: 接收匹配实体的数组。
## [br]
## @param clear_output: 为 true 时先清空 out_entities。
## [br]
## @return 同一个 out_entities 数组。
## [br]
## @schema return: Array[Variant]，同一个 out_entities 数组；实体值来自调用方传入的 entity。
## [br]
## @schema out_entities: Array[Variant]，实体值来自调用方传入的 entity。
func query_radius_into(center: Vector3, radius: float, out_entities: Array, clear_output: bool = true) -> Array:
	if clear_output:
		out_entities.clear()
	var records: Array[Dictionary] = []
	var _query_records_radius_result: Array[Dictionary] = query_records_radius_into(center, radius, records)
	for entity_record: Dictionary in records:
		out_entities.append(GFVariantData.get_option_value(entity_record, "entity"))
	return out_entities


## 查询与 AABB 相交的实体记录。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param area: 查询 AABB。
## [br]
## @return 匹配实体记录数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 entity、bounds 和 metadata。
func query_records_aabb(area: AABB) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	return query_records_aabb_into(area, result)


## 查询与 AABB 相交的实体记录，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param area: 查询 AABB。
## [br]
## @param out_records: 接收匹配实体记录的数组。
## [br]
## @param clear_output: 为 true 时先清空 out_records。
## [br]
## @return 同一个 out_records 数组。
## [br]
## @schema return: Array[Dictionary]，同一个 out_records 数组；每个元素包含 entity、bounds 和 metadata。
## [br]
## @schema out_records: Array[Dictionary]，每个元素包含 entity、bounds 和 metadata。
func query_records_aabb_into(
	area: AABB,
	out_records: Array[Dictionary],
	clear_output: bool = true
) -> Array[Dictionary]:
	prune_invalid_entities()
	if clear_output:
		out_records.clear()
	if not _SPATIAL_BOUNDS_MATH.is_finite_aabb(area):
		return out_records
	var normalized_area: AABB = _normalize_aabb(area)
	var candidate_keys: Array[String] = []
	if _get_active_strategy() == STRATEGY_SPATIAL_HASH:
		for entity: Variant in _spatial_hash.query_aabb(normalized_area):
			var entity_key: String = _make_entity_key(entity)
			if not entity_key.is_empty():
				candidate_keys.append(entity_key)
	else:
		candidate_keys = _query_aabb_linear(normalized_area)
	_append_records_for_keys(candidate_keys, normalized_area, out_records)
	return out_records


## 查询与球体相交的实体记录。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param center: 球心。
## [br]
## @param radius: 半径。
## [br]
## @return 匹配实体记录数组。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 entity、bounds 和 metadata。
func query_records_radius(center: Vector3, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	return query_records_radius_into(center, radius, result)


## 查询与球体相交的实体记录，并写入调用方提供的数组。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param center: 球心。
## [br]
## @param radius: 半径。
## [br]
## @param out_records: 接收匹配实体记录的数组。
## [br]
## @param clear_output: 为 true 时先清空 out_records。
## [br]
## @return 同一个 out_records 数组。
## [br]
## @schema return: Array[Dictionary]，同一个 out_records 数组；每个元素包含 entity、bounds 和 metadata。
## [br]
## @schema out_records: Array[Dictionary]，每个元素包含 entity、bounds 和 metadata。
func query_records_radius_into(
	center: Vector3,
	radius: float,
	out_records: Array[Dictionary],
	clear_output: bool = true
) -> Array[Dictionary]:
	if clear_output:
		out_records.clear()
	if not _SPATIAL_BOUNDS_MATH.is_finite_vector3(center) or not _SPATIAL_BOUNDS_MATH.is_finite_float(radius):
		return out_records
	var safe_radius: float = maxf(radius, 0.0)
	if not _SPATIAL_BOUNDS_MATH.is_finite_vector3(center - Vector3.ONE * safe_radius):
		return out_records
	if not _SPATIAL_BOUNDS_MATH.is_finite_vector3(center + Vector3.ONE * safe_radius):
		return out_records
	if safe_radius == 0.0:
		_append_point_records(center, out_records)
		return out_records

	var area: AABB = AABB(center - Vector3.ONE * safe_radius, Vector3.ONE * safe_radius * 2.0)
	var candidates: Array[Dictionary] = []
	var _query_records_aabb_result: Array[Dictionary] = query_records_aabb_into(area, candidates)
	var radius_sq: float = safe_radius * safe_radius
	for entity_record: Dictionary in candidates:
		var entity_bounds: AABB = _get_record_bounds(entity_record)
		var closest: Vector3 = Vector3(
			clampf(center.x, entity_bounds.position.x, entity_bounds.position.x + entity_bounds.size.x),
			clampf(center.y, entity_bounds.position.y, entity_bounds.position.y + entity_bounds.size.y),
			clampf(center.z, entity_bounds.position.z, entity_bounds.position.z + entity_bounds.size.z)
		)
		if center.distance_squared_to(closest) <= radius_sq:
			out_records.append(entity_record)
	return out_records


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 strategy、active_strategy、cell_size、entity_count 和 index_dirty。
func get_debug_snapshot() -> Dictionary:
	prune_invalid_entities()
	return {
		"strategy": strategy,
		"active_strategy": _get_active_strategy(),
		"cell_size": cell_size,
		"entity_count": _records.size(),
		"index_dirty": _index_dirty,
		"backend_build_failed": _backend_build_failed,
		"auto_spatial_hash_threshold": auto_spatial_hash_threshold,
	}


## 获取 JSON.stringify() 安全的调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 报告编码选项，透传给 GFReportValueCodec。
## [br]
## @return JSON 兼容调试快照。
## [br]
## @schema options: Dictionary with GFReportValueCodec options.
## [br]
## @schema return: Dictionary safe for JSON.stringify().
func get_json_compatible_debug_snapshot(options: Dictionary = {}) -> Dictionary:
	return GFVariantData.as_dictionary(_GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(get_debug_snapshot(), options))


# --- 私有/辅助方法 ---

func _query_aabb_linear(area: AABB) -> Array[String]:
	var result: Array[String] = []
	for entity_key: String in _records.keys():
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_key])
		if _get_record_bounds(entity_record).intersects(area):
			result.append(entity_key)
	return result


func _append_records_for_keys(
	entity_keys: Array[String],
	filter_area: AABB,
	out_records: Array[Dictionary]
) -> void:
	var sorted_keys: Array[String] = entity_keys.duplicate()
	sorted_keys.sort_custom(_sort_entity_keys)
	var seen: Dictionary = {}
	for entity_key: String in sorted_keys:
		if seen.has(entity_key) or not _records.has(entity_key):
			continue
		seen[entity_key] = true
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_key])
		if _get_record_bounds(entity_record).intersects(filter_area):
			out_records.append(_record_to_snapshot(entity_record))


func _append_point_records(point: Vector3, out_records: Array[Dictionary]) -> void:
	prune_invalid_entities()
	if not _SPATIAL_BOUNDS_MATH.is_finite_vector3(point):
		return
	var candidate_keys: Array[String] = []
	if _get_active_strategy() == STRATEGY_SPATIAL_HASH:
		for entity: Variant in _spatial_hash.query_cell(_spatial_hash.get_cell_for_position(point)):
			var entity_key: String = _make_entity_key(entity)
			if not entity_key.is_empty():
				candidate_keys.append(entity_key)
	else:
		for entity_key: String in _records.keys():
			candidate_keys.append(entity_key)
	_append_point_records_for_keys(candidate_keys, point, out_records)


func _append_point_records_for_keys(
	entity_keys: Array[String],
	point: Vector3,
	out_records: Array[Dictionary]
) -> void:
	var sorted_keys: Array[String] = entity_keys.duplicate()
	sorted_keys.sort_custom(_sort_entity_keys)
	var seen: Dictionary = {}
	for entity_key: String in sorted_keys:
		if seen.has(entity_key) or not _records.has(entity_key):
			continue
		seen[entity_key] = true
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_key])
		if _aabb_contains_point(_get_record_bounds(entity_record), point):
			out_records.append(_record_to_snapshot(entity_record))


func _aabb_contains_point(bounds: AABB, point: Vector3) -> bool:
	return (
		point.x >= bounds.position.x
		and point.y >= bounds.position.y
		and point.z >= bounds.position.z
		and point.x <= bounds.position.x + bounds.size.x
		and point.y <= bounds.position.y + bounds.size.y
		and point.z <= bounds.position.z + bounds.size.z
	)


func _sort_entity_keys(left_key: String, right_key: String) -> bool:
	return GFSpatialQueryIdentity.sort_keys(left_key, right_key)


func _ensure_spatial_hash() -> bool:
	if not _index_dirty:
		return _spatial_hash != null and not _backend_build_failed

	var candidate_hash: GFSpatialHash3D = GFSpatialHash3D.new(cell_size)
	for entity_key: String in _records.keys():
		var entity_record: Dictionary = GFVariantData.as_dictionary(_records[entity_key])
		var entity: Variant = _record_to_entity(entity_record)
		if entity == null:
			continue
		if not candidate_hash.insert(entity, _get_record_bounds(entity_record)):
			_spatial_hash = null
			_index_dirty = false
			_backend_build_failed = true
			return false
	_spatial_hash = candidate_hash
	_index_dirty = false
	_backend_build_failed = false
	return true


func _get_active_strategy() -> StringName:
	var preferred_strategy: StringName = _get_preferred_strategy()
	if preferred_strategy == STRATEGY_SPATIAL_HASH and _ensure_spatial_hash():
		return STRATEGY_SPATIAL_HASH
	return STRATEGY_LINEAR


func _get_preferred_strategy() -> StringName:
	if strategy == STRATEGY_LINEAR:
		return STRATEGY_LINEAR
	if strategy == STRATEGY_SPATIAL_HASH:
		return STRATEGY_SPATIAL_HASH
	if _records.size() >= auto_spatial_hash_threshold:
		return STRATEGY_SPATIAL_HASH
	return STRATEGY_LINEAR


func _make_record(entity: Variant, entity_bounds: AABB, p_metadata: Dictionary) -> Dictionary:
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
			"bounds": entity_bounds,
			"metadata": p_metadata.duplicate(true),
		}

	return {
		"identity": identity.to_dictionary(),
		"entity_ref": null,
		"entity": identity.get_value(),
		"bounds": entity_bounds,
		"metadata": p_metadata.duplicate(true),
	}


func _record_to_snapshot(entity_record: Dictionary) -> Dictionary:
	return {
		"identity": GFVariantData.get_option_dictionary(entity_record, "identity").duplicate(true),
		"entity": _record_to_entity(entity_record),
		"bounds": _get_record_bounds(entity_record),
		"metadata": GFVariantData.get_option_dictionary(entity_record, "metadata").duplicate(true),
	}


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


func _get_record_bounds(entity_record: Dictionary) -> AABB:
	var value: Variant = GFVariantData.get_option_value(entity_record, "bounds", AABB())
	if value is AABB:
		var entity_bounds: AABB = value
		return entity_bounds
	return AABB()


func _make_entity_key(entity: Variant) -> String:
	return GFSpatialQueryIdentity.make_key(entity)


func _mark_index_dirty() -> void:
	_index_dirty = true
	_backend_build_failed = false


func _normalize_strategy(value: StringName) -> StringName:
	match value:
		STRATEGY_LINEAR, STRATEGY_SPATIAL_HASH:
			return value
		_:
			return STRATEGY_AUTO


func _normalize_aabb(entity_bounds: AABB) -> AABB:
	return _SPATIAL_BOUNDS_MATH.normalize_aabb(entity_bounds)


func _variant_to_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var entity_ref: WeakRef = value
		return entity_ref
	return null
