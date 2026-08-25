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
| 方法 | [`_get_spawn_transforms`](#member-gfprojectileconepattern3d-methods-_get_spawn_transforms) | `func _get_spawn_transforms( emitter: Node3D, _launch_input: GFProjectileLaunchInput3D = null, emit_count: int = -1 ) -> Array[Transform3D]:` |

## 属性

<a id="member-gfprojectileconepattern3d-properties-projectile_count"></a>

### `projectile_count`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var projectile_count: int = 1
```

默认发射数量。

<a id="member-gfprojectileconepattern3d-properties-yaw_spread_degrees"></a>

### `yaw_spread_degrees`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var yaw_spread_degrees: float = 0.0
```

总水平扩散角度（度）。

<a id="member-gfprojectileconepattern3d-properties-pitch_degrees"></a>

### `pitch_degrees`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var pitch_degrees: float = 0.0
```

额外俯仰角度（度）。

<a id="member-gfprojectileconepattern3d-properties-radius"></a>

### `radius`

- API：`public`
- 首次版本：`3.17.0`

```gdscript
var radius: float = 0.0
```

生成点距离发射器的半径。

## 方法

<a id="member-gfprojectileconepattern3d-methods-_get_spawn_transforms"></a>

### `_get_spawn_transforms`

- API：`protected`
- 首次版本：`3.17.0`

```gdscript
func _get_spawn_transforms( emitter: Node3D, _launch_input: GFProjectileLaunchInput3D = null, emit_count: int = -1 ) -> Array[Transform3D]:
```

生成 3D 扇形发射变换。

参数：

| 名称 | 说明 |
|---|---|
| `emitter` | 发射器节点。 |
| `_launch_input` | 本次 typed 发射输入；当前实现不读取。 |
| `emit_count` | 调用方请求的数量；小于等于 0 时使用 projectile_count。 |

返回：全局 Transform3D 列表。
