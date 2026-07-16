## GFGridTransform2D: 2D 矩形网格坐标变换工具。
##
## 提供旋转、镜像和对角翻转的纯坐标映射，可用于格子模板、画刷、
## 房间蓝图、棋盘片段或编辑器工具。它只处理 Vector2i / Vector2 坐标，
## 不绑定 TileMapLayer、TileSet、渲染、碰撞或项目业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.21.0
class_name GFGridTransform2D
extends RefCounted


# --- 枚举 ---

## 2D 矩形局部空间中的离散变换。
## [br]
## @api public
enum Transform {
	## 不变换。
	IDENTITY,
	## 顺时针旋转 90 度。
	ROTATE_90,
	## 旋转 180 度。
	ROTATE_180,
	## 顺时针旋转 270 度。
	ROTATE_270,
	## 沿 X 轴方向镜像，即左右翻转。
	MIRROR_X,
	## 沿 Y 轴方向镜像，即上下翻转。
	MIRROR_Y,
	## 沿左上到右下对角线翻转。
	DIAGONAL_MAIN,
	## 沿右上到左下对角线翻转。
	DIAGONAL_ANTI,
}


# --- 常量 ---

## 无效变换哨兵值。
## [br]
## @api public
const INVALID_TRANSFORM: int = -1


# --- 公共方法 ---

## 判断变换编号是否有效。
## [br]
## @api public
## [br]
## @param transform: Transform 枚举值。
## [br]
## @return 有效时返回 true。
static func is_transform_valid(transform: int) -> bool:
	return transform >= Transform.IDENTITY and transform <= Transform.DIAGONAL_ANTI


## 判断变换后宽高轴是否互换。
## [br]
## @api public
## [br]
## @param transform: Transform 枚举值。
## [br]
## @return 旋转 90/270 或对角翻转时返回 true。
static func is_axis_swapped(transform: int) -> bool:
	return (
		transform == Transform.ROTATE_90
		or transform == Transform.ROTATE_270
		or transform == Transform.DIAGONAL_MAIN
		or transform == Transform.DIAGONAL_ANTI
	)


## 获取变换后的矩形尺寸。
## [br]
## @api public
## [br]
## @param size: 原始矩形尺寸。
## [br]
## @param transform: Transform 枚举值。
## [br]
## @return 变换后的尺寸；无效尺寸时返回 Vector2i.ZERO。
static func get_transformed_size(size: Vector2i, transform: int) -> Vector2i:
	if not _is_size_positive(size) or not is_transform_valid(transform):
		return Vector2i.ZERO
	return Vector2i(size.y, size.x) if is_axis_swapped(transform) else size


## 获取逆变换。
## [br]
## @api public
## [br]
## @param transform: Transform 枚举值。
## [br]
## @return 对应逆变换；无效输入返回 INVALID_TRANSFORM。
static func get_inverse_transform(transform: int) -> int:
	match transform:
		Transform.IDENTITY:
			return Transform.IDENTITY
		Transform.ROTATE_90:
			return Transform.ROTATE_270
		Transform.ROTATE_180:
			return Transform.ROTATE_180
		Transform.ROTATE_270:
			return Transform.ROTATE_90
		Transform.MIRROR_X:
			return Transform.MIRROR_X
		Transform.MIRROR_Y:
			return Transform.MIRROR_Y
		Transform.DIAGONAL_MAIN:
			return Transform.DIAGONAL_MAIN
		Transform.DIAGONAL_ANTI:
			return Transform.DIAGONAL_ANTI
	return INVALID_TRANSFORM


## 变换局部格坐标。
## [br]
## @api public
## [br]
## @param cell: 原始局部格坐标，通常位于 `[0, size)`。
## [br]
## @param source_size: 原始矩形尺寸。
## [br]
## @param transform: Transform 枚举值。
## [br]
## @return 变换后的局部格坐标。
static func transform_local_cell(cell: Vector2i, source_size: Vector2i, transform: int) -> Vector2i:
	if not _is_size_positive(source_size) or not is_transform_valid(transform):
		return cell

	var max_x: int = source_size.x - 1
	var max_y: int = source_size.y - 1
	match transform:
		Transform.IDENTITY:
			return cell
		Transform.ROTATE_90:
			return Vector2i(max_y - cell.y, cell.x)
		Transform.ROTATE_180:
			return Vector2i(max_x - cell.x, max_y - cell.y)
		Transform.ROTATE_270:
			return Vector2i(cell.y, max_x - cell.x)
		Transform.MIRROR_X:
			return Vector2i(max_x - cell.x, cell.y)
		Transform.MIRROR_Y:
			return Vector2i(cell.x, max_y - cell.y)
		Transform.DIAGONAL_MAIN:
			return Vector2i(cell.y, cell.x)
		Transform.DIAGONAL_ANTI:
			return Vector2i(max_y - cell.y, max_x - cell.x)
	return cell


## 变换矩形内的全局格坐标。
## [br]
## @api public
## [br]
## @param cell: 原始格坐标。
## [br]
## @param source_rect: 原始矩形范围。
## [br]
## @param transform: Transform 枚举值。
## [br]
## @param target_origin: 变换后矩形的目标起点。
## [br]
## @return 变换后的格坐标。
static func transform_cell(
	cell: Vector2i,
	source_rect: Rect2i,
	transform: int,
	target_origin: Vector2i = Vector2i.ZERO
) -> Vector2i:
	if not _is_size_positive(source_rect.size) or not is_transform_valid(transform):
		return cell
	var local_cell: Vector2i = cell - source_rect.position
	return target_origin + transform_local_cell(local_cell, source_rect.size, transform)


## 批量变换矩形内的全局格坐标。
## [br]
## @api public
## [br]
## @param cells: 原始格坐标列表。
## [br]
## @param source_rect: 原始矩形范围。
## [br]
## @param transform: Transform 枚举值。
## [br]
## @param target_origin: 变换后矩形的目标起点。
## [br]
## @return 变换后的格坐标列表，顺序与输入一致。
static func transform_cells(
	cells: Array[Vector2i],
	source_rect: Rect2i,
	transform: int,
	target_origin: Vector2i = Vector2i.ZERO
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in cells:
		result.append(transform_cell(cell, source_rect, transform, target_origin))
	return result


## 变换四向单位方向。
## [br]
## 该方法只接受 `Vector2i.RIGHT`、`LEFT`、`DOWN`、`UP`。无效方向或无效变换返回
## `Vector2i.ZERO`，便于调用方把它作为非方向哨兵处理。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param direction: 原始四向单位方向。
## [br]
## @param transform: Transform 枚举值。
## [br]
## @return 变换后的四向单位方向；无效输入返回 Vector2i.ZERO。
static func transform_cardinal_direction(direction: Vector2i, transform: int) -> Vector2i:
	if not _is_cardinal_direction(direction) or not is_transform_valid(transform):
		return Vector2i.ZERO

	match transform:
		Transform.IDENTITY:
			return direction
		Transform.ROTATE_90:
			return Vector2i(-direction.y, direction.x)
		Transform.ROTATE_180:
			return -direction
		Transform.ROTATE_270:
			return Vector2i(direction.y, -direction.x)
		Transform.MIRROR_X:
			return Vector2i(-direction.x, direction.y)
		Transform.MIRROR_Y:
			return Vector2i(direction.x, -direction.y)
		Transform.DIAGONAL_MAIN:
			return Vector2i(direction.y, direction.x)
		Transform.DIAGONAL_ANTI:
			return Vector2i(-direction.y, -direction.x)
	return Vector2i.ZERO


## 变换局部连续坐标。
## [br]
## @api public
## [br]
## @param point: 原始局部坐标，通常位于 `[0, size]`。
## [br]
## @param source_size: 原始矩形尺寸。
## [br]
## @param transform: Transform 枚举值。
## [br]
## @return 变换后的局部坐标。
static func transform_local_point(point: Vector2, source_size: Vector2, transform: int) -> Vector2:
	if not _is_vector_size_positive(source_size) or not is_transform_valid(transform):
		return point

	match transform:
		Transform.IDENTITY:
			return point
		Transform.ROTATE_90:
			return Vector2(source_size.y - point.y, point.x)
		Transform.ROTATE_180:
			return Vector2(source_size.x - point.x, source_size.y - point.y)
		Transform.ROTATE_270:
			return Vector2(point.y, source_size.x - point.x)
		Transform.MIRROR_X:
			return Vector2(source_size.x - point.x, point.y)
		Transform.MIRROR_Y:
			return Vector2(point.x, source_size.y - point.y)
		Transform.DIAGONAL_MAIN:
			return Vector2(point.y, point.x)
		Transform.DIAGONAL_ANTI:
			return Vector2(source_size.y - point.y, source_size.x - point.x)
	return point


## 变换矩形内的全局连续坐标。
## [br]
## @api public
## [br]
## @param point: 原始坐标。
## [br]
## @param source_rect: 原始矩形范围。
## [br]
## @param transform: Transform 枚举值。
## [br]
## @param target_origin: 变换后矩形的目标起点。
## [br]
## @return 变换后的坐标。
static func transform_point(
	point: Vector2,
	source_rect: Rect2,
	transform: int,
	target_origin: Vector2 = Vector2.ZERO
) -> Vector2:
	if not _is_vector_size_positive(source_rect.size) or not is_transform_valid(transform):
		return point
	var local_point: Vector2 = point - source_rect.position
	return target_origin + transform_local_point(local_point, source_rect.size, transform)


# --- 私有/辅助方法 ---

static func _is_size_positive(size: Vector2i) -> bool:
	return size.x > 0 and size.y > 0


static func _is_cardinal_direction(direction: Vector2i) -> bool:
	return (
		direction == Vector2i.RIGHT
		or direction == Vector2i.LEFT
		or direction == Vector2i.DOWN
		or direction == Vector2i.UP
	)


static func _is_vector_size_positive(size: Vector2) -> bool:
	return size.x > 0.0 and size.y > 0.0
