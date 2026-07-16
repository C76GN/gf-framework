## GFAudioPitchAnalysisTools: 纯样本音高分析工具。
##
## 对调用方提供的 mono 或 stereo 样本做能量与基频估计，返回频率、音名、
## cents 偏差和置信度报告。它不读取麦克风、不创建节点，也不接管音频采集流程。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 6.0.0
class_name GFAudioPitchAnalysisTools
extends RefCounted


# --- 常量 ---

## 自动相关基频估计算法。
## [br]
## @api public
## [br]
## @since 6.0.0
const ALGORITHM_AUTOCORRELATION: StringName = &"autocorrelation"

## 默认最低检测频率。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEFAULT_MIN_FREQUENCY_HZ: float = 50.0

## 默认最高检测频率。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEFAULT_MAX_FREQUENCY_HZ: float = 2000.0

## 默认最小 RMS。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEFAULT_MIN_RMS: float = 0.005

## 默认置信度阈值。
## [br]
## @api public
## [br]
## @since 6.0.0
const DEFAULT_CONFIDENCE_THRESHOLD: float = 0.45

## 单次分析允许的最大样本窗口硬上限。
## [br]
## @api public
## [br]
## @since 8.0.0
const MAX_SAMPLE_COUNT: int = 16384

## 单次分析允许扫描的 lag 数量硬上限。
## [br]
## @api public
## [br]
## @since 8.0.0
const MAX_LAG_COUNT: int = 4096

## 单次分析允许的保守自相关乘加工作量硬上限。
## [br]
## @api public
## [br]
## @since 8.0.0
const MAX_CORRELATION_OPERATIONS: int = 8_000_000

const _DEFAULT_MAX_SAMPLE_COUNT: int = 8192
const _DEFAULT_MAX_LAG_COUNT: int = 2048
const _DEFAULT_MAX_CORRELATION_OPERATIONS: int = MAX_CORRELATION_OPERATIONS

const _NOTE_NAMES: Array[String] = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


# --- 公共方法 ---

## 分析 mono 样本。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param samples: mono PCM 样本。
## [br]
## @param sample_rate: 样本率。
## [br]
## @param options: 分析选项。
## [br]
## @schema samples: PackedFloat32Array mono samples in -1..1 range.
## [br]
## @schema options: Dictionary，可包含 min_frequency_hz、max_frequency_hz、min_rms、confidence_threshold、start_index、sample_count、max_sample_count、max_lag_count 和 max_correlation_operations。
## [br]
## @return 分析报告。
## [br]
## @schema return: Dictionary with ok, detected, frequency_hz, confidence, rms, lag, note_number, note_name, cents, issues, and issue_count.
static func analyze_mono_samples(
	samples: PackedFloat32Array,
	sample_rate: float,
	options: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = _make_report()
	if not _is_finite_float(sample_rate) or sample_rate <= 0.0:
		_add_issue(report, &"invalid_sample_rate", "sample_rate must be positive.")
		return _finalize_report(report)

	report["input_sample_count"] = samples.size()
	var window: PackedFloat32Array = _slice_samples(samples, options, report)
	report["analyzed_sample_count"] = window.size()
	if window.size() < 8:
		_add_issue(report, &"insufficient_samples", "samples window is too small.")
		return _finalize_report(report)
	if not _samples_are_finite(window):
		_add_issue(report, &"non_finite_sample", "samples must not contain NaN or Infinity.")
		return _finalize_report(report)

	var rms: float = calculate_rms(window)
	report["rms"] = rms
	var min_rms: float = _finite_or_default(GFVariantData.get_option_float(options, "min_rms", DEFAULT_MIN_RMS), DEFAULT_MIN_RMS)
	if rms < min_rms:
		_add_issue(report, &"signal_too_quiet", "RMS is below min_rms.")
		return _finalize_report(report)

	var requested_min_frequency: float = _finite_or_default(
		GFVariantData.get_option_float(options, "min_frequency_hz", DEFAULT_MIN_FREQUENCY_HZ),
		DEFAULT_MIN_FREQUENCY_HZ
	)
	var requested_max_frequency: float = _finite_or_default(
		GFVariantData.get_option_float(options, "max_frequency_hz", DEFAULT_MAX_FREQUENCY_HZ),
		DEFAULT_MAX_FREQUENCY_HZ
	)
	var min_frequency: float = maxf(requested_min_frequency, 1.0)
	var max_frequency: float = minf(
		requested_max_frequency,
		sample_rate * 0.5
	)
	if max_frequency <= min_frequency:
		_add_issue(report, &"invalid_frequency_range", "max_frequency_hz must be greater than min_frequency_hz.")
		return _finalize_report(report)

	var normalized: PackedFloat32Array = _remove_dc_offset(window)
	var min_lag: int = maxi(floori(sample_rate / max_frequency), 1)
	var max_lag: int = mini(ceili(sample_rate / min_frequency), normalized.size() - 2)
	if max_lag <= min_lag:
		_add_issue(report, &"insufficient_lag_range", "sample window is too small for the requested frequency range.")
		return _finalize_report(report)

	var requested_lag_count: int = max_lag - min_lag + 1
	var max_lag_count: int = clampi(
		GFVariantData.get_option_int(options, "max_lag_count", _DEFAULT_MAX_LAG_COUNT),
		1,
		MAX_LAG_COUNT
	)
	var max_operations: int = clampi(
		GFVariantData.get_option_int(
			options,
			"max_correlation_operations",
			_DEFAULT_MAX_CORRELATION_OPERATIONS
		),
		1,
		MAX_CORRELATION_OPERATIONS
	)
	var normalized_size: int = maxi(normalized.size(), 1)
	var operation_lag_limit: int = maxi(floori(float(max_operations) / float(normalized_size)), 1)
	var lag_count: int = mini(requested_lag_count, mini(max_lag_count, operation_lag_limit))
	if lag_count < requested_lag_count:
		report["truncated"] = true
	max_lag = min_lag + lag_count - 1
	report["lag_count"] = lag_count
	report["correlation_operations"] = lag_count * normalized.size()

	var best_lag: int = 0
	var best_confidence: float = -1.0
	var correlations: Array[float] = []
	for lag: int in range(min_lag, max_lag + 1):
		var confidence: float = _normalized_autocorrelation(normalized, lag)
		correlations.append(confidence)
		if confidence > best_confidence:
			best_confidence = confidence
			best_lag = lag

	var peak_threshold: float = _finite_or_default(GFVariantData.get_option_float(options, "peak_pick_threshold", 0.75), 0.75)
	for offset: int in range(1, correlations.size() - 1):
		var previous_confidence: float = correlations[offset - 1]
		var current_confidence: float = correlations[offset]
		var next_confidence: float = correlations[offset + 1]
		if (
			current_confidence >= peak_threshold
			and current_confidence >= previous_confidence
			and current_confidence >= next_confidence
		):
			best_confidence = current_confidence
			best_lag = min_lag + offset
			break

	if best_lag <= 0:
		_add_issue(report, &"pitch_not_found", "No usable autocorrelation peak was found.")
		return _finalize_report(report)

	var frequency: float = sample_rate / float(best_lag)
	var threshold: float = _finite_or_default(
		GFVariantData.get_option_float(options, "confidence_threshold", DEFAULT_CONFIDENCE_THRESHOLD),
		DEFAULT_CONFIDENCE_THRESHOLD
	)
	var note: Dictionary = frequency_to_note(frequency)
	report["ok"] = true
	report["detected"] = best_confidence >= threshold
	report["frequency_hz"] = frequency
	report["confidence"] = best_confidence
	report["lag"] = best_lag
	report["algorithm"] = ALGORITHM_AUTOCORRELATION
	report["note_number"] = GFVariantData.get_option_int(note, "note_number", -1)
	report["note_name"] = GFVariantData.get_option_string(note, "note_name")
	report["cents"] = GFVariantData.get_option_float(note, "cents")
	if not GFVariantData.get_option_bool(report, "detected"):
		_add_issue(report, &"low_confidence", "Pitch confidence is below threshold.")
	return _finalize_report(report)


## 分析 stereo 帧。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param frames: stereo PCM 帧。
## [br]
## @param sample_rate: 样本率。
## [br]
## @param options: 分析选项。
## [br]
## @schema frames: PackedVector2Array where x/y are left/right samples.
## [br]
## @schema options: Dictionary forwarded to analyze_mono_samples(), including sample and work budgets.
## [br]
## @return 分析报告。
## [br]
## @schema return: Dictionary with ok, detected, frequency_hz, confidence, rms, lag, note_number, note_name, cents, issues, issue_count, and stereo_mix_mode.
static func analyze_stereo_frames(
	frames: PackedVector2Array,
	sample_rate: float,
	options: Dictionary = {}
) -> Dictionary:
	var start_index: int = clampi(GFVariantData.get_option_int(options, "start_index", 0), 0, frames.size())
	var requested_count: int = clampi(
		GFVariantData.get_option_int(options, "sample_count", frames.size() - start_index),
		0,
		frames.size() - start_index
	)
	var max_sample_count: int = _resolve_max_sample_count(options)
	var frame_count: int = mini(requested_count, max_sample_count)
	var left: PackedFloat32Array = PackedFloat32Array()
	var right: PackedFloat32Array = PackedFloat32Array()
	var mid: PackedFloat32Array = PackedFloat32Array()
	var side: PackedFloat32Array = PackedFloat32Array()
	var _left_resize_error: Error = left.resize(frame_count) as Error
	var _right_resize_error: Error = right.resize(frame_count) as Error
	var _mid_resize_error: Error = mid.resize(frame_count) as Error
	var _side_resize_error: Error = side.resize(frame_count) as Error
	for index: int in range(frame_count):
		var frame: Vector2 = frames[start_index + index]
		left[index] = frame.x
		right[index] = frame.y
		mid[index] = (frame.x + frame.y) * 0.5
		side[index] = (frame.x - frame.y) * 0.5

	var selected: Dictionary = _select_stereo_pitch_candidate(left, right, mid, side)
	var mono_options: Dictionary = options.duplicate(true)
	mono_options["start_index"] = 0
	mono_options["sample_count"] = frame_count
	mono_options["max_sample_count"] = frame_count
	var report: Dictionary = analyze_mono_samples(
		_get_float_array_value(GFVariantData.get_option_value(selected, "samples", mid)),
		sample_rate,
		mono_options
	)
	report["input_sample_count"] = frames.size()
	if frame_count < requested_count:
		report["truncated"] = true
	report["stereo_mix_mode"] = GFVariantData.get_option_string_name(selected, "mode", &"mid")
	return report


## 计算样本 RMS。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param samples: mono PCM 样本。
## [br]
## @schema samples: PackedFloat32Array mono samples.
## [br]
## @return RMS 值。
static func calculate_rms(samples: PackedFloat32Array) -> float:
	if samples.is_empty():
		return 0.0
	var sum: float = 0.0
	for sample: float in samples:
		if not _is_finite_float(sample):
			return 0.0
		sum += sample * sample
	return sqrt(sum / float(samples.size()))


## 将频率转换为十二平均律音名。
## [br]
## @api public
## [br]
## @since 6.0.0
## [br]
## @param frequency_hz: 频率。
## [br]
## @return 音名报告。
## [br]
## @schema return: Dictionary with ok, frequency_hz, note_number, note_name, midi_float, and cents.
static func frequency_to_note(frequency_hz: float) -> Dictionary:
	if not _is_finite_float(frequency_hz) or frequency_hz <= 0.0:
		return {
			"ok": false,
			"frequency_hz": 0.0,
			"note_number": -1,
			"note_name": "",
			"midi_float": 0.0,
			"cents": 0.0,
		}
	var midi_float: float = 69.0 + 12.0 * (log(frequency_hz / 440.0) / log(2.0))
	var note_number: int = roundi(midi_float)
	var note_index: int = posmod(note_number, 12)
	var octave: int = floori(float(note_number) / 12.0) - 1
	return {
		"ok": true,
		"frequency_hz": frequency_hz,
		"note_number": note_number,
		"note_name": "%s%d" % [_NOTE_NAMES[note_index], octave],
		"midi_float": midi_float,
		"cents": (midi_float - float(note_number)) * 100.0,
	}


# --- 私有/辅助方法 ---

static func _slice_samples(
	samples: PackedFloat32Array,
	options: Dictionary,
	report: Dictionary
) -> PackedFloat32Array:
	var start_index: int = clampi(GFVariantData.get_option_int(options, "start_index", 0), 0, samples.size())
	var requested_count: int = GFVariantData.get_option_int(options, "sample_count", samples.size() - start_index)
	requested_count = clampi(requested_count, 0, samples.size() - start_index)
	var count: int = mini(requested_count, _resolve_max_sample_count(options))
	if count < requested_count:
		report["truncated"] = true
	var result: PackedFloat32Array = PackedFloat32Array()
	var _result_resize_error: Error = result.resize(count) as Error
	for index: int in range(count):
		result[index] = samples[start_index + index]
	return result


static func _resolve_max_sample_count(options: Dictionary) -> int:
	return clampi(
		GFVariantData.get_option_int(options, "max_sample_count", _DEFAULT_MAX_SAMPLE_COUNT),
		8,
		MAX_SAMPLE_COUNT
	)


static func _remove_dc_offset(samples: PackedFloat32Array) -> PackedFloat32Array:
	var mean: float = 0.0
	for sample: float in samples:
		mean += sample
	mean /= float(samples.size())
	var result: PackedFloat32Array = PackedFloat32Array()
	var _result_resize_error: Error = result.resize(samples.size()) as Error
	for index: int in range(samples.size()):
		result[index] = samples[index] - mean
	return result


static func _select_stereo_pitch_candidate(
	left: PackedFloat32Array,
	right: PackedFloat32Array,
	mid: PackedFloat32Array,
	side: PackedFloat32Array
) -> Dictionary:
	var candidates: Array[Dictionary] = [
		{ "mode": &"mid", "samples": mid, "rms": calculate_rms(mid) },
		{ "mode": &"side", "samples": side, "rms": calculate_rms(side) },
		{ "mode": &"left", "samples": left, "rms": calculate_rms(left) },
		{ "mode": &"right", "samples": right, "rms": calculate_rms(right) },
	]
	var best: Dictionary = candidates[0]
	for candidate: Dictionary in candidates:
		if GFVariantData.get_option_float(candidate, "rms") > GFVariantData.get_option_float(best, "rms"):
			best = candidate
	return best


static func _get_float_array_value(value: Variant) -> PackedFloat32Array:
	if value is PackedFloat32Array:
		var samples: PackedFloat32Array = value
		return samples
	return PackedFloat32Array()


static func _normalized_autocorrelation(samples: PackedFloat32Array, lag: int) -> float:
	var count: int = samples.size() - lag
	if count <= 1:
		return -1.0
	var numerator: float = 0.0
	var left_energy: float = 0.0
	var right_energy: float = 0.0
	for index: int in range(count):
		var left: float = samples[index]
		var right: float = samples[index + lag]
		if not _is_finite_float(left) or not _is_finite_float(right):
			return -1.0
		numerator += left * right
		left_energy += left * left
		right_energy += right * right
	if (
		left_energy <= 0.0
		or right_energy <= 0.0
		or not _is_finite_float(left_energy)
		or not _is_finite_float(right_energy)
	):
		return -1.0
	return numerator / sqrt(left_energy * right_energy)


static func _samples_are_finite(samples: PackedFloat32Array) -> bool:
	for sample: float in samples:
		if not _is_finite_float(sample):
			return false
	return true


static func _finite_or_default(value: float, default_value: float) -> float:
	return value if _is_finite_float(value) else default_value


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _make_report() -> Dictionary:
	return {
		"ok": false,
		"detected": false,
		"frequency_hz": 0.0,
		"confidence": 0.0,
		"rms": 0.0,
		"lag": 0,
		"algorithm": ALGORITHM_AUTOCORRELATION,
		"note_number": -1,
		"note_name": "",
		"cents": 0.0,
		"issues": [],
		"issue_count": 0,
		"input_sample_count": 0,
		"analyzed_sample_count": 0,
		"lag_count": 0,
		"correlation_operations": 0,
		"truncated": false,
	}


static func _add_issue(report: Dictionary, kind: StringName, message: String) -> void:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	issues.append({
		"kind": kind,
		"message": message,
	})
	report["issues"] = issues


static func _finalize_report(report: Dictionary) -> Dictionary:
	var issues: Array = GFVariantData.get_option_array(report, "issues")
	report["issue_count"] = issues.size()
	return report
