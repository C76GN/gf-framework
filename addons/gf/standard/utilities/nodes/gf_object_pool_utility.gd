## GFObjectPoolUtility: 在安全点借出和归还节点的对象池。
##
## 空闲实例完全离树；借出时返回一次性 Lease。所有挂载、脱树及清理均在主线程
## deferred 安全点执行。根节点可实现同步 on_gf_pool_prepare(context) -> Error，
## 在每次入树前写入本次数据；该方法不得 await、释放根节点或改变根节点父级。
## 普通进入/退出场景树的初始化与清理由节点自己的 Godot 生命周期方法负责。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFObjectPoolUtility
extends GFUtility


# --- 信号 ---

signal _dispose_completed


# --- 枚举 ---

enum _Phase {
	IDLE,
	ACQUIRING,
	LEASED,
	RELEASING,
	RETIRED,
}


enum _Kind {
	ACQUIRE,
	RELEASE,
	PREWARM,
	DISPOSE,
}


# --- 常量 ---

const _MAX_REQUESTS_PER_DRAIN: int = 64


# --- 公共变量 ---

## 每个场景最多缓存的空闲实例数；0 不限制，-1 归还时直接销毁。
## [br]
## @api public
## [br]
## @since 3.17.0
var max_available_per_scene: int = 0


# --- 私有变量 ---

var _entries: Dictionary[int, _Entry] = {}
var _available: Dictionary[PackedScene, Array] = {}
var _queue: Array[_Request] = []
var _scheduled: bool = false
var _draining: bool = false
var _notifying: bool = false
var _disposing: bool = false
var _disposed: bool = false


# --- Godot 生命周期方法 ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for entry: _Entry in _entries.values():
			if is_instance_valid(entry._node):
				entry._node.queue_free()
			if entry._lease != null:
				entry._lease.mark_pending_for_framework()
				GFObjectPoolUtility._settle_lease.call_deferred(entry._lease, &"pool_disposed")


# --- GF 生命周期方法 ---

## 停止接纳新工作，并等待安全点清理及全部已接纳请求与 Lease 的终态通知。
##
## 取消静默等待不会取消节点清理；强制退出后仍可单独等待 wait_disposed。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param _scope: 当前静默阶段的取消作用域，不拥有实际节点清理。
## [br]
## @return: 本次静默等待的一次性完成源。
func begin_quiesce(_scope: GFAsyncScope) -> GFAsyncCompletion:
	var completion: GFAsyncCompletion = GFAsyncCompletion.new()
	dispose()
	if _scope != null:
		var _bound: bool = completion.bind_cancel_token(_scope)
	if _disposed:
		var _succeeded: bool = completion.succeed()
	else:
		var _connected: Error = _dispose_completed.connect(
			completion.succeed, CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error
	return completion


## 立即停止接纳新借用并吊销现有 Lease，在安全点完成节点清理。
## [br]
## @api public
## [br]
## @since 3.17.0
func dispose() -> void:
	if _disposing or not Thread.is_main_thread():
		return
	_disposing = true
	for entry: _Entry in _entries.values():
		if entry._lease != null:
			entry._lease.mark_pending_for_framework()
	var request: _Request = _Request.new()
	request._kind = _Kind.DISPOSE
	_enqueue(request)


# --- 公共方法 ---

## 在安全点取得一个完成入树准备的实例。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scene: 实例来源。
## [br]
## @param parent: 必须位于运行中的 SceneTree，等待期间离树或被删除将取消请求。
## [br]
## @param lifetime_owner: 必填弱引用生命周期锚点；等待期间销毁或 Node 离树会取消请求，成功交付后不再跟踪 owner，也不自动归还 Lease。
## [br]
## @param context: 传给根节点 on_gf_pool_prepare 的本次初始化数据。
## [br]
## @return: 本次借用的结构化结果；成功后由调用方持有并归还 Lease。
## [br]
## @schema context: Dictionary；接受请求时深复制嵌套容器，Object 值保留身份，调用方应在等待期间保持所引用对象只读；不得用 context 传递所有权回调。
func acquire(
	scene: PackedScene,
	parent: Node,
	lifetime_owner: Object,
	context: Dictionary = {}
) -> GFObjectPoolAcquireResult:
	var request: _Request = _make_acquire_request(
		scene, parent, 1, context, lifetime_owner, true
	)
	# 协程参数不能把弱生命周期锚点保活到请求交付。
	lifetime_owner = null
	if request._results.is_empty():
		_enqueue(request)
		await request._completed
	return request._results[0]


## 分帧预分配离树实例，不执行 prepare、enter_tree 或 ready。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param scene: 实例来源。
## [br]
## @param count: 本次希望新增的数量；0 为成功空操作，负数无效。
## [br]
## @param batch_size: 每次安全点最多创建的数量，必须为正数。
## [br]
## @param cancellation_token: 可选取消令牌；已缓存的实例不会因取消被回滚。
## [br]
## @return: 请求完成时的创建数量与最终原因。
func prewarm(
	scene: PackedScene,
	count: int,
	batch_size: int = 32,
	cancellation_token: GFCancellationToken = null
) -> GFObjectPoolPrewarmResult:
	var request: _Request = _Request.new()
	request._kind = _Kind.PREWARM
	request._scene = scene
	request._count = count
	request._batch_size = batch_size
	request._token = cancellation_token
	var invalid_reason: StringName = &""
	if not Thread.is_main_thread():
		invalid_reason = &"main_thread_required"
	elif not is_instance_valid(scene) or not scene.can_instantiate():
		invalid_reason = &"invalid_scene"
	elif count < 0:
		invalid_reason = &"invalid_count"
	elif batch_size <= 0:
		invalid_reason = &"invalid_batch_size"
	if invalid_reason != &"":
		_finish_prewarm(request, GFObjectPoolPrewarmResult.Status.INVALID, invalid_reason)
		return request._prewarm_result
	if _disposing:
		_finish_prewarm(request, GFObjectPoolPrewarmResult.Status.CANCELLED, &"pool_disposed")
		return request._prewarm_result
	_enqueue(request)
	await request._completed
	return request._prewarm_result


## 等待 dispose 已发起的节点清理及全部已接纳请求与 Lease 的终态通知；允许在完成后重复等待。
## [br]
## @api public
## [br]
## @since unreleased
func wait_disposed() -> void:
	if _disposing and not _disposed:
		await _dispose_completed


## 获取当前仍存活的离树缓存数量。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param scene: 实例来源。
## [br]
## @return: 当前可以借出的实例数量。
func get_available_count(scene: PackedScene) -> int:
	var count: int = 0
	for entry: _Entry in _entries.values():
		if entry._scene == scene and _is_available_entry(entry):
			count += 1
	return count


## 获取当前仍由 Lease 持有使用权的实例数量。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param scene: 实例来源。
## [br]
## @return: ACTIVE 借用数量，不含等待归还的实例。
func get_active_count(scene: PackedScene) -> int:
	var count: int = 0
	for entry: _Entry in _entries.values():
		if entry._scene == scene and entry._lease != null and entry._lease.get_node() != null:
			count += 1
	return count


## 获取不含节点或 Lease 的诊断计数快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return: 按场景身份分组的计数。
## [br]
## @schema return: Dictionary[String, Dictionary]，键为资源路径或场景实例 ID，值含 total、available、active 三个非负整数；等待归还只计入 total。
func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for entry: _Entry in _entries.values():
		if not is_instance_valid(entry._node):
			continue
		var key: String = entry._scene.resource_path
		if key.is_empty():
			key = str(entry._scene.get_instance_id())
		var counts: Dictionary = snapshot.get(key, { "total": 0, "available": 0, "active": 0 })
		counts["total"] += 1
		if _is_available_entry(entry):
			counts["available"] += 1
		if entry._lease != null and entry._lease.get_node() != null:
			counts["active"] += 1
		snapshot[key] = counts
	return snapshot


# --- 框架内部方法 ---

## 在同一个安全点准备并挂载整批实例，交付前失败时淘汰整批候选。
## [br]
## @api framework_internal
## [br]
## @param scene: 整批实例共同使用的来源场景。
## [br]
## @param parent: 本批节点的挂载父节点，必须在运行中的 SceneTree 内。
## [br]
## @param count: 本批借用数量，必须为正数。
## [br]
## @param context: 交给每个根节点 prepare 的本次初始化数据。
## [br]
## @param lifetime_owner: 可选弱引用生命周期锚点；等待期间销毁或 Node 离树会取消未交付请求。
## [br]
## @return: 成功时每个实例一个结果，失败时只含一个失败结果。
## [br]
## @schema context: Dictionary；接纳时深复制嵌套容器，每个候选获得独立容器副本；Object 值保留身份，等待期间应保持只读，不得用它传递所有权回调。
func acquire_batch_for_framework(
	scene: PackedScene,
	parent: Node,
	count: int,
	context: Dictionary = {},
	lifetime_owner: Object = null
) -> Array[GFObjectPoolAcquireResult]:
	var request: _Request = _make_acquire_request(
		scene, parent, count, context, lifetime_owner, false
	)
	lifetime_owner = null
	if request._results.is_empty():
		_enqueue(request)
		await request._completed
	return request._results


## 精确接纳当前 Lease；旧借用不能操作新借用。
## [br]
## @api framework_internal
## [br]
## @param lease: 请求归还的当前借用身份。
## [br]
## @param node_id: 该借用初始化时记录的节点实例 ID。
## [br]
## @return: 首次匹配当前借用并接纳归还时为 true；陈旧、重复或已退休借用为 false。
func release_lease_for_framework(lease: GFObjectPoolLease, node_id: int) -> bool:
	var entry: _Entry = _entries.get(node_id)
	if entry == null or entry._lease != lease or entry._phase != _Phase.LEASED:
		return false
	entry._phase = _Phase.RELEASING
	lease.mark_pending_for_framework()
	var request: _Request = _Request.new()
	request._kind = _Kind.RELEASE
	request._entry = entry
	_enqueue(request)
	return true


# --- 私有/辅助方法 ---

func _make_acquire_request(
	scene: PackedScene,
	parent: Node,
	count: int,
	context: Dictionary,
	lifetime_owner: Object,
	require_owner: bool
) -> _Request:
	var request: _Request = _Request.new()
	var invalid_reason: StringName = &""
	if not Thread.is_main_thread():
		invalid_reason = &"main_thread_required"
	elif not is_instance_valid(scene):
		invalid_reason = &"invalid_scene"
	elif not _valid_parent(parent) or count < 1:
		invalid_reason = &"invalid_parent"
	elif (require_owner or lifetime_owner != null) and not _valid_lifetime_owner(lifetime_owner):
		invalid_reason = &"invalid_owner"
	if invalid_reason != &"":
		request._results = [_failure(GFObjectPoolAcquireResult.Status.INVALID, &"validation", invalid_reason)]
		return request
	if _disposing:
		request._results = [_failure(GFObjectPoolAcquireResult.Status.CANCELLED, &"validation", &"pool_disposed")]
		return request
	request._kind = _Kind.ACQUIRE
	request._scene = scene
	request._parent_ref = weakref(parent)
	request._owner_ref = weakref(lifetime_owner) if is_instance_valid(lifetime_owner) else null
	request._count = count
	request._context = context.duplicate(true)
	request._parent_exit_callback = request._invalidate.bind(&"parent_lost")
	var _parent_connected: Error = parent.tree_exiting.connect(request._parent_exit_callback) as Error
	if lifetime_owner is Node:
		var owner_node: Node = lifetime_owner
		request._owner_exit_callback = request._invalidate.bind(&"owner_lost")
		var _owner_connected: Error = owner_node.tree_exiting.connect(request._owner_exit_callback) as Error
	return request


func _enqueue(request: _Request) -> void:
	_queue.append(request)
	_schedule()


func _schedule() -> void:
	if _scheduled:
		return
	_scheduled = true
	var tree: SceneTree = _tree()
	if (_draining or _notifying) and tree != null:
		var _connected: Error = tree.process_frame.connect(_defer_drain, CONNECT_ONE_SHOT as Object.ConnectFlags) as Error
	else:
		call_deferred(&"_drain")


func _defer_drain() -> void:
	call_deferred(&"_drain")


func _drain() -> void:
	_scheduled = false
	_draining = true
	var current: Array[_Request] = _queue
	var batch_count: int = mini(current.size(), _MAX_REQUESTS_PER_DRAIN)
	# Keep accepted requests ahead of continuations and callback reentry.
	_queue = current.slice(batch_count)
	var completed: Array[_Request] = []
	var settlements: Array[Callable] = []
	for index: int in range(batch_count):
		var request: _Request = current[index]
		match request._kind:
			_Kind.ACQUIRE:
				_acquire_batch(request)
			_Kind.RELEASE:
				_release_entry(request._entry, settlements)
			_Kind.PREWARM:
				_prewarm_batch(request)
			_Kind.DISPOSE:
				for entry: _Entry in _entries.values():
					entry._reason = &"pool_disposed"
					_retire_entry(entry)
					if entry._lease != null:
						settlements.append(_settle_lease.bind(entry._lease, entry._reason))
						entry._lease = null
				_available.clear()
		if request._kind != _Kind.PREWARM or request._prewarm_result != null:
			completed.append(request)
	_draining = false
	_notifying = true
	for settle: Callable in settlements:
		var _settled: Variant = settle.call()
	for request: _Request in completed:
		# Earlier completion listeners may dispose the pool or invalidate later owners.
		if request._kind == _Kind.ACQUIRE and not request._results.is_empty() and request._results[0].is_successful():
			var reason: StringName = _request_failure_reason(request)
			var status: GFObjectPoolAcquireResult.Status = GFObjectPoolAcquireResult.Status.CANCELLED
			if reason == &"":
				for result: GFObjectPoolAcquireResult in request._results:
					var node: Node = result.get_lease().get_node()
					if not is_instance_valid(node) or node.get_parent() != _request_parent(request):
						reason = &"candidate_invalidated"
						status = GFObjectPoolAcquireResult.Status.FAILED
						break
			if reason != &"":
				for result: GFObjectPoolAcquireResult in request._results:
					var node: Node = result.get_lease().get_node()
					if node != null:
						var entry: _Entry = _entries.get(node.get_instance_id())
						if entry != null:
							entry._reason = &"node_lost"
					var _released: bool = result.get_lease().release()
				request._results = [_failure(status, &"complete", reason)]
		_disconnect_request_lifetime(request)
		request._completed.emit()
	_notifying = false
	if _disposing and not _disposed and _queue.is_empty():
		_disposed = true
		_dispose_completed.emit()
	if not _queue.is_empty():
		# A bounded drain must yield a real frame before accepting callback reentry.
		_draining = true
		_schedule()
		_draining = false


func _acquire_batch(request: _Request) -> void:
	var reason: StringName = _request_failure_reason(request)
	if reason != &"":
		request._results = [_failure(GFObjectPoolAcquireResult.Status.CANCELLED, &"validation", reason)]
		return
	var candidates: Array[_Entry] = []
	var stage: StringName = &"allocation"
	for _index: int in range(request._count):
		var entry: _Entry = _take_entry(request._scene)
		if entry == null:
			reason = &"scene_instantiation_failed"
			break
		candidates.append(entry)
		entry._phase = _Phase.ACQUIRING
		reason = _request_failure_reason(request)
		if reason != &"":
			break
		if _live_node(entry) == null or entry._node.get_parent() != null:
			reason = &"candidate_invalidated"
			break
		stage = &"prepare"
		if entry._node.has_method(&"on_gf_pool_prepare"):
			var prepare_result: Variant = entry._node.call(&"on_gf_pool_prepare", request._context.duplicate(true))
			if not prepare_result is int:
				reason = &"invalid_prepare_result"
			elif prepare_result != OK:
				reason = &"prepare_failed"
		var lifetime_reason: StringName = _request_failure_reason(request)
		if lifetime_reason != &"":
			reason = lifetime_reason
		if reason != &"":
			break
		if _live_node(entry) == null or entry._node.get_parent() != null:
			reason = &"candidate_invalidated"
			break
	if reason == &"":
		stage = &"attach"
		for entry: _Entry in candidates:
			var parent: Node = _request_parent(request)
			if _live_node(entry) == null or entry._node.get_parent() != null or parent == null:
				reason = &"candidate_invalidated"
				break
			parent.add_child(entry._node)
			reason = _request_failure_reason(request)
			if reason == &"" and (_live_node(entry) == null or entry._node.get_parent() != parent):
				reason = &"candidate_invalidated"
			if reason != &"":
				break
	if reason == &"":
		for entry: _Entry in candidates:
			if _live_node(entry) == null or entry._node.get_parent() != _request_parent(request):
				reason = &"candidate_invalidated"
				break
	if reason != &"":
		for entry: _Entry in candidates:
			_retire_entry(entry)
		var status: GFObjectPoolAcquireResult.Status = GFObjectPoolAcquireResult.Status.FAILED
		if reason in [&"pool_disposed", &"parent_lost", &"owner_lost"]:
			status = GFObjectPoolAcquireResult.Status.CANCELLED
		request._results = [_failure(status, stage, reason)]
		return
	for entry: _Entry in candidates:
		entry._phase = _Phase.LEASED
		entry._reason = &"released"
		entry._lease = GFObjectPoolLease.new()
		entry._lease.configure_for_framework(self, entry._node)
		entry._exit_callback = _on_root_exiting.bind(entry._id)
		var _connected: Error = entry._node.tree_exiting.connect(entry._exit_callback) as Error
		var result: GFObjectPoolAcquireResult = GFObjectPoolAcquireResult.new()
		result.configure_for_framework(GFObjectPoolAcquireResult.Status.SUCCEEDED, &"complete", &"acquired", entry._lease)
		request._results.append(result)


func _take_entry(scene: PackedScene) -> _Entry:
	var available: Array = _available.get(scene, [])
	while not available.is_empty():
		var value: Variant = available.pop_back()
		if value is _Entry:
			var entry: _Entry = value
			if _is_available_entry(entry):
				return entry
			_retire_entry(entry)
	if not scene.can_instantiate():
		return null
	var node: Node = scene.instantiate()
	if not is_instance_valid(node):
		return null
	var fresh_entry: _Entry = _Entry.new()
	fresh_entry._node = node
	fresh_entry._id = node.get_instance_id()
	fresh_entry._scene = scene
	_entries[fresh_entry._id] = fresh_entry
	return fresh_entry


func _release_entry(entry: _Entry, settlements: Array[Callable]) -> void:
	if entry == null or entry._phase == _Phase.RETIRED:
		return
	_disconnect_exit(entry)
	var node: Node = _live_node(entry)
	if _disposing:
		entry._reason = &"pool_disposed"
	elif node == null or entry._reason == &"node_lost":
		entry._reason = &"node_lost"
	elif max_available_per_scene < 0 or (max_available_per_scene > 0 and get_available_count(entry._scene) >= max_available_per_scene):
		entry._reason = &"capacity_retired"
	if entry._reason != &"released":
		_retire_entry(entry)
	else:
		var parent: Node = node.get_parent()
		if parent != null:
			parent.remove_child(node)
		if _disposing or _live_node(entry) == null or node.get_parent() != null:
			entry._reason = &"pool_disposed" if _disposing else &"node_lost"
			_retire_entry(entry)
		else:
			entry._phase = _Phase.IDLE
			_cache_entry(entry)
	if entry._lease != null:
		settlements.append(_settle_lease.bind(entry._lease, entry._reason))
		entry._lease = null


static func _settle_lease(lease: GFObjectPoolLease, reason: StringName) -> void:
	lease.settle_for_framework(reason)


func _retire_entry(entry: _Entry) -> void:
	entry._phase = _Phase.RETIRED
	_disconnect_exit(entry)
	var _removed: bool = _entries.erase(entry._id)
	if is_instance_valid(entry._node):
		var parent: Node = entry._node.get_parent()
		if parent != null and not GFAutoload.is_tree_exit_in_progress():
			parent.remove_child(entry._node)
		if is_instance_valid(entry._node) and not entry._node.is_queued_for_deletion():
			entry._node.queue_free()


func _cache_entry(entry: _Entry) -> void:
	if not _available.has(entry._scene):
		_available[entry._scene] = []
	_available[entry._scene].append(entry)


func _disconnect_exit(entry: _Entry) -> void:
	if is_instance_valid(entry._node) and entry._exit_callback.is_valid() and entry._node.tree_exiting.is_connected(entry._exit_callback):
		entry._node.tree_exiting.disconnect(entry._exit_callback)
	entry._exit_callback = Callable()


func _prewarm_batch(request: _Request) -> void:
	if _disposing:
		_finish_prewarm(request, GFObjectPoolPrewarmResult.Status.CANCELLED, &"pool_disposed")
		return
	var remaining: int = mini(request._batch_size, request._count - request._created)
	for _index: int in range(remaining):
		if request._token != null and request._token.is_cancel_requested():
			_finish_prewarm(request, GFObjectPoolPrewarmResult.Status.CANCELLED, &"cancelled")
			return
		if max_available_per_scene < 0 or (max_available_per_scene > 0 and get_available_count(request._scene) >= max_available_per_scene):
			_finish_prewarm(request, GFObjectPoolPrewarmResult.Status.PARTIAL, &"capacity_limited")
			return
		if not request._scene.can_instantiate():
			_finish_prewarm(request, GFObjectPoolPrewarmResult.Status.FAILED, &"scene_instantiation_failed")
			return
		var node: Node = request._scene.instantiate()
		if not is_instance_valid(node):
			_finish_prewarm(request, GFObjectPoolPrewarmResult.Status.FAILED, &"scene_instantiation_failed")
			return
		if _disposing or node.is_queued_for_deletion() or node.get_parent() != null:
			node.queue_free()
			var status: GFObjectPoolPrewarmResult.Status = GFObjectPoolPrewarmResult.Status.CANCELLED if _disposing else GFObjectPoolPrewarmResult.Status.FAILED
			var reason: StringName = &"pool_disposed" if _disposing else &"scene_instantiation_failed"
			_finish_prewarm(request, status, reason)
			return
		if request._token != null and request._token.is_cancel_requested():
			node.queue_free()
			_finish_prewarm(request, GFObjectPoolPrewarmResult.Status.CANCELLED, &"cancelled")
			return
		var entry: _Entry = _Entry.new()
		entry._node = node
		entry._id = node.get_instance_id()
		entry._scene = request._scene
		_entries[entry._id] = entry
		_cache_entry(entry)
		request._created += 1
	if request._created == request._count:
		_finish_prewarm(request, GFObjectPoolPrewarmResult.Status.SUCCEEDED, &"prewarmed")
	else:
		_queue.append(request)


func _finish_prewarm(request: _Request, status: GFObjectPoolPrewarmResult.Status, reason: StringName) -> void:
	request._prewarm_result = GFObjectPoolPrewarmResult.new()
	request._prewarm_result.configure_for_framework(status, reason, request._count, request._created)


func _failure(status: GFObjectPoolAcquireResult.Status, stage: StringName, reason: StringName) -> GFObjectPoolAcquireResult:
	var result: GFObjectPoolAcquireResult = GFObjectPoolAcquireResult.new()
	result.configure_for_framework(status, stage, reason)
	return result


func _request_failure_reason(request: _Request) -> StringName:
	if _disposing:
		return &"pool_disposed"
	if request._failure_reason != &"":
		return request._failure_reason
	if _request_parent(request) == null:
		return &"parent_lost"
	if request._owner_ref != null:
		var owner_value: Variant = request._owner_ref.get_ref()
		if not is_instance_valid(owner_value):
			return &"owner_lost"
		if owner_value is Object:
			var owner: Object = owner_value
			if not _valid_lifetime_owner(owner):
				return &"owner_lost"
	return &""


func _disconnect_request_lifetime(request: _Request) -> void:
	_disconnect_request_exit(request._parent_ref, request._parent_exit_callback)
	_disconnect_request_exit(request._owner_ref, request._owner_exit_callback)
	request._parent_exit_callback = Callable()
	request._owner_exit_callback = Callable()


func _disconnect_request_exit(node_ref: WeakRef, callback: Callable) -> void:
	if node_ref == null or not callback.is_valid():
		return
	var value: Variant = node_ref.get_ref()
	if is_instance_valid(value) and value is Node:
		var node: Node = value
		if node.tree_exiting.is_connected(callback):
			node.tree_exiting.disconnect(callback)


func _request_parent(request: _Request) -> Node:
	var value: Variant = request._parent_ref.get_ref()
	if value is Node:
		var node: Node = value
		if _valid_parent(node):
			return node
	return null


func _valid_parent(node: Node) -> bool:
	return is_instance_valid(node) and node.is_inside_tree() and not node.is_queued_for_deletion()


func _valid_lifetime_owner(value: Object) -> bool:
	if not is_instance_valid(value):
		return false
	if value is Node:
		var node: Node = value
		return _valid_parent(node)
	return true


func _is_available_entry(entry: _Entry) -> bool:
	return entry._phase == _Phase.IDLE and _live_node(entry) != null and entry._node.get_parent() == null


func _live_node(entry: _Entry) -> Node:
	return entry._node if is_instance_valid(entry._node) and not entry._node.is_queued_for_deletion() else null


func _tree() -> SceneTree:
	var loop: MainLoop = Engine.get_main_loop()
	return loop if loop is SceneTree else null


# --- 信号处理函数 ---

func _on_root_exiting(entry_id: int) -> void:
	var entry: _Entry = _entries.get(entry_id)
	if entry == null or entry._phase not in [_Phase.LEASED, _Phase.RELEASING]:
		return
	entry._reason = &"node_lost"
	if entry._phase == _Phase.LEASED:
		var _accepted: bool = release_lease_for_framework(entry._lease, entry._id)


# --- 内部类 ---

class _Entry extends RefCounted:
	var _node: Node = null
	var _id: int = 0
	var _scene: PackedScene = null
	var _phase: _Phase = _Phase.IDLE
	var _lease: GFObjectPoolLease = null
	var _reason: StringName = &"released"
	var _exit_callback: Callable = Callable()


class _Request extends RefCounted:
	signal _completed
	var _kind: _Kind = _Kind.ACQUIRE
	var _scene: PackedScene = null
	var _parent_ref: WeakRef = null
	var _owner_ref: WeakRef = null
	var _parent_exit_callback: Callable = Callable()
	var _owner_exit_callback: Callable = Callable()
	var _failure_reason: StringName = &""
	var _count: int = 0
	var _context: Dictionary = {}
	var _batch_size: int = 32
	var _created: int = 0
	var _token: GFCancellationToken = null
	var _entry: _Entry = null
	var _results: Array[GFObjectPoolAcquireResult] = []
	var _prewarm_result: GFObjectPoolPrewarmResult = null


	func _invalidate(reason: StringName) -> void:
		if _failure_reason == &"":
			_failure_reason = reason
