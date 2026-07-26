## GFCancellationSource: 可触发取消的拥有者句柄。
##
## source 负责创建和触发 [GFCancellationToken]，并可把上游 token、节点生命周期或
## SceneTree 超时连接为统一取消请求。它不执行具体任务，也不假定取消后的业务回滚策略。
## 所有改变 source 状态或信号连接的方法都只能在主线程调用；[method dispose] 是不可逆终态。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
## [br]
## @layer kernel/core
class_name GFCancellationSource
extends RefCounted


# --- 信号 ---

## source 首次取消时发出。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param reason: 稳定取消原因。
## [br]
## @param metadata: 调用方附加的取消上下文。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
signal cancel_requested(reason: StringName, metadata: Dictionary)


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _token: GFCancellationToken = GFCancellationToken.new()
var _linked_tokens: Dictionary = {}
var _node_lifetime_callbacks: Dictionary = {}
var _timeout_timer: SceneTreeTimer = null
var _timeout_callback: Callable = Callable()
var _disposed: bool = false


# --- 公共方法 ---

## 获取只读取消 token。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 当前 source 持有的取消 token。
func get_token() -> GFCancellationToken:
	return _token


## 触发取消。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param reason: 稳定取消原因。
## [br]
## @param metadata: 调用方附加的取消上下文。
## [br]
## @return 首次取消时返回 true。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
func cancel(reason: StringName = &"cancelled", metadata: Dictionary = {}) -> bool:
	if not _can_mutate_on_current_thread("cancel"):
		return false
	if _disposed:
		return false

	var cancel_requested_now: bool = _token.request_cancel_internal(reason, metadata)
	if not cancel_requested_now:
		return false

	_disconnect_timeout()
	_disconnect_linked_tokens()
	_disconnect_node_lifetime_callbacks()
	cancel_requested.emit(_token.get_cancel_reason(), _token.get_cancel_metadata())
	return true


## 判断 source 是否已经请求取消。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 已请求取消时返回 true。
func is_cancel_requested() -> bool:
	return _token.is_cancel_requested()


## 连接上游 token；上游取消时当前 source 也会取消。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param token: 上游取消 token。
## [br]
## @param reason: 可选覆盖原因；为空时使用上游原因。
## [br]
## @param metadata: 当前连接附加的元数据；注册时深复制，并覆盖同名上游字段。
## [br]
## @return 成功连接或上游已经触发取消时返回 true；重复、自连接、非主线程或终态 source 返回 false。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
func link_token(token: GFCancellationToken, reason: StringName = &"", metadata: Dictionary = {}) -> bool:
	if not _can_mutate_on_current_thread("link_token"):
		return false
	if _disposed or is_cancel_requested():
		return false
	if token == null or token == _token:
		return false

	var token_key: int = token.get_instance_id()
	if _linked_tokens.has(token_key):
		return false

	var metadata_snapshot: Dictionary = _snapshot_metadata(metadata)
	if token.is_cancel_requested():
		var immediate_reason: StringName = reason if reason != &"" else token.get_cancel_reason()
		var immediate_metadata: Dictionary = _merge_metadata(
			token.get_cancel_metadata(),
			metadata_snapshot
		)
		return cancel(immediate_reason, immediate_metadata)

	var callback: Callable = Callable(self, &"_on_linked_token_cancelled").bind(
		weakref(token),
		reason,
		metadata_snapshot
	)
	var connect_error: Error = token.cancel_requested.connect(
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
## @since 8.0.0
## [br]
## @param node: 生命周期拥有者节点。
## [br]
## @param reason: 取消原因。
## [br]
## @param metadata: 取消上下文；注册时深复制。
## [br]
## @return 当前在树内的节点成功连接时返回 true；重复连接、树外节点、非主线程或终态 source 返回 false。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
func cancel_when_node_exits(
	node: Node,
	reason: StringName = &"node_exited",
	metadata: Dictionary = {}
) -> bool:
	if not _can_mutate_on_current_thread("cancel_when_node_exits"):
		return false
	if _disposed or is_cancel_requested():
		return false
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return false

	var node_key: int = node.get_instance_id()
	if _node_lifetime_callbacks.has(node_key):
		return false

	var metadata_snapshot: Dictionary = _snapshot_metadata(metadata)
	var callback: Callable = Callable(self, &"_on_node_tree_exited").bind(
		reason,
		metadata_snapshot
	)
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
## @since 8.0.0
## [br]
## @param seconds: 有限超时时间；小于等于 0 时立即取消。
## [br]
## @param tree: 可选 SceneTree；为空时使用当前主循环。
## [br]
## @param reason: 超时取消原因。
## [br]
## @param metadata: 取消上下文；安排时深复制。
## [br]
## @param process_always: 是否在暂停时继续计时。
## [br]
## @param process_in_physics: 是否在物理帧处理。
## [br]
## @param ignore_time_scale: 是否忽略 Engine.time_scale。
## [br]
## @return 成功安排或立即触发取消时返回 true；后续安排会停止并替换旧 timer。
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
	if not _can_mutate_on_current_thread("cancel_after_seconds"):
		return false
	if _disposed or is_cancel_requested():
		return false
	if is_nan(seconds) or is_inf(seconds):
		return false
	var metadata_snapshot: Dictionary = _snapshot_metadata(metadata)
	if seconds <= 0.0:
		return cancel(reason, metadata_snapshot)

	var target_tree: SceneTree = tree if tree != null else _get_main_scene_tree()
	if target_tree == null or not is_instance_valid(target_tree):
		return false

	_disconnect_timeout()
	_timeout_timer = target_tree.create_timer(seconds, process_always, process_in_physics, ignore_time_scale)
	if _timeout_timer == null:
		return false
	_timeout_callback = Callable(self, &"_on_timeout_elapsed").bind(reason, metadata_snapshot)
	var connect_error: Error = _timeout_timer.timeout.connect(
		_timeout_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		_disconnect_timeout()
		return false
	return true


## 终结 source 并释放其持有的连接。
## dispose 幂等且不可逆；之后所有 mutator 都会失败，既有 token 状态保持不变。
## [br]
## @api public
## [br]
## @since 8.0.0
func dispose() -> void:
	if not _can_mutate_on_current_thread("dispose"):
		return
	if _disposed:
		return
	_disposed = true
	_disconnect_timeout()
	_disconnect_linked_tokens()
	_disconnect_node_lifetime_callbacks()


## 获取取消 source 调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary，包含 token 状态、disposed、linked_token_count、node_lifetime_count 和 has_timeout。
func get_debug_snapshot() -> Dictionary:
	var token_snapshot: Dictionary = _token.get_debug_snapshot()
	token_snapshot["disposed"] = _disposed
	token_snapshot["linked_token_count"] = _linked_tokens.size()
	token_snapshot["node_lifetime_count"] = _node_lifetime_callbacks.size()
	token_snapshot["has_timeout"] = _timeout_timer != null and is_instance_valid(_timeout_timer)
	return token_snapshot


## 创建一个连接多个上游 token 的 source。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param tokens: 上游 token 列表。
## [br]
## @param reason: 可选覆盖原因；为空时使用上游原因。
## [br]
## @param metadata: 当前连接附加的元数据。
## [br]
## @return 完整连接的新 source；无效条目或连接失败时返回 null。若上游已取消，返回 first-cancel-wins 的终态 source。
## [br]
## @schema tokens: Array，元素应为 GFCancellationToken。
## [br]
## @schema metadata: Dictionary，包含调用方定义的取消上下文。
static func create_linked(
	tokens: Array,
	reason: StringName = &"",
	metadata: Dictionary = {}
) -> GFCancellationSource:
	if not Thread.is_main_thread():
		push_error("[GFCancellationSource] create_linked 失败：只能在主线程调用。")
		return null

	var source: GFCancellationSource = GFCancellationSource.new()
	for token_value: Variant in tokens:
		if not (token_value is GFCancellationToken):
			source.dispose()
			return null
		var token: GFCancellationToken = token_value
		if not source.link_token(token, reason, metadata):
			source.dispose()
			return null
		if source.is_cancel_requested():
			return source
	return source


# --- 私有/辅助方法 ---

func _disconnect_timeout() -> void:
	var timeout_timer: SceneTreeTimer = _timeout_timer
	var timeout_callback: Callable = _timeout_callback
	_timeout_timer = null
	_timeout_callback = Callable()
	if timeout_timer == null or not is_instance_valid(timeout_timer):
		return
	if timeout_callback.is_valid() and timeout_timer.timeout.is_connected(timeout_callback):
		timeout_timer.timeout.disconnect(timeout_callback)
	timeout_timer.time_left = 0.0


func _disconnect_linked_tokens() -> void:
	for entry_value: Variant in _linked_tokens.values():
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(entry_value)
		var token: GFCancellationToken = _variant_to_cancel_token(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "token")
		)
		var callback: Callable = _variant_to_callable(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "callback", Callable())
		)
		if token != null and callback.is_valid() and token.cancel_requested.is_connected(callback):
			token.cancel_requested.disconnect(callback)
	_linked_tokens.clear()


func _disconnect_node_lifetime_callbacks() -> void:
	for entry_value: Variant in _node_lifetime_callbacks.values():
		var entry: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(entry_value)
		var node_ref: WeakRef = _variant_to_weak_ref(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "node_ref")
		)
		var node: Node = _weak_ref_to_node(node_ref)
		var callback: Callable = _variant_to_callable(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_value(entry, "callback", Callable())
		)
		if node != null and callback.is_valid() and node.tree_exited.is_connected(callback):
			node.tree_exited.disconnect(callback)
	_node_lifetime_callbacks.clear()


func _get_main_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		return tree
	return null


func _can_mutate_on_current_thread(operation_name: String) -> bool:
	if Thread.is_main_thread():
		return true
	push_error("[GFCancellationSource] %s 失败：只能在主线程调用。" % operation_name)
	return false


func _snapshot_metadata(metadata: Dictionary) -> Dictionary:
	var snapshot_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(metadata)
	if snapshot_value is Dictionary:
		var snapshot: Dictionary = snapshot_value
		return snapshot
	return {}


func _merge_metadata(base: Dictionary, extra: Dictionary) -> Dictionary:
	var result: Dictionary = _snapshot_metadata(base)
	var extra_snapshot: Dictionary = _snapshot_metadata(extra)
	for metadata_key: Variant in extra_snapshot.keys():
		result[metadata_key] = extra_snapshot[metadata_key]
	return result


func _variant_to_cancel_token(value: Variant) -> GFCancellationToken:
	if value is GFCancellationToken:
		var token: GFCancellationToken = value
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


func _weak_ref_to_cancel_token(weak_ref: WeakRef) -> GFCancellationToken:
	if weak_ref == null:
		return null
	var value: Variant = weak_ref.get_ref()
	if value is GFCancellationToken:
		var token: GFCancellationToken = value
		return token
	return null


# --- 信号处理函数 ---

func _on_linked_token_cancelled(
	parent_reason: StringName,
	token_ref: WeakRef,
	override_reason: StringName,
	metadata_snapshot: Dictionary
) -> void:
	var token: GFCancellationToken = _weak_ref_to_cancel_token(token_ref)
	if token == null:
		return
	var linked_reason: StringName = override_reason if override_reason != &"" else parent_reason
	var linked_metadata: Dictionary = _merge_metadata(
		token.get_cancel_metadata(),
		metadata_snapshot
	)
	var _cancelled_from_link: bool = cancel(linked_reason, linked_metadata)


func _on_node_tree_exited(reason: StringName, metadata_snapshot: Dictionary) -> void:
	var _cancelled_from_node: bool = cancel(reason, metadata_snapshot)


func _on_timeout_elapsed(reason: StringName, metadata_snapshot: Dictionary) -> void:
	var _cancelled_from_timeout: bool = cancel(reason, metadata_snapshot)
