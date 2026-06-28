## GFUIUtility: 栈式 UI 管理器。
##
## 负责多层级界面的入栈、出栈与异步加载，
## 适合 HUD、弹窗和顶层遮罩等需要分层管理的 UI 场景。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFUIUtility
extends GFUtility


# --- 信号 ---

## 面板成功进入 UI 栈后发出。
## [br]
## @api public
## [br]
## @param panel: 面板实例。
## [br]
## @param layer: 目标层级。
signal panel_opened(panel: Node, layer: int)

## 面板离开 UI 栈后发出。
## [br]
## @api public
## [br]
## @param panel: 面板实例。
## [br]
## @param layer: 原层级。
signal panel_closed(panel: Node, layer: int)

## 指定层级的栈顶面板变化后发出。
## [br]
## @api public
## [br]
## @param layer: 发生变化的层级。
## [br]
## @param top_panel: 新栈顶面板；层级为空时为 null。
signal navigation_changed(layer: int, top_panel: Node)

## 面板请求被取消或关闭时发出。
## [br]
## @api public
## [br]
## @param panel: 请求关闭的面板。
## [br]
## @param layer: 所在层级。
## [br]
## @param reason: 关闭原因。
signal panel_dismiss_requested(panel: Node, layer: int, reason: String)

## 异步面板加载请求开始时发出。
## [br]
## @api public
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param operation: 打开操作，可能为 push 或 replace。
signal panel_async_load_started(path: String, layer: int, operation: StringName)

## 异步面板加载请求结束时发出。
## [br]
## @api public
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param operation: 打开操作，可能为 push 或 replace。
## [br]
## @param status: 结束状态，使用 AsyncPanelLoadStatus。
## [br]
## @param panel: 成功打开的面板；失败或取消时为 null。
signal panel_async_load_finished(path: String, layer: int, operation: StringName, status: int, panel: Node)


# --- 枚举 ---

## UI 层级，数值越大显示越靠前。
## [br]
## @api public
enum Layer {
	## 基础信息层，如主界面、血条 HUD 等。
	HUD = 0,
	## 弹窗层，如背包、设置菜单、对话框等。
	POPUP = 1,
	## 顶层，如全屏遮罩、断线重连提示等。
	TOP = 2,
}

## 面板交互模式。
## [br]
## @api public
enum PanelMode {
	## 普通面板。
	NORMAL,
	## Modal 面板，通常会独占当前交互焦点。
	MODAL,
}

## 异步面板加载结束状态。
## [br]
## @api public
enum AsyncPanelLoadStatus {
	## 面板已完成加载并进入 UI 栈。
	OPENED,
	## 加载资源、实例化或入栈失败。
	FAILED,
	## 请求被弹出、清层、替换层或销毁 UI 工具取消。
	CANCELLED,
}


# --- 常量 ---

const _INSTANCE_GUARD: Script = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")


# --- 私有变量 ---

# 各层级的 CanvasLayer 根节点。
var _layer_roots: Dictionary = {}

# 各层级的面板栈。
var _panel_stacks: Dictionary = {
	Layer.HUD: [],
	Layer.POPUP: [],
	Layer.TOP: [],
}

# 是否自动隐藏同层级下方的面板。
var _auto_hide_under: bool = true

# Utility 生命周期标记，防止异步回调落到已销毁实例上。
var _is_active: bool = false

# 面板实例 id 到策略选项的映射。
var _panel_options: Dictionary = {}

# 面板实例 id 到打开前焦点控件的映射。
var _previous_focus_by_panel_id: Dictionary = {}

# 每个层级的结构性变更序号，用于阻止迟到异步回调污染新状态。
var _layer_request_serials: Dictionary = {}

# 同一层级、同一路径的异步 push 请求序号，避免连点造成重复面板实例。
var _pending_async_push_serials: Dictionary = {}

# 当前仍在等待资源回调的异步面板请求。
var _pending_async_panel_requests: Dictionary = {}


# --- GF 生命周期方法 ---

## 初始化 UI 层级根节点并激活管理器。
## [br]
## @api public
func init() -> void:
	_is_active = true
	_create_layers()


## 释放 UI 层级、面板栈和未完成异步请求。
## [br]
## @api public
func dispose() -> void:
	_is_active = false
	_cancel_all_pending_async_panel_requests()
	for canvas: CanvasLayer in _layer_roots.values():
		if is_instance_valid(canvas):
			_detach_node_from_tree(canvas)
			canvas.queue_free()
	_layer_roots.clear()

	for stack: Array in _panel_stacks.values():
		stack.clear()
	_panel_options.clear()
	_previous_focus_by_panel_id.clear()
	_layer_request_serials.clear()
	_pending_async_push_serials.clear()
	_pending_async_panel_requests.clear()


# --- 公共方法 ---

## 配置 UI 管理器。
## [br]
## @api public
## [br]
## @param auto_hide_under: 压入新面板时是否自动隐藏下层面板。
func configure(auto_hide_under: bool = true) -> void:
	_auto_hide_under = auto_hide_under


## 异步压入一个面板场景。
## [br]
## @api public
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
func push_panel_async(path: String, layer: Layer = Layer.POPUP, config_callback: Callable = Callable()) -> void:
	push_panel_async_with_options(path, layer, {}, config_callback)


## 异步压入一个带策略选项的面板场景。
## [br]
## @api public
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @schema options: Dictionary，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func push_panel_async_with_options(
	path: String,
	layer: Layer = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable()
) -> void:
	if path.is_empty():
		push_error("[GFUIUtility] 面板场景路径不能为空。")
		return

	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		push_warning("[GFUIUtility] GFAssetUtility 未注册，回退为同步加载。")
		var _fallback_panel: Node = push_panel_with_options(path, layer, options, config_callback)
		return

	var request_serial: int = _get_layer_request_serial(layer)
	var request_key: String = _make_async_push_key(path, layer)
	if _pending_async_push_serials.has(request_key):
		return

	_pending_async_push_serials[request_key] = request_serial
	var async_request_key: String = _make_async_panel_request_key(&"push", path, layer, request_serial)
	_track_async_panel_request(async_request_key, path, layer, &"push", request_serial)
	var on_loaded: Callable = func(res: Resource) -> void:
		_clear_pending_async_push(request_key, request_serial)
		if not _is_active or not _is_layer_request_serial_current(layer, request_serial):
			return

		var scene: PackedScene = _get_packed_scene(res)
		if scene == null:
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.FAILED, null)
			push_error("[GFUIUtility] 无法实例化面板场景：%s" % path)
			return

		var panel_instance: Node = scene.instantiate()
		if _add_panel_instance(panel_instance, layer, config_callback, options):
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.OPENED, panel_instance)
		else:
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.FAILED, null)
			if is_instance_valid(panel_instance):
				panel_instance.queue_free()

	asset_util.load_async(path, on_loaded, "PackedScene")


## 同步压入一个面板场景。
## [br]
## @api public
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @return 成功时返回面板实例，失败时返回 `null`。
func push_panel(path: String, layer: Layer = Layer.POPUP, config_callback: Callable = Callable()) -> Node:
	return push_panel_with_options(path, layer, {}, config_callback)


## 同步压入一个带策略选项的面板场景。
## [br]
## @api public
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @return 成功时返回面板实例，失败时返回 `null`。
## [br]
## @schema options: Dictionary，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func push_panel_with_options(
	path: String,
	layer: Layer = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable()
) -> Node:
	var scene: PackedScene = _load_packed_scene(path)
	if scene == null:
		push_error("[GFUIUtility] 无法加载面板场景：%s" % path)
		return null

	var panel_instance: Node = scene.instantiate()
	if not _add_panel_instance(panel_instance, layer, config_callback, options):
		if is_instance_valid(panel_instance):
			panel_instance.queue_free()
		return null

	return panel_instance


## 同步替换指定层级的面板栈。
## [br]
## @api public
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @return 成功时返回面板实例，失败时返回 `null`。
func replace_layer(path: String, layer: Layer = Layer.POPUP, config_callback: Callable = Callable()) -> Node:
	return replace_layer_with_options(path, layer, {}, config_callback)


## 同步替换指定层级为带策略选项的面板。
## [br]
## @api public
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @return 成功时返回面板实例，失败时返回 `null`。
## [br]
## @schema options: Dictionary，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func replace_layer_with_options(
	path: String,
	layer: Layer = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable()
) -> Node:
	var scene: PackedScene = _load_packed_scene(path)
	if scene == null:
		push_error("[GFUIUtility] 无法加载面板场景：%s" % path)
		return null

	var panel_instance: Node = scene.instantiate()
	clear_layer(layer)
	if not _add_panel_instance(panel_instance, layer, config_callback, options):
		if is_instance_valid(panel_instance):
			panel_instance.queue_free()
		return null

	return panel_instance


## 异步替换指定层级的面板栈。
## [br]
## @api public
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
func replace_layer_async(path: String, layer: Layer = Layer.POPUP, config_callback: Callable = Callable()) -> void:
	replace_layer_async_with_options(path, layer, {}, config_callback)


## 异步替换指定层级为带策略选项的面板。
## [br]
## @api public
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @schema options: Dictionary，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func replace_layer_async_with_options(
	path: String,
	layer: Layer = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable()
) -> void:
	if path.is_empty():
		push_error("[GFUIUtility] 面板场景路径不能为空。")
		return

	var request_serial: int = _next_layer_request_serial(layer)
	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		push_warning("[GFUIUtility] GFAssetUtility 未注册，回退为同步加载。")
		var _fallback_panel: Node = replace_layer_with_options(path, layer, options, config_callback)
		return

	var async_request_key: String = _make_async_panel_request_key(&"replace", path, layer, request_serial)
	_track_async_panel_request(async_request_key, path, layer, &"replace", request_serial)
	var on_loaded: Callable = func(res: Resource) -> void:
		if not _is_active or not _is_layer_request_serial_current(layer, request_serial):
			return

		var scene: PackedScene = _get_packed_scene(res)
		if scene == null:
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.FAILED, null)
			push_error("[GFUIUtility] 无法实例化面板场景：%s" % path)
			return

		var panel_instance: Node = scene.instantiate()
		_clear_layer_without_invalidating_requests(layer)
		if _add_panel_instance(panel_instance, layer, config_callback, options):
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.OPENED, panel_instance)
		else:
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.FAILED, null)
			if is_instance_valid(panel_instance):
				panel_instance.queue_free()

	asset_util.load_async(path, on_loaded, "PackedScene")


## 压入一个已实例化的面板节点。
## [br]
## @api public
## [br]
## @param panel_instance: 面板实例。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 入栈前的可选配置回调。
func push_panel_instance(
	panel_instance: Node,
	layer: Layer = Layer.POPUP,
	config_callback: Callable = Callable()
) -> void:
	push_panel_instance_with_options(panel_instance, layer, {}, config_callback)


## 压入一个已实例化且带策略选项的面板节点。
## [br]
## @api public
## [br]
## @param panel_instance: 面板实例。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 入栈前的可选配置回调。
## [br]
## @schema options: Dictionary，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func push_panel_instance_with_options(
	panel_instance: Node,
	layer: Layer = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable()
) -> void:
	if not is_instance_valid(panel_instance):
		push_error("[GFUIUtility] 传入的 panel_instance 无效。")
		return

	var _added: bool = _add_panel_instance(panel_instance, layer, config_callback, options)


## 用已实例化面板替换指定层级的面板栈。
## [br]
## @api public
## [br]
## @param panel_instance: 面板实例。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 入栈前的可选配置回调。
func replace_layer_instance(
	panel_instance: Node,
	layer: Layer = Layer.POPUP,
	config_callback: Callable = Callable()
) -> void:
	replace_layer_instance_with_options(panel_instance, layer, {}, config_callback)


## 用已实例化且带策略选项的面板替换指定层级的面板栈。
## [br]
## @api public
## [br]
## @param panel_instance: 面板实例。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 入栈前的可选配置回调。
## [br]
## @schema options: Dictionary，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func replace_layer_instance_with_options(
	panel_instance: Node,
	layer: Layer = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable()
) -> void:
	if not is_instance_valid(panel_instance):
		push_error("[GFUIUtility] 传入的 panel_instance 无效。")
		return

	clear_layer(layer)
	push_panel_instance_with_options(panel_instance, layer, options, config_callback)


## 弹出指定层级的顶部面板。
## [br]
## @api public
## [br]
## @param layer: 目标层级。
## [br]
## @param do_free: 是否在弹出后释放面板。
func pop_panel(layer: Layer = Layer.POPUP, do_free: bool = true) -> void:
	var _request_serial: int = _next_layer_request_serial(layer)
	_prune_layer_stack(layer)
	var stack: Array = _get_layer_stack(layer)
	if stack.is_empty():
		return

	var top_panel: Node = _get_valid_panel_from_variant(stack.pop_back())
	if top_panel != null:
		_detach_node_from_tree(top_panel)
		_handle_panel_closed(top_panel)
		if do_free:
			top_panel.queue_free()
		panel_closed.emit(top_panel, layer)

	if _auto_hide_under:
		_reveal_top_panel(layer)
	_emit_navigation_changed(layer)


## 弹出面板直到指定面板成为栈顶。
## [br]
## @api public
## [br]
## @param panel: 目标面板实例。
## [br]
## @param layer: 目标层级。
## [br]
## @param do_free: 是否释放被弹出的面板。
## [br]
## @return 找到目标面板并完成回退时返回 true。
func pop_to_panel(panel: Node, layer: Layer = Layer.POPUP, do_free: bool = true) -> bool:
	if not is_instance_valid(panel):
		return false

	_prune_layer_stack(layer)
	var stack: Array = _panel_stacks[layer]
	if not stack.has(panel):
		return false

	while get_top_panel(layer) != panel:
		pop_panel(layer, do_free)
	return true


## 清空指定层级的所有面板。
## [br]
## @api public
## [br]
## @param layer: 目标层级。
func clear_layer(layer: Layer) -> void:
	var _request_serial: int = _next_layer_request_serial(layer)
	_clear_layer_without_invalidating_requests(layer)


## 清空所有层级的所有面板。
## [br]
## @api public
func clear_all() -> void:
	for layer_idx: int in _panel_stacks.keys():
		clear_layer(_variant_to_layer(layer_idx, Layer.HUD))


## 获取指定层级的顶部面板。
## [br]
## @api public
## [br]
## @param layer: 目标层级。
## [br]
## @return 栈顶面板；为空时返回 `null`。
func get_top_panel(layer: Layer = Layer.POPUP) -> Node:
	_prune_layer_stack(layer)
	var stack: Array = _get_layer_stack(layer)
	if stack.is_empty():
		return null

	return _get_valid_panel_from_variant(stack.back())


## 获取指定层级当前面板栈的副本。
## [br]
## @api public
## [br]
## @param layer: 目标层级。
## [br]
## @return 从底到顶排列的面板列表。
func get_panel_stack(layer: Layer = Layer.POPUP) -> Array[Node]:
	_prune_layer_stack(layer)
	var result: Array[Node] = []
	var stack: Array = _get_layer_stack(layer)
	for panel_variant: Variant in stack:
		var panel: Node = _get_valid_panel_from_variant(panel_variant)
		if panel != null:
			result.append(panel)
	return result


## 获取指定层级当前面板数量。
## [br]
## @api public
## [br]
## @param layer: 目标层级。
## [br]
## @return 面板数量。
func get_stack_count(layer: Layer = Layer.POPUP) -> int:
	return get_panel_stack(layer).size()


## 检查面板是否已进入 UI 栈。
## [br]
## @api public
## [br]
## @param panel: 面板实例。
## [br]
## @param layer: 指定层级；小于 0 时检查所有层级。
## [br]
## @return 面板已打开时返回 true。
func is_panel_open(panel: Node, layer: int = -1) -> bool:
	if not is_instance_valid(panel):
		return false

	_prune_all_layer_stacks()
	if layer >= 0:
		var checked_layer: Layer = _variant_to_layer(layer, Layer.HUD)
		return _panel_stacks.has(layer) and _get_layer_stack(checked_layer).has(panel)

	return _is_panel_in_any_stack(panel)


## 获取 UI 管理器诊断快照。
## [br]
## @api public
## [br]
## @return 包含各层级栈数量和栈顶名称的字典。
## [br]
## @schema return: Dictionary，包含 active、auto_hide_under、pending_async_panel_count 和 layers；layers 按 Layer 值索引，每项包含 count、top_panel 和 top_modal。
func get_debug_snapshot() -> Dictionary:
	var layers: Dictionary = {}
	for layer_idx: int in _panel_stacks.keys():
		var layer: Layer = _variant_to_layer(layer_idx, Layer.HUD)
		_prune_layer_stack(layer)
		var top_panel: Node = get_top_panel(layer)
		var top_panel_name: String = ""
		if top_panel != null:
			top_panel_name = String(top_panel.name)
		layers[layer_idx] = {
			"count": _get_layer_stack(layer).size(),
			"top_panel": top_panel_name,
			"top_modal": is_panel_modal(top_panel) if top_panel != null else false,
		}
	return {
		"active": _is_active,
		"auto_hide_under": _auto_hide_under,
		"pending_async_panel_count": _pending_async_panel_requests.size(),
		"layers": layers,
	}


## 获取指定层级的 CanvasLayer。
## [br]
## @api public
## [br]
## @param layer: 目标层级。
## [br]
## @return 对应的 `CanvasLayer` 实例。
func get_layer_root(layer: Layer) -> CanvasLayer:
	return _get_canvas_layer(GFVariantData.get_option_value(_layer_roots, layer))


## 设置已打开面板的策略选项。
## [br]
## @api public
## [br]
## @param panel: 面板实例。
## [br]
## @param options: 面板策略，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @schema options: Dictionary，支持 mode、modal、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func set_panel_options(panel: Node, options: Dictionary) -> void:
	if not is_instance_valid(panel):
		return
	_panel_options[panel.get_instance_id()] = _normalize_panel_options(options)


## 获取面板策略选项。
## [br]
## @api public
## [br]
## @param panel: 面板实例。
## [br]
## @return 策略选项副本。
## [br]
## @schema return: Dictionary，包含 mode、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func get_panel_options(panel: Node) -> Dictionary:
	if not is_instance_valid(panel):
		return {}
	return GFVariantData.to_dictionary(GFVariantData.get_option_value(_panel_options, panel.get_instance_id(), {}))


## 判断面板是否按 modal 策略管理。
## [br]
## @api public
## [br]
## @param panel: 面板实例。
## [br]
## @return 是 modal 面板时返回 true。
func is_panel_modal(panel: Node) -> bool:
	if not is_instance_valid(panel):
		return false
	var options: Dictionary = _get_panel_options_for_id(panel.get_instance_id())
	return GFVariantData.get_option_int(options, "mode", PanelMode.NORMAL) == PanelMode.MODAL


## 检查是否存在打开的 modal 面板。
## [br]
## @api public
## [br]
## @param layer: 指定层级；小于 0 时检查所有层级。
## [br]
## @return 存在 modal 面板时返回 true。
func has_modal_open(layer: int = -1) -> bool:
	if layer >= 0:
		return _count_modals_in_layer(_variant_to_layer(layer, Layer.HUD)) > 0

	for layer_idx: int in _panel_stacks.keys():
		if _count_modals_in_layer(_variant_to_layer(layer_idx, Layer.HUD)) > 0:
			return true
	return false


## 检查是否存在仍在等待资源回调的异步面板请求。
## [br]
## @api public
## [br]
## @param layer: 指定层级；小于 0 时检查所有层级。
## [br]
## @param path: 指定面板路径；为空时不按路径过滤。
## [br]
## @return 存在匹配请求时返回 true。
func has_pending_async_panel(layer: int = -1, path: String = "") -> bool:
	for request: Dictionary in _pending_async_panel_requests.values():
		if layer >= 0 and GFVariantData.get_option_int(request, "layer", -1) != layer:
			continue
		if not path.is_empty() and GFVariantData.get_option_string(request, "path", "") != path:
			continue
		return true
	return false


## 获取仍在等待资源回调的异步面板请求快照。
## [br]
## @api public
## [br]
## @param layer: 指定层级；小于 0 时返回所有层级。
## [br]
## @return 请求快照数组，每项包含 path、layer、operation 和 serial。
## [br]
## @schema return: Array，元素为 Dictionary，包含 path、layer、operation 和 serial。
func get_pending_async_panel_requests(layer: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for request: Dictionary in _pending_async_panel_requests.values():
		if layer >= 0 and GFVariantData.get_option_int(request, "layer", -1) != layer:
			continue
		result.append(request.duplicate(true))
	return result


## 获取打开的 modal 面板数量。
## [br]
## @api public
## [br]
## @param layer: 指定层级；小于 0 时统计所有层级。
## [br]
## @return modal 面板数量。
func get_modal_count(layer: int = -1) -> int:
	if layer >= 0:
		return _count_modals_in_layer(_variant_to_layer(layer, Layer.HUD))

	var count: int = 0
	for layer_idx: int in _panel_stacks.keys():
		count += _count_modals_in_layer(_variant_to_layer(layer_idx, Layer.HUD))
	return count


## 按顶层优先顺序处理取消请求。
## [br]
## @api public
## [br]
## @param layer: 指定层级；小于 0 时从最高层级开始查找。
## [br]
## @param reason: 关闭原因。
## [br]
## @return 找到可取消面板并处理时返回 true。
func request_dismiss_top(layer: int = -1, reason: String = "cancel") -> bool:
	if layer >= 0:
		return _request_dismiss_layer(_variant_to_layer(layer, Layer.HUD), reason)

	var layer_values: Array = Layer.values()
	layer_values.sort()
	for index: int in range(layer_values.size() - 1, -1, -1):
		var candidate_layer: Layer = _variant_to_layer(layer_values[index], Layer.HUD)
		if _request_dismiss_layer(candidate_layer, reason):
			return true
	return false


## 尝试把焦点保持在指定层级栈顶 modal 面板内。
## [br]
## @api public
## [br]
## @param layer: 目标层级。
## [br]
## @return 发生焦点修正时返回 true。
func keep_focus_inside_top_modal(layer: Layer = Layer.POPUP) -> bool:
	var top_panel: Node = get_top_panel(layer)
	if not is_panel_modal(top_panel):
		return false
	var viewport: Viewport = top_panel.get_viewport()
	if viewport == null:
		return false
	var focused: Control = viewport.gui_get_focus_owner()
	if focused != null and _is_descendant_of(focused, top_panel):
		return false
	return _focus_first_control(top_panel)


# --- 私有/辅助方法 ---

func _clear_layer_without_invalidating_requests(layer: Layer) -> void:
	_prune_layer_stack(layer)
	var stack: Array = _get_layer_stack(layer)
	while not stack.is_empty():
		var panel: Node = _get_valid_panel_from_variant(stack.pop_back())
		if panel != null:
			_detach_node_from_tree(panel)
			_handle_panel_closed(panel)
			panel.queue_free()
			panel_closed.emit(panel, layer)
	_emit_navigation_changed(layer)


func _detach_node_from_tree(node: Node) -> void:
	var parent: Node = node.get_parent()
	if parent != null:
		parent.remove_child(node)


func _next_layer_request_serial(layer: Layer) -> int:
	var next_serial: int = _get_layer_request_serial(layer) + 1
	_layer_request_serials[layer] = next_serial
	_cancel_pending_async_panel_requests_for_layer(layer)
	_clear_pending_async_pushes_for_layer(layer)
	return next_serial


func _get_layer_request_serial(layer: Layer) -> int:
	return GFVariantData.get_option_int(_layer_request_serials, layer, 0)


func _is_layer_request_serial_current(layer: Layer, request_serial: int) -> bool:
	return _get_layer_request_serial(layer) == request_serial


func _make_async_push_key(path: String, layer: Layer) -> String:
	return "%d:%s" % [int(layer), path]


func _make_async_panel_request_key(operation: StringName, path: String, layer: Layer, request_serial: int) -> String:
	return "%s:%d:%d:%s" % [String(operation), int(layer), request_serial, path]


func _track_async_panel_request(
	request_key: String,
	path: String,
	layer: Layer,
	operation: StringName,
	request_serial: int
) -> void:
	_pending_async_panel_requests[request_key] = {
		"path": path,
		"layer": int(layer),
		"operation": operation,
		"serial": request_serial,
	}
	panel_async_load_started.emit(path, int(layer), operation)


func _finish_async_panel_request(request_key: String, status: int, panel: Node) -> void:
	if not _pending_async_panel_requests.has(request_key):
		return

	var request: Dictionary = _get_pending_async_panel_request(request_key)
	var _erased: bool = _pending_async_panel_requests.erase(request_key)
	panel_async_load_finished.emit(
		GFVariantData.get_option_string(request, "path", ""),
		GFVariantData.get_option_int(request, "layer", -1),
		GFVariantData.get_option_string_name(request, "operation", &""),
		status,
		panel
	)


func _clear_pending_async_push(request_key: String, request_serial: int) -> void:
	if GFVariantData.get_option_int(_pending_async_push_serials, request_key, -1) == request_serial:
		var _erased: bool = _pending_async_push_serials.erase(request_key)


func _clear_pending_async_pushes_for_layer(layer: Layer) -> void:
	var prefix: String = "%d:" % int(layer)
	for request_key: String in _pending_async_push_serials.keys():
		if request_key.begins_with(prefix):
			var _erased: bool = _pending_async_push_serials.erase(request_key)


func _cancel_pending_async_panel_requests_for_layer(layer: Layer) -> void:
	for request_key: String in _pending_async_panel_requests.keys():
		var request: Dictionary = _get_pending_async_panel_request(request_key)
		if GFVariantData.get_option_int(request, "layer", -1) == int(layer):
			_finish_async_panel_request(request_key, AsyncPanelLoadStatus.CANCELLED, null)


func _cancel_all_pending_async_panel_requests() -> void:
	for request_key: String in _pending_async_panel_requests.keys():
		_finish_async_panel_request(request_key, AsyncPanelLoadStatus.CANCELLED, null)


func _create_layers() -> void:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		push_error("[GFUIUtility] 无法获取 SceneTree。")
		return

	var scene_tree: SceneTree = main_loop
	var root: Window = scene_tree.root
	for layer_idx: int in Layer.values():
		var canvas: CanvasLayer = CanvasLayer.new()
		canvas.layer = 50 + layer_idx * 10
		canvas.name = "GFUILayer_" + str(Layer.keys()[layer_idx])
		root.call_deferred("add_child", canvas)
		_layer_roots[layer_idx] = canvas


func _add_panel_instance(
	panel: Node,
	layer: Layer,
	config_callback: Callable,
	options: Dictionary = {}
) -> bool:
	if not _is_active:
		push_warning("[GFUIUtility] 当前 UI 管理器已销毁，忽略面板入栈。")
		return false

	var canvas: CanvasLayer = get_layer_root(layer)
	if not is_instance_valid(canvas):
		push_error("[GFUIUtility] 目标层级的 CanvasLayer 不可用。")
		return false

	_prune_all_layer_stacks()
	if _is_panel_in_any_stack(panel):
		push_warning("[GFUIUtility] 面板实例已在 UI 栈中，忽略重复入栈。")
		return false

	_prune_layer_stack(layer)
	var stack: Array = _get_layer_stack(layer)
	var normalized_options: Dictionary = _normalize_panel_options(options)
	var hidden_panel: CanvasItem = null
	if _auto_hide_under and not stack.is_empty():
		var old_top: Node = _get_valid_panel_from_variant(stack.back())
		hidden_panel = _get_canvas_item(old_top)
		if hidden_panel != null:
			hidden_panel.visible = false

	if config_callback.is_valid():
		config_callback.call(panel)
		if not is_instance_valid(panel):
			_restore_hidden_panel(hidden_panel)
			push_warning("[GFUIUtility] config_callback 销毁了面板实例，本次入栈已取消。")
			return false

	stack.push_back(panel)
	_panel_options[panel.get_instance_id()] = normalized_options
	var _tree_exited_connected: Error = panel.tree_exited.connect(
		_on_panel_tree_exited.bind(panel, layer),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if panel.get_parent() != null and panel.get_parent() != canvas:
		panel.get_parent().remove_child(panel)
	if panel.get_parent() != canvas:
		canvas.add_child(panel)
	_capture_previous_focus(panel, normalized_options)
	_apply_open_focus_policy(panel, normalized_options)
	panel_opened.emit(panel, layer)
	_emit_navigation_changed(layer)
	return true


func _prune_all_layer_stacks() -> void:
	for layer_idx: int in _panel_stacks.keys():
		_prune_layer_stack(_variant_to_layer(layer_idx, Layer.HUD))


func _get_valid_panel_from_variant(value: Variant) -> Node:
	var panel: Node = _get_live_node(value)
	if panel == null:
		return null
	if panel.is_queued_for_deletion():
		return null
	return panel


func _prune_layer_stack(layer: Layer) -> void:
	var stack: Array = _get_layer_stack(layer)
	var removed_top: bool = false
	for index: int in range(stack.size() - 1, -1, -1):
		var panel: Node = _get_valid_panel_from_variant(stack[index])
		if panel == null:
			if index == stack.size() - 1:
				removed_top = true
			stack.remove_at(index)
	if removed_top and _auto_hide_under:
		_reveal_top_panel(layer)


func _is_panel_in_any_stack(panel: Node) -> bool:
	for stack: Array in _panel_stacks.values():
		if stack.has(panel):
			return true
	return false


func _reveal_top_panel(layer: Layer) -> void:
	var stack: Array = _get_layer_stack(layer)
	if stack.is_empty():
		return

	var next_panel: Node = _get_valid_panel_from_variant(stack.back())
	var canvas_item: CanvasItem = _get_canvas_item(next_panel)
	if canvas_item != null:
		canvas_item.visible = true


func _restore_hidden_panel(panel: CanvasItem) -> void:
	if is_instance_valid(panel):
		panel.visible = true


func _emit_navigation_changed(layer: Layer) -> void:
	navigation_changed.emit(layer, get_top_panel(layer))


func _request_dismiss_layer(layer: Layer, reason: String) -> bool:
	var top_panel: Node = get_top_panel(layer)
	if top_panel == null:
		return false

	panel_dismiss_requested.emit(top_panel, layer, reason)
	var options: Dictionary = get_panel_options(top_panel)
	if not GFVariantData.get_option_bool(options, "dismiss_on_cancel", false):
		return false

	if top_panel.has_method("resolve_cancel"):
		top_panel.call("resolve_cancel")
		return true

	pop_panel(layer)
	return true


func _count_modals_in_layer(layer: Layer) -> int:
	_prune_layer_stack(layer)
	var count: int = 0
	for panel_variant: Variant in _get_layer_stack(layer):
		var panel: Node = _get_valid_panel_from_variant(panel_variant)
		if panel != null and is_panel_modal(panel):
			count += 1
	return count


func _normalize_panel_options(options: Dictionary) -> Dictionary:
	var is_modal: bool = GFVariantData.get_option_bool(options, "modal", false)
	var mode: int = GFVariantData.get_option_int(options, "mode", PanelMode.MODAL if is_modal else PanelMode.NORMAL)
	mode = clampi(mode, PanelMode.NORMAL, PanelMode.MODAL)
	return {
		"mode": mode,
		"dismiss_on_cancel": GFVariantData.get_option_bool(options, "dismiss_on_cancel", mode == PanelMode.MODAL),
		"focus_on_open": GFVariantData.get_option_bool(options, "focus_on_open", mode == PanelMode.MODAL),
		"restore_focus_on_close": GFVariantData.get_option_bool(options, "restore_focus_on_close", mode == PanelMode.MODAL),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}


func _capture_previous_focus(panel: Node, options: Dictionary) -> void:
	if not GFVariantData.get_option_bool(options, "restore_focus_on_close", false):
		return
	var viewport: Viewport = panel.get_viewport()
	if viewport == null:
		return
	var focused: Control = viewport.gui_get_focus_owner()
	if focused != null:
		_previous_focus_by_panel_id[panel.get_instance_id()] = weakref(focused)


func _apply_open_focus_policy(panel: Node, options: Dictionary) -> void:
	if GFVariantData.get_option_bool(options, "focus_on_open", false):
		var _focused: bool = _focus_first_control(panel)


func _handle_panel_closed(panel: Node) -> void:
	var panel_id: int = panel.get_instance_id()
	var options: Dictionary = _get_panel_options_for_id(panel_id)
	if GFVariantData.get_option_bool(options, "restore_focus_on_close", false):
		_restore_previous_focus(panel_id)
	var _options_erased: bool = _panel_options.erase(panel_id)
	var _focus_erased: bool = _previous_focus_by_panel_id.erase(panel_id)


func _restore_previous_focus(panel_id: int) -> void:
	var previous_ref: WeakRef = _get_weak_ref(GFVariantData.get_option_value(_previous_focus_by_panel_id, panel_id))
	if previous_ref == null:
		return
	var previous: Control = _get_live_control_from_ref(previous_ref)
	if is_instance_valid(previous) and previous.is_inside_tree():
		previous.grab_focus()


func _focus_first_control(root: Node) -> bool:
	if root is Control:
		var control: Control = root
		if _can_focus_control(control):
			control.grab_focus()
			return true

	for child: Node in root.get_children():
		if _focus_first_control(child):
			return true
	return false


func _can_focus_control(control: Control) -> bool:
	return (
		is_instance_valid(control)
		and control.is_inside_tree()
		and control.visible
		and control.focus_mode != Control.FOCUS_NONE
		and not control.is_queued_for_deletion()
	)


func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current: Node = node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


func _get_asset_util() -> GFAssetUtility:
	var arch: GFArchitecture = _get_architecture_or_null()
	if arch == null:
		return null

	var util: Variant = arch.get_utility(GFAssetUtility)
	if util is GFAssetUtility:
		return util
	return null


# --- 私有/辅助方法 (类型收口) ---

func _get_layer_stack(layer: Layer) -> Array:
	var value: Variant = GFVariantData.get_option_value(_panel_stacks, layer, [])
	if value is Array:
		var stack: Array = value
		return stack
	return []


func _get_panel_options_for_id(panel_id: int) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_panel_options, panel_id, {}))


func _get_pending_async_panel_request(request_key: String) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_pending_async_panel_requests, request_key, {}))


func _get_live_node(value: Variant) -> Node:
	var result: Variant = _INSTANCE_GUARD.call("_get_live_node", value)
	if result is Node:
		var node: Node = result
		return node
	return null


func _get_live_control_from_ref(object_ref: WeakRef) -> Control:
	var result: Variant = _INSTANCE_GUARD.call("_get_live_control_from_ref", object_ref)
	if result is Control:
		var control: Control = result
		return control
	return null


static func _get_canvas_layer(value: Variant) -> CanvasLayer:
	if value is CanvasLayer:
		var canvas: CanvasLayer = value
		return canvas
	return null


static func _get_canvas_item(value: Variant) -> CanvasItem:
	if value is CanvasItem:
		var canvas_item: CanvasItem = value
		return canvas_item
	return null


static func _get_packed_scene(value: Variant) -> PackedScene:
	if value is PackedScene:
		var scene: PackedScene = value
		return scene
	return null


static func _load_packed_scene(path: String) -> PackedScene:
	var resource: Resource = load(path)
	return _get_packed_scene(resource)


static func _get_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var object_ref: WeakRef = value
		return object_ref
	return null


static func _variant_to_layer(value: Variant, fallback: Layer) -> Layer:
	var layer_value: int = GFVariantData.to_int(value, int(fallback))
	if not Layer.values().has(layer_value):
		return fallback
	return layer_value as Layer


# --- 信号处理函数 ---

func _on_panel_tree_exited(panel: Node, layer: Layer) -> void:
	if not _panel_stacks.has(layer):
		return

	var stack: Array = _get_layer_stack(layer)
	var was_open: bool = stack.has(panel)
	if not was_open:
		return

	var was_top: bool = not stack.is_empty() and stack.back() == panel
	stack.erase(panel)
	_handle_panel_closed(panel)
	panel_closed.emit(panel, layer)
	if was_top and _auto_hide_under:
		_reveal_top_panel(layer)
	_emit_navigation_changed(layer)
