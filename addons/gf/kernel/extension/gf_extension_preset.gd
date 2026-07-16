## GFExtensionPreset: GF 扩展启用组合描述。
##
## Preset 只描述一组显式启用扩展 ID，不改变 manifest 依赖、
## 不表示扩展之间存在硬依赖，也不承载下载、安装包或跨扩展编排逻辑。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 5.0.0
## [br]
## @layer kernel/extension
class_name GFExtensionPreset
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_EXTENSION_MANIFEST_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_manifest.gd")
const _GF_EXTENSION_JSON_FILE_READER_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_json_file_reader.gd")
const _SUPPORTED_FIELDS: Array[String] = [
	"description",
	"display_name",
	"extension_ids",
	"id",
	"tags",
]
const _FORBIDDEN_RELATION_FIELDS: Array[String] = [
	"after",
	"before",
	"conflicts",
	"dependencies",
	"depends_on",
	"extension_dependencies",
	"extension_pack",
	"integrates_with",
	"load_after",
	"load_before",
	"optional_dependencies",
	"peer_dependencies",
	"preset",
	"presets",
	"recommends",
	"requires",
	"soft_dependencies",
	"suggests",
]
const _FORBIDDEN_PACKAGE_FIELDS: Array[String] = [
	"archive",
	"checksum",
	"download",
	"download_url",
	"download_urls",
	"downloads",
	"editor_action_paths",
	"external_roots",
	"files",
	"install_script",
	"install_url",
	"installer_paths",
	"installers",
	"manifest_overrides",
	"npm",
	"package",
	"package_id",
	"package_name",
	"packages",
	"registry",
	"repository",
	"sha256",
]


# --- 公共变量 ---

## Preset 稳定 ID。
## [br]
## @api public
## [br]
## @since 5.0.0
var id: StringName = &""

## 面向用户显示的 preset 名称。
## [br]
## @api public
## [br]
## @since 5.0.0
var display_name: String = ""

## Preset 说明。
## [br]
## @api public
## [br]
## @since 5.0.0
var description: String = ""

## 要启用的扩展 ID 列表。
## [br]
## @api public
## [br]
## @since 5.0.0
var extension_ids: Array[String] = []

## 便于编辑器工具筛选的标签。
## [br]
## @api public
## [br]
## @since 5.0.0
var tags: Array[String] = []

## Preset 来源文件路径。内置或代码注册的 preset 可为空。
## [br]
## @api public
## [br]
## @since 5.0.0
var source_path: String = ""


# --- 私有变量 ---

var _source_field_names: Array[String] = []


# --- 公共方法 ---

## 从字典创建扩展 preset。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param data: preset 字典。
## [br]
## @schema data: Dictionary containing id, display_name, description, extension_ids, and tags.
## [br]
## @param preset_source_path: preset 来源文件路径。
## [br]
## @return 扩展 preset 实例。
static func from_dictionary(data: Dictionary, preset_source_path: String = "") -> GFExtensionPreset:
	var preset: GFExtensionPreset = GFExtensionPreset.new()
	preset._source_field_names = _normalize_field_name_list(data.keys())
	preset.id = StringName(_normalize_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "id")))
	preset.display_name = _normalize_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		data,
		"display_name"
	))
	if preset.display_name.is_empty() and preset.id != &"":
		preset.display_name = String(preset.id)
	preset.description = _normalize_text(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		data,
		"description"
	))
	preset.extension_ids = _normalize_identifier_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(
		data,
		"extension_ids"
	))
	preset.tags = _normalize_identifier_list(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, "tags"))
	preset.source_path = _GF_PATH_TOOLS.normalize_resource_path(preset_source_path)
	return preset


## 从 JSON 文件读取扩展 preset。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param path: preset JSON 文件路径。
## [br]
## @return 读取成功时返回 preset；失败时返回 null。
static func from_json_file(path: String) -> GFExtensionPreset:
	var report: Dictionary = _from_json_file_object_report(path)
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok", false):
		return null
	var preset_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(report, "preset")
	if preset_value is GFExtensionPreset:
		var preset: GFExtensionPreset = preset_value
		return preset
	return null


## 从 JSON 文件读取扩展 preset 并返回诊断报告。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param path: preset JSON 文件路径。
## [br]
## @return 读取诊断，包含 ok、source_path、preset_data 和 errors。
## [br]
## @schema return: Dictionary { ok: bool, source_path: String, preset_data: Dictionary, errors: Array[String] }.
static func from_json_file_report(path: String) -> Dictionary:
	var report: Dictionary = _from_json_file_object_report(path)
	var preset_value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(report, "preset")
	var preset_data: Dictionary = {}
	if preset_value is GFExtensionPreset:
		var preset: GFExtensionPreset = preset_value
		preset_data = preset.to_dictionary()
	return {
		"ok": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok", false),
		"source_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(report, "source_path"),
		"preset_data": preset_data,
		"errors": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "errors").duplicate(true),
	}


## 转换为字典。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return preset 字典副本。
## [br]
## @schema return: Dictionary matching the extension preset JSON shape.
func to_dictionary() -> Dictionary:
	return {
		"id": String(id),
		"display_name": display_name,
		"description": description,
		"extension_ids": extension_ids.duplicate(),
		"tags": tags.duplicate(),
	}


## 检查 preset 是否满足基本规范。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 满足规范时返回 true。
func is_valid() -> bool:
	return get_validation_errors().is_empty()


## 获取 preset 规范错误。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @return 错误消息列表。
func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []
	_append_unsupported_field_errors(errors)
	var id_error: String = _GF_EXTENSION_MANIFEST_SCRIPT.get_extension_id_validation_error(String(id))
	if not id_error.is_empty():
		errors.append(id_error)
	if display_name.strip_edges().is_empty():
		errors.append("display_name is required")
	_append_identifier_errors(errors, "extension_ids", extension_ids)
	return errors


# --- 私有/辅助方法 ---

static func _from_json_file_object_report(path: String) -> Dictionary:
	var json_report: Dictionary = _GF_EXTENSION_JSON_FILE_READER_SCRIPT.read_object_report(path, {
		"empty_path_error": "preset path is empty",
		"open_error_prefix": "could not open preset",
		"read_error_prefix": "could not read preset",
		"parse_error_prefix": "could not parse preset JSON",
		"root_type_error": "preset JSON root must be an object",
	})
	var normalized_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(json_report, "source_path")
	var errors: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(json_report, "errors")
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(json_report, "ok", false):
		return _make_json_file_report(false, normalized_path, null, errors)

	var parsed_dictionary: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(json_report, "data")
	var preset: GFExtensionPreset = from_dictionary(parsed_dictionary, normalized_path)
	errors.append_array(preset.get_validation_errors())
	return _make_json_file_report(errors.is_empty(), normalized_path, preset, errors)


static func _normalize_text(value: String) -> String:
	return value.strip_edges()


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


func _append_unsupported_field_errors(errors: Array[String]) -> void:
	for field_name: String in _source_field_names:
		if _FORBIDDEN_RELATION_FIELDS.has(field_name):
			errors.append("unsupported preset relation field: %s" % field_name)
		elif _FORBIDDEN_PACKAGE_FIELDS.has(field_name):
			errors.append("unsupported preset package field: %s" % field_name)
		elif not _SUPPORTED_FIELDS.has(field_name):
			errors.append("unsupported preset field: %s" % field_name)


static func _make_json_file_report(
	ok: bool,
	report_source_path: String,
	preset: GFExtensionPreset,
	errors: Array[String]
) -> Dictionary:
	return {
		"ok": ok,
		"source_path": report_source_path,
		"preset": preset,
		"errors": errors.duplicate(),
	}


func _append_identifier_errors(
	errors: Array[String],
	property_name: String,
	values: Array[String]
) -> void:
	for value: String in values:
		var id_error: String = _GF_EXTENSION_MANIFEST_SCRIPT.get_extension_id_validation_error(value, property_name)
		if not id_error.is_empty():
			errors.append(id_error)
