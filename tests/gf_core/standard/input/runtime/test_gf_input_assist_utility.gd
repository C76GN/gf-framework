## 测试 GFInputAssistUtility 的动作缓冲和宽容窗口功能。
extends GutTest


# --- 私有变量 ---

var _utility: GFInputAssistUtility


# --- Godot 生命周期方法 ---

func before_each() -> void:
	_utility = GFInputAssistUtility.new()
	_utility.init()


func after_each() -> void:
	_utility = null


# --- 测试：输入缓冲 ---

## 验证输入辅助默认使用真实 delta，不受全局 time_scale 影响。
func test_input_assist_utility_ignores_time_scale() -> void:
	assert_true(_utility.ignore_time_scale, "输入缓冲与宽容窗口应默认按真实时间递减。")


## 验证缓冲后可成功消费。
func test_buffer_and_consume() -> void:
	_utility.buffer_action(&"jump", 0.15)
	assert_true(_utility.consume_buffered_action(&"jump"), "缓冲后应可消费。")


## 验证消费后再次消费返回 false。
func test_consume_clears_buffer() -> void:
	_utility.buffer_action(&"jump", 0.15)
	var _consume_buffered_action_result_37: Variant = _utility.consume_buffered_action(&"jump")
	assert_false(_utility.consume_buffered_action(&"jump"), "消费后不应再次消费成功。")


## 验证缓冲过期后消费返回 false。
func test_buffer_expires_after_duration() -> void:
	_utility.buffer_action(&"attack", 0.1)
	_utility.tick(0.05)
	assert_true(_utility.has_buffered_action(&"attack"), "未过期时仍应有缓冲。")
	_utility.tick(0.06)
	assert_false(_utility.has_buffered_action(&"attack"), "过期后缓冲应被清除。")
	assert_false(_utility.consume_buffered_action(&"attack"), "过期后消费应返回 false。")


## 验证未缓冲的动作消费返回 false。
func test_consume_unbuffered_returns_false() -> void:
	assert_false(_utility.consume_buffered_action(&"dash"), "未缓冲的动作消费应返回 false。")


## 验证重复缓冲取最大持续时间。
func test_buffer_refresh_takes_max() -> void:
	_utility.buffer_action(&"jump", 0.05)
	_utility.buffer_action(&"jump", 0.2)
	_utility.tick(0.1)
	assert_true(_utility.has_buffered_action(&"jump"), "刷新后应使用更长的持续时间。")


## 验证非正数缓冲时长不会形成可消费输入。
func test_non_positive_buffer_duration_is_not_consumable() -> void:
	_utility.buffer_action(&"jump", 0.0)
	_utility.buffer_action(&"dash", -1.0)

	assert_false(_utility.has_buffered_action(&"jump"), "0 秒缓冲不应活跃。")
	assert_false(_utility.consume_buffered_action(&"jump"), "0 秒缓冲不应可消费。")
	assert_false(_utility.has_buffered_action(&"dash"), "负数缓冲不应活跃。")
	assert_false(_utility.consume_buffered_action(&"dash"), "负数缓冲不应可消费。")


## 验证多个不同动作可并行缓冲。
func test_multiple_actions_parallel() -> void:
	_utility.buffer_action(&"jump", 0.2)
	_utility.buffer_action(&"dash", 0.1)
	assert_true(_utility.has_buffered_action(&"jump"), "jump 应有缓冲。")
	assert_true(_utility.has_buffered_action(&"dash"), "dash 应有缓冲。")


# --- 测试：宽容窗口 ---

## 验证宽容窗口内查询返回 true。
func test_grace_window_active_within_window() -> void:
	_utility.start_grace_window(&"ground", 0.1)
	_utility.tick(0.05)
	assert_true(_utility.is_grace_window_active(&"ground"), "窗口内应返回 true。")


## 验证宽容窗口过期后返回 false。
func test_grace_window_expires_after_window() -> void:
	_utility.start_grace_window(&"ground", 0.1)
	_utility.tick(0.11)
	assert_false(_utility.is_grace_window_active(&"ground"), "过期后应返回 false。")


## 验证宽容窗口自然过期时发出一次过期信号。
func test_grace_window_expired_signal_emitted_once() -> void:
	watch_signals(_utility)

	_utility.start_grace_window(&"ground", 0.1, 2)
	_utility.tick(0.05)

	assert_signal_not_emitted(_utility, "grace_window_expired", "窗口未过期时不应发出过期信号。")

	_utility.tick(0.06)
	_utility.tick(1.0)

	assert_signal_emitted_with_parameters(_utility, "grace_window_expired", [&"ground", 2])
	assert_signal_emit_count(_utility, "grace_window_expired", 1)


## 验证手动取消宽容窗口不会伪装成自然过期。
func test_cancel_grace_window_does_not_emit_expired_signal() -> void:
	watch_signals(_utility)

	_utility.start_grace_window(&"wall", 1.0)
	_utility.cancel_grace_window(&"wall")
	_utility.tick(1.1)

	assert_signal_not_emitted(_utility, "grace_window_expired", "手动取消不应发出自然过期信号。")


## 验证手动取消宽容窗口。
func test_cancel_grace_window() -> void:
	_utility.start_grace_window(&"wall", 1.0)
	_utility.cancel_grace_window(&"wall")
	assert_false(_utility.is_grace_window_active(&"wall"), "取消后应返回 false。")


## 验证未启动的窗口查询返回 false。
func test_inactive_grace_window_returns_false() -> void:
	assert_false(_utility.is_grace_window_active(&"air"), "未启动的窗口应返回 false。")


## 验证 clear_all 清除所有状态。
func test_clear_all() -> void:
	_utility.buffer_action(&"jump", 1.0)
	_utility.start_grace_window(&"ground", 1.0)
	_utility.clear_all()
	assert_false(_utility.has_buffered_action(&"jump"), "clear 后缓冲应被清除。")
	assert_false(_utility.is_grace_window_active(&"ground"), "clear 后宽容窗口应被清除。")


## 验证负数 delta 不会反向延长缓冲或土狼时间。
func test_negative_tick_does_not_extend_timers() -> void:
	_utility.buffer_action(&"jump", 0.1)
	_utility.start_grace_window(&"ground", 0.1)

	_utility.tick(-1.0)
	_utility.tick(0.11)

	assert_false(_utility.has_buffered_action(&"jump"), "负 delta 不应延长输入缓冲。")
	assert_false(_utility.is_grace_window_active(&"ground"), "负 delta 不应延长宽容窗口。")


## 验证玩家级缓冲互相隔离。
func test_player_scoped_buffer_isolated() -> void:
	_utility.buffer_action(&"jump", 0.2, 0)

	assert_true(_utility.consume_buffered_action(&"jump", 0), "0 号玩家应能消费自己的缓冲。")
	assert_false(_utility.consume_buffered_action(&"jump", 1), "1 号玩家不应消费 0 号玩家的缓冲。")


## 验证 clear_player 只清理指定玩家。
func test_clear_player_only_clears_target_scope() -> void:
	_utility.buffer_action(&"jump", 1.0, 0)
	_utility.buffer_action(&"jump", 1.0, 1)
	_utility.start_grace_window(&"ground", 1.0, 0)
	_utility.start_grace_window(&"ground", 1.0, 1)

	_utility.clear_player(0)

	assert_false(_utility.has_buffered_action(&"jump", 0), "目标玩家缓冲应被清理。")
	assert_false(_utility.is_grace_window_active(&"ground", 0), "目标玩家窗口应被清理。")
	assert_true(_utility.has_buffered_action(&"jump", 1), "其他玩家缓冲应保留。")
	assert_true(_utility.is_grace_window_active(&"ground", 1), "其他玩家窗口应保留。")


## 验证调试快照包含剩余时间。
func test_debug_snapshot_reports_timers() -> void:
	_utility.buffer_action(&"jump", 0.2)
	_utility.start_grace_window(&"ground", 0.1)

	var snapshot: Dictionary = _utility.get_debug_snapshot()
	var action_buffers: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(snapshot, "action_buffers")
	)
	var grace_windows: Dictionary = GFVariantData.as_dictionary(
		GFVariantData.get_option_value(snapshot, "grace_windows")
	)

	assert_true(action_buffers.has("global/jump"), "快照应包含动作缓冲。")
	assert_true(grace_windows.has("global/ground"), "快照应包含宽容窗口。")
