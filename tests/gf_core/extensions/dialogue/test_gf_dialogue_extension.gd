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


func test_dialogue_runner_emits_mutation_requested_for_response_mutation() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	var start: GFDialogueLine = _make_text_line(&"start", "Start", &"")
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"pick"
	response.next_line_id = &"done"
	response.mutation_id = &"grant"
	response.mutation_payload = { "amount": 2 }
	start.responses.append(response)
	resource.set_line(start)
	resource.set_line(_make_text_line(&"done", "Done", &""))

	var context: GFDialogueContext = GFDialogueContext.new()
	context.mutation_handler = func(
		_mutation_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		return true
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _start_line: GFDialogueLine = runner.start(resource, &"", context)
	watch_signals(runner)

	var reached: GFDialogueLine = runner.choose_response(&"pick")

	assert_eq(reached.line_id, &"done", "响应 mutation 成功后应继续推进。")
	assert_signal_emitted_with_parameters(
		runner,
		"mutation_requested",
		[&"grant", { "amount": 2 }, start]
	)


func test_dialogue_runner_snapshot_requires_a_restorable_session_state() -> void:
	var idle_runner: GFDialogueRunner = GFDialogueRunner.new()
	var idle_snapshot: Dictionary = idle_runner.create_runtime_snapshot()

	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	resource.set_line(_make_text_line(&"start", "Start", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var started_snapshots: Array[Dictionary] = []
	var started_callback: Callable = func(_resource: GFDialogueResource) -> void:
		started_snapshots.append(runner.create_runtime_snapshot())
	var _started_connection_error: Error = runner.dialogue_started.connect(started_callback) as Error

	var reached: GFDialogueLine = runner.start(resource)
	if runner.dialogue_started.is_connected(started_callback):
		runner.dialogue_started.disconnect(started_callback)
	var stable_snapshot: Dictionary = runner.create_runtime_snapshot()
	var restored_runner: GFDialogueRunner = GFDialogueRunner.new()
	var restored: GFDialogueLine = restored_runner.restore_runtime_snapshot(
		resource,
		stable_snapshot
	)

	assert_true(idle_snapshot.is_empty(), "未开始过会话时没有可恢复资源身份，不得返回成功快照。")
	assert_eq(started_snapshots.size(), 1, "dialogue_started 应同步观察一次快照创建结果。")
	assert_true(_single_snapshot_is_empty(started_snapshots), "dialogue_started 仍在推进起点，不得返回成功快照。")
	assert_not_null(reached, "测试资源应到达稳定 TEXT checkpoint。")
	assert_false(stable_snapshot.is_empty(), "稳定 TEXT checkpoint 应继续返回兼容快照。")
	var expected_snapshot_keys: Array[String] = [
		"schema_version",
		"is_running",
		"current_line_id",
		"resource_fingerprint",
		"context_values",
	]
	assert_eq(stable_snapshot.size(), expected_snapshot_keys.size(), "成功快照必须保持既有精确五字段 schema。")
	for key: String in expected_snapshot_keys:
		assert_true(stable_snapshot.has(key), "成功快照缺少必需字段 %s。" % key)
	assert_not_null(restored, "每个成功创建的运行中快照都必须可恢复。")
	if restored != null:
		assert_eq(restored.line_id, &"start", "恢复后应回到成功快照的稳定 TEXT 行。")


func test_dialogue_runner_rejects_snapshot_during_line_mutation() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"mutate"
	var mutation_line: GFDialogueLine = GFDialogueLine.new()
	mutation_line.line_id = &"mutate"
	mutation_line.kind = GFDialogueLine.LineKind.MUTATION
	mutation_line.mutation_id = &"mark"
	mutation_line.next_line_id = &"done"
	resource.set_line(mutation_line)
	resource.set_line(_make_text_line(&"done", "Done", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var signal_snapshots: Array[Dictionary] = []
	var handler_snapshots: Array[Dictionary] = []
	var context: GFDialogueContext = GFDialogueContext.new()
	context.mutation_handler = func(
		_mutation_id: StringName,
		_payload: Variant,
		_subject: Variant,
		mutation_context: GFDialogueContext
	) -> bool:
		var _updated_context: GFDialogueContext = mutation_context.set_value(&"mutated", true)
		handler_snapshots.append(runner.create_runtime_snapshot())
		return true
	var mutation_callback: Callable = func(
		_mutation_id: StringName,
		_payload: Variant,
		_line: GFDialogueLine
	) -> void:
		signal_snapshots.append(runner.create_runtime_snapshot())
	var _mutation_connection_error: Error = runner.mutation_requested.connect(mutation_callback) as Error

	var reached: GFDialogueLine = runner.start(resource, &"", context)
	if runner.mutation_requested.is_connected(mutation_callback):
		runner.mutation_requested.disconnect(mutation_callback)
	context.mutation_handler = Callable()
	var stable_snapshot: Dictionary = runner.create_runtime_snapshot()
	var restored: GFDialogueLine = GFDialogueRunner.new().restore_runtime_snapshot(
		resource,
		stable_snapshot
	)

	assert_not_null(reached, "mutation 成功后应到达稳定 TEXT checkpoint。")
	assert_eq(signal_snapshots.size(), 1, "行 mutation signal 应同步观察一次快照创建结果。")
	assert_eq(handler_snapshots.size(), 1, "行 mutation handler 应同步观察一次快照创建结果。")
	assert_true(_single_snapshot_is_empty(signal_snapshots), "行 mutation signal 仍在推进中，不得返回成功快照。")
	assert_true(_single_snapshot_is_empty(handler_snapshots), "行 mutation handler 已有副作用但未提交 TEXT，不得返回成功快照。")
	assert_false(stable_snapshot.is_empty(), "mutation 后的稳定 TEXT checkpoint 应可创建快照。")
	assert_not_null(restored, "mutation 后成功创建的快照必须可恢复。")
	if restored != null:
		assert_eq(restored.line_id, &"done", "恢复不得回到已执行的 mutation 行。")


func test_dialogue_runner_rejects_snapshot_during_response_mutation() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	var start: GFDialogueLine = _make_text_line(&"start", "Start", &"")
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"pick"
	response.next_line_id = &"done"
	response.mutation_id = &"grant"
	start.responses.append(response)
	resource.set_line(start)
	resource.set_line(_make_text_line(&"done", "Done", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var signal_snapshots: Array[Dictionary] = []
	var handler_snapshots: Array[Dictionary] = []
	var context: GFDialogueContext = GFDialogueContext.new()
	context.mutation_handler = func(
		_mutation_id: StringName,
		_payload: Variant,
		_subject: Variant,
		mutation_context: GFDialogueContext
	) -> bool:
		var _updated_context: GFDialogueContext = mutation_context.set_value(&"granted", true)
		handler_snapshots.append(runner.create_runtime_snapshot())
		return true
	var _start_line: GFDialogueLine = runner.start(resource, &"", context)
	var mutation_callback: Callable = func(
		_mutation_id: StringName,
		_payload: Variant,
		_line: GFDialogueLine
	) -> void:
		signal_snapshots.append(runner.create_runtime_snapshot())
		var _nested_missing_response: GFDialogueLine = runner.advance(&"missing")
		signal_snapshots.append(runner.create_runtime_snapshot())
	var _mutation_connection_error: Error = runner.mutation_requested.connect(mutation_callback) as Error

	var reached: GFDialogueLine = runner.choose_response(&"pick")
	if runner.mutation_requested.is_connected(mutation_callback):
		runner.mutation_requested.disconnect(mutation_callback)
	context.mutation_handler = Callable()
	var stable_snapshot: Dictionary = runner.create_runtime_snapshot()
	var restored: GFDialogueLine = GFDialogueRunner.new().restore_runtime_snapshot(
		resource,
		stable_snapshot
	)

	assert_not_null(reached, "响应 mutation 成功后应到达稳定 TEXT checkpoint。")
	assert_eq(signal_snapshots.size(), 2, "响应 mutation signal 应在嵌套推进前后各观察一次快照创建结果。")
	assert_eq(handler_snapshots.size(), 1, "响应 mutation handler 应同步观察一次快照创建结果。")
	if signal_snapshots.size() == 2:
		assert_true(
			signal_snapshots[0].is_empty() and signal_snapshots[1].is_empty(),
			"响应 mutation signal 的嵌套推进返回后仍不得把旧 TEXT 误报为稳定 checkpoint。"
		)
	assert_true(_single_snapshot_is_empty(handler_snapshots), "响应 mutation handler 不能把已部分修改的旧 TEXT 持久化。")
	assert_false(stable_snapshot.is_empty(), "响应推进完成后的 TEXT checkpoint 应可创建快照。")
	assert_not_null(restored, "响应推进后成功创建的快照必须可恢复。")
	if restored != null:
		assert_eq(restored.line_id, &"done", "恢复不得回到 mutation 前的响应行。")


func test_dialogue_runner_rejects_snapshot_during_response_condition_evaluation() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	var start: GFDialogueLine = _make_text_line(&"start", "Start", &"")
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"pick"
	response.condition_id = &"can_pick"
	start.responses.append(response)
	resource.set_line(start)
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var condition_snapshots: Array[Dictionary] = []
	var context: GFDialogueContext = GFDialogueContext.new()
	context.condition_handler = func(
		_condition_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		condition_snapshots.append(runner.create_runtime_snapshot())
		return true
	var _start_line: GFDialogueLine = runner.start(resource, &"", context)
	condition_snapshots.clear()

	var blocked_line: GFDialogueLine = runner.advance()
	var query_snapshots: Array[Dictionary] = []
	context.condition_handler = func(
		_condition_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		query_snapshots.append(runner.create_runtime_snapshot())
		return true
	var available_responses: Array[GFDialogueResponse] = runner.get_available_responses()
	context.condition_handler = Callable()
	var stable_snapshot: Dictionary = runner.create_runtime_snapshot()
	var query_restored: GFDialogueLine = null
	if query_snapshots.size() == 1:
		query_restored = GFDialogueRunner.new().restore_runtime_snapshot(
			resource,
			query_snapshots[0]
		)
	var restored: GFDialogueLine = GFDialogueRunner.new().restore_runtime_snapshot(
		resource,
		stable_snapshot
	)

	assert_not_null(blocked_line, "缺少 response_id 时应继续停在当前 TEXT。")
	assert_eq(condition_snapshots.size(), 1, "response condition 应在 advance 内同步评估一次。")
	assert_true(_single_snapshot_is_empty(condition_snapshots), "response condition 评估仍属于 advance 窗口，不得返回成功快照。")
	assert_eq(available_responses.size(), 1, "独立响应查询应继续返回稳定 checkpoint 的可用响应。")
	assert_true(_single_snapshot_is_non_empty(query_snapshots), "独立响应查询不推进会话，应允许 condition handler 保存当前 checkpoint。")
	assert_not_null(query_restored, "独立响应查询回调内创建的成功快照必须可恢复。")
	if query_restored != null:
		assert_eq(query_restored.line_id, &"start", "独立响应查询快照应保持当前稳定 TEXT。")
	assert_false(stable_snapshot.is_empty(), "advance 返回后的原 TEXT 应恢复为稳定 checkpoint。")
	assert_not_null(restored, "稳定 response checkpoint 快照必须可恢复。")
	if restored != null:
		assert_eq(restored.line_id, &"start", "恢复应回到等待响应的 TEXT 行。")


func test_dialogue_runner_line_reached_snapshot_is_immediately_restorable() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	resource.set_line(_make_text_line(&"start", "Start", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var reached_snapshots: Array[Dictionary] = []
	var reached_callback: Callable = func(_line: GFDialogueLine) -> void:
		reached_snapshots.append(runner.create_runtime_snapshot())
	var _reached_connection_error: Error = runner.line_reached.connect(reached_callback) as Error

	var reached: GFDialogueLine = runner.start(resource)
	if runner.line_reached.is_connected(reached_callback):
		runner.line_reached.disconnect(reached_callback)
	var restored: GFDialogueLine = null
	if reached_snapshots.size() == 1:
		restored = GFDialogueRunner.new().restore_runtime_snapshot(
			resource,
			reached_snapshots[0]
		)

	assert_not_null(reached, "测试资源应发出稳定 line_reached。")
	assert_eq(reached_snapshots.size(), 1, "line_reached 应同步创建一次快照。")
	assert_true(_single_snapshot_is_non_empty(reached_snapshots), "line_reached 已发布稳定 TEXT，应允许立即存档。")
	assert_not_null(restored, "line_reached 内成功创建的快照必须立即可恢复。")
	if restored != null:
		assert_eq(restored.line_id, &"start", "line_reached 快照应恢复到刚发布的 TEXT 行。")


func test_dialogue_runner_nested_transition_cannot_reuse_outer_checkpoint_publication() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	var start: GFDialogueLine = _make_text_line(&"start", "Start", &"")
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"pick"
	response.next_line_id = &"done"
	response.mutation_id = &"grant"
	start.responses.append(response)
	resource.set_line(start)
	resource.set_line(_make_text_line(&"done", "Done", &""))
	var context: GFDialogueContext = GFDialogueContext.new()
	context.mutation_handler = func(
		_mutation_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		return true
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var reached_snapshots: Array[Dictionary] = []
	var mutation_snapshots: Array[Dictionary] = []
	var post_nested_snapshots: Array[Dictionary] = []
	var reached_callback: Callable = func(line: GFDialogueLine) -> void:
		reached_snapshots.append(runner.create_runtime_snapshot())
		if line.line_id == &"start":
			var _nested_line: GFDialogueLine = runner.choose_response(&"pick")
			post_nested_snapshots.append(runner.create_runtime_snapshot())
	var mutation_callback: Callable = func(
		_mutation_id: StringName,
		_payload: Variant,
		_line: GFDialogueLine
	) -> void:
		mutation_snapshots.append(runner.create_runtime_snapshot())
	var _reached_connection_error: Error = runner.line_reached.connect(reached_callback) as Error
	var _mutation_connection_error: Error = runner.mutation_requested.connect(mutation_callback) as Error

	var outer_result: GFDialogueLine = runner.start(resource, &"", context)
	if runner.line_reached.is_connected(reached_callback):
		runner.line_reached.disconnect(reached_callback)
	if runner.mutation_requested.is_connected(mutation_callback):
		runner.mutation_requested.disconnect(mutation_callback)
	context.mutation_handler = Callable()
	var first_restored: GFDialogueLine = null
	var second_restored: GFDialogueLine = null
	var post_nested_restored: GFDialogueLine = null
	if reached_snapshots.size() == 2:
		first_restored = GFDialogueRunner.new().restore_runtime_snapshot(
			resource,
			reached_snapshots[0]
		)
		second_restored = GFDialogueRunner.new().restore_runtime_snapshot(
			resource,
			reached_snapshots[1]
		)
	if post_nested_snapshots.size() == 1:
		post_nested_restored = GFDialogueRunner.new().restore_runtime_snapshot(
			resource,
			post_nested_snapshots[0]
		)

	assert_null(outer_result, "line_reached 内替换当前行后，外层 start 应返回 stale null。")
	assert_eq(reached_snapshots.size(), 2, "外层与嵌套 line_reached 都应发布一次稳定 checkpoint。")
	assert_true(
		reached_snapshots.size() == 2
		and not reached_snapshots[0].is_empty()
		and not reached_snapshots[1].is_empty(),
		"每层 line_reached publication 都应允许自己的稳定 TEXT 快照。"
	)
	assert_true(_single_snapshot_is_empty(mutation_snapshots), "嵌套 response mutation 不得借用外层 publication 绕过推进守卫。")
	assert_true(_single_snapshot_is_non_empty(post_nested_snapshots), "嵌套推进返回后应恢复外层 publication 的稳定快照权限。")
	assert_not_null(first_restored, "外层已发布的 start checkpoint 应独立可恢复。")
	assert_not_null(second_restored, "嵌套已发布的 done checkpoint 应独立可恢复。")
	assert_not_null(post_nested_restored, "嵌套推进返回后的 done checkpoint 必须可恢复。")
	if first_restored != null:
		assert_eq(first_restored.line_id, &"start")
	if second_restored != null:
		assert_eq(second_restored.line_id, &"done")
	if post_nested_restored != null:
		assert_eq(post_nested_restored.line_id, &"done")
	var current_line: GFDialogueLine = runner.get_current_line()
	assert_not_null(current_line, "嵌套推进后的 live Runner 应保留新 TEXT。")
	if current_line != null:
		assert_eq(current_line.line_id, &"done", "嵌套推进后的 live Runner 应停在新 TEXT。")


func test_dialogue_runner_dialogue_ended_snapshot_is_immediately_restorable() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	resource.set_line(_make_text_line(&"start", "Start", &"end"))
	resource.set_line(_make_end_line(&"end"))
	var context: GFDialogueContext = GFDialogueContext.new()
	var _context_with_score: GFDialogueContext = context.set_value(&"score", 9)
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _start_line: GFDialogueLine = runner.start(resource, &"", context)
	var ended_snapshots: Array[Dictionary] = []
	var ended_callback: Callable = func(_resource: GFDialogueResource) -> void:
		ended_snapshots.append(runner.create_runtime_snapshot())
	var _ended_connection_error: Error = runner.dialogue_ended.connect(ended_callback) as Error

	var ended_line: GFDialogueLine = runner.advance()
	if runner.dialogue_ended.is_connected(ended_callback):
		runner.dialogue_ended.disconnect(ended_callback)
	var restored_context: GFDialogueContext = GFDialogueContext.new()
	var restored_runner: GFDialogueRunner = GFDialogueRunner.new()
	var restored: GFDialogueLine = null
	if ended_snapshots.size() == 1:
		restored = restored_runner.restore_runtime_snapshot(
			resource,
			ended_snapshots[0],
			restored_context
		)

	assert_null(ended_line, "END 行应正常结束当前会话。")
	assert_true(_single_snapshot_is_non_empty(ended_snapshots), "dialogue_ended 已发布 stopped checkpoint，应允许立即存档。")
	assert_null(restored, "ended snapshot 恢复后不应产生当前行。")
	assert_false(restored_runner.is_running(), "ended snapshot 恢复后 Runner 应保持停止。")
	assert_eq(GFVariantData.to_int(restored_context.get_value(&"score")), 9, "ended snapshot 应保留结束时上下文。")


func test_dialogue_runner_rejects_inconsistent_text_checkpoint_snapshots() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	var original_line: GFDialogueLine = _make_text_line(&"start", "Start", &"")
	resource.set_line(original_line)
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _reached: GFDialogueLine = runner.start(resource)

	original_line.kind = GFDialogueLine.LineKind.JUMP
	var wrong_kind_snapshot: Dictionary = runner.create_runtime_snapshot()
	original_line.kind = GFDialogueLine.LineKind.TEXT
	original_line.line_id = &"other"
	var wrong_id_snapshot: Dictionary = runner.create_runtime_snapshot()
	original_line.line_id = &"start"
	resource.set_line(_make_text_line(&"start", "Start", &""))
	var replaced_line_snapshot: Dictionary = runner.create_runtime_snapshot()

	assert_true(wrong_kind_snapshot.is_empty(), "非 TEXT 当前行不得形成运行中快照。")
	assert_true(wrong_id_snapshot.is_empty(), "当前行 ID 与游标不一致时不得形成运行中快照。")
	assert_true(replaced_line_snapshot.is_empty(), "资源同 ID 行实例已被替换时不得持久化旧 checkpoint。")


func test_dialogue_runner_rejects_snapshot_after_resource_identity_changes() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	var start_line: GFDialogueLine = _make_text_line(&"start", "Start", &"end")
	resource.set_line(start_line)
	resource.set_line(_make_end_line(&"end"))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _reached: GFDialogueLine = runner.start(resource)

	start_line.text = "Changed while running"
	var running_drift_snapshot: Dictionary = runner.create_runtime_snapshot()
	start_line.text = "Start"
	var _ended: GFDialogueLine = runner.advance()
	var stable_ended_snapshot: Dictionary = runner.create_runtime_snapshot()
	start_line.text = "Changed after end"
	var ended_drift_snapshot: Dictionary = runner.create_runtime_snapshot()
	start_line.text = "Start"
	var restored_ended_runner: GFDialogueRunner = GFDialogueRunner.new()
	var _restored_ended: GFDialogueLine = restored_ended_runner.restore_runtime_snapshot(
		resource,
		stable_ended_snapshot
	)
	var restored_ended_stable_snapshot: Dictionary = restored_ended_runner.create_runtime_snapshot()
	start_line.text = "Changed after ended restore"
	var restored_ended_drift_snapshot: Dictionary = restored_ended_runner.create_runtime_snapshot()

	assert_true(running_drift_snapshot.is_empty(), "运行中资源内容身份漂移后不得返回旧 fingerprint 快照。")
	assert_false(stable_ended_snapshot.is_empty(), "资源内容未漂移的停止状态应继续可存档。")
	assert_true(ended_drift_snapshot.is_empty(), "停止后资源内容身份漂移也不得返回旧 fingerprint 快照。")
	assert_false(restored_ended_stable_snapshot.is_empty(), "恢复停止快照后必须保留可复核的资源身份。")
	assert_true(restored_ended_drift_snapshot.is_empty(), "恢复停止快照后仍必须复核当前资源内容身份。")


func test_dialogue_replacement_start_revalidates_resource_after_ended_callbacks() -> void:
	var original: GFDialogueResource = GFDialogueResource.new()
	original.start_line_id = &"original"
	original.set_line(_make_text_line(&"original", "Original", &""))
	var replacement: GFDialogueResource = GFDialogueResource.new()
	replacement.start_line_id = &"replacement"
	var replacement_line: GFDialogueLine = _make_text_line(
		&"replacement",
		"Replacement",
		&""
	)
	replacement.set_line(replacement_line)
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _original_line: GFDialogueLine = runner.start(original)
	var ended_callback: Callable = func(_resource: GFDialogueResource) -> void:
		replacement_line.text = "Changed by old dialogue_ended"
	var _ended_connection_error: Error = runner.dialogue_ended.connect(ended_callback) as Error

	var reached: GFDialogueLine = runner.start(replacement)
	if runner.dialogue_ended.is_connected(ended_callback):
		runner.dialogue_ended.disconnect(ended_callback)
	var snapshot: Dictionary = runner.create_runtime_snapshot()
	var restored: GFDialogueLine = GFDialogueRunner.new().restore_runtime_snapshot(
		replacement,
		snapshot
	)

	assert_not_null(reached, "替换 start 应采用旧会话 ended 回调后的资源内容。")
	assert_false(snapshot.is_empty(), "替换 start 不得缓存 ended 回调前的陈旧资源 fingerprint。")
	assert_not_null(restored, "替换 start 返回后的成功快照必须可恢复。")
	if restored != null:
		assert_eq(restored.line_id, &"replacement")


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
	var _restored_end_result: GFDialogueLine = restored_runner.advance()
	var restored_ended_snapshot: Dictionary = restored_runner.create_runtime_snapshot()
	assert_false(restored_ended_snapshot.is_empty(), "恢复运行快照后正常结束仍应保留可存档资源身份。")


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


func test_dialogue_runner_rejects_ended_snapshot_for_another_resource_atomically() -> void:
	var snapshot_resource: GFDialogueResource = GFDialogueResource.new()
	snapshot_resource.start_line_id = &"snapshot"
	snapshot_resource.set_line(_make_text_line(&"snapshot", "Snapshot", &""))
	var snapshot_context: GFDialogueContext = GFDialogueContext.new()
	var _snapshot_score: GFDialogueContext = snapshot_context.set_value(&"score", 99)
	var snapshot_runner: GFDialogueRunner = GFDialogueRunner.new()
	var _snapshot_start: GFDialogueLine = snapshot_runner.start(snapshot_resource, &"", snapshot_context)
	var _snapshot_end: GFDialogueLine = snapshot_runner.advance()
	var ended_snapshot: Dictionary = snapshot_runner.create_runtime_snapshot()

	var active_resource: GFDialogueResource = GFDialogueResource.new()
	active_resource.start_line_id = &"active"
	active_resource.set_line(_make_text_line(&"active", "Active", &""))
	var active_context: GFDialogueContext = GFDialogueContext.new()
	var _active_score: GFDialogueContext = active_context.set_value(&"score", 1)
	var active_runner: GFDialogueRunner = GFDialogueRunner.new()
	var active_line: GFDialogueLine = active_runner.start(active_resource, &"", active_context)

	var restored: GFDialogueLine = active_runner.restore_runtime_snapshot(
		active_resource,
		ended_snapshot,
		active_context
	)

	assert_null(restored, "跨资源 ended snapshot 应被拒绝。")
	assert_true(active_runner.is_running(), "拒绝 ended snapshot 后原对话应继续运行。")
	assert_eq(active_runner.get_current_line(), active_line, "拒绝恢复不应替换当前行。")
	assert_eq(GFVariantData.to_int(active_context.get_value(&"score")), 1, "拒绝恢复不应污染上下文。")


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


func test_dialogue_runner_rejects_invalid_snapshot_without_mutating_existing_state_or_context() -> void:
	var original_resource: GFDialogueResource = GFDialogueResource.new()
	original_resource.start_line_id = &"start"
	original_resource.metadata = { "resource": "original" }
	original_resource.set_line(_make_text_line(&"start", "Start", &""))
	var wrong_resource: GFDialogueResource = GFDialogueResource.new()
	wrong_resource.start_line_id = &"start"
	wrong_resource.metadata = { "resource": "wrong" }
	wrong_resource.set_line(_make_text_line(&"start", "Start", &""))
	var snapshot_context: GFDialogueContext = GFDialogueContext.new()
	var _snapshot_context_value: GFDialogueContext = snapshot_context.set_value(&"score", 99)
	var snapshot_runner: GFDialogueRunner = GFDialogueRunner.new()
	var _snapshot_line: GFDialogueLine = snapshot_runner.start(original_resource, &"", snapshot_context)
	var snapshot: Dictionary = snapshot_runner.create_runtime_snapshot()
	var active_context: GFDialogueContext = GFDialogueContext.new()
	var _active_context_value: GFDialogueContext = active_context.set_value(&"score", 1)
	var active_runner: GFDialogueRunner = GFDialogueRunner.new()
	var active_line: GFDialogueLine = active_runner.start(wrong_resource, &"", active_context)

	var restored_line: GFDialogueLine = active_runner.restore_runtime_snapshot(wrong_resource, snapshot, active_context)

	assert_null(restored_line, "资源指纹不匹配时恢复应失败。")
	assert_true(active_runner.is_running(), "恢复失败不应清空原本正在运行的对话。")
	assert_eq(active_runner.get_current_line(), active_line, "恢复失败不应替换当前行。")
	assert_eq(GFVariantData.to_int(active_context.get_value(&"score")), 1, "恢复失败不应把快照上下文写入调用方 context。")


func test_dialogue_snapshot_uses_hash_fingerprint_and_json_safe_context_values() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	resource.set_line(_make_text_line(&"start", "Secret Line", &""))
	var context: GFDialogueContext = GFDialogueContext.new()
	var _context_value: GFDialogueContext = context.set_value(&"heat", NAN)
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _start_line: GFDialogueLine = runner.start(resource, &"", context)

	var snapshot: Dictionary = runner.create_runtime_snapshot()
	var snapshot_text: String = JSON.stringify(snapshot)
	var fingerprint: String = GFVariantData.get_option_string(snapshot, "resource_fingerprint")

	assert_eq(fingerprint.length(), 64, "资源指纹应是固定长度 digest。")
	assert_false(fingerprint.contains("Secret Line"), "资源指纹不应把对话正文泄漏进存档快照。")
	assert_true(snapshot_text.contains("__gf_variant__"), "非 JSON 原生上下文值应编码为 GF Variant 标记，避免 JSON.stringify NaN warning。")


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


func test_dialogue_runner_allows_condition_to_exit_automatic_back_edge() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"loop"
	var loop: GFDialogueLine = GFDialogueLine.new()
	loop.line_id = &"loop"
	loop.kind = GFDialogueLine.LineKind.MUTATION
	loop.condition_id = &"continue"
	loop.mutation_id = &"increment"
	loop.next_line_id = &"loop"
	loop.fallback_line_id = &"done"
	resource.set_line(loop)
	resource.set_line(_make_text_line(&"done", "Done", &""))

	var mutation_count: Array[int] = [0]
	var context: GFDialogueContext = GFDialogueContext.new()
	context.condition_handler = func(
		_condition_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		return mutation_count[0] == 0
	context.mutation_handler = func(
		_mutation_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		mutation_count[0] += 1
		return true
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	watch_signals(runner)

	var reached: GFDialogueLine = runner.start(resource, &"", context)

	assert_not_null(reached, "条件回边应通过 fallback 到达展示行。")
	if reached != null:
		assert_eq(reached.line_id, &"done", "重复自动行应先重新评估条件并允许 fallback 退出。")
	assert_eq(mutation_count[0], 1, "退出自动回边前 mutation 只能执行一次。")


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


func test_dialogue_runner_requires_available_response_before_default_advance() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	var start: GFDialogueLine = _make_text_line(&"start", "Start", &"done")
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"pick"
	response.next_line_id = &"done"
	start.responses.append(response)
	resource.set_line(start)
	resource.set_line(_make_text_line(&"done", "Done", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var start_line: GFDialogueLine = runner.start(resource)
	watch_signals(runner)

	var line: GFDialogueLine = runner.advance()

	assert_eq(line, start_line, "当前行存在可用响应时，空 advance 不应绕过选择。")
	assert_signal_emitted_with_parameters(runner, "line_blocked", [&"start", &"response_required"])


func test_dialogue_runner_blocks_choice_when_all_responses_are_unavailable() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	var start: GFDialogueLine = _make_text_line(&"start", "Start", &"done")
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"locked"
	response.condition_id = &"can_choose"
	response.next_line_id = &"done"
	start.responses.append(response)
	resource.set_line(start)
	resource.set_line(_make_text_line(&"done", "Done", &""))
	var context: GFDialogueContext = GFDialogueContext.new()
	context.condition_handler = func(
		_condition_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		return false
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var start_line: GFDialogueLine = runner.start(resource, &"", context)
	watch_signals(runner)

	var reached: GFDialogueLine = runner.advance()

	assert_eq(reached, start_line, "配置了响应的选择行不应在响应全部不可用时静默推进。")
	assert_signal_emitted_with_parameters(runner, "line_blocked", [&"start", &"no_available_response"])


func test_dialogue_runner_blocked_jump_uses_continuation_instead_of_guarded_target() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"guard"
	var guard: GFDialogueLine = GFDialogueLine.new()
	guard.line_id = &"guard"
	guard.kind = GFDialogueLine.LineKind.JUMP
	guard.condition_id = &"allowed"
	guard.jump_line_id = &"secret"
	guard.next_line_id = &"public"
	resource.set_line(guard)
	resource.set_line(_make_text_line(&"secret", "Secret", &""))
	resource.set_line(_make_text_line(&"public", "Public", &""))
	var context: GFDialogueContext = GFDialogueContext.new()
	context.condition_handler = func(
		_condition_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		return false
	var runner: GFDialogueRunner = GFDialogueRunner.new()

	var reached: GFDialogueLine = runner.start(resource, &"", context)

	assert_eq(reached.line_id, &"public", "JUMP 条件失败时不能沿受保护的 jump_line_id 前进。")


func test_dialogue_runner_reports_missing_runtime_line() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"start"
	resource.set_line(_make_text_line(&"start", "Start", &"missing"))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _start_line: GFDialogueLine = runner.start(resource)
	watch_signals(runner)

	var line: GFDialogueLine = runner.advance()

	assert_null(line, "运行时缺失后继行时应结束。")
	assert_signal_emitted_with_parameters(runner, "line_blocked", [&"missing", &"missing_line"])


func test_dialogue_resource_validation_reports_automatic_cycles() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"jump_a"
	var jump_a: GFDialogueLine = GFDialogueLine.new()
	jump_a.line_id = &"jump_a"
	jump_a.kind = GFDialogueLine.LineKind.JUMP
	jump_a.jump_line_id = &"jump_b"
	var jump_b: GFDialogueLine = GFDialogueLine.new()
	jump_b.line_id = &"jump_b"
	jump_b.kind = GFDialogueLine.LineKind.JUMP
	jump_b.jump_line_id = &"jump_a"
	resource.set_line(jump_a)
	resource.set_line(jump_b)

	var report: Dictionary = resource.validate_resource()
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "自动 JUMP/MUTATION 循环应在资源校验阶段失败。")
	assert_true(_has_issue_kind(issues, "automatic_cycle"), "自动循环应进入校验报告。")
	assert_eq(_count_issue_kind(issues, "automatic_cycle"), 1, "同一个自动循环只应生成一条稳定诊断。")


func test_dialogue_resource_validation_allows_conditionally_exitable_automatic_cycle() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"loop"
	var loop: GFDialogueLine = GFDialogueLine.new()
	loop.line_id = &"loop"
	loop.kind = GFDialogueLine.LineKind.MUTATION
	loop.condition_id = &"continue"
	loop.mutation_id = &"increment"
	loop.next_line_id = &"loop"
	loop.fallback_line_id = &"done"
	resource.set_line(loop)
	resource.set_line(_make_text_line(&"done", "Done", &""))

	var report: Dictionary = resource.validate_resource()
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(_has_issue_kind(issues, "automatic_cycle"), "带条件退出边的自动回边不应被静态判为无条件循环。")


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


func test_dialogue_dictionary_snapshots_bound_cycles_and_depth() -> void:
	var cyclic_payload: Dictionary = {}
	cyclic_payload["self"] = cyclic_payload
	var deep_payload: Dictionary = {}
	var cursor: Dictionary = deep_payload
	for depth: int in range(40):
		var child: Dictionary = { "depth": depth }
		cursor["child"] = child
		cursor = child
	var line: GFDialogueLine = _make_text_line(&"start", "Start", &"")
	line.condition_payload = cyclic_payload
	line.mutation_payload = deep_payload

	var snapshot: Dictionary = line.to_dictionary()
	var cyclic_snapshot: Dictionary = GFVariantData.get_option_dictionary(snapshot, "condition_payload")
	var deep_snapshot: Dictionary = GFVariantData.get_option_dictionary(snapshot, "mutation_payload")

	assert_eq(GFVariantData.get_option_string(cyclic_snapshot, "self"), "<circular_reference>", "循环载荷应被稳定截断。")
	assert_true(_dictionary_contains_value(deep_snapshot, "<max_depth>"), "超深载荷应在固定预算内截断。")


func test_dialogue_response_mutation_reentry_preserves_replacement_session() -> void:
	var original: GFDialogueResource = GFDialogueResource.new()
	original.start_line_id = &"start"
	var start_line: GFDialogueLine = _make_text_line(&"start", "Start", &"")
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"pick"
	response.mutation_id = &"replace_session"
	response.next_line_id = &"old_done"
	start_line.responses.append(response)
	original.set_line(start_line)
	original.set_line(_make_text_line(&"old_done", "Old", &""))
	var replacement: GFDialogueResource = GFDialogueResource.new()
	replacement.start_line_id = &"replacement"
	replacement.set_line(_make_text_line(&"replacement", "Replacement", &""))
	var context: GFDialogueContext = GFDialogueContext.new()
	var mutation_call_count: Array[int] = [0]
	context.mutation_handler = func(
		_mutation_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		mutation_call_count[0] += 1
		return true
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var replaced: Array[bool] = [false]
	var replacement_snapshots: Array[Dictionary] = []
	var post_start_snapshots: Array[Dictionary] = []
	var line_reached_callback: Callable = func(line: GFDialogueLine) -> void:
		if line.line_id == &"replacement":
			replacement_snapshots.append(runner.create_runtime_snapshot())
	var mutation_requested_callback: Callable = (
		func(_mutation_id: StringName, _payload: Variant, _line: GFDialogueLine) -> void:
			if replaced[0]:
				return
			replaced[0] = true
			var _replacement_line: GFDialogueLine = runner.start(replacement)
			post_start_snapshots.append(runner.create_runtime_snapshot())
	)
	var _connected: Error = runner.mutation_requested.connect(
		mutation_requested_callback
	) as Error
	var _line_reached_connected: Error = runner.line_reached.connect(
		line_reached_callback
	) as Error
	var _original_line: GFDialogueLine = runner.start(original, &"", context)

	var stale_result: GFDialogueLine = runner.choose_response(&"pick")
	runner.mutation_requested.disconnect(mutation_requested_callback)
	runner.line_reached.disconnect(line_reached_callback)
	context.mutation_handler = Callable()
	var restored_replacement: GFDialogueLine = null
	var restored_post_start: GFDialogueLine = null
	if replacement_snapshots.size() == 1:
		restored_replacement = GFDialogueRunner.new().restore_runtime_snapshot(
			replacement,
			replacement_snapshots[0]
		)
	if post_start_snapshots.size() == 1:
		restored_post_start = GFDialogueRunner.new().restore_runtime_snapshot(
			replacement,
			post_start_snapshots[0]
		)

	assert_null(stale_result, "旧响应调用链在会话被替换后必须返回 null。")
	assert_true(runner.is_running(), "旧 mutation 调用链不得结束重入创建的新会话。")
	var current_line: GFDialogueLine = runner.get_current_line()
	assert_not_null(current_line, "替换会话必须保持自己的当前行。")
	if current_line != null:
		assert_eq(current_line.line_id, &"replacement", "替换会话必须保持在自己的当前行。")
	assert_eq(mutation_call_count[0], 0, "mutation_requested 改变会话后不得再调用旧上下文 handler。")
	assert_true(_single_snapshot_is_non_empty(replacement_snapshots), "新会话 line_reached 不得继承旧会话的推进 barrier。")
	assert_true(_single_snapshot_is_non_empty(post_start_snapshots), "新会话 start 返回后不得残留旧会话的推进 barrier。")
	assert_not_null(restored_replacement, "替换会话发布的稳定 checkpoint 必须可独立恢复。")
	assert_not_null(restored_post_start, "替换会话 start 返回后的 checkpoint 必须可独立恢复。")
	if restored_replacement != null:
		assert_eq(restored_replacement.line_id, &"replacement")
	if restored_post_start != null:
		assert_eq(restored_post_start.line_id, &"replacement")


func test_dialogue_line_mutation_reentry_cannot_end_replacement_session() -> void:
	var original: GFDialogueResource = GFDialogueResource.new()
	original.start_line_id = &"mutate"
	var mutation_line: GFDialogueLine = GFDialogueLine.new()
	mutation_line.line_id = &"mutate"
	mutation_line.kind = GFDialogueLine.LineKind.MUTATION
	mutation_line.mutation_id = &"replace_session"
	mutation_line.next_line_id = &"old_done"
	original.set_line(mutation_line)
	original.set_line(_make_text_line(&"old_done", "Old", &""))
	var replacement: GFDialogueResource = GFDialogueResource.new()
	replacement.start_line_id = &"replacement"
	replacement.set_line(_make_text_line(&"replacement", "Replacement", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var replaced: Array[bool] = [false]
	var mutation_requested_callback: Callable = (
		func(_mutation_id: StringName, _payload: Variant, _line: GFDialogueLine) -> void:
			if replaced[0]:
				return
			replaced[0] = true
			var _replacement_line: GFDialogueLine = runner.start(replacement)
	)
	var _connected: Error = runner.mutation_requested.connect(
		mutation_requested_callback
	) as Error

	var stale_result: GFDialogueLine = runner.start(original, &"", GFDialogueContext.new())
	runner.mutation_requested.disconnect(mutation_requested_callback)

	assert_null(stale_result, "旧 mutation 行推进在会话被替换后必须返回 null。")
	assert_true(runner.is_running(), "旧 mutation 行失败路径不得停止替换会话。")
	assert_eq(runner.get_current_line().line_id, &"replacement", "替换会话当前行不得被旧调用链覆盖。")


func test_dialogue_snapshot_copy_uses_one_global_node_and_packed_budget() -> void:
	var shared_branch: Array = []
	for index: int in range(512):
		shared_branch.append(index)
	var amplified_payload: Array = []
	for index: int in range(64):
		amplified_payload.append(shared_branch)
	var oversized_packed: PackedByteArray = PackedByteArray()
	var _packed_resize_error: Error = oversized_packed.resize(65_537) as Error
	var line: GFDialogueLine = _make_text_line(&"start", "Start", &"")
	line.mutation_payload = amplified_payload
	var packed_line: GFDialogueLine = _make_text_line(&"packed", "Packed", &"")
	packed_line.condition_payload = oversized_packed

	var snapshot: Dictionary = line.to_dictionary()
	var packed_snapshot: Dictionary = packed_line.to_dictionary()

	assert_eq(GFVariantData.get_option_string(packed_snapshot, "condition_payload"), "<packed_length_budget>", "单个 PackedArray 必须受操作级总长度预算约束。")
	assert_true(_variant_contains_value(snapshot, "<node_budget>"), "重复共享分支的复制成本必须累计到同一个节点预算。")


func test_dialogue_identity_uses_complete_content_beyond_display_snapshot_budget() -> void:
	var first_payload: Array = []
	var _payload_resize_error: Error = first_payload.resize(5001) as Error
	first_payload.fill(0)
	var second_payload: Array = first_payload.duplicate()
	second_payload[5000] = 1
	var first_resource: GFDialogueResource = GFDialogueResource.new()
	first_resource.start_line_id = &"line"
	var first_line: GFDialogueLine = _make_text_line(&"line", "Line", &"")
	first_line.mutation_payload = first_payload
	first_resource.set_line(first_line)
	var second_resource: GFDialogueResource = GFDialogueResource.new()
	second_resource.start_line_id = &"line"
	var second_line: GFDialogueLine = _make_text_line(&"line", "Line", &"")
	second_line.mutation_payload = second_payload
	second_resource.set_line(second_line)
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _first_reached: GFDialogueLine = runner.start(first_resource)
	var first_fingerprint: String = GFVariantData.get_option_string(
		runner.create_runtime_snapshot(),
		"resource_fingerprint"
	)
	runner.stop()
	var _second_reached: GFDialogueLine = runner.start(second_resource)
	var second_fingerprint: String = GFVariantData.get_option_string(
		runner.create_runtime_snapshot(),
		"resource_fingerprint"
	)

	assert_false(first_fingerprint.is_empty(), "完整身份编码成功时必须生成 fingerprint。")
	assert_ne(first_fingerprint, second_fingerprint, "展示快照预算之后的内容差异仍必须改变资源身份。")


func test_dialogue_runner_fails_closed_when_resource_identity_is_not_stable() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"line"
	var line: GFDialogueLine = _make_text_line(&"line", "Line", &"")
	line.metadata = {
		"unstable_object": self,
	}
	resource.set_line(line)
	var runner: GFDialogueRunner = GFDialogueRunner.new()

	var reached: GFDialogueLine = runner.start(resource)

	assert_null(reached, "包含不可稳定编码对象的资源不得启动。")
	assert_false(runner.is_running(), "身份计算失败必须保持 Runner 未运行。")
	assert_push_error("GFDialogueRunner refused an incomplete resource identity (unsupported_variant")


func test_dialogue_condition_reentry_preserves_replacement_session() -> void:
	var original: GFDialogueResource = GFDialogueResource.new()
	original.start_line_id = &"guarded"
	var guarded: GFDialogueLine = _make_text_line(&"guarded", "Guarded", &"")
	guarded.condition_id = &"replace"
	original.set_line(guarded)
	var replacement: GFDialogueResource = GFDialogueResource.new()
	replacement.start_line_id = &"replacement"
	replacement.set_line(_make_text_line(&"replacement", "Replacement", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var replaced: Array[bool] = [false]
	var context: GFDialogueContext = GFDialogueContext.new()
	context.condition_handler = func(
		_condition_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		if not replaced[0]:
			replaced[0] = true
			var _replacement_line: GFDialogueLine = runner.start(replacement)
		return true

	var stale_result: GFDialogueLine = runner.start(original, &"", context)

	assert_null(stale_result, "condition 回调替换会话后旧推进必须返回 null。")
	assert_true(runner.is_running(), "旧 condition 调用栈不得终止替换会话。")
	var replacement_line: GFDialogueLine = runner.get_current_line()
	assert_not_null(replacement_line, "替换会话必须保留自己的当前行。")
	if replacement_line != null:
		assert_eq(replacement_line.line_id, &"replacement", "替换会话必须保留自己的当前行。")


func test_dialogue_missing_line_blocked_reentry_preserves_replacement_session() -> void:
	var original: GFDialogueResource = GFDialogueResource.new()
	original.start_line_id = &"start"
	original.set_line(_make_text_line(&"start", "Start", &"missing"))
	var replacement: GFDialogueResource = GFDialogueResource.new()
	replacement.start_line_id = &"replacement"
	replacement.set_line(_make_text_line(&"replacement", "Replacement", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var _original_line: GFDialogueLine = runner.start(original)
	var replaced: Array[bool] = [false]
	var on_blocked: Callable = func(_line_id: StringName, _reason: StringName) -> void:
		if replaced[0]:
			return
		replaced[0] = true
		var _replacement_line: GFDialogueLine = runner.start(replacement)
	var _connected: Error = runner.line_blocked.connect(on_blocked) as Error

	var stale_result: GFDialogueLine = runner.advance()
	runner.line_blocked.disconnect(on_blocked)

	assert_null(stale_result, "line_blocked 回调替换会话后旧推进必须返回 null。")
	assert_true(runner.is_running(), "旧 missing-line 调用栈不得终止替换会话。")
	var replacement_line: GFDialogueLine = runner.get_current_line()
	assert_not_null(replacement_line, "替换会话当前行不得被旧阻断路径清空。")
	if replacement_line != null:
		assert_eq(replacement_line.line_id, &"replacement", "替换会话当前行不得被旧阻断路径清空。")


func test_dialogue_line_reached_reentry_returns_stale_null() -> void:
	var original: GFDialogueResource = GFDialogueResource.new()
	original.start_line_id = &"original"
	original.set_line(_make_text_line(&"original", "Original", &""))
	var replacement: GFDialogueResource = GFDialogueResource.new()
	replacement.start_line_id = &"replacement"
	replacement.set_line(_make_text_line(&"replacement", "Replacement", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var replaced: Array[bool] = [false]
	var on_line_reached: Callable = func(_line: GFDialogueLine) -> void:
		if replaced[0]:
			return
		replaced[0] = true
		var _replacement_line: GFDialogueLine = runner.start(replacement)
	var _connected: Error = runner.line_reached.connect(on_line_reached) as Error

	var stale_result: GFDialogueLine = runner.start(original)
	runner.line_reached.disconnect(on_line_reached)

	assert_null(stale_result, "line_reached 回调替换会话后旧 start 必须返回 null。")
	assert_true(runner.is_running(), "line_reached 旧调用栈不得终止替换会话。")
	var replacement_line: GFDialogueLine = runner.get_current_line()
	assert_not_null(replacement_line, "替换会话应保持当前行。")
	if replacement_line != null:
		assert_eq(replacement_line.line_id, &"replacement", "替换会话应保持当前行。")


func test_dialogue_response_condition_reentry_preserves_replacement_session() -> void:
	var original: GFDialogueResource = GFDialogueResource.new()
	original.start_line_id = &"start"
	var start: GFDialogueLine = _make_text_line(&"start", "Start", &"")
	var response: GFDialogueResponse = GFDialogueResponse.new()
	response.response_id = &"pick"
	response.condition_id = &"replace"
	response.next_line_id = &"old_done"
	start.responses.append(response)
	original.set_line(start)
	original.set_line(_make_text_line(&"old_done", "Old", &""))
	var replacement: GFDialogueResource = GFDialogueResource.new()
	replacement.start_line_id = &"replacement"
	replacement.set_line(_make_text_line(&"replacement", "Replacement", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	var replaced: Array[bool] = [false]
	var context: GFDialogueContext = GFDialogueContext.new()
	context.condition_handler = func(
		_condition_id: StringName,
		_payload: Variant,
		_subject: Variant,
		_context: GFDialogueContext
	) -> bool:
		if not replaced[0]:
			replaced[0] = true
			var _replacement_line: GFDialogueLine = runner.start(replacement)
		return true
	var _original_line: GFDialogueLine = runner.start(original, &"", context)

	var stale_result: GFDialogueLine = runner.choose_response(&"pick")

	assert_null(stale_result, "响应 condition 替换会话后旧选择必须返回 null。")
	assert_true(runner.is_running(), "旧响应 condition 调用栈不得结束替换会话。")
	var replacement_line: GFDialogueLine = runner.get_current_line()
	assert_not_null(replacement_line, "替换会话不得被旧 response 后继覆盖。")
	if replacement_line != null:
		assert_eq(replacement_line.line_id, &"replacement", "替换会话不得被旧 response 后继覆盖。")


func test_dialogue_step_budget_counts_only_non_display_transitions() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"jump"
	var jump: GFDialogueLine = GFDialogueLine.new()
	jump.line_id = &"jump"
	jump.kind = GFDialogueLine.LineKind.JUMP
	jump.jump_line_id = &"visible"
	resource.set_line(jump)
	resource.set_line(_make_text_line(&"visible", "Visible", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	runner.max_steps_per_advance = 1
	watch_signals(runner)

	var reached: GFDialogueLine = runner.start(resource)

	assert_not_null(reached, "一个 JUMP 后的 TEXT 应在一步非展示预算内可达。")
	if reached != null:
		assert_eq(reached.line_id, &"visible", "TEXT 本身不得占用非展示步骤预算。")
	assert_signal_not_emitted(runner, "line_blocked", "恰好耗尽预算后到达 TEXT 不应触发阻断。")


func test_dialogue_step_budget_blocks_before_second_non_display_transition() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"jump_a"
	var jump_a: GFDialogueLine = GFDialogueLine.new()
	jump_a.line_id = &"jump_a"
	jump_a.kind = GFDialogueLine.LineKind.JUMP
	jump_a.jump_line_id = &"jump_b"
	var jump_b: GFDialogueLine = GFDialogueLine.new()
	jump_b.line_id = &"jump_b"
	jump_b.kind = GFDialogueLine.LineKind.JUMP
	jump_b.jump_line_id = &"visible"
	resource.set_line(jump_a)
	resource.set_line(jump_b)
	resource.set_line(_make_text_line(&"visible", "Visible", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	runner.max_steps_per_advance = 1
	watch_signals(runner)

	var reached: GFDialogueLine = runner.start(resource)

	assert_null(reached, "第二个非展示 transition 不得越过一步预算。")
	assert_signal_emitted_with_parameters(runner, "line_blocked", [&"jump_b", &"max_steps_reached"])


func test_dialogue_zero_step_budget_keeps_unlimited_semantics() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"jump_a"
	var jump_a: GFDialogueLine = GFDialogueLine.new()
	jump_a.line_id = &"jump_a"
	jump_a.kind = GFDialogueLine.LineKind.JUMP
	jump_a.jump_line_id = &"jump_b"
	var jump_b: GFDialogueLine = GFDialogueLine.new()
	jump_b.line_id = &"jump_b"
	jump_b.kind = GFDialogueLine.LineKind.JUMP
	jump_b.jump_line_id = &"visible"
	resource.set_line(jump_a)
	resource.set_line(jump_b)
	resource.set_line(_make_text_line(&"visible", "Visible", &""))
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	runner.max_steps_per_advance = 0

	var reached: GFDialogueLine = runner.start(resource)

	assert_not_null(reached, "零预算配置应保留既有的 unlimited 语义。")
	if reached != null:
		assert_eq(reached.line_id, &"visible", "无限步数模式仍应到达稳定 TEXT。")


func test_dialogue_resource_validation_rejects_empty_graph() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()

	var report: Dictionary = resource.validate_resource()
	var issues: Array = GFVariantData.get_option_array(report, "issues")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "没有可运行起点的空对话不得报告为健康。")
	assert_true(_has_issue_kind(issues, "empty_dialogue"), "空图应产生稳定 empty_dialogue issue。")


func test_dialogue_identity_failure_path_redacts_dictionary_keys() -> void:
	var canary_key: String = "DIALOGUE_SECRET_CANARY\r\n" + "x".repeat(8192)
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.metadata[canary_key] = self

	var report: Dictionary = resource.build_identity_report()
	var failure_path: String = GFVariantData.get_option_string(report, "path")

	assert_false(GFVariantData.get_option_bool(report, "ok"), "不稳定对象必须让完整身份复制失败。")
	assert_false(failure_path.contains("DIALOGUE_SECRET_CANARY"), "身份失败路径不得泄漏任意字典键。")
	assert_false(failure_path.contains("\r"), "失败路径不得保留回车控制字符。")
	assert_false(failure_path.contains("\n"), "失败路径不得保留换行控制字符。")
	assert_lt(failure_path.length(), 256, "攻击者控制的键长度不得放大诊断路径。")


func test_dialogue_identity_is_canonical_across_dictionary_insertion_order() -> void:
	var first_nested: Dictionary = {}
	first_nested[&"beta"] = 2
	first_nested["alpha"] = 1
	first_nested[7] = "seven"
	var second_nested: Dictionary = {}
	second_nested[7] = "seven"
	second_nested["alpha"] = 1
	second_nested[&"beta"] = 2
	var first_metadata: Dictionary = {}
	first_metadata["zeta"] = first_nested
	first_metadata[&"alpha"] = true
	var second_metadata: Dictionary = {}
	second_metadata[&"alpha"] = true
	second_metadata["zeta"] = second_nested
	var first_resource: GFDialogueResource = GFDialogueResource.new()
	first_resource.start_line_id = &"line"
	first_resource.metadata = first_metadata
	first_resource.set_line(_make_text_line(&"line", "Line", &""))
	var second_resource: GFDialogueResource = GFDialogueResource.new()
	second_resource.start_line_id = &"line"
	second_resource.metadata = second_metadata
	second_resource.set_line(_make_text_line(&"line", "Line", &""))
	var first_runner: GFDialogueRunner = GFDialogueRunner.new()
	var _first_line: GFDialogueLine = first_runner.start(first_resource)
	var snapshot: Dictionary = first_runner.create_runtime_snapshot()
	var first_fingerprint: String = GFVariantData.get_option_string(snapshot, "resource_fingerprint")
	var second_runner: GFDialogueRunner = GFDialogueRunner.new()
	var _second_line: GFDialogueLine = second_runner.start(second_resource)
	var second_fingerprint: String = GFVariantData.get_option_string(
		second_runner.create_runtime_snapshot(),
		"resource_fingerprint"
	)
	var restored_runner: GFDialogueRunner = GFDialogueRunner.new()
	var restored: GFDialogueLine = restored_runner.restore_runtime_snapshot(second_resource, snapshot)

	assert_eq(first_fingerprint, second_fingerprint, "无序 Dictionary 的插入顺序不得改变资源身份。")
	assert_not_null(restored, "语义相同但插入顺序不同的资源应能交叉恢复快照。")


func test_dialogue_identity_encoding_cannot_hash_traversal_limit_marker() -> void:
	var first_payload: Array = []
	var _first_resize_error: Error = first_payload.resize(20_000) as Error
	first_payload.fill(0)
	var second_payload: Array = first_payload.duplicate()
	second_payload[19_999] = 1
	var first_resource: GFDialogueResource = GFDialogueResource.new()
	first_resource.start_line_id = &"line"
	var first_line: GFDialogueLine = _make_text_line(&"line", "Line", &"")
	first_line.mutation_payload = first_payload
	first_resource.set_line(first_line)
	var second_resource: GFDialogueResource = GFDialogueResource.new()
	second_resource.start_line_id = &"line"
	var second_line: GFDialogueLine = _make_text_line(&"line", "Line", &"")
	second_line.mutation_payload = second_payload
	second_resource.set_line(second_line)
	var first_runner: GFDialogueRunner = GFDialogueRunner.new()
	var _first_reached: GFDialogueLine = first_runner.start(first_resource)
	var first_fingerprint: String = GFVariantData.get_option_string(
		first_runner.create_runtime_snapshot(),
		"resource_fingerprint"
	)
	var second_runner: GFDialogueRunner = GFDialogueRunner.new()
	var _second_reached: GFDialogueLine = second_runner.start(second_resource)
	var second_fingerprint: String = GFVariantData.get_option_string(
		second_runner.create_runtime_snapshot(),
		"resource_fingerprint"
	)

	assert_false(first_fingerprint.is_empty(), "完整有界资源必须生成身份。")
	assert_ne(first_fingerprint, second_fingerprint, "codec 遍历 marker 不得伪装成完整内容身份。")


func test_dialogue_invalid_line_kind_fails_closed_with_stable_reason() -> void:
	var resource: GFDialogueResource = GFDialogueResource.new()
	resource.start_line_id = &"invalid"
	var invalid_line: GFDialogueLine = _make_text_line(&"invalid", "Invalid", &"")
	invalid_line.set(&"kind", 99)
	resource.set_line(invalid_line)
	var report: Dictionary = resource.validate_resource()
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	var runner: GFDialogueRunner = GFDialogueRunner.new()
	watch_signals(runner)

	var reached: GFDialogueLine = runner.start(resource)

	assert_true(_has_issue_kind(issues, "invalid_line_kind"), "validator 应拒绝未知 LineKind。")
	assert_null(reached, "Runner 不得执行未知 LineKind。")
	assert_signal_emitted_with_parameters(runner, "line_blocked", [&"invalid", &"invalid_line_kind"])


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


func _count_issue_kind(issues: Array, kind: String) -> int:
	var count: int = 0
	for issue: Variant in issues:
		var issue_dictionary: Dictionary = GFVariantData.as_dictionary(issue)
		if GFVariantData.get_option_string(issue_dictionary, "kind") == kind:
			count += 1
	return count


func _single_snapshot_is_empty(snapshots: Array[Dictionary]) -> bool:
	return snapshots.size() == 1 and snapshots[0].is_empty()


func _single_snapshot_is_non_empty(snapshots: Array[Dictionary]) -> bool:
	return snapshots.size() == 1 and not snapshots[0].is_empty()


func _dictionary_contains_value(root: Dictionary, expected: Variant) -> bool:
	var dictionary_stack: Array[Dictionary] = [root]
	while not dictionary_stack.is_empty():
		var current: Dictionary = dictionary_stack.pop_back()
		for value: Variant in current.values():
			if typeof(value) == typeof(expected) and value == expected:
				return true
			if value is Dictionary:
				dictionary_stack.append(value)
	return false


func _variant_contains_value(root: Variant, expected: Variant) -> bool:
	var worklist: Array = [root]
	while not worklist.is_empty():
		var current: Variant = worklist.pop_back()
		if typeof(current) == typeof(expected) and current == expected:
			return true
		if current is Dictionary:
			var dictionary: Dictionary = current
			worklist.append_array(dictionary.values())
		elif current is Array:
			var array: Array = current
			worklist.append_array(array)
	return false
