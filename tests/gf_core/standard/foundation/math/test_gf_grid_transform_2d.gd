## 测试 GFGridTransform2D 的 2D 矩形格子与连续坐标变换。
extends GutTest


# --- 常量 ---

const GF_GRID_TRANSFORM_2D = preload("res://addons/gf/standard/foundation/math/gf_grid_transform_2d.gd")


# --- 测试 ---

func test_transformed_size_swaps_axes_for_rotations_and_diagonals() -> void:
	var size: Vector2i = Vector2i(3, 2)

	assert_eq(
		GF_GRID_TRANSFORM_2D.get_transformed_size(size, GF_GRID_TRANSFORM_2D.Transform.ROTATE_90),
		Vector2i(2, 3),
		"90 度旋转应交换宽高。"
	)
	assert_eq(
		GF_GRID_TRANSFORM_2D.get_transformed_size(size, GF_GRID_TRANSFORM_2D.Transform.MIRROR_X),
		size,
		"左右镜像不应交换宽高。"
	)
	assert_eq(
		GF_GRID_TRANSFORM_2D.get_transformed_size(size, GF_GRID_TRANSFORM_2D.Transform.DIAGONAL_MAIN),
		Vector2i(2, 3),
		"对角翻转应交换宽高。"
	)


func test_transform_local_cell_handles_all_rectangular_symmetries() -> void:
	var size: Vector2i = Vector2i(3, 2)
	var top_left: Vector2i = Vector2i.ZERO
	var bottom_right: Vector2i = Vector2i(2, 1)

	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_local_cell(
			top_left,
			size,
			GF_GRID_TRANSFORM_2D.Transform.ROTATE_90
		),
		Vector2i(1, 0),
		"90 度旋转应围绕矩形局部空间变换。"
	)
	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_local_cell(
			bottom_right,
			size,
			GF_GRID_TRANSFORM_2D.Transform.ROTATE_180
		),
		Vector2i.ZERO,
		"180 度旋转应把右下角映射到左上角。"
	)
	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_local_cell(
			bottom_right,
			size,
			GF_GRID_TRANSFORM_2D.Transform.DIAGONAL_MAIN
		),
		Vector2i(1, 2),
		"主对角翻转应交换 x/y。"
	)
	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_local_cell(
			top_left,
			size,
			GF_GRID_TRANSFORM_2D.Transform.DIAGONAL_ANTI
		),
		Vector2i(1, 2),
		"副对角翻转应映射到交换尺寸后的远端。"
	)


func test_transform_cell_applies_source_rect_and_target_origin() -> void:
	var source_rect: Rect2i = Rect2i(Vector2i(10, 20), Vector2i(3, 2))
	var target_origin: Vector2i = Vector2i(100, 200)
	var cell: Vector2i = Vector2i(10, 20)

	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_cell(
			cell,
			source_rect,
			GF_GRID_TRANSFORM_2D.Transform.ROTATE_90,
			target_origin
		),
		Vector2i(101, 200),
		"全局格子应先转为局部坐标，再叠加目标起点。"
	)


func test_transform_cells_preserves_input_order() -> void:
	var transformed: Array[Vector2i] = GF_GRID_TRANSFORM_2D.transform_cells(
		[Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 1)],
		Rect2i(Vector2i.ZERO, Vector2i(3, 2)),
		GF_GRID_TRANSFORM_2D.Transform.MIRROR_X
	)

	assert_eq(
		transformed,
		[Vector2i(2, 0), Vector2i(1, 0), Vector2i(0, 1)],
		"批量变换应保留输入顺序。"
	)


func test_transform_cardinal_direction_matches_grid_symmetry() -> void:
	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_cardinal_direction(
			Vector2i.RIGHT,
			GF_GRID_TRANSFORM_2D.Transform.ROTATE_90
		),
		Vector2i.DOWN,
		"方向旋转应与格子坐标旋转一致。"
	)
	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_cardinal_direction(
			Vector2i.DOWN,
			GF_GRID_TRANSFORM_2D.Transform.MIRROR_X
		),
		Vector2i.DOWN,
		"左右镜像不应改变向下方向。"
	)
	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_cardinal_direction(
			Vector2i.RIGHT,
			GF_GRID_TRANSFORM_2D.Transform.DIAGONAL_ANTI
		),
		Vector2i.UP,
		"副对角翻转应把向右映射为向上。"
	)
	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_cardinal_direction(
			Vector2i(1, 1),
			GF_GRID_TRANSFORM_2D.Transform.ROTATE_90
		),
		Vector2i.ZERO,
		"非四向单位方向应返回哨兵值。"
	)


func test_transform_local_point_uses_continuous_rect_size() -> void:
	var size: Vector2 = Vector2(3.0, 2.0)

	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_local_point(
			Vector2(0.25, 0.5),
			size,
			GF_GRID_TRANSFORM_2D.Transform.MIRROR_X
		),
		Vector2(2.75, 0.5),
		"连续坐标镜像应使用完整矩形尺寸，而不是格子最大索引。"
	)
	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_local_point(
			Vector2(0.25, 0.5),
			size,
			GF_GRID_TRANSFORM_2D.Transform.ROTATE_90
		),
		Vector2(1.5, 0.25),
		"连续坐标旋转应适合 marker、polygon 等非格子点。"
	)


func test_inverse_transform_restores_local_cell_when_using_transformed_size() -> void:
	var source_size: Vector2i = Vector2i(4, 2)
	var original: Vector2i = Vector2i(3, 1)
	var transform: int = GF_GRID_TRANSFORM_2D.Transform.ROTATE_90
	var transformed: Vector2i = GF_GRID_TRANSFORM_2D.transform_local_cell(original, source_size, transform)
	var restored: Vector2i = GF_GRID_TRANSFORM_2D.transform_local_cell(
		transformed,
		GF_GRID_TRANSFORM_2D.get_transformed_size(source_size, transform),
		GF_GRID_TRANSFORM_2D.get_inverse_transform(transform)
	)

	assert_eq(restored, original, "逆变换应能还原局部格坐标。")


func test_invalid_transform_and_size_return_safe_defaults() -> void:
	assert_false(GF_GRID_TRANSFORM_2D.is_transform_valid(GF_GRID_TRANSFORM_2D.INVALID_TRANSFORM))
	assert_eq(
		GF_GRID_TRANSFORM_2D.get_inverse_transform(GF_GRID_TRANSFORM_2D.INVALID_TRANSFORM),
		GF_GRID_TRANSFORM_2D.INVALID_TRANSFORM,
		"无效变换的逆变换应返回哨兵值。"
	)
	assert_eq(
		GF_GRID_TRANSFORM_2D.transform_local_cell(
			Vector2i(2, 3),
			Vector2i.ZERO,
			GF_GRID_TRANSFORM_2D.Transform.ROTATE_90
		),
		Vector2i(2, 3),
		"无效尺寸不应破坏输入坐标。"
	)
