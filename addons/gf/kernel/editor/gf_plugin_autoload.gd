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
const _AUTOLOAD_OWNERSHIP_SETTING: String = "gf/internal/autoload_gf_owned"
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
		push_warning("[GFPlugin] 已存在名为 Gf 的 AutoLoad，且目标不是 GF Framework；插件不会覆盖该设置。")


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


# --- 私有/辅助方法 ---

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


static func _has_autoload_ownership_marker() -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(ProjectSettings.get_setting(_AUTOLOAD_OWNERSHIP_SETTING, false))


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


static func _save_project_settings() -> void:
	var save_result: Error = ProjectSettings.save()
	if save_result != OK:
		push_error("[GFPluginAutoload] ProjectSettings.save() 失败：%s" % error_string(save_result))
