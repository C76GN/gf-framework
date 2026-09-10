## 测试 GFRepeaterBinder 的模板重复渲染绑定行为。
extends GutTest


# --- 常量 ---

const GF_REACTIVE_STATE_STORE_SCRIPT = preload("res://addons/gf/standard/utilities/state/gf_reactive_state_store.gd")
const GF_REPEATER_BINDER_SCRIPT = preload("res://addons/gf/standard/utilities/ui/gf_repeater_binder.gd")


# --- 私有变量 ---

var _nodes: Array[Node] = []
var _binders: Array[GFRepeaterBinder] = []
var _metadata_callbacks: int = 0


# --- Godot 生命周期方法 ---

func after_each() -> void:
	for binder: GFRepeaterBinder in _binders:
		binder.dispose()
	_binders.clear()
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	await get_tree().process_frame


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


func test_keyed_reorder_preserves_nodes_focus_and_uncommitted_text() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	add_child(container)
	_track_node(container)
	var original: Array[Node] = _sync_rows(container, template, [
		{ "key": 1, "label": "Alpha" }, { "key": 2, "label": "Beta" },
	])
	assert_eq(original.size(), 2)
	if original.size() != 2:
		return
	var editor: LineEdit = _row_editor(original[0])
	editor.text = "Uncommitted draft"
	await get_tree().process_frame
	editor.grab_focus()
	assert_same(get_viewport().gui_get_focus_owner(), editor)
	var reordered: Array[Node] = _sync_rows(container, template, [
		{ "key": 2, "label": "Beta updated" }, { "key": 1, "label": "Alpha" },
	])
	assert_eq(reordered.size(), 2)
	if reordered.size() != 2:
		return
	assert_same(reordered[0], original[1])
	assert_same(reordered[1], original[0])
	assert_same(container.get_child(1), original[1])
	assert_same(container.get_child(2), original[0])
	assert_eq(editor.text, "Uncommitted draft")
	assert_same(get_viewport().gui_get_focus_owner(), editor)


func test_keyed_invalid_identity_preserves_existing_ui() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var original: Array[Node] = _sync_rows(container, template, [{ "key": 1, "label": "Original" }])
	assert_eq(original.size(), 1)
	if original.is_empty():
		return
	for invalid_items: Array in [
		[{ "key": 2 }, { "key": 2 }], [{ "key": null }],
		[{ "key": [] }], [{ "key": INF }], [{ "key": "x".repeat(5000) }],
	]:
		var report: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, invalid_items, _keyed_options())
		assert_false(GFVariantData.get_option_bool(report, "ok"))
		assert_eq(container.get_child_count(), 2)
		assert_same(container.get_child(1), original[0])
	var append_options: Dictionary = _keyed_options()
	append_options["clear_existing"] = false
	var append_report: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 3 }], append_options)
	assert_false(GFVariantData.get_option_bool(append_report, "ok"))
	assert_same(container.get_child(1), original[0])


func test_keyed_unchanged_rows_skip_configuration_but_in_place_edit_is_seen() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var data: Dictionary = { "key": 1, "label": "Initial" }
	var options: Dictionary = _keyed_options()
	var configured: Array[int] = [0]
	options["configure_callable"] = func(node: Node, item: Variant, index: int) -> void:
		configured[0] += 1
		_configure_row(node, item, index)
	var original: Array[Node] = _report_nodes(GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [data], options))
	var _unchanged: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [data], options)
	assert_eq(configured[0], 1)
	data["label"] = "Mutated in place"
	var changed: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [data], options)
	assert_eq(configured[0], 2)
	if not original.is_empty() and not _report_nodes(changed).is_empty():
		assert_same(_report_nodes(changed)[0], original[0])
		assert_eq(_as_label(original[0].get_node("Label")).text, "0:Mutated in place")


func test_keyed_callback_reentry_is_rejected_without_replacing_outer_rows() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var nested_reports: Array[Dictionary] = []
	var options: Dictionary = _keyed_options()
	options["configure_callable"] = func(_node: Node, _item: Variant, _index: int) -> void:
		nested_reports.append(GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 99 }], _keyed_options()))
	var report: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 1 }, { "key": 2 }], options)
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(_report_nodes(report).size(), 2)
	assert_eq(nested_reports.size(), 2)
	for nested: Dictionary in nested_reports:
		assert_false(GFVariantData.get_option_bool(nested, "ok"))
		assert_eq(GFVariantData.get_option_string_name(nested, "error"), &"busy")
	assert_eq(container.get_child_count(), 3)


func test_keyed_callback_clear_interrupts_remaining_work() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var options: Dictionary = _keyed_options()
	var calls: Array[int] = [0]
	options["configure_callable"] = func(_node: Node, _item: Variant, _index: int) -> void:
		calls[0] += 1
		var _cleared: int = GF_REPEATER_BINDER_SCRIPT.clear_clones(container)
	var report: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 1 }, { "key": 2 }], options)
	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.get_option_string_name(report, "error"), &"interrupted")
	assert_eq(calls[0], 1)
	assert_eq(container.get_child_count(), 1)


func test_keyed_unbind_from_configuration_stops_subscription_and_remaining_work() -> void:
	var store: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({ "rows": [] })
	var binder: GFRepeaterBinder = GF_REPEATER_BINDER_SCRIPT.new()
	_binders.append(binder)
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var calls: Array[int] = [0]
	var options: Dictionary = _keyed_options()
	options["configure_callable"] = func(_node: Node, _item: Variant, _index: int) -> void:
		calls[0] += 1
		var _unbound: bool = binder.unbind_container(container)
	assert_true(binder.bind_repeater(store, "rows", container, template, options))
	var _changed: bool = store.set_value("rows", [{ "key": 1 }, { "key": 2 }])
	assert_eq(calls[0], 1)
	assert_eq(binder.get_binding_count(), 0)
	assert_eq(store.get_subscription_count(), 0)
	var child_count: int = container.get_child_count()
	var _later_changed: bool = store.set_value("rows", [{ "key": 3 }])
	assert_eq(container.get_child_count(), child_count)
	assert_eq(calls[0], 1)


func test_keyed_insert_remove_and_empty_preserve_other_groups_and_children() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var original: Array[Node] = _sync_rows(container, template, [{ "key": 1 }, { "key": 2 }, { "key": 3 }])
	if original.size() != 3:
		return
	var other_options: Dictionary = _keyed_options()
	other_options["group_key"] = &"other"
	var other_rows: Array[Node] = _report_nodes(GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 1 }], other_options))
	if other_rows.is_empty():
		return
	var ordinary: Label = Label.new()
	container.add_child(ordinary)
	container.move_child(ordinary, 2)
	container.move_child(other_rows[0], 4)
	var reordered: Array[Node] = _sync_rows(container, template, [{ "key": 3 }, { "key": 2 }, { "key": 1 }])
	_assert_children(container, [template, original[2], ordinary, original[1], other_rows[0], original[0]])
	assert_eq(reordered.size(), 3)
	var removed_ref: WeakRef = weakref(original[1])
	var changed: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 3 }, { "key": 4 }, { "key": 1 }], _keyed_options())
	var changed_rows: Array[Node] = _report_nodes(changed)
	assert_true(GFVariantData.get_option_bool(changed, "ok"))
	assert_eq(GFVariantData.get_option_int(changed, "created_count"), 1)
	assert_eq(GFVariantData.get_option_int(changed, "reused_count"), 2)
	assert_eq(GFVariantData.get_option_int(changed, "removed_count"), 1)
	if changed_rows.size() == 3:
		assert_same(changed_rows[0], original[2])
		assert_same(changed_rows[2], original[0])
	await get_tree().process_frame
	assert_true(removed_ref.get_ref() == null)
	var empty: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [], _keyed_options())
	assert_true(GFVariantData.get_option_bool(empty, "ok"))
	assert_eq(GFVariantData.get_option_int(empty, "removed_count"), 3)
	_assert_children(container, [template, ordinary, other_rows[0]])
	assert_eq(GF_REPEATER_BINDER_SCRIPT.clear_clones(container), 0)
	assert_eq(GF_REPEATER_BINDER_SCRIPT.clear_clones(container, { "group_key": &"other" }), 1)
	_assert_children(container, [template, ordinary])


func test_keyed_string_and_string_name_are_distinct_stable_identities() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var original: Array[Node] = _sync_rows(container, template, [{ "key": "same" }, { "key": &"same" }])
	var reordered: Array[Node] = _sync_rows(container, template, [{ "key": &"same" }, { "key": "same" }])
	assert_eq(original.size(), 2)
	assert_eq(reordered.size(), 2)
	if original.size() == 2 and reordered.size() == 2:
		assert_same(reordered[0], original[1])
		assert_same(reordered[1], original[0])
	var duplicate_report: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": &"same" }, { "key": &"same" }], _keyed_options())
	assert_eq(GFVariantData.get_option_string_name(duplicate_report, "error"), &"duplicate_identity")
	_assert_children(container, [template] + reordered)


func test_keyed_template_and_flags_change_replace_only_owned_rows() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var original: Array[Node] = _sync_rows(container, template, [{ "key": 1 }])
	if original.is_empty():
		return
	var replacement: HBoxContainer = _make_row_template()
	container.add_child(replacement)
	var changed: Array[Node] = _sync_rows(container, replacement, [{ "key": 1 }])
	assert_eq(changed.size(), 1)
	if changed.is_empty():
		return
	assert_true(changed[0] != original[0])
	var options: Dictionary = _keyed_options()
	options["duplicate_flags"] = 0
	var changed_flags: Array[Node] = _report_nodes(GF_REPEATER_BINDER_SCRIPT.sync_container(container, replacement, [{ "key": 1 }], options))
	assert_eq(changed_flags.size(), 1)
	if not changed_flags.is_empty():
		assert_true(changed_flags[0] != changed[0])
	assert_same(container.get_child(0), template)
	assert_same(container.get_child(1), replacement)


func test_owned_row_cannot_become_its_own_group_template() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var rows: Array[Node] = _sync_rows(container, template, [{ "key": 1 }, { "key": 2 }])
	if rows.size() != 2:
		return
	var report: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, rows[0], [{ "key": 3 }], _keyed_options())
	assert_eq(GFVariantData.get_option_string_name(report, "error"), &"invalid_target")
	_assert_children(container, [template, rows[0], rows[1]])


func test_duplicated_container_has_independent_group_state_and_cleanup() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var original: Array[Node] = _sync_rows(container, template, [{ "key": 1 }, { "key": 2 }])
	var copied: Node = container.duplicate()
	_track_node(copied)
	var copied_template: Node = copied.get_child(0)
	var copied_rows: Array[Node] = _sync_rows(copied, copied_template, [{ "key": 2 }, { "key": 1 }])
	assert_eq(copied_rows.size(), 2)
	assert_eq(copied.get_child_count(), 3, "复制来的行应由新组重建，不叠加残留行。")
	_assert_children(container, [template] + original)
	assert_eq(GF_REPEATER_BINDER_SCRIPT.clear_clones(container), 2)
	_assert_children(copied, [copied_template] + copied_rows)
	var reused: Array[Node] = _sync_rows(copied, copied_template, [{ "key": 2 }, { "key": 1 }])
	if reused.size() == 2 and copied_rows.size() == 2:
		assert_same(reused[0], copied_rows[0])
		assert_same(reused[1], copied_rows[1])
	assert_eq(GF_REPEATER_BINDER_SCRIPT.clear_clones(copied), 2)
	_assert_children(container, [template])
	_assert_children(copied, [copied_template])


func test_external_free_and_reparent_are_repaired_without_deleting_borrowed_node() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var original: Array[Node] = _sync_rows(container, template, [{ "key": 1 }, { "key": 2 }])
	if original.size() != 2:
		return
	var external: VBoxContainer = VBoxContainer.new()
	_track_node(external)
	original[0].free()
	original[1].reparent(external)
	var rebuilt: Array[Node] = _sync_rows(container, template, [{ "key": 1 }, { "key": 2 }])
	assert_eq(rebuilt.size(), 2)
	assert_same(original[1].get_parent(), external)
	assert_eq(GF_REPEATER_BINDER_SCRIPT.clear_clones(external), 0)
	assert_same(external.get_child(0), original[1])


func test_cyclic_payload_reconfigures_without_copying_or_comparing_reference_cycles() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var payload: Dictionary = { "key": 1, "label": "Cycle" }
	payload["self"] = payload
	var calls: Array[int] = [0]
	var options: Dictionary = _keyed_options()
	options["configure_callable"] = func(node: Node, item: Variant, index: int) -> void:
		calls[0] += 1
		_configure_row(node, item, index)
	var first: Array[Node] = _report_nodes(GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [payload], options))
	var second: Array[Node] = _report_nodes(GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [payload], options))
	assert_eq(calls[0], 2)
	assert_eq(first.size(), 1)
	assert_eq(second.size(), 1)
	if not first.is_empty() and not second.is_empty():
		assert_same(first[0], second[0])
	payload.clear()


func test_nested_value_and_typed_container_type_changes_are_configured() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var calls: Array[int] = [0]
	var options: Dictionary = _keyed_options()
	options["configure_callable"] = func(_node: Node, _item: Variant, _index: int) -> void:
		calls[0] += 1
	var integer_values: Array[int] = [1]
	var float_values: Array[float] = [1.0]
	for value: Variant in ["same", &"same", integer_values, float_values]:
		var report: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 1, "nested": { "value": value } }], options)
		assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(calls[0], 4)


func test_initial_unbind_and_dispose_do_not_restore_removed_subscriptions() -> void:
	for dispose_binding: bool in [false, true]:
		var store: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({ "rows": [{ "key": 1 }, { "key": 2 }] })
		var binder: GFRepeaterBinder = GF_REPEATER_BINDER_SCRIPT.new()
		_binders.append(binder)
		var container: VBoxContainer = VBoxContainer.new()
		var template: HBoxContainer = _make_row_template()
		container.add_child(template)
		_track_node(container)
		var calls: Array[int] = [0]
		var options: Dictionary = _keyed_options()
		options["configure_callable"] = func(_node: Node, _item: Variant, _index: int) -> void:
			calls[0] += 1
			if dispose_binding:
				binder.dispose()
			else:
				var _unbound: bool = binder.unbind_container(container)
		assert_false(binder.bind_repeater(store, "rows", container, template, options))
		assert_eq(calls[0], 1)
		assert_eq(binder.get_binding_count(), 0)
		assert_eq(store.get_subscription_count(), 0)


func test_initial_store_updates_coalesce_to_latest_value_on_next_frame() -> void:
	var store: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({ "rows": [{ "key": 1, "label": "Initial" }] })
	var binder: GFRepeaterBinder = GF_REPEATER_BINDER_SCRIPT.new()
	_binders.append(binder)
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var options: Dictionary = _keyed_options()
	var calls: Array[int] = [0]
	options["configure_callable"] = func(node: Node, item: Variant, index: int) -> void:
		calls[0] += 1
		_configure_row(node, item, index)
		if calls[0] == 1:
			var _middle: bool = store.set_value("rows", [{ "key": 1, "label": "Middle" }])
			var _latest: bool = store.set_value("rows", [{ "key": 1, "label": "Latest" }])
	assert_true(binder.bind_repeater(store, "rows", container, template, options))
	assert_eq(calls[0], 1)
	await get_tree().process_frame
	assert_eq(calls[0], 2)
	assert_eq(_as_label(container.get_child(1).get_node("Label")).text, "0:Latest")
	assert_eq(store.get_subscription_count(), 1)


func test_invalid_store_and_pending_updates_emit_failure_without_replacing_ui() -> void:
	for pending_update: bool in [false, true]:
		var store: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({ "rows": [{ "key": 1, "label": "Original" }] })
		var binder: GFRepeaterBinder = GF_REPEATER_BINDER_SCRIPT.new()
		_binders.append(binder)
		var errors: Array[StringName] = []
		var _connected: int = binder.synchronization_failed.connect(func(_container: Node, _group: StringName, error: StringName) -> void:
			errors.append(error)
		)
		var container: VBoxContainer = VBoxContainer.new()
		var template: HBoxContainer = _make_row_template()
		container.add_child(template)
		_track_node(container)
		var options: Dictionary = _keyed_options()
		options["configure_callable"] = func(node: Node, item: Variant, index: int) -> void:
			_configure_row(node, item, index)
			if pending_update:
				var _invalid: bool = store.set_value("rows", [{ "key": 2 }, { "key": 2 }])
		assert_true(binder.bind_repeater(store, "rows", container, template, options))
		var original: Node = container.get_child(1)
		if pending_update:
			await get_tree().process_frame
		else:
			var _invalid: bool = store.set_value("rows", [{ "key": 2 }, { "key": 2 }])
		assert_eq(errors, [&"duplicate_identity"])
		assert_same(container.get_child(1), original)
		assert_eq(_as_label(original.get_node("Label")).text, "0:Original")


func test_other_binder_unbind_does_not_interrupt_current_group_update() -> void:
	var store_a: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({ "rows": [] })
	var store_b: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({ "rows": [{ "key": 1 }, { "key": 2 }] })
	var binder_a: GFRepeaterBinder = GF_REPEATER_BINDER_SCRIPT.new()
	var binder_b: GFRepeaterBinder = GF_REPEATER_BINDER_SCRIPT.new()
	_binders.append(binder_a)
	_binders.append(binder_b)
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	assert_true(binder_a.bind_repeater(store_a, "rows", container, template, _keyed_options()))
	var options: Dictionary = _keyed_options()
	options["configure_callable"] = func(_node: Node, _item: Variant, _index: int) -> void:
		var _unbound: bool = binder_a.unbind_container(container)
	assert_true(binder_b.bind_repeater(store_b, "rows", container, template, options))
	assert_eq(container.get_child_count(), 3)
	assert_eq(store_a.get_subscription_count(), 0)
	assert_eq(store_b.get_subscription_count(), 1)


func test_identity_callback_clear_and_queued_clone_invalidate_the_current_sync() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var _original: Array[Node] = _sync_rows(container, template, [{ "key": 1 }])
	var options: Dictionary = _keyed_options()
	options["identity_callable"] = func(item: Variant, index: int) -> Variant:
		var _cleared: int = GF_REPEATER_BINDER_SCRIPT.clear_clones(container)
		return _item_key(item, index)
	var cleared: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 2 }], options)
	assert_eq(GFVariantData.get_option_string_name(cleared, "error"), &"interrupted")
	_assert_children(container, [template])
	var calls: Array[int] = [0]
	options = _keyed_options()
	options["configure_callable"] = func(node: Node, _item: Variant, _index: int) -> void:
		calls[0] += 1
		node.queue_free()
	var freed: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 2 }, { "key": 3 }], options)
	assert_eq(GFVariantData.get_option_string_name(freed, "error"), &"interrupted")
	assert_true(_report_nodes(freed).is_empty())
	assert_eq(calls[0], 1)
	await get_tree().process_frame
	_assert_children(container, [template])


func test_item_budget_and_invalid_options_are_rejected_before_callbacks_or_tree_changes() -> void:
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var original: Array[Node] = _sync_rows(container, template, [{ "key": 1 }])
	var calls: Array[int] = [0]
	var options: Dictionary = _keyed_options()
	options["identity_callable"] = func(item: Variant, index: int) -> Variant:
		calls[0] += 1
		return _item_key(item, index)
	var too_many: Array = []
	var _resized: int = too_many.resize(4097)
	var report: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, too_many, options)
	assert_eq(GFVariantData.get_option_string_name(report, "error"), &"item_limit")
	for invalid: Dictionary in [{ "unknown": true }, { "duplicate_flags": -1 }, { "hide_template": 1 }, { "identity_callable": Callable() }]:
		var invalid_options: Dictionary = options.duplicate()
		invalid_options.merge(invalid, true)
		var rejected: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 2 }], invalid_options)
		assert_eq(GFVariantData.get_option_string_name(rejected, "error"), &"invalid_options")
	assert_eq(calls[0], 0)
	_assert_children(container, [template] + original)


func test_pending_old_binding_refresh_is_cancelled_before_replacement_binding() -> void:
	var old_store: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({ "rows": [{ "key": 1, "label": "Initial" }] })
	var new_store: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({ "rows": [{ "key": 2, "label": "Replacement" }] })
	var binder: GFRepeaterBinder = GF_REPEATER_BINDER_SCRIPT.new()
	_binders.append(binder)
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var options: Dictionary = _keyed_options()
	options["configure_callable"] = func(node: Node, item: Variant, index: int) -> void:
		_configure_row(node, item, index)
		var _pending: bool = old_store.set_value("rows", [{ "key": 1, "label": "Stale pending" }])
	assert_true(binder.bind_repeater(old_store, "rows", container, template, options))
	assert_true(binder.unbind_container(container))
	assert_true(binder.bind_repeater(new_store, "rows", container, template, _keyed_options()))
	await get_tree().process_frame
	assert_eq(_as_label(container.get_child(1).get_node("Label")).text, "0:Replacement")
	assert_eq(old_store.get_subscription_count(), 0)
	assert_eq(new_store.get_subscription_count(), 1)
	assert_eq(binder.get_binding_count(), 1)


func test_releasing_binder_disconnects_weak_subscription_and_pending_refresh() -> void:
	var store: GFReactiveStateStore = GF_REACTIVE_STATE_STORE_SCRIPT.new({ "rows": [{ "key": 1, "label": "Displayed" }] })
	var binder: GFRepeaterBinder = GF_REPEATER_BINDER_SCRIPT.new()
	var container: VBoxContainer = VBoxContainer.new()
	var template: HBoxContainer = _make_row_template()
	container.add_child(template)
	_track_node(container)
	var calls: Array[int] = [0]
	var options: Dictionary = _keyed_options()
	options["configure_callable"] = func(node: Node, item: Variant, index: int) -> void:
		calls[0] += 1
		_configure_row(node, item, index)
		var _pending: bool = store.set_value("rows", [{ "key": 1, "label": "Pending" }])
	assert_true(binder.bind_repeater(store, "rows", container, template, options))
	assert_eq(store.get_subscription_count(), 1)
	var binder_ref: WeakRef = weakref(binder)
	binder = null
	assert_true(binder_ref.get_ref() == null)
	assert_eq(store.get_subscription_count(), 0)
	await get_tree().process_frame
	assert_eq(calls[0], 1)
	assert_eq(_as_label(container.get_child(1).get_node("Label")).text, "0:Displayed")


func test_copied_property_signal_interrupts_each_staged_public_metadata_write() -> void:
	for existing_clone_marker: bool in [false, true]:
		_metadata_callbacks = 0
		var container: VBoxContainer = VBoxContainer.new()
		var template: HBoxContainer = _make_row_template()
		container.add_child(template)
		add_child(container)
		_track_node(container)
		if existing_clone_marker:
			template.set_meta(GF_REPEATER_BINDER_SCRIPT.META_CLONE, true)
		var _connected: int = template.property_list_changed.connect(
			Callable(self, "_clear_from_metadata_notification").bind(container),
			CONNECT_PERSIST as Object.ConnectFlags
		)
		var report: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 1 }], _keyed_options())
		assert_eq(GFVariantData.get_option_string_name(report, "error"), &"interrupted")
		assert_eq(_metadata_callbacks, 1, "clone/group 任一公开 metadata 首次添加后的中断必须立即停止后续写入。")
		assert_true(_report_nodes(report).is_empty())
		_assert_children(container, [template])
		await get_tree().process_frame


func test_property_signal_interrupts_each_mounted_public_metadata_write() -> void:
	for existing_index_marker: bool in [false, true]:
		_metadata_callbacks = 0
		var container: VBoxContainer = VBoxContainer.new()
		var template: HBoxContainer = _make_row_template()
		if existing_index_marker:
			template.set_meta(GF_REPEATER_BINDER_SCRIPT.META_INDEX, 0)
		container.add_child(template)
		add_child(container)
		_track_node(container)
		var _connected: int = container.child_entered_tree.connect(Callable(self, "_connect_metadata_clear").bind(container))
		var report: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, [{ "key": 1 }, { "key": 2 }], _keyed_options())
		assert_eq(GFVariantData.get_option_string_name(report, "error"), &"interrupted")
		assert_eq(_metadata_callbacks, 1, "index/item 任一公开 metadata 首次添加后的中断必须立即停止后续写入。")
		assert_true(_report_nodes(report).is_empty())
		_assert_children(container, [template])
		await get_tree().process_frame


# --- 私有/辅助方法 ---


func _assert_children(container: Node, expected: Array) -> void:
	assert_eq(container.get_child_count(), expected.size())
	for index: int in range(mini(container.get_child_count(), expected.size())):
		var expected_value: Variant = expected[index]
		assert_true(expected_value is Node)
		if expected_value is Node:
			var expected_node: Node = expected_value
			assert_same(container.get_child(index), expected_node)


func _connect_metadata_clear(child: Node, container: Node) -> void:
	var _connected: int = child.property_list_changed.connect(Callable(self, "_clear_from_metadata_notification").bind(container))


func _clear_from_metadata_notification(container: Node) -> void:
	_metadata_callbacks += 1
	var _cleared: int = GF_REPEATER_BINDER_SCRIPT.clear_clones(container)


func _keyed_options() -> Dictionary:
	return {
		"identity_callable": Callable(self, "_item_key"),
		"configure_callable": Callable(self, "_configure_row"),
	}


func _item_key(item: Variant, _index: int) -> Variant:
	if item is Dictionary:
		var row: Dictionary = item
		return row.get("key")
	return null


func _make_row_template() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var editor: LineEdit = LineEdit.new()
	editor.name = "Editor"
	editor.custom_minimum_size = Vector2(160.0, 32.0)
	row.add_child(editor)
	var label: Label = Label.new()
	label.name = "Label"
	row.add_child(label)
	return row


func _configure_row(node: Node, item: Variant, index: int) -> void:
	var row_data: Dictionary = GFVariantData.as_dictionary(item)
	_as_label(node.get_node("Label")).text = "%d:%s" % [index, GFVariantData.get_option_string(row_data, "label")]


func _row_editor(node: Node) -> LineEdit:
	var child: Node = node.get_node("Editor")
	assert_true(child is LineEdit)
	if child is LineEdit:
		var editor: LineEdit = child
		return editor
	return null


func _report_nodes(report: Dictionary) -> Array[Node]:
	var nodes: Array[Node] = []
	var value: Variant = report.get("nodes")
	assert_true(value is Array)
	if value is Array:
		var raw_nodes: Array = value
		for raw_node: Variant in raw_nodes:
			if is_instance_valid(raw_node) and raw_node is Node:
				var node: Node = raw_node
				nodes.append(node)
	return nodes


func _sync_rows(container: Node, template: Node, items: Array) -> Array[Node]:
	var report: Dictionary = GF_REPEATER_BINDER_SCRIPT.sync_container(container, template, items, _keyed_options())
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	return _report_nodes(report)


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
