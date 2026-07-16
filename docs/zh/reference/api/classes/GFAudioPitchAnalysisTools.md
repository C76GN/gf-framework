# GFAudioPitchAnalysisTools

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_pitch_analysis_tools.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`6.0.0`

纯样本音高分析工具。 对调用方提供的 mono 或 stereo 样本做能量与基频估计，返回频率、音名、 cents 偏差和置信度报告。它不读取麦克风、不创建节点，也不接管音频采集流程。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`ALGORITHM_AUTOCORRELATION`](#member-gfaudiopitchanalysistools-constants-algorithm_autocorrelation) | `const ALGORITHM_AUTOCORRELATION: StringName = &"autocorrelation"` |
| 常量 | [`DEFAULT_MIN_FREQUENCY_HZ`](#member-gfaudiopitchanalysistools-constants-default_min_frequency_hz) | `const DEFAULT_MIN_FREQUENCY_HZ: float = 50.0` |
| 常量 | [`DEFAULT_MAX_FREQUENCY_HZ`](#member-gfaudiopitchanalysistools-constants-default_max_frequency_hz) | `const DEFAULT_MAX_FREQUENCY_HZ: float = 2000.0` |
| 常量 | [`DEFAULT_MIN_RMS`](#member-gfaudiopitchanalysistools-constants-default_min_rms) | `const DEFAULT_MIN_RMS: float = 0.005` |
| 常量 | [`DEFAULT_CONFIDENCE_THRESHOLD`](#member-gfaudiopitchanalysistools-constants-default_confidence_threshold) | `const DEFAULT_CONFIDENCE_THRESHOLD: float = 0.45` |
| 常量 | [`MAX_SAMPLE_COUNT`](#member-gfaudiopitchanalysistools-constants-max_sample_count) | `const MAX_SAMPLE_COUNT: int = 16384` |
| 常量 | [`MAX_LAG_COUNT`](#member-gfaudiopitchanalysistools-constants-max_lag_count) | `const MAX_LAG_COUNT: int = 4096` |
| 常量 | [`MAX_CORRELATION_OPERATIONS`](#member-gfaudiopitchanalysistools-constants-max_correlation_operations) | `const MAX_CORRELATION_OPERATIONS: int = 8_000_000` |
| 方法 | [`analyze_mono_samples`](#member-gfaudiopitchanalysistools-methods-analyze_mono_samples) | `static func analyze_mono_samples( samples: PackedFloat32Array, sample_rate: float, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`analyze_stereo_frames`](#member-gfaudiopitchanalysistools-methods-analyze_stereo_frames) | `static func analyze_stereo_frames( frames: PackedVector2Array, sample_rate: float, options: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`calculate_rms`](#member-gfaudiopitchanalysistools-methods-calculate_rms) | `static func calculate_rms(samples: PackedFloat32Array) -> float:` |
| 方法 | [`frequency_to_note`](#member-gfaudiopitchanalysistools-methods-frequency_to_note) | `static func frequency_to_note(frequency_hz: float) -> Dictionary:` |

## 常量

<a id="member-gfaudiopitchanalysistools-constants-algorithm_autocorrelation"></a>

### `ALGORITHM_AUTOCORRELATION`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const ALGORITHM_AUTOCORRELATION: StringName = &"autocorrelation"
```

自动相关基频估计算法。

<a id="member-gfaudiopitchanalysistools-constants-default_min_frequency_hz"></a>

### `DEFAULT_MIN_FREQUENCY_HZ`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const DEFAULT_MIN_FREQUENCY_HZ: float = 50.0
```

默认最低检测频率。

<a id="member-gfaudiopitchanalysistools-constants-default_max_frequency_hz"></a>

### `DEFAULT_MAX_FREQUENCY_HZ`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const DEFAULT_MAX_FREQUENCY_HZ: float = 2000.0
```

默认最高检测频率。

<a id="member-gfaudiopitchanalysistools-constants-default_min_rms"></a>

### `DEFAULT_MIN_RMS`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const DEFAULT_MIN_RMS: float = 0.005
```

默认最小 RMS。

<a id="member-gfaudiopitchanalysistools-constants-default_confidence_threshold"></a>

### `DEFAULT_CONFIDENCE_THRESHOLD`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
const DEFAULT_CONFIDENCE_THRESHOLD: float = 0.45
```

默认置信度阈值。

<a id="member-gfaudiopitchanalysistools-constants-max_sample_count"></a>

### `MAX_SAMPLE_COUNT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const MAX_SAMPLE_COUNT: int = 16384
```

单次分析允许的最大样本窗口硬上限。

<a id="member-gfaudiopitchanalysistools-constants-max_lag_count"></a>

### `MAX_LAG_COUNT`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const MAX_LAG_COUNT: int = 4096
```

单次分析允许扫描的 lag 数量硬上限。

<a id="member-gfaudiopitchanalysistools-constants-max_correlation_operations"></a>

### `MAX_CORRELATION_OPERATIONS`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
const MAX_CORRELATION_OPERATIONS: int = 8_000_000
```

单次分析允许的保守自相关乘加工作量硬上限。

## 方法

<a id="member-gfaudiopitchanalysistools-methods-analyze_mono_samples"></a>

### `analyze_mono_samples`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func analyze_mono_samples( samples: PackedFloat32Array, sample_rate: float, options: Dictionary = {} ) -> Dictionary:
```

分析 mono 样本。

参数：

| 名称 | 说明 |
|---|---|
| `samples` | mono PCM 样本。 |
| `sample_rate` | 样本率。 |
| `options` | 分析选项。 |

返回：分析报告。

结构：

- `samples`: PackedFloat32Array mono samples in -1..1 range.
- `options`: Dictionary，可包含 min_frequency_hz、max_frequency_hz、min_rms、confidence_threshold、start_index、sample_count、max_sample_count、max_lag_count 和 max_correlation_operations。
- `return`: Dictionary with ok, detected, frequency_hz, confidence, rms, lag, note_number, note_name, cents, issues, and issue_count.

<a id="member-gfaudiopitchanalysistools-methods-analyze_stereo_frames"></a>

### `analyze_stereo_frames`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func analyze_stereo_frames( frames: PackedVector2Array, sample_rate: float, options: Dictionary = {} ) -> Dictionary:
```

分析 stereo 帧。

参数：

| 名称 | 说明 |
|---|---|
| `frames` | stereo PCM 帧。 |
| `sample_rate` | 样本率。 |
| `options` | 分析选项。 |

返回：分析报告。

结构：

- `frames`: PackedVector2Array where x/y are left/right samples.
- `options`: Dictionary forwarded to analyze_mono_samples(), including sample and work budgets.
- `return`: Dictionary with ok, detected, frequency_hz, confidence, rms, lag, note_number, note_name, cents, issues, issue_count, and stereo_mix_mode.

<a id="member-gfaudiopitchanalysistools-methods-calculate_rms"></a>

### `calculate_rms`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func calculate_rms(samples: PackedFloat32Array) -> float:
```

计算样本 RMS。

参数：

| 名称 | 说明 |
|---|---|
| `samples` | mono PCM 样本。 |

返回：RMS 值。

结构：

- `samples`: PackedFloat32Array mono samples.

<a id="member-gfaudiopitchanalysistools-methods-frequency_to_note"></a>

### `frequency_to_note`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
static func frequency_to_note(frequency_hz: float) -> Dictionary:
```

将频率转换为十二平均律音名。

参数：

| 名称 | 说明 |
|---|---|
| `frequency_hz` | 频率。 |

返回：音名报告。

结构：

- `return`: Dictionary with ok, frequency_hz, note_number, note_name, midi_float, and cents.
