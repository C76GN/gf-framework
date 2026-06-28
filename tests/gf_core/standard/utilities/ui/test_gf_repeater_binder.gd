## 测试 GFRepeaterBinder 的模板重复渲染绑定行为。
extends GutTest


# --- 常量 ---

const GF_REACTIVE_STATE_STORE_SCRIPT = preload("res://addons/gf/standard/utilities/state/gf_reactive_state_store.gd")
const GF_REPEATER_BINDER_SCRIPT = preload("res://addons/gf/standard/utilities/ui/gf_repeater_binder.gd")


# --- 私有变量 ---

var _nodes: Array[Node] = []


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


# --- 测试方法 ---

func test_rebuild_container_duplicates_template_and_clears_previous_clones() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: Label = Label.new()
	container.add_child(template)
	_track_node(container)

	var first_nodes: Array[Node] = GF_REPEATER_BINDER_SCRIPT.rebuild_container(container, template, [
		{
			"text": "Alpha",
		},
		{
			"label": "Beta",
		},
	])
	var first_label: Label = _as_label(first_nodes[0])
	var second_label: Label = _as_label(first_nodes[1])

	assert_false(template.visible, "默认应隐藏模板节点。")
	assert_eq(first_nodes.size(), 2, "应创建两个模板副本。")
	assert_eq(first_label.text, "Alpha", "text 字段应写入副本文本。")
	assert_eq(second_label.text, "Beta", "label 字段应作为文本回退。")
	assert_true(GFVariantData.to_bool(first_label.get_meta(GF_REPEATER_BINDER_SCRIPT.META_CLONE)), "副本应带 repeater 标记。")

	var second_nodes: Array[Node] = GF_REPEATER_BINDER_SCRIPT.rebuild_container(container, template, ["Gamma"])
	var third_label: Label = _as_label(second_nodes[0])

	assert_eq(second_nodes.size(), 1, "第二次重建应只创建当前数据对应副本。")
	assert_eq(container.get_child_count(), 2, "旧副本应立即从容器移除，只保留模板和新副本。")
	assert_eq(third_label.text, "Gamma", "标量条目应转换为文本。")


func test_rebuild_container_uses_configure_callable() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: Label = Label.new()
	container.add_child(template)
	_track_node(container)

	var created_nodes: Array[Node] = GF_REPEATER_BINDER_SCRIPT.rebuild_container(container, template, [
		{
			"name": "Ada",
		},
	], {
		"configure_callable": Callable(self, "_configure_label"),
	})
	var label: Label = _as_label(created_nodes[0])

	assert_eq(label.text, "0:Ada", "configure_callable 应能覆盖默认文本。")


func test_bind_repeater_updates_container_from_store_path() -> void:
	var store: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({
		"rows": [
			{
				"text": "Initial",
			},
		],
	})
	var binder: GF_REPEATER_BINDER_SCRIPT = GF_REPEATER_BINDER_SCRIPT.new()
	var container: VBoxContainer = VBoxContainer.new()
	var template: Label = Label.new()
	container.add_child(template)
	_track_node(container)

	assert_true(binder.bind_repeater(store, "rows", container, template), "有效 store、容器和模板应绑定成功。")
	assert_eq(_as_label(container.get_child(1)).text, "Initial", "初始同步应创建模板副本。")

	var _set_result: bool = store.set_value("rows", [
		{
			"text": "Updated",
		},
		{
			"text": "Second",
		},
	])

	assert_eq(container.get_child_count(), 3, "store 路径变化应重建副本。")
	assert_eq(_as_label(container.get_child(1)).text, "Updated", "第一个副本应同步新数据。")
	assert_eq(_as_label(container.get_child(2)).text, "Second", "第二个副本应同步新数据。")
	assert_eq(binder.get_binding_count(), 1, "绑定应保持有效。")


func test_container_tree_exit_clears_binding_and_store_subscription() -> void:
	var store: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({
		"rows": [],
	})
	var binder: GF_REPEATER_BINDER_SCRIPT = GF_REPEATER_BINDER_SCRIPT.new()
	var container: VBoxContainer = VBoxContainer.new()
	var template: Label = Label.new()
	container.add_child(template)
	add_child(container)
	_nodes.append(container)

	var _bind_result: bool = binder.bind_repeater(store, "rows", container, template)
	remove_child(container)
	container.tree_exited.emit()

	assert_eq(binder.get_binding_count(), 0, "容器退出场景树后 binder 应清理绑定。")
	assert_eq(store.get_subscription_count(), 0, "容器退出场景树后 store 订阅也应清理。")


# --- 私有/辅助方法 ---

func _configure_label(node: Node, item: Variant, index: int) -> void:
	var label: Label = _as_label(node)
	var data: Dictionary = GFVariantData.as_dictionary(item)
	label.text = "%d:%s" % [index, GFVariantData.get_option_string(data, "name")]


func _track_node(node: Node) -> void:
	_nodes.append(node)


func _as_label(value: Variant) -> Label:
	assert_true(value is Label, "测试观察值应为 Label。")
	if value is Label:
		var label: Label = value
		return label
	return null
