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

## 创建每轮扫描的候选快照累积器；由它统一拒绝容量溢出及重复条目身份。
## [br]
## @api private
const _SNAPSHOT_SCRIPT = preload("res://addons/gf/tools/asset_browser/editor/gf_project_asset_snapshot.gd")

## 每帧最多检查的目录项数，子目录与文件均计入，未通过筛选的项也消耗预算。
## [br]
## @api private
const _FRAME_ITEM_BUDGET: int = 128

## 每帧目录遍历的微秒时间预算，在每次处理下一项前检查，不中断已开始的单项操作。
## [br]
## @api private
const _FRAME_USEC_BUDGET: int = 2000


# --- 私有变量 ---

## 借用 Godot 编辑器文件索引并订阅其变化；离树时撤销订阅和引用，不负责启动索引扫描。
## [br]
## @api private
var _filesystem: EditorFileSystem = null

## 尚待遍历的引擎目录引用栈，按后进先出取出；取消或完成时清空，索引变化后不继续沿用。
## [br]
## @api private
var _directories: Array[EditorFileSystemDirectory] = []

## 当前分帧遍历的引擎目录，先检查子目录再检查文件；结束该目录或终结扫描时释放引用。
## [br]
## @api private
var _current_directory: EditorFileSystemDirectory = null

## 当前目录下一份待检查文件的索引，跨帧保留，切换目录时归零。
## [br]
## @api private
var _file_index: int = 0

## 当前目录下一份待检查子目录的索引；每次检查后推进，切换目录时归零。
## [br]
## @api private
var _directory_index: int = 0

## 本轮尚未发布的快照累积器；取消直接丢弃，完成时消费其结果，失败不发布部分目录。
## [br]
## @api private
var _snapshot: _SNAPSHOT_SCRIPT = null

## 当前请求经去空白和路径简化后的根目录，用于取得引擎目录及标识完成报告的扫描范围。
## [br]
## @api private
var _scope: String = "res://"

## 本轮资源类型筛选，空值接受所有已识别类型，否则允许精确类型或 Godot 内置继承关系。
## [br]
## @api private
var _type_filter: String = ""

## 本轮是否允许进入 res://addons 子树；点开头的路径组件始终跳过。
## [br]
## @api private
var _include_addons: bool = false

## 每次取消（含开始新扫描前的取消）递增的请求身份，随完成报告交给宿主辨别结果所属轮次。
## [br]
## @api private
var _generation: int = 0

## 表示活动扫描尚未取得根目录；等待原生索引停止扫描后，在下一处理帧只取一次。
## [br]
## @api private
var _pending: bool = false

## 控制分帧构建是否仍可推进；取消或完成时先关闭并清理状态，再停止处理或发出结果。
## [br]
## @api private
var _active: bool = false


# --- Godot 生命周期方法 ---

## 入树后默认停止逐帧处理，并借用原生文件索引服务监听结构、重导入和重载变化；不主动触发原生扫描。
## [br]
## @api private
func _ready() -> void:
	set_process(false)
	if Engine.is_editor_hint():
		_filesystem = EditorInterface.get_resource_filesystem()
		if _filesystem != null:
			var _changed_connection: int = _filesystem.filesystem_changed.connect(_on_filesystem_changed)
			var _reimport_connection: int = _filesystem.resources_reimported.connect(_on_resources_changed)
			var _reload_connection: int = _filesystem.resources_reload.connect(_on_resources_changed)


## 取消尚未发布的扫描，断开原生索引服务的三个变更信号并释放借用引用。
## [br]
## @api private
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


## 等原生索引扫描结束后按项目数和耗时预算分帧遍历目录，逐项加入未发布快照；遍历完整或失败时统一结束。
## 遍历游标保留到下一帧，绝不将容量或构建失败的部分目录作为完整结果发布。
## [br]
## @api private
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

## 按当前插件资源开关排除 addons 子树，并拒绝任意点开头路径组件；调用方已从指定根目录取得候选。
## [br]
## @api private
func _allows_path(path: String) -> bool:
	if not _include_addons and (path == "res://addons" or path.begins_with("res://addons/")):
		return false
	for component: String in path.trim_prefix("res://").split("/"):
		if component.begins_with("."):
			return false
	return true


## 消费候选累积器，只有 complete 且结果确为目录时发布；先释放遍历状态并停止处理，再同步通知宿主，允许通知期间启动下一轮。
## [br]
## @api private
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

## 原生索引变化后立即取消当前构建并清空目录引用，再通知宿主将既有展示标为过期。
## [br]
## @api private
func _on_filesystem_changed() -> void:
	cancel()
	invalidated.emit()


## 将重导入和重载通知视为整份索引失效，不尝试按通知路径局部修补正在构建的快照。
## [br]
## @api private
func _on_resources_changed(_paths: PackedStringArray) -> void:
	_on_filesystem_changed()
