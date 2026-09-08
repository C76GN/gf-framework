@tool
extends GutTest


# --- 常量 ---

const _DOCK_SCRIPT = preload(
	"res://addons/gf/tools/scene_groups/editor/gf_scene_group_dock.gd"
)
const _CATALOG_SCRIPT = preload(
	"res://addons/gf/kernel/editor/gf_editor_contribution_catalog.gd"
)
const _FIXTURE_PARENT: String = "res://tests/gf_core/tools/scene_groups"


# --- 私有变量 ---

var _docks: Array[GFSceneGroupDock] = []
var _fixture_files: Array[String] = []
var _fixture_roots: Array[String] = []
var _fixture_sequence: int = 0


# --- 公共方法 ---

func after_each() -> void:
	for dock: GFSceneGroupDock in _docks:
		if is_instance_valid(dock):
			dock.free()
	_docks.clear()
	for file_path: String in _fixture_files:
		if FileAccess.file_exists(file_path):
			assert_eq(DirAccess.remove_absolute(file_path), OK)
	_fixture_files.clear()
	for root_path: String in _fixture_roots:
		if DirAccess.dir_exists_absolute(root_path):
			assert_eq(DirAccess.remove_absolute(root_path), OK)
	_fixture_roots.clear()


func test_scene_group_dock_starts_idle_and_waits_for_explicit_refresh() -> void:
	var dock: GFSceneGroupDock = _make_dock()
	var root_edit: LineEdit = dock.find_child("ScanRoot", true, false) as LineEdit
	var results: Tree = _get_results(dock)

	assert_not_null(root_edit)
	if root_edit != null:
		assert_eq(root_edit.text, "res://")
	assert_eq(_status(dock), "idle")
	assert_eq(_visible_row_count(results), 0)
	assert_false(_get_button(dock, "Refresh").disabled)
	assert_true(_get_button(dock, "Cancel").disabled)
	assert_false(dock.is_processing())

	await get_tree().process_frame

	assert_eq(_status(dock), "idle", "进入场景树不得触发项目扫描。")
	assert_eq(GFVariantData.get_option_int(dock.get_snapshot(), "entry_count"), 0)


func test_search_matches_each_column_without_case_and_resets_pagination() -> void:
	var root_path: String = _make_fixture_root()
	_write_group_scene(root_path, 125)
	var dock: GFSceneGroupDock = _make_dock()
	var root_edit: LineEdit = dock.find_child("ScanRoot", true, false) as LineEdit
	assert_not_null(root_edit)
	if root_edit == null:
		return
	root_edit.text = root_path
	_get_button(dock, "Refresh").pressed.emit()
	await _wait_for_scan(dock)

	var results: Tree = _get_results(dock)
	assert_eq(_status(dock), "complete")
	assert_eq(results.columns, 3)
	assert_eq(_visible_row_count(results), 100)
	assert_true(_get_button(dock, "PreviousPage").disabled)
	assert_false(_get_button(dock, "NextPage").disabled)
	_get_button(dock, "NextPage").pressed.emit()
	assert_eq(_visible_row_count(results), 25)
	assert_false(_get_button(dock, "PreviousPage").disabled)
	assert_true(_get_button(dock, "NextPage").disabled)
	_get_button(dock, "PreviousPage").pressed.emit()
	assert_eq(_visible_row_count(results), 100)
	_get_button(dock, "NextPage").pressed.emit()
	assert_eq(_visible_row_count(results), 25)

	_set_search(dock, "gRoUp_12")
	assert_eq(_visible_row_count(results), 5)
	assert_true(_get_button(dock, "PreviousPage").disabled)
	assert_true(_get_button(dock, "NextPage").disabled)
	var first: TreeItem = results.get_root().get_first_child()
	assert_eq(first.get_text(0), "group_120")

	_set_search(dock, "cAtAlOg.TsCn")
	assert_eq(_visible_row_count(results), 100, "场景路径也应可搜索。")
	_get_button(dock, "NextPage").pressed.emit()
	assert_eq(_visible_row_count(results), 25)
	_set_search(dock, "mArKeRnOdE")
	assert_eq(_visible_row_count(results), 100, "节点路径搜索必须回到第一页。")
	assert_true(_get_button(dock, "PreviousPage").disabled)
	assert_eq(GFVariantData.get_option_int(dock.get_snapshot(), "row_count"), 125)

	_set_search(dock, "no_matching_declaration")
	assert_eq(_visible_row_count(results), 0)
	assert_eq(_status(dock), "complete", "筛选无结果不应伪造扫描失败。")
	assert_true(_get_button(dock, "PreviousPage").disabled)
	assert_true(_get_button(dock, "NextPage").disabled)


func test_busy_refresh_preserves_active_scan_and_visible_page_until_cancel_or_completion() -> void:
	var root_a: String = _make_fixture_root()
	var root_b: String = _make_fixture_root()
	_write_group_scene(root_a, 500)
	_write_group_scene(root_b, 1)
	var dock: GFSceneGroupDock = _make_dock()
	_set_search(dock, "group_")
	assert_eq(dock.refresh(root_a), OK)
	for _frame: int in range(120):
		if GFVariantData.get_option_int(dock.get_snapshot(), "row_count") > 0:
			break
		await get_tree().process_frame
	assert_eq(_status(dock), "scanning")
	assert_gt(GFVariantData.get_option_int(dock.get_snapshot(), "row_count"), 0)
	var root_edit: LineEdit = dock.find_child("ScanRoot", true, false) as LineEdit
	var search: LineEdit = dock.find_child("Search", true, false) as LineEdit
	var summary: Label = dock.find_child("Summary", true, false) as Label
	var page_summary: Label = dock.find_child("PageSummary", true, false) as Label
	assert_not_null(root_edit)
	assert_not_null(search)
	assert_not_null(summary)
	assert_not_null(page_summary)
	if root_edit == null or search == null or summary == null or page_summary == null:
		return
	var results: Tree = _get_results(dock)
	var snapshot: Dictionary = dock.get_snapshot()
	var summary_before: String = summary.text
	var page_summary_before: String = page_summary.text
	var visible_rows_before: int = _visible_row_count(results)

	assert_eq(dock.refresh(root_b), ERR_BUSY)

	assert_eq(dock.get_snapshot(), snapshot, "忙时拒绝刷新必须保留正在推进的扫描。")
	assert_eq(root_edit.text, root_a, "被拒绝的扫描根不得覆盖当前页面目录。")
	assert_eq(search.text, "group_")
	assert_eq(summary.text, summary_before, "被拒绝的请求不得重绘当前摘要。")
	assert_eq(page_summary.text, page_summary_before)
	assert_eq(_visible_row_count(results), visible_rows_before, "忙时拒绝不得重建结果页。")
	assert_true(dock.is_processing())
	assert_true(_get_button(dock, "Refresh").disabled)
	assert_false(_get_button(dock, "Cancel").disabled)
	await _wait_for_scan(dock)
	assert_eq(_status(dock), "complete")
	assert_eq(GFVariantData.get_option_string(dock.get_snapshot(), "root_path"), root_a)
	assert_eq(GFVariantData.get_option_int(dock.get_snapshot(), "row_count"), 500)
	assert_eq(root_edit.text, root_a)

	assert_eq(dock.refresh(root_b), OK, "当前扫描完成后可以接受另一个目录。")
	await _wait_for_scan(dock)
	assert_eq(_status(dock), "complete")
	assert_eq(root_edit.text, root_b)
	assert_eq(GFVariantData.get_option_int(dock.get_snapshot(), "row_count"), 1)
	assert_eq(dock.refresh(root_a), OK)
	dock.cancel_scan()
	assert_eq(_status(dock), "cancelled")
	assert_eq(dock.refresh(root_b), OK, "显式取消后也可以接受另一个目录。")
	await _wait_for_scan(dock)
	assert_eq(_status(dock), "complete")
	assert_eq(GFVariantData.get_option_string(dock.get_snapshot(), "root_path"), root_b)
	assert_eq(GFVariantData.get_option_int(dock.get_snapshot(), "row_count"), 1)


func test_cancel_button_stops_scan_and_next_refresh_can_complete() -> void:
	var root_path: String = _make_fixture_root()
	_write_group_scene(root_path, 125)
	var dock: GFSceneGroupDock = _make_dock()
	assert_eq(dock.refresh(root_path), OK)
	assert_eq(_status(dock), "scanning")
	assert_false(_get_button(dock, "Cancel").disabled)

	_get_button(dock, "Cancel").pressed.emit()

	assert_eq(_status(dock), "cancelled")
	assert_false(dock.is_processing())
	assert_true(_get_button(dock, "Cancel").disabled)
	var cancelled: Dictionary = dock.get_snapshot()
	await get_tree().process_frame
	assert_eq(dock.get_snapshot(), cancelled, "取消后不得在后续帧继续积累扫描结果。")

	var empty_root: String = _make_fixture_root()
	assert_eq(dock.refresh(empty_root), OK)
	await _wait_for_scan(dock)
	assert_eq(_status(dock), "complete")
	assert_eq(GFVariantData.get_option_int(dock.get_snapshot(), "row_count"), 0)
	assert_eq(_visible_row_count(_get_results(dock)), 0)


func test_leaving_tree_cancels_scan_and_reentry_does_not_restart_it() -> void:
	var root_path: String = _make_fixture_root()
	_write_group_scene(root_path, 125)
	var dock: GFSceneGroupDock = _make_dock()
	assert_eq(dock.refresh(root_path), OK)

	remove_child(dock)

	assert_eq(_status(dock), "cancelled")
	assert_false(dock.is_processing())
	var cancelled: Dictionary = dock.get_snapshot()
	add_child(dock)
	await get_tree().process_frame
	assert_eq(dock.get_snapshot(), cancelled, "重新进入场景树仍需显式刷新。")
	assert_false(dock.is_processing())


func test_complete_empty_scan_and_partial_scan_have_distinct_visible_states() -> void:
	var empty_root: String = _make_fixture_root()
	var dock: GFSceneGroupDock = _make_dock()
	assert_eq(dock.refresh(empty_root), OK)
	await _wait_for_scan(dock)
	var summary: Label = dock.find_child("Summary", true, false) as Label
	var issues: TextEdit = dock.find_child("Issues", true, false) as TextEdit
	assert_not_null(summary)
	assert_not_null(issues)
	if summary == null or issues == null:
		return
	assert_eq(_status(dock), "complete")
	assert_eq(_visible_row_count(_get_results(dock)), 0)
	assert_true(GFVariantData.get_option_array(dock.get_snapshot(), "issues").is_empty())
	var complete_summary: String = summary.text

	var ignored_root: String = _make_fixture_root()
	_write_fixture_file(ignored_root.path_join(".gdignore"), "")
	var _refresh_error: Error = dock.refresh(ignored_root)
	await _wait_for_scan(dock)

	assert_eq(_status(dock), "partial")
	assert_eq(_visible_row_count(_get_results(dock)), 0)
	assert_false(GFVariantData.get_option_array(dock.get_snapshot(), "issues").is_empty())
	assert_ne(summary.text, complete_summary, "被排除的扫描根不能显示成完整的空结果。")
	assert_false(issues.text.is_empty(), "不完整扫描应在界面展示原因。")
	assert_false(dock.is_processing())
	assert_true(_get_button(dock, "Cancel").disabled)


func test_result_activation_outside_editor_reports_failure_without_losing_selection() -> void:
	if Engine.is_editor_hint():
		pending("此用例验证普通 GUT 运行环境中的编辑器导航边界。")
		return
	var root_path: String = _make_fixture_root()
	_write_group_scene(root_path, 1)
	var dock: GFSceneGroupDock = _make_dock()
	assert_eq(dock.refresh(root_path), OK)
	await _wait_for_scan(dock)
	var results: Tree = _get_results(dock)
	var item: TreeItem = results.get_root().get_first_child()
	assert_not_null(item)
	if item == null:
		return
	item.select(0)
	var snapshot: Dictionary = dock.get_snapshot()
	var location_status: Label = dock.find_child("LocationStatus", true, false) as Label
	assert_not_null(location_status)
	if location_status == null:
		return
	var previous_status: String = location_status.text

	results.item_activated.emit()
	await get_tree().process_frame

	assert_false(location_status.text.is_empty(), "定位不可用时应提供可见反馈。")
	assert_ne(location_status.text, previous_status, "结果激活应实际更新导航反馈。")
	assert_same(results.get_selected(), item, "失败定位不能清空或改写结果选择。")
	assert_eq(dock.get_snapshot(), snapshot)


func test_pagination_clears_feedback_from_the_previous_result_location() -> void:
	if Engine.is_editor_hint():
		pending("普通 GUT 验证公开控件反馈；待完成定位由真实编辑器 smoke 验证。")
		return
	var root_path: String = _make_fixture_root()
	_write_group_scene(root_path, 125)
	var dock: GFSceneGroupDock = _make_dock()
	assert_eq(dock.refresh(root_path), OK)
	await _wait_for_scan(dock)
	var results: Tree = _get_results(dock)
	var location_status: Label = dock.find_child("LocationStatus", true, false) as Label
	assert_not_null(location_status)
	if location_status == null:
		return
	var snapshot: Dictionary = dock.get_snapshot()
	for button_name: String in ["NextPage", "PreviousPage"]:
		var item: TreeItem = results.get_root().get_first_child()
		assert_not_null(item)
		if item == null:
			return
		item.select(0)
		results.item_activated.emit()
		assert_false(location_status.text.is_empty(), "激活结果应先产生可见定位反馈。")
		var page_button: Button = _get_button(dock, button_name)
		assert_false(page_button.disabled)
		page_button.pressed.emit()
		assert_true(location_status.text.is_empty(), "翻页应清除上一条结果的定位反馈。")
		assert_eq(_visible_row_count(results), 25 if button_name == "NextPage" else 100)
		await get_tree().process_frame
		assert_true(location_status.text.is_empty(), "已取消的定位反馈不得在后续帧恢复。")
		assert_false(dock.is_processing())
		assert_eq(dock.get_snapshot(), snapshot, "翻页不得重扫或改变已保存声明摘要。")


func test_scene_group_dock_is_registered_once_through_optional_editor_catalog() -> void:
	var report: Dictionary = _CATALOG_SCRIPT.load_catalog_report(
		"res://addons/gf/gf_builtin_tool_contributions.json"
	)
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	var records: Dictionary = GFVariantData.get_option_dictionary(report, "records")
	var owned_records: Array[Dictionary] = []
	for record_value: Variant in GFVariantData.get_option_array(records, "dock_records"):
		if record_value is Dictionary:
			var record: Dictionary = record_value
			if GFVariantData.get_option_string(record, "owner_package_id") == "gf.tool.scene_groups":
				owned_records.append(record)
	assert_eq(owned_records.size(), 1)
	if owned_records.size() != 1:
		return
	assert_eq(
		GFVariantData.get_option_string(owned_records[0], "source_id"),
		"gf.tool.scene_groups:scene_groups.dock.scene_groups"
	)
	assert_eq(
		GFVariantData.get_option_string(owned_records[0], "path"),
		"res://addons/gf/tools/scene_groups/editor/gf_scene_group_dock.gd"
	)


# --- 私有/辅助方法 ---

func _make_dock() -> GFSceneGroupDock:
	var dock: GFSceneGroupDock = _DOCK_SCRIPT.new()
	_docks.append(dock)
	add_child(dock)
	return dock


func _status(dock: GFSceneGroupDock) -> String:
	return GFVariantData.get_option_string(dock.get_snapshot(), "status")


func _get_results(dock: GFSceneGroupDock) -> Tree:
	var results: Tree = dock.find_child("Results", true, false) as Tree
	assert_not_null(results)
	return results


func _get_button(dock: GFSceneGroupDock, control_name: String) -> Button:
	var button: Button = dock.find_child(control_name, true, false) as Button
	assert_not_null(button)
	return button


func _visible_row_count(results: Tree) -> int:
	if results == null or results.get_root() == null:
		return 0
	return results.get_root().get_child_count()


func _set_search(dock: GFSceneGroupDock, text: String) -> void:
	var search: LineEdit = dock.find_child("Search", true, false) as LineEdit
	assert_not_null(search)
	if search != null:
		search.text = text
		search.text_changed.emit(text)


func _wait_for_scan(dock: GFSceneGroupDock) -> void:
	for _frame: int in range(120):
		if _status(dock) != "scanning":
			return
		await get_tree().process_frame
	assert_ne(_status(dock), "scanning", "小型夹具扫描必须在有界帧数内完成。")


func _make_fixture_root() -> String:
	_fixture_sequence += 1
	var root_path: String = _FIXTURE_PARENT.path_join(
		"_generated_dock_%d_%d_%d" % [get_instance_id(), Time.get_ticks_usec(), _fixture_sequence]
	)
	assert_eq(DirAccess.make_dir_recursive_absolute(root_path), OK)
	_fixture_roots.append(root_path)
	return root_path


func _write_group_scene(root_path: String, group_count: int) -> void:
	var groups: PackedStringArray = PackedStringArray()
	for index: int in range(group_count):
		var _added: bool = groups.append('"group_%03d"' % index)
	var text: String = (
		'[gd_scene format=3]\n\n[node name="Root" type="Node"]\n\n'
		+ '[node name="MarkerNode" type="Node" parent="." groups=[%s]]\n' % ", ".join(groups)
	)
	_write_fixture_file(root_path.path_join("catalog.tscn"), text)


func _write_fixture_file(file_path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null:
		return
	_fixture_files.append(file_path)
	assert_true(file.store_string(text), "测试夹具必须完整写入。")
	file.close()
