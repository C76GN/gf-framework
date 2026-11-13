## GFTimeWindow: 带周期身份的冻结左闭右开时间窗口。
##
## 使用 Unix 毫秒，不隐式读取系统时钟，不代表奖励已结算。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFTimeWindow
extends RefCounted


# --- 私有变量 ---

## 包含在窗口中的起点。
## [br]
## @api private
var _start_msec: int = 0

## 不包含在窗口中的终点。
## [br]
## @api private
var _end_msec: int = 0

## 项目可持久化的周期身份。
## [br]
## @api private
var _period_id: String = ""


# --- 公共方法 ---

## 创建有效窗口。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param start_msec: Unix 毫秒起点，范围 ±8×10^15。
## [br]
## @param end_msec: Unix 毫秒终点，同范围且严格大于起点。
## [br]
## @param period_id: 非空周期身份，最多2048字符。
## [br]
## @return 冻结窗口；无效时返回 null。
static func create(
	start_msec: int,
	end_msec: int,
	period_id: String
) -> GFTimeWindow:
	if (
		start_msec < -8000000000000000
		or end_msec > 8000000000000000
		or start_msec >= end_msec
	):
		return null
	if period_id.is_empty() or period_id.length() > 2048:
		return null
	var window: GFTimeWindow = GFTimeWindow.new()
	window._start_msec = start_msec
	window._end_msec = end_msec
	window._period_id = period_id
	return window


## 获取包含的起点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Unix 毫秒起点。
func get_start_msec() -> int:
	return _start_msec


## 获取排除的终点。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return Unix 毫秒终点。
func get_end_msec() -> int:
	return _end_msec


## 获取周期身份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 创建时冻结的身份；未经工厂创建时为空。
func get_period_id() -> String:
	return _period_id


## 判断一个时间戳是否位于窗口中。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param unix_msec: 待检查的 Unix 毫秒时间戳。
## [br]
## @return start <= unix_msec < end，未经工厂创建的对象始终返回 false。
func contains(unix_msec: int) -> bool:
	return (
		not _period_id.is_empty()
		and unix_msec >= _start_msec
		and unix_msec < _end_msec
	)


## 获取持久化或诊断记录。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 窗口副本。
## [br]
## @schema return: 封闭 Dictionary，start_msec:int、end_msec:int、period_id:String。
func to_record() -> Dictionary:
	return {
		"start_msec": _start_msec,
		"end_msec": _end_msec,
		"period_id": _period_id,
	}
