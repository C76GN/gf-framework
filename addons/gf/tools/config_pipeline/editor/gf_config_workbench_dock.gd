@tool

# 配置工具工作区页面；页面只协调独立草稿、纯数据预览和既有执行入口。
extends VBoxContainer


# --- 常量 ---

## 页面草稿、文件保存和恢复报告的持有者；重建 UI 时保留同一会话。
## [br]
## @api private
const _SESSION_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_session.gd")

## 提供版本化新建值、样例事务和读取示例，页面不另造生成协议。
## [br]
## @api private
const _PRESET_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_preset.gd")

## 编辑当前独立草稿的 Schema；页面重建或来源切换时重新绑定。
## [br]
## @api private
const _SCHEMA_FORM_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_schema_form.gd")

## 每次预览或批量预检新建的解析 worker；只接收纯值来源描述。
## [br]
## @api private
const _WORKER_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_preview_worker.gd")

## 持有后台执行及其回收责任的任务封装；页面取消后仍须等待其退出。
## [br]
## @api private
const _TASK_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_background_request_task.gd")

## 与 CLI 一致的报告格式化入口；页面不将严格质量失败误显示为文件未写出。
## [br]
## @api private
const _COMMAND_SCRIPT = preload("res://addons/gf/tools/config_pipeline/gf_config_pipeline_command.gd")

## 项目默认 Profile 路径设置；只由用户点击设为默认时保存到项目。
## [br]
## @api private
const _SETTING: String = "gf/config_pipeline/default_profile_path"


# --- 私有变量 ---

## 页面独占的任务会话；宿主上下文更换只重建控件，不丢弃其中草稿。
## [br]
## @api private
var _session: _SESSION_SCRIPT = _SESSION_SCRIPT.new()

## 汇总保存、结果新鲜度和事务恢复三个独立状态的标签。
## [br]
## @api private
var _status: Label

## 与当前 Profile.sources 顺序一致的来源列表，选中索引写入 _selected_source。
## [br]
## @api private
var _sources: ItemList

## 当前来源的编辑控件容器；切换来源时先移除旧控件，撤销其写回资格。
## [br]
## @api private
var _source_form: VBoxContainer

## 当前草稿的 Schema 编辑器；changed 信号只在本代控件仍有效时接收。
## [br]
## @api private
var _schema_form: _SCHEMA_FORM_SCRIPT

## Profile 产物路径与高级选项的属性编辑容器，每次重新采用草稿时重建。
## [br]
## @api private
var _profile_form: VBoxContainer

## 保留原始执行或恢复报告的只读文本区，补充摘要未展示的失败细节。
## [br]
## @api private
var _report: TextEdit

## 原始解析结果的有限展示树；显示列和单元格文本均截断，不作为完整校验输入。
## [br]
## @api private
var _preview: Tree

## 区分预览进行中、读取失败与来源已变化的提示；过期后仍可保留旧树供查看。
## [br]
## @api private
var _preview_status: Label

## 展示校验问题，并在行 metadata 中保留来源路径和真实位置供导航。
## [br]
## @api private
var _issues: Tree

## 显示保存、访问器和 manifest 产物状态；每项 metadata 保存导航路径。
## [br]
## @api private
var _artifacts: ItemList

## 按校验、预览导出、导出顺序保存按钮，便于同步保存提示与执行准入状态。
## [br]
## @api private
var _run_buttons: Array[Button] = []

## 本次执行开关到 CheckBox 的映射；值随点击执行或复制 CLI 读取，不写入 Profile。
## [br]
## @api private
var _checks: Dictionary = {}

## 显式保存草稿的入口；事务待恢复或同步执行期间禁用。
## [br]
## @api private
var _save_button: Button

## 只请求阶段边界取消的按钮；禁用不代表后台任务已退出。
## [br]
## @api private
var _cancel_button: Button

## 页面拥有的唯一预览或预检任务；取消后保留到 _process 或卸载路径完成回收。
## [br]
## @api private
var _task: GFEditorBackgroundRequestTask

## 解析结果的发布代次；开始任务和取消均递增，旧代完成结果只能回收而不能展示或执行。
## [br]
## @api private
var _generation: int = 0

## 当前来源在草稿数组中的位置；读取前须重新核对草稿和边界，负值表示未选中。
## [br]
## @api private
var _selected_source: int = -1

## 新鲜度复核的累计帧时间；任务空闲且页面可见时约每两秒复核一次。
## [br]
## @api private
var _elapsed: float = 0.0

## 批量预检或同步执行期间的交互禁用标记；普通预览是否占用另由 _task 判断。
## [br]
## @api private
var _busy: bool = false

## 当前后台任务是否为执行前的批量预检；决定同代结果进入执行收尾还是预览展示。
## [br]
## @api private
var _preparing_run: bool = false

## 尚待用户决定保存或放弃的任务替换操作；取消对话框或撤销上下文时清空。
## [br]
## @api private
var _pending: Callable

## 保存成功后才可执行的一次性续接操作；消费前先清空，保存失败不会调用。
## [br]
## @api private
var _after_save: Callable

## 对未保存草稿提供保存、放弃和取消选择的对话框，回调绑定创建时的上下文代次。
## [br]
## @api private
var _discard_dialog: ConfirmationDialog

## 项目资源路径选择器；选中后调用一次 _file_action，不将文件选择当作保存成功。
## [br]
## @api private
var _file_dialog: FileDialog

## 当前文件选择所服务的一次性操作；选择消费、取消或上下文撤销时清空。
## [br]
## @api private
var _file_action: Callable

## 最近请求的 build/export 操作，供预检完成后执行及复制等价 CLI 使用。
## [br]
## @api private
var _last_operation: String = "export"

## 点击执行时冻结的开关；复制 CLI 会在副本中采用当前复选框值。
## [br]
## @api private
var _last_options: Dictionary = { "write_manifest": true }

## 宿主授予的编辑器上下文；页面和插件均仍在树内且未排队释放时才允许写入操作。
## [br]
## @api private
var _editor_context: GFEditorToolContext

## 控件写回资格的代次，与解析结果代次独立；重绑定和卸载使旧 UI 回调失效。
## [br]
## @api private
var _context_generation: int = 0

## 已接受预览的读取收据副本；取消或磁盘内容不再匹配时清空，不能继续证明旧预览新鲜。
## [br]
## @api private
var _preview_receipt: Dictionary = {}


# --- Godot 生命周期方法 ---

## 创建初始页面控件；真正的编辑资格由宿主上下文决定，后续重绑定会重建控件并保留会话。
## [br]
## @api private
func _init() -> void:
	name = "ConfigWorkbench"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()


## 尝试采用项目默认 Profile 并刷新状态；加载入口仍要求有效宿主上下文，不因进入树就绕过写入资格。
## [br]
## @api private
func _ready() -> void:
	var default_path: String = GFVariantData.to_text(ProjectSettings.get_setting(_SETTING, ""))
	if not default_path.is_empty():
		_load_profile(default_path)
	_refresh_status()


## 回收已结束的后台任务后，仅发布未取消且代次匹配的结果；旧结果仍须回收，但不得推进执行预检。
## 页面空闲且可见时定期复核来源和结果新鲜度，不自动重新执行任务。
## [br]
## @api private
func _process(delta: float) -> void:
	if _task != null and not _task.is_running():
		var result: Dictionary = GFVariantData.as_dictionary(_task.wait_to_finish())
		_task = null
		_cancel_button.disabled = true
		if GFVariantData.get_option_int(result, "generation") == _generation and not GFVariantData.get_option_bool(result, "cancelled"):
			if _preparing_run:
				_preparing_run = false
				_busy = false
				_finish_run_preflight(result)
			else:
				_show_preview(result)
		_refresh_status()
	_elapsed += delta
	if _elapsed >= 2.0 and not _busy and _task == null and is_visible_in_tree():
		_elapsed = 0.0
		_session.refresh_freshness()
		_refresh_preview_freshness()
		_refresh_status()


## 先撤销上下文和续接回调，再请求取消并等待后台任务回收；不能留下仍访问 worker 的任务。
## 编辑器卸载时尝试把脏草稿另存到编辑器缓存，不覆盖用户 Profile。
## [br]
## @api private
func _exit_tree() -> void:
	_context_generation += 1
	_editor_context = null
	_pending = Callable()
	_after_save = Callable()
	_file_action = Callable()
	_cancel_preview()
	if _task != null:
		var _finished: Variant = _task.wait_to_finish()
		_task = null
	# Workspace 切页保留实例。真正卸载时只保留编辑器缓存草稿，不写用户 Profile。
	if Engine.is_editor_hint() and GFVariantData.get_option_bool(_session.get_state(), "dirty"):
		var profile: GFConfigPipelineProfile = _session.get_profile()
		if profile != null:
			var recovery_path: String = "res://.godot/editor/gf_config_workbench_draft.tres"
			var _save_result: Error = ResourceSaver.save(profile, recovery_path)


# --- 框架内部方法 ---

## 工作区刷新贡献时保留未保存的独立 Profile 草稿；检测不会写入项目文件。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return: 当前页面是否拥有未保存的任务修改。
func has_unsaved_workspace_changes() -> bool:
	return GFVariantData.get_option_bool(_session.get_state(), "dirty")


## 宿主撤销上下文时取消预检并使所有旧控件回调失效；重新绑定保留工作草稿。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param context: 当前宿主上下文；null 撤销页面写入资格。
func set_editor_context(context: GFEditorToolContext) -> void:
	_context_generation += 1
	_editor_context = context
	_cancel_preview()
	_pending = Callable()
	_after_save = Callable()
	_file_action = Callable()
	_schema_form.configure(null, null)
	for child: Node in get_children():
		if child is Window:
			var window: Window = child
			window.hide()
	_clear(self)
	_run_buttons.clear()
	_checks.clear()
	_build_ui()
	if context != null:
		_refresh_profile()
	else:
		_refresh_status()


# --- 私有/辅助方法 ---

## 同时确认页面与宿主插件仍在树内且未排队释放；仅持有非空上下文不足以继续编辑。
## [br]
## @api private
func _has_active_context() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and _editor_context != null and is_instance_valid(_editor_context.plugin) and _editor_context.plugin.is_inside_tree() and not _editor_context.plugin.is_queued_for_deletion()


## 只接受本代且仍属于页面树的控件回调；上下文替换或控件移除后即撤销旧闭包的写回资格。
## [br]
## @api private
func _accept_callback(control: Node, generation: int) -> bool:
	return generation == _context_generation and _has_active_context() and is_instance_valid(control) and control.is_inside_tree() and not control.is_queued_for_deletion() and is_ancestor_of(control)


## 创建当前上下文代次的工作台控件与对话框；所有捕获草稿的交互回调先核对所属代次和控件存活。
## [br]
## @api private
func _build_ui() -> void:
	var ui_generation: int = _context_generation
	var toolbar: HFlowContainer = HFlowContainer.new()
	add_child(toolbar)
	var _button_newprofile: Button = _button(toolbar, "NewProfile", "新建任务", func() -> void: _request_replace(_show_new_dialog))
	var _button_openprofile: Button = _button(toolbar, "OpenProfile", "打开 Profile", func() -> void: _request_replace(func() -> void: _choose_file(FileDialog.FILE_MODE_OPEN_FILE, "*.tres ; Profile", _load_profile)))
	_save_button = _button(toolbar, "SaveProfile", "保存", _save_profile)
	var _button_reloadprofile: Button = _button(toolbar, "ReloadProfile", "放弃并重载", func() -> void:
		var path: String = GFVariantData.get_option_string(_session.get_state(), "profile_path")
		if not path.is_empty():
			_request_replace(func() -> void: _load_profile(path))
	)
	var _button_createsample: Button = _button(toolbar, "CreateSample", "创建可运行示例", func() -> void: _request_replace(_show_sample_dialog))
	var _button_recoverdraft: Button = _button(toolbar, "RecoverDraft", "恢复卸载前草稿", func() -> void: _request_replace(func() -> void: _load_profile("res://.godot/editor/gf_config_workbench_draft.tres")))
	var _button_setprojectdefault: Button = _button(toolbar, "SetProjectDefault", "设为项目默认", _set_default)
	var _button_reapplypreset: Button = _button(toolbar, "ReapplyPreset", "比较 / 重新应用预设", _show_preset_dialog)
	var _button_close: Button = _button(toolbar, "CloseTask", "关闭任务", func() -> void: _request_replace(func() -> void:
		_session.clear_profile()
		_refresh_profile()
	))
	var introduction: Label = Label.new()
	introduction.text = "从创建可运行示例开始，或新建任务 → 保存 Profile → 校验/导出。工作台执行最多 4,000 单元格；大表可复制 CLI 调整预算。"
	introduction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(introduction)
	_status = Label.new()
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)
	var sources_page: VBoxContainer = _page(tabs, "来源与预览")
	var source_toolbar: HBoxContainer = HBoxContainer.new()
	sources_page.add_child(source_toolbar)
	var _button_addsource: Button = _button(source_toolbar, "AddSource", "添加来源", _add_source)
	var _button_removesource: Button = _button(source_toolbar, "RemoveSource", "删除来源", _remove_source)
	var _button_previewsource: Button = _button(source_toolbar, "PreviewSource", "读取预览", _start_preview)
	_cancel_button = _button(source_toolbar, "CancelPreview", "取消预览（阶段边界）", _cancel_preview)
	_cancel_button.disabled = true
	_sources = ItemList.new()
	_sources.name = "Sources"
	_sources.custom_minimum_size.y = 90
	sources_page.add_child(_sources)
	var _source_connection: int = _sources.item_selected.connect(func(index: int) -> void:
		if _accept_callback(_sources, ui_generation):
			_select_source(index)
	)
	_source_form = VBoxContainer.new()
	sources_page.add_child(_source_form)
	_preview_status = Label.new()
	_preview_status.name = "PreviewStatus"
	_preview_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_status.text = "预览为原始解析值，最多显示 100 行；校验/导出使用完整数据。XLSX 不计算公式，可能读取已有缓存值。"
	sources_page.add_child(_preview_status)
	_preview = Tree.new()
	_preview.name = "DataPreview"
	_preview.hide_root = true
	_preview.column_titles_visible = true
	_preview.custom_minimum_size.y = 180
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sources_page.add_child(_preview)
	var schema_page: VBoxContainer = _page(tabs, "Schema 与引用")
	var _button_copyinferredschema: Button = _button(schema_page, "CopyInferredSchema", "从最近成功校验复制 Schema", _copy_schema)
	_schema_form = _SCHEMA_FORM_SCRIPT.new()
	schema_page.add_child(_schema_form)
	var _schema_connection: int = _schema_form.changed.connect(func() -> void:
		if _accept_callback(_schema_form, ui_generation):
			_changed()
	)
	_profile_form = _page(tabs, "产物与高级选项")
	var result_page: VBoxContainer = _page(tabs, "问题与产物")
	_issues = Tree.new()
	_issues.name = "Issues"
	_issues.hide_root = true
	_issues.columns = 3
	_issues.column_titles_visible = true
	_issues.set_column_title(0, "级别 / 标识")
	_issues.set_column_title(1, "来源 / 字段")
	_issues.set_column_title(2, "说明")
	_issues.custom_minimum_size.y = 160
	result_page.add_child(_issues)
	var _issue_connection: int = _issues.item_activated.connect(func() -> void:
		if _accept_callback(_issues, ui_generation):
			_open_issue()
	)
	_artifacts = ItemList.new()
	_artifacts.name = "Artifacts"
	_artifacts.custom_minimum_size.y = 85
	result_page.add_child(_artifacts)
	var _artifact_connection: int = _artifacts.item_activated.connect(func(index: int) -> void:
		if _accept_callback(_artifacts, ui_generation):
			_open_artifact(index)
	)
	var _button_recovertransaction: Button = _button(result_page, "RecoverTransaction", "重试报告要求的恢复动作", func() -> void:
		_report.text = JSON.stringify(_session.recover(), "\t")
		_refresh_status()
	)
	_report = TextEdit.new()
	_report.name = "RawReport"
	_report.editable = false
	_report.custom_minimum_size.y = 180
	_report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	result_page.add_child(_report)
	var run_row: HFlowContainer = HFlowContainer.new()
	add_child(run_row)
	for entry: Array in [["strict", "严格结果"], ["changed_only", "仅变化"], ["write_manifest", "写 manifest"]]:
		var checkbox: CheckBox = CheckBox.new()
		checkbox.name = GFVariantData.to_text(entry[0]).to_pascal_case()
		checkbox.text = GFVariantData.to_text(entry[1])
		checkbox.button_pressed = entry[0] == "write_manifest"
		_checks[entry[0]] = checkbox
		run_row.add_child(checkbox)
	var execution_note: Label = Label.new()
	execution_note.text = "本次执行选项不保存到 Profile；严格模式可能在文件写出后报告失败。"
	add_child(execution_note)
	var actions: HFlowContainer = HFlowContainer.new()
	add_child(actions)
	_run_buttons.append(_button(actions, "Validate", "校验", func() -> void: _request_run("build", false)))
	_run_buttons.append(_button(actions, "DryRun", "预览导出", func() -> void: _request_run("export", true)))
	_run_buttons.append(_button(actions, "Export", "导出", func() -> void: _request_run("export", false)))
	var _button_copycli: Button = _button(actions, "CopyCli", "复制等价 CLI", _copy_cli)
	var _button_readexample: Button = _button(actions, "ReadExample", "读取示例", _show_read_example)
	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.title = "未保存的 Profile 草稿"
	_discard_dialog.dialog_text = "保存或放弃当前草稿后继续；取消会保留草稿。"
	_discard_dialog.ok_button_text = "放弃并继续"
	var _save_custom: Button = _discard_dialog.add_button("保存并继续", false, "save")
	add_child(_discard_dialog)
	var _discard_connection: int = _discard_dialog.confirmed.connect(func() -> void:
		if not _accept_callback(_discard_dialog, ui_generation):
			return
		if _pending.is_valid():
			_pending.call()
		_pending = Callable()
	)
	var _custom_connection: int = _discard_dialog.custom_action.connect(func(action: StringName) -> void:
		if not _accept_callback(_discard_dialog, ui_generation):
			return
		if action == &"save":
			_discard_dialog.hide()
			_after_save = _pending
			_pending = Callable()
			_save_profile()
	)
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	add_child(_file_dialog)
	var _file_connection: int = _file_dialog.file_selected.connect(func(path: String) -> void:
		if not _accept_callback(_file_dialog, ui_generation):
			return
		if _file_action.is_valid():
			var action: Callable = _file_action
			_file_action = Callable()
			action.call(path)
	)
	var _file_cancel_connection: int = _file_dialog.canceled.connect(func() -> void:
		if not _accept_callback(_file_dialog, ui_generation):
			return
		_file_action = Callable()
		_after_save = Callable()
	)
	var _discard_cancel_connection: int = _discard_dialog.canceled.connect(func() -> void:
		if _accept_callback(_discard_dialog, ui_generation):
			_pending = Callable()
	)


## 为一个页签建立可滚动的纵向内容容器，返回内层容器供调用方加入控件。
## [br]
## @api private
func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title
	tabs.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content


## 创建绑定当前上下文代次的操作按钮；点击时重新验证按钮仍在页面树中再执行操作。
## [br]
## @api private
func _button(parent: Node, node_name: String, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	parent.add_child(button)
	var generation: int = _context_generation
	var _connection: int = button.pressed.connect(func() -> void:
		if _accept_callback(button, generation):
			callback.call()
	)
	return button


## 为当前操作配置一次文件选择；只记录续接回调，真正读取或保存由选中路径后的回调负责。
## [br]
## @api private
func _choose_file(mode: FileDialog.FileMode, filter: String, action: Callable) -> void:
	if not _has_active_context():
		return
	_file_action = action
	_file_dialog.file_mode = mode
	_file_dialog.filters = PackedStringArray([filter])
	_file_dialog.popup_centered_ratio(0.7)


## 任务占用或事务待恢复时拒绝替换；有脏草稿时暂存操作，待用户保存或放弃后继续。
## [br]
## @api private
func _request_replace(action: Callable) -> void:
	if not _has_active_context():
		return
	if _busy or _task != null or GFVariantData.get_option_bool(_session.get_state(), "recovery_required"):
		_status.text = "请等待当前操作或完成文件恢复。"
		return
	if GFVariantData.get_option_bool(_session.get_state(), "dirty"):
		_pending = action
		_discard_dialog.popup_centered()
	else:
		action.call()


## 收集新任务的来源和输出建议；确认仅创建独立草稿，旧上下文对话框不能写回。
## [br]
## @api private
func _show_new_dialog() -> void:
	var generation: int = _context_generation
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "新建导表任务"
	var form: VBoxContainer = VBoxContainer.new()
	dialog.add_child(form)
	var source: LineEdit = _line(form, "来源文件", "res://data/config/items.csv")
	var database: LineEdit = _line(form, "数据库名", "main")
	var output: LineEdit = _line(form, "输出目录", "res://generated")
	add_child(dialog)
	var _confirm_connection: int = dialog.confirmed.connect(func() -> void:
		if not _accept_callback(dialog, generation):
			return
		_session.create_profile(source.text, database.text, output.text)
		_selected_source = 0
		_refresh_profile()
		dialog.queue_free()
	)
	var _cancel_connection: int = dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(520, 220))


## 明确确认后创建样例文件；把待恢复事务交给会话保留，只有成功创建才加载样例 Profile。
## [br]
## @api private
func _show_sample_dialog() -> void:
	var generation: int = _context_generation
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "创建样例（已有文件不会覆盖）"
	var form: VBoxContainer = VBoxContainer.new()
	dialog.add_child(form)
	var root: LineEdit = _line(form, "样例根目录", "res://")
	add_child(dialog)
	var _confirm_connection: int = dialog.confirmed.connect(func() -> void:
		if not _accept_callback(dialog, generation):
			return
		var result: Dictionary = _PRESET_SCRIPT.create_sample(root.text)
		_session.adopt_recovery_report(result)
		_report.text = JSON.stringify(result, "\t")
		if GFVariantData.get_option_bool(result, "ok"):
			_load_profile(GFVariantData.get_option_string(result, "profile_path"))
			_status.text = "样例已创建。点击导出，再运行：" + GFVariantData.get_option_string(result, "scene_path")
		dialog.queue_free()
	)
	var _cancel_connection: int = dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(540, 150))


## 创建带说明标签的文本输入框；只设置初值，具体草稿写回规则由调用方连接。
## [br]
## @api private
func _line(parent: Node, placeholder: String, initial: String) -> LineEdit:
	var label: Label = Label.new()
	label.text = placeholder
	parent.add_child(label)
	var field: LineEdit = LineEdit.new()
	field.text = initial
	field.placeholder_text = placeholder
	parent.add_child(field)
	return field


## 通过会话采用独立草稿并重建表单；从编辑器恢复目录加载的草稿仍标为待保存。
## [br]
## @api private
func _load_profile(path: String) -> void:
	if not _has_active_context():
		return
	if _session.load_profile(path):
		if path.begins_with("res://.godot/"):
			_session.mark_changed()
		_selected_source = 0
		_refresh_profile()
	else:
		_report.text = JSON.stringify(_session.get_state()["result"], "\t")


## 已有项目路径直接保存；未命名或来自编辑器恢复目录的草稿必须先选择项目内新路径。
## [br]
## @api private
func _save_profile() -> void:
	if not _has_active_context():
		return
	var path: String = GFVariantData.get_option_string(_session.get_state(), "profile_path")
	if path.is_empty() or path.begins_with("res://.godot/"):
		_file_dialog.current_path = "res://config/build/main.tres"
		_choose_file(FileDialog.FILE_MODE_SAVE_FILE, "*.tres ; Profile", _save_to)
	else:
		_save_to(path)


## 展示真实保存报告后消费一次续接操作；失败也清空续接槽位，避免以后误执行旧意图。
## [br]
## @api private
func _save_to(path: String) -> void:
	if not _has_active_context():
		return
	var result: Dictionary = _session.save_profile(path)
	_report.text = JSON.stringify(result, "\t")
	_refresh_status()
	var action: Callable = _after_save
	_after_save = Callable()
	if GFVariantData.get_option_bool(result, "success") and action.is_valid():
		action.call()


## 作废旧预览与表单并绑定当前草稿；不重新加载磁盘，也不把重建界面视为保存。
## [br]
## @api private
func _refresh_profile() -> void:
	_cancel_preview()
	_sources.clear()
	_clear(_profile_form)
	_clear(_source_form)
	_schema_form.configure(null, null)
	_preview.clear()
	var profile: GFConfigPipelineProfile = _session.get_profile()
	if profile == null:
		_refresh_status()
		return
	for source: GFConfigPipelineTableSource in profile.sources:
		var _source_index: int = _sources.add_item("%s · %s" % [source.get_table_key(), source.source_path] if source != null else "Invalid source")
	for property_name: String in ["profile_id", "database_id", "version", "output_path", "access_output_path", "access_class_name", "access_provider_accessor", "build_options", "save_options", "access_options"]:
		_bind_property(_profile_form, profile, property_name)
	if not profile.sources.is_empty():
		_selected_source = clampi(_selected_source, 0, profile.sources.size() - 1)
		_sources.select(_selected_source)
		_select_source(_selected_source)
	_refresh_status()


## 切换当前来源并使旧预览失效；外部选中的 Schema 复制后才归入草稿，旧来源控件先移除。
## [br]
## @api private
func _select_source(index: int) -> void:
	var generation: int = _context_generation
	_cancel_preview()
	_preview.clear()
	_preview_status.text = "当前来源尚未预览。XLSX 不计算公式，可能读取已有缓存值。"
	_selected_source = index
	_clear(_source_form)
	var source: GFConfigPipelineTableSource = _current_source()
	if source == null:
		return
	for property_name: String in ["table_name", "source_path", "source_format"]:
		_bind_property(_source_form, source, property_name)
	var sheet: LineEdit = _line(_source_form, "XLSX Sheet 名（空表示 sheet_index，默认首表）", GFVariantData.get_option_string(source.parse_options, "sheet_name"))
	var _sheet_connection: int = sheet.text_changed.connect(func(text: String) -> void:
		if not _accept_callback(sheet, generation):
			return
		source.parse_options["sheet_name"] = text
		_changed()
	)
	var header: SpinBox = SpinBox.new()
	header.name = "HeaderRow"
	header.min_value = 1
	header.max_value = 100000
	header.prefix = "物理表头行 "
	header.value = GFVariantData.get_option_int(source.parse_options, "header_row", 1)
	_source_form.add_child(header)
	var _header_connection: int = header.value_changed.connect(func(value: float) -> void:
		if not _accept_callback(header, generation):
			return
		source.parse_options["header_row"] = int(value)
		_changed()
	)
	for property_name: String in ["infer_schema", "coerce_records", "parse_options", "schema_options"]:
		_bind_property(_source_form, source, property_name)
	var picker: EditorResourcePicker = EditorResourcePicker.new()
	picker.name = "ExplicitSchema"
	picker.base_type = "GFConfigTableSchema"
	picker.edited_resource = source.schema
	_source_form.add_child(picker)
	var _schema_connection: int = picker.resource_changed.connect(func(resource: Resource) -> void:
		if not _accept_callback(picker, generation):
			return
		source.schema = null
		if resource is GFConfigTableSchema:
			var selected_schema: GFConfigTableSchema = resource
			source.schema = selected_schema.duplicate_schema()
		_changed()
		_schema_form.configure(_session.get_profile(), source)
	)
	_schema_form.configure(_session.get_profile(), source)


## 按资源属性元数据创建草稿编辑器；仍属于本代页面的控件才可写回并标记结果过期。
## [br]
## @api private
func _bind_property(parent: Node, resource: Resource, property_name: String) -> void:
	var generation: int = _context_generation
	for property_info: Dictionary in resource.get_property_list():
		if GFVariantData.get_option_string(property_info, "name") == property_name:
			var field: GFEditorValueField = GFEditorValueField.new()
			field.name = property_name.to_pascal_case()
			parent.add_child(field)
			field.configure(property_info, resource.get(property_name))
			var _connection: int = field.value_changed.connect(func(value: Variant) -> void:
				if not _accept_callback(field, generation):
					return
				resource.set(property_name, value)
				_changed()
			)
			return


## 有效编辑使草稿变脏、旧执行结果过期，并撤销在途预览的发布资格。
## [br]
## @api private
func _changed() -> void:
	if not _has_active_context():
		return
	_session.mark_changed()
	_cancel_preview()
	_preview_status.text = "预览已过期；重新读取或校验以查看当前值。"
	_refresh_status()


## 从当前草稿重新解析选中位置；草稿缺失或索引失效时返回 null，不保留已删除来源。
## [br]
## @api private
func _current_source() -> GFConfigPipelineTableSource:
	var profile: GFConfigPipelineProfile = _session.get_profile()
	if profile == null or _selected_source < 0 or _selected_source >= profile.sources.size():
		return null
	return profile.sources[_selected_source]


## 文件选择成功后从预设创建新来源并追加到草稿；仅刷新编辑状态，不读取表内容或保存 Profile。
## [br]
## @api private
func _add_source() -> void:
	var profile: GFConfigPipelineProfile = _session.get_profile()
	if profile == null:
		return
	_choose_file(FileDialog.FILE_MODE_OPEN_FILE, "*.csv,*.json,*.xlsx,*.cfg ; Config source", func(path: String) -> void:
		var source: GFConfigPipelineTableSource = _PRESET_SCRIPT.make_profile(path).sources[0]
		profile.sources.append(source)
		_selected_source = profile.sources.size() - 1
		_changed()
		_refresh_profile()
	)


## 在有效上下文中删除当前草稿来源，重建表单并取消旧预览；不删除来源文件。
## [br]
## @api private
func _remove_source() -> void:
	var profile: GFConfigPipelineProfile = _session.get_profile()
	if _has_active_context() and profile != null and _selected_source >= 0 and _selected_source < profile.sources.size():
		profile.sources.remove_at(_selected_source)
		_changed()
		_refresh_profile()


## 先做来源准入和纯值检查，再以新代次提交独立 worker；同一页面未回收旧任务前不启动新预览。
## [br]
## @api private
func _start_preview() -> void:
	if not _has_active_context() or _task != null or _busy:
		return
	var source: GFConfigPipelineTableSource = _current_source()
	if source == null:
		return
	var admission: Dictionary = _session.get_admission_report()
	if not GFVariantData.get_option_bool(admission, "success"):
		_preview_status.text = GFVariantData.get_option_string(admission, "error")
		return
	var effective_parse: Dictionary = source.parse_options.duplicate(true)
	var _merged: Dictionary = GFVariantData.merge_dictionary(effective_parse, GFVariantData.get_option_dictionary(_session.get_profile().make_build_options(), "parse_options"))
	# 只传 JSON 纯值。禁止共享 Resource/Callable 进入解析 worker。
	if not _is_pure_value(effective_parse, 0):
		_preview_status.text = "预览仅接受纯值解析选项；请使用 CLI 处理自定义对象。"
		return
	_generation += 1
	_task = _TASK_SCRIPT.new()
	var _configured: GFEditorBackgroundRequestTask = _task.configure(_WORKER_SCRIPT.new(), { "generation": _generation, "source_path": source.source_path, "table_name": source.table_name, "source_format": source.source_format, "parse_options": effective_parse })
	var start_error: Error = _task.start()
	if start_error != OK:
		_task = null
		_preview_status.text = error_string(start_error)
		return
	_cancel_button.disabled = false
	_preview_status.text = "正在后台读取与解析；取消在阶段边界生效。"
	_refresh_status()


## 立即递增代次并撤销预览收据，只向 worker 请求协作取消；任务仍保留到轮询或卸载路径等待回收。
## 取消预检会解除执行意图，但不能据此认为解析线程已经退出。
## [br]
## @api private
func _cancel_preview() -> void:
	_generation += 1
	_preview_receipt.clear()
	if _preparing_run:
		_preparing_run = false
		_busy = false
	if _task != null:
		_task.request_cancel()
	if _cancel_button != null:
		_cancel_button.disabled = true


## 仅展示成功且读取收据仍匹配磁盘的结果；收据复制留作后续新鲜度检查，列数及单元格文本有展示上限。
## [br]
## @api private
func _show_preview(result: Dictionary) -> void:
	_preview.clear()
	_preview_receipt.clear()
	if not GFVariantData.get_option_bool(result, "success"):
		_preview_status.text = GFVariantData.get_option_string(result, "error")
		return
	var receipt: Dictionary = GFVariantData.get_option_dictionary(result, "source_receipt")
	if not _receipt_matches_disk(receipt):
		_preview_status.text = "来源在后台读取后已变化；预览已过期，请重新读取。"
		return
	_preview_receipt = receipt.duplicate(true)
	var records: Array = GFVariantData.get_option_array(result, "data")
	var keys: Array = GFVariantData.as_dictionary(records[0]).keys() if not records.is_empty() else []
	_preview.columns = maxi(1, mini(keys.size(), 32))
	for index: int in range(mini(keys.size(), 32)):
		_preview.set_column_title(index, str(keys[index]))
	var root: TreeItem = _preview.create_item()
	for record_value: Variant in records:
		var record: Dictionary = GFVariantData.as_dictionary(record_value)
		var item: TreeItem = _preview.create_item(root)
		for index: int in range(mini(keys.size(), 32)):
			item.set_text(index, str(record.get(keys[index], "")).left(240))
	_preview_status.text = "共 %d 行；显示前 100 行 / 32 列。Sheet: %s；读取 %.1f ms，解析 %.1f ms。" % [GFVariantData.get_option_int(result, "record_count"), GFVariantData.get_option_string(result, "sheet_name", "不适用"), GFVariantData.get_option_float(result, "read_msec"), GFVariantData.get_option_float(result, "layout_msec")]


## 当前收据不再匹配磁盘时撤销它并标记旧预览过期；不会自动重读来源或清除已显示行。
## [br]
## @api private
func _refresh_preview_freshness() -> void:
	if not _preview_receipt.is_empty() and not _receipt_matches_disk(_preview_receipt):
		_preview_receipt.clear()
		_preview_status.text = "来源已变化；当前显示的预览已过期，请重新读取。"


## 有界读取收据指向的当前文件并比较长度与 SHA-256；这是当次内容复核，不锁住后续文件写入。
## [br]
## @api private
func _receipt_matches_disk(receipt: Dictionary) -> bool:
	var path: String = GFVariantData.get_option_string(receipt, "source_path")
	var expected_size: int = GFVariantData.get_option_int(receipt, "size_bytes", -1)
	if path.is_empty() or expected_size < 0 or expected_size > 2 * 1024 * 1024:
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var bytes: PackedByteArray = file.get_buffer(expected_size + 1)
	file.close()
	if bytes.size() != expected_size:
		return false
	var hashing: HashingContext = HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK or hashing.update(bytes) != OK:
		return false
	return hashing.finish().hex_encode() == GFVariantData.get_option_string(receipt, "sha256")


## 递归限制解析选项的类型、容器长度和嵌套深度，拒绝 Resource、Callable 等对象进入后台请求。
## [br]
## @api private
func _is_pure_value(value: Variant, depth: int) -> bool:
	if depth > 12:
		return false
	if value is Dictionary:
		var dictionary: Dictionary = value
		if dictionary.size() > 128:
			return false
		for key: Variant in dictionary:
			if not (key is String or key is StringName) or not _is_pure_value(dictionary[key], depth + 1):
				return false
		return true
	if value is Array:
		var array: Array = value
		if array.size() > 128:
			return false
		for item: Variant in array:
			if not _is_pure_value(item, depth + 1):
				return false
		return true
	return typeof(value) in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_PACKED_STRING_ARRAY]


## 冻结本次执行开关；脏草稿先显式保存，只有保存成功才续接后台预检。
## [br]
## @api private
func _request_run(operation: String, dry_run: bool) -> void:
	if not _has_active_context():
		return
	if _busy or _task != null:
		return
	_last_operation = operation
	_last_options = { "dry_run": dry_run }
	for option: String in _checks:
		var checkbox: CheckBox = _checks[option]
		_last_options[option] = checkbox.button_pressed
	if GFVariantData.get_option_bool(_session.get_state(), "dirty") or GFVariantData.get_option_string(_session.get_state(), "profile_path").is_empty():
		_after_save = _run_saved
		_save_profile()
	else:
		_run_saved()


## 通过准入后为全部来源创建纯值预检请求；后台只核算输入和单元格预算，实际导出稍后在主线程执行。
## [br]
## @api private
func _run_saved() -> void:
	if not _has_active_context():
		return
	var admission: Dictionary = _session.get_admission_report()
	if not GFVariantData.get_option_bool(admission, "success"):
		_report.text = JSON.stringify(admission, "\t")
		return
	var profile: GFConfigPipelineProfile = _session.get_profile()
	var sources: Array[Dictionary] = []
	var common_parse: Dictionary = GFVariantData.get_option_dictionary(profile.make_build_options(), "parse_options")
	for source: GFConfigPipelineTableSource in profile.sources:
		var effective_parse: Dictionary = source.parse_options.duplicate(true)
		var _merged: Dictionary = GFVariantData.merge_dictionary(effective_parse, common_parse)
		if not _is_pure_value(effective_parse, 0):
			_report.text = "工作台只预检纯值解析选项；自定义对象选项请使用等价 CLI。"
			return
		sources.append({ "source_path": source.source_path, "table_name": source.table_name, "source_format": source.source_format, "parse_options": effective_parse })
	_generation += 1
	_task = _TASK_SCRIPT.new()
	var _configured: GFEditorBackgroundRequestTask = _task.configure(_WORKER_SCRIPT.new(), { "generation": _generation, "sources": sources })
	var start_error: Error = _task.start()
	if start_error != OK:
		_task = null
		_report.text = error_string(start_error)
		return
	_preparing_run = true
	_busy = true
	_cancel_button.disabled = false
	_preview_status.text = "后台预检输入与 4,000 单元格执行预算；可在阶段边界取消。"
	_refresh_status()


## 对成功预检的每个来源收据重新核对磁盘；任何变化都停止本次执行，全部匹配才进入同步 Command。
## [br]
## @api private
func _finish_run_preflight(preflight: Dictionary) -> void:
	if not _has_active_context():
		return
	if not GFVariantData.get_option_bool(preflight, "success"):
		_report.text = JSON.stringify(preflight, "\t")
		return
	var receipts: Dictionary = GFVariantData.get_option_dictionary(preflight, "receipts")
	for path: String in receipts:
		var receipt: Dictionary = GFVariantData.as_dictionary(receipts[path])
		if not _receipt_matches_disk(receipt):
			_report.text = "来源在预检后发生变化；请重新执行。"
			return
	_execute_saved()


## 在页面交互禁用期间同步执行已保存任务并展示结果；此阶段不通过预览取消按钮中断文件事务。
## [br]
## @api private
func _execute_saved() -> void:
	if not _has_active_context():
		return
	_busy = true
	_refresh_status()
	var result: Dictionary = _session.run_operation(_last_operation, _last_options)
	_busy = false
	_report.text = _COMMAND_SCRIPT.new().make_output_text(result)
	_show_result(result)
	_refresh_status()


## 展示原报告的问题位置与产物状态；Command 因严格质量失败而 runner 成功时明确提示文件操作已完成。
## [br]
## @api private
func _show_result(result: Dictionary) -> void:
	_issues.clear()
	_artifacts.clear()
	var root: TreeItem = _issues.create_item()
	var runner: Dictionary = GFVariantData.get_option_dictionary(result, "runner_result")
	var report: Dictionary = GFVariantData.get_option_dictionary(runner, "report")
	for value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(value)
		var item: TreeItem = _issues.create_item(root)
		item.set_text(0, "%s / %s" % [GFVariantData.get_option_string(issue, "severity"), GFVariantData.get_option_string(issue, "kind")])
		item.set_text(1, "%s:%s:%s · %s" % [GFVariantData.get_option_string(issue, "source"), str(issue.get("line", "?")), str(issue.get("column", "?")), str(issue.get("field", ""))])
		item.set_text(2, GFVariantData.get_option_string(issue, "message"))
		item.set_metadata(0, issue)
	for key: String in ["save_result", "access_result", "manifest_result"]:
		var artifact: Dictionary = GFVariantData.get_option_dictionary(runner, key)
		if artifact.is_empty():
			continue
		var path: String = GFVariantData.get_option_string(artifact, "output_path", GFVariantData.get_option_string(artifact, "path"))
		var artifact_report: Dictionary = GFVariantData.get_option_dictionary(artifact, "artifact_report")
		var status: String = GFVariantData.get_option_string(artifact, "status", GFVariantData.get_option_string(artifact_report, "status"))
		var _artifact_index: int = _artifacts.add_item("%s · %s · %s" % [key, status, path])
		_artifacts.set_item_metadata(_artifacts.item_count - 1, path)
	if not GFVariantData.get_option_bool(result, "success") and GFVariantData.get_option_bool(runner, "success"):
		_report.text = "文件操作已完成；严格质量检查未通过。\n" + _report.text


## 仅从会话仍标为新鲜且成功的数据库结果复制当前表 Schema；副本写入草稿后再次使结果过期。
## [br]
## @api private
func _copy_schema() -> void:
	if not _has_active_context():
		return
	var source: GFConfigPipelineTableSource = _current_source()
	var result: Dictionary = GFVariantData.get_option_dictionary(_session.get_state(), "result")
	var runner: Dictionary = GFVariantData.get_option_dictionary(result, "runner_result")
	var value: Variant = runner.get("database")
	if source == null or not (value is GFConfigDatabaseResource) or GFVariantData.get_option_bool(_session.get_state(), "stale") or not GFVariantData.get_option_bool(runner, "success"):
		_status.text = "请先成功校验当前已保存的 Profile。"
		return
	var database: GFConfigDatabaseResource = value
	var table: GFConfigTableResource = database.get_table_resource(source.get_table_key())
	if table != null and table.schema != null:
		source.schema = table.schema.duplicate_schema()
		_changed()
		_schema_form.configure(_session.get_profile(), source)


## 为已保存 Profile 复制 PowerShell 单引号参数命令；采用最近操作和当前复选框，不执行命令或保存草稿。
## [br]
## @api private
func _copy_cli() -> void:
	if GFVariantData.get_option_string(_session.get_state(), "profile_path").is_empty():
		_status.text = "先保存 Profile，再复制可执行 CLI。"
		return
	var pieces: PackedStringArray = ["godot", "--headless", "--path", ".", "-s", "res://addons/gf/tools/config_pipeline/gf_config_pipeline_cli.gd", "--"]
	var options: Dictionary = _last_options.duplicate(true)
	for key: String in _checks:
		var checkbox: CheckBox = _checks[key]
		options[key] = checkbox.button_pressed
	for argument: String in _session.make_arguments(_last_operation, options):
		var _appended: bool = pieces.append("'" + argument.replace("'", "''") + "'")
	DisplayServer.clipboard_set(" ".join(pieces))
	_status.text = "已复制已保存 Profile 的 CLI（PowerShell 单引号参数）。"


## 为资源格式数据库生成并复制读取示例；JSON 交换产物只提示项目自行适配，不给出不适用的资源加载代码。
## [br]
## @api private
func _show_read_example() -> void:
	var profile: GFConfigPipelineProfile = _session.get_profile()
	if profile != null:
		if profile.output_path.get_extension() not in ["tres", "res"]:
			_report.text = "运行时读取示例支持 .tres/.res 数据库；JSON 导出用于项目数据交换，请在项目层读取并适配。"
			return
		_report.text = _PRESET_SCRIPT.make_read_example(profile)
		DisplayServer.clipboard_set(_report.text)
		_status.text = "读取示例已复制；把脚本附到 Label，导出配置后运行。"


## 将已选择的项目 Profile 路径显式保存为默认；设置保存失败时恢复内存中的旧值。
## [br]
## @api private
func _set_default() -> void:
	if not _has_active_context():
		return
	var path: String = GFVariantData.get_option_string(_session.get_state(), "profile_path")
	if path.is_empty() or path.begins_with("res://.godot/"):
		_status.text = "先把 Profile 保存到项目目录。"
		return
	var previous: Variant = ProjectSettings.get_setting(_SETTING, null)
	ProjectSettings.set_setting(_SETTING, path)
	var result: Error = ProjectSettings.save()
	if result != OK:
		ProjectSettings.set_setting(_SETTING, previous)
	_status.text = "项目默认 Profile 已保存。" if result == OK else error_string(result)


## 先展示预设管理字段的差异，确认后只更新当前草稿；同代有效对话框才可写回，不自动保存。
## [br]
## @api private
func _show_preset_dialog() -> void:
	var generation: int = _context_generation
	var profile: GFConfigPipelineProfile = _session.get_profile()
	if profile == null or _busy or _task != null:
		return
	var changes: PackedStringArray = _PRESET_SCRIPT.describe_changes(profile)
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "预设 gf.config.basic / v1"
	dialog.dialog_text = "只更新下列预设管理值；路径、显式 Schema、索引、引用和自定义选项保持原值。\n保存前可用放弃并重载撤销。\n\n" + ("当前值与预设一致。" if changes.is_empty() else "\n".join(changes))
	dialog.ok_button_text = "应用到草稿"
	add_child(dialog)
	var _confirmed: int = dialog.confirmed.connect(func() -> void:
		if not _accept_callback(dialog, generation):
			return
		_PRESET_SCRIPT.apply_managed_values(profile)
		_changed()
		_refresh_profile()
		dialog.queue_free()
	)
	var _cancelled: int = dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(640, 340))


## 用问题 metadata 导航到项目来源文件；行列只显示真实报告值，不伪造编辑器跳转位置。
## [br]
## @api private
func _open_issue() -> void:
	var selected: TreeItem = _issues.get_selected()
	if selected == null or not Engine.is_editor_hint():
		return
	var issue: Dictionary = GFVariantData.as_dictionary(selected.get_metadata(0))
	var path: String = GFVariantData.get_option_string(issue, "source")
	if path.begins_with("res://"):
		EditorInterface.get_file_system_dock().navigate_to_path(path)
		_status.text = "已定位文件；真实位置：%s 行 / %s 列。" % [str(issue.get("line", "未知")), str(issue.get("column", "未知"))]


## 将产物条目的项目路径交给原生文件系统导航；非项目路径不在此入口打开。
## [br]
## @api private
func _open_artifact(index: int) -> void:
	var path: String = GFVariantData.to_text(_artifacts.get_item_metadata(index))
	if Engine.is_editor_hint() and path.begins_with("res://"):
		EditorInterface.get_file_system_dock().navigate_to_path(path)


## 分别呈现草稿脏状态、结果过期和恢复要求；执行按钮还必须等待后台任务回收后才开放。
## [br]
## @api private
func _refresh_status() -> void:
	var state: Dictionary = _session.get_state()
	var dirty: bool = GFVariantData.get_option_bool(state, "dirty")
	var recovering: bool = GFVariantData.get_option_bool(state, "recovery_required")
	var profile_path: String = GFVariantData.get_option_string(state, "profile_path")
	_status.text = "%s · %s · %s · %s" % [profile_path if not profile_path.is_empty() else "未保存任务", "未保存草稿" if dirty else "已保存", "结果过期" if GFVariantData.get_option_bool(state, "stale") else "结果对应当前输入", "需要文件恢复" if recovering else ("执行中" if _busy else "就绪")]
	_save_button.disabled = not _has_active_context() or _session.get_profile() == null or _busy or recovering
	var labels: Array[String] = ["校验", "预览导出", "导出"]
	for index: int in range(_run_buttons.size()):
		_run_buttons[index].text = ("保存并" if dirty else "") + labels[index]
		_run_buttons[index].disabled = not _has_active_context() or _session.get_profile() == null or _busy or _task != null or recovering


## 先解除子控件的页面树归属再排队释放，使已捕获资源的旧回调立即失去写入资格。
## [br]
## @api private
func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
