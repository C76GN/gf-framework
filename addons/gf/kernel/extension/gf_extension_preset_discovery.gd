## GFExtensionPresetDiscovery: GF 扩展 preset 发现快照缓存。
##
## 基于 manifest 集合和项目 preset 路径生成可缓存的 preset snapshot，
## 统一内置 preset、项目 preset、重复 ID、无效文件和未知扩展 ID 的报告边界。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
## [br]
## @layer kernel/extension
class_name GFExtensionPresetDiscovery
extends RefCounted


# --- 常量 ---

const _GF_EXTENSION_PRESET_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_preset.gd")
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_EXTENSION_JSON_FILE_READER_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_json_file_reader.gd")


# --- 私有变量 ---

static var _snapshot_cache: Dictionary = {}
static var _has_snapshot_cache: bool = false
static var _cache_revision: int = 0


# --- 公共方法 ---

## 获取当前扩展 preset 发现快照。
##
## 默认会复用仍然有效的快照；当 manifest ID/default 状态、preset 路径集合或 preset 文件内容变化时，
## 自动重新扫描并替换缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param manifests: 当前可发现的扩展 manifest 列表。
## [br]
## @param configured_paths: 项目配置中的 preset 路径列表，可包含无效路径以便生成诊断。
## [br]
## @param options: 发现选项。
## [br]
## @schema options: Dictionary，支持 force_refresh；为 true 时跳过现有缓存并重新扫描。
## [br]
## @return preset 发现快照。
## [br]
## @schema return: Dictionary，包含 ok、presets、report、configured_paths、signature、signature_hash、revision、preset_count 和 issue_count。
static func get_snapshot(
	manifests: Array[GFExtensionManifest] = [],
	configured_paths: Array[String] = [],
	options: Dictionary = {}
) -> Dictionary:
	var signature: Dictionary = make_discovery_signature(manifests, configured_paths)
	var force_refresh: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "force_refresh", false)
	if not force_refresh and _has_snapshot_cache and _snapshot_matches_signature(signature):
		return _duplicate_snapshot(_snapshot_cache)

	_store_snapshot(_make_snapshot(manifests, configured_paths, signature))
	return _duplicate_snapshot(_snapshot_cache)


## 清空 preset 发现快照缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
static func clear_cache() -> void:
	_snapshot_cache.clear()
	_has_snapshot_cache = false


# --- 框架内部方法 ---

## 生成当前 preset 发现签名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param manifests: 当前可发现的扩展 manifest 列表。
## [br]
## @param configured_paths: 项目配置中的 preset 路径列表。
## [br]
## @return 发现签名。
## [br]
## @schema return: Dictionary containing manifest_tokens, configured_paths, preset_files, and hash.
static func make_discovery_signature(
	manifests: Array[GFExtensionManifest] = [],
	configured_paths: Array[String] = []
) -> Dictionary:
	var signature_paths: Array[String] = _normalize_extension_preset_paths(configured_paths)
	var preset_files: Array[Dictionary] = []
	for preset_path: String in signature_paths:
		preset_files.append(_make_file_signature(preset_path))

	var signature_payload: Dictionary = {
		"manifest_tokens": _make_manifest_tokens(manifests),
		"configured_paths": configured_paths.duplicate(),
		"preset_files": preset_files,
	}
	return {
		"manifest_tokens": _make_manifest_tokens(manifests),
		"configured_paths": configured_paths.duplicate(),
		"preset_files": preset_files,
		"hash": JSON.stringify(signature_payload).sha256_text(),
	}


# --- 私有/辅助方法 ---

static func _make_snapshot(
	manifests: Array[GFExtensionManifest],
	configured_paths: Array[String],
	signature: Dictionary
) -> Dictionary:
	var source_manifests: Array[GFExtensionManifest] = _duplicate_manifest_array(manifests)
	var presets: Array[GFExtensionPreset] = _get_builtin_extension_presets(source_manifests)
	var seen_ids: Dictionary = _build_preset_id_lookup(presets)
	var manifest_by_id: Dictionary = _build_manifest_map(source_manifests)
	var valid_presets: Array[Dictionary] = []
	var invalid_presets: Array[Dictionary] = []
	var skipped_presets: Array[Dictionary] = []
	var duplicate_ids: PackedStringArray = PackedStringArray()
	var issues: PackedStringArray = PackedStringArray()
	for builtin_preset: GFExtensionPreset in presets:
		valid_presets.append(_preset_to_report_record(builtin_preset, "builtin"))

	var seen_paths: Dictionary = {}
	for raw_path: String in configured_paths:
		var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(raw_path)
		if not _extension_preset_path_is_supported(normalized_path):
			var path_errors: Array[String] = ["preset path must be a res:// JSON file"]
			invalid_presets.append(_make_preset_issue_record(raw_path, &"", path_errors))
			var _append_path_issue: bool = issues.append("%s: %s" % [raw_path, path_errors[0]])
			continue
		if seen_paths.has(normalized_path):
			skipped_presets.append(_make_preset_skip_record(normalized_path, &"", "duplicate_path"))
			continue

		seen_paths[normalized_path] = true
		var json_report: Dictionary = _GF_EXTENSION_JSON_FILE_READER_SCRIPT.read_object_report(
			normalized_path,
			_make_preset_json_reader_options()
		)
		var report_errors: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(json_report, "errors")
		var preset_data: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(json_report, "data")
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(json_report, "ok", false):
			var preset_id: StringName = StringName(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(preset_data, "id"))
			if report_errors.is_empty():
				report_errors.append("could not read preset JSON")
			invalid_presets.append(_make_preset_issue_record(normalized_path, preset_id, report_errors))
			var _append_report_issue: bool = issues.append("%s: %s" % [normalized_path, report_errors[0]])
			continue

		var preset: GFExtensionPreset = _GF_EXTENSION_PRESET_SCRIPT.from_dictionary(preset_data, normalized_path)
		var validation_errors: Array[String] = preset.get_validation_errors()
		_append_unknown_preset_extension_id_errors(validation_errors, preset.extension_ids, manifest_by_id)
		if not validation_errors.is_empty():
			invalid_presets.append(_make_preset_issue_record(normalized_path, preset.id, validation_errors))
			var _append_validation_issue: bool = issues.append("%s: %s" % [normalized_path, validation_errors[0]])
			continue
		if seen_ids.has(preset.id):
			if not duplicate_ids.has(String(preset.id)):
				var _append_duplicate_id: bool = duplicate_ids.append(String(preset.id))
			skipped_presets.append(_make_preset_skip_record(normalized_path, preset.id, "duplicate_id"))
			var _append_duplicate_issue: bool = issues.append("%s: duplicate preset id %s" % [
				normalized_path,
				String(preset.id),
			])
			continue

		presets.append(preset)
		seen_ids[preset.id] = true
		valid_presets.append(_preset_to_report_record(preset, "project"))

	var issue_count: int = invalid_presets.size() + skipped_presets.size()
	var report: Dictionary = {
		"ok": issue_count == 0,
		"preset_count": valid_presets.size(),
		"valid_presets": valid_presets,
		"invalid_presets": invalid_presets,
		"skipped_presets": skipped_presets,
		"duplicate_ids": duplicate_ids,
		"issue_count": issue_count,
		"issues": issues,
		"configured_paths": _normalize_extension_preset_paths(configured_paths),
	}
	return {
		"ok": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(report, "ok", false),
		"presets": _duplicate_preset_array(presets),
		"report": report,
		"configured_paths": _normalize_extension_preset_paths(configured_paths),
		"signature": signature.duplicate(true),
		"signature_hash": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(signature, "hash"),
		"revision": 0,
		"preset_count": valid_presets.size(),
		"issue_count": issue_count,
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
	result["presets"] = _duplicate_preset_array(_get_preset_array_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "presets", [])
	))
	result["report"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(snapshot, "report")
	result["configured_paths"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(snapshot, "configured_paths")
	result["signature"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(snapshot, "signature")
	result["preset_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		snapshot,
		"preset_count",
		_get_preset_array_from_value(result["presets"]).size()
	)
	result["issue_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(snapshot, "issue_count", 0)
	return result


static func _get_builtin_extension_presets(
	manifests: Array[GFExtensionManifest]
) -> Array[GFExtensionPreset]:
	var presets: Array[GFExtensionPreset] = []
	presets.append(_make_extension_preset({
		"id": "gf.default",
		"display_name": "默认选择",
		"description": "恢复 GF 当前默认扩展选择。",
		"extension_ids": _get_default_enabled_extension_ids_from_manifests(manifests),
		"tags": ["builtin"],
	}))
	presets.append(_make_extension_preset({
		"id": "gf.none",
		"display_name": "全部关闭",
		"description": "关闭所有可选 GF 扩展，只保留 kernel 与 standard 基础能力。",
		"extension_ids": [],
		"tags": ["builtin"],
	}))
	presets.append(_make_extension_preset({
		"id": "gf.all",
		"display_name": "全部扩展",
		"description": "启用当前可发现的全部 GF 扩展，适合本地评估而非默认发行策略。",
		"extension_ids": _get_all_extension_ids_from_manifests(manifests),
		"tags": ["builtin"],
	}))
	return presets


static func _make_extension_preset(data: Dictionary) -> GFExtensionPreset:
	return _GF_EXTENSION_PRESET_SCRIPT.from_dictionary(data)


static func _duplicate_preset_array(presets: Array[GFExtensionPreset]) -> Array[GFExtensionPreset]:
	var result: Array[GFExtensionPreset] = []
	for preset: GFExtensionPreset in presets:
		if preset == null:
			continue
		result.append(_duplicate_preset(preset))
	return result


static func _duplicate_preset(preset: GFExtensionPreset) -> GFExtensionPreset:
	return _GF_EXTENSION_PRESET_SCRIPT.from_dictionary(preset.to_dictionary(), preset.source_path)


static func _duplicate_manifest_array(manifests: Array[GFExtensionManifest]) -> Array[GFExtensionManifest]:
	var result: Array[GFExtensionManifest] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null:
			continue
		result.append(manifest.duplicate_manifest())
	return result


static func _get_preset_array_from_value(value: Variant) -> Array[GFExtensionPreset]:
	var result: Array[GFExtensionPreset] = []
	if not (value is Array):
		return result

	var values: Array = value
	for item: Variant in values:
		if item is GFExtensionPreset:
			var preset: GFExtensionPreset = item
			result.append(preset)
	return result


static func _get_default_enabled_extension_ids_from_manifests(
	manifests: Array[GFExtensionManifest]
) -> Array[String]:
	var ids: Array[String] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest.enabled_by_default:
			ids.append(manifest.id)
	return _sorted_unique(ids)


static func _get_all_extension_ids_from_manifests(manifests: Array[GFExtensionManifest]) -> Array[String]:
	var ids: Array[String] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null or manifest.id.strip_edges().is_empty():
			continue
		ids.append(manifest.id)
	return _sorted_unique(ids)


static func _append_unknown_preset_extension_id_errors(
	errors: Array[String],
	extension_ids: Array[String],
	manifest_by_id: Dictionary
) -> void:
	for extension_id: String in _get_unknown_enabled_ids(extension_ids, manifest_by_id):
		errors.append("extension_ids contains unknown extension id: %s" % extension_id)


static func _get_unknown_enabled_ids(extension_ids: Array[String], manifest_by_id: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for extension_id: String in extension_ids:
		var normalized_id: String = extension_id.strip_edges()
		if _is_builtin_extension_id(normalized_id):
			continue
		if not manifest_by_id.has(normalized_id) and not result.has(normalized_id):
			result.append(normalized_id)
	result.sort()
	return result


static func _build_manifest_map(manifests: Array[GFExtensionManifest]) -> Dictionary:
	var result: Dictionary = {}
	for manifest: GFExtensionManifest in manifests:
		if manifest == null or manifest.id.strip_edges().is_empty() or result.has(manifest.id):
			continue
		result[manifest.id] = manifest
	return result


static func _build_preset_id_lookup(presets: Array[GFExtensionPreset]) -> Dictionary:
	var result: Dictionary = {}
	for preset: GFExtensionPreset in presets:
		if preset != null and preset.id != &"":
			result[preset.id] = true
	return result


static func _preset_to_report_record(preset: GFExtensionPreset, source_kind: String) -> Dictionary:
	if preset == null:
		return {}
	return {
		"id": String(preset.id),
		"display_name": preset.display_name,
		"source_path": preset.source_path,
		"source_kind": source_kind,
		"extension_ids": preset.extension_ids.duplicate(),
		"tags": preset.tags.duplicate(),
	}


static func _make_preset_issue_record(
	source_path: String,
	preset_id: StringName,
	errors: Array[String]
) -> Dictionary:
	return {
		"id": String(preset_id),
		"source_path": source_path,
		"errors": errors.duplicate(),
	}


static func _make_preset_skip_record(
	source_path: String,
	preset_id: StringName,
	reason: String
) -> Dictionary:
	return {
		"id": String(preset_id),
		"source_path": source_path,
		"reason": reason,
	}


static func _normalize_extension_preset_paths(preset_paths: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for preset_path: String in preset_paths:
		var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(preset_path)
		if (
			normalized_path.is_empty()
			or not _extension_preset_path_is_supported(normalized_path)
			or result.has(normalized_path)
		):
			continue
		result.append(normalized_path)
	return result


static func _extension_preset_path_is_supported(path: String) -> bool:
	return path.begins_with("res://") and path.get_extension().to_lower() == "json"


static func _make_preset_json_reader_options() -> Dictionary:
	return {
		"empty_path_error": "preset path is empty",
		"open_error_prefix": "could not open preset",
		"read_error_prefix": "could not read preset",
		"parse_error_prefix": "could not parse preset JSON",
		"root_type_error": "preset JSON root must be an object",
	}


static func _make_manifest_tokens(manifests: Array[GFExtensionManifest]) -> Array[String]:
	var tokens: Array[String] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null:
			continue
		tokens.append("%s|%s|%s" % [
			manifest.id,
			str(manifest.enabled_by_default),
			manifest.source_path,
		])
	tokens.sort()
	return tokens


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


static func _sorted_unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		var normalized_value: String = value.strip_edges()
		if normalized_value.is_empty() or result.has(normalized_value):
			continue
		result.append(normalized_value)
	result.sort()
	return result


static func _is_builtin_extension_id(extension_id: String) -> bool:
	return extension_id == "gf.kernel" or extension_id == "gf.standard"
