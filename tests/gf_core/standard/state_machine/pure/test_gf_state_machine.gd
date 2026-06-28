## 测试 GFStateMachine 的状态注册、切换、update 驱动及信号发送功能。
extends GutTest


# --- 私有变量 ---

var _fsm: GFStateMachine


# --- 辅助状态类 ---

class TrackingState:
	extends GFState

	var state_id: StringName = &""
	var enter_count: int = 0
	var exit_count: int = 0
	var update_count: int = 0
	var dispose_count: int = 0
	var last_msg: Dictionary = {}
	var events: Array[String] = []

	func _init(p_state_id: StringName = &"") -> void:
		state_id = p_state_id

	func enter(msg: Dictionary = {}) -> void:
		enter_count += 1
		last_msg = msg
		if state_id != &"":
			events.append("enter:%s" % state_id)

	func update(_delta: float) -> void:
		update_count += 1

	func exit() -> void:
		exit_count += 1
		if state_id != &"":
			events.append("exit:%s" % state_id)

	func dispose() -> void:
		dispose_count += 1
		super.dispose()

	func has_machine() -> bool:
		return _get_machine() != null


class RedirectState:
	extends TrackingState

	var target_state_name: StringName

	func _init(p_target_state_name: StringName) -> void:
		target_state_name = p_target_state_name

	func enter(msg: Dictionary = {}) -> void:
		super.enter(msg)
		change_state(target_state_name)


class ExitRedirectState:
	extends TrackingState

	var target_state_name: StringName

	func _init(p_target_state_name: StringName) -> void:
		target_state_name = p_target_state_name

	func exit() -> void:
		super.exit()
		change_state(target_state_name)


class GuardedState:
	extends TrackingState

	var allow_enter: bool = true
	var allow_exit: bool = true

	func can_enter(_previous_state: StringName = &"", _msg: Dictionary = {}) -> bool:
		return allow_enter

	func can_exit(_next_state: StringName = &"", _msg: Dictionary = {}) -> bool:
		return allow_exit


class EventHandlingState:
	extends TrackingState

	var handled_events: Array[StringName] = []

	func handle_state_event(event_id: StringName, _payload: Variant = null) -> bool:
		if handled_events.has(event_id):
			events.append("handle:%s:%s" % [state_id, event_id])
			return true
		events.append("miss:%s:%s" % [state_id, event_id])
		return false


class DummyModel:
	extends GFModel


class DummySystem:
	extends GFSystem


class DummyUtility:
	extends GFUtility


class ContextUtility:
	extends GFUtility


class ContextHolder:
	extends RefCounted


class StateEventPayload:
	extends RefCounted

	var value: int = 0

	func _init(p_value: int = 0) -> void:
		value = p_value


class DerivedStateEventPayload:
	extends StateEventPayload

	func _init(p_value: int = 0) -> void:
		super._init(p_value)


class EventListeningState:
	extends TrackingState

	var typed_values: Array[int] = []
	var assignable_values: Array[int] = []
	var simple_values: Array = []
	var unregister_on_exit: bool = true

	func enter(msg: Dictionary = {}) -> void:
		super.enter(msg)
		register_event(StateEventPayload, _on_typed_event)
		register_assignable_event(StateEventPayload, _on_assignable_event)
		register_simple_event(&"state_simple_event", _on_simple_event)

	func exit() -> void:
		super.exit()
		if unregister_on_exit:
			unregister_owner_events()

	func _on_typed_event(payload: StateEventPayload) -> void:
		typed_values.append(payload.value)

	func _on_assignable_event(payload: StateEventPayload) -> void:
		assignable_values.append(payload.value)

	func _on_simple_event(payload: Variant) -> void:
		simple_values.append(payload)


class DummyCommand:
	extends GFCommand

	func execute() -> Variant:
		return get_utility(DummyUtility)


class DummyQuery:
	extends GFQuery

	func execute() -> Variant:
		return get_utility(DummyUtility)


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_fsm = GFStateMachine.new()


func after_each() -> void:
	if _fsm != null:
		_fsm.dispose()
	_fsm = null
	if Gf.has_architecture():
		Gf.get_architecture().dispose()
	Gf._architecture = null


# --- 测试：注册与启动 ---

## 验证 start() 调用初始状态的 enter()。
func test_start_calls_enter() -> void:
	var state: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", state)
	_fsm.start(&"Idle")

	assert_eq(state.enter_count, 1, "start 应调用一次 enter。")
	assert_eq(_fsm.current_state_name, &"Idle", "current_state_name 应为 Idle。")


## 验证 start() 可传入初始消息。
func test_start_passes_msg() -> void:
	var state: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", state)
	_fsm.start(&"Idle", {"key": 42})

	assert_eq(GFVariantData.get_option_int(state.last_msg, "key"), 42, "enter 应收到传入的 msg。")


func test_start_emits_initial_state_changed_signal_by_default() -> void:
	var state: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", state)

	watch_signals(_fsm)
	_fsm.start(&"Idle")

	assert_signal_emitted_with_parameters(_fsm, "state_changed", [&"", &"Idle"])


func test_start_can_suppress_initial_state_changed_signal() -> void:
	var state: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", state)

	watch_signals(_fsm)
	_fsm.start(&"Idle", {}, false)

	assert_signal_not_emitted(_fsm, "state_changed", "显式传 false 时 start() 可静默进入初始状态。")


func test_start_again_exits_previous_state() -> void:
	var idle: TrackingState = TrackingState.new()
	var run: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", idle)
	_fsm.add_state(&"Run", run)
	_fsm.start(&"Idle")

	_fsm.start(&"Run")

	assert_eq(idle.exit_count, 1, "重复 start 到新状态前应退出旧状态。")
	assert_eq(run.enter_count, 1, "重复 start 应进入新的初始状态。")
	assert_eq(_fsm.current_state_name, &"Run", "重复 start 后 current_state_name 应更新。")


## 验证 start() 对未知状态名打印错误且不崩溃。
func test_start_unknown_state_is_safe() -> void:
	_fsm.start(&"Unknown")

	assert_eq(_fsm.current_state_name, &"", "未找到状态时 current_state_name 应保持空。")
	assert_push_warning("[GFStateMachine] 启动失败，未找到状态：Unknown")


# --- 测试：状态切换 ---

## 验证 change_state 调用旧状态 exit() 和新状态 enter()。
func test_change_state_calls_exit_and_enter() -> void:
	var idle: TrackingState = TrackingState.new()
	var run: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", idle)
	_fsm.add_state(&"Run", run)
	_fsm.start(&"Idle")

	_fsm.change_state(&"Run")

	assert_eq(idle.exit_count, 1, "离开 Idle 应调用一次 exit。")
	assert_eq(run.enter_count, 1, "进入 Run 应调用一次 enter。")
	assert_eq(_fsm.current_state_name, &"Run", "current_state_name 应更新为 Run。")


## 验证 change_state 发出 state_changed 信号。
func test_change_state_emits_signal() -> void:
	var idle: TrackingState = TrackingState.new()
	var run: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", idle)
	_fsm.add_state(&"Run", run)
	_fsm.start(&"Idle")

	watch_signals(_fsm)
	_fsm.change_state(&"Run")

	assert_signal_emitted_with_parameters(_fsm, "state_changed", [&"Idle", &"Run"])


func test_nested_change_state_during_enter_emits_only_final_transition() -> void:
	var idle: TrackingState = TrackingState.new()
	var redirect: RedirectState = RedirectState.new(&"Run")
	var run: TrackingState = TrackingState.new()
	var transitions: Array = []
	_fsm.add_state(&"Idle", idle)
	_fsm.add_state(&"Redirect", redirect)
	_fsm.add_state(&"Run", run)
	_fsm.start(&"Idle")
	var _connect_result_297: Variant = _fsm.state_changed.connect(func(from_state: StringName, to_state: StringName) -> void:
		transitions.append([from_state, to_state])
	)

	_fsm.change_state(&"Redirect")

	assert_eq(_fsm.current_state_name, &"Run", "enter 内部嵌套切换后最终状态应为 Run。")
	assert_eq(transitions, [[&"Redirect", &"Run"]], "外层过时切换不应再发出 state_changed。")


func test_nested_change_state_during_exit_uses_requested_final_state() -> void:
	var idle: ExitRedirectState = ExitRedirectState.new(&"Run")
	var attack: TrackingState = TrackingState.new()
	var run: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", idle)
	_fsm.add_state(&"Attack", attack)
	_fsm.add_state(&"Run", run)
	_fsm.start(&"Idle")

	_fsm.change_state(&"Attack")

	assert_eq(idle.exit_count, 1, "exit 内部请求切换时，旧状态不应重复 exit。")
	assert_eq(attack.enter_count, 0, "exit 内部请求的新状态应替代外层目标。")
	assert_eq(run.enter_count, 1, "exit 内部请求的状态应成为最终状态。")
	assert_eq(_fsm.current_state_name, &"Run", "最终状态应为 exit 内部请求的状态。")


func test_chained_exit_redirects_use_final_requested_state() -> void:
	var parent: ExitRedirectState = ExitRedirectState.new(&"Fallback")
	var child: ExitRedirectState = ExitRedirectState.new(&"Other")
	var outside: TrackingState = TrackingState.new()
	var other: TrackingState = TrackingState.new()
	var fallback: TrackingState = TrackingState.new()
	_fsm.add_state(&"Parent", parent)
	_fsm.add_state(&"Child", child, &"Parent")
	_fsm.add_state(&"Outside", outside)
	_fsm.add_state(&"Other", other)
	_fsm.add_state(&"Fallback", fallback)
	_fsm.start(&"Child")

	_fsm.change_state(&"Outside")

	assert_eq(child.exit_count, 1, "子状态 exit 重定向不应导致子状态重复退出。")
	assert_eq(parent.exit_count, 1, "父状态在后续重定向中应只退出一次。")
	assert_eq(outside.enter_count, 0, "外层目标应被子状态 exit 重定向替换。")
	assert_eq(other.enter_count, 0, "父状态 exit 的重定向应替换子状态重定向目标。")
	assert_eq(fallback.enter_count, 1, "最终应进入最后一次 exit 重定向请求的状态。")
	assert_eq(_fsm.current_state_name, &"Fallback", "多层 exit 重定向后最终状态应稳定。")


## 验证状态可通过自身代理请求状态切换。
func test_state_can_request_change_state() -> void:
	var idle: TrackingState = TrackingState.new()
	var run: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", idle)
	_fsm.add_state(&"Run", run)
	_fsm.start(&"Idle")

	idle.change_state(&"Run")

	assert_eq(idle.exit_count, 1, "State.change_state 应委托状态机退出当前状态。")
	assert_eq(run.enter_count, 1, "State.change_state 应委托状态机进入目标状态。")
	assert_eq(_fsm.current_state_name, &"Run", "State.change_state 应更新状态机当前状态。")


func test_hierarchical_start_enters_parent_then_child() -> void:
	var grounded: TrackingState = TrackingState.new(&"Grounded")
	var idle: TrackingState = TrackingState.new(&"Idle")
	_fsm.add_state(&"Grounded", grounded)
	_fsm.add_state(&"Idle", idle, &"Grounded")

	_fsm.start(&"Idle", { "spawn": true })

	assert_eq(_fsm.get_active_state_path(), [&"Grounded", &"Idle"], "启动子状态时应激活父状态路径。")
	assert_true(_fsm.is_in_state(&"Grounded"), "父状态应处于激活路径。")
	assert_eq(grounded.enter_count, 1, "父状态应先进入。")
	assert_eq(idle.enter_count, 1, "子状态应进入。")
	assert_true(GFVariantData.get_option_bool(idle.last_msg, "spawn"), "切换参数应传给叶子状态。")


func test_hierarchical_sibling_transition_keeps_common_parent() -> void:
	var grounded: TrackingState = TrackingState.new(&"Grounded")
	var idle: TrackingState = TrackingState.new(&"Idle")
	var run: TrackingState = TrackingState.new(&"Run")
	_fsm.add_state(&"Grounded", grounded)
	_fsm.add_state(&"Idle", idle, &"Grounded")
	_fsm.add_state(&"Run", run, &"Grounded")
	_fsm.start(&"Idle")

	_fsm.change_state(&"Run")

	assert_eq(grounded.exit_count, 0, "同父子状态切换不应退出公共父状态。")
	assert_eq(idle.exit_count, 1, "离开叶子状态应调用 exit。")
	assert_eq(run.enter_count, 1, "目标叶子状态应进入。")
	assert_eq(_fsm.get_active_state_path(), [&"Grounded", &"Run"], "激活路径应切换到兄弟叶子。")


func test_hierarchical_unrelated_transition_exits_child_then_parent() -> void:
	var events: Array[String] = []
	var grounded: TrackingState = TrackingState.new(&"Grounded")
	var idle: TrackingState = TrackingState.new(&"Idle")
	var airborne: TrackingState = TrackingState.new(&"Airborne")
	grounded.events = events
	idle.events = events
	airborne.events = events
	_fsm.add_state(&"Grounded", grounded)
	_fsm.add_state(&"Idle", idle, &"Grounded")
	_fsm.add_state(&"Airborne", airborne)
	_fsm.start(&"Idle")
	events.clear()

	_fsm.change_state(&"Airborne")

	assert_eq(events, ["exit:Idle", "exit:Grounded", "enter:Airborne"], "跨根状态切换应按 leaf -> root 退出，再进入目标。")
	assert_eq(_fsm.get_active_state_path(), [&"Airborne"], "跨根切换后只应激活目标根状态。")


func test_hierarchical_transition_guard_blocks_before_exit() -> void:
	var idle: TrackingState = TrackingState.new()
	var run: GuardedState = GuardedState.new()
	run.allow_enter = false
	_fsm.add_state(&"Idle", idle)
	_fsm.add_state(&"Run", run)
	_fsm.start(&"Idle")
	watch_signals(_fsm)

	_fsm.change_state(&"Run", { "reason": "test" })

	assert_eq(_fsm.current_state_name, &"Idle", "进入守卫阻止时应保持当前状态。")
	assert_eq(idle.exit_count, 0, "守卫失败不应退出当前状态。")
	assert_signal_emitted_with_parameters(_fsm, "transition_blocked", [&"Idle", &"Run", { "reason": "test" }, &"enter_guard"])


func test_state_event_bubbles_from_leaf_to_parent() -> void:
	var parent: EventHandlingState = EventHandlingState.new(&"Parent")
	var child: EventHandlingState = EventHandlingState.new(&"Child")
	parent.handled_events.append(&"hit")
	_fsm.add_state(&"Parent", parent)
	_fsm.add_state(&"Child", child, &"Parent")
	_fsm.start(&"Child")
	parent.events.clear()
	child.events.clear()
	watch_signals(_fsm)

	var handled: bool = _fsm.dispatch_state_event(&"hit", { "damage": 3 })

	assert_true(handled, "父状态应能处理子状态未处理的事件。")
	assert_eq(child.events, ["miss:Child:hit"], "事件应先交给叶子状态。")
	assert_eq(parent.events, ["handle:Parent:hit"], "叶子未处理时应上抛给父状态。")
	assert_signal_emitted_with_parameters(_fsm, "state_event_handled", [&"hit", &"Parent", { "damage": 3 }])


func test_update_can_include_ancestor_states() -> void:
	var parent: TrackingState = TrackingState.new()
	var child: TrackingState = TrackingState.new()
	_fsm.add_state(&"Parent", parent)
	_fsm.add_state(&"Child", child, &"Parent")
	_fsm.start(&"Child")

	_fsm.update(0.016)
	_fsm.update(0.016, true)

	assert_eq(parent.update_count, 1, "include_ancestors 为 true 时应更新父状态。")
	assert_eq(child.update_count, 2, "默认更新叶子状态，包含父级时仍应更新叶子。")


func test_state_snapshot_reports_hierarchy_and_blackboard() -> void:
	_fsm.add_state(&"Parent", TrackingState.new())
	_fsm.add_state(&"Child", TrackingState.new(), &"Parent")
	_fsm.blackboard["mode"] = "combat"
	_fsm.start(&"Child")

	var snapshot: Dictionary = _fsm.get_state_snapshot()
	var parents: Dictionary = GFVariantData.get_option_dictionary(snapshot, "parents")
	var blackboard: Dictionary = GFVariantData.get_option_dictionary(snapshot, "blackboard")

	assert_eq(GFVariantData.get_option_string_name(snapshot, "current_state"), &"Child", "快照应报告当前叶子状态。")
	assert_eq(GFVariantData.get_option_array(snapshot, "active_path"), [&"Parent", &"Child"], "快照应报告激活路径。")
	assert_eq(GFVariantData.get_option_string_name(parents, &"Child"), &"Parent", "快照应报告父子关系。")
	assert_eq(GFVariantData.get_option_string(blackboard, "mode"), "combat", "快照应包含黑板副本。")


func test_set_state_parent_rejects_cycles() -> void:
	_fsm.add_state(&"Parent", TrackingState.new())
	_fsm.add_state(&"Child", TrackingState.new(), &"Parent")

	var changed: bool = _fsm.set_state_parent(&"Parent", &"Child")

	assert_false(changed, "父子关系不能形成循环。")
	assert_push_error("[GFStateMachine] 检测到循环状态父级：Parent -> Child")


## 验证 change_state 对未知状态名打印错误且不改变当前状态。
func test_change_state_unknown_is_safe() -> void:
	var idle: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", idle)
	_fsm.start(&"Idle")

	_fsm.change_state(&"NonExistent")

	assert_eq(_fsm.current_state_name, &"Idle", "未找到状态时 current_state_name 不应变化。")
	assert_push_warning("[GFStateMachine] 切换失败，未找到状态：NonExistent")


# --- 测试：update 与 stop ---

## 验证 update 将 delta 传递给当前状态。
func test_update_calls_current_state_update() -> void:
	var idle: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", idle)
	_fsm.start(&"Idle")

	_fsm.update(0.016)
	_fsm.update(0.016)

	assert_eq(idle.update_count, 2, "调用两次 update 应驱动状态的 update 两次。")


## 验证 stop() 调用当前状态的 exit() 并清空状态。
func test_stop_calls_exit_and_clears_state() -> void:
	var idle: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", idle)
	_fsm.start(&"Idle")

	_fsm.stop()

	assert_eq(idle.exit_count, 1, "stop 应调用当前状态的 exit。")
	assert_eq(_fsm.current_state_name, &"", "stop 后 current_state_name 应清空。")


# --- 测试：dispose 与引用释放 ---

## 验证 dispose() 退出当前状态、释放所有状态并断开 State -> Machine 回链。
func test_dispose_exits_current_state_and_disposes_all_states() -> void:
	var idle: TrackingState = TrackingState.new()
	var run: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", idle)
	_fsm.add_state(&"Run", run)
	_fsm.start(&"Idle")

	_fsm.dispose()

	assert_eq(idle.exit_count, 1, "dispose 应先退出当前状态。")
	assert_eq(idle.dispose_count, 1, "dispose 应释放当前状态。")
	assert_eq(run.dispose_count, 1, "dispose 应释放未激活但已注册的状态。")
	assert_false(idle.has_machine(), "dispose 后当前状态不应继续持有状态机引用。")
	assert_false(run.has_machine(), "dispose 后未激活状态不应继续持有状态机引用。")
	assert_eq(_fsm.current_state_name, &"", "dispose 后 current_state_name 应清空。")


## 验证替换同名状态时旧状态会断开对状态机的引用。
func test_add_state_replaces_old_state_safely() -> void:
	var old_idle: TrackingState = TrackingState.new()
	var new_idle: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", old_idle)
	_fsm.add_state(&"Idle", new_idle)
	_fsm.start(&"Idle")

	assert_eq(old_idle.dispose_count, 1, "同名状态被替换时旧状态应被释放。")
	assert_false(old_idle.has_machine(), "同名状态被替换时旧状态不应保留状态机引用。")
	assert_true(new_idle.has_machine(), "新状态应持有可用的状态机弱引用。")
	assert_eq(new_idle.enter_count, 1, "启动时应进入新注册的状态。")


## 验证未 setup 或已 dispose 的状态代理方法不会崩溃。
func test_add_state_replacing_current_state_switches_active_reference() -> void:
	var old_idle: TrackingState = TrackingState.new()
	var new_idle: TrackingState = TrackingState.new()

	_fsm.add_state(&"Idle", old_idle)
	_fsm.start(&"Idle")
	_fsm.add_state(&"Idle", new_idle)
	_fsm.update(0.016)

	assert_eq(old_idle.exit_count, 1, "替换当前激活状态时，旧状态应先退出。")
	assert_eq(old_idle.dispose_count, 1, "替换当前激活状态时，旧状态应被释放。")
	assert_eq(new_idle.enter_count, 1, "替换当前激活状态时，新状态应接管并进入。")
	assert_eq(new_idle.update_count, 1, "接管后的新状态应继续接收 update。")


func test_state_proxy_methods_without_machine_are_safe() -> void:
	var state: TrackingState = TrackingState.new()

	state.change_state(&"Any")
	state.send_event(StateEventPayload.new())
	state.send_simple_event(&"Any")

	assert_null(state.get_model(DummyModel), "未绑定状态机的 State.get_model 应安全返回 null。")
	assert_null(state.get_system(DummySystem), "未绑定状态机的 State.get_system 应安全返回 null。")
	assert_null(state.get_utility(DummyUtility), "未绑定状态机的 State.get_utility 应安全返回 null。")
	assert_true(state.send_command(DummyCommand.new()) == null, "未绑定状态机的 State.send_command 应安全返回 null。")
	assert_true(state.send_query(DummyQuery.new()) == null, "未绑定状态机的 State.send_query 应安全返回 null。")


# --- 测试：框架依赖访问 ---

## 验证无 context 创建时，状态机仍可通过全局 Gf 获取框架依赖。
func test_get_dependencies_without_context_uses_global_architecture() -> void:
	var dependencies: Dictionary = await _setup_dependency_architecture()

	assert_eq(_fsm.get_model(DummyModel), _object_dependency(dependencies, "model"), "无 context 时应能获取 Model。")
	assert_eq(_fsm.get_system(DummySystem), _object_dependency(dependencies, "system"), "无 context 时应能获取 System。")
	assert_eq(_fsm.get_utility(DummyUtility), _object_dependency(dependencies, "utility"), "无 context 时应能获取 Utility。")


## 验证有效 context 不影响状态机获取框架依赖。
func test_get_dependencies_with_valid_context_uses_global_architecture() -> void:
	var dependencies: Dictionary = await _setup_dependency_architecture()
	var context: ContextHolder = ContextHolder.new()
	_fsm.dispose()
	_fsm = GFStateMachine.new(context)

	assert_eq(_fsm.get_model(DummyModel), _object_dependency(dependencies, "model"), "有效 context 下应能获取 Model。")
	assert_eq(_fsm.get_system(DummySystem), _object_dependency(dependencies, "system"), "有效 context 下应能获取 System。")
	assert_eq(_fsm.get_utility(DummyUtility), _object_dependency(dependencies, "utility"), "有效 context 下应能获取 Utility。")


## 验证当 context 是已注入架构的模块时，状态机优先使用该局部架构。
func test_get_dependencies_with_module_context_uses_injected_architecture() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	await Gf.set_architecture(parent_arch)

	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	var context: ContextUtility = ContextUtility.new()
	var local_utility: DummyUtility = DummyUtility.new()
	await child_arch.register_utility_instance(context)
	await child_arch.register_utility_instance(local_utility)

	_fsm.dispose()
	_fsm = GFStateMachine.new(context)

	assert_eq(_fsm.get_utility(DummyUtility), local_utility, "模块 context 应让状态机解析到注入的局部架构。")

	child_arch.dispose()
	parent_arch.dispose()
	Gf._architecture = null


func test_state_can_send_events_through_state_machine_architecture() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	await Gf.set_architecture(architecture)
	var state: TrackingState = TrackingState.new()
	var simple_payloads: Array = []
	var typed_payloads: Array[int] = []
	architecture.register_simple_event(&"state_simple_event", func(payload: Variant) -> void:
		simple_payloads.append(payload)
	)
	architecture.register_event(StateEventPayload, func(payload: StateEventPayload) -> void:
		typed_payloads.append(payload.value)
	)
	_fsm.add_state(&"Idle", state)
	_fsm.start(&"Idle")

	state.send_simple_event(&"state_simple_event", 42)
	state.send_event(StateEventPayload.new(7))

	assert_eq(simple_payloads, [42], "State.send_simple_event 应委托所属状态机发送轻量事件。")
	assert_eq(typed_payloads, [7], "State.send_event 应委托所属状态机发送类型事件。")


func test_state_can_register_events_through_state_machine_architecture() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	await Gf.set_architecture(architecture)
	var state: EventListeningState = EventListeningState.new()
	_fsm.add_state(&"Listen", state)
	_fsm.add_state(&"Idle", TrackingState.new())
	_fsm.start(&"Listen")

	architecture.send_event(StateEventPayload.new(3))
	architecture.send_event(DerivedStateEventPayload.new(5))
	architecture.send_simple_event(&"state_simple_event", "tick")

	assert_eq(state.typed_values, [3], "State.register_event 应监听精确类型事件。")
	assert_eq(state.assignable_values, [3, 5], "State.register_assignable_event 应监听基类与派生类型事件。")
	assert_eq(state.simple_values, ["tick"], "State.register_simple_event 应监听轻量事件。")

	_fsm.change_state(&"Idle")
	architecture.send_event(StateEventPayload.new(7))
	architecture.send_event(DerivedStateEventPayload.new(9))
	architecture.send_simple_event(&"state_simple_event", "late")

	assert_eq(state.typed_values, [3], "状态退出后调用 unregister_owner_events 应移除类型事件监听。")
	assert_eq(state.assignable_values, [3, 5], "状态退出后调用 unregister_owner_events 应移除可赋值事件监听。")
	assert_eq(state.simple_values, ["tick"], "状态退出后调用 unregister_owner_events 应移除轻量事件监听。")


func test_state_machine_unregisters_owned_events_after_state_exit() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	await Gf.set_architecture(architecture)
	var state: EventListeningState = EventListeningState.new()
	state.unregister_on_exit = false
	_fsm.add_state(&"Listen", state)
	_fsm.add_state(&"Idle", TrackingState.new())
	_fsm.start(&"Listen")

	architecture.send_event(StateEventPayload.new(3))
	architecture.send_simple_event(&"state_simple_event", "tick")
	_fsm.change_state(&"Idle")
	architecture.send_event(StateEventPayload.new(7))
	architecture.send_simple_event(&"state_simple_event", "late")

	assert_eq(state.typed_values, [3], "状态自身忘记注销时，状态机 exit 后也应移除类型事件监听。")
	assert_eq(state.simple_values, ["tick"], "状态自身忘记注销时，状态机 exit 后也应移除轻量事件监听。")


func test_state_dispose_unregisters_owned_event_listeners() -> void:
	var architecture: GFArchitecture = GFArchitecture.new()
	await Gf.set_architecture(architecture)
	var state: EventListeningState = EventListeningState.new()
	state.unregister_on_exit = false
	_fsm.add_state(&"Listen", state)
	_fsm.start(&"Listen")

	architecture.send_event(StateEventPayload.new(3))
	architecture.send_simple_event(&"state_simple_event", "tick")
	_fsm.dispose()
	architecture.send_event(StateEventPayload.new(7))
	architecture.send_simple_event(&"state_simple_event", "late")

	assert_eq(state.typed_values, [3], "State.dispose 应清理当前状态持有的类型事件监听。")
	assert_eq(state.simple_values, ["tick"], "State.dispose 应清理当前状态持有的轻量事件监听。")


func test_state_can_send_command_and_query_through_state_machine_architecture() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	await Gf.set_architecture(parent_arch)
	await parent_arch.register_utility_instance(DummyUtility.new())

	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	var context: ContextUtility = ContextUtility.new()
	var local_utility: DummyUtility = DummyUtility.new()
	await child_arch.register_utility_instance(context)
	await child_arch.register_utility_instance(local_utility)

	_fsm.dispose()
	_fsm = GFStateMachine.new(context)
	var state: TrackingState = TrackingState.new()
	_fsm.add_state(&"Idle", state)
	_fsm.start(&"Idle")

	assert_eq(_dummy_utility(state.send_command(DummyCommand.new())), local_utility, "State.send_command 应使用状态机上下文所属架构。")
	assert_eq(_dummy_utility(state.send_query(DummyQuery.new())), local_utility, "State.send_query 应使用状态机上下文所属架构。")

	child_arch.dispose()
	parent_arch.dispose()
	Gf._architecture = null


## 验证 context 已释放时，状态机会拒绝继续访问框架依赖。
func test_get_dependency_with_released_context_returns_null() -> void:
	await _setup_dependency_architecture()
	var context: ContextHolder = ContextHolder.new()
	_fsm.dispose()
	_fsm = GFStateMachine.new(context)
	context = null

	var model: Object = _fsm.get_model(DummyModel)

	assert_null(model, "context 失效后应拒绝获取 Model。")
	assert_push_error("[GFStateMachine] 上下文无效，无法获取 Model。")


# --- 私有/辅助方法 ---

func _setup_dependency_architecture() -> Dictionary:
	var architecture: GFArchitecture = GFArchitecture.new()
	var model: DummyModel = DummyModel.new()
	var system: DummySystem = DummySystem.new()
	var utility: DummyUtility = DummyUtility.new()

	await architecture.register_model_instance(model)
	await architecture.register_system_instance(system)
	await architecture.register_utility_instance(utility)
	await Gf.set_architecture(architecture)

	return {
		"model": model,
		"system": system,
		"utility": utility,
	}


func _object_dependency(dependencies: Dictionary, key: String) -> Object:
	var value: Variant = GFVariantData.get_option_value(dependencies, key)
	if value is Object:
		var object_value: Object = value
		return object_value
	return null


func _dummy_utility(value: Variant) -> DummyUtility:
	if value is DummyUtility:
		var utility: DummyUtility = value
		return utility
	return null
