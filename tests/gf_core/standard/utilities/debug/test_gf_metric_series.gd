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


func test_metric_series_preserves_order_and_nested_sample_copies_after_repeated_trimming() -> void:
	var series: GFMetricSeries = GFMetricSeries.new()
	series.max_samples = 5
	var sample_metadata: Dictionary = {"nested": {"labels": ["recorded"]}}
	for index: int in range(40):
		series.add_sample(float(index), float(index * 2), sample_metadata)
	sample_metadata["nested"]["labels"][0] = "caller changed"

	var samples: Array[Dictionary] = series.get_samples()
	assert_eq(samples.size(), 5, "多次裁剪后仍应保留容量内的最新采样。")
	for index: int in range(samples.size()):
		assert_eq(GFVariantData.get_option_float(samples[index], "value"), float(35 + index), "采样副本应始终按追加顺序排列。")
		assert_eq(GFVariantData.get_option_float(samples[index], "timestamp_seconds"), float((35 + index) * 2), "时间戳应随原采样保留。")
		assert_eq(GFVariantData.get_option_dictionary(samples[index], "metadata"), {"nested": {"labels": ["recorded"]}}, "追加采样时应隔离嵌套元数据。")
	samples[0]["metadata"]["nested"]["labels"][0] = "snapshot changed"
	var snapshot: Dictionary = series.to_dict(true, 3)
	var snapshot_samples: Array = GFVariantData.get_option_array(snapshot, "samples")
	var snapshot_sample: Dictionary = GFVariantData.as_dictionary(snapshot_samples[0])
	assert_eq(GFVariantData.get_option_dictionary(snapshot_sample, "metadata"), {"nested": {"labels": ["recorded"]}}, "修改采样副本不得污染之后的完整快照。")
	snapshot["samples"][0]["metadata"]["nested"]["labels"][0] = "full snapshot changed"
	assert_eq(GFVariantData.get_option_dictionary(series.get_samples()[0], "metadata"), {"nested": {"labels": ["recorded"]}}, "修改完整快照不得污染原序列。")


func test_metric_series_resize_clear_and_reuse_keep_retained_statistics() -> void:
	var series: GFMetricSeries = GFMetricSeries.new()
	series.max_samples = 5
	for index: int in range(20):
		series.add_sample(float(index), float(index))
	series.max_samples = 2
	assert_eq(series.get_sample_count(), 2, "缩小容量时应立即裁剪。")
	assert_eq(series.get_min_value(), 18.0, "缩容后的统计应排除旧采样。")
	assert_eq(series.get_average_value(), 18.5, "缩容后的平均值应只计算保留采样。")
	series.max_samples = 4
	series.add_sample(-2.0, 20.0)
	assert_eq(series.get_sample_count(), 3, "扩容不得恢复曾被裁剪的采样。")
	assert_eq(series.get_latest_value(), -2.0)
	series.max_samples = 0
	assert_eq(series.max_samples, 1, "非正容量应保持既有的下限 1。")
	assert_eq(series.get_sample_count(), 1)
	assert_eq(series.get_average_value(), -2.0)
	series.clear()
	assert_eq(series.get_sample_count(), 0)
	assert_eq(series.get_latest_value(), 0.0)
	assert_eq(series.get_min_value(), 0.0)
	assert_eq(series.get_max_value(), 0.0)
	assert_eq(series.get_average_value(), 0.0)
	assert_eq(series.get_normalized_values(), PackedFloat32Array())
	assert_eq(series.make_sparkline(), "")
	series.add_sample(7.0, 21.0)
	assert_eq(series.get_samples().size(), 1, "清空后应能从新采样重新开始。")
	assert_eq(series.get_average_value(), 7.0)


func test_metric_series_duplicate_has_independent_samples_and_metadata() -> void:
	var series: GFMetricSeries = GFMetricSeries.new()
	var _configured: GFMetricSeries = series.configure(&"queue", {
		"label": "Queue",
		"group": "Jobs",
		"visible": false,
		"max_samples": 2,
		"metadata": {"labels": ["source"]},
	})
	series.add_sample(1.0, 1.0, {"labels": ["first"]})
	series.add_sample(2.0, 2.0)
	series.add_sample(3.0, 3.0, {"labels": ["last"]})
	var copied: GFMetricSeries = series.duplicate_series()
	var empty_copy: GFMetricSeries = series.duplicate_series(false)
	assert_eq(copied.to_dict(true), series.to_dict(true), "复制应保留配置和按序采样。")
	assert_eq(empty_copy.get_sample_count(), 0, "配置副本不应包含采样。")
	assert_eq(empty_copy.id, series.id)
	assert_eq(empty_copy.max_samples, series.max_samples)
	copied.metadata["labels"][0] = "copy"
	copied.add_sample(99.0, 4.0)
	series.clear()
	assert_eq(copied.get_latest_value(), 99.0, "副本和原序列的追加及清空应相互独立。")
	assert_eq(GFVariantData.get_option_dictionary(copied.get_samples()[0], "metadata"), {"labels": ["last"]})
	assert_eq(GFVariantData.get_option_array(series.metadata, "labels"), ["source"], "复制的指标元数据应深度隔离。")
	assert_eq(GFVariantData.get_option_array(empty_copy.metadata, "labels"), ["source"])


func test_metric_series_sparkline_tail_uses_the_full_retained_range() -> void:
	var series: GFMetricSeries = GFMetricSeries.new()
	for value: float in [0.0, 100.0, 25.0, 50.0]:
		series.add_sample(value, 1.0)
	assert_eq(series.make_sparkline(2), "-=", "只显示末尾时仍应使用全部保留采样的范围。")
	assert_eq(series.make_sparkline(8), ".#-=", "输出宽度超过数量时不得补齐或重复采样。")
	assert_eq(series.make_sparkline(0), "")
	assert_eq(series.make_sparkline(-1), "")
	series.max_samples = 2
	assert_eq(series.make_sparkline(2), ".#", "裁剪掉极值后应使用新保留范围。")
	series.clear()
	series.add_sample(7.0, 1.0)
	series.add_sample(7.0, 2.0)
	assert_eq(series.make_sparkline(1), "=", "等值序列应显示中间强度。")
	assert_eq(series.get_normalized_values(), PackedFloat32Array([0.5, 0.5]), "公开归一化结果仍应包含全部采样。")


func test_metric_series_preserves_float32_sparkline_rounding_and_ordered_average() -> void:
	var series: GFMetricSeries = GFMetricSeries.new()
	series.add_sample(0.0, 1.0)
	series.add_sample(1.0, 2.0)
	series.add_sample(1.0 / 12.0 - 0.0000000001, 3.0)
	assert_eq(series.make_sparkline(1), ":", "字符边界应保持归一化值转为 Float32 后的舍入语义。")
	series.clear()
	series.max_samples = 3
	series.add_sample(99.0, 0.0)
	series.add_sample(1.0e16, 1.0)
	series.add_sample(1.0, 2.0)
	series.add_sample(-1.0e16, 3.0)
	assert_eq(series.get_average_value(), 0.0, "平均值应保持对保留采样按序求和的浮点语义。")


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
