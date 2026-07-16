## GFRegionMap3D: 通用三维区域分块数据映射。
##
## 按固定三维区域尺寸管理格子数据，并追踪发生变化的区域，适合大世界格子缓存、局部保存或编辑器批处理。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.18.0
class_name GFRegionMap3D
extends RefCounted


# --- 公共变量 ---

## 每个区域包含的格子尺寸；运行时修改会重新索引已有格子并标记受影响区域为脏。
## [br]
## @api public
## [br]
## @since 8.0.0
var region_size: Vector3i = Vector3i(32, 32, 32):
	get:
		return _region_size
	set(value):
		_set_region_size(value)

## 读写值时是否复制集合类型。
## [br]
## @api public
var duplicate_values: bool = true


# --- 私有变量 ---

var _regions: Dictionary = {}
var _dirty_regions: Dictionary = {}
var _region_size: Vector3i = Vector3i(32, 32, 32)


# --- 公共方法 ---

## 根据格坐标获取区域键。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @return 区域键。
func get_region_key_for_cell(cell: Vector3i) -> Vector3i:
	var safe_size: Vector3i = _get_safe_region_size()
	return Vector3i(
		floori(float(cell.x) / float(safe_size.x)),
		floori(float(cell.y) / float(safe_size.y)),
		floori(float(cell.z) / float(safe_size.z))
	)


## 获取闭区间格子范围覆盖的全部区域键。
## [br]
## @api public
## [br]
## @param min_cell: 范围起点格坐标。
## [br]
## @param max_cell: 范围终点格坐标。
## [br]
## @return 区域键列表。
func get_region_keys_for_cell_bounds(min_cell: Vector3i, max_cell: Vector3i) -> Array[Vector3i]:
	var safe_min: Vector3i = Vector3i(
		mini(min_cell.x, max_cell.x),
		mini(min_cell.y, max_cell.y),
		mini(min_cell.z, max_cell.z)
	)
	var safe_max: Vector3i = Vector3i(
		maxi(min_cell.x, max_cell.x),
		maxi(min_cell.y, max_cell.y),
		maxi(min_cell.z, max_cell.z)
	)
	var min_region: Vector3i = get_region_key_for_cell(safe_min)
	var max_region: Vector3i = get_region_key_for_cell(safe_max)
	var result: Array[Vector3i] = []

	for x: int in range(min_region.x, max_region.x + 1):
		for y: int in range(min_region.y, max_region.y + 1):
			for z: int in range(min_region.z, max_region.z + 1):
				result.append(Vector3i(x, y, z))

	return result


## 设置格子数据。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @param value: 格子数据。
## [br]
## @schema value: Variant cell value stored in the region map.
func set_cell(cell: Vector3i, value: Variant) -> void:
	var region_key: Vector3i = get_region_key_for_cell(cell)
	var region: Dictionary = _get_or_create_region(region_key)
	region[cell] = _copy_value(value)
	_mark_dirty(region_key)


## 获取格子数据。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @param default_value: 缺失时返回的默认值。
## [br]
## @schema default_value: Variant fallback value returned when the cell is missing.
## [br]
## @return 格子数据。
## [br]
## @schema return: Variant cell value or default_value.
func get_cell(cell: Vector3i, default_value: Variant = null) -> Variant:
	var region_key: Vector3i = get_region_key_for_cell(cell)
	var region_variant: Variant = GFVariantData.get_option_value(_regions, region_key)
	if not region_variant is Dictionary:
		return _copy_value(default_value)

	var region: Dictionary = GFVariantData.as_dictionary(region_variant)
	if not region.has(cell):
		return _copy_value(default_value)

	return _copy_value(region[cell])


## 移除格子数据。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @return 移除成功返回 true。
func erase_cell(cell: Vector3i) -> bool:
	var region_key: Vector3i = get_region_key_for_cell(cell)
	var region_variant: Variant = GFVariantData.get_option_value(_regions, region_key)
	if not region_variant is Dictionary:
		return false

	var region: Dictionary = GFVariantData.as_dictionary(region_variant)
	if not region.has(cell):
		return false

	var _cell_erased: bool = region.erase(cell)
	if region.is_empty():
		var _region_erased: bool = _regions.erase(region_key)
	_mark_dirty(region_key)
	return true


## 检查格子是否存在。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @return 存在返回 true。
func has_cell(cell: Vector3i) -> bool:
	var region_variant: Variant = GFVariantData.get_option_value(_regions, get_region_key_for_cell(cell))
	if not region_variant is Dictionary:
		return false

	var region: Dictionary = GFVariantData.as_dictionary(region_variant)
	return region.has(cell)


## 获取区域内全部格子坐标。
## [br]
## @api public
## [br]
## @param region_key: 区域键。
## [br]
## @return 格坐标列表。
func get_region_cells(region_key: Vector3i) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	var region_variant: Variant = GFVariantData.get_option_value(_regions, region_key)
	if not region_variant is Dictionary:
		return result

	var region: Dictionary = GFVariantData.as_dictionary(region_variant)
	for cell: Vector3i in region.keys():
		result.append(cell)

	return result


## 获取区域数据快照。
## [br]
## @api public
## [br]
## @param region_key: 区域键。
## [br]
## @return 区域数据字典。
## [br]
## @schema return: Dictionary mapping Vector3i cells to stored cell values.
func get_region_snapshot(region_key: Vector3i) -> Dictionary:
	var region_variant: Variant = GFVariantData.get_option_value(_regions, region_key)
	if not region_variant is Dictionary:
		return {}

	var region: Dictionary = GFVariantData.as_dictionary(region_variant)
	return region.duplicate(true) if duplicate_values else region.duplicate(false)


## 获取已存在的区域键。
## [br]
## @api public
## [br]
## @return 区域键列表。
func get_region_keys() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for region_key: Vector3i in _regions.keys():
		result.append(region_key)
	return result


## 获取脏区域键。
## [br]
## @api public
## [br]
## @return 脏区域键列表。
func get_dirty_region_keys() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for region_key: Vector3i in _dirty_regions.keys():
		result.append(region_key)
	return result


## 清理脏区域标记。
## [br]
## @api public
## [br]
## @param region_key: 指定区域；为 null 时清空全部。
## [br]
## @schema region_key: Variant null or Vector3i region key.
func clear_dirty(region_key: Variant = null) -> void:
	if region_key == null:
		_dirty_regions.clear()
	elif region_key is Vector3i:
		var _erased: bool = _dirty_regions.erase(region_key)


## 清空全部区域数据。
## [br]
## @api public
func clear() -> void:
	var removed_region_keys: Array = _regions.keys()
	_regions.clear()
	_dirty_regions.clear()
	for region_key_variant: Variant in removed_region_keys:
		if region_key_variant is Vector3i:
			var region_key: Vector3i = region_key_variant
			_mark_dirty(region_key)


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 调试快照字典。
## [br]
## @schema return: Dictionary with region_size, region_count, cell_count, and dirty_region_count.
func get_debug_snapshot() -> Dictionary:
	return {
		"region_size": region_size,
		"region_count": _regions.size(),
		"cell_count": _get_cell_count(),
		"dirty_region_count": _dirty_regions.size(),
	}


# --- 私有/辅助方法 ---

func _set_region_size(value: Vector3i) -> void:
	var normalized_size: Vector3i = _normalize_region_size(value)
	if _region_size == normalized_size:
		return
	var previous_regions: Dictionary = _regions
	_region_size = normalized_size
	if not previous_regions.is_empty():
		_reindex_regions(previous_regions)


func _get_or_create_region(region_key: Vector3i) -> Dictionary:
	if not _regions.has(region_key):
		_regions[region_key] = {}
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_regions, region_key))


func _mark_dirty(region_key: Vector3i) -> void:
	_dirty_regions[region_key] = true


func _copy_value(value: Variant) -> Variant:
	if not duplicate_values:
		return value
	return GFVariantData.duplicate_collection(value, true)


func _get_safe_region_size() -> Vector3i:
	return _normalize_region_size(_region_size)


func _normalize_region_size(value: Vector3i) -> Vector3i:
	return Vector3i(
		maxi(value.x, 1),
		maxi(value.y, 1),
		maxi(value.z, 1)
	)


func _reindex_regions(previous_regions: Dictionary) -> void:
	var previous_dirty_region_keys: Array = _dirty_regions.keys()
	_regions = {}
	_dirty_regions.clear()

	for region_key_variant: Variant in previous_regions.keys():
		if region_key_variant is Vector3i:
			var previous_region_key: Vector3i = region_key_variant
			_mark_dirty(previous_region_key)
	for region_key_variant: Variant in previous_dirty_region_keys:
		if region_key_variant is Vector3i:
			var previous_dirty_region_key: Vector3i = region_key_variant
			_mark_dirty(previous_dirty_region_key)

	for region_variant: Variant in previous_regions.values():
		if not (region_variant is Dictionary):
			continue
		var region: Dictionary = GFVariantData.as_dictionary(region_variant)
		for cell_variant: Variant in region.keys():
			if not (cell_variant is Vector3i):
				continue
			var cell: Vector3i = cell_variant
			var next_region_key: Vector3i = get_region_key_for_cell(cell)
			var next_region: Dictionary = _get_or_create_region(next_region_key)
			next_region[cell] = region[cell]
			_mark_dirty(next_region_key)


func _get_cell_count() -> int:
	var count: int = 0
	for region_variant: Variant in _regions.values():
		if region_variant is Dictionary:
			var region: Dictionary = GFVariantData.as_dictionary(region_variant)
			count += region.size()
	return count
