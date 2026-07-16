# GFInputRecording

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/input/recording/gf_input_recording.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.17.0`

抽象动作输入录制数据。 记录 action_id、时间、值、玩家索引和元数据，可交给 GFInputPlayback 通过 GFVirtualInputSource 回放。它不读取具体设备，也不绑定任何玩法语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`recording_id`](#member-gfinputrecording-properties-recording_id) | `var recording_id: StringName = &""` |
| 属性 | [`duration_seconds`](#member-gfinputrecording-properties-duration_seconds) | `var duration_seconds: float = 0.0` |
| 属性 | [`events`](#member-gfinputrecording-properties-events) | `var events: Array[Dictionary]:` |
| 属性 | [`metadata`](#member-gfinputrecording-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`add_event`](#member-gfinputrecording-methods-add_event) | `func add_event( action_id: StringName, value: Variant, time_seconds: float, player_index: int = -1, source_id: StringName = &"", event_metadata: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`clear`](#member-gfinputrecording-methods-clear) | `func clear() -> void:` |
| 方法 | [`is_empty`](#member-gfinputrecording-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`get_event_count`](#member-gfinputrecording-methods-get_event_count) | `func get_event_count() -> int:` |
| 方法 | [`sort_events`](#member-gfinputrecording-methods-sort_events) | `func sort_events() -> void:` |
| 方法 | [`get_events`](#member-gfinputrecording-methods-get_events) | `func get_events() -> Array[Dictionary]:` |
| 方法 | [`duplicate_recording`](#member-gfinputrecording-methods-duplicate_recording) | `func duplicate_recording() -> GFInputRecording:` |
| 方法 | [`to_dict`](#member-gfinputrecording-methods-to_dict) | `func to_dict(json_compatible: bool = false) -> Dictionary:` |
| 方法 | [`apply_dict`](#member-gfinputrecording-methods-apply_dict) | `func apply_dict(data: Dictionary, json_compatible: bool = false) -> void:` |
| 方法 | [`from_dict`](#member-gfinputrecording-methods-from_dict) | `static func from_dict(data: Dictionary, json_compatible: bool = false) -> GFInputRecording:` |

## 属性

<a id="member-gfinputrecording-properties-recording_id"></a>

### `recording_id`

- API：`public`

```gdscript
var recording_id: StringName = &""
```

录制标识。

<a id="member-gfinputrecording-properties-duration_seconds"></a>

### `duration_seconds`

- API：`public`

```gdscript
var duration_seconds: float = 0.0
```

录制总时长，单位秒。

<a id="member-gfinputrecording-properties-events"></a>

### `events`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
var events: Array[Dictionary]:
```

事件列表只读快照。每项包含 time_seconds、action_id、value、player_index、source_id 和 metadata。

结构：

- `events`: Array，包含 time_seconds: float、action_id: StringName、value: Variant、player_index: int、source_id: StringName 和 metadata: Dictionary 的 Dictionary 条目。

<a id="member-gfinputrecording-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，项目持有的录制标签、工具或存档数据。

## 方法

<a id="member-gfinputrecording-methods-add_event"></a>

### `add_event`

- API：`public`

```gdscript
func add_event( action_id: StringName, value: Variant, time_seconds: float, player_index: int = -1, source_id: StringName = &"", event_metadata: Dictionary = {} ) -> Dictionary:
```

添加一个动作值事件。

参数：

| 名称 | 说明 |
|---|---|
| `action_id` | 动作标识。 |
| `value` | 动作值。 |
| `time_seconds` | 事件时间，单位秒。 |
| `player_index` | 玩家索引；小于 0 表示不指定。 |
| `source_id` | 可选来源标识。 |
| `event_metadata` | 事件元数据。 |

返回：新增事件字典。

结构：

- `value`: Variant，要记录的动作值；常见值为 bool、float、Vector2、Vector3，或 GFVariantData 支持的项目自定义数据。
- `event_metadata`: Dictionary，复制到当前事件中供项目诊断或工具使用。
- `return`: Dictionary，包含 time_seconds、action_id、value、player_index、source_id 和 metadata。

<a id="member-gfinputrecording-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空录制。

<a id="member-gfinputrecording-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

检查录制是否为空。

返回：为空时返回 true。

<a id="member-gfinputrecording-methods-get_event_count"></a>

### `get_event_count`

- API：`public`

```gdscript
func get_event_count() -> int:
```

获取事件数量。

返回：事件数量。

<a id="member-gfinputrecording-methods-sort_events"></a>

### `sort_events`

- API：`public`

```gdscript
func sort_events() -> void:
```

按事件时间排序。

<a id="member-gfinputrecording-methods-get_events"></a>

### `get_events`

- API：`public`

```gdscript
func get_events() -> Array[Dictionary]:
```

获取事件副本。

返回：事件副本数组。

结构：

- `return`: Array，包含 time_seconds、action_id、value、player_index、source_id 和 metadata 的 Dictionary 条目。

<a id="member-gfinputrecording-methods-duplicate_recording"></a>

### `duplicate_recording`

- API：`public`

```gdscript
func duplicate_recording() -> GFInputRecording:
```

复制录制。

返回：新录制。

<a id="member-gfinputrecording-methods-to_dict"></a>

### `to_dict`

- API：`public`

```gdscript
func to_dict(json_compatible: bool = false) -> Dictionary:
```

转为字典。

参数：

| 名称 | 说明 |
|---|---|
| `json_compatible` | 为 true 时会把事件值与元数据转换为 JSON 兼容值。 |

返回：录制字典。

结构：

- `return`: Dictionary，包含 recording_id: String、duration_seconds: float、events: Array[Dictionary] 和 metadata: Dictionary。

<a id="member-gfinputrecording-methods-apply_dict"></a>

### `apply_dict`

- API：`public`

```gdscript
func apply_dict(data: Dictionary, json_compatible: bool = false) -> void:
```

从字典恢复录制。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 录制字典。 |
| `json_compatible` | 为 true 时会先恢复类型化 JSON 值。 |

结构：

- `data`: Dictionary，包含 recording_id、duration_seconds、events 和 metadata。

<a id="member-gfinputrecording-methods-from_dict"></a>

### `from_dict`

- API：`public`

```gdscript
static func from_dict(data: Dictionary, json_compatible: bool = false) -> GFInputRecording:
```

从字典创建录制。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 录制字典。 |
| `json_compatible` | 为 true 时会先恢复类型化 JSON 值。 |

返回：录制。

结构：

- `data`: Dictionary，包含 recording_id、duration_seconds、events 和 metadata。
