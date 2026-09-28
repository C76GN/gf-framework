@tool

# 配置工具工作区页面；页面只协调独立草稿、纯数据预览和既有执行入口。
extends VBoxContainer


# --- 常量 ---

const _SESSION_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_session.gd")
const _PRESET_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_workbench_preset.gd")
const _SCHEMA_FORM_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_schema_form.gd")
const _WORKER_SCRIPT = preload("res://addons/gf/tools/config_pipeline/editor/gf_config_preview_worker.gd")
const _TASK_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_background_request_task.gd")
const _COMMAND_SCRIPT = preload("res://addons/gf/tools/config_pipeline/gf_config_pipeline_command.gd")
const _SETTING: String = "gf/config_pipeline/default_profile_path"


# --- 私有变量 ---

var _session: _SESSION_SCRIPT = _SESSION_SCRIPT.new()
var _status: Label
var _sources: ItemList
var _source_form: VBoxContainer
var _schema_form: _SCHEMA_FORM_SCRIPT
var _profile_form: VBoxContainer
var _report: TextEdit
var _preview: Tree
var _preview_status: Label
var _issues: Tree
var _artifacts: ItemList
var _run_buttons: Array[Button] = []
var _checks: Dictionary = {}
var _save_button: Button
var _cancel_button: Button
var _task: GFEditorBackgroundRequestTask
var _generation: int = 0
var _selected_source: int = -1
var _elapsed: float = 0.0
var _busy: bool = false
var _preparing_run: bool = false
var _pending: Callable
var _after_save: Callable
var _discard_dialog: ConfirmationDialog
var _file_dialog: FileDialog
var _file_action: Callable
var _last_operation: String = "export"
var _last_options: Dictionary = { "write_manifest": true }
var _editor_context: GFEditorToolContext
var _context_generation: int = 0
var _preview_receipt: Dictionary = {}


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "ConfigWorkbench"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()


func _ready() -> void:
	var default_path: String = GFVariantData.to_text(ProjectSettings.get_setting(_SETTING, ""))
	if not default_path.is_empty():
		_load_profile(default_path)
	_refresh_status()


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

func _has_active_context() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and _editor_context != null and is_instance_valid(_editor_context.plugin) and _editor_context.plugin.is_inside_tree() and not _editor_context.plugin.is_queued_for_deletion()


func _accept_callback(control: Node, generation: int) -> bool:
	return generation == _context_generation and _has_active_context() and is_instance_valid(control) and control.is_inside_tree() and not control.is_queued_for_deletion() and is_ancestor_of(control)


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


func _page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title
	tabs.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content


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


func _choose_file(mode: FileDialog.FileMode, filter: String, action: Callable) -> void:
	if not _has_active_context():
		return
	_file_action = action
	_file_dialog.file_mode = mode
	_file_dialog.filters = PackedStringArray([filter])
	_file_dialog.popup_centered_ratio(0.7)


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


func _line(parent: Node, placeholder: String, initial: String) -> LineEdit:
	var label: Label = Label.new()
	label.text = placeholder
	parent.add_child(label)
	var field: LineEdit = LineEdit.new()
	field.text = initial
	field.placeholder_text = placeholder
	parent.add_child(field)
	return field


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


func _save_profile() -> void:
	if not _has_active_context():
		return
	var path: String = GFVariantData.get_option_string(_session.get_state(), "profile_path")
	if path.is_empty() or path.begins_with("res://.godot/"):
		_file_dialog.current_path = "res://config/build/main.tres"
		_choose_file(FileDialog.FILE_MODE_SAVE_FILE, "*.tres ; Profile", _save_to)
	else:
		_save_to(path)


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


func _changed() -> void:
	if not _has_active_context():
		return
	_session.mark_changed()
	_cancel_preview()
	_preview_status.text = "预览已过期；重新读取或校验以查看当前值。"
	_refresh_status()


func _current_source() -> GFConfigPipelineTableSource:
	var profile: GFConfigPipelineProfile = _session.get_profile()
	if profile == null or _selected_source < 0 or _selected_source >= profile.sources.size():
		return null
	return profile.sources[_selected_source]


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


func _remove_source() -> void:
	var profile: GFConfigPipelineProfile = _session.get_profile()
	if _current_source() != null:
		profile.sources.remove_at(_selected_source)
		_changed()
		_refresh_profile()


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


func _refresh_preview_freshness() -> void:
	if not _preview_receipt.is_empty() and not _receipt_matches_disk(_preview_receipt):
		_preview_receipt.clear()
		_preview_status.text = "来源已变化；当前显示的预览已过期，请重新读取。"


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


func _show_read_example() -> void:
	var profile: GFConfigPipelineProfile = _session.get_profile()
	if profile != null:
		if profile.output_path.get_extension() not in ["tres", "res"]:
			_report.text = "运行时读取示例支持 .tres/.res 数据库；JSON 导出用于项目数据交换，请在项目层读取并适配。"
			return
		_report.text = _PRESET_SCRIPT.make_read_example(profile)
		DisplayServer.clipboard_set(_report.text)
		_status.text = "读取示例已复制；把脚本附到 Label，导出配置后运行。"


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


func _open_issue() -> void:
	var selected: TreeItem = _issues.get_selected()
	if selected == null or not Engine.is_editor_hint():
		return
	var issue: Dictionary = GFVariantData.as_dictionary(selected.get_metadata(0))
	var path: String = GFVariantData.get_option_string(issue, "source")
	if path.begins_with("res://"):
		EditorInterface.get_file_system_dock().navigate_to_path(path)
		_status.text = "已定位文件；真实位置：%s 行 / %s 列。" % [str(issue.get("line", "未知")), str(issue.get("column", "未知"))]


func _open_artifact(index: int) -> void:
	var path: String = GFVariantData.to_text(_artifacts.get_item_metadata(index))
	if Engine.is_editor_hint() and path.begins_with("res://"):
		EditorInterface.get_file_system_dock().navigate_to_path(path)


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


func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
