@tool

## GFRuntimeDebuggerPlugin: GF 运行时诊断 EditorDebugger 插件。
##
## 为每个 Godot 调试会话安装 GF Runtime 页，并把运行时 GFDiagnosticsUtility
## 通过 EngineDebugger 返回的消息转发给对应页面。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 6.0.0
class_name GFRuntimeDebuggerPlugin
extends EditorDebuggerPlugin

# --- 私有变量 ---

## 按 EditorDebuggerSession ID 保存对应的运行时诊断页签实例。
## [br]
## @api private
## [br]
var _tabs_by_session_id: Dictionary = {}


# --- Godot 回调方法 ---

## 仅声明接收 GF 诊断的 capture 名称，其他调试协议交给编辑器的其余处理器。
## [br]
## @api private
func _has_capture(capture: String) -> bool:
	return capture == String(GFDiagnosticsUtility.DEBUGGER_CAPTURE_NAME)


## 找到会话页签后按消息类型转交快照、目录或命令结果；页签不存在或消息未知时返回未处理。
## [br]
## @api private
func _capture(message: String, data: Array, session_id: int) -> bool:
	var tab: GFRuntimeDebuggerTab = _get_tab(session_id)
	if tab == null:
		return false

	match message:
		GFDiagnosticsUtility.DEBUGGER_MESSAGE_SNAPSHOT:
			tab.handle_snapshot(_data_dictionary(data, 0))
			return true
		GFDiagnosticsUtility.DEBUGGER_MESSAGE_CATALOG:
			tab.handle_catalog(_data_dictionary(data, 0))
			return true
		GFDiagnosticsUtility.DEBUGGER_MESSAGE_COMMAND_RESULT:
			tab.handle_command_result(_data_string_name(data, 0), _data_dictionary(data, 1))
			return true
		_:
			return false


## 为编辑器调试会话创建并登记页签，交由 EditorDebuggerSession 持有；远端 stopped 不释放该页签，支持跨运行复用。
## [br]
## @api private
func _setup_session(session_id: int) -> void:
	var session: EditorDebuggerSession = get_session(session_id)
	if session == null:
		return

	var tab: GFRuntimeDebuggerTab = GFRuntimeDebuggerTab.new()
	tab.setup_session(session, session_id)
	_tabs_by_session_id[session_id] = tab
	session.add_session_tab(tab)
	# stopped 只表示远端进程断开；页签由 EditorDebuggerSession 持有并跨运行复用。


# --- 公共方法 ---

## 获取插件调试快照。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @return 调试快照。
## [br]
## @schema return: Dictionary with session_ids and tab_count.
func get_debug_snapshot() -> Dictionary:
	var session_ids: PackedStringArray = PackedStringArray()
	for session_id: int in _tabs_by_session_id.keys():
		var _id_appended: bool = session_ids.append(str(session_id))
	session_ids.sort()
	return {
		"session_ids": session_ids,
		"tab_count": _tabs_by_session_id.size(),
	}


# --- 私有/辅助方法 ---

## 读取指定调试会话的页签；缺少记录或值类型不符时返回 null。
## [br]
## @api private
## [br]
func _get_tab(session_id: int) -> GFRuntimeDebuggerTab:
	var value: Variant = GFVariantData.get_option_value(_tabs_by_session_id, session_id, null)
	if value is GFRuntimeDebuggerTab:
		var tab: GFRuntimeDebuggerTab = value
		return tab
	return null


## 读取指定消息数据项；索引越界或值不是字典时返回空字典，字典值返回深复制。
## [br]
## @api private
## [br]
func _data_dictionary(data: Array, index: int) -> Dictionary:
	if index < 0 or index >= data.size():
		return {}
	var value: Variant = data[index]
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


## 读取指定消息数据项并转换为 StringName；索引越界时返回空名称。
## [br]
## @api private
## [br]
func _data_string_name(data: Array, index: int) -> StringName:
	if index < 0 or index >= data.size():
		return &""
	return GFVariantData.to_string_name(data[index])
