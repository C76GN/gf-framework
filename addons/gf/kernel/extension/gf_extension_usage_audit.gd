## GFExtensionUsageAudit: 检查禁用扩展是否仍被项目文件直接引用。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/extension
class_name GFExtensionUsageAudit
extends RefCounted


# --- 常量 ---

const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")
const _GF_PROJECT_REFERENCE_SCANNER_SCRIPT = preload("res://addons/gf/kernel/core/gf_project_reference_scanner.gd")

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

## 仅文本命中的弱引用提示，不会让禁用扩展审计失败。
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
## @since 3.17.0
const DEFAULT_SCAN_ROOTS: Array[String] = ["res://"]

## 默认最大扫描深度。
## [br]
## @api public
## [br]
## @since 3.17.0
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认最大扫描文件数。
## [br]
## @api public
## [br]
## @since 3.17.0
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
## @since 3.17.0
const DEFAULT_IGNORED_ROOTS: Array[String] = [
	"res://.godot",
	"res://.git",
	"res://.gf",
	"res://addons/gf",
	"res://build",
	"res://packages",
]

## 作为文本扫描的资源扩展名。
## [br]
## @api public
## [br]
## @since 3.17.0
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


# --- 公共方法 ---

## 检查一组禁用扩展是否仍被项目文件直接引用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param manifests: 要检查的禁用扩展 manifest 列表。
## [br]
## @param options: 可选参数，支持 scan_roots、ignored_roots、max_references_per_extension、max_weak_references_per_extension、max_scan_depth、max_scanned_files、max_file_bytes、max_total_bytes、include_weak_references 和 use_resource_dependencies。
## [br]
## @schema options: Dictionary controlling scan roots, ignored roots, strong and weak reference limits, depth, scanned file count, file byte budget, total byte budget, weak text reporting, and Godot dependency graph usage.
## [br]
## @return 引用审计报告。
## [br]
## @schema return: Dictionary containing ok, partial_scan, budget_exceeded, extension_count, reference_count, weak_reference_count, extensions, weak_extensions, references, weak_references, candidate_file_count, scanned_file_count, scanned_bytes, skipped_files, scan_warnings, issue_count, issues, and class_name_scan. references only contains strong or verified blocking references.
static func audit_disabled_extensions(
	manifests: Array[GFExtensionManifest],
	options: Dictionary = {}
) -> Dictionary:
	var audited_manifests: Array[GFExtensionManifest] = []
	var root_paths: Array[String] = []
	var scan_targets: Array[Dictionary] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null or manifest.root_path.is_empty():
			continue
		var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(manifest.root_path)
		if normalized_root.is_empty():
			continue
		audited_manifests.append(manifest)
		root_paths.append(normalized_root)
		scan_targets.append({
			"id": manifest.id,
			"root_path": normalized_root,
		})

	var extension_reports: Dictionary = {}
	var weak_extension_reports: Dictionary = {}
	var all_references: Array[Dictionary] = []
	var all_weak_references: Array[Dictionary] = []
	if audited_manifests.is_empty():
		return _make_audit_report(
			true,
			extension_reports,
			weak_extension_reports,
			all_references,
			all_weak_references,
			{}
		)

	var scan_report: Dictionary = _scan_targets_with_class_names(
		scan_targets,
		options,
		PackedStringArray(root_paths)
	)
	var target_reports: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(scan_report, "targets")
	var weak_target_reports: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(scan_report, "weak_targets")
	for index: int in range(audited_manifests.size()):
		var manifest: GFExtensionManifest = audited_manifests[index]
		var root_path: String = root_paths[index]
		var target_report: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(target_reports, manifest.id)
		var weak_target_report: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(weak_target_reports, manifest.id)
		var references: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(target_report, "references")
		var weak_references: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(weak_target_report, "references")

		if not references.is_empty():
			extension_reports[manifest.id] = {
				"id": manifest.id,
				"display_name": manifest.display_name,
				"root_path": root_path,
				"references": references,
				"reference_count": references.size(),
			}
			_append_typed_references(all_references, references)
		if not weak_references.is_empty():
			weak_extension_reports[manifest.id] = {
				"id": manifest.id,
				"display_name": manifest.display_name,
				"root_path": root_path,
				"references": weak_references,
				"reference_count": weak_references.size(),
			}
			_append_typed_references(all_weak_references, weak_references)

	return _make_audit_report(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_report, "ok"),
		extension_reports,
		weak_extension_reports,
		all_references,
		all_weak_references,
		scan_report
	)


## 查找项目文件中对指定扩展根目录的直接路径引用。
## [br]
## @api public
## [br]
## @since 3.17.0
## [br]
## @param root_path: 扩展根目录。
## [br]
## @param options: 可选参数，支持 scan_roots、ignored_roots、max_references_per_extension、max_weak_references_per_extension、max_scan_depth、max_scanned_files、max_file_bytes、max_total_bytes、include_weak_references 和 use_resource_dependencies。
## [br]
## @schema options: Dictionary controlling scan roots, ignored roots, strong and weak reference limits, depth, scanned file count, file byte budget, total byte budget, weak text reporting, and Godot dependency graph usage.
## [br]
## @return 引用列表。
## [br]
## @schema return: Array of Dictionary file reference records. By default only strong or verified blocking references are returned; include_weak_references appends weak text matches.
static func find_references_to_root(root_path: String, options: Dictionary = {}) -> Array[Dictionary]:
	var scan_report: Dictionary = find_references_to_root_report(root_path, options)
	var references: Array[Dictionary] = []
	_append_typed_references(
		references,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "references")
	)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_weak_references", false):
		_append_typed_references(
			references,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "weak_references")
		)
	return references


## 查找项目文件中对指定扩展根目录的直接引用，并返回扫描完整性报告。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param root_path: 扩展根目录。
## [br]
## @param options: 参数同 find_references_to_root()。
## [br]
## @schema options: Dictionary controlling scan roots, ignored roots, strong and weak reference limits, shared depth, candidate file count, file byte and total byte budgets, weak text reporting, and Godot dependency graph usage.
## [br]
## @return: 引用与扫描完整性报告。
## [br]
## @schema return: Dictionary containing ok, partial_scan, budget_exceeded, truncated, references, weak_references, candidate_file_count, scanned_file_count, scanned_bytes, skipped_files, scan_warnings, issue_count, issues, and class_name_scan.
static func find_references_to_root_report(
	root_path: String,
	options: Dictionary = {}
) -> Dictionary:
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	if normalized_root.is_empty():
		return _make_invalid_root_scan_report(root_path)
	var scan_options: Dictionary = options.duplicate(true)
	if not _has_option_key(scan_options, "include_weak_references"):
		scan_options["include_weak_references"] = false
	return _scan_targets_with_class_names(
		[{
			"id": normalized_root,
			"root_path": normalized_root,
		}],
		scan_options,
		PackedStringArray([normalized_root])
	)


# --- 私有/辅助方法 ---

static func _make_audit_report(
	ok: bool,
	extension_reports: Dictionary,
	weak_extension_reports: Dictionary,
	references: Array[Dictionary],
	weak_references: Array[Dictionary],
	scan_report: Dictionary
) -> Dictionary:
	return {
		"ok": ok,
		"partial_scan": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_report, "partial_scan"),
		"budget_exceeded": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_report, "budget_exceeded"),
		"extension_count": extension_reports.size(),
		"reference_count": references.size(),
		"weak_reference_count": weak_references.size(),
		"extensions": extension_reports,
		"weak_extensions": weak_extension_reports,
		"references": references,
		"weak_references": weak_references,
		"candidate_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_report, "candidate_file_count"),
		"scanned_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_report, "scanned_file_count"),
		"scanned_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_report, "scanned_bytes"),
		"skipped_files": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "skipped_files"),
		"scan_warnings": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "scan_warnings"),
		"issue_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_report, "issue_count"),
		"issues": _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "issues"),
		"class_name_scan": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			scan_report,
			"class_name_scan"
		),
	}


static func _make_scanner_options(options: Dictionary, additional_ignored_roots: PackedStringArray) -> Dictionary:
	var scan_options: Dictionary = options.duplicate(true)
	scan_options["warning_prefix"] = "[GFExtensionUsageAudit]"
	if not _has_option_key(scan_options, "max_references_per_target"):
		scan_options["max_references_per_target"] = maxi(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_references_per_extension", 50),
			1
		)
	if not _has_option_key(scan_options, "max_weak_references_per_target"):
		scan_options["max_weak_references_per_target"] = maxi(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				options,
				"max_weak_references_per_extension",
				_GF_VARIANT_ACCESS_SCRIPT.get_option_int(scan_options, "max_references_per_target", 50)
			),
			0
		)
	if not _has_option_key(scan_options, "max_file_bytes"):
		scan_options["max_file_bytes"] = DEFAULT_MAX_FILE_BYTES
	if not _has_option_key(scan_options, "max_total_bytes"):
		scan_options["max_total_bytes"] = DEFAULT_MAX_TOTAL_BYTES

	var ignored_roots: PackedStringArray = _read_option_packed_string_array(scan_options, "additional_ignored_roots")
	for ignored_root: String in additional_ignored_roots:
		if ignored_root.is_empty() or ignored_roots.has(ignored_root):
			continue
		var _append_ignored_root: bool = ignored_roots.append(ignored_root)
	scan_options["additional_ignored_roots"] = ignored_roots
	return scan_options


static func _read_option_packed_string_array(options: Dictionary, key: String) -> PackedStringArray:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(options, key, PackedStringArray())
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		return packed_value.duplicate()
	return PackedStringArray(_GF_VARIANT_ACCESS_SCRIPT.to_string_array(value))


static func _append_typed_references(result: Array[Dictionary], values: Array) -> void:
	for value: Variant in values:
		if value is Dictionary:
			var reference_record: Dictionary = value
			result.append(reference_record)


static func _has_option_key(options: Dictionary, key: String) -> bool:
	return options.has(key) or options.has(StringName(key))


static func _scan_targets_with_class_names(
	targets: Array[Dictionary],
	options: Dictionary,
	additional_ignored_roots: PackedStringArray
) -> Dictionary:
	var class_name_report: Dictionary = _collect_class_name_scan_report(targets, options)
	var class_names_by_target: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
		class_name_report,
		"class_names_by_target"
	)
	var enriched_targets: Array[Dictionary] = []
	for target: Dictionary in targets:
		var enriched_target: Dictionary = target.duplicate(true)
		var target_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			target,
			"id",
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "root_path")
		)
		enriched_target["class_names"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(
			class_names_by_target,
			target_id
		)
		enriched_targets.append(enriched_target)

	var scanner_options: Dictionary = _make_scanner_options(options, additional_ignored_roots)
	var can_scan_project: bool = _apply_remaining_scan_budgets(
		scanner_options,
		class_name_report
	)
	var project_report: Dictionary = _make_empty_project_scan_report(enriched_targets)
	if can_scan_project:
		project_report = _GF_PROJECT_REFERENCE_SCANNER_SCRIPT.scan_references(
			enriched_targets,
			scanner_options
		)
	return _merge_scan_phase_reports(project_report, class_name_report)


static func _apply_remaining_scan_budgets(
	scanner_options: Dictionary,
	class_name_report: Dictionary
) -> bool:
	var can_scan_project: bool = true
	var max_scanned_files: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		scanner_options,
		"max_scanned_files",
		DEFAULT_MAX_SCANNED_FILES
	), 0)
	var candidate_file_count: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		class_name_report,
		"candidate_file_count"
	)
	if max_scanned_files > 0:
		var remaining_files: int = max_scanned_files - candidate_file_count
		if remaining_files <= 0:
			if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "stop_scan"):
				_mark_class_phase_exhausted(
					class_name_report,
					"max_scanned_files",
					"扩展 class_name 预扫描已耗尽与项目扫描共享的 max_scanned_files=%d。"
					% max_scanned_files
				)
			can_scan_project = false
		else:
			scanner_options["max_scanned_files"] = remaining_files

	var max_total_bytes: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		scanner_options,
		"max_total_bytes",
		DEFAULT_MAX_TOTAL_BYTES
	), 0)
	var scanned_bytes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		class_name_report,
		"scanned_bytes"
	)
	if max_total_bytes > 0:
		var remaining_bytes: int = max_total_bytes - scanned_bytes
		if remaining_bytes <= 0:
			if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "stop_scan"):
				_mark_class_phase_exhausted(
					class_name_report,
					"max_total_bytes",
					"扩展 class_name 预扫描已耗尽与项目扫描共享的 max_total_bytes=%d 字节预算。"
					% max_total_bytes
				)
			can_scan_project = false
		else:
			scanner_options["max_total_bytes"] = remaining_bytes
	return can_scan_project


static func _collect_class_name_scan_report(
	targets: Array[Dictionary],
	options: Dictionary
) -> Dictionary:
	var scan_state: Dictionary = _make_class_name_scan_state()
	var regex: RegEx = RegEx.new()
	var compile_error: Error = regex.compile("(?m)^\\s*class_name\\s+([A-Za-z_]\\w*)")
	if compile_error != OK:
		_mark_class_scan_partial(scan_state)
		_append_class_scan_issue(
			"class_name_pattern_invalid",
			"",
			"",
			"扩展 class_name 预扫描正则无法编译。",
			scan_state
		)
		_emit_class_scan_warning("扩展 class_name 预扫描正则无法编译。", scan_state)
		return scan_state

	var max_scan_depth: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		options,
		"max_scan_depth",
		DEFAULT_MAX_SCAN_DEPTH
	), 0)
	var max_scanned_files: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		options,
		"max_scanned_files",
		DEFAULT_MAX_SCANNED_FILES
	), 0)
	var class_names_by_root: Dictionary = {}
	var class_names_by_target: Dictionary = {}
	for target: Dictionary in targets:
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "stop_scan"):
			break
		var target_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			target,
			"id",
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "root_path")
		)
		var root_path: String = _GF_PATH_TOOLS.normalize_root_path(
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(target, "root_path")
		)
		if class_names_by_root.has(root_path):
			class_names_by_target[target_id] = _GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(
				class_names_by_root,
				root_path
			)
			continue

		var files: Array[String] = []
		_collect_class_source_files(
			root_path,
			files,
			0,
			max_scan_depth,
			max_scanned_files,
			scan_state
		)
		var names: Array[String] = []
		for path: String in files:
			if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "stop_scan"):
				break
			var source_report: Dictionary = _read_class_name_source(path, options, scan_state)
			if not _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(source_report, "ok"):
				continue
			var match_result: RegExMatch = regex.search(
				_GF_VARIANT_ACCESS_SCRIPT.get_option_string(source_report, "source")
			)
			if match_result == null:
				continue
			var class_name_value: String = match_result.get_string(1)
			if not names.has(class_name_value):
				names.append(class_name_value)
		names.sort()
		class_names_by_root[root_path] = names
		class_names_by_target[target_id] = names.duplicate()
	scan_state["class_names_by_target"] = class_names_by_target
	return scan_state


static func _collect_class_source_files(
	root_path: String,
	result: Array[String],
	depth: int,
	max_scan_depth: int,
	max_scanned_files: int,
	scan_state: Dictionary
) -> void:
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "stop_scan"):
		return
	if root_path.is_empty():
		return
	var global_root: String = ProjectSettings.globalize_path(root_path)
	if not DirAccess.dir_exists_absolute(global_root):
		return
	var dir: DirAccess = DirAccess.open(root_path)
	if dir == null:
		_mark_class_scan_partial(scan_state)
		_append_class_skipped_file(root_path, "directory_open_failed", 0, "", 0, scan_state)
		_append_class_scan_issue(
			"class_name_directory_open_failed",
			root_path,
			"",
			"无法打开扩展 class_name 扫描目录。",
			scan_state
		)
		return

	var directory_names: PackedStringArray = dir.get_directories()
	var file_names: PackedStringArray = dir.get_files()
	directory_names.sort()
	file_names.sort()
	for directory_name: String in directory_names:
		if directory_name.begins_with("."):
			continue
		var child_path: String = _GF_PATH_TOOLS.normalize_resource_path(
			root_path.path_join(directory_name)
		)
		if max_scan_depth > 0 and depth >= max_scan_depth:
			_mark_class_depth_limit(child_path, max_scan_depth, scan_state)
			continue
		_collect_class_source_files(
			child_path,
			result,
			depth + 1,
			max_scan_depth,
			max_scanned_files,
			scan_state
		)
		if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "stop_scan"):
			return
	for file_name: String in file_names:
		if file_name.begins_with(".") or file_name.get_extension().to_lower() != "gd":
			continue
		var candidate_file_count: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			scan_state,
			"candidate_file_count"
		)
		if max_scanned_files > 0 and candidate_file_count >= max_scanned_files:
			_mark_class_file_count_limit(max_scanned_files, scan_state)
			return
		var path: String = _GF_PATH_TOOLS.normalize_resource_path(root_path.path_join(file_name))
		result.append(path)
		scan_state["candidate_file_count"] = candidate_file_count + 1


static func _read_class_name_source(
	path: String,
	options: Dictionary,
	scan_state: Dictionary
) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"source": "",
	}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_mark_class_scan_partial(scan_state)
		_append_class_skipped_file(path, "read_failed", 0, "", 0, scan_state)
		_append_class_scan_issue(
			"class_name_file_open_failed",
			path,
			"",
			"无法打开扩展 class_name 候选脚本。",
			scan_state
		)
		return result
	var size_bytes: int = file.get_length()
	var max_file_bytes: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		options,
		"max_file_bytes",
		DEFAULT_MAX_FILE_BYTES
	), 0)
	if max_file_bytes > 0 and size_bytes > max_file_bytes:
		file.close()
		_mark_class_byte_budget(
			path,
			"max_file_bytes",
			size_bytes,
			max_file_bytes,
			false,
			scan_state
		)
		return result
	var scanned_bytes: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		scan_state,
		"scanned_bytes"
	)
	var max_total_bytes: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		options,
		"max_total_bytes",
		DEFAULT_MAX_TOTAL_BYTES
	), 0)
	if max_total_bytes > 0 and scanned_bytes + size_bytes > max_total_bytes:
		file.close()
		_mark_class_byte_budget(
			path,
			"max_total_bytes",
			scanned_bytes + size_bytes,
			max_total_bytes,
			true,
			scan_state
		)
		return result
	var source: String = file.get_as_text()
	var read_error: Error = file.get_error()
	file.close()
	if read_error != OK:
		_mark_class_scan_partial(scan_state)
		_append_class_skipped_file(path, "read_failed", size_bytes, "", 0, scan_state)
		_append_class_scan_issue(
			"class_name_file_read_failed",
			path,
			"",
			"读取扩展 class_name 候选脚本失败。",
			scan_state
		)
		return result
	scan_state["scanned_file_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
		scan_state,
		"scanned_file_count"
	) + 1
	scan_state["scanned_bytes"] = scanned_bytes + size_bytes
	result["ok"] = true
	result["source"] = source
	return result


static func _make_class_name_scan_state() -> Dictionary:
	return {
		"class_names_by_target": {},
		"candidate_file_count": 0,
		"scanned_file_count": 0,
		"scanned_bytes": 0,
		"partial_scan": false,
		"budget_exceeded": false,
		"truncated": false,
		"stop_scan": false,
		"skipped_files": [],
		"scan_warnings": [],
		"issues": [],
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
		"budget_warning_emitted": false,
	}


static func _mark_class_scan_partial(scan_state: Dictionary) -> void:
	scan_state["partial_scan"] = true


static func _mark_class_file_count_limit(
	max_scanned_files: int,
	scan_state: Dictionary
) -> void:
	if (
		max_scanned_files <= 0
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "count_warning_emitted")
	):
		return
	scan_state["count_warning_emitted"] = true
	scan_state["truncated"] = true
	scan_state["stop_scan"] = true
	_mark_class_scan_partial(scan_state)
	_append_class_scan_issue(
		"max_scanned_files",
		"",
		"",
		"扩展 class_name 预扫描候选文件数量超过共享配额。",
		scan_state
	)
	_emit_class_scan_warning(
		"扩展 class_name 预扫描达到 max_scanned_files=%d，后续扫描按 partial_scan 处理。"
		% max_scanned_files,
		scan_state
	)


static func _mark_class_depth_limit(
	path: String,
	max_scan_depth: int,
	scan_state: Dictionary
) -> void:
	if (
		max_scan_depth <= 0
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "depth_warning_emitted")
	):
		return
	scan_state["depth_warning_emitted"] = true
	scan_state["truncated"] = true
	_mark_class_scan_partial(scan_state)
	_append_class_scan_issue(
		"max_scan_depth",
		path,
		"",
		"扩展 class_name 预扫描目录深度超过共享配额。",
		scan_state
	)
	_emit_class_scan_warning(
		"扩展 class_name 预扫描达到 max_scan_depth=%d，已跳过更深目录：%s。"
		% [max_scan_depth, path],
		scan_state
	)


static func _mark_class_byte_budget(
	path: String,
	reason: String,
	size_bytes: int,
	limit_bytes: int,
	stop_scan: bool,
	scan_state: Dictionary
) -> void:
	scan_state["budget_exceeded"] = true
	scan_state["truncated"] = true
	if stop_scan:
		scan_state["stop_scan"] = true
	_mark_class_scan_partial(scan_state)
	_append_class_skipped_file(path, reason, size_bytes, reason, limit_bytes, scan_state)
	_append_class_scan_issue(
		reason,
		path,
		"",
		"扩展 class_name 候选脚本超过共享读取字节预算。",
		scan_state
	)
	if _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "budget_warning_emitted"):
		return
	scan_state["budget_warning_emitted"] = true
	_emit_class_scan_warning(
		"扩展 class_name 预扫描达到 %s=%d 字节预算，结果按 partial_scan 处理：%s。"
		% [reason, limit_bytes, path],
		scan_state
	)


static func _mark_class_phase_exhausted(
	class_name_report: Dictionary,
	code: String,
	message: String
) -> void:
	class_name_report["budget_exceeded"] = true
	class_name_report["truncated"] = true
	class_name_report["stop_scan"] = true
	class_name_report["partial_scan"] = true
	_append_class_scan_issue(code, "", "", message, class_name_report)
	_emit_class_scan_warning(message, class_name_report)


static func _append_class_skipped_file(
	path: String,
	reason: String,
	size_bytes: int,
	limit_key: String,
	limit_bytes: int,
	scan_state: Dictionary
) -> void:
	var skipped_files: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		scan_state,
		"skipped_files"
	)
	skipped_files.append({
		"path": path,
		"reason": reason,
		"size_bytes": size_bytes,
		"limit_key": limit_key,
		"limit_bytes": limit_bytes,
		"phase": "class_name_pre_scan",
	})
	scan_state["skipped_files"] = skipped_files


static func _append_class_scan_issue(
	code: String,
	path: String,
	target_id: String,
	message: String,
	scan_state: Dictionary
) -> void:
	var issues: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_state, "issues")
	for issue_value: Variant in issues:
		if not issue_value is Dictionary:
			continue
		var issue: Dictionary = issue_value
		if (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "code") == code
			and _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "path") == path
			and _GF_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "target_id") == target_id
		):
			return
	issues.append({
		"code": code,
		"path": path,
		"target_id": target_id,
		"message": message,
		"phase": "class_name_pre_scan",
	})
	scan_state["issues"] = issues


static func _emit_class_scan_warning(message: String, scan_state: Dictionary) -> void:
	var warning_message: String = "[GFExtensionUsageAudit] %s" % message
	var scan_warnings: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(
		scan_state,
		"scan_warnings"
	)
	if not scan_warnings.has(warning_message):
		scan_warnings.append(warning_message)
		scan_state["scan_warnings"] = scan_warnings
		push_warning(warning_message)


static func _make_empty_project_scan_report(targets: Array[Dictionary]) -> Dictionary:
	return {
		"ok": true,
		"partial_scan": false,
		"budget_exceeded": false,
		"truncated": false,
		"input_target_count": targets.size(),
		"target_count": 0,
		"reference_count": 0,
		"weak_reference_count": 0,
		"targets": {},
		"weak_targets": {},
		"references": [],
		"weak_references": [],
		"candidate_file_count": 0,
		"scanned_file_count": 0,
		"scanned_bytes": 0,
		"skipped_files": [],
		"scan_warnings": [],
		"issue_count": 0,
		"issues": [],
	}


static func _merge_scan_phase_reports(
	project_report: Dictionary,
	class_name_report: Dictionary
) -> Dictionary:
	var result: Dictionary = project_report.duplicate(true)
	var partial_scan: bool = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(project_report, "partial_scan")
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "partial_scan")
	)
	result["partial_scan"] = partial_scan
	result["budget_exceeded"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(project_report, "budget_exceeded")
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "budget_exceeded")
	)
	result["truncated"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(project_report, "truncated")
		or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(class_name_report, "truncated")
	)
	result["candidate_file_count"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(project_report, "candidate_file_count")
		+ _GF_VARIANT_ACCESS_SCRIPT.get_option_int(class_name_report, "candidate_file_count")
	)
	result["scanned_file_count"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(project_report, "scanned_file_count")
		+ _GF_VARIANT_ACCESS_SCRIPT.get_option_int(class_name_report, "scanned_file_count")
	)
	result["scanned_bytes"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(project_report, "scanned_bytes")
		+ _GF_VARIANT_ACCESS_SCRIPT.get_option_int(class_name_report, "scanned_bytes")
	)
	result["skipped_files"] = _merge_report_arrays(
		class_name_report,
		project_report,
		"skipped_files"
	)
	result["scan_warnings"] = _merge_report_arrays(
		class_name_report,
		project_report,
		"scan_warnings"
	)
	result["issues"] = _merge_report_arrays(class_name_report, project_report, "issues")
	result["issue_count"] = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(result, "issues").size()
	result["ok"] = (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_int(project_report, "reference_count") == 0
		and not partial_scan
	)
	result["class_name_scan"] = {
		"partial_scan": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			class_name_report,
			"partial_scan"
		),
		"budget_exceeded": _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(
			class_name_report,
			"budget_exceeded"
		),
		"candidate_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			class_name_report,
			"candidate_file_count"
		),
		"scanned_file_count": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			class_name_report,
			"scanned_file_count"
		),
		"scanned_bytes": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
			class_name_report,
			"scanned_bytes"
		),
		"class_names_by_target": _GF_VARIANT_ACCESS_SCRIPT.get_option_dictionary(
			class_name_report,
			"class_names_by_target"
		),
	}
	return result


static func _merge_report_arrays(
	first_report: Dictionary,
	second_report: Dictionary,
	key: String
) -> Array:
	var result: Array = _GF_VARIANT_ACCESS_SCRIPT.get_option_array(first_report, key).duplicate(true)
	result.append_array(_GF_VARIANT_ACCESS_SCRIPT.get_option_array(second_report, key))
	return result


static func _make_invalid_root_scan_report(root_path: String) -> Dictionary:
	var issue: Dictionary = {
		"code": "invalid_target_root",
		"path": root_path,
		"target_id": root_path,
		"message": "扩展引用扫描 root_path 为空或无效。",
		"phase": "class_name_pre_scan",
	}
	return {
		"ok": false,
		"partial_scan": true,
		"budget_exceeded": false,
		"truncated": false,
		"input_target_count": 1,
		"target_count": 0,
		"reference_count": 0,
		"weak_reference_count": 0,
		"targets": {},
		"weak_targets": {},
		"references": [],
		"weak_references": [],
		"candidate_file_count": 0,
		"scanned_file_count": 0,
		"scanned_bytes": 0,
		"skipped_files": [],
		"scan_warnings": [],
		"issue_count": 1,
		"issues": [issue],
		"class_name_scan": {
			"partial_scan": true,
			"budget_exceeded": false,
			"candidate_file_count": 0,
			"scanned_file_count": 0,
			"scanned_bytes": 0,
			"class_names_by_target": {},
		},
	}
