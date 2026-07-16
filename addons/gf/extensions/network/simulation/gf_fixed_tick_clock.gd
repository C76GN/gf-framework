## GFFixedTickClock: 固定步长 tick 时钟。
##
## 用于网络同步、重放、确定性逻辑或任意固定频率调度；它只计算 tick 推进，不执行项目规则。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 3.17.0
class_name GFFixedTickClock
extends RefCounted


# --- 信号 ---

## tick 推进后发出。
## [br]
## @api public
## [br]
## @param previous_tick: 推进前 tick。
## [br]
## @param current_tick: 推进后 tick。
## [br]
## @param step_count: 本轮推进 tick 数。
signal ticks_advanced(previous_tick: int, current_tick: int, step_count: int)

## 固定 tick 循环开始时发出。
## [br]
## @api public
## [br]
## @param previous_tick: 循环前 tick。
## [br]
## @param target_tick: 本轮预算内预计推进到的 tick。
## [br]
## @param step_count: 本轮要处理的 tick 数。
signal tick_loop_started(previous_tick: int, target_tick: int, step_count: int)

## 单个固定 tick 开始时发出。
## [br]
## @api public
## [br]
## @param tick: 正在处理的 tick。
## [br]
## @param tick_seconds: 单个 tick 的秒数。
signal tick_started(tick: int, tick_seconds: float)

## 单个固定 tick 结束时发出。
## [br]
## @api public
## [br]
## @param tick: 已处理完成的 tick。
## [br]
## @param tick_seconds: 单个 tick 的秒数。
signal tick_finished(tick: int, tick_seconds: float)

## 固定 tick 循环结束时发出。
## [br]
## @api public
## [br]
## @param previous_tick: 循环前 tick。
## [br]
## @param current_tick: 循环后 tick。
## [br]
## @param step_count: 本轮实际处理的 tick 数。
signal tick_loop_finished(previous_tick: int, current_tick: int, step_count: int)

## 由于单次预算限制而未处理所有可用 tick 时发出。
## [br]
## @api public
## [br]
## @param available_steps: 本轮可用 tick 数。
## [br]
## @param processed_steps: 本轮实际处理 tick 数。
## [br]
## @param remaining_seconds: 预算处理后的累积剩余秒数。
signal tick_budget_exhausted(available_steps: int, processed_steps: int, remaining_seconds: float)


# --- 公共变量 ---

## 每秒 tick 数。
## [br]
## @api public
## [br]
## @since 3.17.0
var tick_rate: float = 30.0:
	set(value):
		tick_rate = _normalize_positive_finite(value, 30.0)

## 当前 tick。
## [br]
## @api public
var current_tick: int = 0

## 累积但尚未消费的时间。
## [br]
## @api public
## [br]
## @since 3.17.0
var accumulator_seconds: float = 0.0:
	set(value):
		accumulator_seconds = value if value >= 0.0 and not is_nan(value) and not is_inf(value) else 0.0

## 单次 advance() 最多推进的 tick 数；小于等于 0 表示不限制。
## [br]
## @api public
var max_steps_per_update: int = 8

## 达到单次预算上限时是否丢弃过量累积时间，避免长时间追帧。
## [br]
## @api public
var drop_excess_time_on_budget_hit: bool = true


# --- Godot 生命周期方法 ---

func _init(p_tick_rate: float = 30.0, p_start_tick: int = 0) -> void:
	tick_rate = _normalize_positive_finite(p_tick_rate, 30.0)
	current_tick = p_start_tick


# --- 公共方法 ---

## 配置时钟。
## [br]
## @api public
## [br]
## @param p_tick_rate: 每秒 tick 数。
## [br]
## @param p_max_steps_per_update: 单次 advance() 最大步数；小于 0 表示保留原值。
func configure(p_tick_rate: float, p_max_steps_per_update: int = -1) -> void:
	tick_rate = _normalize_positive_finite(p_tick_rate, tick_rate)
	if p_max_steps_per_update >= 0:
		max_steps_per_update = p_max_steps_per_update


## 重置时钟。
## [br]
## @api public
## [br]
## @param start_tick: 起始 tick。
func reset(start_tick: int = 0) -> void:
	current_tick = start_tick
	accumulator_seconds = 0.0


## 推进时钟并返回应执行的固定步数。
## [br]
## @api public
## [br]
## @param delta_seconds: 本次累积的真实时间。
## [br]
## @return 应执行的固定 tick 数。
func advance(delta_seconds: float) -> int:
	if delta_seconds <= 0.0 or is_nan(delta_seconds) or is_inf(delta_seconds):
		return 0

	accumulator_seconds += delta_seconds
	var tick_seconds: float = get_tick_seconds()
	var available_steps: int = GFVariantData.to_int(floor(accumulator_seconds / tick_seconds))
	if available_steps <= 0:
		return 0

	var step_count: int = available_steps
	if max_steps_per_update > 0:
		step_count = mini(step_count, max_steps_per_update)

	var previous_tick: int = current_tick
	_advance_steps(step_count, tick_seconds)
	accumulator_seconds -= tick_seconds * step_count
	if (
		drop_excess_time_on_budget_hit
		and max_steps_per_update > 0
		and available_steps > max_steps_per_update
	):
		accumulator_seconds = minf(accumulator_seconds, tick_seconds)

	ticks_advanced.emit(previous_tick, current_tick, step_count)
	if available_steps > step_count:
		tick_budget_exhausted.emit(available_steps, step_count, accumulator_seconds)
	return step_count


## 手动推进一个 tick。
## [br]
## @api public
## [br]
## @return 推进后的当前 tick。
func step_once() -> int:
	var previous_tick: int = current_tick
	_advance_steps(1, get_tick_seconds())
	ticks_advanced.emit(previous_tick, current_tick, 1)
	return current_tick


## 获取单个 tick 的秒数。
## [br]
## @api public
## [br]
## @return tick 秒数。
func get_tick_seconds() -> float:
	return 1.0 / _normalize_positive_finite(tick_rate, 30.0)


## 获取插值 alpha。
## [br]
## @api public
## [br]
## @return 0 到 1 的累积时间比例。
func get_interpolation_alpha() -> float:
	return clampf(accumulator_seconds / get_tick_seconds(), 0.0, 1.0)


## 获取当前 tick 插值比例。
## [br]
## @api public
## [br]
## @return 0 到 1 的累积时间比例。
func get_tick_factor() -> float:
	return get_interpolation_alpha()


## 获取当前累积延迟秒数。
## [br]
## @api public
## [br]
## @return 累积但尚未消费的时间。
func get_lag_seconds() -> float:
	return accumulator_seconds


## 转为字典。
## [br]
## @api public
## [br]
## @return 时钟状态字典。
## [br]
## @schema return: Dictionary，包含 tick_rate、current_tick、accumulator_seconds、max_steps_per_update、drop_excess_time_on_budget_hit。
func to_dict() -> Dictionary:
	return {
		"tick_rate": tick_rate,
		"current_tick": current_tick,
		"accumulator_seconds": accumulator_seconds,
		"max_steps_per_update": max_steps_per_update,
		"drop_excess_time_on_budget_hit": drop_excess_time_on_budget_hit,
	}


## 从字典恢复。
## [br]
## @api public
## [br]
## @param data: 时钟状态字典。
## [br]
## @schema data: Dictionary，包含 tick_rate、current_tick、accumulator_seconds、max_steps_per_update、drop_excess_time_on_budget_hit。
func from_dict(data: Dictionary) -> void:
	tick_rate = _normalize_positive_finite(
		GFVariantData.get_option_float(data, "tick_rate", tick_rate),
		tick_rate
	)
	current_tick = GFVariantData.get_option_int(data, "current_tick", current_tick)
	accumulator_seconds = _normalize_non_negative_finite(
		GFVariantData.get_option_float(data, "accumulator_seconds", accumulator_seconds),
		accumulator_seconds
	)
	max_steps_per_update = GFVariantData.get_option_int(
		data,
		"max_steps_per_update",
		max_steps_per_update
	)
	drop_excess_time_on_budget_hit = GFVariantData.get_option_bool(
		data,
		"drop_excess_time_on_budget_hit",
		drop_excess_time_on_budget_hit
	)


## 获取调试快照。
## [br]
## @api public
## [br]
## @return 调试信息字典。
## [br]
## @schema return: Dictionary，包含 to_dict() 字段以及 tick_seconds、interpolation_alpha、tick_factor、lag_seconds。
func get_debug_snapshot() -> Dictionary:
	var snapshot: Dictionary = to_dict()
	snapshot["tick_seconds"] = get_tick_seconds()
	snapshot["interpolation_alpha"] = get_interpolation_alpha()
	snapshot["tick_factor"] = get_tick_factor()
	snapshot["lag_seconds"] = get_lag_seconds()
	return snapshot


# --- 私有/辅助方法 ---

func _advance_steps(step_count: int, tick_seconds: float) -> void:
	if step_count <= 0:
		return

	var previous_tick: int = current_tick
	var target_tick: int = current_tick + step_count
	tick_loop_started.emit(previous_tick, target_tick, step_count)
	for _step_index: int in range(step_count):
		var next_tick: int = current_tick + 1
		tick_started.emit(next_tick, tick_seconds)
		current_tick = next_tick
		tick_finished.emit(current_tick, tick_seconds)
	tick_loop_finished.emit(previous_tick, current_tick, step_count)


func _normalize_positive_finite(value: float, fallback: float) -> float:
	if value > 0.0 and not is_nan(value) and not is_inf(value):
		return value
	if fallback > 0.0 and not is_nan(fallback) and not is_inf(fallback):
		return fallback
	return 30.0


func _normalize_non_negative_finite(value: float, fallback: float) -> float:
	if value >= 0.0 and not is_nan(value) and not is_inf(value):
		return value
	if fallback >= 0.0 and not is_nan(fallback) and not is_inf(fallback):
		return fallback
	return 0.0
