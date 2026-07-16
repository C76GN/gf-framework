@tool

## 测试 GFNodeStateMachineValidator 的结构校验报告。
extends GutTest


# --- 常量 ---

const GFNodeStateMachineInspectorPluginScript = preload("res://addons/gf/standard/state_machine/node/editor/gf_node_state_machine_inspector_plugin.gd")


# --- 辅助子类 ---

class MethodTrapNodeState:
	extends GFNodeState

	var get_state_name_called: bool = false

	func get_state_name() -> StringName:
		get_state_name_called = true
		return &"method_name"


class MethodTrapNodeStateGroup:
	extends GFNodeStateGroup

	var get_group_name_called: bool = false

	func get_group_name() -> StringName:
		get_group_name_called = true
		return &"method_group"


# --- 测试 ---

func test_validator_reports_duplicate_state_names_and_missing_initial() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle_a: GFNodeState = GFNodeState.new()
	var idle_b: GFNodeState = GFNodeState.new()
	idle_a.name = "IdleA"
	idle_b.name = "IdleB"
	idle_a.state_name = &"idle"
	idle_b.state_name = &"idle"
	machine.add_child(idle_a)
	machine.add_child(idle_b)

	var report: GFValidationReport = GFNodeStateMachineValidator.validate_machine(machine)
	var counts: Dictionary = report.get_issue_counts_by_kind()

	assert_gt(report.get_error_count(), 0, "重复状态名应产生错误。")
	assert_eq(GFVariantData.get_option_int(counts, "duplicate_state_name"), 1, "应报告同组重复状态名。")
	assert_eq(GFVariantData.get_option_int(counts, "missing_initial_state"), 1, "自动启动状态机缺少初始状态时应给出警告。")

	machine.free()


func test_state_machine_inspector_tooltip_formats_validation_issue_objects() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle_a: GFNodeState = GFNodeState.new()
	var idle_b: GFNodeState = GFNodeState.new()
	idle_a.name = "IdleA"
	idle_b.name = "IdleB"
	idle_a.state_name = &"idle"
	idle_b.state_name = &"idle"
	machine.add_child(idle_a)
	machine.add_child(idle_b)

	var report: GFValidationReport = GFNodeStateMachineValidator.validate_machine(machine)
	var tooltip: String = GFNodeStateMachineInspectorPluginScript.format_report_tooltip(report)

	assert_true(tooltip.contains("duplicate_state_name"), "Inspector tooltip 应能读取 GFValidationIssue.kind。")
	assert_true(tooltip.contains("State name is duplicated inside the group."), "Inspector tooltip 应能读取 GFValidationIssue.message。")

	machine.free()


func test_state_machine_configuration_warnings_reuse_validator_report() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()

	var warnings: PackedStringArray = machine._get_configuration_warnings()

	assert_eq(warnings.size(), 1, "空状态机应生成 Inspector 配置警告。")
	assert_true(warnings[0].contains("empty_state_machine"), "配置警告应保留校验问题类别。")

	machine.free()


func test_state_group_configuration_warnings_reuse_validator_report() -> void:
	var group: GFNodeStateGroup = GFNodeStateGroup.new()

	var warnings: PackedStringArray = group._get_configuration_warnings()

	assert_eq(warnings.size(), 1, "空状态组应生成 Inspector 配置警告。")
	assert_true(warnings[0].contains("empty_state_group"), "配置警告应保留校验问题类别。")

	group.free()


func test_manual_machine_can_validate_without_initial_state() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	machine.start_mode = GFNodeStateMachine.StartMode.MANUAL
	var idle: GFNodeState = GFNodeState.new()
	idle.name = "Idle"
	machine.add_child(idle)

	var report: GFValidationReport = GFNodeStateMachineValidator.validate_machine(machine)

	assert_true(report.is_healthy(), "手动启动状态机允许不声明初始状态。")

	machine.free()


func test_validator_reads_state_name_without_calling_state_script_method() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	machine.initial_state = &"idle"
	var idle: MethodTrapNodeState = MethodTrapNodeState.new()
	idle.name = "Idle"
	idle.state_name = &"idle"
	machine.add_child(idle)

	var report: GFValidationReport = GFNodeStateMachineValidator.validate_machine(machine)

	assert_true(report.is_healthy(), "校验器应通过导出属性读取状态名。")
	assert_false(idle.get_state_name_called, "编辑器校验不应调用状态脚本方法，避免 placeholder 报错。")

	machine.free()


func test_validator_reads_group_name_without_calling_group_script_method() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var group: MethodTrapNodeStateGroup = MethodTrapNodeStateGroup.new()
	group.name = "Movement"
	group.group_name = &"movement"
	group.initial_state = &"idle"
	var idle: GFNodeState = GFNodeState.new()
	idle.name = "Idle"
	idle.state_name = &"idle"
	group.add_child(idle)
	machine.add_child(group)

	var report: GFValidationReport = GFNodeStateMachineValidator.validate_machine(machine)

	assert_true(report.is_healthy(), "校验器应通过导出属性读取状态组名。")
	assert_false(group.get_group_name_called, "编辑器校验不应调用状态组脚本方法，避免 placeholder 报错。")

	machine.free()


func test_validator_includes_runtime_registered_groups() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: GFNodeState = GFNodeState.new()
	group.name = "Runtime"
	group.group_name = &"runtime"
	group.initial_state = &"missing"
	group.auto_start = false
	idle.name = "Idle"
	idle.state_name = &"idle"
	group.add_state(idle)
	machine.add_state_group(group)

	var report: GFValidationReport = GFNodeStateMachineValidator.validate_machine(machine)
	var counts: Dictionary = report.get_issue_counts_by_kind()

	assert_eq(GFVariantData.get_option_int(counts, "invalid_initial_state"), 1, "运行时注册但非子节点的状态组也应被 validate_machine 校验。")
	assert_eq(GFVariantData.get_option_int(report.metadata, "group_count"), 1, "运行时注册组应计入状态机 group_count。")

	var _removed: bool = machine.remove_state_group(group)
	group.clear_states(false)
	machine.free()
	idle.free()
	group.free()


func test_validator_reports_invalid_initial_state_and_resource_slots() -> void:
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	group.name = "Movement"
	group.initial_state = &"missing"
	var idle: GFNodeState = GFNodeState.new()
	idle.name = "Idle"
	idle.enter_conditions.append(Resource.new())
	idle.behaviors.append(Resource.new())
	group.add_child(idle)

	var report: GFValidationReport = GFNodeStateMachineValidator.validate_group(group)
	var counts: Dictionary = report.get_issue_counts_by_kind()

	assert_eq(GFVariantData.get_option_int(counts, "invalid_initial_state"), 1, "不存在的初始状态应产生错误。")
	assert_eq(GFVariantData.get_option_int(counts, "invalid_state_resource"), 1, "缺少 evaluate() 的条件资源应产生错误。")
	assert_eq(GFVariantData.get_option_int(counts, "inert_state_behavior"), 1, "无生命周期钩子的行为资源应产生警告。")

	group.free()


func test_state_machine_dock_scans_scene_root_and_reports_selected_machine() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	machine.name = "StateMachine"
	machine.initial_state = &"idle"
	var idle: GFNodeState = GFNodeState.new()
	idle.name = "Idle"
	idle.state_name = &"idle"
	machine.add_child(idle)
	root.add_child(machine)
	var dock: GFNodeStateMachineDock = GFNodeStateMachineDock.new()

	dock.set_state_machine_source(root)
	var report: Dictionary = dock.get_last_report()

	assert_eq(dock.get_machine_count(), 1, "状态机工具面板应能扫描场景根节点。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效状态机应在工具面板报告为通过。")

	dock.free()
	root.free()


func test_state_machine_dock_uses_compact_empty_state() -> void:
	var root: Node = Node.new()
	var dock: GFNodeStateMachineDock = GFNodeStateMachineDock.new()

	dock.set_state_machine_source(root)

	assert_true(dock._empty_label.visible, "没有状态机时应显示空状态。")
	assert_false(dock._tree.visible, "没有状态机时不应显示空表格。")
	assert_false(dock._details.visible, "没有状态机时不应留下空详情面板。")

	dock.free()
	root.free()
