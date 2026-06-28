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
		cells.clear()
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


## 创建坐标变换后的缓存副本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param transform: GFGridTransform2D.Transform 枚举值。
## [br]
## @param options: 可选参数，支持 target_origin、normalize_origin。
## [br]
## @schema options: Dictionary with optional `target_origin: Vector2i` and `normalize_origin: bool`.
## [br]
## @return 新缓存。
func transformed(transform: int, options: Dictionary = {}) -> GFTileMapCache:
	var result: GFTileMapCache = GFTileMapCache.new()
	var source_rect: Rect2i = get_used_rect()
	if cells.is_empty() or source_rect.size.x <= 0 or source_rect.size.y <= 0:
		return result

	var normalize_origin: bool = GFVariantData.get_option_bool(options, "normalize_origin", true)
	var target_origin: Vector2i = _get_option_vector2i(
		options,
		"target_origin",
		Vector2i.ZERO if normalize_origin else source_rect.position
	)
	for cell: Vector2i in _get_sorted_cells():
		var target_cell: Vector2i = GFGridTransform2D.transform_cell(cell, source_rect, transform, target_origin)
		result.set_cell_data(target_cell, _get_cell_record(cell))
	return result


## 创建 tile identity 重映射后的缓存副本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param remaps: 重映射表。
## [br]
## @param options: 可选参数，支持 preserve_unknown。
## [br]
## @schema remaps: Dictionary mapping Vector4i(source_id, atlas_x, atlas_y, alternative_tile) or source_id int to Dictionary/Vector4i/int.
## [br]
## @schema options: Dictionary with optional preserve_unknown: bool.
## [br]
## @return 新缓存。
func remapped_tiles(remaps: Dictionary, options: Dictionary = {}) -> GFTileMapCache:
	var result: GFTileMapCache = GFTileMapCache.new()
	var preserve_unknown: bool = GFVariantData.get_option_bool(options, "preserve_unknown", true)
	for cell: Vector2i in _get_sorted_cells():
		var record: Dictionary = _get_cell_record(cell)
		var remapped_record: Dictionary = _remap_record(record, remaps, preserve_unknown)
		if remapped_record.is_empty() and not preserve_unknown:
			continue
		result.set_cell_data(cell, remapped_record)
	return result


## 创建坐标变换并重映射 tile identity 后的缓存副本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param transform: GFGridTransform2D.Transform 枚举值。
## [br]
## @param remaps: 重映射表。
## [br]
## @param options: 可选参数，支持 target_origin、normalize_origin、preserve_unknown。
## [br]
## @schema remaps: Dictionary mapping Vector4i(source_id, atlas_x, atlas_y, alternative_tile) or source_id int to Dictionary/Vector4i/int.
## [br]
## @schema options: Dictionary transform and remap options.
## [br]
## @return 新缓存。
func transformed_and_remapped(transform: int, remaps: Dictionary, options: Dictionary = {}) -> GFTileMapCache:
	return transformed(transform, options).remapped_tiles(remaps, options)


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
		return GFVariantData.duplicate_variant(default_value)
	return GFVariantData.duplicate_variant(GFVariantData.get_option_value(data, key, default_value))


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
		var parse_result: Dictionary = _parse_cell_key(GFVariantData.to_text(key))
		if not GFVariantData.get_option_bool(parse_result, "ok", false):
			continue

		var record_value: Variant = GFVariantData.get_option_value(data, key)
		if not (record_value is Dictionary):
			continue
		var record: Dictionary = record_value
		var cell: Vector2i = _get_parsed_cell(parse_result)
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


func _parse_cell_key(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split(",")
	if parts.size() != 2:
		return { "ok": false, "cell": Vector2i.ZERO }
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return { "ok": false, "cell": Vector2i.ZERO }
	return { "ok": true, "cell": Vector2i(int(parts[0]), int(parts[1])) }


func _get_parsed_cell(parse_result: Dictionary) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(parse_result, "cell", Vector2i.ZERO)
	if value is Vector2i:
		var cell: Vector2i = value
		return cell
	return Vector2i.ZERO


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


func _remap_record(record: Dictionary, remaps: Dictionary, preserve_unknown: bool) -> Dictionary:
	var identity: Vector4i = _make_tile_identity(record)
	var remap_value: Variant = null
	var has_remap: bool = false
	if remaps.has(identity):
		remap_value = remaps[identity]
		has_remap = true
	elif remaps.has(identity.x):
		remap_value = remaps[identity.x]
		has_remap = true

	if not has_remap:
		return record.duplicate(true) if preserve_unknown else {}

	var result: Dictionary = record.duplicate(true)
	if remap_value is Dictionary:
		var remap_dictionary: Dictionary = remap_value
		for key: Variant in remap_dictionary.keys():
			result[key] = GFVariantData.duplicate_variant(remap_dictionary[key], true, true)
		return result
	if remap_value is Vector4i:
		var vector_value: Vector4i = remap_value
		_apply_tile_identity(result, vector_value)
		return result
	if remap_value is Vector4:
		var float_vector: Vector4 = remap_value
		_apply_tile_identity(result, Vector4i(int(float_vector.x), int(float_vector.y), int(float_vector.z), int(float_vector.w)))
		return result
	if remap_value is int:
		var source_id: int = remap_value
		result["source_id"] = source_id
		return result
	return result


func _make_tile_identity(record: Dictionary) -> Vector4i:
	var atlas_coords: Vector2i = _get_record_atlas_coords(record)
	return Vector4i(
		_get_record_source_id(record),
		atlas_coords.x,
		atlas_coords.y,
		_get_record_alternative_tile(record)
	)


func _apply_tile_identity(record: Dictionary, identity: Vector4i) -> void:
	record["source_id"] = identity.x
	record["atlas_coords"] = Vector2i(identity.y, identity.z)
	record["alternative_tile"] = identity.w


func _get_option_vector2i(options: Dictionary, key: String, default_value: Vector2i) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(options, key, default_value)
	if value is Vector2i:
		var vector: Vector2i = value
		return vector
	if value is Vector2:
		var vector_float: Vector2 = value
		return Vector2i(int(vector_float.x), int(vector_float.y))
	return default_value


func _append_report_cell(report: Dictionary, key: String, cell: Vector2i) -> void:
	var values: Array = GFVariantData.get_option_array(report, key)
	values.append(cell)
	report[key] = values
