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

## 默认扫描根目录。
## [br]
## @api public
const DEFAULT_SCAN_ROOTS: Array[String] = ["res://"]

## 默认最大扫描深度。
## [br]
## @api public
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认最大扫描文件数。
## [br]
## @api public
const DEFAULT_MAX_SCANNED_FILES: int = 10000

## 默认忽略的根目录。
## [br]
## @api public
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
## @param manifests: 要检查的禁用扩展 manifest 列表。
## [br]
## @param options: 可选参数，支持 scan_roots、ignored_roots、max_references_per_extension、max_scan_depth、max_scanned_files。
## [br]
## @schema options: Dictionary controlling scan roots, ignored roots, reference limits, depth, and scanned file count.
## [br]
## @return 引用审计报告。
## [br]
## @schema return: Dictionary containing ok, extension_count, reference_count, extensions, and references.
static func audit_disabled_extensions(
	manifests: Array[GFExtensionManifest],
	options: Dictionary = {}
) -> Dictionary:
	var audited_manifests: Array[GFExtensionManifest] = []
	var root_paths: Array[String] = []
	var class_names_by_root: Array[Array] = []
	var references_by_root: Array[Array] = []
	for manifest: GFExtensionManifest in manifests:
		if manifest == null or manifest.root_path.is_empty():
			continue
		var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(manifest.root_path)
		if normalized_root.is_empty():
			continue
		audited_manifests.append(manifest)
		root_paths.append(normalized_root)
		class_names_by_root.append(_collect_extension_class_names(normalized_root))
		references_by_root.append([])

	var extension_reports: Dictionary = {}
	var all_references: Array[Dictionary] = []
	if audited_manifests.is_empty():
		return {
			"ok": true,
			"extension_count": 0,
			"reference_count": 0,
			"extensions": extension_reports,
			"references": all_references,
		}

	var files: Array[String] = _collect_reference_scan_files(options, PackedStringArray())
	var max_references: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_references_per_extension", 50), 1)
	for path: String in files:
		for index: int in range(audited_manifests.size()):
			var references: Array = references_by_root[index]
			if references.size() >= max_references:
				continue
			var root_path: String = root_paths[index]
			if _is_path_ignored(path, PackedStringArray([root_path])):
				continue
			references.append_array(_collect_file_references(
				path,
				root_path,
				class_names_by_root[index],
				max_references - references.size()
			))
			references_by_root[index] = references

	for index: int in range(audited_manifests.size()):
		var manifest: GFExtensionManifest = audited_manifests[index]
		var root_path: String = root_paths[index]
		var references: Array = references_by_root[index]
		if references.is_empty():
			continue

		extension_reports[manifest.id] = {
			"id": manifest.id,
			"display_name": manifest.display_name,
			"root_path": root_path,
			"references": references,
			"reference_count": references.size(),
		}
		all_references.append_array(references)

	return {
		"ok": all_references.is_empty(),
		"extension_count": extension_reports.size(),
		"reference_count": all_references.size(),
		"extensions": extension_reports,
		"references": all_references,
	}


## 查找项目文件中对指定扩展根目录的直接路径引用。
## [br]
## @api public
## [br]
## @param root_path: 扩展根目录。
## [br]
## @param options: 可选参数，支持 scan_roots、ignored_roots、max_references_per_extension、max_scan_depth、max_scanned_files。
## [br]
## @schema options: Dictionary controlling scan roots, ignored roots, reference limits, depth, and scanned file count.
## [br]
## @return 引用列表。
## [br]
## @schema return: Array of Dictionary file reference records.
static func find_references_to_root(root_path: String, options: Dictionary = {}) -> Array[Dictionary]:
	var normalized_root: String = _GF_PATH_TOOLS.normalize_root_path(root_path)
	if normalized_root.is_empty():
		return []

	var files: Array[String] = _collect_reference_scan_files(options, PackedStringArray([normalized_root]))
	var extension_class_names: Array[String] = _collect_extension_class_names(normalized_root)
	var max_references: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_references_per_extension", 50), 1)
	var references: Array[Dictionary] = []
	for path: String in files:
		references.append_array(_collect_file_references(
			path,
			normalized_root,
			extension_class_names,
			max_references - references.size()
		))
		if references.size() >= max_references:
			break
	return references


# --- 私有/辅助方法 ---

static func _collect_reference_scan_files(options: Dictionary, additional_ignored_roots: PackedStringArray) -> Array[String]:
	var scan_roots: PackedStringArray = _GF_PATH_TOOLS.normalize_root_paths(PackedStringArray(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(options, "scan_roots", DEFAULT_SCAN_ROOTS)
	))
	var ignored_roots: PackedStringArray = _GF_PATH_TOOLS.normalize_root_paths(PackedStringArray(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string_array(options, "ignored_roots", DEFAULT_IGNORED_ROOTS)
	))
	for ignored_root: String in additional_ignored_roots:
		if ignored_root.is_empty() or ignored_roots.has(ignored_root):
			continue
		var _append_ignored_root: bool = ignored_roots.append(ignored_root)
	var max_scan_depth: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_scan_depth", DEFAULT_MAX_SCAN_DEPTH), 0)
	var max_scanned_files: int = maxi(_GF_VARIANT_ACCESS_SCRIPT.get_option_int(options, "max_scanned_files", DEFAULT_MAX_SCANNED_FILES), 0)
	var scan_state: Dictionary = _make_scan_state()

	var files: Array[String] = []
	for scan_root: String in scan_roots:
		_collect_text_files(
			scan_root,
			ignored_roots,
			files,
			0,
			max_scan_depth,
			max_scanned_files,
			scan_state
		)
		if not _can_collect_more_files(files, max_scanned_files):
			_warn_scanned_file_limit(max_scanned_files, scan_state)
			break
	return files


static func _collect_text_files(
	root_path: String,
	ignored_roots: PackedStringArray,
	result: Array[String],
	depth: int,
	max_scan_depth: int,
	max_scanned_files: int,
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

	var _list_dir_begin_result_181: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if not _can_collect_more_files(result, max_scanned_files):
			_warn_scanned_file_limit(max_scanned_files, scan_state)
			break

		var path: String = root_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				if _can_scan_deeper(path, depth, max_scan_depth, scan_state):
					_collect_text_files(
						path,
						ignored_roots,
						result,
						depth + 1,
						max_scan_depth,
						max_scanned_files,
						scan_state
					)
		elif _is_text_resource_file(entry):
			result.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


static func _collect_file_references(
	path: String,
	root_path: String,
	class_names: Array,
	remaining: int
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if remaining <= 0:
		return result

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return result

	var lines: PackedStringArray = file.get_as_text().split("\n")
	file.close()
	for line_index: int in range(lines.size()):
		var line: String = String(lines[line_index])
		if _line_references_root(line, root_path):
			result.append(_make_reference(path, line_index + 1, root_path, "path", "", line))
			if result.size() >= remaining:
				break
			continue

		for class_name_value: String in class_names:
			if not _line_references_identifier(line, class_name_value):
				continue
			result.append(_make_reference(path, line_index + 1, root_path, "class_name", class_name_value, line))
			break
		if result.size() >= remaining:
			break
	return result


static func _make_reference(
	path: String,
	line: int,
	root_path: String,
	kind: String,
	symbol: String,
	source_line: String
) -> Dictionary:
	return {
		"path": path,
		"line": line,
		"root_path": root_path,
		"kind": kind,
		"symbol": symbol,
		"preview": source_line.strip_edges().left(180),
	}


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


static func _is_path_ignored(path: String, ignored_roots: PackedStringArray) -> bool:
	return _GF_PATH_TOOLS.is_path_excluded(path, ignored_roots)


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
	var _compile_result_365: Variant = regex.compile("(?m)^\\s*class_name\\s+([A-Za-z_]\\w*)")
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

	var _list_dir_begin_result_398: Variant = dir.list_dir_begin()
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
