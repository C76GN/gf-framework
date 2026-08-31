## GFStorageFamilyResetAuthorization: 单个 Storage logical family 的一次性破坏性恢复授权。
##
## 授权只能由 GFStorageUtility 为当前实例、冻结 root 与 canonical logical identity 创建。
## reset 必须原样提交同一对象；跨 Utility、跨 root/file 或重复提交都会失败关闭。
## 授权冻结签发时的 family 观察；较新写入或修复会在签发、claim 或 worker 复核时使其 stale。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since 11.0.0
class_name GFStorageFamilyResetAuthorization
extends RefCounted


# --- 常量 ---

## 调用方已经确认目标读失败属于可破坏恢复的损坏状态。
## [br]
## @api public
## [br]
## @since 11.0.0
const REASON_CORRUPT: StringName = &"corrupt"

## 授权尚未被 reset 请求消费。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATE_AVAILABLE: StringName = &"available"

## 授权已经被一个 reset 请求消费。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATE_CLAIMED: StringName = &"claimed"

## 授权无效、绑定不匹配或已经过期。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATE_STALE: StringName = &"stale"


# --- 私有变量 ---

var _configured: bool = false
var _authorization_id: int = 0
var _utility_id: int = 0
var _logical_path: String = ""
var _file_key: String = ""
var _observation_token: String = ""
var _reason: StringName = &""
var _state: StringName = STATE_STALE


# --- 公共方法 ---

## 获取当前 Utility 生命周期内唯一的授权 ID。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 正整数授权 ID；未配置时为 0。
func get_authorization_id() -> int:
	return _authorization_id


## 获取授权绑定的 canonical logical identity。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return portable logical file path；未配置时为空字符串。
func get_logical_path() -> String:
	return _logical_path


## 获取调用方确认的破坏性恢复原因。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 当前只可能为 REASON_CORRUPT；未配置时为空 StringName。
func get_reason() -> StringName:
	return _reason


## 获取授权当前状态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return STATE_AVAILABLE、STATE_CLAIMED 或 STATE_STALE。
func get_state() -> StringName:
	return _state


## 检查授权是否仍可提交一次。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 本地句柄已配置且尚未消费时返回 true；实际提交仍会复核冻结的 family 观察。
func is_available() -> bool:
	return _configured and _state == STATE_AVAILABLE


## 检查授权是否已经被 reset 请求消费。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 已 claim 时返回 true。
func is_claimed() -> bool:
	return _state == STATE_CLAIMED


## 检查授权是否无效或已经过期。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return 未配置或已标记 stale 时返回 true。
func is_stale() -> bool:
	return _state == STATE_STALE


# --- 框架内部方法 ---

## 由 GFStorageUtility 一次性绑定授权身份。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param authorization_id: Utility 生命周期内唯一的正整数 ID。
## [br]
## @param utility_id: 创建授权的 GFStorageUtility 实例 ID。
## [br]
## @param logical_path: canonical logical identity。
## [br]
## @param file_key: 冻结 root 与 family identity 的私有绑定键。
## [br]
## @param observation_token: 触发授权的 corrupt read 所绑定的 family 观察快照。
## [br]
## @param reason: 调用方确认的破坏性恢复原因。
## [br]
## @return 首次合法配置成功时返回 true。
func configure_for_framework(
	authorization_id: int,
	utility_id: int,
	logical_path: String,
	file_key: String,
	observation_token: String,
	reason: StringName
) -> bool:
	if (
		_configured
		or authorization_id <= 0
		or utility_id == 0
		or not GFStorageFamilyStore.is_valid_logical_file_path_for_framework(logical_path)
		or file_key.is_empty()
		or observation_token.is_empty()
		or reason != REASON_CORRUPT
	):
		return false
	_configured = true
	_authorization_id = authorization_id
	_utility_id = utility_id
	_logical_path = logical_path
	_file_key = file_key
	_observation_token = observation_token
	_reason = reason
	_state = STATE_AVAILABLE
	return true


## 在 Utility、root 与 logical identity 全部匹配时一次性消费授权。
##
## 任一绑定不匹配都会把尚可用授权标记为 stale，防止修正参数后重放旧决定。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param expected_utility_id: 当前 GFStorageUtility 实例 ID。
## [br]
## @param expected_logical_path: 当前请求的 canonical logical identity。
## [br]
## @param expected_file_key: 当前冻结 root 与 family 的私有绑定键。
## [br]
## @param expected_observation_token: 当前 serialization boundary 内重新观察的 family 快照。
## [br]
## @return 精确匹配且首次消费时返回 true。
func claim_for_framework(
	expected_utility_id: int,
	expected_logical_path: String,
	expected_file_key: String,
	expected_observation_token: String
) -> bool:
	if not is_available():
		return false
	if (
		expected_utility_id != _utility_id
		or expected_logical_path != _logical_path
		or expected_file_key != _file_key
		or expected_observation_token != _observation_token
	):
		_state = STATE_STALE
		return false
	_state = STATE_CLAIMED
	return true


## 在不消费授权的情况下复核 Utility、identity 与 family 观察快照。
##
## 任一绑定不匹配都会把尚可用授权标记 stale，确保高层协调器可以在 reset
## admission 前拒绝已经被新写入修复的目标。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @param expected_utility_id: 当前 GFStorageUtility 实例 ID。
## [br]
## @param expected_logical_path: 当前请求的 canonical logical identity。
## [br]
## @param expected_file_key: 当前冻结 root 与 family 的私有绑定键。
## [br]
## @param expected_observation_token: 当前 serialization boundary 内的 family 快照。
## [br]
## @return 所有绑定仍精确匹配时返回 true；不匹配会使授权 stale。
func validate_for_framework(
	expected_utility_id: int,
	expected_logical_path: String,
	expected_file_key: String,
	expected_observation_token: String
) -> bool:
	if not is_available():
		return false
	if (
		expected_utility_id != _utility_id
		or expected_logical_path != _logical_path
		or expected_file_key != _file_key
		or expected_observation_token != _observation_token
	):
		_state = STATE_STALE
		return false
	return true


## 获取 worker 二次复核所需的 opaque family 观察快照。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @return 已配置授权冻结的 opaque family 观察快照；未配置时为空字符串。
func get_observation_token_for_framework() -> String:
	return _observation_token if _configured else ""


## 显式使尚可用授权过期。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since 11.0.0
## [br]
## @return 本次确实从 available 转为 stale 时返回 true。
func mark_stale_for_framework() -> bool:
	if not is_available():
		return false
	_state = STATE_STALE
	return true
