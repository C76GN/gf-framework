@tool

# 根据已接纳的冻结计划换算整体节奏，只计算纯字段，不读取或改写来源/目标。
extends RefCounted


# --- 常量 ---

## 沿用预览准入的步骤预算，拒绝不能完整检查的计划。
## [br]
## @api private
const _MAX_STEPS: int = 128

## 沿用预览的有限循环预算，不为无限循环定义目标总时长。
## [br]
## @api private
const _MAX_LOOPS: int = 32

## 所有步骤时间与延迟的保守累计预算，不能用并行实际时长绕过。
## [br]
## @api private
const _MAX_SECONDS: float = 120.0


# --- 框架内部方法 ---

## 按已接纳计划的实际总时长计算新倍率；不修改计划、签名、配置或样机。
## 计划、倍率和 captured_signature 必须来自同一次准备；调用方另行证明资源/样机身份。
## 不重编译属性或曲线，承接已接纳计划的合法性；只重新检查时间与缩放后的保守预算。
## [br]
## @api framework_internal
## [br]
## @param plan: 当前已接纳且只读的预览计划，拒绝空、失败、零时长或超预算计划。
## [br]
## @param current_scale: 同次准备捕获的 duration_scale，必须是有限正数并与签名一致。
## [br]
## @param captured_signature: 同次准备的来源纯值签名，不含 Resource 或目标引用。
## [br]
## @schema captured_signature: Array，来自 gf_tween_authoring_snapshot.capture 的 9 个根字段及 1–128 个步骤签名，首项为 duration_scale。
## [br]
## @param current_signature: 调用前重新捕获的来源签名，须与 captured_signature 完全相等。
## [br]
## @schema current_signature: Array，结构同 captured_signature；来源变化返回失败，不用旧计划计算新来源。
## [br]
## @param target_seconds: 希望的完整实际总时长，包含延迟、串并行、循环与往返，必须有限且大于零。
## [br]
## @return: 固定四字段结果；失败的倍率和时长为 0，不产生可部分提交值。
## [br]
## @schema return: Dictionary，固定 ok: bool、error: String、duration_scale: float、total_seconds: float；成功 error 为空，total_seconds 等于 target_seconds。
static func calculate(
	plan: GFTweenPreviewPlan,
	current_scale: float,
	captured_signature: Array,
	current_signature: Array,
	target_seconds: float
) -> Dictionary:
	if captured_signature.size() < 10 or captured_signature.size() > 9 + _MAX_STEPS:
		return _reject("尚未捕获完整来源；请先准备有效预览。")
	if captured_signature != current_signature:
		return _reject("来源已变化；请先重新准备，再调整总时长。")
	if not is_finite(current_scale) or current_scale <= 0.0:
		return _reject("当前时长倍率必须是有限正数。")
	if _number(captured_signature[0]) != current_scale:
		return _reject("倍率与捕获来源不一致；请重新准备。")
	if (
		plan == null
		or not plan.error.is_empty()
		or plan.steps.is_empty()
		or plan.steps.size() > _MAX_STEPS
	):
		return _reject("当前计划无效；请先准备有效预览。")
	if plan.loop_count < 1 or plan.loop_count > _MAX_LOOPS:
		return _reject("只支持 1 至 32 次有限循环。")
	if not is_finite(plan.duration_seconds) or plan.duration_seconds <= 0.0:
		return _reject("当前总时长必须大于零；瞬时计划不能换算倍率。")
	if not is_finite(target_seconds) or target_seconds <= 0.0:
		return _reject("目标总时长必须是有限正数。")
	var ratio: float = target_seconds / plan.duration_seconds
	var next_scale: float = current_scale * ratio
	if (
		not is_finite(ratio)
		or ratio <= 0.0
		or not is_finite(next_scale)
		or next_scale <= 0.0
	):
		return _reject("换算后的倍率必须是有限正数。")
	var cumulative_seconds: float = 0.0
	for step: Dictionary in plan.steps:
		var duration: float = _number(step.get("duration"))
		var delay: float = _number(step.get("delay"))
		if (
			not is_finite(duration)
			or duration < 0.0
			or not is_finite(delay)
			or delay < 0.0
		):
			return _reject("计划的时长与延迟必须是有限非负数。")
		cumulative_seconds += duration + delay
		var budget_seconds: float = (cumulative_seconds * ratio * float(plan.loop_count) * (2.0 if plan.ping_pong else 1.0))
		if not is_finite(budget_seconds) or budget_seconds > _MAX_SECONDS:
			return _reject("调整后全部步骤时间与延迟的保守累计值乘循环和往返次数不能超过 120 秒。")
	return {
		"ok": true,
		"error": "",
		"duration_scale": next_scale,
		"total_seconds": target_seconds,
	}


# --- 私有/辅助方法 ---

## 统一拒绝结果，数值字段不携带可被误提交的候选倍率。
## [br]
## @api private
static func _reject(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"duration_scale": 0.0,
		"total_seconds": 0.0,
	}


## 只读取整数和浮点数；其他字段产生 NAN，由有限检查拒绝。
## [br]
## @api private
static func _number(value: Variant) -> float:
	if value is float:
		var number: float = value
		return number
	if value is int:
		var number: int = value
		return float(number)
	return NAN
