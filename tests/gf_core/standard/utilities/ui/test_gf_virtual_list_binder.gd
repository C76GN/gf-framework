## 测试 GFVirtualListBinder 的有界物化、回收、测量、焦点与生命周期。
extends GutTest


# --- 常量 ---

const GF_VIRTUAL_LIST_BINDER_SCRIPT = preload("res://addons/gf/standard/utilities/ui/gf_virtual_list_binder.gd")
const GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = preload("res://addons/gf/standard/utilities/ui/gf_virtual_list_sync_result.gd")
const _JSON_SAFE_INTEGER_MAX: int = 9_007_199_254_740_991
const _NONNEGATIVE_JSON_INTEGER_FIELDS: Array[String] = [
	"layout_revision",
	"data_revision",
	"pooled_count",
	"created_count",
	"reused_count",
	"released_count",
	"measured_count",
]


# --- 私有变量 ---

var _nodes: Array[Node] = []
var _binders: Array[RefCounted] = []
var _item_ids: Array = []
var _factory_count: int = 0
var _bind_events: Array[Dictionary] = []
var _unbind_events: Array[Dictionary] = []
var _fail_factory: bool = false
var _factory_success_budget: int = -1
var _last_factory_control: Control = null
var _fail_bind_index: int = -1
var _expanded_first_extent: bool = false
var _measured_extents: Dictionary = {}
var _reentrant_mode: StringName = &""
var _invalidate_callback_budget: int = 0
var _layout_callback_budget: int = 0
var _measurement_requeue_budget: int = 0
var _focus_callback_budget: int = 0
var _layout_model_for_callback: GFVirtualListModel = null
var _focus_model_for_callback: GFVirtualListFocusModel = null
var _active_binder: RefCounted = null
var _foreign_parent_for_callback: Control = null
var _sync_completed_event_count: int = 0
var _reentrant_sync_result: RefCounted = null
var _captured_round_geometry: bool = false
var _captured_round_offset: float = 0.0
var _captured_round_extent: float = 0.0
var _identity_callback_count: int = 0


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_reset_fixture_state()


func after_each() -> void:
	for binder: RefCounted in _binders:
		if binder != null and binder.has_method("dispose"):
			var _dispose_result: Variant = binder.call("dispose")
	_binders.clear()
	_active_binder = null
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	await get_tree().process_frame


# --- 测试方法 ---

func test_bind_materializes_only_viewport_plus_overscan() -> void:
	var fixture: Dictionary = _create_fixture(100, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(result.is_successful(), "首次同步应成功。")
	assert_eq(result.get_viewport_range(), Vector2i(0, 5), "真实视口应命中前五项。")
	assert_eq(result.get_requested_range(), Vector2i(0, 6), "overscan 应额外请求一个条目。")
	assert_eq(result.get_materialized_count(), 6, "只应物化 visible + overscan 范围。")
	assert_eq(_factory_count, 6, "factory 调用次数应与首次物化数量一致。")


func test_scroll_reuses_rows_and_unbinds_each_previous_binding_once() -> void:
	var fixture: Dictionary = _create_fixture(100, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var initial_controls: Array[Control] = []
	for item_index: int in range(6):
		initial_controls.append(binder.get_materialized_control(item_index))

	scroll_container.scroll_vertical = 100
	var scrolled_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(scrolled_result.is_successful(), "滚动后的同步应成功。")
	assert_eq(scrolled_result.get_requested_range(), Vector2i(4, 11), "滚动范围应更新为新的 visible + overscan。")
	assert_eq(scrolled_result.get_materialized_count(), 7, "新范围只保留七个物化行。")
	assert_eq(_factory_count, 7, "离开范围的行应先回收复用，只为净增长创建一个行。")
	assert_eq(_unbind_events.size(), 4, "离开范围的四项应各解绑一次。")
	var reused_count: int = 0
	for item_index: int in range(6, 11):
		if binder.get_materialized_control(item_index) in initial_controls:
			reused_count += 1
	assert_true(reused_count >= 4, "新范围应复用已离开范围的 Control。")


func test_stable_identity_follows_visible_reorder() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var alpha_id: StringName = _item_ids[1]
	var beta_id: StringName = _item_ids[2]
	var alpha_control: Control = binder.get_materialized_control_by_id(alpha_id)
	var beta_control: Control = binder.get_materialized_control_by_id(beta_id)
	_item_ids[1] = beta_id
	_item_ids[2] = alpha_id

	assert_true(binder.invalidate_items(), "数据 identity 变化应可显式失效。")
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(result.is_successful(), "可见范围内的稳定 identity 重排应成功。")
	assert_same(binder.get_materialized_control(2), alpha_control, "同一稳定 identity 应沿用原 Control。")
	assert_same(binder.get_materialized_control(1), beta_control, "交换后的另一 identity 也应沿用原 Control。")
	assert_eq(_unbind_events.size(), 6, "invalidate 应对每个旧活动绑定执行一次对称 unbind。")


func test_invalid_identity_preserves_previous_materialization() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var previous_control: Control = binder.get_materialized_control(2)
	var previous_unbind_count: int = _unbind_events.size()
	_item_ids[2] = { "unstable": true }
	var _invalidated: bool = binder.invalidate_items()

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_INVALID_IDENTITY)
	assert_same(binder.get_materialized_control(2), previous_control, "identity 预检失败不得破坏旧提交。")
	assert_eq(_unbind_events.size(), previous_unbind_count, "失败预检不得调用旧行 unbind。")


func test_duplicate_identity_preserves_previous_materialization() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var previous_control: Control = binder.get_materialized_control(1)
	_item_ids[2] = _item_ids[1]
	var _invalidated: bool = binder.invalidate_items()

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DUPLICATE_IDENTITY)
	assert_same(binder.get_materialized_control(1), previous_control, "重复 identity 不得替换旧 materialization。")
	assert_eq(_unbind_events.size(), 0, "重复 identity 预检失败不得解绑旧行。")


func test_factory_failure_rolls_back_staged_rows() -> void:
	var fixture: Dictionary = _create_fixture(50, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var previous_controls: Array[Control] = []
	for item_index: int in range(6):
		previous_controls.append(binder.get_materialized_control(item_index))
	_factory_success_budget = 1
	scroll_container.size.y = 200.0

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var staged_control: Control = _last_factory_control

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_FACTORY_FAILED)
	assert_eq(result.get_materialized_count(), 6, "factory 失败后应保留完整旧范围。")
	assert_eq(result.get_created_count(), 1, "失败前必须真实创建至少一个 staged Control。")
	assert_eq(_factory_count, 7, "失败 factory 之前只允许一个新增 Control 成功交付。")
	for item_index: int in range(6):
		assert_same(binder.get_materialized_control(item_index), previous_controls[item_index])
	assert_eq(_unbind_events.size(), 0, "staging 失败不得解绑旧行。")
	assert_eq(_bind_events.size(), 6, "staged Control 在提交前不得调用 bind callback。")
	assert_not_null(staged_control, "测试必须捕获失败前成功交付的 staged Control。")
	if staged_control == null:
		return
	assert_true(is_instance_valid(staged_control))
	assert_false(staged_control.is_queued_for_deletion())
	assert_null(staged_control.get_parent(), "失败 staging 应把新增 Control 回收到 parentless pool。")
	assert_eq(result.get_pooled_count(), 1, "失败结果应反映已回收的 staged Control。")

	_factory_success_budget = -1
	var retry_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_true(retry_result.is_successful(), "factory 恢复后同一计划应可直接重试。")
	assert_eq(retry_result.get_materialized_count(), 11, "失败 staging 不得在 active 记录中遗留暂存状态。")
	assert_eq(retry_result.get_created_count(), 4, "重试应复用已回收的 staged Control。")
	assert_eq(retry_result.get_reused_count(), 7, "六个旧 active 与一个 staged Control 应被复用。")
	assert_eq(retry_result.get_pooled_count(), 0)
	assert_eq(_factory_count, 11, "重试不应因污染而额外创建 Control。")
	var reused_staged_control: bool = false
	for item_index: int in retry_result.get_materialized_indices():
		if binder.get_materialized_control(item_index) == staged_control:
			reused_staged_control = true
			break
	assert_true(reused_staged_control, "重试必须重新接纳失败轮次回收的 staged Control。")
	assert_eq(_unbind_events.size(), 0, "成功重试前旧 active 不得被错误解绑。")
	assert_eq(_bind_events.size(), retry_result.get_materialized_count())

	binder.dispose()
	assert_eq(_unbind_events.size(), _bind_events.size(), "最终 teardown 必须保持 bind/unbind 对称。")
	assert_true(staged_control.is_queued_for_deletion(), "Binder-owned staged Control 最终必须被释放。")


func test_bind_rejection_reports_first_index_without_item_payload() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var sensitive_identity: StringName = &"private_account_row"
	_item_ids[2] = sensitive_identity
	_fail_bind_index = 2

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_BIND_FAILED)
	assert_eq(result.get_error_index(), 2, "typed result 应报告首个拒绝索引。")
	assert_eq(result.get_error(), "bind_callback rejected an item", "错误说明应固定且有界。")
	assert_false(result.get_error().contains(String(sensitive_identity)), "错误说明不得回显项目 identity。")
	assert_eq(
		_bind_events.size(),
		_unbind_events.size() + result.get_materialized_count(),
		"被拒绝的 bind 也必须保持 callback 与 active 行守恒。"
	)


func test_materialization_cap_prioritizes_raw_viewport() -> void:
	var fixture: Dictionary = _create_fixture(100, 100.0, 3, 5)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_TRUNCATED)
	assert_true(result.was_truncated(), "超出物化硬上限时结果应显式报告截断。")
	assert_eq(result.get_viewport_range(), Vector2i(0, 5))
	assert_eq(result.get_materialized_indices(), PackedInt32Array([0, 1, 2, 3, 4]), "节点预算应优先完整覆盖 raw viewport。")
	assert_eq(_factory_count, 5, "factory 调用不得突破硬上限。")


func test_public_budgets_are_absolutely_bounded_and_pool_shrink_converges() -> void:
	var fixture: Dictionary = _create_fixture(100, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	binder.max_materialized_items = GF_VIRTUAL_LIST_BINDER_SCRIPT.ABSOLUTE_MAX_MATERIALIZED_ITEMS + 1
	binder.max_pooled_items = GF_VIRTUAL_LIST_BINDER_SCRIPT.ABSOLUTE_MAX_POOLED_ITEMS + 1
	assert_eq(
		binder.max_materialized_items,
		GF_VIRTUAL_LIST_BINDER_SCRIPT.ABSOLUTE_MAX_MATERIALIZED_ITEMS,
		"活动节点预算不得突破框架绝对上限。"
	)
	assert_eq(
		binder.max_pooled_items,
		GF_VIRTUAL_LIST_BINDER_SCRIPT.ABSOLUTE_MAX_POOLED_ITEMS,
		"pool 预算不得突破框架绝对上限。"
	)

	binder.max_pooled_items = 2
	binder.max_materialized_items = 1
	var _reduced_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_eq(
		GFVariantData.get_option_int(binder.get_debug_snapshot(), "pooled_count"),
		2,
		"缩小活动范围后 pool 应遵循当前预算。"
	)
	binder.max_pooled_items = 0
	assert_eq(
		GFVariantData.get_option_int(binder.get_debug_snapshot(), "pooled_count"),
		0,
		"运行时缩小 pool 预算应立即回收超额 Control。"
	)


func test_oversized_identity_token_fails_closed_without_echoing_identity() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var previous_control: Control = binder.get_materialized_control(0)
	var oversized_identity: String = "s".repeat(
		GF_VIRTUAL_LIST_BINDER_SCRIPT.ABSOLUTE_MAX_IDENTITY_TOKEN_LENGTH + 1
	)
	_item_ids[0] = oversized_identity
	var _invalidated: bool = binder.invalidate_items()

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(initial_result.is_successful())
	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_INVALID_IDENTITY)
	assert_same(binder.get_materialized_control(0), previous_control, "超长 identity 不得破坏已提交 materialization。")
	assert_false(result.get_error().contains(oversized_identity.left(32)), "诊断不得回显 identity 内容。")


func test_measurement_updates_extent_and_applies_one_anchor_correction() -> void:
	var fixture: Dictionary = _create_fixture(100, 100.0, 5, 20)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	scroll_container.scroll_vertical = 80
	_expanded_first_extent = true
	assert_true(binder.request_measurement(), "活动行应可请求重新测量。")

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(result.is_successful(), "重新测量应成功。")
	assert_eq(model.get_item_extent(0), 40.0, "实测尺寸应回写布局模型。")
	assert_eq(result.get_anchor_adjustment(), 20.0, "位于视口上方的尺寸差应累计为一次 anchor correction。")
	assert_eq(scroll_container.scroll_vertical, 100, "滚动位置应只应用一次累计修正。")


func test_anchor_scroll_invalidation_reports_applied_adjustment_as_deferred() -> void:
	var fixture: Dictionary = _create_fixture(100, 100.0, 5, 20)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	scroll_container.scroll_vertical = 80
	_expanded_first_extent = true
	var callback_budget: Array[int] = [1]
	var _scroll_connected: Error = scroll_container.get_v_scroll_bar().value_changed.connect(
		func(_value: float) -> void:
			if not _binder_sync_is_in_progress(binder) or callback_budget[0] <= 0:
				return
			callback_budget[0] -= 1
			var _invalidated_from_anchor: bool = binder.invalidate_items()
	) as Error
	assert_true(binder.request_measurement())

	var deferred_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(deferred_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(deferred_result.is_successful())
	assert_eq(deferred_result.get_anchor_adjustment(), 20.0, "已执行的 anchor 写入不得在诊断中降为零。")
	assert_eq(scroll_container.scroll_vertical, 100)
	assert_eq(deferred_result.get_materialized_count(), 0)


func test_measurement_anchor_uses_pre_measurement_snapshot_for_multiple_rows() -> void:
	var fixture: Dictionary = _create_fixture(100, 100.0, 6, 32)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	scroll_container.scroll_vertical = 120
	_measured_extents = {
		0: 35.0,
		1: 45.0,
		2: 55.0,
		3: 65.0,
	}
	assert_true(binder.request_measurement())

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(result.is_successful())
	assert_eq(result.get_anchor_adjustment(), 120.0, "所有测量前位于锚点上方的 delta 都应累计。")
	assert_eq(scroll_container.scroll_vertical, 240, "多行 delta 应在该轮末尾一次性应用。")


func test_explicit_measurement_ignores_auto_measure_toggle() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	binder.auto_measure = false
	_measured_extents[0] = 48.0
	assert_true(binder.request_measurement())

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(result.is_successful())
	assert_eq(model.get_item_extent(0), 48.0, "显式测量请求不得被 auto_measure 禁用。")
	assert_true(result.get_measured_count() > 0)


func test_focus_change_reveals_item_and_hands_focus_to_row() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_true(focus_model.set_focused_index(20), "应能更新虚拟焦点。")
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	var focused_control: Control = binder.get_materialized_control(20)
	assert_true(result.is_successful(), "焦点目标滚入视口后的同步应成功。")
	assert_not_null(focused_control, "虚拟焦点对应行应被物化。")
	assert_true(scroll_container.scroll_vertical > 0, "远端焦点应按 nearest 滚入视口。")
	assert_same(get_viewport().gui_get_focus_owner(), focused_control, "Godot 焦点应交接到对应项目行。")


func test_pending_focus_reveal_quantizes_range_before_materialization() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(
		2,
		20.0,
		0,
		512,
		focus_model,
		null,
		Vector2.ZERO,
		false,
		Callable(),
		false
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var _first_extent: Dictionary = model.set_item_extent(0, 20.25, true)
	var _second_extent: Dictionary = model.set_item_extent(1, 20.10, true)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_true(focus_model.set_focused_index(1))
	assert_eq(scroll_container.scroll_vertical, 20, "实际 ScrollContainer 偏移应按整数规则量化。")
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(result.is_successful())
	assert_eq(result.get_viewport_range(), Vector2i(0, 2))
	assert_eq(result.get_requested_range(), Vector2i(0, 2))
	assert_not_null(
		binder.get_materialized_control(0),
		"range 必须使用与实际滚动相同的量化偏移，保留仍露出 0.25px 的首行。"
	)


func test_pending_focus_reveal_measurement_anchors_to_planned_scroll() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(
		100,
		100.0,
		1,
		512,
		focus_model,
		null,
		Vector2.ZERO,
		false,
		Callable(),
		false
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	scroll_container.scroll_vertical = 200
	var _scrolled_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	_focus_model_for_callback = focus_model
	_focus_callback_budget = 1
	_reentrant_mode = &"focus_zero_on_bind"
	assert_true(binder.invalidate_items())

	var queued_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(queued_result.is_successful(), str(queued_result.to_dict()))
	assert_eq(focus_model.focused_index, 0)
	assert_eq(scroll_container.scroll_vertical, 200, "同步 callback 的 reveal 必须留给下一轮。")
	_measured_extents[0] = 40.0
	assert_true(binder.request_measurement(), str(binder.get_debug_snapshot()))

	var reveal_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(reveal_result.is_successful(), str(reveal_result.to_dict()))
	assert_eq(reveal_result.get_anchor_adjustment(), 0.0)
	assert_eq(scroll_container.scroll_vertical, 0, "测量锚点必须基于本轮 reveal 后的量化偏移。")
	assert_not_null(binder.get_materialized_control(0))


func test_bind_callback_focus_intent_hands_off_only_in_next_sync_round() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		focus_model,
		null,
		Vector2.ZERO,
		false,
		Callable(),
		false
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	_focus_model_for_callback = focus_model
	_focus_callback_budget = 1
	_reentrant_mode = &"focus_zero_on_bind"
	assert_true(binder.invalidate_items())

	var intent_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(intent_result.is_successful())
	assert_eq(focus_model.focused_index, 0)
	assert_null(
		get_viewport().gui_get_focus_owner(),
		"bind callback 产生的新焦点意图不得在同一事务尾部执行物理 handoff。"
	)

	var handoff_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_true(handoff_result.is_successful())
	assert_same(get_viewport().gui_get_focus_owner(), binder.get_materialized_control(0))


func test_bind_adopts_preconfigured_virtual_focus() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var _count_changed: bool = focus_model.set_item_count(100)
	assert_true(focus_model.set_focused_index(20))

	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	await get_tree().process_frame
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var focused_control: Control = binder.get_materialized_control(20)

	assert_true(result.is_successful())
	assert_gt(scroll_container.scroll_vertical, 0, "bind 应 reveal 已存在的远端虚拟焦点。")
	assert_not_null(focused_control)
	assert_same(get_viewport().gui_get_focus_owner(), focused_control)


func test_bind_reveals_preconfigured_focus_without_stealing_external_focus() -> void:
	var external_button: Button = Button.new()
	external_button.focus_mode = Control.FOCUS_ALL
	add_child(external_button)
	_nodes.append(external_button)
	external_button.grab_focus()
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), external_button)
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var _count_changed: bool = focus_model.set_item_count(100)
	assert_true(focus_model.set_focused_index(20))

	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	await get_tree().process_frame
	var _first_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var _second_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_gt(scroll_container.scroll_vertical, 0, "bind 仍应 reveal 已存在的虚拟焦点。")
	assert_not_null(binder.get_materialized_control(20))
	assert_same(
		get_viewport().gui_get_focus_owner(),
		external_button,
		"attach 不得把 bind 前已有的项目物理焦点抢给虚拟列表。"
	)


func test_existing_external_focus_wins_while_new_virtual_focus_is_revealed() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var external_button: Button = Button.new()
	external_button.focus_mode = Control.FOCUS_ALL
	add_child(external_button)
	_nodes.append(external_button)
	external_button.grab_focus()
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), external_button)

	assert_true(focus_model.set_focused_index(80))
	var first_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var second_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_true(first_result.is_successful())
	assert_true(second_result.is_successful())
	assert_gt(scroll_container.scroll_vertical, 0, "外部焦点不得阻断虚拟焦点 reveal。")
	assert_not_null(binder.get_materialized_control(80))
	assert_same(
		get_viewport().gui_get_focus_owner(),
		external_button,
		"虚拟焦点变化不得抢走已经存在的项目物理焦点。"
	)


func test_focus_target_immediate_release_cancels_future_handoff_retries() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var focus_state: Dictionary = {
		"connected": false,
		"focus_entered_count": 0,
	}
	var focus_target_callback: Callable = func(
		control: Control,
		_item_index: int,
		_item_id: Variant
	) -> Control:
		if not GFVariantData.get_option_bool(focus_state, "connected"):
			focus_state["connected"] = true
			var release_callback: Callable = func() -> void:
				focus_state["focus_entered_count"] = (
					GFVariantData.get_option_int(focus_state, "focus_entered_count") + 1
				)
				control.release_focus()
			var _connected: Error = control.focus_entered.connect(release_callback) as Error
		return control
	var fixture: Dictionary = _create_fixture(
		100, 100.0, 1, 32, focus_model, null, Vector2.ZERO, false, focus_target_callback
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_true(focus_model.set_focused_index(20))
	var _focused_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_null(get_viewport().gui_get_focus_owner())
	assert_eq(GFVariantData.get_option_int(focus_state, "focus_entered_count"), 1)

	var _retry_one: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var _retry_two: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_eq(
		GFVariantData.get_option_int(focus_state, "focus_entered_count"),
		1,
		"项目在 focus_entered 中显式 release 后不得被 Binder 连续重抢。"
	)


func test_recycled_focused_row_restores_focus_without_stealing_external_focus() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_true(focus_model.set_focused_index(20))
	var _focused_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var first_focused_control: Control = binder.get_materialized_control(20)
	assert_same(get_viewport().gui_get_focus_owner(), first_focused_control)

	binder.auto_reveal_focus = false
	scroll_container.scroll_vertical = 1_000
	var recycled_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_true(recycled_result.is_successful())
	assert_null(binder.get_materialized_control(20), "离开 overscan 的聚焦行应进入回收路径。")
	assert_null(get_viewport().gui_get_focus_owner(), "回收行不得把物理焦点留在复用 Control 上。")
	assert_eq(focus_model.focused_index, 20, "物理行回收不得清除虚拟焦点。")

	scroll_container.scroll_vertical = 400
	var restored_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var restored_control: Control = binder.get_materialized_control(20)
	assert_true(restored_result.is_successful())
	assert_not_null(restored_control)
	assert_same(get_viewport().gui_get_focus_owner(), restored_control, "焦点行重新物化后应恢复交接。")

	scroll_container.scroll_vertical = 1_000
	var _recycled_again_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var external_button: Button = Button.new()
	external_button.focus_mode = Control.FOCUS_ALL
	add_child(external_button)
	_nodes.append(external_button)
	external_button.grab_focus()
	assert_same(get_viewport().gui_get_focus_owner(), external_button)
	scroll_container.scroll_vertical = 400
	var _returned_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_same(
		get_viewport().gui_get_focus_owner(),
		external_button,
		"项目显式取得外部焦点后，Binder 不得在行返回时抢回焦点。"
	)


func test_focus_target_callback_cannot_overwrite_newer_virtual_focus_handoff() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var focus_callback_indices: Array[int] = []
	var focus_target_callback: Callable = func(
		control: Control,
		item_index: int,
		_item_id: Variant
	) -> Control:
		focus_callback_indices.append(item_index)
		if item_index == 20:
			var _focused_next: bool = focus_model.set_focused_index(21)
		return control
	var fixture: Dictionary = _create_fixture(
		100,
		100.0,
		1,
		32,
		focus_model,
		null,
		Vector2.ZERO,
		false,
		focus_target_callback
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_true(focus_model.set_focused_index(20))
	var first_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var old_focus_control: Control = binder.get_materialized_control(20)
	assert_true(first_result.is_successful())
	assert_eq(focus_model.focused_index, 21)
	assert_ne(
		get_viewport().gui_get_focus_owner(),
		old_focus_control,
		"callback 提出的新虚拟焦点必须使旧 handoff 失效。"
	)

	var second_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var new_focus_control: Control = binder.get_materialized_control(21)
	assert_true(second_result.is_successful())
	assert_not_null(new_focus_control)
	assert_same(get_viewport().gui_get_focus_owner(), new_focus_control)
	assert_eq(focus_callback_indices, [20, 21], "新 handoff 应在下一轮执行且不得递归。")


func test_hidden_focus_target_keeps_handoff_pending_until_focus_is_observed() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var focus_state: Dictionary = { "hidden": true }
	var focus_target_callback: Callable = func(
		control: Control,
		item_index: int,
		_item_id: Variant
	) -> Control:
		if item_index == 20:
			control.visible = not GFVariantData.get_option_bool(focus_state, "hidden")
		return control
	var fixture: Dictionary = _create_fixture(
		100,
		100.0,
		1,
		32,
		focus_model,
		null,
		Vector2.ZERO,
		false,
		focus_target_callback
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	get_viewport().gui_release_focus()
	assert_true(focus_model.set_focused_index(20))

	var hidden_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var hidden_control: Control = binder.get_materialized_control(20)

	assert_true(hidden_result.is_successful())
	assert_not_null(hidden_control)
	assert_false(hidden_control.visible)
	assert_null(get_viewport().gui_get_focus_owner(), "隐藏行不能被误报为已完成焦点交接。")

	focus_state["hidden"] = false
	assert_true(binder.request_sync())
	var visible_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_true(visible_result.is_successful())
	assert_true(hidden_control.visible)
	assert_same(
		get_viewport().gui_get_focus_owner(),
		hidden_control,
		"失败的 handoff 必须保留到目标可见并实际取得焦点。"
	)


func test_virtual_focus_change_releases_stale_physical_focus() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_true(focus_model.set_focused_index(20))
	var _focused_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), binder.get_materialized_control(20))

	var _focus_cleared: bool = focus_model.clear_focus()
	await get_tree().process_frame
	assert_null(get_viewport().gui_get_focus_owner(), "清除虚拟焦点必须同步释放旧行物理焦点。")

	assert_true(focus_model.set_focused_index(20))
	var _restored_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), binder.get_materialized_control(20))
	binder.auto_reveal_focus = false
	assert_true(focus_model.set_focused_index(80))
	await get_tree().process_frame
	assert_null(get_viewport().gui_get_focus_owner(), "未物化的新虚拟焦点不得让旧行继续接收输入。")
	assert_null(binder.get_materialized_control(80))

	scroll_container.scroll_vertical = 1_600
	var _remote_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_same(
		get_viewport().gui_get_focus_owner(),
		binder.get_materialized_control(80),
		"新虚拟焦点物化后应完成延迟交接。"
	)


func test_project_focus_on_another_active_row_cancels_pending_handoff() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	binder.auto_reveal_focus = false
	assert_true(focus_model.set_focused_index(20))
	var project_focus_row: Control = binder.get_materialized_control(5)
	assert_not_null(project_focus_row)
	project_focus_row.grab_focus()
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), project_focus_row)

	scroll_container.scroll_vertical = 400
	var _target_visible_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_ne(
		get_viewport().gui_get_focus_owner(),
		binder.get_materialized_control(20),
		"项目聚焦其他活动行后，旧 pending handoff 不得再次抢焦点。"
	)


func test_project_focus_release_cancels_pending_handoff() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	binder.auto_reveal_focus = false
	var project_focus_row: Control = binder.get_materialized_control(5)
	assert_not_null(project_focus_row)
	project_focus_row.grab_focus()
	await get_tree().process_frame
	assert_true(focus_model.set_focused_index(20))
	assert_same(get_viewport().gui_get_focus_owner(), project_focus_row)

	project_focus_row.release_focus()
	await get_tree().process_frame
	assert_null(get_viewport().gui_get_focus_owner())
	scroll_container.scroll_vertical = 400
	var _target_visible_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_ne(
		get_viewport().gui_get_focus_owner(),
		binder.get_materialized_control(20),
		"项目显式释放焦点后，旧 pending handoff 不得再次抢焦点。"
	)


func test_focus_exit_callback_to_external_control_wins_during_row_recycle() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_true(focus_model.set_focused_index(20))
	var _focused_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var focused_row: Control = binder.get_materialized_control(20)
	assert_same(get_viewport().gui_get_focus_owner(), focused_row)
	var external_button: Button = Button.new()
	external_button.focus_mode = Control.FOCUS_ALL
	add_child(external_button)
	_nodes.append(external_button)
	var _focus_exit_connected: Error = focused_row.focus_exited.connect(
		func() -> void: external_button.grab_focus()
	) as Error
	binder.auto_reveal_focus = false

	scroll_container.scroll_vertical = 1_000
	var _recycled_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_same(get_viewport().gui_get_focus_owner(), external_button)
	scroll_container.scroll_vertical = 400
	var _returned_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_not_null(binder.get_materialized_control(20))
	assert_same(
		get_viewport().gui_get_focus_owner(),
		external_button,
		"focus_exited 中产生的更新项目焦点不得被 recycle handoff 覆盖。"
	)


func test_focus_exit_callback_to_external_control_wins_over_new_virtual_focus() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_true(focus_model.set_focused_index(20))
	var _focused_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var focused_row: Control = binder.get_materialized_control(20)
	var external_button: Button = Button.new()
	external_button.focus_mode = Control.FOCUS_ALL
	add_child(external_button)
	_nodes.append(external_button)
	var _focus_exit_connected: Error = focused_row.focus_exited.connect(
		func() -> void: external_button.grab_focus()
	) as Error

	assert_true(focus_model.set_focused_index(21))
	var _next_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_eq(focus_model.focused_index, 21)
	assert_same(
		get_viewport().gui_get_focus_owner(),
		external_button,
		"旧行 focus_exited 中的较新项目焦点必须取消新虚拟焦点的物理 handoff。"
	)


func test_focus_exit_nested_virtual_focus_change_preserves_newest_handoff() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_true(focus_model.set_focused_index(20))
	var _focused_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var focused_row: Control = binder.get_materialized_control(20)
	assert_not_null(focused_row)
	var _focus_exit_connected: Error = focused_row.focus_exited.connect(
		func() -> void:
			var _newer_focus: bool = focus_model.set_focused_index(22),
		CONNECT_ONE_SHOT
	) as Error

	assert_true(focus_model.set_focused_index(21))
	var _next_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_eq(focus_model.focused_index, 22)
	assert_same(
		get_viewport().gui_get_focus_owner(),
		binder.get_materialized_control(22),
		"外层 focused_index_changed 回调不得覆盖 focus_exited 中产生的更新虚拟焦点。"
	)


func test_clear_focus_preserves_scroll_when_focus_exit_moves_to_external_control() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(100, 100.0, 1, 32, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	assert_true(focus_model.set_focused_index(20))
	var _focused_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var focused_row: Control = binder.get_materialized_control(20)
	var external_button: Button = Button.new()
	external_button.focus_mode = Control.FOCUS_ALL
	add_child(external_button)
	_nodes.append(external_button)
	var _focus_exit_connected: Error = focused_row.focus_exited.connect(
		func() -> void: external_button.grab_focus(),
		CONNECT_ONE_SHOT
	) as Error
	var previous_scroll: int = scroll_container.scroll_vertical

	assert_true(focus_model.clear_focus())
	await get_tree().process_frame

	assert_same(get_viewport().gui_get_focus_owner(), external_button)
	assert_eq(
		scroll_container.scroll_vertical,
		previous_scroll,
		"clear_focus 的 NO_FOCUS 不得被当作 index -1 滚回列表顶部。"
	)


func test_owner_exit_disposes_binding_and_releases_rows_once() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var active_count: int = result.get_materialized_count()

	remove_child(scroll_container)
	await get_tree().process_frame

	assert_true(binder.is_disposed(), "owner 离开树后 binder 应进入不可复用终态。")
	assert_eq(_unbind_events.size(), active_count, "每个成功绑定的活动行应恰好解绑一次。")
	assert_eq(binder.get_last_sync_result().get_materialized_count(), 0, "dispose 后诊断不得保留活动行。")


func test_content_exit_disposes_while_owner_remains_alive() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var active_count: int = initial_result.get_materialized_count()
	assert_eq(scroll_container.tree_exited.get_connections().size(), 1, "owner 与 scroll 同一节点时只能连接一次。")
	assert_eq(content_root.tree_exited.get_connections().size(), 1)
	scroll_container.remove_child(content_root)

	assert_eq(binder.get_last_sync_result().get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_true(binder.is_disposed(), "content 退出树必须确定性 teardown，不能恢复 idle。")
	assert_true(scroll_container.is_inside_tree(), "生命周期 owner 应仍保持存活。")
	assert_eq(_unbind_events.size(), active_count)
	assert_eq(scroll_container.tree_exited.get_connections().size(), 0, "其余生命周期连接必须对称断开。")
	assert_eq(content_root.tree_exited.get_connections().size(), 0)


func test_scroll_exit_disposes_while_separate_owner_remains_alive() -> void:
	var lifecycle_owner: Node = Node.new()
	add_child(lifecycle_owner)
	_nodes.append(lifecycle_owner)
	var fixture: Dictionary = _create_fixture(20, 100.0, 1, 512, null, lifecycle_owner)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var active_count: int = initial_result.get_materialized_count()
	assert_eq(lifecycle_owner.tree_exited.get_connections().size(), 1)
	assert_eq(scroll_container.tree_exited.get_connections().size(), 1)
	assert_eq(content_root.tree_exited.get_connections().size(), 1)
	remove_child(scroll_container)

	assert_eq(binder.get_last_sync_result().get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_true(binder.is_disposed(), "scroll 退出树必须确定性 teardown。")
	assert_true(lifecycle_owner.is_inside_tree(), "独立 owner 应仍保持存活。")
	assert_eq(_unbind_events.size(), active_count)
	assert_eq(lifecycle_owner.tree_exited.get_connections().size(), 0)
	assert_eq(scroll_container.tree_exited.get_connections().size(), 0)
	assert_eq(content_root.tree_exited.get_connections().size(), 0)


func test_separate_owner_exit_disposes_while_scroll_and_content_remain_alive() -> void:
	var lifecycle_owner: Node = Node.new()
	add_child(lifecycle_owner)
	_nodes.append(lifecycle_owner)
	var fixture: Dictionary = _create_fixture(20, 100.0, 1, 512, null, lifecycle_owner)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var active_count: int = initial_result.get_materialized_count()
	assert_eq(lifecycle_owner.tree_exited.get_connections().size(), 1)
	assert_eq(scroll_container.tree_exited.get_connections().size(), 1)
	assert_eq(content_root.tree_exited.get_connections().size(), 1)

	remove_child(lifecycle_owner)

	assert_true(binder.is_disposed(), "独立 owner 退出树必须立即 dispose。")
	assert_true(scroll_container.is_inside_tree(), "owner 退出不得移除仍存活的 scroll。")
	assert_true(content_root.is_inside_tree(), "owner 退出不得移除仍存活的 content。")
	assert_eq(_unbind_events.size(), active_count, "owner 退出必须立即解绑全部活动行。")
	assert_eq(lifecycle_owner.tree_exited.get_connections().size(), 0)
	assert_eq(scroll_container.tree_exited.get_connections().size(), 0)
	assert_eq(content_root.tree_exited.get_connections().size(), 0)
	assert_eq(
		binder.get_last_sync_result().get_status(),
		GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED
	)


func test_manual_unbind_disconnects_all_unique_tree_exit_signals() -> void:
	var lifecycle_owner: Node = Node.new()
	add_child(lifecycle_owner)
	_nodes.append(lifecycle_owner)
	var fixture: Dictionary = _create_fixture(20, 100.0, 1, 512, null, lifecycle_owner)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	binder.unbind()

	assert_eq(lifecycle_owner.tree_exited.get_connections().size(), 0)
	assert_eq(scroll_container.tree_exited.get_connections().size(), 0)
	assert_eq(content_root.tree_exited.get_connections().size(), 0)


func test_externally_freed_owned_control_fails_closed() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var row: Control = binder.get_materialized_control(0)
	row.free()

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_true(binder.is_disposed(), "外部破坏 Binder-owned Control 后应 fail-closed。")


func test_externally_reparented_owned_control_fails_closed() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var row: Control = binder.get_materialized_control(0)
	var foreign_root: Control = Control.new()
	add_child(foreign_root)
	_nodes.append(foreign_root)
	row.reparent(foreign_root)

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_true(binder.is_disposed(), "外部重挂载 Binder-owned Control 后应 fail-closed。")


func test_externally_freed_pooled_control_fails_closed() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var owned_rows: Array[Control] = []
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	for item_index: int in range(6):
		owned_rows.append(binder.get_materialized_control(item_index))
	binder.max_pooled_items = 16
	binder.max_materialized_items = 1
	var _reduced_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var pooled_row: Control = _find_parentless_owned_control(owned_rows)
	assert_not_null(pooled_row)
	if pooled_row == null:
		return
	pooled_row.free()

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_true(binder.is_disposed(), "parentless pool 也属于 Binder 所有权边界。")


func test_externally_reparented_pooled_control_fails_closed_without_reclaiming_it() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var owned_rows: Array[Control] = []
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	for item_index: int in range(6):
		owned_rows.append(binder.get_materialized_control(item_index))
	binder.max_pooled_items = 16
	binder.max_materialized_items = 1
	var _reduced_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var pooled_row: Control = _find_parentless_owned_control(owned_rows)
	assert_not_null(pooled_row)
	if pooled_row == null:
		return
	var foreign_root: Control = Control.new()
	add_child(foreign_root)
	_nodes.append(foreign_root)
	foreign_root.add_child(pooled_row)

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_true(binder.is_disposed())
	assert_null(
		binder.get_materialized_control(1),
		"Binder 不得把被外部挂载的 pooled Control 静默抢回活动列表。"
	)


func test_zero_pool_budget_retires_rejected_row_after_transaction_commit() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	binder.max_pooled_items = 0
	_fail_bind_index = 0

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_BIND_FAILED)
	assert_true(binder.is_bound(), "单行 bind 拒绝不得被事务暂态误判为 ownership breach。")
	assert_null(binder.get_materialized_control(0))
	assert_not_null(binder.get_materialized_control(1), "后续行仍应完成同一事务提交。")
	assert_eq(result.get_materialized_count(), 5)
	assert_eq(GFVariantData.get_option_int(binder.get_debug_snapshot(), "pooled_count"), 0)
	assert_eq(_bind_events.size(), 6)
	assert_eq(_unbind_events.size(), 1)


func test_pool_budget_change_inside_bind_is_applied_after_transaction_commit() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	_fail_bind_index = 0
	_reentrant_mode = &"shrink_pool_on_bind"

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_BIND_FAILED)
	assert_true(binder.is_bound(), "callback 内收紧 pool 不得释放事务仍在引用的 Control。")
	assert_eq(result.get_pooled_count(), 0, "结果必须报告事务结束后执行的最终 pool 裁剪。")
	assert_null(binder.get_materialized_control(0))
	assert_not_null(binder.get_materialized_control(1))
	assert_eq(_bind_events.size(), 6)
	assert_eq(_unbind_events.size(), 1)


func test_unbind_callback_reparenting_owned_row_aborts_transaction_fail_closed() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var foreign_root: Control = Control.new()
	add_child(foreign_root)
	_nodes.append(foreign_root)
	_foreign_parent_for_callback = foreign_root
	_reentrant_mode = &"reparent_on_unbind"

	scroll_container.scroll_vertical = 100
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_true(binder.is_disposed())
	assert_eq(
		_unbind_events.size(),
		_bind_events.size(),
		"ownership breach teardown 仍须为每次成功 bind 提供一次对称 unbind。"
	)


func test_tree_entered_unbind_aborts_before_bind_and_allows_clean_rebind() -> void:
	_reentrant_mode = &"unbind_on_tree_enter"
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)

	var interrupted_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(interrupted_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_UNBOUND)
	assert_false(binder.is_bound())
	assert_false(binder.is_disposed(), "tree_entered 的显式 unbind 不得被暂态 parent 误升级为 dispose。")
	assert_eq(_bind_events.size(), 0, "generation 失效后不得调用迟到 bind callback。")
	assert_eq(_unbind_events.size(), 0)
	_reentrant_mode = &""
	assert_true(binder.bind(
		scroll_container,
		scroll_container,
		content_root,
		model,
		Callable(self, "_make_row"),
		Callable(self, "_bind_row"),
		Callable(self, "_unbind_row"),
		Callable(self, "_get_item_identity"),
		null,
		Callable(self, "_measure_row")
	))
	var rebound_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_true(rebound_result.is_successful(), "中断事务清理后同一 Binder 应保持可重绑。")


func test_measure_callback_ownership_breach_prevents_authoritative_extent_write() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var foreign_root: Control = Control.new()
	add_child(foreign_root)
	_nodes.append(foreign_root)
	_foreign_parent_for_callback = foreign_root
	_measured_extents[0] = 40.0
	_reentrant_mode = &"reparent_other_on_measure"
	assert_true(binder.request_measurement())

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_true(binder.is_disposed())
	assert_eq(
		model.get_item_extent(0),
		20.0,
		"measure callback 破坏其他 owned row 后不得继续写权威布局。"
	)


func test_focus_target_ownership_breach_prevents_physical_focus_side_effect() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var callback_state: Dictionary = { "binder": null, "count": 0 }
	var foreign_root: Control = Control.new()
	add_child(foreign_root)
	_nodes.append(foreign_root)
	var focus_target_callback: Callable = func(
		control: Control,
		_item_index: int,
		_item_id: Variant
	) -> Control:
		callback_state["count"] = GFVariantData.get_option_int(callback_state, "count") + 1
		var callback_binder: Variant = callback_state["binder"]
		if callback_binder is GF_VIRTUAL_LIST_BINDER_SCRIPT:
			var typed_binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = callback_binder
			var other_value: Variant = typed_binder.call("get_materialized_control", 4)
			if other_value is Control:
				var other_control: Control = other_value
				other_control.reparent(foreign_root)
		return control
	var fixture: Dictionary = _create_fixture(
		20, 100.0, 1, 32, focus_model, null, Vector2.ZERO, false, focus_target_callback
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	callback_state["binder"] = binder
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	get_viewport().gui_release_focus()
	var target_row: Control = binder.get_materialized_control(5)
	var target_focus_count: Array[int] = [0]
	var _focus_connected: Error = target_row.focus_entered.connect(
		func() -> void: target_focus_count[0] += 1
	) as Error

	assert_true(focus_model.set_focused_index(5))
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame

	assert_eq(GFVariantData.get_option_int(callback_state, "count"), 1)
	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_true(binder.is_disposed())
	assert_eq(target_focus_count[0], 0, "ownership barrier 必须位于 grab_focus 副作用之前。")


func test_layout_resize_teardown_prevents_pending_focus_callback() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var focus_callback_count: Array[int] = [0]
	var focus_target_callback: Callable = func(
		control: Control,
		_item_index: int,
		_item_id: Variant
	) -> Control:
		focus_callback_count[0] += 1
		return control
	var fixture: Dictionary = _create_fixture(
		20, 100.0, 1, 32, focus_model, null, Vector2.ZERO, false, focus_target_callback
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var target_row: Control = binder.get_materialized_control(5)
	var _resize_connected: Error = target_row.resized.connect(
		func() -> void: binder.dispose(),
		CONNECT_ONE_SHOT
	) as Error
	var _extent_report: Dictionary = model.set_item_extent(5, 40.0, false)
	assert_true(focus_model.set_focused_index(5))

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_eq(focus_callback_count[0], 0, "layout callback teardown 后不得再调用 focus target。")


func test_scroll_to_item_returns_false_when_scroll_callback_disposes_binding() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var _scroll_connected: Error = scroll_container.get_v_scroll_bar().value_changed.connect(
		func(_value: float) -> void: binder.dispose(),
		CONNECT_ONE_SHOT
	) as Error

	var scrolled: bool = binder.scroll_to_item(10)

	assert_false(scrolled, "滚动内部回调结束生命周期时不得报告成功。")
	assert_true(binder.is_disposed())


func test_scroll_to_item_returns_false_when_scroll_callback_invalidates_data_generation() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var _scroll_connected: Error = scroll_container.get_v_scroll_bar().value_changed.connect(
		func(_value: float) -> void:
			var _invalidated_from_scroll: bool = binder.invalidate_items(),
		CONNECT_ONE_SHOT
	) as Error

	var scrolled: bool = binder.scroll_to_item(10)

	assert_false(scrolled, "滚动信号改变 data generation 后不得报告旧索引操作成功。")
	assert_true(binder.is_bound())
	assert_eq(scroll_container.scroll_vertical, 120, "已接受的物理写入不伪装成事务提交。")
	var converged_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_true(converged_result.is_successful())
	assert_eq(converged_result.get_data_revision(), 1)


func test_scroll_to_item_aborts_when_scroll_callback_changes_snapshot() -> void:
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		Vector2.ZERO,
		false,
		Callable(),
		false
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	model.trailing_padding = 80.0
	var callback_count: Array[int] = [0]
	var _scroll_connected: Error = scroll_container.get_v_scroll_bar().value_changed.connect(
		func(_value: float) -> void:
			callback_count[0] += 1
			binder.layout_axis = GF_VIRTUAL_LIST_BINDER_SCRIPT.LayoutAxis.HORIZONTAL
			model.trailing_padding = 100.0
			scroll_container.scroll_vertical = 0
			var _requested: bool = binder.request_sync(),
		CONNECT_ONE_SHOT
	) as Error

	var scrolled: bool = binder.scroll_to_item(
		10,
		GF_VIRTUAL_LIST_BINDER_SCRIPT.ScrollAlignment.START
	)

	assert_false(scrolled, "滚动回调改变 operation snapshot 后不得报告混合状态成功。")
	assert_eq(callback_count[0], 1)
	assert_eq(scroll_container.scroll_vertical, 0)
	assert_eq(scroll_container.scroll_horizontal, 0)
	assert_eq(content_root.custom_minimum_size.y, 480.0, "已发生的写入必须保持旧轮内部一致。")

	var next_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_true(next_result.is_successful())
	assert_eq(content_root.custom_minimum_size, Vector2(500.0, 0.0))
	assert_true(binder.is_bound(), "operation 漂移只拒绝本次滚动，不破坏绑定生命周期。")


func test_scroll_to_item_fails_closed_when_scroll_callback_reparents_owned_row() -> void:
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		Vector2.ZERO,
		false,
		Callable(),
		false
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	await get_tree().process_frame
	var owned_row: Control = binder.get_materialized_control(1)
	assert_not_null(owned_row)
	if owned_row == null:
		return
	var foreign_root: Control = Control.new()
	add_child(foreign_root)
	_nodes.append(foreign_root)
	var _scroll_connected: Error = scroll_container.get_v_scroll_bar().value_changed.connect(
		func(_value: float) -> void: owned_row.reparent(foreign_root),
		CONNECT_ONE_SHOT
	) as Error

	var scrolled: bool = binder.scroll_to_item(
		10,
		GF_VIRTUAL_LIST_BINDER_SCRIPT.ScrollAlignment.START
	)

	assert_false(scrolled)
	assert_true(binder.is_disposed(), "public operation 的信号边界也必须验证完整 owned set。")


func test_callback_reentrancy_is_coalesced_and_dispose_aborts_generation() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	_reentrant_mode = &"request_sync"
	var first_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(first_result.is_successful(), "bind callback 的 refresh 请求不得递归破坏当前提交。")
	assert_eq(first_result.get_materialized_count(), 6)
	_reentrant_mode = &"dispose"
	var _invalidated: bool = binder.invalidate_items()
	var disposed_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(binder.is_disposed(), "callback 中 dispose 应使当前 generation 失效并完成清理。")
	assert_eq(disposed_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_eq(_unbind_events.size(), _bind_events.size(), "每次已调用的 bind 都必须有且仅有一次对称 unbind。")


func test_bind_callback_invalidation_defers_and_rebuilds_the_next_generation() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	_reentrant_mode = &"invalidate_items"
	_invalidate_callback_budget = 1
	var first_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(first_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(first_result.is_successful(), "失效快照不得伪装成成功提交。")
	assert_eq(first_result.get_data_revision(), 0, "结果只报告本轮开始时冻结的 data revision。")
	assert_eq(first_result.get_materialized_count(), 0, "带项目副作用的漂移必须清空不可信 materialization。")
	assert_eq(_bind_events.size(), 1, "首个 bind 漂移后不得继续读取后续数据世代。")
	assert_eq(_unbind_events.size(), 1, "每次已调用 bind 必须在回滚时精确对称 unbind。")
	assert_eq(_get_last_committed_data_revision(binder), -1, "deferred 不得推进提交 revision。")
	assert_true(GFVariantData.get_option_bool(binder.get_debug_snapshot(), "pending_sync"))

	var second_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(second_result.is_successful())
	assert_eq(second_result.get_data_revision(), 1)
	assert_eq(_unbind_events.size(), 1)
	assert_eq(_bind_events.size(), 7, "下一轮必须从清空状态按新 generation 完整重建。")
	assert_eq(second_result.get_materialized_count(), 6)
	assert_gt(second_result.get_measured_count(), 0, "invalidate 的测量请求也不得被上一轮清除。")


func test_identity_callback_invalidation_stops_before_factory_and_commits_next_generation() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	_reentrant_mode = &"invalidate_identity"
	_invalidate_callback_budget = 1

	var deferred_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(deferred_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(deferred_result.is_successful())
	assert_eq(_identity_callback_count, 1, "identity 漂移后不得读取下一条目。")
	assert_eq(_factory_count, 0, "失效 identity 计划不得进入 staging。")
	assert_eq(_bind_events.size(), 0)
	assert_eq(deferred_result.get_materialized_count(), 0)
	assert_eq(_get_last_committed_data_revision(binder), -1)

	var rebuilt_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(rebuilt_result.is_successful())
	assert_eq(rebuilt_result.get_data_revision(), 1)
	assert_eq(_identity_callback_count, 7)
	assert_eq(_factory_count, 6)
	assert_not_null(binder.get_materialized_control_by_id(&"replacement_0"))


func test_deferred_identity_plan_preserves_truncation_diagnostic() -> void:
	var fixture: Dictionary = _create_fixture(100, 100.0, 5, 3)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	_reentrant_mode = &"invalidate_identity"
	_invalidate_callback_budget = 1

	var deferred_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(deferred_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(deferred_result.is_successful())
	assert_true(deferred_result.was_truncated(), "deferred 不得丢失本轮已确定的节点预算截断。")
	assert_eq(deferred_result.get_materialized_count(), 0)
	assert_eq(_factory_count, 0)


func test_factory_invalidation_rolls_back_parentless_stage_before_binding() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	_reentrant_mode = &"invalidate_in_factory"
	_invalidate_callback_budget = 1

	var deferred_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(deferred_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(deferred_result.is_successful())
	assert_eq(_factory_count, 1, "factory 漂移后不得继续创建候选。")
	assert_eq(_bind_events.size(), 0)
	assert_eq(_unbind_events.size(), 0)
	assert_eq(deferred_result.get_materialized_count(), 0)
	assert_eq(deferred_result.get_created_count(), 1)
	assert_eq(deferred_result.get_reused_count(), 0)
	assert_eq(deferred_result.get_pooled_count(), 1, "回滚后的 pool 诊断必须反映真实候选归还。")
	assert_not_null(_last_factory_control)
	if _last_factory_control != null:
		assert_null(_last_factory_control.get_parent(), "staged Control 必须回滚为 parentless pool。")

	var rebuilt_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(rebuilt_result.is_successful())
	assert_eq(rebuilt_result.get_data_revision(), 1)
	assert_eq(rebuilt_result.get_materialized_count(), 6)


func test_unbind_callback_invalidation_clears_unknown_materialization_and_rebuilds() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_true(initial_result.is_successful())
	_reentrant_mode = &"invalidate_on_unbind"
	_invalidate_callback_budget = 1
	assert_true(binder.invalidate_items())

	var deferred_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(deferred_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(deferred_result.is_successful())
	assert_eq(deferred_result.get_materialized_count(), 0)
	assert_eq(deferred_result.get_released_count(), 6, "回滚诊断必须计入全部实际旧 binding 释放。")
	assert_eq(_unbind_events.size(), 6, "旧 active binding 必须各自精确 unbind 一次。")
	assert_eq(_bind_events.size(), 6, "漂移后不得调用新 generation bind。")
	assert_true(binder.is_bound())

	var rebuilt_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(rebuilt_result.is_successful())
	assert_eq(rebuilt_result.get_data_revision(), 2)
	assert_eq(rebuilt_result.get_materialized_count(), 6)
	assert_eq(_bind_events.size(), 12)
	assert_eq(_unbind_events.size(), 6)


func test_measurement_invalidation_stops_before_authoritative_extent_write() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	_reentrant_mode = &"invalidate_on_measure"
	_invalidate_callback_budget = 1
	_measured_extents[0] = 37.0

	var deferred_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(deferred_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(deferred_result.is_successful())
	assert_eq(model.get_item_extent(0), 20.0, "漂移 measurement 不得写入权威布局模型。")
	assert_eq(deferred_result.get_measured_count(), 0)
	assert_eq(deferred_result.get_materialized_count(), 0)
	assert_eq(_bind_events.size(), 6)
	assert_eq(_unbind_events.size(), 6)

	var rebuilt_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(rebuilt_result.is_successful())
	assert_eq(model.get_item_extent(0), 37.0)
	assert_gt(rebuilt_result.get_measured_count(), 0)


func test_layout_signal_invalidation_reports_completed_authoritative_measurement() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	_measured_extents[0] = 37.0
	var callback_budget: Array[int] = [1]
	var _layout_connected: Error = model.layout_changed.connect(
		func(_revision: int) -> void:
			if not _binder_sync_is_in_progress(binder) or callback_budget[0] <= 0:
				return
			callback_budget[0] -= 1
			var _invalidated_from_layout: bool = binder.invalidate_items()
	) as Error
	assert_true(binder.request_measurement())

	var deferred_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(deferred_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(deferred_result.is_successful())
	assert_eq(model.get_item_extent(0), 37.0, "信号返回前已完成的权威写入必须保留。")
	assert_eq(deferred_result.get_measured_count(), 1, "诊断必须计入已成功完成的测量写入。")
	assert_eq(deferred_result.get_materialized_count(), 0)
	assert_eq(_unbind_events.size(), 6)

	var rebuilt_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_true(rebuilt_result.is_successful())
	assert_eq(rebuilt_result.get_data_revision(), 1)


func test_focus_target_invalidation_stops_before_grab_focus_and_rebuilds() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		focus_model,
		null,
		Vector2.ZERO,
		false,
		Callable(self, "_resolve_focus_target")
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_true(initial_result.is_successful())
	_reentrant_mode = &"invalidate_on_focus_target"
	_invalidate_callback_budget = 1
	assert_true(focus_model.set_focused_index(1))

	var deferred_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(deferred_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(deferred_result.is_successful())
	assert_eq(deferred_result.get_materialized_count(), 0)
	assert_null(get_viewport().gui_get_focus_owner(), "漂移 focus callback 后不得继续 grab_focus。")
	assert_eq(_unbind_events.size(), 6)

	var rebuilt_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var rebuilt_row: Control = binder.get_materialized_control(1)

	assert_true(rebuilt_result.is_successful())
	assert_not_null(rebuilt_row)
	assert_same(get_viewport().gui_get_focus_owner(), rebuilt_row)


func test_layout_resize_invalidation_stops_remaining_control_writes() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_true(initial_result.is_successful())
	binder.auto_measure = false
	var first_row: Control = binder.get_materialized_control(0)
	assert_not_null(first_row)
	if first_row == null:
		return
	var _resize_connected: Error = first_row.resized.connect(
		func() -> void:
			var _invalidated_from_resize: bool = binder.invalidate_items(),
		CONNECT_ONE_SHOT
	) as Error
	var _extent_report: Dictionary = model.set_item_extent(0, 40.0, false)

	var deferred_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(deferred_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(deferred_result.is_successful())
	assert_eq(deferred_result.get_materialized_count(), 0)
	assert_eq(_unbind_events.size(), 6, "Control signal 漂移后必须清空全部旧 active binding。")

	var rebuilt_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(rebuilt_result.is_successful())
	assert_eq(rebuilt_result.get_materialized_count(), 5)
	assert_eq(model.get_item_extent(0), 40.0)


func test_scroll_listener_layout_drift_returns_non_successful_deferred_snapshot() -> void:
	var focus_model: GFVirtualListFocusModel = GFVirtualListFocusModel.new()
	var fixture: Dictionary = _create_fixture(20, 100.0, 1, 512, focus_model)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_true(initial_result.is_successful())
	binder.auto_measure = false
	await get_tree().process_frame
	var callback_budget: Array[int] = [1]
	var _scroll_connected: Error = scroll_container.get_v_scroll_bar().value_changed.connect(
		func(_value: float) -> void:
			if not _binder_sync_is_in_progress(binder) or callback_budget[0] <= 0:
				return
			callback_budget[0] -= 1
			model.trailing_padding = 80.0
			scroll_container.scroll_vertical = 0
	) as Error
	assert_true(focus_model.set_focused_index(10))
	scroll_container.scroll_vertical = 0
	var frozen_layout_revision: int = model.get_revision()

	var deferred_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(deferred_result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(deferred_result.is_successful(), "未提交滚动快照不得使用 UNCHANGED 成功语义。")
	assert_eq(deferred_result.get_layout_revision(), frozen_layout_revision)
	assert_eq(deferred_result.get_requested_range(), Vector2i(5, 12))
	assert_eq(deferred_result.get_materialized_count(), 6, "pre-commit 漂移应保留最近可信 materialization。")
	assert_eq(_bind_events.size(), 6)
	assert_eq(_unbind_events.size(), 0)

	var converged_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(converged_result.is_successful())
	assert_eq(converged_result.get_layout_revision(), model.get_revision())
	assert_gt(scroll_container.scroll_vertical, 0)


func test_bind_callback_layout_change_is_reported_by_the_next_sync() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var initial_layout_revision: int = model.get_revision()
	_layout_model_for_callback = model
	_layout_callback_budget = 1
	_reentrant_mode = &"change_layout"

	var first_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(first_result.is_successful())
	assert_eq(first_result.get_layout_revision(), initial_layout_revision)
	assert_eq(first_result.get_requested_range(), Vector2i(0, 6), "首轮范围必须对应冻结 revision。")
	assert_eq(first_result.get_measured_count(), 0, "外部布局 revision 漂移后不得写入旧轮测量。")
	assert_gt(model.get_revision(), initial_layout_revision, "callback 与测量可以排队后续 layout revision。")
	var second_layout_revision: int = model.get_revision()

	var second_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(second_result.is_successful())
	assert_eq(second_result.get_layout_revision(), second_layout_revision)
	assert_eq(second_result.get_requested_range(), Vector2i(0, 8))
	assert_eq(second_result.get_materialized_count(), 8)
	assert_gt(second_result.get_measured_count(), 0, "被跳过的测量请求必须保留到下一轮。")


func test_layout_geometry_change_inside_bind_is_isolated_to_next_sync_round() -> void:
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		Vector2.ZERO,
		false,
		Callable(),
		false
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	binder.auto_measure = false
	_layout_model_for_callback = model
	_layout_callback_budget = 1
	_reentrant_mode = &"change_layout_geometry"
	var initial_layout_revision: int = model.get_revision()
	assert_true(binder.invalidate_items())

	var frozen_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var frozen_second_row: Control = binder.get_materialized_control(1)

	assert_true(frozen_result.is_successful())
	assert_eq(frozen_result.get_layout_revision(), initial_layout_revision)
	assert_eq(frozen_result.get_requested_range(), Vector2i(0, 6))
	assert_eq(content_root.custom_minimum_size.y, 400.0, "当前轮 content extent 必须来自冻结布局。")
	assert_not_null(frozen_second_row)
	if frozen_second_row != null:
		assert_eq(frozen_second_row.position.y, 20.0)
	assert_eq(model.get_content_extent(), 800.0, "callback 的模型写入应立即进入模型但不污染当前轮。")

	var next_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var next_second_row: Control = binder.get_materialized_control(1)

	assert_true(next_result.is_successful())
	assert_eq(next_result.get_layout_revision(), model.get_revision())
	assert_eq(next_result.get_requested_range(), Vector2i(0, 4))
	assert_eq(content_root.custom_minimum_size.y, 800.0)
	assert_not_null(next_second_row)
	if next_second_row != null:
		assert_eq(next_second_row.position.y, 40.0)


func test_round_geometry_snapshot_preserves_float64_layout_math() -> void:
	var fixture: Dictionary = _create_fixture(
		3,
		100.0,
		1,
		512,
		null,
		null,
		Vector2.ZERO,
		false,
		Callable(),
		false
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var large_extent: float = 100_000_003.25
	var _extent_report: Dictionary = model.set_item_extent(0, large_extent, true)
	_reentrant_mode = &"capture_round_geometry"

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(result.is_successful())
	assert_true(_captured_round_geometry)
	assert_eq(_captured_round_extent, 20.0)
	assert_eq(_captured_round_offset, model.get_item_offset(1))
	assert_eq(_captured_round_offset, large_extent, "轮次布局数学不得提前降为 Vector2/Float32。")


func test_explicit_measurement_survives_invalidation_when_auto_measure_is_disabled() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	binder.auto_measure = false
	_measured_extents[0] = 37.0
	assert_true(binder.request_measurement())
	assert_true(binder.invalidate_items())

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(result.is_successful())
	assert_gt(result.get_measured_count(), 0)
	assert_eq(model.get_item_extent(0), 37.0, "invalidate 不得清除显式测量请求。")


func test_measurement_callback_requeue_runs_in_the_next_sync() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	_reentrant_mode = &"request_measurement"
	_measurement_requeue_budget = 1

	var first_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(first_result.is_successful())
	assert_gt(first_result.get_measured_count(), 0)
	var second_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_true(second_result.is_successful())
	assert_gt(second_result.get_measured_count(), 0, "测量 callback 的重测请求必须留给下一轮。")


func test_unbind_callback_can_escalate_teardown_to_dispose_without_recursion() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	_reentrant_mode = &"dispose_on_unbind"

	binder.unbind()

	assert_true(binder.is_disposed(), "unbind callback 中请求 dispose 应升级为单次终态 teardown。")
	assert_eq(_unbind_events.size(), _bind_events.size(), "teardown 升级不得递归或重复 unbind。")


func test_sync_completed_recursive_sync_is_coalesced_into_next_generation() -> void:
	var fixture: Dictionary = _create_fixture(20, 100.0, 1)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var connected: Error = binder.sync_completed.connect(
		Callable(self, "_on_sync_completed_reentrant")
	) as Error
	assert_eq(connected, OK)

	var first_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(first_result.is_successful())
	assert_eq(_sync_completed_event_count, 1, "监听器内 sync_now 不得同步递归发出第二个事件。")
	assert_not_null(_reentrant_sync_result)
	var second_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_true(second_result.is_successful())
	assert_eq(_sync_completed_event_count, 2, "递归请求应合并到下一轮。")
	assert_true(binder.is_bound())


func test_axis_switch_restores_only_previous_owned_axis() -> void:
	var original_minimum: Vector2 = Vector2(13.0, 17.0)
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		original_minimum
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_eq(content_root.custom_minimum_size.x, original_minimum.x)
	assert_eq(content_root.custom_minimum_size.y, model.get_content_extent())

	binder.layout_axis = GF_VIRTUAL_LIST_BINDER_SCRIPT.LayoutAxis.HORIZONTAL
	var _horizontal_requested: bool = binder.request_sync()
	var _horizontal_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_eq(content_root.custom_minimum_size.x, model.get_content_extent())
	assert_eq(content_root.custom_minimum_size.y, original_minimum.y, "切轴必须先恢复旧 owned 轴。")

	binder.layout_axis = GF_VIRTUAL_LIST_BINDER_SCRIPT.LayoutAxis.VERTICAL
	var _vertical_requested: bool = binder.request_sync()
	var _vertical_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	assert_eq(content_root.custom_minimum_size.x, original_minimum.x)
	assert_eq(content_root.custom_minimum_size.y, model.get_content_extent())


func test_axis_change_inside_bind_is_isolated_to_next_sync_round() -> void:
	var original_minimum: Vector2 = Vector2(13.0, 17.0)
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		original_minimum,
		false,
		Callable(),
		false
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var model: GFVirtualListModel = _get_fixture_model(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	binder.auto_measure = false
	_reentrant_mode = &"change_axis_on_bind"
	assert_true(binder.invalidate_items())

	var vertical_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var vertical_second_row: Control = binder.get_materialized_control(1)

	assert_true(vertical_result.is_successful())
	assert_eq(content_root.custom_minimum_size, Vector2(original_minimum.x, model.get_content_extent()))
	assert_not_null(vertical_second_row)
	if vertical_second_row != null:
		assert_eq(vertical_second_row.position, Vector2(0.0, 20.0))

	var horizontal_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var horizontal_second_row: Control = binder.get_materialized_control(1)

	assert_true(horizontal_result.is_successful())
	assert_eq(content_root.custom_minimum_size, Vector2(model.get_content_extent(), original_minimum.y))
	assert_not_null(horizontal_second_row)
	if horizontal_second_row != null:
		assert_eq(horizontal_second_row.position, Vector2(20.0, 0.0))


func test_fill_cross_axis_change_during_layout_is_isolated_to_next_sync_round() -> void:
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		Vector2.ZERO,
		false,
		Callable(),
		false
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	binder.auto_measure = false
	binder.fill_cross_axis = false
	var first_row: Control = binder.get_materialized_control(0)
	assert_not_null(first_row)
	if first_row == null:
		return
	for item_index: int in initial_result.get_materialized_indices():
		var row: Control = binder.get_materialized_control(item_index)
		if row != null:
			row.size.x = 120.0 + float(item_index)
	first_row.size.y = 40.0
	var _resized_connected: Error = first_row.resized.connect(
		func() -> void:
			binder.fill_cross_axis = true
			var _requested: bool = binder.request_sync(),
		CONNECT_ONE_SHOT
	) as Error
	assert_true(binder.request_sync())

	var unfilled_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var second_row: Control = binder.get_materialized_control(1)

	assert_true(unfilled_result.is_successful())
	assert_true(binder.fill_cross_axis)
	assert_not_null(second_row)
	if second_row != null:
		assert_eq(second_row.size.x, 121.0, "当前轮所有行必须继续使用冻结的非填充策略。")

	var filled_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	second_row = binder.get_materialized_control(1)

	assert_true(filled_result.is_successful())
	assert_not_null(second_row)
	if second_row != null:
		assert_eq(second_row.position.x, 0.0)
		assert_eq(second_row.size.x, scroll_container.size.x, "下一轮才应用新的交叉轴填充策略。")


func test_cross_extent_change_during_row_resize_is_isolated_to_next_sync_round() -> void:
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		Vector2.ZERO,
		false,
		Callable(),
		false
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var scroll_container: ScrollContainer = _get_fixture_scroll(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var first_row: Control = binder.get_materialized_control(0)
	var second_row: Control = binder.get_materialized_control(1)
	assert_not_null(first_row)
	assert_not_null(second_row)
	if first_row == null or second_row == null:
		return
	scroll_container.size.x = 300.0
	var _resized_connected: Error = first_row.resized.connect(
		func() -> void: scroll_container.size.x = 360.0,
		CONNECT_ONE_SHOT
	) as Error

	var frozen_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(frozen_result.is_successful())
	assert_eq(first_row.size.x, 300.0)
	assert_eq(second_row.size.x, 300.0, "同一轮全部行必须使用入口冻结的 cross extent。")

	var next_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_true(next_result.is_successful())
	assert_eq(first_row.size.x, 360.0)
	assert_eq(second_row.size.x, 360.0)


func test_layout_ownership_breach_stops_before_writing_later_rows() -> void:
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		Vector2.ZERO,
		false,
		Callable(),
		false
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var first_row: Control = binder.get_materialized_control(0)
	var second_row: Control = binder.get_materialized_control(1)
	assert_not_null(first_row)
	assert_not_null(second_row)
	if first_row == null or second_row == null:
		return
	var foreign_root: Control = Control.new()
	add_child(foreign_root)
	_nodes.append(foreign_root)
	var external_position: Vector2 = Vector2(777.0, 888.0)
	first_row.size.y = 40.0
	var _resized_connected: Error = first_row.resized.connect(
		func() -> void:
			second_row.reparent(foreign_root)
			second_row.position = external_position,
		CONNECT_ONE_SHOT
	) as Error
	assert_true(binder.request_sync())

	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DISPOSED)
	assert_true(binder.is_disposed())
	assert_true(is_instance_valid(second_row))
	if is_instance_valid(second_row):
		assert_eq(
			second_row.position,
			external_position,
			"ownership breach 后 Binder 不得继续写入已转交到外部 parent 的后续行。"
		)


func test_teardown_preserves_project_change_on_unowned_cross_axis() -> void:
	var original_minimum: Vector2 = Vector2(13.0, 17.0)
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		original_minimum
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var project_minimum: Vector2 = content_root.custom_minimum_size
	project_minimum.x = 91.0
	content_root.custom_minimum_size = project_minimum

	binder.dispose()

	assert_eq(content_root.custom_minimum_size.x, 91.0, "teardown 不得覆盖项目对未拥有轴的修改。")
	assert_eq(content_root.custom_minimum_size.y, original_minimum.y, "实际 owned 轴应恢复绑定前分量。")


func test_horizontal_acquisition_captures_latest_unowned_x_baseline() -> void:
	var original_minimum: Vector2 = Vector2(13.0, 17.0)
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		original_minimum
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var project_minimum: Vector2 = content_root.custom_minimum_size
	project_minimum.x = 91.0
	content_root.custom_minimum_size = project_minimum
	binder.layout_axis = GF_VIRTUAL_LIST_BINDER_SCRIPT.LayoutAxis.HORIZONTAL
	var _requested: bool = binder.request_sync()
	var _horizontal_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	binder.dispose()

	assert_eq(content_root.custom_minimum_size.x, 91.0, "horizontal 接管应捕获项目最新的 unowned x。")
	assert_eq(content_root.custom_minimum_size.y, original_minimum.y)


func test_vertical_acquisition_captures_latest_unowned_y_baseline() -> void:
	var original_minimum: Vector2 = Vector2(13.0, 17.0)
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		original_minimum,
		true
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var project_minimum: Vector2 = content_root.custom_minimum_size
	project_minimum.y = 93.0
	content_root.custom_minimum_size = project_minimum
	binder.layout_axis = GF_VIRTUAL_LIST_BINDER_SCRIPT.LayoutAxis.VERTICAL
	var _requested: bool = binder.request_sync()
	var _vertical_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()

	binder.dispose()

	assert_eq(content_root.custom_minimum_size.x, original_minimum.x)
	assert_eq(content_root.custom_minimum_size.y, 93.0, "vertical 接管应捕获项目最新的 unowned y。")


func test_invalid_dynamic_layout_axis_write_preserves_owned_axis_and_baseline() -> void:
	var original_minimum: Vector2 = Vector2(13.0, 17.0)
	var fixture: Dictionary = _create_fixture(
		20,
		100.0,
		1,
		512,
		null,
		null,
		original_minimum
	)
	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = _get_fixture_binder(fixture)
	var content_root: Control = _get_fixture_content(fixture)
	var _initial_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var _settled_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = binder.sync_now()
	var project_minimum: Vector2 = content_root.custom_minimum_size
	project_minimum.x = 91.0
	content_root.custom_minimum_size = project_minimum
	var pending_before: bool = GFVariantData.get_option_bool(
		binder.get_debug_snapshot(),
		"pending_sync"
	)

	binder.set(&"layout_axis", 999)

	assert_eq(binder.layout_axis, GF_VIRTUAL_LIST_BINDER_SCRIPT.LayoutAxis.VERTICAL)
	assert_eq(
		GFVariantData.get_option_bool(binder.get_debug_snapshot(), "pending_sync"),
		pending_before,
		"非法轴写入不得隐式请求同步。"
	)
	binder.dispose()
	assert_eq(content_root.custom_minimum_size.x, 91.0, "非法轴写入不得改变 unowned 轴。")
	assert_eq(content_root.custom_minimum_size.y, original_minimum.y, "teardown 应继续恢复原 owned 轴 baseline。")


func test_sync_result_to_dict_is_json_safe_and_round_trips() -> void:
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = _make_configured_sync_result()
	var report: Dictionary = result.to_dict()
	var viewport_range: Dictionary = GFVariantData.get_option_dictionary(
		report,
		"viewport_range"
	)
	var requested_range: Dictionary = GFVariantData.get_option_dictionary(
		report,
		"requested_range"
	)

	assert_eq(typeof(GFVariantData.get_option_value(report, "status")), TYPE_STRING)
	assert_eq(typeof(GFVariantData.get_option_value(report, "viewport_range")), TYPE_DICTIONARY)
	assert_eq(typeof(GFVariantData.get_option_value(report, "requested_range")), TYPE_DICTIONARY)
	assert_eq(typeof(GFVariantData.get_option_value(report, "materialized_indices")), TYPE_ARRAY)
	assert_eq(viewport_range, { "start": 3, "end_exclusive": 8 })
	assert_eq(requested_range, { "start": 2, "end_exclusive": 10 })
	assert_eq(
		GFVariantData.get_option_array(report, "materialized_indices"),
		[3, 4, 7]
	)

	var encoded: String = JSON.stringify(report)
	assert_false(encoded.is_empty(), "JSON-safe 同步摘要必须可直接编码。")
	assert_false(encoded.contains(":null"), "同步摘要不得依赖 JSON.stringify 降级非法值。")
	var parsed_value: Variant = JSON.parse_string(encoded)
	assert_eq(typeof(parsed_value), TYPE_DICTIONARY, "编码后的同步摘要必须能解析为 Dictionary。")
	var parsed: Dictionary = GFVariantData.as_dictionary(parsed_value)
	var restored: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()
	assert_true(restored.configure_for_framework(parsed), "configure 应接受 JSON 往返后的纯数据形状。")
	assert_eq(restored.to_dict(), report, "JSON 往返不得丢失同步诊断字段。")


func test_sync_result_duplicate_preserves_every_field() -> void:
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = _make_configured_sync_result()
	var result_copy: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = result.duplicate_result()

	assert_ne(result_copy, result, "duplicate_result 必须返回独立对象。")
	assert_eq(result_copy.to_dict(), result.to_dict(), "duplicate_result 不得丢失任何诊断字段。")
	assert_eq(result_copy.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_BIND_FAILED)
	assert_eq(result_copy.get_viewport_range(), Vector2i(3, 8))
	assert_eq(result_copy.get_requested_range(), Vector2i(2, 10))
	assert_eq(result_copy.get_materialized_indices(), PackedInt32Array([3, 4, 7]))
	assert_eq(result_copy.get_anchor_adjustment(), -12.5)
	assert_eq(result_copy.get_error_index(), 7)
	assert_eq(result_copy.get_error(), "row binding rejected")


func test_sync_result_deferred_is_known_non_successful_and_round_trips() -> void:
	var data: Dictionary = _make_sync_result_data()
	data["status"] = GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED
	data["error_index"] = -1
	data["error"] = ""
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()

	assert_true(result.configure_for_framework(data))
	assert_eq(result.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(result.is_successful())
	var report: Dictionary = result.to_dict()
	assert_eq(GFVariantData.get_option_string(report, "status"), "deferred")
	var parsed_value: Variant = JSON.parse_string(JSON.stringify(report))
	assert_eq(typeof(parsed_value), TYPE_DICTIONARY)
	var restored: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()
	assert_true(restored.configure_for_framework(GFVariantData.as_dictionary(parsed_value)))
	assert_eq(restored.get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)
	assert_false(restored.is_successful())
	assert_eq(result.duplicate_result().get_status(), GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_DEFERRED)


func test_sync_result_accepts_json_safe_integer_boundaries_and_round_trips_exactly() -> void:
	var minimum_data: Dictionary = _make_sync_result_data()
	for field: String in _NONNEGATIVE_JSON_INTEGER_FIELDS:
		minimum_data[field] = 0
	minimum_data["error_index"] = -1
	var minimum_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = (
		GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()
	)
	assert_true(minimum_result.configure_for_framework(minimum_data))

	var maximum_data: Dictionary = _make_sync_result_data()
	for field: String in _NONNEGATIVE_JSON_INTEGER_FIELDS:
		maximum_data[field] = _JSON_SAFE_INTEGER_MAX
	maximum_data["error_index"] = _JSON_SAFE_INTEGER_MAX
	var maximum_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = (
		GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()
	)
	assert_true(maximum_result.configure_for_framework(maximum_data))
	var encoded: String = JSON.stringify(maximum_result.to_dict())
	var parsed_value: Variant = JSON.parse_string(encoded)
	assert_eq(typeof(parsed_value), TYPE_DICTIONARY)
	var restored: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()
	assert_true(restored.configure_for_framework(GFVariantData.as_dictionary(parsed_value)))
	var restored_report: Dictionary = restored.to_dict()
	for field: String in _NONNEGATIVE_JSON_INTEGER_FIELDS:
		assert_eq(
			GFVariantData.get_option_int(restored_report, field),
			_JSON_SAFE_INTEGER_MAX,
			"JSON safe integer 上界必须精确往返：%s。" % field
		)
	assert_eq(restored.get_error_index(), _JSON_SAFE_INTEGER_MAX)
	assert_eq(restored_report, maximum_result.to_dict())


func test_sync_result_rejects_out_of_range_integers_before_freezing() -> void:
	for field: String in _NONNEGATIVE_JSON_INTEGER_FIELDS:
		var too_large_data: Dictionary = _make_sync_result_data()
		too_large_data[field] = _JSON_SAFE_INTEGER_MAX + 1
		var too_large_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = (
			GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()
		)
		assert_false(
			too_large_result.configure_for_framework(too_large_data),
			"MAX + 1 必须拒绝：%s。" % field
		)
		assert_true(
			too_large_result.configure_for_framework(_make_sync_result_data()),
			"越界失败不得提前冻结结果：%s。" % field
		)

		var negative_data: Dictionary = _make_sync_result_data()
		negative_data[field] = -1
		var negative_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = (
			GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()
		)
		assert_false(
			negative_result.configure_for_framework(negative_data),
			"revision/count 不得为负数：%s。" % field
		)

	for invalid_error_index: int in [-2, _JSON_SAFE_INTEGER_MAX + 1]:
		var invalid_error_data: Dictionary = _make_sync_result_data()
		invalid_error_data["error_index"] = invalid_error_index
		var invalid_error_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = (
			GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()
		)
		assert_false(
			invalid_error_result.configure_for_framework(invalid_error_data),
			"error_index 必须位于 -1..MAX。"
		)


func test_sync_result_json_inputs_and_reports_are_alias_isolated() -> void:
	var typed_indices: PackedInt32Array = PackedInt32Array([3, 4, 7])
	var typed_data: Dictionary = _make_sync_result_data()
	typed_data["materialized_indices"] = typed_indices
	var typed_result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()
	assert_true(typed_result.configure_for_framework(typed_data))
	typed_indices[0] = 99
	var _typed_append_result: bool = typed_indices.append(100)
	assert_eq(
		typed_result.get_materialized_indices(),
		PackedInt32Array([3, 4, 7]),
		"configure 必须复制 typed PackedInt32Array 输入。"
	)

	var source: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = _make_configured_sync_result()
	var input_report: Dictionary = source.to_dict()
	var restored: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()
	assert_true(restored.configure_for_framework(input_report))

	var input_viewport_value: Variant = input_report.get("viewport_range")
	assert_true(input_viewport_value is Dictionary)
	if not input_viewport_value is Dictionary:
		return
	var input_viewport: Dictionary = input_viewport_value
	input_viewport["start"] = 99
	var input_indices_value: Variant = input_report.get("materialized_indices")
	assert_true(input_indices_value is Array)
	if not input_indices_value is Array:
		return
	var input_indices: Array = input_indices_value
	input_indices[0] = 99
	input_indices.append(100)
	assert_eq(restored.get_viewport_range(), Vector2i(3, 8), "configure 必须复制 JSON range。")
	assert_eq(
		restored.get_materialized_indices(),
		PackedInt32Array([3, 4, 7]),
		"configure 必须复制 JSON index array。"
	)

	var exported: Dictionary = restored.to_dict()
	var exported_requested_value: Variant = exported.get("requested_range")
	assert_true(exported_requested_value is Dictionary)
	if not exported_requested_value is Dictionary:
		return
	var exported_requested: Dictionary = exported_requested_value
	exported_requested["end_exclusive"] = 999
	var exported_indices_value: Variant = exported.get("materialized_indices")
	assert_true(exported_indices_value is Array)
	if not exported_indices_value is Array:
		return
	var exported_indices: Array = exported_indices_value
	exported_indices.clear()
	assert_eq(restored.get_requested_range(), Vector2i(2, 10), "to_dict range 不得引用内部状态。")
	assert_eq(
		restored.get_materialized_indices(),
		PackedInt32Array([3, 4, 7]),
		"to_dict index array 不得引用内部状态。"
	)
	var result_copy: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = restored.duplicate_result()
	var copy_report: Dictionary = result_copy.to_dict()
	var copy_viewport_value: Variant = copy_report.get("viewport_range")
	assert_true(copy_viewport_value is Dictionary)
	if not copy_viewport_value is Dictionary:
		return
	var copy_viewport: Dictionary = copy_viewport_value
	copy_viewport["start"] = 777
	var copy_indices_value: Variant = copy_report.get("materialized_indices")
	assert_true(copy_indices_value is Array)
	if not copy_indices_value is Array:
		return
	var copy_indices: Array = copy_indices_value
	copy_indices[0] = 777
	assert_eq(result_copy.get_viewport_range(), Vector2i(3, 8))
	assert_eq(result_copy.get_materialized_indices(), PackedInt32Array([3, 4, 7]))
	assert_eq(restored.get_viewport_range(), Vector2i(3, 8))
	assert_eq(restored.get_materialized_indices(), PackedInt32Array([3, 4, 7]))


# --- 私有/辅助方法 ---

func _binder_sync_is_in_progress(binder: GF_VIRTUAL_LIST_BINDER_SCRIPT) -> bool:
	var value: Variant = binder.get("_sync_in_progress")
	if value is bool:
		var in_progress: bool = value
		return in_progress
	return false


func _get_last_committed_data_revision(binder: GF_VIRTUAL_LIST_BINDER_SCRIPT) -> int:
	var value: Variant = binder.get("_last_committed_data_revision")
	if value is int:
		var revision: int = value
		return revision
	return -2


func _make_configured_sync_result() -> GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT:
	var result: GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT = GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.new()
	var configured: bool = result.configure_for_framework(_make_sync_result_data())
	assert_true(configured, "同步结果 fixture 必须成功配置。")
	return result


func _make_sync_result_data() -> Dictionary:
	return {
		"status": GF_VIRTUAL_LIST_SYNC_RESULT_SCRIPT.STATUS_BIND_FAILED,
		"layout_revision": 17,
		"data_revision": 19,
		"viewport_range": Vector2i(3, 8),
		"requested_range": Vector2i(2, 10),
		"materialized_indices": PackedInt32Array([3, 4, 7]),
		"pooled_count": 2,
		"created_count": 3,
		"reused_count": 4,
		"released_count": 5,
		"measured_count": 6,
		"anchor_adjustment": -12.5,
		"truncated": false,
		"error_index": 7,
		"error": "row binding rejected",
	}


func _create_fixture(
	item_count: int,
	viewport_extent: float,
	overscan_items: int,
	max_materialized_items: int = 512,
	focus_model: GFVirtualListFocusModel = null,
	lifecycle_owner: Node = null,
	content_minimum_size: Vector2 = Vector2.ZERO,
	start_horizontal: bool = false,
	focus_target_callback: Callable = Callable(),
	auto_measure_items: bool = true
) -> Dictionary:
	_item_ids.clear()
	for item_index: int in range(item_count):
		_item_ids.append(StringName("item_%d" % item_index))

	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.size = Vector2(240.0, viewport_extent)
	var content_root: Control = Control.new()
	content_root.custom_minimum_size = content_minimum_size
	scroll_container.add_child(content_root)
	add_child(scroll_container)
	_nodes.append(scroll_container)
	_nodes.append(content_root)

	var model: GFVirtualListModel = GFVirtualListModel.new()
	model.estimated_item_extent = 20.0
	model.overscan_items = overscan_items
	model.set_item_count(item_count)
	if focus_model != null:
		var _focus_count_changed: bool = focus_model.set_item_count(item_count)

	var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = GF_VIRTUAL_LIST_BINDER_SCRIPT.new()
	binder.auto_measure = auto_measure_items
	if start_horizontal:
		binder.layout_axis = GF_VIRTUAL_LIST_BINDER_SCRIPT.LayoutAxis.HORIZONTAL
	binder.max_materialized_items = max_materialized_items
	binder.max_pooled_items = 2
	_active_binder = binder
	_binders.append(binder)
	var binding_owner: Node = lifecycle_owner if lifecycle_owner != null else scroll_container
	var bound: bool = binder.bind(
		binding_owner,
		scroll_container,
		content_root,
		model,
		Callable(self, "_make_row"),
		Callable(self, "_bind_row"),
		Callable(self, "_unbind_row"),
		Callable(self, "_get_item_identity"),
		focus_model,
		Callable(self, "_measure_row"),
		focus_target_callback
	)
	assert_true(bound, "测试 fixture 应成功绑定。")
	return {
		"binder": binder,
		"scroll": scroll_container,
		"content": content_root,
		"model": model,
	}


func _make_row() -> Control:
	if _fail_factory:
		return null
	if _factory_success_budget == 0:
		return null
	if _factory_success_budget > 0:
		_factory_success_budget -= 1
	_factory_count += 1
	var row: Button = Button.new()
	row.custom_minimum_size = Vector2(0.0, 20.0)
	row.focus_mode = Control.FOCUS_ALL
	if _reentrant_mode == &"unbind_on_tree_enter" and _active_binder != null:
		var _tree_entered_connected: Error = row.tree_entered.connect(
			func() -> void:
				if _active_binder != null:
					var _unbound: Variant = _active_binder.call("unbind"),
			CONNECT_ONE_SHOT
		) as Error
	_last_factory_control = row
	if (
		_reentrant_mode == &"invalidate_in_factory"
		and _invalidate_callback_budget > 0
		and _active_binder != null
	):
		_invalidate_callback_budget -= 1
		var _invalidated_in_factory: Variant = _active_binder.call("invalidate_items")
	return row


func _bind_row(row: Control, item_index: int, item_id: Variant) -> bool:
	_bind_events.append({
		"row_id": row.get_instance_id(),
		"index": item_index,
		"item_id": item_id,
	})
	if row is Button:
		var button: Button = row
		button.text = str(item_id)
	if _reentrant_mode == &"request_sync" and item_index == 0 and _active_binder != null:
		var _requested: Variant = _active_binder.call("request_sync")
	elif _reentrant_mode == &"dispose" and item_index == 0 and _active_binder != null:
		var _disposed: Variant = _active_binder.call("dispose")
	elif (
		_reentrant_mode == &"invalidate_items"
		and item_index == 0
		and _invalidate_callback_budget > 0
		and _active_binder != null
	):
		_invalidate_callback_budget -= 1
		var _invalidated: Variant = _active_binder.call("invalidate_items")
	elif (
		_reentrant_mode == &"change_layout"
		and item_index == 0
		and _layout_callback_budget > 0
		and _layout_model_for_callback != null
	):
		_layout_callback_budget -= 1
		_layout_model_for_callback.overscan_items = 3
	elif (
		_reentrant_mode == &"change_layout_geometry"
		and item_index == 0
		and _layout_callback_budget > 0
		and _layout_model_for_callback != null
	):
		_layout_callback_budget -= 1
		_layout_model_for_callback.estimated_item_extent = 40.0
	elif _reentrant_mode == &"change_axis_on_bind" and item_index == 0 and _active_binder != null:
		_reentrant_mode = &""
		_active_binder.set(
			"layout_axis",
			GF_VIRTUAL_LIST_BINDER_SCRIPT.LayoutAxis.HORIZONTAL
		)
		var _requested_axis_sync: Variant = _active_binder.call("request_sync")
	elif _reentrant_mode == &"shrink_pool_on_bind" and item_index == 1 and _active_binder != null:
		_reentrant_mode = &""
		_active_binder.set("max_pooled_items", 0)
	elif (
		_reentrant_mode == &"focus_zero_on_bind"
		and _focus_callback_budget > 0
		and _focus_model_for_callback != null
	):
		_focus_callback_budget -= 1
		var _focused: bool = _focus_model_for_callback.set_focused_index(0)
	return item_index != _fail_bind_index


func _unbind_row(row: Control, item_index: int, item_id: Variant) -> void:
	_unbind_events.append({
		"row_id": row.get_instance_id(),
		"index": item_index,
		"item_id": item_id,
	})
	if _reentrant_mode == &"dispose_on_unbind" and item_index == 0 and _active_binder != null:
		var _disposed: Variant = _active_binder.call("dispose")
	elif (
		_reentrant_mode == &"invalidate_on_unbind"
		and _invalidate_callback_budget > 0
		and _active_binder != null
	):
		_invalidate_callback_budget -= 1
		var _invalidated_on_unbind: Variant = _active_binder.call("invalidate_items")
	elif (
		_reentrant_mode == &"reparent_on_unbind"
		and item_index == 0
		and _foreign_parent_for_callback != null
		and is_instance_valid(_foreign_parent_for_callback)
	):
		_reentrant_mode = &""
		row.reparent(_foreign_parent_for_callback)


func _get_item_identity(item_index: int) -> Variant:
	_identity_callback_count += 1
	if item_index < 0 or item_index >= _item_ids.size():
		return null
	if (
		_reentrant_mode == &"invalidate_identity"
		and item_index == 0
		and _invalidate_callback_budget > 0
		and _active_binder != null
	):
		_invalidate_callback_budget -= 1
		_item_ids[0] = &"replacement_0"
		var _invalidated_identity: Variant = _active_binder.call("invalidate_items")
	if (
		_reentrant_mode == &"capture_round_geometry"
		and item_index == 0
		and _active_binder != null
	):
		_reentrant_mode = &""
		var geometries_value: Variant = _active_binder.get("_sync_item_geometries")
		if geometries_value is Dictionary:
			var geometries: Dictionary = geometries_value
			var geometry_value: Variant = geometries.get(1)
			if geometry_value is Dictionary:
				var geometry: Dictionary = geometry_value
				_captured_round_geometry = true
				_captured_round_offset = GFVariantData.get_option_float(geometry, "offset")
				_captured_round_extent = GFVariantData.get_option_float(geometry, "extent")
	return _item_ids[item_index]


func _resolve_focus_target(
	row: Control,
	_item_index: int,
	_item_id: Variant
) -> Control:
	if (
		_reentrant_mode == &"invalidate_on_focus_target"
		and _invalidate_callback_budget > 0
		and _active_binder != null
	):
		_invalidate_callback_budget -= 1
		var _invalidated_on_focus: Variant = _active_binder.call("invalidate_items")
	return row


func _measure_row(_row: Control, item_index: int, _item_id: Variant) -> float:
	if (
		_reentrant_mode == &"invalidate_on_measure"
		and item_index == 0
		and _invalidate_callback_budget > 0
		and _active_binder != null
	):
		_invalidate_callback_budget -= 1
		var _invalidated_on_measure: Variant = _active_binder.call("invalidate_items")
	if (
		_reentrant_mode == &"reparent_other_on_measure"
		and item_index == 0
		and _active_binder != null
		and _foreign_parent_for_callback != null
	):
		_reentrant_mode = &""
		var other_value: Variant = _active_binder.call("get_materialized_control", 1)
		if other_value is Control:
			var other_control: Control = other_value
			other_control.reparent(_foreign_parent_for_callback)
	if (
		_reentrant_mode == &"request_measurement"
		and item_index == 0
		and _measurement_requeue_budget > 0
		and _active_binder != null
	):
		_measurement_requeue_budget -= 1
		var _requested: Variant = _active_binder.call("request_measurement")
	if _measured_extents.has(item_index):
		var measured_value: Variant = _measured_extents.get(item_index)
		if measured_value is float:
			var measured_extent: float = measured_value
			return measured_extent
	if _expanded_first_extent and item_index == 0:
		return 40.0
	return 20.0


func _find_parentless_owned_control(controls: Array[Control]) -> Control:
	for control: Control in controls:
		if (
			control != null
			and is_instance_valid(control)
			and not control.is_queued_for_deletion()
			and control.get_parent() == null
		):
			return control
	return null


func _get_fixture_binder(fixture: Dictionary) -> GF_VIRTUAL_LIST_BINDER_SCRIPT:
	var value: Variant = fixture.get("binder")
	if value is GF_VIRTUAL_LIST_BINDER_SCRIPT:
		var binder: GF_VIRTUAL_LIST_BINDER_SCRIPT = value
		return binder
	return null


func _get_fixture_scroll(fixture: Dictionary) -> ScrollContainer:
	var value: Variant = fixture.get("scroll")
	if value is ScrollContainer:
		var scroll_container: ScrollContainer = value
		return scroll_container
	return null


func _get_fixture_model(fixture: Dictionary) -> GFVirtualListModel:
	var value: Variant = fixture.get("model")
	if value is GFVirtualListModel:
		var model: GFVirtualListModel = value
		return model
	return null


func _get_fixture_content(fixture: Dictionary) -> Control:
	var value: Variant = fixture.get("content")
	if value is Control:
		var content_root: Control = value
		return content_root
	return null


func _on_sync_completed_reentrant(_result: RefCounted) -> void:
	_sync_completed_event_count += 1
	if _sync_completed_event_count != 1 or _active_binder == null:
		return
	var value: Variant = _active_binder.call("sync_now")
	if value is RefCounted:
		_reentrant_sync_result = value


func _reset_fixture_state() -> void:
	_item_ids.clear()
	_factory_count = 0
	_bind_events.clear()
	_unbind_events.clear()
	_fail_factory = false
	_factory_success_budget = -1
	_last_factory_control = null
	_fail_bind_index = -1
	_expanded_first_extent = false
	_measured_extents.clear()
	_reentrant_mode = &""
	_invalidate_callback_budget = 0
	_layout_callback_budget = 0
	_measurement_requeue_budget = 0
	_focus_callback_budget = 0
	_layout_model_for_callback = null
	_focus_model_for_callback = null
	_active_binder = null
	_foreign_parent_for_callback = null
	_sync_completed_event_count = 0
	_reentrant_sync_result = null
	_captured_round_geometry = false
	_captured_round_offset = 0.0
	_captured_round_extent = 0.0
	_identity_callback_count = 0
