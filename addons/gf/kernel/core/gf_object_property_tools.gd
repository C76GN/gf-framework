## GFObjectPropertyTools: Godot Object 属性访问辅助。
##
## 集中处理属性列表查询、属性路径读写、可写性判断和基础类型校验。
## 它不负责属性绑定、自动派发、表达式执行或业务字段解释。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
## [br]
## @layer kernel/core
class_name GFObjectPropertyTools
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共方法 ---

## 获取对象属性信息列表。
## [br]
## @api public
## [br]
## @param object: 目标对象。
## [br]
## @param usage_filter: 属性 usage 过滤掩码；小于 0 时不过滤。
## [br]
## @return 属性信息字典列表副本。
## [br]
## @schema return: Array of Godot property info Dictionary values.
static func get_property_infos(object: Object, usage_filter: int = -1) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(object):
		return result

	for property_info: Dictionary in object.get_property_list():
		if usage_filter >= 0 and (_GF_VARIANT_ACCESS_SCRIPT.get_option_int(property_info, "usage", 0) & usage_filter) == 0:
			continue
		result.append(property_info.duplicate(true))
	return result


## 获取对象属性信息映射。
## [br]
## @api public
## [br]
## @param object: 目标对象。
## [br]
## @param usage_filter: 属性 usage 过滤掩码；小于 0 时不过滤。
## [br]
## @return 以属性名为键的属性信息字典。
## [br]
## @schema return: Dictionary[StringName, Dictionary]
static func get_property_info_map(object: Object, usage_filter: int = -1) -> Dictionary:
	var result: Dictionary = {}
	for property_info: Dictionary in get_property_infos(object, usage_filter):
		var property_name: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(property_info, "name", &"")
		if property_name != &"":
			result[property_name] = property_info
	return result


## 获取对象属性名列表。
## [br]
## @api public
## [br]
## @param object: 目标对象。
## [br]
## @param usage_filter: 属性 usage 过滤掩码；小于 0 时不过滤。
## [br]
## @return 属性名列表。
static func get_property_names(object: Object, usage_filter: int = -1) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for property_info: Dictionary in get_property_infos(object, usage_filter):
		var property_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(property_info, "name", "")
		if not property_name.is_empty():
			var _append_result_81: Variant = result.append(property_name)
	return result


## 获取单个属性信息。
## [br]
## @api public
## [br]
## @param object: 目标对象。
## [br]
## @param property_name: 属性名。
## [br]
## @return 属性信息字典副本；不存在时返回空字典。
## [br]
## @schema return: Godot property info dictionary.
static func get_property_info(object: Object, property_name: StringName) -> Dictionary:
	if property_name == &"" or not is_instance_valid(object):
		return {}
	for property_info: Dictionary in object.get_property_list():
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(property_info, "name", &"") == property_name:
			return property_info.duplicate(true)
	return {}


## 检查对象是否声明了指定属性。
## [br]
## @api public
## [br]
## @param object: 目标对象。
## [br]
## @param property_name: 属性名。
## [br]
## @return 属性存在时返回 true。
static func has_property(object: Object, property_name: StringName) -> bool:
	return not get_property_info(object, property_name).is_empty()


## 检查对象是否声明了属性路径的根属性。
## [br]
## @api public
## [br]
## @param object: 目标对象。
## [br]
## @param property_path: 属性路径。
## [br]
## @return 根属性存在时返回 true。
static func has_property_path(object: Object, property_path: NodePath) -> bool:
	return has_property(object, get_root_property_name(property_path))


## 判断属性信息是否可写。
## [br]
## @api public
## [br]
## @param property_info: Godot 属性信息字典。
## [br]
## @schema property_info: Godot property info dictionary.
## [br]
## @return 未标记为只读时返回 true。
static func is_property_writable(property_info: Dictionary) -> bool:
	if property_info.is_empty():
		return false
	var usage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(property_info, "usage", 0)
	return (usage & PROPERTY_USAGE_READ_ONLY) == 0


## 检查对象属性路径是否可写。
## [br]
## @api public
## [br]
## @param object: 目标对象。
## [br]
## @param property_path: 属性路径。
## [br]
## @return 根属性存在且未标记为只读时返回 true。
static func can_write_property(object: Object, property_path: NodePath) -> bool:
	return is_property_writable(get_property_info(object, get_root_property_name(property_path)))


## 读取对象属性路径。
## [br]
## @api public
## [br]
## @param object: 目标对象。
## [br]
## @param property_path: 属性路径。
## [br]
## @param default_value: 对象、路径或根属性无效时返回的默认值。
## [br]
## @schema default_value: Variant fallback returned unchanged when the property cannot be read.
## [br]
## @return 属性值或默认值。
## [br]
## @schema return: Variant property value or the supplied default value.
static func read_property(
	object: Object,
	property_path: NodePath,
	default_value: Variant = null
) -> Variant:
	if not is_instance_valid(object) or property_path.is_empty():
		return default_value
	if not has_property_path(object, property_path):
		return default_value
	if not _property_path_can_resolve(object, property_path):
		return default_value
	return object.get_indexed(property_path)


## 写入对象属性路径。
## [br]
## @api public
## [br]
## @param object: 目标对象。
## [br]
## @param property_path: 属性路径。
## [br]
## @param value: 请求写入的值。
## [br]
## @param options: 可选项，支持 check_writable、check_type、coerce_value。
## [br]
## @schema value: Variant value requested for assignment.
## [br]
## @schema options: Dictionary with optional bool keys check_writable, check_type, and coerce_value.
## [br]
## @return 写入结果字典，包含 ok、error、property_name、old_value 与 new_value。
## [br]
## @schema return: Dictionary { ok: bool, error: String, property_name: StringName, old_value: Variant, new_value: Variant }.
static func write_property(
	object: Object,
	property_path: NodePath,
	value: Variant,
	options: Dictionary = {}
) -> Dictionary:
	if not is_instance_valid(object):
		return _make_write_result(false, "Object is null.")
	if property_path.is_empty():
		return _make_write_result(false, "Property path is empty.")

	var root_property: StringName = get_root_property_name(property_path)
	var property_info: Dictionary = get_property_info(object, root_property)
	if property_info.is_empty():
		return _make_write_result(false, "Missing property: %s" % String(root_property), root_property)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "check_writable", true) and not is_property_writable(property_info):
		return _make_write_result(false, "Property is not writable: %s" % String(root_property), root_property)
	if not _property_path_can_resolve(object, property_path):
		return _make_write_result(false, "Property path cannot be resolved: %s" % String(property_path), root_property)

	var old_value: Variant = object.get_indexed(property_path)
	var property_type: int = _get_effective_property_type(property_path, property_info, old_value)
	var value_to_write: Variant = value
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "check_type", true) and not value_matches_property_type(value, property_type):
		return _make_write_result(false, "Property type mismatch: %s" % String(root_property), root_property, old_value)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "coerce_value", true):
		value_to_write = coerce_property_value(value, property_type)

	object.set_indexed(property_path, value_to_write)
	return _make_write_result(true, "", root_property, old_value, object.get_indexed(property_path))


## 检查值是否可写入指定 Variant 类型。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @schema value: Variant value to compare against the requested Variant.Type.
## [br]
## @param property_type: Variant.Type 常量。
## [br]
## @return 类型兼容时返回 true。
static func value_matches_property_type(value: Variant, property_type: int) -> bool:
	if value == null or property_type == TYPE_NIL:
		return true
	match property_type:
		TYPE_BOOL:
			return typeof(value) == TYPE_BOOL
		TYPE_INT:
			return typeof(value) == TYPE_INT
		TYPE_FLOAT:
			return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT
		TYPE_STRING:
			return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
		TYPE_STRING_NAME:
			return typeof(value) == TYPE_STRING_NAME or typeof(value) == TYPE_STRING
		TYPE_VECTOR2:
			return value is Vector2
		TYPE_VECTOR2I:
			return value is Vector2i
		TYPE_RECT2:
			return value is Rect2
		TYPE_RECT2I:
			return value is Rect2i
		TYPE_VECTOR3:
			return value is Vector3
		TYPE_VECTOR3I:
			return value is Vector3i
		TYPE_TRANSFORM2D:
			return value is Transform2D
		TYPE_VECTOR4:
			return value is Vector4
		TYPE_VECTOR4I:
			return value is Vector4i
		TYPE_PLANE:
			return value is Plane
		TYPE_QUATERNION:
			return value is Quaternion
		TYPE_AABB:
			return value is AABB
		TYPE_BASIS:
			return value is Basis
		TYPE_TRANSFORM3D:
			return value is Transform3D
		TYPE_PROJECTION:
			return value is Projection
		TYPE_COLOR:
			return value is Color
		TYPE_NODE_PATH:
			return value is NodePath or typeof(value) == TYPE_STRING
		TYPE_DICTIONARY:
			return value is Dictionary
		TYPE_ARRAY:
			return value is Array
		TYPE_PACKED_BYTE_ARRAY:
			return value is PackedByteArray
		TYPE_PACKED_INT32_ARRAY:
			return value is PackedInt32Array
		TYPE_PACKED_INT64_ARRAY:
			return value is PackedInt64Array
		TYPE_PACKED_FLOAT32_ARRAY:
			return value is PackedFloat32Array
		TYPE_PACKED_FLOAT64_ARRAY:
			return value is PackedFloat64Array
		TYPE_PACKED_STRING_ARRAY:
			return value is PackedStringArray
		TYPE_PACKED_VECTOR2_ARRAY:
			return value is PackedVector2Array
		TYPE_PACKED_VECTOR3_ARRAY:
			return value is PackedVector3Array
		TYPE_PACKED_COLOR_ARRAY:
			return value is PackedColorArray
		TYPE_OBJECT:
			return value is Object
		_:
			return typeof(value) == property_type


## 将值转换为指定 Variant 类型的基础兼容形式。
## [br]
## @api public
## [br]
## @param value: 输入值。
## [br]
## @schema value: Variant value to coerce.
## [br]
## @param property_type: Variant.Type 常量。
## [br]
## @return 转换后的值；不支持转换时返回原值。
## [br]
## @schema return: Variant coerced value or original value.
static func coerce_property_value(value: Variant, property_type: int) -> Variant:
	match property_type:
		TYPE_FLOAT:
			return _GF_VARIANT_ACCESS_SCRIPT.to_float(value)
		TYPE_STRING:
			return _GF_VARIANT_ACCESS_SCRIPT.to_text(value)
		TYPE_STRING_NAME:
			return _GF_VARIANT_ACCESS_SCRIPT.to_string_name(value)
		TYPE_NODE_PATH:
			if value is String or value is StringName or value is NodePath:
				return NodePath(_GF_VARIANT_ACCESS_SCRIPT.to_text(value))
			return value
		_:
			return value


## 将对象声明的属性导出为 Dictionary。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param object: 目标对象。
## [br]
## @param options: 可选项，支持 usage_filter、include_properties、exclude_properties、include_null、copy_values、duplicate_resources、sort_keys。
## [br]
## @schema options: Dictionary with optional keys usage_filter: int, include_properties: Array[String] or PackedStringArray, exclude_properties: Array[String] or PackedStringArray, include_null: bool, copy_values: bool, duplicate_resources: bool, sort_keys: bool.
## [br]
## @return 以属性名 String 为键的属性值字典。
## [br]
## @schema return: Dictionary[String, Variant] containing direct declared object properties.
static func object_to_dictionary(object: Object, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	if not is_instance_valid(object):
		return result

	var usage_filter: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "usage_filter", PROPERTY_USAGE_STORAGE)
	var include_filter: Dictionary = _make_property_name_filter(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(options, "include_properties")
	)
	var exclude_filter: Dictionary = _make_property_name_filter(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(options, "exclude_properties")
	)
	var include_null: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_null", true)
	var copy_values: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "copy_values", true)
	var duplicate_resources: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "duplicate_resources", false)
	var sort_keys: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "sort_keys", true)
	var property_names: PackedStringArray = PackedStringArray()
	var property_values: Dictionary = {}

	for property_info: Dictionary in get_property_infos(object, usage_filter):
		var property_name: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(property_info, "name", &"")
		if not _should_snapshot_property(property_name, include_filter, exclude_filter):
			continue
		var property_value: Variant = object.get(property_name)
		if property_value == null and not include_null:
			continue
		if copy_values:
			property_value = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(
				property_value,
				true,
				duplicate_resources
			)
		var property_key: String = String(property_name)
		var _append_result_264: bool = property_names.append(property_key)
		property_values[property_key] = property_value

	if sort_keys:
		property_names.sort()
	for property_key: String in property_names:
		result[property_key] = property_values[property_key]
	return result


## 将 Dictionary 字段批量写回对象属性。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param object: 目标对象。
## [br]
## @param values: 以属性名为键的字段字典。
## [br]
## @param options: 可选项，支持 check_writable、check_type、coerce_value、ignore_unknown_properties、copy_values、duplicate_resources。
## [br]
## @schema values: Dictionary[String or StringName, Variant] containing direct property assignments.
## [br]
## @schema options: Dictionary with optional bool keys check_writable, check_type, coerce_value, ignore_unknown_properties, copy_values, and duplicate_resources.
## [br]
## @return 写入报告，包含 ok、applied_count、skipped_count 与 issues。
## [br]
## @schema return: Dictionary { ok: bool, applied_count: int, skipped_count: int, issues: Array[Dictionary] }.
static func apply_dictionary(object: Object, values: Dictionary, options: Dictionary = {}) -> Dictionary:
	var issues: Array[Dictionary] = []
	var report: Dictionary = {
		"ok": true,
		"applied_count": 0,
		"skipped_count": 0,
		"issues": issues,
	}
	if not is_instance_valid(object):
		_append_apply_issue(issues, &"", "invalid_object", "Object is null.")
		report["ok"] = false
		report["skipped_count"] = values.size()
		return report

	var ignore_unknown: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		options,
		"ignore_unknown_properties",
		false
	)
	var copy_values: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "copy_values", true)
	var duplicate_resources: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "duplicate_resources", false)
	var write_options: Dictionary = {
		"check_writable": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "check_writable", true),
		"check_type": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "check_type", true),
		"coerce_value": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "coerce_value", true),
	}

	for key: Variant in values.keys():
		var property_name: StringName = _GF_VARIANT_ACCESS_SCRIPT.to_string_name(key)
		if property_name == &"":
			_append_apply_issue(issues, property_name, "invalid_property", "Property name is empty.")
			report["skipped_count"] += 1
			continue
		if not has_property(object, property_name):
			if not ignore_unknown:
				_append_apply_issue(
					issues,
					property_name,
					"unknown_property",
					"Missing property: %s" % String(property_name)
				)
			report["skipped_count"] += 1
			continue

		var value_to_write: Variant = values[key]
		if copy_values:
			value_to_write = _GF_VARIANT_ACCESS_SCRIPT.duplicate_variant(
				value_to_write,
				true,
				duplicate_resources
			)
		var write_result: Dictionary = write_property(
			object,
			NodePath(String(property_name)),
			value_to_write,
			write_options
		)
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(write_result, "ok", false):
			report["applied_count"] += 1
		else:
			_append_apply_issue(
				issues,
				property_name,
				"write_failed",
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(write_result, "error", "Write failed.")
			)
			report["skipped_count"] += 1

	report["ok"] = issues.is_empty()
	return report


## 获取属性路径的根属性名。
## [br]
## @api public
## [br]
## @param property_path: 属性路径。
## [br]
## @return 根属性名；无效路径返回空 StringName。
static func get_root_property_name(property_path: NodePath) -> StringName:
	if property_path.is_empty():
		return &""
	if property_path.get_name_count() > 0:
		return StringName(property_path.get_name(0))
	if property_path.get_subname_count() > 0:
		return StringName(property_path.get_subname(0))
	return StringName(String(property_path))


# --- 私有/辅助方法 ---

static func _get_effective_property_type(
	property_path: NodePath,
	property_info: Dictionary,
	current_value: Variant
) -> int:
	if _is_direct_property_path(property_path):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(property_info, "type", TYPE_NIL)
	if current_value != null:
		return typeof(current_value)
	return TYPE_NIL


static func _is_direct_property_path(property_path: NodePath) -> bool:
	return property_path.get_name_count() <= 1 and property_path.get_subname_count() == 0


static func _property_path_can_resolve(object: Object, property_path: NodePath) -> bool:
	if not is_instance_valid(object) or property_path.is_empty():
		return false
	var root_property: StringName = get_root_property_name(property_path)
	if root_property == &"" or not has_property(object, root_property):
		return false
	if _is_direct_property_path(property_path):
		return true
	if property_path.get_name_count() > 1:
		return false

	var current_value: Variant = object.get(root_property)
	var subname_start: int = 0
	if property_path.get_name_count() == 0 and property_path.get_subname_count() > 0:
		subname_start = 1
	for subname_index: int in range(subname_start, property_path.get_subname_count()):
		var subname: StringName = StringName(property_path.get_subname(subname_index))
		var subvalue: Dictionary = _get_supported_subproperty_value(current_value, subname)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(subvalue, "ok", false):
			return false
		current_value = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(subvalue, "value")
	return true


static func _get_supported_subproperty_value(value: Variant, subname: StringName) -> Dictionary:
	if subname == &"":
		return { "ok": false }
	if value is Object:
		var object_value: Object = value
		if not is_instance_valid(object_value) or not has_property(object_value, subname):
			return { "ok": false }
		return { "ok": true, "value": object_value.get(subname) }

	match typeof(value):
		TYPE_VECTOR2:
			var vector2_value: Vector2 = value
			match subname:
				&"x":
					return { "ok": true, "value": vector2_value.x }
				&"y":
					return { "ok": true, "value": vector2_value.y }
		TYPE_VECTOR2I:
			var vector2i_value: Vector2i = value
			match subname:
				&"x":
					return { "ok": true, "value": vector2i_value.x }
				&"y":
					return { "ok": true, "value": vector2i_value.y }
		TYPE_VECTOR3:
			var vector3_value: Vector3 = value
			match subname:
				&"x":
					return { "ok": true, "value": vector3_value.x }
				&"y":
					return { "ok": true, "value": vector3_value.y }
				&"z":
					return { "ok": true, "value": vector3_value.z }
		TYPE_VECTOR3I:
			var vector3i_value: Vector3i = value
			match subname:
				&"x":
					return { "ok": true, "value": vector3i_value.x }
				&"y":
					return { "ok": true, "value": vector3i_value.y }
				&"z":
					return { "ok": true, "value": vector3i_value.z }
		TYPE_VECTOR4:
			var vector4_value: Vector4 = value
			match subname:
				&"x":
					return { "ok": true, "value": vector4_value.x }
				&"y":
					return { "ok": true, "value": vector4_value.y }
				&"z":
					return { "ok": true, "value": vector4_value.z }
				&"w":
					return { "ok": true, "value": vector4_value.w }
		TYPE_VECTOR4I:
			var vector4i_value: Vector4i = value
			match subname:
				&"x":
					return { "ok": true, "value": vector4i_value.x }
				&"y":
					return { "ok": true, "value": vector4i_value.y }
				&"z":
					return { "ok": true, "value": vector4i_value.z }
				&"w":
					return { "ok": true, "value": vector4i_value.w }
		TYPE_COLOR:
			var color_value: Color = value
			match subname:
				&"r":
					return { "ok": true, "value": color_value.r }
				&"g":
					return { "ok": true, "value": color_value.g }
				&"b":
					return { "ok": true, "value": color_value.b }
				&"a":
					return { "ok": true, "value": color_value.a }
		TYPE_QUATERNION:
			var quaternion_value: Quaternion = value
			match subname:
				&"x":
					return { "ok": true, "value": quaternion_value.x }
				&"y":
					return { "ok": true, "value": quaternion_value.y }
				&"z":
					return { "ok": true, "value": quaternion_value.z }
				&"w":
					return { "ok": true, "value": quaternion_value.w }
		TYPE_RECT2:
			var rect2_value: Rect2 = value
			match subname:
				&"position":
					return { "ok": true, "value": rect2_value.position }
				&"size":
					return { "ok": true, "value": rect2_value.size }
				&"end":
					return { "ok": true, "value": rect2_value.end }
		TYPE_RECT2I:
			var rect2i_value: Rect2i = value
			match subname:
				&"position":
					return { "ok": true, "value": rect2i_value.position }
				&"size":
					return { "ok": true, "value": rect2i_value.size }
				&"end":
					return { "ok": true, "value": rect2i_value.end }
		TYPE_AABB:
			var aabb_value: AABB = value
			match subname:
				&"position":
					return { "ok": true, "value": aabb_value.position }
				&"size":
					return { "ok": true, "value": aabb_value.size }
				&"end":
					return { "ok": true, "value": aabb_value.end }
		TYPE_TRANSFORM2D:
			var transform2d_value: Transform2D = value
			match subname:
				&"x":
					return { "ok": true, "value": transform2d_value.x }
				&"y":
					return { "ok": true, "value": transform2d_value.y }
				&"origin":
					return { "ok": true, "value": transform2d_value.origin }
		TYPE_BASIS:
			var basis_value: Basis = value
			match subname:
				&"x":
					return { "ok": true, "value": basis_value.x }
				&"y":
					return { "ok": true, "value": basis_value.y }
				&"z":
					return { "ok": true, "value": basis_value.z }
		TYPE_TRANSFORM3D:
			var transform3d_value: Transform3D = value
			match subname:
				&"basis":
					return { "ok": true, "value": transform3d_value.basis }
				&"origin":
					return { "ok": true, "value": transform3d_value.origin }
		_:
			pass
	return { "ok": false }


static func _make_property_name_filter(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is PackedStringArray:
		var packed_names: PackedStringArray = value
		for property_name: String in packed_names:
			if not property_name.is_empty():
				result[StringName(property_name)] = true
	elif value is Array:
		var names: Array = value
		for item: Variant in names:
			var item_name: StringName = _GF_VARIANT_ACCESS_SCRIPT.to_string_name(item)
			if item_name != &"":
				result[item_name] = true
	elif value is String or value is StringName:
		var single_name: StringName = _GF_VARIANT_ACCESS_SCRIPT.to_string_name(value)
		if single_name != &"":
			result[single_name] = true
	return result


static func _should_snapshot_property(
	property_name: StringName,
	include_filter: Dictionary,
	exclude_filter: Dictionary
) -> bool:
	if property_name == &"":
		return false
	if not include_filter.is_empty() and not include_filter.has(property_name):
		return false
	if exclude_filter.has(property_name):
		return false
	return true


static func _append_apply_issue(
	issues: Array[Dictionary],
	property_name: StringName,
	kind: String,
	message: String
) -> void:
	issues.append({
		"property_name": property_name,
		"kind": kind,
		"message": message,
	})


static func _make_write_result(
	ok: bool,
	error_message: String = "",
	property_name: StringName = &"",
	old_value: Variant = null,
	new_value: Variant = null
) -> Dictionary:
	return {
		"ok": ok,
		"error": error_message,
		"property_name": property_name,
		"old_value": old_value,
		"new_value": new_value,
	}
