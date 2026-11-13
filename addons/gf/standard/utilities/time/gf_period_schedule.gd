## GFPeriodSchedule: UTC 或固定偏移下的冻结周期政策。
##
## 只计算 daily、weekly 或 fixed 窗口，不处理地区时区、DST、闰秒、奖励或补签。
## 周期身份包含计划身份、版本、实际政策和窗口起点；改变政策不会复用旧身份。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFPeriodSchedule
extends RefCounted


# --- 私有变量 ---

## 经过验证的实际周期政策。
## [br]
## @api private
var _record: Dictionary = {}

## 第一个参考边界的 Unix 毫秒时间戳。
## [br]
## @api private
var _anchor_msec: int = 0

## 固定周期长度。
## [br]
## @api private
var _interval_msec: int = 0

## 冻结政策的无歧义身份文本。
## [br]
## @api private
var _identity_prefix: String = ""


# --- 公共方法 ---

## 创建有版本的周期计划。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param schedule_id: 非空计划身份，最多256字符，无首尾空白和控制字符。
## [br]
## @param version: 正整数政策版本，应随项目结算政策变更递增。
## [br]
## @param options: 显式周期政策。
## [br]
## @schema options: 封闭 Dictionary。period:String=daily|weekly|fixed（默认daily）。daily/weekly 可含 offset_minutes:int[-840,840]（默认0）、reset_second:int[0,86399]（默认0）；weekly 可含 weekday:int[0,6]（周日0，默认周一1）。fixed 必须含 anchor_msec:int（±4×10^15）、interval_msec:int[1,4×10^15]，不接受日历字段。daily 不接受 weekday。
## [br]
## @return 冻结计划；非法或不适用字段返回 null。
static func create(
	schedule_id: StringName,
	version: int,
	options: Dictionary = {}
) -> GFPeriodSchedule:
	var identity: String = String(schedule_id)
	if (
		identity.is_empty()
		or identity.length() > 256
		or identity != identity.strip_edges()
		or version < 1
	):
		return null
	for index: int in range(identity.length()):
		if identity.unicode_at(index) < 32:
			return null
	var period_value: Variant = options.get("period", "daily")
	if not period_value is String or period_value not in [
		"daily",
		"weekly",
		"fixed",
	]:
		return null
	var period: String = period_value
	var allowed: Array[String] = [
		"period",
		"offset_minutes",
		"reset_second",
	]
	if period == "weekly":
		allowed.append("weekday")
	elif period == "fixed":
		allowed = [
			"period",
			"anchor_msec",
			"interval_msec",
		]
	for key: Variant in options:
		if (
			not key is String
			or key not in allowed
			or (
				key != "period"
				and not options[key] is int
			)
		):
			return null
	var anchor: int = 0
	var interval: int = 86400000
	var offset: int = 0
	var reset_second: int = 0
	var weekday: int = 0
	if period == "fixed":
		if not options.has("anchor_msec") or not options.has("interval_msec"):
			return null
		anchor = GFVariantData.get_option_int(options, "anchor_msec")
		interval = GFVariantData.get_option_int(options, "interval_msec")
		if (
			anchor < -4000000000000000
			or anchor > 4000000000000000
			or interval < 1
			or interval > 4000000000000000
		):
			return null
	else:
		offset = GFVariantData.get_option_int(options, "offset_minutes")
		reset_second = GFVariantData.get_option_int(options, "reset_second")
		if (
			offset < -840
			or offset > 840
			or reset_second < 0
			or reset_second >= 86400
		):
			return null
		anchor = reset_second * 1000 - offset * 60000
		if period == "weekly":
			weekday = GFVariantData.get_option_int(
				options,
				"weekday",
				1
			)
			if weekday < 0 or weekday > 6:
				return null
			anchor += ((weekday - 4 + 7) % 7) * 86400000
			interval = 604800000
	var schedule: GFPeriodSchedule = GFPeriodSchedule.new()
	schedule._anchor_msec = anchor
	schedule._interval_msec = interval
	schedule._record = {
		"schedule_id": identity,
		"version": version,
		"period": period,
		"anchor_msec": anchor,
		"interval_msec": interval,
		"offset_minutes": offset,
		"reset_second": reset_second,
		"weekday": weekday,
	}
	schedule._identity_prefix = JSON.stringify(
		[
			identity,
			str(version),
			period,
			str(anchor),
			str(interval),
			offset,
			reset_second,
			weekday,
		]
	)
	return schedule


## 求包含给定时间戳的唯一左闭右开窗口。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param unix_msec: Unix 毫秒时间戳，范围 ±4×10^15；负值和锚点前时间同样支持。
## [br]
## @return 有明确周期身份的窗口；越界或未经工厂创建时为 null。
func get_window(unix_msec: int) -> GFTimeWindow:
	if (
		_interval_msec <= 0
		or unix_msec < -4000000000000000
		or unix_msec > 4000000000000000
	):
		return null
	var start: int = unix_msec - posmod(
		unix_msec - _anchor_msec,
		_interval_msec
	)
	return GFTimeWindow.create(
		start,
		start + _interval_msec,
		_identity_prefix + ":" + str(start)
	)


## 获取实际生效的冻结政策。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return 政策副本；未经工厂创建时为空。
## [br]
## @schema return: 封闭 Dictionary，schedule_id:String、version:int、period:String、anchor_msec:int、interval_msec:int、offset_minutes:int、reset_second:int、weekday:int；fixed 的日历字段为0，daily的weekday为0。
func to_record() -> Dictionary:
	return _record.duplicate()
