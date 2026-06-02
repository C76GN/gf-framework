# GFShakeTrack

[API Reference](../index.md) / [Feedback](../extensions-feedback.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/feedback/resources/gf_shake_track.gd`
- 模块：`Feedback`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用反馈采样轨道。 描述一段可组合的反馈偏移轨道，供 GFShakePreset 混合采样。 轨道只输出通用 position、rotation_degrees 和 scale 偏移，不绑定目标节点或业务事件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Waveform`](#member-gfshaketrack-enums-waveform) | `enum Waveform` |
| 枚举 | [`BlendMode`](#member-gfshaketrack-enums-blendmode) | `enum BlendMode` |
| 属性 | [`enabled`](#member-gfshaketrack-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`blend_mode`](#member-gfshaketrack-properties-blend_mode) | `var blend_mode: BlendMode = BlendMode.ADD` |
| 属性 | [`waveform`](#member-gfshaketrack-properties-waveform) | `var waveform: Waveform = Waveform.NOISE` |
| 属性 | [`start_progress`](#member-gfshaketrack-properties-start_progress) | `var start_progress: float = 0.0` |
| 属性 | [`end_progress`](#member-gfshaketrack-properties-end_progress) | `var end_progress: float = 1.0` |
| 属性 | [`amplitude`](#member-gfshaketrack-properties-amplitude) | `var amplitude: float = 1.0` |
| 属性 | [`frequency`](#member-gfshaketrack-properties-frequency) | `var frequency: float = 24.0` |
| 属性 | [`position_axis`](#member-gfshaketrack-properties-position_axis) | `var position_axis: Vector3 = Vector3.ONE` |
| 属性 | [`rotation_axis_degrees`](#member-gfshaketrack-properties-rotation_axis_degrees) | `var rotation_axis_degrees: Vector3 = Vector3.ZERO` |
| 属性 | [`scale_axis`](#member-gfshaketrack-properties-scale_axis) | `var scale_axis: Vector3 = Vector3.ZERO` |
| 属性 | [`envelope_curve`](#member-gfshaketrack-properties-envelope_curve) | `var envelope_curve: Curve = null` |
| 属性 | [`wave_curve`](#member-gfshaketrack-properties-wave_curve) | `var wave_curve: Curve = null` |
| 属性 | [`sample_seed`](#member-gfshaketrack-properties-sample_seed) | `var sample_seed: int = 1` |
| 属性 | [`metadata`](#member-gfshaketrack-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`sample`](#member-gfshaketrack-methods-sample) | `func sample( preset_progress: float, elapsed_seconds: float, strength: float = 1.0, phase_offset: float = 0.0 ) -> Dictionary:` |
| 方法 | [`zero_sample`](#member-gfshaketrack-methods-zero_sample) | `static func zero_sample() -> Dictionary:` |
| 方法 | [`blend_sample`](#member-gfshaketrack-methods-blend_sample) | `static func blend_sample(base_sample: Dictionary, track_sample: Dictionary, mode: BlendMode) -> Dictionary:` |

## 枚举

<a id="member-gfshaketrack-enums-waveform"></a>

### `Waveform`

- API：`public`

```gdscript
enum Waveform { ## 正弦波，适合可预期的摆动。 SINE, ## 逐步随机值，适合短促冲击。 RANDOM, ## 平滑随机值，适合持续扰动。 NOISE, ## 使用 wave_curve 采样，曲线值 0.5 表示零偏移。 CURVE, }
```

反馈采样波形。

<a id="member-gfshaketrack-enums-blendmode"></a>

### `BlendMode`

- API：`public`

```gdscript
enum BlendMode { ## 叠加到已有采样上。 ADD, ## 覆盖已有采样。 OVERRIDE, ## 按分量相乘。 MULTIPLY, ## 从已有采样中减去当前轨道。 SUBTRACT, ## 与已有采样求平均。 AVERAGE, ## 逐分量取最大值。 MAX, ## 逐分量取最小值。 MIN, }
```

轨道混合模式。

## 属性

<a id="member-gfshaketrack-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true
```

是否启用该轨道。

<a id="member-gfshaketrack-properties-blend_mode"></a>

### `blend_mode`

- API：`public`

```gdscript
var blend_mode: BlendMode = BlendMode.ADD
```

轨道混合模式。

<a id="member-gfshaketrack-properties-waveform"></a>

### `waveform`

- API：`public`

```gdscript
var waveform: Waveform = Waveform.NOISE
```

轨道采样波形。

<a id="member-gfshaketrack-properties-start_progress"></a>

### `start_progress`

- API：`public`

```gdscript
var start_progress: float = 0.0
```

轨道开始进度，范围 0 到 1。

<a id="member-gfshaketrack-properties-end_progress"></a>

### `end_progress`

- API：`public`

```gdscript
var end_progress: float = 1.0
```

轨道结束进度，范围 0 到 1。

<a id="member-gfshaketrack-properties-amplitude"></a>

### `amplitude`

- API：`public`

```gdscript
var amplitude: float = 1.0
```

轨道振幅倍率。

<a id="member-gfshaketrack-properties-frequency"></a>

### `frequency`

- API：`public`

```gdscript
var frequency: float = 24.0
```

每秒采样频率。

<a id="member-gfshaketrack-properties-position_axis"></a>

### `position_axis`

- API：`public`

```gdscript
var position_axis: Vector3 = Vector3.ONE
```

位移轴权重。

<a id="member-gfshaketrack-properties-rotation_axis_degrees"></a>

### `rotation_axis_degrees`

- API：`public`

```gdscript
var rotation_axis_degrees: Vector3 = Vector3.ZERO
```

旋转轴权重，单位度。

<a id="member-gfshaketrack-properties-scale_axis"></a>

### `scale_axis`

- API：`public`

```gdscript
var scale_axis: Vector3 = Vector3.ZERO
```

缩放偏移轴权重。

<a id="member-gfshaketrack-properties-envelope_curve"></a>

### `envelope_curve`

- API：`public`

```gdscript
var envelope_curve: Curve = null
```

轨道包络曲线。为空时使用线性衰减。

<a id="member-gfshaketrack-properties-wave_curve"></a>

### `wave_curve`

- API：`public`

```gdscript
var wave_curve: Curve = null
```

自定义波形曲线。仅在 waveform 为 CURVE 时使用。

<a id="member-gfshaketrack-properties-sample_seed"></a>

### `sample_seed`

- API：`public`

```gdscript
var sample_seed: int = 1
```

确定性采样种子。

<a id="member-gfshaketrack-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，项目自定义轨道元数据；框架会在采样结果中复制透传。

## 方法

<a id="member-gfshaketrack-methods-sample"></a>

### `sample`

- API：`public`

```gdscript
func sample( preset_progress: float, elapsed_seconds: float, strength: float = 1.0, phase_offset: float = 0.0 ) -> Dictionary:
```

按预设归一化进度采样轨道。

参数：

| 名称 | 说明 |
|---|---|
| `preset_progress` | 预设归一化进度，范围 0 到 1。 |
| `elapsed_seconds` | 预设已播放秒数。 |
| `strength` | 播放强度倍率。 |
| `phase_offset` | 相位偏移。 |

返回：采样结果字典。

结构：

- `return`: Dictionary，包含 position: Vector3、rotation_degrees: Vector3、scale: Vector3、intensity: float、progress: float、track_progress: float 与 metadata: Dictionary。

<a id="member-gfshaketrack-methods-zero_sample"></a>

### `zero_sample`

- API：`public`

```gdscript
static func zero_sample() -> Dictionary:
```

创建空采样结果。

返回：空采样结果字典。

结构：

- `return`: Dictionary，包含零值 position、rotation_degrees、scale、intensity、progress、track_progress 与空 metadata。

<a id="member-gfshaketrack-methods-blend_sample"></a>

### `blend_sample`

- API：`public`

```gdscript
static func blend_sample(base_sample: Dictionary, track_sample: Dictionary, mode: BlendMode) -> Dictionary:
```

将轨道采样混合到当前采样。

参数：

| 名称 | 说明 |
|---|---|
| `base_sample` | 当前合成采样。 |
| `track_sample` | 轨道采样。 |
| `mode` | 混合模式。 |

返回：合成后的采样。

结构：

- `base_sample`: Dictionary，包含 position、rotation_degrees、scale、intensity 与 progress 字段的当前合成采样。
- `track_sample`: Dictionary，包含 position、rotation_degrees、scale、intensity 与 progress 字段的轨道采样。
- `return`: Dictionary，合并后的反馈采样，包含 position、rotation_degrees、scale、intensity 与 progress。
