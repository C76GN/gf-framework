## GFCivilDateResult: 公民日期创建或运算的不可变结果。
##
## 成功与失败都使用稳定状态表达，避免用零值日期、隐式钳制或 null 猜测失败原因。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 11.0.0
class_name GFCivilDateResult
extends RefCounted


# --- 常量 ---

## 日期已成功创建或计算。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_OK: StringName = &"ok"

## 年份或运算结果超出支持范围。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_OUT_OF_RANGE: StringName = &"out_of_range"

## 年、月、日组合不是有效公民日期。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_INVALID_DATE: StringName = &"invalid_date"

## 日期文本或字典不符合声明的稳定格式。
## [br]
## @api public
## [br]
## @since 11.0.0
const STATUS_INVALID_FORMAT: StringName = &"invalid_format"


# --- 私有变量 ---

var _configured: bool = false
var _status: StringName = STATUS_INVALID_DATE
var _date: GFCivilDate = null
var _error: String = ""


# --- 公共方法 ---

## 检查操作是否成功。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 包含有效日期时返回 true。
func is_successful() -> bool:
	return _configured and _status == STATUS_OK and _date != null


## 获取稳定结果状态。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 获取成功日期。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 成功时返回不可变日期；失败时返回 null。
func get_date() -> GFCivilDate:
	return _date


## 获取稳定失败说明。
## [br]
## @api public
## [br]
## @since 11.0.0
## [br]
## @return: 成功时为空字符串。
func get_error() -> String:
	return _error


# --- 层内方法 ---

## 由时间工具层一次性配置结果。
## [br]
## @api layer_internal
## [br]
## @layer standard/utilities/time
## [br]
## @since 11.0.0
## [br]
## @param status: `STATUS_*` 常量之一。
## [br]
## @param date: 成功时的有效日期。
## [br]
## @param error: 失败说明。
## [br]
## @return: 首次且状态组合合法时返回 true。
func configure_from_time_layer(
	status: StringName,
	date: GFCivilDate = null,
	error: String = ""
) -> bool:
	if _configured or not _is_valid_configuration(status, date):
		return false
	_configured = true
	_status = status
	_date = date
	_error = "" if status == STATUS_OK else error.strip_edges()
	return true


# --- 私有/辅助方法 ---

func _is_valid_configuration(status: StringName, date: GFCivilDate) -> bool:
	if status == STATUS_OK:
		return date != null and date.is_valid()
	return date == null and status in [
		STATUS_OUT_OF_RANGE,
		STATUS_INVALID_DATE,
		STATUS_INVALID_FORMAT,
	]
