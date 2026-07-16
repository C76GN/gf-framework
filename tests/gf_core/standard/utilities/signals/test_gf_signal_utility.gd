## 测试 GFSignalUtility 的安全连接、owner 清理和链式处理。
extends GutTest


# --- 私有变量 ---

var _utility: GFSignalUtility


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_utility = GFSignalUtility.new()


func after_each() -> void:
	if _utility != null:
		_utility.dispose()
	_utility = null


# --- 测试 ---

func test_connect_signal_invokes_callback_with_default_args() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []

	var _connect_signal_result_28: Variant = _utility.connect_signal(
		emitter.changed,
		func(prefix: String, value: int) -> void:
			received.append("%s:%s" % [prefix, value]),
		null,
		["hp"]
	)
	emitter.emit_changed(7)

	await get_tree().process_frame

	assert_eq(received, ["hp:7"], "Signal 回调应收到默认参数和动态参数。")


func test_connect_signal_preserves_declared_trailing_null_argument() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []

	var _connect_signal_result_46: Variant = _utility.connect_signal(emitter.optional_payload, func(value: Variant) -> void:
		received.append(value)
	)
	emitter.emit_optional_payload(null)

	await get_tree().process_frame

	assert_eq(received, [null], "显式发出的 null 参数不应被当作占位默认值裁掉。")


func test_connect_signal_keeps_nine_signal_arguments() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []

	var _connect_signal_result_60: Variant = _utility.connect_signal(emitter.wide_payload, func(
		first: int,
		second: int,
		third: int,
		fourth: int,
		fifth: int,
		sixth: int,
		seventh: int,
		eighth: int,
		ninth: int
	) -> void:
		received.clear()
		received.append_array([first, second, third, fourth, fifth, sixth, seventh, eighth, ninth])
	)
	emitter.emit_wide_payload()

	await get_tree().process_frame

	assert_eq(received, [1, 2, 3, 4, 5, 6, 7, 8, 9], "Signal 连接应保留 9 个参数。")


func test_filter_map_delay_chain() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []

	var _delay_result_85: Variant = _utility.connect_signal(emitter.changed, func(value: int) -> void:
		received.append(value)
	).filter(func(value: int) -> bool:
		return value > 2
	).map(func(value: int) -> int:
		return value * 10
	).delay(0.001)

	emitter.emit_changed(1)
	emitter.emit_changed(3)

	await get_tree().create_timer(0.03).timeout

	assert_eq(received, [30], "链式 filter/map/delay 应按顺序处理参数。")


func test_delay_keeps_each_emit() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []

	var _delay_result_101: Variant = _utility.connect_signal(emitter.changed, func(value: int) -> void:
		received.append(value)
	).delay(0.01)

	emitter.emit_changed(1)
	emitter.emit_changed(2)
	await get_tree().create_timer(0.05).timeout
	await get_tree().process_frame

	assert_eq(received, [1, 2], "延迟应保留每一次触发，而不是被后续触发取消。")


func test_debounce_keeps_last_emit() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []

	var _debounce_result_119: Variant = _utility.connect_signal(emitter.changed, func(value: int) -> void:
		received.append(value)
	).debounce(0.02)

	emitter.emit_changed(1)
	emitter.emit_changed(2)
	await get_tree().create_timer(0.05).timeout
	await get_tree().process_frame

	assert_eq(received, [2], "防抖应只保留静默期后的最后一次触发。")


func test_throttle_limits_signal_frequency() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []

	var _throttle_result_122: Variant = _utility.connect_signal(emitter.changed, func(value: int) -> void:
		received.append(value)
	).throttle(0.03)

	emitter.emit_changed(1)
	emitter.emit_changed(2)
	await _wait_real_msec(50)
	emitter.emit_changed(3)
	await get_tree().process_frame

	assert_eq(received, [1, 3], "节流应保留窗口内首次触发，并允许窗口后的新触发。")


func test_skip_take_scan_and_start_with_can_chain() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []

	var _start_with_result_139: Variant = _utility.connect_signal(emitter.changed, func(value: int) -> void:
		received.append(value)
	).skip(1).take(2).scan(0, func(accumulator: int, value: int) -> int:
		return accumulator + value
	).start_with([1])

	emitter.emit_changed(2)
	emitter.emit_changed(3)
	emitter.emit_changed(4)
	await get_tree().process_frame

	assert_eq(received, [2, 5], "skip/take/scan/start_with 应按链式顺序组合。")
	assert_eq(_utility.get_connection_count(), 0, "take 耗尽后连接应自动移除。")


func test_connect_any_and_disconnect_connections() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []
	var callback: Callable = func(value: Variant) -> void:
		received.append(value)

	var connections: Array[GFSignalConnection] = _utility.connect_any([emitter.changed, emitter.optional_payload], callback)
	emitter.emit_changed(1)
	emitter.emit_optional_payload("two")
	await get_tree().process_frame

	assert_eq(received, [1, "two"], "connect_any 应把多个 Signal 接到同一个回调。")
	_utility.disconnect_connections(connections)
	emitter.emit_changed(3)
	await get_tree().process_frame
	assert_eq(received, [1, "two"], "disconnect_connections 应断开批量连接。")


func test_direct_connection_disconnect_untracks_from_utility() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []
	var callback: Callable = func(value: int) -> void:
		received.append(value)

	var connection: GFSignalConnection = _utility.connect_signal(emitter.changed, callback)
	assert_eq(_utility.get_connection_count(), 1, "连接启动后工具应追踪句柄。")

	connection.disconnect_signal()
	emitter.emit_changed(3)
	await get_tree().process_frame

	assert_true(received.is_empty(), "直接断开连接后回调不应再触发。")
	assert_eq(_utility.get_connection_count(), 0, "直接断开连接后工具追踪计数应归零。")


func test_connect_once_disconnects_after_first_emit() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var count: Array[Variant] = []

	var _connect_once_result_176: Variant = _utility.connect_once(emitter.changed, func(value: int) -> void:
		count.append(value)
	)

	emitter.emit_changed(1)
	emitter.emit_changed(2)
	await get_tree().process_frame

	assert_eq(count, [1], "connect_once 应只触发一次。")
	assert_eq(_utility.get_connection_count(), 0, "一次性连接触发后应从工具追踪中移除。")


func test_connect_once_does_not_mutate_existing_persistent_connection() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []
	var callback: Callable = func(value: int) -> void:
		received.append(value)

	var _connect_signal_result_194: Variant = _utility.connect_signal(emitter.changed, callback)
	var _connect_once_result_195: Variant = _utility.connect_once(emitter.changed, callback)

	emitter.emit_changed(1)
	emitter.emit_changed(2)
	await get_tree().process_frame

	assert_eq(received, [1, 1, 2], "同一回调的常驻连接和一次性连接应各自保持语义。")
	assert_eq(_utility.get_connection_count(), 1, "一次性连接移除后应保留常驻连接。")


func test_connect_signal_distinguishes_default_args() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []
	var callback: Callable = func(prefix: String, value: int) -> void:
		received.append("%s:%s" % [prefix, value])

	var _connect_signal_result_211: Variant = _utility.connect_signal(emitter.changed, callback, null, ["a"])
	var _connect_signal_result_212: Variant = _utility.connect_signal(emitter.changed, callback, null, ["b"])
	emitter.emit_changed(5)

	await get_tree().process_frame

	assert_eq(received, ["a:5", "b:5"], "相同 Signal/回调但默认参数不同应保留为两个连接。")


func test_connect_signal_does_not_reuse_chain_mutated_connection() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []
	var callback: Callable = func(value: int) -> void:
		received.append(value)

	var _delayed_result: Variant = _utility.connect_signal(emitter.changed, callback).delay(0.03)
	var _direct_result: GFSignalConnection = _utility.connect_signal(emitter.changed, callback)
	emitter.emit_changed(8)

	await get_tree().process_frame
	assert_eq(received, [8], "已链式配置的连接不应阻止同配置普通连接立即触发。")

	await get_tree().create_timer(0.06).timeout
	await get_tree().process_frame

	assert_eq(received, [8, 8], "链式连接和普通连接应各自保留独立语义。")


func test_disconnect_owner_removes_owned_connections() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var listener_owner: SampleOwner = SampleOwner.new()
	var count: Array[Variant] = []
	var callback: Callable = func(value: int) -> void:
		count.append(value)

	var _connect_signal_result_227: Variant = _utility.connect_signal(emitter.changed, callback, listener_owner)
	_utility.disconnect_owner(listener_owner)
	emitter.emit_changed(1)

	await get_tree().process_frame

	assert_true(count.is_empty(), "owner 清理后回调不应再触发。")
	assert_eq(_utility.get_connection_count(), 0, "owner 清理后连接计数应归零。")


func test_prune_invalid_connections_removes_released_callback_target_without_owner() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var listener: SampleListener = SampleListener.new()
	add_child(listener)

	var _connect_signal_result_242: Variant = _utility.connect_signal(emitter.changed, Callable(listener, "on_changed"))
	assert_eq(_utility.get_connection_count(), 1, "释放监听目标前应记录连接。")

	listener.queue_free()
	await get_tree().process_frame

	assert_eq(_utility.get_connection_count(), 0, "callback 目标失效后连接应能被清理。")
	emitter.emit_changed(1)
	await get_tree().process_frame
	assert_eq(_utility.get_connection_count(), 0, "清理后再次发射信号不应恢复失效连接。")


func test_invalid_callback_is_not_tracked_as_connection() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()

	var _connect_signal_result_257: Variant = _utility.connect_signal(emitter.changed, Callable())

	assert_push_error("[GFSignalConnection] start 失败：callback 无效。")
	assert_eq(_utility.get_connection_count(), 0, "启动失败的连接不应残留在工具追踪列表中。")


func test_signal_connect_error_is_not_tracked_as_connection() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var callback: Callable = func(value: int) -> void:
		var _unused_value: int = value
	var connection: GFSignalConnection = GFSignalConnection.new(emitter.changed, callback)
	var internal_callable: Callable = Callable(connection, &"_on_signal_emitted")

	var manual_connect_error: Error = emitter.changed.connect(internal_callable) as Error
	assert_eq(manual_connect_error, OK, "测试准备阶段应能先占用内部连接 callable。")

	var _start_result_290: GFSignalConnection = connection.start()
	assert_push_error("[GFSignalConnection] start 失败：Signal 已连接。")
	assert_false(connection.is_active(), "connect 返回错误时连接句柄不应标记为已连接。")

	if emitter.changed.is_connected(internal_callable):
		emitter.changed.disconnect(internal_callable)


func test_disconnect_signal_cancels_pending_delayed_callback() -> void:
	var emitter: SampleEmitter = SampleEmitter.new()
	var received: Array[Variant] = []
	var callback: Callable = func(value: int) -> void:
		received.append(value)

	var _connection: GFSignalConnection = _utility.connect_signal(emitter.changed, callback).delay(0.03)
	emitter.emit_changed(9)
	_utility.disconnect_signal(emitter.changed, callback)

	await get_tree().create_timer(0.06).timeout
	await get_tree().process_frame
	_connection = null

	assert_true(received.is_empty(), "延迟等待中的连接被断开后不应继续调用回调。")
	assert_eq(_utility.get_connection_count(), 0, "断开延迟连接后追踪计数应归零。")


# --- 私有/辅助方法 ---

func _wait_real_msec(milliseconds: int) -> void:
	var start_msec: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_msec < milliseconds:
		await get_tree().process_frame


# --- 内部类 ---

class SampleEmitter:
	extends RefCounted

	signal changed(value: int)
	signal optional_payload(value: Variant)
	signal wide_payload(
		first: int,
		second: int,
		third: int,
		fourth: int,
		fifth: int,
		sixth: int,
		seventh: int,
		eighth: int,
		ninth: int
	)

	func emit_changed(value: int) -> void:
		changed.emit(value)

	func emit_optional_payload(value: Variant) -> void:
		optional_payload.emit(value)

	func emit_wide_payload() -> void:
		wide_payload.emit(1, 2, 3, 4, 5, 6, 7, 8, 9)


class SampleOwner:
	extends RefCounted


class SampleListener:
	extends Node

	var received: Array[int] = []

	func on_changed(value: int) -> void:
		received.append(value)
