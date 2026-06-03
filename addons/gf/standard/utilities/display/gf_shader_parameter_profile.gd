## GFShaderParameterProfile: 通用 ShaderMaterial 参数集合资源。
##
## 用 Resource 保存一组 shader uniform 参数值，便于项目把视觉 profile、天气表现、
## 选中态或后处理参数声明为可合并、可复制、可插值的数据。它不提供具体 shader、
## 色彩风格或业务语义。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 4.3.0
class_name GFShaderParameterProfile
extends Resource


# --- 导出变量 ---

## Shader 参数字典。键应为 StringName 或 String，值为项目 shader uniform 接受的 Variant。
## [br]
## @api public
## [br]
## @schema parameters: Dictionary[StringName, Variant]，保存 shader uniform 名到参数值的映射。
@export var parameters: Dictionary = {}

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[String, Variant]，项目自定义元数据；框架不会读取或改写其中字段。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 设置一个 shader 参数值。
## [br]
## @api public
## [br]
## @param parameter_name: Shader uniform 参数名。
## [br]
## @param value: 要保存的参数值。
## [br]
## @schema value: Variant，可被 ShaderMaterial.set_shader_parameter() 接受的参数值。
## [br]
## @return: 当前 profile，便于链式配置。
func set_parameter(parameter_name: StringName, value: Variant) -> GFShaderParameterProfile:
	if parameter_name == &"":
		return self

	parameters[parameter_name] = GFVariantData.duplicate_variant(value)
	emit_changed()
	return self


## 获取一个 shader 参数值。
## [br]
## @api public
## [br]
## @param parameter_name: Shader uniform 参数名。
## [br]
## @param default_value: 参数不存在时返回的默认值。
## [br]
## @schema default_value: Variant fallback value returned unchanged when the parameter is missing.
## [br]
## @return: 参数值副本或默认值。
## [br]
## @schema return: Variant shader parameter value or the supplied default value.
func get_parameter(parameter_name: StringName, default_value: Variant = null) -> Variant:
	var key: Variant = _find_parameter_key(parameter_name)
	if key == null:
		return default_value
	return GFVariantData.duplicate_variant(parameters[key])


## 检查 profile 是否包含指定参数。
## [br]
## @api public
## [br]
## @param parameter_name: Shader uniform 参数名。
## [br]
## @return: 存在时返回 true。
func has_parameter(parameter_name: StringName) -> bool:
	return _find_parameter_key(parameter_name) != null


## 移除指定 shader 参数。
## [br]
## @api public
## [br]
## @param parameter_name: Shader uniform 参数名。
## [br]
## @return: 实际移除参数时返回 true。
func erase_parameter(parameter_name: StringName) -> bool:
	var key: Variant = _find_parameter_key(parameter_name)
	if key == null:
		return false
	var existed: bool = parameters.has(key)
	var _erased: bool = parameters.erase(key)
	if existed:
		emit_changed()
	return existed


## 清空所有 shader 参数。
## [br]
## @api public
func clear_parameters() -> void:
	if parameters.is_empty():
		return
	parameters.clear()
	emit_changed()


## 获取参数名列表。
## [br]
## @api public
## [br]
## @return: 参数名数组。
## [br]
## @schema return: Array[StringName]，当前 profile 中可识别的 shader 参数名。
func get_parameter_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for raw_key: Variant in parameters.keys():
		var parameter_name: StringName = _variant_to_parameter_name(raw_key)
		if parameter_name != &"":
			names.append(parameter_name)
	return names


## 合并另一个 profile。
## [br]
## @api public
## [br]
## @param source: 来源 profile。
## [br]
## @param overwrite: 为 true 时覆盖当前已有参数和 metadata 字段。
## [br]
## @return: 当前 profile，便于链式配置。
func merge_from(source: GFShaderParameterProfile, overwrite: bool = true) -> GFShaderParameterProfile:
	if source == null:
		return self

	var did_change: bool = false
	for parameter_name: StringName in source.get_parameter_names():
		if not overwrite and has_parameter(parameter_name):
			continue
		parameters[parameter_name] = GFVariantData.duplicate_variant(source.get_parameter(parameter_name))
		did_change = true

	var _merge_metadata_result: Dictionary = GFVariantData.merge_metadata(
		metadata,
		source.metadata,
		overwrite
	)
	if did_change or not source.metadata.is_empty():
		emit_changed()
	return self


## 构建当前 profile 到目标 profile 的插值副本。
## [br]
## @api public
## [br]
## @param target_profile: 目标 profile。
## [br]
## @param weight: 插值权重，0 返回当前值，1 返回目标值。
## [br]
## @param options: 可选项，支持 include_unmatched。
## [br]
## @return: 新的插值 profile。
## [br]
## @schema options: Dictionary，include_unmatched 为 true 时会把只存在于目标 profile 的参数复制到结果中。未在两端同时提供默认值的参数无法平滑过渡。
func blend_with(
	target_profile: GFShaderParameterProfile,
	weight: float,
	options: Dictionary = {}
) -> GFShaderParameterProfile:
	var result: GFShaderParameterProfile = duplicate_profile()
	if target_profile == null:
		return result

	var safe_weight: float = clampf(weight, 0.0, 1.0)
	var include_unmatched: bool = GFVariantData.get_option_bool(options, "include_unmatched", true)
	for parameter_name: StringName in target_profile.get_parameter_names():
		if has_parameter(parameter_name):
			var _set_blended_result: GFShaderParameterProfile = result.set_parameter(
				parameter_name,
				_blend_value(
					get_parameter(parameter_name),
					target_profile.get_parameter(parameter_name),
					safe_weight
				)
			)
		elif include_unmatched:
			var _set_unmatched_result: GFShaderParameterProfile = result.set_parameter(
				parameter_name,
				target_profile.get_parameter(parameter_name)
			)

	if safe_weight >= 1.0:
		result.metadata = target_profile.metadata.duplicate(true)
	return result


## 复制 profile。
## [br]
## @api public
## [br]
## @return: 深拷贝后的 profile。
func duplicate_profile() -> GFShaderParameterProfile:
	var copy: GFShaderParameterProfile = GFShaderParameterProfile.new()
	copy.parameters = _duplicate_parameter_dictionary(parameters)
	copy.metadata = metadata.duplicate(true)
	return copy


## 转换为 Dictionary。
## [br]
## @api public
## [br]
## @return: profile 字典。
## [br]
## @schema return: Dictionary，包含 parameters 和 metadata 字段。
func to_dict() -> Dictionary:
	return {
		"parameters": _duplicate_parameter_dictionary(parameters),
		"metadata": metadata.duplicate(true),
	}


## 应用 Dictionary 数据。
## [br]
## @api public
## [br]
## @param data: profile 字典。
## [br]
## @schema data: Dictionary，可包含 parameters 和 metadata 字段。
func apply_dict(data: Dictionary) -> void:
	parameters.clear()
	var source_parameters: Dictionary = GFVariantData.get_option_dictionary(data, "parameters")
	for raw_key: Variant in source_parameters.keys():
		var parameter_name: StringName = _variant_to_parameter_name(raw_key)
		if parameter_name == &"":
			continue
		parameters[parameter_name] = GFVariantData.duplicate_variant(source_parameters[raw_key])
	metadata = GFVariantData.get_option_dictionary(data, "metadata")
	emit_changed()


## 从 Dictionary 创建 profile。
## [br]
## @api public
## [br]
## @param data: profile 字典。
## [br]
## @return: 新 profile。
## [br]
## @schema data: Dictionary，可包含 parameters 和 metadata 字段。
static func from_dict(data: Dictionary) -> GFShaderParameterProfile:
	var profile: GFShaderParameterProfile = GFShaderParameterProfile.new()
	profile.apply_dict(data)
	return profile


# --- 私有/辅助方法 ---

func _find_parameter_key(parameter_name: StringName) -> Variant:
	if parameter_name == &"":
		return null
	if parameters.has(parameter_name):
		return parameter_name

	var text_name: String = String(parameter_name)
	if parameters.has(text_name):
		return text_name
	return null


static func _duplicate_parameter_dictionary(source: Dictionary) -> Dictionary:
	var copy: Dictionary = {}
	for raw_key: Variant in source.keys():
		var parameter_name: StringName = _variant_to_parameter_name(raw_key)
		if parameter_name == &"":
			continue
		copy[parameter_name] = GFVariantData.duplicate_variant(source[raw_key])
	return copy


static func _blend_value(from_value: Variant, to_value: Variant, weight: float) -> Variant:
	if weight <= 0.0:
		return GFVariantData.duplicate_variant(from_value)
	if weight >= 1.0:
		return GFVariantData.duplicate_variant(to_value)

	if _is_numeric_value(from_value) and _is_numeric_value(to_value):
		var blended_number: float = lerpf(_number_to_float(from_value), _number_to_float(to_value), weight)
		if typeof(from_value) == TYPE_INT and typeof(to_value) == TYPE_INT:
			return roundi(blended_number)
		return blended_number
	if from_value is Color and to_value is Color:
		var from_color: Color = from_value
		var to_color: Color = to_value
		return from_color.lerp(to_color, weight)
	if from_value is Vector2 and to_value is Vector2:
		var from_vector_2: Vector2 = from_value
		var to_vector_2: Vector2 = to_value
		return from_vector_2.lerp(to_vector_2, weight)
	if from_value is Vector3 and to_value is Vector3:
		var from_vector_3: Vector3 = from_value
		var to_vector_3: Vector3 = to_value
		return from_vector_3.lerp(to_vector_3, weight)
	if from_value is Vector4 and to_value is Vector4:
		var from_vector_4: Vector4 = from_value
		var to_vector_4: Vector4 = to_value
		return from_vector_4.lerp(to_vector_4, weight)
	if from_value is Quaternion and to_value is Quaternion:
		var from_quaternion: Quaternion = from_value
		var to_quaternion: Quaternion = to_value
		return from_quaternion.slerp(to_quaternion, weight)
	return GFVariantData.duplicate_variant(from_value)


static func _is_numeric_value(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _number_to_float(value: Variant) -> float:
	match typeof(value):
		TYPE_FLOAT:
			var float_value: float = value
			return float_value
		TYPE_INT:
			var int_value: int = value
			return float(int_value)
	return 0.0


static func _variant_to_parameter_name(value: Variant) -> StringName:
	if value is StringName:
		var string_name_value: StringName = value
		return string_name_value
	if value is String:
		var text_value: String = value
		return StringName(text_value)
	return &""
