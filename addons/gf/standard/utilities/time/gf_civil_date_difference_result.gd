## GFCivilDateDifferenceResult: 两个公民日期的不可变关系结果。
##
## 成功时同时表达有符号日差与比较次序，失败时不使用 0 伪装相等。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFCivilDateDifferenceResult
extends RefCounted


# --- 常量 ---

## 日期关系已成功计算。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_OK: StringName = &"ok"

## 任一输入不是有效公民日期。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_INVALID_DATE: StringName = &"invalid_date"


# --- 私有变量 ---

var _configured: bool = false
var _status: StringName = STATUS_INVALID_DATE
var _days: int = 0
var _error: String = ""


# --- 公共方法 ---

## 检查日期关系是否成功计算。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功时返回 true。
func is_successful() -> bool:
	return _configured and _status == STATUS_OK


## 获取稳定结果状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 获取从左侧日期到右侧日期的有符号日数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功时的 `right - left` 日差；失败时返回 0，应先检查 [method is_successful]。
func get_days() -> int:
	return _days


## 获取左侧日期相对右侧日期的比较结果。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 左侧较早为 -1，相等为 0，较晚为 1；失败时返回 0。
func get_comparison() -> int:
	if not is_successful() or _days == 0:
		return 0
	return -1 if _days > 0 else 1


## 获取失败说明。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功时为空字符串。
func get_error() -> String:
	return _error


# --- 层内方法 ---

## 由时间工具层一次性配置日期关系。
## [br]
## @api layer_internal
## [br]
## @layer standard/utilities/time
## [br]
## @since unreleased
## [br]
## @param status: `STATUS_*` 常量之一。
## [br]
## @param days: 成功时的 `right - left` 日差。
## [br]
## @param error: 失败说明。
## [br]
## @return: 首次且状态合法时返回 true。
func configure_from_time_layer(
	status: StringName,
	days: int = 0,
	error: String = ""
) -> bool:
	if _configured or status not in [STATUS_OK, STATUS_INVALID_DATE]:
		return false
	if status != STATUS_OK and days != 0:
		return false
	_configured = true
	_status = status
	_days = days
	_error = "" if status == STATUS_OK else error.strip_edges()
	return true
