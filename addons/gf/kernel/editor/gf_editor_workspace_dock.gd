@tool

# GFEditorWorkspaceDock: GF 编辑器统一工作区。
#
# 把核心、标准库和启用扩展贡献的编辑器页面收束到一个响应式工作区中。
extends Control


# --- 常量 ---

## 读取 dock 记录和 HTTP 响应中的类型化字段。
## [br]
## @api private
const _GF_VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")

## 关于弹窗尺寸。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ABOUT_DIALOG_SIZE: Vector2i = Vector2i(560, 320)

## 联系邮箱。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const CONTACT_EMAIL: String = "cl7o6dgyn@gmail.com"

## 联系 QQ。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const CONTACT_QQ: String = "403150493"

## 联系微信。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const CONTACT_WECHAT: String = "C76_GN"

## 文档地址。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const DOCUMENTATION_URL: String = "https://gf-framework.readthedocs.io/"

## 空工作区提示。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const EMPTY_MESSAGE: String = "没有可用的 GF 编辑器面板。"

## 关于文本最大高度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ABOUT_TEXT_MAX_HEIGHT: float = 150.0

## Issue 地址。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const ISSUE_URL: String = "https://github.com/C76GN/gf-framework/issues"

## 最新版本 API 地址。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const LATEST_RELEASE_API_URL: String = "https://api.github.com/repos/C76GN/gf-framework/releases/latest"

## 页面按钮最小宽度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const PAGE_BUTTON_MIN_WIDTH: float = 84.0

## 项目主页地址。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const PROJECT_URL: String = "https://github.com/C76GN/gf-framework"

## 发行版页面地址。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const RELEASES_URL: String = "https://github.com/C76GN/gf-framework/releases"

## 版本状态文本最小高度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const VERSION_STATUS_MIN_HEIGHT: float = 24.0

## 工作区折叠最小高度。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const WORKSPACE_COLLAPSED_MIN_HEIGHT: float = 72.0

## 工作区标题。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
const WORKSPACE_TITLE: String = "GF Workspace"


# --- 私有变量 ---

## 关于按钮节点。
## [br]
## @api private
var _about_button: Button = null

## 首次显示时创建并复用的介绍弹窗。
## [br]
## @api private
var _about_dialog: AcceptDialog = null

## 控制独立工作区窗口置顶状态的按钮。
## [br]
## @api private
var _always_on_top_button: Button = null

## 复用的 GitHub 最新 Release HTTP 请求节点。
## [br]
## @api private
var _latest_version_request: HTTPRequest = null

## 与 TabContainer 页索引一一对应的页面切换按钮。
## [br]
## @api private
var _page_buttons: Array[Button] = []

## 顶部响应式页面按钮容器。
## [br]
## @api private
var _page_selector: HFlowContainer = null

## 持有工作区页面和当前选中页索引的容器。
## [br]
## @api private
var _tabs: TabContainer = null

## 工作区页面数量和当前标题状态提示。
## [br]
## @api private
var _status_label: Label = null

## 关于弹窗中的版本检测按钮。
## [br]
## @api private
var _version_check_button: Button = null

## 关于弹窗中的版本检测状态标签。
## [br]
## @api private
var _version_status_label: Label = null

## 仅在检测到较新 release 时显示的更新页面按钮。
## [br]
## @api private
var _update_release_button: Button = null

## 已通过 release URL 规范化的更新链接。
## [br]
## @api private
var _latest_release_url: String = RELEASES_URL

## setup 提供并深复制的页面贡献记录。
## [br]
## @api private
var _dock_records: Array[Dictionary] = []

## 当前工作区页面使用的编辑器上下文。
## [br]
## @api private
var _editor_context: GFEditorToolContext = null

## 当前已实例化且收到上下文通知的贡献页面控件。
## [br]
## @api private
var _page_controls: Array[Control] = []

## 与占位 Tab 一一对应的待实例化页面记录。
## [br]
## @api private
var _page_records: Array[Dictionary] = []

## 本轮重建中各页面是否已尝试实例化的标记。
## [br]
## @api private
var _page_load_attempted: Array[bool] = []

## 当前是否正在销毁并重建页面占位布局。
## [br]
## @api private
var _rebuilding_pages: bool = false

## setup 或上下文回调要求在当前页面操作结束后重新应用最新配置。
## [br]
## @api private
var _rebuild_pending: bool = false

## 保护页面构造、上下文转发和选页操作期间的重建嵌套。
## [br]
## @api private
var _page_operation_depth: int = 0

## 每次上下文更换递增，用于中止已过期的页面上下文转发循环。
## [br]
## @api private
var _context_generation: int = 0


# --- Godot 生命周期方法 ---

## 设置工作区面板的尺寸与裁剪策略并建立内部界面。
## [br]
## @api private
func _init() -> void:
	name = "GF"
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0.0, WORKSPACE_COLLAPSED_MIN_HEIGHT)
	_build_ui()


## 退出树时清除编辑器上下文，让上下文设置路径负责断开关联。
## [br]
## @api private
func _exit_tree() -> void:
	set_editor_context(null)


# --- 框架内部方法 ---

## 设置工作区页面记录。显式命名的页面首次选中时创建并缓存；未命名的旧页面提前创建以保留构造器标题。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param dock_records: Dock 记录数组。每条记录至少包含 path，可选 label。
## [br]
## @param editor_context: 可选编辑器上下文；在贡献页面入树前注入。
## [br]
## @schema dock_records: Array of Dictionary dock page records.
func setup(dock_records: Array[Dictionary], editor_context: GFEditorToolContext = null) -> void:
	_dock_records = _copy_records(dock_records)
	_editor_context = editor_context
	_context_generation += 1
	_rebuild_pending = true
	_rebuild_pages()


## 更新页面上下文。只有声明 set_editor_context 方法的贡献页面会接收通知。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param editor_context: 当前上下文；null 表示编辑环境已撤销。
func set_editor_context(editor_context: GFEditorToolContext) -> void:
	_editor_context = editor_context
	_context_generation += 1
	var generation: int = _context_generation
	var page_controls: Array[Control] = _page_controls.duplicate()
	_page_operation_depth += 1
	for page_control: Control in page_controls:
		if generation != _context_generation or _rebuild_pending:
			break
		_forward_page_context(page_control, editor_context)
	_page_operation_depth -= 1
	_rebuild_pages()


## 获取工作区页面数量。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 页面数量。
func get_page_count() -> int:
	return _tabs.get_child_count() if _tabs != null else 0


## 获取页面标题列表。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 页面标题。
func get_page_titles() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	if _tabs == null:
		return result
	for index: int in range(_tabs.get_child_count()):
		var _title_appended: bool = result.append(String(_tabs.get_child(index).name))
	return result


## 获取响应式页面按钮标题列表。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 页面按钮标题。
func get_page_button_titles() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for button: Button in _page_buttons:
		var _title_appended: bool = result.append(button.text)
	return result


## 获取框架介绍弹窗文本。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @return 关于弹窗文本。
func get_about_text() -> String:
	return _make_about_text()


## 激活指定页面。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param title: 页面标题。
## [br]
## @return 找到并激活返回 true。
func select_page(title: String) -> bool:
	if _tabs == null:
		return false
	for index: int in range(_tabs.get_child_count()):
		if _tabs.get_child(index).name == title:
			_on_page_button_pressed(index)
			return true
	return false


## 显示 GF Framework 介绍和链接弹窗。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func show_about_dialog() -> void:
	_ensure_about_dialog()
	if is_inside_tree():
		_about_dialog.mode = Window.MODE_WINDOWED
		_about_dialog.min_size = ABOUT_DIALOG_SIZE
		_about_dialog.max_size = ABOUT_DIALOG_SIZE
		_about_dialog.reset_size()
		_about_dialog.popup_centered(ABOUT_DIALOG_SIZE)
		_about_dialog.size = ABOUT_DIALOG_SIZE


# --- 私有/辅助方法 ---

## 只在尚未创建时搭建工作区基础布局并连接顶部控件信号。
## [br]
## @api private
func _build_ui() -> void:
	if _tabs != null:
		return

	var margin: MarginContainer = MarginContainer.new()
	margin.clip_contents = true
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)

	var header: HBoxContainer = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	_page_selector = HFlowContainer.new()
	_page_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_selector.add_theme_constant_override("h_separation", 6)
	_page_selector.add_theme_constant_override("v_separation", 4)
	header.add_child(_page_selector)

	_status_label = Label.new()
	_status_label.modulate = Color(0.72, 0.72, 0.72)
	_status_label.visible = false
	header.add_child(_status_label)

	_about_button = Button.new()
	_about_button.text = "关于"
	_about_button.tooltip_text = "查看 GF Framework 介绍、项目链接、文档地址和版本信息。"
	var _about_pressed_connected: Error = _about_button.pressed.connect(_on_about_button_pressed) as Error
	header.add_child(_about_button)

	_always_on_top_button = Button.new()
	_always_on_top_button.text = "置顶"
	_always_on_top_button.toggle_mode = true
	_always_on_top_button.focus_mode = Control.FOCUS_NONE
	_always_on_top_button.tooltip_text = "让 GF Workspace 独立窗口保持在其他窗口上方。"
	var _always_on_top_connected: Error = _always_on_top_button.toggled.connect(_on_always_on_top_toggled) as Error
	header.add_child(_always_on_top_button)

	_tabs = TabContainer.new()
	_tabs.clip_contents = true
	_tabs.tabs_visible = false
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _tab_changed_connected: Error = _tabs.tab_changed.connect(_on_tabs_tab_changed) as Error
	layout.add_child(_tabs)


## 在没有活动页面操作时应用待处理配置，先清空旧页面上下文再重建占位 Tab。
## 未提供 label 的旧记录和当前选中页会实例化；重入请求由 `_rebuild_pending` 在本轮结束后续跑。
## [br]
## @api private
func _rebuild_pages() -> void:
	if _tabs == null or _page_operation_depth > 0:
		return

	# 用户页面的上下文、入树和离树回调都可能重新 setup；等当前操作结束后只应用最新配置。
	while _rebuild_pending:
		_rebuild_pending = false
		_page_operation_depth += 1
		_rebuilding_pages = true
		var old_controls: Array[Control] = _page_controls
		_page_controls = []
		_page_records.clear()
		_page_load_attempted.clear()
		for page_control: Control in old_controls:
			_forward_page_context(page_control, null)
		for child: Node in _tabs.get_children():
			_tabs.remove_child(child)
			child.queue_free()

		if not _rebuild_pending:
			for record: Dictionary in _dock_records:
				var script_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "path", "").strip_edges()
				if script_path.is_empty():
					continue
				var page: Control = _make_page(record, script_path)
				_page_records.append(record)
				_page_load_attempted.append(false)
				_tabs.add_child(page)
			if _tabs.get_child_count() == 0:
				_tabs.add_child(_make_empty_page())
			else:
				_tabs.current_tab = clampi(_tabs.current_tab, 0, _tabs.get_child_count() - 1)
		_rebuilding_pages = false

		if not _rebuild_pending:
			# 旧记录未提供 label 时，必须实例化才能取得原有的 dock.name，保持按标题选页兼容。
			for index: int in range(_page_records.size()):
				if _rebuild_pending:
					break
				if _GF_VARIANT_ACCESS_SCRIPT.get_option_string(_page_records[index], "label", "").is_empty():
					_ensure_page(index)
			_ensure_page(_tabs.current_tab)
		if not _rebuild_pending:
			_update_status()
			_rebuild_page_buttons()
		_page_operation_depth -= 1


## 为贡献记录创建尚未加载内容的占位 Control，并确定长标题与短标题 metadata。
## [br]
## @api private
func _make_page(record: Dictionary, script_path: String) -> Control:
	var label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "label", "")
	if label.is_empty():
		label = script_path.get_file().get_basename()
	var page: Control = Control.new()
	page.name = label
	page.set_meta("short_label", _resolve_short_page_label(record, label))
	page.clip_contents = true
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return page


## 仅在页面可加载、未加载且不处于重建中时实例化指定页，然后处理排队重建。
## [br]
## @api private
func _ensure_page(index: int) -> void:
	if _rebuilding_pages or _rebuild_pending or _tabs == null:
		return
	if index < 0 or index >= _page_records.size() or _page_load_attempted[index]:
		return
	_page_operation_depth += 1
	_create_page(index)
	_page_operation_depth -= 1
	_rebuild_pages()


## 先标记页面已尝试，再构造并注入上下文；配置重入时移除刚创建页面。
## 加载失败时在占位页显示错误，成功时同步标题、内容控件和对应按钮。
## [br]
## @api private
func _create_page(index: int) -> void:
	# 在用户页面构造前标记，避免入树或上下文回调重入时重复实例化。
	_page_load_attempted[index] = true
	var page: Control = _tabs.get_tab_control(index)
	var record: Dictionary = _page_records[index]
	var dock: Control = _instantiate_page(record)
	if dock != null:
		_page_controls.append(dock)
		_forward_page_context(dock, _editor_context)
	if _rebuild_pending:
		if dock != null:
			_page_controls.erase(dock)
			_forward_page_context(dock, null)
			dock.queue_free()
		return
	if dock == null:
		var failure_label: Label = Label.new()
		failure_label.text = "此页面加载失败，请检查 Godot 错误面板。修复后重新加载 GF 插件。"
		failure_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(failure_label)
		failure_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return

	var label: String = _resolve_page_label(dock, _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "label", ""))
	page.name = label
	page.set_meta("short_label", _resolve_short_page_label(record, label))
	dock.name = "%s Content" % label
	dock.clip_contents = true
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(dock)
	if _rebuild_pending:
		return
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if index < _page_buttons.size():
		_page_buttons[index].text = _resolve_short_page_label(record, label)
		_page_buttons[index].tooltip_text = "切换到 %s" % page.name


## 加载贡献脚本并确认其可实例化且继承 Control，再调用 new 创建页面。
## 任一路径、脚本、基类或实例类型检查失败时返回 null。
## [br]
## @api private
func _instantiate_page(record: Dictionary) -> Control:
	var script_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "path", "").strip_edges()
	if script_path.is_empty():
		return null

	var dock_script: Script = _load_script(script_path)
	if dock_script == null or not dock_script.can_instantiate():
		push_error("[GFEditorWorkspaceDock][editor_workspace_dock.panel_load_failed] Could not load the workspace panel script: %s." % script_path)
		return null

	if not ClassDB.is_parent_class(dock_script.get_instance_base_type(), "Control"):
		push_error("[GFEditorWorkspaceDock][editor_workspace_dock.panel_instantiation_failed] Could not instantiate the workspace panel: %s." % script_path)
		return null

	var dock_value: Variant = dock_script.call("new")
	var dock: Control = _variant_to_control(dock_value)
	if dock == null:
		push_error("[GFEditorWorkspaceDock][editor_workspace_dock.panel_instantiation_failed] Could not instantiate the workspace panel: %s." % script_path)
		return null

	return dock


## 仅对仍有效且实现 set_editor_context 的页面控件转发当前上下文。
## [br]
## @api private
func _forward_page_context(page_control: Control, editor_context: GFEditorToolContext) -> void:
	if is_instance_valid(page_control) and page_control.has_method("set_editor_context"):
		var _context_result: Variant = page_control.call("set_editor_context", editor_context)


## 创建仅含 EMPTY_MESSAGE 的概览页，用于没有有效页面记录的工作区。
## [br]
## @api private
func _make_empty_page() -> Control:
	var page: CenterContainer = CenterContainer.new()
	page.name = "概览"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var label: Label = Label.new()
	label.text = EMPTY_MESSAGE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	page.add_child(label)
	return page


## 优先使用非空 fallback_label，其次使用 dock.name，最后返回 `Panel`。
## [br]
## @api private
func _resolve_page_label(dock: Control, fallback_label: String) -> String:
	if not fallback_label.is_empty():
		return fallback_label
	if dock != null and not dock.name.is_empty():
		return dock.name
	return "Panel"


## 优先采用记录中的 short_label，否则移除 `GF ` 前缀并映射已知长标题。
## 未命中映射时返回处理后的完整标题。
## [br]
## @api private
func _resolve_short_page_label(record: Dictionary, label: String) -> String:
	var explicit_label: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "short_label", "").strip_edges()
	if not explicit_label.is_empty():
		return explicit_label

	var result: String = label.strip_edges()
	if result.begins_with("GF "):
		result = result.substr(3)
	match result:
		"State Tools":
			return "状态"
		"Input Mapping":
			return "输入"
		"Storage Viewer":
			return "存储"
		"Save Viewer":
			return "存储"
		"Signal Graph":
			return "信号诊断"
		"Signal Diagnostics":
			return "信号诊断"
		"Diagnostics":
			return "诊断"
		"Extensions":
			return "扩展"
		"Flow":
			return "流程"
		"Save":
			return "保存"
		"Flow Tools":
			return "流程"
	return result


## 对每条 dock 记录执行深复制，隔离 setup 输入数组中的字典与嵌套数据。
## [br]
## @api private
func _copy_records(source: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record: Dictionary in source:
		records.append(record.duplicate(true))
	return records


## 仅在状态标签节点仍有效时更新其文字。
## [br]
## @api private
func _set_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message


## 将窗口置顶状态同步到对应按钮。
## [br]
## @api private
func _sync_window_controls() -> void:
	_sync_always_on_top_button()


## 按工作区是否处于独立 Window 更新置顶按钮可用性、选中态和提示。
## [br]
## @api private
func _sync_always_on_top_button() -> void:
	if not is_instance_valid(_always_on_top_button):
		return

	var window: Window = _get_workspace_window()
	var available: bool = window != null
	_always_on_top_button.disabled = not available
	_always_on_top_button.set_pressed_no_signal(available and window.always_on_top)
	if available:
		_always_on_top_button.tooltip_text = "让 GF Workspace 独立窗口保持在其他窗口上方。"
	else:
		_always_on_top_button.tooltip_text = "当前工作区没有运行在独立窗口中，无法置顶。"


## 沿祖先链查找标题等于 WORKSPACE_TITLE 的 Window；未找到时返回 null。
## [br]
## @api private
func _get_workspace_window() -> Window:
	var current: Node = self
	while current != null:
		if current is Window:
			var window: Window = current
			if window.title == WORKSPACE_TITLE:
				return window
		current = current.get_parent()
	return null


## 销毁旧页面按钮并按当前 Tab 顺序重建按钮、短标题、提示和索引绑定。
## [br]
## @api private
func _rebuild_page_buttons() -> void:
	if _page_selector == null or _tabs == null:
		return

	for child: Node in _page_selector.get_children():
		_page_selector.remove_child(child)
		child.queue_free()
	_page_buttons.clear()

	for index: int in range(_tabs.get_child_count()):
		var page: Node = _tabs.get_child(index)
		var button: Button = Button.new()
		button.text = _GF_VARIANT_ACCESS_SCRIPT.to_text(page.get_meta("short_label", page.name), String(page.name))
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "切换到 %s" % page.name
		button.custom_minimum_size = Vector2(PAGE_BUTTON_MIN_WIDTH, 30.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var _page_button_connected: Error = button.pressed.connect(_on_page_button_pressed.bind(index)) as Error
		_page_selector.add_child(button)
		_page_buttons.append(button)
	_sync_page_buttons()


## 依据 TabContainer.current_tab 无信号地同步全部页面按钮选中态。
## [br]
## @api private
func _sync_page_buttons() -> void:
	if _tabs == null:
		return

	for index: int in range(_page_buttons.size()):
		_page_buttons[index].set_pressed_no_signal(index == _tabs.current_tab)


## 显示空工作区提示，或显示页面总数和当前页标题。
## [br]
## @api private
func _update_status() -> void:
	if _tabs == null or _tabs.get_child_count() <= 0:
		_set_status(EMPTY_MESSAGE)
		return

	var current_title: String = String(_tabs.get_child(_tabs.current_tab).name)
	_set_status("%d 个页面 · 当前：%s" % [_tabs.get_child_count(), current_title])


## 懒创建并复用固定尺寸的关于弹窗，隐藏默认确认按钮并填入自定义内容。
## [br]
## @api private
func _ensure_about_dialog() -> void:
	if is_instance_valid(_about_dialog):
		return

	_about_dialog = AcceptDialog.new()
	_about_dialog.title = "关于 GF Framework"
	_about_dialog.min_size = ABOUT_DIALOG_SIZE
	_about_dialog.max_size = ABOUT_DIALOG_SIZE
	_about_dialog.unresizable = true
	_about_dialog.wrap_controls = false
	add_child(_about_dialog)
	_about_dialog.add_child(_make_about_content())
	_about_dialog.get_ok_button().visible = false


## 生成包含当前框架版本、项目链接与联系方式的纯文本介绍。
## [br]
## @api private
func _make_about_text() -> String:
	return "\n".join([
		"GF Framework",
		"版本：%s" % _get_framework_version(),
		"",
		"面向 Godot 4 的轻量级游戏架构框架。",
		"它把数据、逻辑、表现、运行时服务和纯算法基础件拆开管理，帮助项目保持可预测的生命周期、清晰的依赖边界和可测试的玩法代码。",
		"",
		"项目地址：%s" % PROJECT_URL,
		"文档地址：%s" % DOCUMENTATION_URL,
		"Issues：%s" % ISSUE_URL,
		"Releases：%s" % RELEASES_URL,
		"",
		"联系方式：",
		"E-mail：%s" % CONTACT_EMAIL,
		"WeChat：%s" % CONTACT_WECHAT,
		"QQ：%s" % CONTACT_QQ,
	])


## 构建关于弹窗的滚动介绍、项目链接、版本检测/更新按钮和自定义确认按钮。
## [br]
## @api private
func _make_about_content() -> Control:
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "AboutContent"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)

	var layout: VBoxContainer = VBoxContainer.new()
	layout.name = "AboutLayout"
	layout.alignment = BoxContainer.ALIGNMENT_BEGIN
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "AboutScroll"
	scroll.custom_minimum_size = Vector2(0.0, ABOUT_TEXT_MAX_HEIGHT)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	layout.add_child(scroll)

	var text: RichTextLabel = RichTextLabel.new()
	text.name = "AboutText"
	text.bbcode_enabled = true
	text.fit_content = false
	text.scroll_active = false
	text.selection_enabled = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.text = _make_about_bbcode()
	var _about_meta_connected: Error = text.meta_clicked.connect(_on_about_link_clicked) as Error
	scroll.add_child(text)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.name = "AboutActionRow"
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 8)
	layout.add_child(action_row)

	var issues_button: Button = Button.new()
	issues_button.name = "AboutIssuesButton"
	issues_button.text = "Issues"
	issues_button.tooltip_text = "打开 GF Framework Issues 页面。"
	var _issues_connected: Error = issues_button.pressed.connect(_on_about_link_button_pressed.bind(ISSUE_URL)) as Error
	action_row.add_child(issues_button)

	var releases_button: Button = Button.new()
	releases_button.name = "AboutReleasesButton"
	releases_button.text = "Releases"
	releases_button.tooltip_text = "打开 GF Framework Releases 页面。"
	var _releases_connected: Error = releases_button.pressed.connect(_on_about_link_button_pressed.bind(RELEASES_URL)) as Error
	action_row.add_child(releases_button)

	_version_check_button = Button.new()
	_version_check_button.name = "AboutVersionCheckButton"
	_version_check_button.text = "检测最新版本"
	_version_check_button.tooltip_text = "从 GitHub Releases 检测当前 GF Framework 是否为最新发布版本。"
	var _version_check_connected: Error = _version_check_button.pressed.connect(_on_version_check_pressed) as Error
	action_row.add_child(_version_check_button)

	_update_release_button = Button.new()
	_update_release_button.name = "AboutUpdateReleaseButton"
	_update_release_button.text = "打开更新页面"
	_update_release_button.tooltip_text = "打开检测到的新版本 Release 页面，由维护者按项目状态手动更新。"
	_update_release_button.visible = false
	var _update_release_connected: Error = _update_release_button.pressed.connect(_on_update_release_pressed) as Error
	action_row.add_child(_update_release_button)

	_version_status_label = Label.new()
	_version_status_label.name = "AboutVersionStatus"
	_version_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_version_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
	_version_status_label.custom_minimum_size = Vector2(0.0, VERSION_STATUS_MIN_HEIGHT)
	_version_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_version_status_label.modulate = Color(0.72, 0.72, 0.72)
	_version_status_label.text = "当前版本：%s。可手动检测最新发布版本。" % _get_framework_version()
	layout.add_child(_version_status_label)

	var confirm_center: CenterContainer = CenterContainer.new()
	confirm_center.name = "AboutConfirmCenter"
	confirm_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(confirm_center)

	var confirm_button: Button = Button.new()
	confirm_button.name = "AboutConfirmButton"
	confirm_button.text = "确定"
	confirm_button.custom_minimum_size = Vector2(96.0, 0.0)
	var _confirm_connected: Error = confirm_button.pressed.connect(_on_about_confirm_pressed) as Error
	confirm_center.add_child(confirm_button)
	return margin


## 生成带项目、文档、Issues、Releases 和邮箱链接的居中 BBCode 介绍文本。
## [br]
## @api private
func _make_about_bbcode() -> String:
	return "\n".join([
		"[center][b]GF Framework[/b] · 版本：%s" % _get_framework_version(),
		"面向 Godot 4 的轻量级游戏架构框架。",
		"[url=%s]GitHub[/url] · [url=%s]文档[/url] · [url=%s]Issues[/url] · [url=%s]Releases[/url]" % [
			PROJECT_URL,
			DOCUMENTATION_URL,
			ISSUE_URL,
			RELEASES_URL,
		],
		"E-mail：[url=mailto:%s]%s[/url]" % [CONTACT_EMAIL, CONTACT_EMAIL],
		"WeChat：%s · QQ：%s[/center]" % [CONTACT_WECHAT, CONTACT_QQ],
	])


## 从 res://addons/gf/plugin.cfg 读取 plugin.version；配置读取失败时返回 `unknown`。
## [br]
## @api private
func _get_framework_version() -> String:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load("res://addons/gf/plugin.cfg")
	if error != OK:
		return "unknown"
	return _GF_VARIANT_ACCESS_SCRIPT.to_text(config.get_value("plugin", "version", "unknown"), "unknown").strip_edges()


## 标签节点仍有效时同步版本状态文字和颜色。
## [br]
## @api private
func _set_version_status(message: String, color: Color = Color(0.72, 0.72, 0.72)) -> void:
	if not is_instance_valid(_version_status_label):
		return
	_version_status_label.text = message
	_version_status_label.modulate = color


## 确保请求节点存在后发起 GitHub latest-release GET；请求繁忙时只更新等待提示。
## 请求无法创建或启动失败时恢复按钮并隐藏更新入口。
## [br]
## @api private
func _request_latest_version() -> void:
	_ensure_latest_version_request()
	if not is_instance_valid(_latest_version_request):
		_set_version_status("无法创建版本检测请求。", Color(0.9, 0.56, 0.56))
		_set_update_release_button(false)
		return

	var status: HTTPClient.Status = _latest_version_request.get_http_client_status()
	if status != HTTPClient.STATUS_DISCONNECTED:
		_set_version_status("正在检测最新版本，请稍候。")
		return

	_set_version_status("正在检测最新版本...")
	_set_update_release_button(false)
	if is_instance_valid(_version_check_button):
		_version_check_button.disabled = true

	var headers: PackedStringArray = PackedStringArray([
		"Accept: application/vnd.github+json",
		"User-Agent: GF-Framework-Godot-Editor",
	])
	var error: Error = _latest_version_request.request(
		LATEST_RELEASE_API_URL,
		headers,
		HTTPClient.METHOD_GET
	)
	if error != OK:
		if is_instance_valid(_version_check_button):
			_version_check_button.disabled = false
		_set_version_status("无法发起版本检测：%s。" % error_string(error), Color(0.9, 0.56, 0.56))
		_set_update_release_button(false)


## 懒创建十秒超时、启用线程请求的 HTTPRequest，并连接完成信号。
## [br]
## @api private
func _ensure_latest_version_request() -> void:
	if is_instance_valid(_latest_version_request):
		return

	_latest_version_request = HTTPRequest.new()
	_latest_version_request.name = "LatestVersionRequest"
	_latest_version_request.timeout = 10.0
	_latest_version_request.use_threads = true
	var _request_completed_connected: Error = _latest_version_request.request_completed.connect(_on_latest_version_request_completed) as Error
	add_child(_latest_version_request)


## 规范化最新与当前版本后生成提示、颜色、是否有更新和受限 release URL。
## 版本比较仅使用前三个数字分量；空最新版本和未知当前版本有独立提示。
## [br]
## @api private
func _make_latest_version_status(latest_version: String, current_version: String, release_url: String = RELEASES_URL) -> Dictionary:
	var latest: String = _normalize_version_tag(latest_version)
	var current: String = _normalize_version_tag(current_version)
	if latest.is_empty():
		return {
			"message": "未能读取最新发布版本。",
			"color": Color(0.9, 0.56, 0.56),
			"update_available": false,
			"release_url": "",
		}
	if current.is_empty() or current == "unknown":
		return {
			"message": "最新发布版本：%s。当前版本未知。" % latest,
			"color": Color(0.86, 0.74, 0.45),
			"update_available": false,
			"release_url": _normalize_release_url(release_url),
		}

	var compare: int = _compare_version_strings(latest, current)
	if compare > 0:
		return {
			"message": "发现新版本：%s。当前版本：%s。" % [latest, current],
			"color": Color(0.86, 0.74, 0.45),
			"update_available": true,
			"release_url": _normalize_release_url(release_url),
		}
	if compare < 0:
		return {
			"message": "当前版本 %s 高于最新发布 %s。" % [current, latest],
			"color": Color(0.86, 0.74, 0.45),
			"update_available": false,
			"release_url": _normalize_release_url(release_url),
		}
	return {
		"message": "当前已是最新版本：%s。" % current,
		"color": Color(0.56, 0.82, 0.56),
		"update_available": false,
		"release_url": _normalize_release_url(release_url),
	}


## 逐项比较规范化后的前三个整数版本分量，返回 1、-1 或 0。
## [br]
## @api private
func _compare_version_strings(left: String, right: String) -> int:
	var left_parts: PackedInt32Array = _parse_version_numbers(left)
	var right_parts: PackedInt32Array = _parse_version_numbers(right)
	for index: int in range(3):
		if left_parts[index] > right_parts[index]:
			return 1
		if left_parts[index] < right_parts[index]:
			return -1
	return 0


## 去除版本标签首尾空白、refs/tags/ 和数字前的 v，并丢弃 build/prerelease 后缀。
## [br]
## @api private
func _normalize_version_tag(value: String) -> String:
	var text: String = value.strip_edges()
	if text.begins_with("refs/tags/"):
		text = text.trim_prefix("refs/tags/")
	if text.length() > 1 and text.substr(0, 1).to_lower() == "v" and text.substr(1, 1).is_valid_int():
		text = text.substr(1)
	if text.find("+") >= 0:
		text = text.split("+", false, 1)[0]
	if text.find("-") >= 0:
		text = text.split("-", false, 1)[0]
	return text.strip_edges()


## 只保留官方 Releases 根 URL 或其子路径；空值及其他地址回退到根 URL。
## [br]
## @api private
func _normalize_release_url(value: String) -> String:
	var text: String = value.strip_edges()
	if text.is_empty():
		return RELEASES_URL
	if text == RELEASES_URL or text.begins_with("%s/" % RELEASES_URL):
		return text
	return RELEASES_URL


## 解析规范化版本的前三个整数分量；缺失或非整数分量保留为零。
## [br]
## @api private
func _parse_version_numbers(value: String) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var parts: PackedStringArray = _normalize_version_tag(value).split(".")
	for index: int in range(mini(parts.size(), 3)):
		var part: String = parts[index].strip_edges()
		if part.is_valid_int():
			result[index] = part.to_int()
	return result


## 加载资源并仅在其为 Script 时返回，否则返回 null。
## [br]
## @api private
func _load_script(path: String) -> Script:
	var resource: Resource = load(path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


## 仅当 Variant 为 Control 时返回强类型控件值，否则返回 null。
## [br]
## @api private
func _variant_to_control(value: Variant) -> Control:
	if value is Control:
		var control: Control = value
		return control
	return null


## 从字典读取指定值，仅在值为 Color 时返回，否则使用 fallback。
## [br]
## @api private
func _get_dictionary_color(dictionary: Dictionary, key: Variant, fallback: Color) -> Color:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(dictionary, key, fallback)
	if value is Color:
		var color: Color = value
		return color
	return fallback


## 将版本状态字典中的 message、color、update_available 和 release_url 应用到界面。
## release_url 仍经过官方路径限制。
## [br]
## @api private
func _apply_latest_version_status(status: Dictionary) -> void:
	var status_color: Color = _get_dictionary_color(status, "color", Color(0.72, 0.72, 0.72))
	_set_version_status(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(status, "message", ""), status_color)
	_set_update_release_button(
		_GF_VARIANT_ACCESS_SCRIPT.get_option_bool(status, "update_available"),
		_GF_VARIANT_ACCESS_SCRIPT.get_option_string(status, "release_url", RELEASES_URL)
	)


## 先规范化并保存 release URL，再在按钮有效时同步显示和禁用状态。
## [br]
## @api private
func _set_update_release_button(should_show: bool, release_url: String = "") -> void:
	_latest_release_url = _normalize_release_url(release_url)
	if not is_instance_valid(_update_release_button):
		return
	_update_release_button.visible = should_show
	_update_release_button.disabled = not should_show


# --- 信号处理函数 ---

## 响应关于按钮并显示介绍弹窗。
## [br]
## @api private
func _on_about_button_pressed() -> void:
	show_about_dialog()


## 切换当前工作区窗口置顶状态；优先调用窗口自定义方法，否则直接更新 Window 属性。
## [br]
## @api private
func _on_always_on_top_toggled(enabled: bool) -> void:
	var window: Window = _get_workspace_window()
	if window == null:
		_sync_always_on_top_button()
		return

	if window.has_method("set_always_on_top_enabled"):
		var _set_on_top_result: Variant = window.call("set_always_on_top_enabled", enabled)
	else:
		if enabled:
			window.transient = false
			window.exclusive = false
		window.always_on_top = enabled
	_sync_always_on_top_button()


## 校验页面索引后选中 Tab、按需实例化页面，并刷新按钮和状态标签。
## 页面操作期间提高嵌套深度，返回后再处理排队重建。
## [br]
## @api private
func _on_page_button_pressed(index: int) -> void:
	if _tabs == null or index < 0 or index >= _tabs.get_child_count():
		return

	_page_operation_depth += 1
	_tabs.current_tab = index
	_ensure_page(index)
	_page_operation_depth -= 1
	_rebuild_pages()
	_sync_page_buttons()
	_update_status()


## 非页面重建期间，按需实例化新选中页并同步按钮与状态标签。
## [br]
## @api private
func _on_tabs_tab_changed(tab: int) -> void:
	if _rebuilding_pages:
		return
	_ensure_page(tab)
	_sync_page_buttons()
	_update_status()


## 将 BBCode meta 转为文本，仅对非空链接请求系统打开。
## [br]
## @api private
func _on_about_link_clicked(meta: Variant) -> void:
	var link: String = str(meta)
	if not link.is_empty():
		var _open_error: Error = OS.shell_open(link)


## 非空链接按钮参数交由系统打开。
## [br]
## @api private
func _on_about_link_button_pressed(url: String) -> void:
	if not url.is_empty():
		var _open_error: Error = OS.shell_open(url)


## 规范化最近保存的更新 URL 后请求系统打开。
## [br]
## @api private
func _on_update_release_pressed() -> void:
	var release_url: String = _normalize_release_url(_latest_release_url)
	var _open_error: Error = OS.shell_open(release_url)


## 响应版本检测按钮并发起 latest-release 请求。
## [br]
## @api private
func _on_version_check_pressed() -> void:
	_request_latest_version()


## 恢复检测按钮状态，校验网络结果、HTTP 状态与 JSON 对象后应用版本报告。
## 任一响应校验失败都会显示错误并隐藏更新按钮。
## [br]
## @api private
func _on_latest_version_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if is_instance_valid(_version_check_button):
		_version_check_button.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_set_version_status("无法检测最新版本：网络请求失败。", Color(0.9, 0.56, 0.56))
		_set_update_release_button(false)
		return
	if response_code < 200 or response_code >= 300:
		_set_version_status("无法检测最新版本：HTTP %d。" % response_code, Color(0.9, 0.56, 0.56))
		_set_update_release_button(false)
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_set_version_status("无法检测最新版本：返回内容不是 JSON 对象。", Color(0.9, 0.56, 0.56))
		_set_update_release_button(false)
		return

	var data: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(parsed)
	var latest_version: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "tag_name", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "name", ""))
	var release_url: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "html_url", RELEASES_URL)
	var status: Dictionary = _make_latest_version_status(latest_version, _get_framework_version(), release_url)
	_apply_latest_version_status(status)


## 关于弹窗仍有效时隐藏弹窗。
## [br]
## @api private
func _on_about_confirm_pressed() -> void:
	if is_instance_valid(_about_dialog):
		_about_dialog.hide()
