## GFPlacementSequenceMath: 连续放置序列的纯数学预测工具。
##
## 根据已经确认的放置点或格子，预测下一次放置候选位置。它只处理纯数据，
## 不创建节点、不读取场景、不绑定编辑器选择、UndoRedo、碰撞或重叠规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFPlacementSequenceMath
extends RefCounted


# --- 常量 ---

## 没有可用历史时使用调用方提供的 fallback。
## [br]
## @api public
## [br]
## @since 8.0.0
const MODE_FALLBACK: StringName = &"fallback"

## 只有一个可用历史点时复用最后一次放置位置。
## [br]
## @api public
## [br]
## @since 8.0.0
const MODE_REPEAT_LAST: StringName = &"repeat_last"

## 至少有两个可用历史点时按 `last + (last - previous)` 推断下一次位置。
## [br]
## @api public
## [br]
## @since 8.0.0
const MODE_EXTRAPOLATED: StringName = &"extrapolated"


# --- 公共方法 ---

## 预测下一次 2D 连续位置。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param positions: 已确认的放置位置，按时间顺序排列。
## [br]
## @param fallback_position: 没有历史位置时使用的候选位置。
## [br]
## @param options: 可选项，支持 max_step_length 限制外推步长；小于等于 0 时不限制。
## [br]
## @schema options: Dictionary，可包含 max_step_length: float。
## [br]
## @return 预测报告。
## [br]
## @schema return: Dictionary，包含 ok、mode、position、step、source_count、valid_count、ignored_invalid_count、clamped、max_step_length 和 error。
static func predict_next_position_2d(
	positions: Array[Vector2],
	fallback_position: Vector2 = Vector2.ZERO,
	options: Dictionary = {}
) -> Dictionary:
	var max_step_length: float = _get_max_step_length(options)
	var valid_positions: Array[Vector2] = _filter_finite_positions_2d(positions)
	var valid_count: int = valid_positions.size()
	if valid_count <= 0:
		var fallback_is_valid: bool = _is_finite_vector2(fallback_position)
		return _make_position_2d_report(
			fallback_is_valid,
			MODE_FALLBACK,
			fallback_position if fallback_is_valid else Vector2.ZERO,
			Vector2.ZERO,
			positions.size(),
			valid_count,
			false,
			max_step_length,
			&"" if fallback_is_valid else &"invalid_fallback_position"
		)

	var last_position: Vector2 = valid_positions[valid_count - 1]
	if valid_count == 1:
		return _make_position_2d_report(
			true,
			MODE_REPEAT_LAST,
			last_position,
			Vector2.ZERO,
			positions.size(),
			valid_count,
			false,
			max_step_length,
			&""
		)

	var previous_position: Vector2 = valid_positions[valid_count - 2]
	var step: Vector2 = last_position - previous_position
	if not _is_finite_vector2(step):
		return _make_position_2d_report(
			false,
			MODE_REPEAT_LAST,
			last_position,
			Vector2.ZERO,
			positions.size(),
			valid_count,
			false,
			max_step_length,
			&"invalid_step"
		)

	var clamp_result: Dictionary = _clamp_step_2d(step, max_step_length)
	step = _get_step_2d(clamp_result)
	var next_position: Vector2 = last_position + step
	var next_is_valid: bool = _is_finite_vector2(next_position)
	return _make_position_2d_report(
		next_is_valid,
		MODE_EXTRAPOLATED,
		next_position if next_is_valid else last_position,
		step if next_is_valid else Vector2.ZERO,
		positions.size(),
		valid_count,
		GFVariantData.get_option_bool(clamp_result, "clamped"),
		max_step_length,
		&"" if next_is_valid else &"invalid_result"
	)


## 预测下一次 3D 连续位置。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param positions: 已确认的放置位置，按时间顺序排列。
## [br]
## @param fallback_position: 没有历史位置时使用的候选位置。
## [br]
## @param options: 可选项，支持 max_step_length 限制外推步长；小于等于 0 时不限制。
## [br]
## @schema options: Dictionary，可包含 max_step_length: float。
## [br]
## @return 预测报告。
## [br]
## @schema return: Dictionary，包含 ok、mode、position、step、source_count、valid_count、ignored_invalid_count、clamped、max_step_length 和 error。
static func predict_next_position_3d(
	positions: Array[Vector3],
	fallback_position: Vector3 = Vector3.ZERO,
	options: Dictionary = {}
) -> Dictionary:
	var max_step_length: float = _get_max_step_length(options)
	var valid_positions: Array[Vector3] = _filter_finite_positions_3d(positions)
	var valid_count: int = valid_positions.size()
	if valid_count <= 0:
		var fallback_is_valid: bool = _is_finite_vector3(fallback_position)
		return _make_position_3d_report(
			fallback_is_valid,
			MODE_FALLBACK,
			fallback_position if fallback_is_valid else Vector3.ZERO,
			Vector3.ZERO,
			positions.size(),
			valid_count,
			false,
			max_step_length,
			&"" if fallback_is_valid else &"invalid_fallback_position"
		)

	var last_position: Vector3 = valid_positions[valid_count - 1]
	if valid_count == 1:
		return _make_position_3d_report(
			true,
			MODE_REPEAT_LAST,
			last_position,
			Vector3.ZERO,
			positions.size(),
			valid_count,
			false,
			max_step_length,
			&""
		)

	var previous_position: Vector3 = valid_positions[valid_count - 2]
	var step: Vector3 = last_position - previous_position
	if not _is_finite_vector3(step):
		return _make_position_3d_report(
			false,
			MODE_REPEAT_LAST,
			last_position,
			Vector3.ZERO,
			positions.size(),
			valid_count,
			false,
			max_step_length,
			&"invalid_step"
		)

	var clamp_result: Dictionary = _clamp_step_3d(step, max_step_length)
	step = _get_step_3d(clamp_result)
	var next_position: Vector3 = last_position + step
	var next_is_valid: bool = _is_finite_vector3(next_position)
	return _make_position_3d_report(
		next_is_valid,
		MODE_EXTRAPOLATED,
		next_position if next_is_valid else last_position,
		step if next_is_valid else Vector3.ZERO,
		positions.size(),
		valid_count,
		GFVariantData.get_option_bool(clamp_result, "clamped"),
		max_step_length,
		&"" if next_is_valid else &"invalid_result"
	)


## 预测下一次 2D 离散格子。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param cells: 已确认的放置格子，按时间顺序排列。
## [br]
## @param fallback_cell: 没有历史格子时使用的候选格子。
## [br]
## @return 预测报告。
## [br]
## @schema return: Dictionary，包含 ok、mode、cell、step、source_count、valid_count、ignored_invalid_count 和 error。
static func predict_next_cell_2d(
	cells: Array[Vector2i],
	fallback_cell: Vector2i = Vector2i.ZERO
) -> Dictionary:
	var source_count: int = cells.size()
	if source_count <= 0:
		return _make_cell_2d_report(MODE_FALLBACK, fallback_cell, Vector2i.ZERO, source_count)

	var last_cell: Vector2i = cells[source_count - 1]
	if source_count == 1:
		return _make_cell_2d_report(MODE_REPEAT_LAST, last_cell, Vector2i.ZERO, source_count)

	var previous_cell: Vector2i = cells[source_count - 2]
	var step: Vector2i = last_cell - previous_cell
	return _make_cell_2d_report(MODE_EXTRAPOLATED, last_cell + step, step, source_count)


## 预测下一次 3D 离散格子。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param cells: 已确认的放置格子，按时间顺序排列。
## [br]
## @param fallback_cell: 没有历史格子时使用的候选格子。
## [br]
## @return 预测报告。
## [br]
## @schema return: Dictionary，包含 ok、mode、cell、step、source_count、valid_count、ignored_invalid_count 和 error。
static func predict_next_cell_3d(
	cells: Array[Vector3i],
	fallback_cell: Vector3i = Vector3i.ZERO
) -> Dictionary:
	var source_count: int = cells.size()
	if source_count <= 0:
		return _make_cell_3d_report(MODE_FALLBACK, fallback_cell, Vector3i.ZERO, source_count)

	var last_cell: Vector3i = cells[source_count - 1]
	if source_count == 1:
		return _make_cell_3d_report(MODE_REPEAT_LAST, last_cell, Vector3i.ZERO, source_count)

	var previous_cell: Vector3i = cells[source_count - 2]
	var step: Vector3i = last_cell - previous_cell
	return _make_cell_3d_report(MODE_EXTRAPOLATED, last_cell + step, step, source_count)


# --- 私有/辅助方法 ---

static func _filter_finite_positions_2d(positions: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for position: Vector2 in positions:
		if _is_finite_vector2(position):
			result.append(position)
	return result


static func _filter_finite_positions_3d(positions: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for position: Vector3 in positions:
		if _is_finite_vector3(position):
			result.append(position)
	return result


static func _clamp_step_2d(step: Vector2, max_step_length: float) -> Dictionary:
	if max_step_length <= 0.0:
		return { "step": step, "clamped": false }
	var length: float = step.length()
	if not _is_finite_float(length) or length <= max_step_length or length <= 0.0:
		return { "step": step, "clamped": false }
	return {
		"step": step.normalized() * max_step_length,
		"clamped": true,
	}


static func _clamp_step_3d(step: Vector3, max_step_length: float) -> Dictionary:
	if max_step_length <= 0.0:
		return { "step": step, "clamped": false }
	var length: float = step.length()
	if not _is_finite_float(length) or length <= max_step_length or length <= 0.0:
		return { "step": step, "clamped": false }
	return {
		"step": step.normalized() * max_step_length,
		"clamped": true,
	}


static func _get_step_2d(report: Dictionary) -> Vector2:
	var value: Variant = GFVariantData.get_option_value(report, "step", Vector2.ZERO)
	if value is Vector2:
		var step: Vector2 = value
		return step
	return Vector2.ZERO


static func _get_step_3d(report: Dictionary) -> Vector3:
	var value: Variant = GFVariantData.get_option_value(report, "step", Vector3.ZERO)
	if value is Vector3:
		var step: Vector3 = value
		return step
	return Vector3.ZERO


static func _get_max_step_length(options: Dictionary) -> float:
	var value: float = GFVariantData.get_option_float(options, "max_step_length", 0.0)
	if not _is_finite_float(value) or value <= 0.0:
		return 0.0
	return value


static func _make_position_2d_report(
	ok: bool,
	mode: StringName,
	position: Vector2,
	step: Vector2,
	source_count: int,
	valid_count: int,
	clamped: bool,
	max_step_length: float,
	error: StringName
) -> Dictionary:
	return {
		"ok": ok,
		"mode": mode,
		"position": position,
		"step": step,
		"source_count": source_count,
		"valid_count": valid_count,
		"ignored_invalid_count": maxi(source_count - valid_count, 0),
		"clamped": clamped,
		"max_step_length": max_step_length,
		"error": error,
	}


static func _make_position_3d_report(
	ok: bool,
	mode: StringName,
	position: Vector3,
	step: Vector3,
	source_count: int,
	valid_count: int,
	clamped: bool,
	max_step_length: float,
	error: StringName
) -> Dictionary:
	return {
		"ok": ok,
		"mode": mode,
		"position": position,
		"step": step,
		"source_count": source_count,
		"valid_count": valid_count,
		"ignored_invalid_count": maxi(source_count - valid_count, 0),
		"clamped": clamped,
		"max_step_length": max_step_length,
		"error": error,
	}


static func _make_cell_2d_report(
	mode: StringName,
	cell: Vector2i,
	step: Vector2i,
	source_count: int
) -> Dictionary:
	return {
		"ok": true,
		"mode": mode,
		"cell": cell,
		"step": step,
		"source_count": source_count,
		"valid_count": source_count,
		"ignored_invalid_count": 0,
		"error": &"",
	}


static func _make_cell_3d_report(
	mode: StringName,
	cell: Vector3i,
	step: Vector3i,
	source_count: int
) -> Dictionary:
	return {
		"ok": true,
		"mode": mode,
		"cell": cell,
		"step": step,
		"source_count": source_count,
		"valid_count": source_count,
		"ignored_invalid_count": 0,
		"error": &"",
	}


static func _is_finite_vector2(value: Vector2) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y)


static func _is_finite_vector3(value: Vector3) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y) and _is_finite_float(value.z)


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
