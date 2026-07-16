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
const _GF_PATH_ENUMERATION_TOOLS = preload("res://addons/gf/standard/utilities/io/gf_path_enumeration_tools.gd")

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
## @since 3.23.0
## [br]
## @return 当前快照字典。
## [br]
## @schema return: Dictionary keyed by file path with file metadata dictionaries containing modified_time, size_bytes, and content_sha256.
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
		if _is_truncated(scan_state):
			break
		var scan_report: Dictionary = _GF_PATH_ENUMERATION_TOOLS.scan_files(
			root_path,
			_make_enumeration_options(scan_state)
		)
		var paths: PackedStringArray = GFVariantData.get_option_packed_string_array(scan_report, "paths")
		for path: String in paths:
			result[path] = _make_file_snapshot(path)
		scan_state["scanned_count"] = (
			GFVariantData.get_option_int(scan_state, "scanned_count")
			+ GFVariantData.get_option_int(scan_report, "scanned_count")
		)
		if GFVariantData.get_option_bool(scan_report, "truncated"):
			scan_state["truncated"] = true
	return result


func _make_change_set(next_snapshot: Dictionary, scan_state: Dictionary) -> GFDirectoryChangeSet:
	var created: PackedStringArray = PackedStringArray()
	var modified: PackedStringArray = PackedStringArray()
	var deleted: PackedStringArray = PackedStringArray()

	for path: String in next_snapshot.keys():
		if not _snapshot.has(path):
			var _appended: bool = created.append(path)
		elif not _snapshot_entries_equal(
			GFVariantData.as_dictionary(_snapshot[path]),
			GFVariantData.as_dictionary(next_snapshot[path])
		):
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


func _make_enumeration_options(scan_state: Dictionary) -> Dictionary:
	var remaining_file_count: int = 0
	if max_file_count > 0:
		remaining_file_count = maxi(max_file_count - GFVariantData.get_option_int(scan_state, "scanned_count"), 0)
		if remaining_file_count <= 0:
			scan_state["truncated"] = true
	return {
		"recursive": recursive,
		"include_hidden": include_hidden,
		"extensions": extensions,
		"excluded_paths": excluded_paths,
		"max_scan_depth": max_scan_depth,
		"max_file_count": remaining_file_count,
		"sort": true,
	}


func _make_file_snapshot(path: String) -> Dictionary:
	return {
		"modified_time": int(FileAccess.get_modified_time(path)),
		"size_bytes": _get_file_size(path),
		"content_sha256": _compute_file_sha256(path),
	}


func _snapshot_entries_equal(left: Dictionary, right: Dictionary) -> bool:
	return (
		GFVariantData.get_option_int(left, "modified_time", -1) == GFVariantData.get_option_int(right, "modified_time", -2)
		and GFVariantData.get_option_int(left, "size_bytes", -1) == GFVariantData.get_option_int(right, "size_bytes", -2)
		and GFVariantData.get_option_string(left, "content_sha256", "") == GFVariantData.get_option_string(right, "content_sha256", " ")
	)


func _get_file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var length: int = file.get_length()
	file.close()
	return length


func _compute_file_sha256(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""

	var hashing: HashingContext = HashingContext.new()
	var start_error: Error = hashing.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		file.close()
		return ""

	while file.get_position() < file.get_length():
		var remaining_bytes: int = file.get_length() - file.get_position()
		var buffer_size: int = mini(65_536, remaining_bytes)
		var update_error: Error = hashing.update(file.get_buffer(buffer_size))
		if update_error != OK:
			file.close()
			return ""
	file.close()
	return hashing.finish().hex_encode()


func _is_truncated(scan_state: Dictionary) -> bool:
	return GFVariantData.get_option_bool(scan_state, "truncated")


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
