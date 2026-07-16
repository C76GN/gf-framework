## 测试 GFVirtualListFocusModel 的虚拟焦点修正、跳过规则和环绕移动。
extends GutTest


# --- 常量 ---

const GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT = preload("res://addons/gf/standard/utilities/ui/gf_virtual_list_focus_model.gd")


# --- 测试方法 ---

func test_virtual_focus_model_keeps_focus_on_data_index() -> void:
	var model: GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT = GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.new()
	var _count_changed: bool = model.set_item_count(5)

	assert_true(model.set_focused_index(2), "应能聚焦合法数据索引。")
	assert_eq(model.focused_index, 2, "焦点应保存为数据索引，而不是 Control 节点引用。")
	assert_true(model.has_focus(), "设置焦点后应报告 has_focus。")

	var snapshot: Dictionary = model.get_debug_snapshot()
	assert_eq(GFVariantData.get_option_int(snapshot, "focused_index"), 2, "调试快照应包含当前焦点索引。")


func test_virtual_focus_model_skips_non_focusable_items() -> void:
	var model: GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT = GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.new()
	model.focusable_callback = func(item_index: int) -> bool:
		return item_index != 1 and item_index != 3
	var _count_changed: bool = model.set_item_count(5)
	var _focus_changed: bool = model.set_focused_index(0)

	assert_true(model.focus_next(), "下一个可聚焦索引应跳过不可聚焦条目。")
	assert_eq(model.focused_index, 2, "索引 1 不可聚焦时应移动到 2。")
	assert_true(model.focus_next(), "再次移动应继续跳过不可聚焦条目。")
	assert_eq(model.focused_index, 4, "索引 3 不可聚焦时应移动到 4。")
	assert_true(model.focus_previous(), "反向移动也应跳过不可聚焦条目。")
	assert_eq(model.focused_index, 2, "反向移动应回到 2。")


func test_virtual_focus_model_wraps_when_enabled() -> void:
	var model: GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT = GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.new()
	model.wrap_navigation = true
	var _count_changed: bool = model.set_item_count(3)
	var _focus_changed: bool = model.set_focused_index(2)

	assert_true(model.focus_next(), "启用环绕后末尾应移动到开头。")
	assert_eq(model.focused_index, 0, "末尾向后移动应环绕到 0。")
	assert_true(model.focus_previous(), "启用环绕后开头应移动到末尾。")
	assert_eq(model.focused_index, 2, "开头向前移动应环绕到末尾。")


func test_virtual_focus_model_stops_at_edges_without_wrap() -> void:
	var model: GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT = GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.new()
	var _count_changed: bool = model.set_item_count(2)
	var _focus_changed: bool = model.set_focused_index(1)

	assert_false(model.focus_next(), "未启用环绕时末尾继续向后不应移动。")
	assert_eq(model.focused_index, 1, "边界移动失败不应改变焦点。")


func test_virtual_focus_model_repairs_focus_when_count_shrinks() -> void:
	var model: GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT = GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.new()
	var _count_changed: bool = model.set_item_count(5)
	var _focus_changed: bool = model.set_focused_index(4)

	assert_true(model.set_item_count(3), "条目数量收缩并修正焦点时应报告变化。")
	assert_eq(model.focused_index, 2, "越界焦点应修正到最近可用索引。")


func test_configure_repairs_focus_after_focusable_callback_changes() -> void:
	var model: GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT = GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.new()
	var _configured: GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT = model.configure(5, {"focused_index": 2})

	_configured = model.configure(5, {
		"focusable_callback": func(item_index: int) -> bool:
			return item_index != 2
	})

	assert_eq(model.focused_index, 3, "原焦点失效后 configure 应原子修正到最近可聚焦索引。")
	assert_true(model.is_focusable(model.focused_index), "configure 返回时焦点不变量应已经恢复。")


func test_virtual_focus_model_auto_focuses_only_when_enabled() -> void:
	var model: GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT = GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.new()
	model.focusable_callback = func(item_index: int) -> bool:
		return item_index > 0

	var _count_changed: bool = model.set_item_count(3)
	assert_eq(model.focused_index, GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.NO_FOCUS, "默认不应自动决定初始焦点。")

	model.auto_focus_on_count_change = true
	assert_true(model.repair_focus(), "启用自动聚焦后应能修正到第一个可聚焦项。")
	assert_eq(model.focused_index, 1, "自动聚焦应跳过不可聚焦项。")


func test_virtual_focus_model_clears_when_no_focusable_items() -> void:
	var model: GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT = GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.new()
	model.focusable_callback = func(_item_index: int) -> bool:
		return false
	var _count_changed: bool = model.set_item_count(3)

	assert_false(model.set_focused_index(0), "不可聚焦索引不应被接受。")
	assert_eq(model.focused_index, GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.NO_FOCUS, "没有可聚焦项时应保持无焦点。")
	assert_false(model.focus_next(), "没有可聚焦项时移动不应改变状态。")


func test_virtual_focus_model_emits_signal_only_on_change() -> void:
	var model: GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT = GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.new()
	var _count_changed: bool = model.set_item_count(3)
	watch_signals(model)

	assert_true(model.set_focused_index(1), "首次设置焦点应变化。")
	assert_false(model.set_focused_index(1), "重复设置相同焦点不应变化。")
	assert_true(model.clear_focus(), "清空焦点应变化。")

	assert_signal_emit_count(model, "focused_index_changed", 2)
	assert_signal_emitted_with_parameters(
		model,
		"focused_index_changed",
		[GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.NO_FOCUS, 1],
		0
	)
	assert_signal_emitted_with_parameters(
		model,
		"focused_index_changed",
		[1, GF_VIRTUAL_LIST_FOCUS_MODEL_SCRIPT.NO_FOCUS],
		1
	)
