# 验证运行期编辑边界、原文与过期回调，不引入业务模型或验证规则。
extends GutTest


# --- 私有变量 ---

var _controls: Array[Control] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for control: Control in _controls:
		if is_instance_valid(control):
			control.free()
	_controls.clear()


# --- 公共方法 ---

func test_repeated_begin_keeps_baseline_and_commit_only_once() -> void:
	var field: LineEdit = _line_edit("before")
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.text = "intermediate"
	assert_eq(session.begin_edit(field), token)
	field.text = "after"
	var result: Dictionary = session.commit_edit(token)
	assert_true(GFVariantData.get_option_bool(result, "changed"))
	assert_eq(_raw_text(GFVariantData.get_option_dictionary(result, "before")), "before")
	assert_eq(_raw_text(GFVariantData.get_option_dictionary(result, "after")), "after")
	assert_false(session.is_current(token))
	assert_true(session.commit_edit(token).is_empty())
	assert_eq(field.text, "after", "结束边界不代替项目写模型。")


func test_spinbox_keeps_invalid_raw_text_and_cancel_restores_exact_baseline() -> void:
	var field: SpinBox = SpinBox.new()
	_controls.append(field)
	add_child(field)
	await wait_process_frames(1)
	field.value = 42.0
	field.get_line_edit().text = "0042.0"
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.get_line_edit().text = "-"
	var draft: Dictionary = session.capture_draft(token)
	assert_eq(_raw_text(draft), "-")
	assert_has(draft, "value")
	var draft_value: Variant = draft.get("value")
	assert_true(draft_value is float)
	if draft_value is float:
		var numeric_value: float = draft_value
		assert_eq(numeric_value, 42.0)
	field.value = 13.0
	field.get_line_edit().text = "-"
	assert_true(session.cancel_edit(token))
	await wait_process_frames(1)
	assert_eq(field.value, 42.0)
	assert_eq(field.get_line_edit().text, "0042.0")
	assert_false(session.cancel_edit(token))


func test_stale_deferred_completion_cannot_end_new_session() -> void:
	var field: LineEdit = _line_edit("old")
	var session: GFControlEditSession = GFControlEditSession.new()
	var old_token: int = session.begin_edit(field)
	session.clear()
	field.text = "new"
	var new_token: int = session.begin_edit(field)
	field.text = "draft"
	assert_true(session.commit_edit(old_token).is_empty())
	assert_false(session.cancel_edit(old_token))
	assert_true(session.is_current(new_token))
	assert_eq(_raw_text(session.get_baseline(new_token)), "new")
	assert_true(session.cancel_edit(new_token))
	assert_eq(field.text, "new")


func test_no_net_change_returns_success_without_changed_intent() -> void:
	var field: LineEdit = _line_edit("same")
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.text = "preview"
	field.text = "same"
	var result: Dictionary = session.commit_edit(token)
	assert_false(result.is_empty())
	assert_false(GFVariantData.get_option_bool(result, "changed", true))
	assert_false(session.is_current(token))


func test_snapshots_are_independent_and_another_field_cannot_replace_baseline() -> void:
	var field: LineEdit = _line_edit("first")
	var other: LineEdit = _line_edit("second")
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	var snapshot: Dictionary = session.get_baseline(token)
	snapshot["raw_text"] = "mutated"
	assert_eq(session.begin_edit(other), 0)
	assert_eq(_raw_text(session.get_baseline(token)), "first")
	assert_eq(_raw_text(session.capture_draft(token)), "first")


func test_freeing_control_invalidates_old_token_without_retaining_node() -> void:
	var field: LineEdit = LineEdit.new()
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.free()
	assert_false(session.is_current(token))
	assert_true(session.capture_draft(token).is_empty())
	assert_false(session.cancel_edit(token))
	var replacement: LineEdit = _line_edit("replacement")
	assert_gt(session.begin_edit(replacement), token)


func test_cancel_blocks_reentrant_begin_and_can_be_invalidated_by_owner() -> void:
	var field: SpinBox = SpinBox.new()
	_controls.append(field)
	add_child(field)
	await wait_process_frames(1)
	field.value = 5.0
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.value = 10.0
	var observed: Array[int] = []
	var connection_result: int = field.value_changed.connect(func(_value: float) -> void:
		observed.append(session.begin_edit(field))
		session.clear()
	)
	assert_eq(connection_result, OK)
	assert_false(session.cancel_edit(token), "宿主 clear 可使恢复中的会话失效。")
	assert_eq(observed, [0])
	assert_false(session.is_current(token))


func test_unsupported_controls_do_not_create_session() -> void:
	var field: Control = Control.new()
	_controls.append(field)
	var session: GFControlEditSession = GFControlEditSession.new()
	assert_eq(session.begin_edit(field), 0)
	assert_eq(session.begin_edit(null), 0)


func test_text_edit_uses_raw_text_and_cancel_restores_multiline_draft() -> void:
	var field: TextEdit = TextEdit.new()
	_controls.append(field)
	field.text = "first\nsecond"
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	assert_false(session.has_ime_composition(token))
	field.text = "first\nunfinished"
	assert_eq(_raw_text(session.capture_draft(token)), "first\nunfinished")
	assert_true(session.cancel_edit(token))
	assert_eq(field.text, "first\nsecond")
	assert_false(session.has_ime_composition(token))


func test_item_list_baseline_selection_is_independent_and_cancel_restores_selection() -> void:
	var field: ItemList = ItemList.new()
	_controls.append(field)
	field.select_mode = ItemList.SELECT_MULTI
	var _first_index: int = field.add_item("first")
	var _second_index: int = field.add_item("second")
	var _third_index: int = field.add_item("third")
	field.select(0, false)
	field.select(1, false)
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	var snapshot: Dictionary = session.get_baseline(token)
	var selection: Variant = snapshot["value"]
	if selection is PackedInt32Array:
		var detached: PackedInt32Array = selection
		detached[0] = 2
	var fresh_baseline: Dictionary = session.get_baseline(token)
	assert_has(fresh_baseline, "value")
	var fresh_selection: Variant = fresh_baseline.get("value")
	assert_true(fresh_selection is PackedInt32Array)
	if fresh_selection is PackedInt32Array:
		var typed_selection: PackedInt32Array = fresh_selection
		assert_eq(typed_selection, PackedInt32Array([0, 1]))
	field.deselect_all()
	field.select(2)
	assert_true(session.cancel_edit(token))
	assert_eq(field.get_selected_items(), PackedInt32Array([0, 1]))


func test_deferred_spinbox_cancel_cannot_overwrite_a_new_edit() -> void:
	var field: SpinBox = SpinBox.new()
	_controls.append(field)
	add_child(field)
	await wait_process_frames(1)
	field.value = 42.0
	await wait_process_frames(1)
	field.get_line_edit().text = "0042"
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.get_line_edit().text = "unfinished"
	assert_true(session.cancel_edit(token))
	var next_token: int = session.begin_edit(field)
	field.get_line_edit().text = "new draft"
	assert_true(session.is_current(next_token))
	await wait_process_frames(1)
	assert_eq(field.get_line_edit().text, "new draft")


func test_line_edit_native_text_assignment_does_not_emit_text_changed() -> void:
	var field: LineEdit = _line_edit("before")
	add_child(field)
	await wait_process_frames(1)
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	var observed: Array[String] = []
	var connection_result: int = field.text_changed.connect(func(text: String) -> void:
		observed.append(text)
		session.clear()
	)
	assert_eq(connection_result, OK)
	field.text = "draft"
	await wait_process_frames(1)
	assert_eq(observed, [], "真实 LineEdit.text 赋值不发 text_changed，不能模拟该信号制造重入。")
	assert_true(session.is_current(token))
	assert_true(session.cancel_edit(token))
	await wait_process_frames(1)
	assert_eq(observed, [])
	assert_eq(field.text, "before")


func test_spinbox_cancel_rejects_baseline_clamped_by_new_maximum() -> void:
	var field: SpinBox = await _spin_box(42.0, "0042")
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.max_value = 10.0
	field.get_line_edit().text = "unfinished"
	assert_false(session.cancel_edit(token), "新上限无法恢复数值基线，不得报告成功或回填旧原文。")
	await wait_process_frames(1)
	assert_eq(field.value, 10.0)
	assert_eq(field.get_line_edit().text, "10")
	assert_false(session.is_current(token))


func test_range_cancel_rejects_baseline_rounded_by_new_step() -> void:
	var field: HSlider = HSlider.new()
	_controls.append(field)
	field.step = 1.0
	field.value = 5.0
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.value = 12.0
	field.step = 2.0
	assert_false(session.cancel_edit(token), "Range 的新步长将基线吸附到另一数值，恢复必须失败。")
	assert_eq(field.value, 6.0)
	assert_false(session.is_current(token))


func test_option_button_cancel_rejects_removed_baseline_choice() -> void:
	var field: OptionButton = OptionButton.new()
	_controls.append(field)
	field.add_item("first")
	field.add_item("second")
	field.add_item("removed")
	field.select(2)
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.select(0)
	field.remove_item(2)
	assert_false(session.cancel_edit(token), "已移除的选项无法恢复，不应调用越界的原生 setter。")
	assert_eq(field.selected, 0)
	assert_eq(field.text, "first")
	assert_false(session.is_current(token))


func test_item_list_cancel_rejects_partly_removed_baseline_without_partial_restore() -> void:
	var field: ItemList = ItemList.new()
	_controls.append(field)
	field.select_mode = ItemList.SELECT_MULTI
	var _first_index: int = field.add_item("first")
	var _second_index: int = field.add_item("current")
	var _third_index: int = field.add_item("removed")
	field.select(0, false)
	field.select(2, false)
	assert_eq(field.get_selected_items(), PackedInt32Array([0, 2]))
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.deselect_all()
	field.select(1)
	field.remove_item(2)
	assert_eq(field.get_selected_items(), PackedInt32Array([1]))
	assert_false(session.cancel_edit(token), "基线只有部分索引有效，须在清空或部分写入当前选择前拒绝。")
	assert_eq(field.get_selected_items(), PackedInt32Array([1]))
	assert_false(session.is_current(token))


func test_spinbox_cancel_rejects_value_replaced_by_native_signal_callback() -> void:
	var field: SpinBox = await _spin_box(42.0, "0042")
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.value = 13.0
	var observed: Array[float] = []
	var connection_result: int = field.value_changed.connect(func(value: float) -> void:
		observed.append(value)
		if value == 42.0:
			field.value = 73.0
	)
	assert_eq(connection_result, OK)
	assert_false(session.cancel_edit(token), "真实 value_changed 回调覆写恢复值后，后置条件不再成立。")
	assert_eq(observed, [42.0, 73.0])
	await wait_process_frames(1)
	assert_eq(field.value, 73.0)
	assert_eq(field.get_line_edit().text, "73")
	assert_false(session.is_current(token))


func test_deferred_spinbox_cancel_cannot_overwrite_later_native_value_update() -> void:
	var field: SpinBox = await _spin_box(42.0, "0042")
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	field.value = 13.0
	field.get_line_edit().text = "unfinished"
	assert_true(session.cancel_edit(token))
	field.value = 73.0
	await wait_process_frames(1)
	assert_eq(field.value, 73.0)
	assert_eq(field.get_line_edit().text, "73", "会话已结束后的原生值更新不得被旧延期原文覆盖。")
	assert_false(session.is_current(token))


func test_spinbox_cancel_returns_false_when_native_raw_rejection_clears_owner() -> void:
	var field: SpinBox = await _spin_box(42.0, "0042")
	var editor: LineEdit = field.get_line_edit()
	var session: GFControlEditSession = GFControlEditSession.new()
	var token: int = session.begin_edit(field)
	editor.max_length = 2
	field.value = 13.0
	await wait_process_frames(1)
	editor.text = "1"
	var rejected: Array[String] = []
	var blocked_begin: Array[int] = []
	var connection_result: int = editor.text_change_rejected.connect(func(text: String) -> void:
		rejected.append(text)
		blocked_begin.append(session.begin_edit(field))
		session.clear()
	)
	assert_eq(connection_result, OK)
	assert_false(session.cancel_edit(token), "真实原文截断回调已 clear，取消必须复核恢复后的所有权。")
	assert_eq(rejected, ["42"], "信号来自 max_length 拒绝旧 raw 的尾部，未人为 emit。")
	assert_eq(blocked_begin, [0])
	assert_false(session.is_current(token))
	var replacement: LineEdit = _line_edit("replacement")
	var next_token: int = session.begin_edit(replacement)
	assert_gt(next_token, token)
	await wait_process_frames(1)
	assert_true(session.is_current(next_token))
	assert_eq(replacement.text, "replacement")


# --- 私有/辅助方法 ---

func _raw_text(snapshot: Dictionary) -> String:
	assert_has(snapshot, "raw_text")
	var value: Variant = snapshot.get("raw_text")
	assert_true(value is String)
	if value is String:
		var text: String = value
		return text
	return ""


func _line_edit(text: String) -> LineEdit:
	var field: LineEdit = LineEdit.new()
	field.text = text
	_controls.append(field)
	return field


func _spin_box(value: float, raw_text: String) -> SpinBox:
	var field: SpinBox = SpinBox.new()
	_controls.append(field)
	add_child(field)
	field.value = value
	await wait_process_frames(1)
	field.get_line_edit().text = raw_text
	return field
