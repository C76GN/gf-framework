# GFSessionTraceRecipe

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_session_trace_recipe.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`unreleased`

可复用、可校验的 Session Trace 采集配方。 配方声明全局内存预算、允许的事件通道、显式检查点和快照读取默认值。 通道与检查点定义各自最多包含 256 项，数值预算会在运行时重新校验。 它不持有 Provider Callable、journal sink、上传地址、玩家许可或业务状态。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`recipe_id`](#member-gfsessiontracerecipe-properties-recipe_id) | `var recipe_id: StringName = &""` |
| 属性 | [`max_events`](#member-gfsessiontracerecipe-properties-max_events) | `var max_events: int = 512` |
| 属性 | [`max_event_buffer_bytes`](#member-gfsessiontracerecipe-properties-max_event_buffer_bytes) | `var max_event_buffer_bytes: int = 1024 * 1024` |
| 属性 | [`max_event_bytes`](#member-gfsessiontracerecipe-properties-max_event_bytes) | `var max_event_bytes: int = 16 * 1024` |
| 属性 | [`redaction_profile`](#member-gfsessiontracerecipe-properties-redaction_profile) | `var redaction_profile: String = GFReportValueCodec.REDACTION_PROFILE_PRIVACY` |
| 属性 | [`channels`](#member-gfsessiontracerecipe-properties-channels) | `var channels: Array[GFSessionTraceChannelDefinition] = []` |
| 属性 | [`checkpoints`](#member-gfsessiontracerecipe-properties-checkpoints) | `var checkpoints: Array[GFSessionTraceCheckpoint] = []` |
| 属性 | [`snapshot_limit`](#member-gfsessiontracerecipe-properties-snapshot_limit) | `var snapshot_limit: int = 0` |
| 属性 | [`include_context`](#member-gfsessiontracerecipe-properties-include_context) | `var include_context: bool = true` |
| 属性 | [`include_channel_catalog`](#member-gfsessiontracerecipe-properties-include_channel_catalog) | `var include_channel_catalog: bool = false` |
| 属性 | [`include_provider_catalog`](#member-gfsessiontracerecipe-properties-include_provider_catalog) | `var include_provider_catalog: bool = false` |
| 属性 | [`metadata`](#member-gfsessiontracerecipe-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfsessiontracerecipe-methods-configure) | `func configure( p_recipe_id: StringName, p_channels: Array[GFSessionTraceChannelDefinition], p_checkpoints: Array[GFSessionTraceCheckpoint] = [], options: Dictionary = {} ) -> GFSessionTraceRecipe:` |
| 方法 | [`validate_recipe`](#member-gfsessiontracerecipe-methods-validate_recipe) | `func validate_recipe() -> Dictionary:` |
| 方法 | [`get_checkpoint`](#member-gfsessiontracerecipe-methods-get_checkpoint) | `func get_checkpoint(checkpoint_id: StringName) -> GFSessionTraceCheckpoint:` |
| 方法 | [`to_report_dictionary`](#member-gfsessiontracerecipe-methods-to_report_dictionary) | `func to_report_dictionary() -> Dictionary:` |

## 属性

<a id="member-gfsessiontracerecipe-properties-recipe_id"></a>

### `recipe_id`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var recipe_id: StringName = &""
```

稳定配方 ID。

<a id="member-gfsessiontracerecipe-properties-max_events"></a>

### `max_events`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_events: int = 512
```

全局内存事件数量上限。

<a id="member-gfsessiontracerecipe-properties-max_event_buffer_bytes"></a>

### `max_event_buffer_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_event_buffer_bytes: int = 1024 * 1024
```

全局内存事件缓冲字节预算。

<a id="member-gfsessiontracerecipe-properties-max_event_bytes"></a>

### `max_event_bytes`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var max_event_bytes: int = 16 * 1024
```

全局单事件字节预算。

<a id="member-gfsessiontracerecipe-properties-redaction_profile"></a>

### `redaction_profile`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var redaction_profile: String = GFReportValueCodec.REDACTION_PROFILE_PRIVACY
```

事件和单次 metadata 使用的脱敏 profile。

<a id="member-gfsessiontracerecipe-properties-channels"></a>

### `channels`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var channels: Array[GFSessionTraceChannelDefinition] = []
```

配方声明的事件通道。

<a id="member-gfsessiontracerecipe-properties-checkpoints"></a>

### `checkpoints`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var checkpoints: Array[GFSessionTraceCheckpoint] = []
```

配方声明的显式采集检查点。

<a id="member-gfsessiontracerecipe-properties-snapshot_limit"></a>

### `snapshot_limit`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var snapshot_limit: int = 0
```

配方快照默认保留的最新事件数；0 表示不限制。

<a id="member-gfsessiontracerecipe-properties-include_context"></a>

### `include_context`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var include_context: bool = true
```

配方快照默认是否包含会话上下文。

<a id="member-gfsessiontracerecipe-properties-include_channel_catalog"></a>

### `include_channel_catalog`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var include_channel_catalog: bool = false
```

配方快照默认是否包含通道目录。

<a id="member-gfsessiontracerecipe-properties-include_provider_catalog"></a>

### `include_provider_catalog`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var include_provider_catalog: bool = false
```

配方快照默认是否包含 Provider 目录。

<a id="member-gfsessiontracerecipe-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`unreleased`

```gdscript
var metadata: Dictionary = {}
```

配方目录元数据；不自动写入会话上下文或事件。

结构：

- `metadata`: Dictionary with project-defined recipe catalog metadata.

## 方法

<a id="member-gfsessiontracerecipe-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func configure( p_recipe_id: StringName, p_channels: Array[GFSessionTraceChannelDefinition], p_checkpoints: Array[GFSessionTraceCheckpoint] = [], options: Dictionary = {} ) -> GFSessionTraceRecipe:
```

配置配方并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_recipe_id` | 稳定配方 ID。 |
| `p_channels` | 通道定义。 |
| `p_checkpoints` | 检查点定义。 |
| `options` | 容量、脱敏与快照默认选项。 |

返回：当前配方。

结构：

- `options`: Dictionary with max_events, max_event_buffer_bytes, max_event_bytes, redaction_profile, snapshot_limit, include_context, include_channel_catalog, include_provider_catalog, and metadata.

<a id="member-gfsessiontracerecipe-methods-validate_recipe"></a>

### `validate_recipe`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func validate_recipe() -> Dictionary:
```

校验配方结构和引用唯一性。

返回：GFValidationReportDictionary 兼容报告。

结构：

- `return`: Dictionary with ok, issues, counts, summary, and next_actions.

<a id="member-gfsessiontracerecipe-methods-get_checkpoint"></a>

### `get_checkpoint`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func get_checkpoint(checkpoint_id: StringName) -> GFSessionTraceCheckpoint:
```

获取指定检查点。

参数：

| 名称 | 说明 |
|---|---|
| `checkpoint_id` | 检查点 ID。 |

返回：检查点；不存在时返回 null。

<a id="member-gfsessiontracerecipe-methods-to_report_dictionary"></a>

### `to_report_dictionary`

- API：`public`
- 首次版本：`unreleased`

```gdscript
func to_report_dictionary() -> Dictionary:
```

获取不含运行时回调的 JSON-safe 配方描述。

返回：配方描述。

结构：

- `return`: Dictionary with recipe identity, budgets, bounded channels and checkpoints, source counts, definitions_truncated, snapshot_options, and metadata.
