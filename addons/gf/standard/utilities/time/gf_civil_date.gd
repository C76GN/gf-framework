## GFCivilDate: 无时区、无时刻的不可变公民日期。
##
## 使用前推格里高利历，支持 0001-01-01 到 9999-12-31。
## 本类只处理日期数学，不读取系统时钟，不包含时区、语言区域、节假日或业务日规则。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFCivilDate
extends RefCounted


# --- 枚举 ---

## ISO 8601 星期编号，星期一为 1，星期日为 7。
## [br]
## @api public
## [br]
## @since unreleased
enum Weekday {
	## 星期一。
	MONDAY = 1,
	## 星期二。
	TUESDAY = 2,
	## 星期三。
	WEDNESDAY = 3,
	## 星期四。
	THURSDAY = 4,
	## 星期五。
	FRIDAY = 5,
	## 星期六。
	SATURDAY = 6,
	## 星期日。
	SUNDAY = 7,
}


# --- 常量 ---

## 最小支持年份。
## [br]
## @api public
## [br]
## @since unreleased
const MIN_YEAR: int = 1

## 最大支持年份。
## [br]
## @api public
## [br]
## @since unreleased
const MAX_YEAR: int = 9999


# --- 私有变量 ---

var _configured: bool = false
var _year: int = 0
var _month: int = 0
var _day: int = 0


# --- 公共方法 ---

## 创建公民日期。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param year: 1 到 9999 的年份。
## [br]
## @param month: 1 到 12 的月份。
## [br]
## @param day: 当月有效日。
## [br]
## @return: 显式成功或失败结果；不钳制输入。
static func create(year: int, month: int, day: int) -> GFCivilDateResult:
	if year < MIN_YEAR or year > MAX_YEAR:
		return _make_failure(
			GFCivilDateResult.STATUS_OUT_OF_RANGE,
			"年份必须处于 1 到 9999。"
		)
	if month < 1 or month > 12 or day < 1 or day > _days_in_month_unchecked(year, month):
		return _make_failure(
			GFCivilDateResult.STATUS_INVALID_DATE,
			"年、月、日组合不是有效公民日期。"
		)
	var date: GFCivilDate = GFCivilDate.new()
	var configured: bool = date.configure_from_time_layer(year, month, day)
	if not configured:
		return _make_failure(
			GFCivilDateResult.STATUS_INVALID_DATE,
			"日期组建失败。"
		)
	var result: GFCivilDateResult = GFCivilDateResult.new()
	var result_configured: bool = result.configure_from_time_layer(
		GFCivilDateResult.STATUS_OK,
		date
	)
	if not result_configured:
		return _make_failure(
			GFCivilDateResult.STATUS_INVALID_DATE,
			"日期结果组建失败。"
		)
	return result


## 解析固定长度 ISO 8601 日期文本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param text: 严格的 `YYYY-MM-DD` 文本，不接受空白、符号或可变位数。
## [br]
## @return: 解析结果；格式错误与日期错误使用不同状态。
static func parse_iso8601(text: String) -> GFCivilDateResult:
	if (
		text.length() != 10
		or text[4] != "-"
		or text[7] != "-"
		or not _is_ascii_digits(text, 0, 4)
		or not _is_ascii_digits(text, 5, 2)
		or not _is_ascii_digits(text, 8, 2)
	):
		return _make_failure(
			GFCivilDateResult.STATUS_INVALID_FORMAT,
			"日期文本必须严格使用 YYYY-MM-DD 格式。"
		)
	return create(text.substr(0, 4).to_int(), text.substr(5, 2).to_int(), text.substr(8, 2).to_int())


## 从稳定字典 schema 恢复日期。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param data: 包含整数 year、month 与 day 的字典。
## [br]
## @schema data: Closed Dictionary with exactly integer year, month, and day fields.
## [br]
## @return: 解析结果；缺少字段或字段类型错误时为 `STATUS_INVALID_FORMAT`。
static func from_dict(data: Dictionary) -> GFCivilDateResult:
	if data.size() != 3 or not data.has("year") or not data.has("month") or not data.has("day"):
		return _make_failure(
			GFCivilDateResult.STATUS_INVALID_FORMAT,
			"日期字典必须仅包含 year、month 与 day。"
		)
	var year_value: Variant = data.get("year")
	var month_value: Variant = data.get("month")
	var day_value: Variant = data.get("day")
	if not year_value is int or not month_value is int or not day_value is int:
		return _make_failure(
			GFCivilDateResult.STATUS_INVALID_FORMAT,
			"日期字典必须包含整数 year、month 与 day。"
		)
	var year: int = year_value
	var month: int = month_value
	var day: int = day_value
	return create(year, month, day)


## 从零起点日序号创建日期。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param ordinal: 0001-01-01 为 0 的日序号。
## [br]
## @return: 序号在支持范围内时的日期结果。
static func from_ordinal(ordinal: int) -> GFCivilDateResult:
	if ordinal < 0 or ordinal > _maximum_ordinal():
		return _make_failure(
			GFCivilDateResult.STATUS_OUT_OF_RANGE,
			"日序号超出支持的公民日期范围。"
		)

	var remaining: int = ordinal
	var year: int = 1
	var cycle_400: int = floori(float(remaining) / 146097.0)
	year += cycle_400 * 400
	remaining -= cycle_400 * 146097
	var cycle_100: int = mini(floori(float(remaining) / 36524.0), 3)
	year += cycle_100 * 100
	remaining -= cycle_100 * 36524
	var cycle_4: int = floori(float(remaining) / 1461.0)
	year += cycle_4 * 4
	remaining -= cycle_4 * 1461
	var cycle_1: int = mini(floori(float(remaining) / 365.0), 3)
	year += cycle_1
	remaining -= cycle_1 * 365

	var month: int = 1
	while remaining >= _days_in_month_unchecked(year, month):
		remaining -= _days_in_month_unchecked(year, month)
		month += 1
	return create(year, month, remaining + 1)


## 检查年份是否为前推格里高利历闰年。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param year: 待检查年份。
## [br]
## @return: 1 到 9999 之内且符合闰年规则时返回 true。
static func is_leap_year(year: int) -> bool:
	return year >= MIN_YEAR and year <= MAX_YEAR and _is_leap_year_unchecked(year)


## 获取指定月天数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param year: 1 到 9999 的年份。
## [br]
## @param month: 1 到 12 的月份。
## [br]
## @return: 当月天数；输入越界时返回 0。
static func get_days_in_month(year: int, month: int) -> int:
	if year < MIN_YEAR or year > MAX_YEAR or month < 1 or month > 12:
		return 0
	return _days_in_month_unchecked(year, month)


## 检查实例是否由日期工厂成功配置。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 包含支持范围内有效日期时返回 true。
func is_valid() -> bool:
	return _configured


## 获取年份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 年份；未配置实例返回 0。
func get_year() -> int:
	return _year


## 获取月份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 1 到 12；未配置实例返回 0。
func get_month() -> int:
	return _month


## 获取月内日。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 1 到当月天数；未配置实例返回 0。
func get_day() -> int:
	return _day


## 转换为固定长度 ISO 8601 日期文本。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: `YYYY-MM-DD`；未配置实例返回空字符串。
func to_iso8601() -> String:
	if not _configured:
		return ""
	return "%04d-%02d-%02d" % [_year, _month, _day]


## 转换为稳定组件字典。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 包含整数 year、month 与 day 的新字典；未配置时为空字典。
## [br]
## @schema return: Dictionary with integer year, month, and day fields.
func to_dict() -> Dictionary:
	if not _configured:
		return {}
	return {
		"year": _year,
		"month": _month,
		"day": _day,
	}


## 获取零起点日序号。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 0001-01-01 为 0 的日序号；未配置时返回 -1。
func to_ordinal() -> int:
	if not _configured:
		return -1
	return _date_to_ordinal(_year, _month, _day)


## 获取 ISO 8601 星期编号。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: `Weekday` 值；未配置时返回 0。
func get_weekday() -> int:
	if not _configured:
		return 0
	return (to_ordinal() % 7) + Weekday.MONDAY


## 获取年内日序号。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 1 到 366；未配置时返回 0。
func get_day_of_year() -> int:
	if not _configured:
		return 0
	return to_ordinal() - _date_to_ordinal(_year, 1, 1) + 1


## 获取 ISO 周所属周年。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: ISO 周年；未配置时返回 0。
func get_iso_week_year() -> int:
	if not _configured:
		return 0
	var thursday_result: GFCivilDateResult = from_ordinal(
		to_ordinal() + (Weekday.THURSDAY - get_weekday())
	)
	return thursday_result.get_date().get_year() if thursday_result.is_successful() else 0


## 获取 ISO 周序号。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 1 到 53；未配置时返回 0。
func get_iso_week_number() -> int:
	var iso_year: int = get_iso_week_year()
	if iso_year == 0:
		return 0
	var january_four_ordinal: int = _date_to_ordinal(iso_year, 1, 4)
	var january_four_weekday: int = (january_four_ordinal % 7) + Weekday.MONDAY
	var week_one_monday: int = january_four_ordinal - (january_four_weekday - Weekday.MONDAY)
	return floori(float(to_ordinal() - week_one_monday) / 7.0) + 1


## 加减日数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param days: 可为负数的日偏移。
## [br]
## @return: 偏移后日期；未配置或超出支持范围时失败。
func add_days(days: int) -> GFCivilDateResult:
	if not _configured:
		return _make_failure(GFCivilDateResult.STATUS_INVALID_DATE, "未配置日期不能运算。")
	var ordinal: int = to_ordinal()
	if days < -ordinal or days > _maximum_ordinal() - ordinal:
		return _make_failure(
			GFCivilDateResult.STATUS_OUT_OF_RANGE,
			"日偏移超出支持的公民日期范围。"
		)
	return from_ordinal(ordinal + days)


## 加减自然月。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param months: 可为负数的月偏移。
## [br]
## @param clamp_day: 目标月不含原月内日时，true 钳制到月末，false 返回失败。
## [br]
## @return: 偏移后日期或显式失败。
func add_months(months: int, clamp_day: bool = true) -> GFCivilDateResult:
	if not _configured:
		return _make_failure(GFCivilDateResult.STATUS_INVALID_DATE, "未配置日期不能运算。")
	var current_index: int = (_year - MIN_YEAR) * 12 + (_month - 1)
	var maximum_index: int = (MAX_YEAR - MIN_YEAR + 1) * 12 - 1
	if months < -current_index or months > maximum_index - current_index:
		return _make_failure(
			GFCivilDateResult.STATUS_OUT_OF_RANGE,
			"月偏移超出支持的公民日期范围。"
		)
	var target_index: int = current_index + months
	var target_year: int = floori(float(target_index) / 12.0) + MIN_YEAR
	var target_month: int = target_index % 12 + 1
	var target_day_limit: int = _days_in_month_unchecked(target_year, target_month)
	if _day > target_day_limit and not clamp_day:
		return _make_failure(
			GFCivilDateResult.STATUS_INVALID_DATE,
			"目标月不包含原月内日，且调用方禁止月末钳制。"
		)
	return create(target_year, target_month, mini(_day, target_day_limit))


## 加减公民年。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param years: 可为负数的年偏移。
## [br]
## @param clamp_day: 目标年不含原月内日时，true 钳制到月末，false 返回失败。
## [br]
## @return: 偏移后日期或显式失败。
func add_years(years: int, clamp_day: bool = true) -> GFCivilDateResult:
	if not _configured:
		return _make_failure(GFCivilDateResult.STATUS_INVALID_DATE, "未配置日期不能运算。")
	if years < MIN_YEAR - _year or years > MAX_YEAR - _year:
		return _make_failure(
			GFCivilDateResult.STATUS_OUT_OF_RANGE,
			"年偏移超出支持的公民日期范围。"
		)
	var target_year: int = _year + years
	var target_day_limit: int = _days_in_month_unchecked(target_year, _month)
	if _day > target_day_limit and not clamp_day:
		return _make_failure(
			GFCivilDateResult.STATUS_INVALID_DATE,
			"目标年不包含原月内日，且调用方禁止月末钳制。"
		)
	return create(target_year, _month, mini(_day, target_day_limit))


## 比较当前日期与另一日期。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param other: 右侧日期。
## [br]
## @return: 包含比较次序与 `other - self` 日差的类型化结果。
func compare_to(other: GFCivilDate) -> GFCivilDateDifferenceResult:
	return days_until(other)


## 计算从当前日期到另一日期的有符号日数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param other: 右侧日期。
## [br]
## @return: 包含 `other - self` 日差和比较次序的类型化结果。
func days_until(other: GFCivilDate) -> GFCivilDateDifferenceResult:
	var result: GFCivilDateDifferenceResult = GFCivilDateDifferenceResult.new()
	if not _configured or other == null or not other.is_valid():
		var _failure_configured: bool = result.configure_from_time_layer(
			GFCivilDateDifferenceResult.STATUS_INVALID_DATE,
			0,
			"两个日期都必须有效。"
		)
		return result
	var _success_configured: bool = result.configure_from_time_layer(
		GFCivilDateDifferenceResult.STATUS_OK,
		other.to_ordinal() - to_ordinal()
	)
	return result


# --- 层内方法 ---

## 由时间工具层一次性配置已校验日期。
## [br]
## @api layer_internal
## [br]
## @layer standard/utilities/time
## [br]
## @since unreleased
## [br]
## @param year: 已校验年份。
## [br]
## @param month: 已校验月份。
## [br]
## @param day: 已校验月内日。
## [br]
## @return: 首次且输入合法时返回 true。
func configure_from_time_layer(year: int, month: int, day: int) -> bool:
	if (
		_configured
		or year < MIN_YEAR
		or year > MAX_YEAR
		or month < 1
		or month > 12
		or day < 1
		or day > _days_in_month_unchecked(year, month)
	):
		return false
	_configured = true
	_year = year
	_month = month
	_day = day
	return true


# --- 私有/辅助方法 ---

static func _make_failure(status: StringName, error: String) -> GFCivilDateResult:
	var result: GFCivilDateResult = GFCivilDateResult.new()
	var _configured_result: bool = result.configure_from_time_layer(status, null, error)
	return result


static func _is_ascii_digits(text: String, start: int, length: int) -> bool:
	for index: int in range(start, start + length):
		var codepoint: int = text.unicode_at(index)
		if codepoint < 48 or codepoint > 57:
			return false
	return true


static func _maximum_ordinal() -> int:
	return _date_to_ordinal(MAX_YEAR, 12, 31)


static func _date_to_ordinal(year: int, month: int, day: int) -> int:
	var previous_year: int = year - 1
	var ordinal: int = (
		previous_year * 365
		+ floori(float(previous_year) / 4.0)
		- floori(float(previous_year) / 100.0)
		+ floori(float(previous_year) / 400.0)
	)
	for previous_month: int in range(1, month):
		ordinal += _days_in_month_unchecked(year, previous_month)
	return ordinal + day - 1


static func _days_in_month_unchecked(year: int, month: int) -> int:
	match month:
		2:
			return 29 if _is_leap_year_unchecked(year) else 28
		4, 6, 9, 11:
			return 30
		_:
			return 31


static func _is_leap_year_unchecked(year: int) -> bool:
	return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)
