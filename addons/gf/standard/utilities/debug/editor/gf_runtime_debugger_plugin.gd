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

var _tabs_by_session_id: Dictionary = {}


# --- Godot 回调方法 ---

func _has_capture(capture: String) -> bool:
	return capture == String(GFDiagnosticsUtility.DEBUGGER_CAPTURE_NAME)


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


func _setup_session(session_id: int) -> void:
	var session: EditorDebuggerSession = get_session(session_id)
	if session == null:
		return

	var tab: GFRuntimeDebuggerTab = GFRuntimeDebuggerTab.new()
	tab.setup_session(session, session_id)
	_tabs_by_session_id[session_id] = tab
	session.add_session_tab(tab)
	if not session.stopped.is_connected(_on_session_stopped.bind(session_id)):
		var _stopped_connected: Error = session.stopped.connect(_on_session_stopped.bind(session_id)) as Error


func _exit_tree() -> void:
	for session_id: int in _tabs_by_session_id.keys():
		_remove_session_tab(session_id)


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

func _get_tab(session_id: int) -> GFRuntimeDebuggerTab:
	var value: Variant = GFVariantData.get_option_value(_tabs_by_session_id, session_id, null)
	if value is GFRuntimeDebuggerTab:
		var tab: GFRuntimeDebuggerTab = value
		return tab
	return null


func _data_dictionary(data: Array, index: int) -> Dictionary:
	if index < 0 or index >= data.size():
		return {}
	var value: Variant = data[index]
	if value is Dictionary:
		var dictionary: Dictionary = value
		return dictionary.duplicate(true)
	return {}


func _data_string_name(data: Array, index: int) -> StringName:
	if index < 0 or index >= data.size():
		return &""
	return GFVariantData.to_string_name(data[index])


func _remove_session_tab(session_id: int) -> void:
	var tab: GFRuntimeDebuggerTab = _get_tab(session_id)
	var _erased: bool = _tabs_by_session_id.erase(session_id)
	if tab != null and is_instance_valid(tab):
		tab.queue_free()


# --- 信号处理函数 ---

func _on_session_stopped(session_id: int) -> void:
	_remove_session_tab(session_id)
