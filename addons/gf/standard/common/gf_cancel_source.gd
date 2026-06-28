## GFCancelSource: 可触发取消的拥有者句柄。
##
## source 负责创建和触发 [GFCancelToken]，并可把上游 token、节点生命周期或 SceneTree 超时
## 连接为统一取消信号。它不执行具体任务，也不假定取消后的业务回滚策略。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFCancelSource
extends RefCounted


# --- 信号 ---

## source 首次取消时发出。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 稳定取消原因。
## [br]
## @param metadata: 调用方附加的取消上下文。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
signal cancelled(reason: StringName, metadata: Dictionary)


# --- 私有变量 ---

var _token: GFCancelToken = GFCancelToken.new()
var _linked_tokens: Dictionary = {}
var _node_lifetime_callbacks: Dictionary = {}
var _timeout_timer: SceneTreeTimer = null
var _timeout_signal: Signal = Signal()
var _timeout_callback: Callable = Callable()


# --- Godot 生命周期方法 ---

## 创建取消 source。
## [br]
## @api public
## [br]
## @since 7.0.0
func _init() -> void:
	pass


# --- 公共方法 ---

## 获取只读取消 token。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 当前 source 持有的取消 token。
func get_token() -> GFCancelToken:
	return _token


## 触发取消。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param reason: 稳定取消原因。
## [br]
## @param metadata: 调用方附加的取消上下文。
## [br]
## @return 首次取消时返回 true。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:
	var cancelled_now: bool = _token.cancel_from_source(reason, metadata)
	if not cancelled_now:
		return false

	_disconnect_timeout()
	_disconnect_linked_tokens()
	_disconnect_node_lifetime_callbacks()
	cancelled.emit(_token.get_reason(), _token.get_metadata())
	return true


## 判断 source 是否已经取消。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 已取消时返回 true。
func is_cancelled() -> bool:
	return _token.is_cancelled()


## 连接上游 token；上游取消时当前 source 也会取消。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param token: 上游取消 token。
## [br]
## @param reason: 可选覆盖原因；为空时使用上游原因。
## [br]
## @param metadata: 当前连接附加的元数据，会覆盖同名上游字段。
## [br]
## @return 成功连接或上游已经触发取消时返回 true。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
func link_token(token: GFCancelToken, reason: StringName = &"", metadata: Dictionary = {}) -> bool:
	if token == null:
		return false
	if is_cancelled():
		return false
	if token.is_cancelled():
		var immediate_reason: StringName = reason if reason != &"" else token.get_reason()
		var immediate_metadata: Dictionary = _merge_metadata(token.get_metadata(), metadata)
		var _cancelled_now: bool = cancel(immediate_reason, immediate_metadata)
		return true

	var token_key: int = token.get_instance_id()
	if _linked_tokens.has(token_key):
		return true

	var callback: Callable = func(parent_reason: StringName, parent_metadata: Dictionary) -> void:
		var linked_reason: StringName = reason if reason != &"" else parent_reason
		var linked_metadata: Dictionary = _merge_metadata(parent_metadata, metadata)
		var _cancelled_from_link: bool = cancel(linked_reason, linked_metadata)

	var connect_error: Error = token.cancelled.connect(
		callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		return false

	_linked_tokens[token_key] = {
		"token": token,
		"callback": callback,
	}
	return true


## 在节点离开场景树时取消。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param node: 生命周期拥有者节点。
## [br]
## @param reason: 取消原因。
## [br]
## @param metadata: 取消上下文。
## [br]
## @return 成功连接或节点已经离树并触发取消时返回 true。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
func cancel_when_node_exits(node: Node, reason: StringName = &"node_exited", metadata: Dictionary = {}) -> bool:
	if node == null:
		return false
	if is_cancelled():
		return false
	if not node.is_inside_tree():
		var _cancelled_now: bool = cancel(reason, metadata)
		return true

	var node_key: int = node.get_instance_id()
	if _node_lifetime_callbacks.has(node_key):
		return true

	var callback: Callable = func() -> void:
		var _cancelled_from_node: bool = cancel(reason, metadata)
	var connect_error: Error = node.tree_exited.connect(
		callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		return false

	_node_lifetime_callbacks[node_key] = {
		"node_ref": weakref(node),
		"callback": callback,
	}
	return true


## 在指定秒数后自动取消。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param seconds: 超时时间；小于等于 0 时立即取消。
## [br]
## @param tree: 可选 SceneTree；为空时使用当前主循环。
## [br]
## @param reason: 超时取消原因。
## [br]
## @param metadata: 取消上下文。
## [br]
## @param process_always: 是否在暂停时继续计时。
## [br]
## @param process_in_physics: 是否在物理帧处理。
## [br]
## @param ignore_time_scale: 是否忽略 Engine.time_scale。
## [br]
## @return 成功安排或立即触发取消时返回 true。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
func cancel_after_seconds(
	seconds: float,
	tree: SceneTree = null,
	reason: StringName = &"timeout",
	metadata: Dictionary = {},
	process_always: bool = true,
	process_in_physics: bool = false,
	ignore_time_scale: bool = false
) -> bool:
	if is_cancelled():
		return false
	if seconds <= 0.0:
		var _cancelled_now: bool = cancel(reason, metadata)
		return true

	var target_tree: SceneTree = tree if tree != null else _get_main_scene_tree()
	if target_tree == null:
		return false

	_disconnect_timeout()
	_timeout_timer = target_tree.create_timer(seconds, process_always, process_in_physics, ignore_time_scale)
	_timeout_signal = _timeout_timer.timeout
	_timeout_callback = func() -> void:
		var _cancelled_from_timeout: bool = cancel(reason, metadata)
	var connect_error: Error = _timeout_signal.connect(
		_timeout_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	return connect_error == OK


## 释放 source 持有的连接。
## [br]
## @api public
## [br]
## @since 7.0.0
func dispose() -> void:
	_disconnect_timeout()
	_disconnect_linked_tokens()
	_disconnect_node_lifetime_callbacks()


## 获取取消 source 调试快照。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 token 状态、linked_token_count、node_lifetime_count 和 has_timeout。
func get_debug_snapshot() -> Dictionary:
	var token_snapshot: Dictionary = _token.get_debug_snapshot()
	token_snapshot["linked_token_count"] = _linked_tokens.size()
	token_snapshot["node_lifetime_count"] = _node_lifetime_callbacks.size()
	token_snapshot["has_timeout"] = not _timeout_signal.is_null()
	return token_snapshot


## 创建一个连接多个上游 token 的 source。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param tokens: 上游 token 列表。
## [br]
## @param reason: 可选覆盖原因；为空时使用上游原因。
## [br]
## @param metadata: 当前连接附加的元数据。
## [br]
## @return 新建的取消 source。
## [br]
## @schema tokens: Array，元素应为 GFCancelToken。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
static func create_linked(tokens: Array, reason: StringName = &"", metadata: Dictionary = {}) -> GFCancelSource:
	var source: GFCancelSource = GFCancelSource.new()
	for token_value: Variant in tokens:
		if token_value is GFCancelToken:
			var token: GFCancelToken = token_value
			var _link_result: bool = source.link_token(token, reason, metadata)
	return source


# --- 私有/辅助方法 ---

func _disconnect_timeout() -> void:
	if not _timeout_signal.is_null() and _timeout_callback.is_valid():
		var signal_owner: Object = _timeout_signal.get_object()
		if is_instance_valid(signal_owner) and _timeout_signal.is_connected(_timeout_callback):
			_timeout_signal.disconnect(_timeout_callback)
	_timeout_timer = null
	_timeout_signal = Signal()
	_timeout_callback = Callable()


func _disconnect_linked_tokens() -> void:
	for entry_value: Variant in _linked_tokens.values():
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		var token: GFCancelToken = _variant_to_cancel_token(GFVariantData.get_option_value(entry, "token"))
		var callback: Callable = _variant_to_callable(GFVariantData.get_option_value(entry, "callback", Callable()))
		if token != null and callback.is_valid() and token.cancelled.is_connected(callback):
			token.cancelled.disconnect(callback)
	_linked_tokens.clear()


func _disconnect_node_lifetime_callbacks() -> void:
	for entry_value: Variant in _node_lifetime_callbacks.values():
		var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
		var node_ref: WeakRef = _variant_to_weak_ref(GFVariantData.get_option_value(entry, "node_ref"))
		var node: Node = _weak_ref_to_node(node_ref)
		var callback: Callable = _variant_to_callable(GFVariantData.get_option_value(entry, "callback", Callable()))
		if node != null and callback.is_valid() and node.tree_exited.is_connected(callback):
			node.tree_exited.disconnect(callback)
	_node_lifetime_callbacks.clear()


func _get_main_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		return tree
	return null


func _merge_metadata(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key: Variant in extra.keys():
		result[key] = GFVariantData.duplicate_variant(extra[key])
	return result


func _variant_to_cancel_token(value: Variant) -> GFCancelToken:
	if value is GFCancelToken:
		var token: GFCancelToken = value
		return token
	return null


func _variant_to_callable(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _variant_to_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var weak_ref: WeakRef = value
		return weak_ref
	return null


func _weak_ref_to_node(weak_ref: WeakRef) -> Node:
	if weak_ref == null:
		return null
	var value: Variant = weak_ref.get_ref()
	if value is Node:
		var node: Node = value
		return node
	return null
