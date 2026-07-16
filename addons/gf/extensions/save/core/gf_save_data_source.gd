## GFSaveDataSource: 通用对象数据源适配器。
##
## 将 Resource、目标 Node 或目标属性上的对象按 Dictionary 载荷接入 SaveGraph。
## 适合已有 Model、Resource 或数据持有对象复用 to_dict()/from_dict() 等通用协议，
## 不要求项目为每份纯数据状态额外编写 GFSaveSource 子类。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 3.18.0
class_name GFSaveDataSource
extends GFSaveSource


# --- 导出变量 ---

## 直接保存的数据对象。设置后优先于 target_node_path 和 provider_property。
## [br]
## @api public
@export var data: Resource = null

## 目标节点上的数据对象属性。留空时使用目标节点自身作为数据对象。
## [br]
## @api public
@export var provider_property: StringName = &""

## 采集载荷时调用的数据对象方法。方法必须返回 Dictionary。
## [br]
## @api public
@export var gather_method: StringName = &"to_dict"

## 应用载荷时调用的数据对象方法。方法接收 Dictionary。
## [br]
## @api public
@export var apply_method: StringName = &"from_dict"

## 是否复制传入/传出的 Dictionary，避免流程外部误改同一个引用。
## [br]
## @api public
@export var duplicate_payload: bool = true


# --- 公共方法 ---

## 获取当前数据对象。
## [br]
## @api public
## [br]
## @return 数据对象；无法解析时返回 null。
func get_data_provider() -> Object:
	if data != null:
		return data if is_instance_valid(data) else null

	var target: Node = get_target_node()
	if target == null:
		return null
	if provider_property == &"":
		return target
	if not _has_object_property(target, provider_property):
		return null

	var value: Variant = GFObjectPropertyTools.read_property(target, NodePath(String(provider_property)))
	return _variant_to_valid_object(value)


## 构造数据对象诊断描述。
## [br]
## @api public
## [br]
## @return 诊断字典。
## [br]
## @schema return: Dictionary，包含 valid、reason、source_key、provider_location、provider_property、provider_class、provider_script、gather_method、apply_method、has_gather_method、has_apply_method 等字段。
func describe_data_provider() -> Dictionary:
	var provider_location: String = "direct_data" if data != null else "target"
	var provider: Object = null
	var reason: String = ""
	if data != null:
		if is_instance_valid(data):
			provider = data
		else:
			reason = "invalid_direct_data"

	if provider == null:
		var target: Node = get_target_node()
		if not reason.is_empty():
			pass
		elif target == null:
			reason = "missing_target"
		elif provider_property == &"":
			provider = target
		elif not _has_object_property(target, provider_property):
			reason = "missing_property"
		else:
			provider_location = "target_property"
			var value: Variant = GFObjectPropertyTools.read_property(target, NodePath(String(provider_property)))
			if typeof(value) == TYPE_NIL:
				reason = "null_property"
			elif typeof(value) == TYPE_OBJECT:
				provider = _variant_to_valid_object(value)
				if provider == null:
					reason = "invalid_property_object"
			else:
				reason = "property_not_object"

	var gather_method_name: String = String(gather_method)
	var apply_method_name: String = String(apply_method)
	var has_gather_method: bool = (
		provider != null
		and gather_method != &""
		and provider.has_method(gather_method_name)
	)
	var has_apply_method: bool = (
		provider != null
		and apply_method != &""
		and provider.has_method(apply_method_name)
	)
	if reason.is_empty() and provider == null:
		reason = "missing_provider"
	elif reason.is_empty() and save_enabled and not has_gather_method:
		reason = "missing_gather_method"
	elif reason.is_empty() and load_enabled and not has_apply_method:
		reason = "missing_apply_method"

	var valid: bool = (
		provider != null
		and (not save_enabled or has_gather_method)
		and (not load_enabled or has_apply_method)
	)
	return {
		"valid": valid,
		"reason": reason,
		"source_key": get_source_key(),
		"provider_location": provider_location,
		"provider_property": provider_property,
		"provider_class": provider.get_class() if provider != null else "",
		"provider_script": _get_object_script_path(provider),
		"gather_method": gather_method,
		"apply_method": apply_method,
		"has_gather_method": has_gather_method,
		"has_apply_method": has_apply_method,
		"save_enabled": save_enabled,
		"load_enabled": load_enabled,
	}


## 构造 Source 描述。
## [br]
## @api public
## [br]
## @param scope: 当前 Scope。
## [br]
## @return 描述字典。
## [br]
## @schema return: Dictionary，包含父类描述字段，并追加 kind 与 data_provider 诊断字段。
func describe_source(scope: Node = null) -> Dictionary:
	var descriptor: Dictionary = super.describe_source(scope)
	descriptor["kind"] = "data"
	descriptor["data_provider"] = describe_data_provider()
	return descriptor


# --- 可重写钩子 / 虚方法 ---

## 采集数据对象载荷。
## [br]
## @api protected
## [br]
## @param context: 调用上下文字典。
## [br]
## @param _serializer_registry: 未使用；保留以匹配 GFSaveSource 协议。
## [br]
## @return 数据对象返回的 Dictionary 载荷；失败时返回空 Dictionary 并写入流程错误。
## [br]
## @schema context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
## [br]
## @schema return: Variant，成功时为 Dictionary。
func _gather_save_data(
	context: Dictionary = {},
	_serializer_registry: GFNodeSerializerRegistry = null
) -> Variant:
	var provider: Object = get_data_provider()
	if provider == null:
		_record_source_error(context, "Data provider is missing.")
		return {}
	if gather_method == &"" or not provider.has_method(String(gather_method)):
		_record_source_error(context, "Data provider gather method is missing.", {
			"method": gather_method,
		})
		return {}

	var payload: Variant = provider.call(String(gather_method))
	if not (payload is Dictionary):
		_record_source_error(context, "Data provider gather method must return a Dictionary.", {
			"method": gather_method,
			"result_type": type_string(typeof(payload)),
		})
		return {}

	var dictionary: Dictionary = GFVariantData.as_dictionary(payload)
	return dictionary.duplicate(true) if duplicate_payload else dictionary


## 应用数据对象载荷。
## [br]
## @api protected
## [br]
## @param payload: 保存载荷。
## [br]
## @param _context: 调用上下文字典。
## [br]
## @param _serializer_registry: 未使用；保留以匹配 GFSaveSource 协议。
## [br]
## @return 结果字典。
## [br]
## @schema payload: Variant，要求为 Dictionary。
## [br]
## @schema _context: Dictionary，可包含 pipeline_context、pipeline_shared、include_pipeline_trace 等流程字段。
## [br]
## @schema return: Dictionary，包含 ok: bool 与 error: String。
func _apply_save_data(
	payload: Variant,
	_context: Dictionary = {},
	_serializer_registry: GFNodeSerializerRegistry = null
) -> Dictionary:
	if not (payload is Dictionary):
		return make_result(false, "Data source payload must be a Dictionary.")

	var provider: Object = get_data_provider()
	if provider == null:
		return make_result(false, "Data provider is missing.")
	if apply_method == &"" or not provider.has_method(String(apply_method)):
		return make_result(false, "Data provider apply method is missing: %s" % String(apply_method))

	var dictionary: Dictionary = GFVariantData.as_dictionary(payload)
	var input: Dictionary = dictionary.duplicate(true) if duplicate_payload else dictionary
	var result: Variant = provider.call(String(apply_method), input)
	return _normalize_apply_result(result)


# --- 私有/辅助方法 ---

func _normalize_apply_result(result: Variant) -> Dictionary:
	if result is Dictionary:
		var dictionary: Dictionary = GFVariantData.as_dictionary(result)
		if dictionary.has("ok") and not GFVariantData.get_option_bool(dictionary, "ok", false):
			return make_result(false, GFVariantData.get_option_string(dictionary, "error", "Data provider apply failed."))
	if result is bool and not GFVariantData.to_bool(result, false):
		return make_result(false, "Data provider apply failed.")
	if result is int:
		var error_code: int = result
		if error_code != OK:
			return make_result(false, "Data provider apply failed with Error %d." % error_code)
	return make_result(true)


func _record_source_error(context: Dictionary, message: String, payload: Dictionary = {}) -> void:
	var source_payload: Dictionary = payload.duplicate(true)
	source_payload["source_key"] = get_source_key()
	source_payload["provider_property"] = provider_property
	var pipeline_context: GFSavePipelineContext = _variant_to_pipeline_context(GFVariantData.get_option_value(context, "pipeline_context"))
	if pipeline_context != null:
		pipeline_context.add_error(message, source_payload)


func _has_object_property(object: Object, property_name: StringName) -> bool:
	return GFObjectPropertyTools.has_property(object, property_name)


func _get_object_script_path(object: Object) -> String:
	if object == null:
		return ""

	var script: Script = _variant_to_script(object.get_script())
	if script == null:
		return ""
	return script.resource_path


func _variant_to_valid_object(value: Variant) -> Object:
	if typeof(value) == TYPE_OBJECT and is_instance_valid(value):
		var object_value: Object = value
		return object_value
	return null


func _variant_to_pipeline_context(value: Variant) -> GFSavePipelineContext:
	if value is GFSavePipelineContext:
		var pipeline_context: GFSavePipelineContext = value
		return pipeline_context
	return null


func _variant_to_script(value: Variant) -> Script:
	if value is Script:
		var script: Script = value
		return script
	return null
