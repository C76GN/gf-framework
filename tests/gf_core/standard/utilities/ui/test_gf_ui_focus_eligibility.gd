# 通过公开 UI 栈验证自动聚焦的资格、实际结果与回调重入。
extends GutTest


# --- 私有变量 ---

var _ui: GFUIUtility


# --- 公共方法 ---

func before_each() -> void:
	_ui = GFUIUtility.new()
	_ui.init()
	await get_tree().process_frame


func after_each() -> void:
	_ui.dispose()
	_ui = null
	await get_tree().process_frame


func test_recovery_skips_hidden_ancestors_in_both_tree_orders() -> void:
	for hidden_first: bool in [true, false]:
		var outside: LineEdit = _make_outside_input()
		var panel: Control = Control.new()
		var hidden_branch: VBoxContainer = VBoxContainer.new()
		var hidden_input: LineEdit = LineEdit.new()
		var visible_input: LineEdit = LineEdit.new()
		hidden_branch.visible = false
		hidden_branch.add_child(hidden_input)
		panel.add_child(hidden_branch)
		panel.add_child(visible_input)
		if not hidden_first:
			panel.move_child(visible_input, 0)
		_ui.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
			"modal": true,
			"focus_on_open": false,
		})
		outside.grab_focus()
		assert_same(get_viewport().gui_get_focus_owner(), outside)
		assert_true(hidden_input.visible)
		assert_false(hidden_input.is_visible_in_tree())
		assert_true(visible_input.is_visible_in_tree())

		assert_true(_ui.keep_focus_inside_top_modal())
		assert_same(get_viewport().gui_get_focus_owner(), visible_input)
		assert_false(_ui.keep_focus_inside_top_modal(), "有效焦点不需要再次修正。")
		await get_tree().process_frame
		assert_same(get_viewport().gui_get_focus_owner(), visible_input)
		_ui.pop_panel(GFUIUtility.Layer.POPUP)
		await get_tree().process_frame


func test_open_focus_runs_after_panel_becomes_visible() -> void:
	var panel: Control = Control.new()
	var hidden_branch: VBoxContainer = VBoxContainer.new()
	var hidden_input: LineEdit = LineEdit.new()
	var visible_input: LineEdit = LineEdit.new()
	panel.visible = false
	hidden_branch.visible = false
	hidden_branch.add_child(hidden_input)
	panel.add_child(hidden_branch)
	panel.add_child(visible_input)

	_ui.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"focus_on_open": true,
	})

	assert_true(panel.is_visible_in_tree())
	assert_false(hidden_input.is_visible_in_tree())
	assert_same(get_viewport().gui_get_focus_owner(), visible_input)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), visible_input)


func test_recovery_without_eligible_targets_does_not_claim_success() -> void:
	var outside: LineEdit = _make_outside_input()
	var panel: Control = Control.new()
	var hidden_branch: VBoxContainer = VBoxContainer.new()
	hidden_branch.visible = false
	hidden_branch.add_child(LineEdit.new())
	panel.add_child(hidden_branch)
	_ui.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"focus_on_open": false,
	})
	outside.grab_focus()

	assert_false(_ui.keep_focus_inside_top_modal())
	assert_same(get_viewport().gui_get_focus_owner(), outside)


func test_recovery_rechecks_effective_visibility_of_current_focus() -> void:
	var panel: Control = Control.new()
	var hidden_branch: VBoxContainer = VBoxContainer.new()
	var hidden_input: LineEdit = LineEdit.new()
	var visible_input: LineEdit = LineEdit.new()
	hidden_branch.visible = false
	hidden_branch.add_child(hidden_input)
	panel.add_child(hidden_branch)
	panel.add_child(visible_input)
	_ui.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"focus_on_open": false,
	})
	hidden_input.grab_focus()
	assert_same(get_viewport().gui_get_focus_owner(), hidden_input, "复现引擎允许显式聚焦隐藏祖先下的控件。")
	assert_false(hidden_input.is_visible_in_tree())

	assert_true(_ui.keep_focus_inside_top_modal())
	assert_same(get_viewport().gui_get_focus_owner(), visible_input)


func test_recovery_skips_disabled_and_recursively_disabled_targets() -> void:
	var outside: LineEdit = _make_outside_input()
	var panel: Control = Control.new()
	var disabled_button: Button = Button.new()
	var disabled_branch: Control = Control.new()
	var visible_input: LineEdit = LineEdit.new()
	disabled_button.disabled = true
	disabled_branch.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	disabled_branch.add_child(LineEdit.new())
	panel.add_child(disabled_button)
	panel.add_child(disabled_branch)
	panel.add_child(visible_input)
	_ui.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"focus_on_open": false,
	})
	outside.grab_focus()

	assert_true(_ui.keep_focus_inside_top_modal())
	assert_same(get_viewport().gui_get_focus_owner(), visible_input)


func test_recovery_does_not_claim_success_when_callback_hides_target() -> void:
	var outside: LineEdit = _make_outside_input()
	var panel: Control = Control.new()
	var rejecting_input: LineEdit = LineEdit.new()
	panel.add_child(rejecting_input)
	_ui.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"focus_on_open": false,
	})
	var _connected: int = rejecting_input.focus_entered.connect(
		rejecting_input.hide,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	)
	outside.grab_focus()

	assert_false(_ui.keep_focus_inside_top_modal())
	assert_false(rejecting_input.is_visible_in_tree())


func test_recovery_preserves_replacement_modal_opened_by_focus_callback() -> void:
	var outside: LineEdit = _make_outside_input()
	var panel: Control = Control.new()
	var replacing_input: LineEdit = LineEdit.new()
	var stale_sibling: LineEdit = LineEdit.new()
	var replacement: Control = Control.new()
	var replacement_input: LineEdit = LineEdit.new()
	panel.add_child(replacing_input)
	panel.add_child(stale_sibling)
	replacement.add_child(replacement_input)
	_ui.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"focus_on_open": false,
	})
	var replace_modal: Callable = func() -> void:
		_ui.pop_panel(GFUIUtility.Layer.POPUP)
		_ui.push_panel_instance_with_options(replacement, GFUIUtility.Layer.POPUP, {
			"modal": true,
			"focus_on_open": true,
		})
	var _connected: int = replacing_input.focus_entered.connect(
		replace_modal,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	)
	outside.grab_focus()

	assert_false(_ui.keep_focus_inside_top_modal(), "原目标已关闭，不能把替代面板的焦点算作原请求成功。")
	assert_same(_ui.get_top_panel(GFUIUtility.Layer.POPUP), replacement)
	assert_same(get_viewport().gui_get_focus_owner(), replacement_input)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), replacement_input)


func test_recovery_continues_after_callback_queues_target_for_deletion() -> void:
	var outside: LineEdit = _make_outside_input()
	var panel: Control = Control.new()
	var discarded_input: LineEdit = LineEdit.new()
	var visible_input: LineEdit = LineEdit.new()
	panel.add_child(discarded_input)
	panel.add_child(visible_input)
	_ui.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"focus_on_open": false,
	})
	var _connected: int = discarded_input.focus_entered.connect(
		discarded_input.queue_free,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	)
	outside.grab_focus()

	assert_true(_ui.keep_focus_inside_top_modal())
	assert_same(get_viewport().gui_get_focus_owner(), visible_input)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), visible_input)


func test_recovery_continues_after_callback_queues_target_ancestor_for_deletion() -> void:
	var outside: LineEdit = _make_outside_input()
	var panel: Control = Control.new()
	var discarded_branch: VBoxContainer = VBoxContainer.new()
	var discarded_input: LineEdit = LineEdit.new()
	var visible_input: LineEdit = LineEdit.new()
	discarded_branch.add_child(discarded_input)
	panel.add_child(discarded_branch)
	panel.add_child(visible_input)
	_ui.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"focus_on_open": false,
	})
	var _connected: int = discarded_input.focus_entered.connect(
		discarded_branch.queue_free,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	)
	outside.grab_focus()

	assert_true(_ui.keep_focus_inside_top_modal())
	assert_same(get_viewport().gui_get_focus_owner(), visible_input)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), visible_input)


func test_recovery_rechecks_queued_ancestor_of_current_focus() -> void:
	var panel: Control = Control.new()
	var discarded_branch: VBoxContainer = VBoxContainer.new()
	var discarded_input: LineEdit = LineEdit.new()
	var visible_input: LineEdit = LineEdit.new()
	discarded_branch.add_child(discarded_input)
	panel.add_child(discarded_branch)
	panel.add_child(visible_input)
	_ui.push_panel_instance_with_options(panel, GFUIUtility.Layer.POPUP, {
		"modal": true,
		"focus_on_open": false,
	})
	discarded_input.grab_focus()
	discarded_branch.queue_free()
	assert_same(get_viewport().gui_get_focus_owner(), discarded_input)
	assert_true(discarded_input.is_visible_in_tree())
	assert_false(discarded_input.is_queued_for_deletion())

	assert_true(_ui.keep_focus_inside_top_modal())
	assert_same(get_viewport().gui_get_focus_owner(), visible_input)
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), visible_input)


# --- 私有/辅助方法 ---

func _make_outside_input() -> LineEdit:
	var input: LineEdit = LineEdit.new()
	add_child_autofree(input)
	return input
