## GFNodeSerializer: 节点序列化器基类。
##
## 用于把通用节点状态拆成可组合的序列化片段。具体项目可以继承该类，
## 在不修改存档图编排逻辑的前提下接入自己的节点状态。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFNodeSerializer
extends Resource


# --- 导出变量 ---

## 序列化器稳定标识。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var serializer_id: StringName = &""

## 编辑器展示名称。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var display_name: String = ""

## 可选 Godot 类名过滤。为空时由子类自行判断。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var supported_class_name: String = ""


# --- 公共方法 ---

## 获取序列化器标识。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 稳定标识。
func get_serializer_id() -> StringName:
	if serializer_id != &"":
		return serializer_id
	if not resource_path.is_empty():
		return StringName(resource_path)
	var script: Script = _get_script_value(get_script())
	return StringName(script.resource_path) if script != null else &""


## 判断当前序列化器是否支持节点。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param node: 待序列化节点。
## [br]
## @return 支持时返回 true。
func supports_node(node: Node) -> bool:
	if node == null:
		return false
	if supported_class_name.is_empty():
		return true
	return _matches_supported_class_name(node, supported_class_name)


## 采集节点数据。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _node: 待序列化节点。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @return 可写入存档的字典。
## [br]
## @schema _context: Dictionary，调用方附加上下文；基础实现保留给子类扩展。
## [br]
## @schema return: Dictionary，当前序列化器写入存档的字段集合；空字典表示无需保存。
func gather(_node: Node, _context: Dictionary = {}) -> Dictionary:
	return {}


## 应用节点数据。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param _node: 目标节点。
## [br]
## @param _payload: 当前序列化器的数据。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @return 结果字典。
## [br]
## @schema _payload: Dictionary，来自 gather() 的当前序列化器数据。
## [br]
## @schema _context: Dictionary，调用方附加上下文；基础实现保留给子类扩展。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func apply(_node: Node, _payload: Dictionary, _context: Dictionary = {}) -> Dictionary:
	return make_result(true)


## 构造统一结果。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param ok: 是否成功。
## [br]
## @param error: 错误描述。
## [br]
## @return 结果字典。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func make_result(ok: bool, error: String = "") -> Dictionary:
	return {
		"ok": ok,
		"error": error,
	}


# --- 可重写钩子 / 虚方法 ---

## 将节点属性复制到序列化载荷。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param node: 属性来源对象。
## [br]
## @param payload: 要写入的载荷字典。
## [br]
## @param property_name: 属性名。
## [br]
## @schema payload: Dictionary，键为属性名，值为属性当前值。
func _copy_property_to_payload(node: Object, payload: Dictionary, property_name: String) -> void:
	if _has_property(node, property_name):
		payload[property_name] = _read_property(node, property_name)


## 批量将节点属性复制到序列化载荷。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param node: 属性来源对象。
## [br]
## @param payload: 要写入的载荷字典。
## [br]
## @param property_names: 属性名列表。
## [br]
## @schema payload: Dictionary，键为属性名，值为属性当前值。
func _copy_properties_to_payload(node: Object, payload: Dictionary, property_names: PackedStringArray) -> void:
	for property_name: String in property_names:
		_copy_property_to_payload(node, payload, property_name)


## 从载荷恢复一个节点属性。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param node: 目标对象。
## [br]
## @param payload: 序列化载荷。
## [br]
## @param property_name: 属性名。
## [br]
## @schema payload: Dictionary，键为属性名，值为要写回的属性值。
func _apply_property_from_payload(node: Object, payload: Dictionary, property_name: String) -> void:
	if payload.has(property_name) and _has_property(node, property_name):
		node.set(property_name, payload[property_name])


## 从载荷批量恢复节点属性。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param node: 目标对象。
## [br]
## @param payload: 序列化载荷。
## [br]
## @param property_names: 属性名列表。
## [br]
## @schema payload: Dictionary，键为属性名，值为要写回的属性值。
func _apply_properties_from_payload(node: Object, payload: Dictionary, property_names: PackedStringArray) -> void:
	for property_name: String in property_names:
		_apply_property_from_payload(node, payload, property_name)


## 按属性规格采集节点状态。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param node: 属性来源对象。
## [br]
## @param specs: 属性规格列表。
## [br]
## @return 采集后的载荷字典。
## [br]
## @schema specs: Array[Dictionary]，每项可包含 key: String、property: String 与 kind: StringName。
## [br]
## @schema return: Dictionary，键为规格 key，值为经过 kind 编码后的属性值。
func _gather_property_specs(node: Object, specs: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for spec: Dictionary in specs:
		var key: String = GFVariantData.get_option_string(spec, "key", GFVariantData.get_option_string(spec, "property"))
		var property_name: String = GFVariantData.get_option_string(spec, "property", key)
		if key.is_empty() or property_name.is_empty() or not _has_property(node, property_name):
			continue
		result[key] = _encode_property_value(
			_read_property(node, property_name),
			GFVariantData.get_option_string_name(spec, "kind")
		)
	return result


## 按属性规格将载荷应用到节点。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param node: 目标对象。
## [br]
## @param payload: 序列化载荷。
## [br]
## @param specs: 属性规格列表。
## [br]
## @return 错误消息列表；空数组表示应用成功。
## [br]
## @schema payload: Dictionary，键为规格 key，值为要写回的属性值。
## [br]
## @schema specs: Array[Dictionary]，每项可包含 key: String、property: String 与 kind: StringName。
func _apply_property_specs(node: Object, payload: Dictionary, specs: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = _validate_property_specs_payload(payload, specs)
	if not errors.is_empty():
		return errors
	for spec: Dictionary in specs:
		var key: String = GFVariantData.get_option_string(spec, "key", GFVariantData.get_option_string(spec, "property"))
		var property_name: String = GFVariantData.get_option_string(spec, "property", key)
		if key.is_empty() or property_name.is_empty() or not payload.has(key) or not _has_property(node, property_name):
			continue
		node.set(property_name, _decode_property_value(
			payload[key],
			_read_property(node, property_name),
			GFVariantData.get_option_string_name(spec, "kind")
		))
	return []


func _validate_property_specs_payload(payload: Dictionary, specs: Array[Dictionary]) -> Array[String]:
	var errors: Array[String] = []
	for spec: Dictionary in specs:
		var key: String = GFVariantData.get_option_string(spec, "key", GFVariantData.get_option_string(spec, "property"))
		if key.is_empty() or not payload.has(key):
			continue
		var kind: StringName = GFVariantData.get_option_string_name(spec, "kind")
		if not _is_payload_value_valid_for_kind(payload[key], kind):
			errors.append("Invalid %s payload value: %s" % [String(kind), key])
	return errors


## 判断对象是否声明了指定属性。
## [br]
## @api protected
## [br]
## @since 3.17.0
## [br]
## @param object: 要检查的对象。
## [br]
## @param property_name: 属性名。
## [br]
## @return 对象属性列表中是否存在该属性。
func _has_property(object: Object, property_name: String) -> bool:
	return GFObjectPropertyTools.has_property(object, StringName(property_name))


# --- 私有/辅助方法 ---

func _matches_supported_class_name(node: Node, type_name: String) -> bool:
	if type_name.is_empty():
		return true
	if node.is_class(type_name):
		return true

	var script: Script = _get_script_value(node.get_script())
	while script != null:
		if String(script.get_global_name()) == type_name or script.resource_path == type_name:
			return true
		script = script.get_base_script()
	return false


func _vector2_to_array(value: Vector2) -> Array[float]:
	return GFVariantJsonCodec.vector2_to_array(value)


func _array_to_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return GFVariantJsonCodec.array_to_vector2(value, fallback)


func _vector3_to_array(value: Vector3) -> Array[float]:
	return GFVariantJsonCodec.vector3_to_array(value)


func _array_to_vector3(value: Variant, fallback: Vector3) -> Vector3:
	return GFVariantJsonCodec.array_to_vector3(value, fallback)


func _color_to_array(value: Color) -> Array[float]:
	return GFVariantJsonCodec.color_to_array(value)


func _array_to_color(value: Variant, fallback: Color) -> Color:
	return GFVariantJsonCodec.array_to_color(value, fallback)


func _encode_property_value(value: Variant, kind: StringName) -> Variant:
	match kind:
		&"vector2":
			return _vector2_to_array(GFVariantData.to_vector2(value))
		&"vector3":
			return _vector3_to_array(GFVariantData.to_vector3(value))
		&"color":
			return _color_to_array(_get_color_value(value))
		_:
			return value


func _decode_property_value(value: Variant, fallback: Variant, kind: StringName) -> Variant:
	match kind:
		&"vector2":
			return _array_to_vector2(value, GFVariantData.to_vector2(fallback))
		&"vector3":
			return _array_to_vector3(value, GFVariantData.to_vector3(fallback))
		&"color":
			return _array_to_color(value, _get_color_value(fallback))
		&"float":
			return GFVariantData.to_float(value)
		&"int":
			return GFVariantData.to_int(value)
		&"bool":
			return GFVariantData.to_bool(value)
		_:
			return value


func _is_payload_value_valid_for_kind(value: Variant, kind: StringName) -> bool:
	match kind:
		&"vector2":
			return _is_numeric_array(value, 2)
		&"vector3":
			return _is_numeric_array(value, 3)
		&"color":
			return _is_numeric_array(value, 4)
		&"float":
			return _is_finite_number(value)
		&"int":
			return typeof(value) == TYPE_INT
		&"bool":
			return value is bool
		&"string":
			return value is String
		&"string_name":
			return value is StringName or value is String
		_:
			return true


func _is_numeric_array(value: Variant, expected_size: int) -> bool:
	if not (value is Array):
		return false
	var values: Array = value
	if values.size() != expected_size:
		return false
	for item: Variant in values:
		if not _is_finite_number(item):
			return false
	return true


func _is_finite_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var number: float = GFVariantData.to_float(value)
	return not is_nan(number) and not is_inf(number)


func _read_property(object: Object, property_name: String) -> Variant:
	return GFObjectPropertyTools.read_property(object, NodePath(property_name))


func _get_script_value(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null


func _get_color_value(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if value is Color:
		var color_value: Color = value
		return color_value
	return fallback
