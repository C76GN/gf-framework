@tool

# GF 插件 AutoLoad 管理辅助。
extends RefCounted


# --- 常量 ---

## GF AutoLoad 名称。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const AUTOLOAD_NAME: String = "Gf"

## GF AutoLoad 脚本路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const AUTOLOAD_PATH: String = "res://addons/gf/kernel/core/gf.gd"

## 记录 GF 插件是否拥有并可移除 Gf AutoLoad 的项目设置键。
## [br]
## @api private
const _AUTOLOAD_OWNERSHIP_SETTING: String = "gf/internal/autoload_gf_owned"

## 将 ProjectSettings 值转换为文本或布尔值的工具脚本。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共方法 ---

## 确保 GF AutoLoad 已安装。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
static func ensure(plugin: EditorPlugin) -> void:
	if plugin == null:
		return
	if not ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		plugin.add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		_set_autoload_ownership_marker(true)
	elif not _autoload_points_to_gf():
		_set_autoload_ownership_marker(false)
		push_warning("[GFPluginAutoload][plugin_autoload.autoload_name_conflict] An AutoLoad named Gf already targets a different resource; the plugin will not overwrite this setting.")


## 移除由 GF 插件安装的 AutoLoad。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
static func remove(plugin: EditorPlugin) -> void:
	if plugin == null:
		return
	if ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME) and _autoload_points_to_gf() and _has_autoload_ownership_marker():
		plugin.remove_autoload_singleton(AUTOLOAD_NAME)
	_set_autoload_ownership_marker(false)


## 查询 Gf 是否作为全局单例启用，并指向 GF 核心脚本的规范路径或 UID。
## 只读项目配置，不加载用户脚本，也不修改 AutoLoad 所有权。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 启用的 Gf 单例指向 GF 核心脚本时返回 true。
static func is_registered_singleton() -> bool:
	var raw_value: Variant = ProjectSettings.get_setting("autoload/%s" % AUTOLOAD_NAME, "")
	if not raw_value is String:
		return false
	var autoload_value: String = raw_value
	return autoload_value.begins_with("*") and _autoload_points_to_gf()


# --- 私有/辅助方法 ---

## 检查 autoload/Gf 指向路径或 ResourceUID 是否与 GF 核心脚本一致。
## [br]
## @api private
static func _autoload_points_to_gf() -> bool:
	var setting_path: String = "autoload/%s" % AUTOLOAD_NAME
	var raw_value: Variant = ProjectSettings.get_setting(setting_path, "")
	var autoload_value: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(raw_value).trim_prefix("*")
	if autoload_value == AUTOLOAD_PATH:
		return true

	var uid: int = ResourceLoader.get_resource_uid(AUTOLOAD_PATH)
	if uid == -1:
		return false
	return autoload_value == ResourceUID.id_to_text(uid)


## 将所有权设置值转为布尔值，缺失时按 false 处理。
## [br]
## @api private
static func _has_autoload_ownership_marker() -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(ProjectSettings.get_setting(_AUTOLOAD_OWNERSHIP_SETTING, false))


## 按 enabled 设置或清除所有权标记，仅在值发生变化时保存项目设置。
## [br]
## @api private
static func _set_autoload_ownership_marker(enabled: bool) -> void:
	var changed: bool = false
	if enabled:
		if not _has_autoload_ownership_marker():
			ProjectSettings.set_setting(_AUTOLOAD_OWNERSHIP_SETTING, true)
			changed = true
	elif ProjectSettings.has_setting(_AUTOLOAD_OWNERSHIP_SETTING):
		ProjectSettings.clear(_AUTOLOAD_OWNERSHIP_SETTING)
		changed = true
	if changed:
		_save_project_settings()


## 保存 ProjectSettings，并在 Godot 返回错误码时输出错误日志。
## [br]
## @api private
static func _save_project_settings() -> void:
	var save_result: Error = ProjectSettings.save()
	if save_result != OK:
		push_error("[GFPluginAutoload][plugin_autoload.settings_save_failed] ProjectSettings.save() failed: %s." % error_string(save_result))
