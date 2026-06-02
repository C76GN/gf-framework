# GFAudioSwitch

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_switch.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`3.17.0`

通用音频开关请求。 表示某个对象或作用域上的开关组和值。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`group_id`](#member-gfaudioswitch-properties-group_id) | `var group_id: StringName = &""` |
| 属性 | [`switch_id`](#member-gfaudioswitch-properties-switch_id) | `var switch_id: StringName = &""` |
| 属性 | [`scope_id`](#member-gfaudioswitch-properties-scope_id) | `var scope_id: StringName = &""` |
| 属性 | [`metadata`](#member-gfaudioswitch-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`to_dictionary`](#member-gfaudioswitch-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfaudioswitch-properties-group_id"></a>

### `group_id`

- API：`public`

```gdscript
var group_id: StringName = &""
```

开关组标识。

<a id="member-gfaudioswitch-properties-switch_id"></a>

### `switch_id`

- API：`public`

```gdscript
var switch_id: StringName = &""
```

开关值标识。

<a id="member-gfaudioswitch-properties-scope_id"></a>

### `scope_id`

- API：`public`

```gdscript
var scope_id: StringName = &""
```

可选作用域标识。

<a id="member-gfaudioswitch-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。

结构：

- `metadata`: 音频开关元数据 Dictionary；键和值由后端或项目逻辑约定。

## 方法

<a id="member-gfaudioswitch-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为请求字典。

返回：请求字典。

结构：

- `return`: 开关请求 Dictionary，包含 group_id、switch_id、scope_id 和 metadata 字段。
