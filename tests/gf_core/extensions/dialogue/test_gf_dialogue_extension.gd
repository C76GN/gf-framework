## 测试通用对话资源与运行器。
extends GutTest


# --- 测试方法 ---

## 验证对话运行器可处理响应、mutation 和文本行推进。
func test_dialogue_runner_advances_with_response_and_mutation() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	resource.set_line(_make_text_line(&"start", "Start", &""))

	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"next"
	response.next_line_id = &"mark"
	response.mutation_id = &"picked"
	resource.get_line(&"start").responses.append(response)

	var mutation_line: GFDialogueLine = GFDialogueLine.new()
	mutation_line.line_id = &"mark"
	mutation_line.kind = GFDialogueLine.LineKind.MUTATION
	mutation_line.mutation_id = &"mark_seen"
	mutation_line.next_line_id = &"done"
	resource.set_line(mutation_line)
	resource.set_line(_make_text_line(&"done", "Done", &"end"))
	resource.set_line(_make_end_line(&"end"))

	var mutations: Array[StringName] = []
	var context: GFDialogueContext = GFDialogueContext.new()
	context.mutation_handler = func(mutation_id: StringName, _payload: Variant, _subject: Variant, _context: GFDialogueContext) -> bool:
		mutations.append(mutation_id)
		return true

	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var first_line: GFDialogueLine = runner.start(resource, &"", context)
	var second_line: GFDialogueLine = runner.choose_response(&"next")

	assert_eq(first_line.line_id, &"start", "启动后应到达起始文本行。")
	assert_eq(second_line.line_id, &"done", "选择响应后应推进到下一条文本行。")
	assert_eq(mutations, [&"picked", &"mark_seen"], "响应与 mutation 行都应请求上下文处理。")


## 验证对话运行快照可恢复当前行且不会重放 mutation。
func test_dialogue_runner_restores_runtime_snapshot_without_replaying_mutation() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	resource.set_line(_make_text_line(&"start", "Start", &"mark"))

	var mutation_line: GFDialogueLine = GFDialogueLine.new()
	mutation_line.line_id = &"mark"
	mutation_line.kind = GFDialogueLine.LineKind.MUTATION
	mutation_line.mutation_id = &"mark_seen"
	mutation_line.next_line_id = &"done"
	resource.set_line(mutation_line)
	resource.set_line(_make_text_line(&"done", "Done", &"end"))
	resource.set_line(_make_end_line(&"end"))

	var mutations: Array[StringName] = []
	var context: GFDialogueContext = GFDialogueContext.new()
	var _context_with_visited: GFDialogueContext = context.set_value(&"visited", true)
	context.mutation_handler = func(
		mutation_id: StringName,
		_payload: Variant,
		_subject: Variant,
		mutation_context: GFDialogueContext
	) -> bool:
		mutations.append(mutation_id)
		var _mutation_context_updated: GFDialogueContext = mutation_context.set_value(&"mutation_count", mutations.size())
		return true

	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _start_line: GFDialogueLine = runner.start(resource, &"", context)
	var reached_line: GFDialogueLine = runner.advance()
	var snapshot: Dictionary = runner.create_runtime_snapshot()

	var restored_mutations: Array[StringName] = []
	var restored_context: GFDialogueContext = GFDialogueContext.new()
	restored_context.mutation_handler = func(
		mutation_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		restored_mutations.append(mutation_id)
		return true

	var restored_runner: GFDialogueRunner = GFDialogueRunner.new()
	var restored_line: GFDialogueLine = restored_runner.restore_runtime_snapshot(resource, snapshot, restored_context)

	assert_eq(reached_line.line_id, &"done", "测试应先推进到 mutation 后的文本行。")
	assert_eq(mutations, [&"mark_seen"], "原始推进应执行一次 mutation。")
	assert_eq(GFVariantData.get_option_int(snapshot, "schema_version"), GFDialogueRunner.SNAPSHOT_SCHEMA_VERSION, "快照应声明结构版本。")
	assert_eq(restored_line.line_id, &"done", "恢复后应回到快照中的当前文本行。")
	assert_eq(restored_runner.get_current_line(), restored_line, "恢复后的当前行应可直接读取。")
	assert_true(restored_runner.is_running(), "恢复到文本行后 Runner 应保持运行中。")
	assert_eq(GFVariantData.to_bool(restored_context.get_value(&"visited")), true, "恢复应带回上下文运行值。")
	assert_eq(GFVariantData.to_int(restored_context.get_value(&"mutation_count")), 1, "恢复应带回 mutation 已写入的上下文值。")
	assert_true(restored_mutations.is_empty(), "恢复快照不应重新执行 mutation。")


## 验证结束状态快照恢复后不会重新启动对话。
func test_dialogue_runner_restore_ended_snapshot_stays_stopped() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	resource.set_line(_make_text_line(&"start", "Start", &""))

	var context: GFDialogueContext = GFDialogueContext.new()
	var _context_with_score: GFDialogueContext = context.set_value(&"score", 7)

	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _start_line: GFDialogueLine = runner.start(resource, &"", context)
	var _end_result: GFDialogueLine = runner.advance()
	var snapshot: Dictionary = runner.create_runtime_snapshot()

	var restored_context: GFDialogueContext = GFDialogueContext.new()
	var restored_runner: GFDialogueRunner = GFDialogueRunner.new()
	var restored_line: GFDialogueLine = restored_runner.restore_runtime_snapshot(resource, snapshot, restored_context)

	assert_null(restored_line, "已结束快照不应恢复出当前行。")
	assert_false(restored_runner.is_running(), "已结束快照恢复后 Runner 应保持停止。")
	assert_null(restored_runner.get_current_line(), "已结束快照恢复后不应保留当前行。")
	assert_eq(GFVariantData.to_int(restored_context.get_value(&"score")), 7, "即使对话已结束，也应恢复上下文值供项目存档使用。")


## 验证对话运行器在条件失败时可走 fallback。
func test_dialogue_runner_uses_fallback_when_condition_fails() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	resource.set_line(_make_text_line(&"start", "Start", &"locked"))

	var locked: GFDialogueLine = _make_text_line(&"locked", "Locked", &"")
	locked.condition_id = &"can_enter"
	locked.fallback_line_id = &"fallback"
	resource.set_line(locked)
	resource.set_line(_make_text_line(&"fallback", "Fallback", &""))

	var context: GFDialogueContext = GFDialogueContext.new()
	context.condition_handler = func(_condition_id: StringName, _payload: Variant, _subject: Variant, _context: GFDialogueContext) -> bool:
		return false

	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _start_result_60: Variant = runner.start(resource, &"", context)
	var line: GFDialogueLine = runner.advance()

	assert_eq(line.line_id, &"fallback", "条件失败且存在 fallback 时应跳到 fallback 行。")


## 验证对话资源校验会报告缺失后继。
func test_dialogue_resource_validation_reports_missing_next_line() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.set_line(_make_text_line(&"start", "Start", &"missing"))

	var report: Dictionary = resource.validate_resource()
	var diagnostics: Array[Dictionary] = GFValidationDiagnosticAdapter.report_to_diagnostics(report)
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])
	var first_diagnostic: Dictionary = diagnostics[0]

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失后继应导致校验失败。")
	assert_eq(GFVariantData.get_option_string(first_issue, "kind"), "missing_next_line", "校验报告应写入标准 kind。")
	assert_false(first_issue.has("issue_id"), "校验报告不应再输出旧 issue_id 字段。")
	assert_eq(GFVariantData.get_option_int(report, "error_count"), 1, "标准报告应统计错误数量。")
	assert_eq(GFVariantData.get_option_int(report, "issue_count"), 1, "标准报告应统计问题总数。")
	assert_eq(GFVariantData.get_option_string(first_diagnostic, "kind"), "missing_next_line", "对话校验报告应可转换为通用诊断。")


## 验证对话资源校验会报告无效起始行。
func test_dialogue_resource_validation_reports_missing_start_line() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"missing_start"
	resource.set_line(_make_text_line(&"start", "Start", &""))

	var report: Dictionary = resource.validate_resource()
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var first_issue: Dictionary = GFVariantData.as_dictionary(issues[0])

	assert_false(GFVariantData.get_option_bool(report, "ok"), "缺失起始行应导致校验失败。")
	assert_eq(GFVariantData.get_option_string(first_issue, "kind"), "missing_start_line", "校验报告应标明缺失起始行。")
	assert_true(GFVariantData.get_option_string(report, "next_action").contains("start_line_id"), "下一步建议应指向起始行配置。")


# --- 私有/辅助方法 ---

func _make_text_line(line_id: StringName, text: String, next_line_id: StringName) -> GFDialogueLine:
	var line: GFDialogueLine = GFDialogueLine.new()
	line.line_id = line_id
	line.kind = GFDialogueLine.LineKind.TEXT
	line.text = text
	line.next_line_id = next_line_id
	return line


func _make_end_line(line_id: StringName) -> GFDialogueLine:
	var line: GFDialogueLine = GFDialogueLine.new()
	line.line_id = line_id
	line.kind = GFDialogueLine.LineKind.END
	return line
