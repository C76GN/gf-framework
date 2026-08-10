# GFReplayTimeline

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/foundation/timeline/gf_replay_timeline.gd`
- 模块：`Standard`
- 继承：`RefCounted`
- API：`public`
- 类别：领域模型 (`domain_model`)
- 首次版本：`3.20.0`

通用回放时间线。 按时间保存命令、输入、快照或项目自定义事件的纯数据记录，便于测试、 诊断、重放和工具链串联。它只负责排序、查询、合并和序列化，不执行事件。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 常量 | [`EVENT_COMMAND`](#member-gfreplaytimeline-constants-event_command) | `const EVENT_COMMAND: StringName = &"command"` |
| 常量 | [`EVENT_INPUT`](#member-gfreplaytimeline-constants-event_input) | `const EVENT_INPUT: StringName = &"input"` |
| 常量 | [`EVENT_SNAPSHOT`](#member-gfreplaytimeline-constants-event_snapshot) | `const EVENT_SNAPSHOT: StringName = &"snapshot"` |
| 属性 | [`timeline_id`](#member-gfreplaytimeline-properties-timeline_id) | `var timeline_id: StringName = &""` |
| 属性 | [`duration_seconds`](#member-gfreplaytimeline-properties-duration_seconds) | `var duration_seconds: float = 0.0` |
| 属性 | [`events`](#member-gfreplaytimeline-properties-events) | `var events: Array[Dictionary] = []` |
| 属性 | [`metadata`](#member-gfreplaytimeline-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`add_event`](#member-gfreplaytimeline-methods-add_event) | `func add_event( time_seconds: float, event_kind: StringName, payload: Variant = null, event_metadata: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`add_command`](#member-gfreplaytimeline-methods-add_command) | `func add_command( time_seconds: float, command_payload: Variant, event_metadata: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`add_input`](#member-gfreplaytimeline-methods-add_input) | `func add_input( time_seconds: float, input_payload: Variant, event_metadata: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`add_snapshot`](#member-gfreplaytimeline-methods-add_snapshot) | `func add_snapshot( time_seconds: float, snapshot_payload: Variant, event_metadata: Dictionary = {} ) -> Dictionary:` |
| 方法 | [`append_timeline`](#member-gfreplaytimeline-methods-append_timeline) | `func append_timeline( timeline: RefCounted, time_offset: float = 0.0, kind_filter: PackedStringArray = PackedStringArray() ) -> int:` |
| 方法 | [`clear`](#member-gfreplaytimeline-methods-clear) | `func clear() -> void:` |
| 方法 | [`is_empty`](#member-gfreplaytimeline-methods-is_empty) | `func is_empty() -> bool:` |
| 方法 | [`get_event_count`](#member-gfreplaytimeline-methods-get_event_count) | `func get_event_count() -> int:` |
| 方法 | [`sort_events`](#member-gfreplaytimeline-methods-sort_events) | `func sort_events() -> void:` |
| 方法 | [`get_events`](#member-gfreplaytimeline-methods-get_events) | `func get_events() -> Array[Dictionary]:` |
| 方法 | [`get_events_by_kind`](#member-gfreplaytimeline-methods-get_events_by_kind) | `func get_events_by_kind(event_kind: StringName) -> Array[Dictionary]:` |
| 方法 | [`get_events_in_range`](#member-gfreplaytimeline-methods-get_events_in_range) | `func get_events_in_range( range_start: float, range_end: float, inclusive_end: bool = false ) -> Array[Dictionary]:` |
| 方法 | [`duplicate_timeline`](#member-gfreplaytimeline-methods-duplicate_timeline) | `func duplicate_timeline() -> RefCounted:` |
| 方法 | [`to_dictionary`](#member-gfreplaytimeline-methods-to_dictionary) | `func to_dictionary(json_compatible: bool = false) -> Dictionary:` |
| 方法 | [`apply_dictionary`](#member-gfreplaytimeline-methods-apply_dictionary) | `func apply_dictionary(data: Dictionary, json_compatible: bool = false) -> void:` |
| 方法 | [`from_dictionary`](#member-gfreplaytimeline-methods-from_dictionary) | `static func from_dictionary(data: Dictionary, json_compatible: bool = false) -> RefCounted:` |

## 常量

<a id="member-gfreplaytimeline-constants-event_command"></a>

### `EVENT_COMMAND`

- API：`public`

```gdscript
const EVENT_COMMAND: StringName = &"command"
```

通用命令事件类型。

<a id="member-gfreplaytimeline-constants-event_input"></a>

### `EVENT_INPUT`

- API：`public`

```gdscript
const EVENT_INPUT: StringName = &"input"
```

通用输入事件类型。

<a id="member-gfreplaytimeline-constants-event_snapshot"></a>

### `EVENT_SNAPSHOT`

- API：`public`

```gdscript
const EVENT_SNAPSHOT: StringName = &"snapshot"
```

通用状态快照事件类型。

## 属性

<a id="member-gfreplaytimeline-properties-timeline_id"></a>

### `timeline_id`

- API：`public`

```gdscript
var timeline_id: StringName = &""
```

时间线标识。

<a id="member-gfreplaytimeline-properties-duration_seconds"></a>

### `duration_seconds`

- API：`public`

```gdscript
var duration_seconds: float = 0.0
```

时间线总时长，单位秒。

<a id="member-gfreplaytimeline-properties-events"></a>

### `events`

- API：`public`
- 首次版本：`3.20.0`

```gdscript
var events: Array[Dictionary] = []
```

事件列表。每项包含 time_seconds、event_kind、sequence、payload 和 metadata。

结构：

- `events`: Array[Dictionary]，包含 time_seconds: float、event_kind: StringName、sequence: int、payload: Variant 和 metadata: Dictionary。

<a id="member-gfreplaytimeline-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

项目自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，项目持有的录制、诊断或工具数据。

## 方法

<a id="member-gfreplaytimeline-methods-add_event"></a>

### `add_event`

- API：`public`

```gdscript
func add_event( time_seconds: float, event_kind: StringName, payload: Variant = null, event_metadata: Dictionary = {} ) -> Dictionary:
```

添加通用事件。

参数：

| 名称 | 说明 |
|---|---|
| `time_seconds` | 事件时间，单位秒。 |
| `event_kind` | 事件类型。 |
| `payload` | 事件载荷。 |
| `event_metadata` | 事件元数据。 |

返回：新增事件字典。

结构：

- `payload`: Variant，命令、输入、快照或项目自定义纯数据。
- `event_metadata`: Dictionary，复制到当前事件中供项目诊断或工具使用。
- `return`: Dictionary，包含 time_seconds、event_kind、payload 和 metadata。

<a id="member-gfreplaytimeline-methods-add_command"></a>

### `add_command`

- API：`public`

```gdscript
func add_command( time_seconds: float, command_payload: Variant, event_metadata: Dictionary = {} ) -> Dictionary:
```

添加通用命令事件。

参数：

| 名称 | 说明 |
|---|---|
| `time_seconds` | 事件时间，单位秒。 |
| `command_payload` | 命令载荷。 |
| `event_metadata` | 事件元数据。 |

返回：新增事件字典。

结构：

- `command_payload`: Variant，通常为命令快照或命令 ID 与参数字典。
- `event_metadata`: Dictionary，复制到当前事件中供项目诊断或工具使用。
- `return`: Dictionary，包含 time_seconds、event_kind、payload 和 metadata。

<a id="member-gfreplaytimeline-methods-add_input"></a>

### `add_input`

- API：`public`

```gdscript
func add_input( time_seconds: float, input_payload: Variant, event_metadata: Dictionary = {} ) -> Dictionary:
```

添加通用输入事件。

参数：

| 名称 | 说明 |
|---|---|
| `time_seconds` | 事件时间，单位秒。 |
| `input_payload` | 输入载荷。 |
| `event_metadata` | 事件元数据。 |

返回：新增事件字典。

结构：

- `input_payload`: Variant，通常为抽象动作输入事件字典。
- `event_metadata`: Dictionary，复制到当前事件中供项目诊断或工具使用。
- `return`: Dictionary，包含 time_seconds、event_kind、payload 和 metadata。

<a id="member-gfreplaytimeline-methods-add_snapshot"></a>

### `add_snapshot`

- API：`public`

```gdscript
func add_snapshot( time_seconds: float, snapshot_payload: Variant, event_metadata: Dictionary = {} ) -> Dictionary:
```

添加通用快照事件。

参数：

| 名称 | 说明 |
|---|---|
| `time_seconds` | 事件时间，单位秒。 |
| `snapshot_payload` | 快照载荷。 |
| `event_metadata` | 事件元数据。 |

返回：新增事件字典。

结构：

- `snapshot_payload`: Variant，通常为状态快照字典。
- `event_metadata`: Dictionary，复制到当前事件中供项目诊断或工具使用。
- `return`: Dictionary，包含 time_seconds、event_kind、payload 和 metadata。

<a id="member-gfreplaytimeline-methods-append_timeline"></a>

### `append_timeline`

- API：`public`
- 首次版本：`3.20.0`

```gdscript
func append_timeline( timeline: RefCounted, time_offset: float = 0.0, kind_filter: PackedStringArray = PackedStringArray() ) -> int:
```

合并另一条时间线。 source 与当前时间线相同时，基于调用开始时的事件快照恰好追加一次。

参数：

| 名称 | 说明 |
|---|---|
| `timeline` | 要合并的时间线。 |
| `time_offset` | 合并时追加的时间偏移。 |
| `kind_filter` | 可选事件类型过滤；为空时合并全部事件。 |

返回：合并的事件数量。

<a id="member-gfreplaytimeline-methods-clear"></a>

### `clear`

- API：`public`

```gdscript
func clear() -> void:
```

清空时间线。

<a id="member-gfreplaytimeline-methods-is_empty"></a>

### `is_empty`

- API：`public`

```gdscript
func is_empty() -> bool:
```

检查时间线是否为空。

返回：为空时返回 true。

<a id="member-gfreplaytimeline-methods-get_event_count"></a>

### `get_event_count`

- API：`public`

```gdscript
func get_event_count() -> int:
```

获取事件数量。

返回：事件数量。

<a id="member-gfreplaytimeline-methods-sort_events"></a>

### `sort_events`

- API：`public`

```gdscript
func sort_events() -> void:
```

按事件时间排序。

<a id="member-gfreplaytimeline-methods-get_events"></a>

### `get_events`

- API：`public`

```gdscript
func get_events() -> Array[Dictionary]:
```

获取事件副本。

返回：事件副本数组。

结构：

- `return`: Array[Dictionary]，包含 time_seconds、event_kind、payload 和 metadata。

<a id="member-gfreplaytimeline-methods-get_events_by_kind"></a>

### `get_events_by_kind`

- API：`public`

```gdscript
func get_events_by_kind(event_kind: StringName) -> Array[Dictionary]:
```

获取指定类型事件。

参数：

| 名称 | 说明 |
|---|---|
| `event_kind` | 事件类型。 |

返回：事件副本数组。

结构：

- `return`: Array[Dictionary]，包含 time_seconds、event_kind、payload 和 metadata。

<a id="member-gfreplaytimeline-methods-get_events_in_range"></a>

### `get_events_in_range`

- API：`public`

```gdscript
func get_events_in_range( range_start: float, range_end: float, inclusive_end: bool = false ) -> Array[Dictionary]:
```

获取与时间范围相交的事件。

参数：

| 名称 | 说明 |
|---|---|
| `range_start` | 范围开始时间。 |
| `range_end` | 范围结束时间。 |
| `inclusive_end` | 为 true 时包含结束时间边界。 |

返回：事件副本数组。

结构：

- `return`: Array[Dictionary]，包含 time_seconds、event_kind、payload 和 metadata。

<a id="member-gfreplaytimeline-methods-duplicate_timeline"></a>

### `duplicate_timeline`

- API：`public`

```gdscript
func duplicate_timeline() -> RefCounted:
```

复制时间线。

返回：新时间线。

<a id="member-gfreplaytimeline-methods-to_dictionary"></a>

### `to_dictionary`

- API：`public`

```gdscript
func to_dictionary(json_compatible: bool = false) -> Dictionary:
```

转换为字典。

参数：

| 名称 | 说明 |
|---|---|
| `json_compatible` | 为 true 时会把 payload 与 metadata 转换为 JSON 兼容值。 |

返回：时间线字典。

结构：

- `return`: Dictionary，包含 timeline_id、duration_seconds、events 和 metadata。

<a id="member-gfreplaytimeline-methods-apply_dictionary"></a>

### `apply_dictionary`

- API：`public`

```gdscript
func apply_dictionary(data: Dictionary, json_compatible: bool = false) -> void:
```

应用字典数据。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 时间线字典。 |
| `json_compatible` | 为 true 时会先恢复类型化 JSON 值。 |

结构：

- `data`: Dictionary，包含 timeline_id、duration_seconds、events 和 metadata。

<a id="member-gfreplaytimeline-methods-from_dictionary"></a>

### `from_dictionary`

- API：`public`

```gdscript
static func from_dictionary(data: Dictionary, json_compatible: bool = false) -> RefCounted:
```

从字典创建时间线。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 时间线字典。 |
| `json_compatible` | 为 true 时会先恢复类型化 JSON 值。 |

返回：时间线。

结构：

- `data`: Dictionary，包含 timeline_id、duration_seconds、events 和 metadata。
