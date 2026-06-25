## 测试 GFTableDataView 的通用排序、过滤、提交和选择模型。
extends GutTest


func test_sort_and_filter_preserve_selection_by_row_id() -> void:
	var view: GFTableDataView = _make_people_view()
	var _select_result: bool = view.selection_model.set_selected("row-a", true)

	assert_true(view.sort_by_column(&"score", false), "可排序列应接受排序设置。")
	assert_eq(view.get_visible_row_ids(), ["row-b", "row-a", "row-c"], "分数降序应只改变可见顺序。")
	assert_true(view.selection_model.is_selected("row-a"), "排序后选择应由稳定 row_id 保留。")

	view.set_filter_query("ali")

	assert_eq(view.get_visible_row_ids(), ["row-a"], "过滤应只保留匹配行。")
	assert_true(view.selection_model.is_selected("row-a"), "过滤后选择仍应保留。")

	view.set_filter_query("")

	assert_eq(view.get_visible_row_ids(), ["row-b", "row-a", "row-c"], "清空过滤后应恢复排序视图。")
	assert_true(view.selection_model.is_selected("row-a"), "清空过滤后选择仍应保留。")


func test_commit_cell_value_updates_row_and_resorts_view() -> void:
	var view: GFTableDataView = _make_people_view()
	var _sort_result: bool = view.sort_by_column(&"score", false)

	assert_true(view.commit_cell_value(2, &"score", 25), "可编辑列应允许提交。")

	var row_data: Variant = view.get_row(2)
	assert_true(row_data is Dictionary, "测试行应保持 Dictionary 数据。")
	if row_data is Dictionary:
		var row_dictionary: Dictionary = row_data
		assert_eq(GFVariantData.get_option_int(row_dictionary, "score"), 25, "提交应写回源行。")
	var visible_row_ids: Array = view.get_visible_row_ids()
	var first_visible_row_id: String = GFVariantData.to_text(visible_row_ids[0]) if not visible_row_ids.is_empty() else ""
	assert_eq(first_visible_row_id, "row-c", "提交排序列后视图应重新排序。")


func test_commit_cell_values_reports_partial_failures_and_refreshes_once() -> void:
	var view: GFTableDataView = _make_people_view()
	watch_signals(view)

	var report: Dictionary = view.commit_cell_values([
		{ "row_index": 0, "column_id": &"score", "new_value": 12 },
		{ "row_index": 1, "column_id": &"score", "new_value": 18 },
		{ "row_index": 9, "column_id": &"score", "new_value": 1 },
		{ "row_index": 2, "column_id": &"name", "new_value": "C" },
	])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "部分失败时批量报告应标记为失败。")
	assert_eq(GFVariantData.get_option_int(report, "requested_count"), 4, "报告应记录请求数量。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 1, "只应计入实际改值的单元格。")
	assert_eq(GFVariantData.get_option_int(report, "unchanged_count"), 1, "相同值应计为未变化。")
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 2, "无效行和不可编辑列应计为失败。")
	assert_eq(_get_row_score(view, 0), 12, "有效变更应写回源行。")
	assert_signal_emit_count(view, "view_changed", 1)
	assert_signal_emit_count(view, "cell_value_committed", 1)


func test_commit_visible_cell_values_resolves_indices_before_refresh() -> void:
	var view: GFTableDataView = _make_people_view()
	var _sort_result: bool = view.sort_by_column(&"score", false)

	var report: Dictionary = view.commit_visible_cell_values([
		{ "visible_row_index": 0, "column_id": &"score", "new_value": 1 },
		{ "visible_row_index": 1, "column_id": &"score", "new_value": 30 },
	])

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效可见行批量提交应成功。")
	assert_eq(GFVariantData.get_option_int(report, "applied_count"), 2, "两个可见行变更都应应用。")
	assert_eq(_get_row_score(view, 0), 30, "第二个可见行应仍指向提交前的 row-a。")
	assert_eq(_get_row_score(view, 1), 1, "第一个可见行应仍指向提交前的 row-b。")
	assert_eq(view.get_visible_row_ids(), ["row-a", "row-c", "row-b"], "批量提交后应按最终值重排。")


func test_selection_model_range_and_prune_use_stable_ids() -> void:
	var selection: GFTableSelectionModel = GFTableSelectionModel.new()
	var ordered_ids: Array = ["row-a", "row-b", "row-c", "row-d"]

	assert_true(selection.select_range(ordered_ids, "row-b", "row-d"), "范围选择应选中闭区间。")
	assert_eq(selection.get_selected_ids(), ["row-b", "row-c", "row-d"])

	assert_true(selection.prune_to_row_ids(["row-a", "row-c", "row-d"]), "剪枝应移除不存在的选择。")
	assert_eq(selection.get_selected_ids(), ["row-c", "row-d"])

	selection.selection_mode = GFTableSelectionModel.SelectionMode.SINGLE

	assert_eq(selection.get_selected_ids(), ["row-c"], "切到单选模式时应保留第一个选中项。")

	selection.selection_mode = GFTableSelectionModel.SelectionMode.NONE

	assert_false(selection.select_single("row-a"), "禁用选择模式下不应允许直接单选。")
	assert_true(selection.is_empty(), "切到禁用选择模式时应清空选择。")


func test_custom_column_formatter_participates_in_filtering() -> void:
	var view: GFTableDataView = _make_people_view()
	var score_column: GFTableColumnDefinition = view.get_column(&"score")
	score_column.value_formatter = Callable(self, &"_format_score")

	view.set_filter_query("score:10")

	assert_eq(view.get_visible_row_ids(), ["row-a"], "自定义 formatter 应参与过滤文本。")


func _make_people_view() -> GFTableDataView:
	var view: GFTableDataView = GFTableDataView.new()
	var id_column: GFTableColumnDefinition = _make_column(&"id")
	var name_column: GFTableColumnDefinition = _make_column(&"name")
	var score_column: GFTableColumnDefinition = _make_column(&"score")
	score_column.editable = true
	score_column.sort_mode = GFTableColumnDefinition.SortMode.NUMBER
	var columns: Array[GFTableColumnDefinition] = [id_column, name_column, score_column]
	view.set_columns(columns)
	view.set_rows([
		{ "id": "row-a", "name": "Alice", "score": 10 },
		{ "id": "row-b", "name": "Bob", "score": 18 },
		{ "id": "row-c", "name": "Cara", "score": 7 },
	])
	return view


func _make_column(column_id: StringName) -> GFTableColumnDefinition:
	var column: GFTableColumnDefinition = GFTableColumnDefinition.new()
	var _configure_result: GFTableColumnDefinition = column.configure(column_id)
	return column


func _get_row_score(view: GFTableDataView, row_index: int) -> int:
	var row_data: Variant = view.get_row(row_index)
	assert_true(row_data is Dictionary, "测试行应保持 Dictionary 数据。")
	if row_data is Dictionary:
		var row_dictionary: Dictionary = row_data
		return GFVariantData.get_option_int(row_dictionary, "score")
	return -1


func _format_score(value: Variant, _row_data: Variant, _column: GFTableColumnDefinition) -> String:
	return "score:%d" % GFVariantData.to_int(value)
