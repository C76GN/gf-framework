@tool

# 测试统一编辑器工作区对贡献页面的上下文传递与撤销。
extends GutTest


# --- 常量 ---

const _WORKSPACE_DOCK_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_workspace_dock.gd")
const _WORKSPACE_WINDOW_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_workspace_window.gd")
const _CONTEXT_PAGE_SCRIPT = preload("res://tests/gf_core/kernel/editor/fixtures/gf_workspace_context_page.gd")
const _PASSIVE_PAGE_SCRIPT = preload("res://tests/gf_core/kernel/editor/fixtures/gf_workspace_passive_page.gd")


# --- 私有变量 ---

var _roots: Array[Node] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	_CONTEXT_PAGE_SCRIPT.next_context_callback = Callable()
	_CONTEXT_PAGE_SCRIPT.next_enter_callback = Callable()
	_CONTEXT_PAGE_SCRIPT.next_exit_callback = Callable()
	for root: Node in _roots:
		if is_instance_valid(root):
			root.free()
	_roots.clear()
	await get_tree().process_frame


# --- 测试用例 ---

func test_dock_injects_context_before_workspace_enters_tree() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var context: GFEditorToolContext = GFEditorToolContext.new()
	dock.setup(_context_records(), context)
	var page: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock)
	if page == null:
		return

	assert_same(page.current_context, context, "尚未入树的页面应收到调用方提供的上下文对象。")
	assert_false(page.first_context_was_in_tree, "首次上下文注入必须发生在页面入树之前。")
	assert_eq(page.enter_count, 0, "setup 不应提前把未挂载的工作区页面加入场景树。")
	add_child(dock)
	assert_eq(page.enter_count, 1, "挂载工作区后页面应正常进入场景树。")
	assert_same(page.context_at_first_enter, context, "页面的 _enter_tree 应能使用已注入的上下文。")


func test_dock_injects_context_before_page_enters_running_workspace() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	add_child(dock)
	var context: GFEditorToolContext = GFEditorToolContext.new()
	dock.setup(_context_records(), context)
	var page: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock)
	if page == null:
		return

	assert_true(page.is_inside_tree(), "已挂载工作区应立即挂载新贡献页面。")
	assert_false(page.first_context_was_in_tree, "工作区已入树时仍须先注入上下文再挂载页面。")
	assert_same(page.context_at_first_enter, context, "新页面首次入树应观察到本次 setup 的上下文。")


func test_dock_updates_and_revokes_context_for_all_existing_pages() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var records: Array[Dictionary] = _context_records("First")
	records.append(_context_record("Second"))
	var original_context: GFEditorToolContext = GFEditorToolContext.new()
	dock.setup(records, original_context)
	add_child(dock)
	assert_true(dock.select_page("Second"), "先访问第二页，使上下文更新覆盖所有已创建页面。")
	var first: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock, "First")
	var second: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock, "Second")
	if first == null or second == null:
		return
	var replacement_context: GFEditorToolContext = GFEditorToolContext.new()
	dock.set_editor_context(replacement_context)

	assert_same(_get_context_page(dock, "First"), first, "替换上下文应复用现有贡献页面。")
	assert_same(_get_context_page(dock, "Second"), second, "上下文更新不应重建未选中的页面。")
	assert_same(first.current_context, replacement_context, "首个页面应收到替换后的上下文。")
	assert_same(second.current_context, replacement_context, "其余页面也应收到替换后的上下文。")
	dock.set_editor_context(null)
	assert_null(first.current_context, "显式撤销应清除首个页面的编辑环境。")
	assert_null(second.current_context, "显式撤销应清除所有页面的编辑环境。")
	assert_eq(first.enter_count, 1, "仅更新上下文不应让页面重复入树。")
	assert_eq(second.enter_count, 1, "未选中的页面也不应因上下文更新重复入树。")


func test_dock_creates_only_selected_page_and_reuses_visited_pages() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var records: Array[Dictionary] = _context_records("First")
	records.append(_context_record("Second"))
	records.append(_context_record("Third"))
	dock.setup(records, GFEditorToolContext.new())
	add_child(dock)
	await get_tree().process_frame

	assert_eq(dock.get_page_titles(), PackedStringArray(["First", "Second", "Third"]))
	assert_null(dock.find_child("Second Content", true, false), "打开工作区不应创建未访问页面。")
	assert_null(dock.find_child("Third Content", true, false), "延迟回调也不应提前创建隐藏页面。")
	var first: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock, "First")
	assert_true(dock.select_page("Second"))
	var second: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock, "Second")
	assert_true(dock.select_page("First"))
	assert_true(dock.select_page("Second"))
	assert_same(_get_context_page(dock, "First"), first, "往返切页必须保留首个页面状态。")
	assert_same(_get_context_page(dock, "Second"), second, "已访问的页面只应创建一次。")
	assert_eq(second.enter_count, 1)
	assert_null(dock.find_child("Third Content", true, false))


func test_unvisited_page_receives_latest_context_before_first_enter() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var records: Array[Dictionary] = _context_records("First")
	records.append(_context_record("Second"))
	dock.setup(records, GFEditorToolContext.new())
	add_child(dock)
	var latest_context: GFEditorToolContext = GFEditorToolContext.new()
	dock.set_editor_context(latest_context)
	assert_null(dock.find_child("Second Content", true, false), "替换上下文不应触发隐藏页面初始化。")
	assert_true(dock.select_page("Second"))
	var second: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock, "Second")
	assert_same(second.context_at_first_enter, latest_context)
	assert_eq(second.context_update_count, 1, "首次创建只接收当前有效上下文。")
	assert_false(second.first_context_was_in_tree)


func test_off_tree_selection_creates_requested_page_before_mount() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var records: Array[Dictionary] = _context_records("First")
	records.append(_context_record("Second"))
	dock.setup(records, GFEditorToolContext.new())
	assert_null(dock.find_child("Second Content", true, false))
	assert_true(dock.select_page("Second"))
	var second: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock, "Second")
	assert_eq(second.enter_count, 0, "离树状态下选页仍应创建目标，但不能提前入树。")
	add_child(dock)
	assert_eq(second.enter_count, 1)
	assert_same(_get_context_page(dock, "Second"), second)


func test_unlabeled_legacy_page_keeps_constructor_title_before_selection() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var records: Array[Dictionary] = _context_records("First")
	records.append(_context_record(""))
	dock.setup(records, GFEditorToolContext.new())
	assert_eq(dock.get_page_titles(), PackedStringArray(["First", "Legacy Context"]))
	assert_eq(dock.get_page_button_titles(), PackedStringArray(["First", "Legacy Context"]))
	assert_true(dock.select_page("Legacy Context"), "没有显式标签的旧贡献仍须支持按构造器名称选页。")
	var legacy: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock, "Legacy Context")
	if legacy == null:
		return
	assert_eq(legacy.context_update_count, 1)
	assert_eq(legacy.enter_count, 0)
	add_child(dock)
	assert_eq(legacy.enter_count, 1)
	assert_same(_get_context_page(dock, "Legacy Context"), legacy)


func test_context_callback_reconfiguration_discards_unmounted_page() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var records: Array[Dictionary] = _context_records("First")
	records.append(_context_record("Second"))
	dock.setup(records, GFEditorToolContext.new())
	add_child(dock)
	var latest_context: GFEditorToolContext = GFEditorToolContext.new()
	var discarded: Array[Control] = []
	_CONTEXT_PAGE_SCRIPT.next_context_callback = func(page: _CONTEXT_PAGE_SCRIPT) -> void:
		discarded.append(page)
		_roots.append(page)
		dock.setup(_context_records("Latest"), latest_context)
	assert_true(dock.select_page("Second"))
	assert_eq(dock.get_page_titles(), PackedStringArray(["Latest"]))
	assert_eq(discarded.size(), 1)
	var latest: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock, "Latest")
	assert_same(latest.context_at_first_enter, latest_context)
	assert_null(discarded[0].get_parent(), "重入替换期间撤销的页面不能挂回旧占位容器。")
	assert_true(discarded[0].is_queued_for_deletion(), "尚未挂载的过期页面也必须被释放。")


func test_revocation_callback_coalesces_reconfiguration_before_rebuild() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	dock.setup(_context_records(), GFEditorToolContext.new())
	add_child(dock)
	var old_page: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock)
	var latest_context: GFEditorToolContext = GFEditorToolContext.new()
	_CONTEXT_PAGE_SCRIPT.next_context_callback = func(page: _CONTEXT_PAGE_SCRIPT) -> void:
		assert_null(page.current_context)
		dock.setup(_context_records("Latest"), latest_context)
	dock.setup(_context_records("Superseded"), GFEditorToolContext.new())
	assert_eq(dock.get_page_titles(), PackedStringArray(["Latest"]), "撤销回调发起的新配置只能生成一组页面。")
	assert_null(old_page.context_at_last_exit)
	assert_same(_get_context_page(dock, "Latest").context_at_first_enter, latest_context)


func test_exit_callback_reconfiguration_waits_until_old_page_is_detached() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	dock.setup(_context_records(), GFEditorToolContext.new())
	add_child(dock)
	var latest_context: GFEditorToolContext = GFEditorToolContext.new()
	_CONTEXT_PAGE_SCRIPT.next_exit_callback = func(page: _CONTEXT_PAGE_SCRIPT) -> void:
		assert_null(page.current_context)
		dock.setup(_context_records("Latest"), latest_context)
	dock.setup(_context_records("Superseded"), GFEditorToolContext.new())
	assert_eq(dock.get_page_titles(), PackedStringArray(["Latest"]))
	assert_same(_get_context_page(dock, "Latest").context_at_first_enter, latest_context)


func test_enter_callback_reconfiguration_waits_until_page_attachment_finishes() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var records: Array[Dictionary] = _context_records("First")
	records.append(_context_record("Second"))
	dock.setup(records, GFEditorToolContext.new())
	add_child(dock)
	var latest_context: GFEditorToolContext = GFEditorToolContext.new()
	var discarded: Array[_CONTEXT_PAGE_SCRIPT] = []
	_CONTEXT_PAGE_SCRIPT.next_enter_callback = func(page: _CONTEXT_PAGE_SCRIPT) -> void:
		discarded.append(page)
		dock.setup(_context_records("Latest"), latest_context)
	assert_true(dock.select_page("Second"))
	assert_eq(dock.get_page_titles(), PackedStringArray(["Latest"]))
	assert_eq(discarded.size(), 1)
	assert_false(discarded[0].is_inside_tree())
	assert_null(discarded[0].context_at_last_exit, "过期页面仍须先撤销上下文，再离树。")
	assert_same(_get_context_page(dock, "Latest").context_at_first_enter, latest_context)


func test_nested_context_update_does_not_overwrite_latest_context_on_later_pages() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var records: Array[Dictionary] = _context_records("First")
	records.append(_context_record("Second"))
	dock.setup(records, GFEditorToolContext.new())
	add_child(dock)
	assert_true(dock.select_page("Second"))
	var latest_context: GFEditorToolContext = GFEditorToolContext.new()
	_CONTEXT_PAGE_SCRIPT.next_context_callback = func(_page: _CONTEXT_PAGE_SCRIPT) -> void:
		dock.set_editor_context(latest_context)
	dock.set_editor_context(GFEditorToolContext.new())
	assert_same(_get_context_page(dock, "First").current_context, latest_context)
	assert_same(_get_context_page(dock, "Second").current_context, latest_context)


func test_failed_page_does_not_preload_or_block_other_pages() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var records: Array[Dictionary] = _context_records("First")
	records.append({
		"path": "res://addons/gf/kernel/editor/gf_editor_tool_context.gd",
		"label": "Invalid",
	})
	records.append(_context_record("Third"))
	dock.setup(records, GFEditorToolContext.new())
	add_child(dock)
	assert_true(dock.select_page("Invalid"))
	assert_push_error("[GFEditorWorkspaceDock][editor_workspace_dock.panel_instantiation_failed] Could not instantiate the workspace panel: res://addons/gf/kernel/editor/gf_editor_tool_context.gd.")
	assert_true(dock.select_page("Third"), "无效页面不应阻止其余页面创建。")
	assert_not_null(_get_context_page(dock, "Third"))
	assert_true(dock.select_page("Invalid"), "再次选择失败页面应显示已有错误提示，避免重复初始化及报错。")
	assert_eq(dock.get_page_count(), 3)


func test_window_reopening_preserves_selected_page_and_unvisited_pages() -> void:
	var workspace_window: _WORKSPACE_WINDOW_SCRIPT = _new_window()
	var records: Array[Dictionary] = _context_records("First")
	records.append(_context_record("Second"))
	records.append(_context_record("Third"))
	workspace_window.setup(records, GFEditorToolContext.new())
	add_child(workspace_window)
	var dock: _WORKSPACE_DOCK_SCRIPT = workspace_window.get_workspace()
	assert_true(dock.select_page("Second"))
	var second: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock, "Second")
	workspace_window.popup_workspace()
	workspace_window.close_requested.emit()
	assert_false(workspace_window.visible)
	workspace_window.popup_workspace()
	assert_same(_get_context_page(dock, "Second"), second)
	assert_true(second.is_visible_in_tree(), "再次打开应保留当前页面。")
	assert_eq(second.enter_count, 1)
	assert_null(dock.find_child("Third Content", true, false))
	workspace_window.hide()


func test_dock_replacement_revokes_old_page_before_detaching_it() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var original_context: GFEditorToolContext = GFEditorToolContext.new()
	dock.setup(_context_records(), original_context)
	add_child(dock)
	var old_page: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock)
	if old_page == null:
		return
	var replacement_context: GFEditorToolContext = GFEditorToolContext.new()
	dock.setup(_context_records(), replacement_context)
	var new_page: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock)
	if new_page == null:
		return

	assert_ne(new_page.get_instance_id(), old_page.get_instance_id(), "重设页面记录应创建新的贡献页面。")
	assert_false(old_page.is_inside_tree(), "旧页面应立即从工作区场景树移除。")
	assert_null(old_page.current_context, "旧页面等待释放期间不得继续持有编辑上下文。")
	assert_null(old_page.context_at_last_exit, "旧页面离树前应已收到上下文撤销。")
	assert_same(new_page.context_at_first_enter, replacement_context, "替换页面应在入树前获得新的上下文。")


func test_dock_leaving_tree_revokes_context_from_retained_pages() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	dock.setup(_context_records(), GFEditorToolContext.new())
	add_child(dock)
	var page: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock)
	if page == null:
		return

	remove_child(dock)
	assert_true(is_instance_valid(page), "从树中移除工作区不应先销毁贡献页面。")
	assert_false(page.is_inside_tree(), "工作区移除后页面也应离树。")
	assert_null(page.current_context, "工作区离树后保留的页面应失去编辑上下文。")


func test_dock_legacy_setup_uses_null_context() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	dock.setup(_context_records())
	add_child(dock)
	var page: _CONTEXT_PAGE_SCRIPT = _get_context_page(dock)
	if page == null:
		return

	assert_null(page.current_context, "旧式单参数 setup 应继续支持无编辑器上下文的页面。")
	assert_null(page.context_at_first_enter, "未传入上下文时不应凭空构造编辑环境。")
	assert_eq(page.context_update_count, 1, "实现上下文接口的页面应明确收到一次初始 null。")


func test_dock_keeps_pages_without_context_hook_compatible() -> void:
	var dock: _WORKSPACE_DOCK_SCRIPT = _new_dock()
	var records: Array[Dictionary] = [{
		"path": "res://tests/gf_core/kernel/editor/fixtures/gf_workspace_passive_page.gd",
		"label": "Passive",
	}]
	dock.setup(records, GFEditorToolContext.new())
	add_child(dock)
	var page: _PASSIVE_PAGE_SCRIPT = _get_passive_page(dock)
	if page == null:
		return

	dock.set_editor_context(GFEditorToolContext.new())
	dock.set_editor_context(null)
	assert_false(page.has_method("set_editor_context"), "兼容夹具应确实没有上下文协作接口。")
	assert_same(_get_passive_page(dock), page, "没有上下文接口的页面应保持原有实例。")
	assert_eq(page.enter_count, 1, "没有上下文接口的页面应照常且仅入树一次。")
	assert_eq(page.marker, "unchanged", "上下文转发不应改写没有协作接口的页面状态。")


func test_window_injects_context_before_contributed_page_enters_tree() -> void:
	var workspace_window: _WORKSPACE_WINDOW_SCRIPT = _new_window()
	var context: GFEditorToolContext = GFEditorToolContext.new()
	workspace_window.setup(_context_records(), context)
	var page: _CONTEXT_PAGE_SCRIPT = _get_context_page(workspace_window)
	if page == null:
		return

	assert_same(page.current_context, context, "独立窗口应通过内部工作区转发 setup 上下文。")
	assert_false(page.first_context_was_in_tree, "独立窗口也必须在贡献页面入树前注入上下文。")
	add_child(workspace_window)
	assert_true(page.is_inside_tree(), "隐藏独立窗口仍应正常挂载内部工作区。")
	assert_same(page.context_at_first_enter, context, "窗口页面首次入树应能访问注入上下文。")
	assert_false(workspace_window.visible, "设置上下文不应自动弹出独立窗口。")


func test_window_forwards_context_replacement_and_explicit_revocation() -> void:
	var workspace_window: _WORKSPACE_WINDOW_SCRIPT = _new_window()
	workspace_window.setup(_context_records(), GFEditorToolContext.new())
	add_child(workspace_window)
	var page: _CONTEXT_PAGE_SCRIPT = _get_context_page(workspace_window)
	if page == null:
		return
	var replacement_context: GFEditorToolContext = GFEditorToolContext.new()
	workspace_window.set_editor_context(replacement_context)

	assert_same(page.current_context, replacement_context, "窗口应把替换上下文转发给已存在的页面。")
	assert_same(_get_context_page(workspace_window), page, "窗口上下文更新不应重建页面。")
	workspace_window.set_editor_context(null)
	assert_null(page.current_context, "窗口显式撤销应传递到贡献页面。")
	assert_eq(page.enter_count, 1, "窗口上下文转发不应改变页面生命周期。")


func test_window_legacy_setup_revokes_replaced_page_context() -> void:
	var workspace_window: _WORKSPACE_WINDOW_SCRIPT = _new_window()
	workspace_window.setup(_context_records(), GFEditorToolContext.new())
	add_child(workspace_window)
	var old_page: _CONTEXT_PAGE_SCRIPT = _get_context_page(workspace_window)
	if old_page == null:
		return
	workspace_window.setup(_context_records())
	var new_page: _CONTEXT_PAGE_SCRIPT = _get_context_page(workspace_window)
	if new_page == null:
		return

	assert_false(old_page.is_inside_tree(), "窗口重设页面记录应移除旧页面。")
	assert_null(old_page.current_context, "窗口重设页面时应撤销旧页面上下文。")
	assert_null(old_page.context_at_last_exit, "窗口旧页面离树前应完成上下文撤销。")
	assert_null(new_page.current_context, "窗口单参数 setup 应清除先前提供的上下文。")
	assert_null(new_page.context_at_first_enter, "新页面入树时不应继承过期的窗口上下文。")


func test_window_leaving_tree_revokes_context_from_retained_pages() -> void:
	var workspace_window: _WORKSPACE_WINDOW_SCRIPT = _new_window()
	workspace_window.setup(_context_records(), GFEditorToolContext.new())
	add_child(workspace_window)
	var page: _CONTEXT_PAGE_SCRIPT = _get_context_page(workspace_window)
	if page == null:
		return

	remove_child(workspace_window)
	assert_true(is_instance_valid(page), "窗口离树时应允许页面存活到窗口真正释放。")
	assert_false(page.is_inside_tree(), "移除窗口应同时移除内部工作区页面。")
	assert_null(page.current_context, "窗口离树应通过内部工作区撤销贡献页面上下文。")


# --- 私有辅助 ---

func _new_dock() -> _WORKSPACE_DOCK_SCRIPT:
	var dock: _WORKSPACE_DOCK_SCRIPT = _WORKSPACE_DOCK_SCRIPT.new()
	_roots.append(dock)
	return dock


func _new_window() -> _WORKSPACE_WINDOW_SCRIPT:
	var workspace_window: _WORKSPACE_WINDOW_SCRIPT = _WORKSPACE_WINDOW_SCRIPT.new()
	_roots.append(workspace_window)
	return workspace_window


func _context_records(label: String = "Context") -> Array[Dictionary]:
	var records: Array[Dictionary] = [_context_record(label)]
	return records


func _context_record(label: String) -> Dictionary:
	return {
		"path": "res://tests/gf_core/kernel/editor/fixtures/gf_workspace_context_page.gd",
		"label": label,
	}


func _get_context_page(root: Node, label: String = "Context") -> _CONTEXT_PAGE_SCRIPT:
	var page: Node = root.find_child("%s Content" % label, true, false)
	assert_true(page is _CONTEXT_PAGE_SCRIPT, "工作区应实例化指定的上下文贡献页面。")
	if page is _CONTEXT_PAGE_SCRIPT:
		var context_page: _CONTEXT_PAGE_SCRIPT = page
		return context_page
	return null


func _get_passive_page(root: Node) -> _PASSIVE_PAGE_SCRIPT:
	var page: Node = root.find_child("Passive Content", true, false)
	assert_true(page is _PASSIVE_PAGE_SCRIPT, "工作区应正常实例化没有上下文接口的贡献页面。")
	if page is _PASSIVE_PAGE_SCRIPT:
		var passive_page: _PASSIVE_PAGE_SCRIPT = page
		return passive_page
	return null
