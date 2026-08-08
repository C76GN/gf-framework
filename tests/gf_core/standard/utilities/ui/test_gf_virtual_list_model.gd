## 测试 GFVirtualListModel 的可变尺寸列表布局计算。
extends GutTest

func test_visible_range_uses_estimated_extent_and_overscan() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.estimated_item_extent = 60.0
	model.overscan_items = 1
	model.set_item_count(10)

	var visible_range: Vector2i = model.get_visible_range(120.0, 120.0)

	assert_eq(model.get_content_extent(false), 600.0, "估算尺寸应形成初始内容高度。")
	assert_eq(visible_range, Vector2i(1, 5), "可见范围应包含视口命中的条目及 overscan。")


func test_measured_extent_updates_offsets_and_visible_items() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.estimated_item_extent = 50.0
	model.overscan_items = 0
	model.set_item_count(3)

	var report: Dictionary = model.set_item_extent(1, 80.0)
	var visible_items: Array[Dictionary] = model.get_visible_items(0.0, 200.0)
	var measured_item: Dictionary = visible_items[1]

	assert_true(GFVariantData.get_option_bool(report, "ok"), "合法索引应返回成功报告。")
	assert_true(GFVariantData.get_option_bool(report, "changed"), "实测尺寸变化应报告 changed。")
	assert_eq(model.get_content_extent(false), 180.0, "实测尺寸应更新内容总高度。")
	assert_eq(model.get_item_offset(2), 130.0, "后续条目偏移应基于实测尺寸。")
	assert_eq(GFVariantData.get_option_int(measured_item, "index"), 1, "可见条目记录应包含索引。")
	assert_eq(GFVariantData.get_option_float(measured_item, "offset"), 50.0, "可见条目记录应包含偏移。")
	assert_true(GFVariantData.get_option_bool(measured_item, "measured"), "实测条目记录应标记 measured。")


func test_extent_change_reports_scroll_adjustment_for_items_above_viewport() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.estimated_item_extent = 50.0
	model.set_item_count(3)

	var report: Dictionary = model.set_item_extent(0, 90.0, true, 120.0)

	assert_eq(GFVariantData.get_option_float(report, "delta"), 40.0, "报告应包含尺寸变化量。")
	assert_eq(GFVariantData.get_option_float(report, "scroll_adjustment"), 40.0, "视口前方条目变化时应返回滚动锚点修正值。")


func test_extent_change_inside_viewport_does_not_adjust_scroll() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.estimated_item_extent = 50.0
	model.set_item_count(3)

	var report: Dictionary = model.set_item_extent(1, 90.0, true, 60.0)

	assert_eq(GFVariantData.get_option_float(report, "delta"), 40.0, "报告应包含尺寸变化量。")
	assert_eq(GFVariantData.get_option_float(report, "scroll_adjustment"), 0.0, "视口内条目变化不应自动修正滚动偏移。")


func test_remove_item_and_trailing_padding_keep_content_extent_consistent() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.estimated_item_extent = 40.0
	model.trailing_padding = 12.0
	model.set_item_count(4)
	var removed: bool = model.remove_item(1)

	assert_true(removed, "合法索引应可移除。")
	assert_eq(model.get_item_count(), 3, "移除后条目数量应减少。")
	assert_eq(model.get_content_extent(false), 120.0, "内容尺寸不应包含 trailing padding。")
	assert_eq(model.get_content_extent(), 132.0, "默认内容尺寸应包含 trailing padding。")


func test_large_trailing_padding_preserves_one_pixel_updates() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.set_item_count(1)
	model.trailing_padding = 1_000_000_000.0
	watch_signals(model)
	var previous_revision: int = model.get_revision()

	model.trailing_padding = 1_000_000_001.0

	assert_eq(model.trailing_padding, 1_000_000_001.0)
	assert_eq(
		model.get_content_extent(),
		model.estimated_item_extent + 1_000_000_001.0,
		"大数值下的整像素 padding 变化不得被相对容差吞掉。"
	)
	assert_eq(model.get_revision(), previous_revision + 1)
	assert_signal_emit_count(model, "layout_changed", 1)


func test_reset_item_extent_returns_item_to_estimate() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.estimated_item_extent = 40.0
	model.set_item_count(2)
	var _report: Dictionary = model.set_item_extent(0, 96.0)
	var reset: bool = model.reset_item_extent(0)

	assert_true(reset, "合法索引应可重置。")
	assert_eq(model.get_item_extent(0), 40.0, "重置后应回到估算尺寸。")
	assert_false(model.is_item_measured(0), "重置后条目不应仍标记为实测。")


func test_reset_item_extent_restores_large_unmeasured_one_pixel_difference() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.estimated_item_extent = 1_000_000_000.0
	model.set_item_count(1)
	var report: Dictionary = model.set_item_extent(0, 1_000_000_001.0, false)
	assert_true(GFVariantData.get_option_bool(report, "changed"))
	assert_false(model.is_item_measured(0))
	watch_signals(model)
	var previous_revision: int = model.get_revision()

	var reset: bool = model.reset_item_extent(0)

	assert_true(reset)
	assert_eq(model.get_item_extent(0), 1_000_000_000.0)
	assert_false(model.is_item_measured(0))
	assert_eq(model.get_revision(), previous_revision + 1)
	assert_signal_emit_count(model, "layout_changed", 1)


func test_large_estimated_extent_preserves_one_pixel_updates() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.estimated_item_extent = 1_000_000_000.0
	model.set_item_count(1)
	watch_signals(model)
	var previous_revision: int = model.get_revision()

	model.estimated_item_extent = 1_000_000_001.0

	assert_eq(model.estimated_item_extent, 1_000_000_001.0)
	assert_eq(model.get_item_extent(0), 1_000_000_001.0)
	assert_eq(model.get_revision(), previous_revision + 1)
	assert_signal_emit_count(model, "layout_changed", 1)


func test_non_finite_layout_inputs_cannot_poison_offsets() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.estimated_item_extent = 24.0
	model.trailing_padding = 8.0
	model.set_item_count(3)

	model.estimated_item_extent = INF
	model.trailing_padding = NAN
	var report: Dictionary = model.set_item_extent(1, INF)

	assert_eq(model.estimated_item_extent, 24.0, "非有限估算尺寸应被拒绝且不改变现有布局。")
	assert_eq(model.trailing_padding, 8.0, "非有限尾部留白应被拒绝。")
	assert_false(GFVariantData.get_option_bool(report, "ok"), "非有限实测尺寸应返回失败报告。")
	assert_eq(GFVariantData.get_option_string(report, "error"), "non_finite_extent")
	assert_true(is_finite(model.get_content_extent()), "累计内容尺寸必须保持有限。")
	var visible_range: Vector2i = model.get_visible_range(INF, NAN)
	assert_true(visible_range.x >= 0 and visible_range.y <= model.get_item_count(), "异常滚动输入不得产生越界范围。")


func test_viewport_range_excludes_overscan_while_visible_range_includes_it() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.estimated_item_extent = 50.0
	model.overscan_items = 2
	model.set_item_count(10)

	assert_eq(model.get_viewport_range(100.0, 100.0), Vector2i(2, 4), "原始视口范围不应包含 overscan。")
	assert_eq(model.get_visible_range(100.0, 100.0), Vector2i(0, 6), "可见范围应在原始视口两端加入 overscan。")


func test_layout_revision_changes_once_per_effective_public_mutation() -> void:
	var model: GFVirtualListModel = GFVirtualListModel.new()
	watch_signals(model)

	assert_eq(model.get_revision(), 0, "新模型 revision 应从 0 开始。")
	model.set_item_count(3)
	assert_eq(model.get_revision(), 1, "条目数量变化应推进一次 revision。")
	assert_signal_emit_count(model, "layout_changed", 1)
	assert_signal_emitted_with_parameters(model, "layout_changed", [1])

	model.set_item_count(3)
	model.overscan_items = GFVirtualListModel.DEFAULT_OVERSCAN_ITEMS
	var invalid_report: Dictionary = model.set_item_extent(0, INF)
	assert_false(GFVariantData.get_option_bool(invalid_report, "ok"), "无效尺寸应被拒绝。")
	assert_eq(model.get_revision(), 1, "无变化和无效写入不得推进 revision。")
	assert_signal_emit_count(model, "layout_changed", 1)

	model.estimated_item_extent = 72.0
	assert_eq(model.get_revision(), 2, "一次 estimate 更新无论影响多少条目都只推进一次 revision。")
	assert_signal_emit_count(model, "layout_changed", 2)
	assert_signal_emitted_with_parameters(model, "layout_changed", [2], 1)
