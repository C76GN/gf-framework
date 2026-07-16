## 测试 GFRuntimeCleanupScope 的注册、排序和注销行为。
extends GutTest


# --- 测试用例 ---

func test_cleanup_scope_runs_callbacks_by_priority_and_reports_ids() -> void:
	var cleanup_scope: GFRuntimeCleanupScope = GFRuntimeCleanupScope.new()
	var calls: Array[String] = []
	var low_callback: Callable = func() -> void:
		calls.append("low")
	var high_callback: Callable = func() -> void:
		calls.append("high")
	var low_registered: bool = cleanup_scope.register_cleanup(&"level", &"low", low_callback, 0)
	var high_registered: bool = cleanup_scope.register_cleanup(&"level", &"high", high_callback, 10)

	var report: Dictionary = cleanup_scope.run_scope(&"level")
	var cleanup_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(report, "cleanup_ids")

	assert_true(low_registered, "低优先级清理项应可注册。")
	assert_true(high_registered, "高优先级清理项应可注册。")
	assert_eq(calls, ["high", "low"], "run_scope 应按优先级从高到低执行。")
	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效回调执行报告应为 ok。")
	assert_eq(GFVariantData.get_option_int(report, "executed_count"), 2, "报告应包含执行数量。")
	assert_eq(cleanup_ids, PackedStringArray(["high", "low"]), "报告应按执行顺序记录 cleanup_id。")


func test_cleanup_scope_unregisters_and_clears_scope() -> void:
	var cleanup_scope: GFRuntimeCleanupScope = GFRuntimeCleanupScope.new()
	var state: Dictionary = { "called": false }
	var callback: Callable = func() -> void:
		state["called"] = true
	var _registered: bool = cleanup_scope.register_cleanup(&"level", &"history", callback)

	var removed: bool = cleanup_scope.unregister_cleanup(&"level", &"history")
	var report: Dictionary = cleanup_scope.run_scope(&"level")

	assert_true(removed, "已注册清理项应可注销。")
	assert_false(GFVariantData.get_option_bool(state, "called"), "注销后不应再执行回调。")
	assert_eq(GFVariantData.get_option_int(report, "executed_count"), 0, "空 scope 执行数量应为 0。")
	assert_false(cleanup_scope.has_cleanup(&"level", &"history"), "注销后 has_cleanup 应返回 false。")

	var _registered_again: bool = cleanup_scope.register_cleanup(&"level", &"history", callback)
	cleanup_scope.clear_scope(&"level")

	assert_false(cleanup_scope.has_cleanup(&"level", &"history"), "clear_scope 应清空指定 scope。")


func test_cleanup_scope_debug_snapshot_reports_scopes() -> void:
	var cleanup_scope: GFRuntimeCleanupScope = GFRuntimeCleanupScope.new()
	var _registered: bool = cleanup_scope.register_cleanup(&"level", &"history", func() -> void:
		pass
	)

	var snapshot: Dictionary = cleanup_scope.get_debug_snapshot()
	var scopes: Dictionary = GFVariantData.get_option_dictionary(snapshot, "scopes")
	var level_ids: PackedStringArray = GFVariantData.get_option_packed_string_array(scopes, "level")

	assert_eq(GFVariantData.get_option_int(snapshot, "scope_count"), 1, "快照应报告 scope 数量。")
	assert_eq(GFVariantData.get_option_int(snapshot, "cleanup_count"), 1, "快照应报告 cleanup 数量。")
	assert_eq(level_ids, PackedStringArray(["history"]), "快照应按 scope 列出 cleanup_id。")
