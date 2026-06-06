## GFExtensionManifest: GF 扩展元数据描述。
##
## 用于描述 GF 扩展的稳定 ID、版本、依赖、安装入口和编辑器扩展。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
## [br]
## @layer kernel/extension
class_name GFExtensionManifest
extends RefCounted


# --- 常量 ---

## GF 扩展 manifest 文件名。
## [br]
## @api public
const FILE_NAME: String = "gf_extension.json"

## 扩展类型：GF 标准库内置能力。
## [br]
## @api public
const KIND_STANDARD: String = "standard"

## 扩展类型：GF 可选扩展。
## [br]
## @api public
const KIND_EXTENSION: String = "extension"

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")


# --- 公共变量 ---

## 稳定扩展 ID，推荐格式为反向域名或作者命名空间，例如 `author.extension_name`。
## [br]
## @api public
var id: String = ""

## 面向用户显示的扩展名。
## [br]
## @api public
var display_name: String = ""

## 扩展发行版本号。GF 内置扩展必须与当前 GF 发行版本一致。
## [br]
## @api public
var version: String = ""

## 扩展自身版本号。GF 内置扩展按扩展内公开行为变化独立递增；未声明时回退到 version。
## [br]
## @api public
var extension_version: String = ""

## 扩展类型，应为 `standard` 或 `extension`。
## [br]
## @api public
var kind: String = KIND_EXTENSION

## 扩展根目录。
## [br]
## @api public
var root_path: String = ""

## 简短说明。
## [br]
## @api public
var description: String = ""

## 依赖的扩展 ID 列表。
## [br]
## @api public
var dependencies: Array[String] = []

## 可选 GFInstaller 路径列表。需要自动装配运行时模块时使用。
## [br]
## @api public
var installer_paths: Array[String] = []

## 可选编辑器菜单动作脚本路径列表。
## [br]
## @api public
var editor_action_paths: Array[String] = []

## 可选编辑器工作区页面脚本路径列表。
## [br]
## @api public
var editor_dock_paths: Array[String] = []

## 编辑器工作区页面排序。数值越小越靠前。
## [br]
## @api public
var editor_dock_order: int = 1000

## 编辑器工作区页面短标签。为空时使用扩展显示名。
## [br]
## @api public
var editor_dock_short_label: String = ""

## 可选 EditorInspectorPlugin 路径列表。需要为扩展内类型提供 Inspector 增强时使用。
## [br]
## @api public
var editor_inspector_paths: Array[String] = []

## 可选 EditorImportPlugin 路径列表。需要为自定义资源格式提供导入器时使用。
## [br]
## @api public
var import_plugin_paths: Array[String] = []

## 可选 EditorExportPlugin 路径列表。
## [br]
## @api public
var export_plugin_paths: Array[String] = []

## 可选 GLTFDocumentExtension 路径列表。用于导入期资产元数据桥接等编辑器能力。
## [br]
## @api public
var gltf_document_extension_paths: Array[String] = []

## 可选 GFAccessGenerator 扩展脚本路径列表。
## [br]
## @api public
var access_generator_extension_paths: Array[String] = []

## 便于工具筛选的标签。
## [br]
## @api public
var tags: Array[String] = []

## 是否在项目首次启用 GF 时默认启用该扩展。
## [br]
## @api public
var enabled_by_default: bool = false

## manifest 文件路径。
## [br]
## @api public
var source_path: String = ""

# --- 公共方法 ---

## 从字典创建扩展 manifest。
## [br]
## @api public
## [br]
## @param data: manifest 字典。
## [br]
## @schema data: Dictionary decoded from gf_extension.json.
## [br]
## @param extension_root_path: 扩展根目录。
## [br]
## @param manifest_source_path: manifest 文件路径。
## [br]
## @return 扩展 manifest 实例。
static func from_dictionary(
	data: Dictionary,
	extension_root_path: String = "",
	manifest_source_path: String = ""
) -> GFExtensionManifest:
	var manifest: GFExtensionManifest = GFExtensionManifest.new()
	manifest.id = _normalize_manifest_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "id"))
	manifest.display_name = _normalize_manifest_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		data,
		"display_name",
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "name")
	))
	manifest.version = _normalize_manifest_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "version"))
	manifest.extension_version = _normalize_manifest_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		data,
		"extension_version",
		manifest.version
	))
	manifest.kind = _normalize_manifest_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "kind", KIND_EXTENSION))
	if manifest.kind.is_empty():
		manifest.kind = KIND_EXTENSION
	manifest.root_path = _GF_PATH_TOOLS.normalize_root_path(extension_root_path)
	manifest.description = _normalize_manifest_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		data,
		"description",
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "summary")
	))
	manifest.dependencies = _normalize_identifier_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "dependencies"))
	manifest.installer_paths = _normalize_resource_path_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "installer_paths"))
	manifest.editor_action_paths = _normalize_resource_path_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "editor_action_paths"))
	manifest.editor_dock_paths = _normalize_resource_path_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "editor_dock_paths"))
	manifest.editor_dock_order = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(data, "editor_dock_order", manifest.editor_dock_order)
	manifest.editor_dock_short_label = _normalize_manifest_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "editor_dock_short_label"))
	manifest.editor_inspector_paths = _normalize_resource_path_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "editor_inspector_paths"))
	manifest.import_plugin_paths = _normalize_resource_path_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "import_plugin_paths"))
	manifest.export_plugin_paths = _normalize_resource_path_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "export_plugin_paths"))
	manifest.gltf_document_extension_paths = _normalize_resource_path_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "gltf_document_extension_paths"))
	manifest.access_generator_extension_paths = _normalize_resource_path_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "access_generator_extension_paths"))
	manifest.tags = _normalize_identifier_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "tags"))
	manifest.enabled_by_default = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		data,
		"enabled_by_default",
		manifest.kind == KIND_STANDARD or manifest.kind == KIND_EXTENSION
	)
	manifest.source_path = _GF_PATH_TOOLS.normalize_resource_path(manifest_source_path)
	return manifest


## 从 JSON 文件读取扩展 manifest。
## [br]
## @api public
## [br]
## @param path: `gf_extension.json` 文件路径。
## [br]
## @return 读取成功时返回 manifest；失败时返回 null。
static func from_json_file(path: String) -> GFExtensionManifest:
	if path.is_empty():
		return null

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return null

	var parsed_dictionary: Dictionary = parsed
	return from_dictionary(parsed_dictionary, path.get_base_dir(), path)


## 转换为字典。
## [br]
## @api public
## [br]
## @return manifest 字典副本。
## [br]
## @schema return: Dictionary matching the gf_extension.json manifest shape.
func to_dictionary() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"version": version,
		"extension_version": extension_version,
		"kind": kind,
		"root_path": root_path,
		"description": description,
		"dependencies": dependencies.duplicate(),
		"installer_paths": installer_paths.duplicate(),
		"editor_action_paths": editor_action_paths.duplicate(),
		"editor_dock_paths": editor_dock_paths.duplicate(),
		"editor_dock_order": editor_dock_order,
		"editor_dock_short_label": editor_dock_short_label,
		"editor_inspector_paths": editor_inspector_paths.duplicate(),
		"import_plugin_paths": import_plugin_paths.duplicate(),
		"export_plugin_paths": export_plugin_paths.duplicate(),
		"gltf_document_extension_paths": gltf_document_extension_paths.duplicate(),
		"access_generator_extension_paths": access_generator_extension_paths.duplicate(),
		"tags": tags.duplicate(),
		"enabled_by_default": enabled_by_default,
		"source_path": source_path,
	}


## 检查 manifest 是否满足基本规范。
## [br]
## @api public
## [br]
## @return 满足规范时返回 true。
func is_valid() -> bool:
	return get_validation_errors().is_empty()


## 获取 manifest 规范错误。
## [br]
## @api public
## [br]
## @return 错误消息列表。
func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if id.strip_edges().is_empty():
		errors.append("id is required")
	if display_name.strip_edges().is_empty():
		errors.append("display_name is required")
	if version.strip_edges().is_empty():
		errors.append("version is required")
	if not [KIND_STANDARD, KIND_EXTENSION].has(kind):
		errors.append("kind must be standard or extension")
	if root_path.strip_edges().is_empty():
		errors.append("root_path is required")
	_append_resource_path_errors(errors, "installer_paths", installer_paths)
	_append_resource_path_errors(errors, "editor_action_paths", editor_action_paths)
	_append_resource_path_errors(errors, "editor_dock_paths", editor_dock_paths)
	_append_resource_path_errors(errors, "editor_inspector_paths", editor_inspector_paths)
	_append_resource_path_errors(errors, "import_plugin_paths", import_plugin_paths)
	_append_resource_path_errors(errors, "export_plugin_paths", export_plugin_paths)
	_append_resource_path_errors(errors, "gltf_document_extension_paths", gltf_document_extension_paths)
	_append_resource_path_errors(errors, "access_generator_extension_paths", access_generator_extension_paths)
	return errors


# --- 私有/辅助方法 ---

static func _normalize_manifest_text(value: String) -> String:
	return value.strip_edges()


static func _normalize_identifier_list(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		var normalized_value: String = value.strip_edges()
		if normalized_value.is_empty() or result.has(normalized_value):
			continue
		result.append(normalized_value)
	return result


static func _normalize_resource_path_list(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		result.append(_GF_PATH_TOOLS.normalize_resource_path(value))
	return result


func _append_resource_path_errors(
	errors: Array[String],
	property_name: String,
	paths: Array[String]
) -> void:
	for path: String in paths:
		var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(path)
		if normalized_path.is_empty():
			errors.append("%s contains empty path" % property_name)
			continue
		if not normalized_path.begins_with("res://"):
			errors.append("%s path must be res://: %s" % [property_name, normalized_path])
			continue
		if not _path_is_under_root(normalized_path):
			errors.append("%s path must stay under root_path: %s" % [property_name, normalized_path])


func _path_is_under_root(path: String) -> bool:
	return _GF_PATH_TOOLS.is_path_under_root(path, root_path, true, true)
