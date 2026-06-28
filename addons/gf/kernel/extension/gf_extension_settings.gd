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
const _GF_DEPENDENCY_GRAPH_TOOLS = preload("res://addons/gf/kernel/core/gf_dependency_graph_tools.gd")
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_PROJECT_SETTINGS_TOOLS = preload("res://addons/gf/kernel/core/gf_project_settings_tools.gd")
const _GF_EXTENSION_PRESET_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_preset.gd")

## 扩展 manifest 发现服务脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
const GFExtensionCatalogBase = preload("res://addons/gf/kernel/extension/gf_extension_catalog.gd")

## 项目设置：启用的 GF 扩展 ID 列表。
## [br]
## @api public
const ENABLED_EXTENSIONS_SETTING: String = "gf/extensions/enabled"

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


# --- 私有变量 ---

static var _all_manifests_cache: Array[GFExtensionManifest] = []
static var _manifest_load_errors_cache: Array[Dictionary] = []
static var _manifest_cache_external_roots: Array[String] = []
static var _has_all_manifests_cache: bool = false
static var _has_manual_manifest_cache: bool = false


# --- 公共方法 ---

## 确保扩展相关 ProjectSettings 存在。
## [br]
## @api public
## [br]
## @return 写入了默认值时返回 true。
static func ensure_defaults() -> bool:
	var should_save: bool = false
	if _ensure_default(ENABLED_EXTENSIONS_SETTING, get_default_enabled_extension_ids()):
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


## 获取用户配置的启用扩展 ID。
## [br]
## @api public
## [br]
## @return 启用扩展 ID 列表。
static func get_enabled_extension_ids() -> Array[String]:
	var raw_value: Variant = ProjectSettings.get_setting(
		ENABLED_EXTENSIONS_SETTING,
		get_default_enabled_extension_ids()
	)
	return _sorted_unique(_GF_VARIANT_ACCESS_SCRIPT.to_string_array(raw_value))


## 保存启用扩展 ID，可选自动补齐依赖。
## [br]
## @api public
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
	var external_roots: Array[String] = get_external_extension_roots()
	if (
		not _has_all_manifests_cache
		or (not _has_manual_manifest_cache and _manifest_cache_external_roots != external_roots)
	):
		_all_manifests_cache = GFExtensionCatalogBase.load_all_manifests(external_roots)
		_manifest_load_errors_cache = GFExtensionCatalogBase.get_last_manifest_load_errors()
		_manifest_cache_external_roots = external_roots.duplicate()
		_has_all_manifests_cache = true
		_has_manual_manifest_cache = false
	return _all_manifests_cache.duplicate()


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
	var collection: Dictionary = _collect_extension_presets_with_report(manifests)
	return _get_preset_array_from_value(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(collection, "presets", []))


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
	var collection: Dictionary = _collect_extension_presets_with_report(manifests)
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(collection, "report")


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


## 应用扩展 preset 到 `gf/extensions/enabled`。
## 该方法只写入启用扩展 ID；保存 project.godot 由调用方决定。
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

	set_enabled_extension_ids(preset.extension_ids, include_dependencies)
	return true


## 清空 manifest 发现缓存。编辑器或工具在扩展目录发生变化后可主动调用。
## [br]
## @api public
static func clear_manifest_cache() -> void:
	_all_manifests_cache.clear()
	_manifest_load_errors_cache.clear()
	_manifest_cache_external_roots.clear()
	_has_all_manifests_cache = false
	_has_manual_manifest_cache = false


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

	var enabled_ids: Array[String] = get_enabled_extension_ids()
	if include_dependencies:
		enabled_ids = resolve_extension_dependencies(enabled_ids, manifests)
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
	if not _manifest_graph_allows_runtime_paths(manifests, "load_enabled_extension_script"):
		return null
	if not is_extension_enabled(extension_id, include_dependencies):
		return null

	var script_path: String = get_extension_resource_path(extension_id, relative_path)
	if script_path.is_empty() or not ResourceLoader.exists(script_path):
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
	if not _manifest_graph_allows_runtime_paths(manifests, "get_enabled_manifests"):
		return []
	var enabled_ids: Array[String] = resolve_extension_dependencies(get_enabled_extension_ids(), manifests)
	var manifest_by_id: Dictionary = _build_manifest_map(manifests)
	var result: Array[GFExtensionManifest] = []
	for extension_id: String in enabled_ids:
		var manifest: GFExtensionManifest = _get_manifest_from_map_or_null(manifest_by_id, extension_id)
		if manifest != null:
			result.append(manifest)
	return result


## 获取禁用扩展的 manifest。
## [br]
## @api public
## [br]
## @return 禁用 manifest 列表。
static func get_disabled_manifests() -> Array[GFExtensionManifest]:
	var manifests: Array[GFExtensionManifest] = get_all_manifests()
	if not _manifest_graph_allows_runtime_paths(manifests, "get_disabled_manifests"):
		return []
	var enabled_ids: Array[String] = resolve_extension_dependencies(get_enabled_extension_ids(), manifests)
	var result: Array[GFExtensionManifest] = []
	for manifest: GFExtensionManifest in manifests:
		if not enabled_ids.has(manifest.id):
			result.append(manifest)
	return result


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
	return _collect_enabled_manifest_paths("editor_action_paths")


## 获取启用扩展声明的编辑器工作区页面路径。
## [br]
## @api public
## [br]
## @return 编辑器工作区页面脚本路径列表。
static func get_enabled_editor_dock_paths() -> Array[String]:
	return _collect_enabled_manifest_paths("editor_dock_paths")


## 获取启用扩展声明的 Inspector 扩展路径。
## [br]
## @api public
## [br]
## @return EditorInspectorPlugin 脚本路径列表。
static func get_enabled_editor_inspector_paths() -> Array[String]:
	return _collect_enabled_manifest_paths("editor_inspector_paths")


## 获取启用扩展声明的导入插件路径。
## [br]
## @api public
## [br]
## @return EditorImportPlugin 脚本路径列表。
static func get_enabled_import_plugin_paths() -> Array[String]:
	return _collect_enabled_manifest_paths("import_plugin_paths")


## 获取启用扩展声明的导出插件路径。
## [br]
## @api public
## [br]
## @return EditorExportPlugin 脚本路径列表。
static func get_enabled_export_plugin_paths() -> Array[String]:
	return _collect_enabled_manifest_paths("export_plugin_paths")


## 获取启用扩展声明的 glTF 文档扩展路径。
## [br]
## @api public
## [br]
## @return GLTFDocumentExtension 脚本路径列表。
static func get_enabled_gltf_document_extension_paths() -> Array[String]:
	return _collect_enabled_manifest_paths("gltf_document_extension_paths")


## 获取启用扩展声明的访问器生成扩展路径。
## [br]
## @api public
## [br]
## @return GFAccessGenerator 扩展脚本路径列表。
static func get_enabled_access_generator_extension_paths() -> Array[String]:
	return _collect_enabled_manifest_paths("access_generator_extension_paths")


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

	var manifest_by_id: Dictionary = _build_manifest_map(source_manifests)
	var requested_ids: Array[String] = _sorted_unique(extension_ids)
	var graph_report: Dictionary = _GF_DEPENDENCY_GRAPH_TOOLS.sort_dependency_first(
		_array_to_packed_string_array(requested_ids),
		_build_dependency_map(manifest_by_id)
	)
	var resolved_order: PackedStringArray = _get_graph_ordered_ids(graph_report)
	var cycles: Array[PackedStringArray] = _get_graph_cycles(graph_report)
	for cycle: PackedStringArray in cycles:
		push_warning("[GFExtensionSettings] 检测到扩展依赖循环：%s" % " -> ".join(Array(cycle)))

	var ordered: Array[String] = []
	if cycles.is_empty():
		for resolved_id: String in resolved_order:
			ordered.append(resolved_id)
		return ordered

	var resolved: Dictionary = _make_lookup_from_packed_string_array(resolved_order)
	for manifest: GFExtensionManifest in source_manifests:
		if resolved.has(manifest.id):
			ordered.append(manifest.id)
	return ordered


## 获取 manifest 依赖图诊断。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param manifests: 可选 manifest 列表；为空时扫描所有 GF 内置扩展。
## [br]
## @return 包含重复 ID、无效 manifest、缺失依赖和循环依赖的诊断字典。
## [br]
## @schema return: Dictionary containing ok, extension_count, issue_count, duplicate_ids, invalid_manifests, manifest_load_errors, missing_dependencies, and dependency_cycles.
static func get_manifest_graph_report(manifests: Array[GFExtensionManifest] = []) -> Dictionary:
	var source_manifests: Array[GFExtensionManifest] = manifests
	var include_load_errors: bool = source_manifests.is_empty()
	if source_manifests.is_empty():
		source_manifests = get_all_manifests()

	var manifest_by_id: Dictionary = {}
	var seen_ids: Dictionary = {}
	var duplicate_ids: PackedStringArray = PackedStringArray()
	var invalid_manifests: Array[Dictionary] = []
	var manifest_load_errors: Array[Dictionary] = _get_manifest_load_errors_for_report(include_load_errors)
	var missing_dependencies: Array[Dictionary] = []
	var dependency_cycles: Array[PackedStringArray] = []
	for load_error: Dictionary in manifest_load_errors:
		invalid_manifests.append(_manifest_load_error_to_invalid_manifest(load_error))

	for manifest: GFExtensionManifest in source_manifests:
		if manifest == null:
			continue

		var errors: Array[String] = manifest.get_validation_errors()
		if not errors.is_empty():
			invalid_manifests.append({
				"extension_id": manifest.id,
				"source_path": manifest.source_path,
				"errors": errors,
			})

		if manifest.id.strip_edges().is_empty():
			continue
		if seen_ids.has(manifest.id):
			if not duplicate_ids.has(manifest.id):
				var _append_result_549: Variant = duplicate_ids.append(manifest.id)
			continue

		seen_ids[manifest.id] = true
		manifest_by_id[manifest.id] = manifest

	for manifest: GFExtensionManifest in source_manifests:
		if manifest == null:
			continue
		for dependency_id: String in manifest.dependencies:
			if not GFExtensionManifest.is_valid_extension_id(dependency_id):
				continue
			if _is_builtin_extension_id(dependency_id):
				continue
			if not manifest_by_id.has(dependency_id):
				missing_dependencies.append({
					"extension_id": manifest.id,
					"dependency_id": dependency_id,
				})

	var graph_report: Dictionary = _GF_DEPENDENCY_GRAPH_TOOLS.sort_dependency_first(
		_dictionary_keys_to_packed_string_array(manifest_by_id),
		_build_dependency_map(manifest_by_id)
	)
	dependency_cycles = _get_graph_cycles(graph_report)

	var issue_count: int = (
		duplicate_ids.size()
		+ invalid_manifests.size()
		+ missing_dependencies.size()
		+ dependency_cycles.size()
	)
	return {
		"ok": issue_count == 0,
		"extension_count": manifest_by_id.size(),
		"issue_count": issue_count,
		"duplicate_ids": duplicate_ids,
		"invalid_manifests": invalid_manifests,
		"manifest_load_errors": manifest_load_errors,
		"missing_dependencies": missing_dependencies,
		"dependency_cycles": dependency_cycles,
	}


## 获取启用状态诊断。
## [br]
## @api public
## [br]
## @return 诊断字典。
## [br]
## @schema return: Dictionary containing external_roots, configured_ids, resolved_ids, unknown_enabled_ids, graph status, and extension counts.
static func get_extension_selection_report() -> Dictionary:
	var manifests: Array[GFExtensionManifest] = get_all_manifests()
	var configured_ids: Array[String] = get_enabled_extension_ids()
	var resolved_ids: Array[String] = resolve_extension_dependencies(configured_ids, manifests)
	var graph_report: Dictionary = get_manifest_graph_report(manifests)
	var unknown_enabled_ids: Array[String] = _get_unknown_enabled_ids(configured_ids, _build_manifest_map(manifests))
	var graph_ok: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(graph_report, "ok", true)

	return {
		"external_roots": get_external_extension_roots(),
		"configured_ids": configured_ids,
		"resolved_ids": resolved_ids,
		"unknown_enabled_ids": unknown_enabled_ids,
		"missing_dependencies": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(graph_report, "missing_dependencies", []),
		"dependency_cycles": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(graph_report, "dependency_cycles", []),
		"duplicate_ids": _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(graph_report, "duplicate_ids", PackedStringArray()),
		"invalid_manifests": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(graph_report, "invalid_manifests", []),
		"graph_ok": graph_ok,
		"ok": graph_ok and unknown_enabled_ids.is_empty(),
		"enabled_count": resolved_ids.size(),
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
	_all_manifests_cache.clear()
	_all_manifests_cache.append_array(manifests)
	_manifest_load_errors_cache.clear()
	_manifest_cache_external_roots = get_external_extension_roots()
	_has_all_manifests_cache = true
	_has_manual_manifest_cache = true


# --- 私有/辅助方法 ---

static func _ensure_default(setting_name: String, default_value: Variant) -> bool:
	return _GF_PROJECT_SETTINGS_TOOLS.ensure_setting(setting_name, default_value, {
		"register_property_info": false,
	})


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


static func _get_all_extension_ids_from_manifests(manifests: Array[GFExtensionManifest]) -> Array[String]:
	var ids: Array[String] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null or manifest.id.strip_edges().is_empty():
			continue
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


static func _get_builtin_extension_presets(
	manifests: Array[GFExtensionManifest]
) -> Array[GFExtensionPreset]:
	var presets: Array[GFExtensionPreset] = []
	presets.append(_make_extension_preset({
		"id": "gf.default",
		"display_name": "默认选择",
		"description": "恢复 GF 当前默认扩展选择。",
		"extension_ids": _get_default_enabled_extension_ids_from_manifests(manifests),
		"tags": ["builtin"],
	}))
	presets.append(_make_extension_preset({
		"id": "gf.none",
		"display_name": "全部关闭",
		"description": "关闭所有可选 GF 扩展，只保留 kernel 与 standard 基础能力。",
		"extension_ids": [],
		"tags": ["builtin"],
	}))
	presets.append(_make_extension_preset({
		"id": "gf.all",
		"display_name": "全部扩展",
		"description": "启用当前可发现的全部 GF 扩展，适合本地评估而非默认发行策略。",
		"extension_ids": _get_all_extension_ids_from_manifests(manifests),
		"tags": ["builtin"],
	}))
	return presets


static func _collect_extension_presets_with_report(
	manifests: Array[GFExtensionManifest]
) -> Dictionary:
	var presets: Array[GFExtensionPreset] = _get_builtin_extension_presets(manifests)
	var seen_ids: Dictionary = _build_preset_id_lookup(presets)
	var valid_presets: Array[Dictionary] = []
	var invalid_presets: Array[Dictionary] = []
	var skipped_presets: Array[Dictionary] = []
	var duplicate_ids: PackedStringArray = PackedStringArray()
	var issues: PackedStringArray = PackedStringArray()
	for builtin_preset: GFExtensionPreset in presets:
		valid_presets.append(_preset_to_report_record(builtin_preset, "builtin"))

	var configured_paths: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.to_string_array(ProjectSettings.get_setting(
		EXTENSION_PRESET_PATHS_SETTING,
		EXTENSION_PRESET_PATHS_DEFAULT
	))
	var seen_paths: Dictionary = {}
	for raw_path: String in configured_paths:
		var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(raw_path)
		if not _extension_preset_path_is_supported(normalized_path):
			var path_errors: Array[String] = ["preset path must be a res:// JSON file"]
			invalid_presets.append(_make_preset_issue_record(raw_path, &"", path_errors))
			var _append_path_issue: bool = issues.append("%s: %s" % [raw_path, path_errors[0]])
			continue
		if seen_paths.has(normalized_path):
			skipped_presets.append(_make_preset_skip_record(normalized_path, &"", "duplicate_path"))
			continue

		seen_paths[normalized_path] = true
		var preset: GFExtensionPreset = _GF_EXTENSION_PRESET_SCRIPT.from_json_file(normalized_path)
		if preset == null:
			var read_errors: Array[String] = ["could not read preset JSON"]
			invalid_presets.append(_make_preset_issue_record(normalized_path, &"", read_errors))
			var _append_read_issue: bool = issues.append("%s: %s" % [normalized_path, read_errors[0]])
			continue

		var validation_errors: Array[String] = preset.get_validation_errors()
		if not validation_errors.is_empty():
			invalid_presets.append(_make_preset_issue_record(normalized_path, preset.id, validation_errors))
			var _append_validation_issue: bool = issues.append("%s: %s" % [normalized_path, validation_errors[0]])
			continue
		if seen_ids.has(preset.id):
			if not duplicate_ids.has(String(preset.id)):
				var _append_duplicate_id: bool = duplicate_ids.append(String(preset.id))
			skipped_presets.append(_make_preset_skip_record(normalized_path, preset.id, "duplicate_id"))
			var _append_duplicate_issue: bool = issues.append("%s: duplicate preset id %s" % [
				normalized_path,
				String(preset.id),
			])
			continue

		presets.append(preset)
		seen_ids[preset.id] = true
		valid_presets.append(_preset_to_report_record(preset, "project"))

	var issue_count: int = invalid_presets.size() + skipped_presets.size()
	return {
		"presets": presets,
		"report": {
			"ok": issue_count == 0,
			"preset_count": valid_presets.size(),
			"valid_presets": valid_presets,
			"invalid_presets": invalid_presets,
			"skipped_presets": skipped_presets,
			"duplicate_ids": duplicate_ids,
			"issue_count": issue_count,
			"issues": issues,
			"configured_paths": _normalize_extension_preset_paths(configured_paths),
		},
	}


static func _make_extension_preset(data: Dictionary) -> GFExtensionPreset:
	return _GF_EXTENSION_PRESET_SCRIPT.from_dictionary(data)


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


static func _build_preset_id_lookup(presets: Array[GFExtensionPreset]) -> Dictionary:
	var result: Dictionary = {}
	for preset: GFExtensionPreset in presets:
		if preset != null and preset.id != &"":
			result[preset.id] = true
	return result


static func _extension_preset_path_is_supported(path: String) -> bool:
	return path.begins_with("res://") and path.get_extension().to_lower() == "json"


static func _preset_to_report_record(preset: GFExtensionPreset, source_kind: String) -> Dictionary:
	if preset == null:
		return {}
	return {
		"id": String(preset.id),
		"display_name": preset.display_name,
		"source_path": preset.source_path,
		"source_kind": source_kind,
		"extension_ids": preset.extension_ids.duplicate(),
		"tags": preset.tags.duplicate(),
	}


static func _make_preset_issue_record(
	source_path: String,
	preset_id: StringName,
	errors: Array[String]
) -> Dictionary:
	return {
		"id": String(preset_id),
		"source_path": source_path,
		"errors": errors.duplicate(),
	}


static func _make_preset_skip_record(
	source_path: String,
	preset_id: StringName,
	reason: String
) -> Dictionary:
	return {
		"id": String(preset_id),
		"source_path": source_path,
		"reason": reason,
	}


static func _build_dependency_map(manifest_by_id: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for extension_id_variant: Variant in manifest_by_id.keys():
		var extension_id: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(extension_id_variant).strip_edges()
		if extension_id.is_empty():
			continue
		var manifest: GFExtensionManifest = _get_manifest_from_map_or_null(manifest_by_id, extension_id)
		if manifest == null:
			continue
		var dependencies: PackedStringArray = PackedStringArray()
		for dependency_id: String in manifest.dependencies:
			var normalized_dependency_id: String = dependency_id.strip_edges()
			if (
				normalized_dependency_id.is_empty()
				or not GFExtensionManifest.is_valid_extension_id(normalized_dependency_id)
				or _is_builtin_extension_id(normalized_dependency_id)
				or not manifest_by_id.has(normalized_dependency_id)
			):
				continue
			var _dependency_appended: bool = dependencies.append(normalized_dependency_id)
		result[extension_id] = dependencies
	return result


static func _array_to_packed_string_array(values: Array[String]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: String in values:
		var normalized_value: String = value.strip_edges()
		if normalized_value.is_empty() or result.has(normalized_value):
			continue
		var _appended: bool = result.append(normalized_value)
	return result


static func _dictionary_keys_to_packed_string_array(values: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in values.keys():
		var normalized_key: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(key).strip_edges()
		if normalized_key.is_empty() or result.has(normalized_key):
			continue
		var _appended: bool = result.append(normalized_key)
	return result


static func _make_lookup_from_packed_string_array(values: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for value: String in values:
		result[value] = true
	return result


static func _get_graph_ordered_ids(report: Dictionary) -> PackedStringArray:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(report, "ordered_ids", PackedStringArray())


static func _get_graph_cycles(report: Dictionary) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var cycles: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "dependency_cycles", [])
	for cycle_variant: Variant in cycles:
		if cycle_variant is PackedStringArray:
			var packed_cycle: PackedStringArray = cycle_variant
			result.append(packed_cycle.duplicate())
		elif cycle_variant is Array:
			var cycle_items: Array = cycle_variant
			result.append(_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array({ "cycle": cycle_items }, "cycle", PackedStringArray()))
	return result


static func _get_manifest_load_errors_for_report(include_load_errors: bool) -> Array[Dictionary]:
	if not include_load_errors:
		return []
	return _manifest_load_errors_cache.duplicate(true)


static func _manifest_load_error_to_invalid_manifest(load_error: Dictionary) -> Dictionary:
	return {
		"extension_id": "",
		"source_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(load_error, "source_path"),
		"errors": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(load_error, "errors"),
	}


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
	var paths: Array[String] = []
	for manifest: GFExtensionManifest in get_enabled_manifests():
		var raw_paths: Variant = _get_manifest_property(manifest, property_name)
		for path_value: String in _GF_VARIANT_ACCESS_SCRIPT.to_string_array(raw_paths):
			var path: String = path_value.strip_edges()
			if path.is_empty() or paths.has(path):
				continue
			paths.append(path)
	return paths


static func _manifest_graph_allows_runtime_paths(manifests: Array[GFExtensionManifest], context: String) -> bool:
	var report: Dictionary = get_manifest_graph_report(manifests)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok", true):
		return true
	push_warning("[GFExtensionSettings] %s blocked: %s" % [context, _summarize_manifest_graph_report(report)])
	return false


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


static func _get_manifest_property(manifest: GFExtensionManifest, property_name: String) -> Variant:
	if manifest == null or not property_name in manifest:
		return null
	return manifest.get_indexed(NodePath(property_name))


static func _get_unknown_enabled_ids(extension_ids: Array[String], manifest_by_id: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for extension_id: String in extension_ids:
		var normalized_id: String = extension_id.strip_edges()
		if _is_builtin_extension_id(normalized_id):
			continue
		if not manifest_by_id.has(normalized_id) and not result.has(normalized_id):
			result.append(normalized_id)
	result.sort()
	return result


static func _is_builtin_extension_id(extension_id: String) -> bool:
	return BUILT_IN_EXTENSION_IDS.has(extension_id)
