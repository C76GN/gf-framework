# GFHapticPreset

[API Reference](../index.md) / [Feedback](../extensions-feedback.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/feedback/resources/gf_haptic_preset.gd`
- 模块：`Feedback`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`7.0.0`

通用手柄震动采样预设。 描述一段弱/强马达强度曲线，不绑定命中、相机、角色、UI 或具体玩法事件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`duration_seconds`](#member-gfhapticpreset-properties-duration_seconds) | `var duration_seconds: float = 0.25` |
| 属性 | [`weak_magnitude`](#member-gfhapticpreset-properties-weak_magnitude) | `var weak_magnitude: float = 0.5` |
| 属性 | [`strong_magnitude`](#member-gfhapticpreset-properties-strong_magnitude) | `var strong_magnitude: float = 0.5` |
| 属性 | [`intensity`](#member-gfhapticpreset-properties-intensity) | `var intensity: float = 1.0` |
| 属性 | [`weak_curve`](#member-gfhapticpreset-properties-weak_curve) | `var weak_curve: Curve = null` |
| 属性 | [`strong_curve`](#member-gfhapticpreset-properties-strong_curve) | `var strong_curve: Curve = null` |
| 方法 | [`get_duration_seconds`](#member-gfhapticpreset-methods-get_duration_seconds) | `func get_duration_seconds() -> float:` |
| 方法 | [`sample`](#member-gfhapticpreset-methods-sample) | `func sample(elapsed_seconds: float, strength: float = 1.0) -> Dictionary:` |
| 方法 | [`sample_at_progress`](#member-gfhapticpreset-methods-sample_at_progress) | `func sample_at_progress(progress: float, strength: float = 1.0) -> Dictionary:` |
| 方法 | [`zero_sample`](#member-gfhapticpreset-methods-zero_sample) | `static func zero_sample() -> Dictionary:` |
| 方法 | [`combine_samples`](#member-gfhapticpreset-methods-combine_samples) | `static func combine_samples(samples: Array[Dictionary]) -> Dictionary:` |

## 属性

<a id="member-gfhapticpreset-properties-duration_seconds"></a>

### `duration_seconds`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var duration_seconds: float = 0.25
```

持续时间，单位秒。非有限值按 0 处理，因此不能表示无限播放。

<a id="member-gfhapticpreset-properties-weak_magnitude"></a>

### `weak_magnitude`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var weak_magnitude: float = 0.5
```

低频马达基础强度，范围 0 到 1。

<a id="member-gfhapticpreset-properties-strong_magnitude"></a>

### `strong_magnitude`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var strong_magnitude: float = 0.5
```

高频马达基础强度，范围 0 到 1。

<a id="member-gfhapticpreset-properties-intensity"></a>

### `intensity`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var intensity: float = 1.0
```

预设整体强度倍率。

<a id="member-gfhapticpreset-properties-weak_curve"></a>

### `weak_curve`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var weak_curve: Curve = null
```

低频马达强度曲线。为空时使用恒定 1.0。

<a id="member-gfhapticpreset-properties-strong_curve"></a>

### `strong_curve`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
var strong_curve: Curve = null
```

高频马达强度曲线。为空时使用恒定 1.0。

## 方法

<a id="member-gfhapticpreset-methods-get_duration_seconds"></a>

### `get_duration_seconds`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func get_duration_seconds() -> float:
```

获取有效持续时间。

返回：有限持续时间，最小为 0。

<a id="member-gfhapticpreset-methods-sample"></a>

### `sample`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func sample(elapsed_seconds: float, strength: float = 1.0) -> Dictionary:
```

按时间采样震动强度。

参数：

| 名称 | 说明 |
|---|---|
| `elapsed_seconds` | 已经过的秒数。 |
| `strength` | 本次播放强度倍率。 |

返回：震动采样结果。

结构：

- `return`: Dictionary，包含 weak_magnitude、strong_magnitude、intensity 与 progress。

<a id="member-gfhapticpreset-methods-sample_at_progress"></a>

### `sample_at_progress`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
func sample_at_progress(progress: float, strength: float = 1.0) -> Dictionary:
```

按归一化进度采样震动强度。

参数：

| 名称 | 说明 |
|---|---|
| `progress` | 归一化进度，范围 0 到 1。 |
| `strength` | 本次播放强度倍率。 |

返回：震动采样结果。

结构：

- `return`: Dictionary，包含 weak_magnitude、strong_magnitude、intensity 与 progress。

<a id="member-gfhapticpreset-methods-zero_sample"></a>

### `zero_sample`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func zero_sample() -> Dictionary:
```

创建空震动采样结果。

返回：空震动采样结果。

结构：

- `return`: Dictionary，包含零值 weak_magnitude、strong_magnitude、intensity 与 progress。

<a id="member-gfhapticpreset-methods-combine_samples"></a>

### `combine_samples`

- API：`public`
- 首次版本：`7.0.0`

```gdscript
static func combine_samples(samples: Array[Dictionary]) -> Dictionary:
```

合并多个震动采样。

参数：

| 名称 | 说明 |
|---|---|
| `samples` | 震动采样数组。 |

返回：合并后的震动采样。

结构：

- `samples`: Array[Dictionary]，每项包含 weak_magnitude、strong_magnitude、intensity 与 progress。
- `return`: Dictionary，包含合并后的 weak_magnitude、strong_magnitude、intensity 与 progress。
