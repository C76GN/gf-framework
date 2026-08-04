## 测试 GFTableDataView 的命名行谓词与事务式投影重建。
extends GutTest


class RecordingPredicate extends GFTableRowPredicate:
	var label: String = ""
	var minimum_score: int = -1
	var invocation_log: Array[String] = []


	func _evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
		invocation_log.append("%s:%s" % [label, GFVariantData.to_text(row_view.get_row_id())])
		if minimum_score >= 0 and GFVariantData.to_int(row_view.get_value(&"score")) < minimum_score:
			return GFTableRowPredicateResult.excluded()
		return GFTableRowPredicateResult.included()


class FailingPredicate extends GFTableRowPredicate:
	var failed_row_id: Variant = null
	var error_message: String = ""


	func _evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
		if failed_row_id == null or row_view.get_row_id() == failed_row_id:
			return GFTableRowPredicateResult.failed(&"predicate_fixture_failed", error_message)
		return GFTableRowPredicateResult.included()


class SnapshotMutationPredicate extends GFTableRowPredicate:
	func _evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
		var values: Dictionary = row_view.get_values()
		var tags_value: Variant = GFVariantData.get_option_value(values, &"tags")
		if tags_value is Array:
			var tags: Array = tags_value
			tags.append("mutated")
		values[&"score"] = 999
		return GFTableRowPredicateResult.included()


class ReentrantPredicate extends GFTableRowPredicate:
	var view: GFTableDataView = null
	var inner_result: GFTableViewRebuildResult = null


	func _evaluate(_row_view: GFTableRowView) -> GFTableRowPredicateResult:
		inner_result = view.refresh_view()
		return GFTableRowPredicateResult.included()


class PublicEvaluateOverridePredicate extends GFTableRowPredicate:
	var view: GFTableDataView = null
	var public_evaluate_call_count: int = 0
	var hook_call_count: int = 0
	var inner_result: GFTableViewRebuildResult = null


	func evaluate(_row_view: GFTableRowView) -> GFTableRowPredicateResult:
		public_evaluate_call_count += 1
		inner_result = view.set_filter_query("public-evaluate-reentry")
		return GFTableRowPredicateResult.excluded()


	func _evaluate(_row_view: GFTableRowView) -> GFTableRowPredicateResult:
		hook_call_count += 1
		return GFTableRowPredicateResult.included()


class ReentrantResult extends GFTableRowPredicateResult:
	var view: GFTableDataView = null
	var getter_call_count: int = 0
	var inner_result: GFTableViewRebuildResult = null


	func is_successful() -> bool:
		_attempt_reentry()
		return true


	func should_include() -> bool:
		_attempt_reentry()
		return true


	func get_error_code() -> StringName:
		_attempt_reentry()
		return &"override_error"


	func get_error_message() -> String:
		_attempt_reentry()
		return "override error"


	func _attempt_reentry() -> void:
		getter_call_count += 1
		if inner_result == null:
			inner_result = view.set_filter_query("result-getter-reentry")


class ReentrantResultPredicate extends GFTableRowPredicate:
	var result: ReentrantResult = null


	func _evaluate(_row_view: GFTableRowView) -> GFTableRowPredicateResult:
		return result


class BackingMutationPredicate extends GFTableRowPredicate:
	func _evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
		row_view.set("_row_id", "forged-row")
		row_view.set("_source_row_index", 999)
		var backing_value: Variant = row_view.get("_values")
		if backing_value is Dictionary:
			var backing_values: Dictionary = backing_value
			backing_values[&"score"] = 999
		row_view.set("_values", { &"score": 777 })
		return GFTableRowPredicateResult.included()


class ObservingRowViewPredicate extends GFTableRowPredicate:
	var observed_row_ids: Array = []
	var observed_source_indices: Array[int] = []
	var observed_scores: Array[int] = []


	func _evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
		observed_row_ids.append(row_view.get_row_id())
		observed_source_indices.append(row_view.get_source_row_index())
		observed_scores.append(GFVariantData.to_int(row_view.get_value(&"score")))
		return GFTableRowPredicateResult.failed(
			&"observer_failure",
			"Observer stopped the candidate projection."
		)


class ReconfiguringRowViewPredicate extends GFTableRowPredicate:
	var configure_results: Array[bool] = []
	var observed_row_ids: Array = []
	var observed_scores: Array[int] = []


	func _evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
		configure_results.append(row_view.configure_for_framework(
			999,
			&"hijacked",
			{ &"score": 999 }
		))
		observed_row_ids.append(row_view.get_row_id())
		observed_scores.append(GFVariantData.to_int(row_view.get_value(&"score")))
		return GFTableRowPredicateResult.included()


class UninitializedResultPredicate extends GFTableRowPredicate:
	func _evaluate(_row_view: GFTableRowView) -> GFTableRowPredicateResult:
		return GFTableRowPredicateResult.new()


class RebuildResultMutationObserver extends RefCounted:
	var configure_result: bool = true


	func on_view_rebuild_failed(result: GFTableViewRebuildResult) -> void:
		configure_result = result.configure_success_for_framework(true, 999, 999, 999, 999)
		result.set("_error_code", &"observer_tampered")
		result.set("_error_message", "observer tampered")


class CountingRegistration extends GFTableRowPredicateRegistration:
	var getter_call_count: int = 0


	func get_predicate_id() -> StringName:
		getter_call_count += 1
		return &"counted"


	func get_predicate() -> GFTableRowPredicate:
		getter_call_count += 1
		return null


	func get_order() -> int:
		getter_call_count += 1
		return 0


	func is_enabled() -> bool:
		getter_call_count += 1
		return true


class ReentrantRegistration extends GFTableRowPredicateRegistration:
	var view: GFTableDataView = null
	var getter_call_count: int = 0
	var inner_result: GFTableViewRebuildResult = null


	func get_predicate_id() -> StringName:
		_attempt_reentry()
		return &"override_id"


	func get_predicate() -> GFTableRowPredicate:
		_attempt_reentry()
		return null


	func get_order() -> int:
		_attempt_reentry()
		return -999


	func is_enabled() -> bool:
		_attempt_reentry()
		return false


	func _attempt_reentry() -> void:
		getter_call_count += 1
		if inner_result == null and view != null:
			inner_result = view.set_filter_query("hostile-reentry")


class ScoreFailurePredicate extends GFTableRowPredicate:
	var failed_score: int = 0


	func _evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
		if GFVariantData.to_int(row_view.get_value(&"score")) == failed_score:
			return GFTableRowPredicateResult.failed(
				&"score_rejected",
				"The staged score is rejected."
			)
		return GFTableRowPredicateResult.included()


class ColumnPresenceFailurePredicate extends GFTableRowPredicate:
	var rejected_column_id: StringName = &""


	func _evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
		if row_view.has_value(rejected_column_id):
			return GFTableRowPredicateResult.failed(
				&"column_rejected",
				"The candidate column set is rejected."
			)
		return GFTableRowPredicateResult.included()


class SelectionRebuildObserver extends RefCounted:
	var view: GFTableDataView = null
	var inner_result: GFTableViewRebuildResult = null


	func on_selection_changed(_selected_ids: Array) -> void:
		inner_result = view.set_filter_query("observer-filter")


class ConfigurationMutationPredicate extends GFTableRowPredicate:
	var view: GFTableDataView = null
	var replacement_model: GFTableSelectionModel = null
	var row_id_result: GFTableViewRebuildResult = null
	var case_result: GFTableViewRebuildResult = null
	var selection_model_result: GFTableViewRebuildResult = null


	func _evaluate(_row_view: GFTableRowView) -> GFTableRowPredicateResult:
		row_id_result = view.set_row_id_column(&"account")
		case_result = view.set_filter_case_sensitive(true)
		selection_model_result = view.set_selection_model(replacement_model)
		return GFTableRowPredicateResult.included()


class SelectionStateObserver extends RefCounted:
	var model: GFTableSelectionModel = null
	var emission_count: int = 0
	var observed_ids: Array = []
	var observed_anchor: Variant = null


	func on_selection_changed(selected_ids: Array) -> void:
		emission_count += 1
		observed_ids = selected_ids.duplicate()
		observed_anchor = model.anchor_row_id


class ReentrantFormatter extends RefCounted:
	var view: GFTableDataView = null
	var inner_result: GFTableViewRebuildResult = null


	func format_value(
		_value: Variant,
		_row_data: Variant,
		_column: GFTableColumnDefinition
	) -> String:
		inner_result = view.refresh_view()
		return "matching text"


class CommittingPredicate extends GFTableRowPredicate:
	var view: GFTableDataView = null
	var commit_succeeded: bool = true


	func _evaluate(_row_view: GFTableRowView) -> GFTableRowPredicateResult:
		commit_succeeded = view.commit_cell_value(0, &"score", 777)
		return GFTableRowPredicateResult.included()


class MutablePayload extends RefCounted:
	var amount: int = 1


class PayloadMutationPredicate extends GFTableRowPredicate:
	func _evaluate(row_view: GFTableRowView) -> GFTableRowPredicateResult:
		var payload_value: Variant = row_view.get_value(&"payload")
		if payload_value is MutablePayload:
			var payload: MutablePayload = payload_value
			payload.amount = 999
		return GFTableRowPredicateResult.included()


class ClearingPredicate extends GFTableRowPredicate:
	var view: GFTableDataView = null
	var observed_row_count: int = -1


	func _evaluate(_row_view: GFTableRowView) -> GFTableRowPredicateResult:
		view.clear_rows()
		observed_row_count = view.get_row_count()
		return GFTableRowPredicateResult.included()


class CountingSetter extends RefCounted:
	var invocation_count: int = 0


	func write_value(
		_row_data: Variant,
		_new_value: Variant,
		_column: GFTableColumnDefinition
	) -> bool:
		invocation_count += 1
		return true


class CellPayloadMutationObserver extends RefCounted:
	func on_cell_value_committed(
		_row_index: int,
		_row_id: Variant,
		_column_id: StringName,
		_old_value: Variant,
		new_value: Variant
	) -> void:
		if new_value is Array:
			var new_values: Array = new_value
			new_values.append("observer-mutation")


class RecordingComparator extends RefCounted:
	var invocation_log: Array[String] = []


	func compare_values(
		left_value: Variant,
		right_value: Variant,
		_left_row: Variant,
		_right_row: Variant,
		_column: GFTableColumnDefinition
	) -> int:
		invocation_log.append("sort")
		var left_score: int = GFVariantData.to_int(left_value)
		var right_score: int = GFVariantData.to_int(right_value)
		if left_score == right_score:
			return 0
		return -1 if left_score < right_score else 1


class ScriptedTableRow extends Resource:
	@export var id: String = "scripted-row"
	@export var score: int = 10


func test_predicates_run_after_text_filter_in_deterministic_order_before_sort() -> void:
	var view: GFTableDataView = _make_people_view()
	var trace: Array[String] = []
	var comparator: RecordingComparator = RecordingComparator.new()
	comparator.invocation_log = trace
	view.get_column(&"score").value_comparator = comparator.compare_values
	var predicate_b: RecordingPredicate = RecordingPredicate.new()
	predicate_b.label = "b"
	predicate_b.invocation_log = trace
	var predicate_a: RecordingPredicate = RecordingPredicate.new()
	predicate_a.label = "a"
	predicate_a.invocation_log = trace
	var _filter_result: GFTableViewRebuildResult = view.set_filter_query("a")
	var _sort_result: bool = view.sort_by_column(&"score", true)
	trace.clear()

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"b", predicate_b, 10),
		GFTableRowPredicateRegistration.create(&"a", predicate_a, 10),
	])

	assert_true(result.is_successful(), "有效谓词集合应成功提交。")
	assert_eq(
		trace.slice(0, 4),
		["a:row-a", "b:row-a", "a:row-c", "b:row-c"],
		"文本过滤后应按 order 与稳定 ID 顺序执行谓词。"
	)
	assert_gt(trace.size(), 4, "两个候选行必须实际进入自定义排序比较器。")
	for trace_index: int in range(4, trace.size()):
		assert_eq(trace[trace_index], "sort", "所有排序回调都必须发生在谓词阶段之后。")
	assert_eq(view.get_visible_row_ids(), ["row-c", "row-a"], "谓词完成后才应排序候选投影。")


func test_set_row_predicates_commits_one_rebuild_and_one_revision() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate_a: RecordingPredicate = RecordingPredicate.new()
	predicate_a.label = "a"
	var predicate_b: RecordingPredicate = RecordingPredicate.new()
	predicate_b.label = "b"
	var previous_revision: int = view.get_view_revision()
	watch_signals(view)

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"a", predicate_a, 0),
		GFTableRowPredicateRegistration.create(&"b", predicate_b, 1),
	])

	assert_true(result.is_successful())
	assert_true(result.was_committed())
	assert_eq(view.get_view_revision(), previous_revision + 1, "批量注册只能提交一个 revision。")
	assert_signal_emit_count(view, "view_changed", 1)
	assert_signal_emit_count(view, "view_rebuild_failed", 0)


func test_predicate_failure_preserves_registry_projection_revision_and_selection() -> void:
	var view: GFTableDataView = _make_people_view()
	var failing: FailingPredicate = FailingPredicate.new()
	failing.failed_row_id = "row-a"
	failing.error_message = "x".repeat(2_000)
	var setup_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"failing", failing, 0, false),
	])
	assert_true(setup_result.is_successful())
	var _selection_result: bool = view.get_selection_model().set_selected("row-a", true)
	var previous_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()
	watch_signals(view)

	var result: GFTableViewRebuildResult = view.set_row_predicate_enabled(&"failing", true)

	assert_false(result.is_successful(), "谓词显式失败应中止重建。")
	assert_eq(result.get_error_code(), &"predicate_fixture_failed")
	assert_eq(result.get_failed_predicate_id(), &"failing")
	assert_true(GFVariantData.values_equal(result.get_failed_row_id(), "row-a"))
	assert_eq(result.get_error_message().length(), 1_024, "诊断说明必须有界。")
	assert_eq(view.get_visible_row_ids(), previous_ids, "失败必须保留 prior projection。")
	assert_eq(view.get_view_revision(), previous_revision, "失败不得推进 revision。")
	assert_false(view.get_row_predicate(&"failing").is_enabled(), "失败必须回滚候选 enablement。")
	assert_true(view.get_selection_model().is_selected("row-a"), "失败不得改变稳定 ID 选择。")
	assert_true(
		GFVariantData.values_equal(view.get_selection_model().anchor_row_id, "row-a"),
		"失败不得改变选择 anchor。"
	)
	assert_signal_emit_count(view, "view_changed", 0)
	assert_signal_emit_count(view, "view_rebuild_failed", 1)


func test_framework_evaluation_bypasses_overridden_public_evaluate() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate: PublicEvaluateOverridePredicate = PublicEvaluateOverridePredicate.new()
	predicate.view = view
	var previous_revision: int = view.get_view_revision()
	watch_signals(view)

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"template_method", predicate),
	])

	assert_true(result.is_successful())
	assert_eq(predicate.public_evaluate_call_count, 0)
	assert_eq(predicate.hook_call_count, view.get_row_count())
	assert_null(predicate.inner_result)
	assert_eq(view.get_filter_query(), "")
	assert_eq(view.get_view_revision(), previous_revision + 1)
	assert_signal_emit_count(view, "view_changed", 1)
	assert_signal_emit_count(view, "filter_changed", 0)


func test_framework_normalizes_result_without_calling_overridden_getters() -> void:
	var view: GFTableDataView = _make_people_view()
	var _single_row_result: GFTableViewRebuildResult = view.set_rows([
		{ "id": "row-a", "name": "Alice", "score": 10, "account": "p1", "tags": [] },
	])
	var hostile_result: ReentrantResult = ReentrantResult.new()
	hostile_result.view = view
	hostile_result.set("_configured", true)
	hostile_result.set("_successful", true)
	hostile_result.set("_should_include", true)
	var predicate: ReentrantResultPredicate = ReentrantResultPredicate.new()
	predicate.result = hostile_result
	var previous_revision: int = view.get_view_revision()
	watch_signals(view)

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"normalized_result", predicate),
	])

	assert_true(result.is_successful())
	assert_eq(hostile_result.getter_call_count, 0)
	assert_null(hostile_result.inner_result)
	assert_eq(view.get_filter_query(), "")
	assert_eq(view.get_view_revision(), previous_revision + 1)
	assert_signal_emit_count(view, "view_changed", 1)
	assert_signal_emit_count(view, "filter_changed", 0)


func test_each_predicate_receives_an_independent_row_view_snapshot() -> void:
	var view: GFTableDataView = _make_people_view()
	var observer: ObservingRowViewPredicate = ObservingRowViewPredicate.new()
	var previous_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(
			&"mutator",
			BackingMutationPredicate.new(),
			0
		),
		GFTableRowPredicateRegistration.create(&"observer", observer, 1),
	])

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"observer_failure")
	assert_true(GFVariantData.values_equal(result.get_failed_row_id(), "row-a"))
	assert_eq(observer.observed_row_ids, ["row-a"])
	assert_eq(observer.observed_source_indices, [0])
	assert_eq(observer.observed_scores, [10])
	assert_eq(view.get_visible_row_ids(), previous_ids)
	assert_eq(view.get_view_revision(), previous_revision)


func test_invalid_duplicate_and_over_limit_registrations_preserve_prior_state() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate: RecordingPredicate = RecordingPredicate.new()
	var initial_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"initial", predicate),
	])
	assert_true(initial_result.is_successful())
	var _selection_result: bool = view.get_selection_model().set_selected("row-a", true)
	var previous_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()
	var previous_selection: Array = view.get_selection_model().get_selected_ids()
	var previous_anchor: Variant = view.get_selection_model().anchor_row_id

	var duplicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"duplicate", predicate),
		GFTableRowPredicateRegistration.create(&"duplicate", predicate),
	])
	assert_false(duplicate_result.is_successful())
	assert_eq(duplicate_result.get_error_code(), &"duplicate_predicate_id")

	var registrations: Array[GFTableRowPredicateRegistration] = []
	var counting_registration: CountingRegistration = CountingRegistration.new()
	for index: int in range(GFTableDataView.MAX_ROW_PREDICATE_COUNT + 1):
		registrations.append(counting_registration)
	var limit_result: GFTableViewRebuildResult = view.set_row_predicates(registrations)
	assert_false(limit_result.is_successful())
	assert_eq(limit_result.get_error_code(), &"predicate_limit_exceeded")
	assert_eq(
		counting_registration.getter_call_count,
		0,
		"超限 registry 必须在 snapshot 或调用任一候选 getter 前失败关闭。"
	)
	assert_eq(view.get_row_predicate_ids(), [&"initial"])
	assert_eq(view.get_visible_row_ids(), previous_ids)
	assert_eq(view.get_view_revision(), previous_revision)
	assert_eq(view.get_selection_model().get_selected_ids(), previous_selection)
	assert_true(
		GFVariantData.values_equal(view.get_selection_model().anchor_row_id, previous_anchor)
	)


func test_registration_subclass_getters_cannot_reenter_bulk_commit() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate: RecordingPredicate = RecordingPredicate.new()
	var registration: ReentrantRegistration = ReentrantRegistration.new()
	registration.view = view
	registration.set("_predicate_id", &"bulk_safe")
	registration.set("_predicate", predicate)
	registration.set("_order", 7)
	registration.set("_enabled", true)
	var previous_revision: int = view.get_view_revision()
	watch_signals(view)

	var result: GFTableViewRebuildResult = view.set_row_predicates([registration])

	assert_true(result.is_successful())
	assert_eq(registration.getter_call_count, 0, "候选 override getter 不得进入事务边界。")
	assert_null(registration.inner_result)
	assert_eq(view.get_filter_query(), "", "候选 getter 不得重入提交过滤状态。")
	assert_eq(view.get_row_predicate_ids(), [&"bulk_safe"])
	assert_eq(view.get_view_revision(), previous_revision + 1)
	assert_signal_emit_count(view, "view_changed", 1)
	assert_signal_emit_count(view, "filter_changed", 0)

	var invalid_registration: ReentrantRegistration = ReentrantRegistration.new()
	invalid_registration.view = view
	var committed_revision: int = view.get_view_revision()
	var invalid_result: GFTableViewRebuildResult = view.set_row_predicates([
		invalid_registration,
	])
	assert_false(invalid_result.is_successful())
	assert_eq(invalid_registration.getter_call_count, 0)
	assert_null(invalid_registration.inner_result)
	assert_eq(view.get_filter_query(), "")
	assert_eq(view.get_row_predicate_ids(), [&"bulk_safe"])
	assert_eq(view.get_view_revision(), committed_revision)
	assert_signal_emit_count(view, "view_changed", 1)


func test_register_row_predicate_delegates_to_base_field_snapshot() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate: RecordingPredicate = RecordingPredicate.new()
	var registration: ReentrantRegistration = ReentrantRegistration.new()
	registration.view = view
	registration.set("_predicate_id", &"register_safe")
	registration.set("_predicate", predicate)
	registration.set("_order", 3)
	registration.set("_enabled", true)
	var previous_revision: int = view.get_view_revision()
	watch_signals(view)

	var result: GFTableViewRebuildResult = view.register_row_predicate(registration)

	assert_true(result.is_successful())
	assert_eq(registration.getter_call_count, 0)
	assert_null(registration.inner_result)
	assert_eq(view.get_filter_query(), "")
	assert_eq(view.get_row_predicate_ids(), [&"register_safe"])
	assert_eq(view.get_view_revision(), previous_revision + 1)
	assert_signal_emit_count(view, "view_changed", 1)
	assert_signal_emit_count(view, "filter_changed", 0)


func test_predicate_receives_isolated_row_view() -> void:
	var view: GFTableDataView = _make_people_view()
	var mutation_predicate: SnapshotMutationPredicate = SnapshotMutationPredicate.new()

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"mutation", mutation_predicate),
	])

	assert_true(result.is_successful())
	var row_value: Variant = view.get_row(0)
	assert_true(row_value is Dictionary)
	if row_value is Dictionary:
		var row: Dictionary = row_value
		assert_eq(GFVariantData.get_option_int(row, &"score"), 10, "RowView 值修改不得写回源 row。")
		assert_eq(GFVariantData.get_option_array(row, &"tags"), ["alpha"], "嵌套集合也必须隔离。")


func test_set_rows_prunes_selection_only_after_successful_projection() -> void:
	var view: GFTableDataView = _make_people_view()
	var failing: FailingPredicate = FailingPredicate.new()
	failing.failed_row_id = "row-new"
	var predicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"conditional_failure", failing),
	])
	assert_true(predicate_result.is_successful())
	var _selection_result: bool = view.get_selection_model().set_selected("row-a", true)
	var previous_revision: int = view.get_view_revision()

	var failed_result: GFTableViewRebuildResult = view.set_rows([
		{ "id": "row-new", "name": "New", "score": 1, "account": "p1", "tags": [] },
	])

	assert_false(failed_result.is_successful())
	assert_eq(view.get_row_ids(), ["row-a", "row-b", "row-c"], "失败的 source transition 不得替换源行。")
	assert_true(view.get_selection_model().is_selected("row-a"), "失败不得提前 prune selection。")
	assert_eq(view.get_view_revision(), previous_revision)

	var unregister_result: GFTableViewRebuildResult = view.unregister_row_predicate(&"conditional_failure")
	assert_true(unregister_result.is_successful())
	var success_result: GFTableViewRebuildResult = view.set_rows([
		{ "id": "row-new", "name": "New", "score": 1, "account": "p1", "tags": [] },
	])
	assert_true(success_result.is_successful())
	assert_false(view.get_selection_model().is_selected("row-a"), "成功提交后才应按新 source IDs prune。")


func test_append_row_predicate_failure_preserves_all_committed_state() -> void:
	var view: GFTableDataView = _make_people_view()
	var failing: FailingPredicate = FailingPredicate.new()
	failing.failed_row_id = "not-present"
	var predicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"append_guard", failing),
	])
	assert_true(predicate_result.is_successful())
	var _selection_result: bool = view.get_selection_model().set_selected("row-a", true)
	var previous_row_ids: Array = view.get_row_ids()
	var previous_visible_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()
	failing.failed_row_id = "row-new"

	var appended_index: int = view.append_row({
		"id": "row-new",
		"name": "New",
		"score": 1,
		"account": "p3",
		"tags": [],
	})

	assert_eq(appended_index, -1)
	assert_eq(view.get_row_ids(), previous_row_ids)
	assert_eq(view.get_visible_row_ids(), previous_visible_ids)
	assert_eq(view.get_view_revision(), previous_revision)
	assert_true(view.get_selection_model().is_selected("row-a"))
	assert_true(GFVariantData.values_equal(view.get_selection_model().anchor_row_id, "row-a"))


func test_remove_row_predicate_failure_preserves_all_committed_state() -> void:
	var view: GFTableDataView = _make_people_view()
	var failing: FailingPredicate = FailingPredicate.new()
	failing.failed_row_id = "not-present"
	var predicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"remove_guard", failing),
	])
	assert_true(predicate_result.is_successful())
	var _selection_result: bool = view.get_selection_model().set_selected("row-a", true)
	var previous_row_ids: Array = view.get_row_ids()
	var previous_visible_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()
	failing.failed_row_id = "row-b"

	var removed: bool = view.remove_row(0)

	assert_false(removed)
	assert_eq(view.get_row_ids(), previous_row_ids)
	assert_eq(view.get_visible_row_ids(), previous_visible_ids)
	assert_eq(view.get_view_revision(), previous_revision)
	assert_true(view.get_selection_model().is_selected("row-a"))
	assert_true(GFVariantData.values_equal(view.get_selection_model().anchor_row_id, "row-a"))


func test_clear_rows_requested_from_predicate_fails_without_partial_state() -> void:
	var view: GFTableDataView = _make_people_view()
	var _selection_result: bool = view.get_selection_model().set_selected("row-a", true)
	var previous_row_ids: Array = view.get_row_ids()
	var previous_visible_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()
	var predicate: ClearingPredicate = ClearingPredicate.new()
	predicate.view = view

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"clear_attempt", predicate),
	])

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"reentrant_rebuild")
	assert_eq(predicate.observed_row_count, 3)
	assert_eq(view.get_row_ids(), previous_row_ids)
	assert_eq(view.get_visible_row_ids(), previous_visible_ids)
	assert_eq(view.get_view_revision(), previous_revision)
	assert_true(view.get_selection_model().is_selected("row-a"))
	assert_true(view.get_row_predicate_ids().is_empty())


func test_reentrant_rebuild_aborts_outer_transaction() -> void:
	var view: GFTableDataView = _make_people_view()
	var reentrant: ReentrantPredicate = ReentrantPredicate.new()
	reentrant.view = view
	var previous_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()
	watch_signals(view)

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"reentrant", reentrant),
	])

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"reentrant_rebuild")
	assert_not_null(reentrant.inner_result)
	assert_false(reentrant.inner_result.is_successful())
	assert_true(view.get_row_predicate_ids().is_empty(), "失败的候选 registry 不得泄漏。")
	assert_eq(view.get_visible_row_ids(), previous_ids)
	assert_eq(view.get_view_revision(), previous_revision)
	assert_signal_emit_count(view, "view_changed", 0)
	assert_signal_emit_count(view, "view_rebuild_failed", 1)


func test_configuration_setters_fail_closed_during_predicate_evaluation() -> void:
	var view: GFTableDataView = _make_people_view()
	var authoritative_model: GFTableSelectionModel = view.get_selection_model()
	var _selection_result: bool = authoritative_model.set_selected("row-a", true)
	var replacement_model: GFTableSelectionModel = GFTableSelectionModel.new()
	var _replacement_selection_result: bool = replacement_model.set_selected("row-b", true)
	var predicate: ConfigurationMutationPredicate = ConfigurationMutationPredicate.new()
	predicate.view = view
	predicate.replacement_model = replacement_model
	var previous_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"configuration_mutation", predicate),
	])

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"reentrant_rebuild")
	for inner_result: GFTableViewRebuildResult in [
		predicate.row_id_result,
		predicate.case_result,
		predicate.selection_model_result,
	]:
		assert_not_null(inner_result)
		assert_false(inner_result.is_successful())
		assert_eq(inner_result.get_error_code(), &"reentrant_rebuild")
	assert_eq(view.get_row_id_column(), &"id")
	assert_false(view.is_filter_case_sensitive())
	assert_true(is_same(view.get_selection_model(), authoritative_model))
	assert_eq(authoritative_model.get_selected_ids(), ["row-a"])
	assert_eq(replacement_model.get_selected_ids(), ["row-b"])
	assert_eq(view.get_visible_row_ids(), previous_ids)
	assert_eq(view.get_view_revision(), previous_revision)
	assert_true(view.get_row_predicate_ids().is_empty())


func test_row_id_configuration_failure_preserves_selection_anchor_and_revision() -> void:
	var view: GFTableDataView = _make_people_view()
	var failing: FailingPredicate = FailingPredicate.new()
	failing.failed_row_id = "p1"
	var predicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"account_guard", failing),
	])
	assert_true(predicate_result.is_successful())
	var model: GFTableSelectionModel = view.get_selection_model()
	var _select_a_result: bool = model.set_selected("row-a", true)
	var _select_b_result: bool = model.set_selected("row-b", true)
	var _move_anchor_result: bool = model.set_selected("row-a", true)
	var previous_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()

	var result: GFTableViewRebuildResult = view.set_row_id_column(&"account")

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"predicate_fixture_failed")
	assert_eq(view.get_row_id_column(), &"id")
	assert_eq(view.get_visible_row_ids(), previous_ids)
	assert_eq(view.get_view_revision(), previous_revision)
	assert_eq(model.get_selected_ids(), ["row-a", "row-b"])
	assert_true(GFVariantData.values_equal(model.anchor_row_id, "row-a"))


func test_filter_case_configuration_failure_preserves_prior_projection() -> void:
	var view: GFTableDataView = _make_people_view()
	var case_result: GFTableViewRebuildResult = view.set_filter_case_sensitive(true)
	assert_true(case_result.is_successful())
	var filter_result: GFTableViewRebuildResult = view.set_filter_query("ALICE")
	assert_true(filter_result.is_successful())
	assert_true(view.get_visible_row_ids().is_empty())
	var failing: FailingPredicate = FailingPredicate.new()
	failing.failed_row_id = "row-a"
	var predicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"case_guard", failing),
	])
	assert_true(predicate_result.is_successful())
	var previous_revision: int = view.get_view_revision()

	var result: GFTableViewRebuildResult = view.set_filter_case_sensitive(false)

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"predicate_fixture_failed")
	assert_true(view.is_filter_case_sensitive())
	assert_true(view.get_visible_row_ids().is_empty())
	assert_eq(view.get_view_revision(), previous_revision)


func test_selection_model_configuration_failure_preserves_both_models() -> void:
	var view: GFTableDataView = _make_people_view()
	var failing: FailingPredicate = FailingPredicate.new()
	failing.failed_row_id = "not-present"
	var predicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"selection_model_guard", failing),
	])
	assert_true(predicate_result.is_successful())
	var authoritative_model: GFTableSelectionModel = view.get_selection_model()
	var _authoritative_selection_result: bool = authoritative_model.set_selected(
		"row-a",
		true
	)
	var replacement_model: GFTableSelectionModel = GFTableSelectionModel.new()
	var _replacement_selection_result: bool = replacement_model.set_selected("row-b", true)
	failing.failed_row_id = "row-a"
	var previous_revision: int = view.get_view_revision()

	var result: GFTableViewRebuildResult = view.set_selection_model(replacement_model)

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"predicate_fixture_failed")
	assert_true(is_same(view.get_selection_model(), authoritative_model))
	assert_eq(authoritative_model.get_selected_ids(), ["row-a"])
	assert_true(GFVariantData.values_equal(authoritative_model.anchor_row_id, "row-a"))
	assert_eq(replacement_model.get_selected_ids(), ["row-b"])
	assert_true(GFVariantData.values_equal(replacement_model.anchor_row_id, "row-b"))
	assert_eq(view.get_view_revision(), previous_revision)


func test_row_id_configuration_migrates_selection_and_original_anchor_atomically() -> void:
	var view: GFTableDataView = _make_people_view()
	var model: GFTableSelectionModel = view.get_selection_model()
	var _select_a_result: bool = model.set_selected("row-a", true)
	var _select_b_result: bool = model.set_selected("row-b", true)
	var _move_anchor_result: bool = model.set_selected("row-a", true)
	var observer: SelectionStateObserver = SelectionStateObserver.new()
	observer.model = model
	var _connection_result: Error = model.selection_changed.connect(
		observer.on_selection_changed
	) as Error
	var previous_revision: int = view.get_view_revision()

	var result: GFTableViewRebuildResult = view.set_row_id_column(&"name")

	assert_true(result.is_successful())
	assert_eq(view.get_row_id_column(), &"name")
	assert_eq(view.get_visible_row_ids(), ["Alice", "Bob", "Cara"])
	assert_eq(view.get_view_revision(), previous_revision + 1)
	assert_eq(model.get_selected_ids(), ["Alice", "Bob"])
	assert_true(GFVariantData.values_equal(model.anchor_row_id, "Alice"))
	assert_eq(observer.emission_count, 1)
	assert_eq(observer.observed_ids, ["Alice", "Bob"])
	assert_true(GFVariantData.values_equal(observer.observed_anchor, "Alice"))


func test_row_id_configuration_maps_each_selection_by_its_source_row() -> void:
	var view: GFTableDataView = GFTableDataView.new()
	var columns_result: GFTableViewRebuildResult = view.set_columns([
		_make_column(&"id"),
		_make_column(&"next_id"),
	])
	assert_true(columns_result.is_successful())
	var rows_result: GFTableViewRebuildResult = view.set_rows([
		{ "id": "row-a", "next_id": "row-b" },
		{ "id": "row-b", "next_id": "row-c" },
	])
	assert_true(rows_result.is_successful())
	var model: GFTableSelectionModel = view.get_selection_model()
	var _selection_result: bool = model.set_selected("row-a", true)

	var result: GFTableViewRebuildResult = view.set_row_id_column(&"next_id")

	assert_true(result.is_successful())
	assert_eq(model.get_selected_ids(), ["row-b"])
	assert_true(GFVariantData.values_equal(model.anchor_row_id, "row-b"))


func test_filter_case_and_selection_model_setters_commit_through_rebuild() -> void:
	var view: GFTableDataView = _make_people_view()
	var filter_result: GFTableViewRebuildResult = view.set_filter_query("ALICE")
	assert_true(filter_result.is_successful())
	assert_eq(view.get_visible_row_ids(), ["row-a"])
	var previous_revision: int = view.get_view_revision()

	var case_result: GFTableViewRebuildResult = view.set_filter_case_sensitive(true)

	assert_true(case_result.is_successful())
	assert_true(view.is_filter_case_sensitive())
	assert_true(view.get_visible_row_ids().is_empty())
	assert_eq(view.get_view_revision(), previous_revision + 1)

	var replacement_model: GFTableSelectionModel = GFTableSelectionModel.new()
	var _select_unknown_result: bool = replacement_model.set_selected("unknown", true)
	var _select_row_result: bool = replacement_model.set_selected("row-b", true)
	previous_revision = view.get_view_revision()
	var model_result: GFTableViewRebuildResult = view.set_selection_model(replacement_model)

	assert_true(model_result.is_successful())
	assert_true(is_same(view.get_selection_model(), replacement_model))
	assert_eq(replacement_model.get_selected_ids(), ["row-b"])
	assert_true(GFVariantData.values_equal(replacement_model.anchor_row_id, "row-b"))
	assert_eq(view.get_view_revision(), previous_revision + 1)


func test_row_view_is_frozen_before_project_predicate_runs() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate: ReconfiguringRowViewPredicate = ReconfiguringRowViewPredicate.new()

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"reconfigure", predicate),
	])

	assert_true(result.is_successful())
	assert_eq(predicate.configure_results, [false, false, false])
	assert_eq(predicate.observed_row_ids, ["row-a", "row-b", "row-c"])
	assert_eq(predicate.observed_scores, [10, 18, 7])


func test_uninitialized_typed_predicate_result_fails_closed() -> void:
	var view: GFTableDataView = _make_people_view()
	var previous_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(
			&"uninitialized",
			UninitializedResultPredicate.new()
		),
	])

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"invalid_predicate_result")
	assert_eq(result.get_failed_predicate_id(), &"uninitialized")
	assert_true(view.get_row_predicate_ids().is_empty())
	assert_eq(view.get_visible_row_ids(), previous_ids)
	assert_eq(view.get_view_revision(), previous_revision)


func test_rebuild_results_are_frozen_and_observers_cannot_pollute_last_result() -> void:
	var view: GFTableDataView = _make_people_view()
	var failing: FailingPredicate = FailingPredicate.new()
	failing.failed_row_id = "row-a"
	failing.error_message = "original failure"
	var observer: RebuildResultMutationObserver = RebuildResultMutationObserver.new()
	var _connected: int = view.view_rebuild_failed.connect(observer.on_view_rebuild_failed)

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"failing", failing),
	])

	assert_false(result.is_successful())
	assert_false(observer.configure_result, "信号观察者不得重配已冻结结果。")
	assert_eq(result.get_error_code(), &"predicate_fixture_failed")
	assert_eq(result.get_error_message(), "original failure")
	assert_false(result.configure_success_for_framework(true, 999, 999, 999, 999))
	assert_eq(result.get_error_code(), &"predicate_fixture_failed")
	var last_result: GFTableViewRebuildResult = view.get_last_view_rebuild_result()
	assert_eq(last_result.get_error_code(), &"predicate_fixture_failed")
	last_result.set("_error_code", &"caller_tampered")
	assert_eq(
		view.get_last_view_rebuild_result().get_error_code(),
		&"predicate_fixture_failed",
		"last result getter 必须返回隔离副本。"
	)
	var result_copy: GFTableViewRebuildResult = result.duplicate_result()
	assert_eq(result_copy.get_error_code(), &"predicate_fixture_failed")
	assert_false(result_copy.configure_success_for_framework(true, 999, 999, 999, 999))


func test_predicates_reject_unsafe_object_row_identity_without_leaking_alias() -> void:
	var view: GFTableDataView = _make_people_view()
	var unsafe_row_id: RefCounted = RefCounted.new()
	var rows_result: GFTableViewRebuildResult = view.set_rows([
		{
			"id": unsafe_row_id,
			"name": "Unsafe",
			"score": 1,
			"account": "p1",
			"tags": [],
		},
	])
	assert_true(rows_result.is_successful())
	var previous_revision: int = view.get_view_revision()
	var predicate: RecordingPredicate = RecordingPredicate.new()

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"safe_identity", predicate),
	])

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"invalid_row_id")
	assert_eq(result.get_failed_source_row_index(), 0)
	assert_true(
		GFVariantData.values_equal(result.get_failed_row_id(), null),
		"失败结果不得携带源 Object row_id alias。"
	)
	assert_true(view.get_row_predicate_ids().is_empty())
	assert_eq(view.get_view_revision(), previous_revision)


func test_cell_commit_rolls_back_source_projection_revision_and_selection_on_predicate_failure() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate: ScoreFailurePredicate = ScoreFailurePredicate.new()
	predicate.failed_score = 99
	var predicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"score_guard", predicate),
	])
	assert_true(predicate_result.is_successful())
	var _selection_result: bool = view.get_selection_model().set_selected("row-a", true)
	var previous_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()

	var committed: bool = view.commit_cell_value(0, &"score", 99)

	assert_false(committed)
	assert_eq(GFVariantData.to_int(view.get_cell_value(0, &"score")), 10)
	assert_eq(view.get_visible_row_ids(), previous_ids)
	assert_eq(view.get_view_revision(), previous_revision)
	assert_true(view.get_selection_model().is_selected("row-a"))
	assert_eq(view.get_last_view_rebuild_result().get_error_code(), &"score_rejected")


func test_batch_cell_commit_is_atomic_when_candidate_projection_fails() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate: ScoreFailurePredicate = ScoreFailurePredicate.new()
	predicate.failed_score = 99
	var predicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"score_guard", predicate),
	])
	assert_true(predicate_result.is_successful())
	var previous_revision: int = view.get_view_revision()

	var report: Dictionary = view.commit_cell_values([
		{ "row_index": 0, "column_id": &"score", "new_value": 12 },
		{ "row_index": 1, "column_id": &"score", "new_value": 99 },
	])

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.to_int(view.get_cell_value(0, &"score")), 10)
	assert_eq(GFVariantData.to_int(view.get_cell_value(1, &"score")), 18)
	assert_eq(view.get_view_revision(), previous_revision)
	assert_eq(view.get_last_view_rebuild_result().get_error_code(), &"score_rejected")


func test_row_id_cell_commit_rolls_back_selection_and_source_on_predicate_failure() -> void:
	var view: GFTableDataView = _make_people_view()
	view.get_column(&"id").editable = true
	var predicate: FailingPredicate = FailingPredicate.new()
	predicate.failed_row_id = "row-z"
	var predicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"row_id_guard", predicate),
	])
	assert_true(predicate_result.is_successful())
	var _selection_result: bool = view.get_selection_model().set_selected("row-a", true)
	var previous_revision: int = view.get_view_revision()

	var committed: bool = view.commit_cell_value(0, &"id", "row-z")

	assert_false(committed)
	assert_eq(view.get_row_ids(), ["row-a", "row-b", "row-c"])
	assert_eq(view.get_visible_row_ids(), ["row-a", "row-b", "row-c"])
	assert_eq(view.get_view_revision(), previous_revision)
	assert_true(view.get_selection_model().is_selected("row-a"))
	assert_true(GFVariantData.values_equal(view.get_selection_model().anchor_row_id, "row-a"))
	assert_eq(view.get_last_view_rebuild_result().get_error_code(), &"predicate_fixture_failed")


func test_row_id_cell_commit_migrates_selection_and_original_anchor_atomically() -> void:
	var view: GFTableDataView = _make_people_view()
	view.get_column(&"id").editable = true
	var model: GFTableSelectionModel = view.get_selection_model()
	var _select_a_result: bool = model.set_selected("row-a", true)
	var _select_b_result: bool = model.set_selected("row-b", true)
	var _move_anchor_result: bool = model.set_selected("row-a", true)
	var observer: SelectionStateObserver = SelectionStateObserver.new()
	observer.model = model
	var _connection_result: Error = model.selection_changed.connect(
		observer.on_selection_changed
	) as Error

	var committed: bool = view.commit_cell_value(0, &"id", "row-a-next")

	assert_true(committed)
	assert_eq(view.get_row_ids(), ["row-a-next", "row-b", "row-c"])
	assert_eq(model.get_selected_ids(), ["row-a-next", "row-b"])
	assert_true(GFVariantData.values_equal(model.anchor_row_id, "row-a-next"))
	assert_eq(observer.emission_count, 1)
	assert_eq(observer.observed_ids, ["row-a-next", "row-b"])
	assert_true(GFVariantData.values_equal(observer.observed_anchor, "row-a-next"))


func test_batch_row_id_commit_maps_swapped_ids_by_source_row() -> void:
	var view: GFTableDataView = _make_people_view()
	view.get_column(&"id").editable = true
	var model: GFTableSelectionModel = view.get_selection_model()
	var _selection_result: bool = model.set_selected("row-a", true)

	var report: Dictionary = view.commit_cell_values([
		{ "row_index": 0, "column_id": &"id", "new_value": "row-b" },
		{ "row_index": 1, "column_id": &"id", "new_value": "row-a" },
	])

	assert_true(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(view.get_row_ids(), ["row-b", "row-a", "row-c"])
	assert_eq(model.get_selected_ids(), ["row-b"])
	assert_true(GFVariantData.values_equal(model.anchor_row_id, "row-b"))


func test_batch_row_id_cell_commit_rolls_back_every_staged_change() -> void:
	var view: GFTableDataView = _make_people_view()
	view.get_column(&"id").editable = true
	var predicate: FailingPredicate = FailingPredicate.new()
	predicate.failed_row_id = "row-z"
	var predicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"batch_row_id_guard", predicate),
	])
	assert_true(predicate_result.is_successful())
	var _selection_result: bool = view.get_selection_model().set_selected("row-a", true)
	var previous_revision: int = view.get_view_revision()

	var report: Dictionary = view.commit_cell_values([
		{ "row_index": 0, "column_id": &"score", "new_value": 12 },
		{ "row_index": 0, "column_id": &"id", "new_value": "row-z" },
	])

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(GFVariantData.to_int(view.get_cell_value(0, &"score")), 10)
	assert_eq(view.get_row_ids(), ["row-a", "row-b", "row-c"])
	assert_eq(view.get_view_revision(), previous_revision)
	assert_true(view.get_selection_model().is_selected("row-a"))
	assert_true(GFVariantData.values_equal(view.get_selection_model().anchor_row_id, "row-a"))


func test_custom_value_setter_is_rejected_before_it_can_run() -> void:
	var view: GFTableDataView = _make_people_view()
	var setter: CountingSetter = CountingSetter.new()
	view.get_column(&"score").value_setter = setter.write_value
	var previous_revision: int = view.get_view_revision()

	var report: Dictionary = view.commit_cell_values([
		{ "row_index": 0, "column_id": &"score", "new_value": 12 },
	])

	assert_false(GFVariantData.get_option_bool(report, "ok"))
	assert_eq(setter.invocation_count, 0, "事务入口必须在调用自定义 setter 前失败关闭。")
	assert_eq(GFVariantData.to_int(view.get_cell_value(0, &"score")), 10)
	assert_eq(view.get_view_revision(), previous_revision)
	var errors: Array = GFVariantData.get_option_array(report, "errors")
	assert_eq(errors.size(), 1)
	if not errors.is_empty():
		assert_eq(
			GFVariantData.get_option_string_name(
				GFVariantData.as_dictionary(errors[0]),
				"reason"
			),
			&"non_transactional_value_setter"
		)


func test_cell_commit_isolates_mutable_input_report_and_signal_payloads() -> void:
	var view: GFTableDataView = _make_people_view()
	view.get_column(&"tags").editable = true
	var observer: CellPayloadMutationObserver = CellPayloadMutationObserver.new()
	var _connection_result: Error = (
		view.cell_value_committed.connect(observer.on_cell_value_committed)
		as Error
	)
	var requested_tags: Array = ["new"]

	var report: Dictionary = view.commit_cell_values([
		{ "row_index": 0, "column_id": &"tags", "new_value": requested_tags },
	])

	assert_true(GFVariantData.get_option_bool(report, "ok"))
	requested_tags.append("caller-mutation")
	var committed_reports_value: Variant = GFVariantData.get_option_value(report, "committed")
	var committed_reports: Array = []
	if committed_reports_value is Array:
		committed_reports = committed_reports_value
	assert_eq(committed_reports.size(), 1)
	if not committed_reports.is_empty():
		var committed_report_value: Variant = committed_reports[0]
		if committed_report_value is Dictionary:
			var committed_report: Dictionary = committed_report_value
			var report_tags_value: Variant = GFVariantData.get_option_value(
				committed_report,
				"new_value"
			)
			if report_tags_value is Array:
				var report_tags: Array = report_tags_value
				report_tags.append("report-mutation")
	assert_eq(
		GFVariantData.get_option_array(GFVariantData.as_dictionary(view.get_row(0)), "tags"),
		["new"],
		"调用方、报告和信号观察者都不得持有权威候选值的别名。"
	)


func test_builtin_resource_row_is_copied_before_transactional_commit() -> void:
	var view: GFTableDataView = GFTableDataView.new()
	var row_id_result: GFTableViewRebuildResult = view.set_row_id_column(&"resource_name")
	assert_true(row_id_result.is_successful())
	var id_column: GFTableColumnDefinition = _make_column(&"resource_name")
	var minimum_column: GFTableColumnDefinition = GFTableColumnDefinition.new()
	var _minimum_configure_result: GFTableColumnDefinition = minimum_column.configure(
		&"minimum",
		"",
		&"min_value"
	)
	minimum_column.editable = true
	var _columns_result: GFTableViewRebuildResult = view.set_columns([
		id_column,
		minimum_column,
	])
	var source_row: Curve = Curve.new()
	source_row.resource_name = "curve-row"
	source_row.min_value = -10.0
	var _rows_result: GFTableViewRebuildResult = view.set_rows([source_row])

	var committed: bool = view.commit_cell_value(0, &"minimum", -20.0)

	assert_true(committed, "无脚本且可验证深复制的内建 Resource 行应可事务提交。")
	assert_eq(source_row.min_value, -10.0, "候选写入不得修改调用方持有的 Resource。")
	var committed_row_value: Variant = view.get_row(0)
	assert_true(committed_row_value is Curve)
	if committed_row_value is Curve:
		var committed_row: Curve = committed_row_value
		assert_false(is_same(committed_row, source_row))
		assert_eq(committed_row.resource_name, "curve-row")
		assert_eq(committed_row.min_value, -20.0)


func test_scripted_resource_row_fails_closed_before_transactional_commit() -> void:
	var view: GFTableDataView = GFTableDataView.new()
	var id_column: GFTableColumnDefinition = _make_column(&"id")
	var score_column: GFTableColumnDefinition = _make_column(&"score")
	score_column.editable = true
	var _columns_result: GFTableViewRebuildResult = view.set_columns([
		id_column,
		score_column,
	])
	var source_row: ScriptedTableRow = ScriptedTableRow.new()
	var _rows_result: GFTableViewRebuildResult = view.set_rows([source_row])
	var previous_revision: int = view.get_view_revision()

	var committed: bool = view.commit_cell_value(0, &"score", 12)

	assert_false(committed)
	assert_eq(source_row.score, 10)
	assert_true(is_same(view.get_row(0), source_row))
	assert_eq(view.get_view_revision(), previous_revision)
	assert_eq(
		view.get_last_view_rebuild_result().get_error_code(),
		&"unisolatable_source_row"
	)


func test_set_rows_commits_coherent_state_before_selection_observers_run() -> void:
	var view: GFTableDataView = _make_people_view()
	var _selection_result: bool = view.get_selection_model().set_selected("row-a", true)
	var observer: SelectionRebuildObserver = SelectionRebuildObserver.new()
	observer.view = view
	var _connection_result: Error = (
		view.get_selection_model().selection_changed.connect(observer.on_selection_changed)
		as Error
	)

	var result: GFTableViewRebuildResult = view.set_rows([
		{ "id": "row-new", "name": "New", "score": 1, "account": "p3", "tags": [] },
	])

	assert_true(result.is_successful())
	assert_not_null(observer.inner_result)
	assert_false(observer.inner_result.is_successful(), "提交期 selection listener 不得重入修改 view。")
	assert_eq(observer.inner_result.get_error_code(), &"reentrant_rebuild")
	assert_eq(view.get_filter_query(), "")
	assert_eq(view.get_visible_row_ids(), ["row-new"])
	assert_false(view.get_selection_model().is_selected("row-a"))


func test_text_formatter_true_match_reentrancy_aborts_outer_projection() -> void:
	var view: GFTableDataView = _make_people_view()
	var formatter: ReentrantFormatter = ReentrantFormatter.new()
	formatter.view = view
	var name_column: GFTableColumnDefinition = view.get_column(&"name")
	name_column.value_formatter = formatter.format_value
	var previous_ids: Array = view.get_visible_row_ids()
	var previous_revision: int = view.get_view_revision()

	var result: GFTableViewRebuildResult = view.set_filter_query("matching")

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"reentrant_rebuild")
	assert_not_null(formatter.inner_result)
	assert_false(formatter.inner_result.is_successful())
	assert_eq(view.get_filter_query(), "")
	assert_eq(view.get_visible_row_ids(), previous_ids)
	assert_eq(view.get_view_revision(), previous_revision)


func test_predicate_cannot_commit_source_during_candidate_rebuild() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate: CommittingPredicate = CommittingPredicate.new()
	predicate.view = view
	var previous_revision: int = view.get_view_revision()

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"committing", predicate),
	])

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"reentrant_rebuild")
	assert_false(predicate.commit_succeeded)
	assert_eq(GFVariantData.to_int(view.get_cell_value(0, &"score")), 10)
	assert_eq(view.get_view_revision(), previous_revision)


func test_row_view_rejects_nested_non_resource_object_aliases() -> void:
	var view: GFTableDataView = GFTableDataView.new()
	var id_column: GFTableColumnDefinition = _make_column(&"id")
	var payload_column: GFTableColumnDefinition = _make_column(&"payload")
	var _columns_result: GFTableViewRebuildResult = view.set_columns([
		id_column,
		payload_column,
	])
	var payload: MutablePayload = MutablePayload.new()
	var _rows_result: GFTableViewRebuildResult = view.set_rows([
		{ "id": "unsafe", "payload": { "nested": [payload] } },
	])
	var previous_revision: int = view.get_view_revision()

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(
			&"payload_mutation",
			PayloadMutationPredicate.new()
		),
	])

	assert_false(result.is_successful())
	assert_eq(result.get_error_code(), &"invalid_row_view_snapshot")
	assert_eq(payload.amount, 1)
	assert_eq(view.get_view_revision(), previous_revision)


func test_row_view_rejects_circular_and_over_budget_values() -> void:
	var row_view: GFTableRowView = GFTableRowView.new()
	var circular_values: Array = []
	circular_values.append(circular_values)
	assert_false(row_view.configure_for_framework(
		0,
		&"circular",
		{ &"value": circular_values }
	))

	var deep_value: Variant = 1
	for _index: int in range(80):
		deep_value = [deep_value]
	var deep_row_view: GFTableRowView = GFTableRowView.new()
	assert_false(deep_row_view.configure_for_framework(
		0,
		&"deep",
		{ &"value": deep_value }
	))

	var node_heavy_values: Array = []
	var _node_resize_result: int = node_heavy_values.resize(17_000)
	var node_heavy_row_view: GFTableRowView = GFTableRowView.new()
	assert_false(node_heavy_row_view.configure_for_framework(
		0,
		&"node-heavy",
		{ &"value": node_heavy_values }
	))

	var collection_heavy_values: Array = []
	var _collection_resize_result: int = collection_heavy_values.resize(65_537)
	var collection_heavy_row_view: GFTableRowView = GFTableRowView.new()
	assert_false(collection_heavy_row_view.configure_for_framework(
		0,
		&"collection-heavy",
		{ &"value": collection_heavy_values }
	))

	var utf8_heavy_row_view: GFTableRowView = GFTableRowView.new()
	assert_false(utf8_heavy_row_view.configure_for_framework(
		0,
		&"utf8-heavy",
		{ &"value": "界".repeat(350_000) }
	))

	var packed_bytes: PackedByteArray = PackedByteArray()
	var _resize_error: int = packed_bytes.resize(1_048_577)
	var packed_heavy_row_view: GFTableRowView = GFTableRowView.new()
	assert_false(packed_heavy_row_view.configure_for_framework(
		0,
		&"packed-heavy",
		{ &"value": packed_bytes }
	))

	var packed_vector_boundary: PackedVector4Array = PackedVector4Array()
	var _boundary_resize_error: int = packed_vector_boundary.resize(32_768)
	var packed_vector_boundary_report: Dictionary = (
		GFTableRowView.duplicate_isolated_variant_for_framework(packed_vector_boundary)
	)
	assert_true(GFVariantData.get_option_bool(packed_vector_boundary_report, "ok"))
	var packed_vector_over_budget: PackedVector4Array = PackedVector4Array()
	var _over_budget_resize_error: int = packed_vector_over_budget.resize(32_769)
	var packed_vector_over_budget_report: Dictionary = (
		GFTableRowView.duplicate_isolated_variant_for_framework(packed_vector_over_budget)
	)
	assert_false(GFVariantData.get_option_bool(packed_vector_over_budget_report, "ok"))


func test_row_view_returns_an_isolated_copy_of_builtin_resources() -> void:
	var source_resource: Curve = Curve.new()
	source_resource.resource_name = "snapshot-curve"
	source_resource.min_value = -10.0
	var row_view: GFTableRowView = GFTableRowView.new()

	assert_true(row_view.configure_for_framework(
		0,
		&"resource-row",
		{ &"curve": source_resource }
	))
	var copied_value: Variant = row_view.get_value(&"curve")
	assert_true(copied_value is Curve)
	if copied_value is Curve:
		var copied_resource: Curve = copied_value
		assert_false(is_same(copied_resource, source_resource))
		assert_eq(copied_resource.resource_name, "snapshot-curve")
		assert_eq(copied_resource.min_value, -10.0)
		copied_resource.min_value = -20.0
		assert_eq(source_resource.min_value, -10.0)


func test_set_columns_rolls_back_when_candidate_predicate_fails() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate: ColumnPresenceFailurePredicate = ColumnPresenceFailurePredicate.new()
	predicate.rejected_column_id = &"forbidden"
	var predicate_result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"column_guard", predicate),
	])
	assert_true(predicate_result.is_successful())
	var previous_revision: int = view.get_view_revision()
	var next_columns: Array[GFTableColumnDefinition] = view.get_columns()
	next_columns.append(_make_column(&"forbidden"))

	var result: GFTableViewRebuildResult = view.set_columns(next_columns)

	assert_false(result.is_successful())
	assert_null(view.get_column(&"forbidden"))
	assert_eq(view.get_view_revision(), previous_revision)


func test_row_predicate_crud_is_transactional_and_deterministic() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate_a: RecordingPredicate = RecordingPredicate.new()
	predicate_a.label = "a"
	var predicate_b: RecordingPredicate = RecordingPredicate.new()
	predicate_b.label = "b"

	var register_b: GFTableViewRebuildResult = view.register_row_predicate(
		GFTableRowPredicateRegistration.create(&"b", predicate_b, 10, false)
	)
	var register_a: GFTableViewRebuildResult = view.register_row_predicate(
		GFTableRowPredicateRegistration.create(&"a", predicate_a, 20)
	)
	assert_true(register_b.is_successful())
	assert_true(register_a.is_successful())
	assert_eq(view.get_row_predicate_ids(), [&"b", &"a"])

	var enable_b: GFTableViewRebuildResult = view.set_row_predicate_enabled(&"b", true)
	var reorder_b: GFTableViewRebuildResult = view.set_row_predicate_order(&"b", 30)
	assert_true(enable_b.is_successful())
	assert_true(reorder_b.is_successful())
	assert_eq(view.get_row_predicate_ids(), [&"a", &"b"])

	var unregister_a: GFTableViewRebuildResult = view.unregister_row_predicate(&"a")
	assert_true(unregister_a.is_successful())
	assert_eq(view.get_row_predicate_ids(), [&"b"])


func test_registration_metadata_is_owned_and_getters_return_snapshots() -> void:
	var view: GFTableDataView = _make_people_view()
	var authoritative_predicate: RecordingPredicate = RecordingPredicate.new()
	authoritative_predicate.label = "authoritative"
	authoritative_predicate.minimum_score = 8
	var replacement_predicate: RecordingPredicate = RecordingPredicate.new()
	replacement_predicate.label = "replacement"
	replacement_predicate.minimum_score = 999
	var caller_registration: GFTableRowPredicateRegistration = (
		GFTableRowPredicateRegistration.create(
			&"owned",
			authoritative_predicate,
			10,
			true
		)
	)
	var registration_result: GFTableViewRebuildResult = view.set_row_predicates([
		caller_registration,
	])
	assert_true(registration_result.is_successful())
	assert_eq(view.get_visible_row_ids(), ["row-a", "row-b"])
	var committed_revision: int = view.get_view_revision()

	caller_registration.set("_predicate_id", &"caller-hijack")
	caller_registration.set("_order", -100)
	caller_registration.set("_enabled", false)
	caller_registration.set("_predicate", replacement_predicate)

	assert_eq(view.get_row_predicate_ids(), [&"owned"])
	assert_null(view.get_row_predicate(&"caller-hijack"))
	assert_eq(view.get_visible_row_ids(), ["row-a", "row-b"])
	assert_eq(view.get_view_revision(), committed_revision)
	var registration_snapshot: GFTableRowPredicateRegistration = (
		view.get_row_predicate(&"owned")
	)
	assert_not_null(registration_snapshot)
	registration_snapshot.set("_predicate_id", &"getter-hijack")
	registration_snapshot.set("_order", -200)
	registration_snapshot.set("_enabled", false)
	registration_snapshot.set("_predicate", replacement_predicate)
	var registration_snapshots: Array[GFTableRowPredicateRegistration] = (
		view.get_row_predicates()
	)
	assert_eq(registration_snapshots.size(), 1)
	registration_snapshots[0].set("_predicate_id", &"array-hijack")
	registration_snapshots[0].set("_order", -300)
	registration_snapshots[0].set("_enabled", false)
	registration_snapshots[0].set("_predicate", replacement_predicate)

	var authoritative_snapshot: GFTableRowPredicateRegistration = (
		view.get_row_predicate(&"owned")
	)
	assert_not_null(authoritative_snapshot)
	assert_eq(authoritative_snapshot.get_predicate_id(), &"owned")
	assert_eq(authoritative_snapshot.get_order(), 10)
	assert_true(authoritative_snapshot.is_enabled())
	assert_true(is_same(authoritative_snapshot.get_predicate(), authoritative_predicate))
	assert_eq(view.get_row_predicate_ids(), [&"owned"])
	assert_eq(view.get_visible_row_ids(), ["row-a", "row-b"])
	assert_eq(view.get_view_revision(), committed_revision)

	authoritative_predicate.invocation_log.clear()
	replacement_predicate.invocation_log.clear()
	var refresh_result: GFTableViewRebuildResult = view.refresh_view()
	assert_true(refresh_result.is_successful())
	assert_false(authoritative_predicate.invocation_log.is_empty())
	assert_true(replacement_predicate.invocation_log.is_empty())
	assert_eq(view.get_visible_row_ids(), ["row-a", "row-b"])


func test_failure_diagnostic_identity_payloads_have_utf8_byte_budgets() -> void:
	var view: GFTableDataView = _make_people_view()
	var predicate: RecordingPredicate = RecordingPredicate.new()
	var oversized_id: StringName = StringName("界".repeat(64))

	var result: GFTableViewRebuildResult = view.set_row_predicates([
		GFTableRowPredicateRegistration.create(oversized_id, predicate),
	])

	assert_false(result.is_successful())
	assert_eq(result.get_failed_predicate_id(), &"", "超预算 predicate id 不得进入诊断载荷。")
	assert_false(result.get_error_message().contains(String(oversized_id)))

	var diagnostic_view: GFTableDataView = _make_people_view()
	var oversized_row_id: String = "行".repeat(300)
	var rows_result: GFTableViewRebuildResult = diagnostic_view.set_rows([
		{
			"id": oversized_row_id,
			"name": "Diagnostic",
			"score": 1,
			"account": "p4",
			"tags": [],
		},
	])
	assert_true(rows_result.is_successful())
	var failing: FailingPredicate = FailingPredicate.new()
	failing.failed_row_id = oversized_row_id
	var registration_result: GFTableViewRebuildResult = diagnostic_view.set_row_predicates([
		GFTableRowPredicateRegistration.create(&"diagnostic_guard", failing, 0, false),
	])
	assert_true(registration_result.is_successful())

	failing.error_message = "A".repeat(4_096) + "ASCII_SECRET_TAIL"
	var ascii_result: GFTableViewRebuildResult = diagnostic_view.set_row_predicate_enabled(
		&"diagnostic_guard",
		true
	)
	assert_false(ascii_result.is_successful())
	assert_true(ascii_result.get_error_message().to_utf8_buffer().size() <= 1_024)
	assert_false(ascii_result.get_error_message().contains("ASCII_SECRET_TAIL"))
	assert_true(
		GFVariantData.values_equal(ascii_result.get_failed_row_id(), null),
		"超预算 row id 必须整体省略，不能被诊断层回显。"
	)

	failing.error_message = "界".repeat(2_000) + "多字节秘密尾部"
	var multibyte_result: GFTableViewRebuildResult = (
		diagnostic_view.set_row_predicate_enabled(&"diagnostic_guard", true)
	)
	assert_false(multibyte_result.is_successful())
	assert_true(multibyte_result.get_error_message().to_utf8_buffer().size() <= 1_024)
	assert_false(multibyte_result.get_error_message().contains("多字节秘密尾部"))
	assert_true(GFVariantData.values_equal(multibyte_result.get_failed_row_id(), null))


func _make_people_view() -> GFTableDataView:
	var view: GFTableDataView = GFTableDataView.new()
	var id_column: GFTableColumnDefinition = _make_column(&"id")
	var name_column: GFTableColumnDefinition = _make_column(&"name")
	var score_column: GFTableColumnDefinition = _make_column(&"score")
	score_column.editable = true
	score_column.sort_mode = GFTableColumnDefinition.SortMode.NUMBER
	var account_column: GFTableColumnDefinition = _make_column(&"account")
	account_column.visible = false
	var tags_column: GFTableColumnDefinition = _make_column(&"tags")
	tags_column.visible = false
	var columns: Array[GFTableColumnDefinition] = [
		id_column,
		name_column,
		score_column,
		account_column,
		tags_column,
	]
	var _columns_result: GFTableViewRebuildResult = view.set_columns(columns)
	var _rows_result: GFTableViewRebuildResult = view.set_rows([
		{ "id": "row-a", "name": "Alice", "score": 10, "account": "p1", "tags": ["alpha"] },
		{ "id": "row-b", "name": "Bob", "score": 18, "account": "p1", "tags": ["beta"] },
		{ "id": "row-c", "name": "Cara", "score": 7, "account": "p2", "tags": ["gamma"] },
	])
	return view


func _make_column(column_id: StringName) -> GFTableColumnDefinition:
	var column: GFTableColumnDefinition = GFTableColumnDefinition.new()
	var _configure_result: GFTableColumnDefinition = column.configure(column_id)
	return column
