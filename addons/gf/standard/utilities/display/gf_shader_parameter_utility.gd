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

const _GLOBAL_SHADER_SETTING_PREFIX: String = "shader_globals/"
const _INVALID_GLOBAL_PARAMETER_TYPE: int = -1


# --- 私有变量 ---

static var _registered_global_parameter_names: Dictionary = {}


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


## 将 shader 参数 profile 应用到 RenderingServer 全局 shader 参数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param profile: 要应用的 shader 参数 profile。
## [br]
## @param options: 可选项，支持 parameter_types、persist_project_setting、project_setting_types、project_setting_definitions、overwrite_project_setting、save_project_settings、register_live_parameter、copy_values、warn_on_invalid_parameter 和 dry_run。
## [br]
## @return: 批量应用报告。
## [br]
## @schema options: Dictionary，parameter_types 为 Dictionary[StringName, int]，用于覆盖 RenderingServer 全局参数类型；persist_project_setting 为 true 时写入 ProjectSettings 的 shader_globals/<name>；project_setting_types 为 Dictionary[StringName, String]，用于覆盖持久化 type；project_setting_definitions 为 Dictionary[StringName, Dictionary]，用于传入完整 ProjectSettings 定义；overwrite_project_setting 控制是否覆盖已有设置；save_project_settings 控制是否立即保存 project.godot；register_live_parameter 控制是否补当前会话 RenderingServer 注册；copy_values 控制写入前是否复制集合值；warn_on_invalid_parameter 控制无效参数 warning；dry_run 为 true 时只生成报告。
## [br]
## @schema return: Dictionary，包含 ok、applied_count、registered_count、updated_count、project_setting_written_count、project_settings_saved、parameters 和 issues；每个参数报告区分 live 与 declaration 状态。
func apply_global_profile(profile: GFShaderParameterProfile, options: Dictionary = {}) -> Dictionary:
	if profile == null:
		var null_report: Dictionary = _make_global_batch_report()
		var null_issues: Array[String] = ["profile 为空。"]
		null_report["ok"] = false
		null_report["error"] = "profile 为空。"
		null_report["issues"] = null_issues
		return null_report
	return apply_global_parameters(profile.parameters, options)


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


## 将 shader 参数字典应用到 RenderingServer 全局 shader 参数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param parameters: 要应用的全局 shader 参数字典。
## [br]
## @param options: 可选项，支持 parameter_types、persist_project_setting、project_setting_types、project_setting_definitions、overwrite_project_setting、save_project_settings、register_live_parameter、copy_values、warn_on_invalid_parameter 和 dry_run。
## [br]
## @return: 批量应用报告。
## [br]
## @schema parameters: Dictionary[StringName, Variant]，全局 shader uniform 名到参数值的映射。
## [br]
## @schema options: Dictionary，parameter_types 为 Dictionary[StringName, int]，用于覆盖 RenderingServer 全局参数类型；persist_project_setting 为 true 时写入 ProjectSettings 的 shader_globals/<name>；project_setting_types 为 Dictionary[StringName, String]，用于覆盖持久化 type；project_setting_definitions 为 Dictionary[StringName, Dictionary]，用于传入完整 ProjectSettings 定义；overwrite_project_setting 控制是否覆盖已有设置；save_project_settings 控制是否立即保存 project.godot；register_live_parameter 控制是否补当前会话 RenderingServer 注册；copy_values 控制写入前是否复制集合值；warn_on_invalid_parameter 控制无效参数 warning；dry_run 为 true 时只生成报告。
## [br]
## @schema return: Dictionary，包含 ok、applied_count、registered_count、updated_count、project_setting_written_count、project_settings_saved、parameters 和 issues；每个参数报告区分 live 与 declaration 状态。
func apply_global_parameters(parameters: Dictionary, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_global_batch_report()
	var parameter_reports: Array[Dictionary] = []
	var issues: Array[String] = []
	if parameters.is_empty():
		report["parameters"] = parameter_reports
		report["issues"] = issues
		return report

	var parameter_types: Dictionary = GFVariantData.get_option_dictionary(options, "parameter_types")
	var save_project_settings: bool = GFVariantData.get_option_bool(options, "save_project_settings", false)
	var dry_run: bool = GFVariantData.get_option_bool(options, "dry_run", false)
	var applied_count: int = 0
	var registered_count: int = 0
	var updated_count: int = 0
	var project_setting_written_count: int = 0
	for raw_key: Variant in parameters.keys():
		var parameter_name: StringName = _variant_to_parameter_name(raw_key)
		if parameter_name == &"":
			issues.append("全局 shader 参数名无效。")
			continue

		var value: Variant = parameters[raw_key]
		var parameter_type: int = GFVariantData.get_option_int(
			parameter_types,
			parameter_name,
			_INVALID_GLOBAL_PARAMETER_TYPE
		)
		if parameter_type == _INVALID_GLOBAL_PARAMETER_TYPE:
			parameter_type = _infer_global_parameter_type(value)

		var entry_options: Dictionary = _build_global_parameter_options(options, parameter_name)
		entry_options["update_live_value"] = true
		entry_options["save_project_settings"] = false
		var parameter_report: Dictionary = _ensure_global_parameter_internal(
			parameter_name,
			parameter_type,
			value,
			entry_options,
			false
		)
		parameter_reports.append(parameter_report)

		if GFVariantData.get_option_bool(parameter_report, "ok"):
			applied_count += 1
		else:
			issues.append(GFVariantData.get_option_string(parameter_report, "error"))
		if GFVariantData.get_option_bool(parameter_report, "live_registered"):
			registered_count += 1
		if GFVariantData.get_option_bool(parameter_report, "live_updated"):
			updated_count += 1
		if GFVariantData.get_option_bool(parameter_report, "project_setting_written"):
			project_setting_written_count += 1

	var project_settings_saved: bool = false
	if save_project_settings and project_setting_written_count > 0 and not dry_run:
		var save_result: int = ProjectSettings.save()
		if save_result == OK:
			project_settings_saved = true
		else:
			issues.append("ProjectSettings.save() 失败：%s。" % error_string(save_result))

	report["ok"] = issues.is_empty()
	report["applied_count"] = applied_count
	report["registered_count"] = registered_count
	report["updated_count"] = updated_count
	report["project_setting_written_count"] = project_setting_written_count
	report["project_settings_saved"] = project_settings_saved
	report["parameters"] = parameter_reports
	report["issues"] = issues
	if not issues.is_empty():
		report["error"] = "; ".join(PackedStringArray(issues))
	return report


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


## 确保 RenderingServer 全局 shader 参数存在，并可选写入 ProjectSettings。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param parameter_name: 全局 shader uniform 参数名。
## [br]
## @param parameter_type: RenderingServer.GLOBAL_VAR_TYPE_* 参数类型。
## [br]
## @param default_value: 参数缺失时用于注册或持久化的默认值。
## [br]
## @param options: 可选项，支持 persist_project_setting、project_setting_type、project_setting_definition、overwrite_project_setting、save_project_settings、register_live_parameter、update_live_value、copy_values、warn_on_invalid_parameter 和 dry_run。
## [br]
## @return: 参数处理报告。
## [br]
## @schema default_value: Variant，可被 RenderingServer.global_shader_parameter_add() 或 ProjectSettings shader_globals 定义接受的默认值。
## [br]
## @schema options: Dictionary，persist_project_setting 为 true 时写入由参数名唯一派生的 shader_globals/<name>；project_setting_type 覆盖持久化 type；project_setting_definition 提供完整声明；overwrite_project_setting 控制是否覆盖已有设置；save_project_settings 控制是否立即保存 project.godot；register_live_parameter 控制是否补当前会话 RenderingServer 注册；update_live_value 控制是否同时设置当前值；copy_values 控制写入前是否复制集合值；warn_on_invalid_parameter 控制无效参数 warning；dry_run 为 true 时只生成报告。
## [br]
## @schema return: Dictionary，包含 ok、parameter_name、parameter_type、live_registered、live_already_registered、live_available、live_updated、project_setting_path、project_setting_written、project_setting_already_present、declaration_written、declaration_already_present、declaration_available、project_settings_saved 和 error。
func ensure_global_parameter(
	parameter_name: StringName,
	parameter_type: int,
	default_value: Variant = null,
	options: Dictionary = {}
) -> Dictionary:
	return _ensure_global_parameter_internal(parameter_name, parameter_type, default_value, options, true)


## 获取 GF 可稳定识别的全局 shader 参数名。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return: 全局 shader 参数名数组。
## [br]
## @schema return: Array[StringName]，包含 GF 本次会话通过本工具注册的 live 参数，以及 ProjectSettings shader_globals/<name> declaration 参数。
func get_global_parameter_names() -> Array[StringName]:
	var names: Array[StringName] = []
	_append_registered_global_parameter_names(names)
	_append_project_setting_global_parameter_names(names)
	return names


## 获取 GF 本次会话通过本工具注册的 live 全局 shader 参数名。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return: live 全局 shader 参数名数组。
## [br]
## @schema return: Array[StringName]，只包含本工具在当前会话中注册的 RenderingServer 全局参数。
func get_global_parameter_live_names() -> Array[StringName]:
	var names: Array[StringName] = []
	_append_registered_global_parameter_names(names)
	return names


## 获取 ProjectSettings 中声明的全局 shader 参数名。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return: declaration 全局 shader 参数名数组。
## [br]
## @schema return: Array[StringName]，只包含 ProjectSettings shader_globals/<name> declaration。
func get_global_parameter_declaration_names() -> Array[StringName]:
	var names: Array[StringName] = []
	_append_project_setting_global_parameter_names(names)
	return names


## 检查当前会话是否已通过本工具注册指定 live 全局 shader 参数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param parameter_name: 全局 shader uniform 参数名。
## [br]
## @return: live 参数存在时返回 true。
func has_global_parameter(parameter_name: StringName) -> bool:
	return has_global_parameter_live(parameter_name)


## 检查当前会话是否已通过本工具注册指定 live 全局 shader 参数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param parameter_name: 全局 shader uniform 参数名。
## [br]
## @return: live 参数存在时返回 true。
func has_global_parameter_live(parameter_name: StringName) -> bool:
	if parameter_name == &"":
		return false
	return _registered_global_parameter_names.has(parameter_name)


## 检查 ProjectSettings 是否声明了指定全局 shader 参数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param parameter_name: 全局 shader uniform 参数名。
## [br]
## @return: declaration 存在时返回 true。
func has_global_parameter_declaration(parameter_name: StringName) -> bool:
	if parameter_name == &"":
		return false
	return ProjectSettings.has_setting(_GLOBAL_SHADER_SETTING_PREFIX + String(parameter_name))


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


func _ensure_global_parameter_internal(
	parameter_name: StringName,
	parameter_type: int,
	default_value: Variant,
	options: Dictionary,
	save_immediately: bool
) -> Dictionary:
	var report: Dictionary = _make_global_parameter_report(parameter_name, parameter_type)
	var warn_on_invalid_parameter: bool = GFVariantData.get_option_bool(
		options,
		"warn_on_invalid_parameter",
		true
	)
	if parameter_name == &"":
		return _fail_global_parameter_report(report, "全局 shader 参数名不能为空。", warn_on_invalid_parameter)
	if parameter_type == _INVALID_GLOBAL_PARAMETER_TYPE:
		return _fail_global_parameter_report(
			report,
			"无法推断全局 shader 参数类型：%s。" % String(parameter_name),
			warn_on_invalid_parameter
		)
	if GFVariantData.get_option_bool(options, "persist_project_setting", false):
		report["project_setting_path"] = _get_global_project_setting_path(parameter_name)
		if options.has("project_setting_path"):
			return _fail_global_parameter_report(
				report,
				"project_setting_path 不受支持；全局 shader 声明只能写入由参数名派生的 shader_globals 命名空间。",
				warn_on_invalid_parameter
			)

	var dry_run: bool = GFVariantData.get_option_bool(options, "dry_run", false)
	var copy_values: bool = GFVariantData.get_option_bool(options, "copy_values", true)
	var parameter_value: Variant = GFVariantData.duplicate_variant(default_value) if copy_values else default_value
	var register_live_parameter: bool = GFVariantData.get_option_bool(options, "register_live_parameter", true)
	var update_live_value: bool = GFVariantData.get_option_bool(options, "update_live_value", false)
	var live_exists: bool = has_global_parameter_live(parameter_name)
	report["live_already_registered"] = live_exists
	if register_live_parameter and not live_exists:
		if not dry_run:
			RenderingServer.global_shader_parameter_add(parameter_name, parameter_type, parameter_value)
			_track_global_parameter(parameter_name)
		report["live_registered"] = true
		live_exists = true
	report["live_available"] = live_exists

	if update_live_value:
		if not live_exists:
			return _fail_global_parameter_report(
				report,
				"全局 shader 参数尚未注册：%s。" % String(parameter_name),
				warn_on_invalid_parameter
			)
		if not dry_run:
			RenderingServer.global_shader_parameter_set(parameter_name, parameter_value)
		report["live_updated"] = true

	if GFVariantData.get_option_bool(options, "persist_project_setting", false):
		var project_report: Dictionary = _persist_global_parameter_project_setting(
			parameter_name,
			parameter_type,
			parameter_value,
			options,
			save_immediately
		)
		var _merged_project_report: Dictionary = GFVariantData.merge_dictionary(
			report,
			project_report,
			true,
			false
		)
	return report


func _persist_global_parameter_project_setting(
	parameter_name: StringName,
	parameter_type: int,
	default_value: Variant,
	options: Dictionary,
	save_immediately: bool
) -> Dictionary:
	var report: Dictionary = {}
	var setting_path: String = _get_global_project_setting_path(parameter_name)
	report["project_setting_path"] = setting_path
	var definition: Dictionary = _build_project_shader_global_definition(
		parameter_type,
		default_value,
		options
	)
	if definition.is_empty():
		report["ok"] = false
		report["error"] = "无法构建全局 shader 参数持久化定义：%s。" % String(parameter_name)
		return report

	var dry_run: bool = GFVariantData.get_option_bool(options, "dry_run", false)
	var already_present: bool = ProjectSettings.has_setting(setting_path)
	var overwrite_project_setting: bool = GFVariantData.get_option_bool(
		options,
		"overwrite_project_setting",
		false
	)
	report["project_setting_already_present"] = already_present
	report["declaration_already_present"] = already_present
	if not already_present or overwrite_project_setting:
		if not dry_run:
			ProjectSettings.set_setting(setting_path, definition)
		report["project_setting_written"] = true
		report["declaration_written"] = true
	report["declaration_available"] = already_present or (
		GFVariantData.get_option_bool(report, "project_setting_written")
		and not dry_run
	)

	var save_project_settings: bool = GFVariantData.get_option_bool(options, "save_project_settings", false)
	if (
		save_immediately
		and save_project_settings
		and GFVariantData.get_option_bool(report, "project_setting_written")
		and not dry_run
	):
		var save_result: int = ProjectSettings.save()
		if save_result == OK:
			report["project_settings_saved"] = true
		else:
			report["ok"] = false
			report["error"] = "ProjectSettings.save() 失败：%s。" % error_string(save_result)
	return report


func _append_registered_global_parameter_names(names: Array[StringName]) -> void:
	for raw_parameter_name: Variant in _registered_global_parameter_names.keys():
		var parameter_name: StringName = _variant_to_parameter_name(raw_parameter_name)
		if parameter_name != &"":
			_append_unique_global_parameter_name(names, parameter_name)


func _append_project_setting_global_parameter_names(names: Array[StringName]) -> void:
	for property_info_value: Variant in ProjectSettings.get_property_list():
		if not (property_info_value is Dictionary):
			continue

		var property_info: Dictionary = property_info_value
		var setting_name: StringName = GFVariantData.get_option_string_name(
			property_info,
			"name",
			&""
		)
		var setting_path: String = String(setting_name)
		if not setting_path.begins_with(_GLOBAL_SHADER_SETTING_PREFIX):
			continue

		var parameter_text: String = setting_path.trim_prefix(_GLOBAL_SHADER_SETTING_PREFIX)
		if not parameter_text.is_empty():
			_append_unique_global_parameter_name(names, StringName(parameter_text))


func _append_unique_global_parameter_name(names: Array[StringName], parameter_name: StringName) -> void:
	if parameter_name != &"" and not names.has(parameter_name):
		names.append(parameter_name)


func _track_global_parameter(parameter_name: StringName) -> void:
	if parameter_name != &"":
		_registered_global_parameter_names[parameter_name] = true


func _build_global_parameter_options(options: Dictionary, parameter_name: StringName) -> Dictionary:
	var entry_options: Dictionary = options.duplicate(true)
	var project_setting_types: Dictionary = GFVariantData.get_option_dictionary(
		options,
		"project_setting_types"
	)
	var project_setting_type: String = GFVariantData.get_option_string(
		project_setting_types,
		parameter_name,
		""
	)
	if not project_setting_type.is_empty():
		entry_options["project_setting_type"] = project_setting_type

	var project_setting_definitions: Dictionary = GFVariantData.get_option_dictionary(
		options,
		"project_setting_definitions"
	)
	var raw_definition: Variant = _get_equivalent_dictionary_value(
		project_setting_definitions,
		parameter_name,
		null
	)
	if raw_definition is Dictionary:
		var definition: Dictionary = raw_definition
		entry_options["project_setting_definition"] = definition.duplicate(true)
	return entry_options


func _build_project_shader_global_definition(
	parameter_type: int,
	default_value: Variant,
	options: Dictionary
) -> Dictionary:
	var explicit_definition: Dictionary = GFVariantData.get_option_dictionary(
		options,
		"project_setting_definition"
	)
	if not explicit_definition.is_empty():
		return explicit_definition.duplicate(true)

	var setting_type: String = GFVariantData.get_option_string(
		options,
		"project_setting_type",
		_global_parameter_type_to_project_setting_type(parameter_type)
	)
	if setting_type.is_empty():
		return {}

	return {
		"type": setting_type,
		"value": GFVariantData.duplicate_variant(default_value),
	}


func _get_global_project_setting_path(parameter_name: StringName) -> String:
	return _GLOBAL_SHADER_SETTING_PREFIX + String(parameter_name)


func _make_global_batch_report() -> Dictionary:
	return {
		"ok": true,
		"applied_count": 0,
		"registered_count": 0,
		"updated_count": 0,
		"project_setting_written_count": 0,
		"project_settings_saved": false,
		"parameters": [],
		"issues": [],
		"error": "",
	}


func _make_global_parameter_report(parameter_name: StringName, parameter_type: int) -> Dictionary:
	return {
		"ok": true,
		"parameter_name": parameter_name,
		"parameter_type": parameter_type,
		"live_registered": false,
		"live_already_registered": false,
		"live_available": false,
		"live_updated": false,
		"project_setting_path": "",
		"project_setting_written": false,
		"project_setting_already_present": false,
		"declaration_written": false,
		"declaration_already_present": false,
		"declaration_available": false,
		"project_settings_saved": false,
		"error": "",
	}


func _fail_global_parameter_report(
	report: Dictionary,
	message: String,
	warn_on_invalid_parameter: bool
) -> Dictionary:
	report["ok"] = false
	report["error"] = message
	if warn_on_invalid_parameter:
		push_warning("[GFShaderParameterUtility] %s" % message)
	return report


func _infer_global_parameter_type(value: Variant) -> int:
	match typeof(value):
		TYPE_BOOL:
			return RenderingServer.GLOBAL_VAR_TYPE_BOOL
		TYPE_INT:
			return RenderingServer.GLOBAL_VAR_TYPE_INT
		TYPE_FLOAT:
			return RenderingServer.GLOBAL_VAR_TYPE_FLOAT
		TYPE_VECTOR2:
			return RenderingServer.GLOBAL_VAR_TYPE_VEC2
		TYPE_VECTOR2I:
			return RenderingServer.GLOBAL_VAR_TYPE_IVEC2
		TYPE_VECTOR3:
			return RenderingServer.GLOBAL_VAR_TYPE_VEC3
		TYPE_VECTOR3I:
			return RenderingServer.GLOBAL_VAR_TYPE_IVEC3
		TYPE_VECTOR4:
			return RenderingServer.GLOBAL_VAR_TYPE_VEC4
		TYPE_VECTOR4I:
			return RenderingServer.GLOBAL_VAR_TYPE_IVEC4
		TYPE_COLOR:
			return RenderingServer.GLOBAL_VAR_TYPE_COLOR
	if value is Texture2D:
		return RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D
	return _INVALID_GLOBAL_PARAMETER_TYPE


func _global_parameter_type_to_project_setting_type(parameter_type: int) -> String:
	match parameter_type:
		RenderingServer.GLOBAL_VAR_TYPE_BOOL:
			return "bool"
		RenderingServer.GLOBAL_VAR_TYPE_INT:
			return "int"
		RenderingServer.GLOBAL_VAR_TYPE_FLOAT:
			return "float"
		RenderingServer.GLOBAL_VAR_TYPE_VEC2:
			return "vec2"
		RenderingServer.GLOBAL_VAR_TYPE_IVEC2:
			return "ivec2"
		RenderingServer.GLOBAL_VAR_TYPE_VEC3:
			return "vec3"
		RenderingServer.GLOBAL_VAR_TYPE_IVEC3:
			return "ivec3"
		RenderingServer.GLOBAL_VAR_TYPE_VEC4:
			return "vec4"
		RenderingServer.GLOBAL_VAR_TYPE_IVEC4:
			return "ivec4"
		RenderingServer.GLOBAL_VAR_TYPE_COLOR:
			return "color"
		RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D:
			return "sampler2D"
	return ""


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


func _get_equivalent_dictionary_value(data: Dictionary, key: Variant, default_value: Variant) -> Variant:
	if data.has(key):
		return data[key]
	if key is StringName:
		var key_name: StringName = key
		var text_key: String = String(key_name)
		if data.has(text_key):
			return data[text_key]
	elif key is String:
		var key_text: String = key
		var name_key: StringName = StringName(key_text)
		if data.has(name_key):
			return data[name_key]
	return default_value
