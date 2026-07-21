extends GutTest


# --- 常量 ---

const _SCENE_A: String = "res://tests/gf_core/fixtures/scene_signal_audit_valid.tscn"
const _SCENE_B: String = "res://addons/gut/gui/NormalGui.tscn"
const _SCENE_C: String = "res://addons/gut/gui/MinGui.tscn"
const _SCENE_D: String = "res://addons/gut/gui/GutRunner.tscn"
const _NON_SCENE_RESOURCE: String = "res://addons/gf/standard/utilities/ui/gf_ui_route.gd"


# --- 测试方法 ---

func test_route_preload_plan_traverses_explicit_neighbors_by_depth() -> void:
	var routes: Array[GFUIRoute] = [
		_make_route(&"home", _SCENE_A, PackedStringArray(["settings", "shop"])),
		_make_route(&"settings", _SCENE_B, PackedStringArray(["audio"])),
		_make_route(&"shop", _SCENE_C),
		_make_route(&"audio", _SCENE_D),
	]

	var shallow: Dictionary = GFUIRoutePreloadUtility.build_plan(
		routes,
		&"home",
		{ "max_depth": 1 }
	)
	var deep: Dictionary = GFUIRoutePreloadUtility.build_plan(
		routes,
		&"home",
		{ "max_depth": 2 }
	)

	assert_eq(
		GFVariantData.get_option_packed_string_array(shallow, "route_ids"),
		PackedStringArray(["settings", "shop"]),
		"深度 1 应只包含直接相邻页面。"
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(deep, "route_ids"),
		PackedStringArray(["settings", "shop", "audio"]),
		"深度 2 应按稳定 BFS 顺序包含下一层页面。"
	)


func test_route_preload_plan_builds_asset_plan_with_fixed_and_temporary_routes() -> void:
	var routes: Array[GFUIRoute] = [
		_make_route(&"home", _SCENE_A, PackedStringArray(["settings", "shop"])),
		_make_route(&"settings", _SCENE_B),
		_make_route(&"shop", _SCENE_C),
	]
	var result: Dictionary = GFUIRoutePreloadUtility.build_plan(
		routes,
		&"home",
		{
			"fixed_route_ids": PackedStringArray(["settings"]),
			"group_id": &"main_menu_pages",
			"pin_cache": true,
		}
	)
	var plan: GFAssetPreloadPlan = _get_asset_plan(result)
	var entries: Array[Dictionary] = plan.get_entries() if plan != null else []

	assert_true(GFVariantData.get_option_bool(result, "ok"), "有效路由图应构建成功。")
	assert_not_null(plan, "结果应包含 GFAssetPreloadPlan。")
	assert_eq(plan.group_id, &"main_menu_pages", "调用方应能覆盖资源分组。")
	assert_true(plan.pin_cache, "固定菜单预热可以显式 pin 缓存。")
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "fixed_route_ids"),
		PackedStringArray(["settings"]),
		"固定路由应单独归类。"
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "temporary_route_ids"),
		PackedStringArray(["shop"]),
		"其他可达路由应进入临时集合。"
	)
	assert_eq(entries.size(), 2, "计划应按场景资源身份去重后生成条目。")
	assert_eq(GFVariantData.get_option_string(entries[0], "type_hint"), "PackedScene", "UI 页面应使用 PackedScene 类型提示。")


func test_route_preload_plan_reports_missing_routes_and_scene_resources() -> void:
	var routes: Array[GFUIRoute] = [
		_make_route(&"home", _SCENE_A, PackedStringArray(["missing", "broken"])),
		_make_route(&"broken", "res://missing/ui_panel.tscn"),
	]
	var result: Dictionary = GFUIRoutePreloadUtility.build_plan(
		routes,
		&"home",
		{ "check_exists": true }
	)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "缺失邻接项不应让可执行部分完全失效。")
	assert_false(GFVariantData.get_option_bool(result, "healthy", true), "缺失邻接和资源应让诊断不健康。")
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "missing_route_ids"),
		PackedStringArray(["missing"]),
		"应报告悬空 route ID。"
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "missing_scene_paths"),
		PackedStringArray(["res://missing/ui_panel.tscn"]),
		"应按选项报告缺失页面资源。"
	)
	assert_true(
		GFVariantData.get_option_packed_string_array(result, "invalid_scene_type_paths").is_empty(),
		"缺失资源不应混入类型错误诊断。"
	)


func test_route_preload_plan_rejects_existing_non_scene_resources() -> void:
	assert_true(ResourceLoader.exists(_NON_SCENE_RESOURCE), "测试资源必须存在。")
	assert_false(
		ResourceLoader.get_recognized_extensions_for_type("PackedScene").has("gd"),
		"测试资源不能被识别为 PackedScene。"
	)
	var routes: Array[GFUIRoute] = [
		_make_route(&"home", _SCENE_A, PackedStringArray(["invalid_scene"])),
		_make_route(&"invalid_scene", _NON_SCENE_RESOURCE),
	]
	var result: Dictionary = GFUIRoutePreloadUtility.build_plan(
		routes,
		&"home",
		{ "check_exists": true }
	)

	assert_true(GFVariantData.get_option_bool(result, "ok"), "有效部分仍应生成稳定计划。")
	assert_false(
		GFVariantData.get_option_bool(result, "healthy", true),
		"指向非场景资源的路由必须标记为不健康。"
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "invalid_scene_type_paths"),
		PackedStringArray([_NON_SCENE_RESOURCE]),
		"类型不匹配的既有资源应进入场景路径诊断。"
	)
	assert_true(
		GFVariantData.get_option_packed_string_array(result, "missing_scene_paths").is_empty(),
		"类型不匹配的既有资源不应误报为缺失。"
	)


func test_route_preload_plan_enforces_route_budget() -> void:
	var routes: Array[GFUIRoute] = [
		_make_route(&"home", _SCENE_A, PackedStringArray(["a", "b", "c"])),
		_make_route(&"a", _SCENE_B),
		_make_route(&"b", _SCENE_C),
		_make_route(&"c", _SCENE_D),
	]
	var result: Dictionary = GFUIRoutePreloadUtility.build_plan(
		routes,
		&"home",
		{ "max_routes": 2 }
	)

	assert_true(GFVariantData.get_option_bool(result, "truncated"), "超过路由预算时应明确标记截断。")
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "route_ids"),
		PackedStringArray(["a", "b"]),
		"截断仍应保持稳定遍历顺序。"
	)
	assert_true(
		GFVariantData.get_option_bool(result, "route_budget_exhausted"),
		"报告应区分路由数量预算耗尽。"
	)


func test_route_preload_plan_counts_fixed_routes_in_total_budget() -> void:
	var routes: Array[GFUIRoute] = [
		_make_route(&"home", _SCENE_A, PackedStringArray(["b", "c"])),
		_make_route(&"a", _SCENE_B),
		_make_route(&"b", _SCENE_C),
		_make_route(&"c", _SCENE_D),
		_make_route(&"d", _SCENE_A),
	]
	var result: Dictionary = GFUIRoutePreloadUtility.build_plan(
		routes,
		&"home",
		{
			"max_routes": 2,
			"fixed_route_ids": PackedStringArray(["a", "d", "c"]),
		}
	)
	var plan: GFAssetPreloadPlan = _get_asset_plan(result)

	assert_true(GFVariantData.get_option_bool(result, "truncated"), "固定路由也应受总预算约束。")
	assert_true(
		GFVariantData.get_option_bool(result, "route_budget_exhausted"),
		"固定候选超限应报告路由预算耗尽。"
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "fixed_route_ids"),
		PackedStringArray(["a", "d"]),
		"固定候选应按声明顺序优先占用预算。"
	)
	assert_eq(plan.get_entry_count() if plan != null else -1, 2, "资产计划条目不能绕过 max_routes。")


func test_route_preload_plan_bounds_raw_edges_and_missing_diagnostics() -> void:
	var routes: Array[GFUIRoute] = [
		_make_route(
			&"home",
			_SCENE_A,
			PackedStringArray(["missing_a", "missing_b", "missing_c"])
		),
	]
	var result: Dictionary = GFUIRoutePreloadUtility.build_plan(
		routes,
		&"home",
		{
			"max_routes": 10,
			"max_edges": 2,
		}
	)

	assert_true(GFVariantData.get_option_bool(result, "truncated"), "原始关系超限应标记截断。")
	assert_true(
		GFVariantData.get_option_bool(result, "edge_budget_exhausted"),
		"报告应区分相邻关系预算耗尽。"
	)
	assert_eq(GFVariantData.get_option_int(result, "edge_count"), 2, "相邻关系检查数应受硬上限约束。")
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "missing_route_ids"),
		PackedStringArray(["missing_a", "missing_b"]),
		"缺失诊断不能越过相邻关系预算。"
	)


func test_route_preload_plan_bounds_catalog_inspection() -> void:
	var routes: Array[GFUIRoute] = [
		_make_route(&"home", _SCENE_A, PackedStringArray(["settings", "shop"])),
		_make_route(&"settings", _SCENE_B),
		_make_route(&"shop", _SCENE_C),
	]
	var result: Dictionary = GFUIRoutePreloadUtility.build_plan(
		routes,
		&"home",
		{ "max_catalog_routes": 2 }
	)

	assert_true(GFVariantData.get_option_bool(result, "truncated"), "目录超限应标记截断。")
	assert_true(
		GFVariantData.get_option_bool(result, "catalog_budget_exhausted"),
		"报告应区分输入目录预算耗尽。"
	)
	assert_eq(
		GFVariantData.get_option_int(result, "catalog_route_count"),
		2,
		"目录检查数不得越过硬上限。"
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "route_ids"),
		PackedStringArray(["settings"]),
		"计划只能使用预算内已检查的目录项。"
	)
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "missing_route_ids"),
		PackedStringArray(["shop"]),
		"预算外邻接项应作为未解析候选报告。"
	)

	var missing_source: Dictionary = GFUIRoutePreloadUtility.build_plan(
		routes,
		&"shop",
		{ "max_catalog_routes": 2 }
	)
	assert_false(GFVariantData.get_option_bool(missing_source, "ok", true), "预算外源路由不能伪装为成功。")
	assert_eq(
		GFVariantData.get_option_string_name(missing_source, "reason"),
		&"catalog_budget_exhausted",
		"源路由可能位于截断目录外时应报告目录预算，而不是断言资源缺失。"
	)
	assert_true(
		GFVariantData.get_option_packed_string_array(missing_source, "missing_route_ids").is_empty(),
		"目录截断时不能把尚未检查的源路由误报为确定缺失。"
	)

	var empty_source: Dictionary = GFUIRoutePreloadUtility.build_plan(
		routes,
		&"",
		{ "max_catalog_routes": 2 }
	)
	assert_eq(
		GFVariantData.get_option_string_name(empty_source, "reason"),
		&"missing_source_route",
		"空源路由本身已无效，不应被目录截断原因掩盖。"
	)


func test_route_resource_deduplicates_adjacent_ids_and_router_uses_registry() -> void:
	var home: GFUIRoute = _make_route(
		&" home ",
		_SCENE_A,
		PackedStringArray([" settings ", "settings", " home ", ""])
	)
	var settings: GFUIRoute = _make_route(&" settings ", _SCENE_B)
	var router: GFUIRouterUtility = GFUIRouterUtility.new()
	router.init()
	assert_true(router.register_route(home), "home 路由应注册成功。")
	assert_true(router.register_route(settings), "settings 路由应注册成功。")
	assert_true(router.has_route(&"home"), "注册边界应保存规范化路由 ID。")
	assert_eq(router.get_route(&" settings "), settings, "查询边界应使用相同的路由 ID 规范化规则。")

	var result: Dictionary = router.build_preload_plan(&" home ")

	assert_eq(home.get_adjacent_route_ids(), PackedStringArray(["settings"]), "相邻路由应去重并移除自引用。")
	assert_eq(
		GFVariantData.get_option_packed_string_array(result, "route_ids"),
		PackedStringArray(["settings"]),
		"Router 应使用当前注册表构建计划。"
	)
	router.unregister_route(&" settings ")
	assert_false(router.has_route(&"settings"), "注销边界应使用相同的路由 ID 规范化规则。")
	router.dispose()


func test_route_preload_plan_rejects_missing_source() -> void:
	var result: Dictionary = GFUIRoutePreloadUtility.build_plan([], &"missing")

	assert_false(GFVariantData.get_option_bool(result, "ok", true), "缺失起始路由时计划应失败。")
	assert_eq(
		GFVariantData.get_option_string_name(result, "reason"),
		&"missing_source_route",
		"失败原因应稳定可诊断。"
	)
	assert_true(
		result.has("asset_plan") and result["asset_plan"] == null,
		"失败结果应保持稳定 schema，但不应伪造空资产计划。"
	)


# --- 私有/辅助方法 ---

func _make_route(
	route_id: StringName,
	scene_path: String,
	adjacent_route_ids: PackedStringArray = PackedStringArray()
) -> GFUIRoute:
	var route: GFUIRoute = GFUIRoute.new()
	route.route_id = route_id
	route.scene_path = scene_path
	route.layer = GFUIUtility.Layer.POPUP
	route.adjacent_route_ids = adjacent_route_ids
	return route


func _get_asset_plan(result: Dictionary) -> GFAssetPreloadPlan:
	var value: Variant = GFVariantData.get_option_value(result, "asset_plan")
	if value is GFAssetPreloadPlan:
		var plan: GFAssetPreloadPlan = value
		return plan
	return null
