## GFCalendarGridTools: 从公民日期构建通用月历网格。
##
## 只计算完整周和相邻日期，不创建 UI 节点，不决定语言区域、节假日、选中态或业务标记。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since unreleased
class_name GFCalendarGridTools
extends RefCounted


# --- 公共方法 ---

## 构建包含目标月全部日期的完整周网格。
## [br]
## @api public
## [br]
## @since unreleased
## [br]
## @param month: 目标月内的任意有效日期，其日值不影响结果。
## [br]
## @param week_start: `GFCivilDate.Weekday` 值，默认星期一。
## [br]
## @param fixed_rows: 0 表示最小完整周数；否则必须为 4、5 或 6。
## [br]
## @return: 7 列、4 到 6 行的网格，或包含稳定失败状态的结果。
static func build_month_grid(
	month: GFCivilDate,
	week_start: int = GFCivilDate.Weekday.MONDAY,
	fixed_rows: int = 0
) -> GFCalendarGrid:
	if (
		month == null
		or not month.is_valid()
		or week_start < GFCivilDate.Weekday.MONDAY
		or week_start > GFCivilDate.Weekday.SUNDAY
		or fixed_rows not in [0, 4, 5, 6]
	):
		return _make_failure(
			GFCalendarGrid.STATUS_INVALID_REQUEST,
			"月历网格需要有效日期、ISO 周起点与 0/4/5/6 行策略。"
		)

	var first_result: GFCivilDateResult = GFCivilDate.create(
		month.get_year(),
		month.get_month(),
		1
	)
	var first_date: GFCivilDate = first_result.get_date()
	var leading_days: int = (first_date.get_weekday() - week_start + 7) % 7
	var required_cells: int = leading_days + GFCivilDate.get_days_in_month(
		month.get_year(),
		month.get_month()
	)
	var minimum_rows: int = floori(float(required_cells + 6) / 7.0)
	var row_count: int = minimum_rows if fixed_rows == 0 else fixed_rows
	if row_count < minimum_rows:
		return _make_failure(
			GFCalendarGrid.STATUS_INSUFFICIENT_ROWS,
			"指定行数无法容纳目标月的全部日期。"
		)

	var first_cell_result: GFCivilDateResult = first_date.add_days(-leading_days)
	if not first_cell_result.is_successful():
		return _make_failure(
			GFCalendarGrid.STATUS_OUT_OF_RANGE,
			"完整周所需的前置日期超出支持范围。"
		)

	var first_cell: GFCivilDate = first_cell_result.get_date()
	var cells: Array[GFCivilDate] = []
	for index: int in range(row_count * GFCalendarGrid.COLUMN_COUNT):
		var cell_result: GFCivilDateResult = first_cell.add_days(index)
		if not cell_result.is_successful():
			return _make_failure(
				GFCalendarGrid.STATUS_OUT_OF_RANGE,
				"完整周所需的后置日期超出支持范围。"
			)
		cells.append(cell_result.get_date())

	var grid: GFCalendarGrid = GFCalendarGrid.new()
	var configured: bool = grid.configure_from_time_layer(
		GFCalendarGrid.STATUS_BUILT,
		month.get_year(),
		month.get_month(),
		week_start,
		row_count,
		cells
	)
	if not configured:
		return _make_failure(
			GFCalendarGrid.STATUS_INVALID_REQUEST,
			"月历网格内部不变量校验失败。"
		)
	return grid


# --- 私有/辅助方法 ---

static func _make_failure(status: StringName, error: String) -> GFCalendarGrid:
	var grid: GFCalendarGrid = GFCalendarGrid.new()
	var _configured: bool = grid.configure_from_time_layer(status, 0, 0, 0, 0, [], error)
	return grid
