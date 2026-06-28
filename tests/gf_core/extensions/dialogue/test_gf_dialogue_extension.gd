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


func test_dialogue_runner_rejects_invalid_snapshot_schema_and_wrong_resource() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	resource.metadata = { "resource": "original" }
	resource.set_line(_make_text_line(&"start", "Start", &""))

	var context: GFDialogueContext = GFDialogueContext.new()
	var _context_with_score: GFDialogueContext = context.set_value(&"score", 7)
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _start_line: GFDialogueLine = runner.start(resource, &"", context)
	var snapshot: Dictionary = runner.create_runtime_snapshot()

	var bad_schema: Dictionary = snapshot.duplicate(true)
	bad_schema["schema_version"] = 999
	var bad_schema_runner: GFDialogueRunner = GFDialogueRunner.new()
	var bad_schema_line: GFDialogueLine = bad_schema_runner.restore_runtime_snapshot(resource, bad_schema)

	var wrong_resource: GFDialogueResource = GFDialogueResource.new()
	wrong_resource.start_line_id = &"start"
	wrong_resource.metadata = { "resource": "other" }
	wrong_resource.set_line(_make_text_line(&"start", "Start", &""))
	var wrong_resource_runner: GFDialogueRunner = GFDialogueRunner.new()
	var wrong_resource_line: GFDialogueLine = wrong_resource_runner.restore_runtime_snapshot(wrong_resource, snapshot)

	assert_null(bad_schema_line, "未知 schema_version 的快照应被拒绝。")
	assert_false(bad_schema_runner.is_running(), "坏 schema 恢复后 Runner 应保持停止。")
	assert_null(wrong_resource_line, "同 ID 但不同资源内容的快照应被拒绝。")
	assert_false(wrong_resource_runner.is_running(), "资源不匹配恢复后 Runner 应保持停止。")


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


func test_dialogue_runner_treats_null_condition_result_as_blocked() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"locked"
	var locked: GFDialogueLine = _make_text_line(&"locked", "Locked", &"")
	locked.condition_id = &"can_enter"
	resource.set_line(locked)

	var context: GFDialogueContext = GFDialogueContext.new()
	context.condition_handler = func(_condition_id: StringName, _payload: Variant, _subject: Variant, _context: GFDialogueContext) -> Variant:
		return null

	var runner: GFDialogueRunner = GFDialogueRunner.new()
	watch_signals(runner)
	var line: GFDialogueLine = runner.start(resource, &"", context)

	assert_null(line, "条件处理器返回 null 时应失败闭合。")
	assert_false(runner.is_running(), "无法进入且无 fallback 时对话应结束。")
	assert_signal_emitted_with_parameters(runner, "line_blocked", [&"locked", &"line_condition_failed"])


func test_dialogue_runner_blocks_automatic_mutation_cycle_before_replay() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"loop"
	var mutation_line: GFDialogueLine = GFDialogueLine.new()
	mutation_line.line_id = &"loop"
	mutation_line.kind = GFDialogueLine.LineKind.MUTATION
	mutation_line.mutation_id = &"mark"
	mutation_line.next_line_id = &"loop"
	resource.set_line(mutation_line)

	var mutations: Array[StringName] = []
	var context: GFDialogueContext = GFDialogueContext.new()
	context.mutation_handler = func(mutation_id: StringName, _payload: Variant, _subject: Variant, _context: GFDialogueContext) -> bool:
		mutations.append(mutation_id)
		return true

	var runner: GFDialogueRunner = GFDialogueRunner.new()
	runner.max_steps_per_advance = 64
	watch_signals(runner)
	var line: GFDialogueLine = runner.start(resource, &"", context)

	assert_null(line, "自动 mutation 循环不应到达展示行。")
	assert_eq(mutations, [&"mark"], "检测到循环前 mutation side effect 只能执行一次。")
	assert_signal_emitted_with_parameters(runner, "line_blocked", [&"loop", &"automatic_cycle_detected"])


func test_dialogue_runner_blocks_failed_response_mutation_without_advancing() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	var start: GFDialogueLine = _make_text_line(&"start", "Start", &"done")
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"pick"
	response.next_line_id = &"done"
	response.mutation_id = &"grant"
	start.responses.append(response)
	resource.set_line(start)
	resource.set_line(_make_text_line(&"done", "Done", &""))

	var context: GFDialogueContext = GFDialogueContext.new()
	context.mutation_handler = func(_mutation_id: StringName, _payload: Variant, _subject: Variant, _context: GFDialogueContext) -> bool:
		return false

	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var first_line: GFDialogueLine = runner.start(resource, &"", context)
	watch_signals(runner)
	var next_line: GFDialogueLine = runner.choose_response(&"pick")

	assert_eq(first_line.line_id, &"start", "测试应先停在起始文本行。")
	assert_eq(next_line.line_id, &"start", "响应 mutation 失败时不应推进到下一行。")
	assert_signal_emitted_with_parameters(runner, "line_blocked", [&"start", &"response_mutation_failed"])


func test_dialogue_runner_blocks_failed_line_mutation() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	resource.set_line(_make_text_line(&"start", "Start", &"mark"))

	var mutation_line: GFDialogueLine = GFDialogueLine.new()
	mutation_line.line_id = &"mark"
	mutation_line.kind = GFDialogueLine.LineKind.MUTATION
	mutation_line.mutation_id = &"mark_seen"
	mutation_line.next_line_id = &"done"
	resource.set_line(mutation_line)
	resource.set_line(_make_text_line(&"done", "Done", &""))

	var context: GFDialogueContext = GFDialogueContext.new()
	context.mutation_handler = func(_mutation_id: StringName, _payload: Variant, _subject: Variant, _context: GFDialogueContext) -> bool:
		return false

	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _start_line: GFDialogueLine = runner.start(resource, &"", context)
	watch_signals(runner)
	var line: GFDialogueLine = runner.advance()

	assert_null(line, "mutation 行失败时不应继续进入后续文本行。")
	assert_false(runner.is_running(), "mutation 行失败时应结束当前推进。")
	assert_signal_emitted_with_parameters(runner, "line_blocked", [&"mark", &"line_mutation_failed"])


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


func test_dialogue_resource_validation_reports_response_identity_issues() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	var start: GFDialogueLine = _make_text_line(&"start", "Start", &"")

	var empty_response: GFDialogueResponse = GFDialogueResponse.new()
	empty_response.response_id = &""
	start.responses.append(empty_response)

	var first: GFDialogueResponse = GFDialogueResponse.new()
	first.response_id = &"same"
	start.responses.append(first)

	var duplicate_response: GFDialogueResponse = GFDialogueResponse.new()
	duplicate_response.response_id = &"same"
	start.responses.append(duplicate_response)
	start.responses.append(null)
	resource.set_line(start)

	var report: Dictionary = resource.validate_resource()
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "无效响应标识应导致校验失败。")
	assert_true(_has_issue_kind(issues, "empty_response_id"), "空响应 ID 应进入校验报告。")
	assert_true(_has_issue_kind(issues, "duplicate_response_id"), "重复响应 ID 应进入校验报告。")
	assert_true(_has_issue_kind(issues, "null_response"), "空响应槽位应进入校验报告。")


func test_dialogue_runner_line_blocked_uses_current_line_for_response_failures() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	var start: GFDialogueLine = _make_text_line(&"start", "Start", &"")
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"locked"
	response.condition_id = &"can_pick"
	start.responses.append(response)
	resource.set_line(start)

	var context: GFDialogueContext = GFDialogueContext.new()
	context.condition_handler = func(_condition_id: StringName, _payload: Variant, _subject: Variant, _context: GFDialogueContext) -> bool:
		return false

	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _start_line: GFDialogueLine = runner.start(resource, &"", context)
	watch_signals(runner)
	var line: GFDialogueLine = runner.choose_response(&"locked")

	assert_eq(line.line_id, &"start", "响应不可用时应停留在当前行。")
	assert_signal_emitted_with_parameters(runner, "line_blocked", [&"start", &"response_condition_failed"])


func test_dialogue_dictionary_snapshots_deep_copy_payloads() -> void:
	var line: GFDialogueLine = _make_text_line(&"start", "Start", &"")
	line.condition_payload = { "nested": { "value": 1 } }
	line.mutation_payload = { "nested": { "value": 2 } }
	line.tags = PackedStringArray(["original"])
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"pick"
	response.condition_payload = { "nested": { "value": 3 } }
	response.mutation_payload = { "nested": { "value": 4 } }
	response.tags = PackedStringArray(["response"])
	line.responses.append(response)

	var snapshot: Dictionary = line.to_dictionary()
	var condition_payload: Dictionary = GFVariantData.get_option_dictionary(snapshot, "condition_payload")
	var mutation_payload: Dictionary = GFVariantData.get_option_dictionary(snapshot, "mutation_payload")
	var responses: Array = GFVariantData.get_option_array(snapshot, "responses")
	var response_snapshot: Dictionary = GFVariantData.as_dictionary(responses[0])
	GFVariantData.get_option_dictionary(condition_payload, "nested")["value"] = 10
	GFVariantData.get_option_dictionary(mutation_payload, "nested")["value"] = 20
	GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(response_snapshot, "condition_payload"),
		"nested"
	)["value"] = 30
	GFVariantData.get_option_dictionary(
		GFVariantData.get_option_dictionary(response_snapshot, "mutation_payload"),
		"nested"
	)["value"] = 40

	var line_condition_payload: Dictionary = GFVariantData.as_dictionary(line.condition_payload)
	var line_mutation_payload: Dictionary = GFVariantData.as_dictionary(line.mutation_payload)
	var response_condition_payload: Dictionary = GFVariantData.as_dictionary(response.condition_payload)
	var response_mutation_payload: Dictionary = GFVariantData.as_dictionary(response.mutation_payload)

	assert_eq(GFVariantData.get_option_int(GFVariantData.get_option_dictionary(line_condition_payload, "nested"), "value"), 1, "行条件载荷快照不应反向修改资源。")
	assert_eq(GFVariantData.get_option_int(GFVariantData.get_option_dictionary(line_mutation_payload, "nested"), "value"), 2, "行 mutation 载荷快照不应反向修改资源。")
	assert_eq(GFVariantData.get_option_int(GFVariantData.get_option_dictionary(response_condition_payload, "nested"), "value"), 3, "响应条件载荷快照不应反向修改资源。")
	assert_eq(GFVariantData.get_option_int(GFVariantData.get_option_dictionary(response_mutation_payload, "nested"), "value"), 4, "响应 mutation 载荷快照不应反向修改资源。")


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


func _has_issue_kind(issues: Array, kind: String) -> bool:
	for issue: Variant in issues:
		var issue_dictionary: Dictionary = GFVariantData.as_dictionary(issue)
		if GFVariantData.get_option_string(issue_dictionary, "kind") == kind:
			return true
	return false
