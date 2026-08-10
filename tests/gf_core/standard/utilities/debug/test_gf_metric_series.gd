extends GutTest


func test_metric_series_keeps_bounded_samples_and_stats() -> void:
	var series: GFMetricSeries = GFMetricSeries.new()
	var _configure_result_6: Variant = series.configure(&"frame_time", {
		"label": "Frame Time",
		"group": "Runtime",
		"max_samples": 3,
	})

	series.add_sample(10.0, 1.0)
	series.add_sample(20.0, 2.0)
	series.add_sample(30.0, 3.0)
	series.add_sample(40.0, 4.0)

	assert_eq(series.get_sample_count(), 3, "序列应只保留 max_samples 条采样。")
	assert_almost_eq(series.get_min_value(), 20.0, 0.001, "最小值应来自保留采样。")
	assert_almost_eq(series.get_max_value(), 40.0, 0.001, "最大值应来自保留采样。")
	assert_almost_eq(series.get_average_value(), 30.0, 0.001, "平均值应来自保留采样。")
	assert_eq(series.make_sparkline(3).length(), 3, "sparkline 应按宽度输出。")
	var snapshot: Dictionary = series.to_dict(false, 3)
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "min_value"), 20.0, 0.001, "快照应复用同一轮统计的最小值。")
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "max_value"), 40.0, 0.001, "快照应复用同一轮统计的最大值。")
	assert_almost_eq(GFVariantData.get_option_float(snapshot, "average_value"), 30.0, 0.001, "快照应复用同一轮统计的平均值。")


func test_metric_series_rejects_non_finite_samples() -> void:
	var series: GFMetricSeries = GFMetricSeries.new()
	series.add_sample(NAN)
	series.add_sample(INF)
	series.add_sample(1.0, INF)

	var samples: Array[Dictionary] = series.get_samples()

	assert_eq(series.get_sample_count(), 1, "NaN 和 INF 采样不应进入序列。")
	assert_almost_eq(GFVariantData.get_option_float(samples[0], "value"), 1.0, 0.001, "有效值应保留。")
	assert_false(is_inf(GFVariantData.get_option_float(samples[0], "timestamp_seconds")), "非有限时间戳应回退到当前时间。")


func test_debug_overlay_rejects_non_finite_metric_without_creating_series() -> void:
	var overlay: GFDebugOverlayUtility = GFDebugOverlayUtility.new()

	assert_false(overlay.record_metric_sample(&"nan", NAN), "NaN 不得被报告为采样成功。")
	assert_false(overlay.record_metric_sample(&"infinity", INF), "Infinity 不得被报告为采样成功。")
	assert_eq(
		overlay.get_metric_series_snapshot(true).size(),
		0,
		"被拒绝的非有限值不得留下空指标序列。"
	)


func test_debug_overlay_records_metric_series_panel() -> void:
	var overlay: GFDebugOverlayUtility = GFDebugOverlayUtility.new()
	overlay.include_diagnostics_monitors = false
	overlay.include_recent_logs = false
	overlay.metric_series_width = 4

	assert_true(overlay.record_metric_sample(&"fps", 58.0, {
		"label": "FPS",
		"group": "Runtime",
		"timestamp_seconds": 1.0,
	}), "有效指标采样应能注册。")
	assert_true(overlay.record_metric_sample(&"fps", 60.0, {
		"timestamp_seconds": 2.0,
	}), "同一指标应追加采样。")

	var metrics: Array[Dictionary] = overlay.get_metric_series_snapshot()
	var metric_snapshot: Dictionary = metrics[0]
	assert_eq(metrics.size(), 1, "应返回一个指标序列快照。")
	assert_eq(GFVariantData.get_option_string(metric_snapshot, "label"), "FPS", "快照应保留指标标签。")
	assert_eq(GFVariantData.get_option_int(metric_snapshot, "sample_count"), 2, "快照应包含采样数量。")

	var panels: Array[Dictionary] = overlay.get_panel_snapshot()
	var metric_panel: Dictionary = panels[0]
	assert_eq(panels.size(), 1, "Overlay 应生成指标面板。")
	assert_true(GFVariantData.get_option_string(metric_panel, "content").contains("FPS"), "指标面板应包含指标标签。")
	assert_true(GFVariantData.get_option_string(metric_panel, "content").contains("latest=60.000"), "指标面板应包含最新值。")


func test_hidden_metric_series_is_filtered_by_default() -> void:
	var overlay: GFDebugOverlayUtility = GFDebugOverlayUtility.new()
	overlay.include_diagnostics_monitors = false
	overlay.include_recent_logs = false

	assert_true(overlay.record_metric_sample(&"hidden", 1.0, {
		"visible": false,
	}), "隐藏指标仍应能采样。")

	assert_eq(overlay.get_metric_series_snapshot().size(), 0, "默认快照不应包含隐藏指标。")
	assert_eq(overlay.get_metric_series_snapshot(true).size(), 1, "include_hidden 时应包含隐藏指标。")


func test_debug_overlay_rejects_metric_series_above_limit() -> void:
	var overlay: GFDebugOverlayUtility = GFDebugOverlayUtility.new()
	overlay.max_metric_series = 1
	var first: GFMetricSeries = overlay.get_or_create_metric_series(&"first")
	var second: GFMetricSeries = overlay.get_or_create_metric_series(&"second")

	assert_not_null(first, "上限内指标应创建成功。")
	assert_null(second, "超过上限的指标序列应被拒绝。")
	assert_eq(overlay.get_metric_series_snapshot(true).size(), 1, "拒绝后快照不应增长。")
	assert_push_warning("[GFDebugOverlayUtility] 指标序列数量已达到上限，已拒绝创建：second")
