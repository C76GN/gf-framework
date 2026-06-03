## GFShaderParameterUtility: 通用 ShaderMaterial 参数应用工具。
##
## 将 `GFShaderParameterProfile` 或参数字典写入 ShaderMaterial，也可以从持有
## `material` 属性的节点解析材质。它只处理参数存在性校验、共享材质复制和批量写入，
## 不提供具体 shader、后处理算法或项目视觉规则。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 4.3.0
class_name GFShaderParameterUtility
extends GFUtility


# --- 常量 ---

## 默认材质属性路径。
## [br]
## @api public
const DEFAULT_MATERIAL_PROPERTY: NodePath = ^"material"


# --- 公共方法 ---

## 将 shader 参数 profile 应用到目标对象。
## [br]
## @api public
## [br]
## @param target: ShaderMaterial，或持有材质属性的对象。
## [br]
## @param profile: 要应用的 shader 参数 profile。
## [br]
## @param options: 可选项，支持 material_property、duplicate_material、require_declared_parameters、warn_on_invalid_target、warn_on_missing_parameters 和 copy_values。
## [br]
## @return: 实际写入的参数数量。
## [br]
## @schema options: Dictionary，material_property 为 NodePath/String，默认 material；duplicate_material 为 true 时会复制目标材质并写回属性；require_declared_parameters 默认为 true，会跳过 shader 未声明的 uniform；warn_on_invalid_target 和 warn_on_missing_parameters 控制警告；copy_values 默认为 true，会复制集合参数值后再写入。
func apply_profile(
	target: Object,
	profile: GFShaderParameterProfile,
	options: Dictionary = {}
) -> int:
	if profile == null:
		return 0
	return apply_parameters(target, profile.parameters, options)


## 将 shader 参数字典应用到目标对象。
## [br]
## @api public
## [br]
## @param target: ShaderMaterial，或持有材质属性的对象。
## [br]
## @param parameters: 要应用的 shader 参数字典。
## [br]
## @param options: 可选项，支持 material_property、duplicate_material、require_declared_parameters、warn_on_invalid_target、warn_on_missing_parameters 和 copy_values。
## [br]
## @return: 实际写入的参数数量。
## [br]
## @schema parameters: Dictionary[StringName, Variant]，shader uniform 名到参数值的映射。
## [br]
## @schema options: Dictionary，material_property 为 NodePath/String，默认 material；duplicate_material 为 true 时会复制目标材质并写回属性；require_declared_parameters 默认为 true，会跳过 shader 未声明的 uniform；warn_on_invalid_target 和 warn_on_missing_parameters 控制警告；copy_values 默认为 true，会复制集合参数值后再写入。
func apply_parameters(target: Object, parameters: Dictionary, options: Dictionary = {}) -> int:
	if parameters.is_empty():
		return 0

	var material_property: NodePath = _get_option_node_path(
		options,
		"material_property",
		DEFAULT_MATERIAL_PROPERTY
	)
	var warn_on_invalid_target: bool = GFVariantData.get_option_bool(
		options,
		"warn_on_invalid_target",
		true
	)
	var material: ShaderMaterial = _resolve_shader_material(
		target,
		material_property,
		GFVariantData.get_option_bool(options, "duplicate_material"),
		warn_on_invalid_target
	)
	if material == null:
		return 0

	var require_declared_parameters: bool = GFVariantData.get_option_bool(
		options,
		"require_declared_parameters",
		true
	)
	var warn_on_missing_parameters: bool = GFVariantData.get_option_bool(
		options,
		"warn_on_missing_parameters",
		true
	)
	var copy_values: bool = GFVariantData.get_option_bool(options, "copy_values", true)
	var applied_count: int = 0
	for raw_key: Variant in parameters.keys():
		var parameter_name: StringName = _variant_to_parameter_name(raw_key)
		if parameter_name == &"":
			continue
		if require_declared_parameters and not has_shader_parameter(material, parameter_name):
			if warn_on_missing_parameters:
				push_warning("[GFShaderParameterUtility] Shader 参数不存在：%s。" % String(parameter_name))
			continue

		var value: Variant = parameters[raw_key]
		material.set_shader_parameter(
			parameter_name,
			GFVariantData.duplicate_variant(value) if copy_values else value
		)
		applied_count += 1
	return applied_count


## 从目标对象解析 ShaderMaterial。
## [br]
## @api public
## [br]
## @param target: ShaderMaterial，或持有材质属性的对象。
## [br]
## @param material_property: 当 target 不是 ShaderMaterial 时读取的材质属性路径。
## [br]
## @return: 解析出的 ShaderMaterial；失败时返回 null。
func resolve_shader_material(
	target: Object,
	material_property: NodePath = DEFAULT_MATERIAL_PROPERTY
) -> ShaderMaterial:
	return _resolve_shader_material(target, material_property, false, false)


## 获取 ShaderMaterial 当前 shader 声明的 uniform 参数名。
## [br]
## @api public
## [br]
## @param material: 目标 ShaderMaterial。
## [br]
## @return: 参数名数组。
## [br]
## @schema return: Array[StringName]，material.shader 声明的 shader uniform 名称。
func get_shader_parameter_names(material: ShaderMaterial) -> Array[StringName]:
	var names: Array[StringName] = []
	if material == null or material.shader == null:
		return names

	for uniform_value: Variant in material.shader.get_shader_uniform_list():
		if not (uniform_value is Dictionary):
			continue
		var uniform: Dictionary = uniform_value
		var parameter_name: StringName = GFVariantData.get_option_string_name(uniform, "name", &"")
		if parameter_name != &"":
			names.append(parameter_name)
	return names


## 检查 ShaderMaterial 的 shader 是否声明了指定 uniform。
## [br]
## @api public
## [br]
## @param material: 目标 ShaderMaterial。
## [br]
## @param parameter_name: Shader uniform 参数名。
## [br]
## @return: 参数存在时返回 true。
func has_shader_parameter(material: ShaderMaterial, parameter_name: StringName) -> bool:
	if parameter_name == &"":
		return false
	return get_shader_parameter_names(material).has(parameter_name)


# --- 私有/辅助方法 ---

func _resolve_shader_material(
	target: Object,
	material_property: NodePath,
	duplicate_material: bool,
	warn_on_invalid_target: bool
) -> ShaderMaterial:
	if target is ShaderMaterial:
		return _variant_to_shader_material(target)
	if not is_instance_valid(target):
		_warn_invalid_target("目标对象无效。", warn_on_invalid_target)
		return null
	if material_property.is_empty():
		_warn_invalid_target("材质属性路径为空。", warn_on_invalid_target)
		return null
	if not GFObjectPropertyTools.has_property_path(target, material_property):
		_warn_invalid_target("目标材质属性不存在：%s。" % String(material_property), warn_on_invalid_target)
		return null

	var material_value: Variant = target.get_indexed(material_property)
	if not (material_value is ShaderMaterial):
		_warn_invalid_target("目标材质属性不是 ShaderMaterial：%s。" % String(material_property), warn_on_invalid_target)
		return null

	var material: ShaderMaterial = _variant_to_shader_material(material_value)
	if not duplicate_material:
		return material

	var duplicated_value: Variant = material.duplicate(true)
	if not (duplicated_value is ShaderMaterial):
		_warn_invalid_target("材质复制结果不是 ShaderMaterial。", warn_on_invalid_target)
		return material

	var duplicated_material: ShaderMaterial = _variant_to_shader_material(duplicated_value)
	var write_result: Dictionary = GFObjectPropertyTools.write_property(
		target,
		material_property,
		duplicated_material
	)
	if not GFVariantData.get_option_bool(write_result, "ok"):
		_warn_invalid_target(
			"复制材质写回失败：%s。" % GFVariantData.get_option_string(write_result, "error"),
			warn_on_invalid_target
		)
		return material
	return duplicated_material


func _get_option_node_path(options: Dictionary, key: Variant, default_value: NodePath) -> NodePath:
	var raw_value: Variant = GFVariantData.get_option_value(options, key, default_value)
	if raw_value is NodePath:
		var node_path_value: NodePath = raw_value
		return node_path_value
	if raw_value is String:
		var text_value: String = raw_value
		return NodePath(text_value)
	if raw_value is StringName:
		var string_name_value: StringName = raw_value
		return NodePath(String(string_name_value))
	return default_value


func _warn_invalid_target(message: String, enabled: bool) -> void:
	if enabled:
		push_warning("[GFShaderParameterUtility] %s" % message)


func _variant_to_shader_material(value: Variant) -> ShaderMaterial:
	if value is ShaderMaterial:
		var material: ShaderMaterial = value
		return material
	return null


func _variant_to_parameter_name(value: Variant) -> StringName:
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	if value is String:
		var text_value: String = value
		return StringName(text_value)
	return &""
