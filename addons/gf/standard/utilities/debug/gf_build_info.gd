## GFBuildInfo: 运行时构建信息快照。
##
## 用统一 Resource 承载项目版本、GF 版本、构建号、提交号和运行平台信息，
## 便于诊断、日志、存档元数据或项目自己的版本界面复用。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.17.0
class_name GFBuildInfo
extends Resource


# --- 常量 ---

## 构建标识 ProjectSettings 键。
## [br]
## @api public
const BUILD_ID_SETTING: String = "gf/build/id"

## 提交哈希 ProjectSettings 键。
## [br]
## @api public
const COMMIT_HASH_SETTING: String = "gf/build/commit_hash"

## 分支名 ProjectSettings 键。
## [br]
## @api public
const BRANCH_SETTING: String = "gf/build/branch"

## 标签名 ProjectSettings 键。
## [br]
## @api public
const TAG_SETTING: String = "gf/build/tag"

## 提交数量 ProjectSettings 键。
## [br]
## @api public
const COMMIT_COUNT_SETTING: String = "gf/build/commit_count"

## 工作区 dirty 状态 ProjectSettings 键。
## [br]
## @api public
const IS_DIRTY_SETTING: String = "gf/build/is_dirty"

## 构建 UTC 时间 ProjectSettings 键。
## [br]
## @api public
const TIME_UTC_SETTING: String = "gf/build/time_utc"

## 项目自定义构建元数据 ProjectSettings 键。
## [br]
## @api public
const METADATA_SETTING: String = "gf/build/metadata"

## 是否在导出开始时写入构建元数据的 ProjectSettings 键。
## [br]
## @api public
## [br]
## @since 6.0.0
const EXPORT_ENABLED_SETTING: String = "gf/build/export/write_metadata"

## 导出时写入 ProjectSettings 的构建元数据字典键。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema value: Dictionary，可包含 GFBuildInfo.write_metadata_to_project_settings() 支持的构建字段。
const EXPORT_BUILD_METADATA_SETTING: String = "gf/build/export/build_metadata"

## 导出结束后是否恢复旧构建元数据的 ProjectSettings 键。
## [br]
## @api public
## [br]
## @since 6.0.0
const EXPORT_RESTORE_PREVIOUS_SETTING: String = "gf/build/export/restore_previous_settings"

## 写入或恢复后是否立即保存 ProjectSettings 的设置键。
## [br]
## @api public
## [br]
## @since 6.0.0
const EXPORT_SAVE_PROJECT_SETTINGS_SETTING: String = "gf/build/export/save_project_settings"

## 导出时附加到构建信息中的自定义元数据 ProjectSettings 键。
## [br]
## @api public
## [br]
## @since 6.0.0
const EXPORT_EXTRA_METADATA_SETTING: String = "gf/build/export/metadata"

## 项目名称 ProjectSettings 键。
## [br]
## @api public
const PROJECT_NAME_SETTING: String = "application/config/name"

## 项目版本 ProjectSettings 键。
## [br]
## @api public
const PROJECT_VERSION_SETTING: String = "application/config/version"

const _FRAMEWORK_PLUGIN_CONFIG_PATH: String = "res://addons/gf/plugin.cfg"


# --- 导出变量 ---

## 项目名称。
## [br]
## @api public
@export var project_name: String = ""

## 项目版本。
## [br]
## @api public
@export var project_version: String = ""

## GF Framework 版本。
## [br]
## @api public
@export var framework_version: String = ""

## 构建流水线或发行流程写入的构建标识。
## [br]
## @api public
@export var build_id: String = ""

## 构建对应的提交哈希。
## [br]
## @api public
@export var commit_hash: String = ""

## 构建对应的分支名。
## [br]
## @api public
@export var branch: String = ""

## 构建对应的标签名。
## [br]
## @api public
@export var tag: String = ""

## 构建对应的提交数量或流水线序号。
## [br]
## @api public
@export var commit_count: int = 0

## 构建来源工作区是否存在未提交改动。
## [br]
## @api public
@export var is_dirty: bool = false

## 构建时间，建议使用 UTC ISO 文本。
## [br]
## @api public
@export var build_time_utc: String = ""

## 当前运行的 Godot 引擎版本文本。
## [br]
## @api public
@export var engine_version: String = ""

## 当前运行平台名称。
## [br]
## @api public
@export var platform_name: String = ""

## 当前运行扩展是否为 debug build。
## [br]
## @api public
@export var is_debug_build: bool = false

## 项目自定义构建元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary，保存项目自定义构建元数据。
@export var metadata: Dictionary = {}


# --- 公共方法 ---

## 转换为 Dictionary。
## [br]
## @api public
## [br]
## @return: 构建信息字典。
## [br]
## @schema return: Dictionary，包含 project_name、project_version、framework_version、build_id、commit_hash、branch、tag、commit_count、is_dirty、build_time_utc、engine_version、platform_name、is_debug_build 和 metadata 字段。
func to_dict() -> Dictionary:
	return {
		"project_name": project_name,
		"project_version": project_version,
		"framework_version": framework_version,
		"build_id": build_id,
		"commit_hash": commit_hash,
		"branch": branch,
		"tag": tag,
		"commit_count": commit_count,
		"is_dirty": is_dirty,
		"build_time_utc": build_time_utc,
		"engine_version": engine_version,
		"platform_name": platform_name,
		"is_debug_build": is_debug_build,
		"metadata": metadata.duplicate(true),
	}


## 应用字典数据。
## [br]
## @api public
## [br]
## @param data: 构建信息字典。
## [br]
## @schema data: Dictionary，可包含 project_name、project_version、framework_version、build_id、commit_hash、branch、tag、commit_count、is_dirty、build_time_utc、engine_version、platform_name、is_debug_build 和 metadata 字段。
func apply_dict(data: Dictionary) -> void:
	project_name = GFVariantData.get_option_string(data, "project_name", project_name)
	project_version = GFVariantData.get_option_string(data, "project_version", project_version)
	framework_version = GFVariantData.get_option_string(data, "framework_version", framework_version)
	build_id = GFVariantData.get_option_string(data, "build_id", build_id)
	commit_hash = GFVariantData.get_option_string(data, "commit_hash", commit_hash)
	branch = GFVariantData.get_option_string(data, "branch", branch)
	tag = GFVariantData.get_option_string(data, "tag", tag)
	commit_count = GFVariantData.get_option_int(data, "commit_count", commit_count)
	is_dirty = GFVariantData.get_option_bool(data, "is_dirty", is_dirty)
	build_time_utc = GFVariantData.get_option_string(data, "build_time_utc", build_time_utc)
	engine_version = GFVariantData.get_option_string(data, "engine_version", engine_version)
	platform_name = GFVariantData.get_option_string(data, "platform_name", platform_name)
	is_debug_build = GFVariantData.get_option_bool(data, "is_debug_build", is_debug_build)
	if data.has("metadata") or data.has(&"metadata"):
		metadata = GFVariantData.get_option_dictionary(data, "metadata")


## 创建当前运行环境的构建信息。
## [br]
## @api public
## [br]
## @return: 构建信息快照。
static func collect() -> GFBuildInfo:
	var info: GFBuildInfo = GFBuildInfo.new()
	info.project_name = _get_project_setting_text(PROJECT_NAME_SETTING)
	info.project_version = _get_project_setting_text(PROJECT_VERSION_SETTING)
	info.framework_version = _read_framework_version()
	info.build_id = _get_project_setting_text(BUILD_ID_SETTING)
	info.commit_hash = _get_project_setting_text(COMMIT_HASH_SETTING)
	info.branch = _get_project_setting_text(BRANCH_SETTING)
	info.tag = _get_project_setting_text(TAG_SETTING)
	info.commit_count = GFVariantData.to_int(ProjectSettings.get_setting(COMMIT_COUNT_SETTING, 0))
	info.is_dirty = GFVariantData.to_bool(ProjectSettings.get_setting(IS_DIRTY_SETTING, false))
	info.build_time_utc = _get_project_setting_text(TIME_UTC_SETTING)
	info.engine_version = _format_engine_version(Engine.get_version_info())
	info.platform_name = OS.get_name()
	info.is_debug_build = OS.is_debug_build()
	var metadata_value: Variant = ProjectSettings.get_setting(METADATA_SETTING, {})
	info.metadata = GFVariantData.to_dictionary(metadata_value)
	return info


## 从 Dictionary 创建构建信息。
## [br]
## @api public
## [br]
## @param data: 构建信息字典。
## [br]
## @return: 新构建信息。
## [br]
## @schema data: Dictionary，可包含 GFBuildInfo.to_dict() 输出的字段。
static func from_dict(data: Dictionary) -> GFBuildInfo:
	var info: GFBuildInfo = GFBuildInfo.new()
	info.apply_dict(data)
	return info


## 把外部构建流水线提供的构建元数据写入 ProjectSettings，供 collect() 在运行时读取。
## [br]
## @api public
## [br]
## @since 5.2.0
## [br]
## @param build_data: 构建流水线提供的构建元数据。
## [br]
## @param extra_metadata: 项目自定义构建元数据。
## [br]
## @param save_settings: 是否立即保存 ProjectSettings。
## [br]
## @return: 实际写入的构建元数据。
## [br]
## @schema build_data: Dictionary，可包含 build_id、commit_hash、branch、tag、commit_count、is_dirty、build_time_utc 和 metadata 字段。
## [br]
## @schema extra_metadata: Dictionary，保存项目自定义构建元数据。
## [br]
## @schema return: Dictionary，包含已写入的构建元数据和可选 save_error。
static func write_metadata_to_project_settings(
	build_data: Dictionary = {},
	extra_metadata: Dictionary = {},
	save_settings: bool = false
) -> Dictionary:
	var written_data: Dictionary = {}
	_set_string_setting_from_data(written_data, build_data, "build_id", BUILD_ID_SETTING)
	_set_string_setting_from_data(written_data, build_data, "commit_hash", COMMIT_HASH_SETTING)
	_set_string_setting_from_data(written_data, build_data, "branch", BRANCH_SETTING)
	_set_string_setting_from_data(written_data, build_data, "tag", TAG_SETTING)
	_set_int_setting_from_data(written_data, build_data, "commit_count", COMMIT_COUNT_SETTING)
	_set_bool_setting_from_data(written_data, build_data, "is_dirty", IS_DIRTY_SETTING)

	var effective_build_time_utc: String = GFVariantData.get_option_string(build_data, "build_time_utc")
	if effective_build_time_utc.is_empty():
		effective_build_time_utc = Time.get_datetime_string_from_system(true, false)
	ProjectSettings.set_setting(TIME_UTC_SETTING, effective_build_time_utc)
	written_data["build_time_utc"] = effective_build_time_utc

	var metadata_value: Dictionary = GFVariantData.get_option_dictionary(build_data, "metadata").duplicate(true)
	var _merge_metadata_result: Dictionary = GFVariantData.merge_dictionary(metadata_value, extra_metadata, true, true)
	ProjectSettings.set_setting(METADATA_SETTING, metadata_value)
	written_data["metadata"] = metadata_value.duplicate(true)

	if save_settings:
		var save_result: int = ProjectSettings.save()
		written_data["save_error"] = save_result
	return written_data


## 复制构建信息。
## [br]
## @api public
## [br]
## @return: 深拷贝后的构建信息。
func duplicate_info() -> GFBuildInfo:
	return GFBuildInfo.from_dict(to_dict())


# --- 私有/辅助方法 ---

static func _get_project_setting_text(path: String) -> String:
	if not ProjectSettings.has_setting(path):
		return ""
	return GFVariantData.to_text(ProjectSettings.get_setting(path, ""))


static func _read_framework_version() -> String:
	var config: ConfigFile = ConfigFile.new()
	var error: int = config.load(_FRAMEWORK_PLUGIN_CONFIG_PATH)
	if error != OK:
		return ""
	return GFVariantData.to_text(config.get_value("plugin", "version", ""))


static func _format_engine_version(version_info: Dictionary) -> String:
	var version_text: String = GFVariantData.get_option_string(version_info, "string")
	if not version_text.is_empty():
		return version_text

	var major: String = GFVariantData.get_option_string(version_info, "major")
	var minor: String = GFVariantData.get_option_string(version_info, "minor")
	var patch: String = GFVariantData.get_option_string(version_info, "patch")
	var status: String = GFVariantData.get_option_string(version_info, "status")
	var result: String = ".".join(PackedStringArray([major, minor, patch]))
	if not status.is_empty():
		result += ".%s" % status
	return result


static func _set_string_setting_from_data(
	written_data: Dictionary,
	source: Dictionary,
	key: String,
	setting_path: String
) -> void:
	if not source.has(key):
		return

	var setting_value: String = GFVariantData.get_option_string(source, key)
	ProjectSettings.set_setting(setting_path, setting_value)
	written_data[key] = setting_value


static func _set_int_setting_from_data(
	written_data: Dictionary,
	source: Dictionary,
	key: String,
	setting_path: String
) -> void:
	if not source.has(key):
		return

	var setting_value: int = GFVariantData.get_option_int(source, key)
	ProjectSettings.set_setting(setting_path, setting_value)
	written_data[key] = setting_value


static func _set_bool_setting_from_data(
	written_data: Dictionary,
	source: Dictionary,
	key: String,
	setting_path: String
) -> void:
	if not source.has(key):
		return

	var setting_value: bool = GFVariantData.get_option_bool(source, key)
	ProjectSettings.set_setting(setting_path, setting_value)
	written_data[key] = setting_value
