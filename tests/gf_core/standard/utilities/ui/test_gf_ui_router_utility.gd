## 测试 GFUIRouterUtility 的路由注册、打开、替换与返回行为。
extends GutTest


# --- 常量 ---

const _PANEL_SCENE_PATH: String = "res://tests/gf_core/fixtures/scene_signal_audit_valid.tscn"


# --- 私有变量 ---

var _ui_utility: GFUIUtility
var _router: GFUIRouterUtility
var _arch: GFArchitecture = null


# --- 辅助类型 ---

class ManualAssetUtility extends GFAssetUtility:
	var _callbacks: Dictionary = {}

	func load_async(path: String, on_loaded: Callable, _type_hint: String = "", _options: Dictionary = {}) -> void:
		if not _callbacks.has(path):
			var created_callbacks: Array[Callable] = []
			_callbacks[path] = created_callbacks
		var list: Array = _callback_list(path)
		list.append(on_loaded)

	func resolve(path: String, resource: Resource) -> void:
		if not _callbacks.has(path):
			return

		var callbacks: Array = _callback_list(path)
		var _erase_result_34: Variant = _callbacks.erase(path)
		for callback: Callable in callbacks:
			callback.call(resource)

	func get_pending_count(path: String) -> int:
		return _callback_list(path).size() if _callbacks.has(path) else 0

	func dispose() -> void:
		_callbacks.clear()
		super.dispose()

	func _callback_list(path: String) -> Array:
		var callbacks_value: Variant = _callbacks[path]
		if callbacks_value is Array:
			var callbacks: Array = callbacks_value
			return callbacks
		return []


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_ui_utility = GFUIUtility.new()
	_ui_utility.init()
	_router = GFUIRouterUtility.new()
	_router.init()
	_router.set_ui_utility(_ui_utility)
	await get_tree().process_frame


func after_each() -> void:
	if _router != null:
		_router.dispose()
		_router = null
	if _ui_utility != null:
		_ui_utility.dispose()
		_ui_utility = null
	if _arch != null:
		_arch.dispose()
		_arch = null
	Gf._architecture = null
	await get_tree().process_frame


# --- 测试方法 ---

func test_push_route_records_history_and_options_metadata() -> void:
	var route: GFUIRoute = _make_route(&"settings", GFUIUtility.Layer.POPUP)
	route.metadata = { "section": "options" }
	assert_true(_router.register_route(route), "有效路由应可注册。")

	var panel: Node = _router.push_route(&"settings", { "tab": "audio" })
	var options: Dictionary = _ui_utility.get_panel_options(panel)
	var metadata: Dictionary = GFVariantData.as_dictionary(options["metadata"])
	var route_params: Dictionary = GFVariantData.as_dictionary(metadata["route_params"])

	assert_not_null(panel, "push_route 应返回打开的面板。")
	assert_eq(_router.get_current_route_id(), &"settings", "当前路由应写入历史。")
	assert_eq(GFVariantData.get_option_string_name(metadata, "route_id"), &"settings", "面板选项应包含 route_id 元数据。")
	assert_eq(GFVariantData.get_option_string(route_params, "tab"), "audio", "面板选项应包含路由参数。")
	assert_eq(GFVariantData.get_option_string(metadata, "section"), "options", "路由元数据应被透传。")


func test_route_open_signals_use_canonical_route_id() -> void:
	var route: GFUIRoute = _make_route(&" settings ", GFUIUtility.Layer.POPUP)
	assert_true(_router.register_route(route), "带首尾空白的声明应按规范化 ID 注册。")
	watch_signals(_router)

	var panel: Node = _router.push_route(&" settings ")

	assert_not_null(panel, "规范化后的路由应可打开。")
	assert_signal_emitted_with_parameters(
		_router,
		"route_open_requested",
		[&"settings", GFUIRouterUtility.Operation.PUSH, {}]
	)
	assert_signal_emitted_with_parameters(
		_router,
		"route_opened",
		[&"settings", panel, GFUIRouterUtility.Operation.PUSH]
	)


func test_route_supports_registered_custom_layer_id() -> void:
	var definition: GFUILayerDefinition = GFUILayerDefinition.new()
	definition.layer_id = 100
	definition.display_name = &"RIGHT_PANE"
	definition.canvas_layer = 60
	definition.auto_hide_under = false
	assert_true(_ui_utility.register_layer(definition), "测试自定义层应注册成功。")
	var route: GFUIRoute = _make_route(&"inventory", 100)

	assert_true(_router.register_route(route), "非负自定义层 ID 的路由应可注册。")
	var panel: Node = _router.push_route(&"inventory")

	assert_not_null(panel, "自定义层路由应可打开。")
	assert_eq(panel.get_parent(), _ui_utility.get_layer_root(100), "路由面板应进入自定义逻辑层。")
	assert_eq(_router.get_current_route_id(100), &"inventory", "自定义层应维护独立路由历史。")


func test_route_rejects_unregistered_custom_layer_with_stable_reason() -> void:
	var route: GFUIRoute = _make_route(&"inventory", 101)
	assert_true(_router.register_route(route), "非负逻辑层 ID 的路由资源本身应有效。")
	watch_signals(_router)

	var panel: Node = _router.push_route(&"inventory")

	assert_null(panel, "未注册逻辑层不应退化为泛化面板打开失败。")
	assert_signal_emitted_with_parameters(_router, "route_open_failed", [&"inventory", "missing_ui_layer"])
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：inventory (missing_ui_layer)")


func test_route_build_options_deep_merges_metadata_and_copies_params() -> void:
	var route: GFUIRoute = _make_route(&"profile", GFUIUtility.Layer.POPUP)
	route.default_options = {
		"metadata": {
			"defaults": {
				"tab": "overview",
			},
		},
	}
	route.metadata = {
		"section": "profile",
	}
	var params: Dictionary = {
		"user_id": 42,
	}

	var options: Dictionary = route.build_options(params, {
		"metadata": {
			"defaults": {
				"mode": "compact",
			},
		},
	})
	var options_metadata: Dictionary = GFVariantData.as_dictionary(options["metadata"])
	var route_params: Dictionary = GFVariantData.as_dictionary(options_metadata["route_params"])
	var defaults: Dictionary = GFVariantData.as_dictionary(options_metadata["defaults"])
	route_params["user_id"] = 100

	assert_eq(GFVariantData.get_option_string_name(options_metadata, "route_id"), &"profile", "路由选项应写入 route_id。")
	assert_eq(GFVariantData.get_option_string(options_metadata, "section"), "profile", "路由自身 metadata 应保留。")
	assert_eq(GFVariantData.get_option_string(defaults, "tab"), "overview", "默认 metadata 嵌套字段应保留。")
	assert_eq(GFVariantData.get_option_string(defaults, "mode"), "compact", "覆盖 metadata 嵌套字段应合并。")
	assert_eq(GFVariantData.get_option_int(params, "user_id"), 42, "路由参数应复制保存。")


func test_back_pops_current_route() -> void:
	var _register_route_result_126: Variant = _router.register_route(_make_route(&"inventory", GFUIUtility.Layer.POPUP))
	var _push_route_result_127: Variant = _router.push_route(&"inventory")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1, "打开路由后层级应有面板。")

	var handled: bool = _router.back()

	assert_true(handled, "存在历史时 back 应成功。")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 0, "back 应弹出当前面板。")
	assert_eq(_router.get_current_route_id(), &"", "弹出后当前路由应为空。")


func test_back_refuses_to_pop_non_route_panel_above_route() -> void:
	var _register_route_result_138: Variant = _router.register_route(_make_route(&"inventory", GFUIUtility.Layer.POPUP))
	var route_panel: Node = _router.push_route(&"inventory")
	var overlay_panel: Control = Control.new()
	_ui_utility.push_panel_instance(overlay_panel, GFUIUtility.Layer.POPUP)

	var handled: bool = _router.back()

	assert_false(handled, "普通面板压在路由面板上方时，router.back 不应误弹普通面板。")
	assert_eq(_ui_utility.get_top_panel(GFUIUtility.Layer.POPUP), overlay_panel, "router.back 失败后栈顶普通面板应保留。")
	assert_eq(_router.get_current_route_id(), &"inventory", "router.back 失败后路由历史不应被删除。")
	assert_true(_ui_utility.is_panel_open(route_panel, GFUIUtility.Layer.POPUP), "原路由面板仍应保持打开。")
	assert_push_warning("[GFUIRouterUtility] back 失败：路由面板不是当前 UI 栈顶。")


func test_replace_route_clears_same_layer_history() -> void:
	var _register_route_result_153: Variant = _router.register_route(_make_route(&"first", GFUIUtility.Layer.POPUP))
	var _register_route_result_154: Variant = _router.register_route(_make_route(&"second", GFUIUtility.Layer.POPUP))
	var _push_route_result_155: Variant = _router.push_route(&"first")
	var _replace_route_result_156: Variant = _router.replace_route(&"second")

	var history: Array[Dictionary] = _router.get_route_history()
	var history_entry: Dictionary = history[0]

	assert_eq(history.size(), 1, "替换层级后同层历史应只保留新路由。")
	assert_eq(GFVariantData.get_option_string_name(history_entry, "route_id"), &"second", "替换后历史应指向新路由。")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1, "替换层级后 UI 栈应只保留一个面板。")


func test_missing_route_emits_failure() -> void:
	watch_signals(_router)

	var panel: Node = _router.push_route(&"missing")

	assert_null(panel, "缺失路由不应打开面板。")
	assert_signal_emitted(_router, "route_open_failed", "缺失路由应发出失败信号。")
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：missing (missing_route)")


func test_duplicate_pending_push_route_async_opens_once() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&" inventory ", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/pending_route_panel.tscn"
	var _register_route_result_182: Variant = _router.register_route(route)

	watch_signals(_router)
	var first_operation: GFUIRouteOperation = _router.push_route_async(&" inventory ")
	var second_operation: GFUIRouteOperation = _router.push_route_async(&"inventory")
	assert_eq(second_operation, first_operation, "相同异步路由请求应返回同一个可观察句柄。")
	asset_util.resolve("res://tests/pending_route_panel.tscn", _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1, "重复异步打开同一路由时 UI 栈只应出现一个面板。")
	assert_eq(_router.get_route_history().size(), 1, "重复异步打开同一路由时历史只应记录一次。")
	assert_signal_emit_count(_router, "route_open_requested", 1, "规范化后相同的异步路由只应发出一次请求。")
	assert_true(first_operation.is_completed(), "合流句柄应观察到唯一终态。")
	assert_eq(first_operation.get_result().get_status(), GFUIRouteResult.STATUS_OPENED)
	assert_signal_emit_count(_router, "route_operation_completed", 1, "合流请求只能产生一个类型化终态。")


func test_async_route_sync_fallback_reaches_terminal_state() -> void:
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	assert_true(_router.register_route(route), "有效路由应可注册。")

	var operation: GFUIRouteOperation = _router.push_route_async(&"inventory")
	assert_push_warning("[GFUIUtility] GFAssetUtility 未注册，回退为同步加载。")
	await get_tree().process_frame

	var snapshot: Dictionary = _router.get_debug_snapshot()
	assert_eq(
		GFVariantData.get_option_int(snapshot, "pending_async_route_count", -1),
		0,
		"缺少 GFAssetUtility 时的同步回退也必须结束异步路由生命周期。"
	)
	assert_eq(_router.get_current_route_id(), &"inventory", "同步回退打开的路由仍应进入历史。")
	assert_true(operation.is_completed(), "同步回退也必须完成返回句柄。")
	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_OPENED)


func test_legacy_ui_telemetry_reentry_cannot_complete_replacement_route() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/ui_telemetry_reentry_route_panel.tscn"
	assert_true(_router.register_route(route))
	_router.set_ui_utility(null)
	var replacement_operations: Array[GFUIRouteOperation] = []
	var reentry_state: Dictionary = { "started": false }
	var telemetry_callback: Callable = func(
		_path: String,
		_layer: int,
		_operation: StringName,
		_status: int,
		_panel: Node
	) -> void:
		if GFVariantData.get_option_bool(reentry_state, "started"):
			return
		reentry_state["started"] = true
		replacement_operations.append(_router.push_route_async(&"inventory"))
	var _connected: Error = _ui_utility.panel_async_load_finished.connect(
		telemetry_callback
	) as Error
	_router.set_ui_utility(_ui_utility)

	var first_operation: GFUIRouteOperation = _router.push_route_async(&"inventory")
	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame

	assert_eq(first_operation.get_result().get_status(), GFUIRouteResult.STATUS_OPENED)
	assert_eq(replacement_operations.size(), 1, "旧请求 telemetry 的重入只应创建一个替代请求。")
	var replacement_operation: GFUIRouteOperation = replacement_operations[0]
	assert_true(replacement_operation.is_pending(), "旧请求 telemetry 不得终结同键替代请求。")
	assert_eq(asset_util.get_pending_count(route.scene_path), 1, "替代请求应保留自己的底层加载。")
	assert_eq(_router.get_route_history().size(), 1, "替代请求完成前只记录首个路由。")

	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(replacement_operation.get_result().get_status(), GFUIRouteResult.STATUS_OPENED)
	assert_eq(_router.get_route_history().size(), 2, "替代请求应按自己的句柄终态独立记录。")
	if _ui_utility.panel_async_load_finished.is_connected(telemetry_callback):
		_ui_utility.panel_async_load_finished.disconnect(telemetry_callback)


func test_route_opened_reentry_creates_distinct_same_key_request() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/route_opened_reentry_panel.tscn"
	assert_true(_router.register_route(route))
	var replacement_operations: Array[GFUIRouteOperation] = []
	var reentry_state: Dictionary = { "started": false }
	var opened_callback: Callable = func(
		_route_id: StringName,
		_panel: Node,
		_operation: GFUIRouterUtility.Operation
	) -> void:
		if GFVariantData.get_option_bool(reentry_state, "started"):
			return
		reentry_state["started"] = true
		replacement_operations.append(_router.push_route_async(&"inventory"))
	var _connected: Error = _router.route_opened.connect(opened_callback) as Error

	var first_operation: GFUIRouteOperation = _router.push_route_async(&"inventory")
	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame

	assert_eq(first_operation.get_result().get_status(), GFUIRouteResult.STATUS_OPENED)
	assert_eq(replacement_operations.size(), 1)
	var replacement_operation: GFUIRouteOperation = replacement_operations[0]
	assert_ne(replacement_operation, first_operation, "route_opened 重入不得合流到正在完成的旧句柄。")
	assert_true(replacement_operation.is_pending(), "重入创建的新请求必须保留自己的终态。")
	assert_eq(asset_util.get_pending_count(route.scene_path), 1)

	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(replacement_operation.get_result().get_status(), GFUIRouteResult.STATUS_OPENED)
	assert_eq(_router.get_route_history().size(), 2)
	if _router.route_opened.is_connected(opened_callback):
		_router.route_opened.disconnect(opened_callback)


func test_conflicting_pending_async_routes_fail_instead_of_silently_overwriting() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var first_route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	first_route.scene_path = "res://tests/shared_pending_route_panel.tscn"
	var second_route: GFUIRoute = _make_route(&"settings", GFUIUtility.Layer.POPUP)
	second_route.scene_path = "res://tests/shared_pending_route_panel.tscn"
	var _register_first_result: Variant = _router.register_route(first_route)
	var _register_second_result: Variant = _router.register_route(second_route)
	watch_signals(_router)

	var inventory_operation: GFUIRouteOperation = _router.push_route_async(&"inventory")
	var settings_operation: GFUIRouteOperation = _router.push_route_async(&"settings")
	asset_util.resolve("res://tests/shared_pending_route_panel.tscn", _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1, "冲突路由只能打开第一个请求对应的面板。")
	assert_eq(_router.get_current_route_id(), &"inventory", "冲突失败后历史应保留第一个路由。")
	assert_signal_emitted_with_parameters(_router, "route_open_failed", [&"settings", "route_async_conflict"])
	assert_eq(inventory_operation.get_result().get_status(), GFUIRouteResult.STATUS_OPENED)
	assert_eq(settings_operation.get_result().get_status(), GFUIRouteResult.STATUS_ASYNC_CONFLICT)
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：settings (route_async_conflict)")


func test_router_rejects_matching_external_ui_async_request() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/external_pending_route_panel.tscn"
	assert_true(_router.register_route(route))
	var _external_operation: GFUIPanelAsyncOperation = _ui_utility.push_panel_async(
		route.scene_path,
		route.layer
	)
	watch_signals(_router)

	var operation: GFUIRouteOperation = _router.push_route_async(&"inventory")

	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_ASYNC_CONFLICT)
	assert_eq(operation.get_result().get_reason(), &"ui_async_request_conflict")
	assert_eq(_router.get_current_route_id(), &"", "Router 不得把外部 UI 请求误记为自己的路由。")
	assert_signal_emitted_with_parameters(
		_router,
		"route_open_failed",
		[&"inventory", "ui_async_request_conflict"]
	)
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：inventory (ui_async_request_conflict)")
	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame
	assert_eq(_router.get_current_route_id(), &"", "外部请求完成后也不得污染 Router 历史。")


func test_async_replace_failure_preserves_existing_route_history() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var _register_first_result: bool = _router.register_route(_make_route(&"first", GFUIUtility.Layer.POPUP))
	var second_route: GFUIRoute = _make_route(&"second", GFUIUtility.Layer.POPUP)
	second_route.scene_path = "res://tests/missing_async_replace_panel.tscn"
	var _register_second_result: bool = _router.register_route(second_route)
	var first_panel: Node = _router.push_route(&"first")
	watch_signals(_router)

	var operation: GFUIRouteOperation = _router.replace_route_async(&"second")
	asset_util.resolve("res://tests/missing_async_replace_panel.tscn", null)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：second (panel_async_failed)")

	assert_eq(_router.get_current_route_id(), &"first", "异步 replace 失败后应保留旧路由历史。")
	assert_true(_ui_utility.is_panel_open(first_panel, GFUIUtility.Layer.POPUP), "异步 replace 失败后旧面板应仍在 UI 栈中。")
	assert_signal_emitted(_router, "route_open_failed", "异步 replace 失败应发出路由失败信号。")
	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_PANEL_FAILED)
	assert_push_error("[GFUIUtility] 无法实例化面板场景：res://tests/missing_async_replace_panel.tscn")


func test_async_missing_route_returns_completed_typed_failure() -> void:
	watch_signals(_router)

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"missing",
		{},
		{},
		Callable(),
		{
			"metadata": {
				"non_finite": NAN,
				"runtime_object": _router,
			},
		}
	)
	var result: GFUIRouteResult = operation.get_result()
	var report: Dictionary = result.to_dict()
	var metadata_copy: Dictionary = result.get_metadata()
	metadata_copy["changed"] = true

	assert_true(operation.is_completed())
	assert_not_null(result)
	assert_eq(result.get_request_id(), operation.get_request_id())
	assert_eq(result.get_route_id(), &"missing")
	assert_eq(result.get_status(), GFUIRouteResult.STATUS_MISSING_ROUTE)
	assert_false(result.is_successful())
	assert_false(result.get_metadata().has("changed"), "结果元数据读取必须返回隔离副本。")
	assert_false(JSON.stringify(report).is_empty(), "类型化结果报告必须可安全 JSON 序列化。")
	assert_signal_emitted_with_parameters(_router, "route_open_failed", [&"missing", "missing_route"])
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：missing (missing_route)")


func test_invalid_async_preload_policy_returns_typed_failure() -> void:
	assert_true(_router.register_route(_make_route(&"inventory", GFUIUtility.Layer.POPUP)))
	watch_signals(_router)

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{ "preload_policy": &"unknown" }
	)

	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_INVALID_PRELOAD_POLICY)
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 0)
	assert_signal_emitted_with_parameters(
		_router,
		"route_open_failed",
		[&"inventory", "invalid_preload_policy"]
	)
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：inventory (invalid_preload_policy)")


func test_async_route_returns_cancelled_for_pre_cancelled_scope() -> void:
	assert_true(_router.register_route(_make_route(&"inventory", GFUIUtility.Layer.POPUP)))
	var scope: GFAsyncScope = GFAsyncScope.new()
	var _cancelled: bool = scope.cancel("navigation_abandoned")
	watch_signals(_router)

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{ "scope": scope }
	)

	assert_true(operation.is_completed(), "已取消 scope 应立即返回终态。")
	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_CANCELLED)
	assert_eq(operation.get_result().get_reason(), &"navigation_abandoned")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 0)
	assert_signal_emit_count(_router, "route_open_requested", 0, "已取消 scope 不应进入路由提交流程。")
	assert_signal_emit_count(_router, "route_operation_completed", 1, "立即取消也只能产生一个终态。")


func test_async_route_rejects_completed_or_invalid_scope() -> void:
	assert_true(_router.register_route(_make_route(&"inventory", GFUIUtility.Layer.POPUP)))
	var completed_scope: GFAsyncScope = GFAsyncScope.new()
	completed_scope.complete()

	var completed_operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{ "scope": completed_scope }
	)
	assert_eq(
		completed_operation.get_result().get_status(),
		GFUIRouteResult.STATUS_INVALID_LIFECYCLE
	)
	assert_eq(completed_operation.get_result().get_reason(), &"scope_completed")
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：inventory (scope_completed)")

	var invalid_operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{ "scope": RefCounted.new() }
	)
	assert_eq(
		invalid_operation.get_result().get_status(),
		GFUIRouteResult.STATUS_INVALID_LIFECYCLE
	)
	assert_eq(invalid_operation.get_result().get_reason(), &"invalid_scope")
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：inventory (invalid_scope)")


func test_async_route_rejects_node_owner_outside_scene_tree() -> void:
	assert_true(_router.register_route(_make_route(&"inventory", GFUIUtility.Layer.POPUP)))
	var owner_node: Node = Node.new()

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{ "owner": owner_node }
	)

	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_INVALID_LIFECYCLE)
	assert_eq(operation.get_result().get_reason(), &"owner_not_in_tree")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 0)
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：inventory (owner_not_in_tree)")
	owner_node.free()


func test_owner_and_scope_use_or_cancellation_before_panel_submit() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/lifecycle_or_route_panel.tscn"
	assert_true(_router.register_route(route))
	var owner_node: Node = Node.new()
	add_child(owner_node)
	var scope: GFAsyncScope = GFAsyncScope.new()
	watch_signals(_router)

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{
			"owner": owner_node,
			"scope": scope,
			"preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED,
		}
	)
	assert_true(operation.is_pending())
	assert_eq(asset_util.get_pending_count(route.scene_path), 1, "请求应先停留在预加载阶段。")

	var _cancelled: bool = scope.cancel("route_scope_cancelled")
	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_CANCELLED)
	assert_eq(operation.get_result().get_reason(), &"route_scope_cancelled")
	owner_node.queue_free()
	await get_tree().process_frame
	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame

	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 0, "取消后的迟到预加载不得再提交面板。")
	assert_signal_emit_count(_router, "route_operation_completed", 1, "scope 与 owner 后续终止只能共享一个终态。")


func test_node_owner_tree_exit_cancels_before_panel_submit() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/node_owner_route_panel.tscn"
	assert_true(_router.register_route(route))
	var owner_node: Node = Node.new()
	add_child(owner_node)

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{
			"owner": owner_node,
			"preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED,
		}
	)
	owner_node.queue_free()
	await get_tree().process_frame

	assert_true(operation.is_completed())
	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_CANCELLED)
	assert_eq(operation.get_result().get_reason(), &"owner_tree_exited")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 0)


func test_ref_counted_owner_release_is_pruned_on_tick() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/ref_counted_owner_route_panel.tscn"
	assert_true(_router.register_route(route))
	var route_owner: RefCounted = RefCounted.new()
	var route_owner_ref: WeakRef = weakref(route_owner)

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{
			"owner": route_owner,
			"preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED,
		}
	)
	route_owner = null
	var owner_was_released: bool = route_owner_ref.get_ref() == null
	assert_true(owner_was_released, "Router 只应弱持有普通 Object owner。")
	_router.tick(0.0)

	assert_true(operation.is_completed())
	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_CANCELLED)
	assert_eq(operation.get_result().get_reason(), &"owner_released")
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 0)


func test_duplicate_pending_route_requires_same_lifecycle_identity() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/lifecycle_identity_route_panel.tscn"
	assert_true(_router.register_route(route))
	var route_owner: RefCounted = RefCounted.new()
	var other_owner: RefCounted = RefCounted.new()
	var scope: GFAsyncScope = GFAsyncScope.new()
	var async_options: Dictionary = {
		"owner": route_owner,
		"scope": scope,
		"preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED,
	}

	var first_operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		async_options
	)
	var duplicate_operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		async_options
	)
	var conflict_operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{
			"owner": other_owner,
			"scope": scope,
			"preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED,
		}
	)

	assert_eq(duplicate_operation, first_operation, "只有生命周期身份相同的请求才能合流。")
	assert_eq(conflict_operation.get_result().get_status(), GFUIRouteResult.STATUS_ASYNC_CONFLICT)
	assert_eq(conflict_operation.get_result().get_reason(), &"route_async_conflict")
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：inventory (route_async_conflict)")
	var _cancelled: bool = scope.cancel("test_cleanup")
	assert_eq(first_operation.get_result().get_status(), GFUIRouteResult.STATUS_CANCELLED)


func test_lifecycle_cancellation_is_ignored_after_panel_submit() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/submitted_lifecycle_route_panel.tscn"
	assert_true(_router.register_route(route))
	var owner_node: Node = Node.new()
	add_child(owner_node)
	var scope: GFAsyncScope = GFAsyncScope.new()
	watch_signals(_router)

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{
			"owner": owner_node,
			"scope": scope,
		}
	)
	assert_true(operation.is_pending(), "面板已提交但尚未加载时句柄应保持 pending。")
	assert_eq(asset_util.get_pending_count(route.scene_path), 1)
	var _cancelled: bool = scope.cancel("too_late")
	owner_node.queue_free()
	await get_tree().process_frame
	assert_true(operation.is_pending(), "面板提交后的 owner/scope 取消不得改写路由结果。")

	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_OPENED)
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1)
	assert_signal_emit_count(_router, "route_operation_completed", 1, "提交后取消不得制造第二终态。")


func test_route_open_requested_reentry_cannot_advance_replacement_request_twice() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/reentrant_route_identity_panel.tscn"
	assert_true(_router.register_route(route))
	var first_scope: GFAsyncScope = GFAsyncScope.new()
	var replacement_operations: Array[GFUIRouteOperation] = []
	var replacement_state: Dictionary = { "started": false }
	var callback: Callable
	callback = func(_route_id: StringName, _operation: GFUIRouterUtility.Operation, _params: Dictionary) -> void:
		if GFVariantData.get_option_bool(replacement_state, "started"):
			return
		replacement_state["started"] = true
		var _cancelled: bool = first_scope.cancel("route_replaced_during_signal")
		replacement_operations.append(_router.push_route_async(
			&"inventory",
			{},
			{},
			Callable(),
			{ "preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED }
		))
	var _connected: Error = _router.route_open_requested.connect(callback) as Error

	var first_operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{
			"scope": first_scope,
			"preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED,
		}
	)

	assert_eq(first_operation.get_result().get_status(), GFUIRouteResult.STATUS_CANCELLED)
	assert_eq(replacement_operations.size(), 1, "重入监听器只应创建一个替代请求。")
	assert_eq(asset_util.get_pending_count(route.scene_path), 1, "旧调用栈不得再次推进替代请求。")
	var replacement_operation: GFUIRouteOperation = replacement_operations[0]
	assert_true(replacement_operation.is_pending())

	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame
	assert_true(replacement_operation.is_pending(), "预加载完成后应等待独立的面板加载终态。")
	assert_eq(asset_util.get_pending_count(route.scene_path), 1, "面板提交只应创建一个后续加载。")
	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(replacement_operation.get_result().get_status(), GFUIRouteResult.STATUS_OPENED)
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1)
	if _router.route_open_requested.is_connected(callback):
		_router.route_open_requested.disconnect(callback)


func test_reinit_rejects_terminal_reentry_and_keeps_request_ids_monotonic() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/reinit_route_identity_panel.tscn"
	assert_true(_router.register_route(route))
	var reentrant_operations: Array[GFUIRouteOperation] = []
	var reentry_state: Dictionary = { "started": false }
	var completion_callback: Callable
	completion_callback = func(result: GFUIRouteResult) -> void:
		if GFVariantData.get_option_bool(reentry_state, "started") or result.get_route_id() != &"inventory":
			return
		reentry_state["started"] = true
		reentrant_operations.append(_router.push_route_async(&"inventory"))
	var _connected: Error = _router.route_operation_completed.connect(
		completion_callback
	) as Error
	var first_operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{ "preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED }
	)

	_router.init()

	assert_eq(first_operation.get_result().get_status(), GFUIRouteResult.STATUS_DISPOSED)
	assert_eq(reentrant_operations.size(), 1, "重置期间的重入请求必须同步收敛。")
	var rejected_operation: GFUIRouteOperation = reentrant_operations[0]
	assert_eq(rejected_operation.get_result().get_status(), GFUIRouteResult.STATUS_DISPOSED)
	assert_gt(
		rejected_operation.get_request_id(),
		first_operation.get_request_id(),
		"同一 Router 实例重置时 request_id 不得回退。"
	)

	_router.configure([route], _ui_utility)
	var next_scope: GFAsyncScope = GFAsyncScope.new()
	var _next_cancelled: bool = next_scope.cancel("request_id_probe")
	var next_operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{ "scope": next_scope }
	)
	assert_gt(
		next_operation.get_request_id(),
		rejected_operation.get_request_id(),
		"重置后的新请求仍应继续使用单调 request_id。"
	)
	if _router.route_operation_completed.is_connected(completion_callback):
		_router.route_operation_completed.disconnect(completion_callback)


func test_required_route_preload_completes_before_panel_open() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/preloaded_route_panel.tscn"
	assert_true(_router.register_route(route))

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{
			"preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED,
			"preload_plan_options": { "max_depth": 0 },
		}
	)
	assert_eq(asset_util.get_pending_count(route.scene_path), 1, "第一阶段只应提交预加载请求。")
	assert_true(operation.is_pending())

	asset_util.resolve(route.scene_path, _make_control_scene())
	assert_eq(asset_util.get_pending_count(route.scene_path), 1, "预加载提交后才应开始面板加载。")
	assert_true(operation.is_pending())

	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame
	var result: GFUIRouteResult = operation.get_result()

	assert_true(result.is_successful())
	assert_eq(result.get_status(), GFUIRouteResult.STATUS_OPENED)
	assert_true(result.was_preload_attempted())
	assert_true(result.was_preload_successful())
	assert_eq(result.get_preload_result().get_status(), GFAssetLoadSessionResult.STATUS_COMMITTED)
	assert_not_null(result.get_panel())
	assert_true(
		asset_util.get_group_paths(result.get_preload_result().get_group_id()).is_empty(),
		"Router 拥有的临时预加载 group 必须在面板终态后释放。"
	)


func test_required_route_preload_retains_explicit_caller_group() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/caller_owned_preload_group.tscn"
	assert_true(_router.register_route(route))

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{
			"preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED,
			"preload_plan_options": {
				"group_id": &"project_route_assets",
				"max_depth": 0,
			},
		}
	)
	asset_util.resolve(route.scene_path, _make_control_scene())
	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(operation.get_result().is_successful())
	assert_true(
		asset_util.get_group_paths(&"project_route_assets").has(route.scene_path),
		"显式 group_id 的所有权属于调用方，Router 不得自动卸载。"
	)


func test_required_route_preload_failure_blocks_panel_open() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/required_preload_failure.tscn"
	assert_true(_router.register_route(route))

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{
			"preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED,
			"preload_plan_options": { "max_depth": 0 },
		}
	)
	asset_util.resolve(route.scene_path, null)
	await get_tree().process_frame
	var result: GFUIRouteResult = operation.get_result()

	assert_eq(result.get_status(), GFUIRouteResult.STATUS_PRELOAD_FAILED)
	assert_true(result.was_preload_attempted())
	assert_false(result.was_preload_successful())
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 0)
	assert_eq(asset_util.get_pending_count(route.scene_path), 0, "严格预加载失败后不得继续提交面板加载。")
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：inventory (preload_failed)")


func test_best_effort_route_preload_failure_continues_with_typed_degradation() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/best_effort_preload_failure.tscn"
	assert_true(_router.register_route(route))

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{
			"preload_policy": GFUIRouterUtility.PRELOAD_BEST_EFFORT,
			"preload_plan_options": { "max_depth": 0 },
		}
	)
	asset_util.resolve(route.scene_path, null)
	assert_eq(asset_util.get_pending_count(route.scene_path), 1, "尽力预加载失败后仍应提交面板加载。")
	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame
	var result: GFUIRouteResult = operation.get_result()

	assert_true(result.is_successful())
	assert_true(result.was_preload_attempted())
	assert_false(result.was_preload_successful())
	assert_eq(result.get_reason(), &"preload_failed_continued")
	assert_eq(result.get_preload_result().get_status(), GFAssetLoadSessionResult.STATUS_FAILED)


func test_router_dispose_reports_unknown_outcome_for_submitted_panel_load() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/disposed_pending_route.tscn"
	assert_true(_router.register_route(route))

	var operation: GFUIRouteOperation = _router.push_route_async(&"inventory")
	_router.dispose()
	var result: GFUIRouteResult = operation.get_result()

	assert_eq(result.get_status(), GFUIRouteResult.STATUS_OUTCOME_UNKNOWN)
	assert_eq(result.get_reason(), &"router_disposed_after_panel_submit")
	assert_false(result.is_successful())


func test_router_reinit_does_not_record_late_panel_from_disposed_lifecycle() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/disposed_lifecycle_late_panel.tscn"
	assert_true(_router.register_route(route))
	watch_signals(_router)

	var operation: GFUIRouteOperation = _router.push_route_async(&"inventory")
	_router.dispose()
	_router.init()
	_router.set_ui_utility(_ui_utility)
	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_OUTCOME_UNKNOWN)
	assert_eq(_router.get_current_route_id(), &"", "旧生命周期的迟到面板不得污染重新初始化后的历史。")
	assert_signal_emit_count(_router, "route_opened", 0, "旧生命周期完成后不得发出新生命周期路由事件。")


func test_router_dispose_rolls_back_preload_before_panel_submit() -> void:
	_arch = GFArchitecture.new()
	var asset_util: ManualAssetUtility = ManualAssetUtility.new()
	await _arch.register_utility_instance(asset_util)
	await Gf.set_architecture(_arch)
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/disposed_preloading_route.tscn"
	assert_true(_router.register_route(route))
	watch_signals(_router)

	var operation: GFUIRouteOperation = _router.push_route_async(
		&"inventory",
		{},
		{},
		Callable(),
		{ "preload_policy": GFUIRouterUtility.PRELOAD_REQUIRED }
	)
	_router.dispose()
	var result: GFUIRouteResult = operation.get_result()

	assert_eq(result.get_status(), GFUIRouteResult.STATUS_DISPOSED)
	assert_eq(result.get_reason(), &"router_disposed_before_panel_submit")
	assert_true(operation.get_preload_session().get_state() == GFAssetLoadSession.State.ROLLBACK_PENDING)
	asset_util.resolve(route.scene_path, _make_control_scene())
	await get_tree().process_frame
	assert_eq(operation.get_result().get_status(), GFUIRouteResult.STATUS_DISPOSED)
	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 0)
	assert_signal_emit_count(_router, "route_operation_completed", 1, "dispose 与迟到预加载只能共享一个终态。")


# --- 私有/辅助方法 ---

func _make_route(route_id: StringName, layer: int) -> GFUIRoute:
	var route: GFUIRoute = GFUIRoute.new()
	route.route_id = route_id
	route.scene_path = _PANEL_SCENE_PATH
	route.layer = layer
	return route


func _make_control_scene() -> PackedScene:
	var control: Control = Control.new()
	var scene: PackedScene = PackedScene.new()
	var _pack_result_207: Variant = scene.pack(control)
	control.free()
	return scene
