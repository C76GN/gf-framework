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

## 拖拽开始时发出。
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

## 拖拽成功释放到落点时发出。
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

## 拖拽释放被拒绝时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param session_id: 会话 ID。
## [br]
## @param reason: 拒绝原因。
signal drag_drop_rejected(session_id: int, reason: StringName)

## 拖拽取消时发出。
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

var _utility: GFDragDropUtility = GFDragDropUtility.new()
var _active_pointer_id: int = _NO_POINTER_ID
var _captures_pointer: bool = false
var _active_session_id: int = -1
var _source_ref: WeakRef = null
var _original_parent_ref: WeakRef = null
var _original_index: int = -1
var _restore_source_parent_on_cancel: bool = true
var _restore_source_parent_on_rejected_drop: bool = true
var _restore_source_parent_on_success: bool = false
var _reparent_keep_global_transform: bool = true
var _pending_cancel_reason: StringName = &""
var _source_tree_exited_callable: Callable = Callable()


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
## @return 会话 ID；失败时返回 -1。
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
	if has_active_drag() or drag_type == &"":
		return -1

	var source_node: Node = _node_from_object(source)
	if not _validate_drag_visual_transaction(source_node, options):
		return -1

	var pointer_id: int = GFVariantData.get_option_int(options, "pointer_id", 0)
	var capture_pointer: bool = GFVariantData.get_option_bool(options, "capture_pointer", true)
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
			_release_pointer_capture()
			_clear_active_source_state()
			return -1

	var metadata: Dictionary = GFVariantData.get_option_dictionary(options, "metadata")
	var session_id: int = _utility.start_drag(drag_type, payload, position, source, metadata)
	if session_id < 0:
		_restore_active_source_parent()
		_release_pointer_capture()
		_clear_active_source_state()
		return -1

	_active_session_id = session_id
	_connect_active_source_tree_exit(source_node, session_id)
	set_process(true)
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
	return result


# --- 私有/辅助方法 ---

func _connect_utility_signals() -> void:
	var _started_connected: int = _utility.drag_started.connect(_on_utility_drag_started)
	var _moved_connected: int = _utility.drag_moved.connect(_on_utility_drag_moved)
	var _dropped_connected: int = _utility.drag_dropped.connect(_on_utility_drag_dropped)
	var _rejected_connected: int = _utility.drag_drop_rejected.connect(_on_utility_drag_drop_rejected)
	var _cancelled_connected: int = _utility.drag_cancelled.connect(_on_utility_drag_cancelled)
	var _zone_registered_connected: int = _utility.drop_zone_registered.connect(_on_utility_drop_zone_registered)
	var _zone_unregistered_connected: int = _utility.drop_zone_unregistered.connect(_on_utility_drop_zone_unregistered)


func _on_utility_drag_started(session_id: int, drag_type: StringName) -> void:
	drag_started.emit(session_id, drag_type)


func _on_utility_drag_moved(session_id: int, position: Vector2, delta: Vector2) -> void:
	var zone: GFDropZone = _utility.get_best_drop_zone(session_id, position)
	var zone_id: StringName = zone.zone_id if zone != null else &""
	drag_moved.emit(session_id, position, delta, zone_id)


func _on_utility_drag_dropped(session_id: int, zone_id: StringName, result: Dictionary) -> void:
	drag_dropped.emit(session_id, zone_id, result)
	_finish_controller_session(session_id, &"dropped", _restore_source_parent_on_success)


func _on_utility_drag_drop_rejected(session_id: int, reason: StringName) -> void:
	drag_drop_rejected.emit(session_id, reason)
	if not _utility.has_active_session(session_id):
		_finish_controller_session(session_id, reason, _restore_source_parent_on_rejected_drop)


func _on_utility_drag_cancelled(session_id: int) -> void:
	var reason: StringName = _pending_cancel_reason if _pending_cancel_reason != &"" else &"utility_cancelled"
	_pending_cancel_reason = &""
	drag_cancelled.emit(session_id, reason)
	_finish_controller_session(session_id, reason, _restore_source_parent_on_cancel)


func _on_utility_drop_zone_registered(zone_id: StringName) -> void:
	drop_zone_registered.emit(zone_id)


func _on_utility_drop_zone_unregistered(zone_id: StringName) -> void:
	drop_zone_unregistered.emit(zone_id)


func _on_active_source_tree_exited(session_id: int) -> void:
	if session_id != _active_session_id or not cancel_when_source_exits_tree:
		return
	var _cancelled_drag: bool = cancel_drag(&"source_exited_tree")


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


func _finish_controller_session(session_id: int, _reason: StringName, restore_source_parent: bool) -> void:
	if session_id != _active_session_id:
		return
	_disconnect_active_source_tree_exit()
	if restore_source_parent:
		_restore_active_source_parent()
	_release_pointer_capture()
	_active_session_id = -1
	_pending_cancel_reason = &""
	_clear_active_source_state()
	set_process(false)


func _capture_original_parent(source_node: Node) -> void:
	var parent: Node = source_node.get_parent()
	_original_parent_ref = weakref(parent) if is_instance_valid(parent) else null
	_original_index = source_node.get_index() if parent != null else -1


func _commit_drag_visual_transaction(source_node: Node, drag_parent: Node) -> bool:
	if drag_parent == null or drag_parent == source_node.get_parent():
		return true
	source_node.reparent(drag_parent, _reparent_keep_global_transform)
	return source_node.get_parent() == drag_parent


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


func _get_requested_drag_parent(options: Dictionary) -> Node:
	return _node_from_variant(GFVariantData.get_option_value(options, "drag_parent"))


func _restore_active_source_parent() -> void:
	var source_node: Node = _get_source_node()
	var original_parent: Node = _get_original_parent()
	if source_node == null or original_parent == null:
		return
	if source_node.get_parent() == null or source_node.is_queued_for_deletion():
		return
	if source_node.get_parent() != original_parent:
		source_node.reparent(original_parent, _reparent_keep_global_transform)
	if source_node.get_parent() == original_parent and _original_index >= 0:
		var max_index: int = max(0, original_parent.get_child_count() - 1)
		var target_index: int = clampi(_original_index, 0, max_index)
		if source_node.get_index() != target_index:
			original_parent.move_child(source_node, target_index)


func _connect_active_source_tree_exit(source_node: Node, session_id: int) -> void:
	if source_node == null or not cancel_when_source_exits_tree:
		return
	_disconnect_active_source_tree_exit()
	_source_tree_exited_callable = _on_active_source_tree_exited.bind(session_id)
	var _tree_exited_connected: Error = source_node.tree_exited.connect(
		_source_tree_exited_callable,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error


func _disconnect_active_source_tree_exit() -> void:
	var source_node: Node = _get_source_node()
	if (
		source_node != null
		and _source_tree_exited_callable.is_valid()
		and source_node.tree_exited.is_connected(_source_tree_exited_callable)
	):
		source_node.tree_exited.disconnect(_source_tree_exited_callable)
	_source_tree_exited_callable = Callable()


func _clear_active_source_state() -> void:
	_source_tree_exited_callable = Callable()
	_source_ref = null
	_original_parent_ref = null
	_original_index = -1
	_restore_source_parent_on_cancel = true
	_restore_source_parent_on_rejected_drop = true
	_restore_source_parent_on_success = false
	_reparent_keep_global_transform = true


func _release_pointer_capture() -> void:
	_active_pointer_id = _NO_POINTER_ID
	_captures_pointer = false


func _get_pointer_capture_dictionary() -> Dictionary:
	return {
		"active_pointer_id": _active_pointer_id,
		"active": _captures_pointer and _active_pointer_id != _NO_POINTER_ID,
	}


func _get_source_node() -> Node:
	if _source_ref == null:
		return null
	var source: Object = _object_from_ref(_source_ref)
	return _node_from_object(source)


func _get_original_parent() -> Node:
	if _original_parent_ref == null:
		return null
	var parent: Object = _object_from_ref(_original_parent_ref)
	return _node_from_object(parent)


func _node_from_variant(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


func _node_from_object(value: Object) -> Node:
	if value is Node and is_instance_valid(value):
		var node: Node = value
		return node
	return null


func _object_from_ref(ref: WeakRef) -> Object:
	if ref == null:
		return null
	var value: Variant = ref.get_ref()
	if value is Object and is_instance_valid(value):
		var object: Object = value
		return object
	return null


func _make_result(ok: bool, session_id: int, zone_id: StringName, reason: StringName) -> Dictionary:
	return {
		"ok": ok,
		"session_id": session_id,
		"zone_id": zone_id,
		"reason": reason,
	}
