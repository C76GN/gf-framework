@tool

# Tween 工作区入口；资源创作与预览仍在原生 Inspector 完成。
extends VBoxContainer


# --- 常量 ---

## 为本页创建独立资源创建动作实例；离树时由本页清理其对话框。
## [br]
## @api private
const _ACTIONS_SCRIPT = preload("res://addons/gf/extensions/action_queue/editor/gf_tween_editor_actions.gd")

## 复用工作区页面边距和按钮构造约定，保持入口控件与其他页面一致。
## [br]
## @api private
const _WORKSPACE_UI_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")


# --- 私有变量 ---

## 本页持有的创建动作；退出场景树时先清理编辑器宿主中的对话框，再释放引用。
## [br]
## @api private
var _actions: _ACTIONS_SCRIPT = null

## 由本页子树持有的配置选择器，仅限制候选资源类型，不复制选中资源。
## [br]
## @api private
var _picker: EditorResourcePicker = null

## 显示创作流程提示和未选择资源的反馈；随本页子树释放。
## [br]
## @api private
var _status: Label = null


# --- Godot 生命周期方法 ---

## 创建本页持有的动作实例和资源选择控件；页面入口只导航，不主动写资源。
## [br]
## @api private
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


## 先清理挂在编辑器宿主下的对话框，再释放本页动作实例，避免页面卸载后残留入口。
## [br]
## @api private
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
## @schema return: Dictionary，ok: bool、status: String（dialog_opened 或 unavailable）、message: String（可读说明）。
func run_workspace_task(action_id: String) -> Dictionary:
	if action_id != "new_resource" or _actions == null:
		return {"ok": false, "status": "unavailable", "message": "Tween 创建入口当前不可用；请重新打开工作区后重试。"}
	_actions.handle_menu_action(&"create_tween_config")
	return {"ok": true, "status": "dialog_opened", "message": "已打开 Tween 配置创建窗口；确认保存位置后创建。"}


# --- 信号处理函数 ---

## 复用工作区任务入口打开创建对话框，文件写入仍由对话框确认触发。
## [br]
## @api private
func _on_create_pressed() -> void:
	var _result: Dictionary = run_workspace_task("new_resource")


## 在原生 Inspector 打开当前选择的共享资源；未选择时只更新页面提示。
## [br]
## @api private
func _on_open_pressed() -> void:
	if _picker.edited_resource != null:
		EditorInterface.edit_resource(_picker.edited_resource)
	else:
		_status.text = "先选择已保存的 Tween 配置，或创建新配置。"


## 将非空选择交给原生 Inspector，不因选择器的 inspect 标志改变资源打开行为。
## [br]
## @api private
func _on_resource_selected(resource: Resource, _inspect: bool) -> void:
	if resource != null:
		EditorInterface.edit_resource(resource)
