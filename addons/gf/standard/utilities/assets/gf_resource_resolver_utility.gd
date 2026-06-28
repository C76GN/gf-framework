## GFResourceResolverUtility: 通用资源键解析工具。
##
## 将项目稳定资源键解析为路径或已加载 Resource，并支持显式注册表、provider 覆盖链和显式直接路径回退。
## 它不扫描目录、不下载资源、不解释业务内容类型，也不负责实例化节点。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.4.0
class_name GFResourceResolverUtility
extends GFUtility


# --- 常量 ---

## provider 协议方法名。
## [br]
## @api public
const PROVIDER_METHOD: StringName = &"resolve_resource"


const _DEFAULT_PROVIDER_ID: StringName = &"registered"
const _DIRECT_PROVIDER_ID: StringName = &"direct_path"
const _REASON_INVALID_KEY: String = "invalid_key"
const _REASON_NOT_FOUND: String = "not_found"
const _REASON_MISSING_RESOURCE: String = "missing_resource"
const _REASON_INCOMPATIBLE_RESOURCE: String = "incompatible_resource"
const _REASON_PROVIDER_ERROR: String = "provider_error"


# --- 私有变量 ---

var _path_records: Dictionary = {}
var _providers: Array[Dictionary] = []
var _registration_order: int = 0


# --- GF 生命周期方法 ---

## 初始化解析器运行时状态。
## [br]
## @api public
func init() -> void:
	_path_records.clear()
	_providers.clear()
	_registration_order = 0


## 释放解析器运行时状态。
## [br]
## @api public
func dispose() -> void:
	_path_records.clear()
	_providers.clear()
	_registration_order = 0


# --- 公共方法 ---

## 注册一个资源键到资源路径的显式映射。
## [br]
## @api public
## [br]
## @param resource_key: 稳定资源键。
## [br]
## @param path: Godot 资源路径，通常为 `res://` 或 `uid://`。
## [br]
## @param type_hint: 可选 ResourceLoader 类型提示。
## [br]
## @param priority: 覆盖优先级；数值越大越优先。
## [br]
## @param metadata: 项目自定义元数据，会复制到解析报告。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema metadata: Dictionary project-defined metadata copied into resolution reports.
func register_path(
	resource_key: StringName,
	path: String,
	type_hint: String = "",
	priority: int = 0,
	metadata: Dictionary = {}
) -> bool:
	if resource_key == &"" or path.strip_edges().is_empty():
		return false

	_registration_order += 1
	_path_records[resource_key] = {
		"key": resource_key,
		"path": path.strip_edges(),
		"type_hint": type_hint.strip_edges(),
		"priority": priority,
		"order": _registration_order,
		"provider_id": _DEFAULT_PROVIDER_ID,
		"metadata": metadata.duplicate(true),
	}
	return true


## 注销显式路径映射。
## [br]
## @api public
## [br]
## @param resource_key: 稳定资源键。
## [br]
## @return 成功移除返回 true。
func unregister_path(resource_key: StringName) -> bool:
	return _path_records.erase(resource_key)


## 清空所有显式路径映射。
## [br]
## @api public
func clear_paths() -> void:
	_path_records.clear()


## 注册一个资源解析 provider。
## [br]
## provider 应实现 `resolve_resource(request: Dictionary) -> Variant`。返回值可为 Dictionary、String 路径或 Resource。
## Dictionary 可包含 `ok`、`path`、`resource`、`type_hint`、`reason`、`metadata` 和 `provider_id`。
## [br]
## @api public
## [br]
## @param provider: provider 对象。
## [br]
## @param provider_id: provider 标识；为空时使用对象类名或实例 ID。
## [br]
## @param priority: 覆盖优先级；数值越大越优先。
## [br]
## @return 注册成功返回 true。
func register_provider(provider: Object, provider_id: StringName = &"", priority: int = 0) -> bool:
	if provider == null or not provider.has_method(PROVIDER_METHOD):
		return false
	if _find_provider_index(provider) != -1:
		return false

	_registration_order += 1
	_providers.append({
		"provider": provider,
		"provider_id": _resolve_provider_id(provider, provider_id),
		"priority": priority,
		"order": _registration_order,
	})
	return true


## 注销资源解析 provider。
## [br]
## @api public
## [br]
## @param provider: provider 对象。
## [br]
## @return 成功移除返回 true。
func unregister_provider(provider: Object) -> bool:
	var index: int = _find_provider_index(provider)
	if index == -1:
		return false
	_providers.remove_at(index)
	return true


## 清空所有 provider。
## [br]
## @api public
func clear_providers() -> void:
	_providers.clear()


## 检查显式路径映射是否存在。
## [br]
## @api public
## [br]
## @param resource_key: 稳定资源键。
## [br]
## @return 存在显式映射时返回 true。
func has_registered_key(resource_key: StringName) -> bool:
	return _path_records.has(resource_key)


## 获取已注册的显式资源键。
## [br]
## @api public
## [br]
## @return 排序后的资源键列表。
func get_registered_keys() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key_value: Variant in _path_records.keys():
		var key: StringName = GFVariantData.to_string_name(key_value)
		var _appended: bool = result.append(String(key))
	result.sort()
	return result


## 解析资源键。
## [br]
## @api public
## [br]
## @param resource_key: 稳定资源键；启用直接路径回退时也可传 `res://`、`uid://` 或 `user://` 路径。
## [br]
## @param type_hint_override: 可选 ResourceLoader 类型提示覆盖。
## [br]
## @param options: 可选参数。`check_exists` 默认为 true；`allow_direct_path` 默认为 false。
## [br]
## @return 解析报告。
## [br]
## @schema options: Dictionary with optional `check_exists: bool` and `allow_direct_path: bool`.
## [br]
## @schema return: Dictionary with `ok`, `key`, `path`, `type_hint`, `provider_id`, `reason`, `metadata`, and optional `resource`.
func resolve(
	resource_key: StringName,
	type_hint_override: String = "",
	options: Dictionary = {}
) -> Dictionary:
	if resource_key == &"":
		return _make_failure(resource_key, type_hint_override, _REASON_INVALID_KEY)

	var request: Dictionary = _make_request(resource_key, type_hint_override, options)
	var candidates: Array[Dictionary] = _collect_candidates(request)
	var best_failure: Dictionary = {}
	for candidate: Dictionary in candidates:
		var validated: Dictionary = _validate_candidate(candidate, request)
		if GFVariantData.get_option_bool(validated, "ok"):
			return validated
		if best_failure.is_empty():
			best_failure = validated

	if not best_failure.is_empty():
		return best_failure
	return _make_failure(resource_key, type_hint_override, _REASON_NOT_FOUND)


## 解析资源键并返回路径。
## [br]
## @api public
## [br]
## @param resource_key: 稳定资源键。
## [br]
## @param type_hint_override: 可选 ResourceLoader 类型提示覆盖。
## [br]
## @param options: 可选参数，见 `resolve()`。
## [br]
## @return 解析成功且结果包含路径时返回路径，否则返回空字符串。
## [br]
## @schema options: Dictionary with optional `check_exists: bool` and `allow_direct_path: bool`.
func resolve_path(
	resource_key: StringName,
	type_hint_override: String = "",
	options: Dictionary = {}
) -> String:
	var report: Dictionary = resolve(resource_key, type_hint_override, options)
	if not GFVariantData.get_option_bool(report, "ok"):
		return ""
	return GFVariantData.get_option_string(report, "path")


## 同步加载解析结果。
## [br]
## @api public
## [br]
## @param resource_key: 稳定资源键。
## [br]
## @param type_hint_override: 可选 ResourceLoader 类型提示覆盖。
## [br]
## @param cache_mode: ResourceLoader 缓存模式。
## [br]
## @param options: 可选参数，见 `resolve()`。
## [br]
## @return 加载到的 Resource；解析或加载失败时返回 null。
## [br]
## @schema options: Dictionary with optional `check_exists: bool` and `allow_direct_path: bool`.
func load(
	resource_key: StringName,
	type_hint_override: String = "",
	cache_mode: int = ResourceLoader.CACHE_MODE_REUSE,
	options: Dictionary = {}
) -> Resource:
	var report: Dictionary = resolve(resource_key, type_hint_override, options)
	if not GFVariantData.get_option_bool(report, "ok"):
		return null

	var provided_resource: Resource = _get_report_resource(report)
	if provided_resource != null:
		return provided_resource

	var path: String = GFVariantData.get_option_string(report, "path")
	if path.is_empty():
		return null
	return ResourceLoader.load(path, GFVariantData.get_option_string(report, "type_hint"), cache_mode)


## 通过 GFAssetUtility 异步加载解析结果。
## [br]
## @api public
## [br]
## @param asset_utility: 资源加载工具。
## [br]
## @param resource_key: 稳定资源键。
## [br]
## @param on_loaded: 加载完成回调，签名为 func(resource: Resource)。
## [br]
## @param type_hint_override: 可选 ResourceLoader 类型提示覆盖。
## [br]
## @param options: 可选参数，见 `resolve()`。
## [br]
## @schema options: Dictionary with optional `check_exists: bool` and `allow_direct_path: bool`.
func load_async(
	asset_utility: GFAssetUtility,
	resource_key: StringName,
	on_loaded: Callable,
	type_hint_override: String = "",
	options: Dictionary = {}
) -> void:
	if asset_utility == null or not on_loaded.is_valid():
		push_error("[GFResourceResolverUtility] load_async 失败：asset_utility 或 on_loaded 无效。")
		if on_loaded.is_valid():
			on_loaded.call(null)
		return

	var report: Dictionary = resolve(resource_key, type_hint_override, options)
	if not GFVariantData.get_option_bool(report, "ok"):
		on_loaded.call(null)
		return

	var provided_resource: Resource = _get_report_resource(report)
	if provided_resource != null:
		on_loaded.call(provided_resource)
		return

	var path: String = GFVariantData.get_option_string(report, "path")
	if path.is_empty():
		on_loaded.call(null)
		return
	asset_utility.load_async(path, on_loaded, GFVariantData.get_option_string(report, "type_hint"))


## 构建可传给 GFAssetUtility.preload_group_async() 的资源请求列表。
## [br]
## @api public
## [br]
## @param resource_keys: 资源键列表。
## [br]
## @param type_hint_override: 可选 ResourceLoader 类型提示覆盖。
## [br]
## @param options: 可选参数，见 `resolve()`。
## [br]
## @return 资源请求列表。
## [br]
## @schema resource_keys: PackedStringArray selected resource keys.
## [br]
## @schema options: Dictionary with optional `check_exists: bool` and `allow_direct_path: bool`.
## [br]
## @schema return: Array[Dictionary] where each item contains `path` and `type_hint`.
func make_asset_group_entries(
	resource_keys: PackedStringArray,
	type_hint_override: String = "",
	options: Dictionary = {}
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key_text: String in resource_keys:
		var report: Dictionary = resolve(StringName(key_text), type_hint_override, options)
		if not GFVariantData.get_option_bool(report, "ok"):
			continue
		var path: String = GFVariantData.get_option_string(report, "path")
		if path.is_empty():
			continue
		result.append({
			"path": path,
			"type_hint": GFVariantData.get_option_string(report, "type_hint"),
		})
	return result


## 获取解析器诊断快照。
## [br]
## @api public
## [br]
## @return 诊断信息。
## [br]
## @schema return: Dictionary with `registered_key_count`, `registered_keys`, `provider_count`, and `providers`.
func get_debug_snapshot() -> Dictionary:
	_prune_invalid_providers()
	var providers: Array[Dictionary] = []
	for provider_record: Dictionary in _providers:
		providers.append({
			"provider_id": _get_record_provider_id(provider_record),
			"priority": _get_record_priority(provider_record),
		})
	return {
		"registered_key_count": _path_records.size(),
		"registered_keys": get_registered_keys(),
		"provider_count": _providers.size(),
		"providers": providers,
	}


# --- 私有/辅助方法 ---

func _make_request(resource_key: StringName, type_hint_override: String, options: Dictionary) -> Dictionary:
	return {
		"key": resource_key,
		"key_text": String(resource_key),
		"type_hint": type_hint_override.strip_edges(),
		"options": options.duplicate(true),
	}


func _collect_candidates(request: Dictionary) -> Array[Dictionary]:
	_prune_invalid_providers()
	var candidates: Array[Dictionary] = []
	var key: StringName = GFVariantData.get_option_string_name(request, "key")
	if _path_records.has(key):
		candidates.append(_normalize_record_candidate(_get_path_record(key)))

	for provider_record: Dictionary in _providers:
		var provider: Object = _get_record_provider(provider_record)
		if provider == null or not is_instance_valid(provider) or not provider.has_method(PROVIDER_METHOD):
			continue
		var provider_result: Variant = provider.call(PROVIDER_METHOD, request.duplicate(true))
		candidates.append(_normalize_provider_candidate(provider_result, provider_record))

	if _allow_direct_path(request):
		var key_text: String = GFVariantData.get_option_string(request, "key_text")
		if _is_resource_path(key_text):
			candidates.append({
				"ok": true,
				"key": key,
				"path": key_text,
				"type_hint": GFVariantData.get_option_string(request, "type_hint"),
				"resource": null,
				"provider_id": _DIRECT_PROVIDER_ID,
				"priority": -1000000,
				"order": -1000000,
				"reason": "",
				"metadata": {},
			})

	candidates.sort_custom(_sort_candidates)
	return candidates


func _normalize_record_candidate(record: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"key": GFVariantData.get_option_string_name(record, "key"),
		"path": GFVariantData.get_option_string(record, "path"),
		"type_hint": GFVariantData.get_option_string(record, "type_hint"),
		"resource": null,
		"provider_id": _get_record_provider_id(record),
		"priority": _get_record_priority(record),
		"order": _get_record_order(record),
		"reason": "",
		"metadata": GFVariantData.get_option_dictionary(record, "metadata"),
	}


func _normalize_provider_candidate(provider_result: Variant, provider_record: Dictionary) -> Dictionary:
	var provider_id: StringName = _get_record_provider_id(provider_record)
	if provider_result is Resource:
		var provided_resource: Resource = provider_result
		return _make_resource_candidate(provided_resource, provider_record, {})
	if provider_result is String:
		return _make_path_candidate(GFVariantData.to_text(provider_result), provider_record, {})
	if provider_result is StringName:
		return _make_path_candidate(GFVariantData.to_text(provider_result), provider_record, {})
	if not provider_result is Dictionary:
		return _make_provider_failure(provider_id, provider_record, _REASON_PROVIDER_ERROR)

	var data: Dictionary = GFVariantData.as_dictionary(provider_result)
	if not GFVariantData.get_option_bool(data, "ok", true):
		return _make_provider_failure(
			GFVariantData.get_option_string_name(data, "provider_id", provider_id),
			provider_record,
			GFVariantData.get_option_string(data, "reason", _REASON_PROVIDER_ERROR),
			GFVariantData.get_option_dictionary(data, "metadata")
		)

	var report_resource: Resource = _get_report_resource(data)
	if report_resource != null:
		return _make_resource_candidate(report_resource, provider_record, data)

	return _make_path_candidate(
		GFVariantData.get_option_string(data, "path", GFVariantData.get_option_string(data, "resource_path")),
		provider_record,
		data
	)


func _make_resource_candidate(resource: Resource, provider_record: Dictionary, data: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"key": &"",
		"path": GFVariantData.get_option_string(data, "path", resource.resource_path),
		"type_hint": GFVariantData.get_option_string(data, "type_hint"),
		"resource": resource,
		"provider_id": GFVariantData.get_option_string_name(data, "provider_id", _get_record_provider_id(provider_record)),
		"priority": _get_record_priority(provider_record),
		"order": _get_record_order(provider_record),
		"reason": "",
		"metadata": GFVariantData.get_option_dictionary(data, "metadata"),
	}


func _make_path_candidate(path: String, provider_record: Dictionary, data: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"key": &"",
		"path": path.strip_edges(),
		"type_hint": GFVariantData.get_option_string(data, "type_hint"),
		"resource": null,
		"provider_id": GFVariantData.get_option_string_name(data, "provider_id", _get_record_provider_id(provider_record)),
		"priority": _get_record_priority(provider_record),
		"order": _get_record_order(provider_record),
		"reason": "",
		"metadata": GFVariantData.get_option_dictionary(data, "metadata"),
	}


func _make_provider_failure(
	provider_id: StringName,
	provider_record: Dictionary,
	reason: String,
	metadata: Dictionary = {}
) -> Dictionary:
	return {
		"ok": false,
		"key": &"",
		"path": "",
		"type_hint": "",
		"resource": null,
		"provider_id": provider_id,
		"priority": _get_record_priority(provider_record),
		"order": _get_record_order(provider_record),
		"reason": reason,
		"metadata": metadata.duplicate(true),
	}


func _validate_candidate(candidate: Dictionary, request: Dictionary) -> Dictionary:
	var report: Dictionary = candidate.duplicate(true)
	var key: StringName = GFVariantData.get_option_string_name(request, "key")
	report["key"] = key

	var requested_type_hint: String = GFVariantData.get_option_string(request, "type_hint")
	var candidate_type_hint: String = GFVariantData.get_option_string(report, "type_hint")
	if not requested_type_hint.is_empty():
		report["type_hint"] = requested_type_hint
	elif candidate_type_hint.is_empty():
		report["type_hint"] = ""

	var resource: Resource = _get_report_resource(report)
	if resource != null:
		if _is_resource_compatible(resource, GFVariantData.get_option_string(report, "type_hint")):
			report["ok"] = true
			report["reason"] = ""
			return report
		report["ok"] = false
		report["reason"] = _REASON_INCOMPATIBLE_RESOURCE
		return report

	var path: String = GFVariantData.get_option_string(report, "path").strip_edges()
	report["path"] = path
	if path.is_empty():
		report["ok"] = false
		if GFVariantData.get_option_string(report, "reason").is_empty():
			report["reason"] = _REASON_NOT_FOUND
		return report

	if _should_check_exists(request) and not ResourceLoader.exists(path, GFVariantData.get_option_string(report, "type_hint")):
		report["ok"] = false
		report["reason"] = _REASON_MISSING_RESOURCE
		return report

	report["ok"] = true
	report["reason"] = ""
	return report


func _make_failure(resource_key: StringName, type_hint: String, reason: String) -> Dictionary:
	return {
		"ok": false,
		"key": resource_key,
		"path": "",
		"type_hint": type_hint.strip_edges(),
		"resource": null,
		"provider_id": &"",
		"reason": reason,
		"metadata": {},
	}


func _get_path_record(resource_key: StringName) -> Dictionary:
	return GFVariantData.get_option_dictionary(_path_records, resource_key)


func _get_record_provider(record: Dictionary) -> Object:
	var provider_value: Variant = GFVariantData.get_option_value(record, "provider")
	if typeof(provider_value) == TYPE_OBJECT and is_instance_valid(provider_value):
		var provider: Object = provider_value
		return provider
	return null


func _get_record_provider_id(record: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(record, "provider_id")


func _get_record_priority(record: Dictionary) -> int:
	return GFVariantData.get_option_int(record, "priority")


func _get_record_order(record: Dictionary) -> int:
	return GFVariantData.get_option_int(record, "order")


func _get_report_resource(report: Dictionary) -> Resource:
	var resource_value: Variant = GFVariantData.get_option_value(report, "resource")
	if resource_value is Resource:
		var resource: Resource = resource_value
		return resource
	return null


func _find_provider_index(provider: Object) -> int:
	if provider == null:
		return -1
	for index: int in range(_providers.size()):
		var registered_provider: Object = _get_record_provider(_providers[index])
		if registered_provider == provider:
			return index
	return -1


func _prune_invalid_providers() -> void:
	for index: int in range(_providers.size() - 1, -1, -1):
		var provider: Object = _get_record_provider(_providers[index])
		if provider == null or not is_instance_valid(provider) or not provider.has_method(PROVIDER_METHOD):
			_providers.remove_at(index)


func _resolve_provider_id(provider: Object, provider_id: StringName) -> StringName:
	if provider_id != &"":
		return provider_id
	var script_value: Variant = provider.get_script()
	if script_value is Script:
		var script: Script = script_value
		var global_name: String = GFVariantData.to_text(script.get_global_name())
		if not global_name.is_empty():
			return StringName(global_name)
	return StringName("%s:%d" % [provider.get_class(), provider.get_instance_id()])


func _allow_direct_path(request: Dictionary) -> bool:
	var options: Dictionary = GFVariantData.get_option_dictionary(request, "options")
	return GFVariantData.get_option_bool(options, "allow_direct_path", false)


func _should_check_exists(request: Dictionary) -> bool:
	var options: Dictionary = GFVariantData.get_option_dictionary(request, "options")
	return GFVariantData.get_option_bool(options, "check_exists", true)


func _is_resource_path(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("uid://") or path.begins_with("user://")


func _is_resource_compatible(resource: Resource, type_hint: String) -> bool:
	if resource == null:
		return false
	if type_hint.is_empty() or resource.is_class(type_hint):
		return true

	var script: Script = _get_script_value(resource.get_script())
	while script != null:
		if GFVariantData.to_text(script.get_global_name()) == type_hint or script.resource_path == type_hint:
			return true
		script = script.get_base_script()
	return false


func _get_script_value(script_value: Variant) -> Script:
	if script_value is Script:
		var script: Script = script_value
		return script
	return null


static func _sort_candidates(left: Dictionary, right: Dictionary) -> bool:
	var left_priority: int = GFVariantData.get_option_int(left, "priority")
	var right_priority: int = GFVariantData.get_option_int(right, "priority")
	if left_priority != right_priority:
		return left_priority > right_priority
	return GFVariantData.get_option_int(left, "order") > GFVariantData.get_option_int(right, "order")
