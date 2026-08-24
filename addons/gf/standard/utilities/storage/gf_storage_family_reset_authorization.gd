## GFStorageFamilyResetAuthorization: 单个 Storage logical family 的一次性破坏性恢复授权。
##
## 授权只能由 GFStorageUtility 为当前实例、冻结 root 与 canonical logical identity 创建。
## reset 必须原样提交同一对象；跨 Utility、跨 root/file 或重复提交都会失败关闭。
## [br]
## @api public
## [br]
## @category runtime_handle
## [br]
## @since unreleased
class_name GFStorageFamilyResetAuthorization
extends RefCounted


# --- 常量 ---

## 调用方已经确认目标读失败属于可破坏恢复的损坏状态。
## [br]
## @api public
## [br]
## @since unreleased
const REASON_CORRUPT: StringName = &"corrupt"

## 授权尚未被 reset 请求消费。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_AVAILABLE: StringName = &"available"

## 授权已经被一个 reset 请求消费。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_CLAIMED: StringName = &"claimed"

## 授权无效、绑定不匹配或已经过期。
## [br]
## @api public
## [br]
## @since unreleased
const STATE_STALE: StringName = &"stale"


# --- 私有变量 ---

var _configured: bool = false
var _authorization_id: int = 0
var _utility_id: int = 0
var _logical_path: String = ""
var _file_key: String = ""
var _reason: StringName = &""
var _state: StringName = STATE_STALE


# --- 公共方法 ---

## 获取当前 Utility 生命周期内唯一的授权 ID。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 正整数授权 ID；未配置时为 0。
func get_authorization_id() -> int:
	return _authorization_id


## 获取授权绑定的 canonical logical identity。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return portable logical file path；未配置时为空字符串。
func get_logical_path() -> String:
	return _logical_path


## 获取调用方确认的破坏性恢复原因。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 当前只可能为 REASON_CORRUPT；未配置时为空 StringName。
func get_reason() -> StringName:
	return _reason


## 获取授权当前状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return STATE_AVAILABLE、STATE_CLAIMED 或 STATE_STALE。
func get_state() -> StringName:
	return _state


## 检查授权是否仍可提交一次。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已配置且尚未消费时返回 true。
func is_available() -> bool:
	return _configured and _state == STATE_AVAILABLE


## 检查授权是否已经被 reset 请求消费。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 已 claim 时返回 true。
func is_claimed() -> bool:
	return _state == STATE_CLAIMED


## 检查授权是否无效或已经过期。
## [br]
## @api public
## [br]
## @since unreleased
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
## @since unreleased
## [br]
## @param authorization_id: Utility 生命周期内唯一的正整数 ID。
## [br]
## @param utility_id: 创建授权的 GFStorageUtility 实例 ID。
## [br]
## @param logical_path: canonical logical identity。
## [br]
## @param file_key: 冻结 root 与 family identity 的私有绑定键。
## [br]
## @param reason: 调用方确认的破坏性恢复原因。
## [br]
## @return 首次合法配置成功时返回 true。
func configure_for_framework(
	authorization_id: int,
	utility_id: int,
	logical_path: String,
	file_key: String,
	reason: StringName
) -> bool:
	if (
		_configured
		or authorization_id <= 0
		or utility_id == 0
		or not GFStorageFamilyStore.is_valid_logical_file_path_for_framework(logical_path)
		or file_key.is_empty()
		or reason != REASON_CORRUPT
	):
		return false
	_configured = true
	_authorization_id = authorization_id
	_utility_id = utility_id
	_logical_path = logical_path
	_file_key = file_key
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
## @since unreleased
## [br]
## @param expected_utility_id: 当前 GFStorageUtility 实例 ID。
## [br]
## @param expected_logical_path: 当前请求的 canonical logical identity。
## [br]
## @param expected_file_key: 当前冻结 root 与 family 的私有绑定键。
## [br]
## @return 精确匹配且首次消费时返回 true。
func claim_for_framework(
	expected_utility_id: int,
	expected_logical_path: String,
	expected_file_key: String
) -> bool:
	if not is_available():
		return false
	if (
		expected_utility_id != _utility_id
		or expected_logical_path != _logical_path
		or expected_file_key != _file_key
	):
		_state = STATE_STALE
		return false
	_state = STATE_CLAIMED
	return true


## 显式使尚可用授权过期。
## [br]
## @api framework_internal
## [br]
## @layer standard/utilities/storage
## [br]
## @since unreleased
## [br]
## @return 本次确实从 available 转为 stale 时返回 true。
func mark_stale_for_framework() -> bool:
	if not is_available():
		return false
	_state = STATE_STALE
	return true
