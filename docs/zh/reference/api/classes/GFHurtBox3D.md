# GFHurtBox3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/hit_detection/gf_hurt_box_3d.gd`
- 模块：`Combat`
- 继承：`Area3D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

3D 通用命中接收区域。 节点只过滤和接收 GFCombatHitContext，不直接修改生命、属性或 Buff。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`hit_validating`](#member-gfhurtbox3d-signals-hit_validating) | `signal hit_validating(context: GFCombatHitContext, report: Dictionary)` |
| 信号 | [`hit_received`](#member-gfhurtbox3d-signals-hit_received) | `signal hit_received(context: GFCombatHitContext, report: Dictionary)` |
| 信号 | [`hit_rejected`](#member-gfhurtbox3d-signals-hit_rejected) | `signal hit_rejected(context: GFCombatHitContext, report: Dictionary)` |
| 信号 | [`enabled_changed`](#member-gfhurtbox3d-signals-enabled_changed) | `signal enabled_changed(enabled: bool)` |
| 属性 | [`enabled`](#member-gfhurtbox3d-properties-enabled) | `var enabled: bool = true:` |
| 属性 | [`accepted_hit_ids`](#member-gfhurtbox3d-properties-accepted_hit_ids) | `var accepted_hit_ids: Array[StringName] = []` |
| 属性 | [`rejected_hit_ids`](#member-gfhurtbox3d-properties-rejected_hit_ids) | `var rejected_hit_ids: Array[StringName] = []` |
| 属性 | [`metadata`](#member-gfhurtbox3d-properties-metadata) | `var metadata: Dictionary = {}` |
| 属性 | [`receiver_path`](#member-gfhurtbox3d-properties-receiver_path) | `var receiver_path: NodePath = NodePath("")` |
| 属性 | [`collision_shape_config`](#member-gfhurtbox3d-properties-collision_shape_config) | `var collision_shape_config: GFHitCollisionShapeConfig3D = null:` |
| 属性 | [`collision_shape_configs`](#member-gfhurtbox3d-properties-collision_shape_configs) | `var collision_shape_configs: Array[GFHitCollisionShapeConfig3D] = []:` |
| 属性 | [`auto_apply_collision_shape_config`](#member-gfhurtbox3d-properties-auto_apply_collision_shape_config) | `var auto_apply_collision_shape_config: bool = true` |
| 属性 | [`validation_callback`](#member-gfhurtbox3d-properties-validation_callback) | `var validation_callback: Callable = Callable()` |
| 方法 | [`apply_collision_shape_config`](#member-gfhurtbox3d-methods-apply_collision_shape_config) | `func apply_collision_shape_config(config: GFHitCollisionShapeConfig3D = null) -> CollisionShape3D:` |
| 方法 | [`apply_collision_shape_configs`](#member-gfhurtbox3d-methods-apply_collision_shape_configs) | `func apply_collision_shape_configs(configs: Array[GFHitCollisionShapeConfig3D] = []) -> Array[CollisionShape3D]:` |
| 方法 | [`get_generated_collision_shape`](#member-gfhurtbox3d-methods-get_generated_collision_shape) | `func get_generated_collision_shape() -> CollisionShape3D:` |
| 方法 | [`get_generated_collision_shapes`](#member-gfhurtbox3d-methods-get_generated_collision_shapes) | `func get_generated_collision_shapes() -> Array[CollisionShape3D]:` |
| 方法 | [`clear_generated_collision_shape`](#member-gfhurtbox3d-methods-clear_generated_collision_shape) | `func clear_generated_collision_shape() -> void:` |
| 方法 | [`clear_generated_collision_shapes`](#member-gfhurtbox3d-methods-clear_generated_collision_shapes) | `func clear_generated_collision_shapes() -> void:` |
| 方法 | [`can_receive_hit`](#member-gfhurtbox3d-methods-can_receive_hit) | `func can_receive_hit(p_hit_id: StringName = &"") -> bool:` |
| 方法 | [`receive_hit`](#member-gfhurtbox3d-methods-receive_hit) | `func receive_hit(context: GFCombatHitContext) -> Dictionary:` |

## 信号

<a id="member-gfhurtbox3d-signals-hit_validating"></a>

### `hit_validating`

- API：`public`

```gdscript
signal hit_validating(context: GFCombatHitContext, report: Dictionary)
```

命中进入自定义校验阶段时发出。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 命中上下文。 |
| `report` | 当前结果报告副本。 |

结构：

- `report`: Dictionary，当前命中接收报告，包含 ok、hit_id、receiver、reason、message 和 metadata。

<a id="member-gfhurtbox3d-signals-hit_received"></a>

### `hit_received`

- API：`public`

```gdscript
signal hit_received(context: GFCombatHitContext, report: Dictionary)
```

命中被接受时发出。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 命中上下文。 |
| `report` | 结果报告。 |

结构：

- `report`: Dictionary，统一命中接收报告，包含 ok、hit_id、receiver、reason、message 和 metadata。

<a id="member-gfhurtbox3d-signals-hit_rejected"></a>

### `hit_rejected`

- API：`public`

```gdscript
signal hit_rejected(context: GFCombatHitContext, report: Dictionary)
```

命中被拒绝时发出。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 命中上下文。 |
| `report` | 结果报告。 |

结构：

- `report`: Dictionary，统一命中接收报告，包含 ok、hit_id、receiver、reason、message 和 metadata。

<a id="member-gfhurtbox3d-signals-enabled_changed"></a>

### `enabled_changed`

- API：`public`

```gdscript
signal enabled_changed(enabled: bool)
```

启用状态变化时发出。

参数：

| 名称 | 说明 |
|---|---|
| `enabled` | 当前是否允许接收命中。 |

## 属性

<a id="member-gfhurtbox3d-properties-enabled"></a>

### `enabled`

- API：`public`

```gdscript
var enabled: bool = true:
```

是否允许接收命中。

<a id="member-gfhurtbox3d-properties-accepted_hit_ids"></a>

### `accepted_hit_ids`

- API：`public`

```gdscript
var accepted_hit_ids: Array[StringName] = []
```

非空时，只接受这些命中 ID。

<a id="member-gfhurtbox3d-properties-rejected_hit_ids"></a>

### `rejected_hit_ids`

- API：`public`

```gdscript
var rejected_hit_ids: Array[StringName] = []
```

始终拒绝的命中 ID。

<a id="member-gfhurtbox3d-properties-metadata"></a>

### `metadata`

- API：`public`

```gdscript
var metadata: Dictionary = {}
```

接收器自定义元数据。框架不解释该字段。

结构：

- `metadata`: Dictionary，接收器自定义命中元数据；会进入命中接收报告。

<a id="member-gfhurtbox3d-properties-receiver_path"></a>

### `receiver_path`

- API：`public`

```gdscript
var receiver_path: NodePath = NodePath("")
```

可选业务接收节点路径；为空时由当前 HurtBox 直接接收。

<a id="member-gfhurtbox3d-properties-collision_shape_config"></a>

### `collision_shape_config`

- API：`public`

```gdscript
var collision_shape_config: GFHitCollisionShapeConfig3D = null:
```

可选碰撞形状配置。设置后可自动生成或更新 CollisionShape3D 子节点。

<a id="member-gfhurtbox3d-properties-collision_shape_configs"></a>

### `collision_shape_configs`

- API：`public`

```gdscript
var collision_shape_configs: Array[GFHitCollisionShapeConfig3D] = []:
```

可选碰撞形状配置列表。非空时可自动生成或更新多个 CollisionShape3D 子节点。

<a id="member-gfhurtbox3d-properties-auto_apply_collision_shape_config"></a>

### `auto_apply_collision_shape_config`

- API：`public`

```gdscript
var auto_apply_collision_shape_config: bool = true
```

是否在进入场景树或配置变化时自动应用碰撞形状配置。

<a id="member-gfhurtbox3d-properties-validation_callback"></a>

### `validation_callback`

- API：`public`

```gdscript
var validation_callback: Callable = Callable()
```

自定义校验回调，建议签名为 func(context: GFCombatHitContext, report: Dictionary) -> Variant。 返回 bool 可直接决定是否接受；返回 Dictionary 可覆盖 ok、reason、metadata 等报告字段。

## 方法

<a id="member-gfhurtbox3d-methods-apply_collision_shape_config"></a>

### `apply_collision_shape_config`

- API：`public`

```gdscript
func apply_collision_shape_config(config: GFHitCollisionShapeConfig3D = null) -> CollisionShape3D:
```

应用碰撞形状配置，创建或更新框架管理的 CollisionShape3D 子节点。

参数：

| 名称 | 说明 |
|---|---|
| `config` | 可选配置；为空时使用 collision_shape_config。 |

返回：创建或更新的 CollisionShape3D；配置无效时返回 null。

<a id="member-gfhurtbox3d-methods-apply_collision_shape_configs"></a>

### `apply_collision_shape_configs`

- API：`public`

```gdscript
func apply_collision_shape_configs(configs: Array[GFHitCollisionShapeConfig3D] = []) -> Array[CollisionShape3D]:
```

应用碰撞形状配置列表，创建或更新框架管理的多个 CollisionShape3D 子节点。

参数：

| 名称 | 说明 |
|---|---|
| `configs` | 可选配置列表；为空时使用 collision_shape_configs。 |

返回：创建或更新的 CollisionShape3D 列表。

<a id="member-gfhurtbox3d-methods-get_generated_collision_shape"></a>

### `get_generated_collision_shape`

- API：`public`

```gdscript
func get_generated_collision_shape() -> CollisionShape3D:
```

获取框架管理的 CollisionShape3D 子节点。

返回：存在则返回 CollisionShape3D，否则返回 null。

<a id="member-gfhurtbox3d-methods-get_generated_collision_shapes"></a>

### `get_generated_collision_shapes`

- API：`public`

```gdscript
func get_generated_collision_shapes() -> Array[CollisionShape3D]:
```

获取框架管理的 CollisionShape3D 子节点列表。

返回：已生成的 CollisionShape3D 列表。

<a id="member-gfhurtbox3d-methods-clear_generated_collision_shape"></a>

### `clear_generated_collision_shape`

- API：`public`

```gdscript
func clear_generated_collision_shape() -> void:
```

移除框架管理的 CollisionShape3D 子节点。

<a id="member-gfhurtbox3d-methods-clear_generated_collision_shapes"></a>

### `clear_generated_collision_shapes`

- API：`public`

```gdscript
func clear_generated_collision_shapes() -> void:
```

移除框架管理的全部 CollisionShape3D 子节点。

<a id="member-gfhurtbox3d-methods-can_receive_hit"></a>

### `can_receive_hit`

- API：`public`

```gdscript
func can_receive_hit(p_hit_id: StringName = &"") -> bool:
```

检查指定命中 ID 是否可被当前接收器接受。

参数：

| 名称 | 说明 |
|---|---|
| `p_hit_id` | 命中 ID。 |

返回：可接受时返回 true。

<a id="member-gfhurtbox3d-methods-receive_hit"></a>

### `receive_hit`

- API：`public`

```gdscript
func receive_hit(context: GFCombatHitContext) -> Dictionary:
```

接收一次命中。

参数：

| 名称 | 说明 |
|---|---|
| `context` | 命中上下文。 |

返回：统一结果报告。

结构：

- `return`: Dictionary，统一命中接收报告，包含 ok、hit_id、receiver、reason、message 和 metadata。
