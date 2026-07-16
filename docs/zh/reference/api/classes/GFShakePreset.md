# GFShakePreset

[API Reference](../index.md) / [Feedback](../extensions-feedback.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/feedback/resources/gf_shake_preset.gd`
- 模块：`Feedback`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用反馈采样预设。 描述一段可采样的位移、旋转和缩放偏移，不绑定相机、角色、UI 或业务事件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 枚举 | [`Waveform`](#member-gfshakepreset-enums-waveform) | `enum Waveform` |
| 属性 | [`duration_seconds`](#member-gfshakepreset-properties-duration_seconds) | `var duration_seconds: float = 0.25` |
| 属性 | [`amplitude`](#member-gfshakepreset-properties-amplitude) | `var amplitude: float = 1.0` |
| 属性 | [`frequency`](#member-gfshakepreset-properties-frequency) | `var frequency: float = 24.0` |
| 属性 | [`waveform`](#member-gfshakepreset-properties-waveform) | `var waveform: Waveform = Waveform.NOISE` |
| 属性 | [`position_axis`](#member-gfshakepreset-properties-position_axis) | `var position_axis: Vector3 = Vector3.ONE` |
| 属性 | [`rotation_axis_degrees`](#member-gfshakepreset-properties-rotation_axis_degrees) | `var rotation_axis_degrees: Vector3 = Vector3.ZERO` |
| 属性 | [`scale_axis`](#member-gfshakepreset-properties-scale_axis) | `var scale_axis: Vector3 = Vector3.ZERO` |
| 属性 | [`decay_curve`](#member-gfshakepreset-properties-decay_curve) | `var decay_curve: Curve = null` |
| 属性 | [`wave_curve`](#member-gfshakepreset-properties-wave_curve) | `var wave_curve: Curve = null` |
| 属性 | [`sample_seed`](#member-gfshakepreset-properties-sample_seed) | `var sample_seed: int = 1` |
| 属性 | [`tracks`](#member-gfshakepreset-properties-tracks) | `var tracks: Array[GFShakeTrack] = []` |
| 方法 | [`get_duration_seconds`](#member-gfshakepreset-methods-get_duration_seconds) | `func get_duration_seconds() -> float:` |
| 方法 | [`sample`](#member-gfshakepreset-methods-sample) | `func sample(elapsed_seconds: float, strength: float = 1.0, phase_offset: float = 0.0) -> Dictionary:` |
| 方法 | [`sample_at_progress`](#member-gfshakepreset-methods-sample_at_progress) | `func sample_at_progress( progress: float, elapsed_seconds: float, strength: float = 1.0, phase_offset: float = 0.0 ) -> Dictionary:` |
| 方法 | [`add_track`](#member-gfshakepreset-methods-add_track) | `func add_track(track: GFShakeTrack) -> bool:` |
| 方法 | [`clear_tracks`](#member-gfshakepreset-methods-clear_tracks) | `func clear_tracks() -> void:` |
| 方法 | [`has_tracks`](#member-gfshakepreset-methods-has_tracks) | `func has_tracks() -> bool:` |
| 方法 | [`zero_sample`](#member-gfshakepreset-methods-zero_sample) | `static func zero_sample() -> Dictionary:` |
| 方法 | [`combine_samples`](#member-gfshakepreset-methods-combine_samples) | `static func combine_samples(samples: Array[Dictionary]) -> Dictionary:` |

## 枚举

<a id="member-gfshakepreset-enums-waveform"></a>

### `Waveform`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
enum Waveform {
	## 正弦波，适合可预期的摆动。
	SINE,
	## 逐步随机值，适合冲击感。
	RANDOM,
	## 平滑随机值，适合持续扰动。
	NOISE,
	## 使用 wave_curve 采样，曲线值 0.5 表示零偏移。
	CURVE,
}
```

反馈采样波形。

## 属性

<a id="member-gfshakepreset-properties-duration_seconds"></a>

### `duration_seconds`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var duration_seconds: float = 0.25
```

持续时间，单位秒。

<a id="member-gfshakepreset-properties-amplitude"></a>

### `amplitude`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var amplitude: float = 1.0
```

采样振幅倍率。

<a id="member-gfshakepreset-properties-frequency"></a>

### `frequency`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var frequency: float = 24.0
```

每秒采样频率。

<a id="member-gfshakepreset-properties-waveform"></a>

### `waveform`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var waveform: Waveform = Waveform.NOISE
```

波形类型。

<a id="member-gfshakepreset-properties-position_axis"></a>

### `position_axis`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var position_axis: Vector3 = Vector3.ONE
```

位移轴权重。

<a id="member-gfshakepreset-properties-rotation_axis_degrees"></a>

### `rotation_axis_degrees`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var rotation_axis_degrees: Vector3 = Vector3.ZERO
```

旋转轴权重，单位度。

<a id="member-gfshakepreset-properties-scale_axis"></a>

### `scale_axis`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var scale_axis: Vector3 = Vector3.ZERO
```

缩放偏移轴权重。返回值是叠加到基础 scale 上的偏移。

<a id="member-gfshakepreset-properties-decay_curve"></a>

### `decay_curve`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var decay_curve: Curve = null
```

包络曲线。为空时使用线性衰减；曲线值越高，当前采样越强。

<a id="member-gfshakepreset-properties-wave_curve"></a>

### `wave_curve`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var wave_curve: Curve = null
```

自定义波形曲线。仅在 waveform 为 CURVE 时使用，曲线值 0.5 表示零偏移。

<a id="member-gfshakepreset-properties-sample_seed"></a>

### `sample_seed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var sample_seed: int = 1
```

确定性采样种子。

<a id="member-gfshakepreset-properties-tracks"></a>

### `tracks`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var tracks: Array[GFShakeTrack] = []
```

可组合反馈轨道。为空时使用兼容的单波形字段。

结构：

- `tracks`: Array[GFShakeTrack]，按顺序采样并根据每个轨道 blend_mode 合成。

## 方法

<a id="member-gfshakepreset-methods-get_duration_seconds"></a>

### `get_duration_seconds`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_duration_seconds() -> float:
```

获取有效持续时间。

返回：持续时间，最小为 0。

<a id="member-gfshakepreset-methods-sample"></a>

### `sample`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func sample(elapsed_seconds: float, strength: float = 1.0, phase_offset: float = 0.0) -> Dictionary:
```

按时间采样反馈偏移。

参数：

| 名称 | 说明 |
|---|---|
| `elapsed_seconds` | 已经过的秒数。 |
| `strength` | 本次播放强度倍率。 |
| `phase_offset` | 相位偏移，用于同一预设多次播放时错开采样。 |

返回：采样结果字典。

结构：

- `return`: Dictionary，包含 position: Vector3、rotation_degrees: Vector3、scale: Vector3、intensity: float 与 progress: float。

<a id="member-gfshakepreset-methods-sample_at_progress"></a>

### `sample_at_progress`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func sample_at_progress( progress: float, elapsed_seconds: float, strength: float = 1.0, phase_offset: float = 0.0 ) -> Dictionary:
```

按归一化进度采样反馈偏移。

参数：

| 名称 | 说明 |
|---|---|
| `progress` | 归一化进度，范围 0 到 1。 |
| `elapsed_seconds` | 已经过的秒数。 |
| `strength` | 本次播放强度倍率。 |
| `phase_offset` | 相位偏移。 |

返回：采样结果字典。

结构：

- `return`: Dictionary，包含 position: Vector3、rotation_degrees: Vector3、scale: Vector3、intensity: float 与 progress: float。

<a id="member-gfshakepreset-methods-add_track"></a>

### `add_track`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func add_track(track: GFShakeTrack) -> bool:
```

添加反馈轨道。

参数：

| 名称 | 说明 |
|---|---|
| `track` | 反馈轨道。 |

返回：添加成功返回 true。

<a id="member-gfshakepreset-methods-clear_tracks"></a>

### `clear_tracks`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear_tracks() -> void:
```

清空反馈轨道。

<a id="member-gfshakepreset-methods-has_tracks"></a>

### `has_tracks`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func has_tracks() -> bool:
```

检查是否存在有效轨道。

返回：存在有效轨道返回 true。

<a id="member-gfshakepreset-methods-zero_sample"></a>

### `zero_sample`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func zero_sample() -> Dictionary:
```

创建空采样结果。

返回：空采样结果字典。

结构：

- `return`: Dictionary，包含零值 position、rotation_degrees、scale、intensity 与 progress。

<a id="member-gfshakepreset-methods-combine_samples"></a>

### `combine_samples`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func combine_samples(samples: Array[Dictionary]) -> Dictionary:
```

合并多个反馈采样。

参数：

| 名称 | 说明 |
|---|---|
| `samples` | 采样结果数组。 |

返回：合并后的采样结果。

结构：

- `samples`: Array[Dictionary]，每项包含 position、rotation_degrees、scale、intensity 与 progress。
- `return`: Dictionary，合并后的反馈采样，包含 position、rotation_degrees、scale、intensity 与 progress。
