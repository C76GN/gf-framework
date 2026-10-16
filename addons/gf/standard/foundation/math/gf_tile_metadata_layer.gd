## GFTileMetadataLayer: 通用格子元数据层。
##
## 在 Vector2i 格坐标上维护任意键值元数据，可服务于编辑器画刷、运行时标记、
## 规则查询或导出流程。它只管理数据结构，不绑定 TileSet、TileMapLayer 或项目业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFTileMetadataLayer
extends GFTileMapCache


# --- 导出变量 ---

## 可选字段 schema。框架不解释 schema 内容，项目可用于编辑器 UI、校验或导出。
## [br]
## @api public
## [br]
## @schema schema: Dictionary mapping metadata field names to project-defined field metadata.
@export var schema: Dictionary = {}


# --- 公共方法 ---

## 设置格子字段值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param cell: 格坐标。
## [br]
## @param key: 字段名。
## [br]
## @param value: 字段值。
## [br]
## @schema value: Variant metadata field value.
func set_cell_value(
	cell: Vector2i,
	key: StringName,
	value: Variant
) -> void:
	if key == &"":
		return
	var data: Dictionary = get_cell_data(cell)
	data[key] = GFVariantData.duplicate_variant(value)
	set_cell_data(cell, data)


## 获取格子数据副本。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @return 格子数据。
## [br]
## @schema return: Dictionary metadata record stored on the cell.
func get_cell_data(cell: Vector2i) -> Dictionary:
	if not cells.has(cell):
		return {}
	var value: Variant = cells[cell]
	if value is Dictionary:
		var data: Dictionary = GFVariantData.as_dictionary(value)
		return data.duplicate(true)
	return {}


## 获取格子字段值。
## [br]
## @api public
## [br]
## @since 3.17.0
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
## @schema return: Variant metadata field value or default_value.
func get_cell_value(
	cell: Vector2i,
	key: StringName,
	default_value: Variant = null
) -> Variant:
	var data: Dictionary = get_cell_data(cell)
	return GFVariantData.get_option_value(
		data,
		key,
		default_value
	)


## 合并格子数据。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param cell: 格坐标。
## [br]
## @param data: 要合并的数据。
## [br]
## @schema data: Dictionary metadata fields merged into the cell.
## [br]
## @param overwrite: 为 false 时不覆盖已有字段。
func merge_cell_data(
	cell: Vector2i,
	data: Dictionary,
	overwrite: bool = true
) -> void:
	var current: Dictionary = get_cell_data(cell)
	for key: Variant in data.keys():
		if overwrite or not current.has(key):
			current[key] = GFVariantData.duplicate_variant(data[key])
	set_cell_data(cell, current)


## 移除格子字段。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @param key: 字段名。
## [br]
## @return 成功移除返回 true。
func erase_cell_key(cell: Vector2i, key: StringName) -> bool:
	if not cells.has(cell):
		return false
	var value: Variant = cells[cell]
	if not (value is Dictionary):
		return false
	var data: Dictionary = GFVariantData.as_dictionary(value)
	if not data.has(key):
		return false
	var _erase_result_122: Variant = data.erase(key)
	if data.is_empty():
		erase_cell(cell)
	else:
		set_cell_data(cell, data)
	return true


## 检查格子字段是否存在。
## [br]
## @api public
## [br]
## @param cell: 格坐标。
## [br]
## @param key: 字段名。
## [br]
## @return 存在时返回 true。
func has_cell_key(cell: Vector2i, key: StringName) -> bool:
	if not cells.has(cell):
		return false
	var value: Variant = cells[cell]
	if not (value is Dictionary):
		return false
	return GFVariantData.as_dictionary(value).has(key)


## 批量为格子绘制同一个字段值。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param target_cells: 目标格子。
## [br]
## @param key: 字段名。
## [br]
## @param value: 字段值。
## [br]
## @schema value: Variant metadata field value painted into target cells.
## [br]
## @return 实际写入的格子数量。
func paint_cells(
	target_cells: Array[Vector2i],
	key: StringName,
	value: Variant
) -> int:
	if key == &"":
		return 0
	var count: int = 0
	for cell: Vector2i in target_cells:
		set_cell_value(
			cell,
			key,
			value
		)
		count += 1
	return count


## 批量移除格子字段。
## [br]
## @api public
## [br]
## @param target_cells: 目标格子。
## [br]
## @param key: 字段名。
## [br]
## @return 实际移除的字段数量。
func erase_cells_key(target_cells: Array[Vector2i], key: StringName) -> int:
	var count: int = 0
	for cell: Vector2i in target_cells:
		if erase_cell_key(cell, key):
			count += 1
	return count


## 查找拥有指定字段值的格子。
## [br]
## @api public
## [br]
## @param key: 字段名。
## [br]
## @param value: 目标值。
## [br]
## @schema value: Variant metadata field value to match.
## [br]
## @return 匹配格子列表。
func get_cells_with_value(key: StringName, value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		var cell_value: Variant = cells[cell]
		if (
			cell_value is Dictionary
			and GFVariantData.get_option_value(
				GFVariantData.as_dictionary(cell_value),
				key
			) == value
		):
			result.append(cell)
	return result


## 设置 schema 字段元数据。
## [br]
## @api public
## [br]
## @param key: 字段名。
## [br]
## @param metadata: 字段元数据。
## [br]
## @schema metadata: Dictionary project-defined schema metadata for a field.
func set_schema_entry(key: StringName, metadata: Dictionary) -> void:
	if key == &"":
		return
	schema[key] = metadata.duplicate(true)


## 获取 schema 字段元数据。
## [br]
## @api public
## [br]
## @param key: 字段名。
## [br]
## @return schema 元数据副本。
## [br]
## @schema return: Dictionary project-defined schema metadata for a field.
func get_schema_entry(key: StringName) -> Dictionary:
	var data: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(
			schema,
			key,
			{}
		)
	)
	return data.duplicate(true)


## 移除 schema 字段元数据。
## [br]
## @api public
## [br]
## @param key: 字段名。
func erase_schema_entry(key: StringName) -> void:
	var _erase_result_243: Variant = schema.erase(key)


## 转换为基础 TileMap 缓存。
## [br]
## @api public
## [br]
## @return 缓存副本。
func to_tile_map_cache() -> GFTileMapCache:
	var cache: GFTileMapCache = GFTileMapCache.new()
	for cell: Vector2i in cells:
		var value: Variant = cells[cell]
		if value is Dictionary:
			cache.set_cell_data(
				cell,
				GFVariantData.as_dictionary(value)
			)
	return cache


## 从基础 TileMap 缓存复制数据。
## [br]
## @api public
## [br]
## @param cache: 源缓存。
## [br]
## @param merge: 为 true 时合并到现有数据，否则先清空。
func from_tile_map_cache(cache: GFTileMapCache, merge: bool = false) -> void:
	if cache == null:
		return
	if not merge:
		clear()
	for cell: Vector2i in cache.cells:
		var value: Variant = cache.cells[cell]
		if value is Dictionary:
			set_cell_data(
				cell,
				GFVariantData.as_dictionary(value)
			)
