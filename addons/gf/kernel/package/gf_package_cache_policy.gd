@tool

## GF Package 缓存策略与所有权边界。
##
## 该内部类型统一解析项目本地、外部只读和外部共享读写模式，并通过版本化 marker
## 确认目录属于 GF package cache。缓存内容始终视为不可信派生数据。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since 8.0.0
## [br]
## @layer kernel/package
class_name GFPackageCachePolicy
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PACKAGE_TRANSACTION_ENGINE = preload("res://addons/gf/kernel/package/gf_package_transaction_engine.gd")
const _SCHEMA_CONTRACT_PATH: String = "res://addons/gf/kernel/package/gf_package_cache_schema.json"
const _SCHEMA_VERSION: int = 1
const _LAYOUT_VERSION: int = 1
const _MARKER_FILE_NAME: String = ".gf-package-cache.json"
const _MARKER_KIND: String = "gf_package_cache"
const _CREATED_BY: String = "gf_package_manager"
const _LOCAL_CACHE_RELATIVE_PATH: String = ".gf/package_cache"
const _WORKSPACE_RELATIVE_PATH: String = ".gf/package_workspace"

## 项目私有缓存模式。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const MODE_PROJECT_LOCAL: String = "project_local"

## 外部只读缓存模式。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const MODE_EXTERNAL_READ_ONLY: String = "external_read_only"

## 外部共享读写缓存模式。
## [br]
## @api framework_internal
## [br]
## @layer kernel/package
const MODE_EXTERNAL_SHARED_RW: String = "external_shared_rw"


# --- 公共方法 ---

## 解析并验证一次 package cache 使用上下文。
## [br]
## @api framework_internal
## [br]
## @param project_root: 目标项目绝对路径。
## [br]
## @param options: cache_mode 与 cache_dir 选项。
## [br]
## @schema options: Dictionary，可包含 cache_mode、cache_dir。
## [br]
## @param issues: 接收策略、marker 和目录错误。
## [br]
## @return 内部缓存上下文。
## [br]
## @schema return: Dictionary，包含 mode、artifact_read_roots、artifact_write_root、workspace_root 和 marker 状态。
static func resolve_context(project_root: String, options: Dictionary, issues: PackedStringArray) -> Dictionary:
	var schema: Dictionary = _load_schema(issues)
	var normalized_project_root: String = _normalize_path(project_root)
	var local_root: String = normalized_project_root.path_join(_LOCAL_CACHE_RELATIVE_PATH).replace("\\", "/").simplify_path()
	var workspace_root: String = normalized_project_root.path_join(_WORKSPACE_RELATIVE_PATH).replace("\\", "/").simplify_path()
	var mode: String = _GF_VARIANT_ACCESS.get_option_string(options, "cache_mode", MODE_PROJECT_LOCAL).strip_edges()
	if mode.is_empty():
		mode = MODE_PROJECT_LOCAL
	var cache_dir: String = _GF_VARIANT_ACCESS.get_option_string(options, "cache_dir").strip_edges()
	var context: Dictionary = _make_context(mode, local_root, workspace_root, normalized_project_root)
	if schema.is_empty():
		return context
	if (
		normalized_project_root.is_empty()
		or _path_has_link_component(normalized_project_root)
		or FileAccess.file_exists(normalized_project_root)
	):
		var _append_project: bool = issues.append("Package cache project root is invalid or crosses a filesystem link: %s" % normalized_project_root)
		return context
	for owned_root: String in [local_root, workspace_root]:
		if not _is_path_inside(normalized_project_root, owned_root) or _path_has_link_component(owned_root):
			var _append_owned_root: bool = issues.append("Project package cache/workspace root leaves project_root or crosses a filesystem link: %s" % owned_root)
	if not issues.is_empty():
		return context
	if not _schema_modes(schema).has(mode):
		var _append_mode: bool = issues.append("Unsupported package cache mode: %s" % mode)
		return context

	if mode == MODE_PROJECT_LOCAL:
		if not cache_dir.is_empty():
			var requested_local_root: String = _resolve_path(cache_dir, normalized_project_root)
			if requested_local_root != local_root:
				var _append_local_override: bool = issues.append("project_local cache mode only permits the project-owned cache directory: %s" % local_root)
				return context
		_configure_project_local_context(context, local_root)
		_validate_existing_local_marker(local_root, context, issues)
		return context

	if cache_dir.is_empty():
		var _append_missing: bool = issues.append("External package cache mode requires cache_dir.")
		return context
	if not cache_dir.is_absolute_path():
		var _append_absolute: bool = issues.append("External package cache directory must be an absolute path: %s" % cache_dir)
		return context
	var external_root: String = _normalize_path(cache_dir)
	if _is_path_inside(normalized_project_root, external_root):
		var _append_inside: bool = issues.append("External package cache directory must be outside project_root; use project_local mode for project-owned cache.")
		return context
	if _path_has_link_component(external_root):
		var _append_external_link: bool = issues.append("External package cache directory crosses a filesystem link: %s" % external_root)
		return context
	context["external"] = true
	context["external_root"] = external_root
	context["marker_path"] = external_root.path_join(_MARKER_FILE_NAME).replace("\\", "/")
	if not _validate_marker(external_root, issues):
		return context
	context["marker_valid"] = true
	if mode == MODE_EXTERNAL_READ_ONLY:
		context["read_only"] = true
		context["artifact_read_roots"] = [external_root, local_root]
		context["artifact_write_root"] = local_root
		_validate_existing_local_marker(local_root, context, issues)
	else:
		context["artifact_read_roots"] = [external_root]
		context["artifact_write_root"] = external_root
	return context


## 初始化一个显式外部 package cache 根目录。
## [br]
## @api framework_internal
## [br]
## @param cache_dir: 待初始化的绝对目录；已有非 marker 内容时拒绝接管。
## [br]
## @return 初始化报告。
## [br]
## @schema return: Dictionary，包含 schema_version、ok、operation、cache_dir、marker_path、created、issues。
static func initialize_external_cache(cache_dir: String) -> Dictionary:
	var issues: PackedStringArray = PackedStringArray()
	var created: bool = false
	var normalized_root: String = ""
	if cache_dir.strip_edges().is_empty():
		var _append_missing: bool = issues.append("External package cache directory is required.")
	elif not cache_dir.is_absolute_path():
		var _append_absolute: bool = issues.append("External package cache directory must be an absolute path: %s" % cache_dir)
	else:
		normalized_root = _normalize_path(cache_dir)
		if not _cache_root_is_safe(normalized_root):
			var _append_unsafe: bool = issues.append("Refusing to initialize unsafe package cache root: %s" % normalized_root)
		elif _path_has_link_component(normalized_root):
			var _append_link: bool = issues.append("Package cache root crosses a filesystem link: %s" % normalized_root)
		elif FileAccess.file_exists(normalized_root):
			var _append_file: bool = issues.append("Package cache root is a file: %s" % normalized_root)
		elif DirAccess.dir_exists_absolute(normalized_root):
			var marker_path: String = normalized_root.path_join(_MARKER_FILE_NAME).replace("\\", "/")
			if FileAccess.file_exists(marker_path):
				var _marker_valid: bool = _validate_marker(normalized_root, issues)
			elif not _directory_is_empty(normalized_root):
				var _append_non_empty: bool = issues.append("Refusing to claim a non-empty directory without a GF package cache marker: %s" % normalized_root)
			else:
				if _path_has_link_component(normalized_root):
					var _append_created_link: bool = issues.append("Created package cache root crosses a filesystem link: %s" % normalized_root)
					return _make_initialize_report(normalized_root, false, issues)
				created = _write_marker(normalized_root, issues)
		else:
			var make_error: Error = DirAccess.make_dir_recursive_absolute(normalized_root)
			if make_error != OK:
				var _append_make: bool = issues.append("Could not create package cache directory: %s" % error_string(make_error))
			else:
				created = _write_marker(normalized_root, issues)
	var marker_path_result: String = ""
	if not normalized_root.is_empty():
		marker_path_result = normalized_root.path_join(_MARKER_FILE_NAME).replace("\\", "/")
	return {
		"schema_version": _SCHEMA_VERSION,
		"ok": issues.is_empty(),
		"operation": "cache_init",
		"cache_dir": normalized_root,
		"marker_path": marker_path_result,
		"created": created,
		"issue_count": issues.size(),
		"issues": _packed_to_array(issues),
	}


## 返回可安全写入操作结果的缓存上下文快照。
## [br]
## @api framework_internal
## [br]
## @param context: resolve_context() 返回的内部上下文。
## [br]
## @schema context: Dictionary，内部 package cache context。
## [br]
## @return JSON-safe 缓存策略报告。
## [br]
## @schema return: Dictionary，字段由 gf_package_cache_schema.json 的 context_report_fields 固定。
static func make_report(context: Dictionary) -> Dictionary:
	return {
		"schema_version": _SCHEMA_VERSION,
		"mode": _GF_VARIANT_ACCESS.get_option_string(context, "mode", MODE_PROJECT_LOCAL),
		"external": _GF_VARIANT_ACCESS.get_option_bool(context, "external", false),
		"read_only": _GF_VARIANT_ACCESS.get_option_bool(context, "read_only", false),
		"artifact_read_roots": _packed_to_array(_GF_VARIANT_ACCESS.get_option_packed_string_array(context, "artifact_read_roots")),
		"artifact_write_root": _GF_VARIANT_ACCESS.get_option_string(context, "artifact_write_root"),
		"workspace_root": _GF_VARIANT_ACCESS.get_option_string(context, "workspace_root"),
		"marker_path": _GF_VARIANT_ACCESS.get_option_string(context, "marker_path"),
		"marker_valid": _GF_VARIANT_ACCESS.get_option_bool(context, "marker_valid", false),
	}


## 确认当前写根已具备有效 GF marker，并在项目本地根首次写入时惰性创建 marker。
## [br]
## @api framework_internal
## [br]
## @param context: resolve_context() 返回的内部上下文。
## [br]
## @schema context: Dictionary，包含 mode、artifact_write_root 和 marker 状态。
## [br]
## @param issues: 接收 marker 创建或校验错误。
## [br]
## @return 当前上下文是否允许安全写入 artifact。
static func ensure_write_root(context: Dictionary, issues: PackedStringArray) -> bool:
	var write_root: String = _GF_VARIANT_ACCESS.get_option_string(context, "artifact_write_root")
	if write_root.is_empty():
		var _append_root: bool = issues.append("Package cache context does not permit artifact writes.")
		return false
	if not _context_path_is_safe(context, write_root):
		var _append_unsafe: bool = issues.append("Package cache write root leaves its context boundary or crosses a filesystem link: %s" % write_root)
		return false
	var mode: String = _GF_VARIANT_ACCESS.get_option_string(context, "mode", MODE_PROJECT_LOCAL)
	if mode == MODE_EXTERNAL_SHARED_RW:
		return _validate_marker(write_root, issues)
	var marker_path: String = write_root.path_join(_MARKER_FILE_NAME).replace("\\", "/")
	var valid: bool = false
	if FileAccess.file_exists(marker_path):
		valid = _validate_marker(write_root, issues)
	else:
		valid = _write_marker(write_root, issues)
	if valid and mode == MODE_PROJECT_LOCAL:
		context["marker_valid"] = true
	return valid


# --- 私有/辅助方法 ---

static func _make_context(mode: String, local_root: String, workspace_root: String, project_root: String) -> Dictionary:
	return {
		"schema_version": _SCHEMA_VERSION,
		"mode": mode,
		"external": false,
		"read_only": false,
		"external_root": "",
		"artifact_read_roots": [],
		"artifact_write_root": "",
		"workspace_root": workspace_root,
		"project_root": project_root,
		"local_root": local_root,
		"marker_path": local_root.path_join(_MARKER_FILE_NAME).replace("\\", "/"),
		"marker_valid": false,
	}


static func _configure_project_local_context(context: Dictionary, local_root: String) -> void:
	context["artifact_read_roots"] = [local_root]
	context["artifact_write_root"] = local_root
	context["marker_path"] = local_root.path_join(_MARKER_FILE_NAME).replace("\\", "/")


static func _validate_existing_local_marker(
	local_root: String,
	context: Dictionary,
	issues: PackedStringArray
) -> void:
	var marker_path: String = local_root.path_join(_MARKER_FILE_NAME).replace("\\", "/")
	if not FileAccess.file_exists(marker_path):
		return
	if _validate_marker(local_root, issues):
		context["marker_valid"] = true


static func _validate_marker(cache_root: String, issues: PackedStringArray) -> bool:
	var marker_path: String = cache_root.path_join(_MARKER_FILE_NAME).replace("\\", "/")
	if _path_has_link_component(cache_root) or _path_has_link_component(marker_path):
		var _append_link: bool = issues.append("Package cache marker path crosses a filesystem link: %s" % marker_path)
		return false
	if not FileAccess.file_exists(marker_path):
		var _append_missing: bool = issues.append("External package cache is missing its GF marker; initialize it explicitly: %s" % cache_root)
		return false
	var marker: Dictionary = _read_json_dictionary(marker_path)
	if marker.is_empty():
		var _append_parse: bool = issues.append("Package cache marker is not a JSON object: %s" % marker_path)
		return false
	var valid: bool = true
	if _GF_VARIANT_ACCESS.get_option_int(marker, "schema_version", 0) != _SCHEMA_VERSION:
		var _append_schema: bool = issues.append("Unsupported package cache marker schema_version: %s" % marker_path)
		valid = false
	if _GF_VARIANT_ACCESS.get_option_string(marker, "kind") != _MARKER_KIND:
		var _append_kind: bool = issues.append("Package cache marker kind is invalid: %s" % marker_path)
		valid = false
	if _GF_VARIANT_ACCESS.get_option_int(marker, "layout_version", 0) != _LAYOUT_VERSION:
		var _append_layout: bool = issues.append("Unsupported package cache layout_version: %s" % marker_path)
		valid = false
	if _GF_VARIANT_ACCESS.get_option_string(marker, "cache_id").strip_edges().is_empty():
		var _append_id: bool = issues.append("Package cache marker cache_id is required: %s" % marker_path)
		valid = false
	if _GF_VARIANT_ACCESS.get_option_string(marker, "created_by") != _CREATED_BY:
		var _append_creator: bool = issues.append("Package cache marker created_by is invalid: %s" % marker_path)
		valid = false
	return valid


static func _write_marker(cache_root: String, issues: PackedStringArray) -> bool:
	if _path_has_link_component(cache_root):
		var _append_root_link: bool = issues.append("Package cache root crosses a filesystem link: %s" % cache_root)
		return false
	var make_error: Error = DirAccess.make_dir_recursive_absolute(cache_root)
	if make_error != OK:
		var _append_make: bool = issues.append("Could not create package cache directory: %s" % error_string(make_error))
		return false
	var marker_path: String = cache_root.path_join(_MARKER_FILE_NAME).replace("\\", "/")
	var temp_path: String = marker_path + ".tmp-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	if _path_has_link_component(cache_root) or _path_has_link_component(marker_path) or _path_has_link_component(temp_path):
		var _append_marker_link: bool = issues.append("Package cache marker path crosses a filesystem link: %s" % marker_path)
		return false
	var marker: Dictionary = {
		"schema_version": _SCHEMA_VERSION,
		"kind": _MARKER_KIND,
		"layout_version": _LAYOUT_VERSION,
		"cache_id": _make_cache_id(cache_root),
		"created_by": _CREATED_BY,
	}
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var _append_open: bool = issues.append("Could not write package cache marker: %s" % error_string(FileAccess.get_open_error()))
		return false
	var text: String = JSON.stringify(marker, "\t", false) + "\n"
	var _store_result: Variant = file.store_string(text)
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		var _remove_failed_temp: Error = DirAccess.remove_absolute(temp_path)
		var _append_write: bool = issues.append("Could not write package cache marker: %s" % error_string(write_error))
		return false
	if FileAccess.file_exists(marker_path):
		var _remove_existing: Error = DirAccess.remove_absolute(marker_path)
	var rename_error: Error = DirAccess.rename_absolute(temp_path, marker_path)
	if rename_error != OK:
		var _remove_temp: Error = DirAccess.remove_absolute(temp_path)
		var _append_rename: bool = issues.append("Could not finalize package cache marker: %s" % error_string(rename_error))
		return false
	return true


static func _load_schema(issues: PackedStringArray) -> Dictionary:
	var schema: Dictionary = _read_json_dictionary(_SCHEMA_CONTRACT_PATH)
	if schema.is_empty():
		var _append_missing: bool = issues.append("Package cache schema is missing or invalid: %s" % _SCHEMA_CONTRACT_PATH)
		return {}
	if _GF_VARIANT_ACCESS.get_option_int(schema, "schema_version", 0) != _SCHEMA_VERSION:
		var _append_schema: bool = issues.append("Unsupported package cache schema_version.")
		return {}
	if _GF_VARIANT_ACCESS.get_option_int(schema, "layout_version", 0) != _LAYOUT_VERSION:
		var _append_layout: bool = issues.append("Unsupported package cache layout_version.")
		return {}
	if _GF_VARIANT_ACCESS.get_option_string(schema, "marker_file") != _MARKER_FILE_NAME:
		var _append_marker: bool = issues.append("Package cache schema marker_file does not match the runtime contract.")
		return {}
	return schema


static func _schema_modes(schema: Dictionary) -> PackedStringArray:
	return _GF_VARIANT_ACCESS.get_option_packed_string_array(schema, "modes")


static func _read_json_dictionary(path: String) -> Dictionary:
	if _path_has_link_component(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var data: Dictionary = parsed
		return data
	return {}


static func _directory_is_empty(path: String) -> bool:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return false
	var list_error: Error = directory.list_dir_begin()
	if list_error != OK:
		return false
	var empty: bool = true
	while true:
		var item_name: String = directory.get_next()
		if item_name.is_empty():
			break
		if item_name != "." and item_name != "..":
			empty = false
			break
	directory.list_dir_end()
	return empty


static func _make_cache_id(cache_root: String) -> String:
	var source: String = "%s|%d|%d|%d" % [cache_root, OS.get_process_id(), Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var update_error: Error = context.update(source.to_utf8_buffer())
	if update_error != OK:
		return "%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var digest: PackedByteArray = context.finish()
	return digest.hex_encode()


static func _cache_root_is_safe(path: String) -> bool:
	var normalized: String = _normalize_path(path)
	return not normalized.is_empty() and normalized != "/" and normalized.length() >= 4


static func _resolve_path(path: String, base_root: String) -> String:
	var text: String = path.strip_edges()
	if text.begins_with("res://") or text.begins_with("user://"):
		return _normalize_path(ProjectSettings.globalize_path(text))
	if text.is_absolute_path():
		return _normalize_path(text)
	return _normalize_path(base_root.path_join(text))


static func _normalize_path(path: String) -> String:
	var normalized: String = path.strip_edges().replace("\\", "/").simplify_path()
	while normalized.length() > 1 and normalized.ends_with("/") and not _is_windows_drive_root(normalized):
		normalized = normalized.substr(0, normalized.length() - 1)
	return normalized


static func _is_windows_drive_root(path: String) -> bool:
	return path.length() == 3 and path[1] == ":" and path.ends_with("/")


static func _is_path_inside(root_path: String, child_path: String) -> bool:
	var root: String = _normalize_path(root_path)
	var child: String = _normalize_path(child_path)
	if OS.get_name() == "Windows":
		root = root.to_lower()
		child = child.to_lower()
	return child == root or child.begins_with(root + "/")


static func _context_path_is_safe(context: Dictionary, path: String) -> bool:
	var normalized_path: String = _normalize_path(path)
	if normalized_path.is_empty() or _path_has_link_component(normalized_path):
		return false
	var project_root: String = _GF_VARIANT_ACCESS.get_option_string(context, "project_root")
	var local_root: String = _GF_VARIANT_ACCESS.get_option_string(context, "local_root")
	var workspace_root: String = _GF_VARIANT_ACCESS.get_option_string(context, "workspace_root")
	var external_root: String = _GF_VARIANT_ACCESS.get_option_string(context, "external_root")
	return (
		(not local_root.is_empty() and _is_path_inside(local_root, normalized_path) and _is_path_inside(project_root, normalized_path))
		or (not workspace_root.is_empty() and _is_path_inside(workspace_root, normalized_path) and _is_path_inside(project_root, normalized_path))
		or (not external_root.is_empty() and _is_path_inside(external_root, normalized_path))
	)


static func _path_has_link_component(path: String) -> bool:
	return _GF_PACKAGE_TRANSACTION_ENGINE._path_has_link_component(path)


static func _make_initialize_report(cache_root: String, created: bool, issues: PackedStringArray) -> Dictionary:
	return {
		"schema_version": _SCHEMA_VERSION,
		"ok": issues.is_empty(),
		"operation": "cache_init",
		"cache_dir": cache_root,
		"marker_path": cache_root.path_join(_MARKER_FILE_NAME).replace("\\", "/") if not cache_root.is_empty() else "",
		"created": created,
		"issue_count": issues.size(),
		"issues": _packed_to_array(issues),
	}


static func _packed_to_array(values: PackedStringArray) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		result.append(value)
	return result
