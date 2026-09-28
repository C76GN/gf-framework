@tool

# 仅保存当前项目的个人编辑器偏好，不修改项目配置或运行时用户数据。
extends RefCounted


# --- 常量 ---

## EditorSettings 项目元数据分区。
## [br]
## @api private
const _SECTION: String = "gf_workspace"


# --- 框架内部方法 ---

## 读取个人偏好；非编辑器环境或设置服务不可用时返回默认值。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
static func get_value(key: String, fallback: Variant = null) -> Variant:
	if not Engine.is_editor_hint():
		return fallback
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		return fallback
	return settings.get_project_metadata(_SECTION, key, fallback)


## 保存个人偏好；非编辑器环境不写入任何文件。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
static func set_value(key: String, value: Variant) -> void:
	if not Engine.is_editor_hint():
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings != null:
		settings.set_project_metadata(_SECTION, key, value)


## 根据启动模式和首次使用状态决定是否展示工作区；未知模式按手动打开处理。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
static func should_auto_open(mode: String, has_opened: bool) -> bool:
	return mode == "always" or (mode == "first_use" and not has_opened)
