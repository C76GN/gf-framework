## GFContentPackageManifest: 通用内容包 manifest。
##
## 描述一个内容包的稳定包 ID、版本、依赖和资源键映射。GF 只校验结构、路径安全和依赖关系，
## 不解释内容类型的业务语义，也不负责下载、启用策略或具体玩法规则。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 4.4.0
class_name GFContentPackageManifest
extends Resource


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_RESOURCE_REGISTRY_TOOLS = preload("res://addons/gf/standard/utilities/assets/gf_resource_registry_tools.gd")

## 内容包 JSON manifest 默认文件名。
## [br]
## @api public
const FILE_NAME: String = "gf_content_package.json"

## 当前 manifest schema 版本。
## [br]
## @api public
const SCHEMA_VERSION: int = 1


const _REPORT_SUBJECT: String = "Content package manifest"
const _KIND_MISSING_PACKAGE_ID: String = "missing_package_id"
const _KIND_MISSING_VERSION: String = "missing_version"
const _KIND_MISSING_SCHEMA_VERSION: String = "missing_schema_version"
const _KIND_INVALID_SCHEMA_VERSION: String = "invalid_schema_version"
const _KIND_UNSUPPORTED_SCHEMA_VERSION: String = "unsupported_schema_version"
const _KIND_INVALID_CONTENT_TYPE: String = "invalid_content_type"
const _KIND_INVALID_DEPENDENCY: String = "invalid_dependency"
const _KIND_INVALID_RESOURCE_ENTRY: String = "invalid_resource_entry"
const _KIND_INVALID_RESOURCE_KEY: String = "invalid_resource_key"
const _KIND_DUPLICATE_RESOURCE_KEY: String = "duplicate_resource_key"
const _KIND_INVALID_RESOURCE_PATH: String = "invalid_resource_path"
const _KIND_RESOURCE_PATH_NOT_ALLOWED: String = "resource_path_not_allowed"
const _KIND_RESOURCE_PATH_OUTSIDE_PACKAGE: String = "resource_path_outside_package"
const _KIND_RESOURCE_EXTENSION_FORBIDDEN: String = "resource_extension_forbidden"
const _KIND_MISSING_RESOURCE_FILE: String = "missing_resource_file"
const _KIND_INVALID_SAFETY_KIND: String = "invalid_safety_kind"
const _KIND_UNKNOWN_FIELD: String = "unknown_field"
const _KIND_INVALID_MANIFEST_FIELD_TYPE: String = "invalid_manifest_field_type"
const _KIND_INVALID_RESOURCE_FIELD_TYPE: String = "invalid_resource_field_type"
const _KIND_RESOURCE_DEPENDENCY_EXTENSION_FORBIDDEN: String = "resource_dependency_extension_forbidden"
const _KIND_RESOURCE_DEPENDENCY_SCAN_FAILED: String = "resource_dependency_scan_failed"

## 只允许数据资源的内容包安全分类。
## [br]
## @api public
## [br]
## @since 6.0.0
const SAFETY_KIND_DATA_ONLY: StringName = &"data_only"

## 允许开发者代码资源的内容包安全分类。
## [br]
## @api public
## [br]
## @since 6.0.0
const SAFETY_KIND_TRUSTED_DEVELOPER: StringName = &"trusted_developer"

const _DATA_ONLY_FORBIDDEN_EXTENSIONS: PackedStringArray = [
	"bat",
	"cmd",
	"cs",
	"dll",
	"dylib",
	"exe",
	"gd",
	"gdc",
	"gdextension",
	"gdshader",
	"ps1",
	"py",
	"sh",
	"shader",
	"so",
]

const _ALLOWED_FIELDS: PackedStringArray = [
	"schema_version",
	"package_id",
	"id",
	"display_name",
	"name",
	"version",
	"content_types",
	"dependencies",
	"safety_kind",
	"forbidden_resource_extensions",
	"resources",
	"metadata",
]

const _ALLOWED_RESOURCE_FIELDS: PackedStringArray = [
	"key",
	"resource_key",
	"path",
	"resource_path",
	"type_hint",
	"priority",
	"metadata",
]


# --- 导出变量 ---

## manifest schema 版本。JSON manifest 必须显式声明当前支持的版本。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var schema_version: int = SCHEMA_VERSION

## 稳定内容包 ID。
## [br]
## @api public
@export var package_id: StringName = &""

## 编辑器或诊断显示名。
## [br]
## @api public
@export var display_name: String = ""

## 内容包版本字符串。
## [br]
## @api public
@export var version: String = ""

## 内容类型标签。GF 只做归一化和诊断，不解释业务语义。
## [br]
## @api public
@export var content_types: PackedStringArray = PackedStringArray()

## 依赖内容包 ID 列表。
## [br]
## @api public
@export var dependencies: PackedStringArray = PackedStringArray()

## 内容包安全分类。data_only 默认拒绝脚本、shader、GDExtension 和可执行文件。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var safety_kind: StringName = SAFETY_KIND_DATA_ONLY

## 调用方额外禁止的资源扩展名，不需要前导点。
## [br]
## @api public
## [br]
## @since 6.0.0
@export var forbidden_resource_extensions: PackedStringArray = PackedStringArray()

## 资源键映射列表。
## [br]
## @api public
## [br]
## @schema resources: Array[Dictionary]，每项包含 key、path、可选 type_hint、priority 和 metadata。
@export var resources: Array[Dictionary] = []

## 项目自定义元数据。GF 不解释其中业务字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary project-defined content package metadata.
@export var metadata: Dictionary = {}


# --- 公共变量 ---

## manifest 所在内容包根目录。通常由加载路径推导。
## [br]
## @api public
var root_path: String = ""

## manifest 文件路径。通常指向 `gf_content_package.json`。
## [br]
## @api public
var source_path: String = ""


# --- 私有变量 ---

var _schema_version_was_present: bool = true
var _schema_version_has_valid_type: bool = true
var _unknown_fields: PackedStringArray = PackedStringArray()
var _schema_issues: Array[Dictionary] = []


# --- 公共方法 ---

## 配置 manifest。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param p_package_id: 稳定内容包 ID。
## [br]
## @param p_version: 内容包版本。
## [br]
## @param p_resources: 资源键映射列表。
## [br]
## @param p_display_name: 可选显示名。
## [br]
## @param p_content_types: 内容类型标签。
## [br]
## @param p_dependencies: 依赖内容包 ID 列表。
## [br]
## @param p_metadata: 项目自定义元数据。
## [br]
## @param p_root_path: 内容包根目录。
## [br]
## @param p_source_path: manifest 文件路径。
## [br]
## @param p_safety_kind: 内容包安全分类。
## [br]
## @param p_forbidden_resource_extensions: 调用方额外禁止的资源扩展名。
## [br]
## @return 当前 manifest。
## [br]
## @schema p_resources: Array[Dictionary]，每项包含 key、path、可选 type_hint、priority 和 metadata。
## [br]
## @schema p_metadata: Dictionary project-defined content package metadata.
## [br]
## @schema p_forbidden_resource_extensions: PackedStringArray extension names without leading dots.
func configure(
	p_package_id: StringName,
	p_version: String,
	p_resources: Array[Dictionary] = [],
	p_display_name: String = "",
	p_content_types: PackedStringArray = PackedStringArray(),
	p_dependencies: PackedStringArray = PackedStringArray(),
	p_metadata: Dictionary = {},
	p_root_path: String = "",
	p_source_path: String = "",
	p_safety_kind: StringName = SAFETY_KIND_DATA_ONLY,
	p_forbidden_resource_extensions: PackedStringArray = PackedStringArray()
) -> GFContentPackageManifest:
	schema_version = SCHEMA_VERSION
	_schema_version_was_present = true
	_schema_version_has_valid_type = true
	_unknown_fields = PackedStringArray()
	_schema_issues.clear()
	package_id = p_package_id
	version = p_version.strip_edges()
	resources = _copy_resource_entries(p_resources)
	display_name = p_display_name.strip_edges()
	content_types = _normalize_string_list(p_content_types)
	dependencies = _normalize_string_list(p_dependencies)
	metadata = p_metadata.duplicate(true)
	root_path = _normalize_root_path(p_root_path)
	source_path = _normalize_resource_path(p_source_path, "")
	safety_kind = p_safety_kind
	forbidden_resource_extensions = _normalize_extensions(p_forbidden_resource_extensions)
	return self


## 从字典应用 manifest 字段。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param data: manifest 字典。
## [br]
## @param p_root_path: 内容包根目录。
## [br]
## @param p_source_path: manifest 文件路径。
## [br]
## @schema data: Dictionary，支持 package_id/id、display_name/name、version、content_types、dependencies、safety_kind、forbidden_resource_extensions、resources 和 metadata；字段类型必须与 manifest schema 一致，不执行字符串、数组或字典宽松转换。
func apply_dictionary(data: Dictionary, p_root_path: String = "", p_source_path: String = "") -> void:
	_reset_dictionary_fields()
	_apply_schema_version(data)
	_unknown_fields = _collect_unknown_fields(data)
	package_id = StringName(_read_text_alias(data, "package_id", "id"))
	display_name = _read_text_alias(data, "display_name", "name")
	version = _read_text_field(data, "version")
	content_types = _normalize_string_list(_read_string_list_field(data, "content_types"))
	dependencies = _normalize_string_list(_read_string_list_field(data, "dependencies"))
	var safety_kind_text: String = _read_text_field(data, "safety_kind", String(SAFETY_KIND_DATA_ONLY))
	safety_kind = StringName(safety_kind_text)
	forbidden_resource_extensions = _normalize_extensions(
		_read_string_list_field(data, "forbidden_resource_extensions")
	)
	resources = _get_resource_entries(data)
	metadata = _read_dictionary_field(data, "metadata")
	root_path = _normalize_root_path(p_root_path)
	source_path = _normalize_resource_path(p_source_path, "")


## 转换为内容包 manifest 字典。
## [br]
## @api public
## [br]
## @return manifest 字典副本。
## [br]
## @schema return: Dictionary，包含 schema_version、package_id、display_name、version、content_types、dependencies、resources 和 metadata。
func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"package_id": package_id,
		"display_name": display_name,
		"version": version,
		"content_types": content_types.duplicate(),
		"dependencies": dependencies.duplicate(),
		"safety_kind": safety_kind,
		"forbidden_resource_extensions": forbidden_resource_extensions.duplicate(),
		"resources": _copy_resource_entries(resources),
		"metadata": metadata.duplicate(true),
	}


## 转换为 JSON-safe 报告字典。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param options: 传给 GFReportValueCodec 的编码选项。
## [br]
## @return manifest 报告字典。
## [br]
## @schema options: Dictionary with GFReportValueCodec encoding options.
## [br]
## @schema return: JSON-safe Dictionary based on to_dictionary().
func to_report_dictionary(options: Dictionary = {}) -> Dictionary:
	return GFReportValueCodec.to_report_dictionary(to_dictionary(), options)


## 创建 manifest 深拷贝。
## [br]
## @api public
## [br]
## @return 新 manifest。
func duplicate_manifest() -> GFContentPackageManifest:
	var manifest: GFContentPackageManifest = GFContentPackageManifest.new()
	var _configured_manifest: GFContentPackageManifest = manifest.configure(
		package_id,
		version,
		resources,
		display_name,
		content_types,
		dependencies,
		metadata,
		root_path,
		source_path,
		safety_kind,
		forbidden_resource_extensions
	)
	manifest.schema_version = schema_version
	manifest._schema_version_was_present = _schema_version_was_present
	manifest._schema_version_has_valid_type = _schema_version_has_valid_type
	manifest._unknown_fields = _unknown_fields.duplicate()
	manifest._schema_issues = _copy_resource_entries(_schema_issues)
	return manifest


## 检查 manifest 是否有效。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param options: 校验选项。可启用文件存在性与传递依赖安全扫描。
## [br]
## @return 无 error issue 时返回 true。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
func is_valid(options: Dictionary = {}) -> bool:
	var report: Dictionary = get_validation_report(options)
	return GFVariantData.get_option_bool(report, "ok")


## 获取 manifest 校验报告。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param options: 校验选项。可启用文件存在性与传递依赖安全扫描。
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action、error_count、warning_count、issue_count、package_id、source_path 和 resource_count。
func get_validation_report(options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_validation_report()
	_append_schema_issues(report)
	_validate_unknown_fields(report)
	_validate_schema_version(report)
	_validate_required_fields(report)
	_validate_safety_kind(report)
	_validate_string_list(content_types, "content_types", _KIND_INVALID_CONTENT_TYPE, report)
	_validate_string_list(dependencies, "dependencies", _KIND_INVALID_DEPENDENCY, report)
	_validate_resources(options, report)
	return _finalize_validation_report(report)


## 获取校验错误文本列表。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param options: 校验选项。可启用文件存在性与传递依赖安全扫描。
## [br]
## @return 错误文本列表。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool、check_resource_dependencies: bool 和 dependency_options: Dictionary。
func get_validation_errors(options: Dictionary = {}) -> Array[String]:
	var result: Array[String] = []
	var report: Dictionary = get_validation_report(options)
	for issue_variant: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)
		if GFVariantData.get_option_string(issue, "severity") != "error":
			continue
		result.append(GFVariantData.get_option_string(issue, "message"))
	return result


## 获取归一化资源键映射。
## [br]
## @api public
## [br]
## @return 资源映射副本。
## [br]
## @schema return: Array[Dictionary]，每项包含 key、path、type_hint、priority、metadata 和 package_id。
func get_normalized_resources() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in resources:
		var resource_key: StringName = _get_resource_key(entry)
		var path: String = _get_normalized_entry_path(entry)
		result.append({
			"key": resource_key,
			"path": path,
			"type_hint": _get_resource_text_field(entry, "type_hint"),
			"priority": _get_resource_priority(entry),
			"metadata": _make_resource_metadata(entry),
			"package_id": package_id,
		})
	return result


## 获取 manifest 中声明的资源键列表。
## [br]
## @api public
## [br]
## @return 排序后的资源键列表。
func get_resource_keys() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for entry: Dictionary in resources:
		var resource_key: StringName = _get_resource_key(entry)
		if resource_key == &"":
			continue
		var _append_result: bool = result.append(String(resource_key))
	result.sort()
	return result


## 从字典创建 manifest。
## [br]
## @api public
## [br]
## @since 4.4.0
## [br]
## @param data: manifest 字典。
## [br]
## @param p_root_path: 内容包根目录。
## [br]
## @param p_source_path: manifest 文件路径。
## [br]
## @return 新 manifest。
## [br]
## @schema data: Dictionary，支持 package_id/id、display_name/name、version、content_types、dependencies、safety_kind、forbidden_resource_extensions、resources 和 metadata；字段类型必须与 manifest schema 一致。
static func from_dictionary(
	data: Dictionary,
	p_root_path: String = "",
	p_source_path: String = ""
) -> GFContentPackageManifest:
	var manifest: GFContentPackageManifest = GFContentPackageManifest.new()
	manifest.apply_dictionary(data, p_root_path, p_source_path)
	return manifest


## 从 JSON manifest 文件加载内容包。
## [br]
## @api public
## [br]
## @param path: manifest 文件路径。
## [br]
## @return 加载成功返回 manifest；解析失败返回 null。
static func load_from_path(path: String) -> GFContentPackageManifest:
	var normalized_path: String = _normalize_resource_path(path, "")
	var file: FileAccess = FileAccess.open(normalized_path, FileAccess.READ)
	if file == null:
		return null

	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		return null
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return null

	var root: String = normalized_path.get_base_dir()
	return GFContentPackageManifest.from_dictionary(GFVariantData.as_dictionary(parsed), root, normalized_path)


# --- 私有/辅助方法 ---

func _apply_schema_version(data: Dictionary) -> void:
	_schema_version_was_present = data.has("schema_version") or data.has(&"schema_version")
	_schema_version_has_valid_type = true
	schema_version = 0
	if not _schema_version_was_present:
		return

	var raw_version: Variant = GFVariantData.get_option_value(data, "schema_version")
	if raw_version is int:
		schema_version = raw_version
		return
	if raw_version is float:
		var float_version: float = raw_version
		if is_finite(float_version) and float_version == floorf(float_version):
			schema_version = int(float_version)
			return
	_schema_version_has_valid_type = false


func _validate_schema_version(report: Dictionary) -> void:
	if not _schema_version_was_present:
		_add_manifest_issue(
			report,
			_KIND_MISSING_SCHEMA_VERSION,
			&"schema_version",
			"schema_version is required",
			{
				"expected_value": SCHEMA_VERSION,
			}
		)
		return
	if not _schema_version_has_valid_type:
		_add_manifest_issue(
			report,
			_KIND_INVALID_SCHEMA_VERSION,
			&"schema_version",
			"schema_version must be an integer",
			{
				"actual_value": schema_version,
				"expected_value": SCHEMA_VERSION,
			}
		)
		return
	if schema_version != SCHEMA_VERSION:
		_add_manifest_issue(
			report,
			_KIND_UNSUPPORTED_SCHEMA_VERSION,
			&"schema_version",
			"schema_version is not supported",
			{
				"actual_value": schema_version,
				"expected_value": SCHEMA_VERSION,
			}
		)


func _validate_required_fields(report: Dictionary) -> void:
	if package_id == &"":
		_add_manifest_issue(
			report,
			_KIND_MISSING_PACKAGE_ID,
			&"package_id",
			"package_id is required",
			{
				"expected_value": "non-empty StringName",
			}
		)
	if version.strip_edges().is_empty():
		_add_manifest_issue(
			report,
			_KIND_MISSING_VERSION,
			&"version",
			"version is required",
			{
				"expected_value": "non-empty String",
			}
		)


func _validate_string_list(
	items: PackedStringArray,
	field_name: String,
	kind: String,
	report: Dictionary
) -> void:
	for index: int in range(items.size()):
		var item: String = items[index].strip_edges()
		if not item.is_empty():
			continue
		_add_manifest_issue(
			report,
			kind,
			StringName(field_name),
			"%s contains an empty value" % field_name,
			{
				"row_index": index,
				"actual_value": items[index],
				"expected_value": "non-empty String",
			}
		)


func _validate_resources(
	options: Dictionary,
	report: Dictionary
) -> void:
	var seen_keys: Dictionary = {}
	for index: int in range(resources.size()):
		var entry: Dictionary = resources[index]
		_validate_resource_entry_schema(entry, index, report)
		var resource_key: StringName = _get_resource_key(entry)
		if resource_key == &"":
			_add_resource_issue(
				report,
				_KIND_INVALID_RESOURCE_KEY,
				index,
				resource_key,
				"resource key is required",
				&"resources",
				{
					"expected_value": "non-empty key",
				}
			)
		elif seen_keys.has(resource_key):
			_add_resource_issue(
				report,
				_KIND_DUPLICATE_RESOURCE_KEY,
				index,
				resource_key,
				"resource key is duplicated",
				&"resources",
				{
					"actual_value": resource_key,
				}
			)
		else:
			seen_keys[resource_key] = true

		_validate_resource_path(entry, index, resource_key, options, report)


func _validate_resource_path(
	entry: Dictionary,
	index: int,
	resource_key: StringName,
	options: Dictionary,
	report: Dictionary
) -> void:
	var raw_path: String = _get_resource_path(entry)
	if raw_path.is_empty():
		_add_resource_issue(
			report,
			_KIND_INVALID_RESOURCE_PATH,
			index,
			resource_key,
			"resource path is required",
			&"resources",
			{
				"expected_value": "res://, user:// or package-relative path",
			}
		)
		return

	var normalized_path: String = _normalize_package_resource_path(raw_path, root_path)
	if normalized_path.is_empty() or not _is_supported_resource_path(normalized_path):
		_add_resource_issue(
			report,
			_KIND_RESOURCE_PATH_NOT_ALLOWED,
			index,
			resource_key,
			"resource path must be res://, user://, or package-relative",
			&"resources",
			{
				"actual_value": raw_path,
				"expected_value": "res://, user:// or package-relative path",
			}
		)
		return

	if not _is_path_inside_root(normalized_path, root_path):
		_add_resource_issue(
			report,
			_KIND_RESOURCE_PATH_OUTSIDE_PACKAGE,
			index,
			resource_key,
			"resource path must stay inside package root",
			&"resources",
			{
				"actual_value": normalized_path,
				"expected_value": root_path,
			}
		)
		return

	_validate_resource_safety(normalized_path, index, resource_key, report)
	if GFVariantData.get_option_bool(options, "check_resource_dependencies", false):
		_validate_resource_dependencies(normalized_path, index, resource_key, options, report)

	if (
		GFVariantData.get_option_bool(options, "check_resource_exists", false)
		and not _resource_path_exists(normalized_path, GFVariantData.get_option_string(entry, "type_hint"))
	):
		_add_resource_issue(
			report,
			_KIND_MISSING_RESOURCE_FILE,
			index,
			resource_key,
			"resource file does not exist",
			&"resources",
			{
				"actual_value": normalized_path,
			}
		)


func _validate_safety_kind(report: Dictionary) -> void:
	if safety_kind == SAFETY_KIND_DATA_ONLY or safety_kind == SAFETY_KIND_TRUSTED_DEVELOPER:
		return
	_add_manifest_issue(
		report,
		_KIND_INVALID_SAFETY_KIND,
		&"safety_kind",
		"safety_kind is not supported",
		{
			"actual_value": safety_kind,
			"expected_value": PackedStringArray([String(SAFETY_KIND_DATA_ONLY), String(SAFETY_KIND_TRUSTED_DEVELOPER)]),
		}
	)


func _validate_unknown_fields(report: Dictionary) -> void:
	for field_name: String in _unknown_fields:
		_add_manifest_issue(
			report,
			_KIND_UNKNOWN_FIELD,
			StringName(field_name),
			"manifest field is not supported",
			{
				"actual_value": field_name,
				"expected_value": _ALLOWED_FIELDS.duplicate(),
			}
		)


func _append_schema_issues(report: Dictionary) -> void:
	for issue: Dictionary in _schema_issues:
		var _issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			GFVariantData.get_option_string_name(issue, "kind", StringName(_KIND_INVALID_MANIFEST_FIELD_TYPE)),
			GFVariantData.get_option_string(issue, "message", "manifest schema value has an invalid type"),
			GFVariantData.get_option_dictionary(issue, "fields")
		)


func _validate_resource_entry_schema(entry: Dictionary, index: int, report: Dictionary) -> void:
	for key_value: Variant in entry.keys():
		var field_name: String = GFVariantData.to_text(key_value)
		if _ALLOWED_RESOURCE_FIELDS.has(field_name):
			continue
		_add_resource_issue(
			report,
			_KIND_UNKNOWN_FIELD,
			index,
			_get_resource_key(entry),
			"resource entry field is not supported",
			&"resources",
			{
				"path": "resources[%d].%s" % [index, field_name],
				"actual_value": field_name,
				"expected_value": _ALLOWED_RESOURCE_FIELDS.duplicate(),
			}
		)

	_validate_resource_text_field(entry, index, "key", "resource_key", report)
	_validate_resource_text_field(entry, index, "path", "resource_path", report)
	_validate_resource_text_field(entry, index, "type_hint", "", report)
	if _has_field(entry, "priority"):
		var priority_value: Variant = _get_field_value(entry, "priority")
		if not _is_integer_value(priority_value):
			_add_invalid_resource_field_type(report, index, _get_resource_key(entry), "priority", "integer", priority_value)
	if _has_field(entry, "metadata") and not _get_field_value(entry, "metadata") is Dictionary:
		_add_invalid_resource_field_type(
			report,
			index,
			_get_resource_key(entry),
			"metadata",
			"Dictionary",
			_get_field_value(entry, "metadata")
		)


func _validate_resource_text_field(
	entry: Dictionary,
	index: int,
	field_name: String,
	alias_name: String,
	report: Dictionary
) -> void:
	var selected_field: String = _select_field_name(entry, field_name, alias_name)
	if selected_field.is_empty():
		return
	var value: Variant = _get_field_value(entry, selected_field)
	if _is_text_value(value):
		return
	_add_invalid_resource_field_type(
		report,
		index,
		_get_resource_key(entry),
		selected_field,
		"String",
		value
	)


func _add_invalid_resource_field_type(
	report: Dictionary,
	index: int,
	resource_key: StringName,
	field_name: String,
	expected_type: String,
	actual_value: Variant
) -> void:
	_add_resource_issue(
		report,
		_KIND_INVALID_RESOURCE_FIELD_TYPE,
		index,
		resource_key,
		"resource entry field has an invalid type",
		&"resources",
		{
			"path": "resources[%d].%s" % [index, field_name],
			"expected_value": expected_type,
			"actual_value": type_string(typeof(actual_value)),
		}
	)


func _validate_resource_safety(
	normalized_path: String,
	index: int,
	resource_key: StringName,
	report: Dictionary
) -> void:
	var extension: String = _normalize_extension(normalized_path.get_extension())
	if extension.is_empty():
		return
	var forbidden_extensions: PackedStringArray = _get_effective_forbidden_extensions()
	if not forbidden_extensions.has(extension):
		return
	_add_resource_issue(
		report,
		_KIND_RESOURCE_EXTENSION_FORBIDDEN,
		index,
		resource_key,
		"resource extension is forbidden for this content package safety kind",
		&"resources",
		{
			"actual_value": normalized_path,
			"expected_value": "resource extension allowed by safety_kind",
			"extension": extension,
			"safety_kind": safety_kind,
		}
	)


func _validate_resource_dependencies(
	normalized_path: String,
	index: int,
	resource_key: StringName,
	options: Dictionary,
	report: Dictionary
) -> void:
	var dependency_options: Dictionary = GFVariantData.get_option_dictionary(options, "dependency_options")
	dependency_options["include_root"] = false
	var dependency_report: Dictionary = _GF_RESOURCE_REGISTRY_TOOLS.build_dependency_report(
		normalized_path,
		dependency_options
	)
	if not GFVariantData.get_option_bool(dependency_report, "ok", false):
		_add_resource_issue(
			report,
			_KIND_RESOURCE_DEPENDENCY_SCAN_FAILED,
			index,
			resource_key,
			"resource dependency closure could not be verified",
			&"resources",
			{
				"actual_value": normalized_path,
				"expected_value": "complete dependency report",
				"dependency_summary": GFVariantData.get_option_string(dependency_report, "summary"),
			}
		)

	var forbidden_extensions: PackedStringArray = _get_effective_forbidden_extensions()
	for dependency_value: Variant in GFVariantData.get_option_array(dependency_report, "paths"):
		var dependency_path: String = GFVariantData.to_text(dependency_value)
		var extension: String = _normalize_extension(dependency_path.get_extension())
		if extension.is_empty() or not forbidden_extensions.has(extension):
			continue
		_add_resource_issue(
			report,
			_KIND_RESOURCE_DEPENDENCY_EXTENSION_FORBIDDEN,
			index,
			resource_key,
			"resource dependency extension is forbidden for this content package safety kind",
			&"resources",
			{
				"path": "resources[%d].dependencies" % index,
				"actual_value": dependency_path,
				"expected_value": "dependency extension allowed by safety_kind",
				"extension": extension,
				"safety_kind": safety_kind,
			}
		)


func _add_resource_issue(
	report: Dictionary,
	kind: String,
	row_index: int,
	resource_key: StringName,
	message: String,
	field_name: StringName,
	context: Dictionary = {}
) -> void:
	var issue_context: Dictionary = {
		"source_path": source_path,
		"source": source_path,
		"row_index": row_index,
		"row_key": resource_key,
		"field": field_name,
		"path": "resources[%d].%s" % [row_index, String(field_name)],
	}
	var merged_context: Dictionary = GFVariantData.merge_dictionary(issue_context, context, true)
	var _issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		"error",
		StringName(kind),
		message,
		merged_context
	)


func _add_manifest_issue(
	report: Dictionary,
	kind: String,
	field_name: StringName,
	message: String,
	context: Dictionary = {}
) -> void:
	var issue_context: Dictionary = {
		"key": package_id,
		"source_path": source_path,
		"source": source_path,
		"field": field_name,
		"path": String(field_name),
	}
	var merged_context: Dictionary = GFVariantData.merge_dictionary(issue_context, context, true)
	var _issue: Dictionary = GFValidationReportDictionary.append_issue(
		report,
		"error",
		StringName(kind),
		message,
		merged_context
	)


func _make_validation_report() -> Dictionary:
	return {
		"subject": _REPORT_SUBJECT,
		"schema_version": schema_version,
		"package_id": package_id,
		"source_path": source_path,
		"resource_count": resources.size(),
		"issues": [],
	}


func _finalize_validation_report(report: Dictionary) -> Dictionary:
	return GFValidationReportDictionary.finalize_report(report, _REPORT_SUBJECT, {
		"fallback_action": "Review the first content package manifest issue.",
		"no_action": "Content package manifest is valid.",
	})


func _get_resource_entries(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _has_field(data, "resources"):
		return result
	var raw_entries_value: Variant = _get_field_value(data, "resources")
	if not raw_entries_value is Array:
		_append_schema_type_issue(
			_KIND_INVALID_MANIFEST_FIELD_TYPE,
			"resources",
			"Array",
			raw_entries_value
		)
		return result
	var raw_entries: Array = raw_entries_value
	for index: int in range(raw_entries.size()):
		var raw_entry: Variant = raw_entries[index]
		if not raw_entry is Dictionary:
			_append_schema_type_issue(
				_KIND_INVALID_RESOURCE_FIELD_TYPE,
				"resources[%d]" % index,
				"Dictionary",
				raw_entry
			)
			continue
		var entry_dictionary: Dictionary = raw_entry
		result.append(_parse_resource_entry(entry_dictionary, index))
	return result


func _parse_resource_entry(data: Dictionary, index: int) -> Dictionary:
	var result: Dictionary = {}
	for key_value: Variant in data.keys():
		var field_name: String = GFVariantData.to_text(key_value)
		if _ALLOWED_RESOURCE_FIELDS.has(field_name):
			continue
		_append_schema_issue(
			_KIND_UNKNOWN_FIELD,
			"resource entry field is not supported",
			{
				"field": StringName(field_name),
				"path": "resources[%d].%s" % [index, field_name],
				"actual_value": field_name,
				"expected_value": _ALLOWED_RESOURCE_FIELDS.duplicate(),
			}
		)

	var key_field: String = _select_field_name(data, "key", "resource_key")
	if not key_field.is_empty():
		result["key"] = _read_resource_text_value(data, key_field, index)
	var path_field: String = _select_field_name(data, "path", "resource_path")
	if not path_field.is_empty():
		result["path"] = _read_resource_text_value(data, path_field, index)
	if _has_field(data, "type_hint"):
		result["type_hint"] = _read_resource_text_value(data, "type_hint", index)
	if _has_field(data, "priority"):
		result["priority"] = _read_resource_integer_value(data, "priority", index)
	if _has_field(data, "metadata"):
		var raw_metadata: Variant = _get_field_value(data, "metadata")
		if raw_metadata is Dictionary:
			var metadata_dictionary: Dictionary = raw_metadata
			result["metadata"] = metadata_dictionary.duplicate(true)
		else:
			_append_schema_type_issue(
				_KIND_INVALID_RESOURCE_FIELD_TYPE,
				"resources[%d].metadata" % index,
				"Dictionary",
				raw_metadata
			)
			result["metadata"] = {}
	return result


func _read_resource_text_value(data: Dictionary, field_name: String, index: int) -> String:
	var value: Variant = _get_field_value(data, field_name)
	if _is_text_value(value):
		return _to_text_value(value).strip_edges()
	_append_schema_type_issue(
		_KIND_INVALID_RESOURCE_FIELD_TYPE,
		"resources[%d].%s" % [index, field_name],
		"String",
		value
	)
	return ""


func _read_resource_integer_value(data: Dictionary, field_name: String, index: int) -> int:
	var value: Variant = _get_field_value(data, field_name)
	if _is_integer_value(value):
		return _to_integer_value(value)
	_append_schema_type_issue(
		_KIND_INVALID_RESOURCE_FIELD_TYPE,
		"resources[%d].%s" % [index, field_name],
		"integer",
		value
	)
	return 0


func _reset_dictionary_fields() -> void:
	package_id = &""
	display_name = ""
	version = ""
	content_types = PackedStringArray()
	dependencies = PackedStringArray()
	safety_kind = SAFETY_KIND_DATA_ONLY
	forbidden_resource_extensions = PackedStringArray()
	resources.clear()
	metadata.clear()
	_schema_issues.clear()


func _read_text_alias(data: Dictionary, field_name: String, alias_name: String) -> String:
	var selected_field: String = _select_field_name(data, field_name, alias_name)
	if selected_field.is_empty():
		return ""
	return _read_text_field(data, selected_field)


func _read_text_field(data: Dictionary, field_name: String, default_value: String = "") -> String:
	if not _has_field(data, field_name):
		return default_value
	var value: Variant = _get_field_value(data, field_name)
	if _is_text_value(value):
		return _to_text_value(value).strip_edges()
	_append_schema_type_issue(_KIND_INVALID_MANIFEST_FIELD_TYPE, field_name, "String", value)
	return default_value


func _read_string_list_field(data: Dictionary, field_name: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not _has_field(data, field_name):
		return result
	var value: Variant = _get_field_value(data, field_name)
	if value is PackedStringArray:
		var packed_values: PackedStringArray = value
		return packed_values.duplicate()
	if not value is Array:
		_append_schema_type_issue(_KIND_INVALID_MANIFEST_FIELD_TYPE, field_name, "Array[String]", value)
		return result
	var values: Array = value
	for index: int in range(values.size()):
		var item: Variant = values[index]
		if _is_text_value(item):
			var _appended_item: bool = result.append(_to_text_value(item))
			continue
		_append_schema_type_issue(
			_KIND_INVALID_MANIFEST_FIELD_TYPE,
			"%s[%d]" % [field_name, index],
			"String",
			item
		)
	return result


func _read_dictionary_field(data: Dictionary, field_name: String) -> Dictionary:
	if not _has_field(data, field_name):
		return {}
	var value: Variant = _get_field_value(data, field_name)
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	_append_schema_type_issue(_KIND_INVALID_MANIFEST_FIELD_TYPE, field_name, "Dictionary", value)
	return {}


func _append_schema_type_issue(kind: String, path: String, expected_type: String, actual_value: Variant) -> void:
	_append_schema_issue(
		kind,
		"manifest schema value has an invalid type",
		{
			"field": StringName(path.get_file()),
			"path": path,
			"actual_value": type_string(typeof(actual_value)),
			"expected_value": expected_type,
		}
	)


func _append_schema_issue(kind: String, message: String, fields: Dictionary) -> void:
	_schema_issues.append({
		"kind": StringName(kind),
		"message": message,
		"fields": fields.duplicate(true),
	})


func _get_resource_key(entry: Dictionary) -> StringName:
	var field_name: String = _select_field_name(entry, "key", "resource_key")
	if field_name.is_empty():
		return &""
	var value: Variant = _get_field_value(entry, field_name)
	return StringName(_to_text_value(value).strip_edges()) if _is_text_value(value) else &""


func _get_resource_path(entry: Dictionary) -> String:
	var field_name: String = _select_field_name(entry, "path", "resource_path")
	if field_name.is_empty():
		return ""
	var value: Variant = _get_field_value(entry, field_name)
	return _to_text_value(value).strip_edges() if _is_text_value(value) else ""


func _get_normalized_entry_path(entry: Dictionary) -> String:
	return _normalize_package_resource_path(_get_resource_path(entry), root_path)


func _get_resource_text_field(entry: Dictionary, field_name: String) -> String:
	if not _has_field(entry, field_name):
		return ""
	var value: Variant = _get_field_value(entry, field_name)
	return _to_text_value(value).strip_edges() if _is_text_value(value) else ""


func _get_resource_priority(entry: Dictionary) -> int:
	if not _has_field(entry, "priority"):
		return 0
	var value: Variant = _get_field_value(entry, "priority")
	return _to_integer_value(value) if _is_integer_value(value) else 0


func _make_resource_metadata(entry: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	if _has_field(entry, "metadata"):
		var metadata_value: Variant = _get_field_value(entry, "metadata")
		if metadata_value is Dictionary:
			var metadata_dictionary: Dictionary = metadata_value
			result = metadata_dictionary.duplicate(true)
	result["package_id"] = package_id
	result["package_version"] = version
	result["content_types"] = content_types.duplicate()
	return result


static func _copy_resource_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		result.append(entry.duplicate(true))
	return result


static func _copy_packed_string_array(items: PackedStringArray) -> PackedStringArray:
	return items.duplicate()


static func _normalize_string_list(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items:
		var normalized: String = item.strip_edges()
		if result.has(normalized):
			continue
		var _append_result: bool = result.append(normalized)
	return result


func _get_effective_forbidden_extensions() -> PackedStringArray:
	var result: PackedStringArray = _normalize_extensions(forbidden_resource_extensions)
	if safety_kind == SAFETY_KIND_DATA_ONLY or safety_kind == &"":
		for extension: String in _DATA_ONLY_FORBIDDEN_EXTENSIONS:
			_append_unique_extension(result, extension)
	result.sort()
	return result


static func _normalize_extensions(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items:
		_append_unique_extension(result, item)
	result.sort()
	return result


static func _append_unique_extension(items: PackedStringArray, value: String) -> void:
	var extension: String = _normalize_extension(value)
	if extension.is_empty() or items.has(extension):
		return
	var _append_extension: bool = items.append(extension)


static func _normalize_extension(value: String) -> String:
	var extension: String = value.strip_edges().to_lower()
	while extension.begins_with("."):
		extension = extension.substr(1)
	return extension


static func _normalize_package_resource_path(path: String, package_root: String) -> String:
	var normalized_path: String = _normalize_resource_path(path, "")
	if normalized_path.is_empty():
		return ""
	if normalized_path.begins_with("res://"):
		return normalized_path
	if normalized_path.begins_with("user://") or normalized_path.contains(":"):
		return normalized_path

	var normalized_root: String = _normalize_root_path(package_root)
	if normalized_root.is_empty():
		return ""
	return _normalize_resource_path(normalized_root.path_join(normalized_path), "")


static func _normalize_resource_path(path: String, fallback: String) -> String:
	return _GF_PATH_TOOLS.normalize_resource_path(path, fallback)


static func _normalize_root_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_root_path(path)


static func _is_supported_resource_path(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("user://")


static func _is_path_inside_root(path: String, package_root: String) -> bool:
	var normalized_root: String = _normalize_root_path(package_root)
	if normalized_root.is_empty():
		return false
	return _GF_PATH_TOOLS.is_path_under_root(path, normalized_root, true, false)


static func _has_field(data: Dictionary, field_name: String) -> bool:
	return data.has(field_name) or data.has(StringName(field_name))


static func _get_field_value(data: Dictionary, field_name: String) -> Variant:
	if data.has(field_name):
		return data[field_name]
	var field_key: StringName = StringName(field_name)
	return data[field_key] if data.has(field_key) else null


static func _select_field_name(data: Dictionary, field_name: String, alias_name: String) -> String:
	if _has_field(data, field_name):
		return field_name
	if not alias_name.is_empty() and _has_field(data, alias_name):
		return alias_name
	return ""


static func _is_text_value(value: Variant) -> bool:
	return value is String or value is StringName


static func _to_text_value(value: Variant) -> String:
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return ""


static func _is_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var float_value: float = value
	return is_finite(float_value) and float_value == floorf(float_value)


static func _to_integer_value(value: Variant) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	return 0


static func _collect_unknown_fields(data: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in data.keys():
		var field_name: String = GFVariantData.to_text(key)
		if _ALLOWED_FIELDS.has(field_name):
			continue
		var _append_result: bool = result.append(field_name)
	result.sort()
	return result


static func _resource_path_exists(path: String, type_hint: String = "") -> bool:
	if ResourceLoader.exists(path, type_hint):
		return true
	return FileAccess.file_exists(path)
