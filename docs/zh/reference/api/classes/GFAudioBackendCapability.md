# GFAudioBackendCapability

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_backend_capability.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：值对象 (`value_object`)
- 首次版本：`3.17.0`

音频后端能力声明。 用布尔能力与元数据描述一个后端能处理哪些通用音频请求。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`supports_bgm`](#member-gfaudiobackendcapability-properties-supports_bgm) | `var supports_bgm: bool = false` |
| 属性 | [`supports_sfx`](#member-gfaudiobackendcapability-properties-supports_sfx) | `var supports_sfx: bool = false` |
| 属性 | [`supports_ambient`](#member-gfaudiobackendcapability-properties-supports_ambient) | `var supports_ambient: bool = false` |
| 属性 | [`supports_spatial_sfx`](#member-gfaudiobackendcapability-properties-supports_spatial_sfx) | `var supports_spatial_sfx: bool = false` |
| 属性 | [`supports_events`](#member-gfaudiobackendcapability-properties-supports_events) | `var supports_events: bool = false` |
| 属性 | [`supports_parameters`](#member-gfaudiobackendcapability-properties-supports_parameters) | `var supports_parameters: bool = false` |
| 属性 | [`supports_states`](#member-gfaudiobackendcapability-properties-supports_states) | `var supports_states: bool = false` |
| 属性 | [`supports_switches`](#member-gfaudiobackendcapability-properties-supports_switches) | `var supports_switches: bool = false` |
| 属性 | [`supports_listeners`](#member-gfaudiobackendcapability-properties-supports_listeners) | `var supports_listeners: bool = false` |
| 属性 | [`supports_async_loading`](#member-gfaudiobackendcapability-properties-supports_async_loading) | `var supports_async_loading: bool = false` |
| 属性 | [`supports_playback_region_contract`](#member-gfaudiobackendcapability-properties-supports_playback_region_contract) | `var supports_playback_region_contract: bool = false` |
| 属性 | [`metadata`](#member-gfaudiobackendcapability-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`has_capability`](#member-gfaudiobackendcapability-methods-has_capability) | `func has_capability(capability_id: StringName) -> bool:` |
| 方法 | [`duplicate_capability`](#member-gfaudiobackendcapability-methods-duplicate_capability) | `func duplicate_capability() -> GFAudioBackendCapability:` |
| 方法 | [`to_dictionary`](#member-gfaudiobackendcapability-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfaudiobackendcapability-properties-supports_bgm"></a>

### `supports_bgm`

- API：`public`

```gdscript
var supports_bgm: bool = false
```

是否支持 BGM。

<a id="member-gfaudiobackendcapability-properties-supports_sfx"></a>

### `supports_sfx`

- API：`public`

```gdscript
var supports_sfx: bool = false
```

是否支持 SFX。

<a id="member-gfaudiobackendcapability-properties-supports_ambient"></a>

### `supports_ambient`

- API：`public`

```gdscript
var supports_ambient: bool = false
```

是否支持环境音。

<a id="member-gfaudiobackendcapability-properties-supports_spatial_sfx"></a>

### `supports_spatial_sfx`

- API：`public`

```gdscript
var supports_spatial_sfx: bool = false
```

是否支持空间音效。

<a id="member-gfaudiobackendcapability-properties-supports_events"></a>

### `supports_events`

- API：`public`

```gdscript
var supports_events: bool = false
```

是否支持资源化事件。

<a id="member-gfaudiobackendcapability-properties-supports_parameters"></a>

### `supports_parameters`

- API：`public`

```gdscript
var supports_parameters: bool = false
```

是否支持参数写入。

<a id="member-gfaudiobackendcapability-properties-supports_states"></a>

### `supports_states`

- API：`public`

```gdscript
var supports_states: bool = false
```

是否支持状态写入。

<a id="member-gfaudiobackendcapability-properties-supports_switches"></a>

### `supports_switches`

- API：`public`

```gdscript
var supports_switches: bool = false
```

是否支持开关写入。

<a id="member-gfaudiobackendcapability-properties-supports_listeners"></a>

### `supports_listeners`

- API：`public`

```gdscript
var supports_listeners: bool = false
```

是否支持监听器。

<a id="member-gfaudiobackendcapability-properties-supports_async_loading"></a>

### `supports_async_loading`

- API：`public`

```gdscript
var supports_async_loading: bool = false
```

是否支持异步加载或卸载。

<a id="member-gfaudiobackendcapability-properties-supports_playback_region_contract"></a>

### `supports_playback_region_contract`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var supports_playback_region_contract: bool = false
```

是否支持逐请求的类型化播放区间能力协商。 该标记只表示后端实现了协商契约；具体片段、通道和循环模式仍须通过 `GFAudioBackend.evaluate_playback_region()` 判断。

<a id="member-gfaudiobackendcapability-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据，供项目层或调试面板展示。

结构：

- `metadata`: 后端能力元数据 Dictionary；键和值由具体后端或项目工具约定。

## 方法

<a id="member-gfaudiobackendcapability-methods-has_capability"></a>

### `has_capability`

- API：`public`

```gdscript
func has_capability(capability_id: StringName) -> bool:
```

检查能力是否存在。

参数：

| 名称 | 说明 |
|---|---|
| `capability_id` | 能力标识。 |

返回：支持返回 true。

<a id="member-gfaudiobackendcapability-methods-duplicate_capability"></a>

### `duplicate_capability`

- API：`public`

```gdscript
func duplicate_capability() -> GFAudioBackendCapability:
```

创建同内容拷贝。

返回：新能力声明。

<a id="member-gfaudiobackendcapability-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`
- 首次版本：`3.2.0`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为字典。

返回：能力字典。

结构：

- `return`: 能力 Dictionary，包含 bgm、sfx、ambient、spatial_sfx、events、parameters、states、switches、listeners、async_loading、playback_region_contract 和 metadata 字段。
