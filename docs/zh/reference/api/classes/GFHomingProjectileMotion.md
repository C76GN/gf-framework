# GFHomingProjectileMotion

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_homing_projectile_motion.gd`
- 模块：`Combat`
- 继承：`GFProjectileMotion`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

使用 LaunchInput target 的 typed 追踪 intent 策略。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`speed`](#member-gfhomingprojectilemotion-properties-speed) | `var speed: float = 0.0` |
| 属性 | [`arrival_distance`](#member-gfhomingprojectilemotion-properties-arrival_distance) | `var arrival_distance: float = 0.0` |
| 属性 | [`track_target`](#member-gfhomingprojectilemotion-properties-track_target) | `var track_target: bool = true` |
| 属性 | [`stop_when_reached`](#member-gfhomingprojectilemotion-properties-stop_when_reached) | `var stop_when_reached: bool = true` |
| 方法 | [`_create_state_2d`](#member-gfhomingprojectilemotion-methods-_create_state_2d) | `func _create_state_2d( launch_input: GFProjectileLaunchInput2D, initial_body: GFProjectileBodyResult2D ) -> GFProjectileMotionState:` |
| 方法 | [`_create_state_3d`](#member-gfhomingprojectilemotion-methods-_create_state_3d) | `func _create_state_3d( launch_input: GFProjectileLaunchInput3D, initial_body: GFProjectileBodyResult3D ) -> GFProjectileMotionState:` |
| 方法 | [`_compute_intent_2d`](#member-gfhomingprojectilemotion-methods-_compute_intent_2d) | `func _compute_intent_2d( state: GFProjectileMotionState, current_body: GFProjectileBodyResult2D, delta: float ) -> GFProjectileMotionIntent2D:` |
| 方法 | [`_compute_intent_3d`](#member-gfhomingprojectilemotion-methods-_compute_intent_3d) | `func _compute_intent_3d( state: GFProjectileMotionState, current_body: GFProjectileBodyResult3D, delta: float ) -> GFProjectileMotionIntent3D:` |

## 属性

<a id="member-gfhomingprojectilemotion-properties-speed"></a>

### `speed`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var speed: float = 0.0
```

world-space 追踪速度。

<a id="member-gfhomingprojectilemotion-properties-arrival_distance"></a>

### `arrival_distance`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var arrival_distance: float = 0.0
```

视为到达目标的距离；NaN/Inf 会被拒绝，有限负值保持兼容语义并禁用 arrival clamp。

<a id="member-gfhomingprojectilemotion-properties-track_target"></a>

### `track_target`

- API：`public`
- 首次版本：`11.0.0`

```gdscript
var track_target: bool = true
```

是否每帧重新读取 node 目标位置；关闭且目标仍存活时，方向与 arrival clamp 使用 launch 快照。 目标失效后会沿锁定方向继续，并禁用旧位置 clamp。

<a id="member-gfhomingprojectilemotion-properties-stop_when_reached"></a>

### `stop_when_reached`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var stop_when_reached: bool = true
```

是否在本帧限制移动距离以停在 arrival boundary。

## 方法

<a id="member-gfhomingprojectilemotion-methods-_create_state_2d"></a>

### `_create_state_2d`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _create_state_2d( launch_input: GFProjectileLaunchInput2D, initial_body: GFProjectileBodyResult2D ) -> GFProjectileMotionState:
```

捕获二维发射目标的位置与初始方向，为本次 session 建立追踪状态。 节点目标只保留弱引用；此处记录目标种类，不将无目标直接判为创建失败。

参数：

| 名称 | 说明 |
|---|---|
| `launch_input` | 已冻结的发射输入，提供节点目标或位置目标。 |
| `initial_body` | 成功的初始 body 快照，用于计算指向目标的方向。 |

返回：本次 session 独占的状态；输入失效、body 失败或配置及目标偏移非有限时返回 null。

<a id="member-gfhomingprojectilemotion-methods-_create_state_3d"></a>

### `_create_state_3d`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _create_state_3d( launch_input: GFProjectileLaunchInput3D, initial_body: GFProjectileBodyResult3D ) -> GFProjectileMotionState:
```

捕获三维发射目标的位置与初始方向，为本次 session 建立追踪状态。 节点目标只保留弱引用；此处记录目标种类，不将无目标直接判为创建失败。

参数：

| 名称 | 说明 |
|---|---|
| `launch_input` | 已冻结的发射输入，提供节点目标或位置目标。 |
| `initial_body` | 成功的初始 body 快照，用于计算指向目标的方向。 |

返回：本次 session 独占的状态；输入失效、body 失败或配置及目标偏移非有限时返回 null。

<a id="member-gfhomingprojectilemotion-methods-_compute_intent_2d"></a>

### `_compute_intent_2d`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _compute_intent_2d( state: GFProjectileMotionState, current_body: GFProjectileBodyResult2D, delta: float ) -> GFProjectileMotionIntent2D:
```

根据二维目标与当前 body 计算追踪 intent，只更新状态中的锁定方向，不移动节点。 追踪开启时重新读取节点位置，目标丢失则拒绝；关闭追踪后目标丢失时， 已有的非零锁定方向可继续使用，并禁用旧目标位置的到达截短。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 本策略创建的 session 状态；其他状态类型会被拒绝。 |
| `current_body` | 成功的当前 body 快照，提供计算距离所需的位置。 |
| `delta` | 本帧秒数；有限非正值生成零速度、零时长 intent，非有限值被拒绝。 |

返回：按到达设置截短路程后的 MOVE；状态、目标或数值无效时返回带原因的 REJECTED。

<a id="member-gfhomingprojectilemotion-methods-_compute_intent_3d"></a>

### `_compute_intent_3d`

- API：`protected`
- 首次版本：`11.0.0`

```gdscript
func _compute_intent_3d( state: GFProjectileMotionState, current_body: GFProjectileBodyResult3D, delta: float ) -> GFProjectileMotionIntent3D:
```

根据三维目标与当前 body 计算追踪 intent，只更新状态中的锁定方向，不移动节点。 追踪开启时重新读取节点位置，目标丢失则拒绝；关闭追踪后目标丢失时， 已有的非零锁定方向可继续使用，并禁用旧目标位置的到达截短。

参数：

| 名称 | 说明 |
|---|---|
| `state` | 本策略创建的 session 状态；其他状态类型会被拒绝。 |
| `current_body` | 成功的当前 body 快照，提供计算距离所需的位置。 |
| `delta` | 本帧秒数；有限非正值生成零速度、零时长 intent，非有限值被拒绝。 |

返回：按到达设置截短路程后的 MOVE；状态、目标或数值无效时返回带原因的 REJECTED。
