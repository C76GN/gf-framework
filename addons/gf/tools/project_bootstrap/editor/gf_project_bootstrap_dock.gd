@tool

# 最小项目创建页。页面卸载会退休 UI 写回资格；同步提交本身必须走完保存或补偿。
extends VBoxContainer


# --- 常量 ---

const _GENERATOR_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/gf_project_bootstrap_generator.gd")
const _WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")


# --- 私有变量 ---

var _directory: LineEdit = null
var _prefix: LineEdit = null
var _main_scene: CheckBox = null
var _preview: Button = null
var _create: Button = null
var _open_scene: Button = null
var _details: RichTextLabel = null
var _plan: Dictionary = {}
var _last_report: Dictionary = {}
var _generation: int = 0
var _busy: bool = false
var _context: GFEditorToolContext = null


# --- Godot 回调方法 ---

func _ready() -> void:
	_WORKSPACE_UI.apply_page_root(self)
	add_child(_WORKSPACE_UI.make_summary_label("创建可运行的 kernel 示例：Model、System、Installer、启动场景和计数按钮。先预览，再创建。"))
	add_child(_WORKSPACE_UI.make_summary_label("输出目录"))
	_directory = LineEdit.new()
	_directory.name = "OutputDirectory"
	_directory.text = "res://game/bootstrap"
	add_child(_directory)
	var _directory_connected: int = _directory.text_changed.connect(_on_input_changed)
	add_child(_WORKSPACE_UI.make_summary_label("类名前缀"))
	_prefix = LineEdit.new()
	_prefix.name = "ClassPrefix"
	_prefix.text = "GameDemo"
	add_child(_prefix)
	var _prefix_connected: int = _prefix.text_changed.connect(_on_input_changed)
	_main_scene = CheckBox.new()
	_main_scene.name = "SetMainScene"
	_main_scene.text = "创建后将样例设为项目主场景（替换当前设置）"
	add_child(_main_scene)
	var _main_connected: int = _main_scene.toggled.connect(_on_main_scene_toggled)
	var toolbar: HBoxContainer = _WORKSPACE_UI.make_toolbar()
	add_child(toolbar)
	_preview = _WORKSPACE_UI.make_button("预览创建计划", "只检查文件和设置，不写入项目。", _on_preview_pressed)
	toolbar.add_child(_preview)
	_create = _WORKSPACE_UI.make_button("创建最小项目", "新建文件并追加 Installer，保存项目设置。", _on_create_pressed)
	_create.disabled = true
	toolbar.add_child(_create)
	_open_scene = _WORKSPACE_UI.make_button("打开样例场景", "打开后按 F6 运行当前场景。", _on_open_scene_pressed)
	_open_scene.disabled = true
	toolbar.add_child(_open_scene)
	_details = RichTextLabel.new()
	_details.name = "CreationDetails"
	_details.bbcode_enabled = false
	_details.selection_enabled = true
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.custom_minimum_size.y = 180.0
	add_child(_details)
	_details.text = "默认保留已有文件、Installer 和主场景。生成的项目文件可自由编辑，工具不会覆盖。"
	_set_busy(false)


func _exit_tree() -> void:
	set_editor_context(null)


# --- 框架内部方法 ---

## 注入宿主上下文；撤销或替换时立即使旧计划和旧调用栈的 UI 写回资格失效。
## 已经进入同步提交的文件事务继续完成保存或补偿，不因页面退休而中断。
## [br]
## @api framework_internal
## [br]
## @param context: 存活的宿主上下文；null 表示页面被卸载。
func set_editor_context(context: GFEditorToolContext) -> void:
	_generation += 1
	_context = context
	_plan.clear()
	if is_instance_valid(_create):
		_set_busy(_busy)
		_open_scene.disabled = not _is_context_active() or _last_report.get("ok") != true

## 工作区任务只打开并聚焦向导；创建始终由明确的预览和按钮操作发起。
## [br]
## @api framework_internal
## [br]
## @param action_id: 空字符串或 new_project。
## [br]
## @return 任务入口结果。
## [br]
## @schema return: Dictionary，包含 ok:bool 和 status:String。
func run_workspace_task(action_id: String) -> Dictionary:
	if action_id not in ["", "new_project"]:
		return {"ok": false, "status": "unknown_action"}
	if not _is_context_active():
		return {"ok": false, "status": "not_ready"}
	_directory.grab_focus()
	return {"ok": true, "status": "wizard_opened"}


# --- 私有/辅助方法 ---

func _is_context_active() -> bool:
	return (
		Engine.is_editor_hint() and is_node_ready() and is_inside_tree()
		and not is_queued_for_deletion() and _context != null
		and is_instance_valid(_context.plugin) and _context.plugin.is_inside_tree()
		and not _context.plugin.is_queued_for_deletion()
	)


func _invalidate_preview() -> void:
	if _last_report.get("recovery_required") == true:
		return
	_plan.clear()
	_create.disabled = true
	_details.text = "输入已变化，请重新预览创建计划。"


func _set_busy(active: bool) -> void:
	_busy = active
	var unavailable: bool = active or not _is_context_active() or _last_report.get("recovery_required") == true
	_directory.editable = not unavailable
	_prefix.editable = not unavailable
	_main_scene.disabled = unavailable
	_preview.disabled = unavailable
	_create.disabled = unavailable or _plan.get("ok") != true


func _show_plan(plan: Dictionary) -> void:
	var lines: PackedStringArray = PackedStringArray()
	var _title_added: bool = lines.append("创建计划" if plan.get("ok") == true else "暂不能创建")
	for issue: String in plan["issues"]:
		var _issue_added: bool = lines.append("• " + issue)
	for path: String in plan["paths"]:
		var _path_added: bool = lines.append("新建：" + path)
	var installer_path: String = plan["installer_path"]
	var _installer_added: bool = lines.append("追加 Installer：" + installer_path)
	if _main_scene.button_pressed:
		var scene_path: String = plan["scene_path"]
		var _main_added: bool = lines.append("设置主场景：" + scene_path)
	else:
		var _main_preserved: bool = lines.append("保留当前主场景：" + str(ProjectSettings.get_setting("application/run/main_scene", "（未设置）")))
	var _note_added: bool = lines.append("生成文件属于项目。创建同时保存当前项目设置；不提供编辑器撤销。")
	_details.text = "\n".join(lines)


func _show_report(report: Dictionary) -> void:
	var lines: PackedStringArray = PackedStringArray()
	var status: String = report["status"]
	var _status_added: bool = lines.append("创建成功。按 F6 运行样例，再点击“计数 +1”。" if report.get("ok") == true else "创建未完成：" + status)
	for issue: String in report["issues"]:
		var _issue_added: bool = lines.append("• " + issue)
	if report.get("rolled_back") == true:
		var _rollback_added: bool = lines.append("本次文件已回滚；可能保留空目录。项目设置未保存。")
	if report.get("files_created") == true:
		for path: String in report["paths"]:
			var _path_added: bool = lines.append(path)
	if report.get("recovery_required") == true:
		var _recovery_added: bool = lines.append("需要检查并恢复：请保留上述文件和项目设置，不要直接重试创建。")
	_details.text = "\n".join(lines)


# --- 信号处理函数 ---

func _on_input_changed(_text: String) -> void:
	if not _busy and _is_context_active():
		_invalidate_preview()


func _on_main_scene_toggled(_enabled: bool) -> void:
	if not _busy and _is_context_active():
		_invalidate_preview()


func _on_preview_pressed() -> void:
	if _busy or not _is_context_active() or _last_report.get("recovery_required") == true:
		return
	_plan = _GENERATOR_SCRIPT.get_plan(_directory.text, _prefix.text, _main_scene.button_pressed)
	_show_plan(_plan)
	_create.disabled = _plan.get("ok") != true


func _on_create_pressed() -> void:
	if _busy or not _is_context_active() or _plan.get("ok") != true or _last_report.get("recovery_required") == true:
		return
	var generation: int = _generation
	var signature: String = _plan["signature"]
	_set_busy(true)
	var report: Dictionary = _GENERATOR_SCRIPT.create(_directory.text, _prefix.text, _main_scene.button_pressed, signature)
	if not is_instance_valid(self) or generation != _generation or not _is_context_active():
		return
	_last_report = report
	_plan.clear()
	_set_busy(false)
	_show_report(report)
	_open_scene.disabled = report.get("ok") != true
	if report.get("ok") == true:
		EditorInterface.get_resource_filesystem().scan()
		if not is_instance_valid(self) or generation != _generation or not _is_context_active():
			return
		_on_open_scene_pressed()


func _on_open_scene_pressed() -> void:
	if not _busy and _is_context_active() and _last_report.get("ok") == true:
		var path: String = _last_report["scene_path"]
		EditorInterface.open_scene_from_path(path)
