# GFHitBox2D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/hit_detection/gf_hit_box_2d.gd`
- 模块：`Combat`
- 继承：`Area2D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

2D 通用命中发送区域。 节点负责构建 GFCombatHitContext 并发送给具备 receive_hit() 的接收对象， 不规定伤害、阵营、冷却、命中特效或生命值规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`hit_sent`](#member-gfhitbox2d-signals-hit_sent) | `signal hit_sent(context: GFCombatHitContext, receiver: Object, report: Dictionary)` |
| 信号 | [`hit_accepted`](#member-gfhitbox2d-signals-hit_accepted) | `signal hit_accepted(context: GFCombatHitContext, receiver: Object, report: Dictionary)` |
| 信号 | [`hit_rejected`](#member-gfhitbox2d-signals-hit_rejected) | `signal hit_rejected(context: GFCombatHitContext, receiver: Object, report: Dictionary)` |
| 信号 | [`enabled_changed`](#member-gfhitbox2d-signals-enabled_changed) | `signal enabled_changed(enabled: bool)` |
| 属性 | [`enabled`](#member-gfhitbox2d-properties-enabled) | `var enabled: bool = true:` |
| 属性 | [`hit_id`](#member-gfhitbox2d-properties-hit_id) | `var hit_id: StringName = &""` |
| 属性 | [`payload`](#member-gfhitbox2d-properties-payload) | `var payload: Dictionary = {}` |
| 属性 | [`magnitude`](#member-gfhitbox2d-properties-magnitude) | `var magnitude: float = 0.0` |
| 属性 | [`tags`](#member-gfhitbox2d-properties-tags) | `var tags: Array[StringName] = []` |
| 属性 | [`metadata`](#member-gfhitbox2d-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`sender_path`](#member-gfhitbox2d-properties-sender_path) | `var sender_path: NodePath = NodePath("")` |
| 属性 | [`collision_shape_config`](#member-gfhitbox2d-properties-collision_shape_config) | `var collision_shape_config: GFHitCollisionShapeConfig2D = null:` |
| 属性 | [`collision_shape_configs`](#member-gfhitbox2d-properties-collision_shape_configs) | `var collision_shape_configs: Array[GFHitCollisionShapeConfig2D] = []:` |
| 属性 | [`auto_apply_collision_shape_config`](#member-gfhitbox2d-properties-auto_apply_collision_shape_config) | `var auto_apply_collision_shape_config: bool = true` |
| 方法 | [`apply_collision_shape_config`](#member-gfhitbox2d-methods-apply_collision_shape_config) | `func apply_collision_shape_config(config: GFHitCollisionShapeConfig2D = null) -> CollisionShape2D:` |
| 方法 | [`apply_collision_shape_configs`](#member-gfhitbox2d-methods-apply_collision_shape_configs) | `func apply_collision_shape_configs(configs: Array[GFHitCollisionShapeConfig2D] = []) -> Array[CollisionShape2D]:` |
| 方法 | [`get_generated_collision_shape`](#member-gfhitbox2d-methods-get_generated_collision_shape) | `func get_generated_collision_shape() -> CollisionShape2D:` |
| 方法 | [`get_generated_collision_shapes`](#member-gfhitbox2d-methods-get_generated_collision_shapes) | `func get_generated_collision_shapes() -> Array[CollisionShape2D]:` |
| 方法 | [`clear_generated_collision_shape`](#member-gfhitbox2d-methods-clear_generated_collision_shape) | `func clear_generated_collision_shape() -> void:` |
| 方法 | [`clear_generated_collision_shapes`](#member-gfhitbox2d-methods-clear_generated_collision_shapes) | `func clear_generated_collision_shapes() -> void:` |
| 方法 | [`build_hit_context`](#member-gfhitbox2d-methods-build_hit_context) | `func build_hit_context( target: Object = null, payload_override: Variant = null, hit_id_override: StringName = &"" ) -> GFCombatHitContext:` |
| 方法 | [`send_to`](#member-gfhitbox2d-methods-send_to) | `func send_to( receiver: Object, payload_override: Variant = null, hit_id_override: StringName = &"" ) -> Dictionary:` |
| 方法 | [`send_to_path`](#member-gfhitbox2d-methods-send_to_path) | `func send_to_path( receiver_path: NodePath, payload_override: Variant = null, hit_id_override: StringName = &"" ) -> Dictionary:` |
| 方法 | [`broadcast_overlaps`](#member-gfhitbox2d-methods-broadcast_overlaps) | `func broadcast_overlaps( max_count: int = 0, payload_override: Variant = null, hit_id_override: StringName = &"" ) -> Array[Dictionary]:` |

## 信号

<a id="member-gfhitbox2d-signals-hit_sent"></a>

### `hit_sent`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal hit_sent(context: GFCombatHitContext, receiver: Object, report: Dictionary)
```

命中已发送。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 命中上下文。 |
| `receiver` | 接收对象。 |
| `report` | 结果报告。 |

结构：

- `report`: Dictionary，统一命中发送结果，包含 ok、hit_id、receiver(JSON-safe 摘要)、reason、message 和 metadata。

<a id="member-gfhitbox2d-signals-hit_accepted"></a>

### `hit_accepted`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal hit_accepted(context: GFCombatHitContext, receiver: Object, report: Dictionary)
```

命中被接收对象接受。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 命中上下文。 |
| `receiver` | 接收对象。 |
| `report` | 结果报告。 |

结构：

- `report`: Dictionary，统一命中发送结果，包含 ok、hit_id、receiver(JSON-safe 摘要)、reason、message 和 metadata。

<a id="member-gfhitbox2d-signals-hit_rejected"></a>

### `hit_rejected`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal hit_rejected(context: GFCombatHitContext, receiver: Object, report: Dictionary)
```

命中被接收对象拒绝或发送失败。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 命中上下文。 |
| `receiver` | 接收对象。 |
| `report` | 结果报告。 |

结构：

- `report`: Dictionary，统一命中发送结果，包含 ok、hit_id、receiver(JSON-safe 摘要)、reason、message 和 metadata。

<a id="member-gfhitbox2d-signals-enabled_changed"></a>

### `enabled_changed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
signal enabled_changed(enabled: bool)
```

启用状态变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `enabled` | 当前是否允许发送命中。 |

## 属性

<a id="member-gfhitbox2d-properties-enabled"></a>

### `enabled`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var enabled: bool = true:
```

是否允许发送命中。

<a id="member-gfhitbox2d-properties-hit_id"></a>

### `hit_id`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var hit_id: StringName = &""
```

默认命中 ID。

<a id="member-gfhitbox2d-properties-payload"></a>

### `payload`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var payload: Dictionary = {}
```

默认 payload；发送时会深拷贝。

结构：

- `payload`: Dictionary，默认命中载荷；框架只复制并透传。

<a id="member-gfhitbox2d-properties-magnitude"></a>

### `magnitude`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var magnitude: float = 0.0
```

通用强度值。框架不解释该字段。

<a id="member-gfhitbox2d-properties-tags"></a>

### `tags`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var tags: Array[StringName] = []
```

命中标签。框架不解释该字段。

<a id="member-gfhitbox2d-properties-metadata"></a>

### `metadata`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var metadata: Dictionary = {}
```

发送器自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，发送器自定义命中元数据；会进入命中上下文和结果报告。

<a id="member-gfhitbox2d-properties-sender_path"></a>

### `sender_path`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var sender_path: NodePath = NodePath("")
```

可选发送者路径；为空时使用当前节点。

<a id="member-gfhitbox2d-properties-collision_shape_config"></a>

### `collision_shape_config`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var collision_shape_config: GFHitCollisionShapeConfig2D = null:
```

可选碰撞形状配置。设置后可自动生成或更新 CollisionShape2D 子节点。

<a id="member-gfhitbox2d-properties-collision_shape_configs"></a>

### `collision_shape_configs`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var collision_shape_configs: Array[GFHitCollisionShapeConfig2D] = []:
```

可选碰撞形状配置列表。非空时可自动生成或更新多个 CollisionShape2D 子节点。

<a id="member-gfhitbox2d-properties-auto_apply_collision_shape_config"></a>

### `auto_apply_collision_shape_config`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var auto_apply_collision_shape_config: bool = true
```

是否在进入场景树或配置变化时自动应用碰撞形状配置。

## 方法

<a id="member-gfhitbox2d-methods-apply_collision_shape_config"></a>

### `apply_collision_shape_config`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func apply_collision_shape_config(config: GFHitCollisionShapeConfig2D = null) -> CollisionShape2D:
```

应用碰撞形状配置，创建或更新框架管理的 CollisionShape2D 子节点。

参数：

| 名称 | 说明 |
|---|---|
| `config` | 可选配置；为空时使用 collision_shape_config。 |

返回：创建或更新的 CollisionShape2D；配置无效时返回 null。

<a id="member-gfhitbox2d-methods-apply_collision_shape_configs"></a>

### `apply_collision_shape_configs`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func apply_collision_shape_configs(configs: Array[GFHitCollisionShapeConfig2D] = []) -> Array[CollisionShape2D]:
```

应用碰撞形状配置列表，创建或更新框架管理的多个 CollisionShape2D 子节点。

参数：

| 名称 | 说明 |
|---|---|
| `configs` | 可选配置列表；为空时使用 collision_shape_configs。 |

返回：创建或更新的 CollisionShape2D 列表。

<a id="member-gfhitbox2d-methods-get_generated_collision_shape"></a>

### `get_generated_collision_shape`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_generated_collision_shape() -> CollisionShape2D:
```

获取框架管理的 CollisionShape2D 子节点。

返回：存在则返回 CollisionShape2D，否则返回 null。

<a id="member-gfhitbox2d-methods-get_generated_collision_shapes"></a>

### `get_generated_collision_shapes`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func get_generated_collision_shapes() -> Array[CollisionShape2D]:
```

获取框架管理的 CollisionShape2D 子节点列表。

返回：已生成的 CollisionShape2D 列表。

<a id="member-gfhitbox2d-methods-clear_generated_collision_shape"></a>

### `clear_generated_collision_shape`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear_generated_collision_shape() -> void:
```

移除框架管理的 CollisionShape2D 子节点。

<a id="member-gfhitbox2d-methods-clear_generated_collision_shapes"></a>

### `clear_generated_collision_shapes`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func clear_generated_collision_shapes() -> void:
```

移除框架管理的全部 CollisionShape2D 子节点。

<a id="member-gfhitbox2d-methods-build_hit_context"></a>

### `build_hit_context`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func build_hit_context( target: Object = null, payload_override: Variant = null, hit_id_override: StringName = &"" ) -> GFCombatHitContext:
```

构建命中上下文。

参数：

| 名称 | 说明 |
|---|---|
| `target` | 命中目标。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `hit_id_override` | 覆盖命中 ID；为空时使用节点默认命中 ID。 |

返回：命中上下文。

结构：

- `payload_override`: Variant，可为 null、Dictionary 或项目自定义命中载荷；为 null 时使用节点默认 payload。

<a id="member-gfhitbox2d-methods-send_to"></a>

### `send_to`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func send_to( receiver: Object, payload_override: Variant = null, hit_id_override: StringName = &"" ) -> Dictionary:
```

向指定接收对象发送命中。

参数：

| 名称 | 说明 |
|---|---|
| `receiver` | 接收对象。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `hit_id_override` | 覆盖命中 ID；为空时使用节点默认命中 ID。 |

返回：统一结果报告。

结构：

- `payload_override`: Variant，可为 null、Dictionary 或项目自定义命中载荷；为 null 时使用节点默认 payload。
- `return`: Dictionary，统一命中发送结果，包含 ok、hit_id、receiver(JSON-safe 摘要)、reason、message 和 metadata。

<a id="member-gfhitbox2d-methods-send_to_path"></a>

### `send_to_path`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func send_to_path( receiver_path: NodePath, payload_override: Variant = null, hit_id_override: StringName = &"" ) -> Dictionary:
```

向指定节点路径发送命中。

参数：

| 名称 | 说明 |
|---|---|
| `receiver_path` | 接收节点路径。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `hit_id_override` | 覆盖命中 ID；为空时使用节点默认命中 ID。 |

返回：统一结果报告。

结构：

- `payload_override`: Variant，可为 null、Dictionary 或项目自定义命中载荷；为 null 时使用节点默认 payload。
- `return`: Dictionary，统一命中发送结果，包含 ok、hit_id、receiver(JSON-safe 摘要)、reason、message 和 metadata。

<a id="member-gfhitbox2d-methods-broadcast_overlaps"></a>

### `broadcast_overlaps`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
func broadcast_overlaps( max_count: int = 0, payload_override: Variant = null, hit_id_override: StringName = &"" ) -> Array[Dictionary]:
```

向当前重叠对象中的命中接收器批量发送命中。

参数：

| 名称 | 说明 |
|---|---|
| `max_count` | 最多发送数量；小于等于 0 表示不限制。 |
| `payload_override` | 覆盖 payload；为 null 时使用节点默认 payload。 |
| `hit_id_override` | 覆盖命中 ID；为空时使用节点默认命中 ID。 |

返回：结果报告列表。

结构：

- `payload_override`: Variant，可为 null、Dictionary 或项目自定义命中载荷；为 null 时使用节点默认 payload。
- `return`: Array[Dictionary]，每项为统一命中发送结果，包含 ok、hit_id、receiver(JSON-safe 摘要)、reason、message 和 metadata。
