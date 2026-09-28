## GFUIUtility: 栈式 UI 管理器。
##
## 负责可扩展逻辑层中的入栈、出栈、层内可见性策略与异步加载，
## 适合 HUD、并行窗口、弹窗和顶层遮罩等需要分层管理的 UI 场景。
## 逻辑层彼此独立：绘制顺序由各层 CanvasLayer.layer 决定，层内 hide_under 不会清理其他层。
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

## 预置 UI 逻辑层 ID。预置绘制值依次为 HUD=50、POPUP=60、TOP=70；
## 自定义逻辑层的绘制顺序只由 GFUILayerDefinition.canvas_layer 决定，而不是 layer_id 大小。
## [br]
## @api public
## [br]
## @since 3.17.0
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

## 转发到实例守卫的存活节点与控件引用解析。
## [br]
## @api private
const _INSTANCE_GUARD: Script = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")

## HUD 逻辑层默认使用的 CanvasLayer.layer 值。
## [br]
## @api private
const _DEFAULT_HUD_CANVAS_LAYER: int = 50

## POPUP 逻辑层默认使用的 CanvasLayer.layer 值。
## [br]
## @api private
const _DEFAULT_POPUP_CANVAS_LAYER: int = 60

## TOP 逻辑层默认使用的 CanvasLayer.layer 值。
## [br]
## @api private
const _DEFAULT_TOP_CANVAS_LAYER: int = 70

## 未指定 layer 参数时使用的默认逻辑层 ID，与 Layer.POPUP 相同。
## [br]
## @api public
## [br]
## @since 8.1.0
const DEFAULT_LAYER_ID: int = 1


# --- 私有变量 ---

# 各层级的 CanvasLayer 根节点。
## 以逻辑层 ID 为键保存 CanvasLayer 根节点。
## [br]
## @api private
var _layer_roots: Dictionary = {}

# 各层级的面板栈。
## 以逻辑层 ID 为键保存该层按打开顺序排列的面板栈。
## [br]
## @api private
var _panel_stacks: Dictionary = {}

# 逻辑层 ID 到不可变定义副本的映射。
## 逻辑层 ID 到已复制层定义的映射。
## [br]
## @api private
var _layer_definitions: Dictionary = {}

# 是否自动隐藏同层级下方的面板。
## 新层默认采用的同层下方面板隐藏策略。
## [br]
## @api private
var _auto_hide_under: bool = true

# Utility 生命周期标记，防止异步回调落到已销毁实例上。
## 标记 UI 工具是否已初始化并可接受面板操作。
## [br]
## @api private
var _is_active: bool = false

# 面板实例 id 到策略选项的映射。
## 以面板实例 ID 为键保存入栈时规范化的交互选项。
## [br]
## @api private
var _panel_options: Dictionary = {}

# 面板实例 id 到打开前焦点控件的映射。
## 以面板实例 ID 为键保存可选的前序焦点控件弱引用。
## [br]
## @api private
var _previous_focus_by_panel_id: Dictionary = {}

# 每次入栈都取得独立身份；同一节点关闭后重开也不会延续旧聚焦遍历。
## 以面板实例 ID 为键记录本次入栈身份序号。
## [br]
## @api private
var _panel_open_serials: Dictionary = {}

## 为每次成功入栈分配新的身份序号。
## [br]
## @api private
var _next_panel_open_serial: int = 1

# 每个层级的结构性变更序号，用于阻止迟到异步回调污染新状态。
## 记录各层最近一次结构性请求序号，用于识别过期异步回调。
## [br]
## @api private
var _layer_request_serials: Dictionary = {}

# 跨 init/dispose 单调递增的异步请求序号，避免旧资源回调与新请求身份碰撞。
## 在同一工具实例生命周期内递增的异步面板请求序号。
## [br]
## @api private
var _next_async_panel_request_serial: int = 1

# 同一层级、同一路径的异步 push 请求序号，避免连点造成重复面板实例。
## 以路径和层级键记录正在等待的异步 push 序号，抑制重复实例化。
## [br]
## @api private
var _pending_async_push_serials: Dictionary = {}

# 当前仍在等待资源回调的异步面板请求。
## 按请求键保存尚未进入终态的异步面板请求。
## [br]
## @api private
var _pending_async_panel_requests: Dictionary = {}


# --- GF 生命周期方法 ---

## 初始化 UI 层级根节点并激活管理器。
## [br]
## @api public
func init() -> void:
	if _is_active:
		return
	_is_active = true
	_layer_roots.clear()
	_panel_stacks.clear()
	_ensure_default_layer_definitions()
	for layer_id: int in _layer_definitions.keys():
		_panel_stacks[layer_id] = []
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
	_panel_open_serials.clear()
	_pending_async_push_serials.clear()
	_pending_async_panel_requests.clear()


# --- 公共方法 ---

## 配置 UI 管理器。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param auto_hide_under: 所有已注册逻辑层的新默认遮挡策略。
func configure(auto_hide_under: bool = true) -> void:
	_auto_hide_under = auto_hide_under
	for layer_id: int in _layer_definitions.keys():
		var definition: GFUILayerDefinition = _get_layer_definition_value(layer_id)
		if definition != null:
			definition.auto_hide_under = auto_hide_under
			_sync_layer_visibility(layer_id)


## 注册或替换一个 UI 逻辑层。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @param definition: 层 ID、显示排序与默认遮挡策略。
## [br]
## @param replace_existing: 已存在同 ID 定义时是否替换。
## [br]
## @return 注册成功返回 true；定义无效、ID 冲突或无法创建根节点时返回 false。
func register_layer(definition: GFUILayerDefinition, replace_existing: bool = false) -> bool:
	if definition == null or not definition.is_valid():
		push_error("[GFUIUtility][ui_utility.layer_definition_invalid] Cannot register an invalid UI layer definition.")
		return false

	var layer_id: int = definition.layer_id
	if _layer_definitions.has(layer_id) and not replace_existing:
		return false

	var previous_definition: GFUILayerDefinition = _get_layer_definition_value(layer_id)
	_layer_definitions[layer_id] = definition.duplicate_definition()
	if not _panel_stacks.has(layer_id):
		_panel_stacks[layer_id] = []

	if _is_active and not _create_or_update_layer_root(layer_id):
		if previous_definition != null:
			_layer_definitions[layer_id] = previous_definition
		else:
			var _definition_erased: bool = _layer_definitions.erase(layer_id)
			var _stack_erased: bool = _panel_stacks.erase(layer_id)
		return false

	_sync_layer_visibility(layer_id)
	return true


## 检查逻辑层是否已注册。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @param layer: 逻辑层 ID。
## [br]
## @return 已注册返回 true。
func has_layer(layer: int) -> bool:
	return _layer_definitions.has(layer)


## 获取逻辑层定义副本。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @param layer: 逻辑层 ID。
## [br]
## @return 已注册层的独立定义副本；不存在时返回 null。
func get_layer_definition(layer: int) -> GFUILayerDefinition:
	var definition: GFUILayerDefinition = _get_layer_definition_value(layer)
	return definition.duplicate_definition() if definition != null else null


## 获取按逻辑层 ID 升序排列的已注册层。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @return 已注册逻辑层 ID 列表。
func get_layer_ids() -> Array[int]:
	var result: Array[int] = []
	for layer_id: int in _layer_definitions.keys():
		result.append(layer_id)
	result.sort()
	return result


## 设置指定逻辑层的新面板默认遮挡策略。
## [br]
## @api public
## [br]
## @since 8.1.0
## [br]
## @param layer: 逻辑层 ID。
## [br]
## @param auto_hide_under: 新面板未指定 hide_under 时采用的默认值。
## [br]
## @return 层存在并完成更新时返回 true。
func set_layer_auto_hide_under(layer: int, auto_hide_under: bool) -> bool:
	var definition: GFUILayerDefinition = _get_layer_definition_value(layer)
	if definition == null:
		return false
	definition.auto_hide_under = auto_hide_under
	_sync_layer_visibility(layer)
	return true


## 异步压入一个面板场景。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @param completion_callback: 可选终态回调，接收当前 GFUIPanelAsyncOperation；同步回退时可能在本方法返回前调用。
## [br]
## @return: 已接受请求的类型化句柄；路径无效时返回 null。
func push_panel_async(
	path: String,
	layer: int = Layer.POPUP,
	config_callback: Callable = Callable(),
	completion_callback: Callable = Callable()
) -> GFUIPanelAsyncOperation:
	return push_panel_async_with_options(
		path,
		layer,
		{},
		config_callback,
		completion_callback
	)


## 异步压入一个带策略选项的面板场景。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @param completion_callback: 可选终态回调，接收当前 GFUIPanelAsyncOperation；同步回退时可能在本方法返回前调用。
## [br]
## @return: 已接受请求的类型化句柄；同步回退可能返回已完成句柄，路径无效时返回 null。
## [br]
## @schema options: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func push_panel_async_with_options(
	path: String,
	layer: int = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable(),
	completion_callback: Callable = Callable()
) -> GFUIPanelAsyncOperation:
	if not _is_active:
		push_error("[GFUIUtility][ui_utility.manager_unavailable] The UI manager is not initialized or has been disposed.")
		return null
	if path.is_empty():
		push_error("[GFUIUtility][ui_utility.panel_path_empty] Panel scene path must not be empty.")
		return null

	var request_key: String = _make_async_push_key(path, layer)
	if _pending_async_push_serials.has(request_key):
		var pending_serial: int = GFVariantData.get_option_int(
			_pending_async_push_serials,
			request_key,
			-1
		)
		var pending_request_key: String = _make_async_panel_request_key(
			GFUIPanelAsyncOperation.OPERATION_PUSH,
			path,
			layer,
			pending_serial
		)
		var pending_operation: GFUIPanelAsyncOperation = (
			_get_async_panel_operation_from_request(pending_request_key)
		)
		if pending_operation != null:
			if not _connect_async_panel_completion_callback(
				pending_operation,
				completion_callback
			):
				push_error("[GFUIUtility][ui_utility.panel_terminal_connect_failed] Cannot connect the asynchronous panel request terminal callback.")
			return pending_operation
		var _stale_push_erased: bool = _pending_async_push_serials.erase(request_key)

	var previous_layer_serial: int = _get_layer_request_serial(layer)
	var request_serial: int = _reserve_layer_request_serial(layer)
	_pending_async_push_serials[request_key] = request_serial
	var async_request_key: String = _make_async_panel_request_key(
		GFUIPanelAsyncOperation.OPERATION_PUSH,
		path,
		layer,
		request_serial
	)
	var operation_handle: GFUIPanelAsyncOperation = _track_async_panel_request(
		async_request_key,
		path,
		layer,
		GFUIPanelAsyncOperation.OPERATION_PUSH,
		request_serial,
		completion_callback
	)
	if operation_handle == null:
		_clear_pending_async_push(request_key, request_serial)
		_restore_layer_request_serial_after_rejection(
			layer,
			request_serial,
			previous_layer_serial
		)
		return null
	if not operation_handle.is_pending():
		return operation_handle
	_cancel_pending_async_replace_requests_for_layer(layer)
	if not operation_handle.is_pending():
		return operation_handle

	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		push_warning("[GFUIUtility][ui_utility.asset_utility_missing] GFAssetUtility is not registered; falling back to synchronous loading.")
		var fallback_panel: Node = push_panel_with_options(path, layer, options, config_callback)
		_clear_pending_async_push(request_key, request_serial)
		_finish_async_panel_request(
			async_request_key,
			AsyncPanelLoadStatus.OPENED if fallback_panel != null else AsyncPanelLoadStatus.FAILED,
			fallback_panel
		)
		return operation_handle

	var on_loaded: Callable = func(res: Resource) -> void:
		_clear_pending_async_push(request_key, request_serial)
		if not _is_active or not _pending_async_panel_requests.has(async_request_key):
			return

		var scene: PackedScene = _get_packed_scene(res)
		if scene == null:
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.FAILED, null)
			push_error("[GFUIUtility][ui_utility.panel_instantiation_failed] Cannot instantiate panel scene: %s." % path)
			return

		var panel_instance: Node = scene.instantiate()
		if _add_panel_instance(panel_instance, layer, config_callback, options):
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.OPENED, panel_instance)
		else:
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.FAILED, null)
			if is_instance_valid(panel_instance) and not _is_panel_in_any_stack(panel_instance):
				panel_instance.queue_free()

	asset_util.load_async(path, on_loaded, "PackedScene")
	return operation_handle


## 同步压入一个面板场景。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @return 成功时返回面板实例，失败时返回 `null`。
func push_panel(path: String, layer: int = Layer.POPUP, config_callback: Callable = Callable()) -> Node:
	return push_panel_with_options(path, layer, {}, config_callback)


## 同步压入一个带策略选项的面板场景。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @return 成功时返回面板实例，失败时返回 `null`。
## [br]
## @schema options: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func push_panel_with_options(
	path: String,
	layer: int = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable()
) -> Node:
	var scene: PackedScene = _load_packed_scene(path)
	if scene == null:
		push_error("[GFUIUtility][ui_utility.panel_load_failed] Cannot load panel scene: %s." % path)
		return null

	var panel_instance: Node = scene.instantiate()
	if not _add_panel_instance(panel_instance, layer, config_callback, options):
		if is_instance_valid(panel_instance) and not _is_panel_in_any_stack(panel_instance):
			panel_instance.queue_free()
		return null

	return panel_instance


## 同步替换指定逻辑层的面板栈，不改变其他逻辑层。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @return 成功时返回面板实例，失败时返回 `null`。
func replace_layer(path: String, layer: int = Layer.POPUP, config_callback: Callable = Callable()) -> Node:
	return replace_layer_with_options(path, layer, {}, config_callback)


## 同步替换指定层级为带策略选项的面板。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @return 成功时返回面板实例，失败时返回 `null`。
## [br]
## @schema options: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func replace_layer_with_options(
	path: String,
	layer: int = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable()
) -> Node:
	return _replace_layer_synchronously(path, layer, options, config_callback, true)


## 异步替换指定层级的面板栈。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @param completion_callback: 可选终态回调，接收当前 GFUIPanelAsyncOperation；同步回退时可能在本方法返回前调用。
## [br]
## @return: 已接受请求的类型化句柄；路径无效时返回 null。
func replace_layer_async(
	path: String,
	layer: int = Layer.POPUP,
	config_callback: Callable = Callable(),
	completion_callback: Callable = Callable()
) -> GFUIPanelAsyncOperation:
	return replace_layer_async_with_options(
		path,
		layer,
		{},
		config_callback,
		completion_callback
	)


## 异步替换指定层级为带策略选项的面板。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param path: 面板场景路径。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 实例化后、入栈前的可选配置回调。
## [br]
## @param completion_callback: 可选终态回调，接收当前 GFUIPanelAsyncOperation；同步回退时可能在本方法返回前调用。
## [br]
## @return: 已接受请求的类型化句柄；同步回退可能返回已完成句柄，路径无效时返回 null。
## [br]
## @schema options: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func replace_layer_async_with_options(
	path: String,
	layer: int = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable(),
	completion_callback: Callable = Callable()
) -> GFUIPanelAsyncOperation:
	if not _is_active:
		push_error("[GFUIUtility][ui_utility.manager_unavailable] The UI manager is not initialized or has been disposed.")
		return null
	if path.is_empty():
		push_error("[GFUIUtility][ui_utility.panel_path_empty] Panel scene path must not be empty.")
		return null

	var previous_layer_serial: int = _get_layer_request_serial(layer)
	var request_serial: int = _reserve_layer_request_serial(layer)
	var async_request_key: String = _make_async_panel_request_key(
		GFUIPanelAsyncOperation.OPERATION_REPLACE,
		path,
		layer,
		request_serial
	)
	var operation_handle: GFUIPanelAsyncOperation = _track_async_panel_request(
		async_request_key,
		path,
		layer,
		GFUIPanelAsyncOperation.OPERATION_REPLACE,
		request_serial,
		completion_callback
	)
	if operation_handle == null:
		_restore_layer_request_serial_after_rejection(
			layer,
			request_serial,
			previous_layer_serial
		)
		return null
	if not operation_handle.is_pending():
		return operation_handle
	_cancel_pending_async_panel_requests_for_layer(layer, async_request_key)
	if not operation_handle.is_pending():
		return operation_handle
	if not _is_layer_request_serial_current(layer, request_serial):
		_finish_async_panel_request(
			async_request_key,
			AsyncPanelLoadStatus.CANCELLED,
			null
		)
		return operation_handle
	var asset_util: GFAssetUtility = _get_asset_util()
	if asset_util == null:
		push_warning("[GFUIUtility][ui_utility.asset_utility_missing] GFAssetUtility is not registered; falling back to synchronous loading.")
		var fallback_panel: Node = _replace_layer_synchronously(
			path,
			layer,
			options,
			config_callback,
			false
		)
		_finish_async_panel_request(
			async_request_key,
			AsyncPanelLoadStatus.OPENED if fallback_panel != null else AsyncPanelLoadStatus.FAILED,
			fallback_panel
		)
		return operation_handle

	var on_loaded: Callable = func(res: Resource) -> void:
		if not _is_active or not _is_layer_request_serial_current(layer, request_serial):
			return

		var scene: PackedScene = _get_packed_scene(res)
		if scene == null:
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.FAILED, null)
			push_error("[GFUIUtility][ui_utility.panel_instantiation_failed] Cannot instantiate panel scene: %s." % path)
			return

		var panel_instance: Node = scene.instantiate()
		_clear_layer_without_invalidating_requests(layer)
		if _add_panel_instance(panel_instance, layer, config_callback, options):
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.OPENED, panel_instance)
		else:
			_finish_async_panel_request(async_request_key, AsyncPanelLoadStatus.FAILED, null)
			if is_instance_valid(panel_instance) and not _is_panel_in_any_stack(panel_instance):
				panel_instance.queue_free()

	asset_util.load_async(path, on_loaded, "PackedScene")
	return operation_handle


## 压入一个已实例化的面板节点。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param panel_instance: 面板实例。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 入栈前的可选配置回调。
func push_panel_instance(
	panel_instance: Node,
	layer: int = Layer.POPUP,
	config_callback: Callable = Callable()
) -> void:
	push_panel_instance_with_options(panel_instance, layer, {}, config_callback)


## 压入一个已实例化且带策略选项的面板节点。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param panel_instance: 面板实例。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 入栈前的可选配置回调。
## [br]
## @schema options: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func push_panel_instance_with_options(
	panel_instance: Node,
	layer: int = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable()
) -> void:
	if not is_instance_valid(panel_instance):
		push_error("[GFUIUtility][ui_utility.panel_instance_invalid] The supplied panel_instance is invalid.")
		return

	var _added: bool = _add_panel_instance(panel_instance, layer, config_callback, options)


## 用已实例化面板替换指定层级的面板栈。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param panel_instance: 面板实例。
## [br]
## @param layer: 目标层级。
## [br]
## @param config_callback: 入栈前的可选配置回调。
func replace_layer_instance(
	panel_instance: Node,
	layer: int = Layer.POPUP,
	config_callback: Callable = Callable()
) -> void:
	replace_layer_instance_with_options(panel_instance, layer, {}, config_callback)


## 用已实例化且带策略选项的面板替换指定层级的面板栈。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param panel_instance: 面板实例。
## [br]
## @param layer: 目标层级。
## [br]
## @param options: 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @param config_callback: 入栈前的可选配置回调。
## [br]
## @schema options: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func replace_layer_instance_with_options(
	panel_instance: Node,
	layer: int = Layer.POPUP,
	options: Dictionary = {},
	config_callback: Callable = Callable()
) -> void:
	if not is_instance_valid(panel_instance):
		push_error("[GFUIUtility][ui_utility.panel_instance_invalid] The supplied panel_instance is invalid.")
		return

	clear_layer(layer)
	push_panel_instance_with_options(panel_instance, layer, options, config_callback)


## 弹出指定层级的顶部面板。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param layer: 目标层级。
## [br]
## @param do_free: 是否在弹出后释放面板。
func pop_panel(layer: int = Layer.POPUP, do_free: bool = true) -> void:
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

	_sync_layer_visibility(layer)
	_emit_navigation_changed(layer)


## 弹出面板直到指定面板成为栈顶。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param panel: 目标面板实例。
## [br]
## @param layer: 目标层级。
## [br]
## @param do_free: 是否释放被弹出的面板。
## [br]
## @return 找到目标面板并完成回退时返回 true。
func pop_to_panel(panel: Node, layer: int = Layer.POPUP, do_free: bool = true) -> bool:
	if not is_instance_valid(panel):
		return false

	_prune_layer_stack(layer)
	var stack: Array = _get_layer_stack(layer)
	if not stack.has(panel):
		return false

	while get_top_panel(layer) != panel:
		pop_panel(layer, do_free)
	return true


## 清空指定逻辑层的所有面板，不改变其他逻辑层。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param layer: 目标层级。
func clear_layer(layer: int) -> void:
	var _request_serial: int = _next_layer_request_serial(layer)
	_clear_layer_without_invalidating_requests(layer)


## 清空所有层级的所有面板。
## [br]
## @api public
func clear_all() -> void:
	for layer_idx: int in _panel_stacks.keys():
		clear_layer(layer_idx)


## 获取指定层级的顶部面板。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param layer: 目标层级。
## [br]
## @return 栈顶面板；为空时返回 `null`。
func get_top_panel(layer: int = Layer.POPUP) -> Node:
	_prune_layer_stack(layer)
	var stack: Array = _get_layer_stack(layer)
	if stack.is_empty():
		return null

	return _get_valid_panel_from_variant(stack.back())


## 获取指定层级当前面板栈的副本。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param layer: 目标层级。
## [br]
## @return 从底到顶排列的面板列表。
func get_panel_stack(layer: int = Layer.POPUP) -> Array[Node]:
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
## @since 3.17.0
## [br]
## @param layer: 目标层级。
## [br]
## @return 面板数量。
func get_stack_count(layer: int = Layer.POPUP) -> int:
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
		return _panel_stacks.has(layer) and _get_layer_stack(layer).has(panel)

	return _is_panel_in_any_stack(panel)


## 获取 UI 管理器诊断快照。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 包含各层级栈数量和栈顶名称的字典。
## [br]
## @schema return: Dictionary，包含 active、auto_hide_under、pending_async_panel_count 和 layers；layers 按逻辑层 ID 索引，每项包含 display_name、canvas_layer、auto_hide_under、count、top_panel 和 top_modal。
func get_debug_snapshot() -> Dictionary:
	var layers: Dictionary = {}
	for layer_idx: int in _panel_stacks.keys():
		_prune_layer_stack(layer_idx)
		var top_panel: Node = get_top_panel(layer_idx)
		var top_panel_name: String = ""
		if top_panel != null:
			top_panel_name = String(top_panel.name)
		var definition: GFUILayerDefinition = _get_layer_definition_value(layer_idx)
		layers[layer_idx] = {
			"display_name": String(definition.display_name) if definition != null else "",
			"canvas_layer": definition.canvas_layer if definition != null else 0,
			"auto_hide_under": definition.auto_hide_under if definition != null else _auto_hide_under,
			"count": _get_layer_stack(layer_idx).size(),
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
## @since 3.17.0
## [br]
## @param layer: 目标层级。
## [br]
## @return 对应的 `CanvasLayer` 实例。
func get_layer_root(layer: int) -> CanvasLayer:
	return _get_canvas_layer(GFVariantData.get_option_value(_layer_roots, layer))


## 设置已打开面板的策略选项。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param panel: 面板实例。
## [br]
## @param options: 面板策略，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close、metadata。
## [br]
## @schema options: Dictionary，支持 mode、modal、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
func set_panel_options(panel: Node, options: Dictionary) -> void:
	if not is_instance_valid(panel):
		return
	var layer: int = _find_panel_layer(panel)
	_panel_options[panel.get_instance_id()] = _normalize_panel_options(options, layer)
	if layer >= 0:
		_sync_layer_visibility(layer)


## 获取面板策略选项。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param panel: 面板实例。
## [br]
## @return 策略选项副本。
## [br]
## @schema return: Dictionary，包含 mode、hide_under、dismiss_on_cancel、focus_on_open、restore_focus_on_close 和 metadata。
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
		return _count_modals_in_layer(layer) > 0

	for layer_idx: int in _panel_stacks.keys():
		if _count_modals_in_layer(layer_idx) > 0:
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
## @since 3.15.0
## [br]
## @param layer: 指定层级；小于 0 时返回所有层级。
## [br]
## @return: 请求快照数组，每项包含 path、layer、operation、serial 和 operation_handle。
## [br]
## @schema return: Array，元素为 Dictionary，包含 path、layer、operation、serial 和 GFUIPanelAsyncOperation operation_handle。
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
		return _count_modals_in_layer(layer)

	var count: int = 0
	for layer_idx: int in _panel_stacks.keys():
		count += _count_modals_in_layer(layer_idx)
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
		return _request_dismiss_layer(layer, reason)

	var layer_values: Array[int] = _get_layer_ids_by_display_order()
	for index: int in range(layer_values.size() - 1, -1, -1):
		var candidate_layer: int = layer_values[index]
		if _request_dismiss_layer(candidate_layer, reason):
			return true
	return false


## 尝试把焦点保持在指定层级栈顶 modal 面板内。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param layer: 目标层级。
## [br]
## @return 发生焦点修正时返回 true。
func keep_focus_inside_top_modal(layer: int = Layer.POPUP) -> bool:
	var top_panel: Node = get_top_panel(layer)
	if not is_panel_modal(top_panel):
		return false
	var viewport: Viewport = top_panel.get_viewport()
	if viewport == null:
		return false
	var focused: Control = viewport.gui_get_focus_owner()
	if focused != null and _can_focus_control(focused) and _is_descendant_of(focused, top_panel):
		return false
	return _focus_first_control(top_panel)


# --- 私有/辅助方法 ---

## 同步加载并实例化场景，按参数选择是否使该层 pending 请求失效后再入栈。
## [br]
## @api private
func _replace_layer_synchronously(
	path: String,
	layer: int,
	options: Dictionary,
	config_callback: Callable,
	invalidate_pending_requests: bool
) -> Node:
	var scene: PackedScene = _load_packed_scene(path)
	if scene == null:
		push_error("[GFUIUtility][ui_utility.panel_load_failed] Cannot load panel scene: %s." % path)
		return null

	var panel_instance: Node = scene.instantiate()
	if invalidate_pending_requests:
		clear_layer(layer)
	else:
		_clear_layer_without_invalidating_requests(layer)
	if not _add_panel_instance(panel_instance, layer, config_callback, options):
		if is_instance_valid(panel_instance) and not _is_panel_in_any_stack(panel_instance):
			panel_instance.queue_free()
		return null

	return panel_instance

## 清空指定层的面板栈，但不取消该层正在等待的异步请求。
## [br]
## @api private
func _clear_layer_without_invalidating_requests(layer: int) -> void:
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


## 若节点仍有父节点且场景树未处于退出阶段，则将其移出父节点。
## [br]
## @api private
func _detach_node_from_tree(node: Node) -> void:
	var parent: Node = node.get_parent()
	if parent != null and not GFAutoload.is_tree_exit_in_progress():
		parent.remove_child(node)


## 为该层保留新请求序号，并取消该层其他等待中的面板请求。
## [br]
## @api private
func _next_layer_request_serial(layer: int) -> int:
	var next_serial: int = _reserve_layer_request_serial(layer)
	_cancel_pending_async_panel_requests_for_layer(layer)
	return next_serial


## 从全局递增序列取号并记录为指定层当前请求序号。
## [br]
## @api private
func _reserve_layer_request_serial(layer: int) -> int:
	var next_serial: int = _next_async_panel_request_serial
	_next_async_panel_request_serial += 1
	_layer_request_serials[layer] = next_serial
	return next_serial


## 仅当拒绝的序号仍是当前值时，恢复之前序号或移除该层记录。
## [br]
## @api private
func _restore_layer_request_serial_after_rejection(
	layer: int,
	rejected_serial: int,
	previous_serial: int
) -> void:
	if not _is_layer_request_serial_current(layer, rejected_serial):
		return
	if previous_serial > 0:
		_layer_request_serials[layer] = previous_serial
	else:
		var _erased: bool = _layer_request_serials.erase(layer)


## 读取层请求序号；未记录时返回 0。
## [br]
## @api private
func _get_layer_request_serial(layer: int) -> int:
	return GFVariantData.get_option_int(_layer_request_serials, layer, 0)


## 判断给定请求序号是否仍是指定层当前记录的序号。
## [br]
## @api private
func _is_layer_request_serial_current(layer: int, request_serial: int) -> bool:
	return _get_layer_request_serial(layer) == request_serial


## 组合层级与场景路径，生成异步 push 去重键。
## [br]
## @api private
func _make_async_push_key(path: String, layer: int) -> String:
	return "%d:%s" % [layer, path]


## 组合操作、层级、请求序号和路径，生成异步面板请求键。
## [br]
## @api private
func _make_async_panel_request_key(operation: StringName, path: String, layer: int, request_serial: int) -> String:
	return "%s:%d:%d:%s" % [String(operation), layer, request_serial, path]


## 配置终态句柄并登记请求；配置或回调连接失败时返回 null。
## [br]
## @api private
func _track_async_panel_request(
	request_key: String,
	path: String,
	layer: int,
	operation: StringName,
	request_serial: int,
	completion_callback: Callable
) -> GFUIPanelAsyncOperation:
	var operation_handle: GFUIPanelAsyncOperation = GFUIPanelAsyncOperation.new()
	if not operation_handle.configure_for_framework(request_serial, path, layer, operation):
		push_error("[GFUIUtility][ui_utility.panel_request_configuration_failed] Cannot configure the asynchronous panel request handle.")
		return null
	if not _connect_async_panel_completion_callback(operation_handle, completion_callback):
		push_error("[GFUIUtility][ui_utility.panel_terminal_connect_failed] Cannot connect the asynchronous panel request terminal callback.")
		return null
	_pending_async_panel_requests[request_key] = {
		"path": path,
		"layer": layer,
		"operation": operation,
		"serial": request_serial,
		"operation_handle": operation_handle,
	}
	panel_async_load_started.emit(path, layer, operation)
	return operation_handle


## 将有效完成回调以一次性连接方式接到异步面板句柄。
## [br]
## @api private
func _connect_async_panel_completion_callback(
	operation_handle: GFUIPanelAsyncOperation,
	completion_callback: Callable
) -> bool:
	if not completion_callback.is_valid():
		return true
	if operation_handle.completed.is_connected(completion_callback):
		return true
	var connection_error: Error = operation_handle.completed.connect(
		completion_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	return connection_error == OK


## 验证成功面板仍在目标层栈中，移除请求记录并完成句柄及结束信号。
## [br]
## @api private
func _finish_async_panel_request(request_key: String, status: int, panel: Node) -> void:
	if not _pending_async_panel_requests.has(request_key):
		return

	var request: Dictionary = _get_pending_async_panel_request(request_key)
	var terminal_status: int = status
	var terminal_panel: Node = panel
	if terminal_status == AsyncPanelLoadStatus.OPENED:
		var panel_is_open: bool = _get_valid_panel_from_variant(terminal_panel) != null
		if panel_is_open:
			var request_layer: int = GFVariantData.get_option_int(request, "layer", -1)
			panel_is_open = _get_layer_stack(request_layer).has(terminal_panel)
		if not panel_is_open:
			terminal_status = AsyncPanelLoadStatus.FAILED
			terminal_panel = null
	var operation_handle: GFUIPanelAsyncOperation = _get_ui_panel_async_operation_value(
		request.get("operation_handle")
	)
	if (
		GFVariantData.get_option_string_name(request, "operation", &"")
		== GFUIPanelAsyncOperation.OPERATION_PUSH
	):
		_clear_pending_async_push(
			_make_async_push_key(
				GFVariantData.get_option_string(request, "path", ""),
				GFVariantData.get_option_int(request, "layer", -1)
			),
			GFVariantData.get_option_int(request, "serial", -1)
		)
	var _erased: bool = _pending_async_panel_requests.erase(request_key)
	if (
		operation_handle == null
		or not operation_handle.complete_for_framework(terminal_status, terminal_panel)
	):
		push_error("[GFUIUtility][ui_utility.panel_terminal_failed] The asynchronous panel request handle cannot enter a terminal state.")
		return
	panel_async_load_finished.emit(
		GFVariantData.get_option_string(request, "path", ""),
		GFVariantData.get_option_int(request, "layer", -1),
		GFVariantData.get_option_string_name(request, "operation", &""),
		terminal_status,
		terminal_panel
	)


## 仅当键当前仍对应给定序号时清除异步 push 占位。
## [br]
## @api private
func _clear_pending_async_push(request_key: String, request_serial: int) -> void:
	if GFVariantData.get_option_int(_pending_async_push_serials, request_key, -1) == request_serial:
		var _erased: bool = _pending_async_push_serials.erase(request_key)


## 取消指定层的 pending 请求，可排除当前正在启动的请求键。
## [br]
## @api private
func _cancel_pending_async_panel_requests_for_layer(
	layer: int,
	excluded_request_key: String = ""
) -> void:
	for request_key: String in _pending_async_panel_requests.keys():
		if request_key == excluded_request_key:
			continue
		var request: Dictionary = _get_pending_async_panel_request(request_key)
		if GFVariantData.get_option_int(request, "layer", -1) == layer:
			_finish_async_panel_request(request_key, AsyncPanelLoadStatus.CANCELLED, null)


## 取消指定层所有尚未完成的 replace 面板请求。
## [br]
## @api private
func _cancel_pending_async_replace_requests_for_layer(layer: int) -> void:
	for request_key: String in _pending_async_panel_requests.keys():
		var request: Dictionary = _get_pending_async_panel_request(request_key)
		if GFVariantData.get_option_int(request, "layer", -1) != layer:
			continue
		if (
			GFVariantData.get_option_string_name(request, "operation", &"")
			!= GFUIPanelAsyncOperation.OPERATION_REPLACE
		):
			continue
		_finish_async_panel_request(request_key, AsyncPanelLoadStatus.CANCELLED, null)


## 将所有 pending 异步面板请求以 CANCELLED 状态终结。
## [br]
## @api private
func _cancel_all_pending_async_panel_requests() -> void:
	for request_key: String in _pending_async_panel_requests.keys():
		_finish_async_panel_request(request_key, AsyncPanelLoadStatus.CANCELLED, null)


## 按已注册层 ID 创建或更新所有 CanvasLayer 根节点。
## [br]
## @api private
func _create_layers() -> void:
	for layer_id: int in get_layer_ids():
		var _created: bool = _create_or_update_layer_root(layer_id)


## 按层定义更新现有 CanvasLayer，或将新节点加入 SceneTree 根节点。
## [br]
## @api private
func _create_or_update_layer_root(layer: int) -> bool:
	var definition: GFUILayerDefinition = _get_layer_definition_value(layer)
	if definition == null:
		return false

	var canvas: CanvasLayer = get_layer_root(layer)
	if is_instance_valid(canvas):
		canvas.layer = definition.canvas_layer
		canvas.name = _make_layer_node_name(definition)
		return true

	var main_loop: MainLoop = Engine.get_main_loop()
	if not main_loop is SceneTree:
		push_error("[GFUIUtility][ui_utility.scene_tree_missing] SceneTree is unavailable.")
		return false

	var scene_tree: SceneTree = main_loop
	canvas = CanvasLayer.new()
	canvas.layer = definition.canvas_layer
	canvas.name = _make_layer_node_name(definition)
	scene_tree.root.add_child(canvas)
	_layer_roots[layer] = canvas
	return true


## 为 HUD、POPUP、TOP 注册当前尚未定义的预置层。
## [br]
## @api private
func _ensure_default_layer_definitions() -> void:
	_register_default_layer_if_missing(Layer.HUD, &"HUD", _DEFAULT_HUD_CANVAS_LAYER)
	_register_default_layer_if_missing(Layer.POPUP, &"POPUP", _DEFAULT_POPUP_CANVAS_LAYER)
	_register_default_layer_if_missing(Layer.TOP, &"TOP", _DEFAULT_TOP_CANVAS_LAYER)


## 仅在层 ID 尚未注册时创建并保存默认层定义。
## [br]
## @api private
func _register_default_layer_if_missing(layer: int, display_name: StringName, canvas_layer: int) -> void:
	if _layer_definitions.has(layer):
		return
	var definition: GFUILayerDefinition = GFUILayerDefinition.new().configure(
		layer,
		display_name,
		canvas_layer,
		_auto_hide_under
	)
	_layer_definitions[layer] = definition


## 根据层显示名生成节点名；空名时使用层 ID 作为后缀。
## [br]
## @api private
func _make_layer_node_name(definition: GFUILayerDefinition) -> StringName:
	var suffix: String = String(definition.display_name).validate_node_name()
	if suffix.is_empty():
		suffix = "LAYER_%d" % definition.layer_id
	return StringName("GFUILayer_%s" % suffix)


## 校验层根节点和面板身份，配置并入栈后同步可见性、焦点及导航通知。
## 每个用户回调或信号后再次确认面板仍为本次打开身份，避免继续处理被替换的节点。
## [br]
## @api private
func _add_panel_instance(
	panel: Node,
	layer: int,
	config_callback: Callable,
	options: Dictionary = {}
) -> bool:
	if not _is_active:
		push_warning("[GFUIUtility][ui_utility.push_after_destruction] The current UI manager was destroyed; panel push ignored.")
		return false

	var canvas: CanvasLayer = get_layer_root(layer)
	if not is_instance_valid(canvas):
		push_error("[GFUIUtility][ui_utility.canvas_layer_unavailable] The target CanvasLayer is unavailable.")
		return false

	_prune_all_layer_stacks()
	if _is_panel_in_any_stack(panel):
		push_warning("[GFUIUtility][ui_utility.panel_already_stacked] The panel instance is already in the UI stack; duplicate push ignored.")
		return false

	_prune_layer_stack(layer)
	var stack: Array = _get_layer_stack(layer)
	var normalized_options: Dictionary = _normalize_panel_options(options, layer)

	if config_callback.is_valid():
		config_callback.call(panel)
		if not is_instance_valid(panel):
			push_warning("[GFUIUtility][ui_utility.panel_destroyed_by_callback] config_callback destroyed the panel instance; this push was cancelled.")
			return false
		if not _is_active or not is_instance_valid(canvas) or get_layer_root(layer) != canvas:
			return false
		if _is_panel_in_any_stack(panel):
			return false

	_capture_previous_focus(panel, normalized_options, canvas.get_viewport())
	if panel.get_parent() != null and panel.get_parent() != canvas:
		panel.get_parent().remove_child(panel)
	if panel.get_parent() != canvas:
		canvas.add_child(panel)

	stack.push_back(panel)
	var open_serial: int = _next_panel_open_serial
	_next_panel_open_serial += 1
	_panel_open_serials[panel.get_instance_id()] = open_serial
	_panel_options[panel.get_instance_id()] = normalized_options
	var _tree_exited_connected: Error = panel.tree_exited.connect(
		_on_panel_tree_exited.bind(panel, layer),
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	_sync_layer_visibility(layer)
	if _get_valid_panel_from_variant(panel) == null or not _is_panel_open_current(panel, layer, open_serial):
		return false
	_apply_open_focus_policy(panel, normalized_options)
	if _get_valid_panel_from_variant(panel) == null or not _is_panel_open_current(panel, layer, open_serial):
		return false
	panel_opened.emit(panel, layer)
	if not is_instance_valid(panel) or not _is_panel_open_current(panel, layer, open_serial):
		return false
	_emit_navigation_changed(layer)
	return _get_valid_panel_from_variant(panel) != null and _is_panel_open_current(panel, layer, open_serial)


## 清理所有已注册层栈中的失效面板条目。
## [br]
## @api private
func _prune_all_layer_stacks() -> void:
	for layer_idx: int in _panel_stacks.keys():
		_prune_layer_stack(layer_idx)


## 将值解析为未释放且未排队删除的面板节点。
## [br]
## @api private
func _get_valid_panel_from_variant(value: Variant) -> Node:
	var panel: Node = _get_live_node(value)
	if panel == null:
		return null
	if panel.is_queued_for_deletion():
		return null
	return panel


## 从层栈移除失效项，对排队删除的面板执行关闭清理并刷新显示状态。
## [br]
## @api private
func _prune_layer_stack(layer: int) -> void:
	var stack: Array = _get_layer_stack(layer)
	var removed_any: bool = false
	var queued_panels: Array[Node] = []
	for index: int in range(stack.size() - 1, -1, -1):
		var panel: Node = _get_live_node(stack[index])
		if panel == null:
			removed_any = true
			stack.remove_at(index)
			continue
		if panel.is_queued_for_deletion():
			removed_any = true
			stack.remove_at(index)
			queued_panels.append(panel)
	for panel: Node in queued_panels:
		_handle_panel_closed(panel)
		panel_closed.emit(panel, layer)
	if removed_any:
		_sync_layer_visibility(layer)


## 检查面板实例是否已经出现在任一逻辑层栈中。
## [br]
## @api private
func _is_panel_in_any_stack(panel: Node) -> bool:
	for stack: Array in _panel_stacks.values():
		if stack.has(panel):
			return true
	return false


## 从栈顶向下更新可见性；首个启用 hide_under 的上层面板隐藏其下方项。
## [br]
## @api private
func _sync_layer_visibility(layer: int) -> void:
	var stack: Array = _get_layer_stack(layer)
	var hidden_by_upper_panel: bool = false
	for index: int in range(stack.size() - 1, -1, -1):
		var panel: Node = _get_valid_panel_from_variant(stack[index])
		var canvas_item: CanvasItem = _get_canvas_item(panel)
		if canvas_item == null:
			continue
		canvas_item.visible = not hidden_by_upper_panel
		if not hidden_by_upper_panel:
			var options: Dictionary = _get_panel_options_for_id(panel.get_instance_id())
			if GFVariantData.get_option_bool(options, "hide_under", _get_layer_auto_hide_under(layer)):
				hidden_by_upper_panel = true


## 发出层级导航变化信号，并附带当前栈顶面板。
## [br]
## @api private
func _emit_navigation_changed(layer: int) -> void:
	navigation_changed.emit(layer, get_top_panel(layer))


## 向顶层面板发送关闭请求；按选项调用 resolve_cancel 或弹出该面板。
## [br]
## @api private
func _request_dismiss_layer(layer: int, reason: String) -> bool:
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


## 清理层栈后统计其中仍有效且为 Modal 模式的面板数。
## [br]
## @api private
func _count_modals_in_layer(layer: int) -> int:
	_prune_layer_stack(layer)
	var count: int = 0
	for panel_variant: Variant in _get_layer_stack(layer):
		var panel: Node = _get_valid_panel_from_variant(panel_variant)
		if panel != null and is_panel_modal(panel):
			count += 1
	return count


## 归一化交互模式及遮挡、取消、焦点和元数据选项。
## [br]
## @api private
func _normalize_panel_options(options: Dictionary, layer: int) -> Dictionary:
	var is_modal: bool = GFVariantData.get_option_bool(options, "modal", false)
	var mode: int = GFVariantData.get_option_int(options, "mode", PanelMode.MODAL if is_modal else PanelMode.NORMAL)
	mode = clampi(mode, PanelMode.NORMAL, PanelMode.MODAL)
	return {
		"mode": mode,
		"hide_under": GFVariantData.get_option_bool(options, "hide_under", _get_layer_auto_hide_under(layer)),
		"dismiss_on_cancel": GFVariantData.get_option_bool(options, "dismiss_on_cancel", mode == PanelMode.MODAL),
		"focus_on_open": GFVariantData.get_option_bool(options, "focus_on_open", mode == PanelMode.MODAL),
		"restore_focus_on_close": GFVariantData.get_option_bool(options, "restore_focus_on_close", mode == PanelMode.MODAL),
		"metadata": GFVariantData.get_option_dictionary(options, "metadata"),
	}


## 启用关闭还原焦点时，将当前焦点控件以弱引用关联到新面板。
## [br]
## @api private
func _capture_previous_focus(
	panel: Node,
	options: Dictionary,
	viewport: Viewport
) -> void:
	if not GFVariantData.get_option_bool(options, "restore_focus_on_close", false):
		return
	if viewport == null:
		return
	var focused: Control = viewport.gui_get_focus_owner()
	if focused != null:
		_previous_focus_by_panel_id[panel.get_instance_id()] = weakref(focused)


## 选项启用 focus_on_open 时尝试聚焦面板内第一个可聚焦控件。
## [br]
## @api private
func _apply_open_focus_policy(panel: Node, options: Dictionary) -> void:
	if GFVariantData.get_option_bool(options, "focus_on_open", false):
		var _focused: bool = _focus_first_control(panel)


## 清除面板打开身份和选项，并按策略恢复之前的焦点控件。
## [br]
## @api private
func _handle_panel_closed(panel: Node) -> void:
	var panel_id: int = panel.get_instance_id()
	var _serial_erased: bool = _panel_open_serials.erase(panel_id)
	var options: Dictionary = _get_panel_options_for_id(panel_id)
	if GFVariantData.get_option_bool(options, "restore_focus_on_close", false):
		_restore_previous_focus(panel_id)
	var _options_erased: bool = _panel_options.erase(panel_id)
	var _focus_erased: bool = _previous_focus_by_panel_id.erase(panel_id)


## 从指定面板记录解析前序控件；控件仍在场景树中时调用 grab_focus。
## [br]
## @api private
func _restore_previous_focus(panel_id: int) -> void:
	var previous_ref: WeakRef = _get_weak_ref(GFVariantData.get_option_value(_previous_focus_by_panel_id, panel_id))
	if previous_ref == null:
		return
	var previous: Control = _get_live_control_from_ref(previous_ref)
	if is_instance_valid(previous) and previous.is_inside_tree():
		previous.grab_focus()


## 在仍打开的面板子树中按节点遍历顺序寻找并聚焦第一个可聚焦控件。
## [br]
## @api private
func _focus_first_control(panel: Node) -> bool:
	if not is_instance_valid(panel):
		return false
	var open_serial: int = GFVariantData.get_option_int(_panel_open_serials, panel.get_instance_id())
	return _focus_first_control_in_branch(panel, panel, _find_panel_layer(panel), open_serial)


## 递归检查子树中的控件；每次聚焦后确认原面板打开身份仍有效。
## [br]
## @api private
func _focus_first_control_in_branch(root: Node, panel: Node, layer: int, open_serial: int) -> bool:
	if not is_instance_valid(panel) or not _is_current_focus_panel(panel, layer, open_serial):
		return false
	if not is_instance_valid(root) or root.is_queued_for_deletion() or not _is_descendant_of(root, panel):
		return false
	if root is Control:
		var control: Control = root
		if _can_focus_control(control):
			control.grab_focus()
			if not is_instance_valid(panel) or not _is_current_focus_panel(panel, layer, open_serial):
				return false
			var focused: Control = panel.get_viewport().gui_get_focus_owner()
			if _can_focus_control(focused) and _is_descendant_of(focused, panel):
				return true

	if not is_instance_valid(root) or root.is_queued_for_deletion() or not _is_descendant_of(root, panel):
		return false
	for child: Node in root.get_children():
		if not is_instance_valid(panel) or not _is_current_focus_panel(panel, layer, open_serial):
			return false
		if is_instance_valid(child) and _focus_first_control_in_branch(child, panel, layer, open_serial):
			return true
	return false


## 判断面板仍在指定层栈中且其打开序号匹配给定身份。
## [br]
## @api private
func _is_panel_open_current(panel: Node, layer: int, open_serial: int) -> bool:
	if not is_instance_valid(panel):
		return false
	if open_serial <= 0 or GFVariantData.get_option_int(_panel_open_serials, panel.get_instance_id()) != open_serial:
		return false
	return _get_layer_stack(layer).has(panel)


## 检查打开身份有效、节点仍在树中且面板仍为该层有效栈顶。
## [br]
## @api private
func _is_current_focus_panel(panel: Node, layer: int, open_serial: int) -> bool:
	if not _is_panel_open_current(panel, layer, open_serial):
		return false
	if not panel.is_inside_tree() or panel.is_queued_for_deletion():
		return false
	var stack: Array = _get_layer_stack(layer)
	return not stack.is_empty() and _get_valid_panel_from_variant(stack.back()) == panel


## 排除树外或排队删除的控件及祖先，再查询框架焦点工具的控件条件。
## [br]
## @api private
func _can_focus_control(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_inside_tree():
		return false
	var ancestor: Node = control
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	return GFControlFocusUtility.is_focusable_control_for_framework(control)


## 沿父节点链检查 node 是否为 ancestor 本身或其后代。
## [br]
## @api private
func _is_descendant_of(node: Node, ancestor: Node) -> bool:
	var current: Node = node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false


## 从当前架构取得 GFAssetUtility；架构缺失或类型不符时返回 null。
## [br]
## @api private
func _get_asset_util() -> GFAssetUtility:
	var arch: GFArchitecture = _get_architecture_or_null()
	if arch == null:
		return null

	var util: Variant = arch.get_utility(GFAssetUtility)
	if util is GFAssetUtility:
		return util
	return null


# --- 私有/辅助方法 (类型收口) ---

## 从层栈映射读取数组；值不是 Array 时返回空数组。
## [br]
## @api private
func _get_layer_stack(layer: int) -> Array:
	var value: Variant = GFVariantData.get_option_value(_panel_stacks, layer, [])
	if value is Array:
		var stack: Array = value
		return stack
	return []


## 从层定义映射读取 GFUILayerDefinition；缺失或类型不符时返回 null。
## [br]
## @api private
func _get_layer_definition_value(layer: int) -> GFUILayerDefinition:
	var value: Variant = GFVariantData.get_option_value(_layer_definitions, layer)
	if value is GFUILayerDefinition:
		var definition: GFUILayerDefinition = value
		return definition
	return null


## 返回指定层策略；没有有效层定义时使用全局默认值。
## [br]
## @api private
func _get_layer_auto_hide_under(layer: int) -> bool:
	var definition: GFUILayerDefinition = _get_layer_definition_value(layer)
	return definition.auto_hide_under if definition != null else _auto_hide_under


## 查找包含面板的逻辑层；未找到时返回 -1。
## [br]
## @api private
func _find_panel_layer(panel: Node) -> int:
	for layer_id: int in _panel_stacks.keys():
		if _get_layer_stack(layer_id).has(panel):
			return layer_id
	return -1


## 获取已注册层 ID，并按 CanvasLayer.layer 与 ID 排序。
## [br]
## @api private
func _get_layer_ids_by_display_order() -> Array[int]:
	var result: Array[int] = get_layer_ids()
	result.sort_custom(_is_layer_before)
	return result


## 比较两个层的绘制顺序；CanvasLayer.layer 相同时按逻辑层 ID 排序。
## [br]
## @api private
func _is_layer_before(left: int, right: int) -> bool:
	var left_definition: GFUILayerDefinition = _get_layer_definition_value(left)
	var right_definition: GFUILayerDefinition = _get_layer_definition_value(right)
	var left_canvas_layer: int = left_definition.canvas_layer if left_definition != null else 0
	var right_canvas_layer: int = right_definition.canvas_layer if right_definition != null else 0
	if left_canvas_layer == right_canvas_layer:
		return left < right
	return left_canvas_layer < right_canvas_layer


## 按面板实例 ID 读取选项字典；缺失或非字典值返回空字典。
## [br]
## @api private
func _get_panel_options_for_id(panel_id: int) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_panel_options, panel_id, {}))


## 按请求键读取 pending 异步面板条目；缺失时返回空字典。
## [br]
## @api private
func _get_pending_async_panel_request(request_key: String) -> Dictionary:
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(_pending_async_panel_requests, request_key, {}))


## 从 pending 请求条目取出并收窄异步面板操作句柄。
## [br]
## @api private
func _get_async_panel_operation_from_request(request_key: String) -> GFUIPanelAsyncOperation:
	var request: Dictionary = _get_pending_async_panel_request(request_key)
	return _get_ui_panel_async_operation_value(request.get("operation_handle"))


## 将 Variant 收窄为 GFUIPanelAsyncOperation；类型不符时返回 null。
## [br]
## @api private
static func _get_ui_panel_async_operation_value(value: Variant) -> GFUIPanelAsyncOperation:
	if value is GFUIPanelAsyncOperation:
		var operation_handle: GFUIPanelAsyncOperation = value
		return operation_handle
	return null


## 委托实例守卫解析 Variant 中仍有效的 Node。
## [br]
## @api private
func _get_live_node(value: Variant) -> Node:
	var result: Variant = _INSTANCE_GUARD.call("_get_live_node", value)
	if result is Node:
		var node: Node = result
		return node
	return null


## 委托实例守卫解析仍有效的弱引用 Control。
## [br]
## @api private
func _get_live_control_from_ref(object_ref: WeakRef) -> Control:
	var result: Variant = _INSTANCE_GUARD.call("_get_live_control_from_ref", object_ref)
	if result is Control:
		var control: Control = result
		return control
	return null


## 将 Variant 收窄为 CanvasLayer；类型不符时返回 null。
## [br]
## @api private
static func _get_canvas_layer(value: Variant) -> CanvasLayer:
	if value is CanvasLayer:
		var canvas: CanvasLayer = value
		return canvas
	return null


## 将 Variant 收窄为 CanvasItem；类型不符时返回 null。
## [br]
## @api private
static func _get_canvas_item(value: Variant) -> CanvasItem:
	if value is CanvasItem:
		var canvas_item: CanvasItem = value
		return canvas_item
	return null


## 将 Variant 收窄为 PackedScene；类型不符时返回 null。
## [br]
## @api private
static func _get_packed_scene(value: Variant) -> PackedScene:
	if value is PackedScene:
		var scene: PackedScene = value
		return scene
	return null


## 从路径加载资源并收窄为 PackedScene；其他资源类型返回 null。
## [br]
## @api private
static func _load_packed_scene(path: String) -> PackedScene:
	var resource: Resource = load(path)
	return _get_packed_scene(resource)


## 将 Variant 收窄为 WeakRef；类型不符时返回 null。
## [br]
## @api private
static func _get_weak_ref(value: Variant) -> WeakRef:
	if value is WeakRef:
		var object_ref: WeakRef = value
		return object_ref
	return null


# --- 信号处理函数 ---

## 面板离开场景树时，从对应层栈移除并发出关闭、可见性及导航更新。
## [br]
## @api private
func _on_panel_tree_exited(panel: Node, layer: int) -> void:
	if not _panel_stacks.has(layer):
		return

	var stack: Array = _get_layer_stack(layer)
	var was_open: bool = stack.has(panel)
	if not was_open:
		return

	stack.erase(panel)
	_handle_panel_closed(panel)
	panel_closed.emit(panel, layer)
	_sync_layer_visibility(layer)
	_emit_navigation_changed(layer)
