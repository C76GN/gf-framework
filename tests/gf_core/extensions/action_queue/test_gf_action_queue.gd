## 测试 GFActionQueueSystem 的 push_front、push_front_parallel 功能。
extends GutTest


# --- 常量 ---

const GF_ACTION_QUEUE_SYSTEM_PATH: String = "res://addons/gf/extensions/action_queue/core/gf_action_queue_system.gd"
const ACTION_QUEUE_INTERCEPTOR_FIXTURES_PATH: String = "res://tests/gf_core/fixtures/action_queue/action_queue_interceptor_fixtures.gd"


# --- 辅助子类 ---

## 立即完成的测试动作，记录执行顺序。
class OrderAction:
	extends GFVisualAction

	var order_list: Array
	var label: String

	func _init(p_list: Array, p_label: String) -> void:
		order_list = p_list
		label = p_label

	func execute() -> Variant:
		order_list.append(label)
		return null


## 执行前判定为无效的测试动作。
class InvalidOrderAction:
	extends OrderAction

	func is_valid() -> bool:
		return false


## 模拟死锁信号动作。
class DeadlockSignalAction:
	extends GFVisualAction

	var emitter: Node

	func _init(e: Node) -> void:
		emitter = e

	func execute() -> Variant:
		return emitter.tree_exited # 返回一个永远不会在正常 await 中恢复的信号，除非手动触发 tree_exited


## 返回 Signal 但可被显式标记为 fire-and-forget 的测试动作。
class SignalOrderAction:
	extends GFVisualAction

	var order_list: Array
	var label: String
	var emitter: Node

	func _init(p_list: Array, p_label: String, p_emitter: Node) -> void:
		order_list = p_list
		label = p_label
		emitter = p_emitter

	func execute() -> Variant:
		order_list.append(label)
		return emitter.tree_exited


## 手动完成的 Signal 动作，用于测试队列取消。
class ManualSignalAction:
	extends GFVisualAction

	signal completed

	var order_list: Array
	var label: String
	var cancelled: bool = false

	func _init(p_list: Array, p_label: String) -> void:
		order_list = p_list
		label = p_label

	func execute() -> Variant:
		order_list.append(label)
		return completed

	func cancel() -> void:
		cancelled = true

	func complete() -> void:
		completed.emit()


## 可暂停、恢复、完成的测试动作。
class ControllableSignalAction:
	extends ManualSignalAction

	var paused: bool = false
	var resumed: bool = false
	var finished: bool = false

	func pause() -> void:
		paused = true

	func resume() -> void:
		resumed = true

	func finish() -> void:
		finished = true
		complete()


## 记录队列执行前注入到动作中的架构。
class InjectedAction:
	extends GFVisualAction

	var injected_architecture: GFArchitecture = null
	var executed: bool = false

	func inject_dependencies(architecture: GFArchitecture) -> void:
		super.inject_dependencies(architecture)
		injected_architecture = architecture

	func execute() -> Variant:
		executed = true
		return null


## 同步执行后继续追加同类动作，用于验证单帧预算。
class RecursiveEnqueueAction:
	extends GFVisualAction

	var queue: Object
	var executions: Array[int]

	func _init(p_queue: Object, p_executions: Array[int]) -> void:
		queue = p_queue
		executions = p_executions

	func execute() -> Variant:
		executions.append(executions.size())
		var next_action: RecursiveEnqueueAction = RecursiveEnqueueAction.new(queue, executions)
		var _enqueue_result: Variant = queue.call(&"enqueue", next_action)
		return null


# --- 私有变量 ---

class ObjectSignalEmitter extends Object:
	signal completed

	func get_completed_signal() -> Signal:
		return completed


class NonNodeDeadlockSignalAction:
	extends GFVisualAction

	var emitter: ObjectSignalEmitter

	func _init(e: ObjectSignalEmitter) -> void:
		emitter = e

	func execute() -> Variant:
		return emitter.get_completed_signal()


class InvalidCompletedSignalAction:
	extends GFVisualAction

	var order_list: Array
	var label: String

	func _init(p_order_list: Array, p_label: String) -> void:
		order_list = p_order_list
		label = p_label

	func execute() -> Variant:
		order_list.append(label)
		var emitter: ObjectSignalEmitter = ObjectSignalEmitter.new()
		var result: Signal = emitter.get_completed_signal()
		emitter.free()
		return result


var _system: Object = null
var _interceptor_fixtures: Object = null


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_system = _new_action_queue(true)
	_interceptor_fixtures = _new_interceptor_fixtures()


func after_each() -> void:
	_dispose_queue(_system)
	_system = null
	_interceptor_fixtures = null
	await get_tree().process_frame


func _signal_from_result(result: Variant) -> Signal:
	if result is Signal:
		return result
	return Signal()


# --- 测试：push_front ---

## 验证 push_front 的动作在 enqueue 的动作之前执行。
## 通过 is_processing 标志防止自动消费，以构建完整的队列后再统一处理。
func test_push_front_executes_before_enqueue() -> void:
	var order: Array = []
	_set_queue_processing(_system, true)
	_enqueue(_system, OrderAction.new(order, "A"))
	_enqueue(_system, OrderAction.new(order, "B"))
	_push_front(_system, OrderAction.new(order, "FRONT"))
	_set_queue_processing(_system, false)
	_enqueue(_system, OrderAction.new(order, "END"))

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order.size(), 4, "应有 4 个动作被执行。")
	assert_eq(GFVariantData.to_text(order[0]), "FRONT", "push_front 的动作应最先执行。")
	assert_eq(GFVariantData.to_text(order[1]), "A", "enqueue 的第一个动作应第二执行。")
	assert_eq(GFVariantData.to_text(order[2]), "B", "enqueue 的第二个动作应第三执行。")
	assert_eq(GFVariantData.to_text(order[3]), "END", "触发处理的动作应最后执行。")


## 验证多次 push_front 保持后进先出的顺序。
func test_multiple_push_front_lifo() -> void:
	var order: Array = []
	_set_queue_processing(_system, true)
	_push_front(_system, OrderAction.new(order, "C"))
	_push_front(_system, OrderAction.new(order, "B"))
	_push_front(_system, OrderAction.new(order, "A"))
	_set_queue_processing(_system, false)
	_enqueue(_system, OrderAction.new(order, "END"))

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order.size(), 4, "应有 4 个动作被执行。")
	assert_eq(GFVariantData.to_text(order[0]), "A", "最后 push_front 的应最先执行。")
	assert_eq(GFVariantData.to_text(order[1]), "B", "第二个 push_front 的应第二执行。")
	assert_eq(GFVariantData.to_text(order[2]), "C", "最早 push_front 的应第三执行。")
	assert_eq(GFVariantData.to_text(order[3]), "END", "触发处理的动作应最后执行。")


## 验证空队列 push_front 能正常启动处理。
func test_push_front_on_empty_queue() -> void:
	var order: Array = []
	_push_front(_system, OrderAction.new(order, "ONLY"))

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(order.has("ONLY"), "空队列 push_front 应正常执行。")


## 验证无效动作不会导致崩溃。
func test_push_front_null_action() -> void:
	_push_front(_system, null)
	assert_true(true, "传入 null 不应崩溃。")


## 验证 clear_queue 清空后 push_front 仍可工作。
func test_clear_then_push_front() -> void:
	var order: Array = []
	_set_queue_processing(_system, true)
	_enqueue(_system, OrderAction.new(order, "OLD"))
	_clear_queue(_system)
	_set_queue_processing(_system, false)
	_push_front(_system, OrderAction.new(order, "NEW"))

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order.size(), 1, "应只有 1 个动作被执行。")
	assert_eq(GFVariantData.to_text(order[0]), "NEW", "clear 后 push_front 应正常执行。")


## 验证 clear_queue(true) 会终止当前等待并丢弃后续队列。
func test_clear_queue_can_stop_current_waiting_action() -> void:
	var order: Array = []
	var waiting_action: ManualSignalAction = ManualSignalAction.new(order, "WAIT")
	_enqueue(_system, waiting_action)
	_enqueue(_system, OrderAction.new(order, "AFTER"))

	await get_tree().process_frame
	assert_true(_is_queue_processing(_system), "队列应正在等待当前 Signal 动作。")

	watch_signals(_system)
	_clear_queue(_system, true)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(waiting_action.cancelled, "stop_current 应向当前动作发送 cancel。")
	assert_false(_is_queue_processing(_system), "stop_current 后队列不应继续处于处理中。")
	assert_eq(order, ["WAIT"], "stop_current 后未执行的后续动作应被丢弃。")
	assert_signal_emitted(_system, "queue_drained", "stop_current 清空运行中队列时应发出排空信号。")


## 验证取消当前动作组时会递归取消正在等待的子动作。
func test_clear_queue_propagates_cancel_to_group_children() -> void:
	var order: Array = []
	var waiting_action: ManualSignalAction = ManualSignalAction.new(order, "WAIT_CHILD")
	var group: GFVisualActionGroup = GFVisualActionGroup.new([waiting_action], false)
	_enqueue(_system, group)

	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(_is_queue_processing(_system), "动作组应正在等待子动作 Signal。")

	_clear_queue(_system, true)
	await get_tree().process_frame

	assert_true(waiting_action.cancelled, "取消动作组时应向子动作传播 cancel。")


func test_current_action_controls_delegate_to_running_action() -> void:
	var order: Array = []
	var waiting_action: ControllableSignalAction = ControllableSignalAction.new(order, "WAIT")
	_enqueue(_system, waiting_action)

	await get_tree().process_frame
	assert_eq(_get_current_action(_system), waiting_action, "等待 Signal 时应可查询当前动作。")

	assert_true(_pause_current_action(_system), "存在当前动作时暂停应返回 true。")
	assert_true(waiting_action.paused, "pause_current_action 应委托给当前动作。")

	assert_true(_resume_current_action(_system), "存在当前动作时恢复应返回 true。")
	assert_true(waiting_action.resumed, "resume_current_action 应委托给当前动作。")

	_finish_current_action(_system)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(waiting_action.finished, "finish_current_action 应委托给当前动作。")
	assert_false(_is_queue_processing(_system), "完成当前动作后队列应恢复空闲。")
	assert_null(_get_current_action(_system), "完成后不应保留当前动作。")


func test_pause_current_action_freezes_wait_action_and_queue_progress() -> void:
	var order: Array = []
	var wait_action: GFWaitAction = GFAction.wait(0.02, self)
	_enqueue(_system, wait_action)
	_enqueue(_system, OrderAction.new(order, "AFTER_WAIT"))

	await get_tree().process_frame
	assert_true(_pause_current_action(_system), "等待动作进入当前动作后应可暂停。")
	await get_tree().create_timer(0.05).timeout
	await get_tree().process_frame

	assert_true(order.is_empty(), "队列暂停期间等待动作不应到期推进后续动作。")
	assert_true(_is_queue_processing(_system), "暂停期间队列应保持处理中。")

	assert_true(_resume_current_action(_system), "暂停后应可恢复当前动作。")
	await wait_until(
		func() -> bool:
			return not _is_queue_processing(_system),
		1.0,
		0.01,
		"恢复后等待动作应完成并排空队列。"
	)
	await get_tree().process_frame

	assert_eq(order, ["AFTER_WAIT"], "恢复后队列应继续执行后续动作。")


# --- 测试：并行队列与组合 ---

## 验证 enqueue_parallel 的子动作被一并执行。
func test_enqueue_parallel() -> void:
	var order: Array = []
	var act1: OrderAction = OrderAction.new(order, "P1")
	var act2: OrderAction = OrderAction.new(order, "P2")
	_enqueue_parallel(_system, [act1, act2])

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(order.has("P1"), "并行 P1 应执行。")
	assert_true(order.has("P2"), "并行 P2 应执行。")


## 验证顺序动作组中的瞬时动作会在同一轮队列处理中完整排空。
func test_enqueue_sequence_group_with_immediate_actions_drains() -> void:
	var order: Array = []
	var group: GFVisualActionGroup = GFVisualActionGroup.new([
		OrderAction.new(order, "S1"),
		OrderAction.new(order, "S2"),
	], false)

	_enqueue(_system, group)

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order, ["S1", "S2"], "顺序动作组应按顺序执行所有瞬时动作。")
	assert_false(_is_queue_processing(_system), "顺序动作组执行完成后，队列应正常排空。")


func test_parallel_group_completion_waits_for_launch_loop() -> void:
	var order: Array = []
	var group: GFVisualActionGroup = GFVisualActionGroup.new([
		InvalidCompletedSignalAction.new(order, "WAIT_INVALID"),
		OrderAction.new(order, "SECOND"),
	], true)
	var completion: Signal = _signal_from_result(group.execute())
	var _connect_result_367: Variant = completion.connect(func() -> void:
		order.append("DONE")
	)

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order, ["WAIT_INVALID", "SECOND", "DONE"], "并行动作组应在启动循环结束后再报告完成。")


func test_repeat_action_yields_during_unbounded_immediate_repeats() -> void:
	var order: Array = []
	var factory: Callable = func() -> Object:
		return OrderAction.new(order, "R")
	var repeat: GFRepeatAction = GFRepeatAction.new(factory, 0)
	repeat.max_immediate_iterations_per_frame = 2
	repeat.execute()

	await get_tree().process_frame
	assert_eq(order.size(), 2, "无限瞬时重复应按单帧预算让出主循环。")

	await get_tree().process_frame
	assert_eq(order.size(), 4, "让出主循环后应继续下一批重复。")

	repeat.cancel()
	await get_tree().process_frame


func test_wait_action_cancel_suppresses_completion_signal() -> void:
	var wait_action: GFWaitAction = GFWaitAction.new(0.01)
	var completed: Array[bool] = []
	var completion: Signal = _signal_from_result(wait_action.execute())
	var _connect_result_399: Variant = completion.connect(func() -> void:
		completed.append(true)
	)

	wait_action.cancel()
	await get_tree().create_timer(0.05).timeout

	assert_true(completed.is_empty(), "取消等待动作后，旧 SceneTreeTimer 不应再触发动作完成信号。")


## 验证显式 fire-and-forget 动作即使返回 Signal，也不会阻塞后续队列。
func test_enqueue_fire_and_forget_does_not_wait_for_signal() -> void:
	var order: Array = []
	var node: Node = Node.new()
	add_child_autofree(node)

	_enqueue_fire_and_forget(_system, SignalOrderAction.new(order, "ASYNC_FAF", node))
	_enqueue(_system, OrderAction.new(order, "NEXT"))

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order, ["ASYNC_FAF", "NEXT"], "fire-and-forget 动作不应阻塞后续动作。")
	assert_false(_is_queue_processing(_system), "队列应在 fire-and-forget 后正常排空。")


func test_action_queue_skips_invalid_action_before_execute() -> void:
	var order: Array = []
	_enqueue(_system, InvalidOrderAction.new(order, "SKIP"))
	_enqueue(_system, OrderAction.new(order, "RUN"))

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order, ["RUN"], "执行前失效的动作应被跳过。")


func test_action_queue_injects_scoped_architecture_into_actions() -> void:
	var parent_arch: GFArchitecture = GFArchitecture.new()
	var child_arch: GFArchitecture = GFArchitecture.new(parent_arch)
	var action_queue: Object = _new_action_queue(false)
	await child_arch.register_system_instance(action_queue)
	await child_arch.init()

	var action: InjectedAction = InjectedAction.new()
	_enqueue(action_queue, action)

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(action.injected_architecture, child_arch, "ActionQueue 应把自身所属架构注入到动作。")

	child_arch.dispose()
	parent_arch.dispose()


func test_action_interceptor_can_skip_and_replace_actions() -> void:
	var order: Array = []
	_add_interceptor(_system, _make_rewrite_interceptor(order))

	_enqueue(_system, OrderAction.new(order, "SKIP"))
	_enqueue(_system, OrderAction.new(order, "OLD"))

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order, ["before:SKIP", "before:OLD", "NEW", "after:NEW"], "拦截器应能跳过和替换动作。")


func test_before_interceptor_clear_invalidates_dequeued_action() -> void:
	var order: Array = []
	var interceptor: Object = _get_object_value(
		_call_object(_interceptor_fixtures, &"make_clear_queue_before_interceptor")
	)
	_add_interceptor(_system, interceptor)
	_enqueue(_system, OrderAction.new(order, "STALE"))

	await get_tree().process_frame

	assert_true(order.is_empty(), "before interceptor 清空队列后，已出队但未执行的动作也必须失效。")
	assert_false(_is_queue_processing(_system), "失效处理链应回到空闲状态。")


func test_immediate_action_budget_yields_between_processing_slices() -> void:
	var executions: Array[int] = []
	_system.set(&"max_immediate_actions_per_slice", 2)
	_enqueue(_system, RecursiveEnqueueAction.new(_system, executions))

	assert_lte(executions.size(), 2, "enqueue 调用栈内最多执行一个即时动作切片。")
	await get_tree().process_frame
	assert_lte(executions.size(), 4, "每帧恢复后仍应受即时动作切片预算约束。")

	_clear_queue(_system, true)


func test_replaced_action_is_injected_before_following_interceptors() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	_inject_dependencies(_system, arch)
	var replacement: InjectedAction = InjectedAction.new()
	var observer: Object = _make_observe_injected_replacement_interceptor()
	var replacer: Object = _make_replace_with_injected_interceptor(replacement)
	replacer.set(&"priority", 10)
	observer.set(&"priority", 0)
	_add_interceptor(_system, replacer)
	_add_interceptor(_system, observer)

	_enqueue(_system, OrderAction.new([], "OLD"))
	await get_tree().process_frame
	await get_tree().process_frame

	assert_same(_get_observed_architecture(observer), arch, "替换动作进入后续拦截器前应完成依赖注入。")
	assert_true(replacement.executed, "替换动作应被实际执行。")

	arch.dispose()


func test_action_interceptors_run_by_priority() -> void:
	var order: Array = []
	_add_interceptor(_system, _make_priority_interceptor(order, "low", 0))
	_add_interceptor(_system, _make_priority_interceptor(order, "high", 10))
	_enqueue(_system, OrderAction.new(order, "RUN"))

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order, ["high", "low", "RUN"], "拦截器应按高优先级优先执行。")


func test_action_interceptor_can_stop_remaining_queue() -> void:
	var order: Array = []
	var stop_action: ManualSignalAction = ManualSignalAction.new(order, "STOP")
	_add_interceptor(_system, _make_stop_after_interceptor())

	_enqueue(_system, stop_action)
	await get_tree().process_frame
	_enqueue(_system, OrderAction.new(order, "AFTER"))

	stop_action.complete()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order, ["STOP"], "after 拦截器停止队列后不应执行后续动作。")
	assert_false(_is_queue_processing(_system), "停止后队列应回到空闲状态。")


## 验证 push_front_parallel 能置顶插队执行。
func test_push_front_parallel() -> void:
	var order: Array = []
	# 为了测试插队，我们要利用一个需要稍微等待的动作或者在第一帧塞入
	_set_queue_processing(_system, true)
	_enqueue(_system, OrderAction.new(order, "END"))
	_push_front_parallel(_system, [OrderAction.new(order, "P1"), OrderAction.new(order, "P2")])
	_set_queue_processing(_system, false)
	_try_start_processing(_system)

	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order.size(), 3, "共有3个动作。")
	assert_true(order.find("P1") < order.find("END"), "P1 应当在 END 之前")
	assert_true(order.find("P2") < order.find("END"), "P2 应当在 END 之前")


# --- 测试：防死锁安全网 (Task 5) ---

## 模拟动作返回的信号发射器被意外释放，验证队列不会永久卡死。
func test_no_deadlock_on_freed_non_node_emitter() -> void:
	var emitter: ObjectSignalEmitter = ObjectSignalEmitter.new()
	_enqueue(_system, NonNodeDeadlockSignalAction.new(emitter))

	await get_tree().process_frame
	assert_true(_is_queue_processing(_system), "队列应进入等待非 Node 信号的处理中状态。")

	emitter.free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(_is_queue_processing(_system), "非 Node 发射源被释放后，队列也应自动恢复，避免死锁。")


func test_signal_timeout_allows_queue_to_continue() -> void:
	var order: Array = []
	var emitter: ObjectSignalEmitter = ObjectSignalEmitter.new()
	var action: GFVisualAction = NonNodeDeadlockSignalAction.new(emitter).with_signal_timeout(0.25, false)
	_enqueue(_system, action)
	_enqueue(_system, OrderAction.new(order, "AFTER_TIMEOUT"))

	await wait_until(
		func() -> bool:
			return not _is_queue_processing(_system),
		1.0,
		0.01,
		"Signal 超时后队列应排空。"
	)
	await get_tree().process_frame

	assert_push_warning("[GFActionQueueSystem] 等待动作 Signal 超时，队列将继续执行后续动作。")
	assert_eq(order, ["AFTER_TIMEOUT"], "Signal 超时后队列应继续执行后续动作。")
	assert_false(_is_queue_processing(_system), "Signal 超时后队列不应继续卡在处理中。")


func test_signal_timeout_respects_time_utility_pause() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var time_utility: GFTimeUtility = GFTimeUtility.new()
	var queue: Object = _new_action_queue(false)
	await arch.register_utility_instance(time_utility)
	await arch.register_system_instance(queue)
	await arch.init()

	var order: Array = []
	var emitter: ObjectSignalEmitter = ObjectSignalEmitter.new()
	var action: GFVisualAction = NonNodeDeadlockSignalAction.new(emitter).with_signal_timeout(0.001)
	time_utility.is_paused = true
	_enqueue(queue, action)
	_enqueue(queue, OrderAction.new(order, "AFTER_TIMEOUT"))

	await get_tree().create_timer(0.03).timeout
	await get_tree().process_frame

	assert_true(_is_queue_processing(queue), "GFTimeUtility 暂停时，Signal 超时计时不应继续推进。")
	assert_true(order.is_empty(), "暂停期间队列不应因超时执行后续动作。")

	time_utility.is_paused = false
	await wait_until(
		func() -> bool:
			return not _is_queue_processing(queue),
		1.0,
		0.01,
		"恢复时间后队列应在 Signal 超时后排空。"
	)
	await get_tree().process_frame

	assert_push_warning("[GFActionQueueSystem] 等待动作 Signal 超时，队列将继续执行后续动作。")
	assert_eq(order, ["AFTER_TIMEOUT"], "恢复时间后，Signal 超时应继续推进并执行后续动作。")
	assert_false(_is_queue_processing(queue), "恢复时间并超时后队列应排空。")

	arch.dispose()


func test_signal_timeout_is_frozen_while_current_action_is_paused() -> void:
	var order: Array = []
	var emitter: ObjectSignalEmitter = ObjectSignalEmitter.new()
	var action: GFVisualAction = NonNodeDeadlockSignalAction.new(emitter).with_signal_timeout(0.25, false)
	_enqueue(_system, action)
	_enqueue(_system, OrderAction.new(order, "AFTER_TIMEOUT"))

	await get_tree().process_frame
	assert_true(_pause_current_action(_system), "当前 Signal 动作应可暂停。")
	await get_tree().create_timer(0.03).timeout
	await get_tree().process_frame

	assert_true(_is_queue_processing(_system), "当前动作暂停时 Signal timeout 不应推进队列。")
	assert_true(order.is_empty(), "暂停期间不应因 timeout 执行后续动作。")

	assert_true(_resume_current_action(_system), "恢复后 timeout 应继续计时。")
	await wait_until(
		func() -> bool:
			return not _is_queue_processing(_system),
		1.0,
		0.01,
		"恢复后队列应允许 Signal timeout 排空。"
	)
	await get_tree().process_frame

	assert_push_warning("[GFActionQueueSystem] 等待动作 Signal 超时，队列将继续执行后续动作。")
	assert_eq(order, ["AFTER_TIMEOUT"], "恢复后 Signal timeout 应继续执行后续动作。")


func test_no_deadlock_on_freed_node() -> void:
	var node: Node = Node.new()
	add_child_autofree(node)

	var action: DeadlockSignalAction = DeadlockSignalAction.new(node)
	_enqueue(_system, action)

	# 启动处理
	await get_tree().process_frame

	# 此时队列应正在等待 node 的信号
	assert_true(_is_queue_processing(_system), "队列应处于处理中。")

	# 模拟节点被销毁 (由外部逻辑触发)
	node.free()

	# 等待几帧让系统响应处理
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(_is_queue_processing(_system), "队列应在节点销毁后自动恢复并结束处理，不产生死锁。")


func test_sequence_group_no_deadlock_on_freed_node() -> void:
	var order: Array = []
	var node: Node = Node.new()
	add_child_autofree(node)

	var group: GFVisualActionGroup = GFVisualActionGroup.new([
		DeadlockSignalAction.new(node),
		OrderAction.new(order, "AFTER"),
	], false)
	_enqueue(_system, group)

	await get_tree().process_frame
	assert_true(_is_queue_processing(_system), "顺序动作组应进入等待状态。")

	node.free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(order, ["AFTER"], "等待源失效后，顺序动作组应继续执行后续动作。")
	assert_false(_is_queue_processing(_system), "顺序动作组在等待源销毁后也应自动恢复。")


# --- 测试：命名队列 ---

func test_named_queues_run_independently() -> void:
	var order: Array = []

	_enqueue_to(_system, &"battle", OrderAction.new(order, "BATTLE"))
	_enqueue_to(_system, &"dialogue", OrderAction.new(order, "DIALOGUE"))

	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(order.has("BATTLE"), "命名队列 battle 应执行动作。")
	assert_true(order.has("DIALOGUE"), "命名队列 dialogue 应执行动作。")
	assert_false(_is_queue_processing(_get_named_queue(_system, &"battle")), "battle 队列应排空。")
	assert_false(_is_queue_processing(_get_named_queue(_system, &"dialogue")), "dialogue 队列应排空。")


func test_linked_queue_clears_when_node_is_released() -> void:
	var node: Node = Node.new()
	add_child(node)
	var queue: Object = _get_linked_queue(_system, &"linked", node)
	var order: Array = []
	var waiting_action: ManualSignalAction = ManualSignalAction.new(order, "WAIT")
	_enqueue(queue, waiting_action)

	await get_tree().process_frame
	assert_true(_is_queue_processing(queue), "绑定队列应进入等待状态。")

	node.free()
	_tick_queue(_system, 0.016)
	await get_tree().process_frame

	assert_true(waiting_action.cancelled, "绑定节点释放后队列应取消当前动作。")
	assert_false(_is_queue_processing(queue), "绑定节点释放后队列应停止处理。")


func test_linked_queue_clears_on_node_tree_exit_without_parent_tick() -> void:
	var node: Node = Node.new()
	add_child(node)
	var queue: Object = _get_linked_queue(_system, &"linked_direct", node)
	var order: Array = []
	var waiting_action: ManualSignalAction = ManualSignalAction.new(order, "WAIT")
	_enqueue(queue, waiting_action)

	await get_tree().process_frame
	assert_true(_is_queue_processing(queue), "绑定队列应进入等待状态。")

	node.free()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(waiting_action.cancelled, "绑定节点离树后队列应主动取消当前动作。")
	assert_false(_is_queue_processing(queue), "绑定节点离树后不应依赖父队列 tick 才停止。")


func test_dispose_releases_named_queue_dependency_scope() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var parent_queue: Object = _new_action_queue(false)
	await arch.register_system_instance(parent_queue)
	await arch.init()
	var named_queue: Object = _get_named_queue(parent_queue, &"scene")
	var order: Array = []
	var waiting_action: ManualSignalAction = ManualSignalAction.new(order, "WAIT")
	_enqueue(named_queue, waiting_action)

	await get_tree().process_frame
	assert_true(_is_queue_processing(named_queue), "命名子队列应进入等待状态。")

	arch.dispose()
	assert_true(waiting_action.cancelled, "父队列销毁时应取消命名子队列当前动作。")
	assert_false(_is_queue_processing(named_queue), "父队列销毁后命名子队列不应继续处理。")

	var injected_action: InjectedAction = InjectedAction.new()
	_enqueue(named_queue, injected_action)
	await get_tree().process_frame

	assert_null(injected_action.injected_architecture, "已被父队列销毁的命名子队列不应继续持有旧架构。")
	assert_false(injected_action.executed, "已被父队列销毁的命名子队列不应继续执行新动作。")


func test_clear_all_named_queues_disposes_owned_named_queues() -> void:
	var named_queue: Object = _get_named_queue(_system, &"scene")
	var order: Array = []
	var waiting_action: ManualSignalAction = ManualSignalAction.new(order, "WAIT")
	_enqueue(named_queue, waiting_action)

	await get_tree().process_frame
	assert_true(_is_queue_processing(named_queue), "命名子队列应进入等待状态。")

	_clear_all_named_queues(_system, true)
	await get_tree().process_frame

	assert_true(waiting_action.cancelled, "clear_all_named_queues 应取消命名子队列当前动作。")
	assert_false(_is_queue_processing(named_queue), "clear_all_named_queues 后旧命名子队列不应继续处理。")
	var next_action: OrderAction = OrderAction.new(order, "NEXT")
	_enqueue(named_queue, next_action)
	await get_tree().process_frame
	assert_eq(order, ["WAIT"], "已被清理的旧命名子队列不应再执行新动作。")


func test_reinit_cancels_current_action_and_disposes_named_queues() -> void:
	var order: Array = []
	var waiting_action: ManualSignalAction = ManualSignalAction.new(order, "WAIT")
	_enqueue(_system, waiting_action)
	var named_queue: Object = _get_named_queue(_system, &"scene")
	var named_waiting_action: ManualSignalAction = ManualSignalAction.new(order, "NAMED")
	_enqueue(named_queue, named_waiting_action)

	await get_tree().process_frame
	assert_true(_is_queue_processing(_system), "主队列应进入等待状态。")
	assert_true(_is_queue_processing(named_queue), "命名队列应进入等待状态。")

	_call_object(_system, &"init")
	await get_tree().process_frame

	assert_true(waiting_action.cancelled, "重复 init 应取消主队列当前动作。")
	assert_true(named_waiting_action.cancelled, "重复 init 应释放命名子队列。")
	assert_false(_is_queue_processing(_system), "重复 init 后主队列不应保持 processing。")
	assert_false(_is_queue_processing(named_queue), "重复 init 后旧命名队列不应继续 processing。")


func test_skip_current_action_continues_with_next_action() -> void:
	var order: Array = []
	var waiting_action: ManualSignalAction = ManualSignalAction.new(order, "WAIT")
	_enqueue(_system, waiting_action)
	_enqueue(_system, OrderAction.new(order, "NEXT"))

	await get_tree().process_frame
	_skip_current_action(_system)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(waiting_action.cancelled, "skip_current_action 应取消当前动作。")
	assert_eq(order, ["WAIT", "NEXT"], "skip_current_action 后应继续执行后续动作。")


func test_debug_snapshot_reports_queue_and_named_queue_state() -> void:
	_set_queue_processing(_system, true)
	_enqueue(_system, OrderAction.new([], "A"))
	var named_queue: Object = _get_named_queue(_system, &"named")
	_set_queue_processing(named_queue, true)
	_enqueue_to(_system, &"named", OrderAction.new([], "B"))

	var snapshot: Dictionary = _get_debug_snapshot(_system)
	var named_queues: Dictionary = GFVariantData.get_option_dictionary(snapshot, "named_queues")
	var named_snapshot: Dictionary = GFVariantData.get_option_dictionary(named_queues, &"named")

	assert_eq(GFVariantData.get_option_int(snapshot, "queued_count"), 1, "快照应报告主队列待执行数量。")
	assert_eq(GFVariantData.get_option_int(snapshot, "named_queue_count"), 1, "快照应报告命名队列数量。")
	assert_eq(GFVariantData.get_option_int(named_snapshot, "queued_count"), 1, "命名队列快照应报告自身待执行数量。")


func test_debug_snapshot_bounds_named_queue_expansion() -> void:
	_system.set(&"max_debug_named_queue_entries", 1)
	var _first_queue: Object = _get_named_queue(_system, &"first")
	var _second_queue: Object = _get_named_queue(_system, &"second")

	var snapshot: Dictionary = _get_debug_snapshot(_system)
	var named_snapshots: Dictionary = GFVariantData.get_option_dictionary(snapshot, "named_queues")

	assert_eq(GFVariantData.get_option_int(snapshot, "named_queue_count"), 2, "总数应保留真实命名队列数量。")
	assert_eq(GFVariantData.get_option_int(snapshot, "named_queue_snapshot_count"), 1, "快照展开数应受预算约束。")
	assert_true(GFVariantData.get_option_bool(snapshot, "named_queues_truncated"), "截断时应显式标记。")
	assert_eq(named_snapshots.size(), 1, "诊断预算不能只在编码后截断。")


func test_tween_action_step_reports_invalid_property() -> void:
	var node: Node2D = Node2D.new()
	add_child_autofree(node)
	var step: GFTweenActionStep = GFTweenActionStep.new()
	step.property_name = ^"missing_property"
	step.target_value = Vector2.ONE

	assert_false(step.can_apply_to(node), "不存在的属性不应通过配置校验。")
	assert_true(step.get_validation_error(node).contains("Property not found"), "校验错误应指出缺失属性。")


# --- 私有/辅助方法 ---

func _new_action_queue(init_queue: bool) -> Object:
	var script: Script = _load_script(GF_ACTION_QUEUE_SYSTEM_PATH)
	if script == null:
		return null

	var queue: Object = _get_object_value(script.call(&"new"))
	if queue != null and init_queue:
		_call_object(queue, &"init")
	return queue


func _new_interceptor_fixtures() -> Object:
	var script: Script = _load_script(ACTION_QUEUE_INTERCEPTOR_FIXTURES_PATH)
	if script == null:
		return null
	return _get_object_value(script.call(&"new"))


func _load_script(script_path: String) -> Script:
	var resource: Resource = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource is Script:
		var script: Script = resource
		return script
	return null


func _call_object(target: Object, method_name: StringName, arguments: Array = []) -> Variant:
	if target == null or not target.has_method(method_name):
		return null
	return target.callv(method_name, arguments)


func _read_object_property(target: Object, property_name: StringName) -> Variant:
	if target == null:
		return null
	return target.call(&"get", property_name)


func _set_queue_processing(queue: Object, processing_active: bool) -> void:
	if queue != null:
		queue.set(&"is_processing", processing_active)


func _is_queue_processing(queue: Object) -> bool:
	return GFVariantData.to_bool(_read_object_property(queue, &"is_processing"))


func _enqueue(queue: Object, action: Object) -> void:
	var _result: Variant = _call_object(queue, &"enqueue", [action])


func _enqueue_fire_and_forget(queue: Object, action: Object) -> void:
	var _result: Variant = _call_object(queue, &"enqueue_fire_and_forget", [action])


func _enqueue_parallel(queue: Object, actions: Array) -> void:
	var _result: Variant = _call_object(queue, &"enqueue_parallel", [actions])


func _enqueue_to(queue: Object, queue_name: StringName, action: Object) -> void:
	var _result: Variant = _call_object(queue, &"enqueue_to", [queue_name, action])


func _push_front(queue: Object, action: Object) -> void:
	var _result: Variant = _call_object(queue, &"push_front", [action])


func _push_front_parallel(queue: Object, actions: Array) -> void:
	var _result: Variant = _call_object(queue, &"push_front_parallel", [actions])


func _clear_queue(queue: Object, stop_current: bool = false) -> void:
	var _result: Variant = _call_object(queue, &"clear_queue", [stop_current])


func _clear_all_named_queues(queue: Object, stop_current: bool = false) -> void:
	var _result: Variant = _call_object(queue, &"clear_all_named_queues", [stop_current])


func _dispose_queue(queue: Object) -> void:
	var _result: Variant = _call_object(queue, &"dispose")


func _try_start_processing(queue: Object) -> void:
	var _result: Variant = _call_object(queue, &"_try_start_processing")


func _tick_queue(queue: Object, delta: float) -> void:
	var _result: Variant = _call_object(queue, &"tick", [delta])


func _skip_current_action(queue: Object) -> void:
	var _result: Variant = _call_object(queue, &"skip_current_action")


func _finish_current_action(queue: Object) -> void:
	var _result: Variant = _call_object(queue, &"finish_current_action")


func _pause_current_action(queue: Object) -> bool:
	return GFVariantData.to_bool(_call_object(queue, &"pause_current_action"))


func _resume_current_action(queue: Object) -> bool:
	return GFVariantData.to_bool(_call_object(queue, &"resume_current_action"))


func _get_current_action(queue: Object) -> Object:
	return _get_object_value(_call_object(queue, &"get_current_action"))


func _get_named_queue(queue: Object, queue_name: StringName) -> Object:
	return _get_object_value(_call_object(queue, &"get_named_queue", [queue_name]))


func _get_linked_queue(queue: Object, queue_name: StringName, linked_node: Node) -> Object:
	return _get_object_value(_call_object(queue, &"get_linked_queue", [queue_name, linked_node]))


func _get_debug_snapshot(queue: Object) -> Dictionary:
	var value: Variant = _call_object(queue, &"get_debug_snapshot")
	if value is Dictionary:
		var snapshot: Dictionary = value
		return snapshot
	return {}


func _inject_dependencies(target: Object, architecture: GFArchitecture) -> void:
	var _result: Variant = _call_object(target, &"inject_dependencies", [architecture])


func _add_interceptor(queue: Object, interceptor: Object) -> void:
	var _result: Variant = _call_object(queue, &"add_interceptor", [interceptor])


func _make_rewrite_interceptor(order_list: Array) -> Object:
	return _get_object_value(_call_object(_interceptor_fixtures, &"make_rewrite_interceptor", [order_list]))


func _make_priority_interceptor(order_list: Array, label: String, priority: int) -> Object:
	return _get_object_value(_call_object(_interceptor_fixtures, &"make_priority_interceptor", [order_list, label, priority]))


func _make_stop_after_interceptor() -> Object:
	return _get_object_value(_call_object(_interceptor_fixtures, &"make_stop_after_interceptor"))


func _make_replace_with_injected_interceptor(replacement: Object) -> Object:
	return _get_object_value(_call_object(_interceptor_fixtures, &"make_replace_with_injected_interceptor", [replacement]))


func _make_observe_injected_replacement_interceptor() -> Object:
	return _get_object_value(_call_object(_interceptor_fixtures, &"make_observe_injected_replacement_interceptor"))


func _get_observed_architecture(observer: Object) -> GFArchitecture:
	var value: Variant = _read_object_property(observer, &"observed_architecture")
	if value is GFArchitecture:
		var architecture: GFArchitecture = value
		return architecture
	return null


func _get_object_value(value: Variant) -> Object:
	if value is Object:
		var object: Object = value
		return object
	return null
