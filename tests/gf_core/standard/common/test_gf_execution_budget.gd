## 测试通用执行预算。
extends GutTest


func test_step_limit_records_report_issue() -> void:
	var budget: GFExecutionBudget = GFExecutionBudget.new({
		"max_steps": 2,
	})

	assert_true(budget.consume_steps(), "第一次消耗应在预算内。")
	assert_true(budget.consume_steps(), "第二次消耗应在预算内。")
	assert_false(budget.consume_steps(), "超过 max_steps 后应拒绝继续。")
	assert_eq(budget.get_violation_reason(), &"step_limit_exceeded", "违规原因应稳定。")

	var report: GFValidationReport = budget.make_report("Budget")
	assert_false(report.is_ok(), "预算违规报告应包含错误。")
	assert_eq(report.get_error_count(), 1, "预算违规应记录一条错误。")


func test_cancel_token_stops_budget_check() -> void:
	var source: GFCancellationSource = GFCancellationSource.new()
	var budget: GFExecutionBudget = GFExecutionBudget.new({
		"cancel_token": source.get_token(),
	})

	var _cancelled: bool = source.cancel(&"user_cancelled", {
		"owner": "test",
	})

	assert_false(budget.check(), "取消 token 后预算检查应失败。")
	assert_true(budget.is_exceeded(), "取消也应进入终止状态。")
	assert_eq(budget.get_violation_reason(), &"cancelled", "取消原因应归一为预算违规原因。")


func test_elapsed_limit_uses_injected_monotonic_clock() -> void:
	var clock: GFManualClock = GFManualClock.new(500000, 1700000000000)
	var budget: GFExecutionBudget = GFExecutionBudget.new({
		"max_elapsed_msec": 10,
	}, clock)

	assert_eq(budget.get_elapsed_msec(), 0, "新预算应从注入时钟当前值开始。")
	assert_true(clock.advance_msec(10), "测试时钟应推进到预算边界。")
	assert_true(budget.check(), "等于最大耗时时仍应在预算内。")
	assert_true(clock.advance_msec(1), "测试时钟应推进越过预算边界。")
	assert_false(budget.check(), "超过最大耗时后应拒绝继续。")
	assert_eq(budget.get_violation_reason(), &"time_limit_exceeded", "耗时违规原因应稳定。")


func test_replacing_budget_clock_resets_measurement_domain() -> void:
	var first_clock: GFManualClock = GFManualClock.new(100000, 1000)
	var second_clock: GFManualClock = GFManualClock.new(900000, 2000)
	var budget: GFExecutionBudget = GFExecutionBudget.new({}, first_clock)
	assert_true(first_clock.advance_msec(25), "第一个时钟应推进。")
	assert_eq(budget.get_elapsed_msec(), 25, "预算应读取第一个时钟。")

	assert_true(budget.set_clock(second_clock), "预算应接受新时钟并重置。")
	assert_same(budget.get_clock(), second_clock, "预算应持有新时钟。")
	assert_eq(budget.get_elapsed_msec(), 0, "替换时钟后不得跨时间域计算耗时。")
