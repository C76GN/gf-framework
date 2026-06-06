## 测试 GFResourceResolverUtility 的路径注册、provider 覆盖、直接路径和 GFAssetUtility 衔接。
extends GutTest


# --- 常量 ---

const RESOURCE_RESOLVER_SCRIPT = preload("res://addons/gf/standard/utilities/assets/gf_resource_resolver_utility.gd")


# --- 私有变量 ---

var _resolver: Object


# --- 测试生命周期 ---

func before_each() -> void:
	_resolver = RESOURCE_RESOLVER_SCRIPT.new()
	_call_resolver("init")


func after_each() -> void:
	if _resolver != null:
		_call_resolver("dispose")
	_resolver = null


# --- 测试用例 ---

func test_registered_path_resolves_and_loads_existing_resource() -> void:
	assert_true(_register_path(&"icon", "res://icon.svg", "Texture2D"), "有效资源键和路径应可注册。")

	var report: Dictionary = _resolve(&"icon")
	var loaded: Resource = _load(&"icon")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "存在的注册路径应解析成功。")
	assert_eq(GFVariantData.get_option_string(report, "path"), "res://icon.svg", "解析报告应包含资源路径。")
	assert_eq(GFVariantData.get_option_string(report, "type_hint"), "Texture2D", "解析报告应保留注册类型提示。")
	assert_true(loaded is Texture2D, "同步加载应返回匹配类型的资源。")


func test_missing_registered_path_reports_missing_resource() -> void:
	var _registered: bool = _register_path(&"missing", "res://missing_resource_for_resolver.tres", "Resource")

	var report: Dictionary = _resolve(&"missing")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失资源路径应解析为失败报告。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "missing_resource", "失败原因应稳定可读。")
	assert_eq(GFVariantData.get_option_string(report, "path"), "res://missing_resource_for_resolver.tres", "报告应保留失败路径。")


func test_provider_override_uses_priority_before_registered_path() -> void:
	var _registered: bool = _register_path(&"icon", "res://icon.svg", "Texture2D", 0)
	var provider: PathProvider = PathProvider.new("res://override_resource.tres", "Resource", { "source": "provider" })
	assert_true(_register_provider(provider, &"override", 10), "provider 应可注册。")

	var report: Dictionary = _resolve(&"icon", "", { "check_exists": false })
	var metadata: Dictionary = GFVariantData.get_option_dictionary(report, "metadata")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "关闭存在性检查时，高优先级 provider 路径应解析成功。")
	assert_eq(GFVariantData.get_option_string(report, "path"), "res://override_resource.tres", "高优先级 provider 应覆盖显式注册路径。")
	assert_eq(GFVariantData.get_option_string_name(report, "provider_id"), &"override", "报告应标识命中的 provider。")
	assert_eq(GFVariantData.get_option_string(metadata, "source"), "provider", "provider 元数据应进入报告副本。")


func test_missing_high_priority_provider_falls_back_to_registered_path() -> void:
	var _registered: bool = _register_path(&"icon", "res://icon.svg", "Texture2D", 0)
	var provider: PathProvider = PathProvider.new("res://missing_override_resource.tres", "Resource")
	var _provider_registered: bool = _register_provider(provider, &"missing_override", 10)

	var report: Dictionary = _resolve(&"icon")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "高优先级 provider 缺失时应继续尝试低优先级候选。")
	assert_eq(GFVariantData.get_option_string(report, "path"), "res://icon.svg", "应回退到有效的显式注册路径。")
	assert_eq(GFVariantData.get_option_string_name(report, "provider_id"), &"registered", "命中的 provider 应是注册路径。")


func test_direct_path_fallback_is_disabled_by_default() -> void:
	var report: Dictionary = _resolve(&"res://icon.svg", "Texture2D")
	var loaded: Resource = _load(&"res://icon.svg", "Texture2D")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "直接路径默认不应作为资源键解析。")
	assert_eq(GFVariantData.get_option_string(report, "reason"), "not_found", "默认禁用直接路径时应返回未找到。")
	assert_eq(loaded, null, "直接路径默认不应触发同步加载。")


func test_direct_path_fallback_can_be_enabled_explicitly() -> void:
	var options: Dictionary = { "allow_direct_path": true }
	var report: Dictionary = _resolve(&"res://icon.svg", "Texture2D", options)
	var loaded: Resource = _load(&"res://icon.svg", "Texture2D", options)

	assert_true(GFVariantData.get_option_bool(report, "ok"), "直接 res:// 路径应可作为回退资源键。")
	assert_eq(GFVariantData.get_option_string_name(report, "provider_id"), &"direct_path", "报告应标识直接路径来源。")
	assert_true(loaded is Texture2D, "直接路径加载应返回资源。")


func test_provider_can_return_in_memory_resource() -> void:
	var resource: Resource = Resource.new()
	var provider: ResourceProvider = ResourceProvider.new(resource)
	var _registered: bool = _register_provider(provider, &"memory", 5)

	var report: Dictionary = _resolve(&"memory", "Resource")
	var loaded: Resource = _load(&"memory", "Resource")
	var entries: Array[Dictionary] = _make_asset_group_entries(PackedStringArray(["memory"]), "Resource")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "provider 返回 Resource 时应解析成功。")
	assert_eq(loaded, resource, "同步加载应直接返回 provider 提供的 Resource。")
	assert_true(entries.is_empty(), "内存 Resource 没有路径时不应生成 AssetUtility 分组请求。")


func test_load_async_uses_asset_utility_for_resolved_path() -> void:
	var asset_utility: CompletingAssetUtility = CompletingAssetUtility.new()
	asset_utility.init()
	asset_utility.complete = true
	var _registered: bool = _register_path(&"async", "res://async_resource.tres", "Resource")
	var loaded: Array[Resource] = []

	_call_resolver("load_async", [
		asset_utility,
		&"async",
		func(resource: Resource) -> void:
			loaded.append(resource),
		"",
		{ "check_exists": false }
	])
	asset_utility.tick()

	assert_eq(asset_utility.requested_paths, ["res://async_resource.tres"], "路径解析后应交给 GFAssetUtility。")
	assert_eq(loaded.size(), 1, "异步加载完成后应回调一次。")
	assert_eq(loaded[0], asset_utility.loaded_resource, "回调应收到 AssetUtility 加载结果。")

	asset_utility.dispose()


func test_debug_snapshot_reports_registered_keys_and_providers() -> void:
	var _registered: bool = _register_path(&"icon", "res://icon.svg")
	var _provider_registered: bool = _register_provider(ResourceProvider.new(Resource.new()), &"memory", 1)

	var snapshot: Dictionary = _get_debug_snapshot()
	var keys: PackedStringArray = GFVariantData.get_option_packed_string_array(snapshot, "registered_keys")
	var providers: Array = GFVariantData.get_option_array(snapshot, "providers")

	assert_eq(GFVariantData.get_option_int(snapshot, "registered_key_count"), 1, "快照应报告注册键数量。")
	assert_true(keys.has("icon"), "快照应包含注册键。")
	assert_eq(GFVariantData.get_option_int(snapshot, "provider_count"), 1, "快照应报告 provider 数量。")
	assert_eq(providers.size(), 1, "快照应列出 provider。")


# --- 私有/辅助方法 ---

func _call_resolver(method_name: StringName, arguments: Array = []) -> Variant:
	return _resolver.callv(method_name, arguments)


func _register_path(
	resource_key: StringName,
	path: String,
	type_hint: String = "",
	priority: int = 0,
	metadata: Dictionary = {}
) -> bool:
	return GFVariantData.to_bool(_call_resolver("register_path", [resource_key, path, type_hint, priority, metadata]))


func _register_provider(provider: Object, provider_id: StringName = &"", priority: int = 0) -> bool:
	return GFVariantData.to_bool(_call_resolver("register_provider", [provider, provider_id, priority]))


func _resolve(resource_key: StringName, type_hint: String = "", options: Dictionary = {}) -> Dictionary:
	return GFVariantData.as_dictionary(_call_resolver("resolve", [resource_key, type_hint, options]))


func _load(resource_key: StringName, type_hint: String = "", options: Dictionary = {}) -> Resource:
	var loaded: Variant = _call_resolver("load", [resource_key, type_hint, ResourceLoader.CACHE_MODE_REUSE, options])
	if loaded is Resource:
		var resource: Resource = loaded
		return resource
	return null


func _make_asset_group_entries(resource_keys: PackedStringArray, type_hint: String = "") -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var raw_entries: Array = GFVariantData.as_array(_call_resolver("make_asset_group_entries", [resource_keys, type_hint]))
	for raw_entry: Variant in raw_entries:
		entries.append(GFVariantData.as_dictionary(raw_entry))
	return entries


func _get_debug_snapshot() -> Dictionary:
	return GFVariantData.as_dictionary(_call_resolver("get_debug_snapshot"))


# --- 内部类 ---

class PathProvider:
	extends RefCounted

	var path: String = ""
	var type_hint: String = ""
	var metadata: Dictionary = {}

	func _init(p_path: String, p_type_hint: String = "", p_metadata: Dictionary = {}) -> void:
		path = p_path
		type_hint = p_type_hint
		metadata = p_metadata.duplicate(true)

	func resolve_resource(_request: Dictionary) -> Dictionary:
		return {
			"path": path,
			"type_hint": type_hint,
			"metadata": metadata.duplicate(true),
		}


class ResourceProvider:
	extends RefCounted

	var resource: Resource = null

	func _init(p_resource: Resource) -> void:
		resource = p_resource

	func resolve_resource(request: Dictionary) -> Dictionary:
		var key: StringName = GFVariantData.get_option_string_name(request, "key")
		if key != &"memory":
			return {
				"ok": false,
				"reason": "not_found",
			}
		return {
			"resource": resource,
		}


class CompletingAssetUtility:
	extends GFAssetUtility

	var complete: bool = false
	var loaded_resource: Resource = Resource.new()
	var requested_paths: Array[String] = []

	func _request_threaded(path: String, _type_hint: String) -> Error:
		requested_paths.append(path)
		return OK

	func _get_threaded_status(_path: String) -> ResourceLoader.ThreadLoadStatus:
		return ResourceLoader.THREAD_LOAD_LOADED if complete else ResourceLoader.THREAD_LOAD_IN_PROGRESS

	func _take_threaded_resource(_path: String) -> Resource:
		return loaded_resource
