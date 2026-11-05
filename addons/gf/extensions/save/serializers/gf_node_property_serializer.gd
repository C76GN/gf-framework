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


# --- 常量 ---

## 当前 Source 派发期间使用的 prepared 属性片段；仅由 SaveGraph 的同次读取状态填充，普通 apply 会清除外部伪造值。
## [br]
## @api framework_internal
## [br]
## @since unreleased
const PREPARED_PAYLOADS_CONTEXT_KEY: StringName = &"_gf_save_prepared_property_payloads"

## 编码预算通过后验证原始纯数据值，避免 Float/Vector 等类型标记隐藏 Save 禁止的非有限分量。
## [br]
## @api private
const _PERSISTED_VALUE_VALIDATOR_SCRIPT = preload("res://addons/gf/extensions/save/core/gf_save_persisted_value_validator.gd")


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
		var property_value: Variant = GFObjectPropertyTools.read_property(
			node,
			NodePath(property_name)
		)
		var encoding: Dictionary = _encode_payload_property_value(property_value, context)
		if not GFResultDictionary.is_ok(encoding):
			_record_gather_error(
				context,
				property_name,
				GFVariantData.get_option_string(
					encoding,
					"error",
					"incomplete_property_value"
				)
			)
			return {}
		var encoded_value: Variant = encoding.get("value")
		if _is_unsupported_property_marker(encoded_value):
			push_warning("[GFNodePropertySerializer][node_property_serializer.unsupported_property_value] Unsupported property value skipped: %s." % property_name)
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
func apply(
	node: Node,
	payload: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if node == null:
		return make_result(false, "Node is null.")

	for property_variant: Variant in payload.keys():
		if not (property_variant is String or property_variant is StringName):
			return make_result(false, "Property key must be a String or StringName.")
		var property_name: String = GFVariantData.to_text(property_variant)
		if not properties.has(property_name):
			return make_result(
				false,
				"Property is not allowed: %s" % property_name
			)
	var decoded_payload: Dictionary = {}
	for property_variant: Variant in payload.keys():
		var property_name: String = GFVariantData.to_text(property_variant)
		if not GFObjectPropertyTools.has_property(
			node,
			StringName(property_name)
		):
			if skip_missing_properties:
				continue
			return make_result(
				false,
				"Missing property: %s" % property_name
			)
		var decode_result: Dictionary = _decode_payload_property_value(
			payload[property_variant],
			context
		)
		if not GFVariantData.get_option_bool(
			decode_result,
			"ok",
			false
		):
			return make_result(
				false,
				GFVariantData.get_option_string(decode_result, "error")
			)
		decoded_payload[property_name] = GFVariantData.get_option_value(decode_result, "value")
	for property_name: String in decoded_payload:
		var result: Dictionary = GFObjectPropertyTools.write_property(
			node,
			NodePath(property_name),
			decoded_payload[property_name]
		)
		if not GFVariantData.get_option_bool(
			result,
			"ok",
			false
		):
			return make_result(
				false,
				GFVariantData.get_option_string(result, "error")
			)

	return make_result(true)


# --- 框架内部方法 ---

## 只在实际 Property 类型派发时选择同次 JSON 读取的 prepared 片段；原生数据被步骤修改后沿用显式调用载荷，不消费过期投影。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param node: 目标节点。
## [br]
## @param payload: Source 当前持有的原生或显式编码片段。
## [br]
## @param context: 当前 Source 的内部派发上下文。
## [br]
## @param payload_index: serializers 数组中的原始索引。
## [br]
## @schema payload: Dictionary，键为属性白名单中的名称。
## [br]
## @schema context: Dictionary，可含由 Graph 同次读取投影签发的内部 prepared payload 记录，其他选项沿用 apply。
## [br]
## @return: 与 apply 相同的结果；投影失效或其表示不完整时失败且不写属性。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func apply_prepared_for_framework(
	node: Node,
	payload: Dictionary,
	context: Dictionary,
	payload_index: int
) -> Dictionary:
	var projection: Dictionary = GFVariantData.as_dictionary(context.get(PREPARED_PAYLOADS_CONTEXT_KEY))
	if projection.has("error"):
		return make_result(
			false,
			GFVariantData.get_option_string(projection, "error")
		)
	var entries: Array = GFVariantData.as_array(projection.get("payloads"))
	if payload_index < 0 or payload_index >= entries.size():
		return apply(
			node,
			payload,
			context
		)
	var entry: Dictionary = GFVariantData.as_dictionary(entries[payload_index])
	if GFVariantData.get_option_string_name(entry, "id") != get_serializer_id():
		return apply(
			node,
			payload,
			context
		)
	var prepared_value: Variant = entry.get("data")
	if not prepared_value is Dictionary:
		return apply(
			node,
			payload,
			context
		)
	var prepared: Dictionary = prepared_value
	var decoded: Dictionary = {}
	for property_name: Variant in prepared:
		var value_result: Dictionary = GFVariantJsonCodec.json_compatible_to_variant_result(prepared[property_name])
		if not GFResultDictionary.is_ok(value_result):
			return make_result(
				false,
				GFVariantData.get_option_string(value_result, "error")
			)
		decoded[property_name] = value_result.get("value")
	if decoded != payload:
		return apply(
			node,
			payload,
			context
		)
	return apply(
		node,
		prepared,
		context
	)


# --- 私有/辅助方法 ---

## Object 值沿用引用标记协议，其余值必须完整编码；失败不返回诊断替代值。
## [br]
## @api private
## [br]
func _encode_payload_property_value(value: Variant, context: Dictionary) -> Dictionary:
	if value is Object:
		return { "ok": true, "value": GFVariantReferenceCodec.encode_reference(value, context) }
	var encoded: Dictionary = GFVariantJsonCodec.variant_to_json_compatible_result(
		value,
		{ "encode_dictionary_keys": true }
	)
	if not GFResultDictionary.is_ok(encoded):
		return encoded
	var validation: Dictionary = _PERSISTED_VALUE_VALIDATOR_SCRIPT.validate(value)
	return encoded if GFResultDictionary.is_ok(validation) else validation


## 采集失败写入共享流程，使 Source/Graph 在替换旧存档前终止；独立调用仍提供明确错误。
## [br]
## @api private
func _record_gather_error(
	context: Dictionary,
	property_name: String,
	error: String
) -> void:
	var message: String = (
		"[GFNodePropertySerializer][node_property_serializer.incomplete_property_value] Property could not be completely encoded: %s (%s)."
		% [property_name, error]
	)
	var pipeline_value: Variant = context.get("pipeline_context")
	if pipeline_value is GFSavePipelineContext:
		var pipeline_context: GFSavePipelineContext = pipeline_value
		pipeline_context.add_error(
			message,
			{ "property": property_name }
		)
	else:
		push_error(message)


## 引用标记通过 ReferenceCodec 解码，其余值交给 JSON codec 转换。
## [br]
## @api private
## [br]
func _decode_payload_property_value(value: Variant, context: Dictionary) -> Dictionary:
	if GFVariantReferenceCodec.is_reference_marker(value):
		return GFVariantReferenceCodec.decode_reference(
			value,
			_make_reference_decode_context(context)
		)
	return GFVariantJsonCodec.json_compatible_to_variant_result(value)


## 检查编码值是否为 ReferenceCodec 标记的不可支持引用。
## [br]
## @api private
## [br]
func _is_unsupported_property_marker(value: Variant) -> bool:
	return GFVariantReferenceCodec.is_unsupported_reference_marker(value)


## 已提供资源恢复策略时沿用 context，否则把本地白名单合并到副本。
## [br]
## @api private
## [br]
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


## 检查 context 是否含非空的资源根目录或路径模式白名单。
## [br]
## @api private
## [br]
func _context_has_resource_decode_policy(context: Dictionary) -> bool:
	return (not (GFVariantData.get_option_packed_string_array(context, GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_ROOTS).is_empty()) or not (GFVariantData.get_option_packed_string_array(context, GFVariantReferenceCodec.OPTION_ALLOWED_RESOURCE_PATTERNS).is_empty()))
