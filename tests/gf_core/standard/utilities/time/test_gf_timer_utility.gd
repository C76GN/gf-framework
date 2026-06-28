## 测试 GFTimerUtility 的时间缩放与暂停行为。
extends GutTest


var _arch: GFArchitecture
var _time_util: GFTimeUtility
var _timer_util: GFTimerUtility


func before_each() -> void:
	_arch = GFArchitecture.new()
	Gf._architecture = _arch

	_time_util = GFTimeUtility.new()
	await _arch.register_utility_instance(_time_util)

	_timer_util = GFTimerUtility.new()
	await _arch.register_utility_instance(_timer_util)

	await Gf.set_architecture(_arch)


func after_each() -> void:
	var arch: GFArchitecture = Gf.get_architecture()
	if arch != null:
		arch.dispose()
		await Gf.set_architecture(GFArchitecture.new())


func test_execute_after_uses_scaled_delta() -> void:
	var fired: TimerCountState = TimerCountState.new()
	_time_util.time_scale = 0.5

	var handle: int = _timer_util.execute_after(1.0, func() -> void:
		fired.count += 1
	)

	_arch.tick(1.0)
	assert_gt(handle, 0, "排队定时器应返回有效句柄。")
	assert_eq(fired.count, 0, "半速时间下，1 秒真实时间不应立刻消耗完 1 秒逻辑计时。")

	_arch.tick(1.0)
	assert_eq(fired.count, 1, "累计 2 秒真实时间后，应恰好触发 1 秒逻辑计时。")


func test_execute_after_respects_pause() -> void:
	var fired: TimerBoolState = TimerBoolState.new()

	var handle: int = _timer_util.execute_after(0.5, func() -> void:
		fired.value = true
	)

	_time_util.is_paused = true
	_arch.tick(1.0)
	assert_gt(handle, 0, "排队定时器应返回有效句柄。")
	assert_false(fired.value, "暂停期间，定时器不应推进。")

	_time_util.is_paused = false
	_arch.tick(0.5)
	assert_true(fired.value, "恢复后，定时器应继续推进并触发回调。")


func test_execute_after_zero_delay_runs_immediately() -> void:
	var fired: TimerCountState = TimerCountState.new()

	var handle: int = _timer_util.execute_after(0.0, func() -> void:
		fired.count += 1
	)

	assert_eq(handle, 0, "立即执行不应返回排队句柄。")
	assert_eq(fired.count, 1, "0 秒延迟应立即执行回调。")
	assert_eq(GFVariantData.get_option_int(_timer_util.get_debug_snapshot(), "pending_count"), 0, "立即执行不应加入待执行队列。")


func test_execute_after_rejects_invalid_callback() -> void:
	var handle: int = _timer_util.execute_after(1.0, Callable())

	assert_eq(handle, 0, "无效回调不应返回有效句柄。")
	assert_push_error("[GFTimerUtility] execute_after 失败：传入的 callback 无效。")
	assert_eq(GFVariantData.get_option_int(_timer_util.get_debug_snapshot(), "pending_count"), 0, "无效回调不应加入待执行队列。")


func test_multiple_timers_fire_in_registration_order() -> void:
	var order: Array[String] = []

	var first_handle: int = _timer_util.execute_after(0.2, func() -> void:
		order.append("first")
	)
	var second_handle: int = _timer_util.execute_after(0.1, func() -> void:
		order.append("second")
	)

	_arch.tick(0.2)

	assert_gt(first_handle, 0, "第一个定时器应返回有效句柄。")
	assert_gt(second_handle, 0, "第二个定时器应返回有效句柄。")
	assert_eq(order, ["first", "second"], "同一 tick 中多个到期定时器应按注册顺序执行。")


func test_cancel_prevents_pending_timer_from_firing() -> void:
	var fired: TimerBoolState = TimerBoolState.new()

	var handle: int = _timer_util.execute_after(0.5, func() -> void:
		fired.value = true
	)

	assert_gt(handle, 0, "排队定时器应返回有效句柄。")
	assert_true(_timer_util.cancel(handle), "未触发的定时器应可取消。")
	assert_false(_timer_util.cancel(handle), "同一句柄取消一次后不应再次命中。")

	_arch.tick(0.5)

	assert_false(fired.value, "已取消的定时器不应触发。")


func test_dispose_clears_pending_timers() -> void:
	var fired: TimerBoolState = TimerBoolState.new()

	var handle: int = _timer_util.execute_after(0.1, func() -> void:
		fired.value = true
	)
	_timer_util.dispose()
	_timer_util.tick(0.2)

	assert_gt(handle, 0, "排队定时器应返回有效句柄。")
	assert_false(fired.value, "dispose 后残留定时器不应触发。")


func test_execute_repeating_runs_expected_count() -> void:
	var fired: TimerCountState = TimerCountState.new()

	var handle: int = _timer_util.execute_repeating(0.1, func() -> void:
		fired.count += 1
	, 3)

	assert_gt(handle, 0, "重复定时器应返回有效句柄。")
	_arch.tick(0.1)
	_arch.tick(0.1)
	_arch.tick(0.1)
	_arch.tick(0.1)

	assert_eq(fired.count, 3, "repeat_count 为 3 时应只触发三次。")
	assert_eq(GFVariantData.get_option_int(_timer_util.get_debug_snapshot(), "pending_count"), 0, "有限重复完成后不应继续保留待执行任务。")


func test_execute_repeating_catches_up_with_long_delta() -> void:
	var fired: TimerCountState = TimerCountState.new()

	var handle: int = _timer_util.execute_repeating(0.5, func() -> void:
		fired.count += 1
	, 3, 0.25)
	_arch.tick(1.25)

	assert_gt(handle, 0, "重复定时器应返回有效句柄。")
	assert_eq(fired.count, 3, "长 delta 应补齐当前 tick 内已到期的重复次数。")
	assert_eq(GFVariantData.get_option_int(_timer_util.get_debug_snapshot(), "pending_count"), 0, "有限重复补齐后不应继续保留待执行任务。")


func test_owner_bound_timer_is_dropped_when_owner_is_released() -> void:
	var fired: TimerBoolState = TimerBoolState.new()
	var timer_owner: RefCounted = RefCounted.new()

	var handle: int = _timer_util.execute_after_owned(timer_owner, 0.1, func() -> void:
		fired.value = true
	)
	timer_owner = null
	_arch.tick(0.2)

	assert_gt(handle, 0, "owner 绑定定时器应返回有效句柄。")
	assert_false(fired.value, "owner 释放后绑定定时器不应触发。")
	assert_eq(GFVariantData.get_option_int(_timer_util.get_debug_snapshot(), "pending_count"), 0, "释放 owner 后绑定任务应被清理。")


func test_cancel_owner_removes_owned_timers() -> void:
	var fired: TimerCountState = TimerCountState.new()
	var timer_owner: RefCounted = RefCounted.new()

	var after_handle: int = _timer_util.execute_after_owned(timer_owner, 0.1, func() -> void:
		fired.count += 1
	)
	var repeating_handle: int = _timer_util.execute_repeating_owned(timer_owner, 0.1, func() -> void:
		fired.count += 1
	)
	var removed: int = _timer_util.cancel_owner(timer_owner)
	_arch.tick(0.2)

	assert_gt(after_handle, 0, "owner 绑定单次定时器应返回有效句柄。")
	assert_gt(repeating_handle, 0, "owner 绑定重复定时器应返回有效句柄。")
	assert_eq(removed, 2, "cancel_owner 应取消同一 owner 的全部任务。")
	assert_eq(fired.count, 0, "被 cancel_owner 移除的任务不应触发。")


func test_cancel_repeating_timer_from_callback_stops_next_repeat() -> void:
	var fired: TimerCancelState = TimerCancelState.new()
	fired.handle = _timer_util.execute_repeating(0.1, func() -> void:
		fired.count += 1
		var cancelled: bool = _timer_util.cancel(fired.handle)
		assert_true(cancelled, "执行中的重复定时器应能被回调取消。")
	)

	_arch.tick(0.1)
	_arch.tick(0.1)

	assert_eq(fired.count, 1, "回调内取消重复任务后不应再次触发。")


func test_repeating_timer_drops_invalid_callback_when_ready() -> void:
	var receiver: TimerCallbackReceiver = TimerCallbackReceiver.new()
	add_child(receiver)
	var handle: int = _timer_util.execute_repeating(0.1, Callable(receiver, "mark"))
	receiver.free()

	_arch.tick(0.1)

	assert_gt(handle, 0, "重复定时器应先接受原本有效的回调。")
	assert_eq(GFVariantData.get_option_int(_timer_util.get_debug_snapshot(), "pending_count"), 0, "到期时回调已失效的重复定时器不应重新排队。")


# --- 辅助类 ---

class TimerBoolState:
	extends RefCounted

	var value: bool = false


class TimerCountState:
	extends RefCounted

	var count: int = 0


class TimerCancelState:
	extends RefCounted

	var count: int = 0
	var handle: int = 0


class TimerCallbackReceiver:
	extends Node

	var count: int = 0

	func mark() -> void:
		count += 1
