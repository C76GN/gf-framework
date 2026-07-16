# GFNoiseFieldTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/math/gf_noise_field_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`8.0.0`

通用二维噪声场采样工具。 使用 Godot 原生 FastNoiseLite 或调用方传入的采样回调生成行优先浮点样本， 并输出范围、平均值和可选归一化样本。它只处理纯数据，不创建地形、 材质、节点、贴图或程序化内容对象。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`DEFAULT_MAX_GRID_SAMPLES`](#member-gfnoisefieldtools-constants-default_max_grid_samples) | `const DEFAULT_MAX_GRID_SAMPLES: int = 1048576` |
| 常量 | [`DEFAULT_NOISE_FREQUENCY`](#member-gfnoisefieldtools-constants-default_noise_frequency) | `const DEFAULT_NOISE_FREQUENCY: float = 0.01` |
| 方法 | [`sample_grid_2d`](#member-gfnoisefieldtools-methods-sample_grid_2d) | `static func sample_grid_2d(grid_size: Vector2i, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`normalize_samples`](#member-gfnoisefieldtools-methods-normalize_samples) | `static func normalize_samples(samples: PackedFloat32Array, options: Dictionary = {}) -> Dictionary:` |
| 方法 | [`to_json_compatible_report`](#member-gfnoisefieldtools-methods-to_json_compatible_report) | `static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:` |

## 常量

<a id="member-gfnoisefieldtools-constants-default_max_grid_samples"></a>

### `DEFAULT_MAX_GRID_SAMPLES`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_MAX_GRID_SAMPLES: int = 1048576
```

默认最大采样数量，避免把超大实时噪声场交给纯 GDScript。

<a id="member-gfnoisefieldtools-constants-default_noise_frequency"></a>

### `DEFAULT_NOISE_FREQUENCY`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const DEFAULT_NOISE_FREQUENCY: float = 0.01
```

未提供 noise 时创建 FastNoiseLite 使用的默认频率。

## 方法

<a id="member-gfnoisefieldtools-methods-sample_grid_2d"></a>

### `sample_grid_2d`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func sample_grid_2d(grid_size: Vector2i, options: Dictionary = {}) -> Dictionary:
```

采样二维行优先噪声场。 采样源优先使用 options.sampler；未提供 sampler 时使用 options.noise， 再未提供时按 seed 与 frequency 创建 FastNoiseLite。

参数：

| 名称 | 说明 |
|---|---|
| `grid_size` | 采样网格尺寸，x 为列数，y 为行数。 |
| `options` | 采样选项。 |

返回：采样报告。

结构：

- `options`: Dictionary，可包含 sampler、metadata、noise、seed、frequency、noise_type、fractal_octaves、origin、step、include_normalized、constant_value 与 max_samples。sampler 为 Callable，签名为 Callable(position: Vector2, cell: Vector2i, metadata: Dictionary) -> int|float；noise 为 FastNoiseLite。
- `return`: Dictionary，包含 ok、error、source、grid_size、origin、step、sample_count、samples、min_value、max_value、average、normalized_samples 与 constant_range 字段。

<a id="member-gfnoisefieldtools-methods-normalize_samples"></a>

### `normalize_samples`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func normalize_samples(samples: PackedFloat32Array, options: Dictionary = {}) -> Dictionary:
```

归一化浮点样本。 默认使用输入样本的最小值和最大值，把每个值映射到 0.0 到 1.0。 如果范围为常量，输出 constant_value，默认为 0.0。

参数：

| 名称 | 说明 |
|---|---|
| `samples` | 待归一化的浮点样本。 |
| `options` | 归一化选项。 |

返回：归一化报告。

结构：

- `options`: Dictionary，可包含 minimum、maximum、constant_value 与 clamp。
- `return`: Dictionary，包含 ok、error、sample_count、min_value、max_value、constant_value、constant_range 与 normalized_samples 字段。

<a id="member-gfnoisefieldtools-methods-to_json_compatible_report"></a>

### `to_json_compatible_report`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
static func to_json_compatible_report(report: Dictionary, options: Dictionary = {}) -> Dictionary:
```

将噪声工具报告转换为 JSON.stringify() 安全的结构。

参数：

| 名称 | 说明 |
|---|---|
| `report` | sample_grid_2d() 或 normalize_samples() 返回的报告。 |
| `options` | 报告编码选项，透传给 GFReportValueCodec。 |

返回：JSON 兼容报告。

结构：

- `report`: Dictionary report returned by GFNoiseFieldTools.
- `options`: Dictionary with GFReportValueCodec options.
- `return`: Dictionary safe for JSON.stringify().
