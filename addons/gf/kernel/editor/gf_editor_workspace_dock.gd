@tool

# GFEditorWorkspaceDock: GF 编辑器统一工作区。
#
# 把核心、标准库和启用扩展贡献的编辑器页面收束到一个响应式工作区中。
extends Control


# --- 常量 ---

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

var _about_button: Button = null
var _about_dialog: AcceptDialog = null
var _always_on_top_button: Button = null
var _latest_version_request: HTTPRequest = null
var _page_buttons: Array[Button] = []
var _page_selector: HFlowContainer = null
var _tabs: TabContainer = null
var _status_label: Label = null
var _version_check_button: Button = null
var _version_status_label: Label = null
var _dock_records: Array[Dictionary] = []


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF"
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0.0, WORKSPACE_COLLAPSED_MIN_HEIGHT)
	_build_ui()


# --- 公共方法 ---

## 设置工作区页面记录。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param dock_records: Dock 记录数组。每条记录至少包含 path，可选 label。
## [br]
## @schema dock_records: Array of Dictionary dock page records.
func setup(dock_records: Array[Dictionary]) -> void:
	_dock_records = _copy_records(dock_records)
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
			_tabs.current_tab = index
			_sync_page_buttons()
			_update_status()
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


func _rebuild_pages() -> void:
	if _tabs == null:
		return

	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()

	for record: Dictionary in _dock_records:
		var page: Control = _instantiate_page(record)
		if page == null:
			continue
		_tabs.add_child(page)

	if _tabs.get_child_count() <= 0:
		_tabs.add_child(_make_empty_page())
		_set_status(EMPTY_MESSAGE)
	else:
		_tabs.current_tab = clampi(_tabs.current_tab, 0, _tabs.get_child_count() - 1)
		_update_status()
	_rebuild_page_buttons()


func _instantiate_page(record: Dictionary) -> Control:
	var script_path: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "path", "").strip_edges()
	if script_path.is_empty():
		return null

	var dock_script: Script = _load_script(script_path)
	if dock_script == null or not dock_script.can_instantiate():
		push_error("[GF Framework] 工作区面板脚本加载失败：%s" % script_path)
		return null

	var dock_value: Variant = dock_script.call("new")
	var dock: Control = _variant_to_control(dock_value)
	if dock == null:
		push_error("[GF Framework] 工作区面板实例化失败：%s" % script_path)
		return null

	var label: String = _resolve_page_label(dock, _GF_VARIANT_ACCESS_SCRIPT.get_option_string(record, "label", ""))
	var short_label: String = _resolve_short_page_label(record, label)
	var page: Control = Control.new()
	page.name = label
	page.set_meta("short_label", short_label)
	page.clip_contents = true
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL

	dock.name = "%s Content" % label
	dock.clip_contents = true
	dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(dock)
	dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return page


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


func _resolve_page_label(dock: Control, fallback_label: String) -> String:
	if not fallback_label.is_empty():
		return fallback_label
	if dock != null and not dock.name.is_empty():
		return dock.name
	return "Panel"


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


func _copy_records(source: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for record: Dictionary in source:
		records.append(record.duplicate(true))
	return records


func _set_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message


func _sync_window_controls() -> void:
	_sync_always_on_top_button()


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


func _get_workspace_window() -> Window:
	var current: Node = self
	while current != null:
		if current is Window:
			var window: Window = current
			if window.title == WORKSPACE_TITLE:
				return window
		current = current.get_parent()
	return null


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


func _sync_page_buttons() -> void:
	if _tabs == null:
		return

	for index: int in range(_page_buttons.size()):
		_page_buttons[index].set_pressed_no_signal(index == _tabs.current_tab)


func _update_status() -> void:
	if _tabs == null or _tabs.get_child_count() <= 0:
		_set_status(EMPTY_MESSAGE)
		return

	var current_title: String = String(_tabs.get_child(_tabs.current_tab).name)
	_set_status("%d 个页面 · 当前：%s" % [_tabs.get_child_count(), current_title])


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


func _get_framework_version() -> String:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load("res://addons/gf/plugin.cfg")
	if error != OK:
		return "unknown"
	return _GF_VARIANT_ACCESS_SCRIPT.to_text(config.get_value("plugin", "version", "unknown"), "unknown").strip_edges()


func _set_version_status(message: String, color: Color = Color(0.72, 0.72, 0.72)) -> void:
	if not is_instance_valid(_version_status_label):
		return
	_version_status_label.text = message
	_version_status_label.modulate = color


func _request_latest_version() -> void:
	_ensure_latest_version_request()
	if not is_instance_valid(_latest_version_request):
		_set_version_status("无法创建版本检测请求。", Color(0.9, 0.56, 0.56))
		return

	var status: HTTPClient.Status = _latest_version_request.get_http_client_status()
	if status != HTTPClient.STATUS_DISCONNECTED:
		_set_version_status("正在检测最新版本，请稍候。")
		return

	_set_version_status("正在检测最新版本...")
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


func _ensure_latest_version_request() -> void:
	if is_instance_valid(_latest_version_request):
		return

	_latest_version_request = HTTPRequest.new()
	_latest_version_request.name = "LatestVersionRequest"
	_latest_version_request.timeout = 10.0
	_latest_version_request.use_threads = true
	var _request_completed_connected: Error = _latest_version_request.request_completed.connect(_on_latest_version_request_completed) as Error
	add_child(_latest_version_request)


func _make_latest_version_status(latest_version: String, current_version: String) -> Dictionary:
	var latest: String = _normalize_version_tag(latest_version)
	var current: String = _normalize_version_tag(current_version)
	if latest.is_empty():
		return {
			"message": "未能读取最新发布版本。",
			"color": Color(0.9, 0.56, 0.56),
		}
	if current.is_empty() or current == "unknown":
		return {
			"message": "最新发布版本：%s。当前版本未知。" % latest,
			"color": Color(0.86, 0.74, 0.45),
		}

	var compare: int = _compare_version_strings(latest, current)
	if compare > 0:
		return {
			"message": "发现新版本：%s。当前版本：%s。" % [latest, current],
			"color": Color(0.86, 0.74, 0.45),
		}
	if compare < 0:
		return {
			"message": "当前版本 %s 高于最新发布 %s。" % [current, latest],
			"color": Color(0.86, 0.74, 0.45),
		}
	return {
		"message": "当前已是最新版本：%s。" % current,
		"color": Color(0.56, 0.82, 0.56),
	}


func _compare_version_strings(left: String, right: String) -> int:
	var left_parts: PackedInt32Array = _parse_version_numbers(left)
	var right_parts: PackedInt32Array = _parse_version_numbers(right)
	for index: int in range(3):
		if left_parts[index] > right_parts[index]:
			return 1
		if left_parts[index] < right_parts[index]:
			return -1
	return 0


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


func _parse_version_numbers(value: String) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var parts: PackedStringArray = _normalize_version_tag(value).split(".")
	for index: int in range(mini(parts.size(), 3)):
		var part: String = parts[index].strip_edges()
		if part.is_valid_int():
			result[index] = part.to_int()
	return result


func _load_script(path: String) -> Script:
	var resource: Resource = load(path)
	if resource is Script:
		var script: Script = resource
		return script
	return null


func _variant_to_control(value: Variant) -> Control:
	if value is Control:
		var control: Control = value
		return control
	return null


func _get_dictionary_color(dictionary: Dictionary, key: Variant, fallback: Color) -> Color:
	var value: Variant = _GF_VARIANT_ACCESS_SCRIPT.get_option_value(dictionary, key, fallback)
	if value is Color:
		var color: Color = value
		return color
	return fallback


# --- 信号处理函数 ---

func _on_about_button_pressed() -> void:
	show_about_dialog()


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


func _on_page_button_pressed(index: int) -> void:
	if _tabs == null or index < 0 or index >= _tabs.get_child_count():
		return

	_tabs.current_tab = index
	_sync_page_buttons()
	_update_status()


func _on_tabs_tab_changed(_tab: int) -> void:
	_sync_page_buttons()
	_update_status()


func _on_about_link_clicked(meta: Variant) -> void:
	var link: String = str(meta)
	if not link.is_empty():
		var _open_error: Error = OS.shell_open(link)


func _on_about_link_button_pressed(url: String) -> void:
	if not url.is_empty():
		var _open_error: Error = OS.shell_open(url)


func _on_version_check_pressed() -> void:
	_request_latest_version()


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
		return
	if response_code < 200 or response_code >= 300:
		_set_version_status("无法检测最新版本：HTTP %d。" % response_code, Color(0.9, 0.56, 0.56))
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_set_version_status("无法检测最新版本：返回内容不是 JSON 对象。", Color(0.9, 0.56, 0.56))
		return

	var data: Dictionary = _GF_VARIANT_ACCESS_SCRIPT.as_dictionary(parsed)
	var latest_version: String = _GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "tag_name", _GF_VARIANT_ACCESS_SCRIPT.get_option_string(data, "name", ""))
	var status: Dictionary = _make_latest_version_status(latest_version, _get_framework_version())
	var status_color: Color = _get_dictionary_color(status, "color", Color(0.72, 0.72, 0.72))
	_set_version_status(_GF_VARIANT_ACCESS_SCRIPT.get_option_string(status, "message", ""), status_color)


func _on_about_confirm_pressed() -> void:
	if is_instance_valid(_about_dialog):
		_about_dialog.hide()
