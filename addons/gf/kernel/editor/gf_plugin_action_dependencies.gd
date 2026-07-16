@tool

## GFPluginActionDependencies: GF 插件菜单动作依赖 provider。
##
## 把 ProjectSettings 读取、访问器生成器创建和启用扩展动作路径发现隔离在
## 单一内部边界中，避免菜单动作辅助脚本直接依赖启动期全局 class_name。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 8.0.0
## [br]
## @layer kernel/editor
class_name GFPluginActionDependencies
extends RefCounted


# --- 常量 ---

const _GF_ACCESS_GENERATOR_SCRIPT = preload("res://addons/gf/kernel/editor/gf_access_generator.gd")
const _GF_EXTENSION_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")
const _GF_PLUGIN_PROJECT_SETTINGS_SCRIPT = preload("res://addons/gf/kernel/editor/gf_plugin_project_settings.gd")


# --- 框架内部方法 ---

## 获取 GF 访问器输出路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return GF 访问器输出路径。
func get_access_output_path() -> String:
	return _GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.get_access_output_path()


## 获取项目常量访问器输出路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 项目常量访问器输出路径。
func get_project_access_output_path() -> String:
	return _GF_PLUGIN_PROJECT_SETTINGS_SCRIPT.get_project_access_output_path()


## 生成 GF 强类型访问器。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param output_path: 访问器输出路径。
## [br]
## @return 生成结果错误码。
func generate_accessors(output_path: String) -> Error:
	var generator: _GF_ACCESS_GENERATOR_SCRIPT = _GF_ACCESS_GENERATOR_SCRIPT.new()
	return generator.generate(output_path)


## 生成项目常量访问器。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param output_path: 项目常量访问器输出路径。
## [br]
## @return 生成结果错误码。
func generate_project_accessors(output_path: String) -> Error:
	var generator: _GF_ACCESS_GENERATOR_SCRIPT = _GF_ACCESS_GENERATOR_SCRIPT.new()
	return generator.generate_project_access(output_path)


## 获取启用扩展声明的编辑器菜单动作路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 编辑器菜单动作脚本路径列表。
func get_enabled_editor_action_paths() -> Array[String]:
	return _GF_EXTENSION_SETTINGS_SCRIPT.get_enabled_editor_action_paths()
