## 测试 GFNoiseFieldTools 的二维噪声场采样、归一化和输入边界。
extends GutTest


# --- 常量 ---

const GF_NOISE_FIELD_TOOLS_SCRIPT = preload("res://addons/gf/standard/foundation/math/gf_noise_field_tools.gd")


# --- 测试方法 ---

## 验证自定义采样器可以按行优先顺序生成样本并报告统计。
func test_sample_grid_2d_uses_callable_sampler_and_reports_stats() -> void:
	var report: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.sample_grid_2d(
		Vector2i(3, 2),
		{
			"origin": Vector2(1.0, 2.0),
			"step": Vector2(2.0, 3.0),
			"sampler": func(position: Vector2, _cell: Vector2i, _metadata: Dictionary) -> float:
				return position.x + position.y,
		}
	)
	var samples: PackedFloat32Array = _get_float_samples(report, "samples")
	var normalized_samples: PackedFloat32Array = _get_float_samples(report, "normalized_samples")

	assert_true(GFVariantData.get_option_bool(report, "ok"), "有效采样器应生成噪声场。")
	assert_eq(GFVariantData.get_option_string(report, "source"), "callable", "报告应记录采样源。")
	assert_eq(samples, PackedFloat32Array([3.0, 5.0, 7.0, 6.0, 8.0, 10.0]), "样本应按行优先顺序写入。")
	assert_almost_eq(GFVariantData.get_option_float(report, "min_value"), 3.0, 0.001)
	assert_almost_eq(GFVariantData.get_option_float(report, "max_value"), 10.0, 0.001)
	assert_almost_eq(GFVariantData.get_option_float(report, "average"), 6.5, 0.001)
	assert_almost_eq(normalized_samples[0], 0.0, 0.001)
	assert_almost_eq(normalized_samples[5], 1.0, 0.001)


## 验证默认 FastNoiseLite 路径由 seed、frequency 和 grid_size 稳定复现。
func test_sample_grid_2d_can_use_fast_noise_lite_deterministically() -> void:
	var options: Dictionary = {
		"seed": 123,
		"frequency": 0.08,
	}
	var first_report: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.sample_grid_2d(Vector2i(4, 4), options)
	var second_report: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.sample_grid_2d(Vector2i(4, 4), options)

	assert_true(GFVariantData.get_option_bool(first_report, "ok"), "有效 FastNoiseLite 选项应生成噪声场。")
	assert_eq(GFVariantData.get_option_string(first_report, "source"), "fast_noise_lite", "报告应记录 FastNoiseLite 来源。")
	assert_eq(_get_float_samples(first_report, "samples"), _get_float_samples(second_report, "samples"), "相同输入应生成稳定样本。")
	assert_eq(GFVariantData.get_option_int(first_report, "sample_count"), 16, "报告应记录采样数量。")


## 验证归一化工具处理常量样本和显式范围。
func test_normalize_samples_handles_constant_and_explicit_range() -> void:
	var constant_report: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.normalize_samples(
		PackedFloat32Array([2.0, 2.0, 2.0]),
		{ "constant_value": 0.5 }
	)
	var explicit_report: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.normalize_samples(
		PackedFloat32Array([10.0, 15.0, 20.0]),
		{
			"minimum": 0.0,
			"maximum": 20.0,
		}
	)

	assert_true(GFVariantData.get_option_bool(constant_report, "ok"), "常量样本也应可归一化。")
	assert_true(GFVariantData.get_option_bool(constant_report, "constant_range"), "常量样本应报告 constant_range。")
	assert_eq(_get_float_samples(constant_report, "normalized_samples"), PackedFloat32Array([0.5, 0.5, 0.5]), "常量样本应写入 constant_value。")
	assert_eq(_get_float_samples(explicit_report, "normalized_samples"), PackedFloat32Array([0.5, 0.75, 1.0]), "显式范围应覆盖自动范围。")


## 验证无效输入返回结构化失败报告。
func test_sample_grid_2d_reports_invalid_inputs() -> void:
	var invalid_size: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.sample_grid_2d(Vector2i.ZERO)
	var too_many_samples: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.sample_grid_2d(
		Vector2i(3, 3),
		{ "max_samples": 4 }
	)
	var invalid_sample: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.sample_grid_2d(
		Vector2i(1, 1),
		{
			"sampler": func(_position: Vector2, _cell: Vector2i, _metadata: Dictionary) -> float:
				return NAN,
		}
	)
	var invalid_normalize: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.normalize_samples(PackedFloat32Array([1.0, NAN]))

	assert_false(GFVariantData.get_option_bool(invalid_size, "ok", true), "空尺寸应失败。")
	assert_false(GFVariantData.get_option_bool(too_many_samples, "ok", true), "超过上限应失败。")
	assert_false(GFVariantData.get_option_bool(invalid_sample, "ok", true), "非有限采样值应失败。")
	assert_false(GFVariantData.get_option_bool(invalid_normalize, "ok", true), "非有限输入样本应失败。")
	assert_eq(_get_float_samples(invalid_sample, "samples"), PackedFloat32Array(), "失败报告不应携带部分样本。")


func test_sample_grid_2d_rejects_invalid_noise_type() -> void:
	var report: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.sample_grid_2d(
		Vector2i(1, 1),
		{ "noise_type": 999999 }
	)

	assert_false(GFVariantData.get_option_bool(report, "ok", true), "非法 FastNoiseLite.NoiseType 不应被隐式枚举转换吞掉。")
	assert_eq(GFVariantData.get_option_string(report, "source"), "fast_noise_lite", "失败报告应标明噪声源。")
	assert_eq(GFVariantData.get_option_string(report, "error"), "noise_type must be a valid FastNoiseLite.NoiseType.")


func test_noise_reports_have_json_compatible_export() -> void:
	var report: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.sample_grid_2d(
		Vector2i(1, 1),
		{
			"sampler": func(_position: Vector2, _cell: Vector2i, _metadata: Dictionary) -> float:
				return 1.0,
		}
	)
	var safe_report: Dictionary = GF_NOISE_FIELD_TOOLS_SCRIPT.to_json_compatible_report(report)
	var json_text: String = JSON.stringify(safe_report)

	assert_false(json_text.is_empty(), "JSON-safe 噪声报告应可序列化。")
	assert_false(json_text.contains(":null"), "JSON-safe 噪声报告不应依赖 JSON.stringify 降级非法值。")


# --- 私有/辅助方法 ---

func _get_float_samples(report: Dictionary, key_text: String) -> PackedFloat32Array:
	var value: Variant = GFVariantData.get_option_value(report, key_text, PackedFloat32Array())
	if value is PackedFloat32Array:
		var samples: PackedFloat32Array = value
		return samples
	return PackedFloat32Array()
