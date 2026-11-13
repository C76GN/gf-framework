## GFUIRouterUtility: 基于路由 ID 的 UI 导航工具。
##
## 作为 GFUIUtility 之上的轻量路由层，负责把稳定 route_id 映射到面板场景、
## 打开参数、层级和历史记录，不接管具体页面业务或动画表现。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFUIRouterUtility
extends GFUtility


# --- 信号 ---

## 路由打开请求发出时触发。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param route_id: 路由标识。
## [br]
## @param operation: 打开操作。
## [br]
## @param params: 路由参数。
## [br]
## @schema params: Dictionary，本次打开路由携带的项目自定义参数。
signal route_open_requested(
	route_id: StringName,
	operation: Operation,
	params: Dictionary
)

## 路由面板成功打开后触发。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param route_id: 路由标识。
## [br]
## @param panel: 面板实例。
## [br]
## @param operation: 打开操作。
signal route_opened(
	route_id: StringName,
	panel: Node,
	operation: Operation
)

## 路由打开失败时触发。
## [br]
## @api public
## [br]
## @param route_id: 路由标识。
## [br]
## @param reason: 失败原因。
signal route_open_failed(route_id: StringName, reason: String)

## 异步路由请求进入终态时触发。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param result: 隔离的类型化终态结果。
signal route_operation_completed(result: GFUIRouteResult)

## 路由返回完成时触发。
## [br]
## @api public
## [br]
## @param route_id: 被弹出的路由标识。
## [br]
## @param layer: 所在层级。
signal route_back_completed(route_id: StringName, layer: int)


# --- 枚举 ---

## 路由打开操作。
## [br]
## @api public
enum Operation {
	## 压入当前层级栈顶。
	PUSH,
	## 替换当前层级栈。
	REPLACE,
}


# --- 常量 ---

## 为历史面板弱引用提供存活节点解析。
## [br]
## @api private
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")

## 不执行路由预加载，直接提交异步面板请求。
## [br]
## @api public
## [br]
## @since 10.0.0
const PRELOAD_NONE: StringName = &"none"

## 尽力执行路由预加载；规划或加载失败时仍继续打开面板。
## [br]
## @api public
## [br]
## @since 10.0.0
const PRELOAD_BEST_EFFORT: StringName = &"best_effort"

## 要求路由预加载完整成功；否则不提交面板请求。
## [br]
## @api public
## [br]
## @since 10.0.0
const PRELOAD_REQUIRED: StringName = &"required"


# --- 公共变量 ---

## 路由历史最大保留数量。小于等于 0 表示不保留历史。
## [br]
## @api public
var max_history: int = 64


# --- 私有变量 ---

## 以规范化 route_id 为键保存已注册路由资源。
## [br]
## @api private
var _routes: Dictionary = {}

## 以弱引用保存可选的 UI 栈工具；失效时从架构重新查找。
## [br]
## @api private
var _ui_utility_ref: WeakRef = null

## 按打开顺序保存路由历史；面板通过弱引用关联。
## [br]
## @api private
var _history: Array[Dictionary] = []

## 以路径、层级和操作键索引尚未完成的异步路由请求。
## [br]
## @api private
var _pending_async_routes: Dictionary = {}

## 为当前实例内的新异步路由句柄分配单调递增的请求 ID。
## [br]
## @api private
var _next_async_request_id: int = 1

## 标记路由工具是否已进入释放状态。
## [br]
## @api private
var _disposed: bool = false

## 路由计时与内容准备预算使用同一个单调时钟。
## [br]
## @api private
var _clock: GFClock = GFClock.new()


# --- GF 生命周期方法 ---

## 初始化路由表、UI 工具引用和历史记录。
## 重复初始化会先以 dispose 语义终结旧 pending 请求；请求 ID 在同一实例内保持单调，
## 避免旧异步回调或临时预加载组与新生命周期串线。
## [br]
## @api public
## [br]
## @since 3.17.0
func init() -> void:
	_disposed = true
	if not _pending_async_routes.is_empty():
		_finish_pending_routes_for_dispose()
	_routes.clear()
	_ui_utility_ref = null
	_history.clear()
	_pending_async_routes.clear()
	_disposed = false


## 释放路由表、UI 工具引用和历史记录。
## [br]
## @api public
func dispose() -> void:
	_disposed = true
	_finish_pending_routes_for_dispose()
	_routes.clear()
	_ui_utility_ref = null
	_history.clear()
	_pending_async_routes.clear()


## 清理失效的 owner/scope，并处理已提交导航的内容就绪超时。
## Node owner 和 GFAsyncScope 取消通过信号处理；普通 Object 与正常结束作用域依赖本帧检查。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @param _delta: 本帧时间增量；生命周期清理不依赖具体数值。
func tick(_delta: float) -> void:
	_prune_pending_route_lifecycles()
	_prune_pending_navigation()


# --- 公共方法 ---

## 在没有 pending 请求时替换单调时间来源。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param clock: 非空时钟；默认服务直接使用 GFClock。
## [br]
## @return 未释放且没有 pending 请求时为 true。
func set_clock(clock: GFClock) -> bool:
	if (
		_disposed
		or clock == null
		or not _pending_async_routes.is_empty()
	):
		return false
	_clock = clock
	return true


## 配置路由表和可选 UI 工具实例。
## [br]
## @api public
## [br]
## @param routes: 路由资源列表。
## [br]
## @param ui_utility: 可选 GFUIUtility；为空时从当前架构查找。
func configure(routes: Array[GFUIRoute] = [], ui_utility: GFUIUtility = null) -> void:
	_routes.clear()
	for route: GFUIRoute in routes:
		var _registered: bool = register_route(route)
	set_ui_utility(ui_utility)


## 设置路由使用的 UI 栈工具。
## [br]
## @api public
## [br]
## @param ui_utility: UI 栈工具实例。
func set_ui_utility(ui_utility: GFUIUtility) -> void:
	var current_ui_utility: GFUIUtility = _get_ui_utility()
	if (not _pending_async_routes.is_empty() and ui_utility != current_ui_utility):
		push_warning("[GFUIRouterUtility][ui_router_utility.ui_utility_change_while_pending] Cannot replace GFUIUtility while asynchronous routing requests exist.")
		return
	_ui_utility_ref = weakref(ui_utility) if ui_utility != null else null


## 注册一个路由。
## [br]
## @api public
## [br]
## @param route: 路由资源。
## [br]
## @return 注册成功返回 true。
func register_route(route: GFUIRoute) -> bool:
	if route == null or not route.is_valid_route():
		return false

	_routes[route.get_route_id()] = route
	return true


## 批量注册路由。
## [br]
## @api public
## [br]
## @param routes: 路由资源列表。
func register_routes(routes: Array[GFUIRoute]) -> void:
	for route: GFUIRoute in routes:
		var _registered: bool = register_route(route)


## 注销路由。
## [br]
## @api public
## [br]
## @param route_id: 路由标识。
func unregister_route(route_id: StringName) -> void:
	var _erased: bool = _routes.erase(_normalize_route_id(route_id))


## 清空路由表。
## [br]
## @api public
func clear_routes() -> void:
	_routes.clear()


## 获取路由资源。
## [br]
## @api public
## [br]
## @param route_id: 路由标识。
## [br]
## @return 路由资源；不存在时返回 null。
func get_route(route_id: StringName) -> GFUIRoute:
	return _get_route_value(
		GFVariantData.get_option_value(
			_routes,
			_normalize_route_id(route_id)
		)
	)


## 检查路由是否已注册。
## [br]
## @api public
## [br]
## @param route_id: 路由标识。
## [br]
## @return 已注册返回 true。
func has_route(route_id: StringName) -> bool:
	return get_route(route_id) != null


## 获取所有路由标识。
## [br]
## @api public
## [br]
## @return 路由标识列表。
func get_route_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for key: Variant in _routes.keys():
		var _appended: bool = ids.append(GFVariantData.to_text(key))
	ids.sort()
	return ids


## 从已注册路由构建有界的页面资源预加载计划。
## 结果中的 asset_plan 可直接交给 GFAssetUtility.preload_plan_async()。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param source_route_id: 起始路由标识。
## [br]
## @param options: 传给 GFUIRoutePreloadUtility.build_plan() 的选项。
## [br]
## @schema options: Dictionary，可包含 max_depth、max_catalog_routes、max_routes、max_edges、include_source、fixed_route_ids、group_id、plan_id、pin_cache、lane_id、max_concurrent_loads、check_exists 和 metadata。
## [br]
## @return 路由预加载结果。
## [br]
## @schema return: Dictionary，结构同 GFUIRoutePreloadUtility.build_plan()，其中 asset_plan 为 GFAssetPreloadPlan。
func build_preload_plan(source_route_id: StringName, options: Dictionary = {}) -> Dictionary:
	var max_catalog_routes: int = maxi(
		GFVariantData.get_option_int(
			options,
			"max_catalog_routes",
			GFUIRoutePreloadUtility.DEFAULT_MAX_CATALOG_ROUTES
		),
		0
	)
	var planner_input_limit: int = max_catalog_routes
	if _routes.size() > max_catalog_routes:
		planner_input_limit += 1
	return GFUIRoutePreloadUtility.build_plan(
		_get_registered_routes(planner_input_limit),
		source_route_id,
		options
	)


## 压入一个路由面板。
## [br]
## @api public
## [br]
## @param route_id: 路由标识。
## [br]
## @param params: 路由参数。
## [br]
## @param option_overrides: 面板选项覆盖。
## [br]
## @param config_callback: 面板实例化后、入栈前的额外配置回调。
## [br]
## @return 成功时返回面板实例。
## [br]
## @schema params: Dictionary，本次打开路由携带的项目自定义参数。
## [br]
## @schema option_overrides: Dictionary，字段同 GFUIUtility 打开面板 options，会覆盖路由 default_options。
func push_route(
	route_id: StringName,
	params: Dictionary = {},
	option_overrides: Dictionary = {},
	config_callback: Callable = Callable()
) -> Node:
	return _open_route(
		route_id,
		Operation.PUSH,
		params,
		option_overrides,
		config_callback
	)


## 替换路由所在层级。
## [br]
## @api public
## [br]
## @param route_id: 路由标识。
## [br]
## @param params: 路由参数。
## [br]
## @param option_overrides: 面板选项覆盖。
## [br]
## @param config_callback: 面板实例化后、入栈前的额外配置回调。
## [br]
## @return 成功时返回面板实例。
## [br]
## @schema params: Dictionary，本次打开路由携带的项目自定义参数。
## [br]
## @schema option_overrides: Dictionary，字段同 GFUIUtility 打开面板 options，会覆盖路由 default_options。
func replace_route(
	route_id: StringName,
	params: Dictionary = {},
	option_overrides: Dictionary = {},
	config_callback: Callable = Callable()
) -> Node:
	return _open_route(
		route_id,
		Operation.REPLACE,
		params,
		option_overrides,
		config_callback
	)


## 异步压入一个路由面板。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param route_id: 路由标识。
## [br]
## @param params: 路由参数。
## [br]
## @param option_overrides: 面板选项覆盖。
## [br]
## @param config_callback: 面板实例化后、入栈前的额外配置回调。
## [br]
## @param async_options: 异步协调选项。
## [br]
## @schema params: Dictionary，本次打开路由携带的项目自定义参数。
## [br]
## @schema option_overrides: Dictionary，字段同 GFUIUtility 打开面板 options，会覆盖路由 default_options。
## [br]
## @schema async_options: Dictionary，可包含 preload_policy、preload_plan_options、metadata、owner:Object、scope:GFAsyncScope。可选 navigation_target:GFUINavigationTarget 与 navigation_resolver:GFUINavigationResolver 必须成对出现；readiness_timeout_msec:int 默认 15000，范围 1..300000，从页面确认入栈起覆盖内容与定位两阶段。普通打开的 owner/scope 只约束提交前；导航还约束提交后的等待，但不会自动关闭页面。preload_policy 使用 PRELOAD_*，自动预加载包含当前路由，未指定 max_depth 时只加载当前页面。
## [br]
## @return 可观察的异步路由句柄；相同 pending 请求返回同一句柄。
func push_route_async(
	route_id: StringName,
	params: Dictionary = {},
	option_overrides: Dictionary = {},
	config_callback: Callable = Callable(),
	async_options: Dictionary = {}
) -> GFUIRouteOperation:
	return _open_route_async(
		route_id,
		Operation.PUSH,
		params,
		option_overrides,
		config_callback,
		async_options
	)


## 异步替换路由所在层级。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param route_id: 路由标识。
## [br]
## @param params: 路由参数。
## [br]
## @param option_overrides: 面板选项覆盖。
## [br]
## @param config_callback: 面板实例化后、入栈前的额外配置回调。
## [br]
## @param async_options: 异步协调选项。
## [br]
## @schema params: Dictionary，本次打开路由携带的项目自定义参数。
## [br]
## @schema option_overrides: Dictionary，字段同 GFUIUtility 打开面板 options，会覆盖路由 default_options。
## [br]
## @schema async_options: Dictionary，结构与 push_route_async.async_options 相同；可选 navigation_target、navigation_resolver 与 readiness_timeout_msec 继续等待内容和语义定位。提交后失败不恢复被 replace 替换的旧页面。
## [br]
## @return 可观察的异步路由句柄；相同 pending 请求返回同一句柄。
func replace_route_async(
	route_id: StringName,
	params: Dictionary = {},
	option_overrides: Dictionary = {},
	config_callback: Callable = Callable(),
	async_options: Dictionary = {}
) -> GFUIRouteOperation:
	return _open_route_async(
		route_id,
		Operation.REPLACE,
		params,
		option_overrides,
		config_callback,
		async_options
	)


## 返回上一层路由。
## [br]
## @api public
## [br]
## @param layer: 指定层级；小于 0 时使用最近的历史记录。
## [br]
## @param do_free: 是否释放被弹出的面板。
## [br]
## @return 成功返回 true。
func back(layer: int = -1, do_free: bool = true) -> bool:
	_prune_history()
	var history_index: int = _find_top_history_index(layer)
	if history_index < 0:
		return false

	var entry: Dictionary = _history[history_index]
	var ui_utility: GFUIUtility = _get_ui_utility()
	if ui_utility == null:
		return false

	var route_id: StringName = GFVariantData.get_option_string_name(
		entry,
		"route_id",
		&""
	)
	var route_layer: int = GFVariantData.get_option_int(
		entry,
		"layer",
		GFUIUtility.Layer.POPUP
	)
	var route_panel: Node = _get_history_panel(entry)
	if route_panel == null or ui_utility.get_top_panel(_get_ui_layer(route_layer)) != route_panel:
		push_warning("[GFUIRouterUtility][ui_router_utility.back_panel_not_top] Cannot go back: the route panel is not at the top of the current UI stack.")
		return false

	ui_utility.pop_panel(
		_get_ui_layer(route_layer),
		do_free
	)
	_history.remove_at(history_index)
	_prune_history()
	route_back_completed.emit(route_id, route_layer)
	return true


## 获取当前路由标识。
## [br]
## @api public
## [br]
## @param layer: 指定层级；小于 0 时返回最近路由。
## [br]
## @return 当前路由标识；没有时返回空 StringName。
func get_current_route_id(layer: int = -1) -> StringName:
	_prune_history()
	var history_index: int = _find_top_history_index(layer)
	if history_index < 0:
		return &""
	return GFVariantData.get_option_string_name(
		_history[history_index],
		"route_id",
		&""
	)


## 获取路由历史副本。
## [br]
## @api public
## [br]
## @return 从旧到新的历史条目。
## [br]
## @schema return: Array，元素为 Dictionary，包含 route_id、layer、panel、params 和 metadata。
func get_route_history() -> Array[Dictionary]:
	_prune_history()
	var result: Array[Dictionary] = []
	for entry: Dictionary in _history:
		result.append(_make_public_history_entry(entry))
	return result


## 清空路由历史，不影响已打开面板。
## [br]
## @api public
func clear_history() -> void:
	_history.clear()


## 获取路由诊断快照。
## [br]
## @api public
## [br]
## @since 3.0.0
## [br]
## @return 诊断快照。
## [br]
## @schema return: Dictionary，包含 route_count、history_count、pending_async_route_count、current_route_id、has_ui_utility、disposed，以及 pending_async_routes；其中每个 pending 条目额外包含 panel_submitted、has_owner、has_scope 与 lifecycle_cancellation_open。
func get_debug_snapshot() -> Dictionary:
	_prune_history()
	return {
		"route_count": _routes.size(),
		"history_count": _history.size(),
		"pending_async_route_count": _pending_async_routes.size(),
		"pending_async_routes": _get_pending_route_snapshots(),
		"current_route_id": String(get_current_route_id()),
		"has_ui_utility": _get_ui_utility() != null,
		"disposed": _disposed,
	}


# --- 私有/辅助方法 ---

## 校验并同步打开路由，成功后更新替换操作对应的历史并发出打开结果。
## [br]
## @api private
func _open_route(
	route_id: StringName,
	operation: Operation,
	params: Dictionary,
	option_overrides: Dictionary,
	config_callback: Callable
) -> Node:
	var normalized_route_id: StringName = _normalize_route_id(route_id)
	if _disposed:
		_fail_route(normalized_route_id, "router_disposed")
		return null
	var route: GFUIRoute = _resolve_route_or_fail(normalized_route_id)
	if route == null:
		return null
	var route_snapshot: GFUIRoute = _make_route_request_snapshot(normalized_route_id, route)
	var request_params: Dictionary = params.duplicate(true)
	var request_option_overrides: Dictionary = option_overrides.duplicate(true)

	var ui_utility: GFUIUtility = _get_ui_utility()
	if ui_utility == null:
		_fail_route(normalized_route_id, "missing_ui_utility")
		return null
	var route_layer: int = _get_ui_layer(route_snapshot.layer)
	if not ui_utility.has_layer(route_layer):
		_fail_route(normalized_route_id, "missing_ui_layer")
		return null

	route_open_requested.emit(
		normalized_route_id,
		operation,
		request_params.duplicate(true)
	)
	var options: Dictionary = route_snapshot.build_options(request_params, request_option_overrides)
	var wrapped_callback: Callable = _make_route_config_callback(
		route_snapshot,
		request_params,
		config_callback
	)
	var panel: Node = null
	if operation == Operation.REPLACE:
		panel = ui_utility.replace_layer_with_options(
			route_snapshot.scene_path,
			route_layer,
			options,
			wrapped_callback
		)
	else:
		panel = ui_utility.push_panel_with_options(
			route_snapshot.scene_path,
			route_layer,
			options,
			wrapped_callback
		)

	if panel == null:
		_fail_route(normalized_route_id, "panel_open_failed")
		return null

	if operation == Operation.REPLACE:
		_remove_history_for_layer(route_snapshot.layer)
	_record_route_open(
		route_snapshot,
		panel,
		request_params,
		operation
	)
	return panel


## 建立或复用异步路由请求，绑定生命周期与预加载策略后推进到面板提交阶段。
## 相同身份的请求共用句柄；同键但请求参数不一致时以冲突结果结束。
## [br]
## @api private
func _open_route_async(
	route_id: StringName,
	operation: Operation,
	params: Dictionary,
	option_overrides: Dictionary,
	config_callback: Callable,
	async_options: Dictionary
) -> GFUIRouteOperation:
	var normalized_route_id: StringName = _normalize_route_id(route_id)
	var preload_policy: StringName = _get_preload_policy(async_options)
	var operation_handle: GFUIRouteOperation = _create_route_operation(
		normalized_route_id,
		operation,
		preload_policy
	)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(async_options, "metadata")
	var immediate_entry: _RouteRequestState = _make_route_operation_entry(
		operation_handle,
		operation,
		preload_policy,
		metadata
	)
	if _disposed:
		_finish_route_entry(
			immediate_entry,
			GFUIRouteResult.STATUS_DISPOSED,
			&"router_disposed",
			null,
			false
		)
		return operation_handle
	var lifecycle: Dictionary = _parse_route_lifecycle_options(async_options)
	if not GFVariantData.get_option_bool(lifecycle, "valid"):
		_finish_route_entry(
			immediate_entry,
			GFUIRouteResult.STATUS_INVALID_LIFECYCLE,
			GFVariantData.get_option_string_name(
				lifecycle,
				"reason",
				&"invalid_lifecycle"
			),
			null,
			true
		)
		return operation_handle
	if GFVariantData.get_option_bool(lifecycle, "cancelled"):
		_finish_route_entry(
			immediate_entry,
			GFUIRouteResult.STATUS_CANCELLED,
			GFVariantData.get_option_string_name(
				lifecycle,
				"reason",
				&"scope_cancelled"
			),
			null,
			false
		)
		return operation_handle
	_apply_route_lifecycle_to_entry(immediate_entry, lifecycle)
	if (
		async_options.has("navigation_target")
		or async_options.has("navigation_resolver")
		or async_options.has("readiness_timeout_msec")
	):
		var navigation: _NavigationState = _parse_navigation_options(async_options, normalized_route_id)
		if navigation == null:
			_finish_route_entry(
				immediate_entry,
				GFUIRouteResult.STATUS_INVALID_NAVIGATION,
				&"invalid_navigation",
				null,
				true
			)
			return operation_handle
		immediate_entry._navigation = navigation
		operation_handle.set_navigation_target_for_framework(navigation._target)

	var route: GFUIRoute = get_route(normalized_route_id)
	if route == null:
		_finish_route_entry(
			immediate_entry,
			GFUIRouteResult.STATUS_MISSING_ROUTE,
			&"missing_route",
			null,
			true
		)
		return operation_handle
	if not route.is_valid_route():
		_finish_route_entry(
			immediate_entry,
			GFUIRouteResult.STATUS_INVALID_ROUTE,
			&"invalid_route",
			null,
			true
		)
		return operation_handle
	var route_snapshot: GFUIRoute = _make_route_request_snapshot(normalized_route_id, route)
	var request_params: Dictionary = params.duplicate(true)
	var request_option_overrides: Dictionary = option_overrides.duplicate(true)
	var request_options: Dictionary = route_snapshot.build_options(request_params, request_option_overrides)
	immediate_entry._layer = route_snapshot.layer
	if not _is_valid_preload_policy(preload_policy):
		_finish_route_entry(
			immediate_entry,
			GFUIRouteResult.STATUS_INVALID_PRELOAD_POLICY,
			&"invalid_preload_policy",
			null,
			true
		)
		return operation_handle

	var ui_utility: GFUIUtility = _get_ui_utility()
	if ui_utility == null:
		_finish_route_entry(
			immediate_entry,
			GFUIRouteResult.STATUS_MISSING_UI_UTILITY,
			&"missing_ui_utility",
			null,
			true
		)
		return operation_handle
	var route_layer: int = _get_ui_layer(route_snapshot.layer)
	if not ui_utility.has_layer(route_layer):
		_finish_route_entry(
			immediate_entry,
			GFUIRouteResult.STATUS_MISSING_UI_LAYER,
			&"missing_ui_layer",
			null,
			true
		)
		return operation_handle

	var preload_plan_options: Dictionary = GFVariantData.get_option_dictionary(async_options, "preload_plan_options")
	_prune_pending_route_lifecycles()
	var pending_route: _RouteRequestState = _find_pending_async_route(
		route_snapshot.scene_path,
		route_snapshot.layer,
		operation
	)
	if pending_route != null:
		if _pending_route_matches_request(
			pending_route,
			route_snapshot,
			request_params,
			request_options,
			config_callback,
			preload_policy,
			preload_plan_options,
			metadata,
			GFVariantData.get_option_int(lifecycle, "owner_id"),
			GFVariantData.get_option_int(lifecycle, "scope_id")
		) and _navigation_matches(pending_route, immediate_entry):
			var pending_handle: GFUIRouteOperation = pending_route._operation_handle
			if pending_handle != null:
				return pending_handle
		_finish_route_entry(
			immediate_entry,
			GFUIRouteResult.STATUS_ASYNC_CONFLICT,
			&"route_async_conflict",
			null,
			true
		)
		return operation_handle

	var pending_key: String = _make_pending_async_route_key(
		route_snapshot.scene_path,
		route_snapshot.layer,
		operation
	)
	var request_id: int = operation_handle.get_request_id()
	var pending_entry: _RouteRequestState = immediate_entry
	if pending_entry._navigation != null:
		pending_entry._navigation._ui_ref = weakref(ui_utility)
	pending_entry._route_snapshot = route_snapshot
	pending_entry._path = route_snapshot.scene_path
	pending_entry._params = request_params
	pending_entry._options = request_options
	pending_entry._config_callback = config_callback
	pending_entry._preload_plan_options = preload_plan_options
	if preload_policy != PRELOAD_NONE:
		pending_entry._preload = _PreloadState.new()
		pending_entry._preload._routes = _make_preload_route_snapshots(route_snapshot, preload_plan_options)
	_pending_async_routes[pending_key] = pending_entry
	_bind_pending_route_lifecycle(
		pending_key,
		request_id,
		_get_object_value(lifecycle.get("owner")),
		_get_async_scope_value(lifecycle.get("scope"))
	)
	if not _pending_route_has_request_id(pending_key, request_id):
		return operation_handle
	route_open_requested.emit(
		normalized_route_id,
		operation,
		request_params.duplicate(true)
	)
	if not _pending_route_has_request_id(pending_key, request_id):
		return operation_handle
	if preload_policy == PRELOAD_NONE:
		_submit_pending_panel_open(pending_key, request_id)
	else:
		_start_pending_route_preload(pending_key, request_id)
	return operation_handle


## 验证可选导航协议；目标与 resolver 必须成对出现，普通打开保持原语义。
## [br]
## @api private
func _parse_navigation_options(options: Dictionary, route_id: StringName) -> _NavigationState:
	var target: GFUINavigationTarget = _get_navigation_target(options.get("navigation_target"))
	var resolver: Variant = options.get("navigation_resolver")
	var timeout_value: Variant = options.get("readiness_timeout_msec", 15000)
	if (
		target == null
		or target.get_route_id() != route_id
		or not resolver is GFUINavigationResolver
		or not timeout_value is int
	):
		return null
	var timeout_msec: int = timeout_value
	if timeout_msec < 1 or timeout_msec > 300000:
		return null
	var navigation: _NavigationState = _NavigationState.new()
	navigation._target = target
	navigation._resolver = resolver
	navigation._timeout_msec = timeout_msec
	return navigation


## 目标按冻结内容比较，resolver 按实例比较，避免不同定位请求共享同一句柄。
## [br]
## @api private
func _navigation_matches(existing: _RouteRequestState, candidate: _RouteRequestState) -> bool:
	var first: _NavigationState = existing._navigation
	var second: _NavigationState = candidate._navigation
	if first == null or second == null:
		return first == null and second == null
	return (
		first._target.is_equivalent_to(second._target)
		and first._resolver == second._resolver
		and first._timeout_msec == second._timeout_msec
	)


## 收窄可选目标类型，不从字典或其他资源隐式构造目标。
## [br]
## @api private
func _get_navigation_target(value: Variant) -> GFUINavigationTarget:
	return value if value is GFUINavigationTarget else null


## 解析页面弱引用；历史提交事实独立保存在 panel_committed。
## [br]
## @api private
func _get_navigation_panel(entry: _RouteRequestState) -> Node:
	if entry._navigation == null:
		return null
	var value: Object = _get_live_object_from_ref(entry._navigation._panel_ref)
	return value if value is Node else null


## 冻结页面提交事实与超时起点，然后记录历史；打开信号可安全重入关闭页面。
## [br]
## @api private
func _begin_pending_navigation(
	pending_key: String,
	request_id: int,
	route: GFUIRoute,
	operation: Operation,
	panel: Node
) -> void:
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if (
		entry == null
		or entry._navigation == null
		or entry._navigation._panel_committed
	):
		return
	_disconnect_entry_ui_completion_callback(entry)
	entry._navigation._panel_committed = true
	entry._navigation._panel_ref = weakref(panel)
	entry._navigation._scope = GFAsyncScope.new()
	entry._navigation._deadline = entry._clock.get_monotonic_msec() + entry._navigation._timeout_msec
	var ui: GFUIUtility = _get_ui_utility_value(_get_live_object_from_ref(entry._navigation._ui_ref))
	if ui != null:
		var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(self, &"_on_navigation_panel_closed")
		var callback: Callable = func(closed_panel: Node, _layer: int) -> void:
			var _result: Dictionary = invocation.invoke(
				[
					closed_panel,
					pending_key,
					request_id,
				]
			)
		entry._navigation._close_callback = callback
		var _connected: int = ui.panel_closed.connect(callback)

	if operation == Operation.REPLACE:
		_remove_history_for_layer(route.layer)
	_record_route_open(
		route,
		panel,
		entry._params,
		operation
	)
	if _check_navigation_alive(pending_key, request_id):
		_start_navigation_phase(
			pending_key,
			request_id,
			&"content"
		)


## 内容和定位共用一个已提交页面、一个请求作用域和一个等待预算。
## [br]
## @api private
func _start_navigation_phase(
	pending_key: String,
	request_id: int,
	phase: StringName
) -> void:
	if not _check_navigation_alive(pending_key, request_id):
		return
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	var resolver_value: Variant = entry._navigation._resolver
	if not resolver_value is GFUINavigationResolver:
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_CONTENT_FAILED,
			&"resolver_unavailable",
			_get_navigation_panel(entry),
			false
		)
		return
	var resolver: GFUINavigationResolver = resolver_value
	var scope: GFAsyncScope = entry._navigation._scope
	var panel: Node = _get_navigation_panel(entry)
	var target: GFUINavigationTarget = entry._navigation._target
	entry._navigation._phase = phase

	var completion: GFAsyncCompletion = resolver.prepare_content(
		panel,
		target,
		scope
	) if phase == &"content" else resolver.resolve_target(
		panel,
		target,
		scope
	)
	if not _check_navigation_alive(pending_key, request_id):
		return
	entry = _get_pending_route(pending_key)
	if completion == null:
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_CONTENT_FAILED if phase == &"content" else GFUIRouteResult.STATUS_TARGET_UNAVAILABLE,
			&"missing_completion",
			panel,
			false
		)
		return
	var invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(self, &"_on_navigation_phase_completed")
	var callback: Callable = func(completed: GFAsyncCompletion) -> void:
		var _result: Dictionary = invocation.invoke(
			[
				completed,
				pending_key,
				request_id,
				phase,
			]
		)
	entry._navigation._completion = completion
	entry._navigation._callback = callback

	if completion.is_completed():
		_on_navigation_phase_completed(
			completion,
			pending_key,
			request_id,
			phase
		)
	else:
		var _connected: int = completion.completed.connect(callback)


## 每个回调和 tick 都复核原请求、页面、生命周期及截止时间。
## [br]
## @api private
func _check_navigation_alive(pending_key: String, request_id: int) -> bool:
	if not _pending_route_has_request_id(pending_key, request_id):
		return false
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if entry._navigation == null:
		return false
	var reason: StringName = entry._navigation._cancel_reason
	if reason == &"":
		reason = _get_route_lifecycle_expired_reason(entry)
	var status: StringName = GFUIRouteResult.STATUS_CANCELLED
	var panel: Node = _get_navigation_panel(entry)
	var ui: GFUIUtility = _get_ui_utility_value(_get_live_object_from_ref(entry._navigation._ui_ref))
	var scope: GFAsyncScope = entry._navigation._scope
	if (
		reason == &""
		and (
			panel == null
			or ui == null
			or not ui.is_panel_open(panel)
		)
	):
		reason = &"panel_closed"
	if (
		reason == &""
		and (
			scope == null
			or not scope.is_active()
		)
	):
		reason = &"navigation_scope_ended"
	if reason == &"" and entry._clock.get_monotonic_msec() >= entry._navigation._deadline:
		reason = &"readiness_timeout"
		status = GFUIRouteResult.STATUS_READINESS_TIMEOUT
	if reason == &"":
		return true
	_complete_pending_route(
		pending_key,
		request_id,
		status,
		reason,
		panel,
		false
	)
	return false


## 完成 owner 的正常结束与内容超时检查；页面阶段尚未确认时保留底层观察责任。
## [br]
## @api private
func _prune_pending_navigation() -> void:
	for key: Variant in _pending_async_routes.keys():
		var pending_key: String = GFVariantData.to_text(key)
		var entry: _RouteRequestState = _get_pending_route(pending_key)
		if (
			entry != null
			and entry._navigation != null
			and entry._navigation._panel_committed
		):
			var _alive: bool = _check_navigation_alive(pending_key, entry._request_id)


## 断开单个完成源回调；已完成源不得在下一个阶段重复作用。
## [br]
## @api private
func _disconnect_navigation_completion(entry: _RouteRequestState) -> void:
	if entry._navigation == null:
		return
	var value: Variant = entry._navigation._completion
	var callback: Callable = entry._navigation._callback
	if value is GFAsyncCompletion:
		var completion: GFAsyncCompletion = value
		if callback.is_valid() and completion.completed.is_connected(callback):
			completion.completed.disconnect(callback)
	entry._navigation._completion = null
	entry._navigation._callback = Callable()


## 终结后取消项目写回资格；成功只正常结束作用域，不触发取消清理。
## [br]
## @api private
func _disconnect_navigation(entry: _RouteRequestState, status: StringName) -> void:
	if entry._navigation == null:
		return
	_disconnect_navigation_completion(entry)
	var ui: GFUIUtility = _get_ui_utility_value(_get_live_object_from_ref(entry._navigation._ui_ref))
	var callback: Callable = entry._navigation._close_callback
	if (
		ui != null
		and callback.is_valid()
		and ui.panel_closed.is_connected(callback)
	):
		ui.panel_closed.disconnect(callback)
	var scope: GFAsyncScope = entry._navigation._scope
	if scope != null and scope.is_active():
		if status in [GFUIRouteResult.STATUS_CONTENT_READY, GFUIRouteResult.STATUS_TARGET_READY]:
			scope.complete()
		else:
			var _cancelled: bool = scope.cancel(String(status))


## 按规范化 ID 查找路由，并在缺失或无效时发出失败信号。
## [br]
## @api private
func _resolve_route_or_fail(route_id: StringName) -> GFUIRoute:
	var route: GFUIRoute = get_route(route_id)
	if route == null:
		_fail_route(route_id, "missing_route")
		return null
	if not route.is_valid_route():
		_fail_route(route_id, "invalid_route")
		return null
	return route


## 发出路由打开失败信号，保留调用方提供的原因文本。
## [br]
## @api private
func _fail_route(route_id: StringName, reason: String) -> void:
	route_open_failed.emit(route_id, reason)
	push_warning(
		"[GFUIRouterUtility][ui_router_utility.route_open_failed] Cannot open route: %s (%s)."
		% [String(route_id), reason]
	)


## 分配请求 ID 并创建供框架完成的异步路由操作句柄。
## [br]
## @api private
func _create_route_operation(
	route_id: StringName,
	operation: Operation,
	preload_policy: StringName
) -> GFUIRouteOperation:
	var operation_handle: GFUIRouteOperation = GFUIRouteOperation.new()
	var request_id: int = _next_async_request_id
	_next_async_request_id += 1
	var configured: bool = operation_handle.configure_for_framework(
		request_id,
		route_id,
		_operation_to_name(operation),
		preload_policy,
		_clock.get_monotonic_msec()
	)
	if not configured:
		push_error("[GFUIRouterUtility][ui_router_utility.request_handle_creation_failed] Cannot create the asynchronous route request handle.")
	return operation_handle


## 构造 Router 独占的类型化请求状态；输入快照与可变执行字段不向外共享。
## [br]
## @api private
func _make_route_operation_entry(
	operation_handle: GFUIRouteOperation,
	operation: Operation,
	preload_policy: StringName,
	metadata: Dictionary
) -> _RouteRequestState:
	var entry: _RouteRequestState = _RouteRequestState.new()
	entry._route_id = operation_handle.get_route_id()
	entry._clock = _clock
	entry._operation = operation
	entry._request_id = operation_handle.get_request_id()
	entry._operation_handle = operation_handle
	entry._preload_policy = preload_policy
	entry._metadata = metadata.duplicate(true)
	return entry


## 从异步选项读取预加载策略；未知值回退为默认策略。
## [br]
## @api private
func _get_preload_policy(async_options: Dictionary) -> StringName:
	if not async_options.has("preload_policy"):
		return PRELOAD_NONE
	var raw_policy: StringName = GFVariantData.get_option_string_name(
		async_options,
		"preload_policy",
		&""
	)
	return StringName(String(raw_policy).strip_edges().to_lower())


## 判断预加载策略是否属于三个受支持的策略常量。
## [br]
## @api private
func _is_valid_preload_policy(preload_policy: StringName) -> bool:
	return preload_policy in [
		PRELOAD_NONE,
		PRELOAD_BEST_EFFORT,
		PRELOAD_REQUIRED,
	]


## 比较 pending 请求保存的路由、面板选项、回调和生命周期身份。
## [br]
## @api private
func _pending_route_matches_request(
	entry: _RouteRequestState,
	route_snapshot: GFUIRoute,
	params: Dictionary,
	options: Dictionary,
	config_callback: Callable,
	preload_policy: StringName,
	preload_plan_options: Dictionary,
	metadata: Dictionary,
	owner_id: int,
	scope_id: int
) -> bool:
	return (
		entry._route_id == route_snapshot.get_route_id()
		and entry._path == route_snapshot.scene_path
		and entry._layer == route_snapshot.layer
		and entry._params == params
		and entry._options == options
		and entry._config_callback == config_callback
		and entry._preload_policy == preload_policy
		and entry._preload_plan_options == preload_plan_options
		and entry._metadata == metadata
		and entry._owner_id == owner_id
		and entry._scope_id == scope_id
	)


## 校验 owner 与 scope 选项，并返回其弱引用、实例 ID 和失效信息。
## [br]
## @api private
func _parse_route_lifecycle_options(async_options: Dictionary) -> Dictionary:
	var owner: Object = null
	if async_options.has("owner"):
		var raw_owner: Variant = async_options.get("owner")
		if raw_owner != null:
			if not (raw_owner is Object):
				return { "valid": false, "reason": &"invalid_owner" }
			owner = raw_owner
			if not is_instance_valid(owner):
				return { "valid": false, "reason": &"invalid_owner" }
			if owner is Node:
				var owner_node: Node = owner
				if not owner_node.is_inside_tree():
					return { "valid": false, "reason": &"owner_not_in_tree" }

	var scope: GFAsyncScope = null
	if async_options.has("scope"):
		var raw_scope: Variant = async_options.get("scope")
		if raw_scope != null:
			if not (raw_scope is GFAsyncScope):
				return { "valid": false, "reason": &"invalid_scope" }
			scope = raw_scope
			if scope.is_completed():
				return { "valid": false, "reason": &"scope_completed" }
			if scope.is_cancel_requested():
				return {
					"valid": true,
					"cancelled": true,
					"reason": _get_scope_cancel_reason(scope),
				}

	return {
		"valid": true,
		"cancelled": false,
		"owner": owner,
		"owner_id": owner.get_instance_id() if owner != null else 0,
		"scope": scope,
		"scope_id": scope.get_instance_id() if scope != null else 0,
	}


## 将已解析的 owner、scope 和取消原因写入 pending 请求条目。
## [br]
## @api private
func _apply_route_lifecycle_to_entry(entry: _RouteRequestState, lifecycle: Dictionary) -> void:
	var owner: Object = _get_object_value(lifecycle.get("owner"))
	var scope: GFAsyncScope = _get_async_scope_value(lifecycle.get("scope"))
	entry._owner_ref = weakref(owner) if owner != null else null
	entry._owner_id = owner.get_instance_id() if owner != null else 0
	entry._scope = scope
	entry._scope_id = scope.get_instance_id() if scope != null else 0


## 为请求订阅 owner 生命周期与 scope 取消信号，并保存可断开的订阅句柄。
## [br]
## @api private
func _bind_pending_route_lifecycle(
	pending_key: String,
	request_id: int,
	owner: Object,
	scope: GFAsyncScope
) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if entry == null:
		return
	var operation_handle: GFUIRouteOperation = entry._operation_handle
	if operation_handle == null:
		var _missing_handle_finished: bool = _finish_pending_route_before_submit(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_INVALID_LIFECYCLE,
			&"missing_route_operation",
			true
		)
		return
	if owner != null:
		var owner_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(self, &"_on_pending_route_lifecycle_cancelled")
		var owner_reason: StringName = &"owner_tree_exited" if owner is Node else &"owner_released"
		var owner_callback: Callable = func() -> void:
			var _invocation_result: Dictionary = owner_invocation.invoke(
				[
					pending_key,
					request_id,
					owner_reason,
				]
			)
		var owner_lifetime: GFLifetimeSubscription = GFLifetimeSubscription.new(
			owner,
			owner_callback,
			"ui_route:%d" % request_id
		)
		if not owner_lifetime.is_active():
			var _invalid_owner_finished: bool = _finish_pending_route_before_submit(
				pending_key,
				request_id,
				GFUIRouteResult.STATUS_INVALID_LIFECYCLE,
				&"owner_binding_failed",
				true
			)
			return
		entry._owner_lifetime = owner_lifetime

	if scope != null:
		var scope_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(self, &"_on_pending_route_lifecycle_cancelled")
		var scope_callback: Callable = func(reason: StringName) -> void:
			var _invocation_result: Dictionary = scope_invocation.invoke(
				[
					pending_key,
					request_id,
					reason if reason != &"" else &"scope_cancelled",
				]
			)
		entry._scope_callback = scope_callback
		var connect_error: Error = scope.cancel_requested.connect(scope_callback) as Error
		if connect_error != OK:

			var _scope_connect_finished: bool = _finish_pending_route_before_submit(
				pending_key,
				request_id,
				GFUIRouteResult.STATUS_INVALID_LIFECYCLE,
				&"scope_connect_failed",
				true
			)
			return

	if scope != null and scope.is_cancel_requested():
		_on_pending_route_lifecycle_cancelled(
			pending_key,
			request_id,
			_get_scope_cancel_reason(scope)
		)


## 扫描尚未提交面板的请求，终结 owner 或 scope 已失效的条目。
## [br]
## @api private
func _prune_pending_route_lifecycles() -> void:
	if _pending_async_routes.is_empty():
		return
	var pending_keys: Array = _pending_async_routes.keys()
	for pending_key_value: Variant in pending_keys:
		var pending_key: String = GFVariantData.to_text(pending_key_value)
		var entry: _RouteRequestState = _get_pending_route(pending_key)
		if entry == null or entry._panel_submitted:
			continue
		var expired_reason: StringName = _get_route_lifecycle_expired_reason(entry)
		if expired_reason == &"":
			continue
		var operation_handle: GFUIRouteOperation = entry._operation_handle
		if operation_handle != null:
			_on_pending_route_lifecycle_cancelled(
				pending_key,
				operation_handle.get_request_id(),
				expired_reason
			)


## 根据 owner 弱引用与 scope 状态返回首个生命周期失效原因。
## [br]
## @api private
func _get_route_lifecycle_expired_reason(entry: _RouteRequestState) -> StringName:
	var owner_id: int = entry._owner_id
	if owner_id != 0:
		var owner_ref: WeakRef = entry._owner_ref
		var owner: Object = _get_live_object_from_ref(owner_ref)
		if owner == null or owner.get_instance_id() != owner_id:
			return &"owner_released"
		if owner is Node:
			var owner_node: Node = owner
			if not owner_node.is_inside_tree():
				return &"owner_tree_exited"

	var scope: GFAsyncScope = entry._scope
	if scope != null:
		if scope.is_cancel_requested():
			return _get_scope_cancel_reason(scope)
		if scope.is_completed():
			return &"scope_completed"
	return &""


## 从 pending 表移除提交前失败的请求，断开回调并回滚未完成预加载。
## [br]
## @api private
func _finish_pending_route_before_submit(
	pending_key: String,
	request_id: int,
	status: StringName,
	reason: StringName,
	emit_legacy_failure: bool
) -> bool:
	if not _pending_route_has_request_id(pending_key, request_id):
		return false
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if entry == null or entry._panel_submitted:
		return false
	var _erased: bool = _pending_async_routes.erase(pending_key)
	_disconnect_entry_lifecycle(entry)
	_disconnect_entry_preload_callback(entry)
	var session: GFAssetLoadSession = (entry._preload._session if entry._preload != null else null)
	if session != null and not session.is_completed():
		var _rolled_back: bool = session.rollback(reason)
	_finish_route_entry(
		entry,
		status,
		reason,
		null,
		emit_legacy_failure
	)
	return true


## 获取 scope 的取消原因；scope 未提供原因时返回通用取消标识。
## [br]
## @api private
func _get_scope_cancel_reason(scope: GFAsyncScope) -> StringName:
	if scope == null:
		return &"scope_cancelled"
	var reason: StringName = scope.get_cancel_reason()
	return reason if reason != &"" else &"scope_cancelled"


## 若请求生命周期已失效则按记录的原因取消；返回是否已终结请求。
## [br]
## @api private
func _cancel_pending_route_if_lifecycle_expired(pending_key: String, request_id: int) -> bool:
	if not _pending_route_has_request_id(pending_key, request_id):
		return false
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if entry == null or entry._panel_submitted:
		return false
	var expired_reason: StringName = _get_route_lifecycle_expired_reason(entry)
	if expired_reason == &"":
		return false
	return _finish_pending_route_before_submit(
		pending_key,
		request_id,
		GFUIRouteResult.STATUS_CANCELLED,
		expired_reason,
		false
	)


## 检查键对应的 pending 条目仍属于指定请求 ID。
## [br]
## @api private
func _pending_route_has_request_id(pending_key: String, request_id: int) -> bool:
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	return entry != null and entry._request_id == request_id


## 借用 Router 独占的请求状态，不复制输入容器，也不向调用方暴露。
## [br]
## @api private
func _get_pending_route(pending_key: String) -> _RouteRequestState:
	var value: Variant = _pending_async_routes.get(pending_key)
	return value if value is _RouteRequestState else null


## 为请求规划并启动预加载；required 失败时结束请求，best-effort 失败时降级继续。
## 在提交前反复校验请求身份和生命周期，避免迟到会话附着到新条目。
## [br]
## @api private
func _start_pending_route_preload(pending_key: String, request_id: int) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	if _cancel_pending_route_if_lifecycle_expired(pending_key, request_id):
		return
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if (
		entry == null
		or entry._preload == null
		or entry._preload._started
	):
		return
	entry._preload._started = true

	var route_id: StringName = entry._route_id
	var operation_handle: GFUIRouteOperation = entry._operation_handle
	if operation_handle == null or operation_handle.get_request_id() != request_id:
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_PRELOAD_PLAN_FAILED,
			&"missing_route_operation",
			null,
			true
		)
		return
	var plan_options: Dictionary = entry._preload_plan_options.duplicate(true)
	plan_options["include_source"] = true
	if not plan_options.has("max_depth"):
		plan_options["max_depth"] = 0
	var group_id: StringName = GFVariantData.get_option_string_name(
		plan_options,
		"group_id",
		&""
	)
	if group_id == &"":
		group_id = StringName("_gf_ui_route_request_%d" % operation_handle.get_request_id())
		plan_options["group_id"] = group_id
		entry._preload._owns_group = true
	if GFVariantData.get_option_string_name(
		plan_options,
		"plan_id",
		&""
	) == &"":
		plan_options["plan_id"] = StringName("ui_route_request:%d" % operation_handle.get_request_id())
	var plan_metadata: Dictionary = GFVariantData.get_option_dictionary(plan_options, "metadata")
	plan_metadata["_gf_route_request_id"] = operation_handle.get_request_id()
	plan_metadata["_gf_route_id"] = route_id
	plan_options["metadata"] = plan_metadata
	var preload_routes: Array[GFUIRoute] = entry._preload._routes
	entry._preload._routes = []


	var raw_plan_report: Dictionary = GFUIRoutePreloadUtility.build_plan(
		preload_routes,
		route_id,
		plan_options
	)
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	if _cancel_pending_route_if_lifecycle_expired(pending_key, request_id):
		return
	entry = _get_pending_route(pending_key)
	var asset_plan: GFAssetPreloadPlan = _get_asset_preload_plan_value(raw_plan_report.get("asset_plan"))
	entry._preload._plan_report = _make_json_safe_preload_plan_report(raw_plan_report, asset_plan)


	var plan_ok: bool = GFVariantData.get_option_bool(raw_plan_report, "ok")
	var plan_healthy: bool = GFVariantData.get_option_bool(raw_plan_report, "healthy")
	var plan_usable: bool = (
		plan_ok
		and asset_plan != null
		and not asset_plan.is_empty()
	)
	var preload_policy: StringName = entry._preload_policy
	if (
		preload_policy == PRELOAD_REQUIRED
		and (
			not plan_usable
			or not plan_healthy
		)
	):
		var plan_reason: StringName = &"preload_plan_failed"
		if plan_usable and not plan_healthy:
			plan_reason = &"preload_plan_unhealthy"
		elif (
			plan_ok
			and asset_plan != null
			and asset_plan.is_empty()
		):
			plan_reason = &"preload_plan_empty"
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_PRELOAD_PLAN_FAILED,
			plan_reason,
			null,
			true
		)
		return
	if not plan_usable:
		_set_pending_preload_degradation(
			pending_key,
			request_id,
			&"preload_plan_failed_continued"
		)
		_submit_pending_panel_open(pending_key, request_id)
		return
	if not plan_healthy:
		_set_pending_preload_degradation(
			pending_key,
			request_id,
			&"preload_plan_degraded_continued"
		)

	var asset_utility: GFAssetUtility = _get_asset_utility()
	if asset_utility == null:
		if preload_policy == PRELOAD_REQUIRED:
			_complete_pending_route(
				pending_key,
				request_id,
				GFUIRouteResult.STATUS_MISSING_ASSET_UTILITY,
				&"missing_asset_utility",
				null,
				true
			)
		else:
			_set_pending_preload_degradation(
				pending_key,
				request_id,
				&"missing_asset_utility_continued"
			)
			_submit_pending_panel_open(pending_key, request_id)
		return

	var session_metadata: Dictionary = entry._metadata.duplicate(true)
	session_metadata["route_request_id"] = operation_handle.get_request_id()
	session_metadata["route_id"] = route_id
	var session: GFAssetLoadSession = asset_utility.start_preload_session(
		asset_plan,
		{ "auto_commit": true, "metadata": session_metadata, }
	)
	if not _pending_route_has_request_id(pending_key, request_id):
		if session != null and not session.is_completed():
			var _orphaned_session_rolled_back: bool = session.rollback(&"route_request_gone")
		return
	if _cancel_pending_route_if_lifecycle_expired(pending_key, request_id):
		if session != null and not session.is_completed():
			var _expired_session_rolled_back: bool = session.rollback(&"route_lifecycle_expired")
		return
	var attached: bool = operation_handle.attach_preload_session_for_framework(session)
	if not attached:
		if session != null and not session.is_completed():
			var _unattached_session_rolled_back: bool = session.rollback(&"preload_session_attach_failed")
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_PRELOAD_FAILED,
			&"preload_session_attach_failed",
			null,
			true
		)
		return
	entry = _get_pending_route(pending_key)
	if entry == null:
		if session != null and not session.is_completed():
			var _rolled_back: bool = session.rollback(&"route_request_gone")
		return
	entry._preload._session = session
	entry._preload._attempted = true

	if session == null:
		_on_pending_route_preload_completed(
			null,
			pending_key,
			request_id
		)
		return
	if session.is_completed():
		_on_pending_route_preload_completed(
			session.get_result(),
			pending_key,
			request_id
		)
		return
	var preload_callback: Callable = _on_pending_route_preload_completed.bind(pending_key, request_id)
	var connect_error: Error = session.completed.connect(
		preload_callback,
		CONNECT_ONE_SHOT as Object.ConnectFlags
	) as Error
	if connect_error != OK:
		var _rolled_back: bool = session.rollback(&"route_completion_signal_failed")
		if preload_policy == PRELOAD_REQUIRED:
			_complete_pending_route(
				pending_key,
				request_id,
				GFUIRouteResult.STATUS_PRELOAD_FAILED,
				&"preload_completion_signal_failed",
				null,
				true
			)
		else:
			_set_pending_preload_degradation(
				pending_key,
				request_id,
				&"preload_completion_signal_failed_continued"
			)
			_submit_pending_panel_open(pending_key, request_id)
		return
	entry = _get_pending_route(pending_key)
	if _pending_route_has_request_id(pending_key, request_id):
		entry = _get_pending_route(pending_key)
		entry._preload._callback = preload_callback


## 将预加载降级标记和原因写入匹配的 pending 请求条目。
## [br]
## @api private
func _set_pending_preload_degradation(
	pending_key: String,
	request_id: int,
	reason: StringName
) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if entry == null:
		return
	entry._preload._degradation_reason = reason


## 将 pending 路由交给 UI 工具执行异步 push 或 replace，并绑定终态回调。
## 提交前校验生命周期和 UI 同键请求；提交后的结果由面板句柄回调收敛。
## [br]
## @api private
func _submit_pending_panel_open(pending_key: String, request_id: int) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	if _cancel_pending_route_if_lifecycle_expired(pending_key, request_id):
		return
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if entry == null or entry._panel_submitted:
		return
	if _disposed:
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_DISPOSED,
			&"router_disposed_before_panel_submit",
			null,
			false
		)
		return
	var route_snapshot: GFUIRoute = entry._route_snapshot
	if route_snapshot == null:
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_INVALID_ROUTE,
			&"route_unavailable_before_panel_submit",
			null,
			true
		)
		return
	var ui_utility: GFUIUtility = _get_ui_utility()
	if ui_utility == null:
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_MISSING_UI_UTILITY,
			&"missing_ui_utility",
			null,
			true
		)
		return
	var path: String = entry._path
	var declared_layer: int = entry._layer
	var route_layer: int = _get_ui_layer(declared_layer)
	if not ui_utility.has_layer(route_layer):
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_MISSING_UI_LAYER,
			&"missing_ui_layer",
			null,
			true
		)
		return
	var operation: Operation = entry._operation
	if _ui_has_matching_pending_request(
		ui_utility,
		path,
		route_layer,
		operation
	):
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_ASYNC_CONFLICT,
			&"ui_async_request_conflict",
			null,
			true
		)
		return
	var params: Dictionary = entry._params.duplicate(true)
	var options: Dictionary = entry._options.duplicate(true)
	var config_callback: Callable = entry._config_callback
	var wrapped_callback: Callable = _make_route_config_callback(
		route_snapshot,
		params,
		config_callback
	)
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	if _cancel_pending_route_if_lifecycle_expired(pending_key, request_id):
		return
	entry = _get_pending_route(pending_key)
	if entry == null:
		return
	entry._panel_submitted = true

	if entry._navigation == null:
		_disconnect_entry_lifecycle(entry)
	if not _pending_route_has_request_id(pending_key, request_id):
		return

	var completion_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(self, &"_on_ui_panel_async_operation_completed")
	var completion_callback: Callable = func(completed_ui_operation: GFUIPanelAsyncOperation) -> void:
		var _invocation_result: Dictionary = completion_invocation.invoke(
			[
				completed_ui_operation,
				pending_key,
				request_id,
			]
		)
	var ui_operation: GFUIPanelAsyncOperation = null
	if operation == Operation.REPLACE:
		ui_operation = ui_utility.replace_layer_async_with_options(
			path,
			route_layer,
			options,
			wrapped_callback,
			completion_callback
		)
	else:
		ui_operation = ui_utility.push_panel_async_with_options(
			path,
			route_layer,
			options,
			wrapped_callback,
			completion_callback
		)
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	if ui_operation == null:
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_PANEL_FAILED,
			&"panel_async_request_rejected",
			null,
			true
		)
		return
	entry = _get_pending_route(pending_key)
	if entry == null:
		return
	var latched_ui_operation: GFUIPanelAsyncOperation = entry._ui_operation
	if latched_ui_operation != null and latched_ui_operation != ui_operation:
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_PANEL_FAILED,
			&"panel_async_identity_mismatch",
			null,
			true
		)
		return
	entry._ui_operation = ui_operation
	entry._ui_completion_callback = completion_callback

	if ui_operation.is_completed():
		_on_ui_panel_async_operation_completed(
			ui_operation,
			pending_key,
			request_id
		)


## 查询 UI 工具是否已有相同路径与操作的未完成面板请求。
## [br]
## @api private
func _ui_has_matching_pending_request(
	ui_utility: GFUIUtility,
	path: String,
	layer: int,
	operation: Operation
) -> bool:
	var operation_name: StringName = _operation_to_name(operation)
	for request: Dictionary in ui_utility.get_pending_async_panel_requests(layer):
		if (
			GFVariantData.get_option_string(
				request,
				"path",
				""
			) == path
			and GFVariantData.get_option_string_name(
				request,
				"operation",
				&""
			) == operation_name
		):
			return true
	return false


## 终结失败或取消的请求；仅移除仍匹配 request_id 的 pending 条目。
## [br]
## @api private
func _complete_pending_route(
	pending_key: String,
	request_id: int,
	status: StringName,
	reason: StringName,
	panel: Node,
	emit_legacy_failure: bool
) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if entry == null:
		return
	var _erased: bool = _pending_async_routes.erase(pending_key)
	_finish_route_entry(
		entry,
		status,
		reason,
		panel,
		emit_legacy_failure
	)


## 终结成功请求，按 replace 语义清理历史，再记录新打开的面板。
## [br]
## @api private
func _complete_pending_route_opened(
	pending_key: String,
	request_id: int,
	route_snapshot: GFUIRoute,
	route_operation: Operation,
	panel: Node
) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if entry == null:
		return
	if entry._navigation != null:
		_begin_pending_navigation(
			pending_key,
			request_id,
			route_snapshot,
			route_operation,
			panel
		)
		return
	var _erased: bool = _pending_async_routes.erase(pending_key)
	if route_operation == Operation.REPLACE:
		_remove_history_for_layer(route_snapshot.layer)
	_record_route_open(
		route_snapshot,
		panel,
		entry._params,
		route_operation
	)
	_finish_route_entry(
		entry,
		GFUIRouteResult.STATUS_OPENED,
		&"",
		panel,
		false
	)


## 生成并发出异步路由终态结果，释放本请求拥有的成功预加载组。
## [br]
## @api private
func _finish_route_entry(
	entry: _RouteRequestState,
	status: StringName,
	reason: StringName,
	panel: Node,
	emit_legacy_failure: bool
) -> void:
	var request_clock: GFClock = entry._clock
	var completed_at_msec: int = request_clock.get_monotonic_msec()
	_disconnect_entry_lifecycle(entry)
	_disconnect_entry_ui_completion_callback(entry)
	_disconnect_navigation(entry, status)
	var operation_handle: GFUIRouteOperation = entry._operation_handle
	if operation_handle == null or operation_handle.is_completed():
		return
	_disconnect_entry_preload_callback(entry)
	var preload_result: GFAssetLoadSessionResult = _get_entry_preload_result(entry)
	var preload_attempted: bool = entry._preload != null and entry._preload._attempted
	var preload_successful: bool = (
		preload_attempted
		and preload_result != null
		and preload_result.is_successful()
	)
	var final_reason: StringName = reason
	if status == GFUIRouteResult.STATUS_OPENED and final_reason == &"":
		final_reason = entry._preload._degradation_reason if entry._preload != null else &""
	var result: GFUIRouteResult = GFUIRouteResult.new()
	var configured: bool = result.configure_for_framework(
		operation_handle.get_request_id(),
		operation_handle.get_route_id(),
		operation_handle.get_operation(),
		status,
		final_reason,
		entry._layer,
		panel,
		operation_handle.get_preload_policy(),
		preload_attempted,
		preload_successful,
		entry._preload._plan_report if entry._preload != null else {},
		preload_result,
		operation_handle.get_started_at_msec(),
		completed_at_msec,
		entry._metadata,
		(entry._navigation != null and entry._navigation._panel_committed),
		(entry._navigation != null and entry._navigation._content_ready),
		(entry._navigation != null and entry._navigation._target_resolved)
	)
	if not configured:
		push_error("[GFUIRouterUtility][ui_router_utility.terminal_result_creation_failed] Cannot construct the asynchronous route terminal result.")
		return
	_release_owned_preload_group(entry, preload_result)
	var completed: bool = operation_handle.complete_for_framework(result)
	if not completed:
		return
	route_operation_completed.emit(result.duplicate_result())
	if emit_legacy_failure:
		_fail_route(
			operation_handle.get_route_id(),
			String(final_reason)
		)


## 释放时快照并清空 pending 表，回滚未提交会话并终结全部请求。
## 已提交面板的最终结果无法确认时记录 outcome_unknown。
## [br]
## @api private
func _finish_pending_routes_for_dispose() -> void:
	var pending_entries: Array[_RouteRequestState] = []
	for pending_key: Variant in _pending_async_routes.keys():
		var entry: _RouteRequestState = _get_pending_route(GFVariantData.to_text(pending_key))
		if entry != null:
			pending_entries.append(entry)
	_pending_async_routes.clear()
	for entry: _RouteRequestState in pending_entries:
		_disconnect_entry_lifecycle(entry)
		_disconnect_entry_preload_callback(entry)
		var panel_submitted: bool = entry._panel_submitted
		var panel_committed: bool = (entry._navigation != null and entry._navigation._panel_committed)
		var session: GFAssetLoadSession = (entry._preload._session if entry._preload != null else null)
		if (
			not panel_submitted
			and session != null
			and not session.is_completed()
		):
			var _rolled_back: bool = session.rollback(&"router_disposed")
		var terminal_status: StringName = GFUIRouteResult.STATUS_DISPOSED
		if panel_committed:
			terminal_status = GFUIRouteResult.STATUS_CANCELLED
		elif panel_submitted:
			terminal_status = GFUIRouteResult.STATUS_OUTCOME_UNKNOWN
		_finish_route_entry(
			entry,
			terminal_status,
			&"router_disposed_after_panel_submit" if panel_submitted else &"router_disposed_before_panel_submit",
			_get_navigation_panel(entry),
			false
		)


## 断开条目中仍连接到预加载会话 completed 信号的回调。
## [br]
## @api private
func _disconnect_entry_preload_callback(entry: _RouteRequestState) -> void:
	if entry._preload == null:
		return
	var session: GFAssetLoadSession = (entry._preload._session if entry._preload != null else null)
	var callback: Callable = entry._preload._callback
	if (
		session != null
		and callback.is_valid()
		and session.completed.is_connected(callback)
	):
		session.completed.disconnect(callback)


## 取消 owner 生命周期订阅并断开 scope 取消信号，随后清空条目引用。
## [br]
## @api private
func _disconnect_entry_lifecycle(entry: _RouteRequestState) -> void:
	var owner_lifetime: GFLifetimeSubscription = entry._owner_lifetime
	if owner_lifetime != null and owner_lifetime.is_active():
		var _cancelled_subscription: bool = owner_lifetime.cancel()
	var scope: GFAsyncScope = entry._scope
	var scope_callback: Callable = entry._scope_callback
	if (
		scope != null
		and scope_callback.is_valid()
		and scope.cancel_requested.is_connected(scope_callback)
	):
		scope.cancel_requested.disconnect(scope_callback)
	entry._owner_lifetime = null
	entry._scope = null
	entry._scope_callback = Callable()


## 断开 UI 面板操作的完成回调，并清空条目内保存的句柄与 Callable。
## [br]
## @api private
func _disconnect_entry_ui_completion_callback(entry: _RouteRequestState) -> void:
	var ui_operation: GFUIPanelAsyncOperation = entry._ui_operation
	var completion_callback: Callable = entry._ui_completion_callback
	if (
		ui_operation != null
		and completion_callback.is_valid()
		and ui_operation.completed.is_connected(completion_callback)
	):
		ui_operation.completed.disconnect(completion_callback)
	entry._ui_operation = null
	entry._ui_completion_callback = Callable()


## 仅当本路由拥有且结果成功时卸载其预加载组。
## [br]
## @api private
func _release_owned_preload_group(entry: _RouteRequestState, preload_result: GFAssetLoadSessionResult) -> void:
	if (
		entry._preload == null
		or not entry._preload._owns_group
		or preload_result == null
		or not preload_result.is_successful()
	):
		return
	var asset_utility: GFAssetUtility = _get_asset_utility()
	if asset_utility != null:
		asset_utility.unload_group(
			preload_result.get_group_id(),
			false
		)


## 优先读取条目缓存的结果，否则从已完成的预加载会话取结果。
## [br]
## @api private
func _get_entry_preload_result(entry: _RouteRequestState) -> GFAssetLoadSessionResult:
	if entry._preload == null:
		return null
	var result: GFAssetLoadSessionResult = entry._preload._result
	if result != null:
		return result
	var session: GFAssetLoadSession = (entry._preload._session if entry._preload != null else null)
	return session.get_result() if session != null and session.is_completed() else null


## 移除报告中的资源对象，加入计划描述并编码为报告字典。
## [br]
## @api private
func _make_json_safe_preload_plan_report(raw_report: Dictionary, asset_plan: GFAssetPreloadPlan) -> Dictionary:
	var report: Dictionary = raw_report.duplicate(true)
	var _erased_asset_plan: bool = report.erase("asset_plan")
	if asset_plan != null:
		report["asset_plan_description"] = asset_plan.describe()
	return GFReportValueCodec.to_report_dictionary(report)


## 按请求 ID 排序生成 pending 句柄的调试快照及生命周期标记。
## [br]
## @api private
func _get_pending_route_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for pending_key: Variant in _pending_async_routes.keys():
		var entry: _RouteRequestState = _get_pending_route(GFVariantData.to_text(pending_key))
		if entry == null:
			continue
		var operation_handle: GFUIRouteOperation = entry._operation_handle
		if operation_handle != null:
			var snapshot: Dictionary = operation_handle.get_debug_snapshot()
			snapshot["panel_submitted"] = entry._panel_submitted
			snapshot["has_owner"] = entry._owner_id != 0
			snapshot["has_scope"] = entry._scope_id != 0
			snapshot["lifecycle_cancellation_open"] = not (entry._panel_submitted)
			snapshots.append(snapshot)
	snapshots.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return GFVariantData.get_option_int(left, "request_id") < GFVariantData.get_option_int(right, "request_id")
	)
	return snapshots


## 以层级、操作和场景路径组合 pending 路由索引键。
## [br]
## @api private
func _make_pending_async_route_key(
	path: String,
	layer: int,
	operation: Operation
) -> String:
	return (
		"%d:%d:%s"
		% [
			layer,
			int(operation),
			path,
		]
	)


## 按面板路径、层级和操作查找对应的 pending 路由条目。
## [br]
## @api private
func _find_pending_async_route(
	path: String,
	layer: int,
	operation: Operation
) -> _RouteRequestState:
	var key: String = _make_pending_async_route_key(
		path,
		layer,
		operation
	)
	return _get_pending_route(key)


## 将路由操作映射为 UI 面板操作标识。
## [br]
## @api private
func _operation_to_name(operation: Operation) -> StringName:
	return (GFUIRouteOperation.OPERATION_REPLACE if operation == Operation.REPLACE else GFUIRouteOperation.OPERATION_PUSH)


## 创建先写入路由参数与元数据、再调用用户配置函数的面板回调。
## [br]
## @api private
func _make_route_config_callback(
	route: GFUIRoute,
	params: Dictionary,
	config_callback: Callable
) -> Callable:
	return func(panel: Node) -> void:
		_apply_route_params(
			panel,
			route,
			params
		)
		if config_callback.is_valid():
			config_callback.call(panel)


## 复制路由可变容器字段，生成请求期间使用的路由快照。
## [br]
## @api private
func _make_route_request_snapshot(route_id: StringName, route: GFUIRoute) -> GFUIRoute:
	var snapshot: GFUIRoute = GFUIRoute.new()
	snapshot.route_id = route_id
	snapshot.scene_path = route.scene_path
	snapshot.layer = route.layer
	snapshot.default_options = route.default_options.duplicate(true)
	snapshot.metadata = route.metadata.duplicate(true)
	snapshot.adjacent_route_ids = route.adjacent_route_ids.duplicate()
	return snapshot


## 按预加载目录上限取得注册路由快照，并用请求路由替换同 ID 项。
## [br]
## @api private
func _make_preload_route_snapshots(source_route: GFUIRoute, options: Dictionary) -> Array[GFUIRoute]:
	var max_catalog_routes: int = maxi(
		GFVariantData.get_option_int(
			options,
			"max_catalog_routes",
			GFUIRoutePreloadUtility.DEFAULT_MAX_CATALOG_ROUTES
		),
		0
	)
	var input_limit: int = max_catalog_routes
	if _routes.size() > max_catalog_routes:
		input_limit += 1
	var snapshots: Array[GFUIRoute] = []
	var inspected_count: int = 0
	for route_key: Variant in _routes:
		if inspected_count >= input_limit:
			break
		inspected_count += 1
		var registered_route: GFUIRoute = _get_route_value(_routes[route_key])
		if registered_route == null:
			continue
		var registered_route_id: StringName = _normalize_route_id(GFVariantData.to_string_name(route_key))
		if registered_route_id == source_route.get_route_id():
			snapshots.append(source_route)
		else:
			snapshots.append(_make_route_request_snapshot(registered_route_id, registered_route))
	return snapshots


## 面板支持相应方法时，传入路由参数与路由元数据的深复制。
## [br]
## @api private
func _apply_route_params(
	panel: Node,
	route: GFUIRoute,
	params: Dictionary
) -> void:
	if not is_instance_valid(panel):
		return
	if panel.has_method("set_route_params"):
		panel.call(
			"set_route_params",
			params.duplicate(true)
		)
	if panel.has_method("set_route_metadata"):
		panel.call(
			"set_route_metadata",
			route.metadata.duplicate(true)
		)


## 依最大历史数记录路由、层级、弱面板引用及参数，并发出打开信号。
## [br]
## @api private
func _record_route_open(
	route: GFUIRoute,
	panel: Node,
	params: Dictionary,
	operation: Operation
) -> void:
	if max_history <= 0:
		route_opened.emit(
			route.get_route_id(),
			panel,
			operation
		)
		return

	_prune_history()
	_history.append(
		{
			"route_id": route.get_route_id(),
			"layer": route.layer,
			"panel_ref": weakref(panel),
			"params": params.duplicate(true),
			"metadata": route.metadata.duplicate(true),
		}
	)
	while _history.size() > max_history:
		_history.remove_at(0)
	route_opened.emit(
		route.get_route_id(),
		panel,
		operation
	)


## 移除已释放或已不在对应 UI 层栈中的历史面板。
## [br]
## @api private
func _prune_history() -> void:
	var ui_utility: GFUIUtility = _get_ui_utility()
	for index: int in range(
		_history.size() - 1,
		-1,
		-1
	):
		var entry: Dictionary = _history[index]
		var panel: Node = _get_history_panel(entry)
		var layer: int = GFVariantData.get_option_int(
			entry,
			"layer",
			GFUIUtility.Layer.POPUP
		)
		if (
			panel == null
			or (
				ui_utility != null
				and not ui_utility.is_panel_open(panel, layer)
			)
		):
			_history.remove_at(index)


## 从最新项向前查找历史；负层级表示不限定层级。
## [br]
## @api private
func _find_top_history_index(layer: int = -1) -> int:
	for index: int in range(
		_history.size() - 1,
		-1,
		-1
	):
		if layer < 0 or GFVariantData.get_option_int(
			_history[index],
			"layer",
			-1
		) == layer:
			return index
	return -1


## 从历史中移除指定层级的所有记录。
## [br]
## @api private
func _remove_history_for_layer(layer: int) -> void:
	for index: int in range(
		_history.size() - 1,
		-1,
		-1
	):
		if GFVariantData.get_option_int(
			_history[index],
			"layer",
			-1
		) == layer:
			_history.remove_at(index)


## 解析历史条目的弱面板引用；失效时返回 null。
## [br]
## @api private
func _get_history_panel(entry: Dictionary) -> Node:
	var panel_ref: WeakRef = _get_weak_ref_value(GFVariantData.get_option_value(entry, "panel_ref"))
	if panel_ref == null:
		return null
	return _INSTANCE_GUARD._get_live_node_from_ref(panel_ref)


## 将内部历史项转换为包含 route_id、层级、面板、参数和元数据的字典。
## [br]
## @api private
func _make_public_history_entry(entry: Dictionary) -> Dictionary:
	return {
		"route_id": GFVariantData.get_option_string_name(
			entry,
			"route_id",
			&""
		),
		"layer": GFVariantData.get_option_int(
			entry,
			"layer",
			GFUIUtility.Layer.POPUP
		),
		"panel": _get_history_panel(entry),
		"params": GFVariantData.get_option_dictionary(entry, "params"),
		"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
	}


## 显式目标失效时返回 null；仅未配置目标时从当前架构解析 UIUtility。
## [br]
## @api private
func _get_ui_utility() -> GFUIUtility:
	if _ui_utility_ref != null:
		return _get_ui_utility_value(_ui_utility_ref.get_ref())

	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return _get_ui_utility_value(architecture.get_utility(GFUIUtility))


## 从当前架构读取 GFAssetUtility；缺失或类型不符时返回 null。
## [br]
## @api private
func _get_asset_utility() -> GFAssetUtility:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	var value: Variant = architecture.get_utility(GFAssetUtility)
	if value is GFAssetUtility:
		var asset_utility: GFAssetUtility = value
		return asset_utility
	return null


## 将 Variant 收窄为 GFUIRoute；类型不符时返回 null。
## [br]
## @api private
func _get_route_value(value: Variant) -> GFUIRoute:
	if value is GFUIRoute:
		var route: GFUIRoute = value
		return route
	return null


## 去除路由标识两端空白并返回 StringName。
## [br]
## @api private
func _normalize_route_id(route_id: StringName) -> StringName:
	return StringName(String(route_id).strip_edges())


## 按字典遍历顺序检查至多 limit 项，筛出类型正确的注册路由。
## [br]
## @api private
func _get_registered_routes(limit: int) -> Array[GFUIRoute]:
	var result: Array[GFUIRoute] = []
	var inspected_count: int = 0
	for route_key: Variant in _routes:
		if inspected_count >= limit:
			break
		inspected_count += 1
		var route: GFUIRoute = _get_route_value(_routes[route_key])
		if route != null:
			result.append(route)
	return result


## 将 Variant 收窄为 GFUIUtility；类型不符时返回 null。
## [br]
## @api private
func _get_ui_utility_value(value: Variant) -> GFUIUtility:
	if value is GFUIUtility:
		var ui_utility: GFUIUtility = value
		return ui_utility
	return null


## 将 Variant 收窄为 GFAssetPreloadPlan；类型不符时返回 null。
## [br]
## @api private
func _get_asset_preload_plan_value(value: Variant) -> GFAssetPreloadPlan:
	if value is GFAssetPreloadPlan:
		var asset_plan: GFAssetPreloadPlan = value
		return asset_plan
	return null


## 返回仍有效的 Object；非对象或已释放对象均返回 null。
## [br]
## @api private
func _get_object_value(value: Variant) -> Object:
	if value is Object:
		var object_value: Object = value
		if is_instance_valid(object_value):
			return object_value
	return null


## 从弱引用取得仍有效的对象；空引用或对象失效时返回 null。
## [br]
## @api private
func _get_live_object_from_ref(object_ref: WeakRef) -> Object:
	if object_ref == null:
		return null
	return _get_object_value(object_ref.get_ref())


## 将 Variant 收窄为 GFAsyncScope；类型不符时返回 null。
## [br]
## @api private
func _get_async_scope_value(value: Variant) -> GFAsyncScope:
	if value is GFAsyncScope:
		var scope: GFAsyncScope = value
		return scope
	return null


## 将 Variant 收窄为 WeakRef；类型不符时返回 null。
## [br]
## @api private
func _get_weak_ref_value(value: Variant) -> WeakRef:
	if value is WeakRef:
		var object_ref: WeakRef = value
		return object_ref
	return null


## 转换层级值，并在结果为负数时返回调用方指定的 fallback。
## [br]
## @api private
func _get_ui_layer(value: Variant, fallback: int = GFUIUtility.DEFAULT_LAYER_ID) -> int:
	var layer_value: int = GFVariantData.to_int(value, fallback)
	return layer_value if layer_value >= 0 else fallback


# --- 信号处理函数 ---

## 原页面关闭立即终结导航，保持其他页面的导航独立。
## [br]
## @api private
func _on_navigation_panel_closed(
	panel: Node,
	pending_key: String,
	request_id: int
) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if _get_navigation_panel(entry) == panel:
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_CANCELLED,
			&"panel_closed",
			panel,
			false
		)


## 只接受原请求和原阶段的完成源；先清理观察再启动下一阶段。
## [br]
## @api private
func _on_navigation_phase_completed(
	completion: GFAsyncCompletion,
	pending_key: String,
	request_id: int,
	phase: StringName
) -> void:
	if not _check_navigation_alive(pending_key, request_id):
		return
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if (
		entry._navigation._completion != completion
		or entry._navigation._phase != phase
		or not completion.is_completed()
	):
		return
	_disconnect_navigation_completion(entry)

	var panel: Node = _get_navigation_panel(entry)
	if not completion.is_successful():
		var status: StringName = GFUIRouteResult.STATUS_CONTENT_FAILED if phase == &"content" else GFUIRouteResult.STATUS_TARGET_UNAVAILABLE
		if completion.is_cancelled():
			status = GFUIRouteResult.STATUS_CANCELLED
		_complete_pending_route(
			pending_key,
			request_id,
			status,
			&"content_failed" if phase == &"content" else &"target_unavailable",
			panel,
			false
		)
		return
	if phase == &"content":
		entry._navigation._content_ready = true

		var target: GFUINavigationTarget = entry._navigation._target
		if target.has_semantic_target():
			_start_navigation_phase(
				pending_key,
				request_id,
				&"target"
			)
		else:
			_complete_pending_route(
				pending_key,
				request_id,
				GFUIRouteResult.STATUS_CONTENT_READY,
				&"",
				panel,
				false
			)
	else:
		entry._navigation._target_resolved = true

		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_TARGET_READY,
			&"",
			panel,
			false
		)


## 校验面板异步操作与 pending 路由身份，并映射其状态到路由终态。
## [br]
## @api private
func _on_ui_panel_async_operation_completed(
	ui_operation: GFUIPanelAsyncOperation,
	pending_key: String,
	request_id: int
) -> void:
	if ui_operation == null or not ui_operation.is_completed():
		return
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	var route_entry: _RouteRequestState = _get_pending_route(pending_key)
	if route_entry == null or not route_entry._panel_submitted:
		return
	if (route_entry._navigation != null and route_entry._navigation._panel_committed):
		return
	var latched_ui_operation: GFUIPanelAsyncOperation = route_entry._ui_operation
	if latched_ui_operation != null and latched_ui_operation != ui_operation:
		return
	var route_snapshot: GFUIRoute = route_entry._route_snapshot
	var route_operation: Operation = route_entry._operation
	if (
		route_snapshot == null
		or ui_operation.get_path() != route_snapshot.scene_path
		or ui_operation.get_layer() != _get_ui_layer(route_snapshot.layer)
		or ui_operation.get_operation() != _operation_to_name(route_operation)
	):
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_PANEL_FAILED,
			&"panel_async_identity_mismatch",
			null,
			true
		)
		return
	if latched_ui_operation == null:
		route_entry._ui_operation = ui_operation

	var status: int = ui_operation.get_status()
	var panel: Node = ui_operation.get_panel()
	if status == GFUIUtility.AsyncPanelLoadStatus.OPENED and is_instance_valid(panel):
		_complete_pending_route_opened(
			pending_key,
			request_id,
			route_snapshot,
			route_operation,
			panel
		)
		return
	if status == GFUIUtility.AsyncPanelLoadStatus.CANCELLED:
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_CANCELLED,
			&"panel_async_cancelled",
			null,
			true
		)
		return
	_complete_pending_route(
		pending_key,
		request_id,
		GFUIRouteResult.STATUS_PANEL_FAILED,
		&"panel_async_failed",
		null,
		true
	)


## 取消原请求的等待；已提交导航保留页面，尚在面板 IO 的导航锁存失效原因待底层确认。
## [br]
## @api private
func _on_pending_route_lifecycle_cancelled(
	pending_key: String,
	request_id: int,
	reason: StringName
) -> void:
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if entry == null:
		return
	var operation_handle: GFUIRouteOperation = entry._operation_handle
	if operation_handle == null or operation_handle.get_request_id() != request_id:
		return
	if entry._panel_submitted:
		if (entry._navigation != null and entry._navigation._panel_committed):
			_complete_pending_route(
				pending_key,
				request_id,
				GFUIRouteResult.STATUS_CANCELLED,
				reason,
				_get_navigation_panel(entry),
				false
			)
		elif entry._navigation != null:
			entry._navigation._cancel_reason = reason if reason != &"" else &"lifecycle_cancelled"

		return
	var final_reason: StringName = reason if reason != &"" else &"lifecycle_cancelled"
	var _cancelled: bool = _finish_pending_route_before_submit(
		pending_key,
		request_id,
		GFUIRouteResult.STATUS_CANCELLED,
		final_reason,
		false
	)


## 先验证请求身份与生命周期，再存下预载结果并移除回调记录。
## 预载必需策略失败时终结路由；可选策略失败登记降级原因后仍继续提交面板。
## [br]
## @api private
func _on_pending_route_preload_completed(
	preload_result: GFAssetLoadSessionResult,
	pending_key: String,
	request_id: int
) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	if _cancel_pending_route_if_lifecycle_expired(pending_key, request_id):
		return
	var entry: _RouteRequestState = _get_pending_route(pending_key)
	if entry == null:
		return
	entry._preload._callback = Callable()
	entry._preload._result = preload_result


	if preload_result != null and preload_result.is_successful():
		_submit_pending_panel_open(pending_key, request_id)
		return
	var preload_policy: StringName = entry._preload_policy
	if preload_policy == PRELOAD_REQUIRED:
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_PRELOAD_FAILED,
			&"preload_failed",
			null,
			true
		)
		return
	_set_pending_preload_degradation(
		pending_key,
		request_id,
		&"preload_failed_continued"
	)
	_submit_pending_panel_open(pending_key, request_id)


# --- 内部类 ---

## 一次准入后始终保留身份的请求状态；只在 pending 表首次发布，终结后不得重新插入。
## [br]
## @api private
class _RouteRequestState extends RefCounted:


	# --- 私有变量 ---

	## 请求的规范化路由标识。
	## [br]
	## @api private
	var _route_id: StringName = &""

	## 准入时固定的单调时钟。
	## [br]
	## @api private
	var _clock: GFClock = null

	## 请求声明的 UI 层级。
	## [br]
	## @api private
	var _layer: int = -1

	## 已验证的路由操作。
	## [br]
	## @api private
	var _operation: Operation = Operation.PUSH

	## 拒绝迟到回调的请求身份。
	## [br]
	## @api private
	var _request_id: int = 0

	## 供外部观察的请求句柄。
	## [br]
	## @api private
	var _operation_handle: GFUIRouteOperation = null

	## 请求独占的路由定义快照。
	## [br]
	## @api private
	var _route_snapshot: GFUIRoute = null

	## 已解析的面板场景路径。
	## [br]
	## @api private
	var _path: String = ""

	## 请求独占的参数容器；仅在输出边界再次复制。
	## [br]
	## @api private
	var _params: Dictionary = {}

	## 请求独占的合并面板选项。
	## [br]
	## @api private
	var _options: Dictionary = {}

	## 原始配置回调及请求复用身份。
	## [br]
	## @api private
	var _config_callback: Callable = Callable()

	## 请求独占的元数据快照。
	## [br]
	## @api private
	var _metadata: Dictionary = {}

	## 已解析的预加载策略。
	## [br]
	## @api private
	var _preload_policy: StringName = PRELOAD_NONE

	## 原始预加载选项快照，供请求等价比较。
	## [br]
	## @api private
	var _preload_plan_options: Dictionary = {}

	## 不延长 owner 存活时间的弱引用。
	## [br]
	## @api private
	var _owner_ref: WeakRef = null

	## 准入时记录的 owner 身份。
	## [br]
	## @api private
	var _owner_id: int = 0

	## 准入时记录的 scope 身份。
	## [br]
	## @api private
	var _scope_id: int = 0

	## 进入底层 UI 调用之前发布的提交事实。
	## [br]
	## @api private
	var _panel_submitted: bool = false

	## 锁定本请求的底层面板操作。
	## [br]
	## @api private
	var _ui_operation: GFUIPanelAsyncOperation = null

	## 可独立断开的底层完成观察。
	## [br]
	## @api private
	var _ui_completion_callback: Callable = Callable()

	## 请求持有的 owner 生命周期订阅。
	## [br]
	## @api private
	var _owner_lifetime: GFLifetimeSubscription = null

	## 尚需观察的调用方作用域。
	## [br]
	## @api private
	var _scope: GFAsyncScope = null

	## 可独立断开的作用域取消观察。
	## [br]
	## @api private
	var _scope_callback: Callable = Callable()

	## 仅导航请求分配的就绪阶段状态。
	## [br]
	## @api private
	var _navigation: _NavigationState = null

	## 仅执行预加载的请求分配的工作状态。
	## [br]
	## @api private
	var _preload: _PreloadState = null


## 仅导航请求持有的内容和语义定位状态；普通打开不分配。
## [br]
## @api private
class _NavigationState extends RefCounted:


	# --- 私有变量 ---

	## 已经校验的不可变导航目标。
	## [br]
	## @api private
	var _target: GFUINavigationTarget = null

	## 本次导航使用的项目解析器。
	## [br]
	## @api private
	var _resolver: GFUINavigationResolver = null

	## 内容和定位共享的等待预算。
	## [br]
	## @api private
	var _timeout_msec: int = 15000

	## 页面所属 UI 工具的弱引用。
	## [br]
	## @api private
	var _ui_ref: WeakRef = null

	## 已提交原页面的弱引用。
	## [br]
	## @api private
	var _panel_ref: WeakRef = null

	## 终态时撤销项目写回资格的作用域。
	## [br]
	## @api private
	var _scope: GFAsyncScope = null

	## 页面提交时固定的就绪截止时刻。
	## [br]
	## @api private
	var _deadline: int = 0

	## 当前等待的内容或定位阶段。
	## [br]
	## @api private
	var _phase: StringName = &""

	## 当前阶段唯一接受的完成源。
	## [br]
	## @api private
	var _completion: GFAsyncCompletion = null

	## 当前完成源上的回调。
	## [br]
	## @api private
	var _callback: Callable = Callable()

	## 原页面关闭信号上的回调。
	## [br]
	## @api private
	var _close_callback: Callable = Callable()

	## 底层面板提交期间锁存的取消原因。
	## [br]
	## @api private
	var _cancel_reason: StringName = &""

	## 原页面曾成功提交的事实。
	## [br]
	## @api private
	var _panel_committed: bool = false

	## 内容阶段已成功完成的事实。
	## [br]
	## @api private
	var _content_ready: bool = false

	## 语义目标已成功定位的事实。
	## [br]
	## @api private
	var _target_resolved: bool = false


## 仅启用预加载时持有的规划和会话状态。
## [br]
## @api private
class _PreloadState extends RefCounted:


	# --- 私有变量 ---

	## 规划期间独占的已注册路由快照。
	## [br]
	## @api private
	var _routes: Array[GFUIRoute] = []

	## JSON 安全的预加载计划报告。
	## [br]
	## @api private
	var _plan_report: Dictionary = {}

	## 预加载会话的已知结果。
	## [br]
	## @api private
	var _result: GFAssetLoadSessionResult = null

	## 是否已经尝试创建预加载会话。
	## [br]
	## @api private
	var _attempted: bool = false

	## 尽力预加载降级后的终态原因。
	## [br]
	## @api private
	var _degradation_reason: StringName = &""

	## 终态是否需要释放框架创建的预加载组。
	## [br]
	## @api private
	var _owns_group: bool = false

	## 避免重复启动规划的执行标记。
	## [br]
	## @api private
	var _started: bool = false

	## 本请求持有的预加载会话。
	## [br]
	## @api private
	var _session: GFAssetLoadSession = null

	## 可独立断开的预加载完成观察。
	## [br]
	## @api private
	var _callback: Callable = Callable()
