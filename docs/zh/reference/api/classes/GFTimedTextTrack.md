# GFTimedTextTrack

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/timeline/gf_timed_text_track.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

通用时间段文本轨道。 管理一组按时间查询的 `GFTimedTextEntry`，不绑定字幕格式或具体 UI。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`track_id`](#member-gftimedtexttrack-properties-track_id) | `var track_id: StringName = &""` |
| 属性 | [`entries`](#member-gftimedtexttrack-properties-entries) | `var entries: Array[GFTimedTextEntry] = []` |
| 属性 | [`metadata`](#member-gftimedtexttrack-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`add_entry`](#member-gftimedtexttrack-methods-add_entry) | `func add_entry( start_time: float, end_time: float, text: String, entry_metadata: Dictionary = {} ) -> GFTimedTextEntry:` |
| 方法 | [`clear`](#member-gftimedtexttrack-methods-clear) | `func clear() -> void:` |
| 方法 | [`sort_entries`](#member-gftimedtexttrack-methods-sort_entries) | `func sort_entries() -> void:` |
| 方法 | [`get_entry_at_time`](#member-gftimedtexttrack-methods-get_entry_at_time) | `func get_entry_at_time(time_seconds: float) -> GFTimedTextEntry:` |
| 方法 | [`get_text_at_time`](#member-gftimedtexttrack-methods-get_text_at_time) | `func get_text_at_time(time_seconds: float, default_text: String = "") -> String:` |
| 方法 | [`get_entries_in_range`](#member-gftimedtexttrack-methods-get_entries_in_range) | `func get_entries_in_range(range_start: float, range_end: float) -> Array[GFTimedTextEntry]:` |
| 方法 | [`get_total_duration`](#member-gftimedtexttrack-methods-get_total_duration) | `func get_total_duration() -> float:` |
| 方法 | [`duplicate_track`](#member-gftimedtexttrack-methods-duplicate_track) | `func duplicate_track() -> GFTimedTextTrack:` |
| 方法 | [`to_dictionary`](#member-gftimedtexttrack-methods-to_dictionary) | `func to_dictionary() -> Dictionary:` |
| 方法 | [`apply_dictionary`](#member-gftimedtexttrack-methods-apply_dictionary) | `func apply_dictionary(data: Dictionary) -> void:` |

## 属性

<a id="member-gftimedtexttrack-properties-track_id"></a>

### `track_id`

- API：`public`

```gdscript
var track_id: StringName = &""
```

轨道标识。

<a id="member-gftimedtexttrack-properties-entries"></a>

### `entries`

- API：`public`

```gdscript
var entries: Array[GFTimedTextEntry] = []
```

时间段文本条目列表。

<a id="member-gftimedtexttrack-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

可选元数据。

结构：

- `metadata`: Dictionary extension metadata for the timed text track.

## 方法

<a id="member-gftimedtexttrack-methods-add_entry"></a>

### `add_entry`

- API：`public`

```gdscript
func add_entry( start_time: float, end_time: float, text: String, entry_metadata: Dictionary = {} ) -> GFTimedTextEntry:
```

添加时间段文本条目。

参数：

| 名称 | 说明 |
|---|---|
| `start_time` | 开始时间，单位秒。 |
| `end_time` | 结束时间，单位秒。 |
| `text` | 文本内容。 |
| `entry_metadata` | 条目元数据。 |

返回：新条目。

结构：

- `entry_metadata`: Dictionary metadata copied into the new entry.

<a id="member-gftimedtexttrack-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空轨道。

<a id="member-gftimedtexttrack-methods-sort_entries"></a>

### `sort_entries`

- API：`public`

```gdscript
func sort_entries() -> void:
```

按开始时间排序条目。

<a id="member-gftimedtexttrack-methods-get_entry_at_time"></a>

### `get_entry_at_time`

- API：`public`

```gdscript
func get_entry_at_time(time_seconds: float) -> GFTimedTextEntry:
```

获取指定时间的第一条文本条目。

参数：

| 名称 | 说明 |
|---|---|
| `time_seconds` | 时间，单位秒。 |

返回：命中的条目；没有命中时返回 null。

<a id="member-gftimedtexttrack-methods-get_text_at_time"></a>

### `get_text_at_time`

- API：`public`

```gdscript
func get_text_at_time(time_seconds: float, default_text: String = "") -> String:
```

获取指定时间的文本。

参数：

| 名称 | 说明 |
|---|---|
| `time_seconds` | 时间，单位秒。 |
| `default_text` | 没有命中时返回的文本。 |

返回：文本内容。

<a id="member-gftimedtexttrack-methods-get_entries_in_range"></a>

### `get_entries_in_range`

- API：`public`

```gdscript
func get_entries_in_range(range_start: float, range_end: float) -> Array[GFTimedTextEntry]:
```

获取与时间范围相交的条目。

参数：

| 名称 | 说明 |
|---|---|
| `range_start` | 范围开始时间。 |
| `range_end` | 范围结束时间。 |

返回：条目列表。

<a id="member-gftimedtexttrack-methods-get_total_duration"></a>

### `get_total_duration`

- API：`public`

```gdscript
func get_total_duration() -> float:
```

获取轨道总时长。

返回：最大结束时间。

<a id="member-gftimedtexttrack-methods-duplicate_track"></a>

### `duplicate_track`

- API：`public`

```gdscript
func duplicate_track() -> GFTimedTextTrack:
```

创建同内容拷贝。

返回：新轨道。

<a id="member-gftimedtexttrack-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary() -> Dictionary:
```

转换为字典。

返回：轨道字典。

结构：

- `return`: Dictionary serialized timed text track.

<a id="member-gftimedtexttrack-methods-apply_dictionary"></a>

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

- `data`: Dictionary serialized timed text track.
