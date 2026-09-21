## GFProgressionMath: 挂机与模拟经营项目的纯进度曲线数学工具。
##
## 负责价格曲线、收益曲线、里程碑倍率、软上限与分段式离线收益结算。
## 它不依赖 GFArchitecture，可直接与 JSON、CSV 或外部工具导出的配置字典配合使用。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFProgressionMath
extends RefCounted


# --- 枚举 ---

## 支持的基础曲线类型。
## [br]
## @api public
enum CurveMode {
	## 常量曲线。
	CONSTANT,
	## 线性曲线。
	LINEAR,
	## 指数曲线。
	EXPONENTIAL,
}


# --- 常量 ---

# 默认的软上限幂指数。
const _DEFAULT_SOFT_CAP_POWER: float = 0.5


# --- 公共方法 ---

## 根据配置计算某一级的曲线值。
## [br]
## @api public
## [br]
## @param level: 目标等级。
## [br]
## @param curve_config: 支持 `base_value/start_level/mode/per_level/multiplier/phases/overrides`。
## [br]
## @schema curve_config: Dictionary with optional `base_value`, `start_level`, `mode`, `per_level`, `multiplier`, `phases`, and `overrides` entries.
## [br]
## @return 对应等级的曲线值。
static func evaluate_curve(level: int, curve_config: Dictionary) -> GFBigNumber:
	var target_level: int = maxi(level, 0)
	var override_value: Variant = _find_override_value(
		target_level,
		GFVariantData.get_option_value(curve_config, "overrides", {})
	)
	if override_value != null:
		return _to_big_number(override_value)

	var phases: Array = GFVariantData.get_option_array(curve_config, "phases")
	if not phases.is_empty():
		return _evaluate_piecewise_curve(target_level, phases, curve_config)

	return _evaluate_single_curve(target_level, curve_config)


## 为基础值叠加里程碑倍率。
## [br]
## @api public
## [br]
## @param value: 基础数值。
## [br]
## @schema value: Variant numeric value accepted by GFBigNumber.
## [br]
## @param level: 当前等级。
## [br]
## @param milestones: 里程碑数组；每项支持 `level/multiplier`。
## [br]
## @schema milestones: Array[Dictionary] where each entry may contain `level: int` and `multiplier: Variant numeric value`.
## [br]
## @return 叠加后的数值。
static func apply_milestone_multipliers(value: Variant, level: int, milestones: Array) -> GFBigNumber:
	var result: GFBigNumber = _to_big_number(value)
	var target_level: int = maxi(level, 0)

	for milestone_variant: Variant in milestones:
		if not (milestone_variant is Dictionary):
			continue

		var milestone: Dictionary = milestone_variant
		var required_level: int = GFVariantData.get_option_int(milestone, "level", 0)
		if target_level < required_level:
			continue

		var multiplier: float = _get_option_progression_float(milestone, "multiplier", 1.0)
		result = result.multiply(_to_big_number(multiplier))

	return result


## 对一个值应用幂函数型软上限。
## [br]
## @api public
## [br]
## @param value: 原始值。
## [br]
## @schema value: Variant numeric value accepted by GFBigNumber.
## [br]
## @param soft_cap: 软上限起点。
## [br]
## @schema soft_cap: Variant numeric value accepted by GFBigNumber.
## [br]
## @param power: 超出部分的幂指数；0.5 表示平方根衰减。
## [br]
## @return 软上限处理后的数值。
static func apply_soft_cap(
	value: Variant,
	soft_cap: Variant,
	power: float = _DEFAULT_SOFT_CAP_POWER
) -> GFBigNumber:
	var big_value: GFBigNumber = _to_big_number(value)
	var cap_value: GFBigNumber = _to_big_number(soft_cap)

	if power <= 0.0:
		push_error("[GFProgressionMath][progression_math.soft_cap_power_invalid] Soft cap power must be greater than zero.")
		return cap_value

	if big_value.compare_to(cap_value) <= 0 or is_equal_approx(power, 1.0):
		return big_value

	var overflow: GFBigNumber = big_value.subtract(cap_value)
	var softened_overflow: GFBigNumber = overflow.powf(power)
	return cap_value.add(softened_overflow)


## 计算一段离线时间内的收益。
## [br]
## @api public
## [br]
## @param rate_per_second: 基础每秒产出。
## [br]
## @schema rate_per_second: Variant numeric value accepted by GFBigNumber.
## [br]
## @param offline_seconds: 离线时长（秒）。
## [br]
## @param options: 支持 `max_seconds/storage_remaining/segments`。
## [br]
## @schema options: Dictionary with optional `max_seconds`, `storage_remaining`, and `segments: Array[Dictionary]`.
## [br]
## @return 包含产出与时间统计的字典。
## [br]
## @schema return: Dictionary with `produced: GFBigNumber`, `requested_seconds: float`, `settled_seconds: float`, `consumed_seconds: float`, `expired_seconds: float`, `wasted_seconds: float`, and `storage_capped: bool`.
static func settle_offline_progress(
	rate_per_second: Variant,
	offline_seconds: float,
	options: Dictionary = {}
) -> Dictionary:
	var base_rate: GFBigNumber = _to_big_number(rate_per_second)
	var zero_value: GFBigNumber = _to_big_number(0)
	var requested_seconds: float = maxf(offline_seconds, 0.0)
	var settled_seconds: float = requested_seconds
	if options.has("max_seconds"):
		settled_seconds = minf(settled_seconds, maxf(_get_option_progression_float(options, "max_seconds", 0.0), 0.0))

	var total_produced: GFBigNumber = _to_big_number(0)
	var consumed_seconds: float = 0.0
	var storage_capped: bool = false
	var segments: Array = GFVariantData.get_option_array(options, "segments")
	var remaining_seconds: float = settled_seconds
	var has_storage_limit: bool = options.has("storage_remaining")
	var storage_remaining: GFBigNumber = null

	if has_storage_limit:
		storage_remaining = _to_big_number(GFVariantData.get_option_value(options, "storage_remaining", 0))
		if storage_remaining.compare_to(zero_value) <= 0:
			storage_remaining = zero_value

	for segment_variant: Variant in segments:
		if remaining_seconds <= 0.0 or storage_capped:
			break

		if not (segment_variant is Dictionary):
			continue

		var segment: Dictionary = segment_variant
		var configured_duration: float = maxf(_get_option_progression_float(segment, "duration_seconds", 0.0), 0.0)
		if configured_duration <= 0.0:
			continue

		var run_seconds: float = minf(configured_duration, remaining_seconds)
		var segment_result: Dictionary = _settle_segment(
			base_rate,
			run_seconds,
			segment,
			storage_remaining
		)
		var segment_produced: GFBigNumber = _get_option_big_number(segment_result, "produced")
		total_produced = total_produced.add(segment_produced)
		consumed_seconds += _get_option_progression_float(segment_result, "consumed_seconds", 0.0)
		remaining_seconds -= run_seconds

		if has_storage_limit:
			storage_remaining = storage_remaining.subtract(segment_produced)
			if storage_remaining.compare_to(zero_value) <= 0:
				storage_remaining = zero_value

		if GFVariantData.get_option_bool(segment_result, "storage_capped"):
			storage_capped = true

	if remaining_seconds > 0.0 and not storage_capped:
		var default_result: Dictionary = _settle_segment(
			base_rate,
			remaining_seconds,
			{},
			storage_remaining
		)
		total_produced = total_produced.add(_get_option_big_number(default_result, "produced"))
		consumed_seconds += _get_option_progression_float(default_result, "consumed_seconds", 0.0)

		if GFVariantData.get_option_bool(default_result, "storage_capped"):
			storage_capped = true

	var expired_seconds: float = requested_seconds - settled_seconds
	var wasted_seconds: float = settled_seconds - consumed_seconds
	if expired_seconds < 0.0:
		expired_seconds = 0.0
	if wasted_seconds < 0.0:
		wasted_seconds = 0.0

	return {
		"produced": total_produced,
		"requested_seconds": requested_seconds,
		"settled_seconds": settled_seconds,
		"consumed_seconds": consumed_seconds,
		"expired_seconds": expired_seconds,
		"wasted_seconds": wasted_seconds,
		"storage_capped": storage_capped,
	}


# --- 私有/辅助方法 ---

static func _evaluate_single_curve(level: int, curve_config: Dictionary) -> GFBigNumber:
	var start_level: int = GFVariantData.get_option_int(curve_config, "start_level", 0)
	var anchor_value: GFBigNumber = _resolve_anchor_value(curve_config, curve_config, null)
	return _evaluate_phase(level, curve_config, anchor_value, start_level)


static func _evaluate_piecewise_curve(level: int, phases: Array, curve_config: Dictionary) -> GFBigNumber:
	var sorted_phases: Array[Dictionary] = _sort_phase_configs(phases)
	if sorted_phases.is_empty():
		return _evaluate_single_curve(level, curve_config)

	var current_index: int = 0
	for i: int in range(sorted_phases.size()):
		var phase_start: int = GFVariantData.get_option_int(sorted_phases[i], "start_level", 0)
		if phase_start <= level:
			current_index = i
		else:
			break

	var anchor_level: int = GFVariantData.get_option_int(sorted_phases[0], "start_level", 0)
	var anchor_value: GFBigNumber = _resolve_anchor_value(sorted_phases[0], curve_config, null)
	var current_phase: Dictionary = sorted_phases[0]

	for i: int in range(1, current_index + 1):
		var next_phase: Dictionary = sorted_phases[i]
		var next_start: int = GFVariantData.get_option_int(next_phase, "start_level", 0)
		var inherited_value: GFBigNumber = _evaluate_phase(next_start, current_phase, anchor_value, anchor_level)
		anchor_value = _resolve_anchor_value(next_phase, curve_config, inherited_value)
		anchor_level = next_start
		current_phase = next_phase

	return _evaluate_phase(level, current_phase, anchor_value, anchor_level)


static func _evaluate_phase(
	level: int,
	phase_config: Dictionary,
	anchor_value: GFBigNumber,
	anchor_level: int
) -> GFBigNumber:
	var delta_levels: int = maxi(level - anchor_level, 0)
	var curve_mode: CurveMode = _parse_curve_mode(GFVariantData.get_option_value(phase_config, "mode", CurveMode.CONSTANT))

	match curve_mode:
		CurveMode.CONSTANT:
			return anchor_value.clone()

		CurveMode.LINEAR:
			var per_level: GFBigNumber = _to_big_number(GFVariantData.get_option_value(phase_config, "per_level", 0))
			return anchor_value.add(per_level.multiply(_to_big_number(delta_levels)))

		CurveMode.EXPONENTIAL:
			var multiplier: float = _get_option_progression_float(phase_config, "multiplier", 1.0)
			if multiplier <= 0.0:
				push_error("[GFProgressionMath][progression_math.exponential_multiplier_invalid] The exponential curve multiplier must be greater than zero.")
				return anchor_value.clone()

			if delta_levels == 0:
				return anchor_value.clone()

			return anchor_value.multiply(_to_big_number(multiplier).powi(delta_levels))

	return anchor_value.clone()


static func _settle_segment(
	base_rate: GFBigNumber,
	duration_seconds: float,
	segment: Dictionary,
	storage_remaining: GFBigNumber
) -> Dictionary:
	var zero_value: GFBigNumber = _to_big_number(0)
	if duration_seconds <= 0.0:
		return {
			"produced": zero_value,
			"consumed_seconds": 0.0,
			"storage_capped": false,
		}

	var segment_rate: GFBigNumber = _resolve_segment_rate(base_rate, segment)
	if segment_rate.compare_to(zero_value) <= 0:
		return {
			"produced": zero_value,
			"consumed_seconds": duration_seconds,
			"storage_capped": false,
		}

	var produced: GFBigNumber = segment_rate.multiply(_to_big_number(duration_seconds))
	var consumed_seconds: float = duration_seconds
	var storage_capped: bool = false

	if storage_remaining != null and produced.compare_to(storage_remaining) > 0:
		produced = storage_remaining.clone()
		storage_capped = true
		consumed_seconds = storage_remaining.divide(segment_rate).to_float()
		consumed_seconds = clampf(consumed_seconds, 0.0, duration_seconds)

	return {
		"produced": produced,
		"consumed_seconds": consumed_seconds,
		"storage_capped": storage_capped,
	}


static func _resolve_segment_rate(base_rate: GFBigNumber, segment: Dictionary) -> GFBigNumber:
	var rate: GFBigNumber = base_rate.clone()
	if segment.has("rate_per_second"):
		rate = _to_big_number(GFVariantData.get_option_value(segment, "rate_per_second"))

	var multiplier: float = _get_option_progression_float(segment, "multiplier", 1.0)
	rate = rate.multiply(_to_big_number(multiplier))

	if segment.has("bonus_per_second"):
		rate = rate.add(_to_big_number(GFVariantData.get_option_value(segment, "bonus_per_second", 0)))

	return rate


static func _resolve_anchor_value(
	phase_config: Dictionary,
	curve_config: Dictionary,
	inherited_value: GFBigNumber
) -> GFBigNumber:
	if phase_config.has("base_value"):
		return _to_big_number(GFVariantData.get_option_value(phase_config, "base_value"))

	if inherited_value != null:
		return inherited_value

	if curve_config.has("base_value"):
		return _to_big_number(GFVariantData.get_option_value(curve_config, "base_value"))

	push_error("[GFProgressionMath][progression_math.base_value_missing] Curve configuration is missing base_value.")
	return _to_big_number(0)


static func _find_override_value(level: int, overrides: Variant) -> Variant:
	if not (overrides is Dictionary):
		return null

	var override_dict: Dictionary = overrides
	if override_dict.has(level):
		return override_dict[level]

	var level_key: String = str(level)
	if override_dict.has(level_key):
		return override_dict[level_key]

	return null


static func _sort_phase_configs(phases: Array) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = []

	for phase_variant: Variant in phases:
		if not (phase_variant is Dictionary):
			continue

		var phase: Dictionary = phase_variant
		var phase_start: int = GFVariantData.get_option_int(phase, "start_level", 0)
		var inserted: bool = false

		for i: int in range(sorted.size()):
			var current_start: int = GFVariantData.get_option_int(sorted[i], "start_level", 0)
			if phase_start < current_start:
				var _insert_result_406: Variant = sorted.insert(i, phase)
				inserted = true
				break

		if not inserted:
			sorted.append(phase)

	return sorted


static func _parse_curve_mode(mode_value: Variant) -> CurveMode:
	match typeof(mode_value):
		TYPE_INT:
			if mode_value == CurveMode.LINEAR:
				return CurveMode.LINEAR
			if mode_value == CurveMode.EXPONENTIAL:
				return CurveMode.EXPONENTIAL
			return CurveMode.CONSTANT

		TYPE_STRING, TYPE_STRING_NAME:
			var mode_text: String = GFVariantData.to_text(mode_value).to_lower()
			if mode_text == "linear":
				return CurveMode.LINEAR
			if mode_text == "exponential":
				return CurveMode.EXPONENTIAL
			return CurveMode.CONSTANT

	return CurveMode.CONSTANT


static func _to_big_number(value: Variant) -> GFBigNumber:
	return GFBigNumber.from_variant(value)


static func _get_option_big_number(options: Dictionary, key: Variant) -> GFBigNumber:
	return _to_big_number(GFVariantData.get_option_value(options, key, 0))


static func _get_option_progression_float(
	options: Dictionary,
	key: Variant,
	default_value: float = 0.0
) -> float:
	return _to_progression_float(GFVariantData.get_option_value(options, key, default_value), default_value)


static func _to_progression_float(value: Variant, default_value: float = 0.0) -> float:
	if value is Object:
		var object: Object = value
		if is_instance_valid(object) and object.has_method("to_float"):
			return GFVariantData.to_float(object.call("to_float"), default_value)

	return GFVariantData.to_float(value, default_value)
