## 测试 GFGraphLayoutUtility 的通用图布局能力。
extends GutTest


# --- 常量 ---

const GFGraphLayoutUtilityBase = preload("res://addons/gf/standard/foundation/math/gf_graph_layout_utility.gd")


# --- 测试 ---

func test_layered_layout_places_connected_nodes_in_later_layers() -> void:
	var positions: Dictionary = GFGraphLayoutUtilityBase.make_layered_layout(
		PackedStringArray(
			[
				"start",
				"middle",
				"end",
			]
		),
		[
			{ "from_node_id": "start", "to_node_id": "middle" },
			{ "from_node_id": "middle", "to_node_id": "end" },
		],
		{ "x_spacing": 100.0, "y_spacing": 50.0, }
	)

	assert_eq(
		GFVariantData.get_option_vector2(positions, "start"),
		Vector2.ZERO,
		"起点应位于第一层。"
	)
	assert_eq(
		GFVariantData.get_option_vector2(positions, "middle"),
		Vector2(100.0, 0.0),
		"后继节点应进入下一层。"
	)
	assert_eq(
		GFVariantData.get_option_vector2(positions, "end"),
		Vector2(200.0, 0.0),
		"链式后继应继续向右布局。"
	)


func test_grid_layout_uses_columns_and_spacing() -> void:
	var positions: Dictionary = GFGraphLayoutUtilityBase.make_grid_layout(
		PackedStringArray(
			[
				"a",
				"b",
				"c",
			]
		),
		{
			"columns": 2,
			"x_spacing": 10.0,
			"y_spacing": 20.0,
		}
	)

	assert_eq(
		GFVariantData.get_option_vector2(positions, "a"),
		Vector2.ZERO,
		"第一个节点应在原点。"
	)
	assert_eq(
		GFVariantData.get_option_vector2(positions, "b"),
		Vector2(10.0, 0.0),
		"同一行第二个节点应按 x 间距排列。"
	)
	assert_eq(
		GFVariantData.get_option_vector2(positions, "c"),
		Vector2(0.0, 20.0),
		"超过列数后应换行。"
	)
