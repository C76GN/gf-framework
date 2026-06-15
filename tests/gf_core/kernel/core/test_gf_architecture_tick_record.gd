## 测试 GFArchitectureTickRecord 的 delta 策略和回调保护。
extends GutTest


class TickTarget extends RefCounted:
	var deltas: Array[float] = []

	func tick(delta: float) -> void:
		deltas.append(delta)


func test_tick_record_applies_time_policy() -> void:
	var target: TickTarget = TickTarget.new()
	var record: GFArchitectureTickRecord = GFArchitectureTickRecord.new().configure(
		target,
		Callable(target, &"tick"),
		0,
		0,
		false,
		false
	)

	record.invoke(1.0, 0.25, false)
	record.invoke(1.0, 0.25, true)

	assert_eq(target.deltas.size(), 2, "有效记录应调用缓存 Callable。")
	assert_almost_eq(target.deltas[0], 0.25, 0.0001, "默认策略应使用缩放 delta。")
	assert_almost_eq(target.deltas[1], 0.0, 0.0001, "未忽略暂停时应收到 0。")


func test_tick_record_can_ignore_pause_and_time_scale() -> void:
	var target: TickTarget = TickTarget.new()
	var record: GFArchitectureTickRecord = GFArchitectureTickRecord.new().configure(
		target,
		Callable(target, &"tick"),
		0,
		0,
		true,
		true
	)

	record.invoke(1.0, 0.25, false)
	record.invoke(1.0, 0.25, true)

	assert_almost_eq(target.deltas[0], 1.0, 0.0001, "ignore_time_scale 应使用原始 delta。")
	assert_almost_eq(target.deltas[1], 1.0, 0.0001, "ignore_pause 应在暂停时使用原始 delta。")


func test_tick_record_ignores_invalid_callback() -> void:
	var target: TickTarget = TickTarget.new()
	var record: GFArchitectureTickRecord = GFArchitectureTickRecord.new().configure(
		target,
		Callable(target, &"missing_tick"),
		0,
		0,
		false,
		false
	)

	record.invoke(1.0, 0.25, false)

	assert_eq(target.deltas.size(), 0, "无效 Callable 不应被调用。")
