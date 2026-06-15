## 测试 GFDebugDrawUtility 的通用命令缓冲行为。
extends GutTest


# --- 测试方法 ---

func test_debug_draw_records_and_expires_items() -> void:
	var utility: GFDebugDrawUtility = GFDebugDrawUtility.new()
	utility.init()

	var item_id: int = utility.draw_line_2d(Vector2.ZERO, Vector2.ONE, Color.RED, 0.1)

	assert_gt(item_id, 0, "绘制命令应返回稳定 id。")
	assert_eq(utility.get_item_count(), 1, "绘制命令应进入缓冲。")

	utility.tick(0.11)

	assert_eq(utility.get_item_count(), 0, "超过生命周期后绘制命令应被清理。")


func test_debug_draw_filters_disabled_channels() -> void:
	var utility: GFDebugDrawUtility = GFDebugDrawUtility.new()
	utility.init()

	var _item_id: int = utility.draw_circle_2d(Vector2(4.0, 5.0), 3.0, Color.GREEN, -1.0, &"physics")
	utility.set_channel_enabled(&"physics", false)

	assert_eq(utility.get_items(&"physics").size(), 0, "禁用频道默认不应返回命令。")
	assert_eq(utility.get_items(&"physics", true).size(), 1, "include_disabled=true 时应返回禁用频道命令。")

	utility.clear(&"physics")

	assert_eq(utility.get_item_count(), 0, "按频道清理应只移除对应命令。")


func test_debug_draw_vector_2d_emits_line_commands_with_components() -> void:
	var utility: GFDebugDrawUtility = GFDebugDrawUtility.new()
	utility.init()

	var ids: Array[int] = utility.draw_vector_2d(
		Vector2(10.0, 20.0),
		Vector2(6.0, 8.0),
		Color.CYAN,
		1.0,
		&"motion",
		2.0,
		{
			"length_mode": "clamp",
			"max_length": 5.0,
			"draw_components": true,
			"arrowhead": false,
		}
	)
	var items: Array[Dictionary] = utility.get_items(&"motion")
	var main_item: Dictionary = items[0]

	assert_eq(ids.size(), 3, "主向量加 XY 分量应产生三条线。")
	assert_eq(items.size(), 3, "向量绘制仍应进入普通命令缓冲。")
	assert_eq(GFVariantData.get_option_int(main_item, "type"), GFDebugDrawUtility.PrimitiveType.LINE_2D, "向量主线应复用 2D 线段图元。")
	assert_eq(GFVariantData.get_option_vector2(main_item, "from"), Vector2(10.0, 20.0), "未居中时主线从 origin 开始。")
	assert_eq(GFVariantData.get_option_vector2(main_item, "to"), Vector2(13.0, 24.0), "clamp 后向量长度应被限制。")


func test_debug_draw_vector_3d_supports_centered_components() -> void:
	var utility: GFDebugDrawUtility = GFDebugDrawUtility.new()
	utility.init()

	var ids: Array[int] = utility.draw_vector_3d(
		Vector3(10.0, 0.0, 0.0),
		Vector3(2.0, 4.0, 6.0),
		Color.WHITE,
		1.0,
		&"physics",
		1.0,
		{
			"centered": true,
			"draw_components": true,
		}
	)
	var items: Array[Dictionary] = utility.get_items(&"physics")
	var main_item: Dictionary = items[0]

	assert_eq(ids.size(), 4, "3D 主向量加 XYZ 分量应产生四条线。")
	assert_eq(GFVariantData.get_option_int(main_item, "type"), GFDebugDrawUtility.PrimitiveType.LINE_3D, "3D 向量主线应复用 3D 线段图元。")
	assert_eq(GFVariantData.get_option_vector3(main_item, "from"), Vector3(9.0, -2.0, -3.0), "居中向量起点应从中心减半向量。")
	assert_eq(GFVariantData.get_option_vector3(main_item, "to"), Vector3(11.0, 2.0, 3.0), "居中向量终点应为中心加半向量。")
