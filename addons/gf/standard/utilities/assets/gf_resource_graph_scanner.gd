## GFResourceGraphScanner: 通用 Object / Resource 图扫描器。
##
## 递归读取 Resource、Object、Array 和 Dictionary 的属性图，生成可用于诊断、编辑器工具和测试的结构化报告。
## 它只描述图形状，不修改对象、不注入编辑器 UI，也不解释资源业务含义。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
class_name GFResourceGraphScanner
extends RefCounted


# --- 常量 ---

## 默认递归深度上限。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEFAULT_MAX_DEPTH: int = 32

## 默认节点数量上限。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEFAULT_MAX_NODES: int = 10000


const _DEFAULT_EXCLUDED_PROPERTIES: PackedStringArray = [
	"script",
	"resource_local_to_scene",
	"resource_name",
	"resource_path",
	"resource_scene_unique_id",
]


# --- 公共方法 ---

## 扫描一个 Variant 图并返回结构化报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param root: 扫描根对象，可为 Resource、Object、Array、Dictionary 或标量。
## [br]
## @param options: 扫描选项。
## [br]
## @return 资源图报告。
## [br]
## @schema root: Variant graph root.
## [br]
## @schema options: Dictionary，可包含 max_depth、max_nodes、include_nodes、include_scalar、include_null、include_all_properties、excluded_properties。
## [br]
## @schema return: Dictionary with ok, nodes, node_count, cycle_count, truncated, depth_limit_reached, and root_type.
static func scan(root: Variant, options: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"nodes": [],
		"visited_objects": {},
		"active_objects": {},
		"cycle_count": 0,
		"truncated": false,
		"depth_limit_reached": false,
	}
	_scan_value(root, "", [], 0, options, state)
	var nodes: Array = GFVariantData.as_array(state["nodes"])
	return {
		"ok": not GFVariantData.get_option_bool(state, "truncated"),
		"root_type": _get_value_type_name(root),
		"nodes": nodes,
		"node_count": nodes.size(),
		"cycle_count": GFVariantData.get_option_int(state, "cycle_count"),
		"truncated": GFVariantData.get_option_bool(state, "truncated"),
		"depth_limit_reached": GFVariantData.get_option_bool(state, "depth_limit_reached"),
	}


## 只返回扫描到的路径列表。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param root: 扫描根对象。
## [br]
## @param options: 扫描选项，见 scan()。
## [br]
## @return 排序后的路径列表。
## [br]
## @schema root: Variant graph root.
## [br]
## @schema options: Dictionary，可包含 max_depth、max_nodes、include_nodes、include_scalar、include_null、include_all_properties、excluded_properties。
static func collect_paths(root: Variant, options: Dictionary = {}) -> PackedStringArray:
	var report: Dictionary = scan(root, options)
	var result: PackedStringArray = PackedStringArray()
	for node_value: Variant in GFVariantData.get_option_array(report, "nodes"):
		var node: Dictionary = GFVariantData.as_dictionary(node_value)
		var path: String = GFVariantData.get_option_string(node, "path")
		if not path.is_empty() and not result.has(path):
			var _appended: bool = result.append(path)
	result.sort()
	return result


# --- 私有/辅助方法 ---

static func _scan_value(
	value: Variant,
	path: String,
	path_segments: Array,
	depth: int,
	options: Dictionary,
	state: Dictionary
) -> void:
	if _is_truncated(state):
		return
	if not _can_append_node(state, options):
		state["truncated"] = true
		return
	if depth > _get_max_depth(options):
		state["depth_limit_reached"] = true
		return

	if value == null:
		if GFVariantData.get_option_bool(options, "include_null", false):
			_append_node(state, _make_value_node(value, path, path_segments, depth))
		return

	if value is Object:
		_scan_object(value, path, path_segments, depth, options, state)
		return

	if value is Array:
		_scan_array(value, path, path_segments, depth, options, state)
		return

	if value is Dictionary:
		_scan_dictionary(value, path, path_segments, depth, options, state)
		return

	if GFVariantData.get_option_bool(options, "include_scalar", false):
		_append_node(state, _make_value_node(value, path, path_segments, depth))


static func _scan_object(
	value: Variant,
	path: String,
	path_segments: Array,
	depth: int,
	options: Dictionary,
	state: Dictionary
) -> void:
	if not (value is Object) or not is_instance_valid(value):
		return
	var object_value: Object = value
	var instance_id: int = object_value.get_instance_id()
	var visited: Dictionary = GFVariantData.as_dictionary(state["visited_objects"])
	var active: Dictionary = GFVariantData.as_dictionary(state["active_objects"])
	if active.has(instance_id):
		_append_cycle_node(object_value, path, path_segments, depth, state)
		return
	if visited.has(instance_id):
		_append_node(state, _make_object_node(object_value, path, path_segments, depth, false, true))
		return

	visited[instance_id] = true
	state["visited_objects"] = visited
	active[instance_id] = true
	state["active_objects"] = active
	_append_node(state, _make_object_node(object_value, path, path_segments, depth, false, false))

	if object_value is Node and not GFVariantData.get_option_bool(options, "include_nodes", false):
		var _node_active_removed: bool = active.erase(instance_id)
		state["active_objects"] = active
		return

	for property_value: Variant in object_value.get_property_list():
		if not property_value is Dictionary:
			continue
		var property_info: Dictionary = property_value
		if not _property_should_scan(property_info, options):
			continue
		var property_name: String = GFVariantData.get_option_string(property_info, "name")
		var child_path_segments: Array = path_segments.duplicate()
		child_path_segments.append(property_name)
		var child_path: String = _format_path(child_path_segments)
		_scan_value(object_value.get(property_name), child_path, child_path_segments, depth + 1, options, state)
	var _active_removed: bool = active.erase(instance_id)
	state["active_objects"] = active


static func _scan_array(
	value: Variant,
	path: String,
	path_segments: Array,
	depth: int,
	options: Dictionary,
	state: Dictionary
) -> void:
	var array: Array = value
	_append_node(state, _make_value_node(array, path, path_segments, depth))
	for index: int in range(array.size()):
		var child_path_segments: Array = path_segments.duplicate()
		child_path_segments.append(index)
		var child_path: String = _format_path(child_path_segments)
		_scan_value(array[index], child_path, child_path_segments, depth + 1, options, state)


static func _scan_dictionary(
	value: Variant,
	path: String,
	path_segments: Array,
	depth: int,
	options: Dictionary,
	state: Dictionary
) -> void:
	var dictionary: Dictionary = value
	_append_node(state, _make_value_node(dictionary, path, path_segments, depth))
	for key: Variant in dictionary.keys():
		var child_path_segments: Array = path_segments.duplicate()
		child_path_segments.append(GFVariantData.to_text(key))
		var child_path: String = _format_path(child_path_segments)
		_scan_value(dictionary[key], child_path, child_path_segments, depth + 1, options, state)


static func _property_should_scan(property_info: Dictionary, options: Dictionary) -> bool:
	var property_name: String = GFVariantData.get_option_string(property_info, "name")
	if property_name.is_empty():
		return false
	if _get_excluded_properties(options).has(property_name):
		return false
	if GFVariantData.get_option_bool(options, "include_all_properties", false):
		return true
	var usage: int = GFVariantData.get_option_int(property_info, "usage")
	return (usage & PROPERTY_USAGE_STORAGE) != 0 or (usage & PROPERTY_USAGE_EDITOR) != 0


static func _get_excluded_properties(options: Dictionary) -> PackedStringArray:
	return GFVariantData.get_option_packed_string_array(
		options,
		"excluded_properties",
		_DEFAULT_EXCLUDED_PROPERTIES
	)


static func _append_cycle_node(object_value: Object, path: String, path_segments: Array, depth: int, state: Dictionary) -> void:
	state["cycle_count"] = GFVariantData.get_option_int(state, "cycle_count") + 1
	_append_node(state, _make_object_node(object_value, path, path_segments, depth, true, false))


static func _append_node(state: Dictionary, node: Dictionary) -> void:
	var nodes: Array = GFVariantData.as_array(state["nodes"])
	nodes.append(node)
	state["nodes"] = nodes


static func _can_append_node(state: Dictionary, options: Dictionary) -> bool:
	var max_nodes: int = maxi(GFVariantData.get_option_int(options, "max_nodes", DEFAULT_MAX_NODES), 0)
	if max_nodes <= 0:
		return true
	var nodes: Array = GFVariantData.as_array(state["nodes"])
	return nodes.size() < max_nodes


static func _get_max_depth(options: Dictionary) -> int:
	return maxi(GFVariantData.get_option_int(options, "max_depth", DEFAULT_MAX_DEPTH), 0)


static func _is_truncated(state: Dictionary) -> bool:
	return GFVariantData.get_option_bool(state, "truncated")


static func _make_object_node(
	object_value: Object,
	path: String,
	path_segments: Array,
	depth: int,
	cycle: bool,
	repeated_reference: bool
) -> Dictionary:
	var resource_path: String = ""
	var built_in: bool = false
	if object_value is Resource:
		var resource: Resource = object_value
		resource_path = resource.resource_path
		built_in = resource_path.is_empty()
	return {
		"path": path,
		"path_segments": path_segments.duplicate(true),
		"depth": depth,
		"value_type": _get_value_type_name(object_value),
		"object_class": object_value.get_class(),
		"instance_id": object_value.get_instance_id(),
		"resource_path": resource_path,
		"built_in": built_in,
		"cycle": cycle,
		"repeated_reference": repeated_reference,
	}


static func _make_value_node(value: Variant, path: String, path_segments: Array, depth: int) -> Dictionary:
	return {
		"path": path,
		"path_segments": path_segments.duplicate(true),
		"depth": depth,
		"value_type": _get_value_type_name(value),
		"object_class": "",
		"instance_id": 0,
		"resource_path": "",
		"built_in": false,
		"cycle": false,
		"repeated_reference": false,
	}


static func _get_value_type_name(value: Variant) -> String:
	if value is Object and is_instance_valid(value):
		var object_value: Object = value
		var script_value: Variant = object_value.get_script()
		if script_value is Script:
			var script: Script = script_value
			var global_name: String = GFVariantData.to_text(script.get_global_name())
			if not global_name.is_empty():
				return global_name
		return object_value.get_class()
	return type_string(typeof(value))


static func _format_path(path_segments: Array) -> String:
	var result: String = ""
	for segment: Variant in path_segments:
		if segment is int:
			var segment_index: int = segment
			result += "[%d]" % segment_index
			continue
		var key: String = GFVariantData.to_text(segment)
		if _is_simple_key(key):
			result = key if result.is_empty() else result + "." + key
		else:
			result += "[\"%s\"]" % key.replace("\\", "\\\\").replace("\"", "\\\"")
	return result


static func _is_simple_key(text: String) -> bool:
	if text.is_empty():
		return false
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		if index == 0:
			if not _is_ascii_letter_or_underscore(code):
				return false
		elif not _is_ascii_letter_or_underscore(code) and not _is_ascii_digit(code):
			return false
	return true


static func _is_ascii_letter_or_underscore(code: int) -> bool:
	return code == 95 or (code >= 65 and code <= 90) or (code >= 97 and code <= 122)


static func _is_ascii_digit(code: int) -> bool:
	return code >= 48 and code <= 57
