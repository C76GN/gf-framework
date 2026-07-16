## GFExtensionSettings: GF 扩展启用状态与 ProjectSettings 桥接。
##
## 负责读取启用扩展 ID、解析扩展依赖、收集启用扩展 Installer，以及提供导出排除开关。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
## [br]
## @layer kernel/extension
class_name GFExtensionSettings
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_PROJECT_SETTINGS_TOOLS = preload("res://addons/gf/kernel/core/gf_project_settings_tools.gd")
const _GF_EXTENSION_PRESET_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_preset.gd")

## 扩展 manifest 无状态读取器脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
const GFExtensionCatalogBase = preload("res://addons/gf/kernel/extension/gf_extension_catalog.gd")

## 扩展 manifest 发现快照服务脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
const GFExtensionManifestDiscoveryBase = preload("res://addons/gf/kernel/extension/gf_extension_manifest_discovery.gd")

## 扩展 preset 发现快照服务脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
const GFExtensionPresetDiscoveryBase = preload("res://addons/gf/kernel/extension/gf_extension_preset_discovery.gd")

## 扩展启用选择发现快照服务脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
const GFExtensionSelectionDiscoveryBase = preload("res://addons/gf/kernel/extension/gf_extension_selection_discovery.gd")

## 项目设置：启用的 GF 扩展 ID 列表。
## [br]
## @api public
const ENABLED_EXTENSIONS_SETTING: String = "gf/extensions/enabled"

## 项目设置：扩展启用选择模式。
## [br]
## @api public
## [br]
## @since 8.0.0
const EXTENSION_SELECTION_MODE_SETTING: String = "gf/extensions/selection_mode"

## 项目设置：是否自动执行启用扩展 manifest 中声明的 installer_paths。
## [br]
## @api public
const AUTO_INSTALL_ENABLED_INSTALLERS_SETTING: String = "gf/extensions/auto_install_enabled_installers"

## 项目设置：额外扩展集合根目录列表。每个根目录下一层为独立扩展目录。
## [br]
## @api public
## [br]
## @since 4.4.0
const EXTERNAL_EXTENSION_ROOTS_SETTING: String = "gf/extensions/external_roots"

## 项目设置：扩展 preset JSON 文件路径列表。
## [br]
## @api public
## [br]
## @since 5.0.0
const EXTENSION_PRESET_PATHS_SETTING: String = "gf/extensions/preset_paths"

## 项目设置：导出时是否跳过禁用扩展目录。
## [br]
## @api public
const EXPORT_EXCLUDE_DISABLED_SETTING: String = "gf/extensions/export_exclude_disabled"

## 项目设置：导出审计发现项目仍引用禁用扩展时是否报告为错误。
## [br]
## @api public
const EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING: String = "gf/extensions/export_fail_on_disabled_references"

## 默认自动执行启用扩展 Installer。
## [br]
## @api public
const AUTO_INSTALL_ENABLED_INSTALLERS_DEFAULT: bool = true

## 默认扩展选择模式：按当前 manifest 的默认启用声明派生启用扩展。
## [br]
## @api public
## [br]
## @since 8.0.0
const SELECTION_MODE_DEFAULT: String = "default"

## 显式扩展选择模式：使用 `gf/extensions/enabled` 中保存的扩展 ID。
## [br]
## @api public
## [br]
## @since 8.0.0
const SELECTION_MODE_EXPLICIT: String = "explicit"

## 默认扩展选择模式。
## [br]
## @api public
## [br]
## @since 8.0.0
const EXTENSION_SELECTION_MODE_DEFAULT: String = SELECTION_MODE_DEFAULT

## 默认显式扩展 ID 列表为空。
## [br]
## @api public
## [br]
## @since 8.0.0
const ENABLED_EXTENSIONS_DEFAULT: Array[String] = []

## 默认不扫描额外扩展根目录。
## [br]
## @api public
## [br]
## @since 4.4.0
const EXTERNAL_EXTENSION_ROOTS_DEFAULT: Array[String] = []

## 默认不加载项目侧扩展 preset。
## [br]
## @api public
## [br]
## @since 5.0.0
const EXTENSION_PRESET_PATHS_DEFAULT: Array[String] = []

## 默认导出时排除禁用扩展。
## [br]
## @api public
const EXPORT_EXCLUDE_DISABLED_DEFAULT: bool = true

## 默认把禁用扩展引用作为导出错误，避免导出产物缺少被引用的扩展文件。
## [br]
## @api public
const EXPORT_FAIL_ON_DISABLED_REFERENCES_DEFAULT: bool = true

## 内置依赖 ID。这些不是可启停扩展 manifest，但允许被扩展声明为基础依赖。
## [br]
## @api public
const BUILT_IN_EXTENSION_IDS: Array[String] = [
	"gf.kernel",
	"gf.standard",
]


# --- 公共方法 ---

## 确保扩展相关 ProjectSettings 存在。
## [br]
## @api public
## [br]
## @return 写入了默认值时返回 true。
static func ensure_defaults() -> bool:
	var should_save: bool = false
	if _ensure_extension_selection_mode_setting():
		should_save = true
	if _ensure_default(ENABLED_EXTENSIONS_SETTING, ENABLED_EXTENSIONS_DEFAULT):
		should_save = true
	if _ensure_default(AUTO_INSTALL_ENABLED_INSTALLERS_SETTING, AUTO_INSTALL_ENABLED_INSTALLERS_DEFAULT):
		should_save = true
	if _ensure_default(EXTERNAL_EXTENSION_ROOTS_SETTING, EXTERNAL_EXTENSION_ROOTS_DEFAULT):
		should_save = true
	if _ensure_default(EXTENSION_PRESET_PATHS_SETTING, EXTENSION_PRESET_PATHS_DEFAULT):
		should_save = true
	if _ensure_default(EXPORT_EXCLUDE_DISABLED_SETTING, EXPORT_EXCLUDE_DISABLED_DEFAULT):
		should_save = true
	if _ensure_default(
		EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING,
		EXPORT_FAIL_ON_DISABLED_REFERENCES_DEFAULT
	):
		should_save = true
	return should_save


## 注册扩展相关 ProjectSettings 显示信息。
## [br]
## @api public
static func register_property_info() -> void:
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(ENABLED_EXTENSIONS_SETTING, TYPE_ARRAY, {
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d:" % TYPE_STRING,
		"basic": true,
	})
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(EXTENSION_SELECTION_MODE_SETTING, TYPE_STRING, {
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "%s,%s" % [SELECTION_MODE_DEFAULT, SELECTION_MODE_EXPLICIT],
		"basic": true,
	})
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(AUTO_INSTALL_ENABLED_INSTALLERS_SETTING, TYPE_BOOL, {
		"basic": true,
	})
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(EXTERNAL_EXTENSION_ROOTS_SETTING, TYPE_ARRAY, {
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d:" % TYPE_STRING,
		"basic": true,
	})
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(EXTENSION_PRESET_PATHS_SETTING, TYPE_ARRAY, {
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d:" % TYPE_STRING,
		"basic": true,
	})
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(EXPORT_EXCLUDE_DISABLED_SETTING, TYPE_BOOL, {
		"basic": true,
	})
	_GF_PROJECT_SETTINGS_TOOLS.register_property_info(EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING, TYPE_BOOL, {
		"basic": true,
	})


## 获取默认启用的扩展 ID。
## [br]
## @api public
## [br]
## @return 默认启用扩展 ID 列表。
static func get_default_enabled_extension_ids() -> Array[String]:
	return _get_default_enabled_extension_ids_from_manifests(get_all_manifests())


## 获取当前有效启用扩展 ID。
##
## 默认模式下返回当前可发现 manifest 的默认启用 ID；显式模式下返回 `gf/extensions/enabled` 保存的 ID。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 启用扩展 ID 列表。
static func get_enabled_extension_ids() -> Array[String]:
	return _get_effective_enabled_extension_ids(get_all_manifests())


## 获取扩展启用选择模式。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return `default` 表示按 manifest 默认值派生；`explicit` 表示读取显式启用列表。
static func get_extension_selection_mode() -> String:
	var raw_value: Variant = ProjectSettings.get_setting(
		EXTENSION_SELECTION_MODE_SETTING,
		EXTENSION_SELECTION_MODE_DEFAULT
	)
	var normalized_mode: String = _normalize_extension_selection_mode(_GF_VARIANT_ACCESS_SCRIPT.to_text(raw_value))
	if normalized_mode.is_empty():
		return EXTENSION_SELECTION_MODE_DEFAULT
	return normalized_mode


## 保存扩展启用选择模式。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param selection_mode: 选择模式，必须是 `default` 或 `explicit`。
## [br]
## @return 模式有效并已写入时返回 true。
static func set_extension_selection_mode(selection_mode: String) -> bool:
	var normalized_mode: String = _normalize_extension_selection_mode(selection_mode)
	if normalized_mode.is_empty():
		push_error("[GFExtensionSettings] 扩展选择模式无效：%s" % selection_mode)
		return false

	_set_extension_selection_mode_unchecked(normalized_mode)
	return true


## 切换到默认扩展选择模式。
##
## 该方法不会改写 `gf/extensions/enabled`，只让有效启用列表重新由当前 manifest 默认值派生。
## [br]
## @api public
## [br]
## @since 8.0.0
static func use_default_extension_selection() -> void:
	_set_extension_selection_mode_unchecked(SELECTION_MODE_DEFAULT)


## 保存显式启用扩展 ID，可选自动补齐依赖。
##
## 调用该方法会把扩展选择模式切换为 `explicit`。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param extension_ids: 要启用的扩展 ID 列表。
## [br]
## @param include_dependencies: 是否自动包含依赖扩展。
static func set_enabled_extension_ids(extension_ids: Array[String], include_dependencies: bool = true) -> void:
	var manifests: Array[GFExtensionManifest] = get_all_manifests()
	var ids: Array[String] = _filter_known_extension_ids(_sorted_unique(extension_ids), manifests)
	if include_dependencies:
		ids = resolve_extension_dependencies(ids, manifests)
	ProjectSettings.set_setting(ENABLED_EXTENSIONS_SETTING, ids)
	_set_extension_selection_mode_unchecked(SELECTION_MODE_EXPLICIT)


## 判断是否自动运行启用扩展 Installer。
## [br]
## @api public
## [br]
## @return 自动运行时返回 true。
static func should_auto_install_enabled_installers() -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(ProjectSettings.get_setting(
		AUTO_INSTALL_ENABLED_INSTALLERS_SETTING,
		AUTO_INSTALL_ENABLED_INSTALLERS_DEFAULT
	))


## 设置是否自动运行启用扩展 Installer。
## [br]
## @api public
## [br]
## @param enabled: 是否自动运行。
static func set_auto_install_enabled_installers(enabled: bool) -> void:
	ProjectSettings.set_setting(AUTO_INSTALL_ENABLED_INSTALLERS_SETTING, enabled)


## 获取项目配置的额外扩展集合根目录。
## 只返回 `res://` 根目录，保证 manifest 贡献路径仍可由 Godot 资源系统加载。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @return 扩展集合根目录列表。
static func get_external_extension_roots() -> Array[String]:
	var raw_value: Variant = ProjectSettings.get_setting(
		EXTERNAL_EXTENSION_ROOTS_SETTING,
		EXTERNAL_EXTENSION_ROOTS_DEFAULT
	)
	return _normalize_external_extension_roots(_GF_VARIANT_ACCESS_SCRIPT.to_string_array(raw_value))


## 保存项目配置的额外扩展集合根目录，并刷新 manifest 缓存。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param root_paths: 扩展集合根目录列表。
static func set_external_extension_roots(root_paths: Array[String]) -> void:
	ProjectSettings.set_setting(
		EXTERNAL_EXTENSION_ROOTS_SETTING,
		_normalize_external_extension_roots(root_paths)
	)
	clear_manifest_cache()


## 获取项目配置的扩展 preset JSON 文件路径。
## 只返回 `res://` 下的 `.json` 文件路径，避免 preset 发现越过项目资源边界。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 扩展 preset JSON 文件路径列表。
static func get_extension_preset_paths() -> Array[String]:
	var raw_value: Variant = ProjectSettings.get_setting(
		EXTENSION_PRESET_PATHS_SETTING,
		EXTENSION_PRESET_PATHS_DEFAULT
	)
	return _normalize_extension_preset_paths(_GF_VARIANT_ACCESS_SCRIPT.to_string_array(raw_value))


## 保存项目配置的扩展 preset JSON 文件路径。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param preset_paths: 扩展 preset JSON 文件路径列表。
static func set_extension_preset_paths(preset_paths: Array[String]) -> void:
	ProjectSettings.set_setting(
		EXTENSION_PRESET_PATHS_SETTING,
		_normalize_extension_preset_paths(preset_paths)
	)


## 添加一个项目扩展 preset JSON 文件路径。
## 路径必须指向能解析为有效 `GFExtensionPreset` 的 `res://` JSON 文件。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param preset_path: 扩展 preset JSON 文件路径。
## [br]
## @return 路径指向有效 preset 且被新增时返回 true；无效或已存在时返回 false。
static func add_extension_preset_path(preset_path: String) -> bool:
	var normalized_paths: Array[String] = _normalize_extension_preset_paths([preset_path])
	if normalized_paths.is_empty():
		return false

	var normalized_path: String = normalized_paths[0]
	var paths: Array[String] = get_extension_preset_paths()
	if paths.has(normalized_path):
		return false
	if not _is_valid_extension_preset_file(normalized_path):
		return false

	paths.append(normalized_path)
	set_extension_preset_paths(paths)
	return true


## 移除一个项目扩展 preset JSON 文件路径。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param preset_path: 扩展 preset JSON 文件路径。
## [br]
## @return 路径存在且已移除时返回 true；无效或不存在时返回 false。
static func remove_extension_preset_path(preset_path: String) -> bool:
	var normalized_paths: Array[String] = _normalize_extension_preset_paths([preset_path])
	if normalized_paths.is_empty():
		return false

	var normalized_path: String = normalized_paths[0]
	var paths: Array[String] = get_extension_preset_paths()
	if not paths.has(normalized_path):
		return false

	paths.erase(normalized_path)
	set_extension_preset_paths(paths)
	return true


## 判断导出时是否排除禁用扩展目录。
## [br]
## @api public
## [br]
## @return 排除禁用扩展时返回 true。
static func should_export_exclude_disabled_extensions() -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(ProjectSettings.get_setting(
		EXPORT_EXCLUDE_DISABLED_SETTING,
		EXPORT_EXCLUDE_DISABLED_DEFAULT
	))


## 设置导出时是否排除禁用扩展目录。
## [br]
## @api public
## [br]
## @param enabled: 是否排除禁用扩展。
static func set_export_exclude_disabled_extensions(enabled: bool) -> void:
	ProjectSettings.set_setting(EXPORT_EXCLUDE_DISABLED_SETTING, enabled)


## 判断导出审计发现禁用扩展引用时是否报告为错误。
## [br]
## @api public
## [br]
## @return 报告为错误时返回 true。
static func should_fail_export_on_disabled_extension_references() -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.to_bool(ProjectSettings.get_setting(
		EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING,
		EXPORT_FAIL_ON_DISABLED_REFERENCES_DEFAULT
	))


## 设置导出审计发现禁用扩展引用时是否报告为错误。
## [br]
## @api public
## [br]
## @param enabled: 是否报告为错误。
static func set_fail_export_on_disabled_extension_references(enabled: bool) -> void:
	ProjectSettings.set_setting(EXPORT_FAIL_ON_DISABLED_REFERENCES_SETTING, enabled)


## 获取所有 manifest。
## [br]
## @api public
## [br]
## @return manifest 列表。
static func get_all_manifests() -> Array[GFExtensionManifest]:
	var snapshot: Dictionary = GFExtensionManifestDiscoveryBase.get_snapshot(get_external_extension_roots())
	return _duplicate_manifest_array(_get_manifest_array_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "manifests", [])
	))


## 获取可用的扩展 preset。
## 返回 GF 内置的动态基础组合，以及项目在 `gf/extensions/preset_paths` 中声明的 preset。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 扩展 preset 列表。
static func get_extension_presets() -> Array[GFExtensionPreset]:
	var manifests: Array[GFExtensionManifest] = get_all_manifests()
	var snapshot: Dictionary = GFExtensionPresetDiscoveryBase.get_snapshot(
		manifests,
		_get_configured_extension_preset_path_values()
	)
	return _get_preset_array_from_value(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "presets", []))


## 获取扩展 preset 发现诊断。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return preset 发现报告，包含有效、无效、重复和跳过的 preset 记录。
## [br]
## @schema return: Dictionary containing ok, preset_count, valid_presets, invalid_presets, skipped_presets, duplicate_ids, issue_count, issues, and configured_paths.
static func get_extension_preset_report() -> Dictionary:
	var manifests: Array[GFExtensionManifest] = get_all_manifests()
	var snapshot: Dictionary = GFExtensionPresetDiscoveryBase.get_snapshot(
		manifests,
		_get_configured_extension_preset_path_values()
	)
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(snapshot, "report")


## 按 ID 获取扩展 preset。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param preset_id: 扩展 preset ID。
## [br]
## @return 找到时返回 preset，否则返回 null。
static func get_extension_preset_by_id(preset_id: StringName) -> GFExtensionPreset:
	if preset_id == &"":
		return null
	for preset: GFExtensionPreset in get_extension_presets():
		if preset.id == preset_id:
			return preset
	return null


## 应用扩展 preset 到显式启用列表。
## 该方法会切换到 `explicit` 选择模式；保存 project.godot 由调用方决定。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param preset_id: 扩展 preset ID。
## [br]
## @param include_dependencies: 是否自动包含 manifest 硬依赖。
## [br]
## @return 找到并写入 preset 时返回 true。
static func apply_extension_preset(
	preset_id: StringName,
	include_dependencies: bool = true
) -> bool:
	var preset: GFExtensionPreset = get_extension_preset_by_id(preset_id)
	if preset == null:
		return false

	var manifests: Array[GFExtensionManifest] = get_all_manifests()
	var unknown_ids: Array[String] = GFExtensionSelectionDiscoveryBase.get_unknown_enabled_ids(
		preset.extension_ids,
		manifests,
		{
			"builtin_extension_ids": BUILT_IN_EXTENSION_IDS,
		}
	)
	if not unknown_ids.is_empty():
		push_error("[GFExtensionSettings] apply_extension_preset 失败：preset 包含未知扩展 ID：%s" % ", ".join(unknown_ids))
		return false

	set_enabled_extension_ids(preset.extension_ids, include_dependencies)
	return true


## 清空 manifest 发现缓存。编辑器或工具在扩展目录发生变化后可主动调用。
## [br]
## @api public
static func clear_manifest_cache() -> void:
	GFExtensionManifestDiscoveryBase.clear_cache()
	GFExtensionPresetDiscoveryBase.clear_cache()
	GFExtensionSelectionDiscoveryBase.clear_cache()


## 按 ID 获取 manifest。
## [br]
## @api public
## [br]
## @param extension_id: 扩展 ID。
## [br]
## @return 找到时返回 manifest，否则返回 null。
static func get_manifest_by_id(extension_id: String) -> GFExtensionManifest:
	var normalized_id: String = extension_id.strip_edges()
	if normalized_id.is_empty():
		return null

	for manifest: GFExtensionManifest in get_all_manifests():
		if manifest.id == normalized_id:
			return manifest
	return null


## 判断扩展 manifest 是否存在。
## [br]
## @api public
## [br]
## @param extension_id: 扩展 ID。
## [br]
## @return 存在 manifest 时返回 true。
static func has_extension(extension_id: String) -> bool:
	return get_manifest_by_id(extension_id) != null


## 获取扩展内资源路径。
## [br]
## @api public
## [br]
## @param extension_id: 扩展 ID。
## [br]
## @param relative_path: 相对扩展根目录的资源路径；传入 `res://` 时必须仍位于扩展根目录下。
## [br]
## @return 扩展根目录下的资源路径；扩展不存在或路径越界时返回空字符串。
static func get_extension_resource_path(
	extension_id: String,
	relative_path: String = ""
) -> String:
	var manifest: GFExtensionManifest = get_manifest_by_id(extension_id)
	if manifest == null or manifest.root_path.is_empty():
		return ""

	var root_path: String = _GF_PATH_TOOLS.normalize_root_path(manifest.root_path)
	var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(relative_path)
	if normalized_path.is_empty():
		return root_path
	if normalized_path.contains("://") and not normalized_path.begins_with("res://"):
		return ""

	var resource_path: String = normalized_path
	if not normalized_path.begins_with("res://"):
		resource_path = _GF_PATH_TOOLS.normalize_resource_path(root_path.path_join(normalized_path.trim_prefix("/")))
	if not _GF_PATH_TOOLS.is_path_under_root(resource_path, root_path, true, false):
		return ""
	return resource_path


## 判断扩展当前是否启用。
## [br]
## @api public
## [br]
## @param extension_id: 扩展 ID。
## [br]
## @param include_dependencies: 是否把依赖补齐后的启用结果纳入判断。
## [br]
## @return 扩展存在且启用时返回 true。
static func is_extension_enabled(
	extension_id: String,
	include_dependencies: bool = true
) -> bool:
	var normalized_id: String = extension_id.strip_edges()
	if normalized_id.is_empty():
		return false

	var manifests: Array[GFExtensionManifest] = get_all_manifests()
	if not _build_manifest_map(manifests).has(normalized_id):
		return false

	var selection_snapshot: Dictionary = _get_selection_snapshot(manifests)
	var enabled_ids: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(
		selection_snapshot,
		"resolved_ids" if include_dependencies else "configured_ids"
	)
	return enabled_ids.has(normalized_id)


## 加载启用扩展内的脚本资源。
## [br]
## @api public
## [br]
## @param extension_id: 扩展 ID。
## [br]
## @param relative_path: 相对扩展根目录的脚本路径；传入 `res://` 时必须仍位于扩展根目录下。
## [br]
## @param include_dependencies: 是否把依赖补齐后的启用结果纳入判断。
## [br]
## @return 扩展存在、已启用、依赖图有效且脚本可加载时返回 Script，否则返回 null。
static func load_enabled_extension_script(
	extension_id: String,
	relative_path: String,
	include_dependencies: bool = true
) -> Script:
	var manifests: Array[GFExtensionManifest] = get_all_manifests()
	var selection_snapshot: Dictionary = _get_selection_snapshot(manifests)
	if not _selection_snapshot_allows_runtime_paths(selection_snapshot, "load_enabled_extension_script"):
		return null
	var enabled_ids: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(
		selection_snapshot,
		"resolved_ids" if include_dependencies else "configured_ids"
	)
	if not enabled_ids.has(extension_id.strip_edges()):
		return null

	var script_path: String = get_extension_resource_path(extension_id, relative_path)
	if (
		script_path.is_empty()
		or script_path.get_extension().to_lower() != "gd"
		or not ResourceLoader.exists(script_path, "Script")
	):
		return null
	var resource: Resource = load(script_path)
	if resource is Script:
		return resource
	return null


## 获取启用扩展的 manifest。
## [br]
## @api public
## [br]
## @return 启用 manifest 列表。
static func get_enabled_manifests() -> Array[GFExtensionManifest]:
	var manifests: Array[GFExtensionManifest] = get_all_manifests()
	var selection_snapshot: Dictionary = _get_selection_snapshot(manifests)
	if not _selection_snapshot_allows_runtime_paths(selection_snapshot, "get_enabled_manifests"):
		return []
	return _duplicate_manifest_array(_get_manifest_array_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(selection_snapshot, "enabled_manifests", [])
	))


## 获取禁用扩展的 manifest。
## [br]
## @api public
## [br]
## @return 禁用 manifest 列表。
static func get_disabled_manifests() -> Array[GFExtensionManifest]:
	var manifests: Array[GFExtensionManifest] = get_all_manifests()
	var selection_snapshot: Dictionary = _get_selection_snapshot(manifests)
	if not _selection_snapshot_allows_runtime_paths(selection_snapshot, "get_disabled_manifests"):
		return []
	return _duplicate_manifest_array(_get_manifest_array_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(selection_snapshot, "disabled_manifests", [])
	))


## 获取启用扩展声明的 Installer 路径。
## [br]
## @api public
## [br]
## @return Installer 路径列表。
static func get_enabled_installer_paths() -> Array[String]:
	if not should_auto_install_enabled_installers():
		return []

	return _collect_enabled_manifest_paths("installer_paths")


## 获取启用扩展声明的编辑器菜单动作路径。
## [br]
## @api public
## [br]
## @return 编辑器菜单动作脚本路径列表。
static func get_enabled_editor_action_paths() -> Array[String]:
	return _collect_enabled_editor_contribution_paths("editor_action_paths")


## 获取启用扩展声明的编辑器工作区页面路径。
## [br]
## @api public
## [br]
## @return 编辑器工作区页面脚本路径列表。
static func get_enabled_editor_dock_paths() -> Array[String]:
	return _collect_enabled_editor_contribution_paths("editor_dock_paths")


## 获取启用扩展声明的 Inspector 扩展路径。
## [br]
## @api public
## [br]
## @return EditorInspectorPlugin 脚本路径列表。
static func get_enabled_editor_inspector_paths() -> Array[String]:
	return _collect_enabled_editor_contribution_paths("editor_inspector_paths")


## 获取启用扩展声明的导入插件路径。
## [br]
## @api public
## [br]
## @return EditorImportPlugin 脚本路径列表。
static func get_enabled_import_plugin_paths() -> Array[String]:
	return _collect_enabled_editor_contribution_paths("import_plugin_paths")


## 获取启用扩展声明的导出插件路径。
## [br]
## @api public
## [br]
## @return EditorExportPlugin 脚本路径列表。
static func get_enabled_export_plugin_paths() -> Array[String]:
	return _collect_enabled_editor_contribution_paths("export_plugin_paths")


## 获取启用扩展声明的 glTF 文档扩展路径。
## [br]
## @api public
## [br]
## @return GLTFDocumentExtension 脚本路径列表。
static func get_enabled_gltf_document_extension_paths() -> Array[String]:
	return _collect_enabled_editor_contribution_paths("gltf_document_extension_paths")


## 获取启用扩展声明的访问器生成扩展路径。
## [br]
## @api public
## [br]
## @return GFAccessGenerator 扩展脚本路径列表。
static func get_enabled_access_generator_extension_paths() -> Array[String]:
	return _collect_enabled_editor_contribution_paths("access_generator_extension_paths")


## 根据 manifest 依赖关系补齐启用扩展。
## [br]
## @api public
## [br]
## @param extension_ids: 原始启用扩展 ID。
## [br]
## @param manifests: 可选 manifest 列表。
## [br]
## @return 补齐依赖后的扩展 ID。
static func resolve_extension_dependencies(
	extension_ids: Array[String],
	manifests: Array[GFExtensionManifest] = []
) -> Array[String]:
	var source_manifests: Array[GFExtensionManifest] = manifests
	if source_manifests.is_empty():
		source_manifests = get_all_manifests()
	return GFExtensionSelectionDiscoveryBase.resolve_extension_dependencies(
		extension_ids,
		source_manifests,
		{ "builtin_extension_ids": BUILT_IN_EXTENSION_IDS }
	)


## 获取 manifest 依赖图诊断。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param manifests: 可选 manifest 列表；为空时扫描所有 GF 内置扩展。
## [br]
## @param include_cached_load_errors: 是否纳入当前发现缓存中的 manifest 读取错误。
## [br]
## @schema include_cached_load_errors: bool。
## [br]
## @return 包含重复 ID、无效 manifest、缺失依赖和循环依赖的诊断字典。
## [br]
## @schema return: Dictionary containing ok, extension_count, issue_count, duplicate_ids, invalid_manifests, manifest_load_errors, missing_dependencies, and dependency_cycles; invalid manifest entries contain stage, extension_id, source_path, and errors.
static func get_manifest_graph_report(
	manifests: Array[GFExtensionManifest] = [],
	include_cached_load_errors: bool = false
) -> Dictionary:
	var source_manifests: Array[GFExtensionManifest] = manifests
	var include_load_errors: bool = include_cached_load_errors or source_manifests.is_empty()
	if source_manifests.is_empty():
		source_manifests = get_all_manifests()
	var options: Dictionary = { "builtin_extension_ids": BUILT_IN_EXTENSION_IDS }
	if include_load_errors:
		options["manifest_load_errors"] = GFExtensionManifestDiscoveryBase.get_cached_manifest_load_errors()
	return GFExtensionSelectionDiscoveryBase.make_manifest_graph_report(source_manifests, options)


## 获取启用状态诊断。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @return 诊断字典。
## [br]
## @schema return: Dictionary containing selection_mode, external_roots, configured_ids, explicit_ids, resolved_ids, unknown_enabled_ids, graph status, and extension counts.
static func get_extension_selection_report() -> Dictionary:
	var manifests: Array[GFExtensionManifest] = get_all_manifests()
	var selection_snapshot: Dictionary = _get_selection_snapshot(manifests)
	var graph_report: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(selection_snapshot, "graph_report")
	var graph_ok: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(selection_snapshot, "graph_ok", true)

	return {
		"selection_mode": get_extension_selection_mode(),
		"external_roots": get_external_extension_roots(),
		"configured_ids": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(selection_snapshot, "configured_ids"),
		"explicit_ids": _get_explicit_enabled_extension_ids(),
		"resolved_ids": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(selection_snapshot, "resolved_ids"),
		"unknown_enabled_ids": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(selection_snapshot, "unknown_enabled_ids"),
		"missing_dependencies": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(graph_report, "missing_dependencies", []),
		"dependency_cycles": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(graph_report, "dependency_cycles", []),
		"duplicate_ids": _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(graph_report, "duplicate_ids", PackedStringArray()),
		"invalid_manifests": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(graph_report, "invalid_manifests", []),
		"graph_ok": graph_ok,
		"ok": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(selection_snapshot, "ok", true),
		"enabled_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(selection_snapshot, "resolved_ids").size(),
		"extension_count": manifests.size(),
	}


# --- 框架内部方法 ---

## 用给定 manifest 列表替换发现缓存，供编辑器流程或维护测试在完成外部扫描后复用同一套选择逻辑。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param manifests: 要写入缓存的 manifest 列表。
static func set_cached_manifests(manifests: Array[GFExtensionManifest]) -> void:
	GFExtensionManifestDiscoveryBase.set_cached_manifests(manifests, {
		"external_roots": get_external_extension_roots(),
	})
	GFExtensionPresetDiscoveryBase.clear_cache()
	GFExtensionSelectionDiscoveryBase.clear_cache()


# --- 私有/辅助方法 ---

static func _ensure_default(setting_name: String, default_value: Variant) -> bool:
	return _GF_PROJECT_SETTINGS_TOOLS.ensure_setting(setting_name, default_value, {
		"register_property_info": false,
	})


static func _ensure_extension_selection_mode_setting() -> bool:
	var next_mode: String = EXTENSION_SELECTION_MODE_DEFAULT
	var should_write: bool = false
	if ProjectSettings.has_setting(EXTENSION_SELECTION_MODE_SETTING):
		var raw_mode: Variant = ProjectSettings.get_setting(
			EXTENSION_SELECTION_MODE_SETTING,
			EXTENSION_SELECTION_MODE_DEFAULT
		)
		var normalized_mode: String = _normalize_extension_selection_mode(_GF_VARIANT_ACCESS_SCRIPT.to_text(raw_mode))
		if normalized_mode.is_empty():
			should_write = true
		else:
			next_mode = normalized_mode
			should_write = _GF_VARIANT_ACCESS_SCRIPT.to_text(raw_mode) != normalized_mode
	else:
		next_mode = _infer_initial_extension_selection_mode()
		should_write = true

	if should_write:
		_set_extension_selection_mode_unchecked(next_mode)
	return should_write


static func _infer_initial_extension_selection_mode() -> String:
	if not ProjectSettings.has_setting(ENABLED_EXTENSIONS_SETTING):
		return SELECTION_MODE_DEFAULT
	if _get_explicit_enabled_extension_ids().is_empty():
		return SELECTION_MODE_DEFAULT
	return SELECTION_MODE_EXPLICIT


static func _normalize_extension_selection_mode(selection_mode: String) -> String:
	var normalized_mode: String = selection_mode.strip_edges().to_lower()
	if normalized_mode == SELECTION_MODE_DEFAULT:
		return SELECTION_MODE_DEFAULT
	if normalized_mode == SELECTION_MODE_EXPLICIT:
		return SELECTION_MODE_EXPLICIT
	return ""


static func _set_extension_selection_mode_unchecked(selection_mode: String) -> void:
	ProjectSettings.set_setting(EXTENSION_SELECTION_MODE_SETTING, selection_mode)
	GFExtensionSelectionDiscoveryBase.clear_cache()


static func _get_explicit_enabled_extension_ids() -> Array[String]:
	var raw_value: Variant = ProjectSettings.get_setting(
		ENABLED_EXTENSIONS_SETTING,
		ENABLED_EXTENSIONS_DEFAULT
	)
	return _sorted_unique(_GF_VARIANT_ACCESS_SCRIPT.to_string_array(raw_value))


static func _get_effective_enabled_extension_ids(manifests: Array[GFExtensionManifest]) -> Array[String]:
	if get_extension_selection_mode() == SELECTION_MODE_DEFAULT:
		return _get_default_enabled_extension_ids_from_manifests(manifests)
	return _get_explicit_enabled_extension_ids()


static func _sorted_unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		var id: String = value.strip_edges()
		if id.is_empty() or result.has(id):
			continue
		result.append(id)
	result.sort()
	return result


static func _normalize_external_extension_roots(root_paths: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var normalized_paths: PackedStringArray = _GF_PATH_TOOLS.normalize_root_paths(PackedStringArray(root_paths))
	for normalized_path: String in normalized_paths:
		if (
			not normalized_path.begins_with("res://")
			or normalized_path == GFExtensionCatalogBase.EXTENSIONS_PATH
		):
			continue
		result.append(normalized_path)
	return result


static func _normalize_extension_preset_paths(preset_paths: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for preset_path: String in preset_paths:
		var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(preset_path)
		if (
			normalized_path.is_empty()
			or not normalized_path.begins_with("res://")
			or normalized_path.get_extension().to_lower() != "json"
			or result.has(normalized_path)
		):
			continue
		result.append(normalized_path)
	return result


static func _get_configured_extension_preset_path_values() -> Array[String]:
	return _GF_VARIANT_ACCESS_SCRIPT.to_string_array(ProjectSettings.get_setting(
		EXTENSION_PRESET_PATHS_SETTING,
		EXTENSION_PRESET_PATHS_DEFAULT
	))


static func _is_valid_extension_preset_file(preset_path: String) -> bool:
	var preset: GFExtensionPreset = _GF_EXTENSION_PRESET_SCRIPT.from_json_file(preset_path)
	return preset != null and preset.is_valid()


static func _get_default_enabled_extension_ids_from_manifests(
	manifests: Array[GFExtensionManifest]
) -> Array[String]:
	var ids: Array[String] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest.enabled_by_default:
			ids.append(manifest.id)
	return _sorted_unique(ids)


static func _filter_known_extension_ids(
	extension_ids: Array[String],
	manifests: Array[GFExtensionManifest]
) -> Array[String]:
	var manifest_by_id: Dictionary = _build_manifest_map(manifests)
	var result: Array[String] = []
	for extension_id: String in extension_ids:
		var normalized_id: String = extension_id.strip_edges()
		if normalized_id.is_empty() or not manifest_by_id.has(normalized_id):
			continue
		result.append(normalized_id)
	return _sorted_unique(result)


static func _get_preset_array_from_value(value: Variant) -> Array[GFExtensionPreset]:
	var result: Array[GFExtensionPreset] = []
	if not (value is Array):
		return result

	var values: Array = value
	for item: Variant in values:
		if item is GFExtensionPreset:
			var preset: GFExtensionPreset = item
			result.append(preset)
	return result


static func _duplicate_manifest_array(manifests: Array[GFExtensionManifest]) -> Array[GFExtensionManifest]:
	var result: Array[GFExtensionManifest] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null:
			continue
		result.append(manifest.duplicate_manifest())
	return result


static func _get_manifest_array_from_value(value: Variant) -> Array[GFExtensionManifest]:
	var result: Array[GFExtensionManifest] = []
	if not (value is Array):
		return result

	var values: Array = value
	for item: Variant in values:
		if item is GFExtensionManifest:
			var manifest: GFExtensionManifest = item
			result.append(manifest)
	return result


static func _build_manifest_map(manifests: Array[GFExtensionManifest]) -> Dictionary:
	var result: Dictionary = {}
	for manifest: GFExtensionManifest in manifests:
		if manifest == null or manifest.id.strip_edges().is_empty() or result.has(manifest.id):
			continue
		result[manifest.id] = manifest
	return result


static func _get_manifest_from_map_or_null(
	manifest_by_id: Dictionary,
	extension_id: String
) -> GFExtensionManifest:
	var raw_manifest: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(manifest_by_id, extension_id)
	if raw_manifest is GFExtensionManifest:
		return raw_manifest
	return null


static func _collect_enabled_manifest_paths(property_name: String) -> Array[String]:
	return _get_selection_manifest_paths(property_name)


static func _collect_enabled_editor_contribution_paths(property_name: String) -> Array[String]:
	return _get_selection_paths(property_name)


static func _get_selection_snapshot(manifests: Array[GFExtensionManifest] = []) -> Dictionary:
	var source_manifests: Array[GFExtensionManifest] = manifests
	if source_manifests.is_empty():
		source_manifests = get_all_manifests()
	return GFExtensionSelectionDiscoveryBase.get_snapshot(source_manifests, _get_effective_enabled_extension_ids(source_manifests), {
		"builtin_extension_ids": BUILT_IN_EXTENSION_IDS,
		"manifest_load_errors": GFExtensionManifestDiscoveryBase.get_cached_manifest_load_errors(),
	})


static func _selection_snapshot_allows_runtime_paths(snapshot: Dictionary, context: String) -> bool:
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(snapshot, "graph_ok", true):
		return true
	var graph_report: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(snapshot, "graph_report")
	push_warning("[GFExtensionSettings] %s blocked: %s" % [context, _summarize_manifest_graph_report(graph_report)])
	return false


static func _get_selection_manifest_paths(property_name: String) -> Array[String]:
	var snapshot: Dictionary = _get_selection_snapshot()
	if not _selection_snapshot_allows_runtime_paths(snapshot, "get_enabled_manifests"):
		return []
	var manifest_paths: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(snapshot, "manifest_paths")
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(manifest_paths, property_name)


static func _get_selection_paths(property_name: String) -> Array[String]:
	var snapshot: Dictionary = _get_selection_snapshot()
	if not _selection_snapshot_allows_runtime_paths(snapshot, "get_enabled_manifests"):
		return []
	var paths: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(snapshot, "paths")
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(paths, property_name)


static func _summarize_manifest_graph_report(report: Dictionary) -> String:
	var parts: Array[String] = []
	var invalid_manifests: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "invalid_manifests")
	if not invalid_manifests.is_empty():
		var invalid_manifest: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(invalid_manifests[0])
		parts.append("invalid manifest %s" % _describe_manifest_issue(invalid_manifest))

	var missing_dependencies: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "missing_dependencies")
	if not missing_dependencies.is_empty():
		var missing_dependency: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(missing_dependencies[0])
		parts.append("missing dependency %s -> %s" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(missing_dependency, "extension_id", "?"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(missing_dependency, "dependency_id", "?"),
		])

	var duplicate_ids: PackedStringArray = _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(report, "duplicate_ids", PackedStringArray())
	if not duplicate_ids.is_empty():
		parts.append("duplicate id %s" % duplicate_ids[0])

	var dependency_cycles: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "dependency_cycles")
	if not dependency_cycles.is_empty():
		parts.append("dependency cycle %s" % _GF_VARIANT_ACCESS_SCRIPT.to_text(dependency_cycles[0], "?"))

	if parts.is_empty():
		return "extension manifest graph is invalid"
	return "; ".join(parts)


static func _describe_manifest_issue(issue: Dictionary) -> String:
	var extension_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "extension_id")
	var source_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "source_path")
	if not extension_id.is_empty() and not source_path.is_empty():
		return "%s (%s)" % [extension_id, source_path]
	if not extension_id.is_empty():
		return extension_id
	if not source_path.is_empty():
		return source_path
	return "?"
