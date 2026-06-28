@tool

## GFAudioLibraryTools: 音频素材库扫描、搜索和导入计划工具。
##
## 面向编辑器 Workspace、Inspector 和构建脚本复用；它只处理音频候选
## 文件、目标路径规划和文件复制，不接管运行时播放、事件命名或混音策略。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 5.0.0
class_name GFAudioLibraryTools
extends RefCounted


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_TEXT_SEARCH_SCORER = preload("res://addons/gf/standard/foundation/collections/gf_text_search_scorer.gd")

const _COPY_BUFFER_SIZE: int = 1_048_576

## 默认搜索字段。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_SEARCH_FIELDS: PackedStringArray = ["clip_id", "relative_path", "file_name", "source_path"]

## 默认单次复制计划可执行的文件数量上限。传入 0 表示不限制。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_MAX_COPY_FILES: int = 10000

## 默认单次复制计划可执行的总字节上限。传入 0 表示不限制。
## [br]
## @api public
## [br]
## @since 5.0.0
const DEFAULT_MAX_COPY_BYTES: int = 512 * 1024 * 1024


# --- 公共方法 ---

## 扫描音频素材库并返回结构化候选条目。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param root_path: 扫描起点，可为 res://、user:// 或本地绝对目录。
## [br]
## @param options: 可选项，支持 GFAudioBankTools.scan_audio_paths() 的扫描选项，以及 id_mode、base_path、path_separator、strip_extension。
## [br]
## @return 音频候选条目数组。
## [br]
## @schema options: Dictionary，可包含扫描选项和片段 ID 生成选项。
## [br]
## @schema return: Array[Dictionary]，元素包含 source_path、library_root、relative_path、directory、file_name、basename、extension 和 clip_id 字段。
static func scan_library(root_path: String, options: Dictionary = {}) -> Array[Dictionary]:
	var paths: PackedStringArray = GFAudioBankTools.scan_audio_paths(root_path, options)
	return build_entries(paths, root_path, options)


## 从已有路径列表构建音频素材库候选条目。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param paths: 音频文件路径列表。
## [br]
## @param library_root: 候选条目的素材库根目录。
## [br]
## @param options: 可选项，支持 id_mode、base_path、path_separator、strip_extension。
## [br]
## @return 音频候选条目数组。
## [br]
## @schema options: Dictionary，可包含片段 ID 生成选项。
## [br]
## @schema return: Array[Dictionary]，元素包含 source_path、library_root、relative_path、directory、file_name、basename、extension 和 clip_id 字段。
static func build_entries(
	paths: PackedStringArray,
	library_root: String,
	options: Dictionary = {}
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var normalized_root: String = _normalize_dir_path(library_root)
	for path: String in paths:
		if not GFAudioBankTools.is_audio_path(path, _get_extensions(options)):
			continue
		entries.append(_make_entry(path, normalized_root, options))
	return entries


## 按关键字过滤音频素材库候选条目。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param entries: scan_library() 或 build_entries() 返回的候选条目。
## [br]
## @param query: 空格分隔的搜索词。
## [br]
## @param options: 可选项，支持 fields、match_all 和 case_sensitive。
## [br]
## @return 过滤后的候选条目副本。
## [br]
## @schema entries: Array[Dictionary]，元素包含可搜索字段。
## [br]
## @schema options: Dictionary，可包含 fields: PackedStringArray、match_all: bool 和 case_sensitive: bool。
## [br]
## @schema return: Array[Dictionary]，元素为匹配的候选条目副本。
static func filter_entries(
	entries: Array[Dictionary],
	query: String,
	options: Dictionary = {}
) -> Array[Dictionary]:
	if query.strip_edges().is_empty():
		return _duplicate_entries(entries)

	var result: Array[Dictionary] = []
	var scorer_options: Dictionary = _make_text_search_options(options)
	for entry: Dictionary in entries:
		var report: Dictionary = _GF_TEXT_SEARCH_SCORER.score_candidate(query, entry, scorer_options)
		if GFVariantData.get_option_bool(report, "matched", false):
			result.append(entry.duplicate(true))
	return result


## 为素材库候选生成导入计划。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param entries: scan_library() 或 build_entries() 返回的候选条目。
## [br]
## @param target_root: 目标根目录，通常为 res://audio 下的目录。
## [br]
## @param options: 可选项，支持 preserve_structure、overwrite 和 check_source_exists。
## [br]
## @return 导入计划条目数组。
## [br]
## @schema entries: Array[Dictionary]，元素包含 source_path、relative_path 和 clip_id 字段。
## [br]
## @schema options: Dictionary，可包含 preserve_structure: bool、overwrite: bool 和 check_source_exists: bool。
## [br]
## @schema return: Array[Dictionary]，元素包含 source_path、target_path、relative_path、clip_id、extension、source_exists、target_exists、will_copy 和 reason 字段。
static func make_import_plan(
	entries: Array[Dictionary],
	target_root: String,
	options: Dictionary = {}
) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var normalized_target_root: String = _normalize_dir_path(target_root)
	var seen_target_paths: Dictionary = {}
	for entry: Dictionary in entries:
		var plan_entry: Dictionary = _make_plan_entry(entry, normalized_target_root, options)
		var target_path: String = GFVariantData.get_option_string(plan_entry, "target_path")
		if not target_path.is_empty():
			if seen_target_paths.has(target_path):
				plan_entry["will_copy"] = false
				plan_entry["reason"] = "duplicate_target"
			else:
				seen_target_paths[target_path] = true
		plan.append(plan_entry)
	return plan


## 按导入计划复制音频文件。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param plan: make_import_plan() 返回的导入计划。
## [br]
## @param options: 可选项，支持 overwrite、max_copy_files 与 max_copy_bytes。
## [br]
## @return 复制报告。
## [br]
## @schema plan: Array[Dictionary]，元素包含 source_path、target_path、will_copy 和 reason 字段。
## [br]
## @schema options: Dictionary，可包含 overwrite: bool、max_copy_files: int 与 max_copy_bytes: int；上限为 0 时表示不限制。
static func copy_import_plan(plan: Array[Dictionary], options: Dictionary = {}) -> GFValidationReport:
	var report: GFValidationReport = GFValidationReport.new("GFAudioLibraryTools.copy_import_plan")
	var overwrite: bool = GFVariantData.get_option_bool(options, "overwrite", false)
	var max_copy_files: int = maxi(GFVariantData.get_option_int(options, "max_copy_files", DEFAULT_MAX_COPY_FILES), 0)
	var max_copy_bytes: int = maxi(GFVariantData.get_option_int(options, "max_copy_bytes", DEFAULT_MAX_COPY_BYTES), 0)
	var planned_copy_count: int = _get_planned_copy_count(plan, overwrite)
	var planned_copy_bytes: int = _get_planned_copy_bytes(plan, overwrite)
	var copied_paths: PackedStringArray = PackedStringArray()
	var copied_count: int = 0
	var skipped_count: int = 0
	var error_count: int = 0

	_apply_copy_budget_metadata(report, planned_copy_count, planned_copy_bytes, max_copy_files, max_copy_bytes)
	if not _validate_copy_budget(report, planned_copy_count, planned_copy_bytes, max_copy_files, max_copy_bytes):
		_finalize_copy_report_metadata(report, copied_count, skipped_count, report.get_error_count(), copied_paths)
		return report

	for plan_entry: Dictionary in plan:
		var copy_result: Error = _copy_plan_entry(plan_entry, overwrite, report)
		if copy_result == OK:
			var target_path: String = GFVariantData.get_option_string(plan_entry, "target_path")
			_append_packed_string(copied_paths, target_path)
			copied_count += 1
		elif _is_copy_skip(copy_result):
			skipped_count += 1
		else:
			error_count += 1

	_finalize_copy_report_metadata(report, copied_count, skipped_count, error_count, copied_paths)
	return report


## 从导入计划收集目标路径。
## [br]
## @api public
## [br]
## @since 5.0.0
## [br]
## @param plan: make_import_plan() 返回的导入计划。
## [br]
## @param only_copyable: 为 true 时只返回 will_copy 为 true 的条目。
## [br]
## @return 去重后的目标路径列表。
## [br]
## @schema plan: Array[Dictionary]，元素包含 target_path 和 will_copy 字段。
static func get_plan_target_paths(plan: Array[Dictionary], only_copyable: bool = false) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for plan_entry: Dictionary in plan:
		if only_copyable and not GFVariantData.get_option_bool(plan_entry, "will_copy"):
			continue
		var target_path: String = GFVariantData.get_option_string(plan_entry, "target_path")
		if not target_path.is_empty() and not result.has(target_path):
			_append_packed_string(result, target_path)
	return result


# --- 私有/辅助方法 ---

static func _make_entry(path: String, library_root: String, options: Dictionary) -> Dictionary:
	var source_path: String = _normalize_resource_path(path)
	var relative_path: String = _make_safe_relative_path(source_path, library_root)
	var file_name: String = source_path.get_file()
	var id_options: Dictionary = _make_clip_id_options(options, library_root)
	return {
		"source_path": source_path,
		"library_root": library_root,
		"relative_path": relative_path,
		"directory": _get_relative_directory(relative_path),
		"file_name": file_name,
		"basename": file_name.get_basename(),
		"extension": source_path.get_extension().to_lower(),
		"clip_id": GFAudioBankTools.make_clip_id(source_path, id_options),
	}


static func _make_clip_id_options(options: Dictionary, library_root: String) -> Dictionary:
	var id_options: Dictionary = GFVariantData.to_dictionary(options)
	if GFVariantData.get_option_value(id_options, "id_mode", null) == null:
		id_options["id_mode"] = GFAudioBankTools.ClipIdMode.RELATIVE_PATH
	if GFVariantData.get_option_string(id_options, "base_path", "").is_empty():
		id_options["base_path"] = library_root
	return id_options


static func _make_plan_entry(entry: Dictionary, target_root: String, options: Dictionary) -> Dictionary:
	var source_path: String = GFVariantData.get_option_string(entry, "source_path")
	var relative_path: String = _get_entry_relative_path(entry)
	var target_relative_path: String = _make_target_relative_path(entry, options)
	var target_path: String = _join_path(target_root, target_relative_path)
	var source_exists: bool = _file_exists(source_path)
	var target_exists: bool = _file_exists(target_path)
	var reason: String = _get_plan_skip_reason(
		source_path,
		target_root,
		target_path,
		source_exists,
		target_exists,
		options
	)

	return {
		"source_path": source_path,
		"target_path": target_path,
		"relative_path": relative_path,
		"clip_id": GFVariantData.get_option_string_name(entry, "clip_id"),
		"extension": source_path.get_extension().to_lower(),
		"source_exists": source_exists,
		"target_exists": target_exists,
		"will_copy": reason.is_empty(),
		"reason": reason,
	}


static func _get_plan_skip_reason(
	source_path: String,
	target_root: String,
	target_path: String,
	source_exists: bool,
	target_exists: bool,
	options: Dictionary
) -> String:
	if source_path.is_empty():
		return "empty_source_path"
	if target_root.is_empty():
		return "empty_target_root"
	if target_path.is_empty():
		return "empty_target_path"
	if source_path == target_path:
		return "same_path"
	if not GFAudioBankTools.is_audio_path(source_path, _get_extensions(options)):
		return "invalid_audio_path"
	if GFVariantData.get_option_bool(options, "check_source_exists", true) and not source_exists:
		return "missing_source"
	if target_exists and not GFVariantData.get_option_bool(options, "overwrite", false):
		return "target_exists"
	return ""


static func _copy_plan_entry(
	plan_entry: Dictionary,
	overwrite: bool,
	report: GFValidationReport
) -> Error:
	var source_path: String = GFVariantData.get_option_string(plan_entry, "source_path")
	var target_path: String = GFVariantData.get_option_string(plan_entry, "target_path")
	var reason: String = GFVariantData.get_option_string(plan_entry, "reason")
	if not GFVariantData.get_option_bool(plan_entry, "will_copy") and not (reason == "target_exists" and overwrite):
		var skip_reason: String = reason if not reason.is_empty() else "not_copyable"
		_add_report_warning(report, StringName(skip_reason), "Audio import plan entry is not copyable.", source_path, target_path)
		return ERR_SKIP
	if source_path.is_empty() or target_path.is_empty():
		_add_report_error(report, &"invalid_import_path", "Audio import path is empty.", source_path, target_path)
		return ERR_INVALID_PARAMETER
	if source_path == target_path:
		_add_report_warning(report, &"same_path", "Audio import source and target are the same path.", source_path, target_path)
		return ERR_SKIP
	if not _file_exists(source_path):
		_add_report_error(report, &"missing_source", "Audio import source file does not exist.", source_path, target_path)
		return ERR_FILE_NOT_FOUND
	if _file_exists(target_path) and not overwrite:
		_add_report_warning(report, &"target_exists", "Audio import target already exists.", source_path, target_path)
		return ERR_SKIP

	var ensure_error: Error = _ensure_parent_dir(target_path)
	if ensure_error != OK:
		_add_report_error(
			report,
			&"target_directory_error",
			"Audio import target directory could not be created.",
			source_path,
			target_path,
			{ "error": ensure_error }
		)
		return ensure_error

	var copy_error: Error = _copy_file(source_path, target_path)
	if copy_error != OK:
		_add_report_error(
			report,
			&"copy_failed",
			"Audio import file copy failed.",
			source_path,
			target_path,
			{ "error": copy_error }
		)
	return copy_error


static func _get_planned_copy_count(plan: Array[Dictionary], overwrite: bool) -> int:
	var count: int = 0
	for plan_entry: Dictionary in plan:
		if _is_copy_budget_candidate(plan_entry, overwrite):
			count += 1
	return count


static func _get_planned_copy_bytes(plan: Array[Dictionary], overwrite: bool) -> int:
	var total_bytes: int = 0
	for plan_entry: Dictionary in plan:
		if not _is_copy_budget_candidate(plan_entry, overwrite):
			continue
		total_bytes += _get_file_size(GFVariantData.get_option_string(plan_entry, "source_path"))
	return total_bytes


static func _is_copy_budget_candidate(plan_entry: Dictionary, overwrite: bool) -> bool:
	if GFVariantData.get_option_bool(plan_entry, "will_copy"):
		return true
	return overwrite and GFVariantData.get_option_string(plan_entry, "reason") == "target_exists"


static func _get_file_size(path: String) -> int:
	if path.is_empty() or not FileAccess.file_exists(path):
		return 0

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var length: int = file.get_length()
	file.close()
	return length


static func _apply_copy_budget_metadata(
	report: GFValidationReport,
	planned_copy_count: int,
	planned_copy_bytes: int,
	max_copy_files: int,
	max_copy_bytes: int
) -> void:
	report.metadata["planned_copy_count"] = planned_copy_count
	report.metadata["planned_copy_bytes"] = planned_copy_bytes
	report.metadata["max_copy_files"] = max_copy_files
	report.metadata["max_copy_bytes"] = max_copy_bytes


static func _validate_copy_budget(
	report: GFValidationReport,
	planned_copy_count: int,
	planned_copy_bytes: int,
	max_copy_files: int,
	max_copy_bytes: int
) -> bool:
	var ok: bool = true
	if max_copy_files > 0 and planned_copy_count > max_copy_files:
		_add_report_error(
			report,
			&"copy_file_count_limit_exceeded",
			"Audio import copy plan exceeds the configured file count limit.",
			planned_copy_count,
			"",
			{
				"planned_copy_count": planned_copy_count,
				"max_copy_files": max_copy_files,
			}
		)
		ok = false
	if max_copy_bytes > 0 and planned_copy_bytes > max_copy_bytes:
		_add_report_error(
			report,
			&"copy_byte_limit_exceeded",
			"Audio import copy plan exceeds the configured total byte limit.",
			planned_copy_bytes,
			"",
			{
				"planned_copy_bytes": planned_copy_bytes,
				"max_copy_bytes": max_copy_bytes,
			}
		)
		ok = false
	return ok


static func _finalize_copy_report_metadata(
	report: GFValidationReport,
	copied_count: int,
	skipped_count: int,
	error_count: int,
	copied_paths: PackedStringArray
) -> void:
	report.metadata["copied_count"] = copied_count
	report.metadata["skipped_count"] = skipped_count
	report.metadata["error_count"] = error_count
	report.metadata["copied_paths"] = copied_paths


static func _copy_file(source_path: String, target_path: String) -> Error:
	var temp_path: String = _make_copy_sidecar_path(target_path, ".tmp")
	var backup_path: String = _make_copy_sidecar_path(target_path, ".bak")
	_remove_file_if_exists(temp_path)
	_remove_file_if_exists(backup_path)

	var copy_error: Error = _copy_file_to_path(source_path, temp_path)
	if copy_error != OK:
		_remove_file_if_exists(temp_path)
		return copy_error

	var replace_error: Error = _replace_file_with_backup(temp_path, target_path, backup_path)
	if replace_error != OK:
		_remove_file_if_exists(temp_path)
		return replace_error

	_remove_file_if_exists(backup_path)
	return OK


static func _copy_file_to_path(source_path: String, target_path: String) -> Error:
	var source_file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source_file == null:
		return FileAccess.get_open_error()

	var target_file: FileAccess = FileAccess.open(target_path, FileAccess.WRITE)
	if target_file == null:
		source_file.close()
		return FileAccess.get_open_error()

	while source_file.get_position() < source_file.get_length():
		var remaining_bytes: int = source_file.get_length() - source_file.get_position()
		var buffer_size: int = mini(_COPY_BUFFER_SIZE, remaining_bytes)
		var buffer: PackedByteArray = source_file.get_buffer(buffer_size)
		if buffer.is_empty() and remaining_bytes > 0:
			source_file.close()
			target_file.close()
			return ERR_FILE_CANT_READ

		var store_result: Variant = target_file.store_buffer(buffer)
		if store_result is bool and not store_result:
			source_file.close()
			target_file.close()
			return ERR_FILE_CANT_WRITE

	source_file.close()
	target_file.close()
	return OK


static func _replace_file_with_backup(temp_path: String, target_path: String, backup_path: String) -> Error:
	var had_target: bool = _file_exists(target_path)
	if had_target:
		var backup_error: Error = DirAccess.rename_absolute(_to_absolute_path(target_path), _to_absolute_path(backup_path))
		if backup_error != OK:
			return backup_error

	var replace_error: Error = DirAccess.rename_absolute(_to_absolute_path(temp_path), _to_absolute_path(target_path))
	if replace_error != OK:
		if had_target:
			var _restore_error: Error = DirAccess.rename_absolute(_to_absolute_path(backup_path), _to_absolute_path(target_path))
		return replace_error

	return OK


static func _make_copy_sidecar_path(target_path: String, suffix: String) -> String:
	return "%s.gf-copy-%d%s" % [target_path, Time.get_ticks_usec(), suffix]


static func _remove_file_if_exists(path: String) -> void:
	if _file_exists(path):
		var _remove_result: Error = DirAccess.remove_absolute(_to_absolute_path(path))


static func _make_target_relative_path(entry: Dictionary, options: Dictionary) -> String:
	if not GFVariantData.get_option_bool(options, "preserve_structure", true):
		return GFVariantData.get_option_string(entry, "file_name")

	var relative_path: String = _get_entry_relative_path(entry)
	if _is_safe_relative_path(relative_path):
		return relative_path
	return GFVariantData.get_option_string(entry, "file_name")


static func _get_entry_relative_path(entry: Dictionary) -> String:
	var relative_path: String = GFVariantData.get_option_string(entry, "relative_path")
	if not relative_path.is_empty():
		return relative_path.replace("\\", "/")
	return GFVariantData.get_option_string(entry, "source_path").get_file()


static func _make_safe_relative_path(path: String, root_path: String) -> String:
	var relative_path: String = _GF_PATH_TOOLS.make_relative_path(path, root_path)
	if _is_safe_relative_path(relative_path):
		return relative_path
	return path.get_file()


static func _is_safe_relative_path(path: String) -> bool:
	var normalized_path: String = path.replace("\\", "/").strip_edges()
	if normalized_path.is_empty():
		return false
	if normalized_path.begins_with("/") or normalized_path.begins_with("../"):
		return false
	if normalized_path.contains("/../"):
		return false
	if normalized_path.contains("://"):
		return false
	return true


static func _get_relative_directory(relative_path: String) -> String:
	var directory: String = relative_path.get_base_dir()
	if directory == ".":
		return ""
	return directory


static func _make_text_search_options(options: Dictionary) -> Dictionary:
	var fields: PackedStringArray = GFVariantData.get_option_packed_string_array(
		options,
		"fields",
		DEFAULT_SEARCH_FIELDS
	)
	return {
		"fields": fields,
		"require_all_tokens": GFVariantData.get_option_bool(options, "match_all", true),
		"case_sensitive": GFVariantData.get_option_bool(options, "case_sensitive", false),
		"duplicate_candidate": false,
	}


static func _duplicate_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		result.append(entry.duplicate(true))
	return result


static func _get_extensions(options: Dictionary) -> PackedStringArray:
	return _normalize_extensions(
		GFVariantData.get_option_packed_string_array(options, "extensions", GFAudioBankTools.AUDIO_EXTENSIONS)
	)


static func _normalize_extensions(extensions: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for extension: String in extensions:
		var normalized: String = extension.strip_edges().to_lower()
		if normalized.begins_with("."):
			normalized = normalized.substr(1)
		if not normalized.is_empty() and not result.has(normalized):
			_append_packed_string(result, normalized)
	return result


static func _normalize_resource_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_resource_path(path, "", false)


static func _normalize_dir_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_root_path(path, "", false)


static func _join_path(root_path: String, relative_path: String) -> String:
	if root_path.is_empty() or relative_path.is_empty():
		return ""
	return root_path.path_join(relative_path)


static func _file_exists(path: String) -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)


static func _ensure_parent_dir(path: String) -> Error:
	var parent_dir: String = path.get_base_dir()
	if parent_dir.is_empty() or parent_dir == ".":
		return OK
	return DirAccess.make_dir_recursive_absolute(_to_absolute_path(parent_dir))


static func _to_absolute_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


static func _is_copy_skip(error: Error) -> bool:
	return error == ERR_SKIP or error == ERR_ALREADY_EXISTS


static func _add_report_warning(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	metadata: Dictionary = {}
) -> void:
	var _issue: RefCounted = report.add_warning(kind, message, key, path, metadata)


static func _add_report_error(
	report: GFValidationReport,
	kind: StringName,
	message: String,
	key: Variant = null,
	path: String = "",
	metadata: Dictionary = {}
) -> void:
	var _issue: RefCounted = report.add_error(kind, message, key, path, metadata)


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	if value.is_empty() or target.has(value):
		return
	var _appended: bool = target.append(value)
