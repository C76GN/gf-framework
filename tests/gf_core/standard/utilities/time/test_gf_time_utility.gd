## 测试 GFTimeUtility 的时间缩放、暂停和组级暂停功能。
extends GutTest


# --- 私有变量 ---

var _utility: GFTimeUtility


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_utility = GFTimeUtility.new()
	_utility.init()


func after_each() -> void:
	_utility = null


# --- 测试：基本缩放 ---

## 验证默认缩放系数为 1.0，scaled_delta 等于原始 delta。
func test_default_scale_returns_raw_delta() -> void:
	var result: float = _utility.get_scaled_delta(0.016)
	assert_almost_eq(result, 0.016, 0.0001, "默认缩放系数应返回原始 delta。")


## 验证设置 time_scale = 0.5 后返回半速 delta。
func test_half_speed() -> void:
	_utility.time_scale = 0.5
	var result: float = _utility.get_scaled_delta(0.016)
	assert_almost_eq(result, 0.008, 0.0001, "0.5 缩放应返回一半的 delta。")


## 验证设置 time_scale = 2.0 后返回双倍 delta。
func test_double_speed() -> void:
	_utility.time_scale = 2.0
	var result: float = _utility.get_scaled_delta(0.016)
	assert_almost_eq(result, 0.032, 0.0001, "2.0 缩放应返回两倍的 delta。")


func test_max_scaled_delta_clamps_large_delta() -> void:
	_utility.time_scale = 10.0
	_utility.max_scaled_delta = 0.05

	var result: float = _utility.get_scaled_delta(0.016)

	assert_almost_eq(result, 0.05, 0.0001, "max_scaled_delta 应限制普通 scaled delta。")


func test_physics_substep_splits_scaled_delta() -> void:
	_utility.time_scale = 10.0
	_utility.physics_substep_max_delta = 0.05
	var steps: Array[float] = _utility.get_physics_scaled_delta_steps(0.016)

	assert_eq(steps.size(), 4, "0.16 秒缩放 delta 应拆分为 4 个子步。")
	assert_almost_eq(steps[0], 0.04, 0.0001, "子步应均分缩放后的 delta。")


## 验证负缩放系数被钳制为 0.0。
func test_negative_scale_clamped_to_zero() -> void:
	_utility.time_scale = -1.0
	assert_almost_eq(_utility.time_scale, 0.0, 0.0001, "负缩放应被钳制为 0.0。")
	var result: float = _utility.get_scaled_delta(0.016)
	assert_almost_eq(result, 0.0, 0.0001, "钳制后 delta 应为 0.0。")


func test_non_finite_time_configuration_preserves_last_valid_values() -> void:
	_utility.time_scale = 0.5
	_utility.max_scaled_delta = 0.25
	_utility.physics_substep_max_delta = 0.125

	_utility.time_scale = INF
	_utility.time_scale = -INF
	_utility.time_scale = NAN
	_utility.max_scaled_delta = INF
	_utility.max_scaled_delta = NAN
	_utility.physics_substep_max_delta = -INF
	_utility.physics_substep_max_delta = NAN

	assert_almost_eq(_utility.time_scale, 0.5, 0.0001, "非法 time_scale 不得覆盖上一有效值。")
	assert_almost_eq(_utility.max_scaled_delta, 0.25, 0.0001, "非法 delta 上限不得覆盖上一有效值。")
	assert_almost_eq(
		_utility.physics_substep_max_delta,
		0.125,
		0.0001,
		"非法 physics 子步上限不得覆盖上一有效值。"
	)
	assert_push_error("[GFTimeUtility] 忽略非有限 time_scale；保留上一有效值。")
	assert_push_error("[GFTimeUtility] 忽略非有限 max_scaled_delta；保留上一有效值。")
	assert_push_error("[GFTimeUtility] 忽略非有限 physics_substep_max_delta；保留上一有效值。")


func test_non_finite_delta_inputs_and_scaled_overflow_return_finite_safe_values() -> void:
	var scaled_inf: float = _utility.get_scaled_delta(INF)
	var grouped_nan: float = _utility.get_group_scaled_delta(&"game", NAN)
	var physics_steps: Array[float] = _utility.get_physics_scaled_delta_steps(-INF)
	var should_substep: bool = _utility.should_substep_physics(INF)

	assert_eq(scaled_inf, 0.0, "非有限普通 delta 应返回安全零值。")
	assert_eq(grouped_nan, 0.0, "非有限分组 delta 应返回安全零值。")
	assert_eq(physics_steps, [0.0], "非有限 physics delta 应返回单个安全零步。")
	assert_false(should_substep, "非有限 physics delta 不应触发子步。")
	assert_push_error("[GFTimeUtility] delta 必须为有限数；本次返回安全零值。")

	_utility.init()
	_utility.time_scale = 2.0
	var overflow_result: float = _utility.get_scaled_delta(1.0e308)
	assert_eq(overflow_result, 0.0, "两个有限数的乘积溢出时也不得向系统传播 Infinity。")
	assert_push_error("[GFTimeUtility] scaled_delta 溢出为非有限数；本次返回安全零值。")


func test_finite_extreme_physics_ratio_uses_bounded_substep_count() -> void:
	_utility.time_scale = 1.0
	_utility.physics_substep_max_delta = 1.0e-300
	_utility.max_physics_substeps = 8

	var steps: Array[float] = _utility.get_physics_scaled_delta_steps(1.0e308)

	assert_eq(steps.size(), 8, "有限但极端的步长比值必须直接受 max_physics_substeps 限制。")
	for step_delta: float in steps:
		assert_false(is_nan(step_delta), "physics 子步不得为 NaN。")
		assert_false(is_inf(step_delta), "physics 子步不得为 Infinity。")


# --- 测试：暂停 ---

## 验证暂停时 get_scaled_delta 返回 0.0。
func test_paused_returns_zero() -> void:
	_utility.is_paused = true
	var result: float = _utility.get_scaled_delta(0.016)
	assert_almost_eq(result, 0.0, 0.0001, "暂停时应返回 0.0。")


## 验证取消暂停后恢复正常。
func test_unpause_restores_delta() -> void:
	_utility.is_paused = true
	_utility.is_paused = false
	var result: float = _utility.get_scaled_delta(0.016)
	assert_almost_eq(result, 0.016, 0.0001, "取消暂停后应恢复正常 delta。")


# --- 测试：组级暂停 ---

## 验证组暂停后 get_group_scaled_delta 返回 0.0。
func test_group_paused_returns_zero() -> void:
	_utility.set_group_paused(&"ui", true)
	var result: float = _utility.get_group_scaled_delta(&"ui", 0.016)
	assert_almost_eq(result, 0.0, 0.0001, "组暂停时应返回 0.0。")


## 验证未暂停的组返回正常 delta。
func test_unpaused_group_returns_scaled_delta() -> void:
	_utility.time_scale = 0.5
	_utility.set_group_paused(&"game", false)
	var result: float = _utility.get_group_scaled_delta(&"game", 0.016)
	assert_almost_eq(result, 0.008, 0.0001, "未暂停的组应返回缩放后的 delta。")


## 验证未注册的组默认不暂停。
func test_unknown_group_is_not_paused() -> void:
	assert_false(_utility.is_group_paused(&"unknown"), "未注册的组应默认不暂停。")


## 验证全局暂停时，组级 delta 也返回 0.0。
func test_global_pause_overrides_group() -> void:
	_utility.is_paused = true
	_utility.set_group_paused(&"game", false)
	var result: float = _utility.get_group_scaled_delta(&"game", 0.016)
	assert_almost_eq(result, 0.0, 0.0001, "全局暂停应覆盖组级设置。")


## 验证 remove_group 移除后查询返回 false。
func test_remove_group() -> void:
	_utility.set_group_paused(&"fx", true)
	_utility.remove_group(&"fx")
	assert_false(_utility.is_group_paused(&"fx"), "移除后应返回 false。")


## 验证 init 重置所有状态。
func test_init_resets_state() -> void:
	var clock: GFManualClock = GFManualClock.new(120000, 1700000000000)
	assert_true(_utility.set_clock(clock), "测试时钟应能注入。")
	_utility.time_scale = 3.0
	_utility.is_paused = true
	_utility.set_group_paused(&"test", true)
	_utility.init()
	assert_almost_eq(_utility.time_scale, 1.0, 0.0001, "init 后缩放应重置为 1.0。")
	assert_false(_utility.is_paused, "init 后暂停应重置为 false。")
	assert_false(_utility.is_group_paused(&"test"), "init 后组暂停应被清除。")
	assert_same(_utility.get_clock(), clock, "init 不应替换显式注入的时钟。")


# --- 测试：时钟语义 ---

func test_manual_clock_separates_monotonic_and_wall_time() -> void:
	var clock: GFManualClock = GFManualClock.new(125000, 1700000000125)
	assert_true(_utility.set_clock(clock), "GFTimeProvider 应接受明确时钟。")

	assert_eq(_utility.get_monotonic_usec(), 125000, "单调微秒应来自注入时钟。")
	assert_eq(_utility.get_monotonic_msec(), 125, "单调毫秒应来自注入时钟。")
	assert_eq(_utility.get_unix_time_msec(), 1700000000125, "墙上时间应保持独立。")
	assert_eq(_utility.get_unix_time_seconds(), 1700000000, "Unix 秒应按毫秒截断。")

	assert_true(clock.advance_msec(25), "手动时钟应能确定推进。")
	assert_eq(_utility.get_monotonic_msec(), 150, "推进后单调时间应增加。")
	assert_eq(_utility.get_unix_time_msec(), 1700000000150, "推进后墙上时间应同步增加。")

	assert_true(clock.set_unix_time_msec(1600000000000), "墙上时钟应允许模拟系统回拨。")
	assert_eq(_utility.get_monotonic_msec(), 150, "墙上时钟回拨不得影响单调时间。")
	assert_eq(_utility.get_unix_time_msec(), 1600000000000, "墙上时钟应使用显式新值。")


func test_manual_clock_rejects_monotonic_rollback() -> void:
	var clock: GFManualClock = GFManualClock.new(1000, 2000)

	assert_false(clock.advance_usec(-1), "单调微秒不得反向推进。")
	assert_false(clock.advance_msec(-1), "单调毫秒不得反向推进。")
	assert_false(clock.set_unix_time_msec(-1), "墙上时钟不得设置为负值。")
	assert_eq(clock.get_monotonic_usec(), 1000, "非法推进不得修改单调时间。")
	assert_eq(clock.get_unix_time_msec(), 2000, "非法设置不得修改墙上时间。")


## 验证模块可选择忽略 time_scale 但仍尊重暂停。
func test_architecture_module_can_ignore_time_scale() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var time_utility: GFTimeUtility = GFTimeUtility.new()
	var system: DeltaRecorderSystem = DeltaRecorderSystem.new()
	system.ignore_time_scale = true
	await arch.register_utility_instance(time_utility)
	await arch.register_system_instance(system)
	await arch.init()

	time_utility.time_scale = 0.25
	arch.tick(1.0)
	assert_almost_eq(system.last_delta, 1.0, 0.0001, "ignore_time_scale 的模块应接收原始 delta。")

	time_utility.is_paused = true
	arch.tick(1.0)
	assert_almost_eq(system.last_delta, 0.0, 0.0001, "未设置 ignore_pause 时仍应尊重全局暂停。")

	arch.dispose()


func test_architecture_physics_tick_uses_time_utility_substeps() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	var time_utility: GFTimeUtility = GFTimeUtility.new()
	var system: DeltaRecorderSystem = DeltaRecorderSystem.new()
	await arch.register_utility_instance(time_utility)
	await arch.register_system_instance(system)
	await arch.init()

	time_utility.time_scale = 10.0
	time_utility.physics_substep_max_delta = 0.05
	arch.physics_tick(0.016)

	assert_eq(system.physics_deltas.size(), 4, "架构 physics_tick 应按 GFTimeUtility 子步进驱动模块。")
	assert_almost_eq(system.physics_deltas[0], 0.04, 0.0001, "模块应收到缩放后的子步 delta。")

	arch.dispose()


# --- 辅助类 ---

class DeltaRecorderSystem extends GFSystem:
	var last_delta: float = -1.0
	var physics_deltas: Array[float] = []

	func tick(delta: float) -> void:
		last_delta = delta

	func physics_tick(delta: float) -> void:
		physics_deltas.append(delta)
