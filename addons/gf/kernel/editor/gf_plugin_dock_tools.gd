@tool

# GF 插件编辑器工作区窗口管理辅助。
extends RefCounted


# --- 常量 ---

## 扩展管理页面脚本路径。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const EXTENSION_MANAGER_DOCK_SCRIPT_PATH: String = "res://addons/gf/kernel/editor/extension/gf_extension_manager_dock.gd"

## 工作区窗口脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorWorkspaceWindowBase = preload("res://addons/gf/kernel/editor/gf_editor_workspace_window.gd")

## 扩展启用设置脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFExtensionSettingsBase = preload("res://addons/gf/kernel/extension/gf_extension_settings.gd")

## 读取并规范化 Dock 贡献记录字段的类型化工具。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 工作区个人偏好存取。
## [br]
## @api private
const _PREFERENCES_SCRIPT = preload("res://addons/gf/kernel/editor/state/gf_editor_preferences.gd")

## 工作区任务与资源动作宿主。
## [br]
## @api private
const _TASK_HOST_SCRIPT = preload("res://addons/gf/kernel/editor/workspace/gf_workspace_task_host.gd")


# --- 私有变量 ---

## 由组合入口提供的标准 Dock 记录副本。
## [br]
## @api private
var _standard_dock_records: Array[Dictionary] = []

## 合并、去重和排序后传给工作区窗口的全部 Dock 记录。
## [br]
## @api private
var _dock_records: Array[Dictionary] = []

## EditorInterface 提供的窗口父级控件。
## [br]
## @api private
var _editor_base_control: Control = null

## 按需创建的独立 GF Workspace Window。
## [br]
## @api private
var _workspace_window: GFEditorWorkspaceWindowBase = null

## setup 为工作区页面生成并注入的编辑器上下文。
## [br]
## @api private
var _editor_context: GFEditorToolContext = null

## 本次插件加载是否已处理启动策略，刷新贡献不会重新弹窗。
## [br]
## @api private
var _startup_handled: bool = false

## 当前贡献代次的任务宿主。
## [br]
## @api private
var _task_host: _TASK_HOST_SCRIPT = _TASK_HOST_SCRIPT.new()


# --- 公共方法 ---

## 安装 GF 编辑器工作区窗口入口。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param plugin: 当前 EditorPlugin 实例。
## [br]
## @param standard_dock_records: 组合入口传入的标准库页面记录。
## [br]
## @schema standard_dock_records: Array of Dictionary dock page records.
func setup(
	plugin: EditorPlugin, standard_dock_records: Array[Dictionary] = [],
	task_records: Array[Dictionary] = [], resource_action_records: Array[Dictionary] = []
) -> void:
	if plugin == null:
		return

	_editor_base_control = EditorInterface.get_base_control()
	if _editor_context != null:
		_editor_context.bind_workspace_host(null)
	_editor_context = GFEditorToolContext.from_plugin(plugin)
	set_standard_dock_records(standard_dock_records)
	_dock_records = _collect_dock_records()
	var tasks: Array[Dictionary] = _copy_records(task_records)
	var actions: Array[Dictionary] = _copy_records(resource_action_records)
	var extension_records: Dictionary = _TASK_HOST_SCRIPT.collect_extension_records(GFExtensionSettingsBase.get_all_manifests())
	for record: Dictionary in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(extension_records, "task_records"):
		tasks.append(record)
	for record: Dictionary in _GF_VARIANT_ACCESS_SCRIPT.get_option_array(extension_records, "resource_action_records"):
		actions.append(record)
	_append_page_tasks(tasks)
	_task_host.configure(tasks, actions, _dock_records, self)
	_editor_context.bind_workspace_host(_task_host)
	if is_instance_valid(_workspace_window):
		_workspace_window.setup(_dock_records, _editor_context)
	if not _startup_handled:
		_startup_handled = true
		var mode_value: Variant = _PREFERENCES_SCRIPT.get_value("startup_mode", "first_use")
		var opened_value: Variant = _PREFERENCES_SCRIPT.get_value("has_opened", false)
		var has_opened: bool = opened_value == true
		if Engine.is_editor_hint() and _PREFERENCES_SCRIPT.should_auto_open(
			str(mode_value), has_opened
		):
			show_workspace()


## 移除 GF 编辑器工作区窗口入口。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param _plugin: 当前 EditorPlugin 实例。
func cleanup(_plugin: EditorPlugin) -> void:
	_task_host.clear()
	if _editor_context != null:
		_editor_context.bind_workspace_host(null)
	if is_instance_valid(_workspace_window):
		_workspace_window.set_editor_context(null)
		_workspace_window.queue_free()
	_workspace_window = null
	_editor_base_control = null
	_editor_context = null
	_dock_records.clear()


## 设置由组合入口收集到的标准库页面记录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param standard_dock_records: 标准库页面记录。
## [br]
## @schema standard_dock_records: Array of Dictionary dock page records.
func set_standard_dock_records(standard_dock_records: Array[Dictionary]) -> void:
	_standard_dock_records = _copy_records(standard_dock_records)


## 显示 GF 编辑器工作区。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func show_workspace() -> void:
	if _ensure_workspace_window() and _workspace_window.has_method("popup_workspace"):
		_workspace_window.call("popup_workspace")
		_PREFERENCES_SCRIPT.set_value("has_opened", true)


## 获取当前工作区窗口。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 工作区窗口；未安装时返回 null。
func get_workspace_window() -> Window:
	return _workspace_window


## 按已登记路径打开页面；工具间的交接只经过此宿主入口。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func open_workspace_page(page_path: String) -> Control:
	for record: Dictionary in _dock_records:
		if str(record.get("path", "")) != page_path:
			continue
		show_workspace()
		if not is_instance_valid(_workspace_window):
			return null
		var workspace: Control = _workspace_window.get_workspace()
		var page_id: String = str(record.get("source_id", page_path))
		var value: Variant = workspace.call("open_page", page_id)
		if value is Control:
			var page: Control = value
			return page
	return null


# --- 私有/辅助方法 ---

## 深复制标准记录并追加内置 GF Extensions 管理页。
## [br]
## @api private
func _collect_core_dock_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = _copy_records(_standard_dock_records)
	records.append({
		"source_id": "gf.kernel.home",
		"path": "res://addons/gf/kernel/editor/workspace/gf_workspace_home.gd",
		"label": "GF Home", "short_label": "首页", "order": -100,
	})
	records.append(
		{
			"source_id": "gf.kernel.extensions",
			"path": EXTENSION_MANAGER_DOCK_SCRIPT_PATH,
			"label": "GF Extensions",
			"short_label": "扩展",
			"order": 80,
		}
	)
	return records


## 没有专用任务声明的旧页面继续提供通用打开入口。
## [br]
## @api private
func _append_page_tasks(tasks: Array[Dictionary]) -> void:
	var described_paths: Dictionary = {}
	for task: Dictionary in tasks:
		described_paths[str(task.get("page_path", ""))] = true
	for page: Dictionary in _dock_records:
		var path: String = str(page.get("path", ""))
		var source_id: String = str(page.get("source_id", path))
		if described_paths.has(path) or source_id == "gf.kernel.home":
			continue
		tasks.append({
			"source_id": "%s:open" % source_id,
			"title": str(page.get("label", "")), "group": "工具页面",
			"description": "打开此页面，查看状态或执行对应工具操作。",
			"keywords": [], "page_path": path, "action_id": "",
		})


## 合并核心页与启用扩展页，按规范化路径去重并按稳定比较器排序。
## [br]
## @api private
func _collect_dock_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = _collect_core_dock_records()
	records.append_array(_collect_enabled_extension_dock_records())
	records = _deduplicate_dock_records(records)
	records.sort_custom(_sort_dock_records)
	return records


## 深复制 Dock 字典数组中的每条记录。
## [br]
## @api private
func _copy_records(source: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record: Dictionary in source:
		records.append(record.duplicate(true))
	return records


## 去除空路径和重复路径，首次出现的记录保留，并将其 path 写为去空白形式。
## [br]
## @api private
func _deduplicate_dock_records(source: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var used_paths: Dictionary = {}
	for record: Dictionary in source:
		var path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "path", "").strip_edges()
		if path.is_empty() or used_paths.has(path):
			continue
		used_paths[path] = true
		var copied_record: Dictionary = record.duplicate(true)
		copied_record["path"] = path
		records.append(copied_record)
	return records


## 从启用扩展贡献读取 Dock 路径，按路径去重并生成 label、short_label 与 order 记录。
## 同一扩展贡献多个 Dock 时，显示标签会从脚本文件名派生区分后缀。
## [br]
## @api private
func _collect_enabled_extension_dock_records() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var used_paths: Dictionary = {}
	var contribution_records: Array[Dictionary] = (
		GFExtensionSettingsBase.get_enabled_editor_contribution_records("editor_dock_paths")
	)
	var dock_counts_by_extension: Dictionary = {}
	for contribution_record: Dictionary in contribution_records:
		var extension_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			contribution_record,
			"extension_id"
		)
		if extension_id.is_empty():
			continue
		dock_counts_by_extension[extension_id] = (
			_GF_VARIANT_ACCESS_SCRIPT.get_option_int(dock_counts_by_extension, extension_id) + 1
		)
	for contribution_record: Dictionary in contribution_records:
		var normalized_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			contribution_record,
			"path"
		).strip_edges()
		if normalized_path.is_empty() or used_paths.has(normalized_path):
			continue
		var extension_id: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			contribution_record,
			"extension_id"
		)
		used_paths[normalized_path] = true
		records.append({
			"source_id": "%s:%s" % [extension_id, normalized_path],
			"path": normalized_path,
			"label": _get_extension_dock_label(
				contribution_record,
				normalized_path,
				_GF_VARIANT_ACCESS_SCRIPT.get_option_int(
					dock_counts_by_extension,
					extension_id
				)
			),
			"short_label": _get_extension_short_label(contribution_record),
			"order": _GF_VARIANT_ACCESS_SCRIPT.get_option_int(
				contribution_record,
				"editor_dock_order",
				1000
			),
		})
	return records


## 已有有效窗口时复用；否则必要时重收集页面记录并创建窗口。
## [br]
## @api private
func _ensure_workspace_window() -> bool:
	if is_instance_valid(_workspace_window):
		return true
	if _dock_records.is_empty():
		_dock_records = _collect_dock_records()
	return _add_workspace_window(_dock_records)


## 父级控件有效时创建窗口、先注入页面与上下文，再加入编辑器控件树。
## 父级无效时不创建并返回 false。
## [br]
## @api private
func _add_workspace_window(records: Array[Dictionary]) -> bool:
	if not is_instance_valid(_editor_base_control):
		return false

	_workspace_window = GFEditorWorkspaceWindowBase.new()
	_workspace_window.setup(records, _editor_context)
	_editor_base_control.add_child(_workspace_window)
	return true


## 优先用扩展 display_name，否则用 extension_id；多 Dock 时追加由路径文件名整理出的后缀。
## [br]
## @api private
func _get_extension_dock_label(
	contribution_record: Dictionary,
	dock_path: String,
	dock_count: int
) -> String:
	var extension_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		contribution_record,
		"display_name"
	)
	if extension_name.is_empty():
		extension_name = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			contribution_record,
			"extension_id"
		)
	if dock_count <= 1:
		return extension_name

	var script_label: String = dock_path.get_file().get_basename()
	if script_label.begins_with("gf_"):
		script_label = script_label.substr(3)
	if script_label.ends_with("_dock"):
		script_label = script_label.substr(0, script_label.length() - 5)
	if script_label.is_empty():
		return extension_name
	script_label = script_label.to_pascal_case()
	if extension_name.ends_with(script_label):
		return extension_name
	return "%s %s" % [extension_name, script_label]


## 优先返回 editor_dock_short_label，否则取扩展显示名或 ID 并移除 `GF ` 前缀。
## [br]
## @api private
func _get_extension_short_label(contribution_record: Dictionary) -> String:
	var short_label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		contribution_record,
		"editor_dock_short_label"
	)
	if not short_label.is_empty():
		return short_label

	var extension_name: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
		contribution_record,
		"display_name"
	)
	if extension_name.is_empty():
		extension_name = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(
			contribution_record,
			"extension_id"
		)
	if extension_name.begins_with("GF "):
		extension_name = extension_name.substr(3)
	return extension_name


## 先按 order，再按 label，最后按 path 进行升序比较。
## [br]
## @api private
func _sort_dock_records(left: Dictionary, right: Dictionary) -> bool:
	var left_order: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(left, "order", 1000)
	var right_order: int = _GF_VARIANT_ACCESS_SCRIPT.get_option_int(right, "order", 1000)
	if left_order != right_order:
		return left_order < right_order

	var left_label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(left, "label", "")
	var right_label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(right, "label", "")
	if left_label != right_label:
		return left_label < right_label
	return (
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(left, "path", "")
		< _GF_VARIANT_ACCESS_SCRIPT.get_option_string(right, "path", "")
	)
