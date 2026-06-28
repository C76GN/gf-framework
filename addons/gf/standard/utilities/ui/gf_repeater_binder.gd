## GFRepeaterBinder: 响应式模板重复渲染绑定器。
##
## 将数组数据渲染为容器中的模板副本，也可以订阅 `GFReactiveStateStore`
## 的路径并在数组变化时重建。它只负责模板复制、生命周期清理和通用文本写入，
## 具体行控件结构和业务交互由项目节点或 configure_callable 决定。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFRepeaterBinder
extends RefCounted


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
const _DEFAULT_DUPLICATE_FLAGS: int = 15


# --- 私有变量 ---

var _bindings: Array[Dictionary] = []
var _next_binding_id: int = 1


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
## @param options: 可选项。支持 group_key、text_key、clear_existing、hide_template、duplicate_flags、configure_callable、sync_initial 和 default_items。
## [br]
## @return 成功绑定时返回 true。
## [br]
## @schema store: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
## [br]
## @schema path: Variant，路径表达。
## [br]
## @schema options: Dictionary，模板复制和字段映射选项。
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
	if not is_instance_valid(container):
		push_error("[GFRepeaterBinder] bind_repeater 失败：container 无效。")
		return false
	if not is_instance_valid(template):
		push_error("[GFRepeaterBinder] bind_repeater 失败：template 无效。")
		return false

	var _previous_binding_removed: bool = unbind_container(container, options)
	var binding_id: int = _next_binding_id
	_next_binding_id += 1
	var path_segments: Array = _GF_REACTIVE_STATE_STORE_SCRIPT.normalize_path(path)
	var binding: Dictionary = {
		"binding_id": binding_id,
		"store_ref": weakref(state_store),
		"container_ref": weakref(container),
		"template_ref": weakref(template),
		"path_segments": path_segments,
		"path": _GF_REACTIVE_STATE_STORE_SCRIPT.format_path(path_segments),
		"options": options.duplicate(true),
		"unsubscribe": Callable(),
		"tree_exited_callable": Callable(),
	}

	if GFVariantData.get_option_bool(options, "sync_initial", true):
		var items: Array = _value_to_items(state_store.get_value(
			path_segments,
			GFVariantData.get_option_value(options, "default_items", [])
		))
		var _initial_nodes: Array[Node] = rebuild_container(container, template, items, options)

	var unsubscribe: Callable = state_store.subscribe(
		path_segments,
		func(change: Dictionary, _store: RefCounted) -> void:
			_apply_store_change_to_container(binding, change),
		{
			"mode": _GF_REACTIVE_STATE_STORE_SCRIPT.SUBSCRIBE_EXACT,
			"owner": container,
		}
	)
	if not unsubscribe.is_valid():
		return false
	binding["unsubscribe"] = unsubscribe

	var tree_exited_callback: Callable = Callable(self, "_on_container_tree_exited").bind(binding_id)
	if not container.tree_exited.is_connected(tree_exited_callback):
		var _tree_exited_result: Variant = container.tree_exited.connect(
			tree_exited_callback,
			CONNECT_ONE_SHOT as Object.ConnectFlags
		)
	binding["tree_exited_callable"] = tree_exited_callback

	_bindings.append(binding)
	return true


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
## @return 新建的节点数组。
## [br]
## @schema items: Array，重复渲染的数据条目。
## [br]
## @schema options: Dictionary，模板复制和字段映射选项。
func rebuild_target(container: Node, template: Node, items: Array, options: Dictionary = {}) -> Array[Node]:
	return rebuild_container(container, template, items, options)


## 解绑指定容器。
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
	for index: int in range(_bindings.size() - 1, -1, -1):
		var binding: Dictionary = _bindings[index]
		if _get_binding_container(binding) == container and _binding_group_key(binding) == group_key:
			_disconnect_binding(binding)
			_bindings.remove_at(index)
			removed = true
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
	for index: int in range(_bindings.size() - 1, -1, -1):
		var binding: Dictionary = _bindings[index]
		if _get_binding_store(binding) == state_store and GFVariantData.get_option_string(binding, "path") == path_text:
			_disconnect_binding(binding)
			_bindings.remove_at(index)
			removed_count += 1
	return removed_count


## 清理所有绑定。
## [br]
## @api public
## [br]
## @since 7.0.0
func clear() -> void:
	for binding: Dictionary in _bindings:
		_disconnect_binding(binding)
	_bindings.clear()


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


## 重建容器中的模板副本。
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
## @param options: 可选项。支持 group_key、text_key、clear_existing、hide_template、duplicate_flags 和 configure_callable。
## [br]
## @return 新建的节点数组。
## [br]
## @schema items: Array，重复渲染的数据条目。
## [br]
## @schema options: Dictionary，模板复制和字段映射选项。
static func rebuild_container(
	container: Node,
	template: Node,
	items: Array,
	options: Dictionary = {}
) -> Array[Node]:
	var created_nodes: Array[Node] = []
	if not is_instance_valid(container) or not is_instance_valid(template):
		return created_nodes

	if GFVariantData.get_option_bool(options, "clear_existing", true):
		var _cleared_count: int = clear_clones(container, options)
	if GFVariantData.get_option_bool(options, "hide_template", true) and template is CanvasItem:
		var template_canvas_item: CanvasItem = template
		template_canvas_item.visible = false

	var duplicate_flags: int = GFVariantData.get_option_int(options, "duplicate_flags", _DEFAULT_DUPLICATE_FLAGS)
	var group_key: StringName = _get_group_key(options)
	for index: int in range(items.size()):
		var clone: Node = template.duplicate(duplicate_flags)
		if clone == null:
			continue
		clone.set_meta(META_CLONE, true)
		clone.set_meta(META_GROUP_KEY, group_key)
		clone.set_meta(META_INDEX, index)
		clone.set_meta(META_ITEM, GFVariantData.duplicate_variant(items[index]))
		container.add_child(clone)
		if clone is CanvasItem:
			var clone_canvas_item: CanvasItem = clone
			clone_canvas_item.visible = true
		_apply_item_to_node(clone, items[index], index, options)
		created_nodes.append(clone)
	return created_nodes


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
	if not is_instance_valid(container):
		return 0

	var group_key: StringName = _get_group_key(options)
	var removed_count: int = 0
	for index: int in range(container.get_child_count() - 1, -1, -1):
		var child: Node = container.get_child(index)
		if not _is_repeater_clone(child, group_key):
			continue
		container.remove_child(child)
		child.queue_free()
		removed_count += 1
	return removed_count


# --- 私有/辅助方法 ---

func _apply_store_change_to_container(binding: Dictionary, change: Dictionary) -> void:
	var container: Node = _get_binding_container(binding)
	var template: Node = _get_binding_template(binding)
	if container == null or template == null:
		var _removed_invalid_binding: bool = _remove_binding(binding)
		return

	var options: Dictionary = GFVariantData.get_option_dictionary(binding, "options")
	var value: Variant = GFVariantData.get_option_value(
		change,
		"new_value",
		GFVariantData.get_option_value(options, "default_items", [])
	)
	if not GFVariantData.get_option_bool(change, "new_exists", true):
		value = GFVariantData.get_option_value(options, "default_items", [])
	var _created_nodes: Array[Node] = rebuild_container(container, template, _value_to_items(value), options)


func _remove_binding(binding: Dictionary) -> bool:
	var binding_id: int = GFVariantData.get_option_int(binding, "binding_id", -1)
	if binding_id == -1:
		return false

	for index: int in range(_bindings.size() - 1, -1, -1):
		if GFVariantData.get_option_int(_bindings[index], "binding_id", -1) == binding_id:
			_disconnect_binding(_bindings[index])
			_bindings.remove_at(index)
			return true
	return false


func _disconnect_binding(binding: Dictionary) -> void:
	var unsubscribe: Callable = _get_binding_callable(binding, "unsubscribe")
	if unsubscribe.is_valid():
		var _unsubscribe_result: Variant = unsubscribe.call()

	var container: Node = _get_binding_container(binding)
	var tree_exited_callable: Callable = _get_binding_callable(binding, "tree_exited_callable")
	if (
		container != null
		and tree_exited_callable.is_valid()
		and container.tree_exited.is_connected(tree_exited_callable)
	):
		container.tree_exited.disconnect(tree_exited_callable)


func _get_binding_store(binding: Dictionary) -> _GF_REACTIVE_STATE_STORE_SCRIPT:
	var store_ref: WeakRef = _get_binding_weak_ref(binding, "store_ref")
	var raw_store: Object = _INSTANCE_GUARD._get_live_object_from_ref(store_ref)
	if raw_store is _GF_REACTIVE_STATE_STORE_SCRIPT:
		var store: _GF_REACTIVE_STATE_STORE_SCRIPT = raw_store
		return store
	return null


func _as_state_store(store: RefCounted) -> _GF_REACTIVE_STATE_STORE_SCRIPT:
	if store is _GF_REACTIVE_STATE_STORE_SCRIPT:
		var state_store: _GF_REACTIVE_STATE_STORE_SCRIPT = store
		return state_store
	return null


func _get_binding_container(binding: Dictionary) -> Node:
	var container_ref: WeakRef = _get_binding_weak_ref(binding, "container_ref")
	var raw_container: Object = _INSTANCE_GUARD._get_live_object_from_ref(container_ref)
	if raw_container is Node:
		var container: Node = raw_container
		return container
	return null


func _get_binding_template(binding: Dictionary) -> Node:
	var template_ref: WeakRef = _get_binding_weak_ref(binding, "template_ref")
	var raw_template: Object = _INSTANCE_GUARD._get_live_object_from_ref(template_ref)
	if raw_template is Node:
		var template: Node = raw_template
		return template
	return null


func _get_binding_weak_ref(binding: Dictionary, key: String) -> WeakRef:
	var value: Variant = GFVariantData.get_option_value(binding, key)
	if value is WeakRef:
		var weak_ref: WeakRef = value
		return weak_ref
	return null


func _get_binding_callable(binding: Dictionary, key: String) -> Callable:
	var value: Variant = GFVariantData.get_option_value(binding, key, Callable())
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _binding_group_key(binding: Dictionary) -> StringName:
	return _get_group_key(GFVariantData.get_option_dictionary(binding, "options"))


func _prune_invalid_bindings() -> void:
	for index: int in range(_bindings.size() - 1, -1, -1):
		var binding: Dictionary = _bindings[index]
		if _get_binding_store(binding) == null or _get_binding_container(binding) == null or _get_binding_template(binding) == null:
			_disconnect_binding(binding)
			_bindings.remove_at(index)


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


static func _apply_item_to_node(node: Node, item: Variant, index: int, options: Dictionary) -> void:
	var text: String = _get_item_text(item, options)
	if node.has_method("set_repeater_item"):
		var _configure_result: Variant = node.call("set_repeater_item", item, index)
	elif "text" in node:
		node.set("text", text)

	var configure_callable: Callable = _get_configure_callable(options)
	if configure_callable.is_valid():
		var _call_result: Variant = configure_callable.call(node, item, index)


static func _get_item_text(item: Variant, options: Dictionary) -> String:
	if item is Dictionary:
		var source: Dictionary = GFVariantData.as_dictionary(item)
		var text_key: StringName = GFVariantData.get_option_string_name(options, "text_key", &"text")
		var text: String = GFVariantData.get_option_string(source, text_key)
		if not text.is_empty():
			return text
		for fallback_key: StringName in [&"label", &"name", &"id"]:
			text = GFVariantData.get_option_string(source, fallback_key)
			if not text.is_empty():
				return text
	return GFVariantData.to_text(item)


static func _get_configure_callable(options: Dictionary) -> Callable:
	var value: Variant = GFVariantData.get_option_value(options, "configure_callable", Callable())
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


static func _get_group_key(options: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(options, "group_key", &"default")


static func _is_repeater_clone(node: Node, group_key: StringName) -> bool:
	if node == null or not node.has_meta(META_CLONE):
		return false
	if not GFVariantData.to_bool(node.get_meta(META_CLONE)):
		return false
	return GFVariantData.to_string_name(node.get_meta(META_GROUP_KEY, &"default")) == group_key
