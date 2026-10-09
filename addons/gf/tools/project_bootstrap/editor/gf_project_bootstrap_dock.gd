@tool

# 项目初始化页。页面卸载会退休 UI 写回资格；同步提交本身必须走完保存或补偿。
extends VBoxContainer


# --- 常量 ---

## 只读计划与同步提交共用的协调器；页面不自行创建文件或补偿项目设置。
## [br]
## @api private
const _GENERATOR_SCRIPT = preload("res://addons/gf/tools/project_bootstrap/gf_project_bootstrap_generator.gd")

## 复用工作区布局和按钮构建方式，保持初始化页与其他工具页面一致。
## [br]
## @api private
const _WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")


# --- 私有变量 ---

## 用户选择的产物根目录；文本变化会作废预览，实际写入前仍由生成器重新校验。
## [br]
## @api private
var _directory: LineEdit = null

## 新项目和已有项目接入模式选择器；模式决定是否创建并登记 Boot 主场景。
## [br]
## @api private
var _mode: OptionButton = null

## 说明当前模式对主场景与 Installer 的处理，随模式变化更新。
## [br]
## @api private
var _mode_hint: Label = null

## 控制是否新建并追加项目 Installer；高级选项收起不会清除此选择。
## [br]
## @api private
var _create_installer: CheckBox = null

## 控制是否创建项目初始化说明文件，不影响核心启动逻辑。
## [br]
## @api private
var _include_readme: CheckBox = null

## 只读刷新计划的入口；提交中或报告要求恢复时禁用。
## [br]
## @api private
var _preview: Button = null

## 唯一发起生成器提交的按钮；须有成功且包含实际产物的当前计划。
## [br]
## @api private
var _create: Button = null

## 打开成功生成的 Boot 场景；仅预览出路径还不足以启用此动作。
## [br]
## @api private
var _open_scene: Button = null

## 打开已有项目的主场景或本次成功生成的 Main，路径选择由 _main_path 决定。
## [br]
## @api private
var _open_main: Button = null

## 打开本次成功创建的 Installer 脚本；恢复未完成时不开放结果动作。
## [br]
## @api private
var _open_installer: Button = null

## 复制已有项目接入片段；只提供文本，不自动修改用户启动脚本。
## [br]
## @api private
var _copy_snippet: Button = null

## 显示只读计划、真实提交状态和恢复提醒的纯文本区域，不解析模板或路径中的 BBCode。
## [br]
## @api private
var _details: RichTextLabel = null

## 当前输入对应的只读计划及内容签名；输入或上下文变化后清空，创建时交给生成器复核。
## [br]
## @api private
var _plan: Dictionary = {}

## 最近一次仍有 UI 写回资格的提交报告；要求恢复时保留并阻止新计划覆盖诊断。
## [br]
## @api private
var _last_report: Dictionary = {}

## 预览和同步调用栈的 UI 写回代次；上下文、输入或操作变化会使旧回调失效。
## [br]
## @api private
var _generation: int = 0

## 当前页面同步提交的交互占用标记；页面失效只撤销结果写回，不中断生成器的保存或补偿。
## [br]
## @api private
var _busy: bool = false

## 宿主授予的编辑器上下文；页面和插件都必须仍存活且未排队释放才能执行交互。
## [br]
## @api private
var _context: GFEditorToolContext = null


# --- Godot 回调方法 ---

## 构建初始化向导并安排只读摘要；进入页面不创建产物，提交仍必须由有效计划上的按钮发起。
## [br]
## @api private
func _ready() -> void:
	_WORKSPACE_UI.apply_page_root(self)
	add_child(_WORKSPACE_UI.make_summary_label("建立项目启动入口，或为现有项目准备接入内容。下方摘要只读检查，点击初始化后才写入。"))
	_mode = OptionButton.new()
	_mode.name = "InitializationMode"
	_mode.add_item("初始化新项目")
	_mode.add_item("接入现有项目")
	add_child(_mode)
	var _mode_connected: int = _mode.item_selected.connect(_on_mode_selected)
	_mode_hint = _WORKSPACE_UI.make_summary_label()
	add_child(_mode_hint)
	add_child(_WORKSPACE_UI.make_summary_label("输出目录"))
	_directory = LineEdit.new()
	_directory.name = "OutputDirectory"
	_directory.text = "res://app"
	add_child(_directory)
	var _directory_connected: int = _directory.text_changed.connect(_on_input_changed)
	var advanced: VBoxContainer = VBoxContainer.new()
	advanced.name = "InitializationOptions"
	var advanced_toggle: CheckButton = _WORKSPACE_UI.make_details_toggle(advanced)
	advanced_toggle.text = "高级选项"
	advanced_toggle.tooltip_text = "选择项目装配入口和说明文件；收起后保留选择。"
	add_child(advanced_toggle)
	add_child(advanced)
	_create_installer = CheckBox.new()
	_create_installer.name = "CreateInstaller"
	_create_installer.text = "创建并登记空的项目 Installer"
	_create_installer.button_pressed = true
	advanced.add_child(_create_installer)
	var _installer_connected: int = _create_installer.toggled.connect(_on_option_toggled)
	_include_readme = CheckBox.new()
	_include_readme.name = "IncludeReadme"
	_include_readme.text = "附带项目初始化说明 README.md"
	advanced.add_child(_include_readme)
	var _readme_connected: int = _include_readme.toggled.connect(_on_option_toggled)
	var toolbar: HBoxContainer = _WORKSPACE_UI.make_toolbar()
	add_child(toolbar)
	_preview = _WORKSPACE_UI.make_button("刷新变更摘要", "重新检查文件和项目设置，不写入项目。", _on_preview_pressed)
	_preview.name = "RefreshPlan"
	toolbar.add_child(_preview)
	_create = _WORKSPACE_UI.make_button("初始化项目", "按摘要新建文件，并保存当前项目设置。", _on_create_pressed)
	_create.name = "InitializeProject"
	_create.disabled = true
	toolbar.add_child(_create)
	_copy_snippet = _WORKSPACE_UI.make_button("复制接入片段", "复制当前接入方式的初始化代码，由项目决定放入哪个入口。", _on_copy_snippet_pressed)
	_copy_snippet.name = "CopyIntegrationSnippet"
	toolbar.add_child(_copy_snippet)
	var result_toolbar: HBoxContainer = _WORKSPACE_UI.make_toolbar()
	add_child(result_toolbar)
	_open_scene = _WORKSPACE_UI.make_button("打开 Boot", "打开生成的启动场景；按 F6 验证初始化并进入 Main。", _on_open_scene_pressed)
	_open_scene.name = "OpenBoot"
	result_toolbar.add_child(_open_scene)
	_open_main = _WORKSPACE_UI.make_button("打开 Main", "打开生成的空主场景或现有项目主场景。", _on_open_main_pressed)
	_open_main.name = "OpenMain"
	result_toolbar.add_child(_open_main)
	_open_installer = _WORKSPACE_UI.make_button("打开 Installer", "打开本次创建的空项目装配脚本。", _on_open_installer_pressed)
	_open_installer.name = "OpenInstaller"
	result_toolbar.add_child(_open_installer)
	_details = RichTextLabel.new()
	_details.name = "CreationDetails"
	_details.bbcode_enabled = false
	_details.selection_enabled = true
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.custom_minimum_size.y = 180.0
	add_child(_details)
	_set_busy(false)
	_update_mode_hint()
	_queue_preview()


## 通过撤销宿主上下文推进代次，使排队预览与旧同步调用栈失去 UI 写回资格；不中断已进入的文件事务。
## [br]
## @api private
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
		_queue_preview()


## 工作区任务只打开并聚焦向导；摘要自动只读刷新，创建始终由明确的按钮操作发起。
## [br]
## @api framework_internal
## [br]
## @param action_id: 空字符串或 new_project。
## [br]
## @return 任务入口结果。
## [br]
## @schema return: Dictionary，包含 ok:bool、status:String 和 message:String。
func run_workspace_task(action_id: String) -> Dictionary:
	if action_id not in ["", "new_project"]:
		return {"ok": false, "status": "unknown_action", "message": "无法识别项目初始化任务。"}
	if not _is_context_active():
		return {"ok": false, "status": "not_ready", "message": "项目初始化页面当前不可用。"}
	_directory.grab_focus()
	return {"ok": true, "status": "wizard_opened", "message": "已打开项目初始化；确认变更摘要后再执行。"}


# --- 私有/辅助方法 ---

## 同时检查编辑器环境、页面 ready 状态与宿主插件存活；未准备好或排队释放的页面不拥有交互资格。
## [br]
## @api private
func _is_context_active() -> bool:
	return (
		Engine.is_editor_hint() and is_node_ready() and is_inside_tree()
		and not is_queued_for_deletion() and _context != null
		and is_instance_valid(_context.plugin) and _context.plugin.is_inside_tree()
		and not _context.plugin.is_queued_for_deletion()
	)


## 普通输入变化清除旧计划及结果并安排新预览；待恢复报告优先保留，不能被新输入冲掉。
## [br]
## @api private
func _invalidate_preview() -> void:
	if _last_report.get("recovery_required") == true:
		return
	_generation += 1
	_last_report.clear()
	_plan.clear()
	_create.disabled = true
	_update_result_actions()
	_queue_preview()


## 延迟检查只属于当前页面代次；旧输入或旧上下文安排的回调不能替换当前摘要。
## [br]
## @api private
func _queue_preview() -> void:
	if _busy or not _is_context_active() or _last_report.get("recovery_required") == true:
		return
	_details.text = "正在更新变更摘要…"
	_refresh_plan.call_deferred(_generation)


## 只读重算指定代次的计划；进入前与返回后均检查资格，旧调用不能发布摘要或重新启用创建按钮。
## [br]
## @api private
func _refresh_plan(generation: int) -> void:
	if generation != _generation or _busy or not _is_context_active() or _last_report.get("recovery_required") == true:
		return
	var plan: Dictionary = _GENERATOR_SCRIPT.get_plan(_directory.text, _get_options())
	if generation != _generation or not _is_context_active():
		return
	_plan = plan
	_show_plan(plan)
	_set_busy(false)


## 从当前控件构造生成器的三个闭合选项；控件显示文字不作为操作模式传入。
## [br]
## @api private
func _get_options() -> Dictionary:
	return {
		"mode": "existing_project" if _mode.selected == 1 else "new_project",
		"create_installer": _create_installer.button_pressed,
		"include_readme": _include_readme.button_pressed,
	}


## 根据所选模式说明会保留或建立的项目入口，不据此执行任何文件或设置变更。
## [br]
## @api private
func _update_mode_hint() -> void:
	_mode_hint.text = (
		"保留已有主场景和 Installer。只新建所选文件，并提供可复制的初始化片段。"
		if _mode.selected == 1 else
		"创建 Boot 和空 Main，设置 Boot 为主场景；已有主场景或 Installer 时请选择接入现有项目。"
	)


## 统一应用提交占用、上下文撤销与待恢复状态；纯说明计划始终禁用创建，但可保留适用的导航动作。
## [br]
## @api private
func _set_busy(active: bool) -> void:
	_busy = active
	var unavailable: bool = active or not _is_context_active() or _last_report.get("recovery_required") == true
	_directory.editable = not unavailable
	_mode.disabled = unavailable
	_create_installer.disabled = unavailable
	_include_readme.disabled = unavailable
	_preview.disabled = unavailable
	_create.disabled = unavailable or _plan.get("ok") != true or _plan.get("guidance_only") == true
	_create.tooltip_text = (
		"按摘要新建文件，并保存当前项目设置。"
		if _has_settings_changes(_plan) else
		"按摘要新建文件，不保存项目设置。"
	)
	_update_result_actions()


## 只以计划中的实际 settings_after 字典判断是否会保存项目设置，避免按操作模式猜测副作用。
## [br]
## @api private
func _has_settings_changes(plan: Dictionary) -> bool:
	var value: Variant = plan.get("settings_after", {})
	if value is Dictionary:
		var settings: Dictionary = value
		return not settings.is_empty()
	return false


## 按有效上下文、恢复状态及可用结果路径更新导航按钮；Boot 和 Installer 必须来自成功报告。
## [br]
## @api private
func _update_result_actions() -> void:
	var unavailable: bool = _busy or not _is_context_active() or _last_report.get("recovery_required") == true
	var completed: bool = _last_report.get("ok") == true
	_open_scene.disabled = unavailable or not completed or _read_string(_last_report, "scene_path").is_empty()
	_open_installer.disabled = unavailable or not completed or _read_string(_last_report, "installer_path").is_empty()
	_open_main.disabled = unavailable or _main_path().is_empty()
	_copy_snippet.disabled = unavailable or _integration_snippet().is_empty()


## 只接受报告中的 String 字段，缺失或类型错误时返回空文本，不对任意对象执行字符串转换。
## [br]
## @api private
func _read_string(data: Dictionary, key: String) -> String:
	var value: Variant = data.get(key, "")
	if value is String:
		var text: String = value
		return text
	return ""


## 已有项目优先使用计划中解析出的主场景；新项目必须等成功报告后才提供生成的 Main 路径。
## [br]
## @api private
func _main_path() -> String:
	if _read_string(_plan, "mode") == "existing_project":
		return _read_string(_plan, "main_scene_path")
	if _last_report.get("ok") == true:
		return _read_string(_last_report, "main_scene_path")
	return ""


## 只返回已有项目模式下成功计划或成功报告的接入片段；新项目模式及无有效结果时为空。
## [br]
## @api private
func _integration_snippet() -> String:
	if _plan.get("ok") == true and _read_string(_plan, "mode") == "existing_project":
		return _read_string(_plan, "integration_snippet")
	if _last_report.get("ok") == true and _read_string(_last_report, "mode") == "existing_project":
		return _read_string(_last_report, "integration_snippet")
	return ""


## 再次确认场景资源存在后交给编辑器打开；文件已被移走时保留报告并追加提示，不自动再生成。
## [br]
## @api private
func _open_scene_path(path: String) -> void:
	if path.is_empty():
		return
	if not ResourceLoader.exists(path, "PackedScene"):
		_details.text += "\n无法定位场景：" + path + "。请确认资源存在并刷新变更摘要。"
		return
	EditorInterface.open_scene_from_path(path)


## 展示确切文件与设置意图，并区分零写入接入说明；这里只呈现计划，不把预览成功视为提交完成。
## [br]
## @api private
func _show_plan(plan: Dictionary) -> void:
	var lines: PackedStringArray = PackedStringArray()
	var _title_added: bool = lines.append("变更摘要" if plan.get("ok") == true else "暂不能初始化")
	for issue: String in plan["issues"]:
		var _issue_added: bool = lines.append("• " + issue)
	for path: String in plan["paths"]:
		var _path_added: bool = lines.append("新建：" + path)
	var installer_path: String = _read_string(plan, "installer_path")
	if not installer_path.is_empty():
		var _installer_added: bool = lines.append("追加 Installer：" + installer_path + "（保留现有顺序）")
	else:
		var _installers_preserved: bool = lines.append("保留现有 Installer 设置。")
	if _read_string(plan, "mode") == "new_project":
		var _main_added: bool = lines.append("设置主场景：" + _read_string(plan, "scene_path"))
	else:
		var _main_preserved: bool = lines.append("保留当前主场景：" + str(ProjectSettings.get_setting("application/run/main_scene", "（未设置）")))
		var snippet: String = _read_string(plan, "integration_snippet")
		if not snippet.is_empty():
			var _snippet_added: bool = lines.append("\n接入片段（复制后加入项目自己的启动入口）：\n" + snippet)
	if plan.get("guidance_only") == true:
		var _guidance_added: bool = lines.append("\n当前仅提供接入说明，不创建文件、不保存设置；可复制片段或打开现有主场景。")
	else:
		var settings_note: String = (
			"本次有设置变更，初始化会保存当前项目设置。"
			if _has_settings_changes(plan) else
			"本次仅创建文件，不保存项目设置。"
		)
		var _note_added: bool = lines.append("\n生成文件属于项目。" + settings_note + "不提供编辑器撤销，不覆盖已有文件。")
	_details.text = "\n".join(lines)


## 按真实报告区分成功、回滚和保留产物待恢复；需要恢复时明确阻止用户把失败理解为零副作用。
## [br]
## @api private
func _show_report(report: Dictionary) -> void:
	var lines: PackedStringArray = PackedStringArray()
	var status: String = report["status"]
	var success_message: String = (
		"项目入口已创建。打开 Boot 后按 F6，初始化成功后会进入空 Main。"
		if _read_string(report, "mode") == "new_project" else
		"接入文件已创建。复制初始化片段，按项目需要接入已有启动入口。"
	)
	var _status_added: bool = lines.append(success_message if report.get("ok") == true else "初始化未完成：" + status)
	for issue: String in report["issues"]:
		var _issue_added: bool = lines.append("• " + issue)
	if report.get("rolled_back") == true:
		var _rollback_added: bool = lines.append("本次文件已回滚；可能保留空目录。项目设置未保存。")
	if report.get("files_created") == true:
		for path: String in report["paths"]:
			var _path_added: bool = lines.append(path)
	if report.get("recovery_required") == true:
		var _recovery_added: bool = lines.append("需要检查并恢复：请保留上述文件和项目设置，不要直接重试创建。")
	var snippet: String = _integration_snippet()
	if not snippet.is_empty():
		var _snippet_added: bool = lines.append("\n接入片段：\n" + snippet)
	_details.text = "\n".join(lines)


# --- 信号处理函数 ---

## 空闲且上下文有效时使旧目录计划失效；实际新目录从控件读取，不使用信号参数作为提交输入。
## [br]
## @api private
func _on_input_changed(_text: String) -> void:
	if not _busy and _is_context_active():
		_invalidate_preview()


## 模式选择后同步使用说明并撤销旧计划，防止复用另一模式下确认的文件和设置意图。
## [br]
## @api private
func _on_mode_selected(_index: int) -> void:
	if not _busy and _is_context_active():
		_update_mode_hint()
		_invalidate_preview()


## 任一产物开关变化都使旧计划失效；新计划统一重新读取两个复选框。
## [br]
## @api private
func _on_option_toggled(_enabled: bool) -> void:
	if not _busy and _is_context_active():
		_invalidate_preview()


## 显式刷新时推进代次并立即重算只读计划，取消此前排队预览的发布资格；恢复期间拒绝刷新。
## [br]
## @api private
func _on_preview_pressed() -> void:
	if _busy or not _is_context_active() or _last_report.get("recovery_required") == true:
		return
	_generation += 1
	_refresh_plan(_generation)


## 按当前计划签名同步提交；生成器负责走完保存或补偿，页面代次失效后只放弃 UI 写回。
## 有产物时才刷新编辑器索引，并在该调用返回后再次核对资格再打开启动场景。
## [br]
## @api private
func _on_create_pressed() -> void:
	if _busy or not _is_context_active() or _plan.get("ok") != true or _plan.get("guidance_only") == true or _last_report.get("recovery_required") == true:
		return
	_generation += 1
	var generation: int = _generation
	var signature: String = _plan["signature"]
	_set_busy(true)
	var report: Dictionary = _GENERATOR_SCRIPT.create(_directory.text, _get_options(), signature)
	if not is_instance_valid(self) or generation != _generation or not _is_context_active():
		return
	_last_report = report
	_plan.clear()
	_set_busy(false)
	_show_report(report)
	if report.get("files_created") == true:
		EditorInterface.get_resource_filesystem().scan()
		if not is_instance_valid(self) or generation != _generation or not _is_context_active():
			return
	if report.get("ok") == true:
		_on_open_scene_pressed()


## 仅在成功报告仍可操作时打开本次 Boot；已有项目或未生成启动场景时路径为空。
## [br]
## @api private
func _on_open_scene_pressed() -> void:
	if not _open_scene.disabled and not _busy and _is_context_active() and _last_report.get("ok") == true:
		var path: String = _read_string(_last_report, "scene_path")
		_open_scene_path(path)


## 在有效页面上导航到 _main_path 选择的主场景，不改写项目的主场景设置。
## [br]
## @api private
func _on_open_main_pressed() -> void:
	if not _open_main.disabled and not _busy and _is_context_active():
		var path: String = _main_path()
		_open_scene_path(path)


## 只加载成功报告指向且仍存在的 Installer Script 供编辑；不实例化脚本或再次登记 Installer。
## [br]
## @api private
func _on_open_installer_pressed() -> void:
	if not _open_installer.disabled and not _busy and _is_context_active() and _last_report.get("ok") == true:
		var path: String = _read_string(_last_report, "installer_path")
		if path.is_empty() or not ResourceLoader.exists(path, "Script"):
			_details.text += "\n无法定位 Installer，请确认生成的脚本仍存在。"
			return
		var resource: Resource = ResourceLoader.load(path, "Script")
		if resource is Script:
			var script: Script = resource
			EditorInterface.edit_script(script)


## 将当前可用的已有项目接入片段复制到剪贴板，保留由项目维护者决定合并入口的边界。
## [br]
## @api private
func _on_copy_snippet_pressed() -> void:
	if not _copy_snippet.disabled and not _busy and _is_context_active():
		var snippet: String = _integration_snippet()
		if not snippet.is_empty():
			DisplayServer.clipboard_set(snippet)
