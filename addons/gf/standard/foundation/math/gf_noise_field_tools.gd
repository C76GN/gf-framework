## GFNoiseFieldTools: 通用二维噪声场采样工具。
##
## 使用 Godot 原生 FastNoiseLite 或调用方传入的采样回调生成行优先浮点样本，
## 并输出范围、平均值和可选归一化样本。它只处理纯数据，不创建地形、
## 材质、节点、贴图或程序化内容对象。
## [br]
## @api public
## [br]
## @category runtime_service
## [br]
## @since 8.0.0
class_name GFNoiseFieldTools
extends RefCounted


# --- 常量 ---

## 默认最大采样数量，避免把超大实时噪声场交给纯 GDScript。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_MAX_GRID_SAMPLES: int = 1048576

## 未提供 noise 时创建 FastNoiseLite 使用的默认频率。
## [br]
## @api public
## [br]
## @since 8.0.0
const DEFAULT_NOISE_FREQUENCY: float = 0.01

const _GF_REPORT_VALUE_CODEC_SCRIPT = preload("res://addons/gf/kernel/core/gf_report_value_codec.gd")


# --- 公共方法 ---

## 采样二维行优先噪声场。
##
## 采样源优先使用 options.sampler；未提供 sampler 时使用 options.noise，
## 再未提供时按 seed 与 frequency 创建 FastNoiseLite。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param grid_size: 采样网格尺寸，x 为列数，y 为行数。
## [br]
## @param options: 采样选项。
## [br]
## @return 采样报告。
## [br]
## @schema options: Dictionary，可包含 sampler、metadata、noise、seed、frequency、noise_type、fractal_octaves、origin、step、include_normalized、constant_value 与 max_samples。sampler 为 Callable，签名为 Callable(position: Vector2, cell: Vector2i, metadata: Dictionary) -> int|float；noise 为 FastNoiseLite。
## [br]
## @schema return: Dictionary，包含 ok、error、source、grid_size、origin、step、sample_count、samples、min_value、max_value、average、normalized_samples 与 constant_range 字段。
static func sample_grid_2d(grid_size: Vector2i, options: Dictionary = {}) -> Dictionary:
	var origin: Vector2 = GFVariantData.get_option_vector2(options, "origin", Vector2.ZERO)
	var step: Vector2 = GFVariantData.get_option_vector2(options, "step", Vector2.ONE)
	var max_samples: int = maxi(
		GFVariantData.get_option_int(options, "max_samples", DEFAULT_MAX_GRID_SAMPLES),
		0
	)
	var validation_error: String = _get_grid_input_error(grid_size, origin, step, max_samples)
	if not validation_error.is_empty():
		return _make_grid_result(false, validation_error, "", grid_size, origin, step)

	var source: Dictionary = _resolve_source(options)
	if not GFVariantData.get_option_bool(source, "ok", false):
		return _make_grid_result(
			false,
			GFVariantData.get_option_string(source, "error"),
			GFVariantData.get_option_string(source, "source"),
			grid_size,
			origin,
			step
		)

	var samples: PackedFloat32Array = PackedFloat32Array()
	var sample_count: int = grid_size.x * grid_size.y
	var _resize_result: int = samples.resize(sample_count)
	var min_value: float = 0.0
	var max_value: float = 0.0
	var sum: float = 0.0
	var source_name: String = GFVariantData.get_option_string(source, "source")
	var metadata: Dictionary = GFVariantData.get_option_dictionary(options, "metadata")
	var sample_index: int = 0

	for y: int in range(grid_size.y):
		for x: int in range(grid_size.x):
			var cell: Vector2i = Vector2i(x, y)
			var position: Vector2 = origin + Vector2(float(x) * step.x, float(y) * step.y)
			var sample_value: float = _sample_source(source, position, cell, metadata)
			if not _is_finite_float(sample_value):
				return _make_grid_result(
					false,
					"sample must be a finite number.",
					source_name,
					grid_size,
					origin,
					step
				)

			samples[sample_index] = sample_value
			if sample_index == 0:
				min_value = sample_value
				max_value = sample_value
			else:
				min_value = minf(min_value, sample_value)
				max_value = maxf(max_value, sample_value)
			sum += sample_value
			sample_index += 1

	var result: Dictionary = _make_grid_result(true, "", source_name, grid_size, origin, step)
	result["samples"] = samples
	result["sample_count"] = samples.size()
	result["min_value"] = min_value
	result["max_value"] = max_value
	result["average"] = sum / float(samples.size())

	if GFVariantData.get_option_bool(options, "include_normalized", true):
		var normalized_report: Dictionary = normalize_samples(
			samples,
			{
				"minimum": min_value,
				"maximum": max_value,
				"constant_value": GFVariantData.get_option_float(options, "constant_value", 0.0),
			}
		)
		if GFVariantData.get_option_bool(normalized_report, "ok", false):
			result["normalized_samples"] = GFVariantData.get_option_value(
				normalized_report,
				"normalized_samples",
				PackedFloat32Array()
			)
			result["constant_range"] = GFVariantData.get_option_bool(normalized_report, "constant_range")
	return result


## 归一化浮点样本。
##
## 默认使用输入样本的最小值和最大值，把每个值映射到 0.0 到 1.0。
## 如果范围为常量，输出 constant_value，默认为 0.0。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param samples: 待归一化的浮点样本。
## [br]
## @param options: 归一化选项。
## [br]
## @return 归一化报告。
## [br]
## @schema options: Dictionary，可包含 minimum、maximum、constant_value 与 clamp。
## [br]
## @schema return: Dictionary，包含 ok、error、sample_count、min_value、max_value、constant_value、constant_range 与 normalized_samples 字段。
static func normalize_samples(samples: PackedFloat32Array, options: Dictionary = {}) -> Dictionary:
	var report: Dictionary = _make_normalize_result(false, "", samples.size())
	if samples.is_empty():
		report["error"] = "samples must not be empty."
		return report

	var stats: Dictionary = _get_sample_stats(samples)
	if not GFVariantData.get_option_bool(stats, "ok", false):
		report["error"] = GFVariantData.get_option_string(stats, "error")
		return report

	var min_value: float = GFVariantData.get_option_float(stats, "min_value")
	var max_value: float = GFVariantData.get_option_float(stats, "max_value")
	if _has_option(options, "minimum"):
		min_value = GFVariantData.get_option_float(options, "minimum", min_value)
	if _has_option(options, "maximum"):
		max_value = GFVariantData.get_option_float(options, "maximum", max_value)

	var constant_value: float = GFVariantData.get_option_float(options, "constant_value", 0.0)
	if not _is_finite_float(min_value) or not _is_finite_float(max_value):
		report["error"] = "minimum and maximum must be finite."
		return report
	if max_value < min_value:
		report["error"] = "maximum must be greater than or equal to minimum."
		return report
	if not _is_finite_float(constant_value):
		report["error"] = "constant_value must be finite."
		return report

	var normalized_samples: PackedFloat32Array = PackedFloat32Array()
	var _resize_result: int = normalized_samples.resize(samples.size())
	var span: float = max_value - min_value
	var constant_range: bool = span <= 0.0
	var should_clamp: bool = GFVariantData.get_option_bool(options, "clamp", true)
	for index: int in range(samples.size()):
		var normalized_value: float = constant_value
		if not constant_range:
			normalized_value = (samples[index] - min_value) / span
			if should_clamp:
				normalized_value = clampf(normalized_value, 0.0, 1.0)
		normalized_samples[index] = normalized_value

	report["ok"] = true
	report["min_value"] = min_value
	report["max_value"] = max_value
	report["constant_value"] = constant_value
	report["constant_range"] = constant_range
	report["normalized_samples"] = normalized_samples
	return report


## 将噪声工具报告转换为 JSON.stringify() 安全的结构。
## [br]
## @api public
## [br]
## @since 8.0.0
## [br]
## @param report: sample_grid_2d() 或 normalize_samples() 返回的报告。
## [br]
## @param options: 报告编码选项，透传给 GFReportValueCodec。
## [br]
## @return: JSON 兼容报告。
## [br]
## @schema report: Dictionary report returned by GFNoiseFieldTools.
## [br]
## @schema options: Dictionary with GFReportValueCodec options.
## [br]
## @schema return: Dictionary safe for JSON.stringify().
static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
	return GFVariantData.as_dictionary(_GF_REPORT_VALUE_CODEC_SCRIPT.to_json_compatible(report, options))


# --- 私有/辅助方法 ---

static func _get_grid_input_error(
	grid_size: Vector2i,
	origin: Vector2,
	step: Vector2,
	max_samples: int
) -> String:
	if grid_size.x <= 0 or grid_size.y <= 0:
		return "grid_size must contain positive dimensions."
	if not _is_finite_vector2(origin):
		return "origin must contain finite values."
	if not _is_finite_vector2(step):
		return "step must contain finite values."

	var sample_count: int = grid_size.x * grid_size.y
	if max_samples <= 0:
		return "max_samples must be greater than 0."
	if sample_count > max_samples:
		return "sample_count exceeds max_samples."
	return ""


static func _resolve_source(options: Dictionary) -> Dictionary:
	if _has_option(options, "sampler"):
		var sampler_value: Variant = GFVariantData.get_option_value(options, "sampler", Callable())
		if not (sampler_value is Callable):
			return { "ok": false, "source": "callable", "error": "sampler must be a Callable." }
		var sampler: Callable = sampler_value
		if not sampler.is_valid():
			return { "ok": false, "source": "callable", "error": "sampler must be valid." }
		return { "ok": true, "source": "callable", "error": "", "sampler": sampler }

	if _has_option(options, "noise"):
		var noise_value: Variant = GFVariantData.get_option_value(options, "noise")
		if not (noise_value is FastNoiseLite):
			return { "ok": false, "source": "fast_noise_lite", "error": "noise must be FastNoiseLite." }
		var provided_noise: FastNoiseLite = noise_value
		return { "ok": true, "source": "fast_noise_lite", "error": "", "noise": provided_noise }

	var frequency: float = GFVariantData.get_option_float(options, "frequency", DEFAULT_NOISE_FREQUENCY)
	if not _is_finite_float(frequency) or frequency <= 0.0:
		return { "ok": false, "source": "fast_noise_lite", "error": "frequency must be a positive finite value." }

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = GFVariantData.get_option_int(options, "seed", 0)
	noise.frequency = frequency
	if _has_option(options, "noise_type"):
		var noise_type: int = GFVariantData.get_option_int(options, "noise_type", noise.noise_type)
		if not _is_valid_noise_type(noise_type):
			return {
				"ok": false,
				"source": "fast_noise_lite",
				"error": "noise_type must be a valid FastNoiseLite.NoiseType.",
			}
		noise.noise_type = _to_noise_type(noise_type, noise.noise_type)
	if _has_option(options, "fractal_octaves"):
		noise.fractal_octaves = maxi(GFVariantData.get_option_int(options, "fractal_octaves", noise.fractal_octaves), 1)
	return { "ok": true, "source": "fast_noise_lite", "error": "", "noise": noise }


static func _sample_source(
	source: Dictionary,
	position: Vector2,
	cell: Vector2i,
	metadata: Dictionary
) -> float:
	var source_name: String = GFVariantData.get_option_string(source, "source")
	if source_name == "callable":
		var sampler_value: Variant = GFVariantData.get_option_value(source, "sampler", Callable())
		if sampler_value is Callable:
			var sampler: Callable = sampler_value
			return _variant_to_float_sample(sampler.call(position, cell, metadata))
		return NAN

	var noise_value: Variant = GFVariantData.get_option_value(source, "noise")
	if noise_value is FastNoiseLite:
		var noise: FastNoiseLite = noise_value
		return noise.get_noise_2d(position.x, position.y)
	return NAN


static func _get_sample_stats(samples: PackedFloat32Array) -> Dictionary:
	var min_value: float = 0.0
	var max_value: float = 0.0
	var sum: float = 0.0
	for index: int in range(samples.size()):
		var sample_value: float = samples[index]
		if not _is_finite_float(sample_value):
			return { "ok": false, "error": "samples must contain only finite values." }
		if index == 0:
			min_value = sample_value
			max_value = sample_value
		else:
			min_value = minf(min_value, sample_value)
			max_value = maxf(max_value, sample_value)
		sum += sample_value

	return {
		"ok": true,
		"error": "",
		"sample_count": samples.size(),
		"min_value": min_value,
		"max_value": max_value,
		"average": sum / float(samples.size()),
	}


static func _make_grid_result(
	ok: bool,
	error: String,
	source: String,
	grid_size: Vector2i,
	origin: Vector2,
	step: Vector2
) -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"source": source,
		"grid_size": grid_size,
		"origin": origin,
		"step": step,
		"sample_count": 0,
		"samples": PackedFloat32Array(),
		"min_value": 0.0,
		"max_value": 0.0,
		"average": 0.0,
		"normalized_samples": PackedFloat32Array(),
		"constant_range": false,
	}


static func _make_normalize_result(ok: bool, error: String, sample_count: int) -> Dictionary:
	return {
		"ok": ok,
		"error": error,
		"sample_count": sample_count,
		"min_value": 0.0,
		"max_value": 0.0,
		"constant_value": 0.0,
		"constant_range": false,
		"normalized_samples": PackedFloat32Array(),
	}


static func _variant_to_float_sample(value: Variant) -> float:
	if value is float:
		var float_value: float = value
		return float_value
	if value is int:
		var int_value: int = value
		return float(int_value)
	return NAN


static func _has_option(options: Dictionary, key_text: String) -> bool:
	return options.has(key_text) or options.has(StringName(key_text))


static func _is_valid_noise_type(value: int) -> bool:
	match value:
		FastNoiseLite.TYPE_SIMPLEX:
			return true
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH:
			return true
		FastNoiseLite.TYPE_CELLULAR:
			return true
		FastNoiseLite.TYPE_PERLIN:
			return true
		FastNoiseLite.TYPE_VALUE_CUBIC:
			return true
		FastNoiseLite.TYPE_VALUE:
			return true
		_:
			return false


static func _to_noise_type(value: int, fallback: FastNoiseLite.NoiseType) -> FastNoiseLite.NoiseType:
	match value:
		FastNoiseLite.TYPE_SIMPLEX:
			return FastNoiseLite.TYPE_SIMPLEX
		FastNoiseLite.TYPE_SIMPLEX_SMOOTH:
			return FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		FastNoiseLite.TYPE_CELLULAR:
			return FastNoiseLite.TYPE_CELLULAR
		FastNoiseLite.TYPE_PERLIN:
			return FastNoiseLite.TYPE_PERLIN
		FastNoiseLite.TYPE_VALUE_CUBIC:
			return FastNoiseLite.TYPE_VALUE_CUBIC
		FastNoiseLite.TYPE_VALUE:
			return FastNoiseLite.TYPE_VALUE
		_:
			return fallback


static func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)


static func _is_finite_vector2(value: Vector2) -> bool:
	return _is_finite_float(value.x) and _is_finite_float(value.y)
