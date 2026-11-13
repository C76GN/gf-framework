extends GutTest

var _clock: GFManualClock
var _estimator: GFServerTimeEstimator


class RegressingClock extends GFClock:
	var current_msec: int = 100

	func get_monotonic_msec() -> int:
		return current_msec


func before_each() -> void:
	_clock = GFManualClock.new()
	_estimator = GFServerTimeEstimator.create(
		_clock,
		{
			"max_age_msec": 1000,
			"max_rtt_msec": 100,
			"drift_ppm": 1000,
		}
	)


func test_no_sample_is_explicitly_unavailable() -> void:
	var record: Dictionary = _estimator.get_estimate()
	assert_eq(
		record.size(),
		9
	)
	assert_eq(
		GFVariantData.get_option_string(record, "status"),
		"unavailable"
	)
	assert_false(GFVariantData.get_option_bool(record, "available"))
	assert_eq(
		GFVariantData.get_option_int(record, "sample_age_msec"),
		-1
	)
	assert_eq(
		GFVariantData.get_option_int(record, "unix_time_msec"),
		0
	)
	assert_eq(
		GFServerTimeEstimator.new().begin_sample(),
		0
	)


func test_midpoint_estimate_exposes_rtt_age_and_conservative_interval() -> void:
	var ticket: int = _estimator.begin_sample()
	assert_true(_clock.advance_msec(51))
	assert_true(
		_estimator.accept_sample(
			ticket,
			100000,
			2
		)
	)
	var record: Dictionary = _estimator.get_estimate()
	assert_eq(
		GFVariantData.get_option_int(record, "unix_time_msec"),
		100025
	)
	assert_eq(
		GFVariantData.get_option_int(record, "round_trip_msec"),
		51
	)
	assert_eq(
		GFVariantData.get_option_int(record, "uncertainty_msec"),
		28
	)
	assert_eq(
		GFVariantData.get_option_int(record, "lower_bound_msec"),
		99997
	)
	assert_eq(
		GFVariantData.get_option_int(record, "upper_bound_msec"),
		100053
	)
	assert_true(_clock.advance_msec(500))
	record = _estimator.get_estimate()
	assert_eq(
		GFVariantData.get_option_int(record, "sample_age_msec"),
		500
	)
	assert_eq(
		GFVariantData.get_option_int(record, "uncertainty_msec"),
		29
	)
	assert_eq(
		GFVariantData.get_option_int(record, "unix_time_msec"),
		100525
	)


func test_wall_clock_adjustments_do_not_change_estimated_elapsed_time() -> void:
	var ticket: int = _estimator.begin_sample()
	assert_true(_estimator.accept_sample(ticket, 10000))
	assert_true(_clock.set_unix_time_msec(999999999999))
	assert_eq(
		_value("unix_time_msec"),
		10000
	)
	assert_true(_clock.advance_msec(10))
	assert_true(_clock.set_unix_time_msec(0))
	assert_eq(
		_value("unix_time_msec"),
		10010
	)


func test_expiry_boundary_hides_unusable_unix_values_but_preserves_diagnostics() -> void:
	var ticket: int = _estimator.begin_sample()
	assert_true(_clock.advance_msec(10))
	assert_true(_estimator.accept_sample(ticket, 123))
	assert_true(_clock.advance_msec(999))
	assert_true(
		GFVariantData.get_option_bool(
			_estimator.get_estimate(),
			"available"
		)
	)
	assert_true(_clock.advance_msec(1))
	var expired: Dictionary = _estimator.get_estimate()
	assert_eq(
		GFVariantData.get_option_string(expired, "status"),
		"expired"
	)
	assert_eq(
		GFVariantData.get_option_int(expired, "unix_time_msec"),
		0
	)
	assert_eq(
		GFVariantData.get_option_int(expired, "round_trip_msec"),
		10
	)
	assert_eq(
		GFVariantData.get_option_int(expired, "sample_age_msec"),
		1000
	)
	assert_eq(
		GFVariantData.get_option_int(expired, "uncertainty_msec"),
		-1
	)
	assert_true(
		_estimator.accept_sample(
			_estimator.begin_sample(),
			2000
		)
	)
	assert_true(
		GFVariantData.get_option_bool(
			_estimator.get_estimate(),
			"available"
		)
	)


func test_late_older_response_and_duplicate_ticket_cannot_replace_newer_sample() -> void:
	var first: int = _estimator.begin_sample()
	assert_true(_clock.advance_msec(1))
	var second: int = _estimator.begin_sample()
	assert_true(_estimator.accept_sample(second, 2000))
	assert_false(_estimator.accept_sample(first, 1000))
	assert_false(_estimator.accept_sample(second, 9999))
	assert_eq(
		_value("unix_time_msec"),
		2000
	)


func test_resume_invalidates_samples_and_pending_tickets_even_in_same_millisecond() -> void:
	assert_true(
		_estimator.accept_sample(
			_estimator.begin_sample(),
			2000
		)
	)
	var pending_ticket: int = _estimator.begin_sample()
	_estimator.mark_resumed()
	assert_eq(
		GFVariantData.get_option_string(
			_estimator.get_estimate(),
			"status"
		),
		"resumed"
	)
	assert_false(_estimator.accept_sample(pending_ticket, 2000))
	var fresh: int = _estimator.begin_sample()
	assert_gt(fresh, pending_ticket)
	assert_true(_estimator.accept_sample(fresh, 3000))
	assert_eq(
		_value("unix_time_msec"),
		3000
	)


func test_rejected_sample_consumes_ticket_and_keeps_previous_valid_sample() -> void:
	assert_true(
		_estimator.accept_sample(
			_estimator.begin_sample(),
			1000
		)
	)
	var delayed: int = _estimator.begin_sample()
	assert_true(_clock.advance_msec(101))
	assert_false(_estimator.accept_sample(delayed, 5000))
	assert_eq(
		_value("unix_time_msec"),
		1101
	)
	var invalid: int = _estimator.begin_sample()
	assert_false(_estimator.accept_sample(invalid, 4000000000000001))
	assert_false(_estimator.accept_sample(invalid, 5000))
	assert_false(
		_estimator.accept_sample(
			_estimator.begin_sample(),
			5000,
			-1
		)
	)
	assert_eq(
		_value("unix_time_msec"),
		1101
	)


func test_pending_budget_cancel_and_timeout_cleanup_are_bounded() -> void:
	var tickets: Array[int] = []
	for index: int in range(16):
		tickets.append(_estimator.begin_sample())
	assert_eq(
		_estimator.begin_sample(),
		0
	)
	assert_true(_estimator.cancel_sample(tickets[0]))
	assert_false(_estimator.cancel_sample(tickets[0]))
	assert_false(
		_estimator.accept_sample(
			tickets[0],
			1000
		)
	)
	assert_gt(
		_estimator.begin_sample(),
		0
	)
	assert_true(_clock.advance_msec(101))
	assert_gt(
		_estimator.begin_sample(),
		0
	)
	assert_false(
		_estimator.accept_sample(
			tickets[1],
			1000
		)
	)


func test_regressing_monotonic_source_requires_explicit_recovery() -> void:
	var clock: RegressingClock = RegressingClock.new()
	var estimator: GFServerTimeEstimator = GFServerTimeEstimator.create(clock)
	assert_true(
		estimator.accept_sample(
			estimator.begin_sample(),
			1000
		)
	)
	clock.current_msec = 99
	assert_eq(
		GFVariantData.get_option_string(
			estimator.get_estimate(),
			"status"
		),
		"clock_regressed"
	)
	clock.current_msec = 200
	assert_eq(
		estimator.begin_sample(),
		0
	)
	estimator.mark_resumed()
	assert_true(
		estimator.accept_sample(
			estimator.begin_sample(),
			5000
		)
	)
	assert_eq(
		GFVariantData.get_option_int(
			estimator.get_estimate(),
			"unix_time_msec"
		),
		5000
	)


func test_new_sample_may_correct_time_backwards_and_retains_large_integer_precision() -> void:
	assert_true(
		_estimator.accept_sample(
			_estimator.begin_sample(),
			3999999999999999
		)
	)
	assert_eq(
		_value("unix_time_msec"),
		3999999999999999
	)
	assert_true(
		_estimator.accept_sample(
			_estimator.begin_sample(),
			-123
		)
	)
	assert_eq(
		_value("unix_time_msec"),
		-123
	)


func test_policies_are_strict_and_frozen() -> void:
	assert_null(
		GFServerTimeEstimator.create(
			_clock,
			{ "max_age_msec": 0 }
		)
	)
	assert_null(
		GFServerTimeEstimator.create(
			_clock,
			{ "max_rtt_msec": 1.0 }
		)
	)
	assert_null(
		GFServerTimeEstimator.create(
			_clock,
			{ "drift_ppm": -1 }
		)
	)
	assert_null(
		GFServerTimeEstimator.create(
			_clock,
			{ "authority": true }
		)
	)
	var options: Dictionary = { "max_age_msec": 5, "max_rtt_msec": 0 }
	var estimator: GFServerTimeEstimator = GFServerTimeEstimator.create(_clock, options)
	options["max_age_msec"] = 5000
	assert_true(
		estimator.accept_sample(
			estimator.begin_sample(),
			100
		)
	)
	assert_true(_clock.advance_msec(5))
	assert_eq(
		GFVariantData.get_option_string(
			estimator.get_estimate(),
			"status"
		),
		"expired"
	)


func _value(key: String) -> int:
	return GFVariantData.get_option_int(
		_estimator.get_estimate(),
		key
	)
