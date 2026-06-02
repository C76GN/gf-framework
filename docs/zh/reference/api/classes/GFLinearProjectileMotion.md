# GFLinearProjectileMotion

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_linear_projectile_motion.gd`
- 模块：`Combat`
- 继承：`GFProjectileMotion`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

2D/3D 通用直线发射体移动策略。 该策略只处理线性位移，不处理碰撞、伤害、生命周期或目标选择。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`speed`](#member-gflinearprojectilemotion-properties-speed) | `var speed: float = 0.0` |
| 属性 | [`direction_2d`](#member-gflinearprojectilemotion-properties-direction_2d) | `var direction_2d: Vector2 = Vector2.RIGHT` |
| 属性 | [`direction_3d`](#member-gflinearprojectilemotion-properties-direction_3d) | `var direction_3d: Vector3 = Vector3.FORWARD` |
| 属性 | [`use_local_direction`](#member-gflinearprojectilemotion-properties-use_local_direction) | `var use_local_direction: bool = true` |
| 属性 | [`normalize_direction`](#member-gflinearprojectilemotion-properties-normalize_direction) | `var normalize_direction: bool = true` |

## 属性

<a id="member-gflinearprojectilemotion-properties-speed"></a>

### `speed`

- API：`public`

```gdscript
var speed: float = 0.0
```

每秒移动距离。

<a id="member-gflinearprojectilemotion-properties-direction_2d"></a>

### `direction_2d`

- API：`public`

```gdscript
var direction_2d: Vector2 = Vector2.RIGHT
```

2D 方向。use_local_direction 为 true 时按发射体当前变换转换。

<a id="member-gflinearprojectilemotion-properties-direction_3d"></a>

### `direction_3d`

- API：`public`

```gdscript
var direction_3d: Vector3 = Vector3.FORWARD
```

3D 方向。use_local_direction 为 true 时按发射体当前变换转换。

<a id="member-gflinearprojectilemotion-properties-use_local_direction"></a>

### `use_local_direction`

- API：`public`

```gdscript
var use_local_direction: bool = true
```

是否把方向视为发射体本地坐标。

<a id="member-gflinearprojectilemotion-properties-normalize_direction"></a>

### `normalize_direction`

- API：`public`

```gdscript
var normalize_direction: bool = true
```

是否归一化方向。
