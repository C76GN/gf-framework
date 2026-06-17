## GFConfigResourcePathValidationRule: Godot 资源路径校验规则。
##
## 用于检查配置字段中的 `res://` 或 `uid://` 路径是否存在，并可按扩展名限制资源类型。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 3.17.0
class_name GFConfigResourcePathValidationRule
extends GFConfigValidationRule


# --- 导出变量 ---

## 空字符串是否直接视为通过。
## [br]
## @api public
@export var allow_empty: bool = true

## 是否要求路径以 res:// 或 uid:// 开头。
## [br]
## @api public
## [br]
## @since 3.17.0
@export var require_resource_prefix: bool = true

## 是否允许 uid:// 资源路径。启用后，扩展名校验会使用 UID 解析出的实际资源路径。
## [br]
## @api public
## [br]
## @since 5.1.0
@export var allow_uid_paths: bool = true

## 允许的扩展名。为空时不限制扩展名，可写 png 或 .png。
## [br]
## @api public
@export var allowed_extensions: PackedStringArray = PackedStringArray()

## 是否使用 ResourceLoader.exists() 检查导入资源。
## [br]
## @api public
@export var use_resource_loader: bool = true

## ResourceLoader 检查失败时是否再用 FileAccess.file_exists() 检查原始文件。
## [br]
## @api public
@export var use_file_access_fallback: bool = true


# --- 公共方法 ---

## 导出规则摘要。
## [br]
## @api public
## [br]
## @return 规则摘要字典。
## [br]
## @schema return: Dictionary，包含基础规则字段和资源路径校验设置。
func describe() -> Dictionary:
	var result: Dictionary = super.describe()
	result["allow_empty"] = allow_empty
	result["require_resource_prefix"] = require_resource_prefix
	result["allow_uid_paths"] = allow_uid_paths
	result["allowed_extensions"] = allowed_extensions.duplicate()
	result["use_resource_loader"] = use_resource_loader
	result["use_file_access_fallback"] = use_file_access_fallback
	return result


# --- 可重写钩子 / 虚方法 ---

## 返回资源路径规则的默认稳定标识。
## [br]
## @api protected
## [br]
## @return 默认规则标识。
func _get_default_rule_id() -> StringName:
	return &"resource_path"


## 校验单个字段值是否是存在且扩展名允许的资源路径。
## [br]
## @api protected
## [br]
## @param value: 待校验值。
## [br]
## @param context: 校验上下文。
## [br]
## @param report: 当前校验报告。
## [br]
## @schema value: Variant，期望为 String 或 StringName 资源路径。
## [br]
## @schema context: Dictionary，可包含 table_name、row_key、field、source、line 和 column 字段。
## [br]
## @schema report: GFConfigValidationReport 兼容 Dictionary，会被当前规则修改。
func _validate_value(value: Variant, context: Dictionary, report: Dictionary) -> void:
	if typeof(value) != TYPE_STRING and typeof(value) != TYPE_STRING_NAME:
		_add_issue(report, _make_issue_context(context, value, "String or StringName"), "resource_path_invalid_type", "资源路径校验只支持 String 或 StringName。")
		return

	var path: String = GFVariantData.to_text(value).strip_edges()
	if path.is_empty() and allow_empty:
		return
	if require_resource_prefix and not _has_allowed_resource_prefix(path):
		_add_issue(report, _make_issue_context(context, value, _describe_allowed_prefixes()), "resource_path_invalid_prefix", "资源路径前缀不在允许范围内。")
		return
	if not _extension_allowed(path):
		_add_issue(report, _make_issue_context(context, value, _describe_allowed_extensions()), "resource_path_extension_not_allowed", "资源路径扩展名不在允许范围内。")
		return
	if not _path_exists(path):
		_add_issue(report, _make_issue_context(context, value, "existing resource path"), "resource_path_missing", "资源路径不存在：%s。" % path)


# --- 私有/辅助方法 ---

func _extension_allowed(path: String) -> bool:
	if allowed_extensions.is_empty():
		return true

	var extension_source_path: String = _resolve_extension_source_path(path)
	if extension_source_path.is_empty():
		return false

	var extension: String = extension_source_path.get_extension().to_lower()
	for allowed_extension: String in allowed_extensions:
		var normalized: String = allowed_extension.strip_edges().trim_prefix(".").to_lower()
		if normalized == extension:
			return true
	return false


func _path_exists(path: String) -> bool:
	if use_resource_loader and ResourceLoader.exists(path):
		return true
	if use_file_access_fallback and path.begins_with("res://") and FileAccess.file_exists(path):
		return true
	return false


func _has_allowed_resource_prefix(path: String) -> bool:
	if path.begins_with("res://"):
		return true
	return allow_uid_paths and path.begins_with("uid://")


func _resolve_extension_source_path(path: String) -> String:
	if not path.begins_with("uid://"):
		return path
	if not allow_uid_paths:
		return ""

	var uid: int = ResourceUID.text_to_id(path)
	if uid == ResourceUID.INVALID_ID or not ResourceUID.has_id(uid):
		return ""
	return ResourceUID.get_id_path(uid)


func _make_issue_context(context: Dictionary, value: Variant, expected_value: Variant) -> Dictionary:
	var issue_context: Dictionary = context.duplicate(true)
	issue_context["value"] = GFVariantData.duplicate_variant(value)
	issue_context["actual_value"] = GFVariantData.duplicate_variant(value)
	issue_context["expected_value"] = GFVariantData.duplicate_variant(expected_value)
	issue_context["supported_formats"] = _describe_supported_formats()
	return issue_context


func _describe_allowed_extensions() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for allowed_extension: String in allowed_extensions:
		var normalized: String = allowed_extension.strip_edges().trim_prefix(".").to_lower()
		if not normalized.is_empty():
			var _appended: bool = result.append(normalized)
	return result


func _describe_supported_formats() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for prefix: String in _describe_allowed_prefixes():
		var _prefix_appended: bool = result.append(prefix)
	for allowed_extension: String in _describe_allowed_extensions():
		var _extension_appended: bool = result.append(".%s" % allowed_extension)
	return result


func _describe_allowed_prefixes() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if require_resource_prefix:
		var _res_prefix_appended: bool = result.append("res://")
		if allow_uid_paths:
			var _uid_prefix_appended: bool = result.append("uid://")
	return result
