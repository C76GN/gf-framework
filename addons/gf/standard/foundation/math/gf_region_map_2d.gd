## GFRegionMap2D: 通用二维区域分块数据映射。
##
## 按固定区域尺寸管理格子数据，并追踪发生变化的区域，适合大地图、编辑器批处理或局部保存。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFRegionMap2D
extends RefCounted


# --- 公共变量 ---

## 每个区域包含的格子尺寸；运行时修改会重新索引已有格子并标记受影响区域为脏。
## [br]
## @api public
## [br]
## @since 8.0.0
var region_size: Vector2i = Vector2i(32, 32):
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
var _region_size: Vector2i = Vector2i(32, 32)


# --- 公共方法 ---

## 根据格坐标获取区域键。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @return 区域键。
func get_region_key_for_cell(cell: Vector2i) -> Vector2i:
	var safe_size: Vector2i = _get_safe_region_size()
	return Vector2i(floori(float(cell.x) / float(safe_size.x)), floori(float(cell.y) / float(safe_size.y)))


## 设置格子数据。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @param value: 格子数据。
## [br]
## @schema value: Variant cell value stored in the region map.
func set_cell(cell: Vector2i, value: Variant) -> void:
	var region_key: Vector2i = get_region_key_for_cell(cell)
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
func get_cell(cell: Vector2i, default_value: Variant = null) -> Variant:
	var region_key: Vector2i = get_region_key_for_cell(cell)
	var region: Dictionary = _get_region(region_key)
	if region.is_empty() or not region.has(cell):
		return _copy_value(default_value)
	return _copy_value(region[cell])


## 移除格子数据。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @return 移除成功返回 true。
func erase_cell(cell: Vector2i) -> bool:
	var region_key: Vector2i = get_region_key_for_cell(cell)
	var region: Dictionary = _get_region(region_key)
	if region.is_empty() or not region.has(cell):
		return false
	var _erase_result_96: Variant = region.erase(cell)
	if region.is_empty():
		var _erase_result_98: Variant = _regions.erase(region_key)
	_mark_dirty(region_key)
	return true


## 检查格子是否存在。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @return 存在返回 true。
func has_cell(cell: Vector2i) -> bool:
	var region: Dictionary = _get_region(get_region_key_for_cell(cell))
	return region.has(cell)


## 获取区域内全部格子坐标。
## [br]
## @api public
## [br]
## @param region_key: 区域键。
## [br]
## @return 格坐标列表。
func get_region_cells(region_key: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var region: Dictionary = _get_region(region_key)
	for cell: Vector2i in region.keys():
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
## @schema return: Dictionary mapping Vector2i cells to stored cell values.
func get_region_snapshot(region_key: Vector2i) -> Dictionary:
	var region: Dictionary = _get_region(region_key)
	return region.duplicate(true) if duplicate_values else region.duplicate(false)


## 获取已存在的区域键。
## [br]
## @api public
## [br]
## @return 区域键列表。
func get_region_keys() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for region_key: Vector2i in _regions.keys():
		result.append(region_key)
	return result


## 获取脏区域键。
## [br]
## @api public
## [br]
## @return 脏区域键列表。
func get_dirty_region_keys() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for region_key: Vector2i in _dirty_regions.keys():
		result.append(region_key)
	return result


## 清理脏区域标记。
## [br]
## @api public
## [br]
## @param region_key: 指定区域；为 null 时清空全部。
## [br]
## @schema region_key: Variant null or Vector2i region key.
func clear_dirty(region_key: Variant = null) -> void:
	if region_key == null:
		_dirty_regions.clear()
	elif region_key is Vector2i:
		var _erase_result_179: Variant = _dirty_regions.erase(region_key)


## 清空全部区域数据。
## [br]
## @api public
func clear() -> void:
	var removed_region_keys: Array = _regions.keys()
	_regions.clear()
	_dirty_regions.clear()
	for region_key_variant: Variant in removed_region_keys:
		if region_key_variant is Vector2i:
			var region_key: Vector2i = region_key_variant
			_mark_dirty(region_key)


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 调试快照字典。
## [br]
## @schema return: Dictionary with region_size, region_count, and dirty_region_count.
func get_debug_snapshot() -> Dictionary:
	return {
		"region_size": region_size,
		"region_count": _regions.size(),
		"dirty_region_count": _dirty_regions.size(),
	}


# --- 私有/辅助方法 ---

func _set_region_size(value: Vector2i) -> void:
	var normalized_size: Vector2i = _normalize_region_size(value)
	if _region_size == normalized_size:
		return
	var previous_regions: Dictionary = _regions
	_region_size = normalized_size
	if not previous_regions.is_empty():
		_reindex_regions(previous_regions)


func _get_or_create_region(region_key: Vector2i) -> Dictionary:
	if not _regions.has(region_key):
		_regions[region_key] = {}
	return _get_region(region_key)


func _get_region(region_key: Vector2i) -> Dictionary:
	var region_variant: Variant = GFVariantData.get_option_value(_regions, region_key)
	if region_variant is Dictionary:
		return GFVariantData.as_dictionary(region_variant)
	return {}


func _mark_dirty(region_key: Vector2i) -> void:
	_dirty_regions[region_key] = true


func _copy_value(value: Variant) -> Variant:
	if not duplicate_values:
		return value
	return GFVariantData.duplicate_collection(value, true)


func _get_safe_region_size() -> Vector2i:
	return _normalize_region_size(_region_size)


func _normalize_region_size(value: Vector2i) -> Vector2i:
	return Vector2i(maxi(value.x, 1), maxi(value.y, 1))


func _reindex_regions(previous_regions: Dictionary) -> void:
	var previous_dirty_region_keys: Array = _dirty_regions.keys()
	_regions = {}
	_dirty_regions.clear()

	for region_key_variant: Variant in previous_regions.keys():
		if region_key_variant is Vector2i:
			var previous_region_key: Vector2i = region_key_variant
			_mark_dirty(previous_region_key)
	for region_key_variant: Variant in previous_dirty_region_keys:
		if region_key_variant is Vector2i:
			var previous_dirty_region_key: Vector2i = region_key_variant
			_mark_dirty(previous_dirty_region_key)

	for region_variant: Variant in previous_regions.values():
		if not (region_variant is Dictionary):
			continue
		var region: Dictionary = GFVariantData.as_dictionary(region_variant)
		for cell_variant: Variant in region.keys():
			if not (cell_variant is Vector2i):
				continue
			var cell: Vector2i = cell_variant
			var next_region_key: Vector2i = get_region_key_for_cell(cell)
			var next_region: Dictionary = _get_or_create_region(next_region_key)
			next_region[cell] = region[cell]
			_mark_dirty(next_region_key)
