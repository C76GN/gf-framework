## GFRepeaterBinder: 响应式模板重复渲染绑定器。
##
## 将数组数据渲染为容器中的模板副本，也可以订阅 `GFReactiveStateStore`
## 的路径并在数组变化时同步。显式提供 identity_callable 后，同 ID、同模板实例和
## duplicate_flags 的节点会复用，普通 Container 继续负责布局。未提供 ID 时重建副本。
## 具体行结构和交互由项目决定；项目回调主动改写的字段不属于局部状态保留承诺。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFRepeaterBinder
extends RefCounted


# --- 信号 ---

## 活跃绑定的自动 store 刷新失败时发出；失败边界同 sync_container()。
## 初次 bind_repeater() 的失败通过返回值报告。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param container: 仍有效的目标容器。
## [br]
## @param group_key: 失败的克隆组。
## [br]
## @param error: sync_container() 的失败标识。
signal synchronization_failed(container: Node, group_key: StringName, error: StringName)


# --- 常量 ---

## 重复节点标记 meta key。
## [br]
## @api public
## [br]
## @since 7.0.0
const META_CLONE: StringName = &"gf_repeater_clone"

## 重复节点分组 meta key。
## [br]
## @api public
## [br]
## @since 7.0.0
const META_GROUP_KEY: StringName = &"gf_repeater_group_key"

## 重复节点索引 meta key。
## [br]
## @api public
## [br]
## @since 7.0.0
const META_INDEX: StringName = &"gf_repeater_index"

## 重复节点原始条目 meta key。
## [br]
## @api public
## [br]
## @since 7.0.0
const META_ITEM: StringName = &"gf_repeater_item"

const _GF_REACTIVE_STATE_STORE_SCRIPT = preload("res://addons/gf/standard/utilities/state/gf_reactive_state_store.gd")
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")
const _SYNC_SCRIPT = preload("res://addons/gf/standard/utilities/ui/gf_repeater_sync.gd")


# --- 私有变量 ---

var _bindings: Array[Dictionary] = []
var _next_binding_id: int = 1


# --- Godot 生命周期方法 ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		GFRepeaterBinder._disconnect_all_bindings(_bindings)


# --- 公共方法 ---

## 绑定 store 路径到模板重复渲染。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param store: `GFReactiveStateStore` 实例。
## [br]
## @param path: 状态路径，路径值应为 Array。
## [br]
## @param container: 承载重复节点的容器。
## [br]
## @param template: 要复制的模板节点。
## [br]
## @param options: sync_container() 的选项，另支持 sync_initial 和 default_items。
## [br]
## @return 成功绑定时返回 true。
## [br]
## @schema store: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
## [br]
## @schema path: Variant，路径表达。
## [br]
## @schema options: Dictionary，支持 group_key、text_key、clear_existing、hide_template、duplicate_flags、configure_callable、identity_callable、sync_initial: bool 和 default_items: Array；同步边界同 sync_container()。
func bind_repeater(
	store: RefCounted,
	path: Variant,
	container: Node,
	template: Node,
	options: Dictionary = {}
) -> bool:
	var state_store: _GF_REACTIVE_STATE_STORE_SCRIPT = _as_state_store(store)
	if state_store == null:
		push_error("[GFRepeaterBinder] bind_repeater 失败：store 必须是 GFReactiveStateStore。")
		return false
	if not _is_live_node(container):
		push_error("[GFRepeaterBinder] bind_repeater 失败：container 无效。")
		return false
	if not _is_live_node(template):
		push_error("[GFRepeaterBinder] bind_repeater 失败：template 无效。")
		return false

	if not _SYNC_SCRIPT.validate_options(options).is_empty():
		return false
	if _SYNC_SCRIPT.is_busy(container, _get_group_key(options)):
		return false
	var binding_id: int = _next_binding_id
	_next_binding_id += 1
	var path_segments: Array = _GF_REACTIVE_STATE_STORE_SCRIPT.normalize_path(path)
	var binding: Dictionary = {
		"active": true,
		"binding_id": binding_id,
		"store_ref": weakref(state_store),
		"container_ref": weakref(container),
		"template_ref": weakref(template),
		"path_segments": path_segments,
		"path": _GF_REACTIVE_STATE_STORE_SCRIPT.format_path(path_segments),
		"options": options.duplicate(),
		"unsubscribe": Callable(),
		"tree_exited_callable": Callable(),
		"refresh_pending": false,
		"refresh_tree_ref": null,
		"refresh_callable": Callable(),
		"sync_owner": RefCounted.new(),
	}
	_bindings.append(binding)

	var binder_ref: WeakRef = weakref(self)
	var unsubscribe: Callable = state_store.subscribe(
		path_segments,
		func(change: Dictionary, _store: RefCounted) -> void:
			var target: GFRepeaterBinder = GFRepeaterBinder._binder_from_ref(binder_ref)
			if target != null:
				target._apply_store_change_by_id(binding_id, change),
		{
			"mode": _GF_REACTIVE_STATE_STORE_SCRIPT.SUBSCRIBE_EXACT,
			"owner": container,
		}
	)
	if not unsubscribe.is_valid():
		var _removed_unsubscribed_binding: bool = _remove_binding(binding)
		return false
	binding["unsubscribe"] = unsubscribe
	if not _binding_is_active(binding):
		var _unused_subscription: Variant = unsubscribe.call()
		return false

	var tree_exited_callback: Callable = func() -> void:
		var target: GFRepeaterBinder = GFRepeaterBinder._binder_from_ref(binder_ref)
		if target != null:
			target._on_container_tree_exited(binding_id)
	if not container.tree_exited.is_connected(tree_exited_callback):
		var _tree_exited_result: Variant = container.tree_exited.connect(
			tree_exited_callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		)
	binding["tree_exited_callable"] = tree_exited_callback
	if GFVariantData.get_option_bool(options, "sync_initial", true):
		var items: Array = _value_to_items(state_store.get_value(
			path_segments,
			GFVariantData.get_option_value(options, "default_items", []),
			false
		))
		var initial_report: Dictionary = _SYNC_SCRIPT.synchronize(container, template, items, options, _get_sync_owner(binding))
		if not GFVariantData.get_option_bool(initial_report, "ok") or not _binding_is_active(binding):
			var _removed_failed_binding: bool = _remove_binding(binding)
			return false

	for previous: Dictionary in _bindings.duplicate():
		if GFVariantData.get_option_int(previous, "binding_id") == binding_id:
			continue
		if _get_binding_container(previous) == container and _binding_group_key(previous) == _get_group_key(options):
			var _removed_previous_binding: bool = _remove_binding(previous)
	return _binding_is_active(binding)


## 直接重建容器中的模板副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param container: 承载重复节点的容器。
## [br]
## @param template: 要复制的模板节点。
## [br]
## @param items: 条目数组。
## [br]
## @param options: 可选项，字段同 bind_repeater()。
## [br]
## @return 本次顺序的节点数组，包含复用节点；失败返回空数组。详细结果使用 sync_container()。
## [br]
## @schema items: Array，重复渲染的数据条目。
## [br]
## @schema options: Dictionary，字段及稳定 ID 同 sync_container()。
func rebuild_target(container: Node, template: Node, items: Array, options: Dictionary = {}) -> Array[Node]:
	return rebuild_container(container, template, items, options)


## 解绑指定容器，并中断本实例绑定驱动的同步；已经显示的节点保留。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param container: 目标容器。
## [br]
## @param options: 可选项，支持 group_key。
## [br]
## @return 找到并解绑时返回 true。
## [br]
## @schema options: Dictionary，包含可选 group_key。
func unbind_container(container: Node, options: Dictionary = {}) -> bool:
	if container == null:
		return false

	var group_key: StringName = _get_group_key(options)
	var removed: bool = false
	for binding: Dictionary in _bindings.duplicate():
		if _get_binding_container(binding) == container and _binding_group_key(binding) == group_key:
			removed = _remove_binding(binding) or removed
	return removed


## 解绑指定 store 路径上的所有重复渲染。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param store: `GFReactiveStateStore` 实例。
## [br]
## @param path: 状态路径。
## [br]
## @return 解绑数量。
## [br]
## @schema store: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
## [br]
## @schema path: Variant，路径表达。
func unbind_path(store: RefCounted, path: Variant) -> int:
	var state_store: _GF_REACTIVE_STATE_STORE_SCRIPT = _as_state_store(store)
	var path_text: String = _GF_REACTIVE_STATE_STORE_SCRIPT.format_path(path)
	var removed_count: int = 0
	for binding: Dictionary in _bindings.duplicate():
		if _get_binding_store(binding) == state_store and GFVariantData.get_option_string(binding, "path") == path_text:
			if _remove_binding(binding):
				removed_count += 1
	return removed_count


## 清理本实例所有绑定并中断它们驱动的同步；已显示节点仍由容器持有。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	_disconnect_all_bindings(_bindings)


## 获取当前有效绑定数量。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @return 有效绑定数量。
func get_binding_count() -> int:
	_prune_invalid_bindings()
	return _bindings.size()


## 释放所有绑定。
## [br]
## @api public
## [br]
## @since 7.0.0
func dispose() -> void:
	clear()


## 同步容器中的模板副本；它是 sync_container() 的节点数组便捷入口。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param container: 承载重复节点的容器。
## [br]
## @param template: 要复制的模板节点。
## [br]
## @param items: 条目数组。
## [br]
## @param options: 可选项，字段及稳定 ID 合同同 sync_container()。
## [br]
## @return 本次顺序的节点数组，包含复用节点；失败返回空数组。
## [br]
## @schema items: Array，重复渲染的数据条目。
## [br]
## @schema options: Dictionary，字段同 sync_container()。
static func rebuild_container(
	container: Node,
	template: Node,
	items: Array,
	options: Dictionary = {}
) -> Array[Node]:
	var report: Dictionary = sync_container(container, template, items, options)
	return _report_nodes(report)


## 同步容器中的模板副本，并报告节点身份的变化。
## 每次最多 4096 项；稳定 key token 最多 4096 UTF-8 字节。ID 回调在结构修改前
## 全量执行并校验；String 与 StringName 按 codec 分别作为不同身份。未提供 ID 时
## 保留重建语义；提供 ID 时 clear_existing 必须为 true。只管理当前克隆组。
## 新增、移动或数据变化的条目才配置。有限纯值 Array/Dictionary 保存独立比较快照；
## 包含 Object/Callable/Signal/RID、循环或超出比较预算的条目保留项目引用并每次配置，
## 不深复制此类数据，也不推断对象内部变化。复制已同步容器会隔离组状态，首次同步重建复制行。
## 同组嵌套同步返回 busy；clear_clones、解绑和离树中断后续工作。项目回调副作用
## 不会回滚。不要在回调中释放/移走正在配置的节点；此类中断返回空 nodes。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param container: 承载当前克隆组的容器。
## [br]
## @param template: 克隆模板；同一模板实例与 duplicate_flags 才能复用节点。
## [br]
## @param items: 本次完整条目数组。
## [br]
## @param options: 模板选项；identity_callable 可显式提供稳定 ID。
## [br]
## @return 同步报告。
## [br]
## @schema items: Array，项目提供的数据条目。
## [br]
## @schema options: Dictionary，包含 group_key: String/StringName、text_key: String/StringName、hide_template: bool、duplicate_flags: int (0..15)、configure_callable: Callable(Node, Variant, int) -> void、clear_existing: bool 和 identity_callable: Callable(Variant, int) -> stable Variant key；允许 bind_repeater 使用的 sync_initial/default_items，拒绝未知键。
## [br]
## @schema return: Dictionary，包含 ok: bool、error: StringName、nodes: Array[Node]、created_count: int、reused_count: int、removed_count: int；error 为空或 invalid_target、invalid_options、item_limit、invalid_identity、duplicate_identity、busy、interrupted、duplicate_failed。失败的 nodes 为空，计数只在成功时提供。
static func sync_container(
	container: Node,
	template: Node,
	items: Array,
	options: Dictionary = {}
) -> Dictionary:
	return _SYNC_SCRIPT.synchronize(container, template, items, options)


## 清理容器中由 GFRepeaterBinder 创建的副本。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param container: 目标容器。
## [br]
## @param options: 可选项，支持 group_key。
## [br]
## @return 清理的节点数量。
## [br]
## @schema options: Dictionary，包含可选 group_key。
static func clear_clones(container: Node, options: Dictionary = {}) -> int:
	return _SYNC_SCRIPT.clear_clones(container, _get_group_key(options))


# --- 私有/辅助方法 ---

func _apply_store_change_to_container(binding: Dictionary, change: Dictionary) -> void:
	if not _binding_is_active(binding):
		return
	var container: Node = _get_binding_container(binding)
	var template: Node = _get_binding_template(binding)
	if container == null or template == null:
		var _removed_invalid_binding: bool = _remove_binding(binding)
		return

	var options: Dictionary = GFVariantData.get_option_dictionary(binding, "options")
	if _SYNC_SCRIPT.is_busy(container, _get_group_key(options)):
		_queue_binding_refresh(binding)
		return
	var value: Variant = GFVariantData.get_option_value(
		change,
		"new_value",
		GFVariantData.get_option_value(options, "default_items", [])
	)
	if not GFVariantData.get_option_bool(change, "new_exists", true):
		value = GFVariantData.get_option_value(options, "default_items", [])
	var report: Dictionary = _SYNC_SCRIPT.synchronize(container, template, _value_to_items(value), options, _get_sync_owner(binding))
	if not GFVariantData.get_option_bool(report, "ok") and _binding_is_active(binding):
		synchronization_failed.emit(container, _get_group_key(options), GFVariantData.get_option_string_name(report, "error"))


func _remove_binding(binding: Dictionary) -> bool:
	var binding_id: int = GFVariantData.get_option_int(binding, "binding_id", -1)
	if binding_id == -1:
		return false

	for index: int in range(_bindings.size() - 1, -1, -1):
		if GFVariantData.get_option_int(_bindings[index], "binding_id", -1) == binding_id:
			_bindings.remove_at(index)
			_disconnect_binding(binding)
			return true
	return false


static func _disconnect_all_bindings(bindings: Array[Dictionary]) -> void:
	var previous_bindings: Array[Dictionary] = bindings.duplicate()
	bindings.clear()
	for binding: Dictionary in previous_bindings:
		_disconnect_binding(binding)


static func _disconnect_binding(binding: Dictionary) -> void:
	binding["active"] = false
	binding["refresh_pending"] = false
	_disconnect_pending_refresh(binding)
	var container: Node = _get_binding_container(binding)
	_SYNC_SCRIPT.interrupt(container, _binding_group_key(binding), _get_sync_owner(binding))
	var unsubscribe: Callable = _get_binding_callable(binding, "unsubscribe")
	if unsubscribe.is_valid():
		var _unsubscribe_result: Variant = unsubscribe.call()

	var tree_exited_callable: Callable = _get_binding_callable(binding, "tree_exited_callable")
	if (
		container != null
		and tree_exited_callable.is_valid()
		and container.tree_exited.is_connected(tree_exited_callable)
	):
		container.tree_exited.disconnect(tree_exited_callable)


static func _get_binding_store(binding: Dictionary) -> _GF_REACTIVE_STATE_STORE_SCRIPT:
	var store_ref: WeakRef = _get_binding_weak_ref(binding, "store_ref")
	var raw_store: Object = _INSTANCE_GUARD._get_live_object_from_ref(store_ref)
	if raw_store is _GF_REACTIVE_STATE_STORE_SCRIPT:
		var store: _GF_REACTIVE_STATE_STORE_SCRIPT = raw_store
		return store
	return null


static func _as_state_store(store: RefCounted) -> _GF_REACTIVE_STATE_STORE_SCRIPT:
	if store is _GF_REACTIVE_STATE_STORE_SCRIPT:
		var state_store: _GF_REACTIVE_STATE_STORE_SCRIPT = store
		return state_store
	return null


static func _get_binding_container(binding: Dictionary) -> Node:
	var container_ref: WeakRef = _get_binding_weak_ref(binding, "container_ref")
	var raw_container: Object = _INSTANCE_GUARD._get_live_object_from_ref(container_ref)
	if raw_container is Node:
		var container: Node = raw_container
		return container if _is_live_node(container) else null
	return null


static func _get_binding_template(binding: Dictionary) -> Node:
	var template_ref: WeakRef = _get_binding_weak_ref(binding, "template_ref")
	var raw_template: Object = _INSTANCE_GUARD._get_live_object_from_ref(template_ref)
	if raw_template is Node:
		var template: Node = raw_template
		return template if _is_live_node(template) else null
	return null


static func _get_binding_weak_ref(binding: Dictionary, key: String) -> WeakRef:
	var value: Variant = GFVariantData.get_option_value(binding, key)
	if value is WeakRef:
		var weak_ref: WeakRef = value
		return weak_ref
	return null


static func _get_binding_callable(binding: Dictionary, key: String) -> Callable:
	var value: Variant = GFVariantData.get_option_value(binding, key, Callable())
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


static func _binding_group_key(binding: Dictionary) -> StringName:
	return _get_group_key(GFVariantData.get_option_dictionary(binding, "options"))


func _prune_invalid_bindings() -> void:
	for binding: Dictionary in _bindings.duplicate():
		if _get_binding_store(binding) == null or _get_binding_container(binding) == null or _get_binding_template(binding) == null:
			var _removed_invalid: bool = _remove_binding(binding)


func _on_container_tree_exited(binding_id: int) -> void:
	for index: int in range(_bindings.size() - 1, -1, -1):
		if GFVariantData.get_option_int(_bindings[index], "binding_id", -1) == binding_id:
			var _removed_exited_binding: bool = _remove_binding(_bindings[index])
			return


static func _value_to_items(value: Variant) -> Array:
	if value is Array:
		var items: Array = value
		return items
	return []


func _binding_is_active(binding: Dictionary) -> bool:
	return (
		GFVariantData.get_option_bool(binding, "active")
		and _get_binding_container(binding) != null
		and _get_binding_template(binding) != null
		and _get_binding_store(binding) != null
	)


func _apply_store_change_by_id(binding_id: int, change: Dictionary) -> void:
	for binding: Dictionary in _bindings:
		if GFVariantData.get_option_int(binding, "binding_id") == binding_id:
			_apply_store_change_to_container(binding, change)
			return


func _flush_binding(binding_id: int) -> void:
	for binding: Dictionary in _bindings:
		if GFVariantData.get_option_int(binding, "binding_id") != binding_id:
			continue
		binding["refresh_pending"] = false
		binding["refresh_tree_ref"] = null
		binding["refresh_callable"] = Callable()
		var state_store: _GF_REACTIVE_STATE_STORE_SCRIPT = _get_binding_store(binding)
		if state_store != null:
			var options: Dictionary = GFVariantData.get_option_dictionary(binding, "options")
			_apply_store_change_to_container(binding, {
				"new_exists": true,
				"new_value": state_store.get_value(
					GFVariantData.get_option_value(binding, "path_segments"),
					GFVariantData.get_option_value(options, "default_items", []),
					false
				),
			})
		return


func _queue_binding_refresh(binding: Dictionary) -> void:
	if GFVariantData.get_option_bool(binding, "refresh_pending"):
		return
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		return
	var scene_tree: SceneTree = main_loop
	var binder_ref: WeakRef = weakref(self)
	var binding_id: int = GFVariantData.get_option_int(binding, "binding_id")
	var callback: Callable = func() -> void:
		var target: GFRepeaterBinder = GFRepeaterBinder._binder_from_ref(binder_ref)
		if target != null:
			target._flush_binding(binding_id)
	binding["refresh_pending"] = true
	binding["refresh_tree_ref"] = weakref(scene_tree)
	binding["refresh_callable"] = callback
	var _connected: int = scene_tree.process_frame.connect(callback, CONNECT_ONE_SHOT as Object.ConnectFlags)


static func _disconnect_pending_refresh(binding: Dictionary) -> void:
	var tree_ref: WeakRef = _get_binding_weak_ref(binding, "refresh_tree_ref")
	var tree_object: Object = _INSTANCE_GUARD._get_live_object_from_ref(tree_ref)
	var callback: Callable = _get_binding_callable(binding, "refresh_callable")
	if tree_object is SceneTree:
		var scene_tree: SceneTree = tree_object
		if callback.is_valid() and scene_tree.process_frame.is_connected(callback):
			scene_tree.process_frame.disconnect(callback)
	binding["refresh_tree_ref"] = null
	binding["refresh_callable"] = Callable()


static func _get_sync_owner(binding: Dictionary) -> RefCounted:
	var value: Variant = binding.get("sync_owner")
	if value is RefCounted:
		var owner: RefCounted = value
		return owner
	return null


static func _binder_from_ref(binder_ref: WeakRef) -> GFRepeaterBinder:
	var candidate: Variant = binder_ref.get_ref()
	if candidate is GFRepeaterBinder:
		var binder: GFRepeaterBinder = candidate
		return binder
	return null


static func _is_live_node(node: Node) -> bool:
	return is_instance_valid(node) and not node.is_queued_for_deletion()


static func _report_nodes(report: Dictionary) -> Array[Node]:
	var nodes: Array[Node] = []
	var value: Variant = report.get("nodes")
	if value is Array:
		var raw_nodes: Array = value
		for candidate: Variant in raw_nodes:
			if candidate is Node:
				var node: Node = candidate
				if _is_live_node(node):
					nodes.append(node)
	return nodes


static func _get_group_key(options: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(options, "group_key", &"default")
