@tool

## GFEditorCommandSession: 编辑器命令会话。
##
## 为编辑器工具、Dock 或快捷键入口提供统一的命令预览、提交、撤销和结果字典格式。
## 会话只管理通用命令生命周期，不绑定具体资源、节点类型或项目业务。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 6.0.0
## [br]
## @layer kernel/editor
class_name GFEditorCommandSession
extends RefCounted


# --- 常量 ---

## 编辑器命令基类脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorCommandBase = preload("res://addons/gf/kernel/editor/gf_editor_command.gd")

## 编辑器工具上下文脚本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const GFEditorToolContextBase = preload("res://addons/gf/kernel/editor/gf_editor_tool_context.gd")


# --- 公共变量 ---

## 会话稳定标识。
## [br]
## @api public
## [br]
## @since 6.0.0
var session_id: StringName = &""

## 会话显示名称。
## [br]
## @api public
## [br]
## @since 6.0.0
var label: String = ""

## 调用方附加元数据。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @schema metadata: Dictionary for caller-defined editor command session metadata.
var metadata: Dictionary = {}


# --- 私有变量 ---

var _history: Array[GFEditorCommandBase] = []


# --- 公共方法 ---

## 配置会话。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param p_session_id: 会话稳定标识。
## [br]
## @param p_label: 会话显示名称。
## [br]
## @param p_metadata: 调用方元数据。
## [br]
## @schema p_metadata: Dictionary copied into metadata.
## [br]
## @return 当前会话。
func configure(
	p_session_id: StringName,
	p_label: String = "",
	p_metadata: Dictionary = {}
) -> GFEditorCommandSession:
	session_id = p_session_id
	label = p_label
	metadata = p_metadata.duplicate(true)
	return self


## 预览命令可执行性，不修改项目状态。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param command: 待预览命令。
## [br]
## @param context: 调用方上下文字典，会复制到结果中便于诊断。
## [br]
## @schema context: Dictionary command preview context.
## [br]
## @return 预览结果字典。
## [br]
## @schema return: Dictionary with ok, status, command_name, executed, history_count, context, and metadata.
func preview_command(command: GFEditorCommandBase, context: Dictionary = {}) -> Dictionary:
	if command == null:
		return _make_command_result(false, &"missing_command", null, ERR_INVALID_PARAMETER, context)
	if not command.can_execute():
		return _make_command_result(false, &"unavailable", command, ERR_UNAVAILABLE, context)
	return _make_command_result(true, &"ready", command, OK, context)


## 提交命令。存在上下文时可接入 UndoRedo，否则直接执行。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param command: 待提交命令。
## [br]
## @param context: 可选编辑器工具上下文。
## [br]
## @param use_undo: 为 true 且 context 拥有 undo_manager 时写入 UndoRedo。
## [br]
## @return 提交结果字典。
## [br]
## @schema return: Dictionary with ok, status, error, command_name, executed, history_count, and metadata.
func commit_command(
	command: GFEditorCommandBase,
	context: GFEditorToolContextBase = null,
	use_undo: bool = true
) -> Dictionary:
	if command == null:
		return _make_command_result(false, &"missing_command", null, ERR_INVALID_PARAMETER)
	var error: Error = OK
	var managed_by_undo: bool = context != null and use_undo and context.undo_manager != null
	if context != null:
		error = context.commit_command(command, use_undo)
	else:
		error = command.execute()
	if error != OK:
		return _make_command_result(false, &"commit_failed", command, error)
	if managed_by_undo:
		return _make_command_result(true, &"committed_to_undo_manager", command, OK)
	_history.append(command)
	return _make_command_result(true, &"committed", command, OK)


## 撤销最近一次提交的命令。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 撤销结果字典。
## [br]
## @schema return: Dictionary with ok, status, error, command_name, executed, history_count, and metadata.
func revert_last() -> Dictionary:
	if _history.is_empty():
		return _make_command_result(false, &"empty_history", null, ERR_UNAVAILABLE)
	var command: GFEditorCommandBase = _history[_history.size() - 1]
	var error: Error = command.revert()
	if error != OK:
		return _make_command_result(false, &"revert_failed", command, error)
	_history.remove_at(_history.size() - 1)
	return _make_command_result(true, &"reverted", command, OK)


## 清空会话历史，不调用撤销。
## [br]
## @api public
## [br]
## @since 6.0.0
func clear_history() -> void:
	_history.clear()


## 获取命令历史数量。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 已提交命令数量。
func get_history_count() -> int:
	return _history.size()


## 获取调试快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary containing session_id, label, history_count, command_names, and metadata.
func get_debug_snapshot() -> Dictionary:
	var command_names: PackedStringArray = PackedStringArray()
	for command: GFEditorCommandBase in _history:
		if command == null:
			continue
		var _append_command_name: bool = command_names.append(command.command_name)
	return {
		"session_id": String(session_id),
		"label": label,
		"history_count": _history.size(),
		"command_names": command_names,
		"metadata": metadata.duplicate(true),
	}


# --- 私有/辅助方法 ---

func _make_command_result(
	ok: bool,
	status: StringName,
	command: GFEditorCommandBase,
	error: Error,
	context: Dictionary = {}
) -> Dictionary:
	return {
		"ok": ok,
		"status": status,
		"error": error,
		"command_name": command.command_name if command != null else "",
		"executed": command.is_executed() if command != null else false,
		"history_count": _history.size(),
		"context": context.duplicate(true),
		"metadata": metadata.duplicate(true),
	}
