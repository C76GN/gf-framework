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
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	route.scene_path = "res://tests/pending_route_panel.tscn"
	var _register_route_result_182: Variant = _router.register_route(route)

	_router.push_route_async(&"inventory")
	_router.push_route_async(&"inventory")
	asset_util.resolve("res://tests/pending_route_panel.tscn", _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1, "重复异步打开同一路由时 UI 栈只应出现一个面板。")
	assert_eq(_router.get_route_history().size(), 1, "重复异步打开同一路由时历史只应记录一次。")


func test_async_route_sync_fallback_reaches_terminal_state() -> void:
	var route: GFUIRoute = _make_route(&"inventory", GFUIUtility.Layer.POPUP)
	assert_true(_router.register_route(route), "有效路由应可注册。")

	_router.push_route_async(&"inventory")
	await get_tree().process_frame

	var snapshot: Dictionary = _router.get_debug_snapshot()
	assert_eq(
		GFVariantData.get_option_int(snapshot, "pending_async_route_count", -1),
		0,
		"缺少 GFAssetUtility 时的同步回退也必须结束异步路由生命周期。"
	)
	assert_eq(_router.get_current_route_id(), &"inventory", "同步回退打开的路由仍应进入历史。")


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

	_router.push_route_async(&"inventory")
	_router.push_route_async(&"settings")
	asset_util.resolve("res://tests/shared_pending_route_panel.tscn", _make_control_scene())
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_ui_utility.get_stack_count(GFUIUtility.Layer.POPUP), 1, "冲突路由只能打开第一个请求对应的面板。")
	assert_eq(_router.get_current_route_id(), &"inventory", "冲突失败后历史应保留第一个路由。")
	assert_signal_emitted_with_parameters(_router, "route_open_failed", [&"settings", "route_async_conflict"])
	assert_push_warning("[GFUIRouterUtility] 路由打开失败：settings (route_async_conflict)")


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

	_router.replace_route_async(&"second")
	asset_util.resolve("res://tests/missing_async_replace_panel.tscn", null)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_router.get_current_route_id(), &"first", "异步 replace 失败后应保留旧路由历史。")
	assert_true(_ui_utility.is_panel_open(first_panel, GFUIUtility.Layer.POPUP), "异步 replace 失败后旧面板应仍在 UI 栈中。")
	assert_signal_emitted(_router, "route_open_failed", "异步 replace 失败应发出路由失败信号。")
	assert_push_error("[GFUIUtility] 无法实例化面板场景：res://tests/missing_async_replace_panel.tscn")


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
