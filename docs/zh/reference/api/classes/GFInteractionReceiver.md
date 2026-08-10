# GFInteractionReceiver

[API Reference](../index.md) / [Interaction](../extensions-interaction.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/interaction/nodes/gf_interaction_receiver.gd`
- 模块：`Interaction`
- 继承：`Node`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用交互接收节点。 用 GFInteractionContext 接收任意交互请求，并提供启用状态、交互 ID 过滤、 自定义校验回调和统一结果报告。节点不解释任何业务语义。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`interaction_validating`](#member-gfinteractionreceiver-signals-interaction_validating) | `signal interaction_validating(context: GFInteractionContext, report: Dictionary)` |
| 信号 | [`interaction_received`](#member-gfinteractionreceiver-signals-interaction_received) | `signal interaction_received(context: GFInteractionContext, report: Dictionary)` |
| 信号 | [`interaction_rejected`](#member-gfinteractionreceiver-signals-interaction_rejected) | `signal interaction_rejected(context: GFInteractionContext, report: Dictionary)` |
| 属性 | [`enabled`](#member-gfinteractionreceiver-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`accepted_interaction_ids`](#member-gfinteractionreceiver-properties-accepted_interaction_ids) | `var accepted_interaction_ids: Array[StringName] = []` |
| 属性 | [`rejected_interaction_ids`](#member-gfinteractionreceiver-properties-rejected_interaction_ids) | `var rejected_interaction_ids: Array[StringName] = []` |
| 属性 | [`metadata`](#member-gfinteractionreceiver-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`receiver_path`](#member-gfinteractionreceiver-properties-receiver_path) | `var receiver_path: NodePath = NodePath("")` |
| 属性 | [`validation_callback`](#member-gfinteractionreceiver-properties-validation_callback) | `var validation_callback: Callable = Callable()` |
| 方法 | [`can_receive_interaction`](#member-gfinteractionreceiver-methods-can_receive_interaction) | `func can_receive_interaction(interaction_id: StringName = &"") -> bool:` |
| 方法 | [`receive_interaction`](#member-gfinteractionreceiver-methods-receive_interaction) | `func receive_interaction(context: GFInteractionContext, interaction_id: StringName = &"") -> Dictionary:` |

## 信号

<a id="member-gfinteractionreceiver-signals-interaction_validating"></a>

### `interaction_validating`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal interaction_validating(context: GFInteractionContext, report: Dictionary)
```

交互进入自定义校验阶段时发出。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `report` | 当前结果报告副本。 |

结构：

- `report`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionreceiver-signals-interaction_received"></a>

### `interaction_received`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal interaction_received(context: GFInteractionContext, report: Dictionary)
```

交互被接受时发出。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `report` | 结果报告。 |

结构：

- `report`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionreceiver-signals-interaction_rejected"></a>

### `interaction_rejected`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal interaction_rejected(context: GFInteractionContext, report: Dictionary)
```

交互被拒绝时发出。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `report` | 结果报告。 |

结构：

- `report`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

## 属性

<a id="member-gfinteractionreceiver-properties-enabled"></a>

### `enabled`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var enabled: bool = true
```

是否允许接收交互。

<a id="member-gfinteractionreceiver-properties-accepted_interaction_ids"></a>

### `accepted_interaction_ids`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var accepted_interaction_ids: Array[StringName] = []
```

非空时，只接受这些交互 ID。

<a id="member-gfinteractionreceiver-properties-rejected_interaction_ids"></a>

### `rejected_interaction_ids`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var rejected_interaction_ids: Array[StringName] = []
```

始终拒绝的交互 ID。

<a id="member-gfinteractionreceiver-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var metadata: Dictionary = {}
```

接收器自定义元数据。框架不解释该字段。

结构：

- `metadata`: 接收器自定义元数据 Dictionary；框架会复制到结果报告，但不解释其中键值。

<a id="member-gfinteractionreceiver-properties-receiver_path"></a>

### `receiver_path`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var receiver_path: NodePath = NodePath("")
```

可选业务接收节点路径；为空时由当前节点直接接收。

<a id="member-gfinteractionreceiver-properties-validation_callback"></a>

### `validation_callback`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var validation_callback: Callable = Callable()
```

自定义校验回调，建议签名为 func(context: GFInteractionContext, report: Dictionary) -> Variant。 返回 bool 可直接决定是否接受；返回 Dictionary 可覆盖 ok、reason、metadata 等报告字段。 非空回调的 owner 失效时会以 invalid_validator 失败关闭；主动恢复无校验状态必须显式赋值 Callable()。

## 方法

<a id="member-gfinteractionreceiver-methods-can_receive_interaction"></a>

### `can_receive_interaction`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func can_receive_interaction(interaction_id: StringName = &"") -> bool:
```

检查指定交互 ID 是否可被当前接收器接受。

参数：

| 名称 | 说明 |
|---|---|
| `interaction_id` | 交互 ID。 |

返回：可接受时返回 true。

<a id="member-gfinteractionreceiver-methods-receive_interaction"></a>

### `receive_interaction`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func receive_interaction(context: GFInteractionContext, interaction_id: StringName = &"") -> Dictionary:
```

接收一次交互。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `interaction_id` | 交互 ID。 |

返回：统一结果报告。

结构：

- `return`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
