# GFAudioSpatialSettings

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_spatial_settings.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.19.0`

空间音效播放器参数。 只描述 Godot 2D/3D 空间播放器的通用衰减、距离、区域、复音和播放类型参数。 该资源可挂到 `GFAudioClip.spatial_settings`，仅在空间 SFX 播放路径中应用。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`max_polyphony`](#member-gfaudiospatialsettings-properties-max_polyphony) | `var max_polyphony: int = 1` |
| 属性 | [`panning_strength`](#member-gfaudiospatialsettings-properties-panning_strength) | `var panning_strength: float = 1.0` |
| 属性 | [`playback_type`](#member-gfaudiospatialsettings-properties-playback_type) | `var playback_type: int = 0` |
| 属性 | [`area_mask_2d`](#member-gfaudiospatialsettings-properties-area_mask_2d) | `var area_mask_2d: int = 1` |
| 属性 | [`max_distance_2d`](#member-gfaudiospatialsettings-properties-max_distance_2d) | `var max_distance_2d: float = 2000.0` |
| 属性 | [`attenuation_2d`](#member-gfaudiospatialsettings-properties-attenuation_2d) | `var attenuation_2d: float = 1.0` |
| 属性 | [`attenuation_model_3d`](#member-gfaudiospatialsettings-properties-attenuation_model_3d) | `var attenuation_model_3d: int = 0` |
| 属性 | [`area_mask_3d`](#member-gfaudiospatialsettings-properties-area_mask_3d) | `var area_mask_3d: int = 1` |
| 属性 | [`unit_size_3d`](#member-gfaudiospatialsettings-properties-unit_size_3d) | `var unit_size_3d: float = 10.0` |
| 属性 | [`max_db_3d`](#member-gfaudiospatialsettings-properties-max_db_3d) | `var max_db_3d: float = 3.0` |
| 属性 | [`max_distance_3d`](#member-gfaudiospatialsettings-properties-max_distance_3d) | `var max_distance_3d: float = 0.0` |
| 属性 | [`emission_angle_enabled_3d`](#member-gfaudiospatialsettings-properties-emission_angle_enabled_3d) | `var emission_angle_enabled_3d: bool = false` |
| 属性 | [`emission_angle_degrees_3d`](#member-gfaudiospatialsettings-properties-emission_angle_degrees_3d) | `var emission_angle_degrees_3d: float = 45.0` |
| 属性 | [`emission_angle_filter_attenuation_db_3d`](#member-gfaudiospatialsettings-properties-emission_angle_filter_attenuation_db_3d) | `var emission_angle_filter_attenuation_db_3d: float = -12.0` |
| 属性 | [`attenuation_filter_cutoff_hz_3d`](#member-gfaudiospatialsettings-properties-attenuation_filter_cutoff_hz_3d) | `var attenuation_filter_cutoff_hz_3d: float = 5000.0` |
| 属性 | [`attenuation_filter_db_3d`](#member-gfaudiospatialsettings-properties-attenuation_filter_db_3d) | `var attenuation_filter_db_3d: float = -24.0` |
| 属性 | [`doppler_tracking_3d`](#member-gfaudiospatialsettings-properties-doppler_tracking_3d) | `var doppler_tracking_3d: int = 0` |
| 方法 | [`apply_to_2d`](#member-gfaudiospatialsettings-methods-apply_to_2d) | `func apply_to_2d(player: AudioStreamPlayer2D) -> bool:` |
| 方法 | [`apply_to_3d`](#member-gfaudiospatialsettings-methods-apply_to_3d) | `func apply_to_3d(player: AudioStreamPlayer3D) -> bool:` |

## 属性

<a id="member-gfaudiospatialsettings-properties-max_polyphony"></a>

### `max_polyphony`

- API：`public`

```gdscript
var max_polyphony: int = 1
```

最大同时复音数量。

<a id="member-gfaudiospatialsettings-properties-panning_strength"></a>

### `panning_strength`

- API：`public`

```gdscript
var panning_strength: float = 1.0
```

声像强度。

<a id="member-gfaudiospatialsettings-properties-playback_type"></a>

### `playback_type`

- API：`public`

```gdscript
var playback_type: int = 0
```

播放类型。0 为 Default，1 为 Stream，2 为 Sample。

<a id="member-gfaudiospatialsettings-properties-area_mask_2d"></a>

### `area_mask_2d`

- API：`public`

```gdscript
var area_mask_2d: int = 1
```

2D 音频区域掩码。

<a id="member-gfaudiospatialsettings-properties-max_distance_2d"></a>

### `max_distance_2d`

- API：`public`

```gdscript
var max_distance_2d: float = 2000.0
```

2D 最大传播距离，单位像素。

<a id="member-gfaudiospatialsettings-properties-attenuation_2d"></a>

### `attenuation_2d`

- API：`public`

```gdscript
var attenuation_2d: float = 1.0
```

2D 衰减强度。

<a id="member-gfaudiospatialsettings-properties-attenuation_model_3d"></a>

### `attenuation_model_3d`

- API：`public`

```gdscript
var attenuation_model_3d: int = 0
```

3D 衰减模型。0 为 Inverse，1 为 Inverse Square，2 为 Logarithmic，3 为 Disabled。

<a id="member-gfaudiospatialsettings-properties-area_mask_3d"></a>

### `area_mask_3d`

- API：`public`

```gdscript
var area_mask_3d: int = 1
```

3D 音频区域掩码。

<a id="member-gfaudiospatialsettings-properties-unit_size_3d"></a>

### `unit_size_3d`

- API：`public`

```gdscript
var unit_size_3d: float = 10.0
```

3D 单位尺寸。

<a id="member-gfaudiospatialsettings-properties-max_db_3d"></a>

### `max_db_3d`

- API：`public`

```gdscript
var max_db_3d: float = 3.0
```

3D 最大增益，单位 dB。

<a id="member-gfaudiospatialsettings-properties-max_distance_3d"></a>

### `max_distance_3d`

- API：`public`

```gdscript
var max_distance_3d: float = 0.0
```

3D 最大传播距离，0 表示不限制。

<a id="member-gfaudiospatialsettings-properties-emission_angle_enabled_3d"></a>

### `emission_angle_enabled_3d`

- API：`public`

```gdscript
var emission_angle_enabled_3d: bool = false
```

是否启用 3D 发射角过滤。

<a id="member-gfaudiospatialsettings-properties-emission_angle_degrees_3d"></a>

### `emission_angle_degrees_3d`

- API：`public`

```gdscript
var emission_angle_degrees_3d: float = 45.0
```

3D 发射角角度。

<a id="member-gfaudiospatialsettings-properties-emission_angle_filter_attenuation_db_3d"></a>

### `emission_angle_filter_attenuation_db_3d`

- API：`public`

```gdscript
var emission_angle_filter_attenuation_db_3d: float = -12.0
```

3D 发射角外的衰减，单位 dB。

<a id="member-gfaudiospatialsettings-properties-attenuation_filter_cutoff_hz_3d"></a>

### `attenuation_filter_cutoff_hz_3d`

- API：`public`

```gdscript
var attenuation_filter_cutoff_hz_3d: float = 5000.0
```

3D 距离衰减滤波截止频率。

<a id="member-gfaudiospatialsettings-properties-attenuation_filter_db_3d"></a>

### `attenuation_filter_db_3d`

- API：`public`

```gdscript
var attenuation_filter_db_3d: float = -24.0
```

3D 距离衰减滤波增益，单位 dB。

<a id="member-gfaudiospatialsettings-properties-doppler_tracking_3d"></a>

### `doppler_tracking_3d`

- API：`public`

```gdscript
var doppler_tracking_3d: int = 0
```

3D 多普勒追踪模式。0 为 Disabled，1 为 Idle，2 为 Physics。

## 方法

<a id="member-gfaudiospatialsettings-methods-apply_to_2d"></a>

### `apply_to_2d`

- API：`public`

```gdscript
func apply_to_2d(player: AudioStreamPlayer2D) -> bool:
```

将设置应用到 2D 空间播放器。

参数：

| 名称 | 说明 |
|---|---|
| `player` | 目标 2D 空间播放器。 |

返回：成功应用时返回 true。

<a id="member-gfaudiospatialsettings-methods-apply_to_3d"></a>

### `apply_to_3d`

- API：`public`

```gdscript
func apply_to_3d(player: AudioStreamPlayer3D) -> bool:
```

将设置应用到 3D 空间播放器。

参数：

| 名称 | 说明 |
|---|---|
| `player` | 目标 3D 空间播放器。 |

返回：成功应用时返回 true。
