## 测试 GFPattern2D 的格子查询与归一化。
extends GutTest


func test_pattern_normalizes_cells_and_bounds() -> void:
	var pattern: GFPattern2D = GFPattern2D.new()
	pattern.pattern_dimensions = Vector2i(3, 2)
	pattern.cells = [
		Vector2i(0, 0),
		Vector2i(2, 1),
		Vector2i(4, 4),
		Vector2i(0, 0),
	]

	assert_eq(
		pattern.get_cells(),
		[Vector2i(0, 0), Vector2i(2, 1)]
	)
	assert_true(pattern.has_cell(Vector2i(2, 1)))
	assert_false(pattern.has_cell(Vector2i(1, 1)))
	assert_false(pattern.is_in_bounds(Vector2i(3, 0)))


func test_pattern_set_cell_and_clear() -> void:
	var pattern: GFPattern2D = GFPattern2D.new()
	pattern.pattern_dimensions = Vector2i(2, 2)

	assert_true(
		pattern.set_cell(
			Vector2i(1, 1),
			true
		)
	)
	assert_true(pattern.has_cell(Vector2i(1, 1)))
	assert_true(
		pattern.set_cell(
			Vector2i(1, 1),
			false
		)
	)
	assert_false(pattern.has_cell(Vector2i(1, 1)))

	var _add_cell_result_25: Variant = pattern.add_cell(Vector2i(0, 0))
	pattern.clear_cells()
	assert_eq(
		pattern.get_cells(),
		[]
	)
