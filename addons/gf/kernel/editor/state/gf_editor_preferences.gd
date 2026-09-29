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
## [br]
## @param key: gf_workspace 项目元数据分区中的键。
## [br]
## @param fallback: 键不存在或编辑器设置不可用时返回的默认值。
## [br]
## @return: 保存的原始偏好值或 fallback；调用方负责类型与范围校验。
## [br]
## @schema fallback: 由 key 对应的偏好约定决定的 Variant，也可以为 null。
## [br]
## @schema return: 未转换的 Variant；可能是 String、bool、PackedStringArray 等可序列化偏好值，也可能是 fallback。
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
## [br]
## @param key: gf_workspace 项目元数据分区中的键。
## [br]
## @param value: 要交给 EditorSettings 保存的偏好值，不属于共享项目配置。
## [br]
## @schema value: 由 key 对应的偏好约定决定的可序列化 Variant；本方法不做结构或范围转换。
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
## [br]
## @param mode: 启动模式：always、first_use 或 manual；其他值按 manual 处理。
## [br]
## @param has_opened: 此项目的个人偏好是否已记录一次工作区打开。
## [br]
## @return: always 或尚未打开过的 first_use 返回 true，其余返回 false。
static func should_auto_open(mode: String, has_opened: bool) -> bool:
	return mode == "always" or (mode == "first_use" and not has_opened)
