## 测试 GFRectPacking2D 的通用矩形打包行为。
extends GutTest


# --- 常量 ---

const GFRectPacking2DBase = preload("res://addons/gf/standard/foundation/math/gf_rect_packing_2d.gd")


# --- 测试方法 ---

## 验证固定容器能打包矩形且不会互相重叠。
func test_pack_fixed_places_rects_inside_container() -> void:
	var result: Dictionary = GFRectPacking2DBase.pack_fixed([
		Vector2i(4, 4),
		Vector2i(4, 4),
		Vector2i(2, 2),
	], Vector2i(8, 8), { "sort": false })

	assert_true(GFVariantData.get_option_bool(result, "ok"), "固定容器足够大时应成功。")
	assert_eq(GFVariantData.get_option_int(result, "placed_count"), 3, "所有矩形都应放置。")
	_assert_placements_valid(result)


## 验证无法放置的矩形会进入 unplaced_indices。
func test_pack_fixed_reports_unplaced_indices() -> void:
	var result: Dictionary = GFRectPacking2DBase.pack_fixed([
		Vector2i(6, 6),
		Vector2i(2, 2),
	], Vector2i(4, 4), { "sort": false })

	assert_false(GFVariantData.get_option_bool(result, "ok"), "容器不足时结果应失败。")
	assert_eq(_get_result_unplaced_indices(result), PackedInt32Array([0]), "过大的矩形应标记为未放置。")
	assert_eq(GFVariantData.get_option_int(result, "placed_count"), 1, "后续较小矩形仍可尝试放置。")
	_assert_placements_valid(result)


## 验证 max_rects 会在打包前拒绝过多输入，避免误用纯 GDScript 算法处理实时大批量数据。
func test_pack_fixed_rejects_rect_count_above_max_rects() -> void:
	var result: Dictionary = GFRectPacking2DBase.pack_fixed([
		Vector2i(2, 2),
		Vector2i(2, 2),
		Vector2i(2, 2),
	], Vector2i(8, 8), {
		"max_rects": 2,
	})

	assert_false(GFVariantData.get_option_bool(result, "ok"), "超过 max_rects 时应返回失败。")
	assert_eq(GFVariantData.get_option_string(result, "error"), "rect_count exceeds max_rects.")
	assert_eq(_get_result_unplaced_indices(result), PackedInt32Array([0, 1, 2]), "所有输入矩形都应保持原索引进入未放置列表。")
	assert_eq(_get_result_placements(result).size(), 3, "失败结果仍应保留与输入等长的 placements。")


## 验证自动正方形入口也会先执行 max_rects 上限检查。
func test_pack_square_rejects_rect_count_above_max_rects_before_solving() -> void:
	var result: Dictionary = GFRectPacking2DBase.pack_square([
		Vector2i(1, 1),
		Vector2i(1, 1),
		Vector2i(1, 1),
	], {
		"max_rects": 2,
	})

	assert_false(GFVariantData.get_option_bool(result, "ok"), "自动容器求解前应先执行数量上限。")
	assert_eq(GFVariantData.get_option_string(result, "error"), "rect_count exceeds max_rects.")
	assert_eq(_get_result_container_size(result), Vector2i.ZERO, "自动求解被拒绝时不应制造推断容器。")


## 验证自动正方形打包和归一化坐标。
func test_pack_square_finds_power_of_two_container_and_normalizes() -> void:
	var result: Dictionary = GFRectPacking2DBase.pack_square([
		Vector2i(5, 3),
		Vector2i(4, 4),
		Vector2i(2, 6),
	], {
		"power_of_two": true,
		"allow_rotate": true,
	})

	assert_true(GFVariantData.get_option_bool(result, "ok"), "自动正方形应找到可容纳所有矩形的边长。")
	var container_size: Vector2i = _get_result_container_size(result)
	assert_eq(container_size.x, container_size.y, "自动容器应为正方形。")
	assert_true(_is_power_of_two(container_size.x), "power_of_two 为 true 时边长应为 2 的幂。")
	_assert_placements_valid(result)

	var normalized: Array = GFRectPacking2DBase.normalize_placements(
		_get_result_placements(result),
		container_size
	)
	assert_eq(normalized.size(), 3, "归一化结果应与输入数量一致。")
	for value: Variant in normalized:
		var rect: Rect2 = value
		assert_true(rect.position.x >= 0.0 and rect.position.y >= 0.0, "归一化坐标不应小于 0。")
		assert_true(rect.end.x <= 1.0 and rect.end.y <= 1.0, "归一化坐标不应超过 1。")


## 验证旋转选项只在允许时生效。
func test_pack_fixed_uses_rotation_only_when_allowed() -> void:
	var no_rotation: Dictionary = GFRectPacking2DBase.pack_fixed([
		Vector2i(4, 6),
	], Vector2i(6, 4))
	var with_rotation: Dictionary = GFRectPacking2DBase.pack_fixed([
		Vector2i(4, 6),
	], Vector2i(6, 4), { "allow_rotate": true })

	assert_false(GFVariantData.get_option_bool(no_rotation, "ok"), "未允许旋转时不应交换宽高。")
	assert_true(GFVariantData.get_option_bool(with_rotation, "ok"), "允许旋转时应可放入容器。")
	assert_eq(_get_result_placements(with_rotation)[0].size, Vector2i(6, 4), "旋转后放置尺寸应交换宽高。")
	assert_true(_get_result_rotated_flags(with_rotation)[0], "旋转标记应为 true。")


## 验证 padding 会作为每个矩形四周的保留边距参与打包。
func test_pack_fixed_respects_padding_margins() -> void:
	var result: Dictionary = GFRectPacking2DBase.pack_fixed([
		Vector2i(2, 2),
		Vector2i(2, 2),
	], Vector2i(8, 4), {
		"padding": 1,
		"sort": false,
	})
	var placements: Array[Rect2i] = _get_result_placements(result)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "带 padding 的两个矩形应能放入容器。")
	assert_eq(placements[0].position, Vector2i(1, 1), "第一个矩形应留出左上边距。")
	assert_true(placements[1].position.x - placements[0].end.x >= 2, "两个矩形之间应至少保留两侧 padding。")
	_assert_placements_valid(result)


# --- 私有/辅助方法 ---

func _assert_placements_valid(result: Dictionary) -> void:
	var container_size: Vector2i = _get_result_container_size(result)
	var placements: Array = _get_result_placements(result)
	for index: int in range(placements.size()):
		var rect: Rect2i = placements[index]
		if rect.size.x <= 0 or rect.size.y <= 0:
			continue
		assert_true(rect.position.x >= 0 and rect.position.y >= 0, "放置矩形不能越过容器左上边界。")
		assert_true(rect.end.x <= container_size.x and rect.end.y <= container_size.y, "放置矩形不能越过容器右下边界。")
		for other_index: int in range(index + 1, placements.size()):
			var other_rect: Rect2i = placements[other_index]
			if other_rect.size.x <= 0 or other_rect.size.y <= 0:
				continue
			assert_false(_rect_intersects(rect, other_rect), "放置矩形之间不能重叠。")


func _get_result_container_size(result: Dictionary) -> Vector2i:
	var value: Variant = GFVariantData.get_option_value(result, "container_size")
	return value if value is Vector2i else Vector2i.ZERO


func _get_result_placements(result: Dictionary) -> Array[Rect2i]:
	var values: Array = GFVariantData.as_array(GFVariantData.get_option_value(result, "placements"))
	var placements: Array[Rect2i] = []
	for value: Variant in values:
		if value is Rect2i:
			var rect: Rect2i = value
			placements.append(rect)
	return placements


func _get_result_unplaced_indices(result: Dictionary) -> PackedInt32Array:
	var value: Variant = GFVariantData.get_option_value(result, "unplaced_indices")
	if value is PackedInt32Array:
		var indices: PackedInt32Array = value
		return indices
	return PackedInt32Array()


func _get_result_rotated_flags(result: Dictionary) -> Array[bool]:
	var value: Variant = GFVariantData.get_option_value(result, "rotated")
	var flags: Array[bool] = []
	if not value is Array:
		return flags

	var values: Array = GFVariantData.as_array(value)
	var _resize_result: int = flags.resize(values.size())
	for index: int in range(values.size()):
		flags[index] = GFVariantData.to_bool(values[index], false)
	return flags


func _rect_intersects(left: Rect2i, right: Rect2i) -> bool:
	return (
		left.position.x < right.position.x + right.size.x
		and left.position.x + left.size.x > right.position.x
		and left.position.y < right.position.y + right.size.y
		and left.position.y + left.size.y > right.position.y
	)


func _is_power_of_two(value: int) -> bool:
	return value > 0 and (value & (value - 1)) == 0
