@tool

# 仅由隔离 Editor 验收入口启用；使用真实插件上下文、工具栏和已连接的原生 UI 信号。
extends EditorPlugin


# --- 常量 ---

const TEMPLATE_SCRIPT = preload("res://tests/gf_core/extensions/flow/fixtures/gf_flow_clipboard_node.gd")
const DOCK_TOOLS_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_dock_tools.gd")
const FLOW_PAGE_PATH: String = "res://addons/gf/extensions/flow/editor/gf_flow_graph_dock.gd"


# --- 内部类 ---

class HistoryFailureCommand extends GFFlowGraphEditCommand:
	var fixture_graph: GFFlowGraph = null

	func get_graph_for_editor() -> GFFlowGraph:
		return fixture_graph


	func _get_undo_context() -> Object:
		return fixture_graph


class ControlledHistoryTarget extends RefCounted:
	var stored_value: int = 0
	var rejected_values: Array[int] = []
	var before_set: Callable = Callable()

	func _init(initial_value: int) -> void:
		stored_value = initial_value


	func _get_property_list() -> Array[Dictionary]:
		return [
			{
				"name": "value",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
			},
		]


	func _get(property: StringName) -> Variant:
		if property == &"value":
			return stored_value
		return null


	func _set(property: StringName, raw_value: Variant) -> bool:
		if property != &"value" or not raw_value is int:
			return false
		var requested_value: int = raw_value
		if before_set.is_valid():
			var _called: Variant = before_set.call(requested_value)
		if rejected_values.has(requested_value):
			return false
		stored_value = requested_value
		return true


# --- 私有变量 ---

var _dock: GFFlowGraphDock = null
var _tools: DOCK_TOOLS_SCRIPT = null
var _graphs: Array[GFFlowGraph] = []
var _paths: PackedStringArray = PackedStringArray()
var _owned_histories: Array[UndoRedo] = []
var _owned_history_test_docks: Array[WeakRef] = []
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
	print(
		"GF_FLOW_NATIVE_HISTORY_SCOPE ",
		JSON.stringify(
			{
				"first_history_id": first_history_id,
				"second_history_id": second_history_id,
				"global_history_id": EditorUndoRedoManager.GLOBAL_HISTORY,
				"same_history": first_history == second_history,
			}
		)
	)
	_check(
		first_history_id == EditorUndoRedoManager.GLOBAL_HISTORY
		and second_history_id == first_history_id
		and first_history == second_history,
		"两个独立保存的外部图资源使用真实共享全局历史"
	)
	# Flow 的生产入口是 GF Workspace 页面，不能把它假设为原生 270px 侧栏。
	_tools = DOCK_TOOLS_SCRIPT.new()
	_tools.setup(
		self,
		[
			{
				"source_id": "flow.clipboard.fixture",
				"path": FLOW_PAGE_PATH,
				"label": "GF Flow Tools",
				"short_label": "流程",
			},
		]
	)
	var page: Control = _tools.open_workspace_page(FLOW_PAGE_PATH)
	_check(
		page is GFFlowGraphDock,
		"正式工作区宿主创建实际 Flow 页面"
	)
	if not (page is GFFlowGraphDock):
		await _finish()
		return
	_dock = page
	var main_context: GFEditorToolContext = GFEditorToolContext.from_plugin(self)
	_check(
		main_context.undo_manager == manager,
		"主 Flow 页面保留来自实际 EditorPlugin 的原生管理器上下文"
	)
	_dock.set_editor_context(main_context)
	_dock.set_graph(first)
	var workspace_window: Window = _tools.get_workspace_window()
	_check(
		workspace_window != null and workspace_window.visible,
		"正式 GF Workspace 窗口可见"
	)
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
	_check(
		first.nodes.size() == 2 and not first_history.has_undo(),
		"复制不改源图或原生历史"
	)
	_dock.set_graph(second)
	_press("粘贴")
	_check(
		second.nodes.size() == 4,
		"真实工具栏跨图粘贴"
	)
	var pasted: GFFlowNode = _node(second, &"a_2")
	_check(
		pasted != null,
		"粘贴产生不冲突的 ID"
	)
	_check(
		second_history.get_current_action_name() == "粘贴 Flow 节点",
		"真实资源历史中的操作名称"
	)
	_check(
		second_history.undo(),
		"原生资源历史 Undo"
	)
	_check(
		second.nodes.size() == 2 and _node(second, &"a_2") == null,
		"一笔 Undo 恢复节点和连接"
	)
	_check(
		second_history.redo(),
		"原生资源历史 Redo"
	)
	_check(
		_node(second, &"a_2") == pasted,
		"Redo 保留同一粘贴资源身份"
	)
	await get_tree().process_frame
	_select([&"a"])
	_press("重复")
	_check(
		second.nodes.size() == 5,
		"真实重复按钮"
	)
	_check(
		second_history.undo(),
		"重复的一笔 Undo"
	)
	_check(
		second.nodes.size() == 4,
		"重复撤销恢复库存"
	)
	await get_tree().process_frame
	var template: GFFlowNode = TEMPLATE_SCRIPT.new()
	template.node_id = &"template"
	var template_port: GFFlowPort = GFFlowPort.new()
	template_port.port_id = &"input"
	template_port.direction = GFFlowPort.Direction.INPUT
	template_port.value_type = GFFlowPort.ValueType.NUMBER
	template.input_ports = [template_port]
	var template_path: String = _path("node_template")
	var template_save_error: Error = ResourceSaver.save(
		template,
		template_path,
		ResourceSaver.FLAG_CHANGE_PATH
	)
	_check(
		template_save_error == OK,
		"保存原生节点模板"
	)
	if template_save_error == OK:
		template.take_over_path(template_path)
		_check(
			template.resource_path == template_path,
			"模板资源取得实际保存路径"
		)
	_press("添加节点模板…")
	var dialog: FileDialog = _template_dialog()
	_check(
		dialog != null,
		"存在独立模板资源选择器"
	)
	if dialog != null:
		dialog.file_selected.emit(template_path)
	_check(
		_node(second, &"template") != null,
		"真实已绑定 FileDialog 信号插入模板"
	)
	var inserted_template: GFFlowNode = _node(second, &"template")
	if inserted_template != null:
		var same_script: bool = inserted_template.get_script() == template.get_script()
		_check(same_script, "真实 Editor 模板保留项目脚本")
		_check(
			inserted_template.input_ports.size() == 1
			and inserted_template.input_ports[0] != template_port
			and inserted_template.input_ports[0].value_type == GFFlowPort.ValueType.NUMBER,
			"真实 Editor 模板深复制 typed port"
		)
	_check(
		second_history.undo(),
		"模板插入的一笔 Undo"
	)
	_check(
		_node(second, &"template") == null,
		"模板撤销完整恢复"
	)
	_press("添加节点模板…")
	_dock.set_graph(first)
	if dialog != null:
		dialog.file_selected.emit(template_path)
	_check(
		first.nodes.size() == 2 and second.nodes.size() == 4,
		"迟到模板选择不修改新旧图"
	)
	var feedback_found: bool = false
	for child: Node in _dock.get_child(0).get_children():
		if child is Label:
			var label: Label = child
			if label.text == "已保留复制包，可粘贴到当前流程图。":
				feedback_found = true
	_check(feedback_found, "换图反馈说明保留的复制包，不宣称上一图插入成功")
	var copy_button: Button = _button("复制")
	_check(
		copy_button != null and copy_button.disabled,
		"换图清除旧选择"
	)
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
	_check(
		second_history.undo(),
		"真实原生 Undo 在拒绝回调后仍移动游标"
	)
	_check(
		second_history.get_current_action() == action_before - 1 and second_history.has_redo(),
		"失败撤销不能冒充停止原生历史游标"
	)
	_check(
		GFFlowGraphEditorModel.capture_edit_state(second) == preserved
		and _node(second, &"a_2") == pasted
		and _node(second, &"external_after_paste") == external,
		"stale Undo 保留粘贴资源和外部编辑且零写图结构"
	)
	await get_tree().process_frame
	_check(
		_has_history_conflict_feedback(),
		"页面必须解释撤销失败、历史位置改变及外部编辑保留"
	)
	_check_workspace_layout()
	_capture_if_requested()
	if not await _check_history_recovery(
		manager,
		main_context,
		first,
		second,
		template_path
	):
		await _finish()
		return
	await _check_refresh_rejects_old_template(manager, template_path)
	await _finish()


func _check_history_recovery(
	manager: EditorUndoRedoManager,
	main_context: GFEditorToolContext,
	first: GFFlowGraph,
	second: GFFlowGraph,
	template_path: String
) -> bool:
	var button: Button = _button("重置撤销历史…")
	_check(
		button != null
		and button.is_visible_in_tree()
		and not button.disabled,
		"历史失配后的实际 Flow 页面必须提供显式确认的重置撤销历史入口"
	)
	if button == null:
		return false
	var history_id: int = manager.get_object_history_id(second)
	var history: UndoRedo = manager.get_history_undo_redo(history_id)
	_check(
		history != null and history == manager.get_history_undo_redo(manager.get_object_history_id(first)),
		"恢复入口面对两个实际图资源共享的原生历史"
	)
	if history == null:
		return false
	var first_before: Dictionary = GFFlowGraphEditorModel.capture_edit_state(first)
	var second_before: Dictionary = GFFlowGraphEditorModel.capture_edit_state(second)
	var first_contents: Dictionary = _fixture_graph_contents(first)
	var second_contents: Dictionary = _fixture_graph_contents(second)
	var first_file_before: PackedByteArray = FileAccess.get_file_as_bytes(first.resource_path)
	var second_file_before: PackedByteArray = FileAccess.get_file_as_bytes(second.resource_path)
	var secondary: GFFlowGraphDock = GFFlowGraphDock.new()
	var secondary_context: GFEditorToolContext = GFEditorToolContext.from_plugin(self)
	secondary.set_editor_context(secondary_context)
	secondary.set_graph(first)
	_dock.get_parent().add_child(secondary)
	_owned_history_test_docks.append(weakref(secondary))
	await get_tree().process_frame
	_check(
		secondary.is_visible_in_tree() and secondary.get_window() == _dock.get_window(),
		"另一张图使用同一真实可见工作区内的独立 Flow 页面"
	)
	_select_for_dock(
		secondary,
		[&"a"]
	)
	_select([&"a"])
	_check_history_buttons(
		secondary,
		true,
		false
	)
	_check_history_buttons(
		_dock,
		true,
		false
	)
	var stamp: Dictionary = _history_stamp(history)
	var confirmation: ConfirmationDialog = await _open_history_reset(_dock)
	if confirmation == null:
		return false
	_check_reset_scope_text(confirmation)
	confirmation.get_cancel_button().pressed.emit()
	await get_tree().process_frame
	_check(
		not confirmation.visible and _history_stamp(history) == stamp,
		"真实取消按钮不清除或移动共享 Undo/Redo 历史"
	)
	_check(
		GFFlowGraphEditorModel.capture_edit_state(first) == first_before and GFFlowGraphEditorModel.capture_edit_state(second) == second_before,
		"取消保留两张图全部结构与资源身份"
	)
	_check(
		_fixture_graph_contents(first) == first_contents and _fixture_graph_contents(second) == second_contents,
		"取消也保留全部 fixture 图与节点属性值"
	)

	confirmation = await _open_history_reset(_dock)
	if confirmation == null:
		return false
	var callbacks: Array[Callable] = _confirmation_callbacks(confirmation)
	_dock.set_graph(first)
	_emit_late_confirmation(callbacks)
	_check(
		_history_stamp(history) == stamp,
		"换图后保存的迟到确认不能清除共享历史"
	)
	_check(
		GFFlowGraphEditorModel.capture_edit_state(first) == first_before and GFFlowGraphEditorModel.capture_edit_state(second) == second_before,
		"换图后的迟到确认不写任一图"
	)
	_dock.set_graph(second)
	confirmation = await _open_history_reset(_dock)
	if confirmation == null:
		return false
	callbacks = _confirmation_callbacks(confirmation)
	_dock.hide()
	_emit_late_confirmation(callbacks)
	_dock.show()
	await get_tree().process_frame
	_check(
		_history_stamp(history) == stamp,
		"隐藏后重新显示也不能重新接纳旧确认"
	)

	confirmation = await _open_history_reset(_dock)
	if confirmation == null:
		return false
	callbacks = _confirmation_callbacks(confirmation)
	var old_resource_name: String = second.resource_name
	var late_resource_name: String = old_resource_name + " late-confirm-action"
	var later_action: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
	var _configured_later: GFEditorPropertyBatchCommand = later_action.configure(
		[
			{
				"target": second,
				"property_name": &"resource_name",
				"new_value": late_resource_name,
			},
		],
		{ "command_name": "Fixture action while confirmation is open" }
	)
	_check(
		later_action.add_to_undo_manager(manager) == OK and later_action.get_last_execute_error() == OK,
		"独立编辑器动作真实写入同一原生历史"
	)
	_check(
		second.resource_name == late_resource_name and _history_stamp(history) != stamp,
		"确认显示后确实发生新 native action 与资源值变化"
	)
	second_contents["resource_name"] = late_resource_name
	stamp = _history_stamp(history)
	_emit_late_confirmation(callbacks)
	_check(
		_history_stamp(history) == stamp and second.resource_name == late_resource_name,
		"新历史动作撤销旧确认的清除资格，并保留该动作实际值"
	)
	_check(
		GFFlowGraphEditorModel.capture_edit_state(first) == first_before and GFFlowGraphEditorModel.capture_edit_state(second) == second_before,
		"新资源名称动作没有篡改原有 Flow 图结构"
	)

	confirmation = await _open_history_reset(_dock)
	if confirmation == null:
		return false
	callbacks = _confirmation_callbacks(confirmation)
	_check_reset_scope_text(confirmation)
	var first_clear_version: int = history.get_version()
	confirmation.get_ok_button().pressed.emit()
	await get_tree().process_frame
	_check(
		history.get_history_count() == 0
		and not history.has_undo()
		and not history.has_redo(),
		"第一次实际确认清除共享 Undo/Redo，随后才能建立健康的新事务"
	)
	_check(
		history.get_version() > first_clear_version,
		"原生历史清除增加版本，不使用不增加版本的清除路径"
	)
	_check(
		_fixture_graph_contents(first) == first_contents and _fixture_graph_contents(second) == second_contents,
		"第一次明确重置保持两张图当前全部 fixture 属性"
	)
	_check(
		FileAccess.get_file_as_bytes(first.resource_path) == first_file_before and FileAccess.get_file_as_bytes(second.resource_path) == second_file_before,
		"第一次重置不写入磁盘资源"
	)
	_select_for_dock(
		secondary,
		[&"a"]
	)
	_select([&"a"])
	_check_history_buttons(
		secondary,
		false,
		false
	)
	_check_history_buttons(
		_dock,
		false,
		false
	)
	# 故障从已成功重置的健康历史开始，不绕过 Flow 自身的新写入锁。
	var first_value: ControlledHistoryTarget = ControlledHistoryTarget.new(1)
	var second_value: ControlledHistoryTarget = ControlledHistoryTarget.new(2)
	second_value.rejected_values.append(20)
	second_value.before_set = func(requested_value: int) -> void:
		if requested_value == 20 and not first_value.rejected_values.has(1):
			first_value.rejected_values.append(1)
	var failure: HistoryFailureCommand = HistoryFailureCommand.new()
	failure.fixture_graph = second
	var _configured_failure: GFEditorPropertyBatchCommand = failure.configure(
		[
			{
				"target": first_value,
				"property_name": &"value",
				"new_value": 10,
			},
			{
				"target": second_value,
				"property_name": &"value",
				"new_value": 20,
			},
		],
		{ "command_name": "Fixture setter compensation failure" }
	)
	failure.observe_page(_dock)
	_check(
		manager.get_object_history_id(first_value) == history_id and manager.get_object_history_id(second_value) == history_id,
		"故障命令目标与图上下文均路由到实际共享历史"
	)
	_check(
		failure.add_to_undo_manager(manager) == OK,
		"真实 native manager 接纳动作不等于属性事务成功"
	)
	_check(
		failure.get_last_execute_error() != OK and GFVariantData.get_option_bool(
			failure.get_transaction_report(),
			"recovery_required"
		),
		"真实 setter 拒绝及 rollback 拒绝形成实际未完成补偿"
	)
	_check(
		first_value.stored_value == 10 and second_value.stored_value == 2,
		"未完成补偿保留真实可诊断残余值"
	)
	stamp = _history_stamp(history)
	_emit_late_confirmation(callbacks)
	_check(
		_history_stamp(history) == stamp and GFVariantData.get_option_bool(
			failure.get_transaction_report(),
			"recovery_required"
		),
		"补偿债务产生后旧确认不能清历史或丢弃债务"
	)
	await get_tree().process_frame
	secondary.refresh()
	_dock.refresh()
	_select_for_dock(
		secondary,
		[&"a"]
	)
	_select([&"a"])
	_check_history_buttons(
		secondary,
		true,
		true
	)
	_check_history_buttons(
		_dock,
		true,
		true
	)
	secondary.set_editor_context(null)
	_select_for_dock(
		secondary,
		[&"a"]
	)
	var copy_without_context: Button = _button_from_dock(secondary, "复制")
	_check(
		copy_without_context != null and copy_without_context.disabled,
		"实际补偿债务存在时撤下上下文不能让复制读入半提交状态"
	)
	if copy_without_context != null:
		copy_without_context.pressed.emit()
	var half_state_copy_reported: bool = false
	for child: Node in secondary.find_children(
		"*",
		"Label",
		true,
		false
	):
		if child is Label:
			var label: Label = child
			if label.text.begins_with("已复制 "):
				half_state_copy_reported = true
	_check(not half_state_copy_reported, "上下文已撤销且有真实欠账时不能把复制信号报告为成功")
	_check(
		GFVariantData.get_option_bool(
			failure.get_transaction_report(),
			"recovery_required"
		)
		and first_value.stored_value == 10
		and second_value.stored_value == 2,
		"撤下上下文后的复制信号不补偿目标或丢弃真实欠账"
	)
	_check(
		_history_stamp(history) == stamp
		and _fixture_graph_contents(first) == first_contents
		and _fixture_graph_contents(second) == second_contents,
		"撤下上下文复制保留真实历史与图属性"
	)
	secondary.set_editor_context(secondary_context)
	_select_for_dock(
		secondary,
		[&"a"]
	)
	_check_history_buttons(
		secondary,
		true,
		true
	)
	var reset_during_debt: Button = _button_from_dock(secondary, "重置撤销历史…")
	if reset_during_debt != null:
		reset_during_debt.pressed.emit()
	_check(
		_history_stamp(history) == stamp and first_value.stored_value == 10,
		"即使收到程序化按钮信号，补偿未完成时也不清历史"
	)
	var recover: Button = _button_from_dock(secondary, "恢复编辑")
	_check(
		recover != null
		and recover.is_visible_in_tree()
		and not recover.disabled,
		"共享历史另一页面可发现并处理真实补偿债务"
	)
	if recover == null:
		return false
	recover.pressed.emit()
	_check(
		GFVariantData.get_option_bool(
			failure.get_transaction_report(),
			"recovery_required"
		) and first_value.stored_value == 10,
		"setter 仍拒绝时恢复失败，不误解锁或清除历史"
	)
	await get_tree().process_frame
	first_value.rejected_values.clear()
	second_value.before_set = Callable()
	# 原地替换上下文管理器不触发 set_editor_context；实际恢复仍须复核当前原生历史资格。
	var incompatible_manager: RefCounted = RefCounted.new()
	secondary_context.undo_manager = incompatible_manager
	recover.pressed.emit()
	_check(
		GFVariantData.get_option_bool(
			failure.get_transaction_report(),
			"recovery_required"
		)
		and first_value.stored_value == 10
		and second_value.stored_value == 2,
		"原地替换为不匹配管理器后迟到恢复信号不能写补偿目标或丢弃真实欠账"
	)
	_check(
		_history_stamp(history) == stamp
		and _fixture_graph_contents(first) == first_contents
		and _fixture_graph_contents(second) == second_contents,
		"失效管理器下的恢复拒绝保持实际原生历史和两图全部 fixture 属性"
	)
	secondary_context.undo_manager = manager
	_dock.set_editor_context(null)
	_select([&"a"])
	var copy_waiting_for_recovery: Button = _button("复制")
	_check(
		copy_waiting_for_recovery != null and copy_waiting_for_recovery.disabled,
		"真实补偿尚未完成时主页面撤下上下文仍禁止复制"
	)
	recover.pressed.emit()
	_check(
		not GFVariantData.get_option_bool(
			failure.get_transaction_report(),
			"recovery_required"
		)
		and first_value.stored_value == 1
		and second_value.stored_value == 2,
		"另一页面通过真实命令恢复原 attempt guard"
	)
	_check(
		_history_stamp(history) == stamp,
		"属性恢复不冒充历史重置，仍保留原 native history"
	)
	await get_tree().process_frame
	await get_tree().process_frame
	_select([&"a"])
	var detached_copy: Button = _button("复制")
	var detached_save: Button = _button("保存")
	var detached_write: Button = _button("重复")
	_check(
		detached_copy != null and not detached_copy.disabled,
		"实际恢复结束后的延期解绑允许无上下文页面复制完整图"
	)
	_check(
		detached_save != null
		and detached_save.disabled
		and detached_write != null
		and detached_write.disabled,
		"无编辑上下文页面恢复只读复制能力，不恢复保存或新写入"
	)
	if detached_copy != null:
		detached_copy.pressed.emit()
	var complete_copy_reported: bool = false
	for child: Node in _dock.find_children(
		"*",
		"Label",
		true,
		false
	):
		if child is Label:
			var detached_label: Label = child
			if detached_label.text.begins_with("已复制 "):
				complete_copy_reported = true
	_check(complete_copy_reported, "延期解绑后的实际复制信号读取已完整恢复图并提供成功反馈")
	_check(
		_history_stamp(history) == stamp
		and first_value.stored_value == 1
		and second_value.stored_value == 2
		and not GFVariantData.get_option_bool(
			failure.get_transaction_report(),
			"recovery_required"
		),
		"完整恢复后的只读复制不新增历史、不改已恢复目标且不重建补偿债务"
	)
	_check(
		_fixture_graph_contents(first) == first_contents and _fixture_graph_contents(second) == second_contents,
		"延期解绑与只读复制保持两图全部 fixture 属性"
	)
	_dock.set_editor_context(main_context)
	_select([&"a"])
	secondary.refresh()
	_dock.refresh()
	_check_history_buttons(
		secondary,
		true,
		false
	)
	_check_history_buttons(
		_dock,
		true,
		false
	)

	confirmation = await _open_history_reset(_dock)
	if confirmation == null:
		return false
	_check_reset_scope_text(confirmation)
	var second_clear_version: int = history.get_version()
	var notification_watch: Dictionary = _watch_history_reset_notification(manager, second)
	if notification_watch.is_empty():
		return false
	var notification_values_variant: Variant = notification_watch.get("values")
	_check(
		notification_values_variant is Dictionary,
		"最终通知 probe 保留同一个可观察字典"
	)
	if not notification_values_variant is Dictionary:
		_finish_history_reset_notification_watch(notification_watch)
		return false
	var notification_values: Dictionary = notification_values_variant
	notification_values["callstack_active"] = true
	confirmation.get_ok_button().pressed.emit()
	notification_values["callstack_active"] = false
	await get_tree().process_frame
	await get_tree().process_frame
	_finish_history_reset_notification_watch(notification_watch)
	var feedback_node: Node = _dock.find_child(
		"HistoryStatus",
		true,
		false
	)
	_check(
		feedback_node is Label,
		"历史完成反馈使用实际可见的状态标签"
	)
	if feedback_node is Label:
		var feedback: Label = feedback_node
		_check(
			feedback.is_visible_in_tree() and feedback.text.contains("撤销历史已重置"),
			"完成反馈不会被同一次延后通知立即清空"
		)
	_check(
		GFVariantData.get_option_bool(notification_values, "open_seen"),
		"实际重置完成后发布可继续的共享历史通知"
	)
	_check(
		not GFVariantData.get_option_bool(notification_values, "synchronous_open"),
		"最终可继续通知发生在确认 handler 返回后，不在旧清除调用栈内提前开放新 native action"
	)
	_check(
		not GFVariantData.get_option_bool(notification_values, "native_action_added"),
		"原清除调用栈不允许最终通知订阅者提前加入原生历史动作"
	)
	_check(
		history.get_history_count() == 0
		and not history.has_undo()
		and not history.has_redo(),
		"实际确认按钮只清除此共享历史的全部 Undo/Redo"
	)
	_check(
		history.get_version() > second_clear_version,
		"第二次确认仍增加原生历史版本，而不是标记为不变版本"
	)
	_check(
		GFFlowGraphEditorModel.capture_edit_state(first) == first_before
		and GFFlowGraphEditorModel.capture_edit_state(second) == second_before
		and second.resource_name == late_resource_name,
		"重置不撤销任何当前图结构或已完成外部资源值"
	)
	_check(
		_fixture_graph_contents(first) == first_contents and _fixture_graph_contents(second) == second_contents,
		"清除共享历史不改任何 fixture 图、节点与端口属性"
	)
	_check(
		FileAccess.get_file_as_bytes(first.resource_path) == first_file_before and FileAccess.get_file_as_bytes(second.resource_path) == second_file_before,
		"重置不写入或保存任何图文件"
	)
	_select_for_dock(
		secondary,
		[&"a"]
	)
	_select([&"a"])
	_check_history_buttons(
		secondary,
		false,
		false
	)
	_check_history_buttons(
		_dock,
		false,
		false
	)
	var before_binding_change: Dictionary = _history_stamp(history)
	var replacement_manager: RefCounted = RefCounted.new()
	main_context.undo_manager = replacement_manager
	_dock.refresh()
	var current_feedback_node: Node = _dock.find_child(
		"HistoryStatus",
		true,
		false
	)
	_check(
		current_feedback_node is Label,
		"绑定改变后仍使用实际状态标签说明当前历史"
	)
	if current_feedback_node is Label:
		var current_feedback: Label = current_feedback_node
		_check(
			not current_feedback.is_visible_in_tree() or not current_feedback.text.contains("撤销历史已重置"),
			"切换实际历史绑定后不得显示旧历史的完成消息"
		)
	_check(
		_history_stamp(history) == before_binding_change,
		"纯绑定变更和刷新不改原实际历史内容或位置"
	)
	main_context.undo_manager = manager
	_dock.refresh()
	_select([&"a"])
	_check_history_buttons(
		_dock,
		false,
		false
	)
	secondary.queue_free()
	await get_tree().process_frame
	var before_new_insert: Dictionary = GFFlowGraphEditorModel.capture_edit_state(second)
	_press("添加节点模板…")
	var template_dialog: FileDialog = _template_dialog()
	_check(
		template_dialog != null and template_dialog.visible,
		"恢复后实际模板入口重新可用"
	)
	if template_dialog == null:
		return false
	template_dialog.file_selected.emit(template_path)
	var inserted: GFFlowNode = _node(second, &"template")
	_check(
		inserted != null and history.get_history_count() == 1,
		"恢复后的新插入只建立一笔 fresh native action"
	)
	if feedback_node is Label:
		var feedback_after_insert: Label = feedback_node
		_check(
			not feedback_after_insert.is_visible_in_tree() or not feedback_after_insert.text.contains("撤销历史已重置"),
			"新的实际图编辑清除上一轮重置完成反馈"
		)
	_check(
		history.undo() and GFFlowGraphEditorModel.capture_edit_state(second) == before_new_insert,
		"重置后新动作的原生 Undo 正常恢复当前基线"
	)
	_check(
		history.redo() and _node(second, &"template") == inserted,
		"新动作的 Redo 仍复用同一新增资源身份"
	)
	template_dialog.hide()
	await get_tree().process_frame
	return true


func _watch_history_reset_notification(manager: EditorUndoRedoManager, graph: GFFlowGraph) -> Dictionary:
	var state: GFFlowEditorHistoryState = GFFlowEditorHistoryState.acquire(manager, graph)
	_check(
		state != null,
		"最终通知 probe 绑定真实管理器与图的共享历史状态"
	)
	if state == null:
		return {}
	var state_ref: WeakRef = weakref(state)
	var manager_ref: WeakRef = weakref(manager)
	var graph_ref: WeakRef = weakref(graph)
	var values: Dictionary = {
		"callstack_active": false,
		"open_seen": false,
		"synchronous_open": false,
		"native_action_added": false,
	}
	var callback: Callable = func() -> void:
		var current_state_value: Variant = state_ref.get_ref()
		if not current_state_value is GFFlowEditorHistoryState:
			return
		var current_state: GFFlowEditorHistoryState = current_state_value
		var status: Dictionary = current_state.get_status()
		if (
			GFVariantData.get_option_bool(status, "busy")
			or GFVariantData.get_option_bool(status, "blocked")
			or GFVariantData.get_option_bool(values, "open_seen")
		):
			return
		values["open_seen"] = true
		var callstack_active: bool = GFVariantData.get_option_bool(values, "callstack_active")
		values["synchronous_open"] = callstack_active
		if not callstack_active:
			return
		# 旧实现的提前开放才提交同值动作；正常 deferred 通知不插入该 probe 动作。
		var current_manager_value: Variant = manager_ref.get_ref()
		var current_graph_value: Variant = graph_ref.get_ref()
		if not current_manager_value is EditorUndoRedoManager or not current_graph_value is GFFlowGraph:
			return
		var current_manager: EditorUndoRedoManager = current_manager_value
		var current_graph: GFFlowGraph = current_graph_value
		var probe_action: GFEditorPropertyBatchCommand = GFEditorPropertyBatchCommand.new()
		var _configured_probe_action: GFEditorPropertyBatchCommand = probe_action.configure(
			[
				{
					"target": current_graph,
					"property_name": &"resource_name",
					"new_value": current_graph.resource_name,
				},
			],
			{ "command_name": "Fixture synchronous reset notification" }
		)
		values["native_action_added"] = probe_action.add_to_undo_manager(current_manager) == OK and probe_action.get_last_execute_error() == OK
	var connection_error: int = state.changed.connect(callback)
	_check(
		connection_error == OK,
		"实际共享状态 changed 订阅成功"
	)
	if connection_error != OK:
		return {}
	return {
		"state_ref": state_ref,
		"callback": callback,
		"values": values,
	}


func _finish_history_reset_notification_watch(watch: Dictionary) -> void:
	var state_ref_value: Variant = watch.get("state_ref")
	var callback_value: Variant = watch.get("callback")
	if not state_ref_value is WeakRef or not callback_value is Callable:
		return
	var state_ref: WeakRef = state_ref_value
	var callback: Callable = callback_value
	var state_value: Variant = state_ref.get_ref()
	if not state_value is GFFlowEditorHistoryState:
		return
	var state: GFFlowEditorHistoryState = state_value
	if state.changed.is_connected(callback):
		state.changed.disconnect(callback)


func _open_history_reset(dock: GFFlowGraphDock) -> ConfirmationDialog:
	var button: Button = _button_from_dock(dock, "重置撤销历史…")
	_check(
		button != null
		and button.is_visible_in_tree()
		and not button.disabled,
		"当前页面可重新发起显式历史重置"
	)
	if button == null or button.disabled:
		return null
	button.pressed.emit()
	await get_tree().process_frame
	for child: Node in dock.find_children(
		"*",
		"ConfirmationDialog",
		true,
		false
	):
		if child is ConfirmationDialog:
			var dialog: ConfirmationDialog = child
			if dialog.visible and dialog.title == "重置撤销历史":
				return dialog
	_check(false, "实际重置入口必须打开可见的确认对话框")
	return null


func _check_reset_scope_text(dialog: ConfirmationDialog) -> void:
	var text: String = dialog.dialog_text
	var describes_undo: bool = text.contains("撤销") or text.contains("Undo")
	var describes_redo: bool = text.contains("重做") or text.contains("Redo")
	_check(
		text.contains("全局")
		and text.contains("其他资源")
		and text.contains("全部")
		and describes_undo
		and describes_redo,
		"确认说明真实共享全局范围和丢失的全部撤销/重做记录"
	)
	_check(
		text.contains("当前")
		and text.contains("内存")
		and (
			text.contains("不会保存")
			or text.contains("不保存")
		),
		"确认说明保持当前内存值且不保存文件"
	)
	_check(
		text.contains("无法撤回") or text.contains("无法恢复"),
		"确认明确说明清除历史不能撤回"
	)
	_check(
		dialog.get_ok_button().text == "清除历史并继续",
		"危险确认明确说明真正清除历史"
	)


func _confirmation_callbacks(dialog: ConfirmationDialog) -> Array[Callable]:
	var callbacks: Array[Callable] = []
	for connection: Dictionary in dialog.confirmed.get_connections():
		var value: Variant = connection.get("callable")
		if value is Callable:
			var callback: Callable = value
			callbacks.append(callback)
	_check(
		not callbacks.is_empty(),
		"迟到确认复用实际已连接的回调，不能捏造私有请求"
	)
	return callbacks


func _emit_late_confirmation(callbacks: Array[Callable]) -> void:
	for callback: Callable in callbacks:
		if callback.is_valid():
			var _called: Variant = callback.call()


func _history_stamp(history: UndoRedo) -> Dictionary:
	return {
		"version": history.get_version(),
		"count": history.get_history_count(),
		"cursor": history.get_current_action(),
		"undo": history.has_undo(),
		"redo": history.has_redo(),
	}


func _fixture_graph_contents(graph: GFFlowGraph) -> Dictionary:
	var node_values: Array[Dictionary] = []
	for node: GFFlowNode in graph.nodes:
		var ports: Array[Dictionary] = []
		for port: GFFlowPort in node.input_ports + node.output_ports:
			ports.append(
				{
					"instance_id": port.get_instance_id(),
					"port_id": port.port_id,
					"display_name": port.display_name,
					"direction": port.direction,
					"value_type": port.value_type,
					"allow_multiple": port.allow_multiple,
					"editor_color": port.editor_color,
					"type_hint": port.type_hint,
					"class_name_hint": port.class_name_hint,
					"semantic_tags": port.semantic_tags.duplicate(),
					"metadata": port.metadata.duplicate(true),
				}
			)
		node_values.append(
			{
				"instance_id": node.get_instance_id(),
				"script": node.get_script(),
				"resource_name": node.resource_name,
				"node_id": node.node_id,
				"display_name": node.display_name,
				"category": node.category,
				"next_node_ids": node.next_node_ids.duplicate(),
				"wait_for_result": node.wait_for_result,
				"input_ports": node.input_ports.duplicate(),
				"output_ports": node.output_ports.duplicate(),
				"ports": ports,
				"metadata": node.metadata.duplicate(true),
				"editor_position": node.editor_position,
				"editor_size": node.editor_size,
				"editor_collapsed": node.editor_collapsed,
			}
		)
	return {
		"instance_id": graph.get_instance_id(),
		"resource_name": graph.resource_name,
		"start_node_id": graph.start_node_id,
		"nodes": node_values,
		"connections": graph.connections.duplicate(true),
		"validate_port_compatibility": graph.validate_port_compatibility,
		"warn_unreachable_nodes": graph.warn_unreachable_nodes,
		"warn_cycles": graph.warn_cycles,
		"warn_terminal_nodes": graph.warn_terminal_nodes,
		"editor_groups": graph.editor_groups.duplicate(true),
		"editor_metadata": graph.editor_metadata.duplicate(true),
		"metadata_schema": graph.metadata_schema.duplicate(true),
	}


func _button_from_dock(dock: GFFlowGraphDock, text: String) -> Button:
	for child: Node in dock.find_children(
		"*",
		"Button",
		true,
		false
	):
		if child is Button:
			var button: Button = child
			if button.text == text:
				return button
	return null


func _select_for_dock(dock: GFFlowGraphDock, identifiers: Array[StringName]) -> void:
	for child: Node in dock.find_children(
		"*",
		"GraphNode",
		true,
		false
	):
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


func _check_history_buttons(
	dock: GFFlowGraphDock,
	conflict: bool,
	compensation: bool
) -> void:
	var duplicate_button: Button = _button_from_dock(dock, "重复")
	var copy_button: Button = _button_from_dock(dock, "复制")
	var save_button: Button = _button_from_dock(dock, "保存")
	var reset_button: Button = _button_from_dock(dock, "重置撤销历史…")
	_check(
		duplicate_button != null and duplicate_button.disabled == conflict,
		"同 history 的页面按失配暂停或恢复新编辑动作"
	)
	_check(
		copy_button != null and copy_button.disabled == compensation,
		"复制仅在真实补偿债务未清时暂停"
	)
	_check(
		save_button != null and save_button.disabled == compensation,
		"保存仅在真实补偿债务未清时暂停"
	)
	if conflict:
		_check(
			reset_button != null
			and reset_button.is_visible_in_tree()
			and reset_button.disabled == compensation,
			"历史重置不能替代真实属性补偿"
		)


func _check_refresh_rejects_old_template(manager: EditorUndoRedoManager, template_path: String) -> void:
	var first: GFFlowGraph = _graph(&"refresh_request_first")
	var second: GFFlowGraph = _graph(&"refresh_destination_second")
	var first_before: Dictionary = GFFlowGraphEditorModel.capture_edit_state(first)
	var second_before: Dictionary = GFFlowGraphEditorModel.capture_edit_state(second)
	var history_id: int = manager.get_object_history_id(second)
	var history: UndoRedo = manager.get_history_undo_redo(history_id)
	_check(
		history != null and _owned_histories.has(history),
		"刷新回归使用真实且已由 fixture 拥有的资源历史"
	)
	if history == null:
		return
	var action_before: int = history.get_current_action()
	var count_before: int = history.get_history_count()
	_dock.set_graph(first)
	await get_tree().process_frame
	var path_edit: LineEdit = _graph_path_edit_for_refresh()
	_check(
		path_edit != null,
		"刷新回归使用实际资源路径输入框"
	)
	if path_edit == null:
		return
	_check(
		path_edit.text == first.resource_path,
		"模板请求从图 A 的实际路径开始"
	)
	_press("添加节点模板…")
	var dialog: FileDialog = _template_dialog()
	_check(
		dialog != null and dialog.visible,
		"模板请求由实际可见对话框发起"
	)
	if dialog == null:
		return
	path_edit.text = second.resource_path
	_press("刷新")
	var model: GFFlowGraphEditorModel = GFFlowGraphEditorModel.new()
	_check(
		path_edit.text == second.resource_path and _dock.get_last_view_model() == model.build_view_model(second),
		"实际刷新按钮已把当前页面重载为图 B"
	)
	dialog.file_selected.emit(template_path)
	_check(
		GFFlowGraphEditorModel.capture_edit_state(first) == first_before and GFFlowGraphEditorModel.capture_edit_state(second) == second_before,
		"图 A 的迟到模板结果不能写入刷新后的图 B"
	)
	_check(
		history.get_current_action() == action_before and history.get_history_count() == count_before,
		"拒绝旧模板请求不增加或移动真实原生资源历史"
	)
	_press("添加节点模板…")
	dialog.file_selected.emit(template_path)
	_check(
		second.nodes.size() == 3 and _node(second, &"template") != null,
		"刷新后重新发起的模板请求可正常插入图 B"
	)
	_check(
		history.get_current_action() == action_before + 1,
		"新模板请求只增加一笔真实原生操作"
	)
	_check(
		GFFlowGraphEditorModel.capture_edit_state(first) == first_before,
		"新请求也不改变原来的图 A"
	)
	dialog.hide()
	await get_tree().process_frame


func _graph_path_edit_for_refresh() -> LineEdit:
	for child: Node in _dock.find_children(
		"*",
		"LineEdit",
		true,
		false
	):
		if child is LineEdit:
			var edit: LineEdit = child
			if edit.placeholder_text == "res://path/to/flow_graph.tres":
				return edit
	return null


func _has_history_conflict_feedback() -> bool:
	for child: Node in _dock.find_children(
		"*",
		"Label",
		true,
		false
	):
		if child is Label:
			var label: Label = child
			if (
				label.text.contains("撤销")
				and label.text.contains("历史")
				and label.text.contains("外部")
			):
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
	_check(
		idle,
		"%s：实际编辑器扫描与导入必须在有界期限内空闲" % phase
	)
	return idle


func _check_workspace_page_visible() -> bool:
	var window: Window = _dock.get_window()
	var visible: bool = (
		_dock.is_visible_in_tree()
		and window != null
		and window.visible
	)
	_check(visible, "正式工作区必须选中实际 Flow 页面且所属窗口可见")
	return visible


func _check_workspace_layout() -> void:
	var page_rect: Rect2 = _dock.get_global_rect()
	for caption: String in [
		"选择资源…",
		"定位资源",
		"刷新",
		"自动布局",
		"保存",
		"复制",
		"剪切",
		"粘贴",
		"重复",
		"添加节点模板…",
	]:
		var button: Button = _button(caption)
		_check(
			button != null,
			"布局保留可发现按钮：%s" % caption
		)
		if button != null:
			_check(
				page_rect.encloses(button.get_global_rect()),
				"正式最小窗口中按钮完整位于页面内：%s" % caption
			)
	var root: Node = _dock.get_child(0)
	if root is VBoxContainer:
		for child: Node in root.get_children():
			if child is Label:
				var label: Label = child
				if label.visible and not label.text.is_empty():
					_check(
						label.get_visible_line_count() > 0,
						"状态摘要与操作反馈实际拥有可见文本行"
					)
	for child: Node in _dock.find_children(
		"*",
		"GraphEdit",
		true,
		false
	):
		if child is GraphEdit:
			var canvas: GraphEdit = child
			_check(
				canvas.is_visible_in_tree()
				and canvas.size.x > 0.0
				and canvas.size.y > 0.0,
				"正式最小窗口中实际图画布可见"
			)
			_check(
				page_rect.encloses(canvas.get_global_rect()),
				"图画布完整位于正式页面内"
			)


func _graph(label: StringName) -> GFFlowGraph:
	var graph: GFFlowGraph = GFFlowGraph.new()
	for identifier: StringName in [&"a", &"b"]:
		var node: GFFlowNode = GFFlowNode.new()
		node.node_id = identifier
		graph.nodes.append(node)
	graph.nodes[0].next_node_ids = PackedStringArray(["b"])
	graph.start_node_id = &"a"
	graph.connections = [
		{
			"from_node_id": &"a",
			"from_port_id": &"",
			"to_node_id": &"b",
			"to_port_id": &"",
			"metadata": { "label": String(label) },
		},
	]
	var path: String = _path(String(label))
	var save_error: Error = ResourceSaver.save(
		graph,
		path,
		ResourceSaver.FLAG_CHANGE_PATH
	)
	_check(
		save_error == OK,
		"保存实际图资源"
	)
	if save_error == OK:
		graph.take_over_path(path)
		_check(
			graph.resource_path == path,
			"图资源取得实际保存路径"
		)
	_graphs.append(graph)
	return graph


func _path(label: String) -> String:
	var directory: String = "res://ai_analysis/godot_logs/flow_clipboard_editor_fixture"
	var error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	_check(
		error == OK,
		"创建隔离 fixture 目录"
	)
	var path: String = (
		"%s/%s_%d.tres"
		% [
			directory,
			label,
			get_instance_id(),
		]
	)
	var _appended: bool = _paths.append(path)
	return path


func _own_empty_history(manager: EditorUndoRedoManager, graph: GFFlowGraph) -> UndoRedo:
	var history_id: int = manager.get_object_history_id(graph)
	var history: UndoRedo = manager.get_history_undo_redo(history_id)
	if (
		history == null
		or history.has_undo()
		or history.has_redo()
	):
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
	for child: Node in _dock.find_children(
		"*",
		"GraphNode",
		true,
		false
	):
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
	for child: Node in _dock.find_children(
		"*",
		"Button",
		true,
		false
	):
		if child is Button:
			var button: Button = child
			if button.text == text:
				return button
	return null


func _press(text: String) -> void:
	var button: Button = _button(text)
	_check(
		button != null and not button.disabled,
		"可发现且可用的按钮：%s" % text
	)
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
	_check(
		image != null and image.save_png(path) == OK,
		"可选实际 Editor viewport 截图"
	)


func _cleanup() -> void:
	_cleanup_history_test_docks()
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
			_check(
				error == OK,
				"删除本 fixture 创建的临时资源"
			)
	_paths.clear()


func _cleanup_history_test_docks() -> void:
	for dock_ref: WeakRef in _owned_history_test_docks:
		var value: Variant = dock_ref.get_ref()
		if value is GFFlowGraphDock and is_instance_valid(value):
			var dock: GFFlowGraphDock = value
			var parent: Node = dock.get_parent()
			if parent != null:
				parent.remove_child(dock)
			dock.queue_free()
	_owned_history_test_docks.clear()


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
	get_tree().call_deferred(
		&"quit",
		0 if _failures.is_empty() else 1
	)
