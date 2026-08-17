## GFExtensionManifest: GF 扩展元数据描述。
##
## 用于描述 GF 扩展的稳定 ID、版本、依赖、运行时安装入口和编辑器展示元数据。
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
const _GF_EXTENSION_ID_VALIDATOR_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_id_validator.gd")
const _GF_EXTENSION_JSON_FILE_READER_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_json_file_reader.gd")
const _SUPPORTED_FIELDS: Array[String] = [
	"dependencies",
	"description",
	"display_name",
	"editor_dock_order",
	"editor_dock_short_label",
	"enabled_by_default",
	"extension_version",
	"id",
	"installer_paths",
	"kind",
	"tags",
	"version",
]
const _MOVED_TO_TOOL_CONTRIBUTION_FIELDS: Array[String] = [
	"access_generator_extension_paths",
	"editor_action_paths",
	"editor_dock_paths",
	"editor_inspector_paths",
	"export_plugin_paths",
	"gltf_document_extension_paths",
	"import_plugin_paths",
]
const _FORBIDDEN_RELATION_FIELDS: Array[String] = [
	"after",
	"before",
	"bundle",
	"bundles",
	"conflicts",
	"extension_dependencies",
	"extension_pack",
	"extension_preset",
	"integrates_with",
	"load_after",
	"load_before",
	"optional_dependencies",
	"peer_dependencies",
	"preset",
	"presets",
	"recommends",
	"soft_dependencies",
	"suggests",
]
const _STRING_FIELDS: Array[String] = [
	"description",
	"display_name",
	"editor_dock_short_label",
	"extension_version",
	"id",
	"kind",
	"version",
]
const _STRING_ARRAY_FIELDS: Array[String] = [
	"dependencies",
	"installer_paths",
	"tags",
]


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

## 编辑器工作区页面排序。数值越小越靠前。
## [br]
## @api public
var editor_dock_order: int = 1000

## 编辑器工作区页面短标签。为空时使用扩展显示名。
## [br]
## @api public
var editor_dock_short_label: String = ""

## 便于工具筛选的标签。
## [br]
## @api public
var tags: Array[String] = []

## 是否在项目首次启用 GF 时进入默认扩展选择。
## [br]
## @api public
## [br]
## @since 3.17.0
var enabled_by_default: bool = false

## manifest 文件路径。
## [br]
## @api public
var source_path: String = ""


# --- 私有变量 ---

var _source_field_names: Array[String] = []
var _source_schema_errors: Array[String] = []


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
	manifest._source_field_names = _normalize_field_name_list(data.keys())
	manifest._source_schema_errors = _get_source_schema_errors(data)
	manifest.id = _normalize_manifest_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "id"))
	manifest.display_name = _normalize_manifest_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		data,
		"display_name"
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
		"description"
	))
	manifest.dependencies = _normalize_identifier_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "dependencies"))
	manifest.installer_paths = _normalize_resource_path_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "installer_paths"))
	manifest.editor_dock_order = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(data, "editor_dock_order", manifest.editor_dock_order)
	manifest.editor_dock_short_label = _normalize_manifest_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "editor_dock_short_label"))
	manifest.tags = _normalize_identifier_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "tags"))
	manifest.enabled_by_default = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		data,
		"enabled_by_default",
		manifest.kind == KIND_STANDARD
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
	var report: Dictionary = _from_json_file_object_report(path)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok", false):
		return null
	var manifest_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(report, "manifest")
	if manifest_value is GFExtensionManifest:
		var manifest: GFExtensionManifest = manifest_value
		return manifest
	return null


## 从 JSON 文件读取扩展 manifest 并返回诊断报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param path: `gf_extension.json` 文件路径。
## [br]
## @return 读取诊断，包含 ok、source_path、manifest_data 和 errors。
## [br]
## @schema return: Dictionary { ok: bool, source_path: String, manifest_data: Dictionary, errors: Array[String] }.
static func from_json_file_report(path: String) -> Dictionary:
	var report: Dictionary = _from_json_file_object_report(path)
	var manifest_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(report, "manifest")
	var manifest_data: Dictionary = {}
	if manifest_value is GFExtensionManifest:
		var manifest: GFExtensionManifest = manifest_value
		manifest_data = manifest.to_dictionary()
	return {
		"ok": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok", false),
		"source_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "source_path"),
		"manifest_data": manifest_data,
		"errors": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "errors").duplicate(true),
	}


## 判断文本是否是合法 GF 扩展 ID。
##
## 合法 ID 使用小写 dotted identifier segments，例如 `vendor.feature` 或
## `author.feature_name`。它是机器稳定 ID，不承载显示名、路径或加载顺序。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param extension_id: 要检查的扩展 ID。
## [br]
## @return 满足扩展 ID 语法时返回 true。
static func is_valid_extension_id(extension_id: String) -> bool:
	return _GF_EXTENSION_ID_VALIDATOR_SCRIPT.is_valid_extension_id(extension_id)


## 获取扩展 ID 语法错误。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param extension_id: 要检查的扩展 ID。
## [br]
## @param field_name: 报错中使用的字段名。
## [br]
## @return ID 合法时返回空字符串，否则返回错误说明。
static func get_extension_id_validation_error(extension_id: String, field_name: String = "id") -> String:
	return _GF_EXTENSION_ID_VALIDATOR_SCRIPT.get_extension_id_validation_error(extension_id, field_name)


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
		"description": description,
		"dependencies": dependencies.duplicate(),
		"installer_paths": installer_paths.duplicate(),
		"editor_dock_order": editor_dock_order,
		"editor_dock_short_label": editor_dock_short_label,
		"tags": tags.duplicate(),
		"enabled_by_default": enabled_by_default,
	}


## 创建 manifest 副本。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 与当前 manifest 内容一致的新实例。
func duplicate_manifest() -> GFExtensionManifest:
	var manifest: GFExtensionManifest = GFExtensionManifest.new()
	manifest.id = id
	manifest.display_name = display_name
	manifest.version = version
	manifest.extension_version = extension_version
	manifest.kind = kind
	manifest.root_path = root_path
	manifest.description = description
	manifest.dependencies = dependencies.duplicate()
	manifest.installer_paths = installer_paths.duplicate()
	manifest.editor_dock_order = editor_dock_order
	manifest.editor_dock_short_label = editor_dock_short_label
	manifest.tags = tags.duplicate()
	manifest.enabled_by_default = enabled_by_default
	manifest.source_path = source_path
	manifest._source_field_names = _source_field_names.duplicate()
	manifest._source_schema_errors = _source_schema_errors.duplicate()
	return manifest


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
	var errors: Array[String] = _source_schema_errors.duplicate()
	_append_unsupported_field_errors(errors)
	var id_error: String = get_extension_id_validation_error(id)
	if not id_error.is_empty():
		errors.append(id_error)
	if display_name.strip_edges().is_empty():
		errors.append("display_name is required")
	if version.strip_edges().is_empty():
		errors.append("version is required")
	if not [KIND_STANDARD, KIND_EXTENSION].has(kind):
		errors.append("kind must be standard or extension")
	if root_path.strip_edges().is_empty():
		errors.append("root_path is required")
	_append_identifier_errors(errors, "dependencies", dependencies)
	_append_script_resource_path_errors(errors, "installer_paths", installer_paths)
	return errors


# --- 私有/辅助方法 ---

static func _from_json_file_object_report(path: String) -> Dictionary:
	var json_report: Dictionary = _GF_EXTENSION_JSON_FILE_READER_SCRIPT.read_object_report(path, {
		"empty_path_error": "manifest path is empty",
		"open_error_prefix": "could not open manifest",
		"read_error_prefix": "could not read manifest",
		"parse_error_prefix": "could not parse JSON manifest",
		"root_type_error": "manifest JSON root must be an object",
	})
	var normalized_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(json_report, "source_path")
	var errors: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(json_report, "errors")
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(json_report, "ok", false):
		return _make_json_file_report(false, normalized_path, null, errors)

	var parsed_dictionary: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(json_report, "data")
	var manifest: GFExtensionManifest = from_dictionary(parsed_dictionary, normalized_path.get_base_dir(), normalized_path)
	errors.append_array(manifest.get_validation_errors())
	return _make_json_file_report(errors.is_empty(), normalized_path, manifest, errors)


static func _normalize_manifest_text(value: String) -> String:
	return value.strip_edges()


static func _get_source_schema_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for field_name: String in _STRING_FIELDS:
		if not _has_dictionary_key(data, field_name):
			continue
		var raw_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(data, field_name)
		if not (raw_value is String or raw_value is StringName):
			errors.append("manifest %s must be a string" % field_name)
	for field_name: String in _STRING_ARRAY_FIELDS:
		if not _has_dictionary_key(data, field_name):
			continue
		var raw_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(data, field_name)
		if not (raw_value is Array or raw_value is PackedStringArray):
			errors.append("manifest %s must be an array of strings" % field_name)
			continue
		if raw_value is Array:
			var raw_values: Array = raw_value
			if raw_values.any(func(item: Variant) -> bool:
				return not (item is String or item is StringName)
			):
				errors.append("manifest %s must contain only strings" % field_name)
	if _has_dictionary_key(data, "editor_dock_order"):
		var raw_order: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(data, "editor_dock_order")
		if not _is_integer_value(raw_order):
			errors.append("manifest editor_dock_order must be an integer")
	if _has_dictionary_key(data, "enabled_by_default"):
		var raw_enabled: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(data, "enabled_by_default")
		if not raw_enabled is bool:
			errors.append("manifest enabled_by_default must be a boolean")
	return errors


static func _has_dictionary_key(data: Dictionary, key: String) -> bool:
	return data.has(key) or data.has(StringName(key))


static func _is_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		var numeric_value: float = value
		return is_finite(numeric_value) and numeric_value == floor(numeric_value)
	return false


static func _normalize_field_name_list(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		var field_name: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(value).strip_edges()
		if field_name.is_empty() or result.has(field_name):
			continue
		result.append(field_name)
	return result


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


func _append_unsupported_field_errors(errors: Array[String]) -> void:
	for field_name: String in _source_field_names:
		if _MOVED_TO_TOOL_CONTRIBUTION_FIELDS.has(field_name):
			errors.append(
				"manifest field moved to editor/gf_tool_contribution.json: %s" % field_name
			)
		elif _FORBIDDEN_RELATION_FIELDS.has(field_name):
			errors.append("unsupported manifest relation field: %s" % field_name)
		elif not _SUPPORTED_FIELDS.has(field_name):
			errors.append("unsupported manifest field: %s" % field_name)


static func _make_json_file_report(
	ok: bool,
	report_source_path: String,
	manifest: GFExtensionManifest,
	errors: Array[String]
) -> Dictionary:
	return {
		"ok": ok,
		"source_path": report_source_path,
		"manifest": manifest,
		"errors": errors.duplicate(),
	}


func _append_script_resource_path_errors(
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
			continue
		if normalized_path.get_extension().to_lower() != "gd":
			errors.append("%s path must point to a GDScript resource: %s" % [property_name, normalized_path])
			continue
		if not source_path.is_empty() and not ResourceLoader.exists(normalized_path, "Script"):
			errors.append("%s path must point to an existing script resource: %s" % [property_name, normalized_path])


func _append_identifier_errors(
	errors: Array[String],
	property_name: String,
	values: Array[String]
) -> void:
	for value: String in values:
		var id_error: String = get_extension_id_validation_error(value, property_name)
		if not id_error.is_empty():
			errors.append(id_error)


func _path_is_under_root(path: String) -> bool:
	return _GF_PATH_TOOLS.is_path_under_root(path, root_path, true, true)
