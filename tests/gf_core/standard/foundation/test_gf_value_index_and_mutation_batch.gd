## 测试 GFValueIndex 与 GFMutationBatch 的通用集合行为。
extends GutTest


# --- 常量 ---

const GFMutationBatchBase = preload("res://addons/gf/standard/foundation/collections/gf_mutation_batch.gd")
const GFValueIndexBase = preload("res://addons/gf/standard/foundation/collections/gf_value_index.gd")


# --- 测试方法 ---

## 验证值索引可按字段单查和多条件查询。
func test_value_index_queries_by_fields() -> void:
	var index: GFValueIndexBase = GFValueIndexBase.new()

	assert_true(index.set_item(&"a", { "score": 1 }, {
		"tag": ["red", "fast"],
		"tier": 1,
	}), "有效条目应写入索引。")
	assert_true(index.set_item(&"b", { "score": 2 }, {
		"tag": ["blue", "fast"],
		"tier": 2,
	}), "第二个条目应写入索引。")

	assert_eq(index.query(&"tag", "fast"), PackedStringArray(["a", "b"]), "单字段查询应返回匹配条目。")
	assert_eq(index.query_many({ "tag": "fast", "tier": 2 }), PackedStringArray(["b"]), "多条件交集应返回共同匹配项。")
	assert_eq(GFVariantData.get_option_int(GFVariantData.as_dictionary(index.get_item(&"a")), "score", 0), 1, "索引应保留条目值。")


## 验证值索引替换条目时会清理旧字段。
func test_value_index_replaces_old_fields() -> void:
	var index: GFValueIndexBase = GFValueIndexBase.new()

	var _set_item_result_35: Variant = index.set_item(&"a", "old", { "tag": "red" })
	var _set_item_result_36: Variant = index.set_item(&"a", "new", { "tag": "blue" })

	assert_eq(index.query(&"tag", "red"), PackedStringArray(), "替换条目后旧字段索引应清理。")
	assert_eq(index.query(&"tag", "blue"), PackedStringArray(["a"]), "替换条目后新字段索引应可查。")


func test_value_index_rejects_unstable_field_values_without_removing_existing_item() -> void:
	var index: GFValueIndexBase = GFValueIndexBase.new()
	var mutable_tag: Dictionary = {
		"id": 1,
	}

	assert_true(index.set_item(&"a", "stable", { "tag": "red" }), "初始稳定字段应写入成功。")
	assert_false(index.set_item(&"a", "unstable", { "tag": mutable_tag }), "可变 Dictionary 不应作为索引字段值。")
	mutable_tag["id"] = 2

	assert_eq(index.query(&"tag", "red"), PackedStringArray(["a"]), "失败写入不应移除旧索引。")
	var stored_item: String = GFVariantData.to_text(index.get_item(&"a"))
	assert_eq(stored_item, "stable", "失败写入不应替换旧值。")


func test_value_index_uses_shared_stable_key_codec() -> void:
	var index: GFValueIndexBase = GFValueIndexBase.new()

	assert_true(index.set_item(&"cell", "value", { "coord": Vector2i(1, 2) }), "稳定数学字段值应可索引。")
	assert_false(index.set_item(&"nan", "value", { "coord": NAN }), "非有限字段值不应写入索引。")

	assert_eq(index.query(&"coord", Vector2i(1, 2)), PackedStringArray(["cell"]), "查询应使用统一稳定 key token。")
	assert_eq(index.query(&"coord", NAN), PackedStringArray(), "非稳定查询值应返回空结果。")


## 验证变更批次可提交并按反向顺序回滚。
func test_mutation_batch_commits_and_rolls_back() -> void:
	var batch: GFMutationBatchBase = GFMutationBatchBase.new()
	var values: Array[String] = []
	var commit_one: Callable = func() -> Dictionary:
		values.append("one")
		return { "ok": true, "value": "one" }
	var rollback_one: Callable = func() -> void:
		values.append("undo_one")
	var commit_two: Callable = func() -> void:
		values.append("two")
	var rollback_two: Callable = func() -> void:
		values.append("undo_two")

	var _add_operation_result_56: Variant = batch.add_operation(commit_one, rollback_one)
	var _add_operation_result_57: Variant = batch.add_operation(commit_two, rollback_two)

	var commit_report: Dictionary = batch.commit()
	var rollback_report: Dictionary = batch.rollback_committed()

	assert_true(GFVariantData.get_option_bool(commit_report, "ok", false), "全部操作成功时提交报告应成功。")
	assert_eq(GFVariantData.get_option_int(commit_report, "committed_count", 0), 2, "提交报告应统计成功数量。")
	assert_true(GFVariantData.get_option_bool(rollback_report, "ok", false), "有效回滚应成功。")
	assert_eq(values, ["one", "two", "undo_two", "undo_one"], "回滚应按提交反向顺序执行。")


## 验证待处理队列在分批提交时保持 FIFO 顺序。
func test_mutation_batch_keeps_fifo_order_across_partial_commits() -> void:
	var batch: GFMutationBatchBase = GFMutationBatchBase.new()
	var values: Array[String] = []

	var _add_first_result: Variant = batch.add_operation(func() -> void:
		values.append("first")
	)
	var _add_second_result: Variant = batch.add_operation(func() -> void:
		values.append("second")
	)
	var _add_third_result: Variant = batch.add_operation(func() -> void:
		values.append("third")
	)

	var first_report: Dictionary = batch.commit(1)
	var remaining_report: Dictionary = batch.commit()

	assert_true(GFVariantData.get_option_bool(first_report, "ok", false), "首批提交应成功。")
	assert_eq(GFVariantData.get_option_int(first_report, "committed_count", 0), 1, "首批只应提交一个操作。")
	assert_eq(GFVariantData.get_option_int(first_report, "pending_count", 0), 2, "首批提交后应保留两个待处理操作。")
	assert_true(GFVariantData.get_option_bool(remaining_report, "ok", false), "剩余提交应成功。")
	assert_eq(values, ["first", "second", "third"], "分批提交必须保持待处理队列 FIFO 顺序。")


## 验证变更批次默认在失败时保留待处理操作。
func test_mutation_batch_stops_on_failure() -> void:
	var batch: GFMutationBatchBase = GFMutationBatchBase.new()
	var blocked_operation: Callable = func() -> Dictionary:
		return { "ok": false, "error": "blocked" }

	var _add_operation_result_74: Variant = batch.add_operation(blocked_operation)

	var report: Dictionary = batch.commit()

	assert_false(GFVariantData.get_option_bool(report, "ok", true), "操作失败时提交报告应失败。")
	assert_eq(GFVariantData.get_option_int(report, "failed_count", 0), 1, "提交报告应统计失败数量。")
	assert_eq(batch.get_pending_count(), 1, "默认停止失败时应保留待处理操作。")


func test_mutation_batch_reports_invalid_callable_at_commit_time() -> void:
	var batch: GFMutationBatchBase = GFMutationBatchBase.new()
	var receiver: MutationCallableReceiver = MutationCallableReceiver.new()
	add_child(receiver)
	var operation_id: int = batch.add_operation(Callable(receiver, "commit"))
	receiver.free()

	var report: Dictionary = batch.commit()
	var errors: Array = GFVariantData.get_option_array(report, "errors")
	var first_error: Dictionary = GFVariantData.as_dictionary(errors[0])

	assert_gt(operation_id, 0, "加入时有效的 Callable 应先被接受。")
	assert_false(GFVariantData.get_option_bool(report, "ok", true), "提交时 Callable 失效应结构化失败。")
	assert_eq(GFVariantData.get_option_int(report, "failed_count"), 1, "失效 Callable 应计为失败。")
	assert_eq(GFVariantData.get_option_string(first_error, "error"), "invalid_callable", "失败原因应稳定。")
	assert_eq(batch.get_pending_count(), 1, "stop_on_error=true 时失败操作应保留待处理。")


func test_mutation_batch_reports_invalid_callable_at_rollback_time() -> void:
	var batch: GFMutationBatchBase = GFMutationBatchBase.new()
	var receiver: MutationCallableReceiver = MutationCallableReceiver.new()
	add_child(receiver)
	var operation_id: int = batch.add_operation(
		Callable(receiver, "commit"),
		Callable(receiver, "rollback")
	)
	var commit_report: Dictionary = batch.commit()
	receiver.free()

	var rollback_report: Dictionary = batch.rollback_committed()
	var errors: Array = GFVariantData.get_option_array(rollback_report, "errors")
	var first_error: Dictionary = GFVariantData.as_dictionary(errors[0])

	assert_gt(operation_id, 0, "加入时有效的回滚 Callable 应先被接受。")
	assert_true(GFVariantData.get_option_bool(commit_report, "ok", false), "测试提交阶段应成功。")
	assert_false(GFVariantData.get_option_bool(rollback_report, "ok", true), "回滚时 Callable 失效应结构化失败。")
	assert_eq(GFVariantData.get_option_int(rollback_report, "failed_count"), 1, "失效回滚应计为失败。")
	assert_eq(GFVariantData.get_option_int(rollback_report, "skipped_count"), 0, "失效回滚不应被当成未配置 rollback。")
	assert_eq(GFVariantData.get_option_string(first_error, "error"), "invalid_callable", "失败原因应稳定。")
	assert_eq(batch.get_committed_count(), 1, "失败回滚项应保留在 committed 栈，避免状态丢失。")


func test_mutation_batch_keeps_failed_rollback_entries_committed() -> void:
	var batch: GFMutationBatchBase = GFMutationBatchBase.new()
	batch.stop_on_error = false
	var values: Array[String] = []

	var _add_success_result: Variant = batch.add_operation(
		func() -> void:
			values.append("commit_one"),
		func() -> void:
			values.append("rollback_one")
	)
	var _add_failed_result: Variant = batch.add_operation(
		func() -> void:
			values.append("commit_two"),
		func() -> Dictionary:
			values.append("rollback_two_failed")
			return { "ok": false, "error": "rollback_failed" }
	)

	var commit_report: Dictionary = batch.commit()
	var rollback_report: Dictionary = batch.rollback_committed()

	assert_true(GFVariantData.get_option_bool(commit_report, "ok", false), "测试提交阶段应成功。")
	assert_false(GFVariantData.get_option_bool(rollback_report, "ok", true), "失败回滚应让回滚报告失败。")
	assert_eq(GFVariantData.get_option_int(rollback_report, "rolled_back_count"), 1, "可回滚项仍应继续回滚。")
	assert_eq(GFVariantData.get_option_int(rollback_report, "failed_count"), 1, "失败回滚项应计数。")
	assert_eq(batch.get_committed_count(), 1, "失败回滚项应保留在 committed 栈，避免状态丢失。")
	assert_eq(values, ["commit_one", "commit_two", "rollback_two_failed", "rollback_one"], "stop_on_error=false 时应继续回滚后续项。")


func test_mutation_batch_auto_clear_summary_matches_post_commit_state() -> void:
	var batch: GFMutationBatchBase = GFMutationBatchBase.new()
	batch.auto_clear_committed_on_success = true
	var _operation_id: int = batch.add_operation(func() -> void:
		pass
	)

	var report: Dictionary = batch.commit()

	assert_true(GFVariantData.get_option_bool(report, "ok"), "操作应提交成功。")
	assert_eq(batch.get_committed_count(), 0, "auto clear 应清空 committed 栈。")
	assert_eq(GFVariantData.get_option_int(report, "stored_committed_count", -1), 0, "提交摘要应描述清理后的可观察状态。")


class MutationCallableReceiver:
	extends Node

	func commit() -> void:
		pass


	func rollback() -> void:
		pass
