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
	"res://ai_analysis",
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
## @schema return: Dictionary containing ok, partial_scan, budget_exceeded, extension_count, reference_count, weak_reference_count, extensions, weak_extensions, references, weak_references, scanned_file_count, scanned_bytes, skipped_files, and scan_warnings. references only contains strong or verified blocking references.
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
			"class_names": _collect_extension_class_names(normalized_root),
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

	var scan_options: Dictionary = _make_scanner_options(options, PackedStringArray(root_paths))
	var scan_report: Dictionary = _GF_PROJECT_REFERENCE_SCANNER_SCRIPT.scan_references(scan_targets, scan_options)
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
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	if normalized_root.is_empty():
		return []

	var scan_options: Dictionary = _make_scanner_options(options, PackedStringArray([normalized_root]))
	var extension_class_names: Array[String] = _collect_extension_class_names(normalized_root)
	var include_weak_references: bool = _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(options, "include_weak_references", false)
	scan_options["include_weak_references"] = include_weak_references
	var scan_report: Dictionary = _GF_PROJECT_REFERENCE_SCANNER_SCRIPT.scan_root_references(
		normalized_root,
		extension_class_names,
		scan_options
	)
	var references: Array[Dictionary] = []
	_append_typed_references(
		references,
		_GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "references")
	)
	if include_weak_references:
		_append_typed_references(
			references,
			_GF_VARIANT_ACCESS_SCRIPT.get_option_array(scan_report, "weak_references")
		)
	return references


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


static func _collect_extension_class_names(root_path: String) -> Array[String]:
	var files: Array[String] = []
	var scan_state: Dictionary = _make_scan_state()
	_collect_gd_files(
		root_path,
		files,
		0,
		DEFAULT_MAX_SCAN_DEPTH,
		DEFAULT_MAX_SCANNED_FILES,
		scan_state
	)

	var names: Array[String] = []
	var regex: RegEx = RegEx.new()
	var _compile_result: Variant = regex.compile("(?m)^\\s*class_name\\s+([A-Za-z_]\\w*)")
	for path: String in files:
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var source: String = file.get_as_text()
		file.close()
		var match_result: RegExMatch = regex.search(source)
		if match_result == null:
			continue
		var class_name_value: String = match_result.get_string(1)
		if not names.has(class_name_value):
			names.append(class_name_value)
	names.sort()
	return names


static func _collect_gd_files(
	root_path: String,
	result: Array[String],
	depth: int,
	max_scan_depth: int,
	max_scanned_files: int,
	scan_state: Dictionary
) -> void:
	if not _can_collect_more_files(result, max_scanned_files):
		_warn_scanned_file_limit(max_scanned_files, scan_state)
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
					_collect_gd_files(
						path,
						result,
						depth + 1,
						max_scan_depth,
						max_scanned_files,
						scan_state
					)
		elif entry.ends_with(".gd"):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


static func _can_scan_deeper(path: String, current_depth: int, max_scan_depth: int, scan_state: Dictionary) -> bool:
	if max_scan_depth <= 0 or current_depth < max_scan_depth:
		return true
	_warn_scan_depth_limit(path, max_scan_depth, scan_state)
	return false


static func _can_collect_more_files(result: Array[String], max_scanned_files: int) -> bool:
	return max_scanned_files <= 0 or result.size() < max_scanned_files


static func _make_scan_state() -> Dictionary:
	return {
		"count_warning_emitted": false,
		"depth_warning_emitted": false,
	}


static func _warn_scanned_file_limit(max_scanned_files: int, scan_state: Dictionary) -> void:
	if max_scanned_files <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "count_warning_emitted"):
		return
	scan_state["count_warning_emitted"] = true
	push_warning("[GFExtensionUsageAudit] 已达到 max_scanned_files=%d，后续文件已跳过。" % max_scanned_files)


static func _warn_scan_depth_limit(path: String, max_scan_depth: int, scan_state: Dictionary) -> void:
	if max_scan_depth <= 0 or _GF_VARIANT_ACCESS_SCRIPT.get_option_bool(scan_state, "depth_warning_emitted"):
		return
	scan_state["depth_warning_emitted"] = true
	push_warning("[GFExtensionUsageAudit] 已达到 max_scan_depth=%d，已跳过更深目录：%s。" % [max_scan_depth, path])
