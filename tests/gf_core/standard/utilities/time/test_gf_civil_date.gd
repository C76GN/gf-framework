## 测试公民日期与月历网格的纯数学契约。
extends GutTest


# --- 测试方法 ---

## 验证日期创建遵循前推格里高利历闰年规则且不隐式钳制。
func test_create_validates_proleptic_gregorian_date() -> void:
	var leap_result: GFCivilDateResult = GFCivilDate.create(2000, 2, 29)
	var century_result: GFCivilDateResult = GFCivilDate.create(1900, 2, 29)
	var out_of_range_result: GFCivilDateResult = GFCivilDate.create(0, 1, 1)

	assert_true(leap_result.is_successful())
	assert_eq(leap_result.get_date().to_iso8601(), "2000-02-29")
	assert_false(century_result.is_successful())
	assert_eq(century_result.get_status(), GFCivilDateResult.STATUS_INVALID_DATE)
	assert_false(out_of_range_result.is_successful())
	assert_eq(out_of_range_result.get_status(), GFCivilDateResult.STATUS_OUT_OF_RANGE)


## 验证 ISO 文本与字典边界严格解析且可无损往返。
func test_parse_and_dictionary_round_trip_are_strict() -> void:
	var parse_result: GFCivilDateResult = GFCivilDate.parse_iso8601("2024-02-29")
	assert_true(parse_result.is_successful())
	assert_eq(parse_result.get_date().to_dict(), {
		"year": 2024,
		"month": 2,
		"day": 29,
	})

	var dictionary_result: GFCivilDateResult = GFCivilDate.from_dict(
		parse_result.get_date().to_dict()
	)
	assert_true(dictionary_result.is_successful())
	assert_eq(dictionary_result.get_date().to_iso8601(), "2024-02-29")
	assert_eq(
		GFCivilDate.parse_iso8601("2024-2-29").get_status(),
		GFCivilDateResult.STATUS_INVALID_FORMAT
	)
	assert_eq(
		GFCivilDate.from_dict({"year": 2024.0, "month": 2, "day": 29}).get_status(),
		GFCivilDateResult.STATUS_INVALID_FORMAT
	)
	assert_eq(
		GFCivilDate.from_dict({
			"year": 2024,
			"month": 2,
			"day": 29,
			"locale": "zh_CN",
		}).get_status(),
		GFCivilDateResult.STATUS_INVALID_FORMAT,
		"日期字典必须保持封闭 schema。"
	)


## 验证序号、ISO 星期与 ISO 周年跨自然年边界。
func test_ordinal_weekday_and_iso_week_boundaries() -> void:
	var epoch: GFCivilDate = GFCivilDate.create(1, 1, 1).get_date()
	assert_eq(epoch.to_ordinal(), 0)
	assert_eq(epoch.get_weekday(), GFCivilDate.Weekday.MONDAY)
	assert_eq(GFCivilDate.from_ordinal(0).get_date().to_iso8601(), "0001-01-01")

	var year_end: GFCivilDate = GFCivilDate.create(2019, 12, 30).get_date()
	assert_eq(year_end.get_iso_week_year(), 2020)
	assert_eq(year_end.get_iso_week_number(), 1)

	var year_start: GFCivilDate = GFCivilDate.create(2021, 1, 1).get_date()
	assert_eq(year_start.get_weekday(), GFCivilDate.Weekday.FRIDAY)
	assert_eq(year_start.get_iso_week_year(), 2020)
	assert_eq(year_start.get_iso_week_number(), 53)


## 验证日与月运算显式报告越界与月末策略。
func test_date_arithmetic_has_explicit_range_and_month_end_policy() -> void:
	var leap_day: GFCivilDate = GFCivilDate.create(2024, 2, 29).get_date()
	assert_eq(leap_day.add_days(1).get_date().to_iso8601(), "2024-03-01")
	assert_eq(leap_day.add_days(-60).get_date().to_iso8601(), "2023-12-31")
	assert_eq(leap_day.get_day_of_year(), 60)

	var january_end: GFCivilDate = GFCivilDate.create(2024, 1, 31).get_date()
	assert_eq(january_end.add_months(1).get_date().to_iso8601(), "2024-02-29")
	assert_eq(
		january_end.add_months(1, false).get_status(),
		GFCivilDateResult.STATUS_INVALID_DATE
	)
	assert_eq(
		GFCivilDate.create(1, 1, 1).get_date().add_days(-1).get_status(),
		GFCivilDateResult.STATUS_OUT_OF_RANGE
	)
	assert_eq(
		GFCivilDate.create(9999, 12, 31).get_date().add_months(1).get_status(),
		GFCivilDateResult.STATUS_OUT_OF_RANGE
	)


## 验证年运算与日期关系使用显式月末策略和类型化失败。
func test_year_arithmetic_comparison_and_days_until_are_explicit() -> void:
	var leap_day: GFCivilDate = GFCivilDate.create(2024, 2, 29).get_date()
	assert_eq(leap_day.add_years(1).get_date().to_iso8601(), "2025-02-28")
	assert_eq(
		leap_day.add_years(1, false).get_status(),
		GFCivilDateResult.STATUS_INVALID_DATE
	)
	assert_eq(
		leap_day.add_years(-2024).get_status(),
		GFCivilDateResult.STATUS_OUT_OF_RANGE
	)

	var earlier: GFCivilDate = GFCivilDate.create(2024, 2, 28).get_date()
	var later: GFCivilDate = GFCivilDate.create(2024, 3, 1).get_date()
	var comparison: GFCivilDateDifferenceResult = earlier.compare_to(later)
	var reverse_days: GFCivilDateDifferenceResult = later.days_until(earlier)
	assert_true(comparison.is_successful())
	assert_eq(comparison.get_comparison(), -1)
	assert_eq(comparison.get_days(), 2)
	assert_true(reverse_days.is_successful())
	assert_eq(reverse_days.get_days(), -2)
	assert_eq(reverse_days.get_comparison(), 1)
	assert_eq(
		earlier.compare_to(GFCivilDate.new()).get_status(),
		GFCivilDateDifferenceResult.STATUS_INVALID_DATE
	)


## 验证月历网格以完整周为单位生成最小 4 到 6 行快照。
func test_calendar_grid_builds_minimum_complete_weeks() -> void:
	var february: GFCivilDate = GFCivilDate.create(2021, 2, 10).get_date()
	var four_week_grid: GFCalendarGrid = GFCalendarGridTools.build_month_grid(february)

	assert_true(four_week_grid.is_successful())
	assert_eq(four_week_grid.get_row_count(), 4)
	assert_eq(four_week_grid.get_column_count(), 7)
	assert_eq(four_week_grid.get_cell_count(), 28)
	assert_eq(four_week_grid.get_cell(0).to_iso8601(), "2021-02-01")
	assert_eq(four_week_grid.get_cell(27).to_iso8601(), "2021-02-28")

	var may: GFCivilDate = GFCivilDate.create(2021, 5, 31).get_date()
	var six_week_grid: GFCalendarGrid = GFCalendarGridTools.build_month_grid(may)
	assert_eq(six_week_grid.get_row_count(), 6)
	assert_eq(six_week_grid.get_cell(0).to_iso8601(), "2021-04-26")
	assert_eq(six_week_grid.get_cell(41).to_iso8601(), "2021-06-06")


## 验证周起点与固定行数是显式策略，不裁剪月内日。
func test_calendar_grid_honors_week_start_and_fixed_rows() -> void:
	var february: GFCivilDate = GFCivilDate.create(2021, 2, 1).get_date()
	var fixed_grid: GFCalendarGrid = GFCalendarGridTools.build_month_grid(
		february,
		GFCivilDate.Weekday.SUNDAY,
		6
	)

	assert_true(fixed_grid.is_successful())
	assert_eq(fixed_grid.get_week_start(), GFCivilDate.Weekday.SUNDAY)
	assert_eq(fixed_grid.get_cell_count(), 42)
	assert_eq(fixed_grid.get_cell(0).to_iso8601(), "2021-01-31")
	assert_eq(fixed_grid.get_cell(41).to_iso8601(), "2021-03-13")

	var may: GFCivilDate = GFCivilDate.create(2021, 5, 1).get_date()
	var insufficient: GFCalendarGrid = GFCalendarGridTools.build_month_grid(
		may,
		GFCivilDate.Weekday.MONDAY,
		5
	)
	assert_false(insufficient.is_successful())
	assert_eq(insufficient.get_status(), GFCalendarGrid.STATUS_INSUFFICIENT_ROWS)


## 验证网格越界与无效策略显式失败，且单元集合隔离。
func test_calendar_grid_fails_closed_at_boundaries_and_isolates_cells() -> void:
	var first_month: GFCivilDate = GFCivilDate.create(1, 1, 1).get_date()
	var before_range: GFCalendarGrid = GFCalendarGridTools.build_month_grid(
		first_month,
		GFCivilDate.Weekday.SUNDAY
	)
	assert_eq(before_range.get_status(), GFCalendarGrid.STATUS_OUT_OF_RANGE)

	var last_month: GFCivilDate = GFCivilDate.create(9999, 12, 1).get_date()
	assert_eq(
		GFCalendarGridTools.build_month_grid(last_month).get_status(),
		GFCalendarGrid.STATUS_OUT_OF_RANGE
	)
	assert_eq(
		GFCalendarGridTools.build_month_grid(first_month, 0).get_status(),
		GFCalendarGrid.STATUS_INVALID_REQUEST
	)

	var grid: GFCalendarGrid = GFCalendarGridTools.build_month_grid(
		GFCivilDate.create(2024, 2, 1).get_date()
	)
	var cells: Array[GFCivilDate] = grid.get_cells()
	cells.clear()
	assert_eq(grid.get_cell_count(), 35, "调用方修改返回数组不得破坏网格快照。")
