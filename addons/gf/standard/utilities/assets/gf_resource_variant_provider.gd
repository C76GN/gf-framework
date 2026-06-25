## GFResourceVariantProvider: 资源键变体解析 provider。
##
## 为 GFResourceResolverUtility 提供按变体键选择资源路径的通用 provider。变体键可以表示语言、
## 平台、皮肤、质量档位或项目自定义域；本类只处理优先级和回退，不解释变体业务含义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
class_name GFResourceVariantProvider
extends RefCounted


# --- 常量 ---

## 默认变体键。注册为空变体时可作为最后回退。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEFAULT_VARIANT_KEY: StringName = &"default"


const _REASON_NOT_FOUND: String = "not_found"
const _REASON_INVALID_KEY: String = "invalid_key"


# --- 私有变量 ---

var _records_by_key: Dictionary = {}
var _default_variant_order: PackedStringArray = PackedStringArray()
var _registration_order: int = 0


# --- 公共方法 ---

## 清空全部变体注册。
## [br]
## @api public
## [br]
## @since 6.0.0
func clear() -> void:
	_records_by_key.clear()
	_default_variant_order.clear()
	_registration_order = 0


## 设置默认变体回退顺序。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param variant_keys: 变体键列表，越靠前越优先。
func set_default_variant_order(variant_keys: PackedStringArray) -> void:
	_default_variant_order = _normalize_variant_keys(variant_keys, true)


## 获取默认变体回退顺序副本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 变体键列表。
func get_default_variant_order() -> PackedStringArray:
	return _default_variant_order.duplicate()


## 注册资源键的某个变体路径。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param resource_key: 稳定资源键。
## [br]
## @param variant_key: 变体键；为空时归一为 default。
## [br]
## @param path: Godot 资源路径。
## [br]
## @param type_hint: 可选 ResourceLoader 类型提示。
## [br]
## @param priority: 同一资源键和变体键重复注册时，数值越大越优先。
## [br]
## @param metadata: 调用方自定义元数据。
## [br]
## @return 注册成功返回 true。
## [br]
## @schema metadata: Dictionary project-defined metadata copied into resolution reports.
func register_variant(
	resource_key: StringName,
	variant_key: StringName,
	path: String,
	type_hint: String = "",
	priority: int = 0,
	metadata: Dictionary = {}
) -> bool:
	if resource_key == &"" or path.strip_edges().is_empty():
		return false

	var normalized_variant: StringName = _normalize_variant_key(variant_key)
	_registration_order += 1
	var record: Dictionary = {
		"key": resource_key,
		"variant_key": normalized_variant,
		"path": path.strip_edges(),
		"type_hint": type_hint.strip_edges(),
		"priority": priority,
		"order": _registration_order,
		"metadata": metadata.duplicate(true),
	}
	var variants: Dictionary = _get_or_create_variant_records(resource_key)
	var existing_value: Variant = GFVariantData.get_option_value(variants, normalized_variant)
	if existing_value is Dictionary:
		var existing_record: Dictionary = existing_value
		if _record_is_higher_priority(existing_record, record):
			return false
	variants[normalized_variant] = record
	return true


## 注销资源键的某个变体。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param resource_key: 稳定资源键。
## [br]
## @param variant_key: 变体键；为空时归一为 default。
## [br]
## @return 成功移除返回 true。
func unregister_variant(resource_key: StringName, variant_key: StringName) -> bool:
	if not _records_by_key.has(resource_key):
		return false
	var variants: Dictionary = GFVariantData.as_dictionary(_records_by_key[resource_key])
	var removed: bool = variants.erase(_normalize_variant_key(variant_key))
	if variants.is_empty():
		var _removed_key: bool = _records_by_key.erase(resource_key)
	return removed


## 检查资源键是否有指定变体。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param resource_key: 稳定资源键。
## [br]
## @param variant_key: 变体键；为空时归一为 default。
## [br]
## @return 存在返回 true。
func has_variant(resource_key: StringName, variant_key: StringName) -> bool:
	if not _records_by_key.has(resource_key):
		return false
	var variants: Dictionary = GFVariantData.as_dictionary(_records_by_key[resource_key])
	return variants.has(_normalize_variant_key(variant_key))


## 获取资源键已注册的变体键。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param resource_key: 稳定资源键。
## [br]
## @return 排序后的变体键列表。
func get_variant_keys(resource_key: StringName) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not _records_by_key.has(resource_key):
		return result
	var variants: Dictionary = GFVariantData.as_dictionary(_records_by_key[resource_key])
	for variant_value: Variant in variants.keys():
		var variant_text: String = String(GFVariantData.to_string_name(variant_value))
		if not variant_text.is_empty():
			var _appended: bool = result.append(variant_text)
	result.sort()
	return result


## GFResourceResolverUtility provider 协议入口。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param request: 资源解析请求。
## [br]
## @return provider 解析报告。
## [br]
## @schema request: Dictionary from GFResourceResolverUtility containing key, type_hint, and options.
## [br]
## @schema return: Dictionary with ok, path, type_hint, provider_id, reason, and metadata.
func resolve_resource(request: Dictionary) -> Dictionary:
	var resource_key: StringName = GFVariantData.get_option_string_name(request, "key")
	if resource_key == &"":
		return _make_failure(_REASON_INVALID_KEY, resource_key, &"")
	if not _records_by_key.has(resource_key):
		return _make_failure(_REASON_NOT_FOUND, resource_key, &"")

	var variants: Dictionary = GFVariantData.as_dictionary(_records_by_key[resource_key])
	for variant_key: StringName in _make_request_variant_order(request):
		var record_value: Variant = GFVariantData.get_option_value(variants, variant_key)
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		return _make_success(record)
	return _make_failure(_REASON_NOT_FOUND, resource_key, &"")


## 获取诊断快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 诊断快照。
## [br]
## @schema return: Dictionary with resource_key_count, variant_count, default_variant_order, and keys.
func get_debug_snapshot() -> Dictionary:
	var variant_count: int = 0
	var keys: PackedStringArray = PackedStringArray()
	for key_value: Variant in _records_by_key.keys():
		var key: StringName = GFVariantData.to_string_name(key_value)
		var _key_appended: bool = keys.append(String(key))
		var variants: Dictionary = GFVariantData.as_dictionary(_records_by_key[key])
		variant_count += variants.size()
	keys.sort()
	return {
		"resource_key_count": _records_by_key.size(),
		"variant_count": variant_count,
		"default_variant_order": _default_variant_order.duplicate(),
		"keys": keys,
	}


# --- 私有/辅助方法 ---

func _get_or_create_variant_records(resource_key: StringName) -> Dictionary:
	if _records_by_key.has(resource_key):
		return GFVariantData.as_dictionary(_records_by_key[resource_key])
	var variants: Dictionary = {}
	_records_by_key[resource_key] = variants
	return variants


func _make_request_variant_order(request: Dictionary) -> Array[StringName]:
	var options: Dictionary = GFVariantData.get_option_dictionary(request, "options")
	var requested: PackedStringArray = _extract_variant_order(options)
	if requested.is_empty():
		requested = _default_variant_order.duplicate()
	requested = _normalize_variant_keys(requested, true)

	var result: Array[StringName] = []
	for variant_text: String in requested:
		var variant_key: StringName = _normalize_variant_key(StringName(variant_text))
		if not result.has(variant_key):
			result.append(variant_key)
	if not result.has(DEFAULT_VARIANT_KEY):
		result.append(DEFAULT_VARIANT_KEY)
	return result


func _extract_variant_order(options: Dictionary) -> PackedStringArray:
	var value: Variant = GFVariantData.get_option_value(
		options,
		"variant_keys",
		GFVariantData.get_option_value(options, "variants", PackedStringArray())
	)
	return _variant_value_to_packed_string_array(value)


func _variant_value_to_packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	var result: PackedStringArray = PackedStringArray()
	if value is Array:
		var values: Array = value
		for item: Variant in values:
			var text: String = GFVariantData.to_text(item).strip_edges()
			if not text.is_empty() and not result.has(text):
				var _appended: bool = result.append(text)
	elif value is String or value is StringName:
		var text: String = GFVariantData.to_text(value).strip_edges()
		if not text.is_empty():
			var _appended_single: bool = result.append(text)
	return result


func _normalize_variant_keys(variant_keys: PackedStringArray, include_default: bool) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for variant_text: String in variant_keys:
		var normalized: String = String(_normalize_variant_key(StringName(variant_text)))
		if normalized.is_empty() or result.has(normalized):
			continue
		var _appended: bool = result.append(normalized)
	if include_default and not result.has(String(DEFAULT_VARIANT_KEY)):
		var _default_appended: bool = result.append(String(DEFAULT_VARIANT_KEY))
	return result


func _normalize_variant_key(variant_key: StringName) -> StringName:
	var text: String = String(variant_key).strip_edges()
	if text.is_empty():
		return DEFAULT_VARIANT_KEY
	return StringName(text)


func _record_is_higher_priority(left: Dictionary, right: Dictionary) -> bool:
	var left_priority: int = GFVariantData.get_option_int(left, "priority")
	var right_priority: int = GFVariantData.get_option_int(right, "priority")
	if left_priority != right_priority:
		return left_priority > right_priority
	return GFVariantData.get_option_int(left, "order") > GFVariantData.get_option_int(right, "order")


func _make_success(record: Dictionary) -> Dictionary:
	var metadata: Dictionary = GFVariantData.get_option_dictionary(record, "metadata")
	metadata["variant_key"] = GFVariantData.get_option_string_name(record, "variant_key")
	return {
		"ok": true,
		"path": GFVariantData.get_option_string(record, "path"),
		"type_hint": GFVariantData.get_option_string(record, "type_hint"),
		"provider_id": &"variant",
		"reason": "",
		"metadata": metadata,
	}


func _make_failure(reason: String, resource_key: StringName, variant_key: StringName) -> Dictionary:
	return {
		"ok": false,
		"path": "",
		"type_hint": "",
		"provider_id": &"variant",
		"reason": reason,
		"metadata": {
			"resource_key": resource_key,
			"variant_key": variant_key,
		},
	}
