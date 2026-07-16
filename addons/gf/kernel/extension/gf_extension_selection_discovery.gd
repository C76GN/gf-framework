## GFExtensionSelectionDiscovery: GF 扩展启用选择与贡献路径快照缓存。
##
## 基于 manifest 集合、当前启用 ID 和扩展工具贡献文件，生成启用选择、依赖图、
## enabled/disabled manifest 与各类贡献路径的稳定 snapshot。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
## [br]
## @layer kernel/extension
class_name GFExtensionSelectionDiscovery
extends RefCounted


# --- 常量 ---

const _TOOL_CONTRIBUTION_FILE_NAME: String = "gf_tool_contribution.json"
const _MANIFEST_PATH_FIELDS: Array[String] = [
	"access_generator_extension_paths",
	"editor_action_paths",
	"editor_dock_paths",
	"editor_inspector_paths",
	"export_plugin_paths",
	"gltf_document_extension_paths",
	"import_plugin_paths",
	"installer_paths",
]
const _GF_DEPENDENCY_GRAPH_TOOLS = preload("res://addons/gf/kernel/core/gf_dependency_graph_tools.gd")
const _GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_tool_contribution.gd")
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_EXTENSION_JSON_FILE_READER_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_json_file_reader.gd")


# --- 私有变量 ---

static var _snapshot_cache: Dictionary = {}
static var _has_snapshot_cache: bool = false
static var _cache_revision: int = 0


# --- 公共方法 ---

## 获取当前扩展启用选择快照。
##
## 默认会复用仍然有效的快照；当 manifest、启用 ID、manifest load errors
## 或扩展工具贡献文件变化时，自动重新派生并替换缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param manifests: 当前可发现的扩展 manifest 列表。
## [br]
## @param configured_ids: 项目配置中的启用扩展 ID。
## [br]
## @param options: 发现选项。
## [br]
## @schema options: Dictionary，支持 force_refresh、builtin_extension_ids 和 manifest_load_errors。
## [br]
## @return 扩展启用选择快照。
## [br]
## @schema return: Dictionary，包含 ok、configured_ids、resolved_ids、unknown_enabled_ids、enabled_manifests、disabled_manifests、graph_report、manifest_paths、contribution_paths、paths、tool_contribution_errors、signature、signature_hash 和 revision。
static func get_snapshot(
	manifests: Array[GFExtensionManifest] = [],
	configured_ids: Array[String] = [],
	options: Dictionary = {}
) -> Dictionary:
	var signature: Dictionary = make_discovery_signature(manifests, configured_ids, options)
	var force_refresh: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "force_refresh", false)
	if not force_refresh and _has_snapshot_cache and _snapshot_matches_signature(signature):
		return _duplicate_snapshot(_snapshot_cache)

	_store_snapshot(_make_snapshot(manifests, configured_ids, options, signature))
	return _duplicate_snapshot(_snapshot_cache)


## 清空启用选择快照缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
static func clear_cache() -> void:
	_snapshot_cache.clear()
	_has_snapshot_cache = false


# --- 框架内部方法 ---

## 根据 manifest 依赖关系补齐启用扩展。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param extension_ids: 原始启用扩展 ID。
## [br]
## @param manifests: 当前可发现的扩展 manifest 列表。
## [br]
## @param options: 依赖解析选项。
## [br]
## @schema options: Dictionary，支持 builtin_extension_ids。
## [br]
## @return 补齐依赖后的扩展 ID。
static func resolve_extension_dependencies(
	extension_ids: Array[String],
	manifests: Array[GFExtensionManifest] = [],
	options: Dictionary = {}
) -> Array[String]:
	var source_manifests: Array[GFExtensionManifest] = _duplicate_manifest_array(manifests)
	var builtin_ids: Array[String] = _get_builtin_extension_ids(options)
	var manifest_by_id: Dictionary = _build_manifest_map(source_manifests)
	var requested_ids: Array[String] = _sorted_unique(extension_ids)
	var graph_report: Dictionary = _GF_DEPENDENCY_GRAPH_TOOLS.sort_dependency_first(
		_array_to_packed_string_array(requested_ids),
		_build_dependency_map(manifest_by_id, builtin_ids)
	)
	var resolved_order: PackedStringArray = _get_graph_ordered_ids(graph_report)
	var cycles: Array[PackedStringArray] = _get_graph_cycles(graph_report)
	for cycle: PackedStringArray in cycles:
		push_warning("[GFExtensionSelectionDiscovery] 检测到扩展依赖循环：%s" % " -> ".join(Array(cycle)))

	var ordered: Array[String] = []
	if cycles.is_empty():
		for resolved_id: String in resolved_order:
			ordered.append(resolved_id)
		return ordered

	var resolved: Dictionary = _make_lookup_from_packed_string_array(resolved_order)
	for manifest: GFExtensionManifest in source_manifests:
		if resolved.has(manifest.id):
			ordered.append(manifest.id)
	return ordered


## 获取启用 ID 中无法匹配当前 manifest 的项目扩展 ID。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param extension_ids: 待检查的扩展 ID。
## [br]
## @param manifests: 当前可发现的扩展 manifest 列表。
## [br]
## @param options: 检查选项。
## [br]
## @schema options: Dictionary，支持 builtin_extension_ids。
## [br]
## @return 未知扩展 ID 列表。
static func get_unknown_enabled_ids(
	extension_ids: Array[String],
	manifests: Array[GFExtensionManifest] = [],
	options: Dictionary = {}
) -> Array[String]:
	return _get_unknown_enabled_ids(
		_sorted_unique(extension_ids),
		_build_manifest_map(manifests),
		_get_builtin_extension_ids(options)
	)


## 生成 manifest 依赖图诊断报告。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param manifests: 当前可发现的扩展 manifest 列表。
## [br]
## @param options: 图诊断选项。
## [br]
## @schema options: Dictionary，支持 builtin_extension_ids 和 manifest_load_errors。
## [br]
## @return manifest 图诊断报告。
## [br]
## @schema return: Dictionary containing ok, extension_count, issue_count, duplicate_ids, invalid_manifests, manifest_load_errors, missing_dependencies, and dependency_cycles.
static func make_manifest_graph_report(
	manifests: Array[GFExtensionManifest] = [],
	options: Dictionary = {}
) -> Dictionary:
	var source_manifests: Array[GFExtensionManifest] = _duplicate_manifest_array(manifests)
	var builtin_ids: Array[String] = _get_builtin_extension_ids(options)
	var manifest_by_id: Dictionary = {}
	var seen_ids: Dictionary = {}
	var duplicate_ids: PackedStringArray = PackedStringArray()
	var invalid_manifests: Array[Dictionary] = []
	var manifest_load_errors: Array[Dictionary] = _get_issue_records_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(options, "manifest_load_errors", [])
	)
	var missing_dependencies: Array[Dictionary] = []
	var dependency_cycles: Array[PackedStringArray] = []
	for load_error: Dictionary in manifest_load_errors:
		invalid_manifests.append(_manifest_load_error_to_invalid_manifest(load_error))

	for manifest: GFExtensionManifest in source_manifests:
		if manifest == null:
			continue

		var errors: Array[String] = manifest.get_validation_errors()
		if not errors.is_empty():
			invalid_manifests.append({
				"stage": "validation",
				"extension_id": manifest.id,
				"source_path": manifest.source_path,
				"errors": errors,
			})

		if manifest.id.strip_edges().is_empty():
			continue
		if seen_ids.has(manifest.id):
			if not duplicate_ids.has(manifest.id):
				var _append_duplicate_id: bool = duplicate_ids.append(manifest.id)
			continue

		seen_ids[manifest.id] = true
		manifest_by_id[manifest.id] = manifest

	for manifest: GFExtensionManifest in source_manifests:
		if manifest == null:
			continue
		for dependency_id: String in manifest.dependencies:
			if not GFExtensionManifest.is_valid_extension_id(dependency_id):
				continue
			if builtin_ids.has(dependency_id):
				continue
			if not manifest_by_id.has(dependency_id):
				missing_dependencies.append({
					"extension_id": manifest.id,
					"dependency_id": dependency_id,
				})

	var dependency_graph_report: Dictionary = _GF_DEPENDENCY_GRAPH_TOOLS.sort_dependency_first(
		_dictionary_keys_to_packed_string_array(manifest_by_id),
		_build_dependency_map(manifest_by_id, builtin_ids)
	)
	dependency_cycles = _get_graph_cycles(dependency_graph_report)

	var issue_count: int = (
		duplicate_ids.size()
		+ invalid_manifests.size()
		+ missing_dependencies.size()
		+ dependency_cycles.size()
	)
	return {
		"ok": issue_count == 0,
		"extension_count": manifest_by_id.size(),
		"issue_count": issue_count,
		"duplicate_ids": duplicate_ids,
		"invalid_manifests": invalid_manifests,
		"manifest_load_errors": manifest_load_errors,
		"missing_dependencies": missing_dependencies,
		"dependency_cycles": dependency_cycles,
	}


## 生成当前启用选择发现签名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param manifests: 当前可发现的扩展 manifest 列表。
## [br]
## @param configured_ids: 项目配置中的启用扩展 ID。
## [br]
## @param options: 签名选项。
## [br]
## @schema options: Dictionary，支持 builtin_extension_ids 和 manifest_load_errors。
## [br]
## @return 发现签名。
## [br]
## @schema return: Dictionary containing manifest_tokens, configured_ids, builtin_extension_ids, tool_contribution_files, manifest_load_errors, and hash.
static func make_discovery_signature(
	manifests: Array[GFExtensionManifest] = [],
	configured_ids: Array[String] = [],
	options: Dictionary = {}
) -> Dictionary:
	var tool_contribution_files: Array[Dictionary] = _make_tool_contribution_file_signatures(manifests)
	var manifest_load_errors: Array[Dictionary] = _get_issue_records_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(options, "manifest_load_errors", [])
	)
	var signature_payload: Dictionary = {
		"manifest_tokens": _make_manifest_tokens(manifests),
		"configured_ids": _sorted_unique(configured_ids),
		"builtin_extension_ids": _get_builtin_extension_ids(options),
		"tool_contribution_files": tool_contribution_files,
		"manifest_load_errors": manifest_load_errors,
	}
	return {
		"manifest_tokens": _make_manifest_tokens(manifests),
		"configured_ids": _sorted_unique(configured_ids),
		"builtin_extension_ids": _get_builtin_extension_ids(options),
		"tool_contribution_files": tool_contribution_files,
		"manifest_load_errors": manifest_load_errors,
		"hash": JSON.stringify(signature_payload).sha256_text(),
	}


# --- 私有/辅助方法 ---

static func _make_snapshot(
	manifests: Array[GFExtensionManifest],
	configured_ids: Array[String],
	options: Dictionary,
	signature: Dictionary
) -> Dictionary:
	var source_manifests: Array[GFExtensionManifest] = _duplicate_manifest_array(manifests)
	var builtin_ids: Array[String] = _get_builtin_extension_ids(options)
	var manifest_load_errors: Array[Dictionary] = _get_issue_records_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(options, "manifest_load_errors", [])
	)
	var graph_report: Dictionary = make_manifest_graph_report(source_manifests, {
		"builtin_extension_ids": builtin_ids,
		"manifest_load_errors": manifest_load_errors,
	})
	var manifest_by_id: Dictionary = _build_manifest_map(source_manifests)
	var normalized_configured_ids: Array[String] = _sorted_unique(configured_ids)
	var resolved_ids: Array[String] = resolve_extension_dependencies(normalized_configured_ids, source_manifests, {
		"builtin_extension_ids": builtin_ids,
	})
	var unknown_enabled_ids: Array[String] = _get_unknown_enabled_ids(
		normalized_configured_ids,
		manifest_by_id,
		builtin_ids
	)
	var graph_ok: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(graph_report, "ok", true)
	var enabled_manifests: Array[GFExtensionManifest] = []
	var disabled_manifests: Array[GFExtensionManifest] = []
	if graph_ok:
		enabled_manifests = _get_manifests_for_ids(resolved_ids, manifest_by_id)
		disabled_manifests = _get_disabled_manifests(source_manifests, resolved_ids)

	var tool_contribution_errors: Array[Dictionary] = []
	var manifest_paths: Dictionary = _collect_manifest_path_dictionary(enabled_manifests)
	var contribution_paths: Dictionary = _collect_tool_contribution_path_dictionary(
		enabled_manifests,
		tool_contribution_errors
	)
	var paths: Dictionary = _merge_path_dictionaries(manifest_paths, contribution_paths)
	return {
		"ok": graph_ok and unknown_enabled_ids.is_empty(),
		"configured_ids": normalized_configured_ids,
		"resolved_ids": resolved_ids,
		"unknown_enabled_ids": unknown_enabled_ids,
		"enabled_manifests": _duplicate_manifest_array(enabled_manifests),
		"disabled_manifests": _duplicate_manifest_array(disabled_manifests),
		"graph_report": graph_report,
		"graph_ok": graph_ok,
		"manifest_paths": manifest_paths,
		"contribution_paths": contribution_paths,
		"paths": paths,
		"tool_contribution_errors": tool_contribution_errors,
		"signature": signature.duplicate(true),
		"signature_hash": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(signature, "hash"),
		"revision": 0,
	}


static func _store_snapshot(snapshot: Dictionary) -> void:
	_cache_revision += 1
	var stored_snapshot: Dictionary = _duplicate_snapshot(snapshot)
	stored_snapshot["revision"] = _cache_revision
	_snapshot_cache = stored_snapshot
	_has_snapshot_cache = true


static func _snapshot_matches_signature(signature: Dictionary) -> bool:
	var current_hash: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(signature, "hash")
	var cached_hash: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(_snapshot_cache, "signature_hash")
	return not current_hash.is_empty() and current_hash == cached_hash


static func _duplicate_snapshot(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = snapshot.duplicate(true)
	result["configured_ids"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(snapshot, "configured_ids")
	result["resolved_ids"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(snapshot, "resolved_ids")
	result["unknown_enabled_ids"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(snapshot, "unknown_enabled_ids")
	result["enabled_manifests"] = _duplicate_manifest_array(_get_manifest_array_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "enabled_manifests", [])
	))
	result["disabled_manifests"] = _duplicate_manifest_array(_get_manifest_array_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "disabled_manifests", [])
	))
	result["graph_report"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(snapshot, "graph_report")
	result["manifest_paths"] = _get_path_dictionary_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "manifest_paths", {})
	)
	result["contribution_paths"] = _get_path_dictionary_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "contribution_paths", {})
	)
	result["paths"] = _get_path_dictionary_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "paths", {})
	)
	result["tool_contribution_errors"] = _get_issue_records_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "tool_contribution_errors", [])
	)
	result["signature"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(snapshot, "signature")
	return result


static func _collect_manifest_path_dictionary(manifests: Array[GFExtensionManifest]) -> Dictionary:
	var result: Dictionary = _make_empty_path_dictionary(_MANIFEST_PATH_FIELDS)
	for manifest: GFExtensionManifest in manifests:
		for property_name: String in _MANIFEST_PATH_FIELDS:
			var raw_paths: Variant = _get_manifest_property(manifest, property_name)
			var target_paths: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, property_name)
			_append_unique_paths(target_paths, _GF_VARIANT_ACCESS_SCRIPT.to_string_array(raw_paths))
			result[property_name] = target_paths
	return result


static func _collect_tool_contribution_path_dictionary(
	manifests: Array[GFExtensionManifest],
	errors: Array[Dictionary]
) -> Dictionary:
	var result: Dictionary = _make_empty_path_dictionary(_GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.PATH_FIELDS)
	for manifest: GFExtensionManifest in manifests:
		var contribution_path: String = _get_tool_contribution_path(manifest)
		if contribution_path.is_empty() or not FileAccess.file_exists(contribution_path):
			continue

		var json_report: Dictionary = _GF_EXTENSION_JSON_FILE_READER_SCRIPT.read_object_report(
			contribution_path,
			_make_tool_contribution_json_reader_options()
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(json_report, "ok", false):
			errors.append(_make_tool_contribution_error_record(
				manifest.id,
				contribution_path,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(json_report, "errors")
			))
			continue

		var raw_data: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(json_report, "data")
		var schema_report: Dictionary = _GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.parse_dictionary(
			raw_data,
			manifest.id
		)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(schema_report, "ok", false):
			errors.append(_make_tool_contribution_error_record(
				manifest.id,
				contribution_path,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(schema_report, "errors")
			))
			continue
		var data: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(schema_report, "data")

		for property_name: String in _GF_EXTENSION_TOOL_CONTRIBUTION_SCRIPT.PATH_FIELDS:
			for raw_path: String in _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(data, property_name):
				var normalized_path: String = _normalize_tool_contribution_resource_path(
					raw_path,
					manifest.root_path,
					manifest.id,
					contribution_path,
					errors
				)
				if normalized_path.is_empty():
					continue
				var target_paths: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, property_name)
				_append_unique_path(target_paths, normalized_path)
				result[property_name] = target_paths
	return result


static func _merge_path_dictionaries(first_paths: Dictionary, second_paths: Dictionary) -> Dictionary:
	var result: Dictionary = _make_empty_path_dictionary(_MANIFEST_PATH_FIELDS)
	for property_name: String in _MANIFEST_PATH_FIELDS:
		var target_paths: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, property_name)
		_append_unique_paths(target_paths, _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(first_paths, property_name))
		_append_unique_paths(target_paths, _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(second_paths, property_name))
		result[property_name] = target_paths
	return result


static func _make_empty_path_dictionary(field_names: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for field_name: String in field_names:
		result[field_name] = []
	return result


static func _append_unique_paths(target_paths: Array, source_paths: Array[String]) -> void:
	for source_path: String in source_paths:
		_append_unique_path(target_paths, source_path)


static func _append_unique_path(target_paths: Array, raw_path: String) -> void:
	var normalized_path: String = raw_path.strip_edges()
	if normalized_path.is_empty() or target_paths.has(normalized_path):
		return
	target_paths.append(normalized_path)


static func _get_manifests_for_ids(
	extension_ids: Array[String],
	manifest_by_id: Dictionary
) -> Array[GFExtensionManifest]:
	var result: Array[GFExtensionManifest] = []
	for extension_id: String in extension_ids:
		var manifest: GFExtensionManifest = _get_manifest_from_map_or_null(manifest_by_id, extension_id)
		if manifest != null:
			result.append(manifest)
	return result


static func _get_disabled_manifests(
	manifests: Array[GFExtensionManifest],
	enabled_ids: Array[String]
) -> Array[GFExtensionManifest]:
	var result: Array[GFExtensionManifest] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null:
			continue
		if not enabled_ids.has(manifest.id):
			result.append(manifest)
	return result


static func _get_tool_contribution_path(manifest: GFExtensionManifest) -> String:
	if manifest == null or manifest.root_path.is_empty():
		return ""
	return _GF_PATH_TOOLS.normalize_resource_path(
		manifest.root_path.path_join("editor").path_join(_TOOL_CONTRIBUTION_FILE_NAME)
	)


static func _normalize_tool_contribution_resource_path(
	raw_path: String,
	root_path: String,
	extension_id: String,
	source_path: String,
	errors: Array[Dictionary]
) -> String:
	var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(raw_path.strip_edges())
	if normalized_path.is_empty():
		return ""
	if not normalized_path.begins_with("res://"):
		normalized_path = _GF_PATH_TOOLS.normalize_resource_path(root_path.path_join(normalized_path.trim_prefix("/")))
	if not _GF_PATH_TOOLS.is_path_under_root(normalized_path, root_path, true, false):
		errors.append(_make_tool_contribution_error_record(
			extension_id,
			source_path,
			["tool contribution path escaped extension root: %s" % normalized_path]
		))
		return ""
	if not ResourceLoader.exists(normalized_path):
		errors.append(_make_tool_contribution_error_record(
			extension_id,
			source_path,
			["tool contribution path does not exist: %s" % normalized_path]
		))
		return ""
	return normalized_path


static func _make_tool_contribution_error_record(
	extension_id: String,
	source_path: String,
	errors: Array[String]
) -> Dictionary:
	return {
		"stage": "tool_contribution",
		"extension_id": extension_id,
		"source_path": source_path,
		"errors": errors.duplicate(),
	}


static func _make_tool_contribution_json_reader_options() -> Dictionary:
	return {
		"empty_path_error": "tool contribution path is empty",
		"open_error_prefix": "could not open tool contribution",
		"read_error_prefix": "could not read tool contribution",
		"parse_error_prefix": "could not parse tool contribution",
		"root_type_error": "tool contribution must be a JSON object",
	}


static func _make_tool_contribution_file_signatures(manifests: Array[GFExtensionManifest]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var paths: Array[String] = []
	for manifest: GFExtensionManifest in manifests:
		var contribution_path: String = _get_tool_contribution_path(manifest)
		if contribution_path.is_empty() or paths.has(contribution_path):
			continue
		paths.append(contribution_path)
	paths.sort()
	for contribution_path: String in paths:
		result.append(_make_file_signature(contribution_path))
	return result


static func _make_file_signature(path: String) -> Dictionary:
	var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(path)
	var source_file: FileAccess = FileAccess.open(normalized_path, FileAccess.READ)
	if source_file == null:
		return {
			"source_path": normalized_path,
			"exists": false,
			"size_bytes": 0,
			"content_sha256": "",
		}

	var source_text: String = source_file.get_as_text()
	var size_bytes: int = source_file.get_length()
	source_file.close()
	return {
		"source_path": normalized_path,
		"exists": true,
		"size_bytes": size_bytes,
		"content_sha256": source_text.sha256_text(),
	}


static func _make_manifest_tokens(manifests: Array[GFExtensionManifest]) -> Array[String]:
	var tokens: Array[String] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null:
			continue
		tokens.append(JSON.stringify({
			"id": manifest.id,
			"source_path": manifest.source_path,
			"root_path": manifest.root_path,
			"dependencies": manifest.dependencies,
			"installer_paths": manifest.installer_paths,
			"editor_action_paths": manifest.editor_action_paths,
			"editor_dock_paths": manifest.editor_dock_paths,
			"editor_inspector_paths": manifest.editor_inspector_paths,
			"import_plugin_paths": manifest.import_plugin_paths,
			"export_plugin_paths": manifest.export_plugin_paths,
			"gltf_document_extension_paths": manifest.gltf_document_extension_paths,
			"access_generator_extension_paths": manifest.access_generator_extension_paths,
		}))
	tokens.sort()
	return tokens


static func _get_builtin_extension_ids(options: Dictionary) -> Array[String]:
	return _sorted_unique(_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(
		options,
		"builtin_extension_ids",
		["gf.kernel", "gf.standard"]
	))


static func _get_unknown_enabled_ids(
	extension_ids: Array[String],
	manifest_by_id: Dictionary,
	builtin_ids: Array[String]
) -> Array[String]:
	var result: Array[String] = []
	for extension_id: String in extension_ids:
		var normalized_id: String = extension_id.strip_edges()
		if builtin_ids.has(normalized_id):
			continue
		if not manifest_by_id.has(normalized_id) and not result.has(normalized_id):
			result.append(normalized_id)
	result.sort()
	return result


static func _manifest_load_error_to_invalid_manifest(load_error: Dictionary) -> Dictionary:
	return {
		"stage": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(load_error, "stage", "load"),
		"extension_id": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(load_error, "extension_id"),
		"source_path": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(load_error, "source_path"),
		"errors": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(load_error, "errors"),
	}


static func _get_issue_records_from_value(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result

	var values: Array = value
	for item: Variant in values:
		if item is Dictionary:
			var issue: Dictionary = item
			result.append(_make_issue_record(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "stage"),
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "extension_id"),
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "source_path"),
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(issue, "errors")
			))
	return result


static func _make_issue_record(
	stage: String,
	extension_id: String,
	source_path: String,
	errors: Array[String]
) -> Dictionary:
	return {
		"stage": stage,
		"extension_id": extension_id,
		"source_path": source_path,
		"errors": errors.duplicate(),
	}


static func _get_path_dictionary_from_value(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result

	var dictionary: Dictionary = value
	for key: Variant in dictionary.keys():
		var property_name: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(key).strip_edges()
		if property_name.is_empty():
			continue
		result[property_name] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(dictionary, property_name)
	return result


static func _duplicate_manifest_array(manifests: Array[GFExtensionManifest]) -> Array[GFExtensionManifest]:
	var result: Array[GFExtensionManifest] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null:
			continue
		result.append(manifest.duplicate_manifest())
	return result


static func _get_manifest_array_from_value(value: Variant) -> Array[GFExtensionManifest]:
	var result: Array[GFExtensionManifest] = []
	if not (value is Array):
		return result

	var values: Array = value
	for item: Variant in values:
		if item is GFExtensionManifest:
			var manifest: GFExtensionManifest = item
			result.append(manifest)
	return result


static func _build_manifest_map(manifests: Array[GFExtensionManifest]) -> Dictionary:
	var result: Dictionary = {}
	for manifest: GFExtensionManifest in manifests:
		if manifest == null or manifest.id.strip_edges().is_empty() or result.has(manifest.id):
			continue
		result[manifest.id] = manifest
	return result


static func _get_manifest_from_map_or_null(
	manifest_by_id: Dictionary,
	extension_id: String
) -> GFExtensionManifest:
	var raw_manifest: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(manifest_by_id, extension_id)
	if raw_manifest is GFExtensionManifest:
		return raw_manifest
	return null


static func _build_dependency_map(manifest_by_id: Dictionary, builtin_ids: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for extension_id_variant: Variant in manifest_by_id.keys():
		var extension_id: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(extension_id_variant).strip_edges()
		if extension_id.is_empty():
			continue
		var manifest: GFExtensionManifest = _get_manifest_from_map_or_null(manifest_by_id, extension_id)
		if manifest == null:
			continue
		var dependencies: PackedStringArray = PackedStringArray()
		for dependency_id: String in manifest.dependencies:
			var normalized_dependency_id: String = dependency_id.strip_edges()
			if (
				normalized_dependency_id.is_empty()
				or not GFExtensionManifest.is_valid_extension_id(normalized_dependency_id)
				or builtin_ids.has(normalized_dependency_id)
				or not manifest_by_id.has(normalized_dependency_id)
			):
				continue
			var _dependency_appended: bool = dependencies.append(normalized_dependency_id)
		result[extension_id] = dependencies
	return result


static func _array_to_packed_string_array(values: Array[String]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: String in values:
		var normalized_value: String = value.strip_edges()
		if normalized_value.is_empty() or result.has(normalized_value):
			continue
		var _appended: bool = result.append(normalized_value)
	return result


static func _dictionary_keys_to_packed_string_array(values: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in values.keys():
		var normalized_key: String = _GF_VARIANT_ACCESS_SCRIPT.to_text(key).strip_edges()
		if normalized_key.is_empty() or result.has(normalized_key):
			continue
		var _appended: bool = result.append(normalized_key)
	return result


static func _make_lookup_from_packed_string_array(values: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for value: String in values:
		result[value] = true
	return result


static func _get_graph_ordered_ids(report: Dictionary) -> PackedStringArray:
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array(report, "ordered_ids", PackedStringArray())


static func _get_graph_cycles(report: Dictionary) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var cycles: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(report, "dependency_cycles", [])
	for cycle_variant: Variant in cycles:
		if cycle_variant is PackedStringArray:
			var packed_cycle: PackedStringArray = cycle_variant
			result.append(packed_cycle.duplicate())
		elif cycle_variant is Array:
			var cycle_items: Array = cycle_variant
			result.append(_GF_VARIANT_ACCESS_SCRIPT.get_option_packed_string_array({ "cycle": cycle_items }, "cycle", PackedStringArray()))
	return result


static func _get_manifest_property(manifest: GFExtensionManifest, property_name: String) -> Variant:
	if manifest == null or not property_name in manifest:
		return null
	return manifest.get_indexed(NodePath(property_name))


static func _sorted_unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		var normalized_value: String = value.strip_edges()
		if normalized_value.is_empty() or result.has(normalized_value):
			continue
		result.append(normalized_value)
	result.sort()
	return result
