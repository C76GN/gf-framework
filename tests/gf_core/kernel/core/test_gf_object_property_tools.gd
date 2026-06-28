## 测试 GFObjectPropertyTools 的属性查询、校验与安全读写。
extends GutTest


const GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 测试用例 ---

func test_get_property_info_and_names_use_usage_filter() -> void:
	var object: DynamicPropertyObject = DynamicPropertyObject.new()

	var names: PackedStringArray = GFObjectPropertyTools.get_property_names(object, PROPERTY_USAGE_STORAGE)
	var info: Dictionary = GFObjectPropertyTools.get_property_info(object, &"dynamic_number")

	assert_true(names.has("dynamic_number"), "应返回匹配 usage 的动态属性。")
	assert_false(names.has("editor_only"), "不匹配 usage 的属性应被过滤。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(info, "type", TYPE_NIL), TYPE_INT)


func test_read_property_returns_default_for_missing_property() -> void:
	var object: DynamicPropertyObject = DynamicPropertyObject.new()

	var value: Variant = GFObjectPropertyTools.read_property(object, ^"missing", "fallback")

	assert_eq(GF_VARIANT_ACCESS.to_text(value), "fallback")


func test_write_property_rejects_read_only_property() -> void:
	var object: DynamicPropertyObject = DynamicPropertyObject.new()

	var result: Dictionary = GFObjectPropertyTools.write_property(object, ^"locked_number", 12)

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"))
	assert_true(GF_VARIANT_ACCESS.get_option_string(result, "error").contains("Property is not writable: locked_number"))
	assert_eq(object.locked_number_value, 7)


func test_write_property_rejects_type_mismatch_before_setting() -> void:
	var node: Node2D = Node2D.new()

	var result: Dictionary = GFObjectPropertyTools.write_property(node, ^"position", "bad-position")

	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"))
	assert_true(GF_VARIANT_ACCESS.get_option_string(result, "error").contains("Property type mismatch: position"))
	assert_eq(node.position, Vector2.ZERO)

	node.free()


func test_write_property_supports_indexed_subproperty() -> void:
	var node: Node2D = Node2D.new()
	node.position = Vector2(1.0, 2.0)

	var result: Dictionary = GFObjectPropertyTools.write_property(node, ^"position:x", 4.5)

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"))
	assert_eq(node.position, Vector2(4.5, 2.0))
	assert_eq(GF_VARIANT_ACCESS.get_option_float(result, "old_value"), 1.0)
	assert_eq(GF_VARIANT_ACCESS.get_option_float(result, "new_value"), 4.5)

	node.free()


func test_indexed_subproperty_rejects_unresolvable_path_before_godot_error() -> void:
	var node: Node2D = Node2D.new()
	node.position = Vector2(1.0, 2.0)

	var read_value: Variant = GFObjectPropertyTools.read_property(node, ^"position:missing", "fallback")
	var result: Dictionary = GFObjectPropertyTools.write_property(node, ^"position:missing", 4.5)

	assert_eq(GF_VARIANT_ACCESS.to_text(read_value), "fallback", "无法解析的子属性读取应返回默认值。")
	assert_false(GF_VARIANT_ACCESS.get_option_bool(result, "ok"), "无法解析的子属性写入应失败。")
	assert_true(GF_VARIANT_ACCESS.get_option_string(result, "error").contains("Property path cannot be resolved"))
	assert_eq(node.position, Vector2(1.0, 2.0), "失败写入不应改变原始属性。")

	node.free()


func test_write_property_coerces_supported_value_types() -> void:
	var object: DynamicPropertyObject = DynamicPropertyObject.new()

	var result: Dictionary = GFObjectPropertyTools.write_property(object, ^"target_path", "Child/Label")

	assert_true(GF_VARIANT_ACCESS.get_option_bool(result, "ok"))
	assert_eq(object.target_path_value, ^"Child/Label")


func test_object_to_dictionary_filters_and_copies_values() -> void:
	var object: DynamicPropertyObject = DynamicPropertyObject.new()
	var snapshot: Dictionary = GFObjectPropertyTools.object_to_dictionary(object, {
		"include_properties": PackedStringArray(["dynamic_number", "payload"]),
	})
	var payload: Dictionary = GF_VARIANT_ACCESS.get_option_dictionary(snapshot, "payload")
	var tags: Array = GF_VARIANT_ACCESS.get_option_array(payload, "tags")
	tags.append("mutated")
	var object_tags: Array = GF_VARIANT_ACCESS.get_option_array(object.payload_value, "tags")

	assert_eq(snapshot.keys(), ["dynamic_number", "payload"], "属性快照应只包含请求的 storage 属性并保持排序。")
	assert_eq(object_tags, ["base"], "快照中的集合值应默认复制，避免污染对象。")


func test_apply_dictionary_reports_partial_writes_and_unknown_properties() -> void:
	var object: DynamicPropertyObject = DynamicPropertyObject.new()

	var report: Dictionary = GFObjectPropertyTools.apply_dictionary(object, {
		"dynamic_number": 12,
		"target_path": "Child/Label",
		"missing": 1,
	})

	assert_false(GF_VARIANT_ACCESS.get_option_bool(report, "ok"), "未知属性应记录 issue。")
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "applied_count"), 2)
	assert_eq(GF_VARIANT_ACCESS.get_option_int(report, "skipped_count"), 1)
	assert_eq(object.dynamic_number_value, 12)
	assert_eq(object.target_path_value, ^"Child/Label")


# --- 内部类 ---

class DynamicPropertyObject extends RefCounted:
	var dynamic_number_value: int = 5
	var locked_number_value: int = 7
	var target_path_value: NodePath = NodePath("")
	var payload_value: Dictionary = {
		"tags": ["base"],
	}


	func _get_property_list() -> Array[Dictionary]:
		return [
			{
				"name": "dynamic_number",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
			},
			{
				"name": "locked_number",
				"type": TYPE_INT,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_READ_ONLY,
			},
			{
				"name": "target_path",
				"type": TYPE_NODE_PATH,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
			},
			{
				"name": "payload",
				"type": TYPE_DICTIONARY,
				"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_STORAGE,
			},
			{
				"name": "editor_only",
				"type": TYPE_STRING,
				"usage": PROPERTY_USAGE_EDITOR,
			},
		]


	func _get(property: StringName) -> Variant:
		match property:
			&"dynamic_number":
				return dynamic_number_value
			&"locked_number":
				return locked_number_value
			&"target_path":
				return target_path_value
			&"payload":
				return payload_value
			_:
				return null


	func _set(property: StringName, value: Variant) -> bool:
		match property:
			&"dynamic_number":
				dynamic_number_value = GF_VARIANT_ACCESS.to_int(value)
				return true
			&"target_path":
				target_path_value = value if value is NodePath else NodePath(GF_VARIANT_ACCESS.to_text(value))
				return true
			&"payload":
				payload_value = GF_VARIANT_ACCESS.to_dictionary(value)
				return true
			_:
				return false
