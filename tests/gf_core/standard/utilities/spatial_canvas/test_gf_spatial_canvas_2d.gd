extends GutTest


# --- 测试方法 ---

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
	assert_false(
		canvas.handle_input_event(invalid_motion),
		"无法转换的局部移动不得被当作世界原点。"
	)
	var invalid_release: InputEventMouseButton = InputEventMouseButton.new()
	invalid_release.button_index = MOUSE_BUTTON_LEFT
	invalid_release.pressed = false
	invalid_release.position = Vector2(2.0e38, 0.0)
	assert_false(
		canvas.handle_input_event(invalid_release),
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
		canvas.set_selection(PackedStringArray(["a"]), GFSpatialCanvas2D.SelectionMode.REPLACE),
		PackedStringArray(["a"])
	)
	assert_eq(
		canvas.set_selection(PackedStringArray(["b"]), GFSpatialCanvas2D.SelectionMode.ADD),
		PackedStringArray(["a", "b"])
	)
	assert_eq(
		canvas.set_selection(PackedStringArray(["a"]), GFSpatialCanvas2D.SelectionMode.TOGGLE),
		PackedStringArray(["b"])
	)
	assert_eq(
		canvas.set_selection(PackedStringArray(["b"]), GFSpatialCanvas2D.SelectionMode.SUBTRACT),
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
	assert_true(
		canvas.handle_screen_input_event(wheel),
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

	assert_true(canvas.handle_input_event(press), "中键按下应开始捕获。")
	assert_true(canvas.handle_input_event(motion), "捕获期间移动应平移。")
	assert_eq(canvas.get_world_center(), Vector2(-20.0, 0.0), "拖动画布应反向移动世界中心。")
	assert_true(canvas.handle_input_event(release), "中键释放应结束捕获。")
	assert_true(canvas.handle_input_event(wheel), "滚轮应执行焦点缩放。")
	assert_gt(canvas.get_zoom(), 1.0, "向上滚轮应放大。")
	assert_false(
		GFVariantData.get_option_bool(canvas.get_debug_snapshot(), "input_active"),
		"一次性滚轮手势不得让诊断永久保持活动。"
	)

	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_A
	key.pressed = true
	assert_false(canvas.handle_input_event(key), "无活动操作时普通按键不应被捕获。")


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

	assert_true(canvas.handle_input_event(press))
	assert_true(canvas.handle_input_event(motion))
	assert_true(canvas.handle_input_event(release))
	assert_eq(canvas.get_world_center(), Vector2(-20.0, 0.0))
	assert_eq(
		GFVariantData.get_option_vector2(
			canvas.get_placement_snapshot(),
			"world_position"
		),
		Vector2(10.0, 10.0),
		"已捕获的平移手势不得被放置预览 MouseMotion 抢占。"
	)


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
