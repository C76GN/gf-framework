@tool

# GF 插件 ProjectSettings 注册辅助。
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PROJECT_SETTINGS_TOOLS = preload("res://addons/gf/kernel/core/gf_project_settings_tools.gd")
const _GF_RESOURCE_PATH_HINT_SCRIPT = preload("res://addons/gf/kernel/editor/gf_resource_path_hint.gd")

## 项目启动 Installer 列表设置。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const INSTALLERS_SETTING: String = "gf/project/installers"

## 项目启动 Installer 列表默认值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const INSTALLERS_DEFAULT: Array[String] = []

## Installer 错误是否中断初始化设置。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const FAIL_ON_INSTALLER_ERROR_SETTING: String = "gf/project/fail_on_installer_error"

## Installer 错误中断初始化默认值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const FAIL_ON_INSTALLER_ERROR_DEFAULT: bool = true

## Installer 超时设置。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const INSTALLER_TIMEOUT_SETTING: String = "gf/project/installer_timeout_seconds"

## Installer 超时默认值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const INSTALLER_TIMEOUT_DEFAULT: float = 0.0

## GF 访问器输出路径设置。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ACCESS_OUTPUT_SETTING: String = "gf/codegen/access_output_path"

## GF 访问器输出路径默认值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ACCESS_OUTPUT_DEFAULT: String = "res://gf/generated/gf_access.gd"

## 项目访问器输出路径设置。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const PROJECT_ACCESS_OUTPUT_SETTING: String = "gf/codegen/project_access_output_path"

## 项目访问器输出路径默认值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const PROJECT_ACCESS_OUTPUT_DEFAULT: String = "res://gf/generated/gf_project_access.gd"

## 扩展启用设置脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFExtensionSettingsBase = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")


# --- 公共方法 ---

## 确保所有 GF ProjectSettings 存在并注册显示信息。
##
## 该方法只补齐缺失默认值和 Inspector 属性提示，不会清理本次未贡献的设置。
## 已写入的 ProjectSettings 归项目所有；模块禁用、贡献消失或 core-only 回退时，
## GF 不会自动删除用户项目配置，也不会隐式保存当前进程中的其他临时设置。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param project_setting_records: 由标准库或扩展贡献的 ProjectSettings 记录。
## [br]
## @schema project_setting_records: Array[Dictionary] with setting registration fields and optional editor_labels, editor_descriptions, editor_enum_labels, and editor_enum_descriptions presentation maps.
static func ensure_all(project_setting_records: Array[Dictionary] = []) -> void:
	var _installers_ensured: bool = _ensure_default(INSTALLERS_SETTING, INSTALLERS_DEFAULT)
	var _fail_policy_ensured: bool = _ensure_default(
		FAIL_ON_INSTALLER_ERROR_SETTING,
		FAIL_ON_INSTALLER_ERROR_DEFAULT
	)
	var _timeout_ensured: bool = _ensure_default(
		INSTALLER_TIMEOUT_SETTING,
		INSTALLER_TIMEOUT_DEFAULT
	)
	var _access_output_ensured: bool = _ensure_default(
		ACCESS_OUTPUT_SETTING,
		ACCESS_OUTPUT_DEFAULT
	)
	var _project_access_output_ensured: bool = _ensure_default(
		PROJECT_ACCESS_OUTPUT_SETTING,
		PROJECT_ACCESS_OUTPUT_DEFAULT
	)
	var _contributed_settings_ensured: bool = _ensure_project_setting_records(
		project_setting_records
	)
	var _extension_defaults_ensured: bool = GFExtensionSettingsBase.ensure_defaults()

	_register_property_info()
	GFExtensionSettingsBase.register_property_info()


## 获取 GF 访问器输出路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return GF 访问器输出路径。
static func get_access_output_path() -> String:
	return _GF_VARIANT_ACCESS_SCRIPT.to_text(ProjectSettings.get_setting(ACCESS_OUTPUT_SETTING, ACCESS_OUTPUT_DEFAULT))


## 获取项目访问器输出路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 项目访问器输出路径。
static func get_project_access_output_path() -> String:
	return _GF_VARIANT_ACCESS_SCRIPT.to_text(ProjectSettings.get_setting(PROJECT_ACCESS_OUTPUT_SETTING, PROJECT_ACCESS_OUTPUT_DEFAULT))


# --- 私有/辅助方法 ---

static func _ensure_default(setting_name: String, default_value: Variant) -> bool:
	return _GF_PROJECT_SETTINGS_TOOLS.ensure_setting(setting_name, default_value, {
		"register_property_info": false,
	})


static func _ensure_project_setting_records(project_setting_records: Array[Dictionary]) -> bool:
	var should_save: bool = false
	for record: Dictionary in project_setting_records:
		var setting_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "name").strip_edges()
		if setting_name.is_empty():
			continue

		var default_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(record, "default_value")
		var options: Dictionary = _make_project_setting_options(record, default_value)
		if _GF_PROJECT_SETTINGS_TOOLS.ensure_setting(setting_name, default_value, options):
			should_save = true
	return should_save


static func _register_property_info() -> void:
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(INSTALLERS_SETTING, TYPE_ARRAY, {
		"hint": _GF_RESOURCE_PATH_HINT_SCRIPT.RESOURCE_PATH_ARRAY,
		"hint_string": "Script",
		"basic": true,
	})
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(FAIL_ON_INSTALLER_ERROR_SETTING, TYPE_BOOL, {
		"basic": true,
	})
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(INSTALLER_TIMEOUT_SETTING, TYPE_FLOAT, {
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,600,0.1,or_greater",
		"basic": true,
	})
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(ACCESS_OUTPUT_SETTING, TYPE_STRING, {
		"hint": PROPERTY_HINT_SAVE_FILE,
		"hint_string": "*.gd",
		"basic": true,
	})
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(PROJECT_ACCESS_OUTPUT_SETTING, TYPE_STRING, {
		"hint": PROPERTY_HINT_SAVE_FILE,
		"hint_string": "*.gd",
		"basic": true,
	})


static func _make_project_setting_options(record: Dictionary, default_value: Variant) -> Dictionary:
	var options: Dictionary = {
		"type": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "type", typeof(default_value)),
		"register_property_info": true,
	}
	for bool_key: String in ["basic", "restart_if_changed", "internal", "update_initial_value"]:
		if record.has(bool_key):
			options[bool_key] = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(record, bool_key, false)
	if record.has("hint"):
		options["hint"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "hint", PROPERTY_HINT_NONE)
	if record.has("hint_string"):
		options["hint_string"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "hint_string", "")
	if record.has("usage"):
		options["usage"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(record, "usage", -1)
	return options
