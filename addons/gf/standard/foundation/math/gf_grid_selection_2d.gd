## GFGridSelection2D: 通用 2D 网格格子选择器。
##
## 从候选格子中筛选一批坐标。可通过显式包含/排除、矩形边界、
## 自定义回调或子类重写组合出项目自己的生成规则。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFGridSelection2D
extends Resource


# --- 导出变量 ---

## 显式包含的格子；为空时不限制。
## [br]
## @api public
@export var included_cells: Array[Vector2i] = []

## 显式排除的格子。
## [br]
## @api public
@export var excluded_cells: Array[Vector2i] = []

## 是否启用矩形边界过滤。
## [br]
## @api public
@export var use_bounds: bool = false

## 边界起点。
## [br]
## @api public
@export var bounds_position: Vector2i = Vector2i.ZERO

## 边界尺寸。
## [br]
## @api public
@export var bounds_size: Vector2i = Vector2i.ZERO

## 是否反转最终选择结果。
## [br]
## @api public
@export var invert: bool = false


# --- 公共变量 ---

## 自定义过滤回调，签名为 func(cell: Vector2i, context: Dictionary) -> bool。
## [br]
## @api public
var filter_callback: Callable = Callable()


# --- 公共方法 ---

## 从候选格子中选择坐标。
## [br]
## @api public
## [br]
## @param candidates: 候选格子。
## [br]
## @param context: 项目自定义上下文。
## [br]
## @schema context: Dictionary project-defined selection context.
## [br]
## @return 选中的格子。
func select_cells(candidates: Array[Vector2i], context: Dictionary = {}) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in candidates:
		var selected: bool = _matches_cell(cell, context)
		if invert:
			selected = not selected
		if selected:
			result.append(cell)
	return result


## 检查格子是否会被选择。
## [br]
## @api public
## [br]
## @param cell: 格子坐标。
## [br]
## @param context: 项目自定义上下文。
## [br]
## @schema context: Dictionary project-defined selection context.
## [br]
## @return 会被选择时返回 true。
func matches_cell(cell: Vector2i, context: Dictionary = {}) -> bool:
	var selected: bool = _matches_cell(cell, context)
	return not selected if invert else selected


# --- 可重写钩子 ---

## 执行单个格子的选择判断。子类可重写该方法定义项目自己的选择规则。
## [br]
## @api protected
## [br]
## @param cell: 格子坐标。
## [br]
## @param context: 项目自定义上下文。
## [br]
## @schema context: Dictionary project-defined selection context.
## [br]
## @return 选中该格子时返回 true。
func _matches_cell(cell: Vector2i, context: Dictionary) -> bool:
	if not included_cells.is_empty() and not included_cells.has(cell):
		return false
	if excluded_cells.has(cell):
		return false
	if use_bounds and not _is_in_bounds(cell):
		return false
	if filter_callback.is_valid():
		return GFVariantData.to_bool(filter_callback.call(cell, context))
	return true


# --- 私有/辅助方法 ---

## 在启用矩形范围尺寸有效时，判断格子是否位于左闭右开边界内。
## [br]
## @api private
func _is_in_bounds(cell: Vector2i) -> bool:
	return (
		bounds_size.x > 0
		and bounds_size.y > 0
		and cell.x >= bounds_position.x
		and cell.y >= bounds_position.y
		and cell.x < bounds_position.x + bounds_size.x
		and cell.y < bounds_position.y + bounds_size.y
	)
