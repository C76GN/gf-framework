# GFProjectileConePattern3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_cone_pattern_3d.gd`
- 模块：`Combat`
- 继承：`GFProjectileSpawnPattern3D`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

3D 水平扇形发射点模式。 围绕发射器局部 Y 轴分布 yaw，可叠加固定 pitch，并按变换前向生成点位。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`projectile_count`](#member-gfprojectileconepattern3d-properties-projectile_count) | `var projectile_count: int = 1` |
| 属性 | [`yaw_spread_degrees`](#member-gfprojectileconepattern3d-properties-yaw_spread_degrees) | `var yaw_spread_degrees: float = 0.0` |
| 属性 | [`pitch_degrees`](#member-gfprojectileconepattern3d-properties-pitch_degrees) | `var pitch_degrees: float = 0.0` |
| 属性 | [`radius`](#member-gfprojectileconepattern3d-properties-radius) | `var radius: float = 0.0` |

## 属性

<a id="member-gfprojectileconepattern3d-properties-projectile_count"></a>

### `projectile_count`

- API：`public`

```gdscript
var projectile_count: int = 1
```

默认发射数量。

<a id="member-gfprojectileconepattern3d-properties-yaw_spread_degrees"></a>

### `yaw_spread_degrees`

- API：`public`

```gdscript
var yaw_spread_degrees: float = 0.0
```

总水平扩散角度（度）。

<a id="member-gfprojectileconepattern3d-properties-pitch_degrees"></a>

### `pitch_degrees`

- API：`public`

```gdscript
var pitch_degrees: float = 0.0
```

额外俯仰角度（度）。

<a id="member-gfprojectileconepattern3d-properties-radius"></a>

### `radius`

- API：`public`

```gdscript
var radius: float = 0.0
```

生成点距离发射器的半径。
