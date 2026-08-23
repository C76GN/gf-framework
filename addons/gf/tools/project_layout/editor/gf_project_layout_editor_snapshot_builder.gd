@tool

## GFProjectLayoutEditorSnapshotBuilder: 编辑器主线程上的分批项目库存捕获器。
##
## 每次 step() 只处理有界条目，并把最终输入冻结为 data-only snapshot。
## 它不会触发 EditorFileSystem.scan()、资源导入或任何项目写入。
## [br]
## @api framework_internal
## [br]
## @category internal_helper
## [br]
## @since unreleased
class_name GFProjectLayoutEditorSnapshotBuilder
extends RefCounted


# --- 常量 ---

const _ANALYSIS_CONTRACT_SCRIPT = preload(
	"res://addons/gf/tools/project_layout/gf_project_layout_analysis_contract.gd"
)
const _OPTION_FIELDS: PackedStringArray = [
	"include_hidden",
	"max_scanned_files",
	"max_scanned_directories",
	"max_scan_depth",
]
const _SNAPSHOT_ISSUE_FIELDS: PackedStringArray = [
	"severity",
	"kind",
	"path",
	"message",
]
const _MAX_SNAPSHOT_ISSUES: int = 1_024
const _DEFAULT_MAX_SCANNED_FILES: int = \
	_ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_FILES
const _DEFAULT_MAX_SCANNED_DIRECTORIES: int = \
	_ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_DIRECTORIES
const _DEFAULT_MAX_SCAN_DEPTH: int = _ANALYSIS_CONTRACT_SCRIPT.MAX_SCAN_DEPTH
const _PROJECT_SOURCE_EXCLUDED_PREFIXES: PackedStringArray = [
	".git",
	".godot",
	".import",
]


# --- 私有变量 ---

var _root_path: String = "res://"
var _include_hidden: bool = true
var _max_scanned_files: int = _DEFAULT_MAX_SCANNED_FILES
var _max_scanned_directories: int = _DEFAULT_MAX_SCANNED_DIRECTORIES
var _max_scan_depth: int = _DEFAULT_MAX_SCAN_DEPTH
var _files: PackedStringArray = PackedStringArray()
var _directories: PackedStringArray = PackedStringArray()
var _pending_directories: Array[Dictionary] = []
var _pending_cursor: int = 0
var _current_directory: DirAccess = null
var _current_relative_path: String = ""
var _current_depth: int = 0
var _status: String = "idle"
var _issues: Array[Dictionary] = []
var _cancel_requested: bool = false
var _inventory_string_bytes: int = 0
var _resource_limit_failed: bool = false


# --- 框架内部方法 ---

## 开始新的项目库存捕获。
## [br]
## @api framework_internal
## [br]
## @param root_path: 规范的 res:// 项目源码根或子根。
## [br]
## @param options: 捕获预算。
## [br]
## @schema options: Dictionary，可包含 include_hidden、max_scanned_files、max_scanned_directories 和 max_scan_depth。
## [br]
## @return Godot 错误码。
func begin(root_path: String = "res://", options: Dictionary = {}) -> Error:
	if _status == "capturing":
		return ERR_BUSY
	_reset_state()
	if root_path.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH:
		_set_resource_limit_failure()
		_status = "failed"
		return ERR_INVALID_PARAMETER
	if not _read_options(options):
		_status = "failed"
		return ERR_INVALID_PARAMETER
	_inventory_string_bytes = _snapshot_base_string_bytes(
		root_path,
		"capturing"
	)
	if _inventory_string_bytes > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES:
		_set_resource_limit_failure()
		_status = "failed"
		return ERR_INVALID_PARAMETER
	if not _is_canonical_root_path(root_path):
		_add_issue("invalid_root_path", root_path, "库存根路径必须是规范 res:// 根或子根。")
		_status = "failed"
		return ERR_INVALID_PARAMETER
	_root_path = root_path
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_root_path)):
		_add_issue("root_path_not_found", _root_path, "库存根目录不存在。")
		_status = "failed"
		return ERR_DOES_NOT_EXIST
	if _path_crosses_link(_root_path):
		_add_issue("linked_root_path_not_allowed", _root_path, "库存根路径不能穿过符号链接或目录联接。")
		_status = "failed"
		return ERR_INVALID_PARAMETER
	_pending_directories.append({ "relative_path": "", "depth": 0 })
	_status = "capturing"
	return OK


## 处理下一批目录条目。
## [br]
## @api framework_internal
## [br]
## @param max_entries: 本帧最多处理的目录条目数量。
## [br]
## @return 当前进度快照。
## [br]
## @schema return: Dictionary，精确包含 status、file_count、directory_count、pending_directory_count 和 issues。
func step(max_entries: int = 256) -> Dictionary:
	if max_entries < 1:
		_add_issue("invalid_step_budget", "max_entries", "step 预算必须是正整数。")
		_finish("failed")
		return get_progress()
	if _status != "capturing":
		return get_progress()
	if _cancel_requested:
		_finish("cancelled")
		return get_progress()

	var processed_entries: int = 0
	while processed_entries < max_entries and _status == "capturing":
		if _cancel_requested:
			_finish("cancelled")
			break
		if _current_directory == null:
			if not _open_next_directory():
				break
			processed_entries += 1
			if processed_entries >= max_entries:
				break
		var entry_name: String = _current_directory.get_next()
		if entry_name.is_empty():
			_close_current_directory()
			continue
		processed_entries += 1
		if entry_name == "." or entry_name == "..":
			continue
		if not _entry_path_length_is_admissible(entry_name):
			_set_resource_limit_failure()
			_finish("partial")
			break
		var relative_path: String = _join_relative_path(
			_current_relative_path,
			entry_name
		)
		if _is_excluded_project_source_path(relative_path):
			continue
		if not _include_hidden and entry_name.begins_with("."):
			continue
		if not _reserve_inventory_path(relative_path):
			_set_resource_limit_failure()
			_finish("partial")
			break
		if _current_directory.is_link(entry_name):
			_add_issue(
				"linked_path_not_allowed",
				relative_path,
				"项目库存不会穿过符号链接或目录联接。"
			)
			_finish("partial")
			break
		if _current_directory.current_is_dir():
			if _directories.size() >= _max_scanned_directories:
				_add_issue(
					"scan_directory_limit_reached",
					relative_path,
					"项目库存超过目录数量上限。"
				)
				_finish("partial")
				break
			var child_depth: int = _current_depth + 1
			if child_depth > _max_scan_depth:
				_add_issue(
					"scan_depth_limit_reached",
					relative_path,
					"项目库存超过目录深度上限。"
				)
				_finish("partial")
				break
			var _append_directory: bool = _directories.append(relative_path)
			_pending_directories.append({
				"relative_path": relative_path,
				"depth": child_depth,
			})
		else:
			if _files.size() >= _max_scanned_files:
				_add_issue(
					"scan_file_limit_reached",
					relative_path,
					"项目库存超过文件数量上限。"
				)
				_finish("partial")
				break
			var _append_file: bool = _files.append(relative_path)
	return get_progress()


## 请求在下一批边界取消捕获。
## [br]
## @api framework_internal
func cancel() -> void:
	_cancel_requested = true


## 返回捕获是否已经停止。
## [br]
## @api framework_internal
## [br]
## @return: 捕获已进入终态时为 true。
func is_finished() -> bool:
	return _status != "capturing" and _status != "idle"


## 返回当前状态。
## [br]
## @api framework_internal
## [br]
## @return: idle、capturing、complete、partial、cancelled 或 failed。
func get_status() -> String:
	return _status


## 返回当前捕获进度。
## [br]
## @api framework_internal
## [br]
## @return Dictionary，包含 status、file_count、directory_count、pending_directory_count 和 issues。
## [br]
## @schema return: Dictionary，精确包含 status、file_count、directory_count、pending_directory_count 和 issues。
func get_progress() -> Dictionary:
	return {
		"status": _status,
		"file_count": _files.size(),
		"directory_count": _directories.size(),
		"pending_directory_count": maxi(
			_pending_directories.size() - _pending_cursor,
			0
		),
		"issues": _issues.duplicate(true),
	}


## 生成 data-only 项目库存。
## [br]
## @api framework_internal
## [br]
## @return: complete/partial 捕获的 project_layout_snapshot；idle、capturing、cancelled 或 failed 时返回空 Dictionary。
## [br]
## @schema return: 非空结果精确包含 schema_version、kind、root_path、scope、complete、capture_status、files、directories 和 issues；capture_status 只可能是 complete 或 partial，scope 精确包含 kind、root_path、include_hidden、excluded_prefixes、max_scanned_files、max_scanned_directories 和 max_scan_depth。
func make_snapshot() -> Dictionary:
	if not ["complete", "partial"].has(_status):
		return {}
	if not _captured_inventory_is_admissible():
		_set_resource_limit_failure()
		_finish("partial")
	var sorted_files: PackedStringArray = _files.duplicate()
	sorted_files.sort()
	var sorted_directories: PackedStringArray = _directories.duplicate()
	sorted_directories.sort()
	return {
		"schema_version": 1,
		"kind": "project_layout_snapshot",
		"root_path": _root_path,
		"scope": {
			"kind": "project_source",
			"root_path": _root_path,
			"include_hidden": _include_hidden,
			"excluded_prefixes": Array(_PROJECT_SOURCE_EXCLUDED_PREFIXES),
			"max_scanned_files": _max_scanned_files,
			"max_scanned_directories": _max_scanned_directories,
			"max_scan_depth": _max_scan_depth,
		},
		"complete": _status == "complete",
		"capture_status": _status,
		"files": Array(sorted_files),
		"directories": Array(sorted_directories),
		"issues": _issues.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _open_next_directory() -> bool:
	if _pending_cursor >= _pending_directories.size():
		_finish("complete")
		return false
	var pending: Dictionary = _pending_directories[_pending_cursor]
	_pending_cursor += 1
	_current_relative_path = _get_string(pending, "relative_path")
	_current_depth = _get_int(pending, "depth")
	var current_path: String = _root_path
	if not _current_relative_path.is_empty():
		current_path = _root_path.path_join(_current_relative_path)
	if _path_crosses_link(current_path):
		_add_issue(
			"linked_path_not_allowed",
			_current_relative_path,
			"项目库存不会打开穿过符号链接或目录联接的目录。"
		)
		_finish("partial")
		return false
	var directory: DirAccess = DirAccess.open(
		ProjectSettings.globalize_path(current_path)
	)
	if directory == null:
		_add_issue("directory_scan_failed", _current_relative_path, "目录无法打开。")
		_finish("partial")
		return false
	if _path_crosses_link(current_path):
		_add_issue(
			"linked_path_not_allowed",
			_current_relative_path,
			"目录打开后路径链发生变化，项目库存拒绝开始枚举。"
		)
		_finish("partial")
		return false
	_current_directory = directory
	_current_directory.include_hidden = _include_hidden
	var begin_error: Error = _current_directory.list_dir_begin()
	if begin_error != OK:
		_add_issue("directory_scan_failed", _current_relative_path, "目录无法枚举。")
		_finish("partial")
		return false
	return true


func _close_current_directory() -> void:
	if _current_directory != null:
		_current_directory.list_dir_end()
	_current_directory = null
	_current_relative_path = ""
	_current_depth = 0


func _finish(status: String) -> void:
	_close_current_directory()
	_status = status


func _reset_state() -> void:
	_close_current_directory()
	_root_path = "res://"
	_include_hidden = true
	_max_scanned_files = _DEFAULT_MAX_SCANNED_FILES
	_max_scanned_directories = _DEFAULT_MAX_SCANNED_DIRECTORIES
	_max_scan_depth = _DEFAULT_MAX_SCAN_DEPTH
	_files = PackedStringArray()
	_directories = PackedStringArray()
	_pending_directories.clear()
	_pending_cursor = 0
	_status = "idle"
	_issues.clear()
	_cancel_requested = false
	_inventory_string_bytes = 0
	_resource_limit_failed = false


func _read_options(options: Dictionary) -> bool:
	if options.size() > _OPTION_FIELDS.size():
		_set_resource_limit_failure()
		return false
	for key_value: Variant in options.keys():
		if not key_value is String:
			_set_option_admission_failure()
			return false
		var key: String = key_value
		if key.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH:
			_set_resource_limit_failure()
			return false
		if not _OPTION_FIELDS.has(key):
			_set_option_admission_failure()
			return false
	if options.has("include_hidden"):
		var include_hidden_value: Variant = options["include_hidden"]
		if not include_hidden_value is bool:
			_set_option_admission_failure()
			return false
		_include_hidden = include_hidden_value
	for budget_limit: Dictionary in [
		{
			"field": "max_scanned_files",
			"maximum": _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_FILES,
		},
		{
			"field": "max_scanned_directories",
			"maximum": _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_DIRECTORIES,
		},
		{
			"field": "max_scan_depth",
			"maximum": _ANALYSIS_CONTRACT_SCRIPT.MAX_SCAN_DEPTH,
		},
	]:
		var field_name: String = _get_string(budget_limit, "field")
		if not options.has(field_name):
			continue
		var budget_value: Variant = options[field_name]
		if not budget_value is int:
			_set_option_admission_failure()
			return false
		var budget: int = budget_value
		if budget <= 0:
			_set_option_admission_failure()
			return false
		if budget > _get_int(budget_limit, "maximum"):
			_set_resource_limit_failure()
			return false
		if field_name == "max_scanned_files":
			_max_scanned_files = budget
		elif field_name == "max_scanned_directories":
			_max_scanned_directories = budget
		else:
			_max_scan_depth = budget
	return true


func _entry_path_length_is_admissible(entry_name: String) -> bool:
	if entry_name.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH:
		return false
	var separator_length: int = 0 if _current_relative_path.is_empty() else 1
	return (
		_current_relative_path.length()
		+ separator_length
		+ entry_name.length()
		<= _ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH
	)


func _reserve_inventory_path(relative_path: String) -> bool:
	if relative_path.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH:
		return false
	var path_bytes: int = relative_path.to_utf8_buffer().size()
	if (
		_inventory_string_bytes
		> _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES - path_bytes
	):
		return false
	_inventory_string_bytes += path_bytes
	return true


func _captured_inventory_is_admissible() -> bool:
	if _resource_limit_failed:
		return false
	if (
		_files.size() > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_FILES
		or _directories.size() > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_DIRECTORIES
		or not _ANALYSIS_CONTRACT_SCRIPT.basic_inventory_counts_are_admissible(
			_files.size(),
			_directories.size(),
			true
		)
		or _root_path.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH
		or _status.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH
		or not _ANALYSIS_CONTRACT_SCRIPT.inventory_budgets_are_admissible(
			_max_scanned_files,
			_max_scanned_directories,
			_max_scan_depth
		)
		or _issues.size() > _MAX_SNAPSHOT_ISSUES
	):
		return false
	var total_bytes: int = _snapshot_base_string_bytes(_root_path, _status)
	if total_bytes > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES:
		return false
	for relative_path: String in _directories:
		if relative_path.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH:
			return false
		total_bytes += relative_path.to_utf8_buffer().size()
		if total_bytes > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES:
			return false
	for relative_path: String in _files:
		if relative_path.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_RELATIVE_PATH_LENGTH:
			return false
		total_bytes += relative_path.to_utf8_buffer().size()
		if total_bytes > _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES:
			return false
	for issue: Dictionary in _issues:
		if (
			issue.size() != _SNAPSHOT_ISSUE_FIELDS.size()
			or not _dictionary_has_only_fields(issue, _SNAPSHOT_ISSUE_FIELDS)
		):
			return false
		for field_name: String in _SNAPSHOT_ISSUE_FIELDS:
			var field_bytes: int = field_name.to_utf8_buffer().size()
			if (
				total_bytes
				> _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES - field_bytes
			):
				return false
			total_bytes += field_bytes
			var text_value: Variant = issue.get(field_name)
			if not text_value is String:
				return false
			var text: String = text_value
			if text.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH:
				return false
			var text_bytes: int = text.to_utf8_buffer().size()
			if (
				total_bytes
				> _ANALYSIS_CONTRACT_SCRIPT.MAX_INVENTORY_STRING_BYTES - text_bytes
			):
				return false
			total_bytes += text_bytes
	return true


func _snapshot_base_string_bytes(root_path: String, capture_status: String) -> int:
	var result: int = 0
	for text: String in [
		"schema_version",
		"kind",
		"root_path",
		"scope",
		"complete",
		"capture_status",
		"files",
		"directories",
		"issues",
		"project_layout_snapshot",
		root_path,
		"kind",
		"root_path",
		"include_hidden",
		"excluded_prefixes",
		"max_scanned_files",
		"max_scanned_directories",
		"max_scan_depth",
		"project_source",
		root_path,
		".git",
		".godot",
		".import",
		capture_status,
	]:
		result += text.to_utf8_buffer().size()
	return result


func _dictionary_has_only_fields(
	value: Dictionary,
	allowed_fields: PackedStringArray
) -> bool:
	if value.size() > allowed_fields.size():
		return false
	for key_value: Variant in value.keys():
		if not key_value is String:
			return false
		var key: String = key_value
		if (
			key.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH
			or not allowed_fields.has(key)
		):
			return false
	return true


func _set_option_admission_failure() -> void:
	if not _issues.is_empty():
		return
	_add_issue(
		"invalid_snapshot_builder_options",
		"",
		"库存捕获选项未通过闭合字段与类型准入。"
	)


func _set_resource_limit_failure() -> void:
	if _resource_limit_failed:
		return
	_resource_limit_failed = true
	_close_current_directory()
	_files = PackedStringArray()
	_directories = PackedStringArray()
	_pending_directories.clear()
	_pending_cursor = 0
	if _root_path.length() > _ANALYSIS_CONTRACT_SCRIPT.MAX_DATA_STRING_LENGTH:
		_root_path = "res://"
	_inventory_string_bytes = 0
	_issues.clear()
	_add_issue(
		"snapshot_builder_resource_limit_exceeded",
		"",
		"项目库存输入超过固有资源边界；捕获未继续。"
	)


func _add_issue(kind: String, path: String, message: String) -> void:
	_issues.append({
		"severity": "error",
		"kind": kind,
		"path": path,
		"message": message,
	})


func _is_canonical_root_path(path: String) -> bool:
	if (
		path.is_empty()
		or path != path.strip_edges()
		or path.contains("\\")
		or not path.begins_with("res://")
	):
		return false
	var relative_path: String = path.substr("res://".length())
	if relative_path.is_empty():
		return true
	if relative_path.ends_with("/") or relative_path.contains(":"):
		return false
	for part: String in relative_path.split("/", true):
		if part.is_empty() or part == "." or part == "..":
			return false
	return true


func _path_crosses_link(path: String) -> bool:
	var probe_path: String = ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	while not probe_path.is_empty():
		var parent_path: String = probe_path.get_base_dir()
		if parent_path == probe_path or parent_path.is_empty():
			return false
		var parent_directory: DirAccess = DirAccess.open(parent_path)
		if parent_directory == null:
			return true
		if parent_directory.is_link(probe_path.get_file()):
			return true
		probe_path = parent_path
	return false


func _join_relative_path(base_path: String, entry_name: String) -> String:
	if base_path.is_empty():
		return entry_name.replace("\\", "/")
	return base_path.path_join(entry_name).replace("\\", "/")


func _is_excluded_project_source_path(relative_path: String) -> bool:
	for excluded_prefix: String in _PROJECT_SOURCE_EXCLUDED_PREFIXES:
		if (
			relative_path == excluded_prefix
			or relative_path.begins_with("%s/" % excluded_prefix)
		):
			return true
	return false


func _get_string(source: Dictionary, key: String, default_value: String = "") -> String:
	var value: Variant = source.get(key, default_value)
	return value if value is String else default_value


func _get_int(source: Dictionary, key: String, default_value: int = 0) -> int:
	var value: Variant = source.get(key, default_value)
	return value if value is int else default_value
