# GFSessionTraceChannelDefinition

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_session_trace_channel_definition.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

Session Trace 配方中的通道定义。 该资源只描述稳定通道 ID、可见性和容量，不持有运行时回调或业务状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`channel_id`](#member-gfsessiontracechanneldefinition-properties-channel_id) | `var channel_id: StringName = &""` |
| 属性 | [`enabled`](#member-gfsessiontracechanneldefinition-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`include_in_snapshot`](#member-gfsessiontracechanneldefinition-properties-include_in_snapshot) | `var include_in_snapshot: bool = true` |
| 属性 | [`max_events`](#member-gfsessiontracechanneldefinition-properties-max_events) | `var max_events: int = 0` |
| 属性 | [`max_event_bytes`](#member-gfsessiontracechanneldefinition-properties-max_event_bytes) | `var max_event_bytes: int = 0` |
| 属性 | [`metadata`](#member-gfsessiontracechanneldefinition-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfsessiontracechanneldefinition-methods-configure) | `func configure( p_channel_id: StringName, options: Dictionary = {} ) -> GFSessionTraceChannelDefinition:` |
| 方法 | [`validate_definition`](#member-gfsessiontracechanneldefinition-methods-validate_definition) | `func validate_definition() -> Dictionary:` |

## 属性

<a id="member-gfsessiontracechanneldefinition-properties-channel_id"></a>

### `channel_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var channel_id: StringName = &""
```

稳定通道 ID。

<a id="member-gfsessiontracechanneldefinition-properties-enabled"></a>

### `enabled`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var enabled: bool = true
```

通道应用后是否启用。

<a id="member-gfsessiontracechanneldefinition-properties-include_in_snapshot"></a>

### `include_in_snapshot`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var include_in_snapshot: bool = true
```

默认快照是否包含该通道事件。

<a id="member-gfsessiontracechanneldefinition-properties-max_events"></a>

### `max_events`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_events: int = 0
```

通道最多保留的事件数；0 表示只使用全局限制。

<a id="member-gfsessiontracechanneldefinition-properties-max_event_bytes"></a>

### `max_event_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_event_bytes: int = 0
```

通道单事件字节预算；0 表示只使用全局限制。

<a id="member-gfsessiontracechanneldefinition-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var metadata: Dictionary = {}
```

使用 privacy 安全下限持久保存的目录元数据。

结构：

- `metadata`: Dictionary with project-defined catalog metadata.

## 方法

<a id="member-gfsessiontracechanneldefinition-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure( p_channel_id: StringName, options: Dictionary = {} ) -> GFSessionTraceChannelDefinition:
```

配置通道定义并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_channel_id` | 稳定通道 ID。 |
| `options` | 通道配置。 |

返回：当前定义。

结构：

- `options`: Dictionary with enabled, include_in_snapshot, max_events, max_event_bytes, and metadata.

<a id="member-gfsessiontracechanneldefinition-methods-validate_definition"></a>

### `validate_definition`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_definition() -> Dictionary:
```

校验通道定义。

返回：GFValidationReportDictionary 兼容报告。

结构：

- `return`: Dictionary with ok, issues, counts, summary, and next_actions.
