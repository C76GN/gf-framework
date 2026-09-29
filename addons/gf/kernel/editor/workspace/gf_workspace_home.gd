@tool

# 由贡献数据驱动的任务首页；搜索不加载任务脚本。
extends VBoxContainer


# --- 常量 ---

## 通用 UI 构建器。
## [br]
## @api private
const _UI_SCRIPT = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")

## 当前项目个人偏好。
## [br]
## @api private
const _PREFERENCES_SCRIPT = preload("res://addons/gf/kernel/editor/state/gf_editor_preferences.gd")


# --- 私有变量 ---

## 当前工作区上下文。
## [br]
## @api private
var _context: GFEditorToolContext = null

## 搜索输入。
## [br]
## @api private
var _search: LineEdit = null

## 任务卡片容器。
## [br]
## @api private
var _list: VBoxContainer = null

## 最近一次操作结果。
## [br]
## @api private
var _status: Label = null

## 缓存纯数据记录，不缓存页面实例。
## [br]
## @api private
var _tasks: Array[Dictionary] = []

## 当前个人收藏 ID。
## [br]
## @api private
var _favorites: PackedStringArray = PackedStringArray()

## 当前个人最近任务 ID。
## [br]
## @api private
var _recent: PackedStringArray = PackedStringArray()


# --- Godot 生命周期方法 ---

## 构建搜索与滚动任务列表。
## [br]
## @api private
func _init() -> void:
	_UI_SCRIPT.apply_page_root(self)
	var introduction: Label = Label.new()
	introduction.text = "从一项任务开始。常用任务可收藏；需要更多控制时进入对应工具。"
	introduction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(introduction)
	_search = LineEdit.new()
	_search.name = "TaskSearch"
	_search.placeholder_text = "搜索任务、工具或关键词（Ctrl+K）"
	_search.clear_button_enabled = true
	var _search_connected: Error = _search.text_changed.connect(_on_search_changed) as Error
	add_child(_search)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_favorites = _read_ids("favorite_tasks")
	_recent = _read_ids("recent_tasks")


# --- 框架内部方法 ---

## 更新可用任务；撤销后清空入口，不保留旧回调。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
## [br]
## @param context: 本代工具上下文；null 清空任务并撤销页面的路由入口。
func set_editor_context(context: GFEditorToolContext) -> void:
	_context = context
	_tasks.clear()
	if context != null:
		_tasks = context.get_workspace_tasks()
	_rebuild()


## 将键盘焦点移动到任务搜索。
## [br]
## @api framework_internal
## [br]
## @layer kernel/editor
func focus_task_search() -> void:
	_search.grab_focus()
	_search.select_all()


# --- 私有/辅助方法 ---

## 读取有界个人 ID 列表，忽略旧版或损坏数据。
## [br]
## @api private
func _read_ids(key: String) -> PackedStringArray:
	var value: Variant = _PREFERENCES_SCRIPT.get_value(key, PackedStringArray())
	if value is PackedStringArray:
		var ids: PackedStringArray = value
		return ids.slice(0, 32)
	return PackedStringArray()


## 展示收藏、最近使用和分组任务；每个任务只出现一次。
## [br]
## @api private
func _rebuild() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var filter: String = _search.text.strip_edges().to_lower()
	var shown: Dictionary = {}
	for section: String in ["收藏", "最近使用", "全部任务"]:
		var entries: Array[Dictionary] = []
		for record: Dictionary in _tasks:
			var identity: String = str(record.get("source_id", ""))
			if shown.has(identity):
				continue
			if section == "收藏" and not _favorites.has(identity):
				continue
			if section == "最近使用" and not _recent.has(identity):
				continue
			var search_text: String = "%s %s %s %s" % [record.get("title", ""), record.get("description", ""), record.get("group", ""), record.get("keywords", [])]
			if not filter.is_empty() and not search_text.to_lower().contains(filter):
				continue
			entries.append(record)
			shown[identity] = true
		if entries.is_empty():
			continue
		if section == "最近使用":
			entries.sort_custom(_sort_recent_tasks)
		var label: Label = Label.new()
		label.text = section
		_list.add_child(label)
		for record: Dictionary in entries:
			_add_task(record)
	if shown.is_empty():
		_list.add_child(_UI_SCRIPT.make_empty_state(
			"没有匹配的任务", "清空搜索，或通过扩展页面启用所需工具。", "清空搜索", _clear_search
		))


## 构建一个可用性明确、带收藏切换的任务卡片。
## [br]
## @api private
func _add_task(record: Dictionary) -> void:
	var identity: String = str(record.get("source_id", ""))
	var row: HBoxContainer = HBoxContainer.new()
	_list.add_child(row)
	var favorite: Button = _UI_SCRIPT.make_button("★" if _favorites.has(identity) else "☆", "收藏或取消收藏此任务", _toggle_favorite.bind(identity))
	row.add_child(favorite)
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(content)
	var available: bool = record.get("available", false) == true
	var title: String = "%s · %s" % [record.get("group", "常用"), record.get("title", "")]
	if not available:
		title += "（需要启用）"
	var button: Button = _UI_SCRIPT.make_button(title, str(record.get("reason", "")), _open_task.bind(identity))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	content.add_child(button)
	var description: Label = Label.new()
	description.text = str(record.get("description", ""))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)


## 显式任务请求成功后记录有限最近任务。
## [br]
## @api private
func _open_task(identity: String) -> void:
	if _context == null:
		return
	var report: Dictionary = _context.request_workspace_task(identity)
	_status.text = str(report.get("message", ""))
	if report.get("ok", false) == true:
		var index: int = _recent.find(identity)
		if index >= 0:
			_recent.remove_at(index)
		var _inserted: int = _recent.insert(0, identity)
		_recent = _recent.slice(0, 12)
		_PREFERENCES_SCRIPT.set_value("recent_tasks", _recent)
		_rebuild()


## 更新收藏，只写个人编辑器偏好。
## [br]
## @api private
func _toggle_favorite(identity: String) -> void:
	var index: int = _favorites.find(identity)
	if index >= 0:
		_favorites.remove_at(index)
	elif _favorites.size() < 32:
		var _appended: bool = _favorites.append(identity)
	_PREFERENCES_SCRIPT.set_value("favorite_tasks", _favorites)
	_rebuild()


## 清空任务过滤文本。
## [br]
## @api private
func _clear_search() -> void:
	_search.text = ""
	_rebuild()


## 最近任务按照实际访问顺序展示。
## [br]
## @api private
func _sort_recent_tasks(left: Dictionary, right: Dictionary) -> bool:
	return _recent.find(str(left.get("source_id", ""))) < _recent.find(str(right.get("source_id", "")))


# --- 信号处理函数 ---

## 搜索仅过滤已解析的数据。
## [br]
## @api private
func _on_search_changed(_text: String) -> void:
	_rebuild()
