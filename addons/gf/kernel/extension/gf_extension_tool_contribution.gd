## GFExtensionToolContribution: 扩展编辑器工具贡献文件的稳定 schema 解析器。
##
## 该类型只定义贡献文件协议，不负责加载脚本、验证资源存在性或管理编辑器生命周期。
## [br]
## @api public
## [br]
## @category protocol
## [br]
## @since 8.0.0
## [br]
## @layer kernel/extension
class_name GFExtensionToolContribution
extends RefCounted


# --- 常量 ---

## 当前支持的贡献文件 schema 版本。
## [br]
## @api public
## [br]
## @since 8.0.0
const SCHEMA_VERSION: int = 1

## 所有可声明的工具贡献路径字段。
## [br]
## @api public
## [br]
## @since 8.0.0
const PATH_FIELDS: Array[String] = [
	"access_generator_extension_paths",
	"editor_action_paths",
	"editor_dock_paths",
	"editor_inspector_paths",
	"export_plugin_paths",
	"gltf_document_extension_paths",
	"import_plugin_paths",
]

## 工具贡献文件允许的全部顶层字段。
## [br]
## @api public
## [br]
## @since 8.0.0
const ALLOWED_FIELDS: Array[String] = [
	"schema_version",
	"extension_id",
	"access_generator_extension_paths",
	"editor_action_paths",
	"editor_dock_paths",
	"editor_inspector_paths",
	"export_plugin_paths",
	"gltf_document_extension_paths",
	"import_plugin_paths",
]
const _GF_EXTENSION_ID_VALIDATOR_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_id_validator.gd")


# --- 公共方法 ---

## 校验并规范化一个工具贡献字典。
##
## 未知字段、未来 schema、错误扩展 ID、非数组路径字段、非字符串或空路径都会使报告失败。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param data: 待校验的 JSON object 数据。
## [br]
## @schema data: Dictionary，字段必须属于 ALLOWED_FIELDS。
## [br]
## @param expected_extension_id: 非空时要求 contribution 的 extension_id 与其一致。
## [br]
## @return: schema 校验报告。
## [br]
## @schema return: Dictionary，包含 ok、data 和 errors；data 包含 schema_version、extension_id 及全部 PATH_FIELDS。
static func parse_dictionary(data: Dictionary, expected_extension_id: String = "") -> Dictionary:
	var errors: Array[String] = []
	var normalized_data: Dictionary = {
		"schema_version": 0,
		"extension_id": "",
	}
	for path_field: String in PATH_FIELDS:
		normalized_data[path_field] = []

	for raw_key: Variant in data.keys():
		if not raw_key is String:
			errors.append("tool contribution field names must be strings")
			continue
		var field_name: String = raw_key
		if not ALLOWED_FIELDS.has(field_name):
			errors.append("unsupported tool contribution field: %s" % field_name)

	var raw_schema_version: Variant = data.get("schema_version")
	var schema_version: int = _parse_schema_version(raw_schema_version)
	if schema_version < 0:
		errors.append("tool contribution schema_version must be an integer")
	elif schema_version != SCHEMA_VERSION:
		errors.append("unsupported tool contribution schema_version: %s" % raw_schema_version)
	else:
		normalized_data["schema_version"] = SCHEMA_VERSION

	var raw_extension_id: Variant = data.get("extension_id")
	if not raw_extension_id is String:
		errors.append("tool contribution extension_id must be a string")
	else:
		var raw_extension_id_text: String = raw_extension_id
		var extension_id: String = raw_extension_id_text.strip_edges()
		if extension_id.is_empty():
			errors.append("tool contribution extension_id must not be empty")
		else:
			var id_error: String = _GF_EXTENSION_ID_VALIDATOR_SCRIPT.get_extension_id_validation_error(
				extension_id,
				"tool contribution extension_id"
			)
			if not id_error.is_empty():
				errors.append(id_error)
			elif not expected_extension_id.is_empty() and extension_id != expected_extension_id:
				errors.append("tool contribution extension_id mismatch")
			else:
				normalized_data["extension_id"] = extension_id

	for path_field: String in PATH_FIELDS:
		var raw_paths: Variant = data.get(path_field, [])
		if not raw_paths is Array:
			errors.append("tool contribution %s must be an array" % path_field)
			continue
		var paths: Array[String] = []
		var path_values: Array = raw_paths
		for raw_path: Variant in path_values:
			if not raw_path is String:
				errors.append("tool contribution %s must contain only strings" % path_field)
				continue
			var raw_path_text: String = raw_path
			var path_text: String = raw_path_text.strip_edges()
			if path_text.is_empty():
				errors.append("tool contribution %s must not contain empty paths" % path_field)
				continue
			if paths.has(path_text):
				continue
			paths.append(path_text)
		normalized_data[path_field] = paths

	return {
		"ok": errors.is_empty(),
		"data": normalized_data,
		"errors": errors,
	}


# --- 私有/辅助方法 ---

static func _parse_schema_version(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		var numeric_value: float = value
		if is_finite(numeric_value) and numeric_value == floor(numeric_value):
			return int(numeric_value)
	return -1
