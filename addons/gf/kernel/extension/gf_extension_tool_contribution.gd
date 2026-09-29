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
const SCHEMA_VERSION: int = 3

## 所有可声明的工具贡献路径字段。
## [br]
## @api public
## [br]
## @since 8.0.0
const PATH_FIELDS: Array[String] = [
	"access_generator_extension_paths",
	"debugger_plugin_paths",
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
	"task_records",
	"resource_action_records",
	"schema_version",
	"extension_id",
	"access_generator_extension_paths",
	"debugger_plugin_paths",
	"editor_action_paths",
	"editor_dock_paths",
	"editor_inspector_paths",
	"export_plugin_paths",
	"gltf_document_extension_paths",
	"import_plugin_paths",
]

## 校验工具贡献文件 extension_id 的辅助脚本。
## [br]
## @api private
const _GF_EXTENSION_ID_VALIDATOR_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_id_validator.gd")

## 工作区记录的纯数据校验器。
## [br]
## @api private
const _WORKSPACE_RECORDS_SCRIPT = preload("res://addons/gf/kernel/extension/gf_workspace_contribution_records.gd")


# --- 公共方法 ---

## 校验并规范化一个工具贡献字典。
##
## 接受 v2 与 v3；v3 额外支持任务和资源动作记录。未知字段、其他 schema、错误扩展 ID、非数组路径字段、
## 非字符串或空路径都会使报告失败。
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
## @schema return: Dictionary，含 ok: bool、data: Dictionary、errors: Array[String]；仅 ok 为 true 时可消费 data。data 始终含 schema_version: int、extension_id: String 及全部 PATH_FIELDS（去空白、去重的字符串数组，省略时为空）。v2 不返回工作区记录字段，输入携带它们时失败；v3 另含 task_records、resource_action_records: Array[Dictionary]（省略时为空）。每项均含 owner_package_id: String（默认 extension_id）、source_id: String（owner_package_id:本地来源 ID）、title: String（去首尾空白）、description: String（默认空）、keywords: 字符串数组（默认空）、group: String（默认“常用”）、page_path: String（保留声明路径，须匹配同一 owner 的 editor_dock_paths）、action_id: String（任务默认空）。资源动作另要求 action_id 非空，并含 resource_types: 非空字符串数组（仅 Resource、PackedScene、Texture2D、AudioStream、Font、Material、Mesh、Script）、max_selection: int（1 到 100，默认 1）。失败时 errors 非空，data 可保留部分规范化结果，不能作为已通过校验的贡献。
static func parse_dictionary(data: Dictionary, expected_extension_id: String = "") -> Dictionary:
	var errors: Array[String] = []
	var normalized_data: Dictionary = {
		"schema_version": 0,
		"extension_id": "",
	}
	for path_field: String in PATH_FIELDS:
		normalized_data[path_field] = []

	var raw_schema_version: Variant = data.get("schema_version")
	var schema_version: int = _parse_schema_version(raw_schema_version)
	for raw_key: Variant in data.keys():
		if not raw_key is String:
			errors.append("tool contribution field names must be strings")
			continue
		var field_name: String = raw_key
		var workspace_field: bool = field_name in ["task_records", "resource_action_records"]
		if not ALLOWED_FIELDS.has(field_name) and not (schema_version == 3 and workspace_field):
			errors.append("unsupported tool contribution field: %s" % field_name)
		elif schema_version == 2 and workspace_field:
			errors.append("workspace records require tool contribution schema_version 3")

	if schema_version < 0:
		errors.append("tool contribution schema_version must be an integer")
	elif schema_version not in [2, SCHEMA_VERSION]:
		errors.append("unsupported tool contribution schema_version: %s" % raw_schema_version)
	else:
		normalized_data["schema_version"] = schema_version

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
	if schema_version == 3:
		var page_owners: Dictionary = {}
		var extension_id: String = str(normalized_data["extension_id"])
		var page_paths: Array = normalized_data.get("editor_dock_paths", [])
		for path: String in page_paths:
			page_owners[path] = extension_id
		var workspace_identities: Dictionary = {}
		for family: String in ["task_records", "resource_action_records"]:
			var parsed: Dictionary = _WORKSPACE_RECORDS_SCRIPT.parse_records(
				data.get(family, []), extension_id, page_owners, family == "resource_action_records"
			)
			normalized_data[family] = parsed["records"]
			var family_errors: Array = parsed["errors"]
			for message: String in family_errors:
				errors.append(message)
			var workspace_records: Array = parsed["records"]
			for record: Dictionary in workspace_records:
				var source_id: String = str(record.get("source_id", ""))
				if workspace_identities.has(source_id):
					errors.append("duplicate workspace source_id: %s" % source_id)
				workspace_identities[source_id] = true

	return {
		"ok": errors.is_empty(),
		"data": normalized_data,
		"errors": errors,
	}


# --- 私有/辅助方法 ---

## 接受 int 或有限且等于其 floor 值的 float，其余类型返回 -1。
## [br]
## @api private
static func _parse_schema_version(value: Variant) -> int:
	if value is int:
		return value
	if value is float:
		var numeric_value: float = value
		if is_finite(numeric_value) and numeric_value == floor(numeric_value):
			return int(numeric_value)
	return -1
