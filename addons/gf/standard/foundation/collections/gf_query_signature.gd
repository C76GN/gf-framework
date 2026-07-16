## GFQuerySignature: 域分离的通用查询签名。
##
## 用稳定的 domain/value 结构生成可缓存的查询 key，避免把不同语义域的条件简单合并后产生歧义。
## 它只负责签名构建，不规定查询含义或匹配规则。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 6.0.0
class_name GFQuerySignature
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_KEY_CODEC_SCRIPT = preload("res://addons/gf/standard/foundation/variant/gf_variant_key_codec.gd")


# --- 私有变量 ---

var _domains: Dictionary = {}


# --- 公共方法 ---

## 清空签名内容。
## [br]
## @api public
## [br]
## @since 6.0.0
func clear() -> void:
	_domains.clear()


## 添加单个域值。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param domain: 条件域，例如 all、any、none、group。
## [br]
## @param value: 条件值。
## [br]
## @schema value: Variant condition value accepted by GFVariantKeyCodec.
## [br]
## @return 当前签名，便于链式调用。
func add_value(domain: StringName, value: Variant) -> GFQuerySignature:
	if domain == &"" or not _GF_VARIANT_KEY_CODEC_SCRIPT.is_stable_key(value):
		return self

	var domain_key: String = String(domain)
	if not _domains.has(domain_key):
		_domains[domain_key] = {}
	var values: Dictionary = GFVariantData.as_dictionary(_domains[domain_key])
	values[_make_value_key(value)] = true
	return self


## 添加一组域值。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param domain: 条件域。
## [br]
## @param values: 条件值集合。
## [br]
## @schema values: Variant accepted as Array, Dictionary keys, PackedStringArray, PackedInt32Array, PackedInt64Array, PackedFloat32Array, PackedFloat64Array, or scalar value.
## [br]
## @return 当前签名，便于链式调用。
func add_values(domain: StringName, values: Variant) -> GFQuerySignature:
	for value: Variant in _extract_values(values):
		var _signature: GFQuerySignature = add_value(domain, value)
	return self


## 添加布尔标记域。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param domain: 条件域。
## [br]
## @param enabled: 标记值。
## [br]
## @return 当前签名，便于链式调用。
func add_flag(domain: StringName, enabled: bool) -> GFQuerySignature:
	return add_value(domain, enabled)


## 检查域是否存在。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param domain: 条件域。
## [br]
## @return 存在返回 true。
func has_domain(domain: StringName) -> bool:
	return _domains.has(String(domain))


## 获取域内规范化值列表。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param domain: 条件域。
## [br]
## @return 已排序的规范化值列表。
func get_domain_values(domain: StringName) -> PackedStringArray:
	var values: PackedStringArray = PackedStringArray()
	var domain_values: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(_domains, String(domain), {}))
	for value_key: String in domain_values.keys():
		var _value_appended: bool = values.append(value_key)
	values.sort()
	return values


## 导出为稳定字典。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 签名字典。
## [br]
## @schema return: Dictionary mapping domain names to sorted PackedStringArray encoded values.
func to_dictionary() -> Dictionary:
	var result: Dictionary = {}
	for domain_key: String in _get_sorted_domain_keys():
		result[domain_key] = get_domain_values(StringName(domain_key))
	return result


## 导出为稳定文本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 可作为缓存 key 的签名文本。
func to_text() -> String:
	var domain_keys: PackedStringArray = _get_sorted_domain_keys()
	var result: String = "gfq1:%d:" % domain_keys.size()
	for domain_key: String in domain_keys:
		var values: PackedStringArray = get_domain_values(StringName(domain_key))
		result += "%d:%s%d:" % [domain_key.length(), domain_key, values.size()]
		for encoded_value: String in values:
			result += "%d:%s" % [encoded_value.length(), encoded_value]
	return result


## 获取签名 hash。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 基于 to_text() 的运行时 hash。
func to_hash() -> int:
	return to_text().hash()


## 从域字典创建签名。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param domains: 域到值集合的字典。
## [br]
## @schema domains: Dictionary mapping domain names to value collections.
## [br]
## @return 新签名。
static func from_dictionary(domains: Dictionary) -> GFQuerySignature:
	var signature: GFQuerySignature = GFQuerySignature.new()
	for domain_variant: Variant in domains.keys():
		var domain: StringName = GFVariantData.to_string_name(domain_variant)
		var _restored: GFQuerySignature = signature._set_encoded_values(domain, domains[domain_variant])
	return signature


# --- 私有/辅助方法 ---

func _get_sorted_domain_keys() -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for domain_key: String in _domains.keys():
		var _key_appended: bool = keys.append(domain_key)
	keys.sort()
	return keys


func _extract_values(values: Variant) -> Array:
	var result: Array = []
	if values == null:
		return result
	if values is Dictionary:
		var dictionary: Dictionary = values
		for key: Variant in dictionary.keys():
			result.append(key)
	elif values is Array:
		var array: Array = values
		for item: Variant in array:
			if item != null:
				result.append(item)
	elif values is PackedStringArray:
		var packed_strings: PackedStringArray = values
		for item: String in packed_strings:
			result.append(item)
	elif values is PackedInt32Array:
		var packed_ints: PackedInt32Array = values
		for item: int in packed_ints:
			result.append(item)
	elif values is PackedInt64Array:
		var packed_int64s: PackedInt64Array = values
		for item: int in packed_int64s:
			result.append(item)
	elif values is PackedFloat32Array:
		var packed_floats: PackedFloat32Array = values
		for item: float in packed_floats:
			result.append(item)
	elif values is PackedFloat64Array:
		var packed_float64s: PackedFloat64Array = values
		for item: float in packed_float64s:
			result.append(item)
	else:
		result.append(values)
	return result


func _make_value_key(value: Variant) -> String:
	return _GF_VARIANT_KEY_CODEC_SCRIPT.make_key_token(value)


func _set_encoded_values(domain: StringName, values: Variant) -> GFQuerySignature:
	if domain == &"":
		return self

	var encoded_values: PackedStringArray = _extract_encoded_value_keys(values)
	if encoded_values.is_empty():
		return self

	var domain_key: String = String(domain)
	if not _domains.has(domain_key):
		_domains[domain_key] = {}
	var domain_values: Dictionary = GFVariantData.as_dictionary(_domains[domain_key])
	for encoded_value: String in encoded_values:
		if _is_encoded_value_key(encoded_value):
			domain_values[encoded_value] = true
	return self


static func _extract_encoded_value_keys(values: Variant) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if values is PackedStringArray:
		var packed_strings: PackedStringArray = values
		for item: String in packed_strings:
			var _append_packed_result: bool = result.append(item)
	elif values is Array:
		var array: Array = values
		for item: Variant in array:
			if item is String:
				var text: String = item
				var _append_array_result: bool = result.append(text)
	elif values is Dictionary:
		var dictionary: Dictionary = values
		for key: Variant in dictionary.keys():
			if key is String:
				var key_text: String = key
				var _append_key_result: bool = result.append(key_text)
	result.sort()
	return result


static func _is_encoded_value_key(value_key: String) -> bool:
	return value_key.begins_with("gfv1:") and value_key.length() > "gfv1:".length()
