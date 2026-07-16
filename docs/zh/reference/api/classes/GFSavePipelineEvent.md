# GFSavePipelineEvent

[API Reference](../index.md) / [Save](../extensions-save.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/save/pipeline/gf_save_pipeline_event.gd`
- 模块：`Save`
- 继承：`RefCounted`
- API：`public`
- 类别：事件契约 (`event_contract`)
- 首次版本：`3.17.0`

存档图流程事件。 用于描述 GFSaveGraphUtility 在采集/应用过程中的通用阶段、Scope、Source 与诊断信息。事件本身不携带业务字段，项目层可通过 payload 扩展。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`stage`](#member-gfsavepipelineevent-properties-stage) | `var stage: StringName = &""` |
| 属性 | [`severity`](#member-gfsavepipelineevent-properties-severity) | `var severity: StringName = &"info"` |
| 属性 | [`scope_key`](#member-gfsavepipelineevent-properties-scope_key) | `var scope_key: StringName = &""` |
| 属性 | [`source_key`](#member-gfsavepipelineevent-properties-source_key) | `var source_key: StringName = &""` |
| 属性 | [`node_path`](#member-gfsavepipelineevent-properties-node_path) | `var node_path: String = ""` |
| 属性 | [`message`](#member-gfsavepipelineevent-properties-message) | `var message: String = ""` |
| 属性 | [`payload`](#member-gfsavepipelineevent-properties-payload) | `var payload: Dictionary = {}` |
| 属性 | [`timestamp_msec`](#member-gfsavepipelineevent-properties-timestamp_msec) | `var timestamp_msec: int = 0` |
| 方法 | [`configure`](#member-gfsavepipelineevent-methods-configure) | `func configure( p_stage: StringName, scope: Object = null, source: Object = null, p_message: String = "", p_payload: Dictionary = {}, p_severity: StringName = &"info" ) -> GFSavePipelineEvent:` |
| 方法 | [`to_dict`](#member-gfsavepipelineevent-methods-to_dict) | `func to_dict() -> Dictionary:` |
| 方法 | [`from_dict`](#member-gfsavepipelineevent-methods-from_dict) | `static func from_dict(data: Dictionary) -> GFSavePipelineEvent:` |

## 属性

<a id="member-gfsavepipelineevent-properties-stage"></a>

### `stage`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var stage: StringName = &""
```

流程阶段标识。

<a id="member-gfsavepipelineevent-properties-severity"></a>

### `severity`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var severity: StringName = &"info"
```

事件严重级别，建议使用 info/warning/error。

<a id="member-gfsavepipelineevent-properties-scope_key"></a>

### `scope_key`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var scope_key: StringName = &""
```

事件关联的作用域键。

<a id="member-gfsavepipelineevent-properties-source_key"></a>

### `source_key`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var source_key: StringName = &""
```

事件关联的来源键。

<a id="member-gfsavepipelineevent-properties-node_path"></a>

### `node_path`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var node_path: String = ""
```

事件关联节点路径。

<a id="member-gfsavepipelineevent-properties-message"></a>

### `message`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var message: String = ""
```

面向调试的短消息。

<a id="member-gfsavepipelineevent-properties-payload"></a>

### `payload`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var payload: Dictionary = {}
```

附加通用载荷。

结构：

- `payload`: Dictionary，项目或流程步骤附加的诊断字段。

<a id="member-gfsavepipelineevent-properties-timestamp_msec"></a>

### `timestamp_msec`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var timestamp_msec: int = 0
```

事件创建时间。

## 方法

<a id="member-gfsavepipelineevent-methods-configure"></a>

### `configure`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func configure( p_stage: StringName, scope: Object = null, source: Object = null, p_message: String = "", p_payload: Dictionary = {}, p_severity: StringName = &"info" ) -> GFSavePipelineEvent:
```

配置事件内容并返回自身。

参数：

| 名称 | 说明 |
|---|---|
| `p_stage` | 流程阶段。 |
| `scope` | 可选 Scope 或节点对象。 |
| `source` | 可选 Source 或节点对象。 |
| `p_message` | 调试消息。 |
| `p_payload` | 附加载荷。 |
| `p_severity` | 严重级别。 |

返回：当前事件。

结构：

- `p_payload`: Dictionary，项目或流程步骤附加的诊断字段。

<a id="member-gfsavepipelineevent-methods-to_dict"></a>

### `to_dict`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func to_dict() -> Dictionary:
```

转换为 Dictionary，便于日志、存档或测试断言。

返回：事件字典。

结构：

- `return`: Dictionary，包含 stage、severity、scope_key、source_key、node_path、message、JSON-safe payload 与 timestamp_msec。

<a id="member-gfsavepipelineevent-methods-from_dict"></a>

### `from_dict`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
static func from_dict(data: Dictionary) -> GFSavePipelineEvent:
```

从 Dictionary 恢复事件。

参数：

| 名称 | 说明 |
|---|---|
| `data` | 事件字典。 |

返回：新事件。

结构：

- `data`: Dictionary，可包含 stage、severity、scope_key、source_key、node_path、message、payload 与 timestamp_msec。
