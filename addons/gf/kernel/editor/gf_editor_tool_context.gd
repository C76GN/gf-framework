@tool

## GFEditorToolContext: 编辑器交互工具上下文。
##
## 用于在工具、动作和命令之间传递 EditorPlugin、UndoRedo、选中节点和额外元数据。
## 该对象只保存通用编辑器上下文，不假设具体工具会编辑哪类资源。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
## [br]
## @layer kernel/editor
class_name GFEditorToolContext
extends RefCounted


# --- 常量 ---

## 编辑器命令基类脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorCommandBase = preload("res://addons/gf/kernel/editor/gf_editor_command.gd")


# --- 公共变量 ---

## 当前 EditorPlugin。
## [br]
## @api public
var plugin: EditorPlugin = null

## UndoRedo 管理器或兼容对象。
## [br]
## @api public
var undo_manager: Object = null

## 当前编辑场景根节点。
## [br]
## @api public
var edited_scene_root: Node = null

## 当前选中节点快照。
## [br]
## @api public
var selected_nodes: Array[Node] = []

## 调用方附加元数据。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary for caller-defined editor tool context metadata.
var metadata: Dictionary = {}


# --- 私有变量 ---

## 当前工作区宿主弱引用，撤销后所有路由立即失效。
## [br]
## @api private
var _workspace_host: WeakRef = null


# --- 公共方法 ---

## 从 EditorPlugin 构建上下文。
## [br]
## @api public
## [br]
## @param editor_plugin: 当前编辑器插件。
## [br]
## @param extra_metadata: 额外元数据。
## [br]
## @schema extra_metadata: Dictionary copied into metadata.
## [br]
## @return 新上下文。
static func from_plugin(editor_plugin: EditorPlugin, extra_metadata: Dictionary = {}) -> GFEditorToolContext:
	var context: GFEditorToolContext = GFEditorToolContext.new()
	context.plugin = editor_plugin
	context.metadata = extra_metadata.duplicate(true)
	if editor_plugin != null:
		context.undo_manager = editor_plugin.get_undo_redo()
		context.edited_scene_root = EditorInterface.get_edited_scene_root()
		var selection: EditorSelection = EditorInterface.get_selection()
		if selection != null:
			for node: Node in selection.get_selected_nodes():
				context.selected_nodes.append(node)
	return context


## 提交一个命令。
## [br]
## @api public
## [br]
## @param command: 需要执行或写入 UndoRedo 的命令。
## [br]
## @param use_undo: 为 true 且存在 undo_manager 时写入 UndoRedo。
## [br]
## @return Godot 错误码。
func commit_command(command: GFEditorCommandBase, use_undo: bool = true) -> Error:
	if command == null:
		return ERR_INVALID_PARAMETER
	if use_undo and undo_manager != null:
		return command.add_to_undo_manager(undo_manager)
	return command.execute()


## 获取选中节点副本。
## [br]
## @api public
## [br]
## @return 选中节点数组。
func get_selected_nodes() -> Array[Node]:
	return selected_nodes.duplicate()


## 获取当前任务入口的纯数据快照；不会创建工具页面。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 任务记录副本。
## [br]
## @schema return: Array of Dictionary with source_id, title, description, group, keywords, available, and reason.
func get_workspace_tasks() -> Array[Dictionary]:
	return _record_array(_call_workspace("get_workspace_tasks", []))


## 请求打开一项任务；不可用的扩展入口转到扩展选择页面。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param source_id: 任务的稳定来源标识。
## [br]
## @return 路由结果。
## [br]
## @schema return: Dictionary containing ok and message, with optional error_code and status.
func request_workspace_task(source_id: String) -> Dictionary:
	return _route_report(_call_workspace("request_workspace_task", [source_id]))


## 查询当前资源选择可交给哪些工具；不会加载资源或创建页面。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param paths: 当前资源路径快照。
## [br]
## @return 资源动作记录副本。
## [br]
## @schema return: Array of Dictionary with action_id, title, available, and reason.
func get_resource_actions(paths: PackedStringArray) -> Array[Dictionary]:
	return _record_array(_call_workspace("get_resource_actions", [paths.duplicate()]))


## 将资源交给声明的接收工具；实际修改仍由接收工具显式提交。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param action_id: 查询返回的稳定动作标识。
## [br]
## @param paths: 当前资源路径快照。
## [br]
## @return 路由结果。
## [br]
## @schema return: Dictionary containing ok and message, with optional error_code and status.
func request_resource_action(action_id: String, paths: PackedStringArray) -> Dictionary:
	return _route_report(_call_workspace("request_resource_action", [action_id, paths.duplicate()]))


## 获取上下文字典。
## [br]
## @api public
## [br]
## @return 普通字典快照。
## [br]
## @schema return: Dictionary containing plugin, undo_manager, edited_scene_root, selected_nodes, and metadata.
func to_dictionary() -> Dictionary:
	return {
		"plugin": plugin,
		"undo_manager": undo_manager,
		"edited_scene_root": edited_scene_root,
		"selected_nodes": selected_nodes.duplicate(),
		"metadata": metadata.duplicate(true),
	}


# --- 框架内部方法 ---

## 绑定或撤销工作区宿主。普通工具通过明确的请求方法使用宿主。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param host: 本代工作区宿主，仅保留弱引用；null 撤销后续路由。
func bind_workspace_host(host: Object) -> void:
	_workspace_host = weakref(host) if host != null else null


# --- 私有/辅助方法 ---

## 仅向仍有效的宿主转发固定接口调用。
## [br]
## @api private
func _call_workspace(method: StringName, arguments: Array) -> Variant:
	var host_value: Variant = _workspace_host.get_ref() if _workspace_host != null else null
	if not host_value is Object or not is_instance_valid(host_value):
		return null
	var host: Object = host_value
	if not host.has_method(method):
		return null
	return host.callv(method, arguments)


## 复制宿主返回的记录，隔离页面对注册状态的修改。
## [br]
## @api private
func _record_array(value: Variant) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	if value is Array:
		var values: Array = value
		for item: Variant in values:
			if item is Dictionary:
				var record: Dictionary = item
				records.append(record.duplicate(true))
	return records


## 将失效或非法响应转换为明确的不可用结果。
## [br]
## @api private
func _route_report(value: Variant) -> Dictionary:
	if value is Dictionary:
		var report: Dictionary = value
		return report.duplicate(true)
	return {"ok": false, "message": "工作区上下文已撤销或尚未连接。", "error_code": ERR_UNAVAILABLE}
