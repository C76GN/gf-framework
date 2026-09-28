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

## 提供资源路径与根目录的归一化及边界检查。
## [br]
## @api private
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## 为安全校验构建资源依赖报告的工具脚本。
## [br]
## @api private
const _GF_RESOURCE_REGISTRY_TOOLS = preload("res://addons/gf/standard/utilities/assets/gf_resource_registry_tools.gd")

## 内容包 JSON manifest 默认文件名。
## [br]
## @api public
const FILE_NAME: String = "gf_content_package.json"

## 当前 manifest schema 版本。
## [br]
## @api public
const SCHEMA_VERSION: int = 1


## 校验报告中用于 finalize 的固定主题。
## [br]
## @api private
const _REPORT_SUBJECT: String = "Content package manifest"

## 缺少必填内容包 ID 时使用的问题类型。
## [br]
## @api private
const _KIND_MISSING_PACKAGE_ID: String = "missing_package_id"

## 缺少必填版本字符串时使用的问题类型。
## [br]
## @api private
const _KIND_MISSING_VERSION: String = "missing_version"

## manifest 未提供 schema_version 时使用的问题类型。
## [br]
## @api private
const _KIND_MISSING_SCHEMA_VERSION: String = "missing_schema_version"

## schema_version 不是整数值时使用的问题类型。
## [br]
## @api private
const _KIND_INVALID_SCHEMA_VERSION: String = "invalid_schema_version"

## schema_version 与当前支持版本不一致时使用的问题类型。
## [br]
## @api private
const _KIND_UNSUPPORTED_SCHEMA_VERSION: String = "unsupported_schema_version"

## content_types 含空值时使用的问题类型。
## [br]
## @api private
const _KIND_INVALID_CONTENT_TYPE: String = "invalid_content_type"

## dependencies 含空值时使用的问题类型。
## [br]
## @api private
const _KIND_INVALID_DEPENDENCY: String = "invalid_dependency"

## 资源条目结构不合法时使用的问题类型。
## [br]
## @api private
const _KIND_INVALID_RESOURCE_ENTRY: String = "invalid_resource_entry"

## 资源键缺失或为空时使用的问题类型。
## [br]
## @api private
const _KIND_INVALID_RESOURCE_KEY: String = "invalid_resource_key"

## 同一 manifest 中的资源键重复时使用的问题类型。
## [br]
## @api private
const _KIND_DUPLICATE_RESOURCE_KEY: String = "duplicate_resource_key"

## 资源路径缺失或为空时使用的问题类型。
## [br]
## @api private
const _KIND_INVALID_RESOURCE_PATH: String = "invalid_resource_path"

## 资源路径无法归一化为允许的路径形式时使用的问题类型。
## [br]
## @api private
const _KIND_RESOURCE_PATH_NOT_ALLOWED: String = "resource_path_not_allowed"

## 归一化后的资源路径越出内容包根目录时使用的问题类型。
## [br]
## @api private
const _KIND_RESOURCE_PATH_OUTSIDE_PACKAGE: String = "resource_path_outside_package"

## 资源扩展名被安全策略禁止时使用的问题类型。
## [br]
## @api private
const _KIND_RESOURCE_EXTENSION_FORBIDDEN: String = "resource_extension_forbidden"

## 启用存在性检查但找不到资源文件时使用的问题类型。
## [br]
## @api private
const _KIND_MISSING_RESOURCE_FILE: String = "missing_resource_file"

## safety_kind 不属于支持值时使用的问题类型。
## [br]
## @api private
const _KIND_INVALID_SAFETY_KIND: String = "invalid_safety_kind"

## manifest 含不在白名单中的字段时使用的问题类型。
## [br]
## @api private
const _KIND_UNKNOWN_FIELD: String = "unknown_field"

## 兼容别名与规范字段值冲突时使用的问题类型。
## [br]
## @api private
const _KIND_CONFLICTING_ALIAS_FIELDS: String = "conflicting_alias_fields"

## manifest 字段类型与 schema 不符时使用的问题类型。
## [br]
## @api private
const _KIND_INVALID_MANIFEST_FIELD_TYPE: String = "invalid_manifest_field_type"

## 资源条目字段类型与 schema 不符时使用的问题类型。
## [br]
## @api private
const _KIND_INVALID_RESOURCE_FIELD_TYPE: String = "invalid_resource_field_type"

## 资源的传递依赖含安全策略禁止扩展名时使用的问题类型。
## [br]
## @api private
const _KIND_RESOURCE_DEPENDENCY_EXTENSION_FORBIDDEN: String = "resource_dependency_extension_forbidden"

## 资源依赖扫描未能生成可验证报告时使用的问题类型。
## [br]
## @api private
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

## data_only 安全分类始终拒绝的可执行或代码资源扩展名。
## [br]
## @api private
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

## manifest 根字典可识别的字段名及其兼容别名。
## [br]
## @api private
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

## 资源映射字典可识别的字段名及其兼容别名。
## [br]
## @api private
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

## 记录输入字典是否显式包含 schema_version。
## [br]
## @api private
var _schema_version_was_present: bool = true

## 记录 schema_version 是否为整数或无小数部分的有限浮点数。
## [br]
## @api private
var _schema_version_has_valid_type: bool = true

## 暂存输入 manifest 中未被字段白名单接纳的键名。
## [br]
## @api private
var _unknown_fields: PackedStringArray = PackedStringArray()

## 暂存字典解析期间收集的结构和字段类型问题。
## [br]
## @api private
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
	_validate_manifest_aliases(data)
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

## 从字典读取 schema_version，并分别记录字段是否存在及其值类型是否可接受。
## [br]
## @api private
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


## 将 schema_version 缺失、类型无效或版本不支持的情况写入报告。
## [br]
## @api private
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


## 检查 package_id 与去除首尾空白后的 version 是否为空。
## [br]
## @api private
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


## 将字符串列表中的空白项逐项报告，保留其原始值和索引。
## [br]
## @api private
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


## 校验每个资源条目的结构、资源键唯一性及路径相关约束。
## [br]
## @api private
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


## 归一化单个资源路径并检查路径范围、安全扩展名及可选依赖和存在性。
## [br]
## @api private
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


## 仅接受 data_only 和 trusted_developer 两种安全分类。
## [br]
## @api private
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


## 把解析阶段收集的未知 manifest 字段逐项追加为校验问题。
## [br]
## @api private
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


## 将字典解析阶段暂存的结构问题转成 validation report 条目。
## [br]
## @api private
func _append_schema_issues(report: Dictionary) -> void:
	for issue: Dictionary in _schema_issues:
		var _issue: Dictionary = GFValidationReportDictionary.append_issue(
			report,
			"error",
			GFVariantData.get_option_string_name(issue, "kind", StringName(_KIND_INVALID_MANIFEST_FIELD_TYPE)),
			GFVariantData.get_option_string(issue, "message", "manifest schema value has an invalid type"),
			GFVariantData.get_option_dictionary(issue, "fields")
		)


## 检查资源条目的未知字段、文本字段类型、priority 和 metadata 类型。
## [br]
## @api private
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


## 对资源条目中存在的文本字段及其兼容别名校验 String/StringName 类型。
## [br]
## @api private
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


## 为类型错误的资源字段构造带行号、字段路径和预期类型的问题。
## [br]
## @api private
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


## 按有效禁止扩展名列表检查归一化资源路径的后缀。
## [br]
## @api private
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


## 扫描资源依赖闭包；报告扫描失败并检查依赖文件的禁止扩展名。
## [br]
## @api private
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


## 为资源行问题合并来源、行索引、资源键等上下文后追加报告项。
## [br]
## @api private
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


## 为 manifest 级问题合并包 ID 和来源路径等上下文后追加报告项。
## [br]
## @api private
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


## 初始化含主题、版本、包身份和空 issues 列表的校验报告字典。
## [br]
## @api private
func _make_validation_report() -> Dictionary:
	return {
		"subject": _REPORT_SUBJECT,
		"schema_version": schema_version,
		"package_id": package_id,
		"source_path": source_path,
		"resource_count": resources.size(),
		"issues": [],
	}


## 使用内容包专属的成功与失败行动文本完成报告汇总。
## [br]
## @api private
func _finalize_validation_report(report: Dictionary) -> Dictionary:
	return GFValidationReportDictionary.finalize_report(report, _REPORT_SUBJECT, {
		"fallback_action": "Review the first content package manifest issue.",
		"no_action": "Content package manifest is valid.",
	})


## 从输入字典读取 resources，并跳过类型错误的条目、记录对应 schema 问题。
## [br]
## @api private
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


## 校验并归一化一个资源条目，保留可识别字段并复制 metadata。
## [br]
## @api private
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

	_validate_resource_aliases(data, index)
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


## 读取资源文本字段并去除首尾空白；类型错误时记问题并返回空字符串。
## [br]
## @api private
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


## 读取资源整数值字段；无效类型记问题并以 0 作为回退值。
## [br]
## @api private
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


## 清空从字典载入的业务字段和暂存 schema 问题，为下一次解析复位状态。
## [br]
## @api private
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


## 校验根字典中的 package_id/id 与 display_name/name 别名对。
## [br]
## @api private
func _validate_manifest_aliases(data: Dictionary) -> void:
	_validate_text_alias_pair(data, "package_id", "id", "", -1)
	_validate_text_alias_pair(data, "display_name", "name", "", -1)


## 校验资源行中的 key/resource_key 与 path/resource_path 别名对。
## [br]
## @api private
func _validate_resource_aliases(data: Dictionary, index: int) -> void:
	_validate_text_alias_pair(data, "key", "resource_key", "resources", index)
	_validate_text_alias_pair(data, "path", "resource_path", "resources", index)


## 两个别名同时出现时检查值类型和内容一致性，并保留冲突字段路径。
## [br]
## @api private
func _validate_text_alias_pair(
	data: Dictionary,
	canonical_name: String,
	alias_name: String,
	collection_path: String,
	row_index: int
) -> void:
	if not _has_field(data, canonical_name) or not _has_field(data, alias_name):
		return
	var canonical_value: Variant = _get_field_value(data, canonical_name)
	var alias_value: Variant = _get_field_value(data, alias_name)
	var alias_path: String = alias_name
	if row_index >= 0:
		alias_path = "%s[%d].%s" % [collection_path, row_index, alias_name]
	if not _is_text_value(alias_value):
		_append_schema_type_issue(
			_KIND_INVALID_RESOURCE_FIELD_TYPE if row_index >= 0 else _KIND_INVALID_MANIFEST_FIELD_TYPE,
			alias_path,
			"String",
			alias_value
		)
		return
	if not _is_text_value(canonical_value):
		return
	var canonical_text: String = _to_text_value(canonical_value).strip_edges()
	var alias_text: String = _to_text_value(alias_value).strip_edges()
	if canonical_text == alias_text:
		return
	var canonical_path: String = canonical_name
	if row_index >= 0:
		canonical_path = "%s[%d].%s" % [collection_path, row_index, canonical_name]
	var conflicting_values: Dictionary = {}
	conflicting_values[canonical_name] = canonical_text
	conflicting_values[alias_name] = alias_text
	_append_schema_issue(
		_KIND_CONFLICTING_ALIAS_FIELDS,
		"canonical field and compatibility alias have conflicting values",
		{
			"field": StringName(canonical_name),
			"path": canonical_path,
			"row_index": row_index,
			"alias_field": StringName(alias_name),
			"alias_path": alias_path,
			"actual_value": conflicting_values,
			"expected_value": "matching canonical and alias values",
		}
	)


## 优先读取规范字段，规范字段缺失时回退到别名；两者都缺失则返回空串。
## [br]
## @api private
func _read_text_alias(data: Dictionary, field_name: String, alias_name: String) -> String:
	var selected_field: String = _select_field_name(data, field_name, alias_name)
	if selected_field.is_empty():
		return ""
	return _read_text_field(data, selected_field)


## 读取 String/StringName 字段并裁去首尾空白；类型错误时记问题并返回默认值。
## [br]
## @api private
func _read_text_field(data: Dictionary, field_name: String, default_value: String = "") -> String:
	if not _has_field(data, field_name):
		return default_value
	var value: Variant = _get_field_value(data, field_name)
	if _is_text_value(value):
		return _to_text_value(value).strip_edges()
	_append_schema_type_issue(_KIND_INVALID_MANIFEST_FIELD_TYPE, field_name, "String", value)
	return default_value


## 接受 PackedStringArray 或字符串数组，转换可读项并记录非文本项的问题。
## [br]
## @api private
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


## 读取并深复制 Dictionary 字段；缺失或类型错误时返回空字典。
## [br]
## @api private
func _read_dictionary_field(data: Dictionary, field_name: String) -> Dictionary:
	if not _has_field(data, field_name):
		return {}
	var value: Variant = _get_field_value(data, field_name)
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		return dictionary_value.duplicate(true)
	_append_schema_type_issue(_KIND_INVALID_MANIFEST_FIELD_TYPE, field_name, "Dictionary", value)
	return {}


## 按字段路径和实际 Variant 类型记录 schema 类型错误。
## [br]
## @api private
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


## 将 kind、message 与字段上下文深复制后暂存为解析阶段问题。
## [br]
## @api private
func _append_schema_issue(kind: String, message: String, fields: Dictionary) -> void:
	_schema_issues.append({
		"kind": StringName(kind),
		"message": message,
		"fields": fields.duplicate(true),
	})


## 按 key 优先、resource_key 次之读取资源键；无文本值时返回空 StringName。
## [br]
## @api private
func _get_resource_key(entry: Dictionary) -> StringName:
	var field_name: String = _select_field_name(entry, "key", "resource_key")
	if field_name.is_empty():
		return &""
	var value: Variant = _get_field_value(entry, field_name)
	return StringName(_to_text_value(value).strip_edges()) if _is_text_value(value) else &""


## 按 path 优先、resource_path 次之读取已去除首尾空白的路径文本。
## [br]
## @api private
func _get_resource_path(entry: Dictionary) -> String:
	var field_name: String = _select_field_name(entry, "path", "resource_path")
	if field_name.is_empty():
		return ""
	var value: Variant = _get_field_value(entry, field_name)
	return _to_text_value(value).strip_edges() if _is_text_value(value) else ""


## 使用当前 root_path 归一化资源条目的路径。
## [br]
## @api private
func _get_normalized_entry_path(entry: Dictionary) -> String:
	return _normalize_package_resource_path(_get_resource_path(entry), root_path)


## 获取资源条目的文本字段；缺失或不是 String/StringName 时返回空串。
## [br]
## @api private
func _get_resource_text_field(entry: Dictionary, field_name: String) -> String:
	if not _has_field(entry, field_name):
		return ""
	var value: Variant = _get_field_value(entry, field_name)
	return _to_text_value(value).strip_edges() if _is_text_value(value) else ""


## 获取资源优先级；字段缺失或不是整数值时回退为 0。
## [br]
## @api private
func _get_resource_priority(entry: Dictionary) -> int:
	if not _has_field(entry, "priority"):
		return 0
	var value: Variant = _get_field_value(entry, "priority")
	return _to_integer_value(value) if _is_integer_value(value) else 0


## 复制资源 metadata，并写入 package_id、package_version 与 content_types。
## [br]
## @api private
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


## 逐项递归复制资源字典，避免结果沿用输入条目的嵌套容器。
## [br]
## @api private
static func _copy_resource_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		result.append(entry.duplicate(true))
	return result


## 复制 PackedStringArray，供调用方隔离可变数组存储。
## [br]
## @api private
static func _copy_packed_string_array(items: PackedStringArray) -> PackedStringArray:
	return items.duplicate()


## 去除各字符串首尾空白并按首次出现顺序移除重复项。
## [br]
## @api private
static func _normalize_string_list(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items:
		var normalized: String = item.strip_edges()
		if result.has(normalized):
			continue
		var _append_result: bool = result.append(normalized)
	return result


## 合并调用方禁用项与 data_only 默认禁用项，并排序返回。
## [br]
## @api private
func _get_effective_forbidden_extensions() -> PackedStringArray:
	var result: PackedStringArray = _normalize_extensions(forbidden_resource_extensions)
	if safety_kind == SAFETY_KIND_DATA_ONLY or safety_kind == &"":
		for extension: String in _DATA_ONLY_FORBIDDEN_EXTENSIONS:
			_append_unique_extension(result, extension)
	result.sort()
	return result


## 归一化扩展名、移除空值与重复值，最后按字典序排序。
## [br]
## @api private
static func _normalize_extensions(items: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for item: String in items:
		_append_unique_extension(result, item)
	result.sort()
	return result


## 归一化单个扩展名，仅在非空且尚未存在时追加到数组。
## [br]
## @api private
static func _append_unique_extension(items: PackedStringArray, value: String) -> void:
	var extension: String = _normalize_extension(value)
	if extension.is_empty() or items.has(extension):
		return
	var _append_extension: bool = items.append(extension)


## 去除首尾空白、转为小写并剥除所有前导点号。
## [br]
## @api private
static func _normalize_extension(value: String) -> String:
	var extension: String = value.strip_edges().to_lower()
	while extension.begins_with("."):
		extension = extension.substr(1)
	return extension


## 先归一路径；相对路径以包根目录拼接，根目录无效时返回空串。
## [br]
## @api private
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


## 将资源路径归一化工作委托给路径工具，并透传回退路径。
## [br]
## @api private
static func _normalize_resource_path(path: String, fallback: String) -> String:
	return _GF_PATH_TOOLS.normalize_resource_path(path, fallback)


## 使用路径工具归一化内容包根目录。
## [br]
## @api private
static func _normalize_root_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_root_path(path)


## 判断归一化路径是否以 res:// 或 user:// 开头。
## [br]
## @api private
static func _is_supported_resource_path(path: String) -> bool:
	return path.begins_with("res://") or path.begins_with("user://")


## 归一化包根目录后，将路径边界判断委托给路径工具。
## [br]
## @api private
static func _is_path_inside_root(path: String, package_root: String) -> bool:
	var normalized_root: String = _normalize_root_path(package_root)
	if normalized_root.is_empty():
		return false
	return _GF_PATH_TOOLS.is_path_under_root(path, normalized_root, true, false)


## 同时检查 String 与 StringName 键形式的字段是否存在。
## [br]
## @api private
static func _has_field(data: Dictionary, field_name: String) -> bool:
	return data.has(field_name) or data.has(StringName(field_name))


## 优先读取 String 键，其次读取同名 StringName 键；都不存在则返回 null。
## [br]
## @api private
static func _get_field_value(data: Dictionary, field_name: String) -> Variant:
	if data.has(field_name):
		return data[field_name]
	var field_key: StringName = StringName(field_name)
	return data[field_key] if data.has(field_key) else null


## 选择已存在的规范键，若无则选非空且存在的兼容别名。
## [br]
## @api private
static func _select_field_name(data: Dictionary, field_name: String, alias_name: String) -> String:
	if _has_field(data, field_name):
		return field_name
	if not alias_name.is_empty() and _has_field(data, alias_name):
		return alias_name
	return ""


## 仅把 String 与 StringName 判定为可接受文本值。
## [br]
## @api private
static func _is_text_value(value: Variant) -> bool:
	return value is String or value is StringName


## 将 StringName 转成 String，保留 String 原值，其余类型转为空串。
## [br]
## @api private
static func _to_text_value(value: Variant) -> String:
	if value is String:
		var string_value: String = value
		return string_value
	if value is StringName:
		var string_name_value: StringName = value
		return String(string_name_value)
	return ""


## 接受 int 或有限且没有小数部分的 float。
## [br]
## @api private
static func _is_integer_value(value: Variant) -> bool:
	if value is int:
		return true
	if not value is float:
		return false
	var float_value: float = value
	return is_finite(float_value) and float_value == floorf(float_value)


## 将 int 原样返回、float 转为 int，其他 Variant 回退为 0。
## [br]
## @api private
static func _to_integer_value(value: Variant) -> int:
	if value is int:
		var int_value: int = value
		return int_value
	if value is float:
		var float_value: float = value
		return int(float_value)
	return 0


## 收集不在根字段白名单中的键名，转换为文本并排序。
## [br]
## @api private
static func _collect_unknown_fields(data: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in data.keys():
		var field_name: String = GFVariantData.to_text(key)
		if _ALLOWED_FIELDS.has(field_name):
			continue
		var _append_result: bool = result.append(field_name)
	result.sort()
	return result


## 先按 type_hint 查询 ResourceLoader，再回退检查文件系统路径。
## [br]
## @api private
static func _resource_path_exists(path: String, type_hint: String = "") -> bool:
	if ResourceLoader.exists(path, type_hint):
		return true
	return FileAccess.file_exists(path)
