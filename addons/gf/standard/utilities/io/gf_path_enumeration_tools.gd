## GFPathEnumerationTools: 只读文件路径枚举工具。
##
## 统一处理目录递归、隐藏文件、扩展名白名单、排除路径、深度上限和数量上限。
## 它只返回路径和扫描报告，不读取文件内容、不生成资源注册表，也不规定项目目录结构。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFPathEnumerationTools
extends RefCounted


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## 默认递归扫描深度上限。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认单次枚举文件数量上限。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_FILE_COUNT: int = 10000

## 默认单次枚举访问的目录项数量上限。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_ENTRY_COUNT: int = 10000


# --- 公共方法 ---

## 枚举目录中的文件路径。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root_path: 扫描起点。
## [br]
## @param options: 可选项，支持 recursive、include_hidden、extensions、excluded_paths、file_filter、max_scan_depth、max_file_count、max_entry_count 和 sort。
## [br]
## @return 按配置枚举出的文件路径。
## [br]
## @schema options: Dictionary with optional recursive, include_hidden, extensions, excluded_paths, file_filter, max_scan_depth, max_file_count, max_entry_count, and sort fields. file_filter receives a normalized file path and returns bool.
static func enumerate_files(root_path: String = "res://", options: Dictionary = {}) -> PackedStringArray:
	var report: Dictionary = scan_files(root_path, options)
	return GFVariantData.get_option_packed_string_array(report, "paths")


## 枚举目录中的文件路径并返回扫描报告。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param root_path: 扫描起点。
## [br]
## @param options: 可选项，支持 recursive、include_hidden、extensions、excluded_paths、file_filter、max_scan_depth、max_file_count、max_entry_count 和 sort。
## [br]
## @return 扫描报告。
## [br]
## @schema options: Dictionary with optional recursive, include_hidden, extensions, excluded_paths, file_filter, max_scan_depth, max_file_count, max_entry_count, and sort fields. file_filter receives a normalized file path and returns bool.
## [br]
## @schema return: Dictionary with ok, root_path, paths, scanned_count, visited_entry_count, truncated, limit_kind, limit_path, and limit_value.
static func scan_files(root_path: String = "res://", options: Dictionary = {}) -> Dictionary:
	var result: PackedStringArray = PackedStringArray()
	var normalized_root: String = _normalize_dir_path(root_path)
	var scan_state: Dictionary = {
		"scanned_count": 0,
		"visited_entry_count": 0,
		"truncated": false,
		"stop_scan": false,
		"limit_kind": "",
		"limit_path": "",
		"limit_value": 0,
	}
	if normalized_root.is_empty():
		return _make_report(false, normalized_root, result, scan_state)

	var recursive: bool = GFVariantData.get_option_bool(options, "recursive", true)
	var include_hidden: bool = GFVariantData.get_option_bool(options, "include_hidden", false)
	var extensions: PackedStringArray = _normalize_extensions(
		GFVariantData.get_option_packed_string_array(options, "extensions", PackedStringArray())
	)
	var excluded_paths: PackedStringArray = _normalize_paths(
		GFVariantData.get_option_packed_string_array(options, "excluded_paths", PackedStringArray())
	)
	var file_filter: Callable = _get_file_filter(options)
	var max_scan_depth: int = maxi(GFVariantData.get_option_int(options, "max_scan_depth", DEFAULT_MAX_SCAN_DEPTH), 0)
	var max_file_count: int = maxi(
		GFVariantData.get_option_int(
			options,
			"max_file_count",
			GFVariantData.get_option_int(options, "max_resource_paths", DEFAULT_MAX_FILE_COUNT)
		),
		0
	)
	var max_entry_count: int = maxi(
		GFVariantData.get_option_int(options, "max_entry_count", DEFAULT_MAX_ENTRY_COUNT),
		0
	)
	_scan_directory_recursive(
		normalized_root,
		result,
		0,
		recursive,
		include_hidden,
		extensions,
		excluded_paths,
		file_filter,
		max_scan_depth,
		max_file_count,
		max_entry_count,
		scan_state
	)
	if GFVariantData.get_option_bool(options, "sort", true):
		result.sort()
	return _make_report(true, normalized_root, result, scan_state)


# --- 私有/辅助方法 ---

static func _scan_directory_recursive(
	dir_path: String,
	result: PackedStringArray,
	depth: int,
	recursive: bool,
	include_hidden: bool,
	extensions: PackedStringArray,
	excluded_paths: PackedStringArray,
	file_filter: Callable,
	max_scan_depth: int,
	max_file_count: int,
	max_entry_count: int,
	scan_state: Dictionary
) -> void:
	if _should_stop_scan(scan_state) or _is_excluded_path(dir_path, excluded_paths):
		return

	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.include_hidden = include_hidden

	var list_error: Error = dir.list_dir_begin()
	if list_error != OK:
		return

	var entry: String = dir.get_next()
	while not entry.is_empty():
		if _should_stop_scan(scan_state):
			break
		if not include_hidden and entry.begins_with("."):
			entry = dir.get_next()
			continue

		var child_path: String = dir_path.path_join(entry)
		if not _consume_entry_budget(child_path, max_entry_count, scan_state):
			break
		if dir.current_is_dir():
			if recursive and _can_scan_deeper(child_path, depth, max_scan_depth, scan_state):
				_scan_directory_recursive(
					child_path,
					result,
					depth + 1,
					recursive,
					include_hidden,
					extensions,
					excluded_paths,
					file_filter,
					max_scan_depth,
					max_file_count,
					max_entry_count,
					scan_state
				)
		elif _can_include_file(child_path, extensions, file_filter):
			var _appended: bool = result.append(child_path)
			scan_state["scanned_count"] = GFVariantData.get_option_int(scan_state, "scanned_count") + 1
			if max_file_count > 0 and GFVariantData.get_option_int(scan_state, "scanned_count") >= max_file_count:
				_mark_scan_limit(scan_state, "count", child_path, max_file_count)
		entry = dir.get_next()
	dir.list_dir_end()


static func _can_scan_deeper(path: String, current_depth: int, max_scan_depth: int, scan_state: Dictionary) -> bool:
	if max_scan_depth <= 0 or current_depth < max_scan_depth:
		return true
	_mark_scan_limit(scan_state, "depth", path, max_scan_depth)
	return false


static func _consume_entry_budget(path: String, max_entry_count: int, scan_state: Dictionary) -> bool:
	var visited_entry_count: int = GFVariantData.get_option_int(scan_state, "visited_entry_count")
	if max_entry_count > 0 and visited_entry_count >= max_entry_count:
		_mark_scan_limit(scan_state, "entry_count", path, max_entry_count)
		return false
	scan_state["visited_entry_count"] = visited_entry_count + 1
	return true


static func _mark_scan_limit(scan_state: Dictionary, kind: String, path: String, value: int) -> void:
	scan_state["truncated"] = true
	if kind == "count" or kind == "entry_count":
		scan_state["stop_scan"] = true
	if kind == "count" or kind == "entry_count" or GFVariantData.get_option_string(scan_state, "limit_kind", "").is_empty():
		scan_state["limit_kind"] = kind
		scan_state["limit_path"] = path
		scan_state["limit_value"] = value


static func _can_include_file(path: String, extensions: PackedStringArray, file_filter: Callable) -> bool:
	if not extensions.is_empty() and not extensions.has(path.get_extension().to_lower()):
		return false
	return not file_filter.is_valid() or GFVariantData.to_bool(file_filter.call(path))


static func _get_file_filter(options: Dictionary) -> Callable:
	var value: Variant = GFVariantData.get_option_value(options, "file_filter", Callable())
	if value is Callable:
		return value
	return Callable()


static func _should_stop_scan(scan_state: Dictionary) -> bool:
	return GFVariantData.get_option_bool(scan_state, "stop_scan")


static func _normalize_extensions(values: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: String in values:
		var extension: String = value.strip_edges().to_lower()
		if extension.begins_with("."):
			extension = extension.substr(1)
		if not extension.is_empty() and not result.has(extension):
			var _appended: bool = result.append(extension)
	return result


static func _normalize_paths(values: PackedStringArray) -> PackedStringArray:
	return _GF_PATH_TOOLS.normalize_root_paths(values, false)


static func _normalize_dir_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_root_path(path, "", false)


static func _is_excluded_path(path: String, excluded_paths: PackedStringArray) -> bool:
	return _GF_PATH_TOOLS.is_path_excluded(path, excluded_paths)


static func _make_report(
	ok: bool,
	root_path: String,
	paths: PackedStringArray,
	scan_state: Dictionary
) -> Dictionary:
	return {
		"ok": ok,
		"root_path": root_path,
		"paths": paths,
		"scanned_count": GFVariantData.get_option_int(scan_state, "scanned_count"),
		"visited_entry_count": GFVariantData.get_option_int(scan_state, "visited_entry_count"),
		"truncated": GFVariantData.get_option_bool(scan_state, "truncated"),
		"limit_kind": GFVariantData.get_option_string(scan_state, "limit_kind", ""),
		"limit_path": GFVariantData.get_option_string(scan_state, "limit_path", ""),
		"limit_value": GFVariantData.get_option_int(scan_state, "limit_value", 0),
	}
