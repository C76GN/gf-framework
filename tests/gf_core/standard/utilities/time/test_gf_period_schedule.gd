extends GutTest


func test_daily_utc_window_is_left_closed_right_open() -> void:
	var schedule: GFPeriodSchedule = GFPeriodSchedule.create(&"daily", 1)
	var window: GFTimeWindow = schedule.get_window(0)
	assert_eq(
		window.get_start_msec(),
		0
	)
	assert_eq(
		window.get_end_msec(),
		86400000
	)
	assert_true(window.contains(0))
	assert_true(window.contains(86399999))
	assert_false(window.contains(-1))
	assert_false(window.contains(86400000))
	assert_eq(
		schedule.get_window(86400000).get_start_msec(),
		86400000
	)
	assert_ne(
		schedule.get_window(86400000).get_period_id(),
		window.get_period_id()
	)


func test_daily_negative_unix_time_uses_floor_boundaries() -> void:
	var schedule: GFPeriodSchedule = GFPeriodSchedule.create(&"daily", 1)
	var window: GFTimeWindow = schedule.get_window(-1)
	assert_eq(
		window.get_start_msec(),
		-86400000
	)
	assert_eq(
		window.get_end_msec(),
		0
	)
	assert_true(window.contains(-1))


func test_fixed_offset_and_reset_hour_are_explicit() -> void:
	var schedule: GFPeriodSchedule = GFPeriodSchedule.create(
		&"daily",
		1,
		{ "offset_minutes": 480, "reset_second": 14400 }
	)
	var window: GFTimeWindow = schedule.get_window(-14400000)
	assert_eq(
		window.get_start_msec(),
		-14400000
	)
	assert_eq(
		window.get_end_msec(),
		72000000
	)
	assert_eq(
		schedule.get_window(-14400001).get_end_msec(),
		-14400000
	)
	var western: GFPeriodSchedule = GFPeriodSchedule.create(
		&"daily",
		1,
		{ "offset_minutes": -345 }
	)
	assert_eq(
		western.get_window(20700000).get_start_msec(),
		20700000
	)


func test_weekly_uses_explicit_weekday_and_does_not_treat_epoch_as_monday() -> void:
	var monday: GFPeriodSchedule = GFPeriodSchedule.create(
		&"weekly",
		1,
		{ "period": "weekly" }
	)
	assert_eq(
		monday.get_window(0).get_start_msec(),
		-259200000
	)
	assert_eq(
		monday.get_window(345600000).get_start_msec(),
		345600000
	)
	var sunday: GFPeriodSchedule = GFPeriodSchedule.create(
		&"weekly",
		1,
		{ "period": "weekly", "weekday": 0 }
	)
	assert_eq(
		sunday.get_window(0).get_start_msec(),
		-345600000
	)
	assert_eq(
		sunday.get_window(259200000).get_start_msec(),
		259200000
	)
	var shifted: GFPeriodSchedule = GFPeriodSchedule.create(
		&"weekly",
		1,
		{
			"period": "weekly",
			"offset_minutes": 480,
			"reset_second": 14400,
		}
	)
	assert_eq(
		shifted.get_window(331200000).get_start_msec(),
		331200000
	)


func test_fixed_period_handles_both_sides_of_anchor_without_float_rounding() -> void:
	var schedule: GFPeriodSchedule = GFPeriodSchedule.create(
		&"fixed",
		1,
		{
			"period": "fixed",
			"anchor_msec": 100,
			"interval_msec": 7,
		}
	)
	assert_eq(
		schedule.get_window(99).get_start_msec(),
		93
	)
	assert_eq(
		schedule.get_window(99).get_end_msec(),
		100
	)
	assert_eq(
		schedule.get_window(100).get_start_msec(),
		100
	)
	assert_eq(
		schedule.get_window(107).get_start_msec(),
		107
	)
	var large: GFPeriodSchedule = GFPeriodSchedule.create(
		&"large",
		1,
		{
			"period": "fixed",
			"anchor_msec": -4000000000000000,
			"interval_msec": 3,
		}
	)
	var window: GFTimeWindow = large.get_window(3999999999999999)
	assert_true(window.contains(3999999999999999))
	assert_eq(
		posmod(
			window.get_start_msec() + 4000000000000000,
			3
		),
		0
	)
	assert_eq(
		window.get_end_msec() - window.get_start_msec(),
		3
	)


func test_identity_changes_for_version_policy_and_window_but_is_stable_for_same_input() -> void:
	var first: GFPeriodSchedule = GFPeriodSchedule.create(&"daily", 1)
	var second: GFPeriodSchedule = GFPeriodSchedule.create(&"daily", 1)
	var new_version: GFPeriodSchedule = GFPeriodSchedule.create(&"daily", 2)
	var changed_policy: GFPeriodSchedule = GFPeriodSchedule.create(
		&"daily",
		1,
		{ "reset_second": 1 }
	)
	assert_eq(
		first.get_window(50).get_period_id(),
		second.get_window(5000).get_period_id()
	)
	assert_ne(
		first.get_window(50).get_period_id(),
		new_version.get_window(50).get_period_id()
	)
	assert_ne(
		first.get_window(50).get_period_id(),
		changed_policy.get_window(50).get_period_id()
	)
	var copy: Dictionary = first.to_record()
	copy["interval_msec"] = 1
	assert_eq(
		first.get_window(0).get_end_msec(),
		86400000
	)


func test_invalid_or_irrelevant_policy_fields_are_rejected() -> void:
	assert_null(GFPeriodSchedule.create(&"", 1))
	assert_null(GFPeriodSchedule.create(&"daily", 0))
	assert_null(
		GFPeriodSchedule.create(
			&"daily",
			1,
			{ "weekday": 1 }
		)
	)
	assert_null(
		GFPeriodSchedule.create(
			&"daily",
			1,
			{ "offset_minutes": 841 }
		)
	)
	assert_null(
		GFPeriodSchedule.create(
			&"daily",
			1,
			{ "reset_second": 86400 }
		)
	)
	assert_null(
		GFPeriodSchedule.create(
			&"daily",
			1,
			{ "offset_minutes": 1.0 }
		)
	)
	assert_null(
		GFPeriodSchedule.create(
			&"weekly",
			1,
			{ "period": "weekly", "weekday": 7 }
		)
	)
	assert_null(
		GFPeriodSchedule.create(
			&"fixed",
			1,
			{ "period": "fixed", "interval_msec": 1 }
		)
	)
	assert_null(
		GFPeriodSchedule.create(
			&"fixed",
			1,
			{
				"period": "fixed",
				"anchor_msec": 0,
				"interval_msec": 0,
			}
		)
	)
	assert_null(
		GFPeriodSchedule.create(
			&"fixed",
			1,
			{
				"period": "fixed",
				"anchor_msec": 0,
				"interval_msec": 1,
				"offset_minutes": 0,
			}
		)
	)
	assert_null(
		GFPeriodSchedule.create(
			&"daily",
			1,
			{ "timezone": "Asia/Shanghai" }
		)
	)
	assert_null(GFPeriodSchedule.new().get_window(0))
	assert_null(GFPeriodSchedule.create(&"daily", 1).get_window(4000000000000001))


func test_time_window_rejects_empty_or_inverted_ranges_and_copies_records() -> void:
	assert_null(
		GFTimeWindow.create(
			1,
			1,
			"period"
		)
	)
	assert_null(
		GFTimeWindow.create(
			2,
			1,
			"period"
		)
	)
	assert_null(
		GFTimeWindow.create(
			0,
			1,
			""
		)
	)
	assert_false(GFTimeWindow.new().contains(0))
	var window: GFTimeWindow = GFTimeWindow.create(
		1,
		2,
		"period"
	)
	var copy: Dictionary = window.to_record()
	copy["end_msec"] = 100
	assert_eq(
		window.get_end_msec(),
		2
	)
