extends GutTest

const GF_TEST_LIFECYCLE_SCOPE_SCRIPT = preload(
	"res://tests/gf_core/support/gf_test_lifecycle_scope.gd"
)


func test_cleanup_runs_callbacks_in_lifo_order() -> void:
	var lifecycle_scope: GF_TEST_LIFECYCLE_SCOPE_SCRIPT = GF_TEST_LIFECYCLE_SCOPE_SCRIPT.new(
		get_tree()
	)
	var events: Array[String] = []
	var first_registered: bool = lifecycle_scope.defer_cleanup(func() -> void:
		events.append("first")
	)
	var second_registered: bool = lifecycle_scope.defer_cleanup(func() -> void:
		events.append("second")
	)

	var report: Dictionary = await lifecycle_scope.cleanup(1)

	assert_true(first_registered, "第一个清理回调应成功登记。")
	assert_true(second_registered, "第二个清理回调应成功登记。")
	assert_eq(events, ["second", "first"], "清理回调必须按 LIFO 顺序执行。")
	assert_eq(_report_int(report, "cleanup_count"), 2, "报告应记录已执行的清理回调数。")
	assert_true(_report_bool(report, "ok"), "无泄漏的清理应成功。")


func test_cleanup_waits_for_queue_free_and_verifies_weak_release() -> void:
	var lifecycle_scope: GF_TEST_LIFECYCLE_SCOPE_SCRIPT = GF_TEST_LIFECYCLE_SCOPE_SCRIPT.new(
		get_tree()
	)
	var owned_node: Node = Node.new()
	add_child(owned_node)
	var owned_node_ref: WeakRef = weakref(owned_node)
	var owned_node_id: int = lifecycle_scope.defer_queue_free(owned_node, "owned_node")

	var ref_target: RefCounted = RefCounted.new()
	var ref_target_ref: WeakRef = weakref(ref_target)
	var ref_target_id: int = lifecycle_scope.expect_released(ref_target, "ref_target")
	owned_node = null
	ref_target = null

	var report: Dictionary = await lifecycle_scope.cleanup()

	assert_ne(owned_node_id, 0, "queue_free 目标应登记实例 ID。")
	assert_ne(ref_target_id, 0, "弱释放目标应登记实例 ID。")
	assert_true(owned_node_ref.get_ref() == null, "cleanup 返回前 queue_free 目标必须完成释放。")
	assert_true(ref_target_ref.get_ref() == null, "cleanup 返回前 RefCounted 目标必须完成释放。")
	assert_eq(_report_array(report, "unreleased"), [], "报告不应包含未释放对象。")
	assert_eq(_report_array(report, "new_orphans"), [], "清理不应留下新增孤儿节点。")
	assert_true(_report_bool(report, "ok"), "完成释放的生命周期清理应成功。")


func test_cleanup_is_one_shot_and_rejects_invalid_callbacks() -> void:
	var lifecycle_scope: GF_TEST_LIFECYCLE_SCOPE_SCRIPT = GF_TEST_LIFECYCLE_SCOPE_SCRIPT.new(
		get_tree()
	)
	var events: Array[String] = []
	var invalid_registered: bool = lifecycle_scope.defer_cleanup(Callable())
	var valid_registered: bool = lifecycle_scope.defer_cleanup(func() -> void:
		events.append("cleanup")
	)

	var first_report: Dictionary = await lifecycle_scope.cleanup(1)
	var late_registered: bool = lifecycle_scope.defer_cleanup(func() -> void:
		events.append("late")
	)
	var second_report: Dictionary = await lifecycle_scope.cleanup(1)

	assert_false(invalid_registered, "无效 Callable 不得进入清理栈。")
	assert_true(valid_registered, "有效 Callable 应进入清理栈。")
	assert_false(late_registered, "cleanup 开始后不得再登记回调。")
	assert_eq(events, ["cleanup"], "重复 cleanup 不得再次执行回调。")
	assert_eq(second_report, first_report, "重复 cleanup 应返回同一份终态报告。")


# --- 私有/辅助方法 ---

func _report_array(report: Dictionary, key: String) -> Array:
	var raw_value: Variant = report.get(key)
	if raw_value is Array:
		var values: Array = raw_value
		return values
	return []


func _report_bool(report: Dictionary, key: String) -> bool:
	var raw_value: Variant = report.get(key, false)
	return raw_value if raw_value is bool else false


func _report_int(report: Dictionary, key: String) -> int:
	var raw_value: Variant = report.get(key, -1)
	return raw_value if raw_value is int else -1
