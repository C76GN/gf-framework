## 测试 GFQuestUtility 的任务推进与 simple event 清理行为。
extends GutTest


var _quest: TrackingQuestUtility


class TrackingQuestUtility extends GFQuestUtility:
	var disposed_called: bool = false

	func dispose() -> void:
		disposed_called = true
		super.dispose()


func before_each() -> void:
	var arch: GFArchitecture = GFArchitecture.new()
	Gf._architecture = arch

	_quest = TrackingQuestUtility.new()
	await Gf.register_utility(_quest)
	await Gf.set_architecture(arch)
	await get_tree().process_frame


func after_each() -> void:
	var arch: GFArchitecture = Gf.get_architecture()
	if arch != null:
		arch.dispose()
		await Gf.set_architecture(GFArchitecture.new())
	await get_tree().process_frame


func test_quest_progress() -> void:
	_quest.start_quest(&"kill_slimes", &"enemy_died", 3)

	_quest.emit_quest_event(&"enemy_died", 1)
	var q_data: Dictionary = _quest.get_quest_report(&"kill_slimes")
	assert_eq(GFVariantData.get_option_int(q_data, "current_count", -1), 1)
	assert_false(_quest.is_quest_completed(&"kill_slimes"))

	_quest.emit_quest_event(&"enemy_died", 2)
	q_data = _quest.get_quest_report(&"kill_slimes")
	assert_eq(GFVariantData.get_option_int(q_data, "current_count", -1), 3)
	assert_true(_quest.is_quest_completed(&"kill_slimes"))
	assert_eq(GFVariantData.get_option_int(_quest.get_debug_snapshot(), "event_count", -1), 0, "最后一个任务完成后应注销对应事件监听。")


func test_quest_integration_with_simple_event() -> void:
	_quest.start_quest(&"collect_coins", &"money_looted", 10)

	Gf.send_simple_event(&"money_looted", 5)
	assert_eq(_quest.get_quest_progress(&"collect_coins"), 0.5)

	Gf.send_simple_event(&"money_looted", {"amount": 5})
	assert_true(_quest.is_quest_completed(&"collect_coins"))


func test_float_payload_amount_is_rounded() -> void:
	_quest.start_quest(&"collect_parts", &"part_looted", 3)

	Gf.send_simple_event(&"part_looted", 1.6)

	var q_data: Dictionary = _quest.get_quest_report(&"collect_parts")
	assert_eq(GFVariantData.get_option_int(q_data, "current_count", -1), 2, "float 进度载荷应四舍五入为最接近的整数。")


func test_non_finite_float_payload_amount_uses_safe_default() -> void:
	_quest.start_quest(&"finite_progress", &"progress_event", 5)

	Gf.send_simple_event(&"progress_event", NAN)
	Gf.send_simple_event(&"progress_event", INF)

	var q_data: Dictionary = _quest.get_quest_report(&"finite_progress")
	assert_eq(GFVariantData.get_option_int(q_data, "current_count", -1), 2, "非有限 float 载荷应使用稳定默认增量。")
	assert_push_error("[GFQuestUtility] payload.amount 必须是有限数，已回退为默认进度 1。")
	assert_push_error("[GFQuestUtility] payload.amount 必须是有限数，已回退为默认进度 1。")


func test_progress_addition_saturates_before_int64_overflow() -> void:
	_quest.start_quest(&"overflow_safe", &"progress_event", 10)

	Gf.send_simple_event(&"progress_event", 1)
	Gf.send_simple_event(&"progress_event", 9223372036854775807)

	var q_data: Dictionary = _quest.get_quest_report(&"overflow_safe")
	assert_eq(GFVariantData.get_option_int(q_data, "current_count", -1), 10, "极大增量应在加法前判溢出并夹到目标值。")
	assert_true(_quest.is_quest_completed(&"overflow_safe"), "溢出防护不得把正向进度翻转为负数。")


func test_out_of_range_float_payload_uses_safe_default_before_rounding() -> void:
	_quest.start_quest(&"float_range", &"progress_event", 5)

	Gf.send_simple_event(&"progress_event", 1.0e30)

	var q_data: Dictionary = _quest.get_quest_report(&"float_range")
	assert_eq(GFVariantData.get_option_int(q_data, "current_count", -1), 1, "超出 int64 的 float 不得进入 roundi。")
	assert_push_error("[GFQuestUtility] payload.amount 超出 int64 范围，已回退为默认进度 1。")


func test_negative_payload_amount_is_ignored_by_default() -> void:
	_quest.start_quest(&"hold_progress", &"progress_event", 3)

	Gf.send_simple_event(&"progress_event", 2)
	Gf.send_simple_event(&"progress_event", -5)

	var q_data: Dictionary = _quest.get_quest_report(&"hold_progress")
	assert_eq(GFVariantData.get_option_int(q_data, "current_count", -1), 2, "默认不应允许负数 payload 反向扣减任务进度。")


func test_negative_payload_amount_can_be_enabled() -> void:
	_quest.allow_negative_progress = true
	_quest.start_quest(&"decay_progress", &"progress_event", 3)

	Gf.send_simple_event(&"progress_event", 2)
	Gf.send_simple_event(&"progress_event", -1)

	var q_data: Dictionary = _quest.get_quest_report(&"decay_progress")
	assert_eq(GFVariantData.get_option_int(q_data, "current_count", -1), 1, "显式开启后应允许负数 payload 调整进度。")


func test_negative_progress_percentage_is_clamped_to_documented_range() -> void:
	_quest.allow_negative_progress = true
	_quest.start_quest(&"decay_progress", &"progress_event", 3)

	Gf.send_simple_event(&"progress_event", -1)

	var q_data: Dictionary = _quest.get_quest_report(&"decay_progress")
	assert_eq(GFVariantData.get_option_int(q_data, "current_count"), -1, "原始任务计数仍应允许负数。")
	assert_eq(_quest.get_quest_progress(&"decay_progress"), 0.0, "公开进度百分比应保持在 0..1。")


func test_cancel_last_quest_unregisters_event_listener() -> void:
	_quest.start_quest(&"cleanup_listener", &"enemy_died", 3)

	assert_true(_quest.cancel_quest(&"cleanup_listener"), "取消 active 任务应成功。")

	assert_eq(GFVariantData.get_option_int(_quest.get_debug_snapshot(), "event_count", -1), 0, "最后一个任务取消后应注销对应事件监听。")


func test_start_quest_rejects_empty_ids() -> void:
	_quest.start_quest(&"", &"event", 1)
	_quest.start_quest(&"quest", &"", 1)

	assert_eq(_quest.get_quest_report(&""), {}, "空 quest_id 不应注册任务。")
	assert_eq(_quest.get_quest_report(&"quest"), {}, "空 target_event 不应注册任务。")
	assert_push_error("[GFQuestUtility] quest_id 和 target_event 不能为空。")
	assert_push_error("[GFQuestUtility] quest_id 和 target_event 不能为空。")


func test_deep_payload_amount_falls_back_without_recursion_overflow() -> void:
	_quest.start_quest(&"nested_payload", &"nested_event", 3)
	var payload: Variant = { "amount": 1 }
	for i: int in range(20):
		payload = { "amount": payload }

	Gf.send_simple_event(&"nested_event", payload)
	var q_data: Dictionary = _quest.get_quest_report(&"nested_payload")

	assert_eq(GFVariantData.get_option_int(q_data, "current_count", -1), 1, "嵌套过深的 payload 应回退为默认进度。")
	assert_push_error("[GFQuestUtility] payload.amount 嵌套过深，已回退为默认进度 1。")


func test_zero_target_quest_completes_immediately() -> void:
	watch_signals(_quest)

	_quest.start_quest(&"already_done", &"unused_event", 0)

	assert_true(_quest.is_quest_completed(&"already_done"), "target_count <= 0 的任务应立即完成。")
	assert_eq(_quest.get_quest_progress(&"already_done"), 1.0, "立即完成任务的进度应为 100%。")
	assert_signal_emitted(_quest, "quest_completed", "立即完成任务应发出完成信号。")


func test_quest_lifecycle_blocker_and_debug_snapshot() -> void:
	watch_signals(_quest)
	_quest.define_quest(&"gated", &"gate_event", 1, {"chapter": 1})
	assert_eq(_quest.get_quest_status(&"gated"), GFQuestUtility.STATUS_AVAILABLE, "define_quest 应创建可接取任务。")
	assert_signal_emitted(_quest, "quest_available", "任务进入 available 时应发出信号。")

	var gate: Dictionary = { "allow": false }
	_quest.add_completion_blocker(&"gated", func(_quest_id: StringName, _report: Dictionary) -> Dictionary:
		return {"ok": GFVariantData.get_option_bool(gate, "allow"), "reason": "locked"}
	)

	assert_true(_quest.accept_quest(&"gated"), "可接取任务应能进入 active。")
	_quest.emit_quest_event(&"gate_event", 1)
	assert_eq(_quest.get_quest_status(&"gated"), GFQuestUtility.STATUS_ACTIVE, "被阻塞时任务应保持 active。")
	assert_signal_emitted(_quest, "quest_completion_blocked", "完成阻塞器拒绝时应发出阻塞信号。")

	gate["allow"] = true
	assert_true(_quest.complete_quest(&"gated"), "阻塞解除后应允许手动完成。")
	assert_eq(_quest.get_quest_status(&"gated"), GFQuestUtility.STATUS_COMPLETED, "完成后状态应更新。")
	assert_true(_quest.get_quests_by_status(GFQuestUtility.STATUS_COMPLETED).has("gated"), "状态查询应包含完成任务。")
	var snapshot: Dictionary = _quest.get_debug_snapshot()
	assert_eq(GFVariantData.get_option_int(snapshot, "quest_count"), 1, "调试快照应统计任务数量。")
	var quests: Dictionary = GFVariantData.get_option_dictionary(snapshot, "quests")
	var gated_report: Dictionary = GFVariantData.get_option_dictionary(quests, "gated")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(gated_report, "metadata")
	assert_eq(GFVariantData.get_option_int(metadata, "chapter"), 1, "任务报告应保留 metadata。")


func test_acceptance_condition_can_block_accepting_quest() -> void:
	watch_signals(_quest)
	_quest.define_quest(&"locked", &"gate_event", 1)
	_quest.add_acceptance_condition(&"locked", func(_quest_id: StringName, _report: Dictionary) -> Dictionary:
		return {
			"ok": false,
			"reason": "missing_key",
		}
	)

	assert_false(_quest.accept_quest(&"locked"), "接取条件拒绝时不应进入 active。")
	assert_eq(_quest.get_quest_status(&"locked"), GFQuestUtility.STATUS_AVAILABLE, "被拒绝后任务应保持 available。")
	assert_signal_emitted(_quest, "quest_acceptance_blocked", "接取条件拒绝时应发出信号。")

	_quest.clear_acceptance_conditions(&"locked")
	assert_true(_quest.accept_quest(&"locked"), "清空条件后应可接取。")


func test_defined_quest_rejects_empty_target_event_up_front() -> void:
	watch_signals(_quest)

	_quest.define_quest(&"broken", &"", 1)

	assert_eq(_quest.get_quest_report(&"broken"), {}, "可接取任务定义阶段也应拒绝空 target_event。")
	assert_signal_not_emitted(_quest, "quest_available", "无效任务定义不应进入 available。")
	assert_push_error("[GFQuestUtility] quest_id 和 target_event 不能为空。")


func test_condition_dictionary_must_declare_ok_field() -> void:
	watch_signals(_quest)
	_quest.define_quest(&"strict", &"gate_event", 1)
	_quest.add_acceptance_condition(&"strict", func(_quest_id: StringName, _report: Dictionary) -> Dictionary:
		return {
			"reason": "ambiguous",
		}
	)

	assert_false(_quest.accept_quest(&"strict"), "条件字典缺少 ok 字段时应按无效条件结果拒绝。")
	assert_eq(_quest.get_quest_status(&"strict"), GFQuestUtility.STATUS_AVAILABLE, "无效条件结果不应推进任务生命周期。")
	assert_signal_emitted(_quest, "quest_acceptance_blocked", "无效条件结果应通过阻塞信号显式暴露。")


func test_available_quest_cannot_be_completed_before_acceptance() -> void:
	watch_signals(_quest)
	_quest.define_quest(&"locked", &"gate_event", 1)
	_quest.add_acceptance_condition(&"locked", func(_quest_id: StringName, _report: Dictionary) -> Dictionary:
		return {
			"ok": false,
			"reason": "missing_key",
		}
	)

	assert_false(_quest.complete_quest(&"locked"), "available 任务未接取前不应被手动完成。")
	assert_eq(_quest.get_quest_status(&"locked"), GFQuestUtility.STATUS_AVAILABLE, "手动完成失败后任务应保持 available。")
	assert_signal_not_emitted(_quest, "quest_completed", "被接取条件保护的任务不应绕过生命周期完成。")


func test_fail_quest_detaches_listener_and_records_reason() -> void:
	watch_signals(_quest)
	_quest.start_quest(&"timed", &"timer_done", 2)

	assert_true(_quest.fail_quest(&"timed", "timeout"), "active 任务应可标记失败。")
	assert_eq(_quest.get_quest_status(&"timed"), GFQuestUtility.STATUS_FAILED, "失败后状态应更新。")
	assert_eq(GFVariantData.get_option_int(_quest.get_debug_snapshot(), "event_count", -1), 0, "失败后应注销事件监听。")
	var timed_report: Dictionary = _quest.get_quest_report(&"timed")
	var timed_metadata: Dictionary = GFVariantData.get_option_dictionary(timed_report, "metadata")
	assert_eq(GFVariantData.get_option_string(timed_metadata, "last_failure_reason"), "timeout", "失败原因应写入 metadata。")
	assert_signal_emitted(_quest, "quest_failed", "失败时应发出 quest_failed 信号。")


func test_quest_parent_child_tree_report_aggregates_progress() -> void:
	_quest.define_quest(&"root", &"root_event", 1)
	_quest.define_quest(&"child_a", &"child_a_event", 1)
	_quest.define_quest(&"child_b", &"child_b_event", 1)

	assert_true(_quest.set_quest_parent(&"child_a", &"root"), "应能设置父子关系。")
	assert_true(_quest.set_quest_parent(&"child_b", &"root"), "应能设置第二个子任务。")
	assert_eq(_quest.get_child_quests(&"root"), PackedStringArray(["child_a", "child_b"]), "子任务 ID 应稳定排序。")
	assert_false(_quest.set_quest_parent(&"root", &"child_a"), "不应允许形成循环父子关系。")

	var _accept_quest_result_210: Variant = _quest.accept_quest(&"child_a")
	var _complete_quest_result_211: Variant = _quest.complete_quest(&"child_a")
	var report: Dictionary = _quest.get_quest_tree_report(&"root")

	assert_eq(GFVariantData.get_option_int(report, "total_count"), 3, "树报告应统计根和所有子任务。")
	assert_eq(GFVariantData.get_option_int(report, "completed_count"), 1, "树报告应统计已完成任务数量。")
	assert_almost_eq(GFVariantData.get_option_float(report, "aggregate_progress"), 1.0 / 3.0, 0.001, "树报告应提供聚合进度。")


func test_quest_tree_report_handles_deep_valid_chains_iteratively() -> void:
	const QUEST_COUNT: int = 1024
	for index: int in range(QUEST_COUNT):
		var quest_id: StringName = StringName("quest_%04d" % index)
		_quest.define_quest(quest_id, StringName("event_%04d" % index), 1)
		if index > 0:
			var parent_id: StringName = StringName("quest_%04d" % (index - 1))
			assert_true(_quest.set_quest_parent(quest_id, parent_id), "合法深链应可建立父子关系。")

	var report: Dictionary = _quest.get_quest_tree_report(&"quest_0000")

	assert_eq(GFVariantData.get_option_int(report, "total_count"), QUEST_COUNT, "深任务树报告应稳定统计全部节点。")


func test_dispose_unregisters_simple_event_listener() -> void:
	_quest.start_quest(&"cleanup_listener", &"enemy_died", 1)

	var arch: GFArchitecture = Gf.get_architecture()
	var quest_script: Script = _quest.get_script()
	arch.unregister_utility(quest_script)

	assert_true(_quest.disposed_called, "注销 Utility 时应执行 dispose。")
	Gf.send_simple_event(&"enemy_died", 1)
	assert_false(_quest.is_quest_completed(&"cleanup_listener"), "dispose 后旧 simple event 回调不应继续推进任务。")
