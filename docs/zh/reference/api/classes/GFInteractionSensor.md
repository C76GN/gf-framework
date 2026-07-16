# GFInteractionSensor

[API Reference](../index.md) / [Interaction](../extensions-interaction.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/interaction/nodes/gf_interaction_sensor.gd`
- 模块：`Interaction`
- 继承：`Node`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

通用交互发送节点。 负责构建 GFInteractionContext，并把交互请求发送给具备 receive_interaction() 方法的接收对象。发送者、目标、payload 和分组均保持通用，不绑定具体玩法。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`interaction_sent`](#member-gfinteractionsensor-signals-interaction_sent) | `signal interaction_sent(context: GFInteractionContext, receiver: Object, report: Dictionary)` |
| 信号 | [`interaction_accepted`](#member-gfinteractionsensor-signals-interaction_accepted) | `signal interaction_accepted(context: GFInteractionContext, receiver: Object, report: Dictionary)` |
| 信号 | [`interaction_rejected`](#member-gfinteractionsensor-signals-interaction_rejected) | `signal interaction_rejected(context: GFInteractionContext, receiver: Object, report: Dictionary)` |
| 属性 | [`enabled`](#member-gfinteractionsensor-properties-enabled) | `var enabled: bool = true` |
| 属性 | [`interaction_id`](#member-gfinteractionsensor-properties-interaction_id) | `var interaction_id: StringName = &""` |
| 属性 | [`group_name`](#member-gfinteractionsensor-properties-group_name) | `var group_name: StringName = &""` |
| 属性 | [`payload`](#member-gfinteractionsensor-properties-payload) | `var payload: Dictionary = {}` |
| 属性 | [`metadata`](#member-gfinteractionsensor-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`sender_path`](#member-gfinteractionsensor-properties-sender_path) | `var sender_path: NodePath = NodePath("")` |
| 方法 | [`build_context`](#member-gfinteractionsensor-methods-build_context) | `func build_context( target: Object = null, payload_override: Variant = null, group_override: StringName = &"" ) -> GFInteractionContext:` |
| 方法 | [`send_to`](#member-gfinteractionsensor-methods-send_to) | `func send_to( receiver: Object, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Dictionary:` |
| 方法 | [`send_to_path`](#member-gfinteractionsensor-methods-send_to_path) | `func send_to_path( receiver_path: NodePath, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Dictionary:` |
| 方法 | [`broadcast_to_group`](#member-gfinteractionsensor-methods-broadcast_to_group) | `func broadcast_to_group(target_group_name: StringName = &"", max_count: int = 0) -> Array[Dictionary]:` |
| 方法 | [`send_to_best_candidate`](#member-gfinteractionsensor-methods-send_to_best_candidate) | `func send_to_best_candidate( candidate_provider: Object, options: Dictionary = {}, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Dictionary:` |
| 方法 | [`broadcast_to_candidates`](#member-gfinteractionsensor-methods-broadcast_to_candidates) | `func broadcast_to_candidates( candidate_provider: Object, options: Dictionary = {}, max_count: int = 0, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Array[Dictionary]:` |
| 方法 | [`send_to_raycast_2d`](#member-gfinteractionsensor-methods-send_to_raycast_2d) | `func send_to_raycast_2d( raycast: RayCast2D, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Dictionary:` |
| 方法 | [`send_to_raycast_3d`](#member-gfinteractionsensor-methods-send_to_raycast_3d) | `func send_to_raycast_3d( raycast: RayCast3D, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Dictionary:` |
| 方法 | [`broadcast_to_area_2d`](#member-gfinteractionsensor-methods-broadcast_to_area_2d) | `func broadcast_to_area_2d( area: Area2D, max_count: int = 0, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Array[Dictionary]:` |
| 方法 | [`broadcast_to_area_3d`](#member-gfinteractionsensor-methods-broadcast_to_area_3d) | `func broadcast_to_area_3d( area: Area3D, max_count: int = 0, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Array[Dictionary]:` |

## 信号

<a id="member-gfinteractionsensor-signals-interaction_sent"></a>

### `interaction_sent`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal interaction_sent(context: GFInteractionContext, receiver: Object, report: Dictionary)
```

交互已发送。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `receiver` | 接收对象。 |
| `report` | 结果报告。 |

结构：

- `report`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionsensor-signals-interaction_accepted"></a>

### `interaction_accepted`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal interaction_accepted(context: GFInteractionContext, receiver: Object, report: Dictionary)
```

交互被接收对象接受。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `receiver` | 接收对象。 |
| `report` | 结果报告。 |

结构：

- `report`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionsensor-signals-interaction_rejected"></a>

### `interaction_rejected`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal interaction_rejected(context: GFInteractionContext, receiver: Object, report: Dictionary)
```

交互被接收对象拒绝或发送失败。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 交互上下文。 |
| `receiver` | 接收对象。 |
| `report` | 结果报告。 |

结构：

- `report`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

## 属性

<a id="member-gfinteractionsensor-properties-enabled"></a>

### `enabled`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var enabled: bool = true
```

是否允许发送交互。

<a id="member-gfinteractionsensor-properties-interaction_id"></a>

### `interaction_id`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var interaction_id: StringName = &""
```

默认交互 ID。

<a id="member-gfinteractionsensor-properties-group_name"></a>

### `group_name`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var group_name: StringName = &""
```

默认交互分组。

<a id="member-gfinteractionsensor-properties-payload"></a>

### `payload`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var payload: Dictionary = {}
```

默认 payload；发送时会深拷贝。

结构：

- `payload`: 默认交互载荷 Dictionary；发送时会复制，项目可定义其中键值。

<a id="member-gfinteractionsensor-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var metadata: Dictionary = {}
```

发送器自定义元数据。框架不解释该字段。

结构：

- `metadata`: 发送器自定义元数据 Dictionary；框架会复制到结果报告，但不解释其中键值。

<a id="member-gfinteractionsensor-properties-sender_path"></a>

### `sender_path`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var sender_path: NodePath = NodePath("")
```

可选发送者路径；为空时使用当前节点。

## 方法

<a id="member-gfinteractionsensor-methods-build_context"></a>

### `build_context`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func build_context( target: Object = null, payload_override: Variant = null, group_override: StringName = &"" ) -> GFInteractionContext:
```

构建交互上下文。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 交互目标。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `group_override` | 覆盖分组；为空时使用节点默认分组。 |

返回：交互上下文。

结构：

- `payload_override`: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。

<a id="member-gfinteractionsensor-methods-send_to"></a>

### `send_to`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func send_to( receiver: Object, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Dictionary:
```

向指定接收对象发送交互。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收对象。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `interaction_id_override` | 覆盖交互 ID；为空时使用节点默认交互 ID。 |

返回：统一结果报告。

结构：

- `payload_override`: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
- `return`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionsensor-methods-send_to_path"></a>

### `send_to_path`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func send_to_path( receiver_path: NodePath, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Dictionary:
```

向指定节点路径发送交互。

参数：

| 名称 | 说明 |
|---|---|
| `receiver_path` | 接收节点路径。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `interaction_id_override` | 覆盖交互 ID；为空时使用节点默认交互 ID。 |

返回：统一结果报告。

结构：

- `payload_override`: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
- `return`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionsensor-methods-broadcast_to_group"></a>

### `broadcast_to_group`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func broadcast_to_group(target_group_name: StringName = &"", max_count: int = 0) -> Array[Dictionary]:
```

向场景树分组中的接收对象广播交互。

参数：

| 名称 | 说明 |
|---|---|
| `target_group_name` | 目标分组；为空时使用节点默认分组。 |
| `max_count` | 最多发送数量；小于等于 0 表示不限制。 |

返回：结果报告列表。

结构：

- `return`: 交互结果报告字典数组；每项包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionsensor-methods-send_to_best_candidate"></a>

### `send_to_best_candidate`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func send_to_best_candidate( candidate_provider: Object, options: Dictionary = {}, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Dictionary:
```

向候选 provider 返回的最佳接收对象发送交互。

参数：

| 名称 | 说明 |
|---|---|
| `candidate_provider` | 暴露 get_candidate_objects(options) 的候选 provider。 |
| `options` | 候选查询选项；未设置 method_name 时默认筛选 receive_interaction。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `interaction_id_override` | 覆盖交互 ID；为空时使用节点默认交互 ID。 |

返回：统一结果报告。

结构：

- `options`: Dictionary passed to candidate_provider.get_candidate_objects(); method_name defaults to receive_interaction.
- `payload_override`: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
- `return`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionsensor-methods-broadcast_to_candidates"></a>

### `broadcast_to_candidates`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
func broadcast_to_candidates( candidate_provider: Object, options: Dictionary = {}, max_count: int = 0, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Array[Dictionary]:
```

向候选 provider 返回的接收对象广播交互。

参数：

| 名称 | 说明 |
|---|---|
| `candidate_provider` | 暴露 get_candidate_objects(options) 的候选 provider。 |
| `options` | 候选查询选项；未设置 method_name 时默认筛选 receive_interaction。 |
| `max_count` | 最多发送数量；小于等于 0 表示不限制。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `interaction_id_override` | 覆盖交互 ID；为空时使用节点默认交互 ID。 |

返回：结果报告列表。

结构：

- `options`: Dictionary passed to candidate_provider.get_candidate_objects(); method_name defaults to receive_interaction.
- `payload_override`: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
- `return`: 交互结果报告字典数组；每项包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionsensor-methods-send_to_raycast_2d"></a>

### `send_to_raycast_2d`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func send_to_raycast_2d( raycast: RayCast2D, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Dictionary:
```

向 RayCast2D 当前命中的接收对象发送交互。

参数：

| 名称 | 说明 |
|---|---|
| `raycast` | RayCast2D 节点。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `interaction_id_override` | 覆盖交互 ID；为空时使用节点默认交互 ID。 |

返回：统一结果报告。

结构：

- `payload_override`: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
- `return`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionsensor-methods-send_to_raycast_3d"></a>

### `send_to_raycast_3d`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func send_to_raycast_3d( raycast: RayCast3D, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Dictionary:
```

向 RayCast3D 当前命中的接收对象发送交互。

参数：

| 名称 | 说明 |
|---|---|
| `raycast` | RayCast3D 节点。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `interaction_id_override` | 覆盖交互 ID；为空时使用节点默认交互 ID。 |

返回：统一结果报告。

结构：

- `payload_override`: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
- `return`: 交互结果报告 Dictionary，包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionsensor-methods-broadcast_to_area_2d"></a>

### `broadcast_to_area_2d`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func broadcast_to_area_2d( area: Area2D, max_count: int = 0, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Array[Dictionary]:
```

向 Area2D 当前重叠的接收对象批量发送交互。

参数：

| 名称 | 说明 |
|---|---|
| `area` | Area2D 节点。 |
| `max_count` | 最多发送数量；小于等于 0 表示不限制。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `interaction_id_override` | 覆盖交互 ID；为空时使用节点默认交互 ID。 |

返回：结果报告列表。

结构：

- `payload_override`: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
- `return`: 交互结果报告字典数组；每项包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。

<a id="member-gfinteractionsensor-methods-broadcast_to_area_3d"></a>

### `broadcast_to_area_3d`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func broadcast_to_area_3d( area: Area3D, max_count: int = 0, payload_override: Variant = null, interaction_id_override: StringName = &"" ) -> Array[Dictionary]:
```

向 Area3D 当前重叠的接收对象批量发送交互。

参数：

| 名称 | 说明 |
|---|---|
| `area` | Area3D 节点。 |
| `max_count` | 最多发送数量；小于等于 0 表示不限制。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `interaction_id_override` | 覆盖交互 ID；为空时使用节点默认交互 ID。 |

返回：结果报告列表。

结构：

- `payload_override`: 覆盖默认 payload 的任意项目载荷；为 null 时复制节点默认 payload。
- `return`: 交互结果报告字典数组；每项包含 ok、interaction_id、receiver(JSON-safe 摘要)、reason、message 和 metadata 等字段。
