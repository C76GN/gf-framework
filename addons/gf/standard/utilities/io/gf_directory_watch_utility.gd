## GFDirectoryWatchUtility: 调用方驱动的目录变化检测工具。
##
## 通过显式 poll() 对目录快照做差异比较，适合编辑器工具、资产索引器、
## 构建脚本或项目安装器按自己的节奏刷新资源。它不创建 Autoload，
## 也不在后台自行扫描。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.23.0
class_name GFDirectoryWatchUtility
extends RefCounted


# --- 信号 ---

## poll() 发现文件变化时发出。
## [br]
## @api public
## [br]
## @param change_set: 本次变化集。
signal changed(change_set: GFDirectoryChangeSet)


# --- 常量 ---

const _GF_PATH_TOOLS = preload("res://addons/gf/kernel/core/gf_path_tools.gd")

## 默认递归扫描深度上限。
## [br]
## @api public
const DEFAULT_MAX_SCAN_DEPTH: int = 32

## 默认单次扫描文件数量上限。
## [br]
## @api public
const DEFAULT_MAX_FILE_COUNT: int = 10000

# --- 公共变量 ---

## 是否递归扫描子目录。
## [br]
## @api public
var recursive: bool = true

## 是否包含隐藏文件和隐藏目录。
## [br]
## @api public
var include_hidden: bool = false

## 可选扩展名白名单。不包含点号；为空表示包含全部文件。
## [br]
## @api public
var extensions: PackedStringArray = PackedStringArray()

## 排除路径。命中目录或其子路径会被跳过。
## [br]
## @api public
var excluded_paths: PackedStringArray = PackedStringArray()

## 递归扫描深度上限。0 表示不限制。
## [br]
## @api public
var max_scan_depth: int = DEFAULT_MAX_SCAN_DEPTH

## 单次扫描文件数量上限。0 表示不限制。
## [br]
## @api public
var max_file_count: int = DEFAULT_MAX_FILE_COUNT

## 首次 poll() 是否把已存在文件报告为 created。
## [br]
## @api public
var report_existing_on_first_scan: bool = false


# --- 私有变量 ---

var _watch_paths: PackedStringArray = PackedStringArray()
var _snapshot: Dictionary = {}
var _has_snapshot: bool = false


# --- 公共方法 ---

## 按字典选项配置检测器。
## [br]
## @api public
## [br]
## @param options: 可选项，支持 recursive、include_hidden、extensions、excluded_paths、max_scan_depth、max_file_count 和 report_existing_on_first_scan。
## [br]
## @return 当前检测器。
## [br]
## @schema options: Dictionary controlling scan behavior.
func configure(options: Dictionary = {}) -> GFDirectoryWatchUtility:
	recursive = GFVariantData.get_option_bool(options, "recursive", recursive)
	include_hidden = GFVariantData.get_option_bool(options, "include_hidden", include_hidden)
	extensions = _normalize_extensions(
		GFVariantData.get_option_packed_string_array(options, "extensions", extensions)
	)
	excluded_paths = _normalize_paths(
		GFVariantData.get_option_packed_string_array(options, "excluded_paths", excluded_paths)
	)
	max_scan_depth = maxi(GFVariantData.get_option_int(options, "max_scan_depth", max_scan_depth), 0)
	max_file_count = maxi(GFVariantData.get_option_int(options, "max_file_count", max_file_count), 0)
	report_existing_on_first_scan = GFVariantData.get_option_bool(
		options,
		"report_existing_on_first_scan",
		report_existing_on_first_scan
	)
	return self


## 添加监听目录。
## [br]
## @api public
## [br]
## @param path: 要监听的目录路径。
func watch_path(path: String) -> void:
	var normalized: String = _normalize_dir_path(path)
	if normalized.is_empty() or _watch_paths.has(normalized):
		return
	var _appended: bool = _watch_paths.append(normalized)
	_watch_paths.sort()


## 移除监听目录。
## [br]
## @api public
## [br]
## @param path: 要移除的目录路径。
## [br]
## @return 成功移除时返回 true。
func unwatch_path(path: String) -> bool:
	var normalized: String = _normalize_dir_path(path)
	var index: int = _watch_paths.find(normalized)
	if index < 0:
		return false
	_watch_paths.remove_at(index)
	reset_snapshot()
	return true


## 清空监听目录。
## [br]
## @api public
func clear_watch_paths() -> void:
	_watch_paths.clear()
	reset_snapshot()


## 获取监听目录副本。
## [br]
## @api public
## [br]
## @return 监听目录列表。
func get_watch_paths() -> PackedStringArray:
	return _watch_paths.duplicate()


## 清空已有快照。下一次 poll() 会重新建立基线。
## [br]
## @api public
func reset_snapshot() -> void:
	_snapshot.clear()
	_has_snapshot = false


## 扫描当前监听目录并返回变化集。
## [br]
## @api public
## [br]
## @return 本次变化集。
func poll() -> GFDirectoryChangeSet:
	var scan_state: Dictionary = _make_scan_state()
	var next_snapshot: Dictionary = _scan_watch_paths(scan_state)
	var change_set: GFDirectoryChangeSet = _make_change_set(next_snapshot, scan_state)
	_snapshot = next_snapshot

	if not _has_snapshot:
		_has_snapshot = true
		if not report_existing_on_first_scan:
			change_set.created.clear()
			change_set.modified.clear()
			change_set.deleted.clear()

	if not change_set.is_empty():
		changed.emit(change_set)
	return change_set


## 获取当前快照副本。
## [br]
## @api public
## [br]
## @return 当前快照字典。
## [br]
## @schema return: Dictionary keyed by file path with modified_time values.
func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 检测器状态字典。
## [br]
## @schema return: Dictionary with watch_paths, snapshot_size, has_snapshot, and scan options.
func get_debug_snapshot() -> Dictionary:
	return {
		"watch_paths": get_watch_paths(),
		"snapshot_size": _snapshot.size(),
		"has_snapshot": _has_snapshot,
		"recursive": recursive,
		"include_hidden": include_hidden,
		"extensions": extensions,
		"excluded_paths": excluded_paths,
		"max_scan_depth": max_scan_depth,
		"max_file_count": max_file_count,
		"report_existing_on_first_scan": report_existing_on_first_scan,
	}


# --- 私有/辅助方法 ---

func _scan_watch_paths(scan_state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for root_path: String in _watch_paths:
		_scan_directory_recursive(root_path, result, 0, scan_state)
	return result


func _scan_directory_recursive(
	dir_path: String,
	result: Dictionary,
	depth: int,
	scan_state: Dictionary
) -> void:
	if _is_truncated(scan_state):
		return
	if _is_excluded_path(dir_path):
		return

	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return

	var _list_dir_begin_result_248: Variant = dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if _is_truncated(scan_state):
			break

		if not include_hidden and entry.begins_with("."):
			entry = dir.get_next()
			continue

		var child_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if recursive and _can_scan_deeper(child_path, depth, scan_state):
				_scan_directory_recursive(child_path, result, depth + 1, scan_state)
		elif _can_include_file(entry):
			result[child_path] = int(FileAccess.get_modified_time(child_path))
			scan_state["scanned_count"] = GFVariantData.get_option_int(scan_state, "scanned_count") + 1
			if max_file_count > 0 and GFVariantData.get_option_int(scan_state, "scanned_count") >= max_file_count:
				scan_state["truncated"] = true
		entry = dir.get_next()
	dir.list_dir_end()


func _make_change_set(next_snapshot: Dictionary, scan_state: Dictionary) -> GFDirectoryChangeSet:
	var created: PackedStringArray = PackedStringArray()
	var modified: PackedStringArray = PackedStringArray()
	var deleted: PackedStringArray = PackedStringArray()

	for path: String in next_snapshot.keys():
		if not _snapshot.has(path):
			var _appended: bool = created.append(path)
		elif GFVariantData.to_int(_snapshot[path]) != GFVariantData.to_int(next_snapshot[path]):
			var _appended: bool = modified.append(path)

	for path: String in _snapshot.keys():
		if not next_snapshot.has(path):
			var _appended: bool = deleted.append(path)

	created.sort()
	modified.sort()
	deleted.sort()
	return GFDirectoryChangeSet.new().configure(
		get_watch_paths(),
		created,
		modified,
		deleted,
		GFVariantData.get_option_int(scan_state, "scanned_count"),
		next_snapshot.size(),
		GFVariantData.get_option_bool(scan_state, "truncated")
	)


func _make_scan_state() -> Dictionary:
	return {
		"scanned_count": 0,
		"truncated": false,
	}


func _is_truncated(scan_state: Dictionary) -> bool:
	return GFVariantData.get_option_bool(scan_state, "truncated")


func _can_scan_deeper(_path: String, current_depth: int, scan_state: Dictionary) -> bool:
	if max_scan_depth <= 0 or current_depth < max_scan_depth:
		return true
	scan_state["truncated"] = true
	return false


func _can_include_file(path: String) -> bool:
	if extensions.is_empty():
		return true
	return extensions.has(path.get_extension().to_lower())


func _normalize_extensions(values: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: String in values:
		var extension: String = value.strip_edges().to_lower()
		if extension.begins_with("."):
			extension = extension.substr(1)
		if not extension.is_empty() and not result.has(extension):
			var _appended: bool = result.append(extension)
	return result


func _normalize_paths(values: PackedStringArray) -> PackedStringArray:
	return _GF_PATH_TOOLS.normalize_root_paths(values, false)


func _normalize_dir_path(path: String) -> String:
	return _GF_PATH_TOOLS.normalize_root_path(path, "", false)


func _is_excluded_path(path: String) -> bool:
	return _GF_PATH_TOOLS.is_path_excluded(path, excluded_paths)
