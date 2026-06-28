## 测试 GFItemListBinder 的通用条目控件绑定行为。
extends GutTest


# --- 常量 ---

const GF_REACTIVE_STATE_STORE_SCRIPT = preload("res://addons/gf/standard/utilities/state/gf_reactive_state_store.gd")
const GF_ITEM_LIST_BINDER_SCRIPT = preload("res://addons/gf/standard/utilities/ui/gf_item_list_binder.gd")


# --- 私有变量 ---

var _nodes: Array[Node] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


# --- 测试方法 ---

func test_write_items_populates_item_list_with_metadata_and_selection() -> void:
	var item_list: ItemList = ItemList.new()
	_track_node(item_list)

	var written_count: int = GF_ITEM_LIST_BINDER_SCRIPT.write_items(item_list, [
		{
			"id": &"alpha",
			"text": "Alpha",
			"disabled": true,
		},
		{
			"id": &"beta",
			"label": "Beta",
			"selected": true,
			"tooltip": "Second item",
		},
	])

	assert_eq(written_count, 2, "应写入两个条目。")
	assert_eq(item_list.item_count, 2, "ItemList 应包含两个条目。")
	assert_eq(item_list.get_item_text(0), "Alpha", "text 字段应作为显示文本。")
	assert_true(item_list.is_item_disabled(0), "disabled 字段应写入 ItemList。")
	assert_eq(item_list.get_item_tooltip(1), "Second item", "tooltip 字段应写入 ItemList。")
	var alpha_metadata: Variant = GF_ITEM_LIST_BINDER_SCRIPT.get_item_metadata(item_list, 0)
	assert_eq(GFVariantData.to_string_name(alpha_metadata), &"alpha", "metadata 默认应使用 id。")
	assert_eq(GF_ITEM_LIST_BINDER_SCRIPT.get_selected_metadata(item_list), [&"beta"], "selected 字段应选中条目。")


func test_write_items_populates_option_button_and_selected_metadata() -> void:
	var option_button: OptionButton = OptionButton.new()
	_track_node(option_button)

	var written_count: int = GF_ITEM_LIST_BINDER_SCRIPT.write_items(option_button, [
		{
			"id": 10,
			"text": "Low",
		},
		{
			"id": 20,
			"text": "High",
			"selected": true,
		},
	])

	assert_eq(written_count, 2, "应写入两个 OptionButton 条目。")
	assert_eq(option_button.item_count, 2, "OptionButton 应包含两个条目。")
	assert_eq(option_button.selected, 1, "selected 字段应选择对应索引。")
	assert_eq(GF_ITEM_LIST_BINDER_SCRIPT.get_selected_metadata(option_button), [20], "OptionButton 应返回选中 metadata。")


func test_bind_items_updates_target_from_store_path() -> void:
	var store: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({
		"items": [
			{
				"id": &"first",
				"text": "First",
			},
		],
	})
	var binder: GF_ITEM_LIST_BINDER_SCRIPT = GF_ITEM_LIST_BINDER_SCRIPT.new()
	var option_button: OptionButton = OptionButton.new()
	_track_node(option_button)

	assert_true(binder.bind_items(store, "items", option_button), "有效 store 和目标控件应绑定成功。")
	assert_eq(option_button.get_item_text(0), "First", "初始同步应写入 store 中的条目。")

	var _set_result: bool = store.set_value("items", [
		{
			"id": &"second",
			"text": "Second",
			"selected": true,
		},
	])

	assert_eq(option_button.item_count, 1, "store 路径变化应重建目标条目。")
	assert_eq(option_button.get_item_text(0), "Second", "目标控件应显示新条目。")
	assert_eq(GF_ITEM_LIST_BINDER_SCRIPT.get_selected_metadata(option_button), [&"second"], "新条目选择状态应同步。")
	assert_eq(binder.get_binding_count(), 1, "绑定应保持有效。")


func test_target_tree_exit_clears_binding_and_store_subscription() -> void:
	var store: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({
		"items": [],
	})
	var binder: GF_ITEM_LIST_BINDER_SCRIPT = GF_ITEM_LIST_BINDER_SCRIPT.new()
	var item_list: ItemList = ItemList.new()
	add_child(item_list)
	_nodes.append(item_list)

	var _bind_result: bool = binder.bind_items(store, "items", item_list)
	remove_child(item_list)
	item_list.tree_exited.emit()

	assert_eq(binder.get_binding_count(), 0, "目标退出场景树后 binder 应清理绑定。")
	assert_eq(store.get_subscription_count(), 0, "目标退出场景树后 store 订阅也应清理。")


# --- 私有/辅助方法 ---

func _track_node(node: Node) -> void:
	_nodes.append(node)
