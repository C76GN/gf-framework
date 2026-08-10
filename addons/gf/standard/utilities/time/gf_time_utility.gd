## GFTimeUtility: 全局时间控制工具。
##
## 继承自 GFUtility，提供全局时间缩放、暂停和组级暂停控制能力。
## 架构在 tick / physics_tick 中自动从本工具获取缩放后的 delta，
## 无需 System 自行处理暂停逻辑。
##
## 用法：
##   1. 在架构的 _on_init() 中注册本工具。
##   2. 设置 time_scale 可全局加减速（如子弹时间设为 0.3）。
##   3. 设置 is_paused = true 暂停所有受控 System。
##   4. 使用 set_group_paused() 实现 UI 层/逻辑层分组暂停。
##   5. System 可设置 ignore_pause = true 来忽略暂停（如暂停菜单动画）。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 3.17.0
class_name GFTimeUtility
extends GFTimeProvider


# --- 公共变量 ---

## 全局时间缩放系数。1.0 为正常速度，0.5 为半速，2.0 为双倍速。
## 不得为负值，设置负值将被钳制为 0.0；非有限值会被拒绝并保留上一有效值。
## [br]
## @api public
## [br]
## @since 11.0.0
var time_scale: float = 1.0:
	set(value):
		if not _is_finite_scalar(value):
			_report_non_finite_once(
				&"time_scale",
				"[GFTimeUtility] 忽略非有限 time_scale；保留上一有效值。"
			)
			return
		time_scale = maxf(value, 0.0)

## 单次缩放后 delta 的最大值。小于等于 0 时不限制。
## 可用于避免极端 time_scale 或掉帧后向普通 tick 传入过大步长。
## 非有限值会被拒绝并保留上一有效值。
## [br]
## @api public
## [br]
## @since 11.0.0
var max_scaled_delta: float = 0.0:
	set(value):
		if not _is_finite_scalar(value):
			_report_non_finite_once(
				&"max_scaled_delta",
				"[GFTimeUtility] 忽略非有限 max_scaled_delta；保留上一有效值。"
			)
			return
		max_scaled_delta = maxf(value, 0.0)

## physics_tick 子步进的最大缩放步长。小于等于 0 时不启用子步进。
## 非有限值会被拒绝并保留上一有效值。
## [br]
## @api public
## [br]
## @since 11.0.0
var physics_substep_max_delta: float = 0.0:
	set(value):
		if not _is_finite_scalar(value):
			_report_non_finite_once(
				&"physics_substep_max_delta",
				"[GFTimeUtility] 忽略非有限 physics_substep_max_delta；保留上一有效值。"
			)
			return
		physics_substep_max_delta = maxf(value, 0.0)

## 单个物理帧最多拆分出的子步数。
## [br]
## @api public
var max_physics_substeps: int = 8:
	set(value):
		max_physics_substeps = maxi(value, 1)

## 全局暂停标志。为 true 时，所有未标记 ignore_pause 的 System 接收 delta = 0.0。
## [br]
## @api public
var is_paused: bool = false


# --- 私有变量 ---

# 组级暂停状态。Key 为 StringName 组标识，Value 为 bool 暂停状态。
var _group_paused: Dictionary = {}
var _reported_non_finite_issues: Dictionary = {}


# --- GF 生命周期方法 ---

## 第一阶段初始化：重置时间状态。
## [br]
## @api public
func init() -> void:
	_reported_non_finite_issues.clear()
	time_scale = 1.0
	max_scaled_delta = 0.0
	physics_substep_max_delta = 0.0
	max_physics_substeps = 8
	is_paused = false
	_group_paused.clear()


# --- 公共方法 ---

## 获取经过全局缩放的 delta 值。暂停时返回 0.0。
## [br]
## @api public
## [br]
## @param delta: 引擎原始帧间隔时间。
## [br]
## @return 缩放后的 delta。
func get_scaled_delta(delta: float) -> float:
	if not _validate_delta(delta):
		return 0.0
	if is_paused:
		return 0.0
	return _clamp_scaled_delta(_scale_delta_or_zero(delta))


## 获取 physics_tick 使用的缩放 delta 子步数组。
## 未启用子步进或无需拆分时返回单元素数组。
## [br]
## @api public
## [br]
## @param delta: 引擎原始物理帧间隔时间。
## [br]
## @return 缩放后的 delta 子步数组。
func get_physics_scaled_delta_steps(delta: float) -> Array[float]:
	if not _validate_delta(delta):
		return [0.0]
	if is_paused:
		return [0.0]

	var scaled_delta: float = _scale_delta_or_zero(delta)
	if physics_substep_max_delta <= 0.0 or is_zero_approx(scaled_delta):
		return [_clamp_scaled_delta(scaled_delta)]

	var required_steps: float = absf(scaled_delta) / physics_substep_max_delta
	var step_count: int = max_physics_substeps
	if _is_finite_scalar(required_steps):
		step_count = clampi(ceili(required_steps), 1, max_physics_substeps)
	var step_delta: float = scaled_delta / float(step_count)
	var result: Array[float] = []
	for _i: int in range(step_count):
		result.append(step_delta)
	return result


## 判断当前物理帧是否会被拆分为多个子步。
## [br]
## @api public
## [br]
## @param delta: 引擎原始物理帧间隔时间。
## [br]
## @return 会拆分时返回 true。
func should_substep_physics(delta: float) -> bool:
	if not _validate_delta(delta):
		return false
	if is_paused or physics_substep_max_delta <= 0.0:
		return false
	return absf(_scale_delta_or_zero(delta)) > physics_substep_max_delta


## 检查当前工具是否处于全局暂停状态。
## [br]
## @api public
## [br]
## @return 暂停时返回 true。
func is_time_paused() -> bool:
	return is_paused


## 设置指定组的暂停状态。
## [br]
## @api public
## [br]
## @param group: 组标识符。
## [br]
## @param paused: 是否暂停。
func set_group_paused(group: StringName, paused: bool) -> void:
	_group_paused[group] = paused


## 查询指定组是否处于暂停状态。
## [br]
## @api public
## [br]
## @param group: 组标识符。
## [br]
## @return 该组是否暂停，未注册的组返回 false。
func is_group_paused(group: StringName) -> bool:
	return GFVariantData.get_option_bool(_group_paused, group, false)


## 获取指定组经过缩放的 delta 值。
## 若全局暂停或该组暂停，返回 0.0。
## [br]
## @api public
## [br]
## @param group: 组标识符。
## [br]
## @param delta: 引擎原始帧间隔时间。
## [br]
## @return 缩放后的 delta。
func get_group_scaled_delta(group: StringName, delta: float) -> float:
	if not _validate_delta(delta):
		return 0.0
	if is_paused or is_group_paused(group):
		return 0.0
	return _clamp_scaled_delta(_scale_delta_or_zero(delta))


## 移除指定组的暂停记录。
## [br]
## @api public
## [br]
## @param group: 组标识符。
func remove_group(group: StringName) -> void:
	var _erase_result_187: Variant = _group_paused.erase(group)


## 清除所有组级暂停记录。
## [br]
## @api public
func clear_groups() -> void:
	_group_paused.clear()


# --- 私有/辅助方法 ---

func _validate_delta(delta: float) -> bool:
	if _is_finite_scalar(delta):
		return true
	_report_non_finite_once(
		&"delta",
		"[GFTimeUtility] delta 必须为有限数；本次返回安全零值。"
	)
	return false


func _scale_delta_or_zero(delta: float) -> float:
	var scaled_delta: float = delta * time_scale
	if _is_finite_scalar(scaled_delta):
		return scaled_delta
	_report_non_finite_once(
		&"scaled_delta",
		"[GFTimeUtility] scaled_delta 溢出为非有限数；本次返回安全零值。"
	)
	return 0.0


func _report_non_finite_once(issue_key: StringName, message: String) -> void:
	if _reported_non_finite_issues.has(issue_key):
		return
	_reported_non_finite_issues[issue_key] = true
	push_error(message)


func _is_finite_scalar(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


func _clamp_scaled_delta(delta: float) -> float:
	if max_scaled_delta <= 0.0:
		return delta
	return clampf(delta, -max_scaled_delta, max_scaled_delta)
