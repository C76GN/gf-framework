@tool

# 编辑器项目资源来源。只遍历 Godot 已有索引，不加载资源、不写入 UID。
extends Node


# --- 信号 ---

## 完整快照构建结束；失败时 catalog 为 null，旧快照由使用方保留并标为过期。
## [br]
## @api framework_internal
## [br]
## @param catalog: 完整目录或 null。
## [br]
## @param report: 构建结果。
## [br]
## @schema report: Dictionary with ok, status, count, scope and generation.
signal completed(catalog: GFAssetCatalog, report: Dictionary)

## Godot 索引发生变化，使用方应作废当前结果。
## [br]
## @api framework_internal
signal invalidated


# --- 常量 ---

const _SNAPSHOT_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_project_asset_snapshot.gd")
const _FRAME_ITEM_BUDGET: int = 128
const _FRAME_USEC_BUDGET: int = 2000


# --- 私有变量 ---

var _filesystem: EditorFileSystem = null
var _directories: Array[EditorFileSystemDirectory] = []
var _current_directory: EditorFileSystemDirectory = null
var _file_index: int = 0
var _directory_index: int = 0
var _snapshot: _SNAPSHOT_SCRIPT = null
var _scope: String = "res://"
var _type_filter: String = ""
var _include_addons: bool = false
var _generation: int = 0
var _pending: bool = false
var _active: bool = false


# --- Godot 生命周期方法 ---

func _ready() -> void:
	set_process(false)
	if Engine.is_editor_hint():
		_filesystem = EditorInterface.get_resource_filesystem()
		if _filesystem != null:
			var _changed_connection: int = _filesystem.filesystem_changed.connect(_on_filesystem_changed)
			var _reimport_connection: int = _filesystem.resources_reimported.connect(_on_resources_changed)
			var _reload_connection: int = _filesystem.resources_reload.connect(_on_resources_changed)


func _exit_tree() -> void:
	cancel()
	if is_instance_valid(_filesystem):
		if _filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
			_filesystem.filesystem_changed.disconnect(_on_filesystem_changed)
		if _filesystem.resources_reimported.is_connected(_on_resources_changed):
			_filesystem.resources_reimported.disconnect(_on_resources_changed)
		if _filesystem.resources_reload.is_connected(_on_resources_changed):
			_filesystem.resources_reload.disconnect(_on_resources_changed)
	_filesystem = null


func _process(_delta: float) -> void:
	if not _active or _filesystem == null or _filesystem.is_scanning():
		return
	if _pending:
		_pending = false
		var root_directory: EditorFileSystemDirectory = _filesystem.get_filesystem_path(_scope)
		if root_directory == null:
			_finish("scope_unavailable")
			return
		_directories.append(root_directory)
	var started_usec: int = Time.get_ticks_usec()
	var visited: int = 0
	while visited < _FRAME_ITEM_BUDGET and Time.get_ticks_usec() - started_usec < _FRAME_USEC_BUDGET:
		if _current_directory == null:
			if _directories.is_empty():
				_finish("complete")
				return
			_current_directory = _directories.pop_back()
			_file_index = 0
			_directory_index = 0
		if _directory_index < _current_directory.get_subdir_count():
			var child_directory: EditorFileSystemDirectory = _current_directory.get_subdir(_directory_index)
			_directory_index += 1
			if _allows_path(child_directory.get_path()):
				_directories.append(child_directory)
			visited += 1
			continue
		if _file_index >= _current_directory.get_file_count():
			_current_directory = null
			continue
		var path: String = _current_directory.get_file_path(_file_index)
		var resource_type: String = _current_directory.get_file_type(_file_index)
		_file_index += 1
		visited += 1
		if resource_type.is_empty() or not _allows_path(path) or not matches_type(resource_type, _type_filter):
			continue
		var entry: GFAssetCatalogEntry = make_entry(path, resource_type, ResourceLoader.get_resource_uid(path))
		if not _snapshot.append_entry(entry):
			_finish("snapshot_failed")
			return


# --- 框架内部方法 ---

## 开始分帧读取指定目录；已有任务失效，不触发 EditorFileSystem.scan。
## [br]
## @api framework_internal
## [br]
## @param scope: res:// 目录。
## [br]
## @param type_filter: Godot 类型或空字符串。
## [br]
## @param include_addons: 是否包括插件资源。
func start_scan(scope: String = "res://", type_filter: String = "", include_addons: bool = false) -> void:
	cancel()
	_scope = scope.strip_edges().simplify_path()
	_type_filter = type_filter
	_include_addons = include_addons
	_snapshot = _SNAPSHOT_SCRIPT.new()
	if not _scope.begins_with("res://") or _scope.contains(".."):
		_finish("invalid_scope")
		return
	if _filesystem == null:
		_finish("editor_unavailable")
		return
	_pending = true
	_active = true
	set_process(true)


## 终止当前索引构建并释放未发布的引擎目录引用。
## [br]
## @api framework_internal
func cancel() -> void:
	_generation += 1
	_active = false
	_pending = false
	_directories.clear()
	_current_directory = null
	_snapshot = null
	set_process(false)


## 从已有身份建立纯目录条目；无 UID 时保留完整路径以避免同名冲突。
## [br]
## @api framework_internal
## [br]
## @param path: 项目资源路径。
## [br]
## @param resource_type: Godot 类型。
## [br]
## @param existing_uid: 已有 UID，负值表示不存在。
## [br]
## @return 只包含元数据的目录条目。
static func make_entry(path: String, resource_type: String, existing_uid: int = -1) -> GFAssetCatalogEntry:
	var normalized_path: String = path.simplify_path()
	var identity: String = ResourceUID.id_to_text(existing_uid) if existing_uid >= 0 else normalized_path
	var entry: GFAssetCatalogEntry = GFAssetCatalogEntry.new()
	entry.asset_id = StringName(identity)
	entry.primary_path = normalized_path
	entry.title = normalized_path.get_file()
	entry.type_hint = resource_type
	entry.source_id = &"project_filesystem"
	entry.metadata = {"identity_kind": "uid" if existing_uid >= 0 else "path", "directory": normalized_path.get_base_dir()}
	return entry


## 类型筛选允许 Godot 内置类型继承；未知脚本类型仍可精确匹配。
## [br]
## @api framework_internal
## [br]
## @param resource_type: 索引中的类型。
## [br]
## @param expected_type: 筛选类型或空字符串。
## [br]
## @return 是否匹配。
static func matches_type(resource_type: String, expected_type: String) -> bool:
	return expected_type.is_empty() or resource_type == expected_type or ClassDB.is_parent_class(resource_type, expected_type)


# --- 私有/辅助方法 ---

func _allows_path(path: String) -> bool:
	if not _include_addons and (path == "res://addons" or path.begins_with("res://addons/")):
		return false
	for component: String in path.trim_prefix("res://").split("/"):
		if component.begins_with("."):
			return false
	return true


func _finish(status: String) -> void:
	var snapshot_report: Dictionary = _snapshot.finish() if _snapshot != null else {}
	var result: GFAssetCatalog = null
	var catalog_value: Variant = snapshot_report.get("catalog")
	if status == "complete" and catalog_value is GFAssetCatalog:
		result = catalog_value
	if status == "snapshot_failed":
		status = GFVariantData.get_option_string(snapshot_report, "status", "snapshot_failed")
	var count: int = GFVariantData.get_option_int(snapshot_report, "count")
	_active = false
	_pending = false
	_directories.clear()
	_current_directory = null
	_snapshot = null
	set_process(false)
	completed.emit(result, {"ok": result != null, "status": status, "count": count, "scope": _scope, "generation": _generation})


# --- 信号处理函数 ---

func _on_filesystem_changed() -> void:
	cancel()
	invalidated.emit()


func _on_resources_changed(_paths: PackedStringArray) -> void:
	_on_filesystem_changed()
