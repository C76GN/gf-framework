## GFSaveProfileRecoveryLease: 缺失或损坏 Profile 的一次性恢复授权。
##
## Lease 由失败的 activate 操作创建，并绑定创建时的事务、Profile、Provider
## domain generation 与 lifecycle epoch。bootstrap/adopt 必须原样提交同一 Lease；
## domain 或 epoch 前进后，旧 Lease 会失效，不能把陈旧恢复决定应用到新状态。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFSaveProfileRecoveryLease
extends RefCounted


# --- 常量 ---

## 激活目标没有持久化文档。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_MISSING: StringName = &"missing"

## 激活目标文档损坏或完整性无效。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_CORRUPT: StringName = &"corrupt"

## Lease 尚未被恢复操作消费。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_AVAILABLE: StringName = &"available"

## Lease 已被一个恢复操作消费。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_CLAIMED: StringName = &"claimed"

## Lease 的 domain generation 或 lifecycle epoch 已过期。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_STALE: StringName = &"stale"


# --- 私有变量 ---

var _configured: bool = false
var _lease_id: int = 0
var _transaction_id: int = 0
var _profile_id: StringName = &""
var _reason: StringName = &""
var _domain_id: int = 0
var _domain_generation: int = 0
var _epoch: int = 0
var _state: StringName = STATE_STALE


# --- 公共方法 ---

## 获取 Utility 生命周期内唯一的 Lease ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数 Lease ID；未配置时为 0。
func get_lease_id() -> int:
	return _lease_id


## 获取产生当前 Lease 的事务 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数事务 ID；未配置时为 0。
func get_transaction_id() -> int:
	return _transaction_id


## 获取待恢复 Profile ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Profile ID。
func get_profile_id() -> StringName:
	return _profile_id


## 获取恢复原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `REASON_MISSING` 或 `REASON_CORRUPT`。
func get_reason() -> StringName:
	return _reason


## 获取运行时 Provider domain ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Utility 生命周期内唯一的正整数 domain ID。
func get_domain_id() -> int:
	return _domain_id


## 获取 Lease 创建时的 domain generation。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数 domain generation。
func get_domain_generation() -> int:
	return _domain_generation


## 获取 Lease 创建时的 Utility lifecycle epoch。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数 lifecycle epoch。
func get_epoch() -> int:
	return _epoch


## 获取当前 Lease 状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return `STATE_*` 常量之一。
func get_state() -> StringName:
	return _state


## 检查 Lease 是否仍可由 bootstrap/adopt 消费。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 可用时返回 true。
func is_available() -> bool:
	return _configured and _state == STATE_AVAILABLE


## 检查 Lease 是否已经被消费。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已 claim 时返回 true。
func is_claimed() -> bool:
	return _state == STATE_CLAIMED


## 检查 Lease 是否已经过期。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已标记 stale 或从未有效配置时返回 true。
func is_stale() -> bool:
	return _state == STATE_STALE


# --- 框架内部方法 ---

## 由 Save Profile 事务协调器一次性绑定恢复授权。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param lease_id: Utility 生命周期内唯一的正整数 Lease ID。
## [br]
## @param transaction_id: 产生该 Lease 的正整数事务 ID。
## [br]
## @param profile_id: 待恢复 Profile ID。
## [br]
## @param reason: `REASON_MISSING` 或 `REASON_CORRUPT`。
## [br]
## @param domain_id: Utility 生命周期内唯一的正整数 Provider domain ID。
## [br]
## @param domain_generation: 创建时的正整数 domain generation。
## [br]
## @param epoch: 创建时的正整数 Utility lifecycle epoch。
## [br]
## @return 输入合法且首次配置时返回 true。
func configure_for_framework(
	lease_id: int,
	transaction_id: int,
	profile_id: StringName,
	reason: StringName,
	domain_id: int,
	domain_generation: int,
	epoch: int
) -> bool:
	if _configured:
		return false
	if (
		lease_id <= 0
		or transaction_id <= 0
		or profile_id == &""
		or reason not in [REASON_MISSING, REASON_CORRUPT]
		or domain_id <= 0
		or domain_generation <= 0
		or epoch <= 0
	):
		return false
	_configured = true
	_lease_id = lease_id
	_transaction_id = transaction_id
	_profile_id = profile_id
	_reason = reason
	_domain_id = domain_id
	_domain_generation = domain_generation
	_epoch = epoch
	_state = STATE_AVAILABLE
	return true


## 获取不含恢复 payload 的 Lease 身份快照。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return Lease 身份、绑定 generation/epoch 与当前状态。
## [br]
## @schema return: Payload-free Dictionary with lease_id, transaction_id, profile_id, reason, domain_id, domain_generation, epoch, state, and available.
func inspect_for_framework() -> Dictionary:
	return {
		"lease_id": _lease_id,
		"transaction_id": _transaction_id,
		"profile_id": _profile_id,
		"reason": _reason,
		"domain_id": _domain_id,
		"domain_generation": _domain_generation,
		"epoch": _epoch,
		"state": _state,
		"available": is_available(),
	}


## 在身份和版本围栏匹配时一次性消费 Lease。
##
## 任一绑定不匹配都把尚可用 Lease 标记为 stale，防止调用方修正参数后把已经
## 失效的恢复决定重放到新状态。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @param expected_profile_id: 当前恢复操作的目标 Profile ID。
## [br]
## @param expected_domain_id: 当前 Provider domain ID。
## [br]
## @param expected_domain_generation: 当前 domain generation。
## [br]
## @param expected_epoch: 当前 Utility lifecycle epoch。
## [br]
## @return 匹配时返回 Lease 身份记录并转为 claimed；否则返回空字典。
## [br]
## @schema return: Payload-free Dictionary with lease_id, transaction_id, profile_id, reason, domain_id, domain_generation, and epoch.
func claim_for_framework(
	expected_profile_id: StringName,
	expected_domain_id: int,
	expected_domain_generation: int,
	expected_epoch: int
) -> Dictionary:
	if not is_available():
		return {}
	if (
		expected_profile_id != _profile_id
		or expected_domain_id != _domain_id
		or expected_domain_generation != _domain_generation
		or expected_epoch != _epoch
	):
		_state = STATE_STALE
		return {}
	_state = STATE_CLAIMED
	return {
		"lease_id": _lease_id,
		"transaction_id": _transaction_id,
		"profile_id": _profile_id,
		"reason": _reason,
		"domain_id": _domain_id,
		"domain_generation": _domain_generation,
		"epoch": _epoch,
	}


## 显式使尚可用 Lease 过期。
## [br]
## @api framework_internal
## [br]
## @since unreleased
## [br]
## @return 本次确实从 available 转为 stale 时返回 true。
func mark_stale_for_framework() -> bool:
	if not is_available():
		return false
	_state = STATE_STALE
	return true
