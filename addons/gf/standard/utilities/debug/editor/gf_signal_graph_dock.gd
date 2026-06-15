@tool

## GFSignalGraphDock: 当前场景信号连接与发射记录查看面板。
##
## 基于 GFSceneSignalAudit 渲染编辑器中保存的信号连接，并可显式开启
## GFSignalRuntimeProbe 观察当前场景信号发射。面板只读，不修改场景。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
class_name GFSignalGraphDock
extends Control


# --- 常量 ---

const _MAX_EVENT_COUNT: int = 300
const _MAX_DISPLAY_ARGUMENT_LENGTH: int = 120
const _NOISY_UNCONNECTED_SIGNAL_NAMES: Array[StringName] = [
	&"draw",
]
const _INSTANCE_GUARD: Script = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")
const _EDITOR_WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")


# --- 私有变量 ---

var _root_ref: WeakRef = null
var _last_graph: Dictionary = {}
var _last_events: Array[Dictionary] = []
var _live_watch_count: int = 0
var _live_signal_names: PackedStringArray = PackedStringArray()
var _probe: GFSignalRuntimeProbe = null
var _persistent_only_check: CheckBox = null
var _include_empty_check: CheckBox = null
var _live_check: CheckBox = null
var _details_toggle: CheckBox = null
var _filter_edit: LineEdit = null
var _summary_label: Label = null
var _hint_label: Label = null
var _empty_state_label: Label = null
var _event_empty_state_label: Label = null
var _tabs: TabContainer = null
var _tree: Tree = null
var _event_tree: Tree = null
var _clear_events_button: Button = null
var _details: TextEdit = null


# --- Godot 生命周期方法 ---

func _ready() -> void:
	name = "GF Signal Diagnostics"
	_build_ui()
	call_deferred("_refresh_deferred")


func _exit_tree() -> void:
	_stop_live_probe()


# --- 公共方法 ---

## 设置要查看的根节点。
## [br]
## @api public
## [br]
## @param root: 根节点；为空时刷新时会尝试使用当前编辑场景根节点。
func set_graph_source(root: Node) -> void:
	_root_ref = weakref(root) if root != null else null
	refresh(root)


## 刷新信号图。
## [br]
## @api public
## [br]
## @param root: 可选根节点；为空时使用 set_graph_source() 或当前编辑场景根节点。
func refresh(root: Node = null) -> void:
	_build_ui()
	var target_root: Node = root if root != null else _resolve_root()
	if target_root == null:
		_last_graph = {
			"ok": false,
			"message": "没有可用的场景根节点。",
		}
		_render_graph()
		_restart_live_probe_if_enabled()
		return

	_root_ref = weakref(target_root)
	_last_graph = GFSceneSignalAudit.build_signal_graph(target_root, {
		"persistent_only": _persistent_only_check.button_pressed,
		"include_empty_signals": _include_empty_check.button_pressed,
		"include_external_targets": false,
		"participating_nodes_only": true,
	})
	_render_graph()
	_restart_live_probe_if_enabled()


## 设置运行时信号发射追踪开关。
## [br]
## @api public
## [br]
## @param enabled: 为 true 时追踪当前可见信号；为 false 时停止追踪。
func set_live_tracking_enabled(enabled: bool) -> void:
	_build_ui()
	if _live_check != null:
		_live_check.set_pressed_no_signal(enabled)
	if enabled:
		_start_live_probe()
	else:
		_stop_live_probe()
	_render_events()


## 获取最近一次信号图快照。
## [br]
## @api public
## [br]
## @return 信号图字典副本。
## [br]
## @schema return: Dictionary，包含 GFSceneSignalAudit.build_signal_graph() 返回的信号图字段。
func get_last_graph() -> Dictionary:
	return _last_graph.duplicate(true)


## 获取最近信号发射记录。
## [br]
## @api public
## [br]
## @return 发射记录副本。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 timestamp_msec、source_node_path、signal_name、arguments 和 connections 等字段。
func get_recent_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in _last_events:
		result.append(event.duplicate(true))
	return result


## 获取面板调试快照。
## [br]
## @api public
## [br]
## @return 面板调试快照。
## [br]
## @schema return: Dictionary，包含 graph、recent_events、live 和 ui 分区，用于编辑器诊断和测试。
func get_debug_snapshot() -> Dictionary:
	_build_ui()
	_render_events()
	var root_box: Control = _get_root_control()
	return {
		"graph": get_last_graph(),
		"recent_events": get_recent_events(),
		"live": {
			"enabled": _live_check != null and _live_check.button_pressed,
			"watch_count": _live_watch_count,
			"signal_names": _live_signal_names.duplicate(),
		},
		"ui": {
			"custom_minimum_size": custom_minimum_size,
			"root_anchor_right": root_box.anchor_right if root_box != null else 0.0,
			"root_anchor_bottom": root_box.anchor_bottom if root_box != null else 0.0,
			"event_empty_visible": _event_empty_state_label != null and _event_empty_state_label.visible,
			"event_tree_visible": _event_tree != null and _event_tree.visible,
			"event_empty_text": _event_empty_state_label.text if _event_empty_state_label != null else "",
			"persistent_only_text": _persistent_only_check.text if _persistent_only_check != null else "",
			"include_empty_text": _include_empty_check.text if _include_empty_check != null else "",
			"live_text": _live_check.text if _live_check != null else "",
			"details_visible": _details != null and _details.visible,
		},
	}


# --- 私有/辅助方法 ---

func _get_root_control() -> Control:
	if get_child_count() <= 0:
		return null
	var child: Node = get_child(0)
	if child is Control:
		var control: Control = child
		return control
	return null


func _get_main_scene_tree() -> SceneTree:
	var main_loop: MainLoop = Engine.get_main_loop()
	if main_loop is SceneTree:
		var tree: SceneTree = main_loop
		return tree
	return null


func _build_ui() -> void:
	if _tree != null:
		return

	_EDITOR_WORKSPACE_UI.apply_page_root(self)

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.clip_contents = true
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root_box)
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var toolbar: HBoxContainer = _EDITOR_WORKSPACE_UI.make_toolbar()
	root_box.add_child(toolbar)

	toolbar.add_child(_EDITOR_WORKSPACE_UI.make_button("刷新", "重新读取当前场景信号连接。", refresh))

	_persistent_only_check = CheckBox.new()
	_persistent_only_check.text = "保存连接"
	_persistent_only_check.tooltip_text = "只显示场景文件中保存的信号连接。"
	_persistent_only_check.button_pressed = true
	_connect_signal(_persistent_only_check.toggled, _on_option_toggled)
	toolbar.add_child(_persistent_only_check)

	_include_empty_check = CheckBox.new()
	_include_empty_check.text = "未连接信号"
	_include_empty_check.tooltip_text = "没有连接目标的节点信号也显示出来。"
	_connect_signal(_include_empty_check.toggled, _on_option_toggled)
	toolbar.add_child(_include_empty_check)

	_live_check = CheckBox.new()
	_live_check.text = "追踪发射"
	_live_check.tooltip_text = "开启后记录连接页当前可见信号的发射。"
	_connect_signal(_live_check.toggled, _on_live_toggled)
	toolbar.add_child(_live_check)

	_clear_events_button = _EDITOR_WORKSPACE_UI.make_button("清空记录", "清空信号发射记录。", _on_clear_events_pressed)
	_clear_events_button.disabled = true
	toolbar.add_child(_clear_events_button)

	_filter_edit = LineEdit.new()
	_filter_edit.placeholder_text = "筛选节点、信号或方法"
	_filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connect_signal(_filter_edit.text_changed, _on_filter_text_changed)
	toolbar.add_child(_filter_edit)

	_details_toggle = CheckBox.new()
	_details_toggle.text = "详情"
	_connect_signal(_details_toggle.toggled, _on_details_toggled)
	toolbar.add_child(_details_toggle)

	_summary_label = _EDITOR_WORKSPACE_UI.make_summary_label()
	root_box.add_child(_summary_label)

	_hint_label = _EDITOR_WORKSPACE_UI.make_empty_label()
	_hint_label.text = "连接页查看场景保存的信号连接；发射记录页查看开启“追踪发射”后的信号发射。只读。"
	root_box.add_child(_hint_label)

	_tabs = TabContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(_tabs)

	var connection_page: VBoxContainer = VBoxContainer.new()
	connection_page.name = "连接"
	connection_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	connection_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(connection_page)

	_empty_state_label = _EDITOR_WORKSPACE_UI.make_empty_label()
	_empty_state_label.text = "打开一个场景，或在场景树中选中节点后点击刷新。"
	_empty_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_empty_state_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	connection_page.add_child(_empty_state_label)

	_tree = _make_tree(["来源", "信号", "目标", "方法"])
	_connect_signal(_tree.item_selected, _on_tree_item_selected)
	connection_page.add_child(_tree)

	var event_page: VBoxContainer = VBoxContainer.new()
	event_page.name = "发射记录"
	event_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_child(event_page)

	_event_empty_state_label = _EDITOR_WORKSPACE_UI.make_empty_label()
	_event_empty_state_label.text = _get_event_empty_text()
	event_page.add_child(_event_empty_state_label)

	_event_tree = _make_tree(["时间", "来源", "信号", "参数"])
	_connect_signal(_event_tree.item_selected, _on_event_tree_item_selected)
	event_page.add_child(_event_tree)

	_details = _EDITOR_WORKSPACE_UI.make_details_output()
	_details.visible = false
	root_box.add_child(_details)


func _make_tree(titles: Array[String]) -> Tree:
	var tree: Tree = Tree.new()
	tree.columns = titles.size()
	tree.hide_root = true
	tree.column_titles_visible = true
	for i: int in range(titles.size()):
		tree.set_column_title(i, titles[i])
		tree.set_column_expand(i, i != 1)
	tree.set_column_custom_minimum_width(1, 130)
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return tree


func _resolve_root() -> Node:
	if _root_ref != null:
		var existing: Node = _get_live_node_from_ref(_root_ref)
		if existing != null:
			return existing

	if Engine.is_editor_hint():
		var edited_root: Node = EditorInterface.get_edited_scene_root()
		if edited_root != null:
			return edited_root
		return _resolve_selected_scene_node()

	var tree: SceneTree = _get_main_scene_tree()
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


func _render_graph() -> void:
	if _tree == null:
		return

	_tree.clear()
	if not GFVariantData.get_option_bool(_last_graph, "ok", false):
		_EDITOR_WORKSPACE_UI.set_status(
			_summary_label,
			GFVariantData.get_option_string(_last_graph, "message", "信号图不可用。"),
			_EDITOR_WORKSPACE_UI.WARNING_TEXT_COLOR
		)
		_tree.visible = false
		_empty_state_label.visible = true
		_empty_state_label.text = "打开一个场景，或在场景树中选中节点后点击刷新。"
		_details.text = _summary_label.text
		_render_events()
		return

	var connection_total: int = GFVariantData.get_option_int(_last_graph, "connection_count", 0)
	var signal_total: int = GFVariantData.get_option_int(_last_graph, "signal_count", 0)
	_summary_label.text = "节点：%d  信号：%d  连接：%d  发射记录：%d" % [
		GFVariantData.get_option_int(_last_graph, "node_count", 0),
		signal_total,
		connection_total,
		_last_events.size(),
	]
	_summary_label.modulate = _EDITOR_WORKSPACE_UI.OK_TEXT_COLOR
	_details.text = "选中一条连接、信号或发射记录后查看详情。"

	if connection_total == 0 and signal_total == 0:
		_tree.visible = false
		_empty_state_label.visible = true
		_empty_state_label.text = _get_connection_empty_text()
		_render_events()
		return

	var root_item: TreeItem = _tree.create_item()
	var visible_count: int = 0
	for connection_variant: Variant in GFVariantData.get_option_array(_last_graph, "connections"):
		var connection: Dictionary = GFVariantData.as_dictionary(connection_variant)
		if connection.is_empty() or not _matches_filter(connection):
			continue
		var item: TreeItem = _tree.create_item(root_item)
		item.set_text(0, GFVariantData.get_option_string(connection, "source_node_path", ""))
		item.set_text(1, GFVariantData.get_option_string(connection, "signal_name", ""))
		item.set_text(2, GFVariantData.get_option_string(connection, "target_node_path", ""))
		item.set_text(3, GFVariantData.get_option_string(connection, "method_name", ""))
		item.set_metadata(0, connection.duplicate(true))
		visible_count += 1

	if connection_total == 0:
		for signal_variant: Variant in GFVariantData.get_option_array(_last_graph, "signals"):
			var signal_entry: Dictionary = GFVariantData.as_dictionary(signal_variant)
			if signal_entry.is_empty() or not _matches_filter(signal_entry):
				continue
			var signal_item: TreeItem = _tree.create_item(root_item)
			signal_item.set_text(0, GFVariantData.get_option_string(signal_entry, "node_path", ""))
			signal_item.set_text(1, GFVariantData.get_option_string(signal_entry, "signal_name", ""))
			signal_item.set_text(2, "-")
			signal_item.set_text(3, "-")
			signal_item.set_metadata(0, signal_entry.duplicate(true))
			visible_count += 1

	_tree.visible = visible_count > 0
	_empty_state_label.visible = visible_count == 0
	if visible_count == 0:
		_empty_state_label.text = "没有匹配当前筛选条件的信号连接。"
	_render_events()


func _render_events() -> void:
	if _event_tree == null:
		return

	_event_tree.clear()
	_clear_events_button.disabled = _last_events.is_empty()
	var root_item: TreeItem = _event_tree.create_item()
	var visible_count: int = 0
	for i: int in range(_last_events.size() - 1, -1, -1):
		var event: Dictionary = _last_events[i]
		if not _matches_filter(event):
			continue
		var item: TreeItem = _event_tree.create_item(root_item)
		item.set_text(0, str(GFVariantData.get_option_int(event, "timestamp_msec", 0)))
		item.set_text(1, GFVariantData.get_option_string(event, "source_node_path", ""))
		item.set_text(2, GFVariantData.get_option_string(event, "signal_name", ""))
		item.set_text(3, _format_arguments(GFVariantData.get_option_array(event, "arguments")))
		item.set_metadata(0, event.duplicate(true))
		visible_count += 1

	_event_tree.visible = visible_count > 0
	_event_empty_state_label.visible = visible_count == 0
	if visible_count == 0:
		_event_empty_state_label.text = "没有匹配当前筛选条件的发射记录。" if not _last_events.is_empty() else _get_event_empty_text()


func _resolve_selected_scene_node() -> Node:
	if not Engine.is_editor_hint():
		return null

	var selection: EditorSelection = EditorInterface.get_selection()
	if selection == null:
		return null

	var selected_nodes: Array = selection.get_selected_nodes()
	if selected_nodes.is_empty():
		return null

	var node: Node = _variant_to_node(selected_nodes[0])
	if node == null:
		return null
	while node.owner != null:
		node = node.owner
	return node


func _restart_live_probe_if_enabled() -> void:
	if _live_check == null or not _live_check.button_pressed:
		return
	_start_live_probe()
	_render_events()


func _start_live_probe() -> void:
	_stop_live_probe()
	var target_root: Node = _resolve_root()
	if target_root == null:
		return

	_live_signal_names = _collect_live_signal_names()
	if _live_signal_names.is_empty():
		return

	_probe = GFSignalRuntimeProbe.new()
	_probe.max_events = _MAX_EVENT_COUNT
	_connect_signal(_probe.signal_emitted, _on_probe_signal_emitted)
	var report: Dictionary = _probe.watch_tree(target_root, {
		"recursive": true,
		"include_internal": false,
		"include_signals": _live_signal_names,
		"max_argument_count": 8,
	})
	_live_watch_count = GFVariantData.get_option_int(report, "watched_count", 0)


func _stop_live_probe() -> void:
	_live_watch_count = 0
	_live_signal_names = PackedStringArray()
	if _probe == null:
		return
	if _probe.signal_emitted.is_connected(_on_probe_signal_emitted):
		_probe.signal_emitted.disconnect(_on_probe_signal_emitted)
	var _removed_count: int = _probe.unwatch_all()
	_probe = null


func _matches_filter(entry: Dictionary) -> bool:
	if _filter_edit == null or _filter_edit.text.strip_edges().is_empty():
		return true

	var needle: String = _filter_edit.text.strip_edges().to_lower()
	for value: Variant in entry.values():
		if str(value).to_lower().contains(needle):
			return true
	return false


func _format_arguments(arguments: Variant) -> String:
	if not arguments is Array:
		return ""

	var parts: PackedStringArray = PackedStringArray()
	for argument: Variant in GFVariantData.as_array(arguments):
		var text: String = str(argument)
		if text.length() > _MAX_DISPLAY_ARGUMENT_LENGTH:
			text = text.substr(0, _MAX_DISPLAY_ARGUMENT_LENGTH) + "..."
		_append_packed_string(parts, text)
	return ", ".join(parts)


func _safe_json(value: Variant) -> String:
	return JSON.stringify(_sanitize_for_display(value), "\t")


func _collect_live_signal_names() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for connection_variant: Variant in GFVariantData.get_option_array(_last_graph, "connections"):
		var connection: Dictionary = GFVariantData.as_dictionary(connection_variant)
		if connection.is_empty() or not _matches_filter(connection):
			continue
		_append_live_signal_name(
			result,
			seen,
			GFVariantData.get_option_string_name(connection, "signal_name", &""),
			false
		)

	if result.is_empty() and _include_empty_check != null and _include_empty_check.button_pressed:
		for signal_variant: Variant in GFVariantData.get_option_array(_last_graph, "signals"):
			var signal_entry: Dictionary = GFVariantData.as_dictionary(signal_variant)
			if signal_entry.is_empty() or not _matches_filter(signal_entry):
				continue
			_append_live_signal_name(
				result,
				seen,
				GFVariantData.get_option_string_name(signal_entry, "signal_name", &""),
				true
			)
	return result


func _append_live_signal_name(
	result: PackedStringArray,
	seen: Dictionary,
	signal_name: StringName,
	from_unconnected_signal: bool
) -> void:
	if signal_name == &"":
		return
	if from_unconnected_signal and _NOISY_UNCONNECTED_SIGNAL_NAMES.has(signal_name):
		return
	var key: String = String(signal_name)
	if seen.has(key):
		return
	seen[key] = true
	_append_packed_string(result, key)


static func _connect_signal(source_signal: Signal, callback: Callable) -> void:
	var error: int = source_signal.connect(callback)
	if error != OK:
		return


static func _get_live_node_from_ref(source_ref: WeakRef) -> Node:
	var result: Variant = _INSTANCE_GUARD.call("_get_live_node_from_ref", source_ref)
	if result is Node:
		var node: Node = result
		return node
	return null


static func _variant_to_node(value: Variant) -> Node:
	if value is Node:
		var node: Node = value
		return node
	return null


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


func _get_connection_empty_text() -> String:
	return "当前场景没有可显示的保存连接。用 Godot 的“节点 > 信号”连接信号后点刷新；或勾选“未连接信号”查看节点声明过但还没连接目标的信号。"


func _get_event_empty_text() -> String:
	if _live_check != null and _live_check.button_pressed:
		if _live_signal_names.is_empty() or _live_watch_count <= 0:
			return "追踪已开启，但当前筛选没有可追踪信号。先在连接页确认有保存连接，或勾选“未连接信号”后刷新。独立运行的游戏进程不会被自动抓取。"
		return "追踪已开启：%d 个信号正在监听。现在操作当前编辑场景，让按钮、Area、AnimationPlayer 或自定义脚本发出信号，新的发射记录会出现在这里。独立运行的游戏进程不会被自动抓取。" % _live_watch_count
	return "勾选“追踪发射”后，再操作当前编辑场景；之后发出的 pressed、area_entered、animation_finished 或自定义信号会记录在这里。"


func _sanitize_for_display(value: Variant) -> Variant:
	if value is Dictionary:
		var dictionary_value: Dictionary = value
		var result: Dictionary = {}
		for key: Variant in dictionary_value.keys():
			result[str(key)] = _sanitize_for_display(dictionary_value[key])
		return result
	if value is Array:
		var array_value: Array = value
		var array_result: Array = []
		for item: Variant in array_value:
			array_result.append(_sanitize_for_display(item))
		return array_result
	if value is PackedStringArray:
		var packed_value: PackedStringArray = value
		var string_array: Array[String] = []
		for item: String in packed_value:
			string_array.append(item)
		return string_array
	if value is Object:
		return str(value)
	return value


func _refresh_deferred() -> void:
	refresh()


# --- 信号处理函数 ---

func _on_option_toggled(_pressed: bool) -> void:
	refresh()


func _on_live_toggled(pressed: bool) -> void:
	if pressed:
		_start_live_probe()
	else:
		_stop_live_probe()
	_render_events()


func _on_clear_events_pressed() -> void:
	_last_events.clear()
	if _probe != null:
		_probe.clear_events()
	_render_graph()


func _on_filter_text_changed(_text: String) -> void:
	_render_graph()
	_restart_live_probe_if_enabled()


func _on_details_toggled(pressed: bool) -> void:
	_details.visible = pressed


func _on_tree_item_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return

	var metadata: Variant = item.get_metadata(0)
	if metadata is Dictionary:
		_details.text = _safe_json(metadata)


func _on_event_tree_item_selected() -> void:
	var item: TreeItem = _event_tree.get_selected()
	if item == null:
		return

	var metadata: Variant = item.get_metadata(0)
	if metadata is Dictionary:
		_details.text = _safe_json(metadata)


func _on_probe_signal_emitted(event: Dictionary) -> void:
	_last_events.append(event.duplicate(true))
	while _last_events.size() > _MAX_EVENT_COUNT:
		var _removed_event: Variant = _last_events.pop_front()
	_render_graph()
