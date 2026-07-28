# GFSessionTraceCheckpoint

[API Reference](../index.md) / [Standard](../standard.md) / [类索引](index.md)

- 路径：`addons/gf/standard/utilities/debug/gf_session_trace_checkpoint.gd`
- 模块：`Standard`
- 继承：`Resource`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`10.0.0`

Session Trace 配方中的显式 Provider 采集点。 检查点只引用已经在运行时注册的 Provider ID，单个列表最多包含 256 项。 默认所有 Provider 都是必需项；`optional_provider_ids` 可把部分失败降级为 可观察但不阻断检查点的结果。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`checkpoint_id`](#member-gfsessiontracecheckpoint-properties-checkpoint_id) | `var checkpoint_id: StringName = &""` |
| 属性 | [`provider_ids`](#member-gfsessiontracecheckpoint-properties-provider_ids) | `var provider_ids: PackedStringArray = PackedStringArray()` |
| 属性 | [`optional_provider_ids`](#member-gfsessiontracecheckpoint-properties-optional_provider_ids) | `var optional_provider_ids: PackedStringArray = PackedStringArray()` |
| 属性 | [`metadata`](#member-gfsessiontracecheckpoint-properties-metadata) | `var metadata: Dictionary = {}` |
| 方法 | [`configure`](#member-gfsessiontracecheckpoint-methods-configure) | `func configure( p_checkpoint_id: StringName, p_provider_ids: PackedStringArray, options: Dictionary = {} ) -> GFSessionTraceCheckpoint:` |
| 方法 | [`validate_checkpoint`](#member-gfsessiontracecheckpoint-methods-validate_checkpoint) | `func validate_checkpoint() -> Dictionary:` |

## 属性

<a id="member-gfsessiontracecheckpoint-properties-checkpoint_id"></a>

### `checkpoint_id`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var checkpoint_id: StringName = &""
```

稳定检查点 ID。

<a id="member-gfsessiontracecheckpoint-properties-provider_ids"></a>

### `provider_ids`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var provider_ids: PackedStringArray = PackedStringArray()
```

按顺序显式采集的 Provider ID。

<a id="member-gfsessiontracecheckpoint-properties-optional_provider_ids"></a>

### `optional_provider_ids`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var optional_provider_ids: PackedStringArray = PackedStringArray()
```

允许失败而不让检查点整体失败的 Provider ID，必须是 `provider_ids` 子集。

<a id="member-gfsessiontracecheckpoint-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
var metadata: Dictionary = {}
```

合并进每次 Provider 事件的检查点元数据。

结构：

- `metadata`: Dictionary with project-defined checkpoint metadata.

## 方法

<a id="member-gfsessiontracecheckpoint-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func configure( p_checkpoint_id: StringName, p_provider_ids: PackedStringArray, options: Dictionary = {} ) -> GFSessionTraceCheckpoint:
```

配置检查点并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_checkpoint_id` | 稳定检查点 ID。 |
| `p_provider_ids` | 按顺序采集的 Provider ID。 |
| `options` | 检查点选项。 |

返回：当前检查点。

结构：

- `options`: Dictionary with optional_provider_ids and metadata.

<a id="member-gfsessiontracecheckpoint-methods-validate_checkpoint"></a>

### `validate_checkpoint`

- API：`public`
- 首次版本：`10.0.0`

```gdscript
func validate_checkpoint() -> Dictionary:
```

校验检查点定义。

返回：GFValidationReportDictionary 兼容报告。

结构：

- `return`: Dictionary with ok, issues, counts, summary, and next_actions.
