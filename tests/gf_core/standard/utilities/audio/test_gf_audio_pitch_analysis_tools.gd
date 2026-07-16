## 测试纯样本音高分析工具。
extends GutTest


func test_audio_pitch_analysis_detects_a4_sine_wave() -> void:
	var sample_rate: float = 44100.0
	var samples: PackedFloat32Array = _make_sine_wave(440.0, sample_rate, 4096)

	var report: Dictionary = GFAudioPitchAnalysisTools.analyze_mono_samples(samples, sample_rate, {
		"min_frequency_hz": 80.0,
		"max_frequency_hz": 1000.0,
		"confidence_threshold": 0.3,
	})

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效样本应完成分析。")
	assert_true(GFVariantData.get_option_bool(report, "detected"), "A4 正弦波应被检测为有音高。")
	assert_almost_eq(GFVariantData.get_option_float(report, "frequency_hz"), 440.0, 5.0, "检测频率应接近 A4。")
	assert_eq(GFVariantData.get_option_string(report, "note_name"), "A4", "A4 频率应映射到 A4 音名。")


func test_audio_pitch_analysis_reports_quiet_signal() -> void:
	var samples: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])

	var report: Dictionary = GFAudioPitchAnalysisTools.analyze_mono_samples(samples, 44100.0)

	assert_false(GFVariantData.get_option_bool(report, "detected"), "静音不应报告检测到音高。")
	assert_true(_has_issue(report, &"signal_too_quiet"), "静音应报告 signal_too_quiet。")


func test_audio_pitch_analysis_sanitizes_non_finite_reports() -> void:
	var invalid_note: Dictionary = GFAudioPitchAnalysisTools.frequency_to_note(NAN)
	var samples: PackedFloat32Array = PackedFloat32Array([0.0, NAN, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])

	var report: Dictionary = GFAudioPitchAnalysisTools.analyze_mono_samples(samples, 44100.0)
	var invalid_note_json: String = JSON.stringify(invalid_note)
	var report_json: String = JSON.stringify(report)

	assert_false(GFVariantData.get_option_bool(invalid_note, "ok"), "非有限频率不应生成有效音名。")
	assert_almost_eq(GFVariantData.get_option_float(invalid_note, "frequency_hz"), 0.0, 0.001, "非有限频率报告应使用 JSON 安全值。")
	assert_true(_has_issue(report, &"non_finite_sample"), "非有限样本应被报告为输入问题。")
	assert_false(invalid_note_json.contains("null"), "频率报告不应依赖 JSON.stringify 将 NaN 替换为 null。")
	assert_false(report_json.contains("null"), "分析报告不应依赖 JSON.stringify 将 NaN 替换为 null。")


func test_audio_pitch_analysis_detects_antiphase_stereo_signal() -> void:
	var sample_rate: float = 44100.0
	var frames: PackedVector2Array = _make_antiphase_stereo_sine_wave(440.0, sample_rate, 4096)

	var report: Dictionary = GFAudioPitchAnalysisTools.analyze_stereo_frames(frames, sample_rate, {
		"min_frequency_hz": 80.0,
		"max_frequency_hz": 1000.0,
		"confidence_threshold": 0.3,
	})

	assert_true(GFVariantData.get_option_bool(report, "detected"), "左右反相但单声道有效的 stereo 输入仍应检测到音高。")
	assert_almost_eq(GFVariantData.get_option_float(report, "frequency_hz"), 440.0, 5.0, "反相 stereo 检测频率应接近 A4。")
	assert_ne(GFVariantData.get_option_string_name(report, "stereo_mix_mode"), &"mid", "反相 stereo 不应选择被抵消的 mid 通道。")


func test_audio_pitch_analysis_enforces_sample_lag_and_work_budgets() -> void:
	var samples: PackedFloat32Array = _make_sine_wave(110.0, 44100.0, 20000)

	var report: Dictionary = GFAudioPitchAnalysisTools.analyze_mono_samples(samples, 44100.0, {
		"min_frequency_hz": 1.0,
		"sample_count": 20000,
		"max_sample_count": 20000,
		"max_lag_count": 20000,
		"max_correlation_operations": 1000000000,
	})

	assert_lte(
		GFVariantData.get_option_int(report, "analyzed_sample_count"),
		GFAudioPitchAnalysisTools.MAX_SAMPLE_COUNT,
		"调用方不得把样本窗口扩大到框架硬上限之外。"
	)
	assert_lte(
		GFVariantData.get_option_int(report, "lag_count"),
		GFAudioPitchAnalysisTools.MAX_LAG_COUNT,
		"lag 扫描数量必须有硬上限。"
	)
	assert_lte(
		GFVariantData.get_option_int(report, "correlation_operations"),
		GFAudioPitchAnalysisTools.MAX_CORRELATION_OPERATIONS,
		"自相关工作量必须有稳定预算。"
	)
	assert_true(GFVariantData.get_option_bool(report, "truncated"), "输入超过预算时报告应明确标记截断。")


func _make_sine_wave(frequency_hz: float, sample_rate: float, count: int) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	var _resize_error: Error = samples.resize(count) as Error
	for index: int in range(count):
		var phase: float = TAU * frequency_hz * float(index) / sample_rate
		samples[index] = sin(phase) * 0.8
	return samples


func _make_antiphase_stereo_sine_wave(frequency_hz: float, sample_rate: float, count: int) -> PackedVector2Array:
	var frames: PackedVector2Array = PackedVector2Array()
	var _resize_error: Error = frames.resize(count) as Error
	for index: int in range(count):
		var phase: float = TAU * frequency_hz * float(index) / sample_rate
		var sample: float = sin(phase) * 0.8
		frames[index] = Vector2(sample, -sample)
	return frames


func _has_issue(report: Dictionary, kind: StringName) -> bool:
	for issue_value: Variant in GFVariantData.get_option_array(report, "issues"):
		var issue: Dictionary = GFVariantData.as_dictionary(issue_value)
		if GFVariantData.get_option_string_name(issue, "kind") == kind:
			return true
	return false
