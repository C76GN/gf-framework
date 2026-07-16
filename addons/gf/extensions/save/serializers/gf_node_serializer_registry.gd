## GFNodeSerializerRegistry: 节点序列化器注册表。
##
## 负责按 serializer_id 管理序列化器，并为节点执行一组可组合的采集和应用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFNodeSerializerRegistry
extends RefCounted


# --- 私有变量 ---

var _serializers: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init(include_default_serializers: bool = true) -> void:
	if include_default_serializers:
		register_serializer(GFNodeTransform2DSerializer.new())
		register_serializer(GFNodeTransform3DSerializer.new())
		register_serializer(GFNodeCanvasItemSerializer.new())
		register_serializer(GFNodeControlSerializer.new())
		register_serializer(GFNodeRangeSerializer.new())
		register_serializer(GFNodeTimerSerializer.new())
		register_serializer(GFNodeAnimationPlayerSerializer.new())
		register_serializer(GFNodeAudioStreamPlayerSerializer.new())


# --- 公共方法 ---

## 注册序列化器。相同 id 会被后注册的实例覆盖。
## [br]
## @api public
## [br]
## @param serializer: 序列化器。
func register_serializer(serializer: GFNodeSerializer) -> void:
	if serializer == null:
		return

	var serializer_id: StringName = serializer.get_serializer_id()
	if serializer_id == &"":
		return
	_serializers[serializer_id] = serializer


## 注销序列化器。
## [br]
## @api public
## [br]
## @param serializer_id: 序列化器标识。
func unregister_serializer(serializer_id: StringName) -> void:
	var _erase_result_56: Variant = _serializers.erase(serializer_id)


## 清空注册表。
## [br]
## @api public
func clear() -> void:
	_serializers.clear()


## 获取指定序列化器。
## [br]
## @api public
## [br]
## @param serializer_id: 序列化器标识。
## [br]
## @return 序列化器实例。
func get_serializer(serializer_id: StringName) -> GFNodeSerializer:
	return _get_node_serializer_value(GFVariantData.get_option_value(_serializers, serializer_id))


## 获取所有支持指定节点的序列化器。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @return 序列化器数组。
func get_serializers_for_node(node: Node) -> Array[GFNodeSerializer]:
	var result: Array[GFNodeSerializer] = []
	for serializer_variant: Variant in _serializers.values():
		var serializer: GFNodeSerializer = _get_node_serializer_value(serializer_variant)
		if serializer != null and serializer.supports_node(node):
			result.append(serializer)
	return result


## 采集节点上所有支持的默认序列化器数据。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param context: 调用上下文字典。
## [br]
## @return 序列化片段数组。
## [br]
## @schema context: Dictionary，传递给各序列化器的调用上下文，可包含项目自定义字段。
## [br]
## @schema return: Array[Dictionary]，每项包含 id: StringName 与 data: Dictionary。
func gather_node(node: Node, context: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for serializer: GFNodeSerializer in get_serializers_for_node(node):
		var data: Dictionary = serializer.gather(node, context)
		if data.is_empty():
			continue
		result.append({
			"id": serializer.get_serializer_id(),
			"data": data,
		})
	return result


## 应用节点序列化片段。
## [br]
## @api public
## [br]
## @param node: 目标节点。
## [br]
## @param serializer_payloads: 由 gather_node 返回的片段数组。
## [br]
## @param context: 调用上下文字典。
## [br]
## @return 结果字典。
## [br]
## @schema serializer_payloads: Array[Dictionary]，每项包含 id: StringName 与 data: Dictionary。
## [br]
## @schema context: Dictionary，传递给各序列化器的调用上下文，可包含项目自定义字段。
## [br]
## @schema return: Dictionary，包含 ok: bool、applied: int 与 errors: Array[String]。
func apply_node(node: Node, serializer_payloads: Array, context: Dictionary = {}) -> Dictionary:
	var errors: Array[String] = []
	var applied: int = 0
	for payload_index: int in range(serializer_payloads.size()):
		var payload_variant: Variant = serializer_payloads[payload_index]
		if not (payload_variant is Dictionary):
			errors.append("Serializer payload at index %d must be a Dictionary." % payload_index)
			continue

		var payload: Dictionary = GFVariantData.as_dictionary(payload_variant)
		var serializer_id: StringName = GFVariantData.get_option_string_name(payload, "id")
		var serializer: GFNodeSerializer = get_serializer(serializer_id)
		if serializer == null:
			errors.append("Missing serializer: %s" % String(serializer_id))
			continue
		if not serializer.supports_node(node):
			errors.append("Serializer does not support node: %s" % String(serializer_id))
			continue

		var payload_data: Variant = GFVariantData.get_option_value(payload, "data", {})
		if not (payload_data is Dictionary):
			errors.append("Serializer data must be a Dictionary: %s" % String(serializer_id))
			continue

		var data: Dictionary = GFVariantData.as_dictionary(payload_data)
		var result: Dictionary = serializer.apply(node, data, context)
		if GFVariantData.get_option_bool(result, "ok", false):
			applied += 1
		else:
			errors.append(GFVariantData.get_option_string(result, "error", "Apply failed: %s" % String(serializer_id)))

	return {
		"ok": errors.is_empty(),
		"applied": applied,
		"errors": errors,
	}


# --- 私有/辅助方法 ---

func _get_node_serializer_value(value: Variant) -> GFNodeSerializer:
	if value is GFNodeSerializer:
		var serializer: GFNodeSerializer = value
		return serializer
	return null
