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
## @param route_id: 路由标识。
## [br]
## @param operation: 打开操作。
## [br]
## @param params: 路由参数。
## [br]
## @schema params: Dictionary，本次打开路由携带的项目自定义参数。
signal route_open_requested(route_id: StringName, operation: Operation, params: Dictionary)

## 路由面板成功打开后触发。
## [br]
## @api public
## [br]
## @param route_id: 路由标识。
## [br]
## @param panel: 面板实例。
## [br]
## @param operation: 打开操作。
signal route_opened(route_id: StringName, panel: Node, operation: Operation)

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

var _routes: Dictionary = {}
var _ui_utility_ref: WeakRef = null
var _history: Array[Dictionary] = []
var _pending_async_routes: Dictionary = {}
var _next_async_request_id: int = 1
var _disposed: bool = false


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


## 清理普通 Object owner 已释放的提交前路由请求。
## Node owner 和 GFAsyncScope 会通过信号即时取消；普通 Object 依赖本帧弱引用检查。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param _delta: 本帧时间增量；生命周期清理不依赖具体数值。
func tick(_delta: float) -> void:
	_prune_pending_route_lifecycles()


# --- 公共方法 ---

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
	if (
		not _pending_async_routes.is_empty()
		and ui_utility != current_ui_utility
	):
		push_warning("[GFUIRouterUtility] 存在异步路由请求时不能更换 GFUIUtility。")
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
		GFVariantData.get_option_value(_routes, _normalize_route_id(route_id))
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
	return _open_route(route_id, Operation.PUSH, params, option_overrides, config_callback)


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
	return _open_route(route_id, Operation.REPLACE, params, option_overrides, config_callback)


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
## @schema async_options: Dictionary，可包含 preload_policy、preload_plan_options、metadata、owner: Object 和 scope: GFAsyncScope；owner 与 scope 使用 OR 取消语义且只约束面板提交前，preload_policy 使用 PRELOAD_* 常量，自动预加载始终包含当前路由，未指定 max_depth 时只加载当前页面。
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
## @schema async_options: Dictionary，可包含 preload_policy、preload_plan_options、metadata、owner: Object 和 scope: GFAsyncScope；owner 与 scope 使用 OR 取消语义且只约束面板提交前，preload_policy 使用 PRELOAD_* 常量，自动预加载始终包含当前路由，未指定 max_depth 时只加载当前页面。
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

	var route_id: StringName = GFVariantData.get_option_string_name(entry, "route_id", &"")
	var route_layer: int = GFVariantData.get_option_int(entry, "layer", GFUIUtility.Layer.POPUP)
	var route_panel: Node = _get_history_panel(entry)
	if route_panel == null or ui_utility.get_top_panel(_get_ui_layer(route_layer)) != route_panel:
		push_warning("[GFUIRouterUtility] back 失败：路由面板不是当前 UI 栈顶。")
		return false

	ui_utility.pop_panel(_get_ui_layer(route_layer), do_free)
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
	return GFVariantData.get_option_string_name(_history[history_index], "route_id", &"")


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

	var ui_utility: GFUIUtility = _get_ui_utility()
	if ui_utility == null:
		_fail_route(normalized_route_id, "missing_ui_utility")
		return null
	var route_layer: int = _get_ui_layer(route.layer)
	if not ui_utility.has_layer(route_layer):
		_fail_route(normalized_route_id, "missing_ui_layer")
		return null

	route_open_requested.emit(normalized_route_id, operation, params.duplicate(true))
	var options: Dictionary = route.build_options(params, option_overrides)
	var wrapped_callback: Callable = _make_route_config_callback(route, params, config_callback)
	var panel: Node = null
	if operation == Operation.REPLACE:
		_remove_history_for_layer(route.layer)
		panel = ui_utility.replace_layer_with_options(
			route.scene_path,
			route_layer,
			options,
			wrapped_callback
		)
	else:
		panel = ui_utility.push_panel_with_options(
			route.scene_path,
			route_layer,
			options,
			wrapped_callback
		)

	if panel == null:
		_fail_route(normalized_route_id, "panel_open_failed")
		return null

	_record_route_open(route, panel, params, operation)
	return panel


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
	var immediate_entry: Dictionary = _make_route_operation_entry(
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
	immediate_entry["layer"] = route.layer
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
	var route_layer: int = _get_ui_layer(route.layer)
	if not ui_utility.has_layer(route_layer):
		_finish_route_entry(
			immediate_entry,
			GFUIRouteResult.STATUS_MISSING_UI_LAYER,
			&"missing_ui_layer",
			null,
			true
		)
		return operation_handle

	_prune_pending_route_lifecycles()
	var pending_route: Dictionary = _find_pending_async_route(route.scene_path, route.layer, operation)
	if not pending_route.is_empty():
		if _pending_route_matches_request(
			pending_route,
			normalized_route_id,
			params,
			option_overrides,
			config_callback,
			preload_policy,
			GFVariantData.get_option_dictionary(async_options, "preload_plan_options"),
			metadata,
			GFVariantData.get_option_int(lifecycle, "owner_id"),
			GFVariantData.get_option_int(lifecycle, "scope_id")
		):
			var pending_handle: GFUIRouteOperation = _get_route_operation_value(
				pending_route.get("operation_handle")
			)
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

	var pending_key: String = _make_pending_async_route_key(route.scene_path, route.layer, operation)
	var request_id: int = operation_handle.get_request_id()
	var pending_entry: Dictionary = immediate_entry.duplicate(true)
	pending_entry.merge({
		"route_id": normalized_route_id,
		"route": route,
		"path": route.scene_path,
		"layer": route.layer,
		"operation": operation,
		"operation_handle": operation_handle,
		"params": params.duplicate(true),
		"option_overrides": option_overrides.duplicate(true),
		"config_callback": config_callback,
		"preload_policy": preload_policy,
		"preload_plan_options": GFVariantData.get_option_dictionary(
			async_options,
			"preload_plan_options"
		),
		"metadata": metadata.duplicate(true),
		"preload_plan_report": {},
		"preload_result": null,
		"preload_attempted": false,
		"preload_successful": false,
		"preload_degradation_reason": &"",
		"owns_preload_group": false,
		"preload_started": false,
		"panel_submitted": false,
	}, true)
	_pending_async_routes[pending_key] = pending_entry
	_bind_pending_route_lifecycle(
		pending_key,
		request_id,
		_get_object_value(lifecycle.get("owner")),
		_get_async_scope_value(lifecycle.get("scope"))
	)
	if not _pending_route_has_request_id(pending_key, request_id):
		return operation_handle
	route_open_requested.emit(normalized_route_id, operation, params.duplicate(true))
	if not _pending_route_has_request_id(pending_key, request_id):
		return operation_handle
	if preload_policy == PRELOAD_NONE:
		_submit_pending_panel_open(pending_key, request_id)
	else:
		_start_pending_route_preload(pending_key, request_id)
	return operation_handle


func _resolve_route_or_fail(route_id: StringName) -> GFUIRoute:
	var route: GFUIRoute = get_route(route_id)
	if route == null:
		_fail_route(route_id, "missing_route")
		return null
	if not route.is_valid_route():
		_fail_route(route_id, "invalid_route")
		return null
	return route


func _fail_route(route_id: StringName, reason: String) -> void:
	route_open_failed.emit(route_id, reason)
	push_warning("[GFUIRouterUtility] 路由打开失败：%s (%s)" % [String(route_id), reason])


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
		Time.get_ticks_msec()
	)
	if not configured:
		push_error("[GFUIRouterUtility] 无法创建异步路由请求句柄。")
	return operation_handle


func _make_route_operation_entry(
	operation_handle: GFUIRouteOperation,
	operation: Operation,
	preload_policy: StringName,
	metadata: Dictionary
) -> Dictionary:
	return {
		"route_id": operation_handle.get_route_id(),
		"layer": -1,
		"operation": operation,
		"request_id": operation_handle.get_request_id(),
		"operation_handle": operation_handle,
		"preload_policy": preload_policy,
		"preload_plan_report": {},
		"preload_result": null,
		"preload_attempted": false,
		"preload_successful": false,
		"preload_degradation_reason": &"",
		"owns_preload_group": false,
		"panel_submitted": false,
		"ui_operation": null,
		"ui_completion_callback": Callable(),
		"owner_ref": null,
		"owner_id": 0,
		"owner_lifetime": null,
		"scope": null,
		"scope_id": 0,
		"scope_callback": Callable(),
		"metadata": metadata.duplicate(true),
	}


func _get_preload_policy(async_options: Dictionary) -> StringName:
	if not async_options.has("preload_policy"):
		return PRELOAD_NONE
	var raw_policy: StringName = GFVariantData.get_option_string_name(
		async_options,
		"preload_policy",
		&""
	)
	return StringName(String(raw_policy).strip_edges().to_lower())


func _is_valid_preload_policy(preload_policy: StringName) -> bool:
	return preload_policy in [PRELOAD_NONE, PRELOAD_BEST_EFFORT, PRELOAD_REQUIRED]


func _pending_route_matches_request(
	entry: Dictionary,
	route_id: StringName,
	params: Dictionary,
	option_overrides: Dictionary,
	config_callback: Callable,
	preload_policy: StringName,
	preload_plan_options: Dictionary,
	metadata: Dictionary,
	owner_id: int,
	scope_id: int
) -> bool:
	return (
		GFVariantData.get_option_string_name(entry, "route_id", &"") == route_id
		and GFVariantData.get_option_dictionary(entry, "params") == params
		and GFVariantData.get_option_dictionary(entry, "option_overrides") == option_overrides
		and _get_callable_value(entry.get("config_callback")) == config_callback
		and GFVariantData.get_option_string_name(entry, "preload_policy", PRELOAD_NONE) == preload_policy
		and GFVariantData.get_option_dictionary(entry, "preload_plan_options") == preload_plan_options
		and GFVariantData.get_option_dictionary(entry, "metadata") == metadata
		and GFVariantData.get_option_int(entry, "owner_id") == owner_id
		and GFVariantData.get_option_int(entry, "scope_id") == scope_id
	)


func _parse_route_lifecycle_options(async_options: Dictionary) -> Dictionary:
	var owner: Object = null
	if async_options.has("owner"):
		var raw_owner: Variant = async_options.get("owner")
		if raw_owner != null:
			if not (raw_owner is Object):
				return {"valid": false, "reason": &"invalid_owner"}
			owner = raw_owner
			if not is_instance_valid(owner):
				return {"valid": false, "reason": &"invalid_owner"}
			if owner is Node:
				var owner_node: Node = owner
				if not owner_node.is_inside_tree():
					return {"valid": false, "reason": &"owner_not_in_tree"}

	var scope: GFAsyncScope = null
	if async_options.has("scope"):
		var raw_scope: Variant = async_options.get("scope")
		if raw_scope != null:
			if not (raw_scope is GFAsyncScope):
				return {"valid": false, "reason": &"invalid_scope"}
			scope = raw_scope
			if scope.is_completed():
				return {"valid": false, "reason": &"scope_completed"}
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


func _apply_route_lifecycle_to_entry(entry: Dictionary, lifecycle: Dictionary) -> void:
	var owner: Object = _get_object_value(lifecycle.get("owner"))
	var scope: GFAsyncScope = _get_async_scope_value(lifecycle.get("scope"))
	entry["owner_ref"] = weakref(owner) if owner != null else null
	entry["owner_id"] = owner.get_instance_id() if owner != null else 0
	entry["scope"] = scope
	entry["scope_id"] = scope.get_instance_id() if scope != null else 0


func _bind_pending_route_lifecycle(
	pending_key: String,
	request_id: int,
	owner: Object,
	scope: GFAsyncScope
) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if entry.is_empty():
		return
	var operation_handle: GFUIRouteOperation = _get_route_operation_value(entry.get("operation_handle"))
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
		var owner_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(
			self,
			&"_on_pending_route_lifecycle_cancelled"
		)
		var owner_reason: StringName = &"owner_tree_exited" if owner is Node else &"owner_released"
		var owner_callback: Callable = func() -> void:
			var _invocation_result: Dictionary = owner_invocation.invoke([
				pending_key,
				request_id,
				owner_reason,
			])
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
		entry["owner_lifetime"] = owner_lifetime

	if scope != null:
		var scope_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(
			self,
			&"_on_pending_route_lifecycle_cancelled"
		)
		var scope_callback: Callable = func(reason: StringName) -> void:
			var _invocation_result: Dictionary = scope_invocation.invoke([
				pending_key,
				request_id,
				reason if reason != &"" else &"scope_cancelled",
			])
		entry["scope_callback"] = scope_callback
		var connect_error: Error = scope.cancel_requested.connect(scope_callback) as Error
		if connect_error != OK:
			_pending_async_routes[pending_key] = entry
			var _scope_connect_finished: bool = _finish_pending_route_before_submit(
				pending_key,
				request_id,
				GFUIRouteResult.STATUS_INVALID_LIFECYCLE,
				&"scope_connect_failed",
				true
			)
			return

	_pending_async_routes[pending_key] = entry
	if scope != null and scope.is_cancel_requested():
		_on_pending_route_lifecycle_cancelled(
			pending_key,
			request_id,
			_get_scope_cancel_reason(scope)
		)


func _on_pending_route_lifecycle_cancelled(
	pending_key: String,
	request_id: int,
	reason: StringName
) -> void:
	var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	var operation_handle: GFUIRouteOperation = _get_route_operation_value(entry.get("operation_handle"))
	if operation_handle == null or operation_handle.get_request_id() != request_id:
		return
	if GFVariantData.get_option_bool(entry, "panel_submitted"):
		return
	var final_reason: StringName = reason if reason != &"" else &"lifecycle_cancelled"
	var _cancelled: bool = _finish_pending_route_before_submit(
		pending_key,
		request_id,
		GFUIRouteResult.STATUS_CANCELLED,
		final_reason,
		false
	)


func _prune_pending_route_lifecycles() -> void:
	if _pending_async_routes.is_empty():
		return
	var pending_keys: Array = _pending_async_routes.keys()
	for pending_key_value: Variant in pending_keys:
		var pending_key: String = GFVariantData.to_text(pending_key_value)
		var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
		if entry.is_empty() or GFVariantData.get_option_bool(entry, "panel_submitted"):
			continue
		var expired_reason: StringName = _get_route_lifecycle_expired_reason(entry)
		if expired_reason == &"":
			continue
		var operation_handle: GFUIRouteOperation = _get_route_operation_value(
			entry.get("operation_handle")
		)
		if operation_handle != null:
			_on_pending_route_lifecycle_cancelled(
				pending_key,
				operation_handle.get_request_id(),
				expired_reason
			)


func _get_route_lifecycle_expired_reason(entry: Dictionary) -> StringName:
	var owner_id: int = GFVariantData.get_option_int(entry, "owner_id")
	if owner_id != 0:
		var owner_ref: WeakRef = _get_weak_ref_value(entry.get("owner_ref"))
		var owner: Object = _get_live_object_from_ref(owner_ref)
		if owner == null or owner.get_instance_id() != owner_id:
			return &"owner_released"
		if owner is Node:
			var owner_node: Node = owner
			if not owner_node.is_inside_tree():
				return &"owner_tree_exited"

	var scope: GFAsyncScope = _get_async_scope_value(entry.get("scope"))
	if scope != null:
		if scope.is_cancel_requested():
			return _get_scope_cancel_reason(scope)
		if scope.is_completed():
			return &"scope_completed"
	return &""


func _finish_pending_route_before_submit(
	pending_key: String,
	request_id: int,
	status: StringName,
	reason: StringName,
	emit_legacy_failure: bool
) -> bool:
	if not _pending_route_has_request_id(pending_key, request_id):
		return false
	var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if entry.is_empty() or GFVariantData.get_option_bool(entry, "panel_submitted"):
		return false
	var _erased: bool = _pending_async_routes.erase(pending_key)
	_disconnect_entry_lifecycle(entry)
	_disconnect_entry_preload_callback(entry)
	var session: GFAssetLoadSession = _get_asset_load_session_value(entry.get("preload_session"))
	if session != null and not session.is_completed():
		var _rolled_back: bool = session.rollback(reason)
	_finish_route_entry(entry, status, reason, null, emit_legacy_failure)
	return true


func _get_scope_cancel_reason(scope: GFAsyncScope) -> StringName:
	if scope == null:
		return &"scope_cancelled"
	var reason: StringName = scope.get_cancel_reason()
	return reason if reason != &"" else &"scope_cancelled"


func _cancel_pending_route_if_lifecycle_expired(pending_key: String, request_id: int) -> bool:
	if not _pending_route_has_request_id(pending_key, request_id):
		return false
	var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if entry.is_empty() or GFVariantData.get_option_bool(entry, "panel_submitted"):
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


func _pending_route_has_request_id(pending_key: String, request_id: int) -> bool:
	var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	return GFVariantData.get_option_int(entry, "request_id") == request_id


func _start_pending_route_preload(pending_key: String, request_id: int) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	if _cancel_pending_route_if_lifecycle_expired(pending_key, request_id):
		return
	var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if entry.is_empty() or GFVariantData.get_option_bool(entry, "preload_started"):
		return
	entry["preload_started"] = true
	_pending_async_routes[pending_key] = entry
	var route_id: StringName = GFVariantData.get_option_string_name(entry, "route_id", &"")
	var operation_handle: GFUIRouteOperation = _get_route_operation_value(entry.get("operation_handle"))
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
	var plan_options: Dictionary = GFVariantData.get_option_dictionary(entry, "preload_plan_options")
	plan_options["include_source"] = true
	if not plan_options.has("max_depth"):
		plan_options["max_depth"] = 0
	var group_id: StringName = GFVariantData.get_option_string_name(plan_options, "group_id", &"")
	if group_id == &"":
		group_id = StringName("_gf_ui_route_request_%d" % operation_handle.get_request_id())
		plan_options["group_id"] = group_id
		entry["owns_preload_group"] = true
	if GFVariantData.get_option_string_name(plan_options, "plan_id", &"") == &"":
		plan_options["plan_id"] = StringName("ui_route_request:%d" % operation_handle.get_request_id())
	var plan_metadata: Dictionary = GFVariantData.get_option_dictionary(plan_options, "metadata")
	plan_metadata["_gf_route_request_id"] = operation_handle.get_request_id()
	plan_metadata["_gf_route_id"] = route_id
	plan_options["metadata"] = plan_metadata
	_pending_async_routes[pending_key] = entry

	var raw_plan_report: Dictionary = build_preload_plan(route_id, plan_options)
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	if _cancel_pending_route_if_lifecycle_expired(pending_key, request_id):
		return
	entry = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	var asset_plan: GFAssetPreloadPlan = _get_asset_preload_plan_value(raw_plan_report.get("asset_plan"))
	entry["preload_plan_report"] = _make_json_safe_preload_plan_report(raw_plan_report, asset_plan)
	_pending_async_routes[pending_key] = entry

	var plan_ok: bool = GFVariantData.get_option_bool(raw_plan_report, "ok")
	var plan_healthy: bool = GFVariantData.get_option_bool(raw_plan_report, "healthy")
	var plan_usable: bool = plan_ok and asset_plan != null and not asset_plan.is_empty()
	var preload_policy: StringName = GFVariantData.get_option_string_name(
		entry,
		"preload_policy",
		PRELOAD_NONE
	)
	if preload_policy == PRELOAD_REQUIRED and (not plan_usable or not plan_healthy):
		var plan_reason: StringName = &"preload_plan_failed"
		if plan_usable and not plan_healthy:
			plan_reason = &"preload_plan_unhealthy"
		elif plan_ok and asset_plan != null and asset_plan.is_empty():
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

	var session_metadata: Dictionary = GFVariantData.get_option_dictionary(entry, "metadata")
	session_metadata["route_request_id"] = operation_handle.get_request_id()
	session_metadata["route_id"] = route_id
	var session: GFAssetLoadSession = asset_utility.start_preload_session(
		asset_plan,
		{
			"auto_commit": true,
			"metadata": session_metadata,
		}
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
			var _unattached_session_rolled_back: bool = session.rollback(
				&"preload_session_attach_failed"
			)
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_PRELOAD_FAILED,
			&"preload_session_attach_failed",
			null,
			true
		)
		return
	entry = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if entry.is_empty():
		if session != null and not session.is_completed():
			var _rolled_back: bool = session.rollback(&"route_request_gone")
		return
	entry["preload_session"] = session
	entry["preload_attempted"] = true
	_pending_async_routes[pending_key] = entry
	if session == null:
		_on_pending_route_preload_completed(null, pending_key, request_id)
		return
	if session.is_completed():
		_on_pending_route_preload_completed(session.get_result(), pending_key, request_id)
		return
	var preload_callback: Callable = _on_pending_route_preload_completed.bind(
		pending_key,
		request_id
	)
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
	entry = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if _pending_route_has_request_id(pending_key, request_id):
		entry = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
		entry["preload_callback"] = preload_callback
		_pending_async_routes[pending_key] = entry


func _on_pending_route_preload_completed(
	preload_result: GFAssetLoadSessionResult,
	pending_key: String,
	request_id: int
) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	if _cancel_pending_route_if_lifecycle_expired(pending_key, request_id):
		return
	var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if entry.is_empty():
		return
	var _erased_callback: bool = entry.erase("preload_callback")
	entry["preload_result"] = preload_result
	entry["preload_successful"] = preload_result != null and preload_result.is_successful()
	_pending_async_routes[pending_key] = entry
	if preload_result != null and preload_result.is_successful():
		_submit_pending_panel_open(pending_key, request_id)
		return
	var preload_policy: StringName = GFVariantData.get_option_string_name(
		entry,
		"preload_policy",
		PRELOAD_NONE
	)
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


func _set_pending_preload_degradation(
	pending_key: String,
	request_id: int,
	reason: StringName
) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if entry.is_empty():
		return
	entry["preload_degradation_reason"] = reason
	_pending_async_routes[pending_key] = entry


func _submit_pending_panel_open(pending_key: String, request_id: int) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	if _cancel_pending_route_if_lifecycle_expired(pending_key, request_id):
		return
	var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if entry.is_empty() or GFVariantData.get_option_bool(entry, "panel_submitted"):
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
	var route: GFUIRoute = _get_route_value(entry.get("route"))
	if route == null:
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
	var route_layer: int = _get_ui_layer(route.layer)
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
	var operation: Operation = _get_route_operation(entry)
	if _ui_has_matching_pending_request(ui_utility, route.scene_path, route_layer, operation):
		_complete_pending_route(
			pending_key,
			request_id,
			GFUIRouteResult.STATUS_ASYNC_CONFLICT,
			&"ui_async_request_conflict",
			null,
			true
		)
		return
	var params: Dictionary = GFVariantData.get_option_dictionary(entry, "params")
	var option_overrides: Dictionary = GFVariantData.get_option_dictionary(entry, "option_overrides")
	var config_callback: Callable = _get_callable_value(entry.get("config_callback"))
	var options: Dictionary = route.build_options(params, option_overrides)
	var wrapped_callback: Callable = _make_route_config_callback(
		route,
		params,
		config_callback
	)
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	if _cancel_pending_route_if_lifecycle_expired(pending_key, request_id):
		return
	entry = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if entry.is_empty():
		return
	entry["panel_submitted"] = true
	_pending_async_routes[pending_key] = entry
	_disconnect_entry_lifecycle(entry)
	_pending_async_routes[pending_key] = entry
	var completion_invocation: GFWeakMethodInvocation = GFWeakMethodInvocation.new(
		self,
		&"_on_ui_panel_async_operation_completed"
	)
	var completion_callback: Callable = func(
		completed_ui_operation: GFUIPanelAsyncOperation
	) -> void:
		var _invocation_result: Dictionary = completion_invocation.invoke([
			completed_ui_operation,
			pending_key,
			request_id,
		])
	var ui_operation: GFUIPanelAsyncOperation = null
	if operation == Operation.REPLACE:
		ui_operation = ui_utility.replace_layer_async_with_options(
			route.scene_path,
			route_layer,
			options,
			wrapped_callback,
			completion_callback
		)
	else:
		ui_operation = ui_utility.push_panel_async_with_options(
			route.scene_path,
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
	entry = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if entry.is_empty():
		return
	var latched_ui_operation: GFUIPanelAsyncOperation = _get_ui_panel_async_operation_value(
		entry.get("ui_operation")
	)
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
	entry["ui_operation"] = ui_operation
	entry["ui_completion_callback"] = completion_callback
	_pending_async_routes[pending_key] = entry
	if ui_operation.is_completed():
		_on_ui_panel_async_operation_completed(ui_operation, pending_key, request_id)


func _ui_has_matching_pending_request(
	ui_utility: GFUIUtility,
	path: String,
	layer: int,
	operation: Operation
) -> bool:
	var operation_name: StringName = _operation_to_name(operation)
	for request: Dictionary in ui_utility.get_pending_async_panel_requests(layer):
		if (
			GFVariantData.get_option_string(request, "path", "") == path
			and GFVariantData.get_option_string_name(request, "operation", &"") == operation_name
		):
			return true
	return false


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
	var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
	if entry.is_empty():
		return
	var _erased: bool = _pending_async_routes.erase(pending_key)
	_finish_route_entry(entry, status, reason, panel, emit_legacy_failure)


func _complete_pending_route_opened(
	pending_key: String,
	request_id: int,
	route: GFUIRoute,
	route_operation: Operation,
	panel: Node
) -> void:
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	var entry: Dictionary = GFVariantData.get_option_dictionary(
		_pending_async_routes,
		pending_key
	)
	if entry.is_empty():
		return
	var _erased: bool = _pending_async_routes.erase(pending_key)
	if route_operation == Operation.REPLACE:
		_remove_history_for_layer(route.layer)
	_record_route_open(
		route,
		panel,
		GFVariantData.get_option_dictionary(entry, "params"),
		route_operation
	)
	_finish_route_entry(
		entry,
		GFUIRouteResult.STATUS_OPENED,
		&"",
		panel,
		false
	)


func _finish_route_entry(
	entry: Dictionary,
	status: StringName,
	reason: StringName,
	panel: Node,
	emit_legacy_failure: bool
) -> void:
	_disconnect_entry_lifecycle(entry)
	_disconnect_entry_ui_completion_callback(entry)
	var operation_handle: GFUIRouteOperation = _get_route_operation_value(entry.get("operation_handle"))
	if operation_handle == null or operation_handle.is_completed():
		return
	_disconnect_entry_preload_callback(entry)
	var preload_result: GFAssetLoadSessionResult = _get_entry_preload_result(entry)
	var preload_attempted: bool = GFVariantData.get_option_bool(entry, "preload_attempted")
	var preload_successful: bool = (
		preload_attempted
		and preload_result != null
		and preload_result.is_successful()
	)
	var final_reason: StringName = reason
	if status == GFUIRouteResult.STATUS_OPENED and final_reason == &"":
		final_reason = GFVariantData.get_option_string_name(
			entry,
			"preload_degradation_reason",
			&""
		)
	var result: GFUIRouteResult = GFUIRouteResult.new()
	var configured: bool = result.configure_for_framework(
		operation_handle.get_request_id(),
		operation_handle.get_route_id(),
		operation_handle.get_operation(),
		status,
		final_reason,
		GFVariantData.get_option_int(entry, "layer", -1),
		panel,
		operation_handle.get_preload_policy(),
		preload_attempted,
		preload_successful,
		GFVariantData.get_option_dictionary(entry, "preload_plan_report"),
		preload_result,
		operation_handle.get_started_at_msec(),
		Time.get_ticks_msec(),
		GFVariantData.get_option_dictionary(entry, "metadata")
	)
	if not configured:
		push_error("[GFUIRouterUtility] 无法构建异步路由终态结果。")
		return
	_release_owned_preload_group(entry, preload_result)
	var completed: bool = operation_handle.complete_for_framework(result)
	if not completed:
		return
	route_operation_completed.emit(result.duplicate_result())
	if emit_legacy_failure:
		_fail_route(operation_handle.get_route_id(), String(final_reason))


func _finish_pending_routes_for_dispose() -> void:
	var pending_entries: Array[Dictionary] = []
	for pending_key: Variant in _pending_async_routes.keys():
		var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
		if not entry.is_empty():
			pending_entries.append(entry)
	_pending_async_routes.clear()
	for entry: Dictionary in pending_entries:
		_disconnect_entry_lifecycle(entry)
		_disconnect_entry_preload_callback(entry)
		var panel_submitted: bool = GFVariantData.get_option_bool(entry, "panel_submitted")
		var session: GFAssetLoadSession = _get_asset_load_session_value(entry.get("preload_session"))
		if not panel_submitted and session != null and not session.is_completed():
			var _rolled_back: bool = session.rollback(&"router_disposed")
		_finish_route_entry(
			entry,
			GFUIRouteResult.STATUS_OUTCOME_UNKNOWN if panel_submitted else GFUIRouteResult.STATUS_DISPOSED,
			&"router_disposed_after_panel_submit" if panel_submitted else &"router_disposed_before_panel_submit",
			null,
			false
		)


func _disconnect_entry_preload_callback(entry: Dictionary) -> void:
	var session: GFAssetLoadSession = _get_asset_load_session_value(entry.get("preload_session"))
	var callback: Callable = _get_callable_value(entry.get("preload_callback"))
	if session != null and callback.is_valid() and session.completed.is_connected(callback):
		session.completed.disconnect(callback)


func _disconnect_entry_lifecycle(entry: Dictionary) -> void:
	var owner_lifetime: GFLifetimeSubscription = _get_lifetime_subscription_value(
		entry.get("owner_lifetime")
	)
	if owner_lifetime != null and owner_lifetime.is_active():
		var _cancelled_subscription: bool = owner_lifetime.cancel()
	var scope: GFAsyncScope = _get_async_scope_value(entry.get("scope"))
	var scope_callback: Callable = _get_callable_value(entry.get("scope_callback"))
	if scope != null and scope_callback.is_valid() and scope.cancel_requested.is_connected(scope_callback):
		scope.cancel_requested.disconnect(scope_callback)
	entry["owner_lifetime"] = null
	entry["scope"] = null
	entry["scope_callback"] = Callable()


func _disconnect_entry_ui_completion_callback(entry: Dictionary) -> void:
	var ui_operation: GFUIPanelAsyncOperation = _get_ui_panel_async_operation_value(
		entry.get("ui_operation")
	)
	var completion_callback: Callable = _get_callable_value(
		entry.get("ui_completion_callback")
	)
	if (
		ui_operation != null
		and completion_callback.is_valid()
		and ui_operation.completed.is_connected(completion_callback)
	):
		ui_operation.completed.disconnect(completion_callback)
	entry["ui_operation"] = null
	entry["ui_completion_callback"] = Callable()


func _release_owned_preload_group(
	entry: Dictionary,
	preload_result: GFAssetLoadSessionResult
) -> void:
	if (
		not GFVariantData.get_option_bool(entry, "owns_preload_group")
		or preload_result == null
		or not preload_result.is_successful()
	):
		return
	var asset_utility: GFAssetUtility = _get_asset_utility()
	if asset_utility != null:
		asset_utility.unload_group(preload_result.get_group_id(), false)


func _get_entry_preload_result(entry: Dictionary) -> GFAssetLoadSessionResult:
	var result: GFAssetLoadSessionResult = _get_asset_load_session_result_value(
		entry.get("preload_result")
	)
	if result != null:
		return result
	var session: GFAssetLoadSession = _get_asset_load_session_value(entry.get("preload_session"))
	return session.get_result() if session != null and session.is_completed() else null


func _make_json_safe_preload_plan_report(
	raw_report: Dictionary,
	asset_plan: GFAssetPreloadPlan
) -> Dictionary:
	var report: Dictionary = raw_report.duplicate(true)
	var _erased_asset_plan: bool = report.erase("asset_plan")
	if asset_plan != null:
		report["asset_plan_description"] = asset_plan.describe()
	return GFReportValueCodec.to_report_dictionary(report)


func _get_pending_route_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for pending_key: Variant in _pending_async_routes.keys():
		var entry: Dictionary = GFVariantData.get_option_dictionary(_pending_async_routes, pending_key)
		var operation_handle: GFUIRouteOperation = _get_route_operation_value(
			entry.get("operation_handle")
		)
		if operation_handle != null:
			var snapshot: Dictionary = operation_handle.get_debug_snapshot()
			snapshot["panel_submitted"] = GFVariantData.get_option_bool(entry, "panel_submitted")
			snapshot["has_owner"] = GFVariantData.get_option_int(entry, "owner_id") != 0
			snapshot["has_scope"] = GFVariantData.get_option_int(entry, "scope_id") != 0
			snapshot["lifecycle_cancellation_open"] = not GFVariantData.get_option_bool(
				entry,
				"panel_submitted"
			)
			snapshots.append(snapshot)
	snapshots.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return GFVariantData.get_option_int(left, "request_id") < GFVariantData.get_option_int(right, "request_id")
	)
	return snapshots


func _make_pending_async_route_key(path: String, layer: int, operation: Operation) -> String:
	return "%d:%d:%s" % [layer, int(operation), path]


func _find_pending_async_route(path: String, layer: int, operation: Operation) -> Dictionary:
	var key: String = _make_pending_async_route_key(path, layer, operation)
	return GFVariantData.get_option_dictionary(_pending_async_routes, key)


func _operation_to_name(operation: Operation) -> StringName:
	return (
		GFUIRouteOperation.OPERATION_REPLACE
		if operation == Operation.REPLACE
		else GFUIRouteOperation.OPERATION_PUSH
	)


func _get_route_operation(entry: Dictionary) -> Operation:
	if GFVariantData.get_option_int(entry, "operation", int(Operation.PUSH)) == int(Operation.REPLACE):
		return Operation.REPLACE
	return Operation.PUSH


func _make_route_config_callback(
	route: GFUIRoute,
	params: Dictionary,
	config_callback: Callable
) -> Callable:
	return func(panel: Node) -> void:
		_apply_route_params(panel, route, params)
		if config_callback.is_valid():
			config_callback.call(panel)


func _apply_route_params(panel: Node, route: GFUIRoute, params: Dictionary) -> void:
	if not is_instance_valid(panel):
		return
	if panel.has_method("set_route_params"):
		panel.call("set_route_params", params.duplicate(true))
	if panel.has_method("set_route_metadata"):
		panel.call("set_route_metadata", route.metadata.duplicate(true))


func _record_route_open(
	route: GFUIRoute,
	panel: Node,
	params: Dictionary,
	operation: Operation
) -> void:
	if max_history <= 0:
		route_opened.emit(route.get_route_id(), panel, operation)
		return

	_prune_history()
	_history.append({
		"route_id": route.get_route_id(),
		"layer": route.layer,
		"panel_ref": weakref(panel),
		"params": params.duplicate(true),
		"metadata": route.metadata.duplicate(true),
	})
	while _history.size() > max_history:
		_history.remove_at(0)
	route_opened.emit(route.get_route_id(), panel, operation)


func _prune_history() -> void:
	var ui_utility: GFUIUtility = _get_ui_utility()
	for index: int in range(_history.size() - 1, -1, -1):
		var entry: Dictionary = _history[index]
		var panel: Node = _get_history_panel(entry)
		var layer: int = GFVariantData.get_option_int(entry, "layer", GFUIUtility.Layer.POPUP)
		if panel == null or (ui_utility != null and not ui_utility.is_panel_open(panel, layer)):
			_history.remove_at(index)


func _find_top_history_index(layer: int = -1) -> int:
	for index: int in range(_history.size() - 1, -1, -1):
		if layer < 0 or GFVariantData.get_option_int(_history[index], "layer", -1) == layer:
			return index
	return -1


func _remove_history_for_layer(layer: int) -> void:
	for index: int in range(_history.size() - 1, -1, -1):
		if GFVariantData.get_option_int(_history[index], "layer", -1) == layer:
			_history.remove_at(index)


func _get_history_panel(entry: Dictionary) -> Node:
	var panel_ref: WeakRef = _get_weak_ref_value(GFVariantData.get_option_value(entry, "panel_ref"))
	if panel_ref == null:
		return null
	return _INSTANCE_GUARD._get_live_node_from_ref(panel_ref)


func _make_public_history_entry(entry: Dictionary) -> Dictionary:
	return {
		"route_id": GFVariantData.get_option_string_name(entry, "route_id", &""),
		"layer": GFVariantData.get_option_int(entry, "layer", GFUIUtility.Layer.POPUP),
		"panel": _get_history_panel(entry),
		"params": GFVariantData.get_option_dictionary(entry, "params"),
		"metadata": GFVariantData.get_option_dictionary(entry, "metadata"),
	}


func _get_ui_utility() -> GFUIUtility:
	if _ui_utility_ref != null:
		var ui_utility: GFUIUtility = _get_ui_utility_value(_ui_utility_ref.get_ref())
		if ui_utility != null:
			return ui_utility

	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	return _get_ui_utility_value(architecture.get_utility(GFUIUtility))


func _get_asset_utility() -> GFAssetUtility:
	var architecture: GFArchitecture = _get_architecture_or_null()
	if architecture == null:
		return null
	var value: Variant = architecture.get_utility(GFAssetUtility)
	if value is GFAssetUtility:
		var asset_utility: GFAssetUtility = value
		return asset_utility
	return null


func _get_route_value(value: Variant) -> GFUIRoute:
	if value is GFUIRoute:
		var route: GFUIRoute = value
		return route
	return null


func _normalize_route_id(route_id: StringName) -> StringName:
	return StringName(String(route_id).strip_edges())


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


func _get_ui_utility_value(value: Variant) -> GFUIUtility:
	if value is GFUIUtility:
		var ui_utility: GFUIUtility = value
		return ui_utility
	return null


func _get_route_operation_value(value: Variant) -> GFUIRouteOperation:
	if value is GFUIRouteOperation:
		var operation_handle: GFUIRouteOperation = value
		return operation_handle
	return null


func _get_ui_panel_async_operation_value(value: Variant) -> GFUIPanelAsyncOperation:
	if value is GFUIPanelAsyncOperation:
		var operation_handle: GFUIPanelAsyncOperation = value
		return operation_handle
	return null


func _get_asset_preload_plan_value(value: Variant) -> GFAssetPreloadPlan:
	if value is GFAssetPreloadPlan:
		var asset_plan: GFAssetPreloadPlan = value
		return asset_plan
	return null


func _get_asset_load_session_value(value: Variant) -> GFAssetLoadSession:
	if value is GFAssetLoadSession:
		var session: GFAssetLoadSession = value
		return session
	return null


func _get_asset_load_session_result_value(value: Variant) -> GFAssetLoadSessionResult:
	if value is GFAssetLoadSessionResult:
		var result: GFAssetLoadSessionResult = value
		return result
	return null


func _get_callable_value(value: Variant) -> Callable:
	if value is Callable:
		var callback: Callable = value
		return callback
	return Callable()


func _get_object_value(value: Variant) -> Object:
	if value is Object:
		var object_value: Object = value
		if is_instance_valid(object_value):
			return object_value
	return null


func _get_live_object_from_ref(object_ref: WeakRef) -> Object:
	if object_ref == null:
		return null
	return _get_object_value(object_ref.get_ref())


func _get_async_scope_value(value: Variant) -> GFAsyncScope:
	if value is GFAsyncScope:
		var scope: GFAsyncScope = value
		return scope
	return null


func _get_lifetime_subscription_value(value: Variant) -> GFLifetimeSubscription:
	if value is GFLifetimeSubscription:
		var subscription: GFLifetimeSubscription = value
		return subscription
	return null


func _get_weak_ref_value(value: Variant) -> WeakRef:
	if value is WeakRef:
		var object_ref: WeakRef = value
		return object_ref
	return null


func _get_ui_layer(value: Variant, fallback: int = GFUIUtility.DEFAULT_LAYER_ID) -> int:
	var layer_value: int = GFVariantData.to_int(value, fallback)
	return layer_value if layer_value >= 0 else fallback


# --- 信号处理函数 ---

func _on_ui_panel_async_operation_completed(
	ui_operation: GFUIPanelAsyncOperation,
	pending_key: String,
	request_id: int
) -> void:
	if ui_operation == null or not ui_operation.is_completed():
		return
	if not _pending_route_has_request_id(pending_key, request_id):
		return
	var route_entry: Dictionary = GFVariantData.get_option_dictionary(
		_pending_async_routes,
		pending_key
	)
	if route_entry.is_empty() or not GFVariantData.get_option_bool(route_entry, "panel_submitted"):
		return
	var latched_ui_operation: GFUIPanelAsyncOperation = _get_ui_panel_async_operation_value(
		route_entry.get("ui_operation")
	)
	if latched_ui_operation != null and latched_ui_operation != ui_operation:
		return
	var route: GFUIRoute = _get_route_value(route_entry.get("route"))
	var route_operation: Operation = _get_route_operation(route_entry)
	if (
		route == null
		or ui_operation.get_path() != route.scene_path
		or ui_operation.get_layer() != _get_ui_layer(route.layer)
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
		route_entry["ui_operation"] = ui_operation
		_pending_async_routes[pending_key] = route_entry
	var status: int = ui_operation.get_status()
	var panel: Node = ui_operation.get_panel()
	if status == GFUIUtility.AsyncPanelLoadStatus.OPENED and is_instance_valid(panel):
		_complete_pending_route_opened(
			pending_key,
			request_id,
			route,
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
