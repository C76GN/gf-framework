## GFProjectileEmissionReceipt: 已扣费但尚未发布的 emission 提交凭据。
## [br]
## @api framework_internal
## [br]
## @category runtime_handle
## [br]
## @since 11.0.0
class_name GFProjectileEmissionReceipt
extends RefCounted


# --- 枚举 ---

## 定义 deferred receipt 的封闭单向状态。
## [br]
## @api framework_internal
enum State {
	COMMITTED_UNPUBLISHED = 0,
	ACTIVATED = 1,
	PUBLISHED = 2,
	COMPENSATED = 3,
}


# --- 私有变量 ---

var _state: State = State.COMMITTED_UNPUBLISHED
var _policy: GFProjectileEmissionPolicy = null
var _emitter_ref: WeakRef = null
var _prepare_report: Dictionary = {}
var _emitted_count: int = 0
var _policy_snapshot: Dictionary = {}
var _committed_generation: int = -1
var _initialized: bool = false
var _settlement_in_progress: bool = false
var _publish_attempted: bool = false
var _compensation_attempted: bool = false


# --- 框架内部方法 ---

## 读取 receipt 状态。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return: 当前 receipt 状态。
func get_state_for_framework() -> State:
	return _state


## 标记所有 reservation 已成为 ACTIVE session。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return: 首次从 COMMITTED_UNPUBLISHED 进入 ACTIVATED 时为 OK。
func mark_activated_for_framework() -> Error:
	if (
		not _initialized
		or _settlement_in_progress
		or _compensation_attempted
		or _state != State.COMMITTED_UNPUBLISHED
	):
		return ERR_ALREADY_IN_USE
	_state = State.ACTIVATED
	return OK


## 发布延迟的用户 commit hook。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @return: 用户 commit hook 的闭合发布报告。
## [br]
## @schema return: 包含 ok、published 与 reason 的闭合报告。
func publish_for_framework() -> Dictionary:
	if (
		not _initialized
		or _settlement_in_progress
		or _publish_attempted
		or _state != State.ACTIVATED
	):
		return { "ok": false, "published": false, "reason": &"receipt_not_activated" }
	_publish_attempted = true
	_settlement_in_progress = true
	var report: Dictionary = { "ok": true, "published": true, "reason": &"" }
	if _policy != null and is_instance_valid(_policy):
		report = _policy.publish_deferred_for_framework(
			_node_from_ref(_emitter_ref),
			_prepare_report,
			_emitted_count,
			_committed_generation
		)
	elif _policy != null:
		report = { "ok": false, "published": false, "reason": &"policy_unavailable" }
	_settlement_in_progress = false
	if not GFVariantData.get_option_bool(report, "ok", false):
		return report
	_state = State.PUBLISHED
	return report


## 在任何 session ACTIVE 前精确补偿 charge/cooldown。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param _reason: 调用边界记录的稳定补偿原因。
## [br]
## @return: 闭合补偿报告。
## [br]
## @schema return: 包含 ok、compensated 与 reason 的闭合报告。
func compensate_for_framework(_reason: StringName) -> Dictionary:
	if (
		not _initialized
		or _settlement_in_progress
		or _compensation_attempted
		or _state != State.COMMITTED_UNPUBLISHED
	):
		return { "ok": false, "compensated": false, "reason": &"receipt_not_compensatable" }
	_compensation_attempted = true
	_settlement_in_progress = true
	var report: Dictionary = { "ok": true, "compensated": true, "reason": &"" }
	if _policy != null and is_instance_valid(_policy):
		report = _policy.compensate_deferred_for_framework(
			_policy_snapshot,
			_committed_generation
		)
	elif _policy != null:
		report = { "ok": false, "compensated": false, "reason": &"policy_unavailable" }
	_settlement_in_progress = false
	if not GFVariantData.get_option_bool(report, "ok", false):
		return report
	_state = State.COMPENSATED
	return report


## 初始化一次成功 deferred commit 的 receipt。
## [br]
## @api framework_internal
## [br]
## @since 11.0.0
## [br]
## @param policy: 可选 emission policy。
## [br]
## @param emitter: 发起提交的 emitter。
## [br]
## @param prepare_report: deferred commit 对应的准备报告。
## [br]
## @param emitted_count: 实际激活数量。
## [br]
## @param policy_snapshot: deferred commit 前由同一 policy 捕获的内部快照。
## [br]
## @param committed_generation: commit 后的策略 generation。
## [br]
## @return: 初始化结果。
## [br]
## @schema prepare_report: Dictionary，原任务签发且已通过 commit 校验的准备报告。
## [br]
## @schema policy_snapshot: Dictionary，仅供同一 policy 精确补偿的内部快照。
func initialize_for_framework(
	policy: GFProjectileEmissionPolicy,
	emitter: Node,
	prepare_report: Dictionary,
	emitted_count: int,
	policy_snapshot: Dictionary,
	committed_generation: int
) -> Error:
	if (
		_initialized
		or emitted_count <= 0
		or emitter == null
		or not is_instance_valid(emitter)
		or emitter.is_queued_for_deletion()
		or (policy != null and not is_instance_valid(policy))
	):
		return ERR_INVALID_PARAMETER
	_policy = policy
	_emitter_ref = weakref(emitter)
	_prepare_report = prepare_report.duplicate(true)
	_emitted_count = emitted_count
	_policy_snapshot = policy_snapshot.duplicate(true)
	_committed_generation = committed_generation
	_state = State.COMMITTED_UNPUBLISHED
	_initialized = true
	return OK


# --- 私有/辅助方法 ---

func _node_from_ref(weak_reference: WeakRef) -> Node:
	if weak_reference == null:
		return null
	var value: Variant = weak_reference.get_ref()
	if value is Node:
		var node: Node = value
		if node.is_queued_for_deletion():
			return null
		return node
	return null
