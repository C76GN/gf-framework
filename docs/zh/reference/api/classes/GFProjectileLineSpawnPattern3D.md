# GFProjectileLineSpawnPattern3D

[API Reference](../index.md) / [Combat](../extensions-combat.md) / [类索引](index.md)

- 路径：`addons/gf/extensions/combat/projectiles/gf_projectile_line_spawn_pattern_3d.gd`
- 模块：`Combat`
- 继承：`GFProjectileSpawnPattern3D`
- API：`public`
- 类别：资源定义 (`resource_definition`)
- 首次版本：`3.17.0`

沿 3D 局部线段生成发射点。 只描述发射点分布，适合多炮口、轨道点或沿空间线段生成发射体。

## 成员概览

| 类型 | 名称 | 签名 |
|---|---|---|
| 属性 | [`point_count`](#member-gfprojectilelinespawnpattern3d-properties-point_count) | `var point_count: int = 1` |
| 属性 | [`local_start`](#member-gfprojectilelinespawnpattern3d-properties-local_start) | `var local_start: Vector3 = Vector3.ZERO` |
| 属性 | [`local_end`](#member-gfprojectilelinespawnpattern3d-properties-local_end) | `var local_end: Vector3 = Vector3.ZERO` |
| 属性 | [`rotate_to_line`](#member-gfprojectilelinespawnpattern3d-properties-rotate_to_line) | `var rotate_to_line: bool = false` |

## 属性

<a id="member-gfprojectilelinespawnpattern3d-properties-point_count"></a>

### `point_count`

- API：`public`

```gdscript
var point_count: int = 1
```

默认发射数量。

<a id="member-gfprojectilelinespawnpattern3d-properties-local_start"></a>

### `local_start`

- API：`public`

```gdscript
var local_start: Vector3 = Vector3.ZERO
```

线段局部起点。

<a id="member-gfprojectilelinespawnpattern3d-properties-local_end"></a>

### `local_end`

- API：`public`

```gdscript
var local_end: Vector3 = Vector3.ZERO
```

线段局部终点。

<a id="member-gfprojectilelinespawnpattern3d-properties-rotate_to_line"></a>

### `rotate_to_line`

- API：`public`

```gdscript
var rotate_to_line: bool = false
```

生成变换是否朝向线段方向。
