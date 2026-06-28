@tool

## GFBuildInfoExportPlugin: 导出时写入构建元数据的可选编辑器插件。
##
## 只负责把外部构建流水线已提供的构建字段写入 ProjectSettings，项目仍可决定是否保存、
## 是否恢复旧值以及如何展示这些字段。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
class_name GFBuildInfoExportPlugin
extends EditorExportPlugin


# --- 常量 ---

## 是否在导出开始时写入构建元数据的 ProjectSettings 键。
## [br]
## @api public
## [br]
## @since 3.17.0
const ENABLED_SETTING: String = GFBuildInfo.EXPORT_ENABLED_SETTING

## 导出时写入 ProjectSettings 的构建元数据字典键。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @schema value: Dictionary，可包含 GFBuildInfo.write_metadata_to_project_settings() 支持的构建字段。
const BUILD_METADATA_SETTING: String = GFBuildInfo.EXPORT_BUILD_METADATA_SETTING

## 导出结束后是否恢复旧构建元数据的 ProjectSettings 键。
## [br]
## @api public
## [br]
## @since 6.0.0
const RESTORE_PREVIOUS_SETTING: String = GFBuildInfo.EXPORT_RESTORE_PREVIOUS_SETTING

## 写入或恢复后是否立即保存 ProjectSettings 的设置键。
## [br]
## @api public
## [br]
## @since 6.0.0
const SAVE_PROJECT_SETTINGS_SETTING: String = GFBuildInfo.EXPORT_SAVE_PROJECT_SETTINGS_SETTING

## 导出时附加到构建信息中的自定义元数据 ProjectSettings 键。
## [br]
## @api public
## [br]
## @since 6.0.0
const EXTRA_METADATA_SETTING: String = GFBuildInfo.EXPORT_EXTRA_METADATA_SETTING

const _BUILD_SETTING_PATHS: Array[String] = [
	GFBuildInfo.BUILD_ID_SETTING,
	GFBuildInfo.COMMIT_HASH_SETTING,
	GFBuildInfo.BRANCH_SETTING,
	GFBuildInfo.TAG_SETTING,
	GFBuildInfo.COMMIT_COUNT_SETTING,
	GFBuildInfo.IS_DIRTY_SETTING,
	GFBuildInfo.TIME_UTC_SETTING,
	GFBuildInfo.METADATA_SETTING,
]


# --- 私有变量 ---

var _previous_settings: Dictionary = {}
var _export_wrote_metadata: bool = false


# --- Godot 生命周期方法 ---

func _get_name() -> String:
	return "GFBuildInfoExportPlugin"


func _export_begin(
	_features: PackedStringArray,
	_is_debug: bool,
	_path: String,
	_flags: int
) -> void:
	if not GFVariantData.to_bool(ProjectSettings.get_setting(ENABLED_SETTING, false)):
		return

	_previous_settings = _write_export_metadata_from_project_settings()
	_export_wrote_metadata = true


func _export_end() -> void:
	if not _export_wrote_metadata:
		return

	if GFVariantData.to_bool(ProjectSettings.get_setting(RESTORE_PREVIOUS_SETTING, true)):
		_restore_export_metadata(_previous_settings)
		if GFVariantData.to_bool(ProjectSettings.get_setting(SAVE_PROJECT_SETTINGS_SETTING, false)):
			var _save_result_89: Variant = ProjectSettings.save()

	_previous_settings.clear()
	_export_wrote_metadata = false


# --- 私有/辅助方法 ---

static func _write_export_metadata_from_project_settings() -> Dictionary:
	var previous_settings: Dictionary = _capture_build_settings()
	var build_data: Dictionary = GFVariantData.to_dictionary(ProjectSettings.get_setting(BUILD_METADATA_SETTING, {}))
	var extra_metadata: Dictionary = GFVariantData.to_dictionary(ProjectSettings.get_setting(EXTRA_METADATA_SETTING, {}))
	var _write_metadata_to_project_settings_result: Dictionary = GFBuildInfo.write_metadata_to_project_settings(
		build_data.duplicate(true),
		extra_metadata.duplicate(true),
		GFVariantData.to_bool(ProjectSettings.get_setting(SAVE_PROJECT_SETTINGS_SETTING, false))
	)
	return previous_settings


static func _restore_export_metadata(previous_settings: Dictionary) -> void:
	for setting_path: String in _BUILD_SETTING_PATHS:
		var entry: Dictionary = GFVariantData.as_dictionary(GFVariantData.get_option_value(previous_settings, setting_path, {}))
		if GFVariantData.get_option_bool(entry, "had_setting", false):
			ProjectSettings.set_setting(setting_path, GFVariantData.get_option_value(entry, "value"))
		else:
			_clear_project_setting_if_exists(setting_path)


static func _capture_build_settings() -> Dictionary:
	var previous_settings: Dictionary = {}
	for setting_path: String in _BUILD_SETTING_PATHS:
		var entry: Dictionary = {
			"had_setting": ProjectSettings.has_setting(setting_path),
		}
		if ProjectSettings.has_setting(setting_path):
			entry["value"] = ProjectSettings.get_setting(setting_path)
		previous_settings[setting_path] = entry
	return previous_settings


static func _clear_project_setting_if_exists(setting_path: String) -> void:
	if ProjectSettings.has_setting(setting_path):
		ProjectSettings.clear(setting_path)
