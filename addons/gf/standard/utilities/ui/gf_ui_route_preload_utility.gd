## GFUIRoutePreloadUtility: 从显式 UI 路由关系构建资源预加载计划。
##
## 该工具只做有界、确定性的可达性遍历，并把页面场景转换为 GFAssetPreloadPlan。
## 权限、导航守卫、动态业务分支和实际预加载时机仍由项目负责。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 10.0.0
class_name GFUIRoutePreloadUtility
extends RefCounted


# --- 常量 ---

## 默认搜索深度，只包含直接相邻路由。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_DEPTH: int = 1

## 默认单次计划最多包含的路由数量。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_ROUTES: int = 64

## 默认单次遍历最多检查的原始相邻关系数量。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_EDGES: int = 512

## 默认单次规划最多检查的输入路由资源数量。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_MAX_CATALOG_ROUTES: int = 1024

## 默认资产预加载分组标识。
## [br]
## @api public
## [br]
## @since 10.0.0
const DEFAULT_GROUP_ID: StringName = &"ui_route_preload"


# --- 公共方法 ---

## 从路由资源构建有界可达性报告和 GFAssetPreloadPlan。
## [br]
## @api public
## [br]
## @since 10.0.0
## [br]
## @param routes: 可参与分析的路由资源。
## [br]
## @param source_route_id: 起始路由标识。
## [br]
## @param options: 计划选项。
## [br]
## @schema options: Dictionary，可包含 max_depth、max_routes、max_edges、max_catalog_routes、include_source、fixed_route_ids、group_id、plan_id、pin_cache、lane_id、max_concurrent_loads、check_exists 和 metadata；fixed_route_ids 优先占用 max_routes 预算，max_catalog_routes 限制输入目录检查数量。
## [br]
## @return 路由预加载结果。
## [br]
## @schema return: Dictionary，包含 ok、healthy、reason、source_route_id、max_depth、max_routes、max_edges、max_catalog_routes、catalog_route_count、edge_count、truncated、catalog_budget_exhausted、route_budget_exhausted、edge_budget_exhausted、route_ids、fixed_route_ids、temporary_route_ids、scene_paths、missing_route_ids、routes_without_scene、missing_scene_paths、invalid_scene_type_paths、duplicate_route_ids、asset_plan 和 metadata；asset_plan 为 GFAssetPreloadPlan。
static func build_plan(
	routes: Array[GFUIRoute],
	source_route_id: StringName,
	options: Dictionary = {}
) -> Dictionary:
	var max_depth: int = maxi(
		GFVariantData.get_option_int(options, "max_depth", DEFAULT_MAX_DEPTH),
		0
	)
	var max_routes: int = maxi(
		GFVariantData.get_option_int(options, "max_routes", DEFAULT_MAX_ROUTES),
		0
	)
	var max_edges: int = maxi(
		GFVariantData.get_option_int(options, "max_edges", DEFAULT_MAX_EDGES),
		0
	)
	var max_catalog_routes: int = maxi(
		GFVariantData.get_option_int(
			options,
			"max_catalog_routes",
			DEFAULT_MAX_CATALOG_ROUTES
		),
		0
	)
	var catalog_result: Dictionary = _build_catalog(routes, max_catalog_routes)
	var route_catalog: Dictionary = GFVariantData.get_option_dictionary(catalog_result, "routes")
	var duplicate_route_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		catalog_result,
		"duplicate_route_ids"
	)
	var catalog_route_count: int = GFVariantData.get_option_int(
		catalog_result,
		"catalog_route_count",
		0
	)
	var catalog_budget_exhausted: bool = GFVariantData.get_option_bool(
		catalog_result,
		"catalog_budget_exhausted"
	)
	var normalized_source_id: StringName = _normalize_route_id(source_route_id)
	var metadata: Dictionary = GFVariantData.get_option_dictionary(options, "metadata").duplicate(true)
	if normalized_source_id == &"" or not route_catalog.has(normalized_source_id):
		return _make_missing_source_result(
			normalized_source_id,
			max_depth,
			max_routes,
			max_edges,
			max_catalog_routes,
			catalog_route_count,
			catalog_budget_exhausted,
			duplicate_route_ids,
			metadata
		)

	var fixed_selection: Dictionary = _select_fixed_route_ids(
		GFVariantData.get_option_packed_string_array(options, "fixed_route_ids"),
		max_routes
	)
	var fixed_route_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		fixed_selection,
		"route_ids"
	)
	var reachable_result: Dictionary = _collect_reachable_routes(
		route_catalog,
		normalized_source_id,
		max_depth,
		max_routes,
		max_edges,
		GFVariantData.get_option_bool(options, "include_source", false),
		fixed_route_ids
	)
	var route_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		reachable_result,
		"route_ids"
	)
	var depths: Dictionary = GFVariantData.get_option_dictionary(reachable_result, "depths")
	var missing_route_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		reachable_result,
		"missing_route_ids"
	)
	for fixed_route_text: String in fixed_route_ids:
		var fixed_route_id: StringName = StringName(fixed_route_text)
		if not route_catalog.has(fixed_route_id):
			_append_unique_string(missing_route_ids, fixed_route_text)

	var plan: GFAssetPreloadPlan = _make_asset_plan(options, normalized_source_id, metadata)
	var route_path_result: Dictionary = _append_route_paths(
		plan,
		route_catalog,
		route_ids,
		fixed_route_ids,
		depths,
		GFVariantData.get_option_bool(options, "check_exists", false)
	)
	var temporary_route_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		route_path_result,
		"temporary_route_ids"
	)
	var included_fixed_route_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(
		route_path_result,
		"fixed_route_ids"
	)
	var routes_without_scene: PackedStringArray = GFVariantData.get_option_packed_string_array(
		route_path_result,
		"routes_without_scene"
	)
	var missing_scene_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(
		route_path_result,
		"missing_scene_paths"
	)
	var invalid_scene_type_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(
		route_path_result,
		"invalid_scene_type_paths"
	)
	var scene_paths: PackedStringArray = GFVariantData.get_option_packed_string_array(
		route_path_result,
		"scene_paths"
	)
	var route_budget_exhausted: bool = (
		GFVariantData.get_option_bool(fixed_selection, "truncated")
		or GFVariantData.get_option_bool(reachable_result, "route_budget_exhausted")
	)
	var edge_budget_exhausted: bool = GFVariantData.get_option_bool(
		reachable_result,
		"edge_budget_exhausted"
	)
	var truncated: bool = (
		catalog_budget_exhausted
		or route_budget_exhausted
		or edge_budget_exhausted
	)
	var edge_count: int = GFVariantData.get_option_int(reachable_result, "edge_count", 0)
	var healthy: bool = (
		missing_route_ids.is_empty()
		and routes_without_scene.is_empty()
		and missing_scene_paths.is_empty()
		and invalid_scene_type_paths.is_empty()
		and duplicate_route_ids.is_empty()
		and not truncated
	)
	plan.metadata["source_route_id"] = normalized_source_id
	plan.metadata["max_depth"] = max_depth
	plan.metadata["max_routes"] = max_routes
	plan.metadata["max_edges"] = max_edges
	plan.metadata["max_catalog_routes"] = max_catalog_routes
	plan.metadata["catalog_route_count"] = catalog_route_count
	plan.metadata["edge_count"] = edge_count
	plan.metadata["truncated"] = truncated
	plan.metadata["catalog_budget_exhausted"] = catalog_budget_exhausted
	plan.metadata["route_budget_exhausted"] = route_budget_exhausted
	plan.metadata["edge_budget_exhausted"] = edge_budget_exhausted
	plan.metadata["route_ids"] = route_ids
	plan.metadata["fixed_route_ids"] = included_fixed_route_ids
	plan.metadata["temporary_route_ids"] = temporary_route_ids
	plan.metadata["missing_route_ids"] = missing_route_ids

	return {
		"ok": true,
		"healthy": healthy,
		"reason": &"",
		"source_route_id": normalized_source_id,
		"max_depth": max_depth,
		"max_routes": max_routes,
		"max_edges": max_edges,
		"max_catalog_routes": max_catalog_routes,
		"catalog_route_count": catalog_route_count,
		"edge_count": edge_count,
		"truncated": truncated,
		"catalog_budget_exhausted": catalog_budget_exhausted,
		"route_budget_exhausted": route_budget_exhausted,
		"edge_budget_exhausted": edge_budget_exhausted,
		"route_ids": route_ids,
		"fixed_route_ids": included_fixed_route_ids,
		"temporary_route_ids": temporary_route_ids,
		"scene_paths": scene_paths,
		"missing_route_ids": missing_route_ids,
		"routes_without_scene": routes_without_scene,
		"missing_scene_paths": missing_scene_paths,
		"invalid_scene_type_paths": invalid_scene_type_paths,
		"duplicate_route_ids": duplicate_route_ids,
		"asset_plan": plan,
		"metadata": metadata,
	}


# --- 私有/辅助方法 ---

static func _build_catalog(routes: Array[GFUIRoute], max_catalog_routes: int) -> Dictionary:
	var route_catalog: Dictionary = {}
	var duplicate_route_ids: PackedStringArray = PackedStringArray()
	var catalog_route_count: int = 0
	var catalog_budget_exhausted: bool = false
	for route: GFUIRoute in routes:
		if catalog_route_count >= max_catalog_routes:
			catalog_budget_exhausted = true
			break
		catalog_route_count += 1
		if route == null:
			continue
		var route_id: StringName = _normalize_route_id(route.get_route_id())
		if route_id == &"":
			continue
		if route_catalog.has(route_id):
			_append_unique_string(duplicate_route_ids, String(route_id))
			continue
		route_catalog[route_id] = route
	return {
		"routes": route_catalog,
		"duplicate_route_ids": duplicate_route_ids,
		"catalog_route_count": catalog_route_count,
		"catalog_budget_exhausted": catalog_budget_exhausted,
	}


static func _collect_reachable_routes(
	route_catalog: Dictionary,
	source_route_id: StringName,
	max_depth: int,
	max_routes: int,
	max_edges: int,
	include_source: bool,
	preselected_route_ids: PackedStringArray
) -> Dictionary:
	var route_ids: PackedStringArray = PackedStringArray()
	var missing_route_ids: PackedStringArray = PackedStringArray()
	var selected_route_ids: Dictionary = {}
	for selected_text: String in preselected_route_ids:
		selected_route_ids[StringName(selected_text)] = true
	var depths: Dictionary = {
		source_route_id: 0,
	}
	var visited: Dictionary = {
		source_route_id: true,
	}
	var queue: Array[Dictionary] = [
		{
			"route_id": source_route_id,
			"depth": 0,
		},
	]
	var edge_count: int = 0
	var route_budget_exhausted: bool = false
	var edge_budget_exhausted: bool = false
	if include_source:
		if selected_route_ids.has(source_route_id):
			var _preselected_source_appended: bool = route_ids.append(String(source_route_id))
		elif selected_route_ids.size() < max_routes:
			selected_route_ids[source_route_id] = true
			var _source_appended: bool = route_ids.append(String(source_route_id))
		else:
			route_budget_exhausted = true

	while (
		not queue.is_empty()
		and not route_budget_exhausted
		and not edge_budget_exhausted
	):
		var current: Dictionary = queue.pop_front()
		var current_route_id: StringName = GFVariantData.get_option_string_name(current, "route_id")
		var current_depth: int = GFVariantData.get_option_int(current, "depth", 0)
		if current_depth >= max_depth:
			continue
		var route: GFUIRoute = _get_route(route_catalog, current_route_id)
		if route == null:
			continue
		for adjacent_text: String in route.adjacent_route_ids:
			if edge_count >= max_edges:
				edge_budget_exhausted = true
				break
			edge_count += 1
			var adjacent_route_id: StringName = _normalize_route_id(StringName(adjacent_text))
			if adjacent_route_id == &"" or visited.has(adjacent_route_id):
				continue
			visited[adjacent_route_id] = true
			if not selected_route_ids.has(adjacent_route_id):
				if selected_route_ids.size() >= max_routes:
					route_budget_exhausted = true
					break
				selected_route_ids[adjacent_route_id] = true
			if not route_catalog.has(adjacent_route_id):
				_append_unique_string(missing_route_ids, String(adjacent_route_id))
				continue
			var next_depth: int = current_depth + 1
			_append_unique_string(route_ids, String(adjacent_route_id))
			depths[adjacent_route_id] = next_depth
			queue.append({
				"route_id": adjacent_route_id,
				"depth": next_depth,
			})
	return {
		"route_ids": route_ids,
		"missing_route_ids": missing_route_ids,
		"depths": depths,
		"edge_count": edge_count,
		"route_budget_exhausted": route_budget_exhausted,
		"edge_budget_exhausted": edge_budget_exhausted,
	}


static func _make_asset_plan(
	options: Dictionary,
	source_route_id: StringName,
	metadata: Dictionary
) -> GFAssetPreloadPlan:
	var group_id: StringName = GFVariantData.get_option_string_name(
		options,
		"group_id",
		DEFAULT_GROUP_ID
	)
	if group_id == &"":
		group_id = DEFAULT_GROUP_ID
	var plan_id: StringName = GFVariantData.get_option_string_name(options, "plan_id")
	if plan_id == &"":
		plan_id = StringName("ui_route_preload:%s" % String(source_route_id))
	var plan: GFAssetPreloadPlan = GFAssetPreloadPlan.new()
	var _configured: GFAssetPreloadPlan = plan.configure(
		group_id,
		[],
		{
			"plan_id": plan_id,
			"pin_cache": GFVariantData.get_option_bool(options, "pin_cache", false),
			"lane_id": GFVariantData.get_option_string_name(options, "lane_id"),
			"max_concurrent_loads": maxi(
				GFVariantData.get_option_int(options, "max_concurrent_loads", 0),
				0
			),
			"metadata": metadata,
		}
	)
	return plan


static func _append_route_paths(
	plan: GFAssetPreloadPlan,
	route_catalog: Dictionary,
	route_ids: PackedStringArray,
	fixed_route_ids: PackedStringArray,
	depths: Dictionary,
	check_exists: bool
) -> Dictionary:
	var included_fixed_route_ids: PackedStringArray = PackedStringArray()
	var temporary_route_ids: PackedStringArray = PackedStringArray()
	var scene_paths: PackedStringArray = PackedStringArray()
	var routes_without_scene: PackedStringArray = PackedStringArray()
	var missing_scene_paths: PackedStringArray = PackedStringArray()
	var invalid_scene_type_paths: PackedStringArray = PackedStringArray()
	var seen_cache_keys: Dictionary = {}
	for fixed_text: String in fixed_route_ids:
		_append_route_path(
			plan,
			route_catalog,
			StringName(fixed_text),
			true,
			depths,
			check_exists,
			included_fixed_route_ids,
			temporary_route_ids,
			scene_paths,
			routes_without_scene,
			missing_scene_paths,
			invalid_scene_type_paths,
			seen_cache_keys
		)
	for route_text: String in route_ids:
		var route_id: StringName = StringName(route_text)
		if included_fixed_route_ids.has(route_text):
			continue
		_append_route_path(
			plan,
			route_catalog,
			route_id,
			false,
			depths,
			check_exists,
			included_fixed_route_ids,
			temporary_route_ids,
			scene_paths,
			routes_without_scene,
			missing_scene_paths,
			invalid_scene_type_paths,
			seen_cache_keys
		)
	return {
		"fixed_route_ids": included_fixed_route_ids,
		"temporary_route_ids": temporary_route_ids,
		"scene_paths": scene_paths,
		"routes_without_scene": routes_without_scene,
		"missing_scene_paths": missing_scene_paths,
		"invalid_scene_type_paths": invalid_scene_type_paths,
	}


static func _append_route_path(
	plan: GFAssetPreloadPlan,
	route_catalog: Dictionary,
	route_id: StringName,
	fixed: bool,
	depths: Dictionary,
	check_exists: bool,
	included_fixed_route_ids: PackedStringArray,
	temporary_route_ids: PackedStringArray,
	scene_paths: PackedStringArray,
	routes_without_scene: PackedStringArray,
	missing_scene_paths: PackedStringArray,
	invalid_scene_type_paths: PackedStringArray,
	seen_cache_keys: Dictionary
) -> void:
	var route: GFUIRoute = _get_route(route_catalog, route_id)
	if route == null:
		return
	var scene_path: String = route.scene_path.strip_edges()
	if scene_path.is_empty():
		_append_unique_string(routes_without_scene, String(route_id))
		return
	var identity: GFResourceIdentity = GFResourceIdentity.from_path(
		scene_path,
		&"",
		"PackedScene",
		{ "check_exists": false }
	)
	var normalized_path: String = identity.canonical_path if not identity.canonical_path.is_empty() else identity.raw_path
	if normalized_path.is_empty():
		_append_unique_string(routes_without_scene, String(route_id))
		return
	if check_exists:
		if not ResourceLoader.exists(normalized_path):
			_append_unique_string(missing_scene_paths, normalized_path)
		elif (
			not ResourceLoader.exists(normalized_path, "PackedScene")
			or not ResourceLoader.get_recognized_extensions_for_type("PackedScene").has(
				identity.extension
			)
		):
			_append_unique_string(invalid_scene_type_paths, normalized_path)
	if seen_cache_keys.has(identity.cache_key):
		return
	seen_cache_keys[identity.cache_key] = true
	var _entry_index: int = plan.add_path(
		normalized_path,
		"PackedScene",
		{
			"route_id": route_id,
			"depth": GFVariantData.get_option_int(depths, route_id, -1),
			"fixed": fixed,
		}
	)
	_append_unique_string(scene_paths, normalized_path)
	if fixed:
		_append_unique_string(included_fixed_route_ids, String(route_id))
	else:
		_append_unique_string(temporary_route_ids, String(route_id))


static func _make_missing_source_result(
	source_route_id: StringName,
	max_depth: int,
	max_routes: int,
	max_edges: int,
	max_catalog_routes: int,
	catalog_route_count: int,
	catalog_budget_exhausted: bool,
	duplicate_route_ids: PackedStringArray,
	metadata: Dictionary
) -> Dictionary:
	var missing_route_ids: PackedStringArray = PackedStringArray()
	var reason: StringName = &"missing_source_route"
	if source_route_id != &"" and catalog_budget_exhausted:
		reason = &"catalog_budget_exhausted"
	else:
		_append_unique_string(missing_route_ids, String(source_route_id))
	return {
		"ok": false,
		"healthy": false,
		"reason": reason,
		"source_route_id": source_route_id,
		"max_depth": max_depth,
		"max_routes": max_routes,
		"max_edges": max_edges,
		"max_catalog_routes": max_catalog_routes,
		"catalog_route_count": catalog_route_count,
		"edge_count": 0,
		"truncated": catalog_budget_exhausted,
		"catalog_budget_exhausted": catalog_budget_exhausted,
		"route_budget_exhausted": false,
		"edge_budget_exhausted": false,
		"route_ids": PackedStringArray(),
		"fixed_route_ids": PackedStringArray(),
		"temporary_route_ids": PackedStringArray(),
		"scene_paths": PackedStringArray(),
		"missing_route_ids": missing_route_ids,
		"routes_without_scene": PackedStringArray(),
		"missing_scene_paths": PackedStringArray(),
		"invalid_scene_type_paths": PackedStringArray(),
		"duplicate_route_ids": duplicate_route_ids,
		"asset_plan": null,
		"metadata": metadata,
	}


static func _select_fixed_route_ids(
	route_ids: PackedStringArray,
	max_routes: int
) -> Dictionary:
	var result: PackedStringArray = PackedStringArray()
	var truncated: bool = false
	for route_text: String in route_ids:
		var route_id: StringName = _normalize_route_id(StringName(route_text))
		if route_id == &"" or result.has(String(route_id)):
			continue
		if result.size() >= max_routes:
			truncated = true
			break
		_append_unique_string(result, String(route_id))
	return {
		"route_ids": result,
		"truncated": truncated,
	}


static func _normalize_route_id(route_id: StringName) -> StringName:
	return StringName(String(route_id).strip_edges())


static func _get_route(route_catalog: Dictionary, route_id: StringName) -> GFUIRoute:
	var value: Variant = route_catalog.get(route_id)
	if value is GFUIRoute:
		var route: GFUIRoute = value
		return route
	return null


static func _append_unique_string(values: PackedStringArray, value: String) -> void:
	if value.is_empty() or values.has(value):
		return
	var _appended: bool = values.append(value)
