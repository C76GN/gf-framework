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
	return _sanitize_debug_dictionary(source, [])


static func _sanitize_debug_dictionary(source: Dictionary, visited: Array) -> Dictionary:
	if _visited_contains_reference(visited, source):
		return GFReportValueCodec.to_report_dictionary({
			"circular_reference": true,
		})
	visited.append(source)
	var result: Dictionary = {}
	for key_variant: Variant in source.keys():
		var key_text: String = GFVariantData.to_text(key_variant)
		result[key_variant] = _sanitize_debug_value(key_text, source[key_variant], visited)
	var _removed_reference: Variant = visited.pop_back()
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
	return _sanitize_debug_array(source, [])


static func _sanitize_debug_array(source: Array, visited: Array) -> Array:
	if _visited_contains_reference(visited, source):
		return [GFReportValueCodec.to_json_compatible({
			"circular_reference": true,
		})]
	visited.append(source)
	var result: Array = []
	for value: Variant in source:
		result.append(_sanitize_debug_value("", value, visited))
	var _removed_reference: Variant = visited.pop_back()
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
	return _sanitize_debug_value(key_text, value, [])


static func _sanitize_debug_value(key_text: String, value: Variant, visited: Array) -> Variant:
	if is_sensitive_debug_key(key_text):
		return "[redacted]"
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return _sanitize_debug_dictionary(dictionary_value, visited)
	if value is Array:
		var array_value: Array = value
		return _sanitize_debug_array(array_value, visited)
	if value is PackedStringArray:
		var string_array: PackedStringArray = value
		return string_array.duplicate()
	if key_text.to_lower() == "endpoint":
		return sanitize_endpoint(GFVariantData.to_text(value))
	return GFReportValueCodec.to_json_compatible(value, {
		"path_redaction": "basename",
	})


## 判断字段名是否应视为敏感信息。
## [br]
## @api framework_internal
## [br]
## @param key_text: 字段名。
## [br]
## @return: 敏感字段返回 true。
static func is_sensitive_debug_key(key_text: String) -> bool:
	var token_source: String = key_text.to_snake_case().to_lower()
	for separator: String in ["-", " ", ".", "/", "\\", ":"]:
		token_source = token_source.replace(separator, "_")
	var tokens: PackedStringArray = token_source.split("_", false)
	for token: String in tokens:
		if token in [
			"auth",
			"authorization",
			"token",
			"secret",
			"password",
			"passwd",
			"credential",
			"cookie",
		]:
			return true

	var normalized_key: String = "".join(tokens)
	if normalized_key in [
		"key",
		"keys",
		"servicekey",
		"servicekeys",
		"apikey",
		"accesskey",
		"privatekey",
		"secretkey",
		"sessionid",
	]:
		return true
	for sensitive_compound: String in [
		"authorization",
		"password",
		"passwd",
		"credential",
		"accesstoken",
		"refreshtoken",
		"authtoken",
		"clientsecret",
		"sessiontoken",
		"sessioncookie",
		"apikey",
		"accesskey",
		"privatekey",
		"secretkey",
		"servicekey",
		"sessionid",
	]:
		if normalized_key.contains(sensitive_compound):
			return true
	return false


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


static func _visited_contains_reference(visited: Array, value: Variant) -> bool:
	for item: Variant in visited:
		if is_same(item, value):
			return true
	return false
