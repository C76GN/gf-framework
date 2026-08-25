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
