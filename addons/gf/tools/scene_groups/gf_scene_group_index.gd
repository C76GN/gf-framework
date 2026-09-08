@tool

## GFSceneGroupIndex: 编辑器期已保存场景 Group 声明位置索引。
##
## 只读取磁盘 .tscn / .scn 自身 SceneState 中的持久化声明，不实例化场景节点，
## 不把继承或嵌套来源已有的组复制到引用场景。隐藏条目与 .gdignore 子树不在扫描范围内。
## 主线程 advance() 在目录项、节点和组之间让出控制；单次 ResourceLoader.load()
## 不能被抢占。引擎资源加载器和自定义 Resource 的加载行为仍由 Godot 管理。
## [br]
## @api public
## [br]
## @category tool_api
## [br]
## @since unreleased
class_name GFSceneGroupIndex
extends RefCounted


# --- 常量 ---

const _HARD_LIMITS: Dictionary = {
	"max_depth": 32,
	"max_entries": 100_000,
	"max_scenes": 10_000,
	"max_rows": 50_000,
	"max_scene_bytes": 8_388_608,
}
const _MAX_ISSUES: int = 64
const _MAX_ADVANCE_BUDGET: int = 4_096
const _MAX_PATH_LENGTH: int = 4_096
const _PHASE_DISCOVERY: int = 0
const _PHASE_SCENES: int = 1


# --- 私有变量 ---

var _status: String = "idle"
var _root_path: String = ""
var _limits: Dictionary = {}
var _entry_count: int = 0
var _scene_count: int = 0
var _issues: Array[Dictionary] = []
var _omitted_issue_count: int = 0
var _rows: Array[Dictionary] = []
var _row_keys: Dictionary = {}
var _rows_sorted: bool = true
var _phase: int = _PHASE_DISCOVERY
var _directory: DirAccess = null
var _directory_path: String = ""
var _directory_depth: int = 0
var _pending_directories: Array[String] = []
var _pending_depths: Array[int] = []
var _scene_paths: PackedStringArray = PackedStringArray()
var _scene_cursor: int = 0
var _scene_state: SceneState = null
var _scene_path: String = ""
var _node_cursor: int = 0
var _node_path: String = ""
var _node_groups: PackedStringArray = PackedStringArray()
var _group_cursor: int = 0
var _advancing: bool = false
var _generation: int = 0


# --- 公共方法 ---

## 丢弃旧索引并开始扫描项目内目录。未知选项、非法类型或越界值会拒绝请求。
## 目录打不开时返回 ERR_CANT_OPEN；路径链含链接时拒绝读取。根目录有 .gdignore
## 时返回 OK 并以 partial / ignored_root 结束。扫描中的重入调用返回 ERR_BUSY。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param root_path: 规范 res:// 目录；不接受相对路径、反斜杠、空片段或点路径穿越。
## [br]
## @param options: 只允许降低内置扫描上限。
## [br]
## @schema options: Dictionary，键为 max_depth（int，0..32）、max_entries（int，1..100000）、max_scenes（int，1..10000）、max_rows（int，1..50000）、max_scene_bytes（int，1..8388608）。省略使用上限，0 深度仅扫描根目录。
## [br]
## @return OK 表示请求有效；ERR_INVALID_PARAMETER、ERR_CANT_OPEN 或 ERR_BUSY 表示拒绝。
func begin_scan(root_path: String = "res://", options: Dictionary = {}) -> Error:
	if _advancing:
		return ERR_BUSY
	_clear_work()
	_generation += 1
	_status = "idle"
	_root_path = root_path
	_entry_count = 0
	_scene_count = 0
	_issues.clear()
	_omitted_issue_count = 0
	_rows.clear()
	_row_keys.clear()
	_rows_sorted = true
	_limits = _HARD_LIMITS.duplicate()
	if not _is_valid_root_path(root_path) or not _configure_options(options):
		_status = "failed"
		_append_issue("invalid_request", root_path, "扫描目录或选项不符合约定。")
		return ERR_INVALID_PARAMETER
	if _root_path != "res://":
		_root_path = _root_path.trim_suffix("/")
	var root_error: Error = _validate_root_chain()
	if root_error != OK:
		_status = "failed"
		return root_error
	_directory = DirAccess.open(_root_path)
	if _directory == null:
		_status = "failed"
		_append_issue("directory_unreadable", _root_path, "无法打开扫描目录。")
		return ERR_CANT_OPEN
	if _directory.file_exists(".gdignore"):
		_append_issue("ignored_root", _root_path, "扫描根目录包含 .gdignore，不读取该目录。")
		_directory = null
		_status = "partial"
		return OK
	_directory_path = _root_path
	_directory_depth = 0
	_directory.include_hidden = false
	_directory.include_navigational = false
	if _directory.list_dir_begin() != OK:
		_clear_work()
		_status = "failed"
		_append_issue("directory_unreadable", _root_path, "无法枚举扫描目录。")
		return ERR_CANT_OPEN
	_phase = _PHASE_DISCOVERY
	_status = "scanning"
	return OK


## 在主线程推进有界工作量。每个目录项、目录打开、场景加载、节点或组占一个单位。
## 单次引擎资源加载不受单位预算抢占；不启动后台任务。无效预算令当前扫描 failed。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param entry_budget: 本次最多处理的工作单位，范围 1..4096。
## [br]
## @return 返回 true 表示仍为 scanning，false 表示当前无需继续调用。
func advance(entry_budget: int = 64) -> bool:
	if _status != "scanning":
		return false
	if _advancing:
		return true
	if entry_budget < 1 or entry_budget > _MAX_ADVANCE_BUDGET:
		_append_issue("invalid_advance_budget", _root_path, "推进预算必须为 1..4096。")
		_finish("failed")
		return false
	_advancing = true
	for _work_index: int in range(entry_budget):
		if _status != "scanning":
			break
		if _phase == _PHASE_DISCOVERY:
			_advance_directory()
		elif _scene_state != null:
			_advance_scene_declaration()
		else:
			_load_next_scene()
	_advancing = false
	return _status == "scanning"


## 取消当前扫描并立即关闭目录枚举，保留已发现记录供查看。
## 终态调用不改变结果；新的 begin_scan() 会清空旧记录。
## [br]
## @api public
## [br]
## @since unreleased
func cancel() -> void:
	if _status == "scanning":
		_generation += 1
		_finish("cancelled")


## 返回摘要和最多 64 条诊断的副本，不包含整个索引。
## complete 仅表示已完成本次范围的声明扫描；不是运行时成员、实例展开或同时刻的文件系统快照。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前扫描摘要。
## [br]
## @schema return: Dictionary，包含 status（idle/scanning/complete/partial/cancelled/failed）、root_path、entry_count（已枚举文件和目录数）、scene_count（尝试读取的场景数）、row_count、issues（Array[Dictionary]，每项 code/path/message）和 omitted_issue_count。
func get_snapshot() -> Dictionary:
	return {
		"status": _status,
		"root_path": _root_path,
		"entry_count": _entry_count,
		"scene_count": _scene_count,
		"row_count": _rows.size(),
		"issues": _issues.duplicate(true),
		"omitted_issue_count": _omitted_issue_count,
	}


## 搜索组名、场景路径或节点路径。搜索忽略大小写，但保留不同组名的精确身份。
## 结果稳定按 group、scene_path、node_path 排序；返回行均为副本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param text: 子字符串搜索文本；空文本匹配所有记录。
## [br]
## @param offset: 起始记录偏移，负数按 0 处理。
## [br]
## @param limit: 页大小，限制到 0..200；0 只计算总数。
## [br]
## @return 有界分页与匹配总数。
## [br]
## @schema return: Dictionary，包含 rows（Array[Dictionary]，每项 group:String、scene_path:String、node_path:String）、total:int、offset:int、limit:int。node_path 相对声明场景根，根节点为 .。
func query(text: String = "", offset: int = 0, limit: int = 100) -> Dictionary:
	_sort_rows()
	var page_offset: int = maxi(offset, 0)
	var page_limit: int = clampi(limit, 0, 200)
	var needle: String = text.to_lower()
	var matches: int = 0
	var page_rows: Array[Dictionary] = []
	for row: Dictionary in _rows:
		if not _matches_query(row, needle):
			continue
		if matches >= page_offset and page_rows.size() < page_limit:
			page_rows.append(row.duplicate(true))
		matches += 1
	return {
		"rows": page_rows,
		"total": matches,
		"offset": page_offset,
		"limit": page_limit,
	}


# --- 私有/辅助方法 ---

func _is_valid_root_path(root_path: String) -> bool:
	if not root_path.begins_with("res://") or root_path.length() > _MAX_PATH_LENGTH:
		return false
	var relative_path: String = root_path.trim_prefix("res://").trim_suffix("/")
	if relative_path.is_empty():
		return root_path == "res://"
	if relative_path.contains("\\") or relative_path.contains(":"):
		return false
	for character_index: int in range(relative_path.length()):
		if relative_path.unicode_at(character_index) < 32:
			return false
	for component: String in relative_path.split("/", true):
		if component.is_empty() or component == "." or component == "..":
			return false
	return true


func _configure_options(options: Dictionary) -> bool:
	for key: Variant in options:
		if not key is String or not _HARD_LIMITS.has(key):
			return false
		var value: Variant = options[key]
		if not value is int:
			return false
		var limit_value: int = value
		var option_name: String = key
		var maximum_value: Variant = _HARD_LIMITS[option_name]
		if not maximum_value is int:
			return false
		var maximum: int = maximum_value
		var minimum: int = 0 if option_name == "max_depth" else 1
		if limit_value < minimum or limit_value > maximum:
			return false
		_limits[option_name] = limit_value
	return true


func _validate_root_chain() -> Error:
	var parent_path: String = "res://"
	var relative_path: String = _root_path.trim_prefix("res://")
	if relative_path.is_empty():
		return OK
	for component: String in relative_path.split("/"):
		var parent_directory: DirAccess = DirAccess.open(parent_path)
		if parent_directory == null:
			_append_issue("directory_unreadable", parent_path, "无法检查扫描目录的父路径。")
			return ERR_CANT_OPEN
		if parent_directory.is_link(component):
			_append_issue("linked_root", parent_path.path_join(component), "扫描根目录不能穿过文件系统链接。")
			return ERR_INVALID_PARAMETER
		if parent_directory.file_exists(".gdignore"):
			_append_issue("ignored_ancestor", parent_path, "扫描根目录位于 .gdignore 子树内。")
			return ERR_INVALID_PARAMETER
		parent_path = parent_path.path_join(component)
	return OK


func _advance_directory() -> void:
	if _directory == null:
		_open_next_directory()
		return
	var entry: String = _directory.get_next()
	if entry.is_empty():
		_directory.list_dir_end()
		_directory = null
		return
	if _entry_count >= _limit("max_entries"):
		_append_issue("entry_limit", _root_path, "已达到目录条目上限，后续路径未扫描。")
		_finish_discovery()
		return
	_entry_count += 1
	var child_path: String = _directory_path.path_join(entry)
	if entry.begins_with("."):
		return
	if _directory.is_link(entry):
		_append_issue("linked_entry", child_path, "不扫描文件系统链接。")
		return
	if _directory.current_is_dir():
		if FileAccess.file_exists(child_path.path_join(".gdignore")):
			return
		if _directory_depth >= _limit("max_depth"):
			_append_issue("depth_limit", child_path, "目录超过扫描深度，未读取其内容。")
			return
		_pending_directories.append(child_path)
		_pending_depths.append(_directory_depth + 1)
		return
	var extension: String = entry.get_extension().to_lower()
	if extension != "tscn" and extension != "scn":
		return
	if _scene_paths.size() >= _limit("max_scenes"):
		_append_issue("scene_limit", child_path, "已达到场景数量上限，后续路径未扫描。")
		_finish_discovery()
		return
	var _appended: bool = _scene_paths.append(child_path)


func _open_next_directory() -> void:
	if _pending_directories.is_empty():
		_finish_discovery()
		return
	var last_index: int = _pending_directories.size() - 1
	_directory_path = _pending_directories[last_index]
	_directory_depth = _pending_depths[last_index]
	_pending_directories.remove_at(last_index)
	_pending_depths.remove_at(last_index)
	if not _is_unlinked_path(_directory_path):
		_append_issue("linked_entry", _directory_path, "目录路径已消失或成为文件系统链接。")
		return
	_directory = DirAccess.open(_directory_path)
	if _directory == null:
		_append_issue("directory_unreadable", _directory_path, "无法打开已发现的目录。")
		return
	if _directory.file_exists(".gdignore"):
		_directory = null
		return
	_directory.include_hidden = false
	_directory.include_navigational = false
	if _directory.list_dir_begin() != OK:
		_append_issue("directory_unreadable", _directory_path, "无法枚举已发现的目录。")
		_directory = null


func _finish_discovery() -> void:
	if _directory != null:
		_directory.list_dir_end()
	_directory = null
	_pending_directories.clear()
	_pending_depths.clear()
	_scene_paths.sort()
	_scene_cursor = 0
	_phase = _PHASE_SCENES


func _load_next_scene() -> void:
	if _scene_cursor >= _scene_paths.size():
		_finish("complete" if _issues.is_empty() and _omitted_issue_count == 0 else "partial")
		return
	_scene_path = _scene_paths[_scene_cursor]
	_scene_cursor += 1
	_scene_count += 1
	if not _is_unlinked_path(_scene_path):
		_append_issue("linked_entry", _scene_path, "场景路径已消失或成为文件系统链接。")
		return
	var file: FileAccess = FileAccess.open(_scene_path, FileAccess.READ)
	if file == null:
		_append_issue("scene_unreadable", _scene_path, "无法打开已发现的场景文件。")
		return
	var file_length: int = file.get_length()
	file.close()
	if file_length > _limit("max_scene_bytes"):
		_append_issue("scene_size_limit", _scene_path, "场景文件超过单文件大小上限。")
		return
	var load_generation: int = _generation
	var loaded: Resource = ResourceLoader.load(_scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if _generation != load_generation or _status != "scanning":
		return
	if not loaded is PackedScene:
		_append_issue("scene_load_failed", _scene_path, "Godot 无法将文件读取为 PackedScene。")
		return
	var packed_scene: PackedScene = loaded
	_scene_state = packed_scene.get_state()
	if _scene_state == null or _scene_state.get_node_count() == 0:
		_append_issue("scene_state_invalid", _scene_path, "场景没有可读取的节点声明。")
		_scene_state = null
		return
	_node_cursor = 0
	_node_groups.clear()
	_group_cursor = 0


func _advance_scene_declaration() -> void:
	if _group_cursor < _node_groups.size():
		var group: String = _node_groups[_group_cursor]
		_group_cursor += 1
		var key: String = JSON.stringify([_scene_path, _node_path, group])
		if _row_keys.has(key):
			return
		if _rows.size() >= _limit("max_rows"):
			_append_issue("row_limit", _scene_path, "已达到 Group 声明数量上限。")
			_finish("partial")
			return
		_row_keys[key] = true
		_rows.append({ "group": group, "scene_path": _scene_path, "node_path": _node_path })
		_rows_sorted = false
		return
	if _node_cursor >= _scene_state.get_node_count():
		_scene_state = null
		_node_groups.clear()
		return
	_node_path = String(_scene_state.get_node_path(_node_cursor)).trim_prefix("./")
	if _node_path.is_empty():
		_node_path = "."
	_node_groups = _scene_state.get_node_groups(_node_cursor)
	_group_cursor = 0
	_node_cursor += 1


func _is_unlinked_path(resource_path: String) -> bool:
	var parent_path: String = "res://"
	for component: String in resource_path.trim_prefix("res://").split("/"):
		var parent_directory: DirAccess = DirAccess.open(parent_path)
		if parent_directory == null or parent_directory.is_link(component):
			return false
		parent_path = parent_path.path_join(component)
	return true


func _limit(option_name: String) -> int:
	var value: Variant = _limits.get(option_name, 0)
	if value is int:
		var typed_value: int = value
		return typed_value
	return 0


func _append_issue(code: String, path: String, message: String) -> void:
	if _issues.size() >= _MAX_ISSUES:
		_omitted_issue_count += 1
		return
	_issues.append({ "code": code, "path": path.left(_MAX_PATH_LENGTH), "message": message })


func _finish(status: String) -> void:
	_clear_work()
	_status = status
	_sort_rows()


func _clear_work() -> void:
	if _directory != null:
		_directory.list_dir_end()
	_directory = null
	_pending_directories.clear()
	_pending_depths.clear()
	_scene_paths.clear()
	_scene_state = null
	_node_groups.clear()
	_scene_path = ""
	_node_path = ""
	_scene_cursor = 0
	_node_cursor = 0
	_group_cursor = 0


func _sort_rows() -> void:
	if not _rows_sorted:
		_rows.sort_custom(_row_precedes)
		_rows_sorted = true


func _row_precedes(left: Dictionary, right: Dictionary) -> bool:
	for field: String in ["group", "scene_path", "node_path"]:
		var left_value: String = _row_string(left, field)
		var right_value: String = _row_string(right, field)
		if left_value != right_value:
			return left_value < right_value
	return false


func _matches_query(row: Dictionary, needle: String) -> bool:
	if needle.is_empty():
		return true
	for field: String in ["group", "scene_path", "node_path"]:
		if _row_string(row, field).to_lower().contains(needle):
			return true
	return false


func _row_string(row: Dictionary, field: String) -> String:
	var value: Variant = row.get(field, "")
	if value is String:
		var typed_value: String = value
		return typed_value
	return ""
