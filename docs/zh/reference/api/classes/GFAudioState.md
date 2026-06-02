# GFAudioState

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_state.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`3.17.0`

通用音频状态请求。 表示一个状态组和值，不解释其具体混音或播放含义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`group_id`](#member-gfaudiostate-properties-group_id) | `var group_id: StringName = &""` |
| 属性 | [`state_id`](#member-gfaudiostate-properties-state_id) | `var state_id: StringName = &""` |
| 属性 | [`metadata`](#member-gfaudiostate-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`to_dictionary`](#member-gfaudiostate-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfaudiostate-properties-group_id"></a>

### `group_id`

- API：`public`

```gdscript
var group_id: StringName = &""
```

状态组标识。

<a id="member-gfaudiostate-properties-state_id"></a>

### `state_id`

- API：`public`

```gdscript
var state_id: StringName = &""
```

状态值标识。

<a id="member-gfaudiostate-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。

结构：

- `metadata`: 音频状态元数据 Dictionary；键和值由后端或项目逻辑约定。

## 方法

<a id="member-gfaudiostate-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为请求字典。

返回：请求字典。

结构：

- `return`: 状态请求 Dictionary，包含 group_id、state_id 和 metadata 字段。
