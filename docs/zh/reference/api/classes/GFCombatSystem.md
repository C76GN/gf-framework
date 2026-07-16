# GFCombatSystem

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/core/gf_combat_system.gd`
- 模块：`Combat`
- 继承：`GFSystem`
- API：`public`
- 类别：运行时服务 (`runtime_service`)
- 首次版本：`3.17.0`

战斗核心系统。 负责驱动所有注册实体的 Buff 计时、周期触发以及技能 CD 更新。 继承自 GFSystem，可通过架构的 tick 自动运行。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`buff_removal_reported`](#member-gfcombatsystem-signals-buff_removal_reported) | `signal buff_removal_reported(` |
| 方法 | [`tick`](#member-gfcombatsystem-methods-tick) | `func tick(p_delta: float) -> void:` |
| 方法 | [`dispose`](#member-gfcombatsystem-methods-dispose) | `func dispose() -> void:` |
| 方法 | [`register_entity`](#member-gfcombatsystem-methods-register_entity) | `func register_entity(p_entity: Object) -> void:` |
| 方法 | [`unregister_entity`](#member-gfcombatsystem-methods-unregister_entity) | `func unregister_entity(p_entity: Object) -> void:` |
| 方法 | [`add_buff`](#member-gfcombatsystem-methods-add_buff) | `func add_buff(p_entity: Object, p_buff: GFBuff) -> void:` |
| 方法 | [`add_skill`](#member-gfcombatsystem-methods-add_skill) | `func add_skill(p_entity: Object, p_skill: GFSkill) -> void:` |
| 方法 | [`get_buff`](#member-gfcombatsystem-methods-get_buff) | `func get_buff(p_entity: Object, p_buff_id: StringName) -> GFBuff:` |
| 方法 | [`has_buff`](#member-gfcombatsystem-methods-has_buff) | `func has_buff(p_entity: Object, p_buff_id: StringName) -> bool:` |
| 方法 | [`get_buffs`](#member-gfcombatsystem-methods-get_buffs) | `func get_buffs(p_entity: Object) -> Array[GFBuff]:` |
| 方法 | [`refresh_buff_modifiers`](#member-gfcombatsystem-methods-refresh_buff_modifiers) | `func refresh_buff_modifiers(p_entity: Object, p_buff_id: StringName) -> bool:` |
| 方法 | [`remove_buff`](#member-gfcombatsystem-methods-remove_buff) | `func remove_buff(p_entity: Object, p_buff_id: StringName) -> bool:` |
| 方法 | [`remove_buff_with_reason`](#member-gfcombatsystem-methods-remove_buff_with_reason) | `func remove_buff_with_reason( p_entity: Object, p_buff_id: StringName, reason: StringName = GFBuff.REMOVAL_REASON_REMOVED ) -> bool:` |
| 方法 | [`clear_buffs`](#member-gfcombatsystem-methods-clear_buffs) | `func clear_buffs(p_entity: Object, predicate: Callable = Callable()) -> int:` |
| 方法 | [`clear_buffs_with_reason`](#member-gfcombatsystem-methods-clear_buffs_with_reason) | `func clear_buffs_with_reason( p_entity: Object, predicate: Callable = Callable(), reason: StringName = GFBuff.REMOVAL_REASON_CLEARED ) -> int:` |
| 方法 | [`remove_skill`](#member-gfcombatsystem-methods-remove_skill) | `func remove_skill(p_entity: Object, p_skill: GFSkill) -> bool:` |

## 信号

<a id="member-gfcombatsystem-signals-buff_removal_reported"></a>

### `buff_removal_reported`

- API：`public`
- 首次版本：`8.0.0`

```gdscript
signal buff_removal_reported(
```

Buff 已从系统索引移除并完成 best-effort 清理。

参数：

| 名称 | 说明 |
|---|---|
| `entity` | 原所属实体；实体已释放时可能为 null。 |
| `buff_id` | 被移除 Buff ID。 |
| `reason` | 移除原因。 |
| `lifecycle_report` | GFBuff.on_remove() 生命周期报告。 |

结构：

- `lifecycle_report`: Dictionary，移除生命周期报告的深副本。

## 方法

<a id="member-gfcombatsystem-methods-tick"></a>

### `tick`

- API：`public`

```gdscript
func tick(p_delta: float) -> void:
```

推进运行时逻辑。

参数：

| 名称 | 说明 |
|---|---|
| `p_delta` | 本帧时间增量（秒）。 |

<a id="member-gfcombatsystem-methods-dispose"></a>

### `dispose`

- API：`public`

```gdscript
func dispose() -> void:
```

释放系统持有的实体、Buff 与技能连接。

<a id="member-gfcombatsystem-methods-register_entity"></a>

### `register_entity`

- API：`public`

```gdscript
func register_entity(p_entity: Object) -> void:
```

注册战斗实体。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |

<a id="member-gfcombatsystem-methods-unregister_entity"></a>

### `unregister_entity`

- API：`public`

```gdscript
func unregister_entity(p_entity: Object) -> void:
```

注销战斗实体。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |

<a id="member-gfcombatsystem-methods-add_buff"></a>

### `add_buff`

- API：`public`

```gdscript
func add_buff(p_entity: Object, p_buff: GFBuff) -> void:
```

给实体添加一个 Buff。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |
| `p_buff` | Buff 实例。 |

<a id="member-gfcombatsystem-methods-add_skill"></a>

### `add_skill`

- API：`public`

```gdscript
func add_skill(p_entity: Object, p_skill: GFSkill) -> void:
```

为实体添加技能。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |
| `p_skill` | 技能实例。 |

<a id="member-gfcombatsystem-methods-get_buff"></a>

### `get_buff`

- API：`public`

```gdscript
func get_buff(p_entity: Object, p_buff_id: StringName) -> GFBuff:
```

获取实体上的指定 Buff。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |
| `p_buff_id` | Buff 标识。 |

返回：找到时返回正在系统中生效的 Buff 实例，否则返回 null。

<a id="member-gfcombatsystem-methods-has_buff"></a>

### `has_buff`

- API：`public`

```gdscript
func has_buff(p_entity: Object, p_buff_id: StringName) -> bool:
```

检查实体上是否存在指定 Buff。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |
| `p_buff_id` | Buff 标识。 |

返回：存在返回 true。

<a id="member-gfcombatsystem-methods-get_buffs"></a>

### `get_buffs`

- API：`public`

```gdscript
func get_buffs(p_entity: Object) -> Array[GFBuff]:
```

获取实体当前持有的 Buff 列表副本。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |

返回：Buff 实例数组副本；数组本身可安全修改，但元素仍是运行中的 Buff 引用。

<a id="member-gfcombatsystem-methods-refresh_buff_modifiers"></a>

### `refresh_buff_modifiers`

- API：`public`

```gdscript
func refresh_buff_modifiers(p_entity: Object, p_buff_id: StringName) -> bool:
```

强制刷新指定 Buff 已挂载修饰器影响到的属性。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |
| `p_buff_id` | Buff 标识。 |

返回：至少刷新了一个属性时返回 true。

<a id="member-gfcombatsystem-methods-remove_buff"></a>

### `remove_buff`

- API：`public`

```gdscript
func remove_buff(p_entity: Object, p_buff_id: StringName) -> bool:
```

移除实体上的指定 Buff。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |
| `p_buff_id` | Buff 标识。 |

返回：找到并移除 Buff 时返回 true。

<a id="member-gfcombatsystem-methods-remove_buff_with_reason"></a>

### `remove_buff_with_reason`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func remove_buff_with_reason( p_entity: Object, p_buff_id: StringName, reason: StringName = GFBuff.REMOVAL_REASON_REMOVED ) -> bool:
```

移除实体上的指定 Buff，并记录移除原因。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |
| `p_buff_id` | Buff 标识。 |
| `reason` | 移除原因。 |

返回：找到并移除 Buff 时返回 true。

<a id="member-gfcombatsystem-methods-clear_buffs"></a>

### `clear_buffs`

- API：`public`

```gdscript
func clear_buffs(p_entity: Object, predicate: Callable = Callable()) -> int:
```

清理实体上的 Buff。predicate 为空时清理全部；否则仅清理返回 true 的 Buff。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |
| `predicate` | 可选过滤回调，签名为 `func(buff: GFBuff) -> bool`。 |

返回：被清理的 Buff 数量。

<a id="member-gfcombatsystem-methods-clear_buffs_with_reason"></a>

### `clear_buffs_with_reason`

- API：`public`
- 首次版本：`6.0.0`

```gdscript
func clear_buffs_with_reason( p_entity: Object, predicate: Callable = Callable(), reason: StringName = GFBuff.REMOVAL_REASON_CLEARED ) -> int:
```

清理实体上的 Buff，并记录移除原因。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |
| `predicate` | 可选过滤回调，签名为 `func(buff: GFBuff) -> bool`。 |
| `reason` | 移除原因。 |

返回：被清理的 Buff 数量。

<a id="member-gfcombatsystem-methods-remove_skill"></a>

### `remove_skill`

- API：`public`

```gdscript
func remove_skill(p_entity: Object, p_skill: GFSkill) -> bool:
```

移除实体上的指定技能。

参数：

| 名称 | 说明 |
|---|---|
| `p_entity` | 实体对象。 |
| `p_skill` | 技能实例。 |

返回：找到并移除技能时返回 true。
