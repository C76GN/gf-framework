## GFMetricSeries: 调试用短期数值序列。
##
## 保存固定长度的数值采样，并提供统计值、归一化值和 ASCII sparkline。
## 适合开发期 Overlay 观察短期趋势，不承担长期日志、遥测或业务分析职责。
## [br]
## @api public
## [br]
## @category value_object
## [br]
## @since 3.23.0
class_name GFMetricSeries
extends RefCounted


# --- 常量 ---

## sparkline 使用的 ASCII 字符，按强度从低到高排列。
## [br]
## @api public
const SPARKLINE_CHARACTERS: String = ".:-=+*#"


# --- 公共变量 ---

## 指标唯一标识。
## [br]
## @api public
var id: StringName = &""

## 显示名称。
## [br]
## @api public
var label: String = ""

## 显示分组。
## [br]
## @api public
var group: String = "Runtime"

## 是否在 Overlay 快照中显示。
## [br]
## @api public
var visible: bool = true

## 最大采样数量。
## [br]
## @api public
var max_samples: int = 120:
	set(value):
		max_samples = maxi(value, 1)
		_trim_samples()

## 项目自定义元数据。框架不解释该字段。
## [br]
## @api public
## [br]
## @schema metadata: Dictionary[String, Variant]，项目自定义元数据；框架不会读取或改写其中字段。
var metadata: Dictionary = {}


# --- 私有变量 ---

var _samples: Array[Dictionary] = []


# --- 公共方法 ---

## 配置指标序列。
## [br]
## @api public
## [br]
## @param metric_id: 指标唯一标识。
## [br]
## @param options: 可选配置，支持 label、group、visible、max_samples 和 metadata。
## [br]
## @return 当前序列，便于链式配置。
## [br]
## @schema options: Dictionary，支持 label、group、visible、max_samples 和 metadata。
func configure(metric_id: StringName, options: Dictionary = {}) -> GFMetricSeries:
	id = metric_id
	if label.is_empty():
		label = String(metric_id)
	if options.has("label"):
		var option_label: String = GFVariantData.get_option_string(options, "label")
		if not option_label.is_empty():
			label = option_label
	if options.has("group"):
		var option_group: String = GFVariantData.get_option_string(options, "group")
		if not option_group.is_empty():
			group = option_group
	if options.has("visible"):
		visible = GFVariantData.get_option_bool(options, "visible", visible)
	if options.has("max_samples"):
		max_samples = GFVariantData.get_option_int(options, "max_samples", max_samples)
	var metadata_value: Variant = GFVariantData.get_option_value(options, "metadata", null)
	if metadata_value is Dictionary:
		metadata = GFVariantData.to_dictionary(metadata_value)
	return self


## 追加一个数值采样。
## [br]
## @api public
## [br]
## @param value: 采样值。
## [br]
## @param timestamp_seconds: 采样时间；小于 0 时使用当前运行时间。
## [br]
## @param sample_metadata: 单个采样的自定义元数据。
## [br]
## @schema sample_metadata: Dictionary[String, Variant]，单个采样的项目自定义元数据。
func add_sample(value: float, timestamp_seconds: float = -1.0, sample_metadata: Dictionary = {}) -> void:
	if not _is_finite_float(value):
		return
	var timestamp: float = timestamp_seconds
	if not _is_finite_float(timestamp) or timestamp < 0.0:
		timestamp = float(Time.get_ticks_msec()) / 1000.0

	_samples.append({
		"value": value,
		"timestamp_seconds": timestamp,
		"metadata": sample_metadata.duplicate(true),
	})
	_trim_samples()


## 清空所有采样。
## [br]
## @api public
func clear() -> void:
	_samples.clear()


## 获取采样数量。
## [br]
## @api public
## [br]
## @return 当前采样数量。
func get_sample_count() -> int:
	return _samples.size()


## 获取采样副本。
## [br]
## @api public
## [br]
## @return 采样数组副本。
## [br]
## @schema return: Array[Dictionary]，每个元素包含 value、timestamp_seconds 和 metadata。
func get_samples() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sample: Dictionary in _samples:
		result.append(sample.duplicate(true))
	return result


## 获取最新采样值。
## [br]
## @api public
## [br]
## @return 最新采样值；没有采样时返回 0。
func get_latest_value() -> float:
	if _samples.is_empty():
		return 0.0
	return _get_sample_value(_samples[_samples.size() - 1])


## 获取最小采样值。
## [br]
## @api public
## [br]
## @return 最小采样值；没有采样时返回 0。
func get_min_value() -> float:
	return GFVariantData.get_option_float(_calculate_statistics(), "min_value")


## 获取最大采样值。
## [br]
## @api public
## [br]
## @return 最大采样值；没有采样时返回 0。
func get_max_value() -> float:
	return GFVariantData.get_option_float(_calculate_statistics(), "max_value")


## 获取平均采样值。
## [br]
## @api public
## [br]
## @return 平均采样值；没有采样时返回 0。
func get_average_value() -> float:
	return GFVariantData.get_option_float(_calculate_statistics(), "average_value")


## 获取归一化后的采样值。
## [br]
## @api public
## [br]
## @return 归一化值数组。
func get_normalized_values() -> PackedFloat32Array:
	if _samples.is_empty():
		return PackedFloat32Array()
	var statistics: Dictionary = _calculate_statistics()
	return _get_normalized_values_for_range(
		GFVariantData.get_option_float(statistics, "min_value"),
		GFVariantData.get_option_float(statistics, "max_value")
	)


## 生成定宽 ASCII sparkline。
## [br]
## @api public
## [br]
## @param width: 输出宽度；小于等于 0 时返回空字符串。
## [br]
## @return sparkline 文本。
func make_sparkline(width: int = 32) -> String:
	if width <= 0 or _samples.is_empty():
		return ""
	var statistics: Dictionary = _calculate_statistics()
	return _make_sparkline_for_range(
		width,
		GFVariantData.get_option_float(statistics, "min_value"),
		GFVariantData.get_option_float(statistics, "max_value")
	)
## 转换为 Dictionary。
## [br]
## @api public
## [br]
## @since 3.23.0
## [br]
## @param include_samples: 是否包含采样明细。
## [br]
## @param sparkline_width: sparkline 输出宽度。
## [br]
## @return 指标序列快照。
## [br]
## @schema return: Dictionary，包含 id、label、group、visible、max_samples、sample_count、latest_value、min_value、max_value、average_value、sparkline、metadata，可选 samples。
func to_dict(include_samples: bool = false, sparkline_width: int = 32) -> Dictionary:
	var statistics: Dictionary = _calculate_statistics()
	var min_value: float = GFVariantData.get_option_float(statistics, "min_value")
	var max_value: float = GFVariantData.get_option_float(statistics, "max_value")
	var result: Dictionary = {
		"id": id,
		"label": label,
		"group": group,
		"visible": visible,
		"max_samples": max_samples,
		"sample_count": get_sample_count(),
		"latest_value": get_latest_value(),
		"min_value": min_value,
		"max_value": max_value,
		"average_value": GFVariantData.get_option_float(statistics, "average_value"),
		"sparkline": _make_sparkline_for_range(sparkline_width, min_value, max_value) if sparkline_width > 0 and not _samples.is_empty() else "",
		"metadata": metadata.duplicate(true),
	}
	if include_samples:
		result["samples"] = get_samples()
	return result


## 复制指标序列。
## [br]
## @api public
## [br]
## @param include_samples: 是否复制采样明细。
## [br]
## @return 复制后的指标序列。
func duplicate_series(include_samples: bool = true) -> GFMetricSeries:
	var copy: GFMetricSeries = GFMetricSeries.new()
	copy.id = id
	copy.label = label
	copy.group = group
	copy.visible = visible
	copy.max_samples = max_samples
	copy.metadata = metadata.duplicate(true)
	if include_samples:
		for sample: Dictionary in _samples:
			copy._samples.append(sample.duplicate(true))
	return copy


# --- 私有/辅助方法 ---

func _make_sparkline_for_range(width: int, min_value: float, max_value: float) -> String:
	var normalized: PackedFloat32Array = _get_normalized_values_for_range(min_value, max_value)
	var start_index: int = maxi(normalized.size() - width, 0)
	var output: PackedStringArray = PackedStringArray()
	for index: int in range(start_index, normalized.size()):
		var value: float = normalized[index]
		var char_index: int = clampi(roundi(value * float(SPARKLINE_CHARACTERS.length() - 1)), 0, SPARKLINE_CHARACTERS.length() - 1)
		var _appended: bool = output.append(SPARKLINE_CHARACTERS.substr(char_index, 1))
	return "".join(output)

func _trim_samples() -> void:
	while _samples.size() > max_samples:
		_samples.pop_front()


func _get_sample_value(sample: Dictionary) -> float:
	return GFVariantData.get_option_float(sample, "value", 0.0)


func _calculate_statistics() -> Dictionary:
	if _samples.is_empty():
		return {
			"min_value": 0.0,
			"max_value": 0.0,
			"average_value": 0.0,
		}
	var first_value: float = _get_sample_value(_samples[0])
	var min_value: float = first_value
	var max_value: float = first_value
	var total: float = 0.0
	for sample: Dictionary in _samples:
		var value: float = _get_sample_value(sample)
		min_value = minf(min_value, value)
		max_value = maxf(max_value, value)
		total += value
	return {
		"min_value": min_value,
		"max_value": max_value,
		"average_value": total / float(_samples.size()),
	}


func _get_normalized_values_for_range(min_value: float, max_value: float) -> PackedFloat32Array:
	var values: PackedFloat32Array = PackedFloat32Array()
	var span: float = max_value - min_value
	for sample: Dictionary in _samples:
		if is_zero_approx(span):
			var _appended: bool = values.append(0.5)
		else:
			var normalized_value: float = clampf((_get_sample_value(sample) - min_value) / span, 0.0, 1.0)
			var _appended: bool = values.append(normalized_value)
	return values


func _is_finite_float(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)
