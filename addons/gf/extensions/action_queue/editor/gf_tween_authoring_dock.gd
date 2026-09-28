@tool

# Tween 工作区入口；资源创作与预览仍在原生 Inspector 完成。
extends VBoxContainer


# --- 常量 ---

const _ACTIONS_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/gf_tween_editor_actions.gd")
const _WORKSPACE_UI_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")


# --- 私有变量 ---

var _actions: _ACTIONS_SCRIPT = null
var _picker: EditorResourcePicker = null
var _status: Label = null


# --- Godot 生命周期方法 ---

func _ready() -> void:
	_WORKSPACE_UI_SCRIPT.apply_page_root(self)
	_actions = _ACTIONS_SCRIPT.new()
	var create_button: Button = _WORKSPACE_UI_SCRIPT.make_button("创建 Tween 配置…", "选择项目内保存位置，然后在 Inspector 编辑步骤。", _on_create_pressed)
	add_child(create_button)
	_picker = EditorResourcePicker.new()
	_picker.base_type = "GFTweenActionConfig"
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_picker)
	var _selected_connected: int = _picker.resource_selected.connect(_on_resource_selected)
	var open_button: Button = _WORKSPACE_UI_SCRIPT.make_button("在 Inspector 打开", "", _on_open_pressed)
	add_child(open_button)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "创建或选择 Tween 配置 → 在 Inspector 调整步骤与样机 → 保存资源 → 复制绑定示例。\n预设只管理步骤；循环、往返和时间策略使用资源原生字段。"
	add_child(_status)


func _exit_tree() -> void:
	if _actions != null:
		_actions.cleanup()
	_actions = null


# --- 框架内部方法 ---

## 工作区任务的固定入口；仅打开创建对话框，不自动写文件。
## [br]
## @api framework_internal
## [br]
## @param action_id: 仅接受 new_resource。
## [br]
## @return: 对话框是否已经打开。
## [br]
## @schema return: Dictionary，ok: bool、status: String（dialog_opened 或 unavailable）。
func run_workspace_task(action_id: String) -> Dictionary:
	if action_id != "new_resource" or _actions == null:
		return {"ok": false, "status": "unavailable"}
	_actions.handle_menu_action(&"create_tween_config")
	return {"ok": true, "status": "dialog_opened"}


# --- 信号处理函数 ---

func _on_create_pressed() -> void:
	var _result: Dictionary = run_workspace_task("new_resource")


func _on_open_pressed() -> void:
	if _picker.edited_resource != null:
		EditorInterface.edit_resource(_picker.edited_resource)
	else:
		_status.text = "先选择已保存的 Tween 配置，或创建新配置。"


func _on_resource_selected(resource: Resource, _inspect: bool) -> void:
	if resource != null:
		EditorInterface.edit_resource(resource)
