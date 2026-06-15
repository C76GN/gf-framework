@tool

# GF 扩展导出过滤插件。
#
# 导出时可跳过禁用扩展目录，让未启用的 GF 扩展不进入最终导出产物。
extends EditorExportPlugin


# --- 常量 ---

## 扩展启用设置脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFExtensionSettingsBase = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")

## 扩展引用审计脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFExtensionUsageAuditBase = preload("res://addons/gf/kernel/extension/gf_extension_usage_audit.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

var _disabled_extension_roots: Array[String] = []
var _disabled_manifests: Array[GFExtensionManifest] = []


# --- Godot 生命周期方法 ---

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	_refresh_disabled_extension_roots()
	_warn_disabled_extension_references()


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if _should_skip_export_path(path, _disabled_extension_roots):
		skip()
		return


func _export_end() -> void:
	_disabled_extension_roots.clear()
	_disabled_manifests.clear()


# --- 私有/辅助方法 ---

func _refresh_disabled_extension_roots() -> void:
	var graph_report: Dictionary = _collect_disabled_export_state(
		_disabled_extension_roots,
		_disabled_manifests
	)
	if not _manifest_graph_allows_export(graph_report):
		push_error("[GFExtensionExportPlugin] 扩展 manifest 图无效，已停止导出扩展过滤：\n%s" % _format_manifest_graph_report(graph_report))


static func _path_is_under(path: String, root_path: String) -> bool:
	var normalized_root: String = root_path.trim_suffix("/")
	return path == normalized_root or path.begins_with(normalized_root + "/")


static func _should_skip_export_path(path: String, disabled_roots: Array[String]) -> bool:
	for root_path: String in disabled_roots:
		if _path_is_under(path, root_path):
			return true
	return false


static func _manifest_graph_allows_export(report: Dictionary) -> bool:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok", true)


static func _collect_disabled_export_state(
	disabled_roots: Array[String],
	disabled_manifests: Array[GFExtensionManifest]
) -> Dictionary:
	disabled_roots.clear()
	disabled_manifests.clear()
	if not GFExtensionSettingsBase.should_export_exclude_disabled_extensions():
		return { "ok": true }

	var graph_report: Dictionary = GFExtensionSettingsBase.get_manifest_graph_report()
	if not _manifest_graph_allows_export(graph_report):
		return graph_report

	for manifest: GFExtensionManifest in GFExtensionSettingsBase.get_disabled_manifests():
		if manifest.root_path.is_empty():
			continue
		disabled_manifests.append(manifest)
		disabled_roots.append(manifest.root_path.trim_suffix("/"))
	return graph_report


static func _format_manifest_graph_report(report: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for invalid_manifest_variant: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "invalid_manifests"):
		var invalid_manifest: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(invalid_manifest_variant)
		var _append_invalid_result: Variant = lines.append("- invalid manifest %s: %s" % [
			_describe_manifest_issue(invalid_manifest),
			", ".join(_GF_VARIANT_ACCESS_SCRIPT.to_string_array(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(invalid_manifest, "errors", []))),
		])

	for missing_dependency_variant: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "missing_dependencies"):
		var missing_dependency: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(missing_dependency_variant)
		var _append_missing_result: Variant = lines.append("- missing dependency %s -> %s" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(missing_dependency, "extension_id", "?"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(missing_dependency, "dependency_id", "?"),
		])

	for duplicate_id: String in _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(report, "duplicate_ids", PackedStringArray()):
		var _append_duplicate_result: Variant = lines.append("- duplicate extension id %s" % duplicate_id)

	for cycle_variant: Variant in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "dependency_cycles"):
		var _append_cycle_result: Variant = lines.append("- dependency cycle %s" % _GF_VARIANT_ACCESS_SCRIPT.to_text(cycle_variant, "?"))

	if lines.is_empty():
		return "extension manifest graph is invalid"
	return "\n".join(lines)


static func _describe_manifest_issue(issue: Dictionary) -> String:
	var extension_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "extension_id")
	var source_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "source_path")
	if not extension_id.is_empty() and not source_path.is_empty():
		return "%s (%s)" % [extension_id, source_path]
	if not extension_id.is_empty():
		return extension_id
	if not source_path.is_empty():
		return source_path
	return "?"


func _warn_disabled_extension_references() -> void:
	if _disabled_manifests.is_empty():
		return

	var report: Dictionary = GFExtensionUsageAuditBase.audit_disabled_extensions(_disabled_manifests, {
		"max_references_per_extension": 8,
	})
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok", true):
		return

	var formatted_report: String = _format_reference_report(report)
	if GFExtensionSettingsBase.should_fail_export_on_disabled_extension_references():
		push_error("[GFExtensionExportPlugin] 检测到禁用扩展仍被项目文件引用，当前导出策略要求报告为错误：\n%s" % formatted_report)
		return

	push_warning("[GFExtensionExportPlugin] 检测到禁用扩展仍被项目文件引用，导出排除后可能缺文件：\n%s" % formatted_report)


func _format_reference_report(report: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var extensions: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(report, "extensions", {})
	)
	for extension_id: String in extensions.keys():
		var extension_report: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(extensions[extension_id])
		if extension_report.is_empty():
			continue

		var _append_result_102: Variant = lines.append("- %s (%s)" % [
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(extension_report, "display_name", extension_id),
			extension_id,
		])
		var references: Array = _GF_VARIANT_ACCESS_SCRIPT.as_array(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_value(extension_report, "references", [])
		)
		for reference_entry: Dictionary in references:
			var _append_result_110: Variant = lines.append("  %s:%d" % [
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_entry, "path", ""),
				_GF_VARIANT_ACCESS_SCRIPT.get_option_int(reference_entry, "line", 0),
			])
	return "\n".join(lines)
