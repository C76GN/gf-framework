@tool

# 仅由隔离 Editor 验收入口启用；使用真实插件上下文、工具栏和已连接的原生 UI 信号。
extends EditorPlugin


# --- 常量 ---

const TEMPLATE_SCRIPT = preload("res://tests/gf_core/extensions/flow/fixtures/gf_flow_clipboard_node.gd")
const DOCK_TOOLS_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_dock_tools.gd")
const FLOW_PAGE_PATH: String = "res://addons/gf/extensions/flow/editor/gf_flow_graph_dock.gd"


# --- 私有变量 ---

var _dock: GFFlowGraphDock = null
var _tools: DOCK_TOOLS_SCRIPT = null
var _graphs: Array[GFFlowGraph] = []
var _paths: PackedStringArray = PackedStringArray()
var _owned_histories: Array[UndoRedo] = []
var _failures: PackedStringArray = PackedStringArray()
var _finished: bool = false


# --- Godot 回调方法 ---

func _enter_tree() -> void:
	_run.call_deferred()


func _exit_tree() -> void:
	_cleanup()


# --- 私有/辅助方法 ---

func _run() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if not await _wait_editor_idle("初始化"):
		await _finish()
		return
	var first: GFFlowGraph = _graph(&"first")
	var second: GFFlowGraph = _graph(&"second")
	var manager: EditorUndoRedoManager = get_undo_redo()
	var first_history: UndoRedo = _own_empty_history(manager, first)
	var second_history: UndoRedo = _own_empty_history(manager, second)
	if first_history == null or second_history == null:
		await _finish()
		return
	var first_history_id: int = manager.get_object_history_id(first)
	var second_history_id: int = manager.get_object_history_id(second)
	print("GF_FLOW_NATIVE_HISTORY_SCOPE ", JSON.stringify({
		"first_history_id": first_history_id, "second_history_id": second_history_id,
		"global_history_id": EditorUndoRedoManager.GLOBAL_HISTORY,
		"same_history": first_history == second_history,
	}))
	_check(first_history_id == EditorUndoRedoManager.GLOBAL_HISTORY and second_history_id == first_history_id and first_history == second_history, "两个独立保存的外部图资源使用真实共享全局历史")
	# Flow 的生产入口是 GF Workspace 页面，不能把它假设为原生 270px 侧栏。
	_tools = DOCK_TOOLS_SCRIPT.new()
	_tools.setup(self, [{"source_id": "flow.clipboard.fixture", "path": FLOW_PAGE_PATH, "label": "GF Flow Tools", "short_label": "流程"}])
	var page: Control = _tools.open_workspace_page(FLOW_PAGE_PATH)
	_check(page is GFFlowGraphDock, "正式工作区宿主创建实际 Flow 页面")
	if not (page is GFFlowGraphDock):
		await _finish()
		return
	_dock = page
	_dock.set_graph(first)
	var workspace_window: Window = _tools.get_workspace_window()
	_check(workspace_window != null and workspace_window.visible, "正式 GF Workspace 窗口可见")
	if workspace_window == null:
		await _finish()
		return
	# 验证正式宿主既有的最小窗口尺寸，不扩大尺寸来隐藏布局问题。
	workspace_window.size = workspace_window.min_size
	await get_tree().process_frame
	if not _check_workspace_page_visible():
		await _finish()
		return
	await get_tree().process_frame
	_select([&"a", &"b"])
	_press("复制")
	_check(first.nodes.size() == 2 and not first_history.has_undo(), "复制不改源图或原生历史")
	_dock.set_graph(second)
	_press("粘贴")
	_check(second.nodes.size() == 4, "真实工具栏跨图粘贴")
	var pasted: GFFlowNode = _node(second, &"a_2")
	_check(pasted != null, "粘贴产生不冲突的 ID")
	_check(second_history.get_current_action_name() == "粘贴 Flow 节点", "真实资源历史中的操作名称")
	_check(second_history.undo(), "原生资源历史 Undo")
	_check(second.nodes.size() == 2 and _node(second, &"a_2") == null, "一笔 Undo 恢复节点和连接")
	_check(second_history.redo(), "原生资源历史 Redo")
	_check(_node(second, &"a_2") == pasted, "Redo 保留同一粘贴资源身份")
	await get_tree().process_frame
	_select([&"a"])
	_press("重复")
	_check(second.nodes.size() == 5, "真实重复按钮")
	_check(second_history.undo(), "重复的一笔 Undo")
	_check(second.nodes.size() == 4, "重复撤销恢复库存")
	await get_tree().process_frame
	var template: GFFlowNode = TEMPLATE_SCRIPT.new()
	template.node_id = &"template"
	var template_port: GFFlowPort = GFFlowPort.new()
	template_port.port_id = &"input"
	template_port.direction = GFFlowPort.Direction.INPUT
	template_port.value_type = GFFlowPort.ValueType.NUMBER
	template.input_ports = [template_port]
	var template_path: String = _path("node_template")
	var template_save_error: Error = ResourceSaver.save(template, template_path, ResourceSaver.FLAG_CHANGE_PATH)
	_check(template_save_error == OK, "保存原生节点模板")
	if template_save_error == OK:
		template.take_over_path(template_path)
		_check(template.resource_path == template_path, "模板资源取得实际保存路径")
	_press("添加节点模板…")
	var dialog: FileDialog = _template_dialog()
	_check(dialog != null, "存在独立模板资源选择器")
	if dialog != null:
		dialog.file_selected.emit(template_path)
	_check(_node(second, &"template") != null, "真实已绑定 FileDialog 信号插入模板")
	var inserted_template: GFFlowNode = _node(second, &"template")
	if inserted_template != null:
		var same_script: bool = inserted_template.get_script() == template.get_script()
		_check(same_script, "真实 Editor 模板保留项目脚本")
		_check(inserted_template.input_ports.size() == 1 and inserted_template.input_ports[0] != template_port and inserted_template.input_ports[0].value_type == GFFlowPort.ValueType.NUMBER, "真实 Editor 模板深复制 typed port")
	_check(second_history.undo(), "模板插入的一笔 Undo")
	_check(_node(second, &"template") == null, "模板撤销完整恢复")
	_press("添加节点模板…")
	_dock.set_graph(first)
	if dialog != null:
		dialog.file_selected.emit(template_path)
	_check(first.nodes.size() == 2 and second.nodes.size() == 4, "迟到模板选择不修改新旧图")
	var feedback_found: bool = false
	for child: Node in _dock.get_child(0).get_children():
		if child is Label:
			var label: Label = child
			if label.text == "已保留复制包，可粘贴到当前流程图。":
				feedback_found = true
	_check(feedback_found, "换图反馈说明保留的复制包，不宣称上一图插入成功")
	var copy_button: Button = _button("复制")
	_check(copy_button != null and copy_button.disabled, "换图清除旧选择")
	if dialog != null:
		dialog.hide()
	await get_tree().process_frame
	_dock.set_graph(second)
	var external: GFFlowNode = GFFlowNode.new()
	external.node_id = &"external_after_paste"
	second.nodes.append(external)
	second.emit_changed()
	var preserved: Dictionary = GFFlowGraphEditorModel.capture_edit_state(second)
	var action_before: int = second_history.get_current_action()
	_check(second_history.undo(), "真实原生 Undo 在拒绝回调后仍移动游标")
	_check(second_history.get_current_action() == action_before - 1 and second_history.has_redo(), "失败撤销不能冒充停止原生历史游标")
	_check(GFFlowGraphEditorModel.capture_edit_state(second) == preserved and _node(second, &"a_2") == pasted and _node(second, &"external_after_paste") == external, "stale Undo 保留粘贴资源和外部编辑且零写图结构")
	await get_tree().process_frame
	_check(_has_history_conflict_feedback(), "页面必须解释撤销失败、历史位置改变及外部编辑保留")
	_check_workspace_layout()
	_capture_if_requested()
	await _check_refresh_rejects_old_template(manager, template_path)
	await _finish()


func _check_refresh_rejects_old_template(manager: EditorUndoRedoManager, template_path: String) -> void:
	var first: GFFlowGraph = _graph(&"refresh_request_first")
	var second: GFFlowGraph = _graph(&"refresh_destination_second")
	var first_before: Dictionary = GFFlowGraphEditorModel.capture_edit_state(first)
	var second_before: Dictionary = GFFlowGraphEditorModel.capture_edit_state(second)
	var history_id: int = manager.get_object_history_id(second)
	var history: UndoRedo = manager.get_history_undo_redo(history_id)
	_check(history != null and _owned_histories.has(history), "刷新回归使用真实且已由 fixture 拥有的资源历史")
	if history == null:
		return
	var action_before: int = history.get_current_action()
	var count_before: int = history.get_history_count()
	_dock.set_graph(first)
	await get_tree().process_frame
	var path_edit: LineEdit = _graph_path_edit_for_refresh()
	_check(path_edit != null, "刷新回归使用实际资源路径输入框")
	if path_edit == null:
		return
	_check(path_edit.text == first.resource_path, "模板请求从图 A 的实际路径开始")
	_press("添加节点模板…")
	var dialog: FileDialog = _template_dialog()
	_check(dialog != null and dialog.visible, "模板请求由实际可见对话框发起")
	if dialog == null:
		return
	path_edit.text = second.resource_path
	_press("刷新")
	var model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	_check(path_edit.text == second.resource_path and _dock.get_last_view_model() == model.build_view_model(second), "实际刷新按钮已把当前页面重载为图 B")
	dialog.file_selected.emit(template_path)
	_check(GFFlowGraphEditorModel.capture_edit_state(first) == first_before and GFFlowGraphEditorModel.capture_edit_state(second) == second_before, "图 A 的迟到模板结果不能写入刷新后的图 B")
	_check(history.get_current_action() == action_before and history.get_history_count() == count_before, "拒绝旧模板请求不增加或移动真实原生资源历史")
	_press("添加节点模板…")
	dialog.file_selected.emit(template_path)
	_check(second.nodes.size() == 3 and _node(second, &"template") != null, "刷新后重新发起的模板请求可正常插入图 B")
	_check(history.get_current_action() == action_before + 1, "新模板请求只增加一笔真实原生操作")
	_check(GFFlowGraphEditorModel.capture_edit_state(first) == first_before, "新请求也不改变原来的图 A")
	dialog.hide()
	await get_tree().process_frame


func _graph_path_edit_for_refresh() -> LineEdit:
	for child: Node in _dock.find_children("*", "LineEdit", true, false):
		if child is LineEdit:
			var edit: LineEdit = child
			if edit.placeholder_text == "res://path/to/flow_graph.tres":
				return edit
	return null


func _has_history_conflict_feedback() -> bool:
	for child: Node in _dock.find_children("*", "Label", true, false):
		if child is Label:
			var label: Label = child
			if label.text.contains("撤销") and label.text.contains("历史") and label.text.contains("外部"):
				return true
	return false


func _wait_editor_idle(phase: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + 30000
	var idle_frames: int = 0
	var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	while idle_frames < 3 and Time.get_ticks_msec() < deadline:
		if not is_inside_tree():
			return false
		await get_tree().process_frame
		idle_frames = 0 if filesystem.is_scanning() or filesystem.is_importing() else idle_frames + 1
	var idle: bool = idle_frames == 3
	_check(idle, "%s：实际编辑器扫描与导入必须在有界期限内空闲" % phase)
	return idle


func _check_workspace_page_visible() -> bool:
	var window: Window = _dock.get_window()
	var visible: bool = _dock.is_visible_in_tree() and window != null and window.visible
	_check(visible, "正式工作区必须选中实际 Flow 页面且所属窗口可见")
	return visible


func _check_workspace_layout() -> void:
	var page_rect: Rect2 = _dock.get_global_rect()
	for caption: String in ["选择资源…", "定位资源", "刷新", "自动布局", "保存", "复制", "剪切", "粘贴", "重复", "添加节点模板…"]:
		var button: Button = _button(caption)
		_check(button != null, "布局保留可发现按钮：%s" % caption)
		if button != null:
			_check(page_rect.encloses(button.get_global_rect()), "正式最小窗口中按钮完整位于页面内：%s" % caption)
	var root: Node = _dock.get_child(0)
	if root is VBoxContainer:
		for child: Node in root.get_children():
			if child is Label:
				var label: Label = child
				if label.visible and not label.text.is_empty():
					_check(label.get_visible_line_count() > 0, "状态摘要与操作反馈实际拥有可见文本行")
	for child: Node in _dock.find_children("*", "GraphEdit", true, false):
		if child is GraphEdit:
			var canvas: GraphEdit = child
			_check(canvas.is_visible_in_tree() and canvas.size.x > 0.0 and canvas.size.y > 0.0, "正式最小窗口中实际图画布可见")
			_check(page_rect.encloses(canvas.get_global_rect()), "图画布完整位于正式页面内")


func _graph(label: StringName) -> GFFlowGraph:
	var graph: GFFlowGraph = GFFlowGraph.new()
	for identifier: StringName in [&"a", &"b"]:
		var node: GFFlowNode = GFFlowNode.new()
		node.node_id = identifier
		graph.nodes.append(node)
	graph.nodes[0].next_node_ids = PackedStringArray(["b"])
	graph.start_node_id = &"a"
	graph.connections = [{"from_node_id": &"a", "from_port_id": &"", "to_node_id": &"b", "to_port_id": &"", "metadata": {"label": String(label)}}]
	var path: String = _path(String(label))
	var save_error: Error = ResourceSaver.save(graph, path, ResourceSaver.FLAG_CHANGE_PATH)
	_check(save_error == OK, "保存实际图资源")
	if save_error == OK:
		graph.take_over_path(path)
		_check(graph.resource_path == path, "图资源取得实际保存路径")
	_graphs.append(graph)
	return graph


func _path(label: String) -> String:
	var directory: String = "res://ai_analysis/godot_logs/flow_clipboard_editor_fixture"
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_check(error == OK, "创建隔离 fixture 目录")
	var path: String = "%s/%s_%d.tres" % [directory, label, get_instance_id()]
	var _appended: bool = _paths.append(path)
	return path


func _own_empty_history(manager: EditorUndoRedoManager, graph: GFFlowGraph) -> UndoRedo:
	var history_id: int = manager.get_object_history_id(graph)
	var history: UndoRedo = manager.get_history_undo_redo(history_id)
	if history == null or history.has_undo() or history.has_redo():
		_check(false, "fixture 必须使用初始为空的隔离编辑历史")
		return null
	if not _owned_histories.has(history):
		_owned_histories.append(history)
	return history


func _node(graph: GFFlowGraph, identifier: StringName) -> GFFlowNode:
	for node: GFFlowNode in graph.nodes:
		if node != null and node.node_id == identifier:
			return node
	return null


func _select(identifiers: Array[StringName]) -> void:
	for child: Node in _dock.find_children("*", "GraphNode", true, false):
		if child is GraphNode:
			var control: GraphNode = child
			var metadata: Variant = control.get_meta("node_id", &"")
			if metadata is StringName:
				var identifier: StringName = metadata
				control.selected = identifiers.has(identifier)
				var parent: Node = control.get_parent()
				if control.selected and parent is GraphEdit:
					var canvas: GraphEdit = parent
					canvas.node_selected.emit(control)


func _button(text: String) -> Button:
	for child: Node in _dock.find_children("*", "Button", true, false):
		if child is Button:
			var button: Button = child
			if button.text == text:
				return button
	return null


func _press(text: String) -> void:
	var button: Button = _button(text)
	_check(button != null and not button.disabled, "可发现且可用的按钮：%s" % text)
	if button != null and not button.disabled:
		button.pressed.emit()


func _template_dialog() -> FileDialog:
	for child: Node in _dock.get_children():
		if child is FileDialog:
			var dialog: FileDialog = child
			if dialog.title == "选择已保存的 Flow 节点模板":
				return dialog
	return null


func _check(condition: bool, description: String) -> void:
	if not condition:
		var _appended: bool = _failures.append(description)


func _capture_if_requested() -> void:
	if OS.get_environment("GF_FLOW_CLIPBOARD_SMOKE_CAPTURE") != "1":
		return
	var image: Image = _dock.get_viewport().get_texture().get_image()
	var path: String = "res://ai_analysis/godot_logs/flow_clipboard_editor_fixture/editor.png"
	_check(image != null and image.save_png(path) == OK, "可选实际 Editor viewport 截图")


func _cleanup() -> void:
	if _tools != null:
		_tools.cleanup(self)
		_tools = null
	_dock = null
	for history: UndoRedo in _owned_histories:
		history.clear_history()
	_owned_histories.clear()
	_graphs.clear()
	for path: String in _paths:
		if FileAccess.file_exists(path):
			var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			_check(error == OK, "删除本 fixture 创建的临时资源")
	_paths.clear()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	_cleanup()
	# 本 fixture 的资源已删除，显式完成原生目录复核后才允许 Editor 退出。
	EditorInterface.get_resource_filesystem().scan()
	var _idle: bool = await _wait_editor_idle("退出前")
	if _failures.is_empty():
		print("GF_FLOW_CLIPBOARD_EDITOR_OK native_history=true toolbar=true template_signal=true stale_rejected=true")
	else:
		print("GF_FLOW_CLIPBOARD_EDITOR_FAILED ", _failures)
	get_tree().call_deferred(&"quit", 0 if _failures.is_empty() else 1)
