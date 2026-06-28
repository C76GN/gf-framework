@tool

## GFTileMetadataPaintTool: Tile 元数据绘制工具辅助。
##
## 为 `GFTileMetadataLayer` 提供编辑器友好的 patch、UndoRedo 和 overlay 数据。
## 它只处理通用格子元数据差异，不绑定 TileSet、TileMapLayer、寻路、地形或项目业务语义。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 7.0.0
class_name GFTileMetadataPaintTool
extends RefCounted


# --- 常量 ---

## 默认 overlay 颜色。
## [br]
## @api public
## [br]
## @since 7.0.0
const DEFAULT_OVERLAY_COLOR: Color = Color(0.2, 0.65, 1.0, 0.45)


# --- 公共方法 ---

## 创建一个绘制或擦除 patch，不修改 layer。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param layer: 目标元数据层。
## [br]
## @param target_cells: 目标格子。
## [br]
## @param key: 元数据字段名。
## [br]
## @param value: 绘制值；erase 为 true 时忽略。
## [br]
## @param erase: 为 true 时擦除字段。
## [br]
## @return patch 字典。
## [br]
## @schema target_cells: Array[Vector2i]，要绘制或擦除的格子。
## [br]
## @schema value: Variant metadata field value.
## [br]
## @schema return: Dictionary，包含 ok、key、erase、cells、before、after、changed_cells 和 changed_count。
static func make_paint_patch(
	layer: GFTileMetadataLayer,
	target_cells: Array[Vector2i],
	key: StringName,
	value: Variant,
	erase: bool = false
) -> Dictionary:
	var patch: Dictionary = _make_empty_patch(key, erase)
	if layer == null or key == &"":
		patch["ok"] = false
		return patch

	patch["ok"] = true
	var before: Dictionary = {}
	var after: Dictionary = {}
	var changed_cells: Array[Vector2i] = []
	for cell: Vector2i in _unique_sorted_cells(target_cells):
		var previous_data: Dictionary = layer.get_cell_data(cell)
		var next_data: Dictionary = previous_data.duplicate(true)
		if erase:
			var _erased_key: Variant = next_data.erase(key)
		else:
			next_data[key] = GFVariantData.duplicate_variant(value)

		if previous_data == next_data:
			continue
		before[cell] = previous_data
		after[cell] = next_data
		changed_cells.append(cell)

	patch["cells"] = changed_cells.duplicate()
	patch["before"] = before
	patch["after"] = after
	patch["changed_cells"] = changed_cells.duplicate()
	patch["changed_count"] = changed_cells.size()
	return patch


## 应用 paint patch。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param layer: 目标元数据层。
## [br]
## @param patch: make_paint_patch() 返回的 patch。
## [br]
## @return 应用报告。
## [br]
## @schema patch: Dictionary，包含 after 与 changed_cells。
## [br]
## @schema return: Dictionary，包含 ok、changed_count 和 changed_cells。
static func apply_paint_patch(layer: GFTileMetadataLayer, patch: Dictionary) -> Dictionary:
	return _apply_patch_side(layer, patch, "after")


## 回滚 paint patch。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param layer: 目标元数据层。
## [br]
## @param patch: make_paint_patch() 返回的 patch。
## [br]
## @return 回滚报告。
## [br]
## @schema patch: Dictionary，包含 before 与 changed_cells。
## [br]
## @schema return: Dictionary，包含 ok、changed_count 和 changed_cells。
static func revert_paint_patch(layer: GFTileMetadataLayer, patch: Dictionary) -> Dictionary:
	return _apply_patch_side(layer, patch, "before")


## 将 paint patch 写入 UndoRedo 兼容对象。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param layer: 目标元数据层。
## [br]
## @param patch: make_paint_patch() 返回的 patch。
## [br]
## @param undo_manager: EditorUndoRedoManager、UndoRedo 或兼容对象。
## [br]
## @param action_name: UndoRedo action 名称。
## [br]
## @param execute_immediately: 提交 action 时是否立即执行 do 方法。
## [br]
## @return Godot 错误码。
## [br]
## @schema patch: Dictionary，包含 before、after 与 changed_cells。
static func commit_paint_patch(
	layer: GFTileMetadataLayer,
	patch: Dictionary,
	undo_manager: Object,
	action_name: String = "Paint Tile Metadata",
	execute_immediately: bool = true
) -> Error:
	if layer == null or undo_manager == null:
		return ERR_INVALID_PARAMETER
	if not GFVariantData.get_option_bool(patch, "ok", false):
		return ERR_INVALID_PARAMETER
	if GFVariantData.get_option_int(patch, "changed_count") <= 0:
		return OK
	if not undo_manager.has_method("create_action"):
		return ERR_INVALID_PARAMETER
	if not undo_manager.has_method("add_do_method"):
		return ERR_INVALID_PARAMETER
	if not undo_manager.has_method("add_undo_method"):
		return ERR_INVALID_PARAMETER
	if not undo_manager.has_method("commit_action"):
		return ERR_INVALID_PARAMETER

	undo_manager.call("create_action", action_name)
	_add_patch_side_to_undo(layer, patch, undo_manager, "after", true)
	_add_patch_side_to_undo(layer, patch, undo_manager, "before", false)
	undo_manager.call("add_do_method", layer, "emit_changed")
	undo_manager.call("add_undo_method", layer, "emit_changed")
	undo_manager.call("commit_action", execute_immediately)
	return OK


## 读取 schema 字段选项。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param layer: 元数据层。
## [br]
## @return 字段选项数组。
## [br]
## @schema return: Array[Dictionary]，每项包含 key、metadata、color 和 value。
static func get_schema_field_options(layer: GFTileMetadataLayer) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if layer == null:
		return result

	var keys: Array[StringName] = []
	for key_variant: Variant in layer.schema.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		if key != &"":
			keys.append(key)
	keys.sort_custom(_sort_string_names)

	for key: StringName in keys:
		var metadata: Dictionary = layer.get_schema_entry(key)
		result.append({
			"key": key,
			"metadata": metadata.duplicate(true),
			"color": _get_schema_color(metadata, DEFAULT_OVERLAY_COLOR),
			"value": _get_schema_paint_value(metadata),
		})
	return result


## 获取单个格子的 overlay 分段数据。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param layer: 元数据层。
## [br]
## @param cell: 格坐标。
## [br]
## @param options: 可选项。支持 field_order、default_color、alpha 和 include_unconfigured。
## [br]
## @return overlay 分段数组。
## [br]
## @schema options: Dictionary，field_order 为字段顺序数组，default_color 为 Color，alpha 为透明度乘数，include_unconfigured 默认为 true。
## [br]
## @schema return: Array[Dictionary]，每项包含 key、value、color、index、count、start_ratio 和 end_ratio。
static func get_cell_overlay_segments(
	layer: GFTileMetadataLayer,
	cell: Vector2i,
	options: Dictionary = {}
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if layer == null:
		return result

	var cell_data: Dictionary = layer.get_cell_data(cell)
	if cell_data.is_empty():
		return result

	var ordered_keys: Array[StringName] = _get_ordered_cell_keys(cell_data, options)
	var include_unconfigured: bool = GFVariantData.get_option_bool(options, "include_unconfigured", true)
	var default_color: Color = _get_option_color(options, "default_color", DEFAULT_OVERLAY_COLOR)
	var alpha: float = clampf(GFVariantData.get_option_float(options, "alpha", 1.0), 0.0, 1.0)
	var segments: Array[Dictionary] = []
	for key: StringName in ordered_keys:
		var schema_entry: Dictionary = layer.get_schema_entry(key)
		if schema_entry.is_empty() and not include_unconfigured:
			continue
		var color: Color = _get_schema_color(schema_entry, default_color)
		color.a *= alpha
		segments.append({
			"key": key,
			"value": GFVariantData.duplicate_variant(GFVariantData.get_option_value(cell_data, key)),
			"color": color,
		})

	var count: int = segments.size()
	for index: int in range(count):
		var segment: Dictionary = segments[index]
		segment["index"] = index
		segment["count"] = count
		segment["start_ratio"] = float(index) / float(count)
		segment["end_ratio"] = float(index + 1) / float(count)
		result.append(segment)
	return result


# --- 私有/辅助方法 ---

static func _make_empty_patch(key: StringName, erase: bool) -> Dictionary:
	return {
		"ok": false,
		"key": key,
		"erase": erase,
		"cells": [],
		"before": {},
		"after": {},
		"changed_cells": [],
		"changed_count": 0,
	}


static func _apply_patch_side(layer: GFTileMetadataLayer, patch: Dictionary, side_key: String) -> Dictionary:
	var report: Dictionary = {
		"ok": layer != null and GFVariantData.get_option_bool(patch, "ok", false),
		"changed_count": 0,
		"changed_cells": [],
	}
	if not GFVariantData.get_option_bool(report, "ok"):
		return report

	var side: Dictionary = GFVariantData.get_option_dictionary(patch, side_key)
	var changed_cells: Array[Vector2i] = _variant_to_cell_array(GFVariantData.get_option_value(patch, "changed_cells", []))
	for cell: Vector2i in changed_cells:
		var data: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(side, cell, {}))
		if data.is_empty():
			layer.erase_cell(cell)
		else:
			layer.set_cell_data(cell, data)
	report["changed_count"] = changed_cells.size()
	report["changed_cells"] = changed_cells.duplicate()
	if not changed_cells.is_empty():
		layer.emit_changed()
	return report


static func _add_patch_side_to_undo(
	layer: GFTileMetadataLayer,
	patch: Dictionary,
	undo_manager: Object,
	side_key: String,
	do_side: bool
) -> void:
	var method_name: String = "add_do_method" if do_side else "add_undo_method"
	var side: Dictionary = GFVariantData.get_option_dictionary(patch, side_key)
	var changed_cells: Array[Vector2i] = _variant_to_cell_array(GFVariantData.get_option_value(patch, "changed_cells", []))
	for cell: Vector2i in changed_cells:
		var data: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(side, cell, {}))
		if data.is_empty():
			undo_manager.call(method_name, layer, "erase_cell", cell)
		else:
			undo_manager.call(method_name, layer, "set_cell_data", cell, data)


static func _unique_sorted_cells(target_cells: Array[Vector2i]) -> Array[Vector2i]:
	var seen: Dictionary = {}
	var result: Array[Vector2i] = []
	for cell: Vector2i in target_cells:
		if seen.has(cell):
			continue
		seen[cell] = true
		result.append(cell)
	result.sort_custom(_sort_cells)
	return result


static func _variant_to_cell_array(value: Variant) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not value is Array:
		return result
	for cell_variant: Variant in GFVariantData.as_array(value):
		if cell_variant is Vector2i:
			var cell: Vector2i = cell_variant
			result.append(cell)
	return result


static func _get_ordered_cell_keys(cell_data: Dictionary, options: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = []
	var seen: Dictionary = {}
	for key_variant: Variant in GFVariantData.get_option_array(options, "field_order"):
		var ordered_key: StringName = GFVariantData.to_string_name(key_variant)
		if ordered_key == &"" or seen.has(ordered_key) or not cell_data.has(ordered_key):
			continue
		seen[ordered_key] = true
		result.append(ordered_key)

	var remaining: Array[StringName] = []
	for key_variant: Variant in cell_data.keys():
		var key: StringName = GFVariantData.to_string_name(key_variant)
		if key != &"" and not seen.has(key):
			remaining.append(key)
	remaining.sort()
	result.append_array(remaining)
	return result


static func _get_schema_color(metadata: Dictionary, fallback: Color) -> Color:
	for key: StringName in [&"paint_color", &"editor_color", &"color"]:
		var color: Color = _variant_to_color(GFVariantData.get_option_value(metadata, key), Color(-1.0, -1.0, -1.0, -1.0))
		if color.r >= 0.0:
			return color
	return fallback


static func _get_schema_paint_value(metadata: Dictionary) -> Variant:
	if _has_metadata_key(metadata, &"paint_value"):
		return GFVariantData.duplicate_variant(_get_metadata_value(metadata, &"paint_value"))
	if _has_metadata_key(metadata, &"default"):
		return GFVariantData.duplicate_variant(_get_metadata_value(metadata, &"default"))
	return true


static func _has_metadata_key(metadata: Dictionary, key: StringName) -> bool:
	return metadata.has(key) or metadata.has(String(key))


static func _get_metadata_value(metadata: Dictionary, key: StringName) -> Variant:
	if metadata.has(key):
		return metadata[key]
	return metadata[String(key)]


static func _get_option_color(options: Dictionary, key: String, fallback: Color) -> Color:
	return _variant_to_color(GFVariantData.get_option_value(options, key), fallback)


static func _variant_to_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		var color: Color = value
		return color
	if value is String or value is StringName:
		var text: String = GFVariantData.to_text(value)
		if text.begins_with("#") or text.length() == 6 or text.length() == 8:
			return Color.html(text)
	return fallback


static func _sort_cells(left: Vector2i, right: Vector2i) -> bool:
	if left.y != right.y:
		return left.y < right.y
	return left.x < right.x


static func _sort_string_names(left: StringName, right: StringName) -> bool:
	return String(left) < String(right)
