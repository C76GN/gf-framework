## GFRectPacking2D: 通用 2D 矩形打包算法。
##
## 使用 MaxRects 风格的空闲矩形拆分，将一组矩形尺寸放入固定容器或自动求解正方形容器。
## 它只计算 Rect2i 放置结果，不创建 Texture、Material、Node 或图集资源。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFRectPacking2D
extends RefCounted


# --- 常量 ---

## 默认最大输入矩形数量，用于避免误把实时大批量数据交给纯 GDScript 打包算法。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_MAX_RECTS: int = 4096


# --- 公共方法 ---

## 将矩形打包进固定容器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param rect_sizes: 每个矩形的原始尺寸。
## [br]
## @param container_size: 容器尺寸。
## [br]
## @param options: 可选参数，支持 padding、allow_rotate、sort 和 max_rects。
## [br]
## @return 打包结果字典。
## [br]
## @schema rect_sizes: Array[Vector2i]，每项是矩形尺寸；非正尺寸会标记为未放置。
## [br]
## @schema options: Dictionary，padding 为每个矩形四周保留的像素边距，allow_rotate 允许交换宽高，sort 控制是否按尺寸降序优化打包顺序，max_rects 控制最大输入矩形数量。
## [br]
## @schema return: Dictionary，包含 ok、error、container_size、placements、rotated、unplaced_indices、placed_count、used_area 和 occupancy。
static func pack_fixed(
	rect_sizes: Array[Vector2i],
	container_size: Vector2i,
	options: Dictionary = {}
) -> Dictionary:
	var max_rects: int = _get_max_rects(options)
	if rect_sizes.size() > max_rects:
		return _make_unplaced_result(
			rect_sizes.size(),
			container_size,
			"rect_count exceeds max_rects."
		)

	var padding: int = maxi(GFVariantData.get_option_int(options, "padding", 0), 0)
	var allow_rotate: bool = GFVariantData.get_option_bool(options, "allow_rotate", false)
	var should_sort: bool = GFVariantData.get_option_bool(options, "sort", true)
	var placements: Array[Rect2i] = []
	var rotated: Array[bool] = []
	_initialize_output_arrays(rect_sizes.size(), placements, rotated)

	var unplaced_indices: PackedInt32Array = PackedInt32Array()
	if container_size.x <= 0 or container_size.y <= 0:
		for index: int in range(rect_sizes.size()):
			var _appended_invalid_container_index: bool = unplaced_indices.append(index)
		return _make_result(container_size, placements, rotated, unplaced_indices)

	var items: Array[Dictionary] = _make_items(rect_sizes, padding)
	if should_sort:
		items.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			return _sort_item_before(left, right)
		)

	var free_rects: Array[Rect2i] = [Rect2i(Vector2i.ZERO, container_size)]
	for item: Dictionary in items:
		var item_index: int = GFVariantData.get_option_int(item, "index", -1)
		if not GFVariantData.get_option_bool(item, "valid", false):
			var _appended_invalid_size_index: bool = unplaced_indices.append(item_index)
			continue

		var placement: Dictionary = _find_best_placement(free_rects, item, allow_rotate, padding)
		if not GFVariantData.get_option_bool(placement, "ok", false):
			var _appended_unplaced_index: bool = unplaced_indices.append(item_index)
			continue

		var footprint_rect: Rect2i = _get_rect2i_value(GFVariantData.get_option_value(placement, "footprint_rect"))
		var placed_rect: Rect2i = _get_rect2i_value(GFVariantData.get_option_value(placement, "rect"))
		placements[item_index] = placed_rect
		rotated[item_index] = GFVariantData.get_option_bool(placement, "rotated", false)
		free_rects = _split_free_rects(free_rects, footprint_rect)
		_prune_free_rects(free_rects)

	return _make_result(container_size, placements, rotated, unplaced_indices)


## 将矩形打包进自动求解的正方形容器。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param rect_sizes: 每个矩形的原始尺寸。
## [br]
## @param options: 可选参数，支持 padding、allow_rotate、sort、power_of_two、max_size 和 max_rects。
## [br]
## @return 打包结果字典。
## [br]
## @schema rect_sizes: Array[Vector2i]，每项是矩形尺寸；非正尺寸会标记为未放置。
## [br]
## @schema options: Dictionary，power_of_two 为 true 时只返回 2 的幂边长，max_size 大于 0 时限制最大边长，max_rects 控制最大输入矩形数量，其余字段同 pack_fixed()。
## [br]
## @schema return: Dictionary，包含 ok、error、container_size、placements、rotated、unplaced_indices、placed_count、used_area 和 occupancy。
static func pack_square(rect_sizes: Array[Vector2i], options: Dictionary = {}) -> Dictionary:
	if rect_sizes.is_empty():
		return pack_fixed(rect_sizes, Vector2i.ZERO, options)
	var max_rects: int = _get_max_rects(options)
	if rect_sizes.size() > max_rects:
		return _make_unplaced_result(
			rect_sizes.size(),
			Vector2i.ZERO,
			"rect_count exceeds max_rects."
		)

	var padding: int = maxi(GFVariantData.get_option_int(options, "padding", 0), 0)
	var power_of_two: bool = GFVariantData.get_option_bool(options, "power_of_two", false)
	var max_size: int = GFVariantData.get_option_int(options, "max_size", 0)
	var lower_bound: int = _get_square_lower_bound(rect_sizes, padding)
	if lower_bound <= 0:
		return pack_fixed(rect_sizes, Vector2i.ZERO, options)

	var low: int = _next_power_of_two(lower_bound) if power_of_two else lower_bound
	if max_size > 0 and low > max_size:
		return pack_fixed(rect_sizes, Vector2i(max_size, max_size), options)

	var high: int = low
	var high_result: Dictionary = pack_fixed(rect_sizes, Vector2i(high, high), options)
	while not GFVariantData.get_option_bool(high_result, "ok", false):
		var next_high: int = high * 2
		if power_of_two:
			next_high = _next_power_of_two(next_high)
		if max_size > 0 and next_high > max_size:
			if high == max_size:
				return high_result
			high = max_size
			high_result = pack_fixed(rect_sizes, Vector2i(high, high), options)
			if not GFVariantData.get_option_bool(high_result, "ok", false):
				return high_result
			break
		high = next_high
		high_result = pack_fixed(rect_sizes, Vector2i(high, high), options)

	if power_of_two:
		return high_result

	var best_result: Dictionary = high_result
	while low < high:
		var middle: int = floori(float(low + high) * 0.5)
		var candidate: Dictionary = pack_fixed(rect_sizes, Vector2i(middle, middle), options)
		if GFVariantData.get_option_bool(candidate, "ok", false):
			best_result = candidate
			high = middle
		else:
			low = middle + 1
	return best_result


## 将像素 Rect2i 放置结果归一化为 0 到 1 的 Rect2。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param placements: 像素矩形列表。
## [br]
## @param container_size: 容器尺寸。
## [br]
## @return 归一化矩形列表。
## [br]
## @schema placements: Array[Rect2i]，通常来自 pack_fixed() 或 pack_square() 的 placements 字段。
## [br]
## @schema return: Array[Rect2]，与输入顺序一致；无效容器或空矩形会返回空 Rect2。
static func normalize_placements(
	placements: Array[Rect2i],
	container_size: Vector2i
) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var _resize_result: int = result.resize(placements.size())
	if container_size.x <= 0 or container_size.y <= 0:
		return result

	var container_vector: Vector2 = Vector2(float(container_size.x), float(container_size.y))
	for index: int in range(placements.size()):
		var rect: Rect2i = placements[index]
		if rect.size.x <= 0 or rect.size.y <= 0:
			result[index] = Rect2()
			continue
		result[index] = Rect2(
			Vector2(float(rect.position.x), float(rect.position.y)) / container_vector,
			Vector2(float(rect.size.x), float(rect.size.y)) / container_vector
		)
	return result


# --- 私有/辅助方法 ---

static func _get_max_rects(options: Dictionary) -> int:
	return maxi(GFVariantData.get_option_int(options, "max_rects", DEFAULT_MAX_RECTS), 0)


static func _initialize_output_arrays(
	count: int,
	placements: Array[Rect2i],
	rotated: Array[bool]
) -> void:
	var _placement_resize_result: int = placements.resize(count)
	var _rotated_resize_result: int = rotated.resize(count)
	for index: int in range(count):
		placements[index] = Rect2i()
		rotated[index] = false


static func _make_items(rect_sizes: Array[Vector2i], padding: int) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for index: int in range(rect_sizes.size()):
		var size: Vector2i = rect_sizes[index]
		var valid: bool = size.x > 0 and size.y > 0
		items.append({
			"index": index,
			"size": size,
			"footprint_size": _get_padded_size(size, padding),
			"valid": valid,
		})
	return items


static func _get_padded_size(size: Vector2i, padding: int) -> Vector2i:
	var margin: int = maxi(padding, 0) * 2
	return Vector2i(size.x + margin, size.y + margin)


static func _sort_item_before(left: Dictionary, right: Dictionary) -> bool:
	var left_size: Vector2i = _get_vector2i_value(GFVariantData.get_option_value(left, "footprint_size"))
	var right_size: Vector2i = _get_vector2i_value(GFVariantData.get_option_value(right, "footprint_size"))
	var left_area: int = left_size.x * left_size.y
	var right_area: int = right_size.x * right_size.y
	if left_area != right_area:
		return left_area > right_area

	var left_max_side: int = maxi(left_size.x, left_size.y)
	var right_max_side: int = maxi(right_size.x, right_size.y)
	if left_max_side != right_max_side:
		return left_max_side > right_max_side

	return GFVariantData.get_option_int(left, "index", 0) < GFVariantData.get_option_int(right, "index", 0)


static func _find_best_placement(
	free_rects: Array[Rect2i],
	item: Dictionary,
	allow_rotate: bool,
	padding: int
) -> Dictionary:
	var item_size: Vector2i = _get_vector2i_value(GFVariantData.get_option_value(item, "size"))
	var best: Dictionary = {}
	for rotated: bool in _get_rotation_options(item_size, allow_rotate):
		var placed_size: Vector2i = Vector2i(item_size.y, item_size.x) if rotated else item_size
		var footprint_size: Vector2i = _get_padded_size(placed_size, padding)
		for free_rect: Rect2i in free_rects:
			if footprint_size.x > free_rect.size.x or footprint_size.y > free_rect.size.y:
				continue
			var footprint_rect: Rect2i = Rect2i(free_rect.position, footprint_size)
			var placed_rect: Rect2i = Rect2i(free_rect.position + Vector2i(padding, padding), placed_size)
			var score: Vector3i = _score_placement(free_rect, footprint_size)
			if best.is_empty() or _score_is_better(score, _get_vector3i_value(GFVariantData.get_option_value(best, "score"))):
				best = {
					"ok": true,
					"rect": placed_rect,
					"footprint_rect": footprint_rect,
					"rotated": rotated,
					"score": score,
				}

	if best.is_empty():
		return { "ok": false }
	return best


static func _get_rotation_options(size: Vector2i, allow_rotate: bool) -> Array[bool]:
	if allow_rotate and size.x != size.y:
		return [false, true]
	return [false]


static func _score_placement(free_rect: Rect2i, footprint_size: Vector2i) -> Vector3i:
	var leftover_width: int = free_rect.size.x - footprint_size.x
	var leftover_height: int = free_rect.size.y - footprint_size.y
	return Vector3i(
		mini(leftover_width, leftover_height),
		maxi(leftover_width, leftover_height),
		free_rect.size.x * free_rect.size.y - footprint_size.x * footprint_size.y
	)


static func _score_is_better(left: Vector3i, right: Vector3i) -> bool:
	if left.x != right.x:
		return left.x < right.x
	if left.y != right.y:
		return left.y < right.y
	return left.z < right.z


static func _split_free_rects(
	free_rects: Array[Rect2i],
	placed: Rect2i
) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	for free_rect: Rect2i in free_rects:
		if not _rect_intersects(free_rect, placed):
			result.append(free_rect)
			continue

		var free_right: int = free_rect.position.x + free_rect.size.x
		var free_bottom: int = free_rect.position.y + free_rect.size.y
		var placed_right: int = placed.position.x + placed.size.x
		var placed_bottom: int = placed.position.y + placed.size.y

		if placed.position.x > free_rect.position.x:
			_append_non_empty_rect(
				result,
				Rect2i(
					free_rect.position,
					Vector2i(placed.position.x - free_rect.position.x, free_rect.size.y)
				)
			)
		if placed_right < free_right:
			_append_non_empty_rect(
				result,
				Rect2i(
					Vector2i(placed_right, free_rect.position.y),
					Vector2i(free_right - placed_right, free_rect.size.y)
				)
			)
		if placed.position.y > free_rect.position.y:
			_append_non_empty_rect(
				result,
				Rect2i(
					free_rect.position,
					Vector2i(free_rect.size.x, placed.position.y - free_rect.position.y)
				)
			)
		if placed_bottom < free_bottom:
			_append_non_empty_rect(
				result,
				Rect2i(
					Vector2i(free_rect.position.x, placed_bottom),
					Vector2i(free_rect.size.x, free_bottom - placed_bottom)
				)
			)
	return result


static func _append_non_empty_rect(target: Array[Rect2i], rect: Rect2i) -> void:
	if rect.size.x > 0 and rect.size.y > 0:
		target.append(rect)


static func _prune_free_rects(free_rects: Array[Rect2i]) -> void:
	var index: int = 0
	while index < free_rects.size():
		var removed_index: bool = false
		var other_index: int = index + 1
		while other_index < free_rects.size():
			if _rect_encloses(free_rects[index], free_rects[other_index]):
				free_rects.remove_at(other_index)
				continue
			if _rect_encloses(free_rects[other_index], free_rects[index]):
				free_rects.remove_at(index)
				removed_index = true
				break
			other_index += 1
		if not removed_index:
			index += 1


static func _rect_intersects(left: Rect2i, right: Rect2i) -> bool:
	return (
		left.position.x < right.position.x + right.size.x
		and left.position.x + left.size.x > right.position.x
		and left.position.y < right.position.y + right.size.y
		and left.position.y + left.size.y > right.position.y
	)


static func _rect_encloses(container: Rect2i, inner: Rect2i) -> bool:
	return (
		inner.position.x >= container.position.x
		and inner.position.y >= container.position.y
		and inner.position.x + inner.size.x <= container.position.x + container.size.x
		and inner.position.y + inner.size.y <= container.position.y + container.size.y
	)


static func _get_square_lower_bound(rect_sizes: Array[Vector2i], padding: int) -> int:
	var total_area: int = 0
	var max_side: int = 0
	for size: Vector2i in rect_sizes:
		if size.x <= 0 or size.y <= 0:
			continue
		var padded_size: Vector2i = _get_padded_size(size, padding)
		total_area += padded_size.x * padded_size.y
		max_side = maxi(max_side, maxi(padded_size.x, padded_size.y))
	if total_area <= 0:
		return 0
	return maxi(ceili(sqrt(float(total_area))), max_side)


static func _next_power_of_two(value: int) -> int:
	var result: int = 1
	while result < value:
		result *= 2
	return result


static func _make_result(
	container_size: Vector2i,
	placements: Array[Rect2i],
	rotated: Array[bool],
	unplaced_indices: PackedInt32Array,
	error: String = ""
) -> Dictionary:
	var used_area: int = 0
	var placed_count: int = 0
	for rect: Rect2i in placements:
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		used_area += rect.size.x * rect.size.y
		placed_count += 1

	var container_area: int = maxi(container_size.x, 0) * maxi(container_size.y, 0)
	return {
		"ok": error.is_empty() and unplaced_indices.is_empty(),
		"error": error,
		"container_size": container_size,
		"placements": placements,
		"rotated": rotated,
		"unplaced_indices": unplaced_indices,
		"placed_count": placed_count,
		"used_area": used_area,
		"occupancy": float(used_area) / float(container_area) if container_area > 0 else 0.0,
	}


static func _make_unplaced_result(rect_count: int, container_size: Vector2i, error: String) -> Dictionary:
	var placements: Array[Rect2i] = []
	var rotated: Array[bool] = []
	_initialize_output_arrays(rect_count, placements, rotated)
	var unplaced_indices: PackedInt32Array = PackedInt32Array()
	for index: int in range(rect_count):
		var _index_appended: bool = unplaced_indices.append(index)
	return _make_result(container_size, placements, rotated, unplaced_indices, error)


static func _get_vector2i_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		var vector: Vector2i = value
		return vector
	if value is Vector2:
		var vector_2: Vector2 = value
		return Vector2i(roundi(vector_2.x), roundi(vector_2.y))
	return Vector2i.ZERO


static func _get_vector3i_value(value: Variant) -> Vector3i:
	if value is Vector3i:
		var vector: Vector3i = value
		return vector
	return Vector3i(2147483647, 2147483647, 2147483647)


static func _get_rect2i_value(value: Variant) -> Rect2i:
	if value is Rect2i:
		var rect: Rect2i = value
		return rect
	return Rect2i()
