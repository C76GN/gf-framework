## 测试 GFNodeStateMachine 的节点状态加载、切换和跨组切换。
extends GutTest


# --- 常量 ---

const GFNodeStateMachineInspectorPluginScript = preload("res://addons/gf/standard/state_machine/node/editor/gf_node_state_machine_inspector_plugin.gd")


# --- 辅助子类 ---

class TrackingNodeState:
	extends GFNodeState

	var enter_count: int = 0
	var exit_count: int = 0
	var pause_count: int = 0
	var resume_count: int = 0
	var initialized_count: int = 0
	var last_previous: StringName = &""
	var last_next: StringName = &""
	var last_args: Dictionary = {}

	func _initialize() -> void:
		initialized_count += 1

	func _enter(previous_state: StringName = &"", args: Dictionary = {}) -> void:
		enter_count += 1
		last_previous = previous_state
		last_args = args

	func _exit(next_state: StringName = &"", args: Dictionary = {}) -> void:
		exit_count += 1
		last_next = next_state
		last_args = args

	func _pause(next_state: StringName = &"", args: Dictionary = {}) -> void:
		pause_count += 1
		last_next = next_state
		last_args = args

	func _resume(previous_state: StringName = &"", args: Dictionary = {}) -> void:
		resume_count += 1
		last_previous = previous_state
		last_args = args


class ExitRedirectNodeState:
	extends TrackingNodeState

	var target_state_name: StringName = &""

	func _init(p_target_state_name: StringName) -> void:
		target_state_name = p_target_state_name

	func _exit(next_state: StringName = &"", args: Dictionary = {}) -> void:
		super._exit(next_state, args)
		transition_to(target_state_name, args)


class ReadyHost:
	extends Node

	var ready_called: bool = false

	func _ready() -> void:
		ready_called = true


class HostReadyTrackingNodeState:
	extends TrackingNodeState

	var host_ready_at_enter: bool = false

	func _enter(previous_state: StringName = &"", args: Dictionary = {}) -> void:
		super._enter(previous_state, args)
		var host_node: Node = get_host()
		host_ready_at_enter = false
		if host_node is ReadyHost:
			var ready_host: ReadyHost = host_node
			host_ready_at_enter = ready_host.ready_called


class GuardedNodeState:
	extends TrackingNodeState

	var allow_enter: bool = true
	var allow_exit: bool = true

	func _can_enter(_previous_state: StringName = &"", _args: Dictionary = {}) -> bool:
		return allow_enter

	func _can_exit(_next_state: StringName = &"", _args: Dictionary = {}) -> bool:
		return allow_exit


class EventHandlingNodeState:
	extends TrackingNodeState

	var handled_events: Array[StringName] = []
	var events: Array[String] = []

	func _handle_state_event(event_id: StringName, _payload: Variant = null) -> bool:
		if handled_events.has(event_id):
			events.append("handle:%s:%s" % [get_state_name(), event_id])
			return true
		events.append("miss:%s:%s" % [get_state_name(), event_id])
		return false


class DummyModel:
	extends GFModel


class DummySystem:
	extends GFSystem


class DummyUtility:
	extends GFUtility


class StateEventPayload:
	extends RefCounted

	var value: int = 0

	func _init(p_value: int = 0) -> void:
		value = p_value


class DerivedStateEventPayload:
	extends StateEventPayload

	func _init(p_value: int = 0) -> void:
		super._init(p_value)


class DummyCommand:
	extends GFCommand

	func execute() -> Variant:
		return get_utility(DummyUtility)


class DummyQuery:
	extends GFQuery

	func execute() -> Variant:
		return get_utility(DummyUtility)


class SampleNodeContext:
	extends GFNodeContext

	var model: DummyModel = DummyModel.new()
	var system: DummySystem = DummySystem.new()
	var utility: DummyUtility = DummyUtility.new()

	func install(architecture_instance: GFArchitecture) -> void:
		await architecture_instance.register_model_instance(model)
		await architecture_instance.register_system_instance(system)
		await architecture_instance.register_utility_instance(utility)


class EventListeningNodeState:
	extends TrackingNodeState

	var typed_values: Array[int] = []
	var assignable_values: Array[int] = []
	var simple_values: Array = []

	func _enter(previous_state: StringName = &"", args: Dictionary = {}) -> void:
		super._enter(previous_state, args)
		register_event(StateEventPayload, _on_typed_event)
		register_assignable_event(StateEventPayload, _on_assignable_event)
		register_simple_event(&"node_state_simple_event", _on_simple_event)

	func _exit(next_state: StringName = &"", args: Dictionary = {}) -> void:
		super._exit(next_state, args)
		unregister_owner_events()

	func _on_typed_event(payload: StateEventPayload) -> void:
		typed_values.append(payload.value)

	func _on_assignable_event(payload: StateEventPayload) -> void:
		assignable_values.append(payload.value)

	func _on_simple_event(payload: Variant) -> void:
		simple_values.append(payload)


# --- 测试 ---

func test_internal_group_loads_direct_child_states() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var run: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	run.name = "Run"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(run)

	await get_tree().process_frame

	assert_eq(machine.get_current_state(), idle, "直接子状态应进入内部状态组。")
	assert_eq(idle.enter_count, 1, "初始状态应被进入。")
	assert_eq(run.initialized_count, 1, "未激活状态也应完成初始化。")


func test_editor_inspector_collects_state_names_from_exports() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: GFNodeState = GFNodeState.new()
	idle.name = "IdleNode"
	idle.state_name = &"idle"
	var run: GFNodeState = GFNodeState.new()
	run.name = "Run"
	machine.add_child(idle)
	machine.add_child(run)

	var states: Array[StringName] = GFNodeStateMachineInspectorPluginScript.collect_direct_states(machine)

	assert_eq(states.size(), 2, "Inspector 应收集直接子状态。")
	assert_has(states, &"idle", "Inspector 应优先使用导出的 state_name。")
	assert_has(states, &"Run", "state_name 为空时应退回节点名称。")

	machine.free()


func test_manual_start_mode_loads_without_entering_initial_state() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var run: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	run.name = "Run"
	machine.initial_state = &"Idle"
	machine.start_mode = GFNodeStateMachine.StartMode.MANUAL
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(run)

	await get_tree().process_frame

	assert_null(machine.get_current_state(), "手动启动模式只应加载状态，不应自动进入初始状态。")
	assert_eq(idle.initialized_count, 1, "手动启动模式仍应初始化状态。")
	assert_eq(idle.enter_count, 0, "手动启动前不应调用状态 enter。")

	machine.start()

	assert_eq(machine.get_current_state(), idle, "start() 应进入内部初始状态。")
	assert_eq(idle.enter_count, 1, "start() 应调用初始状态 enter。")


func test_start_can_reload_when_reload_on_ready_is_disabled() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	machine.initial_state = &"Idle"
	machine.reload_on_ready = false
	machine.start_mode = GFNodeStateMachine.StartMode.MANUAL
	add_child_autofree(machine)
	machine.add_child(idle)

	await get_tree().process_frame

	assert_null(machine.get_state_group(GFNodeStateMachine.INTERNAL_GROUP_NAME), "关闭 reload_on_ready 时不应自动加载状态组。")

	machine.start()

	assert_eq(machine.get_current_state(), idle, "start() 应在需要时先加载子状态再进入初始状态。")
	assert_eq(idle.enter_count, 1, "延迟加载后应进入初始状态。")


func test_runtime_helper_child_does_not_reload_internal_states() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	await get_tree().process_frame

	var initialized_count: int = idle.initialized_count
	var enter_count: int = idle.enter_count
	var exit_count: int = idle.exit_count
	var helper: Node = Node.new()
	helper.name = "Helper"
	machine.add_child(helper)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(idle.initialized_count, initialized_count, "运行时加入普通辅助子节点不应重载内部状态组。")
	assert_eq(idle.enter_count, enter_count, "运行时加入普通辅助子节点不应重新进入当前状态。")
	assert_eq(idle.exit_count, exit_count, "运行时加入普通辅助子节点不应退出当前状态。")


func test_runtime_state_child_reloads_internal_states() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var run: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	run.name = "Run"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	await get_tree().process_frame

	machine.add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	var group: GFNodeStateGroup = machine.get_state_group(GFNodeStateMachine.INTERNAL_GROUP_NAME)
	assert_eq(group.get_state(&"Run"), run, "运行时加入状态子节点应重新加载内部状态组。")
	assert_eq(run.initialized_count, 1, "动态加入的状态应完成初始化。")
	assert_eq(machine.get_current_state(), idle, "重载后应尽量保持当前状态。")


func test_default_start_mode_waits_for_host_ready() -> void:
	var host: ReadyHost = ReadyHost.new()
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: HostReadyTrackingNodeState = HostReadyTrackingNodeState.new()
	idle.name = "Idle"
	machine.initial_state = &"Idle"
	host.add_child(machine)
	machine.add_child(idle)
	add_child_autofree(host)

	await get_tree().process_frame

	assert_true(host.ready_called, "测试宿主应已进入 ready。")
	assert_eq(machine.start_mode, GFNodeStateMachine.StartMode.AFTER_HOST_READY, "2.0 默认应等待宿主 ready 后启动。")
	assert_eq(machine.get_current_state(), idle, "默认启动模式应在宿主 ready 后进入初始状态。")
	assert_true(idle.host_ready_at_enter, "状态 enter 发生时宿主应已经 ready。")


func test_on_ready_start_mode_can_be_selected_for_legacy_order() -> void:
	var host: ReadyHost = ReadyHost.new()
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: HostReadyTrackingNodeState = HostReadyTrackingNodeState.new()
	idle.name = "Idle"
	machine.initial_state = &"Idle"
	machine.start_mode = GFNodeStateMachine.StartMode.ON_READY
	host.add_child(machine)
	machine.add_child(idle)
	add_child_autofree(host)

	await get_tree().process_frame

	assert_true(host.ready_called, "测试宿主应已进入 ready。")
	assert_eq(machine.get_current_state(), idle, "旧启动模式仍应自动进入初始状态。")
	assert_false(idle.host_ready_at_enter, "显式 ON_READY 时状态 enter 可早于宿主 ready。")


func test_manual_start_mode_prevents_external_group_auto_start() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var body_group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	body_group.name = "Body"
	body_group.group_name = &"Body"
	body_group.initial_state = &"Idle"
	idle.name = "Idle"
	machine.start_mode = GFNodeStateMachine.StartMode.MANUAL
	add_child_autofree(machine)
	machine.add_child(body_group)
	body_group.add_child(idle)

	await get_tree().process_frame

	assert_null(body_group.get_current_state(), "手动启动模式下外部状态组也不应自动启动。")

	machine.start()

	assert_eq(body_group.get_current_state(), idle, "start() 应启动已加载的外部状态组。")
	assert_eq(idle.enter_count, 1, "外部状态组初始状态应被进入一次。")


func test_state_group_auto_start_can_be_disabled() -> void:
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	group.name = "Body"
	group.group_name = &"Body"
	group.initial_state = &"Idle"
	group.auto_start = false
	idle.name = "Idle"
	add_child_autofree(group)
	group.add_child(idle)

	await get_tree().process_frame

	assert_null(group.get_current_state(), "auto_start 关闭后状态组 ready 时不应进入初始状态。")
	assert_eq(idle.initialized_count, 1, "auto_start 关闭后仍应加载并初始化状态。")

	group.start()

	assert_eq(group.get_current_state(), idle, "状态组 start() 应进入初始状态。")
	assert_eq(idle.enter_count, 1, "状态组 start() 应调用初始状态 enter。")


func test_runtime_helper_child_does_not_reload_state_group() -> void:
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	group.name = "Body"
	group.group_name = &"Body"
	group.initial_state = &"Idle"
	idle.name = "Idle"
	group.add_child(idle)
	add_child_autofree(group)
	await get_tree().process_frame

	var initialized_count: int = idle.initialized_count
	var enter_count: int = idle.enter_count
	var exit_count: int = idle.exit_count
	var helper: Node = Node.new()
	helper.name = "Helper"
	group.add_child(helper)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(idle.initialized_count, initialized_count, "运行时加入普通辅助子节点不应重载状态组。")
	assert_eq(idle.enter_count, enter_count, "运行时加入普通辅助子节点不应重新进入当前状态。")
	assert_eq(idle.exit_count, exit_count, "运行时加入普通辅助子节点不应退出当前状态。")


func test_runtime_state_child_reloads_state_group() -> void:
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var run: TrackingNodeState = TrackingNodeState.new()
	group.name = "Body"
	group.group_name = &"Body"
	group.initial_state = &"Idle"
	idle.name = "Idle"
	run.name = "Run"
	group.add_child(idle)
	add_child_autofree(group)
	await get_tree().process_frame

	group.add_child(run)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(group.get_state(&"Run"), run, "运行时加入状态子节点应重新加载状态组。")
	assert_eq(run.initialized_count, 1, "动态加入的状态应完成初始化。")
	assert_eq(group.get_current_state(), idle, "状态组重载后应回到初始状态。")


func test_transition_to_changes_internal_state() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var run: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	run.name = "Run"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(run)
	await get_tree().process_frame
	watch_signals(machine)

	machine.transition_to(&"Run", { "speed": 5 })

	assert_eq(idle.exit_count, 1, "切换状态应退出旧状态。")
	assert_eq(idle.last_next, &"Run", "旧状态应收到目标状态名。")
	assert_eq(run.enter_count, 1, "切换状态应进入新状态。")
	assert_eq(run.last_previous, &"Idle", "新状态应收到来源状态名。")
	assert_eq(GFVariantData.get_option_int(run.last_args, "speed"), 5, "切换参数应传给新状态。")
	assert_signal_emitted_with_parameters(
		machine,
		"state_changed",
		[machine.get_state_group(GFNodeStateMachine.INTERNAL_GROUP_NAME), idle, run]
	)
	var current_state: GFNodeState = machine.get_current_state()
	assert_eq(current_state, run, "节点状态机当前状态 getter 应返回 GFNodeState。")


func test_node_state_proxy_methods_without_architecture_are_safe() -> void:
	var state: TrackingNodeState = TrackingNodeState.new()
	autofree(state)

	state.send_event(StateEventPayload.new())
	state.send_simple_event(&"node_state_simple_event")

	assert_null(state.get_model(DummyModel), "未挂入架构上下文的 NodeState.get_model 应安全返回 null。")
	assert_null(state.get_system(DummySystem), "未挂入架构上下文的 NodeState.get_system 应安全返回 null。")
	assert_null(state.get_utility(DummyUtility), "未挂入架构上下文的 NodeState.get_utility 应安全返回 null。")
	assert_true(_is_null(state.send_command(DummyCommand.new())), "未挂入架构上下文的 NodeState.send_command 应安全返回 null。")
	assert_true(_is_null(state.send_query(DummyQuery.new())), "未挂入架构上下文的 NodeState.send_query 应安全返回 null。")


func test_node_state_uses_nearest_context_for_dependencies_commands_and_queries() -> void:
	var context: SampleNodeContext = SampleNodeContext.new()
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	machine.initial_state = &"Idle"
	context.add_child(machine)
	machine.add_child(idle)
	add_child_autofree(context)

	await context.wait_until_ready()
	await get_tree().process_frame

	assert_eq(idle.get_model(DummyModel), context.model, "NodeState.get_model 应解析最近 GFNodeContext。")
	assert_eq(idle.get_system(DummySystem), context.system, "NodeState.get_system 应解析最近 GFNodeContext。")
	assert_eq(idle.get_utility(DummyUtility), context.utility, "NodeState.get_utility 应解析最近 GFNodeContext。")
	assert_eq(_dummy_utility(idle.send_command(DummyCommand.new())), context.utility, "NodeState.send_command 应使用状态机上下文架构。")
	assert_eq(_dummy_utility(idle.send_query(DummyQuery.new())), context.utility, "NodeState.send_query 应使用状态机上下文架构。")

	context.queue_free()
	await get_tree().process_frame


func test_node_state_can_register_events_through_context_architecture() -> void:
	var context: SampleNodeContext = SampleNodeContext.new()
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var listen: EventListeningNodeState = EventListeningNodeState.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	listen.name = "Listen"
	idle.name = "Idle"
	machine.initial_state = &"Listen"
	context.add_child(machine)
	machine.add_child(listen)
	machine.add_child(idle)
	add_child_autofree(context)

	await context.wait_until_ready()
	await get_tree().process_frame
	var architecture: GFArchitecture = context.get_architecture()

	architecture.send_event(StateEventPayload.new(3))
	architecture.send_event(DerivedStateEventPayload.new(5))
	architecture.send_simple_event(&"node_state_simple_event", "tick")

	assert_eq(listen.typed_values, [3], "NodeState.register_event 应监听精确类型事件。")
	assert_eq(listen.assignable_values, [3, 5], "NodeState.register_assignable_event 应监听基类与派生类型事件。")
	assert_eq(listen.simple_values, ["tick"], "NodeState.register_simple_event 应监听轻量事件。")

	machine.transition_to(&"Idle")
	architecture.send_event(StateEventPayload.new(7))
	architecture.send_event(DerivedStateEventPayload.new(9))
	architecture.send_simple_event(&"node_state_simple_event", "late")

	assert_eq(listen.typed_values, [3], "状态退出后 unregister_owner_events 应移除类型事件监听。")
	assert_eq(listen.assignable_values, [3, 5], "状态退出后 unregister_owner_events 应移除可赋值事件监听。")
	assert_eq(listen.simple_values, ["tick"], "状态退出后 unregister_owner_events 应移除轻量事件监听。")

	context.queue_free()
	await get_tree().process_frame


func test_state_can_request_cross_group_transition() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var body_group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var attack: TrackingNodeState = TrackingNodeState.new()
	body_group.name = "Body"
	body_group.group_name = &"Body"
	body_group.initial_state = &"Idle"
	idle.name = "Idle"
	attack.name = "Attack"
	add_child_autofree(machine)
	machine.add_child(body_group)
	body_group.add_child(idle)
	body_group.add_child(attack)
	await get_tree().process_frame

	idle.transition_to(&"Body/Attack")

	assert_eq(body_group.get_current_state(), attack, "状态应能通过 Group/State 请求跨组切换。")
	assert_eq(idle.exit_count, 1, "跨组切换应退出旧状态。")
	assert_eq(attack.enter_count, 1, "跨组切换应进入目标状态。")


func test_transition_requested_during_exit_replaces_outer_target() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: ExitRedirectNodeState = ExitRedirectNodeState.new(&"Attack")
	var run: TrackingNodeState = TrackingNodeState.new()
	var attack: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	run.name = "Run"
	attack.name = "Attack"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(run)
	machine.add_child(attack)
	await get_tree().process_frame

	machine.transition_to(&"Run")

	assert_eq(idle.exit_count, 1, "exit 内部请求切换时，旧状态不应重复 exit。")
	assert_eq(run.enter_count, 0, "exit 内部请求的新状态应替代外层目标。")
	assert_eq(attack.enter_count, 1, "exit 内部请求的状态应成为最终状态。")
	assert_eq(machine.get_current_state(), attack, "最终当前状态应为 exit 内部请求的状态。")


func test_transition_to_redirect_does_not_reexit_current_state_when_stacked_state_redirects() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var menu: ExitRedirectNodeState = ExitRedirectNodeState.new(&"Inventory")
	var confirm: ExitRedirectNodeState = ExitRedirectNodeState.new(&"Combat")
	var run: TrackingNodeState = TrackingNodeState.new()
	var combat: TrackingNodeState = TrackingNodeState.new()
	var inventory: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	menu.name = "Menu"
	confirm.name = "Confirm"
	run.name = "Run"
	combat.name = "Combat"
	inventory.name = "Inventory"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(menu)
	machine.add_child(confirm)
	machine.add_child(run)
	machine.add_child(combat)
	machine.add_child(inventory)
	await get_tree().process_frame

	machine.push_state(&"Menu")
	machine.push_state(&"Confirm")
	machine.transition_to(&"Run")

	assert_eq(confirm.exit_count, 1, "当前叠加状态的 exit 重定向不应导致当前状态重复 exit。")
	assert_eq(menu.exit_count, 1, "被丢弃的暂停状态应只退出一次。")
	assert_eq(idle.exit_count, 1, "更早的暂停状态应按最终重定向目标退出。")
	assert_eq(run.enter_count, 0, "外层目标应被当前状态 exit 重定向替换。")
	assert_eq(combat.enter_count, 0, "较早的重定向目标应被暂停栈退出重定向替换。")
	assert_eq(inventory.enter_count, 1, "暂停栈退出期间的最后一次重定向应成为最终状态。")
	assert_eq(machine.get_current_state(), inventory, "最终当前状态应为暂停栈退出期间请求的目标。")
	assert_eq(machine.get_stack_depth(), 0, "重定向切换后暂停栈应清空。")


func test_push_and_pop_state_uses_pause_and_resume() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var menu: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	menu.name = "Menu"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(menu)
	await get_tree().process_frame

	machine.push_state(&"Menu", { "modal": true })

	assert_eq(machine.get_current_state(), menu, "push_state 后当前状态应为子状态。")
	assert_eq(machine.get_stack_depth(), 1, "push_state 应压入上一层状态。")
	assert_eq(idle.pause_count, 1, "push_state 应暂停旧状态而不是退出旧状态。")
	assert_eq(idle.exit_count, 0, "push_state 不应触发旧状态 exit。")
	assert_true(machine.is_in_state(&"Idle"), "暂停栈中的状态应被视为仍处于状态机内。")
	assert_true(machine.is_in_state(&"Menu"), "当前子状态应被视为处于状态机内。")

	var popped: bool = machine.pop_state(GFNodeStateMachine.INTERNAL_GROUP_NAME, { "closed": true })

	assert_true(popped, "pop_state 有上一层状态时应返回 true。")
	assert_eq(machine.get_current_state(), idle, "pop_state 后应恢复上一层状态。")
	assert_eq(machine.get_stack_depth(), 0, "pop_state 后状态栈应为空。")
	assert_eq(menu.exit_count, 1, "pop_state 应退出当前子状态。")
	assert_eq(idle.resume_count, 1, "pop_state 应恢复上一层状态。")
	assert_eq(idle.last_previous, &"Menu", "恢复状态应收到来源子状态名。")


func test_push_state_does_not_use_exit_guard_for_paused_state() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: GuardedNodeState = GuardedNodeState.new()
	var menu: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	idle.allow_exit = false
	menu.name = "Menu"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(menu)
	await get_tree().process_frame

	machine.push_state(&"Menu")

	assert_eq(machine.get_current_state(), menu, "push_state 是暂停叠加，不应被当前状态 exit guard 阻止。")
	assert_eq(idle.pause_count, 1, "push_state 应暂停旧状态。")
	assert_eq(idle.exit_count, 0, "push_state 不应退出旧状态。")


func test_remove_state_uses_registration_key_after_state_rename() -> void:
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	var state: TrackingNodeState = TrackingNodeState.new()
	state.state_name = &"Idle"
	group.add_state(state)
	state.state_name = &"Renamed"

	var removed: bool = group.remove_state(state)

	assert_true(removed, "移除状态应使用注册 key，不应受节点后续改名影响。")
	assert_null(group.get_state(&"Idle"), "移除后注册 key 应清理。")


func test_remove_state_group_uses_registration_key_after_group_rename() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	group.group_name = &"External"
	machine.add_state_group(group)
	group.group_name = &"Renamed"

	var removed: bool = machine.remove_state_group(group)

	assert_true(removed, "移除状态组应使用注册 key，不应受节点后续改名影响。")
	assert_null(machine.get_state_group(&"External"), "移除后注册 group key 应清理。")


func test_pop_state_redirect_does_not_reexit_current_state_when_stacked_state_redirects() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var menu: ExitRedirectNodeState = ExitRedirectNodeState.new(&"Inventory")
	var confirm: ExitRedirectNodeState = ExitRedirectNodeState.new(&"Combat")
	var combat: TrackingNodeState = TrackingNodeState.new()
	var inventory: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	menu.name = "Menu"
	confirm.name = "Confirm"
	combat.name = "Combat"
	inventory.name = "Inventory"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(menu)
	machine.add_child(confirm)
	machine.add_child(combat)
	machine.add_child(inventory)
	await get_tree().process_frame

	machine.push_state(&"Menu")
	machine.push_state(&"Confirm")
	var popped: bool = machine.pop_state(GFNodeStateMachine.INTERNAL_GROUP_NAME)

	assert_true(popped, "pop_state 有暂停栈时应成功。")
	assert_eq(confirm.exit_count, 1, "当前子状态的 exit 重定向不应导致当前状态重复 exit。")
	assert_eq(menu.exit_count, 1, "被丢弃的暂停状态应只退出一次。")
	assert_eq(idle.exit_count, 1, "更早的暂停状态应按最终重定向目标退出。")
	assert_eq(combat.enter_count, 0, "较早的重定向目标应被后续退出重定向替换。")
	assert_eq(inventory.enter_count, 1, "暂停栈退出期间的最后一次重定向应成为最终状态。")
	assert_eq(machine.get_current_state(), inventory, "最终当前状态应为暂停栈退出期间请求的目标。")
	assert_eq(machine.get_stack_depth(), 0, "重定向切换后暂停栈应清空。")


func test_remove_current_pushed_state_restores_paused_state() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var menu: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	menu.name = "Menu"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(menu)
	await get_tree().process_frame

	machine.push_state(&"Menu")
	var group: GFNodeStateGroup = machine.get_state_group(GFNodeStateMachine.INTERNAL_GROUP_NAME)
	watch_signals(group)
	var removed: bool = group.remove_state(menu)

	assert_true(removed, "移除当前叠加状态应成功。")
	assert_eq(machine.get_current_state(), idle, "移除当前叠加状态后应恢复上一层状态。")
	assert_eq(machine.get_stack_depth(), 0, "恢复后状态栈应为空。")
	assert_eq(menu.exit_count, 1, "被移除的当前叠加状态应执行 exit。")
	assert_eq(idle.resume_count, 1, "暂停的上一层状态应执行 resume。")
	assert_eq(idle.last_previous, &"Menu", "恢复状态应收到被移除状态名。")
	assert_true(machine.is_in_state(&"Idle"), "恢复后的状态应被视为处于状态机内。")
	assert_false(machine.is_in_state(&"Menu"), "被移除的状态不应继续被视为处于状态机内。")
	assert_signal_emitted(group, "current_state_changed", "当前状态被恢复时应发出状态变化信号。")


func test_remove_current_state_honors_exit_redirect() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: ExitRedirectNodeState = ExitRedirectNodeState.new(&"Run")
	var run: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	run.name = "Run"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(run)
	await get_tree().process_frame

	var group: GFNodeStateGroup = machine.get_state_group(GFNodeStateMachine.INTERNAL_GROUP_NAME)
	var removed: bool = group.remove_state(idle)

	assert_true(removed, "移除当前状态应成功。")
	assert_eq(idle.exit_count, 1, "remove_state 应让当前状态执行一次 exit。")
	assert_eq(run.enter_count, 1, "当前状态 exit 中请求的目标应被安全进入。")
	assert_eq(machine.get_current_state(), run, "remove_state 后当前状态应为 exit 重定向目标。")
	assert_null(group.get_state(&"Idle"), "被移除状态应从状态组注册表删除。")


func test_config_controls_initial_state_and_history_limit() -> void:
	var config: Resource = GFNodeStateMachineConfig.new()
	config.set("initial_state", &"Run")
	config.set("history_max_size", 2)

	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var run: TrackingNodeState = TrackingNodeState.new()
	var attack: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	run.name = "Run"
	attack.name = "Attack"
	machine.set("config", config)
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(run)
	machine.add_child(attack)
	await get_tree().process_frame

	assert_eq(machine.get_current_state(), run, "配置资源应驱动内部状态组初始状态。")

	machine.transition_to(&"Idle")
	machine.transition_to(&"Attack")

	var history: Array[StringName] = machine.get_state_history()
	assert_eq(machine.get_current_state(), attack, "状态机应完成后续切换。")
	assert_eq(history.size(), 2, "状态历史应遵守配置资源容量。")
	assert_eq(history[0], &"Idle", "历史应保留最近状态。")
	assert_eq(history[1], &"Attack", "历史应保留最新状态。")


func test_state_can_access_machine_host() -> void:
	var host: Node = Node.new()
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	machine.initial_state = &"Idle"
	add_child_autofree(host)
	host.add_child(machine)
	machine.add_child(idle)
	await get_tree().process_frame

	assert_eq(idle.get_host(), host, "状态应能获取状态机所在宿主节点。")


func test_state_guard_can_block_transition() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: GuardedNodeState = GuardedNodeState.new()
	var run: GuardedNodeState = GuardedNodeState.new()
	idle.name = "Idle"
	run.name = "Run"
	run.allow_enter = false
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(run)
	await get_tree().process_frame

	var group: GFNodeStateGroup = machine.get_state_group(GFNodeStateMachine.INTERNAL_GROUP_NAME)
	watch_signals(group)
	machine.transition_to(&"Run")

	assert_eq(machine.get_current_state(), idle, "目标状态拒绝进入时应保持当前状态。")
	assert_eq(idle.exit_count, 0, "进入守卫失败时旧状态不应退出。")
	assert_signal_emitted(group, "transition_blocked", "守卫阻止切换时应发出 transition_blocked。")


func test_state_group_blackboard_is_shared_with_states() -> void:
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	group.name = "Body"
	group.group_name = &"Body"
	group.initial_state = &"Idle"
	group.auto_start = false
	idle.name = "Idle"
	add_child_autofree(group)
	group.add_child(idle)
	await get_tree().process_frame

	var blackboard: Dictionary = idle.get_blackboard()
	blackboard["speed"] = 4

	assert_eq(GFVariantData.get_option_int(group.blackboard, "speed"), 4, "状态应能访问并修改状态组共享黑板。")


func test_state_group_dispatches_event_from_current_to_stack() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: EventHandlingNodeState = EventHandlingNodeState.new()
	var menu: EventHandlingNodeState = EventHandlingNodeState.new()
	idle.name = "Idle"
	menu.name = "Menu"
	idle.handled_events.append(&"cancel")
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(menu)
	await get_tree().process_frame
	machine.push_state(&"Menu")
	var group: GFNodeStateGroup = machine.get_state_group(GFNodeStateMachine.INTERNAL_GROUP_NAME)
	watch_signals(group)

	var handled: bool = group.dispatch_state_event(&"cancel", { "source": "input" })

	assert_true(handled, "当前子状态未处理时，事件应继续交给暂停栈状态。")
	assert_eq(menu.events, ["miss:Menu:cancel"], "事件应先交给当前状态。")
	assert_eq(idle.events, ["handle:Idle:cancel"], "当前状态未处理后应交给暂停栈顶部。")
	assert_signal_emitted_with_parameters(group, "state_event_handled", [&"cancel", idle, { "source": "input" }])


func test_node_state_machine_dispatches_event_to_named_group_and_reemits() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var body_group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: EventHandlingNodeState = EventHandlingNodeState.new()
	body_group.name = "Body"
	body_group.group_name = &"Body"
	body_group.initial_state = &"Idle"
	idle.name = "Idle"
	idle.handled_events.append(&"hit")
	add_child_autofree(machine)
	machine.add_child(body_group)
	body_group.add_child(idle)
	await get_tree().process_frame
	watch_signals(machine)

	var handled: bool = machine.dispatch_state_event(&"hit", { "amount": 4 }, &"Body")

	assert_true(handled, "节点状态机应能向指定状态组派发状态事件。")
	assert_eq(idle.events, ["handle:Idle:hit"], "目标状态组当前状态应处理事件。")
	assert_signal_emitted_with_parameters(machine, "state_event_handled", [body_group, &"hit", idle, { "amount": 4 }])


func test_node_state_machine_snapshot_reports_groups() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var body_group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	body_group.name = "Body"
	body_group.group_name = &"Body"
	body_group.initial_state = &"Idle"
	body_group.blackboard["speed"] = 5
	idle.name = "Idle"
	add_child_autofree(machine)
	machine.add_child(body_group)
	body_group.add_child(idle)
	await get_tree().process_frame

	var snapshot: Dictionary = machine.get_state_snapshot()
	var groups: Dictionary = GFVariantData.get_option_dictionary(snapshot, "groups")
	var body_snapshot: Dictionary = GFVariantData.get_option_dictionary(groups, &"Body")
	var body_blackboard: Dictionary = GFVariantData.get_option_dictionary(body_snapshot, "blackboard")
	var body_states: Array = GFVariantData.get_option_array(body_snapshot, "states")

	assert_eq(GFVariantData.get_option_string_name(body_snapshot, "current_state"), &"Idle", "状态机快照应报告状态组当前状态。")
	assert_eq(GFVariantData.get_option_int(body_blackboard, "speed"), 5, "状态组快照应包含黑板副本。")
	assert_has(body_states, &"Idle", "状态组快照应包含已注册状态。")


func test_clear_state_groups_disconnects_external_group_signals() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	group.name = "Body"
	group.group_name = &"Body"
	add_child_autofree(machine)
	add_child_autofree(group)
	machine.add_state_group(group)
	watch_signals(machine)

	machine.clear_state_groups()
	group.current_state_changed.emit(null, null)

	assert_signal_not_emitted(machine, "state_changed", "清理状态组后旧 group 信号不应继续转发到状态机。")


func test_clear_state_groups_stops_external_group_without_removing_states() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	group.name = "Body"
	group.group_name = &"Body"
	group.initial_state = &"Idle"
	idle.name = "Idle"
	group.add_child(idle)
	machine.add_state_group(group)

	assert_eq(group.get_current_state(), idle, "测试准备应让外部状态组进入初始状态。")

	machine.clear_state_groups()

	assert_eq(idle.exit_count, 1, "清理状态组时外部组当前状态应执行 exit。")
	assert_null(group.get_current_state(), "清理状态组后外部组不应继续保持当前状态。")
	assert_eq(group.get_state(&"Idle"), idle, "默认清理状态组不应移除外部组已注册状态。")

	group.free()
	machine.free()


func test_clear_state_groups_with_free_detaches_group_immediately() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	group.name = "Body"
	group.group_name = &"Body"
	add_child_autofree(machine)
	machine.add_child(group)
	machine.add_state_group(group)

	machine.clear_state_groups(true)

	assert_null(group.get_parent(), "释放状态组时应立即从状态机节点下移除。")
	assert_false(machine.get_children().has(group), "状态机子节点不应残留已释放状态组。")

	await get_tree().process_frame
	assert_false(is_instance_valid(group), "下一帧状态组应完成释放。")


func test_clear_states_exits_current_and_stacked_states() -> void:
	var machine: GFNodeStateMachine = GFNodeStateMachine.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	var menu: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	menu.name = "Menu"
	machine.initial_state = &"Idle"
	add_child_autofree(machine)
	machine.add_child(idle)
	machine.add_child(menu)
	await get_tree().process_frame

	machine.push_state(&"Menu")
	var group: GFNodeStateGroup = machine.get_state_group(GFNodeStateMachine.INTERNAL_GROUP_NAME)
	group.clear_states(false)

	assert_eq(menu.exit_count, 1, "清空状态时当前状态应执行 exit。")
	assert_eq(idle.exit_count, 1, "清空状态时暂停栈状态也应执行 exit。")
	assert_eq(menu.process_mode, Node.PROCESS_MODE_DISABLED, "当前状态清空后应停止处理。")
	assert_eq(idle.process_mode, Node.PROCESS_MODE_DISABLED, "暂停栈状态清空后应保持停止处理。")


func test_clear_states_with_free_detaches_state_nodes_immediately() -> void:
	var group: GFNodeStateGroup = GFNodeStateGroup.new()
	var idle: TrackingNodeState = TrackingNodeState.new()
	idle.name = "Idle"
	group.initial_state = &"Idle"
	group.auto_start = false
	group.add_child(idle)
	add_child_autofree(group)
	await get_tree().process_frame

	group.clear_states(true)

	assert_null(idle.get_parent(), "释放状态时应立即从状态组节点下移除。")
	assert_false(group.get_children().has(idle), "状态组子节点不应残留已释放状态。")

	await get_tree().process_frame
	assert_false(is_instance_valid(idle), "下一帧状态节点应完成释放。")


func _dummy_utility(value: Variant) -> DummyUtility:
	if value is DummyUtility:
		var utility: DummyUtility = value
		return utility
	return null


func _is_null(value: Variant) -> bool:
	return value == null
