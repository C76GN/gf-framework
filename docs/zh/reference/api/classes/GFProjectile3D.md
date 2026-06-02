# GFProjectile3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_3d.gd`
- 模块：`Combat`
- 继承：`GFHitBox3D`
- API：`public`
- 类别：运行时句柄 (`runtime_handle`)
- 首次版本：`3.17.0`

可组合移动策略的 3D 发射体命中节点。 它继承 GFHitBox3D，命中仍通过 GFCombatHitContext 发送给 receive_hit()。 节点只负责移动、寿命和碰撞触发，不解释伤害、阵营或生命值规则。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 信号 | [`projectile_launched`](#member-gfprojectile3d-signals-projectile_launched) | `signal projectile_launched(projectile: GFProjectile3D)` |
| 信号 | [`projectile_finished`](#member-gfprojectile3d-signals-projectile_finished) | `signal projectile_finished(projectile: GFProjectile3D, reason: StringName)` |
| 属性 | [`auto_launch_on_ready`](#member-gfprojectile3d-properties-auto_launch_on_ready) | `var auto_launch_on_ready: bool = true` |
| 属性 | [`motion`](#member-gfprojectile3d-properties-motion) | `var motion: Resource = null` |
| 属性 | [`lifetime_policy`](#member-gfprojectile3d-properties-lifetime_policy) | `var lifetime_policy: Resource = null` |
| 属性 | [`finish_on_impact`](#member-gfprojectile3d-properties-finish_on_impact) | `var finish_on_impact: bool = true` |
| 属性 | [`queue_free_on_finish`](#member-gfprojectile3d-properties-queue_free_on_finish) | `var queue_free_on_finish: bool = true` |
| 方法 | [`launch`](#member-gfprojectile3d-methods-launch) | `func launch(projectile_context: Dictionary = {}) -> void:` |
| 方法 | [`finish`](#member-gfprojectile3d-methods-finish) | `func finish(reason: StringName = &"finished") -> void:` |
| 方法 | [`is_projectile_active`](#member-gfprojectile3d-methods-is_projectile_active) | `func is_projectile_active() -> bool:` |
| 方法 | [`get_elapsed_seconds`](#member-gfprojectile3d-methods-get_elapsed_seconds) | `func get_elapsed_seconds() -> float:` |
| 方法 | [`get_projectile_context`](#member-gfprojectile3d-methods-get_projectile_context) | `func get_projectile_context() -> Dictionary:` |
| 方法 | [`send_impact_to`](#member-gfprojectile3d-methods-send_impact_to) | `func send_impact_to(candidate: Object) -> void:` |

## 信号

<a id="member-gfprojectile3d-signals-projectile_launched"></a>

### `projectile_launched`

- API：`public`

```gdscript
signal projectile_launched(projectile: GFProjectile3D)
```

发射体启动时发出。

参数：

| 名称 | 说明 |
|---|---|
| `projectile` | 当前发射体。 |

<a id="member-gfprojectile3d-signals-projectile_finished"></a>

### `projectile_finished`

- API：`public`

```gdscript
signal projectile_finished(projectile: GFProjectile3D, reason: StringName)
```

发射体结束时发出。

参数：

| 名称 | 说明 |
|---|---|
| `projectile` | 当前发射体。 |
| `reason` | 结束原因。 |

## 属性

<a id="member-gfprojectile3d-properties-auto_launch_on_ready"></a>

### `auto_launch_on_ready`

- API：`public`

```gdscript
var auto_launch_on_ready: bool = true
```

ready 后是否自动启动本次发射。

<a id="member-gfprojectile3d-properties-motion"></a>

### `motion`

- API：`public`

```gdscript
var motion: Resource = null
```

移动策略。应实现 setup(projectile, context) 与 step(projectile, delta, context)。

<a id="member-gfprojectile3d-properties-lifetime_policy"></a>

### `lifetime_policy`

- API：`public`

```gdscript
var lifetime_policy: Resource = null
```

生命周期策略。应实现 setup(projectile, context) 与 should_finish(projectile, elapsed, context)。

<a id="member-gfprojectile3d-properties-finish_on_impact"></a>

### `finish_on_impact`

- API：`public`

```gdscript
var finish_on_impact: bool = true
```

命中任意 receive_hit() 接收器后是否结束。

<a id="member-gfprojectile3d-properties-queue_free_on_finish"></a>

### `queue_free_on_finish`

- API：`public`

```gdscript
var queue_free_on_finish: bool = true
```

结束时是否 queue_free。使用对象池时通常应关闭。

## 方法

<a id="member-gfprojectile3d-methods-launch"></a>

### `launch`

- API：`public`

```gdscript
func launch(projectile_context: Dictionary = {}) -> void:
```

启动或重置本次发射。

参数：

| 名称 | 说明 |
|---|---|
| `projectile_context` | 本次发射的上下文字典。 |

结构：

- `projectile_context`: Dictionary，本次发射上下文；会复制后传给 motion、lifetime_policy 和命中记录。

<a id="member-gfprojectile3d-methods-finish"></a>

### `finish`

- API：`public`

```gdscript
func finish(reason: StringName = &"finished") -> void:
```

结束本次发射。

参数：

| 名称 | 说明 |
|---|---|
| `reason` | 结束原因。 |

<a id="member-gfprojectile3d-methods-is_projectile_active"></a>

### `is_projectile_active`

- API：`public`

```gdscript
func is_projectile_active() -> bool:
```

判断发射体是否处于已启动状态。

返回：已启动且未结束时返回 true。

<a id="member-gfprojectile3d-methods-get_elapsed_seconds"></a>

### `get_elapsed_seconds`

- API：`public`

```gdscript
func get_elapsed_seconds() -> float:
```

获取本次发射经过的秒数。

返回：经过的秒数。

<a id="member-gfprojectile3d-methods-get_projectile_context"></a>

### `get_projectile_context`

- API：`public`

```gdscript
func get_projectile_context() -> Dictionary:
```

获取本次发射上下文副本。

返回：上下文字典副本。

结构：

- `return`: Dictionary，本次发射上下文副本，包含调用方上下文、发射器写入字段和 impact 计数。

<a id="member-gfprojectile3d-methods-send_impact_to"></a>

### `send_impact_to`

- API：`public`

```gdscript
func send_impact_to(candidate: Object) -> void:
```

向碰撞候选对象发送一次发射体命中。

参数：

| 名称 | 说明 |
|---|---|
| `candidate` | 碰撞候选对象，可为接收器或其子节点。 |
