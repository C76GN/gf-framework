## 测试 GFExecutionLaneDiagnostics 的 lane 记录、容量清理和手动 compact。
extends GutTest


# --- 测试方法 ---

func test_execution_lane_diagnostics_compacts_inactive_lanes_by_capacity() -> void:
	var diagnostics: GFExecutionLaneDiagnostics = GFExecutionLaneDiagnostics.new()
	diagnostics.max_lanes = 2

	var _old_event: Dictionary = diagnostics.record_lane_event(&"old", GFExecutionLaneDiagnostics.EVENT_COMPLETED)
	var _active_event: Dictionary = diagnostics.record_lane_event(&"active", GFExecutionLaneDiagnostics.EVENT_QUEUED)
	var _new_event: Dictionary = diagnostics.record_lane_event(&"new", GFExecutionLaneDiagnostics.EVENT_COMPLETED)

	assert_true(diagnostics.get_lane_snapshot(&"old").is_empty(), "容量超限时最旧 inactive lane 应被清理。")
	assert_false(diagnostics.get_lane_snapshot(&"active").is_empty(), "仍有 queued/active 的 lane 不应被容量清理。")
	assert_false(diagnostics.get_lane_snapshot(&"new").is_empty(), "较新的 inactive lane 应保留。")
	assert_eq(GFVariantData.get_option_int(diagnostics.get_health_snapshot(), "lane_count"), 2, "lane 数量应收敛到上限。")


func test_execution_lane_diagnostics_manual_compact_skips_active_lanes() -> void:
	var diagnostics: GFExecutionLaneDiagnostics = GFExecutionLaneDiagnostics.new()
	var _inactive_event: Dictionary = diagnostics.record_lane_event(&"inactive", GFExecutionLaneDiagnostics.EVENT_COMPLETED)
	var _active_event: Dictionary = diagnostics.record_lane_event(&"active", GFExecutionLaneDiagnostics.EVENT_STARTED)

	var removed_count: int = diagnostics.compact_lanes(0)

	assert_eq(removed_count, 1, "手动 compact 应移除过期 inactive lane。")
	assert_true(diagnostics.get_lane_snapshot(&"inactive").is_empty(), "inactive lane 应被清理。")
	assert_false(diagnostics.get_lane_snapshot(&"active").is_empty(), "active lane 不应被 stale compact 清理。")
