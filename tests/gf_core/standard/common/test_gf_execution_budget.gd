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
