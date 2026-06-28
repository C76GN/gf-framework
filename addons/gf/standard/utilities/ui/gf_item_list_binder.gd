## GFItemListBinder: 响应式条目控件绑定器。
##
## 将数组数据写入 `ItemList`、`OptionButton` 或 `PopupMenu`，也可以订阅
## `GFReactiveStateStore` 的路径并在数组变化时刷新目标控件。它只负责条目展示、
## metadata 和选择状态同步，不定义业务字段含义。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 7.0.0
class_name GFItemListBinder
extends RefCounted


# --- 常量 ---

const _GF_REACTIVE_STATE_STORE_SCRIPT = preload("res://addons/gf/standard/utilities/state/gf_reactive_state_store.gd")
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 私有变量 ---

var _bindings: Array[Dictionary] = []
var _next_binding_id: int = 1


# --- 公共方法 ---

## 绑定 store 路径到条目控件。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param store: `GFReactiveStateStore` 实例。
## [br]
## @param path: 状态路径，路径值应为 Array。
## [br]
## @param target: `ItemList`、`OptionButton` 或 `PopupMenu`。
## [br]
## @param options: 可选映射项。支持 text_key、id_key、metadata_key、icon_key、disabled_key、selectable_key、tooltip_key、selected_key、clear、sync_initial 和 default_items。
## [br]
## @return 成功绑定时返回 true。
## [br]
## @schema store: GFReactiveStateStore 实例；签名使用 RefCounted 以避免新全局类注册顺序影响脚本解析。
## [br]
## @schema path: Variant，路径表达。
## [br]
## @schema options: Dictionary，键名映射与初始同步选项。
func bind_items(
	store: RefCounted,
	path: Variant,
	target: Object,
	options: Dictionary = {}
) -> bool:
	var state_store: _GF_REACTIVE_STATE_STORE_SCRIPT = _as_state_store(store)
	if state_store == null:
		push_error("[GFItemListBinder] bind_items 失败：store 必须是 GFReactiveStateStore。")
		return false
	if not _is_supported_target(target):
		push_error("[GFItemListBinder] bind_items 失败：target 必须是 ItemList、OptionButton 或 PopupMenu。")
		return false

	var _previous_binding_removed: bool = unbind_target(target)
	var binding_id: int = _next_binding_id
	_next_binding_id += 1
	var path_segments: Array = _GF_REACTIVE_STATE_STORE_SCRIPT.normalize_path(path)
	var binding: Dictionary = {
		"binding_id": binding_id,
		"store_ref": weakref(state_store),
		"target_ref": weakref(target),
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
		var _initial_count: int = write_items(target, items, options)

	var unsubscribe: Callable = state_store.subscribe(
		path_segments,
		func(change: Dictionary, _store: RefCounted) -> void:
			_apply_store_change_to_target(binding, change),
		{
			"mode": _GF_REACTIVE_STATE_STORE_SCRIPT.SUBSCRIBE_EXACT,
			"owner": target,
		}
	)
	if not unsubscribe.is_valid():
		return false
	binding["unsubscribe"] = unsubscribe

	if target is Node:
		var target_node: Node = target
		var tree_exited_callback: Callable = Callable(self, "_on_target_tree_exited").bind(binding_id)
		if not target_node.tree_exited.is_connected(tree_exited_callback):
			var _tree_exited_result: Variant = target_node.tree_exited.connect(
				tree_exited_callback,
				CONNECT_ONE_SHOT as Object.ConnectFlags
			)
		binding["tree_exited_callable"] = tree_exited_callback

	_bindings.append(binding)
	return true


## 直接写入目标控件条目。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target: `ItemList`、`OptionButton` 或 `PopupMenu`。
## [br]
## @param items: 条目数组。元素可为 Dictionary 或标量值。
## [br]
## @param options: 可选映射项，字段同 bind_items()。
## [br]
## @return 实际写入条目数。
## [br]
## @schema items: Array，元素为 Dictionary 或标量值。
## [br]
## @schema options: Dictionary，键名映射与 clear 选项。
func write_target_items(target: Object, items: Array, options: Dictionary = {}) -> int:
	return write_items(target, items, options)


## 解绑指定目标控件。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target: 目标控件。
## [br]
## @return 找到并解绑时返回 true。
func unbind_target(target: Object) -> bool:
	if target == null:
		return false

	var removed: bool = false
	for index: int in range(_bindings.size() - 1, -1, -1):
		var binding: Dictionary = _bindings[index]
		if _get_binding_target(binding) == target:
			_disconnect_binding(binding)
			_bindings.remove_at(index)
			removed = true
	return removed


## 解绑指定 store 路径上的所有目标控件。
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


## 将数组数据写入条目控件。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target: `ItemList`、`OptionButton` 或 `PopupMenu`。
## [br]
## @param items: 条目数组。元素可为 Dictionary 或标量值。
## [br]
## @param options: 可选映射项。支持 text_key、id_key、metadata_key、icon_key、disabled_key、selectable_key、tooltip_key、selected_key 和 clear。
## [br]
## @return 实际写入条目数。
## [br]
## @schema items: Array，元素为 Dictionary 或标量值。
## [br]
## @schema options: Dictionary，键名映射与 clear 选项。
static func write_items(target: Object, items: Array, options: Dictionary = {}) -> int:
	if not _is_supported_target(target):
		return 0

	var normalized_items: Array[Dictionary] = _normalize_items(items, options)
	if target is ItemList:
		var item_list: ItemList = target
		return _write_item_list(item_list, normalized_items, options)
	if target is OptionButton:
		var option_button: OptionButton = target
		return _write_option_button(option_button, normalized_items, options)
	if target is PopupMenu:
		var popup_menu: PopupMenu = target
		return _write_popup_menu(popup_menu, normalized_items, options)
	return 0


## 读取控件指定索引的 metadata。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target: `ItemList`、`OptionButton` 或 `PopupMenu`。
## [br]
## @param index: 条目索引。
## [br]
## @param fallback: 索引无效时返回的值。
## [br]
## @return 条目 metadata 或 fallback。
## [br]
## @schema fallback: Variant fallback value.
## [br]
## @schema return: Variant item metadata or fallback.
static func get_item_metadata(target: Object, index: int, fallback: Variant = null) -> Variant:
	if index < 0:
		return fallback
	if target is ItemList:
		var item_list: ItemList = target
		if index >= item_list.item_count:
			return fallback
		return item_list.get_item_metadata(index)
	if target is OptionButton:
		var option_button: OptionButton = target
		if index >= option_button.item_count:
			return fallback
		return option_button.get_item_metadata(index)
	if target is PopupMenu:
		var popup_menu: PopupMenu = target
		if index >= popup_menu.get_item_count():
			return fallback
		return popup_menu.get_item_metadata(index)
	return fallback


## 读取当前选中条目的 metadata。
## [br]
## @api public
## [br]
## @since 7.0.0
## [br]
## @param target: `ItemList` 或 `OptionButton`。
## [br]
## @return 选中 metadata 数组。
## [br]
## @schema return: Array，ItemList 返回所有选中条目 metadata，OptionButton 返回单个 metadata。
static func get_selected_metadata(target: Object) -> Array:
	var result: Array = []
	if target is ItemList:
		var item_list: ItemList = target
		for index: int in item_list.get_selected_items():
			result.append(get_item_metadata(item_list, index))
		return result
	if target is OptionButton:
		var option_button: OptionButton = target
		var selected_index: int = option_button.selected
		if selected_index >= 0:
			result.append(get_item_metadata(option_button, selected_index))
	return result


# --- 私有/辅助方法 ---

func _apply_store_change_to_target(binding: Dictionary, change: Dictionary) -> void:
	var target: Object = _get_binding_target(binding)
	if target == null:
		var _removed_invalid_binding: bool = _remove_binding(binding)
		return

	var value: Variant = GFVariantData.get_option_value(
		change,
		"new_value",
		GFVariantData.get_option_value(GFVariantData.get_option_dictionary(binding, "options"), "default_items", [])
	)
	if not GFVariantData.get_option_bool(change, "new_exists", true):
		value = GFVariantData.get_option_value(GFVariantData.get_option_dictionary(binding, "options"), "default_items", [])
	var _written_count: int = write_items(target, _value_to_items(value), GFVariantData.get_option_dictionary(binding, "options"))


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

	var target: Object = _get_binding_target(binding)
	if target is Node:
		var target_node: Node = target
		var tree_exited_callable: Callable = _get_binding_callable(binding, "tree_exited_callable")
		if tree_exited_callable.is_valid() and target_node.tree_exited.is_connected(tree_exited_callable):
			target_node.tree_exited.disconnect(tree_exited_callable)


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


func _get_binding_target(binding: Dictionary) -> Object:
	var target_ref: WeakRef = _get_binding_weak_ref(binding, "target_ref")
	return _INSTANCE_GUARD._get_live_object_from_ref(target_ref)


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


func _prune_invalid_bindings() -> void:
	for index: int in range(_bindings.size() - 1, -1, -1):
		var binding: Dictionary = _bindings[index]
		if _get_binding_store(binding) == null or _get_binding_target(binding) == null:
			_disconnect_binding(binding)
			_bindings.remove_at(index)


func _on_target_tree_exited(binding_id: int) -> void:
	for index: int in range(_bindings.size() - 1, -1, -1):
		if GFVariantData.get_option_int(_bindings[index], "binding_id", -1) == binding_id:
			var _removed_exited_binding: bool = _remove_binding(_bindings[index])
			return


static func _is_supported_target(target: Object) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return target is ItemList or target is OptionButton or target is PopupMenu


static func _value_to_items(value: Variant) -> Array:
	if value is Array:
		var items: Array = value
		return items
	return []


static func _normalize_items(items: Array, options: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in range(items.size()):
		result.append(_normalize_item(items[index], index, options))
	return result


static func _normalize_item(item: Variant, index: int, options: Dictionary) -> Dictionary:
	if item is Dictionary:
		var source: Dictionary = GFVariantData.as_dictionary(item)
		var metadata: Variant = _get_metadata_value(source, item, options)
		return {
			"text": _get_item_text(source, item, options),
			"metadata": GFVariantData.duplicate_variant(metadata),
			"icon": _variant_to_texture(GFVariantData.get_option_value(source, _get_option_key(options, "icon_key", &"icon"))),
			"disabled": GFVariantData.get_option_bool(source, _get_option_key(options, "disabled_key", &"disabled")),
			"selectable": GFVariantData.get_option_bool(source, _get_option_key(options, "selectable_key", &"selectable"), true),
			"tooltip": GFVariantData.get_option_string(source, _get_option_key(options, "tooltip_key", &"tooltip")),
			"selected": GFVariantData.get_option_bool(source, _get_option_key(options, "selected_key", &"selected")),
			"integer_id": _get_integer_item_id(source, index, options),
		}

	return {
		"text": GFVariantData.to_text(item),
		"metadata": GFVariantData.duplicate_variant(item),
		"icon": null,
		"disabled": false,
		"selectable": true,
		"tooltip": "",
		"selected": false,
		"integer_id": index,
	}


static func _write_item_list(item_list: ItemList, items: Array[Dictionary], options: Dictionary) -> int:
	if GFVariantData.get_option_bool(options, "clear", true):
		item_list.clear()

	var selected_indices: Array[int] = []
	for item: Dictionary in items:
		var index: int = item_list.item_count
		var _add_item_result: Variant = item_list.add_item(
			GFVariantData.get_option_string(item, "text"),
			_variant_to_texture(GFVariantData.get_option_value(item, "icon")),
			GFVariantData.get_option_bool(item, "selectable", true)
		)
		item_list.set_item_metadata(index, GFVariantData.get_option_value(item, "metadata"))
		item_list.set_item_disabled(index, GFVariantData.get_option_bool(item, "disabled"))
		var tooltip: String = GFVariantData.get_option_string(item, "tooltip")
		if not tooltip.is_empty():
			item_list.set_item_tooltip(index, tooltip)
		if GFVariantData.get_option_bool(item, "selected"):
			selected_indices.append(index)

	for index: int in selected_indices:
		item_list.select(index, false)
	return items.size()


static func _write_option_button(option_button: OptionButton, items: Array[Dictionary], options: Dictionary) -> int:
	if GFVariantData.get_option_bool(options, "clear", true):
		option_button.clear()

	var selected_index: int = -1
	for item: Dictionary in items:
		var index: int = option_button.item_count
		var icon: Texture2D = _variant_to_texture(GFVariantData.get_option_value(item, "icon"))
		var text: String = GFVariantData.get_option_string(item, "text")
		var integer_id: int = GFVariantData.get_option_int(item, "integer_id", index)
		if icon != null:
			option_button.add_icon_item(icon, text, integer_id)
		else:
			option_button.add_item(text, integer_id)
		option_button.set_item_metadata(index, GFVariantData.get_option_value(item, "metadata"))
		option_button.set_item_disabled(index, GFVariantData.get_option_bool(item, "disabled"))
		var tooltip: String = GFVariantData.get_option_string(item, "tooltip")
		if not tooltip.is_empty():
			option_button.set_item_tooltip(index, tooltip)
		if selected_index == -1 and GFVariantData.get_option_bool(item, "selected"):
			selected_index = index

	if selected_index >= 0:
		option_button.select(selected_index)
	return items.size()


static func _write_popup_menu(popup_menu: PopupMenu, items: Array[Dictionary], options: Dictionary) -> int:
	if GFVariantData.get_option_bool(options, "clear", true):
		popup_menu.clear()

	for item: Dictionary in items:
		var index: int = popup_menu.get_item_count()
		var icon: Texture2D = _variant_to_texture(GFVariantData.get_option_value(item, "icon"))
		var text: String = GFVariantData.get_option_string(item, "text")
		var integer_id: int = GFVariantData.get_option_int(item, "integer_id", index)
		if icon != null:
			popup_menu.add_icon_item(icon, text, integer_id)
		else:
			popup_menu.add_item(text, integer_id)
		popup_menu.set_item_metadata(index, GFVariantData.get_option_value(item, "metadata"))
		popup_menu.set_item_disabled(index, GFVariantData.get_option_bool(item, "disabled"))
		var tooltip: String = GFVariantData.get_option_string(item, "tooltip")
		if not tooltip.is_empty():
			popup_menu.set_item_tooltip(index, tooltip)
	return items.size()


static func _get_item_text(source: Dictionary, item: Variant, options: Dictionary) -> String:
	var text_key: StringName = _get_option_key(options, "text_key", &"text")
	var text: String = GFVariantData.get_option_string(source, text_key)
	if not text.is_empty():
		return text
	for fallback_key: StringName in [&"label", &"name", &"id"]:
		text = GFVariantData.get_option_string(source, fallback_key)
		if not text.is_empty():
			return text
	return GFVariantData.to_text(item)


static func _get_metadata_value(source: Dictionary, item: Variant, options: Dictionary) -> Variant:
	var metadata_key: StringName = _get_option_key(options, "metadata_key", &"")
	if metadata_key != &"" and source.has(metadata_key):
		return GFVariantData.get_option_value(source, metadata_key)
	var id_key: StringName = _get_option_key(options, "id_key", &"id")
	if id_key != &"" and source.has(id_key):
		return GFVariantData.get_option_value(source, id_key)
	return item


static func _get_integer_item_id(source: Dictionary, index: int, options: Dictionary) -> int:
	var id_key: StringName = _get_option_key(options, "id_key", &"id")
	if id_key == &"":
		return index
	var value: Variant = GFVariantData.get_option_value(source, id_key, index)
	if value is int:
		var item_id: int = value
		return item_id
	return index


static func _get_option_key(options: Dictionary, key: String, fallback: StringName) -> StringName:
	var value: Variant = GFVariantData.get_option_value(options, key, fallback)
	return GFVariantData.to_string_name(value, fallback)


static func _variant_to_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		var texture: Texture2D = value
		return texture
	return null
