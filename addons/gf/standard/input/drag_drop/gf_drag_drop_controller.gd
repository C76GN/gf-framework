## GFDragDropController: 可选拖放 Node 控制器。
##
## 在 `GFDragDropUtility` 的纯数据会话与落点规则之上，补充单指针捕获、source 生命周期、
## 可选拖拽层 reparent、取消和落点剪枝。它不解释 payload，不规定背包、棋盘、
## 卡牌或编辑器工具的业务语义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFDragDropController
extends Node


# --- 信号 ---

## 控制器已提交 session、pointer、source 监听和可选 reparent 后同步发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param session_id: 会话 ID。
## [br]
## @param drag_type: 拖拽类型。
signal drag_started(session_id: int, drag_type: StringName)

## 拖拽位置更新时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param session_id: 会话 ID。
## [br]
## @param position: 当前位置。
## [br]
## @param delta: 本次位移。
## [br]
## @param zone_id: 当前最佳落点 ID；没有落点时为空。
signal drag_moved(session_id: int, position: Vector2, delta: Vector2, zone_id: StringName)

## 旧会话的 pointer/source/reparent lease 已清理后同步发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param session_id: 会话 ID。
## [br]
## @param zone_id: 落点 ID。
## [br]
## @param result: 落点返回结果。
## [br]
## @schema result: Dictionary，由 GFDragDropUtility.drop() 规范化，包含 ok、session_id、zone_id、reason 和可选 value。
signal drag_dropped(session_id: int, zone_id: StringName, result: Dictionary)

## 拖拽释放被拒绝时发出；终态拒绝会先清理旧 lease，可重试拒绝仍保留会话。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param session_id: 会话 ID。
## [br]
## @param reason: 拒绝原因。
signal drag_drop_rejected(session_id: int, reason: StringName)

## 旧会话的 pointer/source/reparent lease 已清理后同步发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param session_id: 会话 ID。
## [br]
## @param reason: 取消原因。
signal drag_cancelled(session_id: int, reason: StringName)

## 落点注册后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param zone_id: 落点 ID。
signal drop_zone_registered(zone_id: StringName)

## 落点注销后发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param zone_id: 落点 ID。
signal drop_zone_unregistered(zone_id: StringName)


# --- 常量 ---

## 无捕获指针时使用的哨兵 ID。
## [br]
## @api private
## [br]
const _NO_POINTER_ID: int = -1


# --- 导出变量 ---

## source 离开场景树时是否自动取消当前拖拽。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var cancel_when_source_exits_tree: bool = true

## source 引用失效时是否自动取消当前拖拽。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var cancel_when_source_freed: bool = true


# --- 私有变量 ---

## 控制器持有的 GFDragDropUtility，提供拖拽会话与落点操作。
## [br]
## @api private
## [br]
var _utility: GFDragDropUtility = GFDragDropUtility.new()

## 当前控制器捕获的 pointer ID；无捕获时为哨兵值。
## [br]
## @api private
## [br]
var _active_pointer_id: int = _NO_POINTER_ID

## 记录当前拖拽是否由控制器取得指针捕获。
## [br]
## @api private
## [br]
var _captures_pointer: bool = false

## 当前由控制器管理的拖拽会话 ID；无会话时为 -1。
## [br]
## @api private
## [br]
var _active_session_id: int = -1

## 当前拖拽来源节点的弱引用，避免控制器延长其生命周期。
## [br]
## @api private
## [br]
var _source_ref: WeakRef = null

## 拖拽开始前来源节点父节点的弱引用。
## [br]
## @api private
## [br]
var _original_parent_ref: WeakRef = null

## 来源节点拖拽前在原父节点中的子项索引。
## [br]
## @api private
## [br]
var _original_index: int = -1

## 当前会话取消结束时是否把来源节点还原到原父节点。
## [br]
## @api private
## [br]
var _restore_source_parent_on_cancel: bool = true

## 当前会话被拒绝结束时是否还原来源节点父节点。
## [br]
## @api private
## [br]
var _restore_source_parent_on_rejected_drop: bool = true

## 当前会话成功结束时是否还原来源节点父节点。
## [br]
## @api private
## [br]
var _restore_source_parent_on_success: bool = false

## 重挂来源节点时是否保持其全局变换。
## [br]
## @api private
## [br]
var _reparent_keep_global_transform: bool = true

## 控制器发起取消时暂存并传给终态信号的原因。
## [br]
## @api private
## [br]
var _pending_cancel_reason: StringName = &""

## 当前来源节点 tree_exited 信号的一次性回调句柄。
## [br]
## @api private
## [br]
var _source_tree_exited_callable: Callable = Callable()

## 标记控制器是否正同步启动 utility 会话，用于抑制启动期间的重入转发。
## [br]
## @api private
## [br]
var _start_in_progress: bool = false

## 启动期间由 utility 发出的会话 ID，供启动事务完成后识别。
## [br]
## @api private
## [br]
var _starting_session_id: int = -1

## 防止同一活动会话被重复或重入收尾。
## [br]
## @api private
## [br]
var _finish_in_progress: bool = false


# --- Godot 生命周期方法 ---

func _init() -> void:
	_connect_utility_signals()


func _ready() -> void:
	set_process(has_active_drag())


func _process(_delta: float) -> void:
	var _source_valid: bool = _cancel_active_drag_if_source_invalid()


func _exit_tree() -> void:
	var _cancelled_drag: bool = cancel_drag(&"controller_exited_tree")


# --- 公共方法 ---

## 获取底层拖放数据工具。
## 返回值是可写 live Utility；直接调用其 update/drop/cancel 会绕过控制器的
## pointer 校验，但底层终态信号仍会驱动控制器清理。需要强制 pointer authority
## 时只使用控制器命令入口。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前控制器持有的拖放工具。
func get_utility() -> GFDragDropUtility:
	return _utility


## 注册落点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param zone: 落点规则。
## [br]
## @return 注册成功返回 true。
func register_zone(zone: GFDropZone) -> bool:
	return _utility.register_zone(zone)


## 注册矩形落点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param zone_id: 落点 ID。
## [br]
## @param rect: 全局矩形区域。
## [br]
## @param accepted_types: 可接收类型；为空表示不限制。
## [br]
## @param options: 可选参数，支持 priority、enabled、metadata、can_accept、drop。
## [br]
## @return 注册成功时返回落点，否则返回 null。
## [br]
## @schema options: Dictionary，透传给 GFDropZone.from_rect()。
func register_rect_zone(
	zone_id: StringName,
	rect: Rect2,
	accepted_types: PackedStringArray = PackedStringArray(),
	options: Dictionary = {}
) -> GFDropZone:
	return _utility.register_rect_zone(zone_id, rect, accepted_types, options)


## 注册 Control 全局矩形落点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param zone_id: 落点 ID。
## [br]
## @param control: 用于读取 get_global_rect() 的 Control。
## [br]
## @param accepted_types: 可接收类型；为空表示不限制。
## [br]
## @param options: 可选参数，支持 priority、enabled、metadata、can_accept、drop。
## [br]
## @return 注册成功时返回落点，否则返回 null。
## [br]
## @schema options: Dictionary，透传给 GFDropZone.from_control()。
func register_control_zone(
	zone_id: StringName,
	control: Control,
	accepted_types: PackedStringArray = PackedStringArray(),
	options: Dictionary = {}
) -> GFDropZone:
	return _utility.register_control_zone(zone_id, control, accepted_types, options)


## 注销落点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param zone_id: 落点 ID。
## [br]
## @return 找到并移除时返回 true。
func unregister_zone(zone_id: StringName) -> bool:
	return _utility.unregister_zone(zone_id)


## 主动剪枝已失效的落点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 本次移除的落点数量。
func prune_stale_drop_zones() -> int:
	return _utility.prune_stale_zones()


## 清空落点。
## [br]
## @api public
## [br]
## @since 8.0.0
func clear_zones() -> void:
	_utility.clear_zones()


## 开始由控制器管理的拖拽。
## [br]
## 控制器一次只管理一个活动会话。需要并行拖拽时可创建多个控制器；底层
## `GFDragDropUtility` 仍保留多会话能力。
## started 只观察完整提交状态；若 started 监听器同步结束本会话，本方法返回 -1。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param drag_type: 拖拽类型。
## [br]
## @param payload: 项目自定义载荷。
## [br]
## @param position: 起始位置。
## [br]
## @param source: 可选来源对象。
## [br]
## @param options: 控制器选项。
## [br]
## @return: 仍保持活动的会话 ID；启动失败或 started 回调已结束会话时返回 -1。
## [br]
## @schema payload: Variant，透传给 drop zone 的项目侧拖拽载荷。
## [br]
## @schema options: Dictionary，可包含 metadata: Dictionary、pointer_id: int、capture_pointer: bool、drag_parent: Node、keep_global_transform: bool、restore_source_parent_on_cancel: bool、restore_source_parent_on_rejected_drop: bool、restore_source_parent_on_success: bool。
func start_drag(
	drag_type: StringName,
	payload: Variant,
	position: Vector2,
	source: Object = null,
	options: Dictionary = {}
) -> int:
	if _start_in_progress or _finish_in_progress or has_active_drag() or drag_type == &"":
		return -1

	var source_node: Node = _node_from_object(source)
	if not _validate_drag_visual_transaction(source_node, options):
		return -1

	var pointer_id: int = GFVariantData.get_option_int(options, "pointer_id", 0)
	var capture_pointer: bool = GFVariantData.get_option_bool(options, "capture_pointer", true)
	if capture_pointer and pointer_id == _NO_POINTER_ID:
		return -1
	_start_in_progress = true
	_starting_session_id = -1
	_captures_pointer = capture_pointer
	_active_pointer_id = pointer_id if capture_pointer else _NO_POINTER_ID

	_restore_source_parent_on_cancel = GFVariantData.get_option_bool(options, "restore_source_parent_on_cancel", true)
	_restore_source_parent_on_rejected_drop = GFVariantData.get_option_bool(options, "restore_source_parent_on_rejected_drop", true)
	_restore_source_parent_on_success = GFVariantData.get_option_bool(options, "restore_source_parent_on_success", false)
	_reparent_keep_global_transform = GFVariantData.get_option_bool(options, "keep_global_transform", true)

	_source_ref = weakref(source) if is_instance_valid(source) else null
	if source_node != null:
		_capture_original_parent(source_node)
		var drag_parent: Node = _get_requested_drag_parent(options)
		if not _commit_drag_visual_transaction(source_node, drag_parent):
			_rollback_start_transaction()
			_start_in_progress = false
			return -1

	var metadata: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(options, "metadata", {})
	)
	var session_id: int = _utility.start_drag(drag_type, payload, position, source, metadata)
	_starting_session_id = -1
	if session_id < 0 or not _utility.has_active_session(session_id):
		_rollback_start_transaction()
		_start_in_progress = false
		return -1

	_active_session_id = session_id
	_start_in_progress = false
	_connect_active_source_tree_exit(source_node, session_id)
	set_process(true)
	drag_started.emit(session_id, drag_type)
	if _active_session_id != session_id or not _utility.has_active_session(session_id):
		return -1
	return session_id


## 更新活动拖拽的指针位置。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param position: 当前指针位置。
## [br]
## @param pointer_id: 发起更新的指针 ID。
## [br]
## @return 更新成功返回 true。
func update_pointer(position: Vector2, pointer_id: int = 0) -> bool:
	if not has_active_drag():
		return false
	if _captures_pointer and pointer_id != _active_pointer_id:
		return false
	if _cancel_active_drag_if_source_invalid():
		return false
	return _utility.update_drag(_active_session_id, position)


## 获取活动拖拽在当前位置命中的落点候选。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param position: 要检查的位置。
## [br]
## @param only_accepting: 为 true 时只返回当前可接收会话的落点。
## [br]
## @return 按优先级排序的落点列表。
func get_active_drop_candidates(position: Vector2, only_accepting: bool = true) -> Array[GFDropZone]:
	if not has_active_drag():
		return []
	return _utility.get_drop_candidates(_active_session_id, position, only_accepting)


## 获取活动拖拽在当前位置的最佳落点。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param position: 要检查的位置。
## [br]
## @return 最佳落点；没有可用落点时返回 null。
func get_active_best_drop_zone(position: Vector2) -> GFDropZone:
	if not has_active_drag():
		return null
	return _utility.get_best_drop_zone(_active_session_id, position)


## 将活动拖拽释放到指定位置。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param position: 释放位置。
## [br]
## @param pointer_id: 发起释放的指针 ID。
## [br]
## @return 结构化结果字典。
## [br]
## @schema return: Dictionary，包含 ok、session_id、zone_id、reason 和可选 value。
func drop(position: Vector2, pointer_id: int = 0) -> Dictionary:
	if not has_active_drag():
		return _make_result(false, -1, &"", &"missing_session")
	if _captures_pointer and pointer_id != _active_pointer_id:
		return _make_result(false, _active_session_id, &"", &"pointer_mismatch")
	if _cancel_active_drag_if_source_invalid():
		return _make_result(false, -1, &"", &"source_invalid")
	return _utility.drop(_active_session_id, position)


## 取消活动拖拽。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param reason: 取消原因。
## [br]
## @return 找到并取消时返回 true。
func cancel_drag(reason: StringName = &"cancelled") -> bool:
	if not has_active_drag():
		return false
	_pending_cancel_reason = reason
	if not _utility.cancel_drag(_active_session_id):
		_finish_controller_session(_active_session_id, reason, _restore_source_parent_on_cancel)
		return false
	return true


## 获取活动会话。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 活动会话；没有活动拖拽时返回 null。
func get_active_session() -> GFDragSession:
	if not has_active_drag():
		return null
	return _utility.get_session(_active_session_id)


## 获取活动会话 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 活动会话 ID；没有活动拖拽时返回 -1。
func get_active_session_id() -> int:
	return _active_session_id


## 检查控制器是否有活动拖拽。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 存在活动拖拽时返回 true。
func has_active_drag() -> bool:
	return _active_session_id >= 0 and _utility.has_active_session(_active_session_id)


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param json_compatible: 为 true 时返回可直接 JSON.stringify() 的值。
## [br]
## @return 当前控制器状态。
## [br]
## @schema return: Dictionary，包含 active_session_id、pointer_capture、has_source、source_inside_tree 和 utility。
func get_debug_snapshot(json_compatible: bool = true) -> Dictionary:
	var source_node: Node = _get_source_node()
	var result: Dictionary = {
		"active_session_id": _active_session_id,
		"pointer_capture": _get_pointer_capture_dictionary(),
		"has_source": source_node != null,
		"source_inside_tree": source_node != null and source_node.is_inside_tree(),
		"utility": _utility.get_debug_snapshot(json_compatible),
	}
	if json_compatible:
		var encoded: Variant = GFVariantJsonCodec.variant_to_json_compatible(result)
		if encoded is Dictionary:
			var encoded_dictionary: Dictionary = encoded
			return encoded_dictionary
		return {
			"ok": false,
			"reason": "json_encoding_failed",
			"type": "GFDragDropController",
		}
	var copied_result: Variant = GFVariantData.duplicate_variant(result)
	if copied_result is Dictionary:
		var copied_dictionary: Dictionary = copied_result
		return copied_dictionary
	return {}


# --- 私有/辅助方法 ---

## 将 utility 的拖拽与落点注册信号连接到控制器转发处理函数。
## [br]
## @api private
## [br]
func _connect_utility_signals() -> void:
	var _started_connected: int = _utility.drag_started.connect(_on_utility_drag_started)
	var _moved_connected: int = _utility.drag_moved.connect(_on_utility_drag_moved)
	var _dropped_connected: int = _utility.drag_dropped.connect(_on_utility_drag_dropped)
	var _rejected_connected: int = _utility.drag_drop_rejected.connect(_on_utility_drag_drop_rejected)
	var _cancelled_connected: int = _utility.drag_cancelled.connect(_on_utility_drag_cancelled)
	var _zone_registered_connected: int = _utility.drop_zone_registered.connect(_on_utility_drop_zone_registered)
	var _zone_unregistered_connected: int = _utility.drop_zone_unregistered.connect(_on_utility_drop_zone_unregistered)


## 按配置检测弱引用来源是否已释放或 Node 已离树，并取消对应活动拖拽。
## [br]
## @api private
## [br]
func _cancel_active_drag_if_source_invalid() -> bool:
	if not has_active_drag():
		return false
	if _source_ref == null:
		return false
	var source: Object = _object_from_ref(_source_ref)
	if source == null and cancel_when_source_freed:
		var _cancelled_drag: bool = cancel_drag(&"source_freed")
		return true
	if source is Node:
		var source_node: Node = source
		if cancel_when_source_exits_tree and not source_node.is_inside_tree():
			var _cancelled_drag: bool = cancel_drag(&"source_exited_tree")
			return true
	return false


## 对匹配的活动会话执行一次性收尾：断开离树监听、按策略还原父节点、释放捕获并清空状态。
## [br]
## @api private
## [br]
func _finish_controller_session(session_id: int, _reason: StringName, restore_source_parent: bool) -> void:
	if session_id != _active_session_id or _finish_in_progress:
		return
	_finish_in_progress = true
	_disconnect_active_source_tree_exit()
	if restore_source_parent:
		var _restored_source: bool = _restore_active_source_parent()
	_release_pointer_capture()
	_active_session_id = -1
	_pending_cancel_reason = &""
	_clear_active_source_state()
	set_process(false)
	_finish_in_progress = false


## 以弱引用记录来源节点当前父节点及其子项索引。
## [br]
## @api private
## [br]
func _capture_original_parent(source_node: Node) -> void:
	var parent: Node = source_node.get_parent()
	_original_parent_ref = weakref(parent) if is_instance_valid(parent) else null
	_original_index = source_node.get_index() if parent != null else -1


## 必要时按全局变换策略重挂来源节点，并验证来源与目标父节点仍有效且层级关系已提交。
## [br]
## @api private
## [br]
func _commit_drag_visual_transaction(source_node: Node, drag_parent: Node) -> bool:
	if drag_parent == null or drag_parent == source_node.get_parent():
		return true
	source_node.reparent(drag_parent, _reparent_keep_global_transform)
	return (
		is_instance_valid(source_node)
		and not source_node.is_queued_for_deletion()
		and is_instance_valid(drag_parent)
		and not drag_parent.is_queued_for_deletion()
		and source_node.get_parent() == drag_parent
	)


## 验证可选 drag_parent 是否为有效且可安全重挂的 Node，并检查层级、删除状态及场景树兼容性。
## [br]
## @api private
## [br]
func _validate_drag_visual_transaction(source_node: Node, options: Dictionary) -> bool:
	if not options.has("drag_parent"):
		return true
	var raw_drag_parent: Variant = GFVariantData.get_option_value(options, "drag_parent")
	if raw_drag_parent == null:
		return true
	if source_node == null or not raw_drag_parent is Node:
		return false
	var drag_parent: Node = raw_drag_parent
	if not is_instance_valid(drag_parent) or drag_parent.is_queued_for_deletion():
		return false
	if source_node.is_queued_for_deletion() or source_node.get_parent() == null:
		return false
	if drag_parent == source_node or source_node.is_ancestor_of(drag_parent):
		return false
	if source_node.is_inside_tree() and not drag_parent.is_inside_tree():
		return false
	if source_node.is_inside_tree() and drag_parent.is_inside_tree():
		return source_node.get_tree() == drag_parent.get_tree()
	return true


## 从 options 读取 drag_parent 并收窄为 Node。
## [br]
## @api private
## [br]
func _get_requested_drag_parent(options: Dictionary) -> Node:
	return _node_from_variant(GFVariantData.get_option_value(options, "drag_parent"))


## 将来源节点还原到原父节点，并在可能时恢复原子项索引；无效引用或不兼容树时失败。
## [br]
## @api private
## [br]
func _restore_active_source_parent() -> bool:
	var source_node: Node = _get_source_node()
	var original_parent: Node = _get_original_parent()
	if source_node == null or original_parent == null:
		return false
	if source_node.is_queued_for_deletion() or original_parent.is_queued_for_deletion():
		return false
	if source_node == original_parent or source_node.is_ancestor_of(original_parent):
		return false
	var current_parent: Node = source_node.get_parent()
	if source_node.is_inside_tree() and original_parent.is_inside_tree():
		if source_node.get_tree() != original_parent.get_tree():
			return false
	if current_parent == null:
		original_parent.add_child(source_node)
	elif current_parent != original_parent:
		source_node.reparent(original_parent, _reparent_keep_global_transform)
	if source_node.get_parent() != original_parent:
		return false
	if source_node.get_parent() == original_parent and _original_index >= 0:
		var max_index: int = max(0, original_parent.get_child_count() - 1)
		var target_index: int = clampi(_original_index, 0, max_index)
		if source_node.get_index() != target_index:
			original_parent.move_child(source_node, target_index)
	return source_node.get_parent() == original_parent


## 按配置把当前来源节点的 tree_exited 信号连接为带会话 ID 的一次性取消回调。
## [br]
## @api private
## [br]
func _connect_active_source_tree_exit(source_node: Node, session_id: int) -> void:
	if source_node == null or not cancel_when_source_exits_tree:
		return
	_disconnect_active_source_tree_exit()
	_source_tree_exited_callable = _on_active_source_tree_exited.bind(session_id)
	var _tree_exited_connected: Error = source_node.tree_exited.connect(
		_source_tree_exited_callable,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error


## 若来源节点仍有效且回调已连接则断开，并清空回调句柄。
## [br]
## @api private
## [br]
func _disconnect_active_source_tree_exit() -> void:
	var source_node: Node = _get_source_node()
	if (
		source_node != null
		and _source_tree_exited_callable.is_valid()
		and source_node.tree_exited.is_connected(_source_tree_exited_callable)
	):
		source_node.tree_exited.disconnect(_source_tree_exited_callable)
	_source_tree_exited_callable = Callable()


## 清空来源、原父节点和索引，并恢复本次重挂及父节点还原选项的默认值。
## [br]
## @api private
## [br]
func _clear_active_source_state() -> void:
	_source_tree_exited_callable = Callable()
	_source_ref = null
	_original_parent_ref = null
	_original_index = -1
	_restore_source_parent_on_cancel = true
	_restore_source_parent_on_rejected_drop = true
	_restore_source_parent_on_success = false
	_reparent_keep_global_transform = true


## 清除活动 pointer ID 与捕获标志。
## [br]
## @api private
## [br]
func _release_pointer_capture() -> void:
	_active_pointer_id = _NO_POINTER_ID
	_captures_pointer = false


## 启动事务失败时尝试还原来源父节点，并释放指针捕获和来源状态。
## [br]
## @api private
## [br]
func _rollback_start_transaction() -> void:
	var _restored_source: bool = _restore_active_source_parent()
	_release_pointer_capture()
	_clear_active_source_state()


## 生成含活动 pointer ID 及有效捕获标志的状态字典。
## [br]
## @api private
## [br]
func _get_pointer_capture_dictionary() -> Dictionary:
	return {
		"active_pointer_id": _active_pointer_id,
		"active": _captures_pointer and _active_pointer_id != _NO_POINTER_ID,
	}


## 通过来源弱引用读取对象并收窄为有效 Node。
## [br]
## @api private
## [br]
func _get_source_node() -> Node:
	if _source_ref == null:
		return null
	var source: Object = _object_from_ref(_source_ref)
	return _node_from_object(source)


## 通过原父节点弱引用读取对象并收窄为有效 Node。
## [br]
## @api private
## [br]
func _get_original_parent() -> Node:
	if _original_parent_ref == null:
		return null
	var parent: Object = _object_from_ref(_original_parent_ref)
	return _node_from_object(parent)


## 仅当 Variant 是 Node 时返回该节点。
## [br]
## @api private
## [br]
func _node_from_variant(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


## 仅当对象是仍有效的 Node 时返回该节点。
## [br]
## @api private
## [br]
func _node_from_object(value: Object) -> Node:
	if value is Node and is_instance_valid(value):
		var node: Node = value
		return node
	return null


## 从 WeakRef 读取仍有效的 Object；空引用、非对象或已释放对象返回 null。
## [br]
## @api private
## [br]
func _object_from_ref(ref: WeakRef) -> Object:
	if ref == null:
		return null
	var value: Variant = ref.get_ref()
	if value is Object and is_instance_valid(value):
		var object: Object = value
		return object
	return null


## 构造包含 ok、session_id、zone_id 和 reason 的统一结果字典。
## [br]
## @api private
## [br]
func _make_result(ok: bool, session_id: int, zone_id: StringName, reason: StringName) -> Dictionary:
	return {
		"ok": ok,
		"session_id": session_id,
		"zone_id": zone_id,
		"reason": reason,
	}


# --- 信号处理函数 ---

## 启动中的同步通知只记录会话 ID，由启动流程处理；其他通知直接转发 drag_started。
## [br]
## @api private
func _on_utility_drag_started(session_id: int, drag_type: StringName) -> void:
	if _start_in_progress:
		_starting_session_id = session_id
		return
	drag_started.emit(session_id, drag_type)


## 查询当前位置的最佳投放区后再次确认会话仍活动，避免查询回调结束拖拽后发送过期移动通知。
## [br]
## @api private
func _on_utility_drag_moved(session_id: int, position: Vector2, delta: Vector2) -> void:
	var zone: GFDropZone = _utility.get_best_drop_zone(session_id, position)
	if not _utility.has_active_session(session_id):
		return
	var zone_id: StringName = zone.zone_id if zone != null else &""
	drag_moved.emit(session_id, position, delta, zone_id)


## 当前受管会话先按成功策略恢复源节点父级并结束控制器状态，再转发投放结果。
## [br]
## @api private
func _on_utility_drag_dropped(session_id: int, zone_id: StringName, result: Dictionary) -> void:
	var managed_session: bool = session_id == _active_session_id
	var restore_source_parent: bool = _restore_source_parent_on_success
	if managed_session:
		_finish_controller_session(session_id, &"dropped", restore_source_parent)
	drag_dropped.emit(session_id, zone_id, result)


## 仅终结当前受管且已不活动的会话；非终态拒绝保留拖拽，随后转发拒绝原因。
## [br]
## @api private
func _on_utility_drag_drop_rejected(session_id: int, reason: StringName) -> void:
	var terminal_reject: bool = not _utility.has_active_session(session_id)
	var managed_session: bool = session_id == _active_session_id
	var restore_source_parent: bool = _restore_source_parent_on_rejected_drop
	if terminal_reject and managed_session:
		_finish_controller_session(session_id, reason, restore_source_parent)
	drag_drop_rejected.emit(session_id, reason)


## 忽略启动中已记录会话的取消；受管会话先消费待用原因并完成清理，再发送控制器取消通知。
## [br]
## @api private
func _on_utility_drag_cancelled(session_id: int) -> void:
	if _start_in_progress and session_id == _starting_session_id:
		return
	var managed_session: bool = session_id == _active_session_id
	var reason: StringName = (
		_pending_cancel_reason
		if managed_session and _pending_cancel_reason != &""
		else &"utility_cancelled"
	)
	var restore_source_parent: bool = _restore_source_parent_on_cancel
	if managed_session:
		_pending_cancel_reason = &""
		_finish_controller_session(session_id, reason, restore_source_parent)
	drag_cancelled.emit(session_id, reason)


## 转发已注册投放区的 ID，供控制器监听者更新可投放目标。
## [br]
## @api private
func _on_utility_drop_zone_registered(zone_id: StringName) -> void:
	drop_zone_registered.emit(zone_id)


## 转发已注销投放区的 ID，不在此回调中改变活动拖拽会话。
## [br]
## @api private
func _on_utility_drop_zone_unregistered(zone_id: StringName) -> void:
	drop_zone_unregistered.emit(zone_id)


## 仅当退出节点仍属于当前会话且配置要求取消时，以 source_exited_tree 取消拖拽。
## [br]
## @api private
func _on_active_source_tree_exited(session_id: int) -> void:
	if session_id != _active_session_id or not cancel_when_source_exits_tree:
		return
	var _cancelled_drag: bool = cancel_drag(&"source_exited_tree")
