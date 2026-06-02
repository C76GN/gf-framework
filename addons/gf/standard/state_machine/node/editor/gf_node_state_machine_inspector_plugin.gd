@tool

# GF Node State Machine Inspector: 在 Inspector 中辅助配置节点状态机。
extends EditorInspectorPlugin


# --- 常量 ---

const _GF_NODE_STATE_BASE = preload("res://addons/gf/standard/state_machine/node/gf_node_state.gd")
const _GF_NODE_STATE_MACHINE_BASE = preload("res://addons/gf/standard/state_machine/node/gf_node_state_machine.gd")
const _GF_NODE_STATE_MACHINE_VALIDATOR = preload("res://addons/gf/standard/state_machine/node/gf_node_state_machine_validator.gd")
const _GF_VALIDATION_DIAGNOSTIC_ADAPTER = preload("res://addons/gf/standard/foundation/validation/gf_validation_diagnostic_adapter.gd")


# --- Godot 回调方法 ---

func _can_handle(object: Object) -> bool:
	return object is _GF_NODE_STATE_MACHINE_BASE


func _parse_begin(object: Object) -> void:
	if not (object is Node):
		return
	var target: Node = object

	var root: VBoxContainer = VBoxContainer.new()
	root.name = "GFNodeStateMachineInspector"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_custom_control(root)

	var header: Label = Label.new()
	header.text = "GF Node State Machine"
	header.modulate = Color(0.4, 0.8, 1.0)
	root.add_child(header)

	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(row)

	var label: Label = Label.new()
	label.text = "初始状态"
	label.custom_minimum_size = Vector2(86, 0)
	row.add_child(label)

	var option: OptionButton = OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.tooltip_text = "从直接子 GFNodeState 中选择内部状态组初始状态"
	row.add_child(option)
	_populate_initial_state_options(option, target)
	var _option_connected: int = option.item_selected.connect(
		_on_initial_state_selected.bind(option, target),
		CONNECT_DEFERRED as Object.ConnectFlags
	)

	var separator: HSeparator = HSeparator.new()
	root.add_child(separator)

	var validate_button: Button = Button.new()
	validate_button.text = "验证状态机结构"
	validate_button.tooltip_text = "检查状态名、初始状态和条件/行为资源挂接。"
	root.add_child(validate_button)

	var report_label: Label = Label.new()
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART as TextServer.AutowrapMode
	report_label.modulate = Color(0.8, 0.8, 0.8)
	root.add_child(report_label)
	var _validate_connected: int = validate_button.pressed.connect(
		_on_validate_pressed.bind(report_label, target),
		CONNECT_DEFERRED as Object.ConnectFlags
	)


# --- 框架内部方法 ---

## 收集状态机直接子节点中的状态名。
## [br]
## @api framework_internal
## [br]
## @param target: 要扫描的节点状态机。
## [br]
## @return: 直接子状态名列表，按显示名排序。
## [br]
## @schema return: 元素为 StringName 的状态名列表。
static func collect_direct_states(target: Node) -> Array[StringName]:
	var result: Array[StringName] = []
	for child: Node in target.get_children():
		if child is _GF_NODE_STATE_BASE:
			result.append(_get_editor_state_name(child))
	result.sort()
	return result


## 将校验报告压缩为 Inspector tooltip 文本。
## [br]
## @api framework_internal
## [br]
## @param report: GFValidationReport 实例。
## [br]
## @return: 适合 Inspector tooltip 展示的短文本。
static func format_report_tooltip(report: RefCounted) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var diagnostics: Array = _GF_VALIDATION_DIAGNOSTIC_ADAPTER.report_to_diagnostics(report)
	for diagnostic: Dictionary in diagnostics:
		var kind: String = GFVariantData.get_option_string(diagnostic, "kind", "unknown")
		var message: String = GFVariantData.get_option_string(diagnostic, "message")
		_append_packed_string(lines, "%s: %s" % [kind, message])
		if lines.size() >= 8:
			_append_packed_string(lines, "...")
			break
	return "\n".join(lines)


# --- 私有/辅助方法 ---

func _populate_initial_state_options(option: OptionButton, target: Node) -> void:
	option.clear()

	var current_initial_state: StringName = _get_initial_state(target)
	option.add_item("未设置", 0)
	option.set_item_metadata(0, &"")
	option.select(0)

	var states: Array[StringName] = collect_direct_states(target)
	for i: int in range(states.size()):
		var state_name: StringName = states[i]
		option.add_item(String(state_name), i + 1)
		option.set_item_metadata(i + 1, state_name)
		if state_name == current_initial_state:
			option.select(i + 1)

	if current_initial_state != &"" and not states.has(current_initial_state):
		var index: int = option.get_item_count()
		option.add_item("%s（未找到）" % current_initial_state, index)
		option.set_item_metadata(index, current_initial_state)
		option.select(index)


static func _get_editor_state_name(state: Node) -> StringName:
	var state_name_value: Variant = _read_property(state, &"state_name")
	var state_name: StringName = GFVariantData.to_string_name(state_name_value)
	if state_name != &"":
		return state_name

	return StringName(state.name)


func _get_initial_state(target: Node) -> StringName:
	var config: Resource = _variant_to_resource(_read_property(target, &"config"))
	if config != null and "initial_state" in config:
		return GFVariantData.to_string_name(_read_property(config, &"initial_state"))
	return GFVariantData.to_string_name(_read_property(target, &"initial_state"))


func _set_initial_state(target: Node, state_name: StringName) -> void:
	var property_owner: Object = target
	var property_name: StringName = &"initial_state"
	var config: Resource = _variant_to_resource(_read_property(target, &"config"))
	if config != null and "initial_state" in config:
		property_owner = config

	var old_value: StringName = GFVariantData.to_string_name(_read_property(property_owner, property_name))
	if old_value == state_name:
		return

	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("设置 GF 初始状态")
	undo_redo.add_do_property(property_owner, property_name, state_name)
	undo_redo.add_undo_property(property_owner, property_name, old_value)
	undo_redo.commit_action()


func _update_validation_report(label: Label, target: Node) -> void:
	if label == null or not is_instance_valid(target):
		return

	if not (target is GFNodeStateMachine):
		return
	var machine: GFNodeStateMachine = target
	var report: GFValidationReport = _GF_NODE_STATE_MACHINE_VALIDATOR.validate_machine(machine)
	label.text = report.make_summary("GFNodeStateMachine")
	label.tooltip_text = format_report_tooltip(report)
	if report.get_error_count() > 0:
		label.modulate = Color(1.0, 0.45, 0.35)
	elif report.get_warning_count() > 0:
		label.modulate = Color(1.0, 0.78, 0.35)
	else:
		label.modulate = Color(0.45, 0.9, 0.55)


static func _variant_to_resource(value: Variant) -> Resource:
	if value is Resource:
		var resource: Resource = value
		return resource
	return null


static func _append_packed_string(target: PackedStringArray, value: String) -> void:
	var appended: bool = target.append(value)
	if appended:
		return


static func _read_property(object: Object, property_name: StringName, fallback: Variant = null) -> Variant:
	return GFObjectPropertyTools.read_property(object, NodePath(property_name), fallback)


# --- 信号处理函数 ---

func _on_initial_state_selected(index: int, option: OptionButton, target: Node) -> void:
	if not is_instance_valid(target):
		return

	var state_name: StringName = GFVariantData.to_string_name(option.get_item_metadata(index))
	_set_initial_state(target, state_name)


func _on_validate_pressed(label: Label, target: Node) -> void:
	_update_validation_report(label, target)
