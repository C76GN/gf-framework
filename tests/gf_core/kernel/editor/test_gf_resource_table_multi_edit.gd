@tool

# 多选编辑通过实际表格选择、分量输入和应用/取消按钮验证。
extends GutTest


# --- 公共方法 ---

func after_each() -> void:
	await get_tree().process_frame


# --- 测试 ---

func test_mixed_vector_edit_changes_only_the_edited_component_and_undoes_once() -> void:
	var first: VectorResource = VectorResource.new()
	var second: VectorResource = VectorResource.new()
	first.position = Vector2(1, 10)
	second.position = Vector2(2, 20)
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([first, second], manager)
	if not _select_rows_and_property(table, &"position"):
		return
	var state: Label = table.find_child("MultiPropertyStatus", true, false)
	assert_string_contains(state.text, "混合")
	var x_input: SpinBox = _component_spin(table, "x")
	if x_input == null:
		return
	x_input.value = 8
	assert_eq(first.position, Vector2(1, 10), "输入仅暂存，不写对象。")
	assert_eq(second.position, Vector2(2, 20))
	_press(table, "ApplyMultiEdit")
	assert_eq(first.position, Vector2(8, 10))
	assert_eq(second.position, Vector2(8, 20), "保留各目标未编辑的 y 分量。")
	assert_eq(manager.action_count, 1, "整次多选只创建一个动作。")
	assert_eq(manager.command.revert(), OK)
	assert_eq(first.position, Vector2(1, 10))
	assert_eq(second.position, Vector2(2, 20))
	assert_eq(manager.command.execute(), OK)
	assert_eq(second.position, Vector2(8, 20))


func test_cancel_and_selection_change_discard_staged_values() -> void:
	var first: VectorResource = VectorResource.new()
	var second: VectorResource = VectorResource.new()
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([first, second], manager)
	if not _select_rows_and_property(table, &"amount"):
		return
	var amount: SpinBox = _component_spin(table, "value")
	if amount == null:
		return
	amount.value = 12
	_press(table, "CancelMultiEdit")
	assert_eq(first.amount, 0)
	assert_eq(second.amount, 0)
	assert_eq(manager.action_count, 0)
	var apply: Button = table.find_child("ApplyMultiEdit", true, false)
	assert_true(apply.disabled)
	amount = _component_spin(table, "value")
	if amount == null:
		return
	amount.value = 5
	var tree: Tree = table.find_child("ResourceTree", true, false)
	tree.deselect_all()
	tree.multi_selected.emit(tree.get_root().get_first_child(), 0, false)
	assert_true(apply.disabled, "清空选择应丢弃草稿。")
	assert_eq(first.amount, 0)
	assert_eq(manager.action_count, 0)


func test_missing_and_incompatible_properties_are_not_partially_written() -> void:
	var first: VectorResource = VectorResource.new()
	var missing: Resource = Resource.new()
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([first, missing], manager)
	if not _select_rows_and_property(table, &"amount"):
		return
	var status: Label = table.find_child("MultiPropertyStatus", true, false)
	var apply: Button = table.find_child("ApplyMultiEdit", true, false)
	assert_string_contains(status.text, "缺失")
	assert_true(apply.disabled)
	var different: DifferentResource = DifferentResource.new()
	table.load_resources([first, different])
	assert_true(_select_rows_and_property(table, &"amount"))
	status = table.find_child("MultiPropertyStatus", true, false)
	assert_string_contains(status.text, "不兼容")
	assert_true(apply.disabled)
	assert_eq(manager.action_count, 0)


func test_no_undo_context_keeps_multi_edit_read_only() -> void:
	var resource: VectorResource = VectorResource.new()
	var table: GFResourceTableEditor = _make_table([resource], null)
	if not _select_rows_and_property(table, &"amount"):
		return
	var amount: SpinBox = _component_spin(table, "value")
	if amount == null:
		return
	amount.value = 3
	var apply: Button = table.find_child("ApplyMultiEdit", true, false)
	assert_true(apply.disabled)
	assert_eq(resource.amount, 0)


func test_undo_history_does_not_keep_table_alive() -> void:
	var resource: VectorResource = VectorResource.new()
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([resource], manager)
	if not _select_rows_and_property(table, &"amount"):
		return
	var amount: SpinBox = _component_spin(table, "value")
	if amount == null:
		return
	amount.value = 7
	_press(table, "ApplyMultiEdit")
	assert_eq(resource.amount, 7)
	var table_reference: WeakRef = weakref(table)
	table.free()
	assert_false(table_reference.get_ref() is Object)
	assert_eq(manager.command.revert(), OK, "关闭面板后历史仍能撤销资源。")
	assert_eq(resource.amount, 0)


func test_external_change_to_an_untouched_component_survives_apply() -> void:
	var resource: VectorResource = VectorResource.new()
	resource.position = Vector2(1, 2)
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([resource], manager)
	if not _select_rows_and_property(table, &"position"):
		return
	var x_input: SpinBox = _component_spin(table, "x")
	if x_input == null:
		return
	x_input.value = 9
	resource.position.y = 42
	_press(table, "ApplyMultiEdit")
	assert_eq(resource.position, Vector2(9, 42))
	assert_eq(manager.command.revert(), OK)
	assert_eq(resource.position, Vector2(1, 42), "Undo 只撤销本次命令的修改。")


func test_explicit_component_checkbox_can_unify_a_mixed_value_without_changing_input() -> void:
	var first: VectorResource = VectorResource.new()
	var second: VectorResource = VectorResource.new()
	first.position = Vector2(5, 10)
	second.position = Vector2(9, 20)
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([first, second], manager)
	if not _select_rows_and_property(table, &"position"):
		return
	var edit_x: CheckBox = table.find_child("Edit_x", true, false)
	assert_not_null(edit_x)
	if edit_x == null:
		return
	edit_x.button_pressed = true
	_press(table, "ApplyMultiEdit")
	assert_eq(first.position, Vector2(5, 10))
	assert_eq(second.position, Vector2(5, 20))
	assert_eq(manager.action_count, 1)


func test_field_rejects_freed_target_and_deduplicates_selection() -> void:
	var field: GFEditorMultiPropertyField = GFEditorMultiPropertyField.new()
	add_child_autofree(field)
	var target: Node2D = Node2D.new()
	field.configure([target, target], &"position")
	var snapshot: Dictionary = field.get_snapshot()
	assert_eq(_int_field(snapshot, "target_count"), 1)
	var input: SpinBox = _component_spin(field, "x")
	if input == null:
		target.free()
		return
	input.value = 4
	target.free()
	var prepared: Dictionary = field.prepare_changes()
	assert_false(_bool_field(prepared, "ok"))
	assert_eq(_string_field(prepared, "status"), "invalid")
	field.configure([], &"position")
	assert_eq(_string_field(field.get_snapshot(), "status"), "empty")


func test_integer_vector_components_remain_integer_and_unsupported_types_stay_read_only() -> void:
	var first: IntegerVectorResource = IntegerVectorResource.new()
	var second: IntegerVectorResource = IntegerVectorResource.new()
	first.position = Vector3i(1, 2, 3)
	second.position = Vector3i(4, 5, 6)
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([first, second], manager)
	if not _select_rows_and_property(table, &"position"):
		return
	var z_input: SpinBox = _component_spin(table, "z")
	if z_input == null:
		return
	z_input.value = 7
	_press(table, "ApplyMultiEdit")
	assert_eq(first.position, Vector3i(1, 2, 7))
	assert_eq(second.position, Vector3i(4, 5, 7))
	assert_true(_select_rows_and_property(table, &"values"))
	var state: Label = table.find_child("MultiPropertyStatus", true, false)
	assert_string_contains(state.text, "仅展示")
	var apply: Button = table.find_child("ApplyMultiEdit", true, false)
	assert_true(apply.disabled)


func test_failed_execution_is_reported_despite_a_void_undo_manager_return() -> void:
	var target: RejectingResource = RejectingResource.new()
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([target], manager)
	watch_signals(table)
	if not _select_rows_and_property(table, &"amount"):
		return
	var amount: SpinBox = _component_spin(table, "value")
	if amount == null:
		return
	amount.value = 7
	_press(table, "ApplyMultiEdit")
	assert_eq(target.amount, 0)
	assert_false(_bool_field(table.get_multi_edit_report(), "ok"))
	assert_signal_not_emitted(table, "cell_value_committed")
	assert_eq(manager.action_count, 1, "管理器已经建立动作，不把它误报成成功写入。")


func test_detached_old_input_cannot_stage_changes_for_a_new_selection() -> void:
	var first: VectorResource = VectorResource.new()
	var second: VectorResource = VectorResource.new()
	var field: GFEditorMultiPropertyField = GFEditorMultiPropertyField.new()
	add_child_autofree(field)
	field.configure([first], &"position")
	var previous: SpinBox = _component_spin(field, "x")
	if previous == null:
		return
	field.configure([second], &"position")
	previous.value = 13
	assert_false(_bool_field(field.get_snapshot(), "dirty"), "旧输入的迟到信号不能污染新选择。")
	var prepared: Dictionary = field.prepare_changes()
	var changes_value: Variant = prepared.get("changes")
	assert_true(changes_value is Array)
	if changes_value is Array:
		var changes: Array = changes_value
		assert_true(changes.is_empty())
	assert_eq(second.position, Vector2.ZERO)


func test_leaving_and_reentering_the_tree_cancels_input_without_rebuilding_during_exit() -> void:
	var target: VectorResource = VectorResource.new()
	var field: GFEditorMultiPropertyField = GFEditorMultiPropertyField.new()
	add_child_autofree(field)
	field.configure([target], &"amount")
	var input: SpinBox = _component_spin(field, "value")
	if input == null:
		return
	input.value = 4
	remove_child(field)
	assert_false(_bool_field(field.get_snapshot(), "dirty"))
	input.value = 8
	assert_false(_bool_field(field.get_snapshot(), "dirty"), "离树后不接收输入回调。")
	add_child(field)
	assert_false(_bool_field(field.get_snapshot(), "dirty"))
	assert_eq(input.value, 0.0, "重新入树恢复未编辑显示。")
	input.value = 3
	assert_true(_bool_field(field.get_snapshot(), "dirty"))
	assert_eq(target.amount, 0)


func test_old_history_does_not_clear_the_draft_of_a_rebound_table() -> void:
	var first: VectorResource = VectorResource.new()
	var second: VectorResource = VectorResource.new()
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([first], manager)
	if not _select_rows_and_property(table, &"amount"):
		return
	var first_input: SpinBox = _component_spin(table, "value")
	if first_input == null:
		return
	first_input.value = 7
	_press(table, "ApplyMultiEdit")
	assert_eq(first.amount, 7)
	table.load_resources([second])
	if not _select_rows_and_property(table, &"amount"):
		return
	var second_input: SpinBox = _component_spin(table, "value")
	if second_input == null:
		return
	second_input.value = 5
	var field: GFEditorMultiPropertyField = table.find_child("MultiPropertyField", true, false)
	watch_signals(table)
	watch_signals(first)
	assert_eq(manager.command.revert(), OK)
	assert_eq(first.amount, 0)
	assert_eq(second.amount, 0)
	assert_true(_bool_field(field.get_snapshot(), "dirty"), "旧资源历史不得取消新选择的草稿。")
	assert_eq(second_input.value, 5.0)
	assert_signal_not_emitted(table, "cell_value_committed")
	assert_signal_emitted(first, "changed", "历史目标自身仍得到变化通知。")


func test_failed_undo_retains_recovery_handle_and_recovery_does_not_complete_undo() -> void:
	var first: RecoverableResource = RecoverableResource.new()
	var second: RecoverableResource = RecoverableResource.new()
	first.amount = 1
	second.amount = 2
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([first, second], manager)
	if not _select_rows_and_property(table, &"amount"):
		return
	var input: SpinBox = _component_spin(table, "value")
	if input == null:
		return
	input.value = 9
	_press(table, "ApplyMultiEdit")
	assert_eq(first.amount, 9)
	assert_eq(second.amount, 9)
	first.rejected_values[1] = true
	second.rejected_values[9] = true
	watch_signals(table)
	assert_ne(manager.command.revert(), OK)
	assert_eq(first.amount, 9)
	assert_eq(second.amount, 2, "补偿失败必须保留实际残余值供恢复。")
	assert_signal_not_emitted(table, "cell_value_committed")
	var report: Dictionary = table.get_multi_edit_report()
	assert_false(_bool_field(report, "ok"), "失败的 Undo 不能继续显示先前成功报告。")
	assert_ne(_int_field(report, "error"), OK)
	assert_same(_command_field(report), manager.command)
	var result_label: Label = table.find_child("MultiEditResult", true, false)
	assert_string_contains(result_label.text, "恢复")
	var recovery: Button = table.find_child("RecoverMultiEdit", true, false)
	assert_not_null(recovery, "用户应有恢复未完整补偿事务的入口。")
	if recovery == null:
		return
	assert_true(recovery.visible)
	assert_false(recovery.disabled)
	var apply: Button = table.find_child("ApplyMultiEdit", true, false)
	assert_true(apply.disabled)
	var blocked: Dictionary = table.apply_selected_property()
	assert_same(_command_field(blocked), manager.command)
	assert_eq(manager.action_count, 1)
	var _removed: bool = second.rejected_values.erase(9)
	_press(table, "RecoverMultiEdit")
	assert_eq(first.amount, 9)
	assert_eq(second.amount, 9, "恢复失败尝试前的 guard，不是假装已完成 Undo。")
	assert_true(manager.command.is_executed())
	assert_true(_bool_field(table.get_multi_edit_report(), "ok"))
	assert_false(table.get_multi_edit_report().has("transaction_command"))
	assert_false(recovery.visible)
	first.rejected_values.clear()
	assert_eq(manager.command.revert(), OK)
	assert_eq(first.amount, 1)
	assert_eq(second.amount, 2)
	assert_true(_bool_field(table.get_multi_edit_report(), "ok"))


func test_pending_apply_recovery_survives_cancel_context_replacement_and_rebinding() -> void:
	var first: RecoverableResource = RecoverableResource.new()
	var second: RecoverableResource = RecoverableResource.new()
	first.amount = 1
	second.amount = 2
	first.rejected_values[1] = true
	second.rejected_values[9] = true
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([first, second], manager)
	if not _select_rows_and_property(table, &"amount"):
		return
	var input: SpinBox = _component_spin(table, "value")
	if input == null:
		return
	input.value = 9
	_press(table, "ApplyMultiEdit")
	assert_eq(first.amount, 9)
	assert_eq(second.amount, 2)
	var failed_command: GFEditorCommand = manager.command
	assert_false(_bool_field(table.get_multi_edit_report(), "ok"))
	assert_same(_command_field(table.get_multi_edit_report()), failed_command)
	_press(table, "CancelMultiEdit")
	table.set_editor_context(null)
	var replacement: VectorResource = VectorResource.new()
	table.load_resources([replacement])
	assert_same(_command_field(table.get_multi_edit_report()), failed_command)
	var recovery: Button = table.find_child("RecoverMultiEdit", true, false)
	assert_not_null(recovery)
	if recovery == null:
		return
	assert_true(recovery.visible)
	assert_true(recovery.disabled)
	_press(table, "RecoverMultiEdit")
	assert_eq(first.amount, 9, "撤销上下文后不能通过按钮继续恢复写入。")
	assert_same(_command_field(table.get_multi_edit_report()), failed_command)
	var context: GFEditorToolContext = GFEditorToolContext.new()
	context.undo_manager = manager
	table.set_editor_context(context)
	if not _select_rows_and_property(table, &"amount"):
		return
	input = _component_spin(table, "value")
	if input == null:
		return
	input.value = 5
	var apply: Button = table.find_child("ApplyMultiEdit", true, false)
	assert_true(apply.disabled, "更换选择不能绕过待恢复事务。")
	var blocked: Dictionary = table.apply_selected_property()
	assert_same(_command_field(blocked), failed_command)
	assert_eq(manager.action_count, 1)
	assert_eq(replacement.amount, 0)
	first.rejected_values.clear()
	_press(table, "RecoverMultiEdit")
	assert_eq(first.amount, 1)
	assert_eq(second.amount, 2)
	assert_false(failed_command.is_executed(), "首次执行失败的恢复不应将命令标记为执行成功。")
	assert_true(_bool_field(table.get_multi_edit_report(), "ok"))
	assert_false(table.get_multi_edit_report().has("transaction_command"))
	assert_eq(replacement.amount, 0)
	assert_false(recovery.visible)


func test_old_resource_undo_failure_preserves_recovery_without_discarding_current_draft() -> void:
	var first: RecoverableResource = RecoverableResource.new()
	var second: RecoverableResource = RecoverableResource.new()
	first.amount = 1
	second.amount = 2
	var manager: RecordingUndoManager = RecordingUndoManager.new()
	var table: GFResourceTableEditor = _make_table([first, second], manager)
	if not _select_rows_and_property(table, &"amount"):
		return
	var input: SpinBox = _component_spin(table, "value")
	if input == null:
		return
	input.value = 9
	_press(table, "ApplyMultiEdit")
	var old_command: GFEditorCommand = manager.command
	var current: VectorResource = VectorResource.new()
	table.load_resources([current])
	if not _select_rows_and_property(table, &"amount"):
		return
	input = _component_spin(table, "value")
	if input == null:
		return
	input.value = 5
	var field: GFEditorMultiPropertyField = table.find_child("MultiPropertyField", true, false)
	first.rejected_values[1] = true
	second.rejected_values[9] = true
	assert_ne(old_command.revert(), OK)
	assert_eq(first.amount, 9)
	assert_eq(second.amount, 2)
	assert_eq(current.amount, 0)
	assert_eq(input.value, 5.0)
	assert_true(_bool_field(field.get_snapshot(), "dirty"), "旧资源失败不能清除当前资源的草稿。")
	var report: Dictionary = table.get_multi_edit_report()
	assert_false(_bool_field(report, "ok"))
	assert_same(_command_field(report), old_command)
	var apply: Button = table.find_child("ApplyMultiEdit", true, false)
	assert_true(apply.disabled, "旧资源补偿失败也必须暂停新的多选应用。")
	var recovery: Button = table.find_child("RecoverMultiEdit", true, false)
	assert_true(recovery.visible)
	if not report.has("transaction_command"):
		return
	var blocked: Dictionary = table.apply_selected_property()
	assert_same(_command_field(blocked), old_command)
	assert_eq(manager.action_count, 1)
	assert_true(_bool_field(field.get_snapshot(), "dirty"))
	second.rejected_values.clear()
	_press(table, "RecoverMultiEdit")
	assert_eq(first.amount, 9)
	assert_eq(second.amount, 9)
	assert_eq(current.amount, 0)
	assert_eq(input.value, 5.0)
	assert_true(_bool_field(field.get_snapshot(), "dirty"), "恢复旧资源不能刷新并清除当前草稿。")
	assert_false(apply.disabled)
	assert_false(recovery.visible)
	_press(table, "ApplyMultiEdit")
	assert_eq(current.amount, 5)
	assert_eq(manager.action_count, 2)


# --- 私有/辅助方法 ---

func _bool_field(source: Dictionary, key: String) -> bool:
	var value: Variant = source.get(key)
	assert_true(value is bool)
	if value is bool:
		var result: bool = value
		return result
	return false


func _command_field(source: Dictionary) -> GFEditorPropertyBatchCommand:
	var value: Variant = source.get("transaction_command")
	assert_true(value is GFEditorPropertyBatchCommand)
	if value is GFEditorPropertyBatchCommand:
		var command: GFEditorPropertyBatchCommand = value
		return command
	return null


func _int_field(source: Dictionary, key: String) -> int:
	var value: Variant = source.get(key)
	assert_true(value is int)
	if value is int:
		var number: int = value
		return number
	return -1


func _string_field(source: Dictionary, key: String) -> String:
	var value: Variant = source.get(key)
	assert_true(value is String)
	if value is String:
		var text: String = value
		return text
	return ""

func _component_spin(root: Node, component: String) -> SpinBox:
	var field: Node = root.find_child("Component_" + component, true, false)
	assert_not_null(field)
	if field != null:
		for child: Node in field.get_children():
			if child is SpinBox:
				var spin: SpinBox = child
				return spin
	assert_true(false, "数值分量应提供 SpinBox。")
	return null

func _make_table(resources: Array[Resource], manager: RecordingUndoManager) -> GFResourceTableEditor:
	var table: GFResourceTableEditor = GFResourceTableEditor.new()
	add_child_autofree(table)
	table.load_resources(resources)
	if table.has_method("set_editor_context") and manager != null:
		var context: GFEditorToolContext = GFEditorToolContext.new()
		context.undo_manager = manager
		var _result: Variant = table.call("set_editor_context", context)
	return table


func _select_rows_and_property(table: GFResourceTableEditor, property: StringName) -> bool:
	var tree: Tree = table.find_child("ResourceTree", true, false)
	var picker: OptionButton = table.find_child("MultiPropertyPicker", true, false)
	assert_not_null(tree, "表格应提供多行选择入口。")
	assert_not_null(picker, "表格应提供选中资源的属性编辑入口。")
	if tree == null or picker == null:
		return false
	var item: TreeItem = tree.get_root().get_first_child()
	while item != null:
		item.select(0)
		tree.multi_selected.emit(item, 0, true)
		item = item.get_next()
	for index: int in range(picker.item_count):
		if picker.get_item_text(index) == String(property):
			picker.select(index)
			picker.item_selected.emit(index)
			return true
	assert_true(false, "属性下拉列表应包含 %s。" % property)
	return false


func _press(table: GFResourceTableEditor, button_name: String) -> void:
	var button: Button = table.find_child(button_name, true, false)
	assert_not_null(button)
	if button != null:
		button.pressed.emit()


# --- 内部类 ---

class VectorResource extends Resource:
	@export var position: Vector2 = Vector2.ZERO
	@export var amount: int = 0


class DifferentResource extends Resource:
	@export var amount: String = "original"


class IntegerVectorResource extends Resource:
	@export var position: Vector3i = Vector3i.ZERO
	@export var values: Array[int] = [1]


class RejectingResource extends Resource:
	@export var amount: int = 0:
		set(_value):
			pass


class RecoverableResource extends Resource:
	var rejected_values: Dictionary = {}
	@export var amount: int = 0:
		set(value):
			if not rejected_values.has(value):
				amount = value


class RecordingUndoManager extends RefCounted:
	var command: GFEditorCommand = null
	var action_count: int = 0


	func create_action(_title: String) -> void:
		action_count += 1


	func add_do_method(target: Object, _method: String) -> void:
		if target is GFEditorCommand:
			command = target


	func add_undo_method(_target: Object, _method: String) -> void:
		pass


	func commit_action(execute_immediately: bool = true) -> void:
		if execute_immediately:
			var _error: Error = command.execute()
