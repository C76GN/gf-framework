# GFAudioParameter

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/audio/gf_audio_parameter.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`3.17.0`

通用音频参数请求。 表示可写入音频后端的全局或对象级数值参数。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`parameter_id`](#member-gfaudioparameter-properties-parameter_id) | `var parameter_id: StringName = &""` |
| 属性 | [`value`](#member-gfaudioparameter-properties-value) | `var value: float = 0.0` |
| 属性 | [`scope_id`](#member-gfaudioparameter-properties-scope_id) | `var scope_id: StringName = &""` |
| 属性 | [`metadata`](#member-gfaudioparameter-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`to_dictionary`](#member-gfaudioparameter-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfaudioparameter-properties-parameter_id"></a>

### `parameter_id`

- API：`public`

```gdscript
var parameter_id: StringName = &""
```

参数稳定标识。

<a id="member-gfaudioparameter-properties-value"></a>

### `value`

- API：`public`

```gdscript
var value: float = 0.0
```

参数值。

<a id="member-gfaudioparameter-properties-scope_id"></a>

### `scope_id`

- API：`public`

```gdscript
var scope_id: StringName = &""
```

可选作用域标识。

<a id="member-gfaudioparameter-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。

结构：

- `metadata`: 音频参数元数据 Dictionary；键和值由后端或项目逻辑约定。

## 方法

<a id="member-gfaudioparameter-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为请求字典。

返回：请求字典。

结构：

- `return`: 参数请求 Dictionary，包含 parameter_id、value、scope_id 和 metadata 字段。
