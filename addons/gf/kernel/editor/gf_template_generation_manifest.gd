@tool

## GFTemplateGenerationManifest: 代码生成模板清单辅助。
##
## 用普通字典描述模板 ID、模板路径、输出路径、变量、要求和产物所有权，并可从 JSON
## sidecar 读取。它不绑定具体模板引擎，也不规定项目目录结构，只为生成器提供稳定、
## 可校验、可汇总并可接入 GFGeneratedArtifactReport 的计划格式。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 6.0.0
## [br]
## @layer kernel/editor
class_name GFTemplateGenerationManifest
extends RefCounted


# --- 常量 ---

## 清单有效。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_READY: StringName = &"ready"

## 清单缺少必要字段。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_INVALID: StringName = &"invalid"

## 清单 JSON 无法解析。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_PARSE_FAILED: StringName = &"parse_failed"

## 清单文件无法读取。
## [br]
## @api public
## [br]
## @since 6.0.0
const STATUS_LOAD_FAILED: StringName = &"load_failed"

## 生成产物报告脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFGeneratedArtifactReportBase = preload("res://addons/gf/kernel/editor/gf_generated_artifact_report.gd")
const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 公共方法 ---

## 创建模板生成清单。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param template_id: 稳定模板 ID。
## [br]
## @param template_path: 模板资源路径。
## [br]
## @param output_path: 生成产物输出路径。
## [br]
## @param options: 清单选项，支持 generator_id、source_id、artifact_owner、variables、requirements 和 metadata。
## [br]
## @schema options: Dictionary with generator_id, source_id, artifact_owner, variables, requirements, and metadata.
## [br]
## @return 模板生成清单字典。
## [br]
## @schema return: Dictionary containing valid, status, template_id, template_path, output_path, generator_id, source_id, artifact_owner, variables, requirements, metadata, and errors.
static func make_manifest(
	template_id: StringName,
	template_path: String,
	output_path: String,
	options: Dictionary = {}
) -> Dictionary:
	var manifest: Dictionary = {
		"valid": true,
		"status": STATUS_READY,
		"template_id": template_id,
		"template_path": template_path,
		"output_path": output_path,
		"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "generator_id"),
		"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "source_id", template_id),
		"artifact_owner": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(options, "artifact_owner", &"generated"),
		"variables": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "variables"),
		"requirements": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "requirements"),
		"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata"),
		"errors": [],
	}
	return validate_manifest(manifest)


## 从字典创建模板生成清单。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param data: 清单字段。
## [br]
## @param defaults: 默认字段，data 会覆盖 defaults。
## [br]
## @schema data: Dictionary manifest fields.
## [br]
## @schema defaults: Dictionary default manifest fields.
## [br]
## @return 模板生成清单字典。
## [br]
## @schema return: Dictionary containing valid, status, template_id, template_path, output_path, generator_id, source_id, artifact_owner, variables, requirements, metadata, and errors.
static func from_dictionary(data: Dictionary, defaults: Dictionary = {}) -> Dictionary:
	var merged: Dictionary = defaults.duplicate(true)
	var _merge_result: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(merged, data, true, true)
	return make_manifest(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(merged, "template_id"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(merged, "template_path"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(merged, "output_path"),
		{
			"generator_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(merged, "generator_id"),
			"source_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(merged, "source_id"),
			"artifact_owner": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(merged, "artifact_owner", &"generated"),
			"variables": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(merged, "variables"),
			"requirements": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(merged, "requirements"),
			"metadata": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(merged, "metadata"),
		}
	)


## 从 JSON 文本创建模板生成清单。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param text: JSON 文本。
## [br]
## @param defaults: 默认字段。
## [br]
## @schema defaults: Dictionary default manifest fields.
## [br]
## @return 模板生成清单字典。
## [br]
## @schema return: Dictionary containing valid, status, fields, and errors.
static func from_json_text(text: String, defaults: Dictionary = {}) -> Dictionary:
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(text)
	if parse_error != OK:
		return _make_invalid_manifest(
			STATUS_PARSE_FAILED,
			"清单 JSON 解析失败：%s。" % json.get_error_message(),
			defaults
		)
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return _make_invalid_manifest(STATUS_PARSE_FAILED, "清单 JSON 根节点必须是 Dictionary。", defaults)
	var data: Dictionary = parsed
	return from_dictionary(data, defaults)


## 从 JSON sidecar 文件创建模板生成清单。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param sidecar_path: JSON sidecar 路径。
## [br]
## @param defaults: 默认字段。
## [br]
## @schema defaults: Dictionary default manifest fields.
## [br]
## @return 模板生成清单字典。
## [br]
## @schema return: Dictionary containing valid, status, fields, sidecar_path, and errors.
static func load_sidecar(sidecar_path: String, defaults: Dictionary = {}) -> Dictionary:
	if sidecar_path.is_empty():
		return _make_invalid_manifest(STATUS_LOAD_FAILED, "sidecar 路径为空。", defaults)
	if not FileAccess.file_exists(sidecar_path):
		return _make_invalid_manifest(STATUS_LOAD_FAILED, "sidecar 文件不存在：%s。" % sidecar_path, defaults)

	var file: FileAccess = FileAccess.open(sidecar_path, FileAccess.READ)
	if file == null:
		var open_error: Error = FileAccess.get_open_error()
		return _make_invalid_manifest(
			STATUS_LOAD_FAILED,
			"sidecar 文件读取失败：%s (%s)。" % [sidecar_path, error_string(open_error)],
			defaults
		)

	var text: String = file.get_as_text()
	file.close()
	var manifest: Dictionary = from_json_text(text, defaults)
	manifest["sidecar_path"] = sidecar_path
	return manifest


## 校验模板生成清单。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param manifest: 待校验清单。
## [br]
## @schema manifest: Dictionary manifest fields.
## [br]
## @return 校验后的清单副本。
## [br]
## @schema return: Dictionary containing valid, status, and errors.
static func validate_manifest(manifest: Dictionary) -> Dictionary:
	var result: Dictionary = manifest.duplicate(true)
	var errors: Array[String] = []
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(result, "template_id") == &"":
		errors.append("template_id 不能为空。")
	var template_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "template_path")
	var output_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(result, "output_path")
	if template_path.strip_edges().is_empty():
		errors.append("template_path 不能为空。")
	else:
		_append_manifest_path_errors("template_path", template_path, errors)
		result["template_path"] = _normalize_manifest_path(template_path)
	if output_path.strip_edges().is_empty():
		errors.append("output_path 不能为空。")
	else:
		_append_manifest_path_errors("output_path", output_path, errors)
		result["output_path"] = _normalize_manifest_path(output_path)

	result["errors"] = errors
	result["valid"] = errors.is_empty()
	result["status"] = STATUS_READY if errors.is_empty() else STATUS_INVALID
	return result


## 从清单生成 GFGeneratedArtifactReport 保存选项。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param manifest: 模板生成清单。
## [br]
## @param extra_options: 额外保存选项，会覆盖清单派生字段。
## [br]
## @schema manifest: Dictionary returned by make_manifest().
## [br]
## @schema extra_options: Dictionary GFGeneratedArtifactReport.save_text() options.
## [br]
## @return 保存选项字典。
## [br]
## @schema return: Dictionary with artifact_owner, generator_id, source_id, metadata, and caller extra options.
static func make_artifact_options(manifest: Dictionary, extra_options: Dictionary = {}) -> Dictionary:
	var manifest_metadata: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(manifest, "metadata")
	var metadata_payload: Dictionary = manifest_metadata.duplicate(true)
	metadata_payload["template_id"] = String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(manifest, "template_id"))
	metadata_payload["template_path"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(manifest, "template_path")
	metadata_payload["variables"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(manifest, "variables")
	metadata_payload["requirements"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(manifest, "requirements")

	var result: Dictionary = {
		"artifact_owner": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(manifest, "artifact_owner", &"generated"),
		"generator_id": String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(manifest, "generator_id")),
		"source_id": String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(manifest, "source_id")),
		"metadata": metadata_payload,
	}
	var _merge_options_result: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.merge_dictionary(result, extra_options, true, true)
	return result


## 按清单保存文本产物。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param manifest: 模板生成清单。
## [br]
## @param text: 要保存的文本。
## [br]
## @param options: 额外保存选项。
## [br]
## @schema manifest: Dictionary returned by make_manifest().
## [br]
## @schema options: Dictionary GFGeneratedArtifactReport.save_text() options.
## [br]
## @return 生成产物报告。
## [br]
## @schema return: Dictionary returned by GFGeneratedArtifactReport.save_text().
static func save_text_from_manifest(manifest: Dictionary, text: String, options: Dictionary = {}) -> Dictionary:
	var checked: Dictionary = validate_manifest(manifest)
	var output_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(checked, "output_path")
	if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(checked, "valid", false):
		return GFGeneratedArtifactReportBase.make_report(
			output_path,
			GFGeneratedArtifactReportBase.STATUS_FAILED,
			ERR_INVALID_DATA,
			"; ".join(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(checked, "errors")),
			make_artifact_options(checked, options)
		)
	return GFGeneratedArtifactReportBase.save_text(output_path, text, make_artifact_options(checked, options))


## 汇总多份模板生成清单。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param manifests: 清单数组。
## [br]
## @param options: 汇总选项，支持 include_manifests 和 metadata；metadata 与可选 manifests 会在返回摘要中编码为 JSON-safe 值。
## [br]
## @schema manifests: Array[Dictionary] template generation manifests.
## [br]
## @schema options: Dictionary with include_manifests and metadata; metadata may contain arbitrary Variant values and is encoded with GFReportValueCodec in the returned summary.
## [br]
## @return 清单摘要。
## [br]
## @schema return: JSON-safe Dictionary containing valid, manifest_count, valid_count, invalid_count, template_ids, output_paths, errors, metadata, and optional manifests.
static func summarize_manifests(manifests: Array[Dictionary], options: Dictionary = {}) -> Dictionary:
	var valid_count: int = 0
	var invalid_count: int = 0
	var template_ids: PackedStringArray = PackedStringArray()
	var output_paths: PackedStringArray = PackedStringArray()
	var errors: Array[Dictionary] = []
	var checked_manifests: Array[Dictionary] = []

	for manifest: Dictionary in manifests:
		var checked: Dictionary = validate_manifest(manifest)
		checked_manifests.append(checked)
		var template_id: String = String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(checked, "template_id"))
		var output_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(checked, "output_path")
		if not template_id.is_empty():
			var _append_template_id: bool = template_ids.append(template_id)
		if not output_path.is_empty():
			var _append_output_path: bool = output_paths.append(output_path)

		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(checked, "valid", false):
			valid_count += 1
		else:
			invalid_count += 1
			errors.append({
				"template_id": template_id,
				"output_path": output_path,
				"errors": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(checked, "errors"),
			})

	var summary: Dictionary = {
		"valid": invalid_count == 0,
		"manifest_count": manifests.size(),
		"valid_count": valid_count,
		"invalid_count": invalid_count,
		"template_ids": _packed_to_array(template_ids),
		"output_paths": _packed_to_array(output_paths),
		"errors": errors,
		"metadata": _to_report_dictionary(_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(options, "metadata")),
	}
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_manifests", false):
		summary["manifests"] = _to_manifest_report_array(checked_manifests)
	return summary


# --- 私有/辅助方法 ---

static func _to_manifest_report_array(manifests: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for manifest: Dictionary in manifests:
		result.append(_to_manifest_report_dictionary(manifest))
	return result


static func _to_manifest_report_dictionary(manifest: Dictionary) -> Dictionary:
	var status_text: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(manifest, "status")
	if status_text.is_empty():
		status_text = String(STATUS_INVALID)
	var artifact_owner: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(manifest, "artifact_owner", "generated")
	if artifact_owner.is_empty():
		artifact_owner = "generated"
	var result: Dictionary = {
		"valid": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(manifest, "valid", false),
		"status": status_text,
		"template_id": String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(manifest, "template_id")),
		"template_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(manifest, "template_path"),
		"output_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(manifest, "output_path"),
		"generator_id": String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(manifest, "generator_id")),
		"source_id": String(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(manifest, "source_id")),
		"artifact_owner": artifact_owner,
		"variables": _to_report_dictionary(_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(manifest, "variables")),
		"requirements": _to_report_dictionary(_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(manifest, "requirements")),
		"metadata": _to_report_dictionary(_GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(manifest, "metadata")),
		"errors": _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(manifest, "errors"),
	}
	if manifest.has("sidecar_path"):
		result["sidecar_path"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(manifest, "sidecar_path")
	return result


static func _to_report_dictionary(value: Dictionary) -> Dictionary:
	return _GF_REPORT_VALUE_CODEC_SCRIPT.to_report_dictionary(value, _make_report_codec_options())


static func _make_report_codec_options() -> Dictionary:
	return _GF_REPORT_VALUE_CODEC_SCRIPT.make_redaction_options(
		_GF_REPORT_VALUE_CODEC_SCRIPT.REDACTION_PROFILE_SUPPORT,
		{ "path_redaction": "basename" }
	)


static func _packed_to_array(values: PackedStringArray) -> Array:
	var result: Array = []
	for value: String in values:
		result.append(value)
	return result


static func _append_manifest_path_errors(field_name: String, path: String, errors: Array[String]) -> void:
	var normalized: String = _normalize_manifest_path(path)
	if not (normalized.begins_with("res://") or normalized.begins_with("user://")):
		errors.append("%s 必须使用 res:// 或 user:// 路径。" % field_name)
		return
	var path_body: String = normalized.trim_prefix("res://").trim_prefix("user://")
	if path_body.contains("://"):
		errors.append("%s 包含不支持的嵌套路径协议。" % field_name)
		return
	if path_body.contains(":\\") or path_body.contains(":/"):
		errors.append("%s 不能使用本地绝对路径。" % field_name)
		return
	if _path_has_parent_segment(path_body):
		errors.append("%s 不能包含 .. 路径段。" % field_name)


static func _normalize_manifest_path(path: String) -> String:
	return path.strip_edges().replace("\\", "/")


static func _path_has_parent_segment(path: String) -> bool:
	for part: String in path.split("/", false):
		if part == "..":
			return true
	return false


static func _make_invalid_manifest(status: StringName, message: String, defaults: Dictionary = {}) -> Dictionary:
	var manifest: Dictionary = from_dictionary(defaults) if not defaults.is_empty() else make_manifest(&"", "", "")
	manifest["valid"] = false
	manifest["status"] = status
	manifest["errors"] = [message]
	return manifest
