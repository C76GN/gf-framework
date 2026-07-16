## GFProjectReferenceScanner: 项目资源引用扫描服务。
##
## 面向编辑器、CI 和框架诊断流程扫描项目资源与文本源码，按目标根目录和
## class_name 输出 verified、strong 与 weak 分级引用，并在文件数量、
## 目录深度和读取字节预算耗尽时返回 fail-closed 诊断。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
## [br]
## @layer kernel/core
class_name GFProjectReferenceScanner
extends RefCounted


const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")


# --- 常量 ---

## Godot 依赖图确认的资源引用。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_STRENGTH_VERIFIED: StringName = &"verified"

## 静态语义扫描确认的资源或 class_name 引用。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_STRENGTH_STRONG: StringName = &"strong"

## 仅文本命中的弱引用提示，不会让扫描报告的引用计数阻断。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_STRENGTH_WEAK: StringName = &"weak"

## GDScript load/preload 等加载表达式来源。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_SOURCE_GDSCRIPT_LOAD: StringName = &"gdscript_load"

## GDScript class_name 标识符来源。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_SOURCE_GDSCRIPT_SYMBOL: StringName = &"gdscript_symbol"

## Godot 文本资源依赖字段来源。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_SOURCE_RESOURCE_TEXT: StringName = &"resource_text"

## Godot ResourceLoader 依赖图来源。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_SOURCE_GODOT_DEPENDENCY: StringName = &"godot_dependency"

## 无法确认语义的文本命中来源。
## [br]
## @api public
## [br]
## @since 8.0.0
const REFERENCE_SOURCE_TEXT_FALLBACK: StringName = &"text_fallback"

## 默认扫描根目录。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_SCAN_ROOTS: Array[String] = ["res://"]

## 默认最大扫描深度。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认最大候选扫描文件数。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_SCANNED_FILES: int = 10000

## 默认单文件读取字节上限。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_FILE_BYTES: int = 4 * 1024 * 1024

## 默认单次扫描总读取字节上限。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_TOTAL_BYTES: int = 64 * 1024 * 1024

## 默认忽略的根目录。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_IGNORED_ROOTS: Array[String] = [
	"res://.godot",
	"res://.git",
	"res://.gf",
	"res://addons/gf",
	"res://ai_analysis",
	"res://build",
	"res://packages",
]

## 作为文本扫描的资源扩展名。
## [br]
## @api public
## [br]
## @since 8.0.0
const TEXT_FILE_EXTENSIONS: Array[String] = [
	"cfg",
	"csv",
	"gd",
	"gdshader",
	"godot",
	"import",
	"json",
	"shader",
	"tscn",
	"tres",
]

const _BINARY_RESOURCE_EXTENSIONS: Array[String] = [
	"res",
	"scn",
]


# --- 公共方法 ---

## 扫描项目文件对一组目标根目录或 class_name 的引用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param targets: 扫描目标列表。
## [br]
## @param options: 可选扫描参数。
## [br]
## @schema targets: Array[Dictionary]，每个目标支持 id、root_path 和 class_names；id 为空时使用 root_path。
## [br]
## @schema options: Dictionary，支持 scan_roots、ignored_roots、additional_ignored_roots、max_references_per_target、max_weak_references_per_target、max_scan_depth、max_scanned_files、max_file_bytes、max_total_bytes、include_weak_references、use_resource_dependencies 和 warning_prefix。
## [br]
## @return 项目引用扫描报告。
## [br]
## @schema return: Dictionary，包含 ok、partial_scan、budget_exceeded、input_target_count、target_count、reference_count、weak_reference_count、targets、weak_targets、references、weak_references、candidate_file_count、scanned_file_count、scanned_bytes、skipped_files 和 scan_warnings。
static func scan_references(targets: Array[Dictionary], options: Dictionary = {}) -> Dictionary:
	var scan_targets: Array[Dictionary] = _normalize_targets(targets)
	var scan_state: Dictionary = _make_scan_state(options)
	if scan_targets.is_empty():
		return _make_scan_report(scan_targets, [], [], {}, {}, scan_state)

	var references_by_target: Array[Array] = []
	var weak_references_by_target: Array[Array] = []
	for index: int in range(scan_targets.size()):
		references_by_target.append([])
		weak_references_by_target.append([])

	var files: Array[String] = _collect_reference_scan_files(options, scan_state)
	var max_references: int = maxi(_get_option_int_with_alias(
		options,
		"max_references_per_target",
		"max_references_per_extension",
		50
	), 1)
	var max_weak_references: int = maxi(_get_option_int_with_alias(
		options,
		"max_weak_references_per_target",
		"max_weak_references_per_extension",
		max_references
	), 0)
	var include_weak_references: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_weak_references", true)
	var use_resource_dependencies: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "use_resource_dependencies", true)

	for path: String in files:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "stop_scan"):
			break
		var source_report: Dictionary = _read_scan_source(path, options, scan_state)
		if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(source_report, "ok"):
			continue
		var source: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(source_report, "source")
		var dependency_paths: PackedStringArray = PackedStringArray()
		if use_resource_dependencies:
			dependency_paths = _collect_resource_dependency_paths(path)
		for index: int in range(scan_targets.size()):
			var target: Dictionary = scan_targets[index]
			var references: Array = references_by_target[index]
			var weak_references: Array = weak_references_by_target[index]
			if (
				references.size() >= max_references
				and (not include_weak_references or weak_references.size() >= max_weak_references)
			):
				continue
			var file_report: Dictionary = _collect_file_references_for_target(
				path,
				source,
				target,
				max_references - references.size(),
				max_weak_references - weak_references.size(),
				include_weak_references,
				use_resource_dependencies,
				dependency_paths
			)
			_append_reference_array_unique(
				references,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_array(file_report, "references"),
				max_references
			)
			_append_reference_array_unique(
				weak_references,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_array(file_report, "weak_references"),
				max_weak_references
			)
			references_by_target[index] = references
			weak_references_by_target[index] = weak_references

	var target_reports: Dictionary = {}
	var weak_target_reports: Dictionary = {}
	var all_references: Array[Dictionary] = []
	var all_weak_references: Array[Dictionary] = []
	for index: int in range(scan_targets.size()):
		var target: Dictionary = scan_targets[index]
		var target_id: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(target, "id")
		var root_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "root_path")
		var references: Array = references_by_target[index]
		var weak_references: Array = weak_references_by_target[index]
		if not references.is_empty():
			target_reports[target_id] = {
				"id": String(target_id),
				"root_path": root_path,
				"references": references,
				"reference_count": references.size(),
			}
			all_references.append_array(references)
		if not weak_references.is_empty():
			weak_target_reports[target_id] = {
				"id": String(target_id),
				"root_path": root_path,
				"references": weak_references,
				"reference_count": weak_references.size(),
			}
			all_weak_references.append_array(weak_references)

	return _make_scan_report(
		scan_targets,
		all_references,
		all_weak_references,
		target_reports,
		weak_target_reports,
		scan_state
	)


## 扫描项目文件对单个根目录的引用。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root_path: 要匹配的根目录。
## [br]
## @param class_names: 同一目标根目录下需要匹配的 class_name 列表。
## [br]
## @param options: 可选扫描参数。
## [br]
## @schema class_names: Array[String]，与 root_path 同属一个目标的公开 class_name 列表。
## [br]
## @schema options: Dictionary，支持 scan_references() 的所有 options；默认会把 root_path 加入 additional_ignored_roots，避免扫描目标自身。
## [br]
## @return 单目标项目引用扫描报告。
## [br]
## @schema return: Dictionary，字段同 scan_references() 返回值。
static func scan_root_references(
	root_path: String,
	class_names: Array[String] = [],
	options: Dictionary = {}
) -> Dictionary:
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	if normalized_root.is_empty():
		return scan_references([], options)

	var scan_options: Dictionary = options.duplicate(true)
	var ignored_roots: PackedStringArray = _read_additional_ignored_roots(scan_options)
	if not ignored_roots.has(normalized_root):
		var _append_root: bool = ignored_roots.append(normalized_root)
	scan_options["additional_ignored_roots"] = ignored_roots
	return scan_references([{
		"id": normalized_root,
		"root_path": normalized_root,
		"class_names": class_names,
	}], scan_options)


# --- 私有/辅助方法 ---

static func _normalize_targets(targets: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw_target: Dictionary in targets:
		var root_path: String = _GF_PATH_TOOLS.normalize_root_path(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_target, "root_path")
		)
		if root_path.is_empty():
			continue

		var target_id_text: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(raw_target, "id")
		if target_id_text.is_empty():
			target_id_text = root_path
		var class_names: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(raw_target, "class_names")
		class_names.sort()
		result.append({
			"id": StringName(target_id_text),
			"root_path": root_path,
			"class_names": class_names,
		})
	return result


static func _collect_reference_scan_files(options: Dictionary, scan_state: Dictionary) -> Array[String]:
	var scan_roots: PackedStringArray = _GF_PATH_TOOLS.normalize_root_paths(PackedStringArray(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(options, "scan_roots", DEFAULT_SCAN_ROOTS)
	))
	var ignored_roots: PackedStringArray = _GF_PATH_TOOLS.normalize_root_paths(PackedStringArray(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(options, "ignored_roots", DEFAULT_IGNORED_ROOTS)
	))
	for ignored_root: String in _read_additional_ignored_roots(options):
		if ignored_root.is_empty() or ignored_roots.has(ignored_root):
			continue
		var _append_ignored_root: bool = ignored_roots.append(ignored_root)

	var max_scan_depth: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_scan_depth", DEFAULT_MAX_SCAN_DEPTH), 0)
	var max_scanned_files: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_scanned_files", DEFAULT_MAX_SCANNED_FILES), 0)
	var include_binary_resources: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
		options,
		"use_resource_dependencies",
		true
	)

	var files: Array[String] = []
	for scan_root: String in scan_roots:
		_collect_scan_files(
			scan_root,
			ignored_roots,
			files,
			0,
			max_scan_depth,
			max_scanned_files,
			include_binary_resources,
			scan_state
		)
		if not _can_collect_more_files(files, max_scanned_files):
			_warn_scanned_file_limit(max_scanned_files, scan_state)
			break
	scan_state["candidate_file_count"] = files.size()
	return files


static func _collect_scan_files(
	root_path: String,
	ignored_roots: PackedStringArray,
	result: Array[String],
	depth: int,
	max_scan_depth: int,
	max_scanned_files: int,
	include_binary_resources: bool,
	scan_state: Dictionary
) -> void:
	if not _can_collect_more_files(result, max_scanned_files):
		_warn_scanned_file_limit(max_scanned_files, scan_state)
		return
	if root_path.is_empty() or _is_path_ignored(root_path, ignored_roots):
		return

	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		return

	var _list_dir_begin_result: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not _can_collect_more_files(result, max_scanned_files):
			_warn_scanned_file_limit(max_scanned_files, scan_state)
			break

		var path: String = root_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				if _can_scan_deeper(path, depth, max_scan_depth, scan_state):
					_collect_scan_files(
						path,
						ignored_roots,
						result,
						depth + 1,
						max_scan_depth,
						max_scanned_files,
						include_binary_resources,
						scan_state
					)
		elif _is_text_resource_file(entry) or (include_binary_resources and _is_binary_resource_file(entry)):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


static func _read_scan_source(path: String, options: Dictionary, scan_state: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"source": "",
	}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_append_skipped_file(path, "read_failed", 0, "", 0, scan_state)
		return result

	var size_bytes: int = file.get_length()
	var max_file_bytes: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_file_bytes", DEFAULT_MAX_FILE_BYTES), 0)
	var max_total_bytes: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_total_bytes", DEFAULT_MAX_TOTAL_BYTES), 0)
	if max_file_bytes > 0 and size_bytes > max_file_bytes:
		file.close()
		_mark_budget_exceeded(path, "max_file_bytes", size_bytes, max_file_bytes, scan_state)
		return result

	var scanned_bytes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_bytes")
	if max_total_bytes > 0 and scanned_bytes + size_bytes > max_total_bytes:
		file.close()
		_mark_budget_exceeded(path, "max_total_bytes", scanned_bytes + size_bytes, max_total_bytes, scan_state)
		scan_state["stop_scan"] = true
		return result

	if _is_binary_resource_file(path) and not ResourceLoader.exists(path):
		file.close()
		_mark_scan_partial(scan_state)
		_append_skipped_file(path, "resource_dependencies_unavailable", size_bytes, "", 0, scan_state)
		return result

	if not _is_binary_resource_file(path):
		result["source"] = file.get_as_text()
	result["ok"] = true
	file.close()
	scan_state["scanned_file_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_file_count") + 1
	scan_state["scanned_bytes"] = scanned_bytes + size_bytes
	return result


static func _collect_file_references_for_target(
	path: String,
	source: String,
	target: Dictionary,
	remaining_blocking: int,
	remaining_weak: int,
	include_weak_references: bool,
	use_resource_dependencies: bool,
	dependency_paths: PackedStringArray
) -> Dictionary:
	var result: Dictionary = _make_file_reference_report()
	if (
		remaining_blocking <= 0
		and (not include_weak_references or remaining_weak <= 0)
	):
		return result

	var root_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "root_path")
	var target_id: StringName = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_name(target, "id")
	var class_names: Array[String] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(target, "class_names")
	var blocking_references: Array[Dictionary] = []
	if use_resource_dependencies and remaining_blocking > 0:
		_append_reference_array_unique(
			blocking_references,
			_collect_dependency_references(path, dependency_paths, root_path, target_id, remaining_blocking),
			remaining_blocking
		)

	var extension: String = path.get_extension().to_lower()
	if extension == "gd":
		_append_reference_array_unique(
			blocking_references,
			_collect_gdscript_file_references(path, source, root_path, target_id, class_names, remaining_blocking),
			remaining_blocking
		)
	elif _is_resource_text_extension(extension):
		_append_reference_array_unique(
			blocking_references,
			_collect_resource_text_file_references(path, source, root_path, target_id, remaining_blocking),
			remaining_blocking
		)

	var weak_references: Array[Dictionary] = []
	if include_weak_references and remaining_weak > 0:
		_collect_weak_text_file_references(
			path,
			source,
			root_path,
			target_id,
			class_names,
			blocking_references,
			weak_references,
			remaining_weak
		)

	result["references"] = blocking_references
	result["weak_references"] = weak_references
	return result


static func _make_file_reference_report() -> Dictionary:
	return {
		"references": [],
		"weak_references": [],
	}


static func _collect_dependency_references(
	path: String,
	dependency_paths: PackedStringArray,
	root_path: String,
	target_id: StringName,
	remaining: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if remaining <= 0:
		return result

	for dependency_path: String in dependency_paths:
		if dependency_path.is_empty() or not _line_references_root(dependency_path, root_path):
			continue
		_append_reference_unique(result, _make_reference(
			path,
			0,
			root_path,
			target_id,
			"path",
			"",
			root_path,
			REFERENCE_STRENGTH_VERIFIED,
			REFERENCE_SOURCE_GODOT_DEPENDENCY,
			dependency_path
		), remaining)
		if result.size() >= remaining:
			break
	return result


static func _collect_resource_dependency_paths(path: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if not ResourceLoader.exists(path):
		return result
	for dependency_entry: String in ResourceLoader.get_dependencies(path):
		var dependency_path: String = _extract_dependency_resource_path(dependency_entry)
		if not dependency_path.is_empty() and not result.has(dependency_path):
			var _append_result: Variant = result.append(dependency_path)
	return result


static func _collect_gdscript_file_references(
	path: String,
	source: String,
	root_path: String,
	target_id: StringName,
	class_names: Array[String],
	remaining: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if remaining <= 0:
		return result

	var lines: PackedStringArray = source.split("\n")
	for line_index: int in range(lines.size()):
		var code_line: String = _strip_gdscript_line_comment(String(lines[line_index]))
		if _line_references_root(code_line, root_path) and _line_has_gdscript_path_context(code_line, root_path):
			_append_reference_unique(result, _make_reference(
				path,
				line_index + 1,
				root_path,
				target_id,
				"path",
				"",
				root_path,
				REFERENCE_STRENGTH_STRONG,
				REFERENCE_SOURCE_GDSCRIPT_LOAD,
				root_path
			), remaining)
			if result.size() >= remaining:
				break

		var identifier_line: String = _replace_quoted_segments(code_line)
		for class_name_value: String in class_names:
			if not _line_references_identifier(identifier_line, class_name_value):
				continue
			_append_reference_unique(result, _make_reference(
				path,
				line_index + 1,
				root_path,
				target_id,
				"class_name",
				class_name_value,
				class_name_value,
				REFERENCE_STRENGTH_STRONG,
				REFERENCE_SOURCE_GDSCRIPT_SYMBOL,
				class_name_value
			), remaining)
			break
		if result.size() >= remaining:
			break
	return result


static func _collect_resource_text_file_references(
	path: String,
	source: String,
	root_path: String,
	target_id: StringName,
	remaining: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if remaining <= 0:
		return result

	var lines: PackedStringArray = source.split("\n")
	for line_index: int in range(lines.size()):
		var line: String = String(lines[line_index])
		if not _line_references_root(line, root_path):
			continue
		if not _line_has_resource_path_context(line):
			continue
		_append_reference_unique(result, _make_reference(
			path,
			line_index + 1,
			root_path,
			target_id,
			"path",
			"",
			root_path,
			REFERENCE_STRENGTH_STRONG,
			REFERENCE_SOURCE_RESOURCE_TEXT,
			root_path
		), remaining)
		if result.size() >= remaining:
			break
	return result


static func _collect_weak_text_file_references(
	path: String,
	source: String,
	root_path: String,
	target_id: StringName,
	class_names: Array[String],
	blocking_references: Array[Dictionary],
	result: Array[Dictionary],
	max_count: int
) -> void:
	if max_count <= 0:
		return

	var lines: PackedStringArray = source.split("\n")
	var is_gdscript: bool = path.get_extension().to_lower() == "gd"
	for line_index: int in range(lines.size()):
		var line: String = String(lines[line_index])
		if is_gdscript:
			line = _strip_gdscript_line_comment(line)
		if line.is_empty():
			continue

		if _line_references_root(line, root_path):
			_append_weak_reference_unique(result, blocking_references, _make_reference(
				path,
				line_index + 1,
				root_path,
				target_id,
				"path",
				"",
				root_path,
				REFERENCE_STRENGTH_WEAK,
				REFERENCE_SOURCE_TEXT_FALLBACK,
				root_path
			), max_count)
		for class_name_value: String in class_names:
			if not _line_references_identifier(line, class_name_value):
				continue
			_append_weak_reference_unique(result, blocking_references, _make_reference(
				path,
				line_index + 1,
				root_path,
				target_id,
				"class_name",
				class_name_value,
				class_name_value,
				REFERENCE_STRENGTH_WEAK,
				REFERENCE_SOURCE_TEXT_FALLBACK,
				class_name_value
			), max_count)
			break
		if result.size() >= max_count:
			break


static func _make_reference(
	path: String,
	line: int,
	root_path: String,
	target_id: StringName,
	kind: String,
	symbol: String,
	match_text: String,
	strength: StringName,
	source: StringName,
	evidence: String
) -> Dictionary:
	var target_path: String = ""
	if kind == "path":
		target_path = evidence if _is_resource_path_text(evidence) else root_path
	return {
		"path": path,
		"line": line,
		"target_id": String(target_id),
		"root_path": root_path,
		"kind": kind,
		"symbol": symbol,
		"match": match_text,
		"target_path": target_path,
		"strength": String(strength),
		"source": String(source),
		"evidence": evidence,
		"blocking": strength == REFERENCE_STRENGTH_VERIFIED or strength == REFERENCE_STRENGTH_STRONG,
		"preview": "%s reference: %s" % [kind, match_text],
	}


static func _append_reference_array_unique(
	result: Array,
	values: Array,
	max_count: int
) -> void:
	for value: Variant in values:
		if value is Dictionary:
			var reference_record: Dictionary = value
			_append_reference_unique(result, reference_record, max_count)


static func _append_reference_unique(
	result: Array,
	candidate: Dictionary,
	max_count: int
) -> void:
	if candidate.is_empty():
		return

	var candidate_key: String = _make_reference_key(candidate)
	for index: int in range(result.size()):
		var existing_value: Variant = result[index]
		if not (existing_value is Dictionary):
			continue
		var existing_reference: Dictionary = existing_value
		if _make_reference_key(existing_reference) != candidate_key:
			continue
		if _get_reference_rank(candidate) > _get_reference_rank(existing_reference):
			result[index] = candidate
		return

	if max_count > 0 and result.size() >= max_count:
		return
	result.append(candidate)


static func _append_weak_reference_unique(
	result: Array,
	blocking_references: Array,
	candidate: Dictionary,
	max_count: int
) -> void:
	if _reference_key_exists(blocking_references, _make_reference_key(candidate)):
		return
	_append_reference_unique(result, candidate, max_count)


static func _reference_key_exists(references: Array, reference_key: String) -> bool:
	for reference_value: Variant in references:
		if not (reference_value is Dictionary):
			continue
		var reference_record: Dictionary = reference_value
		if _make_reference_key(reference_record) == reference_key:
			return true
	return false


static func _make_reference_key(reference_record: Dictionary) -> String:
	return "%s|%s|%s|%s" % [
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_record, "path"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_record, "root_path"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_record, "kind"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_record, "match"),
	]


static func _get_reference_rank(reference_record: Dictionary) -> int:
	var strength: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(reference_record, "strength")
	if strength == String(REFERENCE_STRENGTH_VERIFIED):
		return 3
	if strength == String(REFERENCE_STRENGTH_STRONG):
		return 2
	if strength == String(REFERENCE_STRENGTH_WEAK):
		return 1
	return 0


static func _extract_dependency_resource_path(dependency_entry: String) -> String:
	var normalized_entry: String = dependency_entry.strip_edges()
	if normalized_entry.is_empty():
		return ""
	var parts: PackedStringArray = normalized_entry.split("::", false)
	for part: String in parts:
		var candidate: String = part.strip_edges()
		if _is_resource_path_text(candidate):
			return candidate
	return normalized_entry


static func _line_has_gdscript_path_context(line: String, root_path: String) -> bool:
	var normalized_line: String = _normalize_source_line_path_separators(line)
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	var start: int = _find_root_reference_start(normalized_line, normalized_root)
	while start >= 0:
		var before_path: String = normalized_line.substr(0, start)
		if _context_before_path_is_gdscript_load(before_path):
			return true
		start = _find_root_reference_start_from(normalized_line, normalized_root, start + 1)
	return false


static func _context_before_path_is_gdscript_load(before_path: String) -> bool:
	var stripped: String = before_path.strip_edges()
	if stripped.begins_with("extends"):
		return true

	var open_parenthesis_index: int = before_path.rfind("(")
	if open_parenthesis_index < 0:
		return false
	var callee_text: String = before_path.substr(0, open_parenthesis_index).strip_edges()
	return (
		callee_text.ends_with("preload")
		or callee_text.ends_with("load")
		or callee_text.ends_with("ResourceLoader.load")
		or callee_text.ends_with("ResourceLoader.load_interactive")
		or callee_text.ends_with("ResourceLoader.load_threaded_request")
		or callee_text.ends_with("ResourceLoader.load_threaded_get")
	)


static func _line_has_resource_path_context(line: String) -> bool:
	var stripped: String = line.strip_edges()
	return (
		stripped.begins_with("[ext_resource")
		or stripped.contains("path=")
		or stripped.contains("path =")
		or stripped.contains("script=")
		or stripped.contains("script =")
	)


static func _strip_gdscript_line_comment(line: String) -> String:
	var in_string: bool = false
	var quote_character: String = ""
	var escaped: bool = false
	for index: int in range(line.length()):
		var character: String = line.substr(index, 1)
		if in_string:
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote_character:
				in_string = false
			continue

		if character == "\"" or character == "'":
			in_string = true
			quote_character = character
		elif character == "#":
			return line.substr(0, index)
	return line


static func _replace_quoted_segments(line: String) -> String:
	var result: String = ""
	var in_string: bool = false
	var quote_character: String = ""
	var escaped: bool = false
	for index: int in range(line.length()):
		var character: String = line.substr(index, 1)
		if in_string:
			result += " "
			if escaped:
				escaped = false
			elif character == "\\":
				escaped = true
			elif character == quote_character:
				in_string = false
			continue

		if character == "\"" or character == "'":
			in_string = true
			quote_character = character
			result += " "
		else:
			result += character
	return result


static func _line_references_root(line: String, root_path: String) -> bool:
	var normalized_line: String = _normalize_source_line_path_separators(line)
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	if _line_references_root_variant(normalized_line, normalized_root):
		return true

	for root_variant: String in _root_reference_variants(root_path):
		if _line_references_root_variant(line, root_variant):
			return true
	return false


static func _normalize_source_line_path_separators(line: String) -> String:
	var normalized_line: String = line.replace("\\\\", "/").replace("\\", "/")
	normalized_line = normalized_line.replace("res:/", "res://").replace("user:/", "user://")
	while normalized_line.contains("res:///"):
		normalized_line = normalized_line.replace("res:///", "res://")
	while normalized_line.contains("user:///"):
		normalized_line = normalized_line.replace("user:///", "user://")
	return normalized_line


static func _line_references_root_variant(line: String, root_path: String) -> bool:
	if root_path.is_empty():
		return false
	var start: int = line.find(root_path)
	while start >= 0:
		var next_index: int = start + root_path.length()
		if next_index >= line.length():
			return true

		var next_character: String = line.substr(next_index, 1)
		if _is_reference_boundary(next_character):
			return true
		start = line.find(root_path, start + 1)
	return false


static func _find_root_reference_start(line: String, root_path: String) -> int:
	return _find_root_reference_start_from(line, root_path, 0)


static func _find_root_reference_start_from(line: String, root_path: String, from_index: int) -> int:
	if root_path.is_empty():
		return -1
	var start: int = line.find(root_path, from_index)
	while start >= 0:
		var next_index: int = start + root_path.length()
		if next_index >= line.length():
			return start

		var next_character: String = line.substr(next_index, 1)
		if _is_reference_boundary(next_character):
			return start
		start = line.find(root_path, start + 1)
	return -1


static func _root_reference_variants(root_path: String) -> PackedStringArray:
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	var variants: PackedStringArray = PackedStringArray()
	_append_unique_variant(variants, normalized_root)
	_append_unique_variant(variants, normalized_root.replace("/", "\\"))
	_append_unique_variant(variants, normalized_root.replace("/", "\\\\"))
	return variants


static func _append_unique_variant(values: PackedStringArray, value: String) -> void:
	if value.is_empty() or values.has(value):
		return
	var _append_value: bool = values.append(value)


static func _line_references_identifier(line: String, identifier: String) -> bool:
	if identifier.is_empty():
		return false

	var start: int = line.find(identifier)
	while start >= 0:
		var before_ok: bool = start == 0 or not _is_identifier_character(line.substr(start - 1, 1))
		var end: int = start + identifier.length()
		var after_ok: bool = end >= line.length() or not _is_identifier_character(line.substr(end, 1))
		if before_ok and after_ok:
			return true
		start = line.find(identifier, start + 1)
	return false


static func _is_identifier_character(character: String) -> bool:
	if character.is_empty():
		return false
	var code: int = character.unicode_at(0)
	return (
		(code >= 65 and code <= 90)
		or (code >= 97 and code <= 122)
		or (code >= 48 and code <= 57)
		or code == 95
	)


static func _is_reference_boundary(character: String) -> bool:
	return ["/", "\\", "\"", "'", ")", "]", "}", ",", " ", "\t"].has(character)


static func _is_text_resource_file(path: String) -> bool:
	var extension: String = path.get_extension().to_lower()
	return TEXT_FILE_EXTENSIONS.has(extension)


static func _is_binary_resource_file(path: String) -> bool:
	return _BINARY_RESOURCE_EXTENSIONS.has(path.get_extension().to_lower())


static func _is_resource_text_extension(extension: String) -> bool:
	return ["tscn", "tres", "godot", "import"].has(extension)


static func _is_resource_path_text(value: String) -> bool:
	return value.begins_with("res://") or value.begins_with("user://") or value.begins_with("uid://")


static func _is_path_ignored(path: String, ignored_roots: PackedStringArray) -> bool:
	return _GF_PATH_TOOLS.is_path_excluded(path, ignored_roots)


static func _can_scan_deeper(path: String, current_depth: int, max_scan_depth: int, scan_state: Dictionary) -> bool:
	if max_scan_depth <= 0 or current_depth < max_scan_depth:
		return true
	_warn_scan_depth_limit(path, max_scan_depth, scan_state)
	return false


static func _can_collect_more_files(result: Array[String], max_scanned_files: int) -> bool:
	return max_scanned_files <= 0 or result.size() < max_scanned_files


static func _make_scan_state(options: Dictionary) -> Dictionary:
	return {
		"candidate_file_count": 0,
		"scanned_file_count": 0,
		"scanned_bytes": 0,
		"partial_scan": false,
		"budget_exceeded": false,
		"stop_scan": false,
		"skipped_files": [],
		"scan_warnings": [],
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
		"budget_warning_emitted": false,
		"warning_prefix": _GF_VARIANT_ACCESS_SCRIPT.get_option_string(options, "warning_prefix", "[GFProjectReferenceScanner]"),
	}


static func _make_scan_report(
	scan_targets: Array[Dictionary],
	references: Array[Dictionary],
	weak_references: Array[Dictionary],
	target_reports: Dictionary,
	weak_target_reports: Dictionary,
	scan_state: Dictionary
) -> Dictionary:
	var partial_scan: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "partial_scan")
	return {
		"ok": references.is_empty() and not partial_scan,
		"partial_scan": partial_scan,
		"budget_exceeded": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "budget_exceeded"),
		"input_target_count": scan_targets.size(),
		"target_count": target_reports.size(),
		"reference_count": references.size(),
		"weak_reference_count": weak_references.size(),
		"targets": target_reports,
		"weak_targets": weak_target_reports,
		"references": references,
		"weak_references": weak_references,
		"candidate_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "candidate_file_count"),
		"scanned_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_file_count"),
		"scanned_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_state, "scanned_bytes"),
		"skipped_files": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "skipped_files"),
		"scan_warnings": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "scan_warnings"),
	}


static func _mark_scan_partial(scan_state: Dictionary) -> void:
	scan_state["partial_scan"] = true


static func _mark_budget_exceeded(
	path: String,
	reason: String,
	size_bytes: int,
	limit_bytes: int,
	scan_state: Dictionary
) -> void:
	scan_state["budget_exceeded"] = true
	_mark_scan_partial(scan_state)
	_append_skipped_file(path, reason, size_bytes, reason, limit_bytes, scan_state)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "budget_warning_emitted"):
		return
	scan_state["budget_warning_emitted"] = true
	_emit_scan_warning(
		"引用扫描达到 %s=%d 字节预算，后续结果按 partial_scan 处理：%s。" % [reason, limit_bytes, path],
		scan_state
	)


static func _append_skipped_file(
	path: String,
	reason: String,
	size_bytes: int,
	limit_key: String,
	limit_bytes: int,
	scan_state: Dictionary
) -> void:
	var skipped_files: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "skipped_files")
	skipped_files.append({
		"path": path,
		"reason": reason,
		"size_bytes": size_bytes,
		"limit_key": limit_key,
		"limit_bytes": limit_bytes,
	})
	scan_state["skipped_files"] = skipped_files


static func _warn_scanned_file_limit(max_scanned_files: int, scan_state: Dictionary) -> void:
	if max_scanned_files <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "count_warning_emitted"):
		return
	scan_state["count_warning_emitted"] = true
	_mark_scan_partial(scan_state)
	_emit_scan_warning("已达到 max_scanned_files=%d，后续文件已跳过。" % max_scanned_files, scan_state)


static func _warn_scan_depth_limit(path: String, max_scan_depth: int, scan_state: Dictionary) -> void:
	if max_scan_depth <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "depth_warning_emitted"):
		return
	scan_state["depth_warning_emitted"] = true
	_mark_scan_partial(scan_state)
	_emit_scan_warning("已达到 max_scan_depth=%d，已跳过更深目录：%s。" % [max_scan_depth, path], scan_state)


static func _emit_scan_warning(message: String, scan_state: Dictionary) -> void:
	var warning_prefix: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		scan_state,
		"warning_prefix",
		"[GFProjectReferenceScanner]"
	)
	var warning_message: String = "%s %s" % [warning_prefix, message]
	var scan_warnings: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "scan_warnings")
	scan_warnings.append(warning_message)
	scan_state["scan_warnings"] = scan_warnings
	push_warning(warning_message)


static func _read_additional_ignored_roots(options: Dictionary) -> PackedStringArray:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(options, "additional_ignored_roots", PackedStringArray())
	if value is PackedStringArray:
		var packed_roots: PackedStringArray = value
		return _GF_PATH_TOOLS.normalize_root_paths(packed_roots)
	return _GF_PATH_TOOLS.normalize_root_paths(PackedStringArray(_GF_VARIANT_ACCESS_SCRIPT.to_string_array(value)))


static func _get_option_int_with_alias(
	options: Dictionary,
	key: String,
	alias: String,
	default_value: int
) -> int:
	if _has_option_key(options, key):
		return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, key, default_value)
	return _GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, alias, default_value)


static func _has_option_key(options: Dictionary, key: String) -> bool:
	return options.has(key) or options.has(StringName(key))
