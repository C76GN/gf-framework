# GFMetricSeries

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_metric_series.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.23.0`

调试用短期数值序列。 保存固定长度的数值采样，并提供统计值、归一化值和 ASCII sparkline。 适合开发期 Overlay 观察短期趋势，不承担长期日志、遥测或业务分析职责。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`SPARKLINE_CHARACTERS`](#member-gfmetricseries-constants-sparkline_characters) | `const SPARKLINE_CHARACTERS: String = ".:-=+*#"` |
| 属性 | [`id`](#member-gfmetricseries-properties-id) | `var id: StringName = &""` |
| 属性 | [`label`](#member-gfmetricseries-properties-label) | `var label: String = ""` |
| 属性 | [`group`](#member-gfmetricseries-properties-group) | `var group: String = "Runtime"` |
| 属性 | [`visible`](#member-gfmetricseries-properties-visible) | `var visible: bool = true` |
| 属性 | [`max_samples`](#member-gfmetricseries-properties-max_samples) | `var max_samples: int = 120:` |
| 属性 | [`metadata`](#member-gfmetricseries-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfmetricseries-methods-configure) | `func configure(metric_id: StringName, options: Dictionary = {}) -> GFMetricSeries:` |
| 方法 | [`add_sample`](#member-gfmetricseries-methods-add_sample) | `func add_sample(value: float, timestamp_seconds: float = -1.0, sample_metadata: Dictionary = {}) -> void:` |
| 方法 | [`clear`](#member-gfmetricseries-methods-clear) | `func clear() -> void:` |
| 方法 | [`get_sample_count`](#member-gfmetricseries-methods-get_sample_count) | `func get_sample_count() -> int:` |
| 方法 | [`get_samples`](#member-gfmetricseries-methods-get_samples) | `func get_samples() -> Array[Dictionary]:` |
| 方法 | [`get_latest_value`](#member-gfmetricseries-methods-get_latest_value) | `func get_latest_value() -> float:` |
| 方法 | [`get_min_value`](#member-gfmetricseries-methods-get_min_value) | `func get_min_value() -> float:` |
| 方法 | [`get_max_value`](#member-gfmetricseries-methods-get_max_value) | `func get_max_value() -> float:` |
| 方法 | [`get_average_value`](#member-gfmetricseries-methods-get_average_value) | `func get_average_value() -> float:` |
| 方法 | [`get_normalized_values`](#member-gfmetricseries-methods-get_normalized_values) | `func get_normalized_values() -> PackedFloat32Array:` |
| 方法 | [`make_sparkline`](#member-gfmetricseries-methods-make_sparkline) | `func make_sparkline(width: int = 32) -> String:` |
| 方法 | [`to_dict`](#member-gfmetricseries-methods-to_dict) | `func to_dict(include_samples: bool = false, sparkline_width: int = 32) -> Dictionary:` |
| 方法 | [`duplicate_series`](#member-gfmetricseries-methods-duplicate_series) | `func duplicate_series(include_samples: bool = true) -> GFMetricSeries:` |

## 常量

<a id="member-gfmetricseries-constants-sparkline_characters"></a>

### `SPARKLINE_CHARACTERS`

- API：`public`

```gdscript
const SPARKLINE_CHARACTERS: String = ".:-=+*#"
```

sparkline 使用的 ASCII 字符，按强度从低到高排列。

## 属性

<a id="member-gfmetricseries-properties-id"></a>

### `id`

- API：`public`

```gdscript
var id: StringName = &""
```

指标唯一标识。

<a id="member-gfmetricseries-properties-label"></a>

### `label`

- API：`public`

```gdscript
var label: String = ""
```

显示名称。

<a id="member-gfmetricseries-properties-group"></a>

### `group`

- API：`public`

```gdscript
var group: String = "Runtime"
```

显示分组。

<a id="member-gfmetricseries-properties-visible"></a>

### `visible`

- API：`public`

```gdscript
var visible: bool = true
```

是否在 Overlay 快照中显示。

<a id="member-gfmetricseries-properties-max_samples"></a>

### `max_samples`

- API：`public`

```gdscript
var max_samples: int = 120:
```

最大采样数量。

<a id="member-gfmetricseries-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary[String, Variant]，项目自定义元数据；框架不会读取或改写其中字段。

## 方法

<a id="member-gfmetricseries-methods-configure"></a>

### `configure`

- API：`public`

```gdscript
func configure(metric_id: StringName, options: Dictionary = {}) -> GFMetricSeries:
```

配置指标序列。

参数：

| 名称 | 说明 |
|---|---|
| `metric_id` | 指标唯一标识。 |
| `options` | 可选配置，支持 label、group、visible、max_samples 和 metadata。 |

返回：当前序列，便于链式配置。

结构：

- `options`: Dictionary，支持 label、group、visible、max_samples 和 metadata。

<a id="member-gfmetricseries-methods-add_sample"></a>

### `add_sample`

- API：`public`

```gdscript
func add_sample(value: float, timestamp_seconds: float = -1.0, sample_metadata: Dictionary = {}) -> void:
```

追加一个数值采样。

参数：

| 名称 | 说明 |
|---|---|
| `value` | 采样值。 |
| `timestamp_seconds` | 采样时间；小于 0 时使用当前运行时间。 |
| `sample_metadata` | 单个采样的自定义元数据。 |

结构：

- `sample_metadata`: Dictionary[String, Variant]，单个采样的项目自定义元数据。

<a id="member-gfmetricseries-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空所有采样。

<a id="member-gfmetricseries-methods-get_sample_count"></a>

### `get_sample_count`

- API：`public`

```gdscript
func get_sample_count() -> int:
```

获取采样数量。

返回：当前采样数量。

<a id="member-gfmetricseries-methods-get_samples"></a>

### `get_samples`

- API：`public`

```gdscript
func get_samples() -> Array[Dictionary]:
```

获取采样副本。

返回：采样数组副本。

结构：

- `return`: Array[Dictionary]，每个元素包含 value、timestamp_seconds 和 metadata。

<a id="member-gfmetricseries-methods-get_latest_value"></a>

### `get_latest_value`

- API：`public`

```gdscript
func get_latest_value() -> float:
```

获取最新采样值。

返回：最新采样值；没有采样时返回 0。

<a id="member-gfmetricseries-methods-get_min_value"></a>

### `get_min_value`

- API：`public`

```gdscript
func get_min_value() -> float:
```

获取最小采样值。

返回：最小采样值；没有采样时返回 0。

<a id="member-gfmetricseries-methods-get_max_value"></a>

### `get_max_value`

- API：`public`

```gdscript
func get_max_value() -> float:
```

获取最大采样值。

返回：最大采样值；没有采样时返回 0。

<a id="member-gfmetricseries-methods-get_average_value"></a>

### `get_average_value`

- API：`public`

```gdscript
func get_average_value() -> float:
```

获取平均采样值。

返回：平均采样值；没有采样时返回 0。

<a id="member-gfmetricseries-methods-get_normalized_values"></a>

### `get_normalized_values`

- API：`public`

```gdscript
func get_normalized_values() -> PackedFloat32Array:
```

获取归一化后的采样值。

返回：归一化值数组。

<a id="member-gfmetricseries-methods-make_sparkline"></a>

### `make_sparkline`

- API：`public`

```gdscript
func make_sparkline(width: int = 32) -> String:
```

生成定宽 ASCII sparkline。

参数：

| 名称 | 说明 |
|---|---|
| `width` | 输出宽度；小于等于 0 时返回空字符串。 |

返回：sparkline 文本。

<a id="member-gfmetricseries-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`3.23.0`

```gdscript
func to_dict(include_samples: bool = false, sparkline_width: int = 32) -> Dictionary:
```

转换为 Dictionary。

参数：

| 名称 | 说明 |
|---|---|
| `include_samples` | 是否包含采样明细。 |
| `sparkline_width` | sparkline 输出宽度。 |

返回：指标序列快照。

结构：

- `return`: Dictionary，包含 id、label、group、visible、max_samples、sample_count、latest_value、min_value、max_value、average_value、sparkline、metadata，可选 samples。

<a id="member-gfmetricseries-methods-duplicate_series"></a>

### `duplicate_series`

- API：`public`

```gdscript
func duplicate_series(include_samples: bool = true) -> GFMetricSeries:
```

复制指标序列。

参数：

| 名称 | 说明 |
|---|---|
| `include_samples` | 是否复制采样明细。 |

返回：复制后的指标序列。
