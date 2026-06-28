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
## @param data: manifest 字典。
## [br]
## @param p_root_path: 内容包根目录。
## [br]
## @param p_source_path: manifest 文件路径。
## [br]
## @schema data: Dictionary，支持 package_id/id、display_name/name、version、content_types、dependencies、resources 和 metadata。
func apply_dictionary(data: Dictionary, p_root_path: String = "", p_source_path: String = "") -> void:
	_apply_schema_version(data)
	package_id = GFVariantData.get_option_string_name(
		data,
		"package_id",
		GFVariantData.get_option_string_name(data, "id", package_id)
	)
	display_name = GFVariantData.get_option_string(
		data,
		"display_name",
		GFVariantData.get_option_string(data, "name", display_name)
	).strip_edges()
	version = GFVariantData.get_option_string(data, "version", version).strip_edges()
	content_types = _normalize_string_list(GFVariantData.get_option_packed_string_array(data, "content_types", content_types))
	dependencies = _normalize_string_list(GFVariantData.get_option_packed_string_array(data, "dependencies", dependencies))
	safety_kind = GFVariantData.get_option_string_name(data, "safety_kind", safety_kind)
	forbidden_resource_extensions = _normalize_extensions(
		GFVariantData.get_option_packed_string_array(data, "forbidden_resource_extensions", forbidden_resource_extensions)
	)
	resources = _copy_resource_entries(_get_resource_entries(data))
	metadata = GFVariantData.get_option_dictionary(data, "metadata", metadata)
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
	return manifest


## 检查 manifest 是否有效。
## [br]
## @api public
## [br]
## @param options: 校验选项。`check_resource_exists` 默认为 false。
## [br]
## @return 无 error issue 时返回 true。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool。
func is_valid(options: Dictionary = {}) -> bool:
	var report: Dictionary = get_validation_report(options)
	return GFVariantData.get_option_bool(report, "ok")


## 获取 manifest 校验报告。
## [br]
## @api public
## [br]
## @param options: 校验选项。`check_resource_exists` 默认为 false。
## [br]
## @return GFValidationReportDictionary 兼容报告。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool。
## [br]
## @schema return: GFValidationReportDictionary.finalize_report() 生成的 Dictionary，包含 ok、healthy、summary、issues、next_action、error_count、warning_count、issue_count、package_id、source_path 和 resource_count。
func get_validation_report(options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_validation_report()
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
## @param options: 校验选项。`check_resource_exists` 默认为 false。
## [br]
## @return 错误文本列表。
## [br]
## @schema options: Dictionary，可包含 check_resource_exists: bool。
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
			"type_hint": GFVariantData.get_option_string(entry, "type_hint"),
			"priority": GFVariantData.get_option_int(entry, "priority"),
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
## @param data: manifest 字典。
## [br]
## @param p_root_path: 内容包根目录。
## [br]
## @param p_source_path: manifest 文件路径。
## [br]
## @return 新 manifest。
## [br]
## @schema data: Dictionary，支持 package_id/id、display_name/name、version、content_types、dependencies、resources 和 metadata。
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
		if is_equal_approx(float_version, floorf(float_version)):
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

	if (
		GFVariantData.get_option_bool(options, "check_resource_exists", false)
		and not ResourceLoader.exists(normalized_path, GFVariantData.get_option_string(entry, "type_hint"))
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
	var raw_entries: Array = GFVariantData.get_option_array(data, "resources")
	for raw_entry: Variant in raw_entries:
		if raw_entry is Dictionary:
			var entry: Dictionary = raw_entry
			result.append(entry.duplicate(true))
		else:
			result.append({})
	return result


func _get_resource_key(entry: Dictionary) -> StringName:
	return GFVariantData.get_option_string_name(
		entry,
		"key",
		GFVariantData.get_option_string_name(entry, "resource_key")
	)


func _get_resource_path(entry: Dictionary) -> String:
	return GFVariantData.get_option_string(
		entry,
		"path",
		GFVariantData.get_option_string(entry, "resource_path")
	).strip_edges()


func _get_normalized_entry_path(entry: Dictionary) -> String:
	return _normalize_package_resource_path(_get_resource_path(entry), root_path)


func _make_resource_metadata(entry: Dictionary) -> Dictionary:
	var result: Dictionary = GFVariantData.get_option_dictionary(entry, "metadata")
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
	return _GF_PATH_TOOLS.is_path_under_root(path, normalized_root, true, true)
