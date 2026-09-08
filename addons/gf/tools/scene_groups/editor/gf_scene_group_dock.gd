@tool

## GFSceneGroupDock: 编辑器期已保存场景 Group 声明查询页面。
##
## 用户主动刷新后分批读取磁盘场景，按组名、场景路径或节点路径搜索并定位声明节点。
## 只读查询不包含未保存编辑或运行时添加的组；定位通过编辑器打开源场景。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since unreleased
class_name GFSceneGroupDock
extends VBoxContainer


# --- 常量 ---

const _INDEX_SCRIPT = preload("res://addons/gf/tools/scene_groups/gf_scene_group_index.gd")
const _WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")
const _VARIANT_ACCESS_SCRIPT = preload("res://addons/gf/kernel/core/gf_variant_access.gd")
const _PAGE_SIZE: int = 100
const _ENTRIES_PER_FRAME: int = 64
const _LOCATION_TIMEOUT_MSEC: int = 5000


# --- 私有变量 ---

var _index: GFSceneGroupIndex = _INDEX_SCRIPT.new()
var _scan_root: LineEdit
var _search: LineEdit
var _refresh_button: Button
var _cancel_button: Button
var _results: Tree
var _previous_button: Button
var _next_button: Button
var _summary: Label
var _page_summary: Label
var _issues: TextEdit
var _location_status: Label
var _offset: int = 0
var _scanning: bool = false
var _summary_elapsed: float = 0.0
var _pending_location: Dictionary = {}
var _location_deadline: int = 0


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GFSceneGroupDock"
	_WORKSPACE_UI.apply_page_root(self)
	_build_ui()
	_render_summary()
	_render_page()
	set_process(false)


func _ready() -> void:
	set_process(_scanning or not _pending_location.is_empty())


func _process(delta: float) -> void:
	if _scanning:
		_scanning = _index.advance(_ENTRIES_PER_FRAME)
		_summary_elapsed += delta
		if not _scanning or _summary_elapsed >= 0.15:
			_summary_elapsed = 0.0
			_render_summary()
		if not _scanning:
			_render_page()
	if not _pending_location.is_empty():
		_advance_location()
	set_process(_scanning or not _pending_location.is_empty())


func _exit_tree() -> void:
	cancel_scan()


# --- 公共方法 ---

## 清除旧结果并开始扫描指定项目目录；页面入树后按帧推进。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param root_path: res:// 下的已保存场景搜索根目录。
## [br]
## @return 初始化扫描的 Error；无效输入会呈现 failed 状态。
func refresh(root_path: String = "res://") -> Error:
	_pending_location.clear()
	_location_status.text = ""
	_offset = 0
	_scan_root.text = root_path
	var scan_error: Error = _index.begin_scan(root_path)
	_scanning = _status() == "scanning"
	_summary_elapsed = 0.0
	_render_summary()
	_render_page()
	set_process(_scanning)
	return scan_error


## 取消当前扫描和待完成定位；保留已收集结果，并明确标记取消状态。
## [br]
## @api public
## [br]
## @since unreleased
func cancel_scan() -> void:
	_index.cancel()
	_scanning = false
	_pending_location.clear()
	_render_summary()
	_render_page()
	set_process(false)


## 获取扫描摘要的防御性副本；结果行通过页面分页呈现。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 与 GFSceneGroupIndex.get_snapshot() 相同的摘要。
## [br]
## @schema return: Dictionary，status 为 idle/scanning/complete/partial/cancelled/failed；root_path 为 String；entry_count、scene_count、row_count、omitted_issue_count 为 int；issues 为 Array[Dictionary]，每项含 String 字段 code、path、message。
func get_snapshot() -> Dictionary:
	return _index.get_snapshot()


# --- 私有/辅助方法 ---

func _build_ui() -> void:
	add_child(_WORKSPACE_UI.make_summary_label(
		"查询已保存的 Group 声明；不包含未保存编辑或运行时变更。继承的声明在源场景显示。"
	))
	var toolbar: HBoxContainer = _WORKSPACE_UI.make_toolbar()
	add_child(toolbar)
	_scan_root = LineEdit.new()
	_scan_root.name = "ScanRoot"
	_scan_root.text = "res://"
	_scan_root.placeholder_text = "场景根目录，例如 res://scenes"
	_scan_root.tooltip_text = "扫描此目录下的 .tscn 和 .scn；跳过隐藏目录及 .gdignore 目录。"
	_scan_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_scan_root)
	_refresh_button = _WORKSPACE_UI.make_button("刷新", "重新读取磁盘中的场景", _on_refresh_pressed)
	_refresh_button.name = "Refresh"
	toolbar.add_child(_refresh_button)
	_cancel_button = _WORKSPACE_UI.make_button("取消", "停止后续扫描", cancel_scan)
	_cancel_button.name = "Cancel"
	toolbar.add_child(_cancel_button)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "搜索组、场景或节点路径"
	_search.tooltip_text = "不区分大小写的文本搜索；组名本身仍保留大小写。"
	var _search_result: int = _search.text_changed.connect(_on_search_text_changed)
	add_child(_search)
	_summary = _WORKSPACE_UI.make_summary_label()
	_summary.name = "Summary"
	add_child(_summary)
	_results = Tree.new()
	_results.name = "Results"
	_results.columns = 3
	_results.hide_root = true
	_results.select_mode = Tree.SELECT_ROW
	_results.column_titles_visible = true
	_results.set_column_title(0, "Group")
	_results.set_column_title(1, "声明场景")
	_results.set_column_title(2, "节点路径")
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results.custom_minimum_size.y = 160.0
	var _activate_result: int = _results.item_activated.connect(_on_location_requested)
	add_child(_results)
	var pagination: HBoxContainer = _WORKSPACE_UI.make_toolbar()
	add_child(pagination)
	_previous_button = _WORKSPACE_UI.make_button("上一页", "", _on_previous_pressed)
	_previous_button.name = "PreviousPage"
	pagination.add_child(_previous_button)
	_page_summary = _WORKSPACE_UI.make_summary_label()
	_page_summary.name = "PageSummary"
	_page_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pagination.add_child(_page_summary)
	_next_button = _WORKSPACE_UI.make_button("下一页", "", _on_next_pressed)
	_next_button.name = "NextPage"
	pagination.add_child(_next_button)
	var open_button: Button = _WORKSPACE_UI.make_button(
		"定位节点", "打开声明场景并选中节点，也可双击结果", _on_location_requested
	)
	open_button.name = "OpenLocation"
	pagination.add_child(open_button)
	_location_status = _WORKSPACE_UI.make_summary_label()
	_location_status.name = "LocationStatus"
	add_child(_location_status)
	_issues = _WORKSPACE_UI.make_details_output(96.0)
	_issues.name = "Issues"
	add_child(_issues)


func _status() -> String:
	return _VARIANT_ACCESS_SCRIPT.get_option_string(_index.get_snapshot(), "status", "idle")


func _render_summary() -> void:
	var snapshot: Dictionary = _index.get_snapshot()
	var status: String = _VARIANT_ACCESS_SCRIPT.get_option_string(snapshot, "status", "idle")
	var prefix: String = "尚未扫描。点击刷新读取已保存场景。"
	match status:
		"scanning": prefix = "正在扫描…"
		"complete": prefix = "扫描完整。"
		"partial": prefix = "扫描不完整；以下结果仅覆盖已读取部分。"
		"cancelled": prefix = "已取消；以下结果仅覆盖取消前已读取部分。"
		"failed": prefix = "扫描失败；请检查根目录和问题详情。"
	_summary.text = "%s 已检查 %d 个条目、处理 %d 个场景、收集 %d 条声明。" % [
		prefix,
		_VARIANT_ACCESS_SCRIPT.get_option_int(snapshot, "entry_count", 0),
		_VARIANT_ACCESS_SCRIPT.get_option_int(snapshot, "scene_count", 0),
		_VARIANT_ACCESS_SCRIPT.get_option_int(snapshot, "row_count", 0),
	]
	_refresh_button.disabled = _scanning
	_cancel_button.disabled = not _scanning
	_scan_root.editable = not _scanning
	_search.editable = not _scanning
	var messages: PackedStringArray = PackedStringArray()
	var issue_values: Variant = snapshot.get("issues", [])
	if issue_values is Array:
		for issue_value: Variant in issue_values:
			if issue_value is Dictionary:
				var issue: Dictionary = issue_value
				var _message_added: bool = messages.append("%s: %s\n%s" % [
					_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "code", ""),
					_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "path", ""),
					_VARIANT_ACCESS_SCRIPT.get_option_string(issue, "message", ""),
				])
	var omitted: int = _VARIANT_ACCESS_SCRIPT.get_option_int(snapshot, "omitted_issue_count", 0)
	if omitted > 0:
		var _omission_added: bool = messages.append("另有 %d 条问题未展开。" % omitted)
	_issues.text = "\n\n".join(messages)
	_issues.visible = not messages.is_empty()


func _render_page() -> void:
	_results.clear()
	var page: Dictionary = _index.query(_search.text, _offset, _PAGE_SIZE)
	var total: int = _VARIANT_ACCESS_SCRIPT.get_option_int(page, "total", 0)
	if _offset >= total and _offset > 0:
		_offset = maxi(0, int((total - 1) / float(_PAGE_SIZE)) * _PAGE_SIZE)
		page = _index.query(_search.text, _offset, _PAGE_SIZE)
	var tree_root: TreeItem = _results.create_item()
	var rows: Variant = page.get("rows", [])
	var visible_count: int = 0
	if rows is Array:
		for row_value: Variant in rows:
			if row_value is Dictionary:
				var row: Dictionary = row_value
				var item: TreeItem = _results.create_item(tree_root)
				item.set_text(0, _VARIANT_ACCESS_SCRIPT.get_option_string(row, "group", ""))
				item.set_text(1, _VARIANT_ACCESS_SCRIPT.get_option_string(row, "scene_path", ""))
				item.set_text(2, _VARIANT_ACCESS_SCRIPT.get_option_string(row, "node_path", ""))
				item.set_metadata(0, row.duplicate(true))
				visible_count += 1
	_page_summary.text = "%d–%d / %d 条匹配" % [
		_offset + 1 if visible_count > 0 else 0, _offset + visible_count, total,
	]
	if total == 0:
		_page_summary.text = "未发现匹配声明。" if _status() == "complete" else "暂无匹配结果。"
	_previous_button.disabled = _scanning or _offset == 0
	_next_button.disabled = _scanning or _offset + visible_count >= total


func _advance_location() -> void:
	var scene_path: String = _VARIANT_ACCESS_SCRIPT.get_option_string(_pending_location, "scene_path", "")
	var edited_root: Node = EditorInterface.get_edited_scene_root()
	if edited_root == null or edited_root.scene_file_path != scene_path:
		if Time.get_ticks_msec() >= _location_deadline:
			_location_status.text = "未能打开声明场景，请确认资源仍可读取后刷新重试。"
			_pending_location.clear()
		return
	var node_path: String = _VARIANT_ACCESS_SCRIPT.get_option_string(_pending_location, "node_path", "")
	var group: String = _VARIANT_ACCESS_SCRIPT.get_option_string(_pending_location, "group", "")
	var target_node: Node = edited_root.get_node_or_null(NodePath(node_path))
	_pending_location.clear()
	if target_node == null or not target_node.is_in_group(StringName(group)):
		_location_status.text = "声明位置已变化，或当前场景有未保存修改；请核对场景并刷新查询。"
		return
	var selection: EditorSelection = EditorInterface.get_selection()
	if selection == null:
		_location_status.text = "编辑器选择服务不可用。"
		return
	selection.clear()
	selection.add_node(target_node)
	EditorInterface.edit_node(target_node)
	_location_status.text = "已定位 %s :: %s" % [scene_path, node_path]


# --- 信号处理函数 ---

func _on_refresh_pressed() -> void:
	var _scan_error: Error = refresh(_scan_root.text)


func _on_search_text_changed(_text: String) -> void:
	_pending_location.clear()
	_location_status.text = ""
	_offset = 0
	_render_page()


func _on_previous_pressed() -> void:
	_pending_location.clear()
	_offset = maxi(0, _offset - _PAGE_SIZE)
	_render_page()


func _on_next_pressed() -> void:
	_pending_location.clear()
	_offset += _PAGE_SIZE
	_render_page()


func _on_location_requested() -> void:
	_pending_location.clear()
	if not Engine.is_editor_hint():
		_location_status.text = "节点定位仅在 Godot 编辑器中可用。"
		return
	var selected_item: TreeItem = _results.get_selected()
	if selected_item == null:
		_location_status.text = "请先选择一条声明。"
		return
	var row_value: Variant = selected_item.get_metadata(0)
	if not row_value is Dictionary:
		return
	var row: Dictionary = row_value
	var scene_path: String = _VARIANT_ACCESS_SCRIPT.get_option_string(row, "scene_path", "")
	if not FileAccess.file_exists(scene_path):
		_location_status.text = "声明场景已移动或删除；请刷新查询。"
		return
	_pending_location = row.duplicate(true)
	_location_deadline = Time.get_ticks_msec() + _LOCATION_TIMEOUT_MSEC
	_location_status.text = "正在打开声明场景…"
	EditorInterface.open_scene_from_path(scene_path)
	set_process(true)
