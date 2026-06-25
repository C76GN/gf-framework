## GFTileMapCache: 通用格子数据快照与差分缓存。
##
## 用 Vector2i 管理格子字典数据，既可手动写入，也可从 TileMapLayer 采集基础
## source/atlas/alternative/terrain 信息。它不规定字段语义，项目可扩展记录内容。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFTileMapCache
extends Resource


# --- 导出变量 ---

## 格子数据，结构为 Vector2i -> Dictionary。
## [br]
## @api public
## [br]
## @schema cells: Dictionary mapping Vector2i cells to Dictionary cell records.
@export var cells: Dictionary = {}


# --- 公共方法 ---

## 从 TileMapLayer 更新缓存。
## [br]
## @api public
## [br]
## @param layer: 目标 TileMapLayer。
## [br]
## @param target_cells: 要更新的格子；为空时采集 layer.get_used_cells()。
func update_from_tile_map(layer: TileMapLayer, target_cells: Array[Vector2i] = []) -> void:
	if layer == null:
		return

	var cells_to_update: Array[Vector2i] = target_cells
	if cells_to_update.is_empty():
		cells_to_update = layer.get_used_cells()

	for cell: Vector2i in cells_to_update:
		var source_id: int = layer.get_cell_source_id(cell)
		if source_id == -1:
			erase_cell(cell)
			continue

		var record: Dictionary = {
			"source_id": source_id,
			"atlas_coords": layer.get_cell_atlas_coords(cell),
			"alternative_tile": layer.get_cell_alternative_tile(cell),
		}
		var tile_data: TileData = layer.get_cell_tile_data(cell)
		if tile_data != null:
			record["terrain"] = tile_data.terrain
			record["terrain_set"] = tile_data.terrain_set
		set_cell_data(cell, record)


## 将缓存写回 TileMapLayer。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param layer: 目标 TileMapLayer。
## [br]
## @param origin: 写回偏移，缓存坐标会加上该偏移。
## [br]
## @param options: 可选参数，支持 overwrite、erase_empty。
## [br]
## @schema options: Dictionary with optional `overwrite: bool` and `erase_empty: bool`.
## [br]
## @return 写回报告。
## [br]
## @schema return: Dictionary with ok, applied_count, skipped_count, erased_count, failed_count, applied_cells, skipped_cells, erased_cells, failed_cells, and error.
func apply_to_tile_map(
	layer: TileMapLayer,
	origin: Vector2i = Vector2i.ZERO,
	options: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = {
		"ok": layer != null,
		"applied_count": 0,
		"skipped_count": 0,
		"erased_count": 0,
		"failed_count": 0,
		"applied_cells": [],
		"skipped_cells": [],
		"erased_cells": [],
		"failed_cells": [],
		"error": "",
	}
	if layer == null:
		report["error"] = "TileMapLayer is null."
		return report

	var overwrite: bool = GFVariantData.get_option_bool(options, "overwrite", true)
	var erase_empty: bool = GFVariantData.get_option_bool(options, "erase_empty", true)
	for cell: Vector2i in _get_sorted_cells():
		var target_cell: Vector2i = cell + origin
		var record: Dictionary = _get_cell_record(cell)
		var source_id: int = _get_record_source_id(record)
		if source_id < 0:
			if erase_empty:
				layer.erase_cell(target_cell)
				_append_report_cell(report, "erased_cells", target_cell)
				report["erased_count"] = GFVariantData.get_option_int(report, "erased_count") + 1
			else:
				_append_report_cell(report, "skipped_cells", target_cell)
				report["skipped_count"] = GFVariantData.get_option_int(report, "skipped_count") + 1
			continue

		if not overwrite and layer.get_cell_source_id(target_cell) != -1:
			_append_report_cell(report, "skipped_cells", target_cell)
			report["skipped_count"] = GFVariantData.get_option_int(report, "skipped_count") + 1
			continue

		layer.set_cell(
			target_cell,
			source_id,
			_get_record_atlas_coords(record),
			_get_record_alternative_tile(record)
		)
		_append_report_cell(report, "applied_cells", target_cell)
		report["applied_count"] = GFVariantData.get_option_int(report, "applied_count") + 1

	report["failed_count"] = GFVariantData.get_option_array(report, "failed_cells").size()
	return report


## 提取区域片段。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param region: 要提取的区域。
## [br]
## @param normalize_origin: 为 true 时把区域左上角归一到 Vector2i.ZERO。
## [br]
## @return 新缓存。
func extract_region(region: Rect2i, normalize_origin: bool = true) -> GFTileMapCache:
	var result: GFTileMapCache = GFTileMapCache.new()
	if region.size.x <= 0 or region.size.y <= 0:
		return result

	for cell: Vector2i in cells:
		if not region.has_point(cell):
			continue
		var target_cell: Vector2i = cell - region.position if normalize_origin else cell
		result.set_cell_data(target_cell, _get_cell_record(cell))
	return result


## 创建坐标平移后的缓存副本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param offset: 坐标偏移。
## [br]
## @return 新缓存。
func translated(offset: Vector2i) -> GFTileMapCache:
	var result: GFTileMapCache = GFTileMapCache.new()
	for cell: Vector2i in cells:
		result.set_cell_data(cell + offset, _get_cell_record(cell))
	return result


## 获取缓存覆盖区域。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 覆盖区域；缓存为空时返回空 Rect2i。
func get_used_rect() -> Rect2i:
	if cells.is_empty():
		return Rect2i()

	var first: bool = true
	var min_cell: Vector2i = Vector2i.ZERO
	var max_cell: Vector2i = Vector2i.ZERO
	for cell: Vector2i in cells:
		if first:
			min_cell = cell
			max_cell = cell
			first = false
			continue
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)
	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)


## 设置一个格子的字典数据。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @param data: 格子数据。
## [br]
## @schema data: Dictionary cell record copied into the cache.
func set_cell_data(cell: Vector2i, data: Dictionary) -> void:
	cells[cell] = data.duplicate(true)


## 移除一个格子。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
func erase_cell(cell: Vector2i) -> void:
	var _erase_result_79: Variant = cells.erase(cell)


## 检查格子是否存在。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @return 存在时返回 true。
func has_cell(cell: Vector2i) -> bool:
	return cells.has(cell)


## 获取格子数据副本。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @return 格子数据。
## [br]
## @schema return: Dictionary cell record copy.
func get_cell_data(cell: Vector2i) -> Dictionary:
	var data: Dictionary = _get_cell_record(cell)
	if data.is_empty():
		return {}
	return data.duplicate(true)


## 获取格子字段值。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @param key: 字段名。
## [br]
## @param default_value: 默认值。
## [br]
## @schema default_value: Variant fallback value returned when the field is missing.
## [br]
## @return 字段值。
## [br]
## @schema return: Variant field value or default_value.
func get_value(cell: Vector2i, key: StringName, default_value: Variant = null) -> Variant:
	var data: Dictionary = _get_cell_record(cell)
	if data.is_empty():
		return default_value
	return GFVariantData.get_option_value(data, key, default_value)


## 清空缓存。
## [br]
## @api public
func clear() -> void:
	cells.clear()


## 和另一个缓存做差分。
## [br]
## @api public
## [br]
## @param other: 另一个缓存。
## [br]
## @param compare_key: 为空时比较完整字典；否则只比较指定字段。
## [br]
## @return 发生变化的格子列表。
func diff_cells(other: GFTileMapCache, compare_key: StringName = &"") -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if other == null:
		for cell: Vector2i in cells:
			result.append(cell)
		return result

	for cell: Vector2i in cells:
		if not other.cells.has(cell) or _cell_value_changed(cell, other, compare_key):
			result.append(cell)
	for cell: Vector2i in other.cells:
		if not cells.has(cell):
			result.append(cell)
	return result


## 序列化为字典。
## [br]
## @api public
## [br]
## @return 可保存的字典。
## [br]
## @schema return: Dictionary mapping string cell keys to Dictionary cell records.
func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for cell: Vector2i in cells:
		var record: Dictionary = _get_cell_record(cell)
		result["%d,%d" % [cell.x, cell.y]] = record.duplicate(true)
	return result


## 从字典恢复。
## [br]
## @api public
## [br]
## @param data: to_dict() 生成的数据。
## [br]
## @schema data: Dictionary mapping string cell keys to Dictionary cell records.
func from_dict(data: Dictionary) -> void:
	cells.clear()
	for key: Variant in data.keys():
		var cell: Vector2i = _parse_cell_key(GFVariantData.to_text(key))
		if cell == Vector2i(-2_147_483_648, -2_147_483_648):
			continue
		var record: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(data, key, {}))
		if not record.is_empty():
			cells[cell] = record.duplicate(true)


# --- 私有/辅助方法 ---

func _cell_value_changed(cell: Vector2i, other: GFTileMapCache, compare_key: StringName) -> bool:
	var current: Dictionary = _get_cell_record(cell)
	var previous: Dictionary = other._get_cell_record(cell)
	if compare_key == &"":
		return current != previous
	return GFVariantData.get_option_value(current, compare_key) != GFVariantData.get_option_value(previous, compare_key)


func _get_cell_record(cell: Vector2i) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(cells, cell, {}))


func _parse_cell_key(key: String) -> Vector2i:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return Vector2i(-2_147_483_648, -2_147_483_648)
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return Vector2i(-2_147_483_648, -2_147_483_648)
	return Vector2i(int(parts[0]), int(parts[1]))


func _get_sorted_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		result.append(cell)
	result.sort_custom(_sort_cells)
	return result


func _sort_cells(left: Vector2i, right: Vector2i) -> bool:
	if left.y != right.y:
		return left.y < right.y
	return left.x < right.x


func _get_record_source_id(record: Dictionary) -> int:
	return GFVariantData.get_option_int(record, "source_id", -1)


func _get_record_atlas_coords(record: Dictionary) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(record, "atlas_coords", Vector2i(-1, -1))
	if value is Vector2i:
		var vector: Vector2i = value
		return vector
	if value is Vector2:
		var vector_float: Vector2 = value
		return Vector2i(int(vector_float.x), int(vector_float.y))
	return Vector2i(-1, -1)


func _get_record_alternative_tile(record: Dictionary) -> int:
	return GFVariantData.get_option_int(record, "alternative_tile", 0)


func _append_report_cell(report: Dictionary, key: String, cell: Vector2i) -> void:
	var values: Array = GFVariantData.get_option_array(report, key)
	values.append(cell)
	report[key] = values
