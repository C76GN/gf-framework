## GFGridGenerationStep2D: 通用 2D 网格生成步骤。
##
## 将选择器命中的格子写入或移除一个 Variant 值。它只操作字典数据，
## 不绑定 TileMap、GridMap、房间、碰撞或具体玩法。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFGridGenerationStep2D
extends Resource


# --- 导出变量 ---

## 步骤标识。
## [br]
## @api public
@export var step_id: StringName = &""

## 格子选择器；为空时作用于全部候选格子。
## [br]
## @api public
@export var selection: GFGridSelection2D = null

## 要写入的值。
## [br]
## @api public
## [br]
## @schema value: Variant value written to selected cells.
@export var value: Variant = true

## 为 true 时移除选中格子，而不是写入值。
## [br]
## @api public
@export var erase_cells: bool = false

## 步骤元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary extension metadata for the generation step.
@export var metadata: Dictionary = {}


# --- 公共变量 ---

## 自定义值回调，签名为 func(cell: Vector2i, previous_value: Variant, context: Dictionary) -> Variant。
## [br]
## @api public
var value_callback: Callable = Callable()


# --- 公共方法 ---

## 应用生成步骤。
## [br]
## @api public
## [br]
## @param grid: 目标网格字典，key 为 Vector2i。
## [br]
## @schema grid: Dictionary mapping Vector2i cells to generated values; mutated in place.
## [br]
## @param candidates: 候选格子。
## [br]
## @param context: 项目自定义上下文。
## [br]
## @schema context: Dictionary project-defined generation context.
## [br]
## @return 被修改的格子数量。
func apply(
	grid: Dictionary,
	candidates: Array[Vector2i],
	context: Dictionary = {}
) -> int:
	var selected_cells: Array[Vector2i] = _select_cells(candidates, context)
	var changed_count: int = 0
	for cell: Vector2i in selected_cells:
		if erase_cells:
			if grid.has(cell):
				var _erase_result_82: Variant = grid.erase(cell)
				changed_count += 1
			continue

		var next_value: Variant = _resolve_value(cell, GFVariantData.get_option_value(grid, cell), context)
		grid[cell] = GFVariantData.duplicate_variant(next_value)
		changed_count += 1
	return changed_count


## 获取步骤诊断快照。
## [br]
## @api public
## [br]
## @return 诊断字典。
## [br]
## @schema return: Dictionary with step_id, erase_cells, has_selection, has_value_callback, and metadata.
func get_debug_snapshot() -> Dictionary:
	return {
		"step_id": step_id,
		"erase_cells": erase_cells,
		"has_selection": selection != null,
		"has_value_callback": value_callback.is_valid(),
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

## 无选择器时返回候选格子的副本，否则委托选择器筛选。
## [br]
## @api private
func _select_cells(candidates: Array[Vector2i], context: Dictionary) -> Array[Vector2i]:
	if selection == null:
		return candidates.duplicate()
	return selection.select_cells(candidates, context)


## 调用有效值回调并传入旧值副本；未配置回调时返回配置值的副本。
## [br]
## @api private
func _resolve_value(cell: Vector2i, previous_value: Variant, context: Dictionary) -> Variant:
	if value_callback.is_valid():
		return value_callback.call(cell, GFVariantData.duplicate_variant(previous_value), context)
	return GFVariantData.duplicate_variant(value)
