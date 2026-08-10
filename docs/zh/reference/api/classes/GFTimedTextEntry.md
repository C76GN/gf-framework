# GFTimedTextEntry

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/timeline/gf_timed_text_entry.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用时间段文本条目。 表示一段开始时间、结束时间和文本，可用于字幕、对白、提示或时间轴注释。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`start_time`](#member-gftimedtextentry-properties-start_time) | `var start_time: float = 0.0:` |
| 属性 | [`end_time`](#member-gftimedtextentry-properties-end_time) | `var end_time: float = 0.0:` |
| 属性 | [`text`](#member-gftimedtextentry-properties-text) | `var text: String = ""` |
| 属性 | [`metadata`](#member-gftimedtextentry-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`contains_time`](#member-gftimedtextentry-methods-contains_time) | `func contains_time(time_seconds: float) -> bool:` |
| 方法 | [`intersects_range`](#member-gftimedtextentry-methods-intersects_range) | `func intersects_range(range_start: float, range_end: float) -> bool:` |
| 方法 | [`duplicate_entry`](#member-gftimedtextentry-methods-duplicate_entry) | `func duplicate_entry() -> GFTimedTextEntry:` |
| 方法 | [`to_dictionary`](#member-gftimedtextentry-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`apply_dictionary`](#member-gftimedtextentry-methods-apply_dictionary) | `func apply_dictionary(data: Dictionary) -> void:` |

## 属性

<a id="member-gftimedtextentry-properties-start_time"></a>

### `start_time`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var start_time: float = 0.0:
```

开始时间，单位秒。

<a id="member-gftimedtextentry-properties-end_time"></a>

### `end_time`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var end_time: float = 0.0:
```

结束时间，单位秒。

<a id="member-gftimedtextentry-properties-text"></a>

### `text`

- API：`public`

```gdscript
var text: String = ""
```

文本内容。

<a id="member-gftimedtextentry-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。

结构：

- `metadata`: Dictionary extension metadata for the timed text entry.

## 方法

<a id="member-gftimedtextentry-methods-contains_time"></a>

### `contains_time`

- API：`public`

```gdscript
func contains_time(time_seconds: float) -> bool:
```

检查时间是否落在条目范围内。

参数：

| 名称 | 说明 |
|---|---|
| `time_seconds` | 时间，单位秒。 |

返回：落在范围内返回 true。

<a id="member-gftimedtextentry-methods-intersects_range"></a>

### `intersects_range`

- API：`public`

```gdscript
func intersects_range(range_start: float, range_end: float) -> bool:
```

检查条目是否与时间范围相交。

参数：

| 名称 | 说明 |
|---|---|
| `range_start` | 范围开始时间。 |
| `range_end` | 范围结束时间。 |

返回：相交返回 true。

<a id="member-gftimedtextentry-methods-duplicate_entry"></a>

### `duplicate_entry`

- API：`public`

```gdscript
func duplicate_entry() -> GFTimedTextEntry:
```

创建同内容拷贝。

返回：新条目。

<a id="member-gftimedtextentry-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为字典。

返回：条目字典。

结构：

- `return`: Dictionary serialized timed text entry.

<a id="member-gftimedtextentry-methods-apply_dictionary"></a>

### `apply_dictionary`

- API：`public`

```gdscript
func apply_dictionary(data: Dictionary) -> void:
```

应用字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 字典数据。 |

结构：

- `data`: Dictionary serialized timed text entry.
