## GFProjectSettingsTools: ProjectSettings 默认值和属性信息注册工具。
##
## 用于让插件、扩展和项目工具以一致方式声明 ProjectSettings 键、默认值、
## 缺失键的初始值和 Inspector 元数据。工具不解释具体设置语义，也不保存 project.godot。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFProjectSettingsTools
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共方法 ---

## 确保 ProjectSettings 键存在，并可选注册 Inspector 属性信息。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param setting_name: ProjectSettings 键名。
## [br]
## @param default_value: 缺失时写入的默认值，也会作为缺失键的重置初始值。
## [br]
## @schema default_value: Variant ProjectSettings default value.
## [br]
## @param options: 可选参数，支持 type、hint、hint_string、usage、basic、restart_if_changed、internal、register_property_info 和 update_initial_value。
## [br]
## @return 本次是否写入了默认值。
## [br]
## @schema options: Dictionary with optional type: int, hint: int, hint_string: String, usage: int, basic: bool, restart_if_changed: bool, internal: bool, register_property_info: bool, and update_initial_value: bool.
static func ensure_setting(
	setting_name: String,
	default_value: Variant,
	options: Dictionary = {}
) -> bool:
	var normalized_name: String = setting_name.strip_edges()
	if normalized_name.is_empty():
		push_error("[GFProjectSettingsTools] setting_name 不能为空。")
		return false

	var wrote_default: bool = false
	if not ProjectSettings.has_setting(normalized_name):
		ProjectSettings.set_setting(normalized_name, default_value)
		ProjectSettings.set_initial_value(normalized_name, default_value)
		wrote_default = true
	elif _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "update_initial_value", false):
		ProjectSettings.set_initial_value(normalized_name, default_value)

	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "register_property_info", true):
		register_property_info(
			normalized_name,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "type", typeof(default_value)),
			options
		)
	return wrote_default


## 注册 ProjectSettings Inspector 属性信息和显示标记。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param setting_name: ProjectSettings 键名。
## [br]
## @param value_type: Godot Variant 类型常量。
## [br]
## @param options: 可选参数，支持 hint、hint_string、usage、basic、restart_if_changed 和 internal。
## [br]
## @schema options: Dictionary with optional hint: int, hint_string: String, usage: int, basic: bool, restart_if_changed: bool, and internal: bool.
static func register_property_info(
	setting_name: String,
	value_type: int,
	options: Dictionary = {}
) -> void:
	var normalized_name: String = setting_name.strip_edges()
	if normalized_name.is_empty():
		push_error("[GFProjectSettingsTools] setting_name 不能为空。")
		return

	if value_type != TYPE_NIL:
		var property_info: Dictionary = {
			"name": normalized_name,
			"type": value_type,
		}
		var hint: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "hint", PROPERTY_HINT_NONE)
		var hint_string: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "hint_string", "")
		var usage: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "usage", -1)
		if hint != PROPERTY_HINT_NONE:
			property_info["hint"] = hint
		if not hint_string.is_empty():
			property_info["hint_string"] = hint_string
		if usage >= 0:
			property_info["usage"] = usage
		ProjectSettings.add_property_info(property_info)

	if options.has("basic"):
		ProjectSettings.set_as_basic(
			normalized_name,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "basic", false)
		)
	if options.has("restart_if_changed"):
		ProjectSettings.set_restart_if_changed(
			normalized_name,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "restart_if_changed", false)
		)
	if options.has("internal"):
		ProjectSettings.set_as_internal(
			normalized_name,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "internal", false)
		)
