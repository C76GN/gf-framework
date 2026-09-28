@tool

## GFPattern2D: 可复用的二维格子模式资源。
##
## 用 Array[Vector2i] 描述范围、形状、阵型或 tile pattern。它不规定格子语义，
## 只负责尺寸、去重、边界过滤和常用查询。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFPattern2D
extends Resource


# --- 导出变量 ---

## 模式编辑尺寸。小于 1 的分量会被钳制到 1。
## [br]
## @api public
@export var pattern_dimensions: Vector2i = Vector2i(7, 7):
	set(value):
		pattern_dimensions = Vector2i(maxi(value.x, 1), maxi(value.y, 1))
		normalize_cells()

## 启用的格子坐标列表。
## [br]
## @api public
@export var cells: Array[Vector2i] = []:
	set(value):
		cells = value.duplicate()
		normalize_cells()


# --- 公共方法 ---

## 检查格子是否在 pattern 尺寸内。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @return 在范围内返回 true。
func is_in_bounds(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x < pattern_dimensions.x
		and cell.y < pattern_dimensions.y
	)


## 检查格子是否启用。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @return 启用返回 true。
func has_cell(cell: Vector2i) -> bool:
	return cells.has(cell)


## 设置格子是否启用。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @param enabled: 是否启用。
## [br]
## @return 实际发生变化返回 true。
func set_cell(cell: Vector2i, enabled: bool) -> bool:
	if not is_in_bounds(cell):
		return false
	if enabled:
		return add_cell(cell)
	return remove_cell(cell)


## 添加格子。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @return 实际添加返回 true。
func add_cell(cell: Vector2i) -> bool:
	if not is_in_bounds(cell) or cells.has(cell):
		return false
	cells.append(cell)
	cells.sort_custom(_sort_cells)
	emit_changed()
	return true


## 移除格子。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @return 实际移除返回 true。
func remove_cell(cell: Vector2i) -> bool:
	if not cells.has(cell):
		return false
	cells.erase(cell)
	emit_changed()
	return true


## 清空所有格子。
## [br]
## @api public
func clear_cells() -> void:
	if cells.is_empty():
		return
	cells.clear()
	emit_changed()


## 获取格子列表副本。
## [br]
## @api public
## [br]
## @return 格子列表副本。
func get_cells() -> Array[Vector2i]:
	return cells.duplicate()


## 归一化格子列表，去重、排序并移除越界格子。
## [br]
## @api public
func normalize_cells() -> void:
	var normalized: Array[Vector2i] = []
	for cell: Vector2i in cells:
		if is_in_bounds(cell) and not normalized.has(cell):
			normalized.append(cell)
	normalized.sort_custom(_sort_cells)
	if normalized == cells:
		return
	cells = normalized
	emit_changed()


## 创建深拷贝。
## [br]
## @api public
## [br]
## @return 新 pattern 资源。
func duplicate_pattern() -> GFPattern2D:
	var pattern: GFPattern2D = GFPattern2D.new()
	pattern.pattern_dimensions = pattern_dimensions
	pattern.cells = cells.duplicate()
	return pattern


# --- 私有/辅助方法 ---

## 按 y 升序、再按 x 升序比较格子，用于稳定化 pattern 单元顺序。
## [br]
## @api private
## [br]
func _sort_cells(left: Vector2i, right: Vector2i) -> bool:
	if left.y == right.y:
		return left.x < right.x
	return left.y < right.y
