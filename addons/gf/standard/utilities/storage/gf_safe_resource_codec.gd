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
const _KEY_ARRAY_TYPE: String = "array_type"
const _KEY_DICTIONARY_KEY_TYPE: String = "dictionary_key_type"
const _KEY_DICTIONARY_VALUE_TYPE: String = "dictionary_value_type"


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
	var decode_ok: bool = GFVariantData.get_option_bool(result, "ok")
	if not decode_ok:
		_cleanup_failed_decode(state)
	var report: Dictionary = {
		"ok": decode_ok,
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
		var array_data: Dictionary = {
			KEY_KIND: _KIND_ARRAY,
			KEY_ITEMS: encoded_items,
		}
		if array_value.is_typed():
			var array_type_result: Dictionary = _encode_container_type(
				array_value.get_typed_builtin(),
				array_value.get_typed_class_name(),
				array_value.get_typed_script(),
				policy,
				state
			)
			if not GFVariantData.get_option_bool(array_type_result, "ok"):
				return array_type_result
			array_data[_KEY_ARRAY_TYPE] = GFVariantData.get_option_dictionary(array_type_result, "data")
		return _make_success(array_data)
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
		var dictionary_data: Dictionary = {
			KEY_KIND: _KIND_DICTIONARY,
			KEY_ENTRIES: encoded_entries,
		}
		if dictionary_value.is_typed():
			var key_type_result: Dictionary = _encode_container_type(
				dictionary_value.get_typed_key_builtin(),
				dictionary_value.get_typed_key_class_name(),
				dictionary_value.get_typed_key_script(),
				policy,
				state
			)
			if not GFVariantData.get_option_bool(key_type_result, "ok"):
				return key_type_result
			var value_type_result: Dictionary = _encode_container_type(
				dictionary_value.get_typed_value_builtin(),
				dictionary_value.get_typed_value_class_name(),
				dictionary_value.get_typed_value_script(),
				policy,
				state
			)
			if not GFVariantData.get_option_bool(value_type_result, "ok"):
				return value_type_result
			dictionary_data[_KEY_DICTIONARY_KEY_TYPE] = GFVariantData.get_option_dictionary(key_type_result, "data")
			dictionary_data[_KEY_DICTIONARY_VALUE_TYPE] = GFVariantData.get_option_dictionary(value_type_result, "data")
		return _make_success(dictionary_data)
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
			return _decode_array(data, policy, options, state, depth)
		_KIND_DICTIONARY:
			return _decode_dictionary(data, policy, options, state, depth)
		_KIND_OBJECT_REFERENCE:
			var raw_object_id: Variant = GFVariantData.get_option_value(data, KEY_OBJECT_ID, null)
			if typeof(raw_object_id) != TYPE_INT:
				_add_issue(state, &"invalid_object_id", "Object reference id must be a positive integer.")
				return _make_decoded_failure(_get_first_issue(state))
			var object_id: int = raw_object_id
			if object_id <= 0:
				_add_issue(state, &"invalid_object_id", "Object reference id must be a positive integer.")
				return _make_decoded_failure(_get_first_issue(state))
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


static func _encode_container_type(
	typed_builtin: int,
	typed_class_name: StringName,
	typed_script: Variant,
	policy: GFSafeResourceCodecPolicy,
	state: Dictionary
) -> Dictionary:
	var script_path: String = ""
	if typed_script != null:
		if not typed_script is Script:
			_add_issue(state, &"container_type_script_invalid", "Typed container script metadata is invalid.")
			return _make_failure(_get_first_issue(state))
		var script_value: Script = typed_script
		script_path = script_value.resource_path
		if script_path.is_empty():
			_add_issue(state, &"container_type_script_unstorable", "Typed container script must have a resource path.")
			return _make_failure(_get_first_issue(state))
		if not policy.allows_script_path(script_path):
			_add_issue(state, &"script_not_allowed", "Typed container script path is not allowed: %s." % script_path)
			return _make_failure(_get_first_issue(state))
		var script_base_type: String = String(script_value.get_instance_base_type())
		if script_base_type.is_empty() or not policy.allows_class(script_base_type):
			_add_issue(state, &"class_not_allowed", "Typed container script base class is not allowed: %s." % script_base_type)
			return _make_failure(_get_first_issue(state))
		if not _container_class_matches_script(String(typed_class_name), script_value):
			_add_issue(state, &"container_type_invalid", "Typed container class does not match its script.")
			return _make_failure(_get_first_issue(state))

	var class_id: String = String(typed_class_name)
	if typed_builtin == TYPE_OBJECT and script_path.is_empty() and not class_id.is_empty() and not policy.allows_class(class_id):
		_add_issue(state, &"class_not_allowed", "Typed container class is not allowed: %s." % class_id)
		return _make_failure(_get_first_issue(state))

	return _make_success({
		KEY_VARIANT_TYPE: typed_builtin,
		KEY_CLASS: class_id,
		KEY_SCRIPT_PATH: script_path,
	})


static func _decode_array(
	data: Dictionary,
	policy: GFSafeResourceCodecPolicy,
	options: Dictionary,
	state: Dictionary,
	depth: int
) -> Dictionary:
	var raw_items: Variant = GFVariantData.get_option_value(data, KEY_ITEMS, null)
	if not raw_items is Array:
		_add_issue(state, &"encoded_shape_invalid", "Encoded array items must be an Array.")
		return _make_decoded_failure(_get_first_issue(state))
	var items: Array = raw_items
	var item_nodes: Array[Dictionary] = []
	for item_value: Variant in items:
		if not item_value is Dictionary:
			_add_issue(state, &"encoded_shape_invalid", "Encoded array items must be Dictionaries.")
			return _make_decoded_failure(_get_first_issue(state))
		var item_data: Dictionary = item_value
		item_nodes.append(item_data)

	var type_result: Dictionary = _decode_container_type(data, _KEY_ARRAY_TYPE, policy, state)
	if not GFVariantData.get_option_bool(type_result, "ok"):
		return type_result

	var result_array: Array = []
	for item_data: Dictionary in item_nodes:
		var item_result: Dictionary = _decode_recursive(item_data, policy, options, state, depth + 1)
		if not GFVariantData.get_option_bool(item_result, "ok"):
			return item_result
		var decoded_item: Variant = GFVariantData.get_option_value(item_result, "value")
		if not _value_matches_container_type(decoded_item, type_result):
			_add_issue(state, &"container_value_type_mismatch", "Decoded array item does not match its declared type.")
			return _make_decoded_failure(_get_first_issue(state))
		result_array.append(decoded_item)

	if not GFVariantData.get_option_bool(type_result, "typed"):
		return { "ok": true, "value": result_array, "error": "" }
	var typed_array: Array = Array(
		result_array,
		GFVariantData.get_option_int(type_result, "builtin"),
		GFVariantData.get_option_string_name(type_result, "class_name"),
		GFVariantData.get_option_value(type_result, "script")
	)
	return { "ok": true, "value": typed_array, "error": "" }


static func _decode_dictionary(
	data: Dictionary,
	policy: GFSafeResourceCodecPolicy,
	options: Dictionary,
	state: Dictionary,
	depth: int
) -> Dictionary:
	var raw_entries: Variant = GFVariantData.get_option_value(data, KEY_ENTRIES, null)
	if not raw_entries is Array:
		_add_issue(state, &"encoded_shape_invalid", "Encoded dictionary entries must be an Array.")
		return _make_decoded_failure(_get_first_issue(state))
	var entries: Array = raw_entries
	var entry_nodes: Array[Dictionary] = []
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			_add_issue(state, &"encoded_shape_invalid", "Encoded dictionary entries must be Dictionaries.")
			return _make_decoded_failure(_get_first_issue(state))
		var entry: Dictionary = entry_value
		var raw_key: Variant = GFVariantData.get_option_value(entry, "key", null)
		var raw_value: Variant = GFVariantData.get_option_value(entry, "value", null)
		if not raw_key is Dictionary or not raw_value is Dictionary:
			_add_issue(state, &"encoded_shape_invalid", "Encoded dictionary entries must contain Dictionary key and value nodes.")
			return _make_decoded_failure(_get_first_issue(state))
		entry_nodes.append(entry)

	var has_key_type: bool = data.has(_KEY_DICTIONARY_KEY_TYPE)
	var has_value_type: bool = data.has(_KEY_DICTIONARY_VALUE_TYPE)
	if has_key_type != has_value_type:
		_add_issue(state, &"container_type_invalid", "Typed dictionary metadata must declare both key and value types.")
		return _make_decoded_failure(_get_first_issue(state))
	var key_type_result: Dictionary = _decode_container_type(data, _KEY_DICTIONARY_KEY_TYPE, policy, state)
	if not GFVariantData.get_option_bool(key_type_result, "ok"):
		return key_type_result
	var value_type_result: Dictionary = _decode_container_type(data, _KEY_DICTIONARY_VALUE_TYPE, policy, state)
	if not GFVariantData.get_option_bool(value_type_result, "ok"):
		return value_type_result

	var result_dictionary: Dictionary = {}
	for entry: Dictionary in entry_nodes:
		var key_data: Dictionary = GFVariantData.get_option_dictionary(entry, "key")
		var value_data: Dictionary = GFVariantData.get_option_dictionary(entry, "value")
		var key_result: Dictionary = _decode_recursive(
			key_data,
			policy,
			options,
			state,
			depth + 1
		)
		if not GFVariantData.get_option_bool(key_result, "ok"):
			return key_result
		var decoded_key: Variant = GFVariantData.get_option_value(key_result, "value")
		if not _value_matches_container_type(decoded_key, key_type_result):
			_add_issue(state, &"container_key_type_mismatch", "Decoded dictionary key does not match its declared type.")
			return _make_decoded_failure(_get_first_issue(state))
		if result_dictionary.has(decoded_key):
			_add_issue(state, &"duplicate_dictionary_key", "Encoded dictionary contains a duplicate key.")
			return _make_decoded_failure(_get_first_issue(state))
		var value_result: Dictionary = _decode_recursive(
			value_data,
			policy,
			options,
			state,
			depth + 1
		)
		if not GFVariantData.get_option_bool(value_result, "ok"):
			return value_result
		var decoded_value: Variant = GFVariantData.get_option_value(value_result, "value")
		if not _value_matches_container_type(decoded_value, value_type_result):
			_add_issue(state, &"container_value_type_mismatch", "Decoded dictionary value does not match its declared type.")
			return _make_decoded_failure(_get_first_issue(state))
		result_dictionary[decoded_key] = decoded_value

	if not GFVariantData.get_option_bool(key_type_result, "typed"):
		return { "ok": true, "value": result_dictionary, "error": "" }
	var typed_dictionary: Dictionary = Dictionary(
		result_dictionary,
		GFVariantData.get_option_int(key_type_result, "builtin"),
		GFVariantData.get_option_string_name(key_type_result, "class_name"),
		GFVariantData.get_option_value(key_type_result, "script"),
		GFVariantData.get_option_int(value_type_result, "builtin"),
		GFVariantData.get_option_string_name(value_type_result, "class_name"),
		GFVariantData.get_option_value(value_type_result, "script")
	)
	return { "ok": true, "value": typed_dictionary, "error": "" }


static func _decode_container_type(
	data: Dictionary,
	metadata_key: String,
	policy: GFSafeResourceCodecPolicy,
	state: Dictionary
) -> Dictionary:
	if not data.has(metadata_key):
		return {
			"ok": true,
			"typed": false,
			"builtin": TYPE_NIL,
			"class_name": &"",
			"script": null,
			"error": "",
		}
	var raw_metadata: Variant = data[metadata_key]
	if not raw_metadata is Dictionary:
		_add_issue(state, &"container_type_invalid", "Typed container metadata must be a Dictionary.")
		return _make_decoded_failure(_get_first_issue(state))
	var metadata: Dictionary = raw_metadata
	var raw_typed_builtin: Variant = GFVariantData.get_option_value(metadata, KEY_VARIANT_TYPE, null)
	if typeof(raw_typed_builtin) != TYPE_INT:
		_add_issue(state, &"container_type_invalid", "Typed container Variant type must be an integer.")
		return _make_decoded_failure(_get_first_issue(state))
	var typed_builtin: int = raw_typed_builtin
	if typed_builtin < TYPE_NIL or typed_builtin >= TYPE_MAX:
		_add_issue(state, &"container_type_invalid", "Typed container Variant type is invalid.")
		return _make_decoded_failure(_get_first_issue(state))

	var class_id: String = GFVariantData.get_option_string(metadata, KEY_CLASS)
	var script_path: String = GFVariantData.get_option_string(metadata, KEY_SCRIPT_PATH)
	if typed_builtin != TYPE_OBJECT and (not class_id.is_empty() or not script_path.is_empty()):
		_add_issue(state, &"container_type_invalid", "Only Object container types may declare a class or script.")
		return _make_decoded_failure(_get_first_issue(state))

	var typed_script: Variant = null
	if not script_path.is_empty():
		if not policy.allows_script_path(script_path):
			_add_issue(state, &"script_not_allowed", "Typed container script path is not allowed: %s." % script_path)
			return _make_decoded_failure(_get_first_issue(state))
		var script_resource: Resource = ResourceLoader.load(script_path)
		if script_resource == null or not script_resource is Script:
			_add_issue(state, &"script_load_failed", "Typed container script could not be loaded: %s." % script_path)
			return _make_decoded_failure(_get_first_issue(state))
		var script_value: Script = script_resource
		var script_base_type: String = String(script_value.get_instance_base_type())
		if script_base_type.is_empty() or not policy.allows_class(script_base_type):
			_add_issue(state, &"class_not_allowed", "Typed container script base class is not allowed: %s." % script_base_type)
			return _make_decoded_failure(_get_first_issue(state))
		if not _container_class_matches_script(class_id, script_value):
			_add_issue(state, &"container_type_invalid", "Typed container class does not match its script.")
			return _make_decoded_failure(_get_first_issue(state))
		typed_script = script_value
	elif typed_builtin == TYPE_OBJECT and not class_id.is_empty():
		if not policy.allows_class(class_id):
			_add_issue(state, &"class_not_allowed", "Typed container class is not allowed: %s." % class_id)
			return _make_decoded_failure(_get_first_issue(state))
		if not ClassDB.class_exists(class_id):
			_add_issue(state, &"class_missing", "Typed container ClassDB class does not exist: %s." % class_id)
			return _make_decoded_failure(_get_first_issue(state))

	return {
		"ok": true,
		"typed": true,
		"builtin": typed_builtin,
		"class_name": StringName(class_id),
		"script": typed_script,
		"error": "",
	}


static func _value_matches_container_type(value: Variant, type_result: Dictionary) -> bool:
	if not GFVariantData.get_option_bool(type_result, "typed"):
		return true
	var typed_builtin: int = GFVariantData.get_option_int(type_result, "builtin", TYPE_NIL)
	if value == null:
		return typed_builtin == TYPE_OBJECT or typed_builtin == TYPE_NIL
	if typed_builtin != TYPE_NIL and typeof(value) != typed_builtin:
		return false
	if typed_builtin != TYPE_OBJECT:
		return true
	if not value is Object:
		return false
	var object_value: Object = value
	var typed_script: Variant = GFVariantData.get_option_value(type_result, "script")
	if typed_script is Script:
		var script_value: Script = typed_script
		return script_value.instance_has(object_value)
	var class_id: StringName = GFVariantData.get_option_string_name(type_result, "class_name")
	return class_id.is_empty() or object_value.is_class(class_id)


static func _container_class_matches_script(class_id: String, script_value: Script) -> bool:
	if class_id.is_empty():
		return true
	var global_name: String = String(script_value.get_global_name())
	var base_type: String = String(script_value.get_instance_base_type())
	return class_id == global_name or class_id == base_type


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
	var raw_properties: Variant = GFVariantData.get_option_value(data, KEY_PROPERTIES, null)
	if not raw_properties is Array:
		_add_issue(state, &"encoded_shape_invalid", "Encoded object properties must be an Array.")
		return _make_decoded_failure(_get_first_issue(state))
	var properties: Array = raw_properties
	var property_nodes: Array[Dictionary] = []
	var seen_property_ids: Dictionary = {}
	for property_value: Variant in properties:
		if not property_value is Dictionary:
			_add_issue(state, &"encoded_shape_invalid", "Encoded object properties must be Dictionaries.")
			return _make_decoded_failure(_get_first_issue(state))
		var property_data: Dictionary = property_value
		var raw_property_id: Variant = GFVariantData.get_option_value(property_data, "name", null)
		if typeof(raw_property_id) != TYPE_STRING and typeof(raw_property_id) != TYPE_STRING_NAME:
			_add_issue(state, &"encoded_shape_invalid", "Encoded property names must be strings.")
			return _make_decoded_failure(_get_first_issue(state))
		var property_id: String = GFVariantData.get_option_string(property_data, "name")
		if seen_property_ids.has(property_id):
			_add_issue(state, &"duplicate_property", "Encoded object contains a duplicate property: %s." % property_id)
			return _make_decoded_failure(_get_first_issue(state))
		var raw_property_node: Variant = GFVariantData.get_option_value(property_data, "value", null)
		if not raw_property_node is Dictionary:
			_add_issue(state, &"encoded_shape_invalid", "Encoded property values must be Dictionaries.")
			return _make_decoded_failure(_get_first_issue(state))
		seen_property_ids[property_id] = true
		property_nodes.append(property_data)

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

	var raw_object_id: Variant = GFVariantData.get_option_value(data, KEY_OBJECT_ID, null)
	if typeof(raw_object_id) != TYPE_INT:
		_add_issue(state, &"invalid_object_id", "Object id must be a positive integer.")
		return _make_decoded_failure(_get_first_issue(state))
	var object_id: int = raw_object_id
	if object_id <= 0:
		_add_issue(state, &"invalid_object_id", "Object id must be a positive integer.")
		return _make_decoded_failure(_get_first_issue(state))
	var objects: Dictionary = GFVariantData.get_option_dictionary(state, "objects")
	if objects.has(object_id):
		_add_issue(state, &"duplicate_object_id", "Object id is already registered: %d." % object_id)
		return _make_decoded_failure(_get_first_issue(state))

	var script_value: Script = null
	if not script_path.is_empty():
		var script_resource: Resource = ResourceLoader.load(script_path)
		if script_resource == null or not script_resource is Script:
			_add_issue(state, &"script_load_failed", "Script could not be loaded: %s." % script_path)
			return _make_decoded_failure(_get_first_issue(state))
		script_value = script_resource
		var script_base_type: String = String(script_value.get_instance_base_type())
		if script_base_type.is_empty() or not policy.allows_class(script_base_type):
			_add_issue(state, &"class_not_allowed", "Script base class is not allowed: %s." % script_base_type)
			return _make_decoded_failure(_get_first_issue(state))
		if not ClassDB.class_exists(script_base_type) or not ClassDB.is_parent_class(native_class, script_base_type):
			_add_issue(
				state,
				&"script_class_mismatch",
				"Script base class %s is incompatible with native class %s." % [script_base_type, native_class]
			)
			return _make_decoded_failure(_get_first_issue(state))

	var object_instance: Object = ClassDB.instantiate(native_class)
	if object_instance == null:
		_add_issue(state, &"class_instantiate_failed", "Class could not be instantiated: %s." % native_class)
		return _make_decoded_failure(_get_first_issue(state))
	var created_objects: Array = GFVariantData.get_option_array(state, "decoded_objects_created")
	created_objects.append(object_instance)
	state["decoded_objects_created"] = created_objects

	if script_value != null:
		object_instance.set_script(script_value)
		if object_instance.get_script() != script_value:
			_add_issue(state, &"script_attach_failed", "Script could not be attached: %s." % script_path)
			return _make_decoded_failure(_get_first_issue(state))

	objects[object_id] = object_instance
	state["objects"] = objects

	var allowed_properties: Dictionary = _get_decodable_property_names(object_instance)
	for property_data: Dictionary in property_nodes:
		var property_id: String = GFVariantData.get_option_string(property_data, "name")
		if not allowed_properties.has(property_id):
			_add_issue(state, &"property_not_allowed", "Property is not allowed: %s." % property_id)
			return _make_decoded_failure(_get_first_issue(state))
		var property_node: Dictionary = GFVariantData.get_option_dictionary(property_data, "value")
		var value_result: Dictionary = _decode_recursive(
			property_node,
			policy,
			options,
			state,
			depth + 1
		)
		if not GFVariantData.get_option_bool(value_result, "ok"):
			return value_result
		var decoded_property_value: Variant = GFVariantData.get_option_value(value_result, "value")
		var property_info: Dictionary = GFVariantData.get_option_dictionary(allowed_properties, property_id)
		if not _value_matches_decodable_property(
			decoded_property_value,
			property_info,
			object_instance.get(property_id)
		):
			_add_issue(state, &"property_write_failed", "Property type mismatch: %s." % property_id)
			return _make_decoded_failure(_get_first_issue(state))
		var write_result: Dictionary = GFObjectPropertyTools.write_property(
			object_instance,
			NodePath(property_id),
			decoded_property_value,
			{
				"check_writable": true,
				"check_type": true,
				"coerce_value": false,
			}
		)
		if not GFVariantData.get_option_bool(write_result, "ok"):
			_add_issue(
				state,
				&"property_write_failed",
				"Property write failed for %s: %s" % [property_id, GFVariantData.get_option_string(write_result, "error")]
			)
			return _make_decoded_failure(_get_first_issue(state))
		var property_writes: Array = GFVariantData.get_option_array(state, "decoded_property_writes")
		property_writes.append({
			"object": object_instance,
			"property_path": property_id,
			"old_value": GFVariantData.get_option_value(write_result, "old_value"),
		})
		state["decoded_property_writes"] = property_writes

	return { "ok": true, "value": object_instance, "error": "" }


static func _decode_direct_value(data: Dictionary, state: Dictionary) -> Dictionary:
	if not data.has(KEY_VALUE):
		_add_issue(state, &"encoded_shape_invalid", "Encoded direct value must declare a value field.")
		return _make_decoded_failure(_get_first_issue(state))
	var value: Variant = GFVariantData.get_option_value(data, KEY_VALUE)
	var actual_type: int = typeof(value)
	if not _is_direct_value_type(actual_type):
		_add_issue(state, &"value_type_not_allowed", "Encoded value type is not allowed: %s." % type_string(actual_type))
		return _make_decoded_failure(_get_first_issue(state))

	var raw_declared_type: Variant = GFVariantData.get_option_value(data, KEY_VARIANT_TYPE, null)
	if typeof(raw_declared_type) != TYPE_INT:
		_add_issue(state, &"value_type_invalid", "Encoded value Variant type must be an integer.")
		return _make_decoded_failure(_get_first_issue(state))
	var declared_type: int = raw_declared_type
	if declared_type < TYPE_NIL or declared_type >= TYPE_MAX:
		_add_issue(state, &"value_type_invalid", "Encoded value Variant type is invalid.")
		return _make_decoded_failure(_get_first_issue(state))
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
		result[property_id] = property_info.duplicate(true)
	return result


static func _value_matches_decodable_property(
	value: Variant,
	property_info: Dictionary,
	current_value: Variant
) -> bool:
	var property_type: int = GFVariantData.get_option_int(property_info, "type", TYPE_NIL)
	if value == null:
		return property_type == TYPE_NIL or property_type == TYPE_OBJECT
	if not GFObjectPropertyTools.value_matches_property_type(value, property_type):
		return false
	if current_value is Array and value is Array:
		var current_array: Array = current_value
		var value_array: Array = value
		if current_array.is_typed() and not current_array.is_same_typed(value_array):
			return false
	if current_value is Dictionary and value is Dictionary:
		var current_dictionary: Dictionary = current_value
		var value_dictionary: Dictionary = value
		if current_dictionary.is_typed() and not current_dictionary.is_same_typed(value_dictionary):
			return false
	if property_type != TYPE_OBJECT or value == null:
		return true
	if not value is Object:
		return false
	var declared_type: String = _get_decodable_object_property_type(property_info)
	var object_value: Object = value
	return declared_type.is_empty() or _object_matches_declared_type(object_value, declared_type)


static func _get_decodable_object_property_type(property_info: Dictionary) -> String:
	var hint: int = GFVariantData.get_option_int(property_info, "hint", PROPERTY_HINT_NONE)
	if hint == PROPERTY_HINT_RESOURCE_TYPE:
		var hint_string: String = GFVariantData.get_option_string(property_info, "hint_string").strip_edges()
		if not hint_string.is_empty():
			return hint_string
	return GFVariantData.get_option_string(property_info, "class_name").strip_edges()


static func _object_matches_declared_type(object_value: Object, declared_type: String) -> bool:
	for candidate_value: String in declared_type.split(",", false):
		var candidate: String = candidate_value.strip_edges()
		if candidate.is_empty():
			continue
		if _object_matches_single_declared_type(object_value, candidate):
			return true
	return false


static func _object_matches_single_declared_type(object_value: Object, declared_type: String) -> bool:
	if ClassDB.class_exists(declared_type) and object_value.is_class(declared_type):
		return true
	var script_variant: Variant = object_value.get_script()
	while script_variant is Script:
		var script_value: Script = script_variant
		if String(script_value.get_global_name()) == declared_type or script_value.resource_path == declared_type:
			return true
		script_variant = script_value.get_base_script()
	return false


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


static func _cleanup_failed_decode(state: Dictionary) -> void:
	var property_writes: Array = GFVariantData.get_option_array(state, "decoded_property_writes")
	for index: int in range(property_writes.size() - 1, -1, -1):
		var write_record: Dictionary = GFVariantData.as_dictionary(property_writes[index])
		var object_value: Variant = GFVariantData.get_option_value(write_record, "object")
		if not object_value is Object:
			continue
		var object_instance: Object = object_value
		if not is_instance_valid(object_instance):
			continue
		var property_path: NodePath = NodePath(GFVariantData.get_option_string(write_record, "property_path"))
		var rollback_result: Dictionary = GFObjectPropertyTools.write_property(
			object_instance,
			property_path,
			GFVariantData.get_option_value(write_record, "old_value"),
			{
				"check_writable": false,
				"check_type": false,
				"coerce_value": false,
			}
		)
		if not GFVariantData.get_option_bool(rollback_result, "ok"):
			_add_issue(
				state,
				&"property_rollback_failed",
				"Failed to roll back decoded property %s: %s" % [
					String(property_path),
					GFVariantData.get_option_string(rollback_result, "error"),
				]
			)
	var created_objects: Array = GFVariantData.get_option_array(state, "decoded_objects_created")
	for index: int in range(created_objects.size() - 1, -1, -1):
		var object_value: Variant = created_objects[index]
		if not object_value is Object:
			continue
		var object_instance: Object = object_value
		if not is_instance_valid(object_instance) or object_instance is RefCounted:
			continue
		object_instance.free()
	state["decoded_property_writes"] = []
	state["decoded_objects_created"] = []
	state["objects"] = {}


static func _make_state(policy: GFSafeResourceCodecPolicy, options: Dictionary) -> Dictionary:
	return {
		"issues": [],
		"object_ids": {},
		"next_object_id": 1,
		"decoded_property_writes": [],
		"decoded_objects_created": [],
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
