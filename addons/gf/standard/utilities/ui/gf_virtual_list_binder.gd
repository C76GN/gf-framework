## GFVirtualListBinder: owner-bound 虚拟列表 Control 物化与回收协调器。
##
## 连接项目提供的 `ScrollContainer`、绝对布局 content root、`GFVirtualListModel`
## 与行回调，只物化真实视口及 overscan 范围。项目继续拥有条目数据、稳定 ID、
## 行视觉、选择、激活、输入和无障碍语义；Binder 拥有 factory 成功交付的 Control，
## 并在 unbind、任一绑定节点退出或 dispose 时确定性解除回调和节点引用。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFVirtualListBinder
extends RefCounted


# --- 信号 ---

## 一轮同步完成后发出。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param result: 不含项目条目载荷的 typed 同步结果。
signal sync_completed(result: GFVirtualListSyncResult)


# --- 枚举 ---

## 列表滚动和尺寸测量使用的主轴。
## [br]
## @api public
## [br]
## @since unreleased
enum LayoutAxis {
	## 以 Y 轴和垂直滚动条组织条目。
	VERTICAL,
	## 以 X 轴和水平滚动条组织条目。
	HORIZONTAL,
}

## 把条目滚入视口时使用的对齐方式。
## [br]
## @api public
## [br]
## @since unreleased
enum ScrollAlignment {
	## 已可见时不滚动，否则移动到最近边界。
	NEAREST,
	## 条目起点对齐视口起点。
	START,
	## 条目中心对齐视口中心。
	CENTER,
	## 条目终点对齐视口终点。
	END,
}


# --- 常量 ---

## 默认活动 Control 硬上限。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_MATERIALIZED_ITEMS: int = 512

## 默认 parentless pool Control 上限。
## [br]
## @api public
## [br]
## @since unreleased
const DEFAULT_MAX_POOLED_ITEMS: int = 64

## 活动物化 Control 的框架级绝对硬上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_MATERIALIZED_ITEMS: int = 4096

## parentless pool 的框架级绝对硬上限。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_POOLED_ITEMS: int = 1024

## 稳定 identity token 允许的最大 UTF-8 字节数。
## [br]
## @api public
## [br]
## @since unreleased
const ABSOLUTE_MAX_IDENTITY_TOKEN_LENGTH: int = 1024

const _STATE_UNBOUND: StringName = &"unbound"
const _STATE_IDLE: StringName = &"idle"
const _STATE_PENDING: StringName = &"pending"
const _STATE_SYNCING: StringName = &"syncing"
const _STATE_UNBINDING: StringName = &"unbinding"
const _STATE_DISPOSING: StringName = &"disposing"
const _STATE_DISPOSED: StringName = &"disposed"


# --- 公共变量 ---

## 布局主轴。只接受 VERTICAL/HORIZONTAL；绑定期间修改后调用 request_sync() 使其生效。
## 同步 callback 内修改时，当前轮继续使用入口快照，下一轮才采用新值。
## [br]
## @api public
## [br]
## @since unreleased
var layout_axis: LayoutAxis = LayoutAxis.VERTICAL:
	set(value):
		if value not in [LayoutAxis.VERTICAL, LayoutAxis.HORIZONTAL]:
			return
		layout_axis = value

## 活动物化 Control 硬上限；运行时按至少 1 处理。
## [br]
## @api public
## [br]
## @since unreleased
var max_materialized_items: int = DEFAULT_MAX_MATERIALIZED_ITEMS:
	set(value):
		max_materialized_items = clampi(value, 1, ABSOLUTE_MAX_MATERIALIZED_ITEMS)

## parentless pool 最多保留的 Control 数量；小于 0 时按 0 处理。
## 同步事务内收紧预算时，会在候选提交或回滚完成后统一裁剪。
## [br]
## @api public
## [br]
## @since unreleased
var max_pooled_items: int = DEFAULT_MAX_POOLED_ITEMS:
	set(value):
		max_pooled_items = clampi(value, 0, ABSOLUTE_MAX_POOLED_ITEMS)
		if _is_sync_in_progress():
			_pool_trim_requested = true
		else:
			_trim_pool_to_limit()

## 是否在新绑定或数据失效后自动测量活动行；不影响显式 request_measurement()。
## [br]
## @api public
## [br]
## @since unreleased
var auto_measure: bool = true

## 虚拟焦点变化后是否按最近边界自动滚入视口。
## [br]
## @api public
## [br]
## @since unreleased
var auto_reveal_focus: bool = true

## 是否让行 Control 填满 content root 的交叉轴。
## 同步 callback 内修改时，当前轮继续使用入口快照，下一轮才采用新值。
## [br]
## @api public
## [br]
## @since unreleased
var fill_cross_axis: bool = true


# --- 私有变量 ---

var _state: StringName = _STATE_UNBOUND
var _lifecycle_generation: int = 0
var _data_revision: int = 0
var _last_committed_data_revision: int = -1
var _last_committed_layout_revision: int = -1
var _pending_sync: bool = false
var _deferred_sync_scheduled: bool = false
var _measurement_requested: bool = false
var _measurement_request_revision: int = 0
var _unbind_requested: bool = false
var _dispose_requested: bool = false
var _applying_scroll_adjustment: bool = false
var _sync_in_progress: bool = false
var _teardown_in_progress: bool = false
var _binding_focus_initialization: bool = false
var _sync_layout_axis: int = -1
var _sync_fill_cross_axis: bool = false
var _sync_max_materialized_items: int = DEFAULT_MAX_MATERIALIZED_ITEMS
var _sync_auto_measure: bool = true
var _sync_measurement_requested: bool = false
var _sync_measurement_request_revision: int = 0
var _sync_truncated: bool = false
var _sync_layout_model: GFVirtualListModel = null
var _sync_expected_layout_revision: int = -1
var _sync_content_extent: float = 0.0
var _sync_item_geometries: Dictionary = {}
var _sync_context_ready: bool = false
var _pool_trim_requested: bool = false

var _owner_ref: WeakRef = null
var _scroll_ref: WeakRef = null
var _content_ref: WeakRef = null
var _viewport_ref: WeakRef = null
var _owned_layout_axis: int = -1
var _owned_layout_axis_baseline: float = 0.0
var _layout_model: GFVirtualListModel = null
var _focus_model: GFVirtualListFocusModel = null

var _item_factory: Callable = Callable()
var _bind_callback: Callable = Callable()
var _unbind_callback: Callable = Callable()
var _identity_callback: Callable = Callable()
var _measure_callback: Callable = Callable()
var _focus_target_callback: Callable = Callable()

var _active_by_token: Dictionary = {}
var _token_by_index: Dictionary = {}
var _pool: Array[Control] = []
var _known_control_ids: Dictionary = {}

var _pending_focus_index: int = GFVirtualListFocusModel.NO_FOCUS
var _pending_focus_handoff: bool = false
var _pending_focus_started_with_owner: bool = false
var _pending_focus_reveal_index: int = GFVirtualListFocusModel.NO_FOCUS
var _pending_physical_focus_reconciliation: bool = false
var _focus_intent_revision: int = 0
var _focus_handoff_in_progress: bool = false
var _focus_handoff_index: int = GFVirtualListFocusModel.NO_FOCUS
var _focus_handoff_observed_target: bool = false

var _binding_tree_exited_callable: Callable = Callable()
var _binding_tree_exit_refs: Array[WeakRef] = []
var _scroll_resized_callable: Callable = Callable()
var _content_resized_callable: Callable = Callable()
var _vertical_scroll_callable: Callable = Callable()
var _horizontal_scroll_callable: Callable = Callable()
var _layout_changed_callable: Callable = Callable()
var _focus_changed_callable: Callable = Callable()
var _viewport_focus_changed_callable: Callable = Callable()
var _last_sync_result: GFVirtualListSyncResult = null
var _emitting_sync_completed: bool = false


# --- 公共方法 ---

## 建立一个 owner-bound 虚拟列表绑定。
##
## `content_root` 必须是 ScrollContainer 的直接子 Control，且不能是会接管子节点位置的
## Container。factory 返回的 Control 必须 parentless；返回后其所有权转交 Binder。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param owner: 生命周期 owner；退出 SceneTree 后 Binder 自动 dispose。
## [br]
## @param scroll_container: 项目持有的滚动容器；退出 SceneTree 后 Binder 自动 dispose。
## [br]
## @param content_root: Binder 写入主轴最小尺寸并承载活动行；退出 SceneTree 后自动 dispose。
## [br]
## @param layout_model: 条目 count、extent、offset 和范围模型。
## [br]
## @param item_factory: Callable() -> Control。
## [br]
## @param bind_callback: Callable(control: Control, item_index: int, item_id: Variant) -> bool。
## [br]
## @param unbind_callback: Callable(control: Control, item_index: int, item_id: Variant) -> void。
## [br]
## @param identity_callback: Callable(item_index: int) -> Variant；返回值必须是稳定 key。
## [br]
## @param focus_model: 可选虚拟焦点模型。
## [br]
## @param measure_callback: 可选 Callable(control, item_index, item_id) -> float。
## [br]
## @param focus_target_callback: 可选 Callable(control, item_index, item_id) -> Control。
## [br]
## @return 全部边界合法并建立连接时返回 true。
## [br]
## @schema item_factory: Callable() -> Control.
## [br]
## @schema bind_callback: Callable(Control, int, Variant) -> bool.
## [br]
## @schema unbind_callback: Callable(Control, int, Variant) -> void.
## [br]
## @schema identity_callback: Callable(int) -> stable Variant key.
## [br]
## @schema measure_callback: Optional Callable(Control, int, Variant) -> finite positive float.
## [br]
## @schema focus_target_callback: Optional Callable(Control, int, Variant) -> Control descendant.
func bind(
	owner: Node,
	scroll_container: ScrollContainer,
	content_root: Control,
	layout_model: GFVirtualListModel,
	item_factory: Callable,
	bind_callback: Callable,
	unbind_callback: Callable,
	identity_callback: Callable,
	focus_model: GFVirtualListFocusModel = null,
	measure_callback: Callable = Callable(),
	focus_target_callback: Callable = Callable()
) -> bool:
	if _state == _STATE_DISPOSED or _state != _STATE_UNBOUND:
		return false
	if not _is_valid_binding_boundary(owner, scroll_container, content_root, layout_model):
		return false
	if (
		not item_factory.is_valid()
		or not bind_callback.is_valid()
		or not unbind_callback.is_valid()
		or not identity_callback.is_valid()
	):
		return false

	_lifecycle_generation += 1
	_owner_ref = weakref(owner)
	_scroll_ref = weakref(scroll_container)
	_content_ref = weakref(content_root)
	var viewport: Viewport = scroll_container.get_viewport()
	_viewport_ref = weakref(viewport) if viewport != null else null
	_owned_layout_axis = -1
	_owned_layout_axis_baseline = 0.0
	_layout_model = layout_model
	_focus_model = focus_model
	_item_factory = item_factory
	_bind_callback = bind_callback
	_unbind_callback = unbind_callback
	_identity_callback = identity_callback
	_measure_callback = measure_callback
	_focus_target_callback = focus_target_callback
	_state = _STATE_IDLE
	_last_committed_data_revision = -1
	_last_committed_layout_revision = -1
	_measurement_requested = false
	_measurement_request_revision = 0
	if auto_measure:
		_queue_measurement_request()
	_connect_binding_signals(owner, scroll_container, content_root, viewport)
	if _focus_model != null:
		_binding_focus_initialization = true
		var _focus_count_changed: bool = _focus_model.set_item_count(_layout_model.get_item_count())
		_binding_focus_initialization = false
	_update_content_extent()
	_adopt_bound_virtual_focus()
	return request_sync()


## 请求一次合并到 deferred 队列的同步。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前处于有效绑定生命周期时返回 true。
func request_sync() -> bool:
	if not is_bound() or _state in [_STATE_UNBINDING, _STATE_DISPOSING]:
		return false
	_pending_sync = true
	if _state != _STATE_SYNCING:
		_state = _STATE_PENDING
	_schedule_deferred_sync()
	return true


## 立即执行一轮同步；callback 内的再次请求会合并为下一轮。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return typed 同步结果。
func sync_now() -> GFVirtualListSyncResult:
	if _state == _STATE_DISPOSED:
		return _store_result(_make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED))
	if _state == _STATE_UNBOUND:
		return _store_result(_make_terminal_result(GFVirtualListSyncResult.STATUS_UNBOUND))
	if _sync_in_progress or _emitting_sync_completed:
		var _requested: bool = request_sync()
		return get_last_sync_result()

	_pending_sync = false
	_deferred_sync_scheduled = false
	_state = _STATE_SYNCING
	var generation: int = _lifecycle_generation
	_sync_layout_axis = int(layout_axis)
	_sync_fill_cross_axis = fill_cross_axis
	_sync_max_materialized_items = max_materialized_items
	_sync_auto_measure = auto_measure
	_sync_measurement_requested = _measurement_requested
	_sync_measurement_request_revision = _measurement_request_revision
	_sync_in_progress = true
	var result: GFVirtualListSyncResult = _synchronize(generation)
	_sync_in_progress = false
	_clear_sync_context()
	if (
		_pool_trim_requested
		and not _dispose_requested
		and not _unbind_requested
		and _state not in [_STATE_DISPOSING, _STATE_UNBINDING]
	):
		_trim_pool_to_limit()
		result = _copy_result_with_current_pool_count(result)
	if _dispose_requested or _state == _STATE_DISPOSING:
		_finish_dispose()
		result = _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
	elif _unbind_requested or _state == _STATE_UNBINDING:
		_finish_unbind()
		result = _make_terminal_result(GFVirtualListSyncResult.STATUS_UNBOUND)
	elif _pending_sync:
		_state = _STATE_PENDING
		_schedule_deferred_sync()
	else:
		_state = _STATE_IDLE
	result = _store_result(result)
	_emitting_sync_completed = true
	sync_completed.emit(result.duplicate_result())
	_emitting_sync_completed = false
	return result


## 标记项目条目内容或 identity 已变化，并请求重新绑定当前物化范围。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前已绑定时返回 true。
func invalidate_items() -> bool:
	if not is_bound():
		return false
	_data_revision += 1
	if auto_measure:
		_queue_measurement_request()
	return request_sync()


## 请求下一轮重新测量当前活动行；即使 auto_measure 为 false 也会执行。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前已绑定时返回 true。
func request_measurement() -> bool:
	if not is_bound():
		return false
	_queue_measurement_request()
	return request_sync()


## 把指定条目滚入视口。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param item_index: 条目索引。
## [br]
## @param alignment: `ScrollAlignment` 值。
## [br]
## 同步 callback 内不允许直接改变当前轮滚动；先保存项目意图并请求下一轮。
## [br]
## @return 索引和绑定有效、当前不在同步 callback 内，且滚动操作期间 data generation、
## 模型、视口、主轴与 Control 所有权快照保持有效并接受最终整数偏移时返回 true；
## 否则请求下一轮同步并返回 false。
func scroll_to_item(
	item_index: int,
	alignment: ScrollAlignment = ScrollAlignment.NEAREST
) -> bool:
	if not is_bound() or _layout_model == null:
		return false
	if item_index < 0 or item_index >= _layout_model.get_item_count():
		return false
	if not _scroll_to_item_internal(item_index, alignment):
		return false
	return request_sync()


## 获取指定索引当前物化的 Control。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param item_index: 条目索引。
## [br]
## @return 未物化时为 null。
func get_materialized_control(item_index: int) -> Control:
	var token_value: Variant = _token_by_index.get(item_index)
	if not (token_value is String):
		return null
	var token: String = token_value
	return _get_record_control(_get_active_record(token))


## 按稳定 identity 获取当前物化的 Control。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param item_id: identity callback 使用的稳定 ID。
## [br]
## @return ID 无效或未物化时为 null。
## [br]
## @schema item_id: Stable Variant key accepted by GFVariantKeyCodec.
func get_materialized_control_by_id(item_id: Variant) -> Control:
	var token_report: Dictionary = _make_bounded_identity_token(item_id)
	if not GFVariantData.get_option_bool(token_report, "ok"):
		return null
	var token: String = GFVariantData.get_option_string(token_report, "token")
	return _get_record_control(_get_active_record(token))


## 获取最近同步结果的隔离副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 尚未同步时返回当前生命周期终态结果。
func get_last_sync_result() -> GFVirtualListSyncResult:
	if _last_sync_result != null:
		return _last_sync_result.duplicate_result()
	var status: StringName = GFVirtualListSyncResult.STATUS_UNBOUND
	if _state == _STATE_DISPOSED:
		status = GFVirtualListSyncResult.STATUS_DISPOSED
	return _make_terminal_result(status)


## 获取不含项目条目载荷的调试快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 生命周期、范围和计数摘要。
## [br]
## @schema return: Dictionary with state, bound, disposed, lifecycle_generation, data_revision, pending_sync, active_count, pooled_count, and last_result.
func get_debug_snapshot() -> Dictionary:
	return {
		"state": _state,
		"bound": is_bound(),
		"disposed": is_disposed(),
		"lifecycle_generation": _lifecycle_generation,
		"data_revision": _data_revision,
		"pending_sync": _pending_sync,
		"active_count": _active_by_token.size(),
		"pooled_count": _pool.size(),
		"last_result": get_last_sync_result().to_dict(),
	}


## 检查是否处于有效绑定生命周期。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已绑定且未进入 teardown 时返回 true。
func is_bound() -> bool:
	return _state in [_STATE_IDLE, _STATE_PENDING, _STATE_SYNCING]


## 检查是否进入不可复用终态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return dispose 已完成时返回 true。
func is_disposed() -> bool:
	return _state == _STATE_DISPOSED


## 解除当前绑定并释放全部 Binder-owned Control；实例仍可重新 bind。
## [br]
## @api public
## [br]
## @since unreleased
func unbind() -> void:
	if _state in [_STATE_UNBOUND, _STATE_UNBINDING, _STATE_DISPOSING, _STATE_DISPOSED]:
		return
	_unbind_requested = true
	_lifecycle_generation += 1
	_state = _STATE_UNBINDING
	if not _is_sync_in_progress() and not _teardown_in_progress:
		_finish_unbind()


## 进入终态并释放行、pool、连接和 callback。
## [br]
## @api public
## [br]
## @since unreleased
func dispose() -> void:
	if _state in [_STATE_DISPOSING, _STATE_DISPOSED] or _dispose_requested:
		return
	_dispose_requested = true
	_lifecycle_generation += 1
	_state = _STATE_DISPOSING
	if not _is_sync_in_progress() and not _teardown_in_progress:
		_finish_dispose()


# --- 私有/辅助方法 ---

func _synchronize(generation: int) -> GFVirtualListSyncResult:
	if generation != _lifecycle_generation:
		return _make_terminal_result(_get_interrupted_status())
	if not _binding_objects_are_live() or not _owned_controls_are_live():
		dispose()
		return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
	var scroll_container: ScrollContainer = _get_scroll_container()
	var layout_model: GFVirtualListModel = _layout_model
	if scroll_container == null or layout_model == null:
		dispose()
		return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)

	# Freeze every layout value that can affect this transaction before invoking
	# project callbacks or mutating Controls. Reentrant configuration/model writes
	# are intentionally observed by the next synchronization round.
	var sync_data_revision: int = _data_revision
	var sync_layout_revision: int = layout_model.get_revision()
	var sync_focus_intent_revision: int = _focus_intent_revision
	var sync_item_count: int = layout_model.get_item_count()
	_sync_layout_model = layout_model
	_sync_expected_layout_revision = sync_layout_revision
	_sync_content_extent = layout_model.get_content_extent()
	var scroll_offset: float = _get_scroll_offset(scroll_container)
	var viewport_extent: float = _get_viewport_extent(scroll_container)
	var planned_scroll_offset: float = scroll_offset
	var reveal_index: int = _pending_focus_reveal_index
	var reveal_is_current: bool = (
		reveal_index != GFVirtualListFocusModel.NO_FOCUS
		and auto_reveal_focus
		and _focus_model != null
		and _focus_model.focused_index == reveal_index
		and reveal_index >= 0
		and reveal_index < sync_item_count
	)
	if reveal_is_current:
		planned_scroll_offset = _calculate_scroll_offset_for_item(
			layout_model,
			reveal_index,
			ScrollAlignment.NEAREST,
			scroll_offset,
			viewport_extent,
			_sync_content_extent
		)
	elif reveal_index != GFVirtualListFocusModel.NO_FOCUS:
		_clear_pending_focus_reveal()
	planned_scroll_offset = _quantize_scroll_offset(planned_scroll_offset)
	var viewport_range: Vector2i = layout_model.get_viewport_range(
		planned_scroll_offset,
		viewport_extent
	)
	var requested_range: Vector2i = layout_model.get_visible_range(
		planned_scroll_offset,
		viewport_extent
	)
	var selection: Dictionary = _select_target_indices(viewport_range, requested_range)
	var target_indices: PackedInt32Array = _get_packed_indices(selection, "indices")
	var truncated: bool = GFVariantData.get_option_bool(selection, "truncated")
	_sync_truncated = truncated
	_snapshot_sync_item_geometries(layout_model, target_indices)
	_sync_context_ready = true

	_update_content_extent()
	if generation != _lifecycle_generation:
		return _make_terminal_result(_get_interrupted_status())
	if not _owned_controls_are_live():
		dispose()
		return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
	if not _sync_data_revision_is_current(sync_data_revision):
		return _make_deferred_sync_result(
			viewport_range,
			requested_range,
			sync_layout_revision,
			sync_data_revision
		)
	if reveal_is_current:
		_applying_scroll_adjustment = true
		_set_scroll_offset(scroll_container, planned_scroll_offset)
		_applying_scroll_adjustment = false
		if generation != _lifecycle_generation:
			return _make_terminal_result(_get_interrupted_status())
		if not _owned_controls_are_live():
			dispose()
			return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
		if not _sync_data_revision_is_current(sync_data_revision):
			return _make_deferred_sync_result(
				viewport_range,
				requested_range,
				sync_layout_revision,
				sync_data_revision
			)
	var round_scroll_offset: float = _get_scroll_offset(scroll_container)
	var round_viewport_extent: float = _get_viewport_extent(scroll_container)
	var scroll_snapshot_matches: bool = is_equal_approx(
		round_scroll_offset,
		planned_scroll_offset
	)
	var viewport_snapshot_matches: bool = is_equal_approx(
		round_viewport_extent,
		viewport_extent
	)
	if not scroll_snapshot_matches or not viewport_snapshot_matches:
		var _requested_scroll_convergence: bool = request_sync()
		if layout_model.get_revision() != sync_layout_revision:
			return _make_deferred_sync_result(
				viewport_range,
				requested_range,
				sync_layout_revision,
				sync_data_revision
			)
		viewport_range = layout_model.get_viewport_range(
			round_scroll_offset,
			round_viewport_extent
		)
		requested_range = layout_model.get_visible_range(
			round_scroll_offset,
			round_viewport_extent
		)
		selection = _select_target_indices(viewport_range, requested_range)
		target_indices = _get_packed_indices(selection, "indices")
		truncated = GFVariantData.get_option_bool(selection, "truncated")
		_sync_truncated = truncated
		_snapshot_sync_item_geometries(layout_model, target_indices)
	if not _sync_data_revision_is_current(sync_data_revision):
		return _make_deferred_sync_result(
			viewport_range,
			requested_range,
			sync_layout_revision,
			sync_data_revision
		)
	if (
		scroll_snapshot_matches
		and viewport_snapshot_matches
		and _pending_focus_reveal_index == reveal_index
		and _focus_model != null
		and _focus_model.focused_index == reveal_index
	):
		_clear_pending_focus_reveal()
	if _focus_model != null:
		var _focus_count_changed: bool = _focus_model.set_item_count(sync_item_count)
		if generation != _lifecycle_generation:
			return _make_terminal_result(_get_interrupted_status())
		if not _owned_controls_are_live():
			dispose()
			return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
		if not _sync_data_revision_is_current(sync_data_revision):
			return _make_deferred_sync_result(
				viewport_range,
				requested_range,
				sync_layout_revision,
				sync_data_revision
			)

	var identity_plan: Dictionary = _build_identity_plan(
		target_indices,
		generation,
		sync_data_revision
	)
	if generation != _lifecycle_generation:
		return _make_terminal_result(_get_interrupted_status())
	if not _owned_controls_are_live():
		dispose()
		return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
	var identity_status: StringName = GFVariantData.get_option_string_name(identity_plan, "status")
	if identity_status != GFVirtualListSyncResult.STATUS_SYNCED:
		if _state == _STATE_DISPOSING:
			return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
		if identity_status == GFVirtualListSyncResult.STATUS_DEFERRED:
			return _make_deferred_sync_result(
				viewport_range,
				requested_range,
				sync_layout_revision,
				sync_data_revision
			)
		return _make_sync_result(identity_status, viewport_range, requested_range, {
			"truncated": truncated,
			"error_index": GFVariantData.get_option_int(identity_plan, "error_index", -1),
			"error": GFVariantData.get_option_string(identity_plan, "error"),
		}, sync_layout_revision, sync_data_revision)

	var descriptors: Array[Dictionary] = _get_descriptor_array(identity_plan)
	var plan: Dictionary = _stage_materialization_plan(
		descriptors,
		generation,
		sync_data_revision
	)
	var plan_status: StringName = GFVariantData.get_option_string_name(plan, "status")
	if plan_status != GFVirtualListSyncResult.STATUS_SYNCED:
		_rollback_staged_records(_get_record_array(plan, "staged_records"))
		if generation != _lifecycle_generation:
			return _make_terminal_result(_get_interrupted_status())
		if plan_status == GFVirtualListSyncResult.STATUS_DEFERRED:
			return _make_deferred_sync_result(
				viewport_range,
				requested_range,
				sync_layout_revision,
				sync_data_revision,
				{
					"created_count": GFVariantData.get_option_int(plan, "created_count"),
					"reused_count": GFVariantData.get_option_int(plan, "reused_count"),
				}
			)
		return _make_sync_result(plan_status, viewport_range, requested_range, {
			"truncated": truncated,
			"created_count": GFVariantData.get_option_int(plan, "created_count"),
			"reused_count": GFVariantData.get_option_int(plan, "reused_count"),
			"error_index": GFVariantData.get_option_int(plan, "error_index", -1),
			"error": GFVariantData.get_option_string(plan, "error"),
		}, sync_layout_revision, sync_data_revision)
	var staged_records: Array[Dictionary] = _get_record_array(plan, "staged_records")
	if not _owned_controls_are_live(staged_records):
		dispose()
		_rollback_staged_records(staged_records)
		return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
	if not _sync_data_revision_is_current(sync_data_revision):
		_rollback_staged_records(staged_records)
		return _make_deferred_sync_result(
			viewport_range,
			requested_range,
			sync_layout_revision,
			sync_data_revision
		)

	var metrics: Dictionary = _commit_materialization_plan(
		plan,
		generation,
		sync_data_revision
	)
	if generation != _lifecycle_generation or _state in [_STATE_DISPOSING, _STATE_UNBINDING]:
		return _make_terminal_result(
			GFVirtualListSyncResult.STATUS_DISPOSED
			if _state == _STATE_DISPOSING
			else GFVirtualListSyncResult.STATUS_UNBOUND
		)
	if not _owned_controls_are_live():
		dispose()
		return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
	if GFVariantData.get_option_bool(metrics, "deferred"):
		return _make_deferred_sync_result(
			viewport_range,
			requested_range,
			sync_layout_revision,
			sync_data_revision,
			metrics
		)

	if not _layout_active_controls(generation, sync_data_revision):
		if (
			generation == _lifecycle_generation
			and is_bound()
			and not _sync_data_revision_is_current(sync_data_revision)
		):
			metrics["released_count"] = (
				GFVariantData.get_option_int(metrics, "released_count")
				+ _rollback_materialization_after_data_drift([], generation)
			)
			if generation != _lifecycle_generation:
				return _make_terminal_result(_get_interrupted_status())
			return _make_deferred_sync_result(
				viewport_range,
				requested_range,
				sync_layout_revision,
				sync_data_revision,
				metrics
			)
		return _make_terminal_result(_get_interrupted_status())
	if generation != _lifecycle_generation:
		return _make_terminal_result(_get_interrupted_status())
	if not _owned_controls_are_live():
		dispose()
		return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
	var should_measure: bool = (
		_sync_measurement_requested
		or (
			_sync_auto_measure
			and (
				GFVariantData.get_option_int(metrics, "created_count") > 0
				or sync_data_revision != _last_committed_data_revision
			)
		)
	)
	if should_measure:
		# Consume only the request observed by this round. A measurement callback may
		# enqueue another request, which must remain pending for the next round.
		if (
			_sync_measurement_requested
			and _measurement_request_revision == _sync_measurement_request_revision
		):
			_measurement_requested = false
		var measurement_metrics: Dictionary = _measure_active_controls(
			round_scroll_offset,
			generation,
			sync_data_revision
		)
		metrics["measured_count"] = GFVariantData.get_option_int(measurement_metrics, "measured_count")
		metrics["anchor_adjustment"] = GFVariantData.get_option_float(measurement_metrics, "anchor_adjustment")
		if generation != _lifecycle_generation:
			return _make_terminal_result(
				GFVirtualListSyncResult.STATUS_DISPOSED
				if _state == _STATE_DISPOSING
				else GFVirtualListSyncResult.STATUS_UNBOUND
			)
		if not _owned_controls_are_live():
			dispose()
			return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
		if GFVariantData.get_option_bool(measurement_metrics, "deferred"):
			metrics["released_count"] = (
				GFVariantData.get_option_int(metrics, "released_count")
				+ _rollback_materialization_after_data_drift([], generation)
			)
			if generation != _lifecycle_generation:
				return _make_terminal_result(_get_interrupted_status())
			return _make_deferred_sync_result(
				viewport_range,
				requested_range,
				sync_layout_revision,
				sync_data_revision,
				metrics
			)
	var data_revision_changed: bool = sync_data_revision != _last_committed_data_revision
	var layout_revision_changed: bool = sync_layout_revision != _last_committed_layout_revision
	if sync_focus_intent_revision == _focus_intent_revision:
		var physical_focus_current: bool = _reconcile_pending_physical_focus(
			generation,
			sync_data_revision
		)
		if not physical_focus_current and generation == _lifecycle_generation:
			metrics["released_count"] = (
				GFVariantData.get_option_int(metrics, "released_count")
				+ _rollback_materialization_after_data_drift([], generation)
			)
			if generation != _lifecycle_generation:
				return _make_terminal_result(_get_interrupted_status())
			return _make_deferred_sync_result(
				viewport_range,
				requested_range,
				sync_layout_revision,
				sync_data_revision,
				metrics
			)
	if (
		generation == _lifecycle_generation
		and sync_focus_intent_revision == _focus_intent_revision
	):
		var focus_handoff_current: bool = _apply_pending_focus_handoff(
			generation,
			sync_data_revision
		)
		if not focus_handoff_current and generation == _lifecycle_generation:
			metrics["released_count"] = (
				GFVariantData.get_option_int(metrics, "released_count")
				+ _rollback_materialization_after_data_drift([], generation)
			)
			if generation != _lifecycle_generation:
				return _make_terminal_result(_get_interrupted_status())
			return _make_deferred_sync_result(
				viewport_range,
				requested_range,
				sync_layout_revision,
				sync_data_revision,
				metrics
			)
	if generation != _lifecycle_generation:
		return _make_terminal_result(
			GFVirtualListSyncResult.STATUS_DISPOSED
			if _state == _STATE_DISPOSING
			else GFVirtualListSyncResult.STATUS_UNBOUND
		)
	if not _owned_controls_are_live():
		dispose()
		return _make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
	if not _sync_data_revision_is_current(sync_data_revision):
		metrics["released_count"] = (
			GFVariantData.get_option_int(metrics, "released_count")
			+ _rollback_materialization_after_data_drift([], generation)
		)
		if generation != _lifecycle_generation:
			return _make_terminal_result(_get_interrupted_status())
		return _make_deferred_sync_result(
			viewport_range,
			requested_range,
			sync_layout_revision,
			sync_data_revision,
			metrics
		)
	_last_committed_data_revision = sync_data_revision
	_last_committed_layout_revision = sync_layout_revision

	var status: StringName = GFVirtualListSyncResult.STATUS_SYNCED
	if GFVariantData.get_option_bool(metrics, "bind_failed"):
		status = GFVirtualListSyncResult.STATUS_BIND_FAILED
		metrics["error_index"] = GFVariantData.get_option_int(metrics, "bind_error_index", -1)
		metrics["error"] = "bind_callback rejected an item"
	elif truncated:
		status = GFVirtualListSyncResult.STATUS_TRUNCATED
	elif _sync_metrics_are_unchanged(metrics, data_revision_changed, layout_revision_changed):
		status = GFVirtualListSyncResult.STATUS_UNCHANGED
	metrics["truncated"] = truncated
	return _make_sync_result(
		status,
		viewport_range,
		requested_range,
		metrics,
		sync_layout_revision,
		sync_data_revision
	)


func _build_identity_plan(
	target_indices: PackedInt32Array,
	generation: int,
	sync_data_revision: int
) -> Dictionary:
	var descriptors: Array[Dictionary] = []
	var seen_tokens: Dictionary = {}
	for item_index: int in target_indices:
		if generation != _lifecycle_generation:
			return { "status": GFVirtualListSyncResult.STATUS_DISPOSED }
		if not _sync_data_revision_is_current(sync_data_revision):
			return {
				"status": GFVirtualListSyncResult.STATUS_DEFERRED,
				"descriptors": descriptors,
			}
		var item_id: Variant = _identity_callback.call(item_index)
		if generation != _lifecycle_generation:
			return { "status": GFVirtualListSyncResult.STATUS_DISPOSED }
		if not _owned_controls_are_live():
			dispose()
			return { "status": GFVirtualListSyncResult.STATUS_DISPOSED }
		if not _sync_data_revision_is_current(sync_data_revision):
			return {
				"status": GFVirtualListSyncResult.STATUS_DEFERRED,
				"descriptors": descriptors,
			}
		var token_report: Dictionary = _make_bounded_identity_token(item_id)
		if not GFVariantData.get_option_bool(token_report, "ok"):
			var token_error: String = "identity_callback returned an unstable key"
			if GFVariantData.get_option_bool(token_report, "over_limit"):
				token_error = "identity_callback returned a key that exceeds the bounded token limit"
			return {
				"status": GFVirtualListSyncResult.STATUS_INVALID_IDENTITY,
				"error_index": item_index,
				"error": token_error,
				"descriptors": descriptors,
			}
		var token: String = GFVariantData.get_option_string(token_report, "token")
		if seen_tokens.has(token):
			return {
				"status": GFVirtualListSyncResult.STATUS_DUPLICATE_IDENTITY,
				"error_index": item_index,
				"error": "identity_callback returned a duplicate key in the requested range",
				"descriptors": descriptors,
			}
		seen_tokens[token] = true
		descriptors.append({
			"index": item_index,
			"identity": GFVariantData.duplicate_variant(item_id),
			"token": token,
		})
	return {
		"status": GFVirtualListSyncResult.STATUS_SYNCED,
		"descriptors": descriptors,
	}


func _make_bounded_identity_token(item_id: Variant) -> Dictionary:
	if typeof(item_id) in [TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH]:
		var source_text: String = str(item_id)
		if source_text.length() > ABSOLUTE_MAX_IDENTITY_TOKEN_LENGTH:
			return {
				"ok": false,
				"token": "",
				"over_limit": true,
			}
	var token: String = GFVariantKeyCodec.make_key_token(item_id)
	if token.is_empty():
		return {
			"ok": false,
			"token": "",
			"over_limit": false,
		}
	if (
		token.length() > ABSOLUTE_MAX_IDENTITY_TOKEN_LENGTH
		or token.to_utf8_buffer().size() > ABSOLUTE_MAX_IDENTITY_TOKEN_LENGTH
	):
		return {
			"ok": false,
			"token": "",
			"over_limit": true,
		}
	return {
		"ok": true,
		"token": token,
		"over_limit": false,
	}


func _stage_materialization_plan(
	descriptors: Array[Dictionary],
	generation: int,
	sync_data_revision: int
) -> Dictionary:
	var planned_records: Array[Dictionary] = []
	var staged_records: Array[Dictionary] = []
	var target_tokens: Dictionary = {}
	var created_count: int = 0
	var reused_count: int = 0
	for descriptor: Dictionary in descriptors:
		var target_token: String = GFVariantData.get_option_string(descriptor, "token")
		target_tokens[target_token] = true
	var recyclable_records: Array[Dictionary] = []
	for token_value: Variant in _active_by_token.keys():
		if not (token_value is String):
			continue
		var active_token: String = token_value
		if target_tokens.has(active_token):
			continue
		var recyclable_record: Dictionary = _get_active_record(active_token)
		if not recyclable_record.is_empty():
			recyclable_records.append(recyclable_record)
	var recyclable_index: int = 0
	for descriptor: Dictionary in descriptors:
		var token: String = GFVariantData.get_option_string(descriptor, "token")
		var item_index: int = GFVariantData.get_option_int(descriptor, "index", -1)
		var active_record: Dictionary = _get_active_record(token)
		var record: Dictionary = {}
		if not active_record.is_empty():
			record = _make_plan_record_from_active(active_record)
			reused_count += 1
		elif recyclable_index < recyclable_records.size():
			record = _make_plan_record_from_active(recyclable_records[recyclable_index])
			recyclable_index += 1
			reused_count += 1
		else:
			var acquired: Dictionary = _acquire_control(generation, staged_records)
			if not GFVariantData.get_option_bool(acquired, "ok"):
				if not _sync_data_revision_is_current(sync_data_revision):
					return {
						"status": GFVirtualListSyncResult.STATUS_DEFERRED,
						"planned_records": planned_records,
						"staged_records": staged_records,
						"target_tokens": target_tokens,
						"created_count": created_count,
						"reused_count": reused_count,
					}
				return {
					"status": GFVirtualListSyncResult.STATUS_FACTORY_FAILED,
					"planned_records": planned_records,
					"staged_records": staged_records,
					"target_tokens": target_tokens,
					"created_count": created_count,
					"reused_count": reused_count,
					"error_index": item_index,
					"error": GFVariantData.get_option_string(acquired, "error"),
				}
			record = {
				"control": _get_control_value(acquired, "control"),
				"bound": false,
				"attached_to_content": false,
				"from_active": false,
				"from_pool": GFVariantData.get_option_bool(acquired, "from_pool"),
				"source_token": "",
				"previous_index": -1,
			}
			if GFVariantData.get_option_bool(acquired, "created"):
				created_count += 1
			else:
				reused_count += 1
			staged_records.append(record)
			if not _sync_data_revision_is_current(sync_data_revision):
				return {
					"status": GFVirtualListSyncResult.STATUS_DEFERRED,
					"planned_records": planned_records,
					"staged_records": staged_records,
					"target_tokens": target_tokens,
					"created_count": created_count,
					"reused_count": reused_count,
				}
		record["index"] = item_index
		record["identity"] = GFVariantData.get_option_value(descriptor, "identity")
		record["token"] = token
		record["needs_rebind"] = (
			not GFVariantData.get_option_bool(record, "bound")
			or GFVariantData.get_option_string(record, "source_token") != token
			or GFVariantData.get_option_int(record, "previous_index", -1) != item_index
			or sync_data_revision != _last_committed_data_revision
		)
		planned_records.append(record)
	return {
		"status": GFVirtualListSyncResult.STATUS_SYNCED,
		"planned_records": planned_records,
		"staged_records": staged_records,
		"target_tokens": target_tokens,
		"created_count": created_count,
		"reused_count": reused_count,
	}


func _make_plan_record_from_active(active_record: Dictionary) -> Dictionary:
	return {
		"control": _get_record_control(active_record),
		"bound": GFVariantData.get_option_bool(active_record, "bound"),
		"attached_to_content": true,
		"from_active": true,
		"from_pool": false,
		"source_token": GFVariantData.get_option_string(active_record, "token"),
		"previous_index": GFVariantData.get_option_int(active_record, "index", -1),
	}


func _commit_materialization_plan(
	plan: Dictionary,
	generation: int,
	sync_data_revision: int
) -> Dictionary:
	var planned_records: Array[Dictionary] = _get_record_array(plan, "planned_records")
	var target_tokens: Dictionary = GFVariantData.get_option_dictionary(plan, "target_tokens")
	var content_root: Control = _get_content_root()
	var released_count: int = 0
	var bind_failed: bool = false
	var bind_error_index: int = -1
	var data_drifted: bool = false
	var next_active_by_token: Dictionary = {}
	var next_token_by_index: Dictionary = {}
	var rebind_by_source_token: Dictionary = {}
	for planned_record: Dictionary in planned_records:
		var source_token: String = GFVariantData.get_option_string(planned_record, "source_token")
		if not source_token.is_empty() and GFVariantData.get_option_bool(planned_record, "needs_rebind"):
			rebind_by_source_token[source_token] = true

	for token_value: Variant in _active_by_token.keys():
		if generation != _lifecycle_generation:
			break
		if not _sync_data_revision_is_current(sync_data_revision):
			data_drifted = true
			break
		if not (token_value is String):
			continue
		var token: String = token_value
		var record: Dictionary = _get_active_record(token)
		var leaving: bool = not target_tokens.has(token)
		var needs_rebind: bool = rebind_by_source_token.has(token)
		if (leaving or needs_rebind) and GFVariantData.get_option_bool(record, "bound"):
			var control: Control = _get_record_control(record)
			var _released_commit_focus: bool = _release_control_focus_if_owned(record)
			if generation != _lifecycle_generation:
				break
			if not _sync_data_revision_is_current(sync_data_revision):
				data_drifted = true
				break
			if not _transaction_owned_controls_are_live(planned_records):
				dispose()
				break
			_invoke_unbind(record)
			record["bound"] = false
			released_count += 1
			if generation != _lifecycle_generation:
				break
			if not _sync_data_revision_is_current(sync_data_revision):
				data_drifted = true
				break
			if not _control_has_expected_parent(control, content_root):
				dispose()
				break
			if not _transaction_owned_controls_are_live(planned_records):
				dispose()
				break

	if data_drifted:
		released_count += _rollback_materialization_after_data_drift(
			planned_records,
			generation
		)
		return {
			"created_count": GFVariantData.get_option_int(plan, "created_count"),
			"reused_count": GFVariantData.get_option_int(plan, "reused_count"),
			"released_count": released_count,
			"bind_failed": bind_failed,
			"bind_error_index": bind_error_index,
			"deferred": true,
		}

	for record: Dictionary in planned_records:
		if generation != _lifecycle_generation:
			break
		if not _sync_data_revision_is_current(sync_data_revision):
			data_drifted = true
			break
		var control: Control = _get_record_control(record)
		if control == null:
			dispose()
			break
		var item_index: int = GFVariantData.get_option_int(record, "index", -1)
		var token: String = GFVariantData.get_option_string(record, "token")
		var needs_rebind: bool = GFVariantData.get_option_bool(record, "needs_rebind")
		if not _ensure_control_parent(
			control,
			GFVariantData.get_option_bool(record, "from_active")
		):
			break
		record["attached_to_content"] = true
		if generation != _lifecycle_generation:
			break
		if not _sync_data_revision_is_current(sync_data_revision):
			data_drifted = true
			break
		if not _transaction_owned_controls_are_live(planned_records):
			dispose()
			break
		if needs_rebind:
			record["bound"] = true
			record["bind_invoked"] = true
			var accepted: bool = _invoke_bind(record)
			if generation != _lifecycle_generation:
				break
			if not _control_has_expected_parent(control, content_root):
				dispose()
				break
			if not _transaction_owned_controls_are_live(planned_records):
				dispose()
				break
			if not _sync_data_revision_is_current(sync_data_revision):
				data_drifted = true
				break
			if not accepted:
				_invoke_unbind(record)
				record["bound"] = false
				record["bind_invoked"] = false
				if generation != _lifecycle_generation:
					break
				if not _sync_data_revision_is_current(sync_data_revision):
					data_drifted = true
					break
				if not _transaction_owned_controls_are_live(planned_records):
					dispose()
					break
				if not _release_control_to_pool(control, content_root):
					break
				record["attached_to_content"] = false
				if generation != _lifecycle_generation:
					break
				if not _sync_data_revision_is_current(sync_data_revision):
					data_drifted = true
					break
				if not _transaction_owned_controls_are_live(planned_records):
					dispose()
					break
				bind_failed = true
				if bind_error_index < 0:
					bind_error_index = item_index
				continue
		next_active_by_token[token] = record
		next_token_by_index[item_index] = token

	if data_drifted:
		released_count += _rollback_materialization_after_data_drift(
			planned_records,
			generation
		)
		return {
			"created_count": GFVariantData.get_option_int(plan, "created_count"),
			"reused_count": GFVariantData.get_option_int(plan, "reused_count"),
			"released_count": released_count,
			"bind_failed": bind_failed,
			"bind_error_index": bind_error_index,
			"deferred": true,
		}
	if generation != _lifecycle_generation:
		_abort_materialization_commit(planned_records)
		return {
			"created_count": GFVariantData.get_option_int(plan, "created_count"),
			"reused_count": GFVariantData.get_option_int(plan, "reused_count"),
			"released_count": released_count,
			"bind_failed": bind_failed,
			"bind_error_index": bind_error_index,
		}
	var next_control_ids: Dictionary = {}
	for next_record_value: Variant in next_active_by_token.values():
		if next_record_value is Dictionary:
			var next_record: Dictionary = next_record_value
			var next_control: Control = _get_record_control(next_record)
			if next_control != null:
				next_control_ids[next_control.get_instance_id()] = true
	for token_value: Variant in _active_by_token.keys():
		if not _sync_data_revision_is_current(sync_data_revision):
			data_drifted = true
			break
		if not (token_value is String):
			continue
		var token: String = token_value
		var record: Dictionary = _get_active_record(token)
		var control: Control = _get_record_control(record)
		if (
			control != null
			and not next_control_ids.has(control.get_instance_id())
		):
			if control in _pool:
				continue
			if not _release_control_to_pool(control, content_root):
				break
			if generation != _lifecycle_generation:
				break
			if not _sync_data_revision_is_current(sync_data_revision):
				data_drifted = true
				break
			if not _transaction_owned_controls_are_live(planned_records):
				dispose()
				break
	if data_drifted:
		released_count += _rollback_materialization_after_data_drift(
			planned_records,
			generation
		)
		return {
			"created_count": GFVariantData.get_option_int(plan, "created_count"),
			"reused_count": GFVariantData.get_option_int(plan, "reused_count"),
			"released_count": released_count,
			"bind_failed": bind_failed,
			"bind_error_index": bind_error_index,
			"deferred": true,
		}
	if generation != _lifecycle_generation:
		_abort_materialization_commit(planned_records)
		return {
			"created_count": GFVariantData.get_option_int(plan, "created_count"),
			"reused_count": GFVariantData.get_option_int(plan, "reused_count"),
			"released_count": released_count,
			"bind_failed": bind_failed,
			"bind_error_index": bind_error_index,
		}
	if not _sync_data_revision_is_current(sync_data_revision):
		released_count += _rollback_materialization_after_data_drift(
			planned_records,
			generation
		)
		return {
			"created_count": GFVariantData.get_option_int(plan, "created_count"),
			"reused_count": GFVariantData.get_option_int(plan, "reused_count"),
			"released_count": released_count,
			"bind_failed": bind_failed,
			"bind_error_index": bind_error_index,
			"deferred": true,
		}
	for record: Dictionary in planned_records:
		var _erased_needs_rebind: bool = record.erase("needs_rebind")
		var _erased_source_token: bool = record.erase("source_token")
		var _erased_previous_index: bool = record.erase("previous_index")
		var _erased_from_active: bool = record.erase("from_active")
		var _erased_from_pool: bool = record.erase("from_pool")
		var _erased_bind_invoked: bool = record.erase("bind_invoked")
		var _erased_attached: bool = record.erase("attached_to_content")
	_active_by_token = next_active_by_token
	_token_by_index = next_token_by_index
	if generation == _lifecycle_generation and not _owned_controls_are_live():
		dispose()
	return {
		"created_count": GFVariantData.get_option_int(plan, "created_count"),
		"reused_count": GFVariantData.get_option_int(plan, "reused_count"),
		"released_count": released_count,
		"bind_failed": bind_failed,
		"bind_error_index": bind_error_index,
	}


func _abort_materialization_commit(planned_records: Array[Dictionary]) -> void:
	var content_root: Control = _get_content_root()
	for record: Dictionary in planned_records:
		var was_bound: bool = GFVariantData.get_option_bool(record, "bind_invoked")
		var was_attached: bool = GFVariantData.get_option_bool(record, "attached_to_content")
		if was_bound:
			_invoke_unbind(record)
			record["bound"] = false
			record["bind_invoked"] = false
		if GFVariantData.get_option_bool(record, "from_active"):
			continue
		var control: Control = _get_record_control(record)
		if control == null:
			dispose()
			continue
		if control in _pool:
			record["attached_to_content"] = false
			continue
		var expected_parent: Node = content_root if was_attached else null
		var _released: bool = _release_control_to_pool(control, expected_parent)
		record["attached_to_content"] = false


func _rollback_materialization_after_data_drift(
	planned_records: Array[Dictionary],
	generation: int
) -> int:
	var released_count: int = 0
	_abort_materialization_commit(planned_records)
	if generation != _lifecycle_generation or not is_bound():
		return released_count
	var content_root: Control = _get_content_root()
	if content_root == null:
		dispose()
		return released_count
	var seen_control_ids: Dictionary = {}
	for token_value: Variant in _active_by_token.keys():
		if generation != _lifecycle_generation:
			return released_count
		if not (token_value is String):
			continue
		var token: String = token_value
		var record: Dictionary = _get_active_record(token)
		var control: Control = _get_record_control(record)
		if control == null:
			dispose()
			return released_count
		var control_id: int = control.get_instance_id()
		if seen_control_ids.has(control_id):
			continue
		seen_control_ids[control_id] = true
		if GFVariantData.get_option_bool(record, "bound"):
			var _released_rollback_focus: bool = _release_control_focus_if_owned(record)
			if generation != _lifecycle_generation:
				return released_count
			if not _transaction_owned_controls_are_live(planned_records):
				dispose()
				return released_count
			_invoke_unbind(record)
			record["bound"] = false
			released_count += 1
			if generation != _lifecycle_generation:
				return released_count
			if not _transaction_owned_controls_are_live(planned_records):
				dispose()
				return released_count
		if control in _pool:
			_mark_planned_control_parentless(planned_records, control)
			continue
		if not _release_control_to_pool(control, content_root):
			return released_count
		_mark_planned_control_parentless(planned_records, control)
		if generation != _lifecycle_generation:
			return released_count
		if not _transaction_owned_controls_are_live(planned_records):
			dispose()
			return released_count
	_active_by_token.clear()
	_token_by_index.clear()
	return released_count


func _mark_planned_control_parentless(
	planned_records: Array[Dictionary],
	control: Control
) -> void:
	if control == null:
		return
	for planned_record: Dictionary in planned_records:
		if is_same(_get_record_control(planned_record), control):
			planned_record["attached_to_content"] = false


func _measure_active_controls(
	scroll_offset: float,
	generation: int,
	sync_data_revision: int
) -> Dictionary:
	var measured_count: int = 0
	var anchor_adjustment: float = 0.0
	if not _sync_data_revision_is_current(sync_data_revision):
		_queue_measurement_request()
		return {
			"measured_count": measured_count,
			"anchor_adjustment": anchor_adjustment,
			"deferred": true,
		}
	if not _sync_layout_model_is_current():
		_queue_measurement_request()
		return {
			"measured_count": measured_count,
			"anchor_adjustment": anchor_adjustment,
		}
	var active_indices: Array[int] = _get_active_indices()
	var anchored_indices: Dictionary = {}
	for item_index: int in active_indices:
		var geometry: Dictionary = _get_sync_item_geometry(item_index)
		var geometry_extent: float = GFVariantData.get_option_float(geometry, "extent")
		if geometry_extent <= 0.0:
			dispose()
			break
		var item_bottom: float = (
			GFVariantData.get_option_float(geometry, "offset")
			+ geometry_extent
		)
		if item_bottom <= scroll_offset + 0.5:
			anchored_indices[item_index] = true
	for item_index: int in active_indices:
		if generation != _lifecycle_generation:
			break
		if not _sync_data_revision_is_current(sync_data_revision):
			_queue_measurement_request()
			return {
				"measured_count": measured_count,
				"anchor_adjustment": 0.0,
				"deferred": true,
			}
		if not _sync_layout_model_is_current():
			_queue_measurement_request()
			break
		var record: Dictionary = _get_record_for_index(item_index)
		var control: Control = _get_record_control(record)
		if control == null:
			continue
		var extent: float = _measure_control(record)
		if generation != _lifecycle_generation:
			break
		if not _owned_controls_are_live():
			dispose()
			break
		if not _sync_data_revision_is_current(sync_data_revision):
			_queue_measurement_request()
			return {
				"measured_count": measured_count,
				"anchor_adjustment": 0.0,
				"deferred": true,
			}
		if not _sync_layout_model_is_current():
			_queue_measurement_request()
			break
		if not is_finite(extent) or extent <= 0.0:
			continue
		var report: Dictionary = _sync_layout_model.set_item_extent(item_index, extent, true)
		var report_ok: bool = GFVariantData.get_option_bool(report, "ok")
		if report_ok:
			measured_count += 1
		if generation != _lifecycle_generation:
			break
		if not _owned_controls_are_live():
			dispose()
			break
		if not _sync_data_revision_is_current(sync_data_revision):
			_queue_measurement_request()
			return {
				"measured_count": measured_count,
				"anchor_adjustment": 0.0,
				"deferred": true,
			}
		var report_changed: bool = GFVariantData.get_option_bool(report, "changed")
		var expected_revision: int = _sync_expected_layout_revision
		if report_changed:
			expected_revision += 1
		if (
			not is_same(_layout_model, _sync_layout_model)
			or _sync_layout_model.get_revision() != expected_revision
		):
			_queue_measurement_request()
			break
		_sync_expected_layout_revision = expected_revision
		if not report_ok:
			continue
		if report_changed:
			_apply_sync_measurement_report(item_index, report)
			if anchored_indices.has(item_index):
				anchor_adjustment += GFVariantData.get_option_float(report, "delta")
	if generation != _lifecycle_generation:
		return {
			"measured_count": measured_count,
			"anchor_adjustment": 0.0,
		}
	_update_content_extent()
	if generation != _lifecycle_generation:
		return {
			"measured_count": measured_count,
			"anchor_adjustment": 0.0,
		}
	if not _owned_controls_are_live():
		dispose()
		return {
			"measured_count": measured_count,
			"anchor_adjustment": 0.0,
		}
	if not _sync_data_revision_is_current(sync_data_revision):
		_queue_measurement_request()
		return {
			"measured_count": measured_count,
			"anchor_adjustment": 0.0,
			"deferred": true,
		}
	if not _layout_active_controls(generation, sync_data_revision):
		var layout_data_drifted: bool = (
			generation == _lifecycle_generation
			and not _sync_data_revision_is_current(sync_data_revision)
		)
		if layout_data_drifted:
			_queue_measurement_request()
		return {
			"measured_count": measured_count,
			"anchor_adjustment": 0.0,
			"deferred": layout_data_drifted,
		}
	if generation != _lifecycle_generation:
		return {
			"measured_count": measured_count,
			"anchor_adjustment": 0.0,
		}
	if not _owned_controls_are_live():
		dispose()
		return {
			"measured_count": measured_count,
			"anchor_adjustment": 0.0,
		}
	if not _sync_data_revision_is_current(sync_data_revision):
		_queue_measurement_request()
		return {
			"measured_count": measured_count,
			"anchor_adjustment": 0.0,
			"deferred": true,
		}
	if not is_zero_approx(anchor_adjustment):
		var scroll_container: ScrollContainer = _get_scroll_container()
		if scroll_container != null:
			_applying_scroll_adjustment = true
			_set_scroll_offset(scroll_container, scroll_offset + anchor_adjustment)
			_applying_scroll_adjustment = false
			if generation != _lifecycle_generation:
				return {
					"measured_count": measured_count,
					"anchor_adjustment": 0.0,
				}
			if not _owned_controls_are_live():
				dispose()
				return {
					"measured_count": measured_count,
					"anchor_adjustment": 0.0,
				}
			if not _sync_data_revision_is_current(sync_data_revision):
				_queue_measurement_request()
				return {
					"measured_count": measured_count,
					"anchor_adjustment": anchor_adjustment,
					"deferred": true,
				}
	return {
		"measured_count": measured_count,
		"anchor_adjustment": anchor_adjustment,
	}


func _layout_active_controls(generation: int, sync_data_revision: int) -> bool:
	var content_root: Control = _get_content_root()
	var scroll_container: ScrollContainer = _get_scroll_container()
	if content_root == null or scroll_container == null or _layout_model == null:
		dispose()
		return false
	var effective_axis: int = _get_effective_layout_axis()
	var effective_fill_cross_axis: bool = _get_effective_fill_cross_axis()
	var cross_extent: float = (
		maxf(content_root.size.y, scroll_container.size.y)
		if effective_axis == LayoutAxis.HORIZONTAL
		else maxf(content_root.size.x, scroll_container.size.x)
	)
	for item_index: int in _get_active_indices():
		if not _layout_write_barrier_is_current(generation, sync_data_revision):
			return false
		var control: Control = get_materialized_control(item_index)
		if control == null:
			continue
		var offset: float = 0.0
		var extent: float = 0.0
		if _sync_context_ready:
			var geometry: Dictionary = _get_sync_item_geometry(item_index)
			extent = GFVariantData.get_option_float(geometry, "extent")
			if extent <= 0.0:
				dispose()
				return false
			offset = GFVariantData.get_option_float(geometry, "offset")
		else:
			offset = _layout_model.get_item_offset(item_index)
			extent = _layout_model.get_item_extent(item_index)
		var next_position: Vector2 = control.position
		var next_size: Vector2 = control.size
		if effective_axis == LayoutAxis.HORIZONTAL:
			next_position.x = offset
			next_size.x = extent
			if effective_fill_cross_axis:
				next_position.y = 0.0
				next_size.y = cross_extent
		else:
			next_position.y = offset
			next_size.y = extent
			if effective_fill_cross_axis:
				next_position.x = 0.0
				next_size.x = cross_extent
		control.position = next_position
		if not _layout_write_barrier_is_current(generation, sync_data_revision):
			return false
		control.size = next_size
		if not _layout_write_barrier_is_current(generation, sync_data_revision):
			return false
	return true


func _layout_write_barrier_is_current(
	generation: int,
	sync_data_revision: int
) -> bool:
	if generation != _lifecycle_generation:
		return false
	if not _owned_controls_are_live():
		dispose()
		return false
	return _sync_data_revision_is_current(sync_data_revision)


func _update_content_extent() -> void:
	var content_root: Control = _get_content_root()
	if content_root == null or _layout_model == null:
		return
	var content_extent: float = (
		_sync_content_extent
		if _sync_context_ready
		else _layout_model.get_content_extent()
	)
	var next_owned_axis: int = _get_effective_layout_axis()
	_apply_content_extent_snapshot(content_root, next_owned_axis, content_extent)


func _apply_content_extent_snapshot(
	content_root: Control,
	next_owned_axis: int,
	content_extent: float
) -> void:
	var minimum_size: Vector2 = content_root.custom_minimum_size
	if _owned_layout_axis != -1 and _owned_layout_axis != next_owned_axis:
		if _owned_layout_axis == LayoutAxis.HORIZONTAL:
			minimum_size.x = _owned_layout_axis_baseline
		else:
			minimum_size.y = _owned_layout_axis_baseline
		_owned_layout_axis = -1
	if _owned_layout_axis == -1:
		_owned_layout_axis_baseline = (
			minimum_size.x
			if next_owned_axis == LayoutAxis.HORIZONTAL
			else minimum_size.y
		)
		_owned_layout_axis = next_owned_axis
	if next_owned_axis == LayoutAxis.HORIZONTAL:
		minimum_size.x = content_extent
	else:
		minimum_size.y = content_extent
	content_root.custom_minimum_size = minimum_size


func _select_target_indices(viewport_range: Vector2i, requested_range: Vector2i) -> Dictionary:
	var limit: int = maxi(_sync_max_materialized_items, 1)
	var requested_count: int = maxi(requested_range.y - requested_range.x, 0)
	var result: Array[int] = []
	if requested_count <= limit:
		for item_index: int in range(requested_range.x, requested_range.y):
			result.append(item_index)
		return {
			"indices": PackedInt32Array(result),
			"truncated": false,
		}

	for item_index: int in range(viewport_range.x, mini(viewport_range.y, viewport_range.x + limit)):
		result.append(item_index)
	var before_index: int = viewport_range.x - 1
	var after_index: int = viewport_range.y
	while result.size() < limit and (before_index >= requested_range.x or after_index < requested_range.y):
		if before_index >= requested_range.x and result.size() < limit:
			result.append(before_index)
			before_index -= 1
		if after_index < requested_range.y and result.size() < limit:
			result.append(after_index)
			after_index += 1
	result.sort()
	return {
		"indices": PackedInt32Array(result),
		"truncated": true,
	}


func _acquire_control(generation: int, staged_records: Array[Dictionary]) -> Dictionary:
	if not _owned_controls_are_live(staged_records):
		dispose()
		return { "ok": false, "error": "owned Control boundary was violated" }
	if not _pool.is_empty():
		var pooled_value: Variant = _pool.pop_back()
		var pooled: Control = _get_live_control(pooled_value)
		if not _control_has_expected_parent(pooled, null):
			dispose()
			return { "ok": false, "error": "pooled Control boundary was violated" }
		return {
			"ok": true,
			"control": pooled,
			"from_pool": true,
			"created": false,
		}
	if generation != _lifecycle_generation:
		return { "ok": false, "error": "binding generation ended" }
	var value: Variant = _item_factory.call()
	if generation != _lifecycle_generation:
		if value is Control:
			var abandoned_control: Control = value
			if (
				is_instance_valid(abandoned_control)
				and not abandoned_control.is_queued_for_deletion()
				and abandoned_control.get_parent() == null
			):
				abandoned_control.queue_free()
		return { "ok": false, "error": "binding generation ended" }
	if not _owned_controls_are_live(staged_records):
		if value is Control:
			var abandoned_control: Control = value
			if (
				is_instance_valid(abandoned_control)
				and not abandoned_control.is_queued_for_deletion()
				and abandoned_control.get_parent() == null
			):
				abandoned_control.queue_free()
		dispose()
		return { "ok": false, "error": "owned Control boundary was violated" }
	if not (value is Control):
		return { "ok": false, "error": "item_factory did not return Control" }
	var control: Control = value
	if not is_instance_valid(control) or control.is_queued_for_deletion() or control.get_parent() != null:
		return { "ok": false, "error": "item_factory returned an invalid or parented Control" }
	var control_id: int = control.get_instance_id()
	if _known_control_ids.has(control_id):
		return { "ok": false, "error": "item_factory returned a Control already owned by this Binder" }
	_known_control_ids[control_id] = true
	return {
		"ok": true,
		"control": control,
		"from_pool": false,
		"created": true,
	}


func _rollback_staged_records(records: Array[Dictionary]) -> void:
	for record: Dictionary in records:
		var control: Control = _get_record_control(record)
		if control == null:
			dispose()
			continue
		var _released: bool = _release_control_to_pool(control, null)


func _release_control_to_pool(control: Control, expected_parent: Node) -> bool:
	if control == null or not is_instance_valid(control) or control.is_queued_for_deletion():
		dispose()
		return false
	if _state in [_STATE_DISPOSING, _STATE_DISPOSED]:
		_queue_free_owned_control(control)
		return true
	var parent: Node = control.get_parent()
	if parent != expected_parent:
		dispose()
		_queue_free_owned_control(control)
		return false
	if parent != null:
		parent.remove_child(control)
	if _state not in [_STATE_DISPOSING, _STATE_DISPOSED]:
		_pool.append(control)
		_pool_trim_requested = true
		return true
	_queue_free_owned_control(control)
	return true


func _trim_pool_to_limit() -> void:
	_pool_trim_requested = false
	if not _pool_controls_are_live():
		dispose()
		return
	var limit: int = clampi(max_pooled_items, 0, ABSOLUTE_MAX_POOLED_ITEMS)
	while _pool.size() > limit:
		var control_value: Variant = _pool.pop_back()
		var control: Control = _get_live_control(control_value)
		if control != null:
			_queue_free_owned_control(control)


func _queue_free_owned_control(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	var control_id: int = control.get_instance_id()
	var _known_erased: bool = _known_control_ids.erase(control_id)
	var parent: Node = control.get_parent()
	if parent != null:
		parent.remove_child(control)
	if not control.is_queued_for_deletion():
		control.queue_free()


func _ensure_control_parent(control: Control, from_active: bool) -> bool:
	var content_root: Control = _get_content_root()
	if (
		content_root == null
		or control == null
		or not is_instance_valid(control)
		or control.is_queued_for_deletion()
	):
		dispose()
		return false
	var expected_parent: Node = content_root if from_active else null
	if not _control_has_expected_parent(control, expected_parent):
		dispose()
		return false
	if from_active:
		return true
	content_root.add_child(control)
	if not _control_has_expected_parent(control, content_root):
		dispose()
		return false
	return true


func _invoke_bind(record: Dictionary) -> bool:
	var control: Control = _get_record_control(record)
	if control == null:
		return false
	var result: Variant = _bind_callback.call(
		control,
		GFVariantData.get_option_int(record, "index", -1),
		GFVariantData.get_option_value(record, "identity")
	)
	if result is bool:
		var accepted: bool = result
		return accepted
	return false


func _invoke_unbind(record: Dictionary) -> void:
	var control: Control = _get_record_control(record)
	if control == null or not _unbind_callback.is_valid():
		return
	var _result: Variant = _unbind_callback.call(
		control,
		GFVariantData.get_option_int(record, "index", -1),
		GFVariantData.get_option_value(record, "identity")
	)


func _measure_control(record: Dictionary) -> float:
	var control: Control = _get_record_control(record)
	if control == null:
		return 0.0
	if _measure_callback.is_valid():
		var value: Variant = _measure_callback.call(
			control,
			GFVariantData.get_option_int(record, "index", -1),
			GFVariantData.get_option_value(record, "identity")
		)
		if value is float:
			var measured_float: float = value
			return measured_float
		if value is int:
			var measured_int: int = value
			return float(measured_int)
	var minimum_size: Vector2 = control.get_combined_minimum_size()
	var effective_axis: int = _get_effective_layout_axis()
	var extent: float = (
		minimum_size.x
		if effective_axis == LayoutAxis.HORIZONTAL
		else minimum_size.y
	)
	if extent <= 0.0:
		extent = control.size.x if effective_axis == LayoutAxis.HORIZONTAL else control.size.y
	return extent


func _scroll_to_item_internal(item_index: int, alignment: ScrollAlignment) -> bool:
	if _sync_in_progress and _sync_context_ready:
		return false
	var generation: int = _lifecycle_generation
	var layout_model: GFVirtualListModel = _layout_model
	var scroll_container: ScrollContainer = _get_scroll_container()
	var content_root: Control = _get_content_root()
	if (
		not is_bound()
		or scroll_container == null
		or content_root == null
		or layout_model == null
		or item_index < 0
		or item_index >= layout_model.get_item_count()
	):
		return false
	# Freeze the complete public operation before custom_minimum_size or scroll
	# writes can synchronously invoke project listeners.
	var operation_axis: int = int(layout_axis)
	var operation_data_revision: int = _data_revision
	var operation_layout_revision: int = layout_model.get_revision()
	var operation_content_extent: float = layout_model.get_content_extent()
	var item_start: float = layout_model.get_item_offset(item_index)
	var item_extent: float = layout_model.get_item_extent(item_index)
	var viewport_extent: float = _get_viewport_extent_for_axis(
		scroll_container,
		operation_axis
	)
	var scroll_offset: float = _get_scroll_offset_for_axis(scroll_container, operation_axis)
	var next_offset: float = _calculate_scroll_offset_for_geometry(
		item_start,
		item_extent,
		alignment,
		scroll_offset,
		viewport_extent,
		operation_content_extent
	)
	next_offset = _quantize_scroll_offset(next_offset)
	_apply_content_extent_snapshot(
		content_root,
		operation_axis,
		operation_content_extent
	)
	if not _scroll_operation_is_current(
		generation,
		operation_data_revision,
		layout_model,
		operation_layout_revision,
		operation_axis,
		viewport_extent,
		scroll_container,
		content_root
	):
		_request_sync_after_scroll_drift()
		return false
	_set_scroll_offset_for_axis(scroll_container, next_offset, operation_axis)
	var operation_is_current: bool = _scroll_operation_is_current(
		generation,
		operation_data_revision,
		layout_model,
		operation_layout_revision,
		operation_axis,
		viewport_extent,
		scroll_container,
		content_root
	)
	operation_is_current = (
		operation_is_current
		and is_equal_approx(
			_get_scroll_offset_for_axis(scroll_container, operation_axis),
			next_offset
		)
	)
	if not operation_is_current:
		_request_sync_after_scroll_drift()
	return operation_is_current


func _scroll_operation_is_current(
	generation: int,
	data_revision: int,
	layout_model: GFVirtualListModel,
	layout_revision: int,
	operation_axis: int,
	viewport_extent: float,
	scroll_container: ScrollContainer,
	content_root: Control
) -> bool:
	var binding_is_current: bool = (
		generation == _lifecycle_generation
		and _data_revision == data_revision
		and is_bound()
		and is_same(_layout_model, layout_model)
		and layout_model.get_revision() == layout_revision
		and int(layout_axis) == operation_axis
		and is_equal_approx(
			_get_viewport_extent_for_axis(scroll_container, operation_axis),
			viewport_extent
		)
		and is_same(_get_scroll_container(), scroll_container)
		and is_same(_get_content_root(), content_root)
		and _binding_objects_are_live()
	)
	if not binding_is_current:
		return false
	if not _owned_controls_are_live():
		dispose()
		return false
	return true


func _request_sync_after_scroll_drift() -> void:
	if is_bound() and _state not in [_STATE_UNBINDING, _STATE_DISPOSING]:
		var _requested: bool = request_sync()


func _calculate_scroll_offset_for_item(
	layout_model: GFVirtualListModel,
	item_index: int,
	alignment: ScrollAlignment,
	scroll_offset: float,
	viewport_extent: float,
	content_extent: float
) -> float:
	var item_start: float = layout_model.get_item_offset(item_index)
	var item_extent: float = layout_model.get_item_extent(item_index)
	return _calculate_scroll_offset_for_geometry(
		item_start,
		item_extent,
		alignment,
		scroll_offset,
		viewport_extent,
		content_extent
	)


func _calculate_scroll_offset_for_geometry(
	item_start: float,
	item_extent: float,
	alignment: ScrollAlignment,
	scroll_offset: float,
	viewport_extent: float,
	content_extent: float
) -> float:
	var item_end: float = item_start + item_extent
	var next_offset: float = scroll_offset
	match alignment:
		ScrollAlignment.START:
			next_offset = item_start
		ScrollAlignment.CENTER:
			next_offset = item_start - (viewport_extent - item_extent) * 0.5
		ScrollAlignment.END:
			next_offset = item_end - viewport_extent
		_:
			if item_start < scroll_offset:
				next_offset = item_start
			elif item_end > scroll_offset + viewport_extent:
				next_offset = item_end - viewport_extent
	var max_offset: float = maxf(content_extent - viewport_extent, 0.0)
	return clampf(next_offset, 0.0, max_offset)


func _reconcile_pending_physical_focus(
	generation: int,
	sync_data_revision: int
) -> bool:
	if not _sync_data_revision_is_current(sync_data_revision):
		return false
	if not _pending_physical_focus_reconciliation:
		return true
	_pending_physical_focus_reconciliation = false
	var viewport: Viewport = _get_viewport()
	var focus_owner: Control = viewport.gui_get_focus_owner() if viewport != null else null
	if focus_owner == null:
		return true
	var focused_index: int = (
		_focus_model.focused_index
		if _focus_model != null
		else GFVirtualListFocusModel.NO_FOCUS
	)
	for item_index: int in _get_active_indices():
		var record: Dictionary = _get_record_for_index(item_index)
		var control: Control = _get_record_control(record)
		if (
			control == null
			or (
				focus_owner != control
				and not _node_is_descendant_of(focus_owner, control)
			)
		):
			continue
		if item_index != focused_index:
			var project_focus_replaced_release: bool = _release_control_focus_if_owned(record)
			if generation != _lifecycle_generation:
				return false
			if not _owned_controls_are_live():
				dispose()
				return false
			if not _sync_data_revision_is_current(sync_data_revision):
				return false
			if project_focus_replaced_release:
				_clear_pending_focus_handoff()
		return true
	return true


func _apply_pending_focus_handoff(
	generation: int,
	sync_data_revision: int
) -> bool:
	if not _sync_data_revision_is_current(sync_data_revision):
		return false
	if not _pending_focus_handoff or _focus_model == null:
		return true
	var handoff_index: int = _pending_focus_index
	if handoff_index != _focus_model.focused_index:
		_clear_pending_focus_handoff()
		return true
	var viewport: Viewport = _get_viewport()
	if _pending_focus_started_with_owner and (
		viewport == null or viewport.gui_get_focus_owner() == null
	):
		_clear_pending_focus_handoff()
		return true
	var record: Dictionary = _get_record_for_index(handoff_index)
	var control: Control = _get_record_control(record)
	if control == null:
		return true
	var focus_target: Control = control
	if _focus_target_callback.is_valid():
		var value: Variant = _focus_target_callback.call(
			control,
			handoff_index,
			GFVariantData.get_option_value(record, "identity")
		)
		if generation != _lifecycle_generation:
			return false
		if not _owned_controls_are_live():
			dispose()
			return false
		if not _sync_data_revision_is_current(sync_data_revision):
			return false
		if not _focus_handoff_is_current(generation, handoff_index):
			return true
		if value is Control and is_instance_valid(value):
			var candidate: Control = value
			if (
				not candidate.is_queued_for_deletion()
				and (candidate == control or _node_is_descendant_of(candidate, control))
			):
				focus_target = candidate
	if not _focus_handoff_is_current(generation, handoff_index):
		return true
	if (
		not is_instance_valid(focus_target)
		or focus_target.is_queued_for_deletion()
		or focus_target.focus_mode == Control.FOCUS_NONE
		or not focus_target.is_inside_tree()
		or not focus_target.is_visible_in_tree()
	):
		return true
	_focus_handoff_in_progress = true
	_focus_handoff_index = handoff_index
	_focus_handoff_observed_target = false
	focus_target.grab_focus()
	var observed_target: bool = _focus_handoff_observed_target
	_focus_handoff_in_progress = false
	_focus_handoff_index = GFVirtualListFocusModel.NO_FOCUS
	_focus_handoff_observed_target = false
	if generation != _lifecycle_generation:
		return false
	if not _owned_controls_are_live():
		dispose()
		return false
	if not _sync_data_revision_is_current(sync_data_revision):
		return false
	var focus_owner: Control = viewport.gui_get_focus_owner() if viewport != null else null
	if (
		_focus_handoff_is_current(generation, handoff_index)
		and (
			(
				focus_owner != null
				and (focus_owner == control or _node_is_descendant_of(focus_owner, control))
			)
			or (observed_target and focus_owner == null)
		)
	):
		_clear_pending_focus_handoff()
	return true


func _focus_handoff_is_current(generation: int, handoff_index: int) -> bool:
	return (
		generation == _lifecycle_generation
		and _pending_focus_handoff
		and _pending_focus_index == handoff_index
		and _focus_model != null
		and _focus_model.focused_index == handoff_index
	)


func _arm_pending_focus_handoff(item_index: int) -> void:
	_pending_focus_index = item_index
	_pending_focus_handoff = item_index != GFVirtualListFocusModel.NO_FOCUS
	_pending_focus_started_with_owner = false
	if not _pending_focus_handoff:
		return
	var viewport: Viewport = _get_viewport()
	_pending_focus_started_with_owner = (
		viewport != null and viewport.gui_get_focus_owner() != null
	)


func _clear_pending_focus_handoff() -> void:
	_pending_focus_handoff = false
	_pending_focus_index = GFVirtualListFocusModel.NO_FOCUS
	_pending_focus_started_with_owner = false


func _arm_pending_focus_reveal(item_index: int) -> void:
	if not auto_reveal_focus or item_index == GFVirtualListFocusModel.NO_FOCUS:
		_clear_pending_focus_reveal()
		return
	_pending_focus_reveal_index = item_index


func _clear_pending_focus_reveal() -> void:
	_pending_focus_reveal_index = GFVirtualListFocusModel.NO_FOCUS


func _adopt_bound_virtual_focus() -> void:
	_clear_pending_focus_handoff()
	_clear_pending_focus_reveal()
	if _focus_model == null:
		return
	var focused_index: int = _focus_model.focused_index
	if focused_index == GFVirtualListFocusModel.NO_FOCUS:
		return
	if auto_reveal_focus:
		_arm_pending_focus_reveal(focused_index)
		var _revealed: bool = _scroll_to_item_internal(focused_index, ScrollAlignment.NEAREST)
	var viewport: Viewport = _get_viewport()
	if viewport != null and viewport.gui_get_focus_owner() == null:
		_arm_pending_focus_handoff(focused_index)


func _release_control_focus_if_owned(record: Dictionary) -> bool:
	var control: Control = _get_record_control(record)
	var viewport: Viewport = _get_viewport()
	if control == null or viewport == null:
		return false
	var focus_owner: Control = viewport.gui_get_focus_owner()
	if focus_owner == null:
		return false
	if focus_owner != control and not _node_is_descendant_of(focus_owner, control):
		return false
	focus_owner.release_focus()
	if viewport.gui_get_focus_owner() != null:
		return true
	if (
		_focus_model != null
		and _focus_model.focused_index == GFVariantData.get_option_int(record, "index", -1)
	):
		_arm_pending_focus_handoff(_focus_model.focused_index)
	return false


func _connect_binding_signals(
	owner: Node,
	scroll_container: ScrollContainer,
	content_root: Control,
	viewport: Viewport
) -> void:
	_binding_tree_exited_callable = Callable(self, "_on_binding_tree_exited")
	_scroll_resized_callable = Callable(self, "_on_scroll_resized")
	_content_resized_callable = Callable(self, "_on_content_resized")
	_vertical_scroll_callable = Callable(self, "_on_scroll_value_changed")
	_horizontal_scroll_callable = Callable(self, "_on_scroll_value_changed")
	_layout_changed_callable = Callable(self, "_on_layout_changed")
	_focus_changed_callable = Callable(self, "_on_focus_changed")
	_viewport_focus_changed_callable = Callable(self, "_on_viewport_focus_changed")
	var lifecycle_nodes: Array[Node] = [owner, scroll_container, content_root]
	var connected_node_ids: Dictionary = {}
	_binding_tree_exit_refs.clear()
	for lifecycle_node: Node in lifecycle_nodes:
		var node_id: int = lifecycle_node.get_instance_id()
		if connected_node_ids.has(node_id):
			continue
		connected_node_ids[node_id] = true
		var connect_result: Error = OK
		if not lifecycle_node.tree_exited.is_connected(_binding_tree_exited_callable):
			connect_result = lifecycle_node.tree_exited.connect(
				_binding_tree_exited_callable,
				CONNECT_ONE_SHOT
			) as Error
		if connect_result == OK:
			_binding_tree_exit_refs.append(weakref(lifecycle_node))
	var _scroll_resized_connected: Error = scroll_container.resized.connect(_scroll_resized_callable) as Error
	var _content_resized_connected: Error = content_root.resized.connect(_content_resized_callable) as Error
	var _vertical_connected: Error = scroll_container.get_v_scroll_bar().value_changed.connect(_vertical_scroll_callable) as Error
	var _horizontal_connected: Error = scroll_container.get_h_scroll_bar().value_changed.connect(_horizontal_scroll_callable) as Error
	var _layout_connected: Error = _layout_model.layout_changed.connect(_layout_changed_callable) as Error
	if _focus_model != null:
		var _focus_connected: Error = _focus_model.focused_index_changed.connect(_focus_changed_callable) as Error
	if viewport != null:
		var _viewport_connected: Error = viewport.gui_focus_changed.connect(_viewport_focus_changed_callable) as Error


func _disconnect_binding_signals() -> void:
	for node_ref: WeakRef in _binding_tree_exit_refs:
		var value: Variant = node_ref.get_ref()
		if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
			continue
		if value is Node:
			var lifecycle_node: Node = value
			if (
				_binding_tree_exited_callable.is_valid()
				and lifecycle_node.tree_exited.is_connected(_binding_tree_exited_callable)
			):
				lifecycle_node.tree_exited.disconnect(_binding_tree_exited_callable)
	_binding_tree_exit_refs.clear()
	var scroll_container: ScrollContainer = _get_scroll_container()
	if scroll_container != null:
		if _scroll_resized_callable.is_valid() and scroll_container.resized.is_connected(_scroll_resized_callable):
			scroll_container.resized.disconnect(_scroll_resized_callable)
		var vertical_bar: VScrollBar = scroll_container.get_v_scroll_bar()
		if _vertical_scroll_callable.is_valid() and vertical_bar.value_changed.is_connected(_vertical_scroll_callable):
			vertical_bar.value_changed.disconnect(_vertical_scroll_callable)
		var horizontal_bar: HScrollBar = scroll_container.get_h_scroll_bar()
		if _horizontal_scroll_callable.is_valid() and horizontal_bar.value_changed.is_connected(_horizontal_scroll_callable):
			horizontal_bar.value_changed.disconnect(_horizontal_scroll_callable)
	var content_root: Control = _get_content_root()
	if content_root != null and _content_resized_callable.is_valid() and content_root.resized.is_connected(_content_resized_callable):
		content_root.resized.disconnect(_content_resized_callable)
	if _layout_model != null and _layout_changed_callable.is_valid() and _layout_model.layout_changed.is_connected(_layout_changed_callable):
		_layout_model.layout_changed.disconnect(_layout_changed_callable)
	if _focus_model != null and _focus_changed_callable.is_valid() and _focus_model.focused_index_changed.is_connected(_focus_changed_callable):
		_focus_model.focused_index_changed.disconnect(_focus_changed_callable)
	var viewport: Viewport = _get_viewport()
	if viewport != null and _viewport_focus_changed_callable.is_valid() and viewport.gui_focus_changed.is_connected(_viewport_focus_changed_callable):
		viewport.gui_focus_changed.disconnect(_viewport_focus_changed_callable)


func _finish_unbind() -> void:
	if _teardown_in_progress:
		return
	_teardown_in_progress = true
	_state = _STATE_UNBINDING
	_disconnect_binding_signals()
	_release_all_controls()
	_restore_content_minimum_size()
	_clear_binding_references()
	var escalated_to_dispose: bool = _dispose_requested
	_unbind_requested = false
	_dispose_requested = false
	_state = _STATE_DISPOSED if escalated_to_dispose else _STATE_UNBOUND
	var terminal_status: StringName = (
		GFVirtualListSyncResult.STATUS_DISPOSED
		if escalated_to_dispose
		else GFVirtualListSyncResult.STATUS_UNBOUND
	)
	var _stored_unbind_result: GFVirtualListSyncResult = _store_result(_make_terminal_result(terminal_status))
	_teardown_in_progress = false


func _finish_dispose() -> void:
	if _teardown_in_progress:
		return
	_teardown_in_progress = true
	_state = _STATE_DISPOSING
	_disconnect_binding_signals()
	_release_all_controls()
	_restore_content_minimum_size()
	_clear_binding_references()
	_unbind_requested = false
	_dispose_requested = false
	_state = _STATE_DISPOSED
	var _stored_disposed_result: GFVirtualListSyncResult = _store_result(
		_make_terminal_result(GFVirtualListSyncResult.STATUS_DISPOSED)
	)
	_teardown_in_progress = false


func _release_all_controls() -> void:
	for item_index: int in _get_active_indices():
		var record: Dictionary = _get_record_for_index(item_index)
		if GFVariantData.get_option_bool(record, "bound"):
			var _released_teardown_focus: bool = _release_control_focus_if_owned(record)
			_invoke_unbind(record)
			record["bound"] = false
		var control: Control = _get_record_control(record)
		if control != null:
			_queue_free_owned_control(control)
	_active_by_token.clear()
	_token_by_index.clear()
	for control_value: Variant in _pool:
		var control: Control = _get_live_control(control_value)
		if control != null:
			_queue_free_owned_control(control)
	_pool.clear()
	_known_control_ids.clear()


func _restore_content_minimum_size() -> void:
	var content_root: Control = _get_content_root()
	if content_root != null:
		var minimum_size: Vector2 = content_root.custom_minimum_size
		if _owned_layout_axis == LayoutAxis.HORIZONTAL:
			minimum_size.x = _owned_layout_axis_baseline
		elif _owned_layout_axis == LayoutAxis.VERTICAL:
			minimum_size.y = _owned_layout_axis_baseline
		content_root.custom_minimum_size = minimum_size
	_owned_layout_axis = -1
	_owned_layout_axis_baseline = 0.0


func _clear_binding_references() -> void:
	_pending_sync = false
	_deferred_sync_scheduled = false
	_measurement_requested = false
	_measurement_request_revision = 0
	_pool_trim_requested = false
	_binding_focus_initialization = false
	_clear_sync_context()
	_clear_pending_focus_handoff()
	_clear_pending_focus_reveal()
	_pending_physical_focus_reconciliation = false
	_focus_intent_revision = 0
	_focus_handoff_in_progress = false
	_focus_handoff_index = GFVirtualListFocusModel.NO_FOCUS
	_focus_handoff_observed_target = false
	_owner_ref = null
	_scroll_ref = null
	_content_ref = null
	_viewport_ref = null
	_layout_model = null
	_focus_model = null
	_item_factory = Callable()
	_bind_callback = Callable()
	_unbind_callback = Callable()
	_identity_callback = Callable()
	_measure_callback = Callable()
	_focus_target_callback = Callable()


func _schedule_deferred_sync() -> void:
	if _deferred_sync_scheduled or _state == _STATE_SYNCING:
		return
	_deferred_sync_scheduled = true
	var _deferred_result: Variant = call_deferred("_run_deferred_sync", _lifecycle_generation)


func _run_deferred_sync(generation: int) -> void:
	_deferred_sync_scheduled = false
	if generation != _lifecycle_generation or not _pending_sync or not is_bound():
		return
	var _result: GFVirtualListSyncResult = sync_now()


func _make_sync_result(
	status: StringName,
	viewport_range: Vector2i,
	requested_range: Vector2i,
	metrics: Dictionary = {},
	layout_revision: int = -1,
	data_revision: int = -1
) -> GFVirtualListSyncResult:
	var result: GFVirtualListSyncResult = GFVirtualListSyncResult.new()
	var resolved_layout_revision: int = layout_revision
	if resolved_layout_revision < 0:
		resolved_layout_revision = _layout_model.get_revision() if _layout_model != null else 0
	var resolved_data_revision: int = data_revision if data_revision >= 0 else _data_revision
	var _configured: bool = result.configure_for_framework({
		"status": status,
		"layout_revision": resolved_layout_revision,
		"data_revision": resolved_data_revision,
		"viewport_range": viewport_range,
		"requested_range": requested_range,
		"materialized_indices": PackedInt32Array(_get_active_indices()),
		"pooled_count": _pool.size(),
		"created_count": GFVariantData.get_option_int(metrics, "created_count"),
		"reused_count": GFVariantData.get_option_int(metrics, "reused_count"),
		"released_count": GFVariantData.get_option_int(metrics, "released_count"),
		"measured_count": GFVariantData.get_option_int(metrics, "measured_count"),
		"anchor_adjustment": GFVariantData.get_option_float(metrics, "anchor_adjustment"),
		"truncated": GFVariantData.get_option_bool(metrics, "truncated"),
		"error_index": GFVariantData.get_option_int(metrics, "error_index", -1),
		"error": GFVariantData.get_option_string(metrics, "error"),
	})
	return result


func _make_terminal_result(status: StringName) -> GFVirtualListSyncResult:
	return _make_sync_result(status, Vector2i.ZERO, Vector2i.ZERO)


func _make_deferred_sync_result(
	viewport_range: Vector2i,
	requested_range: Vector2i,
	layout_revision: int,
	data_revision: int,
	metrics: Dictionary = {}
) -> GFVirtualListSyncResult:
	if is_bound() and _state not in [_STATE_UNBINDING, _STATE_DISPOSING]:
		var _requested_deferred_round: bool = request_sync()
	var result_metrics: Dictionary = metrics.duplicate()
	result_metrics["truncated"] = _sync_truncated
	return _make_sync_result(
		GFVirtualListSyncResult.STATUS_DEFERRED,
		viewport_range,
		requested_range,
		result_metrics,
		layout_revision,
		data_revision
	)


func _copy_result_with_current_pool_count(
	source: GFVirtualListSyncResult
) -> GFVirtualListSyncResult:
	if source == null:
		return _make_terminal_result(_get_interrupted_status())
	var snapshot: Dictionary = source.to_dict()
	snapshot["pooled_count"] = _pool.size()
	var result: GFVirtualListSyncResult = GFVirtualListSyncResult.new()
	var _configured: bool = result.configure_for_framework(snapshot)
	return result


func _get_interrupted_status() -> StringName:
	if _state in [_STATE_UNBOUND, _STATE_UNBINDING]:
		return GFVirtualListSyncResult.STATUS_UNBOUND
	return GFVirtualListSyncResult.STATUS_DISPOSED


func _store_result(result: GFVirtualListSyncResult) -> GFVirtualListSyncResult:
	_last_sync_result = result.duplicate_result()
	return result


func _sync_metrics_are_unchanged(
	metrics: Dictionary,
	data_revision_changed: bool,
	layout_revision_changed: bool
) -> bool:
	return (
		GFVariantData.get_option_int(metrics, "created_count") == 0
		and GFVariantData.get_option_int(metrics, "released_count") == 0
		and GFVariantData.get_option_int(metrics, "measured_count") == 0
		and is_zero_approx(GFVariantData.get_option_float(metrics, "anchor_adjustment"))
		and not data_revision_changed
		and not layout_revision_changed
	)


func _get_active_indices() -> Array[int]:
	var indices: Array[int] = []
	for index_value: Variant in _token_by_index.keys():
		if index_value is int:
			var item_index: int = index_value
			indices.append(item_index)
	indices.sort()
	return indices


func _get_active_record(token: String) -> Dictionary:
	var value: Variant = _active_by_token.get(token)
	if value is Dictionary:
		var record: Dictionary = value
		return record
	return {}


func _get_record_for_index(item_index: int) -> Dictionary:
	var token_value: Variant = _token_by_index.get(item_index)
	if token_value is String:
		var token: String = token_value
		return _get_active_record(token)
	return {}


func _get_record_control(record: Dictionary) -> Control:
	return _get_control_value(record, "control")


func _get_control_value(data: Dictionary, key: String) -> Control:
	var value: Variant = GFVariantData.get_option_value(data, key)
	return _get_live_control(value)


func _get_live_control(value: Variant) -> Control:
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return null
	if value is Control:
		var control: Control = value
		if not control.is_queued_for_deletion():
			return control
	return null


func _get_descriptor_array(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in GFVariantData.get_option_array(data, "descriptors"):
		if value is Dictionary:
			var descriptor: Dictionary = value
			result.append(descriptor)
	return result


func _get_record_array(data: Dictionary, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in GFVariantData.get_option_array(data, key):
		if value is Dictionary:
			var record: Dictionary = value
			result.append(record)
	return result


func _get_packed_indices(data: Dictionary, key: String) -> PackedInt32Array:
	var value: Variant = GFVariantData.get_option_value(data, key, PackedInt32Array())
	if value is PackedInt32Array:
		var indices: PackedInt32Array = value
		return indices
	return PackedInt32Array()


func _get_effective_layout_axis() -> int:
	if _sync_in_progress and _sync_layout_axis in [LayoutAxis.VERTICAL, LayoutAxis.HORIZONTAL]:
		return _sync_layout_axis
	return int(layout_axis)


func _get_effective_fill_cross_axis() -> bool:
	if _sync_in_progress:
		return _sync_fill_cross_axis
	return fill_cross_axis


func _sync_layout_model_is_current() -> bool:
	return (
		_sync_context_ready
		and _sync_layout_model != null
		and is_same(_layout_model, _sync_layout_model)
		and _sync_layout_model.get_revision() == _sync_expected_layout_revision
	)


func _sync_data_revision_is_current(sync_data_revision: int) -> bool:
	return _sync_in_progress and _data_revision == sync_data_revision


func _get_sync_item_geometry(item_index: int) -> Dictionary:
	var value: Variant = _sync_item_geometries.get(item_index)
	if value is Dictionary:
		var geometry: Dictionary = value
		return geometry.duplicate()
	return {}


func _snapshot_sync_item_geometries(
	layout_model: GFVirtualListModel,
	target_indices: PackedInt32Array
) -> void:
	_sync_item_geometries.clear()
	for item_index: int in target_indices:
		_sync_item_geometries[item_index] = {
			"offset": layout_model.get_item_offset(item_index),
			"extent": layout_model.get_item_extent(item_index),
		}


func _apply_sync_measurement_report(item_index: int, report: Dictionary) -> void:
	var geometry: Dictionary = _get_sync_item_geometry(item_index)
	var previous_extent: float = GFVariantData.get_option_float(geometry, "extent")
	if previous_extent <= 0.0:
		dispose()
		return
	var delta: float = GFVariantData.get_option_float(report, "delta")
	geometry["extent"] = GFVariantData.get_option_float(report, "extent", previous_extent)
	_sync_item_geometries[item_index] = geometry
	if not is_zero_approx(delta):
		for key: Variant in _sync_item_geometries.keys():
			if key is int:
				var geometry_index: int = key
				if geometry_index > item_index:
					var shifted_geometry: Dictionary = _get_sync_item_geometry(geometry_index)
					shifted_geometry["offset"] = (
						GFVariantData.get_option_float(shifted_geometry, "offset")
						+ delta
					)
					_sync_item_geometries[geometry_index] = shifted_geometry
		_sync_content_extent = maxf(_sync_content_extent + delta, 0.0)


func _clear_sync_context() -> void:
	_sync_layout_axis = -1
	_sync_fill_cross_axis = false
	_sync_max_materialized_items = DEFAULT_MAX_MATERIALIZED_ITEMS
	_sync_auto_measure = true
	_sync_measurement_requested = false
	_sync_measurement_request_revision = 0
	_sync_truncated = false
	_sync_layout_model = null
	_sync_expected_layout_revision = -1
	_sync_content_extent = 0.0
	_sync_item_geometries.clear()
	_sync_context_ready = false


func _get_scroll_offset(scroll_container: ScrollContainer) -> float:
	return _get_scroll_offset_for_axis(scroll_container, _get_effective_layout_axis())


func _get_scroll_offset_for_axis(scroll_container: ScrollContainer, axis: int) -> float:
	if axis == LayoutAxis.HORIZONTAL:
		return float(scroll_container.scroll_horizontal)
	return float(scroll_container.scroll_vertical)


func _set_scroll_offset(scroll_container: ScrollContainer, value: float) -> void:
	_set_scroll_offset_for_axis(scroll_container, value, _get_effective_layout_axis())


func _set_scroll_offset_for_axis(
	scroll_container: ScrollContainer,
	value: float,
	axis: int
) -> void:
	var safe_value: int = int(_quantize_scroll_offset(value))
	if axis == LayoutAxis.HORIZONTAL:
		scroll_container.scroll_horizontal = safe_value
	else:
		scroll_container.scroll_vertical = safe_value


func _quantize_scroll_offset(value: float) -> float:
	return float(maxi(roundi(value), 0))


func _get_viewport_extent(scroll_container: ScrollContainer) -> float:
	return _get_viewport_extent_for_axis(scroll_container, _get_effective_layout_axis())


func _get_viewport_extent_for_axis(scroll_container: ScrollContainer, axis: int) -> float:
	var container_extent: float = (
		scroll_container.size.x
		if axis == LayoutAxis.HORIZONTAL
		else scroll_container.size.y
	)
	var scroll_page: float = (
		scroll_container.get_h_scroll_bar().page
		if axis == LayoutAxis.HORIZONTAL
		else scroll_container.get_v_scroll_bar().page
	)
	if is_finite(scroll_page) and scroll_page > 0.0:
		return minf(scroll_page, maxf(container_extent, 0.0))
	return maxf(container_extent, 0.0)


func _is_valid_binding_boundary(
	owner: Node,
	scroll_container: ScrollContainer,
	content_root: Control,
	layout_model: GFVirtualListModel
) -> bool:
	return (
		owner != null
		and is_instance_valid(owner)
		and owner.is_inside_tree()
		and scroll_container != null
		and is_instance_valid(scroll_container)
		and scroll_container.is_inside_tree()
		and content_root != null
		and is_instance_valid(content_root)
		and content_root.get_parent() == scroll_container
		and not (content_root is Container)
		and layout_model != null
	)


func _binding_objects_are_live() -> bool:
	var owner: Node = _get_owner_node()
	var scroll_container: ScrollContainer = _get_scroll_container()
	var content_root: Control = _get_content_root()
	return (
		owner != null
		and owner.is_inside_tree()
		and scroll_container != null
		and scroll_container.is_inside_tree()
		and content_root != null
		and content_root.is_inside_tree()
		and content_root.get_parent() == scroll_container
	)


func _owned_controls_are_live(additional_parentless_records: Array[Dictionary] = []) -> bool:
	var content_root: Control = _get_content_root()
	if content_root == null:
		return false
	var observed_control_ids: Dictionary = {}
	if _token_by_index.size() != _active_by_token.size():
		return false
	for token_value: Variant in _active_by_token.keys():
		if not (token_value is String):
			return false
		var token: String = token_value
		var record_value: Variant = _active_by_token.get(token)
		if not (record_value is Dictionary):
			return false
		var record: Dictionary = record_value
		var item_index: int = GFVariantData.get_option_int(record, "index", -1)
		if (
			item_index < 0
			or GFVariantData.get_option_string(record, "token") != token
			or not GFVariantData.get_option_bool(record, "bound")
			or _token_by_index.get(item_index) != token
		):
			return false
		var control: Control = _get_record_control(record)
		if not _register_owned_control(control, content_root, observed_control_ids):
			return false
	for index_value: Variant in _token_by_index.keys():
		if not (index_value is int):
			return false
		var item_index: int = index_value
		var token_value: Variant = _token_by_index.get(item_index)
		if not (token_value is String):
			return false
		var token: String = token_value
		var record_value: Variant = _active_by_token.get(token)
		if not (record_value is Dictionary):
			return false
		var record: Dictionary = record_value
		if GFVariantData.get_option_int(record, "index", -1) != item_index:
			return false
	for control_value: Variant in _pool:
		var control: Control = _get_live_control(control_value)
		if not _register_owned_control(control, null, observed_control_ids):
			return false
	for record: Dictionary in additional_parentless_records:
		var control: Control = _get_record_control(record)
		if not _register_owned_control(control, null, observed_control_ids):
			return false
	if observed_control_ids.size() != _known_control_ids.size():
		return false
	for control_id_value: Variant in _known_control_ids.keys():
		if not (control_id_value is int) or not observed_control_ids.has(control_id_value):
			return false
	return true


func _transaction_owned_controls_are_live(planned_records: Array[Dictionary]) -> bool:
	var content_root: Control = _get_content_root()
	if content_root == null or _token_by_index.size() != _active_by_token.size():
		return false
	var controls_by_id: Dictionary = {}
	var active_control_ids: Dictionary = {}
	for token_value: Variant in _active_by_token.keys():
		if not (token_value is String):
			return false
		var token: String = token_value
		var record_value: Variant = _active_by_token.get(token)
		if not (record_value is Dictionary):
			return false
		var record: Dictionary = record_value
		var item_index: int = GFVariantData.get_option_int(record, "index", -1)
		if (
			item_index < 0
			or GFVariantData.get_option_string(record, "token") != token
			or _token_by_index.get(item_index) != token
		):
			return false
		var control: Control = _get_record_control(record)
		if not _register_transaction_control(control, controls_by_id):
			return false
		active_control_ids[control.get_instance_id()] = true
	for index_value: Variant in _token_by_index.keys():
		if not (index_value is int):
			return false
		var item_index: int = index_value
		var token_value: Variant = _token_by_index.get(item_index)
		if not (token_value is String):
			return false
		var record_value: Variant = _active_by_token.get(token_value)
		if not (record_value is Dictionary):
			return false
		var record: Dictionary = record_value
		if GFVariantData.get_option_int(record, "index", -1) != item_index:
			return false

	var expected_parents: Dictionary = {}
	var planned_control_ids: Dictionary = {}
	for record: Dictionary in planned_records:
		var control: Control = _get_record_control(record)
		if not _register_transaction_control(control, controls_by_id):
			return false
		var control_id: int = control.get_instance_id()
		if planned_control_ids.has(control_id):
			return false
		planned_control_ids[control_id] = true
		expected_parents[control_id] = (
			content_root
			if GFVariantData.get_option_bool(record, "attached_to_content")
			else null
		)

	var pooled_control_ids: Dictionary = {}
	for control_value: Variant in _pool:
		var control: Control = _get_live_control(control_value)
		if not _register_transaction_control(control, controls_by_id):
			return false
		var control_id: int = control.get_instance_id()
		if pooled_control_ids.has(control_id):
			return false
		pooled_control_ids[control_id] = true
		if expected_parents.has(control_id) and expected_parents.get(control_id) != null:
			return false
		expected_parents[control_id] = null

	for control_id_value: Variant in active_control_ids.keys():
		if not expected_parents.has(control_id_value):
			expected_parents[control_id_value] = content_root
	if controls_by_id.size() != _known_control_ids.size():
		return false
	for control_id_value: Variant in _known_control_ids.keys():
		if not (control_id_value is int) or not controls_by_id.has(control_id_value):
			return false
	for control_id_value: Variant in controls_by_id.keys():
		if not expected_parents.has(control_id_value):
			return false
		var control_value: Variant = controls_by_id.get(control_id_value)
		if not (control_value is Control):
			return false
		var control: Control = control_value
		var expected_value: Variant = expected_parents.get(control_id_value)
		var expected_parent: Node = expected_value if expected_value is Node else null
		if not _control_has_expected_parent(control, expected_parent):
			return false
	return true


func _register_transaction_control(control: Control, controls_by_id: Dictionary) -> bool:
	if control == null or not is_instance_valid(control) or control.is_queued_for_deletion():
		return false
	var control_id: int = control.get_instance_id()
	if not _known_control_ids.has(control_id):
		return false
	if controls_by_id.has(control_id):
		return is_same(controls_by_id.get(control_id), control)
	controls_by_id[control_id] = control
	return true


func _pool_controls_are_live() -> bool:
	var observed_control_ids: Dictionary = {}
	for control_value: Variant in _pool:
		var control: Control = _get_live_control(control_value)
		if not _register_owned_control(control, null, observed_control_ids):
			return false
	return true


func _register_owned_control(
	control: Control,
	expected_parent: Node,
	observed_control_ids: Dictionary
) -> bool:
	if not _control_has_expected_parent(control, expected_parent):
		return false
	var control_id: int = control.get_instance_id()
	if observed_control_ids.has(control_id) or not _known_control_ids.has(control_id):
		return false
	observed_control_ids[control_id] = true
	return true


func _control_has_expected_parent(control: Control, expected_parent: Node) -> bool:
	return (
		control != null
		and is_instance_valid(control)
		and not control.is_queued_for_deletion()
		and control.get_parent() == expected_parent
	)


func _get_owner_node() -> Node:
	return _get_live_node(_owner_ref)


func _get_scroll_container() -> ScrollContainer:
	var node: Node = _get_live_node(_scroll_ref)
	if node is ScrollContainer:
		var scroll_container: ScrollContainer = node
		return scroll_container
	return null


func _get_content_root() -> Control:
	var node: Node = _get_live_node(_content_ref)
	if node is Control:
		var control: Control = node
		return control
	return null


func _get_viewport() -> Viewport:
	if _viewport_ref == null:
		return null
	var value: Variant = _viewport_ref.get_ref()
	if value is Viewport:
		var viewport: Viewport = value
		if is_instance_valid(viewport):
			return viewport
	return null


func _get_live_node(node_ref: WeakRef) -> Node:
	if node_ref == null:
		return null
	var value: Variant = node_ref.get_ref()
	if value is Node:
		var node: Node = value
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			return node
	return null


func _node_is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current: Node = node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _is_sync_in_progress() -> bool:
	return _sync_in_progress


func _queue_measurement_request() -> void:
	_measurement_requested = true
	_measurement_request_revision += 1


# --- 信号处理函数 ---

func _on_binding_tree_exited() -> void:
	dispose()


func _on_scroll_resized() -> void:
	var _requested: bool = request_sync()


func _on_content_resized() -> void:
	if _get_effective_fill_cross_axis():
		var _requested: bool = request_sync()


func _on_scroll_value_changed(_value: float) -> void:
	if _applying_scroll_adjustment:
		return
	var _requested: bool = request_sync()


func _on_layout_changed(_revision: int) -> void:
	var _requested: bool = request_sync()


func _on_focus_changed(previous_index: int, focused_index: int) -> void:
	if _binding_focus_initialization:
		return
	_focus_intent_revision += 1
	if _sync_in_progress:
		_pending_physical_focus_reconciliation = (
			_pending_physical_focus_reconciliation
			or previous_index != GFVirtualListFocusModel.NO_FOCUS
		)
		if focused_index == GFVirtualListFocusModel.NO_FOCUS:
			_clear_pending_focus_handoff()
			_clear_pending_focus_reveal()
		else:
			_arm_pending_focus_handoff(focused_index)
			_arm_pending_focus_reveal(focused_index)
		var _requested_next_focus_round: bool = request_sync()
		return
	var generation: int = _lifecycle_generation
	var focus_model: GFVirtualListFocusModel = _focus_model
	var project_focus_replaced_release: bool = false
	if previous_index != GFVirtualListFocusModel.NO_FOCUS:
		project_focus_replaced_release = _release_control_focus_if_owned(
			_get_record_for_index(previous_index)
		)
	if (
		generation != _lifecycle_generation
		or not is_bound()
		or not is_same(_focus_model, focus_model)
		or _focus_model == null
		or _focus_model.focused_index != focused_index
	):
		return
	if not _owned_controls_are_live():
		dispose()
		return
	var viewport: Viewport = _get_viewport()
	var physical_focus_owner: Control = viewport.gui_get_focus_owner() if viewport != null else null
	if project_focus_replaced_release or physical_focus_owner != null:
		_clear_pending_focus_handoff()
		_arm_pending_focus_reveal(focused_index)
		if _pending_focus_reveal_index != GFVirtualListFocusModel.NO_FOCUS:
			var _revealed_after_project_focus: bool = _scroll_to_item_internal(
				focused_index,
				ScrollAlignment.NEAREST
			)
		var _requested_after_project_focus: bool = request_sync()
		return
	_arm_pending_focus_handoff(focused_index)
	_arm_pending_focus_reveal(focused_index)
	if _pending_focus_reveal_index != GFVirtualListFocusModel.NO_FOCUS:
		var _revealed: bool = _scroll_to_item_internal(focused_index, ScrollAlignment.NEAREST)
	var _requested: bool = request_sync()


func _on_viewport_focus_changed(control: Control) -> void:
	if _focus_handoff_in_progress:
		if control == null:
			return
		var handoff_record: Dictionary = _get_record_for_index(_focus_handoff_index)
		var handoff_control: Control = _get_record_control(handoff_record)
		if (
			handoff_control != null
			and (control == handoff_control or _node_is_descendant_of(control, handoff_control))
		):
			_focus_handoff_observed_target = true
			return
	if not _pending_focus_handoff:
		return
	if control == null:
		_clear_pending_focus_handoff()
		return
	var pending_record: Dictionary = _get_record_for_index(_pending_focus_index)
	var pending_control: Control = _get_record_control(pending_record)
	if (
		pending_control != null
		and (control == pending_control or _node_is_descendant_of(control, pending_control))
	):
		return
	_clear_pending_focus_handoff()
