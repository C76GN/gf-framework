extends GutTest


func test_same_distribution_has_different_contiguous_windows() -> void:
	for clustered: bool in [true, false]:
		var series: GFFrameIntervalSeries = GFFrameIntervalSeries.create(120)
		for index: int in range(120):
			var slow: bool = (index >= 40 and index <= 45) if clustered else index % 20 == 10
			assert_true(series.record_interval_us(50000 if slow else 16667))
		var summary: Dictionary = series.summarize(30, 16667)
		assert_eq(
			summary,
			{
				"ok": true,
				"capacity": 120,
				"sample_count": 120,
				"total_us": 2200038,
				"mean_us": 18333.65,
				"p95_us": 16667,
				"p99_us": 50000,
				"over_budget_count": 6,
				"max_window_us": 700008 if clustered else 566676,
				"evicted_count": 0,
				"missing_count": 0,
				"rejected_count": 0,
			}
		)


func test_ring_wrap_and_discontinuities_match_a_full_window_scan() -> void:
	var series: GFFrameIntervalSeries = GFFrameIntervalSeries.create(7)
	var values: Array[int] = []
	var segments: Array[int] = []
	var segment: int = 0
	var missing: int = 0
	var rejected: int = 0
	var accepted: int = 0
	for index: int in range(40):
		if index % 9 == 3:
			missing += 2
			segment += 1
			assert_true(series.break_continuity(2))
		if index % 13 == 4:
			rejected += 1
			segment += 1
			assert_false(series.record_interval_us(0))
		else:
			accepted += 1
			var value: int = index * 17 % 29 + 1
			assert_true(series.record_interval_us(value))
			values.append(value)
			segments.append(segment)
			if values.size() > 7:
				var _old_value: int = values.pop_front()
				var _old_segment: int = segments.pop_front()
		for width: int in range(1, 10):
			var longest: int = 0
			for start: int in range(values.size() - width + 1):
				if segments[start] != segments[start + width - 1]:
					continue
				var sum_us: int = 0
				for offset: int in range(width):
					sum_us += values[start + offset]
				longest = maxi(longest, sum_us)
			var expected: Variant = null
			if longest > 0:
				expected = longest
			var summary: Dictionary = series.summarize(width, 17)
			assert_eq(
				[
					summary.ok,
					summary.max_window_us,
					summary.missing_count,
					summary.rejected_count,
					summary.evicted_count,
				],
				[
					true,
					expected,
					missing,
					rejected,
					accepted - values.size(),
				]
			)


func test_bounds_empty_saturation_overflow_and_recovery() -> void:
	const MAX_I64: int = 9223372036854775807
	assert_null(GFFrameIntervalSeries.create(0))
	assert_null(GFFrameIntervalSeries.create(GFFrameIntervalSeries.MAX_CAPACITY + 1))
	var unprepared: GFFrameIntervalSeries = GFFrameIntervalSeries.new()
	assert_false(unprepared.record_interval_us(1))
	assert_eq(
		unprepared.summarize(1, 1),
		{ "ok": false, "error": &"unprepared" }
	)
	var series: GFFrameIntervalSeries = GFFrameIntervalSeries.create(2)
	var empty: Dictionary = series.summarize(1, 0)
	assert_eq(
		empty,
		{
			"ok": true,
			"capacity": 2,
			"sample_count": 0,
			"total_us": 0,
			"mean_us": null,
			"p95_us": null,
			"p99_us": null,
			"over_budget_count": 0,
			"max_window_us": null,
			"evicted_count": 0,
			"missing_count": 0,
			"rejected_count": 0,
		}
	)
	assert_eq(
		series.summarize(0, 1),
		{ "ok": false, "error": &"invalid_query" }
	)
	assert_eq(
		series.summarize(1, -1),
		{ "ok": false, "error": &"invalid_query" }
	)
	assert_true(series.break_continuity(MAX_I64))
	assert_true(series.break_continuity(10))
	assert_true(series.record_interval_us(MAX_I64))
	assert_false(series.break_continuity(-1))
	assert_true(series.record_interval_us(1))
	assert_eq(
		series.summarize(2, 1),
		{ "ok": false, "error": &"duration_overflow" }
	)
	assert_true(series.record_interval_us(2))
	var recovered: Dictionary = series.summarize(2, 1)
	assert_eq(
		recovered,
		{
			"ok": true,
			"capacity": 2,
			"sample_count": 2,
			"total_us": 3,
			"mean_us": 1.5,
			"p95_us": 2,
			"p99_us": 2,
			"over_budget_count": 1,
			"max_window_us": 3,
			"evicted_count": 1,
			"missing_count": MAX_I64,
			"rejected_count": 0,
		}
	)
	assert_true(series.break_continuity())
	assert_true(series.record_interval_us(5))
	assert_true(series.summarize(2, 0).max_window_us == null)
