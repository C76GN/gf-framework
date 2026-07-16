## GFExtensionManifestDiscovery: GF 扩展 manifest 发现快照缓存。
##
## 在 `GFExtensionCatalog` 的无状态 manifest 读取能力之上维护快照缓存，
## 并通过扩展根目录、manifest 路径和 manifest 内容摘要自动判断缓存是否仍然有效。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
## [br]
## @layer kernel/extension
class_name GFExtensionManifestDiscovery
extends RefCounted


# --- 常量 ---

const _GF_EXTENSION_CATALOG_SCRIPT = preload("res://addons/gf/kernel/extension/gf_extension_catalog.gd")
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")


# --- 私有变量 ---

static var _snapshot_cache: Dictionary = {}
static var _has_snapshot_cache: bool = false
static var _cache_revision: int = 0


# --- 公共方法 ---

## 获取当前扩展 manifest 发现快照。
##
## 默认会复用仍然有效的快照；当扩展根目录、manifest 路径集合或 manifest 内容摘要变化时，
## 自动重新扫描并替换缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param extra_root_paths: 额外扩展集合根目录列表，每个根目录下一层为独立扩展目录。
## [br]
## @param options: 发现选项。
## [br]
## @schema options: Dictionary，支持 force_refresh；为 true 时跳过现有缓存并重新扫描。
## [br]
## @return manifest 发现快照。
## [br]
## @schema return: Dictionary，包含 ok、manifests、manifest_load_errors、manifest_validation_errors、invalid_manifests、external_roots、discovery_roots、signature、signature_hash、revision、manual、manifest_count、valid_manifest_count 和 invalid_manifest_count；错误条目包含 stage、extension_id、source_path 和 errors。
static func get_snapshot(
	extra_root_paths: Array[String] = [],
	options: Dictionary = {}
) -> Dictionary:
	var external_roots: Array[String] = _normalize_extra_root_paths(extra_root_paths)
	var signature: Dictionary = make_discovery_signature(external_roots)
	var force_refresh: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "force_refresh", false)
	if not force_refresh and _has_snapshot_cache and _snapshot_matches_signature(signature):
		return _duplicate_snapshot(_snapshot_cache)

	_store_snapshot(_load_snapshot(external_roots, signature))
	return _duplicate_snapshot(_snapshot_cache)


## 清空 manifest 发现快照缓存。
## [br]
## @api public
## [br]
## @since 8.0.0
static func clear_cache() -> void:
	_snapshot_cache.clear()
	_has_snapshot_cache = false


# --- 框架内部方法 ---

## 用给定 manifest 列表替换发现快照缓存。
##
## 手动写入的快照仍会绑定当前发现签名；后续同一 root 内 manifest 文件发生变化时，
## 普通 `get_snapshot()` 会自动丢弃手动快照并重新扫描真实文件。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param manifests: 要写入缓存的 manifest 列表。
## [br]
## @param options: 手动缓存选项。
## [br]
## @schema options: Dictionary，支持 external_roots，用于绑定手动快照对应的扩展集合根目录。
static func set_cached_manifests(
	manifests: Array[GFExtensionManifest],
	options: Dictionary = {}
) -> void:
	var external_roots: Array[String] = _normalize_extra_root_paths(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(options, "external_roots")
	)
	var signature: Dictionary = make_discovery_signature(external_roots)
	_store_snapshot(_make_snapshot(manifests, [], external_roots, signature, true))


## 获取当前缓存中的 manifest 读取错误。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @return 读取错误列表。
## [br]
## @schema return: Array of Dictionary entries with stage, extension_id, source_path, and errors.
static func get_cached_manifest_load_errors() -> Array[Dictionary]:
	if not _has_snapshot_cache:
		return []
	return _get_issue_records_from_value(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		_snapshot_cache,
		"manifest_load_errors",
		[]
	))


## 获取当前缓存中的 manifest 校验错误。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @return 校验错误列表。
## [br]
## @schema return: Array of Dictionary entries with stage, extension_id, source_path, and errors.
static func get_cached_manifest_validation_errors() -> Array[Dictionary]:
	if not _has_snapshot_cache:
		return []
	return _get_issue_records_from_value(_GF_VARIANT_ACCESS_SCRIPT.get_option_value(
		_snapshot_cache,
		"manifest_validation_errors",
		[]
	))


## 生成当前 manifest 发现签名。
## [br]
## @api framework_internal
## [br]
## @layer kernel/extension
## [br]
## @param extra_root_paths: 额外扩展集合根目录列表。
## [br]
## @return 发现签名。
## [br]
## @schema return: Dictionary containing roots, manifest_files, and hash.
static func make_discovery_signature(extra_root_paths: Array[String] = []) -> Dictionary:
	var external_roots: Array[String] = _normalize_extra_root_paths(extra_root_paths)
	var discovery_roots: Array[String] = _make_discovery_roots(external_roots)
	var manifest_files: Array[Dictionary] = []
	for root_path: String in discovery_roots:
		for manifest_path: String in _GF_EXTENSION_CATALOG_SCRIPT.get_manifest_paths(root_path):
			manifest_files.append(_make_manifest_file_signature(root_path, manifest_path))

	var signature_payload: Dictionary = {
		"roots": discovery_roots,
		"manifest_files": manifest_files,
	}
	return {
		"roots": discovery_roots,
		"manifest_files": manifest_files,
		"hash": JSON.stringify(signature_payload).sha256_text(),
	}


# --- 私有/辅助方法 ---

static func _load_snapshot(external_roots: Array[String], signature: Dictionary) -> Dictionary:
	var manifests: Array[GFExtensionManifest] = _GF_EXTENSION_CATALOG_SCRIPT.load_all_manifests(external_roots)
	var load_errors: Array[Dictionary] = _GF_EXTENSION_CATALOG_SCRIPT.get_last_manifest_load_errors()
	return _make_snapshot(manifests, load_errors, external_roots, signature, false)


static func _make_snapshot(
	manifests: Array[GFExtensionManifest],
	load_errors: Array[Dictionary],
	external_roots: Array[String],
	signature: Dictionary,
	manual: bool
) -> Dictionary:
	var snapshot_manifests: Array[GFExtensionManifest] = _duplicate_manifest_array(manifests)
	var load_issue_records: Array[Dictionary] = _make_manifest_load_issue_records(load_errors)
	var validation_issue_records: Array[Dictionary] = _make_manifest_validation_issue_records(snapshot_manifests)
	var invalid_manifest_records: Array[Dictionary] = _merge_issue_records(
		load_issue_records,
		validation_issue_records
	)
	var valid_manifest_count: int = snapshot_manifests.size() - validation_issue_records.size()
	if valid_manifest_count < 0:
		valid_manifest_count = 0
	return {
		"ok": load_issue_records.is_empty() and validation_issue_records.is_empty(),
		"manifests": snapshot_manifests,
		"manifest_load_errors": load_issue_records,
		"manifest_validation_errors": validation_issue_records,
		"invalid_manifests": invalid_manifest_records,
		"external_roots": external_roots.duplicate(),
		"discovery_roots": _make_discovery_roots(external_roots),
		"signature": signature.duplicate(true),
		"signature_hash": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(signature, "hash"),
		"revision": 0,
		"manual": manual,
		"manifest_count": snapshot_manifests.size(),
		"valid_manifest_count": valid_manifest_count,
		"invalid_manifest_count": invalid_manifest_records.size(),
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


static func _make_discovery_roots(external_roots: Array[String]) -> Array[String]:
	var roots: Array[String] = [_GF_EXTENSION_CATALOG_SCRIPT.EXTENSIONS_PATH]
	for root_path: String in external_roots:
		if root_path == _GF_EXTENSION_CATALOG_SCRIPT.EXTENSIONS_PATH or roots.has(root_path):
			continue
		roots.append(root_path)
	return roots


static func _normalize_extra_root_paths(root_paths: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var normalized_paths: PackedStringArray = _GF_PATH_TOOLS.normalize_root_paths(PackedStringArray(root_paths))
	for normalized_path: String in normalized_paths:
		if normalized_path == _GF_EXTENSION_CATALOG_SCRIPT.EXTENSIONS_PATH:
			continue
		result.append(normalized_path)
	return result


static func _make_manifest_file_signature(root_path: String, manifest_path: String) -> Dictionary:
	var normalized_path: String = _GF_PATH_TOOLS.normalize_resource_path(manifest_path)
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	var source_file: FileAccess = FileAccess.open(normalized_path, FileAccess.READ)
	if source_file == null:
		return {
			"root_path": normalized_root,
			"source_path": normalized_path,
			"exists": false,
			"size_bytes": 0,
			"content_sha256": "",
		}

	var source_text: String = source_file.get_as_text()
	var size_bytes: int = source_file.get_length()
	source_file.close()
	return {
		"root_path": normalized_root,
		"source_path": normalized_path,
		"exists": true,
		"size_bytes": size_bytes,
		"content_sha256": source_text.sha256_text(),
	}


static func _duplicate_snapshot(snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = snapshot.duplicate(true)
	result["manifests"] = _duplicate_manifest_array(_get_manifest_array_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "manifests", [])
	))
	result["manifest_load_errors"] = _get_load_errors_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "manifest_load_errors", [])
	)
	result["manifest_validation_errors"] = _get_issue_records_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "manifest_validation_errors", [])
	)
	result["invalid_manifests"] = _get_issue_records_from_value(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_value(snapshot, "invalid_manifests", [])
	)
	result["external_roots"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(snapshot, "external_roots")
	result["discovery_roots"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(snapshot, "discovery_roots")
	result["signature"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(snapshot, "signature")
	result["manifest_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		snapshot,
		"manifest_count",
		_get_manifest_array_from_value(result["manifests"]).size()
	)
	result["valid_manifest_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		snapshot,
		"valid_manifest_count",
		0
	)
	result["invalid_manifest_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		snapshot,
		"invalid_manifest_count",
		_get_issue_records_from_value(result["invalid_manifests"]).size()
	)
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


static func _get_load_errors_from_value(value: Variant) -> Array[Dictionary]:
	return _get_issue_records_from_value(value)


static func _make_manifest_load_issue_records(load_errors: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for load_error: Dictionary in load_errors:
		result.append(_make_issue_record(
			"load",
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(load_error, "extension_id"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(load_error, "source_path"),
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(load_error, "errors")
		))
	return result


static func _make_manifest_validation_issue_records(manifests: Array[GFExtensionManifest]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null:
			continue
		var errors: Array[String] = manifest.get_validation_errors()
		if errors.is_empty():
			continue
		result.append(_make_issue_record(
			"validation",
			manifest.id,
			manifest.source_path,
			errors
		))
	return result


static func _merge_issue_records(
	first_records: Array[Dictionary],
	second_records: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for first_record: Dictionary in first_records:
		result.append(first_record.duplicate(true))
	for second_record: Dictionary in second_records:
		result.append(second_record.duplicate(true))
	return result


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
