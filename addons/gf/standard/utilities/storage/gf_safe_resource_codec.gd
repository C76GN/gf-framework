@tool

## GFSafeResourceCodec: 安全资源图编解码工具。
##
## 把 Variant、Array、Dictionary 和 allowlist 内的 Resource/Object 属性图
## 编码为纯 Dictionary，并在解码时按策略限制类、脚本、外部资源路径、深度和数量。
## 该类不注册 ResourceFormatLoader/Saver，不加载未授权资源，也不执行脚本表达式。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
class_name GFSafeResourceCodec
extends RefCounted


# --- 常量 ---

## 编码节点类型字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_KIND: String = "kind"

## Variant 类型编号字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_VARIANT_TYPE: String = "variant_type"

## 简单值字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_VALUE: String = "value"

## 集合项字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_ITEMS: String = "items"

## 字典条目字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_ENTRIES: String = "entries"

## 对象编号字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_OBJECT_ID: String = "object_id"

## 对象类字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_CLASS: String = "class"

## 对象脚本路径字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_SCRIPT_PATH: String = "script_path"

## 外部资源路径字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_RESOURCE_PATH: String = "resource_path"

## 对象属性字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const KEY_PROPERTIES: String = "properties"

const _KIND_VALUE: StringName = &"value"
const _KIND_ARRAY: StringName = &"array"
const _KIND_DICTIONARY: StringName = &"dictionary"
const _KIND_OBJECT: StringName = &"object"
const _KIND_OBJECT_REFERENCE: StringName = &"object_reference"
const _KIND_EXTERNAL_RESOURCE: StringName = &"external_resource"
const _INVALID_OBJECT_ID: int = -1


# --- 公共方法 ---

## 编码值。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param value: 要编码的值。
## [br]
## @param policy: 安全策略；为 null 时使用空 allowlist。
## [br]
## @param options: 编码选项。
## [br]
## @schema value: Variant value, Array, Dictionary, Resource, or Object graph.
## [br]
## @schema options: Dictionary with encode_external_resources, max_depth, and max_items overrides.
## [br]
## @return 编码报告。
## [br]
## @schema return: Dictionary with ok, data, issues, issue_count, and error.
static func encode(value: Variant, policy: GFSafeResourceCodecPolicy = null, options: Dictionary = {}) -> Dictionary:
	var active_policy: GFSafeResourceCodecPolicy = _get_policy(policy)
	var state: Dictionary = _make_state(active_policy, options)
	var result: Dictionary = _encode_recursive(value, active_policy, options, state, 0)
	if not GFVariantData.get_option_bool(result, "ok"):
		return _make_report(false, {}, _get_first_issue(state), state)
	return _make_report(true, GFVariantData.get_option_dictionary(result, "data"), "", state)


## 解码值。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param data: encode() 返回的 data 字典。
## [br]
## @param policy: 安全策略；为 null 时使用空 allowlist。
## [br]
## @param options: 解码选项。
## [br]
## @schema data: Dictionary produced by encode().
## [br]
## @schema options: Dictionary with load_external_resources, max_depth, and max_items overrides.
## [br]
## @return 解码报告。
## [br]
## @schema return: Dictionary with ok, value, issues, issue_count, and error.
static func decode(data: Dictionary, policy: GFSafeResourceCodecPolicy = null, options: Dictionary = {}) -> Dictionary:
	var active_policy: GFSafeResourceCodecPolicy = _get_policy(policy)
	var state: Dictionary = _make_state(active_policy, options)
	state["objects"] = {}
	var result: Dictionary = _decode_recursive(data, active_policy, options, state, 0)
	var report: Dictionary = {
		"ok": GFVariantData.get_option_bool(result, "ok"),
		"value": GFVariantData.get_option_value(result, "value"),
		"issues": _get_state_issues(state),
		"issue_count": _get_state_issues(state).size(),
		"error": GFVariantData.get_option_string(result, "error"),
	}
	if report["ok"] and GFVariantData.get_option_string(report, "error").is_empty():
		report["error"] = _get_first_issue(state)
	return report


## 创建允许 Resource 基类的策略。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 新策略。
static func make_resource_policy() -> GFSafeResourceCodecPolicy:
	var policy: GFSafeResourceCodecPolicy = GFSafeResourceCodecPolicy.new()
	var _policy_result: GFSafeResourceCodecPolicy = policy.allow_class("Resource")
	return policy


# --- 私有/辅助方法 ---

static func _encode_recursive(
	value: Variant,
	policy: GFSafeResourceCodecPolicy,
	options: Dictionary,
	state: Dictionary,
	depth: int
) -> Dictionary:
	if not _consume_item(state, depth, "encode"):
		return _make_failure(_get_first_issue(state))

	var value_type: int = typeof(value)
	if _is_direct_value_type(value_type):
		return _make_success({
			KEY_KIND: _KIND_VALUE,
			KEY_VARIANT_TYPE: value_type,
			KEY_VALUE: GFVariantData.duplicate_variant(value, true, true),
		})
	if value is Array:
		var array_value: Array = value
		var encoded_items: Array[Dictionary] = []
		for item: Variant in array_value:
			var item_result: Dictionary = _encode_recursive(item, policy, options, state, depth + 1)
			if not GFVariantData.get_option_bool(item_result, "ok"):
				return item_result
			encoded_items.append(GFVariantData.get_option_dictionary(item_result, "data"))
		return _make_success({
			KEY_KIND: _KIND_ARRAY,
			KEY_ITEMS: encoded_items,
		})
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		var encoded_entries: Array[Dictionary] = []
		for raw_key: Variant in dictionary_value.keys():
			var key_result: Dictionary = _encode_recursive(raw_key, policy, options, state, depth + 1)
			if not GFVariantData.get_option_bool(key_result, "ok"):
				return key_result
			var value_result: Dictionary = _encode_recursive(dictionary_value[raw_key], policy, options, state, depth + 1)
			if not GFVariantData.get_option_bool(value_result, "ok"):
				return value_result
			encoded_entries.append({
				"key": GFVariantData.get_option_dictionary(key_result, "data"),
				"value": GFVariantData.get_option_dictionary(value_result, "data"),
			})
		return _make_success({
			KEY_KIND: _KIND_DICTIONARY,
			KEY_ENTRIES: encoded_entries,
		})
	if value is Object:
		var object_value: Object = value
		return _encode_object(object_value, policy, options, state, depth)

	_add_issue(state, &"unsupported_variant_type", "Unsupported Variant type: %s." % type_string(value_type))
	return _make_failure(_get_first_issue(state))


static func _encode_object(
	object_value: Object,
	policy: GFSafeResourceCodecPolicy,
	options: Dictionary,
	state: Dictionary,
	depth: int
) -> Dictionary:
	var native_class: String = object_value.get_class()
	if not policy.allows_class(native_class):
		_add_issue(state, &"class_not_allowed", "Class is not allowed: %s." % native_class)
		return _make_failure(_get_first_issue(state))

	var script_path: String = _get_object_script_path(object_value)
	if not script_path.is_empty() and not policy.allows_script_path(script_path):
		_add_issue(state, &"script_not_allowed", "Script path is not allowed: %s." % script_path)
		return _make_failure(_get_first_issue(state))

	if object_value is Resource:
		var resource_value: Resource = object_value
		var resource_path: String = resource_value.resource_path
		if (
			not resource_path.is_empty()
			and policy.allow_external_resource_paths
			and GFVariantData.get_option_bool(options, "encode_external_resources", true)
		):
			if not policy.allows_resource_path(resource_path):
				_add_issue(state, &"resource_path_not_allowed", "Resource path is not allowed: %s." % resource_path)
				return _make_failure(_get_first_issue(state))
			return _make_success({
				KEY_KIND: _KIND_EXTERNAL_RESOURCE,
				KEY_CLASS: native_class,
				KEY_RESOURCE_PATH: resource_path,
			})

	var object_key: int = object_value.get_instance_id()
	var object_ids: Dictionary = GFVariantData.get_option_dictionary(state, "object_ids")
	if object_ids.has(object_key):
		if not policy.allow_object_identity_references:
			_add_issue(state, &"repeated_object_reference", "Repeated object reference is not allowed.")
			return _make_failure(_get_first_issue(state))
		return _make_success({
			KEY_KIND: _KIND_OBJECT_REFERENCE,
			KEY_OBJECT_ID: GFVariantData.get_option_int(object_ids, object_key, _INVALID_OBJECT_ID),
		})

	var object_id: int = GFVariantData.get_option_int(state, "next_object_id", 1)
	state["next_object_id"] = object_id + 1
	object_ids[object_key] = object_id
	state["object_ids"] = object_ids

	var properties: Array[Dictionary] = []
	for property_info_value: Variant in object_value.get_property_list():
		if not property_info_value is Dictionary:
			continue
		var property_info: Dictionary = property_info_value
		if not _should_encode_property(property_info):
			continue
		var property_id: String = GFVariantData.get_option_string(property_info, "name")
		var property_result: Dictionary = _encode_recursive(object_value.get(property_id), policy, options, state, depth + 1)
		if not GFVariantData.get_option_bool(property_result, "ok"):
			return property_result
		properties.append({
			"name": property_id,
			"value": GFVariantData.get_option_dictionary(property_result, "data"),
		})

	return _make_success({
		KEY_KIND: _KIND_OBJECT,
		KEY_OBJECT_ID: object_id,
		KEY_CLASS: native_class,
		KEY_SCRIPT_PATH: script_path,
		KEY_PROPERTIES: properties,
	})


static func _decode_recursive(
	data: Dictionary,
	policy: GFSafeResourceCodecPolicy,
	options: Dictionary,
	state: Dictionary,
	depth: int
) -> Dictionary:
	if not _consume_item(state, depth, "decode"):
		return _make_decoded_failure(_get_first_issue(state))

	var kind: StringName = GFVariantData.get_option_string_name(data, KEY_KIND)
	match kind:
		_KIND_VALUE:
			return _decode_direct_value(data, state)
		_KIND_ARRAY:
			var result_array: Array = []
			for item_value: Variant in GFVariantData.get_option_array(data, KEY_ITEMS):
				var item_data: Dictionary = GFVariantData.as_dictionary(item_value)
				var item_result: Dictionary = _decode_recursive(item_data, policy, options, state, depth + 1)
				if not GFVariantData.get_option_bool(item_result, "ok"):
					return item_result
				result_array.append(GFVariantData.get_option_value(item_result, "value"))
			return { "ok": true, "value": result_array, "error": "" }
		_KIND_DICTIONARY:
			var result_dictionary: Dictionary = {}
			for entry_value: Variant in GFVariantData.get_option_array(data, KEY_ENTRIES):
				var entry: Dictionary = GFVariantData.as_dictionary(entry_value)
				var key_result: Dictionary = _decode_recursive(
					GFVariantData.get_option_dictionary(entry, "key"),
					policy,
					options,
					state,
					depth + 1
				)
				if not GFVariantData.get_option_bool(key_result, "ok"):
					return key_result
				var value_result: Dictionary = _decode_recursive(
					GFVariantData.get_option_dictionary(entry, "value"),
					policy,
					options,
					state,
					depth + 1
				)
				if not GFVariantData.get_option_bool(value_result, "ok"):
					return value_result
				result_dictionary[GFVariantData.get_option_value(key_result, "value")] = GFVariantData.get_option_value(value_result, "value")
			return { "ok": true, "value": result_dictionary, "error": "" }
		_KIND_OBJECT_REFERENCE:
			var object_id: int = GFVariantData.get_option_int(data, KEY_OBJECT_ID, _INVALID_OBJECT_ID)
			var objects: Dictionary = GFVariantData.get_option_dictionary(state, "objects")
			if not objects.has(object_id):
				_add_issue(state, &"missing_object_reference", "Object reference target is missing.")
				return _make_decoded_failure(_get_first_issue(state))
			return { "ok": true, "value": objects[object_id], "error": "" }
		_KIND_EXTERNAL_RESOURCE:
			return _decode_external_resource(data, policy, options, state)
		_KIND_OBJECT:
			return _decode_object(data, policy, options, state, depth)

	_add_issue(state, &"unknown_encoded_kind", "Unknown encoded kind: %s." % String(kind))
	return _make_decoded_failure(_get_first_issue(state))


static func _decode_external_resource(
	data: Dictionary,
	policy: GFSafeResourceCodecPolicy,
	options: Dictionary,
	state: Dictionary
) -> Dictionary:
	var declared_class: String = GFVariantData.get_option_string(data, KEY_CLASS)
	if not declared_class.is_empty() and not policy.allows_class(declared_class):
		_add_issue(state, &"class_not_allowed", "Class is not allowed: %s." % declared_class)
		return _make_decoded_failure(_get_first_issue(state))

	var resource_path: String = GFVariantData.get_option_string(data, KEY_RESOURCE_PATH)
	if resource_path.is_empty() or not policy.allows_resource_path(resource_path):
		_add_issue(state, &"resource_path_not_allowed", "Resource path is not allowed: %s." % resource_path)
		return _make_decoded_failure(_get_first_issue(state))
	if not GFVariantData.get_option_bool(options, "load_external_resources", false):
		_add_issue(state, &"external_resource_loading_disabled", "External resource loading is disabled.")
		return _make_decoded_failure(_get_first_issue(state))
	if not ResourceLoader.exists(resource_path):
		_add_issue(state, &"external_resource_missing", "External resource does not exist: %s." % resource_path)
		return _make_decoded_failure(_get_first_issue(state))
	if not _preflight_external_resource_dependencies(resource_path, policy, options, state):
		return _make_decoded_failure(_get_first_issue(state))
	var loaded_resource: Resource = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded_resource == null:
		return { "ok": false, "value": null, "error": "External resource load failed." }

	var loaded_class: String = loaded_resource.get_class()
	if not policy.allows_class(loaded_class):
		_add_issue(state, &"class_not_allowed", "Loaded resource class is not allowed: %s." % loaded_class)
		return _make_decoded_failure(_get_first_issue(state))

	var loaded_script_path: String = _get_object_script_path(loaded_resource)
	if not loaded_script_path.is_empty() and not policy.allows_script_path(loaded_script_path):
		_add_issue(state, &"script_not_allowed", "Loaded resource script path is not allowed: %s." % loaded_script_path)
		return _make_decoded_failure(_get_first_issue(state))

	return { "ok": true, "value": loaded_resource, "error": "" }


static func _preflight_external_resource_dependencies(
	resource_path: String,
	policy: GFSafeResourceCodecPolicy,
	options: Dictionary,
	state: Dictionary
) -> bool:
	if not GFVariantData.get_option_bool(options, "preflight_external_resource_dependencies", true):
		return true
	var dependencies: PackedStringArray = ResourceLoader.get_dependencies(resource_path)
	for dependency_entry: String in dependencies:
		var dependency_path: String = _extract_dependency_resource_path(dependency_entry)
		if dependency_path.is_empty() or not _is_script_resource_path(dependency_path):
			continue
		if policy.allows_script_path(dependency_path):
			continue
		_add_issue(
			state,
			&"script_not_allowed",
			"External resource dependency script path is not allowed before load: %s." % dependency_path
		)
		return false
	return true


static func _extract_dependency_resource_path(dependency_entry: String) -> String:
	var normalized_entry: String = dependency_entry.strip_edges()
	if normalized_entry.is_empty():
		return ""
	var parts: PackedStringArray = normalized_entry.split("::", false)
	for part: String in parts:
		var candidate: String = part.strip_edges()
		if candidate.begins_with("res://") or candidate.begins_with("user://"):
			return candidate
	return normalized_entry


static func _is_script_resource_path(path: String) -> bool:
	var extension: String = path.get_extension().to_lower()
	return extension == "gd" or extension == "gdc" or extension == "cs"


static func _decode_object(
	data: Dictionary,
	policy: GFSafeResourceCodecPolicy,
	options: Dictionary,
	state: Dictionary,
	depth: int
) -> Dictionary:
	var native_class: String = GFVariantData.get_option_string(data, KEY_CLASS)
	var script_path: String = GFVariantData.get_option_string(data, KEY_SCRIPT_PATH)
	if not policy.allows_class(native_class):
		_add_issue(state, &"class_not_allowed", "Class is not allowed: %s." % native_class)
		return _make_decoded_failure(_get_first_issue(state))
	if not script_path.is_empty() and not policy.allows_script_path(script_path):
		_add_issue(state, &"script_not_allowed", "Script path is not allowed: %s." % script_path)
		return _make_decoded_failure(_get_first_issue(state))
	if not ClassDB.class_exists(native_class):
		_add_issue(state, &"class_missing", "ClassDB class does not exist: %s." % native_class)
		return _make_decoded_failure(_get_first_issue(state))

	var object_instance: Object = ClassDB.instantiate(native_class)
	if object_instance == null:
		_add_issue(state, &"class_instantiate_failed", "Class could not be instantiated: %s." % native_class)
		return _make_decoded_failure(_get_first_issue(state))

	if not script_path.is_empty():
		var script_resource: Resource = ResourceLoader.load(script_path)
		if script_resource == null or not script_resource is Script:
			_add_issue(state, &"script_load_failed", "Script could not be loaded: %s." % script_path)
			return _make_decoded_failure(_get_first_issue(state))
		object_instance.set_script(script_resource)

	var object_id: int = GFVariantData.get_option_int(data, KEY_OBJECT_ID, _INVALID_OBJECT_ID)
	if object_id != _INVALID_OBJECT_ID:
		var objects: Dictionary = GFVariantData.get_option_dictionary(state, "objects")
		objects[object_id] = object_instance
		state["objects"] = objects

	var allowed_properties: Dictionary = _get_decodable_property_names(object_instance)
	for property_value: Variant in GFVariantData.get_option_array(data, KEY_PROPERTIES):
		var property_data: Dictionary = GFVariantData.as_dictionary(property_value)
		var property_id: String = GFVariantData.get_option_string(property_data, "name")
		if not allowed_properties.has(property_id):
			_add_issue(state, &"property_not_allowed", "Property is not allowed: %s." % property_id)
			return _make_decoded_failure(_get_first_issue(state))
		var value_result: Dictionary = _decode_recursive(
			GFVariantData.get_option_dictionary(property_data, "value"),
			policy,
			options,
			state,
			depth + 1
		)
		if not GFVariantData.get_option_bool(value_result, "ok"):
			return value_result
		object_instance.set(property_id, GFVariantData.get_option_value(value_result, "value"))

	return { "ok": true, "value": object_instance, "error": "" }


static func _decode_direct_value(data: Dictionary, state: Dictionary) -> Dictionary:
	var value: Variant = GFVariantData.get_option_value(data, KEY_VALUE)
	var actual_type: int = typeof(value)
	if not _is_direct_value_type(actual_type):
		_add_issue(state, &"value_type_not_allowed", "Encoded value type is not allowed: %s." % type_string(actual_type))
		return _make_decoded_failure(_get_first_issue(state))

	var declared_type: int = GFVariantData.get_option_int(data, KEY_VARIANT_TYPE, actual_type)
	if declared_type != actual_type:
		_add_issue(
			state,
			&"value_type_mismatch",
			"Encoded value type mismatch: declared %s but found %s." % [type_string(declared_type), type_string(actual_type)]
		)
		return _make_decoded_failure(_get_first_issue(state))

	return {
		"ok": true,
		"value": GFVariantData.duplicate_variant(value, true, true),
		"error": "",
	}


static func _is_direct_value_type(value_type: int) -> bool:
	return [
		TYPE_NIL,
		TYPE_BOOL,
		TYPE_INT,
		TYPE_FLOAT,
		TYPE_STRING,
		TYPE_VECTOR2,
		TYPE_VECTOR2I,
		TYPE_RECT2,
		TYPE_RECT2I,
		TYPE_VECTOR3,
		TYPE_VECTOR3I,
		TYPE_TRANSFORM2D,
		TYPE_VECTOR4,
		TYPE_VECTOR4I,
		TYPE_PLANE,
		TYPE_QUATERNION,
		TYPE_AABB,
		TYPE_BASIS,
		TYPE_TRANSFORM3D,
		TYPE_PROJECTION,
		TYPE_COLOR,
		TYPE_STRING_NAME,
		TYPE_NODE_PATH,
		TYPE_PACKED_BYTE_ARRAY,
		TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY,
		TYPE_PACKED_STRING_ARRAY,
		TYPE_PACKED_VECTOR2_ARRAY,
		TYPE_PACKED_VECTOR3_ARRAY,
		TYPE_PACKED_COLOR_ARRAY,
		TYPE_PACKED_VECTOR4_ARRAY,
	].has(value_type)


static func _should_encode_property(property_info: Dictionary) -> bool:
	var property_id: String = GFVariantData.get_option_string(property_info, "name")
	if property_id.is_empty() or property_id == "script" or property_id == "resource_path":
		return false
	var usage: int = GFVariantData.get_option_int(property_info, "usage")
	return (usage & PROPERTY_USAGE_STORAGE) != 0


static func _get_decodable_property_names(object_instance: Object) -> Dictionary:
	var result: Dictionary = {}
	for property_info_value: Variant in object_instance.get_property_list():
		if not (property_info_value is Dictionary):
			continue
		var property_info: Dictionary = property_info_value
		if not _should_encode_property(property_info):
			continue
		var property_id: String = GFVariantData.get_option_string(property_info, "name")
		result[property_id] = true
	return result


static func _get_object_script_path(object_value: Object) -> String:
	var script_value: Variant = object_value.get_script()
	if script_value is Resource:
		var script_resource: Resource = script_value
		return script_resource.resource_path
	return ""


static func _get_policy(policy: GFSafeResourceCodecPolicy) -> GFSafeResourceCodecPolicy:
	if policy != null:
		return policy
	return GFSafeResourceCodecPolicy.new()


static func _make_state(policy: GFSafeResourceCodecPolicy, options: Dictionary) -> Dictionary:
	return {
		"issues": [],
		"object_ids": {},
		"next_object_id": 1,
		"item_count": 0,
		"max_depth": GFVariantData.get_option_int(options, "max_depth", policy.max_depth),
		"max_items": GFVariantData.get_option_int(options, "max_items", policy.max_items),
	}


static func _consume_item(state: Dictionary, depth: int, phase: String) -> bool:
	var max_depth: int = GFVariantData.get_option_int(state, "max_depth", 32)
	if depth > max_depth:
		_add_issue(state, &"max_depth_exceeded", "%s max_depth exceeded." % phase)
		return false
	var item_count: int = GFVariantData.get_option_int(state, "item_count", 0) + 1
	state["item_count"] = item_count
	if item_count > GFVariantData.get_option_int(state, "max_items", 4096):
		_add_issue(state, &"max_items_exceeded", "%s max_items exceeded." % phase)
		return false
	return true


static func _add_issue(state: Dictionary, kind: StringName, message: String) -> void:
	var issues: Array = GFVariantData.get_option_array(state, "issues")
	issues.append({
		"kind": kind,
		"message": message,
	})
	state["issues"] = issues


static func _get_first_issue(state: Dictionary) -> String:
	for issue_value: Variant in GFVariantData.get_option_array(state, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		var message: String = GFVariantData.get_option_string(issue, "message")
		if not message.is_empty():
			return message
	return ""


static func _get_state_issues(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for issue_value: Variant in GFVariantData.get_option_array(state, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		result.append(issue.duplicate(true))
	return result


static func _make_report(ok: bool, data: Dictionary, error: String, state: Dictionary) -> Dictionary:
	var issues: Array[Dictionary] = _get_state_issues(state)
	return {
		"ok": ok and issues.is_empty(),
		"data": data.duplicate(true),
		"issues": issues,
		"issue_count": issues.size(),
		"error": error,
	}


static func _make_success(data: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"data": data,
		"error": "",
	}


static func _make_failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"error": error,
	}


static func _make_decoded_failure(error: String) -> Dictionary:
	return {
		"ok": false,
		"value": null,
		"error": error,
	}
