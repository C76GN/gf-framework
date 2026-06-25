## GFNodePropertySerializer: 通用节点属性序列化器。
##
## 通过显式属性白名单保存和恢复节点属性，适合项目层快速接入简单状态。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFNodePropertySerializer
extends GFNodeSerializer


# --- 导出变量 ---

## 需要保存的属性名。
## [br]
## @api public
@export var properties: PackedStringArray = PackedStringArray()

## 应用数据时遇到缺失属性是否跳过。
## [br]
## @api public
@export var skip_missing_properties: bool = true

## Resource 引用恢复时允许加载的资源根目录。为空时使用 context 中的同名策略；仍为空则拒绝恢复 Resource 引用。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var allowed_resource_roots: PackedStringArray = PackedStringArray()

## Resource 引用恢复时允许加载的资源路径通配模式。为空时使用 context 中的同名策略；仍为空则拒绝恢复 Resource 引用。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var allowed_resource_patterns: PackedStringArray = PackedStringArray()


# --- Godot 生命周期方法 ---

func _init() -> void:
	serializer_id = &"gf.property"


# --- 公共方法 ---

## 采集节点的可保存状态。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param context: 操作上下文字典。
## [br]
## @return 属性载荷字典。
## [br]
## @schema context: Dictionary，可包含 reference_root_node: Node，用于保存 Node 引用属性。
## [br]
## @schema return: Dictionary，键为 properties 中声明的属性名，值为 JSON 兼容值；Resource / Node 引用使用 __gf_reference__ 标记。
func gather(node: Node, context: Dictionary = {}) -> Dictionary:
	if node == null:
		return {}

	var available: Dictionary = GFObjectPropertyTools.get_property_info_map(node)
	var result: Dictionary = {}
	for property_name: String in properties:
		if not available.has(StringName(property_name)):
			continue
		var property_value: Variant = GFObjectPropertyTools.read_property(node, NodePath(property_name))
		var encoded_value: Variant = _encode_payload_property_value(property_value, context)
		if _is_unsupported_property_marker(encoded_value):
			push_warning("[GFNodePropertySerializer] Unsupported property value skipped: %s" % property_name)
			continue
		result[property_name] = encoded_value
	return result


## 将序列化数据应用到节点。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param node: 目标节点。
## [br]
## @param payload: 属性载荷字典。
## [br]
## @param context: 操作上下文字典。
## [br]
## @return 应用结果字典。
## [br]
## @schema payload: Dictionary，键为属性名，值为 JSON 兼容值或 __gf_reference__ 标记。
## [br]
## @schema context: Dictionary，可包含 reference_root_node: Node，用于恢复 Node 引用属性；可包含 allowed_resource_roots / allowed_resource_patterns，用于恢复 Resource 引用属性。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func apply(node: Node, payload: Dictionary, context: Dictionary = {}) -> Dictionary:
	if node == null:
		return make_result(false, "Node is null.")

	for property_variant: Variant in payload.keys():
		var property_name: String = GFVariantData.to_text(property_variant)
		if not GFObjectPropertyTools.has_property(node, StringName(property_name)):
			if skip_missing_properties:
				continue
			return make_result(false, "Missing property: %s" % property_name)
		var decode_result: Dictionary = _decode_payload_property_value(payload[property_variant], context)
		if not GFVariantData.get_option_bool(decode_result, "ok", false):
			return make_result(false, GFVariantData.get_option_string(decode_result, "error"))
		var result: Dictionary = GFObjectPropertyTools.write_property(
			node,
			NodePath(property_name),
			GFVariantData.get_option_value(decode_result, "value")
		)
		if not GFVariantData.get_option_bool(result, "ok", false):
			return make_result(false, GFVariantData.get_option_string(result, "error"))

	return make_result(true)


# --- 私有/辅助方法 ---

func _encode_payload_property_value(value: Variant, context: Dictionary) -> Variant:
	if value is Object:
		return GFVariantReferenceCodec.encode_reference(value, context)
	return GFVariantJsonCodec.variant_to_json_compatible(value, { "encode_dictionary_keys": true })


func _decode_payload_property_value(value: Variant, context: Dictionary) -> Dictionary:
	if GFVariantReferenceCodec.is_reference_marker(value):
		return GFVariantReferenceCodec.decode_reference(value, _make_reference_decode_context(context))
	return _make_decode_result(true, GFVariantJsonCodec.json_compatible_to_variant(value))


func _is_unsupported_property_marker(value: Variant) -> bool:
	return GFVariantReferenceCodec.is_unsupported_reference_marker(value)


func _make_reference_decode_context(context: Dictionary) -> Dictionary:
	if _context_has_resource_decode_policy(context):
		return context
	if allowed_resource_roots.is_empty() and allowed_resource_patterns.is_empty():
		return context

	var result: Dictionary = context.duplicate()
	if not allowed_resource_roots.is_empty():
		result[GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_ROOTS] = allowed_resource_roots
	if not allowed_resource_patterns.is_empty():
		result[GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_PATTERNS] = allowed_resource_patterns
	return result


func _context_has_resource_decode_policy(context: Dictionary) -> bool:
	return (
		not GFVariantData.get_option_packed_string_array(
			context,
			GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_ROOTS
		).is_empty()
		or not GFVariantData.get_option_packed_string_array(
			context,
			GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_PATTERNS
		).is_empty()
	)


func _make_decode_result(ok: bool, value: Variant = null, error: String = "") -> Dictionary:
	return {
		"ok": ok,
		"value": value,
		"error": error,
	}
