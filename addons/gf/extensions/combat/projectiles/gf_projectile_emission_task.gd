## GFProjectileEmissionTask: 单次发射请求事务。
##
## 在任何生成点或节点分配前统一执行策略门控、硬预算和时间快照，随后只允许
## 提交一次实际生成数量。任务不解释 2D/3D 变换、伤害、弹药或对象池规则。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 8.0.0
class_name GFProjectileEmissionTask
extends RefCounted


# --- 常量 ---

## 等待准备。
## [br]
## @api public
## [br]
## @since 8.0.0
const STATE_PENDING: StringName = &"pending"

## 已通过门控，可进入生成阶段。
## [br]
## @api public
## [br]
## @since 8.0.0
const STATE_PREPARED: StringName = &"prepared"

## 已提交策略状态。
## [br]
## @api public
## [br]
## @since 8.0.0
const STATE_COMMITTED: StringName = &"committed"

## 生成失败或调用方取消后已回滚。
## [br]
## @api public
## [br]
## @since 8.0.0
const STATE_ROLLED_BACK: StringName = &"rolled_back"

## 门控或提交失败。
## [br]
## @api public
## [br]
## @since 8.0.0
const STATE_FAILED: StringName = &"failed"


# --- 公共变量 ---

## 当前任务状态。
## [br]
## @api public
## [br]
## @since 8.0.0
var state: StringName = STATE_PENDING


# --- 私有变量 ---

var _emitter: Node = null
var _policy: GFProjectileEmissionPolicy = null
var _projectile_id: StringName = &""
var _projectile_context: Dictionary = {}
var _requested_count: int = 0
var _hard_limit: int = 1
var _now_msec: int = 0
var _allowed_count: int = 0
var _prepare_report: Dictionary = {}


# --- 公共方法 ---

## 配置新任务。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param emitter: 发射器节点。
## [br]
## @param policy: 可选发射策略。
## [br]
## @param projectile_id: 发射体目录 ID。
## [br]
## @param projectile_context: 调用方上下文。
## [br]
## @param requested_count: 模式解析后的请求数量。
## [br]
## @param hard_limit: 分配前不可绕过的硬上限。
## [br]
## @param now_msec: 本次事务统一使用的单调时钟毫秒值。
## [br]
## @return 当前任务。
## [br]
## @schema projectile_context: Dictionary，任务会深复制，不修改调用方字典。
func configure(
	emitter: Node,
	policy: GFProjectileEmissionPolicy,
	projectile_id: StringName,
	projectile_context: Dictionary,
	requested_count: int,
	hard_limit: int,
	now_msec: int
) -> GFProjectileEmissionTask:
	_emitter = emitter
	_policy = policy
	_projectile_id = projectile_id
	_projectile_context = projectile_context.duplicate(true)
	_requested_count = maxi(requested_count, 0)
	_hard_limit = maxi(hard_limit, 1)
	_now_msec = maxi(now_msec, 0)
	return self


## 执行分配前门控。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 准备报告。
## [br]
## @schema return: Dictionary，包含 ok、reason、state、requested_count、emit_count、hard_limit、now_msec 和 projectile_context。
func prepare() -> Dictionary:
	if state != STATE_PENDING:
		return _make_state_failure(&"emission_task_not_pending")
	if _requested_count <= 0:
		state = STATE_FAILED
		return _make_state_failure(&"empty_emission")

	if _policy != null:
		_prepare_report = _policy.prepare_emission(
			_emitter,
			_projectile_id,
			_projectile_context,
			_requested_count,
			_now_msec
		)
	else:
		_prepare_report = {
			"ok": true,
			"reason": &"",
			"projectile_id": _projectile_id,
			"requested_count": _requested_count,
			"emit_count": _requested_count,
			"projectile_context": _projectile_context.duplicate(true),
			"now_msec": _now_msec,
		}
	if not GFVariantData.get_option_bool(_prepare_report, "ok", false):
		state = STATE_FAILED
		return _decorate_report(_prepare_report)

	var policy_count: int = GFVariantData.get_option_int(
		_prepare_report,
		"emit_count",
		_requested_count
	)
	_allowed_count = mini(maxi(policy_count, 0), mini(_requested_count, _hard_limit))
	if _allowed_count <= 0:
		state = STATE_FAILED
		_prepare_report["ok"] = false
		_prepare_report["reason"] = &"empty_emission"
		return _decorate_report(_prepare_report)

	state = STATE_PREPARED
	_prepare_report["emit_count"] = _allowed_count
	return _decorate_report(_prepare_report)


## 提交实际生成数量。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param emitted_count: 实际成功创建的节点数量。
## [br]
## @return 提交报告。
## [br]
## @schema return: Dictionary，包含 ok、committed、state、emitted_count、emit_count、hard_limit 和 now_msec。
func commit(emitted_count: int) -> Dictionary:
	if state != STATE_PREPARED:
		return _make_state_failure(&"emission_task_not_prepared")
	if emitted_count <= 0 or emitted_count > _allowed_count:
		state = STATE_FAILED
		return _make_state_failure(&"invalid_emitted_count")

	var report: Dictionary = {}
	if _policy != null:
		report = _policy.commit_emission(_emitter, _prepare_report, emitted_count)
	else:
		report = {
			"ok": true,
			"committed": true,
			"reason": &"",
			"emitted_count": emitted_count,
			"available_charges": 0.0,
			"consumed_charges": 0.0,
		}
	if not GFVariantData.get_option_bool(report, "ok", false):
		state = STATE_FAILED
		return _decorate_report(report)
	state = STATE_COMMITTED
	return _decorate_report(report)


## 回滚尚未提交的任务。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param reason: 回滚原因。
## [br]
## @return 回滚报告。
## [br]
## @schema return: Dictionary，包含 ok、rolled_back、reason、state、emit_count、hard_limit 和 now_msec。
func rollback(reason: StringName = &"emission_rolled_back") -> Dictionary:
	if state == STATE_COMMITTED:
		return _make_state_failure(&"committed_emission_cannot_rollback")
	state = STATE_ROLLED_BACK
	return _decorate_report({
		"ok": true,
		"rolled_back": true,
		"reason": reason,
	})


## 获取策略允许的生成数量。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 准备成功后返回允许数量，否则返回 0。
func get_allowed_count() -> int:
	return _allowed_count if state == STATE_PREPARED else 0


## 获取准备阶段合并后的发射上下文。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @return 发射上下文副本。
## [br]
## @schema return: Dictionary，策略返回的 projectile_context 深副本。
func get_projectile_context() -> Dictionary:
	return GFVariantData.get_option_dictionary(
		_prepare_report,
		"projectile_context",
		_projectile_context
	).duplicate(true)


# --- 私有/辅助方法 ---

func _decorate_report(report: Dictionary) -> Dictionary:
	var decorated: Dictionary = report.duplicate(true)
	decorated["state"] = state
	decorated["requested_count"] = _requested_count
	decorated["emit_count"] = _allowed_count
	decorated["hard_limit"] = _hard_limit
	decorated["now_msec"] = _now_msec
	return decorated


func _make_state_failure(reason: StringName) -> Dictionary:
	return _decorate_report({
		"ok": false,
		"committed": false,
		"reason": reason,
	})
