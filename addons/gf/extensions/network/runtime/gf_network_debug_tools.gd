## GFNetworkDebugTools: Network 扩展内部调试快照脱敏工具。
##
## 统一处理 endpoint、token、secret、auth 等字段，避免各公开快照入口规则漂移。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 7.0.0
class_name GFNetworkDebugTools
extends RefCounted


# --- 框架内部方法 ---

## 脱敏调试字典。
## [br]
## @api framework_internal
## [br]
## @param source: 原始调试字典。
## [br]
## @return: 脱敏后的调试字典。
## [br]
## @schema source: Dictionary containing debug data.
## [br]
## @schema return: Dictionary with sensitive values redacted.
static func sanitize_debug_dictionary(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_variant: Variant in source.keys():
		var key_text: String = GFVariantData.to_text(key_variant)
		result[key_variant] = sanitize_debug_value(key_text, source[key_variant])
	return result


## 脱敏调试数组。
## [br]
## @api framework_internal
## [br]
## @param source: 原始调试数组。
## [br]
## @return: 脱敏后的调试数组。
## [br]
## @schema source: Array containing debug data.
## [br]
## @schema return: Array with sensitive values redacted.
static func sanitize_debug_array(source: Array) -> Array:
	var result: Array = []
	for value: Variant in source:
		result.append(sanitize_debug_value("", value))
	return result


## 脱敏单个调试值。
## [br]
## @api framework_internal
## [br]
## @param key_text: 值所属字段名。
## [br]
## @param value: 原始值。
## [br]
## @return: 脱敏后的值。
## [br]
## @schema value: Any debug value.
## [br]
## @schema return: Redacted or duplicated debug value.
static func sanitize_debug_value(key_text: String, value: Variant) -> Variant:
	if is_sensitive_debug_key(key_text):
		return "[redacted]"
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return sanitize_debug_dictionary(dictionary_value)
	if value is Array:
		var array_value: Array = value
		return sanitize_debug_array(array_value)
	if value is PackedStringArray:
		var string_array: PackedStringArray = value
		return string_array.duplicate()
	if key_text.to_lower() == "endpoint":
		return sanitize_endpoint(GFVariantData.to_text(value))
	return GFVariantData.duplicate_variant(value)


## 判断字段名是否应视为敏感信息。
## [br]
## @api framework_internal
## [br]
## @param key_text: 字段名。
## [br]
## @return: 敏感字段返回 true。
static func is_sensitive_debug_key(key_text: String) -> bool:
	var lower_key: String = key_text.to_lower()
	return (
		lower_key == "key"
		or lower_key.ends_with("_key")
		or lower_key.contains("api_key")
		or lower_key.contains("token")
		or lower_key.contains("secret")
		or lower_key.contains("password")
		or lower_key.contains("passwd")
		or lower_key.contains("auth")
		or lower_key.contains("credential")
		or lower_key.contains("cookie")
		or lower_key.contains("session_id")
	)


## 脱敏 endpoint。
## [br]
## @api framework_internal
## [br]
## @param endpoint: 原始 endpoint。
## [br]
## @return: 去除 query、fragment 和 userinfo 后的 endpoint。
static func sanitize_endpoint(endpoint: String) -> String:
	var sanitized: String = endpoint
	var query_index: int = sanitized.find("?")
	if query_index >= 0:
		sanitized = sanitized.substr(0, query_index)
	var fragment_index: int = sanitized.find("#")
	if fragment_index >= 0:
		sanitized = sanitized.substr(0, fragment_index)
	var scheme_index: int = sanitized.find("://")
	var authority_start: int = scheme_index + 3 if scheme_index >= 0 else 0
	var at_index: int = sanitized.find("@", authority_start)
	if at_index >= 0:
		sanitized = sanitized.substr(0, authority_start) + sanitized.substr(at_index + 1)
	return sanitized
