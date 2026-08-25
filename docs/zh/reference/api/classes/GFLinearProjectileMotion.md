# GFLinearProjectileMotion

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_linear_projectile_motion.gd`
- 模块：`Combat`
- 继承：`GFProjectileMotion`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

2D/3D 对称的直线 intent 策略。

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
- 首次版本：`3.17.0`

```gdscript
var speed: float = 0.0
```

world-space 运动速度。

<a id="member-gflinearprojectilemotion-properties-direction_2d"></a>

### `direction_2d`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var direction_2d: Vector2 = Vector2.RIGHT
```

2D 基础方向。

<a id="member-gflinearprojectilemotion-properties-direction_3d"></a>

### `direction_3d`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var direction_3d: Vector3 = Vector3.FORWARD
```

3D 基础方向。

<a id="member-gflinearprojectilemotion-properties-use_local_direction"></a>

### `use_local_direction`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var use_local_direction: bool = true
```

是否按初始 body basis 将基础方向转换到 world-space。

<a id="member-gflinearprojectilemotion-properties-normalize_direction"></a>

### `normalize_direction`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var normalize_direction: bool = true
```

是否在乘以 speed 前单位化方向。
