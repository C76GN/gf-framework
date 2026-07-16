## 测试 GFControlFocusUtility 的可聚焦控件收集、顺序写入和焦点步进。
extends GutTest


# --- 常量 ---

const GF_CONTROL_FOCUS_UTILITY_SCRIPT = preload("res://addons/gf/standard/utilities/ui/gf_control_focus_utility.gd")


# --- 测试方法 ---

func test_collect_focusable_controls_filters_hidden_disabled_and_focus_none() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	var active_button: Button = _make_button("Active")
	var hidden_button: Button = _make_button("Hidden")
	var disabled_button: Button = _make_button("Disabled")
	var label: Label = Label.new()
	hidden_button.visible = false
	disabled_button.disabled = true
	label.focus_mode = Control.FOCUS_NONE
	root.add_child(active_button)
	root.add_child(hidden_button)
	root.add_child(disabled_button)
	root.add_child(label)
	add_child_autofree(root)

	var controls: Array[Control] = GF_CONTROL_FOCUS_UTILITY_SCRIPT.collect_focusable_controls(root)

	assert_eq(controls, [active_button], "默认收集应排除隐藏、禁用和不可聚焦控件。")

	var inclusive_controls: Array[Control] = GF_CONTROL_FOCUS_UTILITY_SCRIPT.collect_focusable_controls(root, {
		"include_hidden": true,
		"include_disabled": true,
	})
	assert_eq(inclusive_controls, [active_button, hidden_button, disabled_button], "显式选项应允许隐藏和禁用控件进入顺序。")

	var limited_root: VBoxContainer = VBoxContainer.new()
	var limited_hidden_button: Button = _make_button("LimitedHidden")
	var limited_active_button: Button = _make_button("LimitedActive")
	limited_hidden_button.visible = false
	limited_root.add_child(limited_hidden_button)
	limited_root.add_child(limited_active_button)
	add_child_autofree(limited_root)

	var limited_controls: Array[Control] = GF_CONTROL_FOCUS_UTILITY_SCRIPT.collect_focusable_controls(limited_root, {
		"limit": 1,
	})

	assert_eq(limited_controls, [limited_active_button], "limit 应作用于过滤后的可聚焦结果。")


func test_apply_focus_order_wires_tab_and_vertical_neighbors() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	var first_button: Button = _make_button("First")
	var second_button: Button = _make_button("Second")
	var third_button: Button = _make_button("Third")
	root.add_child(first_button)
	root.add_child(second_button)
	root.add_child(third_button)
	add_child_autofree(root)

	var report: Dictionary = GF_CONTROL_FOCUS_UTILITY_SCRIPT.apply_focus_order(
		[first_button, second_button, third_button],
		{ "axis": GF_CONTROL_FOCUS_UTILITY_SCRIPT.AXIS_VERTICAL }
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效控件顺序应成功应用。")
	assert_eq(GFVariantData.get_option_int(report, "control_count"), 3, "报告应记录实际控件数量。")
	assert_eq(_resolve_focus_path(first_button, first_button.focus_next), second_button, "第一个控件的 Tab 下一项应指向第二个控件。")
	assert_eq(_resolve_focus_path(first_button, first_button.focus_previous), third_button, "循环顺序应把第一个控件的上一项指向最后一个控件。")
	assert_eq(_resolve_focus_path(second_button, second_button.focus_neighbor_top), first_button, "垂直上一项应指向前序控件。")
	assert_eq(_resolve_focus_path(second_button, second_button.focus_neighbor_bottom), third_button, "垂直下一项应指向后序控件。")
	assert_eq(_resolve_focus_path(third_button, third_button.focus_next), first_button, "最后一个控件的 Tab 下一项应循环到第一个控件。")


func test_apply_focus_order_without_wrap_clears_edge_paths() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	var first_button: Button = _make_button("First")
	var second_button: Button = _make_button("Second")
	root.add_child(first_button)
	root.add_child(second_button)
	add_child_autofree(root)

	var _report: Dictionary = GF_CONTROL_FOCUS_UTILITY_SCRIPT.apply_focus_order(
		[first_button, second_button],
		{
			"wrap": false,
			"axis": GF_CONTROL_FOCUS_UTILITY_SCRIPT.AXIS_HORIZONTAL,
		}
	)

	assert_eq(String(first_button.focus_previous), "", "不循环时首项 previous 应为空。")
	assert_eq(String(second_button.focus_next), "", "不循环时末项 next 应为空。")
	assert_eq(_resolve_focus_path(first_button, first_button.focus_neighbor_right), second_button, "水平右侧应指向后序控件。")
	assert_eq(_resolve_focus_path(second_button, second_button.focus_neighbor_left), first_button, "水平左侧应指向前序控件。")


func test_apply_focus_order_clears_unwired_directional_neighbors_by_default() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	var first_button: Button = _make_button("First")
	var second_button: Button = _make_button("Second")
	root.add_child(first_button)
	root.add_child(second_button)
	add_child_autofree(root)
	first_button.focus_neighbor_bottom = first_button.get_path_to(second_button)
	second_button.focus_neighbor_top = second_button.get_path_to(first_button)

	var report: Dictionary = GF_CONTROL_FOCUS_UTILITY_SCRIPT.apply_focus_order(
		[first_button, second_button],
		{ "axis": GF_CONTROL_FOCUS_UTILITY_SCRIPT.AXIS_HORIZONTAL }
	)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效控件顺序应成功应用。")
	assert_eq(String(first_button.focus_neighbor_bottom), "", "只布线水平轴时应清空旧 bottom 邻居。")
	assert_eq(String(second_button.focus_neighbor_top), "", "只布线水平轴时应清空旧 top 邻居。")

	first_button.focus_neighbor_bottom = first_button.get_path_to(second_button)
	second_button.focus_neighbor_top = second_button.get_path_to(first_button)

	var _preserved_report: Dictionary = GF_CONTROL_FOCUS_UTILITY_SCRIPT.apply_focus_order(
		[first_button, second_button],
		{
			"axis": GF_CONTROL_FOCUS_UTILITY_SCRIPT.AXIS_HORIZONTAL,
			"preserve_unwired_directional_neighbors": true,
		}
	)

	assert_eq(_resolve_focus_path(first_button, first_button.focus_neighbor_bottom), second_button, "显式 preserve 时应保留旧 bottom 邻居。")
	assert_eq(_resolve_focus_path(second_button, second_button.focus_neighbor_top), first_button, "显式 preserve 时应保留旧 top 邻居。")


func test_apply_focus_order_from_root_uses_tree_order() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	var first_button: Button = _make_button("First")
	var nested: HBoxContainer = HBoxContainer.new()
	var second_button: Button = _make_button("Second")
	var third_button: Button = _make_button("Third")
	root.add_child(first_button)
	root.add_child(nested)
	nested.add_child(second_button)
	root.add_child(third_button)
	add_child_autofree(root)

	var report: Dictionary = GF_CONTROL_FOCUS_UTILITY_SCRIPT.apply_focus_order_from_root(root, {
		"axis": GF_CONTROL_FOCUS_UTILITY_SCRIPT.AXIS_NONE,
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "从根节点收集并应用应成功。")
	assert_eq(_resolve_focus_path(first_button, first_button.focus_next), second_button, "根节点收集应保持场景树深度优先顺序。")
	assert_eq(_resolve_focus_path(second_button, second_button.focus_next), third_button, "嵌套控件后应继续回到后续同级控件。")
	assert_eq(String(first_button.focus_neighbor_right), "", "axis none 不应写入方向邻居。")


func test_get_and_grab_next_focus_control_respects_step_and_wrap() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	var first_button: Button = _make_button("First")
	var second_button: Button = _make_button("Second")
	var third_button: Button = _make_button("Third")
	root.add_child(first_button)
	root.add_child(second_button)
	root.add_child(third_button)
	add_child_autofree(root)
	var controls: Array[Control] = [first_button, second_button, third_button]

	assert_eq(GF_CONTROL_FOCUS_UTILITY_SCRIPT.get_next_focus_control(controls, second_button), third_button, "正向步进应返回后一项。")
	assert_eq(GF_CONTROL_FOCUS_UTILITY_SCRIPT.get_next_focus_control(controls, first_button, -1), third_button, "循环反向步进应返回末项。")
	assert_null(GF_CONTROL_FOCUS_UTILITY_SCRIPT.get_next_focus_control(controls, first_button, -1, false), "不循环时越界应返回 null。")

	var focused_control: Control = GF_CONTROL_FOCUS_UTILITY_SCRIPT.grab_next_focus(controls, third_button, 1, true)

	assert_eq(focused_control, first_button, "抓取焦点应返回循环后的目标控件。")
	assert_eq(get_viewport().gui_get_focus_owner(), first_button, "目标控件应获得 Godot GUI 焦点。")


# --- 私有/辅助方法 ---

func _make_button(control_name: String) -> Button:
	var button: Button = Button.new()
	button.name = control_name
	button.focus_mode = Control.FOCUS_ALL
	return button


func _resolve_focus_path(source: Control, path: NodePath) -> Control:
	if source == null or String(path).is_empty():
		return null
	var node: Node = source.get_node_or_null(path)
	if node is Control:
		var control: Control = node
		return control
	return null
