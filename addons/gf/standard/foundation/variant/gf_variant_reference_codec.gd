## GFVariantReferenceCodec: Resource 与 Node 引用的显式编码器。
##
## 只把 Resource 路径 / UID 或相对 root 的 NodePath 转成可持久化标记，
## 不序列化对象图、不加载任意脚本，也不从场景树全局搜索节点。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.3.0
class_name GFVariantReferenceCodec
extends RefCounted


# --- 常量 ---

## 引用标记根字段。
## [br]
## @api public
const REFERENCE_MARKER_KEY: String = "__gf_reference__"

## 引用标记格式版本字段。
## [br]
## @api public
const REFERENCE_VERSION_KEY: String = "version"

## 引用类型字段。
## [br]
## @api public
const REFERENCE_KIND_KEY: String = "kind"

## Resource 路径字段。
## [br]
## @api public
const REFERENCE_PATH_KEY: String = "path"

## Resource UID 字段。
## [br]
## @api public
const REFERENCE_UID_KEY: String = "uid"

## Resource 类型提示字段。
## [br]
## @api public
const REFERENCE_TYPE_HINT_KEY: String = "type_hint"

## NodePath 字段。
## [br]
## @api public
const REFERENCE_NODE_PATH_KEY: String = "node_path"

## 不支持对象的 class 字段。
## [br]
## @api public
const REFERENCE_UNSUPPORTED_CLASS_KEY: String = "class"

## options 中传入引用 root Node 的字段。
## [br]
## @api public
const OPTION_ROOT_NODE: String = "reference_root_node"

## options 中传入允许 Resource 解码路径根目录集合的字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPTION_ALLOWED_RESOURCE_ROOTS: String = "allowed_resource_roots"

## options 中传入允许 Resource 解码路径通配模式集合的字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const OPTION_ALLOWED_RESOURCE_PATTERNS: String = "allowed_resource_patterns"

## Resource 引用类型。
## [br]
## @api public
const REFERENCE_KIND_RESOURCE: String = "Resource"

## Node 引用类型。
## [br]
## @api public
const REFERENCE_KIND_NODE: String = "Node"

## 不支持对象引用类型。
## [br]
## @api public
const REFERENCE_KIND_UNSUPPORTED_OBJECT: String = "UnsupportedObject"

const _REFERENCE_MARKER_VERSION: int = 1


# --- 公共方法 ---

## 判断 value 是否为 GF 引用标记。
## [br]
## @api public
## [br]
## @param value: 待检查的值。
## [br]
## @schema value: Variant value that may contain a reference marker.
## [br]
## @return 是引用标记时返回 true。
static func is_reference_marker(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var dictionary: Dictionary = GFVariantData.as_dictionary(value)
	if dictionary.size() != 1 or not dictionary.has(REFERENCE_MARKER_KEY):
		return false
	var marker: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(dictionary, REFERENCE_MARKER_KEY))
	return (
		GFVariantData.get_option_int(marker, REFERENCE_VERSION_KEY, 0) == _REFERENCE_MARKER_VERSION
		and marker.has(REFERENCE_KIND_KEY)
	)


## 判断 value 是否为不支持对象标记。
## [br]
## @api public
## [br]
## @param value: 待检查的值。
## [br]
## @schema value: Variant value that may contain a reference marker.
## [br]
## @return 是不支持对象标记时返回 true。
static func is_unsupported_reference_marker(value: Variant) -> bool:
	if not is_reference_marker(value):
		return false
	var marker: Dictionary = get_reference_marker(value)
	return GFVariantData.get_option_string(marker, REFERENCE_KIND_KEY) == REFERENCE_KIND_UNSUPPORTED_OBJECT


## 提取引用标记内容。
## [br]
## @api public
## [br]
## @param value: 引用标记字典。
## [br]
## @schema value: Dictionary with a __gf_reference__ marker.
## [br]
## @return 标记内容；不是引用标记时返回空字典。
## [br]
## @schema return: Dictionary containing kind, version, and reference-specific fields.
static func get_reference_marker(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var dictionary: Dictionary = GFVariantData.as_dictionary(value)
	return GFVariantData.as_dictionary(GFVariantData.get_option_value(dictionary, REFERENCE_MARKER_KEY))


## 编码 Resource 引用。
## [br]
## @api public
## [br]
## @param resource: 要编码的资源。
## [br]
## @return 引用标记；资源为空或没有可保存路径时返回 UnsupportedObject 标记。
## [br]
## @schema return: Dictionary reference marker with kind Resource or UnsupportedObject.
static func encode_resource(resource: Resource) -> Dictionary:
	if resource == null:
		return _make_unsupported_marker("Resource")
	if resource.resource_path.is_empty():
		return _make_unsupported_marker(resource.get_class())

	return _make_reference_marker(REFERENCE_KIND_RESOURCE, {
		REFERENCE_PATH_KEY: resource.resource_path,
		REFERENCE_UID_KEY: _get_resource_uid_text(resource.resource_path),
		REFERENCE_TYPE_HINT_KEY: resource.get_class(),
	})


## 编码 Node 引用。
## [br]
## @api public
## [br]
## @param node: 要编码的节点。
## [br]
## @param root_node: NodePath 的解析 root；必须等于 node 或为 node 的祖先。
## [br]
## @return 引用标记；节点不在 root_node 下时返回 UnsupportedObject 标记。
## [br]
## @schema return: Dictionary reference marker with kind Node or UnsupportedObject.
static func encode_node(node: Node, root_node: Node) -> Dictionary:
	if node == null or root_node == null:
		return _make_unsupported_marker("Node")
	if root_node != node and not root_node.is_ancestor_of(node):
		return _make_unsupported_marker(node.get_class())

	return _make_reference_marker(REFERENCE_KIND_NODE, {
		REFERENCE_NODE_PATH_KEY: String(root_node.get_path_to(node)),
	})


## 编码 Object 引用。
## [br]
## @api public
## [br]
## @param value: 要编码的值。
## [br]
## @schema value: Variant Resource or Node reference.
## [br]
## @param options: 可选项；reference_root_node 用于编码 Node 的相对路径。
## [br]
## @schema options: Dictionary with optional reference_root_node: Node.
## [br]
## @return 引用标记；不支持的对象返回 UnsupportedObject 标记。
## [br]
## @schema return: Dictionary reference marker.
static func encode_reference(value: Variant, options: Dictionary = {}) -> Dictionary:
	if value is Resource:
		var resource: Resource = value
		return encode_resource(resource)
	if value is Node:
		var node: Node = value
		return encode_node(node, _get_root_node_option(options))
	if value is Object:
		var object: Object = value
		return _make_unsupported_marker(object.get_class())
	return _make_unsupported_marker("Variant")


## 解码引用标记。
## [br]
## @api public
## [br]
## @since 4.3.0
## [br]
## @param value: 引用标记字典。
## [br]
## @schema value: Dictionary reference marker produced by encode_reference().
## [br]
## @param options: 可选项；reference_root_node 用于解析 NodePath；Resource 解码必须显式提供 allowed_resource_roots 或 allowed_resource_patterns。
## [br]
## @schema options: Dictionary with optional reference_root_node: Node, allowed_resource_roots: PackedStringArray/Array[String], and allowed_resource_patterns: PackedStringArray/Array[String].
## [br]
## @return 解码结果。
## [br]
## @schema return: Dictionary with ok: bool, value: Variant, error: String, and kind: String.
static func decode_reference(value: Variant, options: Dictionary = {}) -> Dictionary:
	if not is_reference_marker(value):
		return _make_decode_result(false, null, "Value is not a GF reference marker.")

	var marker: Dictionary = get_reference_marker(value)
	var marker_kind: String = GFVariantData.get_option_string(marker, REFERENCE_KIND_KEY)
	match marker_kind:
		REFERENCE_KIND_RESOURCE:
			return _decode_resource_marker(marker, options)
		REFERENCE_KIND_NODE:
			return _decode_node_marker(marker, _get_root_node_option(options))
		REFERENCE_KIND_UNSUPPORTED_OBJECT:
			return _make_decode_result(false, null, "Unsupported object reference.", marker_kind)
	return _make_decode_result(false, null, "Unknown reference kind: %s" % marker_kind, marker_kind)


# --- 私有/辅助方法 ---

static func _make_reference_marker(marker_kind: String, data: Dictionary = {}) -> Dictionary:
	var marker: Dictionary = data.duplicate(true)
	marker[REFERENCE_VERSION_KEY] = _REFERENCE_MARKER_VERSION
	marker[REFERENCE_KIND_KEY] = marker_kind
	return {
		REFERENCE_MARKER_KEY: marker,
	}


static func _make_unsupported_marker(class_name_text: String) -> Dictionary:
	return _make_reference_marker(REFERENCE_KIND_UNSUPPORTED_OBJECT, {
		REFERENCE_UNSUPPORTED_CLASS_KEY: class_name_text,
	})


static func _decode_resource_marker(marker: Dictionary, options: Dictionary) -> Dictionary:
	if not _has_resource_path_policy(options):
		return _make_decode_result(false, null, "Resource decode requires allowed_resource_roots or allowed_resource_patterns.", REFERENCE_KIND_RESOURCE)

	var resource_paths: Array[String] = _get_resource_candidate_paths(marker)
	if resource_paths.is_empty():
		return _make_decode_result(false, null, "Resource path is empty.", REFERENCE_KIND_RESOURCE)

	var type_hint: String = GFVariantData.get_option_string(marker, REFERENCE_TYPE_HINT_KEY)
	var has_allowed_candidate: bool = false
	for resource_path: String in resource_paths:
		if not _resource_path_allowed(resource_path, options):
			continue
		has_allowed_candidate = true
		var resource: Resource = ResourceLoader.load(resource_path, type_hint)
		if resource != null:
			return _make_decode_result(true, resource, "", REFERENCE_KIND_RESOURCE)
	if _has_resource_path_policy(options) and not has_allowed_candidate:
		return _make_decode_result(false, null, "Resource path is not allowed: %s" % ", ".join(resource_paths), REFERENCE_KIND_RESOURCE)
	return _make_decode_result(false, null, "Resource could not be loaded: %s" % ", ".join(resource_paths), REFERENCE_KIND_RESOURCE)


static func _decode_node_marker(marker: Dictionary, root_node: Node) -> Dictionary:
	if root_node == null:
		return _make_decode_result(false, null, "Node reference root is null.", REFERENCE_KIND_NODE)
	var node_path_text: String = GFVariantData.get_option_string(marker, REFERENCE_NODE_PATH_KEY)
	if node_path_text.is_empty():
		return _make_decode_result(false, null, "NodePath is empty.", REFERENCE_KIND_NODE)

	var node_path: NodePath = NodePath(node_path_text)
	if node_path.is_absolute():
		return _make_decode_result(false, null, "NodePath must be relative to the reference root: %s" % node_path_text, REFERENCE_KIND_NODE)
	if _node_path_has_parent_segment(node_path):
		return _make_decode_result(false, null, "NodePath must not escape the reference root: %s" % node_path_text, REFERENCE_KIND_NODE)

	var node: Node = root_node.get_node_or_null(node_path)
	if node == null:
		return _make_decode_result(false, null, "Node could not be resolved: %s" % node_path_text, REFERENCE_KIND_NODE)
	if node != root_node and not root_node.is_ancestor_of(node):
		return _make_decode_result(false, null, "Node is outside the reference root: %s" % node_path_text, REFERENCE_KIND_NODE)
	return _make_decode_result(true, node, "", REFERENCE_KIND_NODE)


static func _get_resource_uid_text(resource_path: String) -> String:
	if resource_path.is_empty():
		return ""
	var uid: int = ResourceLoader.get_resource_uid(resource_path)
	if uid == ResourceUID.INVALID_ID:
		return ""
	return ResourceUID.id_to_text(uid)


static func _get_resource_path_from_uid(uid_text: String) -> String:
	if uid_text.is_empty():
		return ""
	var uid: int = ResourceUID.text_to_id(uid_text)
	if uid == ResourceUID.INVALID_ID or not ResourceUID.has_id(uid):
		return ""
	return ResourceUID.get_id_path(uid)


static func _get_resource_candidate_paths(marker: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var uid_path: String = _get_resource_path_from_uid(GFVariantData.get_option_string(marker, REFERENCE_UID_KEY))
	var fallback_path: String = GFVariantData.get_option_string(marker, REFERENCE_PATH_KEY)
	if not uid_path.is_empty():
		result.append(uid_path)
	if not fallback_path.is_empty() and fallback_path != uid_path:
		result.append(fallback_path)
	return result


static func _node_path_has_parent_segment(node_path: NodePath) -> bool:
	for index: int in range(node_path.get_name_count()):
		if String(node_path.get_name(index)) == "..":
			return true
	return false


static func _resource_path_allowed(resource_path: String, options: Dictionary) -> bool:
	if not _has_resource_path_policy(options):
		return false

	var normalized_path: String = GFPathTools.normalize_resource_path(resource_path)
	if normalized_path.is_empty():
		return false

	var allowed_roots: PackedStringArray = GFVariantData.get_option_packed_string_array(options, OPTION_ALLOWED_RESOURCE_ROOTS)
	for allowed_root: String in allowed_roots:
		if GFPathTools.is_path_under_root(normalized_path, allowed_root):
			return true

	var allowed_patterns: PackedStringArray = GFVariantData.get_option_packed_string_array(options, OPTION_ALLOWED_RESOURCE_PATTERNS)
	for allowed_pattern: String in allowed_patterns:
		var normalized_pattern: String = GFPathTools.normalize_resource_path(allowed_pattern, "", false)
		if not normalized_pattern.is_empty() and normalized_path.match(normalized_pattern):
			return true

	return false


static func _has_resource_path_policy(options: Dictionary) -> bool:
	return (
		not GFVariantData.get_option_packed_string_array(options, OPTION_ALLOWED_RESOURCE_ROOTS).is_empty()
		or not GFVariantData.get_option_packed_string_array(options, OPTION_ALLOWED_RESOURCE_PATTERNS).is_empty()
	)


static func _get_root_node_option(options: Dictionary) -> Node:
	var root_value: Variant = GFVariantData.get_option_value(options, OPTION_ROOT_NODE)
	if root_value is Node:
		var root_node: Node = root_value
		return root_node
	return null


static func _make_decode_result(
	ok: bool,
	value: Variant = null,
	error: String = "",
	marker_kind: String = ""
) -> Dictionary:
	return {
		"ok": ok,
		"value": value,
		"error": error,
		"kind": marker_kind,
	}
