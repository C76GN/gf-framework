## GFAssetSlot: 稳定资源身份下的显式可替换资源槽位。
##
## 槽位强持有当前 Resource，并在成功配置、替换或终态释放后推进单调 generation。
## 它不监听文件变化、不接管 GFAssetUtility 缓存，也不改变 GFAssetHandle 的快照语义。
## 全部公开操作限定在主线程；其他线程上的调用会失败关闭且不改变槽位状态。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 10.0.0
class_name GFAssetSlot
extends RefCounted


# --- 信号 ---

## 当前资源成功替换后发出。
##
## 信号发出前资源与 generation 已经提交；通知期间再次替换或释放会失败关闭。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param previous_resource: 替换前的资源；原先为空时为 null。
## [br]
## @param current_resource: 替换后的资源。
## [br]
## @param generation: 本次提交后的槽位 generation。
signal resource_replaced(previous_resource: Resource, current_resource: Resource, generation: int)

## 槽位进入不可逆释放终态后发出。
##
## 信号发出前资源已经清空、generation 已经推进且 owner 监听已经解除。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param previous_resource: 释放前的资源；原先为空时为 null。
## [br]
## @param generation: 本次提交后的槽位 generation。
signal released(previous_resource: Resource, generation: int)


# --- 私有变量 ---

var _resource_identity: GFResourceIdentity = null
var _resource: Resource = null
var _effective_type_hint: String = ""
var _generation: int = 0
var _configured: bool = false
var _released: bool = false
var _is_notifying: bool = false
var _owner_release_pending: bool = false
var _owner_ref: WeakRef = null
var _owner_id: int = 0
var _owner_exit_callable: Callable = Callable()


# --- 公共方法 ---

## 显式配置 live asset slot。
##
## 每个槽位只允许成功配置一次。资源身份会被复制并固定；type_hint_override
## 非空时覆盖身份中的 type_hint。空类型提示接受任意 Resource，非空类型提示
## 同时支持 Godot 原生类名、脚本 global class_name 与脚本资源路径。
##
## owner 为 Node 时必须已经位于场景树中，退出场景树会自动释放槽位；其他 Object
## 通过弱引用在后续读取活动状态或替换时检测生命周期。owner 不会被槽位强持有。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param resource_identity: 具有稳定 cache_key 的资源身份。
## [br]
## @param initial_resource: 可选初始资源。
## [br]
## @param owner: 可选生命周期 owner。
## [br]
## @param type_hint_override: 可选显式类型提示；为空时使用身份中的 type_hint。
## [br]
## @return 本次是否成功提交配置。
func configure(
	resource_identity: GFResourceIdentity,
	initial_resource: Resource = null,
	owner: Object = null,
	type_hint_override: String = ""
) -> bool:
	if not Thread.is_main_thread() or _configured or _is_notifying:
		return false
	if resource_identity == null or not resource_identity.has_identity():
		return false
	if owner != null and not is_instance_valid(owner):
		return false

	var normalized_type_hint: String = type_hint_override.strip_edges()
	if normalized_type_hint.is_empty():
		normalized_type_hint = resource_identity.type_hint.strip_edges()
	if (
		initial_resource != null
		and not _resource_matches_type_hint(initial_resource, normalized_type_hint)
	):
		return false

	var identity_snapshot: GFResourceIdentity = resource_identity.duplicate_identity()
	var owner_binding: Dictionary = _prepare_owner_binding(owner)
	if not GFVariantData.get_option_bool(owner_binding, "ok", false):
		return false

	_resource_identity = identity_snapshot
	_resource = initial_resource
	_effective_type_hint = normalized_type_hint
	_generation += 1
	_configured = true
	_released = false
	_owner_ref = _get_weak_ref(owner_binding, "owner_ref")
	_owner_id = GFVariantData.get_option_int(owner_binding, "owner_id", 0)
	_owner_exit_callable = _get_callable(owner_binding, "owner_exit_callable")
	return true


## 获取稳定资源身份副本。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## 身份不属于活动资源状态，因此槽位释放后仍可读取。
## [br]
## @return 已配置身份的副本；尚未成功配置时返回 null。
func get_resource_identity() -> GFResourceIdentity:
	if not Thread.is_main_thread():
		return null
	if _resource_identity == null:
		return null
	return _resource_identity.duplicate_identity()


## 获取当前资源。
##
## 若普通 Object owner 已释放，本次访问会先把槽位提交到释放终态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前强引用资源；槽位未配置或已释放时返回 null。
func get_resource() -> Resource:
	if not Thread.is_main_thread():
		return null
	if not _ensure_owner_alive():
		return null
	return _resource if not _released else null


## 获取当前生效的资源类型提示。
##
## 类型提示不属于活动资源状态，因此槽位释放后仍可读取。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 显式覆盖值、身份 type_hint 或空字符串。
func get_type_hint() -> String:
	if not Thread.is_main_thread():
		return ""
	return _effective_type_hint


## 检查槽位是否已经成功配置。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 主线程上返回是否已经成功配置；其他线程返回 false。
func is_configured() -> bool:
	return Thread.is_main_thread() and _configured


## 获取当前单调 generation。
##
## generation 在成功配置、成功替换和首次释放后推进，且只应在同一个槽位内比较。
## 若普通 Object owner 已释放，本次访问会先提交释放。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 当前 generation；新建但未配置的槽位为 0，其他线程返回 -1。
func get_generation() -> int:
	if not Thread.is_main_thread():
		return -1
	var _owner_alive: bool = _ensure_owner_alive()
	return _generation


## 检查槽位当前是否持有资源。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 槽位活动且持有资源时返回 true。
func has_resource() -> bool:
	if not Thread.is_main_thread():
		return false
	if not _ensure_owner_alive():
		return false
	return not _released and _resource != null


## 检查槽位是否已经进入不可逆释放终态。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 成功配置后已进入终态时返回 true；未配置时返回 false，其他线程返回 true。
func is_released() -> bool:
	if not Thread.is_main_thread():
		return true
	var _owner_alive: bool = _ensure_owner_alive()
	return _released


## 检查资源是否满足当前槽位类型契约。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param candidate_resource: 待检查资源。
## [br]
## @return 槽位活动且资源非空、类型兼容时返回 true。
func accepts_resource(candidate_resource: Resource) -> bool:
	if not Thread.is_main_thread():
		return false
	if not _ensure_owner_alive() or _released:
		return false
	return _resource_matches_type_hint(candidate_resource, _effective_type_hint)


## 原子替换当前资源。
##
## 成功时先提交资源和 generation，再同步发出 resource_replaced。相同实例、
## 空资源、类型不兼容、释放终态或通知重入均保持原状态并返回 false。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param next_resource: 新资源实例。
## [br]
## @return 本次是否提交了替换。
func replace(next_resource: Resource) -> bool:
	if (
		not Thread.is_main_thread()
		or not _ensure_owner_alive()
		or _released
		or _is_notifying
		or not _resource_matches_type_hint(next_resource, _effective_type_hint)
		or _resource == next_resource
	):
		return false

	var previous_resource: Resource = _resource
	_resource = next_resource
	_generation += 1
	_is_notifying = true
	resource_replaced.emit(previous_resource, next_resource, _generation)
	_is_notifying = false
	_drain_pending_owner_release()
	return true


## 终态释放槽位持有的资源。
##
## 首次成功释放会清空资源、推进 generation、解除 owner 监听，再同步发出 released。
## 重复释放或通知重入没有副作用。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @return 本次是否首次提交了释放。
func release() -> bool:
	if (
		not Thread.is_main_thread()
		or not _configured
		or _released
		or _is_notifying
	):
		return false
	_commit_release()
	return true


# --- 私有/辅助方法 ---

static func _resource_matches_type_hint(
	candidate_resource: Resource,
	type_hint: String
) -> bool:
	if candidate_resource == null:
		return false
	if type_hint.is_empty() or candidate_resource.is_class(type_hint):
		return true

	var script: Script = _get_script_value(candidate_resource.get_script())
	while script != null:
		if (
			GFVariantData.to_text(script.get_global_name()) == type_hint
			or script.resource_path == type_hint
		):
			return true
		script = script.get_base_script()
	return false


static func _get_script_value(value: Variant) -> Script:
	if value is Script:
		return value
	return null


func _prepare_owner_binding(owner: Object) -> Dictionary:
	if owner == null:
		return {
			"ok": true,
			"owner_ref": null,
			"owner_id": 0,
			"owner_exit_callable": Callable(),
		}

	var prepared_owner_ref: WeakRef = weakref(owner)
	var prepared_owner_exit_callable: Callable = Callable()
	if owner is Node:
		var owner_node: Node = owner
		if not owner_node.is_inside_tree():
			return { "ok": false }
		prepared_owner_exit_callable = Callable(self, &"_on_owner_tree_exited")
		var connect_error: Error = owner_node.tree_exited.connect(
			prepared_owner_exit_callable,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		) as Error
		if connect_error != OK:
			return { "ok": false }

	return {
		"ok": true,
		"owner_ref": prepared_owner_ref,
		"owner_id": owner.get_instance_id(),
		"owner_exit_callable": prepared_owner_exit_callable,
	}


func _ensure_owner_alive() -> bool:
	if not _configured or _released:
		return false
	if _owner_id == 0:
		return true

	var owner: Object = _get_owner()
	if owner != null:
		return true
	if _is_notifying:
		_owner_release_pending = true
		return true
	_commit_release()
	return false


func _get_owner() -> Object:
	if _owner_ref == null:
		return null
	var raw_owner: Variant = _owner_ref.get_ref()
	if raw_owner is Object:
		var owner: Object = raw_owner
		if (
			is_instance_valid(owner)
			and owner.get_instance_id() == _owner_id
		):
			return owner
	return null


func _on_owner_tree_exited() -> void:
	if not _configured or _released:
		return
	if _is_notifying:
		_owner_release_pending = true
		return
	_commit_release()


func _drain_pending_owner_release() -> void:
	if not _owner_release_pending:
		return
	_owner_release_pending = false
	if _configured and not _released:
		_commit_release()


func _commit_release() -> void:
	var previous_resource: Resource = _resource
	_resource = null
	_released = true
	_generation += 1
	_disconnect_owner_binding()
	_is_notifying = true
	released.emit(previous_resource, _generation)
	_is_notifying = false


func _disconnect_owner_binding() -> void:
	var owner: Object = _get_owner()
	if (
		owner is Node
		and _owner_exit_callable.is_valid()
	):
		var owner_node: Node = owner
		if owner_node.tree_exited.is_connected(_owner_exit_callable):
			owner_node.tree_exited.disconnect(_owner_exit_callable)
	_owner_ref = null
	_owner_id = 0
	_owner_exit_callable = Callable()


func _get_weak_ref(data: Dictionary, key: String) -> WeakRef:
	var value: Variant = GFVariantData.get_option_value(data, key)
	if value is WeakRef:
		return value
	return null


func _get_callable(data: Dictionary, key: String) -> Callable:
	var value: Variant = GFVariantData.get_option_value(data, key)
	if value is Callable:
		return value
	return Callable()
