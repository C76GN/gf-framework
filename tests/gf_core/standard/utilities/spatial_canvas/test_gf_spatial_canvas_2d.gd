extends GutTest


# --- 常量 ---

const _PAN_ACTION: StringName = &"gf_test_spatial_canvas_pan"
const _SELECTION_ACTION: StringName = &"gf_test_spatial_canvas_selection"
const _CANCEL_ACTION: StringName = &"gf_test_spatial_canvas_cancel"
const _TEST_ACTIONS: Array[StringName] = [
	_PAN_ACTION,
	_SELECTION_ACTION,
	_CANCEL_ACTION,
]


# --- 测试方法 ---

func after_each() -> void:
	for action_id: StringName in _TEST_ACTIONS:
		if InputMap.has_action(action_id):
			InputMap.erase_action(action_id)

func test_view_coordinates_round_trip_and_content_root_follow_view() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(canvas.set_view(Vector2(100.0, 50.0), 2.0), "有限视图应配置成功。")

	var canvas_position: Vector2 = canvas.world_to_canvas(Vector2(120.0, 60.0))
	var restored_world: Vector2 = canvas.canvas_to_world(canvas_position)
	var content_root: Node2D = canvas.get_content_root()

	assert_almost_eq(canvas_position.x, 440.0, 0.001, "世界 X 应映射到画布中心右侧。")
	assert_almost_eq(canvas_position.y, 320.0, 0.001, "世界 Y 应映射到画布中心下方。")
	assert_almost_eq(restored_world.x, 120.0, 0.001, "坐标往返不应漂移 X。")
	assert_almost_eq(restored_world.y, 60.0, 0.001, "坐标往返不应漂移 Y。")
	assert_eq(content_root.scale, Vector2(2.0, 2.0), "内容根应使用画布缩放。")
	assert_eq(content_root.position, Vector2(200.0, 200.0), "内容根应使用画布视图平移。")


func test_focal_zoom_keeps_world_position_under_focus() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(canvas.set_view(Vector2(50.0, 25.0), 1.0))
	var focus: Vector2 = Vector2(700.0, 500.0)
	var before: Vector2 = canvas.canvas_to_world(focus)

	assert_true(canvas.zoom_at(focus, 2.0), "合法缩放因子应被接受。")
	var after: Vector2 = canvas.canvas_to_world(focus)

	assert_almost_eq(after.x, before.x, 0.001, "焦点缩放不得改变焦点下的世界 X。")
	assert_almost_eq(after.y, before.y, 0.001, "焦点缩放不得改变焦点下的世界 Y。")
	assert_almost_eq(canvas.get_zoom(), 2.0, 0.001, "缩放值应更新。")


func test_view_bounds_clamp_center_and_center_small_world() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas(Vector2(40.0, 40.0))
	assert_true(canvas.set_world_bounds(Rect2(Vector2.ZERO, Vector2(100.0, 100.0)), true))
	assert_true(canvas.set_view(Vector2(-100.0, -100.0), 1.0))
	assert_eq(canvas.get_world_center(), Vector2(20.0, 20.0), "中心应为可见半尺寸保留边界。")

	assert_true(canvas.set_view(Vector2(500.0, 500.0), 1.0))
	assert_eq(canvas.get_world_center(), Vector2(80.0, 80.0), "中心应在另一侧边界内。")

	var resize_snapshots: Array[Dictionary] = []
	var _view_changed_connected: Error = canvas.view_changed.connect(
		func(snapshot: Dictionary) -> void:
			resize_snapshots.append(snapshot)
	) as Error
	canvas.size = Vector2(200.0, 200.0)
	assert_eq(canvas.get_world_center(), Vector2(50.0, 50.0), "视口大于世界时应固定在世界中心。")
	assert_eq(resize_snapshots.size(), 1, "尺寸变化必须发布新的可见世界矩形。")
	var visible_rect_value: Variant = GFVariantData.get_option_value(
		resize_snapshots[0],
		"visible_world_rect",
		Rect2()
	)
	var visible_rect: Rect2 = visible_rect_value if visible_rect_value is Rect2 else Rect2()
	assert_eq(
		visible_rect,
		Rect2(Vector2(-50.0, -50.0), Vector2(200.0, 200.0))
	)


func test_non_finite_view_and_grid_changes_are_transactional() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(canvas.set_view(Vector2(10.0, 20.0), 2.0))
	assert_true(canvas.configure_grid(Vector2(5.0, 6.0), Vector2(8.0, 12.0)))
	var original_center: Vector2 = canvas.get_world_center()
	var original_zoom: float = canvas.get_zoom()

	assert_false(canvas.set_view(Vector2(NAN, 0.0), 3.0), "非有限中心必须拒绝。")
	assert_false(canvas.set_view(Vector2.ZERO, INF), "非有限缩放必须拒绝。")
	assert_false(
		canvas.configure_grid(Vector2.ZERO, Vector2(0.0, 10.0)),
		"零网格尺寸必须拒绝。"
	)
	assert_false(
		canvas.configure_grid(Vector2(INF, 0.0), Vector2.ONE),
		"非有限网格原点必须拒绝。"
	)
	var overflowing_rect: Rect2 = Rect2(
		Vector2(2.0e38, 2.0e38),
		Vector2(2.0e38, 2.0e38)
	)
	assert_false(
		canvas.set_world_bounds(overflowing_rect),
		"终点溢出的世界边界必须拒绝。"
	)
	assert_false(
		canvas.upsert_item(&"overflowing", overflowing_rect),
		"终点溢出的条目边界必须拒绝。"
	)
	assert_eq(
		canvas.begin_placement(&"overflowing", overflowing_rect),
		0,
		"终点溢出的 footprint 必须拒绝。"
	)

	assert_eq(canvas.get_world_center(), original_center, "拒绝后中心不得变化。")
	assert_almost_eq(canvas.get_zoom(), original_zoom, 0.001, "拒绝后缩放不得变化。")
	assert_eq(canvas.get_grid_origin(), Vector2(5.0, 6.0), "拒绝后网格原点不得变化。")
	assert_eq(canvas.get_grid_size(), Vector2(8.0, 12.0), "拒绝后网格尺寸不得变化。")


func test_finite_inputs_with_non_finite_derived_geometry_fail_closed() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var original_center: Vector2 = canvas.get_world_center()
	var content_root: Node2D = canvas.get_content_root()

	assert_false(
		canvas.set_view(Vector2(2.0e38, 0.0), 2.0),
		"有限中心与缩放产生非有限内容变换时必须原子拒绝。"
	)
	assert_eq(canvas.get_world_center(), original_center)
	assert_true(
		not is_inf(content_root.position.x)
		and not is_nan(content_root.position.x)
		and not is_inf(content_root.position.y)
		and not is_nan(content_root.position.y)
	)

	assert_true(canvas.set_view(Vector2.ZERO, 2.0))
	assert_eq(
		canvas.world_to_canvas(Vector2(2.0e38, 0.0)),
		Vector2.ZERO,
		"世界到画布转换的派生结果溢出时必须返回稳定哨兵。"
	)
	assert_true(canvas.set_view(Vector2.ZERO, 0.05))
	assert_eq(
		canvas.canvas_to_world(Vector2(2.0e38, 0.0)),
		Vector2.ZERO,
		"画布到世界转换的派生结果溢出时必须返回稳定哨兵。"
	)

	assert_true(
		canvas.configure_grid(
			Vector2.ZERO,
			Vector2.ONE,
			{ "rotation_step_radians": 1.0e-308 }
		)
	)
	assert_eq(
		canvas.snap_rotation(1.0e308),
		0.0,
		"旋转步长除法溢出时不得返回 NaN。"
	)

	assert_gt(
		canvas.begin_placement(
			&"marker",
			Rect2(Vector2.ZERO, Vector2.ONE),
			{ "initial_world_position": Vector2(10.0, 10.0) }
		),
		0
	)
	var preview_before_invalid_input: Dictionary = canvas.get_placement_snapshot()
	var invalid_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	invalid_motion.position = Vector2(2.0e38, 0.0)
	assert_eq(
		canvas.handle_input_event(invalid_motion),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"无法转换的局部移动不得被当作世界原点。"
	)
	var invalid_release: InputEventMouseButton = InputEventMouseButton.new()
	invalid_release.button_index = MOUSE_BUTTON_LEFT
	invalid_release.pressed = false
	invalid_release.position = Vector2(2.0e38, 0.0)
	assert_eq(
		canvas.handle_input_event(invalid_release),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"无法转换的左键释放不得提交放置。"
	)
	assert_eq(
		canvas.get_placement_snapshot(),
		preview_before_invalid_input,
		"非法输入后活动预览必须保持不变。"
	)
	assert_true(canvas.has_active_placement())
	assert_true(GFVariantData.get_option_bool(canvas.cancel_placement(), "ok"))

	var large_rotated_footprint: Rect2 = Rect2(
		Vector2(2.5e38, 2.5e38),
		Vector2(1.0e37, 1.0e37)
	)
	assert_eq(
		canvas.begin_placement(
			&"large",
			large_rotated_footprint,
			{ "initial_rotation_radians": PI / 4.0 }
		),
		0,
		"旋转后的 footprint AABB 溢出时不得创建放置会话。"
	)
	assert_false(canvas.has_active_placement())


func test_grid_conversion_uses_floor_for_negative_coordinates_and_stable_snapping() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(
		canvas.configure_grid(
			Vector2.ZERO,
			Vector2(10.0, 10.0),
			{ "rotation_step_radians": PI / 2.0 }
		)
	)

	assert_eq(
		canvas.world_to_cell(Vector2(-0.1, -10.1)),
		Vector2i(-1, -2),
		"负坐标必须使用 floor 语义。"
	)
	assert_eq(canvas.cell_to_world(Vector2i(-1, -2)), Vector2(-10.0, -20.0))
	assert_eq(
		canvas.cell_to_world(Vector2i(-1, -2), true),
		Vector2(-5.0, -15.0),
		"调用方应能取得格子中心。"
	)
	assert_eq(canvas.snap_world_position(Vector2(-6.0, 14.0)), Vector2(-10.0, 10.0))
	assert_almost_eq(
		canvas.snap_rotation(PI * 0.6),
		PI / 2.0,
		0.001,
		"旋转应按显式步长吸附。"
	)


func test_item_queries_use_priority_stable_ids_and_exact_hit_hook() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(canvas.upsert_item(&"alpha", Rect2(Vector2.ZERO, Vector2(20.0, 20.0))))
	assert_true(
		canvas.upsert_item(
			&"beta",
			Rect2(Vector2.ZERO, Vector2(20.0, 20.0)),
			{ "selection_priority": 20 }
		)
	)
	assert_true(
		canvas.upsert_item(
			&"blocked",
			Rect2(Vector2.ZERO, Vector2(20.0, 20.0)),
			{
				"selection_priority": 100,
				"exact_hit": func(_item_id: StringName, _point: Vector2, _bounds: Rect2) -> bool:
					return false,
			}
		)
	)

	assert_eq(
		canvas.query_items_at(Vector2(5.0, 5.0)),
		PackedStringArray(["beta", "alpha"]),
		"精确命中应过滤候选，剩余项按优先级和稳定 ID 排序。"
	)


func test_point_and_containment_queries_include_shared_rect_boundaries() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var bounds: Rect2 = Rect2(Vector2(10.0, 20.0), Vector2(30.0, 40.0))
	assert_true(canvas.upsert_item(&"boundary", bounds))

	assert_eq(
		canvas.query_items_at(bounds.position),
		PackedStringArray(["boundary"]),
		"点查询应包含条目左上边界。"
	)
	assert_eq(
		canvas.query_items_at(bounds.end),
		PackedStringArray(["boundary"]),
		"点查询应与底层空间索引一致地包含条目右下边界。"
	)
	assert_eq(
		canvas.query_items_in_rect(bounds, true),
		PackedStringArray(["boundary"]),
		"完全相同的查询矩形应视为完全包含。"
	)


func test_select_point_skips_unselectable_occluders_and_rejects_non_finite_input() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas(Vector2(100.0, 100.0))
	assert_true(canvas.set_view(Vector2.ZERO, 1.0))
	assert_true(
		canvas.upsert_item(
			&"locked",
			Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)),
			{ "selectable": false, "selection_priority": 100 }
		)
	)
	assert_true(
		canvas.upsert_item(
			&"selectable",
			Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)),
			{ "selection_priority": 1 }
		)
	)

	assert_eq(
		canvas.select_point(Vector2(50.0, 50.0)),
		PackedStringArray(["selectable"]),
		"不可选高优先级条目不得遮挡下层可选条目。"
	)
	assert_eq(
		canvas.select_point(Vector2(NAN, 0.0)),
		PackedStringArray(["selectable"]),
		"非法画布坐标不得回退到世界原点并改写选择。"
	)


func test_item_and_query_budgets_fail_closed() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(
		canvas.configure_budgets(
			{
				"max_items": 2,
				"max_selection": 2,
				"max_query_candidates": 1,
				"max_grid_lines": 8,
			}
		)
	)
	assert_true(
		canvas.upsert_item(
			&"a",
			Rect2(Vector2.ZERO, Vector2.ONE),
			{ "selection_priority": 1 }
		)
	)
	assert_true(
		canvas.upsert_item(
			&"b",
			Rect2(Vector2.ZERO, Vector2.ONE),
			{ "selection_priority": 100 }
		)
	)
	assert_false(canvas.upsert_item(&"c", Rect2(Vector2.ZERO, Vector2.ONE)), "容量耗尽后不得插入。")

	var matches: PackedStringArray = canvas.query_items_at(Vector2(0.5, 0.5))
	var snapshot: Dictionary = canvas.get_debug_snapshot()
	assert_eq(matches, PackedStringArray(["b"]), "查询窗口必须保留全局最高优先级候选。")
	assert_true(
		GFVariantData.get_option_bool(snapshot, "last_query_truncated"),
		"诊断应明确记录查询截断。"
	)
	assert_false(
		canvas.configure_budgets({ "max_items": GFSpatialCanvas2D.ABSOLUTE_MAX_ITEMS + 1 }),
		"公开预算不得突破绝对上限。"
	)

	var selection_canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(selection_canvas.configure_budgets({ "max_query_candidates": 1 }))
	assert_true(
		selection_canvas.upsert_item(
			&"a_locked",
			Rect2(Vector2.ZERO, Vector2.ONE),
			{ "selectable": false, "selection_priority": 100 }
		)
	)
	assert_true(
		selection_canvas.upsert_item(
			&"z_selectable",
			Rect2(Vector2.ZERO, Vector2.ONE),
			{ "selection_priority": 1 }
		)
	)
	assert_eq(
		selection_canvas.select_point(
			selection_canvas.world_to_canvas(Vector2(0.5, 0.5))
		),
		PackedStringArray(["z_selectable"]),
		"不可选候选不得占用点选查询窗口。"
	)


func test_query_top_k_is_global_and_stable_for_multiple_candidates() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(canvas.configure_budgets({ "max_query_candidates": 3 }))
	var priorities: Dictionary = {
		&"a_low": 0,
		&"b_tie": 20,
		&"c_tie": 20,
		&"m_mid": 10,
		&"z_high": 30,
	}
	for item_id: StringName in [&"a_low", &"b_tie", &"c_tie", &"m_mid", &"z_high"]:
		assert_true(
			canvas.upsert_item(
				item_id,
				Rect2(Vector2.ZERO, Vector2.ONE),
				{ "selection_priority": GFVariantData.get_option_int(priorities, item_id) }
			)
		)

	assert_eq(
		canvas.query_items_at(Vector2(0.5, 0.5)),
		PackedStringArray(["z_high", "b_tie", "c_tie"]),
		"多元素 top-K 必须覆盖替换、下沉和同优先级稳定 ID 排序。"
	)
	var snapshot: Dictionary = canvas.get_debug_snapshot()
	assert_eq(GFVariantData.get_option_int(snapshot, "last_query_candidate_count"), 5)
	assert_true(GFVariantData.get_option_bool(snapshot, "last_query_truncated"))


func test_selection_budget_is_stable_before_truncation() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(canvas.configure_budgets({ "max_selection": 2 }))
	for item_id: StringName in [&"a", &"m", &"z"]:
		assert_true(canvas.upsert_item(item_id, Rect2(Vector2.ZERO, Vector2.ONE)))

	assert_eq(
		canvas.set_selection(PackedStringArray(["z", "m", "a"])),
		PackedStringArray(["a", "m"]),
		"选择应先按稳定 ID 排序，再应用实例预算。"
	)


func test_subtract_and_toggle_process_all_candidates_before_capacity_limit() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(canvas.configure_budgets({ "max_selection": 1 }))
	for item_id: StringName in [&"a", &"z"]:
		assert_true(canvas.upsert_item(item_id, Rect2(Vector2.ZERO, Vector2.ONE)))

	assert_eq(canvas.set_selection(PackedStringArray(["z"])), PackedStringArray(["z"]))
	assert_eq(
		canvas.set_selection(
			PackedStringArray(["a", "z"]),
			GFSpatialCanvas2D.SelectionMode.SUBTRACT
		),
		PackedStringArray(),
		"SUBTRACT 必须处理容量窗口外的已选 ID。"
	)

	assert_eq(canvas.set_selection(PackedStringArray(["z"])), PackedStringArray(["z"]))
	assert_eq(
		canvas.set_selection(
			PackedStringArray(["a", "z"]),
			GFSpatialCanvas2D.SelectionMode.TOGGLE
		),
		PackedStringArray(["a"]),
		"TOGGLE 应先移除全部命中，再按稳定顺序应用受容量限制的新增项。"
	)


func test_option_dictionaries_reject_unknown_or_mistyped_values_transactionally() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_false(
		canvas.configure_grid(
			Vector2.ZERO,
			Vector2.ONE,
			{ "visible": "true" }
		),
		"bool 选项不得接受字符串。"
	)
	assert_false(
		canvas.configure_budgets({ "max_items": 2.0 }),
		"整数预算不得静默接受 float。"
	)
	assert_false(
		canvas.upsert_item(
			&"invalid",
			Rect2(Vector2.ZERO, Vector2.ONE),
			{ "unknown": true }
		),
		"未知条目选项必须拒绝。"
	)
	assert_eq(
		canvas.begin_placement(
			&"invalid",
			Rect2(Vector2.ZERO, Vector2.ONE),
			{ "snap_to_grid": 1 }
		),
		0,
		"放置 bool 选项不得接受整数。"
	)
	assert_eq(canvas.get_grid_size(), Vector2.ONE)
	assert_true(canvas.get_item(&"invalid").is_empty())
	assert_false(canvas.has_active_placement())


func test_selection_modes_rect_selection_and_item_removal_are_consistent() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas(Vector2(100.0, 100.0))
	assert_true(canvas.set_view(Vector2(50.0, 50.0), 1.0))
	assert_true(canvas.upsert_item(&"a", Rect2(Vector2(10.0, 10.0), Vector2(10.0, 10.0))))
	assert_true(canvas.upsert_item(&"b", Rect2(Vector2(30.0, 10.0), Vector2(10.0, 10.0))))
	assert_true(canvas.upsert_item(&"locked", Rect2(Vector2(50.0, 10.0), Vector2(10.0, 10.0)), { "selectable": false }))

	assert_eq(
		canvas.set_selection(
			PackedStringArray(["a"]),
			GFSpatialCanvas2D.SelectionMode.REPLACE
		),
		PackedStringArray(["a"])
	)
	assert_eq(
		canvas.set_selection(
			PackedStringArray(["b"]),
			GFSpatialCanvas2D.SelectionMode.ADD
		),
		PackedStringArray(["a", "b"])
	)
	assert_eq(
		canvas.set_selection(
			PackedStringArray(["a"]),
			GFSpatialCanvas2D.SelectionMode.TOGGLE
		),
		PackedStringArray(["b"])
	)
	assert_eq(
		canvas.set_selection(
			PackedStringArray(["b"]),
			GFSpatialCanvas2D.SelectionMode.SUBTRACT
		),
		PackedStringArray()
	)

	var selected: PackedStringArray = canvas.select_rect(
		Rect2(Vector2(5.0, 5.0), Vector2(60.0, 20.0)),
		GFSpatialCanvas2D.SelectionMode.REPLACE
	)
	assert_eq(selected, PackedStringArray(["a", "b"]), "框选不得加入不可选项。")
	assert_true(canvas.remove_item(&"a"))
	assert_eq(canvas.get_selection(), PackedStringArray(["b"]), "移除条目必须同步清理选择。")


func test_selection_results_and_signals_are_copy_isolated() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(canvas.upsert_item(&"a", Rect2(Vector2.ZERO, Vector2.ONE)))
	var emitted: Array[PackedStringArray] = []
	var _selection_changed_connected: Error = canvas.selection_changed.connect(
		func(ids: PackedStringArray) -> void:
			emitted.append(ids)
			var _mutated_added: bool = ids.append("mutated")
	) as Error
	var selected: PackedStringArray = canvas.set_selection(
		PackedStringArray(["a"]),
		GFSpatialCanvas2D.SelectionMode.REPLACE
	)
	var _outside_added: bool = selected.append("outside")

	assert_eq(canvas.get_selection(), PackedStringArray(["a"]), "返回值和信号都不得泄露内部选择数组。")
	assert_eq(emitted.size(), 1, "实际变化应只发出一次信号。")


func test_placement_snaps_validates_and_emits_history_only_after_success() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(
		canvas.configure_grid(
			Vector2.ZERO,
			Vector2(10.0, 10.0),
			{ "rotation_step_radians": PI / 2.0 }
		)
	)
	var history_operations: Array[Dictionary] = []
	canvas.set_history_hook(
		func(operation: Dictionary) -> bool:
			history_operations.append(operation)
			return true
	)
	canvas.set_placement_validator(
		func(_preview: Dictionary) -> Dictionary:
			return { "ok": false, "reason": &"occupied" }
	)

	var session_id: int = canvas.begin_placement(
		&"tower",
		Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)),
		{
			"initial_world_position": Vector2(6.0, 14.0),
			"initial_rotation_radians": 1.4,
			"snap_to_grid": true,
			"snap_rotation": true,
		}
	)
	var preview: Dictionary = canvas.get_placement_snapshot()
	assert_gt(session_id, 0, "有效放置应创建会话。")
	assert_eq(GFVariantData.get_option_vector2(preview, "world_position"), Vector2(10.0, 10.0))
	assert_almost_eq(
		GFVariantData.get_option_float(preview, "rotation_radians"),
		PI / 2.0,
		0.001
	)

	var denied: Dictionary = canvas.commit_placement()
	assert_false(GFVariantData.get_option_bool(denied, "ok"), "项目校验拒绝时不得提交。")
	assert_eq(GFVariantData.get_option_string_name(denied, "reason"), &"occupied")
	assert_true(canvas.has_active_placement(), "拒绝后应保留预览供项目修正。")
	assert_true(history_operations.is_empty(), "失败提交不得触发历史 Hook。")

	canvas.set_placement_validator(func(_candidate: Dictionary) -> bool: return true)
	var committed: Dictionary = canvas.commit_placement()
	assert_true(GFVariantData.get_option_bool(committed, "ok"), "校验通过后应冻结通用操作记录。")
	assert_false(canvas.has_active_placement(), "成功后应结束会话。")
	assert_eq(history_operations.size(), 1, "成功提交只触发一次历史 Hook。")
	assert_eq(
		GFVariantData.get_option_string_name(history_operations[0], "type_id"),
		&"tower",
		"历史记录应包含稳定类型 ID。"
	)


func test_placement_history_rejection_and_callback_reentrancy_fail_closed() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var nested_results: Array[Dictionary] = []
	canvas.set_placement_validator(
		func(_preview: Dictionary) -> bool:
			nested_results.append(canvas.commit_placement())
			canvas.set_history_hook(Callable())
			return true
	)
	canvas.set_history_hook(func(_operation: Dictionary) -> bool: return false)
	assert_gt(canvas.begin_placement(&"road", Rect2(Vector2.ZERO, Vector2.ONE)), 0)

	var rejected: Dictionary = canvas.commit_placement()
	assert_eq(nested_results.size(), 1, "校验器应执行一次。")
	assert_eq(
		GFVariantData.get_option_string_name(nested_results[0], "reason"),
		&"callback_reentrancy",
		"回调内重入必须失败关闭。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(rejected, "reason"),
		&"history_rejected",
		"回调内不得移除 History Hook 并绕过其拒绝。"
	)
	assert_true(canvas.has_active_placement(), "历史拒绝后应保留会话。")
	canvas.set_placement_validator(func(_preview: Dictionary) -> bool: return true)
	canvas.set_history_hook(
		func(_operation: Dictionary) -> Dictionary:
			return { "ok": false, "reason": &"history_capacity_reached" }
	)
	var custom_rejection: Dictionary = canvas.commit_placement()
	assert_eq(
		GFVariantData.get_option_string_name(custom_rejection, "reason"),
		&"history_capacity_reached",
		"结构化 History Hook 的拒绝原因必须保留。"
	)
	assert_true(canvas.has_active_placement())


func test_cancel_reentrancy_cannot_clear_the_outer_placement_transaction() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var nested_cancel_reports: Array[Dictionary] = []
	canvas.set_placement_validator(
		func(_preview: Dictionary) -> bool:
			nested_cancel_reports.append(
				canvas.cancel_placement(&"nested_cancel")
			)
			return true
	)
	var session_id: int = canvas.begin_placement(
		&"bridge",
		Rect2(Vector2.ZERO, Vector2.ONE)
	)
	assert_gt(session_id, 0)

	var committed: Dictionary = canvas.commit_placement()
	assert_eq(nested_cancel_reports.size(), 1)
	assert_false(
		GFVariantData.get_option_bool(nested_cancel_reports[0], "ok"),
		"回调内取消必须失败关闭。"
	)
	assert_eq(
		GFVariantData.get_option_string_name(nested_cancel_reports[0], "reason"),
		&"callback_reentrancy"
	)
	assert_true(GFVariantData.get_option_bool(committed, "ok"))
	assert_eq(
		GFVariantData.get_option_int(committed, "session_id"),
		session_id,
		"外层提交不得因回调重入丢失会话身份。"
	)


func test_invalid_or_malformed_acceptance_callbacks_fail_closed() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_gt(
		canvas.begin_placement(&"gate", Rect2(Vector2.ZERO, Vector2.ONE)),
		0
	)
	var invalid_target: Node = Node.new()
	var invalid_callback: Callable = Callable(invalid_target, &"missing_callback")
	canvas.set_placement_validator(invalid_callback)
	invalid_target.free()

	var invalid_report: Dictionary = canvas.commit_placement()
	assert_false(GFVariantData.get_option_bool(invalid_report, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(invalid_report, "reason"),
		&"validation_rejected",
		"已配置但失效的校验器不得等同于空回调。"
	)
	assert_true(canvas.has_active_placement())

	canvas.set_placement_validator(
		func(_preview: Dictionary) -> Dictionary:
			return { "ok": "true" }
	)
	var malformed_report: Dictionary = canvas.commit_placement()
	assert_false(GFVariantData.get_option_bool(malformed_report, "ok"))
	assert_eq(
		GFVariantData.get_option_string_name(malformed_report, "reason"),
		&"validation_rejected",
		"Dictionary.ok 必须是严格 bool。"
	)
	assert_true(canvas.has_active_placement())


func test_cancel_placement_returns_stable_report_without_touching_content() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var project_child: Node2D = Node2D.new()
	canvas.get_content_root().add_child(project_child)
	assert_gt(canvas.begin_placement(&"marker", Rect2(Vector2.ZERO, Vector2.ONE)), 0)

	var report: Dictionary = canvas.cancel_placement(&"user_cancelled")
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_string_name(report, "reason"), &"user_cancelled")
	assert_false(canvas.has_active_placement())
	assert_true(is_instance_valid(project_child), "取消会话不得释放项目内容节点。")
	assert_eq(project_child.get_parent(), canvas.get_content_root(), "取消会话不得重挂项目内容。")
	var no_active_report: Dictionary = canvas.cancel_placement()
	assert_true(no_active_report.has("preview"), "取消失败报告仍应保持 preview schema。")
	assert_false(no_active_report.has("operation"), "取消报告不得混用提交报告的 operation schema。")


func test_screen_conversion_and_screen_input_respect_control_transform() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas(Vector2(200.0, 100.0))
	canvas.position = Vector2(30.0, 40.0)
	canvas.scale = Vector2(1.5, 2.0)
	assert_true(canvas.set_view(Vector2(20.0, 10.0), 1.0))
	var world_position: Vector2 = Vector2(35.0, 25.0)
	var screen_position: Vector2 = canvas.world_to_screen(world_position)
	var restored_world: Vector2 = canvas.screen_to_world(screen_position)

	assert_almost_eq(restored_world.x, world_position.x, 0.001)
	assert_almost_eq(restored_world.y, world_position.y, 0.001)

	var screen_focus: Vector2 = canvas.world_to_screen(Vector2(20.0, 10.0))
	var before_focus: Vector2 = canvas.screen_to_world(screen_focus)
	var wheel: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_WHEEL_UP,
		screen_focus,
		true
	)
	assert_eq(
		canvas.handle_screen_input_event(wheel),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"Viewport 坐标事件应先转换到本地画布坐标。"
	)
	var after_focus: Vector2 = canvas.screen_to_world(screen_focus)
	assert_almost_eq(after_focus.x, before_focus.x, 0.001)
	assert_almost_eq(after_focus.y, before_focus.y, 0.001)


func test_mouse_pan_and_wheel_zoom_are_captured_but_unrelated_input_is_not() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(canvas.set_view(Vector2.ZERO, 1.0))
	var press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_MIDDLE,
		Vector2(100.0, 100.0),
		true
	)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(120.0, 100.0)
	motion.relative = Vector2(20.0, 0.0)
	var release: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_MIDDLE,
		Vector2(120.0, 100.0),
		false
	)
	var wheel: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_WHEEL_UP,
		Vector2(400.0, 300.0),
		true
	)

	assert_eq(
		canvas.handle_input_event(press),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"中键按下应开始捕获。"
	)
	assert_eq(
		canvas.handle_input_event(motion),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"捕获期间移动应平移。"
	)
	assert_eq(canvas.get_world_center(), Vector2(-20.0, 0.0), "拖动画布应反向移动世界中心。")
	assert_eq(
		canvas.handle_input_event(release),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"中键释放应结束捕获。"
	)
	assert_eq(
		canvas.handle_input_event(wheel),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"滚轮应执行焦点缩放。"
	)
	assert_gt(canvas.get_zoom(), 1.0, "向上滚轮应放大。")
	assert_false(
		GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"),
		"一次性滚轮手势不得让诊断永久保持活动。"
	)

	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	assert_eq(
		canvas.handle_input_event(key),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"无活动操作时普通按键不应被捕获。"
	)


func test_public_input_and_selection_contracts_use_named_enum_types() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var policy: GFSpatialCanvasInputPolicy = canvas.get_input_policy()
	var wheel_axis: GFSpatialCanvasInputPolicy.WheelAxis = (
		policy.wheel_axis as GFSpatialCanvasInputPolicy.WheelAxis
	)
	var wheel_routing: GFSpatialCanvasInputPolicy.WheelRouting = (
		policy.wheel_routing as GFSpatialCanvasInputPolicy.WheelRouting
	)
	var touch_behavior: GFSpatialCanvasInputPolicy.TouchPrimaryBehavior = (
		policy.touch_primary_behavior as GFSpatialCanvasInputPolicy.TouchPrimaryBehavior
	)
	var disposition: GFSpatialCanvas2D.InputDisposition = canvas.handle_input_event(
		_key_event(KEY_A)
	)
	var default_selection_mode: GFSpatialCanvas2D.SelectionMode = (
		policy.selection_default_mode as GFSpatialCanvas2D.SelectionMode
	)
	var binding_selection_mode: GFSpatialCanvas2D.SelectionMode = (
		policy.selection_modifier_bindings[0].selection_mode as GFSpatialCanvas2D.SelectionMode
	)

	assert_eq(wheel_axis, GFSpatialCanvasInputPolicy.WheelAxis.VERTICAL)
	assert_eq(wheel_routing, GFSpatialCanvasInputPolicy.WheelRouting.CANVAS)
	assert_eq(
		touch_behavior,
		GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.PAN
	)
	assert_eq(disposition, GFSpatialCanvas2D.InputDisposition.IGNORED)
	assert_eq(default_selection_mode, GFSpatialCanvas2D.SelectionMode.REPLACE)
	assert_eq(binding_selection_mode, GFSpatialCanvas2D.SelectionMode.ADD)

	assert_true(canvas.upsert_item(&"typed", Rect2(Vector2(-1.0, -1.0), Vector2(2.0, 2.0))))
	assert_eq(
		canvas.set_selection(PackedStringArray(["typed"]), default_selection_mode),
		PackedStringArray(["typed"])
	)
	var canvas_position: Vector2 = canvas.world_to_canvas(Vector2.ZERO)
	var toggle_mode: GFSpatialCanvas2D.SelectionMode = GFSpatialCanvas2D.SelectionMode.TOGGLE
	assert_true(canvas.select_point(canvas_position, toggle_mode).is_empty())
	var add_mode: GFSpatialCanvas2D.SelectionMode = GFSpatialCanvas2D.SelectionMode.ADD
	assert_eq(
		canvas.select_rect(
			Rect2(canvas_position - Vector2.ONE, Vector2.ONE * 2.0),
			add_mode
		),
		PackedStringArray(["typed"])
	)


func test_active_middle_mouse_gesture_takes_priority_over_placement_motion() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_gt(
		canvas.begin_placement(
			&"tower",
			Rect2(Vector2.ZERO, Vector2.ONE),
			{ "initial_world_position": Vector2(10.0, 10.0) }
		),
		0
	)
	var press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_MIDDLE,
		Vector2(100.0, 100.0),
		true
	)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = Vector2(120.0, 100.0)
	motion.relative = Vector2(20.0, 0.0)
	var release: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_MIDDLE,
		Vector2(120.0, 100.0),
		false
	)

	assert_eq(
		canvas.handle_input_event(press),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(motion),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(release),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(canvas.get_world_center(), Vector2(-20.0, 0.0))
	assert_eq(
		GFVariantData.get_option_vector2(
			canvas.get_placement_snapshot(),
			"world_position"
		),
		Vector2(10.0, 10.0),
		"已捕获的平移手势不得被放置预览 MouseMotion 抢占。"
	)


func test_input_policy_validation_rejects_invalid_mappings_atomically() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var original_policy: GFSpatialCanvasInputPolicy = canvas.get_input_policy()
	var invalid_policy: GFSpatialCanvasInputPolicy = original_policy.duplicate_policy()
	invalid_policy.pan_action = _PAN_ACTION
	_add_mouse_action(_PAN_ACTION, MOUSE_BUTTON_RIGHT)

	var report: Dictionary = invalid_policy.validate_policy()
	assert_false(
		GFVariantData.get_option_bool(report, "ok"),
		"同一行为同时配置直接按钮和 action 必须失败关闭。"
	)
	assert_false(canvas.set_input_policy(invalid_policy), "非法策略不得部分应用。")
	assert_eq(
		canvas.get_input_policy().pan_mouse_button,
		original_policy.pan_mouse_button,
		"非法策略后必须保留上一份有效策略。"
	)

	var invalid_wheel_policy: GFSpatialCanvasInputPolicy = original_policy.duplicate_policy()
	invalid_wheel_policy.wheel_routing = (
		GFSpatialCanvasInputPolicy.WheelRouting.MODIFIER_GATED
	)
	invalid_wheel_policy.wheel_modifier_mask = (
		GFSpatialCanvasInputPolicy.ModifierMask.NONE
	)
	assert_false(
		GFVariantData.get_option_bool(invalid_wheel_policy.validate_policy(), "ok"),
		"modifier-gated wheel 必须声明非零 modifier。"
	)


func test_named_policy_enums_reject_dynamic_out_of_range_values_fail_closed() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var property_names: Array[StringName] = [
		&"wheel_axis",
		&"wheel_routing",
		&"touch_primary_behavior",
		&"selection_default_mode",
	]
	var issue_kinds: Array[String] = [
		"invalid_wheel_axis",
		"invalid_wheel_routing",
		"invalid_touch_behavior",
		"invalid_selection_mode",
	]
	for property_index: int in range(property_names.size()):
		var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
		policy.set(property_names[property_index], 99)
		var report: Dictionary = policy.validate_policy()
		assert_true(
			_report_has_issue_kind(report, issue_kinds[property_index]),
			"反射或反序列化写入的越界命名枚举必须由完整策略校验拒绝。"
		)
		assert_false(canvas.set_input_policy(policy), "非法动态枚举值不得部分应用。")


func test_invalid_nested_selection_mode_binding_is_rejected_atomically() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var original_policy: GFSpatialCanvasInputPolicy = canvas.get_input_policy()
	var invalid_policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	invalid_policy.selection_modifier_bindings.clear()
	var invalid_binding: GFSpatialCanvasSelectionModeBinding = (
		GFSpatialCanvasSelectionModeBinding.new()
	)
	invalid_binding.modifier_mask = GFSpatialCanvasInputPolicy.ModifierMask.SHIFT
	invalid_binding.set(&"selection_mode", 99)
	invalid_policy.selection_modifier_bindings.append(invalid_binding)

	var report: Dictionary = invalid_policy.validate_policy()
	assert_true(_report_has_issue_kind(report, "invalid_selection_mode"))
	assert_false(canvas.set_input_policy(invalid_policy))
	var retained_policy: GFSpatialCanvasInputPolicy = canvas.get_input_policy()
	assert_eq(retained_policy.selection_default_mode, original_policy.selection_default_mode)
	assert_eq(
		retained_policy.selection_modifier_bindings.size(),
		original_policy.selection_modifier_bindings.size(),
		"嵌套 binding 非法时不得部分替换 Canvas 策略。"
	)


func test_cancel_action_rejects_pointer_events_and_fixed_budget_overflow() -> void:
	_add_mouse_action(_CANCEL_ACTION, MOUSE_BUTTON_LEFT)
	var pointer_policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	pointer_policy.placement_cancel_action = _CANCEL_ACTION
	var pointer_report: Dictionary = pointer_policy.validate_policy()
	assert_true(
		_report_has_issue_kind(pointer_report, "pointer_cancel_action_event"),
		"取消动作不得占用任何 Canvas 指针 chord。"
	)

	_add_key_action(_CANCEL_ACTION, KEY_Q)
	for device_index: int in range(
		GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_ACTION_EVENTS + 2
	):
		var extra_key: InputEventKey = InputEventKey.new()
		extra_key.keycode = KEY_Q
		extra_key.device = device_index + 100
		InputMap.action_add_event(_CANCEL_ACTION, extra_key)
	assert_gt(
		InputMap.action_get_events(_CANCEL_ACTION).size(),
		GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_ACTION_EVENTS
	)
	var budget_policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	budget_policy.placement_cancel_action = _CANCEL_ACTION
	var budget_report: Dictionary = budget_policy.validate_policy()
	assert_true(
		_report_has_issue_kind(budget_report, "too_many_action_events"),
		"取消动作必须使用同一固定 64-event 扫描预算。"
	)


func test_canvas_isolates_policy_without_calling_overridable_candidate_methods() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var malicious_policy: MaliciousInputPolicy = MaliciousInputPolicy.new()
	malicious_policy.wheel_zoom_factor = 1.0
	assert_false(
		canvas.set_input_policy(malicious_policy),
		"候选 override 不得让非法字段绕过 GF 基类校验。"
	)
	assert_eq(malicious_policy.validate_call_count, 0)
	assert_eq(malicious_policy.duplicate_call_count, 0)

	malicious_policy.wheel_zoom_factor = 1.1
	malicious_policy.selection_modifier_bindings.clear()
	var malicious_binding: MaliciousSelectionBinding = MaliciousSelectionBinding.new()
	malicious_binding.modifier_mask = GFSpatialCanvasInputPolicy.ModifierMask.SHIFT
	malicious_binding.selection_mode = GFSpatialCanvas2D.SelectionMode.ADD
	malicious_policy.selection_modifier_bindings.append(malicious_binding)
	assert_true(canvas.set_input_policy(malicious_policy))
	assert_eq(malicious_policy.validate_call_count, 0)
	assert_eq(malicious_policy.duplicate_call_count, 0)
	assert_eq(malicious_binding.duplicate_call_count, 0)

	malicious_binding.selection_mode = GFSpatialCanvas2D.SelectionMode.SUBTRACT
	var isolated_policy: GFSpatialCanvasInputPolicy = canvas.get_input_policy()
	assert_false(
		isolated_policy is MaliciousInputPolicy,
		"Canvas 内部及 getter 必须返回纯 GF 基类策略。"
	)
	assert_false(
		isolated_policy.selection_modifier_bindings[0] is MaliciousSelectionBinding,
		"嵌套绑定也必须逐字段复制到纯 GF 基类实例。"
	)
	assert_eq(
		isolated_policy.selection_modifier_bindings[0].selection_mode,
		GFSpatialCanvas2D.SelectionMode.ADD,
		"应用后修改调用方嵌套 Resource 不得污染 Canvas。"
	)
	assert_eq(malicious_policy.duplicate_call_count, 0, "getter 也不得调用候选 override。")
	assert_eq(malicious_binding.duplicate_call_count, 0)


func test_pan_modifier_is_exact_and_action_owns_its_modifier_chord() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var direct_policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	direct_policy.pan_mouse_button = MOUSE_BUTTON_RIGHT
	direct_policy.pan_modifier_mask = GFSpatialCanvasInputPolicy.ModifierMask.SHIFT
	assert_true(canvas.set_input_policy(direct_policy))

	var plain_press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_RIGHT,
		Vector2(100.0, 100.0),
		true
	)
	assert_eq(
		canvas.handle_input_event(plain_press),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)
	var over_modified_press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_RIGHT,
		Vector2(100.0, 100.0),
		true
	)
	over_modified_press.shift_pressed = true
	over_modified_press.ctrl_pressed = true
	assert_eq(
		canvas.handle_input_event(over_modified_press),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"直接按钮必须精确匹配 modifier，不能把额外修饰键当作同一 chord。"
	)

	var exact_press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_RIGHT,
		Vector2(100.0, 100.0),
		true
	)
	exact_press.shift_pressed = true
	assert_eq(
		canvas.handle_input_event(exact_press),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	var release_without_modifier: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_RIGHT,
		Vector2(100.0, 100.0),
		false
	)
	assert_eq(
		canvas.handle_input_event(release_without_modifier),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"捕获后应由同一物理按钮释放，modifier 变化不能遗留捕获。"
	)

	_add_mouse_action(_PAN_ACTION, MOUSE_BUTTON_RIGHT)
	var action_policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	action_policy.pan_mouse_button = MOUSE_BUTTON_NONE
	action_policy.pan_action = _PAN_ACTION
	action_policy.pan_modifier_mask = GFSpatialCanvasInputPolicy.ModifierMask.SHIFT
	var action_report: Dictionary = action_policy.validate_policy()
	assert_false(GFVariantData.get_option_bool(action_report, "ok"))
	assert_true(
		_report_has_issue_kind(action_report, "action_modifier_conflict"),
		"action 的 modifier 必须只由 InputMap 精确 chord 声明。"
	)


func test_policy_rejects_physical_chord_overlap_across_mapping_sources() -> void:
	_add_mouse_action(
		_SELECTION_ACTION,
		MOUSE_BUTTON_MIDDLE,
		GFSpatialCanvasInputPolicy.ModifierMask.SHIFT
	)
	var direct_to_action: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	direct_to_action.pan_modifier_mask = GFSpatialCanvasInputPolicy.ModifierMask.SHIFT
	direct_to_action.selection_mouse_button = MOUSE_BUTTON_NONE
	direct_to_action.selection_action = _SELECTION_ACTION
	var direct_action_report: Dictionary = direct_to_action.validate_policy()
	assert_true(
		_report_has_issue_kind(direct_action_report, "ambiguous_pointer_mapping"),
		"direct pan 与 selection action 的同一物理 chord 必须被拒绝。"
	)

	_add_mouse_action(
		_PAN_ACTION,
		MOUSE_BUTTON_LEFT,
		GFSpatialCanvasInputPolicy.ModifierMask.ALT
	)
	var action_to_direct: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	action_to_direct.pan_mouse_button = MOUSE_BUTTON_NONE
	action_to_direct.pan_action = _PAN_ACTION
	var action_direct_report: Dictionary = action_to_direct.validate_policy()
	assert_true(
		_report_has_issue_kind(action_direct_report, "ambiguous_pointer_mapping"),
		"pan action 与 direct selection 的重叠必须被拒绝。"
	)

	_add_mouse_action(
		_PAN_ACTION,
		MOUSE_BUTTON_RIGHT,
		GFSpatialCanvasInputPolicy.ModifierMask.CTRL
	)
	_add_mouse_action(
		_SELECTION_ACTION,
		MOUSE_BUTTON_RIGHT,
		GFSpatialCanvasInputPolicy.ModifierMask.CTRL
	)
	var action_to_action: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	action_to_action.pan_mouse_button = MOUSE_BUTTON_NONE
	action_to_action.pan_action = _PAN_ACTION
	action_to_action.selection_mouse_button = MOUSE_BUTTON_NONE
	action_to_action.selection_action = _SELECTION_ACTION
	assert_true(
		_report_has_issue_kind(
			action_to_action.validate_policy(),
			"ambiguous_pointer_mapping"
		),
		"两个 InputMap action 的同一物理 chord 必须被拒绝。"
	)


func test_runtime_input_map_conflict_is_ignored_without_state_mutation() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	_add_mouse_action(_PAN_ACTION, MOUSE_BUTTON_RIGHT)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.pan_mouse_button = MOUSE_BUTTON_NONE
	policy.pan_action = _PAN_ACTION
	assert_true(canvas.set_input_policy(policy))

	_add_mouse_action(_PAN_ACTION, MOUSE_BUTTON_LEFT)
	var conflict_press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_LEFT,
		Vector2(100.0, 100.0),
		true
	)
	assert_eq(
		canvas.handle_input_event(conflict_press),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"策略应用后 InputMap 产生冲突时必须逐事件失败关闭。"
	)
	assert_eq(canvas.get_world_center(), Vector2.ZERO)
	assert_true(canvas.get_selection().is_empty())
	assert_false(
		GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"),
		"冲突事件不得留下任一捕获状态。"
	)


func test_runtime_pointer_action_budget_drift_fails_closed() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	_add_mouse_action(_PAN_ACTION, MOUSE_BUTTON_RIGHT)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.pan_mouse_button = MOUSE_BUTTON_NONE
	policy.pan_action = _PAN_ACTION
	assert_true(canvas.set_input_policy(policy))

	for device_index: int in range(
		GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_ACTION_EVENTS + 2
	):
		var extra_button: InputEventMouseButton = InputEventMouseButton.new()
		extra_button.button_index = MOUSE_BUTTON_RIGHT
		extra_button.device = device_index + 100
		InputMap.action_add_event(_PAN_ACTION, extra_button)
	assert_gt(
		InputMap.action_get_events(_PAN_ACTION).size(),
		GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_ACTION_EVENTS
	)
	var press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_RIGHT,
		Vector2(100.0, 100.0),
		true
	)
	assert_eq(
		canvas.handle_input_event(press),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"应用后膨胀的 InputMap action 不得进入无界匹配或建立捕获。"
	)
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))


func test_policy_validation_budgets_bindings_and_action_event_scans() -> void:
	var binding_policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	binding_policy.selection_modifier_bindings.clear()
	for mask: int in range(
		1,
		GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_SELECTION_MODIFIER_BINDINGS + 2
	):
		var binding: GFSpatialCanvasSelectionModeBinding = (
			GFSpatialCanvasSelectionModeBinding.new()
		)
		binding.modifier_mask = mask
		binding_policy.selection_modifier_bindings.append(binding)
	var binding_report: Dictionary = binding_policy.validate_policy()
	assert_true(
		_report_has_issue_kind(binding_report, "too_many_selection_bindings"),
		"选择绑定校验必须受 15 个非零组合的硬上限约束。"
	)

	if InputMap.has_action(_PAN_ACTION):
		InputMap.erase_action(_PAN_ACTION)
	InputMap.add_action(_PAN_ACTION)
	for event_index: int in range(
		GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_ACTION_EVENTS + 1
	):
		var action_event: InputEventMouseButton = InputEventMouseButton.new()
		var button_slot: int = event_index % 5
		var buttons: Array[MouseButton] = [
			MOUSE_BUTTON_LEFT,
			MOUSE_BUTTON_RIGHT,
			MOUSE_BUTTON_MIDDLE,
			MOUSE_BUTTON_XBUTTON1,
			MOUSE_BUTTON_XBUTTON2,
		]
		action_event.button_index = buttons[button_slot]
		_apply_modifier_mask(action_event, floori(float(event_index) / 5.0))
		action_event.device = event_index
		InputMap.action_add_event(_PAN_ACTION, action_event)
	assert_gt(
		InputMap.action_get_events(_PAN_ACTION).size(),
		GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_ACTION_EVENTS,
		"测试前置条件：InputMap action 应超过事件预算。"
	)
	var action_policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	action_policy.pan_mouse_button = MOUSE_BUTTON_NONE
	action_policy.pan_action = _PAN_ACTION
	action_policy.selection_mouse_button = MOUSE_BUTTON_NONE
	var action_report: Dictionary = action_policy.validate_policy()
	assert_true(
		_report_has_issue_kind(action_report, "too_many_action_events"),
		"超大 InputMap action 必须直接报告预算错误并停止扫描。"
	)


func test_policy_actions_buttons_and_modifier_selection_are_explicit() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	_add_mouse_action(_PAN_ACTION, MOUSE_BUTTON_RIGHT)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.pan_mouse_button = MOUSE_BUTTON_NONE
	policy.pan_action = _PAN_ACTION
	policy.selection_modifier_bindings.clear()
	var subtract_binding: GFSpatialCanvasSelectionModeBinding = (
		GFSpatialCanvasSelectionModeBinding.new()
	)
	subtract_binding.modifier_mask = GFSpatialCanvasInputPolicy.ModifierMask.SHIFT
	subtract_binding.selection_mode = GFSpatialCanvas2D.SelectionMode.SUBTRACT
	policy.selection_modifier_bindings.append(subtract_binding)
	assert_true(canvas.set_input_policy(policy))

	var middle_press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_MIDDLE,
		Vector2(100.0, 100.0),
		true
	)
	assert_eq(
		canvas.handle_input_event(middle_press),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"替换 pan 绑定后不得保留内置中键 fallback。"
	)

	var right_press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_RIGHT,
		Vector2(100.0, 100.0),
		true
	)
	var right_motion: InputEventMouseMotion = InputEventMouseMotion.new()
	right_motion.position = Vector2(120.0, 100.0)
	right_motion.relative = Vector2(20.0, 0.0)
	var right_release: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_RIGHT,
		Vector2(120.0, 100.0),
		false
	)
	assert_eq(
		canvas.handle_input_event(right_press),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(right_motion),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(right_release),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(canvas.get_world_center(), Vector2(-20.0, 0.0))

	assert_true(
		canvas.upsert_item(&"target", Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)))
	)
	var _initial_selection: PackedStringArray = canvas.set_selection(
		PackedStringArray(["target"])
	)
	var selection_position: Vector2 = canvas.world_to_canvas(Vector2.ZERO)
	var select_press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_LEFT,
		selection_position,
		true
	)
	select_press.shift_pressed = true
	var select_release: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_LEFT,
		selection_position,
		false
	)
	assert_eq(
		canvas.handle_input_event(select_press),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(select_release),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_true(canvas.get_selection().is_empty(), "Shift mapping 应按 policy 执行 subtract。")


func test_wheel_uses_bounded_smooth_event_factor() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.wheel_zoom_factor = 4.0
	assert_true(canvas.set_input_policy(policy))
	var wheel: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_WHEEL_UP,
		Vector2(400.0, 300.0),
		true
	)
	wheel.factor = 0.5
	assert_eq(
		canvas.handle_input_event(wheel),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_almost_eq(canvas.get_zoom(), 2.0, 0.001, "0.5 格应使用倍率的平方根。")

	var zoom_before_invalid: float = canvas.get_zoom()
	wheel.factor = 0.0
	assert_eq(
		canvas.handle_input_event(wheel),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)
	wheel.factor = 65.0
	assert_eq(
		canvas.handle_input_event(wheel),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"超出固定指数预算的 wheel factor 必须失败关闭。"
	)
	wheel.factor = NAN
	assert_eq(
		canvas.handle_input_event(wheel),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"非有限 wheel factor 必须失败关闭。"
	)
	assert_eq(canvas.get_zoom(), zoom_before_invalid)


func test_cancel_uses_input_map_action_instead_of_raw_escape() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	_add_key_action(_CANCEL_ACTION, KEY_Q)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.placement_cancel_action = _CANCEL_ACTION
	assert_true(canvas.set_input_policy(policy))
	assert_gt(canvas.begin_placement(&"marker", Rect2(Vector2.ZERO, Vector2.ONE)), 0)

	var escape_event: InputEventKey = _key_event(KEY_ESCAPE)
	assert_eq(
		canvas.handle_input_event(escape_event),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"Canvas 不得保留 raw Escape 特判。"
	)
	assert_true(canvas.has_active_placement())

	var cancel_event: InputEventKey = _key_event(KEY_Q)
	assert_eq(
		canvas.handle_input_event(cancel_event),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_false(canvas.has_active_placement())


func test_cancel_action_runtime_drift_cannot_starve_pointer_or_bypass_budget() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	_add_key_action(_CANCEL_ACTION, KEY_Q)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.placement_cancel_action = _CANCEL_ACTION
	assert_true(canvas.set_input_policy(policy))
	assert_gt(canvas.begin_placement(&"marker", Rect2(Vector2.ZERO, Vector2.ONE)), 0)

	_add_mouse_action(_CANCEL_ACTION, MOUSE_BUTTON_MIDDLE)
	var pan_press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_MIDDLE,
		Vector2(100.0, 100.0),
		true
	)
	var pan_release: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_MIDDLE,
		Vector2(100.0, 100.0),
		false
	)
	assert_eq(
		canvas.handle_input_event(pan_press),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"漂移为 pointer 的 cancel action 必须失败关闭并把事件留给 pan。"
	)
	assert_eq(
		canvas.handle_input_event(pan_release),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_true(canvas.has_active_placement(), "pointer 漂移不得取消 placement。")

	_add_key_action(_CANCEL_ACTION, KEY_Q)
	for device_index: int in range(
		GFSpatialCanvasInputPolicy.ABSOLUTE_MAX_ACTION_EVENTS + 2
	):
		var extra_key: InputEventKey = InputEventKey.new()
		extra_key.keycode = KEY_Q
		extra_key.device = device_index + 100
		InputMap.action_add_event(_CANCEL_ACTION, extra_key)
	assert_eq(
		canvas.handle_input_event(_key_event(KEY_Q)),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"超出运行期预算的 cancel action 必须失败关闭。"
	)
	assert_true(canvas.has_active_placement())


func test_manual_forwarding_distinguishes_handled_and_consumed() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas(Vector2(200.0, 100.0))
	canvas.position = Vector2(30.0, 40.0)
	canvas.scale = Vector2(1.5, 2.0)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.consume_wheel_events = false
	assert_true(canvas.set_input_policy(policy))
	var screen_focus: Vector2 = canvas.world_to_screen(Vector2.ZERO)
	var wheel: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_WHEEL_UP,
		screen_focus,
		true
	)
	var original_position: Vector2 = wheel.position

	assert_eq(
		canvas.handle_screen_input_event(wheel),
		GFSpatialCanvas2D.InputDisposition.HANDLED,
		"手工转发必须能观察到已处理但继续传播。"
	)
	assert_eq(wheel.position, original_position, "屏幕转发不得原地改写调用方事件。")
	assert_gt(canvas.get_zoom(), 1.0)

	policy.consume_wheel_events = true
	assert_true(canvas.set_input_policy(policy))
	assert_eq(
		canvas.handle_screen_input_event(wheel),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)


func test_system_gesture_policy_controls_pan_magnify_and_disposition() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.consume_handled_events = false
	assert_true(canvas.set_input_policy(policy))

	var pan_gesture: InputEventPanGesture = InputEventPanGesture.new()
	pan_gesture.position = Vector2(400.0, 300.0)
	pan_gesture.delta = Vector2(12.0, -8.0)
	assert_eq(
		canvas.handle_input_event(pan_gesture),
		GFSpatialCanvas2D.InputDisposition.HANDLED
	)
	assert_eq(canvas.get_world_center(), Vector2(-12.0, 8.0))

	policy.system_pan_gesture_enabled = false
	assert_true(canvas.set_input_policy(policy))
	var center_before_disabled_pan: Vector2 = canvas.get_world_center()
	assert_eq(
		canvas.handle_input_event(pan_gesture),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)
	assert_eq(canvas.get_world_center(), center_before_disabled_pan)

	var magnify_gesture: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	magnify_gesture.position = Vector2(400.0, 300.0)
	magnify_gesture.factor = 2.0
	assert_eq(
		canvas.handle_input_event(magnify_gesture),
		GFSpatialCanvas2D.InputDisposition.HANDLED
	)
	assert_almost_eq(canvas.get_zoom(), 2.0, 0.001)

	policy.system_magnify_gesture_enabled = false
	assert_true(canvas.set_input_policy(policy))
	var zoom_before_disabled_magnify: float = canvas.get_zoom()
	assert_eq(
		canvas.handle_input_event(magnify_gesture),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)
	assert_eq(canvas.get_zoom(), zoom_before_disabled_magnify)


func test_manual_screen_forwarding_localizes_system_gestures_without_mutation() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas(Vector2(240.0, 120.0))
	canvas.position = Vector2(30.0, 40.0)
	canvas.scale = Vector2(2.0, 2.0)
	var world_focus: Vector2 = Vector2(20.0, 10.0)
	var screen_focus: Vector2 = canvas.world_to_screen(world_focus)
	var magnify_gesture: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	magnify_gesture.position = screen_focus
	magnify_gesture.factor = 2.0

	assert_eq(
		canvas.handle_screen_input_event(magnify_gesture),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(magnify_gesture.position, screen_focus, "屏幕转发不得改写调用方手势事件。")
	assert_almost_eq(canvas.get_zoom(), 2.0, 0.001)
	var restored_focus: Vector2 = canvas.screen_to_world(screen_focus)
	assert_almost_eq(restored_focus.x, world_focus.x, 0.001)
	assert_almost_eq(restored_focus.y, world_focus.y, 0.001)

	var pan_gesture: InputEventPanGesture = InputEventPanGesture.new()
	pan_gesture.position = screen_focus
	pan_gesture.delta = Vector2(20.0, 0.0)
	var center_before_pan: Vector2 = canvas.get_world_center()
	assert_eq(
		canvas.handle_screen_input_event(pan_gesture),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(pan_gesture.position, screen_focus, "屏幕转发不得原地局部化 pan gesture。")
	assert_false(canvas.get_world_center().is_equal_approx(center_before_pan))


func test_touch_policy_selects_pans_and_can_disable_raw_touch() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(
		canvas.upsert_item(&"touch_target", Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)))
	)
	var touch_position: Vector2 = canvas.world_to_canvas(Vector2.ZERO)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.touch_primary_behavior = (
		GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.SELECT
	)
	assert_true(canvas.set_input_policy(policy))
	assert_eq(
		canvas.handle_input_event(_touch_event(0, true, touch_position)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(_touch_event(0, false, touch_position)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(canvas.get_selection(), PackedStringArray(["touch_target"]))
	assert_eq(canvas.get_world_center(), Vector2.ZERO, "触摸选择不得同时平移视图。")

	policy.touch_primary_behavior = GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.PAN
	assert_true(canvas.set_input_policy(policy))
	assert_eq(
		canvas.handle_input_event(_touch_event(1, true, touch_position)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(_touch_drag_event(1, touch_position + Vector2(20.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(_touch_event(1, false, touch_position + Vector2(20.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(canvas.get_world_center(), Vector2(-20.0, 0.0))

	policy.touch_enabled = false
	assert_true(canvas.set_input_policy(policy))
	assert_eq(
		canvas.handle_input_event(_touch_event(2, true, touch_position)),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)


func test_touch_primary_none_ignores_single_touch_when_multitouch_is_disabled() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.touch_primary_behavior = GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.NONE
	policy.touch_multi_pan_enabled = false
	policy.touch_multi_zoom_enabled = false
	assert_true(canvas.set_input_policy(policy))
	var start: Vector2 = Vector2(320.0, 240.0)
	var center_before: Vector2 = canvas.get_world_center()
	var zoom_before: float = canvas.get_zoom()

	assert_eq(
		canvas.handle_input_event(_touch_event(0, true, start)),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)
	assert_eq(
		canvas.handle_input_event(_touch_drag_event(0, start + Vector2(40.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)
	assert_eq(
		canvas.handle_input_event(_touch_event(0, false, start + Vector2(40.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)
	assert_eq(canvas.get_world_center(), center_before)
	assert_eq(canvas.get_zoom(), zoom_before)
	assert_true(canvas.get_selection().is_empty())
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))

	policy.touch_multi_pan_enabled = true
	assert_true(canvas.set_input_policy(policy))
	assert_eq(
		canvas.handle_input_event(_touch_event(1, true, start)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"启用多指行为时首触点必须被捕获以等待第二触点。"
	)
	assert_eq(
		canvas.handle_input_event(_touch_drag_event(1, start + Vector2(40.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(canvas.get_world_center(), center_before, "NONE 单指移动不得应用多指 pan。")
	assert_eq(canvas.get_zoom(), zoom_before)
	assert_eq(
		canvas.handle_input_event(_touch_event(1, false, start + Vector2(40.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))


func test_touch_multi_pan_and_zoom_are_independently_configurable() -> void:
	var first_point: Vector2 = Vector2(300.0, 300.0)
	var second_point: Vector2 = Vector2(400.0, 300.0)
	var moved_first_point: Vector2 = Vector2(280.0, 300.0)

	var pan_canvas: GFSpatialCanvas2D = _make_canvas()
	var pan_expected: GFSpatialCanvas2D = _make_canvas()
	var pan_policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	pan_policy.touch_primary_behavior = GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.NONE
	pan_policy.touch_multi_pan_enabled = true
	pan_policy.touch_multi_zoom_enabled = false
	assert_true(pan_canvas.set_input_policy(pan_policy))
	assert_eq(
		pan_canvas.handle_input_event(_touch_event(0, true, first_point)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		pan_canvas.handle_input_event(_touch_event(1, true, second_point)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		pan_canvas.handle_input_event(_touch_drag_event(0, moved_first_point)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_true(pan_expected.pan_by_canvas_delta(Vector2(-10.0, 0.0)))
	assert_eq(pan_canvas.get_world_center(), pan_expected.get_world_center())
	assert_eq(pan_canvas.get_zoom(), pan_expected.get_zoom(), "禁用多指缩放后距离变化不得修改 zoom。")
	var _pan_release_first: GFSpatialCanvas2D.InputDisposition = pan_canvas.handle_input_event(
		_touch_event(0, false, moved_first_point)
	)
	var _pan_release_second: GFSpatialCanvas2D.InputDisposition = pan_canvas.handle_input_event(
		_touch_event(1, false, second_point)
	)

	var zoom_canvas: GFSpatialCanvas2D = _make_canvas()
	var zoom_expected: GFSpatialCanvas2D = _make_canvas()
	var zoom_policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	zoom_policy.touch_primary_behavior = GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.NONE
	zoom_policy.touch_multi_pan_enabled = false
	zoom_policy.touch_multi_zoom_enabled = true
	assert_true(zoom_canvas.set_input_policy(zoom_policy))
	assert_eq(
		zoom_canvas.handle_input_event(_touch_event(0, true, first_point)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		zoom_canvas.handle_input_event(_touch_event(1, true, second_point)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		zoom_canvas.handle_input_event(_touch_drag_event(0, moved_first_point)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_true(zoom_expected.zoom_at(Vector2(340.0, 300.0), 1.2))
	assert_almost_eq(zoom_canvas.get_zoom(), zoom_expected.get_zoom(), 0.001)
	assert_almost_eq(
		zoom_canvas.get_world_center().x,
		zoom_expected.get_world_center().x,
		0.001,
		"禁用多指平移后只允许焦点缩放产生的中心修正。"
	)
	assert_almost_eq(
		zoom_canvas.get_world_center().y,
		zoom_expected.get_world_center().y,
		0.001
	)
	var _zoom_release_first: GFSpatialCanvas2D.InputDisposition = zoom_canvas.handle_input_event(
		_touch_event(0, false, moved_first_point)
	)
	var _zoom_release_second: GFSpatialCanvas2D.InputDisposition = zoom_canvas.handle_input_event(
		_touch_event(1, false, second_point)
	)


func test_touch_select_multi_to_single_does_not_restart_selection() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(
		canvas.upsert_item(&"target", Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)))
	)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.touch_primary_behavior = GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.SELECT
	assert_true(canvas.set_input_policy(policy))
	var center: Vector2 = canvas.world_to_canvas(Vector2.ZERO)
	assert_eq(
		canvas.handle_input_event(_touch_event(0, true, center)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(_touch_event(1, true, center + Vector2(40.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"第二触点应把未提交单指选择升级为多指手势。"
	)
	assert_eq(
		canvas.handle_input_event(_touch_drag_event(1, center + Vector2(60.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(_touch_event(1, false, center + Vector2(60.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	var center_after_downgrade: Vector2 = canvas.get_world_center()
	assert_eq(
		canvas.handle_input_event(_touch_drag_event(0, center + Vector2(10.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"降级后的剩余触点仍归当前手势所有，直到物理 release。"
	)
	assert_eq(canvas.get_world_center(), center_after_downgrade, "降级不得隐式切换为单指 pan。")
	assert_true(canvas.get_selection().is_empty(), "降级不得隐式重启选择捕获。")
	assert_eq(
		canvas.handle_input_event(_touch_event(0, false, center + Vector2(10.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))


func test_touch_multi_pan_and_zoom_disabled_leave_additional_pointer_unowned() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.touch_primary_behavior = GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.PAN
	policy.touch_multi_pan_enabled = false
	policy.touch_multi_zoom_enabled = false
	assert_true(canvas.set_input_policy(policy))
	var start: Vector2 = Vector2(100.0, 100.0)
	assert_eq(
		canvas.handle_input_event(_touch_event(0, true, start)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(_touch_event(1, true, start + Vector2(30.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)
	assert_eq(
		canvas.handle_input_event(_touch_drag_event(1, start + Vector2(40.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)
	assert_eq(
		canvas.handle_input_event(_touch_event(1, false, start + Vector2(40.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"未接管的额外触点 press/drag/release 都必须继续传播。"
	)
	assert_eq(
		canvas.handle_input_event(_touch_drag_event(0, start + Vector2(20.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(canvas.get_world_center(), Vector2(-20.0, 0.0))
	assert_eq(
		canvas.handle_input_event(_touch_event(0, false, start + Vector2(20.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)


func test_raw_touch_capture_excludes_mouse_without_polluting_selection_or_view() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(
		canvas.upsert_item(&"target", Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)))
	)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.touch_primary_behavior = GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.SELECT
	assert_true(canvas.set_input_policy(policy))
	var target_position: Vector2 = canvas.world_to_canvas(Vector2.ZERO)
	assert_eq(
		canvas.handle_input_event(_touch_event(0, true, target_position)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	var center_before_mouse: Vector2 = canvas.get_world_center()
	var zoom_before_mouse: float = canvas.get_zoom()
	var mouse_press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_LEFT,
		target_position + Vector2(80.0, 0.0),
		true
	)
	var mouse_drag: InputEventMouseMotion = InputEventMouseMotion.new()
	mouse_drag.position = target_position + Vector2(120.0, 0.0)
	mouse_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	var mouse_release: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_LEFT,
		mouse_drag.position,
		false
	)
	var wheel: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_WHEEL_UP,
		target_position,
		true
	)

	for conflicting_event: InputEvent in [mouse_press, mouse_drag, wheel, mouse_release]:
		assert_eq(
			canvas.handle_input_event(conflicting_event),
			GFSpatialCanvas2D.InputDisposition.IGNORED,
			"raw touch 捕获期间全部鼠标事件（含 wheel）都必须继续传播。"
		)
	assert_eq(canvas.get_world_center(), center_before_mouse)
	assert_eq(canvas.get_zoom(), zoom_before_mouse)
	assert_true(canvas.get_selection().is_empty(), "冲突鼠标不得提交或改写触摸选择几何。")
	assert_eq(
		canvas.handle_input_event(_touch_event(0, false, target_position)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(canvas.get_selection(), PackedStringArray(["target"]))
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))


func test_mouse_capture_excludes_raw_touch_until_matching_mouse_release() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(
		canvas.upsert_item(&"target", Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)))
	)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.touch_primary_behavior = GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.SELECT
	assert_true(canvas.set_input_policy(policy))
	var target_position: Vector2 = canvas.world_to_canvas(Vector2.ZERO)
	assert_eq(
		canvas.handle_input_event(
			_mouse_button(MOUSE_BUTTON_LEFT, target_position, true)
		),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	var touch_position: Vector2 = target_position + Vector2(100.0, 0.0)
	var center_before_touch: Vector2 = canvas.get_world_center()
	for conflicting_event: InputEvent in [
		_touch_event(7, true, touch_position),
		_touch_drag_event(7, touch_position + Vector2(30.0, 0.0)),
		_touch_event(7, false, touch_position + Vector2(30.0, 0.0)),
	]:
		assert_eq(
			canvas.handle_input_event(conflicting_event),
			GFSpatialCanvas2D.InputDisposition.IGNORED,
			"鼠标捕获期间 raw touch press/drag/release 都不得接管状态。"
		)
	assert_eq(canvas.get_world_center(), center_before_touch)
	assert_true(canvas.get_selection().is_empty())
	assert_eq(
		canvas.handle_input_event(
			_mouse_button(MOUSE_BUTTON_LEFT, target_position, false)
		),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(canvas.get_selection(), PackedStringArray(["target"]))
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))


func test_active_physical_capture_excludes_system_gestures_until_release() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var focus: Vector2 = Vector2(400.0, 300.0)
	var pan_gesture: InputEventPanGesture = InputEventPanGesture.new()
	pan_gesture.position = focus
	pan_gesture.delta = Vector2(25.0, -10.0)
	var magnify_gesture: InputEventMagnifyGesture = InputEventMagnifyGesture.new()
	magnify_gesture.position = focus
	magnify_gesture.factor = 2.0
	assert_eq(
		canvas.handle_input_event(_mouse_button(MOUSE_BUTTON_MIDDLE, focus, true)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	for system_gesture: InputEvent in [pan_gesture, magnify_gesture]:
		assert_eq(
			canvas.handle_input_event(system_gesture),
			GFSpatialCanvas2D.InputDisposition.IGNORED,
			"鼠标捕获期间系统手势不得修改 Canvas。"
		)
	assert_eq(canvas.get_world_center(), Vector2.ZERO)
	assert_eq(canvas.get_zoom(), 1.0)
	assert_eq(
		canvas.handle_input_event(_mouse_button(MOUSE_BUTTON_MIDDLE, focus, false)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))

	assert_eq(
		canvas.handle_input_event(_touch_event(3, true, focus)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	for system_gesture: InputEvent in [pan_gesture, magnify_gesture]:
		assert_eq(
			canvas.handle_input_event(system_gesture),
			GFSpatialCanvas2D.InputDisposition.IGNORED,
			"raw touch 捕获期间系统手势不得修改 Canvas。"
		)
	assert_eq(canvas.get_world_center(), Vector2.ZERO)
	assert_eq(canvas.get_zoom(), 1.0)
	assert_eq(
		canvas.handle_input_event(_touch_event(3, false, focus)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))
	assert_eq(
		canvas.handle_input_event(pan_gesture),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"物理捕获结束后系统手势应恢复正常处理。"
	)
	assert_eq(canvas.get_world_center(), Vector2(-25.0, 10.0))
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))


func test_cancel_and_policy_replacement_release_entire_physical_capture() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	_add_key_action(_CANCEL_ACTION, KEY_Q)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.placement_cancel_action = _CANCEL_ACTION
	policy.touch_primary_behavior = GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.SELECT
	assert_true(canvas.set_input_policy(policy))
	var position: Vector2 = Vector2(200.0, 150.0)
	assert_eq(
		canvas.handle_input_event(_touch_event(4, true, position)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(_key_event(KEY_Q)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED,
		"显式 cancel 应释放 raw-touch owner 和 pointer tracking。"
	)
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))
	assert_eq(
		canvas.handle_input_event(_touch_drag_event(4, position + Vector2(20.0, 0.0))),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)
	assert_eq(
		canvas.handle_input_event(_touch_event(4, false, position)),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"cancel 后的陈旧 release 不得复活已结束捕获。"
	)

	assert_eq(
		canvas.handle_input_event(_mouse_button(MOUSE_BUTTON_MIDDLE, position, true)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(_key_event(KEY_Q)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_eq(
		canvas.handle_input_event(_mouse_button(MOUSE_BUTTON_MIDDLE, position, false)),
		GFSpatialCanvas2D.InputDisposition.IGNORED
	)
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))

	assert_eq(
		canvas.handle_input_event(_touch_event(5, true, position)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_true(canvas.set_input_policy(GFSpatialCanvasInputPolicy.new()))
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))
	assert_eq(
		canvas.handle_input_event(_touch_event(5, false, position)),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"成功替换策略必须原子释放旧 raw-touch 捕获。"
	)


func test_canceled_pointer_release_discards_capture_without_committing() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_true(
		canvas.upsert_item(&"target", Rect2(Vector2(-5.0, -5.0), Vector2(10.0, 10.0)))
	)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.touch_primary_behavior = GFSpatialCanvasInputPolicy.TouchPrimaryBehavior.SELECT
	assert_true(canvas.set_input_policy(policy))
	var target_position: Vector2 = canvas.world_to_canvas(Vector2.ZERO)
	assert_eq(
		canvas.handle_input_event(_touch_event(6, true, target_position)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	var canceled_touch: InputEventScreenTouch = _touch_event(6, false, target_position)
	canceled_touch.canceled = true
	assert_eq(
		canvas.handle_input_event(canceled_touch),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_true(canvas.get_selection().is_empty(), "系统取消的 touch 不得提交选择。")
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))
	assert_eq(
		canvas.handle_input_event(_touch_event(6, false, target_position)),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"取消后的陈旧 release 不得恢复 capture。"
	)

	var history_commit_count: Array[int] = [0]
	canvas.set_history_hook(
		func(_operation: Dictionary) -> bool:
			history_commit_count[0] += 1
			return true
	)
	assert_gt(canvas.begin_placement(&"marker", Rect2(Vector2.ZERO, Vector2.ONE)), 0)
	assert_eq(
		canvas.handle_input_event(_mouse_button(MOUSE_BUTTON_LEFT, target_position, true)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	var canceled_mouse: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_LEFT,
		target_position,
		false
	)
	canceled_mouse.canceled = true
	assert_eq(
		canvas.handle_input_event(canceled_mouse),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_true(canvas.has_active_placement(), "系统取消的鼠标 release 不得提交 placement。")
	assert_eq(history_commit_count[0], 0)
	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))


func test_input_disable_releases_capture_without_clearing_placement() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	assert_gt(canvas.begin_placement(&"marker", Rect2(Vector2.ZERO, Vector2.ONE)), 0)
	var pan_press: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_MIDDLE,
		Vector2(100.0, 100.0),
		true
	)
	assert_eq(
		canvas.handle_input_event(pan_press),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	canvas.set_input_enabled(false)
	canvas.set_input_enabled(true)
	var stale_release: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_MIDDLE,
		Vector2(120.0, 100.0),
		false
	)
	assert_eq(
		canvas.handle_input_event(stale_release),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"禁用输入必须释放已捕获的 pan。"
	)
	assert_eq(canvas.get_world_center(), Vector2.ZERO)
	assert_true(canvas.has_active_placement(), "输入生命周期清理不得取消 placement。")


func test_application_focus_loss_releases_mouse_capture_and_ignores_stale_release() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var position: Vector2 = Vector2(100.0, 100.0)
	assert_eq(
		canvas.handle_input_event(_mouse_button(MOUSE_BUTTON_MIDDLE, position, true)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_true(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))

	canvas.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)

	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))
	assert_eq(
		canvas.handle_input_event(_mouse_button(MOUSE_BUTTON_MIDDLE, position, false)),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"应用失焦后的陈旧 release 不得恢复已释放的 mouse owner。"
	)
	assert_eq(canvas.get_world_center(), Vector2.ZERO)


func test_hiding_canvas_releases_raw_touch_capture_and_ignores_stale_release() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	var position: Vector2 = Vector2(100.0, 100.0)
	assert_eq(
		canvas.handle_input_event(_touch_event(7, true, position)),
		GFSpatialCanvas2D.InputDisposition.CONSUMED
	)
	assert_true(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))

	canvas.hide()

	assert_false(GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"))
	canvas.show()
	assert_eq(
		canvas.handle_input_event(_touch_event(7, false, position)),
		GFSpatialCanvas2D.InputDisposition.IGNORED,
		"Canvas 隐藏后的陈旧 release 不得恢复已释放的 touch owner。"
	)
	assert_eq(canvas.get_world_center(), Vector2.ZERO)


func test_modifier_gated_wheel_bubbles_to_parent_scroll_container() -> void:
	var scroll: ScrollProbe = ScrollProbe.new()
	add_child_autofree(scroll)
	scroll.position = Vector2(40.0, 40.0)
	scroll.size = Vector2(200.0, 120.0)
	var content: Control = Control.new()
	content.custom_minimum_size = Vector2(200.0, 600.0)
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(content)
	var canvas: GFSpatialCanvas2D = GFSpatialCanvas2D.new()
	canvas.size = content.custom_minimum_size
	content.add_child(canvas)
	var policy: GFSpatialCanvasInputPolicy = GFSpatialCanvasInputPolicy.new()
	policy.wheel_routing = GFSpatialCanvasInputPolicy.WheelRouting.MODIFIER_GATED
	policy.wheel_modifier_mask = GFSpatialCanvasInputPolicy.ModifierMask.CTRL
	assert_true(canvas.set_input_policy(policy))
	await wait_process_frames(2)

	var wheel_position: Vector2 = scroll.position + Vector2(80.0, 60.0)
	var plain_wheel: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_WHEEL_DOWN,
		wheel_position,
		true
	)
	Input.parse_input_event(plain_wheel)
	await wait_process_frames(2)
	assert_gt(scroll.wheel_event_count, 0, "未修饰 wheel 应冒泡到父 ScrollContainer。")
	assert_eq(canvas.get_zoom(), 1.0)

	var parent_count_before_ctrl: int = scroll.wheel_event_count
	var ctrl_wheel: InputEventMouseButton = _mouse_button(
		MOUSE_BUTTON_WHEEL_UP,
		wheel_position,
		true
	)
	ctrl_wheel.ctrl_pressed = true
	Input.parse_input_event(ctrl_wheel)
	await wait_process_frames(2)
	assert_eq(
		scroll.wheel_event_count,
		parent_count_before_ctrl,
		"Canvas 消费的 Ctrl+wheel 不得继续到父 ScrollContainer。"
	)
	assert_gt(canvas.get_zoom(), 1.0)


func test_debug_snapshot_is_json_safe_and_excludes_callbacks_and_project_payloads() -> void:
	var canvas: GFSpatialCanvas2D = _make_canvas()
	canvas.set_placement_validator(func(_preview: Dictionary) -> bool: return true)
	canvas.set_history_hook(func(_operation: Dictionary) -> bool: return true)
	assert_true(
		canvas.upsert_item(
			&"secret_item",
			Rect2(Vector2.ZERO, Vector2.ONE),
			{ "exact_hit": func(_id: StringName, _point: Vector2, _bounds: Rect2) -> bool: return true }
		)
	)
	assert_gt(canvas.begin_placement(&"secret_type", Rect2(Vector2.ZERO, Vector2.ONE)), 0)

	var snapshot: Dictionary = canvas.get_debug_snapshot()
	var encoded: String = JSON.stringify(snapshot)
	assert_false(encoded.is_empty(), "诊断快照必须可 JSON 编码。")
	assert_eq(encoded.find("Callable"), -1, "诊断不得泄露回调。")
	assert_eq(encoded.find("payload"), -1, "诊断不得包含任意项目载荷。")
	assert_eq(GFVariantData.get_option_int(snapshot, "item_count"), 1)
	assert_true(GFVariantData.get_option_bool(snapshot, "placement_active"))


# --- 私有/辅助方法 ---

func _make_canvas(canvas_size: Vector2 = Vector2(800.0, 600.0)) -> GFSpatialCanvas2D:
	var canvas: GFSpatialCanvas2D = GFSpatialCanvas2D.new()
	add_child_autofree(canvas)
	canvas.size = canvas_size
	return canvas


func _mouse_button(button_index: MouseButton, position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	event.position = position
	event.pressed = pressed
	return event


func _key_event(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _touch_event(index: int, pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	return event


func _touch_drag_event(index: int, position: Vector2) -> InputEventScreenDrag:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event


func _add_mouse_action(
	action_id: StringName,
	button_index: MouseButton,
	modifier_mask: int = GFSpatialCanvasInputPolicy.ModifierMask.NONE
) -> void:
	if InputMap.has_action(action_id):
		InputMap.erase_action(action_id)
	InputMap.add_action(action_id)
	var input_event: InputEventMouseButton = InputEventMouseButton.new()
	input_event.button_index = button_index
	_apply_modifier_mask(input_event, modifier_mask)
	InputMap.action_add_event(action_id, input_event)


func _add_key_action(action_id: StringName, keycode: Key) -> void:
	if InputMap.has_action(action_id):
		InputMap.erase_action(action_id)
	InputMap.add_action(action_id)
	var input_event: InputEventKey = InputEventKey.new()
	input_event.keycode = keycode
	InputMap.action_add_event(action_id, input_event)


func _apply_modifier_mask(event: InputEventMouseButton, modifier_mask: int) -> void:
	event.shift_pressed = (
		modifier_mask & GFSpatialCanvasInputPolicy.ModifierMask.SHIFT
	) != 0
	event.ctrl_pressed = (
		modifier_mask & GFSpatialCanvasInputPolicy.ModifierMask.CTRL
	) != 0
	event.alt_pressed = (
		modifier_mask & GFSpatialCanvasInputPolicy.ModifierMask.ALT
	) != 0
	event.meta_pressed = (
		modifier_mask & GFSpatialCanvasInputPolicy.ModifierMask.META
	) != 0


func _report_has_issue_kind(report: Dictionary, expected_kind: String) -> bool:
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string(issue, "kind") == expected_kind:
			return true
	return false


# --- 内部类 ---

class MaliciousInputPolicy extends GFSpatialCanvasInputPolicy:
	var validate_call_count: int = 0
	var duplicate_call_count: int = 0


	func validate_policy() -> Dictionary:
		validate_call_count += 1
		return { "ok": true, "issues": [] }


	func duplicate_policy() -> GFSpatialCanvasInputPolicy:
		duplicate_call_count += 1
		return self


class MaliciousSelectionBinding extends GFSpatialCanvasSelectionModeBinding:
	var duplicate_call_count: int = 0


	func duplicate_binding() -> GFSpatialCanvasSelectionModeBinding:
		duplicate_call_count += 1
		return self


class ScrollProbe extends ScrollContainer:
	var wheel_event_count: int = 0


	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse_event: InputEventMouseButton = event
			if mouse_event.button_index in [
				MOUSE_BUTTON_WHEEL_UP,
				MOUSE_BUTTON_WHEEL_DOWN,
				MOUSE_BUTTON_WHEEL_LEFT,
				MOUSE_BUTTON_WHEEL_RIGHT,
			]:
				wheel_event_count += 1
