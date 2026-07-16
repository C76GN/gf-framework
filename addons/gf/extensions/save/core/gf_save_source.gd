## GFSaveSource: 存档图数据源节点。
##
## Source 是存档图的最小数据入口。项目可继承并重写 gather/apply，
## 也可配置节点序列化器保存通用节点属性。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.17.0
class_name GFSaveSource
extends Node


# --- 导出变量 ---

## Source 稳定标识。留空时回退到节点名。
## [br]
## @api public
@export var source_key: StringName = &""

## 目标节点路径。留空时默认序列化父节点。
## [br]
## @api public
@export var target_node_path: NodePath

## 是否启用该 Source。
## [br]
## @api public
@export var enabled: bool = true

## 是否参与保存。
## [br]
## @api public
@export var save_enabled: bool = true

## 是否参与加载。
## [br]
## @api public
@export var load_enabled: bool = true

## 执行阶段。数值越小越早执行。
## [br]
## @api public
@export var phase: int = GFSaveScope.Phase.NORMAL

## Source 局部序列化器。为空时可使用注册表中的默认序列化器。
## [br]
## @api public
@export var serializers: Array[GFNodeSerializer] = []

## 是否在未配置局部序列化器时使用注册表默认序列化器。
## [br]
## @api public
@export var use_registry_serializers: bool = false

## 附加描述字段。
## [br]
## @api public
## [br]
## @schema descriptor_extra: Dictionary，会合并进 describe_source() 返回值的项目自定义描述字段。
@export var descriptor_extra: Dictionary = {}


# --- 公共方法 ---

## 获取 Source 稳定标识。
## [br]
## @api public
## [br]
## @return 来源键。
func get_source_key() -> StringName:
	if source_key != &"":
		return source_key
	return StringName(name)


## 获取目标节点。
## [br]
## @api public
## [br]
## @return 目标节点；不存在时返回 null。
func get_target_node() -> Node:
	if not target_node_path.is_empty():
		return get_node_or_null(target_node_path)
	return get_parent()


## 构造 Source 描述。
## [br]
## @api public
## [br]
## @param scope: 当前 Scope。
## [br]
## @return 描述字典。
## [br]
## @schema return: Dictionary，包含 descriptor_extra、source_key、phase，并在可用时包含 node_path。
func describe_source(scope: Node = null) -> Dictionary:
	var descriptor: Dictionary = descriptor_extra.duplicate(true)
	descriptor["source_key"] = get_source_key()
	descriptor["phase"] = phase
	if scope != null and is_inside_tree() and scope.is_inside_tree():
		descriptor["node_path"] = String(scope.get_path_to(self))
	return descriptor


## 构造统一结果。
## [br]
## @api public
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

## 判断是否可保存。
## [br]
## @api protected
## [br]
## @param _context: 调用上下文字典。
## [br]
## @return 可保存时返回 true。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _can_save_source(_context: Dictionary = {}) -> bool:
	return enabled and save_enabled


## 判断是否可加载。
## [br]
## @api protected
## [br]
## @param _context: 调用上下文字典。
## [br]
## @return 可加载时返回 true。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _can_load_source(_context: Dictionary = {}) -> bool:
	return enabled and load_enabled


## 保存前 Hook。
## [br]
## @api protected
## [br]
## @param _context: 调用上下文字典。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _before_save(_context: Dictionary = {}) -> void:
	pass


## 采集保存数据。
## [br]
## @api protected
## [br]
## @param context: 调用上下文字典。
## [br]
## @param serializer_registry: 可选节点序列化器注册表。
## [br]
## @return 可写入存档的数据。
## [br]
## @schema context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
## [br]
## @schema return: Variant，通常为 Dictionary；默认实现返回包含 serializers: Array[Dictionary] 的载荷，或空 Dictionary。
func _gather_save_data(
	context: Dictionary = {},
	serializer_registry: GFNodeSerializerRegistry = null
) -> Variant:
	var target: Node = get_target_node()
	if target == null:
		return {}

	var serializer_payloads: Array[Dictionary] = _gather_serializer_payloads(target, context, serializer_registry)
	if serializer_payloads.is_empty():
		return {}

	return {
		"serializers": serializer_payloads,
	}


## 应用保存数据。
## [br]
## @api protected
## [br]
## @param data: 保存数据。
## [br]
## @param context: 调用上下文字典。
## [br]
## @param serializer_registry: 可选节点序列化器注册表。
## [br]
## @return 结果字典。
## [br]
## @schema data: Variant，默认实现要求为包含 serializers: Array[Dictionary] 的 Dictionary。
## [br]
## @schema context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
## [br]
## @schema return: Dictionary，包含 ok: bool、error: String，或序列化器应用结果字段。
func _apply_save_data(
	data: Variant,
	context: Dictionary = {},
	serializer_registry: GFNodeSerializerRegistry = null
) -> Dictionary:
	if not (data is Dictionary):
		return make_result(false, "Source data must be a Dictionary.")

	var target: Node = get_target_node()
	if target == null:
		return make_result(false, "Target node is null.")

	var dictionary: Dictionary = GFVariantData.as_dictionary(data)
	if dictionary.is_empty():
		return make_result(true)
	if not dictionary.has("serializers"):
		return make_result(false, "Serializer payloads are missing.")

	var serializer_payloads_variant: Variant = GFVariantData.get_option_value(dictionary, "serializers", [])
	if not (serializer_payloads_variant is Array):
		return make_result(false, "Serializer payloads must be an Array.")

	var serializer_payloads: Array = GFVariantData.as_array(serializer_payloads_variant)
	if serializer_payloads.is_empty():
		return make_result(true)

	if not serializers.is_empty():
		return _apply_local_serializers(target, serializer_payloads, context)
	if serializer_registry != null:
		return serializer_registry.apply_node(target, serializer_payloads, context)
	return make_result(false, "Serializer registry is null.")


## 加载后 Hook。
## [br]
## @api protected
## [br]
## @param _data: 已应用的数据。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @schema _data: Variant，当前 Source 已应用的保存数据。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
func _after_load(_data: Variant, _context: Dictionary = {}) -> void:
	pass


# --- 私有/辅助方法 ---

func _gather_serializer_payloads(
	target: Node,
	context: Dictionary,
	serializer_registry: GFNodeSerializerRegistry
) -> Array[Dictionary]:
	if not serializers.is_empty():
		var result: Array[Dictionary] = []
		for serializer: GFNodeSerializer in serializers:
			if serializer == null or not serializer.supports_node(target):
				continue
			var data: Dictionary = serializer.gather(target, context)
			if data.is_empty():
				continue
			result.append({
				"id": serializer.get_serializer_id(),
				"data": data,
			})
		return result

	if use_registry_serializers and serializer_registry != null:
		return serializer_registry.gather_node(target, context)
	return []


func _apply_local_serializers(target: Node, serializer_payloads: Array, context: Dictionary) -> Dictionary:
	var by_id: Dictionary = {}
	for serializer: GFNodeSerializer in serializers:
		if serializer != null:
			by_id[serializer.get_serializer_id()] = serializer

	var errors: Array[String] = []
	var applied: int = 0
	for payload_index: int in range(serializer_payloads.size()):
		var payload_variant: Variant = serializer_payloads[payload_index]
		if not (payload_variant is Dictionary):
			errors.append("Serializer payload at index %d must be a Dictionary." % payload_index)
			continue

		var payload: Dictionary = GFVariantData.as_dictionary(payload_variant)
		var serializer_id: StringName = GFVariantData.get_option_string_name(payload, "id")
		var serializer: GFNodeSerializer = _variant_to_node_serializer(GFVariantData.get_option_value(by_id, serializer_id))
		if serializer == null:
			errors.append("Missing serializer: %s" % String(serializer_id))
			continue
		if not serializer.supports_node(target):
			errors.append("Serializer does not support target: %s" % String(serializer_id))
			continue

		var payload_data: Variant = GFVariantData.get_option_value(payload, "data", {})
		if not (payload_data is Dictionary):
			errors.append("Serializer data must be a Dictionary: %s" % String(serializer_id))
			continue

		var data: Dictionary = GFVariantData.as_dictionary(payload_data)
		var result: Dictionary = serializer.apply(target, data, context)
		if GFVariantData.get_option_bool(result, "ok", false):
			applied += 1
		else:
			errors.append(GFVariantData.get_option_string(result, "error", "Apply failed: %s" % String(serializer_id)))

	return {
		"ok": errors.is_empty(),
		"applied": applied,
		"errors": errors,
	}


func _variant_to_node_serializer(value: Variant) -> GFNodeSerializer:
	if value is GFNodeSerializer:
		var serializer: GFNodeSerializer = value
		return serializer
	return null
