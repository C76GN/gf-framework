## GFCalendarGrid: 完整周构成的不可变月历网格结果。
##
## 成功网格始终为 7 列、4 到 6 行，并包含目标月的全部日期。
## 返回的日期集合是隔离副本，不暴露内部数组。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since unreleased
class_name GFCalendarGrid
extends RefCounted


# --- 常量 ---

## 网格已成功构建。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_BUILT: StringName = &"built"

## 目标日期、周起点或固定行数无效。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_INVALID_REQUEST: StringName = &"invalid_request"

## 指定行数无法容纳目标月的全部日期。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_INSUFFICIENT_ROWS: StringName = &"insufficient_rows"

## 完整周所需的相邻日期超出支持年份范围。
## [br]
## @api public
## [br]
## @since unreleased
const STATUS_OUT_OF_RANGE: StringName = &"out_of_range"

## 网格固定列数。
## [br]
## @api public
## [br]
## @since unreleased
const COLUMN_COUNT: int = 7


# --- 私有变量 ---

var _configured: bool = false
var _status: StringName = STATUS_INVALID_REQUEST
var _year: int = 0
var _month: int = 0
var _week_start: int = 0
var _row_count: int = 0
var _cells: Array[GFCivilDate] = []
var _error: String = ""


# --- 公共方法 ---

## 检查网格是否成功构建。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 包含完整月历网格时返回 true。
func is_successful() -> bool:
	return _configured and _status == STATUS_BUILT


## 获取稳定构建状态。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: `STATUS_*` 常量之一。
func get_status() -> StringName:
	return _status


## 获取失败说明。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功时为空字符串。
func get_error() -> String:
	return _error


## 获取目标年份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功时的目标年份；失败时返回 0。
func get_year() -> int:
	return _year


## 获取目标月份。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功时的 1 到 12；失败时返回 0。
func get_month() -> int:
	return _month


## 获取每周第一天。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: `GFCivilDate.Weekday` 值；失败时返回 0。
func get_week_start() -> int:
	return _week_start


## 获取网格行数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功时为 4 到 6；失败时返回 0。
func get_row_count() -> int:
	return _row_count


## 获取固定列数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 始终返回 7。
func get_column_count() -> int:
	return COLUMN_COUNT


## 获取单元数。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 成功时为行数乘 7；失败时返回 0。
func get_cell_count() -> int:
	return _cells.size()


## 获取指定单元的日期。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param index: 从 0 开始的行主序索引。
## [br]
## @return: 索引合法时的不可变日期；否则返回 null。
func get_cell(index: int) -> GFCivilDate:
	if index < 0 or index >= _cells.size():
		return null
	return _cells[index]


## 获取全部单元日期。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @return: 按行主序排列的新数组；修改该数组不会影响网格。
func get_cells() -> Array[GFCivilDate]:
	var copy: Array[GFCivilDate] = []
	copy.assign(_cells)
	return copy


# --- 层内方法 ---

## 由时间工具层一次性配置网格或失败结果。
## [br]
## @api layer_internal
## [br]
## @layer standard/utilities/time
## [br]
## @since unreleased
## [br]
## @param status: `STATUS_*` 常量之一。
## [br]
## @param year: 成功时的目标年份。
## [br]
## @param month: 成功时的目标月份。
## [br]
## @param week_start: 成功时的 `GFCivilDate.Weekday` 值。
## [br]
## @param row_count: 成功时的 4 到 6 行。
## [br]
## @param cells: 成功时的连续日期单元。
## [br]
## @param error: 失败说明。
## [br]
## @return: 首次且状态组合合法时返回 true。
func configure_from_time_layer(
	status: StringName,
	year: int = 0,
	month: int = 0,
	week_start: int = 0,
	row_count: int = 0,
	cells: Array[GFCivilDate] = [],
	error: String = ""
) -> bool:
	if _configured:
		return false
	if status == STATUS_BUILT:
		if not _is_valid_built_grid(year, month, week_start, row_count, cells):
			return false
	else:
		if status not in [STATUS_INVALID_REQUEST, STATUS_INSUFFICIENT_ROWS, STATUS_OUT_OF_RANGE]:
			return false
		if year != 0 or month != 0 or week_start != 0 or row_count != 0 or not cells.is_empty():
			return false

	_configured = true
	_status = status
	_year = year
	_month = month
	_week_start = week_start
	_row_count = row_count
	_cells.assign(cells)
	_error = "" if status == STATUS_BUILT else error.strip_edges()
	return true


# --- 私有/辅助方法 ---

func _is_valid_built_grid(
	year: int,
	month: int,
	week_start: int,
	row_count: int,
	cells: Array[GFCivilDate]
) -> bool:
	if (
		GFCivilDate.get_days_in_month(year, month) == 0
		or week_start < GFCivilDate.Weekday.MONDAY
		or week_start > GFCivilDate.Weekday.SUNDAY
		or row_count < 4
		or row_count > 6
		or cells.size() != row_count * COLUMN_COUNT
		or cells.is_empty()
		or cells[0] == null
		or cells[0].get_weekday() != week_start
	):
		return false

	var contains_first: bool = false
	var contains_last: bool = false
	var last_day: int = GFCivilDate.get_days_in_month(year, month)
	for index: int in range(cells.size()):
		var date: GFCivilDate = cells[index]
		if date == null or not date.is_valid():
			return false
		if index > 0 and date.to_ordinal() != cells[index - 1].to_ordinal() + 1:
			return false
		if date.get_year() == year and date.get_month() == month:
			contains_first = contains_first or date.get_day() == 1
			contains_last = contains_last or date.get_day() == last_day
	return contains_first and contains_last
