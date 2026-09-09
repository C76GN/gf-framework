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
