## GFProjectileEmissionPolicy: 发射体发射请求策略。
##
## 用于在 GFProjectileEmitter2D / GFProjectileEmitter3D 生成节点前执行通用门控、数量裁剪和节奏控制。
## 该策略只处理发射请求本身，不解释弹药、阵营、伤害、特效或输入规则。
## [br]
## @api public
## [br]
## @category resource_definition
## [br]
## @since 8.0.0
class_name GFProjectileEmissionPolicy
extends Resource


# --- 常量 ---

const _GF_COMBAT_FINITE_MATH = preload("res://addons/gf/extensions/combat/core/gf_combat_finite_math.gd")


# --- 导出变量 ---

## 策略标识，便于调试或项目工具识别。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var policy_id: StringName = &""

## 是否启用策略。关闭时所有请求直接通过。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var enabled: bool = true

## 两次成功发射请求之间的最小间隔秒数。小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var cooldown_seconds: float = 0.0

## 每次请求最多允许生成的发射体数量。小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var max_projectiles_per_request: int = 0

## 最大成功发射请求次数。小于等于 0 表示不限制。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var max_emission_count: int = 0

## 通用 charge 容量。小于等于 0 表示不启用 charge 门控。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var charge_capacity: float = 0.0

## 每次成功请求消耗的 charge。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var charge_cost_per_request: float = 0.0

## 每个实际生成发射体额外消耗的 charge。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var charge_cost_per_projectile: float = 0.0

## 恢复 1 点 charge 需要的秒数。小于等于 0 表示不会自动恢复。
## [br]
## @api public
## [br]
## @since 8.0.0
@export var charge_recovery_seconds: float = 0.0


# --- 私有变量 ---

var _last_emission_msec: int = -1
var _last_charge_update_msec: int = -1
var _charges: float = -1.0
var _emission_count: int = 0


# --- 公共方法 ---

## 准备一次发射请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param emitter: 发射器节点。
## [br]
## @param projectile_id: 发射体目录 ID。
## [br]
## @param projectile_context: 调用方发射上下文。
## [br]
## @param requested_count: 本次请求准备生成的发射体数量。
## [br]
## @param now_msec: 可选当前毫秒时间；小于 0 时使用 Time.get_ticks_msec()。
## [br]
## @return 发射准备报告。
## [br]
## @schema projectile_context: Dictionary，本次发射上下文；策略会复制后返回，不修改调用方原始字典。
## [br]
## @schema return: Dictionary，包含 ok、reason、policy_id、projectile_id、requested_count、emit_count、projectile_context、now_msec、remaining_cooldown_seconds、available_charges 和 required_charges。
func prepare_emission(
	emitter: Node,
	projectile_id: StringName,
	projectile_context: Dictionary = {},
	requested_count: int = 1,
	now_msec: int = -1
) -> Dictionary:
	var effective_now_msec: int = _resolve_now_msec(now_msec)
	var context: Dictionary = projectile_context.duplicate(true)
	if not is_configuration_valid():
		return _make_prepare_report(false, &"non_finite_policy_configuration", projectile_id, requested_count, 0, context, effective_now_msec)
	if not enabled:
		return _make_prepare_report(true, &"", projectile_id, requested_count, requested_count, context, effective_now_msec)

	_recover_charges(effective_now_msec)
	var emit_count: int = maxi(requested_count, 0)
	if max_projectiles_per_request > 0:
		emit_count = mini(emit_count, max_projectiles_per_request)
	if emit_count <= 0:
		return _make_prepare_report(false, &"empty_emission", projectile_id, requested_count, emit_count, context, effective_now_msec)

	if max_emission_count > 0 and _emission_count >= max_emission_count:
		return _make_prepare_report(false, &"emission_count_exhausted", projectile_id, requested_count, emit_count, context, effective_now_msec)

	var cooldown_remaining: float = get_remaining_cooldown_seconds(effective_now_msec)
	if cooldown_remaining > 0.0:
		var cooldown_report: Dictionary = _make_prepare_report(false, &"cooldown", projectile_id, requested_count, emit_count, context, effective_now_msec)
		cooldown_report["remaining_cooldown_seconds"] = cooldown_remaining
		return cooldown_report

	var required_charges: float = get_required_charges(emit_count)
	var available_charges: float = get_available_charges(effective_now_msec)
	if required_charges > 0.0 and available_charges + 0.000001 < required_charges:
		var charge_report: Dictionary = _make_prepare_report(false, &"insufficient_charges", projectile_id, requested_count, emit_count, context, effective_now_msec)
		charge_report["available_charges"] = available_charges
		charge_report["required_charges"] = required_charges
		return charge_report

	var report: Dictionary = _make_prepare_report(true, &"", projectile_id, requested_count, emit_count, context, effective_now_msec)
	report["available_charges"] = available_charges
	report["required_charges"] = required_charges
	var hook_report: Dictionary = _prepare_emission(emitter, projectile_id, report)
	if not hook_report.is_empty():
		for key: Variant in hook_report.keys():
			report[key] = hook_report[key]
	return report


## 提交一次已生成的发射请求。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param emitter: 发射器节点。
## [br]
## @param prepare_report: prepare_emission() 返回的报告。
## [br]
## @param emitted_count: 实际成功生成的发射体数量。
## [br]
## @return 提交报告。
## [br]
## @schema prepare_report: Dictionary，prepare_emission() 返回的报告。
## [br]
## @schema return: Dictionary，包含 ok、committed、reason、emitted_count、emission_count、available_charges 和 consumed_charges。
func commit_emission(emitter: Node, prepare_report: Dictionary, emitted_count: int) -> Dictionary:
	var now_msec: int = GFVariantData.get_option_int(prepare_report, "now_msec", _resolve_now_msec(-1))
	if not is_configuration_valid():
		return _make_commit_report(false, false, &"non_finite_policy_configuration", emitted_count, 0.0, now_msec)
	if not enabled:
		return _make_commit_report(true, true, &"", emitted_count, 0.0, now_msec)
	if not GFVariantData.get_option_bool(prepare_report, "ok"):
		return _make_commit_report(false, false, &"prepare_report_not_ok", emitted_count, 0.0, now_msec)
	if emitted_count <= 0:
		return _make_commit_report(false, false, &"nothing_emitted", emitted_count, 0.0, now_msec)

	_recover_charges(now_msec)
	var consumed_charges: float = get_required_charges(emitted_count)
	if consumed_charges > 0.0:
		_charges = maxf(0.0, get_available_charges(now_msec) - consumed_charges)
		_last_charge_update_msec = now_msec
	_last_emission_msec = now_msec
	_emission_count += 1
	_commit_emission(emitter, prepare_report, emitted_count)
	return _make_commit_report(true, true, &"", emitted_count, consumed_charges, now_msec)


## 重置运行时策略状态。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param now_msec: 可选当前毫秒时间；小于 0 时使用 Time.get_ticks_msec()。
func reset(now_msec: int = -1) -> void:
	var effective_now_msec: int = _resolve_now_msec(now_msec)
	_last_emission_msec = -1
	_last_charge_update_msec = effective_now_msec
	_charges = _get_charge_capacity() if _uses_charges() else -1.0
	_emission_count = 0


## 获取当前可用 charge。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param now_msec: 可选当前毫秒时间；小于 0 时使用 Time.get_ticks_msec()。
## [br]
## @return 当前可用 charge；未启用 charge 门控时返回 0。
func get_available_charges(now_msec: int = -1) -> float:
	if not _uses_charges():
		return 0.0
	var effective_now_msec: int = _resolve_now_msec(now_msec)
	return _get_recovered_charges(effective_now_msec)


## 获取指定生成数量需要消耗的 charge。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param emit_count: 预计生成数量。
## [br]
## @return 需要消耗的 charge。
func get_required_charges(emit_count: int) -> float:
	if not _uses_charges():
		return 0.0
	var request_cost: float = _GF_COMBAT_FINITE_MATH.non_negative_or(charge_cost_per_request)
	var projectile_cost: float = _GF_COMBAT_FINITE_MATH.non_negative_or(charge_cost_per_projectile)
	var total_cost: float = request_cost + projectile_cost * maxf(float(emit_count), 0.0)
	return total_cost if _GF_COMBAT_FINITE_MATH.is_finite_float(total_cost) else INF


## 获取剩余冷却秒数。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param now_msec: 可选当前毫秒时间；小于 0 时使用 Time.get_ticks_msec()。
## [br]
## @return 剩余冷却秒数。
func get_remaining_cooldown_seconds(now_msec: int = -1) -> float:
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(cooldown_seconds) or cooldown_seconds <= 0.0 or _last_emission_msec < 0:
		return 0.0
	var effective_now_msec: int = _resolve_now_msec(now_msec)
	var elapsed_seconds: float = maxf(float(effective_now_msec - _last_emission_msec) / 1000.0, 0.0)
	return maxf(cooldown_seconds - elapsed_seconds, 0.0)


## 检查策略数值配置是否有限。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 所有浮点配置有限时返回 true。
func is_configuration_valid() -> bool:
	return (
		_GF_COMBAT_FINITE_MATH.is_finite_float(cooldown_seconds)
		and _GF_COMBAT_FINITE_MATH.is_finite_float(charge_capacity)
		and _GF_COMBAT_FINITE_MATH.is_finite_float(charge_cost_per_request)
		and _GF_COMBAT_FINITE_MATH.is_finite_float(charge_cost_per_projectile)
		and _GF_COMBAT_FINITE_MATH.is_finite_float(charge_recovery_seconds)
	)


## 获取策略调试快照。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param now_msec: 可选当前毫秒时间；小于 0 时使用 Time.get_ticks_msec()。
## [br]
## @return 策略状态快照。
## [br]
## @schema return: Dictionary，包含 policy_id、enabled、cooldown_seconds、remaining_cooldown_seconds、charge_capacity、available_charges、emission_count 和 max_emission_count。
func get_debug_snapshot(now_msec: int = -1) -> Dictionary:
	var effective_now_msec: int = _resolve_now_msec(now_msec)
	return {
		"policy_id": policy_id,
		"enabled": enabled,
		"cooldown_seconds": cooldown_seconds,
		"remaining_cooldown_seconds": get_remaining_cooldown_seconds(effective_now_msec),
		"max_projectiles_per_request": max_projectiles_per_request,
		"max_emission_count": max_emission_count,
		"emission_count": _emission_count,
		"charge_capacity": _get_charge_capacity(),
		"available_charges": get_available_charges(effective_now_msec),
		"charge_cost_per_request": charge_cost_per_request,
		"charge_cost_per_projectile": charge_cost_per_projectile,
		"charge_recovery_seconds": charge_recovery_seconds,
	}


# --- 可重写钩子 / 虚方法 ---

## 发射准备扩展点。
## [br]
## 返回的字段会合并到 prepare_emission() 报告。子类可修改 ok、reason、emit_count 或 projectile_context。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param _emitter: 发射器节点。
## [br]
## @param _projectile_id: 发射体目录 ID。
## [br]
## @param _prepare_report: 当前准备报告。
## [br]
## @return 需要合并到准备报告的字段。
## [br]
## @schema _prepare_report: Dictionary，当前准备报告。
## [br]
## @schema return: Dictionary，覆盖或附加到准备报告的字段。
func _prepare_emission(_emitter: Node, _projectile_id: StringName, _prepare_report: Dictionary) -> Dictionary:
	return {}


## 发射提交扩展点。
## [br]
## @api protected
## [br]
## @since 8.0.0
## [br]
## @param _emitter: 发射器节点。
## [br]
## @param _prepare_report: prepare_emission() 返回的报告。
## [br]
## @param _emitted_count: 实际成功生成的发射体数量。
## [br]
## @schema _prepare_report: Dictionary，prepare_emission() 返回的报告。
func _commit_emission(_emitter: Node, _prepare_report: Dictionary, _emitted_count: int) -> void:
	pass


# --- 私有/辅助方法 ---

func _make_prepare_report(
	ok: bool,
	reason: StringName,
	projectile_id: StringName,
	requested_count: int,
	emit_count: int,
	projectile_context: Dictionary,
	now_msec: int
) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"policy_id": policy_id,
		"projectile_id": projectile_id,
		"requested_count": requested_count,
		"emit_count": emit_count,
		"projectile_context": projectile_context,
		"now_msec": now_msec,
		"remaining_cooldown_seconds": get_remaining_cooldown_seconds(now_msec),
		"available_charges": get_available_charges(now_msec),
		"required_charges": get_required_charges(emit_count),
	}


func _make_commit_report(
	ok: bool,
	committed: bool,
	reason: StringName,
	emitted_count: int,
	consumed_charges: float,
	now_msec: int
) -> Dictionary:
	return {
		"ok": ok,
		"committed": committed,
		"reason": reason,
		"emitted_count": emitted_count,
		"emission_count": _emission_count,
		"available_charges": get_available_charges(now_msec),
		"consumed_charges": consumed_charges,
		"now_msec": now_msec,
	}


func _recover_charges(now_msec: int) -> void:
	if not _uses_charges():
		return
	_charges = _get_recovered_charges(now_msec)
	_last_charge_update_msec = now_msec


func _get_recovered_charges(now_msec: int) -> float:
	if not _uses_charges():
		return 0.0
	var capacity: float = _get_charge_capacity()
	var current_charges: float = capacity if _charges < 0.0 else clampf(_charges, 0.0, capacity)
	if charge_recovery_seconds <= 0.0 or _last_charge_update_msec < 0:
		return current_charges
	var elapsed_seconds: float = maxf(float(now_msec - _last_charge_update_msec) / 1000.0, 0.0)
	var recovered: float = elapsed_seconds / charge_recovery_seconds
	return clampf(current_charges + recovered, 0.0, capacity)


func _uses_charges() -> bool:
	return is_configuration_valid() and charge_capacity > 0.0 and (
		charge_cost_per_request > 0.0
		or charge_cost_per_projectile > 0.0
	)


func _get_charge_capacity() -> float:
	if not _GF_COMBAT_FINITE_MATH.is_finite_float(charge_capacity):
		return 0.0
	return maxf(charge_capacity, 0.0)


func _resolve_now_msec(now_msec: int) -> int:
	if now_msec >= 0:
		return now_msec
	return int(Time.get_ticks_msec())
