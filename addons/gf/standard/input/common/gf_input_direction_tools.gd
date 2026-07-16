## GFInputDirectionTools: 二维输入方向处理工具。
##
## 提供径向 deadzone、2/4/8 向离散化、方向名称和反向方向映射。
## 它只处理纯 Vector2 数据，不读取 InputMap，也不规定动作命名。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
## [br]
## @layer standard/input
class_name GFInputDirectionTools
extends RefCounted


# --- 枚举 ---

## 方向吸附模式。
## [br]
## @api public
## [br]
## @since 8.0.0
enum SnapMode {
	## 保留连续模拟向量。
	ANALOG,
	## 只输出左右方向。
	HORIZONTAL_2,
	## 只输出上下方向。
	VERTICAL_2,
	## 输出上下左右四方向。
	CARDINAL_4,
	## 输出上下左右和四个对角方向。
	EIGHT_WAY,
}

## 二维离散方向。
## [br]
## @api public
## [br]
## @since 8.0.0
enum Direction2D {
	## 无方向。
	NONE,
	## 上方向。
	UP,
	## 右方向。
	RIGHT,
	## 下方向。
	DOWN,
	## 左方向。
	LEFT,
	## 右上方向。
	UP_RIGHT,
	## 左上方向。
	UP_LEFT,
	## 右下方向。
	DOWN_RIGHT,
	## 左下方向。
	DOWN_LEFT,
}


# --- 常量 ---

const _DIAGONAL_THRESHOLD: float = 0.38268343
const _EPSILON: float = 0.000001
const _DIRECTION_NAMES: Dictionary = {
	Direction2D.NONE: &"",
	Direction2D.UP: &"up",
	Direction2D.RIGHT: &"right",
	Direction2D.DOWN: &"down",
	Direction2D.LEFT: &"left",
	Direction2D.UP_RIGHT: &"up_right",
	Direction2D.UP_LEFT: &"up_left",
	Direction2D.DOWN_RIGHT: &"down_right",
	Direction2D.DOWN_LEFT: &"down_left",
}
const _DIRECTION_VECTORS: Dictionary = {
	Direction2D.NONE: Vector2.ZERO,
	Direction2D.UP: Vector2.UP,
	Direction2D.RIGHT: Vector2.RIGHT,
	Direction2D.DOWN: Vector2.DOWN,
	Direction2D.LEFT: Vector2.LEFT,
	Direction2D.UP_RIGHT: Vector2(1.0, -1.0),
	Direction2D.UP_LEFT: Vector2(-1.0, -1.0),
	Direction2D.DOWN_RIGHT: Vector2(1.0, 1.0),
	Direction2D.DOWN_LEFT: Vector2(-1.0, 1.0),
}
const _OPPOSITE_DIRECTIONS: Dictionary = {
	Direction2D.NONE: Direction2D.NONE,
	Direction2D.UP: Direction2D.DOWN,
	Direction2D.RIGHT: Direction2D.LEFT,
	Direction2D.DOWN: Direction2D.UP,
	Direction2D.LEFT: Direction2D.RIGHT,
	Direction2D.UP_RIGHT: Direction2D.DOWN_LEFT,
	Direction2D.UP_LEFT: Direction2D.DOWN_RIGHT,
	Direction2D.DOWN_RIGHT: Direction2D.UP_LEFT,
	Direction2D.DOWN_LEFT: Direction2D.UP_RIGHT,
}


# --- 公共方法 ---

## 对二维输入应用径向 deadzone。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param raw_direction: 原始二维输入。
## [br]
## @param deadzone: 死区阈值，自动钳制到 0.0 到 0.99。
## [br]
## @param rescale_after_deadzone: 是否把死区外剩余行程重映射到 0.0 到 1.0。
## [br]
## @return 处理后的二维输入。
static func apply_radial_deadzone(
	raw_direction: Vector2,
	deadzone: float,
	rescale_after_deadzone: bool = true
) -> Vector2:
	var magnitude: float = raw_direction.length()
	var threshold: float = clampf(deadzone, 0.0, 0.99)
	if magnitude <= threshold:
		return Vector2.ZERO
	if magnitude <= _EPSILON:
		return Vector2.ZERO
	if not rescale_after_deadzone:
		return raw_direction.limit_length(1.0)

	var remapped_magnitude: float = (minf(magnitude, 1.0) - threshold) / (1.0 - threshold)
	return raw_direction.normalized() * clampf(remapped_magnitude, 0.0, 1.0)


## 按指定模式把二维输入吸附到连续或离散方向。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param raw_direction: 原始二维输入。
## [br]
## @param mode: 吸附模式。
## [br]
## @param deadzone: 死区阈值，自动钳制到 0.0 到 0.99。
## [br]
## @param rescale_analog_after_deadzone: ANALOG 模式下是否把死区外剩余行程重映射到 0.0 到 1.0。
## [br]
## @return 处理后的方向；离散模式下每个轴只会是 -1.0、0.0 或 1.0。
static func snap_vector(
	raw_direction: Vector2,
	mode: SnapMode = SnapMode.CARDINAL_4,
	deadzone: float = 0.0,
	rescale_analog_after_deadzone: bool = false
) -> Vector2:
	if mode == SnapMode.ANALOG:
		return apply_radial_deadzone(raw_direction, deadzone, rescale_analog_after_deadzone)

	var magnitude: float = raw_direction.length()
	if magnitude <= clampf(deadzone, 0.0, 0.99) or magnitude <= _EPSILON:
		return Vector2.ZERO

	var direction: Vector2 = raw_direction / magnitude
	match mode:
		SnapMode.HORIZONTAL_2:
			return Vector2(signf(direction.x), 0.0) if absf(direction.x) > _EPSILON else Vector2.ZERO
		SnapMode.VERTICAL_2:
			return Vector2(0.0, signf(direction.y)) if absf(direction.y) > _EPSILON else Vector2.ZERO
		SnapMode.CARDINAL_4:
			return _snap_cardinal(direction)
		SnapMode.EIGHT_WAY:
			return _snap_eight_way(direction)
		_:
			return Vector2.ZERO


## 按枚举获取方向名称。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param direction: 方向枚举。
## [br]
## @return 方向名称；NONE 返回空 StringName。
static func get_direction_name(direction: Direction2D) -> StringName:
	var raw_name: Variant = GFVariantData.get_option_value(_DIRECTION_NAMES, direction, &"")
	if raw_name is StringName:
		var direction_name: StringName = raw_name
		return direction_name
	return &""


## 按名称获取方向枚举。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param direction_name: 方向名称。
## [br]
## @param default_direction: 未找到名称时返回的默认方向。
## [br]
## @return 方向枚举。
static func get_direction_from_name(
	direction_name: StringName,
	default_direction: Direction2D = Direction2D.NONE
) -> Direction2D:
	for direction_value: Variant in _DIRECTION_NAMES:
		var candidate: Direction2D = _to_direction(direction_value)
		var candidate_name: StringName = get_direction_name(candidate)
		if candidate_name == direction_name:
			return candidate
	return default_direction


## 按枚举获取方向向量。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param direction: 方向枚举。
## [br]
## @return 方向向量；对角方向保留 -1/1 分量而不归一化。
static func get_direction_vector(direction: Direction2D) -> Vector2:
	var raw_vector: Variant = GFVariantData.get_option_value(_DIRECTION_VECTORS, direction, Vector2.ZERO)
	if raw_vector is Vector2:
		var direction_vector: Vector2 = raw_vector
		return direction_vector
	return Vector2.ZERO


## 获取最接近二维输入的离散方向。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param raw_direction: 原始二维输入。
## [br]
## @param include_diagonal: 是否允许返回对角方向。
## [br]
## @param default_direction: 输入为零时返回的默认方向。
## [br]
## @return 最接近的离散方向。
static func get_closest_direction(
	raw_direction: Vector2,
	include_diagonal: bool = true,
	default_direction: Direction2D = Direction2D.NONE
) -> Direction2D:
	if raw_direction.length_squared() <= _EPSILON:
		return default_direction

	var mode: SnapMode = SnapMode.EIGHT_WAY if include_diagonal else SnapMode.CARDINAL_4
	var snapped_vector: Vector2 = snap_vector(raw_direction, mode)
	return get_direction_from_vector(snapped_vector, include_diagonal, default_direction)


## 按离散向量获取方向枚举。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param direction_vector: 离散方向向量。
## [br]
## @param include_diagonal: 是否允许匹配对角方向。
## [br]
## @param default_direction: 未匹配时返回的默认方向。
## [br]
## @return 方向枚举。
static func get_direction_from_vector(
	direction_vector: Vector2,
	include_diagonal: bool = true,
	default_direction: Direction2D = Direction2D.NONE
) -> Direction2D:
	var snapped_vector: Vector2 = snap_vector(
		direction_vector,
		SnapMode.EIGHT_WAY if include_diagonal else SnapMode.CARDINAL_4
	)
	for direction_value: Variant in _DIRECTION_VECTORS:
		var candidate: Direction2D = _to_direction(direction_value)
		if not include_diagonal and _is_diagonal_direction(candidate):
			continue
		if get_direction_vector(candidate) == snapped_vector:
			return candidate
	return default_direction


## 获取反向方向。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param direction: 方向枚举。
## [br]
## @return 反向方向。
static func get_opposite_direction(direction: Direction2D) -> Direction2D:
	var raw_direction: Variant = GFVariantData.get_option_value(_OPPOSITE_DIRECTIONS, direction, Direction2D.NONE)
	return _to_direction(raw_direction)


## 获取反向方向向量。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param direction_vector: 方向向量。
## [br]
## @return 反向方向向量。
static func get_opposite_vector(direction_vector: Vector2) -> Vector2:
	return -direction_vector


# --- 私有/辅助方法 ---

static func _snap_cardinal(direction: Vector2) -> Vector2:
	if absf(direction.x) >= absf(direction.y):
		return Vector2(signf(direction.x), 0.0)
	return Vector2(0.0, signf(direction.y))


static func _snap_eight_way(direction: Vector2) -> Vector2:
	var result: Vector2 = Vector2.ZERO
	if direction.x > _DIAGONAL_THRESHOLD:
		result.x = 1.0
	elif direction.x < -_DIAGONAL_THRESHOLD:
		result.x = -1.0
	if direction.y > _DIAGONAL_THRESHOLD:
		result.y = 1.0
	elif direction.y < -_DIAGONAL_THRESHOLD:
		result.y = -1.0
	if result == Vector2.ZERO:
		return _snap_cardinal(direction)
	return result


static func _is_diagonal_direction(direction: Direction2D) -> bool:
	return (
		direction == Direction2D.UP_RIGHT
		or direction == Direction2D.UP_LEFT
		or direction == Direction2D.DOWN_RIGHT
		or direction == Direction2D.DOWN_LEFT
	)


static func _to_direction(value: Variant, default_direction: Direction2D = Direction2D.NONE) -> Direction2D:
	if not value is int:
		return default_direction
	var direction_index: int = value
	match direction_index:
		Direction2D.NONE:
			return Direction2D.NONE
		Direction2D.UP:
			return Direction2D.UP
		Direction2D.RIGHT:
			return Direction2D.RIGHT
		Direction2D.DOWN:
			return Direction2D.DOWN
		Direction2D.LEFT:
			return Direction2D.LEFT
		Direction2D.UP_RIGHT:
			return Direction2D.UP_RIGHT
		Direction2D.UP_LEFT:
			return Direction2D.UP_LEFT
		Direction2D.DOWN_RIGHT:
			return Direction2D.DOWN_RIGHT
		Direction2D.DOWN_LEFT:
			return Direction2D.DOWN_LEFT
		_:
			return default_direction
