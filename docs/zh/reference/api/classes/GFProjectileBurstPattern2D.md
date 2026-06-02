# GFProjectileBurstPattern2D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_burst_pattern_2d.gd`
- 模块：`Combat`
- 继承：`GFProjectileSpawnPattern2D`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

2D 扇形/环形发射点模式。 通过数量、角度和半径生成一组通用发射变换，适合散射、圆环、扇形或单点发射。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`projectile_count`](#member-gfprojectileburstpattern2d-properties-projectile_count) | `var projectile_count: int = 1` |
| 属性 | [`spread_degrees`](#member-gfprojectileburstpattern2d-properties-spread_degrees) | `var spread_degrees: float = 0.0` |
| 属性 | [`center_angle_degrees`](#member-gfprojectileburstpattern2d-properties-center_angle_degrees) | `var center_angle_degrees: float = 0.0` |
| 属性 | [`radius`](#member-gfprojectileburstpattern2d-properties-radius) | `var radius: float = 0.0` |
| 属性 | [`rotate_to_direction`](#member-gfprojectileburstpattern2d-properties-rotate_to_direction) | `var rotate_to_direction: bool = true` |
| 属性 | [`include_emitter_rotation`](#member-gfprojectileburstpattern2d-properties-include_emitter_rotation) | `var include_emitter_rotation: bool = true` |

## 属性

<a id="member-gfprojectileburstpattern2d-properties-projectile_count"></a>

### `projectile_count`

- API：`public`

```gdscript
var projectile_count: int = 1
```

默认发射数量。

<a id="member-gfprojectileburstpattern2d-properties-spread_degrees"></a>

### `spread_degrees`

- API：`public`

```gdscript
var spread_degrees: float = 0.0
```

总扩散角度（度）。数量大于 1 时在该范围内均匀分布。

<a id="member-gfprojectileburstpattern2d-properties-center_angle_degrees"></a>

### `center_angle_degrees`

- API：`public`

```gdscript
var center_angle_degrees: float = 0.0
```

相对发射器朝向的中心角度（度）。

<a id="member-gfprojectileburstpattern2d-properties-radius"></a>

### `radius`

- API：`public`

```gdscript
var radius: float = 0.0
```

生成点距离发射器的半径。

<a id="member-gfprojectileburstpattern2d-properties-rotate_to_direction"></a>

### `rotate_to_direction`

- API：`public`

```gdscript
var rotate_to_direction: bool = true
```

生成变换是否朝向对应发射方向。

<a id="member-gfprojectileburstpattern2d-properties-include_emitter_rotation"></a>

### `include_emitter_rotation`

- API：`public`

```gdscript
var include_emitter_rotation: bool = true
```

是否把发射器自身旋转计入方向。
