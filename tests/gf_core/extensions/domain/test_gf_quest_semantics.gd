extends GutTest

var _quest: GFQuestUtility


func before_each() -> void:
	_quest = GFQuestUtility.new()
	_quest.init()


func after_each() -> void:
	_quest.dispose()


func test_definition_diagnostics_locate_fields_without_authorizing_changed_input() -> void:
	var options: Dictionary = { "target": 3 }
	var report: Dictionary = GFQuestDefinition.validate_create(
		&"q",
		&"m",
		options
	)
	assert_eq(
		report,
		{
			"ok": true,
			"error_kind": "",
			"path": "",
		}
	)
	options["target"] = 3.5
	assert_null(
		GFQuestDefinition.create(
			&"q",
			&"m",
			options
		)
	)
	var changed: Dictionary = GFQuestDefinition.validate_create(
		&"q",
		&"m",
		options
	)
	assert_eq(
		GFVariantData.get_option_string(changed, "error_kind"),
		"invalid_type"
	)
	assert_eq(
		GFVariantData.get_option_string(changed, "path"),
		"/options/target"
	)
	report["ok"] = false
	assert_eq(
		GFVariantData.get_option_string(changed, "error_kind"),
		"invalid_type"
	)
	var unknown: Dictionary = GFQuestDefinition.validate_create(
		&"q",
		&"m",
		{ "x/y~z": 1 }
	)
	assert_eq(
		GFVariantData.get_option_string(unknown, "error_kind"),
		"unknown_field"
	)
	assert_eq(
		GFVariantData.get_option_string(unknown, "path"),
		"/options/x~1y~0z"
	)
	var too_long: Dictionary = GFQuestDefinition.validate_create(
		StringName("q".repeat(257)),
		&"m"
	)
	assert_eq(
		GFVariantData.get_option_string(too_long, "error_kind"),
		"length_limit"
	)
	assert_eq(
		GFVariantData.get_option_int(too_long, "limit"),
		256
	)
	assert_eq(
		GFVariantData.get_option_int(too_long, "observed"),
		257
	)
	var callback_data: Dictionary = {
		"metadata": { "callback": Callable(self, "before_each") },
	}
	var invalid_data: Dictionary = GFQuestDefinition.validate_create(
		&"q",
		&"m",
		callback_data
	)
	assert_eq(
		GFVariantData.get_option_string(invalid_data, "error_kind"),
		"data_invalid"
	)
	assert_eq(
		GFVariantData.get_option_string(invalid_data, "path"),
		"/options/metadata"
	)
	assert_true(invalid_data.has("measurement"))
	assert_null(
		GFQuestDefinition.create(
			&"q",
			&"m",
			callback_data
		)
	)
	var external: GFQuestDefinition = GFQuestDefinition.create(
		&"q",
		&"",
		{ "completion": "external" }
	)
	assert_not_null(external)


func test_restore_diagnostics_leave_events_queries_conditions_and_explicit_sources_untouched() -> void:
	_define(
		&"count",
		&"events",
		{ "target": 10 }
	)
	_define(
		&"current",
		&"current_value",
		{ "mode": "current", "target": 10 }
	)
	_define(
		&"queried",
		&"query_value",
		{ "mode": "current", "target": 10 }
	)
	var calls: Array[int] = [0, 0]
	var query: Callable = func() -> int:
		calls[0] += 1
		return 4
	var blocker: Callable = func() -> bool:
		calls[1] += 1
		return false
	assert_true(_quest.register_metric_query(&"query_value", query))
	assert_true(_quest.set_metric_value(&"current_value", 5))
	assert_true(_quest.accept_quest(&"count"))
	assert_true(_quest.accept_quest(&"current"))
	assert_true(_quest.accept_quest(&"queried"))
	_quest.add_completion_blocker(&"current", blocker)
	_quest.emit_quest_event(&"events", 2)
	var before: Dictionary = _quest.export_snapshot()
	var before_calls: Array[int] = calls.duplicate()
	watch_signals(_quest)
	var report: Dictionary = _quest.validate_restore_snapshot(before)
	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(
		_quest.export_snapshot(),
		before
	)
	assert_eq(calls, before_calls)
	assert_signal_not_emitted(_quest, "quest_started")
	assert_signal_not_emitted(_quest, "quest_progressed")
	assert_signal_not_emitted(_quest, "quest_completed")
	assert_false(_quest.register_metric_query(&"current_value", query))
	assert_true(_quest.set_metric_value(&"current_value", 6))
	_quest.emit_quest_event(&"events", 1)
	assert_eq(
		_quest.get_quest_state(&"count").get_current_count(),
		3
	)
	assert_true(_quest.refresh_metric(&"query_value"))
	assert_eq(
		calls[0],
		before_calls[0] + 1
	)


func test_restore_diagnostics_reject_graphs_and_revalidate_input_and_catalog() -> void:
	_define(
		&"a",
		&"events",
		{ "target": 10 }
	)
	_define(
		&"b",
		&"events",
		{ "target": 10 }
	)
	assert_true(_quest.accept_quest(&"a"))
	_quest.emit_quest_event(&"events", 2)
	var before: Dictionary = _quest.export_snapshot()
	var candidate: Dictionary = before.duplicate(true)
	var records: Array = candidate["states"]
	var first: Dictionary = records[0]
	var second: Dictionary = records[1]
	var valid: Dictionary = _quest.validate_restore_snapshot(candidate)
	assert_true(GFVariantData.get_option_bool(valid, "ok"))
	first["parent_id"] = "b"
	second["parent_id"] = "a"
	var cycle: Dictionary = _quest.validate_restore_snapshot(candidate)
	assert_eq(
		GFVariantData.get_option_string(cycle, "error_kind"),
		"cycle"
	)
	assert_eq(
		GFVariantData.get_option_string(cycle, "path"),
		"/snapshot/states/0/parent_id"
	)
	valid["ok"] = true
	assert_false(_quest.restore_snapshot(candidate))
	assert_eq(
		_quest.export_snapshot(),
		before
	)
	second["parent_id"] = "missing"
	var missing: Dictionary = _quest.validate_restore_snapshot(candidate)
	assert_eq(
		GFVariantData.get_option_string(missing, "error_kind"),
		"missing_parent"
	)
	assert_eq(
		GFVariantData.get_option_string(missing, "path"),
		"/snapshot/states/1/parent_id"
	)
	var oversized: Array = []
	for _index: int in range(4097):
		oversized.append(null)
	var capacity: Dictionary = _quest.validate_restore_snapshot({ "format_version": 1, "states": oversized })
	assert_eq(
		GFVariantData.get_option_string(capacity, "error_kind"),
		"state_limit"
	)
	assert_eq(
		GFVariantData.get_option_int(capacity, "limit"),
		4096
	)
	assert_eq(
		GFVariantData.get_option_int(capacity, "observed"),
		4097
	)
	assert_true(
		GFVariantData.get_option_bool(
			_quest.validate_restore_snapshot(before),
			"ok"
		)
	)
	_quest.init()
	var empty_catalog: Dictionary = _quest.validate_restore_snapshot(before)
	assert_eq(
		GFVariantData.get_option_string(empty_catalog, "error_kind"),
		"unknown_quest"
	)
	assert_eq(
		GFVariantData.get_option_string(empty_catalog, "path"),
		"/snapshot/states/0/definition/quest_id"
	)
	assert_false(_quest.restore_snapshot(before))


func test_definition_is_strict_and_owns_nested_metadata() -> void:
	var metadata: Dictionary = {
		"ui": { "label": "before" },
	}
	var definition: GFQuestDefinition = GFQuestDefinition.create(
		&"q",
		&"m",
		{ "metadata": metadata }
	)
	metadata["ui"] = { "label": "after" }
	assert_eq(
		GFVariantData.get_option_dictionary(
			definition.to_record(),
			"metadata"
		),
		{
			"ui": { "label": "before" },
		}
	)
	var copy: Dictionary = definition.to_record()
	copy["target"] = 999
	assert_eq(
		definition.get_target(),
		1
	)
	assert_null(GFQuestDefinition.create(&" q", &"m"))
	assert_null(
		GFQuestDefinition.create(
			&"q",
			&"m",
			{ "target": 1.0 }
		)
	)
	assert_null(
		GFQuestDefinition.create(
			&"q",
			&"m",
			{ "target": -1 }
		)
	)
	assert_null(
		GFQuestDefinition.create(
			&"q",
			&"m",
			{ "mode": "unknown" }
		)
	)
	assert_null(
		GFQuestDefinition.create(
			&"q",
			&"m",
			{
				"metadata": { "callback": Callable(self, "before_each") },
			}
		)
	)
	assert_null(
		GFQuestDefinition.create(
			&"q",
			&"m",
			{ "implicit": true }
		)
	)
	assert_null(GFQuestDefinition.from_record({ "quest_id": "q", "metric_id": "m" }))


func test_published_definition_does_not_change_accepted_version() -> void:
	_define(
		&"active",
		&"m",
		{ "target": 3 }
	)
	_define(
		&"available",
		&"m",
		{ "target": 3 }
	)
	assert_true(_quest.accept_quest(&"active"))
	assert_true(
		_quest.define_quest(
			GFQuestDefinition.create(
				&"active",
				&"other",
				{ "version": 2, "target": 99 }
			)
		)
	)
	assert_true(
		_quest.define_quest(
			GFQuestDefinition.create(
				&"available",
				&"other",
				{ "version": 2, "target": 99 }
			)
		)
	)
	assert_false(
		_quest.define_quest(
			GFQuestDefinition.create(
				&"active",
				&"m",
				{ "target": 3 }
			)
		)
	)
	assert_false(
		_quest.define_quest(
			GFQuestDefinition.create(
				&"active",
				&"other",
				{ "version": 2, "target": 100 }
			)
		)
	)
	_quest.emit_quest_event(&"m", 3)
	assert_true(_quest.is_quest_completed(&"active"))
	assert_eq(
		_quest.get_quest_state(&"active").get_definition().get_version(),
		1
	)
	assert_eq(
		_quest.get_quest_state(&"available").get_definition().get_target(),
		99
	)


func test_history_reads_existing_facts_and_accumulator_ignores_preacceptance() -> void:
	assert_true(_quest.set_metric_value(&"m", 20))
	_define(
		&"historical",
		&"m",
		{ "mode": "history", "target": 10 }
	)
	_define(
		&"accumulated",
		&"m",
		{ "target": 10 }
	)
	_quest.emit_quest_event(&"m", 20)
	assert_true(_quest.accept_quest(&"historical"))
	assert_true(_quest.is_quest_completed(&"historical"))
	assert_true(_quest.accept_quest(&"accumulated"))
	assert_eq(
		_quest.get_quest_state(&"accumulated").get_current_count(),
		0
	)
	_quest.emit_quest_event(&"m", 10)
	assert_true(_quest.is_quest_completed(&"accumulated"))


func test_current_defaults_manual_and_loses_eligibility_when_value_drops() -> void:
	var source: Array[int] = [5]
	var query: Callable = func() -> int:
		return source[0]
	assert_true(_quest.register_metric_query(&"m", query))
	_define(
		&"q",
		&"m",
		{ "mode": "current", "target": 5 }
	)
	assert_true(_quest.accept_quest(&"q"))
	assert_true(_quest.is_quest_eligible(&"q"))
	assert_false(_quest.is_quest_completed(&"q"))
	source[0] = 4
	assert_false(
		_quest.complete_quest(&"q"),
		"确认必须重新查询，不能使用旧达标缓存。"
	)
	assert_false(_quest.is_quest_eligible(&"q"))
	source[0] = 5
	assert_true(_quest.complete_quest(&"q"))
	source[0] = 0
	assert_true(_quest.refresh_metric(&"m"))
	assert_true(
		_quest.is_quest_completed(&"q"),
		"完成是持久事实，不随当前值下降撤销。"
	)


func test_current_can_explicitly_complete_on_first_satisfied_sample() -> void:
	_define(
		&"q",
		&"m",
		{
			"mode": "current",
			"completion": "automatic",
			"target": 2,
		}
	)
	assert_true(_quest.accept_quest(&"q"))
	assert_false(_quest.is_quest_eligible(&"q"))
	assert_true(_quest.set_metric_value(&"m", 2))
	assert_true(_quest.is_quest_completed(&"q"))
	assert_true(_quest.set_metric_value(&"m", 0))
	assert_true(_quest.is_quest_completed(&"q"))


func test_manual_accumulation_requires_threshold_and_explicit_confirmation() -> void:
	_define(
		&"q",
		&"m",
		{
			"target": 2,
			"completion": "manual",
			"allow_negative": true,
		}
	)
	assert_true(_quest.accept_quest(&"q"))
	assert_false(_quest.complete_quest(&"q"))
	_quest.emit_quest_event(&"m", 2)
	assert_true(_quest.is_quest_eligible(&"q"))
	assert_false(_quest.is_quest_completed(&"q"))
	_quest.emit_quest_event(&"m", -1)
	assert_false(_quest.complete_quest(&"q"))
	_quest.emit_quest_event(&"m", 1)
	assert_true(_quest.complete_quest(&"q"))


func test_external_completion_needs_no_counter_but_honors_blockers() -> void:
	_define(
		&"q",
		&"",
		{ "completion": "external" }
	)
	var allowed: Array[bool] = [false]
	var blocker: Callable = func(_id: StringName, _report: Dictionary) -> bool:
		return allowed[0]
	_quest.add_completion_blocker(&"q", blocker)
	assert_false(_quest.complete_quest(&"q"))
	assert_true(_quest.accept_quest(&"q"))
	assert_false(_quest.complete_quest(&"q"))
	allowed[0] = true
	assert_true(_quest.complete_quest(&"q"))
	assert_eq(
		_quest.get_quest_state(&"q").get_current_count(),
		0
	)
	assert_eq(
		_quest.get_quest_progress(&"q"),
		1.0
	)


func test_invalid_query_values_and_source_removal_fail_closed() -> void:
	var source: Array[Variant] = [4]
	var query: Callable = func() -> Variant:
		return source[0]
	assert_true(_quest.register_metric_query(&"m", query))
	_define(
		&"q",
		&"m",
		{ "mode": "current", "target": 4 }
	)
	assert_true(_quest.accept_quest(&"q"))
	for invalid: Variant in [
		4.0,
		null,
		{ "amount": 4 },
		true,
	]:
		source[0] = invalid
		assert_false(_quest.complete_quest(&"q"))
		assert_false(_quest.is_quest_eligible(&"q"))
	_quest.clear_metric_source(&"m")
	assert_false(_quest.refresh_metric(&"m"))
	assert_true(_quest.set_metric_value(&"m", 4))
	assert_true(_quest.complete_quest(&"q"))


func test_refresh_only_queries_requested_metric_and_refuses_mixed_sources() -> void:
	var calls: Array[int] = [0, 0]
	var query_a: Callable = func() -> int:
		calls[0] += 1
		return 1
	var query_b: Callable = func() -> int:
		calls[1] += 1
		return 2
	assert_true(_quest.register_metric_query(&"a", query_a))
	assert_true(_quest.register_metric_query(&"b", query_b))
	assert_true(_quest.refresh_metric(&"a"))
	assert_eq(
		calls,
		[1, 0]
	)
	assert_false(_quest.set_metric_value(&"a", 99))
	_quest.clear_metric_source(&"a")
	assert_true(_quest.set_metric_value(&"a", 99))


func test_query_registration_refuses_explicit_value_until_source_is_cleared() -> void:
	_define(
		&"q",
		&"m",
		{ "mode": "current", "target": 4 }
	)
	assert_true(_quest.set_metric_value(&"m", 4))
	assert_true(_quest.accept_quest(&"q"))
	var calls: Array[int] = [0]
	var query: Callable = func() -> int:
		calls[0] += 1
		return 1
	assert_false(_quest.register_metric_query(&"m", query))
	assert_true(_quest.is_quest_eligible(&"q"))
	assert_eq(
		_quest.get_quest_state(&"q").get_current_count(),
		4
	)
	assert_true(_quest.refresh_metric(&"m"))
	assert_eq(
		calls[0],
		0
	)
	assert_true(_quest.set_metric_value(&"m", 5))
	_quest.clear_metric_source(&"m")
	assert_true(_quest.register_metric_query(&"m", query))
	assert_true(_quest.refresh_metric(&"m"))
	assert_eq(
		calls[0],
		1
	)
	assert_eq(
		_quest.get_quest_state(&"q").get_current_count(),
		1
	)
	assert_false(_quest.is_quest_eligible(&"q"))


func test_restore_preserves_completed_facts_without_events_or_queries() -> void:
	_define(
		&"done",
		&"m",
		{ "target": 1 }
	)
	_define(
		&"current",
		&"m",
		{ "mode": "current", "target": 1 }
	)
	_define(
		&"count",
		&"m",
		{ "target": 10 }
	)
	assert_true(_quest.set_metric_value(&"m", 1))
	var accepted: Dictionary = {
		"period": "week:3",
		"sample": { "server_msec": 10 },
	}
	assert_true(_quest.accept_quest(&"count", accepted))
	accepted["period"] = "changed"
	assert_true(_quest.accept_quest(&"done"))
	assert_true(_quest.accept_quest(&"current"))
	_quest.emit_quest_event(&"m", 1)
	assert_true(_quest.set_quest_parent(&"count", &"done"))
	var snapshot: Dictionary = _quest.export_snapshot()
	var query_calls: Array[int] = [0]
	var query: Callable = func() -> int:
		query_calls[0] += 1
		return 0
	_quest.clear_metric_source(&"m")
	assert_true(_quest.register_metric_query(&"m", query))
	watch_signals(_quest)
	assert_true(_quest.restore_snapshot(snapshot))
	assert_eq(
		query_calls[0],
		0
	)
	assert_signal_not_emitted(_quest, "quest_started")
	assert_signal_not_emitted(_quest, "quest_progressed")
	assert_signal_not_emitted(_quest, "quest_completed")
	assert_true(_quest.is_quest_completed(&"done"))
	assert_false(_quest.is_quest_eligible(&"current"))
	assert_eq(
		_quest.get_quest_state(&"count").get_current_count(),
		1
	)
	var restored_acceptance: Dictionary = GFVariantData.get_option_dictionary(
		_quest.get_quest_state(&"count").to_record(),
		"acceptance_data"
	)
	assert_eq(
		GFVariantData.get_option_string(restored_acceptance, "period"),
		"week:3"
	)
	assert_eq(
		_quest.get_child_quests(&"done"),
		PackedStringArray(["count"])
	)
	_quest.emit_quest_event(&"m", 2)
	assert_eq(
		_quest.get_quest_state(&"count").get_current_count(),
		3
	)
	assert_true(_quest.refresh_metric(&"m"))
	assert_false(_quest.is_quest_eligible(&"current"))


func test_restore_uses_frozen_accepted_definition_and_latest_available_definition() -> void:
	_define(
		&"active",
		&"m",
		{ "target": 3 }
	)
	_define(
		&"available",
		&"m",
		{ "target": 3 }
	)
	assert_true(_quest.accept_quest(&"active"))
	var snapshot: Dictionary = _quest.export_snapshot()
	assert_true(
		_quest.define_quest(
			GFQuestDefinition.create(
				&"active",
				&"m",
				{ "version": 2, "target": 100 }
			)
		)
	)
	assert_true(
		_quest.define_quest(
			GFQuestDefinition.create(
				&"available",
				&"m",
				{ "version": 2, "target": 100 }
			)
		)
	)
	_define(
		&"new",
		&"m",
		{}
	)
	assert_true(_quest.restore_snapshot(snapshot))
	assert_eq(
		_quest.get_quest_state(&"active").get_definition().get_target(),
		3
	)
	assert_eq(
		_quest.get_quest_state(&"available").get_definition().get_target(),
		100
	)
	assert_eq(
		_quest.get_quest_status(&"new"),
		GFQuestUtility.STATUS_AVAILABLE
	)


func test_restore_rejects_duplicate_unknown_and_cyclic_records_atomically() -> void:
	_define(
		&"a",
		&"m",
		{ "target": 10 }
	)
	_define(
		&"b",
		&"m",
		{ "target": 10 }
	)
	assert_true(_quest.accept_quest(&"a"))
	_quest.emit_quest_event(&"m", 2)
	var before: Dictionary = _quest.export_snapshot()
	var duplicate_snapshot: Dictionary = before.duplicate(true)
	var duplicate_records: Array = duplicate_snapshot["states"]
	duplicate_records.append(duplicate_records[0])
	assert_false(_quest.restore_snapshot(duplicate_snapshot))
	var unknown: Dictionary = before.duplicate(true)
	var unknown_records: Array = unknown["states"]
	var unknown_state: Dictionary = unknown_records[0]
	var unknown_definition: Dictionary = unknown_state["definition"]
	unknown_definition["quest_id"] = "missing"
	assert_false(_quest.restore_snapshot(unknown))
	var cyclic: Dictionary = before.duplicate(true)
	var cycle_records: Array = cyclic["states"]
	var first: Dictionary = cycle_records[0]
	var second: Dictionary = cycle_records[1]
	first["parent_id"] = "b"
	second["parent_id"] = "a"
	assert_false(_quest.restore_snapshot(cyclic))
	assert_eq(
		_quest.export_snapshot(),
		before
	)
	_quest.emit_quest_event(&"m", 1)
	assert_eq(
		_quest.get_quest_state(&"a").get_current_count(),
		3
	)


func test_state_rejects_impossible_lifecycle_and_returns_isolated_records() -> void:
	_define(
		&"q",
		&"m",
		{ "target": 2 }
	)
	var state: GFQuestState = _quest.get_quest_state(&"q")
	var invalid: Dictionary = state.to_record()
	invalid["status"] = "completed"
	assert_null(GFQuestState.from_record(invalid))
	invalid["accepted"] = true
	invalid["metric_available"] = true
	assert_null(
		GFQuestState.from_record(invalid),
		"completed 不能保存未达标样本。"
	)
	invalid["current_count"] = 2
	assert_not_null(GFQuestState.from_record(invalid))
	assert_eq(
		state.get_status(),
		GFQuestUtility.STATUS_AVAILABLE
	)


func test_inflight_event_does_not_cross_snapshot_replacement() -> void:
	_define(
		&"a",
		&"m",
		{ "target": 10 }
	)
	_define(
		&"b",
		&"m",
		{ "target": 10 }
	)
	assert_true(_quest.accept_quest(&"a"))
	assert_true(_quest.accept_quest(&"b"))
	var snapshot: Dictionary = _quest.export_snapshot()
	var _connected: int = _quest.quest_progressed.connect(
		func(
			id: StringName,
			_value: int,
			_target: int
		) -> void:
			if id == &"a":
				assert_true(_quest.restore_snapshot(snapshot))
	)
	_quest.emit_quest_event(&"m", 2)
	assert_eq(
		_quest.get_quest_state(&"a").get_current_count(),
		0
	)
	assert_eq(
		_quest.get_quest_state(&"b").get_current_count(),
		0
	)


func test_cancelled_and_failed_states_roundtrip_without_reopening() -> void:
	_define(
		&"cancelled",
		&"m",
		{}
	)
	_define(
		&"failed",
		&"m",
		{ "allow_negative": true }
	)
	assert_true(_quest.cancel_quest(&"cancelled"))
	assert_true(_quest.accept_quest(&"failed"))
	_quest.emit_quest_event(&"m", -1)
	assert_true(_quest.fail_quest(&"failed", "project_rule"))
	var snapshot: Dictionary = _quest.export_snapshot()
	assert_true(_quest.restore_snapshot(snapshot))
	assert_eq(
		_quest.get_quest_status(&"cancelled"),
		GFQuestUtility.STATUS_CANCELLED
	)
	assert_eq(
		_quest.get_quest_status(&"failed"),
		GFQuestUtility.STATUS_FAILED
	)
	assert_eq(
		_quest.get_quest_state(&"failed").get_current_count(),
		-1
	)
	assert_eq(
		GFVariantData.get_option_string(
			_quest.get_quest_state(&"failed").to_record(),
			"failure_reason"
		),
		"project_rule"
	)
	assert_false(_quest.accept_quest(&"cancelled"))
	assert_false(_quest.complete_quest(&"failed"))


func test_query_reentry_cannot_apply_result_to_restored_state() -> void:
	_define(
		&"q",
		&"m",
		{ "mode": "current", "target": 1 }
	)
	assert_true(_quest.accept_quest(&"q"))
	var snapshot: Dictionary = _quest.export_snapshot()
	var query: Callable = func() -> int:
		assert_true(_quest.restore_snapshot(snapshot))
		return 99
	assert_true(_quest.register_metric_query(&"m", query))
	assert_false(_quest.refresh_metric(&"m"))
	assert_false(_quest.is_quest_eligible(&"q"))
	assert_eq(
		_quest.get_quest_state(&"q").get_current_count(),
		0
	)


func test_new_input_in_progress_callback_wins_for_every_affected_quest() -> void:
	_define(
		&"a",
		&"m",
		{ "mode": "current", "target": 10 }
	)
	_define(
		&"b",
		&"m",
		{ "mode": "current", "target": 10 }
	)
	assert_true(_quest.accept_quest(&"a"))
	assert_true(_quest.accept_quest(&"b"))
	var _connected: int = _quest.quest_progressed.connect(
		func(
			id: StringName,
			value: int,
			_target: int
		) -> void:
			if id == &"a" and value == 10:
				assert_true(_quest.set_metric_value(&"m", 1))
	)
	var observed: Array[int] = []
	var observer: Callable = func(
		id: StringName,
		value: int,
		_target: int
	) -> void:
		if id == &"a":
			observed.append(value)
	var _observing: int = _quest.quest_progressed.connect(observer)
	assert_true(_quest.set_metric_value(&"m", 10))
	assert_eq(
		observed,
		[10, 1]
	)
	assert_eq(
		_quest.get_quest_state(&"a").get_current_count(),
		1
	)
	assert_eq(
		_quest.get_quest_state(&"b").get_current_count(),
		1
	)
	assert_false(_quest.is_quest_eligible(&"b"))


func test_progress_feedback_is_bounded_and_restore_discards_pending_notifications() -> void:
	_define(
		&"q",
		&"m",
		{ "mode": "current", "target": 1000 }
	)
	assert_true(_quest.accept_quest(&"q"))
	var snapshot: Dictionary = _quest.export_snapshot()
	var observed: Array[int] = []
	var feedback: Callable = func(
		_id: StringName,
		value: int,
		_target: int
	) -> void:
		if value < 260:
			assert_true(
				_quest.set_metric_value(
					&"m",
					value + 1
				)
			)
	var observe: Callable = func(
		_id: StringName,
		value: int,
		_target: int
	) -> void:
		observed.append(value)
	var _first: int = _quest.quest_progressed.connect(feedback)
	var _second: int = _quest.quest_progressed.connect(observe)
	assert_true(_quest.set_metric_value(&"m", 1))
	assert_eq(
		observed.size(),
		256
	)
	_quest.tick(0.0)
	assert_eq(
		observed[-1],
		260
	)
	assert_eq(
		_quest.get_quest_state(&"q").get_current_count(),
		260
	)
	assert_true(_quest.set_metric_value(&"m", 1))
	var emitted: int = observed.size()
	assert_true(_quest.restore_snapshot(snapshot))
	_quest.tick(0.0)
	assert_eq(
		observed.size(),
		emitted
	)
	assert_eq(
		_quest.get_quest_state(&"q").get_current_count(),
		0
	)


func test_query_remains_guarded_while_publishing_its_result() -> void:
	_define(
		&"q",
		&"m",
		{ "mode": "current", "target": 100 }
	)
	assert_true(_quest.accept_quest(&"q"))
	var calls: Array[int] = [0]
	var nested_results: Array[bool] = []
	var query: Callable = func() -> int:
		calls[0] += 1
		return calls[0]
	assert_true(_quest.register_metric_query(&"m", query))
	var _connected: int = _quest.quest_progressed.connect(
		func(
			_id: StringName,
			_value: int,
			_target: int
		) -> void:
			if calls[0] < 3:
				nested_results.append(_quest.refresh_metric(&"m"))
	)
	assert_true(_quest.refresh_metric(&"m"))
	assert_eq(
		calls[0],
		1
	)
	assert_eq(
		nested_results,
		[false]
	)


func test_queued_query_notification_keeps_same_metric_refresh_guard() -> void:
	_define(
		&"a",
		&"m_a",
		{ "mode": "current", "target": 1000 }
	)
	_define(
		&"b",
		&"m_b",
		{ "mode": "current", "target": 1000 }
	)
	assert_true(_quest.accept_quest(&"a"))
	assert_true(_quest.accept_quest(&"b"))
	var calls: Array[int] = [0]
	var nested_results: Array[bool] = []
	var query: Callable = func() -> int:
		calls[0] += 1
		return calls[0]
	assert_true(_quest.register_metric_query(&"m_b", query))
	var feedback: Callable = func(
		_id: StringName,
		_value: int,
		_target: int
	) -> void:
		if calls[0] < 3:
			nested_results.append(_quest.refresh_metric(&"m_b"))
	var _connected: int = _quest.quest_progressed.connect(feedback)
	assert_true(_quest.set_metric_value(&"m_a", 1))
	assert_eq(
		calls[0],
		1
	)
	assert_eq(
		nested_results,
		[true, false]
	)
	_quest.tick(0.0)
	assert_eq(
		calls[0],
		1
	)
	_quest.quest_progressed.disconnect(feedback)


func test_completion_blocker_can_invalidate_previously_satisfied_metric() -> void:
	_define(
		&"q",
		&"m",
		{ "mode": "current", "target": 10 }
	)
	assert_true(_quest.set_metric_value(&"m", 10))
	assert_true(_quest.accept_quest(&"q"))
	_quest.add_completion_blocker(
		&"q",
		func(_id: StringName, _report: Dictionary) -> bool:
			assert_true(_quest.set_metric_value(&"m", 1))
			return true
	)
	assert_false(_quest.complete_quest(&"q"))
	assert_eq(
		_quest.get_quest_status(&"q"),
		GFQuestUtility.STATUS_ACTIVE
	)


func test_acceptance_reentry_that_replaces_definition_must_retry() -> void:
	_define(
		&"q",
		&"m",
		{ "target": 1 }
	)
	_quest.add_acceptance_condition(
		&"q",
		func(_id: StringName, _report: Dictionary) -> bool:
			assert_true(
				_quest.define_quest(
					GFQuestDefinition.create(
						&"q",
						&"m",
						{ "version": 2, "target": 2 }
					)
				)
			)
			return true
	)
	assert_false(_quest.accept_quest(&"q"))
	assert_eq(
		_quest.get_quest_status(&"q"),
		GFQuestUtility.STATUS_AVAILABLE
	)
	_quest.clear_acceptance_conditions(&"q")
	assert_true(_quest.accept_quest(&"q"))
	assert_eq(
		_quest.get_quest_state(&"q").get_definition().get_version(),
		2
	)


func test_recursive_completion_cannot_commit_twice() -> void:
	_define(
		&"q",
		&"",
		{ "completion": "external" }
	)
	assert_true(_quest.accept_quest(&"q"))
	_quest.add_completion_blocker(
		&"q",
		func(id: StringName, _report: Dictionary) -> bool:
			assert_false(_quest.complete_quest(id))
			return true
	)
	watch_signals(_quest)
	assert_true(_quest.complete_quest(&"q"))
	assert_signal_emit_count(
		_quest,
		"quest_completed",
		1
	)


func test_negative_integer_progress_saturates_without_wrapping_positive() -> void:
	_define(
		&"q",
		&"m",
		{ "target": 1, "allow_negative": true }
	)
	assert_true(_quest.accept_quest(&"q"))
	_quest.emit_quest_event(
		&"m",
		-9223372036854775807 - 1
	)
	_quest.emit_quest_event(&"m", -1)
	assert_eq(
		_quest.get_quest_state(&"q").get_current_count(),
		-9223372036854775807 - 1
	)
	assert_false(_quest.is_quest_completed(&"q"))


func test_valid_metadata_and_acceptance_budgets_fit_a_roundtrippable_state() -> void:
	_define(
		&"q",
		&"m",
		{
			"metadata": { "data": "m".repeat(64000) },
		}
	)
	assert_true(
		_quest.accept_quest(
			&"q",
			{ "data": "a".repeat(64000) }
		)
	)
	assert_true(
		_quest.fail_quest(
			&"q",
			"x".repeat(4096)
		)
	)
	assert_not_null(_quest.get_quest_state(&"q"))
	var snapshot: Dictionary = _quest.export_snapshot()
	assert_false(snapshot.is_empty())
	assert_true(_quest.restore_snapshot(snapshot))
	assert_eq(
		_quest.get_quest_status(&"q"),
		GFQuestUtility.STATUS_FAILED
	)


func test_restore_checks_acceptance_budget_independently_of_state_budget() -> void:
	_define(
		&"q",
		&"m",
		{}
	)
	assert_true(_quest.accept_quest(&"q"))
	var record: Dictionary = _quest.get_quest_state(&"q").to_record()
	record["acceptance_data"] = { "data": "x".repeat(65530) }
	assert_null(GFQuestState.from_record(record))
	var items: Array[int] = []
	var _resize_error: int = items.resize(2050)
	record["acceptance_data"] = { "items": items }
	assert_null(GFQuestState.from_record(record))


func _define(
	quest_id: StringName,
	metric_id: StringName,
	options: Dictionary
) -> void:
	assert_true(
		_quest.define_quest(
			GFQuestDefinition.create(
				quest_id,
				metric_id,
				options
			)
		)
	)
