## 验证异构虚拟行的复用分类、事务边界与交互状态。
extends GutTest


# --- 常量 ---

const BINDER_SCRIPT = preload("res://addons/gf/standard/utilities/ui/gf_virtual_list_binder.gd")
const RESULT_SCRIPT = preload("res://addons/gf/standard/utilities/ui/gf_virtual_list_sync_result.gd")


# --- 私有变量 ---

var _binder: BINDER_SCRIPT = null
var _scroll: ScrollContainer = null
var _content: Control = null
var _model: GFVirtualListModel = null
var _focus: GFVirtualListFocusModel = null
var _ids: Array[int] = []
var _keys: Dictionary = {}
var _extents: Dictionary = {}
var _created: Array[Control] = []
var _bind_count: int = 0
var _unbind_count: int = 0
var _bound_pairs: Dictionary = {}
var _wrong_template_count: int = 0
var _factory_budget: int = -1
var _rejected_index: int = -1
var _selector_action: StringName = &""
var _factory_action: StringName = &""
var _pool_limit_on_bind: int = -1
var _selector_witness: WeakRef = null


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_ids.clear()
	_keys.clear()
	_extents.clear()
	_created.clear()
	_bind_count = 0
	_unbind_count = 0
	_bound_pairs.clear()
	_wrong_template_count = 0
	_factory_budget = -1
	_rejected_index = -1
	_selector_action = &""
	_factory_action = &""
	_pool_limit_on_bind = -1
	_selector_witness = null


func after_each() -> void:
	if _binder != null:
		_binder.dispose()
	assert_true(_bound_pairs.is_empty(), "每个成功接纳或拒绝的绑定都应完成对称解绑。")
	_binder = null
	if is_instance_valid(_scroll):
		_scroll.free()
	_scroll = null
	_content = null
	await get_tree().process_frame


# --- 测试方法 ---

func test_mixed_rows_reuse_only_compatible_active_templates() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	var initial: Array[Control] = _created.duplicate()
	await get_tree().process_frame

	_scroll.scroll_vertical = 100
	var result: RESULT_SCRIPT = _binder.sync_now()

	assert_true(result.is_successful())
	assert_eq(_wrong_template_count, 0)
	assert_eq(_created.size(), 6, "不同类型的需求数量互换时，只创建缺少的一类。")
	assert_eq(result.get_reused_count(), 4)
	assert_eq(result.get_pooled_count(), 1)
	for item_index: int in result.get_materialized_indices():
		_assert_matching_row(item_index)
	assert_true(_binder.get_materialized_control(6) in initial)


func test_reorder_keeps_identity_and_template_together() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	var first: Control = _binder.get_materialized_control_by_id(0)
	var second: Control = _binder.get_materialized_control_by_id(1)
	_ids[0] = 1
	_ids[1] = 0

	assert_true(_binder.invalidate_items())
	assert_true(_binder.sync_now().is_successful())

	assert_same(_binder.get_materialized_control(0), second)
	assert_same(_binder.get_materialized_control(1), first)
	assert_eq(_wrong_template_count, 0)


func test_same_identity_switches_template_and_can_reuse_its_old_template() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	var original: Control = _binder.get_materialized_control_by_id(0)
	_keys[0] = &"image"
	assert_true(_binder.invalidate_items())
	assert_true(_binder.sync_now().is_successful())
	var replacement: Control = _binder.get_materialized_control_by_id(0)

	assert_ne(replacement, original)
	assert_true(replacement is PanelContainer)
	assert_null(original.get_parent())
	assert_eq(_unbind_count, 5, "同 ID 换模板的旧绑定也必须恰好解绑一次。")

	_keys[0] = &"text"
	assert_true(_binder.invalidate_items())
	assert_true(_binder.sync_now().is_successful())
	assert_same(_binder.get_materialized_control_by_id(0), original)
	assert_eq(_created.size(), 6)
	assert_eq(_wrong_template_count, 0)


func test_two_identities_swap_templates_using_each_others_controls_once() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	var first: Control = _binder.get_materialized_control(0)
	var second: Control = _binder.get_materialized_control(1)
	_keys[0] = &"image"
	_keys[1] = &"text"
	_factory_budget = 0
	assert_true(_binder.invalidate_items())
	var result: RESULT_SCRIPT = _binder.sync_now()
	assert_true(result.is_successful())
	assert_same(_binder.get_materialized_control(0), second)
	assert_same(_binder.get_materialized_control(1), first)
	assert_eq(_created.size(), 5)
	assert_eq(_wrong_template_count, 0)
	assert_eq(_bind_count, _unbind_count + result.get_materialized_count())
	var seen: Array[Control] = []
	for item_index: int in result.get_materialized_indices():
		var row: Control = _binder.get_materialized_control(item_index)
		assert_false(row in seen, "同一个候选只能分配给一个活动条目。")
		seen.append(row)


func test_template_factory_failure_preserves_old_commit_and_reuses_staged_rows() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	var first: Control = _binder.get_materialized_control(0)
	var third: Control = _binder.get_materialized_control(2)
	_keys[0] = &"image"
	_keys[2] = &"image"
	_factory_budget = 1
	assert_true(_binder.invalidate_items())

	var failed: RESULT_SCRIPT = _binder.sync_now()

	assert_eq(failed.get_status(), RESULT_SCRIPT.STATUS_FACTORY_FAILED)
	assert_same(_binder.get_materialized_control(0), first)
	assert_same(_binder.get_materialized_control(2), third)
	assert_eq(_unbind_count, 0, "预留阶段失败不得拆除上次已提交行。")
	assert_eq(failed.get_pooled_count(), 1)
	var staged: Control = _created.back()
	assert_null(staged.get_parent())

	_factory_budget = -1
	assert_true(_binder.sync_now().is_successful())
	assert_true(staged in [_binder.get_materialized_control(0), _binder.get_materialized_control(2)])
	assert_eq(_created.size(), 7, "重试应消费兼容的暂存节点。")
	assert_eq(_wrong_template_count, 0)


func test_template_bind_rejection_keeps_callbacks_balanced_and_retryable() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	_keys[0] = &"image"
	_rejected_index = 0
	assert_true(_binder.invalidate_items())
	var result: RESULT_SCRIPT = _binder.sync_now()

	assert_eq(result.get_status(), RESULT_SCRIPT.STATUS_BIND_FAILED)
	assert_null(_binder.get_materialized_control(0))
	assert_eq(_bind_count, _unbind_count + result.get_materialized_count())
	_rejected_index = -1
	assert_true(_binder.sync_now().is_successful())
	_assert_matching_row(0)
	_binder.dispose()
	assert_eq(_bind_count, _unbind_count)


func test_factory_failure_returns_borrowed_pool_rows_to_their_original_class() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	var first_text: Control = _binder.get_materialized_control(0)
	var second_text: Control = _binder.get_materialized_control(2)
	_keys[0] = &"image"
	_keys[2] = &"image"
	assert_true(_binder.invalidate_items())
	assert_true(_binder.sync_now().is_successful())
	var previous: Control = _binder.get_materialized_control(0)
	var previous_unbind_count: int = _unbind_count
	_keys[0] = &"text"
	_keys[1] = &"text"
	_keys[3] = &"text"
	_factory_budget = 0
	assert_true(_binder.invalidate_items())
	var failed: RESULT_SCRIPT = _binder.sync_now()

	assert_eq(failed.get_status(), RESULT_SCRIPT.STATUS_FACTORY_FAILED)
	assert_same(_binder.get_materialized_control(0), previous)
	assert_eq(_unbind_count, previous_unbind_count)
	assert_eq(failed.get_pooled_count(), 2)
	assert_null(first_text.get_parent())
	assert_null(second_text.get_parent())
	_factory_budget = -1
	var retried: RESULT_SCRIPT = _binder.sync_now()
	assert_true(retried.is_successful())
	assert_eq(retried.get_created_count(), 1)
	var restored_rows: Array[Control] = [
		_binder.get_materialized_control(0), _binder.get_materialized_control(1),
	]
	assert_true(first_text in restored_rows)
	assert_true(second_text in restored_rows)
	assert_eq(_wrong_template_count, 0)


func test_invalid_reuse_keys_fail_before_factory_or_old_unbind() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	var previous: Control = _binder.get_materialized_control(0)
	var invalid_keys: Array = [null, 7, {}, "text", &"", StringName("x".repeat(1025))]
	for invalid_key: Variant in invalid_keys:
		_keys[0] = invalid_key
		assert_true(_binder.invalidate_items())
		var result: RESULT_SCRIPT = _binder.sync_now()
		assert_eq(result.get_status(), RESULT_SCRIPT.STATUS_INVALID_REUSE_KEY)
		assert_eq(result.get_error_index(), 0)
		assert_same(_binder.get_materialized_control(0), previous)
		assert_eq(_created.size(), 5)
		assert_eq(_unbind_count, 0)
		assert_lt(result.get_error().length(), 100, "诊断不应回显项目 key。")


func test_reuse_key_multibyte_limit_is_measured_in_utf8_bytes() -> void:
	_create_fixture()
	_keys[0] = StringName("图".repeat(342))
	var result: RESULT_SCRIPT = _binder.sync_now()
	assert_eq(result.get_status(), RESULT_SCRIPT.STATUS_INVALID_REUSE_KEY)
	assert_eq(_created.size(), 0)


func test_invalid_reuse_key_result_round_trips_without_exposing_key() -> void:
	_create_fixture()
	_keys[0] = "private_project_template"
	var result: RESULT_SCRIPT = _binder.sync_now()
	assert_false(result.is_successful())
	var report: Dictionary = result.to_dict()
	var serialized: String = JSON.stringify(report)
	assert_false(serialized.contains("private_project_template"))
	var restored: RESULT_SCRIPT = RESULT_SCRIPT.new()
	assert_true(restored.configure_for_framework(GFVariantData.as_dictionary(JSON.parse_string(serialized))))
	assert_eq(restored.get_status(), RESULT_SCRIPT.STATUS_INVALID_REUSE_KEY)
	assert_eq(restored.to_dict(), report)
	assert_eq(result.duplicate_result().to_dict(), report)


func test_reuse_selector_invalidation_defers_without_changing_old_rows() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	var previous: Control = _binder.get_materialized_control(0)
	_selector_action = &"invalidate"
	assert_true(_binder.invalidate_items())
	var result: RESULT_SCRIPT = _binder.sync_now()

	assert_eq(result.get_status(), RESULT_SCRIPT.STATUS_DEFERRED)
	assert_same(_binder.get_materialized_control(0), previous)
	assert_eq(_unbind_count, 0)
	assert_true(_binder.sync_now().is_successful())
	assert_eq(_wrong_template_count, 0)


func test_reuse_selector_dispose_stops_before_creating_rows() -> void:
	_create_fixture()
	_selector_action = &"dispose"
	var result: RESULT_SCRIPT = _binder.sync_now()
	assert_eq(result.get_status(), RESULT_SCRIPT.STATUS_DISPOSED)
	assert_true(_binder.is_disposed())
	assert_eq(_created.size(), 0)


func test_owner_exit_during_selector_releases_active_pool_and_captured_callback() -> void:
	_create_fixture(0, true)
	assert_true(_binder.sync_now().is_successful())
	_keys[0] = &"image"
	assert_true(_binder.invalidate_items())
	assert_eq(_binder.sync_now().get_pooled_count(), 1)
	assert_true(_selector_witness.get_ref() != null)
	var previous_factory_count: int = _created.size()
	_selector_action = &"exit_owner"
	assert_true(_binder.invalidate_items())
	var result: RESULT_SCRIPT = _binder.sync_now()
	assert_eq(result.get_status(), RESULT_SCRIPT.STATUS_DISPOSED)
	assert_eq(_created.size(), previous_factory_count)
	assert_eq(_bind_count, _unbind_count)
	assert_eq(result.get_materialized_count(), 0)
	assert_eq(result.get_pooled_count(), 0)
	assert_true(_selector_witness.get_ref() == null)
	for row: Control in _created:
		assert_true(row.is_queued_for_deletion())


func test_typed_factory_invalidation_rolls_back_with_its_reuse_key() -> void:
	_create_fixture()
	_factory_action = &"invalidate"
	var result: RESULT_SCRIPT = _binder.sync_now()
	assert_eq(result.get_status(), RESULT_SCRIPT.STATUS_DEFERRED)
	assert_eq(_created.size(), 1)
	assert_eq(_bind_count, 0)
	var staged: Control = _created[0]
	assert_null(staged.get_parent())
	assert_true(_binder.sync_now().is_successful())
	assert_same(_binder.get_materialized_control(0), staged)
	assert_eq(_created.size(), 5)


func test_all_template_pools_share_one_budget_and_shrink_together() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	_binder.max_pooled_items = 2
	_model.set_item_count(0)
	var result: RESULT_SCRIPT = _binder.sync_now()
	assert_true(result.is_successful())
	assert_eq(result.get_pooled_count(), 2, "上限约束所有分类的总和。")
	var retained: int = 0
	for row: Control in _created:
		if not row.is_queued_for_deletion():
			retained += 1
			assert_null(row.get_parent())
	assert_eq(retained, 2)
	_binder.max_pooled_items = 0
	assert_eq(GFVariantData.get_option_int(_binder.get_debug_snapshot(), "pooled_count", -1), 0)
	for row: Control in _created:
		assert_true(row.is_queued_for_deletion())


func test_pool_budget_change_during_template_commit_waits_for_settlement() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	_keys[0] = &"image"
	_pool_limit_on_bind = 0
	assert_true(_binder.invalidate_items())
	var result: RESULT_SCRIPT = _binder.sync_now()
	assert_true(result.is_successful())
	assert_eq(result.get_pooled_count(), 0)
	assert_eq(result.get_materialized_count(), 5)
	_assert_matching_row(0)


func test_template_change_transfers_focus_to_new_row_target() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	await get_tree().process_frame
	assert_true(_focus.set_focused_index(0))
	assert_true(_binder.sync_now().is_successful())
	var previous: Control = _binder.get_materialized_control(0)
	assert_same(get_viewport().gui_get_focus_owner(), previous)
	_keys[0] = &"image"
	assert_true(_binder.invalidate_items())
	assert_true(_binder.sync_now().is_successful())

	var replacement: Control = _binder.get_materialized_control(0)
	assert_ne(replacement, previous)
	assert_eq(_focus.focused_index, 0)
	assert_same(get_viewport().gui_get_focus_owner(), _focus_target(replacement, 0, 0))


func test_template_change_keeps_external_focus() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	await get_tree().process_frame
	var external: Button = Button.new()
	external.text = "External focus"
	_scroll.add_child(external)
	external.grab_focus()
	_keys[0] = &"image"
	assert_true(_binder.invalidate_items())
	assert_true(_binder.sync_now().is_successful())
	assert_same(get_viewport().gui_get_focus_owner(), external)


func test_template_measurement_preserves_visible_scroll_anchor() -> void:
	_create_fixture(1)
	assert_true(_binder.sync_now().is_successful())
	await get_tree().process_frame
	_scroll.scroll_vertical = 100
	assert_true(_binder.sync_now().is_successful())
	var old_offset: float = _model.get_item_offset(5)
	_keys[4] = &"image"
	_extents[4] = 40.0
	assert_true(_binder.invalidate_items())
	var result: RESULT_SCRIPT = _binder.sync_now()

	assert_true(result.is_successful())
	assert_eq(result.get_anchor_adjustment(), 20.0)
	assert_eq(_scroll.scroll_vertical, 120)
	assert_eq(_model.get_item_offset(5) - old_offset, 20.0)
	_assert_matching_row(4)


func test_unbind_then_legacy_bind_clears_typed_factory_mode() -> void:
	_create_fixture()
	assert_true(_binder.sync_now().is_successful())
	_binder.unbind()
	var legacy_factory: Callable = func() -> Control: return Button.new()
	var legacy_bind: Callable = func(_row: Control, _index: int, _id: Variant) -> bool: return true
	var legacy_unbind: Callable = func(_row: Control, _index: int, _id: Variant) -> void: pass
	assert_true(_binder.bind(_scroll, _scroll, _content, _model, legacy_factory,
		legacy_bind, legacy_unbind, _identity))
	assert_true(_binder.sync_now().is_successful())
	assert_true(_binder.get_materialized_control(1) is Button)


# --- 私有/辅助方法 ---

func _create_fixture(overscan: int = 0, capture_witness: bool = false) -> void:
	for item_index: int in range(30):
		_ids.append(item_index)
		_keys[item_index] = &"text" if item_index % 2 == 0 else &"image"
	_scroll = ScrollContainer.new()
	_scroll.size = Vector2(240.0, 100.0)
	_content = Control.new()
	_scroll.add_child(_content)
	add_child(_scroll)
	_model = GFVirtualListModel.new()
	_model.estimated_item_extent = 20.0
	_model.overscan_items = overscan
	_model.set_item_count(_ids.size())
	_focus = GFVirtualListFocusModel.new()
	_binder = BINDER_SCRIPT.new()
	_binder.max_pooled_items = 10
	var selector: Callable = _reuse_key
	if capture_witness:
		var witness: RefCounted = RefCounted.new()
		_selector_witness = weakref(witness)
		selector = func(item_index: int, item_id: Variant) -> Variant:
			assert_true(is_instance_valid(witness))
			return _reuse_key(item_index, item_id)
	assert_true(_binder.bind_with_reuse_keys(_scroll, _scroll, _content, _model,
		_make_row, _bind_row, _unbind_row, _identity, selector,
		_focus, _measure, _focus_target))


func _identity(item_index: int) -> Variant:
	return _ids[item_index]


func _reuse_key(_item_index: int, item_id: Variant) -> Variant:
	var action: StringName = _selector_action
	_selector_action = &""
	if action == &"invalidate":
		var _invalidated: bool = _binder.invalidate_items()
	elif action == &"dispose":
		_binder.dispose()
	elif action == &"exit_owner":
		_scroll.get_parent().remove_child(_scroll)
	return _keys.get(item_id)


func _make_row(reuse_key: StringName) -> Control:
	if _factory_budget == 0:
		return null
	if _factory_budget > 0:
		_factory_budget -= 1
	var row: Control = null
	if reuse_key == &"text":
		row = Button.new()
	elif reuse_key == &"image":
		row = PanelContainer.new()
		var target: Button = Button.new()
		row.add_child(target)
	else:
		return null
	row.custom_minimum_size = Vector2(0.0, 20.0)
	_created.append(row)
	if _factory_action == &"invalidate":
		_factory_action = &""
		var _invalidated: bool = _binder.invalidate_items()
	return row


func _bind_row(row: Control, item_index: int, item_id: Variant) -> bool:
	_bind_count += 1
	var control_id: int = row.get_instance_id()
	assert_false(_bound_pairs.has(control_id), "重新绑定前必须先结束该节点的旧绑定。")
	_bound_pairs[control_id] = { "index": item_index, "id": item_id }
	var expected: Variant = _keys.get(item_id)
	if (expected == &"text" and not row is Button) or (expected == &"image" and not row is PanelContainer):
		_wrong_template_count += 1
	if _pool_limit_on_bind >= 0:
		_binder.max_pooled_items = _pool_limit_on_bind
	return item_index != _rejected_index


func _unbind_row(row: Control, item_index: int, item_id: Variant) -> void:
	_unbind_count += 1
	var control_id: int = row.get_instance_id()
	var bound_pair: Dictionary = GFVariantData.as_dictionary(_bound_pairs.get(control_id))
	assert_eq(bound_pair, { "index": item_index, "id": item_id }, "解绑必须对应原节点、索引和 ID，不能重复或串行。")
	var _erased: bool = _bound_pairs.erase(control_id)


func _measure(_row: Control, _item_index: int, item_id: Variant) -> float:
	return GFVariantData.get_option_float(_extents, item_id, 20.0)


func _focus_target(row: Control, _item_index: int, _item_id: Variant) -> Control:
	if row is PanelContainer:
		return row.get_child(0) as Control
	return row


func _assert_matching_row(item_index: int) -> void:
	var row: Control = _binder.get_materialized_control(item_index)
	assert_not_null(row)
	if _keys[_ids[item_index]] == &"text":
		assert_true(row is Button)
	else:
		assert_true(row is PanelContainer)
