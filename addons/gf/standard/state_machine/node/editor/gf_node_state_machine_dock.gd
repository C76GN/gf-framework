@tool

## GFNodeStateMachineDock: 节点状态机结构检查工作区页面。
##
## 面向编辑器展示当前场景中的 GFNodeStateMachine，复用标准校验器输出结构问题，
## 不推断项目自己的状态转移、输入或动画语义。
## [br]
## @api public
## [br]
## @category editor_api
## [br]
## @since 3.17.0
class_name GFNodeStateMachineDock
extends Control


# --- 常量 ---

const _GF_NODE_STATE_MACHINE_VALIDATOR = preload("res://addons/gf/standard/state_machine/node/gf_node_state_machine_validator.gd")
const _INSTANCE_GUARD = preload("res://addons/gf/kernel/core/gf_instance_guard.gd")
const _GF_EDITOR_WORKSPACE_UI = preload("res://addons/gf/kernel/editor/gf_editor_workspace_ui.gd")


# --- 私有变量 ---

var _root_ref: WeakRef = null
var _machines: Array[GFNodeStateMachine] = []
var _last_report: Dictionary = {}
var _machine_option: OptionButton = null
var _require_initial_check: CheckBox = null
var _select_button: Button = null
var _summary_label: Label = null
var _empty_label: Label = null
var _tree: Tree = null
var _details: TextEdit = null


# --- Godot 生命周期方法 ---

func _init() -> void:
	name = "GF State Tools"
	_GF_EDITOR_WORKSPACE_UI.apply_page_root(self)
	_build_ui()
	call_deferred("refresh")


# --- 公共方法 ---

## 设置要扫描的场景根节点。
## [br]
## @api public
## [br]
## @param root: 场景根节点；为空时刷新会尝试使用当前编辑场景或运行时场景。
func set_state_machine_source(root: Node) -> void:
	_root_ref = weakref(root) if root != null else null
	refresh(root)


## 刷新状态机列表与当前校验报告。
## [br]
## @api public
## [br]
## @param root: 可选场景根节点；为空时使用 set_state_machine_source() 或当前场景。
func refresh(root: Node = null) -> void:
	_build_ui()
	var source_root: Node = root if root != null else _resolve_root()
	_machines.clear()
	if source_root != null:
		_root_ref = weakref(source_root)
		_collect_state_machines(source_root, _machines)
	_populate_machine_options()
	_render_selected_machine()


## 获取最近一次校验报告字典。
## [br]
## @api public
## [br]
## @return: 报告字典副本。
## [br]
## @schema return: 校验报告 Dictionary，包含 ok、summary、next_action、issues、error_count、warning_count 等字段。
func get_last_report() -> Dictionary:
	return _last_report.duplicate(true)


## 获取最近一次扫描到的状态机数量。
## [br]
## @api public
## [br]
## @return: 状态机数量。
func get_machine_count() -> int:
	return _machines.size()


# --- 私有/辅助方法 ---

func _build_ui() -> void:
	if _tree != null:
		return

	var root_box: VBoxContainer = VBoxContainer.new()
	root_box.clip_contents = true
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(root_box)
	root_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var toolbar: HBoxContainer = _GF_EDITOR_WORKSPACE_UI.make_toolbar()
	root_box.add_child(toolbar)

	toolbar.add_child(_GF_EDITOR_WORKSPACE_UI.make_button("刷新", "扫描当前场景中的 GFNodeStateMachine。", refresh))

	_machine_option = OptionButton.new()
	_machine_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_machine_option.tooltip_text = "选择一个已扫描到的节点状态机。"
	var _machine_selected_connected: int = _machine_option.item_selected.connect(_on_machine_selected)
	toolbar.add_child(_machine_option)

	_require_initial_check = CheckBox.new()
	_require_initial_check.text = "要求初始状态"
	_require_initial_check.tooltip_text = "启用后会把手动启动状态机也按必须设置初始状态来检查。"
	var _option_toggled_connected: int = _require_initial_check.toggled.connect(_on_option_toggled)
	toolbar.add_child(_require_initial_check)

	_select_button = Button.new()
	_select_button.text = "选中"
	_select_button.tooltip_text = "在编辑器场景树中选中当前状态机。"
	var _select_connected: int = _select_button.pressed.connect(_on_select_pressed)
	toolbar.add_child(_select_button)

	_summary_label = _GF_EDITOR_WORKSPACE_UI.make_summary_label()
	root_box.add_child(_summary_label)

	_empty_label = _GF_EDITOR_WORKSPACE_UI.make_empty_label()
	root_box.add_child(_empty_label)

	_tree = Tree.new()
	_tree.columns = 4
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "级别")
	_tree.set_column_title(1, "类型")
	_tree.set_column_title(2, "定位")
	_tree.set_column_title(3, "说明")
	_tree.set_column_expand(3, true)
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var _issue_selected_connected: int = _tree.item_selected.connect(_on_issue_selected)
	root_box.add_child(_tree)

	_details = _GF_EDITOR_WORKSPACE_UI.make_details_output()
	root_box.add_child(_details)


func _resolve_root() -> Node:
	if _root_ref != null:
		var root: Node = _INSTANCE_GUARD._get_live_node_from_ref(_root_ref)
		if root != null:
			return root

	if Engine.is_editor_hint():
		var edited_root: Node = EditorInterface.get_edited_scene_root()
		if edited_root != null:
			return edited_root

	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null
	var tree: SceneTree = main_loop
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene != null else tree.root


func _collect_state_machines(node: Node, result: Array[GFNodeStateMachine]) -> void:
	if node is GFNodeStateMachine:
		var machine: GFNodeStateMachine = node
		result.append(machine)

	for child: Node in node.get_children():
		_collect_state_machines(child, result)


func _populate_machine_options() -> void:
	if _machine_option == null:
		return

	var previous_index: int = _machine_option.selected
	_machine_option.clear()
	for index: int in range(_machines.size()):
		var machine: GFNodeStateMachine = _machines[index]
		_machine_option.add_item(_get_node_path_text(machine), index)
		_machine_option.set_item_metadata(index, index)

	if _machines.is_empty():
		_machine_option.add_item("未找到状态机", 0)
		_machine_option.disabled = true
		_select_button.disabled = true
	else:
		_machine_option.disabled = false
		_select_button.disabled = false
		_machine_option.select(clampi(previous_index, 0, _machines.size() - 1))


func _render_selected_machine() -> void:
	if _tree == null:
		return

	_tree.clear()
	_details.text = ""
	_details.visible = false
	if _machines.is_empty():
		_last_report = {}
		_GF_EDITOR_WORKSPACE_UI.set_status(_summary_label, "当前场景没有 GFNodeStateMachine。")
		_empty_label.text = "打开包含节点状态机的场景后点击刷新。"
		_empty_label.visible = true
		_tree.visible = false
		return

	var machine: GFNodeStateMachine = _get_selected_machine()
	if machine == null:
		_last_report = {}
		_GF_EDITOR_WORKSPACE_UI.set_status(_summary_label, "当前选择无效。", _GF_EDITOR_WORKSPACE_UI.WARNING_TEXT_COLOR)
		_empty_label.visible = true
		_tree.visible = false
		return

	var report: GFValidationReport = _GF_NODE_STATE_MACHINE_VALIDATOR.validate_machine(machine, _get_validator_options())
	_last_report = report.to_dict({}, {
		"include_metadata": true,
		"summary_subject": _get_node_path_text(machine),
	})
	_summary_label.text = "%s\n下一步：%s" % [
		GFVariantData.get_option_string(_last_report, "summary"),
		GFVariantData.get_option_string(_last_report, "next_action"),
	]
	_summary_label.modulate = _GF_EDITOR_WORKSPACE_UI.get_report_color(_last_report)
	_render_issues(GFVariantData.get_option_array(_last_report, "issues"))


func _render_issues(issues: Array) -> void:
	var root_item: TreeItem = _tree.create_item()
	var visible_count: int = 0
	for issue_variant: Variant in issues:
		if not (issue_variant is Dictionary):
			continue
		var issue: Dictionary = GFVariantData.as_dictionary(issue_variant)

		var item: TreeItem = _tree.create_item(root_item)
		item.set_text(0, GFVariantData.get_option_string(issue, "severity"))
		item.set_text(1, GFVariantData.get_option_string(issue, "kind"))
		item.set_text(2, GFVariantData.get_option_string(issue, "path", GFVariantData.get_option_string(issue, "key")))
		item.set_text(3, GFVariantData.get_option_string(issue, "message"))
		item.set_metadata(0, issue.duplicate(true))
		visible_count += 1

	_tree.visible = visible_count > 0
	_empty_label.visible = visible_count == 0
	_empty_label.text = "当前状态机结构健康。" if visible_count == 0 else ""
	_details.visible = visible_count > 0


func _get_selected_machine() -> GFNodeStateMachine:
	if _machine_option == null or _machines.is_empty():
		return null

	var index: int = _machine_option.selected
	if index < 0 or index >= _machines.size():
		return null
	var machine: GFNodeStateMachine = _machines[index]
	return machine if is_instance_valid(machine) else null


func _get_validator_options() -> Dictionary:
	var options: Dictionary = {}
	if _require_initial_check != null and _require_initial_check.button_pressed:
		options["require_initial_state"] = true
	return options


func _get_node_path_text(node: Node) -> String:
	if node == null:
		return ""
	if node.is_inside_tree():
		return String(node.get_path())
	return String(node.name)


func _safe_json(value: Variant) -> String:
	return GFReportValueCodec.stringify_json_compatible(
		value,
		"\t",
		false,
		GFReportValueCodec.make_redaction_options(GFReportValueCodec.REDACTION_PROFILE_DEBUG)
	)


# --- 信号处理函数 ---

func _on_machine_selected(_index: int) -> void:
	_render_selected_machine()


func _on_option_toggled(_pressed: bool) -> void:
	_render_selected_machine()


func _on_select_pressed() -> void:
	if not Engine.is_editor_hint():
		return

	var machine: GFNodeStateMachine = _get_selected_machine()
	if machine == null:
		return

	var selection: EditorSelection = EditorInterface.get_selection()
	if selection == null:
		return
	selection.clear()
	selection.add_node(machine)


func _on_issue_selected() -> void:
	var item: TreeItem = _tree.get_selected()
	if item == null:
		return

	var issue: Variant = item.get_metadata(0)
	if issue is Dictionary:
		_details.visible = true
		_details.text = _safe_json(issue)
